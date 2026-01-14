//! //TODO Documentation
//! #### License: Zlib

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
const Types = Root.Types;
const Cast = Root.Cast;
const Utils = Root.Utils;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

pub fn c_non_opaque_conversions(comptime ZIG_TYPE: type, comptime C_TYPE: type) type {
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

pub fn c_opaque_conversions(comptime ZIG_TYPE: type, comptime C_TYPE: type) type {
    return struct {
        pub fn to_c_ptr(self: *ZIG_TYPE) *C_TYPE {
            return @ptrCast(@alignCast(self));
        }
        pub fn from_c_ptr(c_ptr: *C_TYPE) *ZIG_TYPE {
            return @ptrCast(@alignCast(c_ptr));
        }
    };
}

pub fn c_enum_conversions(comptime ZIG_TYPE: type, comptime C_TYPE: type) type {
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

export fn cutil_cos(val: f64) callconv(.c) f64 {
    return @cos(val);
}
export fn cutil_acos(val: f64) callconv(.c) f64 {
    return std.math.acos(val);
}
export fn cutil_sin(val: f64) callconv(.c) f64 {
    return @sin(val);
}
export fn cutil_asin(val: f64) callconv(.c) f64 {
    return std.math.asin(val);
}
export fn cutil_tan(val: f64) callconv(.c) f64 {
    return @tan(val);
}
export fn cutil_atan(val: f64) callconv(.c) f64 {
    return std.math.atan(val);
}
export fn cutil_fabs(val: f64) callconv(.c) f64 {
    return @abs(val);
}
export fn cutil_floor(val: f64) callconv(.c) f64 {
    return @floor(val);
}
export fn cutil_ceil(val: f64) callconv(.c) f64 {
    return @ceil(val);
}
export fn cutil_ifloor(val: f64) callconv(.c) c_int {
    return @intCast(@floor(val));
}
export fn cutil_iceil(val: f64) callconv(.c) c_int {
    return @intCast(@ceil(val));
}
export fn cutil_sqrt(val: f64) callconv(.c) f64 {
    return @sqrt(val);
}
export fn cutil_pow(val: f64, pow: f64) callconv(.c) f64 {
    return std.math.pow(f64, val, pow);
}
export fn cutil_fmod(numer: f64, denom: f64) callconv(.c) f64 {
    return @mod(numer, denom);
}
export fn cutil_assert(condition: bool) callconv(.c) void {
    Assert.assert_with_reason(condition, null, "C assertion failure", .{});
}
export fn cutil_memcpy(dest: ?*anyopaque, src: ?*const anyopaque, n_bytes: usize) callconv(.c) ?*anyopaque {
    if (dest != null and src != null) {
        const dest_u8: [*]u8 = @ptrCast(dest.?);
        const src_u8: [*]const u8 = @ptrCast(src.?);
        @memcpy(dest_u8[0..n_bytes], src_u8[0..n_bytes]);
    }
    return dest;
}
export fn cutil_memset(dest: ?*anyopaque, val: c_int, n_bytes: usize) callconv(.c) ?*anyopaque {
    if (dest != null) {
        const dest_u8: [*]u8 = @ptrCast(dest.?);
        const val_u8: u8 = @intCast(val);
        @memset(dest_u8[0..n_bytes], val_u8);
    }
    return dest;
}
export fn cutil_strlen(str: ?[*:0]c_char) callconv(.c) usize {
    if (str == null) return 0;
    return std.mem.len(str.?);
}
