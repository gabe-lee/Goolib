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
const Allocator = std.mem.Allocator;

const Root = @import("./_root.zig");
const Vec2 = Root.Vec2;
const DataGridModule = Root.DataGrid;
const GridDefinition = DataGridModule.GridDefinition;
const GridDefinitionNoElem = DataGridModule.GridDefinitionNoElem;
const GridDefinitionNoList = DataGridModule.GridDefinitionNoList;
const DataGrid = DataGridModule.DataGrid;
const ShapeModule = Root.Shape;
const List = Root.ListSlice.ListFullDefinition;
const Math = Root.Math;

pub const FillRule = enum(u8) {
    NON_ZERO,
    EVEN_ODD,
};

pub const OutputError = error{
    could_not_obtain_output_grid_for_given_size,
};

pub const RasterOptions = struct {
    /// Maximum deviation of bezier curves from chord in pixels before splitting
    tolerance: f32 = 0.2,
    fill_rule: FillRule = .NON_ZERO,
    coord_origin: DataGridModule.Origin = .TOP_LEFT,
    scale_x: f32 = 1.0,
    scale_y: f32 = 1.0,
    offset_x: f32 = 0.0,
    offset_y: f32 = 0.0,
};

pub fn CellAccumulatorRasterizer(comptime COMPUTE_GRID_DEF_NO_LIST: GridDefinitionNoList, comptime Float: type, comptime Idx: type, comptime IdxSigned: type) type {
    return struct {
        const Self = @This();
        const COMPUTE_GRID_DEF = COMPUTE_GRID_DEF_NO_LIST.with_list_def(.{
            .ELEM = Cell,
            .IDX = Idx,
            .OWNERSHIP = .OWNED_ALLOCATED,
        });
        const Vector = Vec2.define_vec2_type(Float);

        pub const Cell = struct {
            cover: Float = 0,
            area: Float = 0,
        };

        const CellList = List(Cell, Idx, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
        const CellGrid = COMPUTE_GRID_DEF.Grid();
        const CoverList = List(Float, Idx, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
        const Contour = ShapeModule.Contour(Float, void, {});
        const Shape = ShapeModule.Shape(Float, void, {});

        cells: CellGrid = .{},
        row_cover: CoverList = .{},
        allocator: Allocator,

        pub fn init_empty(alloc: Allocator) Self {
            return Self{
                .allocator = alloc,
            };
        }
        pub fn init_with_existing(cells: CellGrid, row_cover: CoverList, alloc: Allocator) Self {
            return Self{
                .cells = cells,
                .row_cover = row_cover,
                .allocator = alloc,
            };
        }

        pub fn clear_and_resize(self: *Self, width: Idx, height: Idx, major_stride: ?Idx) void {
            self.cells.discard_and_resize(width, height, major_stride, Cell{}, self.allocator);
            self.row_cover.clear();
            self.row_cover.grow_capacity_if_needed(height, .GROW_BY_25_PERCENT, self.allocator);
            self.row_cover.set_len(height);
        }

        pub fn free(self: *Self) void {
            self.cells.free_if_non_zero(self.allocator);
            self.row_cover.free_if_non_zero(self.allocator);
        }

        fn rasterize_subsegment_in_row(self: *Self, y_row: IdxSigned, x0: Float, y0: Float, x1: Float, y1: Float, opts: RasterOptions) void {
            if (y_row < 0 or y_row >= @as(IdxSigned, @intCast(self.cells.height))) return;
            const dy_total = y1 - y0;
            if (dy_total == 0) return;

            const width_f = @as(Float, @floatFromInt(self.cells.width));
            const row_u: Idx = @intCast(y_row);

            // Entirely left of the viewport -> contributes to row base coverage
            if (x0 <= 0 and x1 <= 0) {
                self.row_cover.get_ptr(row_u).* += dy_total;
                return;
            }
            // Entirely right of viewport -> no contribution to visible cells
            if (x0 >= width_f and x1 >= width_f) {
                return;
            }

            var sx0 = x0;
            var sy0 = y0;
            var sx1 = x1;
            var sy1 = y1;

            // Clip against left edge (x = 0)
            if (sx0 < 0 or sx1 < 0) {
                if (sx0 < 0) {
                    const t = (0 - sx0) / (sx1 - sx0);
                    const y_mid = sy0 + t * (sy1 - sy0);
                    self.row_cover.get_ptr(row_u).* += (y_mid - sy0);
                    sx0 = 0;
                    sy0 = y_mid;
                } else {
                    const t = (0 - sx0) / (sx1 - sx0);
                    const y_mid = sy0 + t * (sy1 - sy0);
                    self.row_cover.get_ptr(row_u).* += (sy1 - y_mid);
                    sx1 = 0;
                    sy1 = y_mid;
                }
            }

            // Clip against right edge (x = width)
            if (sx0 > width_f or sx1 > width_f) {
                if (sx0 > width_f) {
                    const t = (width_f - sx0) / (sx1 - sx0);
                    sy0 = sy0 + t * (sy1 - sy0);
                    sx0 = width_f;
                } else {
                    const t = (width_f - sx0) / (sx1 - sx0);
                    sy1 = sy0 + t * (sy1 - sy0);
                    sx1 = width_f;
                }
            }

            const c0 = @as(IdxSigned, @intFromFloat(@floor(sx0)));
            const c1 = @as(IdxSigned, @intFromFloat(@floor(sx1)));
            const max_col = @as(IdxSigned, @intCast(self.cells.width - 1));
            const col_start = @min(@max(c0, 0), max_col);
            const col_end = @min(@max(c1, 0), max_col);

            // Single pixel column
            if (col_start == col_end) {
                const u_0 = sx0 - @as(Float, @floatFromInt(col_start));
                const u_1 = sx1 - @as(Float, @floatFromInt(col_start));
                const dy = sy1 - sy0;
                const cell_ptr = self.cells.get_cell_ptr_with_origin(opts.coord_origin, @intCast(col_start), row_u);
                cell_ptr.cover += dy;
                cell_ptr.area += dy * (1.0 - (0.5 * (u_0 + u_1)));
                return;
            }

            // Multi-column traverse (left to right)
            if (sx0 < sx1) {
                var curr_x = sx0;
                var curr_y = sy0;
                var c = col_start;
                while (c < col_end) : (c += 1) {
                    const next_x = @as(Float, @floatFromInt(c + 1));
                    const t = (next_x - sx0) / (sx1 - sx0);
                    const next_y = sy0 + t * (sy1 - sy0);
                    const u_0 = curr_x - @as(Float, @floatFromInt(c));
                    const dy = next_y - curr_y;
                    const cell_ptr = self.cells.get_cell_ptr_with_origin(opts.coord_origin, @intCast(col_start), row_u);
                    cell_ptr.cover += dy;
                    cell_ptr.area += dy * (1.0 - (0.5 * (u_0 + 1.0)));
                    curr_x = next_x;
                    curr_y = next_y;
                }
                const u_0 = curr_x - @as(Float, @floatFromInt(col_end));
                const u_1 = sx1 - @as(Float, @floatFromInt(col_end));
                const dy = sy1 - curr_y;
                const cell_ptr = self.cells.get_cell_ptr_with_origin(opts.coord_origin, @intCast(col_end), row_u);
                cell_ptr.cover += dy;
                cell_ptr.area += dy * (1.0 - (0.5 * (u_0 + u_1)));
            } else {
                // Multi-column traverse (right to left)
                var curr_x = sx0;
                var curr_y = sy0;
                var c = col_start;
                while (c > col_end) : (c -= 1) {
                    const next_x = @as(Float, @floatFromInt(c));
                    const t = (next_x - sx0) / (sx1 - sx0);
                    const next_y = sy0 + t * (sy1 - sy0);
                    const u_0 = curr_x - @as(Float, @floatFromInt(c));
                    const dy = next_y - curr_y;
                    const cell_ptr = self.cells.get_cell_ptr_with_origin(opts.coord_origin, @intCast(col_start), row_u);
                    cell_ptr.cover += dy;
                    cell_ptr.area += dy * (1.0 - (0.5 * (u_0 + 0.0)));
                    curr_x = next_x;
                    curr_y = next_y;
                }
                const u_0 = curr_x - @as(Float, @floatFromInt(col_end));
                const u_1 = sx1 - @as(Float, @floatFromInt(col_end));
                const dy = sy1 - curr_y;
                const cell_ptr = self.cells.get_cell_ptr_with_origin(opts.coord_origin, @intCast(col_start), row_u);
                cell_ptr.cover += dy;
                cell_ptr.area += dy * (1.0 - 0.5 * (u_0 + u_1));
            }
        }

        pub fn add_line(self: *Self, p0: Vector, p1: Vector, opts: RasterOptions) void {
            if (p0.y == p1.y) return; // Purely horizontal lines have dy = 0

            var x0 = p0.x;
            var y0 = p0.y;
            var x1 = p1.x;
            var y1 = p1.y;

            const height_f = @as(Float, @floatFromInt(self.cells.height));

            // Viewport clipping along Y
            if ((y0 <= 0 and y1 <= 0) or (y0 >= height_f and y1 >= height_f)) return;

            if (y0 < 0) {
                const t = (0 - y0) / (y1 - y0);
                x0 = x0 + t * (x1 - x0);
                y0 = 0;
            } else if (y0 > height_f) {
                const t = (height_f - y0) / (y1 - y0);
                x0 = x0 + t * (x1 - x0);
                y0 = height_f;
            }

            if (y1 < 0) {
                const t = (0 - y0) / (y1 - y0);
                x1 = x0 + t * (x1 - x0);
                y1 = 0;
            } else if (y1 > height_f) {
                const t = (height_f - y0) / (y1 - y0);
                x1 = x0 + t * (x1 - x0);
                y1 = height_f;
            }

            const r0 = @as(IdxSigned, @intFromFloat(@floor(y0)));
            const r1 = @as(IdxSigned, @intFromFloat(@floor(y1)));
            const max_row = @as(IdxSigned, @intCast(self.cells.height - 1));
            const row_start = @min(@max(r0, 0), max_row);
            const row_end = @min(@max(r1, 0), max_row);

            if (row_start == row_end) {
                self.rasterize_subsegment_in_row(row_start, x0, y0, x1, y1, opts);
                return;
            }

            if (y0 < y1) {
                var curr_x = x0;
                var curr_y = y0;
                var r = row_start;
                while (r < row_end) : (r += 1) {
                    const next_y = @as(Float, @floatFromInt(r + 1));
                    const t = (next_y - y0) / (y1 - y0);
                    const next_x = x0 + t * (x1 - x0);
                    self.rasterize_subsegment_in_row(r, curr_x, curr_y, next_x, next_y, opts);
                    curr_x = next_x;
                    curr_y = next_y;
                }
                self.rasterize_subsegment_in_row(row_end, curr_x, curr_y, x1, y1, opts);
            } else {
                var curr_x = x0;
                var curr_y = y0;
                var r = row_start;
                while (r > row_end) : (r -= 1) {
                    const next_y = @as(Float, @floatFromInt(r));
                    const t = (next_y - y0) / (y1 - y0);
                    const next_x = x0 + t * (x1 - x0);
                    self.rasterize_subsegment_in_row(r, curr_x, curr_y, next_x, next_y, opts);
                    curr_x = next_x;
                    curr_y = next_y;
                }
                self.rasterize_subsegment_in_row(row_end, curr_x, curr_y, x1, y1, opts);
            }
        }

        pub fn add_quadratic_bezier(self: *Self, p0: Vector, p1: Vector, p2: Vector, tol_sq: Float, depth: Idx, opts: RasterOptions) void {
            // Deviation from chord midpoint
            const mid = p0.add(p2).scale(0.5);
            const dev = p1.subtract(mid);
            const dev_sq = dev.dot_self();

            // Flat enough or max recursion reached
            if (dev_sq <= 4.0 * tol_sq or depth >= 10) {
                self.add_line(p0, p2, opts);
                return;
            }

            // De Casteljau subdivision at t = 0.5
            const p01 = p0.add(p1).scale(0.5);
            const p12 = p1.add(p2).scale(0.5);
            const p012 = p01.add(p12).scale(0.5);

            self.add_quadratic_bezier(p0, p01, p012, tol_sq, depth + 1, opts);
            self.add_quadratic_bezier(p012, p12, p2, tol_sq, depth + 1, opts);
        }

        pub fn add_cubic_bezier(self: *Self, p0: Vector, p1: Vector, p2: Vector, p3: Vector, tol_sq: Float, depth: Idx, opts: RasterOptions) void {
            // Distance of control points to the 1/3 and 2/3 chord points
            const m1 = p0.lerp(p3, 1.0 / 3.0);
            const m2 = p0.lerp(p3, 2.0 / 3.0);
            const dev1_sq = p1.subtract(m1).dot_self();
            const dev2_sq = p2.subtract(m2).dot_self();

            if (dev1_sq + dev2_sq <= tol_sq or depth >= 10) {
                self.add_line(p0, p3, opts);
                return;
            }

            // De Casteljau subdivision at t = 0.5
            const p01 = p0.add(p1).scale(0.5);
            const p12 = p1.add(p2).scale(0.5);
            const p23 = p2.add(p3).scale(0.5);
            const p012 = p01.add(p12).scale(0.5);
            const p123 = p12.add(p23).scale(0.5);
            const p0123 = p012.add(p123).scale(0.5);

            self.add_cubic_bezier(p0, p01, p012, p0123, tol_sq, depth + 1, opts);
            self.add_cubic_bezier(p0123, p123, p23, p3, tol_sq, depth + 1, opts);
        }

        fn transform_point(p: Vector, opts: RasterOptions) Vector {
            const x = (p.x * opts.scale_x) + opts.offset_x;
            const y = (p.y * opts.scale_y) + opts.offset_y;
            return Vector.new(x, y);
        }

        pub fn rasterize_contour(self: *Self, contour: Contour, opts: RasterOptions) void {
            const tolerance_squared = opts.tolerance * opts.tolerance;
            for (contour.edges.zig_slice_entire()) |edge_item| {
                const edge = edge_item.edge;
                switch (edge.kind()) {
                    .POINT => {},
                    .LINE => {
                        const p0 = transform_point(edge.get_start(), opts);
                        const p1 = transform_point(edge.get_end(), opts);
                        self.add_line(p0, p1, opts);
                    },
                    .QUADRATIC_BEZIER => {
                        const p0 = transform_point(edge.get_start(), opts);
                        const p1 = transform_point(edge.get_control_1(), opts);
                        const p2 = transform_point(edge.get_end(), opts);
                        self.add_quadratic_bezier(p0, p1, p2, tolerance_squared, 0, opts);
                    },
                    .CUBIC_BEZIER => {
                        const p0 = transform_point(edge.get_start(), opts);
                        const p1 = transform_point(edge.get_control_1(), opts);
                        const p2 = transform_point(edge.get_control_2(), opts);
                        const p3 = transform_point(edge.get_end(), opts);
                        self.add_cubic_bezier(p0, p1, p2, p3, tolerance_squared, 0, opts);
                    },
                }
            }
        }

        pub fn rasterize_shape(self: *Self, shape: Shape, opts: RasterOptions) void {
            for (shape.contours.zig_slice_entire()) |contour| {
                self.rasterize_contour(contour, opts);
            }
        }

        pub fn write_to_grid(
            self: Self,
            comptime OUTPUT_GRID_DEF: GridDefinition,
            output_grid_region: OUTPUT_GRID_DEF.Grid().Source,
            unfill_val: OUTPUT_GRID_DEF.LIST_DEF.ELEM,
            fill_val: OUTPUT_GRID_DEF.LIST_DEF.ELEM,
            opts: RasterOptions,
        ) OutputError!OUTPUT_GRID_DEF.Grid().DataGridWithParentOffset {
            var output_grid_with_offset = output_grid_region.obtain_grid(self.cells.width, self.cells.height) orelse return OutputError.could_not_obtain_output_grid_for_given_size;
            var y: Idx = 0;
            while (y < self.cells.height) : (y += 1) {
                var accum = self.row_cover.get(y);
                var x: Idx = 0;
                while (x < self.cells.width) : (x += 1) {
                    const c: Cell = self.cells.get_cell_with_origin(opts.coord_origin, x, y);
                    const raw_val = accum + c.area;
                    accum += c.cover;

                    var coverage: Float = 0;
                    switch (opts.fill_rule) {
                        .NON_ZERO => {
                            coverage = @min(1.0, @abs(@as(Float, @floatCast(raw_val))));
                        },
                        .EVEN_ODD => {
                            const v = @abs(@as(Float, @floatCast(raw_val)));
                            const f = v - @floor(v);
                            const int_v = @as(IdxSigned, @intFromFloat(@floor(v)));
                            coverage = if ((int_v & 1) != 0) 1.0 - f else f;
                        },
                    }
                    const final_px = Math.upgrade_lerp_out(unfill_val, fill_val, coverage, OUTPUT_GRID_DEF.LIST_DEF.ELEM);
                    output_grid_with_offset.data_grid.set_cell(x, y, final_px);
                }
            }
            return output_grid_with_offset;
        }
    };
}
