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
const build = @import("builtin");
const math = std.math;
const Root = @import("./_root.zig");
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const DummyAllocator = Root.Allocator.Dummy;
const List = Root.ListSlice.ListAllocated;
const ListFull = Root.ListSlice.ListFullDefinition;
const ListSlice = Root.ListSlice;
const Vec2 = Root.Vec2;
const AABB2 = Root.AABB2;
const MathX = Root.Math;
const Bezier = Root.Bezier;
const Cast = Root.Cast;
const ShapeModule = Root.Shape;
const Contour = ShapeModule.Contour;
const DataGridModule = Root.DataGrid;
const BitmapFormat = Root.FileFormat.Bitmap;
const PoolModule = Root.Pool;
const Shape = ShapeModule.Shape;
const AllocSource = Root.Allocator.AllocSource;

const AABB_i32 = AABB2.define_aabb2_type(i32);
const AABB_i16 = AABB2.define_aabb2_type(i16);
const AABB_f32 = AABB2.define_aabb2_type(f32);
const Vec_i16 = Vec2.define_vec2_type(i16);
const Vec_i32 = Vec2.define_vec2_type(i32);
const Vec_u32 = Vec2.define_vec2_type(u32);
const Vec_f32 = Vec2.define_vec2_type(f32);

const DEBUG = std.debug.print;
const DEBUG_VAL = Utils.DebugPrint.debug_val;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Cast.num_cast;
const read_int = std.mem.readInt;

const Vertex = Root.TrueType.Vertex;
const VertexListPool = Root.TrueType.VertexListPool;
const TrueTypeFont = Root.TrueType.TrueTypeFont;
const convert_vertex_list_to_shape = Root.TrueType.convert_vertex_list_to_shape;
const ShapedGlyphList = Root.TrueType.ShapedGlyphList;

test "TrueTypeFont -> load and render chars" {
    @setEvalBranchQuota(5000);
    const alloc = std.heap.smp_allocator;
    const OUT_DEF = DataGridModule.GridDefinition{
        .LIST_DEF = .{
            .ELEM = u8,
            .OWNERSHIP = .OWNED_ALLOCATED,
        },
        .ROW_COLUMN_ORDER = .ROW_MAJOR,
        .X_ORDER = .LEFT_TO_RIGHT,
        .Y_ORDER = .TOP_TO_BOTTOM,
    };
    const io = std.testing.io;
    const OUT_GRID = DataGridModule.DataGrid(OUT_DEF);
    const output_cells = OUT_GRID.CellList.allocate_new(4096, alloc);
    var vertex_list = List(Vertex).allocate_new(128, alloc);
    defer vertex_list.free(alloc);
    const VertexListPoolST = VertexListPool(.SINGLE_THREADED);
    var vertex_list_pool = VertexListPoolST.allocate_new(8, alloc);
    const PROTO = struct {
        fn free_vert_list(vert_list: *List(Vertex), vert_alloc: Allocator) void {
            vert_list.free(vert_alloc);
        }
        fn free_contour(contour: *Contour(f32, void, {}), contour_alloc: Allocator) void {
            contour.free(contour_alloc);
        }
    };
    defer vertex_list_pool.free_items_then_free_pool(Allocator, PROTO.free_vert_list, alloc);
    var shape = Shape(f32, void, {}).allocate_new(4, alloc);
    defer shape.free(alloc);
    const CHARS = [_]u32{ 'A', 'B', 'c', 'd', 'E', 'f', 'G', 'g', '&', 'ć' };
    const font_file = try std.Io.Dir.cwd().openFile(io, "vendor/fonts/Lato/Lato-Regular.ttf", .{});
    defer font_file.close(io);
    const font_file_stat = try font_file.stat(io);
    const font_file_len = font_file_stat.size;
    var font_file_buf = List(u8).allocate_new_set_len(@intCast(font_file_len), alloc);
    defer font_file_buf.free(alloc);
    font_file_buf.set_len(@intCast(font_file_len));
    _ = try font_file.readPositionalAll(io, font_file_buf.zig_slice_entire(), 0);
    var font: TrueTypeFont = try TrueTypeFont.load(font_file_buf.zig_slice_entire());
    try std.Io.Dir.cwd().createDirPath(io, "test_out/true_type");
    const scale_54_px = font.get_scale_for_pixel_height(54.0);
    const Rasterizer = Root.Shape.ASCA_Rasterizer.CellAccumulatorRasterizer(.{
        .ROW_COLUMN_ORDER = .ROW_MAJOR,
        .X_ORDER = .LEFT_TO_RIGHT,
        .Y_ORDER = .BOTTOM_TO_TOP,
    }, f32, u32, i32);
    const RasterOpts = Rasterizer.RasterOptions;
    const opts = RasterOpts{
        .tolerance = 0.1,
        .fill_rule = .EVEN_ODD,
    };
    var raster = Rasterizer.init_empty(alloc);
    defer raster.free();
    inline for (CHARS[0..]) |char| {
        const glyph_index = font.get_codepoint_glyph_index(char);
        try font.get_glyph_vertex_list(glyph_index, &vertex_list, alloc, .SINGLE_THREADED, &vertex_list_pool, alloc);
        try convert_vertex_list_to_shape(&vertex_list, f32, &shape, alloc);
        shape.scale(.new_splat(scale_54_px));
        var shape_aabb = shape.get_bounds_default_estimate();
        shape_aabb = shape_aabb.expand_by(2);
        const shape_shift_to_frame = shape_aabb.get_min_point().negate();
        shape.translate(shape_shift_to_frame);
        shape_aabb = shape_aabb.with_mins_shifted_to_zero();
        const shape_aabb_max = shape_aabb.get_max_point();
        const raster_size = Vec_u32.new(@intFromFloat(shape_aabb_max.x), @intFromFloat(shape_aabb_max.y));
        const grid_size = raster_size.add(.new_splat(3));
        const output_grid = OUT_GRID.init_repurpose_existing_cell_list(grid_size, 0, output_cells, alloc);
        const output_region = output_grid.get_entire_region();
        raster.clear_and_realloc(raster_size.x, raster_size.y);
        _ = try raster.rasterize_shape_to_grid(shape, opts, OUT_DEF, .existing_region(output_region, 0), 0, 255);
        _ = try BitmapFormat.save_bitmap_to_file("test_out/true_type/shape_raster_char_" ++ std.fmt.comptimePrint("{d}", .{char}) ++ ".bmp", OUT_DEF, output_grid, .{ .bits_per_pixel = .BPP_8 }, .NO_CONVERSION_NEEDED_ALPHA_BECOMES_COLOR_CHANNELS, alloc, io);
    }
    var text_shape_list = ShapedGlyphList.allocate_new(10, alloc);
    defer text_shape_list.free_if_non_zero(alloc);
    try font.layout_text_single_line("ABcdEfGg&ć", 2.0, .passed_allocator_interface(), &text_shape_list, alloc);
}
