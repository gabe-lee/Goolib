const std = @import("std");

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

const best_score_storage_org_name = "goolib_samples";
const best_score_storage_app_name = "breakout";
const records_storage_file_name = "records";
const attempts_storage_file_name = "attempts";
var fully_initialized = false;
const window_size: IVec = IVec.new(640, 480);
var window: *SDL.Window = undefined;
var renderer: *SDL.Renderer = undefined;
var sprite_texture: *SDL.SimpleTexture = undefined;
var sounds: SDL.WaveAudio = undefined;
var audio_device: SDL.AudioDeviceID = undefined;
var audio_streams_buf: [8]*SDL.AudioStream = undefined;
var audio_streams: []*SDL.AudioStream = audio_streams_buf[0..0];
var gamepad: ?*SDL.Gamepad = undefined;
var phcon: PhysicalControllerState = undefined;
var prev_phcon: PhysicalControllerState = undefined;
var vcon: VirtualControllerState = undefined;
var prev_vcon: VirtualControllerState = undefined;
var best_win: u32 = undefined;
var timekeeper: Timekeeper = undefined;

var app_err: ErrorStore = .{};

var paddle: Paddle = undefined;
var ball: Ball = undefined;
var bricks: std.BoundedArray(Brick, 100) = undefined;

var won = false;
var records_need_save = false;

var score: u32 = undefined;
var score_color: SDL.Color_RGBA_u8 = undefined;

var attempts: u32 = 0;

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(SDL.run_app(empty_argv.len, @ptrCast(&empty_argv), sdl_main_func))));
    return app_err.load() orelse status;
}

pub fn app_init(args_list: [][*:0]u8) anyerror!SDL.AppProcess {
    _ = args_list;

    var write_buf = std.BoundedArray(u8, 250).init(0) catch unreachable;

    sdl_log.debug("SDL build time version: {d}.{d}.{d}", .{
        SDL.BUILD_MAJOR_VERSION,
        SDL.BUILD_MINOR_VERSION,
        SDL.BUILD_MICRO_VERSION,
    });
    sdl_log.debug("SDL build time revision: {s}", .{SDL.BUILD_REVISION});
    {
        const version = SDL.runtime_version();
        sdl_log.debug("SDL runtime version: {d}.{d}.{d}", .{
            SDL.RUNTIME_MAJOR_VERSION(version),
            SDL.RUNTIME_MINOR_VERSION(version),
            SDL.RUNTIME_MICRO_VERSION(version),
        });
        const revision: [*:0]const u8 = SDL.runtime_revision();
        sdl_log.debug("SDL runtime revision: {s}", .{revision});
    }

    try SDL.set_metadata("Breakout Sample", "0.0.0", "sample.goolib.breakout");
    try SDL.init(SDL.InitFlags.new(&.{ .VIDEO, .AUDIO, .GAMEPAD }));
    write_buf.clear();
    sdl_log.debug("SDL video drivers: {s}", .{try fmt_sdl_drivers(
        &write_buf,
        try SDL.get_current_video_driver(),
        SDL.get_num_video_drivers(),
        SDL.get_video_driver,
    )});
    write_buf.clear();
    sdl_log.debug("SDL audio drivers: {s}", .{try fmt_sdl_drivers(
        &write_buf,
        try SDL.get_current_audio_driver(),
        SDL.get_num_audio_drivers(),
        SDL.get_audio_driver,
    )});

    SDL.set_hint(SDL.HINT.RENDER_VSYNC, "1") catch {};

    window = try SDL.Window.create(.{ .title = "Breakout Sample", .size = window_size });
    errdefer window.destroy();
    renderer = try window.create_renderer();
    errdefer renderer.destroy();

    write_buf.clear();
    sdl_log.debug("SDL render drivers: {s}", .{try fmt_sdl_drivers(
        &write_buf,
        try renderer.get_name(),
        SDL.Renderer.get_driver_count(),
        SDL.Renderer.get_driver_name,
    )});

    {
        const stream = try SDL.IOStream.from_const_mem(Sprites.bmp[0..Sprites.bmp.len]);
        const surface = try stream.save_bmp_to_new_surface(true);
        defer surface.destroy();

        sprite_texture = try renderer.create_texture_from_surface(surface);
        errdefer comptime unreachable;
    }
    errdefer sprite_texture.destroy();

    {
        const stream = try SDL.IOStream.from_const_mem(Sounds.wav[0..Sounds.wav.len]);
        sounds = try stream.load_wav(true);
        errdefer comptime unreachable;
    }
    errdefer sounds.destroy();

    audio_device = try SDL.AudioDeviceID.DEFAULT_PLAYBACK_DEVICE.open_device(.spec(&sounds.spec));
    errdefer audio_device.close();

    errdefer while (audio_streams.len != 0) {
        audio_streams[audio_streams.len - 1].destroy();
        if (audio_streams.len != 0) audio_streams.len -= 1;
    };
    while (audio_streams.len < audio_streams_buf.len) {
        audio_streams.len += 1;
        audio_streams[audio_streams.len - 1] = try SDL.AudioStream.create(.same_input_and_output(&sounds.spec));
    }

    try audio_device.bind_many_audio_streams(audio_streams);

    {
        const gamepads_list = try SDL.JoystickID.get_all_gamepads();
        defer gamepads_list.free();

        gamepad = if (gamepads_list.list.len > 0) try gamepads_list.list[0].open_gamepad() else null;
    }
    errdefer if (gamepad) |pad| pad.close();

    phcon = .{};
    prev_phcon = phcon;
    vcon = .{};
    prev_vcon = vcon;

    try load_records();

    timekeeper = .{ .tocks_per_s = SDL.get_performance_frequency() };

    try reset_game();

    fully_initialized = true;
    errdefer comptime unreachable;

    return SDL.AppProcess.CONTINUE;
}

