const std = @import("std");
const build = @import("builtin");
const init_zero = std.mem.zeroes;
const assert = std.debug.assert;

const C = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
});

fn c_non_opaque_conversions(comptime ZIG_TYPE: type, comptime C_TYPE: type) type {
    return struct {
        fn to_c(self: ZIG_TYPE) C_TYPE {
            return @bitCast(self);
        }
        fn to_c_ptr(self: *ZIG_TYPE) *C_TYPE {
            return @ptrCast(@alignCast(self));
        }
        fn from_c(c_struct: C_TYPE) ZIG_TYPE {
            return @bitCast(c_struct);
        }
        fn from_c_ptr(c_ptr: *C_TYPE) *ZIG_TYPE {
            return @ptrCast(@alignCast(c_ptr));
        }
    };
}

fn c_opaque_conversions(comptime ZIG_TYPE: type, comptime C_TYPE: type) type {
    return struct {
        fn to_c_ptr(self: *ZIG_TYPE) *C_TYPE {
            return @ptrCast(@alignCast(self));
        }
        fn from_c_ptr(c_ptr: *C_TYPE) *ZIG_TYPE {
            return @ptrCast(@alignCast(c_ptr));
        }
    };
}

fn c_enum_conversions(comptime ZIG_TYPE: type, comptime C_TYPE: type) type {
    Utils.comptime_assert_with_reason(Utils.type_is_enum(ZIG_TYPE), "ZIG_TYPE not an enum");
    Utils.comptime_assert_with_reason(Utils.type_is_int(C_TYPE), "C_TYPE not an integer");
    return struct {
        fn to_c(self: ZIG_TYPE) C_TYPE {
            return @intFromEnum(self);
        }
        fn from_c(c_integer: C_TYPE) ZIG_TYPE {
            return @enumFromInt(c_integer);
        }
    };
}

const Root = @import("./_root.zig");
const Flags = Root.Flags.Flags;
const Utils = Root.Utils;

pub const Error = error{
    SDL_null_value,
    SDL_operation_failure,
    SDL_invalid_value,
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
inline fn positive_or_fail_err(result_int: anytype) Error!@TypeOf(result_int) {
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

pub const IRect = Root.Rect2.define_rect2_type(c_int);
pub const FRect = Root.Rect2.define_rect2_type(f32);
pub const IVec = Root.Vec2.define_vec2_type(c_int);
pub const IVec_16 = Root.Vec2.define_vec2_type(i16);
pub const FVec = Root.Vec2.define_vec2_type(f32);
pub const IColor_RGBA = Root.Color.define_color_rgba_type(u8);
pub const FColor_RGBA = Root.Color.define_color_rgba_type(f32);
pub const IColor_RGB = Root.Color.define_color_rgb_type(u8);
pub const FColor_RGB = Root.Color.define_color_rgb_type(f32);
pub const IColor_U32 = extern struct {
    raw: u32,
};

pub const AppMainFunc = fn (arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) c_int;
pub const AppInitFunc = fn (app_state: ?*?*anyopaque, arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) c_uint;
pub const AppUpdateFunc = fn (app_state: ?*anyopaque) callconv(.c) c_uint;
pub const AppEventFunc = fn (app_state: ?*anyopaque, event: ?*C.SDL_Event) callconv(.c) c_uint;
pub const AppQuitFunc = fn (app_state: ?*anyopaque, quit_process_state: c_uint) callconv(.c) void;

pub fn run_app(arg_count: c_int, arg_list: ?[*:null]?[*:0]u8, main_func: *const AppMainFunc) c_int {
    return C.SDL_RunApp(arg_count, @ptrCast(@alignCast(arg_list)), main_func, null);
}
pub fn run_app_with_callbacks(arg_count: c_int, arg_list: ?[*:null]?[*:0]u8, init_func: *const AppInitFunc, update_func: *const AppUpdateFunc, event_func: *const AppEventFunc, quit_func: *const AppQuitFunc) c_int {
    return C.SDL_EnterAppMainCallbacks(arg_count, @ptrCast(@alignCast(arg_list)), init_func, update_func, event_func, quit_func);
}

pub const Builtin = struct {
    //TODO
    // pub extern fn SDL_malloc(size: usize) ?*anyopaque;
    // pub extern fn SDL_calloc(nmemb: usize, size: usize) ?*anyopaque;
    // pub extern fn SDL_realloc(mem: ?*anyopaque, size: usize) ?*anyopaque;
    // pub extern fn SDL_free(mem: ?*anyopaque) void;
    // pub const SDL_malloc_func = ?*const fn (usize) callconv(.c) ?*anyopaque;
    // pub const SDL_calloc_func = ?*const fn (usize, usize) callconv(.c) ?*anyopaque;
    // pub const SDL_realloc_func = ?*const fn (?*anyopaque, usize) callconv(.c) ?*anyopaque;
    // pub const SDL_free_func = ?*const fn (?*anyopaque) callconv(.c) void;
    // pub extern fn SDL_GetOriginalMemoryFunctions(malloc_func: [*c]SDL_malloc_func, calloc_func: [*c]SDL_calloc_func, realloc_func: [*c]SDL_realloc_func, free_func: [*c]SDL_free_func) void;
    // pub extern fn SDL_GetMemoryFunctions(malloc_func: [*c]SDL_malloc_func, calloc_func: [*c]SDL_calloc_func, realloc_func: [*c]SDL_realloc_func, free_func: [*c]SDL_free_func) void;
    // pub extern fn SDL_SetMemoryFunctions(malloc_func: SDL_malloc_func, calloc_func: SDL_calloc_func, realloc_func: SDL_realloc_func, free_func: SDL_free_func) bool;
    // pub extern fn SDL_aligned_alloc(alignment: usize, size: usize) ?*anyopaque;
    // pub extern fn SDL_aligned_free(mem: ?*anyopaque) void;
    // pub extern fn SDL_GetNumAllocations() c_int;
    // pub const struct_SDL_Environment = opaque {};
    // pub const SDL_Environment = struct_SDL_Environment;
    // pub extern fn SDL_GetEnvironment() ?*SDL_Environment;
    // pub extern fn SDL_CreateEnvironment(populated: bool) ?*SDL_Environment;
    // pub extern fn SDL_GetEnvironmentVariable(env: ?*SDL_Environment, name: [*c]const u8) [*c]const u8;
    // pub extern fn SDL_GetEnvironmentVariables(env: ?*SDL_Environment) [*c][*c]u8;
    // pub extern fn SDL_SetEnvironmentVariable(env: ?*SDL_Environment, name: [*c]const u8, value: [*c]const u8, overwrite: bool) bool;
    // pub extern fn SDL_UnsetEnvironmentVariable(env: ?*SDL_Environment, name: [*c]const u8) bool;
    // pub extern fn SDL_DestroyEnvironment(env: ?*SDL_Environment) void;
    // pub extern fn SDL_getenv(name: [*c]const u8) [*c]const u8;
    // pub extern fn SDL_getenv_unsafe(name: [*c]const u8) [*c]const u8;
    // pub extern fn SDL_setenv_unsafe(name: [*c]const u8, value: [*c]const u8, overwrite: c_int) c_int;
    // pub extern fn SDL_unsetenv_unsafe(name: [*c]const u8) c_int;
    // pub const SDL_CompareCallback = ?*const fn (?*const anyopaque, ?*const anyopaque) callconv(.c) c_int;
    // pub extern fn SDL_qsort(base: ?*anyopaque, nmemb: usize, size: usize, compare: SDL_CompareCallback) void;
    // pub extern fn SDL_bsearch(key: ?*const anyopaque, base: ?*const anyopaque, nmemb: usize, size: usize, compare: SDL_CompareCallback) ?*anyopaque;
    // pub const SDL_CompareCallback_r = ?*const fn (?*anyopaque, ?*const anyopaque, ?*const anyopaque) callconv(.c) c_int;
    // pub extern fn SDL_qsort_r(base: ?*anyopaque, nmemb: usize, size: usize, compare: SDL_CompareCallback_r, userdata: ?*anyopaque) void;
    // pub extern fn SDL_bsearch_r(key: ?*const anyopaque, base: ?*const anyopaque, nmemb: usize, size: usize, compare: SDL_CompareCallback_r, userdata: ?*anyopaque) ?*anyopaque;
    // pub extern fn SDL_abs(x: c_int) c_int;
    // pub extern fn SDL_isalpha(x: c_int) c_int;
    // pub extern fn SDL_isalnum(x: c_int) c_int;
    // pub extern fn SDL_isblank(x: c_int) c_int;
    // pub extern fn SDL_iscntrl(x: c_int) c_int;
    // pub extern fn SDL_isdigit(x: c_int) c_int;
    // pub extern fn SDL_isxdigit(x: c_int) c_int;
    // pub extern fn SDL_ispunct(x: c_int) c_int;
    // pub extern fn SDL_isspace(x: c_int) c_int;
    // pub extern fn SDL_isupper(x: c_int) c_int;
    // pub extern fn SDL_islower(x: c_int) c_int;
    // pub extern fn SDL_isprint(x: c_int) c_int;
    // pub extern fn SDL_isgraph(x: c_int) c_int;
    // pub extern fn SDL_toupper(x: c_int) c_int;
    // pub extern fn SDL_tolower(x: c_int) c_int;
    // pub extern fn SDL_crc16(crc: Uint16, data: ?*const anyopaque, len: usize) Uint16;
    // pub extern fn SDL_crc32(crc: Uint32, data: ?*const anyopaque, len: usize) Uint32;
    // pub extern fn SDL_murmur3_32(data: ?*const anyopaque, len: usize, seed: Uint32) Uint32;
    // pub extern fn SDL_memcpy(dst: ?*anyopaque, src: ?*const anyopaque, len: usize) ?*anyopaque;
    // pub extern fn SDL_memmove(dst: ?*anyopaque, src: ?*const anyopaque, len: usize) ?*anyopaque;
    // pub extern fn SDL_memset(dst: ?*anyopaque, c: c_int, len: usize) ?*anyopaque;
    // pub extern fn SDL_memset4(dst: ?*anyopaque, val: Uint32, dwords: usize) ?*anyopaque;
    // pub extern fn SDL_memcmp(s1: ?*const anyopaque, s2: ?*const anyopaque, len: usize) c_int;
    // pub extern fn SDL_wcslen(wstr: [*c]const wchar_t) usize;
    // pub extern fn SDL_wcsnlen(wstr: [*c]const wchar_t, maxlen: usize) usize;
    // pub extern fn SDL_wcslcpy(dst: [*c]wchar_t, src: [*c]const wchar_t, maxlen: usize) usize;
    // pub extern fn SDL_wcslcat(dst: [*c]wchar_t, src: [*c]const wchar_t, maxlen: usize) usize;
    // pub extern fn SDL_wcsdup(wstr: [*c]const wchar_t) [*c]wchar_t;
    // pub extern fn SDL_wcsstr(haystack: [*c]const wchar_t, needle: [*c]const wchar_t) [*c]wchar_t;
    // pub extern fn SDL_wcsnstr(haystack: [*c]const wchar_t, needle: [*c]const wchar_t, maxlen: usize) [*c]wchar_t;
    // pub extern fn SDL_wcscmp(str1: [*c]const wchar_t, str2: [*c]const wchar_t) c_int;
    // pub extern fn SDL_wcsncmp(str1: [*c]const wchar_t, str2: [*c]const wchar_t, maxlen: usize) c_int;
    // pub extern fn SDL_wcscasecmp(str1: [*c]const wchar_t, str2: [*c]const wchar_t) c_int;
    // pub extern fn SDL_wcsncasecmp(str1: [*c]const wchar_t, str2: [*c]const wchar_t, maxlen: usize) c_int;
    // pub extern fn SDL_wcstol(str: [*c]const wchar_t, endp: [*c][*c]wchar_t, base: c_int) c_long;
    // pub extern fn SDL_strlen(str: [*c]const u8) usize;
    // pub extern fn SDL_strnlen(str: [*c]const u8, maxlen: usize) usize;
    // pub extern fn SDL_strlcpy(dst: [*c]u8, src: [*c]const u8, maxlen: usize) usize;
    // pub extern fn SDL_utf8strlcpy(dst: [*c]u8, src: [*c]const u8, dst_bytes: usize) usize;
    // pub extern fn SDL_strlcat(dst: [*c]u8, src: [*c]const u8, maxlen: usize) usize;
    // pub extern fn SDL_strdup(str: [*c]const u8) [*c]u8;
    // pub extern fn SDL_strndup(str: [*c]const u8, maxlen: usize) [*c]u8;
    // pub extern fn SDL_strrev(str: [*c]u8) [*c]u8;
    // pub extern fn SDL_strupr(str: [*c]u8) [*c]u8;
    // pub extern fn SDL_strlwr(str: [*c]u8) [*c]u8;
    // pub extern fn SDL_strchr(str: [*c]const u8, c: c_int) [*c]u8;
    // pub extern fn SDL_strrchr(str: [*c]const u8, c: c_int) [*c]u8;
    // pub extern fn SDL_strstr(haystack: [*c]const u8, needle: [*c]const u8) [*c]u8;
    // pub extern fn SDL_strnstr(haystack: [*c]const u8, needle: [*c]const u8, maxlen: usize) [*c]u8;
    // pub extern fn SDL_strcasestr(haystack: [*c]const u8, needle: [*c]const u8) [*c]u8;
    // pub extern fn SDL_strtok_r(str: [*c]u8, delim: [*c]const u8, saveptr: [*c][*c]u8) [*c]u8;
    // pub extern fn SDL_utf8strlen(str: [*c]const u8) usize;
    // pub extern fn SDL_utf8strnlen(str: [*c]const u8, bytes: usize) usize;
    // pub extern fn SDL_itoa(value: c_int, str: [*c]u8, radix: c_int) [*c]u8;
    // pub extern fn SDL_uitoa(value: c_uint, str: [*c]u8, radix: c_int) [*c]u8;
    // pub extern fn SDL_ltoa(value: c_long, str: [*c]u8, radix: c_int) [*c]u8;
    // pub extern fn SDL_ultoa(value: c_ulong, str: [*c]u8, radix: c_int) [*c]u8;
    // pub extern fn SDL_lltoa(value: c_longlong, str: [*c]u8, radix: c_int) [*c]u8;
    // pub extern fn SDL_ulltoa(value: c_ulonglong, str: [*c]u8, radix: c_int) [*c]u8;
    // pub extern fn SDL_atoi(str: [*c]const u8) c_int;
    // pub extern fn SDL_atof(str: [*c]const u8) f64;
    // pub extern fn SDL_strtol(str: [*c]const u8, endp: [*c][*c]u8, base: c_int) c_long;
    // pub extern fn SDL_strtoul(str: [*c]const u8, endp: [*c][*c]u8, base: c_int) c_ulong;
    // pub extern fn SDL_strtoll(str: [*c]const u8, endp: [*c][*c]u8, base: c_int) c_longlong;
    // pub extern fn SDL_strtoull(str: [*c]const u8, endp: [*c][*c]u8, base: c_int) c_ulonglong;
    // pub extern fn SDL_strtod(str: [*c]const u8, endp: [*c][*c]u8) f64;
    // pub extern fn SDL_strcmp(str1: [*c]const u8, str2: [*c]const u8) c_int;
    // pub extern fn SDL_strncmp(str1: [*c]const u8, str2: [*c]const u8, maxlen: usize) c_int;
    // pub extern fn SDL_strcasecmp(str1: [*c]const u8, str2: [*c]const u8) c_int;
    // pub extern fn SDL_strncasecmp(str1: [*c]const u8, str2: [*c]const u8, maxlen: usize) c_int;
    // pub extern fn SDL_strpbrk(str: [*c]const u8, breakset: [*c]const u8) [*c]u8;
    // pub extern fn SDL_StepUTF8(pstr: [*c][*c]const u8, pslen: [*c]usize) Uint32;
    // pub extern fn SDL_StepBackUTF8(start: [*c]const u8, pstr: [*c][*c]const u8) Uint32;
    // pub extern fn SDL_UCS4ToUTF8(codepoint: Uint32, dst: [*c]u8) [*c]u8;
    // pub extern fn SDL_sscanf(text: [*c]const u8, fmt: [*c]const u8, ...) c_int;
    // pub extern fn SDL_vsscanf(text: [*c]const u8, fmt: [*c]const u8, ap: [*c]struct___va_list_tag_1) c_int;
    // pub extern fn SDL_snprintf(text: [*c]u8, maxlen: usize, fmt: [*c]const u8, ...) c_int;
    // pub extern fn SDL_swprintf(text: [*c]wchar_t, maxlen: usize, fmt: [*c]const wchar_t, ...) c_int;
    // pub extern fn SDL_vsnprintf(text: [*c]u8, maxlen: usize, fmt: [*c]const u8, ap: [*c]struct___va_list_tag_1) c_int;
    // pub extern fn SDL_vswprintf(text: [*c]wchar_t, maxlen: usize, fmt: [*c]const wchar_t, ap: [*c]struct___va_list_tag_1) c_int;
    // pub extern fn SDL_asprintf(strp: [*c][*c]u8, fmt: [*c]const u8, ...) c_int;
    // pub extern fn SDL_vasprintf(strp: [*c][*c]u8, fmt: [*c]const u8, ap: [*c]struct___va_list_tag_1) c_int;
    // pub extern fn SDL_srand(seed: Uint64) void;
    // pub extern fn SDL_rand(n: Sint32) Sint32;
    // pub extern fn SDL_randf() f32;
    // pub extern fn SDL_rand_bits() Uint32;
    // pub extern fn SDL_rand_r(state: [*c]Uint64, n: Sint32) Sint32;
    // pub extern fn SDL_randf_r(state: [*c]Uint64) f32;
    // pub extern fn SDL_rand_bits_r(state: [*c]Uint64) Uint32;
    // pub extern fn SDL_acos(x: f64) f64;
    // pub extern fn SDL_acosf(x: f32) f32;
    // pub extern fn SDL_asin(x: f64) f64;
    // pub extern fn SDL_asinf(x: f32) f32;
    // pub extern fn SDL_atan(x: f64) f64;
    // pub extern fn SDL_atanf(x: f32) f32;
    // pub extern fn SDL_atan2(y: f64, x: f64) f64;
    // pub extern fn SDL_atan2f(y: f32, x: f32) f32;
    // pub extern fn SDL_ceil(x: f64) f64;
    // pub extern fn SDL_ceilf(x: f32) f32;
    // pub extern fn SDL_copysign(x: f64, y: f64) f64;
    // pub extern fn SDL_copysignf(x: f32, y: f32) f32;
    // pub extern fn SDL_cos(x: f64) f64;
    // pub extern fn SDL_cosf(x: f32) f32;
    // pub extern fn SDL_exp(x: f64) f64;
    // pub extern fn SDL_expf(x: f32) f32;
    // pub extern fn SDL_fabs(x: f64) f64;
    // pub extern fn SDL_fabsf(x: f32) f32;
    // pub extern fn SDL_floor(x: f64) f64;
    // pub extern fn SDL_floorf(x: f32) f32;
    // pub extern fn SDL_trunc(x: f64) f64;
    // pub extern fn SDL_truncf(x: f32) f32;
    // pub extern fn SDL_fmod(x: f64, y: f64) f64;
    // pub extern fn SDL_fmodf(x: f32, y: f32) f32;
    // pub extern fn SDL_isinf(x: f64) c_int;
    // pub extern fn SDL_isinff(x: f32) c_int;
    // pub extern fn SDL_isnan(x: f64) c_int;
    // pub extern fn SDL_isnanf(x: f32) c_int;
    // pub extern fn SDL_log(x: f64) f64;
    // pub extern fn SDL_logf(x: f32) f32;
    // pub extern fn SDL_log10(x: f64) f64;
    // pub extern fn SDL_log10f(x: f32) f32;
    // pub extern fn SDL_modf(x: f64, y: [*c]f64) f64;
    // pub extern fn SDL_modff(x: f32, y: [*c]f32) f32;
    // pub extern fn SDL_pow(x: f64, y: f64) f64;
    // pub extern fn SDL_powf(x: f32, y: f32) f32;
    // pub extern fn SDL_round(x: f64) f64;
    // pub extern fn SDL_roundf(x: f32) f32;
    // pub extern fn SDL_lround(x: f64) c_long;
    // pub extern fn SDL_lroundf(x: f32) c_long;
    // pub extern fn SDL_scalbn(x: f64, n: c_int) f64;
    // pub extern fn SDL_scalbnf(x: f32, n: c_int) f32;
    // pub extern fn SDL_sin(x: f64) f64;
    // pub extern fn SDL_sinf(x: f32) f32;
    // pub extern fn SDL_sqrt(x: f64) f64;
    // pub extern fn SDL_sqrtf(x: f32) f32;
    // pub extern fn SDL_tan(x: f64) f64;
    // pub extern fn SDL_tanf(x: f32) f32;
    // pub const struct_SDL_iconv_data_t = opaque {};
    // pub const SDL_iconv_t = ?*struct_SDL_iconv_data_t;
    // pub extern fn SDL_iconv_open(tocode: [*c]const u8, fromcode: [*c]const u8) SDL_iconv_t;
    // pub extern fn SDL_iconv_close(cd: SDL_iconv_t) c_int;
    // pub extern fn SDL_iconv(cd: SDL_iconv_t, inbuf: [*c][*c]const u8, inbytesleft: [*c]usize, outbuf: [*c][*c]u8, outbytesleft: [*c]usize) usize;
    // pub extern fn SDL_iconv_string(tocode: [*c]const u8, fromcode: [*c]const u8, inbuf: [*c]const u8, inbytesleft: usize) [*c]u8;
    // pub inline fn SDL_size_mul_check_overflow(arg_a: usize, arg_b: usize, arg_ret: [*c]usize) bool {
    //     var a = arg_a;
    //     _ = &a;
    //     var b = arg_b;
    //     _ = &b;
    //     var ret = arg_ret;
    //     _ = &ret;
    //     if ((a != @as(usize, @bitCast(@as(c_long, @as(c_int, 0))))) and (b > (@as(c_ulong, 18446744073709551615) / a))) {
    //         return @as(c_int, 0) != 0;
    //     }
    //     ret.* = a *% b;
    //     return @as(c_int, 1) != 0;
    // }
    // pub inline fn SDL_size_mul_check_overflow_builtin(arg_a: usize, arg_b: usize, arg_ret: [*c]usize) bool {
    //     var a = arg_a;
    //     _ = &a;
    //     var b = arg_b;
    //     _ = &b;
    //     var ret = arg_ret;
    //     _ = &ret;
    //     return @as(c_int, @intFromBool(__builtin_mul_overflow(a, b, ret))) == @as(c_int, 0);
    // }
    // pub inline fn SDL_size_add_check_overflow(arg_a: usize, arg_b: usize, arg_ret: [*c]usize) bool {
    //     var a = arg_a;
    //     _ = &a;
    //     var b = arg_b;
    //     _ = &b;
    //     var ret = arg_ret;
    //     _ = &ret;
    //     if (b > (@as(c_ulong, 18446744073709551615) -% a)) {
    //         return @as(c_int, 0) != 0;
    //     }
    //     ret.* = a +% b;
    //     return @as(c_int, 1) != 0;
    // }
    // pub extern fn SDL_size_add_check_overflow_builtin(arg_a: usize, arg_b: usize, arg_ret: [*c]usize) bool;
    // pub const SDL_FunctionPointer = ?*const fn () callconv(.c) void;
    // pub const SDL_ASSERTION_RETRY: c_int = 0;
    // pub const SDL_ASSERTION_BREAK: c_int = 1;
    // pub const SDL_ASSERTION_ABORT: c_int = 2;
    // pub const SDL_ASSERTION_IGNORE: c_int = 3;
    // pub const SDL_ASSERTION_ALWAYS_IGNORE: c_int = 4;
    // pub const enum_SDL_AssertState = c_uint;
    // pub const SDL_AssertState = enum_SDL_AssertState;
    // pub const struct_SDL_AssertData = extern struct {
    //     always_ignore: bool = @import("std").mem.zeroes(bool),
    //     trigger_count: c_uint = @import("std").mem.zeroes(c_uint),
    //     condition: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    //     filename: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    //     linenum: c_int = @import("std").mem.zeroes(c_int),
    //     function: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    //     next: [*c]const struct_SDL_AssertData = @import("std").mem.zeroes([*c]const struct_SDL_AssertData),
    // };
    // pub const SDL_AssertData = struct_SDL_AssertData;
    // pub extern fn SDL_ReportAssertion(data: [*c]SDL_AssertData, func: [*c]const u8, file: [*c]const u8, line: c_int) SDL_AssertState;
    // pub const SDL_AssertionHandler = ?*const fn ([*c]const SDL_AssertData, ?*anyopaque) callconv(.c) SDL_AssertState;
    // pub extern fn SDL_SetAssertionHandler(handler: SDL_AssertionHandler, userdata: ?*anyopaque) void;
    // pub extern fn SDL_GetDefaultAssertionHandler() SDL_AssertionHandler;
    // pub extern fn SDL_GetAssertionHandler(puserdata: [*c]?*anyopaque) SDL_AssertionHandler;
    // pub extern fn SDL_GetAssertionReport() [*c]const SDL_AssertData;
    // pub extern fn SDL_ResetAssertionReport() void;
    // pub const struct_SDL_AsyncIO = opaque {};
    // pub const SDL_AsyncIO = struct_SDL_AsyncIO;
    // pub const SDL_ASYNCIO_TASK_READ: c_int = 0;
    // pub const SDL_ASYNCIO_TASK_WRITE: c_int = 1;
    // pub const SDL_ASYNCIO_TASK_CLOSE: c_int = 2;
    // pub const enum_SDL_AsyncIOTaskType = c_uint;
    // pub const SDL_AsyncIOTaskType = enum_SDL_AsyncIOTaskType;
    // pub const SDL_ASYNCIO_COMPLETE: c_int = 0;
    // pub const SDL_ASYNCIO_FAILURE: c_int = 1;
    // pub const SDL_ASYNCIO_CANCELED: c_int = 2;
    // pub const enum_SDL_AsyncIOResult = c_uint;
    // pub const SDL_AsyncIOResult = enum_SDL_AsyncIOResult;
    // pub const struct_SDL_AsyncIOOutcome = extern struct {
    //     asyncio: ?*SDL_AsyncIO = @import("std").mem.zeroes(?*SDL_AsyncIO),
    //     type: SDL_AsyncIOTaskType = @import("std").mem.zeroes(SDL_AsyncIOTaskType),
    //     result: SDL_AsyncIOResult = @import("std").mem.zeroes(SDL_AsyncIOResult),
    //     buffer: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    //     offset: Uint64 = @import("std").mem.zeroes(Uint64),
    //     bytes_requested: Uint64 = @import("std").mem.zeroes(Uint64),
    //     bytes_transferred: Uint64 = @import("std").mem.zeroes(Uint64),
    //     userdata: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    // };
    // pub const SDL_AsyncIOOutcome = struct_SDL_AsyncIOOutcome;
    // pub const struct_SDL_AsyncIOQueue = opaque {};
    // pub const SDL_AsyncIOQueue = struct_SDL_AsyncIOQueue;
    // pub extern fn SDL_AsyncIOFromFile(file: [*c]const u8, mode: [*c]const u8) ?*SDL_AsyncIO;
    // pub extern fn SDL_GetAsyncIOSize(asyncio: ?*SDL_AsyncIO) Sint64;
    // pub extern fn SDL_ReadAsyncIO(asyncio: ?*SDL_AsyncIO, ptr: ?*anyopaque, offset: Uint64, size: Uint64, queue: ?*SDL_AsyncIOQueue, userdata: ?*anyopaque) bool;
    // pub extern fn SDL_WriteAsyncIO(asyncio: ?*SDL_AsyncIO, ptr: ?*anyopaque, offset: Uint64, size: Uint64, queue: ?*SDL_AsyncIOQueue, userdata: ?*anyopaque) bool;
    // pub extern fn SDL_CloseAsyncIO(asyncio: ?*SDL_AsyncIO, flush: bool, queue: ?*SDL_AsyncIOQueue, userdata: ?*anyopaque) bool;
    // pub extern fn SDL_CreateAsyncIOQueue() ?*SDL_AsyncIOQueue;
    // pub extern fn SDL_DestroyAsyncIOQueue(queue: ?*SDL_AsyncIOQueue) void;
    // pub extern fn SDL_GetAsyncIOResult(queue: ?*SDL_AsyncIOQueue, outcome: [*c]SDL_AsyncIOOutcome) bool;
    // pub extern fn SDL_WaitAsyncIOResult(queue: ?*SDL_AsyncIOQueue, outcome: [*c]SDL_AsyncIOOutcome, timeoutMS: Sint32) bool;
    // pub extern fn SDL_SignalAsyncIOQueue(queue: ?*SDL_AsyncIOQueue) void;
    // pub extern fn SDL_LoadFileAsync(file: [*c]const u8, queue: ?*SDL_AsyncIOQueue, userdata: ?*anyopaque) bool;
    // pub const SDL_SpinLock = c_int;
    // pub extern fn SDL_TryLockSpinlock(lock: [*c]SDL_SpinLock) bool;
    // pub extern fn SDL_LockSpinlock(lock: [*c]SDL_SpinLock) void;
    // pub extern fn SDL_UnlockSpinlock(lock: [*c]SDL_SpinLock) void;
    // pub extern fn SDL_MemoryBarrierReleaseFunction() void;
    // pub extern fn SDL_MemoryBarrierAcquireFunction() void;

    // pub const struct_SDL_AtomicU32 = extern struct {
    //     value: Uint32 = @import("std").mem.zeroes(Uint32),
    // };
    // pub const SDL_AtomicU32 = struct_SDL_AtomicU32;
    // pub extern fn SDL_CompareAndSwapAtomicU32(a: [*c]SDL_AtomicU32, oldval: Uint32, newval: Uint32) bool;
    // pub extern fn SDL_SetAtomicU32(a: [*c]SDL_AtomicU32, v: Uint32) Uint32;
    // pub extern fn SDL_GetAtomicU32(a: [*c]SDL_AtomicU32) Uint32;
    // pub extern fn SDL_CompareAndSwapAtomicPointer(a: [*c]?*anyopaque, oldval: ?*anyopaque, newval: ?*anyopaque) bool;
    // pub extern fn SDL_SetAtomicPointer(a: [*c]?*anyopaque, v: ?*anyopaque) ?*anyopaque;
    // pub extern fn SDL_GetAtomicPointer(a: [*c]?*anyopaque) ?*anyopaque;
    // pub fn __bswap_16(arg___bsx: __uint16_t) callconv(.c) __uint16_t {
    //     var __bsx = arg___bsx;
    //     _ = &__bsx;
    //     return @as(__uint16_t, @bitCast(@as(c_short, @truncate(((@as(c_int, @bitCast(@as(c_uint, __bsx))) >> @intCast(8)) & @as(c_int, 255)) | ((@as(c_int, @bitCast(@as(c_uint, __bsx))) & @as(c_int, 255)) << @intCast(8))))));
    // }
    // pub fn __bswap_32(arg___bsx: __uint32_t) callconv(.c) __uint32_t {
    //     var __bsx = arg___bsx;
    //     _ = &__bsx;
    //     return ((((__bsx & @as(c_uint, 4278190080)) >> @intCast(24)) | ((__bsx & @as(c_uint, 16711680)) >> @intCast(8))) | ((__bsx & @as(c_uint, 65280)) << @intCast(8))) | ((__bsx & @as(c_uint, 255)) << @intCast(24));
    // }
    // pub fn __bswap_64(arg___bsx: __uint64_t) callconv(.c) __uint64_t {
    //     var __bsx = arg___bsx;
    //     _ = &__bsx;
    //     return @as(__uint64_t, @bitCast(@as(c_ulong, @truncate(((((((((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 18374686479671623680)) >> @intCast(56)) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 71776119061217280)) >> @intCast(40))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 280375465082880)) >> @intCast(24))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 1095216660480)) >> @intCast(8))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 4278190080)) << @intCast(8))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 16711680)) << @intCast(24))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 65280)) << @intCast(40))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 255)) << @intCast(56))))));
    // }
    // pub fn __uint16_identity(arg___x: __uint16_t) callconv(.c) __uint16_t {
    //     var __x = arg___x;
    //     _ = &__x;
    //     return __x;
    // }
    // pub fn __uint32_identity(arg___x: __uint32_t) callconv(.c) __uint32_t {
    //     var __x = arg___x;
    //     _ = &__x;
    //     return __x;
    // }
    // pub fn __uint64_identity(arg___x: __uint64_t) callconv(.c) __uint64_t {
    //     var __x = arg___x;
    //     _ = &__x;
    //     return __x;
    // }
    // pub inline fn SDL_SwapFloat(arg_x: f32) f32 {
    //     var x = arg_x;
    //     _ = &x;
    //     const union_unnamed_4 = extern union {
    //         f: f32,
    //         ui32: Uint32,
    //     };
    //     _ = &union_unnamed_4;
    //     var swapper: union_unnamed_4 = undefined;
    //     _ = &swapper;
    //     swapper.f = x;
    //     swapper.ui32 = __builtin_bswap32(swapper.ui32);
    //     return swapper.f;
    // }
};

pub fn sdl_free(mem: ?*anyopaque) void {
    C.SDL_free(mem);
}
pub fn get_error_details() [*:0]const u8 {
    return C.SDL_GetError();
}
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
pub fn get_current_video_driver() Error![*:0]const u8 {
    return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetCurrentVideoDriver());
}
pub fn get_num_video_drivers() c_int {
    return C.SDL_GetNumVideoDrivers();
}
pub fn get_video_driver(index: c_int) Error![*:0]const u8 {
    return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetVideoDriver(index));
}
pub fn get_current_audio_driver() Error![*:0]const u8 {
    return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetCurrentAudioDriver());
}
pub fn get_num_audio_drivers() c_int {
    return C.SDL_GetNumAudioDrivers();
}
pub fn get_audio_driver(index: c_int) Error![*:0]const u8 {
    return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetAudioDriver(index));
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
pub fn init(init_flags: InitFlags) Error!void {
    return ok_or_fail_err(C.SDL_Init(init_flags.flags));
}
pub fn set_hint(hint_name: [:0]const u8, hint_value: [:0]const u8) Error!void {
    return ok_or_fail_err(C.SDL_SetHint(hint_name.ptr, hint_value.ptr));
}
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

