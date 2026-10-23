//! A simple Breakout clone using Goolib, SDL3, and the Castholm SDL3 wrapper,
//! and using the more advanced Goolib helper systems:
//!   - GraphicsController
//! #### Note
//! This code sample is heavily derived from the Breakout sample provided by the castholm SDL3 wrapper
//! under the MIT License (https://github.com/castholm/zig-examples/blob/master/LICENSES/MIT.txt).
//! Sprites and sounds are transitively licensed from [kenney.nl game assets](https://kenney.nl/assets)
//! under the CC0-1.0 license (https://kenney.nl/assets/interface-sounds), (https://kenney.nl/assets/puzzle-pack-1)
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.

const std = @import("std");
const build = @import("builtin");

const sdl_log = std.log.scoped(.sdl);
const app_log = std.log.scoped(.app);

const Goolib = @import("Goolib");
const SDL = Goolib.SDL3;
const AABB = Goolib.AABB2.define_aabb2_type(f32);
const Rect = Goolib.Rect2.define_rect2_type(f32);
const FVec: type = SDL.Vec_f32;
const IVec: type = SDL.Vec_c_int;
const Cast = Goolib.Cast;
const c_strings_equal = Goolib.Utils.c_strings_equal;
const ANSI = Goolib.ANSI;
const ListSlice = Goolib.ListSlice;
const ListU16 = ListSlice.ListFullDefinition(u16, u16, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
const ListFVec = ListSlice.ListFullDefinition(FVec, u16, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
const ListU32 = ListSlice.ListFullDefinition(u32, u16, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
const Allocator = std.mem.Allocator;
const alloc = std.heap.smp_allocator;

const GraphicsModule = @import("./breakout_graphics.zig");
const GraphicsControllerModule = Goolib.SDL3.GraphicsController;
const ShaderCode = GraphicsControllerModule.ShaderCode;
const GraphicsController = GraphicsModule.Controller;
const AnyGPUBuffer = GraphicsController.AnyGPUBuffer;
const BlitInfo = GraphicsController.BlitInfo;
const BlitRegion = GraphicsController.BlitRegion;
const BufferLocation = GraphicsController.BufferLocation;
const BufferRegion = GraphicsController.BufferRegion;
const ColorTarget = GraphicsController.ColorTarget;
const CommandBuffer = GraphicsController.CommandBuffer;
const CopyDownloadDetails = GraphicsController.CopyDownloadDetails;
const CopyUploadDetails = GraphicsController.CopyUploadDetails;
const CreateOptions = GraphicsController.CreateOptions;
const DeleteBufferDetails = GraphicsController.DeleteBufferDetails;
const DepthTarget = GraphicsController.DepthTarget;
const DownloadBufferInit = GraphicsController.DownloadBufferInit;
const DownloadBufferName = GraphicsController.DownloadBufferName;
const DownloadPass = GraphicsController.DownloadPass;
const DownloadTransferBufferLocation = GraphicsController.DownloadTransferBufferLocation;
const Fence = GraphicsController.Fence;
const FenceName = GraphicsController.FenceName;
const FragmentShaderInit = GraphicsController.FragmentShaderInit;
const FragmentShaderName = GraphicsController.FragmentShaderName;
const GPUAssetRegion = GraphicsController.GPUAssetRegion;
const GrowAndCopyDownloadTransferDetails = GraphicsController.GrowAndCopyDownloadTransferDetails;
const GrowAndCopyGPUBufferDetails = GraphicsController.GrowAndCopyGPUBufferDetails;
const IndexBufferInit = GraphicsController.IndexBufferInit;
const IndexBufferName = GraphicsController.IndexBufferName;
const IndirectDrawBufferInit = GraphicsController.IndirectDrawBufferInit;
const IndirectDrawBufferName = GraphicsController.IndirectDrawBufferName;
const QueuedDownloadCopy = GraphicsController.QueuedDownloadCopy;
const RenderPass = GraphicsController.RenderPass;
const RenderPipeInit = GraphicsController.RenderPipeInit;
const RenderPipelineName = GraphicsController.RenderPipelineName;
const SamplerInit = GraphicsController.SamplerInit;
const SamplerName = GraphicsController.SamplerName;
const StorageBufferInit = GraphicsController.StorageBufferInit;
const StorageBufferName = GraphicsController.StorageBufferName;
const Target = GraphicsController.Target;
const TextureDownloadInfo = GraphicsController.TextureDownloadInfo;
const TextureInit = GraphicsController.TextureInit;
const TextureLocation = GraphicsController.TextureLocation;
const TextureRegion = GraphicsController.TextureRegion;
const TextureUploadInfo = GraphicsController.TextureUploadInfo;
const UniformCollection = GraphicsController.UniformCollection;
const UniformName = GraphicsController.UniformName;
const UploadBufferInit = GraphicsController.UploadBufferInit;
const UploadBufferName = GraphicsController.UploadBufferName;
const UploadPass = GraphicsController.UploadPass;
const UploadTransferBufferLocation = GraphicsController.UploadTransferBufferLocation;
const VertexBufferBindingOffset = GraphicsController.VertexBufferBindingOffset;
const VertexBufferInit = GraphicsController.VertexBufferInit;
const VertexBufferName = GraphicsController.VertexBufferName;
const VertexShaderInit = GraphicsController.VertexShaderInit;
const VertexStructName = GraphicsController.VertexStructName;
const WindowInit = GraphicsController.WindowInit;
const WindowName = GraphicsController.WindowName;

const best_score_storage_org_name = "goolib_samples";
const best_score_storage_app_name = "breakout_advanced";
const records_storage_file_name = "records";
const attempts_storage_file_name = "attempts";
const window_size: IVec = IVec.new(640, 480);

const WindowFlags = SDL.WindowFlags.Flag;
const DEBUG = std.debug.print;
const DEBUG_VAL = Goolib.Utils.DebugPrint.debug_val;
const DEBUG_VAL_ADV = Goolib.Utils.DebugPrint.debug_val_advanced;

const assert_with_reason = Goolib.Assert.assert_with_reason;

const AppState = struct {
    graphics: GraphicsController = undefined,
    timekeeper: Timekeeper = undefined,
    fully_initialized: bool = false,
    sounds: SDL.WaveAudio = undefined,
    audio_device: SDL.AudioDeviceID = undefined,
    audio_streams_buf: [8]*SDL.AudioStream = undefined,
    audio_streams: []*SDL.AudioStream = undefined, //audio_streams_buf[0..0],
    gamepad: ?*SDL.Gamepad = undefined,
    phys_controller: PhysicalControllerState = undefined,
    prev_phys_controller: PhysicalControllerState = undefined,
    virtual_controller: VirtualControllerState = undefined,
    prev_virtual_controller: VirtualControllerState = undefined,
    best_win: u32 = undefined,
    app_err: ErrorStore = .{},
    paddle: Paddle = undefined,
    ball: Ball = undefined,
    bricks: BoundedArray(Brick, 100) = undefined,
    won: bool = false,
    records_need_save: bool = false,
    score: u32 = undefined,
    score_color: SDL.Color_RGBA_u8 = undefined,
    attempts: u32 = 0,
    index_buffer: ListU16 = .{},
    position_buffer: ListFVec = .{},
    sprite_idx_buffer: ListU32 = .{},
    validate_index_buffer: ListU16 = .{},
    validate_position_buffer: ListFVec = .{},
    validate_sprite_idx_buffer: ListU32 = .{},

    pub fn clear_vert_buffers(self: *AppState) void {
        self.index_buffer.clear();
        self.position_buffer.clear();
        self.sprite_idx_buffer.clear();
    }
    pub fn append_vertices(self: *AppState, rect: Rect, sprite: Sprites.Sprite_, alloc_: Allocator) void {
        self.index_buffer.grow_capacity_if_needed_for_n_more_elems(6, .GROW_BY_25_PERCENT, alloc_);
        self.position_buffer.grow_capacity_if_needed_for_n_more_elems(4, .GROW_BY_25_PERCENT, alloc_);
        self.sprite_idx_buffer.grow_capacity_if_needed_for_n_more_elems(4, .GROW_BY_25_PERCENT, alloc_);
        const vert_start: u16 = self.position_buffer.get_len();
        self.position_buffer.append_many_assume_cap(ListFVec.SliceConst.from_slice_const_keep_data(&.{
            rect.top_left(),
            rect.top_right(),
            rect.bot_left(),
            rect.bot_right(),
        }));
        self.sprite_idx_buffer.append_many_assume_cap(ListU32.SliceConst.from_slice_const_keep_data(&.{
            sprite.vert_index(.TOP_LEFT),
            sprite.vert_index(.TOP_RIGHT),
            sprite.vert_index(.BOT_LEFT),
            sprite.vert_index(.BOT_RIGHT),
        }));
        self.index_buffer.append_many_assume_cap(ListU16.SliceConst.from_slice_const_keep_data(&.{
            vert_start, vert_start + 2, vert_start + 1, // top-left triangle
            vert_start + 1, vert_start + 2, vert_start + 3, // bot-right triangle
        }));
    }
};
var app = AppState{};

pub fn main() !u8 {
    app.app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(SDL.App.run_app(empty_argv.len, @ptrCast(&empty_argv), sdl_main_func))));
    return app.app_err.load() orelse status;
}

pub fn app_init(app_opq: ?*?*anyopaque, arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) anyerror!SDL.AppResult {
    app_opq.?.* = @ptrCast(&app);
    _ = arg_count;
    _ = arg_list;

    var write_buf = BoundedArray(u8, 250){};

    sdl_log.debug("SDL build time version: {d}.{d}.{d}", .{
        SDL.Meta.BUILD_MAJOR_VERSION,
        SDL.Meta.BUILD_MINOR_VERSION,
        SDL.Meta.BUILD_MICRO_VERSION,
    });
    sdl_log.debug("SDL build time revision: {s}", .{SDL.Meta.BUILD_REVISION});
    {
        const version = SDL.Meta.runtime_version();
        sdl_log.debug("SDL runtime version: {d}.{d}.{d}", .{
            SDL.Meta.RUNTIME_MAJOR_VERSION(version),
            SDL.Meta.RUNTIME_MINOR_VERSION(version),
            SDL.Meta.RUNTIME_MICRO_VERSION(version),
        });
        const revision: [*:0]const u8 = SDL.Meta.runtime_revision();
        sdl_log.debug("SDL runtime revision: {s}", .{revision});
    }

    try SDL.App.set_metadata("Breakout Sample", "0.0.0", "goolib.sample.breakout");
    try SDL.App.init(SDL.InitFlags.from_flags(&.{ .VIDEO, .AUDIO, .GAMEPAD }));
    write_buf.clear();
    sdl_log.debug("SDL video drivers: {s}", .{try fmt_sdl_drivers(
        &write_buf,
        try SDL.Video.get_current_video_driver(),
        SDL.Video.get_num_video_drivers(),
        SDL.Video.get_video_driver,
    )});
    write_buf.clear();
    sdl_log.debug("SDL audio drivers: {s}", .{try fmt_sdl_drivers(
        &write_buf,
        try SDL.Audio.get_current_audio_driver(),
        SDL.Audio.get_num_audio_drivers(),
        SDL.Audio.get_audio_driver,
    )});

    SDL.App.set_hint(SDL.HINT.RENDER_VSYNC, "1") catch {};

    const rgba_bmp_surface = make: {
        const bmp_stream = try SDL.IOStream.from_const_mem(Sprites.bmp[0..]);
        const bmp_surface = try SDL.Surface.load_from_bmp_iostream(bmp_stream, true);
        const rgba_bmp_surface = try bmp_surface.convert_to_format(.RGBA_32);
        bmp_surface.destroy();
        break :make rgba_bmp_surface;
    };

    app.graphics = try GraphicsController.create(.{
        .vertex_shaders = .{
            VertexShaderInit{
                .name = .MAIN_VERTEX_SHADER,
                .code = switch (build.os.tag) {
                    .linux => ShaderCode.spirv_format(@embedFile("./vert_MAIN_VERTEX_SHADER.spv"), "main"),
                    .windows => ShaderCode.dxil_format(@embedFile("./vert_MAIN_VERTEX_SHADER.dxil"), "main"),
                    .macos => ShaderCode.msl_format(@embedFile("./vert_MAIN_VERTEX_SHADER.msl"), "main"),
                    else => ShaderCode.spirv_format(@embedFile("./vert_MAIN_VERTEX_SHADER.spv"), "main"),
                },
            },
        },
        .fragment_shaders = .{
            FragmentShaderInit{
                .name = .MAIN_FRAGMENT_SHADER,
                .code = switch (build.os.tag) {
                    .linux => ShaderCode.spirv_format(@embedFile("./frag_MAIN_FRAGMENT_SHADER.spv"), "main"),
                    .windows => ShaderCode.dxil_format(@embedFile("./frag_MAIN_FRAGMENT_SHADER.dxil"), "main"),
                    .macos => ShaderCode.msl_format(@embedFile("./frag_MAIN_FRAGMENT_SHADER.msl"), "main"),
                    else => ShaderCode.spirv_format(@embedFile("./frag_MAIN_FRAGMENT_SHADER.spv"), "main"),
                },
            },
        },
        .uniforms_init = UniformCollection{
            .WINDOW_RENDER_INFO = .init(.{
                .target_size = FVec.new_any(window_size.x, window_size.y),
                .camera_offset = FVec.new_any(0, 0),
            }),
        },
        .render_pipeline_init = &.{
            RenderPipeInit{
                .name = .MAIN_PIPELINE,
            },
        },
        .init_windows = &.{
            WindowInit{
                .name = .MAIN,
                .claim_on_init = true,
                .size = window_size,
                .title = "Breakout Sample Advanced",
                .flags = .flags(&.{
                    WindowFlags.RESIZABLE,
                }),
            },
        },
        .init_samplers = &.{
            SamplerInit{
                .name = .PIXEL_SAMPLER,
                .settings = .DEFAULT,
            },
        },
        .init_storage_buffers = &.{
            StorageBufferInit{
                .name = .SPRITE_VERTEX_DATA,
                .max_element_count = 14 * 4,
            },
        },
        .init_textures = &.{
            TextureInit{
                .name = .SPRITE_TEX,
                .width = @intCast(rgba_bmp_surface.size.x),
                .height = @intCast(rgba_bmp_surface.size.y),
            },
        },
        .init_upload_buffers = &.{
            UploadBufferInit{
                .name = .MAIN_UPLOAD_BUFFER,
                .max_byte_size = 128000,
            },
        },
        .init_download_buffers = &.{
            DownloadBufferInit{
                .name = .MAIN_DOWNLOAD_BUFFER,
                .max_byte_size = 128000,
            },
        },
        .init_index_buffers = &.{
            IndexBufferInit{
                .name = .VERT_INDEXES,
                .max_indices = 512,
            },
        },
        .init_vertex_buffers = &.{
            VertexBufferInit{
                .name = .VERTEX_POSITIONS,
                .max_element_count = 512,
            },
            VertexBufferInit{
                .name = .SPRITE_VERTEX_INDEXES,
                .max_element_count = 512,
            },
        },
        .internal_lists_alloc = std.heap.smp_allocator,
    });
    errdefer app.graphics.destroy();

    write_buf.clear();
    sdl_log.debug("SDL render drivers: {s}", .{try fmt_sdl_drivers(
        &write_buf,
        try app.graphics.gpu.get_driver_name(),
        SDL.GPU_Device.get_num_drivers(),
        SDL.GPU_Device.get_driver_name_by_index,
    )});
    {
        const verify_rgba_surface = try rgba_bmp_surface.duplicate();
        defer verify_rgba_surface.destroy();
        var verify_sprite_data: [Sprites.tex_coords.len]GraphicsModule.SpriteData = undefined;
        const upload: UploadPass = app.graphics.begin_upload_pass();
        try upload.upload_to_texture_no_type_check(.SPRITE_TEX, .new(0, 0, 0), .new(@intCast(rgba_bmp_surface.size.x), @intCast(rgba_bmp_surface.size.y), 1), 0, 0, .MAIN_UPLOAD_BUFFER, rgba_bmp_surface.pixel_byte_slice());
        try upload.upload_to_storage_buffer_no_type_check(.SPRITE_VERTEX_DATA, 0, .MAIN_UPLOAD_BUFFER, Sprites.tex_coords[0..]);
        const command: CommandBuffer = try upload.end_upload_pass_and_start_command_buffer(true);
        const download: DownloadPass = try command.begin_download_pass();
        _ = try download.download_from_texture_no_type_check(.SPRITE_TEX, .new(0, 0, 0), .new(@intCast(rgba_bmp_surface.size.x), @intCast(rgba_bmp_surface.size.y), 1), 0, 0, .MAIN_DOWNLOAD_BUFFER, verify_rgba_surface.pixel_byte_slice());
        _ = try download.download_from_storage_buffer(.SPRITE_VERTEX_DATA, 0, @intCast(Sprites.tex_coords.len), .MAIN_DOWNLOAD_BUFFER, verify_sprite_data[0..]);
        try download.end_download_pass_submit_command_buffer_and_immedieately_wait_on_fence_to_complete_downloads();
        assert_with_reason(std.mem.eql(u8, rgba_bmp_surface.pixel_byte_slice(), verify_rgba_surface.pixel_byte_slice()), @src(), "tex data did not transfer correctly", .{});
        assert_with_reason(std.mem.eql(u8, std.mem.sliceAsBytes(verify_sprite_data[0..]), std.mem.sliceAsBytes(Sprites.tex_coords[0..])), @src(), "sprite data did not transfer correctly", .{});
    }
    {
        const stream = try SDL.IOStream.from_const_mem(Sounds.wav[0..Sounds.wav.len]);
        app.sounds = try stream.load_wav(true);
        errdefer comptime unreachable;
    }
    errdefer app.sounds.destroy();

    app.audio_device = try SDL.AudioDeviceID.DEFAULT_PLAYBACK_DEVICE.open_device(.spec(&app.sounds.spec));
    errdefer app.audio_device.close();

    app.audio_streams = app.audio_streams_buf[0..0];
    errdefer while (app.audio_streams.len != 0) {
        app.audio_streams[app.audio_streams.len - 1].destroy();
        if (app.audio_streams.len != 0) app.audio_streams.len -= 1;
    };
    while (app.audio_streams.len < app.audio_streams_buf.len) {
        app.audio_streams.len += 1;
        app.audio_streams[app.audio_streams.len - 1] = try SDL.AudioStream.create(.same_input_and_output(&app.sounds.spec));
    }

    try app.audio_device.bind_many_audio_streams(app.audio_streams);

    {
        const gamepads_list = try SDL.JoystickID.get_all_gamepads();
        defer gamepads_list.free();

        app.gamepad = if (gamepads_list.list.len > 0) try gamepads_list.list[0].open_gamepad() else null;
    }
    errdefer if (app.gamepad) |pad| pad.close();

    app.phys_controller = .{};
    app.prev_phys_controller = app.phys_controller;
    app.virtual_controller = .{};
    app.prev_virtual_controller = app.virtual_controller;

    try load_records();

    app.timekeeper = .{ .tocks_per_s = SDL.Time.get_performance_frequency() };

    try reset_game();

    app.fully_initialized = true;
    errdefer comptime unreachable;

    // const pos_type = GraphicsModule.VertexIn.SlotType(.VERTEX_POSITIONS);
    // const pos_val: pos_type = std.mem.zeroes(pos_type);
    // DEBUG_VAL_ADV("position type", pos_val, 16, .TYPE_NAME_NO_GENERICS, .TOTAL_OFFSET);

    return SDL.AppResult.CONTINUE;
}

const Sprite = Sprites.Sprite_;
const Sprites = struct {
    const bmp = @embedFile("sprites.bmp");

    // zig fmt: off
    const Sprite_ = enum(u32) {
        brick_2x1_purple,
        brick_1x1_purple,
        brick_2x1_red,
        brick_1x1_red,
        brick_2x1_yellow,
        brick_1x1_yellow,
        brick_2x1_green,
        brick_1x1_green,
        brick_2x1_blue,
        brick_1x1_blue,
        brick_2x1_gray,
        brick_1x1_gray,
        ball,
        paddle,

        pub fn vert_index(sprite: Sprite_, corner: Corner) u32 {
            return (@intFromEnum(sprite) * 4) + @intFromEnum(corner);
        }

        pub fn pos(sprite: Sprite_) FVec {
            return rects[@intFromEnum(sprite)].pos;
        }

        pub fn size(sprite: Sprite_) FVec {
            return rects[@intFromEnum(sprite)].size;
        }
        pub fn top_left(sprite: Sprite_) FVec {
            return rects[@intFromEnum(sprite)].top_left();
        }
        pub fn top_right(sprite: Sprite_) FVec {
            return rects[@intFromEnum(sprite)].top_right();
        }
        pub fn bot_left(sprite: Sprite_) FVec {
            return rects[@intFromEnum(sprite)].bot_left();
        }
        pub fn bot_right(sprite: Sprite_) FVec {
            return rects[@intFromEnum(sprite)].bot_right();
        }
    };
    const tex_dimensions = FVec.new(200, 128);
    const rects = [_]Rect{
        Rect{ .pos = .{.x =   1, .y =  1}, .size = .{.x = 64, .y = 32} },
        Rect{ .pos = .{.x =  67, .y =  1}, .size = .{.x = 32, .y = 32} },
        Rect{ .pos = .{.x = 101, .y =  1}, .size = .{.x = 64, .y = 32} },
        Rect{ .pos = .{.x = 167, .y =  1}, .size = .{.x = 32, .y = 32} },
        Rect{ .pos = .{.x =   1, .y = 35}, .size = .{.x = 64, .y = 32} },
        Rect{ .pos = .{.x =  67, .y = 35}, .size = .{.x = 32, .y = 32} },
        Rect{ .pos = .{.x = 101, .y = 35}, .size = .{.x = 64, .y = 32} },
        Rect{ .pos = .{.x = 167, .y = 35}, .size = .{.x = 32, .y = 32} },
        Rect{ .pos = .{.x =   1, .y = 69}, .size = .{.x = 64, .y = 32} },
        Rect{ .pos = .{.x =  67, .y = 69}, .size = .{.x = 32, .y = 32} },
        Rect{ .pos = .{.x = 101, .y = 69}, .size = .{.x = 64, .y = 32} },
        Rect{ .pos = .{.x = 167, .y = 69}, .size = .{.x = 32, .y = 32} },
        Rect{ .pos = .{.x =  2, .y = 104}, .size = .{.x =  22, .y = 22} },
        Rect{ .pos = .{.x = 27, .y = 103}, .size = .{.x = 104, .y = 24} },
    };
    const tex_coords = [_]GraphicsModule.SpriteData{
        .init(.{.texture_uv = Sprite_.brick_2x1_purple.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_purple.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_purple.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_purple.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_1x1_purple.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_purple.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_purple.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_purple.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_2x1_red.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_red.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_red.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_red.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_1x1_red.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_red.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_red.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_red.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_2x1_yellow.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_yellow.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_yellow.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_yellow.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_1x1_yellow.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_yellow.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_yellow.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_yellow.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_2x1_green.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_green.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_green.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_green.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_1x1_green.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_green.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_green.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_green.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_2x1_blue.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_blue.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_blue.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_blue.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_1x1_blue.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_blue.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_blue.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_blue.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_2x1_gray.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_gray.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_gray.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_2x1_gray.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.brick_1x1_gray.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_gray.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_gray.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.brick_1x1_gray.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.ball.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.ball.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.ball.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.ball.bot_right().divide(tex_dimensions)}),

        .init(.{.texture_uv = Sprite_.paddle.top_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.paddle.top_right().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.paddle.bot_left().divide(tex_dimensions)}),
        .init(.{.texture_uv = Sprite_.paddle.bot_right().divide(tex_dimensions)}),
    };
    
    const Corner = enum(u32) {
        TOP_LEFT,
        TOP_RIGHT,
        BOT_LEFT,
        BOT_RIGHT,
    };
    // zig fmt: on
};

const ErrorStore = struct {
    const STATUS_NOT_STORED = 0;
    const STATUS_STORING = 1;
    const STATUS_STORED = 2;

    status: SDL.AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    fn reset(es: *ErrorStore) void {
        _ = es.status.set(STATUS_NOT_STORED);
    }

    fn store(es: *ErrorStore, err: anyerror) SDL.AppResult {
        if (es.status.compare_and_swap(STATUS_NOT_STORED, STATUS_STORING)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = es.status.set(STATUS_STORED);
        }
        return SDL.AppResult.CLOSE_ERROR;
    }

    fn load(es: *ErrorStore) ?anyerror {
        if (es.status.get() != STATUS_STORED) return null;
        if (@errorReturnTrace()) |dst_trace| {
            dst_trace.index = es.trace_index;
            const len = @min(dst_trace.instruction_addresses.len, es.trace_addrs.len);
            @memcpy(dst_trace.instruction_addresses[0..len], es.trace_addrs[0..len]);
        }
        return es.err;
    }
};

const Sounds = struct {
    const wav = @embedFile("sounds.wav");

    // zig fmt: off
    const hit_wall   = [2]comptime_int{      0,  4_886 };
    const hit_paddle = [2]comptime_int{  4_886, 17_165 };
    const hit_brick  = [2]comptime_int{ 17_165, 25_592 };
    const win        = [2]comptime_int{ 25_592, 49_362 };
    const lose       = [2]comptime_int{ 49_362, 64_024 };
    // zig fmt: on
};

const PhysicalControllerState = struct {
    k_left: bool = false,
    k_right: bool = false,
    k_lshift: bool = false,
    k_space: bool = false,
    k_r: bool = false,
    k_escape: bool = false,

    m_left: bool = false,
    m_xrel: f32 = 0,

    g_left: bool = false,
    g_right: bool = false,
    g_left_shoulder: bool = false,
    g_right_shoulder: bool = false,
    g_south: bool = false,
    g_east: bool = false,
    g_back: bool = false,
    g_start: bool = false,
    g_leftx: i16 = 0,
    g_left_trigger: i16 = 0,
    g_right_trigger: i16 = 0,
};

const VirtualControllerState = struct {
    move_paddle_left: bool = false,
    move_paddle_right: bool = false,
    slow_paddle_movement: bool = false,
    launch_ball: bool = false,
    reset_game: bool = false,

    lock_mouse: bool = false,
    move_paddle_exact: f32 = 0,
};

/// Facilitates updating the game logic at a fixed rate.
/// Inspired <https://github.com/TylerGlaiel/FrameTimingControl> and the linked article.
const Timekeeper = struct {
    const updates_per_s = 60;
    const max_accumulated_updates = 8;
    const snap_frame_rates = .{ updates_per_s, 30, 120, 144 };
    const ticks_per_tock = 720; // Least common multiple of 'snap_frame_rates'
    const snap_tolerance_us = 200;
    const us_per_s = 1_000_000;

    tocks_per_s: u64,
    accumulated_ticks: u64 = 0,
    previous_timestamp: ?u64 = null,

    fn consume(timekeeper_: *Timekeeper) bool {
        const ticks_per_s: u64 = timekeeper_.tocks_per_s * ticks_per_tock;
        const ticks_per_update: u64 = @divExact(ticks_per_s, updates_per_s);
        if (timekeeper_.accumulated_ticks >= ticks_per_update) {
            timekeeper_.accumulated_ticks -= ticks_per_update;
            return true;
        } else {
            return false;
        }
    }

    fn produce(timekeeper_: *Timekeeper, current_timestamp: u64) void {
        if (timekeeper_.previous_timestamp) |previous_timestamp| {
            const ticks_per_s: u64 = timekeeper_.tocks_per_s * ticks_per_tock;
            const elapsed_ticks: u64 = (current_timestamp -% previous_timestamp) *| ticks_per_tock;
            const snapped_elapsed_ticks: u64 = inline for (snap_frame_rates) |snap_frame_rate| {
                const target_ticks: u64 = @divExact(ticks_per_s, snap_frame_rate);
                const abs_diff = @max(elapsed_ticks, target_ticks) - @min(elapsed_ticks, target_ticks);
                if (abs_diff *| us_per_s <= snap_tolerance_us *| ticks_per_s) {
                    break target_ticks;
                }
            } else elapsed_ticks;
            const ticks_per_update: u64 = @divExact(ticks_per_s, updates_per_s);
            const max_accumulated_ticks: u64 = max_accumulated_updates * ticks_per_update;
            timekeeper_.accumulated_ticks = @min(timekeeper_.accumulated_ticks +| snapped_elapsed_ticks, max_accumulated_ticks);
        }
        timekeeper_.previous_timestamp = current_timestamp;
    }
};

const Paddle = struct {
    box: Rect,
    sprite: Sprites.Sprite_,
};

const Collision = struct {
    t: f32,
    sign_x: f32,
    sign_y: f32,

    fn intersects(a: Rect, b: Rect) bool {
        const min_x = b.pos.x - a.size.x;
        const max_x = b.pos.x + b.size.x;
        if (a.pos.x > min_x and a.pos.x < max_x) {
            const min_y = b.pos.y - a.size.y;
            const max_y = b.pos.y + b.size.y;
            if (a.pos.y > min_y and a.pos.y < max_y) {
                return true;
            }
        }
        return false;
    }

    fn sweep_test(a: Rect, a_vel: FVec, b: Rect, b_vel: FVec) ?Collision {
        const vel_x_inv = 1 / (a_vel.x - b_vel.x);
        const vel_y_inv = 1 / (a_vel.y - b_vel.y);
        const min_x = b.pos.x - a.size.x;
        const min_y = b.pos.y - a.size.y;
        const max_x = b.pos.x + b.size.x;
        const max_y = b.pos.y + b.size.y;
        const t_min_x = (min_x - a.pos.x) * vel_x_inv;
        const t_min_y = (min_y - a.pos.y) * vel_y_inv;
        const t_max_x = (max_x - a.pos.x) * vel_x_inv;
        const t_max_y = (max_y - a.pos.y) * vel_y_inv;
        const entry_x = @min(t_min_x, t_max_x);
        const entry_y = @min(t_min_y, t_max_y);
        const exit_x = @max(t_min_x, t_max_x);
        const exit_y = @max(t_min_y, t_max_y);

        const last_entry = @max(entry_x, entry_y);
        const first_exit = @min(exit_x, exit_y);
        if (last_entry < first_exit and last_entry < 1 and first_exit > 0) {
            var sign_x: f32 = 0;
            var sign_y: f32 = 0;
            sign_x -= @floatFromInt(@intFromBool(last_entry == t_min_x));
            sign_x += @floatFromInt(@intFromBool(last_entry == t_max_x));
            sign_y -= @floatFromInt(@intFromBool(last_entry == t_min_y));
            sign_y += @floatFromInt(@intFromBool(last_entry == t_max_y));
            return .{ .t = last_entry, .sign_x = sign_x, .sign_y = sign_y };
        }
        return null;
    }
};

const Ball = struct {
    box: Rect,
    vel: FVec,
    launched: bool,
    sprite: Sprites.Sprite_,

    fn get_paddle_bounce_angle(ball_: Ball, paddle_: Paddle) f32 {
        const min_x = paddle_.box.pos.x - ball_.box.size.x;
        const max_x = paddle_.box.pos.x + paddle_.box.size.x;
        const min_angle = std.math.degreesToRadians(195);
        const max_angle = std.math.degreesToRadians(345);
        const angle = ((ball_.box.pos.x - min_x) / (max_x - min_x)) * (max_angle - min_angle) + min_angle;
        return std.math.clamp(angle, min_angle, max_angle);
    }
};

const Brick = struct {
    box: Rect,
    sprite: Sprites.Sprite_,
};

fn fmt_sdl_drivers(write_buf: *BoundedArray(u8, 250), current_driver: [*:0]const u8, num_drivers: c_int, get_driver: *const fn (c_int) SDL.Error![*:0]const u8) anyerror![]const u8 {
    var w: BoundedArray(u8, 250).Writer = write_buf.writer();
    var writer: *std.Io.Writer = &w.interface;
    var i: c_int = 0;
    while (i < num_drivers) : (i += 1) {
        const driver_name = try get_driver(i);
        // _ = c_strings_equal(driver_name, current_driver);
        const is_current = c_strings_equal(driver_name, current_driver);
        if (is_current) _ = try writer.write(ANSI.FG_GREEN);
        try writer.print("\n\t({d}) {s}", .{ i, driver_name });
        if (is_current) _ = try writer.write(ANSI.RESET);
    }
    return write_buf.slice();
}

fn load_records() !void {
    const storage = try SDL.Storage.open_user_storage_folder(best_score_storage_org_name, best_score_storage_app_name, SDL.PropertiesID{});
    defer storage.close() catch {};

    while (!storage.is_ready()) {
        var total_time: u32 = 0;
        SDL.Time.wait_milliseconds(10);
        total_time += 10;
        if (total_time > 10000) return error.load_best_score_ready_timeout;
    }
    const default_best: u32 = 1000 * Timekeeper.updates_per_s;
    const default_best_score_le: [4]u8 = @bitCast(std.mem.nativeToLittle(u32, default_best));

    var buf: [8:0]u8 = @splat(0);
    storage.read_file_into_buffer(records_storage_file_name, buf[0..8]) catch {
        @memcpy(buf[4..8], default_best_score_le[0..4]);
    };
    var stream = try SDL.IOStream.from_mem(buf[0..8]);
    defer stream.close() catch {};
    app.attempts = try stream.read_u32_le();
    app.best_win = try stream.read_u32_le();

    app_log.debug("loaded records:\n\tattempts = {d}\n\tbest win: {d}", .{ app.attempts, app.best_win });
}

fn save_records() !void {
    const storage = try SDL.Storage.open_user_storage_folder(best_score_storage_org_name, best_score_storage_app_name, SDL.PropertiesID{});
    defer storage.close() catch {};

    while (!storage.is_ready()) {
        var total_time: u32 = 0;
        SDL.Time.wait_milliseconds(10);
        total_time += 10;
        if (total_time > 10000) return error.save_best_score_ready_timeout;
    }
    app.records_need_save = false;

    const new_best_win = if (app.won and app.score < app.best_win) app.score else app.best_win;
    var buf: [8:0]u8 = undefined;
    const stream = try SDL.IOStream.from_mem(buf[0..8]);
    defer stream.close() catch {};
    try stream.write_u32_le(app.attempts);
    try stream.write_u32_le(new_best_win);
    try storage.write_file_from_buffer(records_storage_file_name, buf[0..8]);
    app_log.debug("saved records:\n\tattempts = {d}\n\tbest win: {d}", .{ app.attempts, new_best_win });
}

fn reset_game() !void {
    app.won = false;
    app.records_need_save = false;
    app.attempts += 1;
    app.paddle = .{
        .box = .{
            .pos = .{
                .x = Cast.num_cast(window_size.x, f32) * 0.5 - Sprite.paddle.size().x * 0.5,
                .y = Cast.num_cast(window_size.y, f32) - Sprite.paddle.size().y,
            },
            .size = .{
                .x = Sprite.paddle.size().x,
                .y = Sprite.paddle.size().y,
            },
        },
        .sprite = .paddle,
    };

    app.ball = .{
        .box = .{
            .pos = .{
                .x = app.paddle.box.pos.x + app.paddle.box.size.x * 0.5,
                .y = app.paddle.box.pos.y - Sprite.ball.size().y,
            },
            .size = .{
                .x = Sprite.ball.size().x,
                .y = Sprite.ball.size().y,
            },
        },
        .vel = FVec.new(0, 0),
        .launched = false,
        .sprite = .ball,
    };

    app.bricks = .{};
    {
        const x = Cast.num_cast(window_size.x, f32) * 0.5;
        const h = Sprite.brick_1x1_gray.size().y;
        const gap = 5;
        for ([_][2]Sprites.Sprite_{
            .{ Sprites.Sprite_.brick_1x1_purple, Sprites.Sprite_.brick_2x1_purple },
            .{ Sprites.Sprite_.brick_1x1_red, Sprites.Sprite_.brick_2x1_red },
            .{ Sprites.Sprite_.brick_1x1_yellow, Sprites.Sprite_.brick_2x1_yellow },
            .{ Sprites.Sprite_.brick_1x1_green, Sprites.Sprite_.brick_2x1_green },
            .{ Sprites.Sprite_.brick_1x1_blue, Sprites.Sprite_.brick_2x1_blue },
            .{ Sprites.Sprite_.brick_1x1_gray, Sprites.Sprite_.brick_2x1_gray },
        }, 0..) |sprites, row| {
            const y = gap + (h + gap) * (@as(f32, @floatFromInt(row)) + 1);
            var large = row % 2 == 0;
            var sprite = sprites[@intFromBool(large)];
            app.bricks.append(Brick{
                .box = .{ .pos = .{
                    .x = x - sprite.size().x * 0.5,
                    .y = y,
                }, .size = .{
                    .x = sprite.size().x,
                    .y = sprite.size().y,
                } },
                .sprite = sprite,
            });
            var rel_x: f32 = 0;
            var count: usize = 0;
            while (count < 4) : (count += 1) {
                rel_x += sprite.size().x * 0.5 + gap;
                large = !large;
                sprite = sprites[@intFromBool(large)];
                rel_x += sprite.size().x * 0.5;
                for ([_]f32{ -1, 1 }) |sign| {
                    app.bricks.append(Brick{
                        .box = .{
                            .pos = .{
                                .x = x - sprite.size().x * 0.5 + rel_x * sign,
                                .y = y,
                            },
                            .size = .{
                                .x = sprite.size().x,
                                .y = sprite.size().y,
                            },
                        },
                        .sprite = sprite,
                    });
                }
            }
        }
    }

    app.score = 0;
    app.score_color = SDL.Color_RGBA_u8.new_rgba(0xff, 0xff, 0xff, 0xff);
}

fn app_update(appstate: ?*anyopaque) !SDL.AppResult {
    _ = appstate;

    var sounds_to_play: std.EnumSet(enum {
        hit_wall,
        hit_paddle,
        hit_brick,
        win,
        lose,
    }) = .empty;

    // Update the game state.
    while (app.timekeeper.consume()) {
        // Map the physical controller state to the virtual controller state.

        app.prev_virtual_controller = app.virtual_controller;
        app.virtual_controller.move_paddle_exact = 0;

        app.virtual_controller.move_paddle_left =
            app.phys_controller.k_left or
            app.phys_controller.g_left or
            app.phys_controller.g_leftx <= -0x4000;
        app.virtual_controller.move_paddle_right =
            app.phys_controller.k_right or
            app.phys_controller.g_right or
            app.phys_controller.g_leftx >= 0x4000;
        app.virtual_controller.slow_paddle_movement =
            app.phys_controller.k_lshift or
            app.phys_controller.g_left_shoulder or
            app.phys_controller.g_right_shoulder or
            app.phys_controller.g_left_trigger >= 0x2000 or
            app.phys_controller.g_right_trigger >= 0x2000;
        app.virtual_controller.launch_ball =
            app.phys_controller.k_space or
            app.phys_controller.g_south or
            app.phys_controller.g_east;
        app.virtual_controller.reset_game =
            app.phys_controller.k_r or
            app.phys_controller.g_back or
            app.phys_controller.g_start;

        if (!app.virtual_controller.lock_mouse) {
            if (app.phys_controller.m_left and !app.prev_phys_controller.m_left) {
                app.virtual_controller.lock_mouse = true;
                try app.graphics.get_window(.MAIN).set_mouse_mode_relative(true);
            }
        } else {
            if (app.phys_controller.k_escape and !app.prev_phys_controller.k_escape) {
                app.virtual_controller.lock_mouse = false;
                try app.graphics.get_window(.MAIN).set_mouse_mode_relative(false);
            } else {
                app.virtual_controller.launch_ball = app.virtual_controller.launch_ball or app.phys_controller.m_left;
                app.virtual_controller.move_paddle_exact = app.phys_controller.m_xrel;
            }
        }

        app.prev_phys_controller = app.phys_controller;
        app.phys_controller.m_xrel = 0;

        if (app.virtual_controller.reset_game and !app.prev_virtual_controller.reset_game) {
            try reset_game();
            return SDL.AppResult.CONTINUE;
        }

        // Move the paddle.
        {
            var paddle_vel_x: f32 = 0;
            var keyboard_gamepad_vel_x: f32 = 0;
            if (app.virtual_controller.move_paddle_left) keyboard_gamepad_vel_x -= 10;
            if (app.virtual_controller.move_paddle_right) keyboard_gamepad_vel_x += 10;
            if (app.virtual_controller.slow_paddle_movement) keyboard_gamepad_vel_x *= 0.5;
            paddle_vel_x += keyboard_gamepad_vel_x;
            var mouse_vel_x = app.virtual_controller.move_paddle_exact;
            if (app.virtual_controller.slow_paddle_movement) mouse_vel_x *= 0.25;
            paddle_vel_x += mouse_vel_x;
            app.paddle.box.pos.x = std.math.clamp(app.paddle.box.pos.x + paddle_vel_x, 0, window_size.x - app.paddle.box.size.x);
        }

        const previous_ball_y = app.ball.box.pos.y;

        if (!app.ball.launched) {
            // Stick the ball to the paddle.
            app.ball.box.pos.x = app.paddle.box.pos.x + app.paddle.box.size.x * 0.5;

            if (app.virtual_controller.launch_ball and !app.prev_virtual_controller.launch_ball) {
                // Launch the ball.
                const angle = app.ball.get_paddle_bounce_angle(app.paddle);
                app.ball.vel.x = @cos(angle) * 4;
                app.ball.vel.y = @sin(angle) * 4;
                app.ball.launched = true;
            }
        }

        if (app.ball.launched) {
            // Check for and handle collisions using swept AABB collision detection.
            var rem_vel: FVec = app.ball.vel;
            while (rem_vel.x != 0 or rem_vel.y != 0) {
                var t: f32 = 1;
                var sign_x: f32 = 0;
                var sign_y: f32 = 0;
                var collidee: union(enum) {
                    none: void,
                    wall: void,
                    paddle: void,
                    brick: usize,
                } = .none;

                const inv_rem_vel = rem_vel.inverse();

                if (rem_vel.x < 0) {
                    // Left wall
                    const wall_t = -app.ball.box.pos.x * inv_rem_vel.x;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_x = 1;
                        collidee = .wall;
                    }
                } else if (rem_vel.x > 0) {
                    // Right wall
                    const wall_t = (window_size.x - app.ball.box.size.x - app.ball.box.pos.x) * inv_rem_vel.x;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_x = -1;
                        collidee = .wall;
                    }
                }
                if (rem_vel.y < 0) {
                    // Top wall
                    const wall_t = -app.ball.box.pos.y * inv_rem_vel.y;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_y = 1;
                        collidee = .wall;
                    }
                } else if (rem_vel.y > 0) {
                    // Paddle
                    const paddle_top: Rect = .{
                        .pos = .{
                            .x = app.paddle.box.pos.x,
                            .y = app.paddle.box.pos.y,
                        },
                        .size = .{
                            .x = app.paddle.box.size.x,
                            .y = 0,
                        },
                    };
                    if (Collision.sweep_test(app.ball.box, rem_vel, paddle_top, FVec.ZERO)) |collision| {
                        if (t - collision.t >= 0.001) {
                            t = @min(0, collision.t);
                            sign_y = -1;
                            collidee = .paddle;
                        }
                    }
                }

                // Bricks
                const broad: Rect = .{
                    .pos = .{
                        .x = @min(app.ball.box.pos.x, app.ball.box.pos.x + rem_vel.x),
                        .y = @min(app.ball.box.pos.y, app.ball.box.pos.y + rem_vel.y),
                    },
                    .size = .{
                        .x = @max(app.ball.box.size.x, app.ball.box.size.x + rem_vel.x),
                        .y = @max(app.ball.box.size.y, app.ball.box.size.y + rem_vel.y),
                    },
                };
                for (app.bricks.slice(), 0..) |brick, i| {
                    if (Collision.intersects(broad, brick.box)) {
                        if (Collision.sweep_test(app.ball.box, rem_vel, brick.box, FVec.ZERO)) |collision| {
                            if (t - collision.t >= 0.001) {
                                t = collision.t;
                                sign_x = collision.sign_x;
                                sign_y = collision.sign_y;
                                collidee = .{ .brick = i };
                            }
                        }
                    }
                }

                // Bounce the ball off the object it collided with (if any).
                if (collidee == .paddle) {
                    const angle = app.ball.get_paddle_bounce_angle(app.paddle);
                    const vel_factor = 1.05;
                    app.ball.box.pos.x += rem_vel.x * t;
                    app.ball.box.pos.y += rem_vel.y * t;
                    const vel = @sqrt(app.ball.vel.x * app.ball.vel.x + app.ball.vel.y * app.ball.vel.y) * vel_factor;
                    app.ball.vel.x = @cos(angle) * vel;
                    app.ball.vel.y = @sin(angle) * vel;
                    rem_vel.x *= (1 - t);
                    rem_vel.y *= (1 - t);
                    const remaining_vel = @sqrt(rem_vel.x * rem_vel.x + rem_vel.y * rem_vel.y) * vel_factor;
                    rem_vel.x = @cos(angle) * remaining_vel;
                    rem_vel.y = @sin(angle) * remaining_vel;
                } else {
                    app.ball.box.pos.x += rem_vel.x * t;
                    app.ball.box.pos.y += rem_vel.y * t;
                    app.ball.vel.x = std.math.copysign(app.ball.vel.x, if (sign_x != 0) sign_x else rem_vel.x);
                    app.ball.vel.y = std.math.copysign(app.ball.vel.y, if (sign_y != 0) sign_y else rem_vel.y);
                    rem_vel.x = std.math.copysign(rem_vel.x * (1 - t), app.ball.vel.x);
                    rem_vel.y = std.math.copysign(rem_vel.y * (1 - t), app.ball.vel.y);
                    if (collidee == .brick) {
                        _ = app.bricks.swapRemove(collidee.brick);
                    }
                }

                // Enqueue an appropriate sound effect.
                switch (collidee) {
                    .wall => {
                        if (app.ball.box.pos.y < window_size.y) {
                            sounds_to_play.insert(.hit_wall);
                        }
                    },
                    .paddle => {
                        sounds_to_play.insert(.hit_paddle);
                    },
                    .brick => {
                        if (app.bricks.len == 0) {
                            app.won = true;
                            app.records_need_save = true;
                            sounds_to_play.insert(.win);
                        } else {
                            sounds_to_play.insert(.hit_brick);
                        }
                    },
                    .none => {},
                }
            }
        }

        if (previous_ball_y < window_size.y and app.ball.box.pos.y >= window_size.y) {
            // The ball fell below the paddle.
            if (app.bricks.len != 0) {
                sounds_to_play.insert(.lose);
                app.records_need_save = true;
            }
        }

        // Update score.
        if (app.ball.launched) {
            if (app.ball.box.pos.y < window_size.y) {
                if (app.bricks.len != 0) {
                    app.score +|= 1;
                } else {
                    app.best_win = @min(app.score, app.best_win);
                }
            }
            if (app.score <= app.best_win and app.bricks.len == 0) {
                app.score_color = SDL.Color_RGBA_u8.new_rgba(0x52, 0xcc, 0x73, 0xff);
            } else if (app.ball.box.pos.y >= window_size.y or app.score > app.best_win) {
                app.score_color = SDL.Color_RGBA_u8.new_rgba(0xcc, 0x5c, 0x52, 0xff);
            }
        }
    }

    // Save score.
    if (app.records_need_save) {
        try save_records();
    }

    // Play audio.
    {
        // We have created eight SDL audio streams. When we want to play a sound effect,
        // we loop through the streams for the first one that isn't playing any audio
        // and write the audio to that stream.
        // This is a kind of stupid and naive way of handling audio, but it's very easy to
        // set up and use. A proper program would probably use an audio mixing callback.
        var stream_index: usize = 0;
        var it = sounds_to_play.iterator();
        iterate_sounds: while (it.next()) |sound| {
            const stream = find_available_stream: while (stream_index < app.audio_streams.len) {
                defer stream_index += 1;
                const stream = app.audio_streams[stream_index];
                if (try stream.get_bytes_available_to_take_out() == 0) {
                    break :find_available_stream stream;
                }
            } else {
                break :iterate_sounds;
            };
            const frame_size: usize = @intCast(app.sounds.spec.frame_size());
            const start: usize, const end: usize = switch (sound) {
                .hit_wall => Sounds.hit_wall,
                .hit_paddle => Sounds.hit_paddle,
                .hit_brick => Sounds.hit_brick,
                .win => Sounds.win,
                .lose => Sounds.lose,
            };
            const data = app.sounds.data[(frame_size * start)..(frame_size * end)];
            try stream.put_in_audio_data(data);
        }
    }

    // Draw.
    {
        const CLEAR_COLOR = SDL.Color_RGBA_u8.new(0x47, 0x5b, 0x8d, 0xff).change_component_type_normalized(f32);
        app.clear_vert_buffers();
        for (app.bricks.slice()) |brick| {
            app.append_vertices(brick.box, brick.sprite, alloc);
        }
        app.append_vertices(app.ball.box, app.ball.sprite, alloc);
        app.append_vertices(app.paddle.box, app.paddle.sprite, alloc);
        app.validate_position_buffer.grow_capacity_if_needed(app.position_buffer.get_len(), .GROW_EXACT_NEEDED, alloc);
        app.validate_position_buffer.set_len(app.position_buffer.get_len());
        app.validate_index_buffer.grow_capacity_if_needed(app.index_buffer.get_len(), .GROW_EXACT_NEEDED, alloc);
        app.validate_index_buffer.set_len(app.index_buffer.get_len());
        app.validate_sprite_idx_buffer.grow_capacity_if_needed(app.sprite_idx_buffer.get_len(), .GROW_EXACT_NEEDED, alloc);
        app.validate_sprite_idx_buffer.set_len(app.sprite_idx_buffer.get_len());
        var upload = app.graphics.begin_upload_pass();
        try upload.upload_to_index_buffer(.VERT_INDEXES, 0, .MAIN_UPLOAD_BUFFER, app.index_buffer.zig_slice_entire_const());
        try upload.upload_to_vertex_buffer_no_type_check(.VERTEX_POSITIONS, 0, .MAIN_UPLOAD_BUFFER, app.position_buffer.zig_slice_entire_const());
        try upload.upload_to_vertex_buffer_no_type_check(.SPRITE_VERTEX_INDEXES, 0, .MAIN_UPLOAD_BUFFER, app.sprite_idx_buffer.zig_slice_entire_const());
        var cmd: CommandBuffer = try upload.end_upload_pass_and_start_command_buffer(true);
        const can_render: ?RenderPass = try cmd.begin_render_pass(
            .MAIN_PIPELINE,
            &.{
                ColorTarget{
                    .target = .window(.MAIN),
                    .clear_color = CLEAR_COLOR,
                    .load_op = .CLEAR,
                },
            },
            null,
        );
        if (can_render) |render| {
            render.bind_all_resources_and_push_all_uniforms(0, &.{});
            render.bind_index_buffer(.VERT_INDEXES, 0);
            render.draw_indexed_primitives(0, 0, app.index_buffer.get_len());
            render.end_render_pass();
        }
        const download = try cmd.begin_download_pass();
        _ = try download.download_from_vertex_buffer_no_type_check(.VERTEX_POSITIONS, 0, @intCast(app.position_buffer.get_len()), .MAIN_DOWNLOAD_BUFFER, app.validate_position_buffer.zig_slice(0, app.position_buffer.get_len()));
        _ = try download.download_from_vertex_buffer_no_type_check(.SPRITE_VERTEX_INDEXES, 0, @intCast(app.sprite_idx_buffer.get_len()), .MAIN_DOWNLOAD_BUFFER, app.validate_sprite_idx_buffer.zig_slice(0, app.sprite_idx_buffer.get_len()));
        _ = try download.download_from_index_buffer_no_type_check(.VERT_INDEXES, 0, @intCast(app.index_buffer.get_len()), .MAIN_DOWNLOAD_BUFFER, app.validate_index_buffer.zig_slice(0, app.index_buffer.get_len()));
        try download.end_download_pass_submit_command_buffer_and_immedieately_wait_on_fence_to_complete_downloads();
        assert_with_reason(std.mem.eql(u8, std.mem.sliceAsBytes(app.position_buffer.zig_slice_entire_const()), std.mem.sliceAsBytes(app.validate_position_buffer.zig_slice_entire_const())), @src(), "vert position data did not transfer correctly", .{});
        assert_with_reason(std.mem.eql(u8, std.mem.sliceAsBytes(app.sprite_idx_buffer.zig_slice_entire_const()), std.mem.sliceAsBytes(app.validate_sprite_idx_buffer.zig_slice_entire_const())), @src(), "vert sprite idx data did not transfer correctly", .{});
        assert_with_reason(std.mem.eql(u8, std.mem.sliceAsBytes(app.index_buffer.zig_slice_entire_const()), std.mem.sliceAsBytes(app.validate_index_buffer.zig_slice_entire_const())), @src(), "vert index data did not transfer correctly", .{});
    }

    app.timekeeper.produce(SDL.Time.get_performance_counter());

    return SDL.AppResult.CONTINUE;
}

