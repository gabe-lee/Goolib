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
const Assert = Root.Assert;
const MathX = Root.Math;
const Utils = Root.Utils;
const Types = Root.Types;
const Cast = Root.Cast;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const union_and_enum_have_exact_same_fields = Types.union_and_enum_have_exact_same_fields;
const bare_union_with_same_fields_as_tagged_union = Types.bare_union_with_same_fields_as_tagged_union;
const num_cast = Cast.num_cast;

const Allocator = std.mem.Allocator;
const Endian = Root.CommonTypes.Endian;
const Type = std.builtin.Type;
const TypeId = std.builtin.TypeId;
const Kind = Types.Kind;
const KindInfo = Types.KindInfo;
const DefinedLayout = Types.DefinedLayout;
const SerializeModule = Root.Serializer.Simple;
const SerialRoutineBuilder = SerializeModule.SerialRoutineBuilder;
const ByteDataOp = SerializeModule.ByteDataOp;

/// Creates a struct type that can behave similar to tagged union, but has a well-defined memory layout
/// for serialization or MMIO
///
/// Specifically, it is an `extern` struct with one of the following possible 2 layouts:
///   - if the alignment of the tag type is greater than or equal to the align of the resulting bare union type:
///     1. tag
///     2. union
///   - if the alignment of the tag type is less than the align of the resulting bare union type:
///     1. union
///     2. tag
///
/// `DECLS_` should be a struct type (possibly empty if no declarations are needed) that
/// is attatched to the struct and holds only static declarations and has no fields
pub fn HybridUnion(comptime TAGGED_UNION: type, comptime DECLS_: type, comptime UNION_LAYOUT: DefinedLayout) type {
    Kind.STRUCT.assert_type_is_same_kind(DECLS_, @src());
    const DECL_INFO = KindInfo.get_kind_info(DECLS_).STRUCT;
    assert_with_reason(DECL_INFO.fields.len == 0, @src(), "`DECLS_` must not have any instance fields, only static declarations", .{});
    const UNION_ = bare_union_with_same_fields_as_tagged_union(TAGGED_UNION, UNION_LAYOUT.to_native());
    const TAG = @typeInfo(TAGGED_UNION).@"union".tag_type.?;
    const BARE_ALIGN = @alignOf(UNION_);
    const TAG_ALIGN = @alignOf(TAG);
    return extern struct {
        const Self = @This();

        _1: if (TAG_AT_BEGIN) TAG else UNION,
        _2: if (TAG_AT_BEGIN) UNION else TAG,

        const FUNCS = HybridUnionAdapter(Self, if (TAG_AT_BEGIN) "_1" else "_2", if (TAG_AT_BEGIN) "_2" else "_1");

        pub const DECLS = DECLS_;
        pub const TAG_TYPE = TAG;
        pub const TAG_SIZE = @sizeOf(TAG);
        pub const UNION = UNION_;
        pub const TAG_AT_BEGIN = TAG_ALIGN >= BARE_ALIGN;
        pub const FIELD_COUNT = @typeInfo(UNION).@"union".fields.len;
        pub const TAG_OFFSET = if (TAG_AT_BEGIN) @offsetOf(Self, "_1") else @offsetOf(Self, "_2");
        pub const UNION_OFFSET = if (TAG_AT_BEGIN) @offsetOf(Self, "_2") else @offsetOf(Self, "_1");

        pub inline fn new(comptime tag: TAG, val: @FieldType(UNION, @tagName(tag))) Self {
            var self: Self = undefined;
            self.tag_set(tag);
            self.set(tag, val);
            return self;
        }

        pub inline fn tag_parent_ptr(tag: *TAG) *Self {
            return @fieldParentPtr(if (TAG_AT_BEGIN) "_1" else "_2", tag);
        }
        pub inline fn tag_parent_ptr_const(tag: *const TAG) *const Self {
            return @fieldParentPtr(if (TAG_AT_BEGIN) "_1" else "_2", @constCast(tag));
        }
        pub inline fn bare_union_parent_ptr(bare_union: *UNION) *Self {
            return @fieldParentPtr(if (TAG_AT_BEGIN) "_2" else "_1", bare_union);
        }
        pub inline fn bare_union_parent_ptr_const(bare_union: *const UNION) *const Self {
            return @fieldParentPtr(if (TAG_AT_BEGIN) "_2" else "_1", @constCast(bare_union));
        }
        pub inline fn from_tagged(tagged: TAGGED_UNION) Self {
            const active_tag: TAG = std.meta.activeTag(tagged);
            const bare_union: UNION = switch (active_tag) {
                inline else => |active| @unionInit(UNION, @tagName(active), @field(tagged, @tagName(active))),
            };
            return Self{
                ._1 = if (TAG_AT_BEGIN) active_tag else bare_union,
                ._2 = if (TAG_AT_BEGIN) bare_union else active_tag,
            };
        }
        pub inline fn to_tagged(self: Self) TAGGED_UNION {
            return switch (if (TAG_AT_BEGIN) self._1 else self._2) {
                inline else => |active| @unionInit(TAGGED_UNION, @tagName(active), @field(if (TAG_AT_BEGIN) self._2 else self._1, @tagName(active))),
            };
        }

        pub inline fn tag_get(self: Self) TAG {
            if (TAG_AT_BEGIN) {
                return @field(self, "_1");
            } else {
                return @field(self, "_2");
            }
        }
        pub inline fn tag_ptr(self: *Self) *TAG {
            if (TAG_AT_BEGIN) {
                return &@field(self, "_1");
            } else {
                return &@field(self, "_2");
            }
        }
        pub inline fn tag_ptr_const(self: *const Self) *const TAG {
            if (TAG_AT_BEGIN) {
                return &@field(self, "_1");
            } else {
                return &@field(self, "_2");
            }
        }
        pub inline fn tag_set(self: *Self, new_tag: TAG) void {
            if (TAG_AT_BEGIN) {
                @field(self, "_1") = new_tag;
            } else {
                @field(self, "_2") = new_tag;
            }
        }

        pub inline fn bare_union_get(self: Self) UNION {
            if (TAG_AT_BEGIN) {
                return @field(self, "_2");
            } else {
                return @field(self, "_1");
            }
        }
        pub inline fn bare_union_ptr(self: *Self) *UNION {
            if (TAG_AT_BEGIN) {
                return &@field(self, "_2");
            } else {
                return &@field(self, "_1");
            }
        }
        pub inline fn bare_union_ptr_const(self: *const Self) *const UNION {
            if (TAG_AT_BEGIN) {
                return &@field(self, "_2");
            } else {
                return &@field(self, "_1");
            }
        }
        pub inline fn bare_union_set(self: *Self, new_bare_union: UNION) void {
            if (TAG_AT_BEGIN) {
                @field(self, "_2") = new_bare_union;
            } else {
                @field(self, "_1") = new_bare_union;
            }
        }

        pub inline fn get(self: Self, comptime tag: TAG) @FieldType(UNION, @tagName(tag)) {
            return FUNCS.get(self, tag);
        }
        pub inline fn get_ptr(self: *Self, comptime tag: TAG) *@FieldType(UNION, @tagName(tag)) {
            return FUNCS.get_ptr(self, tag);
        }
        pub inline fn get_ptr_const(self: *const Self, comptime tag: TAG) *const @FieldType(UNION, @tagName(tag)) {
            return FUNCS.get_ptr_const(self, tag);
        }
        pub inline fn set(self: *Self, comptime tag: TAG, val: @FieldType(UNION, @tagName(tag))) void {
            FUNCS.set(self, tag, val);
        }

        pub fn custom_serialize_routine(comptime builder: *SerialRoutineBuilder, comptime curr_native_offset_: i32, comptime TARGET_ENDIAN: Endian) void {
            const tag_native_offset = curr_native_offset_ + TAG_OFFSET;
            const union_native_offset = curr_native_offset_ + UNION_OFFSET;
            comptime var union_builder = builder.start_union_routine_builder(tag_native_offset, TARGET_ENDIAN, TAG_TYPE, FIELD_COUNT);
            inline for (@typeInfo(UNION).@"union".fields) |u_field| {
                const tag_raw = find: {
                    inline for (@typeInfo(TAG_TYPE).@"enum".fields) |e_field| {
                        if (std.mem.eql(u8, u_field.name, e_field.name)) {
                            break :find e_field.value;
                        }
                    }
                    unreachable;
                };
                const tag_val: TAG = @enumFromInt(tag_raw);
                union_builder.add_type(builder, tag_val, union_native_offset, TARGET_ENDIAN, u_field.type, 2000);
            }
            union_builder.end_union_builder();
        }
    };
}