pub const SeekRelativeTo = enum(c_uint) {
    RELATIVE_TO_START = C.SDL_IO_SEEK_SET,
    RELATIVE_TO_CURRENT = C.SDL_IO_SEEK_CUR,
    RELATIVE_TO_END = C.SDL_IO_SEEK_END,

    inline fn to_c(self: SeekRelativeTo) c_uint {
        return @intFromEnum(self);
    }
};

pub const IOStatus = enum(c_uint) {
    READY = C.SDL_IO_STATUS_READY,
    ERROR = C.SDL_IO_STATUS_ERROR,
    EOF = C.SDL_IO_STATUS_EOF,
    NOT_READY = C.SDL_IO_STATUS_NOT_READY,
    READONLY = C.SDL_IO_STATUS_READONLY,
    WRITEONLY = C.SDL_IO_STATUS_WRITEONLY,

    inline fn to_c(self: IOStatus) c_uint {
        return @intFromEnum(self);
    }
};

pub const IOStreamInterface = extern struct {
    version: u32 = 0,
    size: ?*const fn (user_data: ?*anyopaque) callconv(.c) i64 = null,
    seek: ?*const fn (user_data: ?*anyopaque, offset: i64, relative_to: SeekRelativeTo) callconv(.c) i64 = null,
    read_from_stream_into_ptr: ?*const fn (user_data: ?*anyopaque, ptr: ?[*]u8, read_len: usize, read_result_var: *IOStatus) callconv(.c) usize = null,
    write_from_ptr_into_stream: ?*const fn (user_data: ?*anyopaque, ptr: ?[*]const u8, write_len: usize, write_result_var: *IOStatus) callconv(.c) usize = null,
    flush: ?*const fn (user_data: ?*anyopaque, flush_result_var: *IOStatus) callconv(.c) bool = null,
    close: ?*const fn (user_data: ?*anyopaque) callconv(.c) bool = null,
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
        sdl_free(self.data.ptr);
        self.data = "";
    }

    pub fn from_buffer(buf: [:0]u8) IOFile {
        return IOFile{ .data = buf };
    }

    pub fn free(self: IOFile) void {
        sdl_free(self.data.ptr);
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
    pub fn from_custom_interface(iface: *IOStreamInterface, user_data: ?*anyopaque) Error!*IOStream {
        return ptr_cast_or_fail_err(*IOStream, C.SDL_OpenIO(@ptrCast(@alignCast(iface)), user_data));
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
        return positive_or_fail_err(C.SDL_SeekIO(self.to_c(), offset, relative_to.to_c()));
    }
    pub fn current_offest(self: *IOStream) Error!i64 {
        return positive_or_fail_err(C.SDL_TellIO(self.to_c()));
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
    // pub extern fn SDL_IOvprintf(context: ?*SDL_IOStream, fmt: [*c]const u8, ap: [*c]struct___va_list_tag_1) usize;
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
    pub fn save_bmp_to_new_surface(self: *IOStream, close_stream: bool) Error!*RenderAPI.Surface {
        return ptr_cast_or_fail_err(*RenderAPI.Surface, C.SDL_LoadBMP_IO(self.to_c(), close_stream));
    }
    pub fn load_bmp_from_surface(self: *IOStream, surface: *RenderAPI.Surface, close_stream: bool) Error!void {
        return ok_or_fail_err(C.SDL_SaveBMP_IO(surface.to_c(), self.to_c(), close_stream));
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
    // pub fn SDL_LoadWAV_IO(src: ?*SDL_IOStream, closeio: bool, spec: [*c]SDL_AudioSpec, audio_buf: [*c][*c]Uint8, audio_len: [*c]Uint32) bool;
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
        sdl_free(self.data.ptr);
    }
};

/// Helper struct for SDL functioons that require a `?*FRect` where:
/// - `null` == use entire area
/// - `*FRect` == use specific rect
///
/// As well as four values for edge widths
pub const FNinePatch = extern struct {
    rect_ptr: ?*const FRect = null,
    left: f32 = 0,
    right: f32 = 0,
    top: f32 = 0,
    bottom: f32 = 0,

    pub fn rect(r: *const FRect, left: f32, right: f32, top: f32, bottom: f32) FNinePatch {
        return FNinePatch{
            .rect_ptr = r,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    pub fn entire_area(left: f32, right: f32, top: f32, bottom: f32) FNinePatch {
        return FNinePatch{
            .rect_ptr = null,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    pub inline fn rect_to_c(self: FNinePatch) ?*C.SDL_FRect {
        return @ptrCast(@alignCast(self.rect_ptr));
    }
};

/// Helper struct for SDL functioons that require a `?*IRect` where:
/// - `null` == use entire area
/// - `*IRect` == use specific rect
///
/// As well as four values for edge widths
pub const INinePatch = extern struct {
    rect_ptr: ?*const IRect = null,
    left: c_int = 0,
    right: c_int = 0,
    top: c_int = 0,
    bottom: c_int = 0,

    pub fn rect(r: *const IRect, left: c_int, right: c_int, top: c_int, bottom: c_int) INinePatch {
        return INinePatch{
            .rect_ptr = r,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    pub fn entire_area(left: c_int, right: c_int, top: c_int, bottom: c_int) INinePatch {
        return INinePatch{
            .rect_ptr = null,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    pub inline fn rect_to_c(self: INinePatch) ?*C.SDL_Rect {
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
    pub fn set_pointer_property_with_cleanup(self: PropertiesID, name: [*:0]const u8, value: ?*anyopaque, cleanup: *PropertyCleanupCallback, user_data: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_SetPointerPropertyWithCleanup(self.id, name, value, @ptrCast(@alignCast(cleanup)), user_data));
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
    pub fn has_property(self: PropertiesID, name: [*:0]const u8) bool {
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
    pub fn do_callback_on_each_property(self: PropertiesID, callback: *EnumeratePropertiesCallback, user_data: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_EnumerateProperties(self.id, @ptrCast(@alignCast(callback)), user_data));
    }
    pub fn destroy(self: PropertiesID) void {
        C.SDL_DestroyProperties(self.id);
    }
};

pub const PropertyCleanupCallback = fn (user_data: ?*anyopaque, value_ptr: ?*anyopaque) callconv(.c) void;
pub const EnumeratePropertiesCallback = fn (user_data: ?*anyopaque, props_id: u32, prop_name: [*:0]const u8) callconv(.c) void;

pub const PropertyType = enum(c_uint) {
    INVALID = C.SDL_PROPERTY_TYPE_INVALID,
    POINTER = C.SDL_PROPERTY_TYPE_POINTER,
    STRING = C.SDL_PROPERTY_TYPE_STRING,
    INTEGER = C.SDL_PROPERTY_TYPE_NUMBER,
    FLOAT = C.SDL_PROPERTY_TYPE_FLOAT,
    BOOLEAN = C.SDL_PROPERTY_TYPE_BOOLEAN,

    inline fn to_c(self: PropertyType) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) PropertyType {
        return @enumFromInt(val);
    }
};

pub const InitStatus = enum(c_uint) {
    UNINIT = C.SDL_INIT_STATUS_UNINITIALIZED,
    INIT_IN_PROGRESS = C.SDL_INIT_STATUS_INITIALIZING,
    INIT = C.SDL_INIT_STATUS_INITIALIZED,
    UNINIT_IN_PROGRESS = C.SDL_INIT_STATUS_UNINITIALIZING,

    inline fn to_c(self: InitStatus) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) InitStatus {
        return @enumFromInt(val);
    }
};

pub const InitFlags = extern struct {
    flags: u32 = 0,

    pub fn new(flags: []const FLAG) InitFlags {
        var all_flags: u32 = 0;
        for (flags) |flag| {
            all_flags |= @intFromEnum(flag);
        }
        return InitFlags{ .flags = all_flags };
    }

    pub fn set(self: *InitFlags, flag: FLAG) void {
        self.flags |= @intFromEnum(flag);
    }
    pub fn clear(self: *InitFlags, flag: FLAG) void {
        self.flags &= ~@intFromEnum(flag);
    }

    pub const FLAG = enum(u32) {
        AUDIO = C.SDL_INIT_AUDIO,
        VIDEO = C.SDL_INIT_VIDEO,
        JOYSTICK = C.SDL_INIT_JOYSTICK,
        HAPTIC = C.SDL_INIT_HAPTIC,
        GAMEPAD = C.SDL_INIT_GAMEPAD,
        EVENTS = C.SDL_INIT_EVENTS,
        SENSOR = C.SDL_INIT_SENSOR,
        CAMERA = C.SDL_INIT_CAMERA,
    };
};

pub const AudioFormat = enum(c_uint) {
    UNKNOWN = C.SDL_AUDIO_UNKNOWN,
    U8 = C.SDL_AUDIO_U8,
    S8 = C.SDL_AUDIO_S8,
    S16LE = C.SDL_AUDIO_S16LE,
    S16BE = C.SDL_AUDIO_S16BE,
    S32LE = C.SDL_AUDIO_S32LE,
    S32BE = C.SDL_AUDIO_S32BE,
    F32BE = C.SDL_AUDIO_F32LE,
    F32LE = C.SDL_AUDIO_F32BE,

    inline fn to_c(self: AudioFormat) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) AudioFormat {
        return @enumFromInt(val);
    }

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

    usingnamespace c_enum_conversions(FlipMode, C.SDL_FlipMode);
};

pub const RenderAPI = struct {
    pub const Renderer = opaque {
        inline fn to_c(self: *Renderer) *C.SDL_Renderer {
            return @ptrCast(@alignCast(self));
        }
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
            return ptr_cast_or_null_err(*Window, C.SDL_GetRenderWindow(self.to_c()));
        }
        pub fn get_name(self: *Renderer) Error![*:0]const u8 {
            return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetRenderWindow(self.to_c()));
        }
        pub fn get_properties_id(self: *Renderer) Error!PropertiesID {
            return PropertiesID{ .id = try nonzero_or_null_err(C.SDL_GetRendererProperties(self.to_c())) };
        }
        pub fn get_true_output_size(self: *Renderer) Error!IVec {
            var size = IVec{};
            try ok_or_null_err(C.SDL_GetRenderOutputSize(self.to_c(), &size.x, &size.y));
            return size;
        }
        pub fn get_adjusted_output_size(self: *Renderer) Error!IVec {
            var size = IVec{};
            try ok_or_null_err(C.SDL_GetCurrentRenderOutputSize(self.to_c(), &size.x, &size.y));
            return size;
        }
        pub fn create_texture(self: *Renderer, format: PixelFormat, access_mode: TextureAccessMode, size: IVec) Error!*Texture {
            return ptr_cast_or_fail_err(*Texture, C.SDL_CreateTexture(self.to_c(), format.to_c(), access_mode.to_c(), size.x, size.y));
        }
        pub fn create_texture_from_surface(self: *Renderer, surface: *Surface) Error!*Texture {
            return ptr_cast_or_fail_err(*Texture, C.SDL_CreateTextureFromSurface(self.to_c(), @ptrCast(@alignCast(surface))));
        }
        pub fn create_texture_with_properties(self: *Renderer, props_id: PropertiesID) Error!*Texture {
            return ptr_cast_or_fail_err(*Texture, C.SDL_CreateTextureWithProperties(self.to_c(), props_id.id));
        }
        pub fn set_texture_target(self: *Renderer, texture: *Texture) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderTarget(self.to_c(), texture.to_c()));
        }
        pub fn clear_texture_target(self: *Renderer) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderTarget(self.to_c(), null));
        }
        pub fn get_texture_target(self: *Renderer) Error!*Texture {
            return ptr_cast_or_null_err(*Texture, C.SDL_GetRenderTarget(self.to_c()));
        }
        pub fn set_logical_presentation(self: *Renderer, presentation: LogicalPresentation) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderLogicalPresentation(self.to_c(), &presentation.size.x, &presentation.size.y, presentation.mode.to_c()));
        }
        pub fn get_logical_presentation(self: *Renderer) Error!LogicalPresentation {
            var pres = LogicalPresentation{};
            try ok_or_null_err(C.SDL_GetRenderLogicalPresentation(self.to_c(), &pres.size.x, &pres.size.y, @ptrCast(@alignCast(&pres.mode))));
            return pres;
        }
        pub fn get_logical_presentation_rect(self: *Renderer) Error!FRect {
            var rect = FRect{};
            try ok_or_null_err(C.SDL_GetRenderLogicalPresentationRect(self.to_c(), @ptrCast(@alignCast(&rect))));
            return rect;
        }
        pub fn render_coords_from_window(self: *Renderer, window_pos: FVec) Error!FVec {
            var vec = FVec{};
            try ok_or_fail_err(C.SDL_RenderCoordinatesFromWindow(self.to_c(), window_pos.x, window_pos.y, &vec.x, &vec.y));
            return vec;
        }
        pub fn render_coords_to_window(self: *Renderer, render_pos: FVec) Error!FVec {
            var vec = FVec{};
            try ok_or_fail_err(C.SDL_RenderCoordinatesToWindow(self.to_c(), render_pos.x, render_pos.y, &vec.x, &vec.y));
            return vec;
        }
        pub fn set_viewport(self: *Renderer, rect: IRect) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderViewport(self.to_c(), @ptrCast(@alignCast(&rect))));
        }
        pub fn clear_viewport(self: *Renderer) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderViewport(self.to_c(), null));
        }
        pub fn get_viewport(self: *Renderer) Error!IRect {
            var rect = IRect{};
            try ok_or_null_err(C.SDL_GetRenderViewport(self.to_c(), @ptrCast(@alignCast(&rect))));
            return rect;
        }
        pub fn viewport_is_set(self: *Renderer) bool {
            return C.SDL_RenderViewportSet(self.to_c());
        }
        pub fn get_safe_area(self: *Renderer) Error!IRect {
            var rect = IRect{};
            try ok_or_null_err(C.SDL_GetRenderSafeArea(self.to_c(), @ptrCast(@alignCast(&rect))));
            return rect;
        }
        pub fn set_clip_rect(self: *Renderer, rect: IRect) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderClipRect(self.to_c(), @ptrCast(@alignCast(&rect))));
        }
        pub fn clear_clip_rect(self: *Renderer) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderClipRect(self.to_c(), null));
        }
        pub fn get_clip_rect(self: *Renderer) Error!IRect {
            var rect = IRect{};
            try ok_or_null_err(C.SDL_GetRenderClipRect(self.to_c(), @ptrCast(@alignCast(&rect))));
            return rect;
        }
        pub fn clip_rect_is_set(self: *Renderer) bool {
            return C.SDL_RenderClipEnabled(self.to_c());
        }
        pub fn set_render_scale(self: *Renderer, scale: FVec) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderScale(self.to_c(), scale.x, scale.y));
        }
        pub fn get_render_scale(self: *Renderer) Error!FVec {
            var vec = FVec{};
            try ok_or_null_err(C.SDL_GetRenderScale(self.to_c(), &vec.x, &vec.y));
            return vec;
        }
        pub fn set_draw_color(self: *Renderer, color: IColor_RGBA) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderDrawColor(self.to_c(), color.r, color.g, color.b, color.a));
        }
        pub fn set_draw_color_float(self: *Renderer, color: FColor_RGBA) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderDrawColorFloat(self.to_c(), color.r, color.g, color.b, color.a));
        }
        pub fn get_draw_color(self: *Renderer) Error!IColor_RGBA {
            var color = IColor_RGBA{};
            try ok_or_null_err(C.SDL_GetRenderDrawColor(self.to_c(), &color.r, &color.g, &color.b, &color.a));
            return color;
        }
        pub fn get_draw_color_float(self: *Renderer) Error!FColor_RGBA {
            var color = FColor_RGBA{};
            try ok_or_null_err(C.SDL_GetRenderDrawColorFloat(self.to_c(), &color.r, &color.g, &color.b, &color.a));
            return color;
        }
        pub fn set_draw_color_scale(self: *Renderer, scale: f32) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderColorScale(self.to_c(), scale));
        }
        pub fn get_draw_color_scale(self: *Renderer) Error!f32 {
            var scale: f32 = 0.0;
            try ok_or_null_err(C.SDL_GetRenderColorScale(self.to_c(), &scale));
            return scale;
        }
        pub fn set_draw_blend_mode(self: *Renderer, mode: BlendMode) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderDrawBlendMode(self.to_c(), mode.mode));
        }
        pub fn get_draw_blend_mode(self: *Renderer) Error!BlendMode {
            var mode: u32 = 0;
            try ok_or_null_err(C.SDL_GetRenderDrawBlendMode(self.to_c(), &mode));
            return BlendMode{ .mode = mode };
        }
        pub fn draw_clear_fill(self: *Renderer) Error!void {
            return ok_or_fail_err(C.SDL_RenderClear(self.to_c()));
        }
        pub fn draw_point(self: *Renderer, point: *const FVec) Error!void {
            return ok_or_fail_err(C.SDL_RenderPoint(self.to_c(), point.x, point.y));
        }
        pub fn draw_many_points(self: *Renderer, points: []const FVec) Error!void {
            return ok_or_fail_err(C.SDL_RenderPoints(self.to_c(), @ptrCast(@alignCast(points.ptr)), @intCast(points.len)));
        }
        pub fn draw_line(self: *Renderer, point_a: *const FVec, point_b: *const FVec) Error!void {
            return ok_or_fail_err(C.SDL_RenderLine(self.to_c(), point_a.x, point_a.y, point_b.x, point_b.y));
        }
        pub fn draw_many_lines(self: *Renderer, points: []const FVec) Error!void {
            return ok_or_fail_err(C.SDL_RenderLines(self.to_c(), @ptrCast(@alignCast(points.ptr)), @intCast(points.len)));
        }
        pub fn draw_rect_outline(self: *Renderer, rect: *const FRect) Error!void {
            return ok_or_fail_err(C.SDL_RenderRect(self.to_c(), @ptrCast(@alignCast(rect))));
        }
        pub fn draw_many_rect_outlines(self: *Renderer, rects: []const FRect) Error!void {
            return ok_or_fail_err(C.SDL_RenderLines(self.to_c(), @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len)));
        }
        pub fn draw_rect_filled(self: *Renderer, rect: *const FRect) Error!void {
            return ok_or_fail_err(C.SDL_RenderRect(self.to_c(), @ptrCast(@alignCast(rect))));
        }
        pub fn draw_many_rects_filled(self: *Renderer, rects: []const FRect) Error!void {
            return ok_or_fail_err(C.SDL_RenderLines(self.to_c(), @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len)));
        }
        pub fn draw_texture_rect(self: *Renderer, texture: *Texture, tex_rect: FArea, target_rect: FArea) Error!void {
            return ok_or_fail_err(C.SDL_RenderTexture(self.to_c(), texture.to_c(), @ptrCast(@alignCast(tex_rect.rect_ptr)), @ptrCast(@alignCast(target_rect.rect_ptr))));
        }
        pub fn draw_texture_rect_rotated(self: *Renderer, texture: *Texture, tex_rect: FArea, target_rect: FArea, angle_deg: f32, pivot: ?*const FVec, flip: FlipMode) Error!void {
            return ok_or_fail_err(C.SDL_RenderTextureRotated(self.to_c(), texture.to_c(), @ptrCast(@alignCast(tex_rect)), @ptrCast(@alignCast(target_rect)), angle_deg, pivot, flip));
        }
        pub fn draw_texture_rect_affine(self: *Renderer, texture: *Texture, tex_rect: FArea, target_top_left: ?*const FVec, target_top_right: ?*const FVec, target_bot_left: ?*const FVec) Error!void {
            return ok_or_fail_err(C.SDL_RenderTextureAffine(self.to_c(), texture.to_c(), @ptrCast(@alignCast(tex_rect)), @ptrCast(@alignCast(target_top_left)), @ptrCast(@alignCast(target_top_right)), @ptrCast(@alignCast(target_bot_left))));
        }
        pub fn draw_texture_rect_tiled(self: *Renderer, texture: *Texture, tex_rect: ?*const FRect, tex_scale: f32, target_rect: ?*const FRect) Error!void {
            return ok_or_fail_err(C.SDL_RenderTextureTiled(self.to_c(), texture.to_c(), @ptrCast(@alignCast(tex_rect)), tex_scale, @ptrCast(@alignCast(target_rect))));
        }
        pub fn draw_texture_rect_nine_patch(self: *Renderer, texture: *Texture, tex_nine_patch: FNinePatch, edge_scale: f32, target_rect: ?*const FRect) Error!void {
            return ok_or_fail_err(C.SDL_RenderTexture9Grid(self.to_c(), texture.to_c(), @ptrCast(@alignCast(tex_nine_patch.rect)), tex_nine_patch.left, tex_nine_patch.right, tex_nine_patch.top, tex_nine_patch.bottom, edge_scale, @ptrCast(@alignCast(target_rect))));
        }
        pub fn draw_vertices_as_triangles(self: *Renderer, texture: ?*Texture, vertices: []const Vertex) Error!void {
            return ok_or_fail_err(C.SDL_RenderGeometry(self.to_c(), @ptrCast(@alignCast(texture)), @ptrCast(@alignCast(vertices.ptr)), @intCast(vertices.len), null, 0));
        }
        pub fn draw_indexed_vertices_as_triangles(self: *Renderer, texture: ?*Texture, vertices: []const Vertex, indices: []const c_int) Error!void {
            return ok_or_fail_err(C.SDL_RenderGeometry(self.to_c(), @ptrCast(@alignCast(texture)), @ptrCast(@alignCast(vertices.ptr)), @intCast(vertices.len), @ptrCast(@alignCast(indices.ptr)), @intCast(indices.len)));
        }
        pub fn draw_vertices_as_triangles_raw(self: *Renderer, texture: ?*Texture, pos_start: [*]const FVec, pos_stride: c_int, color_start: [*]const FColor_RGBA, color_stride: c_int, tex_coord_start: [*]const FVec, tex_coord_stride: c_int, vertex_count: c_int) Error!void {
            return ok_or_fail_err(C.SDL_RenderGeometryRaw(self.to_c(), @ptrCast(@alignCast(texture)), @ptrCast(@alignCast(pos_start.ptr)), pos_stride, @ptrCast(@alignCast(color_start.ptr)), color_stride, @ptrCast(@alignCast(tex_coord_start.ptr)), tex_coord_stride, vertex_count, null, 0, IndexType.U8.to_c()));
        }
        pub fn draw_indexed_vertices_as_triangles_raw(self: *Renderer, texture: ?*Texture, pos_start: [*]const FVec, pos_stride: c_int, color_start: [*]const FColor_RGBA, color_stride: c_int, tex_coord_start: [*]const FVec, tex_coord_stride: c_int, vertex_count: c_int, index_start: *anyopaque, index_count: c_int, index_type: IndexType) Error!void {
            return ok_or_fail_err(C.SDL_RenderGeometryRaw(self.to_c(), @ptrCast(@alignCast(texture)), @ptrCast(@alignCast(pos_start.ptr)), pos_stride, @ptrCast(@alignCast(color_start.ptr)), color_stride, @ptrCast(@alignCast(tex_coord_start.ptr)), tex_coord_stride, vertex_count, @ptrCast(@alignCast(index_start)), index_count, index_type.to_c()));
        }
        pub fn draw_debug_text(self: *Renderer, pos: FVec, text: [*:0]const u8) Error!void {
            return ok_or_fail_err(C.SDL_RenderDebugText(self.to_c(), pos.x, pos.y, @ptrCast(@alignCast(text))));
        }
        pub fn draw_debug_text_formatted(self: *Renderer, pos: FVec, format: [*:0]const u8, args: anytype) Error!void {
            return ok_or_fail_err(@call(.auto, C.SDL_RenderDebugText, .{ self.to_c(), pos.x, pos.y, @as([*c]const u8, @ptrCast(@alignCast(format))) } ++ args));
        }
        pub fn read_pixels_rect(self: *Renderer, rect: IRect) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_RenderReadPixels(self.to_c(), @ptrCast(@alignCast(&rect))));
        }
        pub fn read_pixels_all(self: *Renderer) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_RenderReadPixels(self.to_c(), null));
        }
        pub fn present(self: *Renderer) Error!void {
            return ok_or_fail_err(C.SDL_RenderPresent(self.to_c()));
        }
        pub fn destroy(self: *Renderer) void {
            C.SDL_DestroyRenderer(self.to_c());
        }
        pub fn flush(self: *Renderer) Error!void {
            return ok_or_fail_err(C.SDL_FlushRenderer(self.to_c()));
        }
        pub fn get_metal_layer(self: *Renderer) Error!*MetalLayer {
            return ptr_cast_or_null_err(*MetalLayer, C.SDL_GetRenderMetalLayer(self.to_c()));
        }
        pub fn get_metal_command_encoder(self: *Renderer) Error!*MetalCommandEncoder {
            return ptr_cast_or_null_err(*MetalCommandEncoder, C.SDL_GetRenderMetalCommandEncoder(self.to_c()));
        }
        pub fn add_vulkan_semaphores(self: *Renderer, wait_stage_mask: u32, wait_semaphore: i64, signal_semaphore: i64) Error!void {
            return ok_or_fail_err(C.SDL_AddVulkanRenderSemaphores(self.to_c(), wait_stage_mask, wait_semaphore, signal_semaphore));
        }
        pub fn set_vsync(self: *Renderer, v_sync: VSync) Error!void {
            return ok_or_fail_err(C.SDL_SetRenderVSync(self.to_c(), v_sync.to_c()));
        }
        pub fn get_vsync(self: *Renderer) Error!VSync {
            var val: c_int = 0;
            try ok_or_null_err(C.SDL_GetRenderVSync(self.to_c(), &val));
            return VSync.from_c(val);
        }
    };

    pub const TextureWriteBytes = extern struct {
        bytes: []u8,
        bytes_per_row: c_int,
        texture: ?*Texture,

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

        pub fn create(src_color_factor: RenderAPI.BlendFactor, dst_color_factor: RenderAPI.BlendFactor, color_operation: BlendOperation, src_alpha_factor: RenderAPI.BlendFactor, dst_alpha_factor: RenderAPI.BlendFactor, alpha_operation: BlendOperation) BlendMode {
            return BlendMode{ .mode = C.SDL_ComposeCustomBlendMode(src_color_factor.to_c(), dst_color_factor.to_c(), color_operation.to_c(), src_alpha_factor.to_c(), dst_alpha_factor.to_c(), alpha_operation.to_c()) };
        }
    };

    /// Helper Struct for SDL functions that expect a number of various
    /// properties pertaining to a rectangle of pixels
    pub const PixelRect = extern struct {
        size: IVec,
        ptr: [*]u8,
        bytes_per_row: c_int,
        pixel_format: PixelFormat,
        colorspace: Colorspace = .UNKNOWN,
        optional_color_properties: PropertiesID = PropertiesID.NULL,

        pub fn rect(size: IVec, ptr: [*]u8, bytes_per_row: c_uint, format: PixelFormat) PixelRect {
            return PixelRect{
                .size = size,
                .ptr = ptr,
                .bytes_per_row = bytes_per_row,
                .pixel_format = format,
            };
        }
        pub fn rect_with_colorspace(size: IVec, ptr: [*]u8, bytes_per_row: c_uint, format: PixelFormat, colorspace: Colorspace) PixelRect {
            return PixelRect{
                .size = size,
                .ptr = ptr,
                .bytes_per_row = bytes_per_row,
                .pixel_format = format,
                .colorspace = colorspace,
            };
        }
        pub fn rect_with_colorspace_and_props(size: IVec, ptr: [*]u8, bytes_per_row: c_uint, format: PixelFormat, colorspace: Colorspace, properties: PropertiesID) PixelRect {
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

    pub const Surface = opaque {
        inline fn to_c(self: *Surface) *C.SDL_Surface {
            return @ptrCast(@alignCast(self));
        }
        pub inline fn get_flags(self: *Surface) SurfaceFlags {
            return SurfaceFlags{ .flags = self.to_c().flags };
        }
        pub inline fn get_format(self: *Surface) PixelFormat {
            return @enumFromInt(self.to_c().format);
        }
        pub inline fn get_size(self: *Surface) IVec {
            const c = self.to_c();
            return IVec{
                .x = c.w,
                .y = c.h,
            };
        }
        pub inline fn get_bytes_per_row(self: *Surface) c_int {
            return self.to_c().pitch;
        }
        pub inline fn get_pixel_data_ptr(self: *Surface) ?[*]u8 {
            return @ptrCast(@alignCast(self.to_c().pixels));
        }
        pub inline fn get_ref_count(self: *Surface) c_int {
            return self.to_c().refcount;
        }
        pub inline fn get_reserved_ptr(self: *Surface) ?*anyopaque {
            return self.to_c().reserved;
        }
        pub fn create_surface(size: IVec, format: PixelFormat) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_CreateSurface(size.x, size.y, format));
        }
        pub fn create_surface_from(size: IVec, format: PixelFormat, pixel_data: [*]u8, bytes_per_row: c_int) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_CreateSurface(size.x, size.y, format, @ptrCast(@alignCast(pixel_data)), bytes_per_row));
        }
        pub fn destroy(self: *Surface) void {
            C.SDL_DestroySurface(self.to_c());
        }
        pub fn get_properties(self: *Surface) Error!PropertiesID {
            return PropertiesID{ .id = try nonzero_or_null_err(C.SDL_GetSurfaceProperties(self.to_c())) };
        }
        pub fn set_colorspace(self: *Surface, colorspace: Colorspace) Error!void {
            try ok_or_fail_err(C.SDL_SetSurfaceColorspace(self.to_c(), colorspace.to_c()));
        }
        pub fn get_colorspace(self: *Surface) Colorspace {
            C.SDL_GetSurfaceColorspace(self.to_c());
        }
        pub fn create_color_palette(self: *Surface) Error!*ColorPalette {
            return ptr_cast_or_fail_err(*ColorPalette, C.SDL_CreateSurfacePalette(self.to_c()));
        }
        pub fn set_color_palette(self: *Surface, palette: ColorPalette) Error!void {
            try ok_or_fail_err(C.SDL_SetSurfacePalette(self.to_c(), palette.to_c()));
        }
        pub fn get_color_palette(self: *Surface) Error!*ColorPalette {
            return ptr_cast_or_null_err(*ColorPalette, C.SDL_GetSurfacePalette(self.to_c()));
        }
        pub fn add_alternate_surface(self: *Surface, alternate: *Surface) Error!void {
            try ok_or_fail_err(C.SDL_AddSurfaceAlternateImage(self.to_c(), alternate.to_c()));
        }
        pub fn has_alternate_surfaces(self: *Surface) bool {
            return C.SDL_SurfaceHasAlternateImages(self.to_c());
        }
        pub fn get_all_alternate_surfaces(self: *Surface) Error!SurfaceList {
            var len: c_int = 0;
            const ptr = try ptr_cast_or_null_err([*]*Surface, C.SDL_GetSurfaceImages(self.to_c(), &len));
            return SurfaceList{ .list = ptr[0..len] };
        }
        pub fn remove_all_alternate_surfaces(self: *Surface) Error!void {
            return ok_or_fail_err(C.SDL_RemoveSurfaceAlternateImages(self.to_c()));
        }
        pub fn lock(self: *Surface) Error!void {
            return ok_or_fail_err(C.SDL_LockSurface(self.to_c()));
        }
        pub fn unlock(self: *Surface) Error!void {
            return ok_or_fail_err(C.SDL_UnlockSurface(self.to_c()));
        }
        pub fn load_from_bmp_file(bmp_path: [*:0]const u8) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_LoadBMP(bmp_path));
        }
        pub fn save_to_bmp_file(self: *Surface, bmp_path: [*:0]const u8) Error!void {
            return ok_or_fail_err(C.SDL_SaveBMP(self.to_c(), bmp_path));
        }
        pub fn load_from_bmp_iostream(stream: *IOStream, close_stream: bool) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_LoadBMP_IO(stream.to_c(), close_stream));
        }
        pub fn save_to_bmp_iostream(self: *Surface, stream: *IOStream, close_stream: bool) Error!void {
            return ok_or_fail_err(C.SDL_SaveBMP_IO(self.to_c(), stream.to_c(), close_stream));
        }
        pub fn set_RLE(self: *Surface, state: bool) Error!void {
            return ok_or_fail_err(C.SDL_SetSurfaceRLE(self.to_c(), state));
        }
        pub fn is_RLE_set(self: *Surface) bool {
            return ok_or_fail_err(C.SDL_SurfaceHasRLE(self.to_c()));
        }
        pub fn set_color_key(self: *Surface, state: bool, key: u32) Error!void {
            return ok_or_fail_err(C.SDL_SetSurfaceColorKey(self.to_c(), state, key));
        }
        pub fn has_color_key(self: *Surface) bool {
            return ok_or_fail_err(C.SDL_SurfaceHasColorKey(self.to_c()));
        }
        pub fn get_color_key(self: *Surface) Error!u32 {
            var key: u32 = 0;
            try ok_or_fail_err(C.SDL_GetSurfaceColorKey(self.to_c(), &key));
            return key;
        }
        pub fn set_color_mod(self: *Surface, color: IColor_RGB) Error!void {
            return ok_or_fail_err(C.SDL_SetSurfaceColorMod(self.to_c(), color.r, color.g, color.b));
        }
        pub fn get_color_mod(self: *Surface) Error!IColor_RGB {
            var color: IColor_RGB = IColor_RGB{};
            try ok_or_fail_err(C.SDL_GetSurfaceColorMod(self.to_c(), &color.r, &color.g, &color.b));
            return color;
        }
        pub fn set_alpha_mod(self: *Surface, alpha: u8) Error!void {
            return ok_or_fail_err(C.SDL_SetSurfaceAlphaMod(self.to_c(), alpha));
        }
        pub fn get_alpha_mod(self: *Surface) Error!u8 {
            var alpha: u8 = 0;
            try ok_or_fail_err(C.SDL_GetSurfaceColorMod(self.to_c(), &alpha));
            return alpha;
        }
        pub fn set_blend_mode(self: *Surface, mode: BlendMode) Error!void {
            return ok_or_fail_err(C.SDL_SetSurfaceBlendMode(self.to_c(), mode.mode));
        }
        pub fn get_blend_mode(self: *Surface) Error!BlendMode {
            var mode: u32 = 0;
            try ok_or_fail_err(C.SDL_GetSurfaceBlendMode(self.to_c(), &mode));
            return BlendMode{ .mode = mode };
        }
        pub fn set_clip_rect(self: *Surface, rect: IRect) Error!void {
            return ok_or_fail_err(C.SDL_SetSurfaceClipRect(self.to_c(), &rect));
        }
        pub fn get_clip_rect(self: *Surface) Error!IRect {
            var rect = IRect{};
            try ok_or_fail_err(C.SDL_GetSurfaceClipRect(self.to_c(), &rect));
            return rect;
        }
        pub fn flip(self: *Surface, flip_mode: FlipMode) Error!void {
            return ok_or_fail_err(C.SDL_FlipSurface(self.to_c(), flip_mode.to_c()));
        }
        pub fn duplicate(self: *Surface) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_DuplicateSurface(self.to_c()));
        }
        pub fn scale_copy(self: *Surface, scale: Scale) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_ScaleSurface(self.to_c(), scale.ratio.x, scale.ratio.y, scale.mode.to_c()));
        }
        pub fn convert_to_format(self: *Surface, format: PixelFormat) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_ConvertSurface(self.to_c(), format.to_c()));
        }
        pub fn convert_to_format_and_colorspace(self: *Surface, format: PixelFormat, optional_palette: ?*ColorPalette, color_space: Colorspace, extra_color_props: PropertiesID) Error!*Surface {
            return ptr_cast_or_fail_err(*Surface, C.SDL_ConvertSurface(self.to_c(), format.to_c(), @ptrCast(@alignCast(optional_palette)), color_space.to_c(), extra_color_props.id));
        }
        pub fn premultiply_alpha(self: *Surface, linear: bool) Error!void {
            return ok_or_fail_err(C.SDL_PremultiplySurfaceAlpha(self.to_c(), linear));
        }
        pub fn clear(self: *Surface, color: FColor_RGBA) Error!void {
            return ok_or_fail_err(C.SDL_ClearSurface(self.to_c(), color.r, color.g, color.b, color.a));
        }
        pub fn fill_rect(self: *Surface, rect: IRect, color: IColor_RGBA) Error!void {
            return ok_or_fail_err(C.SDL_FillSurfaceRect(self.to_c(), @ptrCast(@alignCast(&rect)), color.to_raw_int()));
        }
        pub fn fill_many_rects(self: *Surface, rects: []const IRect, color: IColor_RGBA) Error!void {
            return ok_or_fail_err(C.SDL_FillSurfaceRects(self.to_c(), @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len), color.to_raw_int()));
        }
        pub fn blit_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea) Error!void {
            return ok_or_fail_err(C.SDL_BlitSurface(self.to_c(), area.to_c(), dst.to_c(), dst_area.to_c()));
        }
        pub fn blit_unchecked_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea) Error!void {
            return ok_or_fail_err(C.SDL_BlitSurfaceUnchecked(self.to_c(), area.to_c(), dst.to_c(), dst_area.to_c()));
        }
        pub fn blit_scaled_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea, mode: ScaleMode) Error!void {
            return ok_or_fail_err(C.SDL_BlitSurface(self.to_c(), area.to_c(), dst.to_c(), dst_area.to_c(), mode.to_c()));
        }
        pub fn blit_scaled_unchecked_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea, mode: ScaleMode) Error!void {
            return ok_or_fail_err(C.SDL_BlitSurfaceUnchecked(self.to_c(), area.to_c(), dst.to_c(), dst_area.to_c(), mode.to_c()));
        }
        pub fn copy_stretched_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea, mode: ScaleMode) Error!void {
            return ok_or_fail_err(C.SDL_StretchSurface(self.to_c(), area.to_c(), dst.to_c(), dst_area.to_c(), mode.to_c()));
        }
        pub fn blit_tiled_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea) Error!void {
            return ok_or_fail_err(C.SDL_BlitSurfaceTiled(self.to_c(), area.to_c(), dst.to_c(), dst_area.to_c()));
        }
        pub fn blit_tiled_scaled_to(self: *Surface, area: IArea, dst: *Surface, dst_area: IArea, scale: Scale) Error!void {
            return ok_or_fail_err(C.SDL_BlitSurfaceTiledWithScale(self.to_c(), area.to_c(), scale.ratio, scale.mode.to_c(), dst.to_c(), dst_area.to_c()));
        }
        pub fn blit_nine_patch_to(self: *Surface, nine_patch: INinePatch, dst: *Surface, dst_area: IArea, scale: Scale) Error!void {
            return ok_or_fail_err(C.SDL_BlitSurface9Grid(self.to_c(), nine_patch.rect_to_c(), nine_patch.left, nine_patch.right, nine_patch.top, nine_patch.bottom, scale.ratio, scale.mode.to_c(), dst.to_c(), dst_area.to_c()));
        }
        pub fn closest_valid_color_rgb(self: *Surface, color: IColor_RGB) IColor_U32 {
            return IColor_U32{ .raw = C.SDL_MapSurfaceRGB(self.to_c(), color.r, color.g, color.b) };
        }
        pub fn closest_valid_color_rgba(self: *Surface, color: IColor_RGBA) IColor_U32 {
            return IColor_U32{ .raw = C.SDL_MapSurfaceRGBA(self.to_c(), color.r, color.g, color.b, color.a) };
        }
        pub fn read_pixel(self: *Surface, pos: IVec) Error!IColor_RGBA {
            var color = IColor_RGBA{};
            try ok_or_fail_err(C.SDL_ReadSurfacePixel(self.to_c(), pos.x, pos.y, &color.r, &color.g, &color.b, &color.a));
            return color;
        }
        pub fn read_pixel_float(self: *Surface, pos: IVec) Error!FColor_RGBA {
            var color = FColor_RGBA{};
            try ok_or_fail_err(C.SDL_ReadSurfacePixelFloat(self.to_c(), pos.x, pos.y, &color.r, &color.g, &color.b, &color.a));
            return color;
        }
        pub fn write_pixel(self: *Surface, pos: IVec, color: IColor_RGBA) Error!void {
            return ok_or_fail_err(C.SDL_ReadSurfacePixel(self.to_c(), pos.x, pos.y, color.r, color.g, color.b, color.a));
        }
        pub fn write_pixel_float(self: *Surface, pos: IVec, color: FColor_RGBA) Error!void {
            return ok_or_fail_err(C.SDL_WriteSurfacePixelFloat(self.to_c(), pos.x, pos.y, color.r, color.g, color.b, color.a));
        }
    };

    pub const SurfaceList = extern struct {
        list: []*Surface,

        pub fn free(self: SurfaceList) void {
            sdl_free(self.list.ptr);
        }
    };

    pub const Vertex = extern struct {
        position: FVec = FVec{},
        color: FColor_RGBA = FColor_RGBA{},
        tex_coord: FVec = FVec,
    };

    pub const SurfaceFlags = extern struct {
        flags: FLAG_UINT = 0,

        const FLAG_UINT: type = C.SDL_SurfaceFlags;
    };

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
        texture: ?*Texture,

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
    pub const Texture = opaque {
        pub inline fn width(self: *Texture) c_int {
            return self.to_c().w;
        }
        pub inline fn height(self: *Texture) c_int {
            return self.to_c().h;
        }
        pub inline fn format(self: *Texture) PixelFormat {
            return PixelFormat.from_c(self.to_c().format);
        }
        pub inline fn ref_count(self: *Texture) c_int {
            return self.to_c().refcount;
        }

        inline fn to_c(self: *Texture) *C.SDL_Texture {
            return @ptrCast(@alignCast(self));
        }

        pub fn destroy(self: *Texture) void {
            C.SDL_DestroyTexture(self.to_c());
        }

        pub fn get_properties(self: *Texture) PropertiesID {
            return C.SDL_GetTextureProperties(self.to_c());
        }
        pub fn get_renderer(self: *Texture) Error!*Renderer {
            return ptr_cast_or_null_err(*Renderer, C.SDL_GetTextureProperties(self.to_c()));
        }
        pub fn get_size(self: *Texture) Error!IVec {
            var size = IVec{};
            try ok_or_null_err(C.SDL_GetTextureSize(self.to_c(), &size.x, &size.y));
            return size;
        }
        pub fn set_color_mod(self: *Texture, color: IColor_RGB) Error!void {
            return ok_or_fail_err(C.SDL_SetTextureColorMod(self.to_c(), color.r, color.g, color.b));
        }
        pub fn set_color_mod_float(self: *Texture, color: FColor_RGB) Error!void {
            return ok_or_fail_err(C.SDL_SetTextureColorModFloat(self.to_c(), color.r, color.g, color.b));
        }
        pub fn get_color_mod(self: *Texture) Error!IColor_RGB {
            var color = IColor_RGB{};
            try ok_or_null_err(C.SDL_GetTextureColorMod(self.to_c(), &color.r, &color.g, &color.b));
            return color;
        }
        pub fn get_color_mod_float(self: *Texture) Error!FColor_RGB {
            var color = FColor_RGB{};
            try ok_or_null_err(C.SDL_GetTextureColorModFloat(self.to_c(), &color.r, &color.g, &color.b));
            return color;
        }
        pub fn set_alpha_mod(self: *Texture, alpha: u8) Error!void {
            return ok_or_fail_err(C.SDL_SetTextureAlphaMod(self.to_c(), alpha));
        }
        pub fn set_alpha_mod_float(self: *Texture, alpha: f32) Error!void {
            return ok_or_fail_err(C.SDL_SetTextureAlphaModFloat(self.to_c(), alpha));
        }
        pub fn get_alpha_mod(self: *Texture) Error!u8 {
            var alpha: u8 = 0;
            try ok_or_null_err(C.SDL_GetTextureAlphaMod(self.to_c(), &alpha));
            return alpha;
        }
        pub fn get_alpha_mod_float(self: *Texture) Error!f32 {
            var alpha: f32 = 0.0;
            try ok_or_null_err(C.SDL_GetTextureAlphaModFloat(self.to_c(), &alpha));
            return alpha;
        }
        pub fn set_blend_mode(self: *Texture, blend_mode: BlendMode) Error!void {
            return ok_or_fail_err(C.SDL_SetTextureBlendMode(self.to_c(), blend_mode.mode));
        }
        pub fn get_blend_mode(self: *Texture) Error!BlendMode {
            var mode: u32 = 0;
            try ok_or_null_err(C.SDL_GetTextureBlendMode(self.to_c(), &mode));
            return BlendMode{ .mode = mode };
        }
        pub fn set_scale_mode(self: *Texture, scale_mode: ScaleMode) Error!void {
            return ok_or_fail_err(C.SDL_SetTextureScaleMode(self.to_c(), scale_mode.to_c()));
        }
        pub fn get_scale_mode(self: *Texture) Error!ScaleMode {
            var mode: c_int = 0;
            try ok_or_null_err(C.SDL_GetTextureScaleMode(self.to_c(), &mode));
            return ScaleMode.from_c(mode);
        }
        pub fn update_texture(self: *Texture, raw_pixel_data: []const u8, bytes_per_row: c_int) Error!void {
            return ok_or_fail_err(C.SDL_UpdateTexture(self.to_c(), null, raw_pixel_data.ptr, bytes_per_row));
        }
        pub fn update_texture_rect(self: *Texture, rect: IRect, raw_pixel_data: []const u8, bytes_per_row: c_int) Error!void {
            return ok_or_fail_err(C.SDL_UpdateTexture(self.to_c(), @ptrCast(@alignCast(&rect)), raw_pixel_data.ptr, bytes_per_row));
        }
        pub fn update_YUV_texture(self: *Texture, y_plane_data: []const u8, bytes_per_y_row: c_int, u_plane_data: []const u8, bytes_per_u_row: c_int, v_plane_data: []const u8, bytes_per_v_row: c_int) Error!void {
            return ok_or_fail_err(C.SDL_UpdateYUVTexture(self.to_c(), null, y_plane_data.ptr, bytes_per_y_row, u_plane_data.ptr, bytes_per_u_row, v_plane_data.ptr, bytes_per_v_row));
        }
        pub fn update_YUV_texture_rect(self: *Texture, rect: IRect, y_plane_data: []const u8, bytes_per_y_row: c_int, u_plane_data: []const u8, bytes_per_u_row: c_int, v_plane_data: []const u8, bytes_per_v_row: c_int) Error!void {
            return ok_or_fail_err(C.SDL_UpdateYUVTexture(self.to_c(), @ptrCast(@alignCast(&rect)), y_plane_data.ptr, bytes_per_y_row, u_plane_data.ptr, bytes_per_u_row, v_plane_data.ptr, bytes_per_v_row));
        }
        pub fn update_NV_texture_rect(self: *Texture, rect: IRect, y_plane_data: []const u8, bytes_per_y_row: c_int, uv_plane_data: []const u8, bytes_per_uv_row: c_int) Error!void {
            return ok_or_fail_err(C.SDL_UpdateNVTexture(self.to_c(), @ptrCast(@alignCast(&rect)), y_plane_data.ptr, bytes_per_y_row, uv_plane_data.ptr, bytes_per_uv_row));
        }
        pub fn lock_for_byte_write(self: *Texture) Error!TextureWriteBytes {
            var bytes_ptr: [*]u8 = undefined;
            var bytes_per_row: c_int = 0;
            try ok_or_fail_err(C.SDL_LockTexture(self.to_c(), null, &bytes_ptr, &bytes_per_row));
            const total_len = self.height * bytes_per_row;
            return TextureWriteBytes{
                .bytes = bytes_ptr[0..total_len],
                .bytes_per_row = bytes_per_row,
                .texture = self,
            };
        }
        pub fn lock_rect_for_byte_write(self: *Texture, rect: IRect) Error!TextureWriteBytes {
            var bytes_ptr: [*]u8 = undefined;
            var bytes_per_row: c_int = 0;
            try ok_or_fail_err(C.SDL_LockTexture(self.to_c(), @ptrCast(@alignCast(&rect)), &bytes_ptr, &bytes_per_row));
            const total_len = rect.y * bytes_per_row;
            return TextureWriteBytes{
                .bytes = bytes_ptr[0..total_len],
                .bytes_per_row = bytes_per_row,
                .texture = self,
            };
        }
        pub fn lock_for_surface_write(self: *Texture) Error!TextureWriteSurface {
            var surface: *Surface = undefined;
            try ok_or_fail_err(C.SDL_LockTextureToSurface(self.to_c(), null, @ptrCast(@alignCast(&surface))));
            return TextureWriteSurface{
                .surface = surface,
                .texture = self,
            };
        }
        pub fn lock_rect_for_surface_write(self: *Texture, rect: IRect) Error!TextureWriteSurface {
            var surface: *Surface = undefined;
            try ok_or_fail_err(C.SDL_LockTextureToSurface(self.to_c(), @ptrCast(@alignCast(&rect)), @ptrCast(@alignCast(&surface))));
            return TextureWriteSurface{
                .surface = surface,
                .texture = self,
            };
        }
    };

    pub const BlendFactor = enum(c_uint) {
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

        inline fn to_c(self: BlendFactor) c_uint {
            return @intFromEnum(self);
        }
        inline fn from_c(val: c_uint) BlendFactor {
            return @enumFromInt(val);
        }
    };
};

