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

const Root = @import("./_root.zig");
const SliceAdapter = Root.IList_SliceAdapter;
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Flags = Root.Flags;
const IList = Root.IList.IList;
const List = Root.IList_List.List;
const Vec2 = Root.Vec2;
const Mat3x3 = Root.Mat3x3;
const AABB2 = Root.AABB2;
const MathX = Root.Math;
const Bezier = Root.Bezier;
const DataGridModule = Root.DataGrid;
const DataGrid = Root.DataGrid.DataGrid;
const BitmapFormat = Root.FileFormat.Bitmap;

const SignedDistance = MathX.SignedDistance;
const SignedDistanceWithPercent = MathX.SignedDistanceWithPercent;
const ScanlineIntersections = MathX.ScanlineIntersections;
const LinearEstimate = MathX.LinearEstimate;
const QuadraticEstimate = MathX.QuadraticEstimate;
const DoubleRootEstimate = MathX.DoubleRootEstimate;
const FillRule = Root.CommonTypes.FillRule;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

pub const Winding = Root.CommonTypes.ShapeWinding;

pub const DEFAULT_DOUBLE_ROOT_ESTIMATE_RATIO = 1e-12;
pub const DEFAULT_QUADRATIC_ESTIMATE_RATIO = 1e6;
pub const DEFAULT_LINEAR_ESTIMATE_RATIO = 1e12;
pub const HALF_SQRT_5_MINUS_1 = 0.6180339887498948482045868343656381177203091798057628621354;
pub const DEFAULT_DISTANCE_DELTA_FACTOR = 1.001;

pub const EdgeSelectorContants = struct {
    DISTANCE_DELTA_FACTOR: comptime_int = DEFAULT_DISTANCE_DELTA_FACTOR,
};

pub const EdgeKind = enum(u8) {
    POINT,
    LINE,
    QUADRATIC_BEZIER,
    CUBIC_BEZIER,
};

pub fn Point(comptime T: type) type {
    return struct {
        const Self = @This();
        const Matrix = Mat3x3.define_matrix_3x3_type(T);
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        p: [1]Vector,

        pub fn change_base_type(self: Self, comptime TT: type) Point(TT) {
            return Line(TT){ .p = .{
                self.p[0].to_new_type(TT),
            } };
        }

        pub fn upgrade_to_line(self: Self) Line(T) {
            return Line(T){
                .p = .{
                    self.p[0],
                    self.p[0],
                },
            };
        }

        pub fn upgrade_to_quadratic_bezier(self: Self) QuadraticBezier(T) {
            return QuadraticBezier(T){
                .p = .{
                    self.p[0],
                    self.p[0],
                    self.p[0],
                },
            };
        }
        pub fn upgrade_to_cubic_bezier(self: Self) CubicBezier(T) {
            return CubicBezier(T){
                .p = .{
                    self.p[0],
                    self.p[0],
                    self.p[0],
                    self.p[0],
                },
            };
        }

        pub fn get_start(self: Self) Vector {
            return self.p[0];
        }
        pub fn get_end(self: Self) Vector {
            return self.p[0];
        }
        pub fn get_points(self: *Self) []Vector {
            return self.p[0..];
        }

        pub fn lerp(self: Self, _: anytype) Vector {
            return self.p[0];
        }

        pub fn translate(self: Self, vec: Vector) Self {
            return .new(self.p[0].add(vec));
        }
        pub fn scale(self: Self, vec: Vector) Self {
            return .new(self.p[0].multiply(vec));
        }
        pub fn apply_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return .new(self.p[0].apply_complex_transform(steps));
        }
        pub fn apply_inverse_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return .new(self.p[0].apply_inverse_complex_transform(steps));
        }
        pub fn apply_affine_transform_matrix(self: Self, matrix: Matrix) Self {
            return .new(self.p[0].apply_affine_matrix_transform(matrix));
        }
        pub fn transformed(self: Self, transform: TransformNoAlter(T)) Self {
            return switch (transform) {
                .NONE => self,
                .STEPS => |s| self.apply_complex_transform(s),
                .MATRIX => |m| self.apply_affine_transform_matrix(m),
            };
        }

        pub fn new(p: Vector) Self {
            return Self{ .p = .{p} };
        }

        pub fn delta(_: Self) Vector {
            return .ZERO_ZERO;
        }

        pub fn tangent(_: Self, percent: anytype) Vector {
            _ = percent;
            return .ZERO_ZERO;
        }

        pub fn tangent_change(self: Self, percent: anytype) Vector {
            _ = percent;
            _ = self;
            return .ZERO_ZERO;
        }

        pub fn length(self: Self) T {
            _ = self;
            return .ZERO_ZERO;
        }

        pub fn minimum_signed_distance_from_point(self: Self, point: Vector) SignedDistanceWithPercent(T) {
            return SignedDistanceWithPercent(T){
                .signed_dist = SignedDistance(T){
                    .distance = self.p[0].distance_to(point),
                    .dot_product = 0,
                },
                .percent = 0,
            };
        }

        pub fn reverse(self: *Self) void {
            _ = self;
        }
        pub fn horizontal_intersections(self: Self, y_value: T, comptime POINT_MODE: MathX.ScanlinePointMode, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type) ScanlineIntersections(1, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE) {
            var out = ScanlineIntersections(1, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE){};
            if (y_value == self.p[0].y) {
                out.count = 1;
                out.intersections[0] = .new(if (POINT_MODE == .axis_only) self.p[0].x else self.p[0], 0);
            }
            return out;
        }

        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB) void {
            aabb.* = aabb.combine_with_point(self.p[0]);
        }
        pub fn add_rough_bounds_to_aabb(self: Self, aabb: *AABB) void {
            aabb.* = aabb.combine_with_point(self.p[0]);
        }
        pub fn move_start_point(self: *Self, new_start: Vector) void {
            self.p[0] = new_start;
        }
        pub fn move_end_point(self: *Self, new_end: Vector) void {
            self.p[0] = new_end;
        }
        pub fn split_in_thirds(self: Self) [3]Self {
            return .{
                Self.new(self.p[0]),
                Self.new(self.p[0]),
                Self.new(self.p[0]),
            };
        }
    };
}

pub fn Line(comptime T: type) type {
    return struct {
        const Self = @This();
        const Matrix = Mat3x3.define_matrix_3x3_type(T);
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        p: [2]Vector,

        pub fn change_base_type(self: Self, comptime TT: type) Line(TT) {
            return Line(TT){ .p = .{
                self.p[0].to_new_type(TT),
                self.p[1].to_new_type(TT),
            } };
        }

        pub fn upgrade_to_quadratic_bezier(self: Self) QuadraticBezier(T) {
            return QuadraticBezier(T){
                .p = .{
                    self.p[0],
                    self.lerp(0.5),
                    self.p[1],
                },
            };
        }
        pub fn upgrade_to_cubic_bezier(self: Self) CubicBezier(T) {
            return CubicBezier(T){
                .p = .{
                    self.p[0],
                    self.lerp(1.0 / 3.0),
                    self.lerp(2.0 / 3.0),
                    self.p[1],
                },
            };
        }

        pub fn get_start(self: Self) Vector {
            return self.p[0];
        }
        pub fn get_end(self: Self) Vector {
            return self.p[1];
        }
        pub fn get_points(self: *Self) []Vector {
            return self.p[0..];
        }

        pub fn lerp(self: Self, percent: anytype) Vector {
            return Vector.lerp(self.p[0], self.p[1], percent);
        }
        pub fn translate(self: Self, vec: Vector) Self {
            return .new(
                self.p[0].add(vec),
                self.p[1].add(vec),
            );
        }
        pub fn scale(self: Self, vec: Vector) Self {
            return .new(
                self.p[0].multiply(vec),
                self.p[1].multiply(vec),
            );
        }
        pub fn apply_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return .new(
                self.p[0].apply_complex_transform(steps),
                self.p[1].apply_complex_transform(steps),
            );
        }
        pub fn apply_inverse_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return .new(
                self.p[0].apply_inverse_complex_transform(steps),
                self.p[1].apply_inverse_complex_transform(steps),
            );
        }
        pub fn apply_affine_transform_matrix(self: Self, matrix: Matrix) Self {
            return .new(
                self.p[0].apply_affine_matrix_transform(matrix),
                self.p[1].apply_affine_matrix_transform(matrix),
            );
        }
        pub fn transformed(self: Self, transform: TransformNoAlter(T)) Self {
            return switch (transform) {
                .NONE => self,
                .STEPS => |s| self.apply_complex_transform(s),
                .MATRIX => |m| self.apply_affine_transform_matrix(m),
            };
        }

        pub fn new(start: Vector, end: Vector) Self {
            return Self{ .p = .{ start, end } };
        }

        pub fn delta(self: Self) Vector {
            return self.get_end().subtract(self.get_start());
        }

        pub fn tangent(self: Self, percent: T) Vector {
            _ = percent;
            return self.delta();
        }

        pub fn tangent_change(self: Self, percent: T) Vector {
            _ = percent;
            _ = self;
            return Vector.ZERO_ZERO;
        }

        pub fn length(self: Self) T {
            return self.delta().length();
        }

        pub fn minimum_signed_distance_from_point(self: Self, point: Vector) SignedDistanceWithPercent(T) {
            const point_to_start_delta = point.subtract(self.p[0]);
            const line_delta = self.delta();
            const percent = point_to_start_delta.dot(line_delta) / line_delta.dot_self();
            const point_to_nearest_endpoint_delta = self.p[@intFromBool(percent > 0.5)].subtract(point);
            const point_to_nearest_endpoint_distance = point_to_nearest_endpoint_delta.length();
            if (percent > 0 and percent < 1) {
                const ortho_dist = line_delta.orthoganal_normal_cw(.perp_zero_is_y_magnitude_1).dot(point_to_start_delta);
                if (@abs(ortho_dist) < point_to_nearest_endpoint_distance) {
                    return SignedDistanceWithPercent(T).new(ortho_dist, 0, percent);
                }
            }
            const point_to_start_delta_cross_line_delta = point_to_start_delta.cross(line_delta);
            const point_delta_seg_delta_cross_sign = MathX.sign_nonzero(point_to_start_delta_cross_line_delta);
            const dist = point_delta_seg_delta_cross_sign * point_to_nearest_endpoint_distance;
            const line_normal = line_delta.normalize();
            const point_to_nearest_endpoint_normal = point_to_nearest_endpoint_delta.normalize_using_length(point_to_nearest_endpoint_distance);
            const dot = @abs(line_normal.dot(point_to_nearest_endpoint_normal));
            return SignedDistanceWithPercent(T).new(dist, dot, percent);
        }

        pub fn reverse(self: *Self) void {
            const tmp = self.p[1];
            self.p[1] = self.p[0];
            self.p[0] = tmp;
        }
        pub fn horizontal_intersections(self: Self, y_value: T, comptime POINT_MODE: MathX.ScanlinePointMode, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type) ScanlineIntersections(1, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE) {
            var result = ScanlineIntersections(1, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE){};
            if ((y_value >= self.p[0].y and y_value < self.p[1].y) or (y_value >= self.p[1].y and y_value < self.p[0].y)) {
                const slope = self.p[1].y - self.p[0].y;
                const percent = (y_value - self.p[0].y) / slope;
                switch (POINT_MODE) {
                    .axis_only => {
                        result.intersections[0].point = MathX.lerp(self.p[0].x, self.p[1].x, percent);
                    },
                    .point => {
                        result.intersections[0].point.x = MathX.lerp(self.p[0].x, self.p[1].x, percent);
                        result.intersections[0].point.y = y_value;
                    },
                }
                switch (SLOPE_MODE) {
                    .exact => {
                        result.intersections[0].slope = num_cast(slope, SLOPE_TYPE);
                    },
                    .sign => {
                        result.intersections[0].slope = MathX.sign_convert(slope, SLOPE_TYPE);
                    },
                }
                result.count = 1;
            }
            return result;
        }
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB) void {
            aabb.* = aabb.combine_with_point(self.p[0]);
            aabb.* = aabb.combine_with_point(self.p[1]);
        }
        pub fn add_rough_bounds_to_aabb(self: Self, aabb: *AABB) void {
            aabb.* = aabb.combine_with_point(self.p[0]);
            aabb.* = aabb.combine_with_point(self.p[1]);
        }
        pub fn move_start_point(self: *Self, new_start: Vector) void {
            self.p[0] = new_start;
        }
        pub fn move_end_point(self: *Self, new_end: Vector) void {
            self.p[1] = new_end;
        }
        pub fn split_in_thirds(self: Self) [3]Self {
            const p_1_3 = self.lerp(1 / 3);
            const p_2_3 = self.lerp(2 / 3);
            return .{
                Self.new(self.p[0], p_1_3),
                Self.new(p_1_3, p_2_3),
                Self.new(p_2_3, self.p[1]),
            };
        }
    };
}

pub fn QuadraticBezier(comptime T: type) type {
    return struct {
        const Self = @This();
        const Matrix = Mat3x3.define_matrix_3x3_type(T);
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        p: [3]Vector,

        pub fn get_start(self: Self) Vector {
            return self.p[0];
        }
        pub fn get_control(self: Self) Vector {
            return self.p[1];
        }
        pub fn get_end(self: Self) Vector {
            return self.p[2];
        }
        pub fn get_points(self: *Self) []Vector {
            return self.p[0..];
        }

        pub fn change_base_type(self: Self, comptime TT: type) QuadraticBezier(TT) {
            return QuadraticBezier(TT){ .p = .{
                self.p[0].to_new_type(TT),
                self.p[1].to_new_type(TT),
                self.p[2].to_new_type(TT),
            } };
        }

        pub fn upgrade_to_cubic_bezier(self: Self) CubicBezier(T) {
            return CubicBezier(T){
                .p = .{
                    self.p[0],
                    self.p[0].lerp(self.p[1], 2.0 / 3.0),
                    self.p[1].lerp(self.p[2], 1.0 / 3.0),
                    self.p[2],
                },
            };
        }

        pub fn lerp(self: Self, percent: anytype) Vector {
            return Vector.quadratic_interp(self.p[0], self.p[1], self.p[2], percent);
        }
        pub fn translate(self: Self, vec: Vector) Self {
            return .new(
                self.p[0].add(vec),
                self.p[1].add(vec),
                self.p[2].add(vec),
            );
        }
        pub fn scale(self: Self, vec: Vector) Self {
            return .new(
                self.p[0].multiply(vec),
                self.p[1].multiply(vec),
                self.p[2].multiply(vec),
            );
        }
        pub fn apply_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return .new(
                self.p[0].apply_complex_transform(steps),
                self.p[1].apply_complex_transform(steps),
                self.p[2].apply_complex_transform(steps),
            );
        }
        pub fn apply_inverse_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return .new(
                self.p[0].apply_inverse_complex_transform(steps),
                self.p[1].apply_inverse_complex_transform(steps),
                self.p[2].apply_inverse_complex_transform(steps),
            );
        }
        pub fn apply_affine_transform_matrix(self: Self, matrix: Matrix) Self {
            return .new(
                self.p[0].apply_affine_matrix_transform(matrix),
                self.p[1].apply_affine_matrix_transform(matrix),
                self.p[2].apply_affine_matrix_transform(matrix),
            );
        }
        pub fn transformed(self: Self, transform: TransformNoAlter(T)) Self {
            return switch (transform) {
                .NONE => self,
                .STEPS => |s| self.apply_complex_transform(s),
                .MATRIX => |m| self.apply_affine_transform_matrix(m),
            };
        }

        pub fn new(start: Vector, control: Vector, end: Vector) Self {
            return Self{ .p = .{ start, control, end } };
        }

        pub fn delta(self: Self) Vector {
            return self.p[2].subtract(self.p[0]);
        }

        pub fn tangent(self: Self, percent: anytype) Vector {
            const dir_2_1 = self.p[1].subtract(self.p[0]);
            const dir_3_2 = self.p[2].subtract(self.p[1]);
            const tangent_ = dir_2_1.lerp(dir_3_2, percent);
            if (tangent_.is_zero()) {
                return self.p[2].subtract(self.p[0]);
            }
            return tangent_;
        }

        pub fn tangent_change(self: Self, percent: anytype) Vector {
            _ = percent;
            return (self.p[2].subtract(self.p[1])).subtract(self.p[1].subtract(self.p[0]));
        }

        pub fn length(self: Self) T {
            // this comes from https://github.com/Chlumsky/msdfgen/blob/master/core/edge-segments.cpp#L157
            // I have no idea how this works, couldnt find a similar 'arc length of quadratic bezier' algo
            const vec_ab = self.p[1].subtract(self.p[0]);
            const vec_bc = self.p[2].subtract(self.p[1]);
            const vec_br = vec_bc.subtract(vec_ab);
            const prod_abab = vec_ab.dot_self();
            const prod_abbr = vec_ab.dot(vec_br);
            const prod_brbr = vec_br.dot_self();
            const len_ab = @sqrt(prod_abab);
            const len_br = @sqrt(prod_brbr);
            const cross = vec_ab.cross(vec_br);
            const sum_abbr_brbr = prod_abbr + prod_brbr;
            const hypot = @sqrt(prod_abab + prod_abbr + sum_abbr_brbr);
            return ((len_br * ((sum_abbr_brbr * hypot) - (prod_abbr * len_ab))) + (cross * cross * @log(((len_br * hypot) + sum_abbr_brbr) / ((len_br * len_ab) + prod_abbr)))) / (prod_brbr * len_br);
        }
        pub fn length_estimate(self: Self, steps: u32) T {
            const self_float = if (!Types.type_is_float(T)) self.change_base_type(Vector.F) else self;
            const step: Vector.F = 1.0 / MathX.convert_number(steps, Vector.F);
            var i: u32 = 0;
            var s: Vector.F = 0;
            var total: Vector.F = 0;
            var last = self_float.p[0];
            var curr = self_float.p[0];
            var delta_ = self_float.p[0];
            const steps_minus_1 = steps - 1;
            while (i < steps_minus_1) {
                i += 1;
                s += step;
                curr = self_float.lerp(s);
                delta_ = curr.subtract(last);
                total += delta_.length();
                last = curr;
            }
            delta_ = self.p[2].subtract(last);
            total += delta_.length();
            return MathX.convert_number(total, T);
        }

        pub fn minimum_signed_distance_from_point(self: Self, point: Vector) SignedDistanceWithPercent(T) {
            const point_to_start_delta = self.p[0].subtract(point);
            const segment_1_delta = self.p[1].subtract(self.p[0]);
            const segment_2_delta = self.p[2].subtract(self.p[1]);
            const segment_12_delta_diff = segment_2_delta.subtract(segment_1_delta);
            const segment_1_delta_dot_segment_12_delta_diff = segment_1_delta.dot(segment_12_delta_diff);
            const segment_1_delta_dot_self = segment_1_delta.dot_self();
            const point_to_start_delta_dot_segment_12_delta_diff = point_to_start_delta.dot(segment_12_delta_diff);
            const a = segment_12_delta_diff.dot_self();
            const b = 3 * segment_1_delta_dot_segment_12_delta_diff;
            const c = (2 * segment_1_delta_dot_self) + point_to_start_delta_dot_segment_12_delta_diff;
            const d = point_to_start_delta.dot(segment_1_delta);
            const cubic_solutions = MathX.solve_cubic_polynomial_for_zeros_estimate(a, b, c, d);
            const start_tangent = self.tangent(0);
            const start_tangent_cross_point_to_start_delta = start_tangent.cross(point_to_start_delta);
            // set min distance to distance from first point
            const point_to_start_delta_length = point_to_start_delta.length();
            var min_distance = MathX.sign_nonzero(start_tangent_cross_point_to_start_delta) * point_to_start_delta_length;
            var percent = (-point_to_start_delta.dot(start_tangent)) / start_tangent.dot_self();
            var end_tangent: Vector = undefined;
            var point_to_end_delta: Vector = undefined;
            var point_to_end_delta_length: T = undefined;
            {
                // check if point is actually closer to last point and update vals
                point_to_end_delta = self.p[2].subtract(point);
                point_to_end_delta_length = point_to_end_delta.length();
                if (point_to_end_delta_length < @abs(min_distance)) {
                    end_tangent = self.tangent(1);
                    min_distance = MathX.sign_nonzero(end_tangent.cross(point_to_end_delta)) * point_to_end_delta_length;
                    const control_point_to_point_delta = point.subtract(self.p[1]);
                    percent = control_point_to_point_delta.dot(end_tangent) / end_tangent.dot_self();
                }
            }
            for (cubic_solutions.vals[0..cubic_solutions.count]) |x| {
                if (x > 0 and x < 1) {
                    const point_to_solution_point_delta = point_to_start_delta.add_scale(segment_1_delta, 2 * x).add_scale(segment_12_delta_diff, x * x);
                    const point_to_solution_point_distance = point_to_solution_point_delta.length();
                    if (point_to_solution_point_distance < @abs(min_distance)) {
                        min_distance = MathX.sign_nonzero(segment_1_delta.add_scale(segment_12_delta_diff, x).cross(point_to_solution_point_delta)) * point_to_solution_point_distance;
                        percent = x;
                    }
                }
            }
            if (percent >= 0 and percent <= 1) {
                return SignedDistanceWithPercent(T).new(min_distance, 0, percent);
            }
            if (percent < 0.5) {
                // percent < 0
                return SignedDistanceWithPercent(T).new(min_distance, @abs(start_tangent.normalize().dot(point_to_start_delta.normalize_using_length(point_to_start_delta_length))), percent);
            } else {
                // percent > 1
                return SignedDistanceWithPercent(T).new(min_distance, @abs(end_tangent.normalize().dot(point_to_end_delta.normalize_using_length(point_to_end_delta_length))), percent);
            }
        }

        pub fn reverse(self: *Self) void {
            const tmp = self.p[2];
            self.p[2] = self.p[0];
            self.p[0] = tmp;
        }
        pub fn horizontal_intersections(self: Self, y_value: T, comptime POINT_MODE: MathX.ScanlinePointMode, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type, linear_estimate: LinearEstimate(T)) ScanlineIntersections(2, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE) {
            var result = ScanlineIntersections(2, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE){};
            var next_slope_sign: SLOPE_TYPE = if (y_value > self.p[0].y) 1 else -1;
            switch (POINT_MODE) {
                .axis_only => {
                    result.intersections[0].point = self.p[0].x;
                },
                .point => {
                    result.intersections[0].point.x = self.p[0].x;
                    result.intersections[0].point.y = y_value;
                },
            }
            if (self.p[0].y == y_value) {
                if (self.p[0].y < self.p[1].y or (self.p[0].y == self.p[1].y and self.p[0].y < self.p[2].y)) {
                    switch (SLOPE_MODE) {
                        .exact => {
                            result.intersections[0].slope = num_cast(self.tangent(0).slope(), SLOPE_TYPE);
                        },
                        .sign => {
                            result.intersections[0].slope = 1;
                        },
                    }
                    result.count += 1;
                } else {
                    next_slope_sign = 1;
                }
            }
            {
                const segment_1 = self.p[1].subtract(self.p[0]);
                const segment_2 = self.p[2].subtract(self.p[1]);
                const segment_12_diff = segment_2.subtract(segment_1);
                var solutions = MathX.solve_quadratic_polynomial_for_zeros_advanced(segment_12_diff.y, segment_1.y * 2, self.p[0].y - y_value, linear_estimate);
                // // VERIFY this may or may not be incorrect? it seems correct to my intuition
                // solutions.add_finite_solutions_if_infinite(2, .{ self.p[0].x, self.p[2].x });
                var temp: T = undefined;
                if (solutions.count >= 2 and solutions.vals[0] > solutions.vals[1]) {
                    temp = solutions.vals[0];
                    solutions.vals[0] = solutions.vals[1];
                    solutions.vals[1] = temp;
                }
                var i: usize = 0;
                while (i < solutions.count and result.count < 2) {
                    const percent = solutions.vals[i];
                    if (percent >= 0 and percent <= 1) {
                        const x_val = self.p[0].x + (2 * percent * segment_1.x) + (percent * percent * segment_12_diff.x);
                        switch (POINT_MODE) {
                            .axis_only => {
                                result.intersections[result.count].point = x_val;
                            },
                            .point => {
                                result.intersections[result.count].point.x = x_val;
                                result.intersections[result.count].point.y = y_value;
                            },
                        }
                        const y_change = segment_1.y + (percent * segment_12_diff.y);
                        if (MathX.upgrade_multiply(next_slope_sign, y_change) >= 0) {
                            switch (SLOPE_MODE) {
                                .exact => {
                                    result.intersections[result.count].slope = num_cast(y_change / (segment_1.x + (percent * segment_12_diff.x)), SLOPE_TYPE);
                                },
                                .sign => {
                                    result.intersections[result.count].slope = next_slope_sign;
                                },
                            }
                            next_slope_sign = -next_slope_sign;
                            result.count += 1;
                        }
                    }
                    i += 1;
                }
            }
            if (self.p[2].y == y_value) {
                if (next_slope_sign > 0 and result.count > 0) {
                    result.count -= 1;
                    next_slope_sign = -1;
                }
                if ((self.p[2].y < self.p[1].y or (self.p[2].y == self.p[1].y and self.p[2].y < self.p[0].y)) and result.count < 2) {
                    switch (POINT_MODE) {
                        .axis_only => {
                            result.intersections[result.count].point = self.p[2].x;
                        },
                        .point => {
                            result.intersections[result.count].point.x = self.p[2].x;
                            result.intersections[result.count].point.y = y_value;
                        },
                    }
                    if (next_slope_sign < 0) {
                        switch (SLOPE_MODE) {
                            .exact => {
                                result.intersections[result.count].slope = num_cast(self.tangent(1).slope(), SLOPE_TYPE);
                            },
                            .sign => {
                                result.intersections[result.count].slope = -1;
                            },
                        }
                        result.count += 1;
                        next_slope_sign = 1;
                    }
                }
            }
            if (next_slope_sign != if (y_value >= self.p[2].y) @as(SLOPE_TYPE, 1) else @as(SLOPE_TYPE, -1)) {
                if (result.count > 0) {
                    result.count -= 1;
                } else {
                    if (@abs(self.p[2].y - y_value) < @abs(self.p[0].y - y_value)) {
                        switch (POINT_MODE) {
                            .axis_only => {
                                result.intersections[result.count].point = self.p[2].x;
                            },
                            .point => {
                                result.intersections[result.count].point.x = self.p[2].x;
                                result.intersections[result.count].point.y = y_value;
                            },
                        }
                    }
                    switch (SLOPE_MODE) {
                        .exact => {
                            result.intersections[result.count].slope = num_cast(self.tangent(1).slope(), SLOPE_TYPE);
                        },
                        .sign => {
                            result.intersections[result.count].slope = next_slope_sign;
                        },
                    }
                    result.count += 1;
                }
            }
            return result;
        }
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB) void {
            aabb.* = aabb.combine_with_point(self.p[0]);
            aabb.* = aabb.combine_with_point(self.p[2]);
            const seg_1 = self.p[1].subtract(self.p[0]);
            const seg_2 = self.p[2].subtract(self.p[1]);
            const bot = seg_1.subtract(seg_2);
            if (bot.x != 0) {
                const percent = seg_1.x / bot.x;
                if (percent > 0 and percent < 1) {
                    aabb.* = aabb.combine_with_point(self.lerp(percent));
                }
            }
            if (bot.y != 0) {
                const percent = seg_1.y / bot.y;
                if (percent > 0 and percent < 1) {
                    aabb.* = aabb.combine_with_point(self.lerp(percent));
                }
            }
        }
        pub fn add_rough_bounds_to_aabb(self: Self, aabb: *AABB) void {
            aabb.* = aabb.combine_with_point(self.p[0]);
            aabb.* = aabb.combine_with_point(self.p[1]);
            aabb.* = aabb.combine_with_point(self.p[2]);
        }
        pub fn move_start_point(self: *Self, new_start: Vector) void {
            const original_p0_minus_p1 = self.p[0].subtract(self.p[1]);
            const original_p1 = self.p[1];
            const new_start_delta = new_start.subtract(self.p[0]);
            const seg_2_delta = self.p[2].subtract(self.p[1]);
            self.p[1] += seg_2_delta.scale(original_p0_minus_p1.cross(new_start_delta) / original_p0_minus_p1.cross(seg_2_delta));
            self.p[0] = new_start;
            const current_p0_minus_p1 = self.p[0].subtract(self.p[1]);
            if (original_p0_minus_p1.dot(current_p0_minus_p1) < 0) {
                self.p[1] = original_p1;
            }
        }
        pub fn move_end_point(self: *Self, new_end: Vector) void {
            const original_p2_minus_p1 = self.p[2].subtract(self.p[1]);
            const original_p1 = self.p[1];
            const new_end_delta = new_end.subtract(self.p[2]);
            const p0_minus_p1 = self.p[0].subtract(self.p[1]);
            self.p[1] += p0_minus_p1.scale(original_p2_minus_p1.cross(new_end_delta) / original_p2_minus_p1.cross(p0_minus_p1));
            self.p[2] = new_end;
            const current_p2_minus_p1 = self.p[2].subtract(self.p[1]);
            if (original_p2_minus_p1.dot(current_p2_minus_p1) < 0) {
                self.p[1] = original_p1;
            }
        }
        pub fn split_in_thirds(self: Self) [3]Self {
            const frac_1_3: Vector.F = 1.0 / 3.0;
            const frac_2_3: Vector.F = 2.0 / 3.0;
            const frac_1_2: Vector.F = 1.0 / 2.0;
            const frac_5_9: Vector.F = 5.0 / 9.0;
            const frac_4_9: Vector.F = 4.0 / 9.0;
            const p_1_3 = self.lerp(frac_1_3);
            const p_2_3 = self.lerp(frac_2_3);
            const seg_1__5_9 = self.p[0].lerp(self.p[1], frac_5_9);
            const seg_2__4_9 = self.p[1].lerp(self.p[2], frac_4_9);
            const c_1 = self.p[0].lerp(self.p[1], frac_1_3);
            const c_2 = seg_1__5_9.lerp(seg_2__4_9, frac_1_2);
            const c_3 = self.p[1].lerp(self.p[2], frac_2_3);
            return [3]Self{
                Self.new(self.p[0], c_1, p_1_3),
                Self.new(p_1_3, c_2, p_2_3),
                Self.new(p_2_3, c_3, self.p[2]),
            };
        }
    };
}

