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
pub inline fn type_is_numeric(comptime T: type) bool {
    return @typeInfo(T) == .int or @typeInfo(T) == .comptime_int or @typeInfo(T) == .float or @typeInfo(T) == .comptime_float;
}
pub inline fn type_is_unsigned_int(comptime T: type) bool {
    return @typeInfo(T) == .int and @typeInfo(T).int.signedness == .unsigned;
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
