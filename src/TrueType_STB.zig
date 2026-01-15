//! Zig bindings for stb_truetype.h
//!
//! #### License FOR THE CODE IN THIS SOURCE FILE (Bindings): Zlib
//! #### License for stb_truetype.h: MIT or Public Domain (https://github.com/nothings/stb/blob/master/LICENSE)

/// #### stb_truetype.h: MIT or Public Domain (https://github.com/nothings/stb/blob/master/LICENSE)
///
/// This software is available under 2 licenses -- choose whichever you prefer.
///
/// ------------------------------------------------------------------------------
/// ALTERNATIVE A - MIT License
///
/// Copyright (c) 2017 Sean Barrett
/// Permission is hereby granted, free of charge, to any person obtaining a copy of
/// this software and associated documentation files (the "Software"), to deal in
/// the Software without restriction, including without limitation the rights to
/// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
/// of the Software, and to permit persons to whom the Software is furnished to do
/// so, subject to the following conditions:
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.
///
/// ------------------------------------------------------------------------------
/// ALTERNATIVE B - Public Domain (www.unlicense.org)
///
/// This is free and unencumbered software released into the public domain.
/// Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
/// software, either in source code form or as a compiled binary, for any purpose,
/// commercial or non-commercial, and by any means.
/// In jurisdictions that recognize copyright laws, the author or authors of this
/// software dedicate any and all copyright interest in the software to the public
/// domain. We make this dedication for the benefit of the public at large and to
/// the detriment of our heirs and successors. We intend this dedication to be an
/// overt act of relinquishment in perpetuity of all present and future rights to
/// this software under copyright law.
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
/// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
/// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
const std = @import("std");
const math = std.math;

const Root = @import("./_root.zig");
const SliceAdapter = Root.IList_SliceAdapter;
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const C_Allocator = Root.C_Allocator;
const DummyAllocator = Root.DummyAllocator;
const Flags = Root.Flags;
const IList = Root.IList.IList;
const List = Root.IList_List.List;
const Vec2 = Root.Vec2;
const Mat3x3 = Root.Mat3x3;
const AABB2 = Root.AABB2;
const MathX = Root.Math;
const ShapeModule = Root.Shape;
const Contour = ShapeModule.Contour;
const Shape = ShapeModule.Shape;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;
pub const C = @cImport({
    @cInclude("stb_truetype.h");
});

pub var stb_malloc_concrete: *const fn (usize, ?*anyopaque) callconv(.c) ?*anyopaque = C_Allocator.PageAllocatorWrapperFuncsUserdataNoop.malloc;
pub var stb_free_concrete: *const fn (?*anyopaque, ?*anyopaque) callconv(.c) void = C_Allocator.PageAllocatorWrapperFuncsUserdataNoop.free;

pub export fn stbtt_malloc(size: usize, userdata: ?*anyopaque) callconv(.c) ?*anyopaque {
    return stb_malloc_concrete(size, userdata);
}
pub export fn stbtt_free(size: usize, userdata: ?*anyopaque) callconv(.c) ?*anyopaque {
    return stb_malloc_concrete(size, userdata);
}

pub const FontInitError = error{
    failed_to_initialize_font,
};
pub const FontFileFontInitError = error{
    font_index_invalid_for_font_file,
    failed_to_initialize_font,
};
pub const FindCodepointError = error{
    codepoint_not_supplied_by_font,
};
pub const FindGlyphError = error{
    glyph_offset_invalid,
};
pub const GlyphVertexError = error{
    could_not_get_glyph_vertexes,
};
pub const FontIndexError = error{
    font_index_invalid_for_font_file,
};

pub const Vertex = C.stbtt_vertex;

pub const GlyphMetricsHorizontal = struct {
    left_bearing: f32,
    advance_width: f32,
};

pub const GlyphIndex = struct {
    idx: c_int = -1,

    pub inline fn new(idx: c_int) GlyphIndex {
        return GlyphIndex{ .idx = idx };
    }
};

pub const AABB = AABB2.define_aabb2_type(f32);

pub const TABLE_RECORD_SIZE = 16;

pub const FontFileData = struct {
    data: [*]const u8,

    pub fn new(mem: []const u8) FontFileData {
        return FontFileData{ .data = mem.ptr };
    }

    pub fn get_number_of_fonts(self: FontFileData) c_int {
        return C.stbtt_GetNumberOfFonts(@ptrCast(self.data));
    }

    pub fn get_font_data_offset_by_font_index(self: FontFileData, index: c_int) FontIndexError!c_int {
        const offset = C.stbtt_GetFontOffsetForIndex(@ptrCast(self.data), index);
        if (offset < 0) return FontIndexError.font_index_invalid_for_font_file;
        return offset;
    }

    pub fn init_font_by_index(self: FontFileData, index: c_int) FontFileFontInitError!FontInfo {
        const offset = self.get_font_data_offset_by_font_index(index) catch |err| return @errorCast(err);
        const info = FontInfo.init(self.data + num_cast(offset, usize)) catch |err| return @errorCast(err);
        return info;
    }
};

