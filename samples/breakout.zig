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
var audio_streams_buf: [8]SDL.AudioStream = undefined;
var audio_streams: []SDL.AudioStream = audio_streams_buf[0..0];
var gamepad: ?SDL.Gamepad = undefined;
var phcon: PhysicalControllerState = undefined;
var prev_phcon: PhysicalControllerState = undefined;
var vcon: VirtualControllerState = undefined;
var prev_vcon: VirtualControllerState = undefined;
var best_score: u32 = undefined;
var timekeeper: Timekeeper = undefined;

var paddle: Paddle = undefined;
var ball: Ball = undefined;
var bricks: std.BoundedArray(Brick, 100) = undefined;

var score: u32 = undefined;
var score_color: [3]u8 = undefined;

pub fn main() !void {
    std.debug.print("test\n", .{});
}

pub fn app_init(app_state: ?*?*anyopaque, argv: [][*:0]u8) !SDL.AppResult {
    _ = app_state;
    _ = argv;

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
        audio_streams[audio_streams.len - 1].
        c.SDL_DestroyAudioStream(audio_streams[audio_streams.len - 1]);
        audio_streams.len -= 1;
    };
    while (audio_streams.len < audio_streams_buf.len) {
        audio_streams.len += 1;
        audio_streams[audio_streams.len - 1] = try errify(c.SDL_CreateAudioStream(&sounds_spec, null));
    }

    try errify(c.SDL_BindAudioStreams(audio_device, @ptrCast(audio_streams.ptr), @intCast(audio_streams.len)));

    {
        var count: c_int = 0;
        const gamepads: [*]c.SDL_JoystickID = try errify(c.SDL_GetGamepads(&count));
        defer c.SDL_free(gamepads);

        gamepad = if (count > 0) try errify(c.SDL_OpenGamepad(gamepads[0])) else null;
    }
    errdefer c.SDL_CloseGamepad(gamepad);

    phcon = .{};
    prev_phcon = phcon;
    vcon = .{};
    prev_vcon = vcon;

    try loadBestScore();

    timekeeper = .{ .tocks_per_s = c.SDL_GetPerformanceFrequency() };

    try resetGame();

    fully_initialized = true;
    errdefer comptime unreachable;

    return c.SDL_APP_CONTINUE;
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

fn fmt_sdl_drivers(write_buf: *std.BoundedArray(u8, 250), current_driver: [*:0]const u8, num_drivers: c_int, get_driver: *const fn (c_int) SDL.SDL3Error![*:0]const u8) SDL.SDL3Error![]const u8 {
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