const Sprites = struct {
    const bmp = @embedFile("sprites.bmp");

    // zig fmt: off
    const brick_2x1_purple = SDL.Rect_f32{ .x =   1, .y =  1, .w = 64, .h = 32 };
    const brick_1x1_purple = SDL.Rect_f32{ .x =  67, .y =  1, .w = 32, .h = 32 };
    const brick_2x1_red    = SDL.Rect_f32{ .x = 101, .y =  1, .w = 64, .h = 32 };
    const brick_1x1_red    = SDL.Rect_f32{ .x = 167, .y =  1, .w = 32, .h = 32 };
    const brick_2x1_yellow = SDL.Rect_f32{ .x =   1, .y = 35, .w = 64, .h = 32 };
    const brick_1x1_yellow = SDL.Rect_f32{ .x =  67, .y = 35, .w = 32, .h = 32 };
    const brick_2x1_green  = SDL.Rect_f32{ .x = 101, .y = 35, .w = 64, .h = 32 };
    const brick_1x1_green  = SDL.Rect_f32{ .x = 167, .y = 35, .w = 32, .h = 32 };
    const brick_2x1_blue   = SDL.Rect_f32{ .x =   1, .y = 69, .w = 64, .h = 32 };
    const brick_1x1_blue   = SDL.Rect_f32{ .x =  67, .y = 69, .w = 32, .h = 32 };
    const brick_2x1_gray   = SDL.Rect_f32{ .x = 101, .y = 69, .w = 64, .h = 32 };
    const brick_1x1_gray   = SDL.Rect_f32{ .x = 167, .y = 69, .w = 32, .h = 32 };
 
    const ball             = SDL.Rect_f32{ .x =  2, .y = 104, .w =  22, .h = 22 };
    const paddle           = SDL.Rect_f32{ .x = 27, .y = 103, .w = 104, .h = 24 };
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

    fn store(es: *ErrorStore, err: anyerror) SDL.AppProcess {
        if (es.status.compare_and_swap(STATUS_NOT_STORED, STATUS_STORING)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = es.status.set(STATUS_STORED);
        }
        return SDL.AppProcess.CLOSE_ERROR;
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
        const min_x = b.x - a.w;
        const max_x = b.x + b.w;
        if (a.x > min_x and a.x < max_x) {
            const min_y = b.y - a.h;
            const max_y = b.y + b.h;
            if (a.y > min_y and a.y < max_y) {
                return true;
            }
        }
        return false;
    }

    fn sweep_test(a: Rect, a_vel: FVec, b: Rect, b_vel: FVec) ?Collision {
        const vel_x_inv = 1 / (a_vel.x - b_vel.x);
        const vel_y_inv = 1 / (a_vel.y - b_vel.y);
        const min_x = b.x - a.w;
        const min_y = b.y - a.h;
        const max_x = b.x + b.w;
        const max_y = b.y + b.h;
        const t_min_x = (min_x - a.x) * vel_x_inv;
        const t_min_y = (min_y - a.y) * vel_y_inv;
        const t_max_x = (max_x - a.x) * vel_x_inv;
        const t_max_y = (max_y - a.y) * vel_y_inv;
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
        const min_x = paddle_.box.x - ball_.box.w;
        const max_x = paddle_.box.x + paddle_.box.w;
        const min_angle = std.math.degreesToRadians(195);
        const max_angle = std.math.degreesToRadians(345);
        const angle = ((ball_.box.x - min_x) / (max_x - min_x)) * (max_angle - min_angle) + min_angle;
        return std.math.clamp(angle, min_angle, max_angle);
    }
};

