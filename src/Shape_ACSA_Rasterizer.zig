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
const Cast = Root.Cast;
const AABB = Root.AABB2.define_aabb2_type;

const num_cast = Cast.num_cast;
const DEBUG = std.debug.print;
const DEBUG_VAL = Root.Utils.DebugPrint.debug_val;

pub const FillRule = enum(u8) {
    NON_ZERO,
    EVEN_ODD,
};

pub const OutputError = error{
    could_not_obtain_output_grid_for_given_size,
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
        const VectorI = Vec2.define_vec2_type(Idx);

        pub const Cell = struct {
            cover: Float = 0,
            area: Float = 0,
        };

        const CellList = List(Cell, Idx, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
        const CellGrid = COMPUTE_GRID_DEF.Grid();
        const CoverList = List(Float, Idx, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
        const Contour = ShapeModule.Contour(Float, void, {});
        const Shape = ShapeModule.Shape(Float, void, {});

        pub const RasterOptions = struct {
            /// Maximum deviation of bezier curves from chord in pixels before splitting
            tolerance: Float = 0.2,
            fill_rule: FillRule = .NON_ZERO,
            coord_origin: ?DataGridModule.Origin = null,
            final_shape_padding: VectorI = .TWO,
        };

        grid: CellGrid = .{},
        row_cover: CoverList = .{},
        allocator: Allocator,

        pub fn init_empty(alloc: Allocator) Self {
            return Self{
                .allocator = alloc,
            };
        }
        pub fn init_with_existing(cells: CellGrid, row_cover: CoverList, alloc: Allocator) Self {
            return Self{
                .grid = cells,
                .row_cover = row_cover,
                .allocator = alloc,
            };
        }

        pub fn clear_and_realloc(self: *Self, width: Idx, height: Idx) void {
            self.grid.discard_and_realloc(width, height, Cell{}, self.allocator);
            self.row_cover.clear();
            self.row_cover.grow_capacity_if_needed(height, .GROW_BY_25_PERCENT, self.allocator);
            self.row_cover.set_len(height);
        }

        pub fn free(self: *Self) void {
            self.grid.free_if_non_zero(self.allocator);
            self.row_cover.free_if_non_zero(self.allocator);
        }

        fn add_cell_area(self: *Self, x: IdxSigned, y: IdxSigned, delta_y: Float, area: Float, opts: RasterOptions) void {
            if (y < 0 or y >= @as(IdxSigned, @intCast(self.grid.get_height()))) return;
            const y_idx = @as(Idx, @intCast(y));
            if (x < 0) {
                self.row_cover.get_ptr(y_idx).* += delta_y;
                return;
            }
            if (x >= @as(IdxSigned, @intCast(self.grid.get_width()))) {
                return;
            }
            const cell_ptr = self.get_cell_ptr(@intCast(x), y_idx, opts);
            cell_ptr.cover += delta_y;
            cell_ptr.area += area;
        }

        /// Rasterizes a segment strictly contained within scanline [y_row, y_row + 1]
        fn rasterize_subsegment_in_row(self: *Self, y_row: IdxSigned, x0: Float, y0: Float, x1: Float, y1: Float, opts: RasterOptions) void {
            if (y_row < 0 or y_row >= @as(IdxSigned, @intCast(self.grid.get_height()))) return;
            const delta_y = y1 - y0;
            if (delta_y == 0) return;

            const col_0 = @as(IdxSigned, @intFromFloat(@floor(x0)));
            const col_1 = @as(IdxSigned, @intFromFloat(@floor(x1)));

            // Single pixel column
            if (col_0 == col_1) {
                const sub_x_0 = x0 - @as(Float, @floatFromInt(col_0));
                const sub_x_1 = x1 - @as(Float, @floatFromInt(col_0));
                const area = delta_y * (1.0 - (0.5 * (sub_x_0 + sub_x_1)));
                self.add_cell_area(col_0, y_row, delta_y, area, opts);
                return;
            }

            const delta_x = x1 - x0;
            const inv_dx = 1.0 / delta_x;

            if (col_0 < col_1) {
                // Moving right: x0 -> x1
                var curr_x = x0;
                var curr_y = y0;
                var c = col_0;
                while (c < col_1) : (c += 1) {
                    const next_x = @as(Float, @floatFromInt(c + 1));
                    const next_y = y0 + (next_x - x0) * (delta_y * inv_dx);
                    const sub_dy = next_y - curr_y;
                    const sub_x_0 = curr_x - @as(Float, @floatFromInt(c));
                    const area = sub_dy * (1.0 - 0.5 * (sub_x_0 + 1.0));
                    self.add_cell_area(c, y_row, sub_dy, area, opts);
                    curr_x = next_x;
                    curr_y = next_y;
                }
                const sub_dy = y1 - curr_y;
                const sub_x_0 = curr_x - @as(Float, @floatFromInt(col_1));
                const sub_x_1 = x1 - @as(Float, @floatFromInt(col_1));
                const area = sub_dy * (1.0 - 0.5 * (sub_x_0 + sub_x_1));
                self.add_cell_area(col_1, y_row, sub_dy, area, opts);
            } else {
                // Moving left: x0 -> x1
                var curr_x = x0;
                var curr_y = y0;
                var c = col_0;
                while (c > col_1) : (c -= 1) {
                    const next_x = @as(Float, @floatFromInt(c));
                    const next_y = y0 + (next_x - x0) * (delta_y * inv_dx);
                    const sub_dy = next_y - curr_y;
                    const sub_x_0 = curr_x - @as(Float, @floatFromInt(c));
                    const area = sub_dy * (1.0 - 0.5 * (sub_x_0 + 0.0));
                    self.add_cell_area(c, y_row, sub_dy, area, opts);
                    curr_x = next_x;
                    curr_y = next_y;
                }
                const sub_dy = y1 - curr_y;
                const sub_x_0 = curr_x - @as(Float, @floatFromInt(col_1));
                const sub_x_1 = x1 - @as(Float, @floatFromInt(col_1));
                const area = sub_dy * (1.0 - 0.5 * (sub_x_0 + sub_x_1));
                self.add_cell_area(col_1, y_row, sub_dy, area, opts);
            }
        }

        pub fn add_line(self: *Self, p0: Vector, p1: Vector, opts: RasterOptions) void {
            if (p0.y == p1.y) return; // Pure horizontal segments contribute 0 cover/area

            var x0 = p0.x;
            var y0 = p0.y;
            var x1 = p1.x;
            var y1 = p1.y;

            const height_f = @as(Float, @floatFromInt(self.grid.get_height()));

            // Clip against vertical screen bounds [0, height]
            if ((y0 <= 0 and y1 <= 0) or (y0 >= height_f and y1 >= height_f)) return;

            const orig_dy = y1 - y0;
            const orig_dx = x1 - x0;
            const inv_dy = 1.0 / orig_dy;

            // Clip y0
            if (y0 < 0) {
                x0 = x0 + (0 - y0) * orig_dx * inv_dy;
                y0 = 0;
            } else if (y0 > height_f) {
                x0 = x0 + (height_f - y0) * orig_dx * inv_dy;
                y0 = height_f;
            }

            // Clip y1
            if (y1 < 0) {
                x1 = p0.x + (0 - p0.y) * orig_dx * inv_dy;
                y1 = 0;
            } else if (y1 > height_f) {
                x1 = p0.x + (height_f - p0.y) * orig_dx * inv_dy;
                y1 = height_f;
            }

            if (y0 == y1) return;

            const r0 = @as(IdxSigned, @intFromFloat(@floor(y0)));
            const r1 = @as(IdxSigned, @intFromFloat(@floor(y1)));

            if (r0 == r1) {
                self.rasterize_subsegment_in_row(r0, x0, y0, x1, y1, opts);
                return;
            }

            const clamped_dx = x1 - x0;
            const clamped_dy = y1 - y0;
            const clamped_inv_dy = 1.0 / clamped_dy;

            if (r0 < r1) {
                // Moving down/up: y0 -> y1
                var curr_x = x0;
                var curr_y = y0;
                var r = r0;
                while (r < r1) : (r += 1) {
                    const next_y = @as(Float, @floatFromInt(r + 1));
                    const next_x = x0 + (next_y - y0) * clamped_dx * clamped_inv_dy;
                    self.rasterize_subsegment_in_row(r, curr_x, curr_y, next_x, next_y, opts);
                    curr_x = next_x;
                    curr_y = next_y;
                }
                self.rasterize_subsegment_in_row(r1, curr_x, curr_y, x1, y1, opts);
            } else {
                // Moving down/up: y0 -> y1 (reversed)
                var curr_x = x0;
                var curr_y = y0;
                var r = r0;
                while (r > r1) : (r -= 1) {
                    const next_y = @as(Float, @floatFromInt(r));
                    const next_x = x0 + (next_y - y0) * clamped_dx * clamped_inv_dy;
                    self.rasterize_subsegment_in_row(r, curr_x, curr_y, next_x, next_y, opts);
                    curr_x = next_x;
                    curr_y = next_y;
                }
                self.rasterize_subsegment_in_row(r1, curr_x, curr_y, x1, y1, opts);
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

        pub fn rasterize_contour(self: *Self, contour: Contour, opts: RasterOptions) void {
            const tolerance_squared = opts.tolerance * opts.tolerance;
            for (contour.edges.zig_slice_entire()) |edge_item| {
                switch (edge_item.edge) {
                    .POINT => {},
                    .LINE => |line| {
                        self.add_line(line.p[0], line.p[1], opts);
                    },
                    .QUADRATIC_BEZIER => |quad| {
                        self.add_quadratic_bezier(quad.p[0], quad.p[1], quad.p[2], tolerance_squared, 0, opts);
                    },
                    .CUBIC_BEZIER => |cube| {
                        self.add_cubic_bezier(cube.p[0], cube.p[1], cube.p[2], cube.p[3], tolerance_squared, 0, opts);
                    },
                }
            }
        }

        fn get_cell(self: Self, x: Idx, y: Idx, opts: RasterOptions) Cell {
            if (opts.coord_origin) |origin| {
                return self.grid.get_cell_with_origin(origin, x, y);
            } else {
                return self.grid.get_cell(x, y);
            }
        }
        fn get_cell_ptr(self: *Self, x: Idx, y: Idx, opts: RasterOptions) *Cell {
            if (opts.coord_origin) |origin| {
                return self.grid.get_cell_ptr_with_origin(origin, x, y);
            } else {
                return self.grid.get_cell_ptr(x, y);
            }
        }

        pub fn rasterize_shape_to_grid(
            self: *Self,
            shape: Shape,
            opts: RasterOptions,
            comptime OUTPUT_GRID_DEF: GridDefinition,
            output_grid_region: OUTPUT_GRID_DEF.with_ownership(.REGION).Grid().RegionSource,
            unfill_val: OUTPUT_GRID_DEF.LIST_DEF.ELEM,
            fill_val: OUTPUT_GRID_DEF.LIST_DEF.ELEM,
        ) OutputError!OUTPUT_GRID_DEF.with_ownership(.REGION).Grid() {
            var aabb_f: AABB(Float) = .{};
            shape.add_bounds_to_aabb(&aabb_f, .estimate_linear_when_linear_coeff_more_than_N_times_quadratic(ShapeModule.DEFAULT_LINEAR_ESTIMATE_RATIO));
            aabb_f = aabb_f.expand_round_to_int();
            for (shape.contours.zig_slice_entire()) |contour| {
                self.rasterize_contour(contour, opts);
            }
            var output_region = output_grid_region.obtain_region_with_padding(@intFromFloat(aabb_f.x_max), @intFromFloat(aabb_f.y_max), opts.final_shape_padding.x, opts.final_shape_padding.y) orelse return OutputError.could_not_obtain_output_grid_for_given_size;
            if (self.grid.get_width() > num_cast(output_region.get_width(), Idx) or self.grid.get_height() > num_cast(output_region.get_height(), Idx)) return OutputError.could_not_obtain_output_grid_for_given_size;
            var y: Idx = 0;
            while (y < self.grid.get_height()) : (y += 1) {
                var accum = self.row_cover.get(y);
                var x: Idx = 0;
                while (x < self.grid.get_width()) : (x += 1) {
                    const c: Cell = self.get_cell(x, y, opts);
                    const raw_val = accum + c.area;
                    accum += c.cover;
                    var coverage: Float = 0;
                    switch (opts.fill_rule) {
                        .NON_ZERO => {
                            coverage = @min(1.0, @max(0.0, @abs(raw_val)));
                        },
                        .EVEN_ODD => {
                            const v = @abs(raw_val);
                            const f = v - @floor(v);
                            const int_v = @as(i32, @intFromFloat(@floor(v)));
                            coverage = if ((int_v & 1) != 0) 1.0 - f else f;
                            coverage = @min(1.0, @max(0.0, coverage));
                        },
                    }
                    const final_px = Math.upgrade_lerp_out(unfill_val, fill_val, coverage, OUTPUT_GRID_DEF.LIST_DEF.ELEM);
                    output_region.set_cell(x, y, final_px);
                }
            }
            return output_region;
        }
    };
}