fn handle_event(appstate: ?*anyopaque, event_: ?*SDL.Event) !SDL.AppResult {
    _ = appstate;
    const event = event_ orelse return SDL.AppResult.CONTINUE;
    switch (event.type) {
        .QUIT => {
            return SDL.AppResult.CLOSE_NORMAL;
        },
        .KEY_DOWN, .KEY_UP => {
            const is_down = event.type == .KEY_DOWN;
            switch (event.keyboard.scancode) {
                .LEFT => app.phys_controller.k_left = is_down,
                .RIGHT => app.phys_controller.k_right = is_down,
                .LSHIFT => app.phys_controller.k_lshift = is_down,
                .SPACE => app.phys_controller.k_space = is_down,
                .R => app.phys_controller.k_r = is_down,
                .ESCAPE => app.phys_controller.k_escape = is_down,
                else => {},
            }
        },
        .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP => {
            const is_down = event.type == .MOUSE_BUTTON_DOWN;
            switch (event.mouse_button.button) {
                .LEFT => app.phys_controller.m_left = is_down,
                else => {},
            }
        },
        .MOUSE_MOTION => {
            app.phys_controller.m_xrel += event.mouse_motion.delta.x;
        },
        .GAMEPAD_ADDED => {
            if (app.gamepad == null) {
                app.gamepad = try event.gamepad_device.controller_id.open_gamepad();
            }
        },
        .GAMEPAD_REMOVED => {
            if (app.gamepad) |pad| {
                pad.close();
                app.gamepad = null;
            }
        },
        .GAMEPAD_BUTTON_DOWN, .GAMEPAD_BUTTON_UP => {
            const is_down = event.type == .GAMEPAD_BUTTON_DOWN;
            switch (event.gamepad_button.button) {
                .DPAD_LEFT => app.phys_controller.g_left = is_down,
                .DPAD_RIGHT => app.phys_controller.g_right = is_down,
                .LEFT_SHOULDER => app.phys_controller.g_left_shoulder = is_down,
                .RIGHT_SHOULDER => app.phys_controller.g_right_shoulder = is_down,
                .SOUTH => app.phys_controller.g_south = is_down,
                .EAST => app.phys_controller.g_east = is_down,
                .BACK => app.phys_controller.g_back = is_down,
                .START => app.phys_controller.g_start = is_down,
                else => {},
            }
        },
        .GAMEPAD_AXIS_MOTION => {
            switch (event.gamepad_axis.axis) {
                .LEFTX => app.phys_controller.g_leftx = event.gamepad_axis.value,
                .LEFT_TRIGGER => app.phys_controller.g_left_trigger = event.gamepad_axis.value,
                .RIGHT_TRIGGER => app.phys_controller.g_right_trigger = event.gamepad_axis.value,
                else => {},
            }
        },
        .WINDOW_RESIZED => {
            const win_event = event.window;
            const render_info: *GraphicsModule.WindowRenderInfo = &app.graphics.uniforms.WINDOW_RENDER_INFO;
            const new_width: i32 = win_event.data_1;
            const new_height: i32 = win_event.data_2;
            render_info.get_ptr(.target_size).x = @floatFromInt(new_width);
            render_info.get_ptr(.target_size).y = @floatFromInt(new_height);
        },
        else => {},
    }

    return SDL.AppResult.CONTINUE;
}

