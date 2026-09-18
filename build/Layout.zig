const std = @import("std");
const builtin = @import("builtin");
const Options = @import("../build.zig").Options;

pub fn sub_build(b: *std.Build, goolib: *std.Build.Module, opts: Options) void {
    const layout_mod = b.addModule("layout", .{
        .optimize = opts.OPTIMIZE,
        .target = opts.TARGET,
        .root_source_file = b.path("samples/layout.zig"),
    });
    const layout = b.addExecutable(.{
        .name = "layout",
        .root_module = layout_mod,
        .use_llvm = opts.USE_LLVM,
    });
    layout.lto = opts.LINK_TIME_OPTIMIZE;
    layout.root_module.addImport("Goolib", goolib);
    b.installArtifact(layout);

    const run_layout = b.addRunArtifact(layout);
    if (b.args) |args| run_layout.addArgs(args);
    run_layout.step.dependOn(b.getInstallStep());

    const run_layout_cmd = b.step("layout", "Run the immediate-mode layout sample app");
    run_layout_cmd.dependOn(&run_layout.step);
}