pub const FontInfo = struct {
    info: C.stbtt_fontinfo,

    pub fn init(data: [*]const u8) FontInitError!FontInfo {
        var info: C.stbtt_fontinfo = undefined;
        const e = C.stbtt_InitFont(@ptrCast(&info), @ptrCast(data), 0);
        if (e == 0) return FontInitError.failed_to_initialize_font;
        return FontInfo{
            .info = info,
        };
    }

    pub fn free_vertex_list(self: *FontInfo, vertex_list: []Vertex) void {
        C.stbtt_FreeShape(@ptrCast(self), @ptrCast(vertex_list.ptr));
    }

    pub fn get_codepoint_glyph_index(self: *FontInfo, utf8_codepoint: u32) FindCodepointError!GlyphIndex {
        const result: c_int = C.stbtt_FindGlyphIndex(@ptrCast(&self.info), @intCast(utf8_codepoint));
        if (result == 0) return FindCodepointError.codepoint_not_supplied_by_font;
        return GlyphIndex.new(result);
    }

    pub fn get_glyph_vertex_list(self: *FontInfo, glyph_index: GlyphIndex) GlyphVertexError![]Vertex {
        var vertex_ptr: [*c]Vertex = undefined;
        const vertex_count = C.stbtt_GetGlyphShape(@ptrCast(self), glyph_index.idx, @ptrCast(&vertex_ptr));
        if (vertex_ptr == null) return GlyphVertexError.could_not_get_glyph_vertexes;
        return @as([*]Vertex, @ptrCast(vertex_ptr))[0..vertex_count];
    }

    pub fn get_glyph_metrics_horizontal(self: *FontInfo, glyph_index: GlyphIndex) GlyphMetricsHorizontal {
        var advance: c_int = 0;
        var bearing: c_int = 0;
        C.stbtt_GetGlyphHMetrics(@ptrCast(self), glyph_index.idx, @ptrCast(&advance), @ptrCast(&bearing));
        return GlyphMetricsHorizontal{
            .advance_width = @floatFromInt(advance),
            .left_bearing = @floatFromInt(bearing),
        };
    }

    pub fn get_glyph_kern_horizontal(self: *FontInfo, glyph_index_left: GlyphIndex, glyph_index_right: GlyphIndex) f32 {
        return @floatFromInt(C.stbtt_GetGlyphKernAdvance(@ptrCast(self), glyph_index_left.idx, glyph_index_right.idx));
    }
};

pub const VERTEX_KIND = struct {
    const MOVE_TO: u8 = @intCast(C.STBTT_vmove);
    const LINE: u8 = @intCast(C.STBTT_vline);
    const QUADRATIC: u8 = @intCast(C.STBTT_vcurve);
    const CUBIC: u8 = @intCast(C.STBTT_vcubic);
};


pub fn convert_vertex_list_to_new_shape_with_userdata(vertex_list: []Vertex, comptime T: type, comptime EDGE_USERDATA: type, comptime EDGE_USERDATA_DEFAULT: EDGE_USERDATA, shape_allocator: Allocator) ShapeConvertError!Shape(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT) {
    var shape = Shape(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT).init_capacity(2, shape_allocator);
    try convert_vertex_list_to_shape(vertex_list, T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT, &shape, shape_allocator);
    return shape;
}

pub fn convert_vertex_list_to_new_shape(vertex_list: []Vertex, comptime T: type, shape_allocator: Allocator) ShapeConvertError!Shape(T, void, void{}) {
    return convert_vertex_list_to_new_shape_with_userdata(vertex_list, T, void, void{}, shape_allocator);
}

pub fn convert_vertex_list_to_shape(vertex_list: []Vertex, comptime T: type, shape: *Shape(T, void, void{}), shape_allocator: Allocator) ShapeConvertError!void {
    return convert_vertex_list_to_shape_with_userdata(vertex_list, T, void, void{}, shape, shape_allocator);
}

