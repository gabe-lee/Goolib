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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const ANSI = Root.ANSI;
const BinarySearch = Root.BinarySearch;
const Assert = Root.Assert;
const MathX = Root.Math;
const Utils = Root.Utils;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

pub const fsize = switch (@bitSizeOf(usize)) {
    16 => f16,
    32 => f32,
    64 => f64,
    else => f32,
};

pub fn FloatSizeForMaxIntExact(comptime INT: type) type {
    const MAX: comptime_int = math.maxInt(INT);
    switch (MAX) {
        0...MathX.MAX_EXACT_INTEGER_F16 => f16,
        (MathX.MAX_EXACT_INTEGER_F16 + 1)...MathX.MAX_EXACT_INTEGER_F32 => f32,
        (MathX.MAX_EXACT_INTEGER_F32 + 1)...MathX.MAX_EXACT_INTEGER_F64 => f64,
        (MathX.MAX_EXACT_INTEGER_F64 + 1)...MathX.MAX_EXACT_INTEGER_F128 => f128,
        else => assert_unreachable(@src(), "integer type has a max positive size of {d}, which is outside the range an f128 can exactly represent", .{MAX}),
    }
}

pub fn UnsignedIntegerWithSameSize(comptime T: type) type {
    return switch (@sizeOf(T)) {
        1 => u8,
        2 => u16,
        4 => u32,
        8 => u64,
        16 => u128,
        else => assert_unreachable(@src(), "type `{s}` does not have a native matching integer size, its size is `{d}`", .{ @typeName(T), @sizeOf(T) }),
    };
}

pub fn intcast(val: anytype, comptime T: type) T {
    assert_with_reason(type_is_int(T), @src(), "output type T must be an integer type, got type `{s}`", .{@typeName(T)});
    const V = @TypeOf(val);
    if (type_is_int(V)) {
        return @intCast(val);
    } else if (type_is_float(V)) {
        return @as(T, @intFromFloat(val));
    } else if (type_is_enum(V)) {
        return @as(T, @intCast(@intFromEnum(val)));
    } else if (type_is_bool(V)) {
        return @as(T, @intCast(@intFromBool(val)));
    } else {
        Assert.assert_unreachable(@src(), "cannot cast type `{s}` to an integer", .{@typeName(V)});
    }
}

pub fn floatcast(val: anytype, comptime T: type) T {
    assert_with_reason(type_is_float(T), @src(), "output type T must be a float type, got type `{s}`", .{@typeName(T)});
    const V = @TypeOf(val);
    if (type_is_float(V)) {
        return @floatCast(val);
    } else if (type_is_int(V)) {
        return @as(T, @floatFromInt(val));
    } else if (type_is_enum(V)) {
        return @as(T, @floatFromInt(@intFromEnum(val)));
    } else if (type_is_bool(V)) {
        return @as(T, @floatFromInt(@intFromBool(val)));
    } else {
        Assert.assert_unreachable(@src(), "cannot cast type `{s}` to a float", .{@typeName(V)});
    }
}

pub fn ptr_cast_const(ptr_or_slice: anytype, comptime new_type: type) *const new_type {
    const PTR = @TypeOf(ptr_or_slice);
    const P_INFO = @typeInfo(PTR);
    assert_with_reason(P_INFO == .pointer, @src(), "input `ptr_or_slice` must be a pointer type", .{});
    const PTR_INFO = P_INFO.pointer;
    return switch (PTR_INFO.size) {
        .slice => @ptrCast(@alignCast(ptr_or_slice.ptr)),
        else => @ptrCast(@alignCast(ptr_or_slice)),
    };
}

pub fn ptr_cast(ptr_or_slice: anytype, comptime new_type: type) *new_type {
    const PTR = @TypeOf(ptr_or_slice);
    const P_INFO = @typeInfo(PTR);
    assert_with_reason(P_INFO == .pointer, @src(), "input `ptr_or_slice` must be a pointer type", .{});
    const PTR_INFO = P_INFO.pointer;
    return switch (PTR_INFO.size) {
        .slice => switch (PTR_INFO.is_const) {
            true => @ptrCast(@alignCast(@constCast(ptr_or_slice.ptr))),
            false => @ptrCast(@alignCast(ptr_or_slice.ptr)),
        },
        else => switch (PTR_INFO.is_const) {
            true => @ptrCast(@alignCast(@constCast(ptr_or_slice))),
            false => @ptrCast(@alignCast(ptr_or_slice)),
        },
    };
}

pub fn slice_cast(ptr_or_slice: anytype, comptime T: type, len: usize) []T {
    const PTR = @TypeOf(ptr_or_slice);
    const P_INFO = @typeInfo(PTR);
    assert_with_reason(P_INFO == .pointer, @src(), "input `ptr_or_slice` must be a pointer type", .{});
    const PTR_INFO = P_INFO.pointer;
    const ptr: [*]T = switch (PTR_INFO.size) {
        .slice => switch (PTR_INFO.is_const) {
            true => @ptrCast(@alignCast(@constCast(ptr_or_slice.ptr))),
            false => @ptrCast(@alignCast(ptr_or_slice.ptr)),
        },
        else => switch (PTR_INFO.is_const) {
            true => @ptrCast(@alignCast(@constCast(ptr_or_slice))),
            false => @ptrCast(@alignCast(ptr_or_slice)),
        },
    };
    return ptr[0..len];
}
pub fn slice_cast_implicit_len(ptr_or_slice: anytype, comptime T: type) []T {
    const PTR = @TypeOf(ptr_or_slice);
    const P_INFO = @typeInfo(PTR);
    assert_with_reason(P_INFO == .pointer, @src(), "input `ptr_or_slice` must be a pointer type", .{});
    const PTR_INFO = P_INFO.pointer;
    const ptr: [*]T = switch (PTR_INFO.size) {
        .slice => switch (PTR_INFO.is_const) {
            true => @ptrCast(@alignCast(@constCast(ptr_or_slice.ptr))),
            false => @ptrCast(@alignCast(ptr_or_slice.ptr)),
        },
        else => switch (PTR_INFO.is_const) {
            true => @ptrCast(@alignCast(@constCast(ptr_or_slice))),
            false => @ptrCast(@alignCast(ptr_or_slice)),
        },
    };
    const original_len: usize = switch (PTR_INFO.size) {
        .slice => ptr_or_slice.len,
        else => 1,
    };
    const raw_len = @sizeOf(PTR_INFO.child) * original_len;
    const new_len = raw_len / @sizeOf(T);
    return ptr[0..new_len];
}

