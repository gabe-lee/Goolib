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
const meta = std.meta;
const math = std.math;
const Log2Int = math.Log2Int;
const Log2IntCeil = math.Log2IntCeil;

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const Types = Root.Types;
const Assert = Root.Assert;
const MathX = Root.Math;
const assert_with_reason = Assert.assert_with_reason;
const Kind = Root.Types.Kind;
const KindInfo = Root.Types.KindInfo;
const num_cast = Root.Cast.num_cast;
const bit_cast = Root.Cast.bit_cast;
const int_cast_log2 = Root.Cast.int_cast_log2;
const int_cast_log2_ceil = Root.Cast.int_cast_log2_ceil;

/// This is an alternative to a packed struct containing a set of enum fields.
///
/// It evaluates the minimum and maximum non-zero bit patterns for each enum,
/// then creates an aggregate integer that can hold
/// all bit-patterns side-by-side and puts it on a struct type
/// with get/set methods to extract the individual enum values
/// from the raw integer
///
/// `ENUMS` must be a *TAGGED UNION* type, where each union field
/// is an *ENUM* type. This type is not used directly in the final
/// result, but is used as a convenient comptime way to map an enum
/// tag to various other enum types.
///
/// As a special feature, an enum can define a declaration of
/// `pub const ZIGZAG_ENCODE = true;` to perform automatic
/// zig-zag encoding on the enum values. This can allow enums
/// with signed integer tag types but relatively small
/// absolute tag values to be compressed in a more compact
/// way, at the cost of some additional processing time
/// (a round-trip is 3 bit-shifts, 2 xors, 1 bitwise-and, 1 arithmetic negation)
pub fn CompositeEnum(comptime ENUMS: anytype) type {
    // const T_ENUMS = @TypeOf(ENUMS);
    Kind.UNION.assert_type_is_same_kind(ENUMS, @src());
    const ENUMS_INFO = KindInfo.get_kind_info(ENUMS).UNION;
    assert_with_reason(ENUMS_INFO.tag_type != null, @src(), "`ENUMS` must be a tagged-union type, got an untagged-union type `{s}`", .{@typeName(ENUMS)});
    const ENUM_NAMES = ENUMS_INFO.tag_type.?;
    const ENUM_NAMES_INFO = KindInfo.get_kind_info(ENUM_NAMES).ENUM;
    assert_with_reason(Types.all_enum_values_start_from_zero_with_no_gaps(ENUM_NAMES), @src(), "all enum tag values on the tagged-union type `ENUMS` must start from 0 with no gaps while increasing to the max tag value", .{});
    const NUM_ENUMS = ENUMS_INFO.fields.len;
    comptime var ENUM_TYPES: [NUM_ENUMS]type = undefined;
    inline for (ENUMS_INFO.fields) |u_field| {
        Kind.ENUM.assert_type_is_same_kind(u_field.type, @src());
        const tag_val = find: {
            inline for (ENUM_NAMES_INFO.fields) |e_field| {
                if (std.mem.eql(u8, u_field.name, e_field.name)) {
                    break :find e_field.value;
                }
            }
            unreachable;
        };
        ENUM_TYPES[tag_val] = u_field.type;
    }
    comptime var ENUM_BIT_COUNTS: [NUM_ENUMS]u16 = @splat(0);
    comptime var ENUM_TAG_TYPES: [NUM_ENUMS]type = undefined;
    comptime var ENUM_TAG_TYPES_RAW: [NUM_ENUMS]type = undefined;
    comptime var ENUM_VAL_SHIFTS_UP_FROM_ZERO: [NUM_ENUMS]u16 = undefined;
    comptime var ENUM_VAL_SHIFTS_DOWN_FROM_COMPOSITE: [NUM_ENUMS]u16 = undefined;
    comptime var ENUM_ZIGZAGS: [NUM_ENUMS]bool = @splat(false);
    comptime var TOTAL_BIT_COUNT: u16 = 0;
    inline for (0..NUM_ENUMS) |i| {
        const E_TYPE = ENUM_TYPES[i];
        const E_INFO = KindInfo.get_kind_info(E_TYPE).ENUM;
        const E_INT = E_INFO.tag_type;
        const E_INT_INFO = KindInfo.get_kind_info(E_INT).INT;
        const E_INT_BITS = E_INT_INFO.bits;
        ENUM_TAG_TYPES[i] = E_INT;
        const E_INT_RAW = @Type(std.builtin.Type{ .int = .{ .bits = E_INT_INFO.bits, .signedness = .unsigned } });
        ENUM_TAG_TYPES_RAW[i] = E_INT_RAW;
        comptime var COMPOSITE: E_INT_RAW = 0;
        comptime var HAS_NONZERO: bool = false;
        const DO_ZIGZAG = @hasDecl(E_TYPE, "ZIGZAG_ENCODE") and @TypeOf(@field(E_TYPE, "ZIGZAG_ENCODE")) == bool and @field(E_TYPE, "ZIGZAG_ENCODE") == true;
        if (E_INFO.is_exhaustive) {
            ENUM_ZIGZAGS[i] = DO_ZIGZAG;
            inline for (E_INFO.fields) |e_field| {
                const val: E_INT = e_field.value;
                const val_raw: E_INT_RAW = if (DO_ZIGZAG) @bitCast(MathX.zig_zag_encode(val)) else @bitCast(val);
                if (val_raw != 0) {
                    HAS_NONZERO = true;
                    COMPOSITE |= val_raw;
                }
            }
        } else {
            HAS_NONZERO = true;
            COMPOSITE = math.maxInt(E_INT_RAW);
        }
        assert_with_reason(HAS_NONZERO, @src(), "enum `{s}` has only the value `0`, not eligible for inclusion in a CompositeEnum", .{@typeName(E_TYPE)});
        const COMPOSITE_TRAILING_ZEROS = @ctz(COMPOSITE);
        ENUM_VAL_SHIFTS_UP_FROM_ZERO[i] = @intCast(COMPOSITE_TRAILING_ZEROS);
        COMPOSITE >>= int_cast_log2(COMPOSITE_TRAILING_ZEROS, E_INT_RAW);
        const COMPOSITE_LEADING_ZEROES = @clz(COMPOSITE);
        const COMPOSITE_TOTAL_BITS = E_INT_BITS - num_cast(COMPOSITE_LEADING_ZEROES, u16);
        ENUM_BIT_COUNTS[i] = COMPOSITE_TOTAL_BITS;
        ENUM_VAL_SHIFTS_DOWN_FROM_COMPOSITE[i] = TOTAL_BIT_COUNT;
        TOTAL_BIT_COUNT += COMPOSITE_TOTAL_BITS;
    }
    const RAW_INT = std.meta.Int(.unsigned, TOTAL_BIT_COUNT);
    const RAW_SHIFT_INT = Log2Int(RAW_INT);
    comptime var TRUE_SHIFTS: [NUM_ENUMS]RAW_SHIFT_INT = undefined;
    comptime var VAL_MASKS: [NUM_ENUMS]RAW_INT = undefined;
    comptime var VAL_MASKS_INVERSE: [NUM_ENUMS]RAW_INT = undefined;
    comptime var SHIFTS_DOWN: [NUM_ENUMS]bool = undefined;
    inline for (0..NUM_ENUMS) |i| {
        const SHIFT_UP_FROM_ZERO: RAW_SHIFT_INT = @intCast(ENUM_VAL_SHIFTS_UP_FROM_ZERO[i]);
        const SHIFT_DOWN_FROM_COMPOSITE: RAW_SHIFT_INT = @intCast(ENUM_VAL_SHIFTS_DOWN_FROM_COMPOSITE[i]);
        const BIT_COUNT: RAW_SHIFT_INT = @intCast(ENUM_BIT_COUNTS[i]);
        const MASK = ((@as(RAW_INT, 1) << BIT_COUNT) - 1) << SHIFT_DOWN_FROM_COMPOSITE;
        const SHIFT_DOWN = SHIFT_DOWN_FROM_COMPOSITE >= SHIFT_UP_FROM_ZERO;
        SHIFTS_DOWN[i] = SHIFT_DOWN;
        const SHIFT = if (SHIFT_DOWN) (SHIFT_DOWN_FROM_COMPOSITE - SHIFT_UP_FROM_ZERO) else (SHIFT_UP_FROM_ZERO - SHIFT_DOWN_FROM_COMPOSITE);
        TRUE_SHIFTS[i] = SHIFT;
        VAL_MASKS[i] = MASK;
        VAL_MASKS_INVERSE[i] = ~MASK;
    }
    const ENUM_TYPES_CONST = ENUM_TYPES;
    const ENUM_TAG_TYPES_RAW_CONST = ENUM_TAG_TYPES_RAW;
    const ENUM_TAG_TYPES_CONST = ENUM_TAG_TYPES;
    const ZIGZAG_CONST = ENUM_ZIGZAGS;
    const SHIFTS_CONST = TRUE_SHIFTS;
    const MASKS_CONST = VAL_MASKS;
    const INVERSE_MASKS_CONST = VAL_MASKS_INVERSE;
    const SHIFTS_DOWN_CONST = SHIFTS_DOWN;
    return enum(RAW_INT) {
        _,

        const Self = @This();
        pub const EnumName = ENUM_NAMES;
        const ZIGZAG = ZIGZAG_CONST;
        const FULL_SHIFT = SHIFTS_CONST;
        const FULL_SHIFT_DOWN = SHIFTS_DOWN_CONST;
        const TYPES = ENUM_TYPES_CONST;
        const TAG_RAW_TYPES = ENUM_TAG_TYPES_RAW_CONST;
        const TAG_TYPES = ENUM_TAG_TYPES_CONST;
        const MASK = MASKS_CONST;
        const INVERSE_MASK = INVERSE_MASKS_CONST;
        const RAW = RAW_INT;

        pub inline fn EnumForName(comptime enum_name: EnumName) type {
            return TYPES[@intFromEnum(enum_name)];
        }

        pub fn get(self: Self, comptime enum_name: EnumName) EnumForName(enum_name) {
            const IDX = comptime @intFromEnum(enum_name);
            var raw: RAW = @intFromEnum(self);
            raw &= MASK[IDX];
            if (FULL_SHIFT_DOWN[IDX]) {
                raw >>= FULL_SHIFT[IDX];
            } else {
                raw <<= FULL_SHIFT[IDX];
            }
            const raw_typed: TAG_RAW_TYPES[IDX] = @intCast(raw);
            const tag_typed = if (ZIGZAG[IDX]) MathX.zig_zag_decode(TAG_TYPES[IDX], raw_typed) else bit_cast(raw_typed, TAG_TYPES[IDX]);
            return @enumFromInt(tag_typed);
        }

        pub fn set(self: *Self, comptime enum_name: EnumName, val: EnumForName(enum_name)) void {
            const IDX = comptime @intFromEnum(enum_name);
            const tag_typed: TAG_TYPES[IDX] = @intFromEnum(val);
            const raw_typed: TAG_RAW_TYPES[IDX] = if (ZIGZAG[IDX]) bit_cast(MathX.zig_zag_encode(tag_typed), TAG_RAW_TYPES[IDX]) else @bitCast(tag_typed);
            var new_raw: RAW = @intCast(raw_typed);
            if (FULL_SHIFT_DOWN[IDX]) {
                new_raw <<= FULL_SHIFT[IDX];
            } else {
                new_raw >>= FULL_SHIFT[IDX];
            }
            var old_raw: RAW = @intFromEnum(self.*);
            old_raw &= INVERSE_MASK[IDX];
            old_raw |= new_raw;
            self.* = @enumFromInt(old_raw);
        }

        pub inline fn with_enum_set(self: Self, comptime enum_name: EnumName, val: EnumForName(enum_name)) Self {
            var new_self = self;
            new_self.set(enum_name, val);
            return new_self;
        }
    };
}

