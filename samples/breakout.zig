const std = @import("std");

const sdl_log = std.log.scoped(.sdl);
const app_log = std.log.scoped(.app);

const Goolib = @import("Goolib");
const SDL = Goolib.SDL3;
const AABB = Goolib.AABB2.define_aabb2_type(f32);
const Rect = Goolib.Rect2.define_rect2_type(f32);
const FVec: type = SDL.FVec;
const IVec: type = SDL.IVec;
const c_strings_equal = Goolib.Utils.c_strings_equal;
const ansi = Goolib.ANSI.ansi;

const best_score_storage_org_name = "goolib_samples";
const best_score_storage_app_name = "breakout";
const best_score_storage_file_name = "best_score";
var fully_initialized = false;
const window_size: IVec = IVec.new(640, 480);
var window: *SDL.Window = undefined;
var renderer: *SDL.Renderer = undefined;
var sprite_texture: *SDL.Texture = undefined;
var sounds: SDL.WaveAudio = undefined;
var audio_device: SDL.AudioDeviceID = undefined;
var audio_streams_buf: [8]*SDL.AudioStream = undefined;
var audio_streams: []*SDL.AudioStream = audio_streams_buf[0..0];
var gamepad: ?*SDL.Gamepad = undefined;
var phcon: PhysicalControllerState = undefined;
var prev_phcon: PhysicalControllerState = undefined;
var vcon: VirtualControllerState = undefined;
var prev_vcon: VirtualControllerState = undefined;
var best_score: u32 = undefined;
var timekeeper: Timekeeper = undefined;

var app_err: ErrorStore = .{};

var paddle: Paddle = undefined;
var ball: Ball = undefined;
var bricks: std.BoundedArray(Brick, 100) = undefined;

var score: u32 = undefined;
var score_color: [3]u8 = undefined;

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(c.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;
}

