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

        // pub fn combine_with(self: T_Rect2, other: T_Rect2) T_Rect2 {
        //     return T_Rect2{
        //         .x_min = @min(self.x_min, other.x_min),
        //         .y_min = @min(self.y_min, other.y_min),
        //         .x_max = @max(self.x_max, other.x_max),
        //         .y_max = @min(self.y_max, other.y_max),
        //     };
        // }

        // pub fn combine_with_point(self: T_Rect2, point: T_Vec2) T_Rect2 {
        //     return T_Rect2{
        //         .x_min = @min(self.x_min, point.x),
        //         .y_min = @min(self.y_min, point.y),
        //         .x_max = @max(self.x_max, point.x),
        //         .y_max = @min(self.y_max, point.y),
        //     };
        // }

        // pub fn expand_by(self: T_Rect2, amount: T) T_Rect2 {
        //     return T_Rect2{
        //         .x_min = self.x_min - amount,
        //         .y_min = self.y_min - amount,
        //         .x_max = self.x_max + amount,
        //         .y_max = self.y_max + amount,
        //     };
        // }

        pub fn overlaps(self: T_Rect2, other: T_Rect2) bool {
            return self.to_aabb2().overlaps(other.to_aabb2());
        }

        pub fn approx_overlaps(self: T_Rect2, other: T_Rect2) bool {
            return self.to_aabb2().approx_overlaps(other.to_aabb2());
        }

        pub fn point_within(self: T_Rect2, point: T_Vec2) bool {
            return self.to_aabb2().point_within(point);
        }

        pub fn point_approx_within(self: T_Rect2, point: T_Vec2) bool {
            return self.to_aabb2().point_approx_within(point);
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
