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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const ANSI = Root.ANSI;
const BinarySearch = Root.BinarySearch;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

pub fn raw_ptr_cast_const(ptr_or_slice: anytype) [*]const u8 {
    const PTR = @TypeOf(ptr_or_slice);
    const P_INFO = @typeInfo(PTR);
    assert_with_reason(P_INFO == .pointer, @inComptime(), @src(), @This(), "input `ptr` must be a pointer type");
    const PTR_INFO = P_INFO.pointer;
    return if (PTR_INFO.size == .slice) @ptrCast(@alignCast(ptr_or_slice.ptr)) else @ptrCast(@alignCast(ptr_or_slice));
}

pub fn raw_ptr_cast(ptr_or_slice: anytype) [*]u8 {
    const PTR = @TypeOf(ptr_or_slice);
    const P_INFO = @typeInfo(PTR);
    assert_with_reason(P_INFO == .pointer, @inComptime(), @src(), @This(), "input `ptr` must be a pointer type");
    const PTR_INFO = P_INFO.pointer;
    return if (PTR_INFO.size == .slice) @ptrCast(@alignCast(ptr_or_slice.ptr)) else @ptrCast(@alignCast(ptr_or_slice));
}

pub fn raw_slice_cast_const(slice_or_many_with_sentinel: anytype) []const u8 {
    const SLICE = @TypeOf(slice_or_many_with_sentinel);
    const S_INFO = @typeInfo(SLICE);
    assert_with_reason(S_INFO == .pointer and (S_INFO.pointer.size == .slice or (S_INFO.pointer.size == .many and S_INFO.pointer.sentinel_ptr != null)), @inComptime(), @src(), @This(), "input `slice` must be a slice or many-item-pointer with a sentinel");
    const SLICE_INFO = S_INFO.pointer;
    const CHILD = SLICE_INFO.child;
    const SIZE = @sizeOf(CHILD);
    const slice_with_len: []const CHILD = if (SLICE_INFO.size == .many) build: {
        const sent: *const CHILD = @ptrCast(@alignCast(SLICE_INFO.sentinel_ptr.?));
        break :build make_const_slice_from_sentinel_ptr(CHILD, sent.*, slice_or_many_with_sentinel);
    } else slice_or_many_with_sentinel;
    const ptr: [*]const u8 = @ptrCast(@alignCast(slice_with_len.ptr));
    const len: usize = slice_or_many_with_sentinel.len * SIZE;
    return ptr[0..len];
}

pub fn raw_slice_cast(slice_or_many_with_sentinel: anytype) []u8 {
    const SLICE = @TypeOf(slice_or_many_with_sentinel);
    const S_INFO = @typeInfo(SLICE);
    assert_with_reason(S_INFO == .pointer and (S_INFO.pointer.size == .slice or (S_INFO.pointer.size == .many and S_INFO.pointer.sentinel_ptr != null)), @inComptime(), @src(), @This(), "input `slice` must be a slice or many-item-pointer with a sentinel");
    const SLICE_INFO = S_INFO.pointer;
    const CHILD = SLICE_INFO.child;
    const SIZE = @sizeOf(CHILD);
    const slice_with_len: []CHILD = if (SLICE_INFO.size == .many) build: {
        const sent: *const CHILD = @ptrCast(@alignCast(SLICE_INFO.sentinel_ptr.?));
        break :build make_slice_from_sentinel_ptr(CHILD, sent.*, slice_or_many_with_sentinel);
    } else slice_or_many_with_sentinel;
    const ptr: [*]u8 = @ptrCast(@alignCast(slice_with_len.ptr));
    const len: usize = slice_or_many_with_sentinel.len * SIZE;
    return ptr[0..len];
}

pub fn all_enum_values_start_from_zero_with_no_gaps(comptime ENUM: type) bool {
    const min = enum_min_value(ENUM);
    if (min != 0) return false;
    const max = enum_max_value(ENUM);
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), @This(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    const range = (max - min) + 1;
    return (range - E_INFO.fields.len) == 0;
}

pub fn count_enum_gaps_between_raw_min_and_enum_max_val(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), @This(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    if (!E_INFO.is_exhaustive) return 0;
    const raw_smallest = std.math.minInt(E_INFO.tag_type);
    const largest = enum_max_value(ENUM);
    const range = largest - raw_smallest;
    return @intCast(range - E_INFO.fields.len);
}

