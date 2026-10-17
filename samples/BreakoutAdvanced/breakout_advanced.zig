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

const GraphicsModule = @import("./breakout_graphics.zig");
const GraphicsController = GraphicsModule.Controller;
const AnyGPUBuffer = GraphicsController.AnyGPUBuffer;
const BlitInfo = GraphicsController.BlitInfo;
const BlitRegion = GraphicsController.BlitRegion;
const BufferLocation = GraphicsController.BufferLocation;
const BufferRegion = GraphicsController.BufferRegion;
const ColorTarget = GraphicsController.ColorTarget;
const CommandBuffer = GraphicsController.CommandBuffer;
const CopyDownloadDetails = GraphicsController.CopyDownloadDetails;
const CopyPassGPUOnly = GraphicsController.CopyPassGPUOnly;
const CopyPassTransferOnly = GraphicsController.CopyPassTransferOnly;
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
const PendingFinalDownloadHandle = GraphicsController.PendingFinalDownloadHandle;
const QueuedDownloadCopy = GraphicsController.QueuedDownloadCopy;
const RenderPass = GraphicsController.RenderPass;
const RenderPassWithPipeline = GraphicsController.RenderPassWithPipeline;
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
const best_score_storage_app_name = "breakout";
const records_storage_file_name = "records";
const attempts_storage_file_name = "attempts";
const window_size: IVec = IVec.new(640, 480);

const WindowFlags = SDL.WindowFlags.Flag;
const Vec2 = Goolib.Vec2.define_vec2_type(f32);

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
};
var app_state = AppState{};

pub fn main() !u8 {
    app_state.app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(SDL.App.run_app(empty_argv.len, @ptrCast(&empty_argv), sdl_main_func))));
    return app_state.app_err.load() orelse status;
}

