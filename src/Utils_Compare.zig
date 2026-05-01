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

const Root = @import("./_root.zig");
const Types = Root.Types;
const Math = Root.Math;

const Utils = Root.Utils;
const assert_with_reason = Root.Assert.assert_with_reason;
const assert_unreachable = Root.Assert.assert_unreachable;

pub const Order = enum(i8) {
    A_LESS_THAN_B = -1,
    A_EQUAL_B = 0,
    A_GREATER_THAN_B = 1,
};

pub inline fn less_than(a: anytype, b: anytype) bool {
    return Math.upgrade_less_than(a, b);
}

pub inline fn greater_than(a: anytype, b: anytype) bool {
    return Math.upgrade_greater_than(a, b);
}

pub inline fn less_than_or_equal(a: anytype, b: anytype) bool {
    return Math.upgrade_less_than_or_equal(a, b);
}

pub inline fn greater_than_or_equal(a: anytype, b: anytype) bool {
    return Math.upgrade_greater_than_or_equal(a, b);
}

pub inline fn equal(a: anytype, b: anytype) bool {
    return Math.upgrade_equal_to(a, b);
}

pub inline fn not_equal(a: anytype, b: anytype) bool {
    return !Math.upgrade_equal_to(a, b);
}

pub fn order(a: anytype, b: anytype) Order {
    if (less_than(a, b)) {
        return .A_LESS_THAN_B;
    } else if (greater_than(a, b)) {
        return .A_GREATER_THAN_B;
    } else return .A_EQUAL_B;
}

pub inline fn less_than_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_less_than(aa, bb);
}

pub inline fn greater_than_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_greater_than(aa, bb);
}

pub inline fn less_than_or_equal_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_less_than_or_equal(aa, bb);
}

pub inline fn greater_than_or_equal_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_greater_than_or_equal(aa, bb);
}

pub inline fn equal_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_equal_to(aa, bb);
}

pub inline fn not_equal_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return !Math.upgrade_equal_to(aa, bb);
}

pub fn order_follow_pointers(a: anytype, b: anytype) Order {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    if (less_than(aa, bb)) {
        return .A_LESS_THAN_B;
    } else if (greater_than(aa, bb)) {
        return .A_GREATER_THAN_B;
    } else return .A_EQUAL_B;
}