pub fn count_enum_gaps_between_zero_and_enum_max_val(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), @This(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    if (!E_INFO.is_exhaustive) return 0;
    const largest = enum_max_value(ENUM);
    return @intCast(largest - E_INFO.fields.len);
}

pub fn count_enum_gaps_between_enum_min_and_enum_max_val(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), @This(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    if (!E_INFO.is_exhaustive) return 0;
    const largest = enum_max_value(ENUM);
    const smallest = enum_min_value(ENUM);
    const range = largest - smallest;
    return @intCast(range - E_INFO.fields.len);
}

pub fn enum_min_value(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), @This(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    const raw_largest: comptime_int = std.math.maxInt(E_INFO.tag_type);
    var smallest: comptime_int = raw_largest;
    for (E_INFO.fields) |field| {
        if (field.value < smallest) smallest = field.value;
    }
    return smallest;
}
pub fn enum_max_value(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), @This(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    const raw_smallest: comptime_int = std.math.minInt(E_INFO.tag_type);
    var largest: comptime_int = raw_smallest;
    for (E_INFO.fields) |field| {
        if (field.value > largest) largest = field.value;
    }
    return largest;
}

pub fn enum_max_field_count(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), @This(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    if (!E_INFO.is_exhaustive) return @intCast(std.math.maxInt(E_INFO.tag_type));
    return @intCast(E_INFO.fields.len);
}

pub fn enum_defined_field_count(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), @This(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    return @intCast(E_INFO.fields.len);
}

pub fn ptr_with_sentinel_has_min_len(comptime T: type, comptime S: T, ptr: [*:S]const T, len: usize) bool {
    var i: usize = 0;
    while (ptr[i] != S) : (i += 1) {
        if (i >= len) return true;
    }
    return false;
}

pub inline fn type_is_vector_or_array_with_child_type(comptime T: type, comptime CHILD: type) bool {
    const INFO = @typeInfo(T);
    if (INFO == .array and INFO.array.child == CHILD) return true;
    if (INFO == .vector and INFO.vector.child == CHILD) return true;
    return false;
}

pub inline fn type_is_pointer_with_child_type(comptime T: type, comptime CHILD: type) bool {
    const INFO = @typeInfo(T);
    return INFO == .pointer and INFO.pointer.child == CHILD;
}

pub inline fn pointer_field_child_type(comptime T: type, comptime field: []const u8) type {
    return @typeInfo(@FieldType(T, field)).pointer.child;
}
pub inline fn pointer_child_type(comptime T: type) type {
    return @typeInfo(T).pointer.child;
}
pub inline fn pointer_type_has_sentinel(comptime T: type) bool {
    return @typeInfo(T).pointer.sentinel_ptr != null;
}
pub inline fn pointer_type_sentinel(comptime T: type) *const @typeInfo(T).pointer.child {
    return @ptrCast(@alignCast(@typeInfo(T).pointer.sentinel_ptr.?));
}
pub inline fn pointer_is_c_pointer(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .c;
}
pub inline fn pointer_might_be_zero(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .c or @typeInfo(T).pointer.is_allowzero;
}
pub inline fn pointer_is_zero(ptr: anytype) bool {
    return @intFromPtr(ptr) == 0;
}
pub inline fn type_has_field_with_type(comptime T: type, comptime field: []const u8, comptime T_FIELD: type) bool {
    return @hasField(T, field) and @FieldType(T, field) == T_FIELD;
}
pub inline fn type_has_field_with_any_pointer_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .pointer;
}
pub inline fn type_has_field_with_any_integer_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .int;
}
pub inline fn type_has_field_with_any_unsigned_integer_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .int and @typeInfo(@FieldType(T, field)).int.signedness == .unsigned;
}
pub inline fn type_has_field_with_any_signed_integer_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .int and @typeInfo(@FieldType(T, field)).int.signedness == .signed;
}
pub inline fn type_has_field_with_any_float_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .float;
}

pub inline fn type_has_decl_with_type(comptime T: type, comptime decl: []const u8, comptime T_DECL: type) bool {
    return @hasDecl(T, decl) and @TypeOf(@field(T, decl)) == T_DECL;
}
pub inline fn type_has_decl_with_any_pointer_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .pointer;
}
pub inline fn type_has_decl_with_any_integer_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .int;
}
pub inline fn type_has_decl_with_any_signed_integer_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .int and @typeInfo(@TypeOf(@field(T, decl))).int.signedness == .signed;
}
pub inline fn type_has_decl_with_any_unsigned_integer_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .int and @typeInfo(@TypeOf(@field(T, decl))).int.signedness == .unsigned;
}
pub inline fn type_has_decl_with_any_float_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .float;
}

