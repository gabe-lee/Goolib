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
const SerializeModule = Root.Serializer;
// const SerialRoutineBuilder = SerializeModule.SerialRoutineBuilder;
const ByteDataOp = SerializeModule.DataOp;
const ObjectSerialSettings = SerializeModule.ObjectSerialSettings;
const IntPacking = SerializeModule.IntegerPacking;
pub const OptionalObjectSerialSettings = SerializeModule.OptionalObjectSerialSettings;
const CacheMode = SerializeModule.DataCacheMode;
const UseCachedLen = SerializeModule.UseCachedLen;

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
///
/// `PER_FIELD_SERIAL_SETTINGS`, if included, should be a struct type with a declaration for each tag you want to have custom settings:
/// ```zig
/// const MyUnion = union(enum) {
///     tag_with_custom_serial_settings: u32,
///     // other union fields
/// };
/// const PER_FIELD_SERIAL_SETTINGS = struct {
///     pub const tag_with_custom_serial_settings = OptionalObjectSerialSettings{
///         // Fill in your settings
///     };
/// };
/// const MySerialUnion = SerialUnion(MyUnion, struct{}, PER_FIELD_SERIAL_SETTINGS);
/// ```
pub fn SerialSlice(comptime TYPE: type, comptime IDX: type) type {
    return extern struct {
        ptr: [*]TYPE = Utils.invalid_ptr_many(TYPE),
        len: IDX = 0,

        
    };
}