pub fn app_init(app_state: ?*?*anyopaque, args_list: [][*:0]u8) SDL.Error!SDL.AppProcess {
    _ = app_state;
    _ = args_list;

    var write_buf = std.BoundedArray(u8, 200).init(0);

    sdl_log.debug("SDL build time version: {d}.{d}.{d}", .{
        SDL.Meta.BUILD_MAJOR_VERSION,
        SDL.Meta.BUILD_MINOR_VERSION,
        SDL.Meta.BUILD_MICRO_VERSION,
    });
    sdl_log.debug("SDL build time revision: {s}", .{SDL.Meta.BUILD_REVISION});
    {
        const version = SDL.Meta.get_version();
        sdl_log.debug("SDL runtime version: {d}.{d}.{d}", .{
            SDL.Meta.RUNTIME_MAJOR_VERSION(version),
            SDL.Meta.RUNTIME_MINOR_VERSION(version),
            SDL.Meta.RUNTIME_MICRO_VERSION(version),
        });
        const revision: [*:0]const u8 = SDL.Meta.runtime_revision();
        sdl_log.debug("SDL runtime revision: {s}", .{revision});
    }

    try SDL.App.set_metadata("Breakout Sample", "0.0.0", "sample.goolib.breakout");
    try SDL.App.init(SDL.InitFlags.new(.{ .VIDEO, .AUDIO, .GAMEPAD }));
    write_buf.clear();
    sdl_log.debug("SDL video drivers: {s}", .{fmt_sdl_drivers(
        &write_buf,
        SDL.get_current_video_driver().?,
        SDL.get_num_video_drivers(),
        SDL.get_video_driver,
    )});
    write_buf.clear();
    sdl_log.debug("SDL audio drivers: {s}", .{fmt_sdl_drivers(
        &write_buf,
        SDL.get_current_audio_driver().?,
        SDL.get_num_audio_drivers(),
        SDL.get_audio_driver,
    )});

    SDL.set_hint(SDL.HINT.RENDER_VSYNC, "1") catch {};

    window = try SDL.Window.create(.{ .title = "Breakout Sample", .size = window_size });
    errdefer window.destroy();
    renderer = try window.create_renderer("main_window_renderer");
    errdefer renderer.destroy();

    write_buf.clear();
    sdl_log.debug("SDL render drivers: {s}", .{fmt_sdl_drivers(
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
        const stream = SDL.IOStream.from_const_mem(Sounds.wav[0..Sounds.wav.len]);
        sounds = try stream.load_wav(true);
        errdefer comptime unreachable;
    }
    errdefer sounds.free();

    audio_device = try SDL.AudioDeviceID.DEFAULT_PLAYBACK_DEVICE.open_device(.spec(&sounds.spec));
    errdefer audio_device.close_device();

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
        const gamepads_list = try SDL.GameControllerID.get_all_gamepads();
        defer gamepads_list.free();

        gamepad = if (gamepads_list.list.len > 0) try gamepads_list.list[0].open_gamepad() else null;
    }
    errdefer if (gamepad) |pad| pad.close();

    phcon = .{};
    prev_phcon = phcon;
    vcon = .{};
    prev_vcon = vcon;

    try load_best_score();

    timekeeper = .{ .tocks_per_s = SDL.get_performance_frequency() };

    try reset_game();

    fully_initialized = true;
    errdefer comptime unreachable;

    return SDL.AppProcess.CONTINUE;
}

const Sprites = struct {
    const bmp = @embedFile("sprites.bmp");

    // zig fmt: off
    const brick_2x1_purple = SDL.FRect{ .x =   1, .y =  1, .w = 64, .h = 32 };
    const brick_1x1_purple = SDL.FRect{ .x =  67, .y =  1, .w = 32, .h = 32 };
    const brick_2x1_red    = SDL.FRect{ .x = 101, .y =  1, .w = 64, .h = 32 };
    const brick_1x1_red    = SDL.FRect{ .x = 167, .y =  1, .w = 32, .h = 32 };
    const brick_2x1_yellow = SDL.FRect{ .x =   1, .y = 35, .w = 64, .h = 32 };
    const brick_1x1_yellow = SDL.FRect{ .x =  67, .y = 35, .w = 32, .h = 32 };
    const brick_2x1_green  = SDL.FRect{ .x = 101, .y = 35, .w = 64, .h = 32 };
    const brick_1x1_green  = SDL.FRect{ .x = 167, .y = 35, .w = 32, .h = 32 };
    const brick_2x1_blue   = SDL.FRect{ .x =   1, .y = 69, .w = 64, .h = 32 };
    const brick_1x1_blue   = SDL.FRect{ .x =  67, .y = 69, .w = 32, .h = 32 };
    const brick_2x1_gray   = SDL.FRect{ .x = 101, .y = 69, .w = 64, .h = 32 };
    const brick_1x1_gray   = SDL.FRect{ .x = 167, .y = 69, .w = 32, .h = 32 };
 
    const ball             = SDL.FRect{ .x =  2, .y = 104, .w =  22, .h = 22 };
    const paddle           = SDL.FRect{ .x = 27, .y = 103, .w = 104, .h = 24 };
    // zig fmt: on
};

const ErrorStore = struct {
    const status_not_stored = 0;
    const status_storing = 1;
    const status_stored = 2;

    status: c.SDL_AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    fn reset(es: *ErrorStore) void {
        _ = c.SDL_SetAtomicInt(&es.status, status_not_stored);
    }

    fn store(es: *ErrorStore, err: anyerror) c.SDL_AppResult {
        if (c.SDL_CompareAndSwapAtomicInt(&es.status, status_not_stored, status_storing)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = c.SDL_SetAtomicInt(&es.status, status_stored);
        }
        return c.SDL_APP_FAILURE;
    }

    fn load(es: *ErrorStore) ?anyerror {
        if (c.SDL_GetAtomicInt(&es.status) != status_stored) return null;
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
    src_rect: *const SDL.FRect,

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
    src_rect: *const SDL.FRect,
};

fn fmt_sdl_drivers(write_buf: *std.BoundedArray(u8, 250), current_driver: [*:0]const u8, num_drivers: c_int, get_driver: *const fn (c_int) SDL.Error![*:0]const u8) SDL.Error![]const u8 {
    var writer = write_buf.writer();
    var i: c_int = 0;
    while (i < num_drivers) : (i += 1) {
        const driver_name = try get_driver(i);
        const is_current = c_strings_equal(driver_name, current_driver);
        if (is_current) writer.write(ansi(.{.FG_GREEN}));
        writer.print("\n\t({d}) {s}", .{ i, driver_name });
        if (is_current) writer.write(ansi(.{.RESET}));
    }
    return write_buf.slice();
}

fn load_best_score() !void {
    const storage = try SDL.Storage.open_user_storage_folder(best_score_storage_org_name, best_score_storage_app_name, SDL.PropertiesID{});
    defer storage.close() catch {};

    while (!storage.is_ready()) {
        var total_time = 0;
        SDL.wait_milliseconds(10);
        total_time += 10;
        if (total_time > 10000) return error.load_best_score_ready_timeout;
    }

    const default_score = 100 * Timekeeper.updates_per_s;

    var best_score_le: [4]u8 = undefined;

    storage.read_file_into_buffer(best_score_storage_file_name, best_score_le[0..4]) catch |err| {
        app_log.debug("failed to load best score: {s}: {s}", .{ @errorName(err), SDL.get_error_details() });
        best_score = default_score;
        return err;
    };
    best_score = @min(std.mem.littleToNative(u32, best_score_le), default_score);

    app_log.debug("loaded best score: {}", .{best_score});
}

fn save_best_score() !void {
    const storage = try SDL.Storage.open_user_storage_folder(best_score_storage_org_name, best_score_storage_app_name, SDL.PropertiesID{});
    defer storage.close() catch {};

    while (!storage.is_ready()) {
        var total_time = 0;
        SDL.wait_milliseconds(10);
        total_time += 10;
        if (total_time > 10000) return error.save_best_score_ready_timeout;
    }

    const best_score_le: [4]u8 = @bitCast(std.mem.nativeToLittle(u32, best_score));
    try storage.write_file_from_buffer(best_score_storage_file_name, best_score_le[0..4]);

    app_log.debug("saved best score: {}", .{best_score});
}

fn reset_game() !void {
    //CHECKPOINT
    paddle = .{
        .box = .{
            .x = window_w * 0.5 - sprites.paddle.w * 0.5,
            .y = window_h - sprites.paddle.h,
            .w = sprites.paddle.w,
            .h = sprites.paddle.h,
        },
        .src_rect = &sprites.paddle,
    };

    ball = .{
        .box = .{
            .x = paddle.box.x + paddle.box.w * 0.5,
            .y = paddle.box.y - sprites.ball.h,
            .w = sprites.ball.w,
            .h = sprites.ball.h,
        },
        .vel_x = 0,
        .vel_y = 0,
        .launched = false,
        .src_rect = &sprites.ball,
    };

    bricks = .{};
    {
        const x = window_w * 0.5;
        const h = sprites.brick_1x1_gray.h;
        const gap = 5;
        for ([_][2]*const c.SDL_FRect{
            .{ &sprites.brick_1x1_purple, &sprites.brick_2x1_purple },
            .{ &sprites.brick_1x1_red, &sprites.brick_2x1_red },
            .{ &sprites.brick_1x1_yellow, &sprites.brick_2x1_yellow },
            .{ &sprites.brick_1x1_green, &sprites.brick_2x1_green },
            .{ &sprites.brick_1x1_blue, &sprites.brick_2x1_blue },
            .{ &sprites.brick_1x1_gray, &sprites.brick_2x1_gray },
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
    score_color = .{ 0xff, 0xff, 0xff };
}

fn app_update(appstate: ?*anyopaque) !SDL.AppProcess {
    _ = appstate;

    var sounds_to_play: std.EnumSet(enum {
        hit_wall,
        hit_paddle,
        hit_brick,
        win,
        lose,
    }) = .initEmpty();

    var won = false;

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
                try errify(c.SDL_SetWindowRelativeMouseMode(window, true));
            }
        } else {
            if (phcon.k_escape and !prev_phcon.k_escape) {
                vcon.lock_mouse = false;
                try errify(c.SDL_SetWindowRelativeMouseMode(window, false));
            } else {
                vcon.launch_ball = vcon.launch_ball or phcon.m_left;
                vcon.move_paddle_exact = phcon.m_xrel;
            }
        }

        prev_phcon = phcon;
        phcon.m_xrel = 0;

        if (vcon.reset_game and !prev_vcon.reset_game) {
            try resetGame();
            return c.SDL_APP_CONTINUE;
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
            paddle.box.x = std.math.clamp(paddle.box.x + paddle_vel_x, 0, window_w - paddle.box.w);
        }

        const previous_ball_y = ball.box.y;

        if (!ball.launched) {
            // Stick the ball to the paddle.
            ball.box.x = paddle.box.x + paddle.box.w * 0.5;

            if (vcon.launch_ball and !prev_vcon.launch_ball) {
                // Launch the ball.
                const angle = ball.getPaddleBounceAngle(paddle);
                ball.vel_x = @cos(angle) * 4;
                ball.vel_y = @sin(angle) * 4;
                ball.launched = true;
            }
        }

        if (ball.launched) {
            // Check for and handle collisions using swept AABB collision detection.
            var remaining_vel_x: f32 = ball.vel_x;
            var remaining_vel_y: f32 = ball.vel_y;
            while (remaining_vel_x != 0 or remaining_vel_y != 0) {
                var t: f32 = 1;
                var sign_x: f32 = 0;
                var sign_y: f32 = 0;
                var collidee: union(enum) {
                    none: void,
                    wall: void,
                    paddle: void,
                    brick: usize,
                } = .none;

                const remaining_vel_x_inv = 1 / remaining_vel_x;
                const remaining_vel_y_inv = 1 / remaining_vel_y;

                if (remaining_vel_x < 0) {
                    // Left wall
                    const wall_t = -ball.box.x * remaining_vel_x_inv;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_x = 1;
                        collidee = .wall;
                    }
                } else if (remaining_vel_x > 0) {
                    // Right wall
                    const wall_t = (window_w - ball.box.w - ball.box.x) * remaining_vel_x_inv;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_x = -1;
                        collidee = .wall;
                    }
                }
                if (remaining_vel_y < 0) {
                    // Top wall
                    const wall_t = -ball.box.y * remaining_vel_y_inv;
                    if (t - wall_t >= 0.001) {
                        t = wall_t;
                        sign_y = 1;
                        collidee = .wall;
                    }
                } else if (remaining_vel_y > 0) {
                    // Paddle
                    const paddle_top: Box = .{
                        .x = paddle.box.x,
                        .y = paddle.box.y,
                        .w = paddle.box.w,
                        .h = 0,
                    };
                    if (ball.box.sweepTest(remaining_vel_x, remaining_vel_y, paddle_top, 0, 0)) |collision| {
                        if (t - collision.t >= 0.001) {
                            t = @min(0, collision.t);
                            sign_y = -1;
                            collidee = .paddle;
                        }
                    }
                }

                // Bricks
                const broad: Box = .{
                    .x = @min(ball.box.x, ball.box.x + remaining_vel_x),
                    .y = @min(ball.box.y, ball.box.y + remaining_vel_y),
                    .w = @max(ball.box.w, ball.box.w + remaining_vel_x),
                    .h = @max(ball.box.h, ball.box.h + remaining_vel_y),
                };
                for (bricks.slice(), 0..) |brick, i| {
                    if (broad.intersects(brick.box)) {
                        if (ball.box.sweepTest(remaining_vel_x, remaining_vel_y, brick.box, 0, 0)) |collision| {
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
                    const angle = ball.getPaddleBounceAngle(paddle);
                    const vel_factor = 1.05;
                    ball.box.x += remaining_vel_x * t;
                    ball.box.y += remaining_vel_y * t;
                    const vel = @sqrt(ball.vel_x * ball.vel_x + ball.vel_y * ball.vel_y) * vel_factor;
                    ball.vel_x = @cos(angle) * vel;
                    ball.vel_y = @sin(angle) * vel;
                    remaining_vel_x *= (1 - t);
                    remaining_vel_y *= (1 - t);
                    const remaining_vel = @sqrt(remaining_vel_x * remaining_vel_x + remaining_vel_y * remaining_vel_y) * vel_factor;
                    remaining_vel_x = @cos(angle) * remaining_vel;
                    remaining_vel_y = @sin(angle) * remaining_vel;
                } else {
                    ball.box.x += remaining_vel_x * t;
                    ball.box.y += remaining_vel_y * t;
                    ball.vel_x = std.math.copysign(ball.vel_x, if (sign_x != 0) sign_x else remaining_vel_x);
                    ball.vel_y = std.math.copysign(ball.vel_y, if (sign_y != 0) sign_y else remaining_vel_y);
                    remaining_vel_x = std.math.copysign(remaining_vel_x * (1 - t), ball.vel_x);
                    remaining_vel_y = std.math.copysign(remaining_vel_y * (1 - t), ball.vel_y);
                    if (collidee == .brick) {
                        _ = bricks.swapRemove(collidee.brick);
                    }
                }

                // Enqueue an appropriate sound effect.
                switch (collidee) {
                    .wall => {
                        if (ball.box.y < window_h) {
                            sounds_to_play.insert(.hit_wall);
                        }
                    },
                    .paddle => {
                        sounds_to_play.insert(.hit_paddle);
                    },
                    .brick => {
                        if (bricks.len == 0) {
                            won = true;
                            sounds_to_play.insert(.win);
                        } else {
                            sounds_to_play.insert(.hit_brick);
                        }
                    },
                    .none => {},
                }
            }
        }

        if (previous_ball_y < window_h and ball.box.y >= window_h) {
            // The ball fell below the paddle.
            if (bricks.len != 0) {
                sounds_to_play.insert(.lose);
            }
        }

        // Update score.
        if (ball.launched) {
            if (ball.box.y < window_h) {
                if (bricks.len != 0) {
                    score +|= 1;
                } else {
                    best_score = @min(score, best_score);
                }
            }
            if (score <= best_score and bricks.len == 0) {
                score_color = .{ 0x52, 0xcc, 0x73 };
            } else if (ball.box.y >= window_h or score > best_score) {
                score_color = .{ 0xcc, 0x5c, 0x52 };
            }
        }
    }

    // Save score.
    if (won and score < best_score) {
        try saveBestScore();
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
                if (try errify(c.SDL_GetAudioStreamAvailable(stream)) == 0) {
                    break :find_available_stream stream;
                }
            } else {
                break :iterate_sounds;
            };
            const frame_size: usize = c.SDL_AUDIO_BYTESIZE(sounds_spec.format) * @as(c_uint, @intCast(sounds_spec.channels));
            const start: usize, const end: usize = switch (sound) {
                .hit_wall => sounds.hit_wall,
                .hit_paddle => sounds.hit_paddle,
                .hit_brick => sounds.hit_brick,
                .win => sounds.win,
                .lose => sounds.lose,
            };
            const data = sounds_data[(frame_size * start)..(frame_size * end)];
            try errify(c.SDL_PutAudioStreamData(stream, data.ptr, @intCast(data.len)));
        }
    }

    // Draw.
    {
        try errify(c.SDL_SetRenderDrawColor(renderer, 0x47, 0x5b, 0x8d, 0xff));

        try errify(c.SDL_RenderClear(renderer));

        for (bricks.slice()) |brick| try renderObject(renderer, sprites_texture, brick.src_rect, brick.box);
        try renderObject(renderer, sprites_texture, ball.src_rect, ball.box);
        try renderObject(renderer, sprites_texture, paddle.src_rect, paddle.box);

        try errify(c.SDL_SetRenderScale(renderer, 2, 2));
        {
            var buf: [12]u8 = undefined;
            var time: f32 = @min(@as(f32, @floatFromInt(score)) / Timekeeper.updates_per_s, 99.999);
            var text = try std.fmt.bufPrintZ(&buf, "TIME {d:0>6.3}", .{time});
            try errify(c.SDL_SetRenderDrawColor(renderer, score_color[0], score_color[1], score_color[2], 0xff));
            try errify(c.SDL_RenderDebugText(renderer, 8, 8, text.ptr));
            time = @min(@as(f32, @floatFromInt(best_score)) / Timekeeper.updates_per_s, 99.999);
            text = try std.fmt.bufPrintZ(&buf, "BEST {d:0>6.3}", .{time});
            try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff));
            try errify(c.SDL_RenderDebugText(renderer, window_w / 2 - 8 * 12, 8, text.ptr));
        }
        try errify(c.SDL_SetRenderScale(renderer, 1, 1));

        try errify(c.SDL_RenderPresent(renderer));
    }

    timekeeper.produce(c.SDL_GetPerformanceCounter());

    return c.SDL_APP_CONTINUE;
}

