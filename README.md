## Motivating issue

```console
$ bazelisk info release
release 3.7.1
```

I have an example repository rule named `pkg`.  When the rule executes,
it creates a staging directory outside of Bazel's output root containing
a single file named `dummy`.  The contents are then symlinked in a la
`new_local_repository`.

```console
$ bazelisk build @foo//:dummy
$ ls -al $(bazelisk info output_base)/external/foo
total 8
drwxr-xr-x. 2 beasleyr mts  55 Dec  9 14:42 .
drwxr-xr-x. 4 beasleyr mts 134 Dec  9 14:42 ..
-rwxr-xr-x. 1 beasleyr mts  83 Dec  9 14:42 BUILD.bazel
lrwxrwxrwx. 1 beasleyr mts  25 Dec  9 14:42 dummy -> /tmp/tmp.YiBG7q0rtm/dummy
-rwxr-xr-x. 1 beasleyr mts  21 Dec  9 14:42 WORKSPACE
```

Now purge the external directory.  (User might want to free up space, or
system service may have purged the directory after a lease expires.)

```console
$ rm -rf /tmp/tmp.YiBG7q0rtm
```

Finally, attempt to rebuild the target.  Observe that Bazel fails due to
the broken symlink.

```console
$ bazelisk build @foo//:dummy
ERROR: Skipping '@foo//:dummy': no such target '@foo//:dummy': target 'dummy' not declared in package '' defined by /work/.cache/bazel/a8aa08e6ef07e3a4e1371edf579a8335/external/foo/BUILD.bazel
WARNING: Target pattern parsing failed.
ERROR: no such target '@foo//:dummy': target 'dummy' not declared in package '' defined by /work/.cache/bazel/a8aa08e6ef07e3a4e1371edf579a8335/external/foo/BUILD.bazel
INFO: Elapsed time: 10.198s
INFO: 0 processes.
FAILED: Build did NOT complete successfully (1 packages loaded)
```

## Use an always-run rule to detect breakage and signal re-eval of repo rule

I have a pair of repository rules, `pkg_generation` and `pkg`.  For the
purposes of this demo, the corresponding repositories are `@foo_generation`
and `@foo`.

1. `pkg_generation` produces a single output containing the _generation
   number_ of the corresponding `pkg` rule.  Each time `pkg_generation`
   detects that the corresponding `pkg` repository contains broken
   symlinks, the generation number is incremented.
2. This output (ex: `@foo_generation//:generation`) is a dependency of the
   `@foo` package via `rctx.path(Label("@foo_generation//:generation"))`.
   If `generation` changes, `@foo`'s repo rule is reexecuted, and its
   contents are regenerated.
3. `pkg_generation` is optionally an always-run rule:  it declares an env
   var as a dependency, and the user can enable this by invoking Bazel w/
   a constantly changing value (`VAR=$(date +%s) bazelisk ...`).
   
Here's my problem:  This only works when the underlying path to `@foo`
changes between invocations.  If the staging directory is recreated with
the same path, Bazel breaks with a novel error.

### Create `@foo` staging dir w/ `mktemp -d`

By default, `mkpkg` creates a random staging directory w/ `mktemp -d`.

#### Build dummy

```console
$ PKG_LOG=$PWD/pkg.log PKG_SEED=$(date +%s) bazelisk build @foo//:dummy
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:2:10: _pkg_generation_impl start
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:14:14: retcode 0
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:15:14: stdout 0
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:16:14: stderr grep: /work/git/repros/missinginputfile/pkg.log: No such file or directory
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:18:10: _pkg_generation_impl result 0
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:41:10: _pkg_impl start
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:47:10: _pkg_impl start (generation 0)
INFO: Analyzed target @foo//:dummy (1 packages loaded, 1 target configured).
INFO: Found 1 target...
INFO: Elapsed time: 0.479s, Critical Path: 0.02s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
```

#### Delete underlying directory

```console
$ ls -al $(bazelisk info output_base)/external/foo
total 8
drwxr-xr-x. 2 beasleyr mts  55 Dec  9 15:04 .
drwxr-xr-x. 4 beasleyr mts 134 Dec  9 15:04 ..
-rwxr-xr-x. 1 beasleyr mts  83 Dec  9 15:04 BUILD.bazel
lrwxrwxrwx. 1 beasleyr mts  25 Dec  9 15:04 dummy -> /tmp/tmp.n0H7OIg8o2/dummy
-rwxr-xr-x. 1 beasleyr mts  21 Dec  9 15:04 WORKSPACE
$ rm -rf /tmp/tmp.n0H7OIg8o2
```

#### Rebuild

Observe that gen no increments and `_pkg_impl` reexecutes.  Content now in
a different directory.

