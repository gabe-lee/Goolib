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
pub const SDL_ChannelOrder = enum(c_uint) {
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
        return @backingInt(self);
    }
    pub inline fn from_index(idx: u8) Channel {
        return @fromBackingInt(@intCast(idx));
    }
};

pub const ChannelLayout = enum {
    R,
    A,
    RA,
    AR,
    RG,
    GR,
    RGB,
    BGR,
    RGBA,
    ARGB,
    BGRA,
    ABGR,

    pub fn ChannelEnum(comptime self: ChannelLayout) type {
        return switch (comptime self) {
            .R => Channel_R,
            .A => Channel_A,
            .RA => Channel_RA,
            .AR => Channel_AR,
            .RG => Channel_RG,
            .GR => Channel_GR,
            .RGB => Channel_RGB,
            .BGR => Channel_BGR,
            .RGBA => Channel_RGBA,
            .ARGB => Channel_BGRA,
            .BGRA => Channel_ARGB,
            .ABGR => Channel_ABGR,
        };
    }
};
pub const Channel_R = enum(u8) {
    R = 0,
};
pub const Channel_A = enum(u8) {
    A = 0,
};
pub const Channel_AR = enum(u8) {
    A = 0,
    R = 1,
};
pub const Channel_RA = enum(u8) {
    R = 0,
    A = 1,
};
pub const Channel_GR = enum(u8) {
    G = 0,
    R = 1,
};
pub const Channel_RG = enum(u8) {
    R = 0,
    G = 1,
};
pub const Channel_RGB = enum(u8) {
    R = 0,
    G = 1,
    B = 2,
};
pub const Channel_BGR = enum(u8) {
    B = 0,
    G = 1,
    R = 2,
};
pub const Channel_RGBA = enum(u8) {
    R = 0,
    G = 1,
    B = 2,
    A = 3,
};
pub const Channel_BGRA = enum(u8) {
    B = 0,
    G = 1,
    R = 2,
    A = 3,
};
pub const Channel_ARGB = enum(u8) {
    A = 0,
    R = 1,
    G = 2,
    B = 3,
};
pub const Channel_ABGR = enum(u8) {
    A = 0,
    B = 1,
    G = 2,
    R = 3,
};

pub fn define_color_type(comptime T: type, comptime LAYOUT: ChannelLayout) type {
    return define_arbitrary_color_type(T, LAYOUT.ChannelEnum());
}

