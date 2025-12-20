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
const ShapeWinding = Root.CommonTypes.ShapeWinding;
const Assert = Root.Assert;
const MathX = Root.Math;
const SDL3 = Root.SDL3;

const assert_is_float = Assert.assert_is_float;
const assert_with_reason = Assert.assert_with_reason;
const num_cast = Root.Cast.num_cast;

// pub const Vec2ExtraOptions = struct {
//     convert_SDL3: bool = false,
// };

pub const PerpendicularZero = enum(u8) {
    perp_zero_is_zero,
    perp_zero_is_y_magnitude_1,
};
pub const NormalizeZero = enum(u8) {
    norm_zero_is_zero,
    norm_zero_is_y_magnitude_1,
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
        const IS_LARGE_INT = switch (T) {
            i64, i128, isize, u64, u128, usize, c_long, c_longlong, c_ulong, c_ulonglong => true,
            else => false,
        };
        pub const F = if (IS_FLOAT) T else if (IS_LARGE_INT) f64 else f32;

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
        pub fn new_from_any(x: anytype, y: anytype) T_Vec2 {
            return T_Vec2{ .x = num_cast(x, T), .y = num_cast(y, T) };
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

        pub inline fn shoelace(self: T_Vec2, next: T_Vec2) T {
            return (next.x - self.x) * (self.y + next.y);
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

        pub fn scale(self: T_Vec2, val: anytype) T_Vec2 {
            return T_Vec2{ .x = MathX.upgrade_multiply_out(self.x, val, T), .y = MathX.upgrade_multiply_out(self.y, val, T) };
        }

        pub fn add_scale(self: T_Vec2, add_vec: T_Vec2, scale_add_vec_by: anytype) T_Vec2 {
            return T_Vec2{ .x = self.x + MathX.upgrade_multiply_out(add_vec.x, scale_add_vec_by, T), .y = self.y + MathX.upgrade_multiply_out(add_vec.y, scale_add_vec_by, T) };
        }

        pub fn subtract_scale(self: T_Vec2, subtract_vec: T_Vec2, scale_subtract_vec_by: anytype) T_Vec2 {
            return T_Vec2{ .x = self.x - MathX.upgrade_multiply_out(subtract_vec.x, scale_subtract_vec_by, T), .y = self.y - MathX.upgrade_multiply_out(subtract_vec.y, scale_subtract_vec_by, T) };
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

        pub fn normalize_may_be_zero(self: T_Vec2, comptime zero_behavior: NormalizeZero) T_Vec2 {
            if (self.x == 0 and self.y == 0) {
                return T_Vec2.new(0, if (zero_behavior == .norm_zero_is_zero) 0 else 1);
            }
            const len = math.sqrt((self.x * self.x) + (self.y * self.y));
            return T_Vec2{ .x = self.x / len, .y = self.y / len };
        }
        pub fn normalize_may_be_zero_with_length(self: T_Vec2, len: T, comptime zero_behavior: NormalizeZero) T_Vec2 {
            if (len == 0) {
                return T_Vec2.new(0, if (zero_behavior == .norm_zero_is_zero) 0 else 1);
            }
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

        pub fn angle_between(self: T_Vec2, other: T_Vec2, comptime OUT: type) OUT {
            const dot_prod = (self.x * other.x) + (self.y * other.y);
            const lengths_multiplied = @sqrt(MathX.upgrade_to_float((self.x * self.x) + (self.y * self.y), f32)) * @sqrt(MathX.upgrade_to_float((other.x * other.x) + (other.y * other.y), f32));
            return num_cast(math.acos(MathX.upgrade_to_float(dot_prod, f32) / MathX.upgrade_to_float(lengths_multiplied, f32)), OUT);
        }

        pub fn angle_between_using_lengths(self: T_Vec2, other: T_Vec2, len_self: anytype, len_other: anytype, comptime OUT: type) OUT {
            const dot_prod = (self.x * other.x) + (self.y * other.y);
            const lengths_multiplied = MathX.upgrade_multiply(len_self, len_other);
            return num_cast(math.acos(MathX.upgrade_to_float(dot_prod, f32) / MathX.upgrade_to_float(lengths_multiplied, f32)), OUT);
        }

        pub fn angle_between_using_norms(self: T_Vec2, other: T_Vec2, comptime OUT: type) OUT {
            const dot_prod = (self.x * other.x) + (self.y * other.y);
            return num_cast(math.acos(MathX.upgrade_to_float(dot_prod, f32)), OUT);
        }

        pub const MiterNormsAndOffset = struct {
            corner_to_prev_norm: T_Vec2 = .ZERO_ZERO,
            corner_to_next_norm: T_Vec2 = .ZERO_ZERO,
            inner_miter_offset_norm: T_Vec2 = .ZERO_ZERO,
        };

        pub const MiterResult = struct {
            corner_to_prev_norm: T_Vec2 = .ZERO_ZERO,
            corner_to_next_norm: T_Vec2 = .ZERO_ZERO,
            inner_miter_offset_norm: T_Vec2 = .ZERO_ZERO,
            inner_offset: T_Vec2 = .ZERO_ZERO,
            inner_point: T_Vec2 = .ZERO_ZERO,
            outer_point: T_Vec2 = .ZERO_ZERO,
            infinite: bool = false,

            pub fn new_infinite(norms: MiterNormsAndOffset) MiterResult {
                return MiterResult{
                    .corner_to_next_norm = norms.corner_to_next_norm,
                    .corner_to_prev_norm = norms.corner_to_prev_norm,
                    .inner_miter_offset_norm = norms.inner_miter_offset_norm,
                    .infinite = true,
                };
            }
            pub fn new_infinite_seg_norms_only(corner_to_prev_norm: T_Vec2, corner_to_next_norm: T_Vec2) MiterResult {
                return MiterResult{
                    .corner_to_next_norm = corner_to_next_norm,
                    .corner_to_prev_norm = corner_to_prev_norm,
                    .inner_miter_offset_norm = corner_to_next_norm,
                    .infinite = true,
                };
            }
        };

        pub fn miter_points_same_line_width(corner: T_Vec2, prev_point: T_Vec2, next_point: T_Vec2, width: anytype) MiterResult {
            const norms = corner.inner_miter_offset_normal_same_line_width(prev_point, next_point);
            return corner.miter_points_same_line_width_using_norms(norms, width);
        }
        pub fn miter_points_same_line_width_using_norms(corner: T_Vec2, norms: MiterNormsAndOffset, width: anytype) MiterResult {
            const angle_between_segs = norms.corner_to_prev_norm.angle_between_using_norms(norms.corner_to_next_norm, f32);
            if (angle_between_segs == 0) return MiterResult.new_infinite(norms);
            const miter_length = MathX.upgrade_divide(MathX.upgrade_divide(width, 2.0), @sin(MathX.upgrade_divide(angle_between_segs, 2.0)));
            const miter_offset_inner = norms.inner_miter_offset_norm.scale(miter_length);
            const miter_inner = corner.add(miter_offset_inner);
            const miter_outer = corner.subtract(miter_offset_inner);
            return MiterResult{
                .inner_point = miter_inner,
                .outer_point = miter_outer,
                .inner_offset = miter_offset_inner,
                .inner_offset_norm = norms.inner_miter_offset_norm,
                .corner_to_next_norm = norms.corner_to_next_norm,
                .corner_to_prev_norm = norms.corner_to_prev_norm,
            };
        }
        pub fn miter_outer_points_same_line_width(corner: T_Vec2, prev_point: T_Vec2, next_point: T_Vec2, width: anytype) MiterResult {
            const norms = corner.inner_miter_offset_normal_same_line_width(prev_point, next_point);
            return corner.miter_outer_point_same_line_width_using_norms(norms, width);
        }
        pub fn miter_outer_point_same_line_width_using_norms(corner: T_Vec2, norms: MiterNormsAndOffset, width: anytype) MiterResult {
            const angle_between_segs = norms.corner_to_prev_norm.angle_between_using_norms(norms.corner_to_next_norm, f32);
            if (angle_between_segs == 0) return MiterResult.new_infinite(norms);
            const miter_length = MathX.upgrade_divide(MathX.upgrade_divide(width, 2.0), @sin(MathX.upgrade_divide(angle_between_segs, 2.0)));
            const miter_offset_inner = norms.inner_miter_offset_norm.scale(miter_length);
            const miter_outer = corner.subtract(miter_offset_inner);
            return MiterResult{
                .inner_point = .ZERO_ZERO,
                .outer_point = miter_outer,
                .inner_offset = miter_offset_inner,
                .inner_offset_norm = norms.inner_miter_offset_norm,
                .corner_to_next_norm = norms.corner_to_next_norm,
                .corner_to_prev_norm = norms.corner_to_prev_norm,
            };
        }
        pub fn inner_miter_offset_normal_same_line_width(corner: T_Vec2, prev_point: T_Vec2, next_point: T_Vec2) MiterNormsAndOffset {
            const delta_prev_norm = prev_point.subtract(corner).normalize_may_be_zero(.norm_zero_is_zero);
            const delta_next_norm = next_point.subtract(corner).normalize_may_be_zero(.norm_zero_is_zero);
            const miter_offset_norm_inner = delta_prev_norm.lerp(delta_next_norm, 0.5).normalize_may_be_zero(.norm_zero_is_zero);
            return MiterNormsAndOffset{
                .corner_to_prev_norm = delta_prev_norm,
                .corner_to_next_norm = delta_next_norm,
                .inner_miter_offset_norm = miter_offset_norm_inner,
            };
        }
        pub fn miter_different_widths_no_inner_normal(corner: T_Vec2, prev_point: T_Vec2, prev_segment_width: anytype, next_point: T_Vec2, next_segment_width: anytype) MiterResult {
            const delta_prev_norm = prev_point.subtract(corner).normalize_may_be_zero(.norm_zero_is_zero);
            const delta_next_norm = next_point.subtract(corner).normalize_may_be_zero(.norm_zero_is_zero);
            const angle_between_segs = delta_prev_norm.angle_between_using_norms(delta_next_norm, f32);
            const sin_angle_between = @sin(angle_between_segs);
            if (angle_between_segs == 0) return MiterResult.new_infinite_seg_norms_only(delta_prev_norm, delta_next_norm);
            const len_prev_seg = next_segment_width / sin_angle_between;
            const len_next_seg = prev_segment_width / sin_angle_between;
            const delta_1 = delta_prev_norm.scale(len_prev_seg);
            const delta_2 = delta_next_norm.scale(len_next_seg);
            const inner_offset = delta_1 + delta_2;
            const inner_point = corner.add(inner_offset);
            const outer_point = corner.subtract(inner_offset);
            return MiterResult{
                .corner_to_prev_norm = delta_prev_norm,
                .corner_to_next_norm = delta_next_norm,
                .inner_offset = inner_offset,
                .inner_point = inner_point,
                .outer_point = outer_point,
            };
        }
        pub fn miter_different_widths_with_inner_normal(corner: T_Vec2, prev_point: T_Vec2, prev_segment_width: anytype, next_point: T_Vec2, next_segment_width: anytype) MiterResult {
            var result = corner.miter_different_widths_no_inner_normal(prev_point, prev_segment_width, next_point, next_segment_width);
            result.inner_miter_offset_norm = result.inner_offset.normalize_may_be_zero(.norm_zero_is_zero);
        }

        /// Assuming `a` and `b` are vectors from the origin (0, 0)
        /// AND are colinear, return the ratio of the length
        /// of `a` compared to the legnth of `b`
        ///
        /// equals `a.x / b.x` or `a.y / b.y`
        pub fn colinear_ratio_a_of_b(a: T_Vec2, b: T_Vec2) T {
            assert(a.x != 0 or a.y != 0);
            if (a.x == 0) return a.y / b.y;
            return a.x / b.x;
        }

        pub fn perp_ccw(self: T_Vec2) T_Vec2 {
            return T_Vec2{ .x = -self.y, .y = self.x };
        }
        pub fn perp_left(self: T_Vec2) T_Vec2 {
            return self.perp_ccw();
        }

        pub fn perp_cw(self: T_Vec2) T_Vec2 {
            return T_Vec2{ .x = self.y, .y = -self.x };
        }
        pub fn perp_right(self: T_Vec2) T_Vec2 {
            return self.perp_cw();
        }

        pub fn lerp(self: T_Vec2, p2: T_Vec2, percent: anytype) T_Vec2 {
            assert_is_float(@TypeOf(percent));
            return T_Vec2{ .x = MathX.upgrade_lerp_out(self.x, p2.x, percent, T), .y = MathX.upgrade_lerp_out(self.y, p2.y, percent, T) };
        }
        pub inline fn linear_interp(p1: T_Vec2, p2: T_Vec2, percent: anytype) T_Vec2 {
            return p1.lerp(p2, percent);
        }
        pub fn quadratic_interp(p1: T_Vec2, p2: T_Vec2, p3: T_Vec2, percent: anytype) T_Vec2 {
            const p12 = p1.lerp(p2, percent);
            const p23 = p2.lerp(p3, percent);
            return p12.lerp(p23, percent);
        }
        pub fn cubic_interp(p1: T_Vec2, p2: T_Vec2, p3: T_Vec2, p4: T_Vec2, percent: anytype) T_Vec2 {
            const p12 = p1.lerp(p2, percent);
            const p23 = p2.lerp(p3, percent);
            const p34 = p3.lerp(p4, percent);
            const p12_23 = p12.lerp(p23, percent);
            const p23_34 = p23.lerp(p34, percent);
            return p12_23.lerp(p23_34, percent);
        }
        pub fn n_bezier_interp(comptime N: comptime_int, p: [N]T_Vec2, percent: anytype) T_Vec2 {
            var tmp: [2][N]T_Vec2 = .{ p, @splat(T_Vec2{}) };
            var curr: usize = 0;
            var next: usize = 1;
            var curr_points: usize = N;
            var i: usize = undefined;
            var j: usize = undefined;
            while (curr_points > 1) {
                i = 0;
                j = 1;
                while (j < curr_points) {
                    tmp[next][i] = tmp[curr][i].lerp(tmp[curr][j], percent);
                    i = j;
                    j += 1;
                }
                curr_points -= 1;
                curr = curr ^ 1;
                next = next ^ 1;
            }
            return tmp[curr][0];
        }

        pub fn lerp_delta_range(self: T_Vec2, other: T_Vec2, min_delta: anytype, max_delta: anytype, range_delta: anytype) T_Vec2 {
            const range = MathX.upgrade_subtract(max_delta, min_delta);
            const range_percent = MathX.upgrade_multiply(range, range_delta);
            const percent = MathX.upgrade_add(min_delta, range_percent);
            return T_Vec2{ .x = MathX.upgrade_multiply_out((other.x - self.x), percent, T) + self.x, .y = MathX.upgrade_multiply_out((other.y - self.y), percent, T) + self.y };
        }

        pub fn lerp_delta_delta(self: T_Vec2, other: T_Vec2, delta: anytype, delta_delta: anytype) T_Vec2 {
            const percent = MathX.upgrade_multiply(delta, delta_delta);
            return T_Vec2{ .x = MathX.upgrade_multiply_out((other.x - self.x), percent, T) + self.x, .y = MathX.upgrade_multiply_out((other.y - self.y), percent, T) + self.y };
        }

        pub fn rotate_radians(self: T_Vec2, radians: anytype) T_Vec2 {
            const cos = @cos(radians);
            const sin = @sin(radians);
            return T_Vec2{ .x = MathX.upgrade_multiply_out(self.x, cos, T) - MathX.upgrade_multiply_out(self.y, sin, T), .y = MathX.upgrade_multiply_out(self.x, sin, T) + MathX.upgrade_multiply_out(self.y, cos, T) };
        }

        pub fn rotate_degrees(self: T_Vec2, degrees: T) T_Vec2 {
            const rads = degrees * math.rad_per_deg;
            const cos = @cos(rads);
            const sin = @sin(rads);
            return T_Vec2{ .x = MathX.upgrade_multiply_out(self.x, cos, T) - MathX.upgrade_multiply_out(self.y, sin, T), .y = MathX.upgrade_multiply_out(self.x, sin, T) + MathX.upgrade_multiply_out(self.y, cos, T) };
        }

        pub fn rotate_sin_cos(self: T_Vec2, sin: T, cos: T) T_Vec2 {
            return T_Vec2{ .x = MathX.upgrade_multiply_out(self.x, cos, T) - MathX.upgrade_multiply_out(self.y, sin, T), .y = MathX.upgrade_multiply_out(self.x, sin, T) + MathX.upgrade_multiply_out(self.y, cos, T) };
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

        pub fn slope(self: T_Vec2) T {
            return self.y / self.x;
        }

        pub fn approx_colinear(self: T_Vec2, other_a: T_Vec2, other_b: T_Vec2) bool {
            const cross_3 = ((other_b.y - self.y) * (other_a.x - self.x)) - ((other_b.x - self.x) * (other_a.y - self.y));
            return @abs(cross_3) <= math.floatEpsAt(f32, cross_3);
        }

        pub fn colinear(self: T_Vec2, other_a: T_Vec2, other_b: T_Vec2) bool {
            const cross_3 = ((other_b.y - self.y) * (other_a.x - self.x)) - ((other_b.x - self.x) * (other_a.y - self.y));
            return cross_3 == 0;
        }

        pub fn approx_orientation(a: T_Vec2, b: T_Vec2, c: T_Vec2) ShapeWinding {
            const cross_3 = ((c.y - a.y) * (b.x - a.x)) - ((c.x - a.x) * (b.y - a.y));
            if (@abs(cross_3) <= math.floatEpsAt(f32, cross_3)) return ShapeWinding.COLINEAR;
            if (cross_3 > 0) return ShapeWinding.WINDING_CW;
            return ShapeWinding.WINDING_CCW;
        }

        pub fn orientation(a: T_Vec2, b: T_Vec2, c: T_Vec2) ShapeWinding {
            const cross_3 = ((c.y - a.y) * (b.x - a.x)) - ((c.x - a.x) * (b.y - a.y));
            if (cross_3 == 0) return ShapeWinding.COLINEAR;
            if (cross_3 > 0) return ShapeWinding.WINDING_CW;
            return ShapeWinding.WINDING_CCW;
        }

        pub fn approx_on_segment(self: T_Vec2, line_a: T_Vec2, line_b: T_Vec2) bool {
            if (self.approx_orientation(line_a, line_b) != ShapeWinding.COLINEAR) return false;
            const line_aabb = T_Rect2.from_static_line(line_a, line_b);
            return line_aabb.point_approx_within(self);
        }

        pub fn on_segment(self: T_Vec2, line_a: T_Vec2, line_b: T_Vec2) bool {
            if (self.orientation(line_a, line_b) != ShapeWinding.COLINEAR) return false;
            const line_aabb = T_Rect2.from_static_line(line_a, line_b);
            return line_aabb.point_within(self);
        }

        pub fn rate_required_to_reach_point_at_time(self: T_Vec2, point: T_Vec2, time: anytype) T_Vec2 {
            return point.subtract(self).scale(1.0 / time);
        }

        pub fn rate_required_to_reach_point_inverse_time(self: T_Vec2, point: T_Vec2, inverse_time: anytype) T_Vec2 {
            return point.subtract(self).scale(inverse_time);
        }

        pub fn to_new_type(self: T_Vec2, comptime NEW_T: type) define_vec2_type(NEW_T) {
            const V = define_vec2_type(NEW_T);
            return V{
                .x = num_cast(self.x, NEW_T),
                .y = num_cast(self.y, NEW_T),
            };
        }

        pub fn forms_corner_simple(self: T_Vec2, other: T_Vec2) bool {
            return self.dot(other) <= 0;
        }

        /// Where:
        ///   - `ratio == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `ratio == 1` means the vectors always form a corner even if they are pointing in the exact same direction
        ///   - `ratio == -1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_flatness_ratio(self: T_Vec2, other: T_Vec2, ratio: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), @cos(MathX.HALF_PI - (MathX.upgrade_to_float(ratio, f32) * MathX.HALF_PI)));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `ratio == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `ratio == 1` means the vectors always form a corner even if they are pointing in the exact same direction
        ///   - `ratio == -1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_flatness_ratio_using_lengths(self: T_Vec2, self_len: T, other: T_Vec2, other_len: T, ratio: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, @cos(MathX.HALF_PI - (MathX.upgrade_to_float(ratio, f32) * MathX.HALF_PI)));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `threshold == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `threshold > 0` means the vectors form a corner if they are perpendicular, point in generally opposite directions, or point in somewhat the same direction but not enough to cross above the threshold (higher numbers allow 'flatter' corners to pass)
        ///   - `threshold < 0` means the vectors only form a corner if they are pointing in opposite directions enough to remain below the threshold (lower numbers require 'sharper' corners to pass)
        pub fn forms_corner_dot_product_threshold(self: T_Vec2, other: T_Vec2, threshold: anytype) bool {
            return self.dot(other) <= threshold;
        }
        /// Where:
        ///   - `@abs(threshold) == 0` means the vectors only DONT form a corner if they point in EXACTLY the same direction
        ///   - `@abs(threshold) > 0` means the vectors only form a corner if they are perpendicular, point in generally opposite directions, or point in somewhat the same dirction but not enough to fall below the threshold (smaller numbers allow 'flatter' corners to pass)
        pub fn forms_corner_dot_or_cross_product_threshold(self: T_Vec2, other: T_Vec2, threshold: anytype) bool {
            return self.dot(other) <= threshold or @abs(self.cross(other)) > threshold;
        }
        /// Where:
        ///   - `degrees == 180` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `degrees == 90` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `degrees == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and 180
        pub fn forms_corner_less_than_degrees(self: T_Vec2, other: T_Vec2, degrees: anytype) bool {
            const rads = MathX.DEG_TO_RAD * MathX.clamp(0, degrees, 180);
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), @cos(rads));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `degrees == 180` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `degrees == 90` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `degrees == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and 180
        pub fn forms_corner_less_than_degrees_using_lengths(self: T_Vec2, self_len: T, other: T_Vec2, other_len: T, degrees: anytype) bool {
            const rads = MathX.DEG_TO_RAD * MathX.clamp(0, degrees, 180);
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, @cos(rads));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `radians == PI` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `radians == HALF_PI` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `radians == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and PI
        pub fn forms_corner_less_than_radians(self: T_Vec2, other: T_Vec2, radians: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), @cos(radians));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `radians == PI` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `radians == HALF_PI` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `radians == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and PI
        pub fn forms_corner_less_than_radians_using_lengths(self: T_Vec2, self_len: T, other: T_Vec2, other_len: T, radians: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, @cos(radians));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `max_cos == -1` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `max_cos == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `max_cos == 1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_less_than_cosine_of_angle_between(self: T_Vec2, other: T_Vec2, max_cos_of_angle_between: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), max_cos_of_angle_between);
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `max_cos == -1` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `max_cos == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `max_cos == 1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_less_than_cosine_of_angle_between_using_lengths(self: T_Vec2, self_len: T, other: T_Vec2, other_len: T, max_cos_of_angle_between: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, max_cos_of_angle_between);
            return self.dot(other) <= dot_threshold;
        }
    };
}
