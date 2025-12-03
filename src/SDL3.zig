//! TODO Documentation
//! #### License: Zlib
//! #### Dependency Licenses:
//! - SDL3: (Zlib) https://github.com/libsdl-org/SDL/blob/main/LICENSE.txt
//! - SDL3 Zig Bindings: (Multi/Zlib) https://github.com/castholm/SDL/blob/main/LICENSE.txt

// THE FOLLOWING LICENSE APPLIES TO _THIS_ SOURCE FILE ONLY
// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
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
const config = @import("config");
const init_zero = std.mem.zeroes;
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const VERSION = Root.VERSION;
const Types = Root.Types;
const Cast = Root.Cast;
const Flags = Root.Flags.Flags;
const Utils = Root.Utils;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

/// #### SDL LICENSE: https://github.com/libsdl-org/SDL/blob/main/LICENSE.txt
///
/// Copyright (C) 1997-2025 Sam Lantinga <slouken@libsdl.org>
///
/// This software is provided 'as-is', without any express or implied
/// warranty.  In no event will the authors be held liable for any damages
/// arising from the use of this software.
///
/// Permission is granted to anyone to use this software for any purpose,
/// including commercial applications, and to alter it and redistribute it
/// freely, subject to the following restrictions:
///
/// 1. The origin of this software must not be misrepresented; you must not
///    claim that you wrote the original software. If you use this software
///    in a product, an acknowledgment in the product documentation would be
///    appreciated but is not required.
/// 2. Altered source versions must be plainly marked as such, and must not be
///    misrepresented as being the original software.
/// 3. This notice may not be removed or altered from any source distribution.
///
/// #### SDL3 Zig Bindings license: https://github.com/castholm/SDL/blob/main/LICENSE.txt
pub const C = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    if (config.SDL_USER_MAIN) @cDefine("SDL_MAIN_HANDLED", {});
    if (config.SDL_USER_CALLBACKS) @cDefine("SDL_MAIN_USE_CALLBACKS", {});
    @cInclude("SDL3/SDL_main.h");
});

fn c_non_opaque_conversions(comptime ZIG_TYPE: type, comptime C_TYPE: type) type {
    return struct {
        pub fn to_c(self: ZIG_TYPE) C_TYPE {
            return @bitCast(self);
        }
        pub fn to_c_ptr(self: *ZIG_TYPE) *C_TYPE {
            return @ptrCast(@alignCast(self));
        }
        pub fn from_c(c_struct: C_TYPE) ZIG_TYPE {
            return @bitCast(c_struct);
        }
        pub fn from_c_ptr(c_ptr: *C_TYPE) *ZIG_TYPE {
            return @ptrCast(@alignCast(c_ptr));
        }
    };
}

fn c_opaque_conversions(comptime ZIG_TYPE: type, comptime C_TYPE: type) type {
    return struct {
        pub fn to_c_ptr(self: *ZIG_TYPE) *C_TYPE {
            return @ptrCast(@alignCast(self));
        }
        pub fn from_c_ptr(c_ptr: *C_TYPE) *ZIG_TYPE {
            return @ptrCast(@alignCast(c_ptr));
        }
    };
}

fn c_enum_conversions(comptime ZIG_TYPE: type, comptime C_TYPE: type) type {
    assert_with_reason(Types.type_is_enum(ZIG_TYPE), @src(), "ZIG_TYPE not an enum", .{});
    assert_with_reason(Types.type_is_int(C_TYPE), @src(), "C_TYPE not an integer", .{});
    return struct {
        pub fn to_c(self: ZIG_TYPE) C_TYPE {
            return @intFromEnum(self);
        }
        pub fn from_c(c_integer: C_TYPE) ZIG_TYPE {
            return @enumFromInt(c_integer);
        }
    };
}

const EMPTY_STRING: [*:0]const u8 = "";

pub const Error = error{
    SDL_null_value,
    SDL_operation_failure,
    SDL_invalid_value,
    SDL_out_of_memory,
    SDL_custom_error,
};

inline fn ptr_cast_or_null_err(comptime T: type, result_ptr: anytype) Error!T {
    if (result_ptr) |good_ptr| return @ptrCast(@alignCast(good_ptr));
    return Error.SDL_null_value;
}
inline fn ptr_cast_or_fail_err(comptime T: type, result_ptr: anytype) Error!T {
    if (result_ptr) |good_ptr| return @ptrCast(@alignCast(good_ptr));
    return Error.SDL_operation_failure;
}
inline fn nonzero_or_null_err(result_id: anytype) Error!@TypeOf(result_id) {
    if (result_id <= 0) return Error.SDL_null_value;
    return result_id;
}
inline fn nonzero_or_fail_err(result_id: anytype) Error!@TypeOf(result_id) {
    if (result_id <= 0) return Error.SDL_operation_failure;
    return result_id;
}
inline fn greater_than_or_equal_to_zero_or_fail_err(result_int: anytype) Error!@TypeOf(result_int) {
    if (result_int < 0) return Error.SDL_operation_failure;
    return result_int;
}
inline fn positive_or_invalid_err(result_int: anytype) Error!@TypeOf(result_int) {
    if (result_int < 0) return Error.SDL_invalid_value;
    return result_int;
}
inline fn to_enum_or_invalid_err(comptime E: type, result_int: anytype) Error!E {
    const E_INFO = @typeInfo(E).@"enum";
    const E_INT = E_INFO.tag_type;
    if (build.mode == .Debug or build.mode == .ReleaseSafe) {
        const enum_val: E = std.meta.intToEnum(E, result_int) catch return Error.SDL_invalid_value;
        return enum_val;
    } else {
        return @as(E, @enumFromInt(@as(E_INT, @intCast(result_int))));
    }
}
inline fn positive_or_null_err(result_int: anytype) Error!@TypeOf(result_int) {
    if (result_int < 0) return Error.SDL_null_value;
    return result_int;
}
inline fn ok_or_null_err(result: bool) Error!void {
    if (result) return;
    return Error.SDL_null_value;
}
inline fn ok_or_fail_err(result: bool) Error!void {
    if (result) return;
    return Error.SDL_operation_failure;
}
inline fn nonempty_str_or_null_err(result: ?[*:0]u8) Error![*:0]u8 {
    if (result) |ptr| {
        if (ptr[0] != 0) return ptr;
    }
    return Error.SDL_null_value;
}
inline fn nonempty_str_or_fail_err(result: ?[*:0]u8) Error![*:0]u8 {
    if (result) |ptr| {
        if (ptr[0] != 0) return ptr;
    }
    return Error.SDL_operation_failure;
}
inline fn valid_guid_or_null_err(result: C.SDL_GUID) Error!GUID {
    const as_u64s: [2]u64 = @bitCast(result.data);
    const final = as_u64s[0] | as_u64s[1];
    if (final == 0) return Error.SDL_null_value;
    return GUID{ .data = result.data };
}
inline fn nonempty_const_str_or_null_err(result: ?[*:0]const u8) Error![*:0]const u8 {
    if (result) |ptr| {
        if (ptr[0] != 0) return ptr;
    }
    return Error.SDL_null_value;
}
inline fn nonempty_const_str_or_fail_err(result: ?[*:0]const u8) Error![*:0]const u8 {
    if (result) |ptr| {
        if (ptr[0] != 0) return ptr;
    }
    return Error.SDL_operation_failure;
}

pub const Rect_c_int = Root.Rect2.define_rect2_type(c_int);
pub const Rect_c_uint = Root.Rect2.define_rect2_type(c_uint);
pub const Rect_f32 = Root.Rect2.define_rect2_type(f32);
pub const Vec_c_int = Root.Vec2.define_vec2_type(c_int);
pub const Vec_c_uint = Root.Vec2.define_vec2_type(c_uint);
pub const Vec_i16 = Root.Vec2.define_vec2_type(i16);
pub const Vec_f32 = Root.Vec2.define_vec2_type(f32);
pub const Color_RGBA_u8 = Root.Color.define_color_rgba_type(u8);
pub const Color_RGBA_f32 = Root.Color.define_color_rgba_type(f32);
pub const Color_RGB_u8 = Root.Color.define_color_rgb_type(u8);
pub const Color_RGB_f32 = Root.Color.define_color_rgb_type(f32);
pub const Color_raw_u32 = extern struct {
    raw: u32,
};
pub const Time_NS = Root.Time.NSecs;
pub const Time_MS = Root.Time.MSecs;

pub const Video = struct {
    pub fn get_current_video_driver() Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetCurrentVideoDriver());
    }
    pub fn get_num_video_drivers() c_int {
        return C.SDL_GetNumVideoDrivers();
    }
    pub fn get_video_driver(index: c_int) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetVideoDriver(index));
    }

    pub const Props = struct {
        pub const WAYLAND_WL_DISPLAY = Property.new(.POINTER, C.SDL_PROP_GLOBAL_VIDEO_WAYLAND_WL_DISPLAY_POINTER);
    };
};

pub const HINT = struct {
    pub const ALLOW_ALT_TAB_WHILE_GRABBED = "SDL_ALLOW_ALT_TAB_WHILE_GRABBED";
    pub const ANDROID_ALLOW_RECREATE_ACTIVITY = "SDL_ANDROID_ALLOW_RECREATE_ACTIVITY";
    pub const ANDROID_BLOCK_ON_PAUSE = "SDL_ANDROID_BLOCK_ON_PAUSE";
    pub const ANDROID_LOW_LATENCY_AUDIO = "SDL_ANDROID_LOW_LATENCY_AUDIO";
    pub const ANDROID_TRAP_BACK_BUTTON = "SDL_ANDROID_TRAP_BACK_BUTTON";
    pub const APP_ID = "SDL_APP_ID";
    pub const APP_NAME = "SDL_APP_NAME";
    pub const APPLE_TV_CONTROLLER_UI_EVENTS = "SDL_APPLE_TV_CONTROLLER_UI_EVENTS";
    pub const APPLE_TV_REMOTE_ALLOW_ROTATION = "SDL_APPLE_TV_REMOTE_ALLOW_ROTATION";
    pub const AUDIO_ALSA_DEFAULT_DEVICE = "SDL_AUDIO_ALSA_DEFAULT_DEVICE";
    pub const AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE = "SDL_AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE";
    pub const AUDIO_ALSA_DEFAULT_RECORDING_DEVICE = "SDL_AUDIO_ALSA_DEFAULT_RECORDING_DEVICE";
    pub const AUDIO_CATEGORY = "SDL_AUDIO_CATEGORY";
    pub const AUDIO_CHANNELS = "SDL_AUDIO_CHANNELS";
    pub const AUDIO_DEVICE_APP_ICON_NAME = "SDL_AUDIO_DEVICE_APP_ICON_NAME";
    pub const AUDIO_DEVICE_SAMPLE_FRAMES = "SDL_AUDIO_DEVICE_SAMPLE_FRAMES";
    pub const AUDIO_DEVICE_STREAM_NAME = "SDL_AUDIO_DEVICE_STREAM_NAME";
    pub const AUDIO_DEVICE_STREAM_ROLE = "SDL_AUDIO_DEVICE_STREAM_ROLE";
    pub const AUDIO_DISK_INPUT_FILE = "SDL_AUDIO_DISK_INPUT_FILE";
    pub const AUDIO_DISK_OUTPUT_FILE = "SDL_AUDIO_DISK_OUTPUT_FILE";
    pub const AUDIO_DISK_TIMESCALE = "SDL_AUDIO_DISK_TIMESCALE";
    pub const AUDIO_DRIVER = "SDL_AUDIO_DRIVER";
    pub const AUDIO_DUMMY_TIMESCALE = "SDL_AUDIO_DUMMY_TIMESCALE";
    pub const AUDIO_FORMAT = "SDL_AUDIO_FORMAT";
    pub const AUDIO_FREQUENCY = "SDL_AUDIO_FREQUENCY";
    pub const AUDIO_INCLUDE_MONITORS = "SDL_AUDIO_INCLUDE_MONITORS";
    pub const AUTO_UPDATE_JOYSTICKS = "SDL_AUTO_UPDATE_JOYSTICKS";
    pub const AUTO_UPDATE_SENSORS = "SDL_AUTO_UPDATE_SENSORS";
    pub const BMP_SAVE_LEGACY_FORMAT = "SDL_BMP_SAVE_LEGACY_FORMAT";
    pub const CAMERA_DRIVER = "SDL_CAMERA_DRIVER";
    pub const CPU_FEATURE_MASK = "SDL_CPU_FEATURE_MASK";
    pub const JOYSTICK_DIRECTINPUT = "SDL_JOYSTICK_DIRECTINPUT";
    pub const FILE_DIALOG_DRIVER = "SDL_FILE_DIALOG_DRIVER";
    pub const DISPLAY_USABLE_BOUNDS = "SDL_DISPLAY_USABLE_BOUNDS";
    pub const EMSCRIPTEN_ASYNCIFY = "SDL_EMSCRIPTEN_ASYNCIFY";
    pub const EMSCRIPTEN_CANVAS_SELECTOR = "SDL_EMSCRIPTEN_CANVAS_SELECTOR";
    pub const EMSCRIPTEN_KEYBOARD_ELEMENT = "SDL_EMSCRIPTEN_KEYBOARD_ELEMENT";
    pub const ENABLE_SCREEN_KEYBOARD = "SDL_ENABLE_SCREEN_KEYBOARD";
    pub const EVDEV_DEVICES = "SDL_EVDEV_DEVICES";
    pub const EVENT_LOGGING = "SDL_EVENT_LOGGING";
    pub const FORCE_RAISEWINDOW = "SDL_FORCE_RAISEWINDOW";
    pub const FRAMEBUFFER_ACCELERATION = "SDL_FRAMEBUFFER_ACCELERATION";
    pub const GAMECONTROLLERCONFIG = "SDL_GAMECONTROLLERCONFIG";
    pub const GAMECONTROLLERCONFIG_FILE = "SDL_GAMECONTROLLERCONFIG_FILE";
    pub const GAMECONTROLLERTYPE = "SDL_GAMECONTROLLERTYPE";
    pub const GAMECONTROLLER_IGNORE_DEVICES = "SDL_GAMECONTROLLER_IGNORE_DEVICES";
    pub const GAMECONTROLLER_IGNORE_DEVICES_EXCEPT = "SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT";
    pub const GAMECONTROLLER_SENSOR_FUSION = "SDL_GAMECONTROLLER_SENSOR_FUSION";
    pub const GDK_TEXTINPUT_DEFAULT_TEXT = "SDL_GDK_TEXTINPUT_DEFAULT_TEXT";
    pub const GDK_TEXTINPUT_DESCRIPTION = "SDL_GDK_TEXTINPUT_DESCRIPTION";
    pub const GDK_TEXTINPUT_MAX_LENGTH = "SDL_GDK_TEXTINPUT_MAX_LENGTH";
    pub const GDK_TEXTINPUT_SCOPE = "SDL_GDK_TEXTINPUT_SCOPE";
    pub const GDK_TEXTINPUT_TITLE = "SDL_GDK_TEXTINPUT_TITLE";
    pub const HIDAPI_LIBUSB = "SDL_HIDAPI_LIBUSB";
    pub const HIDAPI_LIBUSB_WHITELIST = "SDL_HIDAPI_LIBUSB_WHITELIST";
    pub const HIDAPI_UDEV = "SDL_HIDAPI_UDEV";
    pub const GPU_DRIVER = "SDL_GPU_DRIVER";
    pub const HIDAPI_ENUMERATE_ONLY_CONTROLLERS = "SDL_HIDAPI_ENUMERATE_ONLY_CONTROLLERS";
    pub const HIDAPI_IGNORE_DEVICES = "SDL_HIDAPI_IGNORE_DEVICES";
    pub const IME_IMPLEMENTED_UI = "SDL_IME_IMPLEMENTED_UI";
    pub const IOS_HIDE_HOME_INDICATOR = "SDL_IOS_HIDE_HOME_INDICATOR";
    pub const JOYSTICK_ALLOW_BACKGROUND_EVENTS = "SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS";
    pub const JOYSTICK_ARCADESTICK_DEVICES = "SDL_JOYSTICK_ARCADESTICK_DEVICES";
    pub const JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED = "SDL_JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED";
    pub const JOYSTICK_BLACKLIST_DEVICES = "SDL_JOYSTICK_BLACKLIST_DEVICES";
    pub const JOYSTICK_BLACKLIST_DEVICES_EXCLUDED = "SDL_JOYSTICK_BLACKLIST_DEVICES_EXCLUDED";
    pub const JOYSTICK_DEVICE = "SDL_JOYSTICK_DEVICE";
    pub const JOYSTICK_ENHANCED_REPORTS = "SDL_JOYSTICK_ENHANCED_REPORTS";
    pub const JOYSTICK_FLIGHTSTICK_DEVICES = "SDL_JOYSTICK_FLIGHTSTICK_DEVICES";
    pub const JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED = "SDL_JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED";
    pub const JOYSTICK_GAMEINPUT = "SDL_JOYSTICK_GAMEINPUT";
    pub const JOYSTICK_GAMECUBE_DEVICES = "SDL_JOYSTICK_GAMECUBE_DEVICES";
    pub const JOYSTICK_GAMECUBE_DEVICES_EXCLUDED = "SDL_JOYSTICK_GAMECUBE_DEVICES_EXCLUDED";
    pub const JOYSTICK_HIDAPI = "SDL_JOYSTICK_HIDAPI";
    pub const JOYSTICK_HIDAPI_COMBINE_JOY_CONS = "SDL_JOYSTICK_HIDAPI_COMBINE_JOY_CONS";
    pub const JOYSTICK_HIDAPI_GAMECUBE = "SDL_JOYSTICK_HIDAPI_GAMECUBE";
    pub const JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE = "SDL_JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE";
    pub const JOYSTICK_HIDAPI_JOY_CONS = "SDL_JOYSTICK_HIDAPI_JOY_CONS";
    pub const JOYSTICK_HIDAPI_JOYCON_HOME_LED = "SDL_JOYSTICK_HIDAPI_JOYCON_HOME_LED";
    pub const JOYSTICK_HIDAPI_LUNA = "SDL_JOYSTICK_HIDAPI_LUNA";
    pub const JOYSTICK_HIDAPI_NINTENDO_CLASSIC = "SDL_JOYSTICK_HIDAPI_NINTENDO_CLASSIC";
    pub const JOYSTICK_HIDAPI_PS3 = "SDL_JOYSTICK_HIDAPI_PS3";
    pub const JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER = "SDL_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER";
    pub const JOYSTICK_HIDAPI_PS4 = "SDL_JOYSTICK_HIDAPI_PS4";
    pub const JOYSTICK_HIDAPI_PS4_REPORT_INTERVAL = "SDL_JOYSTICK_HIDAPI_PS4_REPORT_INTERVAL";
    pub const JOYSTICK_HIDAPI_PS5 = "SDL_JOYSTICK_HIDAPI_PS5";
    pub const JOYSTICK_HIDAPI_PS5_PLAYER_LED = "SDL_JOYSTICK_HIDAPI_PS5_PLAYER_LED";
    pub const JOYSTICK_HIDAPI_SHIELD = "SDL_JOYSTICK_HIDAPI_SHIELD";
    pub const JOYSTICK_HIDAPI_STADIA = "SDL_JOYSTICK_HIDAPI_STADIA";
    pub const JOYSTICK_HIDAPI_STEAM = "SDL_JOYSTICK_HIDAPI_STEAM";
    pub const JOYSTICK_HIDAPI_STEAM_HOME_LED = "SDL_JOYSTICK_HIDAPI_STEAM_HOME_LED";
    pub const JOYSTICK_HIDAPI_STEAMDECK = "SDL_JOYSTICK_HIDAPI_STEAMDECK";
    pub const JOYSTICK_HIDAPI_STEAM_HORI = "SDL_JOYSTICK_HIDAPI_STEAM_HORI";
    pub const JOYSTICK_HIDAPI_SWITCH = "SDL_JOYSTICK_HIDAPI_SWITCH";
    pub const JOYSTICK_HIDAPI_SWITCH_HOME_LED = "SDL_JOYSTICK_HIDAPI_SWITCH_HOME_LED";
    pub const JOYSTICK_HIDAPI_SWITCH_PLAYER_LED = "SDL_JOYSTICK_HIDAPI_SWITCH_PLAYER_LED";
    pub const JOYSTICK_HIDAPI_VERTICAL_JOY_CONS = "SDL_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS";
    pub const JOYSTICK_HIDAPI_WII = "SDL_JOYSTICK_HIDAPI_WII";
    pub const JOYSTICK_HIDAPI_WII_PLAYER_LED = "SDL_JOYSTICK_HIDAPI_WII_PLAYER_LED";
    pub const JOYSTICK_HIDAPI_XBOX = "SDL_JOYSTICK_HIDAPI_XBOX";
    pub const JOYSTICK_HIDAPI_XBOX_360 = "SDL_JOYSTICK_HIDAPI_XBOX_360";
    pub const JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED = "SDL_JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED";
    pub const JOYSTICK_HIDAPI_XBOX_360_WIRELESS = "SDL_JOYSTICK_HIDAPI_XBOX_360_WIRELESS";
    pub const JOYSTICK_HIDAPI_XBOX_ONE = "SDL_JOYSTICK_HIDAPI_XBOX_ONE";
    pub const JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED = "SDL_JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED";
    pub const JOYSTICK_IOKIT = "SDL_JOYSTICK_IOKIT";
    pub const JOYSTICK_LINUX_CLASSIC = "SDL_JOYSTICK_LINUX_CLASSIC";
    pub const JOYSTICK_LINUX_DEADZONES = "SDL_JOYSTICK_LINUX_DEADZONES";
    pub const JOYSTICK_LINUX_DIGITAL_HATS = "SDL_JOYSTICK_LINUX_DIGITAL_HATS";
    pub const JOYSTICK_LINUX_HAT_DEADZONES = "SDL_JOYSTICK_LINUX_HAT_DEADZONES";
    pub const JOYSTICK_MFI = "SDL_JOYSTICK_MFI";
    pub const JOYSTICK_RAWINPUT = "SDL_JOYSTICK_RAWINPUT";
    pub const JOYSTICK_RAWINPUT_CORRELATE_XINPUT = "SDL_JOYSTICK_RAWINPUT_CORRELATE_XINPUT";
    pub const JOYSTICK_ROG_CHAKRAM = "SDL_JOYSTICK_ROG_CHAKRAM";
    pub const JOYSTICK_THREAD = "SDL_JOYSTICK_THREAD";
    pub const JOYSTICK_THROTTLE_DEVICES = "SDL_JOYSTICK_THROTTLE_DEVICES";
    pub const JOYSTICK_THROTTLE_DEVICES_EXCLUDED = "SDL_JOYSTICK_THROTTLE_DEVICES_EXCLUDED";
    pub const JOYSTICK_WGI = "SDL_JOYSTICK_WGI";
    pub const JOYSTICK_WHEEL_DEVICES = "SDL_JOYSTICK_WHEEL_DEVICES";
    pub const JOYSTICK_WHEEL_DEVICES_EXCLUDED = "SDL_JOYSTICK_WHEEL_DEVICES_EXCLUDED";
    pub const JOYSTICK_ZERO_CENTERED_DEVICES = "SDL_JOYSTICK_ZERO_CENTERED_DEVICES";
    pub const JOYSTICK_HAPTIC_AXES = "SDL_JOYSTICK_HAPTIC_AXES";
    pub const KEYCODE_OPTIONS = "SDL_KEYCODE_OPTIONS";
    pub const KMSDRM_DEVICE_INDEX = "SDL_KMSDRM_DEVICE_INDEX";
    pub const KMSDRM_REQUIRE_DRM_MASTER = "SDL_KMSDRM_REQUIRE_DRM_MASTER";
    pub const LOGGING = "SDL_LOGGING";
    pub const MAC_BACKGROUND_APP = "SDL_MAC_BACKGROUND_APP";
    pub const MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK = "SDL_MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK";
    pub const MAC_OPENGL_ASYNC_DISPATCH = "SDL_MAC_OPENGL_ASYNC_DISPATCH";
    pub const MAC_OPTION_AS_ALT = "SDL_MAC_OPTION_AS_ALT";
    pub const MAC_SCROLL_MOMENTUM = "SDL_MAC_SCROLL_MOMENTUM";
    pub const MAIN_CALLBACK_RATE = "SDL_MAIN_CALLBACK_RATE";
    pub const MOUSE_AUTO_CAPTURE = "SDL_MOUSE_AUTO_CAPTURE";
    pub const MOUSE_DOUBLE_CLICK_RADIUS = "SDL_MOUSE_DOUBLE_CLICK_RADIUS";
    pub const MOUSE_DOUBLE_CLICK_TIME = "SDL_MOUSE_DOUBLE_CLICK_TIME";
    pub const MOUSE_DEFAULT_SYSTEM_CURSOR = "SDL_MOUSE_DEFAULT_SYSTEM_CURSOR";
    pub const MOUSE_EMULATE_WARP_WITH_RELATIVE = "SDL_MOUSE_EMULATE_WARP_WITH_RELATIVE";
    pub const MOUSE_FOCUS_CLICKTHROUGH = "SDL_MOUSE_FOCUS_CLICKTHROUGH";
    pub const MOUSE_NORMAL_SPEED_SCALE = "SDL_MOUSE_NORMAL_SPEED_SCALE";
    pub const MOUSE_RELATIVE_MODE_CENTER = "SDL_MOUSE_RELATIVE_MODE_CENTER";
    pub const MOUSE_RELATIVE_SPEED_SCALE = "SDL_MOUSE_RELATIVE_SPEED_SCALE";
    pub const MOUSE_RELATIVE_SYSTEM_SCALE = "SDL_MOUSE_RELATIVE_SYSTEM_SCALE";
    pub const MOUSE_RELATIVE_WARP_MOTION = "SDL_MOUSE_RELATIVE_WARP_MOTION";
    pub const MOUSE_RELATIVE_CURSOR_VISIBLE = "SDL_MOUSE_RELATIVE_CURSOR_VISIBLE";
    pub const MOUSE_TOUCH_EVENTS = "SDL_MOUSE_TOUCH_EVENTS";
    pub const MUTE_CONSOLE_KEYBOARD = "SDL_MUTE_CONSOLE_KEYBOARD";
    pub const NO_SIGNAL_HANDLERS = "SDL_NO_SIGNAL_HANDLERS";
    pub const OPENGL_LIBRARY = "SDL_OPENGL_LIBRARY";
    pub const EGL_LIBRARY = "SDL_EGL_LIBRARY";
    pub const OPENGL_ES_DRIVER = "SDL_OPENGL_ES_DRIVER";
    pub const OPENVR_LIBRARY = "SDL_OPENVR_LIBRARY";
    pub const ORIENTATIONS = "SDL_ORIENTATIONS";
    pub const POLL_SENTINEL = "SDL_POLL_SENTINEL";
    pub const PREFERRED_LOCALES = "SDL_PREFERRED_LOCALES";
    pub const QUIT_ON_LAST_WINDOW_CLOSE = "SDL_QUIT_ON_LAST_WINDOW_CLOSE";
    pub const RENDER_DIRECT3D_THREADSAFE = "SDL_RENDER_DIRECT3D_THREADSAFE";
    pub const RENDER_DIRECT3D11_DEBUG = "SDL_RENDER_DIRECT3D11_DEBUG";
    pub const RENDER_VULKAN_DEBUG = "SDL_RENDER_VULKAN_DEBUG";
    pub const RENDER_GPU_DEBUG = "SDL_RENDER_GPU_DEBUG";
    pub const RENDER_GPU_LOW_POWER = "SDL_RENDER_GPU_LOW_POWER";
    pub const RENDER_DRIVER = "SDL_RENDER_DRIVER";
    pub const RENDER_LINE_METHOD = "SDL_RENDER_LINE_METHOD";
    pub const RENDER_METAL_PREFER_LOW_POWER_DEVICE = "SDL_RENDER_METAL_PREFER_LOW_POWER_DEVICE";
    pub const RENDER_VSYNC = "SDL_RENDER_VSYNC";
    pub const RETURN_KEY_HIDES_IME = "SDL_RETURN_KEY_HIDES_IME";
    pub const ROG_GAMEPAD_MICE = "SDL_ROG_GAMEPAD_MICE";
    pub const ROG_GAMEPAD_MICE_EXCLUDED = "SDL_ROG_GAMEPAD_MICE_EXCLUDED";
    pub const RPI_VIDEO_LAYER = "SDL_RPI_VIDEO_LAYER";
    pub const SCREENSAVER_INHIBIT_ACTIVITY_NAME = "SDL_SCREENSAVER_INHIBIT_ACTIVITY_NAME";
    pub const SHUTDOWN_DBUS_ON_QUIT = "SDL_SHUTDOWN_DBUS_ON_QUIT";
    pub const STORAGE_TITLE_DRIVER = "SDL_STORAGE_TITLE_DRIVER";
    pub const STORAGE_USER_DRIVER = "SDL_STORAGE_USER_DRIVER";
    pub const THREAD_FORCE_REALTIME_TIME_CRITICAL = "SDL_THREAD_FORCE_REALTIME_TIME_CRITICAL";
    pub const THREAD_PRIORITY_POLICY = "SDL_THREAD_PRIORITY_POLICY";
    pub const TIMER_RESOLUTION = "SDL_TIMER_RESOLUTION";
    pub const TOUCH_MOUSE_EVENTS = "SDL_TOUCH_MOUSE_EVENTS";
    pub const TRACKPAD_IS_TOUCH_ONLY = "SDL_TRACKPAD_IS_TOUCH_ONLY";
    pub const TV_REMOTE_AS_JOYSTICK = "SDL_TV_REMOTE_AS_JOYSTICK";
    pub const VIDEO_ALLOW_SCREENSAVER = "SDL_VIDEO_ALLOW_SCREENSAVER";
    pub const VIDEO_DISPLAY_PRIORITY = "SDL_VIDEO_DISPLAY_PRIORITY";
    pub const VIDEO_DOUBLE_BUFFER = "SDL_VIDEO_DOUBLE_BUFFER";
    pub const VIDEO_DRIVER = "SDL_VIDEO_DRIVER";
    pub const VIDEO_DUMMY_SAVE_FRAMES = "SDL_VIDEO_DUMMY_SAVE_FRAMES";
    pub const VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK = "SDL_VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK";
    pub const VIDEO_FORCE_EGL = "SDL_VIDEO_FORCE_EGL";
    pub const VIDEO_MAC_FULLSCREEN_SPACES = "SDL_VIDEO_MAC_FULLSCREEN_SPACES";
    pub const VIDEO_MAC_FULLSCREEN_MENU_VISIBILITY = "SDL_VIDEO_MAC_FULLSCREEN_MENU_VISIBILITY";
    pub const VIDEO_MINIMIZE_ON_FOCUS_LOSS = "SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS";
    pub const VIDEO_OFFSCREEN_SAVE_FRAMES = "SDL_VIDEO_OFFSCREEN_SAVE_FRAMES";
    pub const VIDEO_SYNC_WINDOW_OPERATIONS = "SDL_VIDEO_SYNC_WINDOW_OPERATIONS";
    pub const VIDEO_WAYLAND_ALLOW_LIBDECOR = "SDL_VIDEO_WAYLAND_ALLOW_LIBDECOR";
    pub const VIDEO_WAYLAND_MODE_EMULATION = "SDL_VIDEO_WAYLAND_MODE_EMULATION";
    pub const VIDEO_WAYLAND_MODE_SCALING = "SDL_VIDEO_WAYLAND_MODE_SCALING";
    pub const VIDEO_WAYLAND_PREFER_LIBDECOR = "SDL_VIDEO_WAYLAND_PREFER_LIBDECOR";
    pub const VIDEO_WAYLAND_SCALE_TO_DISPLAY = "SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY";
    pub const VIDEO_WIN_D3DCOMPILER = "SDL_VIDEO_WIN_D3DCOMPILER";
    pub const VIDEO_X11_EXTERNAL_WINDOW_INPUT = "SDL_VIDEO_X11_EXTERNAL_WINDOW_INPUT";
    pub const VIDEO_X11_NET_WM_BYPASS_COMPOSITOR = "SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR";
    pub const VIDEO_X11_NET_WM_PING = "SDL_VIDEO_X11_NET_WM_PING";
    pub const VIDEO_X11_NODIRECTCOLOR = "SDL_VIDEO_X11_NODIRECTCOLOR";
    pub const VIDEO_X11_SCALING_FACTOR = "SDL_VIDEO_X11_SCALING_FACTOR";
    pub const VIDEO_X11_VISUALID = "SDL_VIDEO_X11_VISUALID";
    pub const VIDEO_X11_WINDOW_VISUALID = "SDL_VIDEO_X11_WINDOW_VISUALID";
    pub const VIDEO_X11_XRANDR = "SDL_VIDEO_X11_XRANDR";
    pub const VITA_ENABLE_BACK_TOUCH = "SDL_VITA_ENABLE_BACK_TOUCH";
    pub const VITA_ENABLE_FRONT_TOUCH = "SDL_VITA_ENABLE_FRONT_TOUCH";
    pub const VITA_MODULE_PATH = "SDL_VITA_MODULE_PATH";
    pub const VITA_PVR_INIT = "SDL_VITA_PVR_INIT";
    pub const VITA_RESOLUTION = "SDL_VITA_RESOLUTION";
    pub const VITA_PVR_OPENGL = "SDL_VITA_PVR_OPENGL";
    pub const VITA_TOUCH_MOUSE_DEVICE = "SDL_VITA_TOUCH_MOUSE_DEVICE";
    pub const VULKAN_DISPLAY = "SDL_VULKAN_DISPLAY";
    pub const VULKAN_LIBRARY = "SDL_VULKAN_LIBRARY";
    pub const WAVE_FACT_CHUNK = "SDL_WAVE_FACT_CHUNK";
    pub const WAVE_CHUNK_LIMIT = "SDL_WAVE_CHUNK_LIMIT";
    pub const WAVE_RIFF_CHUNK_SIZE = "SDL_WAVE_RIFF_CHUNK_SIZE";
    pub const WAVE_TRUNCATION = "SDL_WAVE_TRUNCATION";
    pub const WINDOW_ACTIVATE_WHEN_RAISED = "SDL_WINDOW_ACTIVATE_WHEN_RAISED";
    pub const WINDOW_ACTIVATE_WHEN_SHOWN = "SDL_WINDOW_ACTIVATE_WHEN_SHOWN";
    pub const WINDOW_ALLOW_TOPMOST = "SDL_WINDOW_ALLOW_TOPMOST";
    pub const WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN = "SDL_WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN";
    pub const WINDOWS_CLOSE_ON_ALT_F4 = "SDL_WINDOWS_CLOSE_ON_ALT_F4";
    pub const WINDOWS_ENABLE_MENU_MNEMONICS = "SDL_WINDOWS_ENABLE_MENU_MNEMONICS";
    pub const WINDOWS_ENABLE_MESSAGELOOP = "SDL_WINDOWS_ENABLE_MESSAGELOOP";
    pub const WINDOWS_GAMEINPUT = "SDL_WINDOWS_GAMEINPUT";
    pub const WINDOWS_RAW_KEYBOARD = "SDL_WINDOWS_RAW_KEYBOARD";
    pub const WINDOWS_FORCE_SEMAPHORE_KERNEL = "SDL_WINDOWS_FORCE_SEMAPHORE_KERNEL";
    pub const WINDOWS_INTRESOURCE_ICON = "SDL_WINDOWS_INTRESOURCE_ICON";
    pub const WINDOWS_INTRESOURCE_ICON_SMALL = "SDL_WINDOWS_INTRESOURCE_ICON_SMALL";
    pub const WINDOWS_USE_D3D9EX = "SDL_WINDOWS_USE_D3D9EX";
    pub const WINDOWS_ERASE_BACKGROUND_MODE = "SDL_WINDOWS_ERASE_BACKGROUND_MODE";
    pub const X11_FORCE_OVERRIDE_REDIRECT = "SDL_X11_FORCE_OVERRIDE_REDIRECT";
    pub const X11_WINDOW_TYPE = "SDL_X11_WINDOW_TYPE";
    pub const X11_XCB_LIBRARY = "SDL_X11_XCB_LIBRARY";
    pub const XINPUT_ENABLED = "SDL_XINPUT_ENABLED";
    pub const ASSERT = "SDL_ASSERT";
    pub const PEN_MOUSE_EVENTS = "SDL_PEN_MOUSE_EVENTS";
    pub const PEN_TOUCH_EVENTS = "SDL_PEN_TOUCH_EVENTS";
};

pub const SeekRelativeTo = enum(C.SDL_IOWhence) {
    RELATIVE_TO_START = C.SDL_IO_SEEK_SET,
    RELATIVE_TO_CURRENT = C.SDL_IO_SEEK_CUR,
    RELATIVE_TO_END = C.SDL_IO_SEEK_END,

    pub const to_c = c_enum_conversions(SeekRelativeTo, C.SDL_IOWhence).to_c;
    pub const from_c = c_enum_conversions(SeekRelativeTo, C.SDL_IOWhence).from_c;
};

pub const IOStatus = enum(C.SDL_IOStatus) {
    READY = C.SDL_IO_STATUS_READY,
    ERROR = C.SDL_IO_STATUS_ERROR,
    EOF = C.SDL_IO_STATUS_EOF,
    NOT_READY = C.SDL_IO_STATUS_NOT_READY,
    READONLY = C.SDL_IO_STATUS_READONLY,
    WRITEONLY = C.SDL_IO_STATUS_WRITEONLY,

    pub const to_c = c_enum_conversions(IOStatus, C.SDL_IOStatus).to_c;
    pub const from_c = c_enum_conversions(IOStatus, C.SDL_IOStatus).from_c;
};

pub const IOStreamInterface = extern struct {
    version: u32 = 0,
    size: ?*const fn (userdata: ?*anyopaque) callconv(.c) i64 = null,
    seek: ?*const fn (userdata: ?*anyopaque, offset: i64, relative_to: SeekRelativeTo) callconv(.c) i64 = null,
    read_from_stream_into_ptr: ?*const fn (userdata: ?*anyopaque, ptr: ?[*]u8, read_len: usize, read_result_var: *IOStatus) callconv(.c) usize = null,
    write_from_ptr_into_stream: ?*const fn (userdata: ?*anyopaque, ptr: ?[*]const u8, write_len: usize, write_result_var: *IOStatus) callconv(.c) usize = null,
    flush: ?*const fn (userdata: ?*anyopaque, flush_result_var: *IOStatus) callconv(.c) bool = null,
    close: ?*const fn (userdata: ?*anyopaque) callconv(.c) bool = null,
};

pub const IOVarArgsList = extern struct {
    gp_offset: c_uint = 0,
    fp_offset: c_uint = 0,
    overflow_arg_area: ?*anyopaque = null,
    reg_save_area: ?*anyopaque = null,
};

pub const IOFile = extern struct {
    data: [:0]u8 = "",

    pub fn load(path: [*:0]const u8) Error!IOFile {
        var len: usize = 0;
        const ptr = try ptr_cast_or_null_err([*:0]u8, C.SDL_LoadFile(path, &len));
        return IOFile{ .data = ptr[0..len :0] };
    }

    pub fn save(self: IOFile, path: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_SaveFile(path, self.data.ptr, self.data.len));
    }

    pub fn save_and_free(self: IOFile, path: [*:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_SaveFile(path, self.data.ptr, self.data.len));
        Mem.free(self.data.ptr);
        self.data = "";
    }

    pub fn from_buffer(buf: [:0]u8) IOFile {
        return IOFile{ .data = buf };
    }

    pub fn free(self: IOFile) void {
        Mem.free(self.data.ptr);
        self.data = "";
    }
};

pub const IOStream = opaque {
    inline fn to_c(self: *IOStream) *C.SDL_IOStream {
        return @ptrCast(@alignCast(self));
    }

    pub fn from_file(file_path: [:0]const u8, mode: IOMode) Error!*IOStream {
        return ptr_cast_or_null_err(*IOStream, C.SDL_IOFromFile(file_path.ptr, mode.to_c()));
    }
    pub fn from_mem(mem: [:0]u8) Error!*IOStream {
        return ptr_cast_or_null_err(*IOStream, C.SDL_IOFromMem(mem.ptr, @intCast(mem.len)));
    }
    pub fn from_const_mem(mem: [:0]const u8) Error!*IOStream {
        return ptr_cast_or_null_err(*IOStream, C.SDL_IOFromConstMem(mem.ptr, @intCast(mem.len)));
    }
    pub fn from_heap_allocation() Error!*IOStream {
        return ptr_cast_or_null_err(*IOStream, C.SDL_IOFromDynamicMem());
    }
    pub fn from_custom_interface(iface: *IOStreamInterface, userdata: ?*anyopaque) Error!*IOStream {
        return ptr_cast_or_fail_err(*IOStream, C.SDL_OpenIO(@ptrCast(@alignCast(iface)), userdata));
    }
    pub fn close(self: *IOStream) Error!void {
        return ok_or_fail_err(C.SDL_CloseIO(self.to_c()));
    }
    pub fn get_properties(self: *IOStream) Error!PropertiesID {
        return PropertiesID{ .id = try nonzero_or_null_err(C.SDL_GetIOProperties(self.to_c())) };
    }
    pub fn get_status(self: *IOStream) IOStatus {
        return @enumFromInt(C.SDL_GetIOStatus(self.to_c()));
    }
    pub fn get_size(self: *IOStream) i64 {
        return C.SDL_GetIOSize(self.to_c());
    }
    pub fn seek(self: *IOStream, offset: i64, relative_to: SeekRelativeTo) Error!i64 {
        return greater_than_or_equal_to_zero_or_fail_err(C.SDL_SeekIO(self.to_c(), offset, relative_to.to_c()));
    }
    pub fn current_offest(self: *IOStream) Error!i64 {
        return greater_than_or_equal_to_zero_or_fail_err(C.SDL_TellIO(self.to_c()));
    }
    pub fn read_from_stream_into_ptr(self: *IOStream, dst_ptr: [*]u8, read_len: usize) Error!usize {
        return nonzero_or_fail_err(C.SDL_ReadIO(self.to_c(), dst_ptr, read_len));
    }
    pub fn write_from_ptr_into_stream(self: *IOStream, src_ptr: [*]const u8, write_len: usize) Error!usize {
        return nonzero_or_fail_err(C.SDL_WriteIO(self.to_c(), src_ptr, write_len));
    }
    pub fn c_printf(self: *IOStream, fmt: [*:0]const u8, args: anytype) Error!usize {
        return nonzero_or_fail_err(@call(.auto, C.SDL_IOprintf, .{ self.to_c(), fmt } ++ args));
    }
    pub fn flush(self: *IOStream) Error!void {
        return ok_or_fail_err(C.SDL_FlushIO(self.to_c()));
    }
    pub fn load_file_from_stream(self: *IOStream, close_stream: bool) Error!IOFile {
        var len: usize = 0;
        const ptr = try ptr_cast_or_null_err([*:0]u8, C.SDL_LoadFile_IO(self.to_c(), &len, close_stream));
        return IOFile{ .data = ptr[0..len :0] };
    }
    pub fn save_file_into_stream(self: *IOStream, file: IOFile, close_stream: bool) Error!void {
        return ok_or_fail_err(C.SDL_SaveFile_IO(self.to_c(), file.data.ptr, file.data.len, close_stream));
    }
    pub fn read_u8(self: *IOStream) Error!u8 {
        var val: u8 = 0;
        try ok_or_fail_err(C.SDL_ReadU8(self.to_c(), &val));
        return val;
    }
    pub fn read_i8(self: *IOStream) Error!i8 {
        var val: i8 = 0;
        try ok_or_fail_err(C.SDL_ReadS8(self.to_c(), &val));
        return val;
    }
    pub fn read_u16_le(self: *IOStream) Error!u16 {
        var val: u16 = 0;
        try ok_or_fail_err(C.SDL_ReadU16LE(self.to_c(), &val));
        return val;
    }
    pub fn read_i16_le(self: *IOStream) Error!i16 {
        var val: i16 = 0;
        try ok_or_fail_err(C.SDL_ReadS16LE(self.to_c(), &val));
        return val;
    }
    pub fn read_u16_be(self: *IOStream) Error!u16 {
        var val: u16 = 0;
        try ok_or_fail_err(C.SDL_ReadU16BE(self.to_c(), &val));
        return val;
    }
    pub fn read_i16_be(self: *IOStream) Error!i16 {
        var val: i16 = 0;
        try ok_or_fail_err(C.SDL_ReadS16BE(self.to_c(), &val));
        return val;
    }
    pub fn read_u32_le(self: *IOStream) Error!u32 {
        var val: u32 = 0;
        try ok_or_fail_err(C.SDL_ReadU32LE(self.to_c(), &val));
        return val;
    }
    pub fn read_i32_le(self: *IOStream) Error!i32 {
        var val: i32 = 0;
        try ok_or_fail_err(C.SDL_ReadS32LE(self.to_c(), &val));
        return val;
    }
    pub fn read_u32_be(self: *IOStream) Error!u32 {
        var val: u32 = 0;
        try ok_or_fail_err(C.SDL_ReadU32BE(self.to_c(), &val));
        return val;
    }
    pub fn read_i32_be(self: *IOStream) Error!i32 {
        var val: i32 = 0;
        try ok_or_fail_err(C.SDL_ReadS32BE(self.to_c(), &val));
        return val;
    }
    pub fn read_u64_le(self: *IOStream) Error!u64 {
        var val: u64 = 0;
        try ok_or_fail_err(C.SDL_ReadU64LE(self.to_c(), &val));
        return val;
    }
    pub fn read_i64_le(self: *IOStream) Error!i64 {
        var val: i64 = 0;
        try ok_or_fail_err(C.SDL_ReadS64LE(self.to_c(), &val));
        return val;
    }
    pub fn read_u64_be(self: *IOStream) Error!u64 {
        var val: u64 = 0;
        try ok_or_fail_err(C.SDL_ReadU64BE(self.to_c(), &val));
        return val;
    }
    pub fn read_i64_be(self: *IOStream) Error!i64 {
        var val: i64 = 0;
        try ok_or_fail_err(C.SDL_ReadS64BE(self.to_c(), &val));
        return val;
    }
    pub fn write_u8(self: *IOStream, val: u8) Error!void {
        return ok_or_fail_err(C.SDL_WriteU8(self.to_c(), val));
    }
    pub fn write_i8(self: *IOStream, val: i8) Error!void {
        return ok_or_fail_err(C.SDL_WriteS8(self.to_c(), val));
    }
    pub fn write_u16_le(self: *IOStream, val: u16) Error!void {
        return ok_or_fail_err(C.SDL_WriteU16LE(self.to_c(), val));
    }
    pub fn write_i16_le(self: *IOStream, val: i16) Error!void {
        return ok_or_fail_err(C.SDL_WriteS16LE(self.to_c(), val));
    }
    pub fn write_u16_be(self: *IOStream, val: u16) Error!void {
        return ok_or_fail_err(C.SDL_WriteU16BE(self.to_c(), val));
    }
    pub fn write_i16_be(self: *IOStream, val: i16) Error!void {
        return ok_or_fail_err(C.SDL_WriteS16BE(self.to_c(), val));
    }
    pub fn write_u32_le(self: *IOStream, val: u32) Error!void {
        return ok_or_fail_err(C.SDL_WriteU32LE(self.to_c(), val));
    }
    pub fn write_i32_le(self: *IOStream, val: i32) Error!void {
        return ok_or_fail_err(C.SDL_WriteS32LE(self.to_c(), val));
    }
    pub fn write_u32_be(self: *IOStream, val: u32) Error!void {
        return ok_or_fail_err(C.SDL_WriteU32BE(self.to_c(), val));
    }
    pub fn write_i32_be(self: *IOStream, val: i32) Error!void {
        return ok_or_fail_err(C.SDL_WriteS32BE(self.to_c(), val));
    }
    pub fn write_u64_le(self: *IOStream, val: u64) Error!void {
        return ok_or_fail_err(C.SDL_WriteU64LE(self.to_c(), val));
    }
    pub fn write_i64_le(self: *IOStream, val: i64) Error!void {
        return ok_or_fail_err(C.SDL_WriteS64LE(self.to_c(), val));
    }
    pub fn write_u64_be(self: *IOStream, val: u64) Error!void {
        return ok_or_fail_err(C.SDL_WriteU64BE(self.to_c(), val));
    }
    pub fn write_i64_be(self: *IOStream, val: i64) Error!void {
        return ok_or_fail_err(C.SDL_WriteS64BE(self.to_c(), val));
    }
    pub fn save_bmp_to_new_surface(self: *IOStream, close_stream: bool) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_LoadBMP_IO(self.to_c(), close_stream));
    }
    pub fn load_bmp_from_surface(self: *IOStream, surface: *Surface, close_stream: bool) Error!void {
        return ok_or_fail_err(C.SDL_SaveBMP_IO(surface.to_c_ptr(), self.to_c(), close_stream));
    }
    pub fn load_wav(self: *IOStream, close_stream: bool) Error!WaveAudio {
        var ptr: [*c]u8 = undefined;
        var len: u32 = 0;
        var spec: AudioSpec = undefined;
        try ok_or_fail_err(C.SDL_LoadWAV_IO(self.to_c(), close_stream, @ptrCast(@alignCast(&spec)), &ptr, &len));
        const good_ptr = try ptr_cast_or_null_err([*]u8, ptr);
        return WaveAudio{
            .data = good_ptr[0..len],
            .spec = spec,
        };
    }

    pub const Props = struct {
        pub const WINDOWS_HANDLE = Property.new(.POINTER, C.SDL_PROP_IOSTREAM_WINDOWS_HANDLE_POINTER);
        pub const STD_IO_FILE = Property.new(.POINTER, C.SDL_PROP_IOSTREAM_STDIO_FILE_POINTER);
        pub const FILE_DESCRIPTOR = Property.new(.INTEGER, C.SDL_PROP_IOSTREAM_FILE_DESCRIPTOR_NUMBER);
        pub const ANDROID_AASSET = Property.new(.POINTER, C.SDL_PROP_IOSTREAM_ANDROID_AASSET_POINTER);
        pub const MEMORY = Property.new(.POINTER, C.SDL_PROP_IOSTREAM_MEMORY_POINTER);
        pub const MEMORY_SIZE = Property.new(.INTEGER, C.SDL_PROP_IOSTREAM_MEMORY_SIZE_NUMBER);
        pub const DYNAMIC_MEMORY = Property.new(.POINTER, C.SDL_PROP_IOSTREAM_DYNAMIC_MEMORY_POINTER);
        pub const DYNAMIC_CHUNKSIZE = Property.new(.INTEGER, C.SDL_PROP_IOSTREAM_DYNAMIC_CHUNKSIZE_NUMBER);
    };
};

pub const IOMode = enum(u8) {
    Read = 0,
    TruncateWrite = 1,
    AppendWrite = 2,
    ReadWrite = 3,
    TruncateReadWrite = 4,
    AppendReadWrite = 5,
    BinaryRead = 6,
    BinaryTruncateWrite = 7,
    BinaryAppendWrite = 8,
    BinaryReadWrite = 9,
    BinaryTruncateReadWrite = 10,
    BinaryAppendReadWrite = 11,

    inline fn to_c(self: IOMode) [*:0]const u8 {
        return STR[@intFromEnum(self)];
    }

    const STR = [12][*:0]const u8{
        "r",
        "w",
        "a",
        "r+",
        "w+",
        "a+",
        "rb",
        "wb",
        "ab",
        "r+b",
        "w+b",
        "a+b",
    };
};

pub const WaveAudio = struct {
    data: []u8 = undefined,
    spec: AudioSpec = undefined,

    pub fn destroy(self: *WaveAudio) void {
        Mem.free(self.data.ptr);
    }
};

/// Helper struct for SDL functioons that require a `?*FRect` where:
/// - `null` == use entire area
/// - `*FRect` == use specific rect
///
/// As well as four values for edge widths
pub const NinePatch_F32 = extern struct {
    rect_ptr: ?*const Rect_f32 = null,
    left: f32 = 0,
    right: f32 = 0,
    top: f32 = 0,
    bottom: f32 = 0,

    pub fn rect(rct: *const Rect_f32, left: f32, right: f32, top: f32, bottom: f32) NinePatch_F32 {
        return NinePatch_F32{
            .rect_ptr = rct,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    pub fn entire_area(left: f32, right: f32, top: f32, bottom: f32) NinePatch_F32 {
        return NinePatch_F32{
            .rect_ptr = null,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    pub inline fn rect_to_c(self: NinePatch_F32) ?*C.SDL_FRect {
        return @ptrCast(@alignCast(self.rect_ptr));
    }
};

/// Helper struct for SDL functioons that require a `?*IRect` where:
/// - `null` == use entire area
/// - `*IRect` == use specific rect
///
/// As well as four values for edge widths
pub const NinePatch_c_int = extern struct {
    rect_ptr: ?*const Rect_c_int = null,
    left: c_int = 0,
    right: c_int = 0,
    top: c_int = 0,
    bottom: c_int = 0,

    pub fn rect(r: *const Rect_c_int, left: c_int, right: c_int, top: c_int, bottom: c_int) NinePatch_c_int {
        return NinePatch_c_int{
            .rect_ptr = r,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    pub fn entire_area(left: c_int, right: c_int, top: c_int, bottom: c_int) NinePatch_c_int {
        return NinePatch_c_int{
            .rect_ptr = null,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    pub inline fn rect_to_c(self: NinePatch_c_int) ?*C.SDL_Rect {
        return @ptrCast(@alignCast(self.rect_ptr));
    }
};

pub const PropertiesID = extern struct {
    id: u32 = 0,

    pub const NULL = PropertiesID{ .id = 0 };

    pub inline fn is_null(self: PropertiesID) bool {
        return self.id == 0;
    }

    inline fn new(id: u32) Error!PropertiesID {
        return PropertiesID{ .id = try nonzero_or_null_err(id) };
    }

    pub fn global_properties() Error!PropertiesID {
        return new(C.SDL_GetGlobalProperties());
    }
    pub fn create_new() Error!PropertiesID {
        return new(C.SDL_CreateProperties());
    }
    pub fn copy_to(self: PropertiesID, dst_props: PropertiesID) Error!void {
        return ok_or_fail_err(C.SDL_CopyProperties(self.id, dst_props.id));
    }
    pub fn lock(self: PropertiesID) Error!void {
        return ok_or_fail_err(C.SDL_LockProperties(self.id));
    }
    pub fn unlock(self: PropertiesID) void {
        C.SDL_UnlockProperties(self.id);
    }
    pub fn set_pointer_property_with_cleanup(self: PropertiesID, name: [*:0]const u8, value: ?*anyopaque, cleanup: *const PropertyCleanupCallback, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_SetPointerPropertyWithCleanup(self.id, name, value, @ptrCast(@alignCast(cleanup)), userdata));
    }
    pub fn set_pointer_property(self: PropertiesID, name: [*:0]const u8, value: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_SetPointerProperty(self.id, name, value));
    }
    pub fn set_string_property(self: PropertiesID, name: [*:0]const u8, value: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_SetStringProperty(self.id, name, value));
    }
    pub fn set_integer_property(self: PropertiesID, name: [*:0]const u8, value: i64) Error!void {
        return ok_or_fail_err(C.SDL_SetNumberProperty(self.id, name, value));
    }
    pub fn set_float_property(self: PropertiesID, name: [*:0]const u8, value: f32) Error!void {
        return ok_or_fail_err(C.SDL_SetFloatProperty(self.id, name, value));
    }
    pub fn set_bool_property(self: PropertiesID, name: [*:0]const u8, value: bool) Error!void {
        return ok_or_fail_err(C.SDL_SetBooleanProperty(self.id, name, value));
    }
    pub fn set_property(self: PropertiesID, comptime prop: Property, val: Property.T_VAL(prop)) Error!void {
        switch (prop.kind) {
            PropertyType.BOOLEAN => return self.set_bool_property(prop.name, val),
            PropertyType.INTEGER => return self.set_integer_property(prop.name, val),
            PropertyType.FLOAT => return self.set_float_property(prop.name, val),
            PropertyType.STRING => return self.set_string_property(prop.name, val),
            PropertyType.POINTER => return self.set_pointer_property(prop.name, val),
            else => unreachable,
        }
    }
    pub fn has_property_name(self: PropertiesID, name: [*:0]const u8) bool {
        return C.SDL_HasProperty(self.id, name);
    }
    pub fn get_property_type(self: PropertiesID, name: [*:0]const u8) PropertyType {
        return PropertyType.from_c(C.SDL_GetPropertyType(self.id, name));
    }
    pub fn get_pointer_property_or_default(self: PropertiesID, name: [*:0]const u8, default: ?*anyopaque) ?*anyopaque {
        return C.SDL_GetPointerProperty(self.id, name, default);
    }
    pub fn get_string_property_or_default(self: PropertiesID, name: [*:0]const u8, default: [*:0]const u8) [*:0]const u8 {
        return C.SDL_GetStringProperty(self.id, name, default);
    }
    pub fn get_integer_property_or_default(self: PropertiesID, name: [*:0]const u8, default: i64) i64 {
        return C.SDL_GetNumberProperty(self.id, name, default);
    }
    pub fn get_float_property_or_default(self: PropertiesID, name: [*:0]const u8, default: f32) f32 {
        return C.SDL_GetFloatProperty(self.id, name, default);
    }
    pub fn get_bool_property_or_default(self: PropertiesID, name: [*:0]const u8, default: bool) bool {
        return C.SDL_GetBooleanProperty(self.id, name, default);
    }
    pub fn clear_property(self: PropertiesID, name: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_ClearProperty(self.id, name));
    }
    pub fn do_callback_on_each_property(self: PropertiesID, callback: *EnumeratePropertiesCallback, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_EnumerateProperties(self.id, @ptrCast(@alignCast(callback)), userdata));
    }
    pub fn destroy(self: PropertiesID) void {
        C.SDL_DestroyProperties(self.id);
    }
};

pub const ActionFuncCallback = fn () callconv(.c) void;

pub const Thread = opaque {
    pub const to_c = c_opaque_conversions(Thread, C.SDL_Thread).to_c_ptr;
    pub const from_c = c_opaque_conversions(Thread, C.SDL_Thread).from_c_ptr;

    pub fn create_thread_with_begin_end(thread_func: ?*const ThreadFunc, name: [*:0]const u8, userdata: ?*anyopaque, begin_func: ?*const ActionFuncCallback, end_func: ?*const ActionFuncCallback) Error!*Thread {
        return ptr_cast_or_fail_err(*Thread, C.SDL_CreateThreadRuntime(Cast.ptr_cast(thread_func, C.SDL_ThreadFunction), name, userdata, begin_func, end_func));
    }
    pub fn create_thread_with_props_begin_end(props: PropertiesID, begin_func: ?*const ActionFuncCallback, end_func: ?*const ActionFuncCallback) Error!*Thread {
        return ptr_cast_or_fail_err(*Thread, C.SDL_CreateThreadWithPropertiesRuntime(props.id, begin_func, end_func));
    }
    pub fn create_thread(thread_func: ?*const ThreadFunc, name: [*:0]const u8, userdata: ?*anyopaque) Error!*Thread {
        return create_thread_with_begin_end(thread_func, name, userdata, null, null);
    }
    pub fn create_thread_with_props(props: PropertiesID) Error!*Thread {
        return create_thread_with_props_begin_end(props, null, null);
    }
    pub fn get_name(self: *Thread) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetThreadName(self.to_c_ptr()));
    }
    pub fn get_thread_id(self: *Thread) Error!ThreadID {
        ThreadID{ .id = try nonzero_or_null_err(C.SDL_GetThreadID(self.to_c_ptr())) };
    }
    pub fn get_current_thread_id() Error!ThreadID {
        return ThreadID{ .id = try nonzero_or_null_err(C.SDL_GetCurrentThreadID()) };
    }
    pub fn set_current_thread_priority(priority: ThreadPriority) Error!void {
        return ok_or_fail_err(C.SDL_SetCurrentThreadPriority(priority.to_c()));
    }
    pub fn wait_for_completion(self: *Thread) Error!c_int {
        var result: c_int = 0;
        C.SDL_WaitThread(self.to_c_ptr(), &result);
        return positive_or_invalid_err(result);
    }
    pub fn get_thread_state(self: *Thread) ThreadState {
        return ThreadState.from_c(C.SDL_GetThreadState(self.to_c_ptr()));
    }
    pub fn detatch(self: *Thread) void {
        C.SDL_DetachThread(self.to_c_ptr());
    }
    pub const CreateProps = struct {
        pub const ENTRY_FUNC = Property.new(.POINTER, C.SDL_PROP_THREAD_CREATE_ENTRY_FUNCTION_POINTER);
        pub const NAME = Property.new(.STRING, C.SDL_PROP_THREAD_CREATE_NAME_STRING);
        pub const USERDATA = Property.new(.POINTER, C.SDL_PROP_THREAD_CREATE_USERDATA_POINTER);
        pub const STACK_SIZE = Property.new(.INTEGER, C.SDL_PROP_THREAD_CREATE_STACKSIZE_NUMBER);
    };
};

pub const ThreadID = extern struct {
    id: C.SDL_ThreadID = 0,
    pub fn set_linux_thread_priority(self: ThreadID, priority: c_int) Error!void {
        return ok_or_fail_err(C.SDL_SetLinuxThreadPriority(@intCast(self.id), priority));
    }
    pub fn set_linux_thread_priority_and_policy(self: ThreadID, priority: c_int, schedule_policy: c_int) Error!void {
        return ok_or_fail_err(C.SDL_SetLinuxThreadPriorityAndPolicy(@intCast(self.id), priority, schedule_policy));
    }
};

pub const Mutex = opaque {
    pub const to_c = c_opaque_conversions(Mutex, C.SDL_Mutex).to_c_ptr;
    pub const from_c = c_opaque_conversions(Mutex, C.SDL_Mutex).from_c_ptr;
    pub fn create() Error!*Mutex {
        return ptr_cast_or_fail_err(*Mutex, C.SDL_CreateMutex());
    }
    pub fn wait_lock(self: *Mutex) void {
        C.SDL_LockMutex(self.to_c_ptr());
    }
    pub fn try_lock(self: *Mutex) bool {
        return C.SDL_TryLockMutex(self.to_c_ptr());
    }
    pub fn unlock(self: *Mutex) void {
        C.SDL_UnlockMutex(self.to_c_ptr());
    }
    pub fn destroy(self: *Mutex) void {
        C.SDL_DestroyMutex(self.to_c_ptr());
    }
};

pub const InitState = extern struct {
    status: AtomicInt = .{},
    thread: ThreadID = .{},
    _reserved: ?*anyopaque = null,

    pub const to_c_ptr = c_non_opaque_conversions(InitState, C.SDL_InitState).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(InitState, C.SDL_InitState).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(InitState, C.SDL_InitState).to_c;
    pub const from_c = c_non_opaque_conversions(InitState, C.SDL_InitState).from_c;
    pub fn should_init(self: *InitState) bool {
        return C.SDL_ShouldInit(self.to_c_ptr());
    }
    pub fn should_quit(self: *InitState) bool {
        return C.SDL_ShouldQuit(self.to_c_ptr());
    }
    pub fn set_initialized_state(self: *InitState, state: bool) void {
        return C.SDL_SetInitialized(self.to_c_ptr(), state);
    }
};

pub const PropertyCleanupCallback = fn (userdata: ?*anyopaque, value_ptr: ?*anyopaque) callconv(.c) void;
pub const EnumeratePropertiesCallback = fn (userdata: ?*anyopaque, props_id: PropertiesID, prop_name: [*:0]const u8) callconv(.c) void;

pub const PropertyType = enum(c_uint) {
    INVALID = C.SDL_PROPERTY_TYPE_INVALID,
    POINTER = C.SDL_PROPERTY_TYPE_POINTER,
    STRING = C.SDL_PROPERTY_TYPE_STRING,
    INTEGER = C.SDL_PROPERTY_TYPE_NUMBER,
    FLOAT = C.SDL_PROPERTY_TYPE_FLOAT,
    BOOLEAN = C.SDL_PROPERTY_TYPE_BOOLEAN,

    pub const to_c = c_enum_conversions(PropertyType, c_uint).to_c;
    pub const from_c = c_enum_conversions(PropertyType, c_uint).from_c;
};

pub const Property = struct {
    kind: PropertyType,
    name: [*:0]const u8,

    pub fn new(kind: PropertyType, name: [*:0]const u8) Property {
        return Property{
            .kind = kind,
            .name = name,
        };
    }

    pub fn T_VAL(comptime self: Property) type {
        return switch (self.kind) {
            .BOOLEAN => bool,
            .FLOAT => f32,
            .INTEGER => i64,
            .STRING => [*:0]const u8,
            .POINTER => ?*anyopaque,
            .INVALID => void,
        };
    }
};

pub const InitStatus = enum(C.SDL_InitStatus) {
    UNINIT = C.SDL_INIT_STATUS_UNINITIALIZED,
    INIT_IN_PROGRESS = C.SDL_INIT_STATUS_INITIALIZING,
    INIT = C.SDL_INIT_STATUS_INITIALIZED,
    UNINIT_IN_PROGRESS = C.SDL_INIT_STATUS_UNINITIALIZING,

    pub const to_c = c_enum_conversions(InitStatus, C.SDL_InitStatus).to_c;
    pub const from_c = c_enum_conversions(InitStatus, C.SDL_InitStatus).from_c;
};

pub const InitFlags = Flags(enum(u32) {
    AUDIO = C.SDL_INIT_AUDIO,
    VIDEO = C.SDL_INIT_VIDEO,
    JOYSTICK = C.SDL_INIT_JOYSTICK,
    HAPTIC = C.SDL_INIT_HAPTIC,
    GAMEPAD = C.SDL_INIT_GAMEPAD,
    EVENTS = C.SDL_INIT_EVENTS,
    SENSOR = C.SDL_INIT_SENSOR,
    CAMERA = C.SDL_INIT_CAMERA,
}, enum(u32) {});

pub const UserFolder = enum(C.SDL_Folder) {
    HOME = C.SDL_FOLDER_HOME,
    DESKTOP = C.SDL_FOLDER_DESKTOP,
    DOCUMENTS = C.SDL_FOLDER_DOCUMENTS,
    DOWNLOADS = C.SDL_FOLDER_DOWNLOADS,
    MUSIC = C.SDL_FOLDER_MUSIC,
    PICTURES = C.SDL_FOLDER_PICTURES,
    PUBLIC_SHARE = C.SDL_FOLDER_PUBLICSHARE,
    SAVED_GAMES = C.SDL_FOLDER_SAVEDGAMES,
    SCREENSHOTS = C.SDL_FOLDER_SCREENSHOTS,
    TEMPLATES = C.SDL_FOLDER_TEMPLATES,
    VIDEOS = C.SDL_FOLDER_VIDEOS,

    pub const COUNT = C.SDL_FOLDER_COUNT;

    pub const to_c = c_enum_conversions(UserFolder, C.SDL_Folder).to_c;
    pub const from_c = c_enum_conversions(UserFolder, C.SDL_Folder).from_c;
};

pub const FileDialogFilter = extern struct {
    name: ?[*:0]const u8 = null,
    pattern: ?[*:0]const u8 = null,

    pub const to_c_ptr = c_non_opaque_conversions(FileDialogFilter, C.SDL_DialogFileFilter).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(FileDialogFilter, C.SDL_DialogFileFilter).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(FileDialogFilter, C.SDL_DialogFileFilter).to_c;
    pub const from_c = c_non_opaque_conversions(FileDialogFilter, C.SDL_DialogFileFilter).from_c;
};

pub const FileDialogCallback = fn (userdata: ?*anyopaque, selected_files: ?[*:null]?[*:0]const u8, selected_filter_index: c_int) callconv(.c) void;

pub const GlobFlags = Flags(enum(u32) {
    CASE_INSENSITIVE = C.SDL_GLOB_CASEINSENSITIVE,
}, null);

pub const Filesystem = struct {
    //TODO

    pub fn get_app_executable_directory() Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetBasePath());
    }
    pub fn get_user_data_directory(org_name: [*:0]const u8, app_name: [*:0]const u8) Error!AllocatedString {
        return AllocatedString{ .str = try ptr_cast_or_null_err([*:0]u8, C.SDL_GetPrefPath(org_name, app_name)) };
    }
    pub fn get_user_folder(folder_kind: UserFolder) Error!AllocatedString {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetUserFolder(folder_kind.to_c()));
    }
    //CHECKPOINT
    // pub extern fn SDL_GetUserFolder(folder: SDL_Folder) [*c]const u8;
    // pub extern fn SDL_CreateDirectory(path: [*c]const u8) bool;
    // pub extern fn SDL_EnumerateDirectory(path: [*c]const u8, callback: SDL_EnumerateDirectoryCallback, userdata: ?*anyopaque) bool;
    // pub extern fn SDL_RemovePath(path: [*c]const u8) bool;
    // pub extern fn SDL_RenamePath(oldpath: [*c]const u8, newpath: [*c]const u8) bool;
    // pub extern fn SDL_CopyFile(oldpath: [*c]const u8, newpath: [*c]const u8) bool;
    // pub extern fn SDL_GetPathInfo(path: [*c]const u8, info: [*c]SDL_PathInfo) bool;
    // pub extern fn SDL_GlobDirectory(path: [*c]const u8, pattern: [*c]const u8, flags: SDL_GlobFlags, count: [*c]c_int) [*c][*c]u8;
    // pub extern fn SDL_GetCurrentDirectory() [*c]u8;
    // pub extern fn SDL_ShowOpenFileDialog(callback: SDL_DialogFileCallback, userdata: ?*anyopaque, window: ?*SDL_Window, filters: [*c]const SDL_DialogFileFilter, nfilters: c_int, default_location: [*c]const u8, allow_many: bool) void;
    // pub extern fn SDL_ShowSaveFileDialog(callback: SDL_DialogFileCallback, userdata: ?*anyopaque, window: ?*SDL_Window, filters: [*c]const SDL_DialogFileFilter, nfilters: c_int, default_location: [*c]const u8) void;
    // pub extern fn SDL_ShowOpenFolderDialog(callback: SDL_DialogFileCallback, userdata: ?*anyopaque, window: ?*SDL_Window, default_location: [*c]const u8, allow_many: bool) void;
    // pub extern fn SDL_ShowFileDialogWithProperties(@"type": SDL_FileDialogType, callback: SDL_DialogFileCallback, userdata: ?*anyopaque, props: SDL_PropertiesID) void;

    pub const FileDialogProps = struct {
        pub const FILTERS = Property.new(.POINTER, C.SDL_PROP_FILE_DIALOG_FILTERS_POINTER);
        pub const NUM_FILTERS = Property.new(.INTEGER, C.SDL_PROP_FILE_DIALOG_NFILTERS_NUMBER);
        pub const WINDOW = Property.new(.POINTER, C.SDL_PROP_FILE_DIALOG_WINDOW_POINTER);
        pub const LOCATION = Property.new(.STRING, C.SDL_PROP_FILE_DIALOG_LOCATION_STRING);
        pub const ALLOW_MANY = Property.new(.BOOLEAN, C.SDL_PROP_FILE_DIALOG_MANY_BOOLEAN);
        pub const TITLE = Property.new(.STRING, C.SDL_PROP_FILE_DIALOG_TITLE_STRING);
        pub const ACCEPT_STR = Property.new(.STRING, C.SDL_PROP_FILE_DIALOG_ACCEPT_STRING);
        pub const CANCEL_STR = Property.new(.STRING, C.SDL_PROP_FILE_DIALOG_CANCEL_STRING);
    };
};

pub const FileDialogType = enum(C.SDL_FileDialogType) {
    OPEN_FILE = C.SDL_FILEDIALOG_OPENFILE,
    SAVE_FILE = C.SDL_FILEDIALOG_SAVEFILE,
    OPEN_FOLDER = C.SDL_FILEDIALOG_OPENFOLDER,

    pub const to_c = c_enum_conversions(FileDialogType, C.SDL_FileDialogType).to_c;
    pub const from_c = c_enum_conversions(FileDialogType, C.SDL_FileDialogType).from_c;
};

pub const AsyncIO = opaque {
    pub const to_c_ptr = c_opaque_conversions(AsyncIO, C.SDL_AsyncIO).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(AsyncIO, C.SDL_AsyncIO).from_c_ptr;

    pub inline fn from_file(file_path: [*:0]const u8, mode: IOMode) Error!*AsyncIO {
        return ptr_cast_or_null_err(*AsyncIO, C.SDL_AsyncIOFromFile(file_path, mode.to_c()));
    }
    pub inline fn get_size(self: *AsyncIO) u64 {
        const result = try nonzero_or_fail_err(C.SDL_GetAsyncIOSize(self.to_c_ptr()));
        return @intCast(result);
    }
    pub inline fn read_to(self: *AsyncIO, dst: *anyopaque, self_byte_offset: u64, read_len: u64, async_io_queue: *AsyncIOQueue, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_ReadAsyncIO(self.to_c_ptr(), dst, self_byte_offset, read_len, async_io_queue, userdata));
    }
    pub inline fn write_from(self: *AsyncIO, src: *anyopaque, self_byte_offset: u64, write_len: u64, async_io_queue: *AsyncIOQueue, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_WriteAsyncIO(self.to_c_ptr(), src, self_byte_offset, write_len, async_io_queue, userdata));
    }
    pub inline fn close(self: *AsyncIO, flush: bool, async_io_queue: *AsyncIOQueue, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_CloseAsyncIO(self.to_c_ptr(), flush, async_io_queue, userdata));
    }
};

pub const AsyncIOTaskType = enum(C.SDL_AsyncIOTaskType) {
    READ = C.SDL_ASYNCIO_TASK_READ,
    WRITE = C.SDL_ASYNCIO_TASK_WRITE,
    CLOSE = C.SDL_ASYNCIO_TASK_CLOSE,

    pub const to_c = c_enum_conversions(AsyncIOTaskType, C.SDL_AsyncIOTaskType).to_c;
    pub const from_c = c_enum_conversions(AsyncIOTaskType, C.SDL_AsyncIOTaskType).from_c;
};

pub const AsyncIOResult = enum(C.SDL_AsyncIOResult) {
    COMPLETE = C.SDL_ASYNCIO_COMPLETE,
    FAILURE = C.SDL_ASYNCIO_FAILURE,
    CANCELED = C.SDL_ASYNCIO_CANCELED,

    pub const to_c = c_enum_conversions(AsyncIOResult, C.SDL_AsyncIOResult).to_c;
    pub const from_c = c_enum_conversions(AsyncIOResult, C.SDL_AsyncIOResult).from_c;
};

pub const AsyncIOOutcome = extern struct {
    async_io: ?*AsyncIO = null,
    type: AsyncIOTaskType = .CLOSE,
    result: AsyncIOResult = .CANCELED,
    buffer: ?*anyopaque = null,
    offset: u64 = 0,
    bytes_requested: u64 = 0,
    bytes_transferred: u64 = 0,
    userdata: ?*anyopaque = null,

    pub const to_c_ptr = c_non_opaque_conversions(AsyncIOOutcome, C.SDL_AsyncIOOutcome).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(AsyncIOOutcome, C.SDL_AsyncIOOutcome).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(AsyncIOOutcome, C.SDL_AsyncIOOutcome).to_c;
    pub const from_c = c_non_opaque_conversions(AsyncIOOutcome, C.SDL_AsyncIOOutcome).from_c;
};

pub const AsyncIOQueue = opaque {
    pub const to_c_ptr = c_opaque_conversions(AsyncIOQueue, C.SDL_AsyncIOQueue).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(AsyncIOQueue, C.SDL_AsyncIOQueue).from_c_ptr;
    pub inline fn create() Error!*AsyncIOQueue {
        return ptr_cast_or_fail_err(*AsyncIOQueue, C.SDL_CreateAsyncIOQueue());
    }
    pub inline fn destroy(self: *AsyncIOQueue) void {
        C.SDL_DestroyAsyncIOQueue(self.to_c_ptr());
    }
    pub inline fn get_next_completed(self: *AsyncIOQueue) ?AsyncIOOutcome {
        var outcome: AsyncIOOutcome = undefined;
        if (!C.SDL_GetAsyncIOResult(self.to_c_ptr(), @ptrCast(@alignCast(&outcome)))) return null;
        return outcome;
    }
    pub inline fn wait_ms_for_next_complete(self: *AsyncIOQueue, timeout_ms: u32) ?AsyncIOOutcome {
        var outcome: AsyncIOOutcome = undefined;
        if (!C.SDL_WaitAsyncIOResult(self.to_c_ptr(), @ptrCast(@alignCast(&outcome)), @intCast(timeout_ms))) return null;
        return outcome;
    }
    pub inline fn wait_until_next_complete(self: *AsyncIOQueue) ?AsyncIOOutcome {
        var outcome: AsyncIOOutcome = undefined;
        if (!C.SDL_WaitAsyncIOResult(self.to_c_ptr(), @ptrCast(@alignCast(&outcome)), -1)) return null;
        return outcome;
    }
    pub inline fn cancel_all_waiting(self: *AsyncIOQueue) void {
        C.SDL_SignalAsyncIOQueue(self.to_c_ptr());
    }
    pub inline fn load_file(self: *AsyncIOQueue, file_name: [*:0]const u8, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_LoadFileAsync(file_name, self.to_c_ptr(), userdata));
    }
};
//TODO
// pub const SDL_SpinLock = c_int;
// pub extern fn SDL_TryLockSpinlock(lock: [*c]SDL_SpinLock) bool;
// pub extern fn SDL_LockSpinlock(lock: [*c]SDL_SpinLock) void;
// pub extern fn SDL_UnlockSpinlock(lock: [*c]SDL_SpinLock) void;
// pub extern fn SDL_MemoryBarrierReleaseFunction() void;
// pub extern fn SDL_MemoryBarrierAcquireFunction() void;
// pub const struct_SDL_AtomicInt = extern struct {
//     value: c_int = @import("std").mem.zeroes(c_int),
// };

// pub const SDL_AtomicU32 = struct_SDL_AtomicU32;
// pub extern fn SDL_CompareAndSwapAtomicU32(a: [*c]SDL_AtomicU32, oldval: Uint32, newval: Uint32) bool;
// pub extern fn SDL_SetAtomicU32(a: [*c]SDL_AtomicU32, v: Uint32) Uint32;
// pub extern fn SDL_GetAtomicU32(a: [*c]SDL_AtomicU32) Uint32;
// pub extern fn SDL_CompareAndSwapAtomicPointer(a: [*c]?*anyopaque, oldval: ?*anyopaque, newval: ?*anyopaque) bool;
// pub extern fn SDL_SetAtomicPointer(a: [*c]?*anyopaque, v: ?*anyopaque) ?*anyopaque;
// pub extern fn SDL_GetAtomicPointer(a: [*c]?*anyopaque) ?*anyopaque;

pub const AtomicInt = extern struct {
    val: c_int = 0,

    pub const to_c_ptr = c_non_opaque_conversions(AtomicInt, C.SDL_AtomicInt).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(AtomicInt, C.SDL_AtomicInt).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(AtomicInt, C.SDL_AtomicInt).to_c;
    pub const from_c = c_non_opaque_conversions(AtomicInt, C.SDL_AtomicInt).from_c;

    pub fn compare_and_swap(self: *AtomicInt, old_val_matches: c_int, new_val: c_int) bool {
        return C.SDL_CompareAndSwapAtomicInt(self.to_c_ptr(), old_val_matches, new_val);
    }
    pub fn set(self: *AtomicInt, val: c_int) c_int {
        return C.SDL_SetAtomicInt(self.to_c_ptr(), val);
    }
    pub fn add(self: *AtomicInt, val: c_int) c_int {
        return C.SDL_AddAtomicInt(self.to_c_ptr(), val);
    }
    pub fn get(self: *AtomicInt) c_int {
        return C.SDL_GetAtomicInt(self.to_c_ptr());
    }
    pub fn increment(self: *AtomicInt) c_int {
        return C.SDL_AddAtomicInt(self.to_c_ptr(), 1);
    }
    pub fn decrement(self: *AtomicInt) c_int {
        return C.SDL_AddAtomicInt(self.to_c_ptr(), -1);
    }
};

pub const TSL_ID = extern struct {
    id: AtomicInt,

    pub const to_c_ptr = c_non_opaque_conversions(TSL_ID, C.SDL_TLSID).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(TSL_ID, C.SDL_TLSID).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(TSL_ID, C.SDL_TLSID).to_c;
    pub const from_c = c_non_opaque_conversions(TSL_ID, C.SDL_TLSID).from_c;
    //TODO
    // pub extern fn SDL_GetTLS(id: [*c]SDL_TLSID) ?*anyopaque;
    // pub const SDL_TLSDestructorCallback = ?*const fn (?*anyopaque) callconv(.c) void;
    // pub extern fn SDL_SetTLS(id: [*c]SDL_TLSID, value: ?*const anyopaque, destructor: SDL_TLSDestructorCallback) bool;
    // pub extern fn SDL_CleanupTLS() void;
};

pub const TLS = opaque {};

pub const ThreadPriority = enum(C.SDL_ThreadPriority) {
    LOW = C.SDL_THREAD_PRIORITY_LOW,
    NORMAL = C.SDL_THREAD_PRIORITY_NORMAL,
    HIGH = C.SDL_THREAD_PRIORITY_HIGH,
    TIME_CRITICAL = C.SDL_THREAD_PRIORITY_TIME_CRITICAL,

    pub const to_c = c_enum_conversions(ThreadPriority, C.SDL_ThreadPriority).to_c;
    pub const from_c = c_enum_conversions(ThreadPriority, C.SDL_ThreadPriority).from_c;
};

pub const ThreadState = enum(C.SDL_ThreadState) {
    UNKNOWN = C.SDL_THREAD_UNKNOWN,
    ALIVE = C.SDL_THREAD_ALIVE,
    DETACHED = C.SDL_THREAD_DETACHED,
    COMPLETE = C.SDL_THREAD_COMPLETE,

    pub const to_c = c_enum_conversions(ThreadState, C.SDL_ThreadState).to_c;
    pub const from_c = c_enum_conversions(ThreadState, C.SDL_ThreadState).from_c;
};

pub const ThreadFunc = fn (userdata: ?*anyopaque) callconv(.c) c_int;

pub const RWLock = opaque {
    pub const to_c_ptr = c_opaque_conversions(RWLock, C.SDL_RWLock).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(RWLock, C.SDL_RWLock).from_c_ptr;
    //TODO
    // pub extern fn SDL_CreateRWLock() ?*SDL_RWLock;
    // pub extern fn SDL_LockRWLockForReading(rwlock: ?*SDL_RWLock) void;
    // pub extern fn SDL_LockRWLockForWriting(rwlock: ?*SDL_RWLock) void;
    // pub extern fn SDL_TryLockRWLockForReading(rwlock: ?*SDL_RWLock) bool;
    // pub extern fn SDL_TryLockRWLockForWriting(rwlock: ?*SDL_RWLock) bool;
    // pub extern fn SDL_UnlockRWLock(rwlock: ?*SDL_RWLock) void;
    // pub extern fn SDL_DestroyRWLock(rwlock: ?*SDL_RWLock) void;
};

pub const Semaphore = opaque {
    pub const to_c_ptr = c_opaque_conversions(Semaphore, C.SDL_Semaphore).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Semaphore, C.SDL_Semaphore).from_c_ptr;
    //TODO
    // pub extern fn SDL_CreateSemaphore(initial_value: Uint32) ?*SDL_Semaphore;
    // pub extern fn SDL_DestroySemaphore(sem: ?*SDL_Semaphore) void;
    // pub extern fn SDL_WaitSemaphore(sem: ?*SDL_Semaphore) void;
    // pub extern fn SDL_TryWaitSemaphore(sem: ?*SDL_Semaphore) bool;
    // pub extern fn SDL_WaitSemaphoreTimeout(sem: ?*SDL_Semaphore, timeoutMS: Sint32) bool;
    // pub extern fn SDL_SignalSemaphore(sem: ?*SDL_Semaphore) void;
    // pub extern fn SDL_GetSemaphoreValue(sem: ?*SDL_Semaphore) Uint32;
};

pub const Condition = opaque {
    pub const to_c_ptr = c_opaque_conversions(Condition, C.SDL_Condition).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Condition, C.SDL_Condition).from_c_ptr;
    //TODO
    // pub extern fn SDL_CreateCondition() ?*SDL_Condition;
    // pub extern fn SDL_DestroyCondition(cond: ?*SDL_Condition) void;
    // pub extern fn SDL_SignalCondition(cond: ?*SDL_Condition) void;
    // pub extern fn SDL_BroadcastCondition(cond: ?*SDL_Condition) void;
    // pub extern fn SDL_WaitCondition(cond: ?*SDL_Condition, mutex: ?*SDL_Mutex) void;
    // pub extern fn SDL_WaitConditionTimeout(cond: ?*SDL_Condition, mutex: ?*SDL_Mutex, timeoutMS: Sint32) bool;
};

pub const AudioFormat = enum(C.SDL_AudioFormat) {
    UNKNOWN = C.SDL_AUDIO_UNKNOWN,
    U8 = C.SDL_AUDIO_U8,
    I8 = C.SDL_AUDIO_S8,
    I16_LE = C.SDL_AUDIO_S16LE,
    I16_BE = C.SDL_AUDIO_S16BE,
    I32_LE = C.SDL_AUDIO_S32LE,
    I32_BE = C.SDL_AUDIO_S32BE,
    F32_BE = C.SDL_AUDIO_F32LE,
    F32_LE = C.SDL_AUDIO_F32BE,

    pub const to_c = c_enum_conversions(AudioFormat, C.SDL_AudioFormat).to_c;
    pub const from_c = c_enum_conversions(AudioFormat, C.SDL_AudioFormat).from_c;

    pub fn bit_size(self: AudioFormat) c_uint {
        return @intCast(C.SDL_AUDIO_BITSIZE(self.to_c()));
    }

    pub fn byte_size(self: AudioFormat) c_uint {
        return @intCast(C.SDL_AUDIO_BYTESIZE(self.to_c()));
    }

    pub fn is_float(self: AudioFormat) bool {
        return C.SDL_AUDIO_ISFLOAT(self.to_c()) > 0;
    }
    pub fn is_integer(self: AudioFormat) bool {
        return C.SDL_AUDIO_ISFLOAT(self.to_c()) == 0;
    }
    pub fn is_big_endian(self: AudioFormat) bool {
        return C.SDL_AUDIO_ISBIGENDIAN(self.to_c()) > 0;
    }
    pub fn is_little_endian(self: AudioFormat) bool {
        return C.SDL_AUDIO_ISBIGENDIAN(self.to_c()) == 0;
    }
    pub fn is_signed(self: AudioFormat) bool {
        return C.SDL_AUDIO_ISSIGNED(self.to_c()) > 0;
    }
    pub fn is_unsigned(self: AudioFormat) bool {
        return C.SDL_AUDIO_ISSIGNED(self.to_c()) == 0;
    }
};

pub const FlipMode = enum(c_uint) {
    NONE = C.SDL_FLIP_NONE,
    HORIZONTAL = C.SDL_FLIP_HORIZONTAL,
    VERTICAL = C.SDL_FLIP_VERTICAL,
    // HORIZ_VERT = C.SDL_FLIP_HORIZONTAL | C.SDL_FLIP_VERTICAL,

    pub const to_c = c_enum_conversions(FlipMode, C.SDL_FlipMode).to_c;
    pub const from_c = c_enum_conversions(FlipMode, C.SDL_FlipMode).from_c;
};

pub const Sensor = opaque {
    pub const to_c_ptr = c_opaque_conversions(Sensor, C.SDL_Sensor).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Sensor, C.SDL_Sensor).from_c_ptr;
    //TODO
    // pub extern fn SDL_GetSensorProperties(sensor: ?*SDL_Sensor) SDL_PropertiesID;
    // pub extern fn SDL_GetSensorName(sensor: ?*SDL_Sensor) [*c]const u8;
    // pub extern fn SDL_GetSensorType(sensor: ?*SDL_Sensor) SDL_SensorType;
    // pub extern fn SDL_GetSensorNonPortableType(sensor: ?*SDL_Sensor) c_int;
    // pub extern fn SDL_GetSensorID(sensor: ?*SDL_Sensor) SDL_SensorID;
    // pub extern fn SDL_GetSensorData(sensor: ?*SDL_Sensor, data: [*c]f32, num_values: c_int) bool;
    // pub extern fn SDL_CloseSensor(sensor: ?*SDL_Sensor) void;
    // pub extern fn SDL_UpdateSensors() void;

    pub const AccelerometerNeutralGravity = C.SDL_STANDARD_GRAVITY;
};

pub const HapticID = extern struct {
    id: u32,
    //TODO
    // pub extern fn SDL_GetHaptics(count: [*c]c_int) [*c]SDL_HapticID;
    // pub extern fn SDL_GetHapticNameForID(instance_id: SDL_HapticID) [*c]const u8;
    // pub extern fn SDL_OpenHaptic(instance_id: SDL_HapticID) ?*SDL_Haptic;
    // pub extern fn SDL_GetHapticFromID(instance_id: SDL_HapticID) ?*SDL_Haptic;
};

pub const Haptic = opaque {
    pub const to_c_ptr = c_opaque_conversions(Haptic, C.SDL_Haptic).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Haptic, C.SDL_Haptic).from_c_ptr;
    //TODO
    // pub extern fn SDL_GetHapticID(haptic: ?*SDL_Haptic) SDL_HapticID;
    // pub extern fn SDL_GetHapticName(haptic: ?*SDL_Haptic) [*c]const u8;
    // pub extern fn SDL_IsMouseHaptic() bool;
    // pub extern fn SDL_OpenHapticFromMouse() ?*SDL_Haptic;
    // pub extern fn SDL_CloseHaptic(haptic: ?*SDL_Haptic) void;
    // pub extern fn SDL_GetMaxHapticEffects(haptic: ?*SDL_Haptic) c_int;
    // pub extern fn SDL_GetMaxHapticEffectsPlaying(haptic: ?*SDL_Haptic) c_int;
    // pub extern fn SDL_GetHapticFeatures(haptic: ?*SDL_Haptic) Uint32;
    // pub extern fn SDL_GetNumHapticAxes(haptic: ?*SDL_Haptic) c_int;
    // pub extern fn SDL_HapticEffectSupported(haptic: ?*SDL_Haptic, effect: [*c]const SDL_HapticEffect) bool;
    // pub extern fn SDL_CreateHapticEffect(haptic: ?*SDL_Haptic, effect: [*c]const SDL_HapticEffect) c_int;
    // pub extern fn SDL_UpdateHapticEffect(haptic: ?*SDL_Haptic, effect: c_int, data: [*c]const SDL_HapticEffect) bool;
    // pub extern fn SDL_RunHapticEffect(haptic: ?*SDL_Haptic, effect: c_int, iterations: Uint32) bool;
    // pub extern fn SDL_StopHapticEffect(haptic: ?*SDL_Haptic, effect: c_int) bool;
    // pub extern fn SDL_DestroyHapticEffect(haptic: ?*SDL_Haptic, effect: c_int) void;
    // pub extern fn SDL_GetHapticEffectStatus(haptic: ?*SDL_Haptic, effect: c_int) bool;
    // pub extern fn SDL_SetHapticGain(haptic: ?*SDL_Haptic, gain: c_int) bool;
    // pub extern fn SDL_SetHapticAutocenter(haptic: ?*SDL_Haptic, autocenter: c_int) bool;
    // pub extern fn SDL_PauseHaptic(haptic: ?*SDL_Haptic) bool;
    // pub extern fn SDL_ResumeHaptic(haptic: ?*SDL_Haptic) bool;
    // pub extern fn SDL_StopHapticEffects(haptic: ?*SDL_Haptic) bool;
    // pub extern fn SDL_HapticRumbleSupported(haptic: ?*SDL_Haptic) bool;
    // pub extern fn SDL_InitHapticRumble(haptic: ?*SDL_Haptic) bool;
    // pub extern fn SDL_PlayHapticRumble(haptic: ?*SDL_Haptic, strength: f32, length: Uint32) bool;
    // pub extern fn SDL_StopHapticRumble(haptic: ?*SDL_Haptic) bool;
};

pub const HapticDirection = extern struct {
    type: HapticDirectionType = .POLAR,
    dir: [3]i32 = @splat(0),

    pub const to_c_ptr = c_non_opaque_conversions(HapticDirection, C.SDL_HapticDirection).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(HapticDirection, C.SDL_HapticDirection).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(HapticDirection, C.SDL_HapticDirection).to_c;
    pub const from_c = c_non_opaque_conversions(HapticDirection, C.SDL_HapticDirection).from_c;
};

pub const HapticConstant = extern struct {
    type: HapticType = .blank(),
    direction: HapticDirection = .{},
    duration_ms: u32 = 0,
    delay_ms: u16 = 0,
    trigger_button: u16 = 0,
    trigger_button_cooldown_ms: u16 = 0,
    level: i16 = 0,
    start_to_max_ratio_ms: u16 = 0,
    start_ratio: u16 = 32767,
    max_to_end_ratio_ms: u16 = 0,
    end_ratio: u16 = 32767,

    pub const to_c_ptr = c_non_opaque_conversions(HapticConstant, C.SDL_HapticConstant).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(HapticConstant, C.SDL_HapticConstant).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(HapticConstant, C.SDL_HapticConstant).to_c;
    pub const from_c = c_non_opaque_conversions(HapticConstant, C.SDL_HapticConstant).from_c;
};

pub const HapticPeriodic = extern struct {
    type: HapticType = .blank(),
    direction: HapticDirection = .{},
    duration_ms: u32 = 0,
    delay_ms: u16 = 0,
    trigger_button: u16 = 0,
    trigger_button_cooldown_ms: u16 = 0,
    period_ms: u16 = 0,
    magnitude: i16 = 0,
    magnitude_offset: i16 = 0,
    phase_shift: u16 = 0,
    start_to_max_ratio_ms: u16 = 0,
    start_ratio: u16 = 32767,
    max_to_end_ratio_ms: u16 = 0,
    end_ratio: u16 = 32767,

    pub const to_c_ptr = c_non_opaque_conversions(HapticPeriodic, C.SDL_HapticPeriodic).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(HapticPeriodic, C.SDL_HapticPeriodic).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(HapticPeriodic, C.SDL_HapticPeriodic).to_c;
    pub const from_c = c_non_opaque_conversions(HapticPeriodic, C.SDL_HapticPeriodic).from_c;
};

pub const HapticCondition = extern struct {
    type: HapticType = .blank(),
    direction: HapticDirection = .{},
    duration_ms: u32 = 0,
    delay_ms: u16 = 0,
    trigger_button: u16 = 0,
    trigger_button_cooldown_ms: u16 = 0,
    right_sat: [3]u16 = @splat(0),
    left_sat: [3]u16 = @splat(0),
    right_coeff: [3]i16 = @splat(0),
    left_coeff: [3]i16 = @splat(0),
    deadband: [3]u16 = @splat(0),
    center: [3]i16 = @splat(0),

    pub const to_c_ptr = c_non_opaque_conversions(HapticCondition, C.SDL_HapticCondition).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(HapticCondition, C.SDL_HapticCondition).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(HapticCondition, C.SDL_HapticCondition).to_c;
    pub const from_c = c_non_opaque_conversions(HapticCondition, C.SDL_HapticCondition).from_c;
};

pub const HapticRamp = extern struct {
    type: HapticType = .blank(),
    direction: HapticDirection = .{},
    duration_ms: u32 = 0,
    delay_ms: u16 = 0,
    trigger_button: u16 = 0,
    trigger_button_cooldown_ms: u16 = 0,
    start_level: i16 = 0,
    end_level: i16 = 0,
    start_to_max_ratio_ms: u16 = 0,
    start_ratio: u16 = 32767,
    max_to_end_ratio_ms: u16 = 0,
    end_ratio: u16 = 32767,

    pub const to_c_ptr = c_non_opaque_conversions(HapticRamp, C.SDL_HapticRamp).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(HapticRamp, C.SDL_HapticRamp).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(HapticRamp, C.SDL_HapticRamp).to_c;
    pub const from_c = c_non_opaque_conversions(HapticRamp, C.SDL_HapticRamp).from_c;
};

pub const HapticDualMotor = extern struct {
    type: HapticType = .blank(),
    duration_ms: u32 = 0,
    large_magnitude: u16 = 0,
    small_magnitude: u16 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(HapticDualMotor, C.SDL_HapticLeftRight).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(HapticDualMotor, C.SDL_HapticLeftRight).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(HapticDualMotor, C.SDL_HapticLeftRight).to_c;
    pub const from_c = c_non_opaque_conversions(HapticDualMotor, C.SDL_HapticLeftRight).from_c;
};

pub const HapticCustom = extern struct {
    type: HapticType = .blank(),
    direction: HapticDirection = .{},
    duration_ms: u32 = 0,
    delay_ms: u16 = 0,
    trigger_button: u16 = 0,
    trigger_button_cooldown_ms: u16 = 0,
    channels: u8 = 0,
    period: u16 = 0,
    samples: u16 = 0,
    data: ?[*]u16 = null,
    start_to_max_ratio_ms: u16 = 0,
    start_ratio: u16 = 32767,
    max_to_end_ratio_ms: u16 = 0,
    end_ratio: u16 = 32767,

    pub const to_c_ptr = c_non_opaque_conversions(HapticDualMotor, C.SDL_HapticCustom).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(HapticDualMotor, C.SDL_HapticCustom).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(HapticDualMotor, C.SDL_HapticCustom).to_c;
    pub const from_c = c_non_opaque_conversions(HapticDualMotor, C.SDL_HapticCustom).from_c;
};

pub const HapticEffect = extern union {
    type: HapticType,
    constant: HapticConstant,
    periodic: HapticPeriodic,
    condition: HapticCondition,
    ramp: HapticRamp,
    dual_motor: HapticDualMotor,
    custom: HapticCustom,

    pub const to_c_ptr = c_non_opaque_conversions(HapticEffect, C.SDL_HapticEffect).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(HapticEffect, C.SDL_HapticEffect).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(HapticEffect, C.SDL_HapticEffect).to_c;
    pub const from_c = c_non_opaque_conversions(HapticEffect, C.SDL_HapticEffect).from_c;

    pub const INFINITE_DURATION: u32 = C.SDL_HAPTIC_INFINITY;
};

pub const HapticType = Flags(
    enum(u16) {
        CONSTANT = C.SDL_HAPTIC_CONSTANT,
        SINE = C.SDL_HAPTIC_SINE,
        SQUARE = C.SDL_HAPTIC_SQUARE,
        TRIANGLE = C.SDL_HAPTIC_TRIANGLE,
        SAWTOOTHUP = C.SDL_HAPTIC_SAWTOOTHUP,
        SAWTOOTHDOWN = C.SDL_HAPTIC_SAWTOOTHDOWN,
        RAMP = C.SDL_HAPTIC_RAMP,
        SPRING = C.SDL_HAPTIC_SPRING,
        DAMPER = C.SDL_HAPTIC_DAMPER,
        INERTIA = C.SDL_HAPTIC_INERTIA,
        FRICTION = C.SDL_HAPTIC_FRICTION,
        DUAL_MOTOR = C.SDL_HAPTIC_LEFTRIGHT,
        CUSTOM = C.SDL_HAPTIC_CUSTOM,
    },
    enum(u16) {
        CONSTANT = C.SDL_HAPTIC_CONSTANT,
        PERIODIC = C.SDL_HAPTIC_SINE | C.SDL_HAPTIC_SINE | C.SDL_HAPTIC_SQUARE | C.SDL_HAPTIC_TRIANGLE | C.SDL_HAPTIC_SAWTOOTHUP | C.SDL_HAPTIC_SAWTOOTHDOWN,
        RAMP = C.SDL_HAPTIC_RAMP,
        CONDITION = C.SDL_HAPTIC_SPRING | C.SDL_HAPTIC_DAMPER | C.SDL_HAPTIC_INERTIA | C.SDL_HAPTIC_FRICTION,
        DUAL_MOTOR = C.SDL_HAPTIC_LEFTRIGHT,
        CUSTOM = C.SDL_HAPTIC_CUSTOM,
    },
);

pub const HapticFeatures = Flags(enum(c_uint) {
    CONSTANT = C.SDL_HAPTIC_CONSTANT,
    SINE = C.SDL_HAPTIC_SINE,
    SQUARE = C.SDL_HAPTIC_SQUARE,
    TRIANGLE = C.SDL_HAPTIC_TRIANGLE,
    SAWTOOTHUP = C.SDL_HAPTIC_SAWTOOTHUP,
    SAWTOOTHDOWN = C.SDL_HAPTIC_SAWTOOTHDOWN,
    RAMP = C.SDL_HAPTIC_RAMP,
    SPRING = C.SDL_HAPTIC_SPRING,
    DAMPER = C.SDL_HAPTIC_DAMPER,
    INERTIA = C.SDL_HAPTIC_INERTIA,
    FRICTION = C.SDL_HAPTIC_FRICTION,
    DUAL_MOTOR = C.SDL_HAPTIC_LEFTRIGHT,
    CUSTOM = C.SDL_HAPTIC_CUSTOM,
    GAIN = C.SDL_HAPTIC_GAIN,
    AUTOCENTER = C.SDL_HAPTIC_AUTOCENTER,
    STATUS = C.SDL_HAPTIC_STATUS,
    PAUSE = C.SDL_HAPTIC_PAUSE,
}, null);

pub const HapticDirectionType = enum(u8) {
    POLAR = C.SDL_HAPTIC_POLAR,
    CARTESIAN = C.SDL_HAPTIC_CARTESIAN,
    SPHERICAL = C.SDL_HAPTIC_SPHERICAL,
    STEERING_AXIS = C.SDL_HAPTIC_STEERING_AXIS,

    pub const to_c = c_enum_conversions(HapticDirectionType, u8).to_c;
    pub const from_c = c_enum_conversions(HapticDirectionType, u8).from_c;
};

pub const OpenGL = struct {
    //TODO
    // pub extern fn SDL_GL_LoadLibrary(path: [*c]const u8) bool;
    // pub extern fn SDL_GL_GetProcAddress(proc: [*c]const u8) SDL_FunctionPointer;
    // pub extern fn SDL_EGL_GetProcAddress(proc: [*c]const u8) SDL_FunctionPointer;
    // pub extern fn SDL_GL_UnloadLibrary() void;
    // pub extern fn SDL_GL_ExtensionSupported(extension: [*c]const u8) bool;
    // pub extern fn SDL_GL_ResetAttributes() void;
    // pub extern fn SDL_EGL_SetAttributeCallbacks(platformAttribCallback: SDL_EGLAttribArrayCallback, surfaceAttribCallback: SDL_EGLIntArrayCallback, contextAttribCallback: SDL_EGLIntArrayCallback, userdata: ?*anyopaque) void;
    // pub extern fn SDL_GL_SetSwapInterval(interval: c_int) bool;
    // pub extern fn SDL_GL_GetSwapInterval(interval: [*c]c_int) bool;
};

pub const GL_Context = opaque {
    pub const to_c_ptr = c_opaque_conversions(GL_Context, C.struct_SDL_GLContextState).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GL_Context, C.struct_SDL_GLContextState).from_c_ptr;
    //TODO
    // pub extern fn SDL_GL_GetCurrentContext() SDL_GLContext;
    // pub extern fn SDL_GL_DestroyContext(context: SDL_GLContext) bool;
};

pub const GL_Attr = enum(C.SDL_GLAttr) {
    RED_SIZE = C.SDL_GL_RED_SIZE,
    GREEN_SIZE = C.SDL_GL_GREEN_SIZE,
    BLUE_SIZE = C.SDL_GL_BLUE_SIZE,
    ALPHA_SIZE = C.SDL_GL_ALPHA_SIZE,
    BUFFER_SIZE = C.SDL_GL_BUFFER_SIZE,
    DOUBLEBUFFER = C.SDL_GL_DOUBLEBUFFER,
    DEPTH_SIZE = C.SDL_GL_DEPTH_SIZE,
    STENCIL_SIZE = C.SDL_GL_STENCIL_SIZE,
    ACCUM_RED_SIZE = C.SDL_GL_ACCUM_RED_SIZE,
    ACCUM_GREEN_SIZE = C.SDL_GL_ACCUM_GREEN_SIZE,
    ACCUM_BLUE_SIZE = C.SDL_GL_ACCUM_BLUE_SIZE,
    ACCUM_ALPHA_SIZE = C.SDL_GL_ACCUM_ALPHA_SIZE,
    STEREO = C.SDL_GL_STEREO,
    MULTISAMPLE_BUFFERS = C.SDL_GL_MULTISAMPLEBUFFERS,
    MULTISAMPLE_SAMPLES = C.SDL_GL_MULTISAMPLESAMPLES,
    ACCELERATED_VISUAL = C.SDL_GL_ACCELERATED_VISUAL,
    RETAINED_BACKING = C.SDL_GL_RETAINED_BACKING,
    CONTEXT_MAJOR_VERSION = C.SDL_GL_CONTEXT_MAJOR_VERSION,
    CONTEXT_MINOR_VERSION = C.SDL_GL_CONTEXT_MINOR_VERSION,
    CONTEXT_FLAGS = C.SDL_GL_CONTEXT_FLAGS,
    CONTEXT_PROFILE_FLAGS = C.SDL_GL_CONTEXT_PROFILE_MASK,
    SHARE_WITH_CURRENT_CONTEXT = C.SDL_GL_SHARE_WITH_CURRENT_CONTEXT,
    FRAMEBUFFER_SRGB_CAPABLE = C.SDL_GL_FRAMEBUFFER_SRGB_CAPABLE,
    CONTEXT_RELEASE_BEHAVIOR = C.SDL_GL_CONTEXT_RELEASE_BEHAVIOR,
    CONTEXT_RESET_NOTIFICATION = C.SDL_GL_CONTEXT_RESET_NOTIFICATION,
    CONTEXT_NO_ERROR = C.SDL_GL_CONTEXT_NO_ERROR,
    FLOAT_BUFFERS = C.SDL_GL_FLOATBUFFERS,
    EGL_PLATFORM = C.SDL_GL_EGL_PLATFORM,

    pub const to_c = c_enum_conversions(GL_Attr, C.SDL_GLAttr).to_c;
    pub const from_c = c_enum_conversions(GL_Attr, C.SDL_GLAttr).from_c;
    //TODO
    // pub extern fn SDL_GL_SetAttribute(attr: SDL_GLAttr, value: c_int) bool;
    // pub extern fn SDL_GL_GetAttribute(attr: SDL_GLAttr, value: [*c]c_int) bool;
};

pub const GL_AttrProfileFlags = Flags(enum(c_uint) {
    CORE = C.SDL_GL_CONTEXT_PROFILE_CORE,
    COMPATIBILITY = C.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY,
    ES = C.SDL_GL_CONTEXT_PROFILE_ES,
}, null);

pub const GL_AttrContextFlags = Flags(enum(c_uint) {
    DEBUG = C.SDL_GL_CONTEXT_DEBUG_FLAG,
    FORWARD_COMPATIBLE = C.SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG,
    ROBUST_ACCESS = C.SDL_GL_CONTEXT_ROBUST_ACCESS_FLAG,
    RESET_ISOLATION = C.SDL_GL_CONTEXT_RESET_ISOLATION_FLAG,
}, null);

pub const GL_AttrReleaseFlags = Flags(enum(c_uint) {
    NONE = C.SDL_GL_CONTEXT_RELEASE_BEHAVIOR_NONE,
    FLUSH = C.SDL_GL_CONTEXT_RELEASE_BEHAVIOR_FLUSH,
}, null);

pub const GL_AttrResetFlags = Flags(enum(c_uint) {
    NO_NOTIFICATION = C.SDL_GL_CONTEXT_RESET_NO_NOTIFICATION,
    LOSE_CONTEXT = C.SDL_GL_CONTEXT_RESET_LOSE_CONTEXT,
}, null);

pub const GL_Profile = struct {
    raw: C.SDL_GLProfile,
};

pub const GL_ContextFlag = struct {
    raw: C.SDL_GLContextFlag,
};

pub const GL_ContextReleaseFlag = struct {
    raw: C.SDL_GLContextReleaseFlag,
};

pub const GL_ContextResetNotification = struct {
    raw: C.SDL_GLContextResetNotification,
};

pub const EGL_Display = opaque {
    //TODO
    // pub extern fn SDL_EGL_GetCurrentDisplay() SDL_EGLDisplay;
};
pub const EGL_Config = opaque {
    //TODO
    // pub extern fn SDL_EGL_GetCurrentConfig() SDL_EGLConfig;
};
pub const EGL_Surface = opaque {};
pub const EGL_Attr = struct {
    raw: C.SDL_EGLAttrib,
};
pub const EGL_Int = struct {
    raw: C.SDL_EGLint,
};
//TODO
// pub const SDL_EGLAttribArrayCallback = ?*const fn (?*anyopaque) callconv(.c) [*c]SDL_EGLAttrib;
// pub const SDL_EGLIntArrayCallback = ?*const fn (?*anyopaque, SDL_EGLDisplay, SDL_EGLConfig) callconv(.c) [*c]SDL_EGLint;

//TODO
// pub extern fn SDL_GL_LoadLibrary(path: [*c]const u8) bool;
// pub extern fn SDL_GL_GetProcAddress(proc: [*c]const u8) SDL_FunctionPointer;
// pub extern fn SDL_EGL_GetProcAddress(proc: [*c]const u8) SDL_FunctionPointer;
// pub extern fn SDL_GL_UnloadLibrary() void;
// pub extern fn SDL_GL_ExtensionSupported(extension: [*c]const u8) bool;
// pub extern fn SDL_GL_ResetAttributes() void;
// pub extern fn SDL_GL_SetAttribute(attr: SDL_GLAttr, value: c_int) bool;
// pub extern fn SDL_GL_GetAttribute(attr: SDL_GLAttr, value: [*c]c_int) bool;
// pub extern fn SDL_GL_CreateContext(window: ?*SDL_Window) SDL_GLContext;
// pub extern fn SDL_GL_MakeCurrent(window: ?*SDL_Window, context: SDL_GLContext) bool;
// pub extern fn SDL_GL_GetCurrentWindow() ?*SDL_Window;
// pub extern fn SDL_GL_GetCurrentContext() SDL_GLContext;
// pub extern fn SDL_EGL_GetCurrentDisplay() SDL_EGLDisplay;
// pub extern fn SDL_EGL_GetCurrentConfig() SDL_EGLConfig;
// pub extern fn SDL_EGL_GetWindowSurface(window: ?*SDL_Window) SDL_EGLSurface;
// pub extern fn SDL_EGL_SetAttributeCallbacks(platformAttribCallback: SDL_EGLAttribArrayCallback, surfaceAttribCallback: SDL_EGLIntArrayCallback, contextAttribCallback: SDL_EGLIntArrayCallback, userdata: ?*anyopaque) void;
// pub extern fn SDL_GL_SetSwapInterval(interval: c_int) bool;
// pub extern fn SDL_GL_GetSwapInterval(interval: [*c]c_int) bool;
// pub extern fn SDL_GL_SwapWindow(window: ?*SDL_Window) bool;
// pub extern fn SDL_GL_DestroyContext(context: SDL_GLContext) bool;

pub const Renderer = opaque {
    pub const to_c_ptr = c_opaque_conversions(Renderer, C.SDL_Renderer).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Renderer, C.SDL_Renderer).from_c_ptr;

    pub fn get_driver_count() c_int {
        return C.SDL_GetNumRenderDrivers();
    }
    pub fn get_driver_name(index: c_int) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetRenderDriver(index));
    }
    pub fn create_renderer_with_properties(props_id: PropertiesID) Error!*Renderer {
        return ptr_cast_or_fail_err(*Renderer, C.SDL_CreateRendererWithProperties(props_id));
    }
    pub fn create_software_renderer(surface: *Surface) Error!*Renderer {
        return ptr_cast_or_fail_err(*Renderer, C.SDL_CreateSoftwareRenderer(@ptrCast(@alignCast(surface))));
    }
    pub fn get_window(self: *Renderer) Error!*Window {
        return ptr_cast_or_null_err(*Window, C.SDL_GetRenderWindow(self.to_c_ptr()));
    }
    pub fn get_name(self: *Renderer) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetRenderWindow(self.to_c_ptr()));
    }
    pub fn get_properties_id(self: *Renderer) Error!PropertiesID {
        return PropertiesID{ .id = try nonzero_or_null_err(C.SDL_GetRendererProperties(self.to_c_ptr())) };
    }
    pub fn get_true_output_size(self: *Renderer) Error!Vec_c_int {
        var size = Vec_c_int{};
        try ok_or_null_err(C.SDL_GetRenderOutputSize(self.to_c_ptr(), &size.x, &size.y));
        return size;
    }
    pub fn get_adjusted_output_size(self: *Renderer) Error!Vec_c_int {
        var size = Vec_c_int{};
        try ok_or_null_err(C.SDL_GetCurrentRenderOutputSize(self.to_c_ptr(), &size.x, &size.y));
        return size;
    }
    pub fn create_texture(self: *Renderer, format: PixelFormat, access_mode: TextureAccessMode, size: Vec_c_int) Error!*SimpleTexture {
        return ptr_cast_or_fail_err(*SimpleTexture, C.SDL_CreateTexture(self.to_c_ptr(), format.to_c(), access_mode.to_c(), size.x, size.y));
    }
    pub fn create_texture_from_surface(self: *Renderer, surface: *Surface) Error!*SimpleTexture {
        return ptr_cast_or_fail_err(*SimpleTexture, C.SDL_CreateTextureFromSurface(self.to_c_ptr(), @ptrCast(@alignCast(surface))));
    }
    pub fn create_texture_with_properties(self: *Renderer, props_id: PropertiesID) Error!*SimpleTexture {
        return ptr_cast_or_fail_err(*SimpleTexture, C.SDL_CreateTextureWithProperties(self.to_c_ptr(), props_id.id));
    }
    pub fn set_texture_target(self: *Renderer, texture: *SimpleTexture) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderTarget(self.to_c_ptr(), texture.to_c_ptr()));
    }
    pub fn clear_texture_target(self: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderTarget(self.to_c_ptr(), null));
    }
    pub fn get_texture_target(self: *Renderer) Error!*SimpleTexture {
        return ptr_cast_or_null_err(*SimpleTexture, C.SDL_GetRenderTarget(self.to_c_ptr()));
    }
    pub fn set_logical_presentation(self: *Renderer, presentation: LogicalPresentation) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderLogicalPresentation(self.to_c_ptr(), &presentation.size.x, &presentation.size.y, presentation.mode.to_c()));
    }
    pub fn get_logical_presentation(self: *Renderer) Error!LogicalPresentation {
        var pres = LogicalPresentation{};
        try ok_or_null_err(C.SDL_GetRenderLogicalPresentation(self.to_c_ptr(), &pres.size.x, &pres.size.y, @ptrCast(@alignCast(&pres.mode))));
        return pres;
    }
    pub fn get_logical_presentation_rect(self: *Renderer) Error!Rect_f32 {
        var rect = Rect_f32{};
        try ok_or_null_err(C.SDL_GetRenderLogicalPresentationRect(self.to_c_ptr(), @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn render_coords_from_window(self: *Renderer, window_pos: Vec_f32) Error!Vec_f32 {
        var vec = Vec_f32{};
        try ok_or_fail_err(C.SDL_RenderCoordinatesFromWindow(self.to_c_ptr(), window_pos.x, window_pos.y, &vec.x, &vec.y));
        return vec;
    }
    pub fn render_coords_to_window(self: *Renderer, render_pos: Vec_f32) Error!Vec_f32 {
        var vec = Vec_f32{};
        try ok_or_fail_err(C.SDL_RenderCoordinatesToWindow(self.to_c_ptr(), render_pos.x, render_pos.y, &vec.x, &vec.y));
        return vec;
    }
    pub fn set_viewport(self: *Renderer, rect: Rect_c_int) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderViewport(self.to_c_ptr(), @ptrCast(@alignCast(&rect))));
    }
    pub fn clear_viewport(self: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderViewport(self.to_c_ptr(), null));
    }
    pub fn get_viewport(self: *Renderer) Error!Rect_c_int {
        var rect = Rect_c_int{};
        try ok_or_null_err(C.SDL_GetRenderViewport(self.to_c_ptr(), @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn viewport_is_set(self: *Renderer) bool {
        return C.SDL_RenderViewportSet(self.to_c_ptr());
    }
    pub fn get_safe_area(self: *Renderer) Error!Rect_c_int {
        var rect = Rect_c_int{};
        try ok_or_null_err(C.SDL_GetRenderSafeArea(self.to_c_ptr(), @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn set_clip_rect(self: *Renderer, rect: Rect_c_int) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderClipRect(self.to_c_ptr(), @ptrCast(@alignCast(&rect))));
    }
    pub fn clear_clip_rect(self: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderClipRect(self.to_c_ptr(), null));
    }
    pub fn get_clip_rect(self: *Renderer) Error!Rect_c_int {
        var rect = Rect_c_int{};
        try ok_or_null_err(C.SDL_GetRenderClipRect(self.to_c_ptr(), @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn clip_rect_is_set(self: *Renderer) bool {
        return C.SDL_RenderClipEnabled(self.to_c_ptr());
    }
    pub fn set_render_scale(self: *Renderer, scale: Vec_f32) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderScale(self.to_c_ptr(), scale.x, scale.y));
    }
    pub fn get_render_scale(self: *Renderer) Error!Vec_f32 {
        var vec = Vec_f32{};
        try ok_or_null_err(C.SDL_GetRenderScale(self.to_c_ptr(), &vec.x, &vec.y));
        return vec;
    }
    pub fn set_draw_color(self: *Renderer, color: Color_RGBA_u8) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderDrawColor(self.to_c_ptr(), color.r, color.g, color.b, color.a));
    }
    pub fn set_draw_color_float(self: *Renderer, color: Color_RGBA_f32) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderDrawColorFloat(self.to_c_ptr(), color.r, color.g, color.b, color.a));
    }
    pub fn get_draw_color(self: *Renderer) Error!Color_RGBA_u8 {
        var color = Color_RGBA_u8{};
        try ok_or_null_err(C.SDL_GetRenderDrawColor(self.to_c_ptr(), &color.r, &color.g, &color.b, &color.a));
        return color;
    }
    pub fn get_draw_color_float(self: *Renderer) Error!Color_RGBA_f32 {
        var color = Color_RGBA_f32{};
        try ok_or_null_err(C.SDL_GetRenderDrawColorFloat(self.to_c_ptr(), &color.r, &color.g, &color.b, &color.a));
        return color;
    }
    pub fn set_draw_color_scale(self: *Renderer, scale: f32) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderColorScale(self.to_c_ptr(), scale));
    }
    pub fn get_draw_color_scale(self: *Renderer) Error!f32 {
        var scale: f32 = 0.0;
        try ok_or_null_err(C.SDL_GetRenderColorScale(self.to_c_ptr(), &scale));
        return scale;
    }
    pub fn set_draw_blend_mode(self: *Renderer, mode: BlendMode) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderDrawBlendMode(self.to_c_ptr(), mode.mode));
    }
    pub fn get_draw_blend_mode(self: *Renderer) Error!BlendMode {
        var mode: u32 = 0;
        try ok_or_null_err(C.SDL_GetRenderDrawBlendMode(self.to_c_ptr(), &mode));
        return BlendMode{ .mode = mode };
    }
    pub fn draw_clear_fill(self: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_RenderClear(self.to_c_ptr()));
    }
    pub fn draw_point(self: *Renderer, point: *const Vec_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderPoint(self.to_c_ptr(), point.x, point.y));
    }
    pub fn draw_many_points(self: *Renderer, points: []const Vec_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderPoints(self.to_c_ptr(), @ptrCast(@alignCast(points.ptr)), @intCast(points.len)));
    }
    pub fn draw_line(self: *Renderer, point_a: *const Vec_f32, point_b: *const Vec_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderLine(self.to_c_ptr(), point_a.x, point_a.y, point_b.x, point_b.y));
    }
    pub fn draw_many_lines(self: *Renderer, points: []const Vec_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderLines(self.to_c_ptr(), @ptrCast(@alignCast(points.ptr)), @intCast(points.len)));
    }
    pub fn draw_rect_outline(self: *Renderer, rect: *const Rect_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderRect(self.to_c_ptr(), @ptrCast(@alignCast(rect))));
    }
    pub fn draw_many_rect_outlines(self: *Renderer, rects: []const Rect_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderLines(self.to_c_ptr(), @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len)));
    }
    pub fn draw_rect_filled(self: *Renderer, rect: *const Rect_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderRect(self.to_c_ptr(), @ptrCast(@alignCast(rect))));
    }
    pub fn draw_many_rects_filled(self: *Renderer, rects: []const Rect_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderLines(self.to_c_ptr(), @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len)));
    }
    pub fn draw_texture_rect(self: *Renderer, texture: *SimpleTexture, tex_rect: FArea, target_rect: FArea) Error!void {
        return ok_or_fail_err(C.SDL_RenderTexture(self.to_c_ptr(), texture.to_c_ptr(), @ptrCast(@alignCast(tex_rect.rect_ptr)), @ptrCast(@alignCast(target_rect.rect_ptr))));
    }
    pub fn draw_texture_rect_rotated(self: *Renderer, texture: *SimpleTexture, tex_rect: FArea, target_rect: FArea, angle_deg: f32, pivot: ?*const Vec_f32, flip: FlipMode) Error!void {
        return ok_or_fail_err(C.SDL_RenderTextureRotated(self.to_c_ptr(), texture.to_c_ptr(), @ptrCast(@alignCast(tex_rect)), @ptrCast(@alignCast(target_rect)), angle_deg, pivot, flip));
    }
    pub fn draw_texture_rect_affine(self: *Renderer, texture: *SimpleTexture, tex_rect: FArea, target_top_left: ?*const Vec_f32, target_top_right: ?*const Vec_f32, target_bot_left: ?*const Vec_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderTextureAffine(self.to_c_ptr(), texture.to_c_ptr(), @ptrCast(@alignCast(tex_rect)), @ptrCast(@alignCast(target_top_left)), @ptrCast(@alignCast(target_top_right)), @ptrCast(@alignCast(target_bot_left))));
    }
    pub fn draw_texture_rect_tiled(self: *Renderer, texture: *SimpleTexture, tex_rect: ?*const Rect_f32, tex_scale: f32, target_rect: ?*const Rect_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderTextureTiled(self.to_c_ptr(), texture.to_c_ptr(), @ptrCast(@alignCast(tex_rect)), tex_scale, @ptrCast(@alignCast(target_rect))));
    }
    pub fn draw_texture_rect_nine_patch(self: *Renderer, texture: *SimpleTexture, tex_nine_patch: NinePatch_F32, edge_scale: f32, target_rect: ?*const Rect_f32) Error!void {
        return ok_or_fail_err(C.SDL_RenderTexture9Grid(self.to_c_ptr(), texture.to_c_ptr(), @ptrCast(@alignCast(tex_nine_patch.rect)), tex_nine_patch.left, tex_nine_patch.right, tex_nine_patch.top, tex_nine_patch.bottom, edge_scale, @ptrCast(@alignCast(target_rect))));
    }
    pub fn draw_vertices_as_triangles(self: *Renderer, texture: ?*SimpleTexture, vertices: []const SimpleVertex) Error!void {
        return ok_or_fail_err(C.SDL_RenderGeometry(self.to_c_ptr(), @ptrCast(@alignCast(texture)), @ptrCast(@alignCast(vertices.ptr)), @intCast(vertices.len), null, 0));
    }
    pub fn draw_indexed_vertices_as_triangles(self: *Renderer, texture: ?*SimpleTexture, vertices: []const SimpleVertex, indices: []const c_int) Error!void {
        return ok_or_fail_err(C.SDL_RenderGeometry(self.to_c_ptr(), @ptrCast(@alignCast(texture)), @ptrCast(@alignCast(vertices.ptr)), @intCast(vertices.len), @ptrCast(@alignCast(indices.ptr)), @intCast(indices.len)));
    }
    pub fn draw_vertices_as_triangles_raw(self: *Renderer, texture: ?*SimpleTexture, pos_start: [*]const Vec_f32, pos_stride: c_int, color_start: [*]const Color_RGBA_f32, color_stride: c_int, tex_coord_start: [*]const Vec_f32, tex_coord_stride: c_int, vertex_count: c_int) Error!void {
        return ok_or_fail_err(C.SDL_RenderGeometryRaw(self.to_c_ptr(), @ptrCast(@alignCast(texture)), @ptrCast(@alignCast(pos_start.ptr)), pos_stride, @ptrCast(@alignCast(color_start.ptr)), color_stride, @ptrCast(@alignCast(tex_coord_start.ptr)), tex_coord_stride, vertex_count, null, 0, IndexType.U8.to_c()));
    }
    pub fn draw_indexed_vertices_as_triangles_raw(self: *Renderer, texture: ?*SimpleTexture, pos_start: [*]const Vec_f32, pos_stride: c_int, color_start: [*]const Color_RGBA_f32, color_stride: c_int, tex_coord_start: [*]const Vec_f32, tex_coord_stride: c_int, vertex_count: c_int, index_start: *anyopaque, index_count: c_int, index_type: IndexType) Error!void {
        return ok_or_fail_err(C.SDL_RenderGeometryRaw(self.to_c_ptr(), @ptrCast(@alignCast(texture)), @ptrCast(@alignCast(pos_start.ptr)), pos_stride, @ptrCast(@alignCast(color_start.ptr)), color_stride, @ptrCast(@alignCast(tex_coord_start.ptr)), tex_coord_stride, vertex_count, @ptrCast(@alignCast(index_start)), index_count, index_type.to_c()));
    }
    pub fn draw_debug_text(self: *Renderer, pos: Vec_f32, text: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_RenderDebugText(self.to_c_ptr(), pos.x, pos.y, @ptrCast(@alignCast(text))));
    }
    pub fn draw_debug_text_formatted(self: *Renderer, pos: Vec_f32, format: [*:0]const u8, args: anytype) Error!void {
        return ok_or_fail_err(@call(.auto, C.SDL_RenderDebugText, .{ self.to_c_ptr(), pos.x, pos.y, @as([*c]const u8, @ptrCast(@alignCast(format))) } ++ args));
    }
    pub fn read_pixels_rect(self: *Renderer, rect: Rect_c_int) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_RenderReadPixels(self.to_c_ptr(), @ptrCast(@alignCast(&rect))));
    }
    pub fn read_pixels_all(self: *Renderer) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_RenderReadPixels(self.to_c_ptr(), null));
    }
    pub fn present(self: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_RenderPresent(self.to_c_ptr()));
    }
    pub fn destroy(self: *Renderer) void {
        C.SDL_DestroyRenderer(self.to_c_ptr());
    }
    pub fn flush(self: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_FlushRenderer(self.to_c_ptr()));
    }
    pub fn get_metal_layer(self: *Renderer) Error!*MetalLayer {
        return ptr_cast_or_null_err(*MetalLayer, C.SDL_GetRenderMetalLayer(self.to_c_ptr()));
    }
    pub fn get_metal_command_encoder(self: *Renderer) Error!*MetalCommandEncoder {
        return ptr_cast_or_null_err(*MetalCommandEncoder, C.SDL_GetRenderMetalCommandEncoder(self.to_c_ptr()));
    }
    pub fn add_vulkan_semaphores(self: *Renderer, wait_stage_mask: u32, wait_semaphore: i64, signal_semaphore: i64) Error!void {
        return ok_or_fail_err(C.SDL_AddVulkanRenderSemaphores(self.to_c_ptr(), wait_stage_mask, wait_semaphore, signal_semaphore));
    }
    pub fn set_vsync(self: *Renderer, v_sync: VSync) Error!void {
        return ok_or_fail_err(C.SDL_SetRenderVSync(self.to_c_ptr(), v_sync.to_c()));
    }
    pub fn get_vsync(self: *Renderer) Error!VSync {
        var val: c_int = 0;
        try ok_or_null_err(C.SDL_GetRenderVSync(self.to_c_ptr(), &val));
        return VSync.from_c(val);
    }

    pub const SOFTWARE_RENDERER_NAME = C.SDL_SOFTWARE_RENDERER;
    pub const DEBUG_TEXT_FONT_PX_SIZE = C.SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE;

    pub const CreateProps = struct {
        pub const NAME = Property.new(.STRING, C.SDL_PROP_RENDERER_CREATE_NAME_STRING);
        pub const WINDOW = Property.new(.POINTER, C.SDL_PROP_RENDERER_CREATE_WINDOW_POINTER);
        pub const SURFACE = Property.new(.POINTER, C.SDL_PROP_RENDERER_CREATE_SURFACE_POINTER);
        pub const OUTPUT_COLORSPACE = Property.new(.POINTER, C.SDL_PROP_RENDERER_CREATE_SURFACE_POINTER);
        pub const PRESENT_VSYNC = Property.new(.INTEGER, C.SDL_PROP_RENDERER_CREATE_PRESENT_VSYNC_NUMBER);
        pub const VULKAN_INSTANCE = Property.new(.POINTER, C.SDL_PROP_RENDERER_CREATE_VULKAN_INSTANCE_POINTER);
        pub const VULKAN_SURFACE = Property.new(.INTEGER, C.SDL_PROP_RENDERER_CREATE_VULKAN_SURFACE_NUMBER);
        pub const VULKAN_PHYSICAL_DEVICE = Property.new(.POINTER, C.SDL_PROP_RENDERER_CREATE_VULKAN_PHYSICAL_DEVICE_POINTER);
        pub const VULKAN_DEVICE = Property.new(.POINTER, C.SDL_PROP_RENDERER_CREATE_VULKAN_DEVICE_POINTER);
        pub const VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX = Property.new(.INTEGER, C.SDL_PROP_RENDERER_CREATE_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER);
        pub const VULKAN_PRESENT_QUEUE_FAMILY_INDEX = Property.new(.INTEGER, C.SDL_PROP_RENDERER_CREATE_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER);
    };
    pub const Props = struct {
        pub const NAME = Property.new(.STRING, C.SDL_PROP_RENDERER_NAME_STRING);
        pub const WINDOW = Property.new(.POINTER, C.SDL_PROP_RENDERER_WINDOW_POINTER);
        pub const SURFACE = Property.new(.POINTER, C.SDL_PROP_RENDERER_SURFACE_POINTER);
        pub const VSYNC = Property.new(.INTEGER, C.SDL_PROP_RENDERER_VSYNC_NUMBER);
        pub const MAX_TEXTURE_SIZE = Property.new(.INTEGER, C.SDL_PROP_RENDERER_MAX_TEXTURE_SIZE_NUMBER);
        pub const TEXTURE_FORMATS = Property.new(.POINTER, C.SDL_PROP_RENDERER_TEXTURE_FORMATS_POINTER);
        pub const OUTPUT_COLORSPACE = Property.new(.INTEGER, C.SDL_PROP_RENDERER_OUTPUT_COLORSPACE_NUMBER);
        pub const HDR_ENABLED = Property.new(.INTEGER, C.SDL_PROP_RENDERER_HDR_ENABLED_BOOLEAN);
        pub const SDR_WHITE_POINT = Property.new(.FLOAT, C.SDL_PROP_RENDERER_SDR_WHITE_POINT_FLOAT);
        pub const HDR_HEADROOM = Property.new(.FLOAT, C.SDL_PROP_RENDERER_HDR_HEADROOM_FLOAT);
        pub const D3D9_DEVICE = Property.new(.POINTER, C.SDL_PROP_RENDERER_D3D9_DEVICE_POINTER);
        pub const D3D11_DEVICE = Property.new(.POINTER, C.SDL_PROP_RENDERER_D3D11_DEVICE_POINTER);
        pub const D3D11_SWAPCHAIN = Property.new(.POINTER, C.SDL_PROP_RENDERER_D3D11_SWAPCHAIN_POINTER);
        pub const D3D12_DEVICE = Property.new(.POINTER, C.SDL_PROP_RENDERER_D3D12_DEVICE_POINTER);
        pub const D3D12_SWAPCHAIN = Property.new(.POINTER, C.SDL_PROP_RENDERER_D3D12_SWAPCHAIN_POINTER);
        pub const D3D12_COMMAND_QUEUE = Property.new(.POINTER, C.SDL_PROP_RENDERER_D3D12_COMMAND_QUEUE_POINTER);
        pub const VULKAN_INSTANCE = Property.new(.POINTER, C.SDL_PROP_RENDERER_VULKAN_INSTANCE_POINTER);
        pub const VULKAN_SURFACE = Property.new(.INTEGER, C.SDL_PROP_RENDERER_VULKAN_SURFACE_NUMBER);
        pub const VULKAN_PHYSICAL_DEVICE = Property.new(.POINTER, C.SDL_PROP_RENDERER_VULKAN_PHYSICAL_DEVICE_POINTER);
        pub const VULKAN_DEVICE = Property.new(.POINTER, C.SDL_PROP_RENDERER_VULKAN_DEVICE_POINTER);
        pub const VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX = Property.new(.INTEGER, C.SDL_PROP_RENDERER_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER);
        pub const VULKAN_PRESENT_QUEUE_FAMILY_INDEX = Property.new(.INTEGER, C.SDL_PROP_RENDERER_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER);
        pub const VULKAN_SWAPCHAIN_IMAGE_COUNT = Property.new(.INTEGER, C.SDL_PROP_RENDERER_VULKAN_SWAPCHAIN_IMAGE_COUNT_NUMBER);
        pub const GPU_DEVICE = Property.new(.POINTER, C.SDL_PROP_RENDERER_GPU_DEVICE_POINTER);
    };
};

pub const TextureWriteBytes = extern struct {
    bytes: []u8,
    bytes_per_row: c_int,
    texture: ?*SimpleTexture,

    pub fn unlock(self: *TextureWriteBytes) void {
        assert(self.texture != null);
        C.SDL_UnlockTexture(self.texture.?);
        self.bytes = &.{};
        self.bytes_per_row = 0;
        self.texture = null;
    }
};

pub const BlendMode = struct {
    mode: u32 = 0,

    pub const NONE = BlendMode{ .mode = C.SDL_BLENDMODE_NONE };
    pub const BLEND = BlendMode{ .mode = C.SDL_BLENDMODE_BLEND };
    pub const BLEND_PREMULTIPLIED = BlendMode{ .mode = C.SDL_BLENDMODE_BLEND_PREMULTIPLIED };
    pub const ADD = BlendMode{ .mode = C.SDL_BLENDMODE_ADD };
    pub const ADD_PREMULTIPLIED = BlendMode{ .mode = C.SDL_BLENDMODE_ADD_PREMULTIPLIED };
    pub const MOD = BlendMode{ .mode = C.SDL_BLENDMODE_MOD };
    pub const MUL = BlendMode{ .mode = C.SDL_BLENDMODE_MUL };

    pub fn custom(src_color_factor: BlendFactor, dst_color_factor: BlendFactor, color_operation: BlendOperation, src_alpha_factor: BlendFactor, dst_alpha_factor: BlendFactor, alpha_operation: BlendOperation) BlendMode {
        return BlendMode{ .mode = C.SDL_ComposeCustomBlendMode(src_color_factor.to_c(), dst_color_factor.to_c(), color_operation.to_c(), src_alpha_factor.to_c(), dst_alpha_factor.to_c(), alpha_operation.to_c()) };
    }
};

/// Helper Struct for SDL functions that expect a number of various
/// properties pertaining to a rectangle of pixels
pub const PixelRect = extern struct {
    size: Vec_c_int,
    ptr: [*]u8,
    bytes_per_row: c_int,
    pixel_format: PixelFormat,
    colorspace: Colorspace = .UNKNOWN,
    optional_color_properties: PropertiesID = PropertiesID.NULL,

    pub fn rect(size: Vec_c_int, ptr: [*]u8, bytes_per_row: c_uint, format: PixelFormat) PixelRect {
        return PixelRect{
            .size = size,
            .ptr = ptr,
            .bytes_per_row = bytes_per_row,
            .pixel_format = format,
        };
    }
    pub fn rect_with_colorspace(size: Vec_c_int, ptr: [*]u8, bytes_per_row: c_uint, format: PixelFormat, colorspace: Colorspace) PixelRect {
        return PixelRect{
            .size = size,
            .ptr = ptr,
            .bytes_per_row = bytes_per_row,
            .pixel_format = format,
            .colorspace = colorspace,
        };
    }
    pub fn rect_with_colorspace_and_props(size: Vec_c_int, ptr: [*]u8, bytes_per_row: c_uint, format: PixelFormat, colorspace: Colorspace, properties: PropertiesID) PixelRect {
        return PixelRect{
            .size = size,
            .ptr = ptr,
            .bytes_per_row = bytes_per_row,
            .pixel_format = format,
            .colorspace = colorspace,
            .optional_color_properties = properties,
        };
    }

    pub fn convert_pixels(src: PixelRect, dst: PixelRect) Error!void {
        assert(src.size.x == dst.size.x and src.size.y == dst.size.y);
        return ok_or_fail_err(C.SDL_ConvertPixels(src.size.x, src.size.y, src.pixel_format.to_c(), src.ptr, src.bytes_per_row, dst.pixel_format.to_c(), dst.ptr, dst.bytes_per_row));
    }
    pub fn convert_pixels_and_colorspace(src: PixelRect, dst: PixelRect) Error!void {
        assert(src.size.x == dst.size.x and src.size.y == dst.size.y);
        return ok_or_fail_err(C.SDL_ConvertPixelsAndColorspace(src.size.x, src.size.y, src.pixel_format.to_c(), src.colorspace.to_c(), src.optional_color_properties.id, src.ptr, src.bytes_per_row, dst.pixel_format.to_c(), dst.colorspace.to_c(), dst.optional_color_properties.id, dst.ptr, dst.bytes_per_row));
    }
    pub fn premultiply_alpha(src: PixelRect, dst: PixelRect, linear: bool) Error!void {
        assert(src.size.x == dst.size.x and src.size.y == dst.size.y);
        return ok_or_fail_err(C.SDL_PremultiplyAlpha(src.size.x, src.size.y, src.pixel_format.to_c(), src.ptr, src.bytes_per_row, dst.pixel_format.to_c(), dst.ptr, dst.bytes_per_row, linear));
    }
};

pub const Surface = extern struct {
    flags: SurfaceFlags = .blank(),
    format: PixelFormat = .UNKNOWN,
    size: Vec_c_int,
    bytes_per_row: c_int = 0,
    pixel_data: ?*anyopaque = null,
    refcount: AtomicInt = .{ .val = 0 },
    _reserved: ?*anyopaque = null,

    pub const to_c_ptr = c_non_opaque_conversions(Surface, C.SDL_Surface).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(Surface, C.SDL_Surface).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(Surface, C.SDL_Surface).to_c;
    pub const from_c = c_non_opaque_conversions(Surface, C.SDL_Surface).from_c;

    pub fn create_surface(size: Vec_c_int, format: PixelFormat) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_CreateSurface(size.x, size.y, format));
    }
    pub fn create_surface_from(size: Vec_c_int, format: PixelFormat, pixel_data: [*]u8, bytes_per_row: c_int) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_CreateSurface(size.x, size.y, format, @ptrCast(@alignCast(pixel_data)), bytes_per_row));
    }
    pub fn destroy(self: *Surface) void {
        C.SDL_DestroySurface(self.to_c_ptr());
    }
    pub fn get_properties(self: *Surface) Error!PropertiesID {
        return PropertiesID{ .id = try nonzero_or_null_err(C.SDL_GetSurfaceProperties(self.to_c_ptr())) };
    }
    pub fn set_colorspace(self: *Surface, colorspace: Colorspace) Error!void {
        try ok_or_fail_err(C.SDL_SetSurfaceColorspace(self.to_c_ptr(), colorspace.to_c()));
    }
    pub fn get_colorspace(self: *Surface) Colorspace {
        C.SDL_GetSurfaceColorspace(self.to_c_ptr());
    }
    pub fn create_color_palette(self: *Surface) Error!*ColorPalette {
        return ptr_cast_or_fail_err(*ColorPalette, C.SDL_CreateSurfacePalette(self.to_c_ptr()));
    }
    pub fn set_color_palette(self: *Surface, palette: ColorPalette) Error!void {
        try ok_or_fail_err(C.SDL_SetSurfacePalette(self.to_c_ptr(), palette.to_c()));
    }
    pub fn get_color_palette(self: *Surface) Error!*ColorPalette {
        return ptr_cast_or_null_err(*ColorPalette, C.SDL_GetSurfacePalette(self.to_c_ptr()));
    }
    pub fn add_alternate_surface(self: *Surface, alternate: *Surface) Error!void {
        try ok_or_fail_err(C.SDL_AddSurfaceAlternateImage(self.to_c_ptr(), alternate.to_c_ptr()));
    }
    pub fn has_alternate_surfaces(self: *Surface) bool {
        return C.SDL_SurfaceHasAlternateImages(self.to_c_ptr());
    }
    pub fn get_all_alternate_surfaces(self: *Surface) Error!SurfaceList {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_null_err([*]*Surface, C.SDL_GetSurfaceImages(self.to_c_ptr(), &len));
        return SurfaceList{ .list = ptr[0..len] };
    }
    pub fn remove_all_alternate_surfaces(self: *Surface) Error!void {
        return ok_or_fail_err(C.SDL_RemoveSurfaceAlternateImages(self.to_c_ptr()));
    }
    pub fn lock(self: *Surface) Error!void {
        return ok_or_fail_err(C.SDL_LockSurface(self.to_c_ptr()));
    }
    pub fn unlock(self: *Surface) Error!void {
        return ok_or_fail_err(C.SDL_UnlockSurface(self.to_c_ptr()));
    }
    pub fn load_from_bmp_file(bmp_path: [*:0]const u8) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_LoadBMP(bmp_path));
    }
    pub fn save_to_bmp_file(self: *Surface, bmp_path: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_SaveBMP(self.to_c_ptr(), bmp_path));
    }
    pub fn load_from_bmp_iostream(stream: *IOStream, close_stream: bool) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_LoadBMP_IO(stream.to_c(), close_stream));
    }
    pub fn save_to_bmp_iostream(self: *Surface, stream: *IOStream, close_stream: bool) Error!void {
        return ok_or_fail_err(C.SDL_SaveBMP_IO(self.to_c_ptr(), stream.to_c(), close_stream));
    }
    pub fn set_RLE(self: *Surface, state: bool) Error!void {
        return ok_or_fail_err(C.SDL_SetSurfaceRLE(self.to_c_ptr(), state));
    }
    pub fn is_RLE_set(self: *Surface) bool {
        return ok_or_fail_err(C.SDL_SurfaceHasRLE(self.to_c_ptr()));
    }
    pub fn set_color_key(self: *Surface, state: bool, key: u32) Error!void {
        return ok_or_fail_err(C.SDL_SetSurfaceColorKey(self.to_c_ptr(), state, key));
    }
    pub fn has_color_key(self: *Surface) bool {
        return ok_or_fail_err(C.SDL_SurfaceHasColorKey(self.to_c_ptr()));
    }
    pub fn get_color_key(self: *Surface) Error!u32 {
        var key: u32 = 0;
        try ok_or_fail_err(C.SDL_GetSurfaceColorKey(self.to_c_ptr(), &key));
        return key;
    }
    pub fn set_color_mod(self: *Surface, color: Color_RGB_u8) Error!void {
        return ok_or_fail_err(C.SDL_SetSurfaceColorMod(self.to_c_ptr(), color.r, color.g, color.b));
    }
    pub fn get_color_mod(self: *Surface) Error!Color_RGB_u8 {
        var color: Color_RGB_u8 = Color_RGB_u8{};
        try ok_or_fail_err(C.SDL_GetSurfaceColorMod(self.to_c_ptr(), &color.r, &color.g, &color.b));
        return color;
    }
    pub fn set_alpha_mod(self: *Surface, alpha: u8) Error!void {
        return ok_or_fail_err(C.SDL_SetSurfaceAlphaMod(self.to_c_ptr(), alpha));
    }
    pub fn get_alpha_mod(self: *Surface) Error!u8 {
        var alpha: u8 = 0;
        try ok_or_fail_err(C.SDL_GetSurfaceColorMod(self.to_c_ptr(), &alpha));
        return alpha;
    }
    pub fn set_blend_mode(self: *Surface, mode: BlendMode) Error!void {
        return ok_or_fail_err(C.SDL_SetSurfaceBlendMode(self.to_c_ptr(), mode.mode));
    }
    pub fn get_blend_mode(self: *Surface) Error!BlendMode {
        var mode: u32 = 0;
        try ok_or_fail_err(C.SDL_GetSurfaceBlendMode(self.to_c_ptr(), &mode));
        return BlendMode{ .mode = mode };
    }
    pub fn set_clip_rect(self: *Surface, rect: Rect_c_int) Error!void {
        return ok_or_fail_err(C.SDL_SetSurfaceClipRect(self.to_c_ptr(), &rect));
    }
    pub fn get_clip_rect(self: *Surface) Error!Rect_c_int {
        var rect = Rect_c_int{};
        try ok_or_fail_err(C.SDL_GetSurfaceClipRect(self.to_c_ptr(), &rect));
        return rect;
    }
    pub fn flip(self: *Surface, flip_mode: FlipMode) Error!void {
        return ok_or_fail_err(C.SDL_FlipSurface(self.to_c_ptr(), flip_mode.to_c()));
    }
    pub fn duplicate(self: *Surface) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_DuplicateSurface(self.to_c_ptr()));
    }
    pub fn scale_copy(self: *Surface, scale: Scale) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_ScaleSurface(self.to_c_ptr(), scale.ratio.x, scale.ratio.y, scale.mode.to_c()));
    }
    pub fn convert_to_format(self: *Surface, format: PixelFormat) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_ConvertSurface(self.to_c_ptr(), format.to_c()));
    }
    pub fn convert_to_format_and_colorspace(self: *Surface, format: PixelFormat, optional_palette: ?*ColorPalette, color_space: Colorspace, extra_color_props: PropertiesID) Error!*Surface {
        return ptr_cast_or_fail_err(*Surface, C.SDL_ConvertSurface(self.to_c_ptr(), format.to_c(), @ptrCast(@alignCast(optional_palette)), color_space.to_c(), extra_color_props.id));
    }
    pub fn premultiply_alpha(self: *Surface, linear: bool) Error!void {
        return ok_or_fail_err(C.SDL_PremultiplySurfaceAlpha(self.to_c_ptr(), linear));
    }
    pub fn clear(self: *Surface, color: Color_RGBA_f32) Error!void {
        return ok_or_fail_err(C.SDL_ClearSurface(self.to_c_ptr(), color.r, color.g, color.b, color.a));
    }
    pub fn fill_rect(self: *Surface, rect: Rect_c_int, color: Color_RGBA_u8) Error!void {
        return ok_or_fail_err(C.SDL_FillSurfaceRect(self.to_c_ptr(), @ptrCast(@alignCast(&rect)), color.to_raw_int()));
    }
    pub fn fill_many_rects(self: *Surface, rects: []const Rect_c_int, color: Color_RGBA_u8) Error!void {
        return ok_or_fail_err(C.SDL_FillSurfaceRects(self.to_c_ptr(), @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len), color.to_raw_int()));
    }
    pub fn blit_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea) Error!void {
        return ok_or_fail_err(C.SDL_BlitSurface(self.to_c_ptr(), area.to_c(), dst.to_c_ptr(), dst_area.to_c()));
    }
    pub fn blit_unchecked_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea) Error!void {
        return ok_or_fail_err(C.SDL_BlitSurfaceUnchecked(self.to_c_ptr(), area.to_c(), dst.to_c_ptr(), dst_area.to_c()));
    }
    pub fn blit_scaled_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea, mode: ScaleMode) Error!void {
        return ok_or_fail_err(C.SDL_BlitSurface(self.to_c_ptr(), area.to_c(), dst.to_c_ptr(), dst_area.to_c(), mode.to_c()));
    }
    pub fn blit_scaled_unchecked_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea, mode: ScaleMode) Error!void {
        return ok_or_fail_err(C.SDL_BlitSurfaceUnchecked(self.to_c_ptr(), area.to_c(), dst.to_c_ptr(), dst_area.to_c(), mode.to_c()));
    }
    pub fn copy_stretched_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea, mode: ScaleMode) Error!void {
        return ok_or_fail_err(C.SDL_StretchSurface(self.to_c_ptr(), area.to_c(), dst.to_c_ptr(), dst_area.to_c(), mode.to_c()));
    }
    pub fn blit_tiled_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea) Error!void {
        return ok_or_fail_err(C.SDL_BlitSurfaceTiled(self.to_c_ptr(), area.to_c(), dst.to_c_ptr(), dst_area.to_c()));
    }
    pub fn blit_tiled_scaled_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea, scale: Scale) Error!void {
        return ok_or_fail_err(C.SDL_BlitSurfaceTiledWithScale(self.to_c_ptr(), area.to_c(), scale.ratio, scale.mode.to_c(), dst.to_c_ptr(), dst_area.to_c()));
    }
    pub fn blit_nine_patch_to(self: *Surface, nine_patch: NinePatch_c_int, dst: *Surface, dst_area: IArea, scale: Scale) Error!void {
        return ok_or_fail_err(C.SDL_BlitSurface9Grid(self.to_c_ptr(), nine_patch.rect_to_c(), nine_patch.left, nine_patch.right, nine_patch.top, nine_patch.bottom, scale.ratio, scale.mode.to_c(), dst.to_c_ptr(), dst_area.to_c()));
    }
    pub fn closest_valid_color_rgb(self: *Surface, color: Color_RGB_u8) Color_raw_u32 {
        return Color_raw_u32{ .raw = C.SDL_MapSurfaceRGB(self.to_c_ptr(), color.r, color.g, color.b) };
    }
    pub fn closest_valid_color_rgba(self: *Surface, color: Color_RGBA_u8) Color_raw_u32 {
        return Color_raw_u32{ .raw = C.SDL_MapSurfaceRGBA(self.to_c_ptr(), color.r, color.g, color.b, color.a) };
    }
    pub fn read_pixel(self: *Surface, pos: Vec_c_int) Error!Color_RGBA_u8 {
        var color = Color_RGBA_u8{};
        try ok_or_fail_err(C.SDL_ReadSurfacePixel(self.to_c_ptr(), pos.x, pos.y, &color.r, &color.g, &color.b, &color.a));
        return color;
    }
    pub fn read_pixel_float(self: *Surface, pos: Vec_c_int) Error!Color_RGBA_f32 {
        var color = Color_RGBA_f32{};
        try ok_or_fail_err(C.SDL_ReadSurfacePixelFloat(self.to_c_ptr(), pos.x, pos.y, &color.r, &color.g, &color.b, &color.a));
        return color;
    }
    pub fn write_pixel(self: *Surface, pos: Vec_c_int, color: Color_RGBA_u8) Error!void {
        return ok_or_fail_err(C.SDL_ReadSurfacePixel(self.to_c_ptr(), pos.x, pos.y, color.r, color.g, color.b, color.a));
    }
    pub fn write_pixel_float(self: *Surface, pos: Vec_c_int, color: Color_RGBA_f32) Error!void {
        return ok_or_fail_err(C.SDL_WriteSurfacePixelFloat(self.to_c_ptr(), pos.x, pos.y, color.r, color.g, color.b, color.a));
    }

    pub const Props = struct {
        pub const SDR_WHITE_POINT = Property.new(.FLOAT, C.SDL_PROP_SURFACE_SDR_WHITE_POINT_FLOAT);
        pub const HDR_HEADROOM = Property.new(.FLOAT, C.SDL_PROP_SURFACE_HDR_HEADROOM_FLOAT);
        pub const TONEMAP_OPERATOR = Property.new(.STRING, C.SDL_PROP_SURFACE_TONEMAP_OPERATOR_STRING);
        pub const HOTSPOT_X = Property.new(.INTEGER, C.SDL_PROP_SURFACE_HOTSPOT_X_NUMBER);
        pub const HOTSPOT_Y = Property.new(.INTEGER, C.SDL_PROP_SURFACE_HOTSPOT_Y_NUMBER);
    };
};

pub const SurfaceList = extern struct {
    list: []*Surface,

    pub fn free(self: SurfaceList) void {
        Mem.free(self.list.ptr);
    }
};

pub const SimpleVertex = extern struct {
    position: Vec_f32 = Vec_f32{},
    color: Color_RGBA_f32 = Color_RGBA_f32{},
    tex_coord: Vec_f32 = Vec_f32,
};

pub const SurfaceFlags = Flags(enum(C.SDL_SurfaceFlags) {
    PREALLOCATED = C.SDL_SURFACE_PREALLOCATED,
    LOCK_NEEDED = C.SDL_SURFACE_LOCK_NEEDED,
    LOCKED = C.SDL_SURFACE_LOCKED,
    SIMD_ALIGNED = C.SDL_SURFACE_SIMD_ALIGNED,
}, enum(C.SDL_SurfaceFlags) {});

pub const TextureAccessMode = enum(c_uint) {
    STATIC = C.SDL_TEXTUREACCESS_STATIC,
    STREAMING = C.SDL_TEXTUREACCESS_STREAMING,
    TARGET = C.SDL_TEXTUREACCESS_TARGET,

    inline fn to_c(self: TextureAccessMode) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) TextureAccessMode {
        return @enumFromInt(val);
    }
};

pub const TextureWriteSurface = extern struct {
    surface: *Surface,
    texture: ?*SimpleTexture,

    pub fn unlock(self: *TextureWriteSurface) void {
        assert(self.texture != null);
        C.SDL_UnlockTexture(self.texture.?);
        self.surface = &Surface{};
        self.texture = null;
    }
};

pub const BlendOperation = enum(c_uint) {
    ADD = C.SDL_BLENDOPERATION_ADD,
    SUBTRACT = C.SDL_BLENDOPERATION_SUBTRACT,
    REV_SUBTRACT = C.SDL_BLENDOPERATION_REV_SUBTRACT,
    MINIMUM = C.SDL_BLENDOPERATION_MINIMUM,
    MAXIMUM = C.SDL_BLENDOPERATION_MAXIMUM,

    inline fn to_c(self: BlendOperation) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) BlendOperation {
        return @enumFromInt(val);
    }
};
pub const SimpleTexture = extern struct {
    format: PixelFormat = .UNKNOWN,
    size: Vec_c_int = .ZERO_ZERO,
    /// WARNING: changing this manually may be dangerous if not handled properly
    ref_count: AtomicInt = .{ .val = 0 },
    /// WARNING: changing this manually may be dangerous if not handled properly
    pub fn increment_refs(self: *SimpleTexture) c_int {
        return self.ref_count.increment();
    }
    /// WARNING: changing this manually may be dangerous if not handled properly
    pub fn decrement_refs(self: *SimpleTexture) bool {
        return self.ref_count.decrement() == 1;
    }

    pub const to_c_ptr = c_non_opaque_conversions(SimpleTexture, C.SDL_Texture).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(SimpleTexture, C.SDL_Texture).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(SimpleTexture, C.SDL_Texture).to_c;
    pub const from_c = c_non_opaque_conversions(SimpleTexture, C.SDL_Texture).from_c;

    pub fn destroy(self: *SimpleTexture) void {
        C.SDL_DestroyTexture(self.to_c_ptr());
    }

    pub fn get_properties(self: *SimpleTexture) PropertiesID {
        return C.SDL_GetTextureProperties(self.to_c_ptr());
    }
    pub fn get_renderer(self: *SimpleTexture) Error!*Renderer {
        return ptr_cast_or_null_err(*Renderer, C.SDL_GetTextureProperties(self.to_c_ptr()));
    }
    pub fn get_size(self: *SimpleTexture) Error!Vec_c_int {
        var size = Vec_c_int{};
        try ok_or_null_err(C.SDL_GetTextureSize(self.to_c_ptr(), &size.x, &size.y));
        return size;
    }
    pub fn set_color_mod(self: *SimpleTexture, color: Color_RGB_u8) Error!void {
        return ok_or_fail_err(C.SDL_SetTextureColorMod(self.to_c_ptr(), color.r, color.g, color.b));
    }
    pub fn set_color_mod_float(self: *SimpleTexture, color: Color_RGB_f32) Error!void {
        return ok_or_fail_err(C.SDL_SetTextureColorModFloat(self.to_c_ptr(), color.r, color.g, color.b));
    }
    pub fn get_color_mod(self: *SimpleTexture) Error!Color_RGB_u8 {
        var color = Color_RGB_u8{};
        try ok_or_null_err(C.SDL_GetTextureColorMod(self.to_c_ptr(), &color.r, &color.g, &color.b));
        return color;
    }
    pub fn get_color_mod_float(self: *SimpleTexture) Error!Color_RGB_f32 {
        var color = Color_RGB_f32{};
        try ok_or_null_err(C.SDL_GetTextureColorModFloat(self.to_c_ptr(), &color.r, &color.g, &color.b));
        return color;
    }
    pub fn set_alpha_mod(self: *SimpleTexture, alpha: u8) Error!void {
        return ok_or_fail_err(C.SDL_SetTextureAlphaMod(self.to_c_ptr(), alpha));
    }
    pub fn set_alpha_mod_float(self: *SimpleTexture, alpha: f32) Error!void {
        return ok_or_fail_err(C.SDL_SetTextureAlphaModFloat(self.to_c_ptr(), alpha));
    }
    pub fn get_alpha_mod(self: *SimpleTexture) Error!u8 {
        var alpha: u8 = 0;
        try ok_or_null_err(C.SDL_GetTextureAlphaMod(self.to_c_ptr(), &alpha));
        return alpha;
    }
    pub fn get_alpha_mod_float(self: *SimpleTexture) Error!f32 {
        var alpha: f32 = 0.0;
        try ok_or_null_err(C.SDL_GetTextureAlphaModFloat(self.to_c_ptr(), &alpha));
        return alpha;
    }
    pub fn set_blend_mode(self: *SimpleTexture, blend_mode: BlendMode) Error!void {
        return ok_or_fail_err(C.SDL_SetTextureBlendMode(self.to_c_ptr(), blend_mode.mode));
    }
    pub fn get_blend_mode(self: *SimpleTexture) Error!BlendMode {
        var mode: u32 = 0;
        try ok_or_null_err(C.SDL_GetTextureBlendMode(self.to_c_ptr(), &mode));
        return BlendMode{ .mode = mode };
    }
    pub fn set_scale_mode(self: *SimpleTexture, scale_mode: ScaleMode) Error!void {
        return ok_or_fail_err(C.SDL_SetTextureScaleMode(self.to_c_ptr(), scale_mode.to_c()));
    }
    pub fn get_scale_mode(self: *SimpleTexture) Error!ScaleMode {
        var mode: c_int = 0;
        try ok_or_null_err(C.SDL_GetTextureScaleMode(self.to_c_ptr(), &mode));
        return ScaleMode.from_c(mode);
    }
    pub fn update_texture(self: *SimpleTexture, raw_pixel_data: []const u8, bytes_per_row: c_int) Error!void {
        return ok_or_fail_err(C.SDL_UpdateTexture(self.to_c_ptr(), null, raw_pixel_data.ptr, bytes_per_row));
    }
    pub fn update_texture_rect(self: *SimpleTexture, rect: Rect_c_int, raw_pixel_data: []const u8, bytes_per_row: c_int) Error!void {
        return ok_or_fail_err(C.SDL_UpdateTexture(self.to_c_ptr(), @ptrCast(@alignCast(&rect)), raw_pixel_data.ptr, bytes_per_row));
    }
    pub fn update_YUV_texture(self: *SimpleTexture, y_plane_data: []const u8, bytes_per_y_row: c_int, u_plane_data: []const u8, bytes_per_u_row: c_int, v_plane_data: []const u8, bytes_per_v_row: c_int) Error!void {
        return ok_or_fail_err(C.SDL_UpdateYUVTexture(self.to_c_ptr(), null, y_plane_data.ptr, bytes_per_y_row, u_plane_data.ptr, bytes_per_u_row, v_plane_data.ptr, bytes_per_v_row));
    }
    pub fn update_YUV_texture_rect(self: *SimpleTexture, rect: Rect_c_int, y_plane_data: []const u8, bytes_per_y_row: c_int, u_plane_data: []const u8, bytes_per_u_row: c_int, v_plane_data: []const u8, bytes_per_v_row: c_int) Error!void {
        return ok_or_fail_err(C.SDL_UpdateYUVTexture(self.to_c_ptr(), @ptrCast(@alignCast(&rect)), y_plane_data.ptr, bytes_per_y_row, u_plane_data.ptr, bytes_per_u_row, v_plane_data.ptr, bytes_per_v_row));
    }
    pub fn update_NV_texture_rect(self: *SimpleTexture, rect: Rect_c_int, y_plane_data: []const u8, bytes_per_y_row: c_int, uv_plane_data: []const u8, bytes_per_uv_row: c_int) Error!void {
        return ok_or_fail_err(C.SDL_UpdateNVTexture(self.to_c_ptr(), @ptrCast(@alignCast(&rect)), y_plane_data.ptr, bytes_per_y_row, uv_plane_data.ptr, bytes_per_uv_row));
    }
    pub fn lock_for_byte_write(self: *SimpleTexture) Error!TextureWriteBytes {
        var bytes_ptr: [*]u8 = undefined;
        var bytes_per_row: c_int = 0;
        try ok_or_fail_err(C.SDL_LockTexture(self.to_c_ptr(), null, &bytes_ptr, &bytes_per_row));
        const total_len = self.height * bytes_per_row;
        return TextureWriteBytes{
            .bytes = bytes_ptr[0..total_len],
            .bytes_per_row = bytes_per_row,
            .texture = self,
        };
    }
    pub fn lock_rect_for_byte_write(self: *SimpleTexture, rect: Rect_c_int) Error!TextureWriteBytes {
        var bytes_ptr: [*]u8 = undefined;
        var bytes_per_row: c_int = 0;
        try ok_or_fail_err(C.SDL_LockTexture(self.to_c_ptr(), @ptrCast(@alignCast(&rect)), &bytes_ptr, &bytes_per_row));
        const total_len = rect.y * bytes_per_row;
        return TextureWriteBytes{
            .bytes = bytes_ptr[0..total_len],
            .bytes_per_row = bytes_per_row,
            .texture = self,
        };
    }
    pub fn lock_for_surface_write(self: *SimpleTexture) Error!TextureWriteSurface {
        var surface: *Surface = undefined;
        try ok_or_fail_err(C.SDL_LockTextureToSurface(self.to_c_ptr(), null, @ptrCast(@alignCast(&surface))));
        return TextureWriteSurface{
            .surface = surface,
            .texture = self,
        };
    }
    pub fn lock_rect_for_surface_write(self: *SimpleTexture, rect: Rect_c_int) Error!TextureWriteSurface {
        var surface: *Surface = undefined;
        try ok_or_fail_err(C.SDL_LockTextureToSurface(self.to_c_ptr(), @ptrCast(@alignCast(&rect)), @ptrCast(@alignCast(&surface))));
        return TextureWriteSurface{
            .surface = surface,
            .texture = self,
        };
    }

    pub const CreateProps = struct {
        pub const COLORSPACE = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_COLORSPACE_NUMBER);
        pub const FORMAT = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_FORMAT_NUMBER);
        pub const ACCESS = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_ACCESS_NUMBER);
        pub const WIDTH = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_WIDTH_NUMBER);
        pub const HEIGHT = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_HEIGHT_NUMBER);
        pub const SDR_WHITE_POINT = Property.new(.FLOAT, C.SDL_PROP_TEXTURE_CREATE_SDR_WHITE_POINT_FLOAT);
        pub const HDR_HEADROOM = Property.new(.FLOAT, C.SDL_PROP_TEXTURE_CREATE_HDR_HEADROOM_FLOAT);
        pub const D3D11_TEXTURE = Property.new(.POINTER, C.SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_POINTER);
        pub const D3D11_TEXTURE_U = Property.new(.POINTER, C.SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_U_POINTER);
        pub const D3D11_TEXTURE_V = Property.new(.POINTER, C.SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_V_POINTER);
        pub const D3D12_TEXTURE = Property.new(.POINTER, C.SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_POINTER);
        pub const D3D12_TEXTURE_U = Property.new(.POINTER, C.SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_U_POINTER);
        pub const D3D12_TEXTURE_V = Property.new(.POINTER, C.SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_V_POINTER);
        pub const METAL_PIXELBUFFER = Property.new(.POINTER, C.SDL_PROP_TEXTURE_CREATE_METAL_PIXELBUFFER_POINTER);
        pub const OPENGL_TEXTURE = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_NUMBER);
        pub const OPENGL_TEXTURE_UV = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_UV_NUMBER);
        pub const OPENGL_TEXTURE_U = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_U_NUMBER);
        pub const OPENGL_TEXTURE_V = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_V_NUMBER);
        pub const OPENGLES2_TEXTURE = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_NUMBER);
        pub const OPENGLES2_TEXTURE_UV = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_UV_NUMBER);
        pub const OPENGLES2_TEXTURE_U = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_U_NUMBER);
        pub const OPENGLES2_TEXTURE_V = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_V_NUMBER);
        pub const VULKAN_TEXTURE = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_CREATE_VULKAN_TEXTURE_NUMBER);
    };
    pub const Props = struct {
        pub const COLORSPACE = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_COLORSPACE_NUMBER);
        pub const FORMAT = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_FORMAT_NUMBER);
        pub const ACCESS = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_ACCESS_NUMBER);
        pub const WIDTH = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_WIDTH_NUMBER);
        pub const HEIGHT = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_HEIGHT_NUMBER);
        pub const SDR_WHITE_POINT = Property.new(.FLOAT, C.SDL_PROP_TEXTURE_SDR_WHITE_POINT_FLOAT);
        pub const HDR_HEADROOM = Property.new(.FLOAT, C.SDL_PROP_TEXTURE_HDR_HEADROOM_FLOAT);
        pub const D3D11_TEXTURE = Property.new(.POINTER, C.SDL_PROP_TEXTURE_D3D11_TEXTURE_POINTER);
        pub const D3D11_TEXTURE_U = Property.new(.POINTER, C.SDL_PROP_TEXTURE_D3D11_TEXTURE_U_POINTER);
        pub const D3D11_TEXTURE_V = Property.new(.POINTER, C.SDL_PROP_TEXTURE_D3D11_TEXTURE_V_POINTER);
        pub const D3D12_TEXTURE = Property.new(.POINTER, C.SDL_PROP_TEXTURE_D3D12_TEXTURE_POINTER);
        pub const D3D12_TEXTURE_U = Property.new(.POINTER, C.SDL_PROP_TEXTURE_D3D12_TEXTURE_U_POINTER);
        pub const D3D12_TEXTURE_V = Property.new(.POINTER, C.SDL_PROP_TEXTURE_D3D12_TEXTURE_V_POINTER);
        pub const OPENGL_TEXTURE = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_OPENGL_TEXTURE_NUMBER);
        pub const OPENGL_TEXTURE_UV = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_OPENGL_TEXTURE_UV_NUMBER);
        pub const OPENGL_TEXTURE_U = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_OPENGL_TEXTURE_U_NUMBER);
        pub const OPENGL_TEXTURE_V = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_OPENGL_TEXTURE_V_NUMBER);
        pub const OPENGL_TEXTURE_TARGET = Property.new(.FLOAT, C.SDL_PROP_TEXTURE_OPENGL_TEX_W_FLOAT);
        pub const OPENGL_TEXTURE_WIDTH = Property.new(.FLOAT, C.SDL_PROP_TEXTURE_OPENGL_TEX_H_FLOAT);
        pub const OPENGLES2_TEXTURE = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_NUMBER);
        pub const OPENGLES2_TEXTURE_UV = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_UV_NUMBER);
        pub const OPENGLES2_TEXTURE_U = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_U_NUMBER);
        pub const OPENGLES2_TEXTURE_V = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_V_NUMBER);
        pub const OPENGLES2_TEXTURE_TARGET = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_TARGET_NUMBER);
        pub const VULKAN_TEXTURE = Property.new(.INTEGER, C.SDL_PROP_TEXTURE_VULKAN_TEXTURE_NUMBER);
    };
};

pub const BlendFactor = enum(C.SDL_BlendFactor) {
    ZERO = C.SDL_BLENDFACTOR_ZERO,
    ONE = C.SDL_BLENDFACTOR_ONE,
    SRC_COLOR = C.SDL_BLENDFACTOR_SRC_COLOR,
    ONE_MINUS_SRC_COLOR = C.SDL_BLENDFACTOR_ONE_MINUS_SRC_COLOR,
    SRC_ALPHA = C.SDL_BLENDFACTOR_SRC_ALPHA,
    ONE_MINUS_SRC_ALPHA = C.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
    DST_COLOR = C.SDL_BLENDFACTOR_DST_COLOR,
    ONE_MINUS_DST_COLOR = C.SDL_BLENDFACTOR_ONE_MINUS_DST_COLOR,
    DST_ALPHA = C.SDL_BLENDFACTOR_DST_ALPHA,
    ONE_MINUS_DST_ALPHA = C.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,

    pub const to_c = c_enum_conversions(BlendFactor, C.SDL_BlendFactor).to_c;
    pub const from_c = c_enum_conversions(BlendFactor, C.SDL_BlendFactor).from_c;
};

pub const PixelType = enum(C.SDL_PixelType) {
    UNKNOWN = C.SDL_PIXELTYPE_UNKNOWN,
    INDEX_1 = C.SDL_PIXELTYPE_INDEX1,
    INDEX_2 = C.SDL_PIXELTYPE_INDEX2,
    INDEX_4 = C.SDL_PIXELTYPE_INDEX4,
    INDEX_8 = C.SDL_PIXELTYPE_INDEX8,
    PACKED_8 = C.SDL_PIXELTYPE_PACKED8,
    PACKED_16 = C.SDL_PIXELTYPE_PACKED16,
    PACKED_32 = C.SDL_PIXELTYPE_PACKED32,
    ARRAY_U8 = C.SDL_PIXELTYPE_ARRAYU8,
    ARRAY_U16 = C.SDL_PIXELTYPE_ARRAYU16,
    ARRAY_U32 = C.SDL_PIXELTYPE_ARRAYU32,
    ARRAY_F16 = C.SDL_PIXELTYPE_ARRAYF16,
    ARRAY_F32 = C.SDL_PIXELTYPE_ARRAYF32,

    pub const to_c = c_enum_conversions(PixelType, C.SDL_PixelType).to_c;
    pub const from_c = c_enum_conversions(PixelType, C.SDL_PixelType).from_c;
};

pub const BitmapOrder = enum(C.SDL_BitmapOrder) {
    NONE = C.SDL_BITMAPORDER_NONE,
    _4321 = C.SDL_BITMAPORDER_4321,
    _1234 = C.SDL_BITMAPORDER_1234,

    pub const to_c = c_enum_conversions(BitmapOrder, C.SDL_BitmapOrder).to_c;
    pub const from_c = c_enum_conversions(BitmapOrder, C.SDL_BitmapOrder).from_c;
};

pub const PackedOrder = enum(C.SDL_PackedOrder) {
    NONE = C.SDL_PACKEDORDER_NONE,
    XRGB = C.SDL_PACKEDORDER_XRGB,
    RGBX = C.SDL_PACKEDORDER_RGBX,
    ARGB = C.SDL_PACKEDORDER_ARGB,
    RGBA = C.SDL_PACKEDORDER_RGBA,
    XBGR = C.SDL_PACKEDORDER_XBGR,
    BGRX = C.SDL_PACKEDORDER_BGRX,
    ABGR = C.SDL_PACKEDORDER_ABGR,
    BGRA = C.SDL_PACKEDORDER_BGRA,

    pub const to_c = c_enum_conversions(PackedOrder, C.SDL_PackedOrder).to_c;
    pub const from_c = c_enum_conversions(PackedOrder, C.SDL_PackedOrder).from_c;
};

pub const ArrayOrder = enum(C.SDL_ArrayOrder) {
    NONE = C.SDL_ARRAYORDER_NONE,
    RGB = C.SDL_ARRAYORDER_RGB,
    RGBA = C.SDL_ARRAYORDER_RGBA,
    ARGB = C.SDL_ARRAYORDER_ARGB,
    BGR = C.SDL_ARRAYORDER_BGR,
    BGRA = C.SDL_ARRAYORDER_BGRA,
    ABGR = C.SDL_ARRAYORDER_ABGR,

    pub const to_c = c_enum_conversions(ArrayOrder, C.SDL_ArrayOrder).to_c;
    pub const from_c = c_enum_conversions(ArrayOrder, C.SDL_ArrayOrder).from_c;
};

pub const PackedLayout = enum(C.SDL_PackedLayout) {
    NONE = C.SDL_PACKEDLAYOUT_NONE,
    _332 = C.SDL_PACKEDLAYOUT_332,
    _4444 = C.SDL_PACKEDLAYOUT_4444,
    _1555 = C.SDL_PACKEDLAYOUT_1555,
    _5551 = C.SDL_PACKEDLAYOUT_5551,
    _565 = C.SDL_PACKEDLAYOUT_565,
    _8888 = C.SDL_PACKEDLAYOUT_8888,
    _2101010 = C.SDL_PACKEDLAYOUT_2101010,
    _1010102 = C.SDL_PACKEDLAYOUT_1010102,

    pub const to_c = c_enum_conversions(PackedLayout, C.SDL_PackedLayout).to_c;
    pub const from_c = c_enum_conversions(PackedLayout, C.SDL_PackedLayout).from_c;
};

pub const ColorType = enum(C.SDL_ColorType) {
    UNKNOWN = C.SDL_COLOR_TYPE_UNKNOWN,
    RGB = C.SDL_COLOR_TYPE_RGB,
    YCBCR = C.SDL_COLOR_TYPE_YCBCR,

    pub const to_c = c_enum_conversions(ColorType, C.SDL_ColorType).to_c;
    pub const from_c = c_enum_conversions(ColorType, C.SDL_ColorType).from_c;
};

pub const ColorRange = enum(C.SDL_ColorRange) {
    UNKNOWN = C.SDL_COLOR_RANGE_UNKNOWN,
    LIMITED = C.SDL_COLOR_RANGE_LIMITED,
    FULL = C.SDL_COLOR_RANGE_FULL,

    pub const to_c = c_enum_conversions(ColorRange, C.SDL_ColorRange).to_c;
    pub const from_c = c_enum_conversions(ColorRange, C.SDL_ColorRange).from_c;
};

pub const System = struct {
    //TODO
    // pub extern fn SDL_ScreenSaverEnabled() bool;
    // pub extern fn SDL_EnableScreenSaver() bool;
    // pub extern fn SDL_DisableScreenSaver() bool;
    // pub extern fn SDL_GetSystemTheme() SDL_SystemTheme;
    // pub extern fn SDL_GetNumLogicalCPUCores() c_int;
    // pub extern fn SDL_GetCPUCacheLineSize() c_int;
    // pub extern fn SDL_HasAltiVec() bool;
    // pub extern fn SDL_HasMMX() bool;
    // pub extern fn SDL_HasSSE() bool;
    // pub extern fn SDL_HasSSE2() bool;
    // pub extern fn SDL_HasSSE3() bool;
    // pub extern fn SDL_HasSSE41() bool;
    // pub extern fn SDL_HasSSE42() bool;
    // pub extern fn SDL_HasAVX() bool;
    // pub extern fn SDL_HasAVX2() bool;
    // pub extern fn SDL_HasAVX512F() bool;
    // pub extern fn SDL_HasARMSIMD() bool;
    // pub extern fn SDL_HasNEON() bool;
    // pub extern fn SDL_HasLSX() bool;
    // pub extern fn SDL_HasLASX() bool;
    // pub extern fn SDL_GetSystemRAM() c_int;
    // pub extern fn SDL_GetSIMDAlignment() usize;
};

pub const Clipboard = struct {
    pub fn get_text() Error!AllocatedString {
        return AllocatedString{ .str = try nonempty_str_or_null_err(C.SDL_GetClipboardText()) };
    }
    pub fn set_text(text: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_SetClipboardText(text));
    }
    pub fn has_text() bool {
        return C.SDL_HasClipboardText();
    }
    //TODO
    // pub extern fn SDL_SetPrimarySelectionText(text: [*c]const u8) bool;
    // pub extern fn SDL_GetPrimarySelectionText() [*c]u8;
    // pub extern fn SDL_HasPrimarySelectionText() bool;
    // pub const SDL_ClipboardDataCallback = ?*const fn (?*anyopaque, [*c]const u8, [*c]usize) callconv(.c) ?*const anyopaque;
    // pub const SDL_ClipboardCleanupCallback = ?*const fn (?*anyopaque) callconv(.c) void;
    // pub extern fn SDL_SetClipboardData(callback: SDL_ClipboardDataCallback, cleanup: SDL_ClipboardCleanupCallback, userdata: ?*anyopaque, mime_types: [*c][*c]const u8, num_mime_types: usize) bool;
    // pub extern fn SDL_ClearClipboardData() bool;
    // pub extern fn SDL_GetClipboardData(mime_type: [*c]const u8, size: [*c]usize) ?*anyopaque;
    // pub extern fn SDL_HasClipboardData(mime_type: [*c]const u8) bool;
    // pub extern fn SDL_GetClipboardMimeTypes(num_mime_types: [*c]usize) [*c][*c]u8;
};

pub const AllocatedString = extern struct {
    str: [*:0]u8,

    pub fn slice(self: AllocatedString) [:0]u8 {
        return Types.make_slice_from_sentinel_ptr(u8, 0, self.str);
    }

    pub fn free(self: AllocatedString) void {
        return Mem.free(self.str);
    }
};

pub const DisplayOrientation = enum(c_int) {
    UNKNOWN = C.SDL_ORIENTATION_UNKNOWN,
    LANDSCAPE = C.SDL_ORIENTATION_LANDSCAPE,
    LANDSCAPE_FLIPPED = C.SDL_ORIENTATION_LANDSCAPE_FLIPPED,
    PORTRAIT = C.SDL_ORIENTATION_PORTRAIT,
    PORTRAIT_FLIPPED = C.SDL_ORIENTATION_PORTRAIT_FLIPPED,

    inline fn to_c(self: DisplayOrientation) c_int {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_int) DisplayOrientation {
        return @enumFromInt(val);
    }
};

pub const DisplayID = extern struct {
    id: u32 = 0,

    pub fn get_all_displays() Error!DisplayList {
        var len: c_int = 0;
        return DisplayList{ .ids = (try ptr_cast_or_null_err([*]u32, C.SDL_GetDisplays(&len)))[0..len] };
    }
    pub fn get_primary_display() Error!DisplayID {
        return DisplayID{ .id = try nonzero_or_null_err(C.SDL_GetPrimaryDisplay()) };
    }
    pub fn get_properties(self: DisplayID) Error!PropertiesID {
        return PropertiesID{ .id = try nonzero_or_null_err(C.SDL_GetDisplayProperties(self.id)) };
    }
    pub fn get_name(self: DisplayID) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetDisplayName(self.id));
    }
    pub fn get_bounds(self: DisplayID) Error!Rect_c_int {
        var rect = Rect_c_int{};
        try ok_or_null_err(C.SDL_GetDisplayBounds(self.id, @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn get_usable_bounds(self: DisplayID) Error!Rect_c_int {
        var rect = Rect_c_int{};
        try ok_or_null_err(C.SDL_GetDisplayUsableBounds(self.id, @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn get_natural_orientation(self: DisplayID) DisplayOrientation {
        return DisplayOrientation.from_c(C.SDL_GetNaturalDisplayOrientation(self.id));
    }
    pub fn get_current_orientation(self: DisplayID) DisplayOrientation {
        return DisplayOrientation.from_c(C.SDL_GetCurrentDisplayOrientation(self.id));
    }
    pub fn get_content_scale(self: DisplayID) f32 {
        return C.SDL_GetDisplayContentScale(self.id);
    }
    pub fn get_all_fullscreen_modes(self: DisplayID) Error!DisplayModeList {
        const len: c_int = 0;
        return DisplayModeList{
            .modes = (try ptr_cast_or_null_err([*]*DisplayMode, C.SDL_GetFullscreenDisplayModes(self.id, &len)))[0..len],
        };
    }
    pub fn get_closest_fullscreen_mode(self: DisplayID, options: ClosestDisplayModeOptions) Error!DisplayMode {
        const mode = DisplayMode{};
        try ok_or_null_err(C.SDL_GetClosestFullscreenDisplayMode(self.id, options.width, options.height, options.refresh_rate, options.include_high_density_modes, @ptrCast(@alignCast(&mode))));
        return mode;
    }
    pub fn get_desktop_mode(self: DisplayID) Error!*const DisplayMode {
        return ptr_cast_or_null_err(*const DisplayMode, C.SDL_GetDesktopDisplayMode(self.id));
    }
    pub fn get_current_mode(self: DisplayID) Error!*const DisplayMode {
        return ptr_cast_or_null_err(*const DisplayMode, C.SDL_GetCurrentDisplayMode(self.id));
    }
    pub fn get_display_for_point(point: Vec_c_int) Error!DisplayID {
        return DisplayID{ .id = try nonzero_or_null_err(C.SDL_GetDisplayForPoint(@ptrCast(@alignCast(&point)))) };
    }
    pub fn get_display_for_rect(rect: Rect_c_int) Error!DisplayID {
        return DisplayID{ .id = try nonzero_or_null_err(C.SDL_GetDisplayForRect(@ptrCast(@alignCast(&rect)))) };
    }

    pub const Props = struct {
        pub const HDR_ENABLED = Property.new(.BOOLEAN, C.SDL_PROP_DISPLAY_HDR_ENABLED_BOOLEAN);
        pub const KMSDRM_PANEL_ORIENTATION = Property.new(.INTEGER, C.SDL_PROP_DISPLAY_KMSDRM_PANEL_ORIENTATION_NUMBER);
    };
};

pub const ClosestDisplayModeOptions = struct {
    width: f32 = 800,
    height: f32 = 600,
    refresh_rate: f32 = 60.0,
    include_high_density_modes: bool = true,
};

pub const WindowID = extern struct {
    id: u32 = 0,

    pub fn get_window(self: WindowID) Error!*Window {
        return try ptr_cast_or_null_err(*Window, C.SDL_GetWindowFromID(self.id));
    }
};

pub const DisplayModeData = extern struct {
    extern_ptr: *External,

    pub const External: type = C.SDL_DisplayModeData;
};

pub const PixelFormat = enum(C.SDL_PixelFormat) {
    UNKNOWN = C.SDL_PIXELFORMAT_UNKNOWN,
    INDEX_1_LSB = C.SDL_PIXELFORMAT_INDEX1LSB,
    INDEX_1_MSB = C.SDL_PIXELFORMAT_INDEX1MSB,
    INDEX_2_LSB = C.SDL_PIXELFORMAT_INDEX2LSB,
    INDEX_2_MSB = C.SDL_PIXELFORMAT_INDEX2MSB,
    INDEX_4_LSB = C.SDL_PIXELFORMAT_INDEX4LSB,
    INDEX_4_MSB = C.SDL_PIXELFORMAT_INDEX4MSB,
    INDEX_8 = C.SDL_PIXELFORMAT_INDEX8,
    RGB_332 = C.SDL_PIXELFORMAT_RGB332,
    XRGB_4444 = C.SDL_PIXELFORMAT_XRGB4444,
    XBGR_4444 = C.SDL_PIXELFORMAT_XBGR4444,
    XRGB_1555 = C.SDL_PIXELFORMAT_XRGB1555,
    XBGR_1555 = C.SDL_PIXELFORMAT_XBGR1555,
    ARGB_4444 = C.SDL_PIXELFORMAT_ARGB4444,
    RGBA_4444 = C.SDL_PIXELFORMAT_RGBA4444,
    ABGR_4444 = C.SDL_PIXELFORMAT_ABGR4444,
    BGRA_4444 = C.SDL_PIXELFORMAT_BGRA4444,
    ARGB_1555 = C.SDL_PIXELFORMAT_ARGB1555,
    RGBA_5551 = C.SDL_PIXELFORMAT_RGBA5551,
    ABGR_1555 = C.SDL_PIXELFORMAT_ABGR1555,
    BGRA_5551 = C.SDL_PIXELFORMAT_BGRA5551,
    RGB_565 = C.SDL_PIXELFORMAT_RGB565,
    BGR_565 = C.SDL_PIXELFORMAT_BGR565,
    RGB_24 = C.SDL_PIXELFORMAT_RGB24,
    BGR_24 = C.SDL_PIXELFORMAT_BGR24,
    XRGB_8888 = C.SDL_PIXELFORMAT_XRGB8888,
    RGBX_8888 = C.SDL_PIXELFORMAT_RGBX8888,
    XBGR_8888 = C.SDL_PIXELFORMAT_XBGR8888,
    BGRX_8888 = C.SDL_PIXELFORMAT_BGRX8888,
    ARGB_8888 = C.SDL_PIXELFORMAT_ARGB8888,
    RGBA_8888 = C.SDL_PIXELFORMAT_RGBA8888,
    ABGR_8888 = C.SDL_PIXELFORMAT_ABGR8888,
    BGRA_8888 = C.SDL_PIXELFORMAT_BGRA8888,
    XRGB_2101010 = C.SDL_PIXELFORMAT_XRGB2101010,
    XBGR_2101010 = C.SDL_PIXELFORMAT_XBGR2101010,
    ARGB_2101010 = C.SDL_PIXELFORMAT_ARGB2101010,
    ABGR_2101010 = C.SDL_PIXELFORMAT_ABGR2101010,
    RGB_48 = C.SDL_PIXELFORMAT_RGB48,
    BGR_48 = C.SDL_PIXELFORMAT_BGR48,
    RGBA_64 = C.SDL_PIXELFORMAT_RGBA64,
    ARGB_64 = C.SDL_PIXELFORMAT_ARGB64,
    BGRA_64 = C.SDL_PIXELFORMAT_BGRA64,
    ABGR_64 = C.SDL_PIXELFORMAT_ABGR64,
    RGB_48_FLOAT = C.SDL_PIXELFORMAT_RGB48_FLOAT,
    BGR_48_FLOAT = C.SDL_PIXELFORMAT_BGR48_FLOAT,
    RGBA_64_FLOAT = C.SDL_PIXELFORMAT_RGBA64_FLOAT,
    ARGB_64_FLOAT = C.SDL_PIXELFORMAT_ARGB64_FLOAT,
    BGRA_64_FLOAT = C.SDL_PIXELFORMAT_BGRA64_FLOAT,
    ABGR_64_FLOAT = C.SDL_PIXELFORMAT_ABGR64_FLOAT,
    RGB_96_FLOAT = C.SDL_PIXELFORMAT_RGB96_FLOAT,
    BGR_96_FLOAT = C.SDL_PIXELFORMAT_BGR96_FLOAT,
    RGBA_128_FLOAT = C.SDL_PIXELFORMAT_RGBA128_FLOAT,
    ARGB_128_FLOAT = C.SDL_PIXELFORMAT_ARGB128_FLOAT,
    BGRA_128_FLOAT = C.SDL_PIXELFORMAT_BGRA128_FLOAT,
    ABGR_128_FLOAT = C.SDL_PIXELFORMAT_ABGR128_FLOAT,
    YV12 = C.SDL_PIXELFORMAT_YV12,
    IYUV = C.SDL_PIXELFORMAT_IYUV,
    YUY2 = C.SDL_PIXELFORMAT_YUY2,
    UYVY = C.SDL_PIXELFORMAT_UYVY,
    YVYU = C.SDL_PIXELFORMAT_YVYU,
    NV12 = C.SDL_PIXELFORMAT_NV12,
    NV21 = C.SDL_PIXELFORMAT_NV21,
    P010 = C.SDL_PIXELFORMAT_P010,
    EXTERNAL_OES = C.SDL_PIXELFORMAT_EXTERNAL_OES,
    MJPG = C.SDL_PIXELFORMAT_MJPG,
    _,

    pub const RGBA_32 = PixelFormat.from_c(C.SDL_PIXELFORMAT_RGBA32);
    pub const ARGB_32 = PixelFormat.from_c(C.SDL_PIXELFORMAT_ARGB32);
    pub const BGRA_32 = PixelFormat.from_c(C.SDL_PIXELFORMAT_BGRA32);
    pub const ABGR_32 = PixelFormat.from_c(C.SDL_PIXELFORMAT_ABGR32);
    pub const RGBX_32 = PixelFormat.from_c(C.SDL_PIXELFORMAT_RGBX32);
    pub const XRGB_32 = PixelFormat.from_c(C.SDL_PIXELFORMAT_XRGB32);
    pub const BGRX_32 = PixelFormat.from_c(C.SDL_PIXELFORMAT_BGRX32);
    pub const XBGR_32 = PixelFormat.from_c(C.SDL_PIXELFORMAT_XBGR32);

    pub fn custom_four_cc(str: []const u8) PixelFormat {
        assert_with_reason(str.len == 4, @src(), "invalid four_cc code `{s}`: four_cc format codes must have exactly 4 chars (use space ` ` to fill spots if needed)", .{str});
        return PixelFormat.from_c(C.SDL_DEFINE_PIXELFOURCC(str[0], str[1], str[2], str[3]));
    }

    pub fn custom(pixel_type: PixelType, order: PixelOrder, layout: PackedLayout, bits: c_uint, bytes: c_uint) PixelFormat {
        return PixelFormat.from_c(C.SDL_DEFINE_PIXELFORMAT(pixel_type, order, layout, bits, bytes));
    }

    pub fn get_flags(self: PixelFormat) c_uint {
        return @intCast(C.SDL_PIXELFLAG(self.to_c()));
    }
    pub fn get_pixel_type(self: PixelFormat) PixelType {
        return PixelType.from_c(C.SDL_PIXELFLAG(self.to_c()));
    }
    pub fn get_pixel_order(self: PixelFormat) PixelOrder {
        return @bitCast(@as(c_uint, @intCast(C.SDL_PIXELORDER(self.to_c()))));
    }
    pub fn get_pixel_layout(self: PixelFormat) PackedLayout {
        return PackedLayout.from_c(C.SDL_PIXELLAYOUT(self.to_c()));
    }

    pub fn bits_per_pixel(self: PixelFormat) c_uint {
        return @intCast(C.SDL_BITSPERPIXEL(self.to_c()));
    }

    pub fn bytes_per_pixel(self: PixelFormat) c_uint {
        return @intCast(C.SDL_BYTESPERPIXEL(self.to_c()));
    }

    pub fn is_indexed(self: PixelFormat) bool {
        return C.SDL_ISPIXELFORMAT_INDEXED(self.to_c());
    }

    pub fn is_packed(self: PixelFormat) bool {
        return C.SDL_ISPIXELFORMAT_PACKED(self.to_c());
    }

    pub fn is_array(self: PixelFormat) bool {
        return C.SDL_ISPIXELFORMAT_ARRAY(self.to_c());
    }

    pub fn is_10_bit(self: PixelFormat) bool {
        return C.SDL_ISPIXELFORMAT_10BIT(self.to_c());
    }

    pub fn is_float(self: PixelFormat) bool {
        return C.SDL_ISPIXELFORMAT_FLOAT(self.to_c());
    }

    pub fn is_integer(self: PixelFormat) bool {
        return !C.SDL_ISPIXELFORMAT_FLOAT(self.to_c());
    }

    pub fn has_alpha(self: PixelFormat) bool {
        return C.SDL_ISPIXELFORMAT_ALPHA(self.to_c());
    }

    pub fn is_four_cc(self: PixelFormat) bool {
        return C.SDL_ISPIXELFORMAT_FOURCC(self.to_c());
    }

    pub const PixelOrder = extern union {
        bitmap_order: BitmapOrder,
        packed_order: PackedOrder,
        array_order: ArrayOrder,

        pub fn new_bitmap_order(order: BitmapOrder) PixelOrder {
            return PixelOrder{ .bitmap_order = order };
        }
        pub fn new_packed_order(order: PackedOrder) PixelOrder {
            return PixelOrder{ .packed_order = order };
        }
        pub fn new_array_order(order: ArrayOrder) PixelOrder {
            return PixelOrder{ .array_order = order };
        }
    };

    pub const to_c = c_enum_conversions(PixelFormat, C.SDL_PixelFormat).to_c;
    pub const from_c = c_enum_conversions(PixelFormat, C.SDL_PixelFormat).from_c;
    //TODO
    // pub extern fn SDL_GetPixelFormatName(format: SDL_PixelFormat) [*c]const u8;
    // pub extern fn SDL_GetMasksForPixelFormat(format: SDL_PixelFormat, bpp: [*c]c_int, Rmask: [*c]Uint32, Gmask: [*c]Uint32, Bmask: [*c]Uint32, Amask: [*c]Uint32) bool;
    // pub extern fn SDL_GetPixelFormatForMasks(bpp: c_int, Rmask: Uint32, Gmask: Uint32, Bmask: Uint32, Amask: Uint32) SDL_PixelFormat;
    // pub extern fn SDL_GetPixelFormatDetails(format: SDL_PixelFormat) [*c]const SDL_PixelFormatDetails;
};

pub const DisplayMode = extern struct {
    display: DisplayID = DisplayID{},
    pixel_format: PixelFormat = .UNKNOWN,
    width: c_int = 0,
    height: c_int = 0,
    pixel_density: f32 = 0.0,
    refresh_rate: f32 = 0.0,
    refresh_rate_numerator: c_int = 0,
    refresh_rate_denominator: c_int = 0,
    data: ?DisplayModeData = null,

    // pub inline fn to_c(self: DisplayMode) C.SDL_DisplayMode {
    //     return @bitCast(self);
    // }
};

pub const SystemTheme = enum(c_uint) {
    UNKNOWN = C.SDL_SYSTEM_THEME_UNKNOWN,
    LIGHT = C.SDL_SYSTEM_THEME_LIGHT,
    DARK = C.SDL_SYSTEM_THEME_DARK,

    pub const to_c = c_enum_conversions(SystemTheme, C.SDL_SystemTheme).to_c;
    pub const from_c = c_enum_conversions(SystemTheme, C.SDL_SystemTheme).from_c;
};

pub const Window = opaque {
    pub const to_c_ptr = c_opaque_conversions(Window, C.SDL_Window).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Window, C.SDL_Window).from_c_ptr;
    pub fn try_get_display_id(self: *Window) Error!DisplayID {
        return DisplayID{ .id = try nonzero_or_null_err(C.SDL_GetDisplayForWindow(self.to_c_ptr())) };
    }
    pub fn get_pixel_density(self: *Window) f32 {
        return C.SDL_GetWindowPixelDensity(self.to_c_ptr());
    }
    pub fn get_display_scale(self: *Window) f32 {
        return C.SDL_GetWindowDisplayScale(self.to_c_ptr());
    }
    pub fn get_fullscreen_display_mode(self: *Window) FullscreenMode {
        return FullscreenMode{ .mode = C.SDL_GetWindowFullscreenMode(self) };
    }
    pub fn set_fullscreen_display_mode(self: *Window, mode: FullscreenMode) Error!void {
        return ok_or_fail_err(C.SDL_SetWindowFullscreenMode(self.to_c_ptr(), mode.mode));
    }
    pub fn get_icc_profile(self: *Window, size: usize) Error!*WindowICCProfile {
        return ptr_cast_or_null_err(*WindowICCProfile, C.SDL_GetWindowICCProfile(self.to_c_ptr(), &size));
    }
    pub fn get_pixel_format(self: *Window) PixelFormat {
        return @enumFromInt(C.SDL_GetWindowPixelFormat(self.to_c_ptr()));
    }
    pub fn get_all_windows() Error!WindowsList {
        var len: c_int = 0;
        return WindowsList{ .list = (try ptr_cast_or_null_err([*]*Window, C.SDL_GetWindows(&len)))[0..len] };
    }
    pub fn create(options: CreateWindowOptions) Error!*Window {
        return ptr_cast_or_fail_err(*Window, C.SDL_CreateWindow(options.title.ptr, options.size.x, options.size.y, options.flags.raw));
    }
    pub fn create_popup_window(parent: *Window, options: CreatePopupWindowOptions) Error!*Window {
        return ptr_cast_or_fail_err(*Window, C.SDL_CreatePopupWindow(parent.to_c_ptr(), options.x_offset, options.y_offset, options.width, options.height, options.flags));
    }
    pub fn create_window_with_properties(properties: PropertiesID) Error!*Window {
        return ptr_cast_or_fail_err(*Window, C.SDL_CreateWindowWithProperties(properties.id));
    }
    pub fn get_id(self: *Window) Error!WindowID {
        return WindowID{ .id = try nonzero_or_null_err(C.SDL_GetWindowID(self.to_c_ptr())) };
    }
    pub fn get_parent_window(self: *Window) Error!*Window {
        return ptr_cast_or_null_err(*Window, C.SDL_GetWindowParent(self.to_c_ptr()));
    }
    pub fn get_properties(self: *Window) Error!PropertiesID {
        return PropertiesID{ .id = try nonzero_or_null_err(C.SDL_GetWindowProperties(self.to_c_ptr())) };
    }
    pub fn get_flags(self: *Window) WindowFlags {
        return WindowFlags{ .flags = C.SDL_GetWindowFlags(self.to_c_ptr()) };
    }
    pub fn set_title(self: *Window, title: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowTitle(self.to_c_ptr(), title.ptr));
    }
    pub fn get_title(self: *Window) [*:0]const u8 {
        return @ptrCast(@alignCast(C.SDL_GetWindowTitle(self.to_c_ptr())));
    }
    pub fn set_window_icon(self: *Window, icon: *Surface) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowIcon(self.to_c_ptr(), @ptrCast(@alignCast(icon))));
    }
    pub fn set_window_position(self: *Window, pos: Vec_c_int) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowPosition(self.to_c_ptr(), pos.x, pos.y));
    }
    pub fn get_window_position(self: *Window) Error!Vec_c_int {
        var point = Vec_c_int{};
        try ok_or_null_err(C.SDL_GetWindowPosition(self.to_c_ptr(), &point.x, &point.y));
        return point;
    }
    pub fn set_size(self: *Window, size: Vec_c_int) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowSize(self.to_c_ptr(), size.x, size.y));
    }
    pub fn get_size(self: *Window) Error!Vec_c_int {
        var size = Vec_c_int.ZERO;
        try ok_or_null_err(C.SDL_GetWindowSize(self.to_c_ptr(), &size.x, &size.y));
        return size;
    }
    pub fn get_safe_area(self: *Window) Error!Rect_c_int {
        var rect = Rect_c_int{};
        try ok_or_null_err(C.SDL_GetWindowSafeArea(self.to_c_ptr(), @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn set_aspect_ratio(self: *Window, aspect_range: AspectRange) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowAspectRatio(self.to_c_ptr(), aspect_range.min, aspect_range.max));
    }
    pub fn get_aspect_ratio(self: *Window) Error!AspectRange {
        var ratio = AspectRange{};
        try ok_or_null_err(C.SDL_SetWindowAspectRatio(self.to_c_ptr(), &ratio.min, &ratio.max));
        return ratio;
    }
    pub fn get_border_sizes(self: *Window) Error!BorderSizes {
        var sizes = BorderSizes{};
        try ok_or_null_err(C.SDL_GetWindowBordersSize(self.to_c_ptr(), &sizes.top, &sizes.left, &sizes.bottom, &sizes.right));
        return sizes;
    }
    pub fn get_size_in_pixels(self: *Window) Error!Vec_c_int {
        var size = Vec_c_int{};
        try ok_or_null_err(C.SDL_GetWindowSizeInPixels(self.to_c_ptr(), &size.x, &size.y));
        return size;
    }
    pub fn set_minimum_size(self: *Window, size: Vec_c_int) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMinimumSize(self.to_c_ptr(), size.x, size.y));
    }
    pub fn get_minimum_size(self: *Window) Error!Vec_c_int {
        var size = Vec_c_int{};
        try ok_or_null_err(C.SDL_GetWindowMinimumSize(self.to_c_ptr(), &size.x, &size.y));
        return size;
    }
    pub fn set_maximum_size(self: *Window, size: Vec_c_int) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMaximumSize(self.to_c_ptr(), size.x, size.y));
    }
    pub fn get_maximum_size(self: *Window) Error!Vec_c_int {
        var size = Vec_c_int{};
        try ok_or_null_err(C.SDL_GetWindowMaximumSize(self.to_c_ptr(), &size.x, &size.y));
        return size;
    }
    pub fn set_bordered(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowBordered(self.to_c_ptr(), state));
    }
    pub fn set_resizable(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowResizable(self.to_c_ptr(), state));
    }
    pub fn set_always_on_top(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowAlwaysOnTop(self.to_c_ptr(), state));
    }
    pub fn show(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_ShowWindow(self.to_c_ptr()));
    }
    pub fn hide(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_HideWindow(self.to_c_ptr()));
    }
    pub fn raise(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_RaiseWindow(self.to_c_ptr()));
    }
    pub fn maximize(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_MaximizeWindow(self.to_c_ptr()));
    }
    pub fn minimize(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_MinimizeWindow(self.to_c_ptr()));
    }
    pub fn restore(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_RestoreWindow(self.to_c_ptr()));
    }
    pub fn set_fullscreen(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowFullscreen(self.to_c_ptr(), state));
    }
    pub fn sync(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SyncWindow(self.to_c_ptr()));
    }
    pub fn has_surface(self: *Window) bool {
        return C.SDL_WindowHasSurface(self.to_c_ptr());
    }
    pub fn get_surface(self: *Window) Error!*Surface {
        return ptr_cast_or_null_err(*Surface, C.SDL_GetWindowSurface(self.to_c_ptr()));
    }
    pub fn set_surface_vsync(self: *Window, vsync: VSync) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowSurfaceVSync(self.to_c_ptr(), vsync.to_c()));
    }
    pub fn get_surface_vsync(self: *Window) Error!VSync {
        var int: c_int = 0;
        try ok_or_fail_err(C.SDL_GetWindowSurfaceVSync(self.to_c_ptr(), &int));
        return VSync.from_c(int);
    }
    pub fn update_surface(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_UpdateWindowSurface(self.to_c_ptr()));
    }
    pub fn update_surface_rects(self: *Window, rects: []const Rect_c_int) Error!void {
        try ok_or_fail_err(C.SDL_UpdateWindowSurfaceRects(self.to_c_ptr(), @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len)));
    }
    pub fn destroy_surface(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_DestroyWindowSurface(self.to_c_ptr()));
    }
    pub fn set_keyboard_grab(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowKeyboardGrab(self.to_c_ptr(), state));
    }
    pub fn set_mouse_grab(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMouseGrab(self.to_c_ptr(), state));
    }
    pub fn is_keyboard_grabbed(self: *Window) bool {
        return C.SDL_GetWindowKeyboardGrab(self.to_c_ptr());
    }
    pub fn is_mouse_grabbed(self: *Window) bool {
        return C.SDL_GetWindowMouseGrab(self.to_c_ptr());
    }
    pub fn get_window_that_has_grab() Error!*Window {
        return ptr_cast_or_null_err(*Window, C.SDL_GetGrabbedWindow());
    }
    pub fn set_mouse_confine_rect(self: *Window, rect: Rect_c_int) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMouseRect(self.to_c_ptr(), @ptrCast(@alignCast(&rect))));
    }
    pub fn clear_mouse_confine_rect(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMouseRect(self.to_c_ptr(), null));
    }
    pub fn get_mouse_confine_rect(self: *Window) Error!Rect_c_int {
        const rect_ptr = try ptr_cast_or_null_err(*Rect_c_int, C.SDL_GetWindowMouseRect(self.to_c_ptr()));
        return rect_ptr.*;
    }
    pub fn set_opacity(self: *Window, opacity: f32) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowOpacity(self.to_c_ptr(), opacity));
    }
    pub fn get_opacity(self: *Window) f32 {
        return C.SDL_GetWindowOpacity(self.to_c_ptr());
    }
    pub fn set_parent(self: *Window, parent: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowParent(self.to_c_ptr(), parent.to_c_ptr()));
    }
    pub fn clear_parent(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowParent(self.to_c_ptr(), null));
    }
    pub fn set_modal(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowModal(self.to_c_ptr(), state));
    }
    pub fn set_focusable(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowFocusable(self.to_c_ptr(), state));
    }
    pub fn show_system_menu(self: *Window, pos: Vec_c_int) Error!void {
        try ok_or_fail_err(C.SDL_ShowWindowSystemMenu(self.to_c_ptr(), pos.x, pos.y));
    }
    pub fn set_custom_hittest(self: *Window, hittest_fn: *const WindowHittestFn, data: ?*anyopaque) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowHitTest(self.to_c_ptr(), @ptrCast(@alignCast(hittest_fn)), data));
    }
    pub fn clear_custom_hittest(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowHitTest(self.to_c_ptr(), null, null));
    }
    pub fn set_window_shape(self: *Window, shape: *Surface) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowShape(self.to_c_ptr(), @ptrCast(@alignCast(shape))));
    }
    pub fn clear_window_shape(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowShape(self.to_c_ptr(), null));
    }
    pub fn flash_window(self: *Window, mode: FlashMode) Error!void {
        try ok_or_fail_err(C.SDL_FlashWindow(self.to_c_ptr(), mode.to_c()));
    }
    pub fn destroy(self: *Window) void {
        C.SDL_DestroyWindow(self.to_c_ptr());
    }
    pub fn create_renderer(self: *Window) Error!*Renderer {
        return ptr_cast_or_fail_err(*Renderer, C.SDL_CreateRenderer(self.to_c_ptr(), null));
    }
    pub fn create_renderer_with_name(self: *Window, name: [*:0]const u8) Error!*Renderer {
        return ptr_cast_or_fail_err(*Renderer, C.SDL_CreateRenderer(self.to_c_ptr(), name));
    }
    pub fn get_renderer(self: *Window) Error!*Renderer {
        return ptr_cast_or_null_err(*Renderer, C.SDL_GetRenderer(self.to_c_ptr()));
    }
    pub fn set_mouse_mode_relative(self: *Window, state: bool) Error!void {
        return ok_or_fail_err(C.SDL_SetWindowRelativeMouseMode(self.to_c_ptr(), state));
    }
    pub fn is_mouse_mode_relative(self: *Window) bool {
        return C.SDL_GetWindowRelativeMouseMode(self.to_c_ptr());
    }
    pub fn warp_mouse_position(self: *Window, pos: Vec_f32) void {
        C.SDL_WarpMouseInWindow(self.to_c_ptr(), pos.x, pos.y);
    }
    //TODO
    // pub extern fn SDL_StartTextInput(window: ?*SDL_Window) bool;
    // pub extern fn SDL_StartTextInputWithProperties(window: ?*SDL_Window, props: SDL_PropertiesID) bool;
    // pub extern fn SDL_TextInputActive(window: ?*SDL_Window) bool;
    // pub extern fn SDL_StopTextInput(window: ?*SDL_Window) bool;
    // pub extern fn SDL_ClearComposition(window: ?*SDL_Window) bool;
    // pub extern fn SDL_SetTextInputArea(window: ?*SDL_Window, rect: [*c]const SDL_Rect, cursor: c_int) bool;
    // pub extern fn SDL_GetTextInputArea(window: ?*SDL_Window, rect: [*c]SDL_Rect, cursor: [*c]c_int) bool;
    // pub extern fn SDL_ScreenKeyboardShown(window: ?*SDL_Window) bool;
    // pub extern fn SDL_GL_CreateContext(window: ?*SDL_Window) SDL_GLContext;
    // pub extern fn SDL_GL_MakeCurrent(window: ?*SDL_Window, context: SDL_GLContext) bool;
    // pub extern fn SDL_GL_GetCurrentWindow() ?*SDL_Window;
    // pub extern fn SDL_EGL_GetWindowSurface(window: ?*SDL_Window) SDL_EGLSurface;
    // pub extern fn SDL_GL_SwapWindow(window: ?*SDL_Window) bool;
    // pub extern fn SDL_ShowSimpleMessageBox(flags: SDL_MessageBoxFlags, title: [*c]const u8, message: [*c]const u8, window: ?*SDL_Window) bool;
    // pub extern fn SDL_Metal_CreateView(window: ?*SDL_Window) SDL_MetalView;

    pub const CreateProps = struct {
        pub const ALWAYS_ON_TOP = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_ALWAYS_ON_TOP_BOOLEAN);
        pub const BORDERLESS = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_BORDERLESS_BOOLEAN);
        pub const FOCUSABLE = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_FOCUSABLE_BOOLEAN);
        pub const EXTERNAL_GRAPHICS_CONTEXT = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_EXTERNAL_GRAPHICS_CONTEXT_BOOLEAN);
        pub const FLAGS = Property.new(.INTEGER, C.SDL_PROP_WINDOW_CREATE_FLAGS_NUMBER);
        pub const FULLSCREEN = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_FULLSCREEN_BOOLEAN);
        pub const HEIGHT = Property.new(.INTEGER, C.SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER);
        pub const HIDDEN = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN);
        pub const HIGH_PIXEL_DENSITY = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_HIGH_PIXEL_DENSITY_BOOLEAN);
        pub const MAXIMIZED = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_MAXIMIZED_BOOLEAN);
        pub const MENU = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_MENU_BOOLEAN);
        pub const METAL = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_METAL_BOOLEAN);
        pub const MINIMIZED = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_MINIMIZED_BOOLEAN);
        pub const MODAL = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_MODAL_BOOLEAN);
        pub const GRAB_MOUSE = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_MOUSE_GRABBED_BOOLEAN);
        pub const OPENGL = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_OPENGL_BOOLEAN);
        pub const PARENT = Property.new(.POINTER, C.SDL_PROP_WINDOW_CREATE_PARENT_POINTER);
        pub const RESIZABLE = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_RESIZABLE_BOOLEAN);
        pub const TITLE = Property.new(.STRING, C.SDL_PROP_WINDOW_CREATE_TITLE_STRING);
        pub const TRANSPARENT = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_TRANSPARENT_BOOLEAN);
        pub const TOOLTIP = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_TOOLTIP_BOOLEAN);
        pub const UTILITY = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_UTILITY_BOOLEAN);
        pub const VULKAN = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_VULKAN_BOOLEAN);
        pub const WIDTH = Property.new(.INTEGER, C.SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER);
        pub const X_POS = Property.new(.INTEGER, C.SDL_PROP_WINDOW_CREATE_X_NUMBER);
        pub const Y_POS = Property.new(.INTEGER, C.SDL_PROP_WINDOW_CREATE_Y_NUMBER);
        pub const POS_DONT_CARE: i64 = @intCast(C.SDL_WINDOWPOS_UNDEFINED);
        pub const POS_CENTERED: i64 = @intCast(C.SDL_WINDOWPOS_CENTERED);
        pub const COCOA_WINDOW = Property.new(.POINTER, C.SDL_PROP_WINDOW_CREATE_COCOA_WINDOW_POINTER);
        pub const COCOA_VIEW = Property.new(.POINTER, C.SDL_PROP_WINDOW_CREATE_COCOA_VIEW_POINTER);
        pub const WAYLAND_SURFACE_ROLE_CUSTOM = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_WAYLAND_SURFACE_ROLE_CUSTOM_BOOLEAN);
        pub const WAYLAND_CREATE_EGL_WINDOW = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_CREATE_WAYLAND_CREATE_EGL_WINDOW_BOOLEAN);
        pub const WAYLAND_WL_SURFACE = Property.new(.POINTER, C.SDL_PROP_WINDOW_CREATE_WAYLAND_WL_SURFACE_POINTER);
        pub const WIN32_HWND = Property.new(.POINTER, C.SDL_PROP_WINDOW_CREATE_WIN32_HWND_POINTER);
        pub const WIN32_PIXEL_FORMAT_HWND = Property.new(.POINTER, C.SDL_PROP_WINDOW_CREATE_WIN32_PIXEL_FORMAT_HWND_POINTER);
        pub const X11_WINDOW = Property.new(.INTEGER, C.SDL_PROP_WINDOW_CREATE_X11_WINDOW_NUMBER);
    };

    pub const Props = struct {
        pub const SHAPE = Property.new(.POINTER, C.SDL_PROP_WINDOW_SHAPE_POINTER);
        pub const HDR_ENABLED = Property.new(.BOOLEAN, C.SDL_PROP_WINDOW_HDR_ENABLED_BOOLEAN);
        pub const SDR_WHITE_LEVEL = Property.new(.FLOAT, C.SDL_PROP_WINDOW_SDR_WHITE_LEVEL_FLOAT);
        pub const HDR_HEADROOM = Property.new(.FLOAT, C.SDL_PROP_WINDOW_HDR_HEADROOM_FLOAT);
        pub const ANDROID_WINDOW = Property.new(.POINTER, C.SDL_PROP_WINDOW_ANDROID_WINDOW_POINTER);
        pub const ANDROID_SURFACE = Property.new(.POINTER, C.SDL_PROP_WINDOW_ANDROID_SURFACE_POINTER);
        pub const UIKIT_WINDOW = Property.new(.POINTER, C.SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER);
        pub const UIKIT_METAL_VIEW_TAG = Property.new(.INTEGER, C.SDL_PROP_WINDOW_UIKIT_METAL_VIEW_TAG_NUMBER);
        pub const UIKIT_OPENGL_FRAMEBUFFER = Property.new(.INTEGER, C.SDL_PROP_WINDOW_UIKIT_OPENGL_FRAMEBUFFER_NUMBER);
        pub const UIKIT_OPENGL_RENDERBUFFER = Property.new(.INTEGER, C.SDL_PROP_WINDOW_UIKIT_OPENGL_RENDERBUFFER_NUMBER);
        pub const UIKIT_OPENGL_RESOLVE_FRAMEBUFFER = Property.new(.INTEGER, C.SDL_PROP_WINDOW_UIKIT_OPENGL_RESOLVE_FRAMEBUFFER_NUMBER);
        pub const KMSDRM_DEVICE_INDEX = Property.new(.INTEGER, C.SDL_PROP_WINDOW_KMSDRM_DEVICE_INDEX_NUMBER);
        pub const KMSDRM_DRM_FD = Property.new(.INTEGER, C.SDL_PROP_WINDOW_KMSDRM_DRM_FD_NUMBER);
        pub const KMSDRM_GBM_DEVICE = Property.new(.POINTER, C.SDL_PROP_WINDOW_KMSDRM_GBM_DEVICE_POINTER);
        pub const COCOA_WINDOW = Property.new(.POINTER, C.SDL_PROP_WINDOW_COCOA_WINDOW_POINTER);
        pub const COCOA_METAL_VIEW_TAG = Property.new(.INTEGER, C.SDL_PROP_WINDOW_COCOA_METAL_VIEW_TAG_NUMBER);
        pub const OPENVR_OVERLAY = Property.new(.INTEGER, C.SDL_PROP_WINDOW_OPENVR_OVERLAY_ID);
        pub const VIVANTE_DISPLAY = Property.new(.POINTER, C.SDL_PROP_WINDOW_VIVANTE_DISPLAY_POINTER);
        pub const VIVANTE_WINDOW = Property.new(.POINTER, C.SDL_PROP_WINDOW_VIVANTE_WINDOW_POINTER);
        pub const VIVANTE_SURFACE = Property.new(.POINTER, C.SDL_PROP_WINDOW_VIVANTE_SURFACE_POINTER);
        pub const WIN32_HWND = Property.new(.POINTER, C.SDL_PROP_WINDOW_WIN32_HWND_POINTER);
        pub const WIN32_HDC = Property.new(.POINTER, C.SDL_PROP_WINDOW_WIN32_HDC_POINTER);
        pub const WIN32_INSTANCE = Property.new(.POINTER, C.SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER);
        pub const WAYLAND_DISPLAY = Property.new(.POINTER, C.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER);
        pub const WAYLAND_SURFACE = Property.new(.POINTER, C.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER);
        pub const WAYLAND_VIEWPORT = Property.new(.POINTER, C.SDL_PROP_WINDOW_WAYLAND_VIEWPORT_POINTER);
        pub const WAYLAND_EGL_WINDOW = Property.new(.POINTER, C.SDL_PROP_WINDOW_WAYLAND_EGL_WINDOW_POINTER);
        pub const WAYLAND_XDG_SURFACE = Property.new(.POINTER, C.SDL_PROP_WINDOW_WAYLAND_XDG_SURFACE_POINTER);
        pub const WAYLAND_XDG_TOPLEVEL = Property.new(.POINTER, C.SDL_PROP_WINDOW_WAYLAND_XDG_TOPLEVEL_POINTER);
        pub const WAYLAND_XDG_TOPLEVEL_EXPORT_HANDLE = Property.new(.STRING, C.SDL_PROP_WINDOW_WAYLAND_XDG_TOPLEVEL_EXPORT_HANDLE_STRING);
        pub const WAYLAND_XDG_POPUP = Property.new(.POINTER, C.SDL_PROP_WINDOW_WAYLAND_XDG_POPUP_POINTER);
        pub const WAYLAND_XDG_POSITIONER = Property.new(.POINTER, C.SDL_PROP_WINDOW_WAYLAND_XDG_POSITIONER_POINTER);
        pub const X11_DISPLAY = Property.new(.POINTER, C.SDL_PROP_WINDOW_X11_DISPLAY_POINTER);
        pub const X11_SCREEN = Property.new(.INTEGER, C.SDL_PROP_WINDOW_X11_SCREEN_NUMBER);
        pub const X11_WINDOW = Property.new(.INTEGER, C.SDL_PROP_WINDOW_X11_WINDOW_NUMBER);
    };

    pub const TextInputProps = struct {
        pub const TYPE = Property.new(.INTEGER, C.SDL_PROP_TEXTINPUT_TYPE_NUMBER);
        pub const CAPITALIZATION = Property.new(.INTEGER, C.SDL_PROP_TEXTINPUT_CAPITALIZATION_NUMBER);
        pub const AUTOCORRECT = Property.new(.BOOLEAN, C.SDL_PROP_TEXTINPUT_AUTOCORRECT_BOOLEAN);
        pub const MULTILINE = Property.new(.BOOLEAN, C.SDL_PROP_TEXTINPUT_MULTILINE_BOOLEAN);
        pub const ANDROID_INPUTTYPE = Property.new(.INTEGER, C.SDL_PROP_TEXTINPUT_ANDROID_INPUTTYPE_NUMBER);
    };
};

pub const Keyboard = struct {
    //TODO
    // pub extern fn SDL_HasKeyboard() bool;
    // pub extern fn SDL_GetKeyboards(count: [*c]c_int) [*c]SDL_KeyboardID;
    // pub extern fn SDL_GetKeyboardFocus() ?*SDL_Window;
    // pub extern fn SDL_GetKeyboardState(numkeys: [*c]c_int) [*c]const bool;
    // pub extern fn SDL_ResetKeyboard() void;
    // pub extern fn SDL_GetModState() SDL_Keymod;
    // pub extern fn SDL_SetModState(modstate: SDL_Keymod) void;
    // pub extern fn SDL_GetScancodeFromName(name: [*c]const u8) SDL_Scancode;
    // pub extern fn SDL_GetKeyFromName(name: [*c]const u8) SDL_Keycode;
    // pub extern fn SDL_HasScreenKeyboardSupport() bool;
};

pub const TextInputType = enum(C.SDL_TextInputType) {
    TEXT = C.SDL_TEXTINPUT_TYPE_TEXT,
    TEXT_NAME = C.SDL_TEXTINPUT_TYPE_TEXT_NAME,
    TEXT_EMAIL = C.SDL_TEXTINPUT_TYPE_TEXT_EMAIL,
    TEXT_USERNAME = C.SDL_TEXTINPUT_TYPE_TEXT_USERNAME,
    PASSWORD_HIDDEN = C.SDL_TEXTINPUT_TYPE_TEXT_PASSWORD_HIDDEN,
    PASSWORD_VISIBLE = C.SDL_TEXTINPUT_TYPE_TEXT_PASSWORD_VISIBLE,
    NUMBER = C.SDL_TEXTINPUT_TYPE_NUMBER,
    NUMBER_PASSWORD_HIDDEN = C.SDL_TEXTINPUT_TYPE_NUMBER_PASSWORD_HIDDEN,
    NUMBER_PASSWORD_VISIBLE = C.SDL_TEXTINPUT_TYPE_NUMBER_PASSWORD_VISIBLE,

    pub const to_c = c_enum_conversions(TextInputType, C.SDL_TextInputType).to_c;
    pub const from_c = c_enum_conversions(TextInputType, C.SDL_TextInputType).from_c;
};

pub const Capitalization = enum(C.SDL_Capitalization) {
    NONE = C.SDL_CAPITALIZE_NONE,
    SENTENCES = C.SDL_CAPITALIZE_SENTENCES,
    WORDS = C.SDL_CAPITALIZE_WORDS,
    LETTERS = C.SDL_CAPITALIZE_LETTERS,

    pub const to_c = c_enum_conversions(Capitalization, C.SDL_Capitalization).to_c;
    pub const from_c = c_enum_conversions(Capitalization, C.SDL_Capitalization).from_c;
};

pub const FlashMode = enum(C.SDL_FlashOperation) {
    CANCEL = C.SDL_FLASH_CANCEL,
    BRIEFLY = C.SDL_FLASH_BRIEFLY,
    UNTIL_FOCUSED = C.SDL_FLASH_UNTIL_FOCUSED,

    pub const to_c = c_enum_conversions(FlashMode, C.SDL_FlashOperation).to_c;
    pub const from_c = c_enum_conversions(FlashMode, C.SDL_FlashOperation).from_c;
};

pub const WindowHitTestResult = enum(C.SDL_HitTestResult) {
    NORMAL = C.SDL_HITTEST_NORMAL,
    DRAGGABLE = C.SDL_HITTEST_DRAGGABLE,
    RESIZE_TOPLEFT = C.SDL_HITTEST_RESIZE_TOPLEFT,
    RESIZE_TOP = C.SDL_HITTEST_RESIZE_TOP,
    RESIZE_TOPRIGHT = C.SDL_HITTEST_RESIZE_TOPRIGHT,
    RESIZE_RIGHT = C.SDL_HITTEST_RESIZE_RIGHT,
    RESIZE_BOTTOMRIGHT = C.SDL_HITTEST_RESIZE_BOTTOMRIGHT,
    RESIZE_BOTTOM = C.SDL_HITTEST_RESIZE_BOTTOM,
    RESIZE_BOTTOMLEFT = C.SDL_HITTEST_RESIZE_BOTTOMLEFT,
    RESIZE_LEFT = C.SDL_HITTEST_RESIZE_LEFT,

    pub const to_c = c_enum_conversions(WindowHitTestResult, C.SDL_HitTestResult).to_c;
    pub const from_c = c_enum_conversions(WindowHitTestResult, C.SDL_HitTestResult).from_c;
};

pub const WindowHittestFn = fn (window: *Window, test_point: *Vec_c_int, custom_data: ?*anyopaque) callconv(.c) WindowHitTestResult;

pub const VSync = enum(c_int) {
    adaptive = C.SDL_WINDOW_SURFACE_VSYNC_ADAPTIVE,
    disabled = C.SDL_WINDOW_SURFACE_VSYNC_DISABLED,
    _,

    pub fn every_n_frames(n: c_int) VSync {
        return @enumFromInt(n);
    }

    pub const to_c = c_enum_conversions(VSync, c_int).to_c;
    pub const from_c = c_enum_conversions(VSync, c_int).from_c;
};

pub const BorderSizes = extern struct {
    top: c_uint = 0,
    left: c_uint = 0,
    bottom: c_uint = 0,
    right: c_uint = 0,
};

pub const AspectRange = extern struct {
    min: f32 = 0.1,
    max: f32 = 10.0,
};

pub const CreateWindowOptions = struct {
    title: [:0]const u8 = "New Window",
    flags: WindowFlags = WindowFlags{},
    size: Vec_c_int = Vec_c_int.new(800, 600),
};

pub const CreatePopupWindowOptions = extern struct {
    flags: WindowFlags = WindowFlags{},
    offset: Vec_c_int = Vec_c_int.ZERO,
    size: Vec_c_int = Vec_c_int.new(400, 300),
};

pub const WindowsList = extern struct {
    list: []Window,

    pub fn free(self: WindowsList) void {
        Mem.free(self.list.ptr);
    }
};

/// Helper struct for SDL functions that take a `?*DisplayMode` where:
/// - `null` == borderless fullscreen
/// - `*DisplayMode` == exclusive fullscreen using the specified mode
pub const FullscreenMode = extern struct {
    mode: ?*const DisplayMode,

    pub fn borderless() FullscreenMode {
        return FullscreenMode{ .mode = null };
    }
    pub fn exclusive(mode: *DisplayMode) FullscreenMode {
        return FullscreenMode{ .mode = mode };
    }

    pub fn is_borderless(self: FullscreenMode) bool {
        return self.mode == null;
    }
    pub fn is_exclusive(self: FullscreenMode) bool {
        return self.mode != null;
    }
};

pub const WindowICCProfile = opaque {};

pub const DisplayModeList = extern struct {
    modes: []*DisplayMode,

    pub fn free(self: DisplayModeList) void {
        Mem.free(self.modes.ptr);
    }
};

pub const DisplayList = extern struct {
    ids: []DisplayID,

    pub fn free(self: DisplayList) void {
        Mem.free(self.ids.ptr);
    }
};

pub const WindowFlags = Flags(enum(u64) {
    FULLSCREEN = C.SDL_WINDOW_FULLSCREEN,
    OPENGL = C.SDL_WINDOW_OPENGL,
    OCCLUDED = C.SDL_WINDOW_OCCLUDED,
    HIDDEN = C.SDL_WINDOW_HIDDEN,
    BORDERLESS = C.SDL_WINDOW_BORDERLESS,
    RESIZABLE = C.SDL_WINDOW_RESIZABLE,
    MINIMIZED = C.SDL_WINDOW_MINIMIZED,
    MAXIMIZED = C.SDL_WINDOW_MAXIMIZED,
    MOUSE_GRABBED = C.SDL_WINDOW_MOUSE_GRABBED,
    INPUT_FOCUS = C.SDL_WINDOW_INPUT_FOCUS,
    MOUSE_FOCUS = C.SDL_WINDOW_MOUSE_FOCUS,
    EXTERNAL = C.SDL_WINDOW_EXTERNAL,
    MODAL = C.SDL_WINDOW_MODAL,
    HIGH_PIXEL_DENSITY = C.SDL_WINDOW_HIGH_PIXEL_DENSITY,
    MOUSE_CAPTURE = C.SDL_WINDOW_MOUSE_CAPTURE,
    MOUSE_RELATIVE_MODE = C.SDL_WINDOW_MOUSE_RELATIVE_MODE,
    ALWAYS_ON_TOP = C.SDL_WINDOW_ALWAYS_ON_TOP,
    UTILITY = C.SDL_WINDOW_UTILITY,
    TOOLTIP = C.SDL_WINDOW_TOOLTIP,
    POPUP_MENU = C.SDL_WINDOW_POPUP_MENU,
    KEYBOARD_GRABBED = C.SDL_WINDOW_KEYBOARD_GRABBED,
    VULKAN = C.SDL_WINDOW_VULKAN,
    METAL = C.SDL_WINDOW_METAL,
    TRANSPARENT = C.SDL_WINDOW_TRANSPARENT,
    NOT_FOCUSABLE = C.SDL_WINDOW_NOT_FOCUSABLE,
}, enum(u64) {});

/// Helper struct for SDL functions that expect a `?*IRect` where:
/// - `null` == use entire area
/// - `*IRect` == use this rect area
pub const IArea = extern struct {
    rect_ptr: ?*Rect_c_int = null,

    pub inline fn rect(r: *Rect_c_int) IArea {
        return IArea{ .rect_ptr = r };
    }
    pub inline fn entire_area() IArea {
        return ENTIRE_AREA;
    }
    pub const ENTIRE_AREA = IArea{ .rect_ptr = null };

    inline fn to_c(self: *IArea) ?*C.SDL_Rect {
        return @ptrCast(@alignCast(self.rect_ptr));
    }
};

/// Helper struct for SDL functions that expect a `?*FRect` where:
/// - `null` == use entire area
/// - `*FRect` == use this rect area
pub const FArea = extern struct {
    rect_ptr: ?*const Rect_f32 = null,

    pub inline fn rect(r: *const Rect_f32) FArea {
        return FArea{ .rect_ptr = r };
    }
    pub inline fn entire_area() FArea {
        return ENTIRE_AREA;
    }
    pub const ENTIRE_AREA = FArea{ .rect_ptr = null };
};

/// Helper struct for SDL functions that expect both a
/// `f32` ratio and `ScaleMode(u32)` mode
pub const Scale = extern struct {
    ratio: f32 = 1.0,
    mode: ScaleMode = .NEAREST,

    pub inline fn none() Scale {
        return Scale{ .ratio = 1.0, .mode = .NEAREST };
    }
    pub inline fn linear(ratio: f32) Scale {
        return Scale{ .ratio = ratio, .mode = .LINEAR };
    }
    pub inline fn nearest(ratio: f32) Scale {
        return Scale{ .ratio = ratio, .mode = .NEAREST };
    }
};

pub const ColorPalette = opaque {
    pub const to_c_ptr = c_opaque_conversions(ColorPalette, C.SDL_Palette).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(ColorPalette, C.SDL_Palette).from_c_ptr;

    pub fn colors(self: *ColorPalette) []const Color_RGBA_u8 {
        const c = self.to_c_ptr();
        const ptr: ?[*]C.SDL_Color = c.colors;
        if (ptr) |good_ptr| {
            return @as([*]const Color_RGBA_u8, @ptrCast(@alignCast(good_ptr)))[0..c.ncolors];
        }
        return &.{};
    }
    pub fn version(self: *ColorPalette) u32 {
        return self.to_c_ptr().version;
    }
    pub fn refcount(self: *ColorPalette) c_int {
        return self.to_c_ptr().refcount;
    }
    //TODO
    // pub extern fn SDL_CreatePalette(ncolors: c_int) [*c]SDL_Palette;
    // pub extern fn SDL_SetPaletteColors(palette: [*c]SDL_Palette, colors: [*c]const SDL_Color, firstcolor: c_int, ncolors: c_int) bool;
    // pub extern fn SDL_DestroyPalette(palette: [*c]SDL_Palette) void;
};

pub const Colorspace = enum(C.SDL_Colorspace) {
    UNKNOWN = C.SDL_COLORSPACE_UNKNOWN,
    SRGB = C.SDL_COLORSPACE_SRGB,
    SRGB_LINEAR = C.SDL_COLORSPACE_SRGB_LINEAR,
    HDR10 = C.SDL_COLORSPACE_HDR10,
    JPEG = C.SDL_COLORSPACE_JPEG,
    BT601_LIMITED = C.SDL_COLORSPACE_BT601_LIMITED,
    BT601_FULL = C.SDL_COLORSPACE_BT601_FULL,
    BT709_LIMITED = C.SDL_COLORSPACE_BT709_LIMITED,
    BT709_FULL = C.SDL_COLORSPACE_BT709_FULL,
    BT2020_LIMITED = C.SDL_COLORSPACE_BT2020_LIMITED,
    BT2020_FULL = C.SDL_COLORSPACE_BT2020_FULL,
    RGB_DEFAULT = C.SDL_COLORSPACE_RGB_DEFAULT,
    YUV_DEFAULT = C.SDL_COLORSPACE_YUV_DEFAULT,
    _,

    pub const to_c = c_enum_conversions(Colorspace, C.SDL_Colorspace).to_c;
    pub const from_c = c_enum_conversions(Colorspace, C.SDL_Colorspace).from_c;

    pub fn custom(color_type: ColorType, range: ColorRange, primaries: ColorPrimaries, transfer: TransferCharacteristics, matrix: MatrixCoefficients, chroma_loc: ChromaLocation) Colorspace {
        return Colorspace.from_c(C.SDL_DEFINE_COLORSPACE(color_type.to_c(), range.to_c(), primaries.to_c(), transfer.to_c(), matrix.to_c(), chroma_loc.to_c()));
    }

    pub fn get_type(self: Colorspace) ColorType {
        return ColorType.from_c(C.SDL_COLORSPACETYPE(self.to_c()));
    }
    pub fn get_range(self: Colorspace) ColorRange {
        return ColorRange.from_c(C.SDL_COLORSPACERANGE(self.to_c()));
    }
    pub fn get_chroma(self: Colorspace) ChromaLocation {
        return ChromaLocation.from_c(C.SDL_COLORSPACERANGE(self.to_c()));
    }
    pub fn get_primaries(self: Colorspace) ColorPrimaries {
        return ColorPrimaries.from_c(C.SDL_COLORSPACEPRIMARIES(self.to_c()));
    }
    pub fn get_transfer(self: Colorspace) TransferCharacteristics {
        return TransferCharacteristics.from_c(C.SDL_COLORSPACETRANSFER(self.to_c()));
    }
    pub fn get_matrix(self: Colorspace) MatrixCoefficients {
        return MatrixCoefficients.from_c(C.SDL_COLORSPACEMATRIX(self.to_c()));
    }

    pub fn matrix_is_bt601(self: Colorspace) bool {
        return C.SDL_ISCOLORSPACE_MATRIX_BT601(self.to_c());
    }
    pub fn matrix_is_bt709(self: Colorspace) bool {
        return C.SDL_ISCOLORSPACE_MATRIX_BT709(self.to_c());
    }
    pub fn matrix_is_bt2020_ncl(self: Colorspace) bool {
        return C.SDL_ISCOLORSPACE_MATRIX_BT2020_NCL(self.to_c());
    }
    pub fn has_limited_range(self: Colorspace) bool {
        return C.SDL_ISCOLORSPACE_LIMITED_RANGE(self.to_c());
    }
    pub fn has_full_range(self: Colorspace) bool {
        return C.SDL_ISCOLORSPACE_FULL_RANGE(self.to_c());
    }
};

pub const MetalLayer = opaque {};
pub const MetalCommandEncoder = opaque {};

pub const IndexType = enum(c_int) {
    U8 = 1,
    U16 = 2,
    U32 = 4,

    pub const to_c = c_enum_conversions(IndexType, c_int).to_c;
    pub const from_c = c_enum_conversions(IndexType, c_int).from_c;
};

pub const AppResult = enum(C.SDL_AppResult) {
    CONTINUE = C.SDL_APP_CONTINUE,
    CLOSE_NORMAL = C.SDL_APP_SUCCESS,
    CLOSE_ERROR = C.SDL_APP_FAILURE,

    pub const to_c = c_enum_conversions(AppResult, C.SDL_AppResult).to_c;
    pub const from_c = c_enum_conversions(AppResult, C.SDL_AppResult).from_c;
};

pub const LogicalPresentationMode = enum(C.SDL_RendererLogicalPresentation) {
    DISABLED = C.SDL_LOGICAL_PRESENTATION_DISABLED,
    STRETCH = C.SDL_LOGICAL_PRESENTATION_STRETCH,
    LETTERBOX = C.SDL_LOGICAL_PRESENTATION_LETTERBOX,
    OVERSCAN = C.SDL_LOGICAL_PRESENTATION_OVERSCAN,
    INTEGER_SCALE = C.SDL_LOGICAL_PRESENTATION_INTEGER_SCALE,

    pub const to_c = c_enum_conversions(AppResult, C.SDL_RendererLogicalPresentation).to_c;
    pub const from_c = c_enum_conversions(AppResult, C.SDL_RendererLogicalPresentation).from_c;
};

pub const LogicalPresentation = extern struct {
    size: Vec_c_int = Vec_c_int{},
    mode: LogicalPresentationMode = .DISABLED,

    pub fn new(mode: LogicalPresentationMode, size: Vec_c_int) LogicalPresentation {
        return LogicalPresentation{
            .mode = mode,
            .size = size,
        };
    }
    pub fn new_xy(mode: LogicalPresentationMode, x: c_int, y: c_int) LogicalPresentation {
        return LogicalPresentation{
            .mode = mode,
            .size = Vec_c_int.new(x, y),
        };
    }
};

pub const ScaleMode = enum(c_int) {
    INVALID = C.SDL_SCALEMODE_INVALID,
    NEAREST = C.SDL_SCALEMODE_NEAREST,
    LINEAR = C.SDL_SCALEMODE_LINEAR,

    inline fn to_c(self: ScaleMode) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) ScaleMode {
        return @enumFromInt(val);
    }
};

pub const Audio = struct {
    pub fn get_current_audio_driver() Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetCurrentAudioDriver());
    }
    pub fn get_num_audio_drivers() c_int {
        return C.SDL_GetNumAudioDrivers();
    }
    pub fn get_audio_driver(index: c_int) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetAudioDriver(index));
    }
    //TODO
    // pub extern fn SDL_LoadWAV(path: [*c]const u8, spec: [*c]SDL_AudioSpec, audio_buf: [*c][*c]Uint8, audio_len: [*c]Uint32) bool;
    // pub extern fn SDL_MixAudio(dst: [*c]Uint8, src: [*c]const Uint8, format: SDL_AudioFormat, len: Uint32, volume: f32) bool;
    // pub extern fn SDL_ConvertAudioSamples(src_spec: [*c]const SDL_AudioSpec, src_data: [*c]const Uint8, src_len: c_int, dst_spec: [*c]const SDL_AudioSpec, dst_data: [*c][*c]Uint8, dst_len: [*c]c_int) bool;
    // pub extern fn SDL_GetAudioFormatName(format: SDL_AudioFormat) [*c]const u8;
    // pub extern fn SDL_GetSilenceValueForFormat(format: SDL_AudioFormat) c_int;
};

pub const ColorPrimaries = enum(c_uint) {
    UNKNOWN = C.SDL_COLOR_PRIMARIES_UNKNOWN,
    BT709 = C.SDL_COLOR_PRIMARIES_BT709,
    UNSPECIFIED = C.SDL_COLOR_PRIMARIES_UNSPECIFIED,
    BT470M = C.SDL_COLOR_PRIMARIES_BT470M,
    BT470BG = C.SDL_COLOR_PRIMARIES_BT470BG,
    BT601 = C.SDL_COLOR_PRIMARIES_BT601,
    SMPTE240 = C.SDL_COLOR_PRIMARIES_SMPTE240,
    GENERIC_FILM = C.SDL_COLOR_PRIMARIES_GENERIC_FILM,
    BT2020 = C.SDL_COLOR_PRIMARIES_BT2020,
    XYZ = C.SDL_COLOR_PRIMARIES_XYZ,
    SMPTE431 = C.SDL_COLOR_PRIMARIES_SMPTE431,
    SMPTE432 = C.SDL_COLOR_PRIMARIES_SMPTE432,
    EBU3213 = C.SDL_COLOR_PRIMARIES_EBU3213,
    CUSTOM = C.SDL_COLOR_PRIMARIES_CUSTOM,

    pub const to_c = c_enum_conversions(ColorPrimaries, c_uint).to_c;
    pub const from_c = c_enum_conversions(ColorPrimaries, c_uint).from_c;
};

pub const TransferCharacteristics = enum(C.SDL_TransferCharacteristics) {
    UNKNOWN = C.SDL_TRANSFER_CHARACTERISTICS_UNKNOWN,
    BT709 = C.SDL_TRANSFER_CHARACTERISTICS_BT709,
    UNSPECIFIED = C.SDL_TRANSFER_CHARACTERISTICS_UNSPECIFIED,
    GAMMA22 = C.SDL_TRANSFER_CHARACTERISTICS_GAMMA22,
    GAMMA28 = C.SDL_TRANSFER_CHARACTERISTICS_GAMMA28,
    BT601 = C.SDL_TRANSFER_CHARACTERISTICS_BT601,
    SMPTE240 = C.SDL_TRANSFER_CHARACTERISTICS_SMPTE240,
    LINEAR = C.SDL_TRANSFER_CHARACTERISTICS_LINEAR,
    LOG100 = C.SDL_TRANSFER_CHARACTERISTICS_LOG100,
    LOG100_SQRT10 = C.SDL_TRANSFER_CHARACTERISTICS_LOG100_SQRT10,
    IEC61966 = C.SDL_TRANSFER_CHARACTERISTICS_IEC61966,
    BT1361 = C.SDL_TRANSFER_CHARACTERISTICS_BT1361,
    SRGB = C.SDL_TRANSFER_CHARACTERISTICS_SRGB,
    BT2020_10BIT = C.SDL_TRANSFER_CHARACTERISTICS_BT2020_10BIT,
    BT2020_12BIT = C.SDL_TRANSFER_CHARACTERISTICS_BT2020_12BIT,
    PQ = C.SDL_TRANSFER_CHARACTERISTICS_PQ,
    SMPTE428 = C.SDL_TRANSFER_CHARACTERISTICS_SMPTE428,
    HLG = C.SDL_TRANSFER_CHARACTERISTICS_HLG,
    CUSTOM = C.SDL_TRANSFER_CHARACTERISTICS_CUSTOM,

    pub const to_c = c_enum_conversions(TransferCharacteristics, C.SDL_TransferCharacteristics).to_c;
    pub const from_c = c_enum_conversions(TransferCharacteristics, C.SDL_TransferCharacteristics).from_c;
};

pub const MatrixCoefficients = enum(C.SDL_MatrixCoefficients) {
    IDENTITY = C.SDL_MATRIX_COEFFICIENTS_IDENTITY,
    BT709 = C.SDL_MATRIX_COEFFICIENTS_BT709,
    UNSPECIFIED = C.SDL_MATRIX_COEFFICIENTS_UNSPECIFIED,
    FCC = C.SDL_MATRIX_COEFFICIENTS_FCC,
    BT470BG = C.SDL_MATRIX_COEFFICIENTS_BT470BG,
    BT601 = C.SDL_MATRIX_COEFFICIENTS_BT601,
    SMPTE240 = C.SDL_MATRIX_COEFFICIENTS_SMPTE240,
    YCGCO = C.SDL_MATRIX_COEFFICIENTS_YCGCO,
    BT2020_NCL = C.SDL_MATRIX_COEFFICIENTS_BT2020_NCL,
    BT2020_CL = C.SDL_MATRIX_COEFFICIENTS_BT2020_CL,
    SMPTE2085 = C.SDL_MATRIX_COEFFICIENTS_SMPTE2085,
    CHROMA_DERIVED_NCL = C.SDL_MATRIX_COEFFICIENTS_CHROMA_DERIVED_NCL,
    CHROMA_DERIVED_CL = C.SDL_MATRIX_COEFFICIENTS_CHROMA_DERIVED_CL,
    ICTCP = C.SDL_MATRIX_COEFFICIENTS_ICTCP,
    CUSTOM = C.SDL_MATRIX_COEFFICIENTS_CUSTOM,

    pub const to_c = c_enum_conversions(MatrixCoefficients, C.SDL_MatrixCoefficients).to_c;
    pub const from_c = c_enum_conversions(MatrixCoefficients, C.SDL_MatrixCoefficients).from_c;
};

pub const ChromaLocation = enum(C.SDL_ChromaLocation) {
    NONE = C.SDL_CHROMA_LOCATION_NONE,
    LEFT = C.SDL_CHROMA_LOCATION_LEFT,
    CENTER = C.SDL_CHROMA_LOCATION_CENTER,
    TOPLEFT = C.SDL_CHROMA_LOCATION_TOPLEFT,

    pub const to_c = c_enum_conversions(ChromaLocation, C.SDL_ChromaLocation).to_c;
    pub const from_c = c_enum_conversions(ChromaLocation, C.SDL_ChromaLocation).from_c;
};

pub const PixelFormatDetails = extern struct {
    format: PixelFormat = .UNKNOWN,
    bits_per_pixel: u8 = 0,
    bytes_per_pixel: u8 = 0,
    padding: [2]u8 = 0,
    Rmask: u32 = 0,
    Gmask: u32 = 0,
    Bmask: u32 = 0,
    Amask: u32 = 0,
    Rbits: u8 = 0,
    Gbits: u8 = 0,
    Bbits: u8 = 0,
    Abits: u8 = 0,
    Rshift: u8 = 0,
    Gshift: u8 = 0,
    Bshift: u8 = 0,
    Ashift: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(PixelFormatDetails, C.SDL_PixelFormatDetails).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(PixelFormatDetails, C.SDL_PixelFormatDetails).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(PixelFormatDetails, C.SDL_PixelFormatDetails).to_c;
    pub const from_c = c_non_opaque_conversions(PixelFormatDetails, C.SDL_PixelFormatDetails).from_c;

    //TODO
    // pub extern fn SDL_MapRGB(format: [*c]const SDL_PixelFormatDetails, palette: [*c]const SDL_Palette, r: Uint8, g: Uint8, b: Uint8) Uint32;
    // pub extern fn SDL_MapRGBA(format: [*c]const SDL_PixelFormatDetails, palette: [*c]const SDL_Palette, r: Uint8, g: Uint8, b: Uint8, a: Uint8) Uint32;
    // pub extern fn SDL_GetRGB(pixel: Uint32, format: [*c]const SDL_PixelFormatDetails, palette: [*c]const SDL_Palette, r: [*c]Uint8, g: [*c]Uint8, b: [*c]Uint8) void;
    // pub extern fn SDL_GetRGBA(pixel: Uint32, format: [*c]const SDL_PixelFormatDetails, palette: [*c]const SDL_Palette, r: [*c]Uint8, g: [*c]Uint8, b: [*c]Uint8, a: [*c]Uint8) void;
};

pub const AudioSpec = extern struct {
    format: AudioFormat = .UNKNOWN,
    channels: c_int = 0,
    freq: c_int = 0,

    pub const to_c_ptr = c_non_opaque_conversions(AudioSpec, C.SDL_AudioSpec).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(AudioSpec, C.SDL_AudioSpec).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(AudioSpec, C.SDL_AudioSpec).to_c;
    pub const from_c = c_non_opaque_conversions(AudioSpec, C.SDL_AudioSpec).from_c;

    pub fn frame_size(self: *AudioSpec) c_int {
        return @as(c_int, @intCast(self.format.byte_size())) * self.channels;
    }
};

pub const AudioPostmixCallback = fn (userdata: ?*anyopaque, aduio_spec: ?*C.SDL_AudioSpec, samples_ptr: ?[*]f32, samples_len: c_int) callconv(.c) void;

pub const AudioDeviceID = extern struct {
    id: u32 = 0,

    pub const DEFAULT_PLAYBACK_DEVICE = AudioDeviceID{ .id = C.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK };
    pub const DEFAULT_RECORDING_DEVICE = AudioDeviceID{ .id = C.SDL_AUDIO_DEVICE_DEFAULT_RECORDING };
    pub inline fn default_playback_device() AudioDeviceID {
        return DEFAULT_PLAYBACK_DEVICE;
    }
    pub inline fn default_recording_device() AudioDeviceID {
        return DEFAULT_RECORDING_DEVICE;
    }

    pub fn is_null(self: AudioDeviceID) bool {
        return self.id == 0;
    }
    pub fn get_all_playback_devices() Error!AudioDeviceIDList {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_null_err([*]AudioDeviceID, C.SDL_GetAudioPlaybackDevices(&len));
        return AudioDeviceIDList{ .list = ptr[0..len] };
    }
    pub fn get_all_recording_devices() Error!AudioDeviceIDList {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_null_err([*]AudioDeviceID, C.SDL_GetAudioRecordingDevices(&len));
        return AudioDeviceIDList{ .list = ptr[0..len] };
    }
    pub fn get_name(self: AudioDeviceID) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetAudioDeviceName(self.id));
    }
    pub fn get_format(self: AudioDeviceID) Error!AudioDeviceFormat {
        var fmt: AudioDeviceFormat = undefined;
        try ok_or_fail_err(C.SDL_GetAudioDeviceFormat(self.id, @ptrCast(@alignCast(&fmt.spec)), &fmt.sample_frames_len));
        return fmt;
    }
    pub fn get_channel_map(self: AudioDeviceID) Error!AudioDeviceFormat {
        var len: c_int = 0;
        const ptr = ptr_cast_or_null_err([*]c_int, C.SDL_GetAudioDeviceChannelMap(self.id, &len));
        return AudioChannelMap{
            .map = ptr[0..len],
        };
    }
    pub fn open_device(self: AudioDeviceID, spec_request: AudioSpecRequest) Error!AudioDeviceID {
        return AudioDeviceID{ .id = try nonzero_or_null_err(C.SDL_OpenAudioDevice(self.id, @ptrCast(@alignCast(spec_request.spec_ptr)))) };
    }
    pub fn is_physical(self: AudioDeviceID) bool {
        return C.SDL_IsAudioDevicePhysical(self.id);
    }
    pub fn is_playback_device(self: AudioDeviceID) bool {
        return C.SDL_IsAudioDevicePlayback(self.id);
    }
    pub fn is_recording_device(self: AudioDeviceID) bool {
        return !C.SDL_IsAudioDevicePlayback(self.id);
    }
    pub fn pause_operation(self: AudioDeviceID) Error!void {
        return ok_or_fail_err(C.SDL_PauseAudioDevice(self.id));
    }
    pub fn resume_operation(self: AudioDeviceID) Error!void {
        return ok_or_fail_err(C.SDL_ResumeAudioDevice(self.id));
    }
    pub fn is_paused(self: AudioDeviceID) bool {
        return C.SDL_AudioDevicePaused(self.id);
    }
    pub fn get_gain(self: AudioDeviceID) f32 {
        return C.SDL_GetAudioDeviceGain(self.id);
    }
    pub fn set_gain(self: AudioDeviceID, gain: f32) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioDeviceGain(self.id, gain));
    }
    pub fn close(self: AudioDeviceID) void {
        C.SDL_CloseAudioDevice(self.id);
    }
    pub fn bind_audio_stream(self: AudioDeviceID, audio_stream: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_BindAudioStream(self.id, audio_stream.to_c()));
    }
    pub fn bind_many_audio_streams(self: AudioDeviceID, audio_streams: []*AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_BindAudioStreams(self.id, @ptrCast(@alignCast(audio_streams.ptr)), @intCast(audio_streams.len)));
    }
    pub fn open_new_audio_stream(self: AudioDeviceID, spec: AudioSpec, callback: ?*AudioStreamCallback, userdata: ?*anyopaque) Error!*AudioStream {
        return ptr_cast_or_fail_err(*AudioStream, C.SDL_OpenAudioDeviceStream(self.id, spec.to_c(), @ptrCast(@alignCast(callback)), userdata));
    }
    pub fn set_postmix_callback(self: AudioDeviceID, postmix_callback: *const AudioPostmixCallback, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioPostmixCallback(self.id, postmix_callback, userdata));
    }
};

/// Helper struct for SDL functions that require a `?*AudioSpec` where:
/// - `null` == use default for device
/// - `*AudioSpec` == use specific spec
pub const AudioSpecRequest = extern struct {
    spec_ptr: ?*AudioSpec,

    pub fn use_default() AudioSpecRequest {
        return AudioSpecRequest{ .spec_ptr = null };
    }
    pub fn spec(spec_: *AudioSpec) AudioSpecRequest {
        return AudioSpecRequest{ .spec_ptr = spec_ };
    }
};

pub const AudioDeviceFormat = extern struct {
    spec: AudioSpec,
    sample_frames_len: c_int,
};

pub const AudioChannelMap = extern struct {
    map: []c_int,

    pub fn free(self: *AudioChannelMap) void {
        Mem.free(self.map.ptr);
    }
};

pub const AudioDeviceIDList = extern struct {
    list: []AudioDeviceID,

    pub fn free(self: AudioDeviceIDList) void {
        Mem.free(self.list.ptr);
    }
};

pub const AudioStream = opaque {
    fn to_c(self: *AudioStream) *C.SDL_AudioStream {
        return @ptrCast(@alignCast(self));
    }
    pub fn unbind_streams(streams: []*AudioStream) void {
        C.SDL_UnbindAudioStreams(@ptrCast(@alignCast(streams.ptr)), @intCast(streams.len));
    }
    pub fn unbind(self: *AudioStream) void {
        C.SDL_UnbindAudioStream(self.to_c());
    }
    pub fn get_device(self: *AudioStream) Error!AudioDeviceID {
        return AudioDeviceID{ .id = try nonzero_or_null_err(C.SDL_GetAudioStreamDevice(self.to_c())) };
    }
    pub fn create(format: AudioStreamFormat) Error!*AudioStream {
        return ptr_cast_or_fail_err(*AudioStream, C.SDL_CreateAudioStream(@ptrCast(@alignCast(format.input_spec)), @ptrCast(@alignCast(format.output_spec))));
    }
    pub fn get_properties(self: *AudioStream) Error!PropertiesID {
        return PropertiesID{ .id = try nonzero_or_null_err(C.SDL_GetAudioStreamProperties(self.to_c())) };
    }
    pub fn get_format(self: *AudioStream) Error!AudioStreamFormat {
        var fmt: AudioStreamFormat = undefined;
        try ok_or_fail_err(C.SDL_GetAudioStreamFormat(self.to_c(), @ptrCast(@alignCast(&fmt.input_spec)), @ptrCast(@alignCast(&fmt.output_spec))));
        return fmt;
    }
    pub fn set_format(self: *AudioStream, format: AudioStreamFormat) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamFormat(self.to_c(), @ptrCast(@alignCast(format.input_spec)), @ptrCast(@alignCast(format.output_spec))));
    }
    pub fn get_frequency_ratio(self: *AudioStream) f32 {
        return C.SDL_GetAudioStreamFrequencyRatio(self.to_c());
    }
    pub fn set_frequency_ratio(self: *AudioStream, freq_ratio: f32) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamFrequencyRatio(self.to_c(), freq_ratio));
    }
    pub fn get_gain(self: *AudioStream) f32 {
        return C.SDL_GetAudioStreamGain(self.to_c());
    }
    pub fn set_gain(self: *AudioStream, gain: f32) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamGain(self.to_c(), gain));
    }
    pub fn get_input_channel_map(self: *AudioStream) Error!AudioChannelMap {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_null_err([*]c_int, C.SDL_GetAudioStreamInputChannelMap(self.to_c(), &len));
        return AudioChannelMap{ .map = ptr[0..len] };
    }
    pub fn get_output_channel_map(self: *AudioStream) Error!AudioChannelMap {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_null_err([*]c_int, C.SDL_GetAudioStreamOutputChannelMap(self.to_c(), &len));
        return AudioChannelMap{ .map = ptr[0..len] };
    }
    pub fn set_input_channel_map(self: *AudioStream, channel_map: AudioChannelMap) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamInputChannelMap(self.to_c(), channel_map.map.ptr, @intCast(channel_map.map.len)));
    }
    pub fn set_output_channel_map(self: *AudioStream, channel_map: AudioChannelMap) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamOutputChannelMap(self.to_c(), channel_map.map.ptr, @intCast(channel_map.map.len)));
    }
    pub fn put_in_audio_data(self: *AudioStream, data: []const u8) Error!void {
        return ok_or_fail_err(C.SDL_PutAudioStreamData(self.to_c(), data.ptr, @intCast(data.len)));
    }
    pub fn take_out_audio_data(self: *AudioStream, dst_buffer: []u8) Error!void {
        return greater_than_or_equal_to_zero_or_fail_err(C.SDL_PutAudioStreamData(self.to_c(), dst_buffer.ptr, @intCast(dst_buffer.len)));
    }
    pub fn get_bytes_available_to_take_out(self: *AudioStream) Error!c_int {
        return greater_than_or_equal_to_zero_or_fail_err(C.SDL_GetAudioStreamAvailable(self.to_c()));
    }
    pub fn get_bytes_queued_for_take_out(self: *AudioStream) Error!c_int {
        return greater_than_or_equal_to_zero_or_fail_err(C.SDL_GetAudioStreamQueued(self.to_c()));
    }
    pub fn flush(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_FlushAudioStream(self.to_c()));
    }
    pub fn clear(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_ClearAudioStream(self.to_c()));
    }
    pub fn pause_device(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_PauseAudioStreamDevice(self.to_c()));
    }
    pub fn resume_device(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_ResumeAudioStreamDevice(self.to_c()));
    }
    pub fn is_device_paused(self: *AudioStream) bool {
        return C.SDL_AudioStreamDevicePaused(self.to_c());
    }
    pub fn lock(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_LockAudioStream(self.to_c()));
    }
    pub fn unlock(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_UnlockAudioStream(self.to_c()));
    }
    pub fn set_take_out_callback(self: *AudioStream, callback: *AudioStreamCallback, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamGetCallback(self.to_c(), @ptrCast(@alignCast(callback)), userdata));
    }
    pub fn clear_take_out_callback(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamGetCallback(self.to_c(), null, null));
    }
    pub fn set_put_in_callback(self: *AudioStream, callback: *AudioStreamCallback, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamPutCallback(self.to_c(), @ptrCast(@alignCast(callback)), userdata));
    }
    pub fn clear_put_in_callback(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamPutCallback(self.to_c(), null, null));
    }
    pub fn destroy(self: *AudioStream) void {
        C.SDL_DestroyAudioStream(self.to_c());
    }
};

pub const AudioStreamCallback = fn (userdata: ?*anyopaque, stream: *AudioStream, additional_needed: c_int, total_available: c_int) callconv(.c) void;

/// Helper struct for SDL functions that expect an input `*AudioSpec` and
/// _optional_ output `?*AudioSpec` where for the output spec:
/// - `null` == same as input
/// - `*AudioSpec` == convert from the input spec to the output spec
pub const AudioStreamFormat = extern struct {
    input_spec: *AudioSpec,
    output_spec: ?*AudioSpec,

    pub inline fn same_input_and_output(spec: *AudioSpec) AudioStreamFormat {
        return AudioStreamFormat{
            .input_spec = spec,
            .output_spec = null,
        };
    }

    pub inline fn convert_input_to_output(input: *AudioSpec, output: *AudioSpec) AudioStreamFormat {
        return AudioStreamFormat{
            .input_spec = input,
            .output_spec = output,
        };
    }
};

pub const GamepadType = enum(C.SDL_GamepadType) {
    UNKNOWN = C.SDL_GAMEPAD_TYPE_UNKNOWN,
    STANDARD = C.SDL_GAMEPAD_TYPE_STANDARD,
    XBOX360 = C.SDL_GAMEPAD_TYPE_XBOX360,
    XBOXONE = C.SDL_GAMEPAD_TYPE_XBOXONE,
    PS3 = C.SDL_GAMEPAD_TYPE_PS3,
    PS4 = C.SDL_GAMEPAD_TYPE_PS4,
    PS5 = C.SDL_GAMEPAD_TYPE_PS5,
    NINTENDO_SWITCH_PRO = C.SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_PRO,
    NINTENDO_SWITCH_JOYCON_LEFT = C.SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_LEFT,
    NINTENDO_SWITCH_JOYCON_RIGHT = C.SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT,
    NINTENDO_SWITCH_JOYCON_PAIR = C.SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_PAIR,

    pub const COUNT: C.SDL_GamepadType = C.SDL_GAMEPAD_TYPE_COUNT;

    pub const to_c = c_enum_conversions(GamepadType, C.SDL_GamepadType).to_c;
    pub const from_c = c_enum_conversions(GamepadType, C.SDL_GamepadType).from_c;

    pub fn from_string(str: [*:0]const u8) GamepadType {
        return GamepadType.from_c(C.SDL_GetGamepadTypeFromString(str));
    }
    pub fn to_string(self: GamepadType) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGamepadStringForType(self.to_c()));
    }

    pub fn get_label_for_face_button(self: GamepadType, button: GamepadButton) GamepadFaceButtonLabel {
        return GamepadFaceButtonLabel.from_c(C.SDL_GetGamepadButtonLabelForType(self.to_c(), button.to_c()));
    }
};

pub const GamepadButton = enum(u8) {
    SOUTH = C.SDL_GAMEPAD_BUTTON_SOUTH,
    EAST = C.SDL_GAMEPAD_BUTTON_EAST,
    WEST = C.SDL_GAMEPAD_BUTTON_WEST,
    NORTH = C.SDL_GAMEPAD_BUTTON_NORTH,
    BACK = C.SDL_GAMEPAD_BUTTON_BACK,
    GUIDE = C.SDL_GAMEPAD_BUTTON_GUIDE,
    START = C.SDL_GAMEPAD_BUTTON_START,
    LEFT_STICK = C.SDL_GAMEPAD_BUTTON_LEFT_STICK,
    RIGHT_STICK = C.SDL_GAMEPAD_BUTTON_RIGHT_STICK,
    LEFT_SHOULDER = C.SDL_GAMEPAD_BUTTON_LEFT_SHOULDER,
    RIGHT_SHOULDER = C.SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER,
    DPAD_UP = C.SDL_GAMEPAD_BUTTON_DPAD_UP,
    DPAD_DOWN = C.SDL_GAMEPAD_BUTTON_DPAD_DOWN,
    DPAD_LEFT = C.SDL_GAMEPAD_BUTTON_DPAD_LEFT,
    DPAD_RIGHT = C.SDL_GAMEPAD_BUTTON_DPAD_RIGHT,
    MISC1 = C.SDL_GAMEPAD_BUTTON_MISC1,
    RIGHT_PADDLE1 = C.SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1,
    LEFT_PADDLE1 = C.SDL_GAMEPAD_BUTTON_LEFT_PADDLE1,
    RIGHT_PADDLE2 = C.SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2,
    LEFT_PADDLE2 = C.SDL_GAMEPAD_BUTTON_LEFT_PADDLE2,
    TOUCHPAD = C.SDL_GAMEPAD_BUTTON_TOUCHPAD,
    MISC2 = C.SDL_GAMEPAD_BUTTON_MISC2,
    MISC3 = C.SDL_GAMEPAD_BUTTON_MISC3,
    MISC4 = C.SDL_GAMEPAD_BUTTON_MISC4,
    MISC5 = C.SDL_GAMEPAD_BUTTON_MISC5,
    MISC6 = C.SDL_GAMEPAD_BUTTON_MISC6,
    _,

    pub const COUNT: u8 = C.SDL_GAMEPAD_BUTTON_COUNT;

    pub inline fn from_int(val: anytype) GamepadButton {
        return @enumFromInt(@as(u8, @intCast(val)));
    }

    pub const to_c = c_enum_conversions(GamepadButton, u8).to_c;
    pub const from_c = c_enum_conversions(GamepadButton, u8).from_c;

    pub fn from_string(str: [*:0]const u8) GamepadButton {
        return GamepadButton.from_c(C.SDL_GetGamepadButtonFromString(str));
    }
    pub fn to_string(self: GamepadButton) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGamepadStringForButton(self.to_c()));
    }
};

pub const GamepadFaceButtonLabel = enum(c_uint) {
    UNKNOWN = C.SDL_GAMEPAD_BUTTON_LABEL_UNKNOWN,
    A = C.SDL_GAMEPAD_BUTTON_LABEL_A,
    B = C.SDL_GAMEPAD_BUTTON_LABEL_B,
    X = C.SDL_GAMEPAD_BUTTON_LABEL_X,
    Y = C.SDL_GAMEPAD_BUTTON_LABEL_Y,
    CROSS = C.SDL_GAMEPAD_BUTTON_LABEL_CROSS,
    CIRCLE = C.SDL_GAMEPAD_BUTTON_LABEL_CIRCLE,
    SQUARE = C.SDL_GAMEPAD_BUTTON_LABEL_SQUARE,
    TRIANGLE = C.SDL_GAMEPAD_BUTTON_LABEL_TRIANGLE,

    pub const to_c = c_enum_conversions(GamepadFaceButtonLabel, c_uint).to_c;
    pub const from_c = c_enum_conversions(GamepadFaceButtonLabel, c_uint).from_c;
};

pub const GamepadAxis = enum(u8) {
    LEFTX = C.SDL_GAMEPAD_AXIS_LEFTX,
    LEFTY = C.SDL_GAMEPAD_AXIS_LEFTY,
    RIGHTX = C.SDL_GAMEPAD_AXIS_RIGHTX,
    RIGHTY = C.SDL_GAMEPAD_AXIS_RIGHTY,
    LEFT_TRIGGER = C.SDL_GAMEPAD_AXIS_LEFT_TRIGGER,
    RIGHT_TRIGGER = C.SDL_GAMEPAD_AXIS_RIGHT_TRIGGER,

    pub const COUNT: u8 = C.SDL_GAMEPAD_AXIS_COUNT;

    pub const to_c = c_enum_conversions(GamepadAxis, u8).to_c;
    pub const from_c = c_enum_conversions(GamepadAxis, u8).from_c;

    pub fn from_string(str: [*:0]const u8) GamepadAxis {
        return GamepadAxis.from_c(C.SDL_GetGamepadAxisFromString(str));
    }
    pub fn to_string(self: GamepadAxis) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGamepadStringForAxis(self.to_c()));
    }
};

pub const GamepadBindingType = enum(c_uint) {
    NONE = C.SDL_GAMEPAD_BINDTYPE_NONE,
    BUTTON = C.SDL_GAMEPAD_BINDTYPE_BUTTON,
    AXIS = C.SDL_GAMEPAD_BINDTYPE_AXIS,
    HAT = C.SDL_GAMEPAD_BINDTYPE_HAT,

    pub const to_c = c_enum_conversions(GamepadBindingType, c_uint).to_c;
    pub const from_c = c_enum_conversions(GamepadBindingType, c_uint).from_c;
};

pub const StorageInterface = extern struct {
    version: C.Uint32 = @sizeOf(*StorageInterface),
    close: ?*const fn (?*anyopaque) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque) callconv(.c) bool),
    ready: ?*const fn (?*anyopaque) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque) callconv(.c) bool),
    enumerate: ?*const fn (?*anyopaque, [*c]const u8, C.SDL_EnumerateDirectoryCallback, ?*anyopaque) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, C.SDL_EnumerateDirectoryCallback, ?*anyopaque) callconv(.c) bool),
    info: ?*const fn (?*anyopaque, [*c]const u8, [*c]C.SDL_PathInfo) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, [*c]C.SDL_PathInfo) callconv(.c) bool),
    read_file: ?*const fn (?*anyopaque, [*c]const u8, ?*anyopaque, C.Uint64) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, ?*anyopaque, C.Uint64) callconv(.c) bool),
    write_file: ?*const fn (?*anyopaque, [*c]const u8, ?*const anyopaque, C.Uint64) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, ?*const anyopaque, C.Uint64) callconv(.c) bool),
    mkdir: ?*const fn (?*anyopaque, [*c]const u8) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8) callconv(.c) bool),
    remove: ?*const fn (?*anyopaque, [*c]const u8) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8) callconv(.c) bool),
    rename: ?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.c) bool),
    copy: ?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.c) bool),
    space_remaining: ?*const fn (?*anyopaque) callconv(.c) C.Uint64 = @import("std").mem.zeroes(?*const fn (?*anyopaque) callconv(.c) C.Uint64),
};

pub const Storage = opaque {
    pub const to_c_ptr = c_opaque_conversions(Storage, C.SDL_Storage).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Storage, C.SDL_Storage).from_c_ptr;
    pub fn open_app_readonly_storage_folder(override: [:0]const u8, properties: PropertiesID) Error!*Storage {
        return ptr_cast_or_fail_err(*Storage, C.SDL_OpenTitleStorage(override.ptr, properties));
    }
    pub fn open_user_storage_folder(org_name: [:0]const u8, app_name: [:0]const u8, properties: PropertiesID) Error!*Storage {
        return ptr_cast_or_fail_err(*Storage, C.SDL_OpenUserStorage(org_name.ptr, app_name.ptr, properties.id));
    }
    pub fn open_filesystem(path: [:0]const u8) Error!*Storage {
        return ptr_cast_or_fail_err(*Storage, C.SDL_OpenFileStorage(path.ptr));
    }
    pub fn open_storage_with_custom_interface(iface: StorageInterface, userdata: ?*anyopaque) Error!*Storage {
        return ptr_cast_or_fail_err(*Storage, C.SDL_OpenStorage(@ptrCast(@alignCast(&iface)), userdata));
    }
    pub fn close(self: *Storage) Error!void {
        return ok_or_fail_err(C.SDL_CloseStorage(self.to_c_ptr()));
    }
    pub fn is_ready(self: *Storage) bool {
        return C.SDL_StorageReady(self.to_c_ptr());
    }
    pub fn get_file_size(self: *Storage, sub_path: [:0]const u8) Error!u64 {
        var size: u64 = 0;
        try ok_or_null_err(C.SDL_GetStorageFileSize(self.to_c_ptr(), sub_path.ptr, &size));
        return size;
    }
    pub fn read_file_into_buffer(self: *Storage, sub_path: [:0]const u8, buffer: []u8) Error!void {
        try ok_or_fail_err(C.SDL_ReadStorageFile(self.to_c_ptr(), sub_path.ptr, buffer.ptr, @intCast(buffer.len)));
    }
    pub fn write_file_from_buffer(self: *Storage, sub_path: [:0]const u8, buffer: []const u8) Error!void {
        try ok_or_fail_err(C.SDL_WriteStorageFile(self.to_c_ptr(), sub_path.ptr, buffer.ptr, @intCast(buffer.len)));
    }
    pub fn create_directory(self: *Storage, sub_path: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_CreateStorageDirectory(self.to_c_ptr(), sub_path.ptr));
    }
    pub fn do_callback_for_each_directory_entry(self: *Storage, sub_path: [:0]const u8, callback: *const FolderEntryCallback, callback_data: ?*anyopaque) Error!void {
        try ok_or_fail_err(C.SDL_EnumerateStorageDirectory(self.to_c_ptr(), sub_path.ptr, @ptrCast(@alignCast(callback)), callback_data));
    }
    pub fn delete_file_or_empty_directory(self: *Storage, sub_path: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_RemoveStoragePath(self.to_c_ptr(), sub_path.ptr));
    }
    pub fn rename_file_or_directory(self: Storage, old_sub_path: [:0]const u8, new_sub_path: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_RenameStoragePath(self.to_c_ptr(), old_sub_path.ptr, new_sub_path.ptr));
    }
    pub fn copy_file(self: Storage, old_sub_path: [:0]const u8, new_sub_path: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_CopyStorageFile(self.to_c_ptr(), old_sub_path.ptr, new_sub_path.ptr));
    }
    pub fn get_path_info(self: Storage, sub_path: [:0]const u8) Error!PathInfo {
        var info = PathInfo{};
        try ok_or_null_err(C.SDL_GetStoragePathInfo(self.to_c_ptr(), sub_path.ptr, @ptrCast(@alignCast(&info))));
        return info;
    }
    pub fn get_remaining_storage_space(self: *Storage) u64 {
        return @intCast(C.SDL_GetStorageSpaceRemaining(self));
    }
    pub fn get_directory_glob(self: Storage, sub_path: [:0]const u8, pattern: [:0]const u8, case_insensitive: bool) Error!DirectoryGlob {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_null_err([*]const [*:0]const u8, C.SDL_GlobStorageDirectory(self.to_c_ptr(), sub_path.ptr, pattern.ptr, @intCast(@intFromBool(case_insensitive)), &len));
        return DirectoryGlob{
            .strings = ptr[0..len],
        };
    }
};

pub const FolderEntryCallback = fn (callback_data: ?*anyopaque, folder_name: [*:0]const u8, entry_name: [*:0]const u8) callconv(.c) EnumerationResult;

pub const EnumerationResult = enum(C.SDL_EnumerationResult) {
    CONTINUE = C.SDL_ENUM_CONTINUE,
    SUCCESS = C.SDL_ENUM_SUCCESS,
    FAILURE = C.SDL_ENUM_FAILURE,

    pub const to_c = c_enum_conversions(EnumerationResult, C.SDL_EnumerationResult).to_c;
    pub const from_c = c_enum_conversions(EnumerationResult, C.SDL_EnumerationResult).from_c;
};

pub const PathInfo = extern struct {
    path_type: PathType = .NONE,
    size: u64 = 0,
    create_time: Time_NS = Time_NS{},
    modify_time: Time_NS = Time_NS{},
    access_time: Time_NS = Time_NS{},
};

pub const PathType = enum(C.SDL_PathType) {
    NONE = C.SDL_PATHTYPE_NONE,
    FILE = C.SDL_PATHTYPE_FILE,
    DIRECTORY = C.SDL_PATHTYPE_DIRECTORY,
    OTHER = C.SDL_PATHTYPE_OTHER,

    pub const to_c = c_enum_conversions(PathType, C.SDL_PathType).to_c;
    pub const from_c = c_enum_conversions(PathType, C.SDL_PathType).from_c;
};

pub const DirectoryGlob = extern struct {
    strings: []const [*:0]const u8,

    pub fn get_string(self: DirectoryGlob, index: usize) []const u8 {
        assert(index < self.strings.len);
        return Root.Utils.make_const_slice_from_sentinel_ptr(u8, 0, self.strings[index]);
    }

    pub fn free(self: DirectoryGlob) void {
        Mem.free(self.strings.ptr);
        self.strings = &.{};
    }
};

pub const KeyboardID = extern struct {
    id: u32 = 0,
    //TODO
    // pub extern fn SDL_GetKeyboardNameForID(instance_id: SDL_KeyboardID) [*c]const u8;
};

pub const Camera = opaque {
    pub const to_c_ptr = c_opaque_conversions(Camera, C.SDL_Camera).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Camera, C.SDL_Camera).from_c_ptr;
    //TODO
    // pub extern fn SDL_GetCameraPermissionState(camera: ?*SDL_Camera) c_int;
    // pub extern fn SDL_GetCameraID(camera: ?*SDL_Camera) SDL_CameraID;
    // pub extern fn SDL_GetCameraProperties(camera: ?*SDL_Camera) SDL_PropertiesID;
    // pub extern fn SDL_GetCameraFormat(camera: ?*SDL_Camera, spec: [*c]SDL_CameraSpec) bool;
    // pub extern fn SDL_AcquireCameraFrame(camera: ?*SDL_Camera, timestampNS: [*c]Uint64) [*c]SDL_Surface;
    // pub extern fn SDL_ReleaseCameraFrame(camera: ?*SDL_Camera, frame: [*c]SDL_Surface) void;
    // pub extern fn SDL_CloseCamera(camera: ?*SDL_Camera) void;
};

pub const CameraSpec = extern struct {
    format: PixelFormat = .UNKNOWN,
    colorspace: Colorspace = .UNKNOWN,
    width: c_int = 0,
    height: c_int = 0,
    framerate_numerator: c_int = 0,
    framerate_denominator: c_int = 0,

    pub const to_c_ptr = c_non_opaque_conversions(CameraSpec, C.SDL_CameraSpec).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(CameraSpec, C.SDL_CameraSpec).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(CameraSpec, C.SDL_CameraSpec).to_c;
    pub const from_c = c_non_opaque_conversions(CameraSpec, C.SDL_CameraSpec).from_c;
};

pub const CameraPosition = enum(c_uint) {
    UNKNOWN = C.SDL_CAMERA_POSITION_UNKNOWN,
    FRONT_FACING = C.SDL_CAMERA_POSITION_FRONT_FACING,
    BACK_FACING = C.SDL_CAMERA_POSITION_BACK_FACING,

    pub const to_c = c_enum_conversions(CameraPosition, C.SDL_CameraPosition).to_c;
    pub const from_c = c_enum_conversions(CameraPosition, C.SDL_CameraPosition).from_c;
};

pub const Event = extern union {
    type: EventType,
    common: CommonEvent,
    display: DisplayEvent,
    window: WindowEvent,
    keyboard_device: KeyboardDeviceEvent,
    keyboard: KeyboardEvent,
    text_edit: TextEditEvent,
    text_edit_candidate: TextEditCandidateEvent,
    text_input: TextInputEvent,
    mouse_device: MouseDeviceEvent,
    mouse_motion: MouseMotionEvent,
    mouse_button: MouseButtonEvent,
    mouse_wheel: MouseWheelEvent,
    joy_device: JoyDeviceEvent,
    joy_axis: JoyAxisEvent,
    joy_ball: JoyBallEvent,
    joy_hat: JoyHatEvent,
    joy_button: JoyButtonEvent,
    joy_battery: JoyBatteryEvent,
    gamepad_device: GamepadDeviceEvent,
    gamepad_axis: GamepadAxisEvent,
    gamepad_button: GamepadButtonEvent,
    gamepad_touchpad: GamepadTouchpadEvent,
    gamepad_sensor: GamepadSensorEvent,
    audio_device: AudioDeviceEvent,
    camera_device: CameraDeviceEvent,
    sensor: SensorEvent,
    quit: QuitEvent,
    user: UserEvent,
    touch_finger: TouchFingerEvent,
    pen_proximity: PenProximityEvent,
    pen_touch: PenTouchEvent,
    pen_motion: PenMotionEvent,
    pen_button: PenButtonEvent,
    pen_axis: PenAxisEvent,
    render: RenderEvent,
    drop: DropEvent,
    clipboard: ClipboardEvent,
    _FORCE_SIZE: [128]u8,

    pub const to_c_ptr = c_non_opaque_conversions(Event, C.SDL_Event).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(Event, C.SDL_Event).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(Event, C.SDL_Event).to_c;
    pub const from_c = c_non_opaque_conversions(Event, C.SDL_Event).from_c;

    pub fn convert_coords_to_render_coords(self: *Event, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c()));
    }
    //TODO
    // pub extern fn SDL_PumpEvents() void;
    // pub extern fn SDL_PeepEvents(events: [*c]SDL_Event, numevents: c_int, action: SDL_EventAction, minType: Uint32, maxType: Uint32) c_int;
    // pub extern fn SDL_HasEvent(@"type": Uint32) bool;
    // pub extern fn SDL_HasEvents(minType: Uint32, maxType: Uint32) bool;
    // pub extern fn SDL_FlushEvent(@"type": Uint32) void;
    // pub extern fn SDL_FlushEvents(minType: Uint32, maxType: Uint32) void;
    // pub extern fn SDL_PollEvent(event: [*c]SDL_Event) bool;
    // pub extern fn SDL_WaitEvent(event: [*c]SDL_Event) bool;
    // pub extern fn SDL_WaitEventTimeout(event: [*c]SDL_Event, timeoutMS: Sint32) bool;
    // pub extern fn SDL_PushEvent(event: [*c]SDL_Event) bool;
    // pub extern fn SDL_SetEventFilter(filter: SDL_EventFilter, userdata: ?*anyopaque) void;
    // pub extern fn SDL_GetEventFilter(filter: [*c]SDL_EventFilter, userdata: [*c]?*anyopaque) bool;
    // pub extern fn SDL_AddEventWatch(filter: SDL_EventFilter, userdata: ?*anyopaque) bool;
    // pub extern fn SDL_RemoveEventWatch(filter: SDL_EventFilter, userdata: ?*anyopaque) void;
    // pub extern fn SDL_FilterEvents(filter: SDL_EventFilter, userdata: ?*anyopaque) void;
    // pub extern fn SDL_SetEventEnabled(@"type": Uint32, enabled: bool) void;
    // pub extern fn SDL_EventEnabled(@"type": Uint32) bool;
    // pub extern fn SDL_RegisterEvents(numevents: c_int) Uint32;
    // pub extern fn SDL_GetWindowFromEvent(event: [*c]const SDL_Event) ?*SDL_Window;
};

pub const EventFilter = fn (userdata: ?*anyopaque, event: ?*C.SDL_Event) callconv(.c) bool;

pub const CommonEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(CommonEvent, C.SDL_CommonEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(CommonEvent, C.SDL_CommonEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(CommonEvent, C.SDL_CommonEvent).to_c;
    pub const from_c = c_non_opaque_conversions(CommonEvent, C.SDL_CommonEvent).from_c;
};

pub const DisplayEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    display_id: DisplayID = .{},
    data_1: i32 = 0,
    data_2: i32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(DisplayEvent, C.SDL_DisplayEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(DisplayEvent, C.SDL_DisplayEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(DisplayEvent, C.SDL_DisplayEvent).to_c;
    pub const from_c = c_non_opaque_conversions(DisplayEvent, C.SDL_DisplayEvent).from_c;
};

pub const WindowEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    data_1: i32 = 0,
    data_2: i32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(WindowEvent, C.SDL_WindowEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(WindowEvent, C.SDL_WindowEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(WindowEvent, C.SDL_WindowEvent).to_c;
    pub const from_c = c_non_opaque_conversions(WindowEvent, C.SDL_WindowEvent).from_c;
};

pub const KeyboardDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    keyboard_id: KeyboardID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(KeyboardDeviceEvent, C.SDL_KeyboardDeviceEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(KeyboardDeviceEvent, C.SDL_KeyboardDeviceEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(KeyboardDeviceEvent, C.SDL_KeyboardDeviceEvent).to_c;
    pub const from_c = c_non_opaque_conversions(KeyboardDeviceEvent, C.SDL_KeyboardDeviceEvent).from_c;
};

pub const KeyboardEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    keyboard_id: KeyboardID = .{},
    scancode: Scancode = .UNKNOWN,
    key: Keycode = .UNKNOWN,
    mod: Keymod = .{},
    raw: u16 = 0,
    down: bool = false,
    repeat: bool = false,

    pub const to_c_ptr = c_non_opaque_conversions(KeyboardEvent, C.SDL_KeyboardEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(KeyboardEvent, C.SDL_KeyboardEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(KeyboardEvent, C.SDL_KeyboardEvent).to_c;
    pub const from_c = c_non_opaque_conversions(KeyboardEvent, C.SDL_KeyboardEvent).from_c;
};

pub const TextEditEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    text: [*:0]const u8 = "",
    start: i32 = 0,
    length: i32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(TextEditEvent, C.SDL_TextEditingEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(TextEditEvent, C.SDL_TextEditingEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(TextEditEvent, C.SDL_TextEditingEvent).to_c;
    pub const from_c = c_non_opaque_conversions(TextEditEvent, C.SDL_TextEditingEvent).from_c;
};

pub const TextEditCandidateEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    candidates: ?[*]const [*:0]const u8 = null,
    candidates_len: i32 = 0,
    selected_candidate: i32 = 0,
    horizontal: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(TextEditCandidateEvent, C.SDL_TextEditingCandidatesEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(TextEditCandidateEvent, C.SDL_TextEditingCandidatesEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(TextEditCandidateEvent, C.SDL_TextEditingCandidatesEvent).to_c;
    pub const from_c = c_non_opaque_conversions(TextEditCandidateEvent, C.SDL_TextEditingCandidatesEvent).from_c;
};

pub const TextInputEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    text: ?[*:0]const u8 = null,

    pub const to_c_ptr = c_non_opaque_conversions(TextInputEvent, C.SDL_TextInputEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(TextInputEvent, C.SDL_TextInputEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(TextInputEvent, C.SDL_TextInputEvent).to_c;
    pub const from_c = c_non_opaque_conversions(TextInputEvent, C.SDL_TextInputEvent).from_c;
};

pub const MouseDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    mouse_id: MouseID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(MouseDeviceEvent, C.SDL_MouseDeviceEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(MouseDeviceEvent, C.SDL_MouseDeviceEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(MouseDeviceEvent, C.SDL_MouseDeviceEvent).to_c;
    pub const from_c = c_non_opaque_conversions(MouseDeviceEvent, C.SDL_MouseDeviceEvent).from_c;
};

pub const MouseMotionEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    mouse_id: MouseID = .{},
    state: MouseButtonFlags = .{},
    pos: Vec_f32 = Vec_f32{},
    delta: Vec_f32 = Vec_f32{},

    pub const to_c_ptr = c_non_opaque_conversions(MouseMotionEvent, C.SDL_MouseMotionEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(MouseMotionEvent, C.SDL_MouseMotionEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(MouseMotionEvent, C.SDL_MouseMotionEvent).to_c;
    pub const from_c = c_non_opaque_conversions(MouseMotionEvent, C.SDL_MouseMotionEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *MouseMotionEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const MouseButtonEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    mouse_id: MouseID = .{},
    button: MouseButton = .LEFT,
    down: bool = false,
    clicks: u8 = 0,
    _padding: u8 = 0,
    pos: Vec_f32 = Vec_f32{},

    pub const to_c_ptr = c_non_opaque_conversions(MouseButtonEvent, C.SDL_MouseButtonEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(MouseButtonEvent, C.SDL_MouseButtonEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(MouseButtonEvent, C.SDL_MouseButtonEvent).to_c;
    pub const from_c = c_non_opaque_conversions(MouseButtonEvent, C.SDL_MouseButtonEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *MouseButtonEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const MouseButton = enum(u8) {
    LEFT = C.SDL_BUTTON_LEFT,
    MIDDLE = C.SDL_BUTTON_MIDDLE,
    RIGHT = C.SDL_BUTTON_RIGHT,
    SIDE_1 = C.SDL_BUTTON_X1,
    SIDE_2 = C.SDL_BUTTON_X2,
    _,

    pub const to_c = c_enum_conversions(MouseButton, u8).to_c;
    pub const from_c = c_enum_conversions(MouseButton, u8).from_c;

    pub inline fn to_flag(self: MouseButton) MouseButtonFlags {
        return MouseButtonFlags.from_bit(@intCast(self.to_c() - 1));
    }
};

pub const MouseButtonFlags = Flags(enum(u32) {
    LEFT = C.SDL_BUTTON_LMASK,
    MIDDLE = C.SDL_BUTTON_MMASK,
    RIGHT = C.SDL_BUTTON_RMASK,
    SIDE_1 = C.SDL_BUTTON_X1MASK,
    SIDE_2 = C.SDL_BUTTON_X2MASK,
    _,
}, enum(u32) {});

pub const MouseWheelEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    mouse_id: MouseID = .{},
    delta: Vec_f32 = Vec_f32{},
    direction: MouseWheelDirection = .NORMAL,
    pos: Vec_f32 = Vec_f32{},

    pub const to_c_ptr = c_non_opaque_conversions(MouseWheelEvent, C.SDL_MouseWheelEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(MouseWheelEvent, C.SDL_MouseWheelEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(MouseWheelEvent, C.SDL_MouseWheelEvent).to_c;
    pub const from_c = c_non_opaque_conversions(MouseWheelEvent, C.SDL_MouseWheelEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *MouseWheelEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const JoyAxisEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},
    axis: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,
    value: i16 = 0,
    _padding_4: u16 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(JoyAxisEvent, C.SDL_JoyAxisEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(JoyAxisEvent, C.SDL_JoyAxisEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(JoyAxisEvent, C.SDL_JoyAxisEvent).to_c;
    pub const from_c = c_non_opaque_conversions(JoyAxisEvent, C.SDL_JoyAxisEvent).from_c;
};

pub const JoyBallEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},
    ball: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,
    delta: Vec_i16 = Vec_i16{},

    pub const to_c_ptr = c_non_opaque_conversions(JoyBallEvent, C.SDL_JoyBallEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(JoyBallEvent, C.SDL_JoyBallEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(JoyBallEvent, C.SDL_JoyBallEvent).to_c;
    pub const from_c = c_non_opaque_conversions(JoyBallEvent, C.SDL_JoyBallEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *JoyBallEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const JoyHatEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},
    hat: u8 = 0,
    value: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(JoyHatEvent, C.SDL_JoyHatEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(JoyHatEvent, C.SDL_JoyHatEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(JoyHatEvent, C.SDL_JoyHatEvent).to_c;
    pub const from_c = c_non_opaque_conversions(JoyHatEvent, C.SDL_JoyHatEvent).from_c;
};

pub const JoyButtonEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},
    button: u8 = 0,
    down: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(JoyButtonEvent, C.SDL_JoyButtonEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(JoyButtonEvent, C.SDL_JoyButtonEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(JoyButtonEvent, C.SDL_JoyButtonEvent).to_c;
    pub const from_c = c_non_opaque_conversions(JoyButtonEvent, C.SDL_JoyButtonEvent).from_c;
};

pub const JoyDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(JoyDeviceEvent, C.SDL_JoyDeviceEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(JoyDeviceEvent, C.SDL_JoyDeviceEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(JoyDeviceEvent, C.SDL_JoyDeviceEvent).to_c;
    pub const from_c = c_non_opaque_conversions(JoyDeviceEvent, C.SDL_JoyDeviceEvent).from_c;
};

pub const JoyBatteryEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},
    state: PowerState = .UNKNOWN,
    percent: c_int = 0,

    pub const to_c_ptr = c_non_opaque_conversions(JoyBatteryEvent, C.SDL_JoyBatteryEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(JoyBatteryEvent, C.SDL_JoyBatteryEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(JoyBatteryEvent, C.SDL_JoyBatteryEvent).to_c;
    pub const from_c = c_non_opaque_conversions(JoyBatteryEvent, C.SDL_JoyBatteryEvent).from_c;
};

pub const GamepadAxisEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},
    axis: GamepadAxis = .LEFTX,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,
    value: i16 = 0,
    _padding_4: u16 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GamepadAxisEvent, C.SDL_GamepadAxisEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GamepadAxisEvent, C.SDL_GamepadAxisEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GamepadAxisEvent, C.SDL_GamepadAxisEvent).to_c;
    pub const from_c = c_non_opaque_conversions(GamepadAxisEvent, C.SDL_GamepadAxisEvent).from_c;
};

pub const GamepadButtonEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},
    button: GamepadButton = .START,
    down: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GamepadButtonEvent, C.SDL_GamepadButtonEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GamepadButtonEvent, C.SDL_GamepadButtonEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GamepadButtonEvent, C.SDL_GamepadButtonEvent).to_c;
    pub const from_c = c_non_opaque_conversions(GamepadButtonEvent, C.SDL_GamepadButtonEvent).from_c;
};

pub const GamepadDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(GamepadDeviceEvent, C.SDL_GamepadDeviceEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GamepadDeviceEvent, C.SDL_GamepadDeviceEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GamepadDeviceEvent, C.SDL_GamepadDeviceEvent).to_c;
    pub const from_c = c_non_opaque_conversions(GamepadDeviceEvent, C.SDL_GamepadDeviceEvent).from_c;
};

pub const GamepadTouchpadEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},
    touchpad: i32 = 0,
    finger: i32 = 0,
    pos: Vec_f32 = Vec_f32{},
    pressure: f32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GamepadTouchpadEvent, C.SDL_GamepadTouchpadEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GamepadTouchpadEvent, C.SDL_GamepadTouchpadEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GamepadTouchpadEvent, C.SDL_GamepadTouchpadEvent).to_c;
    pub const from_c = c_non_opaque_conversions(GamepadTouchpadEvent, C.SDL_GamepadTouchpadEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *GamepadTouchpadEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const GamepadSensorEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: JoystickID = .{},
    sensor: i32 = 0,
    data: [3]f32 = @splat(0.0),
    sensor_timestamp: u64 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GamepadSensorEvent, C.SDL_GamepadSensorEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GamepadSensorEvent, C.SDL_GamepadSensorEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GamepadSensorEvent, C.SDL_GamepadSensorEvent).to_c;
    pub const from_c = c_non_opaque_conversions(GamepadSensorEvent, C.SDL_GamepadSensorEvent).from_c;
};

pub const AudioDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    device_id: AudioDeviceID = .{},
    recording: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(AudioDeviceEvent, C.SDL_AudioDeviceEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(AudioDeviceEvent, C.SDL_AudioDeviceEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(AudioDeviceEvent, C.SDL_AudioDeviceEvent).to_c;
    pub const from_c = c_non_opaque_conversions(AudioDeviceEvent, C.SDL_AudioDeviceEvent).from_c;
};

pub const CameraDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    device_id: CameraID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(CameraDeviceEvent, C.SDL_CameraDeviceEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(CameraDeviceEvent, C.SDL_CameraDeviceEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(CameraDeviceEvent, C.SDL_CameraDeviceEvent).to_c;
    pub const from_c = c_non_opaque_conversions(CameraDeviceEvent, C.SDL_CameraDeviceEvent).from_c;
};

pub const RenderEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(RenderEvent, C.SDL_RenderEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(RenderEvent, C.SDL_RenderEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(RenderEvent, C.SDL_RenderEvent).to_c;
    pub const from_c = c_non_opaque_conversions(RenderEvent, C.SDL_RenderEvent).from_c;
};

pub const TouchFingerEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    touch_id: TouchID = .{},
    finger_id: FingerID = .{},
    pos: Vec_f32 = Vec_f32{},
    delta: Vec_f32 = Vec_f32{},
    pressure: f32 = 0,
    window_id: WindowID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(TouchFingerEvent, C.SDL_TouchFingerEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(TouchFingerEvent, C.SDL_TouchFingerEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(TouchFingerEvent, C.SDL_TouchFingerEvent).to_c;
    pub const from_c = c_non_opaque_conversions(TouchFingerEvent, C.SDL_TouchFingerEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *TouchFingerEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const PenProximityEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(PenProximityEvent, C.SDL_PenProximityEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(PenProximityEvent, C.SDL_PenProximityEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(PenProximityEvent, C.SDL_PenProximityEvent).to_c;
    pub const from_c = c_non_opaque_conversions(PenProximityEvent, C.SDL_PenProximityEvent).from_c;
};

pub const PenMotionEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: Vec_f32 = Vec_f32{},

    pub const to_c_ptr = c_non_opaque_conversions(PenMotionEvent, C.SDL_PenMotionEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(PenMotionEvent, C.SDL_PenMotionEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(PenMotionEvent, C.SDL_PenMotionEvent).to_c;
    pub const from_c = c_non_opaque_conversions(PenMotionEvent, C.SDL_PenMotionEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *PenMotionEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const PenTouchEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: Vec_f32 = Vec_f32{},
    eraser: bool = false,
    down: bool = false,

    pub const to_c_ptr = c_non_opaque_conversions(PenTouchEvent, C.SDL_PenTouchEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(PenTouchEvent, C.SDL_PenTouchEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(PenTouchEvent, C.SDL_PenTouchEvent).to_c;
    pub const from_c = c_non_opaque_conversions(PenTouchEvent, C.SDL_PenTouchEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *PenTouchEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const PenButtonEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: Vec_f32 = Vec_f32{},
    button: u8 = 0,
    down: bool = false,

    pub const to_c_ptr = c_non_opaque_conversions(PenButtonEvent, C.SDL_PenButtonEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(PenButtonEvent, C.SDL_PenButtonEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(PenButtonEvent, C.SDL_PenButtonEvent).to_c;
    pub const from_c = c_non_opaque_conversions(PenButtonEvent, C.SDL_PenButtonEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *PenButtonEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const PenAxisEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: Vec_f32 = Vec_f32{},
    axis: PenAxis = .PRESSURE,
    value: f32 = 0.0,

    pub const to_c_ptr = c_non_opaque_conversions(PenAxisEvent, C.SDL_PenAxisEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(PenAxisEvent, C.SDL_PenAxisEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(PenAxisEvent, C.SDL_PenAxisEvent).to_c;
    pub const from_c = c_non_opaque_conversions(PenAxisEvent, C.SDL_PenAxisEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *PenAxisEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const DropEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pos: Vec_f32 = Vec_f32{},
    source: ?[*]const u8 = null,
    data: ?[*]const u8 = null,

    pub const to_c_ptr = c_non_opaque_conversions(DropEvent, C.SDL_DropEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(DropEvent, C.SDL_DropEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(DropEvent, C.SDL_DropEvent).to_c;
    pub const from_c = c_non_opaque_conversions(DropEvent, C.SDL_DropEvent).from_c;

    pub fn convert_coords_to_render_coords(self: *DropEvent, renderer: *Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c_ptr(), self.to_c_event()));
    }
};

pub const ClipboardEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    owner: bool = false,
    num_mime_types: i32 = 0,
    mime_types: ?[*]const [*:0]const u8 = null,

    pub const to_c_ptr = c_non_opaque_conversions(ClipboardEvent, C.SDL_ClipboardEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(ClipboardEvent, C.SDL_ClipboardEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(ClipboardEvent, C.SDL_ClipboardEvent).to_c;
    pub const from_c = c_non_opaque_conversions(ClipboardEvent, C.SDL_ClipboardEvent).from_c;
};

pub const SensorEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    sensor_id: bool = false,
    data: [6]f32 = @splat(0),
    sensor_timestamp: u64 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(SensorEvent, C.SDL_SensorEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(SensorEvent, C.SDL_SensorEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(SensorEvent, C.SDL_SensorEvent).to_c;
    pub const from_c = c_non_opaque_conversions(SensorEvent, C.SDL_SensorEvent).from_c;
};

pub const QuitEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(QuitEvent, C.SDL_QuitEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(QuitEvent, C.SDL_QuitEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(QuitEvent, C.SDL_QuitEvent).to_c;
    pub const from_c = c_non_opaque_conversions(QuitEvent, C.SDL_QuitEvent).from_c;
};

pub const UserEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    code: i32 = 0,
    userdata_1: ?*anyopaque = null,
    userdata_2: ?*anyopaque = null,

    pub const to_c_ptr = c_non_opaque_conversions(UserEvent, C.SDL_UserEvent).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(UserEvent, C.SDL_UserEvent).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(UserEvent, C.SDL_UserEvent).to_c;
    pub const from_c = c_non_opaque_conversions(UserEvent, C.SDL_UserEvent).from_c;
};

pub const Cursor = opaque {
    pub const to_c_ptr = c_opaque_conversions(Cursor, C.SDL_Cursor).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Cursor, C.SDL_Cursor).from_c_ptr;
    //TODO
    // pub extern fn SDL_CreateCursor(data: [*c]const Uint8, mask: [*c]const Uint8, w: c_int, h: c_int, hot_x: c_int, hot_y: c_int) ?*SDL_Cursor;
    // pub extern fn SDL_CreateColorCursor(surface: [*c]SDL_Surface, hot_x: c_int, hot_y: c_int) ?*SDL_Cursor;
    // pub extern fn SDL_CreateSystemCursor(id: SDL_SystemCursor) ?*SDL_Cursor;
    // pub extern fn SDL_SetCursor(cursor: ?*SDL_Cursor) bool;
    // pub extern fn SDL_GetCursor() ?*SDL_Cursor;
    // pub extern fn SDL_GetDefaultCursor() ?*SDL_Cursor;
    // pub extern fn SDL_DestroyCursor(cursor: ?*SDL_Cursor) void;
    // pub extern fn SDL_ShowCursor() bool;
    // pub extern fn SDL_HideCursor() bool;
    // pub extern fn SDL_CursorVisible() bool;
};

pub const SystemCursor = enum(C.SDL_SystemCursor) {
    DEFAULT = C.SDL_SYSTEM_CURSOR_DEFAULT,
    TEXT = C.SDL_SYSTEM_CURSOR_TEXT,
    WAIT = C.SDL_SYSTEM_CURSOR_WAIT,
    CROSSHAIR = C.SDL_SYSTEM_CURSOR_CROSSHAIR,
    PROGRESS = C.SDL_SYSTEM_CURSOR_PROGRESS,
    TOP_LEFT_BOT_RIGHT_RESIZE = C.SDL_SYSTEM_CURSOR_NWSE_RESIZE,
    TOP_RIGHT_BOT_LEFT_RESIZE = C.SDL_SYSTEM_CURSOR_NESW_RESIZE,
    HORIZONTAL_RESIZE = C.SDL_SYSTEM_CURSOR_EW_RESIZE,
    VERTICAL_RESIZE = C.SDL_SYSTEM_CURSOR_NS_RESIZE,
    MOVE = C.SDL_SYSTEM_CURSOR_MOVE,
    NOT_ALLOWED = C.SDL_SYSTEM_CURSOR_NOT_ALLOWED,
    POINTER = C.SDL_SYSTEM_CURSOR_POINTER,
    TOP_LEFT_RESIZE = C.SDL_SYSTEM_CURSOR_NW_RESIZE,
    TOP_RESIZE = C.SDL_SYSTEM_CURSOR_N_RESIZE,
    TOP_RIGHT_RESIZE = C.SDL_SYSTEM_CURSOR_NE_RESIZE,
    RIGHT_RESIZE = C.SDL_SYSTEM_CURSOR_E_RESIZE,
    BOT_RIGHT_RESIZE = C.SDL_SYSTEM_CURSOR_SE_RESIZE,
    BOT_RESIZE = C.SDL_SYSTEM_CURSOR_S_RESIZE,
    BOT_LEFT_RESIZE = C.SDL_SYSTEM_CURSOR_SW_RESIZE,
    LEFT_RESIZE = C.SDL_SYSTEM_CURSOR_W_RESIZE,

    pub const COUNT = C.SDL_SYSTEM_CURSOR_COUNT;

    pub const to_c = c_enum_conversions(SystemCursor, C.SDL_SystemCursor).to_c;
    pub const from_c = c_enum_conversions(SystemCursor, C.SDL_SystemCursor).from_c;
    //TODO
    // pub extern fn SDL_CreateSystemCursor(id: SDL_SystemCursor) ?*SDL_Cursor;
};

pub const MouseID = extern struct {
    id: u32 = 0,

    pub const VIRTUAL_FROM_TOUCH = MouseID{ .id = C.SDL_TOUCH_MOUSEID };
    pub const VIRTUAL_FROM_PEN = MouseID{ .id = C.SDL_PEN_MOUSEID };
    //TODO
    // pub extern fn SDL_GetMouseNameForID(instance_id: SDL_MouseID) [*c]const u8;
};

pub const PenID = extern struct {
    id: u32 = 0,
};

pub const SensorID = extern struct {
    id: u32 = 0,
    //TODO
    // pub extern fn SDL_GetSensors(count: [*c]c_int) [*c]SDL_SensorID;
    // pub extern fn SDL_GetSensorNameForID(instance_id: SDL_SensorID) [*c]const u8;
    // pub extern fn SDL_GetSensorTypeForID(instance_id: SDL_SensorID) SDL_SensorType;
    // pub extern fn SDL_GetSensorNonPortableTypeForID(instance_id: SDL_SensorID) c_int;
    // pub extern fn SDL_OpenSensor(instance_id: SDL_SensorID) ?*SDL_Sensor;
    // pub extern fn SDL_GetSensorFromID(instance_id: SDL_SensorID) ?*SDL_Sensor;
    // pub extern fn SDL_UpdateSensors() void;
};

pub const TouchDeviceType = enum(C.SDL_TouchDeviceType) {
    INVALID = C.SDL_TOUCH_DEVICE_INVALID,
    DIRECT = C.SDL_TOUCH_DEVICE_DIRECT,
    INDIRECT_ABSOLUTE = C.SDL_TOUCH_DEVICE_INDIRECT_ABSOLUTE,
    INDIRECT_RELATIVE = C.SDL_TOUCH_DEVICE_INDIRECT_RELATIVE,

    pub const to_c = c_enum_conversions(TouchDeviceType, C.SDL_TouchDeviceType).to_c;
    pub const from_c = c_enum_conversions(TouchDeviceType, C.SDL_TouchDeviceType).from_c;
};

pub const JoystickType = enum(C.SDL_JoystickType) {
    UNKNOWN = C.SDL_JOYSTICK_TYPE_UNKNOWN,
    GAMEPAD = C.SDL_JOYSTICK_TYPE_GAMEPAD,
    WHEEL = C.SDL_JOYSTICK_TYPE_WHEEL,
    ARCADE_STICK = C.SDL_JOYSTICK_TYPE_ARCADE_STICK,
    FLIGHT_STICK = C.SDL_JOYSTICK_TYPE_FLIGHT_STICK,
    DANCE_PAD = C.SDL_JOYSTICK_TYPE_DANCE_PAD,
    GUITAR = C.SDL_JOYSTICK_TYPE_GUITAR,
    DRUM_KIT = C.SDL_JOYSTICK_TYPE_DRUM_KIT,
    ARCADE_PAD = C.SDL_JOYSTICK_TYPE_ARCADE_PAD,
    THROTTLE = C.SDL_JOYSTICK_TYPE_THROTTLE,

    pub const COUNT = C.SDL_JOYSTICK_TYPE_COUNT;

    pub const to_c = c_enum_conversions(JoystickType, C.SDL_JoystickType).to_c;
    pub const from_c = c_enum_conversions(JoystickType, C.SDL_JoystickType).from_c;
};

pub const JoystickID = extern struct {
    id: u32 = 0,

    fn new_err(id: u32) Error!JoystickID {
        return JoystickID{ .id = try nonzero_or_null_err(id) };
    }

    pub fn new(id: u32) JoystickID {
        return JoystickID{ .id = id };
    }
    pub fn null_id() JoystickID {
        return NULL_ID;
    }
    pub const NULL_ID = JoystickID{ .id = 0 };

    pub fn get_all_gamepads() Error!GamepadsList {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_fail_err([*]JoystickID, C.SDL_GetGamepads(&len));
        return GamepadsList{ .list = ptr[0..@intCast(len)] };
    }
    pub fn is_gamepad(self: JoystickID) bool {
        return C.SDL_IsGamepad(self.id);
    }
    pub fn get_name(self: JoystickID) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGamepadNameForID(self.id));
    }
    pub fn get_path(self: JoystickID) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGamepadPathForID(self.id));
    }
    pub fn get_player_index(self: JoystickID) Error!PlayerIndex {
        return PlayerIndex{ .index = try positive_or_null_err(C.SDL_GetGamepadPlayerIndexForID(self.id)) };
    }
    pub fn get_guid(self: JoystickID) Error!GUID {
        return valid_guid_or_null_err(C.SDL_GetGamepadGUIDForID(self.id));
    }
    pub fn get_vendor_code(self: JoystickID) Error!HID_VendorCode {
        return HID_VendorCode{ .code = try nonzero_or_null_err(C.SDL_GetGamepadVendorForID(self.id)) };
    }
    pub fn get_product_code(self: JoystickID) Error!HID_ProductCode {
        return HID_ProductCode{ .code = try nonzero_or_null_err(C.SDL_GetGamepadProductForID(self.id)) };
    }
    pub fn get_product_version(self: JoystickID) Error!HID_ProductVersion {
        return HID_ProductVersion{ .code = try nonzero_or_null_err(C.SDL_GetGamepadProductVersionForID(self.id)) };
    }
    pub fn get_gamepad_type(self: JoystickID) Error!GamepadType {
        return GamepadType.from_c(C.SDL_GetGamepadTypeForID(self.id));
    }
    pub fn get_real_gamepad_type(self: JoystickID) Error!GamepadType {
        return GamepadType.from_c(C.SDL_GetRealGamepadTypeForID(self.id));
    }
    pub fn get_gamepad_mapping_string(self: JoystickID) Error!AllocatedString {
        return AllocatedString{ .str = try ptr_cast_or_null_err([*:0]u8, C.SDL_GetGamepadMappingForID(self.id)) };
    }
    pub fn open_gamepad(self: JoystickID) Error!*Gamepad {
        return ptr_cast_or_null_err(*Gamepad, C.SDL_OpenGamepad(self.id));
    }
    pub fn get_open_gamepad(self: JoystickID) Error!*Gamepad {
        return ptr_cast_or_null_err(*Gamepad, C.SDL_GetGamepadFromID(self.id));
    }
    //TODO
    // pub extern fn SDL_AddGamepadMapping(mapping: [*c]const u8) c_int;
    // pub extern fn SDL_AddGamepadMappingsFromIO(src: ?*SDL_IOStream, closeio: bool) c_int;
    // pub extern fn SDL_AddGamepadMappingsFromFile(file: [*c]const u8) c_int;
    // pub extern fn SDL_ReloadGamepadMappings() bool;
    // pub extern fn SDL_GetGamepadMappings(count: [*c]c_int) [*c][*c]u8;
    // pub extern fn SDL_GetGamepadMappingForGUID(guid: SDL_GUID) [*c]u8;
    // pub extern fn SDL_GetGamepadMapping(gamepad: ?*SDL_Gamepad) [*c]u8;
    // pub extern fn SDL_SetGamepadMapping(instance_id: SDL_JoystickID, mapping: [*c]const u8) bool;
    // pub extern fn SDL_HasGamepad() bool;
    // pub extern fn SDL_LockJoysticks() void;
    // pub extern fn SDL_UnlockJoysticks() void;
    // pub extern fn SDL_HasJoystick() bool;
    // pub extern fn SDL_GetJoysticks(count: [*c]c_int) [*c]SDL_JoystickID;
    // pub extern fn SDL_GetJoystickNameForID(instance_id: SDL_JoystickID) [*c]const u8;
    // pub extern fn SDL_GetJoystickPathForID(instance_id: SDL_JoystickID) [*c]const u8;
    // pub extern fn SDL_GetJoystickPlayerIndexForID(instance_id: SDL_JoystickID) c_int;
    // pub extern fn SDL_GetJoystickGUIDForID(instance_id: SDL_JoystickID) SDL_GUID;
    // pub extern fn SDL_GetJoystickVendorForID(instance_id: SDL_JoystickID) Uint16;
    // pub extern fn SDL_GetJoystickProductForID(instance_id: SDL_JoystickID) Uint16;
    // pub extern fn SDL_GetJoystickProductVersionForID(instance_id: SDL_JoystickID) Uint16;
    // pub extern fn SDL_GetJoystickTypeForID(instance_id: SDL_JoystickID) SDL_JoystickType;
    // pub extern fn SDL_OpenJoystick(instance_id: SDL_JoystickID) ?*SDL_Joystick;
    // pub extern fn SDL_GetJoystickFromID(instance_id: SDL_JoystickID) ?*SDL_Joystick;
};

pub const Gamepad = opaque {
    pub const to_c_ptr = c_opaque_conversions(Gamepad, C.SDL_Gamepad).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Gamepad, C.SDL_Gamepad).from_c_ptr;

    pub fn set_events_enabled(state: bool) void {
        C.SDL_SetGamepadEventsEnabled(state);
    }
    pub fn update_all_gamepads() void {
        C.SDL_UpdateGamepads();
    }
    pub fn events_are_enabled() bool {
        return C.SDL_GamepadEventsEnabled();
    }
    pub fn from_player_index(index: PlayerIndex) Error!*Gamepad {
        return ptr_cast_or_null_err(*Gamepad, C.SDL_GetGamepadFromPlayerIndex(index.index));
    }
    pub fn get_properties(self: *Gamepad) Error!PropertiesID {
        return PropertiesID.new(try nonzero_or_null_err(C.SDL_GetGamepadProperties(self.to_c_ptr())));
    }
    pub fn get_id(self: *Gamepad) Error!JoystickID {
        return JoystickID.new_err(C.SDL_GetGamepadProperties(self.to_c_ptr()));
    }
    pub fn get_name(self: *Gamepad) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGamepadName(self.to_c_ptr()));
    }
    pub fn get_path(self: *Gamepad) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGamepadPath(self.to_c_ptr()));
    }
    pub fn get_type(self: *Gamepad) Error!GamepadType {
        return GamepadType.from_c(C.SDL_GetGamepadType(self.to_c_ptr()));
    }
    pub fn get_real_type(self: *Gamepad) Error!GamepadType {
        return GamepadType.from_c(C.SDL_GetRealGamepadType(self.to_c_ptr()));
    }
    pub fn get_player_index(self: *Gamepad) Error!PlayerIndex {
        return PlayerIndex.new_err(C.SDL_GetGamepadPlayerIndex(self.to_c_ptr()));
    }
    pub fn set_player_index(self: *Gamepad, player: PlayerIndex) Error!void {
        return ok_or_fail_err(C.SDL_SetGamepadPlayerIndex(self.to_c_ptr(), player.index));
    }
    pub fn clear_player_index(self: *Gamepad) Error!void {
        return ok_or_fail_err(C.SDL_SetGamepadPlayerIndex(self.to_c_ptr(), -1));
    }
    pub fn get_vendor_code(self: *Gamepad) HID_VendorCode {
        return HID_VendorCode.new(C.SDL_GetGamepadVendor(self.to_c_ptr()));
    }
    pub fn get_product_code(self: *Gamepad) HID_ProductCode {
        return HID_ProductCode.new(C.SDL_GetGamepadProduct(self.to_c_ptr()));
    }
    pub fn get_product_version(self: *Gamepad) HID_ProductVersion {
        return HID_ProductVersion.new(C.SDL_GetGamepadProductVersion(self.to_c_ptr()));
    }
    pub fn get_firmware_version(self: *Gamepad) HID_FirmwareVersion {
        return HID_FirmwareVersion.new(C.SDL_GetGamepadFirmwareVersion(self.to_c_ptr()));
    }
    pub fn get_serial_number(self: *Gamepad) Error!HID_SerialNumber {
        return HID_SerialNumber.new_err(C.SDL_GetGamepadSerial(self.to_c_ptr()));
    }
    pub fn get_steam_handle(self: *Gamepad) Error!SteamHandle {
        return SteamHandle.new_err(C.SDL_GetGamepadSteamHandle(self.to_c_ptr()));
    }
    pub fn get_connection_state(self: *Gamepad) ControllerConnectionState {
        return ControllerConnectionState.from_c(C.SDL_GetGamepadConnectionState(self.to_c_ptr()));
    }
    pub fn get_power_info(self: *Gamepad) PowerInfo {
        var percent: c_int = 0;
        const state = PowerState.from_c(C.SDL_GetGamepadPowerInfo(self.to_c_ptr(), &percent));
        return PowerInfo{ .state = state, .percent = percent };
    }
    pub fn is_connected(self: *Gamepad) bool {
        return C.SDL_GamepadConnected(self.to_c_ptr());
    }
    pub fn get_joystick_api(self: *Gamepad) Error!*Joystick {
        return ptr_cast_or_null_err(*Joystick, C.SDL_GetGamepadJoystick(self.to_c()));
    }
    pub fn get_bindings(self: *Gamepad) Error!GamepadBindingList {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_null_err([*]*GamepadBinding, C.SDL_GetGamepadBindings(self.to_c_ptr(), &len));
        GamepadBindingList{ .list = ptr[0..len] };
    }
    pub fn has_axis(self: *Gamepad, axis: GamepadAxis) bool {
        return C.SDL_GamepadHasAxis(self.to_c_ptr(), axis.to_c());
    }
    pub fn get_axis_position(self: *Gamepad, axis: GamepadAxis) AxisPosition {
        return AxisPosition{ .val = C.SDL_GetGamepadAxis(self.to_c_ptr(), axis.to_c()) };
    }
    pub fn has_button(self: *Gamepad, button: GamepadButton) bool {
        return C.SDL_GamepadHasButton(self.to_c_ptr(), button.to_c());
    }
    pub fn get_button_state(self: *Gamepad, button: GamepadButton) KeyButtonState {
        return KeyButtonState.from_bool(C.SDL_GetGamepadButton(self.to_c_ptr(), button.to_c()));
    }
    pub fn get_label_for_face_button(self: *Gamepad, button: GamepadButton) GamepadFaceButtonLabel {
        return GamepadFaceButtonLabel.from_c(C.SDL_GetGamepadButtonLabel(self.to_c_ptr(), button.to_c()));
    }
    pub fn get_number_of_touchpads(self: *Gamepad) c_int {
        return C.SDL_GetNumGamepadTouchpads(self.to_c_ptr());
    }
    pub fn get_touchpad_max_fingers(self: *Gamepad, touchpad: c_int) c_int {
        return C.SDL_GetNumGamepadTouchpadFingers(self.to_c_ptr(), touchpad);
    }
    pub fn get_touchpad_finger_state(self: *Gamepad, touchpad: c_int, finger: c_int) FingerState {
        var state: FingerState = undefined;
        try ok_or_null_err(C.SDL_GetGamepadTouchpadFinger(self.to_c_ptr(), touchpad, finger, @ptrCast(@alignCast(&state.state)), &state.position.x, &state.position.y, &state.pressure));
        return state;
    }
    pub fn has_sensor(self: *Gamepad, sensor: SensorType) bool {
        return C.SDL_GamepadHasSensor(self.to_c_ptr(), sensor.to_c());
    }
    pub fn set_sensor_enabled(self: *Gamepad, sensor: SensorType, state: bool) Error!void {
        return ok_or_fail_err(C.SDL_SetGamepadSensorEnabled(self.to_c_ptr(), sensor.to_c(), state));
    }
    pub fn is_sensor_enabled(self: *Gamepad, sensor: SensorType) bool {
        return C.SDL_GamepadSensorEnabled(self.to_c_ptr(), sensor.to_c());
    }
    //TODO
    // pub extern fn SDL_GetGamepadSensorDataRate(gamepad: ?*SDL_Gamepad, @"type": SDL_SensorType) f32;
    // pub extern fn SDL_GetGamepadSensorData(gamepad: ?*SDL_Gamepad, @"type": SDL_SensorType, data: [*c]f32, num_values: c_int) bool;
    // pub extern fn SDL_RumbleGamepad(gamepad: ?*SDL_Gamepad, low_frequency_rumble: Uint16, high_frequency_rumble: Uint16, duration_ms: Uint32) bool;
    // pub extern fn SDL_RumbleGamepadTriggers(gamepad: ?*SDL_Gamepad, left_rumble: Uint16, right_rumble: Uint16, duration_ms: Uint32) bool;
    // pub extern fn SDL_SetGamepadLED(gamepad: ?*SDL_Gamepad, red: Uint8, green: Uint8, blue: Uint8) bool;
    // pub extern fn SDL_SendGamepadEffect(gamepad: ?*SDL_Gamepad, data: ?*const anyopaque, size: c_int) bool;
    // pub extern fn SDL_GetGamepadAppleSFSymbolsNameForButton(gamepad: ?*SDL_Gamepad, button: SDL_GamepadButton) [*c]const u8;
    // pub extern fn SDL_GetGamepadAppleSFSymbolsNameForAxis(gamepad: ?*SDL_Gamepad, axis: SDL_GamepadAxis) [*c]const u8;
    pub fn close(self: *Gamepad) void {
        C.SDL_CloseGamepad(self.to_c_ptr());
    }

    pub const AxisMax = C.SDL_JOYSTICK_AXIS_MAX;
    pub const AxisMin = C.SDL_JOYSTICK_AXIS_MIN;

    pub const Props = struct {
        pub const HAS_MONO_LED = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_MONO_LED_BOOLEAN);
        pub const HAS_RGB_LED = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_RGB_LED_BOOLEAN);
        pub const HAS_PLAYER_LED = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_PLAYER_LED_BOOLEAN);
        pub const HAS_RUMBLE = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_RUMBLE_BOOLEAN);
        pub const HAS_TRIGGER_RUMBLE = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_TRIGGER_RUMBLE_BOOLEAN);
    };
};

pub const Joystick = opaque {
    pub const to_c_ptr = c_opaque_conversions(Joystick, C.SDL_Joystick).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Joystick, C.SDL_Joystick).from_c_ptr;
    //TODO
    // pub extern fn SDL_AttachVirtualJoystick(desc: [*c]const SDL_VirtualJoystickDesc) SDL_JoystickID;
    // pub extern fn SDL_DetachVirtualJoystick(instance_id: SDL_JoystickID) bool;
    // pub extern fn SDL_IsJoystickVirtual(instance_id: SDL_JoystickID) bool;
    // pub extern fn SDL_SetJoystickVirtualAxis(joystick: ?*SDL_Joystick, axis: c_int, value: Sint16) bool;
    // pub extern fn SDL_SetJoystickVirtualBall(joystick: ?*SDL_Joystick, ball: c_int, xrel: Sint16, yrel: Sint16) bool;
    // pub extern fn SDL_SetJoystickVirtualButton(joystick: ?*SDL_Joystick, button: c_int, down: bool) bool;
    // pub extern fn SDL_SetJoystickVirtualHat(joystick: ?*SDL_Joystick, hat: c_int, value: Uint8) bool;
    // pub extern fn SDL_SetJoystickVirtualTouchpad(joystick: ?*SDL_Joystick, touchpad: c_int, finger: c_int, down: bool, x: f32, y: f32, pressure: f32) bool;
    // pub extern fn SDL_SendJoystickVirtualSensorData(joystick: ?*SDL_Joystick, @"type": SDL_SensorType, sensor_timestamp: Uint64, data: [*c]const f32, num_values: c_int) bool;
    // pub extern fn SDL_GetJoystickProperties(joystick: ?*SDL_Joystick) SDL_PropertiesID;
    // pub extern fn SDL_GetJoystickName(joystick: ?*SDL_Joystick) [*c]const u8;
    // pub extern fn SDL_GetJoystickPath(joystick: ?*SDL_Joystick) [*c]const u8;
    // pub extern fn SDL_GetJoystickPlayerIndex(joystick: ?*SDL_Joystick) c_int;
    // pub extern fn SDL_SetJoystickPlayerIndex(joystick: ?*SDL_Joystick, player_index: c_int) bool;
    // pub extern fn SDL_GetJoystickGUID(joystick: ?*SDL_Joystick) SDL_GUID;
    // pub extern fn SDL_GetJoystickVendor(joystick: ?*SDL_Joystick) Uint16;
    // pub extern fn SDL_GetJoystickProduct(joystick: ?*SDL_Joystick) Uint16;
    // pub extern fn SDL_GetJoystickProductVersion(joystick: ?*SDL_Joystick) Uint16;
    // pub extern fn SDL_GetJoystickFirmwareVersion(joystick: ?*SDL_Joystick) Uint16;
    // pub extern fn SDL_GetJoystickSerial(joystick: ?*SDL_Joystick) [*c]const u8;
    // pub extern fn SDL_GetJoystickType(joystick: ?*SDL_Joystick) SDL_JoystickType;
    // pub extern fn SDL_GetJoystickGUIDInfo(guid: SDL_GUID, vendor: [*c]Uint16, product: [*c]Uint16, version: [*c]Uint16, crc16: [*c]Uint16) void;
    // pub extern fn SDL_JoystickConnected(joystick: ?*SDL_Joystick) bool;
    // pub extern fn SDL_GetJoystickID(joystick: ?*SDL_Joystick) SDL_JoystickID;
    // pub extern fn SDL_GetNumJoystickAxes(joystick: ?*SDL_Joystick) c_int;
    // pub extern fn SDL_GetNumJoystickBalls(joystick: ?*SDL_Joystick) c_int;
    // pub extern fn SDL_GetNumJoystickHats(joystick: ?*SDL_Joystick) c_int;
    // pub extern fn SDL_GetNumJoystickButtons(joystick: ?*SDL_Joystick) c_int;
    // pub extern fn SDL_SetJoystickEventsEnabled(enabled: bool) void;
    // pub extern fn SDL_JoystickEventsEnabled() bool;
    // pub extern fn SDL_UpdateJoysticks() void;
    // pub extern fn SDL_GetJoystickAxis(joystick: ?*SDL_Joystick, axis: c_int) Sint16;
    // pub extern fn SDL_GetJoystickAxisInitialState(joystick: ?*SDL_Joystick, axis: c_int, state: [*c]Sint16) bool;
    // pub extern fn SDL_GetJoystickBall(joystick: ?*SDL_Joystick, ball: c_int, dx: [*c]c_int, dy: [*c]c_int) bool;
    // pub extern fn SDL_GetJoystickHat(joystick: ?*SDL_Joystick, hat: c_int) Uint8;
    // pub extern fn SDL_GetJoystickButton(joystick: ?*SDL_Joystick, button: c_int) bool;
    // pub extern fn SDL_RumbleJoystick(joystick: ?*SDL_Joystick, low_frequency_rumble: Uint16, high_frequency_rumble: Uint16, duration_ms: Uint32) bool;
    // pub extern fn SDL_RumbleJoystickTriggers(joystick: ?*SDL_Joystick, left_rumble: Uint16, right_rumble: Uint16, duration_ms: Uint32) bool;
    // pub extern fn SDL_SetJoystickLED(joystick: ?*SDL_Joystick, red: Uint8, green: Uint8, blue: Uint8) bool;
    // pub extern fn SDL_SendJoystickEffect(joystick: ?*SDL_Joystick, data: ?*const anyopaque, size: c_int) bool;
    // pub extern fn SDL_CloseJoystick(joystick: ?*SDL_Joystick) void;
    // pub extern fn SDL_GetJoystickConnectionState(joystick: ?*SDL_Joystick) SDL_JoystickConnectionState;
    // pub extern fn SDL_GetJoystickPowerInfo(joystick: ?*SDL_Joystick, percent: [*c]c_int) SDL_PowerState;
    // pub extern fn SDL_IsJoystickHaptic(joystick: ?*SDL_Joystick) bool;
    // pub extern fn SDL_OpenHapticFromJoystick(joystick: ?*SDL_Joystick) ?*SDL_Haptic;
    // pub extern fn SDL_GetJoystickFromPlayerIndex(player_index: c_int) ?*SDL_Joystick;

    pub const AxisMax = C.SDL_JOYSTICK_AXIS_MAX;
    pub const AxisMin = C.SDL_JOYSTICK_AXIS_MIN;

    pub const Props = struct {
        pub const HAS_MONO_LED = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_MONO_LED_BOOLEAN);
        pub const HAS_RGB_LED = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_RGB_LED_BOOLEAN);
        pub const HAS_PLAYER_LED = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_PLAYER_LED_BOOLEAN);
        pub const HAS_RUMBLE = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_RUMBLE_BOOLEAN);
        pub const HAS_TRIGGER_RUMBLE = Property.new(.BOOLEAN, C.SDL_PROP_JOYSTICK_CAP_TRIGGER_RUMBLE_BOOLEAN);
    };
};

pub const JoystickHatPos = Flags(enum(u8) {
    CENTERED = C.SDL_HAT_CENTERED,
    UP = C.SDL_HAT_UP,
    RIGHT = C.SDL_HAT_RIGHT,
    DOWN = C.SDL_HAT_DOWN,
    LEFT = C.SDL_HAT_LEFT,
    RIGHT_UP = C.SDL_HAT_RIGHTUP,
    RIGHT_DOWN = C.SDL_HAT_RIGHTDOWN,
    LEFT_UP = C.SDL_HAT_LEFTUP,
    LEFT_DOWN = C.SDL_HAT_LEFTDOWN,
}, enum(u8) {
    NOT_CENTERED = C.SDL_HAT_UP | C.SDL_HAT_RIGHT | C.SDL_HAT_DOWN | C.SDL_HAT_LEFT,
});

pub const VirtualJoystickTouchpadDesc = extern struct {
    num_fingers: u16 = 0,
    _padding: [3]u16 = @splat(0),

    pub const to_c_ptr = c_non_opaque_conversions(VirtualJoystickTouchpadDesc, C.SDL_VirtualJoystickTouchpadDesc).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(VirtualJoystickTouchpadDesc, C.SDL_VirtualJoystickTouchpadDesc).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(VirtualJoystickTouchpadDesc, C.SDL_VirtualJoystickTouchpadDesc).to_c;
    pub const from_c = c_non_opaque_conversions(VirtualJoystickTouchpadDesc, C.SDL_VirtualJoystickTouchpadDesc).from_c;
};

pub const VirtualJoystickSensorDesc = extern struct {
    type: SensorType = .UNKNOWN,
    rate: f32 = 0.0,

    pub const to_c_ptr = c_non_opaque_conversions(VirtualJoystickSensorDesc, C.SDL_VirtualJoystickSensorDesc).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(VirtualJoystickSensorDesc, C.SDL_VirtualJoystickSensorDesc).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(VirtualJoystickSensorDesc, C.SDL_VirtualJoystickSensorDesc).to_c;
    pub const from_c = c_non_opaque_conversions(VirtualJoystickSensorDesc, C.SDL_VirtualJoystickSensorDesc).from_c;
};

pub const VirtualJoystickDesc = extern struct {
    version: u32 = 0,
    type: u16 = 0,
    _padding: u16 = 0,
    vendor_id: HID_VendorCode = .{},
    product_id: HID_ProductCode = .{},
    num_axes: u16 = 0,
    num_buttons: u16 = 0,
    num_balls: u16 = 0,
    num_hats: u16 = 0,
    num_touchpads: u16 = 0,
    num_sensors: u16 = 0,
    _padding2: [2]u16 = @splat(0),
    button_mask: u32 = 0,
    axis_mask: u32 = 0,
    name: ?[*:0]const u8 = null,
    touchpads: ?[*:0]const VirtualJoystickTouchpadDesc = null,
    sensors: ?[*:0]const VirtualJoystickSensorDesc = null,
    userdata: ?*anyopaque = null,
    update: ?*const fn (userdata: ?*anyopaque) callconv(.c) void = null,
    set_player_index: ?*const fn (userdata: ?*anyopaque, player_index: c_int) callconv(.c) void = null,
    rumble: ?*const fn (userdata: ?*anyopaque, low_freq: u16, high_freq: u16) callconv(.c) bool = null,
    rumble_triggers: ?*const fn (userdata: ?*anyopaque, left_trigger: u16, right_trigger: u16) callconv(.c) bool = null,
    set_LED: ?*const fn (userdata: ?*anyopaque, red: u8, green: u8, blue: u8) callconv(.c) bool = null,
    send_effect: ?*const fn (userdata: ?*anyopaque, effect_data: ?*const anyopaque, effect_data_len: c_int) callconv(.c) bool = null,
    set_sensors_enabled: ?*const fn (userdata: ?*anyopaque, enabled: bool) callconv(.c) bool = null,
    cleanup: ?*const fn (userdata: ?*anyopaque) callconv(.c) void = null,

    pub const to_c_ptr = c_non_opaque_conversions(VirtualJoystickDesc, C.SDL_VirtualJoystickDesc).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(VirtualJoystickDesc, C.SDL_VirtualJoystickDesc).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(VirtualJoystickDesc, C.SDL_VirtualJoystickDesc).to_c;
    pub const from_c = c_non_opaque_conversions(VirtualJoystickDesc, C.SDL_VirtualJoystickDesc).from_c;
};

pub const HID_InitHandle = extern struct {
    is_open: bool = false,

    pub inline fn open() Error!HID_InitHandle {
        _ = try greater_than_or_equal_to_zero_or_fail_err(C.SDL_hid_init());
        return HID_InitHandle{ .is_open = true };
    }
    pub inline fn close(self: *HID_InitHandle) Error!void {
        _ = try greater_than_or_equal_to_zero_or_fail_err(C.SDL_hid_exit());
        self.is_open = false;
    }
};

pub const HID_DeviceChangeTracker = extern struct {
    counter: u32 = 0,
    changed_this_frame: bool = false,

    pub inline fn new() HID_DeviceChangeTracker {
        return HID_DeviceChangeTracker{ .counter = 0, .changed_this_frame = false };
    }

    pub inline fn check_for_changes(self: *HID_DeviceChangeTracker) void {
        const old_count = self.prev_count;
        self.prev_count = C.SDL_hid_device_change_count();
        self.changed_this_frame = self.changed_this_frame or (old_count != self.counter);
    }
    pub inline fn start_new_frame(self: *HID_DeviceChangeTracker) void {
        self.changed_this_frame = false;
    }
    pub inline fn start_new_frame_and_check_for_changes(self: *HID_DeviceChangeTracker) void {
        const old_count = self.prev_count;
        self.prev_count = C.SDL_hid_device_change_count();
        self.changed_this_frame = old_count != self.counter;
    }
};

pub const HID_Device = opaque {
    pub const to_c_ptr = c_opaque_conversions(HID_Device, C.SDL_hid_device).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(HID_Device, C.SDL_hid_device).from_c_ptr;
    //TODO
    // pub extern fn SDL_hid_open(vendor_id: c_ushort, product_id: c_ushort, serial_number: [*c]const wchar_t) ?*SDL_hid_device;
    // pub extern fn SDL_hid_open_path(path: [*c]const u8) ?*SDL_hid_device;
    // pub extern fn SDL_hid_write(dev: ?*SDL_hid_device, data: [*c]const u8, length: usize) c_int;
    // pub extern fn SDL_hid_read_timeout(dev: ?*SDL_hid_device, data: [*c]u8, length: usize, milliseconds: c_int) c_int;
    // pub extern fn SDL_hid_read(dev: ?*SDL_hid_device, data: [*c]u8, length: usize) c_int;
    // pub extern fn SDL_hid_set_nonblocking(dev: ?*SDL_hid_device, nonblock: c_int) c_int;
    // pub extern fn SDL_hid_send_feature_report(dev: ?*SDL_hid_device, data: [*c]const u8, length: usize) c_int;
    // pub extern fn SDL_hid_get_feature_report(dev: ?*SDL_hid_device, data: [*c]u8, length: usize) c_int;
    // pub extern fn SDL_hid_get_input_report(dev: ?*SDL_hid_device, data: [*c]u8, length: usize) c_int;
    // pub extern fn SDL_hid_close(dev: ?*SDL_hid_device) c_int;
    // pub extern fn SDL_hid_get_manufacturer_string(dev: ?*SDL_hid_device, string: [*c]wchar_t, maxlen: usize) c_int;
    // pub extern fn SDL_hid_get_product_string(dev: ?*SDL_hid_device, string: [*c]wchar_t, maxlen: usize) c_int;
    // pub extern fn SDL_hid_get_serial_number_string(dev: ?*SDL_hid_device, string: [*c]wchar_t, maxlen: usize) c_int;
    // pub extern fn SDL_hid_get_indexed_string(dev: ?*SDL_hid_device, string_index: c_int, string: [*c]wchar_t, maxlen: usize) c_int;
    // pub extern fn SDL_hid_get_device_info(dev: ?*SDL_hid_device) [*c]SDL_hid_device_info;
    // pub extern fn SDL_hid_get_report_descriptor(dev: ?*SDL_hid_device, buf: [*c]u8, buf_size: usize) c_int;
    // pub extern fn SDL_hid_ble_scan(active: bool) void;
};

pub const HID_BusType = enum(C.SDL_hid_bus_type) {
    UNKNOWN = C.SDL_HID_API_BUS_UNKNOWN,
    USB = C.SDL_HID_API_BUS_USB,
    BLUETOOTH = C.SDL_HID_API_BUS_BLUETOOTH,
    I2C = C.SDL_HID_API_BUS_I2C,
    SPI = C.SDL_HID_API_BUS_SPI,

    pub const to_c = c_enum_conversions(HID_BusType, C.SDL_hid_bus_type).to_c;
    pub const from_c = c_enum_conversions(HID_BusType, C.SDL_hid_bus_type).from_c;
};

pub const HID_DeviceInfo = extern struct {
    path: ?[*:0]u8 = null,
    vendor_id: c_ushort = 0,
    product_id: c_ushort = 0,
    serial_number: ?[*:0]C.wchar_t = null,
    release_number: c_ushort = 0,
    manufacturer_string: ?[*:0]C.wchar_t = null,
    product_string: ?[*:0]C.wchar_t = null,
    usage_page: c_ushort = 0,
    usage: c_ushort = 0,
    interface_number: c_int = 0,
    interface_class: c_int = 0,
    interface_subclass: c_int = 0,
    interface_protocol: c_int = 0,
    bus_type: HID_BusType = .UNKNOWN,
    next: ?*HID_DeviceInfo = null,

    pub const to_c_ptr = c_non_opaque_conversions(HID_DeviceInfo, C.SDL_hid_device_info).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(HID_DeviceInfo, C.SDL_hid_device_info).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(HID_DeviceInfo, C.SDL_hid_device_info).to_c;
    pub const from_c = c_non_opaque_conversions(HID_DeviceInfo, C.SDL_hid_device_info).from_c;
};

pub const HID_List = struct {
    first: *HID_DeviceInfo,

    pub fn get_all_matching_devices(vendor_code: HID_VendorCode, product_code: HID_ProductCode) Error!HID_List {
        const ptr = try ptr_cast_or_null_err(*HID_DeviceInfo, C.SDL_hid_enumerate(vendor_code.code, product_code.code));
        return HID_List{
            .first = ptr,
        };
    }
    pub fn free(self: HID_List) void {
        C.SDL_hid_free_enumeration(self.first.to_c_ptr());
    }
};

pub const Finger = extern struct {
    id: FingerID = .{},
    position: Vec_f32 = .{},
    pressure: f32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(Finger, C.SDL_Finger).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(Finger, C.SDL_Finger).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(Finger, C.SDL_Finger).to_c;
    pub const from_c = c_non_opaque_conversions(Finger, C.SDL_Finger).from_c;
};

pub const FingerState = extern struct {
    state: KeyButtonState,
    position: Vec_f32,
    pressure: f32,
};

pub const KeyButtonState = enum(u1) {
    UP = 0,
    DOWN = 1,

    pub inline fn is_down(self: KeyButtonState) bool {
        return self.to_bool();
    }
    pub inline fn is_up(self: KeyButtonState) bool {
        return !self.to_bool();
    }

    pub inline fn from_bool(val: bool) KeyButtonState {
        return @enumFromInt(@intFromBool(val));
    }
    pub inline fn to_bool(self: KeyButtonState) bool {
        return @bitCast(@intFromEnum(self));
    }
};

pub const SensorType = enum(c_int) {
    INVALID = C.SDL_SENSOR_INVALID,
    UNKNOWN = C.SDL_SENSOR_UNKNOWN,
    ACCEL = C.SDL_SENSOR_ACCEL,
    GYRO = C.SDL_SENSOR_GYRO,
    ACCEL_L = C.SDL_SENSOR_ACCEL_L,
    GYRO_L = C.SDL_SENSOR_GYRO_L,
    ACCEL_R = C.SDL_SENSOR_ACCEL_R,
    GYRO_R = C.SDL_SENSOR_GYRO_R,

    pub const to_c = c_enum_conversions(SensorType, c_int).to_c;
    pub const from_c = c_enum_conversions(SensorType, c_int).from_c;
};

pub const AxisPosition = extern struct {
    val: i16,

    pub fn to_percent(self: AxisPosition) f32 {
        return @min(-1.0, @max(1.0, @as(f32, @floatFromInt(self.val)) / 32767.0));
    }
    pub fn from_percent(percent: f32) AxisPosition {
        return @intFromFloat(@min(-32767.0, @max(32767.0, percent * 32767.0)));
    }
};

pub const GamepadBindingList = extern struct {
    list: []*GamepadBinding,

    pub fn free(self: GamepadBindingList) void {
        Mem.free(self.list.ptr);
    }
};

pub const GamepadBinding = extern struct {
    input_type: GamepadBindingType,
    input_details: GamepadBindingInput,
    output_type: GamepadBindingType,
    output_details: GamepadBindingOutput,
};
pub const GamepadBindingInput = extern struct {
    button: GamepadButtonInputBinding,
    axis: GamepadAxisInputBinding,
    hat: GamepadHatInputBinding,
};
pub const GamepadBindingOutput = extern struct {
    button: GamepadButtonOutputBinding,
    axis: GamepadAxisOutputBinding,
};
pub const GamepadButtonOutputBinding = extern struct {
    id: GamepadButton,
};
pub const GamepadButtonInputBinding = extern struct {
    id: c_int,
};
pub const GamepadHatInputBinding = extern struct {
    id: c_int,
    mask: c_int,
};
pub const GamepadAxisInputBinding = extern struct {
    axis: c_int,
    min: c_int,
    max: c_int,
};
pub const GamepadAxisOutputBinding = extern struct {
    axis: GamepadAxis,
    min: c_int,
    max: c_int,
};

pub const PowerInfo = extern struct {
    state: PowerState,
    percent: c_int,
};

pub const PowerInfoWithTime = extern struct {
    state: PowerState,
    percent: c_int,
    time_left: c_int,
};

pub const ControllerConnectionState = enum(c_int) {
    INVALID = C.SDL_JOYSTICK_CONNECTION_INVALID,
    UNKNOWN = C.SDL_JOYSTICK_CONNECTION_UNKNOWN,
    WIRED = C.SDL_JOYSTICK_CONNECTION_WIRED,
    WIRELESS = C.SDL_JOYSTICK_CONNECTION_WIRELESS,

    pub const to_c = c_enum_conversions(ControllerConnectionState, c_int).to_c;
    pub const from_c = c_enum_conversions(ControllerConnectionState, c_int).from_c;
};

/// https://partner.steamgames.com/doc/api/ISteamInput#InputHandle_t
pub const SteamHandle = extern struct {
    handle: u64 = 0,

    inline fn new_err(handle: u64) Error!SteamHandle {
        return SteamHandle{ .handle = try nonzero_or_null_err(handle) };
    }
    pub inline fn steam_handle(handle: u64) SteamHandle {
        return SteamHandle{ .handle = handle };
    }
    pub inline fn null_steam_handle() SteamHandle {
        return NULL_HANDLE;
    }
    pub const NULL_HANDLE = SteamHandle{ .handle = 0 };
};

pub const HID_VendorCode = extern struct {
    code: u16 = 0,

    inline fn new(code: u16) HID_VendorCode {
        return HID_VendorCode{ .code = code };
    }
    pub inline fn vendor_code(code: u16) HID_VendorCode {
        return HID_VendorCode{ .code = code };
    }
};
pub const HID_ProductCode = extern struct {
    code: u16 = 0,

    inline fn new(code: u16) HID_ProductCode {
        return HID_ProductCode{ .code = code };
    }
    pub inline fn product_code(code: u16) HID_ProductCode {
        return HID_ProductCode{ .code = code };
    }
};
pub const HID_ProductVersion = extern struct {
    ver: u16 = 0,

    inline fn new(ver: u16) HID_ProductVersion {
        return HID_ProductVersion{ .ver = ver };
    }
    pub inline fn product_version(ver: u16) HID_ProductVersion {
        return HID_ProductVersion{ .ver = ver };
    }
};
pub const HID_FirmwareVersion = extern struct {
    ver: u16 = 0,

    inline fn new(ver: u16) HID_FirmwareVersion {
        return HID_FirmwareVersion{ .ver = ver };
    }
    pub inline fn firmware_version(ver: u16) HID_FirmwareVersion {
        return HID_FirmwareVersion{ .ver = ver };
    }
};
pub const HID_SerialNumber = extern struct {
    serial: [*:0]const u8,

    inline fn new_err(ser: [*c]const u8) Error!HID_SerialNumber {
        return HID_SerialNumber{ .serial = try ptr_cast_or_null_err([*:0]const u8, ser) };
    }
    pub inline fn serial_number(serial: [*:0]const u8) HID_SerialNumber {
        return HID_SerialNumber{ .serial = serial };
    }
};

pub const PlayerIndex = extern struct {
    index: c_int = 0,

    fn new_err(idx: c_int) Error!PlayerIndex {
        return PlayerIndex{ .index = @intCast(try positive_or_null_err(idx)) };
    }

    pub fn player_index(idx: c_int) PlayerIndex {
        return PlayerIndex{ .index = idx };
    }
    pub fn null_player_idx() PlayerIndex {
        return NULL_IDX;
    }
    pub const NULL_IDX = PlayerIndex{ .index = -1 };
};

pub const GamepadsList = struct {
    list: []JoystickID,

    pub fn free(self: GamepadsList) void {
        Mem.free(self.list.ptr);
    }
};

pub const GUID = extern struct {
    data: [16]u8 = @splat(0),

    pub const to_c_ptr = c_non_opaque_conversions(GUID, C.SDL_GUID).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GUID, C.SDL_GUID).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GUID, C.SDL_GUID).to_c;
    pub const from_c = c_non_opaque_conversions(GUID, C.SDL_GUID).from_c;

    // pub extern fn SDL_GUIDToString(guid: SDL_GUID, pszGUID: [*c]u8, cbGUID: c_int) void;
    // pub extern fn SDL_StringToGUID(pchGUID: [*c]const u8) SDL_GUID;
};

pub const CameraID = extern struct {
    id: u32 = 0,
    //TODO
    // pub extern fn SDL_GetNumCameraDrivers() c_int;
    // pub extern fn SDL_GetCameraDriver(index: c_int) [*c]const u8;
    // pub extern fn SDL_GetCurrentCameraDriver() [*c]const u8;
    // pub extern fn SDL_GetCameras(count: [*c]c_int) [*c]SDL_CameraID;
    // pub extern fn SDL_GetCameraSupportedFormats(instance_id: SDL_CameraID, count: [*c]c_int) [*c][*c]SDL_CameraSpec;
    // pub extern fn SDL_GetCameraName(instance_id: SDL_CameraID) [*c]const u8;
    // pub extern fn SDL_GetCameraPosition(instance_id: SDL_CameraID) SDL_CameraPosition;
    // pub extern fn SDL_OpenCamera(instance_id: SDL_CameraID, spec: [*c]const SDL_CameraSpec) ?*SDL_Camera;
};

pub const TouchID = extern struct {
    id: u64 = 0,

    pub const VIRTUAL_FROM_MOUSE = MouseID{ .id = C.SDL_MOUSE_TOUCHID };
    pub const VIRTUAL_FROM_PEN = MouseID{ .id = C.SDL_PEN_TOUCHID };
    //TODO
    // pub extern fn SDL_GetTouchDevices(count: [*c]c_int) [*c]SDL_TouchID;
    // pub extern fn SDL_GetTouchDeviceName(touchID: SDL_TouchID) [*c]const u8;
    // pub extern fn SDL_GetTouchDeviceType(touchID: SDL_TouchID) SDL_TouchDeviceType;
    // pub extern fn SDL_GetTouchFingers(touchID: SDL_TouchID, count: [*c]c_int) [*c][*c]SDL_Finger;
};

pub const FingerID = extern struct {
    id: u64 = 0,
};

pub const PenInputFlags = Flags(enum(u32) {
    DOWN = C.SDL_PEN_INPUT_DOWN,
    BUTTON_1 = C.SDL_PEN_INPUT_BUTTON_1,
    BUTTON_2 = C.SDL_PEN_INPUT_BUTTON_2,
    BUTTON_3 = C.SDL_PEN_INPUT_BUTTON_3,
    BUTTON_4 = C.SDL_PEN_INPUT_BUTTON_4,
    BUTTON_5 = C.SDL_PEN_INPUT_BUTTON_5,
    ERASER_TIP = C.SDL_PEN_INPUT_ERASER_TIP,
    _,
}, enum(u32) {});

pub const Mouse = struct {
    //TODO
    // pub extern fn SDL_HasMouse() bool;
    // pub extern fn SDL_GetMice(count: [*c]c_int) [*c]SDL_MouseID;
    // pub extern fn SDL_GetMouseFocus() ?*SDL_Window;
    // pub extern fn SDL_GetMouseState(x: [*c]f32, y: [*c]f32) SDL_MouseButtonFlags;
    // pub extern fn SDL_GetGlobalMouseState(x: [*c]f32, y: [*c]f32) SDL_MouseButtonFlags;
    // pub extern fn SDL_GetRelativeMouseState(x: [*c]f32, y: [*c]f32) SDL_MouseButtonFlags;
    // pub extern fn SDL_WarpMouseGlobal(x: f32, y: f32) bool;
    // pub extern fn SDL_CaptureMouse(enabled: bool) bool;
};

pub const PenAxis = enum(C.SDL_PenAxis) {
    PRESSURE = C.SDL_PEN_AXIS_PRESSURE,
    X_TILT = C.SDL_PEN_AXIS_XTILT,
    Y_TILT = C.SDL_PEN_AXIS_YTILT,
    DISTANCE = C.SDL_PEN_AXIS_DISTANCE,
    ROTATION = C.SDL_PEN_AXIS_ROTATION,
    SLIDER = C.SDL_PEN_AXIS_SLIDER,
    TANGENTIAL_PRESSURE = C.SDL_PEN_AXIS_TANGENTIAL_PRESSURE,

    pub const AXIS_COUNT: c_uint = C.SDL_PEN_AXIS_COUNT;

    pub const to_c = c_enum_conversions(PenAxis, C.SDL_PenAxis).to_c;
    pub const from_c = c_enum_conversions(PenAxis, C.SDL_PenAxis).from_c;
};

pub const MouseWheelDirection = enum(C.SDL_MouseWheelDirection) {
    NORMAL = C.SDL_MOUSEWHEEL_NORMAL,
    FLIPPED = C.SDL_MOUSEWHEEL_FLIPPED,

    pub const to_c = c_enum_conversions(MouseWheelDirection, C.SDL_MouseWheelDirection).to_c;
    pub const from_c = c_enum_conversions(MouseWheelDirection, C.SDL_MouseWheelDirection).from_c;
};

pub const PowerState = enum(c_int) {
    ERROR = C.SDL_POWERSTATE_ERROR,
    UNKNOWN = C.SDL_POWERSTATE_UNKNOWN,
    ON_BATTERY = C.SDL_POWERSTATE_ON_BATTERY,
    NO_BATTERY = C.SDL_POWERSTATE_NO_BATTERY,
    CHARGING = C.SDL_POWERSTATE_CHARGING,
    CHARGED = C.SDL_POWERSTATE_CHARGED,

    pub const to_c = c_enum_conversions(PowerState, c_int).to_c;
    pub const from_c = c_enum_conversions(PowerState, c_int).from_c;
    //TODO
    // pub fn get_power_info() PowerInfoWithTime {
    //     pub extern fn SDL_GetPowerInfo(seconds: [*c]c_int, percent: [*c]c_int) SDL_PowerState;
    // }

};

pub const EventAction = enum(C.SDL_EventAction) {
    ADD_EVENT = C.SDL_ADDEVENT,
    PEEK_EVENT = C.SDL_PEEKEVENT,
    GET_EVENT = C.SDL_GETEVENT,

    pub const to_c = c_enum_conversions(EventAction, C.SDL_EventAction).to_c;
    pub const from_c = c_enum_conversions(EventAction, C.SDL_EventAction).from_c;
};

pub const EventType = enum(C.SDL_EventType) {
    NONE = 0,
    QUIT = C.SDL_EVENT_QUIT,
    TERMINATING = C.SDL_EVENT_TERMINATING,
    LOW_MEMORY = C.SDL_EVENT_LOW_MEMORY,
    WILL_ENTER_BACKGROUND = C.SDL_EVENT_WILL_ENTER_BACKGROUND,
    DID_ENTER_BACKGROUND = C.SDL_EVENT_DID_ENTER_BACKGROUND,
    WILL_ENTER_FOREGROUND = C.SDL_EVENT_WILL_ENTER_FOREGROUND,
    DID_ENTER_FOREGROUND = C.SDL_EVENT_DID_ENTER_FOREGROUND,
    LOCALE_CHANGED = C.SDL_EVENT_LOCALE_CHANGED,
    SYSTEM_THEME_CHANGED = C.SDL_EVENT_SYSTEM_THEME_CHANGED,
    DISPLAY_ORIENTATION = C.SDL_EVENT_DISPLAY_ORIENTATION,
    DISPLAY_ADDED = C.SDL_EVENT_DISPLAY_ADDED,
    DISPLAY_REMOVED = C.SDL_EVENT_DISPLAY_REMOVED,
    DISPLAY_MOVED = C.SDL_EVENT_DISPLAY_MOVED,
    DISPLAY_DESKTOP_MODE_CHANGED = C.SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED,
    DISPLAY_CURRENT_MODE_CHANGED = C.SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED,
    DISPLAY_CONTENT_SCALE_CHANGED = C.SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED,
    WINDOW_SHOWN = C.SDL_EVENT_WINDOW_SHOWN,
    WINDOW_HIDDEN = C.SDL_EVENT_WINDOW_HIDDEN,
    WINDOW_EXPOSED = C.SDL_EVENT_WINDOW_EXPOSED,
    WINDOW_MOVED = C.SDL_EVENT_WINDOW_MOVED,
    WINDOW_RESIZED = C.SDL_EVENT_WINDOW_RESIZED,
    WINDOW_PIXEL_SIZE_CHANGED = C.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
    WINDOW_METAL_VIEW_RESIZED = C.SDL_EVENT_WINDOW_METAL_VIEW_RESIZED,
    WINDOW_MINIMIZED = C.SDL_EVENT_WINDOW_MINIMIZED,
    WINDOW_MAXIMIZED = C.SDL_EVENT_WINDOW_MAXIMIZED,
    WINDOW_RESTORED = C.SDL_EVENT_WINDOW_RESTORED,
    WINDOW_MOUSE_ENTER = C.SDL_EVENT_WINDOW_MOUSE_ENTER,
    WINDOW_MOUSE_LEAVE = C.SDL_EVENT_WINDOW_MOUSE_LEAVE,
    WINDOW_FOCUS_GAINED = C.SDL_EVENT_WINDOW_FOCUS_GAINED,
    WINDOW_FOCUS_LOST = C.SDL_EVENT_WINDOW_FOCUS_LOST,
    WINDOW_CLOSE_REQUESTED = C.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
    WINDOW_HIT_TEST = C.SDL_EVENT_WINDOW_HIT_TEST,
    WINDOW_ICCPROF_CHANGED = C.SDL_EVENT_WINDOW_ICCPROF_CHANGED,
    WINDOW_DISPLAY_CHANGED = C.SDL_EVENT_WINDOW_DISPLAY_CHANGED,
    WINDOW_DISPLAY_SCALE_CHANGED = C.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED,
    WINDOW_SAFE_AREA_CHANGED = C.SDL_EVENT_WINDOW_SAFE_AREA_CHANGED,
    WINDOW_OCCLUDED = C.SDL_EVENT_WINDOW_OCCLUDED,
    WINDOW_ENTER_FULLSCREEN = C.SDL_EVENT_WINDOW_ENTER_FULLSCREEN,
    WINDOW_LEAVE_FULLSCREEN = C.SDL_EVENT_WINDOW_LEAVE_FULLSCREEN,
    WINDOW_DESTROYED = C.SDL_EVENT_WINDOW_DESTROYED,
    WINDOW_HDR_STATE_CHANGED = C.SDL_EVENT_WINDOW_HDR_STATE_CHANGED,
    KEY_DOWN = C.SDL_EVENT_KEY_DOWN,
    KEY_UP = C.SDL_EVENT_KEY_UP,
    TEXT_EDITING = C.SDL_EVENT_TEXT_EDITING,
    TEXT_INPUT = C.SDL_EVENT_TEXT_INPUT,
    KEYMAP_CHANGED = C.SDL_EVENT_KEYMAP_CHANGED,
    KEYBOARD_ADDED = C.SDL_EVENT_KEYBOARD_ADDED,
    KEYBOARD_REMOVED = C.SDL_EVENT_KEYBOARD_REMOVED,
    TEXT_EDITING_CANDIDATES = C.SDL_EVENT_TEXT_EDITING_CANDIDATES,
    MOUSE_MOTION = C.SDL_EVENT_MOUSE_MOTION,
    MOUSE_BUTTON_DOWN = C.SDL_EVENT_MOUSE_BUTTON_DOWN,
    MOUSE_BUTTON_UP = C.SDL_EVENT_MOUSE_BUTTON_UP,
    MOUSE_WHEEL = C.SDL_EVENT_MOUSE_WHEEL,
    MOUSE_ADDED = C.SDL_EVENT_MOUSE_ADDED,
    MOUSE_REMOVED = C.SDL_EVENT_MOUSE_REMOVED,
    JOYSTICK_AXIS_MOTION = C.SDL_EVENT_JOYSTICK_AXIS_MOTION,
    JOYSTICK_BALL_MOTION = C.SDL_EVENT_JOYSTICK_BALL_MOTION,
    JOYSTICK_HAT_MOTION = C.SDL_EVENT_JOYSTICK_HAT_MOTION,
    JOYSTICK_BUTTON_DOWN = C.SDL_EVENT_JOYSTICK_BUTTON_DOWN,
    JOYSTICK_BUTTON_UP = C.SDL_EVENT_JOYSTICK_BUTTON_UP,
    JOYSTICK_ADDED = C.SDL_EVENT_JOYSTICK_ADDED,
    JOYSTICK_REMOVED = C.SDL_EVENT_JOYSTICK_REMOVED,
    JOYSTICK_BATTERY_UPDATED = C.SDL_EVENT_JOYSTICK_BATTERY_UPDATED,
    JOYSTICK_UPDATE_COMPLETE = C.SDL_EVENT_JOYSTICK_UPDATE_COMPLETE,
    GAMEPAD_AXIS_MOTION = C.SDL_EVENT_GAMEPAD_AXIS_MOTION,
    GAMEPAD_BUTTON_DOWN = C.SDL_EVENT_GAMEPAD_BUTTON_DOWN,
    GAMEPAD_BUTTON_UP = C.SDL_EVENT_GAMEPAD_BUTTON_UP,
    GAMEPAD_ADDED = C.SDL_EVENT_GAMEPAD_ADDED,
    GAMEPAD_REMOVED = C.SDL_EVENT_GAMEPAD_REMOVED,
    GAMEPAD_REMAPPED = C.SDL_EVENT_GAMEPAD_REMAPPED,
    GAMEPAD_TOUCHPAD_DOWN = C.SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN,
    GAMEPAD_TOUCHPAD_MOTION = C.SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION,
    GAMEPAD_TOUCHPAD_UP = C.SDL_EVENT_GAMEPAD_TOUCHPAD_UP,
    GAMEPAD_SENSOR_UPDATE = C.SDL_EVENT_GAMEPAD_SENSOR_UPDATE,
    GAMEPAD_UPDATE_COMPLETE = C.SDL_EVENT_GAMEPAD_UPDATE_COMPLETE,
    GAMEPAD_STEAM_HANDLE_UPDATED = C.SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED,
    FINGER_DOWN = C.SDL_EVENT_FINGER_DOWN,
    FINGER_UP = C.SDL_EVENT_FINGER_UP,
    FINGER_MOTION = C.SDL_EVENT_FINGER_MOTION,
    FINGER_CANCELED = C.SDL_EVENT_FINGER_CANCELED,
    CLIPBOARD_UPDATE = C.SDL_EVENT_CLIPBOARD_UPDATE,
    DROP_FILE = C.SDL_EVENT_DROP_FILE,
    DROP_TEXT = C.SDL_EVENT_DROP_TEXT,
    DROP_BEGIN = C.SDL_EVENT_DROP_BEGIN,
    DROP_COMPLETE = C.SDL_EVENT_DROP_COMPLETE,
    DROP_POSITION = C.SDL_EVENT_DROP_POSITION,
    AUDIO_DEVICE_ADDED = C.SDL_EVENT_AUDIO_DEVICE_ADDED,
    AUDIO_DEVICE_REMOVED = C.SDL_EVENT_AUDIO_DEVICE_REMOVED,
    AUDIO_DEVICE_FORMAT_CHANGED = C.SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED,
    SENSOR_UPDATE = C.SDL_EVENT_SENSOR_UPDATE,
    PEN_PROXIMITY_IN = C.SDL_EVENT_PEN_PROXIMITY_IN,
    PEN_PROXIMITY_OUT = C.SDL_EVENT_PEN_PROXIMITY_OUT,
    PEN_DOWN = C.SDL_EVENT_PEN_DOWN,
    PEN_UP = C.SDL_EVENT_PEN_UP,
    PEN_BUTTON_DOWN = C.SDL_EVENT_PEN_BUTTON_DOWN,
    PEN_BUTTON_UP = C.SDL_EVENT_PEN_BUTTON_UP,
    PEN_MOTION = C.SDL_EVENT_PEN_MOTION,
    PEN_AXIS = C.SDL_EVENT_PEN_AXIS,
    CAMERA_DEVICE_ADDED = C.SDL_EVENT_CAMERA_DEVICE_ADDED,
    CAMERA_DEVICE_REMOVED = C.SDL_EVENT_CAMERA_DEVICE_REMOVED,
    CAMERA_DEVICE_APPROVED = C.SDL_EVENT_CAMERA_DEVICE_APPROVED,
    CAMERA_DEVICE_DENIED = C.SDL_EVENT_CAMERA_DEVICE_DENIED,
    RENDER_TARGETS_RESET = C.SDL_EVENT_RENDER_TARGETS_RESET,
    RENDER_DEVICE_RESET = C.SDL_EVENT_RENDER_DEVICE_RESET,
    RENDER_DEVICE_LOST = C.SDL_EVENT_RENDER_DEVICE_LOST,
    PRIVATE0 = C.SDL_EVENT_PRIVATE0,
    PRIVATE1 = C.SDL_EVENT_PRIVATE1,
    PRIVATE2 = C.SDL_EVENT_PRIVATE2,
    PRIVATE3 = C.SDL_EVENT_PRIVATE3,
    POLL_SENTINEL = C.SDL_EVENT_POLL_SENTINEL,
    _,

    pub const SDL_BEGIN = C.SDL_EVENT_FIRST;
    pub const DISPLAY_FIRST = C.SDL_EVENT_DISPLAY_ORIENTATION;
    pub const DISPLAY_LAST = C.SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED;
    pub const WINDOW_FIRST = C.SDL_EVENT_WINDOW_FIRST;
    pub const WINDOW_LAST = C.SDL_EVENT_WINDOW_LAST;
    pub const SDL_END = USER_BEGIN - 1;
    pub const USER_BEGIN = C.SDL_EVENT_USER;
    pub const USER_END = C.SDL_EVENT_LAST;

    pub fn user_event_int(int: u32) EventType {
        assert(int >= USER_BEGIN and int <= USER_END);
        return @enumFromInt(int);
    }
    pub fn user_event(comptime E: type, val: E) EventType {
        const int = @intFromEnum(val);
        assert(int >= USER_BEGIN and int <= USER_END);
        return @enumFromInt(@as(u32, @intCast(int)));
    }

    pub const to_c = c_enum_conversions(EventType, C.SDL_EventType).to_c;
    pub const from_c = c_enum_conversions(EventType, C.SDL_EventType).from_c;
};

pub const Scancode = enum(C.SDL_Scancode) {
    UNKNOWN = C.SDL_SCANCODE_UNKNOWN,
    A = C.SDL_SCANCODE_A,
    B = C.SDL_SCANCODE_B,
    C = C.SDL_SCANCODE_C,
    D = C.SDL_SCANCODE_D,
    E = C.SDL_SCANCODE_E,
    F = C.SDL_SCANCODE_F,
    G = C.SDL_SCANCODE_G,
    H = C.SDL_SCANCODE_H,
    I = C.SDL_SCANCODE_I,
    K = C.SDL_SCANCODE_K,
    L = C.SDL_SCANCODE_L,
    M = C.SDL_SCANCODE_M,
    N = C.SDL_SCANCODE_N,
    O = C.SDL_SCANCODE_O,
    P = C.SDL_SCANCODE_P,
    Q = C.SDL_SCANCODE_Q,
    R = C.SDL_SCANCODE_R,
    S = C.SDL_SCANCODE_S,
    T = C.SDL_SCANCODE_T,
    U = C.SDL_SCANCODE_U,
    V = C.SDL_SCANCODE_V,
    W = C.SDL_SCANCODE_W,
    X = C.SDL_SCANCODE_X,
    Y = C.SDL_SCANCODE_Y,
    Z = C.SDL_SCANCODE_Z,
    _1 = C.SDL_SCANCODE_1,
    _2 = C.SDL_SCANCODE_2,
    _3 = C.SDL_SCANCODE_3,
    _4 = C.SDL_SCANCODE_4,
    _5 = C.SDL_SCANCODE_5,
    _6 = C.SDL_SCANCODE_6,
    _7 = C.SDL_SCANCODE_7,
    _8 = C.SDL_SCANCODE_8,
    _9 = C.SDL_SCANCODE_9,
    _0 = C.SDL_SCANCODE_0,
    RETURN = C.SDL_SCANCODE_RETURN,
    ESCAPE = C.SDL_SCANCODE_ESCAPE,
    BACKSPACE = C.SDL_SCANCODE_BACKSPACE,
    TAB = C.SDL_SCANCODE_TAB,
    SPACE = C.SDL_SCANCODE_SPACE,
    MINUS = C.SDL_SCANCODE_MINUS,
    EQUALS = C.SDL_SCANCODE_EQUALS,
    LEFTBRACKET = C.SDL_SCANCODE_LEFTBRACKET,
    RIGHTBRACKET = C.SDL_SCANCODE_RIGHTBRACKET,
    BACKSLASH = C.SDL_SCANCODE_BACKSLASH,
    NONUSHASH = C.SDL_SCANCODE_NONUSHASH,
    SEMICOLON = C.SDL_SCANCODE_SEMICOLON,
    APOSTROPHE = C.SDL_SCANCODE_APOSTROPHE,
    GRAVE = C.SDL_SCANCODE_GRAVE,
    COMMA = C.SDL_SCANCODE_COMMA,
    PERIOD = C.SDL_SCANCODE_PERIOD,
    SLASH = C.SDL_SCANCODE_SLASH,
    CAPSLOCK = C.SDL_SCANCODE_CAPSLOCK,
    F1 = C.SDL_SCANCODE_F1,
    F2 = C.SDL_SCANCODE_F2,
    F3 = C.SDL_SCANCODE_F3,
    F4 = C.SDL_SCANCODE_F4,
    F5 = C.SDL_SCANCODE_F5,
    F6 = C.SDL_SCANCODE_F6,
    F7 = C.SDL_SCANCODE_F7,
    F8 = C.SDL_SCANCODE_F8,
    F9 = C.SDL_SCANCODE_F9,
    F10 = C.SDL_SCANCODE_F10,
    F11 = C.SDL_SCANCODE_F11,
    F12 = C.SDL_SCANCODE_F12,
    PRINTSCREEN = C.SDL_SCANCODE_PRINTSCREEN,
    SCROLLLOCK = C.SDL_SCANCODE_SCROLLLOCK,
    PAUSE = C.SDL_SCANCODE_PAUSE,
    INSERT = C.SDL_SCANCODE_INSERT,
    HOME = C.SDL_SCANCODE_HOME,
    PAGEUP = C.SDL_SCANCODE_PAGEUP,
    DELETE = C.SDL_SCANCODE_DELETE,
    END = C.SDL_SCANCODE_END,
    PAGEDOWN = C.SDL_SCANCODE_PAGEDOWN,
    RIGHT = C.SDL_SCANCODE_RIGHT,
    LEFT = C.SDL_SCANCODE_LEFT,
    DOWN = C.SDL_SCANCODE_DOWN,
    UP = C.SDL_SCANCODE_UP,
    NUMLOCKCLEAR = C.SDL_SCANCODE_NUMLOCKCLEAR,
    KP_DIVIDE = C.SDL_SCANCODE_KP_DIVIDE,
    KP_MULTIPLY = C.SDL_SCANCODE_KP_MULTIPLY,
    KP_MINUS = C.SDL_SCANCODE_KP_MINUS,
    KP_PLUS = C.SDL_SCANCODE_KP_PLUS,
    KP_ENTER = C.SDL_SCANCODE_KP_ENTER,
    KP_1 = C.SDL_SCANCODE_KP_1,
    KP_2 = C.SDL_SCANCODE_KP_2,
    KP_3 = C.SDL_SCANCODE_KP_3,
    KP_4 = C.SDL_SCANCODE_KP_4,
    KP_5 = C.SDL_SCANCODE_KP_5,
    KP_6 = C.SDL_SCANCODE_KP_6,
    KP_7 = C.SDL_SCANCODE_KP_7,
    KP_8 = C.SDL_SCANCODE_KP_8,
    KP_9 = C.SDL_SCANCODE_KP_9,
    KP_0 = C.SDL_SCANCODE_KP_0,
    KP_PERIOD = C.SDL_SCANCODE_KP_PERIOD,
    NONUSBACKSLASH = C.SDL_SCANCODE_NONUSBACKSLASH,
    APPLICATION = C.SDL_SCANCODE_APPLICATION,
    POWER = C.SDL_SCANCODE_POWER,
    KP_EQUALS = C.SDL_SCANCODE_KP_EQUALS,
    F13 = C.SDL_SCANCODE_F13,
    F14 = C.SDL_SCANCODE_F14,
    F15 = C.SDL_SCANCODE_F15,
    F16 = C.SDL_SCANCODE_F16,
    F17 = C.SDL_SCANCODE_F17,
    F18 = C.SDL_SCANCODE_F18,
    F19 = C.SDL_SCANCODE_F19,
    F20 = C.SDL_SCANCODE_F20,
    F21 = C.SDL_SCANCODE_F21,
    F22 = C.SDL_SCANCODE_F22,
    F23 = C.SDL_SCANCODE_F23,
    F24 = C.SDL_SCANCODE_F24,
    EXECUTE = C.SDL_SCANCODE_EXECUTE,
    HELP = C.SDL_SCANCODE_HELP,
    MENU = C.SDL_SCANCODE_MENU,
    SELECT = C.SDL_SCANCODE_SELECT,
    STOP = C.SDL_SCANCODE_STOP,
    AGAIN = C.SDL_SCANCODE_AGAIN,
    UNDO = C.SDL_SCANCODE_UNDO,
    CUT = C.SDL_SCANCODE_CUT,
    COPY = C.SDL_SCANCODE_COPY,
    PASTE = C.SDL_SCANCODE_PASTE,
    FIND = C.SDL_SCANCODE_FIND,
    MUTE = C.SDL_SCANCODE_MUTE,
    VOLUMEUP = C.SDL_SCANCODE_VOLUMEUP,
    VOLUMEDOWN = C.SDL_SCANCODE_VOLUMEDOWN,
    KP_COMMA = C.SDL_SCANCODE_KP_COMMA,
    KP_EQUALSAS400 = C.SDL_SCANCODE_KP_EQUALSAS400,
    INTERNATIONAL1 = C.SDL_SCANCODE_INTERNATIONAL1,
    INTERNATIONAL2 = C.SDL_SCANCODE_INTERNATIONAL2,
    INTERNATIONAL3 = C.SDL_SCANCODE_INTERNATIONAL3,
    INTERNATIONAL4 = C.SDL_SCANCODE_INTERNATIONAL4,
    INTERNATIONAL5 = C.SDL_SCANCODE_INTERNATIONAL5,
    INTERNATIONAL6 = C.SDL_SCANCODE_INTERNATIONAL6,
    INTERNATIONAL7 = C.SDL_SCANCODE_INTERNATIONAL7,
    INTERNATIONAL8 = C.SDL_SCANCODE_INTERNATIONAL8,
    INTERNATIONAL9 = C.SDL_SCANCODE_INTERNATIONAL9,
    LANG1 = C.SDL_SCANCODE_LANG1,
    LANG2 = C.SDL_SCANCODE_LANG2,
    LANG3 = C.SDL_SCANCODE_LANG3,
    LANG4 = C.SDL_SCANCODE_LANG4,
    LANG5 = C.SDL_SCANCODE_LANG5,
    LANG6 = C.SDL_SCANCODE_LANG6,
    LANG7 = C.SDL_SCANCODE_LANG7,
    LANG8 = C.SDL_SCANCODE_LANG8,
    LANG9 = C.SDL_SCANCODE_LANG9,
    ALTERASE = C.SDL_SCANCODE_ALTERASE,
    SYSREQ = C.SDL_SCANCODE_SYSREQ,
    CANCEL = C.SDL_SCANCODE_CANCEL,
    CLEAR = C.SDL_SCANCODE_CLEAR,
    PRIOR = C.SDL_SCANCODE_PRIOR,
    RETURN2 = C.SDL_SCANCODE_RETURN2,
    SEPARATOR = C.SDL_SCANCODE_SEPARATOR,
    OUT = C.SDL_SCANCODE_OUT,
    OPER = C.SDL_SCANCODE_OPER,
    CLEARAGAIN = C.SDL_SCANCODE_CLEARAGAIN,
    CRSEL = C.SDL_SCANCODE_CRSEL,
    EXSEL = C.SDL_SCANCODE_EXSEL,
    KP_00 = C.SDL_SCANCODE_KP_00,
    KP_000 = C.SDL_SCANCODE_KP_000,
    THOUSANDSSEPARATOR = C.SDL_SCANCODE_THOUSANDSSEPARATOR,
    DECIMALSEPARATOR = C.SDL_SCANCODE_DECIMALSEPARATOR,
    CURRENCYUNIT = C.SDL_SCANCODE_CURRENCYUNIT,
    CURRENCYSUBUNIT = C.SDL_SCANCODE_CURRENCYSUBUNIT,
    KP_LEFTPAREN = C.SDL_SCANCODE_KP_LEFTPAREN,
    KP_RIGHTPAREN = C.SDL_SCANCODE_KP_RIGHTPAREN,
    KP_LEFTBRACE = C.SDL_SCANCODE_KP_LEFTBRACE,
    KP_RIGHTBRACE = C.SDL_SCANCODE_KP_RIGHTBRACE,
    KP_TAB = C.SDL_SCANCODE_KP_TAB,
    KP_BACKSPACE = C.SDL_SCANCODE_KP_BACKSPACE,
    KP_A = C.SDL_SCANCODE_KP_A,
    KP_B = C.SDL_SCANCODE_KP_B,
    KP_C = C.SDL_SCANCODE_KP_C,
    KP_D = C.SDL_SCANCODE_KP_D,
    KP_E = C.SDL_SCANCODE_KP_E,
    KP_F = C.SDL_SCANCODE_KP_F,
    KP_XOR = C.SDL_SCANCODE_KP_XOR,
    KP_POWER = C.SDL_SCANCODE_KP_POWER,
    KP_PERCENT = C.SDL_SCANCODE_KP_PERCENT,
    KP_LESS = C.SDL_SCANCODE_KP_LESS,
    KP_GREATER = C.SDL_SCANCODE_KP_GREATER,
    KP_AMPERSAND = C.SDL_SCANCODE_KP_AMPERSAND,
    KP_DBLAMPERSAND = C.SDL_SCANCODE_KP_DBLAMPERSAND,
    KP_VERTICALBAR = C.SDL_SCANCODE_KP_VERTICALBAR,
    KP_DBLVERTICALBAR = C.SDL_SCANCODE_KP_DBLVERTICALBAR,
    KP_COLON = C.SDL_SCANCODE_KP_COLON,
    KP_HASH = C.SDL_SCANCODE_KP_HASH,
    KP_SPACE = C.SDL_SCANCODE_KP_SPACE,
    KP_AT = C.SDL_SCANCODE_KP_AT,
    KP_EXCLAM = C.SDL_SCANCODE_KP_EXCLAM,
    KP_MEMSTORE = C.SDL_SCANCODE_KP_MEMSTORE,
    KP_MEMRECALL = C.SDL_SCANCODE_KP_MEMRECALL,
    KP_MEMCLEAR = C.SDL_SCANCODE_KP_MEMCLEAR,
    KP_MEMADD = C.SDL_SCANCODE_KP_MEMADD,
    KP_MEMSUBTRACT = C.SDL_SCANCODE_KP_MEMSUBTRACT,
    KP_MEMMULTIPLY = C.SDL_SCANCODE_KP_MEMMULTIPLY,
    KP_MEMDIVIDE = C.SDL_SCANCODE_KP_MEMDIVIDE,
    KP_PLUSMINUS = C.SDL_SCANCODE_KP_PLUSMINUS,
    KP_CLEAR = C.SDL_SCANCODE_KP_CLEAR,
    KP_CLEARENTRY = C.SDL_SCANCODE_KP_CLEARENTRY,
    KP_BINARY = C.SDL_SCANCODE_KP_BINARY,
    KP_OCTAL = C.SDL_SCANCODE_KP_OCTAL,
    KP_DECIMAL = C.SDL_SCANCODE_KP_DECIMAL,
    KP_HEXADECIMAL = C.SDL_SCANCODE_KP_HEXADECIMAL,
    LCTRL = C.SDL_SCANCODE_LCTRL,
    LSHIFT = C.SDL_SCANCODE_LSHIFT,
    LALT = C.SDL_SCANCODE_LALT,
    LGUI = C.SDL_SCANCODE_LGUI,
    RCTRL = C.SDL_SCANCODE_RCTRL,
    RSHIFT = C.SDL_SCANCODE_RSHIFT,
    RALT = C.SDL_SCANCODE_RALT,
    RGUI = C.SDL_SCANCODE_RGUI,
    MODE = C.SDL_SCANCODE_MODE,
    SLEEP = C.SDL_SCANCODE_SLEEP,
    WAKE = C.SDL_SCANCODE_WAKE,
    CHANNEL_INCREMENT = C.SDL_SCANCODE_CHANNEL_INCREMENT,
    CHANNEL_DECREMENT = C.SDL_SCANCODE_CHANNEL_DECREMENT,
    MEDIA_PLAY = C.SDL_SCANCODE_MEDIA_PLAY,
    MEDIA_PAUSE = C.SDL_SCANCODE_MEDIA_PAUSE,
    MEDIA_RECORD = C.SDL_SCANCODE_MEDIA_RECORD,
    MEDIA_FAST_FORWARD = C.SDL_SCANCODE_MEDIA_FAST_FORWARD,
    MEDIA_REWIND = C.SDL_SCANCODE_MEDIA_REWIND,
    MEDIA_NEXT_TRACK = C.SDL_SCANCODE_MEDIA_NEXT_TRACK,
    MEDIA_PREVIOUS_TRACK = C.SDL_SCANCODE_MEDIA_PREVIOUS_TRACK,
    MEDIA_STOP = C.SDL_SCANCODE_MEDIA_STOP,
    MEDIA_EJECT = C.SDL_SCANCODE_MEDIA_EJECT,
    MEDIA_PLAY_PAUSE = C.SDL_SCANCODE_MEDIA_PLAY_PAUSE,
    MEDIA_SELECT = C.SDL_SCANCODE_MEDIA_SELECT,
    AC_NEW = C.SDL_SCANCODE_AC_NEW,
    AC_OPEN = C.SDL_SCANCODE_AC_OPEN,
    AC_CLOSE = C.SDL_SCANCODE_AC_CLOSE,
    AC_EXIT = C.SDL_SCANCODE_AC_EXIT,
    AC_SAVE = C.SDL_SCANCODE_AC_SAVE,
    AC_PRINT = C.SDL_SCANCODE_AC_PRINT,
    AC_PROPERTIES = C.SDL_SCANCODE_AC_PROPERTIES,
    AC_SEARCH = C.SDL_SCANCODE_AC_SEARCH,
    AC_HOME = C.SDL_SCANCODE_AC_HOME,
    AC_BACK = C.SDL_SCANCODE_AC_BACK,
    AC_FORWARD = C.SDL_SCANCODE_AC_FORWARD,
    AC_STOP = C.SDL_SCANCODE_AC_STOP,
    AC_REFRESH = C.SDL_SCANCODE_AC_REFRESH,
    AC_BOOKMARKS = C.SDL_SCANCODE_AC_BOOKMARKS,
    SOFTLEFT = C.SDL_SCANCODE_SOFTLEFT,
    SOFTRIGHT = C.SDL_SCANCODE_SOFTRIGHT,
    CALL = C.SDL_SCANCODE_CALL,
    ENDCALL = C.SDL_SCANCODE_ENDCALL,
    _,

    pub const RESERVED = C.SDL_SCANCODE_RESERVED;
    pub const COUNT = C.SDL_SCANCODE_COUNT;

    pub const to_c = c_enum_conversions(Scancode, C.SDL_Scancode).to_c;
    pub const from_c = c_enum_conversions(Scancode, C.SDL_Scancode).from_c;

    //TODO
    // pub extern fn SDL_GetKeyFromScancode(scancode: SDL_Scancode, modstate: SDL_Keymod, key_event: bool) SDL_Keycode;
    // pub extern fn SDL_SetScancodeName(scancode: SDL_Scancode, name: [*c]const u8) bool;
    // pub extern fn SDL_GetScancodeName(scancode: SDL_Scancode) [*c]const u8;
};

pub const Keycode = enum(C.SDL_Keycode) {
    UNKNOWN = C.SDLK_UNKNOWN,
    RETURN = C.SDLK_RETURN,
    ESCAPE = C.SDLK_ESCAPE,
    BACKSPACE = C.SDLK_BACKSPACE,
    TAB = C.SDLK_TAB,
    SPACE = C.SDLK_SPACE,
    EXCLAIM = C.SDLK_EXCLAIM,
    DBLAPOSTROPHE = C.SDLK_DBLAPOSTROPHE,
    HASH = C.SDLK_HASH,
    DOLLAR = C.SDLK_DOLLAR,
    PERCENT = C.SDLK_PERCENT,
    AMPERSAND = C.SDLK_AMPERSAND,
    APOSTROPHE = C.SDLK_APOSTROPHE,
    LEFTPAREN = C.SDLK_LEFTPAREN,
    RIGHTPAREN = C.SDLK_RIGHTPAREN,
    ASTERISK = C.SDLK_ASTERISK,
    PLUS = C.SDLK_PLUS,
    COMMA = C.SDLK_COMMA,
    MINUS = C.SDLK_MINUS,
    PERIOD = C.SDLK_PERIOD,
    SLASH = C.SDLK_SLASH,
    _0 = C.SDLK_0,
    _1 = C.SDLK_1,
    _2 = C.SDLK_2,
    _3 = C.SDLK_3,
    _4 = C.SDLK_4,
    _5 = C.SDLK_5,
    _6 = C.SDLK_6,
    _7 = C.SDLK_7,
    _8 = C.SDLK_8,
    _9 = C.SDLK_9,
    COLON = C.SDLK_COLON,
    SEMICOLON = C.SDLK_SEMICOLON,
    LESS = C.SDLK_LESS,
    EQUALS = C.SDLK_EQUALS,
    GREATER = C.SDLK_GREATER,
    QUESTION = C.SDLK_QUESTION,
    AT = C.SDLK_AT,
    LEFTBRACKET = C.SDLK_LEFTBRACKET,
    BACKSLASH = C.SDLK_BACKSLASH,
    RIGHTBRACKET = C.SDLK_RIGHTBRACKET,
    CARET = C.SDLK_CARET,
    UNDERSCORE = C.SDLK_UNDERSCORE,
    GRAVE = C.SDLK_GRAVE,
    A = C.SDLK_A,
    B = C.SDLK_B,
    C = C.SDLK_C,
    D = C.SDLK_D,
    E = C.SDLK_E,
    F = C.SDLK_F,
    G = C.SDLK_G,
    H = C.SDLK_H,
    I = C.SDLK_I,
    J = C.SDLK_J,
    K = C.SDLK_K,
    L = C.SDLK_L,
    M = C.SDLK_M,
    N = C.SDLK_N,
    O = C.SDLK_O,
    P = C.SDLK_P,
    Q = C.SDLK_Q,
    R = C.SDLK_R,
    S = C.SDLK_S,
    T = C.SDLK_T,
    U = C.SDLK_U,
    V = C.SDLK_V,
    W = C.SDLK_W,
    X = C.SDLK_X,
    Y = C.SDLK_Y,
    Z = C.SDLK_Z,
    LEFTBRACE = C.SDLK_LEFTBRACE,
    PIPE = C.SDLK_PIPE,
    RIGHTBRACE = C.SDLK_RIGHTBRACE,
    TILDE = C.SDLK_TILDE,
    DELETE = C.SDLK_DELETE,
    PLUSMINUS = C.SDLK_PLUSMINUS,
    CAPSLOCK = C.SDLK_CAPSLOCK,
    F1 = C.SDLK_F1,
    F2 = C.SDLK_F2,
    F3 = C.SDLK_F3,
    F4 = C.SDLK_F4,
    F5 = C.SDLK_F5,
    F6 = C.SDLK_F6,
    F7 = C.SDLK_F7,
    F8 = C.SDLK_F8,
    F9 = C.SDLK_F9,
    F10 = C.SDLK_F10,
    F11 = C.SDLK_F11,
    F12 = C.SDLK_F12,
    PRINTSCREEN = C.SDLK_PRINTSCREEN,
    SCROLLLOCK = C.SDLK_SCROLLLOCK,
    PAUSE = C.SDLK_PAUSE,
    INSERT = C.SDLK_INSERT,
    HOME = C.SDLK_HOME,
    PAGEUP = C.SDLK_PAGEUP,
    END = C.SDLK_END,
    PAGEDOWN = C.SDLK_PAGEDOWN,
    RIGHT = C.SDLK_RIGHT,
    LEFT = C.SDLK_LEFT,
    DOWN = C.SDLK_DOWN,
    UP = C.SDLK_UP,
    NUMLOCKCLEAR = C.SDLK_NUMLOCKCLEAR,
    KP_DIVIDE = C.SDLK_KP_DIVIDE,
    KP_MULTIPLY = C.SDLK_KP_MULTIPLY,
    KP_MINUS = C.SDLK_KP_MINUS,
    KP_PLUS = C.SDLK_KP_PLUS,
    KP_ENTER = C.SDLK_KP_ENTER,
    KP_1 = C.SDLK_KP_1,
    KP_2 = C.SDLK_KP_2,
    KP_3 = C.SDLK_KP_3,
    KP_4 = C.SDLK_KP_4,
    KP_5 = C.SDLK_KP_5,
    KP_6 = C.SDLK_KP_6,
    KP_7 = C.SDLK_KP_7,
    KP_8 = C.SDLK_KP_8,
    KP_9 = C.SDLK_KP_9,
    KP_0 = C.SDLK_KP_0,
    KP_PERIOD = C.SDLK_KP_PERIOD,
    APPLICATION = C.SDLK_APPLICATION,
    POWER = C.SDLK_POWER,
    KP_EQUALS = C.SDLK_KP_EQUALS,
    F13 = C.SDLK_F13,
    F14 = C.SDLK_F14,
    F15 = C.SDLK_F15,
    F16 = C.SDLK_F16,
    F17 = C.SDLK_F17,
    F18 = C.SDLK_F18,
    F19 = C.SDLK_F19,
    F20 = C.SDLK_F20,
    F21 = C.SDLK_F21,
    F22 = C.SDLK_F22,
    F23 = C.SDLK_F23,
    F24 = C.SDLK_F24,
    EXECUTE = C.SDLK_EXECUTE,
    HELP = C.SDLK_HELP,
    MENU = C.SDLK_MENU,
    SELECT = C.SDLK_SELECT,
    STOP = C.SDLK_STOP,
    AGAIN = C.SDLK_AGAIN,
    UNDO = C.SDLK_UNDO,
    CUT = C.SDLK_CUT,
    COPY = C.SDLK_COPY,
    PASTE = C.SDLK_PASTE,
    FIND = C.SDLK_FIND,
    MUTE = C.SDLK_MUTE,
    VOLUMEUP = C.SDLK_VOLUMEUP,
    VOLUMEDOWN = C.SDLK_VOLUMEDOWN,
    KP_COMMA = C.SDLK_KP_COMMA,
    KP_EQUALSAS400 = C.SDLK_KP_EQUALSAS400,
    ALTERASE = C.SDLK_ALTERASE,
    SYSREQ = C.SDLK_SYSREQ,
    CANCEL = C.SDLK_CANCEL,
    CLEAR = C.SDLK_CLEAR,
    PRIOR = C.SDLK_PRIOR,
    RETURN2 = C.SDLK_RETURN2,
    SEPARATOR = C.SDLK_SEPARATOR,
    OUT = C.SDLK_OUT,
    OPER = C.SDLK_OPER,
    CLEARAGAIN = C.SDLK_CLEARAGAIN,
    CRSEL = C.SDLK_CRSEL,
    EXSEL = C.SDLK_EXSEL,
    KP_00 = C.SDLK_KP_00,
    KP_000 = C.SDLK_KP_000,
    THOUSANDSSEPARATOR = C.SDLK_THOUSANDSSEPARATOR,
    DECIMALSEPARATOR = C.SDLK_DECIMALSEPARATOR,
    CURRENCYUNIT = C.SDLK_CURRENCYUNIT,
    CURRENCYSUBUNIT = C.SDLK_CURRENCYSUBUNIT,
    KP_LEFTPAREN = C.SDLK_KP_LEFTPAREN,
    KP_RIGHTPAREN = C.SDLK_KP_RIGHTPAREN,
    KP_LEFTBRACE = C.SDLK_KP_LEFTBRACE,
    KP_RIGHTBRACE = C.SDLK_KP_RIGHTBRACE,
    KP_TAB = C.SDLK_KP_TAB,
    KP_BACKSPACE = C.SDLK_KP_BACKSPACE,
    KP_A = C.SDLK_KP_A,
    KP_B = C.SDLK_KP_B,
    KP_C = C.SDLK_KP_C,
    KP_D = C.SDLK_KP_D,
    KP_E = C.SDLK_KP_E,
    KP_F = C.SDLK_KP_F,
    KP_XOR = C.SDLK_KP_XOR,
    KP_POWER = C.SDLK_KP_POWER,
    KP_PERCENT = C.SDLK_KP_PERCENT,
    KP_LESS = C.SDLK_KP_LESS,
    KP_GREATER = C.SDLK_KP_GREATER,
    KP_AMPERSAND = C.SDLK_KP_AMPERSAND,
    KP_DBLAMPERSAND = C.SDLK_KP_DBLAMPERSAND,
    KP_VERTICALBAR = C.SDLK_KP_VERTICALBAR,
    KP_DBLVERTICALBAR = C.SDLK_KP_DBLVERTICALBAR,
    KP_COLON = C.SDLK_KP_COLON,
    KP_HASH = C.SDLK_KP_HASH,
    KP_SPACE = C.SDLK_KP_SPACE,
    KP_AT = C.SDLK_KP_AT,
    KP_EXCLAM = C.SDLK_KP_EXCLAM,
    KP_MEMSTORE = C.SDLK_KP_MEMSTORE,
    KP_MEMRECALL = C.SDLK_KP_MEMRECALL,
    KP_MEMCLEAR = C.SDLK_KP_MEMCLEAR,
    KP_MEMADD = C.SDLK_KP_MEMADD,
    KP_MEMSUBTRACT = C.SDLK_KP_MEMSUBTRACT,
    KP_MEMMULTIPLY = C.SDLK_KP_MEMMULTIPLY,
    KP_MEMDIVIDE = C.SDLK_KP_MEMDIVIDE,
    KP_PLUSMINUS = C.SDLK_KP_PLUSMINUS,
    KP_CLEAR = C.SDLK_KP_CLEAR,
    KP_CLEARENTRY = C.SDLK_KP_CLEARENTRY,
    KP_BINARY = C.SDLK_KP_BINARY,
    KP_OCTAL = C.SDLK_KP_OCTAL,
    KP_DECIMAL = C.SDLK_KP_DECIMAL,
    KP_HEXADECIMAL = C.SDLK_KP_HEXADECIMAL,
    LCTRL = C.SDLK_LCTRL,
    LSHIFT = C.SDLK_LSHIFT,
    LALT = C.SDLK_LALT,
    LGUI = C.SDLK_LGUI,
    RCTRL = C.SDLK_RCTRL,
    RSHIFT = C.SDLK_RSHIFT,
    RALT = C.SDLK_RALT,
    RGUI = C.SDLK_RGUI,
    MODE = C.SDLK_MODE,
    SLEEP = C.SDLK_SLEEP,
    WAKE = C.SDLK_WAKE,
    CHANNEL_INCREMENT = C.SDLK_CHANNEL_INCREMENT,
    CHANNEL_DECREMENT = C.SDLK_CHANNEL_DECREMENT,
    MEDIA_PLAY = C.SDLK_MEDIA_PLAY,
    MEDIA_PAUSE = C.SDLK_MEDIA_PAUSE,
    MEDIA_RECORD = C.SDLK_MEDIA_RECORD,
    MEDIA_FAST_FORWARD = C.SDLK_MEDIA_FAST_FORWARD,
    MEDIA_REWIND = C.SDLK_MEDIA_REWIND,
    MEDIA_NEXT_TRACK = C.SDLK_MEDIA_NEXT_TRACK,
    MEDIA_PREVIOUS_TRACK = C.SDLK_MEDIA_PREVIOUS_TRACK,
    MEDIA_STOP = C.SDLK_MEDIA_STOP,
    MEDIA_EJECT = C.SDLK_MEDIA_EJECT,
    MEDIA_PLAY_PAUSE = C.SDLK_MEDIA_PLAY_PAUSE,
    MEDIA_SELECT = C.SDLK_MEDIA_SELECT,
    AC_NEW = C.SDLK_AC_NEW,
    AC_OPEN = C.SDLK_AC_OPEN,
    AC_CLOSE = C.SDLK_AC_CLOSE,
    AC_EXIT = C.SDLK_AC_EXIT,
    AC_SAVE = C.SDLK_AC_SAVE,
    AC_PRINT = C.SDLK_AC_PRINT,
    AC_PROPERTIES = C.SDLK_AC_PROPERTIES,
    AC_SEARCH = C.SDLK_AC_SEARCH,
    AC_HOME = C.SDLK_AC_HOME,
    AC_BACK = C.SDLK_AC_BACK,
    AC_FORWARD = C.SDLK_AC_FORWARD,
    AC_STOP = C.SDLK_AC_STOP,
    AC_REFRESH = C.SDLK_AC_REFRESH,
    AC_BOOKMARKS = C.SDLK_AC_BOOKMARKS,
    SOFTLEFT = C.SDLK_SOFTLEFT,
    SOFTRIGHT = C.SDLK_SOFTRIGHT,
    CALL = C.SDLK_CALL,
    ENDCALL = C.SDLK_ENDCALL,
    LEFT_TAB = C.SDLK_LEFT_TAB,
    LEVEL5_SHIFT = C.SDLK_LEVEL5_SHIFT,
    MULTI_KEY_COMPOSE = C.SDLK_MULTI_KEY_COMPOSE,
    LMETA = C.SDLK_LMETA,
    RMETA = C.SDLK_RMETA,
    LHYPER = C.SDLK_LHYPER,
    RHYPER = C.SDLK_RHYPER,

    //TODO
    // pub extern fn SDL_GetScancodeFromKey(key: SDL_Keycode, modstate: [*c]SDL_Keymod) SDL_Scancode;
    // pub extern fn SDL_GetKeyName(key: SDL_Keycode) [*c]const u8;
};
pub const Keymod = Flags(enum(u16) {
    NONE = C.SDL_KMOD_NONE,
    L_SHIFT = C.SDL_KMOD_LSHIFT,
    R_SHIFT = C.SDL_KMOD_RSHIFT,
    LEVEL5_SHIFT = C.SDL_KMOD_LEVEL5,
    L_CTRL = C.SDL_KMOD_LCTRL,
    R_CTRL = C.SDL_KMOD_RCTRL,
    L_ALT = C.SDL_KMOD_LALT,
    R_ALT = C.SDL_KMOD_RALT,
    L_GUI = C.SDL_KMOD_LGUI,
    R_GUI = C.SDL_KMOD_RGUI,
    NUM_LOCK = C.SDL_KMOD_NUM,
    CAPS_LOCK = C.SDL_KMOD_CAPS,
    ALT_INPUT_MODE = C.SDL_KMOD_MODE,
    SCROLL_LOCK = C.SDL_KMOD_SCROLL,
    CTRL = C.SDL_KMOD_CTRL,
    SHIFT = C.SDL_KMOD_SHIFT,
    ALT = C.SDL_KMOD_ALT,
    GUI = C.SDL_KMOD_GUI,
}, enum(u16) {
    ANY_CTRL = C.SDL_KMOD_CTRL,
    ANY_SHIFT = C.SDL_KMOD_SHIFT,
    ANY_ALT = C.SDL_KMOD_ALT,
    ANY_GUI = C.SDL_KMOD_GUI,
});

pub const Meta = struct {
    pub fn runtime_version() c_int {
        return C.SDL_GetVersion();
    }
    pub fn runtime_revision() [*:0]const u8 {
        return C.SDL_GetRevision();
    }
    pub const BUILD_MAJOR_VERSION = C.SDL_MAJOR_VERSION;
    pub const BUILD_MINOR_VERSION = C.SDL_MINOR_VERSION;
    pub const BUILD_MICRO_VERSION = C.SDL_MICRO_VERSION;
    pub const BUILD_VERSION = C.SDL_VERSION;
    pub const BUILD_REVISION = C.SDL_REVISION;
    pub fn RUNTIME_MAJOR_VERSION(version: anytype) @TypeOf(@import("std").zig.c_translation.MacroArithmetic.div(version, @import("std").zig.c_translation.promoteIntLiteral(c_int, 1000000, .decimal))) {
        return C.SDL_VERSIONNUM_MAJOR(version);
    }
    pub fn RUNTIME_MINOR_VERSION(version: anytype) @TypeOf(@import("std").zig.c_translation.MacroArithmetic.rem(@import("std").zig.c_translation.MacroArithmetic.div(version, @as(c_int, 1000)), @as(c_int, 1000))) {
        return C.SDL_VERSIONNUM_MINOR(version);
    }
    pub fn RUNTIME_MICRO_VERSION(version: anytype) @TypeOf(@import("std").zig.c_translation.MacroArithmetic.rem(version, @as(c_int, 1000))) {
        return C.SDL_VERSIONNUM_MICRO(version);
    }
    pub fn RUNTIME_VERSION(major: anytype, minor: anytype, patch: anytype) c_int {
        return C.SDL_VERSIONNUM(major, minor, patch);
    }

    pub fn version_is_at_least(major: anytype, minor: anytype, patch: anytype) bool {
        return C.SDL_VERSION_ATLEAST(major, minor, patch);
    }

    pub const SDL_REVISION = C.SDL_REVISION[0 .. C.SDL_REVISION.len - 1] ++ "https://github.com/gabe-lee/Goolib " ++ VERSION ++ ")";
};

pub const GPU_Device = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_Device, C.SDL_GPUDevice).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_Device, C.SDL_GPUDevice).from_c_ptr;

    pub fn get_num_drivers() c_int {
        return C.SDL_GetNumGPUDrivers();
    }
    pub fn get_driver_name_by_inndex(index: c_int) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGPUDriver(index));
    }
    pub fn device_supports_shader_formats(device_name: [*:0]const u8, shader_formats: GPU_ShaderFormatFlags) bool {
        return C.SDL_GPUSupportsShaderFormats(shader_formats.raw, device_name);
    }
    pub fn device_supports_properties(props: PropertiesID) bool {
        return C.SDL_GPUSupportsProperties(props.id);
    }
    pub fn create(shader_formats: GPU_ShaderFormatFlags, debug_mode: bool, driver_name: ?[*:0]const u8) Error!*GPU_Device {
        return ptr_cast_or_fail_err(*GPU_Device, C.SDL_CreateGPUDevice(shader_formats.raw, debug_mode, driver_name));
    }
    pub fn create_from_properties(props: PropertiesID) Error!*GPU_Device {
        return ptr_cast_or_fail_err(*GPU_Device, C.SDL_CreateGPUDeviceWithProperties(props.id));
    }
    pub fn destroy(self: *GPU_Device) void {
        C.SDL_DestroyGPUDevice(self.to_c_ptr());
    }
    pub fn get_driver_name(self: *GPU_Device) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGPUDeviceDriver(self.to_c_ptr()));
    }
    pub fn get_shader_formats(self: *GPU_Device) GPU_ShaderFormatFlags {
        return GPU_ShaderFormatFlags{ .raw = C.SDL_GetGPUShaderFormats(self.to_c_ptr()) };
    }
    pub fn create_compute_pipeline(self: *GPU_Device, pipeline_info: *GPU_ComputePipelineCreateInfo) Error!*GPU_ComputePipeline {
        return ptr_cast_or_null_err(*GPU_ComputePipeline, C.SDL_CreateGPUComputePipeline(self.to_c_ptr(), pipeline_info.to_c_ptr()));
    }
    pub fn create_graphics_pipeline(self: *GPU_Device, pipeline_info: *GPU_GraphicsPipelineCreateInfo) Error!*GPU_GraphicsPipeline {
        return ptr_cast_or_null_err(*GPU_GraphicsPipeline, C.SDL_CreateGPUGraphicsPipeline(self.to_c_ptr(), pipeline_info.to_c_ptr()));
    }
    pub fn create_texture_sampler(self: *GPU_Device, sampler_info: *GPU_SamplerCreateInfo) Error!*GPU_TextureSampler {
        return ptr_cast_or_null_err(*GPU_TextureSampler, C.SDL_CreateGPUSampler(self.to_c_ptr(), sampler_info.to_c_ptr()));
    }
    pub fn create_shader(self: *GPU_Device, shader_info: *GPU_ShaderCreateInfo) Error!*GPU_Shader {
        return ptr_cast_or_null_err(*GPU_Shader, C.SDL_CreateGPUShader(self.to_c_ptr(), shader_info.to_c_ptr()));
    }
    pub fn create_buffer(self: *GPU_Device, buffer_info: *GPU_BufferCreateInfo) Error!*GPU_Buffer {
        return ptr_cast_or_null_err(*GPU_Buffer, C.SDL_CreateGPUBuffer(self.to_c_ptr(), buffer_info.to_c_ptr()));
    }
    pub fn create_transfer_buffer(self: *GPU_Device, buffer_info: *GPU_TransferBufferCreateInfo) Error!*GPU_TransferBuffer {
        return ptr_cast_or_null_err(*GPU_TransferBuffer, C.SDL_CreateGPUTransferBuffer(self.to_c_ptr(), buffer_info.to_c_ptr()));
    }
    pub fn set_buffer_name(self: *GPU_Device, buffer: *GPU_Buffer, name: [*:0]const u8) void {
        C.SDL_SetGPUBufferName(self.to_c_ptr(), buffer.to_c_ptr(), name);
    }
    pub fn set_texture_name(self: *GPU_Device, texture: *GPU_Texture, name: [*:0]const u8) void {
        C.SDL_SetGPUTextureName(self.to_c_ptr(), texture.to_c_ptr(), name);
    }
    pub fn release_texture(self: *GPU_Device, texture: *GPU_Texture) void {
        C.SDL_ReleaseGPUTexture(self.to_c_ptr(), texture.to_c_ptr());
    }
    pub fn release_texture_sampler(self: *GPU_Device, sampler: *GPU_TextureSampler) void {
        C.SDL_ReleaseGPUSampler(self.to_c_ptr(), sampler.to_c_ptr());
    }
    pub fn release_buffer(self: *GPU_Device, buffer: *GPU_Buffer) void {
        C.SDL_ReleaseGPUBuffer(self.to_c_ptr(), buffer.to_c_ptr());
    }
    pub fn release_transfer_buffer(self: *GPU_Device, buffer: *GPU_TransferBuffer) void {
        C.SDL_ReleaseGPUTransferBuffer(self.to_c_ptr(), buffer.to_c_ptr());
    }
    pub fn release_compute_pipeline(self: *GPU_Device, pipeline: *GPU_ComputePipeline) void {
        C.SDL_ReleaseGPUComputePipeline(self.to_c_ptr(), pipeline.to_c_ptr());
    }
    pub fn release_shader(self: *GPU_Device, shader: *GPU_Shader) void {
        C.SDL_ReleaseGPUShader(self.to_c_ptr(), shader.to_c_ptr());
    }
    pub fn release_graphics_pipeline(self: *GPU_Device, pipeline: *GPU_GraphicsPipeline) void {
        C.SDL_ReleaseGPUGraphicsPipeline(self.to_c_ptr(), pipeline.to_c_ptr());
    }
    pub fn aquire_command_buffer(self: *GPU_Device) Error!*GPU_CommandBuffer {
        return ptr_cast_or_fail_err(*GPU_CommandBuffer, C.SDL_AcquireGPUCommandBuffer(self.to_c()));
    }
    pub fn map_transfer_buffer(self: *GPU_Device, buffer: *GPU_TransferBuffer, cycle: bool) Error![*]u8 {
        return ptr_cast_or_fail_err([*]u8, C.SDL_MapGPUTransferBuffer(self.to_c_ptr(), buffer, cycle));
    }
    pub fn unmap_transfer_buffer(self: *GPU_Device, buffer: *GPU_TransferBuffer) void {
        C.SDL_UnmapGPUTransferBuffer(self.to_c_ptr(), buffer);
    }
    pub fn window_supports_swapchain_composition(self: *GPU_Device, window: *Window, composition: GPU_SwapchainComposition) bool {
        return C.SDL_WindowSupportsGPUSwapchainComposition(self.to_c_ptr(), window.to_c_ptr(), composition.to_c());
    }
    pub fn window_supports_present_mode(self: *GPU_Device, window: *Window, mode: GPU_PresentMode) bool {
        return C.SDL_WindowSupportsGPUSwapchainComposition(self.to_c_ptr(), window.to_c_ptr(), mode.to_c());
    }
    pub fn claim_window(self: *GPU_Device, window: *Window) Error!void {
        return ok_or_fail_err(C.SDL_ClaimWindowForGPUDevice(self.to_c_ptr(), window.to_c_ptr()));
    }
    pub fn release_window(self: *GPU_Device, window: *Window) void {
        C.SDL_ReleaseWindowFromGPUDevice(self.to_c_ptr(), window.to_c_ptr());
    }
    pub fn set_swapchain_parameters(self: *GPU_Device, window: *Window, composition: GPU_SwapchainComposition, present_mode: GPU_PresentMode) Error!void {
        return ok_or_fail_err(C.SDL_SetGPUSwapchainParameters(self.to_c_ptr(), window.to_c_ptr(), composition.to_c(), present_mode.to_c()));
    }
    pub fn set_max_frames_in_flight(self: *GPU_Device, frames: u32) Error!void {
        return ok_or_fail_err(C.SDL_SetGPUAllowedFramesInFlight(self.to_c_ptr(), frames));
    }
    pub fn get_swapchain_texture_format(self: *GPU_Device, window: *Window) GPU_TextureFormat {
        return GPU_TextureFormat.from_c(C.SDL_GetGPUSwapchainTextureFormat(self.to_c_ptr(), window.to_c_ptr()));
    }
    pub fn wait_for_swapchain(self: *GPU_Device, window: *Window) Error!void {
        return ok_or_fail_err(C.SDL_WaitForGPUSwapchain(self.to_c_ptr(), window.to_c_ptr()));
    }
    pub fn wait_for_gpu_idle(self: *GPU_Device) Error!void {
        return ok_or_fail_err(C.SDL_WaitForGPUIdle(self.to_c_ptr()));
    }
    pub fn wait_for_gpu_fences(self: *GPU_Device, wait_for_all: bool, fences: []const GPU_Fence) Error!void {
        return ok_or_fail_err(C.SDL_WaitForGPUFences(self.to_c_ptr(), wait_for_all, @ptrCast(@alignCast(fences.ptr)), @intCast(fences.len)));
    }
    pub fn is_fence_signaled(self: *GPU_Device, fence: *GPU_Fence) bool {
        return C.SDL_QueryGPUFence(self.to_c_ptr(), fence.to_c_ptr());
    }
    pub fn release_fence(self: *GPU_Device, fence: *GPU_Fence) void {
        return C.SDL_ReleaseGPUFence(self.to_c_ptr(), fence.to_c_ptr());
    }
    pub fn texture_supports_format(self: *GPU_Device, tex_format: GPU_TextureFormat, tex_type: GPU_TextureType, tex_usage: GPU_TextureUsageFlags) bool {
        return C.SDL_GPUTextureSupportsFormat(self.to_c_ptr(), tex_format.to_c(), tex_type.to_c(), tex_usage.raw);
    }
    pub fn texture_supports_sample_count(self: *GPU_Device, tex_format: GPU_TextureFormat, sample_count: GPU_SampleCount) bool {
        return C.SDL_GPUTextureSupportsFormat(self.to_c_ptr(), tex_format.to_c(), sample_count.to_c());
    }

    pub const CreateProps = struct {
        pub const DEBUG_MODE = Property.new(.BOOLEAN, C.SDL_PROP_GPU_DEVICE_CREATE_DEBUGMODE_BOOLEAN);
        pub const PREFER_LOW_POWER = Property.new(.BOOLEAN, C.SDL_PROP_GPU_DEVICE_CREATE_PREFERLOWPOWER_BOOLEAN);
        pub const NAME = Property.new(.STRING, C.SDL_PROP_GPU_DEVICE_CREATE_NAME_STRING);
        pub const SHADERS_PRIVATE = Property.new(.BOOLEAN, C.SDL_PROP_GPU_DEVICE_CREATE_SHADERS_PRIVATE_BOOLEAN);
        pub const SHADERS_SPIRV = Property.new(.BOOLEAN, C.SDL_PROP_GPU_DEVICE_CREATE_SHADERS_SPIRV_BOOLEAN);
        pub const SHADERS_DXBC = Property.new(.BOOLEAN, C.SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXBC_BOOLEAN);
        pub const SHADERS_DXIL = Property.new(.BOOLEAN, C.SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXIL_BOOLEAN);
        pub const SHADERS_MSL = Property.new(.BOOLEAN, C.SDL_PROP_GPU_DEVICE_CREATE_SHADERS_MSL_BOOLEAN);
        pub const SHADERS_METALLIB = Property.new(.BOOLEAN, C.SDL_PROP_GPU_DEVICE_CREATE_SHADERS_METALLIB_BOOLEAN);
        pub const D3D12_SEMANTIC_NAME = Property.new(.STRING, C.SDL_PROP_GPU_DEVICE_CREATE_D3D12_SEMANTIC_NAME_STRING);
    };
};

pub const GPU_TransferBufferCreateInfo = extern struct {
    usage: GPU_TransferBufferUsage = .DOWNLOAD,
    size: u32 = 0,
    props: PropertiesID = .NULL,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_TransferBufferCreateInfo, C.SDL_GPUTransferBufferCreateInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_TransferBufferCreateInfo, C.SDL_GPUTransferBufferCreateInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_TransferBufferCreateInfo, C.SDL_GPUTransferBufferCreateInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_TransferBufferCreateInfo, C.SDL_GPUTransferBufferCreateInfo).from_c;

    pub const CreateProps = struct {
        pub const NAME = Property.new(.STRING, C.SDL_PROP_GPU_TRANSFERBUFFER_CREATE_NAME_STRING);
    };
};

pub const GPU_BufferCreateInfo = extern struct {
    usage: GPU_BufferUsageFlags = .blank(),
    size: u32 = 0,
    props: PropertiesID = .NULL,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_BufferCreateInfo, C.SDL_GPUBufferCreateInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_BufferCreateInfo, C.SDL_GPUBufferCreateInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_BufferCreateInfo, C.SDL_GPUBufferCreateInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_BufferCreateInfo, C.SDL_GPUBufferCreateInfo).from_c;

    pub const CreateProps = struct {
        pub const NAME = Property.new(.STRING, C.SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING);
    };
};

pub const GPU_TextureCreateInfo = extern struct {
    type: GPU_TextureType = ._2D,
    format: GPU_TextureFormat = .INVALID,
    usage: GPU_TextureUsageFlags = .blank(),
    width: u32 = 0,
    height: u32 = 0,
    layer_count_or_depth: u32 = 0,
    num_levels: u32 = 0,
    sample_count: GPU_SampleCount = ._1,
    props: PropertiesID = .NULL,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_TextureCreateInfo, C.SDL_GPUTextureCreateInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_TextureCreateInfo, C.SDL_GPUTextureCreateInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_TextureCreateInfo, C.SDL_GPUTextureCreateInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_TextureCreateInfo, C.SDL_GPUTextureCreateInfo).from_c;

    pub const CreateProps = struct {
        pub const D3D12_CLEAR_RED = Property.new(.FLOAT, C.SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_R_FLOAT);
        pub const D3D12_CLEAR_GREEN = Property.new(.FLOAT, C.SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_G_FLOAT);
        pub const D3D12_CLEAR_BLUE = Property.new(.FLOAT, C.SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_B_FLOAT);
        pub const D3D12_CLEAR_ALPHA = Property.new(.FLOAT, C.SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_A_FLOAT);
        pub const D3D12_CLEAR_DEPTH = Property.new(.FLOAT, C.SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_DEPTH_FLOAT);
        pub const D3D12_CLEAR_STENCIL = Property.new(.INTEGER, C.SDL_PROP_GPU_TEXTURE_CREATE_D3D12_CLEAR_STENCIL_NUMBER);
        pub const NAME = Property.new(.STRING, C.SDL_PROP_GPU_TEXTURE_CREATE_NAME_STRING);
    };
};

pub const GPU_ShaderCreateInfo = extern struct {
    code_size: usize = 0,
    code: ?[*]const u8 = null,
    entrypoint_func: [*:0]const u8 = "",
    format: GPU_ShaderFormatFlags = GPU_ShaderFormatFlags.new_single(.INVALID),
    stage: GPU_ShaderStage = .VERTEX,
    num_samplers: u32 = 0,
    num_storage_textures: u32 = 0,
    num_storage_buffers: u32 = 0,
    num_uniform_buffers: u32 = 0,
    props: PropertiesID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(GPU_ShaderCreateInfo, C.SDL_GPUShaderCreateInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_ShaderCreateInfo, C.SDL_GPUShaderCreateInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_ShaderCreateInfo, C.SDL_GPUShaderCreateInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_ShaderCreateInfo, C.SDL_GPUShaderCreateInfo).from_c;

    pub const CreateProps = struct {
        pub const NAME = Property.new(.STRING, C.SDL_PROP_GPU_SHADER_CREATE_NAME_STRING);
    };
};

pub const GPU_ComputePipelineCreateInfo = extern struct {
    code_len: usize = 0,
    code_data: [*]const u8,
    entrypoint_func: [*:0]const u8 = "",
    format: GPU_ShaderFormatFlags = .{ .raw = 0 },
    num_samplers: u32 = 0,
    num_readonly_storage_textures: u32 = 0,
    num_readonly_storage_buffers: u32 = 0,
    num_readwrite_storage_textures: u32 = 0,
    num_readwrite_storage_buffers: u32 = 0,
    num_uniform_buffers: u32 = 0,
    thread_count_x: u32 = 0,
    thread_count_y: u32 = 0,
    thread_count_z: u32 = 0,
    props: PropertiesID = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_ComputePipelineCreateInfo, C.SDL_GPUComputePipelineCreateInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_ComputePipelineCreateInfo, C.SDL_GPUComputePipelineCreateInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_ComputePipelineCreateInfo, C.SDL_GPUComputePipelineCreateInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_ComputePipelineCreateInfo, C.SDL_GPUComputePipelineCreateInfo).from_c;

    pub const CreateProps = struct {
        pub const NAME = Property.new(.STRING, C.SDL_PROP_GPU_COMPUTEPIPELINE_CREATE_NAME_STRING);
    };
};

pub const GPU_GraphicsPipelineCreateInfo = extern struct {
    vertex_shader: ?*GPU_Shader = null,
    fragment_shader: ?*GPU_Shader = null,
    vertex_input_state: GPU_VertexInputState = .{},
    primitive_type: GPU_PrimitiveType = .TRIANGLE_LIST,
    rasterizer_state: GPU_RasterizerState = .{},
    multisample_state: GPU_MultisampleState = .{},
    depth_stencil_state: GPU_DepthStencilState = .{},
    target_info: GPU_GraphicsPipelineTargetInfo = .{},
    props: PropertiesID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(GPU_GraphicsPipelineCreateInfo, C.SDL_GPUGraphicsPipelineCreateInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_GraphicsPipelineCreateInfo, C.SDL_GPUGraphicsPipelineCreateInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_GraphicsPipelineCreateInfo, C.SDL_GPUGraphicsPipelineCreateInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_GraphicsPipelineCreateInfo, C.SDL_GPUGraphicsPipelineCreateInfo).from_c;

    pub const CreateProps = struct {
        pub const NAME = Property.new(.STRING, C.SDL_PROP_GPU_GRAPHICSPIPELINE_CREATE_NAME_STRING);
    };
};

pub const GPU_VertexInputState = extern struct {
    vertex_buffer_descriptions: ?[*]const GPU_VertexBufferDescription = null,
    num_vertex_buffers: u32 = 0,
    vertex_attributes: ?[*]const GPU_VertexAttribute = null,
    num_vertex_attributes: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_VertexInputState, C.SDL_GPUVertexInputState).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_VertexInputState, C.SDL_GPUVertexInputState).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_VertexInputState, C.SDL_GPUVertexInputState).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_VertexInputState, C.SDL_GPUVertexInputState).from_c;
};

pub const GPU_VertexBufferDescription = extern struct {
    slot: u32 = 0,
    stride: u32 = 0,
    input_rate: GPU_VertexInputRate = .VERTEX,
    instance_step_rate: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_VertexBufferDescription, C.SDL_GPUVertexBufferDescription).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_VertexBufferDescription, C.SDL_GPUVertexBufferDescription).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_VertexBufferDescription, C.SDL_GPUVertexBufferDescription).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_VertexBufferDescription, C.SDL_GPUVertexBufferDescription).from_c;
};

pub const GPU_VertexAttribute = extern struct {
    location: u32 = 0,
    buffer_slot: u32 = 0,
    format: GPU_VertexElementFormat = .INVALID,
    offset: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_VertexAttribute, C.SDL_GPUVertexAttribute).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_VertexAttribute, C.SDL_GPUVertexAttribute).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_VertexAttribute, C.SDL_GPUVertexAttribute).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_VertexAttribute, C.SDL_GPUVertexAttribute).from_c;
};

pub const GPU_RasterizerState = extern struct {
    fill_mode: GPU_FillMode = .FILL,
    cull_mode: GPU_CullMode = .NONE,
    front_face_winding: GPU_FrontFaceWinding = .CCW,
    depth_bias_constant_factor: f32 = 0,
    depth_bias_clamp: f32 = 0,
    depth_bias_slope_factor: f32 = 0,
    enable_depth_bias: bool = false,
    enable_depth_clip: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_RasterizerState, C.SDL_GPURasterizerState).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_RasterizerState, C.SDL_GPURasterizerState).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_RasterizerState, C.SDL_GPURasterizerState).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_RasterizerState, C.SDL_GPURasterizerState).from_c;
};

pub const GPU_MultisampleState = extern struct {
    sample_count: GPU_SampleCount = ._1,
    sample_mask: u32 = 0,
    enable_mask: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,
    _padding3: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_MultisampleState, C.SDL_GPUMultisampleState).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_MultisampleState, C.SDL_GPUMultisampleState).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_MultisampleState, C.SDL_GPUMultisampleState).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_MultisampleState, C.SDL_GPUMultisampleState).from_c;
};

pub const GPU_DepthStencilState = extern struct {
    compare_op: GPU_CompareOp = .INVALID,
    back_stencil_state: GPU_StencilOpState = .{},
    front_stencil_state: GPU_StencilOpState = .{},
    compare_mask: u8 = 0,
    write_mask: u8 = 0,
    enable_depth_test: bool = false,
    enable_depth_write: bool = false,
    enable_stencil_test: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,
    _padding3: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_DepthStencilState, C.SDL_GPUDepthStencilState).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_DepthStencilState, C.SDL_GPUDepthStencilState).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_DepthStencilState, C.SDL_GPUDepthStencilState).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_DepthStencilState, C.SDL_GPUDepthStencilState).from_c;
};

pub const GPU_StencilOpState = extern struct {
    fail_op: GPU_StencilOp = .INVALID,
    pass_op: GPU_StencilOp = .INVALID,
    depth_fail_op: GPU_StencilOp = .INVALID,
    compare_op: GPU_CompareOp = .INVALID,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_StencilOpState, C.SDL_GPUStencilOpState).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_StencilOpState, C.SDL_GPUStencilOpState).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_StencilOpState, C.SDL_GPUStencilOpState).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_StencilOpState, C.SDL_GPUStencilOpState).from_c;
};

pub const GPU_GraphicsPipelineTargetInfo = extern struct {
    color_target_descriptions: ?[*]const GPU_ColorTargetDescription = null,
    num_color_targets: u32 = 0,
    depth_stencil_format: GPU_TextureFormat = .INVALID,
    has_depth_stencil_target: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,
    _padding3: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_GraphicsPipelineTargetInfo, C.SDL_GPUGraphicsPipelineTargetInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_GraphicsPipelineTargetInfo, C.SDL_GPUGraphicsPipelineTargetInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_GraphicsPipelineTargetInfo, C.SDL_GPUGraphicsPipelineTargetInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_GraphicsPipelineTargetInfo, C.SDL_GPUGraphicsPipelineTargetInfo).from_c;
};

pub const GPU_ColorTargetDescription = extern struct {
    format: GPU_TextureFormat = .INVALID,
    blend_state: GPU_ColorTargetBlendState = .{},

    pub const to_c_ptr = c_non_opaque_conversions(GPU_ColorTargetDescription, C.SDL_GPUColorTargetDescription).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_ColorTargetDescription, C.SDL_GPUColorTargetDescription).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_ColorTargetDescription, C.SDL_GPUColorTargetDescription).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_ColorTargetDescription, C.SDL_GPUColorTargetDescription).from_c;
};

pub const GPU_ColorTargetBlendState = extern struct {
    src_color_blendfactor: GPU_BlendFactor = .INVALID,
    dst_color_blendfactor: GPU_BlendFactor = .INVALID,
    color_blend_op: GPU_BlendOp = .INVALID,
    src_alpha_blendfactor: GPU_BlendFactor = .INVALID,
    dst_alpha_blendfactor: GPU_BlendFactor = .INVALID,
    alpha_blend_op: GPU_BlendOp = .INVALID,
    color_write_mask: GPU_ColorComponentFlags = .{ .raw = 0 },
    enable_blend: bool = false,
    enable_color_write_mask: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_ColorTargetBlendState, C.SDL_GPUColorTargetBlendState).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_ColorTargetBlendState, C.SDL_GPUColorTargetBlendState).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_ColorTargetBlendState, C.SDL_GPUColorTargetBlendState).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_ColorTargetBlendState, C.SDL_GPUColorTargetBlendState).from_c;
};

pub const GPU_IndirectDispatchCommand = extern struct {
    groupcount_x: u32 = 0,
    groupcount_y: u32 = 0,
    groupcount_z: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_IndirectDispatchCommand, C.SDL_GPUIndirectDispatchCommand).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_IndirectDispatchCommand, C.SDL_GPUIndirectDispatchCommand).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_IndirectDispatchCommand, C.SDL_GPUIndirectDispatchCommand).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_IndirectDispatchCommand, C.SDL_GPUIndirectDispatchCommand).from_c;
};

pub const GPU_IndexedIndirectDrawCommand = extern struct {
    num_indices: u32 = 0,
    num_instances: u32 = 0,
    first_index: u32 = 0,
    vertex_offset: i32 = 0,
    first_instance: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_IndexedIndirectDrawCommand, C.SDL_GPUIndexedIndirectDrawCommand).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_IndexedIndirectDrawCommand, C.SDL_GPUIndexedIndirectDrawCommand).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_IndexedIndirectDrawCommand, C.SDL_GPUIndexedIndirectDrawCommand).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_IndexedIndirectDrawCommand, C.SDL_GPUIndexedIndirectDrawCommand).from_c;
};

pub const GPU_IndirectDrawCommand = extern struct {
    num_vertices: u32 = 0,
    num_instances: u32 = 0,
    first_vertex: u32 = 0,
    first_instance: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_IndirectDrawCommand, C.SDL_GPUIndirectDrawCommand).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_IndirectDrawCommand, C.SDL_GPUIndirectDrawCommand).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_IndirectDrawCommand, C.SDL_GPUIndirectDrawCommand).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_IndirectDrawCommand, C.SDL_GPUIndirectDrawCommand).from_c;
};

pub const GPU_BufferRegion = extern struct {
    buffer: ?*GPU_Buffer = null,
    offset: u32 = 0,
    size: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_BufferRegion, C.SDL_GPUBufferRegion).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_BufferRegion, C.SDL_GPUBufferRegion).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_BufferRegion, C.SDL_GPUBufferRegion).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_BufferRegion, C.SDL_GPUBufferRegion).from_c;
};

pub const GPU_BufferLocation = extern struct {
    buffer: ?*GPU_Buffer = null,
    offset: u32 = u32,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_BufferLocation, C.SDL_GPUBufferLocation).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_BufferLocation, C.SDL_GPUBufferLocation).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_BufferLocation, C.SDL_GPUBufferLocation).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_BufferLocation, C.SDL_GPUBufferLocation).from_c;
};

pub const GPU_BlitRegion = extern struct {
    texture: ?*GPU_Texture = null,
    mip_level: u32 = 0,
    layer_or_depth_plane: u32 = 0,
    x: u32 = 0,
    y: u32 = 0,
    w: u32 = 0,
    h: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_BlitRegion, C.SDL_GPUBlitRegion).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_BlitRegion, C.SDL_GPUBlitRegion).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_BlitRegion, C.SDL_GPUBlitRegion).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_BlitRegion, C.SDL_GPUBlitRegion).from_c;
};

pub const GPU_TextureRegion = extern struct {
    texture: ?*GPU_Texture = null,
    mip_level: u32 = 0,
    layer: u32 = 0,
    x: u32 = 0,
    y: u32 = 0,
    z: u32 = 0,
    w: u32 = 0,
    h: u32 = 0,
    d: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_TextureRegion, C.SDL_GPUTextureRegion).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_TextureRegion, C.SDL_GPUTextureRegion).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_TextureRegion, C.SDL_GPUTextureRegion).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_TextureRegion, C.SDL_GPUTextureRegion).from_c;
};

pub const GPU_TextureLocation = extern struct {
    texture: ?*GPU_Texture = null,
    mip_level: u32 = 0,
    layer: u32 = 0,
    x: u32 = 0,
    y: u32 = 0,
    z: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_TextureLocation, C.SDL_GPUTextureLocation).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_TextureLocation, C.SDL_GPUTextureLocation).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_TextureLocation, C.SDL_GPUTextureLocation).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_TextureLocation, C.SDL_GPUTextureLocation).from_c;
};

pub const GPU_TransferBufferLocation = extern struct {
    transfer_buffer: ?*GPU_TransferBuffer = null,
    offset: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_TransferBufferLocation, C.SDL_GPUTransferBufferLocation).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_TransferBufferLocation, C.SDL_GPUTransferBufferLocation).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_TransferBufferLocation, C.SDL_GPUTransferBufferLocation).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_TransferBufferLocation, C.SDL_GPUTransferBufferLocation).from_c;
};

pub const GPU_TextureTransferInfo = extern struct {
    transfer_buffer: ?*GPU_TransferBuffer = null,
    offset: u32 = 0,
    pixels_per_row: u32 = 0,
    rows_per_layer: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_TextureTransferInfo, C.SDL_GPUTextureTransferInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_TextureTransferInfo, C.SDL_GPUTextureTransferInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_TextureTransferInfo, C.SDL_GPUTextureTransferInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_TextureTransferInfo, C.SDL_GPUTextureTransferInfo).from_c;
};

pub const GPU_SamplerCreateInfo = extern struct {
    min_filter: GPU_FilterMode = .LINEAR,
    mag_filter: GPU_FilterMode = .LINEAR,
    mipmap_mode: GPU_SamplerMipmapMode = .LINEAR,
    address_mode_u: GPU_SamplerAddressMode = .CLAMP_TO_EDGE,
    address_mode_v: GPU_SamplerAddressMode = .CLAMP_TO_EDGE,
    address_mode_w: GPU_SamplerAddressMode = .CLAMP_TO_EDGE,
    mip_lod_bias: f32 = 0,
    max_anisotropy: f32 = 0,
    compare_op: GPU_CompareOp = .INVALID,
    min_lod: f32 = @import("std").mem.zeroes(f32),
    max_lod: f32 = @import("std").mem.zeroes(f32),
    enable_anisotropy: bool = false,
    enable_compare: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,
    props: PropertiesID = .{},

    pub const to_c_ptr = c_non_opaque_conversions(GPU_SamplerCreateInfo, C.SDL_GPUSamplerCreateInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_SamplerCreateInfo, C.SDL_GPUSamplerCreateInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_SamplerCreateInfo, C.SDL_GPUSamplerCreateInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_SamplerCreateInfo, C.SDL_GPUSamplerCreateInfo).from_c;

    pub const CreateProps = struct {
        pub const NAME = Property.new(.STRING, C.SDL_PROP_GPU_SAMPLER_CREATE_NAME_STRING);
    };
};

pub const GPU_ColorTargetInfo = extern struct {
    texture: ?*GPU_Texture = null,
    mip_level: u32 = 0,
    layer_or_depth_plane: u32 = 0,
    clear_color: Color_RGBA_f32 = .BLACK,
    load_op: GPU_LoadOp = .LOAD,
    store_op: GPU_StoreOp = .STORE,
    resolve_texture: ?*GPU_Texture = null,
    resolve_mip_level: u32 = 0,
    resolve_layer: u32 = 0,
    cycle: bool = false,
    cycle_resolve_texture: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_ColorTargetInfo, C.SDL_GPUColorTargetInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_ColorTargetInfo, C.SDL_GPUColorTargetInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_ColorTargetInfo, C.SDL_GPUColorTargetInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_ColorTargetInfo, C.SDL_GPUColorTargetInfo).from_c;
};

pub const GPU_DepthStencilTargetInfo = extern struct {
    texture: ?*GPU_Texture = null,
    clear_depth: f32 = 0,
    load_op: GPU_LoadOp = .LOAD,
    store_op: GPU_StoreOp = .STORE,
    stencil_load_op: GPU_LoadOp = .LOAD,
    stencil_store_op: GPU_StoreOp = .STORE,
    cycle: bool = false,
    clear_stencil: u8 = 0,
    _padding1: u8 = 0,
    _padding2: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_DepthStencilTargetInfo, C.SDL_GPUDepthStencilTargetInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_DepthStencilTargetInfo, C.SDL_GPUDepthStencilTargetInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_DepthStencilTargetInfo, C.SDL_GPUDepthStencilTargetInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_DepthStencilTargetInfo, C.SDL_GPUDepthStencilTargetInfo).from_c;
};

pub const GPU_Viewport = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,
    min_depth: f32 = 0,
    max_depth: f32 = 0,

    pub fn from_rect(rect: Rect_f32, min_depth: f32, max_depth: f32) GPU_Viewport {
        return GPU_Viewport{
            .x = rect.x,
            .y = rect.y,
            .w = rect.w,
            .h = rect.h,
            .min_depth = min_depth,
            .max_depth = max_depth,
        };
    }

    pub const to_c_ptr = c_non_opaque_conversions(GPU_Viewport, C.SDL_GPUViewport).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_Viewport, C.SDL_GPUViewport).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_Viewport, C.SDL_GPUViewport).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_Viewport, C.SDL_GPUViewport).from_c;
};

pub const GPU_BufferBinding = extern struct {
    buffer: ?*GPU_Buffer = null,
    offset: u32 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_BufferBinding, C.SDL_GPUBufferBinding).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_BufferBinding, C.SDL_GPUBufferBinding).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_BufferBinding, C.SDL_GPUBufferBinding).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_BufferBinding, C.SDL_GPUBufferBinding).from_c;
};

pub const GPU_TextureSamplerBinding = extern struct {
    texture: ?*GPU_Texture = null,
    sampler: ?*GPU_TextureSampler = null,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_TextureSamplerBinding, C.SDL_GPUTextureSamplerBinding).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_TextureSamplerBinding, C.SDL_GPUTextureSamplerBinding).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_TextureSamplerBinding, C.SDL_GPUTextureSamplerBinding).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_TextureSamplerBinding, C.SDL_GPUTextureSamplerBinding).from_c;
};

pub const GPU_StorageBufferReadWriteBinding = extern struct {
    buffer: ?*GPU_Buffer = null,
    cycle: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,
    _padding3: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_StorageBufferReadWriteBinding, C.SDL_GPUStorageBufferReadWriteBinding).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_StorageBufferReadWriteBinding, C.SDL_GPUStorageBufferReadWriteBinding).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_StorageBufferReadWriteBinding, C.SDL_GPUStorageBufferReadWriteBinding).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_StorageBufferReadWriteBinding, C.SDL_GPUStorageBufferReadWriteBinding).from_c;
};

pub const GPU_StorageTextureReadWriteBinding = extern struct {
    texture: ?*GPU_Texture = null,
    mip_level: u32 = 0,
    layer: u32 = 0,
    cycle: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,
    _padding3: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_StorageTextureReadWriteBinding, C.SDL_GPUStorageTextureReadWriteBinding).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_StorageTextureReadWriteBinding, C.SDL_GPUStorageTextureReadWriteBinding).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_StorageTextureReadWriteBinding, C.SDL_GPUStorageTextureReadWriteBinding).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_StorageTextureReadWriteBinding, C.SDL_GPUStorageTextureReadWriteBinding).from_c;
};

pub const GPU_BlitInfo = extern struct {
    source: GPU_BlitRegion = .{},
    destination: GPU_BlitRegion = .{},
    load_op: GPU_LoadOp = .LOAD,
    clear_color: Color_RGBA_f32 = .BLACK,
    flip_mode: FlipMode = .NONE,
    filter: GPU_FilterMode = .LINEAR,
    cycle: bool = false,
    _padding1: u8 = 0,
    _padding2: u8 = 0,
    _padding3: u8 = 0,

    pub const to_c_ptr = c_non_opaque_conversions(GPU_BlitInfo, C.SDL_GPUBlitInfo).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(GPU_BlitInfo, C.SDL_GPUBlitInfo).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(GPU_BlitInfo, C.SDL_GPUBlitInfo).to_c;
    pub const from_c = c_non_opaque_conversions(GPU_BlitInfo, C.SDL_GPUBlitInfo).from_c;
};

pub const GPU_SwapchainComposition = enum(c_uint) {
    SDR = C.SDL_GPU_SWAPCHAINCOMPOSITION_SDR,
    SDR_LINEAR = C.SDL_GPU_SWAPCHAINCOMPOSITION_SDR_LINEAR,
    HDR_EXTENDED_LINEAR = C.SDL_GPU_SWAPCHAINCOMPOSITION_HDR_EXTENDED_LINEAR,
    HDR10_ST2084 = C.SDL_GPU_SWAPCHAINCOMPOSITION_HDR10_ST2084,

    pub const to_c = c_enum_conversions(GPU_SwapchainComposition, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_SwapchainComposition, c_uint).from_c;
};

pub const GPU_TransferBufferUsage = enum(c_uint) {
    UPLOAD = C.SDL_TRANSFERBUFFERUSAGE_UPLOAD,
    DOWNLOAD = C.SDL_TRANSFERBUFFERUSAGE_DOWNLOAD,

    pub const to_c = c_enum_conversions(GPU_TransferBufferUsage, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_TransferBufferUsage, c_uint).from_c;
};

pub const GPU_ShaderStage = enum(c_uint) {
    VERTEX = C.SDL_SHADERSTAGE_VERTEX,
    FRAGMENT = C.SDL_SHADERSTAGE_FRAGMENT,

    pub const to_c = c_enum_conversions(GPU_ShaderStage, C.SDL_GPUShaderStage).to_c;
    pub const from_c = c_enum_conversions(GPU_ShaderStage, C.SDL_GPUShaderStage).from_c;
};

pub const GPU_VertexInputRate = enum(c_uint) {
    VERTEX = C.SDL_VERTEXINPUTRATE_VERTEX,
    INSTANCE = C.SDL_VERTEXINPUTRATE_INSTANCE,

    pub const to_c = c_enum_conversions(GPU_VertexInputRate, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_VertexInputRate, c_uint).from_c;
};

pub const GPU_FilterMode = enum(c_uint) {
    NEAREST = C.SDL_FILTER_NEAREST,
    LINEAR = C.SDL_FILTER_LINEAR,

    pub const to_c = c_enum_conversions(GPU_FilterMode, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_FilterMode, c_uint).from_c;
};

pub const GPU_SamplerMipmapMode = enum(c_uint) {
    NEAREST = C.SDL_SAMPLERMIPMAPMODE_NEAREST,
    LINEAR = C.SDL_SAMPLERMIPMAPMODE_LINEAR,

    pub const to_c = c_enum_conversions(GPU_SamplerMipmapMode, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_SamplerMipmapMode, c_uint).from_c;
};

pub const GPU_SamplerAddressMode = enum(c_uint) {
    REPEAT = C.SDL_SAMPLERADDRESSMODE_REPEAT,
    MIRRORED_REPEAT = C.SDL_SAMPLERADDRESSMODE_MIRRORED_REPEAT,
    CLAMP_TO_EDGE = C.SDL_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,

    pub const to_c = c_enum_conversions(GPU_SamplerAddressMode, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_SamplerAddressMode, c_uint).from_c;
};

pub const GPU_PresentMode = enum(c_uint) {
    VSYNC = C.SDL_PRESENTMODE_VSYNC,
    IMMEDIATE = C.SDL_PRESENTMODE_IMMEDIATE,
    MAILBOX = C.SDL_PRESENTMODE_MAILBOX,

    pub const to_c = c_enum_conversions(GPU_PresentMode, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_PresentMode, c_uint).from_c;
};

pub const GPU_BlendFactor = enum(c_uint) {
    INVALID = C.SDL_BLENDFACTOR_INVALID,
    ZERO = C.SDL_BLENDFACTOR_ZERO,
    ONE = C.SDL_BLENDFACTOR_ONE,
    SRC_COLOR = C.SDL_BLENDFACTOR_SRC_COLOR,
    ONE_MINUS_SRC_COLOR = C.SDL_BLENDFACTOR_ONE_MINUS_SRC_COLOR,
    DST_COLOR = C.SDL_BLENDFACTOR_DST_COLOR,
    ONE_MINUS_DST_COLOR = C.SDL_BLENDFACTOR_ONE_MINUS_DST_COLOR,
    SRC_ALPHA = C.SDL_BLENDFACTOR_SRC_ALPHA,
    ONE_MINUS_SRC_ALPHA = C.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
    DST_ALPHA = C.SDL_BLENDFACTOR_DST_ALPHA,
    ONE_MINUS_DST_ALPHA = C.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,
    CONSTANT_COLOR = C.SDL_BLENDFACTOR_CONSTANT_COLOR,
    ONE_MINUS_CONSTANT_COLOR = C.SDL_BLENDFACTOR_ONE_MINUS_CONSTANT_COLOR,
    SRC_ALPHA_SATURATE = C.SDL_BLENDFACTOR_SRC_ALPHA_SATURATE,

    pub const to_c = c_enum_conversions(GPU_BlendFactor, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_BlendFactor, c_uint).from_c;
};

pub const GPU_BlendOp = enum(c_uint) {
    INVALID = C.SDL_BLENDOP_INVALID,
    ADD = C.SDL_BLENDOP_ADD,
    SUBTRACT = C.SDL_BLENDOP_SUBTRACT,
    REVERSE_SUBTRACT = C.SDL_BLENDOP_REVERSE_SUBTRACT,
    MIN = C.SDL_BLENDOP_MIN,
    MAX = C.SDL_BLENDOP_MAX,

    pub const to_c = c_enum_conversions(GPU_BlendOp, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_BlendOp, c_uint).from_c;
};

pub const GPU_CompareOp = enum(c_uint) {
    INVALID = C.SDL_COMPAREOP_INVALID,
    NEVER = C.SDL_COMPAREOP_NEVER,
    LESS = C.SDL_COMPAREOP_LESS,
    EQUAL = C.SDL_COMPAREOP_EQUAL,
    LESS_OR_EQUAL = C.SDL_COMPAREOP_LESS_OR_EQUAL,
    GREATER = C.SDL_COMPAREOP_GREATER,
    NOT_EQUAL = C.SDL_COMPAREOP_NOT_EQUAL,
    GREATER_OR_EQUAL = C.SDL_COMPAREOP_GREATER_OR_EQUAL,
    ALWAYS = C.SDL_COMPAREOP_ALWAYS,

    pub const to_c = c_enum_conversions(GPU_CompareOp, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_CompareOp, c_uint).from_c;
};

pub const GPU_StencilOp = enum(c_uint) {
    INVALID = C.SDL_STENCILOP_INVALID,
    KEEP = C.SDL_STENCILOP_KEEP,
    ZERO = C.SDL_STENCILOP_ZERO,
    REPLACE = C.SDL_STENCILOP_REPLACE,
    INCREMENT_AND_CLAMP = C.SDL_STENCILOP_INCREMENT_AND_CLAMP,
    DECREMENT_AND_CLAMP = C.SDL_STENCILOP_DECREMENT_AND_CLAMP,
    INVERT = C.SDL_STENCILOP_INVERT,
    INCREMENT_AND_WRAP = C.SDL_STENCILOP_INCREMENT_AND_WRAP,
    DECREMENT_AND_WRAP = C.SDL_STENCILOP_DECREMENT_AND_WRAP,

    pub const to_c = c_enum_conversions(GPU_StencilOp, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_StencilOp, c_uint).from_c;
};

pub const GPU_FillMode = enum(c_uint) {
    FILL = C.SDL_FILLMODE_FILL,
    LINE = C.SDL_FILLMODE_LINE,

    pub const to_c = c_enum_conversions(GPU_FillMode, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_FillMode, c_uint).from_c;
};

pub const GPU_CullMode = enum(c_uint) {
    NONE = C.SDL_CULLMODE_NONE,
    FRONT = C.SDL_CULLMODE_FRONT,
    BACK = C.SDL_CULLMODE_BACK,

    pub const to_c = c_enum_conversions(GPU_CullMode, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_CullMode, c_uint).from_c;
};

pub const GPU_FrontFaceWinding = enum(c_uint) {
    CCW = C.SDL_FRONTFACE_COUNTER_CLOCKWISE,
    CW = C.SDL_FRONTFACE_CLOCKWISE,

    pub const to_c = c_enum_conversions(GPU_FrontFaceWinding, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_FrontFaceWinding, c_uint).from_c;
};

pub const GPU_VertexElementFormat = enum(c_uint) {
    INVALID = C.SDL_VERTEXELEMENTFORMAT_INVALID,
    I32_x1 = C.SDL_VERTEXELEMENTFORMAT_INT,
    I32_x2 = C.SDL_VERTEXELEMENTFORMAT_INT2,
    I32_x3 = C.SDL_VERTEXELEMENTFORMAT_INT3,
    I32_x4 = C.SDL_VERTEXELEMENTFORMAT_INT4,
    U32_x1 = C.SDL_VERTEXELEMENTFORMAT_UINT,
    U32_x2 = C.SDL_VERTEXELEMENTFORMAT_UINT2,
    U32_x3 = C.SDL_VERTEXELEMENTFORMAT_UINT3,
    U32_x4 = C.SDL_VERTEXELEMENTFORMAT_UINT4,
    F32_x1 = C.SDL_VERTEXELEMENTFORMAT_FLOAT,
    F32_x2 = C.SDL_VERTEXELEMENTFORMAT_FLOAT2,
    F32_x3 = C.SDL_VERTEXELEMENTFORMAT_FLOAT3,
    F32_x4 = C.SDL_VERTEXELEMENTFORMAT_FLOAT4,
    I8_x2 = C.SDL_VERTEXELEMENTFORMAT_BYTE2,
    I8_x4 = C.SDL_VERTEXELEMENTFORMAT_BYTE4,
    U8_x2 = C.SDL_VERTEXELEMENTFORMAT_UBYTE2,
    U8_x4 = C.SDL_VERTEXELEMENTFORMAT_UBYTE4,
    I8_x2_normalized = C.SDL_VERTEXELEMENTFORMAT_BYTE2_NORM,
    I8_x4_normalized = C.SDL_VERTEXELEMENTFORMAT_BYTE4_NORM,
    U8_x2_normalized = C.SDL_VERTEXELEMENTFORMAT_UBYTE2_NORM,
    U8_x4_normalized = C.SDL_VERTEXELEMENTFORMAT_UBYTE4_NORM,
    I16_x2 = C.SDL_VERTEXELEMENTFORMAT_SHORT2,
    I16_x4 = C.SDL_VERTEXELEMENTFORMAT_SHORT4,
    U16_x2 = C.SDL_VERTEXELEMENTFORMAT_USHORT2,
    U16_x4 = C.SDL_VERTEXELEMENTFORMAT_USHORT4,
    I16_x2_normalized = C.SDL_VERTEXELEMENTFORMAT_SHORT2_NORM,
    I16_x4_normalized = C.SDL_VERTEXELEMENTFORMAT_SHORT4_NORM,
    U16_x2_normalized = C.SDL_VERTEXELEMENTFORMAT_USHORT2_NORM,
    U16_x4_normalized = C.SDL_VERTEXELEMENTFORMAT_USHORT4_NORM,
    F16_x2 = C.SDL_VERTEXELEMENTFORMAT_HALF2,
    F16_x4 = C.SDL_VERTEXELEMENTFORMAT_HALF4,

    pub const to_c = c_enum_conversions(GPU_VertexElementFormat, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_VertexElementFormat, c_uint).from_c;
};

pub const GPU_Buffer = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_Buffer, C.SDL_GPUBuffer).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_Buffer, C.SDL_GPUBuffer).from_c_ptr;
};

pub const GPU_TransferBuffer = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_TransferBuffer, C.SDL_GPUTransferBuffer).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_TransferBuffer, C.SDL_GPUTransferBuffer).from_c_ptr;
};

pub const GPU_Texture = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_Texture, C.SDL_GPUTexture).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_Texture, C.SDL_GPUTexture).from_c_ptr;
};

pub const GPU_TextureSampler = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_TextureSampler, C.SDL_GPUSampler).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_TextureSampler, C.SDL_GPUSampler).from_c_ptr;
};

pub const GPU_Shader = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_Shader, C.SDL_GPUShader).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_Shader, C.SDL_GPUShader).from_c_ptr;
};

pub const GPU_ComputePipeline = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_ComputePipeline, C.SDL_GPUComputePipeline).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_ComputePipeline, C.SDL_GPUComputePipeline).from_c_ptr;
};

pub const GPU_GraphicsPipeline = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_GraphicsPipeline, C.SDL_GPUGraphicsPipeline).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_GraphicsPipeline, C.SDL_GPUGraphicsPipeline).from_c_ptr;
};

pub const GPU_CommandBuffer = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_CommandBuffer, C.SDL_GPUCommandBuffer).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_CommandBuffer, C.SDL_GPUCommandBuffer).from_c_ptr;

    pub fn insert_debug_label(self: *GPU_CommandBuffer, text: [*:0]const u8) void {
        C.SDL_InsertGPUDebugLabel(self.to_c_ptr(), text);
    }
    pub fn push_debug_group(self: *GPU_CommandBuffer, name: [*:0]const u8) void {
        C.SDL_PushGPUDebugGroup(self.to_c_ptr(), name);
    }
    pub fn pop_debug_group(self: *GPU_CommandBuffer) void {
        C.SDL_PopGPUDebugGroup(self.to_c_ptr());
    }
    pub fn push_vertex_uniform_data(self: *GPU_CommandBuffer, slot_index: u32, data_ptr: anytype) void {
        const data_raw = Utils.raw_slice_cast_const(data_ptr);
        C.SDL_PushGPUVertexUniformData(self.to_c_ptr(), slot_index, data_raw.ptr, @intCast(data_raw.len));
    }
    pub fn push_fragment_uniform_data(self: *GPU_CommandBuffer, slot_index: u32, data_ptr: anytype) void {
        const data_raw = Utils.raw_slice_cast_const(data_ptr);
        C.SDL_PushGPUFragmentUniformData(self.to_c_ptr(), slot_index, data_raw.ptr, @intCast(data_raw.len));
    }
    pub fn push_compute_uniform_data(self: *GPU_CommandBuffer, slot_index: u32, data_ptr: anytype) void {
        const data_raw = Utils.raw_slice_cast_const(data_ptr);
        C.SDL_PushGPUComputeUniformData(self.to_c_ptr(), slot_index, data_raw.ptr, @intCast(data_raw.len));
    }
    pub fn begin_render_pass(self: *GPU_CommandBuffer, color_targets: []const GPU_ColorTargetInfo, depth_stencil_target: *GPU_DepthStencilTargetInfo) Error!*GPU_RenderPass {
        return ptr_cast_or_fail_err(*GPU_RenderPass, C.SDL_BeginGPURenderPass(self.to_c_ptr(), @ptrCast(@alignCast(color_targets.ptr)), @intCast(color_targets.len), depth_stencil_target.to_c()));
    }
    pub fn begin_compute_pass(self: *GPU_CommandBuffer, storage_texture_bindings: []const GPU_StorageTextureReadWriteBinding, storage_buffer_bindings: []const GPU_StorageBufferReadWriteBinding) Error!*GPU_ComputePass {
        return ptr_cast_or_fail_err(*GPU_ComputePass, C.SDL_BeginGPUComputePass(self.to_c_ptr(), @ptrCast(@alignCast(storage_texture_bindings.ptr)), @intCast(storage_texture_bindings.len), @ptrCast(@alignCast(storage_buffer_bindings.ptr)), @intCast(storage_buffer_bindings.len)));
    }
    pub fn begin_copy_pass(self: *GPU_CommandBuffer) Error!*GPU_CopyPass {
        return ptr_cast_or_fail_err(*GPU_CopyPass, C.SDL_BeginGPUCopyPass(self.to_c_ptr()));
    }
    pub fn generate_mipmaps_for_texture(self: *GPU_CommandBuffer, texture: *GPU_Texture) void {
        C.SDL_GenerateMipmapsForGPUTexture(self.to_c_ptr(), texture.to_c_ptr());
    }
    pub fn blit_texture(self: *GPU_CommandBuffer, blit_info: *GPU_BlitInfo) void {
        C.SDL_GenerateMipmapsForGPUTexture(self.to_c_ptr(), blit_info.to_c_ptr());
    }
    pub fn aquire_swapchain_texture(self: *GPU_CommandBuffer, window: *Window) Error!GPU_SwapchainTexture {
        var tex: GPU_SwapchainTexture = undefined;
        try ok_or_null_err(C.SDL_AcquireGPUSwapchainTexture(self.to_c_ptr(), window.to_c_ptr(), tex.texture.to_c_ptr(), &tex.w, &tex.h));
        return tex;
    }
    pub fn wait_and_aquire_swapchain_texture(self: *GPU_CommandBuffer, window: *Window) Error!GPU_SwapchainTexture {
        var tex: GPU_SwapchainTexture = undefined;
        try ok_or_null_err(C.SDL_AcquireGPUSwapchainTexture(self.to_c_ptr(), window.to_c_ptr(), tex.texture.to_c_ptr(), &tex.w, &tex.h));
        return tex;
    }
    pub fn submit_commands(self: *GPU_CommandBuffer) Error!void {
        return ok_or_fail_err(C.SDL_SubmitGPUCommandBuffer(self.to_c_ptr()));
    }
    pub fn submit_commands_and_aquire_fence(self: *GPU_CommandBuffer) Error!GPU_Fence {
        return ptr_cast_or_fail_err(*GPU_Fence, C.SDL_SubmitGPUCommandBufferAndAcquireFence(self.to_c_ptr()));
    }
    pub fn cancel_commands(self: *GPU_CommandBuffer) Error!void {
        return ok_or_fail_err(C.SDL_CancelGPUCommandBuffer(self.to_c_ptr()));
    }
};

pub const GPU_SwapchainTexture = struct {
    texture: *GPU_Texture,
    w: u32,
    h: u32,
};

pub const GPU_RenderPass = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_RenderPass, C.SDL_GPURenderPass).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_RenderPass, C.SDL_GPURenderPass).from_c_ptr;

    pub fn bind_graphics_pipeline(self: *GPU_RenderPass, pipeline: *GPU_GraphicsPipeline) void {
        C.SDL_BindGPUGraphicsPipeline(self.to_c_ptr(), pipeline.to_c());
    }
    pub fn set_viewport(self: *GPU_RenderPass, viewport: GPU_Viewport) void {
        C.SDL_SetGPUViewport(self.to_c_ptr(), viewport.to_c());
    }
    pub fn clear_viewport(self: *GPU_RenderPass) void {
        C.SDL_SetGPUViewport(self.to_c_ptr(), null);
    }
    pub fn set_scissor(self: *GPU_RenderPass, scissor_rect: Rect_c_int) void {
        C.SDL_SetGPUScissor(self.to_c_ptr(), @ptrCast(@alignCast(&scissor_rect)));
    }
    pub fn clear_scissor(self: *GPU_RenderPass) void {
        C.SDL_SetGPUScissor(self.to_c_ptr(), null);
    }
    pub fn set_blend_constants(self: *GPU_RenderPass, blend_constants: Color_RGBA_f32) void {
        C.SDL_SetGPUBlendConstants(self.to_c_ptr(), @bitCast(blend_constants));
    }
    pub fn set_stencil_reference_val(self: *GPU_RenderPass, ref_val: u8) void {
        C.SDL_SetGPUStencilReference(self.to_c_ptr(), ref_val);
    }
    pub fn bind_vertex_buffers_to_consecutive_slots(self: *GPU_RenderPass, first_slot: u32, buffer_bindings: []const GPU_BufferBinding) void {
        C.SDL_BindGPUVertexBuffers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(buffer_bindings.ptr)), @intCast(buffer_bindings.len));
    }
    pub fn bind_index_buffer(self: *GPU_RenderPass, buffer_binding: *GPU_BufferBinding, index_type_size: GPU_IndexTypeSize) void {
        C.SDL_BindGPUIndexBuffer(self.to_c_ptr(), buffer_binding.to_c_ptr(), index_type_size.to_c());
    }
    pub fn bind_vertex_samplers_to_consecutive_slots(self: *GPU_RenderPass, first_slot: u32, sampler_bindings: []const GPU_TextureSamplerBinding) void {
        C.SDL_BindGPUVertexSamplers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(sampler_bindings.ptr)), @intCast(sampler_bindings.len));
    }
    pub fn bind_vertex_storage_textures_to_consecutive_slots(self: *GPU_RenderPass, first_slot: u32, storage_textures: []const GPU_Texture) void {
        C.SDL_BindGPUVertexStorageTextures(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(storage_textures.ptr)), @intCast(storage_textures.len));
    }
    pub fn bind_vertex_storage_buffers_to_consecutive_slots(self: *GPU_RenderPass, first_slot: u32, storage_buffers: []const GPU_Buffer) void {
        C.SDL_BindGPUVertexStorageBuffers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(storage_buffers.ptr)), @intCast(storage_buffers.len));
    }
    pub fn bind_fragment_samplers_to_consecutive_slots(self: *GPU_RenderPass, first_slot: u32, sampler_bindings: []const GPU_TextureSamplerBinding) void {
        C.SDL_BindGPUFragmentSamplers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(sampler_bindings.ptr)), @intCast(sampler_bindings.len));
    }
    pub fn bind_fragment_storage_textures_to_consecutive_slots(self: *GPU_RenderPass, first_slot: u32, storage_textures: []const GPU_Texture) void {
        C.SDL_BindGPUFragmentStorageTextures(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(storage_textures.ptr)), @intCast(storage_textures.len));
    }
    pub fn bind_fragment_storage_buffers_to_consecutive_slots(self: *GPU_RenderPass, first_slot: u32, storage_buffers: []const GPU_Buffer) void {
        C.SDL_BindGPUFragmentStorageBuffers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(storage_buffers.ptr)), @intCast(storage_buffers.len));
    }
    pub fn draw_primitives(self: *GPU_RenderPass, first_vertex: u32, num_vertexes: u32, first_instance_id: u32, num_instances: u32) void {
        C.SDL_DrawGPUPrimitives(self.to_c_ptr(), num_vertexes, num_instances, first_vertex, first_instance_id);
    }
    pub fn draw_indexed_primitives(self: *GPU_RenderPass, vertex_offset_per_index: i32, first_index: u32, num_indexes: u32, first_instance_id: u32, num_instances: u32) void {
        C.SDL_DrawGPUIndexedPrimitives(self.to_c_ptr(), num_indexes, num_instances, first_index, vertex_offset_per_index, first_instance_id);
    }
    pub fn draw_primitives_indirect(self: *GPU_RenderPass, buffer: *GPU_Buffer, offset: u32, draw_count: u32) void {
        C.SDL_DrawGPUPrimitivesIndirect(self.to_c_ptr(), buffer.to_c_ptr(), offset, draw_count);
    }
    pub fn draw_indexed_primitives_indirect(self: *GPU_RenderPass, buffer: *GPU_Buffer, offset: u32, draw_count: u32) void {
        C.SDL_DrawGPUIndexedPrimitivesIndirect(self.to_c_ptr(), buffer.to_c_ptr(), offset, draw_count);
    }
    pub fn end_render_pass(self: *GPU_RenderPass) void {
        C.SDL_EndGPURenderPass(self.to_c_ptr());
    }
};

pub const GPU_ComputePass = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_ComputePass, C.SDL_GPUComputePass).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_ComputePass, C.SDL_GPUComputePass).from_c_ptr;
    //TODO
    // pub extern fn SDL_BindGPUComputePipeline(compute_pass: ?*SDL_GPUComputePass, compute_pipeline: ?*SDL_GPUComputePipeline) void;
    // pub extern fn SDL_BindGPUComputeSamplers(compute_pass: ?*SDL_GPUComputePass, first_slot: Uint32, texture_sampler_bindings: [*c]const SDL_GPUTextureSamplerBinding, num_bindings: Uint32) void;
    // pub extern fn SDL_BindGPUComputeStorageTextures(compute_pass: ?*SDL_GPUComputePass, first_slot: Uint32, storage_textures: [*c]const ?*SDL_GPUTexture, num_bindings: Uint32) void;
    // pub extern fn SDL_BindGPUComputeStorageBuffers(compute_pass: ?*SDL_GPUComputePass, first_slot: Uint32, storage_buffers: [*c]const ?*SDL_GPUBuffer, num_bindings: Uint32) void;
    // pub extern fn SDL_DispatchGPUCompute(compute_pass: ?*SDL_GPUComputePass, groupcount_x: Uint32, groupcount_y: Uint32, groupcount_z: Uint32) void;
    // pub extern fn SDL_DispatchGPUComputeIndirect(compute_pass: ?*SDL_GPUComputePass, buffer: ?*SDL_GPUBuffer, offset: Uint32) void;
    // pub extern fn SDL_EndGPUComputePass(compute_pass: ?*SDL_GPUComputePass) void;
};

pub const GPU_CopyPass = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_CopyPass, C.SDL_GPUCopyPass).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_CopyPass, C.SDL_GPUCopyPass).from_c_ptr;
    //TODO
    // pub extern fn SDL_UploadToGPUTexture(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUTextureTransferInfo, destination: [*c]const SDL_GPUTextureRegion, cycle: bool) void;
    // pub extern fn SDL_UploadToGPUBuffer(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUTransferBufferLocation, destination: [*c]const SDL_GPUBufferRegion, cycle: bool) void;
    // pub extern fn SDL_CopyGPUTextureToTexture(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUTextureLocation, destination: [*c]const SDL_GPUTextureLocation, w: Uint32, h: Uint32, d: Uint32, cycle: bool) void;
    // pub extern fn SDL_CopyGPUBufferToBuffer(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUBufferLocation, destination: [*c]const SDL_GPUBufferLocation, size: Uint32, cycle: bool) void;
    // pub extern fn SDL_DownloadFromGPUTexture(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUTextureRegion, destination: [*c]const SDL_GPUTextureTransferInfo) void;
    // pub extern fn SDL_DownloadFromGPUBuffer(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUBufferRegion, destination: [*c]const SDL_GPUTransferBufferLocation) void;
    // pub extern fn SDL_EndGPUCopyPass(copy_pass: ?*SDL_GPUCopyPass) void;
};

pub const GPU_Fence = opaque {
    pub const to_c_ptr = c_opaque_conversions(GPU_Fence, C.SDL_GPUFence).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(GPU_Fence, C.SDL_GPUFence).from_c_ptr;
};

pub const GPU_PrimitiveType = enum(c_uint) {
    TRIANGLE_LIST = C.SDL_PRIMITIVETYPE_TRIANGLELIST,
    TRIANGLE_STRIP = C.SDL_PRIMITIVETYPE_TRIANGLESTRIP,
    LINE_LIST = C.SDL_PRIMITIVETYPE_LINELIST,
    LINE_STRIP = C.SDL_PRIMITIVETYPE_LINESTRIP,
    POINT_LIST = C.SDL_PRIMITIVETYPE_POINTLIST,

    pub const to_c = c_enum_conversions(GPU_PrimitiveType, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_PrimitiveType, c_uint).from_c;
};

pub const GPU_LoadOp = enum(c_uint) {
    LOAD = C.SDL_LOADOP_LOAD,
    CLEAR = C.SDL_LOADOP_CLEAR,
    DONT_CARE = C.SDL_LOADOP_DONT_CARE,

    pub const to_c = c_enum_conversions(GPU_LoadOp, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_LoadOp, c_uint).from_c;
};

pub const GPU_StoreOp = enum(c_uint) {
    STORE = C.SDL_STOREOP_STORE,
    DONT_CARE = C.SDL_STOREOP_DONT_CARE,
    RESOLVE = C.SDL_STOREOP_RESOLVE,
    RESOLVE_AND_STORE = C.SDL_STOREOP_RESOLVE_AND_STORE,

    pub const to_c = c_enum_conversions(GPU_StoreOp, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_StoreOp, c_uint).from_c;
};

pub const GPU_IndexTypeSize = enum(c_uint) {
    U16 = C.SDL_INDEXELEMENTSIZE_16BIT,
    U32 = C.SDL_INDEXELEMENTSIZE_32BIT,

    pub const to_c = c_enum_conversions(GPU_IndexTypeSize, C.SDL_GPUIndexElementSize).to_c;
    pub const from_c = c_enum_conversions(GPU_IndexTypeSize, C.SDL_GPUIndexElementSize).from_c;
};

pub const GPU_TextureFormat = enum(C.SDL_GPUTextureFormat) {
    INVALID = C.SDL_TEXTUREFORMAT_INVALID,
    A8_UNORM = C.SDL_TEXTUREFORMAT_A8_UNORM,
    R8_UNORM = C.SDL_TEXTUREFORMAT_R8_UNORM,
    R8G8_UNORM = C.SDL_TEXTUREFORMAT_R8G8_UNORM,
    R8G8B8A8_UNORM = C.SDL_TEXTUREFORMAT_R8G8B8A8_UNORM,
    R16_UNORM = C.SDL_TEXTUREFORMAT_R16_UNORM,
    R16G16_UNORM = C.SDL_TEXTUREFORMAT_R16G16_UNORM,
    R16G16B16A16_UNORM = C.SDL_TEXTUREFORMAT_R16G16B16A16_UNORM,
    R10G10B10A2_UNORM = C.SDL_TEXTUREFORMAT_R10G10B10A2_UNORM,
    B5G6R5_UNORM = C.SDL_TEXTUREFORMAT_B5G6R5_UNORM,
    B5G5R5A1_UNORM = C.SDL_TEXTUREFORMAT_B5G5R5A1_UNORM,
    B4G4R4A4_UNORM = C.SDL_TEXTUREFORMAT_B4G4R4A4_UNORM,
    B8G8R8A8_UNORM = C.SDL_TEXTUREFORMAT_B8G8R8A8_UNORM,
    BC1_RGBA_UNORM = C.SDL_TEXTUREFORMAT_BC1_RGBA_UNORM,
    BC2_RGBA_UNORM = C.SDL_TEXTUREFORMAT_BC2_RGBA_UNORM,
    BC3_RGBA_UNORM = C.SDL_TEXTUREFORMAT_BC3_RGBA_UNORM,
    BC4_R_UNORM = C.SDL_TEXTUREFORMAT_BC4_R_UNORM,
    BC5_RG_UNORM = C.SDL_TEXTUREFORMAT_BC5_RG_UNORM,
    BC7_RGBA_UNORM = C.SDL_TEXTUREFORMAT_BC7_RGBA_UNORM,
    BC6H_RGB_FLOAT = C.SDL_TEXTUREFORMAT_BC6H_RGB_FLOAT,
    BC6H_RGB_UFLOAT = C.SDL_TEXTUREFORMAT_BC6H_RGB_UFLOAT,
    R8_SNORM = C.SDL_TEXTUREFORMAT_R8_SNORM,
    R8G8_SNORM = C.SDL_TEXTUREFORMAT_R8G8_SNORM,
    R8G8B8A8_SNORM = C.SDL_TEXTUREFORMAT_R8G8B8A8_SNORM,
    R16_SNORM = C.SDL_TEXTUREFORMAT_R16_SNORM,
    R16G16_SNORM = C.SDL_TEXTUREFORMAT_R16G16_SNORM,
    R16G16B16A16_SNORM = C.SDL_TEXTUREFORMAT_R16G16B16A16_SNORM,
    R16_FLOAT = C.SDL_TEXTUREFORMAT_R16_FLOAT,
    R16G16_FLOAT = C.SDL_TEXTUREFORMAT_R16G16_FLOAT,
    R16G16B16A16_FLOAT = C.SDL_TEXTUREFORMAT_R16G16B16A16_FLOAT,
    R32_FLOAT = C.SDL_TEXTUREFORMAT_R32_FLOAT,
    R32G32_FLOAT = C.SDL_TEXTUREFORMAT_R32G32_FLOAT,
    R32G32B32A32_FLOAT = C.SDL_TEXTUREFORMAT_R32G32B32A32_FLOAT,
    R11G11B10_UFLOAT = C.SDL_TEXTUREFORMAT_R11G11B10_UFLOAT,
    R8_UINT = C.SDL_TEXTUREFORMAT_R8_UINT,
    R8G8_UINT = C.SDL_TEXTUREFORMAT_R8G8_UINT,
    R8G8B8A8_UINT = C.SDL_TEXTUREFORMAT_R8G8B8A8_UINT,
    R16_UINT = C.SDL_TEXTUREFORMAT_R16_UINT,
    R16G16_UINT = C.SDL_TEXTUREFORMAT_R16G16_UINT,
    R16G16B16A16_UINT = C.SDL_TEXTUREFORMAT_R16G16B16A16_UINT,
    R32_UINT = C.SDL_TEXTUREFORMAT_R32_UINT,
    R32G32_UINT = C.SDL_TEXTUREFORMAT_R32G32_UINT,
    R32G32B32A32_UINT = C.SDL_TEXTUREFORMAT_R32G32B32A32_UINT,
    R8_INT = C.SDL_TEXTUREFORMAT_R8_INT,
    R8G8_INT = C.SDL_TEXTUREFORMAT_R8G8_INT,
    R8G8B8A8_INT = C.SDL_TEXTUREFORMAT_R8G8B8A8_INT,
    R16_INT = C.SDL_TEXTUREFORMAT_R16_INT,
    R16G16_INT = C.SDL_TEXTUREFORMAT_R16G16_INT,
    R16G16B16A16_INT = C.SDL_TEXTUREFORMAT_R16G16B16A16_INT,
    R32_INT = C.SDL_TEXTUREFORMAT_R32_INT,
    R32G32_INT = C.SDL_TEXTUREFORMAT_R32G32_INT,
    R32G32B32A32_INT = C.SDL_TEXTUREFORMAT_R32G32B32A32_INT,
    R8G8B8A8_UNORM_SRGB = C.SDL_TEXTUREFORMAT_R8G8B8A8_UNORM_SRGB,
    B8G8R8A8_UNORM_SRGB = C.SDL_TEXTUREFORMAT_B8G8R8A8_UNORM_SRGB,
    BC1_RGBA_UNORM_SRGB = C.SDL_TEXTUREFORMAT_BC1_RGBA_UNORM_SRGB,
    BC2_RGBA_UNORM_SRGB = C.SDL_TEXTUREFORMAT_BC2_RGBA_UNORM_SRGB,
    BC3_RGBA_UNORM_SRGB = C.SDL_TEXTUREFORMAT_BC3_RGBA_UNORM_SRGB,
    BC7_RGBA_UNORM_SRGB = C.SDL_TEXTUREFORMAT_BC7_RGBA_UNORM_SRGB,
    D16_UNORM = C.SDL_TEXTUREFORMAT_D16_UNORM,
    D24_UNORM = C.SDL_TEXTUREFORMAT_D24_UNORM,
    D32_FLOAT = C.SDL_TEXTUREFORMAT_D32_FLOAT,
    D24_UNORM_S8_UINT = C.SDL_TEXTUREFORMAT_D24_UNORM_S8_UINT,
    D32_FLOAT_S8_UINT = C.SDL_TEXTUREFORMAT_D32_FLOAT_S8_UINT,
    ASTC_4x4_UNORM = C.SDL_TEXTUREFORMAT_ASTC_4x4_UNORM,
    ASTC_5x4_UNORM = C.SDL_TEXTUREFORMAT_ASTC_5x4_UNORM,
    ASTC_5x5_UNORM = C.SDL_TEXTUREFORMAT_ASTC_5x5_UNORM,
    ASTC_6x5_UNORM = C.SDL_TEXTUREFORMAT_ASTC_6x5_UNORM,
    ASTC_6x6_UNORM = C.SDL_TEXTUREFORMAT_ASTC_6x6_UNORM,
    ASTC_8x5_UNORM = C.SDL_TEXTUREFORMAT_ASTC_8x5_UNORM,
    ASTC_8x6_UNORM = C.SDL_TEXTUREFORMAT_ASTC_8x6_UNORM,
    ASTC_8x8_UNORM = C.SDL_TEXTUREFORMAT_ASTC_8x8_UNORM,
    ASTC_10x5_UNORM = C.SDL_TEXTUREFORMAT_ASTC_10x5_UNORM,
    ASTC_10x6_UNORM = C.SDL_TEXTUREFORMAT_ASTC_10x6_UNORM,
    ASTC_10x8_UNORM = C.SDL_TEXTUREFORMAT_ASTC_10x8_UNORM,
    ASTC_10x10_UNORM = C.SDL_TEXTUREFORMAT_ASTC_10x10_UNORM,
    ASTC_12x10_UNORM = C.SDL_TEXTUREFORMAT_ASTC_12x10_UNORM,
    ASTC_12x12_UNORM = C.SDL_TEXTUREFORMAT_ASTC_12x12_UNORM,
    ASTC_4x4_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_4x4_UNORM_SRGB,
    ASTC_5x4_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_5x4_UNORM_SRGB,
    ASTC_5x5_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_5x5_UNORM_SRGB,
    ASTC_6x5_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_6x5_UNORM_SRGB,
    ASTC_6x6_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_6x6_UNORM_SRGB,
    ASTC_8x5_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_8x5_UNORM_SRGB,
    ASTC_8x6_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_8x6_UNORM_SRGB,
    ASTC_8x8_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_8x8_UNORM_SRGB,
    ASTC_10x5_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_10x5_UNORM_SRGB,
    ASTC_10x6_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_10x6_UNORM_SRGB,
    ASTC_10x8_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_10x8_UNORM_SRGB,
    ASTC_10x10_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_10x10_UNORM_SRGB,
    ASTC_12x10_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_12x10_UNORM_SRGB,
    ASTC_12x12_UNORM_SRGB = C.SDL_TEXTUREFORMAT_ASTC_12x12_UNORM_SRGB,
    ASTC_4x4_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_4x4_FLOAT,
    ASTC_5x4_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_5x4_FLOAT,
    ASTC_5x5_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_5x5_FLOAT,
    ASTC_6x5_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_6x5_FLOAT,
    ASTC_6x6_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_6x6_FLOAT,
    ASTC_8x5_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_8x5_FLOAT,
    ASTC_8x6_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_8x6_FLOAT,
    ASTC_8x8_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_8x8_FLOAT,
    ASTC_10x5_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_10x5_FLOAT,
    ASTC_10x6_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_10x6_FLOAT,
    ASTC_10x8_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_10x8_FLOAT,
    ASTC_10x10_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_10x10_FLOAT,
    ASTC_12x10_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_12x10_FLOAT,
    ASTC_12x12_FLOAT = C.SDL_TEXTUREFORMAT_ASTC_12x12_FLOAT,

    pub const to_c = c_enum_conversions(GPU_TextureFormat, C.SDL_GPUTextureFormat).to_c;
    pub const from_c = c_enum_conversions(GPU_TextureFormat, C.SDL_GPUTextureFormat).from_c;

    pub fn texel_block_size(self: GPU_TextureFormat) u32 {
        return C.SDL_GPUTextureFormatTexelBlockSize(self.to_c());
    }
    pub fn calculate_texture_size(self: GPU_TextureFormat, size: Vec_c_uint, depth_or_layer_count: u32) u32 {
        return C.SDL_CalculateGPUTextureFormatSize(self.to_c(), size.x, size.y, depth_or_layer_count);
    }
};

pub const GPU_TextureUsageFlags = Flags(enum(u32) {
    SAMPLER = C.SDL_GPU_TEXTUREUSAGE_SAMPLER,
    COLOR_TARGET = C.SDL_GPU_TEXTUREUSAGE_COLOR_TARGET,
    DEPTH_STENCIL_TARGET = C.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
    GRAPHICS_STORAGE_READ = C.SDL_GPU_TEXTUREUSAGE_GRAPHICS_STORAGE_READ,
    COMPUTE_STORAGE_READ = C.SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_READ,
    COMPUTE_STORAGE_WRITE = C.SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_WRITE,
    COMPUTE_STORAGE_SIMULTANEOUS_READ_WRITE = C.SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_SIMULTANEOUS_READ_WRITE,
}, null);

pub const GPU_TextureType = enum(c_uint) {
    _2D = C.SDL_TEXTURETYPE_2D,
    _2D_ARRAY = C.SDL_TEXTURETYPE_2D_ARRAY,
    _3D = C.SDL_TEXTURETYPE_3D,
    CUBE = C.SDL_TEXTURETYPE_CUBE,
    CUBE_ARRAY = C.SDL_TEXTURETYPE_CUBE_ARRAY,

    pub const to_c = c_enum_conversions(GPU_TextureType, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_TextureType, c_uint).from_c;
};

pub const GPU_SampleCount = enum(c_uint) {
    _1 = C.SDL_SAMPLECOUNT_1,
    _2 = C.SDL_SAMPLECOUNT_2,
    _4 = C.SDL_SAMPLECOUNT_4,
    _8 = C.SDL_SAMPLECOUNT_8,

    pub const to_c = c_enum_conversions(GPU_SampleCount, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_SampleCount, c_uint).from_c;
};

pub const GPU_CubeMapFace = enum(c_uint) {
    POSITIVE_X = C.SDL_CUBEMAPFACE_POSITIVEX,
    NEGATIVE_X = C.SDL_CUBEMAPFACE_NEGATIVEX,
    POSITIVE_Y = C.SDL_CUBEMAPFACE_POSITIVEY,
    NEGATIVE_Y = C.SDL_CUBEMAPFACE_NEGATIVEY,
    POSITIVE_Z = C.SDL_CUBEMAPFACE_POSITIVEZ,
    NEGATIVE_Z = C.SDL_CUBEMAPFACE_NEGATIVEZ,

    pub const to_c = c_enum_conversions(GPU_CubeMapFace, c_uint).to_c;
    pub const from_c = c_enum_conversions(GPU_CubeMapFace, c_uint).from_c;
};

pub const GPU_BufferUsageFlags = Flags(enum(u32) {
    VERTEX = C.SDL_GPU_BUFFERUSAGE_VERTEX,
    INDEX = C.SDL_GPU_BUFFERUSAGE_INDEX,
    INDIRECT = C.SDL_GPU_BUFFERUSAGE_INDIRECT,
    GRAPHICS_STORAGE_READ = C.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
    COMPUTE_STORAGE_READ = C.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_READ,
    COMPUTE_STORAGE_WRITE = C.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
}, null);
pub const GPU_ShaderFormatFlags = Flags(enum(u32) {
    INVALID = C.SDL_GPU_SHADERFORMAT_INVALID,
    PRIVATE = C.SDL_GPU_SHADERFORMAT_PRIVATE,
    SPIRV = C.SDL_GPU_SHADERFORMAT_SPIRV,
    DXBC = C.SDL_GPU_SHADERFORMAT_DXBC,
    DXIL = C.SDL_GPU_SHADERFORMAT_DXIL,
    MSL = C.SDL_GPU_SHADERFORMAT_MSL,
    METALLIB = C.SDL_GPU_SHADERFORMAT_METALLIB,
}, null);
pub const GPU_ColorComponentFlags = Flags(enum(u8) {
    R = C.SDL_GPU_COLORCOMPONENT_R,
    G = C.SDL_GPU_COLORCOMPONENT_G,
    B = C.SDL_GPU_COLORCOMPONENT_B,
    A = C.SDL_GPU_COLORCOMPONENT_A,
}, null);
pub const Mem = struct {
    pub inline fn malloc(bytes: usize) ?*anyopaque {
        return C.SDL_malloc(bytes);
    }
    pub inline fn calloc(element_count: usize, element_size: usize) ?*anyopaque {
        return C.SDL_calloc(element_count, element_size);
    }
    pub inline fn realloc(mem: ?*anyopaque, new_bytes: usize) ?*anyopaque {
        return C.SDL_realloc(mem, new_bytes);
    }
    pub inline fn free(mem: ?*anyopaque) void {
        return C.SDL_free(mem);
    }
    pub inline fn aligned_alloc(alignment: usize, bytes: usize) ?*anyopaque {
        return C.SDL_aligned_alloc(alignment, bytes);
    }
    pub inline fn aligned_free(mem: ?*anyopaque) void {
        return C.SDL_aligned_free(mem);
    }
    pub inline fn get_allocation_count() c_int {
        return C.SDL_GetNumAllocations();
    }
    pub inline fn get_original_allocation_funcs() MemoryFuncs {
        var funcs: MemoryFuncs = undefined;
        C.SDL_GetOriginalMemoryFunctions(&funcs.malloc_fn, &funcs.calloc_fn, &funcs.realloc_fn, &funcs.free_fn);
        return funcs;
    }
    pub inline fn get_allocation_funcs() MemoryFuncs {
        var funcs: MemoryFuncs = undefined;
        C.SDL_GetMemoryFunctions(&funcs.malloc_fn, &funcs.calloc_fn, &funcs.realloc_fn, &funcs.free_fn);
        return funcs;
    }
    pub inline fn set_allocation_funcs(funcs: MemoryFuncs) Error!void {
        return ok_or_fail_err(C.SDL_SetMemoryFunctions(funcs.malloc_fn, funcs.calloc_fn, funcs.realloc_fn, funcs.free_fn));
    }
};

pub const MallocFunc = fn (usize) callconv(.c) ?*anyopaque;
pub const CallocFunc = fn (usize, usize) callconv(.c) ?*anyopaque;
pub const ReallocFunc = fn (?*anyopaque, usize) callconv(.c) ?*anyopaque;
pub const FreeFunc = fn (?*anyopaque) callconv(.c) void;

pub const MemoryFuncs = struct {
    malloc_fn: ?*const MallocFunc,
    calloc_fn: ?*const CallocFunc,
    realloc_fn: ?*const ReallocFunc,
    free_fn: ?*const FreeFunc,
};

pub const Environment = opaque {
    pub const to_c_ptr = c_opaque_conversions(Environment, C.SDL_Environment).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Environment, C.SDL_Environment).from_c_ptr;

    pub inline fn get_environment() Error!*Environment {
        return ptr_cast_or_null_err(*Environment, C.SDL_GetEnvironment());
    }
    pub inline fn create_environment(populate_with_env: bool) Error!*Environment {
        return ptr_cast_or_null_err(*Environment, C.SDL_CreateEnvironment(populate_with_env));
    }
    pub inline fn get_variable(self: *Environment, var_name: [*:0]const u8) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetEnvironmentVariable(self.to_c_ptr(), var_name));
    }
    pub inline fn get_all_variables(self: *Environment) Error!EnvVariablesList {
        const ptr = try ptr_cast_or_null_err([*:null]?[*:0]u8, C.SDL_GetEnvironmentVariables(self.to_c_ptr()));
        return EnvVariablesList{
            .vars = ptr,
        };
    }
    pub inline fn set_variable(self: *Environment, var_name: [*:0]const u8, value: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_SetEnvironmentVariable(self.to_c_ptr(), var_name, value));
    }
    pub inline fn unset_variable(self: *Environment, var_name: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_UnsetEnvironmentVariable(self.to_c_ptr(), var_name));
    }
    pub inline fn destroy(self: *Environment) void {
        return C.SDL_DestroyEnvironment(self.to_c_ptr());
    }
    pub inline fn get_env_variable(var_name: [*:0]const u8) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_getenv(var_name));
    }
    pub inline fn get_env_variable_unsafe(var_name: [*:0]const u8) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_getenv_unsafe(var_name));
    }
    pub inline fn set_env_variable_unsafe(var_name: [*:0]const u8, value: [*:0]const u8, overwrite: bool) Error!void {
        return greater_than_or_equal_to_zero_or_fail_err(C.SDL_setenv_unsafe(var_name, value, @intCast(@intFromBool(overwrite))));
    }
    pub inline fn unset_env_variable_unsafe(var_name: [*:0]const u8) Error!void {
        return greater_than_or_equal_to_zero_or_fail_err(C.SDL_unsetenv_unsafe(var_name));
    }
};

pub const EnvVariablesList = struct {
    vars: [*:null]?[*:0]u8,

    pub fn free(self: *EnvVariablesList) void {
        Mem.free(@ptrCast(self.vars));
    }
};

pub const HintPriority = enum(C.SDL_HintPriority) {
    DEFAULT = C.SDL_HINT_DEFAULT,
    NORMAL = C.SDL_HINT_NORMAL,
    OVERRIDE = C.SDL_HINT_OVERRIDE,

    pub const to_c = c_enum_conversions(HintPriority, C.SDL_HintPriority).to_c;
    pub const from_c = c_enum_conversions(HintPriority, C.SDL_HintPriority).from_c;
};

pub const HintChangeCallback = fn (userdata: ?*anyopaque, hint_name: ?[*:0]const u8, old_value: ?[*:0]const u8, new_value: ?[*:0]const u8) callconv(.c) void;
pub const MainThreadCallback = fn (userdata: ?*anyopaque) callconv(.c) void;

pub const App = struct {
    pub fn init(init_flags: InitFlags) Error!void {
        return ok_or_fail_err(C.SDL_Init(init_flags.raw));
    }
    pub fn init_subsystems(init_flags: InitFlags) Error!void {
        return ok_or_fail_err(C.SDL_InitSubSystem(init_flags.raw));
    }
    pub fn quit_subsystems(init_flags: InitFlags) Error!void {
        return ok_or_fail_err(C.SDL_QuitSubSystem(init_flags.raw));
    }
    pub fn init_state(subsystem_filter: InitFlags) InitFlags {
        return InitFlags.from_raw(C.SDL_WasInit(subsystem_filter.raw));
    }
    pub fn set_hint(hint_name: [*:0]const u8, hint_value: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_SetHint(hint_name, hint_value));
    }
    pub fn set_hint_with_priority(hint_name: [*:0]const u8, hint_value: [*:0]const u8, priority: HintPriority) Error!void {
        return ok_or_fail_err(C.SDL_SetHintWithPriority(hint_name, hint_value, priority.to_c()));
    }
    pub fn set_hint_to_default(hint_name: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_ResetHint(hint_name));
    }
    pub fn quit() void {
        C.SDL_Quit();
    }
    pub fn run_callback_on_main_thread(callback: *const MainThreadCallback, userdata: ?*anyopaque, wait_for_completion: bool) Error!void {
        return ok_or_fail_err(C.SDL_RunOnMainThread(callback, userdata, wait_for_completion));
    }
    pub fn this_thread_is_main_thread() bool {
        return C.SDL_IsMainThread();
    }
    pub fn set_all_hint_to_default() void {
        C.SDL_ResetHints();
    }
    pub fn get_hint_value(hint_name: [*:0]const u8) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetHint(hint_name));
    }
    pub fn get_hint_bool_or_fallback(hint_name: [*:0]const u8, return_if_null: bool) bool {
        return C.SDL_GetHintBoolean(hint_name, return_if_null);
    }
    pub fn add_hint_change_callback(hint_name: [*:0]const u8, callback: *const HintChangeCallback, userdata: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_AddHintCallback(hint_name, callback, userdata));
    }
    pub fn remove_hint_change_callback(hint_name: [*:0]const u8, callback: *const HintChangeCallback, userdata: ?*anyopaque) void {
        C.SDL_RemoveHintCallback(hint_name, callback, userdata);
    }
    pub fn sdl_main(arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) c_int {
        return C.SDL_main(arg_count, arg_list);
    }
    pub fn set_main_ready() void {
        C.SDL_SetMainReady();
    }
    pub fn run_app(arg_count: c_int, arg_list: ?[*:null]?[*:0]u8, main_func: *const AppMainFunc) c_int {
        return C.SDL_RunApp(arg_count, @ptrCast(@alignCast(arg_list)), main_func, null);
    }
    pub fn run_app_with_callbacks(arg_count: c_int, arg_list: ?[*:null]?[*:0]u8, init_func: *const AppInitFunc, update_func: *const AppUpdateFunc, event_func: *const AppEventFunc, quit_func: *const AppQuitFunc) c_int {
        return C.SDL_EnterAppMainCallbacks(arg_count, @ptrCast(@alignCast(arg_list)), Cast.ptr_cast(init_func, C.SDL_AppInit_func), Cast.ptr_cast(update_func, C.SDL_AppIterate_func), Cast.ptr_cast(event_func, C.SDL_AppEvent_func), Cast.ptr_cast(quit_func, C.SDL_AppQuit_func));
    }
    pub fn GDK_suspend_complete() void {
        C.SDL_GDKSuspendComplete();
    }
    pub fn get_error_details() [*:0]const u8 {
        return C.SDL_GetError();
    }
    pub inline fn set_out_of_memory_error() Error {
        _ = C.SDL_OutOfMemory();
        return Error.SDL_out_of_memory;
    }
    pub inline fn set_error(fmt: [*:0]const u8, args: anytype) Error {
        _ = @call(.auto, C.SDL_SetError, .{fmt} ++ args);
        return Error.SDL_custom_error;
    }
    pub inline fn clear_error() void {
        _ = C.SDL_ClearError();
    }
    pub fn set_metadata(app_name: [:0]const u8, app_version: [:0]const u8, app_identifier: [:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_SetAppMetadata(app_name.ptr, app_version.ptr, app_identifier.ptr));
    }
    pub fn set_metadata_property(prop_name: [:0]const u8, prop_val: [:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_SetAppMetadataProperty(prop_name.ptr, prop_val.ptr));
    }
    pub fn get_metadata_property(prop_name: [:0]const u8) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetAppMetadataProperty(prop_name.ptr));
    }
    pub fn set_assertion_handler(handler: *const AssertionHandler, userdata: ?*anyopaque) void {
        C.SDL_SetAssertionHandler(handler, userdata);
    }
    pub fn clear_assertion_handler() void {
        C.SDL_SetAssertionHandler(null, null);
    }
    pub fn get_default_assertion_handler() *const AssertionHandler {
        C.SDL_GetDefaultAssertionHandler().?;
    }
    pub fn get_assertion_handler_and_userdata() AssertionHandlerReturn {
        var handler: AssertionHandlerReturn = undefined;
        handler.func = C.SDL_GetAssertionHandler(&handler.userdata).?;
        return handler;
    }
    pub fn get_assertion_report() ?*const AssertData {
        return @ptrCast(C.SDL_GetAssertionReport());
    }
    pub fn reset_assertion_reports() void {
        C.SDL_ResetAssertionReport();
    }
    //TODO
    // pub extern fn SDL_OpenURL(url: [*c]const u8) bool;
    // pub extern fn SDL_GetPlatform() [*c]const u8;
    // pub extern fn SDL_IsTablet() bool;
    // pub extern fn SDL_IsTV() bool;
    // pub extern fn SDL_OnApplicationWillTerminate() void;
    // pub extern fn SDL_OnApplicationDidReceiveMemoryWarning() void;
    // pub extern fn SDL_OnApplicationWillEnterBackground() void;
    // pub extern fn SDL_OnApplicationDidEnterBackground() void;
    // pub extern fn SDL_OnApplicationWillEnterForeground() void;
    // pub extern fn SDL_OnApplicationDidEnterForeground() void;

    pub const Props = struct {
        pub const NAME = Property.new(.STRING, C.SDL_PROP_APP_METADATA_NAME_STRING);
        pub const VERSION = Property.new(.STRING, C.SDL_PROP_APP_METADATA_VERSION_STRING);
        pub const IDENTIFIER = Property.new(.STRING, C.SDL_PROP_APP_METADATA_IDENTIFIER_STRING);
        pub const CREATOR = Property.new(.STRING, C.SDL_PROP_APP_METADATA_CREATOR_STRING);
        pub const COPYRIGHT = Property.new(.STRING, C.SDL_PROP_APP_METADATA_COPYRIGHT_STRING);
        pub const URL = Property.new(.STRING, C.SDL_PROP_APP_METADATA_URL_STRING);
        pub const APP_TYPE = Property.new(.STRING, C.SDL_PROP_APP_METADATA_TYPE_STRING);
    };
};

pub const AppMainFunc = fn (arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) c_int;
pub const AppInitFunc = fn (app_state: ?*?*anyopaque, arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) AppResult;
pub const AppUpdateFunc = fn (app_state: ?*anyopaque) callconv(.c) AppResult;
pub const AppEventFunc = fn (app_state: ?*anyopaque, event: ?*Event) callconv(.c) AppResult;
pub const AppQuitFunc = fn (app_state: ?*anyopaque, quit_process_state: AppResult) callconv(.c) void;

pub const Sandbox = enum(C.SDL_Sandbox) {
    NONE = C.SDL_SANDBOX_NONE,
    UNKNOWN_CONTAINER = C.SDL_SANDBOX_UNKNOWN_CONTAINER,
    FLATPAK = C.SDL_SANDBOX_FLATPAK,
    SNAP = C.SDL_SANDBOX_SNAP,
    MACOS = C.SDL_SANDBOX_MACOS,

    pub const to_c = c_enum_conversions(Sandbox, C.SDL_Sandbox).to_c;
    pub const from_c = c_enum_conversions(Sandbox, C.SDL_Sandbox).from_c;
    //TODO
    // pub extern fn SDL_GetSandbox() SDL_Sandbox;
};

pub const SharedObject = opaque {
    pub const to_c_ptr = c_opaque_conversions(SharedObject, C.SDL_SharedObject).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(SharedObject, C.SDL_SharedObject).from_c_ptr;
    //TODO
    // pub extern fn SDL_LoadObject(sofile: [*c]const u8) ?*SDL_SharedObject;
    // pub extern fn SDL_LoadFunction(handle: ?*SDL_SharedObject, name: [*c]const u8) SDL_FunctionPointer;
    // pub extern fn SDL_UnloadObject(handle: ?*SDL_SharedObject) void;
};

pub const Locale = extern struct {
    language: ?[*:0]const u8 = null,
    country: ?[*:0]const u8 = null,

    pub const to_c_ptr = c_non_opaque_conversions(Locale, C.SDL_Locale).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(Locale, C.SDL_Locale).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(Locale, C.SDL_Locale).to_c;
    pub const from_c = c_non_opaque_conversions(Locale, C.SDL_Locale).from_c;
    //TODO
    // pub extern fn SDL_GetPreferredLocales(count: [*c]c_int) [*c][*c]SDL_Locale;
};
pub const PreferedLocaleList = struct {
    list: []*const Locale,

    pub fn free(self: PreferedLocaleList) void {
        Mem.free(self.list.ptr);
    }
};

pub const LogCategory = enum(C.SDL_LogCategory) {
    APPLICATION = C.SDL_LOG_CATEGORY_APPLICATION,
    ERROR = C.SDL_LOG_CATEGORY_ERROR,
    ASSERT = C.SDL_LOG_CATEGORY_ASSERT,
    SYSTEM = C.SDL_LOG_CATEGORY_SYSTEM,
    AUDIO = C.SDL_LOG_CATEGORY_AUDIO,
    VIDEO = C.SDL_LOG_CATEGORY_VIDEO,
    RENDER = C.SDL_LOG_CATEGORY_RENDER,
    INPUT = C.SDL_LOG_CATEGORY_INPUT,
    TEST = C.SDL_LOG_CATEGORY_TEST,
    GPU = C.SDL_LOG_CATEGORY_GPU,
    _,
    pub const CUSTOM_START = C.SDL_LOG_CATEGORY_CUSTOM;

    pub const to_c = c_enum_conversions(LogCategory, C.SDL_LogCategory).to_c;
    pub const from_c = c_enum_conversions(LogCategory, C.SDL_LogCategory).from_c;

    pub fn custom(tag_val: C.SDL_LogCategory) LogCategory {
        assert_with_reason(tag_val >= CUSTOM_START, @src(), "custom log categories must have a tag value greater than or equal to {d}", .{CUSTOM_START});
        return LogCategory.from_c(tag_val);
    }
};

pub const LogPriority = enum(C.SDL_LogPriority) {
    INVALID = C.SDL_LOG_PRIORITY_INVALID,
    TRACE = C.SDL_LOG_PRIORITY_TRACE,
    VERBOSE = C.SDL_LOG_PRIORITY_VERBOSE,
    DEBUG = C.SDL_LOG_PRIORITY_DEBUG,
    INFO = C.SDL_LOG_PRIORITY_INFO,
    WARN = C.SDL_LOG_PRIORITY_WARN,
    ERROR = C.SDL_LOG_PRIORITY_ERROR,
    CRITICAL = C.SDL_LOG_PRIORITY_CRITICAL,

    pub const COUNT = C.SDL_LOG_PRIORITY_COUNT;

    pub const to_c = c_enum_conversions(LogPriority, C.SDL_LogPriority).to_c;
    pub const from_c = c_enum_conversions(LogPriority, C.SDL_LogPriority).from_c;
};

pub const Logging = struct {
    //TODO
    // pub extern fn SDL_SetogPriorities(priority: SDL_LogPriority) void;
    // pub extern fn SDL_SetLogPriority(category: c_int, priority: SDL_LogPriority) void;
    // pub extern fn SDL_GetLogPriority(category: c_int) SDL_LogPriority;
    // pub extern fn SDL_ResetLogPriorities() void;
    // pub extern fn SDL_SetLogPriorityPrefix(priority: SDL_LogPriority, prefix: [*c]const u8) bool;
    // pub extern fn SDL_Log(fmt: [*c]const u8, ...) void;
    // pub extern fn SDL_LogTrace(category: c_int, fmt: [*c]const u8, ...) void;
    // pub extern fn SDL_LogVerbose(category: c_int, fmt: [*c]const u8, ...) void;
    // pub extern fn SDL_LogDebug(category: c_int, fmt: [*c]const u8, ...) void;
    // pub extern fn SDL_LogInfo(category: c_int, fmt: [*c]const u8, ...) void;
    // pub extern fn SDL_LogWarn(category: c_int, fmt: [*c]const u8, ...) void;
    // pub extern fn SDL_LogError(category: c_int, fmt: [*c]const u8, ...) void;
    // pub extern fn SDL_LogCritical(category: c_int, fmt: [*c]const u8, ...) void;
    // pub extern fn SDL_LogMessage(category: c_int, priority: SDL_LogPriority, fmt: [*c]const u8, ...) void;
    // pub extern fn SDL_GetDefaultLogOutputFunction() SDL_LogOutputFunction;
    // pub extern fn SDL_GetLogOutputFunction(callback: [*c]SDL_LogOutputFunction, userdata: [*c]?*anyopaque) void;
    // pub extern fn SDL_SetLogOutputFunction(callback: SDL_LogOutputFunction, userdata: ?*anyopaque) void;
};

pub const LogHandlerFunc = fn (userdata: ?*anyopaque, msg_category: c_int, msg_priority: LogPriority, msg: [*:0]const u8) callconv(.c) void;

pub const AssertionHandlerReturn = struct {
    func: *const AssertionHandler,
    userdata: ?*anyopaque,
};

pub const MessageBoxFlags = Flags(enum(C.SDL_MessageBoxFlags) {
    ERROR = C.SDL_MESSAGEBOX_ERROR,
    WARNING = C.SDL_MESSAGEBOX_WARNING,
    INFORMATION = C.SDL_MESSAGEBOX_INFORMATION,
    BUTTONS_LEFT_TO_RIGHT = C.SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT,
    BUTTONS_RIGHT_TO_LEFT = C.SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT,
}, null);

pub const MessageBoxButtonFlags = Flags(enum(C.SDL_MessageBoxButtonFlags) {
    RETURN_KEY_DEFAULT = C.SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
    ESCAPE_KEY_DEFAULT = C.SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT,
}, null);

pub const MessageBoxButtonData = extern struct {
    flags: MessageBoxButtonFlags = .blank(),
    button_id: c_int = 0,
    text: ?[*:0]const u8 = null,
};

pub const MessageBoxColorSlot = enum(C.SDL_MessageBoxColorType) {
    BACKGROUND = C.SDL_MESSAGEBOX_COLOR_BACKGROUND,
    TEXT = C.SDL_MESSAGEBOX_COLOR_TEXT,
    BUTTON_BORDER = C.SDL_MESSAGEBOX_COLOR_BUTTON_BORDER,
    BUTTON_BACKGROUND = C.SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND,
    BUTTON_SELECTED = C.SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED,

    pub const COUNT = C.SDL_MESSAGEBOX_COLOR_COUNT;

    pub const to_c = c_enum_conversions(MessageBoxColorSlot, C.SDL_MessageBoxColorType).to_c;
    pub const from_c = c_enum_conversions(MessageBoxColorSlot, C.SDL_MessageBoxColorType).from_c;
};

pub const MessageBoxColorScheme = extern struct {
    colors: [5]Color_RGB_u8 = @splat(Color_RGB_u8.BLACK),

    pub const to_c_ptr = c_non_opaque_conversions(MessageBoxColorScheme, C.SDL_MessageBoxColorScheme).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(MessageBoxColorScheme, C.SDL_MessageBoxColorScheme).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(MessageBoxColorScheme, C.SDL_MessageBoxColorScheme).to_c;
    pub const from_c = c_non_opaque_conversions(MessageBoxColorScheme, C.SDL_MessageBoxColorScheme).from_c;
};

pub const MessageBoxData = extern struct {
    flags: MessageBoxFlags = .blank(),
    window: ?*Window = null,
    title: ?[*:0]const u8 = null,
    message: ?[*:0]const u8 = null,
    num_buttons: c_int = 0,
    buttons: ?[*]const MessageBoxButtonData = null,
    color_scheme: ?*const MessageBoxColorScheme = null,

    pub const to_c_ptr = c_non_opaque_conversions(MessageBoxData, C.SDL_MessageBoxData).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(MessageBoxData, C.SDL_MessageBoxData).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(MessageBoxData, C.SDL_MessageBoxData).to_c;
    pub const from_c = c_non_opaque_conversions(MessageBoxData, C.SDL_MessageBoxData).from_c;

    //TODO
    // pub extern fn SDL_ShowMessageBox(messageboxdata: [*c]const SDL_MessageBoxData, buttonid: [*c]c_int) bool;
};

pub const MetalView = opaque {
    //TODO
    // pub extern fn SDL_Metal_DestroyView(view: SDL_MetalView) void;
    // pub extern fn SDL_Metal_GetLayer(view: SDL_MetalView) ?*anyopaque;
};

pub const AssertState = enum(C.SDL_AssertState) {
    RETRY = C.SDL_ASSERTION_RETRY,
    BREAK = C.SDL_ASSERTION_BREAK,
    ABORT = C.SDL_ASSERTION_ABORT,
    IGNORE = C.SDL_ASSERTION_IGNORE,
    ALWAYS_IGNORE = C.SDL_ASSERTION_ALWAYS_IGNORE,

    pub const to_c = c_enum_conversions(AssertState, C.SDL_AssertState).to_c;
    pub const from_c = c_enum_conversions(AssertState, C.SDL_AssertState).from_c;
};

pub const AssertData = extern struct {
    always_ignore: bool = false,
    trigger_count: c_uint = 0,
    condition_code: ?[*:0]const u8 = null,
    filename: ?[*:0]const u8 = null,
    line_num: c_int = 0,
    function_name: ?[*:0]const u8 = null,
    next: ?*const AssertData = null,

    pub const to_c_ptr = c_non_opaque_conversions(AssertData, C.SDL_AssertData).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(AssertData, C.SDL_AssertData).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(AssertData, C.SDL_AssertData).to_c;
    pub const from_c = c_non_opaque_conversions(AssertData, C.SDL_AssertData).from_c;
};

pub const AssertionHandler = fn (assert_data: *C.SDL_AssertData, userdata: ?*anyopaque) callconv(.c) C.SDL_AssertState;

pub const Process = opaque {
    pub const to_c_ptr = c_opaque_conversions(Process, C.SDL_Process).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Process, C.SDL_Process).from_c_ptr;
    //TODO
    // pub extern fn SDL_CreateProcess(args: [*c]const [*c]const u8, pipe_stdio: bool) ?*SDL_Process;
    // pub extern fn SDL_GetProcessProperties(process: ?*SDL_Process) SDL_PropertiesID;
    // pub extern fn SDL_ReadProcess(process: ?*SDL_Process, datasize: [*c]usize, exitcode: [*c]c_int) ?*anyopaque;
    // pub extern fn SDL_GetProcessInput(process: ?*SDL_Process) ?*SDL_IOStream;
    // pub extern fn SDL_GetProcessOutput(process: ?*SDL_Process) ?*SDL_IOStream;
    // pub extern fn SDL_KillProcess(process: ?*SDL_Process, force: bool) bool;
    // pub extern fn SDL_WaitProcess(process: ?*SDL_Process, block: bool, exitcode: [*c]c_int) bool;
    // pub extern fn SDL_DestroyProcess(process: ?*SDL_Process) void;

    pub const Props = struct {
        pub const ARGS = Property.new(.POINTER, C.SDL_PROP_PROCESS_CREATE_ARGS_POINTER);
        pub const ENVIRONMENT = Property.new(.POINTER, C.SDL_PROP_PROCESS_CREATE_ENVIRONMENT_POINTER);
        pub const STD_IN_OPTIONS = Property.new(.INTEGER, C.SDL_PROP_PROCESS_CREATE_STDIN_NUMBER);
        pub const STD_IN_SOURCE = Property.new(.POINTER, C.SDL_PROP_PROCESS_CREATE_STDIN_POINTER);
        pub const STD_OUT_OPTIONS = Property.new(.INTEGER, C.SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER);
        pub const STD_OUT_SOURCE = Property.new(.POINTER, C.SDL_PROP_PROCESS_CREATE_STDOUT_POINTER);
        pub const STD_ERR_OPTIONS = Property.new(.INTEGER, C.SDL_PROP_PROCESS_CREATE_STDERR_NUMBER);
        pub const STD_ERR_SOURCE = Property.new(.POINTER, C.SDL_PROP_PROCESS_CREATE_STDERR_POINTER);
        pub const SEND_STD_ERR_TO_STD_OUT = Property.new(.BOOLEAN, C.SDL_PROP_PROCESS_CREATE_STDERR_TO_STDOUT_BOOLEAN);
        pub const MAKE_BACKGROUND = Property.new(.BOOLEAN, C.SDL_PROP_PROCESS_CREATE_BACKGROUND_BOOLEAN);
        pub const PID = Property.new(.INTEGER, C.SDL_PROP_PROCESS_PID_NUMBER);
        pub const STD_IN = Property.new(.POINTER, C.SDL_PROP_PROCESS_STDIN_POINTER);
        pub const STD_OUT = Property.new(.POINTER, C.SDL_PROP_PROCESS_STDOUT_POINTER);
        pub const STD_ERR = Property.new(.POINTER, C.SDL_PROP_PROCESS_STDERR_POINTER);
        pub const BACKGROUND = Property.new(.BOOLEAN, C.SDL_PROP_PROCESS_BACKGROUND_BOOLEAN);
    };
};

pub const ProcessIO = enum(C.SDL_ProcessIO) {
    INHERITED = C.SDL_PROCESS_STDIO_INHERITED,
    NULL = C.SDL_PROCESS_STDIO_NULL,
    APP = C.SDL_PROCESS_STDIO_APP,
    REDIRECT = C.SDL_PROCESS_STDIO_REDIRECT,

    pub const to_c = c_enum_conversions(ProcessIO, C.SDL_ProcessIO).to_c;
    pub const from_c = c_enum_conversions(ProcessIO, C.SDL_ProcessIO).from_c;
};

pub const X11_Event = opaque {
    pub const to_c_ptr = c_opaque_conversions(X11_Event, C.XEvent).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(X11_Event, C.XEvent).from_c_ptr;
};

pub const X11_EventHook = fn (userdata: ?*anyopaque, event: ?*C.XEvent) callconv(.c) bool;

pub const X11 = struct {
    //TODO
    // pub extern fn SDL_SetX11EventHook(callback: SDL_X11EventHook, userdata: ?*anyopaque) void;
};

pub const DateTime = extern struct {
    year: c_int = 0,
    month: c_int = 0,
    day: c_int = 0,
    hour: c_int = 0,
    minute: c_int = 0,
    second: c_int = 0,
    nanosecond: c_int = 0,
    day_of_week: c_int = 0,
    utc_offset: c_int = 0,

    pub const to_c_ptr = c_non_opaque_conversions(DateTime, C.SDL_DateTime).to_c_ptr;
    pub const from_c_ptr = c_non_opaque_conversions(DateTime, C.SDL_DateTime).from_c_ptr;
    pub const to_c = c_non_opaque_conversions(DateTime, C.SDL_DateTime).to_c;
    pub const from_c = c_non_opaque_conversions(DateTime, C.SDL_DateTime).from_c;
    //TODO
    // pub extern fn SDL_DateTimeToTime(dt: [*c]const SDL_DateTime, ticks: [*c]SDL_Time) bool;
};

pub const DateFormat = enum(C.SDL_DateFormat) {
    YYYY_MM_DD = C.SDL_DATE_FORMAT_YYYYMMDD,
    DD_MM_YYYY = C.SDL_DATE_FORMAT_DDMMYYYY,
    MM_DD_YYYY = C.SDL_DATE_FORMAT_MMDDYYYY,

    pub const to_c = c_enum_conversions(DateFormat, C.SDL_DateFormat).to_c;
    pub const from_c = c_enum_conversions(DateFormat, C.SDL_DateFormat).from_c;
};

pub const TimeFormat = enum(C.SDL_TimeFormat) {
    _24_HR = C.SDL_TIME_FORMAT_24HR,
    _12_HR = C.SDL_TIME_FORMAT_12HR,

    pub const to_c = c_enum_conversions(TimeFormat, C.SDL_TimeFormat).to_c;
    pub const from_c = c_enum_conversions(TimeFormat, C.SDL_TimeFormat).from_c;
};

pub const Time = struct {
    pub fn wait_milliseconds(ms: u32) void {
        C.SDL_Delay(ms);
    }
    pub fn wait_nanoseconds(ns: u64) void {
        C.SDL_DelayNS(ns);
    }
    pub fn wait_milliseconds_precise(ms: u32) void {
        C.SDL_DelayPrecise(ms);
    }
    pub fn get_ticks_ms() u64 {
        return C.SDL_GetTicks();
    }
    pub fn get_ticks_ns() u64 {
        return C.SDL_GetTicksNS();
    }
    pub fn get_performance_counter() u64 {
        return C.SDL_GetPerformanceCounter();
    }
    pub fn get_performance_frequency() u64 {
        return C.SDL_GetPerformanceFrequency();
    }
    //TODO
    // pub extern fn SDL_GetDateTimeLocalePreferences(dateFormat: [*c]SDL_DateFormat, timeFormat: [*c]SDL_TimeFormat) bool;
    // pub extern fn SDL_GetCurrentTime(ticks: [*c]SDL_Time) bool;
    // pub extern fn SDL_TimeToDateTime(ticks: SDL_Time, dt: [*c]SDL_DateTime, localTime: bool) bool;
    // pub extern fn SDL_TimeToWindows(ticks: SDL_Time, dwLowDateTime: [*c]Uint32, dwHighDateTime: [*c]Uint32) void;
    // pub extern fn SDL_TimeFromWindows(dwLowDateTime: Uint32, dwHighDateTime: Uint32) SDL_Time;
    // pub extern fn SDL_GetDaysInMonth(year: c_int, month: c_int) c_int;
    // pub extern fn SDL_GetDayOfYear(year: c_int, month: c_int, day: c_int) c_int;
    // pub extern fn SDL_GetDayOfWeek(year: c_int, month: c_int, day: c_int) c_int;
    // pub extern fn SDL_AddTimer(interval: Uint32, callback: SDL_TimerCallback, userdata: ?*anyopaque) SDL_TimerID;
    // pub extern fn SDL_AddTimerNS(interval: Uint64, callback: SDL_NSTimerCallback, userdata: ?*anyopaque) SDL_TimerID;
    // pub extern fn SDL_RemoveTimer(id: SDL_TimerID) bool;
};

pub const TimerID = extern struct {
    id: u32,
};

pub const TimerCallback_MS = fn (userdata: ?*anyopaque, timer_id: u32, current_interval: u32) callconv(.c) u32;
pub const TimerCallback_NS = fn (userdata: ?*anyopaque, timer_id: u32, current_interval: u32) callconv(.c) u32;

pub const Tray = opaque {
    pub const to_c_ptr = c_opaque_conversions(Tray, C.SDL_Tray).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(Tray, C.SDL_Tray).from_c_ptr;

    //TODO
    // pub extern fn SDL_UpdateTrays() void;
    // pub extern fn SDL_CreateTray(icon: [*c]SDL_Surface, tooltip: [*c]const u8) ?*SDL_Tray;
    // pub extern fn SDL_SetTrayIcon(tray: ?*SDL_Tray, icon: [*c]SDL_Surface) void;
    // pub extern fn SDL_SetTrayTooltip(tray: ?*SDL_Tray, tooltip: [*c]const u8) void;
    // pub extern fn SDL_CreateTrayMenu(tray: ?*SDL_Tray) ?*SDL_TrayMenu;
    // pub extern fn SDL_GetTrayMenu(tray: ?*SDL_Tray) ?*SDL_TrayMenu;
    // pub extern fn SDL_DestroyTray(tray: ?*SDL_Tray) void;
};

pub const TrayMenu = opaque {
    pub const to_c_ptr = c_opaque_conversions(TrayMenu, C.SDL_TrayMenu).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(TrayMenu, C.SDL_TrayMenu).from_c_ptr;
    //TODO
    // pub extern fn SDL_GetTrayEntries(menu: ?*SDL_TrayMenu, count: [*c]c_int) [*c]?*const SDL_TrayEntry;
    // pub extern fn SDL_InsertTrayEntryAt(menu: ?*SDL_TrayMenu, pos: c_int, label: [*c]const u8, flags: SDL_TrayEntryFlags) ?*SDL_TrayEntry;
    // pub extern fn SDL_GetTrayMenuParentEntry(menu: ?*SDL_TrayMenu) ?*SDL_TrayEntry;
    // pub extern fn SDL_GetTrayMenuParentTray(menu: ?*SDL_TrayMenu) ?*SDL_Tray;
};

pub const TrayEntry = opaque {
    pub const to_c_ptr = c_opaque_conversions(TrayEntry, C.SDL_TrayEntry).to_c_ptr;
    pub const from_c_ptr = c_opaque_conversions(TrayEntry, C.SDL_TrayEntry).from_c_ptr;
    //TODO
    // pub extern fn SDL_CreateTraySubmenu(entry: ?*SDL_TrayEntry) ?*SDL_TrayMenu;
    // pub extern fn SDL_GetTraySubmenu(entry: ?*SDL_TrayEntry) ?*SDL_TrayMenu;
    // pub extern fn SDL_RemoveTrayEntry(entry: ?*SDL_TrayEntry) void;
    // pub extern fn SDL_SetTrayEntryLabel(entry: ?*SDL_TrayEntry, label: [*c]const u8) void;
    // pub extern fn SDL_GetTrayEntryLabel(entry: ?*SDL_TrayEntry) [*c]const u8;
    // pub extern fn SDL_SetTrayEntryChecked(entry: ?*SDL_TrayEntry, checked: bool) void;
    // pub extern fn SDL_GetTrayEntryChecked(entry: ?*SDL_TrayEntry) bool;
    // pub extern fn SDL_SetTrayEntryEnabled(entry: ?*SDL_TrayEntry, enabled: bool) void;
    // pub extern fn SDL_GetTrayEntryEnabled(entry: ?*SDL_TrayEntry) bool;
    // pub extern fn SDL_SetTrayEntryCallback(entry: ?*SDL_TrayEntry, callback: SDL_TrayCallback, userdata: ?*anyopaque) void;
    // pub extern fn SDL_ClickTrayEntry(entry: ?*SDL_TrayEntry) void;
    // pub extern fn SDL_GetTrayEntryParent(entry: ?*SDL_TrayEntry) ?*SDL_TrayMenu;
};

pub const TrayEntryFlags = Flags(enum(u32) {
    BUTTON = C.SDL_TRAYENTRY_BUTTON,
    CHECKBOX = C.SDL_TRAYENTRY_CHECKBOX,
    SUBMENU = C.SDL_TRAYENTRY_SUBMENU,
    DISABLED = C.SDL_TRAYENTRY_DISABLED,
    CHECKED = C.SDL_TRAYENTRY_CHECKED,
}, null);

pub const TrayCallback = fn (userdata: ?*anyopaque, entry: ?*C.SDL_TrayEntry) callconv(.c) void;
