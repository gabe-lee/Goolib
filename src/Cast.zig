//! //TODO Documentation
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
const log = std.log;
const mem = std.mem;
const Allocator = std.mem.Allocator;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Types = Root.Types;
const Utils = Root.Utils;
const List = Root.IList.List;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

pub inline fn bit_cast(from: anytype, comptime TO: type) TO {
    return @as(TO, @bitCast(from));
}

pub fn real_cast(val: anytype) Utils.real_type(@TypeOf(val)) {
    return num_cast(val, Utils.real_type(@TypeOf(val)));
}

pub fn num_cast(from: anytype, comptime TO: type) TO {
    const FROM = @TypeOf(from);
    const FI = @typeInfo(FROM);
    const TI = @typeInfo(TO);
    // zig fmt: off
    const FROM_INT: comptime_int       = 0b0000_00;
    const FROM_FLOAT: comptime_int     = 0b0000_01;
    const FROM_INT_VEC: comptime_int   = 0b0000_10;
    const FROM_FLOAT_VEC: comptime_int = 0b0000_11;
    const TO_INT: comptime_int         = 0b0000_00;
    const TO_FLOAT: comptime_int       = 0b0001_00;
    const TO_ENUM: comptime_int        = 0b0010_00;
    const TO_BOOL: comptime_int        = 0b0011_00;
    const TO_PTR: comptime_int         = 0b0100_00;
    const TO_INT_VEC: comptime_int     = 0b0101_00;
    const TO_FLOAT_VEC: comptime_int   = 0b0110_00;
    const TO_ENUM_VEC: comptime_int    = 0b0111_00;
    const TO_BOOL_VEC: comptime_int    = 0b1000_00;
    const TO_PTR_VEC: comptime_int     = 0b1001_00;
    // zig fmt: on
    comptime var LEN_IN: comptime_int = 1;
    comptime var LEN_OUT: comptime_int = 1;
    const from_kind: comptime_int = comptime switch (FI) {
        .int, .comptime_int, .@"enum", .bool, .pointer => FROM_INT,
        .float, .comptime_float => FROM_FLOAT,
        .vector => |VI| get: {
            LEN_IN = VI.len;
            break :get switch (@typeInfo(VI.child)) {
                .int, .comptime_int, .@"enum", .bool, .pointer => FROM_INT_VEC,
                .float, .comptime_float => FROM_FLOAT_VEC,
                else => assert_unreachable(@src(), "`from` type must be an integer, float, enum, bool, *T, or [*]T, or a @Vector(T, N) of any of the previous, got type `{s}`", .{@typeName(FROM)}),
            };
        },
        else => assert_unreachable(@src(), "`from` type must be an integer, float, enum, bool, *T, or [*]T, or a @Vector(T, N) of any of the previous, got type `{s}`", .{@typeName(FROM)}),
    };
    const cast_from = switch (FI) {
        .int, .comptime_int, .float, .comptime_float => from,
        .@"enum" => @intFromEnum(from),
        .bool => @intFromBool(from),
        .vector => |VI| get: {
            break :get switch (@typeInfo(VI.child)) {
                .int, .comptime_int, .float, .comptime_float => from,
                .@"enum" => |EI| @as(@Vector(VI.len, EI.tag_type), @bitCast(from)),
                .bool => @as(@Vector(VI.len, u1), @bitCast(from)),
                .pointer => |PI| get_addr: {
                    switch (PI.size) {
                        .c, .one, .many => break :get_addr @as(@Vector(VI.len, usize), @bitCast(from)),
                        .slice => {
                            var out: @Vector(VI.len, usize) = undefined;
                            inline for (0..VI.len) |i| {
                                out[i] = from[i].ptr;
                            }
                            break :get_addr out;
                        },
                    }
                },
                else => assert_unreachable(@src(), "`from` type must be an integer, float, enum, bool, *T, or [*]T, or a @Vector(T, N) of any of the previous, got type `{s}`", .{@typeName(FROM)}),
            };
        },
        .pointer => get_addr: {
            switch (FI.pointer.size) {
                .c, .one, .many => break :get_addr @intFromPtr(from),
                .slice => break :get_addr @intFromPtr(from.ptr),
            }
        },
        else => unreachable,
    };
    const CAST_FROM = @TypeOf(cast_from);
    const to_kind: comptime_int = switch (TI) {
        .int, .comptime_int => TO_INT,
        .float, .comptime_float => TO_FLOAT,
        .@"enum" => TO_ENUM,
        .bool => TO_BOOL,
        .pointer => check: {
            assert_with_reason(Types.pointer_is_single_many_or_c(TO), @src(), "`TO` type must be an integer, float, enum, bool, *T, [*]T, [*c]T, or a @Vector(N, T) of any of the previous, got type `{s}`", .{@typeName(TO)});
            break :check TO_PTR;
        },
        .vector => |VI| get: {
            LEN_OUT = VI.len;
            break :get switch (@typeInfo(VI.child)) {
                .int, .comptime_int => TO_INT_VEC,
                .float, .comptime_float => TO_FLOAT_VEC,
                .@"enum" => TO_ENUM_VEC,
                .bool => TO_BOOL_VEC,
                .pointer => |PI| check: {
                    assert_with_reason(Types.pointer_is_single_many_or_c(PI.child), @src(), "`TO` type must be an integer, float, enum, bool, *T, [*]T, [*c]T, or a @Vector(N, T) of any of the previous, got type `{s}`", .{@typeName(TO)});
                    break :check TO_PTR_VEC;
                },
                else => assert_unreachable(@src(), "`TO` type must be an integer, float, enum, bool, *T, [*]T, [*c]T, or a @Vector(N, T) of any of the previous, got type `{s}`", .{@typeName(TO)}),
            };
        },
        else => assert_unreachable(@src(), "`TO` type must be an integer, float, enum, bool, *T, [*]T, [*c]T, or a @Vector(N, T) of any of the previous, got type `{s}`", .{@typeName(TO)}),
    };
    assert_with_reason(LEN_IN == 1 or LEN_IN == LEN_OUT, @src(), "cannot convert from a vector to a scalar, or between two vectors of different lengths, got `{s}` => `{s}`", .{ @typeName(FROM), @typeName(TO) });
    const branch = comptime calc: {
        break :calc from_kind | to_kind;
    };
    // 40 total cases (4 input (after cast) x 10 output)
    // 10 invalid cases (vector to vector of different len, or vector to scalar)
    return switch (branch) {
        // TO_BOOL cases (8 total, 6 valid, 2 invalid, 32 remaining)
        FROM_INT | TO_BOOL, FROM_FLOAT | TO_BOOL => cast_from != 0,
        FROM_INT | TO_BOOL_VEC, FROM_FLOAT | TO_BOOL_VEC => @splat(cast_from != 0),
        FROM_INT_VEC | TO_BOOL_VEC, FROM_FLOAT_VEC | TO_BOOL_VEC => cast_from != @as(@Vector(CAST_FROM.len, CAST_FROM), @splat(@as(CAST_FROM, 0))),
        // FROM_INT cases (16 total, 12 valid, 4 invalid, 16 remainig)
        FROM_INT | TO_INT, FROM_INT_VEC | TO_INT_VEC => @intCast(cast_from),
        FROM_INT | TO_INT_VEC => @splat(@intCast(cast_from)),
        FROM_INT | TO_FLOAT, FROM_INT_VEC | TO_FLOAT_VEC => @floatFromInt(cast_from),
        FROM_INT | TO_FLOAT_VEC => @splat(@floatFromInt(cast_from)),
        FROM_INT | TO_ENUM => @enumFromInt(cast_from),
        FROM_INT_VEC | TO_ENUM_VEC => check: {
            if (Assert.should_assert()) {
                var out: TO = undefined;
                inline for (0..cast_from.len) |i| {
                    out[i] = @enumFromInt(cast_from[i]);
                }
                break :check out;
            } else {
                const INT_TYPE = @typeInfo(@typeInfo(TO).vector.child).@"enum".tag_type;
                const INTERMEDIATE = @Vector(TO.len, INT_TYPE);
                const intermediate: INTERMEDIATE = @intCast(cast_from);
                break :check @as(TO, @bitCast(intermediate));
            }
        },
        FROM_INT | TO_ENUM_VEC => @splat(@enumFromInt(cast_from)),
        FROM_INT | TO_PTR => @ptrFromInt(cast_from),
        FROM_INT_VEC | TO_PTR_VEC => make: {
            if (Assert.should_assert()) {
                var out: TO = undefined;
                inline for (0..cast_from.len) |i| {
                    out[i] = @ptrFromInt(cast_from[i]);
                }
                break :make out;
            } else {
                const INTERMEDIATE = @Vector(TO.len, usize);
                const intermediate: INTERMEDIATE = @intCast(cast_from);
                break :make @as(TO, @bitCast(intermediate));
            }
        },
        FROM_INT | TO_PTR_VEC => @splat(@ptrFromInt(cast_from)),
        // FROM_FLOAT cases (16 total, 12 valid, 4 invalid, 0 remainig)
        FROM_FLOAT | TO_INT, FROM_FLOAT_VEC | TO_INT_VEC => @intFromFloat(cast_from),
        FROM_FLOAT | TO_INT_VEC => @splat(@intFromFloat(cast_from)),
        FROM_FLOAT | TO_FLOAT, FROM_FLOAT_VEC | TO_FLOAT_VEC => @floatCast(cast_from),
        FROM_FLOAT | TO_FLOAT_VEC => @splat(@floatCast(cast_from)),
        FROM_FLOAT | TO_ENUM => make: {
            const INT_TYPE = @typeInfo(TO).@"enum".tag_type;
            break :make @enumFromInt(@as(INT_TYPE, @intFromFloat(cast_from)));
        },
        FROM_FLOAT_VEC | TO_ENUM_VEC => make: {
            const INT_TYPE = @typeInfo(@typeInfo(TO).vector.child).@"enum".tag_type;
            if (Assert.should_assert()) {
                var out: TO = undefined;
                inline for (0..cast_from.len) |i| {
                    out[i] = @enumFromInt(@as(INT_TYPE, @intFromFloat(cast_from[i])));
                }
                break :make out;
            } else {
                const INTERMEDIATE = @Vector(TO.len, INT_TYPE);
                const intermediate: INTERMEDIATE = @intFromFloat(cast_from);
                break :make @as(TO, @bitCast(intermediate));
            }
        },
        FROM_FLOAT | TO_ENUM_VEC => make: {
            const INT_TYPE = @typeInfo(@typeInfo(TO).vector.child).@"enum".tag_type;
            break :make @splat(@enumFromInt(@as(INT_TYPE, @intFromFloat(cast_from))));
        },
        FROM_FLOAT | TO_PTR => @ptrFromInt(@as(usize, @intFromFloat(cast_from))),
        FROM_FLOAT_VEC | TO_PTR_VEC => make: {
            if (Assert.should_assert()) {
                var out: TO = undefined;
                inline for (0..cast_from.len) |i| {
                    out[i] = @ptrFromInt(@as(usize, @intFromFloat(cast_from[i])));
                }
                break :make out;
            } else {
                const INTERMEDIATE = @Vector(TO.len, usize);
                const intermediate: INTERMEDIATE = @intFromFloat(cast_from);
                break :make @as(TO, @bitCast(intermediate));
            }
        },
        FROM_FLOAT | TO_PTR_VEC => @splat(@ptrFromInt(@as(usize, @intFromFloat(cast_from)))),
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

pub fn SameTypeSliceSameProps(comptime POINTER_OR_SLICE: type) type {
    const INFO = @typeInfo(POINTER_OR_SLICE);
    assert_with_reason(INFO == .pointer, @src(), "type of `POINTER_OR_SLICE` must be a pointer type, got type `{s}`", .{@typeName(POINTER_OR_SLICE)});
    const PTR = INFO.pointer;
    return @Type(.{
        .pointer = .{
            .size = .slice,
            .is_const = PTR.is_const,
            .is_volatile = PTR.is_volatile,
            .is_allowzero = PTR.is_allowzero,
            .alignment = PTR.alignment,
            .address_space = PTR.address_space,
            .child = PTR.child,
            .sentinel_ptr = PTR.sentinel_ptr,
        },
    });
}

pub fn TypeSliceSameProps(comptime POINTER_OR_SLICE: type, comptime NEW_TYPE: type) type {
    const INFO = @typeInfo(POINTER_OR_SLICE);
    assert_with_reason(INFO == .pointer, @src(), "type of `POINTER_OR_SLICE` must be a pointer type, got type `{s}`", .{@typeName(POINTER_OR_SLICE)});
    const PTR = INFO.pointer;
    return @Type(.{
        .pointer = .{
            .size = .slice,
            .is_const = PTR.is_const,
            .is_volatile = PTR.is_volatile,
            .is_allowzero = PTR.is_allowzero,
            .alignment = PTR.alignment,
            .address_space = PTR.address_space,
            .child = NEW_TYPE,
            .sentinel_ptr = if (PTR.child == NEW_TYPE) PTR.sentinel_ptr else null,
        },
    });
}

pub fn many_item_with_sentinel_to_slice(many_item_ptr_with_sentinel: anytype) SameTypeSliceSameProps(@TypeOf(many_item_ptr_with_sentinel)) {
    const MANY_ITEM_WITH_SENT = @TypeOf(many_item_ptr_with_sentinel);
    const INFO = @typeInfo(MANY_ITEM_WITH_SENT);
    assert_with_reason(INFO == .pointer and INFO.pointer.size == .many and INFO.pointer.sentinel_ptr != null, @src(), "type of `many_item_ptr_with_sentinel` must be a many-item pointer type with a sentinel, got type `{s}`", .{@typeName(MANY_ITEM_WITH_SENT)});
    const PTR = INFO.pointer;
    const SENTINEL = PTR.sentinel();
    var i: usize = 0;
    while (true) {
        if (many_item_ptr_with_sentinel[i] == SENTINEL) break;
        i += 1;
    }
    return @ptrCast(many_item_ptr_with_sentinel[0..i]);
}

pub fn ByteSliceSameProps(comptime POINTER_OR_SLICE: type) type {
    const INFO = @typeInfo(POINTER_OR_SLICE);
    assert_with_reason(INFO == .pointer, @src(), "type of `POINTER_OR_SLICE` must be a pointer type, got type `{s}`", .{@typeName(POINTER_OR_SLICE)});
    const PTR = INFO.pointer;
    return @Type(.{
        .pointer = .{
            .size = .slice,
            .is_const = PTR.is_const,
            .is_volatile = PTR.is_volatile,
            .is_allowzero = PTR.is_allowzero,
            .alignment = PTR.alignment,
            .address_space = PTR.address_space,
            .child = u8,
            .sentinel_ptr = if (PTR.child == u8) PTR.sentinel_ptr else null,
        },
    });
}
pub fn ByteSliceSamePropsAlign1(comptime POINTER_OR_SLICE: type) type {
    const INFO = @typeInfo(POINTER_OR_SLICE);
    assert_with_reason(INFO == .pointer, @src(), "type of `POINTER_OR_SLICE` must be a pointer type, got type `{s}`", .{@typeName(POINTER_OR_SLICE)});
    const PTR = INFO.pointer;
    return @Type(.{
        .pointer = .{
            .size = .slice,
            .is_const = PTR.is_const,
            .is_volatile = PTR.is_volatile,
            .is_allowzero = PTR.is_allowzero,
            .alignment = 1,
            .address_space = PTR.address_space,
            .child = u8,
            .sentinel_ptr = if (PTR.child == u8) PTR.sentinel_ptr else null,
        },
    });
}

pub fn bytes_cast(pointer_or_slice: anytype) ByteSliceSameProps(@TypeOf(pointer_or_slice)) {
    const POINTER_OR_SLICE = @TypeOf(pointer_or_slice);
    const INFO = @typeInfo(POINTER_OR_SLICE);
    assert_with_reason(INFO == .pointer, @src(), "type of `pointer_or_slice` must be a pointer type, got type `{s}`", .{@typeName(POINTER_OR_SLICE)});
    const PTR = INFO.pointer;

    // a slice of zero-bit values always occupies zero bytes
    if (@sizeOf(PTR.child) == 0) return &[0]u8{};

    const BYTE_SLICE = ByteSliceSameProps(@TypeOf(pointer_or_slice));
    const CHILD = PTR.child;
    var len: usize = if (PTR.size == .slice) pointer_or_slice.len else 1;
    switch (PTR.size) {
        .slice => {
            if (@intFromPtr(pointer_or_slice.ptr) == 0 or (pointer_or_slice.len == 0 and PTR.sentinel_ptr == null)) return &[0]u8{};
        },
        .many => {
            if (@intFromPtr(pointer_or_slice) == 0) return &[0]u8{};
            assert_with_reason(PTR.sentinel_ptr != null, @src(), "cannot convert an unbound many-item pointer with no sentinel value to a byte slice, got type `{s}`", .{@typeName(POINTER_OR_SLICE)});
            const as_slice = many_item_with_sentinel_to_slice(pointer_or_slice);
            len = as_slice.len;
        },
        else => {
            if (@intFromPtr(pointer_or_slice) == 0) return &[0]u8{};
        },
    }
    const total_len = len * @sizeOf(CHILD);

    return @as(BYTE_SLICE, @ptrCast(pointer_or_slice))[0..total_len];
}

pub fn element_type(comptime POINTER_OR_SLICE: type) type {
    const INFO = @typeInfo(POINTER_OR_SLICE);
    assert_with_reason(INFO == .pointer, @src(), "type of `POINTER_OR_SLICE` must be a pointer type, got type `{s}`", .{@typeName(POINTER_OR_SLICE)});
    const PTR = INFO.pointer;
    return PTR.child;
}

pub fn any_ptr_to_many_item_ptr(ptr_or_slice: anytype) [*]@typeInfo(@TypeOf(ptr_or_slice)).pointer.child {
    const T = @TypeOf(ptr_or_slice);
    const ptr = switch (@typeInfo(T)) {
        .pointer => |PTR| switch (PTR.size) {
            .one, .c, .many => ptr_or_slice,
            .slice => ptr_or_slice.ptr,
        },
        else => assert_unreachable(@src(), "`ptr_or_slice` must be a pointer or slice type, got type `{s}`", .{@typeName(T)}),
    };
    return @ptrCast(ptr);
}
