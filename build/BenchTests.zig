const std = @import("std");
const builtin = @import("builtin");
const Options = @import("../build.zig").Options;

pub fn sub_build(b: *std.Build, goolib: *std.Build.Module, opts: Options) void {
    const benchtest_mod = b.addModule("benchtest", .{
        .optimize = opts.OPTIMIZE,
        .target = opts.TARGET,
        .root_source_file = b.path("src/_bench.zig"),
    });
    const benchtest = b.addExecutable(.{
        .name = "benchtest",
        .root_module = benchtest_mod,
        .use_llvm = opts.USE_LLVM,
    });
    benchtest.root_module.addImport("Goolib", goolib);
    b.installArtifact(benchtest);

    const run_benchtest = b.addRunArtifact(benchtest);
    if (b.args) |args| run_benchtest.addArgs(args);
    run_benchtest.step.dependOn(b.getInstallStep());

    const run_benchtest_cmd = b.step("benchtest", "Run all (or one) library bench tests");
    run_benchtest_cmd.dependOn(&run_benchtest.step);
}
