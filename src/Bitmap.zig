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
const Color_ = Root.Color;
const Math = Root.Math;

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;

pub const YOrder = enum(u8) {
    top_to_bottom,
    bottom_to_top,
};
pub const XOrder = enum(u8) {
    left_to_right,
    right_to_left,
};

pub const Y_Invert = enum(u8) {
    same_y_order,
    invert_y,
};
pub const X_Invert = enum(u8) {
    same_x_order,
    invert_x,
};

pub const ResizeAnchor = enum(u8) {
    top_left,
    top_center,
    top_right,
    middle_left,
    middle_center,
    middle_right,
    bottom_left,
    bottom_center,
    bottom_right,
};

pub const RowColumnOrder = enum(u8) {
    row_major,
    column_major,
};

const TotalOrder = enum(u8) {
    row_major__top_to_bottom__left_to_right,
    row_major__top_to_bottom__right_to_left,
    row_major__bottom_to_top__left_to_right,
    row_major__bottom_to_top__right_to_left,
    column_major__top_to_bottom__left_to_right,
    column_major__top_to_bottom__right_to_left,
    column_major__bottom_to_top__left_to_right,
    column_major__bottom_to_top__right_to_left,
};

pub const RGB_Channels = enum(u8) {
    red,
    green,
    blue,
};
pub const BGR_Channels = enum(u8) {
    blue,
    green,
    red,
};
pub const RGBA_Channels = enum(u8) {
    red,
    green,
    blue,
    alpha,
};
pub const ABGR_Channels = enum(u8) {
    alpha,
    blue,
    green,
    red,
};
pub const ARGB_Channels = enum(u8) {
    alpha,
    red,
    green,
    blue,
};
pub const BGRA_Channels = enum(u8) {
    blue,
    green,
    red,
    alpha,
};
pub const RA_Channels = enum(u8) {
    red,
    alpha,
};
pub const A_Channel = enum(u8) {
    alpha,
};

pub const BitmapDefinition = struct {
    CHANNEL_TYPE: type = u8,
    CHANNELS_ENUM: type = RGB_Channels,
    ROW_COLUMN_ORDER: RowColumnOrder = .row_major,
    X_ORDER: XOrder = .left_to_right,
    Y_ORDER: YOrder = .top_to_bottom,
};

