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
const Type = std.builtin.Type;
const Allocator = std.mem.Allocator;

const Root = @import("./_root.zig");
const Utils = Root.Utils;

pub fn define_aabb2_type(comptime T: type) type {
    return extern struct {
        const T_AABB2 = @This();
        const T_Vec2 = Root.Vec2.define_vec2_type(T);
        const T_Rect2 = Root.Rect2.define_rect2_type(T);
        const INF = if (@typeInfo(T).int) math.maxInt(T) else math.inf(T);
        const NEG_INF = if (@typeInfo(T).int) math.minInt(T) else -math.inf(T);
        const IS_FLOAT = switch (T) {
            f16, f32, f64, f80, f128, c_longdouble => true,
            else => false,
        };
        const IS_INT = switch (T) {
            i8, i16, i32, i64, i128, isize, u8, u16, u32, u64, u128, usize, c_short, c_int, c_long, c_longlong, c_char, c_ushort, c_uint, c_ulong, c_ulonglong => true,
            else => false,
        };
        const DEFAULT_EPSILON: T = if (IS_FLOAT) math.floatEps(T) else 0;

        x_min: T = INF,
        x_max: T = NEG_INF,
        y_min: T = INF,
        y_max: T = NEG_INF,

        pub fn new(x_min: T, x_max: T, y_min: T, y_max: T) T_AABB2 {
            return T_AABB2{ .x_min = x_min, .x_max = x_max, .y_min = y_min, .y_max = y_max };
        }

        pub fn new_from_point(point: T_Vec2) T_AABB2 {
            return T_AABB2{
                .x_max = point.x,
                .x_min = point.x,
                .y_min = point.y,
                .y_max = point.y,
            };
        }

        pub fn new_from_points(points: []const T_Vec2) T_AABB2 {
            var result = T_AABB2{
                .x_max = points[0].x,
                .x_min = points[0].x,
                .y_min = points[0].y,
                .y_max = points[0].y,
            };
            for (points[1..]) |point| {
                result.x_min = @min(result.x_min, point.x);
                result.y_min = @min(result.y_min, point.y);
                result.x_max = @max(result.x_max, point.x);
                result.y_max = @min(result.y_max, point.y);
            }
            return result;
        }

        pub fn combine_with(self: T_AABB2, other: T_AABB2) T_AABB2 {
            return T_AABB2{
                .x_min = @min(self.x_min, other.x_min),
                .y_min = @min(self.y_min, other.y_min),
                .x_max = @max(self.x_max, other.x_max),
                .y_max = @min(self.y_max, other.y_max),
            };
        }

        pub fn combine_with_point(self: T_AABB2, point: T_Vec2) T_AABB2 {
            return T_AABB2{
                .x_min = @min(self.x_min, point.x),
                .y_min = @min(self.y_min, point.y),
                .x_max = @max(self.x_max, point.x),
                .y_max = @min(self.y_max, point.y),
            };
        }

        pub fn combine_with_all_points(self: T_AABB2, points: []const T_Vec2) T_AABB2 {
            var result = self;
            for (points) |point| {
                result.x_min = @min(result.x_min, point.x);
                result.y_min = @min(result.y_min, point.y);
                result.x_max = @max(result.x_max, point.x);
                result.y_max = @min(result.y_max, point.y);
            }
            return result;
        }

        pub fn expand_by(self: T_AABB2, amount: T) T_AABB2 {
            return T_AABB2{
                .x_min = self.x_min - amount,
                .y_min = self.y_min - amount,
                .x_max = self.x_max + amount,
                .y_max = self.y_max + amount,
            };
        }

        pub fn from_static_circle_with_changing_radius(center: T_Vec2, t1_radius: T, t2_radius: T) T_AABB2 {
            return T_AABB2{
                .x_min = @min(center.x - t1_radius, center.x - t2_radius),
                .x_max = @max(center.x + t1_radius, center.x + t2_radius),
                .y_min = @min(center.y - t1_radius, center.y - t2_radius),
                .y_max = @max(center.y + t1_radius, center.y + t2_radius),
            };
        }

        pub fn from_static_circle(center: T_Vec2, radius: T) T_AABB2 {
            return T_AABB2{
                .x_min = center.x - radius,
                .x_max = center.x + radius,
                .y_min = center.y - radius,
                .y_max = center.y + radius,
            };
        }

        pub fn from_static_line(point_a: T_Vec2, point_b: T_Vec2) T_AABB2 {
            return T_AABB2{
                .x_min = @min(point_a.x, point_b.x),
                .x_max = @max(point_a.x, point_b.x),
                .y_min = @min(point_a.y, point_b.y),
                .y_max = @max(point_a.y, point_b.y),
            };
        }

        pub fn from_moving_circle(t1_center: T_Vec2, t2_center: T_Vec2, radius: T) T_AABB2 {
            return T_AABB2{
                .x_min = @min(t1_center.x - radius, t2_center.x - radius),
                .x_max = @max(t1_center.x + radius, t2_center.x + radius),
                .y_min = @min(t1_center.y - radius, t2_center.y - radius),
                .y_max = @max(t1_center.y + radius, t2_center.y + radius),
            };
        }

        pub fn from_moving_circle_with_changing_radius(t1_center: T_Vec2, t2_center: T_Vec2, t1_radius: T, t2_radius: T) T_AABB2 {
            return T_AABB2{
                .x_min = @min(t1_center.x - t1_radius, t2_center.x - t2_radius),
                .x_max = @max(t1_center.x + t1_radius, t2_center.x + t2_radius),
                .y_min = @min(t1_center.y - t1_radius, t2_center.y - t2_radius),
                .y_max = @max(t1_center.y + t1_radius, t2_center.y + t2_radius),
            };
        }

        pub fn from_moving_line(t1_point_a: T_Vec2, t2_point_a: T_Vec2, t1_point_b: T_Vec2, t2_point_b: T_Vec2) T_AABB2 {
            return T_AABB2{
                .x_min = @min(@min(t1_point_a.x, t2_point_a.x), @min(t1_point_b.x, t2_point_b.x)),
                .x_max = @max(@max(t1_point_a.x, t2_point_a.x), @max(t1_point_b.x, t2_point_b.x)),
                .y_min = @min(@min(t1_point_a.y, t2_point_a.y), @min(t1_point_b.y, t2_point_b.y)),
                .y_max = @max(@max(t1_point_a.y, t2_point_a.y), @max(t1_point_b.y, t2_point_b.y)),
            };
        }

        pub fn from_moving_point(t1_point: T_Vec2, t2_point: T_Vec2) T_AABB2 {
            return T_AABB2{
                .x_min = @min(t1_point.x, t2_point.x),
                .x_max = @max(t1_point.x, t2_point.x),
                .y_min = @min(t1_point.y, t2_point.y),
                .y_max = @max(t1_point.y, t2_point.y),
            };
        }

        pub fn from_static_point(t1_point: T_Vec2) T_AABB2 {
            return T_AABB2{
                .x_min = t1_point.x,
                .x_max = t1_point.x,
                .y_min = t1_point.y,
                .y_max = t1_point.y,
            };
        }

        pub fn overlaps(self: T_AABB2, other: T_AABB2) bool {
            return self.x_max >= other.x_min and other.x_max >= self.x_min and self.y_max >= other.y_min and other.y_max >= self.y_min;
        }

        pub fn approx_overlaps(self: T_AABB2, other: T_AABB2) bool {
            self.approx_overlaps_threshold(other, DEFAULT_EPSILON);
        }

        pub fn approx_overlaps_threshold(self: T_AABB2, other: T_AABB2, threshold: T) bool {
            return self.x_max + threshold >= other.x_min - threshold and other.x_max + threshold >= self.x_min - threshold and self.y_max + threshold >= other.y_min - threshold and other.y_max + threshold >= self.y_min - threshold;
        }

        pub fn overlap_area(self: T_AABB2, other: T_AABB2) ?T_AABB2 {
            const overlap_x_min = @max(self.x_min, other.x_min);
            const overlap_x_max = @min(self.x_max, other.x_max);
            if (overlap_x_min >= overlap_x_max) return null;
            const overlap_y_min = @max(self.y_min, other.y_min);
            const overlap_y_max = @min(self.y_max, other.y_max);
            if (overlap_y_min >= overlap_y_max) return null;
            return T_AABB2{
                .x_min = overlap_x_min,
                .x_max = overlap_x_max,
                .y_min = overlap_y_min,
                .y_max = overlap_y_max,
            };
        }

        pub fn overlap_area_approx(self: T_AABB2, other: T_AABB2) ?T_AABB2 {
            return self.overlap_area_approx_threshold(other, DEFAULT_EPSILON);
        }

        pub fn overlap_area_approx_threshold(self: T_AABB2, other: T_AABB2, threshold: T) ?T_AABB2 {
            const overlap_x_min = @max(self.x_min - threshold, other.x_min - threshold);
            const overlap_x_max = @min(self.x_max + threshold, other.x_max + threshold);
            if (overlap_x_min >= overlap_x_max) return null;
            const overlap_y_min = @max(self.y_min - threshold, other.y_min - threshold);
            const overlap_y_max = @min(self.y_max + threshold, other.y_max + threshold);
            if (overlap_y_min >= overlap_y_max) return null;
            return T_AABB2{
                .x_min = overlap_x_min,
                .x_max = overlap_x_max,
                .y_min = overlap_y_min,
                .y_max = overlap_y_max,
            };
        }

        pub fn overlap_area_guaranteed(self: T_AABB2, other: T_AABB2) T_AABB2 {
            const overlap_x_min = @max(self.x_min, other.x_min);
            const overlap_x_max = @min(self.x_max, other.x_max);
            const overlap_y_min = @max(self.y_min, other.y_min);
            const overlap_y_max = @min(self.y_max, other.y_max);
            return T_AABB2{
                .x_min = overlap_x_min,
                .x_max = overlap_x_max,
                .y_min = overlap_y_min,
                .y_max = overlap_y_max,
            };
        }

        pub fn overlap_area_approx_guaranteed_threshold(self: T_AABB2, other: T_AABB2, threshold: T) T_AABB2 {
            const overlap_x_min = @max(self.x_min - threshold, other.x_min - threshold);
            const overlap_x_max = @min(self.x_max + threshold, other.x_max + threshold);
            const overlap_y_min = @max(self.y_min - threshold, other.y_min - threshold);
            const overlap_y_max = @min(self.y_max + threshold, other.y_max + threshold);
            Utils.assert_with_reason(overlap_x_min < overlap_x_max and overlap_y_min < overlap_y_max, @src(), @This(), "", .{});
            return T_AABB2{
                .x_min = overlap_x_min,
                .x_max = overlap_x_max,
                .y_min = overlap_y_min,
                .y_max = overlap_y_max,
            };
        }

        pub fn point_within(self: T_AABB2, point: T_Vec2) bool {
            return self.x_max >= point.x and point.x >= self.x_min and self.y_max >= point.y and point.y >= self.y_min;
        }

        pub fn point_approx_within(self: T_AABB2, point: T_Vec2) bool {
            return self.point_approx_within_threshold(point, DEFAULT_EPSILON);
        }

        pub fn point_approx_within_threshold(self: T_AABB2, point: T_Vec2, threshold: T) bool {
            return self.x_max + threshold >= point.x - threshold and point.x + threshold >= self.x_min - threshold and self.y_max + threshold >= point.y - threshold and point.y + threshold >= self.y_min - threshold;
        }

        pub fn all_points_within(self: T_AABB2, points: []const T_Vec2) bool {
            for (points) |point| {
                const is_within = self.x_max >= point.x and point.x >= self.x_min and self.y_max >= point.y and point.y >= self.y_min;
                if (!is_within) return false;
            }
            return true;
        }

        pub fn all_points_approx_within(self: T_AABB2, points: []const T_Vec2) bool {
            return self.all_points_approx_within_threshold(points, DEFAULT_EPSILON);
        }

        pub fn all_points_approx_within_threshold(self: T_AABB2, points: []const T_Vec2, threshold: T) bool {
            const expanded = self.expand_by(threshold);
            for (points) |point| {
                const is_within = expanded.x_max >= point.x and point.x >= expanded.x_min and expanded.y_max >= point.y and point.y >= expanded.y_min;
                if (!is_within) return false;
            }
            return true;
        }

        pub fn to_rect2(self: T_AABB2) T_Rect2 {
            return T_Rect2{
                .x = self.x_min,
                .y = self.y_min,
                .w = self.x_max - self.x_min,
                .h = self.y_max - self.y_min,
            };
        }

        pub fn to_new_type(self: T_AABB2, comptime NEW_T: type) define_aabb2_type(NEW_T) {
            const A = define_aabb2_type(NEW_T);
            const mode = @as(u8, @bitCast(IS_FLOAT)) | (@as(u8, @bitCast(A.IS_FLOAT)) << 1);
            const FLOAT_TO_FLOAT: u8 = 0b11;
            const FLOAT_TO_INT: u8 = 0b01;
            const INT_TO_INT: u8 = 0b00;
            const INT_TO_FLOAT: u8 = 0b10;
            switch (mode) {
                FLOAT_TO_FLOAT => return A{
                    .x_max = @floatCast(self.x_max),
                    .x_min = @floatCast(self.x_min),
                    .y_max = @floatCast(self.y_max),
                    .y_min = @floatCast(self.y_min),
                },
                FLOAT_TO_INT => return A{
                    .x_max = @intFromFloat(self.x_max),
                    .x_min = @intFromFloat(self.x_min),
                    .y_max = @intFromFloat(self.y_max),
                    .y_min = @intFromFloat(self.y_min),
                },
                INT_TO_INT => return A{
                    .x_max = @intCast(self.x_max),
                    .x_min = @intCast(self.x_min),
                    .y_max = @intCast(self.y_max),
                    .y_min = @intCast(self.y_min),
                },
                INT_TO_FLOAT => return A{
                    .x_max = @floatFromInt(self.x_max),
                    .x_min = @floatFromInt(self.x_min),
                    .y_max = @floatFromInt(self.y_max),
                    .y_min = @floatFromInt(self.y_min),
                },
                else => unreachable,
            }
        }
    };
}