pub fn raw_ptr_cast_const(ptr_or_slice: anytype) [*]const u8 {
    const PTR = @TypeOf(ptr_or_slice);
    const P_INFO = @typeInfo(PTR);
    assert_with_reason(P_INFO == .pointer, @src(), "input `ptr_or_slice` must be a pointer type", .{});
    const PTR_INFO = P_INFO.pointer;
    return if (PTR_INFO.size == .slice) @ptrCast(@alignCast(ptr_or_slice.ptr)) else @ptrCast(@alignCast(ptr_or_slice));
}

pub fn raw_ptr_cast(ptr_or_slice: anytype) [*]u8 {
    const PTR = @TypeOf(ptr_or_slice);
    const P_INFO = @typeInfo(PTR);
    assert_with_reason(P_INFO == .pointer, @src(), "input `ptr_or_slice` must be a pointer type", .{});
    const PTR_INFO = P_INFO.pointer;
    return if (PTR_INFO.size == .slice) @ptrCast(@alignCast(ptr_or_slice.ptr)) else @ptrCast(@alignCast(ptr_or_slice));
}

pub fn raw_slice_cast_const(slice_or_many_with_sentinel: anytype) []const u8 {
    const SLICE = @TypeOf(slice_or_many_with_sentinel);
    const S_INFO = @typeInfo(SLICE);
    assert_with_reason(S_INFO == .pointer and (S_INFO.pointer.size == .slice or (S_INFO.pointer.size == .many and S_INFO.pointer.sentinel_ptr != null)), @inComptime(), @src(), "input `slice` must be a slice or many-item-pointer with a sentinel");
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
    assert_with_reason(S_INFO == .pointer and (S_INFO.pointer.size == .slice or (S_INFO.pointer.size == .many and S_INFO.pointer.sentinel_ptr != null)), @inComptime(), @src(), "input `slice` must be a slice or many-item-pointer with a sentinel");
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
    if (@typeInfo(ENUM).@"enum".fields.len == 0) return true;
    const min = enum_min_value(ENUM);
    if (min != 0) return false;
    const max = enum_max_value(ENUM);
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    const range = (max - min) + 1;
    return (range - E_INFO.fields.len) == 0;
}

pub fn count_enum_gaps_between_raw_min_and_enum_max_val(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    if (!E_INFO.is_exhaustive) return 0;
    const raw_smallest = std.math.minInt(E_INFO.tag_type);
    const largest = enum_max_value(ENUM);
    const range = largest - raw_smallest;
    return @intCast(range - E_INFO.fields.len);
}

pub fn count_enum_gaps_between_zero_and_enum_max_val(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    if (!E_INFO.is_exhaustive) return 0;
    const largest = enum_max_value(ENUM);
    return @intCast(largest - E_INFO.fields.len);
}

pub fn count_enum_gaps_between_enum_min_and_enum_max_val(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    if (!E_INFO.is_exhaustive) return 0;
    const largest = enum_max_value(ENUM);
    const smallest = enum_min_value(ENUM);
    const range = largest - smallest;
    return @intCast(range - E_INFO.fields.len);
}

