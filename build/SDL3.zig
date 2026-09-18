const std = @import("std");
const builtin = @import("builtin");
const Options = @import("../build.zig").Options;

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
        goolib.linkLibrary(sdl_lib);
    }
}