pub fn define_arbitrary_color_type(comptime T: type, comptime CHANNEL: type) type {
    assert_with_reason(Types.type_is_enum(CHANNEL), @src(), "type `CHANNELS_ENUM` must be an enum type, got type `{s}`", .{@typeName(CHANNEL)});
    assert_with_reason(Types.enum_is_exhaustive(CHANNEL), @src(), "type `CHANNELS_ENUM` must be an exhaustive enum type", .{@typeName(CHANNEL)});
    assert_with_reason(Types.all_enum_values_start_from_zero_with_no_gaps(CHANNEL), @src(), "type `CHANNELS_ENUM` must be an enum type with all tags starting from value 0 to the max tag value, with no gaps", .{@typeName(CHANNEL)});
    return extern struct {
        const Color = @This();
        const Vec = switch (CHANNEL_COUNT) {
            2 => Root.Vec2.define_vec2_type(T),
            3 => Root.Vec3.define_vec3_type(T),
            4 => Root.Vec4.define_vec4_type(T),
            else => void,
        };

        pub const CHANNEL_COUNT = @typeInfo(CHANNEL).@"enum".field_names.len;
        pub const BYTE_SIZE = @sizeOf(T) * CHANNEL_COUNT;
        pub const ZERO = Color{};
        pub const Channel = CHANNEL;

        raw: [CHANNEL_COUNT]T = @splat(0),

        pub fn has_channel(comptime chan: []const u8) bool {
            return @hasField(CHANNEL, chan);
        }
        pub fn has_all_channels(comptime chans: []const []const u8) bool {
            inline for (chans) |chan| {
                if (@hasField(CHANNEL, chan)) return false;
            }
            return true;
        }

        pub const TYPE = T;

        pub inline fn to_vec(self: Color) Vec {
            return @bitCast(self);
        }
        pub inline fn from_vec(v: Vec) Color {
            return @bitCast(v);
        }

        pub fn new_vals_in_order(vals: [CHANNEL_COUNT]T) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = vals[c];
            }
            return out;
        }

        pub fn new_same_val_all_channels(val: T) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = val;
            }
            return out;
        }

        pub const MAX_VALS = make: {
            var out = Color{};
            for (0..CHANNEL_COUNT) |c| {
                if (Types.type_is_int(T)) {
                    out.raw[c] = math.maxInt(T);
                } else {
                    out.raw[c] = 1.0;
                }
            }
            break :make out;
        };

        pub inline fn new_max_values() Color {
            return MAX_VALS;
        }

        pub inline fn get(self: Color, channel: CHANNEL) T {
            return self.raw[@backingInt(channel)];
        }
        pub inline fn set(self: *Color, channel: CHANNEL, val: T) void {
            self.raw[@backingInt(channel)] = val;
        }
        pub inline fn set_all_channels(self: *Color, val: T) void {
            inline for (0..CHANNEL_COUNT) |c| {
                self.raw[c] = val;
            }
        }
        pub inline fn with_set(self: Color, channel: CHANNEL, val: T) Color {
            var new_self = self;
            new_self.raw[@backingInt(channel)] = val;
            return new_self;
        }

        pub fn cast_values_to(self: Color, comptime NEW_CHANNEL_TYPE: type) define_arbitrary_color_type(NEW_CHANNEL_TYPE, CHANNEL) {
            var out: define_arbitrary_color_type(NEW_CHANNEL_TYPE, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = num_cast(self.raw[c], NEW_CHANNEL_TYPE);
            }
            return out;
        }
        pub fn to_bgra_u8_raw(self: Color) [4]u8 {
            const cast_u8 = self.cast_values_normalized_to(u8);
            return [4]u8{
                if (comptime has_channel("B")) cast_u8.get(.B) else 255,
                if (comptime has_channel("G")) cast_u8.get(.G) else 255,
                if (comptime has_channel("R")) cast_u8.get(.R) else 255,
                if (comptime has_channel("A")) cast_u8.get(.A) else 255,
            };
        }
        pub fn reorder_channels_to(self: Color, comptime NEW_CHANNEL_ENUM: type) define_arbitrary_color_type(T, NEW_CHANNEL_ENUM) {
            var out: define_arbitrary_color_type(T, NEW_CHANNEL_ENUM) = undefined;
            const NEW_TAG_INFO = @typeInfo(NEW_CHANNEL_ENUM).@"enum".fields;
            const OLD_TAG_INFO = @typeInfo(CHANNEL).@"enum".fields;
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
                    out.raw[new_tag.value] = std.mem.zeroes(T);
                }
            }
            return out;
        }

        pub fn cast_values_normalized_to(self: Color, comptime NEW_CHANNEL_TYPE: type) define_arbitrary_color_type(NEW_CHANNEL_TYPE, CHANNEL) {
            var out: define_arbitrary_color_type(NEW_CHANNEL_TYPE, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                if (Types.type_is_float(NEW_CHANNEL_TYPE) and Types.type_is_int(T)) {
                    out.raw[c] = MathX.int_to_normalized_float(self.raw[c], NEW_CHANNEL_TYPE);
                } else if (Types.type_is_int(NEW_CHANNEL_TYPE) and Types.type_is_float(T)) {
                    out.raw[c] = MathX.normalized_float_to_int(self.raw[c], NEW_CHANNEL_TYPE);
                } else if (Types.type_is_int(NEW_CHANNEL_TYPE) and Types.type_is_int(T) and NEW_CHANNEL_TYPE != T) {
                    out.raw[c] = MathX.normalized_float_to_int(MathX.int_to_normalized_float(self.raw[c], f64), NEW_CHANNEL_TYPE);
                } else {
                    out.raw[c] = num_cast(self.raw[c], NEW_CHANNEL_TYPE);
                }
            }
            return out;
        }

        /// Linear interpolation on each channel
        pub fn lerp(self: Color, other: Color, percent: anytype) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = MathX.upgrade_lerp_out(self.raw[c], other.raw[c], percent, T);
            }
            return out;
        }
        pub fn lerp_f32(self: Color, other: Color, percent: f32) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = MathX.upgrade_lerp_out(self.raw[c], other.raw[c], percent, T);
            }
            return out;
        }
        pub fn bilinear_interp_from_terms(constant: Color, linear: Color, quadratic: Color, percent: anytype) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = MathX.upgrade_add_out(MathX.upgrade_multiply(percent, MathX.upgrade_add(MathX.upgrade_multiply(percent, quadratic.raw[c]), linear.raw[c])), constant.raw[c], T);
            }
            return out;
        }
        pub fn median_of_3_channels(self: Color, chan_a: CHANNEL, chan_b: CHANNEL, chan_c: CHANNEL) T {
            return MathX.median_of_3(T, self.get(chan_a), self.get(chan_b), self.get(chan_c));
        }
        /// returns `color[chan_b] - color[chan_a]`
        pub fn channel_delta(self: Color, chan_a: CHANNEL, chan_b: CHANNEL) T {
            return self.get(chan_b) - self.get(chan_a);
        }
        /// Adds each channel to the matching channel of the other color
        pub fn add(self: Color, other: Color) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] + other.raw[c];
            }
            return out;
        }
        /// Adds value to each channel
        pub fn add_scalar(self: Color, val: T) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] + val;
            }
            return out;
        }
        /// Subtracts each channel by the matching channel of the other color
        pub fn subtract(self: Color, other: Color) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] - other.raw[c];
            }
            return out;
        }
        /// Subtracts value from each channel (chan = chan - val)
        pub fn subtract_scalar(self: Color, val: T) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] - val;
            }
            return out;
        }
        /// Subtract channel value from scalar value (chan = val - chan)
        pub fn subtract_from_scalar(self: Color, val: T) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = val - self.raw[c];
            }
            return out;
        }
        /// Multiplies each channel by the matching channel of the other color
        pub fn multiply(self: Color, other: Color) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] * other.raw[c];
            }
            return out;
        }
        /// Multiplies each channel by value
        pub fn multiply_scalar(self: Color, val: T) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] * val;
            }
            return out;
        }
        /// Divieds each channel by the matching channel of the other color
        pub fn divide(self: Color, other: Color) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] / other.raw[c];
            }
            return out;
        }
        /// Divides each channel by value (chan = chan / val)
        pub fn divide_scalar(self: Color, val: T) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] / val;
            }
            return out;
        }
        /// Divides value by each channel (chan = val / chan)
        pub fn divide_scalar_inverse(self: Color, val: T) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = val / self.raw[c];
            }
            return out;
        }
        /// Negates each channel (only works with CHANNEL_TYPE's that can be negative)
        pub fn negate(self: Color) Color {
            var out = Color{};
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = -self.raw[c];
            }
            return out;
        }

        pub fn greater_than(self: Color, other: Color) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] > other.raw[c];
            }
        }
        pub fn greater_than_scalar(self: Color, val: T) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] > val;
            }
        }
        pub fn less_than(self: Color, other: Color) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] < other.raw[c];
            }
        }
        pub fn less_than_scalar(self: Color, val: T) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] < val;
            }
        }
        pub fn greater_than_or_equal(self: Color, other: Color) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] >= other.raw[c];
            }
        }
        pub fn greater_than_or_equal_scalar(self: Color, val: T) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] >= val;
            }
        }
        pub fn less_than_or_equal(self: Color, other: Color) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] <= other.raw[c];
            }
        }
        pub fn less_than_or_equal_scalar(self: Color, val: T) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] <= val;
            }
        }
        pub fn equals_by_channel(self: Color, other: Color) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] == other.raw[c];
            }
        }
        pub fn equals_by_channel_scalar(self: Color, val: T) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] == val;
            }
        }
        pub fn not_equal_by_channel(self: Color, other: Color) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] != other.raw[c];
            }
        }
        pub fn not_equal_by_channel_scalar(self: Color, val: T) define_arbitrary_color_type(bool, CHANNEL) {
            var out: define_arbitrary_color_type(bool, CHANNEL) = undefined;
            inline for (0..CHANNEL_COUNT) |c| {
                out.raw[c] = self.raw[c] != val;
            }
        }
        pub fn equals(self: Color, other: Color) bool {
            var result: bool = true;
            inline for (0..CHANNEL_COUNT) |c| {
                result = result and self.raw[c] == other.raw[c];
            }
            return result;
        }
        pub fn not_equal(self: Color, other: Color) bool {
            var result: bool = false;
            inline for (0..CHANNEL_COUNT) |c| {
                result = result or self.raw[c] != other.raw[c];
            }
            return result;
        }
        pub fn implicit_equals(self: Color, other: Color) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Color);
            const self_int: INT = @bitCast(self.raw);
            const other_int: INT = @bitCast(other.raw);
            return self_int == other_int;
        }
        pub fn implicit_not_equals(self: Color, other: Color) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Color);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int != other_int;
        }
        pub fn implicit_greater_than(self: Color, other: Color) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Color);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int > other_int;
        }
        pub fn implicit_less_than(self: Color, other: Color) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Color);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int < other_int;
        }
        pub fn implicit_greater_than_or_equal(self: Color, other: Color) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Color);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int >= other_int;
        }
        pub fn implicit_less_than_or_equal(self: Color, other: Color) bool {
            const INT = Types.UnsignedIntegerWithSameSize(Color);
            const self_int: INT = @bitCast(self);
            const other_int: INT = @bitCast(other);
            return self_int <= other_int;
        }
    };
}