pub fn enum_min_value(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), "input `ENUM` must be an enum type", .{});
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
    assert_with_reason(EI == .@"enum", @src(), "input `ENUM` must be an enum type", .{});
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
    assert_with_reason(EI == .@"enum", @src(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    if (!E_INFO.is_exhaustive) return @intCast(std.math.maxInt(E_INFO.tag_type));
    return @intCast(E_INFO.fields.len);
}

pub fn enum_defined_field_count(comptime ENUM: type) comptime_int {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    return @intCast(E_INFO.fields.len);
}

pub fn enum_is_exhaustive(comptime ENUM: type) bool {
    const EI = @typeInfo(ENUM);
    assert_with_reason(EI == .@"enum", @src(), "input `ENUM` must be an enum type", .{});
    const E_INFO = EI.@"enum";
    return E_INFO.is_exhaustive;
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
pub inline fn type_is_pointer_with_child_int_type(comptime T: type) bool {
    const INFO = @typeInfo(T);
    return INFO == .pointer and @typeInfo(INFO.pointer.child) == .int;
}
pub inline fn type_is_pointer_with_child_unsigned_int_type(comptime T: type) bool {
    const INFO = @typeInfo(T);
    return INFO == .pointer and @typeInfo(INFO.pointer.child) == .int and @typeInfo(INFO.pointer.child).int.signedness == .unsigned;
}
pub inline fn type_is_pointer_with_child_signed_int_type(comptime T: type) bool {
    const INFO = @typeInfo(T);
    return INFO == .pointer and @typeInfo(INFO.pointer.child) == .int and @typeInfo(INFO.pointer.child).int.signedness == .signed;
}
pub inline fn type_is_pointer_with_child_float_type(comptime T: type) bool {
    const INFO = @typeInfo(T);
    return INFO == .pointer and @typeInfo(INFO.pointer.child) == .float;
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
pub inline fn type_has_any_field_with_type(comptime T: type, comptime T_FIELD: type) bool {
    const INFO = @typeInfo(T).@"struct";
    inline for (INFO.fields) |field| {
        if (field.type == T_FIELD) return true;
    }
    return false;
}
pub inline fn type_has_exactly_all_field_types(comptime T: type, comptime T_FIELDS: []const type) bool {
    const found_idx: [T_FIELDS.len]usize = undefined;
    const INFO = @typeInfo(T).@"struct";
    if (INFO.fields.len != T_FIELDS.len) return false;
    inline for (T_FIELDS, 0..) |find_type, i| {
        comptime var found_match = false;
        inline for (INFO.fields, 0..) |field, f| {
            if (field.type == find_type) {
                comptime var unique: bool = true;
                inline for (found_idx[0..i]) |prev_found_f| {
                    if (prev_found_f == f) {
                        unique = false;
                        break;
                    }
                }
                if (unique) {
                    found_idx[i] = f;
                    found_match = true;
                    break;
                }
            }
        }
        if (!found_match) return false;
    }
    return true;
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
pub inline fn type_has_decl_with_type_and_val(comptime T: type, comptime decl: []const u8, comptime T_DECL: type, comptime V_DECL: T_DECL) bool {
    return @hasDecl(T, decl) and @TypeOf(@field(T, decl)) == T_DECL and @field(T, decl) == V_DECL;
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
pub inline fn type_is_slice(comptime T: type) bool {
    return @typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .slice;
}
pub inline fn type_is_slice_with_child_type(comptime T: type, comptime C: type) bool {
    return @typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .slice and @typeInfo(T).pointer.child == C;
}
pub inline fn type_is_many_item_pointer(comptime T: type) bool {
    return @typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .many;
}
pub inline fn type_is_single_item_pointer(comptime T: type) bool {
    return @typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .one;
}
pub inline fn type_is_slice_or_pointer_to_slice(comptime T: type) bool {
    return @typeInfo(T) == .pointer and (@typeInfo(T).pointer.size == .slice or (@typeInfo(@typeInfo(T).pointer.child) == .pointer and @typeInfo(@typeInfo(T).pointer.child).pointer.size == .slice));
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
pub inline fn pointer_is_single_or_many(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .one or @typeInfo(T).pointer.size == .many;
}
pub inline fn pointer_is_single_many_or_c(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .one or @typeInfo(T).pointer.size == .many or @typeInfo(T).pointer.size == .c;
}
pub inline fn type_is_array_or_vector(comptime T: type) bool {
    return @typeInfo(T) == .array or @typeInfo(T) == .vector;
}
pub inline fn type_is_vector(comptime T: type) bool {
    return @typeInfo(T) == .vector;
}
pub inline fn type_is_array(comptime T: type) bool {
    return @typeInfo(T) == .array;
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

pub inline fn type_is_comptime(comptime T: type) bool {
    return @typeInfo(T) == .comptime_int or @typeInfo(T) == .comptime_float;
}
pub inline fn type_is_float(comptime T: type) bool {
    return @typeInfo(T) == .float or @typeInfo(T) == .comptime_float;
}
pub inline fn type_is_int(comptime T: type) bool {
    return @typeInfo(T) == .int or @typeInfo(T) == .comptime_int;
}
pub inline fn type_is_numeric(comptime T: type) bool {
    return @typeInfo(T) == .int or @typeInfo(T) == .comptime_int or @typeInfo(T) == .float or @typeInfo(T) == .comptime_float;
}
pub inline fn type_is_numeric_not_comptime(comptime T: type) bool {
    return @typeInfo(T) == .int or @typeInfo(T) == .float;
}
pub inline fn type_is_equatable(comptime T: type) bool {
    const I = @typeInfo(T);
    return I == .int or I == .comptime_int or I == .float or I == .comptime_float or I == .@"enum" or I == .bool;
}
pub inline fn type_is_unsigned_int(comptime T: type) bool {
    return @typeInfo(T) == .int and @typeInfo(T).int.signedness == .unsigned;
}
pub inline fn type_is_comptime_or_unsigned_int(comptime T: type) bool {
    return @typeInfo(T) == .comptime_int or (@typeInfo(T) == .int and @typeInfo(T).int.signedness == .unsigned);
}
pub inline fn type_is_comptime_or_signed_int(comptime T: type) bool {
    return @typeInfo(T) == .comptime_int or (@typeInfo(T) == .int and @typeInfo(T).int.signedness == .signed);
}
pub inline fn type_is_unsigned_int_aligned(comptime T: type) bool {
    switch (T) {
        u8, u16, u32, u64, u128, usize => return true,
        else => return false,
    }
}
pub inline fn type_is_signed_int(comptime T: type) bool {
    return @typeInfo(T) == .int and @typeInfo(T).int.signedness == .signed;
}
pub inline fn type_is_signed_int_aligned(comptime T: type) bool {
    switch (T) {
        i8, i16, i32, i64, i128, isize => return true,
        else => return false,
    }
}
pub inline fn type_is_bool(comptime T: type) bool {
    return T == bool;
}
pub inline fn type_is_enum(comptime T: type) bool {
    return @typeInfo(T) == .@"enum";
}
pub inline fn type_is_union(comptime T: type) bool {
    return @typeInfo(T) == .@"union";
}
pub inline fn type_is_struct(comptime T: type) bool {
    return @typeInfo(T) == .@"struct";
}
pub inline fn type_is_tuple(comptime T: type) bool {
    return @typeInfo(T) == .@"struct" and @typeInfo(T).@"struct".is_tuple == true;
}
pub inline fn type_is_void(comptime T: type) bool {
    return @typeInfo(T) == .void;
}
pub inline fn type_is_func(comptime T: type) bool {
    return @typeInfo(T) == .@"fn";
}

pub inline fn type_is_one_of(comptime T: type, comptime Ts: []const type) bool {
    inline for (Ts) |Tt| {
        if (T == Tt) return true;
    }
    return false;
}

pub inline fn type_name_list(comptime Ts: []const type) [:0]const u8 {
    comptime var S: [:0]const u8 = "{ ";
    inline for (Ts) |T| {
        S = S ++ @typeName(T) ++ " ";
    }
    S = S ++ "}";
    return S;
}

pub inline fn integer_type_A_has_bits_greater_than_B(comptime A: type, comptime B: type) bool {
    return @typeInfo(A).int.bits > @typeInfo(B).int.bits;
}

pub inline fn integer_type_A_has_bits_greater_than_N(comptime A: type, comptime N: comptime_int) bool {
    return @typeInfo(A).int.bits > N;
}

pub inline fn integer_type_A_has_bits_greater_than_or_equal_to_B(comptime A: type, comptime B: type) bool {
    return @typeInfo(A).int.bits >= @typeInfo(B).int.bits;
}

pub inline fn integer_type_A_has_bits_greater_than_or_equal_to_N(comptime A: type, comptime N: comptime_int) bool {
    return @typeInfo(A).int.bits >= N;
}

pub inline fn type_is_struct_with_all_fields_same_type(comptime T: type, comptime F: type) bool {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .@"struct" => {},
        else => return false,
    }
    const STRUCT = INFO.@"struct";
    for (STRUCT.fields) |field| {
        if (field.type != F) return false;
    }
    return true;
}
pub inline fn type_is_struct_with_all_decls_same_type(comptime T: type, comptime D: type) bool {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .@"struct" => {},
        else => return false,
    }
    const STRUCT = INFO.@"struct";
    for (STRUCT.decls) |decl| {
        if (@TypeOf(@field(T, decl.name)) != D) return false;
    }
    return true;
}
pub inline fn type_is_struct_with_all_fields_same_type_any(comptime T: type) bool {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .@"struct" => {},
        else => return false,
    }
    const STRUCT = INFO.@"struct";
    const FIELD_TYPE = STRUCT.fields[0].type;
    for (STRUCT.fields[1..]) |field| {
        if (field.type != FIELD_TYPE) return false;
    }
    return true;
}
pub inline fn type_is_union_with_all_fields_same_type(comptime T: type, comptime F: type) bool {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .@"union" => {},
        else => return false,
    }
    const UNION = INFO.@"union";
    for (UNION.fields) |field| {
        if (field.type != F) return false;
    }
    return true;
}
pub inline fn type_class(comptime T: type) std.builtin.TypeId {
    return comptime std.meta.activeTag(@typeInfo(T));
}
pub inline fn type_is_struct_with_all_fields_same_type_class(comptime T: type, comptime TYPE_ID: std.builtin.TypeId) bool {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .@"struct" => {},
        else => return false,
    }
    const STRUCT = INFO.@"struct";
    for (STRUCT.fields) |field| {
        if (type_class(field.type) != TYPE_ID) return false;
    }
    return true;
}
pub inline fn type_is_union_with_all_fields_same_type_class(comptime T: type, comptime TYPE_ID: std.builtin.TypeId) bool {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .@"union" => {},
        else => return false,
    }
    const UNION = INFO.@"union";
    for (UNION.fields) |field| {
        if (type_class(field.type) != TYPE_ID) return false;
    }
    return true;
}
pub inline fn type_is_union_with_all_fields_an_enum_type_with_all_tag_values_from_0_to_max_with_no_gaps(comptime T: type) bool {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .@"union" => {},
        else => return false,
    }
    const UNION = INFO.@"union";
    for (UNION.fields) |field| {
        const FINFO = @typeInfo(field.type);
        switch (FINFO) {
            .@"enum" => {
                if (!all_enum_values_start_from_zero_with_no_gaps(FINFO.type)) return false;
            },
            else => return false,
        }
    }
    return true;
}
pub inline fn type_is_struct_with_all_fields_an_enum_type_with_all_tag_values_from_0_to_max_with_no_gaps(comptime T: type) bool {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .@"struct" => {},
        else => return false,
    }
    const STRUCT = INFO.@"struct";
    for (STRUCT.fields) |field| {
        const FINFO = @typeInfo(field.type);
        switch (FINFO) {
            .@"enum" => {
                if (!all_enum_values_start_from_zero_with_no_gaps(FINFO.type)) return false;
            },
            else => return false,
        }
    }
    return true;
}

