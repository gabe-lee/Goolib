const std = @import("std");
const builtin = @import("builtin");
const Options = @import("../build.zig").Options;

pub fn sub_build(b: *std.Build, goolib: *std.Build.Module, opts: Options) void {
    const breakout_mod = b.addModule("breakout_advanced_shaders", .{
        .optimize = opts.OPTIMIZE,
        .target = opts.TARGET,
        .root_source_file = b.path("samples/BreakoutAdvanced/build_shader_templates.zig"),
    });
    const breakout = b.addExecutable(.{
        .name = "breakout_advanced_shaders",
        .root_module = breakout_mod,
        .use_llvm = opts.USE_LLVM,
    });

    breakout.lto = opts.LINK_TIME_OPTIMIZE;
    breakout.root_module.addImport("Goolib", goolib);
    b.installArtifact(breakout);

    const run_breakout = b.addRunArtifact(breakout);
    run_breakout.addPassthruArgs();
    run_breakout.step.dependOn(b.getInstallStep());

    const run_breakout_cmd = b.step("breakout_advanced_shaders", "Generate the advanced breakout sample shader templates");
    run_breakout_cmd.dependOn(&run_breakout.step);
}