const Brick = struct {
    box: Rect,
    src_rect: *const SDL.Rect_f32,
};

fn fmt_sdl_drivers(write_buf: *std.BoundedArray(u8, 250), current_driver: [*:0]const u8, num_drivers: c_int, get_driver: *const fn (c_int) SDL.Error![*:0]const u8) anyerror![]const u8 {
    var writer = write_buf.writer();
    var i: c_int = 0;
    while (i < num_drivers) : (i += 1) {
        const driver_name = try get_driver(i);
        // _ = c_strings_equal(driver_name, current_driver);
        const is_current = c_strings_equal(driver_name, current_driver);
        if (is_current) _ = try writer.write(ANSI.BEGIN ++ ANSI.FG_GREEN ++ ANSI.END);
        try writer.print("\n\t({d}) {s}", .{ i, driver_name });
        if (is_current) _ = try writer.write(ANSI.BEGIN ++ ANSI.RESET ++ ANSI.END);
    }
    return write_buf.slice();
}

fn load_records() !void {
    const storage = try SDL.Storage.open_user_storage_folder(best_score_storage_org_name, best_score_storage_app_name, SDL.PropertiesID{});
    defer storage.close() catch {};

    while (!storage.is_ready()) {
        var total_time: u32 = 0;
        SDL.wait_milliseconds(10);
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
    attempts = try stream.read_u32_le();
    best_win = try stream.read_u32_le();

    app_log.debug("loaded records:\n\tattempts = {d}\n\tbest win: {d}", .{ attempts, best_win });
}

fn save_records() !void {
    const storage = try SDL.Storage.open_user_storage_folder(best_score_storage_org_name, best_score_storage_app_name, SDL.PropertiesID{});
    defer storage.close() catch {};

    while (!storage.is_ready()) {
        var total_time: u32 = 0;
        SDL.wait_milliseconds(10);
        total_time += 10;
        if (total_time > 10000) return error.save_best_score_ready_timeout;
    }
    records_need_save = false;

    const new_best_win = if (won and score < best_win) score else best_win;
    var buf: [8:0]u8 = undefined;
    const stream = try SDL.IOStream.from_mem(buf[0..8]);
    defer stream.close() catch {};
    try stream.write_u32_le(attempts);
    try stream.write_u32_le(new_best_win);
    try storage.write_file_from_buffer(records_storage_file_name, buf[0..8]);
    app_log.debug("saved records:\n\tattempts = {d}\n\tbest win: {d}", .{ attempts, new_best_win });
}

fn reset_game() !void {
    won = false;
    records_need_save = false;
    attempts += 1;
    paddle = .{
        .box = .{
            .x = Cast.to(f32, window_size.x) * 0.5 - Sprites.paddle.w * 0.5,
            .y = Cast.to(f32, window_size.y) - Sprites.paddle.h,
            .w = Sprites.paddle.w,
            .h = Sprites.paddle.h,
        },
        .src_rect = &Sprites.paddle,
    };

    ball = .{
        .box = .{
            .x = paddle.box.x + paddle.box.w * 0.5,
            .y = paddle.box.y - Sprites.ball.h,
            .w = Sprites.ball.w,
            .h = Sprites.ball.h,
        },
        .vel = FVec.new(0, 0),
        .launched = false,
        .src_rect = &Sprites.ball,
    };

    bricks = .{};
    {
        const x = Cast.to(f32, window_size.x) * 0.5;
        const h = Sprites.brick_1x1_gray.h;
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
            try bricks.append(.{
                .box = .{
                    .x = x - src_rect.w * 0.5,
                    .y = y,
                    .w = src_rect.w,
                    .h = src_rect.h,
                },
                .src_rect = src_rect,
            });
            var rel_x: f32 = 0;
            var count: usize = 0;
            while (count < 4) : (count += 1) {
                rel_x += src_rect.w * 0.5 + gap;
                large = !large;
                src_rect = src_rects[@intFromBool(large)];
                rel_x += src_rect.w * 0.5;
                for ([_]f32{ -1, 1 }) |sign| {
                    try bricks.append(.{
                        .box = .{
                            .x = x - src_rect.w * 0.5 + rel_x * sign,
                            .y = y,
                            .w = src_rect.w,
                            .h = src_rect.h,
                        },
                        .src_rect = src_rect,
                    });
                }
            }
        }
    }

    score = 0;
    score_color = SDL.Color_RGBA_u8.new_opaque(0xff, 0xff, 0xff);
}