```console
$ PKG_LOG=$PWD/pkg.log PKG_SEED=$(date +%s) bazelisk build @foo//:dummy
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:2:10: _pkg_generation_impl start
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:14:14: retcode 0
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:15:14: stdout 1
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:16:14: stderr
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:18:10: _pkg_generation_impl result 1
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:41:10: _pkg_impl start
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:47:10: _pkg_impl start (generation 1)
INFO: Analyzed target @foo//:dummy (1 packages loaded, 1 target configured).
INFO: Found 1 target...
INFO: Elapsed time: 0.184s, Critical Path: 0.01s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
$ ls -al $(bazelisk info output_base)/external/foo
total 8
drwxr-xr-x. 2 beasleyr mts  55 Dec  9 15:04 .
drwxr-xr-x. 4 beasleyr mts 134 Dec  9 15:04 ..
-rwxr-xr-x. 1 beasleyr mts  83 Dec  9 15:04 BUILD.bazel
lrwxrwxrwx. 1 beasleyr mts  25 Dec  9 15:04 dummy -> /tmp/tmp.sdkMqbEdvR/dummy
-rwxr-xr-x. 1 beasleyr mts  21 Dec  9 15:04 WORKSPACE
```

### Recreate `@foo` at a fixed location

When not using random directories, even though my repository rule
is reexecuting and recreates the external tree, Bazel fails with a
message indicating that the generated file doesn't exist.  However,
it clearly does.  What's extremely odd is that immediately running the
same Bazel command succeeds.

#### Build `@foo` at fixed path `/tmp/asdf/foo`

```console
$ mkdir /tmp/asdf
$ PKG_BASE=/tmp/asdf PKG_LOG=$PWD/pkg.log PKG_SEED=$(date +%s) bazelisk build @foo//:dummy
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:2:10: _pkg_generation_impl start
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:14:14: retcode 0
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:15:14: stdout 2
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:16:14: stderr
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:18:10: _pkg_generation_impl result 2
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:41:10: _pkg_impl start
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:47:10: _pkg_impl start (generation 2)
INFO: Analyzed target @foo//:dummy (1 packages loaded, 1 target configured).
INFO: Found 1 target...
INFO: Elapsed time: 0.511s, Critical Path: 0.02s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
$ ls -al $(bazelisk info output_base)/external/foo
total 8
drwxr-xr-x. 2 beasleyr mts  55 Dec  9 15:12 .
drwxr-xr-x. 4 beasleyr mts 134 Dec  9 15:12 ..
-rwxr-xr-x. 1 beasleyr mts  83 Dec  9 15:12 BUILD.bazel
lrwxrwxrwx. 1 beasleyr mts  19 Dec  9 15:12 dummy -> /tmp/asdf/foo/dummy
-rwxr-xr-x. 1 beasleyr mts  21 Dec  9 15:12 WORKSPACE
```

#### Purge `foo` and regenerate at same location

Observe the failure.

```console
$ rm -rf /tmp/asdf/foo
$ PKG_BASE=/tmp/asdf  PKG_LOG=$PWD/pkg.log PKG_SEED=$(date +%s) bazelisk build @foo//:dummy
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:2:10: _pkg_generation_impl start
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:14:14: retcode 0
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:15:14: stdout 3
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:16:14: stderr
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:18:10: _pkg_generation_impl result 3
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:41:10: _pkg_impl start
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:47:10: _pkg_impl start (generation 3)
INFO: Analyzed target @foo//:dummy (1 packages loaded, 1 target configured).
INFO: Found 1 target...
ERROR: /work/.cache/bazel/a8aa08e6ef07e3a4e1371edf579a8335/external/foo/BUILD.bazel:3:14: @foo//:dummy: missing input file 'external/foo/dummy', owner: '@foo//:dummy'
ERROR: /work/.cache/bazel/a8aa08e6ef07e3a4e1371edf579a8335/external/foo/BUILD.bazel:3:14 1 input file(s) do not exist
INFO: Elapsed time: 0.251s, Critical Path: 0.01s
INFO: 1 process: 1 internal.
FAILED: Build did NOT complete successfully
```

#### Re-run the same command w/o doing anything else

Suddenly it works.

```console
$ PKG_BASE=/tmp/asdf  PKG_LOG=$PWD/pkg.log PKG_SEED=$(date +%s) bazelisk build @foo//:dummy
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:2:10: _pkg_generation_impl start
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:14:14: retcode 0
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:15:14: stdout 3
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:16:14: stderr
DEBUG: /work/git/repros/missinginputfile/pkg.bzl:18:10: _pkg_generation_impl result 3
INFO: Analyzed target @foo//:dummy (1 packages loaded, 1 target configured).
INFO: Found 1 target...
INFO: Elapsed time: 0.169s, Critical Path: 0.01s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
```
