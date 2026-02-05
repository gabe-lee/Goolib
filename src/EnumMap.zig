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
const Type = std.builtin.Type;
const meta = std.meta;
const math = std.math;
const Log2Int = math.Log2Int;
const Log2IntCeil = math.Log2IntCeil;

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const Assert = Root.Assert;
const Types = Root.Types;
const num_cast = Root.Cast.num_cast;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

pub fn EnumMap(comptime ENUM: type, comptime T: type) type {
    assert_with_reason(Types.type_is_enum(ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(ENUM), @src(), "type `ENUM` must be an enum type with tag values from 0 to max value with no gaps, got type `{s}`", .{@typeName(ENUM)});
    return struct {
        const Self = @This();

        map: [Types.enum_defined_field_count(ENUM)]T = undefined,

        pub fn get(self: Self, tag: ENUM) T {
            return self.map[@intFromEnum(tag)];
        }
        pub fn get_indirect(self: *const Self, tag: ENUM) T {
            return self.map[@intFromEnum(tag)];
        }
        pub fn get_ptr(self: *Self, tag: ENUM) *T {
            return &self.map[@intFromEnum(tag)];
        }
        pub fn get_ptr_const(self: *const Self, tag: ENUM) *const T {
            return &self.map[@intFromEnum(tag)];
        }
        pub fn set(self: *Self, tag: ENUM, val: T) void {
            self.map[@intFromEnum(tag)] = val;
        }
    };
}

pub fn EnumMapOfMaps(comptime ENUM_PRIMARY: type, comptime ENUM_SECONDARY: [Types.enum_defined_field_count(ENUM_PRIMARY)]type, comptime T: type) type {
    assert_with_reason(Types.type_is_enum(ENUM_PRIMARY) and Types.all_enum_values_start_from_zero_with_no_gaps(ENUM_PRIMARY), @src(), "type `ENUM` must be an enum type with tag values from 0 to max value with no gaps, got type `{s}`", .{@typeName(ENUM_PRIMARY)});
    const num_primary = Types.enum_defined_field_count(ENUM_PRIMARY);
    comptime var total_enums: usize = 0;
    comptime var secondary_offsets: [num_primary]usize = @splat(0);
    inline for (0..num_primary) |S| {
        assert_with_reason(Types.type_is_enum(ENUM_SECONDARY[S]) and Types.all_enum_values_start_from_zero_with_no_gaps(ENUM_SECONDARY[S]), @src(), "type `ENUM_SECONDARY[{d}]` must be an enum type with tag values from 0 to max value with no gaps, got type `{s}`", .{ S, @typeName(ENUM_SECONDARY[S]) });
        secondary_offsets[S] = total_enums;
        total_enums += Types.enum_defined_field_count(ENUM_SECONDARY[S]);
    }
    const total_enums_const = total_enums;
    const secondary_offsets_const = secondary_offsets;
    return struct {
        const Self = @This();

        map: [TOTAL_ENUMS]T = undefined,

        const TOTAL_ENUMS = total_enums_const;
        const SECONDARY_OFFSETS = secondary_offsets_const;
        const NUM_PRIMARY = num_primary;
        const SECONDARY_TAGS = ENUM_SECONDARY;

        pub fn sub_map(self: *Self, comptime primary: ENUM_PRIMARY) SubMap(SECONDARY_TAGS[@intFromEnum(primary)]) {
            return SubMap(SECONDARY_TAGS[@intFromEnum(primary)]){
                .map = @ptrCast(&self.map[SECONDARY_OFFSETS[@intFromEnum(primary)]]),
            };
        }

        pub fn get(self: Self, comptime primary: ENUM_PRIMARY, secondary: SECONDARY_TAGS[@intFromEnum(primary)]) T {
            const idx = SECONDARY_OFFSETS[@intFromEnum(primary)] + num_cast(@intFromEnum(secondary), usize);
            return self.map[idx];
        }
        pub fn get_indirect(self: *const Self, comptime primary: ENUM_PRIMARY, secondary: SECONDARY_TAGS[@intFromEnum(primary)]) T {
            const idx = SECONDARY_OFFSETS[@intFromEnum(primary)] + num_cast(@intFromEnum(secondary), usize);
            return self.map[idx];
        }
        pub fn get_ptr(self: *Self, comptime primary: ENUM_PRIMARY, secondary: SECONDARY_TAGS[@intFromEnum(primary)]) *T {
            const idx = SECONDARY_OFFSETS[@intFromEnum(primary)] + num_cast(@intFromEnum(secondary), usize);
            return &self.map[idx];
        }
        pub fn get_ptr_const(self: *const Self, comptime primary: ENUM_PRIMARY, secondary: SECONDARY_TAGS[@intFromEnum(primary)]) *const T {
            const idx = SECONDARY_OFFSETS[@intFromEnum(primary)] + num_cast(@intFromEnum(secondary), usize);
            return &self.map[idx];
        }
        pub fn set(self: *Self, comptime primary: ENUM_PRIMARY, secondary: SECONDARY_TAGS[@intFromEnum(primary)], val: T) void {
            const idx = SECONDARY_OFFSETS[@intFromEnum(primary)] + num_cast(@intFromEnum(secondary), usize);
            self.map[idx] = val;
        }

        pub fn SubMap(comptime ENUM: type) type {
            assert_with_reason(Types.type_is_enum(ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(ENUM), @src(), "type `ENUM` must be an enum type with tag values from 0 to max value with no gaps, got type `{s}`", .{@typeName(ENUM)});
            return struct {
                const Self2 = @This();

                map: [*]T = undefined,

                pub fn get(self: Self2, tag: ENUM) T {
                    return self.map[@intFromEnum(tag)];
                }
                pub fn get_indirect(self: *const Self2, tag: ENUM) T {
                    return self.map[@intFromEnum(tag)];
                }
                pub fn get_ptr(self: *Self2, tag: ENUM) *T {
                    return &self.map[@intFromEnum(tag)];
                }
                pub fn get_ptr_const(self: *const Self2, tag: ENUM) *const T {
                    return &self.map[@intFromEnum(tag)];
                }
                pub fn set(self: *Self2, tag: ENUM, val: T) void {
                    self.map[@intFromEnum(tag)] = val;
                }
            };
        }
    };
}

test "enum map" {
    const Test = Root.Testing;
    const People = EnumMap(enum {
        DOUG,
        GREG,
        STEVE,
    }, struct {
        age: u32,
        height: f32,
    });
    var people = People{};
    people.set(.STEVE, .{ .age = 27, .height = 108 });
    people.set(.GREG, .{ .age = 55, .height = 123 });
    people.set(.DOUG, .{ .age = 84, .height = 91 });
    try Test.expect_equal(people.get(.DOUG).height, "people.get(.DOUG).height", 91, "91", "wrong val", .{});
}

test "enum map of maps type 1" {
    const Test = Root.Testing;
    const Children = EnumMapOfMaps(enum {
        DOUG,
        GREG,
        STEVE,
    }, .{
        enum {
            MAUD,
            PRISCILLA,
        },
        enum {
            KATHY,
            RICHARD,
        },
        enum {
            DAVE,
            TYSON,
            MIKE,
        },
    }, struct {
        age: u32,
        height: f32,
    });
    var children = Children{};
    children.set(.DOUG, .MAUD, .{
        .age = 99,
        .height = 88,
    });

    try Test.expect_equal(children.get(.DOUG, .MAUD).age, "children.get(.DOUG, .MAUD).age", 99, "99", "wrong val", .{});
    var mike = children.sub_map(.STEVE);
    mike.set(.MIKE, .{ .age = 4, .height = 32 });
    try Test.expect_equal(children.get(.STEVE, .MIKE).height, "children.get(.STEVE, .MIKE).height", 32, "32", "wrong val", .{});
}