pub fn define_packed_color_type(comptime integer_type: type, comptime order: SDL_ChannelOrder, comptime red_bits: comptime_int, comptime green_bits: comptime_int, comptime blue_bits: comptime_int, comptime alpha_bits: comptime_int) type {
    assert_with_reason(Types.type_is_unsigned_int_aligned(integer_type), @src(), "type `integer_type` MUST be one of: u8, u16, u32, u64, u128, usize... got type `{s}`", .{@typeName(integer_type)});
    const R_INT = @Int(.unsigned, red_bits);
    const G_INT = @Int(.unsigned, green_bits);
    const B_INT = @Int(.unsigned, blue_bits);
    const A_INT = @Int(.unsigned, alpha_bits);
    const CHANNEL_BITS = red_bits + green_bits + blue_bits + alpha_bits;
    const CHANNEL_BYTES = ((CHANNEL_BITS + 7) >> 3);
    const INT_BITS = @typeInfo(integer_type).int.bits;
    const PAD = @Int(.unsigned, INT_BITS - CHANNEL_BITS);
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

            pub fn reorder(self: Self, comptime new_order: SDL_ChannelOrder) define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits) {
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

            pub fn reorder(self: Self, comptime new_order: SDL_ChannelOrder) define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits) {
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

            pub fn reorder(self: Self, comptime new_order: SDL_ChannelOrder) define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits) {
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

            pub fn reorder(self: Self, comptime new_order: SDL_ChannelOrder) define_packed_color_type(new_order, red_bits, green_bits, blue_bits, alpha_bits) {
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
        const T_RAW = @Int(.unsigned, @bitSizeOf(T_RGBA));
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
        const T_RAW = @Int(.unsigned, @bitSizeOf(T_RGBA));
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
