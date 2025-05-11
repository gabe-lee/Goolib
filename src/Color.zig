const std = @import("std");

const Root = @import("root");

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

pub fn define_packed_color_type(comptime order: ChannelOrder, comptime red_bits: comptime_int, comptime green_bits: comptime_int, comptime blue_bits: comptime_int, comptime alpha_bits: comptime_int) type {
    const R_INT = std.meta.Int(.unsigned, red_bits);
    const G_INT = std.meta.Int(.unsigned, green_bits);
    const B_INT = std.meta.Int(.unsigned, blue_bits);
    const A_INT = std.meta.Int(.unsigned, alpha_bits);
    const CHANNEL_BITS = red_bits + green_bits + blue_bits + alpha_bits;
    const CHANNEL_BYTES = ((CHANNEL_BITS + 7) >> 3);
    const PAD = std.meta.Int(.unsigned, 32 - CHANNEL_BITS);
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

        pub fn new(r: T, g: T, b: T, a: T) T_RGBA {
            return T_RGBA{ .r = r, .g = g, .b = b, .a = a };
        }
        pub fn new_opaque(r: T, g: T, b: T) T_RGBA {
            return T_RGBA{ .r = r, .g = g, .b = b, .a = MAX };
        }

        pub const WHITE = T_RGBA{ .r = MAX, .g = MAX, .b = MAX, .a = MAX };

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
    };
}
