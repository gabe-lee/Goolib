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
const Range = Root.IList.Range;
const Vec2 = Root.Vec2;
const AABB2 = Root.AABB2;
const MathX = Root.Math;

const SignedDistance = MathX.SignedDistance;
const SignedDistanceWithPercent = MathX.SignedDistanceWithPercent;
const ScanlineIntersections = MathX.ScanlineIntersections;
const LinearEstimate = MathX.LinearEstimate;
const QuadraticEstimate = MathX.QuadraticEstimate;
const DoubleRootEstimate = MathX.DoubleRootEstimate;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

pub fn LinearBezier(comptime T: type) type {
    return struct {
        const Self = @This();

        const Point = Vec2.define_vec2_type(T);
        const PointF = Vec2.define_vec2_type(Point.F);
        const Vector = Point;
        const VectorF = PointF;
        const AABB = AABB2.define_aabb2_type(T);

        p: [2]Point,

        pub fn change_base_type(self: Self, comptime TT: type) LinearBezier(TT) {
            return LinearBezier(TT){ .p = .{
                self.p[0].to_new_type(TT),
                self.p[1].to_new_type(TT),
            } };
        }

        pub fn start(self: Self) Point {
            return self.p[0];
        }
        pub fn end(self: Self) Point {
            return self.p[1];
        }

        pub fn interp_point(self: Self, percent: anytype) Point {
            return Vector.lerp(self.p[0], self.p[1], percent);
        }

        pub fn new(start_: T, end_: T) Self {
            return Self{ .p = .{ start_, end_ } };
        }

        pub fn delta(self: Self) Vector {
            return self.end.subtract(self.start);
        }

        pub fn tangent_at_interp(self: Self, percent: T) Vector {
            _ = percent;
            return self.delta();
        }

        pub fn tangent_change_at_interp(self: Self, percent: T) Vector {
            _ = percent;
            _ = self;
            return Vector.ZERO_ZERO;
        }

        pub fn length(self: Self) Vector {
            return self.delta().length();
        }

        pub fn minimum_signed_distance_from_point(self: Self, point: Point) SignedDistanceWithPercent(T) {
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
        pub fn horizontal_intersections(self: Self, y_value: T) ScanlineIntersections(1, T) {
            var result = ScanlineIntersections(1, T){};
            if ((y_value >= self.p[0].y and y_value < self.p[1].y) or (y_value >= self.p[1].y and y_value < self.p[0].y)) {
                const slope = self.p[1].y - self.p[0].y;
                const percent = (y_value - self.p[0].y) / slope;
                result.points[0].x = MathX.weighted_average(self.p[0].x, self.p[1].x, percent);
                result.points[0].y = y_value;
                result.slopes[0] = slope;
                result.count = 1;
            }
            return result;
        }
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB) void {
            aabb.combine_with_point(self.p[0]);
            aabb.combine_with_point(self.p[1]);
        }
        pub fn move_start_point(self: *Self, new_start: Point) void {
            self.p[0] = new_start;
        }
        pub fn move_end_point(self: *Self, new_end: Point) void {
            self.p[1] = new_end;
        }
        pub fn split_in_thirds(self: Self) [3]Self {
            const p_1_3 = self.interp_point(1 / 3);
            const p_2_3 = self.interp_point(2 / 3);
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

        const Point = Vec2.define_vec2_type(T);
        const PointF = Vec2.define_vec2_type(Point.F);
        const Vector = Point;
        const VectorF = PointF;
        const AABB = AABB2.define_aabb2_type(T);

        p: [3]Point,

        pub fn start(self: Self) Point {
            return self.p[0];
        }
        pub fn control(self: Self) Point {
            return self.p[1];
        }
        pub fn end(self: Self) Point {
            return self.p[2];
        }

        pub fn change_base_type(self: Self, comptime TT: type) QuadraticBezier(TT) {
            return QuadraticBezier(TT){ .p = .{
                self.p[0].to_new_type(TT),
                self.p[1].to_new_type(TT),
                self.p[2].to_new_type(TT),
            } };
        }

        pub fn interp_point(self: Self, percent: anytype) Point {
            return Vector.quadratic_interp(self.p[0], self.p[1], self.p[2], percent);
        }

        pub fn new(start_: Point, control_: Point, end_: Point) Self {
            return Self{ .p = .{ start_, control_, end_ } };
        }

        pub fn delta(self: Self) Vector {
            return self.p[2].subtract(self.p[0]);
        }

        pub fn tangent_at_interp(self: Self, percent: anytype) Vector {
            const dir_2_1 = self.p[1].subtract(self.p[0]);
            const dir_3_2 = self.p[2].subtract(self.p[1]);
            const tangent = dir_2_1.lerp(dir_3_2, percent);
            if (tangent.is_zero()) {
                return self.p[2].subtract(self.p[0]);
            }
            return tangent;
        }

        pub fn tangent_change_at_interp(self: Self, percent: anytype) Vector {
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
                curr = self_float.interp_point(s);
                delta_ = curr.subtract(last);
                total += delta_.length();
                last = curr;
            }
            delta_ = self.p[2].subtract(last);
            total += delta_.length();
            return MathX.convert_number(total, T);
        }

        pub fn minimum_signed_distance_from_point(self: Self, point: Point) SignedDistanceWithPercent(T) {
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
            const start_tangent = self.tangent_at_interp(0);
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
                    end_tangent = self.tangent_at_interp(1);
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
        pub fn horizontal_intersections(self: Self, y_value: T, comptime linear_estimate: LinearEstimate(T)) ScanlineIntersections(2, T) {
            var result = ScanlineIntersections(2, T){};
            var next_slope_sign: T = if (y_value > self.p[0].y) 1 else -1;
            result.points[0].x = self.p[0].x;
            if (self.p[0].y == y_value) {
                if (self.p[0].y < self.p[1].y or (self.p[0].y == self.p[1].y and self.p[0].y < self.p[2].y)) {
                    result.points[0].y = y_value;
                    result.slopes[0] = 1;
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
                        result.points[result.count].x = x_val;
                        result.points[result.count].y = y_value;
                        if (next_slope_sign * (segment_1.y + (percent * segment_12_diff.y)) >= 0) {
                            result.slopes[result.count] = next_slope_sign;
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
                    result.points[result.count].x = self.p[2].x;
                    result.points[result.count].y - y_value;
                    if (next_slope_sign < 0) {
                        result.slopes[result.count] = -1;
                        result.count += 1;
                        next_slope_sign = 1;
                    }
                }
            }
            if (next_slope_sign != if (y_value >= self.p[2].y) 1 else -1) {
                if (result.count > 0) {
                    result.count -= 1;
                } else {
                    if (@abs(self.p[2].y - y_value) < @abs(self.p[0].y - y_value)) {
                        result.points[result.count].x = self.p[2].x;
                        result.points[result.count].y = y_value;
                    }
                    result.slopes[result.count] = next_slope_sign;
                    result.count += 1;
                }
            }
            return result;
        }
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB) void {
            aabb.combine_with_point(self.p[0]);
            aabb.combine_with_point(self.p[2]);
            const seg_1 = self.p[1].subtract(self.p[0]);
            const seg_2 = self.p[2].subtract(self.p[1]);
            const bot = seg_1.subtract(seg_2);
            if (bot.x != 0) {
                const percent = seg_1.x / bot.x;
                if (percent > 0 and percent < 1) {
                    aabb.combine_with_point(self.interp_point(percent));
                }
            }
            if (bot.y != 0) {
                const percent = seg_1.y / bot.y;
                if (percent > 0 and percent < 1) {
                    aabb.combine_with_point(self.interp_point(percent));
                }
            }
        }
        pub fn move_start_point(self: *Self, new_start: Point) void {
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
        pub fn move_end_point(self: *Self, new_end: Point) void {
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
            const p_1_3 = self.interp_point(frac_1_3);
            const p_2_3 = self.interp_point(frac_2_3);
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

        const Point = Vec2.define_vec2_type(T);
        const PointF = Vec2.define_vec2_type(Point.F);
        const Vector = Point;
        const VectorF = PointF;
        const AABB = AABB2.define_aabb2_type(T);

        p: [4]Point,

        pub fn change_base_type(self: Self, comptime TT: type) CubicBezier(TT) {
            return CubicBezier(TT){ .p = .{
                self.p[0].to_new_type(TT),
                self.p[1].to_new_type(TT),
                self.p[2].to_new_type(TT),
                self.p[3].to_new_type(TT),
            } };
        }

        pub fn start(self: Self) Point {
            return self.p[0];
        }
        pub fn control_1(self: Self) Point {
            return self.p[1];
        }
        pub fn control_2(self: Self) Point {
            return self.p[2];
        }
        pub fn end(self: Self) Point {
            return self.p[3];
        }

        pub fn new(start_: Point, control_1_: Point, control_2_: Point, end_: Point) Self {
            return Self{ .p = .{ start_, control_1_, control_2_, end_ } };
        }

        pub fn delta(self: Self) Vector {
            return self.p[3].subtract(self.p[0]);
        }

        pub fn interp_point(self: Self, percent: T) Point {
            return Vector.cubic_interp(self.p[0], self.p[1], self.p[2], self.p[3], percent);
        }

        pub fn tangent_at_interp(self: Self, percent: T) Vector {
            const dir_12 = self.p[1].subtract(self.p[0]);
            const dir_23 = self.p[2].subtract(self.p[1]);
            const dir_34 = self.p[3].subtract(self.p[2]);
            const tangent = dir_12.quadratic_interp(dir_23, dir_34, percent);
            if (tangent.is_zero()) {
                if (percent == 0) return self.p[2].subtract(self.p[0]);
                if (percent == 1) return self.p[3].subtract(self.p[1]);
            }
            return tangent;
        }

        pub fn tangent_change_at_interp(self: Self, percent: T) Vector {
            const change_123 = (self.p[2].subtract(self.p[1])).subtract(self.p[1].subtract(self.p[0]));
            const change_234 = (self.p[3].subtract(self.p[2])).subtract(self.p[2].subtract(self.p[1]));
            return change_123.lerp(change_234, percent);
        }

        pub fn length(self: Self) Vector {
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
                curr = self_float.interp_point(s);
                delta_ = curr.subtract(last);
                total += delta_.length();
                last = curr;
            }
            delta_ = self.p[3].subtract(last);
            total += delta_.length();
            return MathX.convert_number(total, T);
        }

        pub fn minimum_signed_distance_from_point_estimate(self: Self, point: Point, comptime precision: comptime_int) SignedDistanceWithPercent(T) {
            const point_to_start_delta = self.p[0].subtract(point);
            const segment_1_delta = self.p[1].subtract(self.p[0]);
            const segment_2_delta = self.p[2].subtract(self.p[1]);
            const segment_3_delta = self.p[3].subtract(self.p[2]);
            const segment_d1_d2_delta = segment_2_delta.subtract(segment_1_delta);
            const segment_d2_d3_delta = segment_3_delta.subtract(segment_2_delta);
            const segment_dd12_dd23_delta = segment_d2_d3_delta.subtract(segment_d1_d2_delta);
            const start_tangent = self.tangent_at_interp(0);
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
                    end_tangent = self.tangent_at_interp(1);
                    min_distance = MathX.sign_nonzero(end_tangent.cross(point_to_end_delta)) * point_to_end_delta_length;
                    const point_to_end_delta_to_end_tangent_delta = end_tangent.subtract(point_to_end_delta);
                    percent = point_to_end_delta_to_end_tangent_delta.dot(end_tangent) / end_tangent.dot_self();
                }
            }
            const STEP = @as(T, 1) / @as(T, @floatFromInt(precision));
            for (0..precision) |i| {
                var t = STEP * @as(T, @floatFromInt(i));
                const t_squared = t * t;
                const t_cubed = t_squared * t;
                const t_3 = t * 3;
                const t_6 = t_3 * 2;
                const t_squared_3 = t_squared * 3;
                var point_to_current_interp_point_delta = point_to_start_delta.add_scale(segment_1_delta, t_3).add_scale(segment_d1_d2_delta, t_squared_3).add_scale(segment_dd12_dd23_delta, t_cubed);
                var calc_delta_1 = segment_1_delta.scale(3).add_scale(segment_d1_d2_delta, t_6).add_scale(segment_dd12_dd23_delta, t_squared_3);
                var calc_delta_2 = segment_d1_d2_delta.scale(6).add_scale(segment_dd12_dd23_delta, t_6);
                var better_min_dist_percent = t - (point_to_current_interp_point_delta.dot(calc_delta_1) / (calc_delta_1.dot_self() + point_to_current_interp_point_delta.dot(calc_delta_2)));
                if (better_min_dist_percent > 0 and better_min_dist_percent < 1) {
                    var remaining_steps: usize = precision;
                    while (better_min_dist_percent > 0 and better_min_dist_percent < 1) {
                        t = better_min_dist_percent;
                        point_to_current_interp_point_delta = point_to_start_delta.add_scale(segment_1_delta, t_3).add_scale(segment_d1_d2_delta, t_squared_3).add_scale(segment_dd12_dd23_delta, t_cubed);
                        calc_delta_1 = segment_1_delta.scale(3).add_scale(segment_d1_d2_delta, t_6).add_scale(segment_dd12_dd23_delta, t_squared_3);
                        if (remaining_steps <= 0) {
                            break;
                        }
                        remaining_steps -= 1;
                        calc_delta_2 = segment_d1_d2_delta.scale(6).add_scale(segment_dd12_dd23_delta, t_6);
                        better_min_dist_percent = t - (point_to_current_interp_point_delta.dot(calc_delta_1) / (calc_delta_1.dot_self() + point_to_current_interp_point_delta.dot(calc_delta_2)));
                    }
                    const point_to_current_interp_point_distance = point_to_current_interp_point_delta.length();
                    if (point_to_current_interp_point_distance < @abs(min_distance)) {
                        min_distance = MathX.sign_nonzero(calc_delta_1.cross(point_to_current_interp_point_delta)) * point_to_current_interp_point_distance;
                        percent = t;
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
        }
        pub fn reverse(self: *Self) void {
            const tmp_1 = self.p[3];
            const tmp_2 = self.p[2];
            self.p[3] = self.p[0];
            self.p[2] = self.p[1];
            self.p[0] = tmp_1;
            self.p[1] = tmp_2;
        }
        pub fn horizontal_intersections(self: Self, y_value: T, comptime double_root_estimate: DoubleRootEstimate(T), comptime quadratic_estimate: QuadraticEstimate(T), comptime linear_estimate: LinearEstimate(T)) ScanlineIntersections(3, T) {
            var result = ScanlineIntersections(2, T){};
            var next_slope_sign: T = if (y_value > self.p[0].y) 1 else -1;
            result.points[0].x = self.p[0].x;
            result.points[0].y = y_value;
            if (self.p[0].y == y_value) {
                if (self.p[0].y < self.p[1].y or (self.p[0].y == self.p[1].y and (self.p[0].y < self.p[2].y or (self.p[0].y == self.p[2].y and self.p[0].y < self.p[3].y)))) {
                    result.slopes[result.count] = 1;
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
                        result.points[result.count].x = self.p[0].x + (3 * percent * segment_1.x) + (3 * percent_squared * segment_12_diff.x) + (percent_cubed * segment_12d_23d_diff.x);
                        result.points[result.count].y = y_value;
                        if (next_slope_sign * (segment_1.y + (2 * percent * segment_12_diff.y) + (percent_squared * segment_12d_23d_diff.y)) >= 0) {
                            result.slopes[result.count] = next_slope_sign;
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
                    result.points[result.count].x = self.p[3].x;
                    result.points[result.count].y = y_value;
                    if (next_slope_sign < 0) {
                        result.slopes[result.count] = -1;
                        result.count += 1;
                        next_slope_sign = 1;
                    }
                }
            }
            if (next_slope_sign != if (y_value >= self.p[3].y) 1 else -1) {
                if (result.count > 0) {
                    result.count -= 1;
                } else {
                    if (@abs(self.p[3].y - y_value) < @abs(self.p[0].y - y_value)) {
                        result.points[result.count].x = self.p[3].x;
                        result.points[result.count].y = y_value;
                    }
                    result.slopes[result.count] = next_slope_sign;
                    result.count += 1;
                }
            }
            return result;
        }
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB, comptime linear_estimate: LinearEstimate(T)) void {
            aabb.combine_with_point(self.p[0]);
            aabb.combine_with_point(self.p[3]);
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
                    aabb.combine_with_point(self.interp_point(percent));
                }
            }
            const y_solutions = MathX.solve_quadratic_polynomial_for_zeros_advanced(vec_a.y, vec_b.y, vec_c.y, linear_estimate);
            for (y_solutions.vals[0..y_solutions.count]) |percent| {
                if (percent > 0 and percent < 1) {
                    aabb.combine_with_point(self.interp_point(percent));
                }
            }
        }
        pub fn move_start_point(self: *Self, new_start: Point) void {
            self.p[1] = self.p[1].add(new_start.subtract(self.p[0]));
            self.p[0] = new_start;
        }
        pub fn move_end_point(self: *Self, new_end: Point) void {
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
            const p_one_third = self.interp_point(frac_1_3);
            const c_2_1 = seg_1_one_third_to_seg_2_one_third_one_third.lerp(seg_2_one_third_to_seg_3_one_third_one_third, frac_2_3);
            const c_2_2 = seg_1_two_third_to_seg_2_two_third_two_third.lerp(seg_2_two_third_to_seg_3_two_third_two_third, frac_1_3);
            const p_two_third = self.interp_point(frac_2_3);
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
