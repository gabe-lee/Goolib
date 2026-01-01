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
const Color_ = Root.Color;
const MathX = Root.Math;

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

pub const YOrder = enum(u8) {
    top_to_bottom,
    bottom_to_top,
};
pub const XOrder = enum(u8) {
    left_to_right,
    right_to_left,
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

pub const Origin = enum(u8) {
    top_left,
    top_right,
    bot_left,
    bot_right,
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
    red = 0,
    green = 1,
    blue = 2,

    pub const tag_names = [_][:0]const u8{
        "red",
        "green",
        "blue",
    };
};
pub const BGR_Channels = enum(u8) {
    blue = 0,
    green = 1,
    red = 2,

    pub const tag_names = [_][:0]const u8{
        "blue",
        "green",
        "red",
    };
};
pub const RGBA_Channels = enum(u8) {
    red = 0,
    green = 1,
    blue = 2,
    alpha = 3,

    pub const tag_names = [_][:0]const u8{
        "red",
        "green",
        "blue",
        "alpha",
    };
};
pub const ABGR_Channels = enum(u8) {
    alpha = 0,
    blue = 1,
    green = 2,
    red = 3,

    pub const tag_names = [_][:0]const u8{
        "alpha",
        "blue",
        "green",
        "red",
    };
};
pub const ARGB_Channels = enum(u8) {
    alpha = 0,
    red = 1,
    green = 2,
    blue = 3,

    pub const tag_names = [_][:0]const u8{
        "alpha",
        "red",
        "green",
        "blue",
    };
};
pub const BGRA_Channels = enum(u8) {
    blue = 0,
    green = 1,
    red = 2,
    alpha = 3,

    pub const tag_names = [_][:0]const u8{
        "blue",
        "green",
        "red",
        "alpha",
    };
};
pub const RA_Channels = enum(u8) {
    red = 0,
    alpha = 1,

    pub const tag_names = [_][:0]const u8{
        "red",
        "alpha",
    };
};
pub const A_Channel = enum(u8) {
    alpha = 0,

    pub const tag_names = [_][:0]const u8{
        "alpha",
    };
};

pub const BitmapDefinition = struct {
    CHANNEL_TYPE: type = u8,
    CHANNELS_ENUM: type = RGB_Channels,
    ROW_COLUMN_ORDER: RowColumnOrder = .row_major,
    X_ORDER: XOrder = .left_to_right,
    Y_ORDER: YOrder = .top_to_bottom,
};

pub const BitmapOpaque = struct {
    bytes: List(u8),
    bytes_width: u32,
    bytes_height: u32,
    bytes_major_stride: u32,
    owns_memory: bool,

    pub fn to_typed(self: BitmapOpaque, comptime DEF: BitmapDefinition) Bitmap(DEF) {
        const BMP = Bitmap(DEF);
        const new_width = self.bytes_width / @sizeOf(BMP.Pixel);
        const new_height = self.bytes_height / @sizeOf(BMP.Pixel);
        const new_stride = self.bytes_major_stride / @sizeOf(BMP.Pixel);
        const recalced_width_bytes = new_width * @sizeOf(BMP.Pixel);
        const recalced_height_bytes = new_height * @sizeOf(BMP.Pixel);
        const recalced_stride_bytes = new_stride * @sizeOf(BMP.Pixel);
        assert_with_reason(recalced_width_bytes == self.bytes_width, @src(), "cannot convert opaque bitmap to one with pixel type `{s} x {d}`, loss of width bytes", .{ @typeName(BMP.Pixel.TYPE), BMP.Pixel.CHANNEL_COUNT });
        assert_with_reason(recalced_height_bytes == self.bytes_height, @src(), "cannot convert opaque bitmap to one with pixel type `{s} x {d}`, loss of height bytes", .{ @typeName(BMP.Pixel.TYPE), BMP.Pixel.CHANNEL_COUNT });
        assert_with_reason(recalced_stride_bytes == self.bytes_major_stride, @src(), "cannot convert opaque bitmap to one with pixel type `{s} x {d}`, loss of stride bytes", .{ @typeName(BMP.Pixel.TYPE), BMP.Pixel.CHANNEL_COUNT });
        return BMP{
            .pixels = self.bytes.cast_to_type(BMP.Pixel),
            .width = new_width,
            .height = new_height,
            .major_stride = new_stride,
            .owns_memory = self.owns_memory,
        };
    }
};

pub fn Bitmap(comptime DEFINITION: BitmapDefinition) type {
    return struct {
        const Self = @This();

        pixels: List(Pixel) = .{},
        width: u32 = 0,
        height: u32 = 0,
        major_stride: u32 = 0,
        owns_memory: bool = false,

        pub const CHANNEL_TYPE = DEFINITION.CHANNEL_TYPE;
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
        pub const Pixel = Color_.define_arbitrary_color_type(CHANNEL_TYPE, CHANNELS);
        pub const NUM_CHANNELS = Pixel.CHANNEL_COUNT;
        pub const PIXEL_SIZE = Pixel.BYTE_SIZE;

        pub fn init(width: u32, height: u32, fill_color: ?Pixel, alloc: Allocator) Self {
            const total = width * height * PIXEL_SIZE;
            var self = Self{
                .pixels = List(Pixel).init_capacity(total, alloc),
                .width = width,
                .height = height,
                .major_stride = if (ROW_COLUMN_ORDER == .row_major) width else height,
                .owns_memory = true,
            };
            if (fill_color) |fill| {
                self.fill_all(fill);
            }
            return self;
        }
        pub fn init_from_existing_pixel_buffer(width: u32, height: u32, fill_color: ?Pixel, buffer: List(Pixel), alloc: Allocator) Self {
            const total = width * height * PIXEL_SIZE;
            buffer.clear();
            buffer.ensure_free_slots(total, alloc);
            buffer.len = total;
            var self = Self{
                .pixels = buffer,
                .width = width,
                .height = height,
                .major_stride = if (ROW_COLUMN_ORDER == .row_major) width else height,
                .owns_memory = true,
            };
            if (fill_color) |fill| {
                self.fill_all(fill);
            }
            return self;
        }
        pub fn free(self: *Self, alloc: Allocator) void {
            assert_with_reason(self.owns_memory, @src(), "cannot free: this bitmap does not own its memory (it is a region-of or reference-to another bitmap, or is uninitialized)", .{});
            const total = self.width * self.height * PIXEL_SIZE;
            alloc.free(self.pixels.ptr[0..total]);
            self.width = 0;
            self.height = 0;
            self.major_stride = 0;
        }
        pub fn free_retain_buffer(self: *Self) List(Pixel) {
            assert_with_reason(self.owns_memory, @src(), "cannot free: this bitmap does not own its memory (it is a region-of or reference-to another bitmap, or is uninitialized)", .{});
            self.width = 0;
            self.height = 0;
            self.major_stride = 0;
            var buf = self.pixels.ptr;
            self.pixels.ptr = .{};
            self.owns_memory = false;
            buf.clear();
            return buf;
        }
        pub fn clear(self: *Self) void {
            assert_with_reason(self.owns_memory, @src(), "cannot clear: this bitmap does not own its memory (it is a region-of or reference-to another bitmap, or is uninitialized)", .{});
            self.pixels.ptr.clear();
            self.width = 0;
            self.height = 0;
            self.major_stride = 0;
        }
        pub fn to_opaque(self: Self) BitmapOpaque {
            return BitmapOpaque{
                .bytes = self.pixels.cast_to_byte_list(),
                .bytes_height = self.height * @sizeOf(Pixel),
                .bytes_width = self.width * @sizeOf(Pixel),
                .bytes_major_stride = self.major_stride * @sizeOf(Pixel),
                .owns_memory = self.owns_memory,
            };
        }

        pub inline fn pixel_count(self: Self) u32 {
            return self.width * self.height;
        }
        pub inline fn pixel_slice(self: Self) []Pixel {
            return self.pixels.ptr[0..self.pixel_count()];
        }

        pub fn has_all_channels(comptime channel_tags: []const [:0]const u8) bool {
            inline for (channel_tags) |tag| {
                if (!Types.is_valid_tag_name_for_enum(CHANNELS, tag)) return false;
            }
            return true;
        }

        pub inline fn get_x_with_origin(self: Self, origin: Origin, x: u32) u32 {
            return switch (origin) {
                .bot_left, .top_left => if (X_ORDER == .left_to_right) x else (self.width - 1 - x),
                .bot_right, .top_right => if (X_ORDER == .right_to_left) x else (self.width - 1 - x),
            };
        }
        pub inline fn get_y_with_origin(self: Self, origin: Origin, y: u32) u32 {
            return switch (origin) {
                .top_left, .top_right => if (Y_ORDER == .top_to_bottom) y else (self.height - 1 - y),
                .bot_left, .bot_right => if (Y_ORDER == .bottom_to_top) y else (self.height - 1 - y),
            };
        }
        pub inline fn get_x_delta_with_origin(origin: Origin, x_delta: i32) i32 {
            return switch (origin) {
                .bot_left, .top_left => if (X_ORDER == .left_to_right) x_delta else -x_delta,
                .bot_right, .top_right => if (X_ORDER == .right_to_left) x_delta else -x_delta,
            };
        }
        pub inline fn get_y_delta_with_origin(origin: Origin, y_delta: i32) i32 {
            return switch (origin) {
                .top_left, .top_right => if (Y_ORDER == .top_to_bottom) y_delta else -y_delta,
                .bot_left, .bot_right => if (Y_ORDER == .bottom_to_top) y_delta else -y_delta,
            };
        }
        inline fn get_x_with_origin_float(self: Self, origin: Origin, comptime F: type, x: F) F {
            return switch (origin) {
                .bot_left, .top_left => if (X_ORDER == .left_to_right) x else (num_cast(self.width, F) - 1 - x),
                .bot_right, .top_right => if (X_ORDER == .right_to_left) x else (num_cast(self.width, F) - 1 - x),
            };
        }
        inline fn get_y_with_origin_float(self: Self, origin: Origin, comptime F: type, y: F) F {
            return switch (origin) {
                .top_left, .top_right => if (Y_ORDER == .top_to_bottom) y else (num_cast(self.height, F) - 1 - y),
                .bot_left, .bot_right => if (Y_ORDER == .bottom_to_top) y else (num_cast(self.height, F) - 1 - y),
            };
        }
        inline fn get_x_with_origin_and_width(self: Self, origin: Origin, x: u32, width: u32, width_direction: XOrder) u32 {
            const xx = self.get_x_with_origin(origin, x);
            return if (width_direction == X_ORDER) xx else xx - width;
        }
        inline fn get_y_with_origin_and_height(self: Self, origin: Origin, y: u32, height: u32, height_direction: XOrder) u32 {
            const yy = self.get_y_with_origin(origin, y);
            return if (height_direction == Y_ORDER) yy else yy - height;
        }

        pub fn move_pixel_ptr_many_native(self: Self, x_delta: i32, y_delta: i32, ptr: [*]Pixel) [*]Pixel {
            const idx_delta = switch (ROW_COLUMN_ORDER) {
                .row_major => return MathX.minor_major_coord_to_idx(x_delta, y_delta, num_cast(self.major_stride, i32)),
                .column_major => MathX.minor_major_coord_to_idx(y_delta, x_delta, num_cast(self.major_stride, i32)),
            };
            return switch (idx_delta < 1) {
                true => ptr - num_cast(@abs(idx_delta), usize),
                false => ptr + num_cast(idx_delta, usize),
            };
        }
        pub inline fn move_pixel_ptr_many_with_origin(self: Self, origin: Origin, x_delta: i32, y_delta: i32, ptr: [*]Pixel) [*]Pixel {
            self.move_pixel_ptr_native(get_x_delta_with_origin(origin, x_delta), get_y_delta_with_origin(origin, y_delta), ptr);
        }
        pub fn move_pixel_ptr_native(self: Self, x_delta: i32, y_delta: i32, ptr: *Pixel) *Pixel {
            return @ptrCast(self.move_pixel_ptr_many_native(x_delta, y_delta, @ptrCast(ptr)));
        }
        pub inline fn move_pixel_ptr_with_origin(self: Self, origin: Origin, x_delta: i32, y_delta: i32, ptr: *Pixel) *Pixel {
            return @ptrCast(self.move_pixel_ptr_many_with_origin(origin, x_delta, y_delta, @ptrCast(ptr)));
        }

        pub fn get_idx_native(self: Self, x: u32, y: u32) u32 {
            assert_with_reason(x < self.width and y < self.height, @src(), "coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x, y, self.width, self.height });
            switch (ROW_COLUMN_ORDER) {
                .row_major => {
                    return MathX.minor_major_coord_to_idx(x, y, self.major_stride);
                },
                .column_major => {
                    return MathX.minor_major_coord_to_idx(y, x, self.major_stride);
                },
            }
        }
        pub inline fn get_idx_with_origin(self: Self, origin: Origin, x: u32, y: u32) u32 {
            return self.get_idx_native(self.get_x_with_origin(origin, x), self.get_y_with_origin(origin, y));
        }
        pub fn get_scanline_native(self: Self, x: u32, y: u32, length: u32) []Pixel {
            assert_with_reason(x < self.width and y < self.height, @src(), "coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x, y, self.width, self.height });
            const start = self.get_idx_native(x, y);
            const end = start + length;
            assert_with_reason(end <= self.width * self.height, @src(), "scanline starting from ({d}, {d}) with length {d} (end index = {d}) is outside the bitmap length (len = {d})", .{ x, y, length, end, self.width * self.height });
        }
        pub fn get_h_scanline_native(self: Self, x: u32, y: u32, width: u32) []Pixel {
            Assert.assert_with_reason(ROW_COLUMN_ORDER == .row_major, @src(), "can only use `get_h_scanline` when `ROW_COLUMN_ORDER == .row_major`", .{});
            return self.get_scanline_native(x, y, width);
        }
        pub fn get_h_scanline_with_origin(self: Self, origin: Origin, x: u32, y: u32, width_direction: XOrder, width: u32) []Pixel {
            return self.get_h_scanline_native(self.get_x_with_origin_and_width(origin, x, width, width_direction), y, width);
        }
        pub fn get_v_scanline_native(self: Self, x: u32, y: u32, height: u32) []Pixel {
            Assert.assert_with_reason(ROW_COLUMN_ORDER == .column_major, @src(), "can only use `get_v_scanline` when `ROW_COLUMN_ORDER == .column_major`", .{});
            return self.get_scanline_native(x, y, height);
        }
        pub fn get_v_scanline_with_origin(self: Self, origin: Origin, x: u32, y: u32, height_direction: YOrder, height: u32) []Pixel {
            return self.get_v_scanline_native(x, self.get_y_with_origin_and_height(origin, y, height, height_direction), height);
        }
        pub fn get_pixel_native(self: Self, x: u32, y: u32) Pixel {
            const idx = self.get_idx_native(x, y);
            return self.pixels.ptr[idx];
        }
        pub fn get_pixel_with_origin(self: Self, origin: Origin, x: u32, y: u32) Pixel {
            const idx = self.get_idx_with_origin(origin, x, y);
            return self.pixels.ptr[idx];
        }
        pub fn get_pixel_channel_native(self: Self, x: u32, y: u32, chan: CHANNELS) CHANNEL_TYPE {
            const idx = self.get_idx_native(x, y);
            return self.pixels.ptr[idx].raw[@intFromEnum(chan)];
        }
        pub fn get_pixel_channel_with_origin(self: Self, origin: Origin, x: u32, y: u32, chan: CHANNELS) CHANNEL_TYPE {
            const idx = self.get_idx_with_origin(origin, x, y);
            return self.pixels.ptr[idx].raw[@intFromEnum(chan)];
        }
        pub fn get_pixel_channel_ptr_native(self: Self, x: u32, y: u32, chan: CHANNELS) *CHANNEL_TYPE {
            const idx = self.get_idx_native(x, y);
            return &self.pixels.ptr[idx].raw[@intFromEnum(chan)];
        }
        pub fn get_pixel_channel_ptr_with_origin(self: Self, origin: Origin, x: u32, y: u32, chan: CHANNELS) *CHANNEL_TYPE {
            const idx = self.get_idx_with_origin(origin, x, y);
            return &self.pixels.ptr[idx].raw[@intFromEnum(chan)];
        }
        pub fn get_pixel_channel_idx_native(self: Self, x: u32, y: u32, chan_idx: anytype) CHANNEL_TYPE {
            assert_with_reason(chan_idx < Types.enum_max_field_count(CHANNELS), @src(), "channel index `{d}` is outside the bounds for the number of channels (max index = {d})", .{ chan_idx, Types.enum_max_field_count(CHANNELS) - 1 });
            const idx = self.get_idx_native(x, y);
            return self.pixels.ptr[idx].raw[chan_idx];
        }
        pub fn get_pixel_channel_idx_with_origin(self: Self, origin: Origin, x: u32, y: u32, chan_idx: anytype) CHANNEL_TYPE {
            assert_with_reason(chan_idx < Types.enum_max_field_count(CHANNELS), @src(), "channel index `{d}` is outside the bounds for the number of channels (max index = {d})", .{ chan_idx, Types.enum_max_field_count(CHANNELS) - 1 });
            const idx = self.get_idx_with_origin(origin, x, y);
            return self.pixels.ptr[idx].raw[chan_idx];
        }
        pub fn get_pixel_ptr_native(self: Self, x: u32, y: u32) *Pixel {
            const idx = self.get_idx_native(x, y);
            return &self.pixels.ptr[idx];
        }
        pub fn get_pixel_ptr_with_origin(self: Self, origin: Origin, x: u32, y: u32) *Pixel {
            const idx = self.get_idx_with_origin(origin, x, y);
            return &self.pixels.ptr[idx];
        }
        pub fn get_pixel_ptr_many_native(self: Self, x: u32, y: u32) [*]Pixel {
            const idx = self.get_idx_native(x, y);
            return @ptrCast(&self.pixels.ptr[idx]);
        }
        pub fn get_pixel_ptr_many_with_origin(self: Self, origin: Origin, x: u32, y: u32) [*]Pixel {
            const idx = self.get_idx_with_origin(origin, x, y);
            return @ptrCast(&self.pixels.ptr[idx]);
        }
        pub fn set_pixel_native(self: Self, x: u32, y: u32, val: Pixel) void {
            const idx = self.get_idx_native(x, y);
            self.pixels.ptr[idx] = val;
        }
        pub fn set_pixel_with_origin(self: Self, origin: Origin, x: u32, y: u32, val: Pixel) void {
            const idx = self.get_idx_with_origin(origin, x, y);
            self.pixels.ptr[idx] = val;
        }
        pub fn set_pixel_channel_native(self: Self, x: u32, y: u32, chan: CHANNELS, val: CHANNEL_TYPE) void {
            const idx = self.get_idx_native(x, y);
            self.pixels.ptr[idx].raw[@intFromEnum(chan)] = val;
        }
        pub fn set_pixel_channel_with_origin(self: Self, origin: Origin, x: u32, y: u32, chan: CHANNELS, val: CHANNEL_TYPE) void {
            const idx = self.get_idx_with_origin(origin, x, y);
            self.pixels.ptr[idx].raw[@intFromEnum(chan)] = val;
        }
        pub fn set_pixel_channel_idx_native(self: Self, x: u32, y: u32, chan_idx: anytype, val: CHANNEL_TYPE) void {
            assert_with_reason(chan_idx < Types.enum_max_field_count(CHANNELS), @src(), "channel index `{d}` is outside the bounds for the number of channels (max index = {d})", .{ chan_idx, Types.enum_max_field_count(CHANNELS) - 1 });
            const idx = self.get_idx_native(x, y);
            self.pixels.ptr[idx].raw[chan_idx] = val;
        }
        pub fn set_pixel_channel_idx_with_origin(self: Self, origin: Origin, x: u32, y: u32, chan_idx: anytype, val: CHANNEL_TYPE) void {
            assert_with_reason(chan_idx < Types.enum_max_field_count(CHANNELS), @src(), "channel index `{d}` is outside the bounds for the number of channels (max index = {d})", .{ chan_idx, Types.enum_max_field_count(CHANNELS) - 1 });
            const idx = self.get_idx_with_origin(origin, x, y);
            self.pixels.ptr[idx].raw[chan_idx] = val;
        }
        pub fn get_subpixel_mix_near_native(self: Self, comptime F: type, x: F, y: F) Pixel {
            assert_with_reason(Types.type_is_float(F), @src(), "type `F` must be a float, got type `{s}`", .{@typeName(F)});
            var xx = MathX.clamp_0_to_max(x, @as(f32, @floatFromInt(self.width)));
            var yy = MathX.clamp_0_to_max(y, @as(f32, @floatFromInt(self.height)));
            xx -= 0.5;
            yy -= 0.5;
            const left_i: i32 = @intFromFloat(xx);
            const bot_i: i32 = @intFromFloat(yy);
            const right_i: i32 = left_i + 1;
            const top_i: i32 = bot_i + 1;
            const weight_left_right: F = xx - @as(F, @floatFromInt(left_i));
            const weight_top_bottom: F = yy - @as(F, @floatFromInt(bot_i));
            const left: u32 = @intCast(MathX.clamp_0_to_max(i32, left_i, @intCast(self.width - 1)));
            const right: u32 = @intCast(MathX.clamp_0_to_max(i32, right_i, @intCast(self.width - 1)));
            const top: u32 = @intCast(MathX.clamp_0_to_max(i32, top_i, @intCast(self.height - 1)));
            const bot: u32 = @intCast(MathX.clamp_0_to_max(i32, bot_i, @intCast(self.height - 1)));
            const subpixel = Pixel{};
            inline for (0..NUM_CHANNELS) |c| {
                subpixel.raw[c] = MathX.lerp(
                    MathX.lerp(self.get_pixel_channel_idx_native(left, bot, c), self.get_pixel_channel_idx_native(right, bot, c), weight_left_right),
                    MathX.lerp(self.get_pixel_channel_idx_native(left, top, c), self.get_pixel_channel_idx_native(right, top, c), weight_left_right),
                    weight_top_bottom,
                );
            }
            return subpixel;
        }
        pub fn get_subpixel_mix_near_with_origin(self: Self, origin: Origin, comptime F: type, x: F, y: F) Pixel {
            self.get_subpixel_mix_near_native(F, self.get_x_with_origin_float(origin, F, x), self.get_y_with_origin_float(origin, F, y));
        }

        pub fn discard_and_resize(self: *Self, new_width: u32, new_height: u32, fill_color: ?Pixel, alloc: Allocator) void {
            assert_with_reason(self.owns_memory, @src(), "cannot resize: this bitmap does not own its memory (it is a region-of or reference-to another bitmap, or is uninitialized)", .{});
            if (self.width == 0 or self.height == 0) {
                if (new_width == 0 or new_height == 0) return;
                self.* = init_from_existing_pixel_buffer(new_width, new_height, fill_color, self.pixels, alloc);
                return;
            }
            if (new_width == 0 or new_height == 0) {
                if (self.width == 0 or self.height == 0) return;
                self.clear(alloc);
                return;
            }
            const new_len = new_width * new_height;
            self.pixels.ptr.clear();
            self.pixels.ptr.ensure_free_slots(@intCast(new_len), alloc);
            self.width = new_width;
            self.height = new_height;
        }

        pub fn resize(self: *Self, new_width: u32, new_height: u32, anchor: ResizeAnchor, fill_color: ?Pixel, alloc: Allocator) void {
            assert_with_reason(self.owns_memory, @src(), "cannot resize: this bitmap does not own its memory (it is a region-of or reference-to another bitmap, or is uninitialized)", .{});
            if (self.width == 0 or self.height == 0) {
                if (new_width == 0 or new_height == 0) return;
                self.* = init_from_existing_pixel_buffer(new_width, new_height, fill_color, self.pixels, alloc);
                return;
            }
            if (new_width == 0 or new_height == 0) {
                if (self.width == 0 or self.height == 0) return;
                self.clear();
                return;
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
            self.* = new_bmp;
        }

        fn fill_rect_internal_native(self: Self, x1: u32, y1: u32, x2: u32, y2: u32, width: u32, height: u32, fill_color: Pixel) void {
            switch (ROW_COLUMN_ORDER) {
                .row_major => {
                    if (y2 != y1) {
                        if (x1 == 0 and width == self.width) {
                            const fill_block = self.get_h_scanline_native(x1, y1, self.width * (height));
                            @memset(fill_block, fill_color);
                        } else {
                            for (y1..y2) |y| {
                                const fill_line = self.get_h_scanline_native(x1, y, width);
                                @memset(fill_line, fill_color);
                            }
                        }
                    }
                },
                .column_major => {
                    if (x2 != x1) {
                        if (y1 == 0 and height == self.height) {
                            const fill_block = self.get_v_scanline_native(x1, y1, self.height * (width));
                            @memset(fill_block, fill_color);
                        } else {
                            for (x1..x2) |x| {
                                const fill_line = self.get_v_scanline_native(x, y1, height);
                                @memset(fill_line, fill_color);
                            }
                        }
                    }
                },
            }
        }

        pub fn fill_all(self: Self, fill_color: Pixel) void {
            self.fill_rect_native(0, 0, self.width, self.height, fill_color);
        }
        pub fn fill_rect_native(self: Self, x: u32, y: u32, width: u32, height: u32, fill_color: Pixel) void {
            assert_with_reason(x + width <= self.width and y + height <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
            const x2 = x + width;
            const y2 = y + height;
            self.fill_rect_internal_native(x, y, x2, y2, width, height, fill_color);
        }
        pub fn fill_rect_with_origin(self: Self, origin: Origin, x: u32, y: u32, width: u32, height: u32, width_dir: XOrder, height_dir: YOrder, fill_color: Pixel) void {
            const x1 = self.get_x_with_origin_and_width(origin, x, width, width_dir);
            const y1 = self.get_y_with_origin_and_height(origin, y, height, height_dir);
            assert_with_reason(x1 + width <= self.width and y1 + height <= self.height, @src(), "max extent coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x1 + width, y1 + height, self.width, self.height });
            const x2 = x + width;
            const y2 = y + height;
            self.fill_rect_internal_native(x1, y1, x2, y2, width, height, fill_color);
        }
        pub fn fill_rect_xy_native(self: Self, x1: u32, y1: u32, x2: u32, y2: u32, fill_color: Pixel) void {
            assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
            assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
            assert_with_reason(x2 <= self.width and y2 <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x2, y2, self.width, self.height });
            const width = x2 - x1;
            const height = y2 - y1;
            self.fill_rect_internal_native(x1, y1, x2, y2, width, height, fill_color);
        }
        pub fn fill_rect_xy_with_origin(self: Self, origin: Origin, x1: u32, y1: u32, x2: u32, y2: u32, fill_color: Pixel) void {
            assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
            assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
            const width = x2 - x1;
            const height = y2 - y1;
            const xx1 = self.get_x_with_origin(origin, x1);
            const xx2 = self.get_x_with_origin(origin, x2);
            const yy1 = self.get_y_with_origin(origin, y1);
            const yy2 = self.get_y_with_origin(origin, y2);
            assert_with_reason(xx2 <= self.width and yy2 <= self.height, @src(), "max extent coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ xx2, yy2, self.width, self.height });
            self.fill_rect_internal_native(xx1, yy1, xx2, yy2, width, height, fill_color);
        }

        fn copy_rect_to_internal_native(source: Self, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32, comptime overlap: bool) void {
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

        pub fn copy_rect_to_native(source: Self, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32) void {
            source.copy_rect_to_internal_native(x_src, y_src, width, height, dest, x_dest, y_dest, false);
        }
        pub fn copy_rect_to_with_origin(source: Self, origin: Origin, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32, width_dir: XOrder, height_dir: YOrder) void {
            const xx_src = source.get_x_with_origin_and_width(origin, x_src, width, width_dir);
            const yy_src = source.get_y_with_origin_and_height(origin, y_src, height, height_dir);
            const xx_dest = dest.get_x_with_origin_and_width(origin, x_dest, width, width_dir);
            const yy_dest = dest.get_y_with_origin_and_height(origin, y_dest, height, height_dir);
            source.copy_rect_to_internal_native(xx_src, yy_src, width, height, dest, xx_dest, yy_dest, false);
        }

        pub fn copy_rect_to_possible_overlap_native(source: Self, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32) void {
            source.copy_rect_to_internal_native(x_src, y_src, width, height, dest, x_dest, y_dest, true);
        }
        pub fn copy_rect_to_possible_overlap_with_origin(source: Self, origin: Origin, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32, width_dir: XOrder, height_dir: YOrder) void {
            const xx_src = source.get_x_with_origin_and_width(origin, x_src, width, width_dir);
            const yy_src = source.get_y_with_origin_and_height(origin, y_src, height, height_dir);
            const xx_dest = dest.get_x_with_origin_and_width(origin, x_dest, width, width_dir);
            const yy_dest = dest.get_y_with_origin_and_height(origin, y_dest, height, height_dir);
            source.copy_rect_to_internal_native(xx_src, yy_src, width, height, dest, xx_dest, yy_dest, true);
        }

        pub fn get_region_native(self: Self, x: u32, y: u32, width: u32, height: u32) Self {
            assert_with_reason(x + width <= self.width and y + height <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the bitmap width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
            const idx = self.get_idx_native(x, y);
            return Self{
                .pixels = List(Pixel){
                    .ptr = self.pixels.ptr + idx,
                    .len = self.pixels.len - idx,
                    .cap = self.pixels.cap - idx,
                },
                .width = width,
                .height = height,
                .major_stride = self.major_stride,
                .owns_memory = false,
            };
        }
        pub fn get_region_with_origin(self: Self, origin: Origin, x: u32, y: u32, width: u32, width_direction: XOrder, height: u32, height_direction: YOrder) Self {
            const xx = self.get_x_with_origin_and_width(origin, x, width, width_direction);
            const yy = self.get_y_with_origin_and_height(origin, y, height, height_direction);
            return self.get_region_native(xx, yy, width, height);
        }
        pub fn get_region_xy_native(self: Self, x1: u32, y1: u32, x2: u32, y2: u32) Self {
            const xx1 = @min(x1, x2);
            const yy1 = @min(y1, y2);
            const xx2 = @max(x1, x2);
            const yy2 = @max(y1, y2);
            const width = xx2 - xx1;
            const height = yy2 - yy1;
            return self.get_region_native(xx1, yy1, width, height);
        }
        pub fn get_region_xy_with_origin(self: Self, origin: Origin, x1: u32, y1: u32, x2: u32, y2: u32) Self {
            const xx1 = @min(x1, x2);
            const yy1 = @min(y1, y2);
            const xx2 = @max(x1, x2);
            const yy2 = @max(y1, y2);
            const width = xx2 - xx1;
            const height = yy2 - yy1;
            const xxx1 = self.get_x_with_origin(origin, x1);
            const yyy1 = self.get_y_with_origin(origin, y1);
            return self.get_region_native(xxx1, yyy1, width, height);
        }
    };
}