pub fn CubicBezier(comptime T: type) type {
    return struct {
        const Self = @This();
        const Matrix = Mat3x3.define_matrix_3x3_type(T);
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        p: [4]Vector,

        pub fn change_base_type(self: Self, comptime TT: type) CubicBezier(TT) {
            return CubicBezier(TT){ .p = .{
                self.p[0].to_new_type(TT),
                self.p[1].to_new_type(TT),
                self.p[2].to_new_type(TT),
                self.p[3].to_new_type(TT),
            } };
        }

        pub fn get_start(self: Self) Vector {
            return self.p[0];
        }
        pub fn get_control_1(self: Self) Vector {
            return self.p[1];
        }
        pub fn get_control_2(self: Self) Vector {
            return self.p[2];
        }
        pub fn get_end(self: Self) Vector {
            return self.p[3];
        }
        pub fn get_points(self: *Self) []Vector {
            return self.p[0..];
        }

        pub fn new(start: Vector, control_1: Vector, control_2: Vector, end: Vector) Self {
            return Self{ .p = .{ start, control_1, control_2, end } };
        }

        pub fn delta(self: Self) Vector {
            return self.p[3].subtract(self.p[0]);
        }

        pub fn lerp(self: Self, percent: T) Vector {
            return Vector.cubic_interp(self.p[0], self.p[1], self.p[2], self.p[3], percent);
        }
        pub fn translate(self: Self, vec: Vector) Self {
            return .new(
                self.p[0].add(vec),
                self.p[1].add(vec),
                self.p[2].add(vec),
                self.p[3].add(vec),
            );
        }
        pub fn scale(self: Self, vec: Vector) Self {
            return .new(
                self.p[0].multiply(vec),
                self.p[1].multiply(vec),
                self.p[2].multiply(vec),
                self.p[3].multiply(vec),
            );
        }
        pub fn transformed(self: Self, transform: TransformNoAlter(T)) Self {
            return switch (transform) {
                .NONE => self,
                .STEPS => |s| self.apply_complex_transform(s),
                .MATRIX => |m| self.apply_affine_transform_matrix(m),
            };
        }
        pub fn apply_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return .new(
                self.p[0].apply_complex_transform(steps),
                self.p[1].apply_complex_transform(steps),
                self.p[2].apply_complex_transform(steps),
                self.p[3].apply_complex_transform(steps),
            );
        }
        pub fn apply_inverse_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return .new(
                self.p[0].apply_inverse_complex_transform(steps),
                self.p[1].apply_inverse_complex_transform(steps),
                self.p[2].apply_inverse_complex_transform(steps),
                self.p[3].apply_inverse_complex_transform(steps),
            );
        }
        pub fn apply_affine_transform_matrix(self: Self, matrix: Matrix) Self {
            return .new(
                self.p[0].apply_affine_matrix_transform(matrix),
                self.p[1].apply_affine_matrix_transform(matrix),
                self.p[2].apply_affine_matrix_transform(matrix),
                self.p[3].apply_affine_matrix_transform(matrix),
            );
        }

        pub fn tangent(self: Self, percent: T) Vector {
            const dir_12 = self.p[1].subtract(self.p[0]);
            const dir_23 = self.p[2].subtract(self.p[1]);
            const dir_34 = self.p[3].subtract(self.p[2]);
            const tangent_ = dir_12.quadratic_interp(dir_23, dir_34, percent);
            if (tangent_.is_zero()) {
                if (percent == 0) return self.p[2].subtract(self.p[0]);
                if (percent == 1) return self.p[3].subtract(self.p[1]);
            }
            return tangent_;
        }

        pub fn tangent_change(self: Self, percent: T) Vector {
            const change_123 = (self.p[2].subtract(self.p[1])).subtract(self.p[1].subtract(self.p[0]));
            const change_234 = (self.p[3].subtract(self.p[2])).subtract(self.p[2].subtract(self.p[1]));
            return change_123.lerp(change_234, percent);
        }

        pub fn length(self: Self) T {
            _ = self;
            assert_unreachable(@src(), "not implemented", .{});
        }
        pub fn length_estimate(self: Self, steps: u32) T {
            const self_float = if (!Types.type_is_float(T)) self.change_base_type(Vector.F) else self;
            const step: Vector.F = 1.0 / MathX.convert_number(steps, Vector.F);
            var i: u32 = 0;
            var s: Vector.F = 0;
            var total: Vector.F = 0;
            var last = self_float.p[0];
            var curr = self_float.p[0];
            var delta_ = self_float.p[0];
            const steps_minus_1 = steps - 1;
            while (i < steps_minus_1) {
                i += 1;
                s += step;
                curr = self_float.lerp(s);
                delta_ = curr.subtract(last);
                total += delta_.length();
                last = curr;
            }
            delta_ = self.p[3].subtract(last);
            total += delta_.length();
            return MathX.convert_number(total, T);
        }

        pub fn minimum_signed_distance_from_point_estimate(self: Self, point: Vector, comptime estimate_steps: comptime_int) SignedDistanceWithPercent(T) {
            const point_to_start_delta = self.p[0].subtract(point);
            const segment_1_delta = self.p[1].subtract(self.p[0]);
            const segment_2_delta = self.p[2].subtract(self.p[1]);
            const segment_3_delta = self.p[3].subtract(self.p[2]);
            const segment_d1_d2_delta = segment_2_delta.subtract(segment_1_delta);
            const segment_d2_d3_delta = segment_3_delta.subtract(segment_2_delta);
            const segment_dd12_dd23_delta = segment_d2_d3_delta.subtract(segment_d1_d2_delta);
            const start_tangent = self.tangent(0);
            // set min distance to distance from first point
            const point_to_start_delta_length = point_to_start_delta.length();
            var min_distance = MathX.sign_nonzero(start_tangent.cross(point_to_start_delta)) * point_to_start_delta_length;
            var percent = (-point_to_start_delta.dot(start_tangent)) / start_tangent.dot_self();
            var end_tangent: Vector = undefined;
            var point_to_end_delta: Vector = undefined;
            var point_to_end_delta_length: T = undefined;
            {
                // check if point is actually closer to last point and update vals
                point_to_end_delta = self.p[3].subtract(point);
                point_to_end_delta_length = point_to_end_delta.length();
                if (point_to_end_delta_length < @abs(min_distance)) {
                    end_tangent = self.tangent(1);
                    min_distance = MathX.sign_nonzero(end_tangent.cross(point_to_end_delta)) * point_to_end_delta_length;
                    const point_to_end_delta_to_end_tangent_delta = end_tangent.subtract(point_to_end_delta);
                    percent = point_to_end_delta_to_end_tangent_delta.dot(end_tangent) / end_tangent.dot_self();
                }
            }
            const STEP = @as(T, 1) / @as(T, @floatFromInt(estimate_steps));
            for (0..estimate_steps) |i| {
                var t = STEP * @as(T, @floatFromInt(i));
                const t_squared = t * t;
                const t_cubed = t_squared * t;
                const t_3 = t * 3;
                const t_6 = t_3 * 2;
                const t_squared_3 = t_squared * 3;
                var point_to_current_lerp_delta = point_to_start_delta.add_scale(segment_1_delta, t_3).add_scale(segment_d1_d2_delta, t_squared_3).add_scale(segment_dd12_dd23_delta, t_cubed);
                var calc_delta_1 = segment_1_delta.scale(3).add_scale(segment_d1_d2_delta, t_6).add_scale(segment_dd12_dd23_delta, t_squared_3);
                var calc_delta_2 = segment_d1_d2_delta.scale(6).add_scale(segment_dd12_dd23_delta, t_6);
                var better_min_dist_percent = t - (point_to_current_lerp_delta.dot(calc_delta_1) / (calc_delta_1.dot_self() + point_to_current_lerp_delta.dot(calc_delta_2)));
                if (better_min_dist_percent > 0 and better_min_dist_percent < 1) {
                    var remaining_steps: usize = estimate_steps;
                    while (better_min_dist_percent > 0 and better_min_dist_percent < 1) {
                        t = better_min_dist_percent;
                        point_to_current_lerp_delta = point_to_start_delta.add_scale(segment_1_delta, t_3).add_scale(segment_d1_d2_delta, t_squared_3).add_scale(segment_dd12_dd23_delta, t_cubed);
                        calc_delta_1 = segment_1_delta.scale(3).add_scale(segment_d1_d2_delta, t_6).add_scale(segment_dd12_dd23_delta, t_squared_3);
                        if (remaining_steps <= 0) {
                            break;
                        }
                        remaining_steps -= 1;
                        calc_delta_2 = segment_d1_d2_delta.scale(6).add_scale(segment_dd12_dd23_delta, t_6);
                        better_min_dist_percent = t - (point_to_current_lerp_delta.dot(calc_delta_1) / (calc_delta_1.dot_self() + point_to_current_lerp_delta.dot(calc_delta_2)));
                    }
                    const point_to_current_lerp_distance = point_to_current_lerp_delta.length();
                    if (point_to_current_lerp_distance < @abs(min_distance)) {
                        min_distance = MathX.sign_nonzero(calc_delta_1.cross(point_to_current_lerp_delta)) * point_to_current_lerp_distance;
                        percent = t;
                    }
                }
            }
            if (percent >= 0 and percent <= 1) {
                return SignedDistanceWithPercent(T).new(min_distance, 0, percent);
            }
            if (percent < 0.5) {
                // percent < 0
                return SignedDistanceWithPercent(T).new(min_distance, @abs(start_tangent.normalize().dot(point_to_start_delta.normalize_using_length(point_to_start_delta_length))), percent);
            } else {
                // percent > 1
                return SignedDistanceWithPercent(T).new(min_distance, @abs(end_tangent.normalize().dot(point_to_end_delta.normalize_using_length(point_to_end_delta_length))), percent);
            }
        }
        pub fn reverse(self: *Self) void {
            const tmp_1 = self.p[3];
            const tmp_2 = self.p[2];
            self.p[3] = self.p[0];
            self.p[2] = self.p[1];
            self.p[0] = tmp_1;
            self.p[1] = tmp_2;
        }
        pub fn horizontal_intersections(self: Self, y_value: T, comptime POINT_MODE: MathX.ScanlinePointMode, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type, double_root_estimate: DoubleRootEstimate(T), quadratic_estimate: QuadraticEstimate(T), linear_estimate: LinearEstimate(T)) ScanlineIntersections(3, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE) {
            var result = ScanlineIntersections(3, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE){};
            var next_slope_sign: SLOPE_TYPE = if (y_value > self.p[0].y) 1 else -1;
            switch (POINT_MODE) {
                .axis_only => {
                    result.intersections[result.count].point = self.p[0].x;
                },
                .point => {
                    result.intersections[result.count].point.x = self.p[0].x;
                    result.intersections[result.count].point.y = y_value;
                },
            }
            if (self.p[0].y == y_value) {
                if (self.p[0].y < self.p[1].y or (self.p[0].y == self.p[1].y and (self.p[0].y < self.p[2].y or (self.p[0].y == self.p[2].y and self.p[0].y < self.p[3].y)))) {
                    switch (SLOPE_MODE) {
                        .exact => {
                            result.intersections[result.count].slope = num_cast(self.tangent(0).slope(), SLOPE_TYPE);
                        },
                        .sign => {
                            result.intersections[result.count].slope = 1;
                        },
                    }
                    result.count += 1;
                } else {
                    next_slope_sign = 1;
                }
            }
            {
                const segment_1 = self.p[1].subtract(self.p[0]);
                const segment_2 = self.p[2].subtract(self.p[1]);
                const segment_3 = self.p[3].subtract(self.p[2]);
                const segment_12_diff = segment_2.subtract(segment_1);
                const segment_23_diff = segment_3.subtract(segment_2);
                const segment_12d_23d_diff = segment_23_diff.subtract(segment_12_diff);
                var solutions = MathX.solve_cubic_polynomial_for_zeros_advanced(segment_12d_23d_diff.y, 3 * segment_12_diff.y, 3 * segment_1.y, self.p[0].y - y_value, double_root_estimate, quadratic_estimate, linear_estimate);
                solutions.sort_by_val_small_to_large();
                var i: usize = 0;
                while (i < solutions.count and result.count < 3) {
                    i += 1;
                    const percent = solutions.vals[i];
                    const percent_squared = percent * percent;
                    const percent_cubed = percent_squared * percent;
                    if (percent >= 0 and percent <= 1) {
                        switch (POINT_MODE) {
                            .axis_only => {
                                result.intersections[result.count].point = self.p[0].x + (3 * percent * segment_1.x) + (3 * percent_squared * segment_12_diff.x) + (percent_cubed * segment_12d_23d_diff.x);
                            },
                            .point => {
                                result.intersections[result.count].point.x = self.p[0].x + (3 * percent * segment_1.x) + (3 * percent_squared * segment_12_diff.x) + (percent_cubed * segment_12d_23d_diff.x);
                                result.intersections[result.count].point.y = y_value;
                            },
                        }
                        if (MathX.upgrade_multiply(next_slope_sign, (segment_1.y + (2 * percent * segment_12_diff.y) + (percent_squared * segment_12d_23d_diff.y))) >= 0) {
                            switch (SLOPE_MODE) {
                                .exact => {
                                    result.intersections[result.count].slope = num_cast(self.tangent(percent).slope(), SLOPE_TYPE);
                                },
                                .sign => {
                                    result.intersections[result.count].slope = next_slope_sign;
                                },
                            }
                            result.count += 1;
                            next_slope_sign = -next_slope_sign;
                        }
                    }
                }
            }
            if (self.p[3].y == y_value) {
                if (next_slope_sign > 0 and result.count > 0) {
                    result.count -= 1;
                    next_slope_sign = -1;
                }
                if ((self.p[3].y < self.p[2].y or (self.p[3].y == self.p[2].y and (self.p[3].y < self.p[1].y or (self.p[3].y == self.p[1].y and self.p[3].y < self.p[0].y)))) and result.count < 3) {
                    switch (POINT_MODE) {
                        .axis_only => {
                            result.intersections[result.count].point = self.p[3].x;
                        },
                        .point => {
                            result.intersections[result.count].point.x = self.p[3].x;
                            result.intersections[result.count].point.y = y_value;
                        },
                    }
                    if (next_slope_sign < 0) {
                        switch (SLOPE_MODE) {
                            .exact => {
                                result.intersections[result.count].slope = num_cast(self.tangent(1).slope(), SLOPE_TYPE);
                            },
                            .sign => {
                                result.intersections[result.count].slope = -1;
                            },
                        }
                        result.count += 1;
                        next_slope_sign = 1;
                    }
                }
            }
            if (next_slope_sign != if (y_value >= self.p[3].y) @as(SLOPE_TYPE, 1) else @as(SLOPE_TYPE, -1)) {
                if (result.count > 0) {
                    result.count -= 1;
                } else {
                    if (@abs(self.p[3].y - y_value) < @abs(self.p[0].y - y_value)) {
                        switch (POINT_MODE) {
                            .axis_only => {
                                result.intersections[result.count].point = self.p[3].x;
                            },
                            .point => {
                                result.intersections[result.count].point.x = self.p[3].x;
                                result.intersections[result.count].point.y = y_value;
                            },
                        }
                    }
                    switch (SLOPE_MODE) {
                        .exact => {
                            result.intersections[result.count].slope = num_cast(self.tangent(1).slope(), SLOPE_TYPE);
                        },
                        .sign => {
                            result.intersections[result.count].slope = next_slope_sign;
                        },
                    }
                    result.count += 1;
                }
            }
            return result;
        }
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB, linear_estimate: LinearEstimate(T)) void {
            aabb.* = aabb.combine_with_point(self.p[0]);
            aabb.* = aabb.combine_with_point(self.p[3]);
            const seg_1 = self.p[1].subtract(self.p[0]);
            const seg_2 = self.p[2].subtract(self.p[1]);
            const seg_12_diff = seg_2.subtract(seg_1);
            const seg_12_diff_2 = seg_12_diff.scale(2);
            const vec_a = self.p[3].subtract_scale(self.p[2], 3).add_scale(self.p[1], 3).subtract(self.p[0]);
            const vec_b = seg_12_diff_2;
            const vec_c = seg_1;
            const x_solutions = MathX.solve_quadratic_polynomial_for_zeros_advanced(vec_a.x, vec_b.x, vec_c.x, linear_estimate);
            for (x_solutions.vals[0..x_solutions.count]) |percent| {
                if (percent > 0 and percent < 1) {
                    aabb.* = aabb.combine_with_point(self.lerp(percent));
                }
            }
            const y_solutions = MathX.solve_quadratic_polynomial_for_zeros_advanced(vec_a.y, vec_b.y, vec_c.y, linear_estimate);
            for (y_solutions.vals[0..y_solutions.count]) |percent| {
                if (percent > 0 and percent < 1) {
                    aabb.* = aabb.combine_with_point(self.lerp(percent));
                }
            }
        }
        pub fn move_start_point(self: *Self, new_start: Vector) void {
            self.p[1] = self.p[1].add(new_start.subtract(self.p[0]));
            self.p[0] = new_start;
        }
        pub fn move_end_point(self: *Self, new_end: Vector) void {
            self.p[2] = self.p[2].add(new_end.subtract(self.p[3]));
            self.p[3] = new_end;
        }
        pub fn split_in_thirds(self: Self) [3]Self {
            const frac_1_3: Vector.F = 1.0 / 3.0;
            const frac_2_3: Vector.F = 2.0 / 3.0;
            const seg_1_one_third = self.p[0].lerp(self.p[1], frac_1_3);
            const seg_1_two_third = self.p[0].lerp(self.p[1], frac_2_3);
            const seg_2_one_third = self.p[1].lerp(self.p[2], frac_1_3);
            const seg_2_two_third = self.p[1].lerp(self.p[2], frac_2_3);
            const seg_3_one_third = self.p[2].lerp(self.p[3], frac_1_3);
            const seg_3_two_third = self.p[2].lerp(self.p[3], frac_2_3);
            const seg_1_one_third_to_seg_2_one_third_one_third = seg_1_one_third.lerp(seg_2_one_third, frac_1_3);
            const seg_1_two_third_to_seg_2_two_third_two_third = seg_1_two_third.lerp(seg_2_two_third, frac_2_3);
            const seg_2_one_third_to_seg_3_one_third_one_third = seg_2_one_third.lerp(seg_3_one_third, frac_1_3);
            const seg_2_two_third_to_seg_3_two_third_two_third = seg_2_two_third.lerp(seg_3_two_third, frac_2_3);
            const c_1_1 = if (self.p[0].approx_equal(self.p[1])) self.p[0] else seg_1_one_third;
            const c_1_2 = seg_1_one_third_to_seg_2_one_third_one_third;
            const p_one_third = self.lerp(frac_1_3);
            const c_2_1 = seg_1_one_third_to_seg_2_one_third_one_third.lerp(seg_2_one_third_to_seg_3_one_third_one_third, frac_2_3);
            const c_2_2 = seg_1_two_third_to_seg_2_two_third_two_third.lerp(seg_2_two_third_to_seg_3_two_third_two_third, frac_1_3);
            const p_two_third = self.lerp(frac_2_3);
            const c_3_1 = seg_2_two_third_to_seg_3_two_third_two_third;
            const c_3_2 = if (self.p[2].approx_equal(self.p[3])) self.p[3] else seg_3_two_third;
            return [3]Self{
                Self.new(self.p[0], c_1_1, c_1_2, p_one_third),
                Self.new(p_one_third, c_2_1, c_2_2, p_two_third),
                Self.new(p_two_third, c_3_1, c_3_2, self.p[3]),
            };
        }
    };
}