fn app_update() !SDL.AppProcess {
    var sounds_to_play: std.EnumSet(enum {
        hit_wall,
        hit_paddle,
        hit_brick,
        win,
        lose,
    }) = .initEmpty();

    // Update the game state.
    while (timekeeper.consume()) {
        // Map the physical controller state to the virtual controller state.

        prev_vcon = vcon;
        vcon.move_paddle_exact = 0;

        vcon.move_paddle_left =
            phcon.k_left or
            phcon.g_left or
            phcon.g_leftx <= -0x4000;
        vcon.move_paddle_right =
            phcon.k_right or
            phcon.g_right or
            phcon.g_leftx >= 0x4000;
        vcon.slow_paddle_movement =
            phcon.k_lshift or
            phcon.g_left_shoulder or
            phcon.g_right_shoulder or
            phcon.g_left_trigger >= 0x2000 or
            phcon.g_right_trigger >= 0x2000;
        vcon.launch_ball =
            phcon.k_space or
            phcon.g_south or
            phcon.g_east;
        vcon.reset_game =
            phcon.k_r or
            phcon.g_back or
            phcon.g_start;

        if (!vcon.lock_mouse) {
            if (phcon.m_left and !prev_phcon.m_left) {
                vcon.lock_mouse = true;
                try window.set_mouse_mode_relative(true);
            }
        } else {
            if (phcon.k_escape and !prev_phcon.k_escape) {
                vcon.lock_mouse = false;
                try window.set_mouse_mode_relative(false);
            } else {
                vcon.launch_ball = vcon.launch_ball or phcon.m_left;
                vcon.move_paddle_exact = phcon.m_xrel;
            }
        }

        prev_phcon = phcon;
        phcon.m_xrel = 0;

        if (vcon.reset_game and !prev_vcon.reset_game) {
            try reset_game();
            return SDL.AppProcess.CONTINUE;
        }

        // Move the paddle.
        {
            var paddle_vel_x: f32 = 0;
            var keyboard_gamepad_vel_x: f32 = 0;
            if (vcon.move_paddle_left) keyboard_gamepad_vel_x -= 10;
            if (vcon.move_paddle_right) keyboard_gamepad_vel_x += 10;
            if (vcon.slow_paddle_movement) keyboard_gamepad_vel_x *= 0.5;
            paddle_vel_x += keyboard_gamepad_vel_x;
            var mouse_vel_x = vcon.move_paddle_exact;
            if (vcon.slow_paddle_movement) mouse_vel_x *= 0.25;
            paddle_vel_x += mouse_vel_x;
            paddle.box.x = std.math.clamp(paddle.box.x + paddle_vel_x, 0, window_size.x - paddle.box.w);
        }

        const previous_ball_y = ball.box.y;

        if (!ball.launched) {
            // Stick the ball to the paddle.
            ball.box.x = paddle.box.x + paddle.box.w * 0.5;

            if (vcon.launch_ball and !prev_vcon.launch_ball) {
                // Launch the ball.
                const angle = ball.get_paddle_bounce_angle(paddle);
                ball.vel.x = @cos(angle) * 4;
                ball.vel.y = @sin(angle) * 4;
                ball.launched = true;
            }
        }

        if (ball.launched) {
            // Check for and handle collisions using swept AABB collision detection.
            var rem_vel: FVec = ball.vel;
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
                    const wall_t = -ball.box.x * inv_rem_vel.x;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_x = 1;
                        collidee = .wall;
                    }
                } else if (rem_vel.x > 0) {
                    // Right wall
                    const wall_t = (window_size.x - ball.box.w - ball.box.x) * inv_rem_vel.x;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_x = -1;
                        collidee = .wall;
                    }
                }
                if (rem_vel.y < 0) {
                    // Top wall
                    const wall_t = -ball.box.y * inv_rem_vel.y;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_y = 1;
                        collidee = .wall;
                    }
                } else if (rem_vel.y > 0) {
                    // Paddle
                    const paddle_top: Rect = .{
                        .x = paddle.box.x,
                        .y = paddle.box.y,
                        .w = paddle.box.w,
                        .h = 0,
                    };
                    if (Collision.sweep_test(ball.box, rem_vel, paddle_top, FVec.ZERO_ZERO)) |collision| {
                        if (t - collision.t >= 0.001) {
                            t = @min(0, collision.t);
                            sign_y = -1;
                            collidee = .paddle;
                        }
                    }
                }

                // Bricks
                const broad: Rect = .{
                    .x = @min(ball.box.x, ball.box.x + rem_vel.x),
                    .y = @min(ball.box.y, ball.box.y + rem_vel.y),
                    .w = @max(ball.box.w, ball.box.w + rem_vel.x),
                    .h = @max(ball.box.h, ball.box.h + rem_vel.y),
                };
                for (bricks.slice(), 0..) |brick, i| {
                    if (Collision.intersects(broad, brick.box)) {
                        if (Collision.sweep_test(ball.box, rem_vel, brick.box, FVec.ZERO_ZERO)) |collision| {
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
                    const angle = ball.get_paddle_bounce_angle(paddle);
                    const vel_factor = 1.05;
                    ball.box.x += rem_vel.x * t;
                    ball.box.y += rem_vel.y * t;
                    const vel = @sqrt(ball.vel.x * ball.vel.x + ball.vel.y * ball.vel.y) * vel_factor;
                    ball.vel.x = @cos(angle) * vel;
                    ball.vel.y = @sin(angle) * vel;
                    rem_vel.x *= (1 - t);
                    rem_vel.y *= (1 - t);
                    const remaining_vel = @sqrt(rem_vel.x * rem_vel.x + rem_vel.y * rem_vel.y) * vel_factor;
                    rem_vel.x = @cos(angle) * remaining_vel;
                    rem_vel.y = @sin(angle) * remaining_vel;
                } else {
                    ball.box.x += rem_vel.x * t;
                    ball.box.y += rem_vel.y * t;
                    ball.vel.x = std.math.copysign(ball.vel.x, if (sign_x != 0) sign_x else rem_vel.x);
                    ball.vel.y = std.math.copysign(ball.vel.y, if (sign_y != 0) sign_y else rem_vel.y);
                    rem_vel.x = std.math.copysign(rem_vel.x * (1 - t), ball.vel.x);
                    rem_vel.y = std.math.copysign(rem_vel.y * (1 - t), ball.vel.y);
                    if (collidee == .brick) {
                        _ = bricks.swapRemove(collidee.brick);
                    }
                }

                // Enqueue an appropriate sound effect.
                switch (collidee) {
                    .wall => {
                        if (ball.box.y < window_size.y) {
                            sounds_to_play.insert(.hit_wall);
                        }
                    },
                    .paddle => {
                        sounds_to_play.insert(.hit_paddle);
                    },
                    .brick => {
                        if (bricks.len == 0) {
                            won = true;
                            records_need_save = true;
                            sounds_to_play.insert(.win);
                        } else {
                            sounds_to_play.insert(.hit_brick);
                        }
                    },
                    .none => {},
                }
            }
        }

        if (previous_ball_y < window_size.y and ball.box.y >= window_size.y) {
            // The ball fell below the paddle.
            if (bricks.len != 0) {
                sounds_to_play.insert(.lose);
                records_need_save = true;
            }
        }

        // Update score.
        if (ball.launched) {
            if (ball.box.y < window_size.y) {
                if (bricks.len != 0) {
                    score +|= 1;
                } else {
                    best_win = @min(score, best_win);
                }
            }
            if (score <= best_win and bricks.len == 0) {
                score_color = SDL.Color_RGBA_u8.new_opaque(0x52, 0xcc, 0x73);
            } else if (ball.box.y >= window_size.y or score > best_win) {
                score_color = SDL.Color_RGBA_u8.new_opaque(0xcc, 0x5c, 0x52);
            }
        }
    }

    // Save score.
    if (records_need_save) {
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
            const stream = find_available_stream: while (stream_index < audio_streams.len) {
                defer stream_index += 1;
                const stream = audio_streams[stream_index];
                if (try stream.get_bytes_available_to_take_out() == 0) {
                    break :find_available_stream stream;
                }
            } else {
                break :iterate_sounds;
            };
            const frame_size: usize = @intCast(sounds.spec.frame_size());
            const start: usize, const end: usize = switch (sound) {
                .hit_wall => Sounds.hit_wall,
                .hit_paddle => Sounds.hit_paddle,
                .hit_brick => Sounds.hit_brick,
                .win => Sounds.win,
                .lose => Sounds.lose,
            };
            const data = sounds.data[(frame_size * start)..(frame_size * end)];
            try stream.put_in_audio_data(data);
        }
    }

    // Draw.
    {
        const CLEAR_COLOR = SDL.Color_RGBA_u8.new(0x47, 0x5b, 0x8d, 0xff);
        try renderer.set_draw_color(CLEAR_COLOR);
        try renderer.draw_clear_fill();

        for (bricks.slice()) |brick| try renderer.draw_texture_rect(sprite_texture, .rect(brick.src_rect), .rect(&brick.box));
        try renderer.draw_texture_rect(sprite_texture, .rect(ball.src_rect), .rect(&ball.box));
        try renderer.draw_texture_rect(sprite_texture, .rect(paddle.src_rect), .rect(&paddle.box));

        try renderer.set_render_scale(FVec.new(2, 2));
        {
            var buf: [13]u8 = undefined;
            var time: f32 = @min(@as(f32, @floatFromInt(score)) / Timekeeper.updates_per_s, 999.999);
            var text = try std.fmt.bufPrintZ(&buf, "TIME {d: >7.3}", .{time});
            try renderer.set_draw_color(score_color);
            try renderer.draw_debug_text(FVec.new(8, 8), text.ptr);
            time = @min(@as(f32, @floatFromInt(best_win)) / Timekeeper.updates_per_s, 999.999);
            text = try std.fmt.bufPrintZ(&buf, "BEST {d: >7.3}", .{time});
            try renderer.set_draw_color(SDL.Color_RGBA_u8.WHITE);
            try renderer.draw_debug_text(FVec.new(window_size.x / 2 - 8 * 12, 8), text.ptr);
        }
        try renderer.set_render_scale(FVec.new(1, 1));
        try renderer.present();
    }

    timekeeper.produce(SDL.get_performance_counter());

    return SDL.AppProcess.CONTINUE;
}