fn app_quit(appstate: ?*anyopaque, result: anyerror!SDL.AppResult) void {
    _ = appstate;
    _ = result catch |err| switch (err) {
        SDL.Error.SDL_null_value,
        SDL.Error.SDL_operation_failure,
        SDL.Error.SDL_invalid_value,
        => {
            sdl_log.err("{s}: {s}", .{ @errorName(err), SDL.App.get_error_details() });
        },
        else => {
            app_log.err("{s}", .{@errorName(err)});
        },
    };

    if (app.fully_initialized) {
        if (app.gamepad) |pad| pad.close();
        while (app.audio_streams.len != 0) {
            app.audio_streams[app.audio_streams.len - 1].destroy();
            app.audio_streams.len -= 1;
        }
        app.audio_device.close();
        app.sounds.destroy();
        app.graphics.destroy();
        app.fully_initialized = false;
    }
}

fn sdl_main_func(arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return SDL.App.run_app_with_callbacks(arg_count, arg_list, sdl_init_func, sdl_update_func, sdl_event_func, sdl_quit_func);
}

fn sdl_init_func(appstate: ?*?*anyopaque, arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) SDL.AppResult {
    return app_init(appstate, arg_count, arg_list) catch |err| app.app_err.store(err);
}

fn sdl_update_func(appstate: ?*anyopaque) callconv(.c) SDL.AppResult {
    return app_update(appstate) catch |err| app.app_err.store(err);
}

