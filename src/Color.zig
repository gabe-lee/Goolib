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

const Root = @import("./_root.zig");
const Types = Root.Types;
const Assert = Root.Assert;
const MathX = Root.Math;
const math = std.math;

const assert_with_reason = Assert.assert_with_reason;
const num_cast = Root.Cast.num_cast;

/// The order of color channels in packed color types
/// - MSB -> LSB
///
/// The integer values here are in sync with `SDL3.SDL_PackedOrder`
/// so the two can be directly converted from one to the other
pub const ChannelOrder = enum(c_uint) {
    // NONE = 0,
    _RGB = 1,
    RGB_ = 2,
    ARGB = 3,
    RGBA = 4,
    _BGR = 5,
    BGR_ = 6,
    ABGR = 7,
    BGRA = 8,
};

pub const Channel = enum(u8) {
    red,
    green,
    blue,
    alpha,
    depth,
    _,

    pub inline fn to_index(self: Channel) u8 {
        return @intFromEnum(self);
    }
    pub inline fn from_index(idx: u8) Channel {
        return @enumFromInt(idx);
    }
};

pub fn define_arbitrary_color_type(comptime CHANNEL_TYPE: type, comptime CHANNELS_ENUM: type) type {
    assert_with_reason(Types.type_is_enum(CHANNELS_ENUM), @src(), "type `CHANNELS_ENUM` must be an enum type, got type `{s}`", .{@typeName(CHANNELS_ENUM)});
    assert_with_reason(Types.enum_is_exhaustive(CHANNELS_ENUM), @src(), "type `CHANNELS_ENUM` must be an exhaustive enum type", .{@typeName(CHANNELS_ENUM)});
    assert_with_reason(Types.all_enum_values_start_from_zero_with_no_gaps(CHANNELS_ENUM), @src(), "type `CHANNELS_ENUM` must be an enum type with all tags starting from value 0 to the max tag value, with no gaps", .{@typeName(CHANNELS_ENUM)});
    return struct {
        const Self = @This();
        raw: [CHANNEL_COUNT]CHANNEL_TYPE = @splat(0),

        pub fn new_vals_in_order(vals: [CHANNEL_COUNT]CHANNEL_TYPE) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = vals[c];
            }
            return out;
        }

        pub fn new_same_val_all_channels(val: CHANNEL_TYPE) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = val;
            }
            return out;
        }

        pub const MAX_VALS = make: {
            var out = Self{};
            for (0..CHANNEL_COUNT) |c| {
                if (Types.type_is_int(CHANNEL_TYPE)) {
                    out.raw[c] = math.maxInt(CHANNEL_TYPE);
                } else {
                    out.raw[c] = 1.0;
                }
            }
            break :make out;
        };

        pub inline fn new_max_values() Self {
            return MAX_VALS;
        }

        pub inline fn get(self: Self, comptime channel: CHANNELS_ENUM) CHANNEL_TYPE {
            return self.raw[@intFromEnum(channel)];
        }
        pub inline fn set(self: *Self, comptime channel: CHANNELS_ENUM, val: CHANNEL_TYPE) void {
            self.raw[@intFromEnum(channel)] = val;
        }
        pub inline fn set_all_channels(self: *Self, val: CHANNEL_TYPE) void {
            inline for (0..CHANNEL_COUNT) |c| {
                self.raw[c] = val;
            }
        }
        pub inline fn with_set(self: Self, comptime channel: CHANNELS_ENUM, val: CHANNEL_TYPE) Self {
            var new_self = self;
            new_self.raw[@intFromEnum(channel)] = val;
            return new_self;
        }

        pub fn cast_values_to(self: Self, comptime NEW_CHANNEL_TYPE: type) define_arbitrary_color_type(NEW_CHANNEL_TYPE, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(NEW_CHANNEL_TYPE, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = num_cast(self.raw[c], NEW_CHANNEL_TYPE);
            }
            return out;
        }
        pub fn reorder_channels_to(self: Self, comptime NEW_CHANNEL_ENUM: type) define_arbitrary_color_type(CHANNEL_TYPE, NEW_CHANNEL_ENUM) {
            var out: define_arbitrary_color_type(CHANNEL_TYPE, NEW_CHANNEL_ENUM) = undefined;
            const NEW_TAG_INFO = @typeInfo(NEW_CHANNEL_ENUM).@"enum".fields;
            const OLD_TAG_INFO = @typeInfo(CHANNELS_ENUM).@"enum".fields;
            inline for (NEW_TAG_INFO) |new_tag| {
                var found = false;
                inline for (OLD_TAG_INFO) |old_tag| {
                    if (std.mem.eql(u8, new_tag.name, old_tag.name)) {
                        out.raw[new_tag.value] = self.raw[old_tag.value];
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    out.raw[new_tag.value] = std.mem.zeroes(CHANNEL_TYPE);
                }
            }
            return out;
        }

        pub fn cast_values_normalized_to(self: Self, comptime NEW_CHANNEL_TYPE: type) define_arbitrary_color_type(NEW_CHANNEL_TYPE, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(NEW_CHANNEL_TYPE, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                if (Types.type_is_float(NEW_CHANNEL_TYPE) and Types.type_is_int(CHANNEL_TYPE)) {
                    out.raw[c] = MathX.int_to_normalized_float(self.raw[c], NEW_CHANNEL_TYPE);
                } else if (Types.type_is_int(NEW_CHANNEL_TYPE) and Types.type_is_float(CHANNEL_TYPE)) {
                    out.raw[c] = MathX.normalized_float_to_int(self.raw[c], NEW_CHANNEL_TYPE);
                } else if (Types.type_is_int(NEW_CHANNEL_TYPE) and Types.type_is_int(CHANNEL_TYPE) and NEW_CHANNEL_TYPE != CHANNEL_TYPE) {
                    out.raw[c] = MathX.normalized_float_to_int(MathX.int_to_normalized_float(self.raw[c], f64), NEW_CHANNEL_TYPE);
                } else {
                    out.raw[c] = num_cast(self.raw[c], NEW_CHANNEL_TYPE);
                }
            }
            return out;
        }

        /// Linear interpolation on each channel
        pub fn lerp(self: Self, other: Self, percent: anytype) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = MathX.lerp(self.raw[c], other.raw[c], percent);
            }
            return out;
        }
        pub fn bilinear_interp_from_terms(constant: Self, linear: Self, quadratic: Self, percent: anytype) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = MathX.upgrade_add_out(MathX.upgrade_multiply(percent, MathX.upgrade_add(MathX.upgrade_multiply(percent, quadratic.raw[c]), linear.raw[c])), constant.raw[c], CHANNEL_TYPE);
            }
            return out;
        }
        pub fn median_of_3_channels(self: Self, chan_a: CHANNELS_ENUM, chan_b: CHANNELS_ENUM, chan_c: CHANNELS_ENUM) CHANNEL_TYPE {
            return MathX.median_of_3(CHANNEL_TYPE, self.get(chan_a), self.get(chan_b), self.get(chan_c));
        }
        /// returns `color[chan_b] - color[chan_a]`
        pub fn channel_delta(self: Self, chan_a: CHANNELS_ENUM, chan_b: CHANNELS_ENUM) CHANNEL_TYPE {
            return self.get(chan_b) - self.get(chan_a);
        }
        /// Adds each channel to the matching channel of the other color
        pub fn add(self: Self, other: Self) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] + other.raw[c];
            }
            return out;
        }
        /// Adds value to each channel
        pub fn add_scalar(self: Self, val: CHANNEL_TYPE) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] + val;
            }
            return out;
        }
        /// Subtracts each channel by the matching channel of the other color
        pub fn subtract(self: Self, other: Self) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] + other.raw[c];
            }
            return out;
        }
        /// Subtracts value from each channel (chan = chan - val)
        pub fn subtract_scalar(self: Self, val: CHANNEL_TYPE) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] - val;
            }
            return out;
        }
        /// Subtract channel value from scalar value (chan = val - chan)
        pub fn subtract_from_scalar(self: Self, val: CHANNEL_TYPE) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = val - self.raw[c];
            }
            return out;
        }
        /// Multiplies each channel by the matching channel of the other color
        pub fn multiply(self: Self, other: Self) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] * other.raw[c];
            }
            return out;
        }
        /// Multiplies each channel by value
        pub fn multiply_scalar(self: Self, val: CHANNEL_TYPE) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] * val;
            }
            return out;
        }
        /// Divieds each channel by the matching channel of the other color
        pub fn divide(self: Self, other: Self) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] / other.raw[c];
            }
            return out;
        }
        /// Divides each channel by value (chan = chan / val)
        pub fn divide_scalar(self: Self, val: CHANNEL_TYPE) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] / val;
            }
            return out;
        }
        /// Divides value by each channel (chan = val / chan)
        pub fn divide_scalar_inverse(self: Self, val: CHANNEL_TYPE) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = val / self.raw[c];
            }
            return out;
        }
        /// Negates each channel (only works with CHANNEL_TYPE's that can be negative)
        pub fn negate(self: Self) Self {
            var out = Self{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = -self.raw[c];
            }
            return out;
        }

        pub fn greater_than(self: Self, other: Self) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] > other.raw[c];
            }
        }
        pub fn greater_than_scalar(self: Self, val: CHANNEL_TYPE) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] > val;
            }
        }
        pub fn less_than(self: Self, other: Self) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] < other.raw[c];
            }
        }
        pub fn less_than_scalar(self: Self, val: CHANNEL_TYPE) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] < val;
            }
        }
        pub fn greater_than_or_equal(self: Self, other: Self) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] >= other.raw[c];
            }
        }
        pub fn greater_than_or_equal_scalar(self: Self, val: CHANNEL_TYPE) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] >= val;
            }
        }
        pub fn less_than_or_equal(self: Self, other: Self) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] <= other.raw[c];
            }
        }
        pub fn less_than_or_equal_scalar(self: Self, val: CHANNEL_TYPE) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] <= val;
            }
        }
        pub fn equals_by_channel(self: Self, other: Self) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] == other.raw[c];
            }
        }
        pub fn equals_by_channel_scalar(self: Self, val: CHANNEL_TYPE) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] == val;
            }
        }
        pub fn not_equal_by_channel(self: Self, other: Self) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] != other.raw[c];
            }
        }
        pub fn not_equal_by_channel_scalar(self: Self, val: CHANNEL_TYPE) define_arbitrary_color_type(bool, CHANNELS_ENUM) {
            var out: define_arbitrary_color_type(bool, CHANNELS_ENUM) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] != val;
            }
        }
        pub fn equals(self: Self, other: Self) bool {
            var result: bool = true;
            inline for (0..CHANNEL_COUNT) |c| {
                result = result and self.raw[c] == other.raw[c];
            }
            return result;
        }
        pub fn not_equal(self: Self, other: Self) bool {
            var result: bool = false;
            inline for (0..CHANNEL_COUNT) |c| {
                result = result or self.raw[c] != other.raw[c];
            }
            return result;
        }
        pub fn implicit_equals(self: Self, other: Self) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Self);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int == other_int;
        }
        pub fn implicit_not_equals(self: Self, other: Self) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Self);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int != other_int;
        }
        pub fn implicit_greater_than(self: Self, other: Self) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Self);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int > other_int;
        }
        pub fn implicit_less_than(self: Self, other: Self) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Self);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int < other_int;
        }
        pub fn implicit_greater_than_or_equal(self: Self, other: Self) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Self);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int >= other_int;
        }
        pub fn implicit_less_than_or_equal(self: Self, other: Self) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Self);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int <= other_int;
        }

        pub const CHANNEL_COUNT = @typeInfo(CHANNELS_ENUM).@"enum".fields.len;
        pub const BYTE_SIZE = @sizeOf(CHANNEL_TYPE) * CHANNEL_COUNT;
        pub const ZERO = Self{};
    };
}