fn handle_event(event: *SDL.Event) !SDL.AppProcess {
    switch (event.type) {
        .QUIT => {
            return SDL.AppProcess.CLOSE_NORMAL;
        },
        .KEY_DOWN, .KEY_UP => {
            const is_down = event.type == .KEY_DOWN;
            switch (event.keyboard.scancode) {
                .LEFT => phcon.k_left = is_down,
                .RIGHT => phcon.k_right = is_down,
                .LSHIFT => phcon.k_lshift = is_down,
                .SPACE => phcon.k_space = is_down,
                .R => phcon.k_r = is_down,
                .ESCAPE => phcon.k_escape = is_down,
                else => {},
            }
        },
        .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP => {
            const is_down = event.type == .MOUSE_BUTTON_DOWN;
            switch (event.mouse_button.button) {
                .LEFT => phcon.m_left = is_down,
                else => {},
            }
        },
        .MOUSE_MOTION => {
            phcon.m_xrel += event.mouse_motion.delta.x;
        },
        .GAMEPAD_ADDED => {
            if (gamepad == null) {
                gamepad = try event.gamepad_device.controller_id.open_gamepad();
            }
        },
        .GAMEPAD_REMOVED => {
            if (gamepad) |pad| {
                pad.close();
                gamepad = null;
            }
        },
        .GAMEPAD_BUTTON_DOWN, .GAMEPAD_BUTTON_UP => {
            const is_down = event.type == .GAMEPAD_BUTTON_DOWN;
            switch (event.gamepad_button.button) {
                .DPAD_LEFT => phcon.g_left = is_down,
                .DPAD_RIGHT => phcon.g_right = is_down,
                .LEFT_SHOULDER => phcon.g_left_shoulder = is_down,
                .RIGHT_SHOULDER => phcon.g_right_shoulder = is_down,
                .SOUTH => phcon.g_south = is_down,
                .EAST => phcon.g_east = is_down,
                .BACK => phcon.g_back = is_down,
                .START => phcon.g_start = is_down,
                else => {},
            }
        },
        .GAMEPAD_AXIS_MOTION => {
            switch (event.gamepad_axis.axis) {
                .LEFTX => phcon.g_leftx = event.gamepad_axis.value,
                .LEFT_TRIGGER => phcon.g_left_trigger = event.gamepad_axis.value,
                .RIGHT_TRIGGER => phcon.g_right_trigger = event.gamepad_axis.value,
                else => {},
            }
        },
        else => {},
    }

    return SDL.AppProcess.CONTINUE;
}