pub const PixelType = enum(c_uint) {
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

    inline fn to_c(self: PixelType) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) PixelType {
        return @enumFromInt(val);
    }
};

pub const BitmapOrder = enum(c_uint) {
    NONE = C.SDL_BITMAPORDER_NONE,
    _4321 = C.SDL_BITMAPORDER_4321,
    _1234 = C.SDL_BITMAPORDER_1234,

    inline fn to_c(self: BitmapOrder) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) BitmapOrder {
        return @enumFromInt(val);
    }
};

pub const PackedOrder = enum(c_uint) {
    NONE = C.SDL_PACKEDORDER_NONE,
    XRGB = C.SDL_PACKEDORDER_XRGB,
    RGBX = C.SDL_PACKEDORDER_RGBX,
    ARGB = C.SDL_PACKEDORDER_ARGB,
    RGBA = C.SDL_PACKEDORDER_RGBA,
    XBGR = C.SDL_PACKEDORDER_XBGR,
    BGRX = C.SDL_PACKEDORDER_BGRX,
    ABGR = C.SDL_PACKEDORDER_ABGR,
    BGRA = C.SDL_PACKEDORDER_BGRA,

    inline fn to_c(self: PackedOrder) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) PackedOrder {
        return @enumFromInt(val);
    }
};