pub fn define_packed_color_type(comptime integer_type: type, comptime order: ChannelOrder, comptime red_bits: comptime_int, comptime green_bits: comptime_int, comptime blue_bits: comptime_int, comptime alpha_bits: comptime_int) type {
    assert_with_reason(Types.type_is_unsigned_int_aligned(integer_type), @src(), "type `integer_type` MUST be one of: u8, u16, u32, u64, u128, usize... got type `{s}`", .{@typeName(integer_type)});
    const R_INT = std.meta.Int(.unsigned, red_bits);
    const G_INT = std.meta.Int(.unsigned, green_bits);
    const B_INT = std.meta.Int(.unsigned, blue_bits);
    const A_INT = std.meta.Int(.unsigned, alpha_bits);
    const CHANNEL_BITS = red_bits + green_bits + blue_bits + alpha_bits;
    const CHANNEL_BYTES = ((CHANNEL_BITS + 7) >> 3);
    const INT_BITS = @typeInfo(integer_type).int.bits;
    const PAD = std.meta.Int(.unsigned, INT_BITS - CHANNEL_BITS);
    switch (order) {
        ._RGB, .ARGB => return packed struct {
            b: B_INT = 0,
            g: G_INT = 0,
            r: R_INT = 0,
            a: A_INT = 0,
            __pad: PAD = 0,

            const Self = @This();
            pub const ORDER = order;
            pub const BITS = CHANNEL_BITS;
            pub const BYTES = CHANNEL_BYTES;

            pub fn to_u32(self: Self) u32 {
                return @bitCast(self);
            }
            pub fn to_u16(self: Self) u16 {
                if (CHANNEL_BITS > 16) @compileError("more than 16 channel bits");
                return @intCast(@as(u32, @bitCast(self)));
            }
            pub fn to_u8(self: Self) u8 {
                if (CHANNEL_BITS > 8) @compileError("more than 8 channel bits");
                return @intCast(@as(u32, @bitCast(self)));
            }

            pub fn reorder(self: Self, comptime new_order: ChannelOrder) define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits) {
                const NEW_T = define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits);
                var new = NEW_T{};
                new.r = self.r;
                new.g = self.g;
                new.b = self.b;
                new.a = self.a;
                return new;
            }
        },
        .RGB_, .RGBA => return packed struct {
            a: A_INT = 0,
            b: B_INT = 0,
            g: G_INT = 0,
            r: R_INT = 0,
            __pad: PAD = 0,

            const Self = @This();
            pub const ORDER = order;
            pub const BITS = CHANNEL_BITS;
            pub const BYTES = CHANNEL_BYTES;

            pub fn to_u32(self: Self) u32 {
                return @bitCast(self);
            }
            pub fn to_u16(self: Self) u16 {
                if (CHANNEL_BITS > 16) @compileError("more than 16 channel bits");
                return @intCast(@as(u32, @bitCast(self)));
            }
            pub fn to_u8(self: Self) u8 {
                if (CHANNEL_BITS > 8) @compileError("more than 8 channel bits");
                return @intCast(@as(u32, @bitCast(self)));
            }

            pub fn reorder(self: Self, comptime new_order: ChannelOrder) define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits) {
                const NEW_T = define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits);
                var new = NEW_T{};
                new.r = self.r;
                new.g = self.g;
                new.b = self.b;
                new.a = self.a;
                return new;
            }
        },
        ._BGR, .ABGR => return packed struct {
            r: R_INT = 0,
            g: G_INT = 0,
            b: B_INT = 0,
            a: A_INT = 0,
            __pad: PAD = 0,

            const Self = @This();
            pub const ORDER = order;
            pub const BITS = CHANNEL_BITS;
            pub const BYTES = CHANNEL_BYTES;

            pub fn to_u32(self: Self) u32 {
                return @bitCast(self);
            }
            pub fn to_u16(self: Self) u16 {
                if (CHANNEL_BITS > 16) @compileError("more than 16 channel bits");
                return @intCast(@as(u32, @bitCast(self)));
            }
            pub fn to_u8(self: Self) u8 {
                if (CHANNEL_BITS > 8) @compileError("more than 8 channel bits");
                return @intCast(@as(u32, @bitCast(self)));
            }

            pub fn reorder(self: Self, comptime new_order: ChannelOrder) define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits) {
                const NEW_T = define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits);
                var new = NEW_T{};
                new.r = self.r;
                new.g = self.g;
                new.b = self.b;
                new.a = self.a;
                return new;
            }
        },
        .BGR_, .BGRA => return packed struct {
            a: A_INT = 0,
            r: R_INT = 0,
            g: G_INT = 0,
            b: B_INT = 0,
            __pad: PAD = 0,

            const Self = @This();
            pub const ORDER = order;
            pub const BITS = CHANNEL_BITS;
            pub const BYTES = CHANNEL_BYTES;

            pub fn to_u32(self: Self) u32 {
                return @bitCast(self);
            }
            pub fn to_u16(self: Self) u16 {
                if (CHANNEL_BITS > 16) @compileError("more than 16 channel bits");
                return @intCast(@as(u32, @bitCast(self)));
            }
            pub fn to_u8(self: Self) u8 {
                if (CHANNEL_BITS > 8) @compileError("more than 8 channel bits");
                return @intCast(@as(u32, @bitCast(self)));
            }

            pub fn reorder(self: Self, comptime new_order: ChannelOrder) define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits) {
                const NEW_T = define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits);
                var new = NEW_T{};
                new.r = self.r;
                new.g = self.g;
                new.b = self.b;
                new.a = self.a;
                return new;
            }
        },
    }
}

