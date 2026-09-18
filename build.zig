const std = @import("std");
const builtin = @import("builtin");
const BreakoutApp = @import("./build/Breakout.zig");
const LayoutApp = @import("./build/Layout.zig");
const SDL3 = @import("./build/SDL3.zig");
const FuzzTests = @import("./build/FuzzTests.zig");
const BenchTests = @import("./build/BenchTests.zig");
const Tests = @import("./build/Tests.zig");
const FORCE_USE_LLVM: bool = false;

pub const Options = struct {
    TARGET: std.Build.ResolvedTarget,
    OPTIMIZE: std.builtin.OptimizeMode,
    USE_LLVM: bool,
    INCLUDE_SDL: bool,
    LINK_TIME_OPTIMIZE: std.zig.LtoMode,
    PREFERRED_LINKAGE: std.builtin.LinkMode,
    STRIP_DEBUG: bool,
    POS_INDEPENDANT_CODE: bool,
    SDL_EMSCRIPTEN_PTHREADS: bool,
    SDL_INSTALL_BUILD_CONFIG_H: bool,
    SDL_USER_HANDLES_MAIN: bool,
    SDL_USER_PROVIDES_CALLBACKS: bool,
    SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS: u32,
};

pub const OptionsInLib = struct {
    USE_LLVM: bool,
    INCLUDE_SDL: bool,
    SDL_EMSCRIPTEN_PTHREADS: bool,
    SDL_INSTALL_BUILD_CONFIG_H: bool,
    SDL_USER_HANDLES_MAIN: bool,
    SDL_USER_PROVIDES_CALLBACKS: bool,
    SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS: u32,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // OPTIONS
    const opts = Options{
        .TARGET = target,
        .OPTIMIZE = optimize,
        .USE_LLVM = FORCE_USE_LLVM or b.option(bool, "use-llvm", "use the LLVM compiler instead of the native x86-64 compiler (default: .Debug = false, .Release___ = true)") orelse if (optimize == .Debug) false else true,
        .INCLUDE_SDL = b.option(bool, "include-sdl", "include SDL3 when building (default: true)") orelse true,
        .PREFERRED_LINKAGE = b.option(std.builtin.LinkMode, "preferred-linkage", "Prefer building statically or dynamically linked libraries (default: static)") orelse .static,
        .STRIP_DEBUG = b.option(bool, "strip-debug", "Strip debug symbols (default: varies)") orelse (optimize != .Debug),
        .POS_INDEPENDANT_CODE = b.option(bool, "pos-independant-code", "Produce position-independent code (default: varies)") orelse true,
        .LINK_TIME_OPTIMIZE = b.option(std.zig.LtoMode, "link-time-optimize", "Perform link time optimization (default: varies)") orelse if (optimize == .Debug) std.zig.LtoMode.none else std.zig.LtoMode.full,
        .SDL_EMSCRIPTEN_PTHREADS = b.option(bool, "sdl-emscripten-pthreads", "Build with pthreads support when targeting Emscripten (default: false)") orelse false,
        .SDL_INSTALL_BUILD_CONFIG_H = b.option(bool, "sdl-install-build-config-h", "Additionally install 'SDL_build_config.h' when installing SDL (default: false)") orelse false,
        .SDL_USER_HANDLES_MAIN = b.option(bool, "sdl-user-handles-main", "define `SDL_MAIN_HANDLED` when importing SDL (default: true)") orelse true,
        .SDL_USER_PROVIDES_CALLBACKS = b.option(bool, "sdl-user-provides-callbacks", "define `SDL_MAIN_USE_CALLBACKS` when importing SDL (default: false)") orelse false,
        .SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS = b.option(u32, "sdl-gfx-controller-max-storage-registers", "max number of storage registers that can exist in one shader (default: 64)\n\t(# sampled textures + # storage textures + # storage buffers)") orelse 64,
    };

    const opts_in_lib = OptionsInLib{
        .INCLUDE_SDL = opts.INCLUDE_SDL,
        .SDL_EMSCRIPTEN_PTHREADS = opts.SDL_EMSCRIPTEN_PTHREADS,
        .SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS = opts.SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS,
        .SDL_INSTALL_BUILD_CONFIG_H = opts.SDL_INSTALL_BUILD_CONFIG_H,
        .SDL_USER_HANDLES_MAIN = opts.SDL_USER_HANDLES_MAIN,
        .SDL_USER_PROVIDES_CALLBACKS = opts.SDL_USER_PROVIDES_CALLBACKS,
        .USE_LLVM = opts.USE_LLVM,
    };

    const code_options = b.addOptions();
    code_options.addOption(OptionsInLib, "OPTS", opts_in_lib);

    const LIBC = opts.INCLUDE_SDL;

    //MAIN LIBRARY
    const goolib = b.addModule("Goolib", .{
        .root_source_file = b.path("src/_root.zig"),
        .target = target,
        .optimize = optimize,
        .pic = opts.POS_INDEPENDANT_CODE,
        .strip = opts.STRIP_DEBUG,
        .link_libc = LIBC,
    });

    goolib.addOptions("config", code_options);

    //OPTIONAL DEPENDANCIES
    SDL3.sub_build(b, goolib, opts);

    //SAMPLE APPS
    BreakoutApp.sub_build(b, goolib, opts);
    LayoutApp.sub_build(b, goolib, opts);

    //TESTING PROGRAMS
    Tests.sub_build(b, goolib, opts);
    BenchTests.sub_build(b, goolib, opts);
    FuzzTests.sub_build(b, goolib, opts);
}
