const std = @import("std");

const Root = @import("root");

pub fn define_color_rgba_type(comptime T: type) type {
    return extern struct {
        r: T = 0,
        g: T = 0,
        b: T = 0,
        a: T = 0,

        const T_RGBA = @This();
        const T_RGB = define_color_rgb_type(T);
        const T_RAW = std.meta.Int(.unsigned, @bitSizeOf(T_RGBA));

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