pub fn Bitmap(comptime DEFINITION: BitmapDefinition) type {
    return struct {
        const Self = @This();

        pixels: [*]Pixel = @ptrFromInt(std.mem.alignBackward(usize, math.maxInt(usize), @alignOf(Pixel))),
        width: u32 = 0,
        height: u32 = 0,

        pub const CHANNEL_UINT = DEFINITION.CHANNEL_TYPE;
        pub const CHANNELS = DEFINITION.CHANNELS_ENUM;
        pub const ROW_COLUMN_ORDER = DEFINITION.ROW_COLUMN_ORDER;
        pub const X_ORDER = DEFINITION.X_ORDER;
        pub const Y_ORDER = DEFINITION.Y_ORDER;
        pub const TOTAL_ORDER: TotalOrder = switch (X_ORDER) {
            .left_to_right => switch (Y_ORDER) {
                .top_to_bottom => switch (ROW_COLUMN_ORDER) {
                    .row_major => .row_major__top_to_bottom__left_to_right,
                    .column_major => .column_major__top_to_bottom__left_to_right,
                },
                .bottom_to_top => switch (ROW_COLUMN_ORDER) {
                    .row_major => .row_major__bottom_to_top__left_to_right,
                    .column_major => .column_major__bottom_to_top__left_to_right,
                },
            },
            .right_to_left => switch (Y_ORDER) {
                .top_to_bottom => switch (ROW_COLUMN_ORDER) {
                    .row_major => .row_major__top_to_bottom__right_to_left,
                    .column_major => .column_major__top_to_bottom__right_to_left,
                },
                .bottom_to_top => switch (ROW_COLUMN_ORDER) {
                    .row_major => .row_major__bottom_to_top__right_to_left,
                    .column_major => .column_major__bottom_to_top__right_to_left,
                },
            },
        };
        pub const Pixel = Color_.define_arbitrary_color_type(CHANNEL_UINT, CHANNELS);
        pub const NUM_CHANNELS = Pixel.CHANNEL_COUNT;
        pub const PIXEL_SIZE = Pixel.BYTE_SIZE;

        pub fn init(width: u32, height: u32, alloc: Allocator) Self {
            const total = width * height * PIXEL_SIZE;
            const mem = alloc.alloc(Pixel, total) catch |err| Assert.assert_allocation_failure(@src(), Pixel, total, err);
            return Self{
                .pixels = mem.ptr,
                .width = width,
                .height = height,
            };
        }
        pub fn free(self: Self, alloc: Allocator) void {
            const total = self.width * self.height * PIXEL_SIZE;
            alloc.free(self.pixels[0..total]);
        }

        pub fn get_idx(self: Self, x: u32, y: u32) u32 {
            assert_with_reason(x < self.width and y < self.height, @src(), "coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x, y, self.width, self.height });
            switch (TOTAL_ORDER) {
                .row_major__top_to_bottom__left_to_right => {
                    return x + (y * self.width);
                },
                .row_major__top_to_bottom__right_to_left => {
                    return (self.width - x - 1) + (y * self.width);
                },
                .row_major__bottom_to_top__left_to_right => {
                    return x + ((self.height - y - 1) * self.width);
                },
                .row_major__bottom_to_top__right_to_left => {
                    return (self.width - x - 1) + ((self.height - y - 1) * self.width);
                },
                .column_major__top_to_bottom__left_to_right => {
                    return y + (x * self.height);
                },
                .column_major__top_to_bottom__right_to_left => {
                    return (self.height - y - 1) + (x * self.height);
                },
                .column_major__bottom_to_top__left_to_right => {
                    return y + ((self.width - x - 1) * self.height);
                },
                .column_major__bottom_to_top__right_to_left => {
                    return (self.height - y - 1) + ((self.width - x - 1) * self.height);
                },
            }
        }
        pub fn get_idx_custom_order(self: Self, x: u32, y: u32, ordering: TOTAL_ORDER) u32 {
            assert_with_reason(x < self.width and y < self.height, @src(), "coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x, y, self.width, self.height });
            switch (ordering) {
                .row_major__top_to_bottom__left_to_right => {
                    return x + (y * self.width);
                },
                .row_major__top_to_bottom__right_to_left => {
                    return (self.width - x - 1) + (y * self.width);
                },
                .row_major__bottom_to_top__left_to_right => {
                    return x + ((self.height - y - 1) * self.width);
                },
                .row_major__bottom_to_top__right_to_left => {
                    return (self.width - x - 1) + ((self.height - y - 1) * self.width);
                },
                .column_major__top_to_bottom__left_to_right => {
                    return y + (x * self.height);
                },
                .column_major__top_to_bottom__right_to_left => {
                    return (self.height - y - 1) + (x * self.height);
                },
                .column_major__bottom_to_top__left_to_right => {
                    return y + ((self.width - x - 1) * self.height);
                },
                .column_major__bottom_to_top__right_to_left => {
                    return (self.height - y - 1) + ((self.width - x - 1) * self.height);
                },
            }
        }
        pub fn get_h_scanline(self: Self, x: u32, y: u32, width: u32) []Pixel {
            Assert.assert_with_reason(ROW_COLUMN_ORDER == .row_major, @src(), "can only use `get_h_scanline` when `ROW_COLUMN_ORDER == .row_major`", .{});
            const start = self.get_idx(x, y);
            switch (X_ORDER) {
                .left_to_right => {
                    const end = start + width;
                    assert_with_reason(end <= self.width * self.height, @src(), "scanline end index ({d}) falls outside the bitmap data range (len = {d})", .{ end, self.width * self.height });
                    return self.pixels[start..end];
                },
                .right_to_left => {
                    const real_end = start + 1;
                    assert_with_reason(real_end >= width, @src(), "scanline start index ({d}) is negative, starts before bitmap data range", .{@as(isize, @intCast(real_end)) - @as(isize, @intCast(width))});
                    const real_start = real_end - width;
                    return self.pixels[real_start..real_end];
                },
            }
        }
        pub fn get_v_scanline(self: Self, x: u32, y: u32, height: u32) []Pixel {
            Assert.assert_with_reason(ROW_COLUMN_ORDER == .column_major, @src(), "can only use `get_v_scanline` when `ROW_COLUMN_ORDER == .column_major`", .{});
            const start = self.get_idx(x, y);
            switch (Y_ORDER) {
                .top_to_bottom => {
                    const end = start + height;
                    assert_with_reason(end <= self.width * self.height, @src(), "scanline end index ({d}) falls outside the bitmap data range (len = {d})", .{ end, self.width * self.height });
                    return self.pixels[start..end];
                },
                .bottom_to_top => {
                    const real_end = start + 1;
                    assert_with_reason(real_end >= height, @src(), "scanline start index ({d}) is negative, starts before bitmap data range", .{@as(isize, @intCast(real_end)) - @as(isize, @intCast(height))});
                    const real_start = real_end - height;
                    return self.pixels[real_start..real_end];
                },
            }
        }
        pub fn get_pixel(self: Self, x: u32, y: u32) Pixel {
            const idx = self.get_idx(x, y);
            return self.pixels[idx];
        }
        pub fn get_pixel_channel(self: Self, x: u32, y: u32, chan: CHANNELS) CHANNEL_UINT {
            const idx = self.get_idx(x, y);
            return self.pixels[idx].raw[@intFromEnum(chan)];
        }
        pub fn get_pixel_channel_idx(self: Self, x: u32, y: u32, chan_idx: anytype) CHANNEL_UINT {
            assert_with_reason(chan_idx < Types.enum_max_field_count(CHANNELS), @src(), "channel index `{d}` is outside the bounds for the number of channels (max index = {d})", .{ chan_idx, Types.enum_max_field_count(CHANNELS) - 1 });
            const idx = self.get_idx(x, y);
            return self.pixels[idx].raw[chan_idx];
        }
        pub fn get_pixel_ptr(self: Self, x: u32, y: u32) *Pixel {
            const idx = self.get_idx(x, y);
            return &self.pixels[idx];
        }
        pub fn get_pixel_ptr_many(self: Self, x: u32, y: u32) [*]Pixel {
            const idx = self.get_idx(x, y);
            return @ptrCast(&self.pixels[idx]);
        }
        pub fn set_pixel(self: Self, x: u32, y: u32, val: Pixel) void {
            const idx = self.get_idx(x, y);
            self.pixels[idx] = val;
        }
        pub fn set_pixel_channel(self: Self, x: u32, y: u32, chan: CHANNELS, val: CHANNEL_UINT) void {
            const idx = self.get_idx(x, y);
            self.pixels[idx].raw[@intFromEnum(chan)] = val;
        }
        pub fn set_pixel_channel_idx(self: Self, x: u32, y: u32, chan_idx: anytype, val: CHANNEL_UINT) void {
            assert_with_reason(chan_idx < Types.enum_max_field_count(CHANNELS), @src(), "channel index `{d}` is outside the bounds for the number of channels (max index = {d})", .{ chan_idx, Types.enum_max_field_count(CHANNELS) - 1 });
            const idx = self.get_idx(x, y);
            self.pixels[idx].raw[chan_idx] = val;
        }
        pub fn get_subpixel_mix_near(self: Self, comptime F: type, x: F, y: F) Pixel {
            assert_with_reason(Types.type_is_float(F), @src(), "type `F` must be a float, got type `{s}`", .{@typeName(F)});
            var xx = Math.clamp_0_to_max(F, x, @floatFromInt(self.width));
            var yy = Math.clamp_0_to_max(F, y, @floatFromInt(self.height));
            xx -= 0.5;
            yy -= 0.5;
            const left_i: i32 = @intFromFloat(xx);
            const bot_i: i32 = @intFromFloat(yy);
            const right_i: i32 = left_i + 1;
            const top_i: i32 = bot_i + 1;
            const weight_left_right: F = xx - @as(F, @floatFromInt(left_i));
            const weight_top_bottom: F = yy - @as(F, @floatFromInt(bot_i));
            const left: u32 = @intCast(Math.clamp_0_to_max(i32, left_i, @intCast(self.width - 1)));
            const right: u32 = @intCast(Math.clamp_0_to_max(i32, right_i, @intCast(self.width - 1)));
            const top: u32 = @intCast(Math.clamp_0_to_max(i32, top_i, @intCast(self.height - 1)));
            const bot: u32 = @intCast(Math.clamp_0_to_max(i32, bot_i, @intCast(self.height - 1)));
            const subpixel = Pixel{};
            inline for (0..NUM_CHANNELS) |c| {
                subpixel.raw[c] = Math.weighted_average(
                    CHANNEL_UINT,
                    Math.weighted_average(CHANNEL_UINT, self.get_pixel_channel_idx(left, bot, c), self.get_pixel_channel_idx(right, bot, c), weight_left_right),
                    Math.weighted_average(CHANNEL_UINT, self.get_pixel_channel_idx(left, top, c), self.get_pixel_channel_idx(right, top, c), weight_left_right),
                    weight_top_bottom,
                );
            }
            return subpixel;
        }

        pub fn discard_and_resize(self: Self, new_width: u32, new_height: u32, fill_color: ?Pixel, alloc: Allocator) Self {
            if (self.width == 0 or self.height == 0) {
                if (new_width == 0 or new_height == 0) return self;
                return Self.init(new_width, new_height, alloc);
            }
            if (new_width == 0 or new_height == 0) {
                if (self.width == 0 or self.height == 0) return self;
                const mem_len = self.width * self.height;
                alloc.free(self.pixels[0..mem_len]);
                return Self{};
            }
            const old_len = self.width * self.height;
            const new_len = new_width * new_height;
            const new_mem = Utils.Alloc.realloc_custom(alloc, self.pixels[0..old_len], @intCast(new_len), .dont_copy_data, .init_new_custom_orelse_zero(fill_color), .dont_memset_old) catch |err| assert_allocation_failure(@src(), Pixel, new_len, err);
            return Self{
                .pixels = new_mem.ptr,
                .width = new_width,
                .height = new_height,
            };
        }

        pub fn resize(self: Self, new_width: u32, new_height: u32, anchor: ResizeAnchor, fill_color: ?Pixel, alloc: Allocator) Self {
            if (self.width == 0 or self.height == 0) {
                if (new_width == 0 or new_height == 0) return self;
                return Self.init(new_width, new_height, alloc);
            }
            if (new_width == 0 or new_height == 0) {
                if (self.width == 0 or self.height == 0) return self;
                const mem_len = self.width * self.height;
                alloc.free(self.pixels[0..mem_len]);
                return Self{};
            }
            const half_old_width = self.width >> 1;
            const half_old_height = self.height >> 1;
            const half_new_width = new_width >> 1;
            const half_new_height = new_height >> 1;
            const min_width = @min(self.width, new_width);
            const min_height = @min(self.height, new_height);
            const half_min_width = min_width >> 1;
            const half_min_height = min_height >> 1;
            var min_x_copy_old: u32 = undefined;
            var max_x_copy_old: u32 = undefined;
            var min_y_copy_old: u32 = undefined;
            var max_y_copy_old: u32 = undefined;
            var min_x_copy_new: u32 = undefined;
            var max_x_copy_new: u32 = undefined;
            var min_y_copy_new: u32 = undefined;
            var max_y_copy_new: u32 = undefined;
            switch (anchor) {
                .top_left, .middle_left, .bottom_left => {
                    min_x_copy_old = 0;
                    max_x_copy_old = min_width;
                    min_x_copy_new = 0;
                    max_x_copy_new = min_width;
                },
                .top_center, .middle_center, .bottom_center => {
                    min_x_copy_old = half_old_width - half_min_width;
                    max_x_copy_old = min_x_copy_old + min_width;
                    min_x_copy_new = half_new_width - half_min_width;
                    max_x_copy_new = min_x_copy_new + min_width;
                },
                .top_right, .middle_right, .bottom_right => {
                    min_x_copy_old = self.width - min_width;
                    max_x_copy_old = self.width;
                    min_x_copy_new = new_width - min_width;
                    max_x_copy_new = new_width;
                },
            }
            switch (anchor) {
                .top_left, .top_center, .top_right => {
                    min_y_copy_old = 0;
                    max_y_copy_old = min_height;
                    min_y_copy_new = 0;
                    max_y_copy_new = min_height;
                },
                .middle_left, .middle_center, .middle_right => {
                    min_y_copy_old = half_old_height - half_min_height;
                    max_y_copy_old = min_y_copy_old + min_height;
                    min_y_copy_new = half_new_height - half_min_height;
                    max_y_copy_new = min_y_copy_new + min_height;
                },
                .bottom_left, .bottom_center, .bottom_right => {
                    min_y_copy_old = self.height - min_height;
                    max_y_copy_old = self.height;
                    min_y_copy_new = new_height - min_height;
                    max_y_copy_new = new_height;
                },
            }
            const new_bmp = Self.init(new_width, new_height, alloc);
            switch (ROW_COLUMN_ORDER) {
                .row_major => {
                    for (min_y_copy_old..max_y_copy_old, min_y_copy_new..max_y_copy_new) |old_y, new_y| {
                        const old_line = self.get_h_scanline(min_x_copy_old, old_y, min_width);
                        const new_line = new_bmp.get_h_scanline(min_x_copy_new, new_y, min_width);
                        @memcpy(new_line, old_line);
                    }
                },
                .column_major => {
                    for (min_x_copy_old..max_x_copy_old, min_x_copy_new..max_x_copy_new) |old_x, new_x| {
                        const old_line = self.get_v_scanline(min_y_copy_old, old_x, min_height);
                        const new_line = new_bmp.get_v_scanline(min_y_copy_new, new_x, min_height);
                        @memcpy(new_line, old_line);
                    }
                },
            }
            self.free(alloc);
            if (fill_color) |fill| {
                const fill_x1 = 0;
                const fill_x2 = min_x_copy_new;
                const fill_x3 = max_x_copy_new;
                const fill_x4 = new_width;
                const fill_y1 = 0;
                const fill_y2 = min_y_copy_new;
                const fill_y3 = max_y_copy_new;
                const fill_y4 = new_height;
                switch (ROW_COLUMN_ORDER) {
                    .row_major => {
                        new_bmp.fill_rect_xy(fill_x1, fill_y1, fill_x4, fill_y2, fill);
                        new_bmp.fill_rect_xy(fill_x1, fill_y2, fill_x2, fill_y3, fill);
                        new_bmp.fill_rect_xy(fill_x3, fill_y2, fill_x4, fill_y3, fill);
                        new_bmp.fill_rect_xy(fill_x1, fill_y3, fill_x4, fill_y4, fill);
                    },
                    .column_major => {
                        new_bmp.fill_rect_xy(fill_x1, fill_y1, fill_x2, fill_y4, fill);
                        new_bmp.fill_rect_xy(fill_x2, fill_y1, fill_x3, fill_y2, fill);
                        new_bmp.fill_rect_xy(fill_x2, fill_y3, fill_x3, fill_y4, fill);
                        new_bmp.fill_rect_xy(fill_x3, fill_y1, fill_x4, fill_y4, fill);
                    },
                }
            }
            return new_bmp;
        }

        fn fill_rect_internal(self: Self, x1: u32, y1: u32, x2: u32, y2: u32, width: u32, height: u32, fill_color: Pixel) void {
            switch (ROW_COLUMN_ORDER) {
                .row_major => {
                    if (y2 != y1) {
                        if (x1 == 0 and width == self.width) {
                            const fill_block = self.get_h_scanline(x1, y1, self.width * (height));
                            @memset(fill_block, fill_color);
                        } else {
                            for (y1..y2) |y| {
                                const fill_line = self.get_h_scanline(x1, y, width);
                                @memset(fill_line, fill_color);
                            }
                        }
                    }
                },
                .column_major => {
                    if (x2 != x1) {
                        if (y1 == 0 and height == self.height) {
                            const fill_block = self.get_v_scanline(x1, y1, self.height * (width));
                            @memset(fill_block, fill_color);
                        } else {
                            for (x1..x2) |x| {
                                const fill_line = self.get_v_scanline(x, y1, height);
                                @memset(fill_line, fill_color);
                            }
                        }
                    }
                },
            }
        }

        pub fn fill_all(self: Self, fill_color: Pixel) void {
            self.fill_rect(0, 0, self.width, self.height, fill_color);
        }
        pub fn fill_rect(self: Self, x: u32, y: u32, width: u32, height: u32, fill_color: Pixel) void {
            assert_with_reason(x + width <= self.width and y + height <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
            const x2 = x + width;
            const y2 = y + height;
            self.fill_rect_internal(x, y, x2, y2, width, height, fill_color);
        }
        pub fn fill_rect_xy(self: Self, x1: u32, y1: u32, x2: u32, y2: u32, fill_color: Pixel) void {
            assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
            assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
            assert_with_reason(x2 <= self.width and y2 <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x2, y2, self.width, self.height });
            const width = x2 - x1;
            const height = y2 - y1;
            self.fill_rect_internal(x1, y1, x2, y2, width, height, fill_color);
        }

        fn copy_rect_to_internal(source: Self, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32, comptime overlap: bool) void {
            assert_with_reason(x_src + width <= source.width and y_src + height <= source.height, @src(), "bottom-right source coordinate ({d}, {d}) is outside the source bitmap width/height ({d}, {d})", .{ x_src + width, y_src + height, source.width, source.height });
            assert_with_reason(x_dest + width <= dest.width and y_dest + height <= dest.height, @src(), "bottom-right destination coordinate ({d}, {d}) is outside the destination bitmap width/height ({d}, {d})", .{ x_dest + width, y_dest + height, dest.width, dest.height });
            const y_src_2 = y_src + height;
            const x_src_2 = x_src + width;
            const y_dest_2 = y_dest + height;
            const x_dest_2 = x_dest + width;
            switch (ROW_COLUMN_ORDER) {
                .row_major => {
                    if (y_src_2 != y_src) {
                        if (x_src == 0 and x_dest == 0 and width == source.width and width == dest.width) {
                            const from_block = source.get_h_scanline(x_src, y_src, source.width * (height));
                            const to_block = source.get_h_scanline(x_dest, y_dest, dest.width * (height));
                            if (overlap) {
                                @memmove(to_block, from_block);
                            } else {
                                @memcpy(to_block, from_block);
                            }
                        } else {
                            for (y_src..y_src_2, y_dest..y_dest_2) |y, yy| {
                                const from_line = source.get_h_scanline(x_src, y, width);
                                const to_line = source.get_h_scanline(x_dest, yy, width);
                                if (overlap) {
                                    @memmove(to_line, from_line);
                                } else {
                                    @memcpy(to_line, from_line);
                                }
                            }
                        }
                    }
                },
                .column_major => {
                    if (x_src_2 != x_src) {
                        if (y_src == 0 and y_dest == 0 and height == source.height and height == dest.height) {
                            const from_block = source.get_v_scanline(x_src, y_src, source.height * (width));
                            const to_block = source.get_v_scanline(x_dest, y_dest, dest.height * (width));
                            if (overlap) {
                                @memmove(to_block, from_block);
                            } else {
                                @memcpy(to_block, from_block);
                            }
                        } else {
                            for (x_src..x_src_2, x_dest..x_dest_2) |x, xx| {
                                const from_line = source.get_v_scanline(x, y_src, height);
                                const to_line = source.get_v_scanline(xx, y_dest, height);
                                if (overlap) {
                                    @memmove(to_line, from_line);
                                } else {
                                    @memcpy(to_line, from_line);
                                }
                            }
                        }
                    }
                },
            }
        }

        pub fn copy_rect_to(source: Self, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32) void {
            source.copy_rect_to_internal(x_src, y_src, width, height, dest, x_dest, y_dest, false);
        }

        pub fn copy_rect_to_possible_overlap(source: Self, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32) void {
            source.copy_rect_to_internal(x_src, y_src, width, height, dest, x_dest, y_dest, true);
        }

        pub fn get_region(self: Self, x: u32, y: u32, width: u32, height: u32) Region {
            assert_with_reason(x + width <= self.width and y + height <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
            return Region{
                .bmp = self,
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            };
        }
        // pub fn get_region_change_order(self: Self, x: u32, y: u32, width: u32, height: u32, x_invert: X_Invert, y_invert: Y_Invert) Region {
        //     assert_with_reason(x + width <= self.width and y + height <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
        //     return Region{
        //         .bmp = self,
        //         .x = x,
        //         .y = y,
        //         .width = width,
        //         .height = height,
        //         .x_invert = x_invert,
        //         .y_invert = y_invert,
        //     };
        // }
        pub fn get_region_xy(self: Self, x1: u32, y1: u32, x2: u32, y2: u32) Region {
            assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
            assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
            assert_with_reason(x2 <= self.width and y2 <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x2, y2, self.width, self.height });
            const width = x2 - x1;
            const height = y2 - y1;
            return Region{
                .bmp = self,
                .x = x1,
                .y = y1,
                .width = width,
                .height = height,
            };
        }
        // pub fn get_region_xy_change_order(self: Self, x1: u32, y1: u32, x2: u32, y2: u32, x_invert: X_Invert, y_invert: Y_Invert) Region {
        //     assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
        //     assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
        //     assert_with_reason(x2 <= self.width and y2 <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x2, y2, self.width, self.height });
        //     const width = x2 - x1;
        //     const height = y2 - y1;
        //     return Region{
        //         .bmp = self,
        //         .x = x1,
        //         .y = y1,
        //         .width = width,
        //         .height = height,
        //         .x_invert = x_invert,
        //         .y_invert = y_invert,
        //     };
        // }

        pub const Region = struct {
            bmp: Self,
            x: u32,
            y: u32,
            width: u32,
            height: u32,
            // x_invert: X_Invert = .same_x_order,
            // y_invert: Y_Invert = .same_y_order,

            pub fn major_stride(self: Region) u32 {
                return switch (ROW_COLUMN_ORDER) {
                    .row_major => self.bmp.width,
                    .column_major => self.bmp.height,
                };
            }

            pub fn get_idx(self: Region, x: u32, y: u32) u32 {
                assert_with_reason(x < self.width and y < self.height, @src(), "coordinate ({d}, {d}) is outside the region width/height ({d}, {d})", .{ x, y, self.width, self.height });
                // const xx = switch (self.x_invert) {
                //     .same_x_order => x + self.x,
                //     .invert_x => self.x + self.width - x,
                // };
                // const yy = switch (self.y_invert) {
                //     .same_y_order => y + self.y,
                //     .invert_y => self.y + self.height - y,
                // };
                return self.bmp.get_idx(x + self.x, y + self.y);
            }
            pub fn get_h_scanline(self: Region, x: u32, y: u32, width: u32) []Pixel {
                const idx = self.get_idx(x, y);
                return self.bmp.get_h_scanline(idx.x, idx.y, width);
            }
            pub fn get_v_scanline(self: Region, x: u32, y: u32, height: u32) []Pixel {
                const idx = self.get_idx(x, y);
                return self.bmp.get_v_scanline(idx.x, idx.y, height);
            }

            pub fn get_pixel(self: Region, x: u32, y: u32) Pixel {
                const idx = self.get_idx(x, y);
                return self.bmp.pixels[idx];
            }
            pub fn get_pixel_ptr(self: Region, x: u32, y: u32) *Pixel {
                const idx = self.get_idx(x, y);
                return &self.bmp.pixels[idx];
            }
            pub fn get_pixel_ptr_many(self: Region, x: u32, y: u32) [*]Pixel {
                const idx = self.get_idx(x, y);
                return @ptrCast(&self.bmp.pixels[idx]);
            }
            pub fn get_pixel_channel(self: Region, x: u32, y: u32, chan: CHANNELS) CHANNEL_UINT {
                const idx = self.get_idx(x, y);
                return self.bmp.pixels[idx].raw[@intFromEnum(chan)];
            }
            pub fn get_pixel_channel_idx(self: Region, x: u32, y: u32, chan_idx: anytype) CHANNEL_UINT {
                const idx = self.get_idx(x, y);
                return self.bmp.pixels[idx].raw[chan_idx];
            }
            pub fn set_pixel(self: Region, x: u32, y: u32, val: Pixel) void {
                const idx = self.get_idx(x, y);
                self.bmp.pixels[idx] = val;
            }
            pub fn set_pixel_channel(self: Region, x: u32, y: u32, chan: CHANNELS, val: CHANNEL_UINT) void {
                const idx = self.get_idx(x, y);
                self.bmp.pixels[idx].raw[@intFromEnum(chan)] = val;
            }
            pub fn set_pixel_channel_idx(self: Region, x: u32, y: u32, chan_idx: anytype, val: CHANNEL_UINT) void {
                const idx = self.get_idx(x, y);
                self.bmp.pixels[idx].raw[chan_idx] = val;
            }

            pub fn fill_all(self: Region, fill_color: Pixel) void {
                self.fill_rect(0, 0, self.width, self.height, fill_color);
            }

            pub fn fill_rect(self: Region, x: u32, y: u32, width: u32, height: u32, fill_color: Pixel) void {
                assert_with_reason(x + width < self.width and y + height < self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the region width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
                const x2 = x + width;
                const y2 = y + height;
                self.bmp.fill_rect_internal(x + self.x, y + self.y, x2 + self.x, y2 + self.y, width, height, fill_color);
            }
            pub fn fill_rect_xy(self: Region, x1: u32, y1: u32, x2: u32, y2: u32, fill_color: Pixel) void {
                assert_with_reason(x2 < self.width and y2 < self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the region width/height ({d}, {d})", .{ x2, y2, self.width, self.height });
                const width = x2 - x1;
                const height = y2 - y1;
                self.bmp.fill_rect_internal(x1 + self.x, y1 + self.y, x2 + self.x, y2 + self.y, width, height, fill_color);
            }

            pub fn copy_rect_to(source: Region, x_src: u32, y_src: u32, width: u32, height: u32, dest: Region, x_dest: u32, y_dest: u32) void {
                assert_with_reason(x_src + width < source.width and y_src + height < source.height, @src(), "bottom-right source coordinate ({d}, {d}) is outside the source region width/height ({d}, {d})", .{ x_src + width, y_src + height, source.width, source.height });
                assert_with_reason(x_dest + width < dest.width and y_dest + height < dest.height, @src(), "bottom-right destination coordinate ({d}, {d}) is outside the destination region width/height ({d}, {d})", .{ x_dest + width, y_dest + height, dest.width, dest.height });
                source.bmp.copy_rect_to_internal(x_src, y_src, width, height, dest, x_dest, y_dest, false);
            }

            pub fn copy_rect_to_possible_overlap(source: Region, x_src: u32, y_src: u32, width: u32, height: u32, dest: Region, x_dest: u32, y_dest: u32) void {
                assert_with_reason(x_src + width < source.width and y_src + height < source.height, @src(), "bottom-right source coordinate ({d}, {d}) is outside the source region width/height ({d}, {d})", .{ x_src + width, y_src + height, source.width, source.height });
                assert_with_reason(x_dest + width < dest.width and y_dest + height < dest.height, @src(), "bottom-right destination coordinate ({d}, {d}) is outside the destination region width/height ({d}, {d})", .{ x_dest + width, y_dest + height, dest.width, dest.height });
                source.bmp.copy_rect_to_internal(x_src + source.x, y_src + source.y, width, height, dest, x_dest + dest.x, y_dest + dest.y, true);
            }

            pub fn get_region(self: Region, x: u32, y: u32, width: u32, height: u32) Region {
                assert_with_reason(x + width <= self.width and y + height <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the region width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
                return Region{
                    .bmp = self,
                    .x = self.x + x,
                    .y = self.y + y,
                    .width = width,
                    .height = height,
                    .x_invert = self.x_invert,
                    .y_invert = self.y_invert,
                };
            }
            // pub fn get_region_change_order(self: Region, x: u32, y: u32, width: u32, height: u32, x_invert: X_Invert, y_invert: Y_Invert) Region {
            //     assert_with_reason(x + width <= self.width and y + height <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the region width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
            //     return Region{
            //         .bmp = self,
            //         .x = self.x + x,
            //         .y = self.y + y,
            //         .width = width,
            //         .height = height,
            //         .x_invert = if (x_invert == .invert_x) switch (self.x_invert) {
            //             .invert_x => .same_x_order,
            //             .same_x_order => .invert_x,
            //         } else self.x_invert,
            //         .y_invert = if (y_invert == .invert_y) switch (self.y_invert) {
            //             .invert_y => .same_y_order,
            //             .same_y_order => .invert_y,
            //         } else self.y_invert,
            //     };
            // }
            pub fn get_region_xy(self: Region, x1: u32, y1: u32, x2: u32, y2: u32) Region {
                assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
                assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
                assert_with_reason(x2 <= self.width and y2 <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the region width/height ({d}, {d})", .{ x2, y2, self.width, self.height });
                const width = x2 - x1;
                const height = y2 - y1;
                return Region{
                    .bmp = self,
                    .x = self.x + x1,
                    .y = self.y + y1,
                    .width = width,
                    .height = height,
                    .x_invert = self.x_invert,
                    .y_invert = self.y_invert,
                };
            }
            // pub fn get_region_xy_change_order(self: Region, x1: u32, y1: u32, x2: u32, y2: u32, x_invert: X_Invert, y_invert: Y_Invert) Region {
            //     assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
            //     assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
            //     assert_with_reason(x2 <= self.width and y2 <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the region width/height ({d}, {d})", .{ x2, y2, self.width, self.height });
            //     const width = x2 - x1;
            //     const height = y2 - y1;
            //     return Region{
            //         .bmp = self,
            //         .x = self.x + x1,
            //         .y = self.y + y1,
            //         .width = width,
            //         .height = height,
            //         .x_invert = if (x_invert == .invert_x) switch (self.x_invert) {
            //             .invert_x => .same_x_order,
            //             .same_x_order => .invert_x,
            //         } else self.x_invert,
            //         .y_invert = if (y_invert == .invert_y) switch (self.y_invert) {
            //             .invert_y => .same_y_order,
            //             .same_y_order => .invert_y,
            //         } else self.y_invert,
            //     };
            // }
            pub fn get_subpixel_mix4(self: Region, comptime F: type, x: F, y: F) Pixel {
                assert_with_reason(Types.type_is_float(F), @src(), "type `F` must be a float, got type `{s}`", .{@typeName(F)});
                var xx = Math.clamp_0_to_max(F, x, @floatFromInt(self.width));
                var yy = Math.clamp_0_to_max(F, y, @floatFromInt(self.height));
                xx -= 0.5;
                yy -= 0.5;
                const left_i: i32 = @intFromFloat(xx);
                const bot_i: i32 = @intFromFloat(yy);
                const right_i: i32 = left_i + 1;
                const top_i: i32 = bot_i + 1;
                const weight_left_right: F = xx - @as(F, @floatFromInt(left_i));
                const weight_top_bottom: F = yy - @as(F, @floatFromInt(bot_i));
                const left: u32 = @intCast(Math.clamp_0_to_max(i32, left_i, @intCast(self.width - 1)));
                const right: u32 = @intCast(Math.clamp_0_to_max(i32, right_i, @intCast(self.width - 1)));
                const top: u32 = @intCast(Math.clamp_0_to_max(i32, top_i, @intCast(self.height - 1)));
                const bot: u32 = @intCast(Math.clamp_0_to_max(i32, bot_i, @intCast(self.height - 1)));
                const subpixel = Pixel{};
                inline for (0..NUM_CHANNELS) |c| {
                    subpixel.raw[c] = Math.weighted_average(
                        CHANNEL_UINT,
                        Math.weighted_average(CHANNEL_UINT, self.get_pixel_channel_idx(left, bot, c), self.get_pixel_channel_idx(right, bot, c), weight_left_right),
                        Math.weighted_average(CHANNEL_UINT, self.get_pixel_channel_idx(left, top, c), self.get_pixel_channel_idx(right, top, c), weight_left_right),
                        weight_top_bottom,
                    );
                }
                return subpixel;
            }
        };
    };
}