pub inline fn type_has_method_with_signature(comptime TYPE: type, comptime NAME: []const u8, comptime INPUTS: []const builtin.Type.Fn.Param, comptime OUTPUT: ?type) bool {
    if (!@hasDecl(TYPE, NAME)) return false;
    if (@typeInfo(@TypeOf(@field(TYPE, NAME))) != .@"fn") return false;
    const FN_INFO = @typeInfo(@TypeOf(@field(TYPE, NAME))).@"fn";
    if (FN_INFO.return_type == null) {
        if (OUTPUT != null) return false;
    } else {
        if (OUTPUT == null) return false;
        if (FN_INFO.return_type.? != OUTPUT.?) return false;
    }
    const INS = FN_INFO.params;
    if (INS.len != INPUTS.len) return false;
    for (INS[0..], INPUTS[0..]) |got_in, exp_in| {
        if (got_in.is_generic != exp_in.is_generic) return false;
        if (got_in.is_noalias != exp_in.is_noalias) return false;
        if (got_in.type == null) {
            if (exp_in.type != null) return false;
        } else {
            if (exp_in.type == null) return false;
            if (got_in.type.? != exp_in.type.?) return false;
        }
    }
    return true;
}

// pub inline fn all_struct_fields_are_same_type(comptime T: type, comptime T_FIELD: type) bool {}

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

