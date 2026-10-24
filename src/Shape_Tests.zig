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
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Flags = Root.Flags;
const List = Root.ListSlice.ListAllocated;
const Slice = Root.ListSlice.SliceMutable;
const SliceConst = Root.ListSlice.SliceImmutable;
const Vec2 = Root.Vec2;
const Mat3x3 = Root.Matrix.Mat3x3;
const AABB2 = Root.AABB2;
const MathX = Root.Math;
const Bezier = Root.Bezier;
const DataGridModule = Root.DataGrid;
const DataGrid = Root.DataGrid.DataGrid;
const BitmapFormat = Root.FileFormat.Bitmap;

const SignedDistance = MathX.SignedDistance;
const SignedDistanceWithPercent = MathX.SignedDistanceWithPercent;
const ScanlineIntersections = MathX.ScanlineIntersections;
const LinearEstimate = MathX.LinearEstimate;
const QuadraticEstimate = MathX.QuadraticEstimate;
const DoubleRootEstimate = MathX.DoubleRootEstimate;
const FillRule = Root.CommonTypes.FillRule;

const ShapeModule = Root.Shape;

const EdgeWithUserdata = ShapeModule.EdgeWithUserdata;
const EdgeNoUserdata = ShapeModule.EdgeNoUserdata;
const EdgeColor = ShapeModule.EdgeColor;
const Contour = ShapeModule.Contour;
const Shape = ShapeModule.Shape;
const ScanlineRasterizer = ShapeModule.ScanlineRasterizer;
const CellAccumulatorRasterizer = ShapeModule.ASCA_Rasterizer;
const RasterOpts = CellAccumulatorRasterizer.RasterOptions;

fn make_test_triangle_with_edge_color(inner_edges: *[3]EdgeWithUserdata(f32, EdgeColor, .WHITE), outer_edges: *[3]EdgeWithUserdata(f32, EdgeColor, .WHITE), shapes: *[2]Contour(f32, EdgeColor, .WHITE)) Shape(f32, EdgeColor, .WHITE) {
    const Vec = Vec2.define_vec2_type(f32);
    const EdgeType = EdgeWithUserdata(f32, EdgeColor, .WHITE);
    const ShapeType = Contour(f32, EdgeColor, .WHITE);
    const CompositeShapeType = Shape(f32, EdgeColor, .WHITE);
    const A = Vec.new(2, 2);
    const B = Vec.new(27, 52);
    const C = Vec.new(52, 2);
    const AB: EdgeType = .new_line(A, B);
    const BC: EdgeType = .new_line(B, C);
    const CA: EdgeType = .new_line(C, A);
    outer_edges[0] = AB;
    outer_edges[1] = BC;
    outer_edges[2] = CA;
    const AA = Vec.new(10, 6);
    const BB = Vec.new(27, 42);
    const CC = Vec.new(44, 6);
    const AACC: EdgeType = .new_line(AA, CC);
    const CCBB: EdgeType = .new_line(CC, BB);
    const BBAA: EdgeType = .new_line(BB, AA);
    inner_edges[0] = AACC;
    inner_edges[1] = CCBB;
    inner_edges[2] = BBAA;
    shapes[0] = ShapeType{
        .edges = .from_slice_keep_data(outer_edges[0..3]),
    };
    shapes[1] = ShapeType{
        .edges = .from_slice_keep_data(inner_edges[0..3]),
    };
    return CompositeShapeType{
        .contours = .from_slice_keep_data(shapes[0..2]),
    };
}

fn make_test_triangle_no_userdata(inner_edges: *[3]EdgeWithUserdata(f32, void, {}), outer_edges: *[3]EdgeWithUserdata(f32, void, {}), shapes: *[2]Contour(f32, void, {})) Shape(f32, void, {}) {
    const Vec = Vec2.define_vec2_type(f32);
    const EdgeType = EdgeWithUserdata(f32, void, {});
    const ShapeType = Contour(f32, void, {});
    const CompositeShapeType = Shape(f32, void, {});
    const A = Vec.new(2, 2);
    const B = Vec.new(27, 52);
    const C = Vec.new(52, 2);
    const AB: EdgeType = .new_line(A, B);
    const BC: EdgeType = .new_line(B, C);
    const CA: EdgeType = .new_line(C, A);
    outer_edges[0] = AB;
    outer_edges[1] = BC;
    outer_edges[2] = CA;
    const AA = Vec.new(10, 6);
    const BB = Vec.new(27, 42);
    const CC = Vec.new(44, 6);
    const AACC: EdgeType = .new_line(AA, CC);
    const CCBB: EdgeType = .new_line(CC, BB);
    const BBAA: EdgeType = .new_line(BB, AA);
    inner_edges[0] = AACC;
    inner_edges[1] = CCBB;
    inner_edges[2] = BBAA;
    shapes[0] = ShapeType{
        .edges = .from_slice_keep_data(outer_edges[0..3]),
    };
    shapes[1] = ShapeType{
        .edges = .from_slice_keep_data(inner_edges[0..3]),
    };
    return CompositeShapeType{
        .contours = .from_slice_keep_data(shapes[0..2]),
    };
}

