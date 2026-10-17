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
const int_cast_log2 = Root.Cast.int_cast_log2;
const int_cast_log2_ceil = Root.Cast.int_cast_log2_ceil;

pub fn Flags(comptime FLAGS_ENUM: type, comptime GROUPS_ENUM: type) type {
    const INFO_1 = @typeInfo(FLAGS_ENUM);
    assert_with_reason(INFO_1 == .@"enum", @src(), "parameter `FLAGS_ENUM` must be an enum type", .{});
    const E_INFO = INFO_1.@"enum";
    assert_with_reason(@typeInfo(E_INFO.tag_type).int.signedness == .unsigned, @src(), "parameter `FLAGS_ENUM` tag type must be an unsigned integer type", .{});
    const INFO_2 = @typeInfo(GROUPS_ENUM);
    assert_with_reason(INFO_2 == .@"enum", @src(), "parameter `GROUPS` must be an enum type (possibly empty)", .{});
    const G_INFO = INFO_2.@"enum";
    assert_with_reason(G_INFO.tag_type == E_INFO.tag_type, @src(), "parameter `GROUPS` must have the exact same tag type as `FLAGS_ENUM`", .{});
    const F: E_INFO.tag_type = @as(E_INFO.tag_type, math.maxInt(meta.Int(.unsigned, @bitSizeOf(E_INFO.tag_type))));
    const A: E_INFO.tag_type = combine: {
        if (!E_INFO.is_exhaustive) break :combine F;
        var a: E_INFO.tag_type = 0;
        for (E_INFO.fields) |field| {
            a |= field.value;
        }
        break :combine a;
    };
    for (G_INFO.fields) |group_field| {
        assert_with_reason(group_field.value & ~A == 0, @src(), "group `{s}` has invalid bits for flags enum:\nbits to set = {b:0>64}\nvalid range = {b:0>64}\ninvalid pos = {b:0>64}", .{ group_field.name, group_field.value, A, group_field.value & ~A });
    }
    return extern struct {
        raw: RawInt = 0,

        const Self = @This();
        pub const RawInt: type = E_INFO.tag_type;
        pub const BitIndex = Log2Int(RawInt);
        pub const BitCount = Log2IntCeil(RawInt);
        pub const Flag = FLAGS_ENUM;
        pub const Group = GROUPS_ENUM;
        pub const ALL = Self{ .raw = A };
        pub const FLOOD = Self{ .raw = math.maxInt(RawInt) };
        const FULL = F;
        const NEEDS_VALID_ASSERT = A != FULL;

        inline fn assert_valid_bits(raw: RawInt) void {
            if (NEEDS_VALID_ASSERT) {
                assert_with_reason(raw & ~A == 0, @src(), "invalid bits for flags type {s}:\nbits to set = {b:0>64}\nvalid range = {b:0>64}\ninvalid pos = {b:0>64}", .{ @typeName(Self), raw, A, raw & ~A });
            }
        }

        inline fn bits(flag_or_group: anytype) RawInt {
            return @intFromEnum(flag_or_group);
        }
        inline fn inv_bits(flag_or_group: anytype) RawInt {
            return ~@intFromEnum(flag_or_group);
        }
        inline fn ctz(flag_or_group: anytype) BitCount {
            return @ctz(@intFromEnum(flag_or_group));
        }
        inline fn clz(flag_or_group: anytype) BitCount {
            return @clz(@intFromEnum(flag_or_group));
        }
        inline fn bit_count(flag_or_group: anytype) BitCount {
            return @popCount(@intFromEnum(flag_or_group));
        }

        pub inline fn blank() Self {
            return Self{ .raw = 0 };
        }
        pub inline fn all() Self {
            return ALL;
        }
        pub inline fn flood() Self {
            return FLOOD;
        }

        /// current flags must EXACTLY match one of the tags in the enum set
        pub fn flag_name(self: Self) []const u8 {
            const tag: Flag = @enumFromInt(self.raw);
            return @tagName(tag);
        }

        pub fn from_flag(flag: Flag) Self {
            return Self{ .raw = @intFromEnum(flag) };
        }
        pub fn from_flags(flags: []const Flag) Self {
            var self = Self{ .raw = 0 };
            for (flags) |flag| {
                self.raw |= @intFromEnum(flag);
            }
            return self;
        }
        pub fn from_full_group(group: Group) Self {
            return Self{ .raw = @intFromEnum(group) };
        }
        pub fn from_combined_full_groups(groups: []const Group) Self {
            var self = Self{ .raw = 0 };
            for (groups) |group| {
                self.raw |= @intFromEnum(group);
            }
            return self;
        }
        pub inline fn from_raw(val: RawInt) Self {
            assert_valid_bits(val);
            return Self{ .raw = val };
        }
        pub fn from_raws(raws: []const RawInt) Self {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            assert_valid_bits(composite);
            return Self{ .raw = composite };
        }
        pub inline fn from_bit(bit_index: BitIndex) Self {
            const raw = @as(RawInt, 1) << bit_index;
            assert_valid_bits(raw);
            return Self{ .raw = @as(RawInt, 1) << bit_index };
        }
        pub fn from_bits(bit_indexes: []const BitIndex) Self {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= @as(RawInt, 1) << index;
            }
            assert_valid_bits(composite);
            return Self{ .raw = composite };
        }
        pub inline fn copy(self: Self) Self {
            return Self{ .raw = self.raw };
        }

        pub inline fn combine_with(self: *Self, other: Self) void {
            self.raw |= other.raw;
        }

        pub inline fn set(self: *Self, flag: Flag) void {
            self.raw |= bits(flag);
        }
        pub inline fn set_one_bit_if_true(self: *Self, flag: Flag, state: bool) void {
            const off = ctz(flag);
            const bit_lo: RawInt = @intCast(@intFromBool(state));
            const bit = bit_lo << off;
            self.raw |= bit;
        }
        pub inline fn clear_one_bit_if_false(self: *Self, flag: Flag, state: bool) void {
            const off = ctz(flag);
            const bit_lo: RawInt = @intCast(@intFromBool(state));
            const bit = bit_lo << off;
            self.raw &= ~bit;
        }
        pub inline fn set_or_clear_one_bit_from_bool(self: *Self, flag: Flag, state: bool) void {
            const off = ctz(flag);
            const bit_lo: RawInt = @intCast(@intFromBool(state));
            const bit = bit_lo << off;
            const mask = 1 << off;
            self.raw &= ~mask;
            self.raw |= bit;
        }
        pub inline fn set_raw(self: *Self, raw: RawInt) void {
            assert_valid_bits(raw);
            self.raw |= raw;
        }
        pub inline fn set_bit(self: *Self, bit_index: BitIndex) void {
            const raw = (@as(RawInt, 1) << bit_index);
            assert_valid_bits(raw);
            self.raw |= raw;
        }
        pub inline fn set_many(self: *Self, flags: []const Flag) void {
            for (flags) |flag| {
                self.raw |= bits(flag);
            }
        }
        pub inline fn set_many_raw(self: *Self, raws: []const RawInt) void {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            assert_valid_bits(composite);
            self.raw = composite;
        }
        pub inline fn set_many_bits(self: *Self, bit_indexes: []const BitIndex) void {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= @as(RawInt, 1) << index;
            }
            assert_valid_bits(composite);
            self.raw = composite;
        }

        pub inline fn clear_group_then_set(self: *Self, group: Group, flag: Flag) void {
            self.raw &= inv_bits(group);
            self.raw |= bits(flag);
        }
        pub inline fn clear_group_then_set_raw(self: *Self, group: Group, raw: RawInt) void {
            self.raw &= inv_bits(group);
            self.raw |= raw;
        }
        pub inline fn clear_group_then_set_many(self: *Self, group: Group, flags: []const Flag) void {
            self.raw &= inv_bits(group);
            for (flags) |flag| {
                self.raw |= bits(flag);
            }
        }
        pub inline fn clear_many_groups_then_set_many(self: *Self, groups: []const Group, flags: []const Flag) void {
            for (groups) |group| {
                self.raw &= inv_bits(group);
            }
            for (flags) |flag| {
                self.raw |= bits(flag);
            }
        }

        pub inline fn clear_all(self: *Self) void {
            self.raw = 0;
        }
        pub inline fn clear(self: *Self, flag: Flag) void {
            self.raw &= inv_bits(flag);
        }
        pub inline fn clear_many(self: *Self, flags: []const Flag) void {
            for (flags) |flag| {
                self.raw &= inv_bits(flag);
            }
        }
        pub inline fn clear_raw(self: *Self, raw: RawInt) void {
            self.raw &= ~raw;
        }
        pub inline fn clear_many_raw(self: *Self, raws: []const RawInt) void {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            self.raw &= ~composite;
        }
        pub inline fn clear_bit(self: *Self, bit_index: BitIndex) void {
            self.raw &= ~(@as(RawInt, 1) << bit_index);
        }
        pub inline fn clear_many_bits(self: *Self, bit_indexes: []const BitIndex) void {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= (@as(RawInt, 1) << index);
            }
            self.raw &= ~composite;
        }
        pub inline fn has_flag(self: Self, flag: Flag) bool {
            return self.raw & bits(flag) == bits(flag);
        }
        pub inline fn missing_flag(self: Self, flag: Flag) bool {
            return self.raw & bits(flag) == 0;
        }
        pub inline fn has_only_this_flag(self: Self, flag: Flag) bool {
            return self.raw == bits(flag);
        }
        pub inline fn has_all_flags(self: Self, flags: []const Flag) bool {
            var composite: RawInt = 0;
            for (flags) |flag| {
                composite |= bits(flag);
            }
            return self.raw & composite == composite;
        }
        pub inline fn has_only_these_flags(self: Self, flags: []const Flag) bool {
            var composite: RawInt = 0;
            for (flags) |flag| {
                composite |= bits(flag);
            }
            return self.raw == composite;
        }
        pub inline fn has_none_of_these_flags(self: Self, flags: []const Flag) bool {
            var composite: RawInt = 0;
            for (flags) |flag| {
                composite |= bits(flag);
            }
            return self.raw & composite == 0;
        }
        pub inline fn has_any_of_these_flags(self: Self, flags: []const Flag) bool {
            var composite: RawInt = 0;
            for (flags) |flag| {
                composite |= bits(flag);
            }
            return self.raw & composite > 0;
        }
        pub inline fn has_flag_in_group(self: Self, flag: Flag, group: Group) bool {
            return self.raw & bits(group) & bits(flag) == bits(flag);
        }
        pub inline fn has_only_flag_in_group(self: Self, flag: Flag, group: Group) bool {
            return self.raw & bits(group) == bits(flag);
        }
        pub inline fn has_all_flags_in_group(self: Self, flags: []const Flag, group: Group) bool {
            var composite: RawInt = 0;
            for (flags) |flag| {
                composite |= bits(flag);
            }
            return self.raw & bits(group) & composite == composite;
        }
        pub inline fn has_only_these_flags_in_group(self: Self, flags: []const Flag, group: Group) bool {
            var composite: RawInt = 0;
            for (flags) |flag| {
                composite |= bits(flag);
            }
            return self.raw & bits(group) == composite;
        }
        pub inline fn has_none_of_these_flags_in_group(self: Self, flags: []const Flag, group: Group) bool {
            var composite: RawInt = 0;
            for (flags) |flag| {
                composite |= bits(flag);
            }
            return self.raw & bits(group) & composite == 0;
        }
        pub inline fn has_any_of_these_flags_in_group(self: Self, flags: []const Flag, group: Group) bool {
            var composite: RawInt = 0;
            for (flags) |flag| {
                composite |= bits(flag);
            }
            return self.raw & bits(group) & composite > 0;
        }
        pub inline fn has_raw(self: Self, raw: RawInt) bool {
            return self.raw & raw == raw;
        }
        pub inline fn has_only_raw(self: Self, raw: RawInt) bool {
            return self.raw == raw;
        }
        pub inline fn has_all_raws(self: Self, raws: []const RawInt) bool {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            return self.raw & composite == composite;
        }
        pub inline fn has_only_these_raws(self: Self, raws: []const RawInt) bool {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            return self.raw == composite;
        }
        pub inline fn has_none_of_these_raws(self: Self, raws: []const RawInt) bool {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            return self.raw & composite == 0;
        }
        pub inline fn has_any_of_these_raws(self: Self, raws: []const RawInt) bool {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            return self.raw & composite > 0;
        }
        pub inline fn has_raw_in_group(self: Self, raw: RawInt, group: Group) bool {
            return self.raw & bits(group) & raw == raw;
        }
        pub inline fn has_only_raw_in_group(self: Self, raw: RawInt, group: Group) bool {
            return self.raw & bits(group) == raw;
        }
        pub inline fn has_all_raws_in_group(self: Self, raws: []const RawInt, group: Group) bool {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            return self.raw & bits(group) & composite == composite;
        }
        pub inline fn has_only_these_raws_in_group(self: Self, raws: []const RawInt, group: Group) bool {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            return self.raw & bits(group) == composite;
        }
        pub inline fn has_none_of_these_raws_in_group(self: Self, raws: []const RawInt, group: Group) bool {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            return self.raw & bits(group) & composite == 0;
        }
        pub inline fn has_any_of_these_raws_in_group(self: Self, raws: []const RawInt, group: Group) bool {
            var composite: RawInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            return self.raw & bits(group) & composite > 0;
        }
        pub inline fn has_bit(self: Self, bit_index: BitIndex) bool {
            const bit = (@as(RawInt, 1) << bit_index);
            return self.raw & bit == bit;
        }
        pub inline fn has_only_bit(self: Self, bit_index: BitIndex) bool {
            const bit = (@as(RawInt, 1) << bit_index);
            return self.raw == bit;
        }
        pub inline fn has_all_bits(self: Self, bit_indexes: []const BitIndex) bool {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= (@as(RawInt, 1) << index);
            }
            return self.raw & composite == composite;
        }
        pub inline fn has_only_these_bits(self: Self, bit_indexes: []const BitIndex) bool {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= (@as(RawInt, 1) << index);
            }
            return self.raw == composite;
        }
        pub inline fn has_none_of_these_bits(self: Self, bit_indexes: []const BitIndex) bool {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= (@as(RawInt, 1) << index);
            }
            return self.raw & composite == 0;
        }
        pub inline fn has_any_of_these_bits(self: Self, bit_indexes: []const BitIndex) bool {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= (@as(RawInt, 1) << index);
            }
            return self.raw & composite > 0;
        }
        pub inline fn has_bit_in_group(self: Self, bit_index: BitIndex, group: Group) bool {
            const bit = (@as(RawInt, 1) << bit_index);
            return self.raw & bits(group) & bit == bit;
        }
        pub inline fn has_only_bit_in_group(self: Self, bit_index: BitIndex, group: Group) bool {
            const bit = (@as(RawInt, 1) << bit_index);
            return self.raw & bits(group) == bit;
        }
        pub inline fn has_all_bits_in_group(self: Self, bit_indexes: []const BitIndex, group: Group) bool {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= (@as(RawInt, 1) << index);
            }
            return self.raw & bits(group) & composite == composite;
        }
        pub inline fn has_only_these_bits_in_group(self: Self, bit_indexes: []const BitIndex, group: Group) bool {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= (@as(RawInt, 1) << index);
            }
            return self.raw & bits(group) == composite;
        }
        pub inline fn has_none_of_these_bits_in_group(self: Self, bit_indexes: []const BitIndex, group: Group) bool {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= (@as(RawInt, 1) << index);
            }
            return self.raw & bits(group) & composite == 0;
        }
        pub inline fn has_any_bits_in_group(self: Self, bit_indexes: []const BitIndex, group: Group) bool {
            var composite: RawInt = 0;
            for (bit_indexes) |index| {
                composite |= (@as(RawInt, 1) << index);
            }
            return self.raw & bits(group) & composite > 0;
        }
        pub inline fn isolate_group(self: Self, group: Group) Self {
            return Self{ .raw = self.raw & bits(group) };
        }
        pub inline fn isolate_group_as_int_aligned_to_bit_0(self: Self, group: Group) RawInt {
            return (self.raw & bits(group)) >> ctz(group);
        }
        pub inline fn clear_group(self: *Self, group: Group) void {
            self.raw &= inv_bits(group);
        }
        pub inline fn set_entire_group(self: *Self, group: Group) void {
            self.raw |= bits(group);
        }
        pub inline fn has_entire_group_set(self: Self, group: Group) bool {
            const group_bits = bits(group);
            return self.raw & group_bits == group_bits;
        }
        pub inline fn has_only_this_entire_group_set(self: Self, group: Group) bool {
            const group_bits = bits(group);
            return self.raw == group_bits;
        }
        pub inline fn has_any_flag_in_group_set(self: Self, group: Group) bool {
            return self.raw & bits(group) > 0;
        }
        pub inline fn has_any_flag_in_only_this_group_set(self: Self, group: Group) bool {
            return (self.raw & bits(group) > 0) and (self.raw & inv_bits(group) == 0);
        }
        pub inline fn has_no_flags_outside_this_group_set(self: Self, group: Group) bool {
            return self.raw & inv_bits(group) == 0;
        }
        pub inline fn has_one_or_zero_bits_set(self: Self) bool {
            return (self.raw & (self.raw - 1)) == 0;
        }
        pub inline fn has_exactly_one_bit_set(self: Self) bool {
            return self.raw != 0 and (self.raw & (self.raw - 1)) == 0;
        }
        pub inline fn has_more_than_one_bit_set(self: Self) bool {
            return (self.raw & (self.raw - 1)) != 0;
        }
        pub inline fn has_exactly_n_bits_set(self: Self, n: anytype) bool {
            return @popCount(self.raw) == n;
        }
        pub inline fn does_not_have_exactly_n_bits_set(self: Self, n: anytype) bool {
            return @popCount(self.raw) != n;
        }
        pub inline fn has_at_least_n_bits_set(self: Self, n: anytype) bool {
            return @popCount(self.raw) >= n;
        }
        pub inline fn has_more_than_n_bits_set(self: Self, n: anytype) bool {
            return @popCount(self.raw) > n;
        }
        pub inline fn has_at_most_n_bits_set(self: Self, n: anytype) bool {
            return @popCount(self.raw) <= n;
        }
        pub inline fn has_less_than_n_bits_set(self: Self, n: anytype) bool {
            return @popCount(self.raw) < n;
        }

        pub inline fn set_group_from_int_aligned_at_bit_0(self: *Self, group: Group, val: RawInt) void {
            const masked_val = ((val) << ctz(group)) & bits(group);
            self.raw |= masked_val;
        }
        pub inline fn clear_and_set_group_from_int_aligned_at_bit_0(self: *Self, group: Group, val: RawInt) void {
            self.raw &= inv_bits(group);
            const masked_val = ((val) << ctz(group)) & bits(group);
            self.raw |= masked_val;
        }
        pub inline fn partial_clear_group_from_inverse_of_int_aligned_at_bit_0(self: *Self, group: Group, val: RawInt) void {
            const masked_val = ((val) << ctz(group)) & bits(group);
            self.raw &= ~masked_val;
        }
        pub inline fn set_group_from_int_aligned_at_bit_0_dont_mask(self: *Self, group: Group, val: RawInt) void {
            const unmasked_val = ((val) << ctz(group));
            self.raw |= unmasked_val;
        }
        pub inline fn clear_and_set_group_from_int_aligned_at_bit_0_dont_mask(self: *Self, group: Group, val: RawInt) void {
            self.raw &= inv_bits(group);
            const unmasked_val = ((val) << ctz(group));
            self.raw |= unmasked_val;
        }
        pub inline fn partial_clear_group_from_inverse_of_int_aligned_at_bit_0_dont_mask(self: *Self, group: Group, val: RawInt) void {
            const unmasked_val = ((val) << ctz(group));
            self.raw &= ~unmasked_val;
        }

        pub inline fn flag_to_first_matching_group(flag: Flag) ?Group {
            for (G_INFO.fields) |field| {
                if (bits(flag) & field.value == bits(flag)) return @enumFromInt(field.value);
            }
            return null;
        }
        pub inline fn flag_to_first_matching_group_guaranteed(flag: Flag) Group {
            for (G_INFO.fields) |field| {
                if (bits(flag) & field.value == bits(flag)) return @enumFromInt(field.value);
            }
            unreachable;
        }
        pub inline fn flag_to_first_matching_group_in_set(flag: Flag, group_set: []const Group) ?Group {
            for (group_set) |group| {
                if (bits(flag) & bits(group) == bits(flag)) return group;
            }
            return null;
        }
        pub inline fn flag_to_first_matching_group_in_set_guaranteed(flag: Flag, group_set: []const Group) Group {
            for (group_set) |group| {
                if (bits(flag) & bits(group) == bits(flag)) return group;
            }
            unreachable;
        }

        pub inline fn all_flags_to_first_matching_group(self: Self) ?Group {
            for (G_INFO.fields) |field| {
                if (self.raw & field.value == self.raw) return @enumFromInt(field.value);
            }
            return null;
        }
        pub inline fn all_flags_to_first_matching_group_guaranteed(self: Self) Group {
            for (G_INFO.fields) |field| {
                if (self.raw & field.value == self.raw) return @enumFromInt(field.value);
            }
            unreachable;
        }
        pub inline fn all_flags_to_first_matching_group_in_set(self: Self, group_set: []const Group) ?Group {
            for (group_set) |group| {
                if (self.raw & bits(group) == self.raw) return group;
            }
            return null;
        }
        pub inline fn all_flags_to_first_matching_group_in_set_guaranteed(self: Self, group_set: []const Group) Group {
            for (group_set) |group| {
                if (self.raw & bits(group) == self.raw) return group;
            }
            unreachable;
        }
    };
}