fn handle_event(appstate: ?*anyopaque, event: *SDL.Event) !SDL.AppProcess {
    _ = appstate;

    switch (event.type) {
        .QUIT => {
            return SDL.AppProcess.CLOSE_NORMAL;
        },
        .KEY_DOWN, .KEY_UP => {
            const is_down = event.type == .KEY_DOWN;
            switch (event.key.scancode) {
                //CHECKPOINT
                c.SDL_SCANCODE_LEFT => phcon.k_left = is_down,
                c.SDL_SCANCODE_RIGHT => phcon.k_right = is_down,
                c.SDL_SCANCODE_LSHIFT => phcon.k_lshift = is_down,
                c.SDL_SCANCODE_SPACE => phcon.k_space = is_down,
                c.SDL_SCANCODE_R => phcon.k_r = is_down,
                c.SDL_SCANCODE_ESCAPE => phcon.k_escape = is_down,
                else => {},
            }
        },
        c.SDL_EVENT_MOUSE_BUTTON_DOWN, c.SDL_EVENT_MOUSE_BUTTON_UP => {
            const down = event.type == c.SDL_EVENT_MOUSE_BUTTON_DOWN;
            switch (event.button.button) {
                c.SDL_BUTTON_LEFT => phcon.m_left = down,
                else => {},
            }
        },
        c.SDL_EVENT_MOUSE_MOTION => {
            phcon.m_xrel += event.motion.xrel;
        },
        c.SDL_EVENT_GAMEPAD_ADDED => {
            if (gamepad == null) {
                gamepad = try errify(c.SDL_OpenGamepad(event.gdevice.which));
            }
        },
        c.SDL_EVENT_GAMEPAD_REMOVED => {
            if (gamepad != null) {
                c.SDL_CloseGamepad(gamepad);
                gamepad = null;
            }
        },
        c.SDL_EVENT_GAMEPAD_BUTTON_DOWN, c.SDL_EVENT_GAMEPAD_BUTTON_UP => {
            const down = event.type == c.SDL_EVENT_GAMEPAD_BUTTON_DOWN;
            switch (event.gbutton.button) {
                c.SDL_GAMEPAD_BUTTON_DPAD_LEFT => phcon.g_left = down,
                c.SDL_GAMEPAD_BUTTON_DPAD_RIGHT => phcon.g_right = down,
                c.SDL_GAMEPAD_BUTTON_LEFT_SHOULDER => phcon.g_left_shoulder = down,
                c.SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER => phcon.g_right_shoulder = down,
                c.SDL_GAMEPAD_BUTTON_SOUTH => phcon.g_south = down,
                c.SDL_GAMEPAD_BUTTON_EAST => phcon.g_east = down,
                c.SDL_GAMEPAD_BUTTON_BACK => phcon.g_back = down,
                c.SDL_GAMEPAD_BUTTON_START => phcon.g_start = down,
                else => {},
            }
        },
        c.SDL_EVENT_GAMEPAD_AXIS_MOTION => {
            switch (event.gaxis.axis) {
                c.SDL_GAMEPAD_AXIS_LEFTX => phcon.g_leftx = event.gaxis.value,
                c.SDL_GAMEPAD_AXIS_LEFT_TRIGGER => phcon.g_left_trigger = event.gaxis.value,
                c.SDL_GAMEPAD_AXIS_RIGHT_TRIGGER => phcon.g_right_trigger = event.gaxis.value,
                else => {},
            }
        },
        else => {},
    }

    return c.SDL_APP_CONTINUE;
}

fn app_quit(appstate: ?*anyopaque, result: anyerror!SDL.AppProcess) void {
    _ = appstate;

    _ = result catch |err| switch (err) {
        SDL.Error.SDL_null_value, SDL.Error.SDL_operation_failure => {
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

fn sdl_init_func(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) SDL.AppProcess {
    const zig_args = Goolib.Utils.c_args_to_zig_args(.c_args_list(argc, argv));
    return app_init(appstate, zig_args) catch |err| app_err.store(err);
}

fn sdl_update_func(appstate: ?*anyopaque) callconv(.c) SDL.AppProcess {
    return app_update(appstate) catch |err| app_err.store(err);
}

fn sdl_event_func(appstate: ?*anyopaque, event: ?*SDL.Event) callconv(.c) SDL.AppProcess {
    return handle_event(appstate, event.?) catch |err| app_err.store(err);
}

fn sdl_quit_func(appstate: ?*anyopaque, close_state: SDL.AppProcess) callconv(.c) void {
    app_quit(appstate, app_err.load() orelse close_state);
}