fn sdl_event_func(appstate: ?*anyopaque, event: ?*SDL.Event) callconv(.c) SDL.AppResult {
    return handle_event(appstate, event) catch |err| app.app_err.store(err);
}

fn sdl_quit_func(appstate: ?*anyopaque, close_result: SDL.AppResult) callconv(.c) void {
    app_quit(appstate, app.app_err.load() orelse close_result);
}

fn BoundedArray(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();

        arr: [N]T = undefined,
        len: usize = 0,

        pub fn clear(self: *Self) void {
            self.len = 0;
        }
        pub fn slice(self: *Self) []T {
            return self.arr[0..self.len];
        }
        pub fn append(self: *Self, val: T) void {
            self.arr[self.len] = val;
            self.len += 1;
        }
        pub fn swapRemove(self: *Self, idx: usize) T {
            const rem = self.arr[idx];
            self.arr[idx] = self.arr[self.len - 1];
            self.len -= 1;
            return rem;
        }

        pub fn writer(self: *Self) Writer {
            const empty: [0]u8 = undefined;
            return .{ .buf = self, .interface = std.Io.Writer{
                .end = 0,
                .buffer = empty[0..0],
                .vtable = &VT,
            } };
        }
        const VT = std.Io.Writer.VTable{
            .drain = Writer.drain,
        };

        pub const Writer = struct {
            buf: *Self,
            interface: std.Io.Writer,
            // this has a bunch of other fields

            fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
                _ = splat;
                const self: *Writer = @fieldParentPtr("interface", io_w);
                const old_n = self.buf.len;
                for (data) |d| {
                    const n = d.len;
                    @memcpy(self.buf.arr[self.buf.len .. self.buf.len + n], d);
                    self.buf.len += n;
                }
                return self.buf.len - old_n;
            }
        };
    };
}