pub fn app_init(app_state_opq: ?*?*anyopaque, arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) anyerror!SDL.AppResult {
    app_state_opq.?.* = @ptrCast(&app_state);
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
        const bmp_stream = try SDL.IOStream.from_mem(Sprites.bmp);
        const bmp_surface = try SDL.Surface.load_from_bmp_iostream(bmp_stream, true);
        const rgba_bmp_surface = try bmp_surface.convert_to_format(.RGBA_8888);
        bmp_surface.destroy();
        break :make rgba_bmp_surface;
    };

    app_state.graphics = GraphicsController.create(.{
        .vertex_shaders = .{
            VertexShaderInit{
                .name = .MAIN_VERTEX_SHADER,
                .code = switch (build.os.tag) {
                    .linux => @embedFile("./vert_MAIN_VERTEX_SHADER.spv"),
                    .windows => @embedFile("./vert_MAIN_VERTEX_SHADER.dxil"),
                    .macos => @embedFile("./vert_MAIN_VERTEX_SHADER.msl"),
                    else => @embedFile("./vert_MAIN_VERTEX_SHADER.spv"),
                },
            },
        },
        .fragment_shaders = .{
            FragmentShaderInit{
                .name = .MAIN_FRAGMENT_SHADER,
                .code = switch (build.os.tag) {
                    .linux => @embedFile("./frag_MAIN_FRAGMENT_SHADER.spv"),
                    .windows => @embedFile("./frag_MAIN_FRAGMENT_SHADER.dxil"),
                    .macos => @embedFile("./frag_MAIN_FRAGMENT_SHADER.msl"),
                    else => @embedFile("./frag_MAIN_FRAGMENT_SHADER.spv"),
                },
            },
        },
        .uniforms_init = UniformCollection{
            .GLOBAL = .{
                .pos_offset = Vec2.new(0, 0),
            },
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
                    WindowFlags.KEYBOARD_GRABBED,
                    WindowFlags.INPUT_FOCUS,
                    WindowFlags.MOUSE_GRABBED,
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
                .max_byte_size = @max(400 * @sizeOf(GraphicsModule.VertexIn), 2500 * 4),
            },
        },
        .internal_lists_alloc = std.heap.smp_allocator,
    });
    errdefer app_state.graphics.destroy();

    write_buf.clear();
    sdl_log.debug("SDL render drivers: {s}", .{try fmt_sdl_drivers(
        &write_buf,
        try app_state.graphics.gpu.get_driver_name(),
        SDL.GPU_Device.get_num_drivers(),
        SDL.GPU_Device.get_driver_name_by_index,
    )});
    {
        var upload = app_state.graphics.begin_upload_pass();
        try upload.upload_to_texture(rgba_bmp_surface.pixel_slice(), .SPRITE_TEX, .new(0, 0, 0), .new(@intCast(rgba_bmp_surface.size.x), @intCast(rgba_bmp_surface.size.y), 1), 0, 1, .MAIN_UPLOAD_BUFFER);
        upload.end_upload_pass_then_create_and_submit_new_command_buffer_and_immediately_wait_on_fence(false);
        upload = app_state.graphics.begin_upload_pass();
        try upload.upload_to_storage_buffer(Sprites.tex_coords[0..], .SPRITE_VERTEX_DATA, 0, .MAIN_UPLOAD_BUFFER);
        upload.end_upload_pass_then_create_and_submit_new_command_buffer_and_immediately_wait_on_fence(false);
    }

    {
        const stream = try SDL.IOStream.from_const_mem(Sounds.wav[0..Sounds.wav.len]);
        app_state.sounds = try stream.load_wav(true);
        errdefer comptime unreachable;
    }
    errdefer app_state.sounds.destroy();

    app_state.audio_device = try SDL.AudioDeviceID.DEFAULT_PLAYBACK_DEVICE.open_device(.spec(&app_state.sounds.spec));
    errdefer app_state.audio_device.close();

    errdefer while (app_state.audio_streams.len != 0) {
        app_state.audio_streams[app_state.audio_streams.len - 1].destroy();
        if (app_state.audio_streams.len != 0) app_state.audio_streams.len -= 1;
    };
    while (app_state.audio_streams.len < app_state.audio_streams_buf.len) {
        app_state.audio_streams.len += 1;
        app_state.audio_streams[app_state.audio_streams.len - 1] = try SDL.AudioStream.create(.same_input_and_output(&app_state.sounds.spec));
    }

    try app_state.audio_device.bind_many_audio_streams(app_state.audio_streams);

    {
        const gamepads_list = try SDL.JoystickID.get_all_gamepads();
        defer gamepads_list.free();

        app_state.gamepad = if (gamepads_list.list.len > 0) try gamepads_list.list[0].open_gamepad() else null;
    }
    errdefer if (app_state.gamepad) |pad| pad.close();

    app_state.phys_controller = .{};
    app_state.prev_phys_controller = app_state.phys_controller;
    app_state.virtual_controller = .{};
    app_state.prev_virtual_controller = app_state.virtual_controller;

    try load_records();

    app_state.timekeeper = .{ .tocks_per_s = SDL.Time.get_performance_frequency() };

    try reset_game();

    app_state.fully_initialized = true;
    errdefer comptime unreachable;

    return SDL.AppResult.CONTINUE;
}