pub fn define_color_rgba_type(comptime T: type) type {
    return extern struct {
        r: T = 0,
        g: T = 0,
        b: T = 0,
        a: T = 0,

        const T_RGBA = @This();
        const T_RGB = define_color_rgb_type(T);
        const T_RAW = std.meta.Int(.unsigned, @bitSizeOf(T_RGBA));
        const MAX = switch (T) {
            f16, f32, f64, f80, f128, comptime_float => 1.0,
            else => std.math.maxInt(T),
        };
        const MIN = switch (T) {
            f16, f32, f64, f80, f128, comptime_float => 0.0,
            else => std.math.minInt(T),
        };

        pub fn new(r: T, g: T, b: T, a: T) T_RGBA {
            return T_RGBA{ .r = r, .g = g, .b = b, .a = a };
        }
        pub fn new_opaque(r: T, g: T, b: T) T_RGBA {
            return T_RGBA{ .r = r, .g = g, .b = b, .a = MAX };
        }

        pub const WHITE = T_RGBA{ .r = MAX, .g = MAX, .b = MAX, .a = MAX };
        pub const BLACK = T_RGBA{ .r = MIN, .g = MIN, .b = MIN, .a = MAX };
        pub const CLEAR = T_RGBA{ .r = MIN, .g = MIN, .b = MIN, .a = MIN };

        pub fn to_rgb(self: T_RGBA) T_RGB {
            return T_RGB{
                .r = self.r,
                .g = self.g,
                .b = self.b,
            };
        }

        pub inline fn to_raw_int(self: T_RGBA) T_RAW {
            return @bitCast(self);
        }
    };
}