pub fn is_valid_tag_name_for_enum(comptime ENUM_TYPE: type, tag_name: [:0]const u8) bool {
    const enum_info = @typeInfo(ENUM_TYPE).@"enum";
    for (enum_info.fields) |field| {
        if (std.mem.eql(u8, field.name, tag_name)) return true;
    }
    return false;
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
                    assert_with_reason(INFO.sentinel_ptr != null, @src(), "many-item pointers must have sentinel values to find their length", .{});
                    const sent_ptr: *const INFO.child = @ptrCast(@alignCast(INFO.sentinel_ptr.?));
                    const sent = sent_ptr.*;
                    var i: usize = 0;
                    while (ptr[i] != sent) : (i += 1) {}
                    return i;
                },
                else => assert_with_reason(false, @src(), "only slices or many-item pointers with sentinel values can return their length", .{}),
            }
        },
        else => assert_with_reason(false, @src(), "`ptr` must be a pointer type, got type {s}", .{@typeName(T)}),
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

pub inline fn enum_tag_type(comptime T: type) type {
    const TI = @typeInfo(T);
    assert_with_reason(TI == .@"enum", @src(), "`T` must be an enum type", .{});
    const E_INFO = TI.@"enum";
    return E_INFO.tag_type;
}

pub inline fn union_tag_type(comptime T: type) type {
    const TI = @typeInfo(T);
    assert_with_reason(TI == .@"union", @src(), "`T` must be an union type", .{});
    const U_INFO = TI.@"union";
    assert_with_reason(U_INFO.tag_type != null, @src(), "union type `{s}` has no defined tag type", .{@typeName(T)});
    return U_INFO.tag_type.?;
}

pub inline fn union_tag(union_val: anytype) union_tag_type(@TypeOf(union_val)) {
    return @enumFromInt(@intFromEnum(union_val));
}

pub fn is_error(error_union: anytype) bool {
    return if (error_union) |_| false else |_| true;
}

pub fn not_error(error_union: anytype) bool {
    return if (error_union) |_| true else |_| false;
}

pub fn both_or_neither_null(a: anytype, b: anytype) bool {
    var c: u8 = @intCast(@intFromBool(a == null));
    c += @intCast(@intFromBool(b == null));
    return c != 1;
}

pub fn unimplemented_5_params(comptime NAME: []const u8, comptime P1: type, comptime P2: type, comptime P3: type, comptime P4: type, comptime P5: type, comptime OUT: type) fn (P1, P2, P3, P4, P5) OUT {
    const PROTO = struct {
        fn FUNC(_: P1, _: P2, _: P3, _: P4, _: P5) OUT {
            assert_with_reason(false, null, "function {s} is not implemented.", .{NAME});
            unreachable;
        }
    };
    return PROTO.FUNC;
}
pub fn unimplemented_4_params(comptime NAME: []const u8, comptime P1: type, comptime P2: type, comptime P3: type, comptime P4: type, comptime OUT: type) fn (P1, P2, P3, P4) OUT {
    const PROTO = struct {
        fn FUNC(_: P1, _: P2, _: P3, _: P4) OUT {
            assert_with_reason(false, null, "function {s} is not implemented.", .{NAME});
            unreachable;
        }
    };
    return PROTO.FUNC;
}
pub fn unimplemented_3_params(comptime NAME: []const u8, comptime P1: type, comptime P2: type, comptime P3: type, comptime OUT: type) fn (P1, P2, P3) OUT {
    const PROTO = struct {
        fn FUNC(_: P1, _: P2, _: P3) OUT {
            assert_with_reason(false, null, "function {s} is not implemented.", .{NAME});
            unreachable;
        }
    };
    return PROTO.FUNC;
}
pub fn unimplemented_2_params(comptime NAME: []const u8, comptime P1: type, comptime P2: type, comptime OUT: type) fn (P1, P2) OUT {
    const PROTO = struct {
        fn FUNC(_: P1, _: P2) OUT {
            assert_with_reason(false, null, "function {s} is not implemented.", .{NAME});
            unreachable;
        }
    };
    return PROTO.FUNC;
}
pub fn unimplemented_1_params(comptime NAME: []const u8, comptime P1: type, comptime OUT: type) fn (P1) OUT {
    const PROTO = struct {
        fn FUNC(_: P1) OUT {
            assert_with_reason(false, null, "function {s} is not implemented.", .{NAME});
            unreachable;
        }
    };
    return PROTO.FUNC;
}
pub fn unimplemented_0_params(comptime NAME: []const u8, comptime OUT: type) fn () OUT {
    const PROTO = struct {
        fn FUNC() OUT {
            assert_with_reason(false, null, "function {s} is not implemented.", .{NAME});
            unreachable;
        }
    };
    return PROTO.FUNC;
}

pub fn child_type(comptime T: type) type {
    const I = @typeInfo(T);
    switch (I) {
        .pointer => |P| {
            return P.child;
        },
        .array => |A| {
            return A.child;
        },
        .vector => |V| {
            return V.child;
        },
        else => {
            Assert.assert_unreachable(@src(), "type {s} does not have a child type", .{@typeName(T)});
        },
    }
}