fn app_quit(result: anyerror!SDL.AppProcess) void {
    _ = result catch |err| switch (err) {
        SDL.Error.SDL_null_value,
        SDL.Error.SDL_operation_failure,
        SDL.Error.SDL_invalid_value,
        => {
            sdl_log.err("{s}: {s}", .{ @errorName(err), SDL.get_error_details() });
        },
        else => {
            app_log.err("{s}", .{@errorName(err)});
        },
    };

    if (fully_initialized) {
        if (gamepad) |pad| pad.close();
        while (audio_streams.len != 0) {
            audio_streams[audio_streams.len - 1].destroy();
            audio_streams.len -= 1;
        }
        audio_device.close();
        sounds.destroy();
        sprite_texture.destroy();
        renderer.destroy();
        window.destroy();
        fully_initialized = false;
    }
}

fn sdl_main_func(arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return SDL.run_app_with_callbacks(arg_count, arg_list, sdl_init_func, sdl_update_func, sdl_event_func, sdl_quit_func);
}

fn sdl_init_func(appstate: ?*?*anyopaque, arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) c_uint {
    _ = appstate;
    const zig_args = Goolib.Utils.c_args_to_zig_args(.c_args_list(arg_count, arg_list));
    const process = app_init(zig_args) catch |err| app_err.store(err);
    return @intFromEnum(process);
}

fn sdl_update_func(appstate: ?*anyopaque) callconv(.c) c_uint {
    _ = appstate;
    const process = app_update() catch |err| app_err.store(err);
    return @intFromEnum(process);
}

fn sdl_event_func(appstate: ?*anyopaque, event: ?*SDL.C_Event) callconv(.c) c_uint {
    _ = appstate;
    const process = handle_event(SDL.Event.from_c(event.?)) catch |err| app_err.store(err);
    return @intFromEnum(process);
}

fn sdl_quit_func(appstate: ?*anyopaque, close_state: c_uint) callconv(.c) void {
    _ = appstate;
    app_quit(app_err.load() orelse @enumFromInt(close_state));
}
