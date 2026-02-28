const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // OPTIONS
    const no_sdl = b.option(bool, "no-sdl", "do not include SDL3 when building") orelse false;

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
        std.zig.LtoMode,
        "link_time_optimize",
        "Perform link time optimization (default: varies)",
    ) orelse if (optimize == .Debug) std.zig.LtoMode.none else std.zig.LtoMode.full;
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
    const sdl_gfx_controller_max_storage_registers = b.option(
        u32,
        "sdl_gfx_controller_max_storage_registers",
        "max number of storage registers that can exist in one shader (default: 64)\n\t(# sampled textures + # storage textures + # storage buffers)",
    ) orelse 64;

    const options = b.addOptions();
    options.addOption(bool, "SDL_USER_MAIN", sdl_user_handles_main);
    options.addOption(bool, "SDL_USER_CALLBACKS", sdl_user_provides_callbacks);
    options.addOption(bool, "NO_SDL", no_sdl);
    options.addOption(u32, "SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS", sdl_gfx_controller_max_storage_registers);

    //DEPENDENCIES

    const sdl_dep: *std.Build.Dependency = if (!no_sdl) b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = preferred_linkage,
        .strip = strip_debug,
        .pic = pos_independant_code,
        .lto = link_time_optimize,
        .emscripten_pthreads = sdl_emscripten_pthreads,
        .install_build_config_h = sdl_install_build_config_h,
    }) else undefined;
    const sdl_lib: *std.Build.Step.Compile = if (!no_sdl) sdl_dep.artifact("SDL3") else undefined;

    //MAIN LIBRARY

    const lib = b.addModule("Goolib", .{
        .root_source_file = b.path("src/_root.zig"),
        .target = target,
        .optimize = optimize,
        .pic = pos_independant_code,
        .strip = strip_debug,
        .link_libc = true,
    });
    if (!no_sdl) {
        lib.linkLibrary(sdl_lib);
    }

    lib.addOptions("config", options);

    const lib_tests = b.addTest(.{
        .root_module = lib,
        // A bug in the x86-64 backend affects some parts of this library
        .use_llvm = true,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);

    //FILEGEN
    const filegen_mod = b.addModule("filegen", .{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("srcgen/main.zig"),
    });
    const filegen = b.addExecutable(.{
        .name = "filegen",
        .root_module = filegen_mod,
    });
    filegen.root_module.addImport("Goolib", lib);
    b.installArtifact(filegen);

    const run_filegen = b.addRunArtifact(filegen);
    if (b.args) |args| run_filegen.addArgs(args);
    run_filegen.step.dependOn(b.getInstallStep());

    const run_filegen_cmd = b.step("filegen", "Automatically generate files for the library");
    run_filegen_cmd.dependOn(&run_filegen.step);

    //BREAKOUT SAMPLE APP
    const breakout_mod = b.addModule("breakout", .{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("samples/breakout.zig"),
    });
    const breakout = b.addExecutable(.{
        .name = "breakout",
        .root_module = breakout_mod,
    });
    breakout.want_lto = optimize != .Debug;
    breakout.root_module.addImport("Goolib", lib);
    b.installArtifact(breakout);

    const run_breakout = b.addRunArtifact(breakout);
    if (b.args) |args| run_breakout.addArgs(args);
    run_breakout.step.dependOn(b.getInstallStep());

    const run_breakout_cmd = b.step("breakout", "Run the breakout sample app");
    run_breakout_cmd.dependOn(&run_breakout.step);

    // FUZZ TESTS
    const fuzztest_mod = b.addModule("fuzztest", .{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("src/_fuzz.zig"),
    });
    const fuzztest = b.addExecutable(.{
        .name = "fuzztest",
        .root_module = fuzztest_mod,
    });
    fuzztest.root_module.addImport("Goolib", lib);
    b.installArtifact(fuzztest);

    const run_fuzztest = b.addRunArtifact(fuzztest);
    if (b.args) |args| run_fuzztest.addArgs(args);
    run_fuzztest.step.dependOn(b.getInstallStep());

    const run_fuzztest_cmd = b.step("fuzztest", "Run all (or one) library fuzz tests");
    run_fuzztest_cmd.dependOn(&run_fuzztest.step);

    // BENCH TESTS
    const benchtest_mod = b.addModule("benchtest", .{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("src/_bench.zig"),
    });
    const benchtest = b.addExecutable(.{
        .name = "benchtest",
        .root_module = benchtest_mod,
    });
    benchtest.root_module.addImport("Goolib", lib);
    b.installArtifact(benchtest);

    const run_benchtest = b.addRunArtifact(benchtest);
    if (b.args) |args| run_benchtest.addArgs(args);
    run_benchtest.step.dependOn(b.getInstallStep());

    const run_benchtest_cmd = b.step("benchtest", "Run all (or one) library bench tests");
    run_benchtest_cmd.dependOn(&run_benchtest.step);
}