pub const ArrayOrder = enum(c_uint) {
    NONE = C.SDL_ARRAYORDER_NONE,
    RGB = C.SDL_ARRAYORDER_RGB,
    RGBA = C.SDL_ARRAYORDER_RGBA,
    ARGB = C.SDL_ARRAYORDER_ARGB,
    BGR = C.SDL_ARRAYORDER_BGR,
    BGRA = C.SDL_ARRAYORDER_BGRA,
    ABGR = C.SDL_ARRAYORDER_ABGR,

    inline fn to_c(self: ArrayOrder) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) ArrayOrder {
        return @enumFromInt(val);
    }
};

pub const PackedLayout = enum(c_uint) {
    NONE = C.SDL_PACKEDLAYOUT_NONE,
    _332 = C.SDL_PACKEDLAYOUT_332,
    _4444 = C.SDL_PACKEDLAYOUT_4444,
    _1555 = C.SDL_PACKEDLAYOUT_1555,
    _5551 = C.SDL_PACKEDLAYOUT_5551,
    _565 = C.SDL_PACKEDLAYOUT_565,
    _8888 = C.SDL_PACKEDLAYOUT_8888,
    _2101010 = C.SDL_PACKEDLAYOUT_2101010,
    _1010102 = C.SDL_PACKEDLAYOUT_1010102,

    inline fn to_c(self: PackedLayout) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) PackedLayout {
        return @enumFromInt(val);
    }
};

pub const ColorType = enum(c_uint) {
    UNKNOWN = C.SDL_COLOR_TYPE_UNKNOWN,
    RGB = C.SDL_COLOR_TYPE_RGB,
    YCBCR = C.SDL_COLOR_TYPE_YCBCR,

    inline fn to_c(self: ColorType) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) ColorType {
        return @enumFromInt(val);
    }
};

pub const ColorRange = enum(c_uint) {
    UNKNOWN = C.SDL_COLOR_RANGE_UNKNOWN,
    LIMITED = C.SDL_COLOR_RANGE_LIMITED,
    FULL = C.SDL_COLOR_RANGE_FULL,

    inline fn to_c(self: ColorRange) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) ColorRange {
        return @enumFromInt(val);
    }
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

    inline fn to_c(self: ColorPrimaries) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) ColorPrimaries {
        return @enumFromInt(val);
    }
};

