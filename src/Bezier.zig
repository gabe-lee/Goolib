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

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

pub fn LinearBezier(comptime T: type) type {
    return struct {
        const Self = @This();

        const Point = Vec2.define_vec2_type(T);
        const Vector = Point;
        const AABB = AABB2.define_aabb2_type(T);

        p: [2]Point,

        pub fn start(self: Self) Point {
            return self.p[0];
        }
        pub fn end(self: Self) Point {
            return self.p[1];
        }

        pub fn interp_point(self: Self, percent: T) Point {
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
        pub fn horizontal_scanline_intersections(self: Self, y_value: T) ScanlineIntersections(3, T) {}
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB) void {}
        pub fn move_start_point(self: *Self, new_start: Point) void {}
        pub fn move_end_point(self: *Self, new_start: Point) void {}
        pub fn split_in_thirds(self: Self) [3]Self {}
    };
}

pub fn QuadraticBezier(comptime T: type) type {
    return struct {
        const Self = @This();

        const Point = Vec2.define_vec2_type(T);
        const Vector = Point;
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

        pub fn interp_point(self: Self, percent: T) Point {
            return Vector.quad_interp(self.p[0], self.p[1], self.p[2], percent);
        }

        pub fn new(start_: Point, control_: Point, end_: Point) Self {
            return Self{ .p = .{ start_, control_, end_ } };
        }

        pub fn delta(self: Self) Vector {
            return self.p[2].subtract(self.p[0]);
        }

        pub fn tangent_at_interp(self: Self, percent: T) Vector {
            const dir_2_1 = self.p[1].subtract(self.p[0]);
            const dir_3_2 = self.p[2].subtract(self.p[1]);
            const tangent = dir_2_1.lerp(dir_3_2, percent);
            if (tangent.is_zero()) {
                return self.p[2].subtract(self.p[0]);
            }
            return tangent;
        }

        pub fn tangent_change_at_interp(self: Self, percent: T) Vector {
            _ = percent;
            return (self.p[2].subtract(self.p[1])).subtract(self.p[1].subtract(self.p[0]));
        }

        pub fn length(self: Self) Vector {
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
            for (cubic_solutions.solution_x_vals[0..cubic_solutions.num_solutions]) |x| {
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
        pub fn horizontal_scanline_intersections(self: Self, y_value: T) ScanlineIntersections(3, T) {}
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB) void {}
        pub fn move_start_point(self: *Self, new_start: Point) void {}
        pub fn move_end_point(self: *Self, new_start: Point) void {}
        pub fn split_in_thirds(self: Self) [3]Self {}
    };
}

pub fn CubicBezier(comptime T: type) type {
    return struct {
        const Self = @This();

        const Point = Vec2.define_vec2_type(T);
        const Vector = Point;
        const AABB = AABB2.define_aabb2_type(T);

        p: [4]Point,

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
            const tangent = dir_12.quad_interp(dir_23, dir_34, percent);
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
        pub fn horizontal_scanline_intersections(self: Self, y_value: T) ScanlineIntersections(3, T) {}
        pub fn add_bounds_to_aabb(self: Self, aabb: *AABB) void {}
        pub fn move_start_point(self: *Self, new_start: Point) void {}
        pub fn move_end_point(self: *Self, new_start: Point) void {}
        pub fn split_in_thirds(self: Self) [3]Self {}
    };
}
