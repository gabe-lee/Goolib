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
const math = std.math;
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const PointOrientation = Root.CommonTypes.PointOrientation;
const SDL3 = Root.SDL3;

// pub const Vec2ExtraOptions = struct {
//     convert_SDL3: bool = false,
// };

pub const PerpendicularZero = enum(u8) {
    perp_zero_is_zero,
    perp_zero_is_y_magnitude_1,
};

pub fn define_vec2_type(comptime T: type) type {
    return extern struct {
        const T_Vec2 = @This();
        const T_Rect2 = Root.Rect2.define_rect2_type(T);
        const IS_FLOAT = switch (T) {
            f16, f32, f64, f80, f128, c_longdouble => true,
            else => false,
        };
        const IS_INT = switch (T) {
            i8, i16, i32, i64, i128, isize, u8, u16, u32, u64, u128, usize, c_short, c_int, c_long, c_longlong, c_char, c_ushort, c_uint, c_ulong, c_ulonglong => true,
            else => false,
        };

        x: T = 0,
        y: T = 0,

        pub const ZERO_ZERO = T_Vec2{ .x = 0, .y = 0 };
        pub const ZERO_ONE = T_Vec2{ .x = 0, .y = 1 };
        pub const ONE_ZERO = T_Vec2{ .x = 1, .y = 0 };
        pub const ONE_ONE = T_Vec2{ .x = 1, .y = 1 };
        pub const MIN_MIN = T_Vec2{ .x = MIN, .y = MIN };
        pub const MAX_MAX = T_Vec2{ .x = MAX, .y = MAX };
        pub const MIN = if (IS_FLOAT) -math.inf(T) else math.minInt(T);
        pub const MAX = if (IS_FLOAT) math.inf(T) else math.maxInt(T);

        pub fn new(x: T, y: T) T_Vec2 {
            return T_Vec2{ .x = x, .y = y };
        }

        pub fn inverse(self: T_Vec2) T_Vec2 {
            return T_Vec2{ .x = 1 / self.x, .y = 1 / self.y };
        }

        pub fn dot_product(self: T_Vec2, other: T_Vec2) T {
            return (self.x * other.x) + (self.y * other.y);
        }
        pub inline fn dot(self: T_Vec2, other: T_Vec2) T {
            return self.dot_product(other);
        }
        pub fn dot_product_self(self: T_Vec2) T {
            return (self.x * self.x) + (self.y * self.y);
        }
        pub inline fn dot_self(self: T_Vec2) T {
            return self.dot_product_self();
        }

        pub fn cross_product(self: T_Vec2, other: T_Vec2) T {
            return (self.x * other.y) - (self.y * other.x);
        }
        pub inline fn cross(self: T_Vec2, other: T_Vec2) T {
            return self.cross_product(other);
        }

        pub fn add(self: T_Vec2, other: T_Vec2) T_Vec2 {
            return T_Vec2{ .x = self.x + other.x, .y = self.y + other.y };
        }

        pub fn subtract(self: T_Vec2, other: T_Vec2) T_Vec2 {
            return T_Vec2{ .x = self.x - other.x, .y = self.y - other.y };
        }

        pub fn multiply(self: T_Vec2, other: T_Vec2) T_Vec2 {
            return T_Vec2{ .x = self.x * other.x, .y = self.y * other.y };
        }

        pub fn scale(self: T_Vec2, val: T) T_Vec2 {
            return T_Vec2{ .x = self.x * val, .y = self.y * val };
        }

        pub fn add_scale(self: T_Vec2, add_vec: T_Vec2, scale_add_vec_by: T) T_Vec2 {
            return T_Vec2{ .x = self.x + (add_vec.x * scale_add_vec_by), .y = self.y + (add_vec.y * scale_add_vec_by) };
        }

        pub fn divide(self: T_Vec2, other: T_Vec2) T_Vec2 {
            assert(other.x != 0 and other.y != 0);
            return T_Vec2{ .x = self.x / other.x, .y = self.y / other.y };
        }

        pub fn distance_to(self: T_Vec2, other: T_Vec2) T {
            const diff = T_Vec2{ .x = other.x - self.x, .y = other.y - self.y };
            return math.sqrt((diff.x * diff.x) + (diff.y * diff.y));
        }

        pub fn distance_to_squared(self: T_Vec2, other: T_Vec2) T {
            const diff = T_Vec2{ .x = other.x - self.x, .y = other.y - self.y };
            return (diff.x * diff.x) + (diff.y * diff.y);
        }

        pub fn length(self: T_Vec2) T {
            return math.sqrt((self.x * self.x) + (self.y * self.y));
        }

        pub fn length_squared(self: T_Vec2) T {
            return (self.x * self.x) + (self.y * self.y);
        }

        pub fn length_using_squares(x_squared: T, y_squared: T) T {
            assert(x_squared >= 0 and y_squared >= 0);
            return math.sqrt(x_squared + y_squared);
        }

        pub fn normalize(self: T_Vec2) T_Vec2 {
            assert(self.x != 0 or self.y != 0);
            const len = math.sqrt((self.x * self.x) + (self.y * self.y));
            return T_Vec2{ .x = self.x / len, .y = self.y / len };
        }

        pub fn normalize_using_length(self: T_Vec2, len: T) T_Vec2 {
            assert(len != 0);
            return T_Vec2{ .x = self.x / len, .y = self.y / len };
        }

        pub fn normalize_using_squares(self: T_Vec2, x_squared: T, y_squared: T) T_Vec2 {
            assert(x_squared != 0 or y_squared != 0);
            assert(x_squared >= 0 and y_squared >= 0);
            const len = math.sqrt(x_squared + y_squared);
            return T_Vec2{ .x = self.x / len, .y = self.y / len };
        }

        pub fn orthoganal_normal_ccw(self: T_Vec2, comptime zero_behavior: PerpendicularZero) T_Vec2 {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                return .new(0, if (zero_behavior == .perp_zero_is_zero) 0 else 1);
            }
            const len = self.length();
            return self.normalize_using_length(len).perp_ccw();
        }
        pub fn orthoganal_normal_cw(self: T_Vec2, comptime zero_behavior: PerpendicularZero) T_Vec2 {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                return .new(0, if (zero_behavior == .perp_zero_is_zero) 0 else -1);
            }
            const len = self.length();
            return self.normalize_using_length(len).perp_cw();
        }

        pub fn angle_between(self: T_Vec2, other: T_Vec2) T {
            const dot_prod = (self.x * other.x) + (self.y * other.y);
            const lengths_multiplied = math.sqrt((self.x * self.x) + (self.y * self.y)) * math.sqrt((other.x * other.x) + (other.y * other.y));
            return math.acos(dot_prod / lengths_multiplied);
        }

        pub fn angle_between_using_lengths(self: T_Vec2, other: T_Vec2, len_self: T, len_other: T) T {
            const dot_prod = (self.x * other.x) + (self.y * other.y);
            const lengths_multiplied = len_self * len_other;
            return math.acos(dot_prod / lengths_multiplied);
        }

        pub fn angle_between_using_norms(self: T_Vec2, other: T_Vec2) T {
            const dot_prod = (self.x * other.x) + (self.y * other.y);
            return math.acos(dot_prod);
        }

        pub fn ratio_a_to_b(a: T_Vec2, b: T_Vec2) T {
            assert(a.x != 0 or a.y != 0);
            if (a.x == 0) return b.y / a.y;
            return b.x / a.x;
        }

        pub fn perp_ccw(self: T_Vec2) T_Vec2 {
            return T_Vec2{ .x = -self.y, .y = self.x };
        }

        pub fn perp_cw(self: T_Vec2) T_Vec2 {
            return T_Vec2{ .x = self.y, .y = -self.x };
        }

        pub fn lerp(self: T_Vec2, p2: T_Vec2, percent: T) T_Vec2 {
            return T_Vec2{ .x = ((p2.x - self.x) * percent) + self.x, .y = ((p2.y - self.y) * percent) + self.y };
        }
        pub inline fn linear_interp(self: T_Vec2, p2: T_Vec2, percent: T) T_Vec2 {
            return self.lerp(p2, percent);
        }
        pub fn quad_interp(self: T_Vec2, p2: T_Vec2, p3: T_Vec2, percent: T) T_Vec2 {
            const p12 = self.lerp(p2, percent);
            const p23 = p2.lerp(p3, percent);
            return p12.lerp(p23, percent);
        }
        pub fn cubic_interp(self: T_Vec2, p2: T_Vec2, p3: T_Vec2, p4: T_Vec2, percent: T) T_Vec2 {
            const p12 = self.lerp(p2, percent);
            const p23 = p2.lerp(p3, percent);
            const p34 = p3.lerp(p4, percent);
            const p12_23 = p12.lerp(p23, percent);
            const p23_34 = p23.lerp(p34, percent);
            return p12_23.lerp(p23_34, percent);
        }

        pub fn lerp_delta_min_max(self: T_Vec2, other: T_Vec2, min_delta: T, max_delta: T, delta: T) T_Vec2 {
            const percent = (delta - min_delta) / (max_delta - min_delta);
            return T_Vec2{ .x = ((other.x - self.x) * percent) + self.x, .y = ((other.y - self.y) * percent) + self.y };
        }

        pub fn lerp_delta_max(self: T_Vec2, other: T_Vec2, max_delta: T, delta: T) T_Vec2 {
            const percent = delta / max_delta;
            return T_Vec2{ .x = ((other.x - self.x) * percent) + self.x, .y = ((other.y - self.y) * percent) + self.y };
        }

        pub fn rotate_radians(self: T_Vec2, radians: T) T_Vec2 {
            const cos = @cos(radians);
            const sin = @sin(radians);
            return T_Vec2{ .x = (self.x * cos) - (self.y * sin), .y = (self.x * sin) + (self.y * cos) };
        }

        pub fn rotate_degrees(self: T_Vec2, degrees: T) T_Vec2 {
            const rads = degrees * math.rad_per_deg;
            const cos = @cos(rads);
            const sin = @sin(rads);
            return T_Vec2{ .x = (self.x * cos) - (self.y * sin), .y = (self.x * sin) + (self.y * cos) };
        }

        pub fn rotate_sin_cos(self: T_Vec2, sin: T, cos: T) T_Vec2 {
            return T_Vec2{ .x = (self.x * cos) - (self.y * sin), .y = (self.x * sin) + (self.y * cos) };
        }

        pub fn reflect(self: T_Vec2, reflect_normal: T_Vec2) T_Vec2 {
            const fix_scale = 2 * ((self.x * reflect_normal.x) + (self.y * reflect_normal.y));
            return T_Vec2{ .x = self.x - (reflect_normal.x * fix_scale), .y = self.y - (reflect_normal.y * fix_scale) };
        }

        pub fn negate(self: T_Vec2) T_Vec2 {
            return T_Vec2{ .x = -self.x, .y = -self.y };
        }

        pub fn equals(self: T_Vec2, other: T_Vec2) bool {
            return self.x == other.x and self.y == other.y;
        }

        pub fn approx_equal(self: T_Vec2, other: T_Vec2) bool {
            return Root.Math.approx_equal(T, self.x, other.x) and Root.Math.approx_equal(T, self.y, other.y);
        }

        pub fn is_zero(self: T_Vec2) bool {
            return self.x == 0 and self.y == 0;
        }
        pub fn non_zero(self: T_Vec2) bool {
            return self.x != 0 or self.y != 0;
        }

        pub fn approx_colinear(self: T_Vec2, other_a: T_Vec2, other_b: T_Vec2) bool {
            const cross_3 = ((other_b.y - self.y) * (other_a.x - self.x)) - ((other_b.x - self.x) * (other_a.y - self.y));
            return @abs(cross_3) <= math.floatEpsAt(f32, cross_3);
        }

        pub fn colinear(self: T_Vec2, other_a: T_Vec2, other_b: T_Vec2) bool {
            const cross_3 = ((other_b.y - self.y) * (other_a.x - self.x)) - ((other_b.x - self.x) * (other_a.y - self.y));
            return cross_3 == 0;
        }

        pub fn approx_orientation(self: T_Vec2, other_a: T_Vec2, other_b: T_Vec2) PointOrientation {
            const cross_3 = ((other_b.y - self.y) * (other_a.x - self.x)) - ((other_b.x - self.x) * (other_a.y - self.y));
            if (@abs(cross_3) <= math.floatEpsAt(f32, cross_3)) return PointOrientation.COLINEAR;
            if (cross_3 > 0) return PointOrientation.WINDING_CW;
            return PointOrientation.WINDING_CCW;
        }

        pub fn orientation(self: T_Vec2, other_a: T_Vec2, other_b: T_Vec2) PointOrientation {
            const cross_3 = ((other_b.y - self.y) * (other_a.x - self.x)) - ((other_b.x - self.x) * (other_a.y - self.y));
            if (cross_3 == 0) return PointOrientation.COLINEAR;
            if (cross_3 > 0) return PointOrientation.WINDING_CW;
            return PointOrientation.WINDING_CCW;
        }

        pub fn approx_on_segment(self: T_Vec2, line_a: T_Vec2, line_b: T_Vec2) bool {
            if (self.approx_orientation(line_a, line_b) != PointOrientation.COLINEAR) return false;
            const line_aabb = T_Rect2.from_static_line(line_a, line_b);
            return line_aabb.point_approx_within(self);
        }

        pub fn on_segment(self: T_Vec2, line_a: T_Vec2, line_b: T_Vec2) bool {
            if (self.orientation(line_a, line_b) != PointOrientation.COLINEAR) return false;
            const line_aabb = T_Rect2.from_static_line(line_a, line_b);
            return line_aabb.point_within(self);
        }

        pub fn velocity_required_to_reach_point_at_time(self: T_Vec2, point: T_Vec2, time: T) T_Vec2 {
            return point.subtract(self).scale(1.0 / time);
        }

        pub fn velocity_required_to_reach_point_inverse_time(self: T_Vec2, point: T_Vec2, inverse_time: T) T_Vec2 {
            return point.subtract(self).scale(inverse_time);
        }

        pub fn to_new_type(self: T_Vec2, comptime NEW_T: type) define_vec2_type(NEW_T) {
            const V = define_vec2_type(NEW_T);
            const mode = @as(u8, @bitCast(IS_FLOAT)) | (@as(u8, @bitCast(V.IS_FLOAT)) << 1);
            const FLOAT_TO_FLOAT: u8 = 0b11;
            const FLOAT_TO_INT: u8 = 0b01;
            const INT_TO_INT: u8 = 0b00;
            const INT_TO_FLOAT: u8 = 0b10;
            switch (mode) {
                FLOAT_TO_FLOAT => return V{
                    .x = @floatCast(self.x),
                    .y = @floatCast(self.y),
                },
                FLOAT_TO_INT => return V{
                    .x = @intFromFloat(self.x),
                    .y = @intFromFloat(self.y),
                },
                INT_TO_INT => return V{
                    .x = @intCast(self.x),
                    .y = @intCast(self.y),
                },
                INT_TO_FLOAT => return V{
                    .x = @floatFromInt(self.x),
                    .y = @floatFromInt(self.y),
                },
                else => unreachable,
            }
        }
    };
}
