const std = @import("std");
const builtin = @import("builtin");
const Options = @import("../build.zig").Options;
const translate_c = @import("translate_c");

pub fn sub_build(b: *std.Build, goolib: *std.Build.Module, opts: Options) void {
    if (opts.INCLUDE_SDL) {
        const sdl_dep: *std.Build.Dependency = b.dependency("sdl", .{
            .target = opts.TARGET,
            .optimize = opts.OPTIMIZE,
            .preferred_linkage = opts.PREFERRED_LINKAGE,
            .strip = opts.STRIP_DEBUG,
            .pic = opts.POS_INDEPENDANT_CODE,
            .lto = opts.LINK_TIME_OPTIMIZE,
            .emscripten_pthreads = opts.SDL_EMSCRIPTEN_PTHREADS,
            .install_build_config_h = opts.SDL_INSTALL_BUILD_CONFIG_H,
        });
        const sdl_lib: *std.Build.Step.Compile = sdl_dep.artifact("SDL3");

        const translate_c_dep = b.dependency("translate_c", .{});
        const header_content = b.fmt(
            \\#define SDL_DISABLE_OLD_NAMES
            \\#include <SDL3/SDL.h>
            \\#include <SDL3/SDL_revision.h>
            \\{s}{s}#include <SDL3/SDL_main.h>
        , .{ if (opts.SDL_USER_HANDLES_MAIN) "#define SDL_MAIN_HANDLED\n" else "", if (opts.SDL_USER_PROVIDES_CALLBACKS) "#define SDL_MAIN_USE_CALLBACKS\n" else "" });
        const translator: translate_c.Translator = .init(translate_c_dep, .{
            .c_source_file = b.addWriteFiles().add("sdl3_c.h", header_content),
            .target = opts.TARGET,
            .optimize = opts.OPTIMIZE,
        });
        translator.linkLibrary(sdl_lib);
        goolib.addImport("sdl3_c", translator.mod);

        // goolib.linkLibrary(sdl_lib);
    }
}
