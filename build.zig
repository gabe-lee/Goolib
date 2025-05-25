const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // OPTIONS

    const preferred_linkage = b.option(
        std.builtin.LinkMode,
        "preferred_linkage",
        "Prefer building statically or dynamically linked libraries (default: static)",
    ) orelse .static;
    const strip_debug = b.option(
        bool,
        "strip_debug",
        "Strip debug symbols (default: varies)",
    ) orelse (optimize != .Debug);
    const pos_independant_code = b.option(
        bool,
        "pos_independant_code",
        "Produce position-independent code (default: varies)",
    ) orelse true;
    const link_time_optimize = b.option(
        bool,
        "link_time_optimize",
        "Perform link time optimization (default: varies)",
    ) orelse (optimize != .Debug);
    const sdl_emscripten_pthreads = b.option(
        bool,
        "sdl_emscripten_pthreads",
        "Build with pthreads support when targeting Emscripten (default: false)",
    ) orelse false;
    const sdl_install_build_config_h = b.option(
        bool,
        "sdl_install_build_config_h",
        "Additionally install 'SDL_build_config.h' when installing SDL (default: false)",
    ) orelse false;
    const sdl_user_handles_main = b.option(
        bool,
        "sdl_user_handles_main",
        "define `SDL_MAIN_HANDLED` when importing SDL (default: true)",
    ) orelse true;
    const sdl_user_provides_callbacks = b.option(
        bool,
        "sdl_user_provides_callbacks",
        "define `SDL_MAIN_USE_CALLBACKS` when importing SDL (default: false)",
    ) orelse false;

    const options = b.addOptions();
    options.addOption(bool, "SDL_USER_MAIN", sdl_user_handles_main);
    options.addOption(bool, "SDL_USER_CALLBACKS", sdl_user_provides_callbacks);

    //DEPENDENCIES

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = preferred_linkage,
        .strip = strip_debug,
        .pic = pos_independant_code,
        .lto = link_time_optimize,
        .emscripten_pthreads = sdl_emscripten_pthreads,
        .install_build_config_h = sdl_install_build_config_h,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    //MAIN LIBRARY

    const lib = b.addModule("Goolib", .{
        .root_source_file = b.path("src/_root.zig"),
        .target = target,
        .optimize = optimize,
        .pic = pos_independant_code,
        .strip = strip_debug,
    });
    lib.linkLibrary(sdl_lib);

    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/_root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.addOptions("config", options);

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
