const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        // .preferred_linkage = .static,
        //.strip = null,
        //.pic = null,
        .lto = optimize != .Debug,
        //.emscripten_pthreads = false,
        //.install_build_config_h = false,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    const lib = b.addModule("ZigGulag", .{
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
}