pub fn EdgeNoUserdata(comptime T: type) type {
    return EdgeWithUserdata(T, void, void{});
}

pub fn EdgeWithUserdata(comptime T: type, comptime USERDATA: type, comptime USERDATA_DEFAULT_ZERO: USERDATA) type {
    return struct {
        const Self = @This();
        const Matrix = Mat3x3.define_matrix_3x3_type(T);
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);
        const EDGE = Edge(T);

        edge: EDGE = .new_point(.ZERO_ZERO),
        userdata: USERDATA = USERDATA_DEFAULT_ZERO,

        pub inline fn new_point(p: Vector) Self {
            return Self{ .edge = .new_point(p) };
        }

        pub inline fn new_line(p1: Vector, p2: Vector) Self {
            return Self{ .edge = .new_line(p1, p2) };
        }

        pub inline fn new_quadratic_bezier(p1: Vector, p2: Vector, p3: Vector) Self {
            return Self{ .edge = .new_quadratic_bezier(p1, p2, p3) };
        }

        pub inline fn new_cubic_bezier(p1: Vector, p2: Vector, p3: Vector, p4: Vector) Self {
            return Self{ .edge = .new_cubic_bezier(p1, p2, p3, p4) };
        }

        pub fn change_base_type(self: Self, comptime TT: type) EdgeWithUserdata(TT) {
            return EdgeWithUserdata(TT){
                .edge = self.edge.change_base_type(TT),
                .userdata = self.userdata,
            };
        }

        pub fn get_start(self: Self) Vector {
            return self.edge.get_start();
        }
        pub fn get_control_1(self: Self) Vector {
            return self.edge.get_control_1();
        }
        pub fn get_control_2(self: Self) Vector {
            return self.edge.get_control_2();
        }
        pub fn get_end(self: Self) Vector {
            return self.edge.get_end();
        }
        pub fn get_points(self: *Self) []Vector {
            return self.edge.get_points();
        }

        pub fn delta(self: Self) Vector {
            return self.edge.delta();
        }

        pub fn lerp(self: Self, percent: anytype) Vector {
            return self.edge.lerp(percent);
        }
        pub fn translate(self: Self, vec: Vector) Self {
            return Self{ .edge = self.edge.translate(vec), .userdata = self.userdata };
        }
        pub fn scale(self: Self, vec: Vector) Self {
            return Self{ .edge = self.edge.scale(vec), .userdata = self.userdata };
        }
        pub fn apply_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return Self{ .edge = self.edge.apply_complex_transform(steps), .userdata = self.userdata };
        }
        pub fn apply_inverse_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return Self{ .edge = self.edge.apply_inverse_complex_transform(steps), .userdata = self.userdata };
        }
        pub fn apply_affine_transform_matrix(self: Self, matrix: Matrix) Self {
            return Self{ .edge = self.edge.apply_affine_transform_matrix(matrix), .userdata = self.userdata };
        }
        pub fn transformed(self: Self, transform: TransformNoAlter(T)) Self {
            return Self{ .edge = self.edge.transformed(transform), .userdata = self.userdata };
        }

        pub fn tangent(self: Self, percent: anytype) Vector {
            return self.edge.tangent(percent);
        }

        pub fn tangent_change(self: Self, percent: anytype) Vector {
            return self.edge.tangent_change(percent);
        }

        pub fn length(self: Self) T {
            return self.edge.length();
        }
        pub fn length_estimate(self: Self, steps: u32) T {
            return self.edge.length_estimate(steps);
        }

        pub fn minimum_signed_distance_from_point(self: Self, point: Vector, comptime estimate_steps_for_cubic: comptime_int) SignedDistanceWithPercent(T) {
            return self.edge.minimum_signed_distance_from_point(point, estimate_steps_for_cubic);
        }
        pub fn reverse(self: *Self) void {
            return self.edge.reverse();
        }
        pub fn horizontal_intersections(self: Self, y_value: T, comptime POINT_MODE: MathX.ScanlinePointMode, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type, estimates: Estimates(T)) ScanlineIntersections(3, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE) {
            return self.edge.horizontal_intersections(y_value, POINT_MODE, SLOPE_MODE, SLOPE_TYPE, estimates);
        }
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB, linear_estimate: LinearEstimate(T)) void {
            self.edge.add_bounds_to_aabb(aabb, linear_estimate);
        }
        pub fn move_start_point(self: *Self, new_start: Vector) void {
            self.edge.move_start_point(new_start);
        }
        pub fn move_end_point(self: *Self, new_end: Vector) void {
            self.edge.move_end_point(new_end);
        }
        pub fn split_in_thirds(self: Self) [3]Self {
            const thirds = self.edge.split_in_thirds();
            return [3]Self{
                Self{ .edge = thirds[0], .userdata = self.userdata },
                Self{ .edge = thirds[1], .userdata = self.userdata },
                Self{ .edge = thirds[2], .userdata = self.userdata },
            };
        }

        pub fn signed_dist_to_perpendicular_dist(self: Self, signed_dist: SignedDistanceWithPercent(T), point: Vector) SignedDistanceWithPercent(T) {
            return self.edge.signed_dist_to_perpendicular_dist(signed_dist, point);
        }

        pub fn kind(self: Self) EdgeKind {
            return self.edge;
        }

        pub fn simplify_degenerate_edge(self: *Self, epsilon: T) void {
            self.edge.simplify_degenerate_edge(epsilon);
        }

        /// For edges a and b converging at P = a.get_end() = b.get_start() with the same (opposite) tangent,
        /// determines the relative ordering in which they exit P
        ///
        /// (i.e. whether a is to the left or right of b at the smallest positive radius around P)
        pub fn convergent_curve_ordering(a: *Self, b: *Self) i8 {
            return a.edge.convergent_curve_ordering(b);
        }

        pub fn deconverge_edge(self: *Self, cubic_control_segment: u1, vector: Vector) void {
            self.edge.deconverge_edge(cubic_control_segment, vector);
        }

        pub fn swap_with(self: *Self, other: *Self) void {
            const tmp = self.*;
            self.* = other.*;
            other.* = tmp;
        }
    };
}

