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
const Vec2 = Root.Vec2;

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

const Vector = Vec2.define_vec2_type(u32);

pub const YOrder = enum(u8) {
    TOP_TO_BOTTOM,
    BOTTOM_TO_TOP,
};
pub const XOrder = enum(u8) {
    LEFT_TO_RIGHT,
    RIGHT_TO_LEFT,
};

pub const ResizeAnchor = enum(u8) {
    TOP_LEFT,
    TOP_CENTER,
    TOP_RIGHT,
    MIDDLE_LEFT,
    MIDDLE_CENTER,
    MIDDLE_RIGHT,
    BOTTOM_LEFT,
    BOTTOM_CENTER,
    BOTTOM_RIGHT,
};

pub const Origin = enum(u8) {
    TOP_LEFT,
    TOP_RIGHT,
    BOT_LEFT,
    BOT_RIGHT,
};

pub const RowColumnOrder = enum(u8) {
    ROW_MAJOR,
    COLUMN_MAJOR,
};

pub const GridDefinition = struct {
    CELL_TYPE: type = u8,
    ROW_COLUMN_ORDER: RowColumnOrder = .ROW_MAJOR,
    X_ORDER: XOrder = .LEFT_TO_RIGHT,
    Y_ORDER: YOrder = .TOP_TO_BOTTOM,

    pub fn with_cell_type(comptime self: GridDefinition, comptime T: type) GridDefinition {
        return GridDefinition{
            .CELL_TYPE = T,
            .ROW_COLUMN_ORDER = self.ROW_COLUMN_ORDER,
            .X_ORDER = self.X_ORDER,
            .Y_ORDER = self.Y_ORDER,
        };
    }
};

// pub const BitmapOpaque = struct {
//     bytes: List(u8),
//     bytes_width: u32,
//     bytes_height: u32,
//     bytes_major_stride: u32,
//     owns_memory: bool,

//     pub fn to_typed(self: BitmapOpaque, comptime DEF: GridDefinition) Bitmap(DEF) {
//         const BMP = Bitmap(DEF);
//         const new_width = self.bytes_width / @sizeOf(BMP.CELL);
//         const new_height = self.bytes_height / @sizeOf(BMP.CELL);
//         const new_stride = self.bytes_major_stride / @sizeOf(BMP.CELL);
//         const recalced_width_bytes = new_width * @sizeOf(BMP.CELL);
//         const recalced_height_bytes = new_height * @sizeOf(BMP.CELL);
//         const recalced_stride_bytes = new_stride * @sizeOf(BMP.CELL);
//         assert_with_reason(recalced_width_bytes == self.bytes_width, @src(), "cannot convert opaque DataGrid to one with pixel type `{s} x {d}`, loss of width bytes", .{ @typeName(BMP.CELL.TYPE), BMP.CELL.CHANNEL_COUNT });
//         assert_with_reason(recalced_height_bytes == self.bytes_height, @src(), "cannot convert opaque DataGrid to one with pixel type `{s} x {d}`, loss of height bytes", .{ @typeName(BMP.CELL.TYPE), BMP.CELL.CHANNEL_COUNT });
//         assert_with_reason(recalced_stride_bytes == self.bytes_major_stride, @src(), "cannot convert opaque DataGrid to one with pixel type `{s} x {d}`, loss of stride bytes", .{ @typeName(BMP.CELL.TYPE), BMP.CELL.CHANNEL_COUNT });
//         return BMP{
//             .pixels = self.bytes.cast_to_type(BMP.CELL),
//             .width = new_width,
//             .height = new_height,
//             .major_stride = new_stride,
//             .owns_memory = self.owns_memory,
//         };
//     }
// };