test CompositeEnum {
    const Test = Root.Testing;
    const E1 = enum(u1) {
        t,
        f,
    };
    const E2 = enum(u2) {
        a,
        b,
        c,
        d,
    };
    const E3 = enum(u11) {
        x = 0b000_0001_0000,
        y = 0b000_1000_0000,
    };
    const E4 = enum(i16) {
        _,

        pub const ZIGZAG_ENCODE = true;
    };
    const E5 = enum(u7) {
        _,
    };
    const E6 = enum(i3) {
        u = -1,
        v = 0,
        w = 1,
    };
    const U = union(enum) {
        ENUM_1: E1,
        ENUM_2: E2,
        ENUM_5: E5,
        ENUM_3: E3,
        ENUM_4: E4,
        ENUM_6: E6,
    };
    const CE = CompositeEnum(U);
    var ce: CE = undefined;
    const rand = Root.Rand.seed_default_rand_time_now_and_get();
    const NUM_TESTS = 100;
    for (0..NUM_TESTS) |_| {
        const e1_raw = rand.int(u1);
        const e2_raw = rand.int(u2);
        const e3_bool = rand.boolean();
        const e4_raw = rand.int(i16);
        const e5_raw = rand.int(u7);
        const e6_raw = rand.intRangeAtMost(i3, -1, 1);
        const e1_exp: E1 = @enumFromInt(e1_raw);
        const e2_exp: E2 = @enumFromInt(e2_raw);
        const e3_exp: E3 = if (e3_bool) E3.x else E3.y;
        const e4_exp: E4 = @enumFromInt(e4_raw);
        const e5_exp: E5 = @enumFromInt(e5_raw);
        const e6_exp: E6 = @enumFromInt(e6_raw);
        ce.set(.ENUM_1, e1_exp);
        ce.set(.ENUM_2, e2_exp);
        ce.set(.ENUM_3, e3_exp);
        ce.set(.ENUM_4, e4_exp);
        ce.set(.ENUM_5, e5_exp);
        ce.set(.ENUM_6, e6_exp);
        const e1_got = ce.get(.ENUM_1);
        const e2_got = ce.get(.ENUM_2);
        const e3_got = ce.get(.ENUM_3);
        const e4_got = ce.get(.ENUM_4);
        const e5_got = ce.get(.ENUM_5);
        const e6_got = ce.get(.ENUM_6);
        try Test.expect_equal(e1_exp, "e1_expect", e1_got, "e1_got", "fail", .{});
        try Test.expect_equal(e2_exp, "e2_expect", e2_got, "e2_got", "fail", .{});
        try Test.expect_equal(e3_exp, "e3_expect", e3_got, "e3_got", "fail", .{});
        try Test.expect_equal(e4_exp, "e4_expect", e4_got, "e4_got", "fail", .{});
        try Test.expect_equal(e5_exp, "e5_expect", e5_got, "e5_got", "fail", .{});
        try Test.expect_equal(e6_exp, "e6_expect", e6_got, "e6_got", "fail", .{});
    }
}