pub fn type_has_equals(comptime T: type) bool {
    const I = @typeInfo(T);
    switch (I) {
        .comptime_int, .comptime_float, .bool, .@"enum", .int, .float, .type, .enum_literal => return true,
        .@"struct" => {
            if (type_has_method_with_signature(T, "equals", &.{builtin.Type.Fn.Param{
                .is_generic = false,
                .is_noalias = false,
                .type = T,
            }}, bool)) {
                return true;
            } else {
                return false;
            }
        },
        else => return false,
    }
}

pub const EqualsMode = enum(u8) {
    none,
    native,
    slice,
    method,
};

pub fn type_equals_mode(comptime T: type) EqualsMode {
    const I = @typeInfo(T);
    switch (I) {
        .comptime_int, .comptime_float, .bool, .@"enum", .int, .float, .type, .enum_literal => return .native,
        .@"struct" => {
            if (type_has_method_with_signature(T, "equals", &.{builtin.Type.Fn.Param{
                .is_generic = false,
                .is_noalias = false,
                .type = T,
            }}, bool)) {
                return .function;
            } else {
                return .none;
            }
        },
        .array => |A| {
            if (type_equals_mode(A.child) != .native) return .none;
            return .slice;
        },
        .vector => |V| {
            if (type_equals_mode(V.child) != .native) return .none;
            return .slice;
        },
        .pointer => |P| {
            switch (P.size) {
                .one => return .native,
                .slice => {
                    if (type_equals_mode(P.child) != .native) return .none;
                    return .slice;
                },
                else => return .none,
            }
        },
        else => return .none,
    }
}

pub const InterfaceSignatureError = error{
    missing_function,
    function_has_wrong_signature,
    missing_field,
    field_has_wrong_type,
    missing_const_declaration,
    const_declaration_wrong_type,
    const_declaration_wrong_val,
};

pub const InterfaceSignature = struct {
    interface_name: []const u8,
    const_decls: []const ConstDeclDefinition = &.{},
    struct_fields: []const StructFieldDefinition = &.{},
    functions: []const NamedFuncDefinition = &.{},

    pub fn type_fulfills(comptime self: InterfaceSignature, comptime T: type) bool {
        inline for (self.functions) |func| {
            if (func.has_func_error(T) != null) return false;
        }
        inline for (self.const_decls) |const_decl| {
            if (const_decl.has_decl_error(T) != null) return false;
        }
        inline for (self.struct_fields) |field| {
            if (field.has_field_error(T) != null) return false;
        }
        return true;
    }

    pub fn assert_type_fulfills(comptime self: InterfaceSignature, comptime T: type, comptime src_loc: ?SourceLocation) void {
        inline for (self.functions) |func| {
            if (func.has_func_error(T)) |err| switch (err) {
                InterfaceSignatureError.missing_function => assert_unreachable(src_loc, "(assert interface `{s}`) type `{s}` is missing function `{s}`", .{ self.interface_name, @typeName(T), func.name }),
                InterfaceSignatureError.function_has_wrong_signature => assert_unreachable(src_loc, "(assert interface `{s}`) type `{s}` function `{s}` does not match the needed signature `{s}`, got `{s}`", .{ self.interface_name, @typeName(T), func.name, @typeName(func.signature_builder(T)), @typeName(@TypeOf(@field(T, func.name))) }),
                else => unreachable,
            };
        }
        inline for (self.const_decls) |const_decl| {
            if (const_decl.has_decl_error(T)) |err| switch (err) {
                InterfaceSignatureError.missing_const_declaration => assert_unreachable(src_loc, "(assert interface `{s}`) type `{s}` is missing constant declaration `{s}`", .{ self.interface_name, @typeName(T), const_decl.name }),
                InterfaceSignatureError.const_declaration_wrong_type => assert_unreachable(src_loc, "(assert interface `{s}`) type `{s}` constant declaration `{s}` is not the needed type `{s}`, got `{s}`", .{ self.interface_name, @typeName(T), const_decl.name, @typeName(const_decl.T), @typeName(@TypeOf(@field(T, const_decl.name))) }),
                InterfaceSignatureError.const_declaration_wrong_val => assert_unreachable(src_loc, "(assert interface `{s}`) type `{s}` constant declaration `{s}` does not have the required value `{any}`, got `{any}`", .{ self.interface_name, @typeName(T), const_decl.name, @as(*const const_decl.T, @ptrCast(@alignCast(const_decl.needed_val.?))).*, @field(T, const_decl.name) }),
                else => unreachable,
            };
        }
        inline for (self.struct_fields) |field| {
            if (field.has_field_error(T)) |err| switch (err) {
                InterfaceSignatureError.missing_field => assert_unreachable(src_loc, "(assert interface `{s}`) type `{s}` is missing field `{s}`", .{ self.interface_name, @typeName(T), field.name }),
                InterfaceSignatureError.field_has_wrong_type => assert_unreachable(src_loc, "(assert interface `{s}`) type `{s}` field `{s}` is not the correct type `{s}`, got type `{s}`", .{ self.interface_name, @typeName(T), field.name, @typeName(field.T), @typeName(@FieldType(T, field.name)) }),
                else => unreachable,
            };
        }
    }
};

