//! //TODO Documentation
//! #### License: Zlib
//! #### License for original source from which this source was adapted: MIT (https://github.com/Chlumsky/msdfgen/blob/master/LICENSE.txt)

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
const Bezier = Root.Bezier;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

pub fn BezierMultiSignedDistanceFieldGenerator(comptime FLOAT_TYPE: type) type {
    assert_with_reason(Types.type_is_float(FLOAT_TYPE), @src(), "type `FLOAT_TYPE` must be a float type (f16, f32, f64, f80, f128), got type `{s}`", .{@typeName(FLOAT_TYPE)});
    return struct {
        pub const Point = Vec2.define_vec2_type(FLOAT_TYPE);
        pub const Vector = Point;
        pub const AABB = AABB2.define_aabb2_type(FLOAT_TYPE);
        pub const LinearBezier = Bezier.LinearBezier(FLOAT_TYPE);
        pub const QuadraticBezier = Bezier.QuadraticBezier(FLOAT_TYPE);
        pub const CubicBezier = Bezier.CubicBezier(FLOAT_TYPE);
        pub const SignedDistance = MathX.SignedDistance(FLOAT_TYPE);
        pub const SignedDistanceWithPercent = MathX.SignedDistanceWithPercent(FLOAT_TYPE);
        pub const ScanlineIntersections = MathX.ScanlineIntersections(3, FLOAT_TYPE);
        pub const ITERATIVE_STEPS_FOR_CUBIC_MIN_SIGNED_DISTANCE = 4;

        /// Edge color specifies which color channels an edge belongs to.
        pub const EdgeColor = enum(u8) {
            black = 0b000,
            red = 0b001,
            green = 0b010,
            yellow = 0b011,
            blue = 0b100,
            magenta = 0b101,
            cyan = 0b110,
            white = 0b111,

            pub const RED_RAW = 0b001;
            pub const GREEN_RAW = 0b010;
            pub const BLUE_RAW = 0b100;

            pub fn has_all_channels(self: EdgeColor, channels: EdgeColor) bool {
                return @intFromEnum(self) & @intFromEnum(channels) == @intFromEnum(channels);
            }
            pub fn has_any_channels(self: EdgeColor, channels: EdgeColor) bool {
                return @intFromEnum(self) & @intFromEnum(channels) != 0;
            }
            pub fn has_no_channels(self: EdgeColor, channels: EdgeColor) bool {
                return @intFromEnum(self) & @intFromEnum(channels) == 0;
            }
        };

        pub const EdgeType = enum(u8) {
            linear,
            quadratic,
            cubic,
        };

        pub const EdgePoints = union(EdgeType) {
            linear: LinearBezier,
            quadratic: QuadraticBezier,
            cubic: CubicBezier,

            pub fn new_linear(p1: Point, p2: Point) EdgePoints {
                return EdgePoints{ .linear = .new(p1, p2) };
            }
            pub fn new_quadratic(p1: Point, p2: Point, p3: Point) EdgePoints {
                return EdgePoints{ .quadratic = .new(p1, p2, p3) };
            }
            pub fn new_cubic(p1: Point, p2: Point, p3: Point, p4: Point) EdgePoints {
                return EdgePoints{ .cubic = .new(p1, p2, p3, p4) };
            }
        };

        pub const EdgeHolder = struct {};

        pub const EdgeSegment = struct {
            color: EdgeColor = .white,
            points: EdgePoints,

            pub fn create_linear(p1: Point, p2: Point, color: EdgeColor) EdgeSegment {
                return EdgeSegment{
                    .color = color,
                    .points = .new_linear(p1, p2),
                };
            }
            pub fn create_quadratic(p1: Point, p2: Point, p3: Point, color: EdgeColor) EdgeSegment {
                return EdgeSegment{
                    .color = color,
                    .points = .new_quadratic(p1, p2, p3),
                };
            }
            pub fn create_cubic(p1: Point, p2: Point, p3: Point, p4: Point, color: EdgeColor) EdgeSegment {
                return EdgeSegment{
                    .color = color,
                    .points = .new_cubic(p1, p2, p3, p4),
                };
            }
            pub fn get_start_point(self: EdgeSegment) Point {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.p[0];
                    },
                    .quadratic => |bezier| {
                        return bezier.p[0];
                    },
                    .cubic => |bezier| {
                        return bezier.p[0];
                    },
                }
            }
            pub fn get_end_point(self: EdgeSegment) Point {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.p[1];
                    },
                    .quadratic => |bezier| {
                        return bezier.p[2];
                    },
                    .cubic => |bezier| {
                        return bezier.p[3];
                    },
                }
            }
            pub fn interp_point(self: EdgeSegment, percent: FLOAT_TYPE) Point {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.interp_point(percent);
                    },
                    .quadratic => |bezier| {
                        return bezier.interp_point(percent);
                    },
                    .cubic => |bezier| {
                        return bezier.interp_point(percent);
                    },
                }
            }
            pub fn start_point(self: EdgeSegment) Point {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.start();
                    },
                    .quadratic => |bezier| {
                        return bezier.start();
                    },
                    .cubic => |bezier| {
                        return bezier.start();
                    },
                }
            }
            pub fn end_point(self: EdgeSegment) Point {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.end();
                    },
                    .quadratic => |bezier| {
                        return bezier.end();
                    },
                    .cubic => |bezier| {
                        return bezier.end();
                    },
                }
            }
            pub fn edge_type(self: EdgeSegment) EdgeType {
                return @enumFromInt(@intFromEnum(self.points));
            }
            pub fn tangent_at_interp(self: EdgeSegment, percent: FLOAT_TYPE) Vector {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.tangent_at_interp(percent);
                    },
                    .quadratic => |bezier| {
                        return bezier.tangent_at_interp(percent);
                    },
                    .cubic => |bezier| {
                        return bezier.tangent_at_interp(percent);
                    },
                }
            }
            pub fn tangent_change_at_interp(self: EdgeSegment, percent: FLOAT_TYPE) Vector {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.tangent_change_at_interp(percent);
                    },
                    .quadratic => |bezier| {
                        return bezier.tangent_change_at_interp(percent);
                    },
                    .cubic => |bezier| {
                        return bezier.tangent_change_at_interp(percent);
                    },
                }
            }
            pub fn length(self: EdgeSegment) FLOAT_TYPE {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.length();
                    },
                    .quadratic => |bezier| {
                        return bezier.length();
                    },
                    .cubic => |bezier| {
                        return bezier.length();
                    },
                }
            }
            pub fn minimum_signed_distance_from_point(self: EdgeSegment, point: Point) SignedDistanceWithPercent {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.minimum_signed_distance_from_point(point);
                    },
                    .quadratic => |bezier| {
                        return bezier.minimum_signed_distance_from_point(point);
                    },
                    .cubic => |bezier| {
                        return bezier.minimum_signed_distance_from_point_estimate(point, ITERATIVE_STEPS_FOR_CUBIC_MIN_SIGNED_DISTANCE);
                    },
                }
            }
            pub fn signed_dist_to_perpendicular_dist(self: EdgeSegment, signed_dist: SignedDistanceWithPercent, point: Point) SignedDistanceWithPercent {
                if (signed_dist.percent < 0) {
                    const start_tangent_normal = self.tangent_at_interp(0).normalize();
                    const point_to_start_delta = point.subtract(self.get_start_point());
                    const point_to_start_delta_dot_start_tangent_normal = point_to_start_delta.dot(start_tangent_normal);
                    if (point_to_start_delta_dot_start_tangent_normal < 0) {
                        const perp_dist = point_to_start_delta.cross(start_tangent_normal);
                        if (@abs(perp_dist) <= @abs(signed_dist.signed_dist.distance)) {
                            return SignedDistanceWithPercent{
                                .signed_dist = SignedDistance{
                                    .distance = perp_dist,
                                    .dot_product = 0,
                                },
                                .percent = signed_dist.percent,
                            };
                        }
                    }
                } else if (signed_dist.percent < 0) {
                    const end_tangent_normal = self.tangent_at_interp(1).normalize();
                    const point_to_end_delta = point.subtract(self.get_end_point());
                    const point_to_end_delta_dot_end_tangent_normal = point_to_end_delta.dot(end_tangent_normal);
                    if (point_to_end_delta_dot_end_tangent_normal > 0) {
                        const perp_dist = point_to_end_delta.cross(end_tangent_normal);
                        if (@abs(perp_dist) <= @abs(signed_dist.signed_dist.distance)) {
                            return SignedDistanceWithPercent{
                                .signed_dist = SignedDistance{
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
            pub fn horizontal_intersections(self: EdgeSegment, point: Point) ScanlineIntersections {
                switch (self.points) {
                    .linear => |bezier| {
                        return bezier.horizontal_intersections(point).change_max_intersections(3);
                    },
                    .quadratic => |bezier| {
                        return bezier.horizontal_intersections(point, .estimate_linear_when_linear_coeff_more_than_N_times_quadratic(1e12)).change_max_intersections(3);
                    },
                    .cubic => |bezier| {
                        return bezier.horizontal_intersections(point, .estimate_double_roots_when_u_minus_v_less_than_N_times_u_plus_v(1e-12), .estimate_quadratic_when_quadratic_coeff_more_than_N_times_cubic(1e6), .estimate_linear_when_linear_coeff_more_than_N_times_quadratic(1e12));
                    },
                }
            }
            pub fn add_bounds_to_aabb(self: EdgeSegment, aabb: *AABB) void {
                switch (self.points) {
                    .linear => |bezier| {
                        bezier.add_bounds_to_aabb(aabb);
                    },
                    .quadratic => |bezier| {
                        bezier.add_bounds_to_aabb(aabb);
                    },
                    .cubic => |bezier| {
                        bezier.add_bounds_to_aabb(aabb);
                    },
                }
            }
            pub fn reverse(self: *EdgeSegment) void {
                switch (self.points) {
                    .linear => |*bezier| {
                        bezier.reverse();
                    },
                    .quadratic => |*bezier| {
                        bezier.reverse();
                    },
                    .cubic => |*bezier| {
                        bezier.reverse();
                    },
                }
            }
            pub fn move_start_point(self: *EdgeSegment, new_start: Point) void {
                switch (self.points) {
                    .linear => |*bezier| {
                        bezier.move_start_point(new_start);
                    },
                    .quadratic => |*bezier| {
                        bezier.move_start_point(new_start);
                    },
                    .cubic => |*bezier| {
                        bezier.move_start_point(new_start);
                    },
                }
            }
            pub fn move_end_point(self: *EdgeSegment, new_end: Point) void {
                switch (self.points) {
                    .linear => |*bezier| {
                        bezier.move_end_point(new_end);
                    },
                    .quadratic => |*bezier| {
                        bezier.move_end_point(new_end);
                    },
                    .cubic => |*bezier| {
                        bezier.move_end_point(new_end);
                    },
                }
            }
            pub fn split_in_thirds(self: EdgeSegment) [3]EdgeSegment {
                switch (self.points) {
                    .linear => |bezier| {
                        const thirds = bezier.split_in_thirds();
                        return [3]EdgeSegment{
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .linear = thirds[0] },
                            },
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .linear = thirds[1] },
                            },
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .linear = thirds[2] },
                            },
                        };
                    },
                    .quadratic => |bezier| {
                        const thirds = bezier.split_in_thirds();
                        return [3]EdgeSegment{
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .quadratic = thirds[0] },
                            },
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .quadratic = thirds[1] },
                            },
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .quadratic = thirds[2] },
                            },
                        };
                    },
                    .cubic => |bezier| {
                        const thirds = bezier.split_in_thirds();
                        return [3]EdgeSegment{
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .cubic = thirds[0] },
                            },
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .cubic = thirds[1] },
                            },
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .cubic = thirds[2] },
                            },
                        };
                    },
                }
            }
            pub fn get_points(self: EdgeSegment) []Point {
                switch (self.points) {
                    .linear => |*bezier| {
                        return bezier.p[0..];
                    },
                    .quadratic => |*bezier| {
                        return bezier.p[0..];
                    },
                    .cubic => |*bezier| {
                        return bezier.p[0..];
                    },
                }
            }
        };

        pub const MultiDistance = struct {
            r: FLOAT_TYPE,
            g: FLOAT_TYPE,
            b: FLOAT_TYPE,
        };
        pub const MultiAndTrueDistance = struct {
            r: FLOAT_TYPE,
            g: FLOAT_TYPE,
            b: FLOAT_TYPE,
            a: FLOAT_TYPE,
        };

        pub const DISTANCE_DELTA_FACTOR = 1.001;

        pub const TrueDistanceSelector = struct {
            point: Point,
            min_signed_distance: SignedDistance,

            pub fn reset(self: *TrueDistanceSelector, point: Point) void {
                const delta = DISTANCE_DELTA_FACTOR * point.subtract(self.point).length();
                self.min_signed_distance.distance += MathX.sign_nonzero(self.min_signed_distance.distance) * delta;
                self.point = point;
            }

            pub fn add_edge(self: *TrueDistanceSelector, cache: *EdgeCache, prev_edge: *const EdgeSegment, edge: *const EdgeSegment, next_edge: *const EdgeSegment) void {
                _ = prev_edge;
                _ = next_edge;
                const delta = DISTANCE_DELTA_FACTOR * self.point.subtract(cache.point).length();
                if (cache.abs_distance - delta < @abs(self.min_signed_distance.distance)) {
                    const this_dist = edge.minimum_signed_distance_from_point(self.point);
                    if (this_dist.signed_dist.less_than(self.min_signed_distance)) {
                        self.min_signed_distance = this_dist.signed_dist;
                    }
                    cache.point = self.point;
                    cache.abs_distance = @abs(this_dist.signed_dist.distance);
                }
            }

            pub fn merge(self: *TrueDistanceSelector, other: TrueDistanceSelector) void {
                if (other.min_signed_distance.less_than(self.min_signed_distance)) {
                    self.min_signed_distance = other.min_signed_distance;
                }
            }

            pub fn distance(self: TrueDistanceSelector) FLOAT_TYPE {
                return self.min_signed_distance.distance;
            }

            pub const EdgeCache = struct {
                point: Point,
                abs_distance: FLOAT_TYPE,

                pub fn new(point: Point, abs_distance: FLOAT_TYPE) EdgeCache {
                    return EdgeCache{
                        .point = point,
                        .abs_distance = abs_distance,
                    };
                }
            };
        };

        pub const PerpendicularDistanceSelector = struct {
            base: BaseData = .{},
            point: Point = .{},

            pub const EdgeCache = struct {
                point: Point = .{},
                abs_distance: FLOAT_TYPE = 0,
                a_domain_distance: FLOAT_TYPE = 0,
                b_domain_distance: FLOAT_TYPE = 0,
                a_perp_distance: FLOAT_TYPE = 0,
                b_perp_distance: FLOAT_TYPE = 0,
            };

            pub fn reset(self: *PerpendicularDistanceSelector, point: Point) void {
                const delta = DISTANCE_DELTA_FACTOR * point.subtract(self.point).length();
                self.base.reset(delta);
                self.point = point;
            }

            pub fn add_edge(self: *PerpendicularDistanceSelector, cache: *EdgeCache, prev_edge: *const EdgeSegment, this_edge: *const EdgeSegment, next_edge: *const EdgeSegment) void {
                if (self.base.edge_is_relevant(cache, self.point)) {
                    const signed_distance = this_edge.minimum_signed_distance_from_point(self.point);
                    self.base.add_edge_true_distance(this_edge, signed_distance.signed_dist, signed_distance.percent);
                    cache.point = self.point;
                    cache.abs_distance = @abs(signed_distance.distance());

                    const point_to_a_delta = self.point.subtract(this_edge.start_point());
                    const point_to_b_delta = self.point.subtract(this_edge.end_point());
                    const a_tangent = this_edge.tangent_at_interp(0).normalize_may_be_zero(.norm_zero_is_zero);
                    const b_tangent = this_edge.tangent_at_interp(1).normalize_may_be_zero(.norm_zero_is_zero);
                    const prev_tangent = prev_edge.tangent_at_interp(1).normalize_may_be_zero(.norm_zero_is_zero);
                    const next_tangent = next_edge.tangent_at_interp(0).normalize_may_be_zero(.norm_zero_is_zero);
                    const prev_tan_plus_a_tan_norm = prev_tangent.add(a_tangent).normalize_may_be_zero(.norm_zero_is_zero);
                    const next_tan_plus_b_tan_norm = next_tangent.add(b_tangent).normalize_may_be_zero(.norm_zero_is_zero);
                    const a_domain_distance = point_to_a_delta.dot(prev_tan_plus_a_tan_norm);
                    const b_domain_distance = -point_to_b_delta.dot(next_tan_plus_b_tan_norm);
                    if (a_domain_distance > 0) {
                        var perp_dist = signed_distance.distance();
                        if (self.base.update_perpendicular_distance(&perp_dist, point_to_a_delta, a_tangent.negate())) {
                            perp_dist = -perp_dist;
                            self.base.add_edge_perpendicular_distance(perp_dist);
                        }
                        cache.a_perp_distance = perp_dist;
                    }
                    if (b_domain_distance > 0) {
                        var perp_dist = signed_distance.distance();
                        if (self.base.update_perpendicular_distance(&perp_dist, point_to_b_delta, b_tangent)) {
                            self.base.add_edge_perpendicular_distance(perp_dist);
                        }
                        cache.b_perp_distance = perp_dist;
                    }
                    cache.a_domain_distance = a_domain_distance;
                    cache.b_domain_distance = b_domain_distance;
                }
            }

            pub fn calculate_distance(self: PerpendicularDistanceSelector) FLOAT_TYPE {
                return self.base.calculate_distance(self.point);
            }

            pub const BaseData = struct {
                min_true_distance: SignedDistance = .{},
                min_negative_perp_distance: FLOAT_TYPE = 0,
                min_positive_perp_distance: FLOAT_TYPE = 0,
                near_edge: ?*EdgeSegment = undefined,
                near_edge_percent: FLOAT_TYPE = 0,

                pub fn reset(self: *BaseData, delta: FLOAT_TYPE) void {
                    self.min_true_distance.distance += MathX.sign_nonzero(self.min_true_distance.distance) * delta;
                    self.min_negative_perp_distance = -@abs(self.min_true_distance.distance);
                    self.min_positive_perp_distance = @abs(self.min_true_distance.distance);
                    self.near_edge = null;
                    self.near_edge_percent = 0;
                }

                pub fn edge_is_relevant(self: BaseData, cache: EdgeCache, point: Point) bool {
                    const delta = DISTANCE_DELTA_FACTOR * point.subtract(cache.point).length();
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

                pub fn add_edge_true_distance(self: *BaseData, edge: *const EdgeSegment, signed_distance: SignedDistance, percent: FLOAT_TYPE) void {
                    if (signed_distance.less_than(self.min_true_distance)) {
                        self.min_true_distance = signed_distance;
                        self.near_edge = edge;
                        self.near_edge_percent = percent;
                    }
                }

                pub fn add_edge_perpendicular_distance(self: *BaseData, dist: FLOAT_TYPE) void {
                    if (dist <= 0 and dist > self.min_negative_perp_distance) {
                        self.min_negative_perp_distance = dist;
                    }
                    if (dist >= 0 and dist < self.min_positive_perp_distance) {
                        self.min_positive_perp_distance = dist;
                    }
                }

                pub fn merge(self: *BaseData, other: BaseData) void {
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

                pub fn calculate_distance(self: BaseData, point: Point) FLOAT_TYPE {
                    const min_distance = if (self.min_true_distance.distance < 0) self.min_negative_perp_distance else self.min_positive_perp_distance;
                    if (self.near_edge) |n_edge| {
                        var signed_dist = self.min_true_distance.with_percent(self.near_edge_percent);
                        signed_dist = n_edge.signed_dist_to_perpendicular_dist(signed_dist, point);
                        if (@abs(signed_dist.distance()) < @abs(min_distance)) {
                            min_distance = signed_dist.distance();
                        }
                    }
                    return min_distance;
                }

                pub fn update_perpendicular_distance(_: BaseData, curr_perp_distance: *FLOAT_TYPE, test_point_to_edge_point_delta: Point, edge_tangent: Vector) bool {
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
        };

        pub const MultiDistanceSelector = struct {
            point: Point = .{},
            chan_r: PerpendicularDistanceSelector.BaseData = .{},
            chan_g: PerpendicularDistanceSelector.BaseData = .{},
            chan_b: PerpendicularDistanceSelector.BaseData = .{},

            pub const EdgeCache = PerpendicularDistanceSelector.EdgeCache;

            pub fn reset(self: *MultiDistanceSelector, point: Point) void {
                const delta = DISTANCE_DELTA_FACTOR * point.subtract(self.point).length();
                self.chan_r.reset(delta);
                self.chan_g.reset(delta);
                self.chan_b.reset(delta);
                self.point = point;
            }

            pub fn add_edge(self: *MultiDistanceSelector, cache: *EdgeCache, prev_edge: *const EdgeSegment, this_edge: *const EdgeSegment, next_edge: *const EdgeSegment) void {
                if ((this_edge.color.has_all_channels(.red) and self.chan_r.edge_is_relevant(cache, self.point)) or
                    (this_edge.color.has_all_channels(.green) and self.chan_g.edge_is_relevant(cache, self.point)) or
                    (this_edge.color.has_all_channels(.blue) and self.chan_b.edge_is_relevant(cache, self.point)))
                {
                    var signed_distance = this_edge.minimum_signed_distance_from_point(self.point);
                    if (this_edge.color.has_all_channels(.red)) {
                        self.chan_r.add_edge_true_distance(this_edge, signed_distance.signed_dist, signed_distance.percent);
                    }
                    if (this_edge.color.has_all_channels(.green)) {
                        self.chan_g.add_edge_true_distance(this_edge, signed_distance.signed_dist, signed_distance.percent);
                    }
                    if (this_edge.color.has_all_channels(.blue)) {
                        self.chan_b.add_edge_true_distance(this_edge, signed_distance.signed_dist, signed_distance.percent);
                    }
                    cache.point = self.point;
                    cache.abs_distance = @abs(signed_distance.distance());

                    const point_to_a_delta = self.point.subtract(this_edge.start_point());
                    const point_to_b_delta = self.point.subtract(this_edge.end_point());
                    const a_tangent = this_edge.tangent_at_interp(0).normalize_may_be_zero(.norm_zero_is_zero);
                    const b_tangent = this_edge.tangent_at_interp(1).normalize_may_be_zero(.norm_zero_is_zero);
                    const prev_tangent = prev_edge.tangent_at_interp(1).normalize_may_be_zero(.norm_zero_is_zero);
                    const next_tangent = next_edge.tangent_at_interp(0).normalize_may_be_zero(.norm_zero_is_zero);
                    const prev_tan_plus_a_tan_norm = prev_tangent.add(a_tangent).normalize_may_be_zero(.norm_zero_is_zero);
                    const next_tan_plus_b_tan_norm = next_tangent.add(b_tangent).normalize_may_be_zero(.norm_zero_is_zero);
                    const a_domain_distance = point_to_a_delta.dot(prev_tan_plus_a_tan_norm);
                    const b_domain_distance = -point_to_b_delta.dot(next_tan_plus_b_tan_norm);
                    if (a_domain_distance > 0) {
                        var perp_dist = signed_distance.distance();
                        if (self.base.update_perpendicular_distance(&perp_dist, point_to_a_delta, a_tangent.negate())) {
                            perp_dist = -perp_dist;
                            if (this_edge.color.has_all_channels(.red)) {
                                self.chan_r.add_edge_perpendicular_distance(perp_dist);
                            }
                            if (this_edge.color.has_all_channels(.green)) {
                                self.chan_g.add_edge_perpendicular_distance(perp_dist);
                            }
                            if (this_edge.color.has_all_channels(.blue)) {
                                self.chan_b.add_edge_perpendicular_distance(perp_dist);
                            }
                        }
                        cache.a_perp_distance = perp_dist;
                    }
                    if (b_domain_distance > 0) {
                        var perp_dist = signed_distance.distance();
                        if (self.base.update_perpendicular_distance(&perp_dist, point_to_b_delta, b_tangent)) {
                            if (this_edge.color.has_all_channels(.red)) {
                                self.chan_r.add_edge_perpendicular_distance(perp_dist);
                            }
                            if (this_edge.color.has_all_channels(.green)) {
                                self.chan_g.add_edge_perpendicular_distance(perp_dist);
                            }
                            if (this_edge.color.has_all_channels(.blue)) {
                                self.chan_b.add_edge_perpendicular_distance(perp_dist);
                            }
                        }
                        cache.b_perp_distance = perp_dist;
                    }
                    cache.a_domain_distance = a_domain_distance;
                    cache.b_domain_distance = b_domain_distance;
                }
            }

            pub fn merge(self: *MultiDistanceSelector, other: MultiDistanceSelector) void {
                self.chan_r.merge(other.chan_r);
                self.chan_g.merge(other.chan_g);
                self.chan_b.merge(other.chan_b);
            }

            pub fn calculate_channel_distances(self: MultiDistanceSelector) MultiDistance {
                return MultiDistance{
                    .r = self.chan_r.calculate_distance(self.point),
                    .g = self.chan_g.calculate_distance(self.point),
                    .b = self.chan_b.calculate_distance(self.point),
                };
            }

            pub fn smallest_true_distance(self: MultiDistanceSelector) SignedDistance {
                var smallest = self.chan_r.min_true_distance;
                if (self.chan_g.min_true_distance.less_than(smallest)) {
                    smallest = self.chan_g.min_true_distance;
                }
                if (self.chan_b.min_true_distance.less_than(smallest)) {
                    smallest = self.chan_b.min_true_distance;
                }
                return smallest;
            }
        };

        pub const MultiAndTrueDistanceSelector = struct {
            true_dist_selector: TrueDistanceSelector = .{},
            multi_dist_selector: MultiDistanceSelector = .{},

            pub fn calculate_all_distances(self: MultiAndTrueDistanceSelector) MultiAndTrueDistance {
                const multi = self.multi_dist_selector.calculate_channel_distances();
                return MultiAndTrueDistance{
                    .r = multi.r,
                    .g = multi.g,
                    .b = multi.b,
                    .a = self.true_dist_selector.distance(),
                };
            }
        };
    };
}
