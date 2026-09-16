const std = @import("std");
const builtin = @import("builtin");

pub fn sub_build(b: *std.Build, goolib: *std.Build.Module, sdl3_dep: *std.Build.Dependency, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, opts: anytype) void {
    const shadercross_dep = b.dependency("sdl_shadercross", .{
        .target = target,
        .optimize = optimize,
    });

    // 2. Create a static library build step for SDL_shadercross
    const shadercross_lib = b.addLibrary(.{
        .name = "SDL3_shadercross",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // 3. Add shadercross include paths and source files
    // (Depending on your exact version of SDL_shadercross, check if source files
    // reside in src/. Adjust path blocks as necessary)
    shadercross_lib.root_module.addIncludePath(shadercross_dep.path("include"));

    // Add necessary C source files.
    // SDL_shadercross typically has core source files in src/
    shadercross_lib.root_module.addCSourceFiles(.{
        .dependency = shadercross_dep,
        .files = &.{
            shadercross_dep.path("src/SDL_shadercross.c"),
        },
        // .flags = &.{
        //     "-DSHADERCROSS_XINPUT=0", // Adjust flags if necessary
        // },
    });

    // 4. IMPORTANT: SDL_shadercross depends on SDL3 headers and library.
    // If you have SDL3 as a dependency (e.g., named "sdl3"):
    // const sdl3_dep = b.dependency("sdl3", .{ .target = target, .optimize = optimize });
    shadercross_lib.linkLibrary(sdl3_dep.artifact("SDL3"));
    // shadercross_lib.addIncludePath(sdl3_dep.artifact("SDL3").getEmittedIncludeDirectory());

    // 5. Install the shadercross artifact
    b.installArtifact(shadercross_lib);

    // 6. Link it to your main executable
    const exe = b.addExecutable(.{
        .name = "my_game",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link shadercross and C to your executable
    exe.linkLibrary(shadercross_lib);
    exe.linkLibC();

    // Make shadercross headers available to your project if writing raw C/Zig interop
    exe.root_module.addIncludePath(shadercross_dep.path("include"));

    b.installArtifact(exe);

    // Optional run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