pub inline fn type_is_pointer_or_slice(comptime T: type) bool {
    return @typeInfo(T) == .pointer;
}
pub inline fn pointer_is_slice(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .slice;
}
pub inline fn pointer_is_single(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .one;
}
pub inline fn pointer_is_many(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .many;
}
pub inline fn type_is_array_or_vector(comptime T: type) bool {
    return @typeInfo(T) == .array or @typeInfo(T) == .vector;
}
pub inline fn array_or_vector_child_type(comptime T: type) type {
    if (@typeInfo(T) == .array) return @typeInfo(T).array.child;
    return @typeInfo(T).vector.child;
}
pub inline fn pointer_is_mutable(comptime T: type) bool {
    return @typeInfo(T).pointer.is_const == false;
}
pub inline fn pointer_is_immutable(comptime T: type) bool {
    return @typeInfo(T).pointer.is_const == true;
}

pub inline fn type_is_optional(comptime T: type) bool {
    return @typeInfo(T) == .optional;
}
pub inline fn optional_type_child(comptime T: type) type {
    return @typeInfo(T).optional.child;
}

pub inline fn type_is_float(comptime T: type) bool {
    return @typeInfo(T) == .float or @typeInfo(T) == .comptime_float;
}
pub inline fn type_is_int(comptime T: type) bool {
    return @typeInfo(T) == .int or @typeInfo(T) == .comptime_int;
}
pub inline fn type_is_bool(comptime T: type) bool {
    return T == bool;
}
pub inline fn type_is_enum(comptime T: type) bool {
    return @typeInfo(T) == .@"enum";
}

pub fn is_valid_value_for_enum(comptime ENUM_TYPE: type, int_value: anytype) bool {
    const enum_info = @typeInfo(ENUM_TYPE).@"enum";
    if (!enum_info.is_exhaustive) {
        if (std.math.cast(enum_info.tag_type, int_value) == null) return false;
        return true;
    }

    const ordered_values = comptime make: {
        var arr: [enum_info.fields.len]enum_info.tag_type = undefined;
        var len: usize = 0;
        while (len < enum_info.fields.len) : (len += 1) {
            const ins_idx = BinarySearch.simple_binary_search_insert_index(enum_info.tag_type, false, arr[0..len], enum_info.fields[len].value);
            mem.copyBackwards(enum_info.tag_type, arr[ins_idx + 1 .. len + 1], arr[ins_idx..len]);
            arr[ins_idx] = enum_info.fields[len].value;
        }
        break :make arr;
    };

    if (BinarySearch.simple_binary_search(enum_info.tag_type, ordered_values[0..], int_value) == null) return false;
    return true;
}

pub fn make_slice_from_sentinel_ptr(comptime T: type, comptime S: T, ptr: [*:S]T) [:S]T {
    var i: usize = 0;
    while (ptr[i] != S) : (i += 1) {}
    return ptr[0..i :S];
}

pub fn make_const_slice_from_sentinel_ptr(comptime T: type, comptime S: T, ptr: [*:S]const T) [:S]T {
    var i: usize = 0;
    while (ptr[i] != S) : (i += 1) {}
    return ptr[0..i :S];
}

pub fn make_slice_from_sentinel_ptr_max_len(comptime T: type, comptime S: T, ptr: [*:S]T, max_len: usize) [:S]T {
    var i: usize = 0;
    while (ptr[i] != S and i < max_len) : (i += 1) {}
    return ptr[0..i :S];
}

pub fn make_const_slice_from_sentinel_ptr_max_len(comptime T: type, comptime S: T, ptr: [*:S]const T, max_len: usize) [:S]T {
    var i: usize = 0;
    while (ptr[i] != S and i < max_len) : (i += 1) {}
    return ptr[0..i :S];
}

