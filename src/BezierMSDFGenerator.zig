//! This module provides a MultiSignedDistanceField generator (see: https://github.com/Chlumsky/msdfgen)
//!
//! Most of this code is a translated version of the work done in that repository,
//! with some changes that make more sense for Zig/Goolib
//!
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
const Vec2 = Root.Vec2;
const AABB2 = Root.AABB2;
const MathX = Root.Math;
const Bezier = Root.Bezier;
const ShapeWinding = Root.CommonTypes.ShapeWinding;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

pub fn BezierMultiSignedDistanceFieldGenerator(comptime FLOAT_TYPE: type, comptime ESTIMATION_STEPS: comptime_int) type {
    assert_with_reason(Types.type_is_float(FLOAT_TYPE), @src(), "type `FLOAT_TYPE` must be a float type (f16, f32, f64, f80, f128), got type `{s}`", .{@typeName(FLOAT_TYPE)});
    return struct {
        pub const MAX_NEGATIVE_FLOAT = -math.floatMax(FLOAT_TYPE);
        pub const MAX_POSITIVE_FLOAT = math.floatMax(FLOAT_TYPE);

        pub const DISTANCE_DELTA_FACTOR = 1.001;
        pub const CORNER_DOT_EPSILON = 0.000001;
        pub const CORNER_DOT_EPSILON_MINUS_ONE = CORNER_DOT_EPSILON - 1;
        pub const CORNER_DOT_EPSILON_MINUS_ONE_SQUARED = CORNER_DOT_EPSILON_MINUS_ONE * CORNER_DOT_EPSILON_MINUS_ONE;
        pub const DECONVERGE_OVERSHOOT = 1.11111111111111111;
        pub const DECONVERGE_FACTOR = DECONVERGE_OVERSHOOT * @sqrt(1 - CORNER_DOT_EPSILON_MINUS_ONE_SQUARED) / CORNER_DOT_EPSILON_MINUS_ONE;
        pub const HALF_SQRT_5_MINUS_1 = 0.6180339887498948482045868343656381177203091798057628621354;

        pub const Point = Vec2.define_vec2_type(FLOAT_TYPE);
        pub const Vector = Point;
        pub const AABB = AABB2.define_aabb2_type(FLOAT_TYPE);
        pub const LinearBezier = Bezier.LinearBezier(FLOAT_TYPE);
        pub const QuadraticBezier = Bezier.QuadraticBezier(FLOAT_TYPE);
        pub const CubicBezier = Bezier.CubicBezier(FLOAT_TYPE);
        pub const SignedDistance = MathX.SignedDistance(FLOAT_TYPE);
        pub const SignedDistanceWithPercent = MathX.SignedDistanceWithPercent(FLOAT_TYPE);
        pub const ScanlineIntersections = MathX.ScanlineIntersections(3, FLOAT_TYPE, .axis_only, .sign, i32);
        pub const SingleScanlineIntersection = ScanlineIntersections.Intersection;

        /// Edge color specifies which color channels an edge belongs to.
        pub const EdgeColor = enum(u8) {
            black = BLACK,
            red = RED,
            green = GREEN,
            yellow = YELLOW,
            blue = BLUE,
            magenta = MAGENTA,
            cyan = CYAN,
            white = WHITE,

            pub const BLACK = 0b000;
            pub const RED = 0b001;
            pub const GREEN = 0b010;
            pub const YELLOW = 0b011;
            pub const BLUE = 0b100;
            pub const MAGENTA = 0b101;
            pub const CYAN = 0b110;
            pub const WHITE = 0b111;

            pub fn has_all_channels(self: EdgeColor, channels: EdgeColor) bool {
                return @intFromEnum(self) & @intFromEnum(channels) == @intFromEnum(channels);
            }
            pub fn has_any_channels(self: EdgeColor, channels: EdgeColor) bool {
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
                const RAND_CHOICES = [3]EdgeColor{ .cyan, .magenta, .yellow };
                return RAND_CHOICES[MathX.extract_partial_rand_from_rand(rand, 3, u64)];
            }
            pub fn switch_color(self: *EdgeColor, rand: *u64) void {
                const r = MathX.extract_partial_rand_from_rand(rand, 2, u3);
                var switched: u8 = self.raw() << (1 + r);
                switched |= switched >> 3;
                switched &= WHITE;
                self.* = .from_raw(switched);
            }
            pub fn switch_color_with_ban(self: *EdgeColor, rand: *u64, banned: EdgeColor) void {
                const overlap = self.bit_and(banned);
                if (overlap == .red or overlap == .green or overlap == .blue) {
                    self.* = overlap.bit_xor(.white);
                } else {
                    self.switch_color(rand);
                }
            }
        };

        pub const EdgeType = enum(u8) {
            point = 1,
            linear = 2,
            quadratic = 3,
            cubic = 4,
        };

        pub const Range = struct {
            low: FLOAT_TYPE,
            high: FLOAT_TYPE,

            pub fn multiplied_by(self: Range, factor: FLOAT_TYPE) Range {
                return Range{
                    .low = self.low * factor,
                    .high = self.high * factor,
                };
            }
            pub fn multiply_self(self: *Range, factor: FLOAT_TYPE) void {
                self.low *= factor;
                self.high *= factor;
            }
            pub fn divided_by(self: Range, factor: FLOAT_TYPE) Range {
                return Range{
                    .low = self.low / factor,
                    .high = self.high / factor,
                };
            }
            pub fn divide_self(self: *Range, factor: FLOAT_TYPE) void {
                self.low /= factor;
                self.high /= factor;
            }
            pub fn new(low: FLOAT_TYPE, high: FLOAT_TYPE) Range {
                return Range{
                    .low = low,
                    .high = high,
                };
            }
            pub fn new_centered_at_zero(symetrical_width: FLOAT_TYPE) Range {
                return Range{
                    .low = (-0.5) * symetrical_width,
                    .high = (0.5) * symetrical_width,
                };
            }
        };

        pub const DistanceMapping = struct {
            scale: FLOAT_TYPE = 1,
            translate: FLOAT_TYPE = 0,

            pub fn new(scale: FLOAT_TYPE, translate: FLOAT_TYPE) DistanceMapping {
                return DistanceMapping{
                    .scale = scale,
                    .translate = translate,
                };
            }
            pub fn new_from_range(range: Range) DistanceMapping {
                return DistanceMapping{
                    .scale = 1 / (range.high - range.low),
                    .translate = -range.low,
                };
            }
            pub fn new_from_range_inverse(range: Range) DistanceMapping {
                const width = (range.high - range.low);
                return DistanceMapping{
                    .scale = width,
                    .translate = range.low / if (width != 0) width else 1,
                };
            }
            pub fn inverse(self: DistanceMapping) DistanceMapping {
                return DistanceMapping{
                    .scale = 1 / self.scale,
                    .translate = -self.scale * self.translate,
                };
            }
            pub fn calc(self: DistanceMapping, distance: FLOAT_TYPE) FLOAT_TYPE {
                return self.scale * (distance + self.translate);
            }
            pub fn calc_delta(self: DistanceMapping, distance_delta: Delta) FLOAT_TYPE {
                return self.scale * (distance_delta.value + self.translate);
            }

            pub const Delta = struct {
                value: FLOAT_TYPE = 0,

                pub fn new(delta: FLOAT_TYPE) Delta {
                    return Delta{
                        .value = delta,
                    };
                }
            };
        };

        pub const EdgePoints = union(EdgeType) {
            point: Point,
            linear: LinearBezier,
            quadratic: QuadraticBezier,
            cubic: CubicBezier,

            pub fn new_point(p: Point) EdgePoints {
                return EdgePoints{ .point = p };
            }
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

            pub fn create_point(p: Point, color: EdgeColor) EdgeSegment {
                return EdgeSegment{
                    .color = color,
                    .points = .new_point(p),
                };
            }
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
                    .point => |point| {
                        return point;
                    },
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
                    .point => |point| {
                        return point;
                    },
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
                    .point => |point| {
                        return point;
                    },
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
            pub fn edge_type(self: EdgeSegment) EdgeType {
                return @enumFromInt(@intFromEnum(self.points));
            }
            pub fn tangent_at_interp(self: EdgeSegment, percent: FLOAT_TYPE) Vector {
                switch (self.points) {
                    .point => {
                        return .ZERO_ZERO;
                    },
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
                    .point => {
                        return .ZERO_ZERO;
                    },
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
                    .point => {
                        return 0;
                    },
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
            pub fn estimate_length(self: EdgeSegment) FLOAT_TYPE {
                switch (self.points) {
                    .point => {
                        return 0;
                    },
                    .linear => |bezier| {
                        return bezier.length();
                    },
                    .quadratic => |bezier| {
                        return bezier.length_estimate(ESTIMATION_STEPS);
                    },
                    .cubic => |bezier| {
                        return bezier.length_estimate(ESTIMATION_STEPS);
                    },
                }
            }
            pub fn minimum_signed_distance_from_point(self: EdgeSegment, point: Point) SignedDistanceWithPercent {
                switch (self.points) {
                    .point => |p| {
                        return SignedDistanceWithPercent.new(p.distance_to(point), 0, 0);
                    },
                    .linear => |bezier| {
                        return bezier.minimum_signed_distance_from_point(point);
                    },
                    .quadratic => |bezier| {
                        return bezier.minimum_signed_distance_from_point(point);
                    },
                    .cubic => |bezier| {
                        return bezier.minimum_signed_distance_from_point_estimate(point, ESTIMATION_STEPS);
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
            pub fn horizontal_intersections(self: EdgeSegment, y_value: FLOAT_TYPE) ScanlineIntersections {
                switch (self.points) {
                    .point => {
                        return .{};
                    },
                    .linear => |bezier| {
                        return bezier.horizontal_intersections(y_value, .axis_only, .sign, i32).change_max_intersections(3);
                    },
                    .quadratic => |bezier| {
                        return bezier.horizontal_intersections(y_value, .estimate_linear_when_linear_coeff_more_than_N_times_quadratic(1e12), .axis_only, .sign, i32).change_max_intersections(3);
                    },
                    .cubic => |bezier| {
                        return bezier.horizontal_intersections(y_value, .estimate_double_roots_when_u_minus_v_less_than_N_times_u_plus_v(1e-12), .estimate_quadratic_when_quadratic_coeff_more_than_N_times_cubic(1e6), .estimate_linear_when_linear_coeff_more_than_N_times_quadratic(1e12), .axis_only, .sign, i32);
                    },
                }
            }
            pub fn add_bounds_to_aabb(self: EdgeSegment, aabb: *AABB) void {
                switch (self.points) {
                    .point => |p| {
                        aabb.combine_with_point(p);
                    },
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
                    .point => {},
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
                    .point => |*p| {
                        p.* = new_start;
                    },
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
                    .point => |*p| {
                        p.* = new_end;
                    },
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
                    .point => |p| {
                        return [3]EdgeSegment{
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .point = p },
                            },
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .point = p },
                            },
                            EdgeSegment{
                                .color = self.color,
                                .points = EdgePoints{ .point = p },
                            },
                        };
                    },
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
                    .point => |*p| {
                        return Utils.scalar_ptr_as_single_item_slice(p);
                    },
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
            pub fn simplify_degenerate_curve(self: *EdgeSegment) void {
                recheck: switch (self.points) {
                    .point => {},
                    .linear => |bezier| {
                        if (bezier.p[0].approx_equal(bezier.p[1])) {
                            self.points = .new_point(bezier[0]);
                        }
                    },
                    .quadratic => |bezier| {
                        if (bezier.p[0].approx_equal(bezier.p[1]) or bezier.p[1].approx_equal(bezier.p[2])) {
                            self.points = .new_linear(bezier.p[0], bezier.p[2]);
                            continue :recheck self.points;
                        }
                    },
                    .cubic => |bezier| {
                        if ((bezier.p[0].approx_equal(bezier.p[1]) or bezier.p[1].approx_equal(bezier.p[3])) and (bezier.p[0].approx_equal(bezier.p[2]) or bezier.p[2].approx_equal(bezier.p[3]))) {
                            self.points = .new_linear(bezier.p[0], bezier.p[3]);
                            continue :recheck self.points;
                        }
                    },
                }
            }

            pub fn _convergent_curve_ordering_internal(p: [8]Point, control_points_before: usize, control_points_after: usize) i8 {
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
            /// For curves a, b converging at P = a->point(1) = b->point(0) with the same (opposite) direction,
            /// determines the relative ordering in which they exit P
            /// (i.e. whether a is to the left or right of b at the smallest positive radius around P)
            pub fn convergent_curve_ordering(a: *EdgeSegment, b: *EdgeSegment) i8 {
                // NOTE: this is greatly simplified from the original source code, which used a lot
                // of pointer arithmetics and unneeded for-loop copying
                var points: [8]Point = undefined;
                const CORNER_IDX = 4;
                if (a.edge_type() == .point or b.edge_type() == .point) {
                    // Not implemented - only linear, quadratic, and cubic curves supported
                    return 0;
                }
                // VERIFY unlike in the original source, the original edge segments are simplified in-place
                // this *might* cause issues somewhere else in the pipeline, but I suspect it should be fine
                a.simplify_degenerate_curve();
                b.simplify_degenerate_curve();
                const a_points = a.get_points();
                const b_points = b.get_points();
                @memcpy(points[CORNER_IDX .. CORNER_IDX + b_points.len], b_points);
                @memcpy(points[CORNER_IDX - a_points.len .. CORNER_IDX], a_points);
                return _convergent_curve_ordering_internal(points, a_points.len - 1, b_points.len - 1);
            }
        };

        pub const MultiDistance = struct {
            r: FLOAT_TYPE,
            g: FLOAT_TYPE,
            b: FLOAT_TYPE,

            pub fn init_max_negative() MultiDistance {
                return MultiDistance{
                    .r = MAX_NEGATIVE_FLOAT,
                    .g = MAX_NEGATIVE_FLOAT,
                    .b = MAX_NEGATIVE_FLOAT,
                };
            }

            pub fn median_distance(self: MultiDistance) FLOAT_TYPE {
                return MathX.median_of_3(FLOAT_TYPE, self.r, self.g, self.b);
            }
        };
        pub const MultiAndTrueDistance = struct {
            r: FLOAT_TYPE,
            g: FLOAT_TYPE,
            b: FLOAT_TYPE,
            a: FLOAT_TYPE,

            pub fn init_max_negative() MultiAndTrueDistance {
                return MultiAndTrueDistance{
                    .r = MAX_NEGATIVE_FLOAT,
                    .g = MAX_NEGATIVE_FLOAT,
                    .b = MAX_NEGATIVE_FLOAT,
                    .a = MAX_NEGATIVE_FLOAT,
                };
            }

            pub fn median_colored_distance(self: MultiAndTrueDistance) FLOAT_TYPE {
                return MathX.median_of_3(FLOAT_TYPE, self.r, self.g, self.b);
            }
        };

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

        pub const EdgeSegmentRef = struct {
            edge: *EdgeSegment,

            pub fn swap(self: *EdgeSegmentRef, other: *EdgeSegmentRef) void {
                const tmp = self.edge;
                self.edge = other.edge;
                other.edge = tmp;
            }

            pub fn deconverge_edge(self: EdgeSegmentRef, control_segment: u1, vector: Vector) void {
                goto_top_of_switch: switch (self.edge.edge_type()) {
                    .quadratic => {
                        self.edge.points = EdgePoints{ .cubic = self.edge.points.quadratic.upgrade_to_cubic() };
                        continue :goto_top_of_switch .cubic;
                    },
                    .cubic => {
                        var p: *[4]Point = &self.edge.points.cubic.p;
                        switch (control_segment) {
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

            pub fn allocate_new(alloc: Allocator) EdgeSegmentRef {
                return EdgeSegmentRef{
                    .edge = alloc.create(EdgeSegment) catch |err| assert_allocation_failure(@src(), EdgeSegment, 1, err),
                };
            }
            pub fn deallocate(self: EdgeSegmentRef, alloc: Allocator) void {
                alloc.destroy(self.edge);
            }
        };

        pub const Contour = struct {
            edges: List(EdgeSegmentRef),

            pub fn init(cap: usize, alloc: Allocator) Contour {
                return Contour{
                    .edges = List(EdgeSegmentRef).init_capacity(cap, alloc),
                };
            }
            pub fn free(self: *Contour, alloc: Allocator) void {
                self.edges.free(alloc);
            }

            pub fn add_edge(self: *Contour, edge_ref: EdgeSegmentRef, alloc: Allocator) void {
                _ = self.edges.append(edge_ref, alloc);
            }
            pub fn add_edge_return_ref(self: *Contour, edge_ref: EdgeSegmentRef, alloc: Allocator) *EdgeSegmentRef {
                const idx = self.edges.append(edge_ref, alloc);
                return self.edges.get_ptr(idx);
            }

            pub fn add_bounds_to_aabb(self: Contour, aabb: *AABB) void {
                for (self.edges.slice()) |edge_ref| {
                    edge_ref.edge.add_bounds_to_aabb(aabb);
                }
            }

            pub fn add_mitered_bounds_to_aabb(self: Contour, aabb: *AABB, border_size: FLOAT_TYPE, miter_limit: FLOAT_TYPE, polarity: FLOAT_TYPE) void {
                if (self.edges.is_empty()) return;
                var prev_tangent = self.edges.get_last().edge.tangent_at_interp(1).normalize_may_be_zero(.norm_zero_is_zero);
                var this_tangent: Vector = undefined;
                for (self.edges.slice()) |edge_ref| {
                    this_tangent = edge_ref.edge.tangent_at_interp(0).normalize_may_be_zero(.norm_zero_is_zero).negate();
                    if (polarity * prev_tangent.cross(this_tangent) >= 0) {
                        var miter_factor = miter_limit;
                        const q = 0.5 * (1 - prev_tangent.dot(this_tangent));
                        if (q > 0) {
                            miter_factor = @min(1 / @sqrt(q), miter_limit);
                        }
                        const miter_offest = prev_tangent.add(this_tangent).normalize_may_be_zero(.norm_zero_is_zero).scale(border_size * miter_factor);
                        const miter_point = edge_ref.edge.interp_point(0).add(miter_offest);
                        aabb.* = aabb.combine_with_point(miter_point);
                    }
                    prev_tangent = edge_ref.edge.tangent_at_interp(1).normalize_may_be_zero(.norm_zero_is_zero);
                }
            }

            pub fn winding_orientation(self: Contour) ShapeWinding {
                if (self.edges.is_empty()) return .COLINEAR;
                var total: FLOAT_TYPE = 0;
                if (self.edges.len == 1) {
                    const a = self.edges.ptr[0].edge.interp_point(0);
                    const b = self.edges.ptr[0].edge.interp_point(1.0 / 3.0);
                    const c = self.edges.ptr[0].edge.interp_point(2.0 / 3.0);
                    total += a.shoelace(b);
                    total += b.shoelace(c);
                    total += c.shoelace(a);
                } else if (self.edges.len == 2) {
                    const a = self.edges.ptr[0].edge.interp_point(0);
                    const b = self.edges.ptr[0].edge.interp_point(0.5);
                    const c = self.edges.ptr[1].edge.interp_point(0);
                    const d = self.edges.ptr[1].edge.interp_point(0.5);
                    total += a.shoelace(b);
                    total += b.shoelace(c);
                    total += c.shoelace(d);
                    total += d.shoelace(a);
                } else {
                    var prev: Point = self.edges.get_last().edge.interp_point(0);
                    var curr: Point = undefined;
                    for (self.edges.slice()) |edge_ref| {
                        curr = edge_ref.edge.interp_point(0);
                        total += prev.shoelace(curr);
                        prev = curr;
                    }
                }
                return num_cast(MathX.sign_convert(total, i8), ShapeWinding);
            }

            pub fn reverse(self: Contour) void {
                self.edges.reverse(.entire_list());
                for (self.edges.slice()) |edge_ref| {
                    edge_ref.edge.reverse();
                }
            }
        };

        pub const Shape = struct {
            contours: List(Contour),
            y_orientation: YAxisOrientation = .Y_DOWNWARD,

            pub fn init(cap: usize, alloc: Allocator) Shape {
                return Shape{
                    .contours = List(Contour).init_capacity(cap, alloc),
                };
            }
            pub fn free(self: *Shape, alloc: Allocator) void {
                for (self.contours.slice()) |*con| {
                    con.free(alloc);
                }
                self.contours.free(alloc);
            }

            pub fn add_empty_contour(self: *Shape, alloc: Allocator) *Contour {
                const range = self.contours.append_slots(1, alloc);
                return self.contours.get_ptr(range.first_idx);
            }

            pub fn is_valid(self: Shape) bool {
                for (self.contours.slice()) |contour| {
                    if (!contour.edges.is_empty()) {
                        var prev_corner = contour.edges.get_last().edge.interp_point(1);
                        for (contour.edges.slice()) |edge_ref| {
                            if (!edge_ref.edge.interp_point(0).approx_equal(prev_corner)) {
                                return false;
                            }
                            prev_corner = edge_ref.edge.interp_point(1);
                        }
                    }
                }
                return true;
            }

            pub fn normalize(self: *Shape, alloc: Allocator) void {
                for (self.contours.slice()) |*contour| {
                    if (contour.edges.len == 1) {
                        @branchHint(.unlikely);
                        const parts: [3]EdgeSegment = contour.edges.ptr[0].edge.split_in_thirds();
                        for (contour.edges.slice()) |edge_ref| {
                            edge_ref.deallocate(alloc);
                        }
                        contour.edges.clear();
                        var ref = EdgeSegmentRef.allocate_new(alloc);
                        ref.edge.* = parts[0];
                        ref = EdgeSegmentRef.allocate_new(alloc);
                        ref.edge.* = parts[1];
                        ref = EdgeSegmentRef.allocate_new(alloc);
                        ref.edge.* = parts[2];
                        contour.edges.append(ref, alloc);
                    } else {
                        var prev_edge_ref: *EdgeSegmentRef = contour.edges.get_last_ptr();
                        var prev_tangent: Vector = undefined;
                        var curr_tangent: Vector = undefined;
                        var axis: Vector = undefined;
                        for (contour.edges.slice()) |*curr_edge_ref| {
                            prev_tangent = prev_edge_ref.edge.tangent_at_interp(1).normalize();
                            curr_tangent = curr_edge_ref.edge.tangent_at_interp(0).normalize();
                            if (prev_tangent.dot(curr_tangent) < CORNER_DOT_EPSILON_MINUS_ONE) {
                                axis = curr_tangent.subtract(prev_tangent).normalize().scale(DECONVERGE_FACTOR);
                                if (prev_edge_ref.edge.convergent_curve_ordering(curr_edge_ref.edge) < 0) {
                                    axis = -axis;
                                }
                                prev_edge_ref.deconverge_edge(1, axis.perp_ccw());
                                curr_edge_ref.deconverge_edge(0, axis.perp_cw());
                            }
                            prev_edge_ref = curr_edge_ref;
                        }
                    }
                }
            }

            pub fn add_bounds_to_aabb(self: Shape, aabb: *AABB) void {
                for (self.contours.slice()) |contour| {
                    contour.add_bounds_to_aabb(aabb);
                }
            }

            pub fn add_mitered_bounds_to_aabb(self: Shape, aabb: *AABB, border_width: FLOAT_TYPE, miter_limit: FLOAT_TYPE, polarity: FLOAT_TYPE) void {
                for (self.contours.slice()) |contour| {
                    contour.add_mitered_bounds_to_aabb(aabb, border_width, miter_limit, polarity);
                }
            }

            pub fn get_bounds(self: Shape, border_width: FLOAT_TYPE, miter_limit: FLOAT_TYPE, polarity: FLOAT_TYPE) AABB {
                var aabb = AABB{};
                self.add_bounds_to_aabb(&aabb);
                if (border_width > 0) {
                    aabb.x_min -= border_width;
                    aabb.y_min -= border_width;
                    aabb.x_max += border_width;
                    aabb.y_max += border_width;
                    if (miter_limit > 0) {
                        self.add_mitered_bounds_to_aabb(&aabb, border_width, miter_limit, polarity);
                    }
                }
                return aabb;
            }

            pub const Scanline = struct {
                intersections: List(SingleScanlineIntersection),
                last_index: usize,

                pub fn init_cap(cap: usize, alloc: Allocator) Scanline {
                    return Scanline{
                        .intersections = List(SingleScanlineIntersection).init_capacity(cap, alloc),
                        .last_index = 0,
                    };
                }
                pub fn free(self: *Scanline, alloc: Allocator) void {
                    self.intersections.free(alloc);
                }

                fn point_x_greater_than(a: Point, b: Point) bool {
                    return a.x > b.x;
                }

                pub fn pre_process(self: *Scanline) void {
                    self.last_index = 0;
                    if (!self.intersections.is_empty()) {
                        self.intersections.insertion_sort(.entire_list(), point_x_greater_than);
                        var total_direction: FLOAT_TYPE = 0;
                        for (self.intersections.slice()) |intersection| {
                            total_direction += intersection.slope;
                            intersection.slope = total_direction;
                        }
                    }
                }

                pub fn move_to(self: *Scanline, x_value: FLOAT_TYPE) ?usize {
                    if (self.intersections.is_empty()) {
                        return null;
                    }
                    while (x_value < self.intersections.ptr[self.last_index].point.x) {
                        if (self.last_index == 0) {
                            return null;
                        }
                        self.last_index -= 1;
                    }
                    while (x_value > self.intersections.ptr[self.last_index].point.x and self.last_index < self.intersections.len) {
                        self.last_index += 1;
                    }
                    if (self.last_index >= self.intersections.len) {
                        return null;
                    }
                    return self.last_index;
                }

                pub fn count_intersections(self: *Scanline, x_value: FLOAT_TYPE) usize {
                    return self.move_to(x_value) + 1;
                }

                pub fn sum_intersections(self: *Scanline, x_value: FLOAT_TYPE) FLOAT_TYPE {
                    const idx = self.move_to(x_value);
                    if (idx) |i| {
                        return self.intersections.ptr[i].slope;
                    }
                    return 0;
                }

                pub fn interpret_fill_rule(self: *Scanline, intersection_idx: usize, fill_rule: FillRule) bool {
                    const slope = self.intersections.ptr[intersection_idx].slope;
                    return switch (fill_rule) {
                        .NONZERO => slope != 0,
                        .EVEN_ODD => slope & 1 == 1,
                        .POSITIVE => slope > 0,
                        .NEGATIVE => slope < 0,
                    };
                }

                pub fn overlap_amount(a: *Scanline, b: *Scanline, from_x: FLOAT_TYPE, to_x: FLOAT_TYPE, fill_rule: FillRule) FLOAT_TYPE {
                    var total: FLOAT_TYPE = 0;
                    var a_inside = false;
                    var b_inside = false;
                    var a_idx: usize = 0;
                    var b_idx: usize = 0;
                    var ax = if (!a.intersections.is_empty()) a.intersections.ptr[a_idx].point else to_x;
                    var bx = if (!b.intersections.is_empty()) b.intersections.ptr[b_idx].point else to_x;
                    while (ax < from_x or bx < from_x) {
                        const next_x = @min(ax, bx);
                        if (ax == next_x and a_idx < a.intersections.len) {
                            a_inside = a.interpret_fill_rule(a_idx, fill_rule);
                            a_idx += 1;
                            ax = if (a_idx < a.intersections.len) a.intersections.ptr[a_idx].point else to_x;
                        }
                        if (bx == next_x and b_idx < b.intersections.len) {
                            b_inside = b.interpret_fill_rule(b_idx, fill_rule);
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
                            a_inside = a.interpret_fill_rule(a_idx, fill_rule);
                            a_idx += 1;
                            ax = if (a_idx < a.intersections.len) a.intersections.ptr[a_idx].point else to_x;
                        }
                        if (bx == next_x and b_idx < b.intersections.len) {
                            b_inside = b.interpret_fill_rule(b_idx, fill_rule);
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

                pub fn is_filled_at_x(self: *Scanline, x_value: FLOAT_TYPE, fill_rule: FillRule) bool {
                    return self.interpret_fill_rule(self.sum_intersections(x_value), fill_rule);
                }
            };

            pub fn get_horizontal_scanline_intersections(self: Shape, y_value: FLOAT_TYPE, alloc: Allocator) Scanline {
                var intersections = Scanline.init_cap(8, alloc);
                for (self.contours.slice()) |contour| {
                    for (contour.edges.slice()) |edge_ref| {
                        const edge_intersections = edge_ref.edge.horizontal_intersections(y_value);
                        for (0..edge_intersections.count) |i| {
                            const inter = edge_intersections.intersections[i];
                            _ = intersections.intersections.append(inter, alloc);
                        }
                    }
                }
                intersections.pre_process();
            }

            pub fn edge_count(self: Shape) u32 {
                var total: u32 = 0;
                for (self.contours.slice()) |contour| {
                    total += contour.edges.len;
                }
                return total;
            }

            pub const IntersectionWithCountourIdx = struct {
                inter: ScanlineIntersections.Intersection,
                contour_idx: usize,

                pub fn x_greater_than(a: IntersectionWithCountourIdx, b: IntersectionWithCountourIdx) bool {
                    return a.inter.point > b.inter.point;
                }
            };

            pub fn orient_contours(self: *Shape, alloc: Allocator) void {
                var orientations = List(i32).init_capacity(@intCast(self.contours.len), alloc);
                defer orientations.free(alloc);
                var intersections = List(IntersectionWithCountourIdx).init_capacity(@intCast(self.contours.len), alloc);
                defer intersections.free(alloc);
                for (self.contours.slice(), 0..) |contour, i| {
                    if (i >= orientations.len and !contour.edges.is_empty()) {
                        orientations.len = @intCast(i);
                        const y0 = contour.edges.get_first().edge.interp_point(0).y;
                        var y1 = y0;
                        for (contour.edges.slice()) |edge_ref| {
                            if (y0 != y1) break;
                            y1 = edge_ref.edge.interp_point(1).y;
                        }
                        // in case all endpoints are in a horizontal line
                        for (contour.edges.slice()) |edge_ref| {
                            if (y0 != y1) break;
                            y1 = edge_ref.edge.interp_point(HALF_SQRT_5_MINUS_1).y;
                        }
                        const y = MathX.lerp(y0, y1, HALF_SQRT_5_MINUS_1);
                        for (self.contours.slice(), 0..) |contour_2, j| {
                            for (contour_2.edges.slice()) |edge_ref| {
                                const edge_intersections = edge_ref.edge.horizontal_intersections(y);
                                var k: u32 = 0;
                                while (k < intersections.count) {
                                    const isection = IntersectionWithCountourIdx{
                                        .inter = edge_intersections.intersections[k],
                                        .contour_idx = j,
                                    };
                                    _ = intersections.append(isection, alloc);
                                    k += 1;
                                }
                            }
                        }
                        if (!intersections.is_empty()) {
                            intersections.insertion_sort(.entire_list(), IntersectionWithCountourIdx.x_greater_than);
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
                                    orientations.ptr[intersections.ptr[j].contour_idx] += (2 * (num_cast(j & 1, i32) ^ num_cast(intersections.ptr[j].inter.slope > 0, i32))) - 1;
                                }
                                j += 1;
                            }
                            intersections.clear();
                        }
                    }
                }
                // Reverse contours that have the opposite orientation
                for (self.contours.slice(), 0..) |*contour, i| {
                    if (orientations[i] < 0) {
                        contour.reverse();
                    }
                }
            }
        };

        pub fn SimpleContourCombiner(comptime EdgeSelectorType: type) type {
            return struct {
                shape_edge_selector: EdgeSelectorType,
            };
        }

        pub fn OverlappingContourCombiner(comptime EdgeSelectorType: type) type {
            return struct {
                point: Point,
                windings: List(ShapeWinding),
                selectors: List(EdgeSelectorType),
            };
        }
    };
}

/// Fill rule dictates how intersection total is interpreted during rasterization.
pub const FillRule = enum {
    NONZERO,
    EVEN_ODD,
    POSITIVE,
    NEGATIVE,
};

/// Specifies whether the Y component of the coordinate system increases in the upward or downward direction.
pub const YAxisOrientation = enum { Y_UPWARD, Y_DOWNWARD };