const Sprites = struct {
    const bmp = @embedFile("sprites.bmp");

    // zig fmt: off
    const brick_2x1_purple = SDL.Rect_f32{ .pos = .{.x =   1, .y =  1}, .size = .{.x = 64, .y = 32} };
    const brick_1x1_purple = SDL.Rect_f32{ .pos = .{.x =  67, .y =  1}, .size = .{.x = 32, .y = 32} };
    const brick_2x1_red    = SDL.Rect_f32{ .pos = .{.x = 101, .y =  1}, .size = .{.x = 64, .y = 32} };
    const brick_1x1_red    = SDL.Rect_f32{ .pos = .{.x = 167, .y =  1}, .size = .{.x = 32, .y = 32} };
    const brick_2x1_yellow = SDL.Rect_f32{ .pos = .{.x =   1, .y = 35}, .size = .{.x = 64, .y = 32} };
    const brick_1x1_yellow = SDL.Rect_f32{ .pos = .{.x =  67, .y = 35}, .size = .{.x = 32, .y = 32} };
    const brick_2x1_green  = SDL.Rect_f32{ .pos = .{.x = 101, .y = 35}, .size = .{.x = 64, .y = 32} };
    const brick_1x1_green  = SDL.Rect_f32{ .pos = .{.x = 167, .y = 35}, .size = .{.x = 32, .y = 32} };
    const brick_2x1_blue   = SDL.Rect_f32{ .pos = .{.x =   1, .y = 69}, .size = .{.x = 64, .y = 32} };
    const brick_1x1_blue   = SDL.Rect_f32{ .pos = .{.x =  67, .y = 69}, .size = .{.x = 32, .y = 32} };
    const brick_2x1_gray   = SDL.Rect_f32{ .pos = .{.x = 101, .y = 69}, .size = .{.x = 64, .y = 32} };
    const brick_1x1_gray   = SDL.Rect_f32{ .pos = .{.x = 167, .y = 69}, .size = .{.x = 32, .y = 32} };

    const ball             = SDL.Rect_f32{ .pos = .{.x =  2, .y = 104}, .size = .{.x =  22, .y = 22} };
    const paddle           = SDL.Rect_f32{ .pos = .{.x = 27, .y = 103}, .size = .{.x = 104, .y = 24} };
    const tex_coords = [_]Vec2{
        brick_2x1_purple.top_left(),
        brick_2x1_purple.top_right(),
        brick_2x1_purple.bot_left(),
        brick_2x1_purple.bot_right(),
        //
        brick_1x1_purple.top_left(),
        brick_1x1_purple.top_right(),
        brick_1x1_purple.bot_left(),
        brick_1x1_purple.bot_right(),
        //
        brick_2x1_red.top_left(),
        brick_2x1_red.top_right(),
        brick_2x1_red.bot_left(),
        brick_2x1_red.bot_right(),
        //
        brick_1x1_red.top_left(),
        brick_1x1_red.top_right(),
        brick_1x1_red.bot_left(),
        brick_1x1_red.bot_right(),
        //
        brick_2x1_yellow.top_left(),
        brick_2x1_yellow.top_right(),
        brick_2x1_yellow.bot_left(),
        brick_2x1_yellow.bot_right(),
        //
        brick_1x1_yellow.top_left(),
        brick_1x1_yellow.top_right(),
        brick_1x1_yellow.bot_left(),
        brick_1x1_yellow.bot_right(),
        //
        brick_2x1_green.top_left(),
        brick_2x1_green.top_right(),
        brick_2x1_green.bot_left(),
        brick_2x1_green.bot_right(),
        //
        brick_1x1_green.top_left(),
        brick_1x1_green.top_right(),
        brick_1x1_green.bot_left(),
        brick_1x1_green.bot_right(),
        //
        brick_2x1_blue.top_left(),
        brick_2x1_blue.top_right(),
        brick_2x1_blue.bot_left(),
        brick_2x1_blue.bot_right(),
        //
        brick_1x1_blue.top_left(),
        brick_1x1_blue.top_right(),
        brick_1x1_blue.bot_left(),
        brick_1x1_blue.bot_right(),
        //
        brick_2x1_gray.top_left(),
        brick_2x1_gray.top_right(),
        brick_2x1_gray.bot_left(),
        brick_2x1_gray.bot_right(),
        //
        brick_1x1_gray.top_left(),
        brick_1x1_gray.top_right(),
        brick_1x1_gray.bot_left(),
        brick_1x1_gray.bot_right(),
        //
        ball.top_left(),
        ball.top_right(),
        ball.bot_left(),
        ball.bot_right(),
        //
        paddle.top_left(),
        paddle.top_right(),
        paddle.bot_left(),
        paddle.bot_right(),
    };
    const tex_coord_indexes = enum(u32) {
        brick_2x1_purple_TOP_LEFT,
        brick_2x1_purple_TOP_RIGHT,
        brick_2x1_purple_BOT_LEFT,
        brick_2x1_purple_BOT_RIGHT,
        //
        brick_1x1_purple_TOP_LEFT,
        brick_1x1_purple_TOP_RIGHT,
        brick_1x1_purple_BOT_LEFT,
        brick_1x1_purple_BOT_RIGHT,
        //
        brick_2x1_red_TOP_LEFT,
        brick_2x1_red_TOP_RIGHT,
        brick_2x1_red_BOT_LEFT,
        brick_2x1_red_BOT_RIGHT,
        //
        brick_1x1_red_TOP_LEFT,
        brick_1x1_red_TOP_RIGHT,
        brick_1x1_red_BOT_LEFT,
        brick_1x1_red_BOT_RIGHT,
        //
        brick_2x1_yellow_TOP_LEFT,
        brick_2x1_yellow_TOP_RIGHT,
        brick_2x1_yellow_BOT_LEFT,
        brick_2x1_yellow_BOT_RIGHT,
        //
        brick_1x1_yellow_TOP_LEFT,
        brick_1x1_yellow_TOP_RIGHT,
        brick_1x1_yellow_BOT_LEFT,
        brick_1x1_yellow_BOT_RIGHT,
        //
        brick_2x1_green_TOP_LEFT,
        brick_2x1_green_TOP_RIGHT,
        brick_2x1_green_BOT_LEFT,
        brick_2x1_green_BOT_RIGHT,
        //
        brick_1x1_green_TOP_LEFT,
        brick_1x1_green_TOP_RIGHT,
        brick_1x1_green_BOT_LEFT,
        brick_1x1_green_BOT_RIGHT,
        //
        brick_2x1_blue_TOP_LEFT,
        brick_2x1_blue_TOP_RIGHT,
        brick_2x1_blue_BOT_LEFT,
        brick_2x1_blue_BOT_RIGHT,
        //
        brick_1x1_blue_TOP_LEFT,
        brick_1x1_blue_TOP_RIGHT,
        brick_1x1_blue_BOT_LEFT,
        brick_1x1_blue_BOT_RIGHT,
        //
        brick_2x1_gray_TOP_LEFT,
        brick_2x1_gray_TOP_RIGHT,
        brick_2x1_gray_BOT_LEFT,
        brick_2x1_gray_BOT_RIGHT,
        //
        brick_1x1_gray_TOP_LEFT,
        brick_1x1_gray_TOP_RIGHT,
        brick_1x1_gray_BOT_LEFT,
        brick_1x1_gray_BOT_RIGHT,
        //
        ball_TOP_LEFT,
        ball_TOP_RIGHT,
        ball_BOT_LEFT,
        ball_BOT_RIGHT,
        //
        paddle_TOP_LEFT,
        paddle_TOP_RIGHT,
        paddle_BOT_LEFT,
        paddle_BOT_RIGHT,
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
    src_rect: *const Rect,
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
    src_rect: *const SDL.Rect_f32,

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
    src_rect: *const SDL.Rect_f32,
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
    app_state.attempts = try stream.read_u32_le();
    app_state.best_win = try stream.read_u32_le();

    app_log.debug("loaded records:\n\tattempts = {d}\n\tbest win: {d}", .{ app_state.attempts, app_state.best_win });
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
    app_state.records_need_save = false;

    const new_best_win = if (app_state.won and app_state.score < app_state.best_win) app_state.score else app_state.best_win;
    var buf: [8:0]u8 = undefined;
    const stream = try SDL.IOStream.from_mem(buf[0..8]);
    defer stream.close() catch {};
    try stream.write_u32_le(app_state.attempts);
    try stream.write_u32_le(new_best_win);
    try storage.write_file_from_buffer(records_storage_file_name, buf[0..8]);
    app_log.debug("saved records:\n\tattempts = {d}\n\tbest win: {d}", .{ app_state.attempts, new_best_win });
}

fn reset_game() !void {
    app_state.won = false;
    app_state.records_need_save = false;
    app_state.attempts += 1;
    app_state.paddle = .{
        .box = .{
            .pos = .{
                .x = Cast.num_cast(window_size.x, f32) * 0.5 - Sprites.paddle.size.x * 0.5,
                .y = Cast.num_cast(window_size.y, f32) - Sprites.paddle.size.y,
            },
            .size = .{
                .x = Sprites.paddle.size.x,
                .y = Sprites.paddle.size.y,
            },
        },
        .src_rect = &Sprites.paddle,
    };

    app_state.ball = .{
        .box = .{
            .pos = .{
                .x = app_state.paddle.box.pos.x + app_state.paddle.box.size.x * 0.5,
                .y = app_state.paddle.box.pos.y - Sprites.ball.size.y,
            },
            .size = .{
                .x = Sprites.ball.size.x,
                .y = Sprites.ball.size.y,
            },
        },
        .vel = FVec.new(0, 0),
        .launched = false,
        .src_rect = &Sprites.ball,
    };

    app_state.bricks = .{};
    {
        const x = Cast.num_cast(window_size.x, f32) * 0.5;
        const h = Sprites.brick_1x1_gray.size.y;
        const gap = 5;
        for ([_][2]*const SDL.Rect_f32{
            .{ &Sprites.brick_1x1_purple, &Sprites.brick_2x1_purple },
            .{ &Sprites.brick_1x1_red, &Sprites.brick_2x1_red },
            .{ &Sprites.brick_1x1_yellow, &Sprites.brick_2x1_yellow },
            .{ &Sprites.brick_1x1_green, &Sprites.brick_2x1_green },
            .{ &Sprites.brick_1x1_blue, &Sprites.brick_2x1_blue },
            .{ &Sprites.brick_1x1_gray, &Sprites.brick_2x1_gray },
        }, 0..) |src_rects, row| {
            const y = gap + (h + gap) * (@as(f32, @floatFromInt(row)) + 1);
            var large = row % 2 == 0;
            var src_rect = src_rects[@intFromBool(large)];
            app_state.bricks.append(.{
                .box = .{ .pos = .{
                    .x = x - src_rect.size.x * 0.5,
                    .y = y,
                }, .size = .{
                    .x = src_rect.size.x,
                    .y = src_rect.size.y,
                } },
                .src_rect = src_rect,
            });
            var rel_x: f32 = 0;
            var count: usize = 0;
            while (count < 4) : (count += 1) {
                rel_x += src_rect.size.x * 0.5 + gap;
                large = !large;
                src_rect = src_rects[@intFromBool(large)];
                rel_x += src_rect.size.x * 0.5;
                for ([_]f32{ -1, 1 }) |sign| {
                    app_state.bricks.append(.{
                        .box = .{
                            .pos = .{
                                .x = x - src_rect.size.x * 0.5 + rel_x * sign,
                                .y = y,
                            },
                            .size = .{
                                .x = src_rect.size.x,
                                .y = src_rect.size.y,
                            },
                        },
                        .src_rect = src_rect,
                    });
                }
            }
        }
    }

    app_state.score = 0;
    app_state.score_color = SDL.Color_RGBA_u8.new_rgba(0xff, 0xff, 0xff, 0xff);
}

fn app_update(appstate: ?*anyopaque) !SDL.AppResult {
    _ = appstate;

    var sounds_to_play: std.EnumSet(enum {
        hit_wall,
        hit_paddle,
        hit_brick,
        win,
        lose,
    }) = .initEmpty();

    // Update the game state.
    while (app_state.timekeeper.consume()) {
        // Map the physical controller state to the virtual controller state.

        app_state.prev_virtual_controller = app_state.virtual_controller;
        app_state.virtual_controller.move_paddle_exact = 0;

        app_state.virtual_controller.move_paddle_left =
            app_state.phys_controller.k_left or
            app_state.phys_controller.g_left or
            app_state.phys_controller.g_leftx <= -0x4000;
        app_state.virtual_controller.move_paddle_right =
            app_state.phys_controller.k_right or
            app_state.phys_controller.g_right or
            app_state.phys_controller.g_leftx >= 0x4000;
        app_state.virtual_controller.slow_paddle_movement =
            app_state.phys_controller.k_lshift or
            app_state.phys_controller.g_left_shoulder or
            app_state.phys_controller.g_right_shoulder or
            app_state.phys_controller.g_left_trigger >= 0x2000 or
            app_state.phys_controller.g_right_trigger >= 0x2000;
        app_state.virtual_controller.launch_ball =
            app_state.phys_controller.k_space or
            app_state.phys_controller.g_south or
            app_state.phys_controller.g_east;
        app_state.virtual_controller.reset_game =
            app_state.phys_controller.k_r or
            app_state.phys_controller.g_back or
            app_state.phys_controller.g_start;

        if (!app_state.virtual_controller.lock_mouse) {
            if (app_state.phys_controller.m_left and !app_state.prev_phys_controller.m_left) {
                app_state.virtual_controller.lock_mouse = true;
                try app_state.graphics.get_window(.MAIN).set_mouse_mode_relative(true);
            }
        } else {
            if (app_state.phys_controller.k_escape and !app_state.prev_phys_controller.k_escape) {
                app_state.virtual_controller.lock_mouse = false;
                try app_state.graphics.get_window(.MAIN).set_mouse_mode_relative(false);
            } else {
                app_state.virtual_controller.launch_ball = app_state.virtual_controller.launch_ball or app_state.phys_controller.m_left;
                app_state.virtual_controller.move_paddle_exact = app_state.phys_controller.m_xrel;
            }
        }

        app_state.prev_phys_controller = app_state.phys_controller;
        app_state.phys_controller.m_xrel = 0;

        if (app_state.virtual_controller.reset_game and !app_state.prev_virtual_controller.reset_game) {
            try reset_game();
            return SDL.AppResult.CONTINUE;
        }

        // Move the paddle.
        {
            var paddle_vel_x: f32 = 0;
            var keyboard_gamepad_vel_x: f32 = 0;
            if (app_state.virtual_controller.move_paddle_left) keyboard_gamepad_vel_x -= 10;
            if (app_state.virtual_controller.move_paddle_right) keyboard_gamepad_vel_x += 10;
            if (app_state.virtual_controller.slow_paddle_movement) keyboard_gamepad_vel_x *= 0.5;
            paddle_vel_x += keyboard_gamepad_vel_x;
            var mouse_vel_x = app_state.virtual_controller.move_paddle_exact;
            if (app_state.virtual_controller.slow_paddle_movement) mouse_vel_x *= 0.25;
            paddle_vel_x += mouse_vel_x;
            app_state.paddle.box.pos.x = std.math.clamp(app_state.paddle.box.pos.x + paddle_vel_x, 0, window_size.x - app_state.paddle.box.size.x);
        }

        const previous_ball_y = app_state.ball.box.pos.y;

        if (!app_state.ball.launched) {
            // Stick the ball to the paddle.
            app_state.ball.box.pos.x = app_state.paddle.box.pos.x + app_state.paddle.box.size.x * 0.5;

            if (app_state.virtual_controller.launch_ball and !app_state.prev_virtual_controller.launch_ball) {
                // Launch the ball.
                const angle = app_state.ball.get_paddle_bounce_angle(app_state.paddle);
                app_state.ball.vel.x = @cos(angle) * 4;
                app_state.ball.vel.y = @sin(angle) * 4;
                app_state.ball.launched = true;
            }
        }

        if (app_state.ball.launched) {
            // Check for and handle collisions using swept AABB collision detection.
            var rem_vel: FVec = app_state.ball.vel;
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
                    const wall_t = -app_state.ball.box.pos.x * inv_rem_vel.x;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_x = 1;
                        collidee = .wall;
                    }
                } else if (rem_vel.x > 0) {
                    // Right wall
                    const wall_t = (window_size.x - app_state.ball.box.size.x - app_state.ball.box.pos.x) * inv_rem_vel.x;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_x = -1;
                        collidee = .wall;
                    }
                }
                if (rem_vel.y < 0) {
                    // Top wall
                    const wall_t = -app_state.ball.box.pos.y * inv_rem_vel.y;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_y = 1;
                        collidee = .wall;
                    }
                } else if (rem_vel.y > 0) {
                    // Paddle
                    const paddle_top: Rect = .{
                        .pos = .{
                            .x = app_state.paddle.box.pos.x,
                            .y = app_state.paddle.box.pos.y,
                        },
                        .size = .{
                            .x = app_state.paddle.box.size.x,
                            .y = 0,
                        },
                    };
                    if (Collision.sweep_test(app_state.ball.box, rem_vel, paddle_top, FVec.ZERO)) |collision| {
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
                        .x = @min(app_state.ball.box.pos.x, app_state.ball.box.pos.x + rem_vel.x),
                        .y = @min(app_state.ball.box.pos.y, app_state.ball.box.pos.y + rem_vel.y),
                    },
                    .size = .{
                        .x = @max(app_state.ball.box.size.x, app_state.ball.box.size.x + rem_vel.x),
                        .y = @max(app_state.ball.box.size.y, app_state.ball.box.size.y + rem_vel.y),
                    },
                };
                for (app_state.bricks.slice(), 0..) |brick, i| {
                    if (Collision.intersects(broad, brick.box)) {
                        if (Collision.sweep_test(app_state.ball.box, rem_vel, brick.box, FVec.ZERO)) |collision| {
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
                    const angle = app_state.ball.get_paddle_bounce_angle(app_state.paddle);
                    const vel_factor = 1.05;
                    app_state.ball.box.pos.x += rem_vel.x * t;
                    app_state.ball.box.pos.y += rem_vel.y * t;
                    const vel = @sqrt(app_state.ball.vel.x * app_state.ball.vel.x + app_state.ball.vel.y * app_state.ball.vel.y) * vel_factor;
                    app_state.ball.vel.x = @cos(angle) * vel;
                    app_state.ball.vel.y = @sin(angle) * vel;
                    rem_vel.x *= (1 - t);
                    rem_vel.y *= (1 - t);
                    const remaining_vel = @sqrt(rem_vel.x * rem_vel.x + rem_vel.y * rem_vel.y) * vel_factor;
                    rem_vel.x = @cos(angle) * remaining_vel;
                    rem_vel.y = @sin(angle) * remaining_vel;
                } else {
                    app_state.ball.box.pos.x += rem_vel.x * t;
                    app_state.ball.box.pos.y += rem_vel.y * t;
                    app_state.ball.vel.x = std.math.copysign(app_state.ball.vel.x, if (sign_x != 0) sign_x else rem_vel.x);
                    app_state.ball.vel.y = std.math.copysign(app_state.ball.vel.y, if (sign_y != 0) sign_y else rem_vel.y);
                    rem_vel.x = std.math.copysign(rem_vel.x * (1 - t), app_state.ball.vel.x);
                    rem_vel.y = std.math.copysign(rem_vel.y * (1 - t), app_state.ball.vel.y);
                    if (collidee == .brick) {
                        _ = app_state.bricks.swapRemove(collidee.brick);
                    }
                }

                // Enqueue an appropriate sound effect.
                switch (collidee) {
                    .wall => {
                        if (app_state.ball.box.pos.y < window_size.y) {
                            sounds_to_play.insert(.hit_wall);
                        }
                    },
                    .paddle => {
                        sounds_to_play.insert(.hit_paddle);
                    },
                    .brick => {
                        if (app_state.bricks.len == 0) {
                            app_state.won = true;
                            app_state.records_need_save = true;
                            sounds_to_play.insert(.win);
                        } else {
                            sounds_to_play.insert(.hit_brick);
                        }
                    },
                    .none => {},
                }
            }
        }

        if (previous_ball_y < window_size.y and app_state.ball.box.pos.y >= window_size.y) {
            // The ball fell below the paddle.
            if (app_state.bricks.len != 0) {
                sounds_to_play.insert(.lose);
                app_state.records_need_save = true;
            }
        }

        // Update score.
        if (app_state.ball.launched) {
            if (app_state.ball.box.pos.y < window_size.y) {
                if (app_state.bricks.len != 0) {
                    app_state.score +|= 1;
                } else {
                    app_state.best_win = @min(app_state.score, app_state.best_win);
                }
            }
            if (app_state.score <= app_state.best_win and app_state.bricks.len == 0) {
                app_state.score_color = SDL.Color_RGBA_u8.new_rgba(0x52, 0xcc, 0x73, 0xff);
            } else if (app_state.ball.box.pos.y >= window_size.y or app_state.score > app_state.best_win) {
                app_state.score_color = SDL.Color_RGBA_u8.new_rgba(0xcc, 0x5c, 0x52, 0xff);
            }
        }
    }

    // Save score.
    if (app_state.records_need_save) {
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
            const stream = find_available_stream: while (stream_index < app_state.audio_streams.len) {
                defer stream_index += 1;
                const stream = app_state.audio_streams[stream_index];
                if (try stream.get_bytes_available_to_take_out() == 0) {
                    break :find_available_stream stream;
                }
            } else {
                break :iterate_sounds;
            };
            const frame_size: usize = @intCast(app_state.sounds.spec.frame_size());
            const start: usize, const end: usize = switch (sound) {
                .hit_wall => Sounds.hit_wall,
                .hit_paddle => Sounds.hit_paddle,
                .hit_brick => Sounds.hit_brick,
                .win => Sounds.win,
                .lose => Sounds.lose,
            };
            const data = app_state.sounds.data[(frame_size * start)..(frame_size * end)];
            try stream.put_in_audio_data(data);
        }
    }

    // Draw.
    {
        const CLEAR_COLOR = SDL.Color_RGBA_u8.new(0x47, 0x5b, 0x8d, 0xff);
        for (app_state.bricks.slice()) |brick| {
            //CHECKPOINT chencge Brick, Ball, and Paddle defs to take sprite ids instead of raw coords
        }
    }

    app_state.timekeeper.produce(SDL.Time.get_performance_counter());

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
                .LEFT => app_state.phys_controller.k_left = is_down,
                .RIGHT => app_state.phys_controller.k_right = is_down,
                .LSHIFT => app_state.phys_controller.k_lshift = is_down,
                .SPACE => app_state.phys_controller.k_space = is_down,
                .R => app_state.phys_controller.k_r = is_down,
                .ESCAPE => app_state.phys_controller.k_escape = is_down,
                else => {},
            }
        },
        .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP => {
            const is_down = event.type == .MOUSE_BUTTON_DOWN;
            switch (event.mouse_button.button) {
                .LEFT => app_state.phys_controller.m_left = is_down,
                else => {},
            }
        },
        .MOUSE_MOTION => {
            app_state.phys_controller.m_xrel += event.mouse_motion.delta.x;
        },
        .GAMEPAD_ADDED => {
            if (app_state.gamepad == null) {
                app_state.gamepad = try event.gamepad_device.controller_id.open_gamepad();
            }
        },
        .GAMEPAD_REMOVED => {
            if (app_state.gamepad) |pad| {
                pad.close();
                app_state.gamepad = null;
            }
        },
        .GAMEPAD_BUTTON_DOWN, .GAMEPAD_BUTTON_UP => {
            const is_down = event.type == .GAMEPAD_BUTTON_DOWN;
            switch (event.gamepad_button.button) {
                .DPAD_LEFT => app_state.phys_controller.g_left = is_down,
                .DPAD_RIGHT => app_state.phys_controller.g_right = is_down,
                .LEFT_SHOULDER => app_state.phys_controller.g_left_shoulder = is_down,
                .RIGHT_SHOULDER => app_state.phys_controller.g_right_shoulder = is_down,
                .SOUTH => app_state.phys_controller.g_south = is_down,
                .EAST => app_state.phys_controller.g_east = is_down,
                .BACK => app_state.phys_controller.g_back = is_down,
                .START => app_state.phys_controller.g_start = is_down,
                else => {},
            }
        },
        .GAMEPAD_AXIS_MOTION => {
            switch (event.gamepad_axis.axis) {
                .LEFTX => app_state.phys_controller.g_leftx = event.gamepad_axis.value,
                .LEFT_TRIGGER => app_state.phys_controller.g_left_trigger = event.gamepad_axis.value,
                .RIGHT_TRIGGER => app_state.phys_controller.g_right_trigger = event.gamepad_axis.value,
                else => {},
            }
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

    if (app_state.fully_initialized) {
        if (app_state.gamepad) |pad| pad.close();
        while (app_state.audio_streams.len != 0) {
            app_state.audio_streams[app_state.audio_streams.len - 1].destroy();
            app_state.audio_streams.len -= 1;
        }
        app_state.audio_device.close();
        app_state.sounds.destroy();
        app_state.sprite_texture.destroy();
        app_state.renderer.destroy();
        app_state.window.destroy();
        app_state.fully_initialized = false;
    }
}

fn sdl_main_func(arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return SDL.App.run_app_with_callbacks(arg_count, arg_list, sdl_init_func, sdl_update_func, sdl_event_func, sdl_quit_func);
}

fn sdl_init_func(appstate: ?*?*anyopaque, arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) SDL.AppResult {
    return app_init(appstate, arg_count, arg_list) catch |err| app_state.app_err.store(err);
}

fn sdl_update_func(appstate: ?*anyopaque) callconv(.c) SDL.AppResult {
    return app_update(appstate) catch |err| app_state.app_err.store(err);
}

fn sdl_event_func(appstate: ?*anyopaque, event: ?*SDL.Event) callconv(.c) SDL.AppResult {
    return handle_event(appstate, event) catch |err| app_state.app_err.store(err);
}

fn sdl_quit_func(appstate: ?*anyopaque, close_result: SDL.AppResult) callconv(.c) void {
    app_quit(appstate, app_state.app_err.load() orelse close_result);
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