pub fn Edge(comptime T: type) type {
    return union(EdgeKind) {
        const Self = @This();
        const Matrix = Mat3x3.define_matrix_3x3_type(T);
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        POINT: Point(T),
        LINE: Line(T),
        QUADRATIC_BEZIER: QuadraticBezier(T),
        CUBIC_BEZIER: CubicBezier(T),

        pub inline fn new_point(p: Vector) Self {
            return Self{ .POINT = .new(p) };
        }

        pub inline fn new_line(p1: Vector, p2: Vector) Self {
            return Self{ .LINE = .new(p1, p2) };
        }

        pub inline fn new_quadratic_bezier(p1: Vector, p2: Vector, p3: Vector) Self {
            return Self{ .QUADRATIC_BEZIER = .new(p1, p2, p3) };
        }

        pub inline fn new_cubic_bezier(p1: Vector, p2: Vector, p3: Vector, p4: Vector) Self {
            return Self{ .CUBIC_BEZIER = .new(p1, p2, p3, p4) };
        }

        pub fn change_base_type(self: Self, comptime TT: type) Edge(TT) {
            return switch (self.*) {
                .POINT => Edge(TT).new_point(self.POINT.change_base_type(TT)),
                .LINE => Edge(TT).new_point(self.LINE.change_base_type(TT)),
                .QUADRATIC_BEZIER => Edge(TT).new_point(self.QUADRATIC_BEZIER.change_base_type(TT)),
                .CUBIC_BEZIER => Edge(TT).new_point(self.CUBIC_BEZIER.change_base_type(TT)),
            };
        }

        pub fn get_start(self: Self) Vector {
            return switch (self) {
                .POINT => self.POINT.get_start(),
                .LINE => self.LINE.get_start(),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.get_start(),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.get_start(),
            };
        }
        pub fn get_control_1(self: Self) Vector {
            return switch (self) {
                .POINT => self.POINT.get_start(),
                .LINE => self.LINE.get_start(),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.get_control(),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.get_control_1(),
            };
        }
        pub fn get_control_2(self: Self) Vector {
            return switch (self) {
                .POINT => self.POINT.get_start(),
                .LINE => self.LINE.get_end(),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.get_control(),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.get_control_2(),
            };
        }
        pub fn get_end(self: Self) Vector {
            return switch (self) {
                .POINT => self.POINT.get_end(),
                .LINE => self.LINE.get_end(),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.get_end(),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.get_end(),
            };
        }
        pub fn get_points(self: *Self) []Vector {
            return switch (self.*) {
                .POINT => self.POINT.get_points(),
                .LINE => self.LINE.get_points(),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.get_points(),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.get_points(),
            };
        }

        pub fn delta(self: Self) Vector {
            return switch (self) {
                .POINT => self.POINT.delta(),
                .LINE => self.LINE.delta(),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.delta(),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.delta(),
            };
        }

        pub fn lerp(self: Self, percent: anytype) Vector {
            return switch (self) {
                .POINT => self.POINT.lerp(percent),
                .LINE => self.LINE.lerp(percent),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.lerp(percent),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.lerp(percent),
            };
        }
        pub fn translate(self: Self, vec: Vector) Self {
            return switch (self) {
                .POINT => Self{ .POINT = self.POINT.translate(vec) },
                .LINE => Self{ .LINE = self.LINE.translate(vec) },
                .QUADRATIC_BEZIER => Self{ .QUADRATIC_BEZIER = self.QUADRATIC_BEZIER.translate(vec) },
                .CUBIC_BEZIER => Self{ .CUBIC_BEZIER = self.CUBIC_BEZIER.translate(vec) },
            };
        }
        pub fn scale(self: Self, vec: Vector) Self {
            return switch (self) {
                .POINT => Self{ .POINT = self.POINT.scale(vec) },
                .LINE => Self{ .LINE = self.LINE.scale(vec) },
                .QUADRATIC_BEZIER => Self{ .QUADRATIC_BEZIER = self.QUADRATIC_BEZIER.scale(vec) },
                .CUBIC_BEZIER => Self{ .CUBIC_BEZIER = self.CUBIC_BEZIER.scale(vec) },
            };
        }
        pub fn apply_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return switch (self) {
                .POINT => Self{ .POINT = self.POINT.apply_complex_transform(steps) },
                .LINE => Self{ .LINE = self.LINE.apply_complex_transform(steps) },
                .QUADRATIC_BEZIER => Self{ .QUADRATIC_BEZIER = self.QUADRATIC_BEZIER.apply_complex_transform(steps) },
                .CUBIC_BEZIER => Self{ .CUBIC_BEZIER = self.CUBIC_BEZIER.apply_complex_transform(steps) },
            };
        }
        pub fn apply_inverse_complex_transform(self: Self, steps: []const Vector.TransformStep) Self {
            return switch (self) {
                .POINT => Self{ .POINT = self.POINT.apply_inverse_complex_transform(steps) },
                .LINE => Self{ .LINE = self.LINE.apply_inverse_complex_transform(steps) },
                .QUADRATIC_BEZIER => Self{ .QUADRATIC_BEZIER = self.QUADRATIC_BEZIER.apply_inverse_complex_transform(steps) },
                .CUBIC_BEZIER => Self{ .CUBIC_BEZIER = self.CUBIC_BEZIER.apply_inverse_complex_transform(steps) },
            };
        }
        pub fn apply_affine_transform_matrix(self: Self, matrix: Matrix) Self {
            return switch (self) {
                .POINT => Self{ .POINT = self.POINT.apply_affine_transform_matrix(matrix) },
                .LINE => Self{ .LINE = self.LINE.apply_affine_transform_matrix(matrix) },
                .QUADRATIC_BEZIER => Self{ .QUADRATIC_BEZIER = self.QUADRATIC_BEZIER.apply_affine_transform_matrix(matrix) },
                .CUBIC_BEZIER => Self{ .CUBIC_BEZIER = self.CUBIC_BEZIER.apply_affine_transform_matrix(matrix) },
            };
        }
        pub fn transformed(self: Self, transform: TransformNoAlter(T)) Self {
            return switch (self) {
                .POINT => Self{ .POINT = self.POINT.transformed(transform) },
                .LINE => Self{ .LINE = self.LINE.transformed(transform) },
                .QUADRATIC_BEZIER => Self{ .QUADRATIC_BEZIER = self.QUADRATIC_BEZIER.transformed(transform) },
                .CUBIC_BEZIER => Self{ .CUBIC_BEZIER = self.CUBIC_BEZIER.transformed(transform) },
            };
        }

        pub fn tangent(self: Self, percent: anytype) Vector {
            return switch (self) {
                .POINT => self.POINT.tangent(percent),
                .LINE => self.LINE.tangent(percent),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.tangent(percent),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.tangent(percent),
            };
        }

        pub fn tangent_change(self: Self, percent: anytype) Vector {
            return switch (self) {
                .POINT => self.POINT.tangent_change(percent),
                .LINE => self.LINE.tangent_change(percent),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.tangent_change(percent),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.tangent_change(percent),
            };
        }

        pub fn length(self: Self) T {
            return switch (self) {
                .POINT => self.POINT.length(),
                .LINE => self.LINE.length(),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.length(),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.length(),
            };
        }
        pub fn length_estimate(self: Self, steps: u32) T {
            return switch (self) {
                .POINT => self.POINT.length(),
                .LINE => self.LINE.length(),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.length_estimate(steps),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.length_estimate(steps),
            };
        }

        pub fn minimum_signed_distance_from_point(self: Self, point: Vector, comptime estimate_steps_for_cubic: comptime_int) SignedDistanceWithPercent(T) {
            return switch (self) {
                .POINT => self.POINT.minimum_signed_distance_from_point(point),
                .LINE => self.LINE.minimum_signed_distance_from_point(point),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.minimum_signed_distance_from_point(point),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.minimum_signed_distance_from_point_estimate(point, estimate_steps_for_cubic),
            };
        }
        pub fn reverse(self: *Self) void {
            return switch (self.*) {
                .POINT => self.POINT.reverse(),
                .LINE => self.LINE.reverse(),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.reverse(),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.reverse(),
            };
        }
        pub fn horizontal_intersections(self: Self, y_value: T, comptime POINT_MODE: MathX.ScanlinePointMode, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type, estimates: Estimates(T)) ScanlineIntersections(3, T, POINT_MODE, SLOPE_MODE, SLOPE_TYPE) {
            return switch (self) {
                .POINT => self.POINT.horizontal_intersections(y_value, POINT_MODE, SLOPE_MODE, SLOPE_TYPE).change_max_intersections(3),
                .LINE => self.LINE.horizontal_intersections(y_value, POINT_MODE, SLOPE_MODE, SLOPE_TYPE).change_max_intersections(3),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.horizontal_intersections(y_value, POINT_MODE, SLOPE_MODE, SLOPE_TYPE, estimates.linear).change_max_intersections(3),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.horizontal_intersections(y_value, POINT_MODE, SLOPE_MODE, SLOPE_TYPE, estimates.double_root, estimates.quadratic, estimates.linear),
            };
        }
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB, linear_estimate: LinearEstimate(T)) void {
            return switch (self) {
                .POINT => self.POINT.add_bounds_to_aabb(aabb),
                .LINE => self.LINE.add_bounds_to_aabb(aabb),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.add_bounds_to_aabb(aabb),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.add_bounds_to_aabb(aabb, linear_estimate),
            };
        }
        pub fn move_start_point(self: *Self, new_start: Vector) void {
            return switch (self.*) {
                .POINT => self.POINT.move_start_point(new_start),
                .LINE => self.LINE.move_start_point(new_start),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.move_start_point(new_start),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.move_start_point(new_start),
            };
        }
        pub fn move_end_point(self: *Self, new_end: Vector) void {
            return switch (self.*) {
                .POINT => self.POINT.move_end_point(new_end),
                .LINE => self.LINE.move_end_point(new_end),
                .QUADRATIC_BEZIER => self.QUADRATIC_BEZIER.move_end_point(new_end),
                .CUBIC_BEZIER => self.CUBIC_BEZIER.move_end_point(new_end),
            };
        }
        pub fn split_in_thirds(self: Self) [3]Self {
            switch (self) {
                .POINT => {
                    const thirds = self.POINT.split_in_thirds();
                    return [3]Self{ Self{ .POINT = thirds[0] }, Self{ .POINT = thirds[0] }, Self{ .POINT = thirds[0] } };
                },
                .LINE => {
                    const thirds = self.LINE.split_in_thirds();
                    return [3]Self{ Self{ .LINE = thirds[0] }, Self{ .LINE = thirds[0] }, Self{ .LINE = thirds[0] } };
                },
                .QUADRATIC_BEZIER => {
                    const thirds = self.QUADRATIC_BEZIER.split_in_thirds();
                    return [3]Self{ Self{ .QUADRATIC_BEZIER = thirds[0] }, Self{ .QUADRATIC_BEZIER = thirds[0] }, Self{ .QUADRATIC_BEZIER = thirds[0] } };
                },
                .CUBIC_BEZIER => {
                    const thirds = self.CUBIC_BEZIER.split_in_thirds();
                    return [3]Self{ Self{ .CUBIC_BEZIER = thirds[0] }, Self{ .CUBIC_BEZIER = thirds[0] }, Self{ .CUBIC_BEZIER = thirds[0] } };
                },
            }
        }

        pub fn signed_dist_to_perpendicular_dist(self: Self, signed_dist: SignedDistanceWithPercent(T), point: Vector) SignedDistanceWithPercent(T) {
            if (signed_dist.percent < 0) {
                const start_tangent_normal = self.tangent(0).normalize();
                const point_to_start_delta = point.subtract(self.get_start_point());
                const point_to_start_delta_dot_start_tangent_normal = point_to_start_delta.dot(start_tangent_normal);
                if (point_to_start_delta_dot_start_tangent_normal < 0) {
                    const perp_dist = point_to_start_delta.cross(start_tangent_normal);
                    if (@abs(perp_dist) <= @abs(signed_dist.signed_dist.distance)) {
                        return SignedDistanceWithPercent(T){
                            .signed_dist = SignedDistance(T){
                                .distance = perp_dist,
                                .dot_product = 0,
                            },
                            .percent = signed_dist.percent,
                        };
                    }
                }
            } else if (signed_dist.percent < 0) {
                const end_tangent_normal = self.tangent(1).normalize();
                const point_to_end_delta = point.subtract(self.get_end_point());
                const point_to_end_delta_dot_end_tangent_normal = point_to_end_delta.dot(end_tangent_normal);
                if (point_to_end_delta_dot_end_tangent_normal > 0) {
                    const perp_dist = point_to_end_delta.cross(end_tangent_normal);
                    if (@abs(perp_dist) <= @abs(signed_dist.signed_dist.distance)) {
                        return SignedDistanceWithPercent(T){
                            .signed_dist = SignedDistance(T){
                                .distance = perp_dist,
                                .dot_product = 0,
                            },
                            .percent = signed_dist.percent,
                        };
                    }
                }
            }
            return signed_dist;
        }

        pub fn kind(self: Self) EdgeKind {
            return self;
        }

        pub fn simplify_degenerate_edge(self: *Self, epsilon: T) void {
            recheck: switch (self.*) {
                .POINT => {},
                .LINE => |line| {
                    if (line.p[0].approx_equal_with_epsilon(line.p[1], epsilon)) {
                        self.* = .new_point(line.p[0]);
                    }
                },
                .QUADRATIC_BEZIER => |bezier| {
                    if (bezier.p[0].approx_equal_with_epsilon(bezier.p[1], epsilon) or bezier.p[1].approx_equal_with_epsilon(bezier.p[2], epsilon)) {
                        self.* = .new_linear(bezier.p[0], bezier.p[2]);
                        continue :recheck self.*;
                    }
                },
                .CUBIC_BEZIER => |bezier| {
                    if ((bezier.p[0].approx_equal_with_epsilon(bezier.p[1], epsilon) or bezier.p[1].approx_equal_with_epsilon(bezier.p[3], epsilon)) and (bezier.p[0].approx_equal_with_epsilon(bezier.p[2], epsilon) or bezier.p[2].approx_equal_with_epsilon(bezier.p[3], epsilon))) {
                        self.* = .new_linear(bezier.p[0], bezier.p[3]);
                        continue :recheck self.*;
                    }
                },
            }
        }

        fn _convergent_curve_ordering_internal(p: [8]Vector, control_points_before: usize, control_points_after: usize) i8 {
            if (!(control_points_before > 0 and control_points_before > 0)) {
                return 0;
            }
            const CORNER_IDX = 4;
            var a1: Vector = undefined;
            var a2: Vector = undefined;
            var a3: Vector = undefined;
            var b1: Vector = undefined;
            var b2: Vector = undefined;
            var b3: Vector = undefined;
            a1 = p[CORNER_IDX - 1].subtract(p[CORNER_IDX]);
            b1 = p[CORNER_IDX + 1].subtract(p[CORNER_IDX]);
            if (control_points_before >= 2) {
                a2 = p[CORNER_IDX - 1].subtract(p[CORNER_IDX - 1]).subtract(a1);
            }
            if (control_points_after >= 2) {
                b2 = p[CORNER_IDX + 2].subtract(p[CORNER_IDX + 1]).subtract(b1);
            }
            if (control_points_before >= 3) {
                a3 = p[CORNER_IDX - 3].subtract(p[CORNER_IDX - 2]).subtract(p[CORNER_IDX - 2].subtract(p[CORNER_IDX - 1])).subtract(a2);
                a2 = a2.scale(3);
            }
            if (control_points_after >= 3) {
                b3 = p[CORNER_IDX + 3].subtract(p[CORNER_IDX + 2]).subtract(p[CORNER_IDX + 2].subtract(p[CORNER_IDX + 1])).subtract(b2);
                b2 = b2.scale(3);
            }
            a1 = a1.scale(control_points_before);
            b1 = b1.scale(control_points_after);
            // Non-degenerate case
            if (a1.non_zero() and b1.non_zero()) {
                const a1_len = a1.length();
                const b1_len = b1.length();
                // Third derivative
                var d = (a1.cross(b2) * a1_len) + (a2.cross(b1) * b1_len);
                if (d != 0) {
                    return MathX.sign_convert(d, i8);
                }
                // Fourth derivative
                d = (a1.cross(b3) * a1_len * a1_len) + (a2.cross(b2) * a1_len * b1_len) + (a3.cross(b1) * b1_len * b1_len);
                if (d != 0) {
                    return MathX.sign_convert(d, i8);
                }
                // Fifth derivative
                d = (a2.cross(b3) * a1_len) + (a3.cross(b2) * b1_len);
                if (d != 0) {
                    return MathX.sign_convert(d, i8);
                }
                // Sixth derivative
                d = a3.cross(b3);
                return MathX.sign_convert(d, i8);
            }
            // Degenerate curve after corner (control point after corner equals corner)
            var s: i8 = 1;
            if (a1.non_zero()) {
                // Swap aN <-> bN and handle in if (b1)
                b1 = a1;
                a1 = b2;
                b2 = a2;
                a2 = a1;
                a1 = b3;
                b3 = a3;
                a3 = a1;
                s = -1;
            }
            // Degenerate curve before corner (control point before corner equals corner)
            if (b1.non_zero()) {
                // Two-and-a-half-th derivative
                var d = a3.cross(b1);
                if (d != 0) {
                    return s * MathX.sign_convert(d, i8);
                }
                // Third derivative
                d = a2.cross(b2);
                if (d != 0) {
                    return s * MathX.sign_convert(d, i8);
                }
                // Three-and-a-half-th derivative
                d = a3.cross(b2);
                if (d != 0) {
                    return s * MathX.sign_convert(d, i8);
                }
                // Fourth derivative
                d = a2.cross(b3);
                if (d != 0) {
                    return s * MathX.sign_convert(d, i8);
                }
                // Four-and-a-half-th derivative
                d = a3.cross(b3);
                return s * MathX.sign_convert(d, i8);
            }
            // Degenerate curves on both sides of the corner (control point before and after corner equals corner)
            // Two-and-a-half-th derivative
            var d = (@sqrt(a2.length()) * a2.cross(b3)) + (@sqrt(b2.length()) * a3.cross(b2));
            if (d != 0) {
                return MathX.sign_convert(d, i8);
            }
            // Third derivative
            d = a3.cross(b3);
            return MathX.sign_convert(d, i8);
        }
        /// For edges a and b converging at P = a.get_end() = b.get_start() with the same (opposite) tangent,
        /// determines the relative ordering in which they exit P
        ///
        /// (i.e. whether a is to the left or right of b at the smallest positive radius around P)
        pub fn convergent_curve_ordering(a: *Self, b: *Self) i8 {
            var points: [8]Point = undefined;
            const CORNER_IDX = 4;
            if (a.kind() == .POINT or b.kind() == .POINT) {
                // Not implemented - only linear, quadratic, and cubic curves supported
                return 0;
            }
            const a_points = a.get_points();
            const b_points = b.get_points();
            @memcpy(points[CORNER_IDX .. CORNER_IDX + b_points.len], b_points);
            @memcpy(points[CORNER_IDX - a_points.len .. CORNER_IDX], a_points);
            return _convergent_curve_ordering_internal(points, a_points.len - 1, b_points.len - 1);
        }

        pub fn deconverge_edge(self: *Self, cubic_control_segment: u1, vector: Vector) void {
            goto_top_of_switch: switch (self.kind()) {
                .QUADRATIC_BEZIER => {
                    self.* = Self{ .CUBIC_BEZIER = self.QUADRATIC_BEZIER.upgrade_to_cubic_bezier() };
                    continue :goto_top_of_switch .CUBIC_BEZIER;
                },
                .CUBIC_BEZIER => {
                    var p: []Vector = self.CUBIC_BEZIER.get_points();
                    switch (cubic_control_segment) {
                        0 => {
                            p[1] = p[1].add(vector.scale(p[1].subtract(p[0]).length()));
                        },
                        1 => {
                            p[2] = p[2].add(vector.scale(p[2].subtract(p[3]).length()));
                        },
                    }
                },
                else => {},
            }
        }

        pub fn swap_with(self: *Self, other: *Self) void {
            const tmp = self.*;
            self.* = other.*;
            other.* = tmp;
        }
    };
}

pub fn ContourNoUserdata(comptime T: type) type {
    return Contour(T, void, void{});
}

pub fn Contour(comptime T: type, comptime EDGE_USERDATA: type, comptime EDGE_USERDATA_DEFAULT_VALUE: EDGE_USERDATA) type {
    return struct {
        const Self = @This();
        const Matrix = Mat3x3.define_matrix_3x3_type(T);
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);
        const EDGE = EdgeWithUserdata(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT_VALUE);

        edges: List(EDGE) = .{},

        pub fn clear(self: *Self) void {
            self.edges.clear();
        }
        pub fn init_capacity(edge_cap: usize, alloc: Allocator) Self {
            return Self{
                .edges = List(EDGE).init_capacity(edge_cap, alloc),
            };
        }
        pub fn free(self: *Self, alloc: Allocator) void {
            self.edges.free(alloc);
        }

        pub fn is_closed(self: *Self, epsilon: T) bool {
            if (self.edges.is_empty()) return true;
            var prev_corner = self.edges.get_last().get_end();
            for (self.edges.slice()) |edge| {
                if (!edge.get_start().approx_equal_with_epsilon(prev_corner, epsilon)) {
                    return false;
                }
                prev_corner = edge.get_end();
            }
            return true;
        }

        pub fn append_edge(self: *Self, edge: EDGE, alloc: Allocator) void {
            _ = self.edges.append(edge, alloc);
        }

        pub fn add_bounds_to_aabb(self: *Self, aabb: *AABB, linear_estimate: LinearEstimate(T)) void {
            for (self.edges.slice()) |edge| {
                edge.add_bounds_to_aabb(aabb, linear_estimate);
            }
        }

        pub fn add_mitered_bounds_to_aabb(self: *Self, aabb: *AABB, border_size: T, miter_limit: T, polarity: T) void {
            if (self.edges.is_empty()) return;
            var prev_tangent = self.edges.get_last().tangent(1).normalize_may_be_zero(.norm_zero_is_zero);
            var this_tangent: Vector = undefined;
            for (self.edges.slice()) |edge| {
                this_tangent = edge.tangent(0).normalize_may_be_zero(.norm_zero_is_zero).negate();
                if (polarity * prev_tangent.cross(this_tangent) >= 0) {
                    var miter_factor = miter_limit;
                    const q = 0.5 * (1 - prev_tangent.dot(this_tangent));
                    if (q > 0) {
                        miter_factor = @min(1 / @sqrt(q), miter_limit);
                    }
                    const miter_offest = prev_tangent.add(this_tangent).normalize_may_be_zero(.norm_zero_is_zero).scale(border_size * miter_factor);
                    const miter_point = edge.get_start().add(miter_offest);
                    aabb.* = aabb.combine_with_point(miter_point);
                }
                prev_tangent = edge.tangent(1).normalize_may_be_zero(.norm_zero_is_zero);
            }
        }

        pub fn get_bounds(self: Self, border_width: T, miter_limit: T, polarity: T) AABB {
            var aabb = AABB{};
            self.add_bounds_to_aabb(&aabb);
            if (border_width > 0) {
                aabb.expand_by(border_width);
                if (miter_limit > 0) {
                    self.add_mitered_bounds_to_aabb(&aabb, border_width, miter_limit, polarity);
                }
            }
            return aabb;
        }

        pub fn winding_orientation(self: Self) Winding {
            if (self.edges.is_empty()) return .COLINEAR;
            var total: T = 0;
            if (self.edges.len == 1) {
                const a = self.edges.ptr[0].get_start();
                const b = self.edges.ptr[0].lerp(1.0 / 3.0);
                const c = self.edges.ptr[0].lerp(2.0 / 3.0);
                total += a.shoelace_area_step(b);
                total += b.shoelace_area_step(c);
                total += c.shoelace_area_step(a);
            } else if (self.edges.len == 2) {
                const a = self.edges.ptr[0].get_start();
                const b = self.edges.ptr[0].lerp(0.5);
                const c = self.edges.ptr[1].get_start();
                const d = self.edges.ptr[1].lerp(0.5);
                total += a.shoelace_area_step(b);
                total += b.shoelace_area_step(c);
                total += c.shoelace_area_step(d);
                total += d.shoelace_area_step(a);
            } else {
                var prev: Vector = self.edges.get_last().get_start();
                var curr: Vector = undefined;
                for (self.edges.slice()) |edge| {
                    curr = edge.get_start();
                    total += prev.shoelace_area_step(curr);
                    prev = curr;
                }
            }
            return num_cast(MathX.sign_convert(total, i8), Winding);
        }

        pub fn reverse(self: *Self) void {
            self.edges.reverse(.entire_list());
            for (self.edges.slice()) |*edge| {
                edge.reverse();
            }
        }

        pub fn translate(self: *Self, vec: Vector) void {
            for (self.edges.slice()) |*edge| {
                edge.* = edge.translate(vec);
            }
        }
        pub fn scale(self: *Self, vec: Vector) void {
            for (self.edges.slice()) |*edge| {
                edge.* = edge.scale(vec);
            }
        }
        pub fn apply_complex_transform(self: *Self, steps: []const Vector.TransformStep) void {
            for (self.edges.slice()) |*edge| {
                edge.* = edge.apply_complex_transform(steps);
            }
        }
        pub fn apply_inverse_complex_transform(self: *Self, steps: []const Vector.TransformStep) void {
            for (self.edges.slice()) |*edge| {
                edge.* = edge.apply_inverse_complex_transform(steps);
            }
        }
        pub fn apply_affine_transform_matrix(self: *Self, matrix: Matrix) void {
            for (self.edges.slice()) |*edge| {
                edge.* = edge.apply_affine_transform_matrix(matrix);
            }
        }

        /// If any of the edges are degenerate (for example a quadratic bezier that approximately forms a line, or a line that is actualy a point),
        /// it converts those edges to their simpler forms.
        pub fn simplify_degenerate_edges(self: *Self, degenerate_epsilon: T) void {
            for (self.edges.slice()) |*edge| {
                edge.simplify_degenerate_edge(degenerate_epsilon);
            }
        }

        /// This is not the same as vector normalization!
        ///
        /// First, if any of the edges are degenerate (for example a quadratic bezier that approximately forms a line, or a line that is actualy a point),
        /// it converts those edges to their simpler forms.
        ///
        /// Then, if a shape has only one edge, it splits the edge into thirds and replaces the existing edge with the 3 thirds
        ///
        /// Otherwise, it de-converges adjacent edges when the dot product of the tangents of the two edges at the corner where they meet
        /// is less than `corner_dot_epsilon - 1` using the `deconverge_factor`
        pub fn normalize(self: *Self, alloc: Allocator, degenerate_epsilon: T, corner_dot_epsilon: anytype, deconverge_factor: anytype) void {
            const CORNER_DOT_EPSILON_MINUS_ONE = corner_dot_epsilon - 1;
            self.simplify_degenerate_edges(degenerate_epsilon);
            if (self.edges.len == 1) {
                @branchHint(.unlikely);
                const parts: [3]Edge(T) = self.edges.ptr[0].split_in_thirds();
                self.edges.clear();
                _ = self.edges.append(parts[0], alloc);
                _ = self.edges.append(parts[1], alloc);
                _ = self.edges.append(parts[2], alloc);
            } else {
                var prev_edge: *Edge = self.edges.get_last_ptr();
                var prev_tangent: Vector = undefined;
                var curr_tangent: Vector = undefined;
                var axis: Vector = undefined;
                for (self.edges.slice()) |*curr_edge| {
                    prev_tangent = prev_edge.tangent(1).normalize();
                    curr_tangent = curr_edge.tangent(0).normalize();
                    if (prev_tangent.dot(curr_tangent) < CORNER_DOT_EPSILON_MINUS_ONE) {
                        axis = curr_tangent.subtract(prev_tangent).normalize().scale(deconverge_factor);
                        if (prev_edge.convergent_curve_ordering(curr_edge.edge) < 0) {
                            axis = axis.negate();
                        }
                        prev_edge.deconverge_edge(1, axis.perp_ccw());
                        curr_edge.deconverge_edge(0, axis.perp_cw());
                    }
                    prev_edge = curr_edge;
                }
            }
        }

        pub fn get_new_horizontal_scanline_intersections(self: Self, y_value: T, alloc: Allocator, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type, estimates: Estimates(T)) Scanline(T, SLOPE_MODE, SLOPE_TYPE) {
            var scanline = Scanline(T, SLOPE_MODE, SLOPE_TYPE).init_cap(8, alloc);
            self.append_horizontal_scanline_intersections(y_value, SLOPE_MODE, SLOPE_TYPE, &scanline, alloc, estimates);
            return scanline;
        }

        pub fn append_horizontal_scanline_intersections(self: Self, y_value: T, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type, scanline: *Scanline(T, SLOPE_MODE, SLOPE_TYPE), scanline_allocator: Allocator, estimates: Estimates(T)) void {
            for (self.edges.slice()) |edge| {
                const edge_intersections = edge.horizontal_intersections(y_value, .axis_only, SLOPE_MODE, SLOPE_TYPE, estimates);
                for (0..edge_intersections.count) |i| {
                    const inter = edge_intersections.intersections[i];
                    _ = scanline.intersections.append(.{ .inter = inter }, scanline_allocator);
                }
            }
        }
    };
}

pub fn ShapeNoUserdata(comptime T: type) type {
    return Shape(T, void, void{});
}

