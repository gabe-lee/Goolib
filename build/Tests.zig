const std = @import("std");
const builtin = @import("builtin");
const Options = @import("../build.zig").Options;

pub fn sub_build(b: *std.Build, goolib: *std.Build.Module, opts: Options) void {
    const lib_tests = b.addTest(.{
        .root_module = goolib,
        .test_runner = .{ .path = b.path("testrunner_src/test_runner.zig"), .mode = .simple },
        .use_llvm = opts.USE_LLVM,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);
}