pub const Clipboard = struct {
    pub fn get_text() Error!String {
        return String{ .ptr = try nonempty_str_or_null_err(C.SDL_GetClipboardText()) };
    }
    pub fn set_text(text: [*:0]const u8) Error!void {
        return ok_or_fail_err(C.SDL_SetClipboardText(text));
    }
    pub fn has_text() bool {
        return C.SDL_HasClipboardText();
    }

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

pub const String = extern struct {
    ptr: [*:0]u8,

    pub fn slice(self: String) [:0]u8 {
        return Root.Utils.make_slice_from_sentinel_ptr(u8, 0, self.ptr);
    }

    pub fn free(self: String) void {
        return sdl_free(self.ptr);
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
    pub fn get_bounds(self: DisplayID) Error!IRect {
        var rect = IRect{};
        try ok_or_null_err(C.SDL_GetDisplayBounds(self.id, @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn get_usable_bounds(self: DisplayID) Error!IRect {
        var rect = IRect{};
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
    pub fn get_display_for_point(point: IVec) Error!DisplayID {
        return DisplayID{ .id = try nonzero_or_null_err(C.SDL_GetDisplayForPoint(@ptrCast(@alignCast(&point)))) };
    }
    pub fn get_display_for_rect(rect: IRect) Error!DisplayID {
        return DisplayID{ .id = try nonzero_or_null_err(C.SDL_GetDisplayForRect(@ptrCast(@alignCast(&rect)))) };
    }
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

pub const PixelFormat = enum(c_uint) {
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
    RGBA_32 = C.SDL_PIXELFORMAT_RGBA32,
    ARGB_32 = C.SDL_PIXELFORMAT_ARGB32,
    BGRA_32 = C.SDL_PIXELFORMAT_BGRA32,
    ABGR_32 = C.SDL_PIXELFORMAT_ABGR32,
    RGBX_32 = C.SDL_PIXELFORMAT_RGBX32,
    XRGB_32 = C.SDL_PIXELFORMAT_XRGB32,
    BGRX_32 = C.SDL_PIXELFORMAT_BGRX32,
    XBGR_32 = C.SDL_PIXELFORMAT_XBGR32,

    inline fn to_c(self: PixelFormat) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) PixelFormat {
        return @enumFromInt(val);
    }
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

pub const Window = opaque {
    inline fn to_c(self: *Window) *C.SDL_Window {
        return @ptrCast(@alignCast(self));
    }
    pub fn try_get_display_id(self: *Window) Error!DisplayID {
        return DisplayID{ .id = try nonzero_or_null_err(C.SDL_GetDisplayForWindow(self.to_c())) };
    }
    pub fn get_pixel_density(self: *Window) f32 {
        return C.SDL_GetWindowPixelDensity(self.to_c());
    }
    pub fn get_display_scale(self: *Window) f32 {
        return C.SDL_GetWindowDisplayScale(self.to_c());
    }
    pub fn get_fullscreen_display_mode(self: *Window) FullscreenMode {
        return FullscreenMode{ .mode = C.SDL_GetWindowFullscreenMode(self) };
    }
    pub fn set_fullscreen_display_mode(self: *Window, mode: FullscreenMode) Error!void {
        return ok_or_fail_err(C.SDL_SetWindowFullscreenMode(self.to_c(), mode.mode));
    }
    pub fn get_icc_profile(self: *Window, size: usize) Error!*WindowICCProfile {
        return ptr_cast_or_null_err(*WindowICCProfile, C.SDL_GetWindowICCProfile(self.to_c(), &size));
    }
    pub fn get_pixel_format(self: *Window) PixelFormat {
        return @enumFromInt(C.SDL_GetWindowPixelFormat(self.to_c()));
    }
    pub fn get_all_windows() Error!WindowsList {
        var len: c_int = 0;
        return WindowsList{ .list = (try ptr_cast_or_null_err([*]*Window, C.SDL_GetWindows(&len)))[0..len] };
    }
    pub fn create(options: CreateWindowOptions) Error!*Window {
        return ptr_cast_or_fail_err(*Window, C.SDL_CreateWindow(options.title.ptr, options.size.x, options.size.y, options.flags.flags));
    }
    pub fn create_popup_window(parent: *Window, options: CreatePopupWindowOptions) Error!*Window {
        return ptr_cast_or_fail_err(*Window, C.SDL_CreatePopupWindow(parent.to_c(), options.x_offset, options.y_offset, options.width, options.height, options.flags));
    }
    pub fn create_window_with_properties(properties: PropertiesID) Error!*Window {
        return ptr_cast_or_fail_err(*Window, C.SDL_CreateWindowWithProperties(properties.id));
    }
    pub fn get_id(self: *Window) Error!WindowID {
        return WindowID{ .id = try nonzero_or_null_err(C.SDL_GetWindowID(self.to_c())) };
    }
    pub fn get_parent_window(self: *Window) Error!*Window {
        return ptr_cast_or_null_err(*Window, C.SDL_GetWindowParent(self.to_c()));
    }
    pub fn get_properties(self: *Window) Error!PropertiesID {
        return PropertiesID{ .id = try nonzero_or_null_err(C.SDL_GetWindowProperties(self.to_c())) };
    }
    pub fn get_flags(self: *Window) WindowFlags {
        return WindowFlags{ .flags = C.SDL_GetWindowFlags(self.to_c()) };
    }
    pub fn set_title(self: *Window, title: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowTitle(self.to_c(), title.ptr));
    }
    pub fn get_title(self: *Window) [*:0]const u8 {
        return @ptrCast(@alignCast(C.SDL_GetWindowTitle(self.to_c())));
    }
    pub fn set_window_icon(self: *Window, icon: *RenderAPI.Surface) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowIcon(self.to_c(), @ptrCast(@alignCast(icon))));
    }
    pub fn set_window_position(self: *Window, pos: IVec) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowPosition(self.to_c(), pos.x, pos.y));
    }
    pub fn get_window_position(self: *Window) Error!IVec {
        var point = IVec{};
        try ok_or_null_err(C.SDL_GetWindowPosition(self.to_c(), &point.x, &point.y));
        return point;
    }
    pub fn set_size(self: *Window, size: IVec) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowSize(self.to_c(), size.x, size.y));
    }
    pub fn get_size(self: *Window) Error!IVec {
        var size = IVec.ZERO;
        try ok_or_null_err(C.SDL_GetWindowSize(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn get_safe_area(self: *Window) Error!IRect {
        var rect = IRect{};
        try ok_or_null_err(C.SDL_GetWindowSafeArea(self.to_c(), @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn set_aspect_ratio(self: *Window, aspect_range: AspectRange) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowAspectRatio(self.to_c(), aspect_range.min, aspect_range.max));
    }
    pub fn get_aspect_ratio(self: *Window) Error!AspectRange {
        var ratio = AspectRange{};
        try ok_or_null_err(C.SDL_SetWindowAspectRatio(self.to_c(), &ratio.min, &ratio.max));
        return ratio;
    }
    pub fn get_border_sizes(self: *Window) Error!BorderSizes {
        var sizes = BorderSizes{};
        try ok_or_null_err(C.SDL_GetWindowBordersSize(self.to_c(), &sizes.top, &sizes.left, &sizes.bottom, &sizes.right));
        return sizes;
    }
    pub fn get_size_in_pixels(self: *Window) Error!IVec {
        var size = IVec{};
        try ok_or_null_err(C.SDL_GetWindowSizeInPixels(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn set_minimum_size(self: *Window, size: IVec) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMinimumSize(self.to_c(), size.x, size.y));
    }
    pub fn get_minimum_size(self: *Window) Error!IVec {
        var size = IVec{};
        try ok_or_null_err(C.SDL_GetWindowMinimumSize(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn set_maximum_size(self: *Window, size: IVec) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMaximumSize(self.to_c(), size.x, size.y));
    }
    pub fn get_maximum_size(self: *Window) Error!IVec {
        var size = IVec{};
        try ok_or_null_err(C.SDL_GetWindowMaximumSize(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn set_bordered(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowBordered(self.to_c(), state));
    }
    pub fn set_resizable(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowResizable(self.to_c(), state));
    }
    pub fn set_always_on_top(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowAlwaysOnTop(self.to_c(), state));
    }
    pub fn show(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_ShowWindow(self.to_c()));
    }
    pub fn hide(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_HideWindow(self.to_c()));
    }
    pub fn raise(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_RaiseWindow(self.to_c()));
    }
    pub fn maximize(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_MaximizeWindow(self.to_c()));
    }
    pub fn minimize(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_MinimizeWindow(self.to_c()));
    }
    pub fn restore(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_RestoreWindow(self.to_c()));
    }
    pub fn set_fullscreen(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowFullscreen(self.to_c(), state));
    }
    pub fn sync(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SyncWindow(self.to_c()));
    }
    pub fn has_surface(self: *Window) bool {
        return C.SDL_WindowHasSurface(self.to_c());
    }
    pub fn get_surface(self: *Window) Error!*RenderAPI.Surface {
        return ptr_cast_or_null_err(*RenderAPI.Surface, C.SDL_GetWindowSurface(self.to_c()));
    }
    pub fn set_surface_vsync(self: *Window, vsync: VSync) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowSurfaceVSync(self.to_c(), vsync.to_c()));
    }
    pub fn get_surface_vsync(self: *Window) Error!VSync {
        var int: c_int = 0;
        try ok_or_fail_err(C.SDL_GetWindowSurfaceVSync(self.to_c(), &int));
        return VSync.from_c(int);
    }
    pub fn update_surface(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_UpdateWindowSurface(self.to_c()));
    }
    pub fn update_surface_rects(self: *Window, rects: []const IRect) Error!void {
        try ok_or_fail_err(C.SDL_UpdateWindowSurfaceRects(self.to_c(), @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len)));
    }
    pub fn destroy_surface(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_DestroyWindowSurface(self.to_c()));
    }
    pub fn set_keyboard_grab(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowKeyboardGrab(self.to_c(), state));
    }
    pub fn set_mouse_grab(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMouseGrab(self.to_c(), state));
    }
    pub fn is_keyboard_grabbed(self: *Window) bool {
        return C.SDL_GetWindowKeyboardGrab(self.to_c());
    }
    pub fn is_mouse_grabbed(self: *Window) bool {
        return C.SDL_GetWindowMouseGrab(self.to_c());
    }
    pub fn get_window_that_has_grab() Error!*Window {
        return ptr_cast_or_null_err(*Window, C.SDL_GetGrabbedWindow());
    }
    pub fn set_mouse_confine_rect(self: *Window, rect: IRect) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMouseRect(self.to_c(), @ptrCast(@alignCast(&rect))));
    }
    pub fn clear_mouse_confine_rect(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowMouseRect(self.to_c(), null));
    }
    pub fn get_mouse_confine_rect(self: *Window) Error!IRect {
        const rect_ptr = try ptr_cast_or_null_err(*IRect, C.SDL_GetWindowMouseRect(self.to_c()));
        return rect_ptr.*;
    }
    pub fn set_opacity(self: *Window, opacity: f32) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowOpacity(self.to_c(), opacity));
    }
    pub fn get_opacity(self: *Window) f32 {
        return C.SDL_GetWindowOpacity(self.to_c());
    }
    pub fn set_parent(self: *Window, parent: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowParent(self.to_c(), parent.to_c()));
    }
    pub fn clear_parent(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowParent(self.to_c(), null));
    }
    pub fn set_modal(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowModal(self.to_c(), state));
    }
    pub fn set_focusable(self: *Window, state: bool) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowFocusable(self.to_c(), state));
    }
    pub fn show_system_menu(self: *Window, pos: IVec) Error!void {
        try ok_or_fail_err(C.SDL_ShowWindowSystemMenu(self.to_c(), pos.x, pos.y));
    }
    pub fn set_custom_hittest(self: *Window, hittest_fn: *const WindowHittestFn, data: ?*anyopaque) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowHitTest(self.to_c(), @ptrCast(@alignCast(hittest_fn)), data));
    }
    pub fn clear_custom_hittest(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowHitTest(self.to_c(), null, null));
    }
    pub fn set_window_shape(self: *Window, shape: *RenderAPI.Surface) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowShape(self.to_c(), @ptrCast(@alignCast(shape))));
    }
    pub fn clear_window_shape(self: *Window) Error!void {
        try ok_or_fail_err(C.SDL_SetWindowShape(self.to_c(), null));
    }
    pub fn flash_window(self: *Window, mode: FlashMode) Error!void {
        try ok_or_fail_err(C.SDL_FlashWindow(self.to_c(), mode.to_c()));
    }
    pub fn destroy(self: *Window) void {
        C.SDL_DestroyWindow(self.to_c());
    }
    pub fn create_renderer(self: *Window) Error!*RenderAPI.Renderer {
        return ptr_cast_or_fail_err(*RenderAPI.Renderer, C.SDL_CreateRenderer(self.to_c(), null));
    }
    pub fn create_renderer_with_name(self: *Window, name: [*:0]const u8) Error!*RenderAPI.Renderer {
        return ptr_cast_or_fail_err(*RenderAPI.Renderer, C.SDL_CreateRenderer(self.to_c(), name));
    }
    pub fn get_renderer(self: *Window) Error!*RenderAPI.Renderer {
        return ptr_cast_or_null_err(*RenderAPI.Renderer, C.SDL_GetRenderer(self.to_c()));
    }
    pub fn set_mouse_mode_relative(self: *Window, state: bool) Error!void {
        return ok_or_fail_err(C.SDL_SetWindowRelativeMouseMode(self.to_c(), state));
    }
    pub fn is_mouse_mode_relative(self: *Window) bool {
        return C.SDL_GetWindowRelativeMouseMode(self.to_c());
    }
    pub fn warp_mouse_position(self: *Window, pos: FVec) void {
        C.SDL_WarpMouseInWindow(self.to_c(), pos.x, pos.y);
    }
};

pub const FlashMode = enum(c_uint) {
    CANCEL = C.SDL_FLASH_CANCEL,
    BRIEFLY = C.SDL_FLASH_BRIEFLY,
    UNTIL_FOCUSED = C.SDL_FLASH_UNTIL_FOCUSED,

    inline fn to_c(self: FlashMode) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) FlashMode {
        return @enumFromInt(val);
    }
};

pub const WindowHitTestResult = enum(c_uint) {
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

    inline fn to_c(self: WindowHitTestResult) c_uint {
        return @intFromEnum(self);
    }

    inline fn from_c(val: c_uint) WindowHitTestResult {
        return @enumFromInt(val);
    }
};

pub const WindowHittestFn = fn (window: *Window, test_point: *IVec, custom_data: ?*anyopaque) callconv(.c) WindowHitTestResult;

pub const VSync = enum(c_int) {
    adaptive = C.SDL_WINDOW_SURFACE_VSYNC_ADAPTIVE,
    disabled = C.SDL_WINDOW_SURFACE_VSYNC_DISABLED,
    _,

    pub fn every_n_frames(n: c_int) VSync {
        return @enumFromInt(n);
    }

    inline fn to_c(self: VSync) c_int {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_int) VSync {
        return @enumFromInt(val);
    }
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
    size: IVec = IVec.new(800, 600),
};

pub const CreatePopupWindowOptions = extern struct {
    flags: WindowFlags = WindowFlags{},
    offset: IVec = IVec.ZERO,
    size: IVec = IVec.new(400, 300),
};

pub const WindowsList = extern struct {
    list: []Window,

    pub fn free(self: WindowsList) void {
        sdl_free(self.list.ptr);
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
        sdl_free(self.modes.ptr);
    }
};

pub const DisplayList = extern struct {
    ids: []DisplayID,

    pub fn free(self: DisplayList) void {
        sdl_free(self.ids.ptr);
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
}, null);

/// Helper struct for SDL functions that expect a `?*IRect` where:
/// - `null` == use entire area
/// - `*IRect` == use this rect area
pub const IArea = extern struct {
    rect_ptr: ?*IRect = null,

    pub inline fn rect(r: *IRect) IArea {
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
    rect_ptr: ?*const FRect = null,

    pub inline fn rect(r: *const FRect) FArea {
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
    inline fn to_c(self: *ColorPalette) *C.SDL_Palette {
        return @ptrCast(@alignCast(self));
    }

    pub fn colors(self: *ColorPalette) []const IColor_RGBA {
        const c = self.to_c();
        const ptr: ?[*]C.SDL_Color = c.colors;
        if (ptr) |good_ptr| {
            return @as([*]const IColor_RGBA, @ptrCast(@alignCast(good_ptr)))[0..c.ncolors];
        }
        return &.{};
    }
    pub fn version(self: *ColorPalette) u32 {
        return self.to_c().version;
    }
    pub fn refcount(self: *ColorPalette) c_int {
        return self.to_c().refcount;
    }
};

pub const Colorspace = enum(c_uint) {
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

    inline fn to_c(self: Colorspace) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) Colorspace {
        return @enumFromInt(val);
    }
};

pub const AtomicInt = extern struct {
    val: c_int = 0,

    fn to_c(self: *AtomicInt) *C.SDL_AtomicInt {
        return @ptrCast(@alignCast(self));
    }

    pub fn compare_and_swap(self: *AtomicInt, old_val_matches: c_int, new_val: c_int) bool {
        return C.SDL_CompareAndSwapAtomicInt(self.to_c(), old_val_matches, new_val);
    }
    pub fn set(self: *AtomicInt, val: c_int) c_int {
        return C.SDL_SetAtomicInt(self.to_c(), val);
    }
    pub fn add(self: *AtomicInt, val: c_int) c_int {
        return C.SDL_AddAtomicInt(self.to_c(), val);
    }
    pub fn get(self: *AtomicInt) c_int {
        return C.SDL_GetAtomicInt(self.to_c());
    }
};

pub const MetalLayer = opaque {};
pub const MetalCommandEncoder = opaque {};

pub const IndexType = enum(c_int) {
    U8 = 1,
    U16 = 2,
    U32 = 4,

    inline fn to_c(self: IndexType) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) IndexType {
        return @enumFromInt(val);
    }
};

pub const AppProcess = enum(c_uint) {
    CONTINUE = C.SDL_APP_CONTINUE,
    CLOSE_NORMAL = C.SDL_APP_SUCCESS,
    CLOSE_ERROR = C.SDL_APP_FAILURE,
    _,

    inline fn to_c(self: AppProcess) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) AppProcess {
        return @enumFromInt(val);
    }
};

pub const LogicalPresentationMode = enum(c_uint) {
    DISABLED = C.SDL_LOGICAL_PRESENTATION_DISABLED,
    STRETCH = C.SDL_LOGICAL_PRESENTATION_STRETCH,
    LETTERBOX = C.SDL_LOGICAL_PRESENTATION_LETTERBOX,
    OVERSCAN = C.SDL_LOGICAL_PRESENTATION_OVERSCAN,
    INTEGER_SCALE = C.SDL_LOGICAL_PRESENTATION_INTEGER_SCALE,

    inline fn to_c(self: LogicalPresentationMode) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) LogicalPresentationMode {
        return @enumFromInt(val);
    }
};

pub const LogicalPresentation = extern struct {
    size: IVec = IVec{},
    mode: LogicalPresentationMode = .DISABLED,

    pub fn new(mode: LogicalPresentationMode, size: IVec) LogicalPresentation {
        return LogicalPresentation{
            .mode = mode,
            .size = size,
        };
    }
    pub fn new_xy(mode: LogicalPresentationMode, x: c_int, y: c_int) LogicalPresentation {
        return LogicalPresentation{
            .mode = mode,
            .size = IVec.new(x, y),
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

pub const AudioSpec = extern struct {
    format: AudioFormat = .UNKNOWN,
    channels: c_int = 0,
    freq: c_int = 0,

    fn to_c(self: *AudioSpec) *C.SDL_AudioSpec {
        return @ptrCast(@alignCast(self));
    }

    pub fn frame_size(self: *AudioSpec) c_int {
        return @as(c_int, @intCast(self.format.byte_size())) * self.channels;
    }
};

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
    pub fn open_new_audio_stream(self: AudioDeviceID, spec: AudioSpec, callback: ?*AudioStreamCallback, user_data: ?*anyopaque) Error!*AudioStream {
        return ptr_cast_or_fail_err(*AudioStream, C.SDL_OpenAudioDeviceStream(self.id, spec.to_c(), @ptrCast(@alignCast(callback)), user_data));
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
        sdl_free(self.map.ptr);
    }
};

pub const AudioDeviceIDList = extern struct {
    list: []AudioDeviceID,

    pub fn free(self: AudioDeviceIDList) void {
        sdl_free(self.list.ptr);
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
        return positive_or_fail_err(C.SDL_PutAudioStreamData(self.to_c(), dst_buffer.ptr, @intCast(dst_buffer.len)));
    }
    pub fn get_bytes_available_to_take_out(self: *AudioStream) Error!c_int {
        return positive_or_fail_err(C.SDL_GetAudioStreamAvailable(self.to_c()));
    }
    pub fn get_bytes_queued_for_take_out(self: *AudioStream) Error!c_int {
        return positive_or_fail_err(C.SDL_GetAudioStreamQueued(self.to_c()));
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
    pub fn set_take_out_callback(self: *AudioStream, callback: *AudioStreamCallback, user_data: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamGetCallback(self.to_c(), @ptrCast(@alignCast(callback)), user_data));
    }
    pub fn clear_take_out_callback(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamGetCallback(self.to_c(), null, null));
    }
    pub fn set_put_in_callback(self: *AudioStream, callback: *AudioStreamCallback, user_data: ?*anyopaque) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamPutCallback(self.to_c(), @ptrCast(@alignCast(callback)), user_data));
    }
    pub fn clear_put_in_callback(self: *AudioStream) Error!void {
        return ok_or_fail_err(C.SDL_SetAudioStreamPutCallback(self.to_c(), null, null));
    }
    pub fn destroy(self: *AudioStream) void {
        C.SDL_DestroyAudioStream(self.to_c());
    }
};

pub const AudioStreamCallback = fn (user_data: ?*anyopaque, stream: *AudioStream, additional_needed: c_int, total_available: c_int) callconv(.c) void;

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

pub const GamepadType = enum(c_uint) {
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

    pub const COUNT: c_uint = C.SDL_GAMEPAD_TYPE_COUNT;

    inline fn to_c(self: GamepadType) c_uint {
        return @intFromEnum(self);
    }
    inline fn from_c(val: c_uint) GamepadType {
        return @enumFromInt(val);
    }

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

    inline fn to_c(self: GamepadButton) c_uint {
        return @intCast(@intFromEnum(self));
    }
    inline fn from_c(val: c_uint) GamepadButton {
        return @enumFromInt(@as(u8, @intCast(val)));
    }

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

    usingnamespace c_enum_conversions(GamepadFaceButtonLabel, c_uint);
};

pub const GamepadAxis = enum(u8) {
    LEFTX = C.SDL_GAMEPAD_AXIS_LEFTX,
    LEFTY = C.SDL_GAMEPAD_AXIS_LEFTY,
    RIGHTX = C.SDL_GAMEPAD_AXIS_RIGHTX,
    RIGHTY = C.SDL_GAMEPAD_AXIS_RIGHTY,
    LEFT_TRIGGER = C.SDL_GAMEPAD_AXIS_LEFT_TRIGGER,
    RIGHT_TRIGGER = C.SDL_GAMEPAD_AXIS_RIGHT_TRIGGER,

    pub const COUNT: u8 = C.SDL_GAMEPAD_AXIS_COUNT;

    usingnamespace c_enum_conversions(GamepadAxis, u8);

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

    usingnamespace c_enum_conversions(GamepadBindingType, c_uint);
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
    inline fn to_c(self: *Storage) *C.SDL_Storage {
        return @ptrCast(@alignCast(self));
    }
    pub fn open_app_readonly_storage_folder(override: [:0]const u8, properties: PropertiesID) Error!*Storage {
        return ptr_cast_or_fail_err(*Storage, C.SDL_OpenTitleStorage(override.ptr, properties));
    }
    pub fn open_user_storage_folder(org_name: [:0]const u8, app_name: [:0]const u8, properties: PropertiesID) Error!*Storage {
        return ptr_cast_or_fail_err(*Storage, C.SDL_OpenUserStorage(org_name.ptr, app_name.ptr, properties.id));
    }
    pub fn open_filesystem(path: [:0]const u8) Error!*Storage {
        return ptr_cast_or_fail_err(*Storage, C.SDL_OpenFileStorage(path.ptr));
    }
    pub fn open_storage_with_custom_interface(iface: StorageInterface, user_data: ?*anyopaque) Error!*Storage {
        return ptr_cast_or_fail_err(*Storage, C.SDL_OpenStorage(@ptrCast(@alignCast(&iface)), user_data));
    }
    pub fn close(self: *Storage) Error!void {
        return ok_or_fail_err(C.SDL_CloseStorage(self.to_c()));
    }
    pub fn is_ready(self: *Storage) bool {
        return C.SDL_StorageReady(self.to_c());
    }
    pub fn get_file_size(self: *Storage, sub_path: [:0]const u8) Error!u64 {
        var size: u64 = 0;
        try ok_or_null_err(C.SDL_GetStorageFileSize(self.to_c(), sub_path.ptr, &size));
        return size;
    }
    pub fn read_file_into_buffer(self: *Storage, sub_path: [:0]const u8, buffer: []u8) Error!void {
        try ok_or_fail_err(C.SDL_ReadStorageFile(self.to_c(), sub_path.ptr, buffer.ptr, @intCast(buffer.len)));
    }
    pub fn write_file_from_buffer(self: *Storage, sub_path: [:0]const u8, buffer: []const u8) Error!void {
        try ok_or_fail_err(C.SDL_WriteStorageFile(self.to_c(), sub_path.ptr, buffer.ptr, @intCast(buffer.len)));
    }
    pub fn create_directory(self: *Storage, sub_path: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_CreateStorageDirectory(self.to_c(), sub_path.ptr));
    }
    pub fn do_callback_for_each_directory_entry(self: *Storage, sub_path: [:0]const u8, callback: *const FolderEntryCallback, callback_data: ?*anyopaque) Error!void {
        try ok_or_fail_err(C.SDL_EnumerateStorageDirectory(self.to_c(), sub_path.ptr, @ptrCast(@alignCast(callback)), callback_data));
    }
    pub fn delete_file_or_empty_directory(self: *Storage, sub_path: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_RemoveStoragePath(self.to_c(), sub_path.ptr));
    }
    pub fn rename_file_or_directory(self: Storage, old_sub_path: [:0]const u8, new_sub_path: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_RenameStoragePath(self.to_c(), old_sub_path.ptr, new_sub_path.ptr));
    }
    pub fn copy_file(self: Storage, old_sub_path: [:0]const u8, new_sub_path: [:0]const u8) Error!void {
        try ok_or_fail_err(C.SDL_CopyStorageFile(self.to_c(), old_sub_path.ptr, new_sub_path.ptr));
    }
    pub fn get_path_info(self: Storage, sub_path: [:0]const u8) Error!PathInfo {
        var info = PathInfo{};
        try ok_or_null_err(C.SDL_GetStoragePathInfo(self.to_c(), sub_path.ptr, @ptrCast(@alignCast(&info))));
        return info;
    }
    pub fn get_remaining_storage_space(self: *Storage) u64 {
        return @intCast(C.SDL_GetStorageSpaceRemaining(self));
    }
    pub fn get_directory_glob(self: Storage, sub_path: [:0]const u8, pattern: [:0]const u8, case_insensitive: bool) Error!DirectoryGlob {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_null_err([*]const [*:0]const u8, C.SDL_GlobStorageDirectory(self.to_c(), sub_path.ptr, pattern.ptr, @intCast(@intFromBool(case_insensitive)), &len));
        return DirectoryGlob{
            .strings = ptr[0..len],
        };
    }
};