pub fn Shape(comptime T: type, comptime EDGE_USERDATA: type, comptime EDGE_USERDATA_DEFAULT_VALUE: EDGE_USERDATA) type {
    return struct {
        const Self = @This();
        const Matrix = Mat3x3.define_matrix_3x3_type(T);
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);
        const EDGE = EdgeWithUserdata(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT_VALUE);
        const CONTOUR = Contour(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT_VALUE);

        contours: List(CONTOUR) = .{},

        pub fn clear(self: *Self, alloc: Allocator) void {
            for (self.contours.slice()) |*shape| {
                shape.free(alloc);
            }
            self.contours.clear();
        }
        pub fn init_capacity(shape_cap: usize, alloc: Allocator) Self {
            return Self{
                .contours = List(CONTOUR).init_capacity(shape_cap, alloc),
            };
        }
        pub fn free(self: *Self, alloc: Allocator) void {
            for (self.contours.slice()) |*contour| {
                contour.free(alloc);
            }
            self.contours.free(alloc);
        }

        pub fn all_contours_are_closed(self: Self, epsilon: T) bool {
            for (self.contours.slice()) |contour| {
                if (!contour.is_closed(epsilon)) return false;
            }
            return true;
        }

        pub fn append_contour(self: *Self, shape: CONTOUR, alloc: Allocator) void {
            _ = self.contours.append(shape, alloc);
        }
        pub fn append_empty_contour(self: *Self, shape_edge_capacity: usize, alloc: Allocator) *CONTOUR {
            const idx = self.contours.append(.init_capacity(shape_edge_capacity, alloc), alloc);
            return self.contours.get_ptr(idx);
        }

        /// This is not the same as vector normalization!
        ///
        /// First, if any of the contour edges are degenerate (for example a bezier that approximately forms a line, or a line that is actualy a point),
        /// it converts those edges to their simpler forms.
        ///
        /// Then, if a contour has only one edge, it splits the edge into thirds and replaces the existing edge with the 3 thirds
        ///
        /// Otherwise, it de-converges adjacent contour edges when the dot product of the tangents of the two edges at the corner where they meet
        /// is less than `corner_dot_epsilon - 1` using the `deconverge_factor`
        pub fn normalize(self: *Self, alloc: Allocator, degenerate_epsilon: T, corner_dot_epsilon: anytype, deconverge_factor: anytype) void {
            for (self.contours.slice()) |*contour| {
                contour.normalize(alloc, degenerate_epsilon, corner_dot_epsilon, deconverge_factor);
            }
        }

        pub fn translate(self: *Self, vec: Vector) void {
            for (self.contours.slice()) |*contour| {
                contour.translate(vec);
            }
        }

        pub fn scale(self: *Self, vec: Vector) void {
            for (self.contours.slice()) |*contour| {
                contour.scale(vec);
            }
        }
        pub fn apply_complex_transform(self: *Self, steps: []const Vector.TransformStep) void {
            for (self.contours.slice()) |*contour| {
                contour.apply_complex_transform(steps);
            }
        }
        pub fn apply_inverse_complex_transform(self: *Self, steps: []const Vector.TransformStep) void {
            for (self.contours.slice()) |*contour| {
                contour.apply_inverse_complex_transform(steps);
            }
        }
        pub fn apply_affine_transform_matrix(self: *Self, matrix: Matrix) void {
            for (self.contours.slice()) |*contour| {
                contour.apply_affine_transform_matrix(matrix);
            }
        }

        pub fn add_bounds_to_aabb(self: *Self, aabb: *AABB, linear_estimate: LinearEstimate(T)) void {
            for (self.contours.slice()) |*contour| {
                contour.add_bounds_to_aabb(aabb, linear_estimate);
            }
        }

        pub fn add_mitered_bounds_to_aabb(self: *Self, aabb: *AABB, border_size: T, miter_limit: T, polarity: T) void {
            for (self.contours.slice()) |*contour| {
                contour.add_mitered_bounds_to_aabb(aabb, border_size, miter_limit, polarity);
            }
        }

        pub fn get_bounds_with_miter(self: *Self, border_width: T, miter_limit: T, polarity: T, linear_estimate: MathX.LinearEstimate(T)) AABB {
            var aabb = AABB{};
            self.add_bounds_to_aabb(&aabb, linear_estimate);
            if (border_width > 0) {
                aabb = aabb.expand_by(border_width);
                if (miter_limit > 0) {
                    self.add_mitered_bounds_to_aabb(&aabb, border_width, miter_limit, polarity);
                }
            }
            return aabb;
        }
        pub fn get_bounds_with_miter_default_estimate(self: *Self, border_width: T, miter_limit: T, polarity: T) AABB {
            return self.get_bounds_with_miter(border_width, miter_limit, polarity, Estimates(T).DEFAULT.linear);
        }
        pub fn get_bounds(self: *Self, linear_estimate: MathX.LinearEstimate(T)) AABB {
            return self.get_bounds_with_miter(0, 0, 0, linear_estimate);
        }
        pub fn get_bounds_default_estimate(self: *Self) AABB {
            return self.get_bounds_with_miter(0, 0, 0, Estimates(T).DEFAULT.linear);
        }

        pub fn get_new_horizontal_scanline_intersections(self: Self, y_value: T, alloc: Allocator, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type, estimates: Estimates(T)) Scanline(T, SLOPE_MODE, SLOPE_TYPE) {
            var scanline = Scanline(T, SLOPE_MODE, SLOPE_TYPE).init_cap(8, alloc);
            for (self.contours.slice()) |contour| {
                contour.append_horizontal_scanline_intersections(y_value, SLOPE_MODE, SLOPE_TYPE, &scanline, alloc, estimates);
            }
            return scanline;
        }

        pub fn remake_horizontal_scanline_intersections(self: Self, y_value: T, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type, scanline: *Scanline(T, SLOPE_MODE, SLOPE_TYPE), scanline_allocator: Allocator, estimates: Estimates(T)) void {
            scanline.reset();
            for (self.contours.slice()) |contour| {
                contour.append_horizontal_scanline_intersections(y_value, SLOPE_MODE, SLOPE_TYPE, scanline, scanline_allocator, estimates);
            }
        }

        pub fn edge_count(self: Self) u32 {
            var total: u32 = 0;
            for (self.contours.slice()) |contour| {
                total += contour.edges.len;
            }
            return total;
        }

        /// reverses shapes that have a winding that does not agree
        pub fn reorient_shape_winding_directions(self: *Self, temp_alloc: Allocator, comptime POINT_MODE: MathX.ScanlinePointMode, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type, comptime double_root_estimate: DoubleRootEstimate(T), comptime quadratic_estimate: QuadraticEstimate(T), comptime linear_estimate: LinearEstimate(T)) void {
            const IntersectionWithIdx = IntersectionWithShapeIdx(T, SLOPE_MODE, SLOPE_TYPE);
            var orientations = List(i32).init_capacity(@intCast(self.contours.len), temp_alloc);
            defer orientations.free(temp_alloc);
            var intersections = List(IntersectionWithIdx).init_capacity(@intCast(self.contours.len), temp_alloc);
            defer intersections.free(temp_alloc);
            for (self.contours.slice(), 0..) |*shape, i| {
                if (i >= orientations.len and !shape.edges.is_empty()) {
                    orientations.len = @intCast(i);
                    const y0 = shape.edges.get_first().get_start().y;
                    var y1 = y0;
                    for (shape.edges.slice()) |edge| {
                        if (y0 != y1) break;
                        y1 = edge.get_end().y;
                    }
                    // in case all endpoints are in a horizontal line
                    for (shape.edges.slice()) |edge| {
                        if (y0 != y1) break;
                        y1 = edge.lerp(HALF_SQRT_5_MINUS_1).y;
                    }
                    const y = MathX.lerp(y0, y1, HALF_SQRT_5_MINUS_1);
                    for (self.contours.slice(), 0..) |shape_2, j| {
                        for (shape_2.edges.slice()) |edge| {
                            const edge_intersections = edge.horizontal_intersections(y, POINT_MODE, SLOPE_MODE, SLOPE_TYPE, double_root_estimate, quadratic_estimate, linear_estimate);
                            var k: u32 = 0;
                            while (k < edge_intersections.count) {
                                const isection = IntersectionWithIdx{
                                    .inter = edge_intersections.intersections[k],
                                    .shape_idx = j,
                                };
                                _ = intersections.append(isection, temp_alloc);
                                k += 1;
                            }
                        }
                    }
                    if (!intersections.is_empty()) {
                        intersections.insertion_sort(.entire_list(), IntersectionWithIdx.x_greater_than);
                        // Disqualify multiple intersections
                        var j: u32 = 1;
                        var jj: u32 = 0;
                        while (j < intersections.len) {
                            if (intersections.ptr[j].inter.point == intersections.ptr[jj].inter.point) {
                                intersections.ptr[j].inter.slope = 0;
                                intersections.ptr[jj].inter.slope = 0;
                            }
                            jj = j;
                            j += 1;
                        }
                        j = 0;
                        while (j < intersections.len) {
                            if (intersections.ptr[j].inter.slope != 0) {
                                orientations.ptr[intersections.ptr[j].shape_idx] += (2 * (num_cast(j & 1, i32) ^ num_cast(intersections.ptr[j].inter.slope > 0, i32))) - 1;
                            }
                            j += 1;
                        }
                        intersections.clear();
                    }
                }
            }

            // Reverse shapes that have the opposite orientation
            for (self.contours.slice(), 0..) |*shape, i| {
                if (orientations.ptr[i] < 0) {
                    shape.reverse();
                }
            }
        }
    };
}

pub fn Intersection(comptime T: type, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type) type {
    assert_with_reason(Types.type_is_signed_int(SLOPE_TYPE), @src(), "`SLOPE_TYPE` must be a signed integer type, got type `{s}`", .{@typeName(SLOPE_TYPE)});
    return struct {
        const Self = @This();

        inter: MathX.ScanlineIntersection(.axis_only, SLOPE_MODE, T, SLOPE_TYPE),

        pub fn new(inter: MathX.ScanlineIntersection(.axis_only, .sign, T, SLOPE_TYPE)) Self {
            return Self{
                .inter = inter,
            };
        }

        pub fn x_greater_than(a: Self, b: Self) bool {
            return a.inter.point > b.inter.point;
        }
    };
}

pub fn IntersectionWithShapeIdx(comptime T: type, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type) type {
    assert_with_reason(Types.type_is_signed_int(SLOPE_TYPE), @src(), "`SLOPE_TYPE` must be a signed integer type, got type `{s}`", .{@typeName(SLOPE_TYPE)});
    return struct {
        const Self = @This();

        inter: MathX.ScanlineIntersection(.axis_only, SLOPE_MODE, T, SLOPE_TYPE),
        shape_idx: usize,

        pub fn new(inter: MathX.ScanlineIntersection(.axis_only, .sign, T, SLOPE_TYPE), shape_idx: usize) Self {
            return Self{
                .inter = inter,
                .shape_idx = shape_idx,
            };
        }

        pub fn x_greater_than(a: Self, b: Self) bool {
            return a.inter.point > b.inter.point;
        }
    };
}

pub fn Scanline(comptime T: type, comptime SLOPE_MODE: MathX.ScanlineSlopeMode, comptime SLOPE_TYPE: type) type {
    return struct {
        const Self = @This();

        pub const IntersectionType = Intersection(T, SLOPE_MODE, SLOPE_TYPE);
        pub const IntersectionList = List(IntersectionType);

        intersections: IntersectionList = .{},
        last_index: usize = 0,

        pub fn init_cap(cap: usize, alloc: Allocator) Self {
            return Self{
                .intersections = IntersectionList.init_capacity(cap, alloc),
                .last_index = 0,
            };
        }
        pub fn reset(self: *Self) void {
            self.intersections.clear();
            self.last_index = 0;
        }
        pub fn free(self: *Self, alloc: Allocator) void {
            self.intersections.free(alloc);
        }

        pub fn sort_and_sum(self: *Self) void {
            self.last_index = 0;
            if (!self.intersections.is_empty()) {
                self.intersections.insertion_sort(.entire_list(), IntersectionType.x_greater_than);
                var total_direction: SLOPE_TYPE = 0;
                for (self.intersections.slice()) |*intersection| {
                    total_direction += intersection.inter.slope;
                    intersection.inter.slope = total_direction;
                }
            }
        }

        /// Returns the intersection index at the x_value, or null if no intersections exist at that x_value
        pub fn move_to(self: *Self, x_value: T) ?usize {
            if (self.intersections.is_empty()) {
                return null;
            }
            while (x_value < self.intersections.ptr[self.last_index].point) {
                if (self.last_index == 0) {
                    return null;
                }
                self.last_index -= 1;
            }
            while (x_value > self.intersections.ptr[self.last_index].point and self.last_index < self.intersections.len) {
                self.last_index += 1;
            }
            if (self.last_index >= self.intersections.len) {
                return null;
            }
            return self.last_index;
        }

        pub fn count_intersections(self: *Self, x_value: T) usize {
            return self.move_to(x_value) + 1;
        }

        /// Assumes the Scanline had `sort_and_sum()` called
        pub fn sum_intersection_slopes_at_x_val(self: *Self, x_value: T) SLOPE_TYPE {
            const idx = self.move_to(x_value);
            if (idx) |i| {
                return self.intersections.ptr[i].inter.slope;
            }
            return 0;
        }

        /// Assumes the Scanline had `sort_and_sum()` called
        pub fn sum_intersection_slopes_at_idx(self: *Self, idx: usize) SLOPE_TYPE {
            return self.intersections.ptr[idx].inter.slope;
        }

        /// Assumes the Scanline had `sort_and_sum()` called
        pub fn should_be_filled_at_x(self: *Self, x_value: T, fill_rule: FillRule) bool {
            return fill_rule.should_be_filled(self.sum_intersection_slopes_at_x_val(x_value));
        }

        /// Assumes the Scanline had `sort_and_sum()` called
        pub fn should_be_filled_at_idx(self: *Self, idx: usize, fill_rule: FillRule) bool {
            return fill_rule.should_be_filled(self.sum_intersection_slopes_at_idx(idx));
        }

        pub fn overlap_amount(a: *Self, b: *Self, from_x: T, to_x: T, fill_rule: FillRule) T {
            var total: T = 0;
            var a_inside = false;
            var b_inside = false;
            var a_idx: usize = 0;
            var b_idx: usize = 0;
            var ax = if (!a.intersections.is_empty()) a.intersections.ptr[a_idx].point else to_x;
            var bx = if (!b.intersections.is_empty()) b.intersections.ptr[b_idx].point else to_x;
            while (ax < from_x or bx < from_x) {
                const next_x = @min(ax, bx);
                if (ax == next_x and a_idx < a.intersections.len) {
                    a_inside = a.should_be_filled_at_idx(a_idx, fill_rule);
                    a_idx += 1;
                    ax = if (a_idx < a.intersections.len) a.intersections.ptr[a_idx].point else to_x;
                }
                if (bx == next_x and b_idx < b.intersections.len) {
                    b_inside = b.should_be_filled_at_idx(b_idx, fill_rule);
                    b_idx += 1;
                    bx = if (b_idx < b.intersections.len) b.intersections.ptr[b_idx].point else to_x;
                }
            }
            var x = from_x;
            while (ax < to_x or bx < to_x) {
                const next_x = @min(ax, bx);
                if (a_inside == b_inside) {
                    total += next_x - x;
                }
                if (ax == next_x and a_idx < a.intersections.len) {
                    a_inside = a.should_be_filled_at_idx(a_idx, fill_rule);
                    a_idx += 1;
                    ax = if (a_idx < a.intersections.len) a.intersections.ptr[a_idx].point else to_x;
                }
                if (bx == next_x and b_idx < b.intersections.len) {
                    b_inside = b.should_be_filled_at_idx(b_idx, fill_rule);
                    b_idx += 1;
                    bx = if (b_idx < b.intersections.len) b.intersections.ptr[b_idx].point else to_x;
                }
                x = next_x;
            }
            if (a_inside == b_inside) {
                total += to_x - x;
            }
            return total;
        }
    };
}

pub fn TrueDistance(comptime T: type) type {
    return extern struct {
        const Self = @This();

        alpha: T = 0,

        pub fn new(dist: T) Self {
            return Self{ .value = dist };
        }

        pub fn median(self: Self) T {
            return self.value;
        }

        pub fn with_median(self: Self) TrueDistanceAndMedian(T) {
            return TrueDistanceAndMedian(T){
                .distance = self,
                .median = self.value,
            };
        }
    };
}
pub fn PerpDistance(comptime T: type) type {
    return TrueDistance(T);
}
pub fn TrueDistanceAndMedian(comptime T: type) type {
    return struct {
        const Self = @This();

        distance: TrueDistance(T) = .{},
        median: T = 0,
    };
}
pub fn PerpDistanceAndMedian(comptime T: type) type {
    return TrueDistanceAndMedian(T);
}

pub fn MultiDistance(comptime T: type) type {
    return extern struct {
        const Self = @This();

        red: T = 0,
        green: T = 0,
        blue: T = 0,

        pub fn new(red: T, green: T, blue: T) Self {
            return Self{ .red = red, .green = green, .blue = blue };
        }

        pub fn median(self: Self) T {
            return MathX.median_of_3(T, self.red, self.green, self.blue);
        }

        pub fn with_median(self: Self) MultiDistanceAndMedian(T) {
            return MultiDistanceAndMedian(T){
                .distance = self,
                .median = self.median(),
            };
        }
    };
}

pub fn MultiDistanceAndMedian(comptime T: type) type {
    return struct {
        const Self = @This();

        distance: MultiDistance(T) = .{},
        median: T = .{},
    };
}

pub fn TrueAndMultiDistance(comptime T: type) type {
    return extern struct {
        const Self = @This();

        red: T = 0,
        green: T = 0,
        blue: T = 0,
        alpha: T = 0,

        pub fn new(alpha: T, red: T, green: T, blue: T) Self {
            return Self{
                .alpha = alpha,
                .red = red,
                .green = green,
                .blue = blue,
            };
        }
        pub fn median(self: Self) T {
            return MathX.median_of_3(T, self.red, self.green, self.blue);
        }
        pub fn with_median(self: Self) TrueAndMultiDistanceAndMedian(T) {
            return TrueAndMultiDistanceAndMedian(T){
                .distance = self,
                .median = self.median(),
            };
        }
    };
}

pub fn TrueAndMultiDistanceAndMedian(comptime T: type) type {
    return struct {
        const Self = @This();

        distance: TrueAndMultiDistance(T) = .{},
        median: T = .{},
    };
}

pub fn TrueDistanceEdgeCache(comptime T: type) type {
    return struct {
        const Self = @This();
        const Vector = Vec2.define_vec2_type(T);

        point: Vector,
        abs_distance: T,

        pub fn new(point: Point, abs_distance: T) Self {
            return Self{
                .point = point,
                .abs_distance = abs_distance,
            };
        }
    };
}

pub fn TrueDistanceSelector(comptime T: type, comptime CONST: EdgeSelectorContants) type {
    return struct {
        const Self = @This();
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        pub const Distance = TrueDistance(T);
        pub const DistanceAndMedian = TrueDistanceAndMedian(T);
        pub const EdgeCache = TrueDistanceEdgeCache(T);
        pub const EdgeType = Edge(T);

        point: Vector = .{},
        min_signed_distance: MathX.SignedDistance(T) = .{},

        pub fn reset(self: *Self, point: Vector) void {
            const delta = CONST.DISTANCE_DELTA_FACTOR * point.subtract(self.point).length();
            self.min_signed_distance.distance += MathX.sign_nonzero(self.min_signed_distance.distance) * delta;
            self.point = point;
        }

        pub fn add_edge(self: *Self, cache: *EdgeCache, prev_edge: EdgeType, this_edge: EdgeType, next_edge: EdgeType) void {
            _ = prev_edge;
            _ = next_edge;
            const delta = CONST.DISTANCE_DELTA_FACTOR * self.point.subtract(cache.point).length();
            if (cache.abs_distance - delta < @abs(self.min_signed_distance.distance)) {
                const this_dist = this_edge.minimum_signed_distance_from_point(self.point);
                if (this_dist.signed_dist.less_than(self.min_signed_distance)) {
                    self.min_signed_distance = this_dist.signed_dist;
                }
                cache.point = self.point;
                cache.abs_distance = @abs(this_dist.signed_dist.distance);
            }
        }

        pub fn merge(self: *Self, other: Self) void {
            if (other.min_signed_distance.less_than(self.min_signed_distance)) {
                self.min_signed_distance = other.min_signed_distance;
            }
        }

        pub fn distance(self: Self) Distance {
            return .new(self.min_signed_distance.distance);
        }
        pub fn median_distance(self: Self) T {
            return self.min_signed_distance.distance;
        }
        pub fn distance_and_median(self: TrueDistanceSelector) DistanceAndMedian {
            return DistanceAndMedian{
                .distance = .new(self.min_signed_distance.distance),
                .median = self.min_signed_distance.distance,
            };
        }
    };
}

pub fn PerpendicularDistanceEdgeCache(comptime T: type) type {
    return struct {
        const Vector = Vec2.define_vec2_type(T);

        point: Vector = .{},
        abs_distance: T = 0,
        a_domain_distance: T = 0,
        b_domain_distance: T = 0,
        a_perp_distance: T = 0,
        b_perp_distance: T = 0,
    };
}

pub fn PerpendicularDistanceSelectorBase(comptime T: type, comptime CONST: EdgeSelectorContants) type {
    return struct {
        const Self = @This();
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        pub const Distance = TrueDistance(T);
        pub const DistanceAndMedian = TrueDistanceAndMedian(T);
        pub const EdgeType = Edge(T);
        pub const EdgeCacheType = PerpendicularDistanceEdgeCache(T);

        min_true_distance: SignedDistance(T) = .{},
        min_negative_perp_distance: T = 0,
        min_positive_perp_distance: T = 0,
        near_edge: ?*EdgeType = undefined,
        near_edge_percent: T = 0,

        pub fn reset(self: *Self, delta: T) void {
            self.min_true_distance.distance += MathX.sign_nonzero(self.min_true_distance.distance) * delta;
            self.min_negative_perp_distance = -@abs(self.min_true_distance.distance);
            self.min_positive_perp_distance = @abs(self.min_true_distance.distance);
            self.near_edge = null;
            self.near_edge_percent = 0;
        }

        pub fn edge_is_relevant(self: Self, cache: EdgeCacheType, point: Vector) bool {
            const delta = CONST.DISTANCE_DELTA_FACTOR * point.subtract(cache.point).length();
            return (cache.abs_distance - delta <= @abs(self.min_true_distance.distance) or
                @abs(cache.a_domain_distance) < delta or
                @abs(cache.b_domain_distance) < delta or
                (cache.a_domain_distance > 0 and if (cache.a_perp_distance < 0)
                    cache.a_perp_distance + delta >= self.min_negative_perp_distance
                else
                    cache.a_perp_distance - delta <= self.min_positive_perp_distance) or
                (cache.b_domain_distance > 0 and if (cache.b_perp_distance < 0)
                    cache.b_perp_distance + delta >= self.min_negative_perp_distance
                else
                    cache.b_perp_distance - delta <= self.min_positive_perp_distance));
        }

        pub fn add_edge_true_distance(self: *Self, edge: *EdgeType, signed_distance: SignedDistance(T), percent: T) void {
            if (signed_distance.less_than(self.min_true_distance)) {
                self.min_true_distance = signed_distance;
                self.near_edge = edge;
                self.near_edge_percent = percent;
            }
        }

        pub fn add_edge_perpendicular_distance(self: *Self, dist: T) void {
            if (dist <= 0 and dist > self.min_negative_perp_distance) {
                self.min_negative_perp_distance = dist;
            }
            if (dist >= 0 and dist < self.min_positive_perp_distance) {
                self.min_positive_perp_distance = dist;
            }
        }

        pub fn merge(self: *Self, other: Self) void {
            if (other.min_true_distance.less_than(self.min_true_distance)) {
                self.min_true_distance = other.min_true_distance;
                self.near_edge = other.near_edge;
                self.near_edge_percent = other.near_edge_percent;
            }
            if (other.min_negative_perp_distance > self.min_negative_perp_distance) {
                self.min_negative_perp_distance = other.min_negative_perp_distance;
            }
            if (other.min_positive_perp_distance < self.min_positive_perp_distance) {
                self.min_positive_perp_distance = other.min_positive_perp_distance;
            }
        }

        pub fn calculate_distance(self: Self, point: Vector) T {
            var min_distance = if (self.min_true_distance.distance < 0) self.min_negative_perp_distance else self.min_positive_perp_distance;
            if (self.near_edge) |near_edge| {
                var signed_dist = self.min_true_distance.with_percent(self.near_edge_percent);
                signed_dist = near_edge.signed_dist_to_perpendicular_dist(signed_dist, point);
                if (@abs(signed_dist.distance()) < @abs(min_distance)) {
                    min_distance = signed_dist.distance();
                }
            }
            return min_distance;
        }

        pub fn should_update_perpendicular_distance(curr_perp_distance: *T, test_point_to_edge_point_delta: Vector, edge_tangent: Vector) bool {
            const ts = test_point_to_edge_point_delta.dot(edge_tangent);
            if (ts > 0) {
                const new_perp_distance = test_point_to_edge_point_delta.cross(edge_tangent);
                if (@abs(new_perp_distance) < @abs(curr_perp_distance.*)) {
                    curr_perp_distance.* = new_perp_distance;
                    return true;
                }
            }
            return false;
        }
    };
}

