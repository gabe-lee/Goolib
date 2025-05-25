//! //TODO Documentation
//! #### License: Zlib

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
const log = std.log;

pub inline fn to(comptime T: type, val: anytype) T {
    const V: type = @TypeOf(val);
    switch (@typeInfo(T)) {
        .comptime_float, .float => switch (@typeInfo(V)) {
            .comptime_float, .float => return @floatCast(val),
            .comptime_int, .int => return @floatFromInt(val),
            .@"enum" => return @floatFromInt(@intFromEnum(val)),
            .bool => return @floatFromInt(@intFromBool(val)),
            else => @compileError("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T)),
        },
        .comptime_int, .int => switch (@typeInfo(V)) {
            .comptime_float, .float => return @intFromFloat(val),
            .comptime_int, .int => return @intCast(val),
            .@"enum" => return @intCast(@intFromEnum(val)),
            .bool => return @intCast(@intFromBool(val)),
            .pointer => |ptr_info| if (ptr_info.size == .slice) @as(T, @intCast(@intFromPtr(val.ptr))) else @as(T, @intCast(@intFromPtr(val))),
            else => @compileError("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T)),
        },
        .bool => switch (@typeInfo(V)) {
            .comptime_float, .float, .comptime_int, .int => val != 0,
            .@"enum" => return @intFromEnum(val) != 0,
            .pointer => |ptr_info| if (ptr_info.size == .slice) val.ptr != null else val != null,
            .bool => return val,
            else => @compileError("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T)),
        },
        .pointer => |out_ptr_info| switch (@typeInfo(V)) {
            .comptime_int, .int => make_ptr: {
                if (out_ptr_info.size == .slice) @compileError("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T));
                if (!out_ptr_info.is_allowzero and val == 0) @panic("invalid cast: " ++ @typeName(V) ++ " == 0 to " ++ @typeName(T));
                break :make_ptr @as(T, @ptrFromInt(@as(usize, @intCast(val))));
            },
            .bool => make_ptr: {
                if (val == true) @panic("invalid cast: " ++ @typeName(V) ++ " == true to " ++ @typeName(T));
                if (!out_ptr_info.is_allowzero and val == false) @panic("invalid cast: " ++ @typeName(V) ++ " == false to " ++ @typeName(T) ++ ": ptr cannot be null");
                if (out_ptr_info.size == .slice) {
                    var result: T = undefined;
                    result.ptr = null;
                    result.len = 0;
                    break :make_ptr result;
                }
                break :make_ptr null;
            },
            .pointer => |in_ptr_info| make_ptr: {
                if (out_ptr_info.size == .slice and in_ptr_info.size != .slice) @compileError("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T));
                if (!out_ptr_info.is_allowzero and in_ptr_info.is_allowzero and val == null) @panic("invalid cast: " ++ @typeName(V) ++ " == null to " ++ @typeName(T));
                if (out_ptr_info.size == .slice and in_ptr_info.size == .slice) {
                    const byte_len = val.len * @sizeOf(in_ptr_info.child);
                    const t_len = byte_len / @sizeOf(out_ptr_info.child);
                    if (out_ptr_info.sentinel_ptr) |out_sent| {
                        if (in_ptr_info.sentinel_ptr != null and in_ptr_info.child == out_ptr_info.child) {
                            const out_sent_val: *const out_ptr_info.child = @ptrCast(@alignCast(out_sent));
                            const in_sent_val: *const in_ptr_info.child = @ptrCast(@alignCast(in_ptr_info.sentinel_ptr.?));
                            if (in_sent_val.* != out_sent_val.*) @panic("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T) ++ " (invalid sentinel after conversion)");
                        } else {
                            const cast_ptr_no_sent: [*]const out_ptr_info.child = @ptrCast(@alignCast(val.ptr));
                            const sent_val: *const out_ptr_info.child = @ptrCast(@alignCast(out_sent));
                            if (cast_ptr_no_sent[t_len] != sent_val.*) @panic("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T) ++ " (invalid sentinel after conversion)");
                        }
                    }
                    var result: T = undefined;
                    result.ptr = @ptrCast(@alignCast(val.ptr));
                    result.len = t_len;
                    break :make_ptr result;
                }
                if (build.mode == .Debug or build.mode == .ReleaseSafe) {
                    if (out_ptr_info.sentinel_ptr) |out_sent| {
                        if (in_ptr_info.sentinel_ptr != null and in_ptr_info.child == out_ptr_info.child) {
                            const out_sent_val: *const out_ptr_info.child = @ptrCast(@alignCast(out_sent));
                            const in_sent_val: *const in_ptr_info.child = @ptrCast(@alignCast(in_ptr_info.sentinel_ptr.?));
                            if (in_sent_val.* != out_sent_val.*) @panic("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T) ++ " (invalid sentinel after conversion)");
                        } else {
                            const cast_ptr_no_sent: [*]const out_ptr_info.child = @ptrCast(@alignCast(val.ptr));
                            const sent_val: *const out_ptr_info.child = @ptrCast(@alignCast(out_sent));
                            var i: usize = 0;
                            find_sent: while (true) : (i += 1) {
                                if (cast_ptr_no_sent[i] == sent_val.*) break :find_sent;
                            }
                        }
                    }
                }
                break :make_ptr @as(T, @ptrCast(@alignCast(val)));
            },
            else => @compileError("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T)),
        },
        .@"enum" => |e_info| switch (@typeInfo(V)) {
            .comptime_int, .int => @as(T, @enumFromInt(@as(e_info.tag_type, @intCast(val)))),
            .comptime_float, .float => @as(T, @enumFromInt(@as(e_info.tag_type, @intFromFloat(val)))),
            .bool => @as(T, @enumFromInt(@as(e_info.tag_type, @intCast(@intFromBool(val))))),
            .@"enum" => @as(T, @enumFromInt(@as(e_info.tag_type, @intCast(@intFromEnum(val))))),
            else => @compileError("invalid cast: " ++ @typeName(V) ++ " to " ++ @typeName(T)),
        },
        else => @as(T, @bitCast(val)),
    }
}
