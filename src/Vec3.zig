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
const Common = Root.CommonTypes;
const Types = Root.Types;
const ShapeWinding = Root.CommonTypes.ShapeWinding;
const Assert = Root.Assert;
const MathX = Root.Math;
const SDL3 = Root.SDL3;
const Vec2Module = Root.Vec2;
const Matrix = Root.Matrix;

const assert_is_float = Assert.assert_is_float;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;

pub const PadForGpu = Common.PadForGpu;
pub const PerpendicularZero = Common.PerpendicularZero;
pub const NormalizeZero = Common.NormalizeZero;
pub const Plane3D = Common.Plane3D;
pub const ShouldTranslate = Common.ShouldTranslate;

pub const Component = enum(u8) {
    X = 0,
    Y = 1,
    Z = 2,
};

pub fn define_vec3_type(comptime T: type) type {
    return extern struct {
        const Vec3 = @This();
        const Vec2 = Vec2Module.define_vec2_type(T);
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
        z: T = 0,

        pub const VEC: type = @Vector(3, T);
        pub const ZERO = Vec3{ .x = 0, .y = 0, .z = 0 };
        pub const ONE = Vec3{ .x = 1, .y = 1, .z = 1 };
        pub const MIN = Vec3{ .x = MIN_T, .y = MIN_T, .z = MIN_T };
        pub const MAX = Vec3{ .x = MAX_T, .y = MAX_T, .z = MAX_T };
        pub const MIN_T = if (IS_FLOAT) -math.inf(T) else math.minInt(T);
        pub const MAX_T = if (IS_FLOAT) math.inf(T) else math.maxInt(T);

        pub fn new(x: T, y: T, z: T) Vec3 {
            return Vec3{ .vec = .{ x, y, z } };
        }
        pub fn new_splat(val: T) Vec3 {
            return Vec3{ .vec = @splat(val) };
        }
        pub fn new_any(x: anytype, y: anytype, z: anytype) Vec3 {
            return Vec3{ .vec = .{ num_cast(x, T), num_cast(y, T), num_cast(z, T) } };
        }
        pub fn new_splat_any(val: anytype) Vec3 {
            return Vec3{ .vec = num_cast(val, T) };
        }

        pub fn flat(self: Vec2) VEC {
            return @bitCast(self);
        }

        // pub fn downgrade_to_vec2_xy(self: Vec3) Vec2 {
        //     return Vec2{.}
        // }

        pub fn swizzle(self: Vec3, new_x: Component, new_y: Component, new_z: Component) Vec3 {
            return Vec3{ .x = self.flat[@intFromEnum(new_x)], .y = self.flat[@intFromEnum(new_y)], .z = self.flat[@intFromEnum(new_z)] };
        }

        pub fn inverse(self: Vec3) Vec3 {
            return Vec3{ .vec = ONE.vec / self.vec };
        }

        pub fn ceil(self: Vec3) Vec3 {
            if (IS_INT) return self;
            return Vec3{ .vec = @ceil(self.vec) };
        }

        pub fn floor(self: Vec3) Vec3 {
            if (IS_INT) return self;
            return Vec3{ .vec = @floor(self.vec) };
        }

        pub fn round(self: Vec3) Vec3 {
            if (IS_INT) return self;
            return Vec3{ .vec = @round(self.vec) };
        }

        pub fn dot_product(self: Vec3, other: Vec3) T {
            const products = self.vec * other.vec;
            return @reduce(.Add, products);
        }
        pub inline fn dot(self: Vec3, other: Vec3) T {
            return self.dot_product(other);
        }
        pub inline fn dot_product_self(self: Vec3) T {
            return self.dot_product(self);
        }
        pub inline fn dot_self(self: Vec3) T {
            return self.dot_product_self();
        }

        pub fn cross_product(self: Vec3, other: Vec3) Vec3 {
            var out: Vec3 = undefined;
            out.x = (self.y * other.z) - (self.z * other.y);
            out.y = (self.z * other.x) - (self.x * other.z);
            out.z = (self.x * other.y) - (self.y * other.x);
            return out;
        }
        pub inline fn cross(self: Vec3, other: Vec3) Vec3 {
            return self.cross_product(other);
        }

        pub fn triple_product_scalar(self_a: Vec3, other_b: Vec3, other_c: Vec3) T {
            return self_a.dot_product(other_b.cross_product(other_c));
        }
        pub fn triple_product_vector(self_a: Vec3, other_b: Vec3, other_c: Vec3) T {
            return self_a.cross_product(other_b.cross_product(other_c));
        }

        pub inline fn shoelace_area_step(self: Vec3, next: Vec3) Vec3 {
            return self.cross(next);
        }
        pub fn shoelace_area_total(ccw_ordered_points: []const Vec3) Vec3 {
            var sum: Vec3 = .ZERO;
            var i = 0;
            var ii = 1;
            while (ii < ccw_ordered_points.len) {
                sum = sum.add(ccw_ordered_points[i].shoelace_area_step(ccw_ordered_points[ii]));
                i = ii;
                ii += 1;
            }
            sum += ccw_ordered_points[i].shoelace_area_step(ccw_ordered_points[0]);
            sum = sum.length();
            return sum.inverse_scale(2);
        }

        pub fn all_components_less_than(self: Vec3, other: Vec3) bool {
            return self.x < other.x and self.y < other.y and self.z < other.z;
        }
        pub fn all_components_less_than_or_equal(self: Vec3, other: Vec3) bool {
            return self.x <= other.x and self.y <= other.y and self.z <= other.z;
        }
        pub fn all_components_greater_than(self: Vec3, other: Vec3) bool {
            return self.x > other.x and self.y > other.y and self.z > other.z;
        }
        pub fn all_components_greater_than_or_equal(self: Vec3, other: Vec3) bool {
            return self.x >= other.x and self.y >= other.y and self.z >= other.z;
        }

        pub fn add(self: Vec3, other: Vec3) Vec3 {
            return Vec3{ .vec = self.vec + other.vec };
        }

        pub fn subtract(self: Vec3, other: Vec3) Vec3 {
            return Vec3{ .vec = self.vec - other.vec };
        }

        pub fn multiply(self: Vec3, other: Vec3) Vec3 {
            return Vec3{ .vec = self.vec * other.vec };
        }

        pub fn divide(self: Vec3, other: Vec3) Vec3 {
            assert_with_reason(!@reduce(.Or, other.vec == ZERO.vec), @src(), "cannot divide two vectors when one of the components of the divisor vector is 0, got divisor = {any}", .{other.vec});
            return Vec3{ .vec = self.vec / other.vec };
        }

        pub fn scale(self: Vec3, val: anytype) Vec3 {
            const val_vec: @Vector(3, @TypeOf(val)) = @splat(val);
            return Vec3{ .vec = MathX.upgrade_multiply_out(self.vec, val_vec, VEC) };
        }
        pub fn inverse_scale(self: Vec3, val: anytype) Vec3 {
            if (@TypeOf(val) == bool) {
                assert_with_reason(val != false, @src(), "cannot `inverse_scale()` when the scale value is `false`, (divide by zero)", .{});
            } else {
                assert_with_reason(val != 0, @src(), "cannot `inverse_scale()` when the scale value is 0, (divide by zero)", .{});
            }
            const val_vec: @Vector(3, @TypeOf(val)) = @splat(val);
            return Vec3{ .vec = MathX.upgrade_divide_out(self.vec, val_vec, VEC) };
        }

        pub fn add_scale(self: Vec3, add_vec: Vec3, scale_add_vec_by: anytype) Vec3 {
            return self.add(add_vec.scale(scale_add_vec_by));
        }

        pub fn subtract_scale(self: Vec3, subtract_vec: Vec3, scale_subtract_vec_by: anytype) Vec3 {
            return self.add(subtract_vec.scale(scale_subtract_vec_by));
        }

        pub fn squared(self: Vec3) Vec3 {
            return Vec3{ .vec = self.vec * self.vec };
        }

        pub fn component_sum(self: Vec3) T {
            return @reduce(.Add, self.vec);
        }

        pub fn distance_to(self: Vec3, other: Vec3) T {
            const sum_squares = self.distance_to_squared(other);
            return num_cast(@sqrt(MathX.upgrade_to_float(sum_squares, F)), T);
        }

        pub fn distance_to_squared(self: Vec3, other: Vec3) T {
            const delta = other.subtract(self);
            const square = delta.squared();
            return square.component_sum();
        }

        pub fn length(self: Vec3) T {
            const squared_sum = self.length_squared();
            return num_cast(@sqrt(MathX.upgrade_to_float(squared_sum, F)), T);
        }

        pub fn length_squared(self: Vec3) T {
            const square = self.squared();
            return square.component_sum();
        }

        pub fn length_using_squares(self_squared: Vec3) T {
            assert_with_reason(@reduce(.And, self_squared.vec >= ZERO.vec), @src(), "all components of `self_squared` must be positive or zero, got {any}", .{self_squared.vec});
            const sum = self_squared.component_sum();
            return num_cast(@sqrt(MathX.upgrade_to_float(sum, F)), T);
        }

        pub fn normalize(self: Vec3) Vec3 {
            assert_with_reason(@reduce(.Or, self.vec != ZERO.vec), @src(), "at least one component of `self` must be nonzero, otherwise a it will cause a divide by zero", .{});
            const len = self.length();
            return self.inverse_scale(len);
        }

        pub fn normalize_using_length(self: Vec3, len: anytype) Vec3 {
            assert_with_reason(len != 0, @src(), "`len` must be nonzero, otherwise a it will cause a divide by zero", .{});
            return self.inverse_scale(len);
        }

        pub fn normalize_using_squares(self: Vec3, self_squared: Vec3) Vec3 {
            assert_with_reason(@reduce(.And, self_squared.vec >= ZERO.vec), @src(), "all components of `self_squared` must be positive or zero, got {any}", .{self_squared.vec});
            const sum = self_squared.component_sum();
            const len = num_cast(@sqrt(MathX.upgrade_to_float(sum, F)), T);
            return self.inverse_scale(len);
        }

        pub fn normalize_may_be_zero(self: Vec3, comptime zero_behavior: NormalizeZero) Vec3 {
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
        pub fn normalize_may_be_zero_with_length(self: Vec3, len: anytype, comptime zero_behavior: NormalizeZero) Vec3 {
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

        pub fn orthoganal_normal_any(self: Vec3, comptime zero_behavior: PerpendicularZero) Vec3 {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                var out = ZERO;
                if (zero_behavior == .PERP_ZERO_IS_LAST_COMPONENT_1) {
                    out.vec[LAST_COMPONENT_IDX] = 1;
                }
                return out;
            }
            const len = self.length();
            return self.normalize_using_length(len).perp_any();
        }
        pub fn orthoganal_normal_with_righthand(self: Vec3, other: Vec3, comptime zero_behavior: PerpendicularZero) Vec3 {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                var out = ZERO;
                if (zero_behavior == .PERP_ZERO_IS_LAST_COMPONENT_1) {
                    out.vec[LAST_COMPONENT_IDX] = 1;
                }
                return out;
            }
            const perp = self.perp_with_righthand(other);
            return perp.normalize();
        }
        pub fn orthoganal_normal_with_lefthand(self: Vec3, other: Vec3, comptime zero_behavior: PerpendicularZero) Vec3 {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                var out = ZERO;
                if (zero_behavior == .PERP_ZERO_IS_LAST_COMPONENT_1) {
                    out.vec[LAST_COMPONENT_IDX] = 1;
                }
                return out;
            }
            const perp = self.perp_with_lefthand(other);
            return perp.normalize();
        }

        pub fn angle_between(self: Vec3, other: Vec3, comptime OUT: type) OUT {
            const dot_prod = self.dot_product(other);
            const self_length_squared = self.length_squared();
            const self_length_squared_float = MathX.upgrade_to_float(self_length_squared, F);
            const other_length_squared = self.length_squared();
            const other_length_squared_float = MathX.upgrade_to_float(other_length_squared, F);
            const lengths_multiplied = @sqrt(self_length_squared_float) * @sqrt(other_length_squared_float);
            return num_cast(math.acos(MathX.upgrade_to_float(dot_prod, F) / lengths_multiplied), OUT);
        }

        pub fn angle_between_using_lengths(self: Vec3, other: Vec3, len_self: anytype, len_other: anytype, comptime OUT: type) OUT {
            const dot_prod = self.dot_product(other);
            const self_length_float = MathX.upgrade_to_float(len_self, F);
            const other_length_float = MathX.upgrade_to_float(len_other, F);
            const lengths_multiplied = MathX.upgrade_multiply(self_length_float, other_length_float);
            return num_cast(math.acos(MathX.upgrade_divide(MathX.upgrade_to_float(dot_prod, F), lengths_multiplied)), OUT);
        }

        pub fn angle_between_using_norms(self_norm: Vec3, other_norm: Vec3, comptime OUT: type) OUT {
            const dot_prod = self_norm.dot_product(other_norm);
            return num_cast(math.acos(MathX.upgrade_to_float(dot_prod, F)), OUT);
        }

        /// Assuming `a` and `b` are vectors from the origin
        /// AND are colinear, return the ratio of the length
        /// of `a` compared to the legnth of `b`
        ///
        /// this equals `a.x / b.x` or `a.y / b.y` or `a.z / b.z`
        pub fn colinear_ratio_a_of_b(a: Vec3, b: Vec3) T {
            inline for (0..3) |i| {
                if (b.vec[i] != 0) return a.vec[i] / b.vec[i];
            }
            return 0;
        }

        pub fn perp_any(self: Vec3) Vec3 {
            return Vec3{ .vec = .{
                math.copysign(self.z, self.x),
                math.copysign(self.z, self.y),
                -math.copysign(self.x, self.z) - math.copysign(self.y, self.z),
            } };
        }
        pub fn perp_with_righthand(self: Vec3, other: Vec3) Vec3 {
            return self.cross(other);
        }
        pub fn perp_with_lefthand(self: Vec3, other: Vec3) Vec3 {
            return other.cross(self);
        }

        fn lerp_internal(p1: Vec3, p2: Vec3, percent: anytype) Vec3 {
            const delta = if (Types.type_is_vector(@TypeOf(percent))) get: {
                const CHILD = @typeInfo(@TypeOf(percent)).vector.child;
                assert_is_float(CHILD, @src());
                break :get percent;
            } else get: {
                assert_is_float(@TypeOf(percent), @src());
                break :get @as(@Vector(VEC.len, @TypeOf(percent)), @splat(percent));
            };
            const nums = MathX.upgrade_3_numbers_for_math(p1.vec, p2.vec, delta);
            const TU = @FieldType(@TypeOf(nums), "a");
            const result = @mulAdd(TU, nums.c, nums.b, @mulAdd(TU, -nums.c, nums.a, nums.a));
            return Vec3{ .vec = num_cast(result, VEC) };
        }

        pub fn lerp(p1: Vec3, p2: Vec3, percent: anytype) Vec3 {
            return lerp_internal(p1, p2, percent);
        }
        pub inline fn linear_interp(p1: Vec3, p2: Vec3, percent: anytype) Vec3 {
            return lerp_internal(p1, p2, percent);
        }
        pub fn quadratic_interp(p1: Vec3, p2: Vec3, p3: Vec3, percent: anytype) Vec3 {
            const p12 = lerp_internal(p1, p2, percent);
            const p23 = lerp_internal(p2, p3, percent);
            return lerp_internal(p12, p23, percent);
        }
        pub fn cubic_interp(p1: Vec3, p2: Vec3, p3: Vec3, p4: Vec3, percent: anytype) Vec3 {
            const p12 = lerp_internal(p1, p2, percent);
            const p23 = lerp_internal(p2, p3, percent);
            const p34 = lerp_internal(p3, p4, percent);
            const p12_23 = lerp_internal(p12, p23, percent);
            const p23_34 = lerp_internal(p23, p34, percent);
            return lerp_internal(p12_23, p23_34, percent);
        }
        pub fn n_bezier_interp(comptime NN: comptime_int, p: [NN]Vec3, percent: anytype) Vec3 {
            var tmp: [2][NN]Vec3 = .{ p, @splat(Vec3{}) };
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

        pub fn lerp_delta_range(self: Vec3, other: Vec3, min_delta: anytype, max_delta: anytype, range_delta: anytype) Vec3 {
            const range = MathX.upgrade_subtract(max_delta, min_delta);
            const range_percent = MathX.upgrade_multiply(range, range_delta);
            const percent = MathX.upgrade_add(min_delta, range_percent);
            return lerp_internal(self, other, percent);
        }

        pub fn lerp_delta_delta(self: Vec3, other: Vec3, delta: anytype, delta_delta: anytype) Vec3 {
            const percent = MathX.upgrade_multiply(delta, delta_delta);
            return lerp_internal(self, other, percent);
        }

        pub fn rotate_around_x_axis_degrees(self: Vec3, degrees: anytype) Vec3 {
            const rads = MathX.upgrade_multiply(degrees, MathX.DEG_TO_RAD);
            return self.rotate_around_x_axis_radians(rads);
        }

        pub fn rotate_around_x_axis_radians(self: Vec3, radians: anytype) Vec3 {
            const cos = @cos(MathX.upgrade_to_float(radians, f32));
            const sin = @sin(MathX.upgrade_to_float(radians, f32));
            return self.rotate_around_x_axis_sin_cos(sin, cos);
        }

        pub fn rotate_around_x_axis_sin_cos(self: Vec3, sin: anytype, cos: anytype) Vec3 {
            return Vec3{ .vec = .{
                self.get_x(),
                MathX.upgrade_subtract_out(MathX.upgrade_multiply(self.get_y(), cos), MathX.upgrade_multiply(self.get_z(), sin), T),
                MathX.upgrade_add_out(MathX.upgrade_multiply(self.get_y(), sin), MathX.upgrade_multiply(self.get_z(), cos), T),
            } };
        }

        pub fn rotate_around_y_axis_degrees(self: Vec3, degrees: anytype) Vec3 {
            const rads = MathX.upgrade_multiply(degrees, MathX.DEG_TO_RAD);
            return self.rotate_around_y_axis_radians(rads);
        }

        pub fn rotate_around_y_axis_radians(self: Vec3, radians: anytype) Vec3 {
            const cos = @cos(MathX.upgrade_to_float(radians, f32));
            const sin = @sin(MathX.upgrade_to_float(radians, f32));
            return self.rotate_around_y_axis_sin_cos(sin, cos);
        }

        pub fn rotate_around_y_axis_sin_cos(self: Vec3, sin: anytype, cos: anytype) Vec3 {
            return Vec3{ .vec = .{
                MathX.upgrade_add_out(MathX.upgrade_multiply(self.get_x(), cos), MathX.upgrade_multiply(self.get_z(), sin), T),
                self.get_y(),
                MathX.upgrade_add_out(MathX.upgrade_multiply(-self.get_x(), sin), MathX.upgrade_multiply(self.get_z(), cos), T),
            } };
        }

        pub fn rotate_around_z_axis_degrees(self: Vec3, degrees: anytype) Vec3 {
            const rads = MathX.upgrade_multiply(degrees, MathX.DEG_TO_RAD);
            return self.rotate_around_z_axis_radians(rads);
        }

        pub fn rotate_around_z_axis_radians(self: Vec3, radians: anytype) Vec3 {
            const cos = @cos(MathX.upgrade_to_float(radians, f32));
            const sin = @sin(MathX.upgrade_to_float(radians, f32));
            return self.rotate_around_z_axis_sin_cos(sin, cos);
        }

        pub fn rotate_around_z_axis_sin_cos(self: Vec3, sin: anytype, cos: anytype) Vec3 {
            return Vec3{ .vec = .{
                MathX.upgrade_subtract_out(MathX.upgrade_multiply(self.get_x(), cos), MathX.upgrade_multiply(self.get_y(), sin), T),
                MathX.upgrade_add_out(MathX.upgrade_multiply(self.get_x(), sin), MathX.upgrade_multiply(self.get_y(), cos), T),
                self.get_z(),
            } };
        }

        pub fn negate(self: Vec3) Vec3 {
            return Vec3{ .vec = -self.vec };
        }

        pub fn equals(self: Vec3, other: Vec3) bool {
            return @reduce(.And, self.vec == other.vec);
        }

        pub fn approx_equal(self: Vec3, other: Vec3) bool {
            return MathX.approx_equal_vec(VEC, self.vec, other.vec);
        }
        pub fn approx_equal_with_epsilon(self: Vec3, other: Vec3, epsilon: Vec3) bool {
            return MathX.approx_equal_with_epsilon_vec(VEC, self.vec, other.vec, epsilon);
        }

        pub fn is_zero(self: Vec3) bool {
            return @reduce(.And, self.vec == ZERO.vec);
        }
        pub fn non_zero(self: Vec3) bool {
            return !@reduce(.And, self.vec == ZERO.vec);
        }

        /// 'rise' (component not in `reference_plane`) / 'run' (the length of the 2D vector formed by the components belonging to the `reference_plane`)
        pub fn slope(self: Vec3, reference_plane: Plane3D) T {
            var run: Vec2 = undefined;
            var rise: T = undefined;
            switch (reference_plane) {
                .XY => {
                    run = Vec2{ .vec = .{ self.x, self.y } };
                    rise = self.z;
                },
                .YZ => {
                    run = Vec2{ .vec = .{ self.y, self.z } };
                    rise = self.x;
                },
                .XZ => {
                    run = Vec2{ .vec = .{ self.x, self.z } };
                    rise = self.y;
                },
            }
            const run_len = run.length();
            return rise / run_len;
        }
        ///  'run' (the length of the 2D vector formed by the components belonging to the `reference_plane`) / 'rise' (component not in `reference_plane`)
        pub fn slope_inverse(self: Vec3, reference_plane: Plane3D) T {
            var run: Vec2 = undefined;
            var rise: T = undefined;
            switch (reference_plane) {
                .XY => {
                    run = Vec2{ .vec = .{ self.x, self.y } };
                    rise = self.z;
                },
                .YZ => {
                    run = Vec2{ .vec = .{ self.y, self.z } };
                    rise = self.x;
                },
                .XZ => {
                    run = Vec2{ .vec = .{ self.x, self.z } };
                    rise = self.y;
                },
            }
            const run_len = run.length();
            return run_len / rise;
        }

        pub fn approx_colinear(a: Vec3, b: Vec3, c: Vec3) bool {
            const ab = b.subtract(a);
            const bc = c.subtract(b);
            const x = ab.cross(bc);
            const eps: VEC = @splat(math.floatEps(T));
            return @reduce(.And, x <= eps);
        }
        pub fn approx_colinear_with_epsilon(a: Vec3, b: Vec3, c: Vec3, epsilon: T) bool {
            const ab = b.subtract(a);
            const bc = c.subtract(b);
            const x = ab.cross(bc);
            const eps: VEC = @splat(epsilon);
            return @reduce(.And, x <= eps);
        }

        pub fn colinear(a: Vec3, b: Vec3, c: Vec3) bool {
            const ab = b.subtract(a);
            const bc = c.subtract(b);
            return ab.cross(bc).is_zero();
        }

        pub fn rate_required_to_reach_point_at_time(self: Vec3, point: Vec3, time: anytype) Vec3 {
            return point.subtract(self).scale(1 / time);
        }

        pub fn rate_required_to_reach_point_inverse_time(self: Vec3, point: Vec3, inverse_time: anytype) Vec3 {
            return point.subtract(self).scale(inverse_time);
        }

        pub fn change_component_type(self: Vec3, comptime NEW_T: type) define_vec3_type(NEW_T) {
            const V = define_vec3_type(NEW_T);
            return V{ .vec = num_cast(self.vec, V.VEC) };
        }

        pub fn forms_corner_simple(self: Vec3, other: Vec3) bool {
            return self.dot(other) <= 0;
        }

        /// Where:
        ///   - `ratio == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `ratio == 1` means the vectors always form a corner even if they are pointing in the exact same direction
        ///   - `ratio == -1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_flatness_ratio(self: Vec3, other: Vec3, ratio: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), @cos(MathX.HALF_PI - (MathX.upgrade_to_float(ratio, f32) * MathX.HALF_PI)));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `ratio == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `ratio == 1` means the vectors always form a corner even if they are pointing in the exact same direction
        ///   - `ratio == -1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_flatness_ratio_using_lengths(self: Vec3, self_len: T, other: Vec3, other_len: T, ratio: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, @cos(MathX.HALF_PI - (MathX.upgrade_to_float(ratio, f32) * MathX.HALF_PI)));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `threshold == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `threshold > 0` means the vectors form a corner if they are perpendicular, point in generally opposite directions, or point in somewhat the same direction but not enough to cross above the threshold (higher numbers allow 'flatter' corners to pass)
        ///   - `threshold < 0` means the vectors only form a corner if they are pointing in opposite directions enough to remain below the threshold (lower numbers require 'sharper' corners to pass)
        pub fn forms_corner_dot_product_threshold(self: Vec3, other: Vec3, threshold: anytype) bool {
            return self.dot(other) <= threshold;
        }
        /// Where:
        ///   - `@abs(threshold) == 0` means the vectors only DONT form a corner if they point in EXACTLY the same direction
        ///   - `@abs(threshold) > 0` means the vectors only form a corner if they are perpendicular, point in generally opposite directions, or point in somewhat the same dirction but not enough to fall below the threshold (smaller numbers allow 'flatter' corners to pass)
        pub fn forms_corner_dot_or_cross_product_threshold(self: Vec3, other: Vec3, threshold: anytype) bool {
            return self.dot(other) <= threshold or @abs(self.cross(other)) > threshold;
        }
        /// Where:
        ///   - `degrees == 180` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `degrees == 90` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `degrees == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and 180
        pub fn forms_corner_less_than_degrees(self: Vec3, other: Vec3, degrees: anytype) bool {
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
        pub fn forms_corner_less_than_degrees_using_lengths(self: Vec3, self_len: T, other: Vec3, other_len: T, degrees: anytype) bool {
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
        pub fn forms_corner_less_than_radians(self: Vec3, other: Vec3, radians: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), @cos(radians));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `radians == PI` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `radians == HALF_PI` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `radians == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and PI
        pub fn forms_corner_less_than_radians_using_lengths(self: Vec3, self_len: T, other: Vec3, other_len: T, radians: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, @cos(radians));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `max_cos == -1` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `max_cos == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `max_cos == 1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_less_than_cosine_of_angle_between(self: Vec3, other: Vec3, max_cos_of_angle_between: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), max_cos_of_angle_between);
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `max_cos == -1` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `max_cos == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `max_cos == 1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_less_than_cosine_of_angle_between_using_lengths(self: Vec3, self_len: T, other: Vec3, other_len: T, max_cos_of_angle_between: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, max_cos_of_angle_between);
            return self.dot(other) <= dot_threshold;
        }

        pub fn apply_transform(self: Vec3, transform: TransformStep) Vec3 {
            return self.apply_transform_advanced(transform, .PREFORM_TRANSLATIONS);
        }
        pub fn apply_transform_ignore_translate(self: Vec3, transform: TransformStep) Vec3 {
            return self.apply_transform_advanced(transform, .IGNORE_TRANSLATIONS);
        }
        fn apply_transform_advanced(self: Vec3, transform: TransformStep, should_translate: ShouldTranslate) Vec3 {
            return switch (transform) {
                .TRANSLATE => |vec| if (should_translate == .PREFORM_TRANSLATIONS) self.add(vec) else self,
                .TRANSLATE_X => |x| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x() + x, self.get_y(), self.get_z() } } else self,
                .TRANSLATE_Y => |y| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x(), self.get_y() + y, self.get_z() } } else self,
                .TRANSLATE_Z => |z| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x(), self.get_y(), self.get_z() + z } } else self,
                .TRANSLATE_XY => |xy| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x() + xy[0], self.get_y() + xy[1], self.get_z() } } else self,
                .TRANSLATE_YZ => |yz| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x(), self.get_y() + yz[0], self.get_z() + yz[1] } } else self,
                .TRANSLATE_XZ => |xz| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x() + xz[0], self.get_y(), self.get_z() + xz[1] } } else self,
                .SCALE => |vec| self.multiply(vec),
                .SCALE_X => |x| Vec3{ .vec = .{ self.get_x() * x, self.get_y(), self.get_z() } },
                .SCALE_Y => |y| Vec3{ .vec = .{ self.get_x(), self.get_y() * y, self.get_z() } },
                .SCALE_Z => |z| Vec3{ .vec = .{ self.get_x(), self.get_y(), self.get_z() * z } },
                .SCALE_XY => |xy| Vec3{ .vec = .{ self.get_x() * xy[0], self.get_y() * xy[1], self.get_z() } },
                .SCALE_YZ => |yz| Vec3{ .vec = .{ self.get_x(), self.get_y() * yz[0], self.get_z() * yz[1] } },
                .SCALE_XZ => |xz| Vec3{ .vec = .{ self.get_x() * xz[0], self.get_y(), self.get_z() * xz[1] } },
                .SKEW_X_AWAY_FROM_Y => |ratio| Vec3{ .vec = .{ self.get_x() + (ratio * self.get_y()), self.get_y(), self.get_z() } },
                .SKEW_X_AWAY_FROM_Z => |ratio| Vec3{ .vec = .{ self.get_x() + (ratio * self.get_z()), self.get_y(), self.get_z() } },
                .SKEW_Y_AWAY_FROM_X => |ratio| Vec3{ .vec = .{ self.get_x(), self.get_y() + (ratio * self.get_x()), self.get_z() } },
                .SKEW_Y_AWAY_FROM_Z => |ratio| Vec3{ .vec = .{ self.get_x(), self.get_y() + (ratio * self.get_z()), self.get_z() } },
                .SKEW_Z_AWAY_FROM_X => |ratio| Vec3{ .vec = .{ self.get_x(), self.get_y(), self.get_z() + (ratio * self.get_x()) } },
                .SKEW_Z_AWAY_FROM_Y => |ratio| Vec3{ .vec = .{ self.get_x(), self.get_y(), self.get_z() + (ratio * self.get_y()) } },
                .ROTATE_AROUND_X_AXIS => |sincos| self.rotate_around_x_axis_sin_cos(sincos.sin, sincos.cos),
                .ROTATE_AROUND_Y_AXIS => |sincos| self.rotate_around_y_axis_sin_cos(sincos.sin, sincos.cos),
                .ROTATE_AROUND_Z_AXIS => |sincos| self.rotate_around_y_axis_sin_cos(sincos.sin, sincos.cos),
            };
        }
        pub fn apply_inverse_transform(self: Vec3, transform: TransformStep) Vec3 {
            return self.apply_inverse_transform_advanced(transform, .PREFORM_TRANSLATIONS);
        }
        pub fn apply_inverse_transform_ignore_translate(self: Vec3, transform: TransformStep) Vec3 {
            return self.apply_inverse_transform_advanced(transform, .IGNORE_TRANSLATIONS);
        }
        fn apply_inverse_transform_advanced(self: Vec3, transform: TransformStep, should_translate: ShouldTranslate) Vec3 {
            return switch (transform) {
                .TRANSLATE => |vec| if (should_translate == .PREFORM_TRANSLATIONS) self.add(vec) else self,
                .TRANSLATE_X => |x| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x() - x, self.get_y(), self.get_z() } } else self,
                .TRANSLATE_Y => |y| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x(), self.get_y() - y, self.get_z() } } else self,
                .TRANSLATE_Z => |z| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x(), self.get_y(), self.get_z() - z } } else self,
                .TRANSLATE_XY => |xy| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x() - xy[0], self.get_y() - xy[1], self.get_z() } } else self,
                .TRANSLATE_YZ => |yz| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x(), self.get_y() - yz[0], self.get_z() - yz[1] } } else self,
                .TRANSLATE_XZ => |xz| if (should_translate == .PREFORM_TRANSLATIONS) Vec3{ .vec = .{ self.get_x() - xz[0], self.get_y(), self.get_z() - xz[1] } } else self,
                .SCALE => |vec| self.multiply(vec),
                .SCALE_X => |x| Vec3{ .vec = .{ self.get_x() / x, self.get_y(), self.get_z() } },
                .SCALE_Y => |y| Vec3{ .vec = .{ self.get_x(), self.get_y() / y, self.get_z() } },
                .SCALE_Z => |z| Vec3{ .vec = .{ self.get_x(), self.get_y(), self.get_z() / z } },
                .SCALE_XY => |xy| Vec3{ .vec = .{ self.get_x() / xy[0], self.get_y() / xy[1], self.get_z() } },
                .SCALE_YZ => |yz| Vec3{ .vec = .{ self.get_x(), self.get_y() / yz[0], self.get_z() / yz[1] } },
                .SCALE_XZ => |xz| Vec3{ .vec = .{ self.get_x() / xz[0], self.get_y(), self.get_z() / xz[1] } },
                .SKEW_X_AWAY_FROM_Y => |ratio| Vec3{ .vec = .{ self.get_x() + (-ratio * self.get_y()), self.get_y(), self.get_z() } },
                .SKEW_X_AWAY_FROM_Z => |ratio| Vec3{ .vec = .{ self.get_x() + (-ratio * self.get_z()), self.get_y(), self.get_z() } },
                .SKEW_Y_AWAY_FROM_X => |ratio| Vec3{ .vec = .{ self.get_x(), self.get_y() + (-ratio * self.get_x()), self.get_z() } },
                .SKEW_Y_AWAY_FROM_Z => |ratio| Vec3{ .vec = .{ self.get_x(), self.get_y() + (-ratio * self.get_z()), self.get_z() } },
                .SKEW_Z_AWAY_FROM_X => |ratio| Vec3{ .vec = .{ self.get_x(), self.get_y(), self.get_z() + (-ratio * self.get_x()) } },
                .SKEW_Z_AWAY_FROM_Y => |ratio| Vec3{ .vec = .{ self.get_x(), self.get_y(), self.get_z() + (-ratio * self.get_y()) } },
                .ROTATE_AROUND_X_AXIS => |sincos| self.rotate_around_x_axis_sin_cos(-sincos.sin, sincos.cos),
                .ROTATE_AROUND_Y_AXIS => |sincos| self.rotate_around_y_axis_sin_cos(-sincos.sin, sincos.cos),
                .ROTATE_AROUND_Z_AXIS => |sincos| self.rotate_around_y_axis_sin_cos(-sincos.sin, sincos.cos),
            };
        }

        fn apply_complex_transform(self: Vec3, steps: []const TransformStep) Vec3 {
            return self.apply_complex_transform_advanced(steps, .PREFORM_TRANSLATIONS);
        }
        fn apply_complex_transform_ignore_translate(self: Vec3, steps: []const TransformStep) Vec3 {
            return self.apply_complex_transform_advanced(steps, .IGNORE_TRANSLATIONS);
        }
        fn apply_complex_transform_advanced(self: Vec3, steps: []const TransformStep, should_translate: ShouldTranslate) Vec3 {
            var out = self;
            for (0..steps.len) |i| {
                out = out.apply_transform_advanced(steps[i], should_translate);
            }
            return out;
        }
        fn apply_inverse_complex_transform(self: Vec3, steps: []const TransformStep) Vec3 {
            return self.apply_inverse_complex_transform_advanced(steps, .PREFORM_TRANSLATIONS);
        }
        fn apply_inverse_complex_transform_ignore_translate(self: Vec3, steps: []const TransformStep) Vec3 {
            return self.apply_inverse_complex_transform_advanced(steps, .IGNORE_TRANSLATIONS);
        }
        fn apply_inverse_complex_transform_advanced(self: Vec3, steps: []const TransformStep, should_translate: ShouldTranslate) Vec3 {
            var out = self;
            const LAST_STEP = steps.len - 1;
            for (0..steps.len) |i| {
                const ii = LAST_STEP - i;
                out = out.apply_inverse_transform_advanced(steps[ii], should_translate);
            }
            return out;
        }

        pub fn complex_transform_to_affine_matrix(steps: []const TransformStep) Matrix.define_square_NxN_matrix_type(T, 4, .ROW_MAJOR, 0) {
            return complex_transform_to_affine_matrix_advanced(steps, .PREFORM_TRANSLATIONS, T, .ROW_MAJOR, 0);
        }
        pub fn complex_transform_to_affine_matrix_ignore_translations(steps: []const TransformStep) Matrix.define_square_NxN_matrix_type(T, 4, .ROW_MAJOR, 0) {
            return complex_transform_to_affine_matrix_advanced(steps, .IGNORE_TRANSLATIONS, T, .ROW_MAJOR, 0);
        }

        pub fn complex_transform_to_affine_matrix_advanced(steps: []const TransformStep, should_translate: ShouldTranslate, comptime MAT_T: type, comptime MAT_ORDER: Matrix.RowColumnOrder, comptime MAJOR_PAD: comptime_int) Matrix.define_square_NxN_matrix_type(MAT_T, 4, MAT_ORDER, MAJOR_PAD) {
            const MAT = Matrix.define_square_NxN_matrix_type(MAT_T, 4, MAT_ORDER, MAJOR_PAD);
            const LAST_STEP: usize = steps.len - 1;
            var matrix = MAT.IDENTITY;
            for (0..steps.len) |i| {
                const ii = LAST_STEP - i;
                if (should_translate == .IGNORE_TRANSLATIONS and steps[ii].is_translate()) continue;
                matrix = matrix.multiply(steps[ii].to_affine_matrix_advanced(MAT_T, MAT_ORDER, MAJOR_PAD));
            }
            return matrix;
        }

        pub fn complex_transform_to_inverse_affine_matrix(steps: []const TransformStep) Matrix.define_square_NxN_matrix_type(T, 4, .ROW_MAJOR, 0) {
            return complex_transform_to_inverse_affine_matrix_advanced(steps, .PREFORM_TRANSLATIONS, T, .ROW_MAJOR, 0);
        }
        pub fn complex_transform_to_inverse_affine_matrix_ignore_translations(steps: []const TransformStep) Matrix.define_square_NxN_matrix_type(T, 4, .ROW_MAJOR, 0) {
            return complex_transform_to_inverse_affine_matrix_advanced(steps, .IGNORE_TRANSLATIONS, T, .ROW_MAJOR, 0);
        }

        pub fn complex_transform_to_inverse_affine_matrix_advanced(steps: []const TransformStep, should_translate: ShouldTranslate, comptime MAT_T: type, comptime MAT_ORDER: Matrix.RowColumnOrder, comptime MAJOR_PAD: comptime_int) Matrix.define_square_NxN_matrix_type(MAT_T, 4, MAT_ORDER, MAJOR_PAD) {
            const MAT = Matrix.define_square_NxN_matrix_type(MAT_T, 4, MAT_ORDER, MAJOR_PAD);
            var matrix = MAT.IDENTITY;
            for (0..steps.len) |i| {
                if (should_translate == .IGNORE_TRANSLATIONS and steps[i].is_translate()) continue;
                matrix = matrix.multiply(steps[i].to_affine_matrix_advanced(MAT_T, MAT_ORDER, MAJOR_PAD));
            }
            return matrix;
        }

        pub fn as_4x1_matrix_column_fill_1(self: Vec3) Matrix.define_rectangular_RxC_matrix_type(T, 4, 1, .COLUMN_MAJOR, 0) {
            const raw: [4]T = .{ self.x, self.y, self.z, 1 };
            return @bitCast(raw);
        }
        pub fn as_1x4_matrix_row_fill_1(self: Vec3) Matrix.define_rectangular_RxC_matrix_type(T, 1, 4, .ROW_MAJOR, 0) {
            const raw: [4]T = .{ self.x, self.y, self.z, 1 };
            return @bitCast(raw);
        }
        pub fn as_4x1_matrix_column_fill_0(self: Vec3) Matrix.define_rectangular_RxC_matrix_type(T, 4, 1, .COLUMN_MAJOR, 0) {
            const raw: [4]T = .{ self.x, self.y, self.z, 0 };
            return @bitCast(raw);
        }
        pub fn as_1x4_matrix_row_fill_0(self: Vec3) Matrix.define_rectangular_RxC_matrix_type(T, 1, 4, .ROW_MAJOR, 0) {
            const raw: [4]T = .{ self.x, self.y, self.z, 0 };
            return @bitCast(raw);
        }

        pub fn apply_affine_matrix_transform(self: Vec3, matrix: anytype) Vec3 {
            return self.apply_affine_matrix_transform_advanced(matrix, .PREFORM_TRANSLATIONS);
        }
        pub fn apply_affine_matrix_transform_ignore_translations(self: Vec3, matrix: anytype) Vec3 {
            return self.apply_affine_matrix_transform_advanced(matrix, .IGNORE_TRANSLATIONS);
        }

        fn apply_affine_matrix_transform_advanced(self: Vec3, matrix: anytype, should_translate: ShouldTranslate) Vec3 {
            const SEFL_DEF = Matrix.define_rectangular_RxC_matrix_type(T, 4, 1, .COLUMN_MAJOR, 0).DEF;
            const self_as_mat = if (should_translate == .PREFORM_TRANSLATIONS) self.as_4x1_matrix_column_fill_1() else self.as_4x1_matrix_column_fill_0();
            const DEF = Matrix.assert_anytype_is_matrix_and_get_def(matrix, @src());
            assert_with_reason(DEF.COLS == 4 and DEF.ROWS == 4, @src(), "affine matrix to apply MUST be a 4x4 matrix, got {d}x{d}", .{ DEF.ROWS, DEF.COLS });
            const result = Matrix.Advanced.multiply_matrices(DEF, matrix, SEFL_DEF, self_as_mat, T, .COLUMN_MAJOR, 0);
            return Vec3{ .vec = .{ result[0][0], result[0][1], result[0][2] } };
        }

        pub const TransformStep = union(TransformKind) {
            TRANSLATE: Vec3,
            TRANSLATE_X: T,
            TRANSLATE_Y: T,
            TRANSLATE_Z: T,
            TRANSLATE_XY: [2]T,
            TRANSLATE_YZ: [2]T,
            TRANSLATE_XZ: [2]T,
            SCALE: Vec3,
            SCALE_X: T,
            SCALE_Y: T,
            SCALE_Z: T,
            SCALE_XY: [2]T,
            SCALE_YZ: [2]T,
            SCALE_XZ: [2]T,
            SKEW_X_AWAY_FROM_Y: T,
            SKEW_X_AWAY_FROM_Z: T,
            SKEW_Y_AWAY_FROM_X: T,
            SKEW_Y_AWAY_FROM_Z: T,
            SKEW_Z_AWAY_FROM_X: T,
            SKEW_Z_AWAY_FROM_Y: T,
            ROTATE_AROUND_X_AXIS: struct {
                sin: F,
                cos: F,
            },
            ROTATE_AROUND_Y_AXIS: struct {
                sin: F,
                cos: F,
            },
            ROTATE_AROUND_Z_AXIS: struct {
                sin: F,
                cos: F,
            },

            pub fn is_translate(self: TransformStep) bool {
                return switch (self) {
                    .TRANSLATE, .TRANSLATE_X, .TRANSLATE_Y, .TRANSLATE_Z, .TRANSLATE_XY, .TRANSLATE_YZ, .TRANSLATE_XZ => true,
                    else => false,
                };
            }

            pub fn translate(vec: Vec3) TransformStep {
                return TransformStep{ .TRANSLATE = vec };
            }
            pub fn translate_x(x: T) TransformStep {
                return TransformStep{ .TRANSLATE_X = x };
            }
            pub fn translate_y(y: T) TransformStep {
                return TransformStep{ .TRANSLATE_Y = y };
            }
            pub fn translate_z(z: T) TransformStep {
                return TransformStep{ .TRANSLATE_Z = z };
            }
            pub fn translate_xy(x: T, y: T) TransformStep {
                return TransformStep{ .TRANSLATE_XY = .{ x, y } };
            }
            pub fn translate_yz(y: T, z: T) TransformStep {
                return TransformStep{ .TRANSLATE_YZ = .{ y, z } };
            }
            pub fn translate_xz(x: T, z: T) TransformStep {
                return TransformStep{ .TRANSLATE_XZ = .{ x, z } };
            }

            pub fn scale(vec: Vec3) TransformStep {
                return TransformStep{ .SCALE = vec };
            }
            pub fn scale_x(x: T) TransformStep {
                return TransformStep{ .SCALE_X = x };
            }
            pub fn scale_y(y: T) TransformStep {
                return TransformStep{ .SCALE_Y = y };
            }
            pub fn scale_z(z: T) TransformStep {
                return TransformStep{ .SCALE_Z = z };
            }
            pub fn scale_xy(x: T, y: T) TransformStep {
                return TransformStep{ .SCALE_XY = .{ x, y } };
            }
            pub fn scale_yz(y: T, z: T) TransformStep {
                return TransformStep{ .SCALE_YZ = .{ y, z } };
            }
            pub fn scale_xz(x: T, z: T) TransformStep {
                return TransformStep{ .SCALE_XZ = .{ x, z } };
            }

            pub fn skew_x_away_from_y_ratio(x_ratio_or_tangent_of_angle_from_y_axis: T) TransformStep {
                return TransformStep{ .SKEW_X_AWAY_FROM_Y = x_ratio_or_tangent_of_angle_from_y_axis };
            }
            pub fn skew_x_away_from_y_radians(radians_from_y_axis: T) TransformStep {
                return TransformStep{ .SKEW_X_AWAY_FROM_Y = @tan(radians_from_y_axis) };
            }
            pub fn skew_x_away_from_y_degrees(degrees_from_y_axis: T) TransformStep {
                return TransformStep{ .SKEW_X_AWAY_FROM_Y = @tan(degrees_from_y_axis * MathX.DEG_TO_RAD) };
            }
            pub fn skew_x_away_from_z_ratio(x_ratio_or_tangent_of_angle_from_z_axis: T) TransformStep {
                return TransformStep{ .SKEW_X_AWAY_FROM_Z = x_ratio_or_tangent_of_angle_from_z_axis };
            }
            pub fn skew_x_away_from_z_radians(radians_from_z_axis: T) TransformStep {
                return TransformStep{ .SKEW_X_AWAY_FROM_Z = @tan(radians_from_z_axis) };
            }
            pub fn skew_x_away_from_z_degrees(degrees_from_z_axis: T) TransformStep {
                return TransformStep{ .SKEW_X_AWAY_FROM_Z = @tan(degrees_from_z_axis * MathX.DEG_TO_RAD) };
            }

            pub fn skew_y_away_from_x_ratio(y_ratio_or_tangent_of_angle_from_x_axis: T) TransformStep {
                return TransformStep{ .SKEW_Y_AWAY_FROM_X = y_ratio_or_tangent_of_angle_from_x_axis };
            }
            pub fn skew_y_away_from_x_radians(radians_from_x_axis: T) TransformStep {
                return TransformStep{ .SKEW_Y_AWAY_FROM_X = @tan(radians_from_x_axis) };
            }
            pub fn skew_y_away_from_x_degrees(degrees_from_x_axis: T) TransformStep {
                return TransformStep{ .SKEW_Y_AWAY_FROM_X = @tan(degrees_from_x_axis * MathX.DEG_TO_RAD) };
            }
            pub fn skew_y_away_from_z_ratio(y_ratio_or_tangent_of_angle_from_z_axis: T) TransformStep {
                return TransformStep{ .SKEW_Y_AWAY_FROM_Z = y_ratio_or_tangent_of_angle_from_z_axis };
            }
            pub fn skew_y_away_from_z_radians(radians_from_z_axis: T) TransformStep {
                return TransformStep{ .SKEW_Y_AWAY_FROM_Z = @tan(radians_from_z_axis) };
            }
            pub fn skew_y_away_from_z_degrees(degrees_from_z_axis: T) TransformStep {
                return TransformStep{ .SKEW_Y_AWAY_FROM_Z = @tan(degrees_from_z_axis * MathX.DEG_TO_RAD) };
            }

            pub fn skew_z_away_from_x_ratio(z_ratio_or_tangent_of_angle_from_x_axis: T) TransformStep {
                return TransformStep{ .SKEW_Z_AWAY_FROM_X = z_ratio_or_tangent_of_angle_from_x_axis };
            }
            pub fn skew_z_away_from_x_radians(radians_from_x_axis: T) TransformStep {
                return TransformStep{ .SKEW_Z_AWAY_FROM_X = @tan(radians_from_x_axis) };
            }
            pub fn skew_z_away_from_x_degrees(degrees_from_x_axis: T) TransformStep {
                return TransformStep{ .SKEW_Z_AWAY_FROM_X = @tan(degrees_from_x_axis * MathX.DEG_TO_RAD) };
            }
            pub fn skew_z_away_from_y_ratio(z_ratio_or_tangent_of_angle_from_y_axis: T) TransformStep {
                return TransformStep{ .SKEW_Z_AWAY_FROM_Y = z_ratio_or_tangent_of_angle_from_y_axis };
            }
            pub fn skew_z_away_from_y_radians(radians_from_y_axis: T) TransformStep {
                return TransformStep{ .SKEW_Z_AWAY_FROM_Y = @tan(radians_from_y_axis) };
            }
            pub fn skew_z_away_from_y_degrees(degrees_from_y_axis: T) TransformStep {
                return TransformStep{ .SKEW_Z_AWAY_FROM_Y = @tan(degrees_from_y_axis * MathX.DEG_TO_RAD) };
            }

            pub fn rotate_around_x_axis_radians(radians: F) TransformStep {
                return TransformStep{ .ROTATE_AROUND_X_AXIS = .{ .sin = @sin(radians), .cos = @cos(radians) } };
            }
            pub fn rotate_around_x_axis_degrees(degrees: F) TransformStep {
                return TransformStep{ .ROTATE_AROUND_X_AXIS = .{ .sin = @sin(degrees * MathX.DEG_TO_RAD), .cos = @cos(degrees * MathX.DEG_TO_RAD) } };
            }
            pub fn rotate_around_x_axis_sin_cos(sin: F, cos: F) TransformStep {
                return TransformStep{ .ROTATE_AROUND_X_AXIS = .{ .sin = sin, .cos = cos } };
            }

            pub fn rotate_around_y_axis_radians(radians: F) TransformStep {
                return TransformStep{ .ROTATE_AROUND_Y_AXIS = .{ .sin = @sin(radians), .cos = @cos(radians) } };
            }
            pub fn rotate_around_y_axis_degrees(degrees: F) TransformStep {
                return TransformStep{ .ROTATE_AROUND_Y_AXIS = .{ .sin = @sin(degrees * MathX.DEG_TO_RAD), .cos = @cos(degrees * MathX.DEG_TO_RAD) } };
            }
            pub fn rotate_around_y_axis_sin_cos(sin: F, cos: F) TransformStep {
                return TransformStep{ .ROTATE_AROUND_Y_AXIS = .{ .sin = sin, .cos = cos } };
            }

            pub fn rotate_around_z_axis_radians(radians: F) TransformStep {
                return TransformStep{ .ROTATE_AROUND_Z_AXIS = .{ .sin = @sin(radians), .cos = @cos(radians) } };
            }
            pub fn rotate_around_z_axis_degrees(degrees: F) TransformStep {
                return TransformStep{ .ROTATE_AROUND_Z_AXIS = .{ .sin = @sin(degrees * MathX.DEG_TO_RAD), .cos = @cos(degrees * MathX.DEG_TO_RAD) } };
            }
            pub fn rotate_around_z_axis_sin_cos(sin: F, cos: F) TransformStep {
                return TransformStep{ .ROTATE_AROUND_Z_AXIS = .{ .sin = sin, .cos = cos } };
            }

            pub fn relect_across_origin() TransformStep {
                return TransformStep{ .SCALE = .new(-1, -1, -1) };
            }
            pub fn relect_across_yz_plane() TransformStep {
                return TransformStep{ .SCALE_X = -1 };
            }
            pub fn relect_across_xz_plane() TransformStep {
                return TransformStep{ .SCALE_Y = -1 };
            }
            pub fn relect_across_xy_plane() TransformStep {
                return TransformStep{ .SCALE_Z = -1 };
            }
            pub fn relect_across_x_axis() TransformStep {
                return TransformStep{ .SCALE_YZ = .{ -1, -1 } };
            }
            pub fn relect_across_y_axis() TransformStep {
                return TransformStep{ .SCALE_XZ = .{ -1, -1 } };
            }
            pub fn relect_across_z_axis() TransformStep {
                return TransformStep{ .SCALE_XY = .{ -1, -1 } };
            }

            pub fn to_affine_matrix(self: TransformStep) Matrix.define_square_NxN_matrix_type(T, 4, .ROW_MAJOR, 0) {
                return self.to_affine_matrix_advanced(T, .PREFORM_TRANSLATIONS, .ROW_MAJOR, 0);
            }
            pub fn to_affine_matrix_ignore_translations(self: TransformStep) Matrix.define_square_NxN_matrix_type(T, 4, .ROW_MAJOR, 0) {
                return self.to_affine_matrix_advanced(T, .IGNORE_TRANSLATIONS, .ROW_MAJOR, 0);
            }

            pub fn to_affine_matrix_advanced(self: TransformStep, comptime MAT_T: type, should_translate: ShouldTranslate, comptime MAT_ORDER: Matrix.RowColumnOrder, comptime MAJOR_PAD: comptime_int) Matrix.define_square_NxN_matrix_type(MAT_T, 4, MAT_ORDER, MAJOR_PAD) {
                const MAT = Matrix.define_square_NxN_matrix_type(MAT_T, 4, MAT_ORDER, MAJOR_PAD);
                const DEF = MAT.DEF;
                var m = MAT.IDENTITY;
                switch (self) {
                    // TRANSLATIONS
                    //
                    // 1 0 0 x
                    // 0 1 0 y
                    // 0 0 1 z
                    // 0 0 0 1
                    .TRANSLATE => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 3, num_cast(v.get_x(), MAT_T));
                            DEF.set_cell(&m.mat, 1, 3, num_cast(v.get_y(), MAT_T));
                            DEF.set_cell(&m.mat, 2, 3, num_cast(v.get_z(), MAT_T));
                        }
                    },
                    .TRANSLATE_X => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 3, num_cast(v, MAT_T));
                        }
                    },
                    .TRANSLATE_Y => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 1, 3, num_cast(v, MAT_T));
                        }
                    },
                    .TRANSLATE_Z => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 2, 3, num_cast(v, MAT_T));
                        }
                    },
                    .TRANSLATE_XY => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 3, num_cast(v[0], MAT_T));
                            DEF.set_cell(&m.mat, 1, 3, num_cast(v[1], MAT_T));
                        }
                    },
                    .TRANSLATE_YZ => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 1, 3, num_cast(v[0], MAT_T));
                            DEF.set_cell(&m.mat, 2, 3, num_cast(v[1], MAT_T));
                        }
                    },
                    .TRANSLATE_XZ => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 3, num_cast(v[0], MAT_T));
                            DEF.set_cell(&m.mat, 2, 3, num_cast(v[1], MAT_T));
                        }
                    },
                    // SCALES
                    //
                    // x 0 0 0
                    // 0 y 0 0
                    // 0 0 z 0
                    // 0 0 0 1
                    .SCALE => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v.get_x(), MAT_T));
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v.get_y(), MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(v.get_z(), MAT_T));
                    },
                    .SCALE_X => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v, MAT_T));
                    },
                    .SCALE_Y => |v| {
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v, MAT_T));
                    },
                    .SCALE_Z => |v| {
                        DEF.set_cell(&m.mat, 2, 2, num_cast(v, MAT_T));
                    },
                    .SCALE_XY => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v[0], MAT_T));
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v[1], MAT_T));
                    },
                    .SCALE_YZ => |v| {
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v[0], MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(v[1], MAT_T));
                    },
                    .SCALE_XZ => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v[0], MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(v[1], MAT_T));
                    },
                    // SHEARS
                    //  X away Y   X away Z   Y away X   Y away Z  Z away X   Z away Y
                    //
                    //  1 * 0 0    1 0 * 0    1 0 0 0    1 0 0 0   1 0 0 0    1 0 0 0
                    //  0 1 0 0    0 1 0 0    * 1 0 0    0 1 * 0   0 1 0 0    0 1 0 0
                    //  0 0 1 0    0 0 1 0    0 0 1 0    0 0 1 0   * 0 1 0    0 * 1 0
                    //  0 0 0 1    0 0 0 1    0 0 0 1    0 0 0 1   0 0 0 1    0 0 0 1
                    .SKEW_X_AWAY_FROM_Y => |v| {
                        DEF.set_cell(&m.mat, 0, 1, num_cast(v, MAT_T));
                    },
                    .SKEW_X_AWAY_FROM_Z => |v| {
                        DEF.set_cell(&m.mat, 0, 2, num_cast(v, MAT_T));
                    },
                    .SKEW_Y_AWAY_FROM_X => |v| {
                        DEF.set_cell(&m.mat, 1, 0, num_cast(v, MAT_T));
                    },
                    .SKEW_Y_AWAY_FROM_Z => |v| {
                        DEF.set_cell(&m.mat, 1, 2, num_cast(v, MAT_T));
                    },
                    .SKEW_Z_AWAY_FROM_X => |v| {
                        DEF.set_cell(&m.mat, 2, 0, num_cast(v, MAT_T));
                    },
                    .SKEW_Z_AWAY_FROM_Y => |v| {
                        DEF.set_cell(&m.mat, 2, 1, num_cast(v, MAT_T));
                    },
                    // ROTATIONS
                    //   X axis          Y axis          Z axis
                    //
                    // 1  0  0  0      C  0 -S  0      C -S  0  0
                    // 0  C  S  0      0  1  0  0      S  C  0  0
                    // 0 -S  C  0      S  0  C  0      0  0  1  0
                    // 0  0  0  1      0  0  0  1      0  0  0  1
                    .ROTATE_AROUND_X_AXIS => |v| {
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 1, 2, num_cast(v.sin, MAT_T));
                        DEF.set_cell(&m.mat, 2, 1, num_cast(-v.sin, MAT_T));
                    },
                    .ROTATE_AROUND_Y_AXIS => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 0, 2, num_cast(-v.sin, MAT_T));
                        DEF.set_cell(&m.mat, 2, 0, num_cast(v.sin, MAT_T));
                    },
                    .ROTATE_AROUND_Z_AXIS => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 0, 1, num_cast(-v.sin, MAT_T));
                        DEF.set_cell(&m.mat, 1, 0, num_cast(v.sin, MAT_T));
                    },
                }
                return m;
            }

            pub fn to_inverse_affine_matrix(self: TransformStep) Matrix.define_square_NxN_matrix_type(T, 4, .ROW_MAJOR, 0) {
                return self.to_inverse_affine_matrix_advanced(T, .PREFORM_TRANSLATIONS, .ROW_MAJOR, 0);
            }
            pub fn to_inverse_affine_matrix_ignore_translations(self: TransformStep) Matrix.define_square_NxN_matrix_type(T, 4, .ROW_MAJOR, 0) {
                return self.to_inverse_affine_matrix_advanced(T, .IGNORE_TRANSLATIONS, .ROW_MAJOR, 0);
            }

            pub fn to_inverse_affine_matrix_advanced(self: TransformStep, comptime MAT_T: type, should_translate: ShouldTranslate, comptime MAT_ORDER: Matrix.RowColumnOrder, comptime MAJOR_PAD: comptime_int) Matrix.define_square_NxN_matrix_type(MAT_T, 4, MAT_ORDER, MAJOR_PAD) {
                const MAT = Matrix.define_square_NxN_matrix_type(MAT_T, 4, MAT_ORDER, MAJOR_PAD);
                const DEF = MAT.DEF;
                var m = MAT.IDENTITY;
                switch (self) {
                    // TRANSLATIONS
                    //
                    // 1 0 0 x
                    // 0 1 0 y
                    // 0 0 1 z
                    // 0 0 0 1
                    .TRANSLATE => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 3, num_cast(-v.get_x(), MAT_T));
                            DEF.set_cell(&m.mat, 1, 3, num_cast(-v.get_y(), MAT_T));
                            DEF.set_cell(&m.mat, 2, 3, num_cast(-v.get_z(), MAT_T));
                        }
                    },
                    .TRANSLATE_X => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 3, num_cast(-v, MAT_T));
                        }
                    },
                    .TRANSLATE_Y => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 1, 3, num_cast(-v, MAT_T));
                        }
                    },
                    .TRANSLATE_Z => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 2, 3, num_cast(-v, MAT_T));
                        }
                    },
                    .TRANSLATE_XY => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 3, num_cast(-v[0], MAT_T));
                            DEF.set_cell(&m.mat, 1, 3, num_cast(-v[1], MAT_T));
                        }
                    },
                    .TRANSLATE_YZ => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 1, 3, num_cast(-v[0], MAT_T));
                            DEF.set_cell(&m.mat, 2, 3, num_cast(-v[1], MAT_T));
                        }
                    },
                    .TRANSLATE_XZ => |v| {
                        if (should_translate == .PREFORM_TRANSLATIONS) {
                            DEF.set_cell(&m.mat, 0, 3, num_cast(-v[0], MAT_T));
                            DEF.set_cell(&m.mat, 2, 3, num_cast(-v[1], MAT_T));
                        }
                    },
                    // SCALES
                    //
                    // x 0 0 0
                    // 0 y 0 0
                    // 0 0 z 0
                    // 0 0 0 1
                    .SCALE => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(1 / v.get_x(), MAT_T));
                        DEF.set_cell(&m.mat, 1, 1, num_cast(1 / v.get_y(), MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(1 / v.get_z(), MAT_T));
                    },
                    .SCALE_X => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(1 / v, MAT_T));
                    },
                    .SCALE_Y => |v| {
                        DEF.set_cell(&m.mat, 1, 1, num_cast(1 / v, MAT_T));
                    },
                    .SCALE_Z => |v| {
                        DEF.set_cell(&m.mat, 2, 2, num_cast(1 / v, MAT_T));
                    },
                    .SCALE_XY => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(1 / v[0], MAT_T));
                        DEF.set_cell(&m.mat, 1, 1, num_cast(1 / v[1], MAT_T));
                    },
                    .SCALE_YZ => |v| {
                        DEF.set_cell(&m.mat, 1, 1, num_cast(1 / v[0], MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(1 / v[1], MAT_T));
                    },
                    .SCALE_XZ => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(1 / v[0], MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(1 / v[1], MAT_T));
                    },
                    // SHEARS
                    //  X away Y   X away Z   Y away X   Y away Z  Z away X   Z away Y
                    //
                    //  1 * 0 0    1 0 * 0    1 0 0 0    1 0 0 0   1 0 0 0    1 0 0 0
                    //  0 1 0 0    0 1 0 0    * 1 0 0    0 1 * 0   0 1 0 0    0 1 0 0
                    //  0 0 1 0    0 0 1 0    0 0 1 0    0 0 1 0   * 0 1 0    0 * 1 0
                    //  0 0 0 1    0 0 0 1    0 0 0 1    0 0 0 1   0 0 0 1    0 0 0 1
                    .SKEW_X_AWAY_FROM_Y => |v| {
                        DEF.set_cell(&m.mat, 0, 1, num_cast(-v, MAT_T));
                    },
                    .SKEW_X_AWAY_FROM_Z => |v| {
                        DEF.set_cell(&m.mat, 0, 2, num_cast(-v, MAT_T));
                    },
                    .SKEW_Y_AWAY_FROM_X => |v| {
                        DEF.set_cell(&m.mat, 1, 0, num_cast(-v, MAT_T));
                    },
                    .SKEW_Y_AWAY_FROM_Z => |v| {
                        DEF.set_cell(&m.mat, 1, 2, num_cast(-v, MAT_T));
                    },
                    .SKEW_Z_AWAY_FROM_X => |v| {
                        DEF.set_cell(&m.mat, 2, 0, num_cast(-v, MAT_T));
                    },
                    .SKEW_Z_AWAY_FROM_Y => |v| {
                        DEF.set_cell(&m.mat, 2, 1, num_cast(-v, MAT_T));
                    },
                    // ROTATIONS
                    //   X axis          Y axis          Z axis
                    //
                    // 1  0  0  0      C  0 -S  0      C -S  0  0
                    // 0  C  S  0      0  1  0  0      S  C  0  0
                    // 0 -S  C  0      S  0  C  0      0  0  1  0
                    // 0  0  0  1      0  0  0  1      0  0  0  1
                    .ROTATE_AROUND_X_AXIS => |v| {
                        DEF.set_cell(&m.mat, 1, 1, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 1, 2, num_cast(-v.sin, MAT_T));
                        DEF.set_cell(&m.mat, 2, 1, num_cast(v.sin, MAT_T));
                    },
                    .ROTATE_AROUND_Y_AXIS => |v| {
                        DEF.set_cell(&m.mat, 0, 0, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 2, 2, num_cast(v.cos, MAT_T));
                        DEF.set_cell(&m.mat, 0, 2, num_cast(v.sin, MAT_T));
                        DEF.set_cell(&m.mat, 2, 0, num_cast(-v.sin, MAT_T));
                    },
                    .ROTATE_AROUND_Z_AXIS => |v| {
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
    TRANSLATE_Z,
    TRANSLATE_XY,
    TRANSLATE_YZ,
    TRANSLATE_XZ,
    SCALE,
    SCALE_X,
    SCALE_Y,
    SCALE_Z,
    SCALE_XY,
    SCALE_YZ,
    SCALE_XZ,
    SKEW_X_AWAY_FROM_Y,
    SKEW_X_AWAY_FROM_Z,
    SKEW_Y_AWAY_FROM_X,
    SKEW_Y_AWAY_FROM_Z,
    SKEW_Z_AWAY_FROM_X,
    SKEW_Z_AWAY_FROM_Y,
    ROTATE_AROUND_X_AXIS,
    ROTATE_AROUND_Y_AXIS,
    ROTATE_AROUND_Z_AXIS,
};