pub const FlagTagLayout = enum(u8) {
    TAGS_ARE_FLAG_INDEXES,
    TAGS_ARE_FLAG_VALUES,
};

pub fn SingleBitFlags(comptime LAYOUT: FlagTagLayout, comptime ENUM: type) type {
    const INFO_1 = @typeInfo(ENUM);
    assert_with_reason(INFO_1 == .@"enum", @src(), "parameter `ENUM` must be an enum type", .{});
    const E_INFO = INFO_1.@"enum";
    // const I_INFO = @typeInfo(E_INFO.tag_type).int;
    // assert_with_reason(I_INFO.signedness == .unsigned, @src(), "parameter `ENUM` tag type must be an unsigned integer type", .{});

    const _ValueInt = if (comptime LAYOUT == .TAGS_ARE_FLAG_VALUES) check: {
        var bits: u16 = @bitSizeOf(E_INFO.tag_type);
        // Round up to next power of 2, at least 8
        bits = @max(8, bits);
        bits -= 1;
        bits |= bits >> 1;
        bits |= bits >> 2;
        bits |= bits >> 4;
        bits |= bits >> 8;
        bits += 1;
        break :check std.meta.Int(.unsigned, bits);
    } else check: {
        var bits: u16 = 0;
        for (E_INFO.fields) |field| {
            bits = @max(bits, @as(u16, @intCast(field.value)));
        }
        bits += 1;
        // Round up to next power of 2, at least 8
        bits = @max(8, bits);
        bits -= 1;
        bits |= bits >> 1;
        bits |= bits >> 2;
        bits |= bits >> 4;
        bits |= bits >> 8;
        bits += 1;
        break :check std.meta.Int(.unsigned, bits);
    };
    const _ALLOWED_BITS = comptime check: {
        var allowed: _ValueInt = 0;
        for (E_INFO.fields) |field| {
            if (LAYOUT == .TAGS_ARE_FLAG_VALUES) {
                allowed |= field.value;
                const pop_count = @popCount(@as(E_INFO.tag_type, @intCast(field.value)));
                assert_with_reason(pop_count == 1 or pop_count == 0, @src(), "SingleBitFlags is only compatible with enums where each tag is only a single bit, but tag `{s}` has value `{b}`", .{ field.name, field.value });
            } else {
                allowed |= @as(_ValueInt, 1) << field.value;
            }
        }
        break :check allowed;
    };
    return extern struct {
        raw: ValueInt = 0,

        const Self = @This();
        pub const ValueInt = _ValueInt;
        pub const Flag = ENUM;
        pub const ALLOWED_BITS: ValueInt = _ALLOWED_BITS;
        const DISALLOWED: ValueInt = ~ALLOWED_BITS;
        pub const ALL = Self{ .raw = ALLOWED_BITS };
        pub const EMPTY = Self{ .raw = 0 };
        const RAW_MAX = math.maxInt(ValueInt);
        const NEEDS_VALID_ASSERT = ALLOWED_BITS != RAW_MAX;

        inline fn assert_valid_bits(raw: ValueInt) void {
            if (NEEDS_VALID_ASSERT) {
                assert_with_reason(raw & DISALLOWED == 0, @src(), "invalid bits for flags type {s}:\nbits to set = {b:0>64}\nvalid range = {b:0>64}\ninvalid pos = {b:0>64}", .{ @typeName(Self), raw, ALLOWED_BITS, raw & DISALLOWED });
            }
        }

        inline fn flag_to_bit(flag_: ENUM) ValueInt {
            switch (comptime LAYOUT) {
                .TAGS_ARE_FLAG_VALUES => {
                    return @intCast(@intFromEnum(flag_));
                },
                .TAGS_ARE_FLAG_INDEXES => {
                    return @as(ValueInt, 1) << @intCast(@intFromEnum(flag_));
                },
            }
        }
        inline fn bit_to_flag(raw_: ValueInt) Flag {
            switch (comptime LAYOUT) {
                .TAGS_ARE_FLAG_VALUES => {
                    return @enumFromInt(@as(E_INFO.tag_type, @intCast(raw_)));
                },
                .TAGS_ARE_FLAG_INDEXES => {
                    return @enumFromInt(@as(E_INFO.tag_type, @intCast(@ctz(raw_))));
                },
            }
        }

        pub inline fn empty() Self {
            return EMPTY;
        }
        pub inline fn all() Self {
            return ALL;
        }

        /// current flags must EXACTLY match one of the tags in the enum set
        pub fn flag_name(self: Self) []const u8 {
            assert_valid_bits(self.raw);
            assert_with_reason(self.has_exactly_n_flags(1), @src(), "must have exactly one flag set in order to get the flag name", .{});
            return @tagName(bit_to_flag(self.raw));
        }
        pub fn flag_tag(self: Self) Flag {
            assert_valid_bits(self.raw);
            assert_with_reason(self.has_exactly_n_flags(1), @src(), "must have exactly one flag set in order to get the flag enum tag", .{});
            return bit_to_flag(self.raw);
        }

        pub inline fn is_empty(self: Self) bool {
            return self.raw == 0;
        }
        pub inline fn not_empty(self: Self) bool {
            return self.raw != 0;
        }

        pub fn flag(flag_: Flag) Self {
            return Self{ .raw = flag_to_bit(flag_) };
        }
        pub fn flags(flags_: []const Flag) Self {
            var self = Self{ .raw = 0 };
            for (flags_) |flag_| {
                self.raw |= flag_to_bit(flag_);
            }
            return self;
        }
        pub fn from_raw(val: ValueInt) Self {
            assert_valid_bits(val);
            return Self{ .raw = val };
        }
        pub fn from_raws(raws: []const ValueInt) Self {
            var composite: ValueInt = 0;
            for (raws) |raw| {
                composite |= raw;
            }
            assert_valid_bits(composite);
            return Self{ .raw = composite };
        }

        pub fn copy(self: Self) Self {
            return Self{ .raw = self.raw };
        }

        pub fn union_with(self: *Self, other: Self) void {
            self.raw |= other.raw;
        }
        pub fn intersection_with(self: *Self, other: Self) void {
            self.raw &= other.raw;
        }
        pub fn xor_with(self: *Self, other: Self) void {
            self.raw ^= other.raw;
        }

        pub fn add_all(self: *Self) void {
            self.raw = ALLOWED_BITS;
        }
        pub fn add(self: *Self, flag_: Flag) void {
            self.raw |= flag_to_bit(flag_);
        }
        pub fn add_if_true(self: *Self, flag_: Flag, condition: bool) void {
            if (condition) {
                self.raw |= flag_to_bit(flag_);
            }
        }
        pub fn add_raw(self: *Self, raw: ValueInt) void {
            assert_valid_bits(raw);
            self.raw |= raw;
        }
        pub fn add_many(self: *Self, flags_: []const Flag) void {
            for (flags_) |flag_| {
                self.add(flag_);
            }
        }
        pub fn add_many_if_true(self: *Self, flags_: []const Flag, condition: bool) void {
            if (condition) {
                for (flags_) |flag_| {
                    self.add(flag_);
                }
            }
        }
        pub inline fn remove_all(self: *Self) void {
            self.raw = 0;
        }
        pub fn remove(self: *Self, flag_: Flag) void {
            self.raw &= ~flag_to_bit(flag_);
        }
        pub fn remove_if_false(self: *Self, flag_: Flag, condition: bool) void {
            if (!condition) {
                self.raw &= ~flag_to_bit(flag_);
            }
        }
        pub inline fn remove_raw(self: *Self, raw: ValueInt) void {
            self.raw &= ~raw;
        }
        pub fn remove_many(self: *Self, flags_: []const Flag) void {
            for (flags_) |flag_| {
                self.remove(flag_);
            }
        }
        pub fn remove_many_if_false(self: *Self, flags_: []const Flag, condition: bool) void {
            if (!condition) {
                for (flags_) |flag_| {
                    self.remove(flag_);
                }
            }
        }
        pub fn set_state(self: *Self, flag_: Flag, state: bool) void {
            if (state) {
                self.add(flag_);
            } else {
                self.remove(flag_);
            }
        }
        pub fn set_state_on_many(self: *Self, flags_: []const Flag, state: bool) void {
            var mask: ValueInt = 0;
            for (flags_) |flag_| {
                mask |= flag_to_bit(flag_);
            }
            if (state) {
                self.raw |= mask;
            } else {
                self.raw &= ~mask;
            }
        }
        pub fn has_flag(self: Self, flag_: Flag) bool {
            const bits = flag_to_bit(flag_);
            return self.raw & bits == bits;
        }
        pub fn missing_flag(self: Self, flag_: Flag) bool {
            const bits = flag_to_bit(flag_);
            return self.raw & bits == 0;
        }
        pub fn has_only_this_flag(self: Self, flag_: Flag) bool {
            return self.raw == flag_to_bit(flag_);
        }
        pub fn has_all_flags(self: Self, flags_: []const Flag) bool {
            var composite: ValueInt = 0;
            for (flags_) |flag_| {
                composite |= flag_to_bit(flag_);
            }
            return self.raw & composite == composite;
        }
        pub fn has_only_these_flags(self: Self, flags_: []const Flag) bool {
            var composite: ValueInt = 0;
            for (flags_) |flag_| {
                composite |= flag_to_bit(flag_);
            }
            return self.raw == composite;
        }
        pub inline fn has_none_of_these_flags(self: Self, flags_: []const Flag) bool {
            var composite: ValueInt = 0;
            for (flags_) |flag_| {
                composite |= flag_to_bit(flag_);
            }
            return self.raw & composite == 0;
        }
        pub inline fn has_any_of_these_flags(self: Self, flags_: []const Flag) bool {
            var composite: ValueInt = 0;
            for (flags_) |flag_| {
                composite |= flag_to_bit(flag_);
            }
            return self.raw & composite > 0;
        }

        pub inline fn has_exactly_n_flags(self: Self, n: anytype) bool {
            return @popCount(self.raw) == n;
        }
        pub inline fn does_not_have_exactly_n_flags(self: Self, n: anytype) bool {
            return @popCount(self.raw) != n;
        }
        pub inline fn has_at_least_n_flags(self: Self, n: anytype) bool {
            return @popCount(self.raw) >= n;
        }
        pub inline fn has_more_than_n_flags(self: Self, n: anytype) bool {
            return @popCount(self.raw) > n;
        }
        pub inline fn has_at_most_n_flags(self: Self, n: anytype) bool {
            return @popCount(self.raw) <= n;
        }
        pub inline fn has_less_than_n_flags(self: Self, n: anytype) bool {
            return @popCount(self.raw) < n;
        }

        pub fn iterator(self: Self) Iterator {
            return Iterator{
                .remaining = self.raw,
            };
        }

        pub const Iterator = struct {
            remaining: ValueInt = 0,

            pub fn next(self: *Iterator) ?Flag {
                if (self.remaining == 0) return null;
                const lowest_bit = self.remaining & -%self.remaining;
                self.remaining &= self.remaining - 1;
                return bit_to_flag(lowest_bit);
            }
        };
    };
}
