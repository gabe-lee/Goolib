//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
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
// const SliceAdapter = Root.IList_SliceAdapter;
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Flags = Root.Flags;
// const IList = Root.IList.IList;
// const List = Root.IList_List.List;
// const Range = Root.IList.Range;
const ListAllocated = Root.ListSlice.ListAllocated;
const Color_ = Root.Color;
const MathX = Root.Math;
const Vec2 = Root.Vec2;

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

const DEBUG = std.debug.print;
const DEBUG_VAL = Utils.DebugPrint.debug_val;

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

pub const Ownership = enum(u8) {
    ROOT,
    REGION,
};

pub const RowColumnOrder = Root.CommonTypes.RowColumnOrder;

pub const GridDefinitionNoElem = struct {
    LIST_DEF: Root.ListSlice.ListDefNoElem,
    ROW_COLUMN_ORDER: RowColumnOrder = .ROW_MAJOR,
    X_ORDER: XOrder = .LEFT_TO_RIGHT,
    Y_ORDER: YOrder = .TOP_TO_BOTTOM,
    OWNERSHIP: Ownership = .ROOT,

    pub fn Grid(comptime self: GridDefinitionNoElem, comptime CELL: type) type {
        return DataGrid(self.with_cell_type(CELL));
    }

    pub fn with_cell_type(comptime self: GridDefinitionNoElem, comptime CELL: type) GridDefinition {
        return GridDefinition{
            .LIST_DEF = self.LIST_DEF.with_type(CELL),
            .ROW_COLUMN_ORDER = self.ROW_COLUMN_ORDER,
            .X_ORDER = self.X_ORDER,
            .Y_ORDER = self.Y_ORDER,
        };
    }
    pub fn with_ownership(comptime self: GridDefinitionNoElem, comptime OWNERSHIP: Root.ListSlice.Ownership) GridDefinitionNoElem {
        return GridDefinitionNoElem{
            .LIST_DEF = self.LIST_DEF.with_ownership(OWNERSHIP),
            .ROW_COLUMN_ORDER = self.ROW_COLUMN_ORDER,
            .X_ORDER = self.X_ORDER,
            .Y_ORDER = self.Y_ORDER,
        };
    }
};

pub const GridDefinitionNoList = struct {
    ROW_COLUMN_ORDER: RowColumnOrder = .ROW_MAJOR,
    X_ORDER: XOrder = .LEFT_TO_RIGHT,
    Y_ORDER: YOrder = .TOP_TO_BOTTOM,
    OWNERSHIP: Ownership = .ROOT,

    pub fn Grid(comptime self: GridDefinitionNoList, comptime LIST: Root.ListSlice.ListDef) type {
        return DataGrid(self.with_list_def(LIST));
    }

    pub fn with_list_def(comptime self: GridDefinitionNoList, comptime LIST: Root.ListSlice.ListDef) GridDefinition {
        return GridDefinition{
            .LIST_DEF = LIST,
            .ROW_COLUMN_ORDER = self.ROW_COLUMN_ORDER,
            .X_ORDER = self.X_ORDER,
            .Y_ORDER = self.Y_ORDER,
        };
    }
};

pub const GridDefinition = struct {
    LIST_DEF: Root.ListSlice.ListDef,
    ROW_COLUMN_ORDER: RowColumnOrder = .ROW_MAJOR,
    X_ORDER: XOrder = .LEFT_TO_RIGHT,
    Y_ORDER: YOrder = .TOP_TO_BOTTOM,
    OWNERSHIP: Ownership = .ROOT,

    pub fn Grid(comptime self: GridDefinition) type {
        return DataGrid(self);
    }

    pub fn with_cell_type(comptime self: GridDefinition, comptime T: type) GridDefinition {
        return GridDefinition{
            .LIST_DEF = self.LIST_DEF.with_type(T),
            .ROW_COLUMN_ORDER = self.ROW_COLUMN_ORDER,
            .X_ORDER = self.X_ORDER,
            .Y_ORDER = self.Y_ORDER,
            .OWNERSHIP = self.OWNERSHIP,
        };
    }
    pub fn with_list_ownership(comptime self: GridDefinition, comptime OWNERSHIP: Root.ListSlice.Ownership) GridDefinition {
        return GridDefinition{
            .LIST_DEF = self.LIST_DEF.with_ownership(OWNERSHIP),
            .ROW_COLUMN_ORDER = self.ROW_COLUMN_ORDER,
            .X_ORDER = self.X_ORDER,
            .Y_ORDER = self.Y_ORDER,
            .OWNERSHIP = self.OWNERSHIP,
        };
    }
    pub fn with_ownership(comptime self: GridDefinition, comptime OWNERSHIP: Ownership) GridDefinition {
        return GridDefinition{
            .LIST_DEF = self.LIST_DEF,
            .ROW_COLUMN_ORDER = self.ROW_COLUMN_ORDER,
            .X_ORDER = self.X_ORDER,
            .Y_ORDER = self.Y_ORDER,
            .OWNERSHIP = OWNERSHIP,
        };
    }
};

