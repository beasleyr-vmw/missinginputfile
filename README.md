## Motivating issue

```console
$ bazelisk build @foo//:dummy
INFO: Analyzed target @foo//:dummy (1 packages loaded, 1 target configured).
INFO: Found 1 target...
INFO: Elapsed time: 0.409s, Critical Path: 0.02s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
$ ls -al $(bazelisk info output_base)/external/foo
total 0
drwxr-xr-x. 2 beasleyr mts 49 Dec  7 06:18 .
drwxr-xr-x. 3 beasleyr mts 82 Dec  7 06:18 ..
lrwxrwxrwx. 1 beasleyr mts 25 Dec  7 06:18 BUILD -> /tmp/tmp.Gx7y3CMhg6/BUILD
lrwxrwxrwx. 1 beasleyr mts 25 Dec  7 06:18 dummy -> /tmp/tmp.Gx7y3CMhg6/dummy
lrwxrwxrwx. 1 beasleyr mts 29 Dec  7 06:18 WORKSPACE -> /tmp/tmp.Gx7y3CMhg6/WORKSPACE
$ rm -rf /tmp/tmp.Gx7y3CMhg6
$ bazelisk build @foo//:dummy
ERROR: Skipping '@foo//:dummy': no such package '@foo//': BUILD file not found in directory '' of external repository @foo. Add a BUILD file to a directory to mark it as a package.
WARNING: Target pattern parsing failed.
ERROR: no such package '@foo//': BUILD file not found in directory '' of external repository @foo. Add a BUILD file to a directory to mark it as a package.
INFO: Elapsed time: 10.008s
INFO: 0 processes.
FAILED: Build did NOT complete successfully (0 packages loaded)
```