test "Shape -> Scanline Rasterized Triangle" {
    const OUT_DEF = DataGridModule.GridDefinition{
        .LIST_DEF = .{
            .ELEM = u8,
            .OWNERSHIP = .OWNED_ALLOCATED,
        },
        .ROW_COLUMN_ORDER = .ROW_MAJOR,
        .X_ORDER = .LEFT_TO_RIGHT,
        .Y_ORDER = .TOP_TO_BOTTOM,
    };
    const alloc = std.heap.page_allocator;
    const OUT_GRID = DataGrid(OUT_DEF);
    const Raster = ScanlineRasterizer(f32, EdgeColor, .WHITE, i8, OUT_DEF);
    var raster = Raster.init_with_intersection_capacity(8, alloc);
    defer raster.free(alloc);
    var output_grid = OUT_GRID.allocate_new(54, 54, 0, alloc);
    defer output_grid.free(alloc);
    var inner: [3]EdgeWithUserdata(f32, EdgeColor, .WHITE) = undefined;
    var outer: [3]EdgeWithUserdata(f32, EdgeColor, .WHITE) = undefined;
    var shapes: [2]Contour(f32, EdgeColor, .WHITE) = undefined;
    const io = std.testing.io;
    var triangle = make_test_triangle_with_edge_color(&inner, &outer, &shapes);
    // triangle.apply_complex_transform(&.{.skew_from_origin_x_degrees(20)});
    try std.Io.Dir.cwd().createDirPath(io, "test_out/shape");
    raster.rasterize_to_existing_data_grid_default_lerp(&triangle, .NONE, output_grid, 0, 255, .default_estimates(), alloc);
    _ = try BitmapFormat.save_bitmap_to_file("test_out/shape/triangle_hard_no_antialias.bmp", OUT_DEF, output_grid, .{ .bits_per_pixel = .BPP_8 }, .NO_CONVERSION_NEEDED_ALPHA_BECOMES_COLOR_CHANNELS, alloc, io);
    output_grid.fill_all(0);
    raster.rasterize_to_existing_data_grid_default_lerp(&triangle, .X_ONLY_LINEAR_FALLOFF, output_grid, 0, 255, .default_estimates(), alloc);
    _ = try BitmapFormat.save_bitmap_to_file("test_out/shape/triangle_hard_antialias_x_linear.bmp", OUT_DEF, output_grid, .{ .bits_per_pixel = .BPP_8 }, .NO_CONVERSION_NEEDED_ALPHA_BECOMES_COLOR_CHANNELS, alloc, io);
    output_grid.fill_all(0);
    raster.rasterize_to_existing_data_grid_default_lerp(&triangle, .X_ONLY_EXPONENTIAL_FALLOFF, output_grid, 0, 255, .default_estimates(), alloc);
    _ = try BitmapFormat.save_bitmap_to_file("test_out/shape/triangle_hard_antialias_x_exponential.bmp", OUT_DEF, output_grid, .{ .bits_per_pixel = .BPP_8 }, .NO_CONVERSION_NEEDED_ALPHA_BECOMES_COLOR_CHANNELS, alloc, io);
}

test "Shape -> Analytical Cell/Span Accumulator Rasterized Triangle" {
    const alloc = std.testing.allocator;

    const OUT_DEF = DataGridModule.GridDefinition{
        .LIST_DEF = .{
            .ELEM = u8,
            .OWNERSHIP = .OWNED_ALLOCATED,
        },
        .ROW_COLUMN_ORDER = .ROW_MAJOR,
        .X_ORDER = .LEFT_TO_RIGHT,
        .Y_ORDER = .TOP_TO_BOTTOM,
    };
    const OUT_GRID = DataGrid(OUT_DEF);
    var output_grid = OUT_GRID.allocate_new(54, 54, 0, alloc);
    defer output_grid.free(alloc);

    var inner: [3]EdgeWithUserdata(f32, void, {}) = undefined;
    var outer: [3]EdgeWithUserdata(f32, void, {}) = undefined;
    var shapes: [2]Contour(f32, void, {}) = undefined;
    const triangle = make_test_triangle_no_userdata(&inner, &outer, &shapes);

    const Rasterizer = CellAccumulatorRasterizer.CellAccumulatorRasterizer(.{
        .ROW_COLUMN_ORDER = .ROW_MAJOR,
        .X_ORDER = .LEFT_TO_RIGHT,
        .Y_ORDER = .BOTTOM_TO_TOP,
    }, f32, u32, i32);
    var raster = Rasterizer.init_empty(alloc);
    defer raster.free();

    raster.clear_and_resize(output_grid.width, output_grid.height, null);

    const opts = RasterOpts{
        .tolerance = 0.1,
        .fill_rule = .EVEN_ODD, // inner and outer contours create a hollow shape
        .coord_origin = .BOT_LEFT,
    };
    // Accumulate all contour edges
    raster.rasterize_shape(triangle, opts);

    _ = try raster.write_to_grid(OUT_DEF, .existing_data_grid(.{ .data_grid = output_grid }, 0), 0, 255, opts);

    // Save to file or inspect
    const io = std.testing.io;
    try std.Io.Dir.cwd().createDirPath(io, "test_out/shape");
    _ = try Root.FileFormat.Bitmap.save_bitmap_to_file(
        "test_out/shape/triangle_accumulator_aa.bmp",
        OUT_DEF,
        output_grid,
        .{ .bits_per_pixel = .BPP_8 },
        .NO_CONVERSION_NEEDED_ALPHA_BECOMES_COLOR_CHANNELS,
        alloc,
        io,
    );
}