/// Returns a set of get/set functions that can be used within a parent struct to treat a pair of its bare union and enum tag fields as
/// a psuedo tagged union
pub fn HybridUnionAdapter(comptime PARENT_STRUCT: type, comptime tag_field: []const u8, comptime bare_union_field: []const u8) type {
    Kind.STRUCT.assert_type_is_same_kind(PARENT_STRUCT, @src());
    assert_with_reason(@hasField(PARENT_STRUCT, tag_field), @src(), "`PARENT_STRUCT` must have union tag field `{s}`", .{tag_field});
    const TAG_TYPE = @FieldType(PARENT_STRUCT, tag_field);
    Kind.ENUM.assert_type_is_same_kind(TAG_TYPE, @src());
    assert_with_reason(@hasField(PARENT_STRUCT, bare_union_field), @src(), "`PARENT_STRUCT` must have bare union field `{s}`", .{bare_union_field});
    const UNION_TYPE = @FieldType(PARENT_STRUCT, bare_union_field);
    Kind.UNION.assert_type_is_same_kind(UNION_TYPE, @src());
    const U_INFO = @typeInfo(UNION_TYPE).@"union";
    assert_with_reason(U_INFO.tag_type == null, @src(), "union type for field `{s}` must be a bare union (no tag)", .{bare_union_field});
    assert_with_reason(union_and_enum_have_exact_same_fields(UNION_TYPE, TAG_TYPE), @src(), "union `{s}` and tag `{s} must have all the same fields", .{});
    return struct {
        fn assert_tag(parent: PARENT_STRUCT, comptime tag: TAG_TYPE) void {
            const current_tag = @field(parent, tag_field);
            assert_with_reason(current_tag == tag, @src(), "union field `{s}` is not active, current field is `{s}`", .{ @tagName(tag), @tagName(current_tag) });
        }
        pub fn get(parent: PARENT_STRUCT, comptime tag: TAG_TYPE) @FieldType(UNION_TYPE, @tagName(tag)) {
            assert_tag(parent, tag);
            return @field(@field(parent, bare_union_field), @tagName(tag));
        }
        pub fn get_ptr(parent: *PARENT_STRUCT, comptime tag: TAG_TYPE) *@FieldType(UNION_TYPE, @tagName(tag)) {
            assert_tag(parent, tag);
            return &@field(@field(parent, bare_union_field), @tagName(tag));
        }
        pub fn get_ptr_const(parent: *const PARENT_STRUCT, comptime tag: TAG_TYPE) *const @FieldType(UNION_TYPE, @tagName(tag)) {
            assert_tag(parent, tag);
            return &@field(@field(parent, bare_union_field), @tagName(tag));
        }
        pub fn set(parent: *PARENT_STRUCT, comptime tag: TAG_TYPE, val: @FieldType(UNION_TYPE, @tagName(tag))) void {
            @field(parent, bare_union_field) = @unionInit(UNION_TYPE, @tagName(tag), val);
        }
    };
}
