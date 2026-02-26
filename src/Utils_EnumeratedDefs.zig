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
const config = @import("config");
const Allocator = std.mem.Allocator;
const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Types = Root.Types;

const assert_with_reason = Assert.assert_with_reason;

pub fn EnumeratedDefinitions(comptime ENUM: type, comptime ENUM_DEF: type, comptime ENUM_DEF_NAME_FIELD: []const u8, comptime UNNAMED_DEF: type) type {
    assert_with_reason(Types.type_is_enum(ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(ENUM), @src(), "type `ENUM` must be an enum type with all tag values from 0 to the max value with no gaps, got type `{s}`", .{@typeName(ENUM)});
    assert_with_reason(Types.type_is_struct(ENUM_DEF), @src(), "type `ENUM_DEF` must be a struct type, got type `{s}`", .{@typeName(ENUM_DEF)});
    assert_with_reason(Types.type_is_struct(UNNAMED_DEF), @src(), "type `UNNAMED_DEF` must be a struct type, got type `{s}`", .{@typeName(UNNAMED_DEF)});
    assert_with_reason(@hasField(ENUM_DEF, ENUM_DEF_NAME_FIELD), @src(), "type `ENUM_DEF` must have a field named `{s}`", .{ENUM_DEF_NAME_FIELD});
    assert_with_reason(@FieldType(ENUM_DEF, ENUM_DEF_NAME_FIELD) == ENUM, @src(), "type `ENUM_DEF` field `{s}` must be type `{s}`, got type `{s}`", .{ ENUM_DEF_NAME_FIELD, @typeName(ENUM_DEF), @typeName(@FieldType(ENUM_DEF, ENUM_DEF_NAME_FIELD)) });
    assert_with_reason(@typeInfo(ENUM_DEF).@"struct".fields.len - 1 == @typeInfo(UNNAMED_DEF).@"struct".fields.len, @src(), "type `ENUM_DEF` must have 1 more field than `UNNAMED_DEF` (the enum field `{s}`), got {d} - 1 != {d}", .{ @typeInfo(ENUM_DEF).@"struct".fields.len, @typeInfo(UNNAMED_DEF).@"struct".fields.len });
    inline for (@typeInfo(UNNAMED_DEF).@"struct".fields) |field| {
        assert_with_reason(@hasField(ENUM_DEF, field.name), @src(), "mismatched fields: `ENUM_DEF` does not have field `{s}` (on `UNNAMED_DEF` struct)", .{field.name});
        assert_with_reason(@FieldType(ENUM_DEF, field.name) == @FieldType(UNNAMED_DEF, field.name), @src(), "field `{s}` is a different type on `ENUM_DEF` and `UNNAMED_DEF` (`{s}` != `{s}`)", .{ field.name, @typeName(@FieldType(ENUM_DEF, field.name)), @typeName(@FieldType(UNNAMED_DEF, field.name)) });
    }
    return struct {
        pub fn build_ordered(comptime enumerated: [NUM_DEFS]ENUM_DEF, userdata_for_extra_validation: anytype, comptime extra_validations: ?*const fn (item: ENUM_DEF, userdata: @TypeOf(userdata_for_extra_validation)) void) [NUM_DEFS]UNNAMED_DEF {
            comptime var out: [NUM_DEFS]UNNAMED_DEF = undefined;
            comptime var done: [NUM_DEFS]bool = @splat(false);
            inline for (enumerated[0..]) |def| {
                const idx = @intFromEnum(@field(def, ENUM_DEF_NAME_FIELD));
                assert_with_reason(done[idx] == false, @src(), "definition name `{s}` was defined more than once", .{@tagName(@field(def, ENUM_DEF_NAME_FIELD))});
                done[idx] = true;
                if (extra_validations) |validate| {
                    validate(def, userdata_for_extra_validation);
                }
                inline for (@typeInfo(UNNAMED_DEF).@"struct".fields) |field| {
                    @field(out[idx], field.type) = @field(def, field.name);
                }
            }
            return out;
        }
        pub const NUM_DEFS = Types.enum_defined_field_count(ENUM);
        pub const ENUMERATED_LIST = [NUM_DEFS]ENUM_DEF;
        pub const UNNAMED_LIST = [NUM_DEFS]UNNAMED_DEF;
    };
}