pub fn DataGrid(comptime DEFINITION: GridDefinition) type {
    return struct {
        const Self = @This();

        cells: CellList = .{},
        root_size: IVec = .ZERO,
        offset: if (IS_REGION) IVec else void = if (IS_REGION) .ZERO else {},
        size: if (IS_REGION) IVec else void = if (IS_REGION) .ZERO else {},

        pub const CellList = DEFINITION.LIST_DEF.List();
        pub const Cell = DEFINITION.LIST_DEF.ELEM;
        pub const CellPtr = CellList.ElemPtr;
        pub const CellPtrConst = CellList.ElemPtrConst;
        pub const CellPtrMany = CellList.ElemPtrMany;
        pub const CellPtrManyConst = CellList.ElemPtrManyConst;
        pub const Idx = DEFINITION.LIST_DEF.IDX;
        pub const IVec = Vec2.define_vec2_type(Idx);
        pub const CELL_BYTE_SIZE = @sizeOf(Cell);
        pub const ROW_COLUMN_ORDER = DEFINITION.ROW_COLUMN_ORDER;
        pub const X_ORDER = DEFINITION.X_ORDER;
        pub const Y_ORDER = DEFINITION.Y_ORDER;
        pub const DEF = DEFINITION;
        pub const IS_ROOT = DEF.OWNERSHIP == .ROOT;
        pub const IS_REGION = DEF.OWNERSHIP == .REGION;

        const GridAllocRoot = DEFINITION.with_ownership(.ROOT).with_list_ownership(.OWNED_ALLOCATED).Grid();
        const GridRoot = DEFINITION.with_ownership(.ROOT).Grid();
        const GridRegion = DEFINITION.with_ownership(.REGION).Grid();

        pub fn allocate_new(root_size: IVec, fill_value: ?Cell, alloc: Allocator) GridAllocRoot {
            const total = root_size.x * root_size.y;
            var self = GridAllocRoot{
                .cells = CellList.allocate_new_set_len(total, alloc),
                .root_size = root_size,
            };
            if (fill_value) |fill| {
                self.fill_all(fill);
            }
            return self;
        }
        pub fn init_repurpose_existing_cell_list(root_size: IVec, fill_value: ?Cell, list: CellList, alloc: Allocator) GridRoot {
            const total = root_size.x * root_size.y;
            var self = Self{
                .cells = list,
                .root_size = root_size,
            };
            self.cells.clear();
            self.cells.grow_capacity_if_needed(@intCast(total), .GROW_EXACT_NEEDED, alloc);
            self.cells.set_len_unchecked(total);
            if (fill_value) |fill| {
                self.fill_all(fill);
            }
            return self;
        }
        pub fn free(self: *Self, alloc: Allocator) void {
            self.cells.free(alloc);
            self.* = .{};
        }
        pub fn free_if_non_zero(self: *Self, alloc: Allocator) void {
            self.cells.free_if_non_zero(alloc);
            self.* = .{};
        }
        pub fn clear(self: *Self) void {
            assert_root(@src());
            self.cells.clear();
            self.root_size = .ZERO;
        }
        fn assert_root(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(IS_ROOT, src, "grid is not the root grid (it is a region)", .{});
        }
        fn assert_region(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(IS_REGION, src, "grid is not a region (it is the root grid)", .{});
        }

        pub inline fn get_offset(self: Self) Vec {
            switch (comptime DEF.OWNERSHIP) {
                .ROOT => {
                    return .ZERO;
                },
                .REGION => {
                    return self.offset;
                },
            }
        }
        pub inline fn get_size(self: Self) Vec {
            switch (comptime DEF.OWNERSHIP) {
                .ROOT => {
                    return self.root_size;
                },
                .REGION => {
                    return self.size;
                },
            }
        }
        pub inline fn get_width(self: Self) Idx {
            switch (comptime DEF.OWNERSHIP) {
                .ROOT => {
                    return self.root_size.x;
                },
                .REGION => {
                    return self.size.x;
                },
            }
        }
        pub inline fn get_height(self: Self) Idx {
            switch (comptime DEF.OWNERSHIP) {
                .ROOT => {
                    return self.root_size.y;
                },
                .REGION => {
                    return self.size.y;
                },
            }
        }

        pub inline fn root_cell_count(self: Self) Idx {
            return self.root_size.x * self.root_size.y;
        }
        pub inline fn cell_count(self: Self) Idx {
            return self.get_width() * self.get_height();
        }
        pub inline fn root_cells_slice(self: Self) CellList.Slice {
            return self.cells.slice(0, self.root_cell_count());
        }
        pub inline fn root_cells_slice_const(self: Self) CellList.SliceConst {
            return self.cells.slice_const(0, self.root_cell_count());
        }

        pub inline fn get_x_with_origin(self: Self, origin: Origin, x: Idx) Idx {
            return switch (origin) {
                .BOT_LEFT, .TOP_LEFT => if (X_ORDER == .LEFT_TO_RIGHT) x else (self.get_size().x - 1 - x),
                .BOT_RIGHT, .TOP_RIGHT => if (X_ORDER == .RIGHT_TO_LEFT) x else (self.get_size().x - 1 - x),
            };
        }
        pub inline fn get_y_with_origin(self: Self, origin: Origin, y: Idx) Idx {
            return switch (origin) {
                .TOP_LEFT, .TOP_RIGHT => if (Y_ORDER == .TOP_TO_BOTTOM) y else (self.get_size().y - 1 - y),
                .BOT_LEFT, .BOT_RIGHT => if (Y_ORDER == .BOTTOM_TO_TOP) y else (self.get_size().y - 1 - y),
            };
        }
        pub inline fn get_x_delta_with_origin(origin: Origin, x_delta: isize) isize {
            return switch (origin) {
                .BOT_LEFT, .TOP_LEFT => if (X_ORDER == .LEFT_TO_RIGHT) x_delta else -x_delta,
                .BOT_RIGHT, .TOP_RIGHT => if (X_ORDER == .RIGHT_TO_LEFT) x_delta else -x_delta,
            };
        }
        pub inline fn get_y_delta_with_origin(origin: Origin, y_delta: isize) isize {
            return switch (origin) {
                .TOP_LEFT, .TOP_RIGHT => if (Y_ORDER == .TOP_TO_BOTTOM) y_delta else -y_delta,
                .BOT_LEFT, .BOT_RIGHT => if (Y_ORDER == .BOTTOM_TO_TOP) y_delta else -y_delta,
            };
        }
        pub inline fn get_x_with_origin_any(self: Self, origin: Origin, x: anytype) @TypeOf(x) {
            return switch (origin) {
                .BOT_LEFT, .TOP_LEFT => if (X_ORDER == .LEFT_TO_RIGHT) x else (num_cast(self.get_size().x, @TypeOf(x)) - 1 - x),
                .BOT_RIGHT, .TOP_RIGHT => if (X_ORDER == .RIGHT_TO_LEFT) x else (num_cast(self.get_size().x, @TypeOf(x)) - 1 - x),
            };
        }
        pub inline fn get_y_with_origin_any(self: Self, origin: Origin, y: anytype) @TypeOf(y) {
            return switch (origin) {
                .TOP_LEFT, .TOP_RIGHT => if (Y_ORDER == .TOP_TO_BOTTOM) y else (num_cast(self.get_size().y, @TypeOf(y)) - 1 - y),
                .BOT_LEFT, .BOT_RIGHT => if (Y_ORDER == .BOTTOM_TO_TOP) y else (num_cast(self.get_size().y, @TypeOf(y)) - 1 - y),
            };
        }
        pub inline fn get_x_with_origin_and_span_width(self: Self, origin: Origin, x: Idx, width: Idx, width_direction: XOrder) Idx {
            const xx = self.get_x_with_origin(origin, x);
            return if (width_direction == X_ORDER) xx else xx - width;
        }
        pub inline fn get_y_with_origin_and_span_height(self: Self, origin: Origin, y: Idx, height: Idx, height_direction: YOrder) Idx {
            const yy = self.get_y_with_origin(origin, y);
            return if (height_direction == Y_ORDER) yy else yy - height;
        }

        pub fn move_cell_ptr_many(self: Self, x_delta: isize, y_delta: isize, ptr: CellPtrMany) CellPtrMany {
            const idx_delta = switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => MathX.minor_major_coord_to_idx(x_delta, y_delta, num_cast(self.root_size.x, isize)),
                .COLUMN_MAJOR => MathX.minor_major_coord_to_idx(y_delta, x_delta, num_cast(self.root_size.y, isize)),
            };
            return CellList.move_many_item_pointer(ptr, idx_delta);
        }
        pub inline fn move_cell_ptr_many_with_origin(self: Self, origin: Origin, x_delta: isize, y_delta: isize, ptr: CellPtrMany) CellPtrMany {
            return self.move_cell_ptr_many(get_x_delta_with_origin(origin, x_delta), get_y_delta_with_origin(origin, y_delta), ptr);
        }
        pub inline fn move_cell_ptr(self: Self, x_delta: isize, y_delta: isize, ptr: CellPtr) CellPtr {
            return CellList.cast_many_item_ptr_to_ptr(self.move_cell_ptr_many(x_delta, y_delta, CellList.cast_ptr_to_many_item_ptr(ptr)));
        }
        pub inline fn move_cell_ptr_with_origin(self: Self, origin: Origin, x_delta: isize, y_delta: isize, ptr: CellPtr) CellPtr {
            return CellList.cast_many_item_ptr_to_ptr(self.move_cell_ptr_many_with_origin(origin, x_delta, y_delta, CellList.cast_ptr_to_many_item_ptr(ptr)));
        }

        pub fn get_idx_unchecked(self: Self, x: Idx, y: Idx) Idx {
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    return MathX.minor_major_coord_to_idx(x + self.get_offset().x, y + self.get_offset().y, self.root_size.x);
                },
                .COLUMN_MAJOR => {
                    return MathX.minor_major_coord_to_idx(y + self.get_offset().y, x + self.get_offset().x, self.root_size.y);
                },
            }
        }
        pub fn get_idx(self: Self, x: Idx, y: Idx) Idx {
            assert_with_reason(x < self.get_size().x and y < self.get_size().y, @src(), "coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x, y, self.get_size().x, self.get_size().y });
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    return MathX.minor_major_coord_to_idx(x + self.get_offset().x, y + self.get_offset().y, self.root_size.x);
                },
                .COLUMN_MAJOR => {
                    return MathX.minor_major_coord_to_idx(y + self.get_offset().y, x + self.get_offset().x, self.root_size.y);
                },
            }
        }
        pub fn get_idx_at_end_of_region(self: Self, x: Idx, y: Idx, width: Idx, height: Idx) Idx {
            assert_with_reason(x < self.get_size().x and y < self.get_size().y, @src(), "coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x, y, self.get_size().x, self.get_size().y });
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    return MathX.minor_major_coord_to_idx(x + self.get_offset().x, y + self.get_offset().y, self.root_size.x) + ((height - 1) * self.root_size.x) + (width);
                },
                .COLUMN_MAJOR => {
                    return MathX.minor_major_coord_to_idx(y + self.get_offset().y, x + self.get_offset().x, self.root_size.y) + ((width - 1) * self.root_size.y) + (height);
                },
            }
        }
        pub fn get_idx_at_end_of_region_known_start_idx(self: Self, idx: Idx, width: Idx, height: Idx) Idx {
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    return idx + ((height - 1) * self.root_size.x) + (width);
                },
                .COLUMN_MAJOR => {
                    return idx + ((width - 1) * self.root_size.y) + (height);
                },
            }
        }
        pub inline fn get_idx_with_origin(self: Self, origin: Origin, x: Idx, y: Idx) Idx {
            return self.get_idx(self.get_x_with_origin(origin, x), self.get_y_with_origin(origin, y));
        }
        pub fn get_scanline(self: Self, x: Idx, y: Idx, length: Idx) CellList.Slice {
            assert_with_reason(x < self.get_size().x and y < self.get_size().y, @src(), "coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x, y, self.get_size().x, self.get_size().y });
            const start = self.get_idx(x, y);
            const end = start + length;
            assert_with_reason(end <= self.root_size.x * self.root_size.y, @src(), "scanline starting from ({d}, {d}) with length {d} (end index = {d}) is outside the DataGrid length (len = {d})", .{ x, y, length, end, self.root_size.x * self.root_size.y });
            return self.cells.slice(start, end);
        }
        pub fn get_h_scanline(self: Self, x: Idx, y: Idx, width: Idx) CellList.Slice {
            Assert.assert_with_reason(ROW_COLUMN_ORDER == .ROW_MAJOR, @src(), "can only use `get_h_scanline` when `ROW_COLUMN_ORDER == .ROW_MAJOR`", .{});
            return self.get_scanline(x, y, width);
        }
        pub fn get_h_scanline_with_origin(self: Self, origin: Origin, x: Idx, y: Idx, width_direction: XOrder, width: Idx) CellList.Slice {
            return self.get_h_scanline(self.get_x_with_origin_and_span_width(origin, x, width, width_direction), y, width);
        }
        pub fn get_v_scanline(self: Self, x: Idx, y: Idx, height: Idx) CellList.Slice {
            Assert.assert_with_reason(ROW_COLUMN_ORDER == .COLUMN_MAJOR, @src(), "can only use `get_v_scanline` when `ROW_COLUMN_ORDER == .COLUMN_MAJOR`", .{});
            return self.get_scanline(x, y, height);
        }
        pub fn get_v_scanline_with_origin(self: Self, origin: Origin, x: Idx, y: Idx, height_direction: YOrder, height: Idx) CellList.Slice {
            return self.get_v_scanline(x, self.get_y_with_origin_and_span_height(origin, y, height, height_direction), height);
        }
        pub fn get_cell(self: Self, x: Idx, y: Idx) Cell {
            const idx = self.get_idx(x, y);
            return self.cells.get(idx);
        }
        pub fn get_cell_with_origin(self: Self, origin: Origin, x: Idx, y: Idx) Cell {
            const idx = self.get_idx_with_origin(origin, x, y);
            return self.cells.get(idx);
        }
        pub fn get_cell_ptr(self: Self, x: Idx, y: Idx) CellPtr {
            const idx = self.get_idx(x, y);
            return self.cells.get_ptr(idx);
        }
        pub fn get_cell_ptr_with_origin(self: Self, origin: Origin, x: Idx, y: Idx) CellPtr {
            const idx = self.get_idx_with_origin(origin, x, y);
            return self.cells.get_ptr(idx);
        }
        pub fn get_cell_ptr_many(self: Self, x: Idx, y: Idx) CellPtrMany {
            const idx = self.get_idx(x, y);
            return self.cells.get_many_item_ptr(idx);
        }
        pub fn get_cell_ptr_many_with_origin(self: Self, origin: Origin, x: Idx, y: Idx) CellPtrMany {
            const idx = self.get_idx_with_origin(origin, x, y);
            return self.cells.get_many_item_ptr(idx);
        }
        pub fn set_cell(self: Self, x: Idx, y: Idx, val: Cell) void {
            const idx = self.get_idx(x, y);
            self.cells.set(idx, val);
        }
        pub fn set_cell_with_origin(self: Self, origin: Origin, x: Idx, y: Idx, val: Cell) void {
            const idx = self.get_idx_with_origin(origin, x, y);
            self.cells.set(idx, val);
        }
        fn lerp_implicit(cell_a: Cell, cell_b: Cell, percent: f32) Cell {
            return cell_a + num_cast(num_cast(cell_b - cell_a, f32) * percent, Cell);
        }
        fn lerp_named_lerp_f32(cell_a: Cell, cell_b: Cell, percent: f32) Cell {
            return cell_a.lerp_f32(cell_b, percent);
        }
        fn lerp_named_lerp(cell_a: Cell, cell_b: Cell, percent: f32) Cell {
            return cell_a.lerp(cell_b, percent);
        }
        pub fn lerp_sub_cell_implicit(self: Self, x: f32, y: f32) Cell {
            return self.lerp_sub_cell(x, y, lerp_implicit);
        }
        pub fn lerp_sub_cell_with_origin_implicit(self: Self, origin: Origin, x: f32, y: f32) Cell {
            return self.lerp_sub_cell_with_origin(origin, x, y, lerp_implicit);
        }
        pub fn lerp_sub_cell_fn_on_cell(self: Self, x: f32, y: f32) Cell {
            return self.lerp_sub_cell(x, y, lerp_named_lerp);
        }
        pub fn lerp_sub_cell_with_origin_fn_on_cell(self: Self, origin: Origin, x: f32, y: f32) Cell {
            return self.lerp_sub_cell_with_origin(origin, x, y, lerp_named_lerp);
        }
        pub fn lerp_sub_cell_fn_on_cell_f32(self: Self, x: f32, y: f32) Cell {
            return self.lerp_sub_cell(x, y, lerp_named_lerp_f32);
        }
        pub fn lerp_sub_cell_with_origin_fn_on_cell_f32(self: Self, origin: Origin, x: f32, y: f32) Cell {
            return self.lerp_sub_cell_with_origin(origin, x, y, lerp_named_lerp_f32);
        }
        pub fn lerp_sub_cell(self: Self, x: f32, y: f32, lerp_fn: *const fn (cell_a: Cell, cell_b: Cell, percent: f32) Cell) Cell {
            var xx = MathX.clamp_0_to_max(x, @as(f32, @floatFromInt(self.root_size.x)));
            var yy = MathX.clamp_0_to_max(y, @as(f32, @floatFromInt(self.root_size.y)));
            xx -= 0.5;
            yy -= 0.5;
            const left_i: isize = @intFromFloat(@floor(xx));
            const bot_i: isize = @intFromFloat(@floor(yy));
            const right_i: isize = left_i + 1;
            const top_i: isize = bot_i + 1;
            const percent_left_to_right: f32 = xx - @as(f32, @floatFromInt(left_i));
            const percent_top_to_bottom: f32 = yy - @as(f32, @floatFromInt(bot_i));
            const left: Idx = @intCast(MathX.clamp_0_to_max(left_i, self.root_size.x - 1));
            const right: Idx = @intCast(MathX.clamp_0_to_max(right_i, self.root_size.x - 1));
            const top: Idx = @intCast(MathX.clamp_0_to_max(top_i, self.root_size.y - 1));
            const bot: Idx = @intCast(MathX.clamp_0_to_max(bot_i, self.root_size.y - 1));
            const subcell_top_lr = lerp_fn(self.get_cell(left, top), self.get_cell(right, top), percent_left_to_right);
            const subcell_bot_lr = lerp_fn(self.get_cell(left, bot), self.get_cell(right, bot), percent_left_to_right);
            return lerp_fn(subcell_top_lr, subcell_bot_lr, percent_top_to_bottom);
        }
        pub fn lerp_sub_cell_with_origin(self: Self, origin: Origin, x: f32, y: f32, lerp_fn: *const fn (cell_a: Cell, cell_b: Cell, percent: f32) Cell) Cell {
            var xx = MathX.clamp_0_to_max(x, @as(f32, @floatFromInt(self.root_size.x)));
            var yy = MathX.clamp_0_to_max(y, @as(f32, @floatFromInt(self.root_size.y)));
            xx -= 0.5;
            yy -= 0.5;
            const left_i: isize = @intFromFloat(@floor(xx));
            const bot_i: isize = @intFromFloat(@floor(yy));
            const right_i: isize = left_i + 1;
            const top_i: isize = bot_i + 1;
            const percent_left_to_right: f32 = xx - @as(f32, @floatFromInt(left_i));
            const percent_top_to_bottom: f32 = yy - @as(f32, @floatFromInt(bot_i));
            const left: Idx = @intCast(MathX.clamp_0_to_max(left_i, self.root_size.x - 1));
            const right: Idx = @intCast(MathX.clamp_0_to_max(right_i, self.root_size.x - 1));
            const top: Idx = @intCast(MathX.clamp_0_to_max(top_i, self.root_size.y - 1));
            const bot: Idx = @intCast(MathX.clamp_0_to_max(bot_i, self.root_size.y - 1));
            const subcell_top_lr = lerp_fn(self.get_cell_with_origin(origin, left, top), self.get_cell_with_origin(origin, right, top), percent_left_to_right);
            const subcell_bot_lr = lerp_fn(self.get_cell_with_origin(origin, left, bot), self.get_cell_with_origin(origin, right, bot), percent_left_to_right);
            return lerp_fn(subcell_top_lr, subcell_bot_lr, percent_top_to_bottom);
        }

        pub inline fn discard_and_realloc(self: *Self, new_root_width: Idx, new_root_height: Idx, fill_value: ?Cell, alloc: Allocator) void {
            self.discard_and_realloc_with_growth(new_root_width, new_root_height, fill_value, .GROW_BY_25_PERCENT, alloc);
        }
        pub fn discard_and_realloc_with_growth(self: *Self, new_root_width: Idx, new_root_height: Idx, fill_value: ?Cell, growth: Root.CommonTypes.GrowthModel, alloc: Allocator) void {
            assert_root(@src());
            self.cells.clear();
            if (new_root_width > 0 and new_root_height > 0) {
                const new_total = new_root_width * new_root_height;
                self.cells.grow_capacity_if_needed(new_total, growth, alloc);
                self.cells.set_len_unchecked(new_total);
                if (fill_value) |val| {
                    self.cells.memset_len(val);
                }
            }
            self.root_size.x = new_root_width;
            self.root_size.y = new_root_height;
        }

        pub fn realloc(self: *Self, new_root_width: Idx, new_root_height: Idx, anchor: ResizeAnchor, fill_value: ?Cell, alloc: Allocator) void {
            assert_root(@src());
            if (new_root_width == 0 or new_root_height == 0) {
                self.clear();
                self.root_size = .ZERO;
                return;
            }
            if (self.root_size.x == 0 or self.root_size.y == 0) {
                self.discard_and_realloc_with_growth(new_root_width, new_root_height, fill_value, .GROW_EXACT_NEEDED, alloc);
                return;
            }
            const half_old_width = self.root_size.x >> 1;
            const half_old_height = self.root_size.y >> 1;
            const half_new_width = new_root_width >> 1;
            const half_new_height = new_root_height >> 1;
            const min_width = @min(self.root_size.x, new_root_width);
            const min_height = @min(self.root_size.y, new_root_height);
            const half_min_width = min_width >> 1;
            const half_min_height = min_height >> 1;
            var min_x_copy_old: Idx = undefined;
            var max_x_copy_old: Idx = undefined;
            var min_y_copy_old: Idx = undefined;
            var max_y_copy_old: Idx = undefined;
            var min_x_copy_new: Idx = undefined;
            var max_x_copy_new: Idx = undefined;
            var min_y_copy_new: Idx = undefined;
            var max_y_copy_new: Idx = undefined;
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
                    min_x_copy_old = self.root_size.x - min_width;
                    max_x_copy_old = self.root_size.x;
                    min_x_copy_new = new_root_width - min_width;
                    max_x_copy_new = new_root_width;
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
                    min_y_copy_old = self.root_size.y - min_height;
                    max_y_copy_old = self.root_size.y;
                    min_y_copy_new = new_root_height - min_height;
                    max_y_copy_new = new_root_height;
                },
            }
            const new_grid: GridAllocRoot = Self.allocate_new(.new(new_root_width, new_root_height), fill_value, alloc);
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    for (min_y_copy_old..max_y_copy_old, min_y_copy_new..max_y_copy_new) |old_y, new_y| {
                        const old_line = self.get_h_scanline(min_x_copy_old, old_y, min_width);
                        const new_line = new_grid.get_h_scanline(min_x_copy_new, new_y, min_width);
                        old_line.copy_entire_self_to_dest_start(new_line);
                    }
                },
                .COLUMN_MAJOR => {
                    for (min_x_copy_old..max_x_copy_old, min_x_copy_new..max_x_copy_new) |old_x, new_x| {
                        const old_line = self.get_v_scanline(min_y_copy_old, old_x, min_height);
                        const new_line = new_grid.get_v_scanline(min_y_copy_new, new_x, min_height);
                        old_line.copy_entire_self_to_dest_start(new_line);
                    }
                },
            }
            self.free(alloc);
            if (fill_value) |fill| {
                const fill_x1 = 0;
                const fill_x2 = min_x_copy_new;
                const fill_x3 = max_x_copy_new;
                const fill_x4 = new_root_width;
                const fill_y1 = 0;
                const fill_y2 = min_y_copy_new;
                const fill_y3 = max_y_copy_new;
                const fill_y4 = new_root_height;
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

        fn fill_rect_internal(self: Self, x1: Idx, y1: Idx, x2: Idx, y2: Idx, width: Idx, height: Idx, fill_value: Cell) void {
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    if (y2 != y1) {
                        if (x1 == 0 and width == self.root_size.x) {
                            const fill_block = self.get_h_scanline(x1, y1, self.root_size.x * (height));
                            fill_block.memset_len(fill_value);
                        } else {
                            for (y1..y2) |y| {
                                const fill_line = self.get_h_scanline(x1, @intCast(y), width);
                                fill_line.memset_len(fill_value);
                            }
                        }
                    }
                },
                .COLUMN_MAJOR => {
                    if (x2 != x1) {
                        if (y1 == 0 and height == self.root_size.y) {
                            const fill_block = self.get_v_scanline(x1, y1, self.root_size.y * (width));
                            fill_block.memset_len(fill_value);
                        } else {
                            for (x1..x2) |x| {
                                const fill_line = self.get_v_scanline(@intCast(x), y1, height);
                                fill_line.memset_len(fill_value);
                            }
                        }
                    }
                },
            }
        }

        pub fn fill_all(self: Self, fill_color: Cell) void {
            self.fill_rect(0, 0, self.root_size.x, self.root_size.y, fill_color);
        }
        pub fn fill_rect(self: Self, x: Idx, y: Idx, width: Idx, height: Idx, fill_val: Cell) void {
            assert_with_reason(x + width <= self.root_size.x and y + height <= self.root_size.y, @src(), "bottom-right coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x + width, y + height, self.root_size.x, self.root_size.y });
            const x2 = x + width;
            const y2 = y + height;
            self.fill_rect_internal(x, y, x2, y2, width, height, fill_val);
        }
        pub fn fill_rect_with_origin(self: Self, origin: Origin, x: Idx, y: Idx, width: Idx, height: Idx, width_dir: XOrder, height_dir: YOrder, fill_val: Cell) void {
            const x1 = self.get_x_with_origin_and_span_width(origin, x, width, width_dir);
            const y1 = self.get_y_with_origin_and_span_height(origin, y, height, height_dir);
            assert_with_reason(x1 + width <= self.root_size.x and y1 + height <= self.root_size.y, @src(), "max extent coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x1 + width, y1 + height, self.root_size.x, self.root_size.y });
            const x2 = x + width;
            const y2 = y + height;
            self.fill_rect_internal(x1, y1, x2, y2, width, height, fill_val);
        }
        pub fn fill_rect_xy(self: Self, x1: Idx, y1: Idx, x2: Idx, y2: Idx, fill_val: Cell) void {
            assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
            assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
            assert_with_reason(x2 <= self.root_size.x and y2 <= self.root_size.y, @src(), "bottom-right coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ x2, y2, self.root_size.x, self.root_size.y });
            const width = x2 - x1;
            const height = y2 - y1;
            self.fill_rect_internal(x1, y1, x2, y2, width, height, fill_val);
        }
        pub fn fill_rect_xy_with_origin(self: Self, origin: Origin, x1: Idx, y1: Idx, x2: Idx, y2: Idx, fill_val: Cell) void {
            assert_with_reason(x1 <= x2, @src(), "x2 ({d}) is smaller than x1 ({d})", .{ x2, x1 });
            assert_with_reason(y1 <= y2, @src(), "y2 ({d}) is smaller than y1 ({d})", .{ y2, y1 });
            const width = x2 - x1;
            const height = y2 - y1;
            const xx1 = self.get_x_with_origin(origin, x1);
            const xx2 = self.get_x_with_origin(origin, x2);
            const yy1 = self.get_y_with_origin(origin, y1);
            const yy2 = self.get_y_with_origin(origin, y2);
            assert_with_reason(xx2 <= self.root_size.x and yy2 <= self.root_size.y, @src(), "max extent coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ xx2, yy2, self.root_size.x, self.root_size.y });
            self.fill_rect_internal(xx1, yy1, xx2, yy2, width, height, fill_val);
        }

        fn copy_rect_to_internal(source: Self, x_src: Idx, y_src: Idx, width: Idx, height: Idx, dest: Self, x_dest: Idx, y_dest: Idx) void {
            assert_with_reason(source.get_offset().x + x_src + width <= source.root_size.x and source.get_offset().y + y_src + height <= source.root_size.y, @src(), "bottom-right source coordinate ({d}, {d}) is outside the source DataGrid width/height ({d}, {d})", .{ source.get_offset().x + x_src + width, source.get_offset().y + y_src + height, source.root_size.x, source.root_size.y });
            assert_with_reason(dest.get_offset().x + x_dest + width <= dest.root_size.x and dest.get_offset().y + y_dest + height <= dest.root_size.y, @src(), "bottom-right destination coordinate ({d}, {d}) is outside the destination DataGrid width/height ({d}, {d})", .{ dest.get_offset().x + x_dest + width, dest.get_offset().y + y_dest + height, dest.root_size.x, dest.root_size.y });
            const y_src_2 = y_src + height;
            const x_src_2 = x_src + width;
            const y_dest_2 = y_dest + height;
            const x_dest_2 = x_dest + width;
            switch (ROW_COLUMN_ORDER) {
                .ROW_MAJOR => {
                    if (y_src_2 != y_src) {
                        if (x_src == 0 and x_dest == 0 and width == source.root_size.x and width == dest.root_size.x) {
                            const from_block = source.get_h_scanline(x_src, y_src, source.root_size.x * (height));
                            const to_block = source.get_h_scanline(x_dest, y_dest, dest.root_size.x * (height));
                            from_block.copy_entire_self_to_dest_start(to_block);
                        } else {
                            for (y_src..y_src_2, y_dest..y_dest_2) |y, yy| {
                                const from_line = source.get_h_scanline(x_src, y, width);
                                const to_line = source.get_h_scanline(x_dest, yy, width);
                                from_line.copy_entire_self_to_dest_start(to_line);
                            }
                        }
                    }
                },
                .COLUMN_MAJOR => {
                    if (x_src_2 != x_src) {
                        if (y_src == 0 and y_dest == 0 and height == source.root_size.y and height == dest.root_size.y) {
                            const from_block = source.get_v_scanline(x_src, y_src, source.root_size.y * (width));
                            const to_block = source.get_v_scanline(x_dest, y_dest, dest.root_size.y * (width));
                            from_block.copy_entire_self_to_dest_start(to_block);
                        } else {
                            for (x_src..x_src_2, x_dest..x_dest_2) |x, xx| {
                                const from_line = source.get_v_scanline(x, y_src, height);
                                const to_line = source.get_v_scanline(xx, y_dest, height);
                                from_line.copy_entire_self_to_dest_start(to_line);
                            }
                        }
                    }
                },
            }
        }

        pub fn copy_rect_to(source: Self, x_src: Idx, y_src: Idx, width: Idx, height: Idx, dest: Self, x_dest: Idx, y_dest: Idx) void {
            source.copy_rect_to_internal(x_src, y_src, width, height, dest, x_dest, y_dest, false);
        }
        pub fn copy_rect_to_with_origin(source: Self, origin: Origin, x_src: Idx, y_src: Idx, width: Idx, height: Idx, dest: Self, x_dest: Idx, y_dest: Idx, width_dir: XOrder, height_dir: YOrder) void {
            const xx_src = source.get_x_with_origin_and_span_width(origin, x_src, width, width_dir);
            const yy_src = source.get_y_with_origin_and_span_height(origin, y_src, height, height_dir);
            const xx_dest = dest.get_x_with_origin_and_span_width(origin, x_dest, width, width_dir);
            const yy_dest = dest.get_y_with_origin_and_span_height(origin, y_dest, height, height_dir);
            source.copy_rect_to_internal(xx_src, yy_src, width, height, dest, xx_dest, yy_dest, false);
        }

        pub fn copy_rect_to_possible_overlap(source: Self, x_src: Idx, y_src: Idx, width: Idx, height: Idx, dest: Self, x_dest: Idx, y_dest: Idx) void {
            source.copy_rect_to_internal(x_src, y_src, width, height, dest, x_dest, y_dest, true);
        }
        pub fn copy_rect_to_possible_overlap_with_origin(source: Self, origin: Origin, x_src: Idx, y_src: Idx, width: Idx, height: Idx, dest: Self, x_dest: Idx, y_dest: Idx, width_dir: XOrder, height_dir: YOrder) void {
            const xx_src = source.get_x_with_origin_and_span_width(origin, x_src, width, width_dir);
            const yy_src = source.get_y_with_origin_and_span_height(origin, y_src, height, height_dir);
            const xx_dest = dest.get_x_with_origin_and_span_width(origin, x_dest, width, width_dir);
            const yy_dest = dest.get_y_with_origin_and_span_height(origin, y_dest, height, height_dir);
            source.copy_rect_to_internal(xx_src, yy_src, width, height, dest, xx_dest, yy_dest, true);
        }
        pub inline fn get_entire_region(self: Self) GridRegion {
            return self.get_region(0, 0, self.get_width(), self.get_height());
        }
        pub fn get_region(self: Self, x: Idx, y: Idx, width: Idx, height: Idx) GridRegion {
            assert_with_reason(self.get_offset().x + x + width <= self.root_size.x and self.get_offset().y + y + height <= self.root_size.y, @src(), "bottom-right coordinate ({d}, {d}) is outside the DataGrid width/height ({d}, {d})", .{ self.get_offset().x + x + width, self.get_offset().y + y + height, self.root_size.x, self.root_size.y });
            return GridRegion{
                .cells = self.cells,
                .root_size = self.root_size,
                .offset = .new(x, y),
                .size = .new(width, height),
            };
        }
        pub fn get_region_with_origin(self: Self, origin: Origin, x: Idx, y: Idx, width: Idx, width_direction: XOrder, height: Idx, height_direction: YOrder) GridRegion {
            const xx = self.get_x_with_origin_and_span_width(origin, x, width, width_direction);
            const yy = self.get_y_with_origin_and_span_height(origin, y, height, height_direction);
            return self.get_region(xx, yy, width, height);
        }
        pub fn get_region_xy(self: Self, x1: Idx, y1: Idx, x2: Idx, y2: Idx) GridRegion {
            const xx1 = @min(x1, x2);
            const yy1 = @min(y1, y2);
            const xx2 = @max(x1, x2);
            const yy2 = @max(y1, y2);
            const width = xx2 - xx1;
            const height = yy2 - yy1;
            return self.get_region(xx1, yy1, width, height);
        }
        pub fn get_region_xy_with_origin(self: Self, origin: Origin, x1: Idx, y1: Idx, x2: Idx, y2: Idx) GridRegion {
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
            PROVIDER_FUNC_OPAQUE,
            PROVIDER_FUNC_FROM_GRID,
        };

        const Vec = Vec2.define_vec2_type(Idx);

        pub const RegionSource = union(SourceKind) {
            EXISTING: struct {
                region: GridRegion,
                fill: ?Cell,
            },
            PROVIDER_FUNC_OPAQUE: struct {
                func: *const fn (width: Idx, height: Idx, fill: ?Cell) ?GridRegion,
                fill: ?Cell,
            },
            PROVIDER_FUNC_FROM_GRID: struct {
                grid: Self,
                func: *const fn (grid: Self, width: Idx, height: Idx, fill: ?Cell) ?GridRegion,
                fill: ?Cell,
            },

            pub fn existing_region(grid_with_offset: GridRegion, fill: ?Cell) RegionSource {
                return RegionSource{ .EXISTING = .{ .region = grid_with_offset, .fill = fill } };
            }
            pub fn data_grid_provider_opaque(func: *const fn (width: Idx, height: Idx, fill: ?Cell) ?GridRegion, fill: ?Cell) RegionSource {
                return RegionSource{ .PROVIDER_FUNC_OPAQUE = .{ .func = func, .fill = fill } };
            }
            pub fn data_grid_provider_from_grid(grid: Self, func: *const fn (grid: Self, width: Idx, height: Idx, fill: ?Cell) ?GridRegion, fill: ?Cell) RegionSource {
                return RegionSource{ .PROVIDER_FUNC_FROM_GRID = .{ .grid = grid, .func = func, .fill = fill } };
            }

            pub fn obtain_grid(self: RegionSource, width: Idx, height: Idx) ?GridRegion {
                return switch (self) {
                    .EXISTING => |src| after_fill: {
                        if (src.region.get_width() < width or src.region.get_height() < height) return null;
                        const adjusted = src.region.get_region(0, 0, width, height);
                        if (src.fill) |fill| adjusted.fill_all(fill);
                        break :after_fill adjusted;
                    },
                    .PROVIDER_FUNC_OPAQUE => |src| src.func(width, height, src.fill),
                    .PROVIDER_FUNC_FROM_GRID => |src| src.func(src.grid, width, height, src.fill),
                };
            }
            pub fn obtain_region_with_padding(self: RegionSource, width: Idx, height: Idx, pad_x: Idx, pad_y: Idx) ?GridRegion {
                var with_pad = self.obtain_grid(width + (2 * pad_x), height + (2 * pad_y)) orelse return null;
                const without_pad = with_pad.get_region(pad_x, pad_y, width, height);
                return without_pad;
            }
            pub fn obtain_grid_block(self: RegionSource, width: Idx, height: Idx, comptime SUB_GRID_X_COUNT: Idx, comptime SUB_GRID_Y_COUNT: Idx) ?[SUB_GRID_X_COUNT][SUB_GRID_Y_COUNT]GridRegion {
                const total_width = width * SUB_GRID_X_COUNT;
                const total_height = height * SUB_GRID_Y_COUNT;
                const total = self.obtain_grid(total_width, total_height) orelse return null;
                var out: [SUB_GRID_X_COUNT][SUB_GRID_Y_COUNT]GridRegion = undefined;
                var px: Idx = 0;
                var py: Idx = 0;
                for (0..SUB_GRID_Y_COUNT) |gy| {
                    px = 0;
                    for (0..SUB_GRID_X_COUNT) |gx| {
                        const dg_adjusted = total.get_region(px, py, width, height);
                        out[gx][gy] = dg_adjusted;
                        px += width;
                    }
                    py += height;
                }
                return out;
            }
            pub fn obtain_grid_block_with_padding(self: RegionSource, width: Idx, height: Idx, pad_x: Idx, pad_y: Idx, comptime SUB_GRID_X_COUNT: Idx, comptime SUB_GRID_Y_COUNT: Idx) ?[SUB_GRID_X_COUNT][SUB_GRID_Y_COUNT]GridRegion {
                const width_and_pad = width + (2 * pad_x);
                const height_and_pad = height + (2 * pad_y);
                const total_width = width_and_pad * SUB_GRID_X_COUNT;
                const total_height = height_and_pad * SUB_GRID_Y_COUNT;
                const total = self.obtain_grid(total_width, total_height) orelse return null;
                var out: [SUB_GRID_X_COUNT][SUB_GRID_Y_COUNT]GridRegion = undefined;
                var px: Idx = 0;
                var py: Idx = 0;
                for (0..SUB_GRID_Y_COUNT) |gy| {
                    px = 0;
                    for (0..SUB_GRID_X_COUNT) |gx| {
                        const dg_adjusted = total.data_grid.get_region(px + pad_x, py + pad_y, width, height);
                        out[gx][gy] = dg_adjusted;
                        px += width_and_pad;
                    }
                    py += height_and_pad;
                }
                return out;
            }
        };
    };
}
