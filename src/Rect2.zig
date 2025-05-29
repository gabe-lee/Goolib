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
const mem = std.mem;

const Root = @import("./_root.zig");

pub fn define_rect2_type(comptime T: type) type {
    return extern struct {
        const T_Rect2 = @This();
        const T_AABB2 = Root.AABB2.define_aabb2_type(T);
        const T_Vec2 = Root.Vec2.define_vec2_type(T);
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

        x: T = 0,
        y: T = 0,
        w: T = 0,
        h: T = 0,

        pub fn new(x: T, y: T, w: T, h: T) T_Rect2 {
            return T_Rect2{ .x = x, .y = y, .w = w, .h = h };
        }

        pub fn overlaps(self: T_Rect2, other: T_Rect2) bool {
            return self.to_aabb2().overlaps(other.to_aabb2());
        }

        pub fn approx_overlaps(self: T_Rect2, other: T_Rect2) bool {
            return self.to_aabb2().approx_overlaps(other.to_aabb2());
        }

        pub fn overlap_area(self: T_Rect2, other: T_Rect2) ?T_Rect2 {
            const overlap_aabb = self.to_aabb2().overlap_area(other.to_aabb2());
            if (overlap_aabb) |aabb| return aabb.to_rect2();
            return null;
        }

        pub fn overlap_area_guaranteed(self: T_Rect2, other: T_Rect2) T_Rect2 {
            return self.to_aabb2().overlap_area_graranteed(other.to_aabb2()).to_rect2();
        }

        pub fn point_within(self: T_Rect2, point: T_Vec2) bool {
            return self.to_aabb2().point_within(point);
        }

        pub fn all_points_within(self: T_Rect2, points: []const T_Vec2) bool {
            return self.to_aabb2().all_points_within(points);
        }

        pub fn point_approx_within(self: T_Rect2, point: T_Vec2) bool {
            return self.to_aabb2().point_approx_within(point);
        }

        pub fn equals(self: T_Rect2, other: T_Rect2) bool {
            var result: u8 = @as(u8, @intCast(@intFromBool(self.x == other.x)));
            result |= @as(u8, @intCast(@intFromBool(self.y == other.y))) << 1;
            result |= @as(u8, @intCast(@intFromBool(self.w == other.w))) << 2;
            result |= @as(u8, @intCast(@intFromBool(self.h == other.h))) << 3;
            return result == 0b1111;
        }

        pub fn to_aabb2(self: T_Rect2) T_AABB2 {
            return T_AABB2{
                .x_min = self.x,
                .y_min = self.y,
                .x_max = self.x + self.w,
                .y_max = self.y + self.h,
            };
        }

        pub fn to_new_type(self: T_Rect2, comptime NEW_T: type) define_rect2_type(NEW_T) {
            const R = define_rect2_type(NEW_T);
            const mode = @as(u8, @bitCast(IS_FLOAT)) | (@as(u8, @bitCast(R.IS_FLOAT)) << 1);
            const FLOAT_TO_FLOAT: u8 = 0b11;
            const FLOAT_TO_INT: u8 = 0b01;
            const INT_TO_INT: u8 = 0b00;
            const INT_TO_FLOAT: u8 = 0b10;
            switch (mode) {
                FLOAT_TO_FLOAT => return R{
                    .x = @floatCast(self.x),
                    .y = @floatCast(self.y),
                    .w = @floatCast(self.w),
                    .h = @floatCast(self.h),
                },
                FLOAT_TO_INT => return R{
                    .x = @intFromFloat(self.x),
                    .y = @intFromFloat(self.y),
                    .w = @intFromFloat(self.w),
                    .h = @intFromFloat(self.h),
                },
                INT_TO_INT => return R{
                    .x = @intCast(self.x),
                    .y = @intCast(self.y),
                    .w = @intCast(self.w),
                    .h = @intCast(self.h),
                },
                INT_TO_FLOAT => return R{
                    .x = @floatFromInt(self.x),
                    .y = @floatFromInt(self.y),
                    .w = @floatFromInt(self.w),
                    .h = @floatFromInt(self.h),
                },
                else => unreachable,
            }
        }
    };
}