/// Compares two of any type for equality. Containers that do not support comparison
/// on their own are compared on a field-by-field basis. Pointers are not followed.
///
/// Struct, Enum, Union, and Opaque types
pub fn shallow_equals(a: anytype, b: anytype) bool {
    const T_A = @TypeOf(a);
    const T_B = @TypeOf(b);
    const T_SAME = T_A == T_B;
    const T_DIFF = T_A != T_B;
    const INFO_A = Types.KindInfo.get_kind_info(T_A);
    switch (INFO_A) {
        .STRUCT => |STRUCT| {
            if (@hasDecl(T_A, "equals") and @TypeOf(@field(T_A, "equals")) == fn (T_A, T_B) bool) {
                return @call(.auto, @field(T_A, "equals"), .{ a, b });
            } else if (T_DIFF and @hasDecl(T_B, "equals") and @TypeOf(@field(T_B, "equals")) == fn (T_B, T_A) bool) {
                return @call(.auto, @field(T_B, "equals"), .{ b, a });
            }
            assert_with_reason(T_SAME, @src(), "cannot compare two structs with different types, got `{s}` and `{s}`", .{ @typeName(T_A), @typeName(T_B) });
            if (STRUCT.layout == .@"packed") return a == b;

            inline for (STRUCT.fields) |field_info| {
                if (!shallow_equals(@field(a, field_info.name), @field(b, field_info.name))) return false;
            }
            return true;
        },
        .ERROR_UNION => {
            if (a) |a_p| {
                if (b) |b_p| return shallow_equals(a_p, b_p) else |_| return false;
            } else |a_e| {
                if (b) |_| return false else |b_e| return a_e == b_e;
            }
        },
        .UNION => |UNION| {
            if (@hasDecl(T_A, "equals") and @TypeOf(@field(T_A, "equals")) == fn (T_A, T_B) bool) {
                return @call(.auto, @field(T_A, "equals"), .{ a, b });
            } else if (T_DIFF and @hasDecl(T_B, "equals") and @TypeOf(@field(T_B, "equals")) == fn (T_B, T_A) bool) {
                return @call(.auto, @field(T_B, "equals"), .{ b, a });
            }
            assert_with_reason(T_SAME, @src(), "cannot compare two unions with different types, got `{s}` and `{s}`", .{ @typeName(T_A), @typeName(T_B) });
            if (UNION.tag_type) |UnionTag| {
                const tag_a: UnionTag = a;
                const tag_b: UnionTag = b;
                if (tag_a != tag_b) return false;

                return switch (a) {
                    inline else => |val, tag| return shallow_equals(val, @field(b, @tagName(tag))),
                };
            }
            if (UNION.layout == .@"packed") {
                const CONTAINER = packed struct {
                    u: T_A,
                };
                const u_a = CONTAINER{
                    .u = a,
                };
                const u_b = CONTAINER{
                    .u = b,
                };
                return u_a == u_b;
            }
            @compileError("cannot compare untagged and non-packed union type " ++ @typeName(T_A));
        },
        .ARRAY => {
            assert_with_reason(T_SAME, @src(), "cannot compare two arrays with different types, got `{s}` and `{s}`", .{ @typeName(T_A), @typeName(T_B) });
            for (a[0..], b[0..]) |aa, bb|
                if (!shallow_equals(aa, bb)) return false;
            return true;
        },
        .VECTOR => |VECTOR| {
            assert_with_reason(T_SAME, @src(), "cannot compare two vectors with different types, got `{s}` and `{s}`", .{ @typeName(T_A), @typeName(T_B) });
            const arr_a: [VECTOR.len]VECTOR.child = a;
            const arr_b: [VECTOR.len]VECTOR.child = b;
            for (arr_a[0..], arr_b[0..]) |aa, bb|
                if (!shallow_equals(aa, bb)) return false;
            return true;
        },
        .POINTER => {
            const flat_a = Types.get_flat_ptr_info(a);
            const flat_b = Types.get_flat_ptr_info(b);
            return flat_a.equals(flat_b);
        },
        .OPTIONAL => |OPTIONAL| {
            const child_info = Types.KindInfo.get_kind_info(OPTIONAL.child);
            switch (child_info) {
                .POINTER => {
                    const flat_a = Types.get_flat_ptr_info(a);
                    const flat_b = Types.get_flat_ptr_info(b);
                    return flat_a.equals(flat_b);
                },
                else => {
                    assert_with_reason(T_SAME, @src(), "cannot compare two optionals with different types, got `{s}` and `{s}`", .{ @typeName(T_A), @typeName(T_B) });
                    if (a == null and b == null) return true;
                    if (a == null or b == null) return false;
                    return shallow_equals(a.?, b.?);
                },
            }
        },
        .ENUM => {
            if (@hasDecl(T_A, "equals") and @TypeOf(@field(T_A, "equals")) == fn (T_A, T_B) bool) {
                return @call(.auto, @field(T_A, "equals"), .{ a, b });
            } else if (T_DIFF and @hasDecl(T_B, "equals") and @TypeOf(@field(T_B, "equals")) == fn (T_B, T_A) bool) {
                return @call(.auto, @field(T_B, "equals"), .{ b, a });
            }
            assert_with_reason(T_SAME, @src(), "cannot compare two enums with different types, got `{s}` and `{s}`", .{ @typeName(T_A), @typeName(T_B) });
            return a == b;
        },
        .OPAQUE => {
            if (@hasDecl(T_A, "equals") and @TypeOf(@field(T_A, "equals")) == fn (T_A, T_B) bool) {
                return @call(.auto, @field(T_A, "equals"), .{ a, b });
            } else if (T_DIFF and @hasDecl(T_B, "equals") and @TypeOf(@field(T_B, "equals")) == fn (T_B, T_A) bool) {
                return @call(.auto, @field(T_B, "equals"), .{ b, a });
            }
            assert_unreachable(@src(), "opaque types can only be tested for equality if they implement `pub fn equals(a: T, b: T) bool`", .{});
        },
        .ERROR_SET => {
            if (@hasDecl(T_A, "equals") and @TypeOf(@field(T_A, "equals")) == fn (T_A, T_B) bool) {
                return @call(.auto, @field(T_A, "equals"), .{ a, b });
            } else if (T_DIFF and @hasDecl(T_B, "equals") and @TypeOf(@field(T_B, "equals")) == fn (T_B, T_A) bool) {
                return @call(.auto, @field(T_B, "equals"), .{ b, a });
            }
            return a == b;
        },
        else => return Math.upgrade_equal_to(a, b),
    }
}

/// Reports whether calling `object_equals()` on the type is valid
pub fn has_object_equals(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            if (@hasDecl(T, "equals") and @TypeOf(@field(T, "equals")) == fn (T, T) bool) {
                return true;
            }
            if (info.layout == .@"packed") return true;

            inline for (info.fields) |field_info| {
                if (!has_object_equals(@FieldType(T, field_info.name))) return false;
            }
            return true;
        },
        .error_union => |info| {
            return has_object_equals(info.payload);
        },
        .@"union" => |info| {
            if (@hasDecl(T, "equals") and @FieldType(T, "equals") == fn (T, T) bool) {
                return true;
            }
            if (info.tag_type == null) return false;
            inline for (info.fields) |field_info| {
                if (!has_object_equals(@FieldType(T, field_info.name))) return false;
            }
        },
        .array => |info| {
            return has_object_equals(info.child);
        },
        .vector => |info| {
            return has_object_equals(info.child);
        },
        .optional => |info| {
            return has_object_equals(info.child);
        },
        .@"opaque" => {
            if (@hasDecl(T, "equals") and @FieldType(T, "equals") == fn (T, T) bool) {
                return true;
            }
            return false;
        },
        .int, .comptime_int, .float, .comptime_float, .@"enum", .bool, .error_set, .enum_literal, .type, .void, .pointer => {
            return true;
        },
        else => return false,
    }
}

/// The function should return `true` if `item_to_check == search_param`
pub fn CompareFunc(comptime TA: type, comptime TB: type) type {
    return fn (a: TA, b: TB) bool;
}
/// The function should return `true` if `item_to_check == search_param`
pub fn CompareFuncUserdata(comptime TA: type, comptime TB: type, comptime USERDATA: type) type {
    return fn (a: TA, b: TB, userdata: USERDATA) bool;
}