pub fn get_ptr_len(ptr: anytype) usize {
    const T = @TypeOf(ptr);
    const I = @typeInfo(T);
    switch (I) {
        .pointer => |INFO| {
            switch (INFO.size) {
                .slice => {
                    return ptr.len;
                },
                .many => {
                    assert_with_reason(INFO.sentinel_ptr != null, @src(), @This(), "many-item pointers must have sentinel values to find their length", .{});
                    const sent_ptr: *const INFO.child = @ptrCast(@alignCast(INFO.sentinel_ptr.?));
                    const sent = sent_ptr.*;
                    var i: usize = 0;
                    while (ptr[i] != sent) : (i += 1) {}
                    return i;
                },
                else => assert_with_reason(false, @src(), @This(), "only slices or many-item pointers with sentinel values can return their length", .{}),
            }
        },
        else => assert_with_reason(false, @src(), @This(), "`ptr` must be a pointer type, got type {s}", .{@typeName(T)}),
    }
}
pub fn can_get_ptr_len(comptime ptr_type: type) bool {
    const T = ptr_type;
    const I = @typeInfo(T);
    switch (I) {
        .pointer => |INFO| {
            switch (INFO.size) {
                .slice => {
                    return true;
                },
                .many => {
                    return INFO.sentinel_ptr != null;
                },
                else => return false,
            }
        },
        else => return false,
    }
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
                        assert_with_reason(INT_INFO.signedness == .unsigned and INT_INFO.bits == @bitSizeOf(usize), @src(), @This(), "integers must be unsigned and the exact same size as `usize`", .{});
                        raw_addr = @intCast(from.?);
                    },
                    else => assert_with_reason(false, @src(), @This(), "cannot convert from type {s}", .{@typeName(FROM)}),
                }
            }
        },
        .int => |INT_INFO| {
            assert_with_reason(INT_INFO.signedness == .unsigned and INT_INFO.bits == @bitSizeOf(usize), @src(), @This(), "integers must be unsigned and the exact same size as `usize`", .{});
            raw_addr = @intCast(from);
        },
        else => assert_with_reason(false, @src(), @This(), "cannot convert from type {s}", .{@typeName(FROM)}),
    }
    switch (TI) {
        .pointer => |PTR_INFO| switch (PTR_INFO.size) {
            .slice => {
                assert_with_reason(mem.isAligned(raw_addr, PTR_INFO.alignment), @src(), @This(), "address {d} was not aligned to required alignment for type {s} ({d})", .{ raw_addr, @typeName(TO), PTR_INFO.alignment });
                var to: TO = undefined;
                to.ptr = @ptrFromInt(raw_addr);
                to.len = 0;
                return to;
            },
            else => {
                assert_with_reason(mem.isAligned(raw_addr, PTR_INFO.alignment), @src(), @This(), "address {d} was not aligned to required alignment for type {s} ({d})", .{ raw_addr, @typeName(TO), PTR_INFO.alignment });
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
                            assert_with_reason(mem.isAligned(raw_addr, CHILD_PTR_INFO.alignment), @src(), @This(), "address {d} was not aligned to required alignment for type {s} ({d})", .{ raw_addr, @typeName(TO), CHILD_PTR_INFO.alignment });
                            var to: TO = undefined;
                            to.ptr = @ptrFromInt(raw_addr);
                            to.len = 0;
                            return to;
                        },
                        else => {
                            assert_with_reason(mem.isAligned(raw_addr, CHILD_PTR_INFO.alignment), @src(), @This(), "address {d} was not aligned to required alignment for type {s} ({d})", .{ raw_addr, @typeName(TO), CHILD_PTR_INFO.alignment });
                            return @ptrFromInt(raw_addr);
                        },
                    },
                    .int => |INT_INFO| {
                        assert_with_reason(INT_INFO.signedness == .unsigned and INT_INFO.bits == @bitSizeOf(usize), @src(), @This(), "integers must be unsigned and the exact same size as `usize`", .{});
                        return @intCast(raw_addr);
                    },
                    else => assert_with_reason(false, @src(), @This(), "cannot convert into type {s}", .{@typeName(TO)}),
                }
            }
        },
        .int => |INT_INFO| {
            assert_with_reason(INT_INFO.signedness == .unsigned and INT_INFO.bits == @bitSizeOf(usize), @src(), @This(), "integers must be unsigned and the exact same size as `usize`", .{});
            return @intCast(raw_addr);
        },
        else => assert_with_reason(false, @src(), @This(), "cannot convert into type {s}", .{@typeName(TO)}),
    }
    unreachable;
}