pub const FolderEntryCallback = fn (callback_data: ?*anyopaque, folder_name: [*:0]const u8, entry_name: [*:0]const u8) callconv(.c) EnumerationResult;

pub const EnumerationResult = enum(c_uint) {
    CONTINUE = C.SDL_ENUM_CONTINUE,
    SUCCESS = C.SDL_ENUM_SUCCESS,
    FAILURE = C.SDL_ENUM_FAILURE,

    usingnamespace c_enum_conversions(EnumerationResult, c_uint);
};

pub const PathInfo = extern struct {
    path_type: PathType = .NONE,
    size: u64 = 0,
    create_time: Time = Time{},
    modify_time: Time = Time{},
    access_time: Time = Time{},
};

pub const PathType = enum(c_uint) {
    NONE = C.SDL_PATHTYPE_NONE,
    FILE = C.SDL_PATHTYPE_FILE,
    DIRECTORY = C.SDL_PATHTYPE_DIRECTORY,
    OTHER = C.SDL_PATHTYPE_OTHER,

    usingnamespace c_enum_conversions(PathType, c_uint);
};

pub const Time = extern struct {
    ns: i64 = 0,
};

pub const DirectoryGlob = extern struct {
    strings: []const [*:0]const u8,

    pub fn get_string(self: DirectoryGlob, index: usize) []const u8 {
        assert(index < self.strings.len);
        return Root.Utils.make_const_slice_from_sentinel_ptr(u8, 0, self.strings[index]);
    }

    pub fn free(self: DirectoryGlob) void {
        sdl_free(self.strings.ptr);
        self.strings = &.{};
    }
};

pub const KeyboardID = extern struct {
    id: u32 = 0,
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

    usingnamespace c_non_opaque_conversions(Event, C.SDL_Event);

    pub fn convert_coords_to_render_coords(self: *Event, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c()));
    }
};

pub const CommonEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,

    usingnamespace c_non_opaque_conversions(CommonEvent, C.SDL_CommonEvent);
};

pub const DisplayEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    display_id: DisplayID = .{},
    data_1: i32 = 0,
    data_2: i32 = 0,

    usingnamespace c_non_opaque_conversions(DisplayEvent, C.SDL_DisplayEvent);
};

pub const WindowEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    data_1: i32 = 0,
    data_2: i32 = 0,

    usingnamespace c_non_opaque_conversions(WindowEvent, C.SDL_WindowEvent);
};

pub const KeyboardDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    keyboard_id: KeyboardID = .{},

    usingnamespace c_non_opaque_conversions(KeyboardDeviceEvent, C.SDL_KeyboardDeviceEvent);
};

pub const KeyboardEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    keyboard_id: KeyboardID = .{},
    scancode: Scancode = .UNKNOWN,
    key: Keycode = .{},
    mod: Keymod = .{},
    raw: u16 = 0,
    down: bool = false,
    repeat: bool = false,

    usingnamespace c_non_opaque_conversions(KeyboardEvent, C.SDL_KeyboardEvent);
};

pub const TextEditEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    text: [*:0]const u8 = "",
    start: i32 = 0,
    length: i32 = 0,

    usingnamespace c_non_opaque_conversions(TextEditEvent, C.SDL_TextEditingEvent);
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

    usingnamespace c_non_opaque_conversions(TextEditCandidateEvent, C.SDL_TextEditingCandidatesEvent);
};

pub const TextInputEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    text: ?[*:0]const u8 = null,

    usingnamespace c_non_opaque_conversions(TextInputEvent, C.SDL_TextInputEvent);
};

pub const MouseDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    mouse_id: MouseID = .{},

    usingnamespace c_non_opaque_conversions(MouseDeviceEvent, C.SDL_MouseDeviceEvent);
};

pub const MouseMotionEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    mouse_id: MouseID = .{},
    state: MouseButtonFlags = .{},
    pos: FVec = FVec{},
    delta: FVec = FVec{},

    usingnamespace c_non_opaque_conversions(MouseMotionEvent, C.SDL_MouseMotionEvent);

    pub fn convert_coords_to_render_coords(self: *MouseMotionEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
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
    pos: FVec = FVec{},

    usingnamespace c_non_opaque_conversions(MouseButtonEvent, C.SDL_MouseButtonEvent);

    pub fn convert_coords_to_render_coords(self: *MouseButtonEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const MouseButton = enum(u8) {
    LEFT = C.SDL_BUTTON_LEFT,
    MIDDLE = C.SDL_BUTTON_MIDDLE,
    RIGHT = C.SDL_BUTTON_RIGHT,
    MOUSE_4 = C.SDL_BUTTON_X1,
    MOUSE_5 = C.SDL_BUTTON_X2,
    _,

    usingnamespace c_enum_conversions(MouseButton, u8);

    pub inline fn to_mask(self: MouseButton) Mask {
        return @enumFromInt(@as(u32, 1) << @intCast(@intFromEnum(self) - @as(u8, 1)));
    }

    pub const Mask = enum(u32) {
        LEFT = to_mask(MouseButton.LEFT),
        MIDDLE = to_mask(MouseButton.MIDDLE),
        RIGHT = to_mask(MouseButton.RIGHT),
        MOUSE_4 = to_mask(MouseButton.MOUSE_4),
        MOUSE_5 = to_mask(MouseButton.MOUSE_5),
        _,

        usingnamespace c_enum_conversions(Mask, u32);
    };
};

pub const MouseWheelEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    mouse_id: MouseID = .{},
    delta: FVec = FVec{},
    direction: MouseWheelDirection = .NORMAL,
    pos: FVec = FVec{},

    usingnamespace c_non_opaque_conversions(MouseWheelEvent, C.SDL_MouseWheelEvent);

    pub fn convert_coords_to_render_coords(self: *MouseWheelEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const JoyAxisEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},
    axis: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,
    value: i16 = 0,
    _padding_4: u16 = 0,

    usingnamespace c_non_opaque_conversions(JoyAxisEvent, C.SDL_JoyAxisEvent);
};

pub const JoyBallEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},
    ball: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,
    delta: IVec_16 = IVec_16{},

    usingnamespace c_non_opaque_conversions(JoyBallEvent, C.SDL_JoyBallEvent);

    pub fn convert_coords_to_render_coords(self: *JoyBallEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const JoyHatEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},
    hat: u8 = 0,
    value: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,

    usingnamespace c_non_opaque_conversions(JoyHatEvent, C.SDL_JoyHatEvent);
};

pub const JoyButtonEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},
    button: u8 = 0,
    down: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,

    usingnamespace c_non_opaque_conversions(JoyButtonEvent, C.SDL_JoyButtonEvent);
};

pub const JoyDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},

    usingnamespace c_non_opaque_conversions(JoyDeviceEvent, C.SDL_JoyDeviceEvent);
};

pub const JoyBatteryEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},
    state: PowerState = .UNKNOWN,
    percent: c_int = 0,

    usingnamespace c_non_opaque_conversions(JoyBatteryEvent, C.SDL_JoyBatteryEvent);
};

pub const GamepadAxisEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},
    axis: GamepadAxis = .LEFTX,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,
    value: i16 = 0,
    _padding_4: u16 = 0,

    usingnamespace c_non_opaque_conversions(GamepadAxisEvent, C.SDL_GamepadAxisEvent);
};

pub const GamepadButtonEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},
    button: GamepadButton = .START,
    down: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,

    usingnamespace c_non_opaque_conversions(GamepadButtonEvent, C.SDL_GamepadButtonEvent);
};

pub const GamepadDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},

    usingnamespace c_non_opaque_conversions(GamepadDeviceEvent, C.SDL_GamepadDeviceEvent);
};

pub const GamepadTouchpadEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},
    touchpad: i32 = 0,
    finger: i32 = 0,
    pos: FVec = FVec{},
    pressure: f32 = 0,

    usingnamespace c_non_opaque_conversions(GamepadTouchpadEvent, C.SDL_GamepadTouchpadEvent);

    pub fn convert_coords_to_render_coords(self: *GamepadTouchpadEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const GamepadSensorEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    controller_id: GameControllerID = .{},
    sensor: i32 = 0,
    data: [3]f32 = @splat(0.0),
    sensor_timestamp: u64 = 0,

    usingnamespace c_non_opaque_conversions(GamepadSensorEvent, C.SDL_GamepadSensorEvent);
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

    usingnamespace c_non_opaque_conversions(AudioDeviceEvent, C.SDL_AudioDeviceEvent);
};

pub const CameraDeviceEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    device_id: CameraID = .{},

    usingnamespace c_non_opaque_conversions(CameraDeviceEvent, C.SDL_CameraDeviceEvent);
};

pub const RenderEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},

    usingnamespace c_non_opaque_conversions(RenderEvent, C.SDL_RenderEvent);
};

pub const TouchFingerEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    touch_id: TouchID = .{},
    finger_id: FingerID = .{},
    pos: FVec = FVec{},
    delta: FVec = FVec{},
    pressure: f32 = 0,
    window_id: WindowID = .{},

    usingnamespace c_non_opaque_conversions(TouchFingerEvent, C.SDL_TouchFingerEvent);

    pub fn convert_coords_to_render_coords(self: *TouchFingerEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const PenProximityEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},

    usingnamespace c_non_opaque_conversions(PenProximityEvent, C.SDL_PenProximityEvent);
};

pub const PenMotionEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: FVec = FVec{},

    usingnamespace c_non_opaque_conversions(PenMotionEvent, C.SDL_PenMotionEvent);

    pub fn convert_coords_to_render_coords(self: *PenMotionEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const PenTouchEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: FVec = FVec{},
    eraser: bool = false,
    down: bool = false,

    usingnamespace c_non_opaque_conversions(PenTouchEvent, C.SDL_PenTouchEvent);

    pub fn convert_coords_to_render_coords(self: *PenTouchEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const PenButtonEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: FVec = FVec{},
    button: u8 = 0,
    down: bool = false,

    usingnamespace c_non_opaque_conversions(PenButtonEvent, C.SDL_PenButtonEvent);

    pub fn convert_coords_to_render_coords(self: *PenButtonEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const PenAxisEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: FVec = FVec{},
    axis: PenAxis = .PRESSURE,
    value: f32 = 0.0,

    usingnamespace c_non_opaque_conversions(PenAxisEvent, C.SDL_PenAxisEvent);

    pub fn convert_coords_to_render_coords(self: *PenAxisEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const DropEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pos: FVec = FVec{},
    source: ?[*]const u8 = null,
    data: ?[*]const u8 = null,

    usingnamespace c_non_opaque_conversions(DropEvent, C.SDL_DropEvent);

    pub fn convert_coords_to_render_coords(self: *DropEvent, renderer: *RenderAPI.Renderer) Error!void {
        return ok_or_fail_err(C.SDL_ConvertEventToRenderCoordinates(renderer.to_c(), self.to_c_event()));
    }
};

pub const ClipboardEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    owner: bool = false,
    num_mime_types: i32 = 0,
    mime_types: ?[*]const [*:0]const u8 = null,

    usingnamespace c_non_opaque_conversions(ClipboardEvent, C.SDL_ClipboardEvent);
};

pub const SensorEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    sensor_id: bool = false,
    data: [6]f32 = @splat(0),
    sensor_timestamp: u64 = 0,

    usingnamespace c_non_opaque_conversions(SensorEvent, C.SDL_SensorEvent);
};

pub const QuitEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,

    usingnamespace c_non_opaque_conversions(QuitEvent, C.SDL_QuitEvent);
};

pub const UserEvent = extern struct {
    type: EventType = .NONE,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    code: i32 = 0,
    user_data_1: ?*anyopaque = null,
    user_data_2: ?*anyopaque = null,

    usingnamespace c_non_opaque_conversions(UserEvent, C.SDL_UserEvent);
};

pub const MouseID = extern struct {
    id: u32 = 0,
};

pub const PenID = extern struct {
    id: u32 = 0,
};

pub const SensorID = extern struct {
    id: u32 = 0,
};

pub const GameControllerID = extern struct {
    id: u32 = 0,

    fn new_err(id: u32) Error!GameControllerID {
        return GameControllerID{ .id = try nonzero_or_null_err(id) };
    }

    pub fn game_controller_id(id: u32) GameControllerID {
        return GameControllerID{ .id = id };
    }
    pub fn null_id() GameControllerID {
        return NULL_ID;
    }
    pub const NULL_ID = GameControllerID{ .id = 0 };

    pub fn get_all_gamepads() Error!GamepadsList {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_fail_err([*]GameControllerID, C.SDL_GetGamepads(&len));
        return GamepadsList{ .list = ptr[0..@intCast(len)] };
    }
    pub fn is_gamepad(self: GameControllerID) bool {
        return C.SDL_IsGamepad(self.id);
    }
    pub fn get_name(self: GameControllerID) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGamepadNameForID(self.id));
    }
    pub fn get_path(self: GameControllerID) Error![*:0]const u8 {
        return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGamepadPathForID(self.id));
    }
    pub fn get_player_index(self: GameControllerID) Error!PlayerIndex {
        return PlayerIndex{ .index = try positive_or_null_err(C.SDL_GetGamepadPlayerIndexForID(self.id)) };
    }
    pub fn get_guid(self: GameControllerID) Error!GUID {
        return valid_guid_or_null_err(C.SDL_GetGamepadGUIDForID(self.id));
    }
    pub fn get_vendor_code(self: GameControllerID) Error!HW_VendorCode {
        return HW_VendorCode{ .code = try nonzero_or_null_err(C.SDL_GetGamepadVendorForID(self.id)) };
    }
    pub fn get_product_code(self: GameControllerID) Error!HW_ProductCode {
        return HW_ProductCode{ .code = try nonzero_or_null_err(C.SDL_GetGamepadProductForID(self.id)) };
    }
    pub fn get_product_version(self: GameControllerID) Error!HW_ProductVersion {
        return HW_ProductVersion{ .code = try nonzero_or_null_err(C.SDL_GetGamepadProductVersionForID(self.id)) };
    }
    pub fn get_gamepad_type(self: GameControllerID) Error!GamepadType {
        return GamepadType.from_c(C.SDL_GetGamepadTypeForID(self.id));
    }
    pub fn get_real_gamepad_type(self: GameControllerID) Error!GamepadType {
        return GamepadType.from_c(C.SDL_GetRealGamepadTypeForID(self.id));
    }
    pub fn get_gamepad_mapping_string(self: GameControllerID) Error!String {
        return String{ .ptr = try ptr_cast_or_null_err([*:0]u8, C.SDL_GetGamepadMappingForID(self.id)) };
    }
    pub fn open_gamepad(self: GameControllerID) Error!*Gamepad {
        return ptr_cast_or_null_err(*Gamepad, C.SDL_OpenGamepad(self.id));
    }
    pub fn get_open_gamepad(self: GameControllerID) Error!*Gamepad {
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
};

