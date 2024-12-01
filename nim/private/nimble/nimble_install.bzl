
def _nimble_install_impl(rctx):
    nimble_bin = rctx.which("nimble") or rctx.os.environ.get("NIMBLE_BIN")
    rctx.symlink(rctx.attr.nimble_file, "file.nimble")

    result = rctx.execute(
        [
            nimble_bin,
            "-y",
            "--nimbleDir:.",
        ] + rctx.attr.nimble_attrs + [
            "install"
        ],
        quiet = rctx.attr.quiet,
    )
    if result.return_code != 0:
        fail("nimble invocation failed with code = '{}' and error message = '{}'".format(result.return_code, result.stderr))

    deps = rctx.path("pkgs2").readdir()

    build_bazel_content = """# generated by nimble_install
load("@rules_nim//nim:defs.bzl", "nim_module")"""

    for dep in deps:
        pkg_fullname = dep.basename
        pkg_name = pkg_fullname.split("-")[0]

        lib_target = """
nim_module(
    name = "{pkg_name}",
    srcs = glob(["{pkgs_dir_prefix}/{pkg_fullname}/**/*"]),
    strip_import_prefix = "{pkgs_dir_prefix}/{pkg_fullname}",
    visibility = ["//visibility:public"],
)
""".format(
       pkgs_dir_prefix = rctx.attr.pkgs_dir_prefix,
       pkg_name = pkg_name,
       pkg_fullname = pkg_fullname,
    )
        build_bazel_content += lib_target

    rctx.file("BUILD.bazel", build_bazel_content, executable = False)

nimble_install = repository_rule(
    attrs = {
        "nimble_file": attr.label(),
        "nimble_attrs": attr.string_list(default = ["--noLockFile"]),
        "quiet": attr.bool(default = False),
        "pkgs_dir_prefix": attr.string(default = "pkgs2")
    },
    implementation = _nimble_install_impl,
    doc = """
    Runs `nimble install` on `nimble_file` attribute which brings dependencies into the scope.
    CAUTION: Such a simple wrapper around `nimble` invocation comes with a cost of omitting Bazel's
    repository cache. Therefore it is suggested to generate `nimble.lock` file and then use `nimble_lock`
    repository rule (with the appropriate `nimble_lock_update` target). See `numericalnim` e2e example.
    """
)

