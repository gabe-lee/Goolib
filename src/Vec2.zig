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
const math = std.math;
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const ShapeWinding = Root.CommonTypes.ShapeWinding;
const Assert = Root.Assert;
const MathX = Root.Math;
const SDL3 = Root.SDL3;
const Common = Root.CommonTypes;
const Types = Root.Types;
const AABB2 = Root.AABB2;
const Matrix = Root.Matrix;
const Vec3Module = Root.Vec3;
const Utils = Root.Utils;

const assert_is_float = Assert.assert_is_float;
const assert_with_reason = Assert.assert_with_reason;
const num_cast = Root.Cast.num_cast;
const real_cast = Root.Cast.real_cast;

pub const PerpendicularZero = Common.PerpendicularZero;
pub const NormalizeZero = Common.NormalizeZero;
pub const ShouldTranslate = Common.ShouldTranslate;

pub const Component = enum(u8) {
    X = 0,
    Y = 1,
};

pub fn define_vec2_type(comptime T: type) type {
    return extern struct {
        const Vec2 = @This();
        const AABB = AABB2.define_aabb2_type(T);
        const Vec3 = Vec3Module.define_vec3_type(T, 2);
        const IS_FLOAT = switch (T) {
            f16, f32, f64, f80, f128, c_longdouble => true,
            else => false,
        };
        const IS_INT = switch (T) {
            i8, i16, i32, i64, i128, isize, u8, u16, u32, u64, u128, usize, c_short, c_int, c_long, c_longlong, c_char, c_ushort, c_uint, c_ulong, c_ulonglong => true,
            else => false,
        };
        const IS_LARGE_INT = switch (T) {
            i64, i128, isize, u64, u128, usize, c_longlong, c_ulonglong => true,
            else => false,
        };
        pub const F = if (IS_FLOAT) T else if (IS_LARGE_INT) f64 else f32;

        x: T = 0,
        y: T = 0,

        pub const VEC: type = @Vector(LEN, T);
        pub const LEN = 2;
        pub const ZERO = Vec2{ .x = 0, .y = 0 };
        pub const ONE = Vec2{ .x = 1, .y = 1 };
        pub const MIN = Vec2{ .x = MIN_T, .y = MIN_T };
        pub const MAX = Vec2{ .x = MAX_T, .y = MAX_T };
        pub const FILLED_WITH_2 = Vec2{ .x = 2, .y = 2 };
        pub const MIN_T = if (IS_FLOAT) -math.inf(T) else math.minInt(T);
        pub const MAX_T = if (IS_FLOAT) math.inf(T) else math.maxInt(T);

        pub fn new(x: T, y: T) Vec2 {
            return Vec2{ .x = x, .y = y };
        }
        pub fn new_splat(val: T) Vec2 {
            return Vec2{ .x = val, .y = val };
        }
        pub fn new_any(x: anytype, y: anytype) Vec2 {
            return Vec2{ .x = num_cast(x, T), .y = num_cast(y, T) };
        }
        pub fn new_splat_any(val: anytype) Vec2 {
            return Vec2{ .vec = num_cast(val, T) };
        }

        pub fn flat(self: Vec2) VEC {
            return @bitCast(self);
        }

        pub fn change_component_type(self: Vec2, comptime NEW_T: type) define_vec2_type(NEW_T) {
            const V = define_vec2_type(NEW_T);
            return V{ .x = num_cast(self.x, NEW_T), .y = num_cast(self.y, NEW_T) };
        }

        pub fn upgrade_to_vec3_fill_1(self: Vec2) Vec3 {
            return Vec3{ .x = self.x, .y = self.y, .z = 1 };
        }
        pub fn upgrade_to_vec3_fill_0(self: Vec2) Vec3 {
            return Vec3{ .x = self.x, .y = self.y, .z = 0 };
        }

        pub fn swizzle(self: Vec2, new_x: Component, new_y: Component) Vec2 {
            const vec = self.flat();
            return Vec2{ .x = vec[@intFromEnum(new_x)], .y = vec[@intFromEnum(new_y)] };
        }
        // CHECKPOINT RE-refactor back to x,y,z,w components, but flatten internally for math where possible

        pub fn inverse(self: Vec2) Vec2 {
            return Vec2{ .vec = ONE.vec / self.vec };
        }

        pub fn ceil(self: Vec2) Vec2 {
            if (IS_INT) return self;
            return Vec2{ .vec = @ceil(self.vec) };
        }

        pub fn floor(self: Vec2) Vec2 {
            if (IS_INT) return self;
            return Vec2{ .vec = @floor(self.vec) };
        }

        pub fn round(self: Vec2) Vec2 {
            if (IS_INT) return self;
            return Vec2{ .vec = @round(self.vec) };
        }

        pub fn dot_product(self: Vec2, other: Vec2) T {
            const products = self.flat() * other.flat();
            return @reduce(.Add, products);
        }
        pub inline fn dot(self: Vec2, other: Vec2) T {
            return self.dot_product(other);
        }
        pub inline fn dot_product_self(self: Vec2) T {
            return self.dot_product(self);
        }
        pub inline fn dot_self(self: Vec2) T {
            return self.dot_product_self();
        }

        pub fn cross_product(self: Vec2, other: Vec2) T {
            return (self.vec[0] * other.vec[1]) - (self.vec[1] * other.vec[0]);
        }
        pub inline fn cross(self: Vec2, other: Vec2) T {
            return self.cross_product(other);
        }

        pub inline fn shoelace_area_step(self: Vec2, next: Vec2) T {
            return (next.vec[0] - self.vec[0]) * (self.vec[1] + next.vec[1]);
        }

        pub fn add(self: Vec2, other: Vec2) Vec2 {
            return Vec2{ .vec = self.vec + other.vec };
        }

        pub fn subtract(self: Vec2, other: Vec2) Vec2 {
            return Vec2{ .vec = self.vec - other.vec };
        }

        pub fn multiply(self: Vec2, other: Vec2) Vec2 {
            return Vec2{ .vec = self.vec * other.vec };
        }

        pub fn divide(self: Vec2, other: Vec2) Vec2 {
            assert_with_reason(!@reduce(.Or, other.vec == ZERO.vec), @src(), "cannot divide two vectors when one of the components of the divisor vector is 0, got divisor = {any}", .{other.vec});
            return Vec2{ .vec = self.vec / other.vec };
        }

        pub fn scale(self: Vec2, val: anytype) Vec2 {
            const v = real_cast(val);
            const val_vec: @Vector(3, @TypeOf(v)) = @splat(val);
            return Vec2{ .vec = MathX.upgrade_multiply_out(self.vec, val_vec, VEC) };
        }
        pub fn inverse_scale(self: Vec2, val: anytype) Vec2 {
            if (@TypeOf(val) == bool) {
                assert_with_reason(val != false, @src(), "cannot `inverse_scale()` when the scale value is `false`, (divide by zero)", .{});
            } else {
                assert_with_reason(val != 0, @src(), "cannot `inverse_scale()` when the scale value is 0, (divide by zero)", .{});
            }
            const val_vec: @Vector(3, @TypeOf(val)) = @splat(val);
            return Vec2{ .vec = MathX.upgrade_divide_out(self.vec, val_vec, VEC) };
        }

        pub fn add_scale(self: Vec2, add_vec: Vec2, scale_add_vec_by: anytype) Vec2 {
            return self.add(add_vec.scale(scale_add_vec_by));
        }

        pub fn subtract_scale(self: Vec2, subtract_vec: Vec2, scale_subtract_vec_by: anytype) Vec2 {
            return self.add(subtract_vec.scale(scale_subtract_vec_by));
        }

        pub fn squared(self: Vec2) Vec2 {
            return Vec2{ .vec = self.vec * self.vec };
        }

        pub fn component_sum(self: Vec2) T {
            return @reduce(.Add, self.vec);
        }

        pub fn distance_to(self: Vec2, other: Vec2) T {
            const sum_squares = self.distance_to_squared(other);
            return num_cast(@sqrt(MathX.upgrade_to_float(sum_squares, F)), T);
        }

        pub fn distance_to_squared(self: Vec2, other: Vec2) T {
            const delta = other.subtract(self);
            const square = delta.squared();
            return square.component_sum();
        }

        pub fn length(self: Vec2) T {
            const squared_sum = self.length_squared();
            return num_cast(@sqrt(MathX.upgrade_to_float(squared_sum, F)), T);
        }

        pub fn length_squared(self: Vec2) T {
            const square = self.squared();
            return square.component_sum();
        }

        pub fn length_using_squares(self_squared: Vec2) T {
            assert_with_reason(@reduce(.And, self_squared.vec >= ZERO.vec), @src(), "all components of `self_squared` must be positive or zero, got {any}", .{self_squared.vec});
            const sum = self_squared.component_sum();
            return num_cast(@sqrt(MathX.upgrade_to_float(sum, F)), T);
        }

        pub fn normalize(self: Vec2) Vec2 {
            assert_with_reason(@reduce(.Or, self.vec != ZERO.vec), @src(), "at least one component of `self` must be nonzero, otherwise a it will cause a divide by zero", .{});
            const len = self.length();
            return self.inverse_scale(len);
        }

        pub fn normalize_using_length(self: Vec2, len: anytype) Vec2 {
            assert_with_reason(len != 0, @src(), "`len` must be nonzero, otherwise a it will cause a divide by zero", .{});
            return self.inverse_scale(len);
        }

        pub fn normalize_using_squares(self: Vec2, self_squared: Vec2) Vec2 {
            assert_with_reason(@reduce(.And, self_squared.vec >= ZERO.vec), @src(), "all components of `self_squared` must be positive or zero, got {any}", .{self_squared.vec});
            const sum = self_squared.component_sum();
            const len = num_cast(@sqrt(MathX.upgrade_to_float(sum, F)), T);
            return self.inverse_scale(len);
        }

        pub fn normalize_may_be_zero(self: Vec2, comptime zero_behavior: NormalizeZero) Vec2 {
            if (@reduce(.Add, self.vec == ZERO.vec)) {
                @branchHint(.unlikely);
                var out = ZERO;
                if (zero_behavior == .NORM_ZERO_IS_LAST_COMPONENT_1) {
                    out.vec[LAST_COMPONENT_IDX] = 1;
                }
                return out;
            }
            return self.normalize();
        }
        pub fn normalize_may_be_zero_with_length(self: Vec2, len: anytype, comptime zero_behavior: NormalizeZero) Vec2 {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                var out = ZERO;
                if (zero_behavior == .NORM_ZERO_IS_LAST_COMPONENT_1) {
                    out.vec[LAST_COMPONENT_IDX] = 1;
                }
                return out;
            }
            return self.normalize_using_length(len);
        }

        pub fn orthoganal_normal_ccw(self: Vec2, comptime zero_behavior: PerpendicularZero) Vec2 {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                return .new(0, if (zero_behavior == .perp_zero_is_zero) 0 else 1);
            }
            const len = self.length();
            return self.normalize_using_length(len).perp_ccw();
        }
        pub fn orthoganal_normal_cw(self: Vec2, comptime zero_behavior: PerpendicularZero) Vec2 {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                return .new(0, if (zero_behavior == .perp_zero_is_zero) 0 else -1);
            }
            const len = self.length();
            return self.normalize_using_length(len).perp_cw();
        }

        pub fn angle_between(self: Vec2, other: Vec2, comptime OUT: type) OUT {
            const dot_prod = self.dot_product(other);
            const self_length_squared = self.length_squared();
            const self_length_squared_float = MathX.upgrade_to_float(self_length_squared, F);
            const other_length_squared = self.length_squared();
            const other_length_squared_float = MathX.upgrade_to_float(other_length_squared, F);
            const lengths_multiplied = @sqrt(self_length_squared_float) * @sqrt(other_length_squared_float);
            return num_cast(math.acos(MathX.upgrade_to_float(dot_prod, F) / lengths_multiplied), OUT);
        }

        pub fn angle_between_using_lengths(self: Vec2, other: Vec2, len_self: anytype, len_other: anytype, comptime OUT: type) OUT {
            const dot_prod = self.dot_product(other);
            const self_length_float = MathX.upgrade_to_float(len_self, F);
            const other_length_float = MathX.upgrade_to_float(len_other, F);
            const lengths_multiplied = MathX.upgrade_multiply(self_length_float, other_length_float);
            return num_cast(math.acos(MathX.upgrade_divide(MathX.upgrade_to_float(dot_prod, F), lengths_multiplied)), OUT);
        }

        pub fn angle_between_using_norms(self_norm: Vec2, other_norm: Vec2, comptime OUT: type) OUT {
            const dot_prod = self_norm.dot_product(other_norm);
            return num_cast(math.acos(MathX.upgrade_to_float(dot_prod, F)), OUT);
        }

        /// Assuming `a` and `b` are vectors from the origin
        /// AND are colinear, return the ratio of the length
        /// of `a` compared to the legnth of `b`
        ///
        /// this equals `a.x / b.x` or `a.y / b.y`
        pub fn colinear_ratio_a_of_b(a: Vec2, b: Vec2) T {
            inline for (0..2) |i| {
                if (b.vec[i] != 0) return a.vec[i] / b.vec[i];
            }
            return 0;
        }

        pub fn perp_ccw(self: Vec2) Vec2 {
            return Vec2{ .vec = .{ -self.vec[1], self.vec[0] } };
        }
        pub fn perp_left(self: Vec2) Vec2 {
            return self.perp_ccw();
        }

        pub fn perp_cw(self: Vec2) Vec2 {
            return Vec2{ .vec = .{ self.vec[1], -self.vec[0] } };
        }
        pub fn perp_right(self: Vec2) Vec2 {
            return self.perp_cw();
        }

        fn lerp_internal(p1: Vec2, p2: Vec2, percent: anytype) Vec2 {
            const delta = if (Types.type_is_vector(@TypeOf(percent))) get: {
                const CHILD = @typeInfo(@TypeOf(percent)).vector.child;
                assert_is_float(CHILD, @src());
                break :get percent;
            } else get: {
                assert_is_float(@TypeOf(percent), @src());
                const per = real_cast(percent);
                break :get @as(@Vector(LEN, @TypeOf(per)), @splat(per));
            };
            const nums = MathX.upgrade_3_numbers_for_math(p1.vec, p2.vec, delta);
            const TU = @FieldType(@TypeOf(nums), "a");
            const result = @mulAdd(TU, nums.c, nums.b, @mulAdd(TU, -nums.c, nums.a, nums.a));
            return Vec2{ .vec = num_cast(result, VEC) };
        }

        pub fn lerp(p1: Vec2, p2: Vec2, percent: anytype) Vec2 {
            return lerp_internal(p1, p2, percent);
        }
        pub inline fn linear_interp(p1: Vec2, p2: Vec2, percent: anytype) Vec2 {
            return lerp_internal(p1, p2, percent);
        }
        pub fn quadratic_interp(p1: Vec2, p2: Vec2, p3: Vec2, percent: anytype) Vec2 {
            const p12 = lerp_internal(p1, p2, percent);
            const p23 = lerp_internal(p2, p3, percent);
            return lerp_internal(p12, p23, percent);
        }
        pub fn cubic_interp(p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2, percent: anytype) Vec2 {
            const p12 = lerp_internal(p1, p2, percent);
            const p23 = lerp_internal(p2, p3, percent);
            const p34 = lerp_internal(p3, p4, percent);
            const p12_23 = lerp_internal(p12, p23, percent);
            const p23_34 = lerp_internal(p23, p34, percent);
            return lerp_internal(p12_23, p23_34, percent);
        }
        pub fn n_bezier_interp(comptime NN: comptime_int, p: [NN]Vec2, percent: anytype) Vec2 {
            var tmp: [2][NN]Vec2 = .{ p, @splat(Vec2{}) };
            var curr: usize = 0;
            var next: usize = 1;
            var curr_points: usize = NN;
            var i: usize = undefined;
            var j: usize = undefined;
            while (curr_points > 1) {
                i = 0;
                j = 1;
                while (j < curr_points) {
                    tmp[next][i] = lerp_internal(tmp[curr][i], tmp[curr][j], percent);
                    i = j;
                    j += 1;
                }
                curr_points -= 1;
                curr = curr ^ 1;
                next = next ^ 1;
            }
            return tmp[curr][0];
        }

        pub fn lerp_delta_range(self: Vec2, other: Vec2, min_delta: anytype, max_delta: anytype, range_delta: anytype) Vec2 {
            const range = MathX.upgrade_subtract(max_delta, min_delta);
            const range_percent = MathX.upgrade_multiply(range, range_delta);
            const percent = MathX.upgrade_add(min_delta, range_percent);
            return lerp_internal(self, other, percent);
        }

        pub fn lerp_delta_delta(self: Vec2, other: Vec2, delta: anytype, delta_delta: anytype) Vec2 {
            const percent = MathX.upgrade_multiply(delta, delta_delta);
            return lerp_internal(self, other, percent);
        }

        pub fn rotate_radians(self: Vec2, radians: anytype) Vec2 {
            const cos = @cos(radians);
            const sin = @sin(radians);
            return self.rotate_sin_cos(sin, cos);
        }

        pub fn rotate_degrees(self: Vec2, degrees: T) Vec2 {
            const rads = degrees * math.rad_per_deg;
            const cos = @cos(rads);
            const sin = @sin(rads);
            return self.rotate_sin_cos(sin, cos);
        }

        pub fn rotate_sin_cos(self: Vec2, sin: T, cos: T) Vec2 {
            return Vec2{ .vec = .{ MathX.upgrade_multiply_out(self.vec[0], cos, T) - MathX.upgrade_multiply_out(self.vec[1], sin, T), MathX.upgrade_multiply_out(self.vec[0], sin, T) + MathX.upgrade_multiply_out(self.vec[1], cos, T) } };
        }

        pub fn negate(self: Vec2) Vec2 {
            return Vec2{ .vec = -self.vec };
        }

        pub fn equals(self: Vec2, other: Vec2) bool {
            return @reduce(.And, self.vec == other.vec);
        }

        pub fn approx_equal(self: Vec2, other: Vec2) bool {
            return MathX.approx_equal_vec(VEC, self.vec, other.vec);
        }
        pub fn approx_equal_with_epsilon(self: Vec2, other: Vec2, epsilon: Vec2) bool {
            return MathX.approx_equal_with_epsilon_vec(VEC, self.vec, other.vec, epsilon);
        }

        pub fn is_zero(self: Vec2) bool {
            return @reduce(.And, self.vec == ZERO.vec);
        }
        pub fn non_zero(self: Vec2) bool {
            return !@reduce(.And, self.vec == ZERO.vec);
        }
        pub fn reflect(self: Vec2, reflect_normal: Vec2) Vec2 {
            const fix_scale = 2 * ((self.vec[0] * reflect_normal.vec[0]) + (self.vec[1] * reflect_normal.vec[1]));
            return Vec2{ .vec = .{ self.vec[0] - (reflect_normal.vec[0] * fix_scale), self.vec[1] - (reflect_normal.vec[1] * fix_scale) } };
        }

        pub fn slope(self: Vec2) T {
            return self.vec[1] / self.vec[0];
        }

        fn cross_3(self: Vec2, other_a: Vec2, other_b: Vec2) T {
            return ((other_b.vec[1] - self.vec[1]) * (other_a.vec[0] - self.vec[0])) - ((other_b.vec[0] - self.vec[0]) * (other_a.vec[1] - self.vec[1]));
        }

        pub fn approx_colinear(self: Vec2, other_a: Vec2, other_b: Vec2) bool {
            if (IS_INT) return self.colinear(other_a, other_b);
            const _cross_3 = self.cross_3(other_a, other_b);
            return @abs(_cross_3) <= math.floatEps(T);
        }

        pub fn colinear(self: Vec2, other_a: Vec2, other_b: Vec2) bool {
            const _cross_3 = self.cross_3(other_a, other_b);
            return _cross_3 == 0;
        }

        pub fn approx_orientation(a: Vec2, b: Vec2, c: Vec2) ShapeWinding {
            const _cross_3 = a.cross_3(b, c);
            if (@abs(_cross_3) <= math.floatEpsAt(f32, _cross_3)) return ShapeWinding.COLINEAR;
            if (_cross_3 > 0) return ShapeWinding.WINDING_CW;
            return ShapeWinding.WINDING_CCW;
        }

        pub fn orientation(a: Vec2, b: Vec2, c: Vec2) ShapeWinding {
            const _cross_3 = a.cross_3(b, c);
            if (_cross_3 == 0) return ShapeWinding.COLINEAR;
            if (_cross_3 > 0) return ShapeWinding.WINDING_CW;
            return ShapeWinding.WINDING_CCW;
        }

        pub fn approx_on_segment(self: Vec2, line_a: Vec2, line_b: Vec2) bool {
            if (self.approx_orientation(line_a, line_b) != ShapeWinding.COLINEAR) return false;
            const line_aabb = AABB.from_static_line(line_a, line_b);
            return line_aabb.point_approx_within(self);
        }

        pub fn on_segment(self: Vec2, line_a: Vec2, line_b: Vec2) bool {
            if (self.orientation(line_a, line_b) != ShapeWinding.COLINEAR) return false;
            const line_aabb = AABB.from_static_line(line_a, line_b);
            return line_aabb.point_within(self);
        }

        pub fn rate_required_to_reach_point_at_time(self: Vec2, point: Vec2, time: anytype) Vec2 {
            return point.subtract(self).scale(1 / time);
        }

        pub fn rate_required_to_reach_point_inverse_time(self: Vec2, point: Vec2, inverse_time: anytype) Vec2 {
            return point.subtract(self).scale(inverse_time);
        }

        pub fn forms_corner_simple(self: Vec2, other: Vec2) bool {
            return self.dot(other) <= 0;
        }

        /// Where:
        ///   - `ratio == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `ratio == 1` means the vectors always form a corner even if they are pointing in the exact same direction
        ///   - `ratio == -1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_flatness_ratio(self: Vec2, other: Vec2, ratio: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), @cos(MathX.HALF_PI - (MathX.upgrade_to_float(ratio, f32) * MathX.HALF_PI)));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `ratio == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `ratio == 1` means the vectors always form a corner even if they are pointing in the exact same direction
        ///   - `ratio == -1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_flatness_ratio_using_lengths(self: Vec2, self_len: T, other: Vec2, other_len: T, ratio: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, @cos(MathX.HALF_PI - (MathX.upgrade_to_float(ratio, f32) * MathX.HALF_PI)));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `threshold == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `threshold > 0` means the vectors form a corner if they are perpendicular, point in generally opposite directions, or point in somewhat the same direction but not enough to cross above the threshold (higher numbers allow 'flatter' corners to pass)
        ///   - `threshold < 0` means the vectors only form a corner if they are pointing in opposite directions enough to remain below the threshold (lower numbers require 'sharper' corners to pass)
        pub fn forms_corner_dot_product_threshold(self: Vec2, other: Vec2, threshold: anytype) bool {
            return self.dot(other) <= threshold;
        }
        /// Where:
        ///   - `@abs(threshold) == 0` means the vectors only DONT form a corner if they point in EXACTLY the same direction
        ///   - `@abs(threshold) > 0` means the vectors only form a corner if they are perpendicular, point in generally opposite directions, or point in somewhat the same dirction but not enough to fall below the threshold (smaller numbers allow 'flatter' corners to pass)
        pub fn forms_corner_dot_or_cross_product_threshold(self: Vec2, other: Vec2, threshold: anytype) bool {
            return self.dot(other) <= threshold or @abs(self.cross(other)) > threshold;
        }
        /// Where:
        ///   - `degrees == 180` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `degrees == 90` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `degrees == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and 180
        pub fn forms_corner_less_than_degrees(self: Vec2, other: Vec2, degrees: anytype) bool {
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
        pub fn forms_corner_less_than_degrees_using_lengths(self: Vec2, self_len: T, other: Vec2, other_len: T, degrees: anytype) bool {
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
        pub fn forms_corner_less_than_radians(self: Vec2, other: Vec2, radians: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), @cos(radians));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `radians == PI` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `radians == HALF_PI` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `radians == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and PI
        pub fn forms_corner_less_than_radians_using_lengths(self: Vec2, self_len: T, other: Vec2, other_len: T, radians: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, @cos(radians));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `max_cos == -1` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `max_cos == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `max_cos == 1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_less_than_cosine_of_angle_between(self: Vec2, other: Vec2, max_cos_of_angle_between: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), max_cos_of_angle_between);
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `max_cos == -1` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `max_cos == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `max_cos == 1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_less_than_cosine_of_angle_between_using_lengths(self: Vec2, self_len: T, other: Vec2, other_len: T, max_cos_of_angle_between: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, max_cos_of_angle_between);
            return self.dot(other) <= dot_threshold;
        }

        pub const MiterNormsAndOffset = struct {
            corner_to_prev_norm: Vec2 = .ZERO_ZERO,
            corner_to_next_norm: Vec2 = .ZERO_ZERO,
            inner_miter_offset_norm: Vec2 = .ZERO_ZERO,
        };

        pub const MiterResult = struct {
            corner_to_prev_norm: Vec2 = .ZERO_ZERO,
            corner_to_next_norm: Vec2 = .ZERO_ZERO,
            inner_miter_offset_norm: Vec2 = .ZERO_ZERO,
            inner_offset: Vec2 = .ZERO_ZERO,
            inner_point: Vec2 = .ZERO_ZERO,
            outer_point: Vec2 = .ZERO_ZERO,
            infinite: bool = false,

            pub fn new_infinite(norms: MiterNormsAndOffset) MiterResult {
                return MiterResult{
                    .corner_to_next_norm = norms.corner_to_next_norm,
                    .corner_to_prev_norm = norms.corner_to_prev_norm,
                    .inner_miter_offset_norm = norms.inner_miter_offset_norm,
                    .infinite = true,
                };
            }
            pub fn new_infinite_seg_norms_only(corner_to_prev_norm: Vec2, corner_to_next_norm: Vec2) MiterResult {
                return MiterResult{
                    .corner_to_next_norm = corner_to_next_norm,
                    .corner_to_prev_norm = corner_to_prev_norm,
                    .inner_miter_offset_norm = corner_to_next_norm,
                    .infinite = true,
                };
            }
        };

        pub fn miter_points_same_line_width(corner: Vec2, prev_point: Vec2, next_point: Vec2, width: anytype) MiterResult {
            const norms = corner.inner_miter_offset_normal_same_line_width(prev_point, next_point);
            return corner.miter_points_same_line_width_using_norms(norms, width);
        }
        pub fn miter_points_same_line_width_using_norms(corner: Vec2, norms: MiterNormsAndOffset, width: anytype) MiterResult {
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
        pub fn miter_outer_points_same_line_width(corner: Vec2, prev_point: Vec2, next_point: Vec2, width: anytype) MiterResult {
            const norms = corner.inner_miter_offset_normal_same_line_width(prev_point, next_point);
            return corner.miter_outer_point_same_line_width_using_norms(norms, width);
        }
        pub fn miter_outer_point_same_line_width_using_norms(corner: Vec2, norms: MiterNormsAndOffset, width: anytype) MiterResult {
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
        pub fn inner_miter_offset_normal_same_line_width(corner: Vec2, prev_point: Vec2, next_point: Vec2) MiterNormsAndOffset {
            const delta_prev_norm = prev_point.subtract(corner).normalize_may_be_zero(.norm_zero_is_zero);
            const delta_next_norm = next_point.subtract(corner).normalize_may_be_zero(.norm_zero_is_zero);
            const miter_offset_norm_inner = delta_prev_norm.lerp(delta_next_norm, 0.5).normalize_may_be_zero(.norm_zero_is_zero);
            return MiterNormsAndOffset{
                .corner_to_prev_norm = delta_prev_norm,
                .corner_to_next_norm = delta_next_norm,
                .inner_miter_offset_norm = miter_offset_norm_inner,
            };
        }
        pub fn miter_different_widths_no_inner_normal(corner: Vec2, prev_point: Vec2, prev_segment_width: anytype, next_point: Vec2, next_segment_width: anytype) MiterResult {
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
        pub fn miter_different_widths_with_inner_normal(corner: Vec2, prev_point: Vec2, prev_segment_width: anytype, next_point: Vec2, next_segment_width: anytype) MiterResult {
            var result = corner.miter_different_widths_no_inner_normal(prev_point, prev_segment_width, next_point, next_segment_width);
            result.inner_miter_offset_norm = result.inner_offset.normalize_may_be_zero(.norm_zero_is_zero);
        }

        pub fn apply_transform(self: Vec2, transform: TransformStep) Vec2 {
            return self.apply_transform_advanced(transform, .PREFORM_TRANSLATIONS);
        }
        pub fn apply_transform_ignore_translate(self: Vec2, transform: TransformStep) Vec2 {
            return self.apply_transform_advanced(transform, .IGNORE_TRANSLATIONS);
        }
        fn apply_transform_advanced(self: Vec2, transform: TransformStep, should_translate: ShouldTranslate) Vec2 {
            return switch (transform) {
                .TRANSLATE => |vec| if (should_translate == .PREFORM_TRANSLATIONS) self.add(vec) else self,
                .TRANSLATE_X => |x| if (should_translate == .PREFORM_TRANSLATIONS) Vec2{ .vec = .{ self.get_x() + x, self.get_y() } } else self,
                .TRANSLATE_Y => |y| if (should_translate == .PREFORM_TRANSLATIONS) Vec2{ .vec = .{ self.get_x(), self.get_y() + y } } else self,
                .SCALE => |vec| self.multiply(vec),
                .SCALE_X => |x| Vec2{ .vec = .{ self.get_x() * x, self.get_y() } },
                .SCALE_Y => |y| Vec2{ .vec = .{ self.get_x(), self.get_y() * y } },
                .SKEW_X => |ratio| Vec2{ .vec = .{ self.get_x() + (ratio * self.get_y()), self.get_y() } },
                .SKEW_Y => |ratio| Vec2{ .vec = .{ self.get_x(), self.get_y() + (ratio * self.get_x()) } },
                .ROTATE => |sincos| self.rotate_sin_cos(sincos.sin, sincos.cos),
            };
        }
        pub fn apply_inverse_transform(self: Vec2, transform: TransformStep) Vec2 {
            return self.apply_inverse_transform_advanced(transform, .PREFORM_TRANSLATIONS);
        }
        pub fn apply_inverse_transform_ignore_translate(self: Vec2, transform: TransformStep) Vec2 {
            return self.apply_inverse_transform_advanced(transform, .IGNORE_TRANSLATIONS);
        }
        fn apply_inverse_transform_advanced(self: Vec2, transform: TransformStep, should_translate: ShouldTranslate) Vec2 {
            return switch (transform) {
                .TRANSLATE => |vec| if (should_translate == .PREFORM_TRANSLATIONS) self.add(vec) else self,
                .TRANSLATE_X => |x| if (should_translate == .PREFORM_TRANSLATIONS) Vec2{ .vec = .{ self.get_x() - x, self.get_y() } } else self,
                .TRANSLATE_Y => |y| if (should_translate == .PREFORM_TRANSLATIONS) Vec2{ .vec = .{ self.get_x(), self.get_y() - y } } else self,
                .SCALE => |vec| self.multiply(vec),
                .SCALE_X => |x| Vec2{ .vec = .{ self.get_x() / x, self.get_y() } },
                .SCALE_Y => |y| Vec2{ .vec = .{ self.get_x(), self.get_y() / y } },
                .SKEW_X => |ratio| Vec2{ .vec = .{ self.get_x() + (-ratio * self.get_y()), self.get_y() } },
                .SKEW_Y => |ratio| Vec2{ .vec = .{ self.get_x(), self.get_y() + (-ratio * self.get_x()) } },
                .ROTATE => |sincos| self.rotate_sin_cos(-sincos.sin, sincos.cos),
            };
        }

        fn apply_complex_transform(self: Vec2, steps: []const TransformStep) Vec2 {
            return self.apply_complex_transform_advanced(steps, .PREFORM_TRANSLATIONS);
        }
        fn apply_complex_transform_ignore_translate(self: Vec2, steps: []const TransformStep) Vec2 {
            return self.apply_complex_transform_advanced(steps, .IGNORE_TRANSLATIONS);
        }
        fn apply_complex_transform_advanced(self: Vec2, steps: []const TransformStep, should_translate: ShouldTranslate) Vec2 {
            var out = self;
            for (0..steps.len) |i| {
                out = out.apply_transform_advanced(steps[i], should_translate);
            }
            return out;
        }
        fn apply_inverse_complex_transform(self: Vec2, steps: []const TransformStep) Vec2 {
            return self.apply_inverse_complex_transform_advanced(steps, .PREFORM_TRANSLATIONS);
        }
        fn apply_inverse_complex_transform_ignore_translate(self: Vec2, steps: []const TransformStep) Vec2 {
            return self.apply_inverse_complex_transform_advanced(steps, .IGNORE_TRANSLATIONS);
        }
        fn apply_inverse_complex_transform_advanced(self: Vec2, steps: []const TransformStep, should_translate: ShouldTranslate) Vec2 {
            var out = self;
            const LAST_STEP = steps.len - 1;
            for (0..steps.len) |i| {
                const ii = LAST_STEP - i;
                out = out.apply_inverse_transform_advanced(steps[ii], should_translate);
            }
            return out;
        }

        pub fn complex_transform_to_affine_matrix(steps: []const TransformStep) Matrix.define_square_NxN_matrix_type(T, 3, .ROW_MAJOR, 0) {
            return complex_transform_to_affine_matrix_advanced(steps, .PREFORM_TRANSLATIONS, T, .ROW_MAJOR, 0);
        }
        pub fn complex_transform_to_affine_matrix_ignore_translations(steps: []const TransformStep) Matrix.define_square_NxN_matrix_type(T, 3, .ROW_MAJOR, 0) {
            return complex_transform_to_affine_matrix_advanced(steps, .IGNORE_TRANSLATIONS, T, .ROW_MAJOR, 0);
        }

        pub fn complex_transform_to_affine_matrix_advanced(steps: []const TransformStep, should_translate: ShouldTranslate, comptime MAT_T: type, comptime MAT_ORDER: Matrix.RowColumnOrder, comptime MAJOR_PAD: comptime_int) Matrix.define_square_NxN_matrix_type(MAT_T, 3, MAT_ORDER, MAJOR_PAD) {
            const MAT = Matrix.define_square_NxN_matrix_type(MAT_T, 3, MAT_ORDER, MAJOR_PAD);
            const LAST_STEP: usize = steps.len - 1;
            var matrix = MAT.IDENTITY;
            for (0..steps.len) |i| {
                const ii = LAST_STEP - i;
                if (should_translate == .IGNORE_TRANSLATIONS and steps[ii].is_translate()) continue;
                matrix = matrix.multiply(steps[ii].to_affine_matrix_advanced(MAT_T, MAT_ORDER, MAJOR_PAD));
            }
            return matrix;
        }

        pub fn complex_transform_to_inverse_affine_matrix(steps: []const TransformStep) Matrix.define_square_NxN_matrix_type(T, 3, .ROW_MAJOR, 0) {
            return complex_transform_to_inverse_affine_matrix_advanced(steps, .PREFORM_TRANSLATIONS, T, .ROW_MAJOR, 0);
        }
        pub fn complex_transform_to_inverse_affine_matrix_ignore_translations(steps: []const TransformStep) Matrix.define_square_NxN_matrix_type(T, 3, .ROW_MAJOR, 0) {
            return complex_transform_to_inverse_affine_matrix_advanced(steps, .IGNORE_TRANSLATIONS, T, .ROW_MAJOR, 0);
        }

        pub fn complex_transform_to_inverse_affine_matrix_advanced(steps: []const TransformStep, should_translate: ShouldTranslate, comptime MAT_T: type, comptime MAT_ORDER: Matrix.RowColumnOrder, comptime MAJOR_PAD: comptime_int) Matrix.define_square_NxN_matrix_type(MAT_T, 3, MAT_ORDER, MAJOR_PAD) {
            const MAT = Matrix.define_square_NxN_matrix_type(MAT_T, 3, MAT_ORDER, MAJOR_PAD);
            var matrix = MAT.IDENTITY;
            for (0..steps.len) |i| {
                if (should_translate == .IGNORE_TRANSLATIONS and steps[i].is_translate()) continue;
                matrix = matrix.multiply(steps[i].to_affine_matrix_advanced(MAT_T, MAT_ORDER, MAJOR_PAD));
            }
            return matrix;
        }

        pub fn as_3x1_matrix_column_fill_1(self: Vec2) Matrix.define_rectangular_RxC_matrix_type(T, 3, 1, .COLUMN_MAJOR, 0) {
            const raw: [3]T = .{ self.vec[0], self.vec[1], 1 };
            return @bitCast(raw);
        }
        pub fn as_1x3_matrix_row_fill_1(self: Vec2) Matrix.define_rectangular_RxC_matrix_type(T, 1, 3, .ROW_MAJOR, 0) {
            const raw: [3]T = .{ self.vec[0], self.vec[1], 1 };
            return @bitCast(raw);
        }
        pub fn as_3x1_matrix_column_fill_0(self: Vec2) Matrix.define_rectangular_RxC_matrix_type(T, 3, 1, .COLUMN_MAJOR, 0) {
            const raw: [3]T = .{ self.vec[0], self.vec[1], 0 };
            return @bitCast(raw);
        }
        pub fn as_1x3_matrix_row_fill_0(self: Vec2) Matrix.define_rectangular_RxC_matrix_type(T, 1, 3, .ROW_MAJOR, 0) {
            const raw: [3]T = .{ self.vec[0], self.vec[1], 0 };
            return @bitCast(raw);
        }

        pub fn apply_affine_matrix_transform(self: Vec2, matrix: anytype) Vec2 {
            return self.apply_affine_matrix_transform_advanced(matrix, .PREFORM_TRANSLATIONS);
        }
        pub fn apply_affine_matrix_transform_ignore_translations(self: Vec2, matrix: anytype) Vec2 {
            return self.apply_affine_matrix_transform_advanced(matrix, .IGNORE_TRANSLATIONS);
        }

        fn apply_affine_matrix_transform_advanced(self: Vec2, matrix: anytype, should_translate: ShouldTranslate) Vec2 {
            const SEFL_DEF = Matrix.define_rectangular_RxC_matrix_type(T, 3, 1, .COLUMN_MAJOR, 0).DEF;
            const self_as_mat = if (should_translate == .PREFORM_TRANSLATIONS) self.as_3x1_matrix_column_fill_1() else self.as_3x1_matrix_column_fill_0();
            const DEF = Matrix.assert_anytype_is_matrix_and_get_def(matrix, @src());
            assert_with_reason(DEF.COLS == 3 and DEF.ROWS == 3, @src(), "affine matrix to apply MUST be a 3x3 matrix, got {d}x{d}", .{ DEF.ROWS, DEF.COLS });
            const result = Matrix.Advanced.multiply_matrices(DEF, matrix, SEFL_DEF, self_as_mat, T, .COLUMN_MAJOR, 0);
            return Vec2{ .vec = .{ result[0][0], result[0][1], result[0][2] } };
        }

        pub const TransformStep = union(TransformKind) {
            TRANSLATE: Vec2,
            TRANSLATE_X: T,
            TRANSLATE_Y: T,
            SCALE: Vec2,
            SCALE_X: T,
            SCALE_Y: T,
            SKEW_X: T,
            SKEW_Y: T,
            ROTATE: struct {
                sin: F,
                cos: F,
            },

            pub fn translate(vec: Vec2) TransformStep {
                return TransformStep{ .TRANSLATE = vec };
            }
            pub fn translate_x(x: T) TransformStep {
                return TransformStep{ .TRANSLATE_X = x };
            }
            pub fn translate_y(y: T) TransformStep {
                return TransformStep{ .TRANSLATE_Y = y };
            }
            pub fn scale(vec: Vec2) TransformStep {
                return TransformStep{ .SCALE = vec };
            }
            pub fn scale_x(x: T) TransformStep {
                return TransformStep{ .SCALE_X = x };
            }
            pub fn scale_y(y: T) TransformStep {
                return TransformStep{ .SCALE_Y = y };
            }
            pub fn skew_x_ratio(x_ratio_or_tangent_of_angle_from_y_axis: T) TransformStep {
                return TransformStep{ .SKEW_X = x_ratio_or_tangent_of_angle_from_y_axis };
            }
            pub fn skew_y_ratio(y_ratio_or_tangent_of_angle_from_x_axis: T) TransformStep {
                return TransformStep{ .SKEW_Y = y_ratio_or_tangent_of_angle_from_x_axis };
            }
            pub fn skew_x_radians(radians_from_y_axis: T) TransformStep {
                return TransformStep{ .SKEW_X = @tan(radians_from_y_axis) };
            }
            pub fn skew_y_radians(radians_from_x_axis: T) TransformStep {
                return TransformStep{ .SKEW_Y = @tan(radians_from_x_axis) };
            }
            pub fn skew_x_degrees(degrees_from_y_axis: T) TransformStep {
                return TransformStep{ .SKEW_X = @tan(degrees_from_y_axis * MathX.DEG_TO_RAD) };
            }
            pub fn skew_y_degrees(degrees_from_x_axis: T) TransformStep {
                return TransformStep{ .SKEW_Y = @tan(degrees_from_x_axis * MathX.DEG_TO_RAD) };
            }
            pub fn rotate_radians(radians: F) TransformStep {
                return TransformStep{ .ROTATE = .{ .sin = @sin(radians), .cos = @cos(radians) } };
            }
            pub fn rotate_degrees(degrees: F) TransformStep {
                return TransformStep{ .ROTATE = .{ .sin = @sin(degrees * MathX.DEG_TO_RAD), .cos = @cos(degrees * MathX.DEG_TO_RAD) } };
            }
            pub fn rotate_sin_cos(sin: F, cos: F) TransformStep {
                return TransformStep{ .ROTATE = .{ .sin = sin, .cos = cos } };
            }
            pub fn relect_across_origin() TransformStep {
                return TransformStep{ .SCALE = .new(-1, -1) };
            }
            pub fn relect_across_y_axis() TransformStep {
                return TransformStep{ .SCALE_X = -1 };
            }
            pub fn relect_across_x_axis() TransformStep {
                return TransformStep{ .SCALE_Y = -1 };
            }

            pub fn to_affine_matrix(self: TransformStep) Matrix.define_square_NxN_matrix_type(T, 3, .ROW_MAJOR, 0) {
                return self.to_affine_matrix_advanced(T, .PREFORM_TRANSLATIONS, .ROW_MAJOR, 0);
            }
            pub fn to_affine_matrix_ignore_translations(self: TransformStep) Matrix.define_square_NxN_matrix_type(T, 3, .ROW_MAJOR, 0) {
                return self.to_affine_matrix_advanced(T, .IGNORE_TRANSLATIONS, .ROW_MAJOR, 0);
            }

            pub fn to_affine_matrix_advanced(self: TransformStep, comptime MAT_T: type, should_translate: ShouldTranslate, comptime MAT_ORDER: Matrix.RowColumnOrder, comptime MAJOR_PAD: comptime_int) Matrix.define_square_NxN_matrix_type(MAT_T, 3, MAT_ORDER, MAJOR_PAD) {
                const MAT = Matrix.define_square_NxN_matrix_type(MAT_T, 3, MAT_ORDER, MAJOR_PAD);
                const DEF = MAT.DEF;
                var m = MAT.IDENTITY;
                switch (self) {
                    // TRANSLATIONS
                    //
                    // 1 0 x
                    // 0 1 y
                    // 0 0 1
                    .TRANSLATE => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 2, num_cast(v.get_x(), MAT_T));
                            DEF.set_cell(&m.mat, 1, 2, num_cast(v.get_y(), MAT_T));
                        }
                    },
                    .TRANSLATE_X => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 2, num_cast(v, MAT_T));
                        }
                    },
                    .TRANSLATE_Y => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 1, 2, num_cast(v, MAT_T));
                        }
                    },
                    // SCALES
                    //
                    // x 0 0
                    // 0 y 0
                    // 0 0 1
                    .SCALE => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v.get_x(), MAT_T));
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v.get_y(), MAT_T));
                    },
                    .SCALE_X => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v, MAT_T));
                    },
                    .SCALE_Y => |v| {
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v, MAT_T));
                    },
                    // SHEARS
                    // X away Y  Y away X
                    //
                    //  1 * 0     1 0 0
                    //  0 1 0     * 1 0
                    //  0 0 1     0 0 1
                    .SKEW_X => |v| {
                        DEF.set_cell(&m.mat, 0, 1, num_cast(v, MAT_T));
                    },
                    .SKEW_Y => |v| {
                        DEF.set_cell(&m.mat, 1, 0, num_cast(v, MAT_T));
                    },
                    // ROTATION
                    //
                    //  C -S  0
                    //  S  C  0
                    //  0  0  1
                    .ROTATE => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 0, 1, num_cast(-v.sin, MAT_T));
                        DEF.set_cell(&m.mat, 1, 0, num_cast(v.sin, MAT_T));
                    },
                }
                return m;
            }

            pub fn to_inverse_affine_matrix(self: TransformStep) Matrix.define_square_NxN_matrix_type(T, 3, .ROW_MAJOR, 0) {
                return self.to_inverse_affine_matrix_advanced(T, .PREFORM_TRANSLATIONS, .ROW_MAJOR, 0);
            }
            pub fn to_inverse_affine_matrix_ignore_translations(self: TransformStep) Matrix.define_square_NxN_matrix_type(T, 3, .ROW_MAJOR, 0) {
                return self.to_inverse_affine_matrix_advanced(T, .IGNORE_TRANSLATIONS, .ROW_MAJOR, 0);
            }

            pub fn to_inverse_affine_matrix_advanced(self: TransformStep, comptime MAT_T: type, should_translate: ShouldTranslate, comptime MAT_ORDER: Matrix.RowColumnOrder, comptime MAJOR_PAD: comptime_int) Matrix.define_square_NxN_matrix_type(MAT_T, 3, MAT_ORDER, MAJOR_PAD) {
                const MAT = Matrix.define_square_NxN_matrix_type(MAT_T, 3, MAT_ORDER, MAJOR_PAD);
                const DEF = MAT.DEF;
                var m = MAT.IDENTITY;
                switch (self) {
                    // TRANSLATIONS
                    //
                    // 1 0 x
                    // 0 1 y
                    // 0 0 1
                    .TRANSLATE => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 2, num_cast(-v.get_x(), MAT_T));
                            DEF.set_cell(&m.mat, 1, 2, num_cast(-v.get_y(), MAT_T));
                        }
                    },
                    .TRANSLATE_X => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 2, num_cast(-v, MAT_T));
                        }
                    },
                    .TRANSLATE_Y => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 1, 2, num_cast(-v, MAT_T));
                        }
                    },
                    // SCALES
                    //
                    // x 0 0
                    // 0 y 0
                    // 0 0 1
                    .SCALE => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(1 / v.get_x(), MAT_T));
                        DEF.set_cell(&m.mat, 1, 1, num_cast(1 / v.get_y(), MAT_T));
                    },
                    .SCALE_X => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(1 / v, MAT_T));
                    },
                    .SCALE_Y => |v| {
                        DEF.set_cell(&m.mat, 1, 1, num_cast(1 / v, MAT_T));
                    },
                    // SHEARS
                    // X away Y  Y away X
                    //
                    //  1 * 0     1 0 0
                    //  0 1 0     * 1 0
                    //  0 0 1     0 0 1
                    .SKEW_X => |v| {
                        DEF.set_cell(&m.mat, 0, 1, num_cast(-v, MAT_T));
                    },
                    .SKEW_Y => |v| {
                        DEF.set_cell(&m.mat, 1, 0, num_cast(-v, MAT_T));
                    },
                    // ROTATION
                    //
                    //  C -S  0
                    //  S  C  0
                    //  0  0  1
                    .ROTATE => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 0, 1, num_cast(v.sin, MAT_T));
                        DEF.set_cell(&m.mat, 1, 0, num_cast(-v.sin, MAT_T));
                    },
                }
                return m;
            }
        };
    };
}

pub const TransformKind = enum(u8) {
    TRANSLATE,
    TRANSLATE_X,
    TRANSLATE_Y,
    SCALE,
    SCALE_X,
    SCALE_Y,
    SKEW_X,
    SKEW_Y,
    ROTATE,
};
