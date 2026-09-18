const std = @import("std");
const builtin = @import("builtin");
const Options = @import("../build.zig").Options;

pub fn sub_build(b: *std.Build, goolib: *std.Build.Module, opts: Options) void {
    const fuzztest_mod = b.addModule("fuzztest", .{
        .optimize = opts.OPTIMIZE,
        .target = opts.TARGET,
        .root_source_file = b.path("src/_fuzz.zig"),
    });
    const fuzztest = b.addExecutable(.{
        .name = "fuzztest",
        .root_module = fuzztest_mod,
        .use_llvm = opts.USE_LLVM,
    });
    fuzztest.root_module.addImport("Goolib", goolib);
    b.installArtifact(fuzztest);

    const run_fuzztest = b.addRunArtifact(fuzztest);
    if (b.args) |args| run_fuzztest.addArgs(args);
    run_fuzztest.step.dependOn(b.getInstallStep());

    const run_fuzztest_cmd = b.step("fuzztest", "Run all (or one) library fuzz tests");
    run_fuzztest_cmd.dependOn(&run_fuzztest.step);
}
