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
const Types = Root.Types;
const ShapeWinding = Root.CommonTypes.ShapeWinding;
const Assert = Root.Assert;
const MathX = Root.Math;
const SDL3 = Root.SDL3;

const assert_is_float = Assert.assert_is_float;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;

// pub const Vec2ExtraOptions = struct {
//     convert_SDL3: bool = false,
// };

pub const PerpendicularZero = enum(u8) {
    PERP_ZERO_IS_ZERO,
    PERP_ZERO_IS_LAST_COMPONENT_1,
};
pub const NormalizeZero = enum(u8) {
    NORM_ZERO_IS_ZERO,
    NORM_ZERO_IS_LAST_COMPONENT_1,
};
pub const Plane3D = enum(u8) {
    XY,
    YZ,
    XZ,
};

pub fn define_vec_type(comptime T: type, comptime N: comptime_int) type {
    assert_with_reason(N != 0, @src(), "cannot define a 0-dimension vector", .{});
    return extern struct {
        const Vec = @This();
        // const Rect = Root.Rect2.define_rect2_type(T);
        // const Mat3x3 = Root.Mat3x3.define_matrix_3x3_type(T);
        // const Mat4x4 = Root.Mat3x3.define_matrix_3x3_type(T);
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

        vec: VEC = @splat(0),

        pub const VEC: type = @Vector(N, T);
        pub const ZERO = Vec{ .vec = @splat(0) };
        pub const ONE = Vec{ .vec = @splat(1) };
        pub const MIN = Vec{ .vec = @splat(MIN_T) };
        pub const MAX = Vec{ .vec = @splat(MAX_T) };
        pub const FILLED_WITH_N = Vec{ .vec = @splat(N) };
        pub const MIN_T = if (IS_FLOAT) -math.inf(T) else math.minInt(T);
        pub const MAX_T = if (IS_FLOAT) math.inf(T) else math.maxInt(T);
        pub const LAST_COMPONENT_IDX = N - 1;

        fn new_1(x: T) Vec {
            return Vec{ .vec = .{x} };
        }
        fn new_2(x: T, y: T) Vec {
            return Vec{ .vec = .{ x, y } };
        }
        fn new_3(x: T, y: T, z: T) Vec {
            return Vec{ .vec = .{ x, y, z } };
        }
        fn new_4(x: T, y: T, z: T, w: T) Vec {
            return Vec{ .vec = .{ x, y, z, w } };
        }
        fn new_n(vals: [N]T) Vec {
            return Vec{ .vec = @bitCast(vals) };
        }
        pub const new = switch (N) {
            1 => new_1,
            2 => new_2,
            3 => new_3,
            4 => new_4,
            else => new_n,
        };

        pub fn new_splat(val: T) Vec {
            return Vec{ .vec = @splat(val) };
        }
        fn new_1_any(x: anytype) Vec {
            return Vec{ .vec = .{num_cast(x, T)} };
        }
        fn new_2_any(x: anytype, y: anytype) Vec {
            return Vec{ .vec = .{ num_cast(x, T), num_cast(y, T) } };
        }
        fn new_3_any(x: anytype, y: anytype, z: anytype) Vec {
            return Vec{ .vec = .{ num_cast(x, T), num_cast(y, T), num_cast(z, T) } };
        }
        fn new_4_any(x: anytype, y: anytype, z: anytype, w: anytype) Vec {
            return Vec{ .vec = .{ num_cast(x, T), num_cast(y, T), num_cast(z, T), num_cast(w, T) } };
        }
        fn new_n_any() noreturn {
            assert_unreachable(@src(), "`new_any()` is not defined for {d}-D vectors, manually instantiate `.raw` field instead", .{});
        }
        pub const new_any = switch (N) {
            1 => new_1_any,
            2 => new_2_any,
            3 => new_3_any,
            4 => new_4_any,
            else => new_n_any,
        };
        pub fn new_splat_any(val: anytype) Vec {
            return Vec{ .vec = num_cast(val, T) };
        }

        pub fn inverse(self: Vec) Vec {
            return Vec{ .vec = ONE.vec / self.vec };
        }

        pub fn change_size_fill_1(self: Vec, comptime NN: comptime_int) define_vec_type(T, NN) {
            const VV = define_vec_type(T, NN);
            var out: VV = .ONE;
            const M = comptime @min(N, 3);
            inline for (0..M) |i| {
                out.vec[i] = self.vec[i];
            }
            return out;
        }
        pub fn change_size_fill_0(self: Vec, comptime NN: comptime_int) define_vec_type(T, NN) {
            const VV = define_vec_type(T, NN);
            var out: VV = .ZERO;
            const M = comptime @min(N, 3);
            inline for (0..M) |i| {
                out.vec[i] = self.vec[i];
            }
            return out;
        }

        pub fn ceil(self: Vec) Vec {
            if (IS_INT) return self;
            return Vec{ .vec = @ceil(self.vec) };
        }

        pub fn floor(self: Vec) Vec {
            if (IS_INT) return self;
            return Vec{ .vec = @floor(self.vec) };
        }

        pub fn round(self: Vec) Vec {
            if (IS_INT) return self;
            return Vec{ .vec = @round(self.vec) };
        }

        pub fn dot_product(self: Vec, other: Vec) T {
            const products = self.vec * other.vec;
            return @reduce(.Add, products);
        }
        pub inline fn dot(self: Vec, other: Vec) T {
            return self.dot_product(other);
        }
        pub inline fn dot_product_self(self: Vec) T {
            return self.dot_product(self);
        }
        pub inline fn dot_self(self: Vec) T {
            return self.dot_product_self();
        }

        pub fn cross_product(self: Vec, other: Vec) if (N == 2) T else Vec {
            switch (N) {
                2 => {
                    return (self.vec[0] * other.vec[1]) - (self.vec[1] * other.vec[0]);
                },
                3 => {
                    var out: Vec = undefined;
                    out.vec[0] = (self.vec[1] * other.vec[2]) - (self.vec[2] * other.vec[1]);
                    out.vec[1] = (self.vec[2] * other.vec[0]) - (self.vec[0] * other.vec[2]);
                    out.vec[2] = (self.vec[0] * other.vec[1]) - (self.vec[1] * other.vec[0]);
                    return out;
                },
                7 => assert_unreachable(@src(), "the cross-product of a 7-D vector is valid, but not implemented", .{}),
                else => assert_unreachable(@src(), "the cross-product of a {d}-D vector is not valid or implemented", .{N}),
            }
        }
        pub inline fn cross(self: Vec, other: Vec) if (N == 2) T else Vec {
            return self.cross_product(other);
        }

        pub fn triple_product_scalar(self_a: Vec, other_b: Vec, other_c: Vec) T {
            switch (N) {
                3 => {
                    return self_a.dot_product(other_b.cross_product(other_c));
                },
                else => assert_unreachable(@src(), "the scalar triple-product is not defined/implemented for a {d}-D vector", .{N}),
            }
        }
        pub fn triple_product_vector(self_a: Vec, other_b: Vec, other_c: Vec) T {
            switch (N) {
                3 => {
                    return self_a.cross_product(other_b.cross_product(other_c));
                },
                else => assert_unreachable(@src(), "the vector triple-product is not defined/implemented for a {d}-D vector", .{N}),
            }
        }

        pub inline fn shoelace_area_step(self: Vec, next: Vec) if (N == 2) T else Vec {
            switch (N) {
                2 => {
                    return (next.vec[0] - self.vec[0]) * (self.vec[1] + next.y);
                },
                3 => {
                    return self.cross(next);
                },
                else => assert_unreachable(@src(), "the `shoelace_area_step()` function is not defined/implemented for a {d}-D vector", .{N}),
            }
        }
        pub fn shoelace_area_total(ccw_ordered_points: []const Vec) if (N == 2) T else Vec {
            assert_with_reason(ccw_ordered_points.len > 1, @src(), "`shoelace_area_total()` can only be used with a `ordered_points` slice with len >= 2, got len {d}", .{ccw_ordered_points.len});
            switch (N) {
                2 => {
                    var sum: T = 0;
                    var i = 0;
                    var ii = 1;
                    while (ii < ccw_ordered_points.len) {
                        sum += ccw_ordered_points[i].shoelace_area_step(ccw_ordered_points[ii]);
                        i = ii;
                        ii += 1;
                    }
                    sum += ccw_ordered_points[0].shoelace_area_step(ccw_ordered_points[i]);
                    return sum / 2;
                },
                3 => {
                    var sum: Vec = .ZERO;
                    var i = 0;
                    var ii = 1;
                    while (ii < ccw_ordered_points.len) {
                        sum = sum.add(ccw_ordered_points[i].shoelace_area_step(ccw_ordered_points[ii]));
                        i = ii;
                        ii += 1;
                    }
                    sum += ccw_ordered_points[0].shoelace_area_step(ccw_ordered_points[i]);
                    sum = sum.length();
                    return sum.inverse_scale(2);
                },
                else => assert_unreachable(@src(), "the `shoelace_area_total()` function is not defined/implemented for a {d}-D vector", .{N}),
            }
        }

        pub fn add(self: Vec, other: Vec) Vec {
            return Vec{ .vec = self.vec + other.vec };
        }

        pub fn subtract(self: Vec, other: Vec) Vec {
            return Vec{ .vec = self.vec - other.vec };
        }

        pub fn multiply(self: Vec, other: Vec) Vec {
            return Vec{ .vec = self.vec * other.vec };
        }

        pub fn divide(self: Vec, other: Vec) Vec {
            assert_with_reason(!@reduce(.Or, other.vec == ZERO.vec), @src(), "cannot divide two vectors when one of the components of the divisor vector is 0, got divisor = {any}", .{other.vec});
            return Vec{ .vec = self.vec / other.vec };
        }

        pub fn scale(self: Vec, val: anytype) Vec {
            const val_vec: @Vector(N, @TypeOf(val)) = @splat(val);
            return Vec{ .raw = MathX.upgrade_multiply_out(self.raw, val_vec, VEC) };
        }
        pub fn inverse_scale(self: Vec, val: anytype) Vec {
            if (@TypeOf(val) == bool) {
                assert_with_reason(val != false, @src(), "cannot `inverse_scale()` when the scale value is `false`, (divide by zero)", .{});
            } else {
                assert_with_reason(val != 0, @src(), "cannot `inverse_scale()` when the scale value is 0, (divide by zero)", .{});
            }
            const val_vec: @Vector(N, @TypeOf(val)) = @splat(val);
            return Vec{ .raw = MathX.upgrade_divide_out(self.raw, val_vec, VEC) };
        }

        pub fn add_scale(self: Vec, add_vec: Vec, scale_add_vec_by: anytype) Vec {
            return self.add(add_vec.scale(scale_add_vec_by));
        }

        pub fn subtract_scale(self: Vec, subtract_vec: Vec, scale_subtract_vec_by: anytype) Vec {
            return self.add(subtract_vec.scale(scale_subtract_vec_by));
        }

        pub fn squared(self: Vec) Vec {
            return Vec{ .vec = self.vec * self.vec };
        }

        pub fn component_sum(self: Vec) T {
            return @reduce(.Add, self.vec);
        }

        pub fn distance_to(self: Vec, other: Vec) T {
            const sum_squares = self.distance_to_squared(other);
            return num_cast(@sqrt(MathX.upgrade_to_float(sum_squares, F)), T);
        }

        pub fn distance_to_squared(self: Vec, other: Vec) T {
            const delta = other.subtract(self);
            const square = delta.squared();
            return square.component_sum();
        }

        pub fn length(self: Vec) T {
            const squared_sum = self.length_squared();
            return num_cast(@sqrt(MathX.upgrade_to_float(squared_sum, F)), T);
        }

        pub fn length_squared(self: Vec) T {
            const square = self.squared();
            return square.component_sum();
        }

        pub fn length_using_squares(self_squared: Vec) T {
            assert_with_reason(@reduce(.And, self_squared.vec >= ZERO.vec), @src(), "all components of `self_squared` must be positive or zero, got {any}", .{self_squared.vec});
            const sum = self_squared.component_sum();
            return num_cast(@sqrt(MathX.upgrade_to_float(sum, F)), T);
        }

        pub fn normalize(self: Vec) Vec {
            assert_with_reason(@reduce(.Or, self.vec != ZERO.vec), @src(), "at least one component of `self` must be nonzero, otherwise a it will cause a divide by zero", .{});
            const len = self.length();
            return self.inverse_scale(len);
        }

        pub fn normalize_using_length(self: Vec, len: anytype) Vec {
            assert_with_reason(len != 0, @src(), "`len` must be nonzero, otherwise a it will cause a divide by zero", .{});
            return self.inverse_scale(len);
        }

        pub fn normalize_using_squares(self: Vec, self_squared: Vec) Vec {
            assert_with_reason(@reduce(.And, self_squared.vec >= ZERO.vec), @src(), "all components of `self_squared` must be positive or zero, got {any}", .{self_squared.vec});
            const sum = self_squared.component_sum();
            const len = num_cast(@sqrt(MathX.upgrade_to_float(sum, F)), T);
            return self.inverse_scale(len);
        }

        pub fn normalize_may_be_zero(self: Vec, comptime zero_behavior: NormalizeZero) Vec {
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
        pub fn normalize_may_be_zero_with_length(self: Vec, len: anytype, comptime zero_behavior: NormalizeZero) Vec {
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

        pub fn orthoganal_normal_ccw(self: Vec, comptime zero_behavior: PerpendicularZero) Vec {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                var out = ZERO;
                if (zero_behavior == .PERP_ZERO_IS_LAST_COMPONENT_1) {
                    out.vec[LAST_COMPONENT_IDX] = 1;
                }
                return out;
            }
            const len = self.length();
            return self.normalize_using_length(len).perp_ccw();
        }
        pub fn orthoganal_normal_cw(self: Vec, comptime zero_behavior: PerpendicularZero) Vec {
            if (self.is_zero()) {
                @branchHint(.unlikely);
                var out = ZERO;
                if (zero_behavior == .PERP_ZERO_IS_LAST_COMPONENT_1) {
                    out.vec[LAST_COMPONENT_IDX] = 1;
                }
                return out;
            }
            const len = self.length();
            return self.normalize_using_length(len).perp_cw();
        }

        pub fn angle_between(self: Vec, other: Vec, comptime OUT: type) OUT {
            const dot_prod = self.dot_product(other);
            const self_length_squared = self.length_squared();
            const self_length_squared_float = MathX.upgrade_to_float(self_length_squared, F);
            const other_length_squared = self.length_squared();
            const other_length_squared_float = MathX.upgrade_to_float(other_length_squared, F);
            const lengths_multiplied = @sqrt(self_length_squared_float) * @sqrt(other_length_squared_float);
            return num_cast(math.acos(MathX.upgrade_to_float(dot_prod, F) / lengths_multiplied), OUT);
        }

        pub fn angle_between_using_lengths(self: Vec, other: Vec, len_self: anytype, len_other: anytype, comptime OUT: type) OUT {
            const dot_prod = self.dot_product(other);
            const self_length_float = MathX.upgrade_to_float(len_self, F);
            const other_length_float = MathX.upgrade_to_float(len_other, F);
            const lengths_multiplied = MathX.upgrade_multiply(self_length_float, other_length_float);
            return num_cast(math.acos(MathX.upgrade_divide(MathX.upgrade_to_float(dot_prod, F), lengths_multiplied)), OUT);
        }

        pub fn angle_between_using_norms(self_norm: Vec, other_norm: Vec, comptime OUT: type) OUT {
            const dot_prod = self_norm.dot_product(other_norm);
            return num_cast(math.acos(MathX.upgrade_to_float(dot_prod, F)), OUT);
        }

        pub const MiterNormsAndOffset = struct {
            corner_to_prev_norm: Vec = .ZERO,
            corner_to_next_norm: Vec = .ZERO,
            inner_miter_offset_norm: Vec = .ZERO,
        };

        pub const MiterResult = struct {
            corner_to_prev_norm: Vec = .ZERO,
            corner_to_next_norm: Vec = .ZERO,
            inner_miter_offset_norm: Vec = .ZERO,
            inner_offset: Vec = .ZERO,
            inner_point: Vec = .ZERO,
            outer_point: Vec = .ZERO,
            infinite: bool = false,

            pub fn new_infinite(norms: MiterNormsAndOffset) MiterResult {
                return MiterResult{
                    .corner_to_next_norm = norms.corner_to_next_norm,
                    .corner_to_prev_norm = norms.corner_to_prev_norm,
                    .inner_miter_offset_norm = norms.inner_miter_offset_norm,
                    .infinite = true,
                };
            }
            pub fn new_infinite_seg_norms_only(corner_to_prev_norm: Vec, corner_to_next_norm: Vec) MiterResult {
                return MiterResult{
                    .corner_to_next_norm = corner_to_next_norm,
                    .corner_to_prev_norm = corner_to_prev_norm,
                    .inner_miter_offset_norm = corner_to_next_norm,
                    .infinite = true,
                };
            }
        };

        pub fn miter_points_same_line_width(corner: Vec, prev_point: Vec, next_point: Vec, width: anytype) MiterResult {
            const norms = corner.inner_miter_offset_normal_same_line_width(prev_point, next_point);
            return corner.miter_points_same_line_width_using_norms(norms, width);
        }
        pub fn miter_points_same_line_width_using_norms(corner: Vec, norms: MiterNormsAndOffset, width: anytype) MiterResult {
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
        pub fn miter_outer_points_same_line_width(corner: Vec, prev_point: Vec, next_point: Vec, width: anytype) MiterResult {
            const norms = corner.inner_miter_offset_normal_same_line_width(prev_point, next_point);
            return corner.miter_outer_point_same_line_width_using_norms(norms, width);
        }
        pub fn miter_outer_point_same_line_width_using_norms(corner: Vec, norms: MiterNormsAndOffset, width: anytype) MiterResult {
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
        pub fn inner_miter_offset_normal_same_line_width(corner: Vec, prev_point: Vec, next_point: Vec) MiterNormsAndOffset {
            const delta_prev_norm = prev_point.subtract(corner).normalize_may_be_zero(.NORM_ZERO_IS_ZERO);
            const delta_next_norm = next_point.subtract(corner).normalize_may_be_zero(.NORM_ZERO_IS_ZERO);
            const miter_offset_norm_inner = delta_prev_norm.lerp(delta_next_norm, 0.5).normalize_may_be_zero(.NORM_ZERO_IS_ZERO);
            return MiterNormsAndOffset{
                .corner_to_prev_norm = delta_prev_norm,
                .corner_to_next_norm = delta_next_norm,
                .inner_miter_offset_norm = miter_offset_norm_inner,
            };
        }
        pub fn miter_different_widths_no_inner_normal(corner: Vec, prev_point: Vec, prev_segment_width: anytype, next_point: Vec, next_segment_width: anytype) MiterResult {
            const delta_prev_norm = prev_point.subtract(corner).normalize_may_be_zero(.NORM_ZERO_IS_ZERO);
            const delta_next_norm = next_point.subtract(corner).normalize_may_be_zero(.NORM_ZERO_IS_ZERO);
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
        pub fn miter_different_widths_with_inner_normal(corner: Vec, prev_point: Vec, prev_segment_width: anytype, next_point: Vec, next_segment_width: anytype) MiterResult {
            var result = corner.miter_different_widths_no_inner_normal(prev_point, prev_segment_width, next_point, next_segment_width);
            result.inner_miter_offset_norm = result.inner_offset.normalize_may_be_zero(.NORM_ZERO_IS_ZERO);
        }

        /// Assuming `a` and `b` are vectors from the origin
        /// AND are colinear, return the ratio of the length
        /// of `a` compared to the legnth of `b`
        ///
        /// this equals `a.x / b.x` or `a.y / b.y` or `a.z / b.z` or `a.w / b.w`
        pub fn colinear_ratio_a_of_b(a: Vec, b: Vec) T {
            inline for (0..N) |i| {
                if (b.vec[i] != 0) return a.vec[i] / b.vec[i];
            }
            return 0;
        }

        pub fn perp_ccw(self: Vec) Vec {
            switch (N) {
                2 => {
                    return Vec{ .vec = .{ -self.vec[1], self.vec[0] } };
                },
                else => assert_unreachable(@src(), "the function `perp_ccw()` is only defined for 2D vectors, other vectors must use `perp_any()` or `perp_with()` instead", .{}),
            }
        }
        pub fn perp_left(self: Vec) Vec {
            return self.perp_ccw();
        }

        pub fn perp_cw(self: Vec) Vec {
            switch (N) {
                2 => {
                    return Vec{ .vec = .{ self.vec[1], -self.vec[0] } };
                },
                else => assert_unreachable(@src(), "the function `perp_ccw()` is only defined for 2D vectors, other vectors must use `perp_any()` or `perp_with_(right/left)hand()` instead", .{}),
            }
        }
        pub fn perp_right(self: Vec) Vec {
            return self.perp_cw();
        }

        pub fn perp_any(self: Vec) Vec {
            switch (N) {
                3 => {
                    return Vec{ .vec = .{
                        math.copysign(self.vec[2], self.vec[0]),
                        math.copysign(self.vec[2], self.vec[1]),
                        -math.copysign(self.vec[0], self.vec[2]) - math.copysign(self.vec[1], self.vec[2]),
                    } };
                },
                else => assert_unreachable(@src(), "the function `perp_any()` is only defined for 3D vectors, 2D vectors must use `perp_ccw/cw()` instead", .{}),
            }
        }
        pub fn perp_with_righthand(self: Vec, other: Vec) Vec {
            switch (N) {
                3 => {
                    return self.cross(other);
                },
                else => assert_unreachable(@src(), "the function `perp_with_righthand()` is only defined for 3D vectors, 2D vectors must use `perp_ccw/cw()` instead", .{}),
            }
        }
        pub fn perp_with_lefthand(self: Vec, other: Vec) Vec {
            switch (N) {
                3 => {
                    return other.cross(self);
                },
                else => assert_unreachable(@src(), "the function `perp_with_lefthand()` is only defined for 3D vectors, 2D vectors must use `perp_ccw/cw()` instead", .{}),
            }
        }

        fn lerp_internal(p1: Vec, p2: Vec, percent: anytype) Vec {
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
            return Vec{ .vec = num_cast(result, VEC) };
        }

        pub fn lerp(p1: Vec, p2: Vec, percent: anytype) Vec {
            return lerp_internal(p1, p2, percent);
        }
        pub inline fn linear_interp(p1: Vec, p2: Vec, percent: anytype) Vec {
            return lerp_internal(p1, p2, percent);
        }
        pub fn quadratic_interp(p1: Vec, p2: Vec, p3: Vec, percent: anytype) Vec {
            const p12 = lerp_internal(p1, p2, percent);
            const p23 = lerp_internal(p2, p3, percent);
            return lerp_internal(p12, p23, percent);
        }
        pub fn cubic_interp(p1: Vec, p2: Vec, p3: Vec, p4: Vec, percent: anytype) Vec {
            const p12 = lerp_internal(p1, p2, percent);
            const p23 = lerp_internal(p2, p3, percent);
            const p34 = lerp_internal(p3, p4, percent);
            const p12_23 = lerp_internal(p12, p23, percent);
            const p23_34 = lerp_internal(p23, p34, percent);
            return lerp_internal(p12_23, p23_34, percent);
        }
        pub fn n_bezier_interp(comptime NN: comptime_int, p: [NN]Vec, percent: anytype) Vec {
            var tmp: [2][NN]Vec = .{ p, @splat(Vec{}) };
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

        pub fn lerp_delta_range(self: Vec, other: Vec, min_delta: anytype, max_delta: anytype, range_delta: anytype) Vec {
            const range = MathX.upgrade_subtract(max_delta, min_delta);
            const range_percent = MathX.upgrade_multiply(range, range_delta);
            const percent = MathX.upgrade_add(min_delta, range_percent);
            return lerp_internal(self, other, percent);
        }

        pub fn lerp_delta_delta(self: Vec, other: Vec, delta: anytype, delta_delta: anytype) Vec {
            const percent = MathX.upgrade_multiply(delta, delta_delta);
            return lerp_internal(self, other, percent);
        }

        pub fn rotate_radians_2D(self: Vec, radians: anytype) Vec {
            const cos = @cos(MathX.upgrade_to_float(radians, f32));
            const sin = @sin(MathX.upgrade_to_float(radians, f32));
            return self.rotate_sin_cos_2D(sin, cos);
        }

        pub fn rotate_degrees_2D(self: Vec, degrees: anytype) Vec {
            const rads = degrees * math.rad_per_deg;
            return self.rotate_radians_2D(rads);
        }

        pub fn rotate_sin_cos_2D(self: Vec, sin: anytype, cos: anytype) Vec {
            switch (N) {
                2 => {
                    return Vec{ .vec = .{
                        MathX.upgrade_multiply_out(self.vec[0], cos, T) - MathX.upgrade_multiply_out(self.vec[1], sin, T),
                        MathX.upgrade_multiply_out(self.vec[0], sin, T) + MathX.upgrade_multiply_out(self.vec[1], cos, T),
                    } };
                },
                else => assert_unreachable(@src(), "`rotate_xxxxx_2D()` is only defined for 2D vectors, other vectors must use `rotate_xxxxx_around()` instead", .{}),
            }
        }

        pub fn reflect_2D(self: Vec, reflect_normal: Vec) Vec {
            switch (N) {
                2 => {
                    const fix_scale = self.dot_product(reflect_normal) * 2;
                    const reflect_normal_scaled = reflect_normal.scale(fix_scale);
                    return self.subtract(reflect_normal_scaled);
                },
                else => assert_unreachable(@src(), "`reflect_2D()` is only defined for 2D vectors", .{}),
            }
        }

        pub fn negate(self: Vec) Vec {
            return Vec{ .vec = -self.vec };
        }

        pub fn equals(self: Vec, other: Vec) bool {
            return @reduce(.And, self.vec == other.vec);
        }

        pub fn approx_equal(self: Vec, other: Vec) bool {
            return MathX.approx_equal_vec(VEC, self.vec, other.vec);
        }
        pub fn approx_equal_with_epsilon(self: Vec, other: Vec, epsilon: Vec) bool {
            return MathX.approx_equal_with_epsilon_vec(VEC, self.vec, other.vec, epsilon);
        }

        pub fn is_zero(self: Vec) bool {
            return @reduce(.And, self.vec == ZERO.vec);
        }
        pub fn non_zero(self: Vec) bool {
            return !@reduce(.And, self.vec == ZERO.vec);
        }

        /// 'rise' (y) / 'run' (x)
        pub fn slope_2D(self: Vec) T {
            switch (N) {
                2 => {
                    return self.vec[1] / self.vec[0];
                },
                else => assert_unreachable(@src(), "`slope_2D()` is only defined for 2D vectors, 3D vectors must use `slope_3D()` instead", .{}),
            }
        }
        /// 'run' (x) / 'rise' (y)
        pub fn slope_2D_inverse(self: Vec) T {
            switch (N) {
                2 => {
                    return self.vec[0] / self.vec[1];
                },
                else => assert_unreachable(@src(), "`slope_2D_inverse()` is only defined for 2D vectors, 3D vectors must use `slope_3D()` instead", .{}),
            }
        }

        /// 'rise' (component not in `reference_plane`) / 'run' (the length of the 2D vector formed by the components belonging to the `reference_plane`)
        pub fn slope_3D(self: Vec, reference_plane: Plane3D) T {
            switch (N) {
                3 => {
                    var run: define_vec_type(T, 2) = undefined;
                    var rise: T = undefined;
                    switch (reference_plane) {
                        .XY => {
                            run = define_vec_type(T, 2){ .vec = .{ self.vec[0], self.vec[1] } };
                            rise = self.vec[2];
                        },
                        .YZ => {
                            run = define_vec_type(T, 2){ .vec = .{ self.vec[1], self.vec[2] } };
                            rise = self.vec[0];
                        },
                        .XZ => {
                            run = define_vec_type(T, 2){ .vec = .{ self.vec[0], self.vec[2] } };
                            rise = self.vec[1];
                        },
                    }
                    const run_len = run.length();
                    return rise / run_len;
                },
                else => assert_unreachable(@src(), "`slope_3D()` is only defined for 3D vectors, 2D vectors must use `slope_2D()` instead", .{}),
            }
        }
        ///  'run' (the length of the 2D vector formed by the components belonging to the `reference_plane`) / 'rise' (component not in `reference_plane`)
        pub fn slope_3D_inverse(self: Vec, reference_plane: Plane3D) T {
            switch (N) {
                3 => {
                    var run: define_vec_type(T, 2) = undefined;
                    var rise: T = undefined;
                    switch (reference_plane) {
                        .XY => {
                            run = define_vec_type(T, 2){ .vec = .{ self.vec[0], self.vec[1] } };
                            rise = self.vec[2];
                        },
                        .YZ => {
                            run = define_vec_type(T, 2){ .vec = .{ self.vec[1], self.vec[2] } };
                            rise = self.vec[0];
                        },
                        .XZ => {
                            run = define_vec_type(T, 2){ .vec = .{ self.vec[0], self.vec[2] } };
                            rise = self.vec[1];
                        },
                    }
                    const run_len = run.length();
                    return run_len / rise;
                },
                else => assert_unreachable(@src(), "`slope_3D()` is only defined for 3D vectors, 2D vectors must use `slope_2D()` instead", .{}),
            }
        }

        /// ((c.y - a.y) * (b.x - a.x)) - ((c.x - a.x) * (b.y - a.y))
        pub fn cross_3_2D(a: Vec, b: Vec, c: Vec) T {
            switch (N) {
                2 => {
                    return ((c.vec[1] - a.vec[1]) * (b.vec[0] - a.vec[0])) - ((c.vec[0] - a.vec[0]) * (b.vec[1] - a.vec[1]));
                },
                else => assert_unreachable(@src(), "`cross_3_2D()` is only defined for 2D vectors", .{}),
            }
        }

        pub fn approx_colinear(a: Vec, b: Vec, c: Vec) bool {
            if (IS_INT) return colinear(a, b, c);
            switch (N) {
                2 => {
                    return @abs(cross_3_2D(a, b, c)) <= math.floatEps(T);
                },
                else => {
                    const ab = b.subtract(a);
                    const bc = c.subtract(b);
                    const x = ab.cross(bc);
                    const eps: VEC = @splat(math.floatEps(T));
                    return @reduce(.And, x <= eps);
                },
            }
        }

        pub fn colinear(a: Vec, b: Vec, c: Vec) bool {
            switch (N) {
                2 => {
                    return cross_3_2D(a, b, c) == 0;
                },
                else => {
                    const ab = b.subtract(a);
                    const bc = c.subtract(b);
                    return ab.cross(bc).is_zero();
                },
            }
        }

        pub fn approx_orientation_2D(a: Vec, b: Vec, c: Vec) ShapeWinding {
            if (IS_INT) return orientation_2D(a, b, c);
            switch (N) {
                2 => {
                    const cross_3 = cross_3_2D(a, b, c);
                    if (@abs(cross_3) <= math.floatEps(F)) return ShapeWinding.COLINEAR;
                    if (cross_3 > 0) return ShapeWinding.WINDING_CW;
                    return ShapeWinding.WINDING_CCW;
                },
                else => assert_unreachable(@src(), "`approx_orientation_2D()` is only defined for 2D vectors", .{}),
            }
        }

        pub fn orientation_2D(a: Vec, b: Vec, c: Vec) ShapeWinding {
            switch (N) {
                2 => {
                    const cross_3 = cross_3_2D(a, b, c);
                    if (cross_3 == 0) return ShapeWinding.COLINEAR;
                    if (cross_3 > 0) return ShapeWinding.WINDING_CW;
                    return ShapeWinding.WINDING_CCW;
                },
                else => assert_unreachable(@src(), "`orientation_2D()` is only defined for 2D vectors", .{}),
            }
        }

        pub fn approx_on_segment_2D(self: Vec, line_a: Vec, line_b: Vec) bool {
            switch (N) {
                2 => {
                    if (self.approx_orientation_2D(line_a, line_b) != ShapeWinding.COLINEAR) return false;
                    const line_aabb = Root.AABB2.define_aabb2_type(T).from_static_line(line_a, line_b);
                    return line_aabb.point_approx_within(self);
                },
                else => assert_unreachable(@src(), "`approx_on_segment_2D()` is only defined for 2D vectors", .{}),
            }
        }

        pub fn on_segment_2D(self: Vec, line_a: Vec, line_b: Vec) bool {
            switch (N) {
                2 => {
                    if (self.orientation_2D(line_a, line_b) != ShapeWinding.COLINEAR) return false;
                    const line_aabb = Root.AABB2.define_aabb2_type(T).from_static_line(line_a, line_b);
                    return line_aabb.point_within(self);
                },
                else => assert_unreachable(@src(), "`on_segment_2D()` is only defined for 2D vectors", .{}),
            }
        }

        pub fn rate_required_to_reach_point_at_time(self: Vec, point: Vec, time: anytype) Vec {
            return point.subtract(self).scale(1.0 / time);
        }

        pub fn rate_required_to_reach_point_inverse_time(self: Vec, point: Vec, inverse_time: anytype) Vec {
            return point.subtract(self).scale(inverse_time);
        }

        pub fn to_new_type(self: Vec, comptime NEW_T: type) define_vec_type(NEW_T, N) {
            const V = define_vec_type(NEW_T, N);
            return V{ .vec = num_cast(self.vec, V.VEC) };
        }

        pub fn forms_corner_simple(self: Vec, other: Vec) bool {
            return self.dot(other) <= 0;
        }

        /// Where:
        ///   - `ratio == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `ratio == 1` means the vectors always form a corner even if they are pointing in the exact same direction
        ///   - `ratio == -1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_flatness_ratio(self: Vec, other: Vec, ratio: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), @cos(MathX.HALF_PI - (MathX.upgrade_to_float(ratio, f32) * MathX.HALF_PI)));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `ratio == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `ratio == 1` means the vectors always form a corner even if they are pointing in the exact same direction
        ///   - `ratio == -1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_flatness_ratio_using_lengths(self: Vec, self_len: T, other: Vec, other_len: T, ratio: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, @cos(MathX.HALF_PI - (MathX.upgrade_to_float(ratio, f32) * MathX.HALF_PI)));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `threshold == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `threshold > 0` means the vectors form a corner if they are perpendicular, point in generally opposite directions, or point in somewhat the same direction but not enough to cross above the threshold (higher numbers allow 'flatter' corners to pass)
        ///   - `threshold < 0` means the vectors only form a corner if they are pointing in opposite directions enough to remain below the threshold (lower numbers require 'sharper' corners to pass)
        pub fn forms_corner_dot_product_threshold(self: Vec, other: Vec, threshold: anytype) bool {
            return self.dot(other) <= threshold;
        }
        /// Where:
        ///   - `@abs(threshold) == 0` means the vectors only DONT form a corner if they point in EXACTLY the same direction
        ///   - `@abs(threshold) > 0` means the vectors only form a corner if they are perpendicular, point in generally opposite directions, or point in somewhat the same dirction but not enough to fall below the threshold (smaller numbers allow 'flatter' corners to pass)
        pub fn forms_corner_dot_or_cross_product_threshold(self: Vec, other: Vec, threshold: anytype) bool {
            return self.dot(other) <= threshold or @abs(self.cross(other)) > threshold;
        }
        /// Where:
        ///   - `degrees == 180` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `degrees == 90` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `degrees == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and 180
        pub fn forms_corner_less_than_degrees(self: Vec, other: Vec, degrees: anytype) bool {
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
        pub fn forms_corner_less_than_degrees_using_lengths(self: Vec, self_len: T, other: Vec, other_len: T, degrees: anytype) bool {
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
        pub fn forms_corner_less_than_radians(self: Vec, other: Vec, radians: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), @cos(radians));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `radians == PI` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `radians == HALF_PI` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `radians == 0` means the vectors only form a corner if they are pointing in exact opposite directions
        ///
        /// degrees are clamped to between 0 and PI
        pub fn forms_corner_less_than_radians_using_lengths(self: Vec, self_len: T, other: Vec, other_len: T, radians: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, @cos(radians));
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `max_cos == -1` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `max_cos == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `max_cos == 1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_less_than_cosine_of_angle_between(self: Vec, other: Vec, max_cos_of_angle_between: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self.length() * other.length(), max_cos_of_angle_between);
            return self.dot(other) <= dot_threshold;
        }
        /// Where:
        ///   - `max_cos == -1` means the vectors only DONT form a corner if they are pointing in the exact same direction
        ///   - `max_cos == 0` means the vectors only form a corner if they are perpendicular or point in generally opposite directions
        ///   - `max_cos == 1` means the vectors only form a corner if they are pointing in exact opposite directions
        pub fn forms_corner_less_than_cosine_of_angle_between_using_lengths(self: Vec, self_len: T, other: Vec, other_len: T, max_cos_of_angle_between: anytype) bool {
            const dot_threshold = MathX.upgrade_multiply(self_len * other_len, max_cos_of_angle_between);
            return self.dot(other) <= dot_threshold;
        }

        //CHECKPOINT define separate transform funcs for 2D and 3D vectors

        pub fn apply_complex_transform(self: Vec, steps: []const TransformStep) Vec {
            var out = self;
            for (0..steps.len) |i| {
                switch (steps[i]) {
                    .TRANSLATE => |vec| {
                        out = out.add(vec);
                    },
                    .TRANSLATE_X => |x| {
                        out = Vec{ .x = out.x + x, .y = out.y };
                    },
                    .TRANSLATE_Y => |y| {
                        out = Vec{ .x = out.x, .y = out.y + y };
                    },
                    .SCALE => |vec| {
                        out = out.multiply(vec);
                    },
                    .SCALE_X => |x| {
                        out = Vec{ .x = out.x * x, .y = out.y };
                    },
                    .SCALE_Y => |y| {
                        out = Vec{ .x = out.x, .y = out.y * y };
                    },
                    .SKEW_X => |ratio| {
                        out = Vec{ .x = out.x + (ratio * out.y), .y = out.y };
                    },
                    .SKEW_Y => |ratio| {
                        out = Vec{ .x = out.x, .y = out.y + (ratio * out.x) };
                    },
                    .ROTATE => |sincos| {
                        out = out.rotate_sin_cos_2D(sincos.sin, sincos.cos);
                    },
                }
            }
            return out;
        }

        pub fn apply_inverse_complex_transform(self: Vec, steps: []const TransformStep) Vec {
            var out = self;
            const LAST_STEP = steps.len - 1;
            for (0..steps.len) |i| {
                const ii = LAST_STEP - i;
                switch (steps[ii]) {
                    .TRANSLATE => |vec| {
                        out = out.subtract(vec);
                    },
                    .TRANSLATE_X => |x| {
                        out = Vec{ .x = out.x - x, .y = out.y };
                    },
                    .TRANSLATE_Y => |y| {
                        out = Vec{ .x = out.x, .y = out.y - y };
                    },
                    .SCALE => |vec| {
                        out = out.divide(vec);
                    },
                    .SCALE_X => |x| {
                        out = Vec{ .x = out.x / x, .y = out.y };
                    },
                    .SCALE_Y => |y| {
                        out = Vec{ .x = out.x, .y = out.y / y };
                    },
                    .SKEW_X => |ratio| {
                        out = Vec{ .x = out.x + (-ratio * out.y), .y = out.y };
                    },
                    .SKEW_Y => |ratio| {
                        out = Vec{ .x = out.x, .y = out.y + (-ratio * out.x) };
                    },
                    .ROTATE => |sincos| {
                        out = out.rotate_sin_cos_2D(-sincos.sin, sincos.cos);
                    },
                }
            }
            return out;
        }

        /// Ignores translations
        pub fn apply_complex_transform_for_direction_vector(self: Vec, steps: []const TransformStep) Vec {
            var out = self;
            for (0..steps.len) |i| {
                switch (steps[i]) {
                    .TRANSLATE, .TRANSLATE_X, .TRANSLATE_Y => {},
                    .SCALE => |vec| {
                        out = out.multiply(vec);
                    },
                    .SCALE_X => |x| {
                        out = Vec{ .x = out.x * x, .y = out.y };
                    },
                    .SCALE_Y => |y| {
                        out = Vec{ .x = out.x, .y = out.y * y };
                    },
                    .SKEW_X => |ratio| {
                        out = Vec{ .x = out.x + (ratio * out.y), .y = out.y };
                    },
                    .SKEW_Y => |ratio| {
                        out = Vec{ .x = out.x, .y = out.y + (ratio * out.x) };
                    },
                    .ROTATE => |sincos| {
                        out = out.rotate_sin_cos_2D(sincos.sin, sincos.cos);
                    },
                }
            }
            return out;
        }

        /// Ignores translations
        pub fn apply_inverse_complex_transform_for_direction_vector(self: Vec, steps: []const TransformStep) Vec {
            var out = self;
            const LAST_STEP = steps.len - 1;
            inline for (0..steps) |i| {
                const ii = LAST_STEP - i;
                switch (steps[ii]) {
                    .TRANSLATE, .TRANSLATE_X, .TRANSLATE_Y => {},
                    .SCALE => |vec| {
                        out = out.divide(vec);
                    },
                    .SCALE_X => |x| {
                        out = Vec{ .x = out.x / x, .y = out.y };
                    },
                    .SCALE_Y => |y| {
                        out = Vec{ .x = out.x, .y = out.y / y };
                    },
                    .SKEW_X => |ratio| {
                        out = Vec{ .x = out.x + (-ratio * out.y), .y = out.y };
                    },
                    .SKEW_Y => |ratio| {
                        out = Vec{ .x = out.x, .y = out.y + (-ratio * out.x) };
                    },
                    .ROTATE => |sincos| {
                        out = out.rotate_sin_cos_2D(-sincos.sin, sincos.cos);
                    },
                }
            }
            return out;
        }

        pub fn ComplexTransform(comptime NUM_STEPS: comptime_int) type {
            return [NUM_STEPS]TransformStep;
        }

        pub fn complex_transform_steps_to_affine_matrix(steps: []const TransformStep) Mat3x3 {
            const LAST_STEP: usize = steps.len - 1;
            var matrix = Mat3x3.IDENTITY;
            for (0..steps.len) |i| {
                const ii = LAST_STEP - i;
                matrix = matrix.multiply(steps[ii].to_affine_matrix());
            }
            return matrix;
        }
        pub fn complex_transform_steps_to_inverse_affine_matrix(steps: []const TransformStep) Mat3x3 {
            var matrix = Mat3x3.IDENTITY;
            for (0..steps.len) |i| {
                matrix = matrix.multiply(steps[i].to_inverse_affine_matrix());
            }
            return matrix;
        }

        /// Ignores translations
        pub fn complex_transform_steps_to_affine_matrix_for_direction_vector(steps: []const TransformStep) Mat3x3 {
            const LAST_STEP: usize = steps.len - 1;
            var matrix = Mat3x3.IDENTITY;
            for (0..steps.len) |i| {
                const ii = LAST_STEP - i;
                var step_matrix = steps[ii].to_affine_matrix();
                step_matrix.data[0][2] = 0;
                step_matrix.data[1][2] = 0;
                matrix = matrix.multiply(step_matrix);
            }
            return matrix;
        }

        /// Ignores translations
        pub fn complex_transform_steps_to_inverse_affine_matrix_for_direction_vector(steps: []const TransformStep) Mat3x3 {
            var matrix = Mat3x3.IDENTITY;
            for (0..steps.len) |i| {
                var step_matrix = steps[i].to_inverse_affine_matrix();
                step_matrix.data[0][2] = 0;
                step_matrix.data[1][2] = 0;
                matrix = matrix.multiply(step_matrix);
            }
            return matrix;
        }

        pub fn apply_affine_matrix_transform(self: Vec, matrix: Mat3x3) Vec {
            const col = self.as_1x3_matrix_column();
            const new_col = matrix.multiply_with_column(col);
            return Vec.from_1x3_matrix_column(new_col);
        }

        pub const TransformMatrix = switch (N) {
            2 => 
        };

        pub const TransformStep = switch (N) {
            2 => union(TransformKind2D) {
                TRANSLATE: Vec,
                TRANSLATE_X: T,
                TRANSLATE_Y: T,
                SCALE: Vec,
                SCALE_X: T,
                SCALE_Y: T,
                SKEW_X: T,
                SKEW_Y: T,
                ROTATE: struct {
                    sin: F,
                    cos: F,
                },

                pub fn translate(vec: Vec) TransformStep {
                    return TransformStep{ .TRANSLATE = vec };
                }
                pub fn translate_x(x: T) TransformStep {
                    return TransformStep{ .TRANSLATE_X = x };
                }
                pub fn translate_y(y: T) TransformStep {
                    return TransformStep{ .TRANSLATE_Y = y };
                }

                pub fn scale(vec: Vec) TransformStep {
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
                pub fn skew_x_radians(radians_from_y_axis: T) TransformStep {
                    return TransformStep{ .SKEW_X = @tan(radians_from_y_axis) };
                }
                pub fn skew_x_degrees(degrees_from_y_axis: T) TransformStep {
                    return TransformStep{ .SKEW_X = @tan(degrees_from_y_axis * MathX.DEG_TO_RAD) };
                }

                pub fn skew_y_ratio(y_ratio_or_tangent_of_angle_from_x_axis: T) TransformStep {
                    return TransformStep{ .SKEW_Y = y_ratio_or_tangent_of_angle_from_x_axis };
                }
                pub fn skew_y_radians(radians_from_x_axis: T) TransformStep {
                    return TransformStep{ .SKEW_Y = @tan(radians_from_x_axis) };
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

                pub fn to_affine_matrix(self: TransformStep) Mat3x3 {
                    var m = Mat3x3.IDENTITY;
                    switch (self) {
                        .TRANSLATE => |vec| {
                            m.data[0][2] = vec.x;
                            m.data[1][2] = vec.y;
                        },
                        .TRANSLATE_X => |x| {
                            m.data[0][2] = x;
                        },
                        .TRANSLATE_Y => |y| {
                            m.data[1][2] = y;
                        },
                        .SCALE => |vec| {
                            m.data[0][0] = vec.x;
                            m.data[1][1] = vec.y;
                        },
                        .SCALE_X => |x| {
                            m.data[0][0] = x;
                        },
                        .SCALE_Y => |y| {
                            m.data[1][1] = y;
                        },
                        .SKEW_X => |x| {
                            m.data[0][1] = x;
                        },
                        .SKEW_Y => |y| {
                            m.data[1][0] = y;
                        },
                        .ROTATE => |sincos| {
                            m.data[0][0] = sincos.cos;
                            m.data[1][1] = sincos.cos;
                            m.data[0][1] = -sincos.sin;
                            m.data[1][0] = sincos.sin;
                        },
                    }
                }

                pub fn to_inverse_affine_matrix(self: TransformStep) Mat3x3 {
                    var m = Mat3x3.IDENTITY;
                    switch (self) {
                        .TRANSLATE => |vec| {
                            m.data[0][2] = -vec.x;
                            m.data[1][2] = -vec.y;
                        },
                        .TRANSLATE_X => |x| {
                            m.data[0][2] = -x;
                        },
                        .TRANSLATE_Y => |y| {
                            m.data[1][2] = -y;
                        },
                        .SCALE => |vec| {
                            m.data[0][0] = ONE / vec.x;
                            m.data[1][1] = ONE / vec.y;
                        },
                        .SCALE_X => |x| {
                            m.data[0][0] = ONE / x;
                        },
                        .SCALE_Y => |y| {
                            m.data[1][1] = ONE / y;
                        },
                        .SKEW_X => |x| {
                            m.data[0][1] = -x;
                        },
                        .SKEW_Y => |y| {
                            m.data[1][0] = -y;
                        },
                        .ROTATE => |sincos| {
                            m.data[0][0] = sincos.cos;
                            m.data[1][1] = sincos.cos;
                            m.data[0][1] = sincos.sin;
                            m.data[1][0] = -sincos.sin;
                        },
                    }
                }
            },
            3 => union(TransformKind3D) {
                TRANSLATE: Vec,
                TRANSLATE_X: T,
                TRANSLATE_Y: T,
                TRANSLATE_Z: T,
                TRANSLATE_XY: [2]T,
                TRANSLATE_YZ: [2]T,
                TRANSLATE_XZ: [2]T,
                SCALE: Vec,
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

                pub fn translate(vec: Vec) TransformStep {
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

                pub fn scale(vec: Vec) TransformStep {
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

                pub fn to_affine_matrix(self: TransformStep) Mat3x3 {
                    var m = Mat3x3.IDENTITY;
                    switch (self) {
                        .TRANSLATE => |vec| {
                            m.data[0][2] = vec.x;
                            m.data[1][2] = vec.y;
                        },
                        .TRANSLATE_X => |x| {
                            m.data[0][2] = x;
                        },
                        .TRANSLATE_Y => |y| {
                            m.data[1][2] = y;
                        },
                        .SCALE => |vec| {
                            m.data[0][0] = vec.x;
                            m.data[1][1] = vec.y;
                        },
                        .SCALE_X => |x| {
                            m.data[0][0] = x;
                        },
                        .SCALE_Y => |y| {
                            m.data[1][1] = y;
                        },
                        .SKEW_X => |x| {
                            m.data[0][1] = x;
                        },
                        .SKEW_Y => |y| {
                            m.data[1][0] = y;
                        },
                        .ROTATE => |sincos| {
                            m.data[0][0] = sincos.cos;
                            m.data[1][1] = sincos.cos;
                            m.data[0][1] = -sincos.sin;
                            m.data[1][0] = sincos.sin;
                        },
                    }
                }

                pub fn to_inverse_affine_matrix(self: TransformStep) Mat3x3 {
                    var m = Mat3x3.IDENTITY;
                    switch (self) {
                        .TRANSLATE => |vec| {
                            m.data[0][2] = -vec.x;
                            m.data[1][2] = -vec.y;
                        },
                        .TRANSLATE_X => |x| {
                            m.data[0][2] = -x;
                        },
                        .TRANSLATE_Y => |y| {
                            m.data[1][2] = -y;
                        },
                        .SCALE => |vec| {
                            m.data[0][0] = ONE / vec.x;
                            m.data[1][1] = ONE / vec.y;
                        },
                        .SCALE_X => |x| {
                            m.data[0][0] = ONE / x;
                        },
                        .SCALE_Y => |y| {
                            m.data[1][1] = ONE / y;
                        },
                        .SKEW_X => |x| {
                            m.data[0][1] = -x;
                        },
                        .SKEW_Y => |y| {
                            m.data[1][0] = -y;
                        },
                        .ROTATE => |sincos| {
                            m.data[0][0] = sincos.cos;
                            m.data[1][1] = sincos.cos;
                            m.data[0][1] = sincos.sin;
                            m.data[1][0] = -sincos.sin;
                        },
                    }
                }
            },
            else => void,
        };
    };
}

pub const TransformKind2D = enum(u8) {
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

pub const TransformKind3D = enum(u8) {
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
