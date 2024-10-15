_FFI_H_DEFAULTS = {
    "FFI_EXEC_TRAMPOLINE_TABLE": "0",
    "HAVE_LONG_DOUBLE": "0",
}

_FFICONFIG_H_DEFAULTS = {
    "HAVE_ALLOCA_H": "1",
    "HAVE_MEMCPY": "1",
    "HAVE_INTTYPES_H": "1",
    "HAVE_STDINT_H": "1",
    "STDC_HEADERS": "1",
}

_FFICONFIG_H_CC_DEFAULTS = {
    "clang": {
        "HAVE_AS_CFI_PSEUDO_OP": "1",
        "HAVE_HIDDEN_VISIBILITY_ATTRIBUTE": "1",
    },
    "gcc": {
        "HAVE_AS_CFI_PSEUDO_OP": "1",
        "HAVE_HIDDEN_VISIBILITY_ATTRIBUTE": "1",
    },
}

_FFICONFIG_H_OS_DEFAULTS = {
    "linux": {
        "HAVE_MEMFD_CREATE": "1",
    },
    "macos": {
        "FFI_EXEC_TRAMPOLINE_TABLE": "1",
    },
}

def _expand_ffi_h(ctx):
    substitutions = {}
    for key, value in _FFI_H_DEFAULTS.items():
        substitutions["@%s@" % (key,)] = value
    substitutions["@VERSION@"] = ctx.attr.version
    for key, value in ctx.attr.substitutions.items():
        substitutions["@%s@" % (key,)] = value
    ctx.actions.expand_template(
        template = ctx.file.template,
        output = ctx.outputs.out,
        substitutions = substitutions,
    )

expand_ffi_h = rule(
    implementation = _expand_ffi_h,
    attrs = {
        "template": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "version": attr.string(
            mandatory = True,
        ),
        "substitutions": attr.string_dict(
            mandatory = True,
        ),
        "out": attr.output(
            mandatory = True,
        ),
    },
)

# vars referenced from source, but not set in x86
"""

closures.c
/* #undef FFI_MMAP_EXEC_WRIT */


"""


def _expand_fficonfig_h(ctx):
    defines = {}
    for key, value in _FFICONFIG_H_DEFAULTS.items():
        defines[key] = value
    cc_defaults = _FFICONFIG_H_CC_DEFAULTS.get(ctx.attr.cc_compiler, {})
    for key, value in cc_defaults.items():
        defines[key] = value
    os_defaults = _FFICONFIG_H_OS_DEFAULTS.get(ctx.attr.os, {})
    for key, value in os_defaults.items():
        defines[key] = value
    for key, value in ctx.attr.substitutions.items():
        defines[key] = value
    defines["VERSION"] = "\"%s\"" % (ctx.attr.version,)

    substitutions = {}
    for key, value in defines.items():
        substitutions["#undef %s\n" % (key,)] = "#define %s %s\n" % (key, value)
    substitutions["#undef "] = "// #undef "
    ctx.actions.expand_template(
        template = ctx.file.template,
        output = ctx.outputs.out,
        substitutions = substitutions,
    )

expand_fficonfig_h = rule(
    implementation = _expand_fficonfig_h,
    attrs = {
        "template": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "version": attr.string(
            mandatory = True,
        ),
        "substitutions": attr.string_dict(
            mandatory = True,
        ),
        "out": attr.output(
            mandatory = True,
        ),
        "cc_compiler": attr.string(
            mandatory = True,
        ),
        "os": attr.string(
            mandatory = True,
        ),
    },
)

def selected(target, attr_name):
    targetdir = target.targetdir
    if attr_name == "target_h":
        return "//src/%s:target_h" % (targetdir,)
    value = getattr(target, attr_name, None)
    if attr_name == "substitutions":
        if value == None:
            fail("fficonfig.h.in substitutions not transcribed yet for target %r" % (target.target,))
            return None
        value["TARGET"] = target.target
        return value
    if attr_name == "srcs":
        return ["//src/%s:%s" % (targetdir, src,) for src in value]
    return value

def select_target_attr(targets, attr_name):
    return select({
        #"@platforms//cpu:arm64": selected(targets["AARCH64"], attr_name),
        "@platforms//cpu:aarch64": selected(targets["AARCH64"], attr_name),
        #"@platforms//cpu:i386": selected(targets["X86"], attr_name),
        #"@platforms//cpu:x86_32": selected(targets["X86"], attr_name),
        "@platforms//cpu:x86_64": selected(targets["X86_64"], attr_name),
    })

def select_cc_compiler():
    return select({
        ":cc_compiler_clang": "clang",
        ":cc_compiler_gcc": "gcc",
        "//conditions:default": "",
    })

def select_os():
    return select({
        "@platforms//os:linux": "linux",
        "@platforms//os:macos": "macos",
        "//conditions:default": "",
    })

def struct_(**kwargs):
    return struct(**kwargs)
