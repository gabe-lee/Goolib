const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //DEPENDENCIES

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = .static,
        //.strip = null,
        //.pic = null,
        .lto = optimize != .Debug,
        //.emscripten_pthreads = false,
        //.install_build_config_h = false,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    //MAIN LIBRARY

    const lib = b.addModule("Goolib", .{
        .root_source_file = b.path("src/_root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibrary(sdl_lib);

    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/_root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);

    //BREAKOUT SAMPLE APP
    const breakout = b.addExecutable(.{
        .target = target,
        .optimize = optimize,
        .name = "breakout",
        .root_source_file = b.path("samples/breakout.zig"),
    });
    breakout.want_lto = optimize != .Debug;
    breakout.root_module.addImport("Goolib", lib);
    b.installArtifact(breakout);

    const run_breakout = b.addRunArtifact(breakout);
    if (b.args) |args| run_breakout.addArgs(args);
    run_breakout.step.dependOn(b.getInstallStep());

    const run_breakout_cmd = b.step("breakout", "Run the breakout sample app");
    run_breakout_cmd.dependOn(&run_breakout.step);
}