pub fn DataGrid(comptime DEFINITION: GridDefinition) type {
    return struct {
        const Self = @This();

        cells: CellList = .{},
        width: u32 = 0,
        height: u32 = 0,
        major_stride: u32 = 0,
        owns_memory: bool = false,

        pub const CellList = List(Cell);
        pub const Cell = DEFINITION.CELL_TYPE;
        pub const CELL_BYTE_SIZE = @sizeOf(Cell);
        pub const ROW_COLUMN_ORDER = DEFINITION.ROW_COLUMN_ORDER;
        pub const X_ORDER = DEFINITION.X_ORDER;
        pub const Y_ORDER = DEFINITION.Y_ORDER;
        pub const DEF = DEFINITION;

        pub fn init(width: u32, height: u32, fill_value: ?Cell, alloc: Allocator) Self {
            const total = width * height;
            var self = Self{
                .cells = CellList.init_capacity(total, alloc),
                .width = width,
                .height = height,
                .major_stride = if (ROW_COLUMN_ORDER == .ROW_MAJOR) width else height,
                .owns_memory = true,
            };
            if (fill_value) |fill| {
                self.fill_all(fill);
            }
            return self;
        }
        pub fn init_from_existing_cell_buffer(width: u32, height: u32, fill_value: ?Cell, buffer: CellList, alloc: Allocator) Self {
            const total = width * height;
            var self = Self{
                .cells = buffer,
                .width = width,
                .height = height,
                .major_stride = if (ROW_COLUMN_ORDER == .ROW_MAJOR) width else height,
                .owns_memory = true,
            };
            self.cells.clear();
            self.cells.ensure_free_slots(@intCast(total), alloc);
            self.cells.len = total;
            if (fill_value) |fill| {
                self.fill_all(fill);
            }
            return self;
        }
        pub fn free(self: *Self, alloc: Allocator) void {
            if (self.cells.cap != 0) {
                assert_with_reason(self.owns_memory, @src(), "cannot free: this DataGrid does not own its memory (it is a region-of or reference-to another DataGrid, or is uninitialized)", .{});
                self.cells.free(alloc);
            }
            self.width = 0;
            self.height = 0;
            self.major_stride = 0;
        }
        pub fn free_retain_buffer(self: *Self) CellList {
            assert_with_reason(self.owns_memory, @src(), "cannot free: this DataGrid does not own its memory (it is a region-of or reference-to another DataGrid, or is uninitialized)", .{});
            self.width = 0;
            self.height = 0;
            self.major_stride = 0;
            var cells = self.cells;
            self.cells = .{};
            self.owns_memory = false;
            cells.clear();
            return cells;
        }
        pub fn clear(self: *Self) void {
            assert_with_reason(self.owns_memory, @src(), "cannot clear: this DataGrid does not own its memory (it is a region-of or reference-to another DataGrid, or is uninitialized)", .{});
            self.cells.clear();
            self.width = 0;
            self.height = 0;
            self.major_stride = 0;
        }
        // pub fn to_opaque(self: Self) BitmapOpaque {
        //     return BitmapOpaque{
        //         .bytes = self.cells.cast_to_byte_list(),
        //         .bytes_height = self.height * @sizeOf(CELL),
        //         .bytes_width = self.width * @sizeOf(CELL),
        //         .bytes_major_stride = self.major_stride * @sizeOf(CELL),
        //         .owns_memory = self.owns_memory,
        //     };
        // }

        pub inline fn cell_count(self: Self) u32 {
            return self.width * self.height;
        }
        pub inline fn cells_slice(self: Self) []Cell {
            return self.cells.ptr[0..self.cell_count()];
        }

        // pub fn has_all_channels(comptime channel_tags: []const [:0]const u8) bool {
        //     inline for (channel_tags) |tag| {
        //         if (!Types.is_valid_tag_name_for_enum(CHANNELS, tag)) return false;
        //     }
        //     return true;
        // }

        pub inline fn get_x_with_origin(self: Self, origin: Origin, x: u32) u32 {
            return switch (origin) {
                .BOT_LEFT, .TOP_LEFT => if (X_ORDER == .LEFT_TO_RIGHT) x else (self.width - 1 - x),
                .BOT_RIGHT, .TOP_RIGHT => if (X_ORDER == .RIGHT_TO_LEFT) x else (self.width - 1 - x),
            };
        }
        pub inline fn get_y_with_origin(self: Self, origin: Origin, y: u32) u32 {
            return switch (origin) {
                .TOP_LEFT, .TOP_RIGHT => if (Y_ORDER == .TOP_TO_BOTTOM) y else (self.height - 1 - y),
                .BOT_LEFT, .BOT_RIGHT => if (Y_ORDER == .BOTTOM_TO_TOP) y else (self.height - 1 - y),
            };
        }
        pub inline fn get_x_delta_with_origin(origin: Origin, x_delta: i32) i32 {
            return switch (origin) {
                .BOT_LEFT, .TOP_LEFT => if (X_ORDER == .LEFT_TO_RIGHT) x_delta else -x_delta,
                .BOT_RIGHT, .TOP_RIGHT => if (X_ORDER == .RIGHT_TO_LEFT) x_delta else -x_delta,
            };
        }
        pub inline fn get_y_delta_with_origin(origin: Origin, y_delta: i32) i32 {
            return switch (origin) {
                .TOP_LEFT, .TOP_RIGHT => if (Y_ORDER == .TOP_TO_BOTTOM) y_delta else -y_delta,
                .BOT_LEFT, .BOT_RIGHT => if (Y_ORDER == .BOTTOM_TO_TOP) y_delta else -y_delta,
            };
        }
        pub inline fn get_x_with_origin_any(self: Self, origin: Origin, x: anytype) @TypeOf(x) {
            return switch (origin) {
                .BOT_LEFT, .TOP_LEFT => if (X_ORDER == .LEFT_TO_RIGHT) x else (num_cast(self.width, @TypeOf(x)) - 1 - x),
                .BOT_RIGHT, .TOP_RIGHT => if (X_ORDER == .RIGHT_TO_LEFT) x else (num_cast(self.width, @TypeOf(x)) - 1 - x),
            };
        }
        pub inline fn get_y_with_origin_any(self: Self, origin: Origin, y: anytype) @TypeOf(y) {
            return switch (origin) {
                .TOP_LEFT, .TOP_RIGHT => if (Y_ORDER == .TOP_TO_BOTTOM) y else (num_cast(self.height, @TypeOf(y)) - 1 - y),
                .BOT_LEFT, .BOT_RIGHT => if (Y_ORDER == .BOTTOM_TO_TOP) y else (num_cast(self.height, @TypeOf(y)) - 1 - y),
            };
        }
        pub inline fn get_x_with_origin_and_span_width(self: Self, origin: Origin, x: u32, width: u32, width_direction: XOrder) u32 {
            const xx = self.get_x_with_origin(origin, x);
            return switch (width_direction == X_ORDER) {
                true => xx,
                false => xx - width,
            };
        }
        pub inline fn get_y_with_origin_and_span_height(self: Self, origin: Origin, y: u32, height: u32, height_direction: XOrder) u32 {
            const yy = self.get_y_with_origin(origin, y);
            return switch (height_direction == Y_ORDER) {
                true => yy,
                false => yy - height,
            };
        }

        pub fn move_cell_ptr_many(self: Self, x_delta: i32, y_delta: i32, ptr: [*]Cell) [*]Cell {
            const idx_delta = switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => MathX.minor_major_coord_to_idx(x_delta, y_delta, num_cast(self.major_stride, i32)),
                .COLUMN_MAJOR => MathX.minor_major_coord_to_idx(y_delta, x_delta, num_cast(self.major_stride, i32)),
            };
            return switch (idx_delta < 0) {
                true => ptr - num_cast(@abs(idx_delta), usize),
                false => ptr + num_cast(idx_delta, usize),
            };
        }
        pub inline fn move_cell_ptr_many_with_origin(self: Self, origin: Origin, x_delta: i32, y_delta: i32, ptr: [*]Cell) [*]Cell {
            return self.move_cell_ptr_many(get_x_delta_with_origin(origin, x_delta), get_y_delta_with_origin(origin, y_delta), ptr);
        }
        pub fn move_cell_ptr(self: Self, x_delta: i32, y_delta: i32, ptr: *Cell) *Cell {
            return @ptrCast(self.move_cell_ptr_many(x_delta, y_delta, @ptrCast(ptr)));
        }
        pub inline fn move_cell_ptr_with_origin(self: Self, origin: Origin, x_delta: i32, y_delta: i32, ptr: *Cell) *Cell {
            return @ptrCast(self.move_cell_ptr_many_with_origin(origin, x_delta, y_delta, @ptrCast(ptr)));
        }

        pub fn get_idx(self: Self, x: u32, y: u32) u32 {
            assert_with_reason(x < self.width and y < self.height, @src(), "coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x, y, self.width, self.height });
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    return MathX.minor_major_coord_to_idx(x, y, self.major_stride);
                },
                .COLUMN_MAJOR => {
                    return MathX.minor_major_coord_to_idx(y, x, self.major_stride);
                },
            }
        }
        pub inline fn get_idx_with_origin(self: Self, origin: Origin, x: u32, y: u32) u32 {
            return self.get_idx(self.get_x_with_origin(origin, x), self.get_y_with_origin(origin, y));
        }
        pub fn get_scanline(self: Self, x: u32, y: u32, length: u32) []Cell {
            assert_with_reason(x < self.width and y < self.height, @src(), "coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x, y, self.width, self.height });
            const start = self.get_idx(x, y);
            const end = start + length;
            assert_with_reason(end <= self.width * self.height, @src(), "scanline starting from ({d}, {d}) with length {d} (end index = {d}) is outside the DataGrid length (len = {d})", .{ x, y, length, end, self.width * self.height });
            return self.cells.ptr[start..end];
        }
        pub fn get_h_scanline(self: Self, x: u32, y: u32, width: u32) []Cell {
            Assert.assert_with_reason(ROW_COLUMN_ORDER == .ROW_MAJOR, @src(), "can only use `get_h_scanline` when `ROW_COLUMN_ORDER == .ROW_MAJOR`", .{});
            return self.get_scanline(x, y, width);
        }
        pub fn get_h_scanline_with_origin(self: Self, origin: Origin, x: u32, y: u32, width_direction: XOrder, width: u32) []Cell {
            return self.get_h_scanline(self.get_x_with_origin_and_span_width(origin, x, width, width_direction), y, width);
        }
        pub fn get_v_scanline(self: Self, x: u32, y: u32, height: u32) []Cell {
            Assert.assert_with_reason(ROW_COLUMN_ORDER == .COLUMN_MAJOR, @src(), "can only use `get_v_scanline` when `ROW_COLUMN_ORDER == .COLUMN_MAJOR`", .{});
            return self.get_scanline(x, y, height);
        }
        pub fn get_v_scanline_with_origin(self: Self, origin: Origin, x: u32, y: u32, height_direction: YOrder, height: u32) []Cell {
            return self.get_v_scanline(x, self.get_y_with_origin_and_span_height(origin, y, height, height_direction), height);
        }
        pub fn get_cell(self: Self, x: u32, y: u32) Cell {
            const idx = self.get_idx(x, y);
            return self.cells.ptr[idx];
        }
        pub fn get_cell_with_origin(self: Self, origin: Origin, x: u32, y: u32) Cell {
            const idx = self.get_idx_with_origin(origin, x, y);
            return self.cells.ptr[idx];
        }
        pub fn get_cell_ptr(self: Self, x: u32, y: u32) *Cell {
            const idx = self.get_idx(x, y);
            return &self.cells.ptr[idx];
        }
        pub fn get_cell_ptr_with_origin(self: Self, origin: Origin, x: u32, y: u32) *Cell {
            const idx = self.get_idx_with_origin(origin, x, y);
            return &self.cells.ptr[idx];
        }
        pub fn get_cell_ptr_many(self: Self, x: u32, y: u32) [*]Cell {
            const idx = self.get_idx(x, y);
            return @ptrCast(&self.cells.ptr[idx]);
        }
        pub fn get_cell_ptr_many_with_origin(self: Self, origin: Origin, x: u32, y: u32) [*]Cell {
            const idx = self.get_idx_with_origin(origin, x, y);
            return @ptrCast(&self.cells.ptr[idx]);
        }
        pub fn set_cell(self: Self, x: u32, y: u32, val: Cell) void {
            const idx = self.get_idx(x, y);
            self.cells.ptr[idx] = val;
        }
        pub fn set_cell_with_origin(self: Self, origin: Origin, x: u32, y: u32, val: Cell) void {
            const idx = self.get_idx_with_origin(origin, x, y);
            self.cells.ptr[idx] = val;
        }
        pub fn lerp_sub_cell(self: Self, x: f32, y: f32, lerp_fn: *const fn (cell_a: Cell, cell_b: Cell, percent: f32) Cell) Cell {
            var xx = MathX.clamp_0_to_max(x, @as(f32, @floatFromInt(self.width)));
            var yy = MathX.clamp_0_to_max(y, @as(f32, @floatFromInt(self.height)));
            xx -= 0.5;
            yy -= 0.5;
            const left_i: i32 = @intFromFloat(@floor(xx));
            const bot_i: i32 = @intFromFloat(@floor(yy));
            const right_i: i32 = left_i + 1;
            const top_i: i32 = bot_i + 1;
            const percent_left_to_right: f32 = xx - @as(f32, @floatFromInt(left_i));
            const percent_top_to_bottom: f32 = yy - @as(f32, @floatFromInt(bot_i));
            const left: u32 = @intCast(MathX.clamp_0_to_max(left_i, self.width - 1));
            const right: u32 = @intCast(MathX.clamp_0_to_max(right_i, self.width - 1));
            const top: u32 = @intCast(MathX.clamp_0_to_max(top_i, self.height - 1));
            const bot: u32 = @intCast(MathX.clamp_0_to_max(bot_i, self.height - 1));
            const subpixel_top_lr = lerp_fn(self.get_cell(left, top), self.get_cell(right, top), percent_left_to_right);
            const subpixel_bot_lr = lerp_fn(self.get_cell(left, bot), self.get_cell(right, bot), percent_left_to_right);
            return lerp_fn(subpixel_top_lr, subpixel_bot_lr, percent_top_to_bottom);
        }
        pub fn lerp_sub_cell_with_origin(self: Self, origin: Origin, x: f32, y: f32, lerp_fn: *const fn (cell_a: Cell, cell_b: Cell, percent: f32) Cell) Cell {
            var xx = MathX.clamp_0_to_max(x, @as(f32, @floatFromInt(self.width)));
            var yy = MathX.clamp_0_to_max(y, @as(f32, @floatFromInt(self.height)));
            xx -= 0.5;
            yy -= 0.5;
            const left_i: i32 = @intFromFloat(@floor(xx));
            const bot_i: i32 = @intFromFloat(@floor(yy));
            const right_i: i32 = left_i + 1;
            const top_i: i32 = bot_i + 1;
            const percent_left_to_right: f32 = xx - @as(f32, @floatFromInt(left_i));
            const percent_top_to_bottom: f32 = yy - @as(f32, @floatFromInt(bot_i));
            const left: u32 = @intCast(MathX.clamp_0_to_max(left_i, self.width - 1));
            const right: u32 = @intCast(MathX.clamp_0_to_max(right_i, self.width - 1));
            const top: u32 = @intCast(MathX.clamp_0_to_max(top_i, self.height - 1));
            const bot: u32 = @intCast(MathX.clamp_0_to_max(bot_i, self.height - 1));
            const subpixel_top_lr = lerp_fn(self.get_cell_with_origin(origin, left, top), self.get_cell_with_origin(origin, right, top), percent_left_to_right);
            const subpixel_bot_lr = lerp_fn(self.get_cell_with_origin(origin, left, bot), self.get_cell_with_origin(origin, right, bot), percent_left_to_right);
            return lerp_fn(subpixel_top_lr, subpixel_bot_lr, percent_top_to_bottom);
        }

        pub fn discard_and_resize(self: *Self, new_width: u32, new_height: u32, fill_value: ?Cell, alloc: Allocator) void {
            if (self.cells.cap == 0) {
                self.* = init(new_width, new_height, fill_value, alloc);
                return;
            }
            assert_with_reason(self.owns_memory, @src(), "cannot resize: this DataGrid does not own its memory (it is a region-of or reference-to another DataGrid, or is uninitialized)", .{});
            if (self.width == 0 or self.height == 0) {
                if (new_width == 0 or new_height == 0) return;
                self.* = init_from_existing_cell_buffer(new_width, new_height, fill_value, self.cells, alloc);
                return;
            }
            if (new_width == 0 or new_height == 0) {
                if (self.width == 0 or self.height == 0) return;
                self.clear();
                return;
            }
            const new_len = new_width * new_height;
            self.cells.clear();
            self.cells.ensure_free_slots(@intCast(new_len), alloc);
            self.width = new_width;
            self.height = new_height;
        }

        pub fn resize(self: *Self, new_width: u32, new_height: u32, anchor: ResizeAnchor, fill_value: ?Cell, alloc: Allocator) void {
            assert_with_reason(self.owns_memory, @src(), "cannot resize: this DataGrid does not own its memory (it is a region-of or reference-to another DataGrid, or is uninitialized)", .{});
            if (self.width == 0 or self.height == 0) {
                if (new_width == 0 or new_height == 0) return;
                self.* = init_from_existing_cell_buffer(new_width, new_height, fill_value, self.cells, alloc);
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
                .TOP_LEFT, .MIDDLE_LEFT, .BOTTOM_LEFT => {
                    min_x_copy_old = 0;
                    max_x_copy_old = min_width;
                    min_x_copy_new = 0;
                    max_x_copy_new = min_width;
                },
                .TOP_CENTER, .MIDDLE_CENTER, .BOTTOM_CENTER => {
                    min_x_copy_old = half_old_width - half_min_width;
                    max_x_copy_old = min_x_copy_old + min_width;
                    min_x_copy_new = half_new_width - half_min_width;
                    max_x_copy_new = min_x_copy_new + min_width;
                },
                .TOP_RIGHT, .MIDDLE_RIGHT, .BOTTOM_RIGHT => {
                    min_x_copy_old = self.width - min_width;
                    max_x_copy_old = self.width;
                    min_x_copy_new = new_width - min_width;
                    max_x_copy_new = new_width;
                },
            }
            switch (anchor) {
                .TOP_LEFT, .TOP_CENTER, .TOP_RIGHT => {
                    min_y_copy_old = 0;
                    max_y_copy_old = min_height;
                    min_y_copy_new = 0;
                    max_y_copy_new = min_height;
                },
                .MIDDLE_LEFT, .MIDDLE_CENTER, .MIDDLE_RIGHT => {
                    min_y_copy_old = half_old_height - half_min_height;
                    max_y_copy_old = min_y_copy_old + min_height;
                    min_y_copy_new = half_new_height - half_min_height;
                    max_y_copy_new = min_y_copy_new + min_height;
                },
                .BOTTOM_LEFT, .BOTTOM_CENTER, .BOTTOM_RIGHT => {
                    min_y_copy_old = self.height - min_height;
                    max_y_copy_old = self.height;
                    min_y_copy_new = new_height - min_height;
                    max_y_copy_new = new_height;
                },
            }
            const new_grid = Self.init(new_width, new_height, alloc);
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    for (min_y_copy_old..max_y_copy_old, min_y_copy_new..max_y_copy_new) |old_y, new_y| {
                        const old_line = self.get_h_scanline(min_x_copy_old, old_y, min_width);
                        const new_line = new_grid.get_h_scanline(min_x_copy_new, new_y, min_width);
                        @memcpy(new_line, old_line);
                    }
                },
                .COLUMN_MAJOR => {
                    for (min_x_copy_old..max_x_copy_old, min_x_copy_new..max_x_copy_new) |old_x, new_x| {
                        const old_line = self.get_v_scanline(min_y_copy_old, old_x, min_height);
                        const new_line = new_grid.get_v_scanline(min_y_copy_new, new_x, min_height);
                        @memcpy(new_line, old_line);
                    }
                },
            }
            self.free(alloc);
            if (fill_value) |fill| {
                const fill_x1 = 0;
                const fill_x2 = min_x_copy_new;
                const fill_x3 = max_x_copy_new;
                const fill_x4 = new_width;
                const fill_y1 = 0;
                const fill_y2 = min_y_copy_new;
                const fill_y3 = max_y_copy_new;
                const fill_y4 = new_height;
                switch (ROW_COLUMN_ORDER) {
                    .ROW_MAJOR => {
                        new_grid.fill_rect_xy(fill_x1, fill_y1, fill_x4, fill_y2, fill);
                        new_grid.fill_rect_xy(fill_x1, fill_y2, fill_x2, fill_y3, fill);
                        new_grid.fill_rect_xy(fill_x3, fill_y2, fill_x4, fill_y3, fill);
                        new_grid.fill_rect_xy(fill_x1, fill_y3, fill_x4, fill_y4, fill);
                    },
                    .COLUMN_MAJOR => {
                        new_grid.fill_rect_xy(fill_x1, fill_y1, fill_x2, fill_y4, fill);
                        new_grid.fill_rect_xy(fill_x2, fill_y1, fill_x3, fill_y2, fill);
                        new_grid.fill_rect_xy(fill_x2, fill_y3, fill_x3, fill_y4, fill);
                        new_grid.fill_rect_xy(fill_x3, fill_y1, fill_x4, fill_y4, fill);
                    },
                }
            }
            self.* = new_grid;
        }

        fn fill_rect_internal(self: Self, x1: u32, y1: u32, x2: u32, y2: u32, width: u32, height: u32, fill_color: Cell) void {
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    if (y2 != y1) {
                        if (x1 == 0 and width == self.width) {
                            const fill_block = self.get_h_scanline(x1, y1, self.width * (height));
                            @memset(fill_block, fill_color);
                        } else {
                            for (y1..y2) |y| {
                                const fill_line = self.get_h_scanline(x1, @intCast(y), width);
                                @memset(fill_line, fill_color);
                            }
                        }
                    }
                },
                .COLUMN_MAJOR => {
                    if (x2 != x1) {
                        if (y1 == 0 and height == self.height) {
                            const fill_block = self.get_v_scanline(x1, y1, self.height * (width));
                            @memset(fill_block, fill_color);
                        } else {
                            for (x1..x2) |x| {
                                const fill_line = self.get_v_scanline(@intCast(x), y1, height);
                                @memset(fill_line, fill_color);
                            }
                        }
                    }
                },
            }
        }

        pub fn fill_all(self: Self, fill_color: Cell) void {
            self.fill_rect(0, 0, self.width, self.height, fill_color);
        }
        pub fn fill_rect(self: Self, x: u32, y: u32, width: u32, height: u32, fill_color: Cell) void {
            assert_with_reason(x + width <= self.width and y + height <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
            const x2 = x + width;
            const y2 = y + height;
            self.fill_rect_internal(x, y, x2, y2, width, height, fill_color);
        }
        pub fn fill_rect_with_origin(self: Self, origin: Origin, x: u32, y: u32, width: u32, height: u32, width_dir: XOrder, height_dir: YOrder, fill_color: Cell) void {
            const x1 = self.get_x_with_origin_and_span_width(origin, x, width, width_dir);
            const y1 = self.get_y_with_origin_and_span_height(origin, y, height, height_dir);
            assert_with_reason(x1 + width <= self.width and y1 + height <= self.height, @src(), "max extent coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x1 + width, y1 + height, self.width, self.height });
            const x2 = x + width;
            const y2 = y + height;
            self.fill_rect_internal(x1, y1, x2, y2, width, height, fill_color);
        }
        pub fn fill_rect_xy(self: Self, x1: u32, y1: u32, x2: u32, y2: u32, fill_color: Cell) void {
            assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
            assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
            assert_with_reason(x2 <= self.width and y2 <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x2, y2, self.width, self.height });
            const width = x2 - x1;
            const height = y2 - y1;
            self.fill_rect_internal(x1, y1, x2, y2, width, height, fill_color);
        }
        pub fn fill_rect_xy_with_origin(self: Self, origin: Origin, x1: u32, y1: u32, x2: u32, y2: u32, fill_color: Cell) void {
            assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
            assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
            const width = x2 - x1;
            const height = y2 - y1;
            const xx1 = self.get_x_with_origin(origin, x1);
            const xx2 = self.get_x_with_origin(origin, x2);
            const yy1 = self.get_y_with_origin(origin, y1);
            const yy2 = self.get_y_with_origin(origin, y2);
            assert_with_reason(xx2 <= self.width and yy2 <= self.height, @src(), "max extent coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ xx2, yy2, self.width, self.height });
            self.fill_rect_internal(xx1, yy1, xx2, yy2, width, height, fill_color);
        }

        fn copy_rect_to_internal(source: Self, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32, comptime overlap: bool) void {
            assert_with_reason(x_src + width <= source.width and y_src + height <= source.height, @src(), "bottom-right source coordinate ({d}, {d}) is outside the source DataGrid width/height ({d}, {d})", .{ x_src + width, y_src + height, source.width, source.height });
            assert_with_reason(x_dest + width <= dest.width and y_dest + height <= dest.height, @src(), "bottom-right destination coordinate ({d}, {d}) is outside the destination DataGrid width/height ({d}, {d})", .{ x_dest + width, y_dest + height, dest.width, dest.height });
            const y_src_2 = y_src + height;
            const x_src_2 = x_src + width;
            const y_dest_2 = y_dest + height;
            const x_dest_2 = x_dest + width;
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
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
                .COLUMN_MAJOR => {
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
        pub fn copy_rect_to_with_origin(source: Self, origin: Origin, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32, width_dir: XOrder, height_dir: YOrder) void {
            const xx_src = source.get_x_with_origin_and_span_width(origin, x_src, width, width_dir);
            const yy_src = source.get_y_with_origin_and_span_height(origin, y_src, height, height_dir);
            const xx_dest = dest.get_x_with_origin_and_span_width(origin, x_dest, width, width_dir);
            const yy_dest = dest.get_y_with_origin_and_span_height(origin, y_dest, height, height_dir);
            source.copy_rect_to_internal(xx_src, yy_src, width, height, dest, xx_dest, yy_dest, false);
        }

        pub fn copy_rect_to_possible_overlap(source: Self, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32) void {
            source.copy_rect_to_internal(x_src, y_src, width, height, dest, x_dest, y_dest, true);
        }
        pub fn copy_rect_to_possible_overlap_with_origin(source: Self, origin: Origin, x_src: u32, y_src: u32, width: u32, height: u32, dest: Self, x_dest: u32, y_dest: u32, width_dir: XOrder, height_dir: YOrder) void {
            const xx_src = source.get_x_with_origin_and_span_width(origin, x_src, width, width_dir);
            const yy_src = source.get_y_with_origin_and_span_height(origin, y_src, height, height_dir);
            const xx_dest = dest.get_x_with_origin_and_span_width(origin, x_dest, width, width_dir);
            const yy_dest = dest.get_y_with_origin_and_span_height(origin, y_dest, height, height_dir);
            source.copy_rect_to_internal(xx_src, yy_src, width, height, dest, xx_dest, yy_dest, true);
        }

        pub fn get_region(self: Self, x: u32, y: u32, width: u32, height: u32) Self {
            assert_with_reason(x + width <= self.width and y + height <= self.height, @src(), "bottom-right coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x + width, y + height, self.width, self.height });
            const idx = self.get_idx(x, y);
            return Self{
                .cells = CellList{
                    .ptr = self.cells.ptr + idx,
                    .len = self.cells.len - idx,
                    .cap = self.cells.cap - idx,
                },
                .width = width,
                .height = height,
                .major_stride = self.major_stride,
                .owns_memory = false,
            };
        }
        pub fn get_region_with_origin(self: Self, origin: Origin, x: u32, y: u32, width: u32, width_direction: XOrder, height: u32, height_direction: YOrder) Self {
            const xx = self.get_x_with_origin_and_span_width(origin, x, width, width_direction);
            const yy = self.get_y_with_origin_and_span_height(origin, y, height, height_direction);
            return self.get_region(xx, yy, width, height);
        }
        pub fn get_region_xy(self: Self, x1: u32, y1: u32, x2: u32, y2: u32) Self {
            const xx1 = @min(x1, x2);
            const yy1 = @min(y1, y2);
            const xx2 = @max(x1, x2);
            const yy2 = @max(y1, y2);
            const width = xx2 - xx1;
            const height = yy2 - yy1;
            return self.get_region(xx1, yy1, width, height);
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
            return self.get_region(xxx1, yyy1, width, height);
        }

        pub const SourceKind = enum(u8) {
            EXISTING,
            ALLOCATE_NEW,
            REUSE_CELL_BUFFER,
            PROVIDER_FUNC,
        };

        pub const DataGridWithParentOffset = struct {
            data_grid: Self = .{},
            parent_offset: Vector = .ZERO_ZERO,

            pub fn new_no_parent(grid: Self) DataGridWithParentOffset {
                return DataGridWithParentOffset{
                    .data_grid = grid,
                };
            }
            pub fn new_with_parent(grid: Self, parent_offset: Vector) DataGridWithParentOffset {
                return DataGridWithParentOffset{
                    .data_grid = grid,
                    .parent_offset = parent_offset,
                };
            }
        };

        pub const Source = union(SourceKind) {
            EXISTING: struct {
                grid_with_offset: DataGridWithParentOffset,
                fill: ?DEF.CELL_TYPE,
            },
            ALLOCATE_NEW: struct {
                alloc: Allocator,
                fill: ?DEF.CELL_TYPE,
            },
            REUSE_CELL_BUFFER: struct {
                cells: CellList,
                alloc: Allocator,
                fill: ?DEF.CELL_TYPE,
            },
            PROVIDER_FUNC: struct {
                func: *const fn (width: u32, height: u32, fill: ?DEF.CELL_TYPE) ?DataGridWithParentOffset,
                fill: ?DEF.CELL_TYPE,
            },

            pub fn existing_data_grid(grid_with_offset: DataGridWithParentOffset, fill: ?DEF.CELL_TYPE) Source {
                return Source{ .EXISTING = .{ .grid_with_offset = grid_with_offset, .fill = fill } };
            }
            pub fn allocate_new_data_grid(alloc: Allocator, fill: ?DEF.CELL_TYPE) Source {
                return Source{ .ALLOCATE_NEW = .{ .alloc = alloc, .fill = fill } };
            }
            pub fn reuse_cell_buffer(cells: CellList, alloc: Allocator, fill: ?DEF.CELL_TYPE) Source {
                return Source{ .REUSE_CELL_BUFFER = .{ .cells = cells, .alloc = alloc, .fill = fill } };
            }
            pub fn data_grid_provider(func: *const fn (width: u32, height: u32, fill: ?DEF.CELL_TYPE) ?DataGridWithParentOffset, fill: ?DEF.CELL_TYPE) Source {
                return Source{ .PROVIDER_FUNC = .{ .func = func, .fill = fill } };
            }

            pub fn obtain_grid(self: Source, width: u32, height: u32) ?DataGridWithParentOffset {
                return switch (self) {
                    .EXISTING => |src| after_fill: {
                        if (src.fill) |fill| src.grid_with_offset.data_grid.fill_all(fill);
                        break :after_fill src.grid_with_offset;
                    },
                    .ALLOCATE_NEW => |src| DataGridWithParentOffset.new_no_parent(Self.init(width, height, src.fill, src.alloc)),
                    .REUSE_CELL_BUFFER => |src| DataGridWithParentOffset.new_no_parent(Self.init_from_existing_cell_buffer(width, height, src.fill, src.cells, src.alloc)),
                    .PROVIDER_FUNC => |src| src.func(width, height, src.fill),
                };
            }
        };
    };
}