pub fn convert_vertex_list_to_shape_with_userdata(vertex_list: []Vertex, comptime T: type, comptime EDGE_USERDATA: type, comptime EDGE_USERDATA_DEFAULT: EDGE_USERDATA, shape: *Shape(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT), shape_allocator: Allocator) ShapeConvertError!void {
    const VEC = Vec2.define_vec2_type(T);
    const EDGE = ShapeModule.EdgeWithUserdata(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT);
    const CONTOUR = Contour(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT);
    var incomplete_edge: EDGE = .new_point(.ZERO_ZERO);
    var started_a_contour: bool = false;
    var first_point_in_contour: VEC = .ZERO_ZERO;
    var curr_contour: CONTOUR = .init_capacity(8, shape_allocator);
    shape.clear(shape_allocator);
    for (vertex_list) |vert| {
        const point = VEC.new_from_any(vert.x, vert.y);
        switch (vert.type) {
            VERTEX_KIND.MOVE_TO => {
                if (started_a_contour) {
                    started_a_contour = false;
                    switch (incomplete_edge.edge) {
                        .POINT => {},
                        .LINE => |*line| {
                            line.p[1] = first_point_in_contour;
                        },
                        .QUADRATIC_BEZIER => |*bezier| {
                            bezier.p[2] = first_point_in_contour;
                        },
                        .CUBIC_BEZIER => |*bezier| {
                            bezier.p[3] = first_point_in_contour;
                        },
                    }
                    curr_contour.append_edge(incomplete_edge, shape_allocator);
                    shape.append_contour(curr_contour, shape_allocator);
                    curr_contour = .init_capacity(8, shape_allocator);
                    first_point_in_contour = .ZERO_ZERO;
                }
            },
            VERTEX_KIND.LINE => {
                if (started_a_contour) {
                    switch (incomplete_edge.edge) {
                        .POINT => {},
                        .LINE => |*line| {
                            line.p[1] = point;
                        },
                        .QUADRATIC_BEZIER => |*bezier| {
                            bezier.p[2] = point;
                        },
                        .CUBIC_BEZIER => |*bezier| {
                            bezier.p[3] = point;
                        },
                    }
                    curr_contour.append_edge(incomplete_edge, shape_allocator);
                } else {
                    first_point_in_contour = point;
                }
                incomplete_edge = .new_line(point, point);
            },
            VERTEX_KIND.QUADRATIC => {
                if (started_a_contour) {
                    switch (incomplete_edge.edge) {
                        .POINT => {},
                        .LINE => |*line| {
                            line.p[1] = point;
                        },
                        .QUADRATIC_BEZIER => |*bezier| {
                            bezier.p[2] = point;
                        },
                        .CUBIC_BEZIER => |*bezier| {
                            bezier.p[3] = point;
                        },
                    }
                    curr_contour.append_edge(incomplete_edge, shape_allocator);
                } else {
                    first_point_in_contour = point;
                }
                const control = VEC.new_from_any(vert.cx, vert.cy);
                incomplete_edge = .new_quadratic_bezier(point, control, control);
            },
            VERTEX_KIND.CUBIC => {
                if (started_a_contour) {
                    switch (incomplete_edge.edge) {
                        .POINT => {},
                        .LINE => |*line| {
                            line.p[1] = point;
                        },
                        .QUADRATIC_BEZIER => |*bezier| {
                            bezier.p[2] = point;
                        },
                        .CUBIC_BEZIER => |*bezier| {
                            bezier.p[3] = point;
                        },
                    }
                    curr_contour.append_edge(incomplete_edge, shape_allocator);
                } else {
                    first_point_in_contour = point;
                }
                const control_1 = VEC.new_from_any(vert.cx, vert.cy);
                const control_2 = VEC.new_from_any(vert.cx1, vert.cy1);
                incomplete_edge = .new_cubic_bezier(point, control_1, control_2, control_2);
            },
            else => return ShapeConvertError.invalid_vertex_type,
        }
    }
}

pub const ShapeConvertError = error{
    invalid_vertex_type,
};

test "TyueType_STB__Lato-Regular.ttf" {
    const Test = Root.Testing;
    const data = try Utils.File.load_entire_file("./vendor/fonts/Lato/Lato-Regular.ttf", .{});
    defer data.free_all(std.heap.page_allocator);
    const file_data = FontFileData.new(data.data);
    var font_info = try file_data.init_font_by_index(0);
    const CHARS_TO_CHECK = "The quick brown fox jumped over the lazy brown dog. %&@";
    for (CHARS_TO_CHECK[0..]) |char| {
        const index = try font_info.get_codepoint_glyph_index(@intCast(char));
        const metrics = font_info.get_glyph_metrics_horizontal(index);
        try Test.expect_greater_than(metrics.advance_width, "metrics.advance_width", 0, "0", "all characters to check should have a positive 'advance width', but got 0 for char '{c}'", .{char});
    }
}