pub fn PerpendicularDistanceSelector(comptime T: type, comptime CONST: EdgeSelectorContants) type {
    return struct {
        const Self = @This();
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        pub const Distance = TrueDistance(T);
        pub const DistanceAndMedian = TrueDistanceAndMedian(T);
        pub const EdgeType = Edge(T);
        pub const EdgeCache = PerpendicularDistanceEdgeCache(T);
        pub const BaseData = PerpendicularDistanceSelectorBase(T, CONST);

        base: BaseData = .{},
        point: Vector = .{},

        pub fn reset(self: *Self, point: Vector) void {
            const delta = CONST.DISTANCE_DELTA_FACTOR * point.subtract(self.point).length();
            self.base.reset(delta);
            self.point = point;
        }

        pub fn add_edge(self: *Self, cache: *EdgeCache, prev_edge: EdgeType, this_edge: EdgeType, next_edge: EdgeType) void {
            if (self.base.edge_is_relevant(cache, self.point)) {
                const signed_distance = this_edge.minimum_signed_distance_from_point(self.point);
                self.base.add_edge_true_distance(this_edge, signed_distance.signed_dist, signed_distance.percent);
                cache.point = self.point;
                cache.abs_distance = @abs(signed_distance.distance());
                const point_to_a_delta = self.point.subtract(this_edge.start_point());
                const point_to_b_delta = self.point.subtract(this_edge.end_point());
                const a_tangent = this_edge.tangent(0).normalize_may_be_zero(.norm_zero_is_zero);
                const b_tangent = this_edge.tangent(1).normalize_may_be_zero(.norm_zero_is_zero);
                const prev_tangent = prev_edge.tangent(1).normalize_may_be_zero(.norm_zero_is_zero);
                const next_tangent = next_edge.tangent(0).normalize_may_be_zero(.norm_zero_is_zero);
                const prev_tan_plus_a_tan_norm = prev_tangent.add(a_tangent).normalize_may_be_zero(.norm_zero_is_zero);
                const next_tan_plus_b_tan_norm = next_tangent.add(b_tangent).normalize_may_be_zero(.norm_zero_is_zero);
                const a_domain_distance = point_to_a_delta.dot(prev_tan_plus_a_tan_norm);
                const b_domain_distance = -point_to_b_delta.dot(next_tan_plus_b_tan_norm);
                if (a_domain_distance > 0) {
                    var perp_dist = signed_distance.distance();
                    if (BaseData.should_update_perpendicular_distance(&perp_dist, point_to_a_delta, a_tangent.negate())) {
                        perp_dist = -perp_dist;
                        self.base.add_edge_perpendicular_distance(perp_dist);
                    }
                    cache.a_perp_distance = perp_dist;
                }
                if (b_domain_distance > 0) {
                    var perp_dist = signed_distance.distance();
                    if (BaseData.should_update_perpendicular_distance(&perp_dist, point_to_b_delta, b_tangent)) {
                        self.base.add_edge_perpendicular_distance(perp_dist);
                    }
                    cache.b_perp_distance = perp_dist;
                }
                cache.a_domain_distance = a_domain_distance;
                cache.b_domain_distance = b_domain_distance;
            }
        }

        pub fn distance(self: Self) Distance {
            return .new(self.base.calculate_distance(self.point));
        }
        pub fn median(self: Self) T {
            return self.base.calculate_distance(self.point);
        }
        pub fn distance_and_median(self: Self) DistanceAndMedian {
            const d = self.base.calculate_distance(self.point);
            return DistanceAndMedian{
                .distance = .new(d),
                .median = d,
            };
        }
        pub fn merge(self: *Self, other: Self) void {
            self.base.merge(other.base);
        }
    };
}

/// Edge color specifies which color channels an edge belongs to when using `MULTI_DISTANCE` or `TRUE_AND_MULTI_DISTANCE`
pub const EdgeColor = enum(u8) {
    BLACK = _BLACK,
    RED = _RED,
    GREEN = _GREEN,
    YELLOW = _YELLOW,
    BLUE = _BLUE,
    MAGENTA = _MAGENTA,
    CYAN = _CYAN,
    WHITE = _WHITE,

    pub const _BLACK = 0b000;
    pub const _RED = 0b001;
    pub const _GREEN = 0b010;
    pub const _YELLOW = 0b011;
    pub const _BLUE = 0b100;
    pub const _MAGENTA = 0b101;
    pub const _CYAN = 0b110;
    pub const _WHITE = 0b111;

    pub const EdgeColorFlags = Flags.Flags(EdgeColor, enum(u8) {});
    pub fn as_flags(self: EdgeColor) EdgeColorFlags {
        return EdgeColorFlags{ .raw = @intFromEnum(self) };
    }
    pub fn from_flags(flags: EdgeColorFlags) EdgeColor {
        return @enumFromInt(flags.raw);
    }

    pub fn has_all_channels(self: EdgeColor, channels: EdgeColor) bool {
        return @intFromEnum(self) & @intFromEnum(channels) == @intFromEnum(channels);
    }
    pub fn has_channel(self: EdgeColor, channels: EdgeColor) bool {
        return @intFromEnum(self) & @intFromEnum(channels) != 0;
    }
    pub fn has_no_channels(self: EdgeColor, channels: EdgeColor) bool {
        return @intFromEnum(self) & @intFromEnum(channels) == 0;
    }

    pub fn raw(self: EdgeColor) u8 {
        return @intFromEnum(self);
    }
    pub fn from_raw(val: u8) EdgeColor {
        return @enumFromInt(val);
    }
    pub fn bit_and(self: EdgeColor, other: EdgeColor) EdgeColor {
        return .from_raw(self.raw() & other.raw());
    }
    pub fn bit_or(self: EdgeColor, other: EdgeColor) EdgeColor {
        return .from_raw(self.raw() | other.raw());
    }
    pub fn bit_xor(self: EdgeColor, other: EdgeColor) EdgeColor {
        return .from_raw(self.raw() ^ other.raw());
    }

    pub fn init_color(rand: *u64) EdgeColor {
        const RAND_CHOICES = [3]EdgeColor{ .CYAN, .MAGENTA, .YELLOW };
        return RAND_CHOICES[MathX.extract_partial_rand_from_rand(rand, 3, u64)];
    }
    pub fn switch_color(self: *EdgeColor, rand: *u64) void {
        const r = MathX.extract_partial_rand_from_rand(rand, 2, u3);
        var switched: u8 = self.raw() << (1 + r);
        switched |= switched >> 3;
        switched &= _WHITE;
        self.* = .from_raw(switched);
    }
    pub fn switch_color_with_ban(self: *EdgeColor, rand: *u64, banned: EdgeColor) void {
        const overlap = self.bit_and(banned);
        if (overlap == .RED or overlap == .GREEN or overlap == .BLUE) {
            self.* = overlap.bit_xor(.WHITE);
        } else {
            self.switch_color(rand);
        }
    }
};

pub fn MultiDistanceSelector(comptime T: type, comptime CONST: EdgeSelectorContants) type {
    return struct {
        const Self = @This();
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        pub const Distance = MultiDistance(T);
        pub const DistanceAndMedian = MultiDistanceAndMedian(T);
        pub const EdgeType = EdgeWithUserdata(T, EdgeColor);
        pub const EdgeCache = PerpendicularDistanceEdgeCache(T);
        pub const BaseData = PerpendicularDistanceSelectorBase(T, CONST);

        point: Vector = .{},
        select_red: BaseData = .{},
        select_green: BaseData = .{},
        select_blue: BaseData = .{},

        pub fn reset(self: *Self, point: Vector) void {
            const delta = CONST.DISTANCE_DELTA_FACTOR * point.subtract(self.point).length();
            self.select_red.reset(delta);
            self.select_green.reset(delta);
            self.select_blue.reset(delta);
            self.point = point;
        }

        pub fn add_edge(self: *Self, cache: *EdgeCache, prev_edge: EdgeType, this_edge: *EdgeType, next_edge: *EdgeType) void {
            if ((this_edge.userdata.has_all_channels(.RED) and self.select_red.edge_is_relevant(cache.*, self.point)) or
                (this_edge.userdata.has_all_channels(.GREEN) and self.select_green.edge_is_relevant(cache.*, self.point)) or
                (this_edge.userdata.has_all_channels(.BLUE) and self.select_blue.edge_is_relevant(cache.*, self.point)))
            {
                var signed_distance = this_edge.minimum_signed_distance_from_point(self.point);
                if (this_edge.userdata.has_all_channels(.RED)) {
                    self.select_red.add_edge_true_distance(this_edge, signed_distance.signed_dist, signed_distance.percent);
                }
                if (this_edge.userdata.has_all_channels(.GREEN)) {
                    self.select_green.add_edge_true_distance(this_edge, signed_distance.signed_dist, signed_distance.percent);
                }
                if (this_edge.userdata.has_all_channels(.BLUE)) {
                    self.select_blue.add_edge_true_distance(this_edge, signed_distance.signed_dist, signed_distance.percent);
                }
                cache.point = self.point;
                cache.abs_distance = @abs(signed_distance.distance());

                const point_to_a_delta = self.point.subtract(this_edge.get_start_point());
                const point_to_b_delta = self.point.subtract(this_edge.get_end_point());
                const a_tangent = this_edge.tangent(0).normalize_may_be_zero(.norm_zero_is_zero);
                const b_tangent = this_edge.tangent(1).normalize_may_be_zero(.norm_zero_is_zero);
                const prev_tangent = prev_edge.tangent(1).normalize_may_be_zero(.norm_zero_is_zero);
                const next_tangent = next_edge.tangent(0).normalize_may_be_zero(.norm_zero_is_zero);
                const prev_tan_plus_a_tan_norm = prev_tangent.add(a_tangent).normalize_may_be_zero(.norm_zero_is_zero);
                const next_tan_plus_b_tan_norm = next_tangent.add(b_tangent).normalize_may_be_zero(.norm_zero_is_zero);
                const a_domain_distance = point_to_a_delta.dot(prev_tan_plus_a_tan_norm);
                const b_domain_distance = -point_to_b_delta.dot(next_tan_plus_b_tan_norm);
                if (a_domain_distance > 0) {
                    var perp_dist = signed_distance.distance();
                    if (BaseData.should_update_perpendicular_distance(&perp_dist, point_to_a_delta, a_tangent.negate())) {
                        perp_dist = -perp_dist;
                        if (this_edge.userdata.has_all_channels(.red)) {
                            self.select_red.add_edge_perpendicular_distance(perp_dist);
                        }
                        if (this_edge.userdata.has_all_channels(.green)) {
                            self.select_green.add_edge_perpendicular_distance(perp_dist);
                        }
                        if (this_edge.userdata.has_all_channels(.blue)) {
                            self.select_blue.add_edge_perpendicular_distance(perp_dist);
                        }
                    }
                    cache.a_perp_distance = perp_dist;
                }
                if (b_domain_distance > 0) {
                    var perp_dist = signed_distance.distance();
                    if (BaseData.should_update_perpendicular_distance(&perp_dist, point_to_b_delta, b_tangent)) {
                        if (this_edge.userdata.has_all_channels(.red)) {
                            self.select_red.add_edge_perpendicular_distance(perp_dist);
                        }
                        if (this_edge.userdata.has_all_channels(.green)) {
                            self.select_green.add_edge_perpendicular_distance(perp_dist);
                        }
                        if (this_edge.userdata.has_all_channels(.blue)) {
                            self.select_blue.add_edge_perpendicular_distance(perp_dist);
                        }
                    }
                    cache.b_perp_distance = perp_dist;
                }
                cache.a_domain_distance = a_domain_distance;
                cache.b_domain_distance = b_domain_distance;
            }
        }

        pub fn merge(self: *Self, other: MultiDistanceSelector) void {
            self.select_red.merge(other.chan_r);
            self.select_green.merge(other.chan_g);
            self.select_blue.merge(other.chan_b);
        }

        pub fn distance(self: Self) MultiDistance {
            return MultiDistance{
                .red = self.select_red.calculate_distance(self.point),
                .green = self.select_green.calculate_distance(self.point),
                .blue = self.select_blue.calculate_distance(self.point),
            };
        }
        pub fn median(self: Self) T {
            return self.distance().median();
        }
        pub fn distance_and_median(self: Self) DistanceAndMedian {
            const d = self.distance();
            return d.with_median();
        }

        pub fn smallest_true_distance(self: Self) SignedDistance {
            var smallest = self.select_red.min_true_distance;
            if (self.select_green.min_true_distance.less_than(smallest)) {
                smallest = self.select_green.min_true_distance;
            }
            if (self.select_blue.min_true_distance.less_than(smallest)) {
                smallest = self.select_blue.min_true_distance;
            }
            return smallest;
        }
    };
}

pub fn TrueAndMultiDistanceSelector(comptime T: type, comptime CONST: EdgeSelectorContants) type {
    return struct {
        const Self = @This();
        const Vector = Vec2.define_vec2_type(T);
        const VectorF = Vec2.define_vec2_type(Vector.F);
        const AABB = AABB2.define_aabb2_type(T);

        pub const Distance = TrueAndMultiDistance(T);
        pub const DistanceAndMedian = TrueAndMultiDistanceAndMedian(T);
        pub const EdgeType = EdgeWithUserdata(T, EdgeColor);
        pub const EdgeCache = PerpendicularDistanceEdgeCache(T);
        pub const BaseData = PerpendicularDistanceSelectorBase(T, CONST);

        true_dist_selector: TrueDistanceSelector(T) = .{},
        multi_dist_selector: MultiDistanceSelector(T) = .{},

        pub fn distance(self: Self) Distance {
            const multi: MultiDistance(T) = self.multi_dist_selector.distance();
            return Distance{
                .red = multi.red,
                .green = multi.green,
                .blue = multi.blue,
                .alpha = self.true_dist_selector.distance().alpha,
            };
        }
        pub fn median(self: Self) T {
            return self.distance().median();
        }
        pub fn distance_and_median(self: Self) DistanceAndMedian {
            const d = self.distance(self.point);
            return d.with_median();
        }
    };
}

pub const DistanceCalculationMode = enum(u8) {
    TRUE_DISTANCE,
    PERPENDICULAR_DISTANCE,
    MULTI_DISTANCE,
    TRUE_AND_MULTI_DISTANCE,

    pub fn get_edge_selector_type(comptime self: DistanceCalculationMode, comptime T: type, comptime EDGE_SELECTOR_CONSTS: EdgeSelectorContants) type {
        return switch (self) {
            .TRUE_DISTANCE => TrueDistanceSelector(T, EDGE_SELECTOR_CONSTS),
            .PERPENDICULAR_DISTANCE => PerpendicularDistanceSelector(T, EDGE_SELECTOR_CONSTS),
            .MULTI_DISTANCE => MultiDistanceSelector(T, EDGE_SELECTOR_CONSTS),
            .TRUE_AND_MULTI_DISTANCE => TrueAndMultiDistanceSelector(T, EDGE_SELECTOR_CONSTS),
        };
    }
    pub fn get_distance_type(comptime self: DistanceCalculationMode, comptime T: type) type {
        return switch (self) {
            .TRUE_DISTANCE => TrueDistance(T),
            .PERPENDICULAR_DISTANCE => PerpDistance(T),
            .MULTI_DISTANCE => MultiDistance(T),
            .TRUE_AND_MULTI_DISTANCE => TrueAndMultiDistance(T),
        };
    }
    pub fn get_distance_and_median_type(comptime self: DistanceCalculationMode, comptime T: type) type {
        return switch (self) {
            .TRUE_DISTANCE => TrueDistanceAndMedian(T),
            .PERPENDICULAR_DISTANCE => TrueDistanceAndMedian(T),
            .MULTI_DISTANCE => MultiDistanceAndMedian(T),
            .TRUE_AND_MULTI_DISTANCE => TrueAndMultiDistanceAndMedian(T),
        };
    }
    pub fn get_shape_combiner_type(comptime self: DistanceCalculationMode, comptime T: type, comptime COMBINE_MODE: ShapeCombineMode, comptime EDGE_SELECTOR_CONSTS: EdgeSelectorContants) type {
        return switch (COMBINE_MODE) {
            .SIMPLE => SimpleShapeCombiner(T, self, EDGE_SELECTOR_CONSTS),
            .OVERLAPPING => OverlappingShapeCombiner(T, self, EDGE_SELECTOR_CONSTS),
        };
    }
    pub fn get_data_grid_type(comptime self: DistanceCalculationMode, comptime T: type) type {
        return switch (self) {
            .TRUE_DISTANCE => DataGrid(DATA_GRID_DEF.with_cell_type(TrueDistance(T))),
            .PERPENDICULAR_DISTANCE => DataGrid(DATA_GRID_DEF.with_cell_type(PerpDistance(T))),
            .MULTI_DISTANCE => DataGrid(DATA_GRID_DEF.with_cell_type(MultiDistance(T))),
            .TRUE_AND_MULTI_DISTANCE => DataGrid(DATA_GRID_DEF.with_cell_type(TrueAndMultiDistance(T))),
        };
    }
};

pub const DATA_GRID_DEF = DataGridModule.GridDefinition{
    .CELL_TYPE = f32,
    .ROW_COLUMN_ORDER = .ROW_MAJOR,
    .X_ORDER = .LEFT_TO_RIGHT,
    .Y_ORDER = .BOTTOM_TO_TOP,
};

pub const ShapeCombineMode = enum(u8) {
    SIMPLE,
    OVERLAPPING,
};

pub fn SimpleShapeCombiner(comptime T: type, comptime DISTANCE_MODE: DistanceCalculationMode, comptime EDGE_SELECTOR_CONSTS: EdgeSelectorContants) type {
    return struct {
        const Self = @This();

        pub const EdgeSelector = DISTANCE_MODE.get_edge_selector_type(T, EDGE_SELECTOR_CONSTS);
        pub const EdgeCache = EdgeSelector.EdgeCache;
        pub const Distance = DISTANCE_MODE.get_distance_type(T);
        pub const DistanceAndMedian = DISTANCE_MODE.get_distance_and_median_type(T);
        pub const DataGridType = DISTANCE_MODE.get_data_grid_type(T);

        shape_edge_selector: EdgeSelector = .{},

        pub fn init_from_shape(_: *Contour, _: Allocator) Self {
            return Self{};
        }

        pub fn distance(self: Self, _: Allocator) Distance {
            return self.shape_edge_selector.distance();
        }
        pub fn median(self: Self, _: Allocator) T {
            return self.shape_edge_selector.median();
        }
        pub fn distance_and_median(self: Self, _: Allocator) DistanceAndMedian {
            return self.shape_edge_selector.distance_and_median();
        }

        pub fn edge_selector(self: Self, _: usize) EdgeSelector {
            return self.shape_edge_selector;
        }
        pub fn edge_selector_ptr(self: *Self, _: usize) *EdgeSelector {
            return &self.shape_edge_selector;
        }

        pub fn reset(self: *Self, point: Point) void {
            self.shape_edge_selector.reset(point);
        }
        pub fn free(_: *Self, _: Allocator) void {
            return;
        }
    };
}

