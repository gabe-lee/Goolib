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
const log = std.log;
const mem = std.mem;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

pub fn num_cast(from: anytype, comptime TO: type) TO {
    const FROM = @TypeOf(from);
    const FI = @typeInfo(FROM);
    const TI = @typeInfo(TO);
    const FROM_INT: u8 = 0b0000;
    const FROM_FLOAT: u8 = 0b0001;
    const TO_INT: u8 = 0b000;
    const TO_FLOAT: u8 = 0b010;
    const TO_ENUM: u8 = 0b100;
    const TO_BOOL: u8 = 0b110;
    const from_kind: u8 = comptime switch (FI) {
        .int, .comptime_int, .@"enum", .bool => FROM_INT,
        .float, .comptime_float => FROM_FLOAT,
        else => assert_with_reason(false, @src(), "`from` type must be an integer, float, enum, or bool, got type `{s}`", .{@typeName(FROM)}),
    };
    const cast_from = comptime switch (FI) {
        .int, .comptime_int, .float, .comptime_float => from,
        .@"enum" => @intFromEnum(from),
        .bool => @intFromBool(from),
        else => unreachable,
    };
    const to_kind: u8 = switch (FI) {
        .int, .comptime_int => TO_INT,
        .float, .comptime_float => TO_FLOAT,
        .@"enum" => TO_ENUM,
        .bool => TO_BOOL,
        else => assert_with_reason(false, @src(), "`TO` type must be an integer, float, enum, or bool, got type `{s}`", .{@typeName(TO)}),
    };
    const FROM_INT_TO_INT = FROM_INT | TO_INT;
    const FROM_INT_TO_FLOAT = FROM_INT | TO_FLOAT;
    const FROM_INT_TO_BOOL = FROM_INT | TO_BOOL;
    const FROM_INT_TO_ENUM = FROM_INT | TO_BOOL;
    const FROM_FLOAT_TO_INT = FROM_FLOAT | TO_INT;
    const FROM_FLOAT_TO_FLOAT = FROM_FLOAT | TO_FLOAT;
    const FROM_FLOAT_TO_BOOL = FROM_FLOAT | TO_BOOL;
    const FROM_FLOAT_TO_ENUM = FROM_FLOAT | TO_ENUM;
    return switch (from_kind | to_kind) {
        FROM_INT_TO_INT => @intCast(cast_from),
        FROM_INT_TO_FLOAT => @floatFromInt(cast_from),
        FROM_INT_TO_BOOL, FROM_FLOAT_TO_BOOL => cast_from != 0,
        FROM_INT_TO_ENUM => @enumFromInt(@as(TI.@"enum".tag_type, @intCast(cast_from))),
        FROM_FLOAT_TO_INT => @intFromFloat(cast_from),
        FROM_FLOAT_TO_FLOAT => @floatCast(cast_from),
        FROM_FLOAT_TO_ENUM => @enumFromInt(@as(TI.@"enum".tag_type, @intFromFloat(cast_from))),
        else => unreachable,
    };
}

pub inline fn ptr_cast(from: anytype, comptime TO: type) TO {
    const FROM = @TypeOf(from);
    const FI = @typeInfo(FROM);
    const TI = @typeInfo(TO);
    var raw_addr: usize = 0;
    switch (FI) {
        .pointer => |PTR_INFO| switch (PTR_INFO.size) {
            .slice => raw_addr = @intFromPtr(from.ptr),
            else => raw_addr = @intFromPtr(from),
        },
        .optional => |OPT_INFO| {
            if (from == null) {
                raw_addr == 0;
            } else {
                const OPT_CHILD_INFO = @typeInfo(OPT_INFO.child);
                switch (OPT_CHILD_INFO) {
                    .pointer => |CHILD_PTR_INFO| switch (CHILD_PTR_INFO.size) {
                        .slice => raw_addr = @intFromPtr(from.?.ptr),
                        else => raw_addr = @intFromPtr(from.?),
                    },
                    .int => |INT_INFO| {
                        assert_with_reason(INT_INFO.signedness == .unsigned and INT_INFO.bits == @bitSizeOf(usize), @src(), "integers must be unsigned and the exact same size as `usize`", .{});
                        raw_addr = @intCast(from.?);
                    },
                    else => assert_with_reason(false, @src(), "cannot convert from type {s}", .{@typeName(FROM)}),
                }
            }
        },
        .int => |INT_INFO| {
            assert_with_reason(INT_INFO.signedness == .unsigned and INT_INFO.bits == @bitSizeOf(usize), @src(), "integers must be unsigned and the exact same size as `usize`", .{});
            raw_addr = @intCast(from);
        },
        else => assert_with_reason(false, @src(), "cannot convert from type {s}", .{@typeName(FROM)}),
    }
    switch (TI) {
        .pointer => |PTR_INFO| switch (PTR_INFO.size) {
            .slice => {
                assert_with_reason(mem.isAligned(raw_addr, PTR_INFO.alignment), @src(), "address {d} was not aligned to required alignment for type {s} ({d})", .{ raw_addr, @typeName(TO), PTR_INFO.alignment });
                var to: TO = undefined;
                to.ptr = @ptrFromInt(raw_addr);
                to.len = 0;
                return to;
            },
            else => {
                assert_with_reason(mem.isAligned(raw_addr, PTR_INFO.alignment), @src(), "address {d} was not aligned to required alignment for type {s} ({d})", .{ raw_addr, @typeName(TO), PTR_INFO.alignment });
                return @ptrFromInt(raw_addr);
            },
        },
        .optional => |OPT_INFO| {
            if (raw_addr == 0) {
                return null;
            } else {
                const OPT_CHILD_INFO = @typeInfo(OPT_INFO.child);
                switch (OPT_CHILD_INFO) {
                    .pointer => |CHILD_PTR_INFO| switch (CHILD_PTR_INFO.size) {
                        .slice => {
                            assert_with_reason(mem.isAligned(raw_addr, CHILD_PTR_INFO.alignment), @src(), "address {d} was not aligned to required alignment for type {s} ({d})", .{ raw_addr, @typeName(TO), CHILD_PTR_INFO.alignment });
                            var to: TO = undefined;
                            to.ptr = @ptrFromInt(raw_addr);
                            to.len = 0;
                            return to;
                        },
                        else => {
                            assert_with_reason(mem.isAligned(raw_addr, CHILD_PTR_INFO.alignment), @src(), "address {d} was not aligned to required alignment for type {s} ({d})", .{ raw_addr, @typeName(TO), CHILD_PTR_INFO.alignment });
                            return @ptrFromInt(raw_addr);
                        },
                    },
                    .int => |INT_INFO| {
                        assert_with_reason(INT_INFO.signedness == .unsigned and INT_INFO.bits == @bitSizeOf(usize), @src(), "integers must be unsigned and the exact same size as `usize`", .{});
                        return @intCast(raw_addr);
                    },
                    else => assert_with_reason(false, @src(), "cannot convert into type {s}", .{@typeName(TO)}),
                }
            }
        },
        .int => |INT_INFO| {
            assert_with_reason(INT_INFO.signedness == .unsigned and INT_INFO.bits == @bitSizeOf(usize), @src(), "integers must be unsigned and the exact same size as `usize`", .{});
            return @intCast(raw_addr);
        },
        else => assert_with_reason(false, @src(), "cannot convert into type {s}", .{@typeName(TO)}),
    }
    unreachable;
}
