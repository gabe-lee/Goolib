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

const BitmapModule = Root.Bitmap;
const Bitmap = BitmapModule.Bitmap;
const BitmapDef = Root.Bitmap.BitmapDefinition;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

pub fn BezierMultiSignedDistanceFieldGenerator(comptime Float: type, comptime ESTIMATION_STEPS: comptime_int) type {
    assert_with_reason(Types.type_is_float(Float), @src(), "type `FLOAT_TYPE` must be a float type (f16, f32, f64, f80, f128), got type `{s}`", .{@typeName(Float)});
    return struct {
        pub const MAX_NEGATIVE_FLOAT = -math.floatMax(Float);
        pub const MAX_POSITIVE_FLOAT = math.floatMax(Float);

        pub const DISTANCE_DELTA_FACTOR = 1.001;
        pub const CORNER_DOT_EPSILON = 0.000001;
        pub const CORNER_DOT_EPSILON_MINUS_ONE = CORNER_DOT_EPSILON - 1;
        pub const CORNER_DOT_EPSILON_MINUS_ONE_SQUARED = CORNER_DOT_EPSILON_MINUS_ONE * CORNER_DOT_EPSILON_MINUS_ONE;
        pub const DECONVERGE_OVERSHOOT = 1.11111111111111111;
        pub const DEFAULT_MIN_ERROR_IMPROVE_RATIO = 1.11111111111111111;
        pub const DEFAULT_MIN_ERROR_DEVIATION_RATIO = 1.11111111111111111;
        pub const DECONVERGE_FACTOR = DECONVERGE_OVERSHOOT * @sqrt(1 - CORNER_DOT_EPSILON_MINUS_ONE_SQUARED) / CORNER_DOT_EPSILON_MINUS_ONE;
        pub const HALF_SQRT_5_MINUS_1 = 0.6180339887498948482045868343656381177203091798057628621354;
        pub const PROTECTION_RADIUS_TOLERANCE = 1.001;
        pub const ARTIFACT_T_EPSILON = 0.01;
        pub const DEFAULT_ANGLE_THRESHOLD_RADIANS = 3.0;

        pub const Point = Vec2.define_vec2_type(Float);
        pub const Vector = Point;
        pub const AABB = AABB2.define_aabb2_type(Float);
        pub const LinearBezier = Bezier.LinearBezier(Float);
        pub const QuadraticBezier = Bezier.QuadraticBezier(Float);
        pub const CubicBezier = Bezier.CubicBezier(Float);
        pub const SignedDistance = MathX.SignedDistance(Float);
        pub const SignedDistanceWithPercent = MathX.SignedDistanceWithPercent(Float);
        pub const ScanlineIntersections = MathX.ScanlineIntersections(3, Float, .axis_only, .sign, i32);
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
            low: Float,
            high: Float,

            pub fn multiplied_by(self: Range, factor: Float) Range {
                return Range{
                    .low = self.low * factor,
                    .high = self.high * factor,
                };
            }
            pub fn multiply_self(self: *Range, factor: Float) void {
                self.low *= factor;
                self.high *= factor;
            }
            pub fn divided_by(self: Range, factor: Float) Range {
                return Range{
                    .low = self.low / factor,
                    .high = self.high / factor,
                };
            }
            pub fn divide_self(self: *Range, factor: Float) void {
                self.low /= factor;
                self.high /= factor;
            }
            pub fn new(low: Float, high: Float) Range {
                return Range{
                    .low = low,
                    .high = high,
                };
            }
            pub fn new_centered_at_zero(symetrical_width: Float) Range {
                return Range{
                    .low = (-0.5) * symetrical_width,
                    .high = (0.5) * symetrical_width,
                };
            }
        };

        pub const DistanceMapping = struct {
            scale: Float = 1,
            translate: Float = 0,

            pub fn new(scale: Float, translate: Float) DistanceMapping {
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
            pub fn calc(self: DistanceMapping, distance: Float) Float {
                return self.scale * (distance + self.translate);
            }
            pub fn calc_delta(self: DistanceMapping, distance_delta: Delta) Float {
                return self.scale * (distance_delta.value + self.translate);
            }
            pub fn calc_biased_normalized(self: DistanceMapping, bias: Float, distance: Float) Float {
                return MathX.normalized_num_cast(MathX.clamp_0_to_1(self.calc(distance + bias) + 0.5), Float);
            }
            pub fn calc_biased_normalized_out(self: DistanceMapping, bias: Float, distance: Float, comptime OUT: type) OUT {
                return MathX.normalized_num_cast(MathX.clamp_0_to_1(self.calc(distance + bias) + 0.5), OUT);
            }

            pub const Delta = struct {
                value: Float = 0,

                pub fn new(delta: Float) Delta {
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
            pub fn interp_point(self: EdgeSegment, percent: Float) Point {
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
            pub fn tangent_at_interp(self: EdgeSegment, percent: Float) Vector {
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
            pub fn tangent_change_at_interp(self: EdgeSegment, percent: Float) Vector {
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
            pub fn length(self: EdgeSegment) Float {
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
            pub fn estimate_length(self: EdgeSegment) Float {
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
            pub fn horizontal_intersections(self: EdgeSegment, y_value: Float) ScanlineIntersections {
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
            r: Float,
            g: Float,
            b: Float,

            pub fn init_max_negative() MultiDistance {
                return MultiDistance{
                    .r = MAX_NEGATIVE_FLOAT,
                    .g = MAX_NEGATIVE_FLOAT,
                    .b = MAX_NEGATIVE_FLOAT,
                };
            }

            pub fn median_distance(self: MultiDistance) Float {
                return MathX.median_of_3(Float, self.r, self.g, self.b);
            }
        };
        pub const MultiAndTrueDistance = struct {
            r: Float,
            g: Float,
            b: Float,
            a: Float,

            pub fn init_max_negative() MultiAndTrueDistance {
                return MultiAndTrueDistance{
                    .r = MAX_NEGATIVE_FLOAT,
                    .g = MAX_NEGATIVE_FLOAT,
                    .b = MAX_NEGATIVE_FLOAT,
                    .a = MAX_NEGATIVE_FLOAT,
                };
            }

            pub fn median_colored_distance(self: MultiAndTrueDistance) Float {
                return MathX.median_of_3(Float, self.r, self.g, self.b);
            }
        };

        pub fn DistanceTypeAndMedian(comptime T: type) type {
            return struct {
                const Self = @This();

                distance: T,
                median: Float,

                pub fn init_max_negative() DistanceTypeAndMedian {
                    return DistanceTypeAndMedian{
                        .distance = if (T == Float) MAX_NEGATIVE_FLOAT else T.init_max_negative(),
                        .median = MAX_NEGATIVE_FLOAT,
                    };
                }
                pub fn set_max_negative(self: *Self) void {
                    self.distance = if (T == Float) MAX_NEGATIVE_FLOAT else T.init_max_negative();
                    self.median = MAX_NEGATIVE_FLOAT;
                }

                pub const DISTANCE_TYPE = T;
            };
        }

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

            pub fn distance(self: TrueDistanceSelector) Float {
                return self.min_signed_distance.distance;
            }
            pub fn median_distance(self: TrueDistanceSelector) Float {
                return self.min_signed_distance.distance;
            }
            pub fn distance_and_median(self: TrueDistanceSelector) DistanceTypeAndMedian(Float) {
                return DistanceTypeAndMedian(Float){
                    .distance = self.min_signed_distance.distance,
                    .median = self.min_signed_distance.distance,
                };
            }
            pub const DISTANCE_AND_MEDIAN_TYPE = DistanceTypeAndMedian(Float);

            pub const EdgeCache = struct {
                point: Point,
                abs_distance: Float,

                pub fn new(point: Point, abs_distance: Float) EdgeCache {
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
                abs_distance: Float = 0,
                a_domain_distance: Float = 0,
                b_domain_distance: Float = 0,
                a_perp_distance: Float = 0,
                b_perp_distance: Float = 0,
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

            pub fn distance(self: PerpendicularDistanceSelector) Float {
                return self.base.calculate_distance(self.point);
            }
            pub fn median_distance(self: PerpendicularDistanceSelector) Float {
                return self.base.calculate_distance(self.point);
            }
            pub fn distance_and_median(self: TrueDistanceSelector) DistanceTypeAndMedian(Float) {
                const d = self.base.calculate_distance(self.point);
                return DistanceTypeAndMedian(Float){
                    .distance = d,
                    .median = d,
                };
            }
            pub const DISTANCE_AND_MEDIAN_TYPE = DistanceTypeAndMedian(Float);
            pub fn merge(self: *PerpendicularDistanceSelector, other: PerpendicularDistanceSelector) void {
                self.base.merge(other.base);
            }

            pub const BaseData = struct {
                min_true_distance: SignedDistance = .{},
                min_negative_perp_distance: Float = 0,
                min_positive_perp_distance: Float = 0,
                near_edge: ?*EdgeSegment = undefined,
                near_edge_percent: Float = 0,

                pub fn reset(self: *BaseData, delta: Float) void {
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

                pub fn add_edge_true_distance(self: *BaseData, edge: *const EdgeSegment, signed_distance: SignedDistance, percent: Float) void {
                    if (signed_distance.less_than(self.min_true_distance)) {
                        self.min_true_distance = signed_distance;
                        self.near_edge = edge;
                        self.near_edge_percent = percent;
                    }
                }

                pub fn add_edge_perpendicular_distance(self: *BaseData, dist: Float) void {
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

                pub fn calculate_distance(self: BaseData, point: Point) Float {
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

                pub fn update_perpendicular_distance(_: BaseData, curr_perp_distance: *Float, test_point_to_edge_point_delta: Point, edge_tangent: Vector) bool {
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

            pub fn distance(self: MultiDistanceSelector) MultiDistance {
                return MultiDistance{
                    .r = self.chan_r.calculate_distance(self.point),
                    .g = self.chan_g.calculate_distance(self.point),
                    .b = self.chan_b.calculate_distance(self.point),
                };
            }
            pub fn distance_and_median(self: MultiDistanceSelector) DistanceTypeAndMedian(MultiDistance) {
                const d = self.distance(self.point);
                return DistanceTypeAndMedian(MultiDistance){
                    .distance = d,
                    .median = d.median_distance(),
                };
            }
            pub const DISTANCE_AND_MEDIAN_TYPE = DistanceTypeAndMedian(MultiDistance);

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

            pub const EdgeCache = MultiDistanceSelector.EdgeCache;

            pub fn distance(self: MultiAndTrueDistanceSelector) MultiAndTrueDistance {
                const multi = self.multi_dist_selector.distance();
                return MultiAndTrueDistance{
                    .r = multi.r,
                    .g = multi.g,
                    .b = multi.b,
                    .a = self.true_dist_selector.distance(),
                };
            }

            pub fn distance_and_median(self: MultiAndTrueDistanceSelector) DistanceTypeAndMedian(MultiAndTrueDistance) {
                const d = self.distance(self.point);
                return DistanceTypeAndMedian(MultiAndTrueDistance){
                    .distance = d,
                    .median = d.median_colored_distance(),
                };
            }
            pub const DISTANCE_AND_MEDIAN_TYPE = DistanceTypeAndMedian(MultiAndTrueDistance);
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
            pub fn clear(self: *Contour, alloc: Allocator) void {
                for (self.edges.slice()) |edge_ref| {
                    edge_ref.deallocate(alloc);
                }
                self.edges.clear();
            }

            pub fn allocate_and_add_edge(self: *Contour, edge: EdgeSegment, alloc: Allocator) void {
                const edge_ref = EdgeSegmentRef.allocate_new(alloc);
                edge_ref.edge.* = edge;
                _ = self.edges.append(edge_ref, alloc);
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

            pub fn add_mitered_bounds_to_aabb(self: Contour, aabb: *AABB, border_size: Float, miter_limit: Float, polarity: Float) void {
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
                var total: Float = 0;
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

            pub fn add_mitered_bounds_to_aabb(self: Shape, aabb: *AABB, border_width: Float, miter_limit: Float, polarity: Float) void {
                for (self.contours.slice()) |contour| {
                    contour.add_mitered_bounds_to_aabb(aabb, border_width, miter_limit, polarity);
                }
            }

            pub fn get_bounds(self: Shape, border_width: Float, miter_limit: Float, polarity: Float) AABB {
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
                pub fn reset(self: *Scanline) void {
                    self.intersections.clear();
                    self.last_index = 0;
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
                        var total_direction: Float = 0;
                        for (self.intersections.slice()) |intersection| {
                            total_direction += intersection.slope;
                            intersection.slope = total_direction;
                        }
                    }
                }

                pub fn move_to(self: *Scanline, x_value: Float) ?usize {
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

                pub fn count_intersections(self: *Scanline, x_value: Float) usize {
                    return self.move_to(x_value) + 1;
                }

                pub fn sum_intersections(self: *Scanline, x_value: Float) Float {
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

                pub fn overlap_amount(a: *Scanline, b: *Scanline, from_x: Float, to_x: Float, fill_rule: FillRule) Float {
                    var total: Float = 0;
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

                pub fn is_filled_at_x(self: *Scanline, x_value: Float, fill_rule: FillRule) bool {
                    return self.interpret_fill_rule(self.sum_intersections(x_value), fill_rule);
                }
            };

            pub fn get_new_horizontal_scanline_intersections(self: Shape, y_value: Float, alloc: Allocator) Scanline {
                var scanline = Scanline.init_cap(8, alloc);
                self.get_horizontal_scanline_intersections(y_value, &scanline, alloc);
                return scanline;
            }

            pub fn get_horizontal_scanline_intersections(self: Shape, y_value: Float, scanline: *Scanline, alloc: Allocator) void {
                scanline.reset();
                for (self.contours.slice()) |contour| {
                    for (contour.edges.slice()) |edge_ref| {
                        const edge_intersections = edge_ref.edge.horizontal_intersections(y_value);
                        for (0..edge_intersections.count) |i| {
                            const inter = edge_intersections.intersections[i];
                            _ = scanline.intersections.append(inter, alloc);
                        }
                    }
                }
                scanline.pre_process();
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

            pub fn edge_coloring_simple(self: *Shape, corner_list: *List(usize), angle_threshold: Float, seed: *u64, alloc: Allocator) void {
                const cross_product_threshold = @sin(angle_threshold);
                var color = EdgeColor.init_color(seed);
                corner_list.clear();
                for (self.contours.slice()) |contour| {
                    if (contour.edges.is_empty()) {
                        continue;
                    }
                    { // Identify corners
                        corner_list.clear();
                        const prev_tangent = contour.edges.get_last().edge.tangent_at_interp(1);
                        for (contour.edges.slice(), 0..) |edge_ref, edge_idx| {
                            if (prev_tangent.normalize().forms_corner_dot_or_cross_product_threshold(edge_ref.edge.tangent_at_interp(0).normalize(), cross_product_threshold)) {
                                _ = corner_list.append(edge_idx, alloc);
                            }
                            prev_tangent = edge_ref.edge.tangent_at_interp(1);
                        }
                    }

                    if (corner_list.is_empty()) {
                        // Fully 'smooth' contour
                        color.switch_color(seed);
                        for (contour.edges.slice()) |*edge_ref| {
                            edge_ref.edge.color = color;
                        }
                    } else if (corner_list.len == 1) {
                        // `Teardrop` case (exactly one corner)
                        var colors: [3]EdgeColor = undefined;
                        color.switch_color(seed);
                        colors[0] = color;
                        colors[1] = EdgeColor.white;
                        color.switch_color(seed);
                        colors[2] = color;
                        const corner_idx = corner_list.ptr[0];
                        if (contour.edges.len >= 3) {
                            const limit = contour.edges.len;
                            var edge_idx: u32 = 0;
                            while (edge_idx < limit) : (edge_idx += 1) {
                                contour.edges.ptr[(corner_idx + edge_idx) % limit].edge.color = colors[1 + MathX.range_trichotomy(0, edge_idx, limit, usize)];
                            }
                        } else if (contour.edges.len >= 1) {
                            // Less than three edge segments for three colors => edges must be split
                            var parts: [6]EdgeSegment = undefined;
                            var part_count: usize = 0;
                            const thirds_0 = contour.edges.ptr[0].edge.split_in_thirds();
                            const corner_idx_3 = 3 * corner_idx;
                            parts[0 + corner_idx_3] = thirds_0[0];
                            parts[1 + corner_idx_3] = thirds_0[1];
                            parts[2 + corner_idx_3] = thirds_0[2];
                            if (contour.edges.len >= 2) {
                                const thirds_1 = contour.edges.ptr[1].edge.split_in_thirds();
                                parts[3 - corner_idx_3] = thirds_1[0];
                                parts[4 - corner_idx_3] = thirds_1[1];
                                parts[5 - corner_idx_3] = thirds_1[2];
                                parts[0].color = colors[0];
                                parts[1].color = colors[0];
                                parts[2].color = colors[1];
                                parts[3].color = colors[1];
                                parts[4].color = colors[2];
                                parts[5].color = colors[2];
                                part_count = 6;
                            } else {
                                parts[0].color = colors[0];
                                parts[1].color = colors[1];
                                parts[2].color = colors[2];
                                part_count = 3;
                            }
                            contour.clear(alloc);
                            for (0..part_count) |part_idx| {
                                contour.allocate_and_add_edge(parts[part_idx], alloc);
                            }
                        } else {
                            // multiple corners
                            const corner_count = corner_list.len;
                            const last_corner_idx = corner_count - 1;
                            var spline_idx: u32 = 0;
                            const start_idx = corner_list.ptr[0];
                            const limit = contour.edges.len;
                            const initial_color = color;
                            var i: usize = 0;
                            while (i < limit) : (i += 1) {
                                const idx = (start_idx + i) % limit;
                                if (spline_idx + 1 < corner_count and corner_list.ptr[spline_idx + 1] == idx) {
                                    spline_idx += 1;
                                    color.switch_color_with_ban(seed, EdgeColor.from_raw(num_cast(spline_idx == last_corner_idx, u8) * initial_color.raw()));
                                }
                                contour.edges.ptr[idx].edge.color = color;
                            }
                        }
                    }
                }
            }

            pub fn edge_coloring_inktrap(self: *Shape, corner_list: *List(EdgeColoringInktrapCorner), angle_threshold: Float, seed: *u64, alloc: Allocator) void {
                const cross_product_threshold = @sin(angle_threshold);
                var color = EdgeColor.init_color(seed);
                corner_list.clear();
                for (self.contours.slice()) |contour| {
                    if (contour.edges.is_empty()) {
                        continue;
                    }
                    var spline_length: Float = 0;
                    { // Identify corners
                        corner_list.clear();
                        const prev_tangent = contour.edges.get_last().edge.tangent_at_interp(1);
                        for (contour.edges.slice(), 0..) |edge_ref, edge_idx| {
                            if (prev_tangent.normalize().forms_corner_dot_or_cross_product_threshold(edge_ref.edge.tangent_at_interp(0).normalize(), cross_product_threshold)) {
                                const corner = EdgeColoringInktrapCorner{
                                    .idx = edge_idx,
                                    .prev_edge_length_estimate = spline_length,
                                };
                                _ = corner_list.append(corner, alloc);
                                spline_length = 0;
                            }
                            spline_length += edge_ref.edge.estimate_length();
                            prev_tangent = edge_ref.edge.tangent_at_interp(1);
                        }
                    }

                    if (corner_list.is_empty()) {
                        // Fully 'smooth' contour
                        color.switch_color(seed);
                        for (contour.edges.slice()) |*edge_ref| {
                            edge_ref.edge.color = color;
                        }
                    } else if (corner_list.len == 1) {
                        // `Teardrop` case (exactly one corner)
                        var colors: [3]EdgeColor = undefined;
                        color.switch_color(seed);
                        colors[0] = color;
                        colors[1] = EdgeColor.white;
                        color.switch_color(seed);
                        colors[2] = color;
                        const corner_idx = corner_list.ptr[0].idx;
                        if (contour.edges.len >= 3) {
                            const limit = contour.edges.len;
                            var edge_idx: u32 = 0;
                            while (edge_idx < limit) : (edge_idx += 1) {
                                contour.edges.ptr[(corner_idx + edge_idx) % limit].edge.color = colors[1 + MathX.range_trichotomy(0, edge_idx, limit, usize)];
                            }
                        } else if (contour.edges.len >= 1) {
                            // Less than three edge segments for three colors => edges must be split
                            var parts: [6]EdgeSegment = undefined;
                            var part_count: usize = 0;
                            const thirds_0 = contour.edges.ptr[0].edge.split_in_thirds();
                            const corner_idx_3 = 3 * corner_idx;
                            parts[0 + corner_idx_3] = thirds_0[0];
                            parts[1 + corner_idx_3] = thirds_0[1];
                            parts[2 + corner_idx_3] = thirds_0[2];
                            if (contour.edges.len >= 2) {
                                const thirds_1 = contour.edges.ptr[1].edge.split_in_thirds();
                                parts[3 - corner_idx_3] = thirds_1[0];
                                parts[4 - corner_idx_3] = thirds_1[1];
                                parts[5 - corner_idx_3] = thirds_1[2];
                                parts[0].color = colors[0];
                                parts[1].color = colors[0];
                                parts[2].color = colors[1];
                                parts[3].color = colors[1];
                                parts[4].color = colors[2];
                                parts[5].color = colors[2];
                                part_count = 6;
                            } else {
                                parts[0].color = colors[0];
                                parts[1].color = colors[1];
                                parts[2].color = colors[2];
                                part_count = 3;
                            }
                            contour.clear(alloc);
                            for (0..part_count) |part_idx| {
                                contour.allocate_and_add_edge(parts[part_idx], alloc);
                            }
                        } else {
                            // multiple corners
                            const corner_count = corner_list.len;
                            var major_corner_count = corner_count;
                            var this_corner_idx: u32 = 0;
                            if (corner_count > 3) {
                                corner_list.get_first_ptr().prev_edge_length_estimate += spline_length;
                                while (this_corner_idx < corner_count) : (this_corner_idx += 1) {
                                    const this_len_estimate = corner_list.ptr[this_corner_idx].prev_edge_length_estimate;
                                    const next_len_estimate = corner_list.ptr[(this_corner_idx + 1) % corner_count].prev_edge_length_estimate;
                                    const next_next_len_estimate = corner_list.ptr[(this_corner_idx + 2) % corner_count].prev_edge_length_estimate;
                                    if (this_len_estimate > next_len_estimate and next_len_estimate < next_next_len_estimate) {
                                        corner_list.ptr[this_corner_idx].is_minor = true;
                                        major_corner_count -= 1;
                                    }
                                }
                            }
                            var initial_color = EdgeColor.black;
                            this_corner_idx = 0;
                            while (this_corner_idx < corner_count) : (this_corner_idx += 1) {
                                if (!corner_list.ptr[this_corner_idx].is_minor) {
                                    major_corner_count -= 1;
                                    color.switch_color_with_ban(seed, EdgeColor.from_raw(num_cast(major_corner_count * num_cast(initial_color.raw(), u32) == 0, u8)));
                                    corner_list.ptr[this_corner_idx].color = color;
                                    if (initial_color == EdgeColor.black) {
                                        initial_color = color;
                                    }
                                }
                            }
                            this_corner_idx = 0;
                            while (this_corner_idx < corner_count) : (this_corner_idx += 1) {
                                if (corner_list.ptr[this_corner_idx].is_minor) {
                                    const next_color = corner_list.ptr[(this_corner_idx + 1) % corner_count].color;
                                    corner_list.ptr[this_corner_idx].color = color.bit_and(next_color).bit_xor(.white);
                                } else {
                                    color = corner_list.ptr[this_corner_idx].color;
                                }
                            }
                            var spline_idx: usize = 0;
                            const start_idx = corner_list.ptr[0].idx;
                            color = corner_list.ptr[0].color;
                            const limit = contour.edges.len;
                            var i: u32 = 0;
                            while (i < limit) : (i += 1) {
                                const index = (start_idx + i) % limit;
                                const next_spline_idx = spline_idx + 1;
                                if (next_spline_idx < corner_count and corner_list.ptr[next_spline_idx].idx == index) {
                                    color = corner_list.ptr[next_spline_idx].color;
                                    spline_idx = next_spline_idx;
                                }
                                contour.edges.ptr[index].edge.color = color;
                            }
                        }
                    }
                }
            }
        };

        pub const EdgeColoringInktrapCorner = struct {
            idx: usize = 0,
            prev_edge_length_estimate: Float,
            is_minor: bool = false,
            color: EdgeColor = EdgeColor.black,
        };

        pub fn SimpleContourCombiner(comptime EdgeSelectorType: type) type {
            return struct {
                const Self = @This();

                pub const EDGE_SELECTOR_TYPE = EdgeSelectorType;
                pub const EDGE_CACHE_TYPE = EDGE_SELECTOR_TYPE.EdgeCache;
                pub const DISTANCE_TYPE = EdgeSelectorType.DISTANCE_TYPE;
                pub const NUM_CHANNELS = switch (DISTANCE_TYPE) {
                    Float => 1,
                    MultiDistance => 3,
                    MultiAndTrueDistance => 4,
                    else => assert_unreachable(null, "invalid DISTANCE_TYPE, must be `Float` (the float type declared at comptime), `MultiDistance`, or `MultiAndTrueDistance`, got type `{s}`", .{@typeName(DISTANCE_TYPE)}),
                };
                pub const BITMAP_TYPE = FloatBitmap(NUM_CHANNELS);

                shape_edge_selector: EdgeSelectorType = .{},

                pub fn init_from_shape(_: *Shape, _: Allocator) Self {
                    return Self{};
                }

                pub fn distance(self: Self, _: Allocator) EdgeSelectorType.DISTANCE_TYPE {
                    return self.shape_edge_selector.distance();
                }

                pub fn edge_selector(self: Self, _: usize) EdgeSelectorType {
                    return self.shape_edge_selector;
                }
                pub fn edge_selector_ptr(self: *Self, _: usize) *EdgeSelectorType {
                    return &self.shape_edge_selector;
                }

                pub fn reset(self: *Self, point: Point) void {
                    self.shape_edge_selector.reset(point);
                }
            };
        }

        pub fn OverlappingContourCombiner(comptime EdgeSelectorType: type) type {
            return struct {
                const Self = @This();

                point: Point = .{},
                windings: List(ShapeWinding),
                selectors: List(EdgeSelectorType),

                pub const EDGE_SELECTOR_TYPE = EdgeSelectorType;
                pub const EDGE_CACHE_TYPE = EDGE_SELECTOR_TYPE.EdgeCache;
                pub const DISTANCE_TYPE = EdgeSelectorType.DISTANCE_TYPE;
                pub const NUM_CHANNELS = switch (DISTANCE_TYPE) {
                    Float => 1,
                    MultiDistance => 3,
                    MultiAndTrueDistance => 4,
                    else => assert_unreachable(null, "invalid DISTANCE_TYPE, must be `Float` (the float type declared at comptime), `MultiDistance`, or `MultiAndTrueDistance`, got type `{s}`", .{@typeName(DISTANCE_TYPE)}),
                };
                pub const BITMAP_TYPE = FloatBitmap(NUM_CHANNELS);

                pub fn init_from_shape(shape: *Shape, alloc: Allocator) Self {
                    var self = Self{
                        .windings = List(ShapeWinding).init_capacity(shape.contours.len, alloc),
                        .selectors = List(EdgeSelectorType).init_capacity(shape.contours.len, alloc),
                    };
                    self.selectors.len = shape.contours.len;
                    for (shape.contours.slice()) |contour| {
                        const idx = self.windings.append_slots_assume_capacity(1).first_idx;
                        self.windings.ptr[idx] = contour.winding_orientation();
                    }
                }
                pub fn free(self: *Self, alloc: Allocator) void {
                    self.windings.free(alloc);
                    self.selectors.free(alloc);
                }

                pub fn edge_selector(self: Self, idx: usize) EdgeSelectorType {
                    return self.selectors.ptr[idx];
                }
                pub fn edge_selector_ptr(self: Self, idx: usize) *EdgeSelectorType {
                    return &self.selectors.ptr[idx];
                }

                pub fn reset(self: *Self, point: Point) void {
                    self.point = point;
                    for (self.selectors.slice()) |*selector| {
                        selector.reset(point);
                    }
                }

                pub fn distance(self: *Self, alloc: Allocator) EdgeSelectorType.DISTANCE_TYPE {
                    const contour_count = self.selectors.len;
                    var shape_edge_selector: EdgeSelectorType = undefined;
                    var inner_edge_selector: EdgeSelectorType = undefined;
                    var outer_edge_selector: EdgeSelectorType = undefined;
                    var selector_distances = List(EdgeSelectorType.DISTANCE_AND_MEDIAN_TYPE).init_capacity(contour_count, alloc);
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
                    var winding: ShapeWinding = .COLINEAR;
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
            };
        }

        pub const Projection = struct {
            scale: Vector = .ONE_ONE,
            translate: Vector = .ZERO_ZERO,

            pub fn new(scale: Vector, translate: Vector) Projection {
                return Projection{
                    .scale = scale,
                    .translate = translate,
                };
            }

            pub fn project(self: Projection, point: Point) Point {
                return point.add(self.translate).scale(self.scale);
            }

            pub fn un_project(self: Projection, point: Point) Point {
                return point.inverse_scale(self.scale).subtract(self.translate);
            }

            pub fn project_vec(self: Projection, vec: Vector) Point {
                return vec.scale(self.scale);
            }

            pub fn un_project_vec(self: Projection, vec: Vector) Point {
                return vec.inverse_scale(self.scale);
            }

            pub fn project_x(self: Projection, x: Float) Float {
                return (x + self.translate.x) * self.scale.x;
            }
            pub fn project_y(self: Projection, y: Float) Float {
                return (y + self.translate.y) * self.scale.y;
            }

            pub fn un_project_x(self: Projection, x: Float) Float {
                return (x / self.scale.x) - self.translate.x;
            }
            pub fn un_project_y(self: Projection, y: Float) Float {
                return (y / self.scale.y) - self.translate.y;
            }
        };

        pub const Transformation = struct {
            distance_mapping: DistanceMapping = .{},
            projection: Projection = .{},

            pub fn new(dist_map: DistanceMapping, projection: Projection) Transformation {
                return Transformation{
                    .distance_mapping = dist_map,
                    .projection = projection,
                };
            }
            pub fn new_from_range(range: Range, projection: Projection) Transformation {
                return Transformation{
                    .distance_mapping = DistanceMapping.new_from_range(range),
                    .projection = projection,
                };
            }
        };

        pub const ErrorStencilBitmapDefEnum = enum(u8) {
            flags,
        };

        pub const ErrorStencilBitmapDef = BitmapDef{
            .CHANNEL_TYPE = ErrorFlags,
            .CHANNELS_ENUM = ErrorStencilBitmapDefEnum,
            .Y_ORDER = .bottom_to_top,
        };

        pub const ErrorStencilBitmap = Bitmap(ErrorStencilBitmapDef);

        pub const ErrorCorrector = struct {
            stencil: ErrorStencilBitmap = .{},
            transform: Transformation = .{},
            /// The minimum ratio between the actual and maximum expected distance delta to be considered an error.
            min_deviation_ratio: Float = DEFAULT_MIN_ERROR_DEVIATION_RATIO,
            /// The minimum ratio between the pre-correction distance error and the post-correction distance error.
            min_improve_ratio: Float = DEFAULT_MIN_ERROR_IMPROVE_RATIO,

            pub fn init(stencil: Bitmap(ErrorStencilBitmapDef), transform: Transformation) ErrorCorrector {
                var self = ErrorCorrector{
                    .stencil = stencil,
                    .transform = transform,
                };
                self.stencil.fill_all(ErrorStencilBitmap.Pixel{ .raw = .{ErrorFlags.from_flag(.NONE)} });
                return self;
            }

            pub fn protect_all(self: *ErrorCorrector) void {
                var y: u32 = 0;
                var x: u32 = undefined;
                while (y < self.stencil.height) : (y += 1) {
                    x = 0;
                    const row = self.stencil.get_h_scanline_native(0, y, self.stencil.width);
                    while (x < self.stencil.width) : (x += 1) {
                        row.ptr[x].set(.flags, ErrorStencilBitmap.Pixel{ .raw = .{ErrorFlags.from_flag(.PROTECTED)} });
                    }
                }
            }

            pub fn protect_corners(self: *ErrorCorrector, shape: *Shape) void {
                if (self.stencil.height == 0 or self.stencil.width == 0) return;
                for (shape.contours.slice()) |contour| {
                    if (!contour.edges.is_empty()) {
                        var prev_edge = contour.edges.get_last().edge;
                        var this_edge: *EdgeSegment = undefined;
                        for (contour.edges.slice()) |edge_ref| {
                            this_edge = edge_ref.edge;
                            const common_color = prev_edge.color.bit_and(this_edge.color).as_flags();
                            // If the color changes from prevEdge to edge, this is a corner.
                            if (common_color.has_one_or_zero_bits_set()) {
                                // Find the four pixels that envelop the corner and mark them as protected.
                                const p = self.transform.projection.project(this_edge.interp_point(0));
                                const min_x: i32 = @intFromFloat(p.x - 0.5);
                                const min_y: i32 = @intFromFloat(p.y - 0.5);
                                const max_x = min_x + 1;
                                const max_y = min_y + 1;
                                // Check that the positions are within bounds.
                                const min_x_in_bounds = min_x >= 0;
                                const min_y_in_bounds = min_y >= 0;
                                const max_x_in_bounds = max_x < self.stencil.width;
                                const max_y_in_bounds = max_y < self.stencil.height;
                                // Protect the corner pixels that are in bounds
                                if (min_x_in_bounds) {
                                    if (min_y_in_bounds) {
                                        self.stencil.set_pixel_channel_with_origin(.bot_left, @intCast(min_x), @intCast(min_y), .flags, ErrorFlags.PROTECTED);
                                    }
                                    if (max_y_in_bounds) {
                                        self.stencil.set_pixel_channel_with_origin(.bot_left, @intCast(min_x), @intCast(max_y), .flags, ErrorFlags.PROTECTED);
                                    }
                                }
                                if (max_x_in_bounds) {
                                    if (min_y_in_bounds) {
                                        self.stencil.set_pixel_channel_with_origin(.bot_left, @intCast(max_x), @intCast(min_y), .flags, ErrorFlags.PROTECTED);
                                    }
                                    if (max_y_in_bounds) {
                                        self.stencil.set_pixel_channel_with_origin(.bot_left, @intCast(max_x), @intCast(max_y), .flags, ErrorFlags.PROTECTED);
                                    }
                                }
                            }
                            prev_edge = this_edge;
                        }
                    }
                }
            }

            pub fn protect_edges(self: *ErrorCorrector, comptime NUM_CHANNELS: comptime_int, msdf_region: FloatBitmap(NUM_CHANNELS)) void {
                const BMP = FloatBitmap(NUM_CHANNELS);
                const edge_util = EdgeMaskFuncs(NUM_CHANNELS);
                var radius: Float = undefined;
                // Horizontal pixel pairs
                radius = PROTECTION_RADIUS_TOLERANCE * self.transform.projection.un_project_vec(Vector.new(self.transform.distance_mapping.calc_delta(.new(1)), 0)).length();
                var y: u32 = 0;
                var x: u32 = undefined;
                while (y < msdf_region.height) : (y += 1) {
                    x = 0;
                    const row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y);
                    while (x < msdf_region.width - 1) : (x += 1) {
                        const left = row_ptr[x];
                        const right = row_ptr[x + 1];
                        const left_median = left.median_of_3_channels(.red, .green, .blue);
                        const right_median = right.median_of_3_channels(.red, .green, .blue);
                        if (@abs(left_median - 0.5) + @abs(right_median - 0.5) < radius) {
                            const edge_mask = edge_util.edge_mask_between_pixels(left, right);
                            var stencil_ptr = self.stencil.get_pixel_ptr_with_origin(.bot_left, x, y);
                            edge_util.protect_extreme_channels(stencil_ptr, left, left_median, edge_mask);
                            stencil_ptr = self.stencil.move_pixel_ptr_with_origin(.bot_left, 1, 0, stencil_ptr);
                            edge_util.protect_extreme_channels(stencil_ptr, right, right_median, edge_mask);
                        }
                    }
                }
                // Vertical pixel pairs
                radius = PROTECTION_RADIUS_TOLERANCE * self.transform.projection.un_project_vec(Vector.new(0, self.transform.distance_mapping.calc_delta(.new(1)))).length();
                y = 0;
                while (y < msdf_region.height - 1) : (y += 1) {
                    x = 0;
                    const top_row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y + 1);
                    const bot_row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y);
                    while (x < msdf_region.width) : (x += 1) {
                        const top = top_row_ptr[x];
                        const bottom = bot_row_ptr[x];
                        const top_median = top.median_of_3_channels(.red, .green, .blue);
                        const bottom_median = bottom.median_of_3_channels(.red, .green, .blue);
                        if (@abs(bottom_median - 0.5) + @abs(top_median - 0.5) < radius) {
                            const edge_mask = edge_util.edge_mask_between_pixels(bottom_median, top_median);
                            var stencil_ptr = self.stencil.get_pixel_ptr_with_origin(.bot_left, x, y);
                            edge_util.protect_extreme_channels(stencil_ptr, bottom, bottom_median, edge_mask);
                            stencil_ptr = self.stencil.move_pixel_ptr_with_origin(.bot_left, 0, 1, stencil_ptr);
                            edge_util.protect_extreme_channels(stencil_ptr, top, top_median, edge_mask);
                        }
                    }
                }
                // Diagonal pixel pairs
                radius = PROTECTION_RADIUS_TOLERANCE * self.transform.projection.un_project_vec(Vector.new_same_xy(self.transform.distance_mapping.calc_delta(.new(1)))).length();
                y = 0;
                while (y < msdf_region.height - 1) : (y += 1) {
                    x = 0;
                    const top_row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y + 1);
                    const bot_row_ptr: [*]BMP.Pixel = msdf_region.get_pixel_ptr_many_with_origin(.bot_left, 0, y);
                    while (x < msdf_region.width - 1) : (x += 1) {
                        const top_left = top_row_ptr[x];
                        const bottom_left = bot_row_ptr[x];
                        const top_right = top_row_ptr[x + 1];
                        const bottom_right = bot_row_ptr[x + 1];
                        const top_left_median = top_left.median_of_3_channels(.red, .green, .blue);
                        const bottom_left_median = bottom_left.median_of_3_channels(.red, .green, .blue);
                        const top_right_median = top_right.median_of_3_channels(.red, .green, .blue);
                        const bottom_right_median = bottom_right.median_of_3_channels(.red, .green, .blue);
                        if (@abs(top_left_median - 0.5) + @abs(bottom_right_median - 0.5) < radius) {
                            const edge_mask = edge_util.edge_mask_between_pixels(bottom_right, top_left);
                            var stencil_ptr = self.stencil.get_pixel_ptr_with_origin(.bot_left, x + 1, y);
                            edge_util.protect_extreme_channels(stencil_ptr, bottom_right, bottom_right_median, edge_mask);
                            stencil_ptr = self.stencil.move_pixel_ptr_with_origin(.bot_left, -1, 1, stencil_ptr);
                            edge_util.protect_extreme_channels(stencil_ptr, top_left, top_left_median, edge_mask);
                        }
                        if (@abs(top_right_median - 0.5) + @abs(bottom_left_median - 0.5) < radius) {
                            const edge_mask = edge_util.edge_mask_between_pixels(bottom_left, top_right);
                            var stencil_ptr = self.stencil.get_pixel_ptr_with_origin(.bot_left, x, y);
                            edge_util.protect_extreme_channels(stencil_ptr, bottom_left, bottom_left_median, edge_mask);
                            stencil_ptr = self.stencil.move_pixel_ptr_with_origin(.bot_left, 1, 1, stencil_ptr);
                            edge_util.protect_extreme_channels(stencil_ptr, top_right, top_right_median, edge_mask);
                        }
                    }
                }
            }

            pub fn find_errors_msdf_only(self: *ErrorCorrector, comptime NUM_CHANNELS: comptime_int, msdf_region: FloatBitmap(NUM_CHANNELS), alloc: Allocator) void {
                // Compute the expected deltas between values of horizontally, vertically, and diagonally adjacent texels.
                const horizontal_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new(self.transform.distance_mapping.calc_delta(.new(1)), 0)).length();
                const vertical_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new(0, self.transform.distance_mapping.calc_delta(.new(1)))).length();
                const diagonal_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new_same_xy(self.transform.distance_mapping.calc_delta(.new(1)))).length();
                // Inspect all texels.
                var y: u32 = 0;
                var x: u32 = undefined;
                while (y < msdf_region.height) : (y += 1) {
                    x = 0;
                    while (x < msdf_region.width) : (x += 1) {
                        const pixel = msdf_region.get_pixel_native(x, y);
                        const pixel_median = pixel.median_of_3_channels(.red, .green, .blue);
                        const stencil_flag_ptr: *ErrorFlags = self.stencil.get_pixel_channel_ptr_native(x, y);
                        const is_protected = stencil_flag_ptr.has_flag(.PROTECTED);
                        const horizontal_classifier = BaseArtifactClassifier.new(horizontal_span, is_protected);
                        const vertical_classifier = BaseArtifactClassifier.new(vertical_span, is_protected);
                        const diagonal_classifier = BaseArtifactClassifier.new(diagonal_span, is_protected);
                        const check = ClassifierFuncs(BaseArtifactClassifier, NUM_CHANNELS);
                        // Mark current pixel with the error flag if an artifact occurs when it's interpolated with any of its 8 neighbors.
                        stencil_flag_ptr.set_one_bit_if_true(.ERROR,
                            //
                            (x > 0 and check.has_linear_artifact(horizontal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), alloc)) or
                                (x < msdf_region.width - 1 and check.has_linear_artifact(horizontal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), alloc)) or
                                (y > 0 and check.has_linear_artifact(vertical_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x, y - 1), alloc)) or
                                (y < msdf_region.height - 1 and check.has_linear_artifact(vertical_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x, y + 1), alloc)) or
                                (x > 0 and y > 0 and check.has_diagonal_artifact(diagonal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), msdf_region.get_pixel_native(x, y - 1), msdf_region.get_pixel_native(x - 1, y - 1), alloc)) or
                                (x < msdf_region.width - 1 and y > 0 and check.has_diagonal_artifact(diagonal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), msdf_region.get_pixel_native(x, y - 1), msdf_region.get_pixel_native(x + 1, y - 1), alloc)) or
                                (x > 0 and y < msdf_region.height - 1 and check.has_diagonal_artifact(diagonal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), msdf_region.get_pixel_native(x, y + 1), msdf_region.get_pixel_native(x - 1, y + 1), alloc)) or
                                (x < msdf_region.width - 1 and y < msdf_region.height - 1 and check.has_diagonal_artifact(diagonal_classifier, pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), msdf_region.get_pixel_native(x, y + 1), msdf_region.get_pixel_native(x + 1, y + 1), alloc))
                                //
                        );
                    }
                }
            }

            pub fn find_errors_msdf_and_shape(self: *ErrorCorrector, comptime CONTOUR_COMBINER_TYPE: type, comptime NUM_CHANNELS: comptime_int, msdf_region: FloatBitmap(NUM_CHANNELS), shape: *Shape, alloc: Allocator) void {
                // Compute the expected deltas between values of horizontally, vertically, and diagonally adjacent texels.
                const horizontal_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new(self.transform.distance_mapping.calc_delta(.new(1)), 0)).length();
                const vertical_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new(0, self.transform.distance_mapping.calc_delta(.new(1)))).length();
                const diagonal_span = self.min_deviation_ratio * self.transform.projection.un_project_vec(.new_same_xy(self.transform.distance_mapping.calc_delta(.new(1)))).length();
                var distance_checker = ShapeDistanceChecker(CONTOUR_COMBINER_TYPE, NUM_CHANNELS).init(msdf_region, shape, self.transform.projection, self.transform.distance_mapping, self.min_improve_ratio, alloc);
                const check = ClassifierFuncs(ShapeDistanceChecker(CONTOUR_COMBINER_TYPE, NUM_CHANNELS).ArtifactClassifier, NUM_CHANNELS);
                var reverse_x = false;
                var y: u32 = 0;
                var x: u32 = undefined;
                var step_x: i32 = undefined;
                var abs_x: u32 = undefined;
                //TODO: enable some sort of optional multi-threading here?
                // Inspect all texels.
                while (y < msdf_region.height) : ({
                    y += 1;
                    reverse_x = !reverse_x;
                }) {
                    if (reverse_x) {
                        x = msdf_region.width - 1;
                        step_x = -1;
                    } else {
                        x = 0;
                        step_x = 1;
                    }
                    abs_x = 0;
                    while (abs_x < msdf_region.width) : ({
                        abs_x += 1;
                        x = MathX.upgrade_add_out(x, step_x, u32);
                    }) {
                        const stencil_flag_ptr = self.stencil.get_pixel_channel_ptr_native(x, y);
                        if (stencil_flag_ptr.has_flag(.ERROR)) continue;
                        const point = Point.new(num_cast(x, f32) + 0.5, num_cast(y, f32) + 0.5);
                        distance_checker.shape_point = self.transform.projection.un_project(point);
                        distance_checker.msdf_point = point;
                        distance_checker.curr_pixel_ptr = msdf_region.get_pixel_ptr_native(@intCast(x), y);
                        distance_checker.protected = stencil_flag_ptr.has_flag(.PROTECTED);
                        const pixel = distance_checker.curr_pixel_ptr.*;
                        const pixel_median = pixel.median_of_3_channels(.red, .green, .blue);
                        // Mark current pixel with the error flag if an artifact occurs when it's interpolated with any of its 8 neighbors.
                        stencil_flag_ptr.set_one_bit_if_true(.ERROR,
                            //
                            (x > 0 and check.has_linear_artifact(distance_checker.classifier(.new(-1, 0), horizontal_span), pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), alloc)) or
                                (x < msdf_region.width - 1 and check.has_linear_artifact(distance_checker.classifier(.new(1, 0), horizontal_span), pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), alloc)) or
                                (y > 0 and check.has_linear_artifact(distance_checker.classifier(.new(0, 1), vertical_span), pixel_median, pixel, msdf_region.get_pixel_native(x, y - 1), alloc)) or
                                (y < msdf_region.height - 1 and check.has_linear_artifact(distance_checker.classifier(.new(0, -1), vertical_span), pixel_median, pixel, msdf_region.get_pixel_native(x, y + 1), alloc)) or
                                (x > 0 and y > 0 and check.has_diagonal_artifact(distance_checker.classifier(.new(-1, 1), diagonal_span), pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), msdf_region.get_pixel_native(x, y - 1), msdf_region.get_pixel_native(x - 1, y - 1), alloc)) or
                                (x < msdf_region.width - 1 and y > 0 and check.has_diagonal_artifact(distance_checker.classifier(.new(1, 1), diagonal_span), pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), msdf_region.get_pixel_native(x, y - 1), msdf_region.get_pixel_native(x + 1, y - 1), alloc)) or
                                (x > 0 and y < msdf_region.height - 1 and check.has_diagonal_artifact(distance_checker.classifier(.new(-1, -1), diagonal_span), pixel_median, pixel, msdf_region.get_pixel_native(x - 1, y), msdf_region.get_pixel_native(x, y + 1), msdf_region.get_pixel_native(x - 1, y + 1), alloc)) or
                                (x < msdf_region.width - 1 and y < msdf_region.height - 1 and check.has_diagonal_artifact(distance_checker.classifier(.new(1, -1), diagonal_span), pixel_median, pixel, msdf_region.get_pixel_native(x + 1, y), msdf_region.get_pixel_native(x, y + 1), msdf_region.get_pixel_native(x + 1, y + 1), alloc))
                                //
                        );
                    }
                }
            }

            pub fn apply_error_correction(self: *ErrorCorrector, comptime NUM_CHANNELS: comptime_int, msdf_region: FloatBitmap(NUM_CHANNELS)) void {
                var y: u32 = 0;
                var x: u32 = undefined;
                var pixel_row: []FloatBitmap(NUM_CHANNELS).Pixel = undefined;
                var stencil_row: []ErrorStencilBitmap.Pixel = undefined;
                while (y < msdf_region.height) : (y += 1) {
                    x = 0;
                    pixel_row = msdf_region.get_h_scanline_native(0, y, msdf_region.width);
                    stencil_row = self.stencil.get_h_scanline_native(0, y, msdf_region.width);
                    while (x < msdf_region.width) : (x += 1) {
                        const error_check = stencil_row.ptr[x].get(.flags);
                        if (error_check.has_flag(.ERROR)) {
                            // Set all color channels to the median.
                            const pixel_ptr: *FloatBitmap(NUM_CHANNELS).Pixel = &pixel_row.ptr[x];
                            const median = pixel_ptr.median_of_3_channels(.red, .green, .blue);
                            pixel_ptr.set(.red, median);
                            pixel_ptr.set(.green, median);
                            pixel_ptr.set(.blue, median);
                        }
                    }
                }
            }
        };

        pub const Generator = struct {
            /// Whether or not to support overlapping contours (uses more complex algorithm)
            pub const ContourOverlapSupport = enum(u8) {
                DO_NOT_HANDLE_OVERLAPPING_CONTOURS,
                HANDLE_OVERLAPPING_CONTOURS,
            };

            pub const FastErrorProtectionMode = enum(u8) {
                ONLY_PROTECT_EDGES_AND_CORNERS,
                PROTECT_ALL_PIXELS,
            };

            pub const ErrorCorrectionMode = enum(u8) {
                /// Skips error correction pass.
                DISABLED,
                /// Does not use the shape when perofrming error correction,
                FAST,
                /// Corrects all discontinuities of the distance field regardless if edges are adversely affected.
                INDISCRIMINATE,
                /// Corrects artifacts at edges and other discontinuous distances only if it does not affect edges or corners.
                EDGE_PRIORITY,
                /// Only corrects artifacts at edges.
                EDGE_ONLY,
            };

            /// Configuration of whether to use an algorithm that computes the exact shape distance at the positions of suspected artifacts. This algorithm can be much slower.
            pub const DistanceCheckMode = enum(u8) {
                /// Never computes exact shape distance.
                DO_NOT_CHECK_DISTANCE,
                /// An alternate pass that checks scanlines instead of exact pixel distance
                SCANLINE_PASS,
                /// Only computes exact shape distance at edges. Provides a good balance between speed and precision.
                CHECK_DISTANCE_AT_EDGE,
                /// Computes and compares the exact shape distance for each suspected artifact.
                ALWAYS_CHECK_DISTANCE,
            };

            /// The type of final signed distance field bitmap to produce
            pub const GenerateType = enum(u8) {
                /// true signed distance field, 1 channel
                TSDF,
                /// psuedo/perpendicular signed distance field, 1 channel
                PSDF,
                /// multi signed distance field, 3 channels
                MSDF,
                /// multi AND true signed distance field, 4 channels
                MTSDF,
            };

            /// Whether to check that shape is properly formed before generating
            pub const ShapeValidation = enum(u8) {
                /// Assume shape is properly formed
                DO_NOT_VALIDATE_SHAPE,
                /// Check that shape is properly formed before generating
                VALIDATE_SHAPE,
            };

            /// Whether to perform a pass to orient shape contour windings
            pub const ShapeWindingPreprocess = enum(u8) {
                /// Do not perform a pass to orient shape contour windings
                NO_WINDING_PREPROCESS,
                /// Perform a pass to orient shape contour windings
                PERFORM_WINDING_PREPREOCESS,
            };

            /// Whether to reverse shape contour windings
            pub const ShapeWindingChange = enum(u8) {
                /// Do not change shape contour windings
                KEEP_EXISTING_WINDING,
                /// Run a test distance check to determine existing winding and reverse if neccesary
                GUESS_CORRECT_WINDING,
                /// Always reverse the shape contour windings
                REVERSE_EXISTING_WINDING,
            };

            pub const Angle = union(Root.CommonTypes.AngleType) {
                RADIANS: Float,
                DEGREES: Float,

                pub fn new_radians(radians: Float) Angle {
                    return Angle{ .RADIANS = radians };
                }
                pub fn new_degrees(degrees: Float) Angle {
                    return Angle{ .DEGREES = degrees };
                }

                pub fn to_radians(self: Angle) Angle {
                    return switch (self) {
                        .RADIANS => self,
                        .DEGREES => |deg| new_radians(deg * MathX.DEG_TO_RAD),
                    };
                }
                pub fn to_radians_raw(self: Angle) Float {
                    return switch (self) {
                        .RADIANS => |rad| rad,
                        .DEGREES => |deg| deg * MathX.DEG_TO_RAD,
                    };
                }
            };

            /// Whether or not to support overlapping contours (uses more complex algorithm)
            overlap_support: ContourOverlapSupport = .HANDLE_OVERLAPPING_CONTOURS,
            /// The minimum ratio between the actual and maximum expected distance delta to be considered an error.
            min_deviation_ratio: Float = DEFAULT_MIN_ERROR_DEVIATION_RATIO,
            /// The minimum ratio between the pre-correction distance error and the post-correction distance error. Has no effect for DO_NOT_CHECK_DISTANCE.
            min_improve_ratio: Float = DEFAULT_MIN_ERROR_IMPROVE_RATIO,
            /// Configuration of whether to use an algorithm that computes the exact shape distance at the positions of suspected artifacts. This algorithm can be much slower.
            msdf_error_correction_distance_check_mode: DistanceCheckMode = .CHECK_DISTANCE_AT_EDGE,
            /// How to apply/compute error correction for MSDF bitmaps, if any
            msdf_error_correction_mode: ErrorCorrectionMode = .EDGE_PRIORITY,
            /// Whether or not to protect ALL pixels in `.FAST` error correction mode
            msdf_error_correction_fast_protection_mode: FastErrorProtectionMode = .ONLY_PROTECT_EDGES_AND_CORNERS,
            /// re-usable error stencil buffer
            error_stencil_buffer: ErrorStencilBitmap = .{},
            /// whether or not to automatically free the error stencil or retain it for future use
            free_error_stencil_buffer_after: bool = false,
            /// Whether to check that shape is properly formed before generating
            shape_validation: ShapeValidation = .VALIDATE_SHAPE,
            /// Whether to perform a pass to orient shape contour windings
            shape_winding_preprocess: ShapeWindingPreprocess = .PERFORM_WINDING_PREPREOCESS,
            /// Whether to reverse shape contour windings
            shape_winding_change: ShapeWindingChange = .KEEP_EXISTING_WINDING,
            /// Whether to skip the edge coloring pass for MSDF or MTSDF bitmaps
            skip_edge_coloring: bool = false,
            /// re-usable index list for simple edge-coloring pass
            edge_coloring_corner_list_simple: List(usize) = .{},
            /// re-usable index list for inktrap edge-coloring pass
            edge_coloring_corner_list_inktrap: List(EdgeColoringInktrapCorner) = .{},
            /// whether or not to automatically free the `edge_coloring_corner_list_simple` and/or `edge_coloring_corner_list_inktrap` or retain them for future use
            free_edge_coloring_corner_list_after: bool = false,

            /// the allocator to use for allocations,
            alloc: Allocator,

            fn generate_field_inner(self: *Generator, comptime CONTOUR_COMBINER_TYPE: type, output: FloatBitmap(CONTOUR_COMBINER_TYPE.NUM_CHANNELS), shape: *Shape, transform: Transformation) void {
                const converter = DistancePixelConverter(CONTOUR_COMBINER_TYPE.DISTANCE_TYPE).new(transform.distance_mapping);
                const distance_finder = ShapeDistanceFinder(CONTOUR_COMBINER_TYPE).init(shape, self.alloc);
                var x_dir: i32 = 1;
                var y: u32 = 0;
                var x: i32 = undefined;
                var abs_x: u32 = undefined;
                //TODO enable some sort of multi-threading here?
                while (y < output.height) : (y += 1) {
                    abs_x = 0;
                    x = if (x_dir == 1) 0 else @intCast(output.width - 1);
                    while (abs_x < output.width) : ({
                        abs_x += 1;
                        x += x_dir;
                    }) {
                        const pixel_ptr = output.get_pixel_ptr_with_origin(.bot_left, @intCast(x), y);
                        const point = transform.projection.un_project(.new(num_cast(x, Float) + 0.5, num_cast(y, Float) + 0.5));
                        const distance = distance_finder.distance(point, self.alloc);
                        converter.apply(pixel_ptr, distance);
                    }
                    x_dir = -x_dir;
                }
            }

            /// The output bitmap is assumed to be the correct size and the shape is assumed to have all preprocessing done
            pub fn generate_signed_distance_field_into_existing_bitmap_comptime_kind(self: *Generator, comptime kind: GenerateType, output: BitmapTypeForGeneratorKind(kind), shape: *Shape, transform: Transformation) void {
                switch (kind) {
                    .TSDF => switch (self.overlap_support) {
                        .DO_NOT_HANDLE_OVERLAPPING_CONTOURS => {
                            self.generate_field_inner(SimpleContourCombiner(TrueDistanceSelector), output, shape, transform);
                        },
                        .HANDLE_OVERLAPPING_CONTOURS => {
                            self.generate_field_inner(OverlappingContourCombiner(TrueDistanceSelector), output, shape, transform);
                        },
                    },
                    .PSDF => switch (self.overlap_support) {
                        .DO_NOT_HANDLE_OVERLAPPING_CONTOURS => {
                            self.generate_field_inner(SimpleContourCombiner(PerpendicularDistanceSelector), output, shape, transform);
                        },
                        .HANDLE_OVERLAPPING_CONTOURS => {
                            self.generate_field_inner(OverlappingContourCombiner(PerpendicularDistanceSelector), output, shape, transform);
                        },
                    },
                    .MSDF => switch (self.overlap_support) {
                        .DO_NOT_HANDLE_OVERLAPPING_CONTOURS => {
                            self.generate_field_inner(SimpleContourCombiner(MultiDistanceSelector), output, shape, transform);
                            self.perform_error_correction(3, output, shape, transform);
                        },
                        .HANDLE_OVERLAPPING_CONTOURS => {
                            self.generate_field_inner(OverlappingContourCombiner(MultiDistanceSelector), output, shape, transform);
                            self.perform_error_correction(3, output, shape, transform);
                        },
                    },
                    .MTSDF => switch (self.overlap_support) {
                        .DO_NOT_HANDLE_OVERLAPPING_CONTOURS => {
                            self.generate_field_inner(SimpleContourCombiner(MultiAndTrueDistanceSelector), output, shape, transform);
                            self.perform_error_correction(4, output, shape, transform);
                        },
                        .HANDLE_OVERLAPPING_CONTOURS => {
                            self.generate_field_inner(OverlappingContourCombiner(MultiAndTrueDistanceSelector), output, shape, transform);
                            self.perform_error_correction(4, output, shape, transform);
                        },
                    },
                }
            }

            pub const PreProcessResult = struct {
                aabb: ?AABB = null,
                windings_were_oriented: bool = false,
                shape_was_normalized: bool = false,
                windings_were_reversed: bool = false,
            };

            pub const ShapeTransformMode = enum(u8) {
                MANUAL,
                AUTO,
            };

            pub const ShapeTransformAuto = struct {
                units_per_pixel_x: Float = 1,
                units_per_pixel_y: Float = 1,

                pub fn new_same_xy(units_per_pixel: Float) ShapeTransformAuto {
                    return ShapeTransformAuto{
                        .units_per_pixel_x = units_per_pixel,
                        .units_per_pixel_y = units_per_pixel,
                    };
                }
                pub fn new(units_per_pixel_x: Float, units_per_pixel_y: Float) ShapeTransformAuto {
                    return ShapeTransformAuto{
                        .units_per_pixel_x = units_per_pixel_x,
                        .units_per_pixel_y = units_per_pixel_y,
                    };
                }
            };

            pub const ShapeTransformSetting = union(ShapeTransformMode) {
                MANUAL: Projection,
                AUTO: ShapeTransformAuto,

                pub fn manual(projection: Projection) ShapeTransformSetting {
                    return ShapeTransformSetting{
                        .MANUAL = projection,
                    };
                }

                pub fn auto_same_xy(units_per_pixel: Float) ShapeTransformSetting {
                    return ShapeTransformSetting{
                        .AUTO = ShapeTransformAuto.new_same_xy(units_per_pixel),
                    };
                }

                pub fn auto(units_per_pixel_x: Float, units_per_pixel_y: Float) ShapeTransformSetting {
                    return ShapeTransformSetting{
                        .AUTO = ShapeTransformAuto.new(units_per_pixel_x, units_per_pixel_y),
                    };
                }
            };

            /// Whather the shape range is given in native shape units or pixels
            pub const ShapeRangeSettingMode = enum(u8) {
                /// the distance range is given in terms of native units
                NATIVE_UNITS,
                /// the distance range is given in terms of rendered pixels
                PIXELS,
            };

            pub const ShapeBitmapSettingsMode = enum(u8) {
                EXISTING_BITMAP,
                ALLOCATE_NEW_BITMAP,
                FROM_BITMAP_PROVIDER,
            };

            pub const ShapeSettings = struct {
                transform: ShapeTransformSetting = .auto_same_xy(1),
                /// If specified > 0, the shape bounds will be calculated with this miter length limit (using `border_width` as well)
                miter_limit: Float = 0,
                /// If specified > 0, the shape bounds will be calculated with this border width (using `miter_limit` as well)
                border_width: Float = 0,
                /// The minimum angle between the end of one edge and the beginning of the next to be considered a corner
                corner_angle_threshold: Angle = .new_radians(DEFAULT_ANGLE_THRESHOLD_RADIANS),
                /// The fill rule to use when determining what part of the shape is filled
                fill_rule: FillRule = .NONZERO,
                /// Whether or not the shape comes pre-normalized
                needs_to_be_normalized: bool = true,
                /// Whather the `distance_range_width` is given in native shape units or pixels
                range_mode: ShapeRangeSettingMode = .PIXELS,
                /// The range width between the lowest signed distance and the highest signed distance
                distance_range_width: Float = 2.0,
                /// Shifts the signed distance lower and upper bounds down by this much
                distance_shift: Float = 0.0,
            };

            pub fn ShapeData(comptime OUTPUT_KIND: GenerateType) type {
                return struct {
                    shape: Shape,
                    aabb: AABB = .{},
                    miter_limit: Float = 0,
                    border_width: Float = 0,
                    angle_threshold: Angle = .new_radians(DEFAULT_ANGLE_THRESHOLD_RADIANS),
                    normalized: bool = false,
                    windings_oriented: bool = false,
                    windings_reversed: bool = false,
                    aabb_calculated: bool = false,
                    bitmap_generated: bool = false,
                    msdf_region_x_offset_from_atlas_bot_left: u32 = 0,
                    msdf_region_y_offset_from_atlas_bot_left: u32 = 0,
                    shape_origin_offset_from_msdf_region_bot_left: Vector = .{},
                    msdf_bitmap: BitmapTypeForGeneratorKind(OUTPUT_KIND) = .{},
                };
            }
            pub const ShapeOrShapeDataKind = enum(u8) {
                SHAPE_ONLY,
                SHAPE_WITH_DATA,
            };
            pub fn ShapeOrShapeData(comptime OUTPUT_KIND: GenerateType) type {
                return union(ShapeOrShapeDataKind) {
                    const Self = @This();

                    SHAPE_ONLY: Shape,
                    SHAPE_WITH_DATA: ShapeData(OUTPUT_KIND),

                    pub inline fn shape_only(shape: *Shape) Self {
                        return Self{
                            .SHAPE_ONLY = shape,
                        };
                    }
                    pub inline fn shape_with_data(shape_data: *ShapeData(OUTPUT_KIND)) Self {
                        return Self{
                            .SHAPE_WITH_DATA = shape_data,
                        };
                    }
                };
            }
            pub fn pre_process_shape(self: *Generator, comptime OUTPUT_KIND: GenerateType, shape_or_shape_with_data: ShapeOrShapeData(OUTPUT_KIND), preexisting_aabb: ?AABB) ShapeError!ShapeData(OUTPUT_KIND) {}

            pub fn generate(
                self: *Generator,
                comptime KIND: GenerateType,
                shape: *Shape,
                shape_settings: ShapeSettings,
            ) ShapeData(KIND) {}

            // CHECKPOINT derive the framing/transformation code from the original MSDFGen/main.cpp cli code

            // pub fn calculate_msdf_bounds(shape: )
            pub fn perform_error_correction(self: Generator, comptime NUM_CHANNELS: comptime_int, msdf_bitmap: FloatBitmap(NUM_CHANNELS), shape: *Shape, transform: Transformation) void {
                if (self.msdf_error_correction_mode == .DISABLED) return;
                self.error_stencil_buffer.discard_and_resize(msdf_bitmap.width, msdf_bitmap.height, ErrorStencilBitmap.Pixel{ .raw = .{ErrorFlags.from_flag(.NONE)} }, self.alloc);
                var corrector = ErrorCorrector.init(self.error_stencil_buffer, transform);
                corrector.min_deviation_ratio = self.min_deviation_ratio;
                switch (self.msdf_error_correction_mode) {
                    .FAST => {
                        if (self.msdf_error_correction_fast_protection_mode == .PROTECT_ALL_PIXELS) {
                            corrector.protect_all();
                        }
                        corrector.find_errors_msdf_only(NUM_CHANNELS, msdf_bitmap, self.alloc);
                    },
                    else => {
                        corrector.min_improve_ratio = self.min_improve_ratio;
                        switch (self.msdf_error_correction_mode) {
                            .EDGE_PRIORITY => {
                                corrector.protect_corners(shape);
                                corrector.protect_edges(NUM_CHANNELS, msdf_bitmap);
                            },
                            .EDGE_ONLY => {
                                corrector.protect_all();
                            },
                            else => {},
                        }
                        if (self.msdf_error_correction_distance_check_mode == .DO_NOT_CHECK_DISTANCE or (self.msdf_error_correction_distance_check_mode == .CHECK_DISTANCE_AT_EDGE and self.msdf_error_correction_mode != .EDGE_ONLY)) {
                            corrector.find_errors_msdf_only(NUM_CHANNELS, msdf_bitmap, self.alloc);
                            if (self.msdf_error_correction_distance_check_mode == .CHECK_DISTANCE_AT_EDGE) {
                                corrector.protect_all();
                            }
                        }
                        if (self.msdf_error_correction_distance_check_mode == .ALWAYS_CHECK_DISTANCE or self.msdf_error_correction_distance_check_mode == .CHECK_DISTANCE_AT_EDGE) {
                            if (self.overlap_support == .HANDLE_OVERLAPPING_CONTOURS) {
                                corrector.find_errors_msdf_and_shape(OverlappingContourCombiner(EdgeSelectorForNumChannels(NUM_CHANNELS)), NUM_CHANNELS, msdf_bitmap, shape, self.alloc);
                            } else {
                                corrector.find_errors_msdf_and_shape(SimpleContourCombiner(EdgeSelectorForNumChannels(NUM_CHANNELS)), NUM_CHANNELS, msdf_bitmap, shape, self.alloc);
                            }
                        }
                    },
                }
                corrector.apply_error_correction(NUM_CHANNELS, msdf_bitmap);
            }
        };

        pub fn BitmapTypeForGeneratorKind(comptime kind: Generator.GenerateType) type {
            return switch (kind) {
                .TSDF, .PSDF => FloatBitmap(1),
                .MSDF => FloatBitmap(3),
                .MTSDF => FloatBitmap(4),
            };
        }

        pub fn EdgeSelectorForNumChannels(comptime NUM_CHANNELS: comptime_int) type {
            return switch (NUM_CHANNELS) {
                1 => TrueDistanceSelector,
                3 => MultiDistanceSelector,
                4 => MultiAndTrueDistanceSelector,
                else => assert_unreachable(@src(), "invalid NUM_CHANNELS, must be 1 (TrueDistanceSelector), 3 (MultiDistanceSelector), or  4 (MultiAndTrueDistanceSelector), got `{d}`", .{NUM_CHANNELS}),
            };
        }

        pub fn DistancePixelConverter(comptime DISTANCE_TYPE: type) type {
            return struct {
                const Self = @This();

                mapping: DistanceMapping,

                pub fn new(mapping: DistanceMapping) Self {
                    return Self{
                        .mapping = mapping,
                    };
                }

                pub const BITMAP_TYPE = switch (DISTANCE_TYPE) {
                    Float => FloatBitmap(1),
                    MultiDistance => FloatBitmap(3),
                    MultiAndTrueDistance => FloatBitmap(4),
                    else => assert_unreachable(null, "invalid DISTANCE_TYPE, must be `Float` (the float type declared at comptime), `MultiDistance`, or `MultiAndTrueDistance`, got type `{s}`", .{@typeName(DISTANCE_TYPE)}),
                };

                pub fn apply(self: Self, pixel: *BITMAP_TYPE.Pixel, distance: DISTANCE_TYPE) void {
                    switch (DISTANCE_TYPE) {
                        Float => {
                            pixel.set(.alpha, self.mapping.calc(distance));
                        },
                        MultiDistance => {
                            pixel.set(.red, self.mapping.calc(distance.r));
                            pixel.set(.green, self.mapping.calc(distance.g));
                            pixel.set(.blue, self.mapping.calc(distance.b));
                        },
                        MultiAndTrueDistance => {
                            pixel.set(.red, self.mapping.calc(distance.r));
                            pixel.set(.green, self.mapping.calc(distance.g));
                            pixel.set(.blue, self.mapping.calc(distance.b));
                            pixel.set(.alpha, self.mapping.calc(distance.a));
                        },
                        else => assert_unreachable(@src(), "invalid DISTANCE_TYPE, must be `Float` (the float type declared at comptime), `MultiDistance`, or `MultiAndTrueDistance`, got type `{s}`", .{@typeName(DISTANCE_TYPE)}),
                    }
                }
            };
        }

        pub const BaseArtifactClassifier = struct {
            span: Float,
            protected: bool,

            pub fn new(span: Float, is_protected: bool) BaseArtifactClassifier {
                return BaseArtifactClassifier{
                    .span = span,
                    .protected = is_protected,
                };
            }

            /// Evaluates if the median value xm interpolated at xt in the range between am at at and bm at bt indicates an artifact.
            pub fn range_test(self: BaseArtifactClassifier, at: Float, bt: Float, xt: Float, am: Float, bm: Float, xm: Float) ArtifactFlags {
                // For protected pixels, only consider inversion artifacts (interpolated median has different sign than boundaries). For the rest, it is sufficient that the interpolated median is outside its boundaries.
                if ((am > 0.5 and bm > 0.5 and xm <= 0.5) or (am < 0.5 and bm < 0.5 and xm >= 0.5) or (!self.protected and MathX.median_of_3(Float, am, bm, xm) != xm)) {
                    const ax_span = (xt - at) * self.span;
                    const bx_span = (bt - xt) * self.span;
                    // Check if the interpolated median's value is in the expected range based on its distance (span) from boundaries a, b.
                    if (!(xm >= am - ax_span and xm <= am + ax_span and xm >= bm - bx_span and xm <= bm + bx_span)) {
                        return ArtifactFlags.from_full_group(.candidate_and_artifact);
                    } else {
                        return ArtifactFlags.from_flag(.candidate);
                    }
                }
                return ArtifactFlags{};
            }

            pub fn is_artifact(_: Float, _: Float, flags: ArtifactFlags) bool {
                return flags.has_flag(.artifact);
            }
        };

        pub const ArtifactFlags = Flags.Flags(enum(u8) {
            candidate = 1 << 0,
            artifact = 1 << 1,
        }, enum(u8) {
            candidate_and_artifact = 0b11,
        });

        pub fn FloatBitmapDef(comptime NUM_CHANNELS: comptime_int) type {
            return switch (NUM_CHANNELS) {
                1 => BitmapDef{ .CHANNEL_TYPE = f32, .CHANNELS_ENUM = BitmapModule.A_Channel, .Y_ORDER = .bottom_to_top },
                2 => BitmapDef{ .CHANNEL_TYPE = f32, .CHANNELS_ENUM = BitmapModule.RA_Channels, .Y_ORDER = .bottom_to_top },
                3 => BitmapDef{ .CHANNEL_TYPE = f32, .CHANNELS_ENUM = BitmapModule.RGB_Channels, .Y_ORDER = .bottom_to_top },
                4 => BitmapDef{ .CHANNEL_TYPE = f32, .CHANNELS_ENUM = BitmapModule.RGBA_Channels, .Y_ORDER = .bottom_to_top },
                else => assert_unreachable(@src(), "`NUM_CHANNELS` value (number of msdf bitmap channels) must be between 1-4, `{d}` not supported", .{NUM_CHANNELS}),
            };
        }
        pub fn FloatBitmap(comptime NUM_CHANNELS: comptime_int) type {
            return Bitmap(FloatBitmapDef(NUM_CHANNELS));
        }

        pub const SimpleTrueShapeDistanceFinder = ShapeDistanceFinder(SimpleContourCombiner(TrueDistanceSelector));

        pub fn ShapeDistanceChecker(comptime CONTOUR_COMBINER: type, comptime NUM_CHANNELS: comptime_int) type {
            switch (NUM_CHANNELS) {
                3, 4 => {},
                else => assert_unreachable(@src(), "`NUM_CHANNELS` value (number of msdf bitmap channels) must be either 3 or 4, `{d}` not supported", .{NUM_CHANNELS}),
            }
            const BMP = FloatBitmap(NUM_CHANNELS);
            return struct {
                const Self = @This();

                shape_point: Point = .ZERO_ZERO,
                msdf_point: Point = .ZERO_ZERO,
                curr_pixel_ptr: *BMP.Pixel = undefined,
                protected: bool = false,
                distance_finder: ShapeDistanceFinder(CONTOUR_COMBINER) = undefined,
                msdf_bitmap: *BMP = undefined,
                distance_mapping: DistanceMapping,
                pixel_size: Vector = .ONE_ONE,
                min_improve_ratio: Float = DEFAULT_MIN_ERROR_IMPROVE_RATIO,

                pub fn init(msdf_bitmap: *BMP, shape: *Shape, projection: Projection, dist_mapping: DistanceMapping, min_improve_ratio: Float, alloc: Allocator) Self {
                    return Self{
                        .distance_finder = ShapeDistanceFinder(CONTOUR_COMBINER).init(shape, alloc),
                        .msdf_bitmap = msdf_bitmap,
                        .distance_mapping = dist_mapping,
                        .min_improve_ratio = min_improve_ratio,
                        .pixel_size = projection.un_project_vec(.ONE_ONE),
                    };
                }

                pub fn classifier(self: *Self, direction: Vector, span: Float) ArtifactClassifier {
                    return ArtifactClassifier{
                        .parent = self,
                        .dirction = direction,
                        .base = BaseArtifactClassifier{
                            .protected = self.protected,
                            .span = span,
                        },
                    };
                }

                pub const ArtifactClassifier = struct {
                    base: BaseArtifactClassifier = undefined,
                    parent: *Self,
                    direction: Vector,

                    /// Returns true if the combined results of the tests performed on the median value m interpolated at t indicate an artifact.
                    pub fn is_artifact(self: ArtifactClassifier, t: Float, _: Float, flags: ArtifactFlags, alloc: Allocator) bool {
                        if (flags.has_flag(.candidate)) {
                            if (flags.has_flag(.artifact)) return true;
                            const t_vector = self.direction.scale(t);
                            var old_pixel: BMP.Pixel = undefined;
                            var new_pixel: BMP.Pixel = undefined;
                            // Compute the color that would be currently interpolated at the artifact candidate's position.
                            const msdf_point = self.parent.msdf_point.add(t_vector);
                            old_pixel = self.parent.msdf_bitmap.get_subpixel_mix_near(f32, msdf_point.x, msdf_point.y);
                            if (NUM_CHANNELS == 4) {
                                new_pixel.set(.alpha, old_pixel.get(.alpha));
                            }
                            // Compute the color that would be interpolated at the artifact candidate's position if error correction was applied on the current pixel.
                            const a_weight = (1 - @abs(t_vector.x)) * (1 - @abs(t_vector.y));
                            const a_psd = MathX.median_of_3(f32, self.parent.curr_pixel_ptr.get(.red), self.parent.curr_pixel_ptr.get(.green), self.parent.curr_pixel_ptr.get(.blue));
                            new_pixel.set(.red, old_pixel.get(.red) + (a_weight * (a_psd - self.parent.curr_pixel_ptr.get(.red))));
                            new_pixel.set(.green, old_pixel.get(.green) + (a_weight * (a_psd - self.parent.curr_pixel_ptr.get(.green))));
                            new_pixel.set(.blue, old_pixel.get(.blue) + (a_weight * (a_psd - self.parent.curr_pixel_ptr.get(.blue))));
                            // Compute the evaluated distance (interpolated median) before and after error correction, as well as the exact shape distance.
                            const old_psd = MathX.median_of_3(f32, old_pixel.get(.red), old_pixel.get(.green), old_pixel.get(.blue));
                            const new_psd = MathX.median_of_3(f32, new_pixel.get(.red), new_pixel.get(.green), new_pixel.get(.blue));
                            const ref_psd = self.parent.distance_mapping.calc(self.parent.distance_finder.distance(self.parent.shape_point.add_scale(t_vector, self.parent.pixel_size), alloc));
                            // Compare the differences of the exact distance and the before and after distances.
                            return self.parent.min_improve_ratio * @abs(new_psd - ref_psd) < @abs(old_psd - ref_psd);
                        }
                        return false;
                    }

                    pub fn range_test(self: ArtifactClassifier, at: Float, bt: Float, xt: Float, am: Float, bm: Float, xm: Float) ArtifactFlags {
                        return self.base.range_test(at, bt, xt, am, bm, xm);
                    }
                };
            };
        }

        pub fn EdgeMaskFuncs(comptime NUM_CHANNELS: comptime_int) type {
            const BMP = FloatBitmap(NUM_CHANNELS);
            return struct {
                /// Determines if the channel contributes to an edge between the two pixels a, b.
                pub fn edge_is_between_pixels_by_channel(pixel_a: BMP.Pixel, pixel_b: BMP.Pixel, channel: BMP.CHANNELS) bool {
                    // Find interpolation ratio t (0 < t < 1) where an edge is expected (mix(a[channel], b[channel], t) == 0.5).
                    const t = (pixel_a.get(channel) - 0.5) / (pixel_a.get(channel) - pixel_b.get(channel));
                    if (t > 0 and t < 1) {
                        // Interpolate all channel values at t.
                        const mixed_pixel = pixel_a.lerp(pixel_b);
                        // This is only an edge if the zero-distance channel is the median.
                        return MathX.median_of_3(f32, mixed_pixel.get(.red), mixed_pixel.get(.green), mixed_pixel.get(.blue)) == mixed_pixel.get(channel);
                    }
                    return false;
                }

                pub fn edge_mask_between_pixels(pixel_a: BMP.Pixel, pixel_b: BMP.Pixel) EdgeColor {
                    var flags = EdgeColor.black.as_flags();
                    flags.set_one_bit_if_true(.red, edge_is_between_pixels_by_channel(pixel_a, pixel_b, .red));
                    flags.set_one_bit_if_true(.green, edge_is_between_pixels_by_channel(pixel_a, pixel_b, .green));
                    flags.set_one_bit_if_true(.blue, edge_is_between_pixels_by_channel(pixel_a, pixel_b, .blue));
                    return EdgeColor.from_flags(flags);
                }

                /// Marks pixel as protected if one of its non-median channels is present in the channel mask.
                pub fn protect_extreme_channels(stencil_pixel: *ErrorStencilBitmap.Pixel, bitmap_pixel: BMP.Pixel, median_channel_val: f32, edge_mask: EdgeColor) void {
                    if ((edge_mask.has_channel(.red) and bitmap_pixel.get(.red) != median_channel_val) or
                        (edge_mask.has_channel(.green) and bitmap_pixel.get(.green) != median_channel_val) or
                        (edge_mask.has_channel(.blue) and bitmap_pixel.get(.blue) != median_channel_val))
                    {
                        stencil_pixel.set(.flags, ErrorFlags.PROTECTED);
                    }
                }
            };
        }

        pub fn ClassifierFuncs(comptime CLASSIFIER_TYPE: type, comptime BMP_NUM_CHANNELS: comptime_int) type {
            const BMP = FloatBitmap(BMP_NUM_CHANNELS);
            return struct {
                /// Determines if the channel contributes to an edge between the two pixels a, b.
                pub fn edge_is_between_pixels_by_channel(comptime BITMAP_TYPE: type, pixel_a: BITMAP_TYPE.Pixel, pixel_b: BITMAP_TYPE.Pixel, channel: BITMAP_TYPE.CHANNELS) bool {
                    // Find interpolation ratio t (0 < t < 1) where an edge is expected (mix(a[channel], b[channel], t) == 0.5).
                    const t = (pixel_a.get(channel) - 0.5) / (pixel_a.get(channel) - pixel_b.get(channel));
                    if (t > 0 and t < 1) {
                        // Interpolate all channel values at t.
                        const mixed_pixel = pixel_a.lerp(pixel_b);
                        // This is only an edge if the zero-distance channel is the median.
                        return MathX.median_of_3(f32, mixed_pixel.get(.red), mixed_pixel.get(.green), mixed_pixel.get(.blue)) == mixed_pixel.get(channel);
                    }
                    return false;
                }

                pub fn edge_mask_between_pixels(comptime BITMAP_TYPE: type, pixel_a: BITMAP_TYPE.Pixel, pixel_b: BITMAP_TYPE.Pixel) EdgeColor {
                    var flags = EdgeColor.black.as_flags();
                    flags.set_one_bit_if_true(.red, edge_is_between_pixels_by_channel(BITMAP_TYPE, pixel_a, pixel_b, .red));
                    flags.set_one_bit_if_true(.green, edge_is_between_pixels_by_channel(BITMAP_TYPE, pixel_a, pixel_b, .green));
                    flags.set_one_bit_if_true(.blue, edge_is_between_pixels_by_channel(BITMAP_TYPE, pixel_a, pixel_b, .blue));
                    return EdgeColor.from_flags(flags);
                }

                /// Marks pixel as protected if one of its non-median channels is present in the channel mask.
                pub fn protect_extreme_channels(comptime BITMAP_TYPE: type, stencil_pixel: *ErrorStencilBitmap.Pixel, bitmap_pixel: BITMAP_TYPE.Pixel, median_channel_val: f32, edge_mask: EdgeColor) void {
                    if ((edge_mask.has_channel(.red) and bitmap_pixel.get(.red) != median_channel_val) or
                        (edge_mask.has_channel(.green) and bitmap_pixel.get(.green) != median_channel_val) or
                        (edge_mask.has_channel(.blue) and bitmap_pixel.get(.blue) != median_channel_val))
                    {
                        stencil_pixel.set(.flags, ErrorFlags.PROTECTED);
                    }
                }
                pub fn has_linear_artifact_on_channel_pair(classifier: CLASSIFIER_TYPE, a_median: f32, b_median: f32, pixel_a: BMP.Pixel, pixel_b: BMP.Pixel, delta_a: f32, delta_b: f32, alloc: Allocator) bool {
                    // Find interpolation ratio t (0 < t < 1) where two color channels are equal (mix(dA, dB, t) == 0).
                    const percent = delta_a / (delta_a - delta_b);
                    if (percent > ARTIFACT_T_EPSILON and percent < 1 - ARTIFACT_T_EPSILON) {
                        // Interpolate median at t and let the classifier decide if its value indicates an artifact.
                        const interp_median = pixel_a.lerp(pixel_b, percent);
                        return classifier.is_artifact(percent, interp_median, classifier.range_test(0, 1, percent, a_median, b_median, interp_median), alloc);
                    }
                    return false;
                }
                pub fn has_linear_artifact(classifier: CLASSIFIER_TYPE, a_median: f32, pixel_a: BMP.Pixel, pixel_b: BMP.Pixel, alloc: Allocator) bool {
                    const b_median = pixel_b.median_of_3_channels(.red, .green, .blue);
                    return (
                        // Out of the pair, only report artifacts for the pixel further from the edge to minimize side effects.
                        @abs(a_median - 0.5) >= @abs(b_median) and
                            ( // Check points where each pair of color channels meets.
                                has_linear_artifact_on_channel_pair(classifier, a_median, b_median, pixel_a, pixel_b, pixel_a.channel_delta(.red, .green), pixel_b.channel_delta(.red, .green), alloc) or
                                    has_linear_artifact_on_channel_pair(classifier, a_median, b_median, pixel_a, pixel_b, pixel_a.channel_delta(.green, .blue), pixel_b.channel_delta(.green, .blue), alloc) or
                                    has_linear_artifact_on_channel_pair(classifier, a_median, b_median, pixel_a, pixel_b, pixel_a.channel_delta(.blue, .red), pixel_b.channel_delta(.blue, .red), alloc)
                                    //
                            )
                            //
                    );
                }
                pub fn has_diagonal_artifact_on_channel_pair(classifier: CLASSIFIER_TYPE, a_median: Float, d_median: Float, pixel_a: BMP.Pixel, pixel_a_linear_coeff: BMP.Pixel, pixel_a_quadratic_coeff: BMP.Pixel, delta_A: Float, delta_BC: Float, delta_D: Float, t_extreme_0: Float, t_extreme_1: Float, alloc: Allocator) bool {
                    // Find interpolation ratios t (0 < t[i] < 1) where two color channels are equal.
                    const solutions = MathX.solve_quadratic_polynomial_for_zeros(delta_D - delta_BC + delta_A, delta_BC - delta_A - delta_A, delta_A);
                    var i: u32 = 0;
                    while (i < solutions.count) : (i += 1) {
                        // Solutions ts[i] == 0 and ts[i] == 1 are singularities and occur very often because two channels are usually equal at pixels.
                        if (solutions.vals[i] > ARTIFACT_T_EPSILON and solutions.vals[i] < 1 - ARTIFACT_T_EPSILON) {
                            // Interpolate median at t.
                            const interp_median = pixel_a.bilinear_interp_from_terms(pixel_a_linear_coeff, pixel_a_quadratic_coeff, solutions.vals[i]);
                            // Determine if interp_median deviates too much from medians of a, d.
                            const artifact_flags = classifier.range_test(0, 1, solutions.vals[i], a_median, d_median, interp_median);
                            // Additionally, check interp_median against the interpolated medians at the local extremes.
                            var t_end: [2]Float = undefined;
                            var extreme_medians: [2]Float = undefined;
                            // Test t_extreme_0
                            if (t_extreme_0 > 0 and t_extreme_0 < 1) {
                                t_end[0] = 0;
                                t_end[1] = 1;
                                extreme_medians[0] = a_median;
                                extreme_medians[1] = d_median;
                                const t_end_idx = num_cast(t_extreme_0 > solutions.vals[i], u8);
                                t_end[t_end_idx] = t_extreme_0;
                                extreme_medians[t_end_idx] = pixel_a.bilinear_interp_from_terms(pixel_a_linear_coeff, pixel_a_quadratic_coeff, t_extreme_0);
                                artifact_flags.combine_with(classifier.range_test(t_end[0], t_end[1], solutions.vals[i], extreme_medians[0], extreme_medians[1], interp_median));
                            }
                            // Test t_extreme_1
                            if (t_extreme_1 > 0 and t_extreme_1 < 1) {
                                t_end[0] = 0;
                                t_end[1] = 1;
                                extreme_medians[0] = a_median;
                                extreme_medians[1] = d_median;
                                const t_end_idx = num_cast(t_extreme_1 > solutions.vals[i], u8);
                                t_end[t_end_idx] = t_extreme_1;
                                extreme_medians[t_end_idx] = pixel_a.bilinear_interp_from_terms(pixel_a_linear_coeff, pixel_a_quadratic_coeff, t_extreme_1);
                                artifact_flags.combine_with(classifier.range_test(t_end[0], t_end[1], solutions.vals[i], extreme_medians[0], extreme_medians[1], interp_median));
                            }
                            if (classifier.is_artifact(solutions.vals[i], interp_median, artifact_flags, alloc)) {
                                return true;
                            }
                        }
                    }
                    return false;
                }
                pub fn has_diagonal_artifact(classifier: CLASSIFIER_TYPE, a_median: Float, pixel_a: BMP.Pixel, pixel_b: BMP.Pixel, pixel_c: BMP.Pixel, pixel_d: BMP.Pixel, alloc: Allocator) bool {
                    const d_median = pixel_d.median_of_3_channels(.red, .green, .blue);
                    // Out of the pair, only report artifacts for the texel further from the edge to minimize side effects.
                    if (@abs(a_median - 0.5) >= @abs(d_median - 0.5)) {
                        const sub_abc = pixel_a.subtract(pixel_b).subtract(pixel_c);
                        // Compute the linear terms for bilinear interpolation.
                        const linear = pixel_a.negate().subtract(sub_abc);
                        // Compute the quadratic terms for bilinear interpolation.
                        const quadratic = pixel_d.add(sub_abc);
                        // Compute interpolation ratio extremes (0 < extremes[i] < 1) for the local extremes of each color channel (the derivative 2*quadratic[i]*extremes[i]+linear[i] == 0).
                        const extremes = BMP.Pixel.new_same_val_all_channels(-0.5).multiply(linear).divide(quadratic);
                        const a_delta_red_grn = pixel_a.channel_delta(.red, .green);
                        const b_delta_red_grn = pixel_b.channel_delta(.red, .green);
                        const c_delta_red_grn = pixel_c.channel_delta(.red, .green);
                        const d_delta_red_grn = pixel_d.channel_delta(.red, .green);
                        const a_delta_grn_blu = pixel_a.channel_delta(.green, .blue);
                        const b_delta_grn_blu = pixel_b.channel_delta(.green, .blue);
                        const c_delta_grn_blu = pixel_c.channel_delta(.green, .blue);
                        const d_delta_grn_blu = pixel_d.channel_delta(.green, .blue);
                        const a_delta_blu_red = pixel_a.channel_delta(.blue, .red);
                        const b_delta_blu_red = pixel_b.channel_delta(.blue, .red);
                        const c_delta_blu_red = pixel_c.channel_delta(.blue, .red);
                        const d_delta_blu_red = pixel_d.channel_delta(.blue, .red);
                        return ( // Check points where each pair of color channels meets.
                            has_diagonal_artifact_on_channel_pair(classifier, a_median, d_median, pixel_a, linear, quadratic, a_delta_red_grn, b_delta_red_grn + c_delta_red_grn, d_delta_red_grn, extremes.get(.red), extremes.get(.green), alloc) or
                                has_diagonal_artifact_on_channel_pair(classifier, a_median, d_median, pixel_a, linear, quadratic, a_delta_grn_blu, b_delta_grn_blu + c_delta_grn_blu, d_delta_grn_blu, extremes.get(.green), extremes.get(.blue), alloc) or
                                has_diagonal_artifact_on_channel_pair(classifier, a_median, d_median, pixel_a, linear, quadratic, a_delta_blu_red, b_delta_blu_red + c_delta_blu_red, d_delta_blu_red, extremes.get(.blue), extremes.get(.red), alloc)
                                //
                        );
                    }
                    return false;
                }
            };
        }

        pub fn ShapeDistanceFinder(comptime CONTOUR_COMBINER: type) type {
            return struct {
                const Self = @This();

                shape: *Shape,
                contour_combiner: CONTOUR_COMBINER = undefined,
                shape_edge_cache_list: List(CONTOUR_COMBINER.EDGE_CACHE_TYPE) = undefined,

                pub const DISTANCE_AND_MEDIAN_TYPE = CONTOUR_COMBINER.DISTANCE_AND_MEDIAN_TYPE;
                pub const DISTANCE_TYPE = DISTANCE_AND_MEDIAN_TYPE.DISTANCE_TYPE;

                pub fn init(shape: *Shape, alloc: Allocator) Self {
                    var self = Self{
                        .shape = shape,
                        .contour_combiner = CONTOUR_COMBINER.init_from_shape(shape, alloc),
                        .shape_edge_cache_list = List(CONTOUR_COMBINER.EDGE_CACHE_TYPE).init_capacity(@intCast(shape.edge_count()), alloc),
                    };
                    self.shape_edge_cache_list.len = shape.edge_count();
                    return self;
                }
                pub fn free(self: *Self, alloc: Allocator) void {
                    self.contour_combiner.free(alloc);
                    self.shape_edge_cache_list.free(alloc);
                }

                pub fn distance(self: *Self, point: Point, alloc: Allocator) DISTANCE_TYPE {
                    self.contour_combiner.reset(point);
                    for (self.shape.contours.slice(), 0..) |contour, c| {
                        if (!contour.edges.is_empty()) {
                            var edge_selector = self.contour_combiner.edge_selector_ptr(@intCast(c));
                            var prev_edge = if (contour.edges.len >= 2) contour.edges.get_nth_ptr_from_end(1) else contour.edges.get_first_ptr();
                            var curr_edge = contour.edges.get_last_ptr();
                            for (contour.edges.slice(), 0..) |*next_edge, e| {
                                const edge_cache_ptr = self.shape_edge_cache_list.get_ptr(e);
                                edge_selector.add_edge(edge_cache_ptr, prev_edge, curr_edge, next_edge);
                                prev_edge = curr_edge;
                                curr_edge = next_edge;
                            }
                        }
                    }
                    return self.contour_combiner.distance(alloc);
                }

                pub fn distance_skip_cache(shape: *Shape, point: Point, alloc: Allocator) DISTANCE_TYPE {
                    var contour_combiner = CONTOUR_COMBINER.init_from_shape(shape, alloc);
                    defer contour_combiner.free(alloc);
                    contour_combiner.reset(point);
                    for (shape.contours.slice(), 0..) |contour, c| {
                        if (!contour.edges.is_empty()) {
                            var edge_selector = contour_combiner.edge_selector_ptr(@intCast(c));
                            var prev_edge = if (contour.edges.len >= 2) contour.edges.get_nth_ptr_from_end(1) else contour.edges.get_first_ptr();
                            var curr_edge = contour.edges.get_last_ptr();
                            for (contour.edges.slice()) |*next_edge| {
                                const dummy_edge_cache: CONTOUR_COMBINER.EDGE_CACHE_TYPE = undefined;
                                edge_selector.add_edge(&dummy_edge_cache, prev_edge, curr_edge, next_edge);
                                prev_edge = curr_edge;
                                curr_edge = next_edge;
                            }
                        }
                    }
                    return contour_combiner.distance(alloc);
                }
            };
        }

        pub const Rasterize = struct {
            pub fn simple_rasterize_shape_to_bitmap(output: FloatBitmap(1), shape: *Shape, projection: Projection, fill_rule: FillRule, scanline: *Shape.Scanline, alloc: Allocator) void {
                var y: u32 = 0;
                var x: u32 = undefined;
                var is_filled: bool = undefined;
                while (y < output.height) : (y += 1) {
                    x = 0;
                    shape.get_horizontal_scanline_intersections(projection.un_project_y(num_cast(y, f32) + 0.5), scanline, alloc);
                    while (x < output.width) : (x += 1) {
                        is_filled = scanline.is_filled_at_x(projection.un_project_x(num_cast(x, f32) + 0.5), fill_rule);
                        output.set_pixel_channel_with_origin(.bot_left, x, y, .alpha, num_cast(is_filled, f32));
                    }
                }
            }

            pub const SignCorrectMode = enum(u8) {
                alpha_only,
                color_only,
                alpha_and_color,
            };

            pub fn correct_msdf_signs(mode: SignCorrectMode, comptime NUM_CHANNELS: comptime_int, msdf: FloatBitmap(NUM_CHANNELS), shape: *Shape, projection: Projection, signed_zero_value: f32, fill_rule: FillRule, scanline: *Shape.Scanline, alloc: Allocator) void {
                var y: u32 = 0;
                var x: u32 = undefined;
                var m: usize = 0;
                var is_filled: bool = undefined;
                var ambiguous: bool = false;
                const pixel_count = msdf.pixel_count();
                var match_map: List(i8) = if (mode == .color_only or mode == .alpha_and_color) List(i8).init_capacity(@intCast(pixel_count), alloc) else List(i8).init_empty();
                defer match_map.free(alloc);
                if (mode == .color_only or mode == .alpha_and_color) {
                    match_map.len = pixel_count;
                    @memset(match_map.slice(), 0);
                }
                const double_signed_zero = signed_zero_value + signed_zero_value;
                while (y < msdf.height) : (y += 1) {
                    x = 0;
                    shape.get_horizontal_scanline_intersections(projection.un_project_y(num_cast(y, f32) + 0.5), scanline, alloc);
                    while (x < msdf.width) : (x += 1) {
                        is_filled = scanline.is_filled_at_x(projection.un_project_x(num_cast(x, f32) + 0.5), fill_rule);
                        const pixel = msdf.get_pixel_ptr_with_origin(.bot_left, x, y);
                        switch (mode) {
                            .alpha_only, .alpha_and_color => {
                                assert_with_reason(NUM_CHANNELS == 1 or NUM_CHANNELS == 4, @src(), "an MSDF bitmap with {d} channels has no alpha (sdf) channel", .{NUM_CHANNELS});
                                const pixel_alpha = pixel.get(.alpha);
                                if ((pixel_alpha > signed_zero_value) != is_filled) {
                                    pixel.set(.alpha, double_signed_zero - pixel_alpha);
                                }
                            },
                            .color_only => {},
                        }
                        switch (mode) {
                            .color_only, .alpha_and_color => {
                                assert_with_reason(NUM_CHANNELS == 3 or NUM_CHANNELS == 4, @src(), "an MSDF bitmap with {d} channels has no color (msdf) channels", .{NUM_CHANNELS});
                                const color_median = pixel.median_of_3_channels(.red, .green, .blue);
                                if (color_median == signed_zero_value) {
                                    ambiguous = true;
                                } else if ((color_median > signed_zero_value) != is_filled) {
                                    pixel.set(.red, double_signed_zero - pixel.get(.red));
                                    pixel.set(.green, double_signed_zero - pixel.get(.green));
                                    pixel.set(.blue, double_signed_zero - pixel.get(.blue));
                                    match_map.ptr[m] = -1;
                                } else {
                                    match_map.ptr[m] = 1;
                                }
                                m += 1;
                            },
                            .alpha_only => {},
                        }
                    }
                }
                // This step is necessary to avoid artifacts when whole shape is inverted
                if (ambiguous) {
                    y = 0;
                    m = 0;
                    while (y < msdf.height) : (y += 1) {
                        x = 0;
                        while (x < msdf.width) : (x += 1) {
                            if (match_map[m] == 0) {
                                var neighbor_match: i8 = 0;
                                if (x > 0) neighbor_match += match_map[m - 1];
                                if (x < msdf.width - 1) neighbor_match += match_map[m + 1];
                                if (y > 0) neighbor_match += match_map[m - num_cast(msdf.width, usize)];
                                if (y < msdf.height - 1) neighbor_match += match_map[m + num_cast(msdf.width, usize)];
                                if (neighbor_match < 0) {
                                    const pixel = msdf.get_pixel_ptr_with_origin(.bot_left, x, y);
                                    pixel.set(.red, double_signed_zero - pixel.get(.red));
                                    pixel.set(.green, double_signed_zero - pixel.get(.green));
                                    pixel.set(.blue, double_signed_zero - pixel.get(.blue));
                                }
                            }
                            m += 1;
                        }
                    }
                }
            }

            /// Renders an MSDF bitmap to an arbitrary output bitmap
            ///
            /// The output bitmap MUST have at least ONE of the following conditions:
            ///   - all 3 of `.red` and `.green` and `.blue` channels
            ///   - an `.alpha` channel
            ///
            /// The output will result in the following depending on the MSDF and output formats:
            ///   - Output has alpha only:
            ///     - MSDF has alpha:
            ///       - MSDF alpha => Output alpha
            ///       - MSDF color is ignored (if exists)
            ///     - MSDF has color only:
            ///       - Median of MSDF color => Output alpha
            ///   - Output has color only:
            ///     - MSDF has color:
            ///       - MSDF color => Output color
            ///       - MSDF alpha is ignored (if exists)
            ///     - MSDF has alpha only:
            ///       - MSDF alpha => Each Output color channel (greyscale)
            ///   - Output has color and alpha:
            ///     - MSDF has alpha only:
            ///       - White (max vals) => Output color channels
            ///       - MSDF alpha => Output alpha
            ///     - MSDF has color only:
            ///       - MSDF color => Output color
            ///       - Opaque (max val) => Output alpha
            ///     - MSDF has color and alpha:
            ///       - MSDF color => Output color
            ///       - MSDF alpha => Output alpha
            pub fn render_msdf_using_cpu(comptime OUTPUT_BMP_DEF: BitmapDef, output: Bitmap(OUTPUT_BMP_DEF), comptime MSDF_NUM_CHANNELS: comptime_int, msdf: FloatBitmap(MSDF_NUM_CHANNELS), signed_pixel_range: Range, signed_threshhold: Float) void {
                const OUT_BMP = Bitmap(OUTPUT_BMP_DEF);
                const MSDF_BMP = FloatBitmap(MSDF_NUM_CHANNELS);
                const msdf_has_alpha = comptime MSDF_BMP.has_all_channels(&BitmapModule.A_Channel.tag_names);
                const msdf_has_color = comptime MSDF_BMP.has_all_channels(&BitmapModule.RGB_Channels.tag_names);
                // const msdf_has_color_and_alpha = msdf_has_color and msdf_has_alpha;
                const msdf_has_color_only = msdf_has_color and !msdf_has_alpha;
                const msdf_has_alpha_only = !msdf_has_color and msdf_has_alpha;
                const out_has_alpha = comptime OUT_BMP.has_all_channels(&BitmapModule.A_Channel.tag_names);
                const out_has_color = comptime OUT_BMP.has_all_channels(&BitmapModule.RGB_Channels.tag_names);
                const out_has_color_and_alpha = out_has_color and out_has_alpha;
                const out_has_color_only = out_has_color and !out_has_alpha;
                const out_has_alpha_only = !out_has_color and out_has_alpha;
                assert_with_reason(out_has_color or out_has_alpha, @src(), "output bitmap format does not specify either RGB channels, an Alpha channel, or both, you must implement your own rendering algorithm", .{});
                const scale = Vector.new(num_cast(msdf.width, f32) / num_cast(output.width, f32), num_cast(msdf.height, f32) / num_cast(output.height, f32));
                var y: u32 = 0;
                var x: u32 = undefined;
                if (signed_pixel_range.low == signed_pixel_range.high) {
                    while (y < output.height) : (y += 1) {
                        x = 0;
                        while (x < output.width) : (x += 1) {
                            const msdf_point = Point.new(num_cast(x, f32) + 0.5, num_cast(y, f32) + 0.5).scale(scale);
                            const msdf_interp = msdf.get_subpixel_mix_near_with_origin(.top_left, f32, msdf_point.x, msdf_point.y);
                            const output_ptr = output.get_pixel_ptr_with_origin(.top_left, x, y);
                            if (out_has_alpha_only) {
                                if (msdf_has_alpha) {
                                    output_ptr.set(.alpha, MathX.normalized_num_cast(msdf_interp.get(.alpha) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                } else {
                                    const median = msdf_interp.median_of_3_channels(.red, .green, .blue);
                                    output_ptr.set(.alpha, MathX.normalized_num_cast(median >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                }
                            } else if (out_has_color_only) {
                                if (msdf_has_color) {
                                    output_ptr.set(.red, MathX.normalized_num_cast(msdf_interp.get(.red) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    output_ptr.set(.green, MathX.normalized_num_cast(msdf_interp.get(.green) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    output_ptr.set(.blue, MathX.normalized_num_cast(msdf_interp.get(.blue) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                } else {
                                    const greyscale = OUT_BMP.Pixel.MAX_VALS.multiply_scalar(MathX.normalized_num_cast(msdf_interp.get(.alpha) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    output_ptr.* = greyscale;
                                }
                            } else if (out_has_color_and_alpha) {
                                if (msdf_has_alpha_only) {
                                    const white_with_alpha = OUT_BMP.Pixel.MAX_VALS.with_set(.alpha, MathX.normalized_num_cast(msdf_interp.get(.alpha) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    output_ptr.* = white_with_alpha;
                                } else if (msdf_has_color_only) {
                                    var color_fully_opaque = OUT_BMP.Pixel.MAX_VALS.with_set(.red, MathX.normalized_num_cast(msdf_interp.get(.red) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    color_fully_opaque.set(.green, MathX.normalized_num_cast(msdf_interp.get(.green) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    color_fully_opaque.set(.blue, MathX.normalized_num_cast(msdf_interp.get(.blue) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    output_ptr.* = color_fully_opaque;
                                } else {
                                    output_ptr.set(.red, MathX.normalized_num_cast(msdf_interp.get(.red) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    output_ptr.set(.green, MathX.normalized_num_cast(msdf_interp.get(.green) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    output_ptr.set(.blue, MathX.normalized_num_cast(msdf_interp.get(.blue) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                    output_ptr.set(.alpha, MathX.normalized_num_cast(msdf_interp.get(.alpha) >= signed_threshhold, OUT_BMP.CHANNEL_TYPE));
                                }
                            }
                        }
                    }
                } else {
                    const output_size_sum = num_cast(output.width + output.height, f32);
                    const msdf_size_sum = num_cast(msdf.width + msdf.height, f32);
                    const px_range_ratio = signed_pixel_range.multiplied_by(output_size_sum / msdf_size_sum);
                    const dist_map = DistanceMapping.new_from_range_inverse(px_range_ratio);
                    const bias = 0.5 - signed_threshhold;
                    while (y < output.height) : (y += 1) {
                        x = 0;
                        while (x < output.width) : (x += 1) {
                            const msdf_point = Point.new(num_cast(x, f32) + 0.5, num_cast(y, f32) + 0.5).scale(scale);
                            const msdf_interp = msdf.get_subpixel_mix_near_with_origin(.top_left, f32, msdf_point.x, msdf_point.y);
                            const output_ptr = output.get_pixel_ptr_with_origin(.top_left, x, y);
                            if (out_has_alpha_only) {
                                if (msdf_has_alpha) {
                                    output_ptr.set(.alpha, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.alpha)));
                                } else {
                                    const median = msdf_interp.median_of_3_channels(.red, .green, .blue);
                                    output_ptr.set(.alpha, dist_map.calc_biased_normalized_out(bias, median));
                                }
                            } else if (out_has_color_only) {
                                if (msdf_has_color) {
                                    output_ptr.set(.red, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.red)));
                                    output_ptr.set(.green, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.green)));
                                    output_ptr.set(.blue, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.blue)));
                                } else {
                                    const greyscale = OUT_BMP.Pixel.MAX_VALS.multiply_scalar(dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.alpha)));
                                    output_ptr.* = greyscale;
                                }
                            } else if (out_has_color_and_alpha) {
                                if (msdf_has_alpha_only) {
                                    const white_with_alpha = OUT_BMP.Pixel.MAX_VALS.with_set(.alpha, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.alpha)));
                                    output_ptr.* = white_with_alpha;
                                } else if (msdf_has_color_only) {
                                    var color_fully_opaque = OUT_BMP.Pixel.MAX_VALS.with_set(.red, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.red)));
                                    color_fully_opaque.set(.green, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.green)));
                                    color_fully_opaque.set(.blue, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.blue)));
                                    output_ptr.* = color_fully_opaque;
                                } else {
                                    output_ptr.set(.red, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.red)));
                                    output_ptr.set(.green, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.green)));
                                    output_ptr.set(.blue, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.blue)));
                                    output_ptr.set(.alpha, dist_map.calc_biased_normalized_out(bias, msdf_interp.get(.alpha)));
                                }
                            }
                        }
                    }
                }
            }
        };
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
pub const YAxisOrientation = enum {
    Y_UPWARD,
    Y_DOWNWARD,
};

pub const ErrorFlags = Flags.Flags(enum(u8) {
    NONE = 0,
    /// pixel marked as potentially causing interpolation errors.
    ERROR = 1,
    /// pixel marked as protected. Protected pixels are only given the error flag if they cause inversion artifacts.
    PROTECTED = 2,
}, enum(u8) {});

pub const ShapeError = error{
    shape_is_invalid,
};

pub const GeneratorError = error{
    shape_is_invalid,
};