pub const ConstDeclDefinition = struct {
    name: [:0]const u8,
    T: type,
    needed_val: ?*const anyopaque = null,

    pub fn has_decl_error(comptime self: ConstDeclDefinition, comptime T: type) ?InterfaceSignatureError {
        if (!@hasDecl(T, self.name)) return InterfaceSignatureError.missing_const_declaration;
        if (@FieldType(T, self.name) != self.T) return InterfaceSignatureError.const_declaration_wrong_type;
        if (self.needed_val) |need_val_opaque| {
            const need_val: *const self.T = @ptrCast(@alignCast(need_val_opaque));
            if (@field(T, self.name) != need_val) return InterfaceSignatureError.const_declaration_wrong_type;
        }
        return null;
    }

    pub fn define_const_decl(comptime name: [:0]const u8, comptime T: type) ConstDeclDefinition {
        return ConstDeclDefinition{
            .name = name,
            .T = T,
            .needed_val = null,
        };
    }
    pub fn define_const_decl_with_val(comptime name: [:0]const u8, comptime T: type, comptime val: *const T) ConstDeclDefinition {
        return ConstDeclDefinition{
            .name = name,
            .T = T,
            .needed_val = @ptrCast(val),
        };
    }
};

pub const StructFieldDefinition = struct {
    name: [:0]const u8,
    T: type,

    pub fn has_field_error(comptime self: StructFieldDefinition, comptime T: type) ?InterfaceSignatureError {
        if (!@hasField(T, self.name)) return InterfaceSignatureError.missing_field;
        if (@FieldType(T, self.name) != self.T) return InterfaceSignatureError.field_has_wrong_type;
        return null;
    }

    pub fn define_field(comptime name: [:0]const u8, comptime T: type) StructFieldDefinition {
        return StructFieldDefinition{
            .name = name,
            .T = T,
        };
    }
};

pub const NamedFuncDefinition = struct {
    name: [:0]const u8,
    signature_builder: fn (comptime CONCRETE_TYPE: type) type,

    pub fn has_func_error(comptime self: NamedFuncDefinition, comptime T: type) ?InterfaceSignatureError {
        if (!@hasDecl(T, self.name)) return InterfaceSignatureError.missing_function;
        const needed_signature = self.signature_builder(T);
        if (@TypeOf(@field(T, self.name)) != needed_signature) return InterfaceSignatureError.function_has_wrong_signature;
        return null;
    }

    pub fn define_func_with_builder(comptime name: [:0]const u8, comptime signature_builder: fn (comptime SELF_T: type) type) NamedFuncDefinition {
        return NamedFuncDefinition{
            .name = name,
            .signature_builder = signature_builder,
        };
    }
};

// pub const ParamDefinition = struct {
//     is_generic:  bool = false,
//     is_noalias: bool = false,
//     type: ?type = null,

//     pub fn from_type_info(comptime info: std.builtin.Type.Fn.Param) ParamDefinition {
//         return ParamDefinition{
//             .is_generic = info.is_generic,
//             .is_noalias = info.is_noalias,
//             .type = info.type,
//         }
//     }

//     pub fn equals(self: ParamDefinition, other: ParamDefinition) bool {
//         return self.is_generic == other.is_generic and self.is_noalias == other.is_noalias and self.type == other.type;
//     }

//     pub fn first_param_is_self() ParamDefinition {
//         return ParamDefinition{ .p = .{ .type = null, .is_generic = true, .is_noalias = false } };
//     }
//     pub fn define_param(comptime t: type) ParamDefinition {
//         return ParamDefinition{ .p = .{ .type = t, .is_generic = false, .is_noalias = false } };
//     }
//     pub fn define_param_adv(comptime t: type, comptime generic: Generic, comptime no_alias: NoAlias) ParamDefinition {
//         return ParamDefinition{ .p = .{ .type = t, .is_generic = @bitCast(generic), .is_noalias = @bitCast(no_alias) } };
//     }
// };

pub fn all_enum_names_match_all_object_field_names(comptime ENUM: type, comptime STRUCT_OR_UNION_OR_ENUM: type) bool {
    const E_INFO = @typeInfo(ENUM).@"enum";
    const len = switch (@typeInfo(STRUCT_OR_UNION_OR_ENUM)) {
        .@"struct" => |info| info.fields.len,
        .@"union" => |info| info.fields.len,
        .@"enum" => |info| info.fields.len,
        else => unreachable,
    };
    if (E_INFO.fields.len != len) return false;
    for (E_INFO.fields) |e_field| {
        if (!@hasField(STRUCT_OR_UNION_OR_ENUM, e_field.name)) return false;
    }
    return true;
}

pub fn all_enum_names_match_an_object_field_name(comptime ENUM: type, comptime STRUCT_OR_UNION_OR_ENUM: type) bool {
    const E_INFO = @typeInfo(ENUM).@"enum";
    for (E_INFO.fields) |e_field| {
        if (!@hasField(STRUCT_OR_UNION_OR_ENUM, e_field.name)) return false;
    }
    return true;
}
pub fn all_enum_names_match_an_object_field_name_with_same_type(comptime ENUM: type, comptime STRUCT_OR_UNION_OR_ENUM: type, comptime FIELD_TYPE: type) bool {
    const E_INFO = @typeInfo(ENUM).@"enum";
    for (E_INFO.fields) |e_field| {
        if (!@hasField(STRUCT_OR_UNION_OR_ENUM, e_field.name)) return false;
        if (@FieldType(STRUCT_OR_UNION_OR_ENUM, e_field.name) != FIELD_TYPE) return false;
    }
    return true;
}

pub fn all_enum_names_match_an_object_decl_name(comptime ENUM: type, comptime STRUCT_OR_UNION_OR_ENUM: type) bool {
    const E_INFO = @typeInfo(ENUM).@"enum";
    for (E_INFO.fields) |e_field| {
        if (!@hasDecl(STRUCT_OR_UNION_OR_ENUM, e_field.name)) return false;
    }
    return true;
}