pub fn define_color_rgb_type(comptime T: type) type {
    return extern struct {
        r: T = 0,
        g: T = 0,
        b: T = 0,

        const T_RGB = @This();
        const T_RGBA = define_color_rgba_type(T);
        const T_RAW = std.meta.Int(.unsigned, @bitSizeOf(T_RGBA));
        const MAX = switch (T) {
            f16, f32, f64, f80, f128, comptime_float => 1.0,
            else => std.math.maxInt(T),
        };
        const MIN = switch (T) {
            f16, f32, f64, f80, f128, comptime_float => 0.0,
            else => std.math.minInt(T),
        };

        pub fn new(r: T, g: T, b: T) T_RGB {
            return T_RGB{ .r = r, .g = g, .b = b };
        }

        pub fn to_rgba(self: T_RGB, a: T) T_RGBA {
            return T_RGBA{
                .r = self.r,
                .g = self.g,
                .b = self.b,
                .a = a,
            };
        }

        pub inline fn to_raw_int(self: T_RGB) T_RAW {
            return @bitCast(self.to_rgba(0));
        }

        pub const WHITE = T_RGB{ .r = MAX, .g = MAX, .b = MAX };
        pub const BLACK = T_RGB{ .r = MIN, .g = MIN, .b = MIN };
    };
}