pub fn OverlappingShapeCombiner(comptime T: type, comptime DISTANCE_MODE: DistanceCalculationMode, comptime EDGE_SELECTOR_CONSTS: EdgeSelectorContants) type {
    return struct {
        const Self = @This();

        const Vector = Vec2.define_vec2_type(T);
        pub const EdgeSelector = DISTANCE_MODE.get_edge_selector_type(T, EDGE_SELECTOR_CONSTS);
        pub const EdgeCache = EdgeSelector.EdgeCache;
        pub const Distance = DISTANCE_MODE.get_distance_type(T);
        pub const DistanceAndMedian = DISTANCE_MODE.get_distance_and_median_type(T);
        pub const DataGridType = DISTANCE_MODE.get_data_grid_type(T);

        point: Vector = .{},
        windings: List(Winding),
        selectors: List(EdgeSelector),

        pub fn init_from_shape(shape: *Contour, alloc: Allocator) Self {
            var self = Self{
                .windings = List(Winding).init_capacity(shape.contours.len, alloc),
                .selectors = List(EdgeSelector).init_capacity(shape.contours.len, alloc),
            };
            self.selectors.len = shape.contours.len;
            for (shape.contours.slice()) |*contour| {
                const idx = self.windings.append_slots_assume_capacity(1).first_idx;
                self.windings.ptr[idx] = contour.winding_orientation();
            }
            return self;
        }
        pub fn free(self: *Self, alloc: Allocator) void {
            self.windings.free(alloc);
            self.selectors.free(alloc);
        }

        pub fn edge_selector(self: Self, idx: usize) EdgeSelector {
            return self.selectors.ptr[idx];
        }
        pub fn edge_selector_ptr(self: Self, idx: usize) *EdgeSelector {
            return &self.selectors.ptr[idx];
        }

        pub fn reset(self: *Self, point: Point) void {
            self.point = point;
            for (self.selectors.slice()) |*selector| {
                selector.reset(point);
            }
        }

        pub fn distance(self: *Self, alloc: Allocator) Distance {
            const contour_count = self.selectors.len;
            var shape_edge_selector: EdgeSelector = undefined;
            var inner_edge_selector: EdgeSelector = undefined;
            var outer_edge_selector: EdgeSelector = undefined;
            var selector_distances = List(EdgeSelector.DISTANCE_AND_MEDIAN_TYPE).init_capacity(contour_count, alloc);
            defer selector_distances.free(alloc);
            selector_distances.len = contour_count;
            shape_edge_selector.reset(self.point);
            inner_edge_selector.reset(self.point);
            outer_edge_selector.reset(self.point);
            var i: u32 = 0;
            while (i < contour_count) : (i += 1) {
                const this_selector_distance = self.selectors.ptr[i].distance_and_median();
                selector_distances.ptr[i] = this_selector_distance;
                shape_edge_selector.merge(self.selectors.ptr[i]);
                if (self.windings.ptr[i] == .WINDING_CCW and this_selector_distance.median >= 0) {
                    inner_edge_selector.merge(self.selectors.ptr[i]);
                }
                if (self.windings.ptr[i] == .WINDING_CW and this_selector_distance.median <= 0) {
                    outer_edge_selector.merge(self.selectors.ptr[i]);
                }
            }

            const shape_distance = shape_edge_selector.distance_and_median();
            const inner_distance = inner_edge_selector.distance_and_median();
            const outer_distance = outer_edge_selector.distance_and_median();
            var final_distance = @TypeOf(shape_distance).init_max_negative();
            var winding: Winding = .COLINEAR;
            if (inner_distance.median >= 0 and inner_distance.median <= @abs(outer_distance.median)) {
                final_distance = inner_distance;
                winding = .WINDING_CCW;
                i = 0;
                while (i < contour_count) : (i += 1) {
                    if (self.windings.ptr[i] == .WINDING_CCW) {
                        const contour_distance = selector_distances.ptr[i];
                        if (@abs(contour_distance.median) < @abs(outer_distance.median) and contour_distance.median > final_distance.median) {
                            final_distance = contour_distance;
                        }
                    }
                }
            } else if (outer_distance.median <= 0 and @abs(outer_distance.median) < @abs(inner_distance.median)) {
                final_distance = outer_distance;
                winding = .WINDING_CW;
                i = 0;
                while (i < contour_count) : (i += 1) {
                    if (self.windings.ptr[i] == .WINDING_CW) {
                        const contour_distance = selector_distances.ptr[i];
                        if (@abs(contour_distance.median) < @abs(inner_distance.median) and contour_distance.median < final_distance.median) {
                            final_distance = contour_distance;
                        }
                    }
                }
            } else {
                return shape_distance.distance;
            }

            i = 0;
            while (i < contour_count) : (i += 1) {
                if (self.windings.ptr[i] != winding) {
                    const contour_distance = selector_distances.ptr[i];
                    if (contour_distance.median * final_distance.median >= 0 and @abs(contour_distance.median) < @abs(final_distance.median)) {
                        final_distance = contour_distance;
                    }
                }
            }
            if (final_distance.median == shape_distance.median) {
                final_distance = shape_distance;
            }
            return final_distance.distance;
        }
        pub fn median(self: Self, alloc: Allocator) T {
            return self.distance(alloc).median();
        }
        pub fn distance_and_median(self: Self, alloc: Allocator) DistanceAndMedian {
            return self.distance(alloc).with_median();
        }
    };
}
pub const ErrorFlags = Flags.Flags(enum(u8) {
    NONE = 0,
    /// distance marked as potentially causing interpolation errors.
    ERROR = 1,
    /// distance marked as protected. Protected distances are only given the error flag if they cause inversion artifacts.
    PROTECTED = 2,
}, enum(u8) {});

pub const ErrorDataGrid = DataGrid(DATA_GRID_DEF.with_cell_type(ErrorFlags));

// pub fn MultiSignedDistanceFieldErrorCorrector(comptime T: type) type {
//     return struct {
//         const Self = @This();
//         const Vector = Vec2.define_vec2_type(T);

//         error_grid: ErrorDataGrid = .{},
//         transform: Transformation = .{},
//         /// The minimum ratio between the actual and maximum expected distance delta to be considered an error.
//         min_deviation_ratio: Float = DEFAULT_MIN_ERROR_DEVIATION_RATIO,
//         /// The minimum ratio between the pre-correction distance error and the post-correction distance error.
//         min_improve_ratio: Float = DEFAULT_MIN_ERROR_IMPROVE_RATIO,

//         pub fn init(stencil: Bitmap(ErrorStencilBitmapDef), transform: Transformation) Self {
//             var self = Self{
//                 .stencil = stencil,
//                 .transform = transform,
//             };
//             self.stencil.fill_all(ErrorStencilBitmap.Pixel{ .raw = .{ErrorFlags.from_flag(.NONE)} });
//             return self;
//         }

//         pub fn protect_all(self: *Self) void {
//             var y: u32 = 0;
//             var x: u32 = undefined;
//             while (y < self.stencil.height) : (y += 1) {
//                 x = 0;
//                 const row = self.stencil.get_h_scanline_native(0, y, self.stencil.width);
//                 while (x < self.stencil.width) : (x += 1) {
//                     row.ptr[x].set(.flags, ErrorFlags.from_flag(.PROTECTED));
//                 }
//             }
//         }

//         pub fn protect_corners(self: *Self, shape: *Shape) void {
//             if (self.stencil.height == 0 or self.stencil.width == 0) return;
//             for (shape.contours.slice()) |*contour| {
//                 if (!contour.edges.is_empty()) {
//                     var prev_edge = contour.edges.get_last().edge;
//                     var this_edge: *EdgeSegment = undefined;
//                     for (contour.edges.slice()) |edge_ref| {
//                         this_edge = edge_ref.edge;
//                         const common_color = prev_edge.color.bit_and(this_edge.color).as_flags();
//                         // If the color changes from prevEdge to edge, this is a corner.
//                         if (common_color.has_one_or_zero_bits_set()) {
//                             // Find the four pixels that envelop the corner and mark them as protected.
//                             const p = self.transform.projection.project(this_edge.interp_point(0));
//                             const min_x: i32 = @intFromFloat(p.x - 0.5);
//                             const min_y: i32 = @intFromFloat(p.y - 0.5);
//                             const max_x = min_x + 1;
//                             const max_y = min_y + 1;
//                             // Check that the positions are within bounds.
//                             const min_x_in_bounds = min_x >= 0;
//                             const min_y_in_bounds = min_y >= 0;
//                             const max_x_in_bounds = max_x < self.stencil.width;
//                             const max_y_in_bounds = max_y < self.stencil.height;
//                             // Protect the corner pixels that are in bounds
//                             if (min_x_in_bounds) {
//                                 if (min_y_in_bounds) {
//                                     self.stencil.set_pixel_channel_with_origin(.bot_left, @intCast(min_x), @intCast(min_y), .flags, ErrorFlags.from_flag(.PROTECTED));
//                                 }
//                                 if (max_y_in_bounds) {
//                                     self.stencil.set_pixel_channel_with_origin(.bot_left, @intCast(min_x), @intCast(max_y), .flags, ErrorFlags.from_flag(.PROTECTED));
//                                 }
//                             }
//                             if (max_x_in_bounds) {
//                                 if (min_y_in_bounds) {
//                                     self.stencil.set_pixel_channel_with_origin(.bot_left, @intCast(max_x), @intCast(min_y), .flags, ErrorFlags.from_flag(.PROTECTED));
//                                 }
//                                 if (max_y_in_bounds) {
//                                     self.stencil.set_pixel_channel_with_origin(.bot_left, @intCast(max_x), @intCast(max_y), .flags, ErrorFlags.from_flag(.PROTECTED));
//                                 }
//                             }
//                         }
//                         prev_edge = this_edge;
//                     }
//                 }
//             }
//         }

//         pub fn protect_edges(self: *Self, comptime NUM_CHANNELS: comptime_int, msdf_region: FloatBitmap(NUM_CHANNELS)) void {
//             const BMP = FloatBitmap(NUM_CHANNELS);
//             const edge_util = EdgeMaskFuncs(NUM_CHANNELS);
//             var radius: Float = undefined;
//             // Horizontal pixel pairs
//             radius = PROTECTION_RADIUS_TOLERANCE * self.transform.projection.un_project_vec(Vector.new(self.transform.distance_mapping.calc_delta(.new(1)), 0)).length();
//             var y: u32 = 0;
//             var x: u32 = undefined;
//             while (y < msdf_region.height) : (y += 1) {
//                 x = 0;
//                 const row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y);
//                 while (x < msdf_region.width - 1) : (x += 1) {
//                     const left = row_ptr[x];
//                     const right = row_ptr[x + 1];
//                     const left_median = left.median_of_3_channels(.red, .green, .blue);
//                     const right_median = right.median_of_3_channels(.red, .green, .blue);
//                     if (@abs(left_median - 0.5) + @abs(right_median - 0.5) < radius) {
//                         const edge_mask = edge_util.edge_mask_between_pixels(left, right);
//                         var stencil_ptr = self.stencil.get_pixel_ptr_with_origin(.bot_left, x, y);
//                         edge_util.protect_extreme_channels(stencil_ptr, left, left_median, edge_mask);
//                         stencil_ptr = self.stencil.move_pixel_ptr_with_origin(.bot_left, 1, 0, stencil_ptr);
//                         edge_util.protect_extreme_channels(stencil_ptr, right, right_median, edge_mask);
//                     }
//                 }
//             }
//             // Vertical pixel pairs
//             radius = PROTECTION_RADIUS_TOLERANCE * self.transform.projection.un_project_vec(Vector.new(0, self.transform.distance_mapping.calc_delta(.new(1)))).length();
//             y = 0;
//             while (y < msdf_region.height - 1) : (y += 1) {
//                 x = 0;
//                 const top_row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y + 1);
//                 const bot_row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y);
//                 while (x < msdf_region.width) : (x += 1) {
//                     const top = top_row_ptr[x];
//                     const bottom = bot_row_ptr[x];
//                     const top_median = top.median_of_3_channels(.red, .green, .blue);
//                     const bottom_median = bottom.median_of_3_channels(.red, .green, .blue);
//                     if (@abs(bottom_median - 0.5) + @abs(top_median - 0.5) < radius) {
//                         const edge_mask = edge_util.edge_mask_between_pixels(bottom, top);
//                         var stencil_ptr = self.stencil.get_pixel_ptr_with_origin(.bot_left, x, y);
//                         edge_util.protect_extreme_channels(stencil_ptr, bottom, bottom_median, edge_mask);
//                         stencil_ptr = self.stencil.move_pixel_ptr_with_origin(.bot_left, 0, 1, stencil_ptr);
//                         edge_util.protect_extreme_channels(stencil_ptr, top, top_median, edge_mask);
//                     }
//                 }
//             }
//             // Diagonal pixel pairs
//             radius = PROTECTION_RADIUS_TOLERANCE * self.transform.projection.un_project_vec(Vector.new_same_xy(self.transform.distance_mapping.calc_delta(.new(1)))).length();
//             y = 0;
//             while (y < msdf_region.height - 1) : (y += 1) {
//                 x = 0;
//                 const top_row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y + 1);
//                 const bot_row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y);
//                 while (x < msdf_region.width - 1) : (x += 1) {
//                     const top_left = top_row_ptr[x];
//                     const bottom_left = bot_row_ptr[x];
//                     const top_right = top_row_ptr[x + 1];
//                     const bottom_right = bot_row_ptr[x + 1];
//                     const top_left_median = top_left.median_of_3_channels(.red, .green, .blue);
//                     const bottom_left_median = bottom_left.median_of_3_channels(.red, .green, .blue);
//                     const top_right_median = top_right.median_of_3_channels(.red, .green, .blue);
//                     const bottom_right_median = bottom_right.median_of_3_channels(.red, .green, .blue);
//                     if (@abs(top_left_median - 0.5) + @abs(bottom_right_median - 0.5) < radius) {
//                         const edge_mask = edge_util.edge_mask_between_pixels(bottom_right, top_left);
//                         var stencil_ptr = self.stencil.get_pixel_ptr_with_origin(.bot_left, x + 1, y);
//                         edge_util.protect_extreme_channels(stencil_ptr, bottom_right, bottom_right_median, edge_mask);
//                         stencil_ptr = self.stencil.move_pixel_ptr_with_origin(.bot_left, -1, 1, stencil_ptr);
//                         edge_util.protect_extreme_channels(stencil_ptr, top_left, top_left_median, edge_mask);
//                     }
//                     if (@abs(top_right_median - 0.5) + @abs(bottom_left_median - 0.5) < radius) {
//                         const edge_mask = edge_util.edge_mask_between_pixels(bottom_left, top_right);
//                         var stencil_ptr = self.stencil.get_pixel_ptr_with_origin(.bot_left, x, y);
//                         edge_util.protect_extreme_channels(stencil_ptr, bottom_left, bottom_left_median, edge_mask);
//                         stencil_ptr = self.stencil.move_pixel_ptr_with_origin(.bot_left, 1, 1, stencil_ptr);
//                         edge_util.protect_extreme_channels(stencil_ptr, top_right, top_right_median, edge_mask);
//                     }
//                 }
//             }
//         }

//         pub fn find_errors_msdf_only(self: *Self, comptime NUM_CHANNELS: comptime_int, msdf_region: FloatBitmap(NUM_CHANNELS), alloc: Allocator) void {
//             // Compute the expected deltas between values of horizontally, vertically, and diagonally adjacent texels.
//             const horizontal_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new(self.transform.distance_mapping.calc_delta(.new(1)), 0)).length();
//             const vertical_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new(0, self.transform.distance_mapping.calc_delta(.new(1)))).length();
//             const diagonal_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new_same_xy(self.transform.distance_mapping.calc_delta(.new(1)))).length();
//             // Inspect all texels.
//             var y: u32 = 0;
//             var x: u32 = undefined;
//             while (y < msdf_region.height) : (y += 1) {
//                 x = 0;
//                 while (x < msdf_region.width) : (x += 1) {
//                     const pixel = msdf_region.get_pixel_native(x, y);
//                     const pixel_median = pixel.median_of_3_channels(.red, .green, .blue);
//                     const stencil_flag_ptr: *ErrorFlags = self.stencil.get_pixel_channel_ptr_native(x, y, .flags);
//                     const is_protected = stencil_flag_ptr.has_flag(.PROTECTED);
//                     const horizontal_classifier = BaseArtifactClassifier.new(horizontal_span, is_protected);
//                     const vertical_classifier = BaseArtifactClassifier.new(vertical_span, is_protected);
//                     const diagonal_classifier = BaseArtifactClassifier.new(diagonal_span, is_protected);
//                     const check = ClassifierFuncs(BaseArtifactClassifier, NUM_CHANNELS);
//                     // Mark current pixel with the error flag if an artifact occurs when it's interpolated with any of its 8 neighbors.
//                     stencil_flag_ptr.set_one_bit_if_true(.ERROR,
//                         //
//                         (x > 0 and check.has_linear_artifact(horizontal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), alloc)) or
//                             (x < msdf_region.width - 1 and check.has_linear_artifact(horizontal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), alloc)) or
//                             (y > 0 and check.has_linear_artifact(vertical_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x, y - 1), alloc)) or
//                             (y < msdf_region.height - 1 and check.has_linear_artifact(vertical_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x, y + 1), alloc)) or
//                             (x > 0 and y > 0 and check.has_diagonal_artifact(diagonal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), msdf_region.get_pixel_native(x, y - 1), msdf_region.get_pixel_native(x - 1, y - 1), alloc)) or
//                             (x < msdf_region.width - 1 and y > 0 and check.has_diagonal_artifact(diagonal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), msdf_region.get_pixel_native(x, y - 1), msdf_region.get_pixel_native(x + 1, y - 1), alloc)) or
//                             (x > 0 and y < msdf_region.height - 1 and check.has_diagonal_artifact(diagonal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), msdf_region.get_pixel_native(x, y + 1), msdf_region.get_pixel_native(x - 1, y + 1), alloc)) or
//                             (x < msdf_region.width - 1 and y < msdf_region.height - 1 and check.has_diagonal_artifact(diagonal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), msdf_region.get_pixel_native(x, y + 1), msdf_region.get_pixel_native(x + 1, y + 1), alloc))
//                             //
//                     );
//                 }
//             }
//         }

//         pub fn find_errors_msdf_and_shape(self: *Self, comptime CONTOUR_COMBINER_TYPE: type, comptime NUM_CHANNELS: comptime_int, msdf_region: FloatBitmap(NUM_CHANNELS), shape: *Shape, temp_alloc: Allocator) void {
//             // Compute the expected deltas between values of horizontally, vertically, and diagonally adjacent texels.
//             const horizontal_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new(self.transform.distance_mapping.calc_delta(.new(1)), 0)).length();
//             const vertical_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new(0, self.transform.distance_mapping.calc_delta(.new(1)))).length();
//             const diagonal_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new_same_xy(self.transform.distance_mapping.calc_delta(.new(1)))).length();
//             var distance_checker = ShapeDistanceChecker(CONTOUR_COMBINER_TYPE, NUM_CHANNELS).init(msdf_region, shape, self.transform.projection, self.transform.distance_mapping, self.min_improve_ratio, temp_alloc);
//             const check = ClassifierFuncs(ShapeDistanceChecker(CONTOUR_COMBINER_TYPE, NUM_CHANNELS).ArtifactClassifier, NUM_CHANNELS);
//             var reverse_x: u1 = 0;
//             var y: u32 = 0;
//             var x: u32 = undefined;
//             var abs_x: u32 = undefined;
//             const last_x = msdf_region.width - 1;
//             //TODO: enable some sort of optional multi-threading here?
//             // Inspect all texels.
//             while (y < msdf_region.height) : ({
//                 y += 1;
//                 reverse_x ^= 1;
//             }) {
//                 abs_x = 0;
//                 while (abs_x < msdf_region.width) : (abs_x += 1) {
//                     switch (reverse_x) {
//                         0 => {
//                             x = abs_x;
//                         },
//                         1 => {
//                             x = last_x - abs_x;
//                         },
//                     }
//                     const stencil_flag_ptr: *ErrorFlags = self.stencil.get_pixel_channel_ptr_native(x, y, .flags);
//                     if (stencil_flag_ptr.has_flag(.ERROR)) continue;
//                     const point = Point.new(num_cast(x, f32) + 0.5, num_cast(y, f32) + 0.5);
//                     distance_checker.shape_point = self.transform.projection.un_project(point);
//                     distance_checker.msdf_point = point;
//                     distance_checker.curr_pixel_ptr = msdf_region.get_pixel_ptr_native(@intCast(x), y);
//                     distance_checker.protected = stencil_flag_ptr.has_flag(.PROTECTED);
//                     const pixel = distance_checker.curr_pixel_ptr.*;
//                     const pixel_median = pixel.median_of_3_channels(.red, .green, .blue);
//                     // Mark current pixel with the error flag if an artifact occurs when it's interpolated with any of its 8 neighbors.
//                     stencil_flag_ptr.set_one_bit_if_true(.ERROR,
//                         //
//                         (x > 0 and check.has_linear_artifact(distance_checker.classifier(.new(-1, 0), horizontal_span), pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), temp_alloc)) or
//                             (x < msdf_region.width - 1 and check.has_linear_artifact(distance_checker.classifier(.new(1, 0), horizontal_span), pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), temp_alloc)) or
//                             (y > 0 and check.has_linear_artifact(distance_checker.classifier(.new(0, 1), vertical_span), pixel_median, pixel, msdf_region.get_pixel_native(x, y - 1), temp_alloc)) or
//                             (y < msdf_region.height - 1 and check.has_linear_artifact(distance_checker.classifier(.new(0, -1), vertical_span), pixel_median, pixel, msdf_region.get_pixel_native(x, y + 1), temp_alloc)) or
//                             (x > 0 and y > 0 and check.has_diagonal_artifact(distance_checker.classifier(.new(-1, 1), diagonal_span), pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), msdf_region.get_pixel_native(x, y - 1), msdf_region.get_pixel_native(x - 1, y - 1), temp_alloc)) or
//                             (x < msdf_region.width - 1 and y > 0 and check.has_diagonal_artifact(distance_checker.classifier(.new(1, 1), diagonal_span), pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), msdf_region.get_pixel_native(x, y - 1), msdf_region.get_pixel_native(x + 1, y - 1), temp_alloc)) or
//                             (x > 0 and y < msdf_region.height - 1 and check.has_diagonal_artifact(distance_checker.classifier(.new(-1, -1), diagonal_span), pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), msdf_region.get_pixel_native(x, y + 1), msdf_region.get_pixel_native(x - 1, y + 1), temp_alloc)) or
//                             (x < msdf_region.width - 1 and y < msdf_region.height - 1 and check.has_diagonal_artifact(distance_checker.classifier(.new(1, -1), diagonal_span), pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), msdf_region.get_pixel_native(x, y + 1), msdf_region.get_pixel_native(x + 1, y + 1), temp_alloc))
//                             //
//                     );
//                 }
//             }
//         }