pub fn all_enum_names_match_an_object_decl_name_with_same_type(comptime ENUM: type, comptime STRUCT_OR_UNION_OR_ENUM: type, comptime DECL_TYPE: type) bool {
    const E_INFO = @typeInfo(ENUM).@"enum";
    for (E_INFO.fields) |e_field| {
        if (!@hasDecl(STRUCT_OR_UNION_OR_ENUM, e_field.name)) return false;
        if (@TypeOf(@field(STRUCT_OR_UNION_OR_ENUM, e_field.name)) != DECL_TYPE) return false;
    }
    return true;
}

pub const Combined2EnumIntInfo = struct {
    combined_type: type,
    width_1: u16,
    mask_1: u64,
};

/// Returns an integer type that can hold all bitwise values from both enums side-by-side,
/// and the number of bits the second enum needs to be shifted to combine
pub fn Combined2EnumInt(comptime E1: type, comptime E2: type) Combined2EnumIntInfo {
    const largest_1: u64 = enum_max_value(E1);
    const largest_2: u64 = enum_max_value(E2);
    const bit_width_1: u16 = @intCast(64 - @clz(largest_1));
    var mask_1: u64 = @as(u64, 1) << @intCast(bit_width_1 - 1);
    mask_1 |= mask_1 >> 1;
    mask_1 |= mask_1 >> 2;
    mask_1 |= mask_1 >> 4;
    mask_1 |= mask_1 >> 8;
    mask_1 |= mask_1 >> 16;
    mask_1 |= mask_1 >> 32;
    const bit_width_2: u16 = @intCast(64 - @clz(largest_2));
    const total = bit_width_1 + bit_width_2;
    const INT = std.meta.Int(.unsigned, total);
    return Combined2EnumIntInfo{ .combined_type = INT, .width_1 = bit_width_1, .mask_1 = mask_1 };
}

pub fn combine_2_enums(enum_1: anytype, enum_2: anytype) Combined2EnumInt(@TypeOf(enum_1), @TypeOf(enum_1)).combined_type {
    const INFO = Combined2EnumInt(@TypeOf(enum_1), @TypeOf(enum_1));
    const a: INFO.combined_type = @intCast(@intFromEnum(enum_1));
    const b: INFO.combined_type = @intCast(@intFromEnum(enum_2));
    return a | (b << @intCast(INFO.width_1));
}
pub fn decombine_2_enums(combined: anytype, comptime ENUM_1: type, comptime ENUM_2: type) .{ ENUM_1, ENUM_2 } {
    const INFO = Combined2EnumInt(ENUM_1, ENUM_2);
    const a: enum_tag_type(ENUM_1) = @intCast(combined & @as(@TypeOf(combined), @intCast(INFO.mask_1)));
    const b: enum_tag_type(ENUM_2) = @intCast(combined >> @intCast(INFO.width_1));
    return .{ @enumFromInt(a), @enumFromInt(b) };
}

/// Returns a struct type with matching fields that holds *CONCRETE SCALAR* types of the matching fields in the given type
///
/// Scalar concrete fields in the source struct becomse scalar concrete fields in the new struct (eg. `value: u32` => `value: u32`)
///
/// Pointer, array, and vector fields in the source struct become scalar concrete fields in the new struct (eg. `values: []u32` => `values: u32`)
pub fn make_temp_value_struct_from_struct_type(comptime STRUCT_TYPE: type) type {
    const INFO = @typeInfo(STRUCT_TYPE);
    switch (INFO) {
        .@"struct" => |STRUCT| {
            comptime var new_fields: [STRUCT.fields.len]std.builtin.Type.StructField = undefined;
            inline for (STRUCT.fields, new_fields) |field, *new_field| {
                switch (@typeInfo(new_field.type)) {
                    .pointer => |P| {
                        new_field.* = std.builtin.Type.StructField{
                            .alignment = field.alignment,
                            .default_value_ptr = null,
                            .is_comptime = field.is_comptime,
                            .name = field.name,
                            .type = P.child,
                        };
                    },
                    .array => |A| {
                        new_field.* = std.builtin.Type.StructField{
                            .alignment = field.alignment,
                            .default_value_ptr = null,
                            .is_comptime = field.is_comptime,
                            .name = field.name,
                            .type = A.child,
                        };
                    },
                    .vector => |V| {
                        new_field.* = std.builtin.Type.StructField{
                            .alignment = field.alignment,
                            .default_value_ptr = null,
                            .is_comptime = field.is_comptime,
                            .name = field.name,
                            .type = V.child,
                        };
                    },
                    else => {
                        new_field.* = field;
                    },
                }
            }
            const new_type = std.builtin.Type{ .@"struct" = .{
                .backing_integer = STRUCT.backing_integer,
                .decls = &.{},
                .fields = new_fields[0..],
                .is_tuple = STRUCT.is_tuple,
                .layout = STRUCT.layout,
            } };
            return @Type(new_type);
        },
        else => assert_unreachable(@src(), "type `STRUCT_TYPE` must be a struct type, got type `{s}`", .{@typeName(STRUCT_TYPE)}),
    }
}

pub fn error_union_payload(comptime T: type) type {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .error_union => |ERR| {
            return ERR.payload;
        },
        else => {
            return T;
        },
    }
}
pub fn error_union_error(comptime T: type) type {
    const INFO = @typeInfo(T);
    switch (INFO) {
        .error_union => |ERR| {
            return ERR.error_set;
        },
        else => {
            return void;
        },
    }
}
