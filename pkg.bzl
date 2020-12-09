def _pkg_generation_impl(rctx):
    print("_pkg_generation_impl start")
    generation = "0"
    checkpkg = rctx.path(rctx.attr.checkpkg)
    pkg_log = rctx.os.environ.get("PKG_LOG")
    if pkg_log:
        res = rctx.execute(
            [checkpkg, pkg_log, rctx.attr.pkgname],
            # environment = {"PKG_SEED": rctx.os.environ.get("PKG_SEED", "")},
        )
        if res.return_code == 0:
            generation = res.stdout.strip()

        print("retcode %d" % res.return_code)
        print("stdout %s" % res.stdout)
        print("stderr %s" % res.stderr)

    print("_pkg_generation_impl result %s" % generation)

    rctx.file("generation", generation)
    rctx.file("WORKSPACE", "workspace(name = {})".format(rctx.name))
    rctx.file("BUILD", """
package(default_visibility = ["//visibility:public"])
exports_files(glob(["**"]))
""")

pkg_generation = repository_rule(
    implementation = _pkg_generation_impl,
    local = True,
    attrs = {
        "checkpkg": attr.label(default = "@//:checkpkg"),
        "pkgname": attr.string(),
    },
    environ = [
        "PKG_LOG",
        "PKG_SEED",  # `PKG_SEED=$(date +%s) bazelisk ...` to always run this.
    ],
)

def _pkg_impl(rctx):
    print("_pkg_impl start")

    # Invalidate when the following file changes.
    # broken_marker = "@{}_generation//:generation".format(rctx.name)
    # generation = rctx.read(rctx.path(Label(broken_marker))).strip()
    generation = rctx.read(rctx.path(rctx.attr._generation)).strip()
    print("_pkg_impl start (generation %s)" % generation)

    mkpkg = rctx.path(rctx.attr.mkpkg)
    logpkg = rctx.path(rctx.attr.logpkg)

    res = rctx.execute([mkpkg, rctx.name])
    if res.return_code != 0:
        fail(res.stderr)
    root = res.stdout.strip()

    for p in rctx.path(root).readdir():
        rctx.symlink(p, p.basename)

    pkg_log = rctx.os.environ.get("PKG_LOG")
    if pkg_log:
        rctx.execute([logpkg, pkg_log, rctx.name, rctx.path("."), generation])

    rctx.file("WORKSPACE", "workspace(name = {})".format(rctx.name))
    rctx.file("BUILD.bazel", """
package(default_visibility = ["//visibility:public"])
exports_files(glob(["**"]))
""")

pkg = repository_rule(
    implementation = _pkg_impl,
    attrs = {
        "logpkg": attr.label(default = "@//:logpkg"),
        "mkpkg": attr.label(default = "@//:mkpkg"),
        "_generation": attr.label(default = "@foo_generation//:generation")
    },
    environ = [
        "SOME_ROOT",
        "PKG_LOG",
        "PKG_BASE",
    ],
)