//         pub fn apply_error_correction(self: *Self, comptime NUM_CHANNELS: comptime_int, msdf_region: FloatBitmap(NUM_CHANNELS)) void {
//             var y: u32 = 0;
//             var x: u32 = undefined;
//             var pixel_row: []FloatBitmap(NUM_CHANNELS).Pixel = undefined;
//             var stencil_row: []ErrorStencilBitmap.Pixel = undefined;
//             while (y < msdf_region.height) : (y += 1) {
//                 x = 0;
//                 pixel_row = msdf_region.get_h_scanline_native(0, y, msdf_region.width);
//                 stencil_row = self.stencil.get_h_scanline_native(0, y, msdf_region.width);
//                 while (x < msdf_region.width) : (x += 1) {
//                     const error_check = stencil_row.ptr[x].get(.flags);
//                     if (error_check.has_flag(.ERROR)) {
//                         // Set all color channels to the median.
//                         const pixel_ptr: *FloatBitmap(NUM_CHANNELS).Pixel = &pixel_row.ptr[x];
//                         const median = pixel_ptr.median_of_3_channels(.red, .green, .blue);
//                         pixel_ptr.set(.red, median);
//                         pixel_ptr.set(.green, median);
//                         pixel_ptr.set(.blue, median);
//                     }
//                 }
//             }
//         }
//     };
// }

pub const EstimatesMode = enum(u8) {
    NO_ESTIMATES,
    WITH_ESTIMATES,
    DEFAULT_ESTIMATES,
};

pub fn Estimates(comptime T: type) type {
    return struct {
        const Self = @This();

        double_root: MathX.DoubleRootEstimate(T) = .do_not_estimate_double_roots(),
        quadratic: MathX.QuadraticEstimate(T) = .do_not_estimate_quadratic(),
        linear: MathX.LinearEstimate(T) = .do_not_estimate_linear(),

        pub fn new_estimates(double_root: MathX.DoubleRootEstimate(T), quadratic: MathX.QuadraticEstimate(T), linear: MathX.LinearEstimate(T)) Self {
            return Self{
                .double_root = double_root,
                .quadratic = quadratic,
                .linear = linear,
            };
        }

        pub fn default_estimates() Self {
            return DEFAULT;
        }

        pub const DEFAULT = Self{
            .double_root = .estimate_double_roots_when_u_minus_v_less_than_N_times_u_plus_v(DEFAULT_DOUBLE_ROOT_ESTIMATE_RATIO),
            .quadratic = .estimate_quadratic_when_quadratic_coeff_more_than_N_times_cubic(DEFAULT_QUADRATIC_ESTIMATE_RATIO),
            .linear = .estimate_linear_when_linear_coeff_more_than_N_times_quadratic(DEFAULT_LINEAR_ESTIMATE_RATIO),
        };
    };
}
pub fn EstimatesSetting(comptime T: type) type {
    return union(EstimatesMode) {
        const Self = @This();

        NO_ESTIMATES: void,
        WITH_ESTIMATES: Estimates(T),
        DEFAULT_ESTIMATES: void,

        pub fn no_estimates() Self {
            return Self{ .NO_ESTIMATES = void{} };
        }
        pub fn with_estimates(estimates: Estimates(T)) Self {
            return Self{ .WITH_ESTIMATES = estimates };
        }
        pub fn default_estimates() Self {
            return Self{ .DEFAULT_ESTIMATES = void{} };
        }

        pub fn get_estimates(self: Self) Estimates(T) {
            switch (self) {
                .NO_ESTIMATES => Estimates(T){},
                .WITH_ESTIMATES => |est| est,
                .DEFAULT_ESTIMATES => Estimates(T).DEFAULT,
            }
        }
    };
}

pub const TransformMode = enum(u8) {
    NONE,
    STEPS_ALTER_ORIGINAL,
    STEPS_PRESERVE_ORIGINAL,
    MATRIX_ALTER_ORIGINAL,
    MATRIX_PRESERVE_ORIGINAL,
};

pub const TransformModeNoAlter = enum(u8) {
    NONE,
    STEPS,
    MATRIX,
};

pub fn Transform(comptime T: type) type {
    const VEC = Vec2.define_vec2_type(T);
    const MAT = Mat3x3.define_matrix_3x3_type(T);
    return union(TransformMode) {
        const Self = @This();

        NONE: void,
        STEPS_ALTER_ORIGINAL: []const VEC.TransformStep,
        STEPS_PRESERVE_ORIGINAL: []const VEC.TransformStep,
        MATRIX_ALTER_ORIGINAL: MAT,
        MATRIX_PRESERVE_ORIGINAL: MAT,

        pub fn none() Self {
            return Self{ .NONE = void{} };
        }
        pub fn steps_alter_original(s: []const VEC.TransformStep) Self {
            return Self{ .STEPS_ALTER_ORIGINAL = s };
        }
        pub fn steps_preserve_original(s: []const VEC.TransformStep) Self {
            return Self{ .STEPS_PRESERVE_ORIGINAL = s };
        }
        pub fn matrix_alter_original(m: MAT) Self {
            return Self{ .MATRIX_ALTER_ORIGINAL = m };
        }
        pub fn matrix_preserve_original(m: MAT) Self {
            return Self{ .MATRIX_PRESERVE_ORIGINAL = m };
        }

        pub fn to_no_alter(self: Self) TransformNoAlter(T) {
            return switch (self) {
                .NONE, .STEPS_ALTER_ORIGINAL, .MATRIX_ALTER_ORIGINAL => TransformNoAlter(T){ .NONE = void{} },
                .STEPS_PRESERVE_ORIGINAL => |s| TransformNoAlter(T).steps(s),
                .MATRIX_PRESERVE_ORIGINAL => |m| TransformNoAlter(T).matrix(m),
            };
        }
    };
}

pub fn TransformNoAlter(comptime T: type) type {
    const VEC = Vec2.define_vec2_type(T);
    const MAT = Mat3x3.define_matrix_3x3_type(T);
    return union(TransformModeNoAlter) {
        const Self = @This();

        NONE: void,
        STEPS: []const VEC.TransformStep,
        MATRIX: MAT,

        pub fn none() Self {
            return Self{ .NONE = void{} };
        }
        pub fn steps(s: []const VEC.TransformStep) Self {
            return Self{ .STEPS = s };
        }
        pub fn matrix(m: MAT) Self {
            return Self{ .MATRIX = m };
        }
    };
}

pub const ScanlineAntiAliasMode = enum(u8) {
    NONE,
    X_ONLY_LINEAR_FALLOFF,
    X_ONLY_EXPONENTIAL_FALLOFF,
};

pub fn ScanlineRasterizer(comptime T: type, comptime EDGE_USERDATA: type, comptime EDGE_USERDATA_DEFAULT_VALUE: EDGE_USERDATA, comptime SLOPE_TYPE: type, comptime OUTPUT_DATA_GRID_DEF: DataGridModule.GridDefinition) type {
    return struct {
        const Self = @This();
        const Vector = Vec2.define_vec2_type(T);
        const ShapeType = Contour(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT_VALUE);
        const CompositeShapeType = Shape(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT_VALUE);
        const EdgeType = EdgeWithUserdata(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT_VALUE);
        const OutputGrid = DataGrid(OUTPUT_DATA_GRID_DEF);
        const ScanlineType = Scanline(T, .sign, SLOPE_TYPE);

        scanline: ScanlineType = .{},

        pub fn init_from_scanline(scanline: ScanlineType) Self {
            var self = Self{
                .scanline = scanline,
            };
            self.scanline.reset();
            return self;
        }

        pub fn init_with_intersection_capacity(capacity: u32, alloc: Allocator) Self {
            return Self{
                .scanline = ScanlineType.init_cap(capacity, alloc),
            };
        }

        pub fn reset(self: *Self) void {
            self.scanline.reset();
        }

        pub fn free(self: *Self, alloc: Allocator) void {
            self.scanline.free(alloc);
        }

        pub fn intersection_fill_at_idx_nonzero(self: *Self, idx: u32) u1 {
            return @intFromBool(self.scanline.intersections.ptr[idx].inter.slope != 0);
        }

        fn default_lerp(unfill: OUTPUT_DATA_GRID_DEF.CELL_TYPE, fill: OUTPUT_DATA_GRID_DEF.CELL_TYPE, percent: f32) OUTPUT_DATA_GRID_DEF.CELL_TYPE {
            const unfill_float = num_cast(unfill, f32);
            const fill_float = num_cast(fill, f32);
            var lerp_float = MathX.lerp(unfill_float, fill_float, percent);
            if (Types.type_is_int(OUTPUT_DATA_GRID_DEF.CELL_TYPE)) {
                lerp_float = @round(lerp_float);
            }
            var lerp_final = num_cast(lerp_float, OUTPUT_DATA_GRID_DEF.CELL_TYPE);
            if (unfill < fill) {
                lerp_final = MathX.clamp(unfill, lerp_final, fill);
            } else {
                lerp_final = MathX.clamp(fill, lerp_final, unfill);
            }
            return lerp_final;
        }

        pub fn debug_rasterize_intersections_only(self: *Self, shape: *CompositeShapeType, output_grid: OutputGrid, no_intersection_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, intersection_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, estimates: Estimates(T), scanline_allocator: Allocator) void {
            output_grid.fill_all(no_intersection_val);
            for (0..output_grid.height) |y_usize| {
                const y: u32 = @intCast(y_usize);
                const yy = num_cast(y, T) + 0.5;
                shape.remake_horizontal_scanline_intersections(yy, .sign, SLOPE_TYPE, &self.scanline, scanline_allocator, estimates);
                self.scanline.sort_and_sum();
                const output_row: []OUTPUT_DATA_GRID_DEF.CELL_TYPE = output_grid.get_h_scanline(0, y, output_grid.width);
                for (self.scanline.intersections.slice()) |isect| {
                    const isect_x = isect.inter.point;
                    const isect_x_floor: u32 = @intFromFloat(@floor(isect_x));
                    if (isect_x_floor >= 0 and isect_x_floor < output_row.len) {
                        output_row.ptr[isect_x_floor] = intersection_val;
                    }
                }
            }
        }

        pub fn debug_rasterize_contours(_: *Self, shape: *CompositeShapeType, output_grid: OutputGrid, empty_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, edge_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, steps_per_edge: u32, guaranteed_within_bitmap: bool) void {
            output_grid.fill_all(empty_val);
            const step: f32 = 1.0 / num_cast(steps_per_edge, f32);
            const steps_per_edge_minus_one = steps_per_edge - 1;
            var curr_percent: f32 = 0;
            for (shape.contours.slice()) |*contour| {
                for (contour.edges.slice()) |*edge| {
                    curr_percent = 0.0;
                    for (0..steps_per_edge_minus_one) |_| {
                        const point = edge.lerp(curr_percent);
                        const point_floor = point.floor();
                        const point_floor_int = point_floor.to_new_type(u32);
                        if (guaranteed_within_bitmap or (point_floor_int.x >= 0 and point_floor_int.x < output_grid.width and point_floor_int.y >= 0 and point_floor_int.y < output_grid.height)) {
                            output_grid.set_cell(point_floor_int.x, point_floor_int.y, edge_val);
                        }
                        curr_percent += step;
                    }
                    const point = edge.lerp(1.0);
                    const point_floor = point.floor();
                    const point_floor_int = point_floor.to_new_type(u32);
                    if (guaranteed_within_bitmap or (point_floor_int.x >= 0 and point_floor_int.x < output_grid.width and point_floor_int.y >= 0 and point_floor_int.y < output_grid.height)) {
                        output_grid.set_cell(point_floor_int.x, point_floor_int.y, edge_val);
                    }
                }
            }
        }

        pub fn rasterize_to_existing_data_grid_default_lerp(self: *Self, shape: *CompositeShapeType, anti_alias: ScanlineAntiAliasMode, output_grid: OutputGrid, unfill_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, fill_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, estimates: Estimates(T), scanline_allocator: Allocator) void {
            return self.rasterize_to_existing_data_grid(shape, anti_alias, output_grid, unfill_val, fill_val, default_lerp, estimates, scanline_allocator);
        }

        pub fn rasterize_to_existing_data_grid(self: *Self, shape: *CompositeShapeType, anti_alias: ScanlineAntiAliasMode, output_grid: OutputGrid, unfill_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, fill_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, lerp_func: *const fn (unfill_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, fill_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE, percent_filled: f32) OUTPUT_DATA_GRID_DEF.CELL_TYPE, estimates: Estimates(T), scanline_allocator: Allocator) void {
            for (0..output_grid.height) |y_usize| {
                // std.debug.print("\nscanline y = {d}", .{y_usize}); //DEBUG
                const y: u32 = @intCast(y_usize);
                const yy = num_cast(y, T) + 0.5;
                shape.remake_horizontal_scanline_intersections(yy, .sign, SLOPE_TYPE, &self.scanline, scanline_allocator, estimates);
                self.scanline.sort_and_sum();
                const output_row: []OUTPUT_DATA_GRID_DEF.CELL_TYPE = output_grid.get_h_scanline(0, y, output_grid.width);
                // assert_with_reason(self.scanline.intersections.is_sorted(.entire_list(), ScanlineType.IntersectionType.x_greater_than), @src(), "scanline intersections not sorted", .{}); //DEBUG
                var x: u32 = 0;
                var next_x: u32 = undefined;
                var partial_fill_x: u32 = undefined;
                var whole_fill_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE = undefined;
                var partial_fill_val: OUTPUT_DATA_GRID_DEF.CELL_TYPE = undefined;
                var previous_fill: u1 = 0;
                const fills: [2]OUTPUT_DATA_GRID_DEF.CELL_TYPE = .{ unfill_val, fill_val };
                const start_percents: [2]f32 = .{ 0.0, 1.0 };
                const delta_percents: [2]f32 = .{ -1.0, 1.0 };
                var i: u32 = 0;
                var next_i: u32 = undefined;
                var intersection_x: f32 = undefined;
                var next_intersection_x: f32 = undefined;
                var next_intersection_x_floor_int: u32 = undefined;
                var intersection_x_floor: f32 = undefined;
                var next_fill: u1 = undefined;
                var partial_percent: f32 = undefined;
                var partial_delta: f32 = undefined;
                var partial_remainder: f32 = undefined;
                // if (!self.scanline.intersections.is_empty()) {
                //     const second_fill: u1 = self.intersection_fill_at_idx_nonzero(0);
                //     previous_fill = second_fill ^ 1;
                // }
                while (i < self.scanline.intersections.len) : (i += 1) {
                    intersection_x = self.scanline.intersections.ptr[i].inter.point;
                    intersection_x_floor = @floor(intersection_x);
                    if (intersection_x_floor >= 0) break;
                }
                while (i < self.scanline.intersections.len) {
                    next_fill = self.intersection_fill_at_idx_nonzero(i);
                    if (next_fill == previous_fill) {
                        i += 1;
                        continue;
                    }
                    intersection_x = self.scanline.intersections.ptr[i].inter.point;
                    intersection_x_floor = @floor(intersection_x);
                    partial_fill_x = @intFromFloat(intersection_x_floor);
                    whole_fill_val = fills[previous_fill];
                    const max_fill_x = @min(output_grid.width, partial_fill_x);
                    @memset(output_row[x..max_fill_x], whole_fill_val);
                    if (max_fill_x >= output_grid.width) break;
                    partial_percent = start_percents[previous_fill];
                    partial_remainder = (intersection_x - intersection_x_floor);
                    partial_delta = delta_percents[next_fill] * partial_remainder;
                    partial_percent += partial_delta;
                    next_i = i + 1;
                    next_x = partial_fill_x + 1;
                    while (next_i < self.scanline.intersections.len) {
                        next_intersection_x = self.scanline.intersections.ptr[next_i].inter.point;
                        next_intersection_x_floor_int = @intFromFloat(@floor(next_intersection_x));
                        if (next_intersection_x_floor_int >= next_x) break;
                        const next_next_fill = self.intersection_fill_at_idx_nonzero(next_i);
                        if (next_next_fill == next_fill) {
                            next_i += 1;
                            continue;
                        }
                        partial_remainder = (next_intersection_x - intersection_x);
                        partial_delta = delta_percents[next_next_fill] * partial_remainder;
                        partial_percent += partial_delta;
                        i = next_i;
                        next_i += 1;
                        previous_fill = next_fill;
                        next_fill = next_next_fill;
                    }
                    partial_percent = MathX.clamp_0_to_1(partial_percent);

                    switch (anti_alias) {
                        .NONE => {
                            if (partial_percent >= 0.5) {
                                output_row.ptr[partial_fill_x] = fill_val;
                            } else {
                                output_row.ptr[partial_fill_x] = unfill_val;
                            }
                        },
                        .X_ONLY_LINEAR_FALLOFF => {
                            partial_fill_val = lerp_func(unfill_val, fill_val, 1 - partial_percent);
                            output_row.ptr[partial_fill_x] = partial_fill_val;
                        },
                        .X_ONLY_EXPONENTIAL_FALLOFF => {
                            partial_fill_val = lerp_func(unfill_val, fill_val, 1 - (partial_percent * partial_percent));
                            output_row.ptr[partial_fill_x] = partial_fill_val;
                        },
                    }
                    i = next_i;
                    x = next_x;
                    previous_fill = next_fill;
                }
                if (x < output_grid.width) {
                    @memset(output_row[x..], fills[previous_fill]);
                }
            }
        }
    };
}

fn make_test_triangle(inner_edges: *[3]EdgeWithUserdata(f32, EdgeColor, .WHITE), outer_edges: *[3]EdgeWithUserdata(f32, EdgeColor, .WHITE), shapes: *[2]Contour(f32, EdgeColor, .WHITE)) Shape(f32, EdgeColor, .WHITE) {
    const Vec = Vec2.define_vec2_type(f32);
    const EdgeType = EdgeWithUserdata(f32, EdgeColor, .WHITE);
    const ShapeType = Contour(f32, EdgeColor, .WHITE);
    const CompositeShapeType = Shape(f32, EdgeColor, .WHITE);
    const A = Vec.new(2, 2);
    const B = Vec.new(27, 52);
    const C = Vec.new(52, 2);
    const AB: EdgeType = .new_line(A, B);
    const BC: EdgeType = .new_line(B, C);
    const CA: EdgeType = .new_line(C, A);
    outer_edges[0] = AB;
    outer_edges[1] = BC;
    outer_edges[2] = CA;
    const AA = Vec.new(10, 6);
    const BB = Vec.new(27, 42);
    const CC = Vec.new(44, 6);
    const AACC: EdgeType = .new_line(AA, CC);
    const CCBB: EdgeType = .new_line(CC, BB);
    const BBAA: EdgeType = .new_line(BB, AA);
    inner_edges[0] = AACC;
    inner_edges[1] = CCBB;
    inner_edges[2] = BBAA;
    shapes[0] = ShapeType{
        .edges = .{
            .ptr = outer_edges[0..3],
            .len = 3,
            .cap = 3,
        },
    };
    shapes[1] = ShapeType{
        .edges = .{
            .ptr = inner_edges[0..3],
            .len = 3,
            .cap = 3,
        },
    };
    return CompositeShapeType{
        .contours = .{
            .ptr = shapes[0..2],
            .len = 2,
            .cap = 2,
        },
    };
}

test "Shape_rasterize_triangle" {
    const OUT_DEF = DataGridModule.GridDefinition{
        .CELL_TYPE = u8,
        .ROW_COLUMN_ORDER = .ROW_MAJOR,
        .X_ORDER = .LEFT_TO_RIGHT,
        .Y_ORDER = .TOP_TO_BOTTOM,
    };
    const alloc = std.heap.page_allocator;
    const OUT_GRID = DataGrid(OUT_DEF);
    const Raster = ScanlineRasterizer(f32, EdgeColor, .WHITE, i8, OUT_DEF);
    var raster = Raster.init_with_intersection_capacity(8, alloc);
    defer raster.free(alloc);
    var output_grid = OUT_GRID.init(54, 54, 0, alloc);
    defer output_grid.free(alloc);
    var inner: [3]EdgeWithUserdata(f32, EdgeColor, .WHITE) = undefined;
    var outer: [3]EdgeWithUserdata(f32, EdgeColor, .WHITE) = undefined;
    var shapes: [2]Contour(f32, EdgeColor, .WHITE) = undefined;
    var triangle = make_test_triangle(&inner, &outer, &shapes);
    // triangle.apply_complex_transform(&.{.skew_from_origin_x_degrees(20)});
    try std.fs.cwd().makePath("test_out/shape");
    raster.rasterize_to_existing_data_grid_default_lerp(&triangle, .NONE, output_grid, 0, 255, .default_estimates(), alloc);
    _ = try BitmapFormat.save_bitmap_to_file("test_out/shape/triangle_hard_no_antialias.bmp", OUT_DEF, output_grid, .{ .bits_per_pixel = .BPP_8 }, .NO_CONVERSION_NEEDED_ALPHA_BECOMES_COLOR_CHANNELS, alloc);
    output_grid.fill_all(0);
    raster.rasterize_to_existing_data_grid_default_lerp(&triangle, .X_ONLY_LINEAR_FALLOFF, output_grid, 0, 255, .default_estimates(), alloc);
    _ = try BitmapFormat.save_bitmap_to_file("test_out/shape/triangle_hard_antialias_x_linear.bmp", OUT_DEF, output_grid, .{ .bits_per_pixel = .BPP_8 }, .NO_CONVERSION_NEEDED_ALPHA_BECOMES_COLOR_CHANNELS, alloc);
    output_grid.fill_all(0);
    raster.rasterize_to_existing_data_grid_default_lerp(&triangle, .X_ONLY_EXPONENTIAL_FALLOFF, output_grid, 0, 255, .default_estimates(), alloc);
    _ = try BitmapFormat.save_bitmap_to_file("test_out/shape/triangle_hard_antialias_x_exponential.bmp", OUT_DEF, output_grid, .{ .bits_per_pixel = .BPP_8 }, .NO_CONVERSION_NEEDED_ALPHA_BECOMES_COLOR_CHANNELS, alloc);
}