pub const Gamepad = opaque {
    usingnamespace c_opaque_conversions(Gamepad, C.SDL_Gamepad);

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
    pub fn get_id(self: *Gamepad) Error!GameControllerID {
        return GameControllerID.new_err(C.SDL_GetGamepadProperties(self.to_c_ptr()));
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
    pub fn get_vendor_code(self: *Gamepad) HW_VendorCode {
        return HW_VendorCode.new(C.SDL_GetGamepadVendor(self.to_c_ptr()));
    }
    pub fn get_product_code(self: *Gamepad) HW_ProductCode {
        return HW_ProductCode.new(C.SDL_GetGamepadProduct(self.to_c_ptr()));
    }
    pub fn get_product_version(self: *Gamepad) HW_ProductVersion {
        return HW_ProductVersion.new(C.SDL_GetGamepadProductVersion(self.to_c_ptr()));
    }
    pub fn get_firmware_version(self: *Gamepad) HW_FirmwareVersion {
        return HW_FirmwareVersion.new(C.SDL_GetGamepadFirmwareVersion(self.to_c_ptr()));
    }
    pub fn get_serial_number(self: *Gamepad) Error!HW_SerialNumber {
        return HW_SerialNumber.new_err(C.SDL_GetGamepadSerial(self.to_c_ptr()));
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
};

pub const Joystick = opaque {
    usingnamespace c_opaque_conversions(Joystick, C.SDL_Joystick);
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
};

pub const FingerState = extern struct {
    state: KeyButtonState,
    position: FVec,
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

    usingnamespace c_enum_conversions(SensorType, c_int);
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
        sdl_free(self.list.ptr);
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

pub const ControllerConnectionState = enum(c_int) {
    INVALID = C.SDL_JOYSTICK_CONNECTION_INVALID,
    UNKNOWN = C.SDL_JOYSTICK_CONNECTION_UNKNOWN,
    WIRED = C.SDL_JOYSTICK_CONNECTION_WIRED,
    WIRELESS = C.SDL_JOYSTICK_CONNECTION_WIRELESS,

    usingnamespace c_enum_conversions(ControllerConnectionState, c_int);
};

/// https://partner.steamgames.com/doc/api/ISteamInput#InputHandle_t
pub const SteamHandle = extern struct {
    handle: u64,

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

pub const HW_VendorCode = extern struct {
    code: u16,

    inline fn new(code: u16) HW_VendorCode {
        return HW_VendorCode{ .code = code };
    }
    pub inline fn vendor_code(code: u16) HW_VendorCode {
        return HW_VendorCode{ .code = code };
    }
};
pub const HW_ProductCode = extern struct {
    code: u16,

    inline fn new(code: u16) HW_ProductCode {
        return HW_ProductCode{ .code = code };
    }
    pub inline fn product_code(code: u16) HW_ProductCode {
        return HW_ProductCode{ .code = code };
    }
};
pub const HW_ProductVersion = extern struct {
    ver: u16,

    inline fn new(ver: u16) HW_ProductVersion {
        return HW_ProductVersion{ .ver = ver };
    }
    pub inline fn product_version(ver: u16) HW_ProductVersion {
        return HW_ProductVersion{ .ver = ver };
    }
};
pub const HW_FirmwareVersion = extern struct {
    ver: u16,

    inline fn new(ver: u16) HW_FirmwareVersion {
        return HW_FirmwareVersion{ .ver = ver };
    }
    pub inline fn firmware_version(ver: u16) HW_FirmwareVersion {
        return HW_FirmwareVersion{ .ver = ver };
    }
};
pub const HW_SerialNumber = extern struct {
    serial: [*:0]const u8,

    inline fn new_err(ser: [*c]const u8) Error!HW_SerialNumber {
        return HW_SerialNumber{ .serial = try ptr_cast_or_null_err([*:0]const u8, ser) };
    }
    pub inline fn serial_number(serial: [*:0]const u8) HW_SerialNumber {
        return HW_SerialNumber{ .serial = serial };
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
    list: []GameControllerID,

    pub fn free(self: GamepadsList) void {
        sdl_free(self.list.ptr);
    }
};

pub const GUID = extern struct {
    data: [16]u8 = @splat(0),
};

pub const CameraID = extern struct {
    id: u32 = 0,
};

pub const TouchID = extern struct {
    id: u64 = 0,
};

pub const FingerID = extern struct {
    id: u64 = 0,
};

pub const MouseButtonFlags = extern struct {
    flags: u32 = 0,
};

pub const PenInputFlags = extern struct {
    flags: u32 = 0,
};

pub const PenAxis = enum(c_uint) {
    PRESSURE = C.SDL_PEN_AXIS_PRESSURE,
    X_TILT = C.SDL_PEN_AXIS_XTILT,
    Y_TILT = C.SDL_PEN_AXIS_YTILT,
    DISTANCE = C.SDL_PEN_AXIS_DISTANCE,
    ROTATION = C.SDL_PEN_AXIS_ROTATION,
    SLIDER = C.SDL_PEN_AXIS_SLIDER,
    TANGENTIAL_PRESSURE = C.SDL_PEN_AXIS_TANGENTIAL_PRESSURE,

    pub const AXIS_COUNT: c_uint = C.SDL_PEN_AXIS_COUNT;

    usingnamespace c_enum_conversions(PenAxis, c_uint);
};

pub const MouseWheelDirection = enum(c_uint) {
    NORMAL = C.SDL_MOUSEWHEEL_NORMAL,
    FLIPPED = C.SDL_MOUSEWHEEL_FLIPPED,

    usingnamespace c_enum_conversions(MouseWheelDirection, c_uint);
};

pub const PowerState = enum(c_int) {
    ERROR = C.SDL_POWERSTATE_ERROR,
    UNKNOWN = C.SDL_POWERSTATE_UNKNOWN,
    ON_BATTERY = C.SDL_POWERSTATE_ON_BATTERY,
    NO_BATTERY = C.SDL_POWERSTATE_NO_BATTERY,
    CHARGING = C.SDL_POWERSTATE_CHARGING,
    CHARGED = C.SDL_POWERSTATE_CHARGED,

    usingnamespace c_enum_conversions(PowerState, c_int);
};

pub const EventType = enum(u32) {
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

    usingnamespace c_enum_conversions(EventType, c_uint);
};

pub const Scancode = enum(c_uint) {
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

    pub const RESERVED = C.SDL_SCANCODE_RESERVED;
    pub const COUNT = C.SDL_SCANCODE_COUNT;

    usingnamespace c_enum_conversions(Scancode, c_uint);
};

pub const Keycode = extern struct {
    code: u32 = 0,
};
pub const Keymod = extern struct {
    mod: u16 = 0,
};

pub fn runtime_version() c_int {
    return C.SDL_GetVersion();
}
pub fn runtime_revision() [*:0]const u8 {
    return C.SDL_GetRevision();
}
pub const BUILD_MAJOR_VERSION = C.SDL_MAJOR_VERSION;
pub const BUILD_MINOR_VERSION = C.SDL_MINOR_VERSION;
pub const BUILD_MICRO_VERSION = C.SDL_MICRO_VERSION;
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

pub const GPU_API = struct {
    pub const Device = opaque {
        usingnamespace c_opaque_conversions(Device, C.SDL_GPUDevice);

        pub fn get_num_drivers() c_int {
            return C.SDL_GetNumGPUDrivers();
        }
        pub fn get_driver_name_by_inndex(index: c_int) Error![*:0]const u8 {
            return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGPUDriver(index));
        }
        pub fn device_supports_shader_formats(device_name: [*:0]const u8, shader_formats: ShaderFormatFlags) bool {
            return C.SDL_GPUSupportsShaderFormats(shader_formats.raw, device_name);
        }
        pub fn device_supports_properties(props: PropertiesID) bool {
            return C.SDL_GPUSupportsProperties(props.id);
        }
        pub fn create(shader_formats: ShaderFormatFlags, debug_mode: bool, driver_name: ?[*:0]const u8) Error!*Device {
            return ptr_cast_or_fail_err(*Device, C.SDL_CreateGPUDevice(shader_formats.raw, debug_mode, driver_name));
        }
        pub fn create_from_properties(props: PropertiesID) Error!*Device {
            return ptr_cast_or_fail_err(*Device, C.SDL_CreateGPUDeviceWithProperties(props.id));
        }
        pub fn destroy(self: *Device) void {
            C.SDL_DestroyGPUDevice(self.to_c());
        }
        pub fn get_driver_name(self: *Device) Error![*:0]const u8 {
            return ptr_cast_or_null_err([*:0]const u8, C.SDL_GetGPUDeviceDriver(self.to_c()));
        }
        pub fn get_shader_formats(self: *Device) ShaderFormatFlags {
            return ShaderFormatFlags{ .raw = C.SDL_GetGPUShaderFormats(self.to_c()) };
        }
        pub fn create_compute_pipeline(self: *Device, pipeline_info: *ComputePipelineCreateInfo) Error!*ComputePipeline {
            return ptr_cast_or_null_err(*ComputePipeline, C.SDL_CreateGPUComputePipeline(self.to_c(), pipeline_info.to_c()));
        }
        pub fn create_graphics_pipeline(self: *Device, pipeline_info: *GraphicsPipelineCreateInfo) Error!*GraphicsPipeline {
            return ptr_cast_or_null_err(*GraphicsPipeline, C.SDL_CreateGPUGraphicsPipeline(self.to_c(), pipeline_info.to_c()));
        }
        pub fn create_texture_sampler(self: *Device, sampler_info: *SamplerCreateInfo) Error!*TextureSampler {
            return ptr_cast_or_null_err(*TextureSampler, C.SDL_CreateGPUSampler(self.to_c(), sampler_info.to_c()));
        }
        pub fn create_shader(self: *Device, shader_info: *ShaderCreateInfo) Error!*Shader {
            return ptr_cast_or_null_err(*Shader, C.SDL_CreateGPUShader(self.to_c(), shader_info.to_c()));
        }
        pub fn create_buffer(self: *Device, buffer_info: *BufferCreateInfo) Error!*Buffer {
            return ptr_cast_or_null_err(*Buffer, C.SDL_CreateGPUBuffer(self.to_c(), buffer_info.to_c()));
        }
        pub fn create_transfer_buffer(self: *Device, buffer_info: *TransferBufferCreateInfo) Error!*TransferBuffer {
            return ptr_cast_or_null_err(*TransferBuffer, C.SDL_CreateGPUTransferBuffer(self.to_c(), buffer_info.to_c()));
        }
        pub fn set_buffer_name(self: *Device, buffer: *Buffer, name: [*:0]const u8) void {
            C.SDL_SetGPUBufferName(self.to_c(), buffer.to_c(), name);
        }
        pub fn set_texture_name(self: *Device, texture: *Texture, name: [*:0]const u8) void {
            C.SDL_SetGPUTextureName(self.to_c(), texture.to_c(), name);
        }
        pub fn release_texture(self: *Device, texture: *Texture) void {
            C.SDL_ReleaseGPUTexture(self.to_c(), texture.to_c());
        }
        pub fn release_texture_sampler(self: *Device, sampler: *TextureSampler) void {
            C.SDL_ReleaseGPUSampler(self.to_c(), sampler.to_c());
        }
        pub fn release_buffer(self: *Device, buffer: *Buffer) void {
            C.SDL_ReleaseGPUBuffer(self.to_c(), buffer.to_c());
        }
        pub fn release_transfer_buffer(self: *Device, buffer: *TransferBuffer) void {
            C.SDL_ReleaseGPUTransferBuffer(self.to_c(), buffer.to_c());
        }
        pub fn release_compute_pipeline(self: *Device, pipeline: *ComputePipeline) void {
            C.SDL_ReleaseGPUComputePipeline(self.to_c(), pipeline.to_c());
        }
        pub fn release_shader(self: *Device, shader: *Shader) void {
            C.SDL_ReleaseGPUShader(self.to_c(), shader.to_c());
        }
        pub fn release_graphics_pipeline(self: *Device, pipeline: *GraphicsPipeline) void {
            C.SDL_ReleaseGPUGraphicsPipeline(self.to_c(), pipeline.to_c());
        }
        pub fn aquire_command_buffer(self: *Device) Error!*CommandBuffer {
            return ptr_cast_or_fail_err(*CommandBuffer, C.SDL_AcquireGPUCommandBuffer(self.to_c()));
        }
        //TODO
        // pub extern fn SDL_MapGPUTransferBuffer(device: ?*SDL_GPUDevice, transfer_buffer: ?*SDL_GPUTransferBuffer, cycle: bool) ?*anyopaque;
        // pub extern fn SDL_UnmapGPUTransferBuffer(device: ?*SDL_GPUDevice, transfer_buffer: ?*SDL_GPUTransferBuffer) void;
        // pub extern fn SDL_WindowSupportsGPUSwapchainComposition(device: ?*SDL_GPUDevice, window: ?*SDL_Window, swapchain_composition: SDL_GPUSwapchainComposition) bool;
        // pub extern fn SDL_WindowSupportsGPUPresentMode(device: ?*SDL_GPUDevice, window: ?*SDL_Window, present_mode: SDL_GPUPresentMode) bool;
        // pub extern fn SDL_ClaimWindowForGPUDevice(device: ?*SDL_GPUDevice, window: ?*SDL_Window) bool;
        // pub extern fn SDL_ReleaseWindowFromGPUDevice(device: ?*SDL_GPUDevice, window: ?*SDL_Window) void;
        // pub extern fn SDL_SetGPUSwapchainParameters(device: ?*SDL_GPUDevice, window: ?*SDL_Window, swapchain_composition: SDL_GPUSwapchainComposition, present_mode: SDL_GPUPresentMode) bool;
        // pub extern fn SDL_SetGPUAllowedFramesInFlight(device: ?*SDL_GPUDevice, allowed_frames_in_flight: Uint32) bool;
        // pub extern fn SDL_GetGPUSwapchainTextureFormat(device: ?*SDL_GPUDevice, window: ?*SDL_Window) SDL_GPUTextureFormat;
        // pub extern fn SDL_WaitForGPUSwapchain(device: ?*SDL_GPUDevice, window: ?*SDL_Window) bool;
        // pub extern fn SDL_WaitForGPUIdle(device: ?*SDL_GPUDevice) bool;
        // pub extern fn SDL_WaitForGPUFences(device: ?*SDL_GPUDevice, wait_all: bool, fences: [*c]const ?*SDL_GPUFence, num_fences: Uint32) bool;
        // pub extern fn SDL_QueryGPUFence(device: ?*SDL_GPUDevice, fence: ?*SDL_GPUFence) bool;
        // pub extern fn SDL_ReleaseGPUFence(device: ?*SDL_GPUDevice, fence: ?*SDL_GPUFence) void;
    };

    pub const TransferBufferCreateInfo = extern struct {
        usage: TransferBufferUsage = .DOWNLOAD,
        size: u32 = 0,
        props: PropertiesID = .NULL,

        usingnamespace c_non_opaque_conversions(TransferBufferCreateInfo, C.SDL_GPUTransferBufferCreateInfo);
    };

    pub const BufferCreateInfo = extern struct {
        usage: BufferUsageFlags = .blank(),
        size: u32 = 0,
        props: PropertiesID = .NULL,

        usingnamespace c_non_opaque_conversions(BufferCreateInfo, C.SDL_GPUBufferCreateInfo);
    };

    pub const TextureCreateInfo = extern struct {
        type: TextureType = ._2D,
        format: TextureFormat = .INVALID,
        usage: TextureUsageFlags = .blank(),
        width: u32 = 0,
        height: u32 = 0,
        layer_count_or_depth: u32 = 0,
        num_levels: u32 = 0,
        sample_count: SampleCount = ._1,
        props: PropertiesID = .NULL,

        usingnamespace c_non_opaque_conversions(TextureCreateInfo, C.SDL_GPUTextureCreateInfo);
    };

    pub const ShaderCreateInfo = extern struct {
        code_size: usize = 0,
        code: ?[*]const u8 = null,
        entrypoint_func: [*:0]const u8 = "",
        format: ShaderFormatFlags = ShaderFormatFlags.new_single(.INVALID),
        stage: ShaderStage = .VERTEX,
        num_samplers: u32 = 0,
        num_storage_textures: u32 = 0,
        num_storage_buffers: u32 = 0,
        num_uniform_buffers: u32 = 0,
        props: PropertiesID = .{},

        usingnamespace c_non_opaque_conversions(ShaderCreateInfo, C.SDL_GPUShaderCreateInfo);
    };

    pub const ComputePipelineCreateInfo = extern struct {
        code_len: usize = 0,
        code_data: [*]const u8,
        entrypoint_func: [*:0]const u8 = "",
        format: ShaderFormatFlags = .{ .raw = 0 },
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

        usingnamespace c_non_opaque_conversions(ComputePipelineCreateInfo, C.SDL_GPUComputePipelineCreateInfo);
    };

    pub const GraphicsPipelineCreateInfo = extern struct {
        vertex_shader: ?*Shader = null,
        fragment_shader: ?*Shader = null,
        vertex_input_state: VertexInputState = .{},
        primitive_type: PrimitiveType = .TRIANGLE_LIST,
        rasterizer_state: RasterizerState = .{},
        multisample_state: MultisampleState = .{},
        depth_stencil_state: DepthStencilState = .{},
        target_info: GraphicsPipelineTargetInfo = .{},
        props: PropertiesID = .{},

        usingnamespace c_non_opaque_conversions(GraphicsPipelineCreateInfo, C.SDL_GPUGraphicsPipelineCreateInfo);
    };

    pub const VertexInputState = extern struct {
        vertex_buffer_descriptions: ?[*]const VertexBufferDescription = null,
        num_vertex_buffers: u32 = 0,
        vertex_attributes: ?[*]const VertexAttribute = null,
        num_vertex_attributes: u32 = 0,

        usingnamespace c_non_opaque_conversions(VertexInputState, C.SDL_GPUVertexInputState);
    };

    pub const VertexBufferDescription = extern struct {
        slot: u32 = 0,
        stride: u32 = 0,
        input_rate: VertexInputRate = .VERTEX,
        instance_step_rate: u32 = 0,

        usingnamespace c_non_opaque_conversions(VertexBufferDescription, C.SDL_GPUVertexBufferDescription);
    };

    pub const VertexAttribute = extern struct {
        location: u32 = 0,
        buffer_slot: u32 = 0,
        format: VertexElementFormat = .INVALID,
        offset: u32 = 0,

        usingnamespace c_non_opaque_conversions(VertexAttribute, C.SDL_GPUVertexAttribute);
    };

    pub const RasterizerState = extern struct {
        fill_mode: FillMode = .FILL,
        cull_mode: CullMode = .NONE,
        front_face_winding: FrontFaceWinding = .CCW,
        depth_bias_constant_factor: f32 = 0,
        depth_bias_clamp: f32 = 0,
        depth_bias_slope_factor: f32 = 0,
        enable_depth_bias: bool = false,
        enable_depth_clip: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,

        usingnamespace c_non_opaque_conversions(RasterizerState, C.SDL_GPURasterizerState);
    };

    pub const MultisampleState = extern struct {
        sample_count: SampleCount = ._1,
        sample_mask: u32 = 0,
        enable_mask: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,
        _padding3: u8 = 0,

        usingnamespace c_non_opaque_conversions(MultisampleState, C.SDL_GPUMultisampleState);
    };

    pub const DepthStencilState = extern struct {
        compare_op: CompareOp = .INVALID,
        back_stencil_state: StencilOpState = .{},
        front_stencil_state: StencilOpState = .{},
        compare_mask: u8 = 0,
        write_mask: u8 = 0,
        enable_depth_test: bool = false,
        enable_depth_write: bool = false,
        enable_stencil_test: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,
        _padding3: u8 = 0,

        usingnamespace c_non_opaque_conversions(DepthStencilState, C.SDL_GPUDepthStencilState);
    };

    pub const StencilOpState = extern struct {
        fail_op: StencilOp = .INVALID,
        pass_op: StencilOp = .INVALID,
        depth_fail_op: StencilOp = .INVALID,
        compare_op: CompareOp = .INVALID,

        usingnamespace c_non_opaque_conversions(StencilOpState, C.SDL_GPUStencilOpState);
    };

    pub const GraphicsPipelineTargetInfo = extern struct {
        color_target_descriptions: ?[*]const ColorTargetDescription = null,
        num_color_targets: u32 = 0,
        depth_stencil_format: TextureFormat = .INVALID,
        has_depth_stencil_target: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,
        _padding3: u8 = 0,

        usingnamespace c_non_opaque_conversions(GraphicsPipelineTargetInfo, C.SDL_GPUGraphicsPipelineTargetInfo);
    };

    pub const ColorTargetDescription = extern struct {
        format: TextureFormat = .INVALID,
        blend_state: ColorTargetBlendState = .{},

        usingnamespace c_non_opaque_conversions(ColorTargetDescription, C.SDL_GPUColorTargetDescription);
    };

    pub const ColorTargetBlendState = extern struct {
        src_color_blendfactor: RenderAPI.BlendFactor = .INVALID,
        dst_color_blendfactor: RenderAPI.BlendFactor = .INVALID,
        color_blend_op: BlendOp = .INVALID,
        src_alpha_blendfactor: RenderAPI.BlendFactor = .INVALID,
        dst_alpha_blendfactor: RenderAPI.BlendFactor = .INVALID,
        alpha_blend_op: BlendOp = .INVALID,
        color_write_mask: ColorComponentFlags = .{ .raw = 0 },
        enable_blend: bool = false,
        enable_color_write_mask: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,

        usingnamespace c_non_opaque_conversions(ColorTargetBlendState, C.SDL_GPUColorTargetBlendState);
    };

    pub const IndirectDispatchCommand = extern struct {
        groupcount_x: u32 = 0,
        groupcount_y: u32 = 0,
        groupcount_z: u32 = 0,

        usingnamespace c_non_opaque_conversions(IndirectDispatchCommand, C.SDL_GPUIndirectDispatchCommand);
    };

    pub const IndexedIndirectDrawCommand = extern struct {
        num_indices: u32 = 0,
        num_instances: u32 = 0,
        first_index: u32 = 0,
        vertex_offset: i32 = 0,
        first_instance: u32 = 0,

        usingnamespace c_non_opaque_conversions(IndexedIndirectDrawCommand, C.SDL_GPUIndexedIndirectDrawCommand);
    };

    pub const IndirectDrawCommand = extern struct {
        num_vertices: u32 = 0,
        num_instances: u32 = 0,
        first_vertex: u32 = 0,
        first_instance: u32 = 0,

        usingnamespace c_non_opaque_conversions(IndirectDrawCommand, C.SDL_GPUIndirectDrawCommand);
    };

    pub const BufferRegion = extern struct {
        buffer: ?*Buffer = null,
        offset: u32 = 0,
        size: u32 = 0,

        usingnamespace c_non_opaque_conversions(BufferRegion, C.SDL_GPUBufferRegion);
    };

    pub const BufferLocation = extern struct {
        buffer: ?*Buffer = null,
        offset: u32 = u32,

        usingnamespace c_non_opaque_conversions(BufferLocation, C.SDL_GPUBufferLocation);
    };

    pub const BlitRegion = extern struct {
        texture: ?*Texture = null,
        mip_level: u32 = 0,
        layer_or_depth_plane: u32 = 0,
        x: u32 = 0,
        y: u32 = 0,
        w: u32 = 0,
        h: u32 = 0,

        usingnamespace c_non_opaque_conversions(BlitRegion, C.SDL_GPUBlitRegion);
    };

    pub const TextureRegion = extern struct {
        texture: ?*Texture = null,
        mip_level: u32 = 0,
        layer: u32 = 0,
        x: u32 = 0,
        y: u32 = 0,
        z: u32 = 0,
        w: u32 = 0,
        h: u32 = 0,
        d: u32 = 0,

        usingnamespace c_non_opaque_conversions(TextureRegion, C.SDL_GPUTextureRegion);
    };

    pub const TextureLocation = extern struct {
        texture: ?*Texture = null,
        mip_level: u32 = 0,
        layer: u32 = 0,
        x: u32 = 0,
        y: u32 = 0,
        z: u32 = 0,

        usingnamespace c_non_opaque_conversions(TextureLocation, C.SDL_GPUTextureLocation);
    };

    pub const TransferBufferLocation = extern struct {
        transfer_buffer: ?*TransferBuffer = null,
        offset: u32 = 0,

        usingnamespace c_non_opaque_conversions(TransferBufferLocation, C.SDL_GPUTransferBufferLocation);
    };

    pub const TextureTransferInfo = extern struct {
        transfer_buffer: ?*TransferBuffer = null,
        offset: u32 = 0,
        pixels_per_row: u32 = 0,
        rows_per_layer: u32 = 0,

        usingnamespace c_non_opaque_conversions(TextureTransferInfo, C.SDL_GPUTextureTransferInfo);
    };

    pub const SamplerCreateInfo = extern struct {
        min_filter: FilterMode = .LINEAR,
        mag_filter: FilterMode = .LINEAR,
        mipmap_mode: SamplerMipmapMode = .LINEAR,
        address_mode_u: SamplerAddressMode = .CLAMP_TO_EDGE,
        address_mode_v: SamplerAddressMode = .CLAMP_TO_EDGE,
        address_mode_w: SamplerAddressMode = .CLAMP_TO_EDGE,
        mip_lod_bias: f32 = 0,
        max_anisotropy: f32 = 0,
        compare_op: CompareOp = .INVALID,
        min_lod: f32 = @import("std").mem.zeroes(f32),
        max_lod: f32 = @import("std").mem.zeroes(f32),
        enable_anisotropy: bool = false,
        enable_compare: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,
        props: PropertiesID = .{},

        usingnamespace c_non_opaque_conversions(SamplerCreateInfo, C.SDL_GPUSamplerCreateInfo);
    };

    pub const ColorTargetInfo = extern struct {
        texture: ?*Texture = null,
        mip_level: u32 = 0,
        layer_or_depth_plane: u32 = 0,
        clear_color: FColor_RGBA = .BLACK,
        load_op: LoadOp = .LOAD,
        store_op: StoreOp = .STORE,
        resolve_texture: ?*Texture = null,
        resolve_mip_level: u32 = 0,
        resolve_layer: u32 = 0,
        cycle: bool = false,
        cycle_resolve_texture: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,

        usingnamespace c_non_opaque_conversions(ColorTargetInfo, C.SDL_GPUColorTargetInfo);
    };

    pub const DepthStencilTargetInfo = extern struct {
        texture: ?*Texture = null,
        clear_depth: f32 = 0,
        load_op: LoadOp = .LOAD,
        store_op: StoreOp = .STORE,
        stencil_load_op: LoadOp = .LOAD,
        stencil_store_op: StoreOp = .STORE,
        cycle: bool = false,
        clear_stencil: u8 = 0,
        _padding1: u8 = 0,
        _padding2: u8 = 0,

        usingnamespace c_non_opaque_conversions(DepthStencilTargetInfo, C.SDL_GPUDepthStencilTargetInfo);
    };

    pub const Viewport = extern struct {
        x: f32 = 0,
        y: f32 = 0,
        w: f32 = 0,
        h: f32 = 0,
        min_depth: f32 = 0,
        max_depth: f32 = 0,

        pub fn from_rect(rect: FRect, min_depth: f32, max_depth: f32) Viewport {
            return Viewport{
                .x = rect.x,
                .y = rect.y,
                .w = rect.w,
                .h = rect.h,
                .min_depth = min_depth,
                .max_depth = max_depth,
            };
        }

        usingnamespace c_non_opaque_conversions(Viewport, C.SDL_GPUViewport);
    };

    pub const BufferBinding = extern struct {
        buffer: ?*Buffer = null,
        offset: u32 = 0,

        usingnamespace c_non_opaque_conversions(BufferBinding, C.SDL_GPUBufferBinding);
    };

    pub const TextureSamplerBinding = extern struct {
        texture: ?*Texture = null,
        sampler: ?*TextureSampler = null,

        usingnamespace c_non_opaque_conversions(TextureSamplerBinding, C.SDL_GPUTextureSamplerBinding);
    };

    pub const StorageBufferReadWriteBinding = extern struct {
        buffer: ?*Buffer = null,
        cycle: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,
        _padding3: u8 = 0,

        usingnamespace c_non_opaque_conversions(StorageBufferReadWriteBinding, C.SDL_GPUStorageBufferReadWriteBinding);
    };

    pub const StorageTextureReadWriteBinding = extern struct {
        texture: ?*Texture = null,
        mip_level: u32 = 0,
        layer: u32 = 0,
        cycle: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,
        _padding3: u8 = 0,

        usingnamespace c_non_opaque_conversions(StorageTextureReadWriteBinding, C.SDL_GPUStorageTextureReadWriteBinding);
    };

    pub const BlitInfo = extern struct {
        source: BlitRegion = .{},
        destination: BlitRegion = .{},
        load_op: LoadOp = .LOAD,
        clear_color: FColor_RGBA = .BLACK,
        flip_mode: FlipMode = .NONE,
        filter: FilterMode = .LINEAR,
        cycle: bool = false,
        _padding1: u8 = 0,
        _padding2: u8 = 0,
        _padding3: u8 = 0,

        usingnamespace c_non_opaque_conversions(BlitInfo, C.SDL_GPUBlitInfo);
    };

    pub const SwapchainComposition = enum(c_uint) {
        SDR = C.SDL_GPU_SWAPCHAINCOMPOSITION_SDR,
        SDR_LINEAR = C.SDL_GPU_SWAPCHAINCOMPOSITION_SDR_LINEAR,
        HDR_EXTENDED_LINEAR = C.SDL_GPU_SWAPCHAINCOMPOSITION_HDR_EXTENDED_LINEAR,
        HDR10_ST2084 = C.SDL_GPU_SWAPCHAINCOMPOSITION_HDR10_ST2084,

        usingnamespace c_enum_conversions(SwapchainComposition, c_uint);
    };

    pub const TransferBufferUsage = enum(c_uint) {
        UPLOAD = C.SDL_TRANSFERBUFFERUSAGE_UPLOAD,
        DOWNLOAD = C.SDL_TRANSFERBUFFERUSAGE_DOWNLOAD,

        usingnamespace c_enum_conversions(TransferBufferUsage, c_uint);
    };

    pub const ShaderStage = enum(c_uint) {
        VERTEX = C.SDL_SHADERSTAGE_VERTEX,
        FRAGMENT = C.SDL_SHADERSTAGE_FRAGMENT,

        usingnamespace c_enum_conversions(ShaderStage, c_uint);
    };

    pub const VertexInputRate = enum(c_uint) {
        VERTEX = C.SDL_VERTEXINPUTRATE_VERTEX,
        INSTANCE = C.SDL_VERTEXINPUTRATE_INSTANCE,

        usingnamespace c_enum_conversions(VertexInputRate, c_uint);
    };

    pub const FilterMode = enum(c_uint) {
        NEAREST = C.SDL_FILTER_NEAREST,
        LINEAR = C.SDL_FILTER_LINEAR,

        usingnamespace c_enum_conversions(FilterMode, c_uint);
    };

    pub const SamplerMipmapMode = enum(c_uint) {
        NEAREST = C.SDL_SAMPLERMIPMAPMODE_NEAREST,
        LINEAR = C.SDL_SAMPLERMIPMAPMODE_LINEAR,

        usingnamespace c_enum_conversions(SamplerMipmapMode, c_uint);
    };

    pub const SamplerAddressMode = enum(c_uint) {
        REPEAT = C.SDL_SAMPLERADDRESSMODE_REPEAT,
        MIRRORED_REPEAT = C.SDL_SAMPLERADDRESSMODE_MIRRORED_REPEAT,
        CLAMP_TO_EDGE = C.SDL_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,

        usingnamespace c_enum_conversions(SamplerAddressMode, c_uint);
    };

    pub const PresentMode = enum(c_uint) {
        VSYNC = C.SDL_PRESENTMODE_VSYNC,
        IMMEDIATE = C.SDL_PRESENTMODE_IMMEDIATE,
        MAILBOX = C.SDL_PRESENTMODE_MAILBOX,

        usingnamespace c_enum_conversions(PresentMode, c_uint);
    };

    pub const BlendFactor = enum(c_uint) {
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

        usingnamespace c_enum_conversions(BlendFactor, c_uint);
    };

    pub const BlendOp = enum(c_uint) {
        INVALID = C.SDL_BLENDOP_INVALID,
        ADD = C.SDL_BLENDOP_ADD,
        SUBTRACT = C.SDL_BLENDOP_SUBTRACT,
        REVERSE_SUBTRACT = C.SDL_BLENDOP_REVERSE_SUBTRACT,
        MIN = C.SDL_BLENDOP_MIN,
        MAX = C.SDL_BLENDOP_MAX,

        usingnamespace c_enum_conversions(BlendOp, c_uint);
    };

    pub const CompareOp = enum(c_uint) {
        INVALID = C.SDL_COMPAREOP_INVALID,
        NEVER = C.SDL_COMPAREOP_NEVER,
        LESS = C.SDL_COMPAREOP_LESS,
        EQUAL = C.SDL_COMPAREOP_EQUAL,
        LESS_OR_EQUAL = C.SDL_COMPAREOP_LESS_OR_EQUAL,
        GREATER = C.SDL_COMPAREOP_GREATER,
        NOT_EQUAL = C.SDL_COMPAREOP_NOT_EQUAL,
        GREATER_OR_EQUAL = C.SDL_COMPAREOP_GREATER_OR_EQUAL,
        ALWAYS = C.SDL_COMPAREOP_ALWAYS,

        usingnamespace c_enum_conversions(CompareOp, c_uint);
    };

    pub const StencilOp = enum(c_uint) {
        INVALID = C.SDL_STENCILOP_INVALID,
        KEEP = C.SDL_STENCILOP_KEEP,
        ZERO = C.SDL_STENCILOP_ZERO,
        REPLACE = C.SDL_STENCILOP_REPLACE,
        INCREMENT_AND_CLAMP = C.SDL_STENCILOP_INCREMENT_AND_CLAMP,
        DECREMENT_AND_CLAMP = C.SDL_STENCILOP_DECREMENT_AND_CLAMP,
        INVERT = C.SDL_STENCILOP_INVERT,
        INCREMENT_AND_WRAP = C.SDL_STENCILOP_INCREMENT_AND_WRAP,
        DECREMENT_AND_WRAP = C.SDL_STENCILOP_DECREMENT_AND_WRAP,

        usingnamespace c_enum_conversions(StencilOp, c_uint);
    };

    pub const FillMode = enum(c_uint) {
        FILL = C.SDL_FILLMODE_FILL,
        LINE = C.SDL_FILLMODE_LINE,

        usingnamespace c_enum_conversions(FillMode, c_uint);
    };

    pub const CullMode = enum(c_uint) {
        NONE = C.SDL_CULLMODE_NONE,
        FRONT = C.SDL_CULLMODE_FRONT,
        BACK = C.SDL_CULLMODE_BACK,

        usingnamespace c_enum_conversions(CullMode, c_uint);
    };

    pub const FrontFaceWinding = enum(c_uint) {
        CCW = C.SDL_FRONTFACE_COUNTER_CLOCKWISE,
        CW = C.SDL_FRONTFACE_CLOCKWISE,

        usingnamespace c_enum_conversions(FrontFaceWinding, c_uint);
    };

    pub const VertexElementFormat = enum(c_uint) {
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

        usingnamespace c_enum_conversions(VertexElementFormat, c_uint);
    };

    pub const Buffer = opaque {
        usingnamespace c_opaque_conversions(Buffer, C.SDL_GPUBuffer);
    };

    pub const TransferBuffer = opaque {
        usingnamespace c_opaque_conversions(TransferBuffer, C.SDL_GPUTransferBuffer);
    };

    pub const Texture = opaque {
        usingnamespace c_opaque_conversions(Texture, C.SDL_GPUTexture);
    };

    pub const TextureSampler = opaque {
        usingnamespace c_opaque_conversions(TextureSampler, C.SDL_GPUSampler);
    };

    pub const Shader = opaque {
        usingnamespace c_opaque_conversions(Shader, C.SDL_GPUShader);
    };

    pub const ComputePipeline = opaque {
        usingnamespace c_opaque_conversions(ComputePipeline, C.SDL_GPUComputePipeline);
    };

    pub const GraphicsPipeline = opaque {
        usingnamespace c_opaque_conversions(GraphicsPipeline, C.SDL_GPUGraphicsPipeline);
    };

    pub const CommandBuffer = opaque {
        usingnamespace c_opaque_conversions(CommandBuffer, C.SDL_GPUCommandBuffer);

        pub fn insert_debug_label(self: *CommandBuffer, text: [*:0]const u8) void {
            C.SDL_InsertGPUDebugLabel(self.to_c(), text);
        }
        pub fn push_debug_group(self: *CommandBuffer, name: [*:0]const u8) void {
            C.SDL_PushGPUDebugGroup(self.to_c(), name);
        }
        pub fn pop_debug_group(self: *CommandBuffer) void {
            C.SDL_PopGPUDebugGroup(self.to_c());
        }
        pub fn push_vertex_uniform_data(self: *CommandBuffer, slot_index: u32, data_ptr: anytype) void {
            const data_raw = Utils.raw_slice_cast_const(data_ptr);
            C.SDL_PushGPUVertexUniformData(self.to_c(), slot_index, data_raw.ptr, @intCast(data_raw.len));
        }
        pub fn push_fragment_uniform_data(self: *CommandBuffer, slot_index: u32, data_ptr: anytype) void {
            const data_raw = Utils.raw_slice_cast_const(data_ptr);
            C.SDL_PushGPUFragmentUniformData(self.to_c(), slot_index, data_raw.ptr, @intCast(data_raw.len));
        }
        pub fn push_compute_uniform_data(self: *CommandBuffer, slot_index: u32, data_ptr: anytype) void {
            const data_raw = Utils.raw_slice_cast_const(data_ptr);
            C.SDL_PushGPUComputeUniformData(self.to_c(), slot_index, data_raw.ptr, @intCast(data_raw.len));
        }
        pub fn begin_render_pass(self: *CommandBuffer, color_targets: []const ColorTargetInfo, depth_stencil_target: *DepthStencilTargetInfo) Error!*RenderPass {
            return ptr_cast_or_fail_err(*RenderPass, C.SDL_BeginGPURenderPass(self.to_c(), @ptrCast(@alignCast(color_targets.ptr)), @intCast(color_targets.len), depth_stencil_target.to_c()));
        }
        pub fn begin_compute_pass(self: *CommandBuffer, storage_texture_bindings: []const StorageTextureReadWriteBinding, storage_buffer_bindings: []const StorageBufferReadWriteBinding) Error!*ComputePass {
            return ptr_cast_or_fail_err(*ComputePass, C.SDL_BeginGPUComputePass(self.to_c(), @ptrCast(@alignCast(storage_texture_bindings.ptr)), @intCast(storage_texture_bindings.len), @ptrCast(@alignCast(storage_buffer_bindings.ptr)), @intCast(storage_buffer_bindings.len)));
        }
        //TODO
        // pub extern fn SDL_BeginGPUCopyPass(command_buffer: ?*SDL_GPUCommandBuffer) ?*SDL_GPUCopyPass;
        // pub extern fn SDL_GenerateMipmapsForGPUTexture(command_buffer: ?*SDL_GPUCommandBuffer, texture: ?*SDL_GPUTexture) void;
        // pub extern fn SDL_BlitGPUTexture(command_buffer: ?*SDL_GPUCommandBuffer, info: [*c]const SDL_GPUBlitInfo) void;
        // pub extern fn SDL_AcquireGPUSwapchainTexture(command_buffer: ?*SDL_GPUCommandBuffer, window: ?*SDL_Window, swapchain_texture: [*c]?*SDL_GPUTexture, swapchain_texture_width: [*c]Uint32, swapchain_texture_height: [*c]Uint32) bool;
    };

    pub const RenderPass = opaque {
        usingnamespace c_opaque_conversions(RenderPass, C.SDL_GPURenderPass);

        pub fn bind_graphics_pipeline(self: *RenderPass, pipeline: *GraphicsPipeline) void {
            C.SDL_BindGPUGraphicsPipeline(self.to_c_ptr(), pipeline.to_c());
        }
        pub fn set_viewport(self: *RenderPass, viewport: Viewport) void {
            C.SDL_SetGPUViewport(self.to_c_ptr(), viewport.to_c());
        }
        pub fn clear_viewport(self: *RenderPass) void {
            C.SDL_SetGPUViewport(self.to_c_ptr(), null);
        }
        pub fn set_scissor(self: *RenderPass, scissor_rect: IRect) void {
            C.SDL_SetGPUScissor(self.to_c_ptr(), @ptrCast(@alignCast(&scissor_rect)));
        }
        pub fn clear_scissor(self: *RenderPass) void {
            C.SDL_SetGPUScissor(self.to_c_ptr(), null);
        }
        pub fn set_blend_constants(self: *RenderPass, blend_constants: FColor_RGBA) void {
            C.SDL_SetGPUBlendConstants(self.to_c_ptr(), @bitCast(blend_constants));
        }
        pub fn set_stencil_reference_val(self: *RenderPass, ref_val: u8) void {
            C.SDL_SetGPUStencilReference(self.to_c_ptr(), ref_val);
        }
        pub fn bind_vertex_buffers_to_consecutive_slots(self: *RenderPass, first_slot: u32, buffer_bindings: []const BufferBinding) void {
            C.SDL_BindGPUVertexBuffers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(buffer_bindings.ptr)), @intCast(buffer_bindings.len));
        }
        pub fn bind_index_buffer(self: *RenderPass, buffer_binding: *BufferBinding, index_type_size: IndexTypeSize) void {
            C.SDL_BindGPUIndexBuffer(self.to_c_ptr(), buffer_binding.to_c_ptr(), index_type_size.to_c());
        }
        pub fn bind_vertex_samplers_to_consecutive_slots(self: *RenderPass, first_slot: u32, sampler_bindings: []const TextureSamplerBinding) void {
            C.SDL_BindGPUVertexSamplers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(sampler_bindings.ptr)), @intCast(sampler_bindings.len));
        }
        pub fn bind_vertex_storage_textures_to_consecutive_slots(self: *RenderPass, first_slot: u32, storage_textures: []const Texture) void {
            C.SDL_BindGPUVertexStorageTextures(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(storage_textures.ptr)), @intCast(storage_textures.len));
        }
        pub fn bind_vertex_storage_buffers_to_consecutive_slots(self: *RenderPass, first_slot: u32, storage_buffers: []const Buffer) void {
            C.SDL_BindGPUVertexStorageBuffers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(storage_buffers.ptr)), @intCast(storage_buffers.len));
        }
        pub fn bind_fragment_samplers_to_consecutive_slots(self: *RenderPass, first_slot: u32, sampler_bindings: []const TextureSamplerBinding) void {
            C.SDL_BindGPUFragmentSamplers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(sampler_bindings.ptr)), @intCast(sampler_bindings.len));
        }
        pub fn bind_fragment_storage_textures_to_consecutive_slots(self: *RenderPass, first_slot: u32, storage_textures: []const Texture) void {
            C.SDL_BindGPUFragmentStorageTextures(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(storage_textures.ptr)), @intCast(storage_textures.len));
        }
        pub fn bind_fragment_storage_buffers_to_consecutive_slots(self: *RenderPass, first_slot: u32, storage_buffers: []const Buffer) void {
            C.SDL_BindGPUFragmentStorageBuffers(self.to_c_ptr(), first_slot, @ptrCast(@alignCast(storage_buffers.ptr)), @intCast(storage_buffers.len));
        }
        pub fn draw_primitives(self: *RenderPass, first_vertex: u32, num_vertexes: u32, first_instance_id: u32, num_instances: u32) void {
            C.SDL_DrawGPUPrimitives(self.to_c_ptr(), num_vertexes, num_instances, first_vertex, first_instance_id);
        }
        pub fn draw_indexed_primitives(self: *RenderPass, vertex_offset_per_index: i32, first_index: u32, num_indexes: u32, first_instance_id: u32, num_instances: u32) void {
            C.SDL_DrawGPUIndexedPrimitives(self.to_c_ptr(), num_indexes, num_instances, first_index, vertex_offset_per_index, first_instance_id);
        }
        pub fn draw_primitives_indirect(self: *RenderPass, buffer: *Buffer, offset: u32, draw_count: u32) void {
            C.SDL_DrawGPUPrimitivesIndirect(self.to_c_ptr(), buffer.to_c_ptr(), offset, draw_count);
        }
        pub fn draw_indexed_primitives_indirect(self: *RenderPass, buffer: *Buffer, offset: u32, draw_count: u32) void {
            C.SDL_DrawGPUIndexedPrimitivesIndirect(self.to_c_ptr(), buffer.to_c_ptr(), offset, draw_count);
        }
        pub fn end_render_pass(self: *RenderPass) void {
            C.SDL_EndGPURenderPass(self.to_c_ptr());
        }
    };

    pub const ComputePass = opaque {
        usingnamespace c_opaque_conversions(ComputePass, C.SDL_GPUComputePass);
        //TODO
        // pub extern fn SDL_BindGPUComputePipeline(compute_pass: ?*SDL_GPUComputePass, compute_pipeline: ?*SDL_GPUComputePipeline) void;
        // pub extern fn SDL_BindGPUComputeSamplers(compute_pass: ?*SDL_GPUComputePass, first_slot: Uint32, texture_sampler_bindings: [*c]const SDL_GPUTextureSamplerBinding, num_bindings: Uint32) void;
        // pub extern fn SDL_BindGPUComputeStorageTextures(compute_pass: ?*SDL_GPUComputePass, first_slot: Uint32, storage_textures: [*c]const ?*SDL_GPUTexture, num_bindings: Uint32) void;
        // pub extern fn SDL_BindGPUComputeStorageBuffers(compute_pass: ?*SDL_GPUComputePass, first_slot: Uint32, storage_buffers: [*c]const ?*SDL_GPUBuffer, num_bindings: Uint32) void;
        // pub extern fn SDL_DispatchGPUCompute(compute_pass: ?*SDL_GPUComputePass, groupcount_x: Uint32, groupcount_y: Uint32, groupcount_z: Uint32) void;
        // pub extern fn SDL_DispatchGPUComputeIndirect(compute_pass: ?*SDL_GPUComputePass, buffer: ?*SDL_GPUBuffer, offset: Uint32) void;
        // pub extern fn SDL_EndGPUComputePass(compute_pass: ?*SDL_GPUComputePass) void;
    };

    pub const CopyPass = opaque {
        usingnamespace c_opaque_conversions(CopyPass, C.SDL_GPUCopyPass);
        //TODO
        // pub extern fn SDL_UploadToGPUTexture(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUTextureTransferInfo, destination: [*c]const SDL_GPUTextureRegion, cycle: bool) void;
        // pub extern fn SDL_UploadToGPUBuffer(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUTransferBufferLocation, destination: [*c]const SDL_GPUBufferRegion, cycle: bool) void;
        // pub extern fn SDL_CopyGPUTextureToTexture(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUTextureLocation, destination: [*c]const SDL_GPUTextureLocation, w: Uint32, h: Uint32, d: Uint32, cycle: bool) void;
        // pub extern fn SDL_CopyGPUBufferToBuffer(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUBufferLocation, destination: [*c]const SDL_GPUBufferLocation, size: Uint32, cycle: bool) void;
        // pub extern fn SDL_DownloadFromGPUTexture(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUTextureRegion, destination: [*c]const SDL_GPUTextureTransferInfo) void;
        // pub extern fn SDL_DownloadFromGPUBuffer(copy_pass: ?*SDL_GPUCopyPass, source: [*c]const SDL_GPUBufferRegion, destination: [*c]const SDL_GPUTransferBufferLocation) void;
        // pub extern fn SDL_EndGPUCopyPass(copy_pass: ?*SDL_GPUCopyPass) void;
    };

    pub const Fence = opaque {
        usingnamespace c_opaque_conversions(Fence, C.SDL_GPUFence);
    };

    pub const PrimitiveType = enum(c_uint) {
        TRIANGLE_LIST = C.SDL_PRIMITIVETYPE_TRIANGLELIST,
        TRIANGLE_STRIP = C.SDL_PRIMITIVETYPE_TRIANGLESTRIP,
        LINE_LIST = C.SDL_PRIMITIVETYPE_LINELIST,
        LINE_STRIP = C.SDL_PRIMITIVETYPE_LINESTRIP,
        POINT_LIST = C.SDL_PRIMITIVETYPE_POINTLIST,

        usingnamespace c_enum_conversions(PrimitiveType, c_uint);
    };

    pub const LoadOp = enum(c_uint) {
        LOAD = C.SDL_LOADOP_LOAD,
        CLEAR = C.SDL_LOADOP_CLEAR,
        DONT_CARE = C.SDL_LOADOP_DONT_CARE,

        usingnamespace c_enum_conversions(LoadOp, c_uint);
    };

    pub const StoreOp = enum(c_uint) {
        STORE = C.SDL_STOREOP_STORE,
        DONT_CARE = C.SDL_STOREOP_DONT_CARE,
        RESOLVE = C.SDL_STOREOP_RESOLVE,
        RESOLVE_AND_STORE = C.SDL_STOREOP_RESOLVE_AND_STORE,

        usingnamespace c_enum_conversions(StoreOp, c_uint);
    };

    pub const IndexTypeSize = enum(c_uint) {
        U16 = C.SDL_INDEXELEMENTSIZE_16BIT,
        U32 = C.SDL_INDEXELEMENTSIZE_32BIT,

        usingnamespace c_enum_conversions(IndexTypeSize, C.SDL_GPUIndexElementSize);
    };

    pub const TextureFormat = enum(c_uint) {
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

        usingnamespace c_enum_conversions(TextureFormat, c_uint);
    };

    pub const TextureUsageFlags = Flags(enum(u32) {
        SAMPLER = C.SDL_TEXTUREUSAGE_SAMPLER,
        COLOR_TARGET = C.SDL_TEXTUREUSAGE_COLOR_TARGET,
        DEPTH_STENCIL_TARGET = C.SDL_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        GRAPHICS_STORAGE_READ = C.SDL_TEXTUREUSAGE_GRAPHICS_STORAGE_READ,
        COMPUTE_STORAGE_READ = C.SDL_TEXTUREUSAGE_COMPUTE_STORAGE_READ,
        COMPUTE_STORAGE_WRITE = C.SDL_TEXTUREUSAGE_COMPUTE_STORAGE_WRITE,
        COMPUTE_STORAGE_SIMULTANEOUS_READ_WRITE = C.SDL_TEXTUREUSAGE_COMPUTE_STORAGE_SIMULTANEOUS_READ_WRITE,
    }, null);

    pub const TextureType = enum(c_uint) {
        _2D = C.SDL_TEXTURETYPE_2D,
        _2D_ARRAY = C.SDL_TEXTURETYPE_2D_ARRAY,
        _3D = C.SDL_TEXTURETYPE_3D,
        CUBE = C.SDL_TEXTURETYPE_CUBE,
        CUBE_ARRAY = C.SDL_TEXTURETYPE_CUBE_ARRAY,

        usingnamespace c_enum_conversions(TextureType, c_uint);
    };

    pub const SampleCount = enum(c_uint) {
        _1 = C.SDL_SAMPLECOUNT_1,
        _2 = C.SDL_SAMPLECOUNT_2,
        _4 = C.SDL_SAMPLECOUNT_4,
        _8 = C.SDL_SAMPLECOUNT_8,

        usingnamespace c_enum_conversions(SampleCount, c_uint);
    };

    pub const CubeMapFace = enum(c_uint) {
        POSITIVE_X = C.SDL_CUBEMAPFACE_POSITIVEX,
        NEGATIVE_X = C.SDL_CUBEMAPFACE_NEGATIVEX,
        POSITIVE_Y = C.SDL_CUBEMAPFACE_POSITIVEY,
        NEGATIVE_Y = C.SDL_CUBEMAPFACE_NEGATIVEY,
        POSITIVE_Z = C.SDL_CUBEMAPFACE_POSITIVEZ,
        NEGATIVE_Z = C.SDL_CUBEMAPFACE_NEGATIVEZ,

        usingnamespace c_enum_conversions(CubeMapFace, c_uint);
    };

    pub const BufferUsageFlags = Flags(enum(u32) {
        VERTEX = C.SDL_BUFFERUSAGE_VERTEX,
        INDEX = C.SDL_BUFFERUSAGE_INDEX,
        INDIRECT = C.SDL_BUFFERUSAGE_INDIRECT,
        GRAPHICS_STORAGE_READ = C.SDL_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
        COMPUTE_STORAGE_READ = C.SDL_BUFFERUSAGE_COMPUTE_STORAGE_READ,
        COMPUTE_STORAGE_WRITE = C.SDL_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
    }, null);

    pub const ShaderFormatFlags = Flags(enum(u32) {
        INVALID = C.SDL_SHADERFORMAT_INVALID,
        PRIVATE = C.SDL_SHADERFORMAT_PRIVATE,
        SPIRV = C.SDL_SHADERFORMAT_SPIRV,
        DXBC = C.SDL_SHADERFORMAT_DXBC,
        DXIL = C.SDL_SHADERFORMAT_DXIL,
        MSL = C.SDL_SHADERFORMAT_MSL,
        METALLIB = C.SDL_SHADERFORMAT_METALLIB,
    }, null);

    pub const ColorComponentFlags = Flags(enum(u8) {
        R = C.SDL_COLORCOMPONENT_R,
        G = C.SDL_COLORCOMPONENT_G,
        B = C.SDL_COLORCOMPONENT_B,
        A = C.SDL_COLORCOMPONENT_A,
    }, null);
};
