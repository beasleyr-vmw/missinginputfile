def _pkg_impl(rctx):
    res = rctx.execute([rctx.path(rctx.attr.mkpkg), rctx.name])
    if res.return_code != 0:
        fail(res.stderr)

    for p in rctx.path(res.stdout.strip()).readdir():
        rctx.symlink(p, p.basename)

pkg = repository_rule(
    implementation = _pkg_impl,
    attrs = {
        "mkpkg": attr.label(default = "@//:mkpkg"),
    },
)
