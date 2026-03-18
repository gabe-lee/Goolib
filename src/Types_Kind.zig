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

const Type = std.builtin.Type;
const TypeId = std.builtin.TypeId;
/// This is an alternative representation of `std.builtin.TypeId`
pub const Kind = enum(std.meta.Tag(TypeId)) {
    TYPE = @intFromEnum(TypeId.type),
    VOID = @intFromEnum(TypeId.void),
    BOOL = @intFromEnum(TypeId.bool),
    NO_RETURN = @intFromEnum(TypeId.noreturn),
    INT = @intFromEnum(TypeId.int),
    FLOAT = @intFromEnum(TypeId.float),
    POINTER = @intFromEnum(TypeId.pointer),
    ARRAY = @intFromEnum(TypeId.array),
    STRUCT = @intFromEnum(TypeId.@"struct"),
    COMPTIME_FLOAT = @intFromEnum(TypeId.comptime_float),
    COMPTIME_INT = @intFromEnum(TypeId.comptime_int),
    UNDEFINED = @intFromEnum(TypeId.undefined),
    NULL = @intFromEnum(TypeId.null),
    OPTIONAL = @intFromEnum(TypeId.optional),
    ERROR_UNION = @intFromEnum(TypeId.error_union),
    ERROR_SET = @intFromEnum(TypeId.error_set),
    ENUM = @intFromEnum(TypeId.@"enum"),
    UNION = @intFromEnum(TypeId.@"union"),
    FUNCTION = @intFromEnum(TypeId.@"fn"),
    OPAQUE = @intFromEnum(TypeId.@"opaque"),
    FRAME = @intFromEnum(TypeId.frame),
    ANYFRAME = @intFromEnum(TypeId.@"anyframe"),
    VECTOR = @intFromEnum(TypeId.vector),
    ENUM_LITERAL = @intFromEnum(TypeId.enum_literal),

    pub inline fn get_kind(comptime T: type) Kind {
        const int = @intFromEnum(@typeInfo(T));
        return @enumFromInt(int);
    }
    pub inline fn type_is_same_kind(comptime K: Kind, comptime T: type) bool {
        return get_kind(T) == K;
    }
    pub inline fn assert_type_is_same_kind(comptime K: Kind, comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
        assert_with_reason(type_is_same_kind(K, T), src, "type `{s}` does not match needed kind `{s}`, got kind `{s}`", .{ @typeName(T), @tagName(K), @tagName(get_kind(T)) });
    }

    pub inline fn is_type(comptime K: Kind) bool {
        return K == .TYPE;
    }
    pub inline fn is_void(comptime K: Kind) bool {
        return K == .VOID;
    }
    pub inline fn is_bool(comptime K: Kind) bool {
        return K == .BOOL;
    }
    pub inline fn is_no_return(comptime K: Kind) bool {
        return K == .NO_RETURN;
    }
    pub inline fn is_int(comptime K: Kind) bool {
        return K == .INT;
    }
    pub inline fn is_float(comptime K: Kind) bool {
        return K == .FLOAT;
    }
    pub inline fn is_pointer(comptime K: Kind) bool {
        return K == .POINTER;
    }
    pub inline fn is_array(comptime K: Kind) bool {
        return K == .ARRAY;
    }
    pub inline fn is_struct(comptime K: Kind) bool {
        return K == .STRUCT;
    }
    pub inline fn is_comptime_float(comptime K: Kind) bool {
        return K == .COMPTIME_FLOAT;
    }
    pub inline fn is_comptime_int(comptime K: Kind) bool {
        return K == .COMPTIME_INT;
    }
    pub inline fn is_undefined(comptime K: Kind) bool {
        return K == .UNDEFINED;
    }
    pub inline fn is_null(comptime K: Kind) bool {
        return K == .NULL;
    }
    pub inline fn is_optional(comptime K: Kind) bool {
        return K == .OPTIONAL;
    }
    pub inline fn is_error_union(comptime K: Kind) bool {
        return K == .ERROR_UNION;
    }
    pub inline fn is_error_set(comptime K: Kind) bool {
        return K == .ERROR_SET;
    }
    pub inline fn is_enum(comptime K: Kind) bool {
        return K == .ENUM;
    }
    pub inline fn is_union(comptime K: Kind) bool {
        return K == .UNION;
    }
    pub inline fn is_function(comptime K: Kind) bool {
        return K == .FUNCTION;
    }
    pub inline fn is_opaque(comptime K: Kind) bool {
        return K == .OPAQUE;
    }
    pub inline fn is_frame(comptime K: Kind) bool {
        return K == .FRAME;
    }
    pub inline fn is_anyframe(comptime K: Kind) bool {
        return K == .ANYFRAME;
    }
    pub inline fn is_vector(comptime K: Kind) bool {
        return K == .VECTOR;
    }
    pub inline fn is_array_or_vector(comptime K: Kind) bool {
        return K == .ARRAY or K == .VECTOR;
    }
    pub inline fn is_enum_literal(comptime K: Kind) bool {
        return K == .ENUM_LITERAL;
    }
    pub inline fn has_child(comptime K: Kind) bool {
        switch (K) {
            .POINTER, .ARRAY, .VECTOR, .OPTIONAL => return true,
            else => return false,
        }
    }
    pub inline fn is_any_of(comptime K: Kind, comptime allowed: []const Kind) bool {
        inline for (allowed) |A| {
            if (A == K) return true;
        }
        return false;
    }
    pub inline fn is_sub_structured_type(comptime K: Kind) bool {
        return K == .ENUM_LITERAL;
    }
};
/// This is an alternative representation of `std.builtin.Type`
pub const KindInfo = union(Kind) {
    TYPE: void,
    VOID: void,
    BOOL: void,
    NO_RETURN: void,
    INT: std.builtin.Type.Int,
    FLOAT: std.builtin.Type.Float,
    POINTER: std.builtin.Type.Pointer,
    ARRAY: std.builtin.Type.Array,
    STRUCT: std.builtin.Type.Struct,
    COMPTIME_FLOAT: void,
    COMPTIME_INT: void,
    UNDEFINED: void,
    NULL: void,
    OPTIONAL: std.builtin.Type.Optional,
    ERROR_UNION: std.builtin.Type.ErrorUnion,
    ERROR_SET: std.builtin.Type.ErrorSet,
    ENUM: std.builtin.Type.Enum,
    UNION: std.builtin.Type.Union,
    FUNCTION: std.builtin.Type.Fn,
    OPAQUE: std.builtin.Type.Opaque,
    FRAME: std.builtin.Type.Frame,
    ANYFRAME: std.builtin.Type.AnyFrame,
    VECTOR: std.builtin.Type.Vector,
    ENUM_LITERAL: void,

    pub inline fn kind(comptime K: KindInfo) Kind {
        return @enumFromInt(@intFromEnum(K));
    }
    pub inline fn get_kind_info(comptime T: type) KindInfo {
        const INFO = comptime @typeInfo(T);
        const int = comptime @intFromEnum(@typeInfo(T));
        const id_tag: TypeId = comptime @enumFromInt(int);
        const kind_tag: Kind = comptime @enumFromInt(int);
        return @unionInit(KindInfo, @tagName(kind_tag), @field(INFO, @tagName(id_tag)));
    }
    pub inline fn type_is_same_kind(comptime K: KindInfo, comptime T: type) bool {
        return Kind.get_kind(T) == K.kind();
    }
    pub inline fn assert_type_is_same_kind(comptime K: KindInfo, comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
        assert_with_reason(type_is_same_kind(K, T), src, "type `{s}` does not match needed kind `{s}`, got kind `{s}`", .{ @typeName(T), @tagName(K), @tagName(Kind.get_kind(T)) });
    }

    pub inline fn is_type(comptime K: KindInfo) bool {
        return K == .TYPE;
    }
    pub inline fn is_void(comptime K: KindInfo) bool {
        return K == .VOID;
    }
    pub inline fn is_bool(comptime K: KindInfo) bool {
        return K == .BOOL;
    }
    pub inline fn is_no_return(comptime K: KindInfo) bool {
        return K == .NO_RETURN;
    }
    pub inline fn is_int(comptime K: KindInfo) bool {
        return K == .INT;
    }
    pub inline fn is_float(comptime K: KindInfo) bool {
        return K == .FLOAT;
    }
    pub inline fn is_pointer(comptime K: KindInfo) bool {
        return K == .POINTER;
    }
    pub inline fn is_array(comptime K: KindInfo) bool {
        return K == .ARRAY;
    }
    pub inline fn is_struct(comptime K: KindInfo) bool {
        return K == .STRUCT;
    }
    pub inline fn is_comptime_float(comptime K: KindInfo) bool {
        return K == .COMPTIME_FLOAT;
    }
    pub inline fn is_comptime_int(comptime K: KindInfo) bool {
        return K == .COMPTIME_INT;
    }
    pub inline fn is_undefined(comptime K: KindInfo) bool {
        return K == .UNDEFINED;
    }
    pub inline fn is_null(comptime K: KindInfo) bool {
        return K == .NULL;
    }
    pub inline fn is_optional(comptime K: KindInfo) bool {
        return K == .OPTIONAL;
    }
    pub inline fn is_error_union(comptime K: KindInfo) bool {
        return K == .ERROR_UNION;
    }
    pub inline fn is_error_set(comptime K: KindInfo) bool {
        return K == .ERROR_SET;
    }
    pub inline fn is_enum(comptime K: KindInfo) bool {
        return K == .ENUM;
    }
    pub inline fn is_union(comptime K: KindInfo) bool {
        return K == .UNION;
    }
    pub inline fn is_function(comptime K: KindInfo) bool {
        return K == .FUNCTION;
    }
    pub inline fn is_opaque(comptime K: KindInfo) bool {
        return K == .OPAQUE;
    }
    pub inline fn is_frame(comptime K: KindInfo) bool {
        return K == .FRAME;
    }
    pub inline fn is_anyframe(comptime K: KindInfo) bool {
        return K == .ANYFRAME;
    }
    pub inline fn is_vector(comptime K: KindInfo) bool {
        return K == .VECTOR;
    }
    pub inline fn is_array_or_vector(comptime K: KindInfo) bool {
        return K == .ARRAY or K == .VECTOR;
    }
    pub inline fn is_array_or_vector_with_child_kind(comptime K: KindInfo, comptime KK: Kind) bool {
        switch (K) {
            .ARRAY => |A| {
                const CHILD = A.child;
                return KK.type_is_same_kind(CHILD);
            },
            .VECTOR => |V| {
                const CHILD = V.child;
                return KK.type_is_same_kind(CHILD);
            },
            else => return false,
        }
    }

    pub inline fn is_enum_literal(comptime K: KindInfo) bool {
        return K == .ENUM_LITERAL;
    }
    pub inline fn is_any_of(comptime K: KindInfo, comptime allowed: []const Kind) bool {
        inline for (allowed) |A| {
            if (K == A) return true;
        }
        return false;
    }
    pub inline fn get_len(comptime K: KindInfo) comptime_int {
        switch (K) {
            .ARRAY => |A| {
                return A.len;
            },
            .VECTOR => |V| {
                return V.len;
            },
            else => assert_unreachable(@src(), "kind was not an array or vector, has no comptime len, got kind `{s}`", .{@tagName(K)}),
        }
    }
    /// Returns the number of struct fields, union fields/tags, or enum tags
    pub inline fn field_count(comptime K: KindInfo) usize {
        switch (K) {
            .STRUCT => |S| {
                return S.fields.len;
            },
            .UNION => |U| {
                return U.fields.len;
            },
            .ENUM => |E| {
                return E.fields.len;
            },
            else => assert_unreachable(@src(), "kind was not a struct, union, or enum, has no field count, got kind `{s}`", .{@tagName(K)}),
        }
    }
    pub inline fn has_child(comptime K: KindInfo) bool {
        switch (K) {
            .POINTER, .ARRAY, .VECTOR, .OPTIONAL => return true,
            else => return false,
        }
    }
    pub inline fn child_kind(comptime K: KindInfo) Kind {
        switch (K) {
            .POINTER => |P| {
                return Kind.get_kind(P.child);
            },
            .ARRAY => |A| {
                return Kind.get_kind(A.child);
            },
            .VECTOR => |V| {
                return Kind.get_kind(V.child);
            },
            .OPTIONAL => |O| {
                return Kind.get_kind(O.child);
            },
            else => return false,
        }
    }
    pub inline fn child_kind_info(comptime K: KindInfo) KindInfo {
        switch (K) {
            .POINTER => |P| {
                return get_kind_info(P.child);
            },
            .ARRAY => |A| {
                return get_kind_info(A.child);
            },
            .VECTOR => |V| {
                return get_kind_info(V.child);
            },
            .OPTIONAL => |O| {
                return get_kind_info(O.child);
            },
            else => return false,
        }
    }
    pub inline fn has_child_kind(comptime K: KindInfo, comptime KK: Kind) bool {
        switch (K) {
            .POINTER => |P| {
                return Kind.get_kind(P.child) == KK;
            },
            .ARRAY => |A| {
                return Kind.get_kind(A.child) == KK;
            },
            .VECTOR => |V| {
                return Kind.get_kind(V.child) == KK;
            },
            .OPTIONAL => |O| {
                return Kind.get_kind(O.child) == KK;
            },
            else => return false,
        }
    }
    pub inline fn has_child_type(comptime K: KindInfo, comptime TT: type) bool {
        switch (K) {
            .POINTER => |P| {
                return P.child == TT;
            },
            .ARRAY => |A| {
                return A.child == TT;
            },
            .VECTOR => |V| {
                return V.child == TT;
            },
            .OPTIONAL => |O| {
                return O.child == TT;
            },
            else => return false,
        }
    }
    pub inline fn is_indexable(comptime K: KindInfo) bool {
        switch (K) {
            .POINTER => |P| {
                return P.size == .many or P.size == .slice or (P.size == .one and Kind.get_kind(P.child).is_any_of(&.{ .ARRAY, .VECTOR }));
            },
            .ARRAY, .VECTOR => return true,
            .STRUCT => |S| {
                return S.is_tuple;
            },
            else => return false,
        }
    }
    pub inline fn has_indexable_child_kind(comptime K: KindInfo, comptime KK: Kind) bool {
        if (K == .POINTER and K.POINTER.size == .one and K.child_kind().is_array_or_vector()) {
            return K.child_kind_info().has_child_kind(KK);
        }
        return K.is_indexable() and K.has_child_kind(KK);
    }
    pub inline fn assert_has_indexable_child_kind(comptime K: KindInfo, comptime KK: Kind, comptime src: ?std.builtin.SourceLocation) void {
        assert_with_reason(K.has_indexable_child_kind(KK), src, "kind {any} does not have an indexable child kind `{s}`", .{ K, @tagName(KK) });
    }
    pub inline fn has_indexable_child_type(comptime K: KindInfo, comptime TT: type) bool {
        if (K == .POINTER and K.POINTER.size == .one and K.child_kind().is_array_or_vector()) {
            return K.child_kind_info().has_child_type(TT);
        }
        return K.is_indexable() and K.has_child_type(TT);
    }
    pub inline fn assert_has_indexable_child_type(comptime K: KindInfo, comptime TT: type, comptime src: ?std.builtin.SourceLocation) void {
        assert_with_reason(K.has_indexable_child_type(TT), src, "kind {any} does not have an indexable child type `{s}`", .{ K, @typeName(TT) });
    }

    pub fn is_kind_with_sub_structure(comptime K: KindInfo) bool {
        re_eval: switch (K) {
            .STRUCT, .UNION, .OPTIONAL, .ERROR_UNION => return true,
            .ARRAY => |A| {
                const KK = KindInfo.get_kind_info(A.child);
                continue :re_eval KK;
            },
            .VECTOR => |V| {
                const KK = KindInfo.get_kind_info(V.child);
                continue :re_eval KK;
            },
            .POINTER => |P| {
                if (P.size == .slice) return true;
                return false;
            },
            else => return false,
        }
    }
    pub fn is_kind_with_sub_structure_follow_pointers(comptime K: KindInfo) bool {
        re_eval: switch (K) {
            .STRUCT, .UNION, .OPTIONAL, .ERROR_UNION => return true,
            .ARRAY => |A| {
                const KK = KindInfo.get_kind_info(A.child);
                continue :re_eval KK;
            },
            .VECTOR => |V| {
                const KK = KindInfo.get_kind_info(V.child);
                continue :re_eval KK;
            },
            .POINTER => |P| {
                const KK = KindInfo.get_kind_info(P.child);
                continue :re_eval KK;
            },
            else => return false,
        }
    }
};
