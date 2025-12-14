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
const meta = std.meta;
const math = std.math;
const Log2Int = math.Log2Int;
const Log2IntCeil = math.Log2IntCeil;

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const Types = Root.Types;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

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
    return packed struct {
        raw: RawInt = 0,

        const Self = @This();
        pub const RawInt: type = E_INFO.tag_type;
        pub const BitIndex = Log2Int(RawInt);
        pub const BitCount = Log2IntCeil(RawInt);
        pub const Flag = FLAGS_ENUM;
        pub const Group = GROUPS_ENUM;
        pub const ALL = Self{ .raw = A };
        const FULL = F;
        const NEEDS_VALID_ASSERT = ALL != FULL;

        inline fn assert_valid_bits(raw: RawInt) void {
            if (NEEDS_VALID_ASSERT) {
                assert_with_reason(raw & ~ALL == 0, @src(), "invalid bits for flags type {s}:\nbits to set = {b:0>64}\nvalid range = {b:0>64}\ninvalid pos = {b:0>64}", .{ @typeName(Self), raw, ALL, raw & ~ALL });
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

        pub inline fn blank() Self {
            return Self{ .raw = 0 };
        }
        pub inline fn all() Self {
            return ALL;
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

        pub inline fn set(self: *Self, flag: Flag) void {
            self.raw |= bits(flag);
        }
        pub inline fn set_one_bit_from_bool(self: *Self, flag: Flag, state: bool) void {
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
