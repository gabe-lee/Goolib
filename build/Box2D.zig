const std = @import("std");
const builtin = @import("builtin");
const Options = @import("../build.zig").Options;
const translate_c = @import("translate_c");

pub fn sub_build(b: *std.Build, goolib: *std.Build.Module, opts: Options) void {
    if (opts.INCLUDE_BOX2D) {
        const box2d_dep: *std.Build.Dependency = b.dependency("box2d", .{
            .target = opts.TARGET,
            .optimize = opts.OPTIMIZE,
            .shared = opts.PREFERRED_LINKAGE == .dynamic,
            .zig_unit_tests = opts.BOX2D_COMPILE_ZIG_UNIT_TESTS,
            .c_unit_tests = opts.BOX2D_COMPILE_C_UNIT_TESTS,
            .disable_simd = opts.BOX2D_DISABLE_SIMD,
        });
        goolib.addImport("box2d", box2d_dep.module("box2d"));
    }
}
