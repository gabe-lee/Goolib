//! Provides the ability to read TrueType .ttf files and rasterize glyphs
//!
//! This is largely a conversion of `https://codeberg.org/andrewrk/TrueType`,
//! which is itself a translation of `https://github.com/nothings/stb/blob/master/stb_truetype.h`
//! from C to Zig.
//!
//! Most (if not all) of the code __logic__ remains unchanged from `https://codeberg.org/andrewrk/TrueType`,
//! except that many function signatures and return types, error tags, enum tags, struct types are altered
//! to more closely align with Goolib's conventions and integrate with Goolib's native Vec2,
//! AABB, DataGrid/Bitmap, Shape, List, etc. types
//!
//! The chain of licenses from the original onward are listed below,
//!
//! If this portion of the Goolib library is usefull to you, PLEASE support the original
//! projects. I'm standing on the shoulders of giants here.
//!
//! ### Original License (https://github.com/nothings/stb/blob/master/stb_truetype.h): MIT or Public Domain:
//! This software is available under 2 licenses -- choose whichever you prefer.
//!
//! ------------------------------------------------------------------------------
//!
//! ALTERNATIVE A - MIT License
//!
//! Copyright (c) 2017 Sean Barrett
//!
//! Permission is hereby granted, free of charge, to any person obtaining a copy of
//! this software and associated documentation files (the "Software"), to deal in
//! the Software without restriction, including without limitation the rights to
//! use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//! of the Software, and to permit persons to whom the Software is furnished to do
//! so, subject to the following conditions:
//! The above copyright notice and this permission notice shall be included in all
//! copies or substantial portions of the Software.
//! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//! AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//! OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//! SOFTWARE.
//!
//! ------------------------------------------------------------------------------
//!
//! ALTERNATIVE B - Public Domain (www.unlicense.org)
//!
//! This is free and unencumbered software released into the public domain.
//! Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
//! software, either in source code form or as a compiled binary, for any purpose,
//! commercial or non-commercial, and by any means.
//! In jurisdictions that recognize copyright laws, the author or authors of this
//! software dedicate any and all copyright interest in the software to the public
//! domain. We make this dedication for the benefit of the public at large and to
//! the detriment of our heirs and successors. We intend this dedication to be an
//! overt act of relinquishment in perpetuity of all present and future rights to
//! this software under copyright law.
//! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//! AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//! ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//! WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//! ### License (https://codeberg.org/andrewrk/TrueType): MIT
//! The MIT License (Expat)
//!
//! Copyright (c) contributors
//!
//! Permission is hereby granted, free of charge, to any person obtaining a copy
//! of this software and associated documentation files (the "Software"), to deal
//! in the Software without restriction, including without limitation the rights
//! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//! copies of the Software, and to permit persons to whom the Software is
//! furnished to do so, subject to the following conditions:
//!
//! The above copyright notice and this permission notice shall be included in
//! all copies or substantial portions of the Software.
//!
//! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//! AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//! OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//! THE SOFTWARE.
//!
//! ### License (Goolib): ZLib
//! zlib license
//!
//! Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
//!
//! This software is provided 'as-is', without any express or implied
//! warranty. In no event will the authors be held liable for any damages
//! arising from the use of this software.
//!
//! Permission is granted to anyone to use this software for any purpose,
//! including commercial applications, and to alter it and redistribute it
//! freely, subject to the following restrictions:
//!
//! 1. The origin of this software must not be misrepresented; you must not
//!    claim that you wrote the original software. If you use this software
//!    in a product, an acknowledgment in the product documentation would be
//!    appreciated but is not required.
//! 2. Altered source versions must be plainly marked as such, and must not be
//!    misrepresented as being the original software.
//! 3. This notice may not be removed or altered from any source distribution.

const std = @import("std");
const build = @import("builtin");
const math = std.math;
const Root = @import("./_root.zig");
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const List = Root.ListSlice.ListAllocated;
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

const AABB_i32 = AABB2.define_aabb2_type(i32);
const AABB_i16 = AABB2.define_aabb2_type(i16);
const Vec_i16 = Vec2.define_vec2_type(i16);
const Vec_i32 = Vec2.define_vec2_type(i32);
const Vec_u32 = Vec2.define_vec2_type(u32);
const Vec_f32 = Vec2.define_vec2_type(f32);

const DEBUG = std.debug.print;
const DEBUG_VAL = Utils.DebugPrint.debug_val;

pub fn VertexListPool(comptime THREADING: Root.CommonTypes.ThreadingMode) type {
    return PoolModule.Pool(.{
        .LIST_DEF = .{
            .ELEM = List(Vertex),
            .IDX = u32,
            .OWNERSHIP = .OWNED_ALLOCATED,
        },
        .BLOCK_SIZE = 8,
        .THREADING = THREADING,
    }, .{});
}
pub fn ContourPool(comptime T: type, comptime EDGE_USERDATA: type, comptime EDGE_USERDATA_DEFAULT_VALUE: EDGE_USERDATA, comptime THREADING: Root.CommonTypes.ThreadingMode) type {
    return PoolModule.Pool(Contour(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT_VALUE), .{}, u32, 8, THREADING);
}
const DATA_GRID_U8_DEF = DataGridModule.GridDefinition{
    .CELL_TYPE = u8,
};
const DataGrid_u8 = DataGridModule.DataGrid(DATA_GRID_U8_DEF);

pub const ShapedGlyph = struct {
    codepoint: u32,
    x_advance: f32,
    glyph_idx: GlyphIndex,
};

pub const ShapedGlyphList = List(ShapedGlyph);

// pub const VertexList = List(Vertex);

/// Direct C bindings for stb_truetype.h
// pub const STB_TrueTypeFont = @import("./TrueTypeFont_STB.zig");

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Cast.num_cast;
const read_int = std.mem.readInt;

pub const GlyphIndex = enum(u16) {
    NOT_DEFINED = 0,
    _,
};

pub const TableId = enum(u32) {
    cmap = 0, // 'cmap'
    loca = 1, // 'loca'
    head = 2, // 'head'
    glyf = 3, // 'glyf'
    hhea = 4, // 'hhea'
    hmtx = 5, // 'hmtx'
    kern = 6, // 'kern'
    GPOS = 7, // 'GPOS'
    maxp = 8, // 'maxp'
    CFF_ = 9, // 'CFF '

    const TAG = [_]u32{
        0x636D6170, // 'cmap'
        0x6C6F6361, // 'loca'
        0x68656164, // 'head'
        0x676C7966, // 'glyf'
        0x68686561, // 'hhea'
        0x686D7478, // 'hmtx'
        0x6B65726E, // 'kern'
        0x47504F53, // 'GPOS'
        0x6D617870, // 'maxp'
        0x43464620, // 'CFF '
    };
    const NUM_TABLES = 9;

    inline fn tag(id: TableId) u32 {
        return TAG[@backingInt(id)];
    }
    inline fn idx(id: TableId) u32 {
        return @backingInt(id);
    }
};

const PlatformId = enum(u16) {
    UNICODE = 0,
    MAC = 1,
    ISO = 2,
    MICROSOFT = 3,
};

const MicrosoftEncodingId = enum(u16) {
    SYMBOL = 0,
    UNICODE_BMP = 1,
    SHIFTJIS = 2,
    UNICODE_FULL = 10,
};

pub const VerticalMetrics = struct {
    /// The coordinate above the baseline the font extends.
    ascent: i16,
    /// The coordinate below the baseline the font extends (typically negative).
    descent: i16,
    /// The spacing between one row's descent and the next row's ascent.
    line_gap: i16,
};

pub const HorizontalMetrics = struct {
    /// The offset from the current horizontal position to the next horizontal
    /// position in unscaled coordinates.
    advance_width: i16,
    /// The offset from the current horizontal position to the left edge of the
    /// character in unscaled coordinates.
    left_side_bearing: i16,
};

pub const GlyphBitmapError = error{
    could_not_obtain_bitmap_from_source,
    glyph_not_found,
    unimplemented,
    r_move_to_stack,
    v_move_to_stack,
    h_move_to_stack,
    r_line_to_stack,
    v_line_to_stack,
    h_line_to_stack,
    h_curve_to_stack,
    r_curve_to_stack,
    r_curve_line_stack,
    curve_line_stack,
    r_line_curve_stack,
    call_global_subroutines_stack,
    recursion_limit,
    subroutine_not_found,
    return_outside_subroutine,
    h_flex_stack,
    flex_stack,
    h_flex_1_stack,
    flex_1_stack,
    curve_to_stack,
    reserved_operator,
    push_stack_overflow,
    no_end_char,
};

pub const Vertex = struct {
    x: i16,
    y: i16,
    cx: i16,
    cy: i16,
    cx1: i16,
    cy1: i16,
    type: Type,

    pub const Type = enum(u8) {
        MOVE_TO = 1,
        LINE = 2,
        QUADRATIC = 3,
        CUBIC = 4,
        _,
    };

    fn set(v: *Vertex, ty: Type, x: i32, y: i32, cx: i32, cy: i32) void {
        v.type = ty;
        v.x = @intCast(x);
        v.y = @intCast(y);
        v.cx = @intCast(cx);
        v.cy = @intCast(cy);
    }
};

pub const Point_f32 = Vec2.define_vec2_type(f32);

const Edge = struct {
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    invert: bool,

    pub fn y0_less_than(a: Edge, b: Edge) bool {
        return a.y0 < b.y0;
    }
};

const CharstringFlags = packed struct(u8) {
    started: bool = false,
    mode: enum(u1) {
        /// set min/max and num_vertices
        bounds,
        /// set vertices and num_vertices
        verts,
    },
    _padding: u6 = undefined,
};

pub const TrueTypeFont = struct {
    table_offsets: [TableId.NUM_TABLES]u32,
    ttf_bytes: []const u8,
    index_map: u32,
    index_to_loc_format: u16,
    glyphs_len: u32,
    cff_data: CffData,

    pub fn load(bytes: []const u8) !TrueTypeFont {
        // Find tables.
        var table_offsets: [TableId.NUM_TABLES]u32 = @splat(0);
        const tables_len = read_int(u16, bytes[4..][0..2], .big);
        var cff: u32 = 0;
        for (0..tables_len) |i| {
            const loc = 12 + 16 * i;
            const tag = read_int(u32, bytes[loc..][0..4], .big);
            const table_index: u32 = switch (tag) {
                TableId.cmap.tag() => TableId.cmap.idx(),
                TableId.loca.tag() => TableId.loca.idx(),
                TableId.head.tag() => TableId.head.idx(),
                TableId.glyf.tag() => TableId.glyf.idx(),
                TableId.hhea.tag() => TableId.hhea.idx(),
                TableId.hmtx.tag() => TableId.hmtx.idx(),
                TableId.kern.tag() => TableId.kern.idx(),
                TableId.GPOS.tag() => TableId.GPOS.idx(),
                TableId.maxp.tag() => TableId.maxp.idx(),
                TableId.CFF_.tag() => {
                    cff = read_int(u32, bytes[loc + 8 ..][0..4], .big);
                    continue;
                },
                else => continue,
            };
            table_offsets[table_index] = read_int(u32, bytes[loc + 8 ..][0..4], .big);
        }

        if (table_offsets[TableId.cmap.idx()] == 0) return error.missing_required_table;
        if (table_offsets[TableId.head.idx()] == 0) return error.missing_required_table;
        if (table_offsets[TableId.hhea.idx()] == 0) return error.missing_required_table;
        if (table_offsets[TableId.hmtx.idx()] == 0) return error.missing_required_table;

        var cff_data: CffData = .empty;

        if (table_offsets[TableId.glyf.idx()] != 0) {
            if (table_offsets[TableId.loca.idx()] == 0) return error.missing_required_table;
        } else {
            if (cff == 0) return error.missing_required_table;
            cff_data = try .init(cff, bytes.ptr);
        }

        const maxp = table_offsets[TableId.maxp.idx()];
        const glyphs_len = if (maxp == 0) 0xffff else read_int(u16, bytes[maxp + 4 ..][0..2], .big);

        const cmap = table_offsets[TableId.cmap.idx()];
        const cmap_tables_len = read_int(u16, bytes[cmap + 2 ..][0..2], .big);
        const index_map = find_index_map: {
            var i = cmap_tables_len;
            while (true) {
                i -= 1;
                if (i == 0) return error.index_map_missing;
                const encoding_record = cmap + 4 + 8 * i;
                const platform_id = read_int(u16, bytes[encoding_record..][0..2], .big);
                switch (platform_id) {
                    @backingInt(PlatformId.MICROSOFT) => switch (read_int(u16, bytes[encoding_record + 2 ..][0..2], .big)) {
                        @backingInt(MicrosoftEncodingId.UNICODE_BMP),
                        @backingInt(MicrosoftEncodingId.UNICODE_FULL),
                        => {
                            break :find_index_map cmap + read_int(u32, bytes[encoding_record + 4 ..][0..4], .big);
                        },
                        else => continue,
                    },
                    @backingInt(PlatformId.UNICODE) => {
                        break :find_index_map cmap + read_int(u32, bytes[encoding_record + 4 ..][0..4], .big);
                    },
                    else => continue,
                }
            }
        };

        const head = table_offsets[TableId.head.idx()];
        const index_to_loc_format = read_int(u16, bytes[head + 50 ..][0..2], .big);

        return .{
            .table_offsets = table_offsets,
            .ttf_bytes = bytes,
            .index_map = index_map,
            .index_to_loc_format = index_to_loc_format,
            .glyphs_len = glyphs_len,
            .cff_data = cff_data,
        };
    }

    pub fn get_codepoint_glyph_index(self: *const TrueTypeFont, codepoint: u32) GlyphIndex {
        const bytes = self.ttf_bytes;
        const index_map = self.index_map;
        const format = read_int(u16, bytes[index_map..][0..2], .big);
        switch (format) {
            0 => {
                const n = read_int(u16, bytes[index_map + 2 ..][0..2], .big);
                if (codepoint < n - 6)
                    return @fromBackingInt(@intCast(bytes[index_map + 6 + codepoint]));

                return .NOT_DEFINED;
            },
            2 => {
                return .NOT_DEFINED;
            },
            4 => {
                const seg_count = read_int(u16, bytes[index_map + 6 ..][0..2], .big) >> 1;
                var search_range = read_int(u16, bytes[index_map + 8 ..][0..2], .big) >> 1;
                var entry_selector = read_int(u16, bytes[index_map + 10 ..][0..2], .big);
                const range_shift = read_int(u16, bytes[index_map + 12 ..][0..2], .big) >> 1;

                // Do a binary search of the segments.
                const end_count = index_map + 14;
                var search = end_count;

                if (codepoint > 0xffff)
                    return .NOT_DEFINED;

                // They lie from end_count .. end_count + seg_count but search_range
                // is the nearest power of two.
                if (codepoint >= read_int(u16, bytes[search + range_shift * 2 ..][0..2], .big))
                    search += range_shift * 2;

                // Now decrement to bias correctly to find smallest.
                search -= 2;
                while (entry_selector > 0) {
                    search_range >>= 1;
                    const end = read_int(u16, bytes[search + search_range * 2 ..][0..2], .big);
                    if (codepoint > end)
                        search += search_range * 2;
                    entry_selector -= 1;
                }
                search += 2;

                const item: u16 = @intCast((search - end_count) >> 1);

                const start = read_int(u16, bytes[index_map + 14 + seg_count * 2 + 2 + 2 * item ..][0..2], .big);
                const last = read_int(u16, bytes[end_count + 2 * item ..][0..2], .big);
                if (codepoint < start or codepoint > last)
                    return .NOT_DEFINED;

                const offset = read_int(u16, bytes[index_map + 14 + seg_count * 6 + 2 + 2 * item ..][0..2], .big);
                if (offset == 0) {
                    const result = num_cast(codepoint, i32) + read_int(i16, bytes[index_map + 14 + seg_count * 4 + 2 + 2 * item ..][0..2], .big);
                    // truncate to u16
                    return @fromBackingInt(@intCast(@as(u16, @truncate(@as(u32, @bitCast(result))))));
                }

                return @fromBackingInt(@intCast(read_int(u16, bytes[offset + (codepoint - start) * 2 + index_map + 14 + seg_count * 6 + 2 + 2 * item ..][0..2], .big)));
            },
            6 => {
                const first = read_int(u16, bytes[index_map + 6 ..][0..2], .big);
                const count = read_int(u16, bytes[index_map + 8 ..][0..2], .big);
                if (codepoint >= first and codepoint < first + count)
                    return @fromBackingInt(@intCast(read_int(u16, bytes[index_map + 10 + (codepoint - first) * 2 ..][0..2], .big)));

                return .NOT_DEFINED;
            },
            12, 13 => {
                const ngroups = read_int(u32, bytes[index_map + 12 ..][0..4], .big);
                var low: u32 = 0;
                var high: u32 = ngroups;
                // Binary search the right group.
                while (low < high) {
                    const mid = low + ((high - low) >> 1); // rounds down, so low <= mid < high
                    const off = index_map + 16 + mid * 12;
                    const start_char = read_int(u32, bytes[off..][0..4], .big);
                    const end_char = read_int(u32, bytes[off + 4 ..][0..4], .big);
                    if (codepoint < start_char) {
                        high = mid;
                    } else if (codepoint > end_char) {
                        low = mid + 1;
                    } else {
                        const start_glyph = read_int(u32, bytes[off + 8 ..][0..4], .big);
                        return @fromBackingInt(@intCast(start_glyph + if (format == 12) codepoint - start_char else 0));
                    }
                }
                return .NOT_DEFINED;
            },
            else => {
                //TODO implement glyphIndex for more formats
                return .NOT_DEFINED;
            },
        }
    }

    pub fn get_scale_for_pixel_height(self: *const TrueTypeFont, height: f32) f32 {
        const vm = self.get_font_vertical_metrics();
        const fheight: f32 = @floatFromInt(vm.ascent - vm.descent);
        return height / fheight;
    }

    /// A typical expression for advancing the vertical position is
    /// `ascent - descent + line_gap`. These are expressed in unscaled coordinates,
    /// which are typically then multiplied by the scale factor for a given font size.
    pub fn get_font_vertical_metrics(self: *const TrueTypeFont) VerticalMetrics {
        const bytes = self.ttf_bytes;
        const hhea = self.table_offsets[TableId.hhea.idx()];
        return .{
            .ascent = read_int(i16, bytes[hhea + 4 ..][0..2], .big),
            .descent = read_int(i16, bytes[hhea + 6 ..][0..2], .big),
            .line_gap = read_int(i16, bytes[hhea + 8 ..][0..2], .big),
        };
    }

    pub fn get_glyph_horizontal_metrics(self: *const TrueTypeFont, glyph: GlyphIndex) HorizontalMetrics {
        const glyph_index: u32 = @backingInt(glyph);
        const bytes = self.ttf_bytes;
        const hhea = self.table_offsets[TableId.hhea.idx()];
        const hmtx = self.table_offsets[TableId.hmtx.idx()];
        const n_long_h_metrics = read_int(u16, bytes[hhea + 34 ..][0..2], .big);
        if (glyph_index < n_long_h_metrics) return .{
            .advance_width = read_int(i16, bytes[hmtx + 4 * glyph_index ..][0..2], .big),
            .left_side_bearing = read_int(i16, bytes[hmtx + 4 * glyph_index + 2 ..][0..2], .big),
        };
        return .{
            .advance_width = read_int(i16, bytes[hmtx + 4 * (n_long_h_metrics - 1) ..][0..2], .big),
            .left_side_bearing = read_int(i16, bytes[hmtx + 4 * n_long_h_metrics + 2 * (glyph_index - n_long_h_metrics) ..][0..2], .big),
        };
    }

    /// An additional amount to advance the horizontal coordinate between the two
    /// provided glyphs.
    pub fn get_kerning_between_two_glyphs(self: *const TrueTypeFont, left_glyph: GlyphIndex, right_glyph: GlyphIndex) i16 {
        const gpos = self.table_offsets[TableId.GPOS.idx()];
        if (gpos > 0) return get_glyph_kern_using_gpos(self, left_glyph, right_glyph);
        const kern = self.table_offsets[TableId.kern.idx()];
        if (kern > 0) return get_glyph_kern_using_kern(self, left_glyph, right_glyph);
        return 0;
    }

    fn get_glyph_kern_using_gpos(self: *const TrueTypeFont, left: GlyphIndex, right: GlyphIndex) i16 {
        const bytes = self.ttf_bytes;
        const gpos = self.table_offsets[TableId.GPOS.idx()];
        assert_with_reason(gpos > 0, @src(), "`GPOS` table not provided by font", .{});

        if (read_int(u16, bytes[gpos + 0 ..][0..2], .big) != 1) return 0; // Major version 1
        if (read_int(u16, bytes[gpos + 2 ..][0..2], .big) != 0) return 0; // Minor version 0

        const lookup_list_offset: u16 = read_int(u16, bytes[gpos + 8 ..][0..2], .big);
        const lookup_list = gpos + lookup_list_offset;
        const lookup_count: u16 = read_int(u16, bytes[lookup_list..][0..2], .big);

        for (0..lookup_count) |i| {
            const lookup_offset = read_int(u16, bytes[lookup_list + 2 + 2 * i ..][0..2], .big);
            const lookup_table = lookup_list + lookup_offset;

            const lookup_type = read_int(u16, bytes[lookup_table..][0..2], .big);
            const sub_table_count = read_int(u16, bytes[lookup_table + 4 ..][0..2], .big);
            const sub_table_offsets = lookup_table + 6;
            if (lookup_type != 2) // Pair Adjustment Positioning Subtable
                continue;

            for (0..sub_table_count) |sti| {
                const subtable_offset = read_int(u16, bytes[sub_table_offsets + 2 * sti ..][0..2], .big);
                const table = lookup_table + subtable_offset;
                const pos_format = read_int(u16, bytes[table..][0..2], .big);
                const coverage_offset = read_int(u16, bytes[table + 2 ..][0..2], .big);
                const _coverage_index = coverage_index(bytes, table + coverage_offset, left) orelse continue;

                switch (pos_format) {
                    1 => {
                        const value_format_1 = read_int(u16, bytes[table + 4 ..][0..2], .big);
                        const value_format_2 = read_int(u16, bytes[table + 6 ..][0..2], .big);
                        if (value_format_1 == 4 and value_format_2 == 0) {
                            const value_record_pair_size_in_bytes = 2;
                            const pair_set_count = read_int(u16, bytes[table + 8 ..][0..2], .big);
                            const pair_pos_offset = read_int(u16, bytes[table + 10 + 2 * _coverage_index ..][0..2], .big);
                            const pair_value_table = table + pair_pos_offset;
                            const pair_value_count = read_int(u16, bytes[pair_value_table..][0..2], .big);
                            const pair_value_array = pair_value_table + 2;

                            if (_coverage_index >= pair_set_count) return 0;

                            const needle = @backingInt(right);
                            var r: u32 = pair_value_count - 1;
                            var l: u32 = 0;

                            // Binary search.
                            while (l <= r) {
                                const m = (l + r) >> 1;
                                const pair_value = pair_value_array + (2 + value_record_pair_size_in_bytes) * m;
                                const second_glyph = read_int(u16, bytes[pair_value..][0..2], .big);
                                const straw = second_glyph;
                                if (needle < straw) {
                                    if (m == 0) break;
                                    r = m - 1;
                                } else if (needle > straw) {
                                    l = m + 1;
                                } else {
                                    return read_int(i16, bytes[pair_value + 2 ..][0..2], .big);
                                }
                            }
                        } else {
                            //TODO implement more glyphKernAdvanceGpos
                            return 0;
                        }
                    },
                    2 => {
                        const value_format_1 = read_int(u16, bytes[table + 4 ..][0..2], .big);
                        const value_format_2 = read_int(u16, bytes[table + 6 ..][0..2], .big);
                        if (value_format_1 == 4 and value_format_2 == 0) {
                            const class_def10_offset = read_int(u16, bytes[table + 8 ..][0..2], .big);
                            const class_def20_offset = read_int(u16, bytes[table + 10 ..][0..2], .big);
                            const glyph1class = glyph_class(bytes, table + class_def10_offset, left);
                            const glyph2class = glyph_class(bytes, table + class_def20_offset, right);

                            const class1_count = read_int(u16, bytes[table + 12 ..][0..2], .big);
                            const class2_count = read_int(u16, bytes[table + 14 ..][0..2], .big);

                            if (glyph1class >= class1_count) return 0; // malformed
                            if (glyph2class >= class2_count) return 0; // malformed

                            const class1_records = table + 16;
                            const class2_records = class1_records + 2 * (glyph1class * class2_count);
                            return read_int(i16, bytes[class2_records + 2 * glyph2class ..][0..2], .big);
                        } else {
                            //TODO implement more glyphKernAdvanceGpos
                            return 0;
                        }
                    },
                    else => {
                        // TODO implement more glyphKernAdvanceGpos
                        return 0;
                    },
                }
            }
        }

        return 0;
    }

    fn get_glyph_kern_using_kern(self: *const TrueTypeFont, a: GlyphIndex, b: GlyphIndex) i16 {
        const bytes = self.ttf_bytes;
        const kern = self.table_offsets[TableId.kern.idx()];
        assert_with_reason(kern > 0, @src(), "`kern` table not provided by font", .{});
        // we only look at the first table. it must be 'horizontal' and format 0.
        if (read_int(u16, bytes[kern + 2 ..][0..2], .big) < 1) // number of tables, need at least 1
            return 0;
        if (read_int(u16, bytes[kern + 8 ..][0..2], .big) != 1) // horizontal flag must be set in format
            return 0;

        var l: u32 = 0;
        var r: u32 = read_int(u16, bytes[kern + 10 ..][0..2], .big) - 1;
        const needle: u32 = @as(u32, @backingInt(a)) << 16 | @as(u32, @backingInt(b));
        while (l <= r) {
            const m: u32 = (l + r) >> 1;
            const straw: u32 = read_int(u32, bytes[kern + 18 + (m * 6) ..][0..4], .big); // note: unaligned read
            if (needle < straw) {
                r = m - 1;
            } else if (needle > straw) {
                l = m + 1;
            } else {
                return read_int(i16, bytes[kern + 22 + (m * 6) ..][0..2], .big);
            }
        }
        return 0;
    }

    pub fn get_glyph_vertex_list(self: *const TrueTypeFont, glyph: GlyphIndex, vertices: *List(Vertex), vertex_alloc: Allocator, comptime POOL_THREADING: Root.CommonTypes.ThreadingMode, temp_compound_vertex_list_pool: *VertexListPool(POOL_THREADING), temp_compound_vertex_list_allocator: Allocator) GlyphBitmapError!void {
        return if (self.cff_data.cff.size != 0)
            self.get_glyph_vertex_list_cff(glyph, vertices, vertex_alloc)
        else
            self.get_glyph_vertex_list_ttf(glyph, vertices, vertex_alloc, POOL_THREADING, temp_compound_vertex_list_pool, temp_compound_vertex_list_allocator);
    }

    fn get_glyph_vertex_list_ttf(self: *const TrueTypeFont, glyph: GlyphIndex, vertices: *List(Vertex), vertex_alloc: Allocator, comptime POOL_THREADING: Root.CommonTypes.ThreadingMode, temp_compound_vertex_list_pool: *VertexListPool(POOL_THREADING), temp_compound_vertex_list_allocator: Allocator) GlyphBitmapError!void {
        const bytes = self.ttf_bytes;
        const g = try get_glyph_offset(self, glyph);
        vertices.clear();
        const n_contours_signed = read_int(i16, bytes[g..][0..2], .big);
        if (n_contours_signed > 0) {
            const n_contours: u16 = @intCast(n_contours_signed);
            const contours_end_pts: u32 = g + 10;
            const ins: i32 = read_int(u16, bytes[g + 10 + n_contours * 2 ..][0..2], .big);
            var points: u32 = @intCast(g + 10 + @as(i64, n_contours) * 2 + 2 + ins);

            const n: u32 = 1 + read_int(u16, bytes[contours_end_pts + n_contours * 2 - 2 ..][0..2], .big);

            // A loose bound on how many vertices we might need.
            const max: u32 = n + 2 * n_contours;
            vertices.grow_capacity_if_needed_for_n_more_elems(max, .GROW_EXACT_NEEDED, vertex_alloc);
            vertices.set_len(max);
            var next_move: i32 = 0;
            var flagcount: u8 = 0;

            // in first pass, we load uninterpreted data into the allocated array
            // above, shifted to the end of the array so we won't overwrite it when
            // we create our final data starting from the front

            // Starting offset for uninterpreted data, regardless of how m ends up being calculated.
            const off: u32 = max - n;

            // first load flags
            {
                var flags: u8 = 0;
                for (0..n) |i| {
                    if (flagcount == 0) {
                        flags = bytes[points];
                        points += 1;
                        if ((flags & 8) != 0) {
                            flagcount = bytes[points];
                            points += 1;
                        }
                    } else {
                        flagcount -= 1;
                    }
                    vertices.get_field_ptr(.type, off + num_cast(i, u32)).* = @fromBackingInt(@intCast(flags));
                }
            }

            // now load x coordinates
            var x: i32 = 0;
            for (0..n) |i| {
                const flags = @backingInt(vertices.get_field(.type, off + num_cast(i, u32)));
                if ((flags & 2) != 0) {
                    const dx: i16 = bytes[points];
                    points += 1;
                    x += if ((flags & 16) != 0) dx else -dx;
                } else {
                    if ((flags & 16) == 0) {
                        x += read_int(i16, bytes[points..][0..2], .big);
                        points += 2;
                    }
                }
                vertices.set_field(.x, off + num_cast(i, u32), @intCast(x));
            }

            // now load y coordinates
            var y: i32 = 0;
            for (0..n) |i| {
                const flags = @backingInt(vertices.get_field(.type, off + num_cast(i, u32)));
                if ((flags & 4) != 0) {
                    const dy: i16 = bytes[points];
                    points += 1;
                    y += if ((flags & 32) != 0) dy else -dy;
                } else {
                    if ((flags & 32) == 0) {
                        y += read_int(i16, bytes[points..][0..2], .big);
                        points += 2;
                    }
                }
                vertices.set_field(.y, off + num_cast(i, u32), @intCast(y));
            }

            // now convert them to our format
            var num_vertices: u32 = 0;
            var sx: i32 = 0;
            var sy: i32 = 0;
            var cx: i32 = 0;
            var cy: i32 = 0;
            var scx: i32 = 0;
            var scy: i32 = 0;
            var i: u32 = 0;
            var j: u32 = 0;
            var start_off: bool = false;
            var was_off: bool = false;
            while (i < n) : (i += 1) {
                const flags = @backingInt(vertices.get_field(.type, off + num_cast(i, u32)));
                x = @intCast(vertices.get_field(.x, off + i));
                y = @intCast(vertices.get_field(.y, off + i));

                if (next_move == i) {
                    if (i != 0) {
                        num_vertices = close_shape(vertices.zig_slice_entire(), num_vertices, was_off, start_off, sx, sy, scx, scy, cx, cy);
                    }

                    // now start the new one
                    start_off = (flags & 1) == 0;
                    if (start_off) {
                        // if we start off with an off-curve point, then when we need to find a point on the curve
                        // where we can start, and we need to save some state for when we wraparound.
                        scx = x;
                        scy = y;
                        if ((@backingInt(vertices.get_field(.type, off + i + 1)) & 1) == 0) {
                            // next point is also a curve point, so interpolate an on-point curve
                            sx = (x + vertices.get_field(.x, off + i + 1)) >> 1;
                            sy = (y + vertices.get_field(.y, off + i + 1)) >> 1;
                        } else {
                            // otherwise just use the next point as our start point
                            sx = vertices.get_field(.x, off + i + 1);
                            sy = vertices.get_field(.y, off + i + 1);
                            i += 1; // we're using point i+1 as the starting point, so skip it
                        }
                    } else {
                        sx = x;
                        sy = y;
                    }
                    vertices.get_ptr(num_vertices).set(.MOVE_TO, sx, sy, 0, 0);
                    num_vertices += 1;
                    was_off = false;
                    next_move = 1 + read_int(u16, bytes[contours_end_pts + j * 2 ..][0..2], .big);
                    j += 1;
                } else {
                    if ((flags & 1) == 0) { // if it's a curve
                        if (was_off) {
                            // two off-curve control points in a row means interpolate an on-curve midpoint
                            vertices.get_ptr(num_vertices).set(.QUADRATIC, (cx + x) >> 1, (cy + y) >> 1, cx, cy);
                            num_vertices += 1;
                        }
                        cx = x;
                        cy = y;
                        was_off = true;
                    } else {
                        if (was_off)
                            vertices.get_ptr(num_vertices).set(.QUADRATIC, x, y, cx, cy)
                        else
                            vertices.get_ptr(num_vertices).set(.LINE, x, y, 0, 0);
                        num_vertices += 1;
                        was_off = false;
                    }
                }
            }
            num_vertices = close_shape(vertices.zig_slice_entire(), num_vertices, was_off, start_off, sx, sy, scx, scy, cx, cy);
            vertices.set_len(num_vertices);
        } else if (n_contours_signed < 0) {
            // Compound shapes.
            var more = true;
            var comp = g + 10;
            while (more) {
                var mtx: [6]f32 = .{ 1, 0, 0, 1, 0, 0 };

                const flags = read_cursor(u16, bytes, &comp);
                const gidx: GlyphIndex = @fromBackingInt(@intCast(read_cursor(u16, bytes, &comp)));

                if ((flags & 2) != 0) { // XY values
                    if ((flags & 1) != 0) { // shorts
                        mtx[4] = @floatFromInt(read_cursor(i16, bytes, &comp));
                        mtx[5] = @floatFromInt(read_cursor(i16, bytes, &comp));
                    } else {
                        mtx[4] = @floatFromInt(read_cursor(i8, bytes, &comp));
                        mtx[5] = @floatFromInt(read_cursor(i8, bytes, &comp));
                    }
                } else {
                    //TODO handle matching point
                }
                if ((flags & (1 << 3)) != 0) { // WE_HAVE_A_SCALE
                    mtx[0] = @as(f32, @floatFromInt(read_cursor(i16, bytes, &comp))) / 16384.0;
                    mtx[1] = 0;
                    mtx[2] = 0;
                    mtx[3] = mtx[0];
                } else if ((flags & (1 << 6)) != 0) { // WE_HAVE_AN_X_AND_YSCALE
                    mtx[0] = @as(f32, @floatFromInt(read_cursor(i16, bytes, &comp))) / 16384.0;
                    mtx[1] = 0;
                    mtx[2] = 0;
                    mtx[3] = @as(f32, @floatFromInt(read_cursor(i16, bytes, &comp))) / 16384.0;
                } else if ((flags & (1 << 7)) != 0) { // WE_HAVE_A_TWO_BY_TWO
                    mtx[0] = @as(f32, @floatFromInt(read_cursor(i16, bytes, &comp))) / 16384.0;
                    mtx[1] = @as(f32, @floatFromInt(read_cursor(i16, bytes, &comp))) / 16384.0;
                    mtx[2] = @as(f32, @floatFromInt(read_cursor(i16, bytes, &comp))) / 16384.0;
                    mtx[3] = @as(f32, @floatFromInt(read_cursor(i16, bytes, &comp))) / 16384.0;
                }

                // Find transformation scales.
                const m: f32 = @sqrt(mtx[0] * mtx[0] + mtx[1] * mtx[1]);
                const n: f32 = @sqrt(mtx[2] * mtx[2] + mtx[3] * mtx[3]);

                // Get indexed glyph.
                var comp_verts: *List(Vertex) = temp_compound_vertex_list_pool.claim();
                defer temp_compound_vertex_list_pool.release(comp_verts);
                comp_verts.clear();
                try get_glyph_vertex_list(self, gidx, comp_verts, temp_compound_vertex_list_allocator, POOL_THREADING, temp_compound_vertex_list_pool, temp_compound_vertex_list_allocator);
                if (comp_verts.get_len() > 0) {
                    // Transform vertices.
                    for (comp_verts.zig_slice_entire()) |*v| {
                        {
                            const x: f32 = @floatFromInt(v.x);
                            const y: f32 = @floatFromInt(v.y);
                            v.x = @intCast(@as(i32, @intFromFloat(m * (mtx[0] * x + mtx[2] * y + mtx[4]))));
                            v.y = @intCast(@as(i32, @intFromFloat(n * (mtx[1] * x + mtx[3] * y + mtx[5]))));
                        }
                        {
                            const x: f32 = @floatFromInt(v.cx);
                            const y: f32 = @floatFromInt(v.cy);
                            v.cx = @intFromFloat(m * (mtx[0] * x + mtx[2] * y + mtx[4]));
                            v.cy = @intFromFloat(n * (mtx[1] * x + mtx[3] * y + mtx[5]));
                        }
                    }
                    _ = vertices.append_many(comp_verts.slice_entire(), vertex_alloc);
                }
                more = (flags & (1 << 5)) != 0;
            }
        }
        return;
    }

    fn get_glyph_offset(self: *const TrueTypeFont, glyph: GlyphIndex) error{glyph_not_found}!u32 {
        const bytes = self.ttf_bytes;
        const glyph_index: u32 = @backingInt(glyph);

        assert_with_reason(glyph_index < self.glyphs_len, @src(), "glyph index {d} is out of bounds for font `glyphs_len` ({d})", .{ glyph_index, self.glyphs_len });
        assert_with_reason(self.index_to_loc_format < 2, @src(), "only `index_to_loc_format` 0 or 1 is supported, got {d}", .{self.index_to_loc_format});

        const glyf = self.table_offsets[TableId.glyf.idx()];
        const loca = self.table_offsets[TableId.loca.idx()];
        const g1, const g2 = if (self.index_to_loc_format == 0) .{
            glyf + @as(u32, read_int(u16, bytes[loca + glyph_index * 2 ..][0..2], .big)) * 2,
            glyf + @as(u32, read_int(u16, bytes[loca + glyph_index * 2 + 2 ..][0..2], .big)) * 2,
        } else .{
            glyf + read_int(u32, bytes[loca + glyph_index * 4 ..][0..4], .big),
            glyf + read_int(u32, bytes[loca + glyph_index * 4 + 4 ..][0..4], .big),
        };
        if (g1 == g2) return error.glyph_not_found;
        return g1;
    }

    pub fn get_glyph_bitmap_bounds_with_subpixel_offset(self: *const TrueTypeFont, glyph: GlyphIndex, scale_x: f32, scale_y: f32, shift_x: f32, shift_y: f32) !AABB_i32 {
        const box = try get_glyph_bounds(self, glyph);
        return .{
            // move to integral bboxes (treating pixels as little squares, what pixels get touched)?
            .x_min = @intFromFloat(@floor(@as(f32, @floatFromInt(box.x_min)) * scale_x + shift_x)),
            .y_min = @intFromFloat(@floor(@as(f32, @floatFromInt(-box.y_max)) * scale_y + shift_y)),
            .x_max = @intFromFloat(@ceil(@as(f32, @floatFromInt(box.x_max)) * scale_x + shift_x)),
            .y_max = @intFromFloat(@ceil(@as(f32, @floatFromInt(-box.y_min)) * scale_y + shift_y)),
        };
    }

    pub fn get_glyph_bitmap_bounds(self: *const TrueTypeFont, glyph: GlyphIndex, scale_x: f32, scale_y: f32) AABB_i32 {
        return get_glyph_bitmap_bounds_with_subpixel_offset(self, glyph, scale_x, scale_y, 0, 0);
    }

    pub fn get_glyph_bounds(self: *const TrueTypeFont, glyph: GlyphIndex) !AABB_i32 {
        return if (self.cff_data.cff.size != 0)
            self.get_glyph_bounds_cff(glyph)
        else
            self.get_glyph_bounds_ttf(glyph);
    }

    fn get_glyph_bounds_ttf(self: *const TrueTypeFont, glyph: GlyphIndex) error{glyph_not_found}!AABB_i32 {
        const bytes = self.ttf_bytes;
        const off = try get_glyph_offset(self, glyph);
        return .{
            .x_min = read_int(i16, bytes[off + 2 ..][0..2], .big),
            .y_min = read_int(i16, bytes[off + 4 ..][0..2], .big),
            .x_max = read_int(i16, bytes[off + 6 ..][0..2], .big),
            .y_max = read_int(i16, bytes[off + 8 ..][0..2], .big),
        };
    }

    /// Shapes a UTF-8 string into a slice of glyphs with individual x-advances.
    ///
    /// The provided `*ShapedGlyphList` is cleared, reallocated if necessary, and reused.
    pub fn shape_text(
        font: *const TrueTypeFont,
        text_utf8: []const u8,
        scale: f32,
        list: *ShapedGlyphList,
        allocator: Allocator,
    ) !void {
        const valid, const count = Utils.UTF8.utf8_validate_slice_and_count_codepoints(text_utf8, .cannot_encode_surrogate_half);
        if (!valid) return error.invalid_utf8_string;
        var utf8_view = std.unicode.Utf8View.initUnchecked(text_utf8);

        list.clear();
        list.grow_capacity_if_needed(@intCast(count), .GROW_BY_25_PERCENT, allocator);

        var iter = utf8_view.iterator();
        var prev_glyph_idx: GlyphIndex = .NOT_DEFINED;
        if (iter.nextCodepoint()) |codepoint| {
            const glyph_idx = font.get_codepoint_glyph_index(codepoint);
            const h_metrics = font.get_glyph_horizontal_metrics(glyph_idx);
            list.append_one_assume_cap(ShapedGlyph{
                .codepoint = @intCast(codepoint),
                .glyph_idx = glyph_idx,
                .x_advance = @as(f32, @floatFromInt(h_metrics.advance_width)) * scale,
            });
            prev_glyph_idx = glyph_idx;
        }
        while (iter.nextCodepoint()) |codepoint| {
            const glyph_idx = font.get_codepoint_glyph_index(codepoint);
            const h_metrics = font.get_glyph_horizontal_metrics(glyph_idx);
            const advance = @as(f32, @floatFromInt(h_metrics.advance_width)) * scale;
            const kern = font.get_kerning_between_two_glyphs(prev_glyph_idx, glyph_idx);
            if (kern != 0) {
                const scaled_kern_for_prev = @as(f32, @floatFromInt(kern)) * scale;
                list.get_last_ptr().x_advance += scaled_kern_for_prev;
            }
            list.append_one_assume_cap(ShapedGlyph{
                .codepoint = @intCast(codepoint),
                .glyph_idx = glyph_idx,
                .x_advance = advance,
            });
            prev_glyph_idx = glyph_idx;
        }
    }

    fn close_shape(
        vertices: []Vertex,
        num_verts: u32,
        was_off: bool,
        start_off: bool,
        sx: i32,
        sy: i32,
        scx: i32,
        scy: i32,
        cx: i32,
        cy: i32,
    ) u32 {
        var new_num_verts = num_verts;
        if (start_off) {
            if (was_off) {
                vertices.ptr[new_num_verts].set(.QUADRATIC, (cx + scx) >> 1, (cy + scy) >> 1, cx, cy);
                new_num_verts += 1;
            }
            vertices.ptr[new_num_verts].set(.QUADRATIC, sx, sy, scx, scy);
            new_num_verts += 1;
        } else {
            if (was_off) {
                vertices.ptr[new_num_verts].set(.QUADRATIC, sx, sy, cx, cy);
                new_num_verts += 1;
            } else {
                vertices.ptr[new_num_verts].set(.LINE, sx, sy, 0, 0);
                new_num_verts += 1;
            }
        }
        return new_num_verts;
    }

    fn read_cursor(comptime I: type, bytes: []const u8, cursor: *u32) I {
        const start = cursor.*;
        const result = read_int(I, bytes[start..][0..@sizeOf(I)], .big);
        cursor.* = start + @sizeOf(I);
        return result;
    }

    fn coverage_index(bytes: []const u8, coverage_table: u32, glyph: GlyphIndex) ?u32 {
        const coverage_format = read_int(u16, bytes[coverage_table..][0..2], .big);
        switch (coverage_format) {
            1 => {
                const glyph_count = read_int(u16, bytes[coverage_table + 2 ..][0..2], .big);

                // Binary search.
                var l: u32 = 0;
                var r: u32 = glyph_count - 1;
                const needle = @backingInt(glyph);
                while (l <= r) {
                    const glyph_array = coverage_table + 4;
                    const m = (l + r) >> 1;
                    const glyph_id = read_int(u16, bytes[glyph_array + 2 * m ..][0..2], .big);
                    const straw = glyph_id;
                    if (needle < straw) {
                        if (m == 0) break;
                        r = m - 1;
                    } else if (needle > straw) {
                        l = m + 1;
                    } else {
                        return m;
                    }
                }
            },
            2 => {
                const range_count = read_int(u16, bytes[coverage_table + 2 ..][0..2], .big);
                const range_array = coverage_table + 4;

                // Binary search.
                var l: u32 = 0;
                var r: u32 = range_count - 1;
                const needle = @backingInt(glyph);
                while (l <= r) {
                    const m = (l + r) >> 1;
                    const range_record = range_array + 6 * m;
                    const straw_start = read_int(u16, bytes[range_record..][0..2], .big);
                    const straw_end = read_int(u16, bytes[range_record + 2 ..][0..2], .big);
                    if (needle < straw_start) {
                        if (m == 0) break;
                        r = m - 1;
                    } else if (needle > straw_end) {
                        l = m + 1;
                    } else {
                        const start_coverage_index = read_int(u16, bytes[range_record + 4 ..][0..2], .big);
                        return start_coverage_index + needle - straw_start;
                    }
                }
            },
            else => {},
        }
        return null;
    }

    fn glyph_class(bytes: []const u8, class_def_table: u32, glyph: GlyphIndex) u32 {
        const glyph_int = @backingInt(glyph);
        const class_def_format = read_int(u16, bytes[class_def_table..][0..2], .big);
        switch (class_def_format) {
            1 => {
                const start_glyph_id = read_int(u16, bytes[class_def_table + 2 ..][0..2], .big);
                const glyph_count = read_int(u16, bytes[class_def_table + 4 ..][0..2], .big);
                const class_def1_value_array = class_def_table + 6;

                if (glyph_int >= start_glyph_id and glyph_int < start_glyph_id + glyph_count)
                    return read_int(u16, bytes[class_def1_value_array + 2 * (glyph_int - start_glyph_id) ..][0..2], .big);
            },
            2 => {
                const class_range_count = read_int(u16, bytes[class_def_table + 2 ..][0..2], .big);
                const class_range_records = class_def_table + 4;

                // Binary search.
                var l: u32 = 0;
                var r: u32 = class_range_count - 1;
                while (l <= r) {
                    const m = (l + r) >> 1;
                    const class_range_record = class_range_records + 6 * m;
                    const straw_start = read_int(u16, bytes[class_range_record..][0..2], .big);
                    const straw_end = read_int(u16, bytes[class_range_record + 2 ..][0..2], .big);
                    if (glyph_int < straw_start) {
                        if (m == 0) break;
                        r = m - 1;
                    } else if (glyph_int > straw_end) {
                        l = m + 1;
                    } else {
                        return read_int(u16, bytes[class_range_record + 4 ..][0..2], .big);
                    }
                }
            },
            else => return std.math.maxInt(u32), // Unsupported definition type, return an error.
        }

        // "All glyphs not assigned to a class fall into class 0". (OpenType spec)
        return 0;
    }

    // ---
    // opentype specific code
    // ---

    const CffData = struct {
        /// cff font data
        cff: DataBuf,
        /// the charstring index
        charstrings: DataBuf,
        /// global charstring subroutines index
        gsubrs: DataBuf,
        /// private charstring subroutines index
        subrs: DataBuf,
        /// array of font dicts
        fontdicts: DataBuf,
        /// map from glyph to fontdict
        fdselect: DataBuf,

        pub const empty: CffData = .{
            .cff = .empty,
            .charstrings = .empty,
            .gsubrs = .empty,
            .subrs = .empty,
            .fontdicts = .empty,
            .fdselect = .empty,
        };

        pub fn init(cff_offset: u32, bytes: [*]const u8) !CffData {
            var result: CffData = .empty;
            // TODO this should use size from table (not 512MB)
            result.cff = .init(bytes + cff_offset, 512 * 1024 * 1024);
            var b = result.cff;
            // read the header
            b.skip(2);
            b.seek(b.get8());
            // TODO the name INDEX could list multiple fonts, but we just use the first one.
            _ = b.cff_get_index(); // name INDEX
            var topdictidx = b.cff_get_index();
            var topdict = topdictidx.cff_index_get(@fromBackingInt(@intCast(0)));
            _ = b.cff_get_index(); // string INDEX
            result.gsubrs = b.cff_get_index();

            var cstype: u32 = 2;
            var csoff: u32 = 0;
            var fdarrayoff: u32 = 0;
            var fdselectoff: u32 = 0;

            topdict.dict_get_ints(17, 1, @ptrCast(&csoff));
            topdict.dict_get_ints(0x100 | 6, 1, @ptrCast(&cstype));
            topdict.dict_get_ints(0x100 | 36, 1, @ptrCast(&fdarrayoff));
            topdict.dict_get_ints(0x100 | 37, 1, @ptrCast(&fdselectoff));
            result.subrs = b.get_subroutines(topdict);

            // we only support Type 2 charstrings
            if (cstype != 2) return error.UnsupportedCffData;
            if (csoff == 0) return error.UnsupportedCffData;

            if (fdarrayoff != 0) {
                // looks like a CID font
                if (fdselectoff == 0) return error.UnsupportedCffData;
                b.seek(fdarrayoff);
                result.fontdicts = b.cff_get_index();
                result.fdselect = b.range(fdselectoff, b.size - fdselectoff);
            }

            b.seek(csoff);
            result.charstrings = b.cff_get_index();
            return result;
        }
    };

    const DataBuf = struct {
        data: [*]const u8,
        cursor: u32,
        size: u32,

        pub const empty: DataBuf = .init(undefined, 0);

        pub fn init(data: [*]const u8, size: u32) DataBuf {
            return .{ .data = data, .size = size, .cursor = 0 };
        }

        pub fn skip(buf: *DataBuf, offset: u32) void {
            buf.seek(buf.cursor + offset);
        }

        pub fn seek(buf: *DataBuf, offset: u32) void {
            assert_with_reason(offset <= buf.size, @src(), "offset > buffer.size ({d} > {d})", .{ offset, buf.size });
            buf.cursor = if (offset > buf.size) buf.size else offset;
        }

        pub fn peek8(buf: *DataBuf) u8 {
            if (buf.cursor >= buf.size)
                return 0;
            return buf.data[buf.cursor];
        }

        pub fn get8(buf: *DataBuf) u8 {
            if (buf.cursor >= buf.size) return 0;
            defer buf.cursor += 1;
            return buf.data[buf.cursor];
        }

        pub fn get16(buf: *DataBuf) u16 {
            return @truncate(buf.get(2));
        }

        pub fn get32(buf: *DataBuf) u32 {
            return buf.get(4);
        }

        pub fn get(buf: *DataBuf, n: u32) u32 {
            var v: u32 = 0;
            assert_with_reason(n >= 1 and n <= 4, @src(), "`n` for offset size must be between 1 and 4 (inclusive), got {d}", .{n});
            for (0..n) |_|
                v = (v << 8) | buf.get8();
            return v;
        }

        pub fn cff_get_index(buf: *DataBuf) DataBuf {
            const start = buf.cursor;
            const count = buf.get16();
            if (count != 0) {
                const offsize = buf.get8();
                assert_with_reason(offsize >= 1 and offsize <= 4, @src(), "`offsize` for offset size must be between 1 and 4 (inclusive), got {d}", .{offsize});
                buf.skip(offsize * count);

                buf.skip(buf.get(offsize) - 1);
            }
            return buf.range(start, buf.cursor - start);
        }

        pub fn cff_index_get(buf_const: DataBuf, glyph: GlyphIndex) DataBuf {
            var b = buf_const;
            b.seek(0);
            const count = b.get16();
            const offsize = b.get8();
            const i: u32 = @backingInt(glyph);
            assert_with_reason(i < count, @src(), "glyph index out of bounds for cff index count ({d} >= {d})", .{ i, count });
            assert_with_reason(offsize >= 1 and offsize <= 4, @src(), "`offsize` for offset size must be between 1 and 4 (inclusive), got {d}", .{offsize});
            b.skip(i * offsize);

            const start = b.get(offsize);
            const end = b.get(offsize);
            return b.range(2 + (count + 1) * offsize + start, end - start);
        }

        pub fn cff_index_count(buf: *DataBuf) u16 {
            buf.seek(0);
            return buf.get16();
        }

        pub fn range(buf: *DataBuf, offset: u32, size: u32) DataBuf {
            var r = DataBuf.empty;
            if (offset < 0 or size < 0 or offset > buf.size or size > buf.size - offset) return r;
            r.data = buf.data + offset;
            r.size = size;
            return r;
        }

        pub fn cff_int(buf: *DataBuf) u32 {
            const b0: i32 = buf.get8();
            const result: u32 = switch (b0) {
                32...246 => @bitCast(b0 - 139),
                247...250 => @bitCast((b0 - 247) * 256 + buf.get8() + 108),
                251...254 => @bitCast(-(b0 - 251) * 256 - buf.get8() - 108),
                28 => buf.get16(),
                29 => buf.get32(),
                else => @panic("invalid instruction"),
            };
            // std.log.debug("cffInt() b0 {} result {}", .{ b0, result });
            return result;
        }

        pub fn dict_get_ints(buf: *DataBuf, key: u32, outcount: u32, out: [*]u32) void {
            var operands = buf.dict_get(key);
            for (0..outcount) |i| {
                if (operands.cursor >= operands.size) break;
                out[i] = operands.cff_int();
            }
        }

        pub fn dict_get(buf: *DataBuf, key: u32) DataBuf {
            buf.seek(0);
            while (buf.cursor < buf.size) {
                const start = buf.cursor;
                while (buf.peek8() >= 28) buf.cff_skip_operand();
                const end = buf.cursor;
                var op: i32 = buf.get8();
                if (op == 12) op = @as(i32, buf.get8()) | 0x100;
                if (op == key) return buf.range(start, end - start);
            }
            return buf.range(0, 0);
        }

        fn cff_skip_operand(b: *DataBuf) void {
            const b0 = b.peek8();
            assert_with_reason(b0 >= 28, @src(), "first byte in cff operand must be >= 28, got {d}, malformed", .{b0});
            if (b0 == 30) {
                b.skip(1);
                while (b.cursor < b.size) {
                    const v = b.get8();
                    if ((v & 0xF) == 0xF or (v >> 4) == 0xF)
                        break;
                }
            } else {
                _ = b.cff_int();
            }
        }

        pub fn get_subroutines(cff_const: DataBuf, fontdict_const: DataBuf) DataBuf {
            var private_loc: [2]u32 = .{ 0, 0 };
            var fontdict = fontdict_const;
            fontdict.dict_get_ints(18, 2, &private_loc);
            if (private_loc[1] == 0 or private_loc[0] == 0) return .empty;
            var cff = cff_const;
            var pdict = cff.range(private_loc[1], private_loc[0]);
            var subrsoff: u32 = 0;
            pdict.dict_get_ints(19, 1, @ptrCast(&subrsoff));
            if (subrsoff == 0) return .empty;
            cff.seek(private_loc[1] + subrsoff);
            return cff.cff_get_index();
        }

        fn get_subroutine(idx_const: DataBuf, n_const: u32) DataBuf {
            var idx = idx_const;
            var n = n_const;
            const count = idx.cff_index_count();
            n +%= if (count >= 33900)
                32768
            else if (count >= 1240)
                1131
            else
                107;
            if (n >= count) return .empty;
            return idx.cff_index_get(@fromBackingInt(@intCast(n)));
        }
    };

    pub const CharstringCtx = struct {
        first_x: f32,
        first_y: f32,
        x: f32,
        y: f32,
        min_x: i32,
        min_y: i32,
        max_x: i32,
        max_y: i32,
        num_vertices: u32,
        vertices: [*]Vertex,
        flags: CharstringFlags,

        pub fn init(flags: CharstringFlags, vertices: [*]Vertex) CharstringCtx {
            return .{
                .flags = flags,
                .vertices = vertices,
                .first_x = 0,
                .first_y = 0,
                .x = 0,
                .y = 0,
                .min_x = 0,
                .min_y = 0,
                .max_x = 0,
                .max_y = 0,
                .num_vertices = 0,
            };
        }
        pub fn deinit(ctx: *CharstringCtx, alloc: Allocator) void {
            if (ctx.flags.mode == .verts)
                alloc.free(ctx.allVertices());
        }

        fn trackVertex(ctx: *CharstringCtx, x: i32, y: i32) void {
            if (x > ctx.max_x or !ctx.flags.started) ctx.max_x = x;
            if (y > ctx.max_y or !ctx.flags.started) ctx.max_y = y;
            if (x < ctx.min_x or !ctx.flags.started) ctx.min_x = x;
            if (y < ctx.min_y or !ctx.flags.started) ctx.min_y = y;
            ctx.flags.started = true;
        }

        fn v(ctx: *CharstringCtx, ty: Vertex.Type, x: i32, y: i32, cx: i32, cy: i32, cx1: i32, cy1: i32) !void {
            if (ctx.flags.mode == .bounds) {
                trackVertex(ctx, x, y);
                if (ty == .CUBIC) {
                    trackVertex(ctx, cx, cy);
                    trackVertex(ctx, cx1, cy1);
                }
            } else {
                ctx.vertices[ctx.num_vertices].set(ty, x, y, cx, cy);
                ctx.vertices[ctx.num_vertices].cx1 = @truncate(cx1);
                ctx.vertices[ctx.num_vertices].cy1 = @truncate(cy1);
            }
            ctx.num_vertices += 1;
        }

        fn close_shape(ctx: *CharstringCtx) !void {
            if (ctx.first_x != ctx.x or ctx.first_y != ctx.y)
                try ctx.v(.LINE, @intFromFloat(ctx.first_x), @intFromFloat(ctx.first_y), 0, 0, 0, 0);
        }

        fn r_move_to(ctx: *CharstringCtx, dx: f32, dy: f32) !void {
            try ctx.close_shape();
            ctx.first_x = ctx.x + dx;
            ctx.x = ctx.first_x;
            ctx.first_y = ctx.y + dy;
            ctx.y = ctx.first_y;
            // std.log.debug("moveTo {d:.1},{d:.1}", .{ ctx.x, ctx.y });
            try ctx.v(.MOVE_TO, @intFromFloat(ctx.x), @intFromFloat(ctx.y), 0, 0, 0, 0);
        }

        fn r_line_to(ctx: *CharstringCtx, dx: f32, dy: f32) !void {
            ctx.x += dx;
            ctx.y += dy;
            // std.log.debug("lineTo {d:.1},{d:.1}", .{ ctx.x, ctx.y });
            try ctx.v(.LINE, @intFromFloat(ctx.x), @intFromFloat(ctx.y), 0, 0, 0, 0);
        }

        fn rc_curve_to(ctx: *CharstringCtx, dx1: f32, dy1: f32, dx2: f32, dy2: f32, dx3: f32, dy3: f32) !void {
            const cx1 = ctx.x + dx1;
            const cy1 = ctx.y + dy1;
            const cx2 = cx1 + dx2;
            const cy2 = cy1 + dy2;
            ctx.x = cx2 + dx3;
            ctx.y = cy2 + dy3;
            // std.log.debug("curveTo {d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1}", .{ ctx.x, ctx.y, cx1, cy1, cx2, cy2 });
            try ctx.v(
                .CUBIC,
                @intFromFloat(ctx.x),
                @intFromFloat(ctx.y),
                @intFromFloat(cx1),
                @intFromFloat(cy1),
                @intFromFloat(cx2),
                @intFromFloat(cy2),
            );
        }
    };

    fn get_glyph_bounds_cff(tt: *const TrueTypeFont, glyph: GlyphIndex) !AABB_i32 {
        var ctx = CharstringCtx.init(.{ .mode = .bounds }, undefined);
        try run_charstring(&tt.cff_data, glyph, &ctx);

        return AABB_i32{
            .x_min = ctx.min_x,
            .y_min = ctx.min_y,
            .x_max = ctx.max_x,
            .y_max = ctx.max_y,
        };
    }

    fn get_glyph_vertex_list_cff(self: *const TrueTypeFont, glyph: GlyphIndex, vertices: *List(Vertex), vertices_alloc: Allocator) GlyphBitmapError!void {
        // Pass 1: mode=bounds to count number of vertices
        var count_ctx = CharstringCtx.init(.{ .mode = .bounds }, undefined);
        try run_charstring(&self.cff_data, glyph, &count_ctx);

        // Pass 2: allocate the required capacity and extract vertices
        vertices.clear();
        vertices.grow_capacity_if_needed_for_n_more_elems(count_ctx.num_vertices, .GROW_EXACT_NEEDED, vertices_alloc);
        vertices.set_len(count_ctx.num_vertices);

        var out_ctx = CharstringCtx.init(.{ .mode = .verts }, vertices.get_many_item_ptr(0));
        try run_charstring(&self.cff_data, glyph, &out_ctx);
        assert_with_reason(out_ctx.num_vertices == count_ctx.num_vertices, @src(), "`out_ctx.num_vertices != count_ctx.num_vertices`", .{});
    }

    const Instruction = enum(u8) {
        HINT_MASK = 0x13,
        CNTR_MASK = 0x14,
        H_STEM = 0x01,
        V_STEM = 0x03,
        H_STEM_HM = 0x12,
        V_STEM_HM = 0x17,
        R_MOVE_TO = 0x15,
        V_MOVE_TO = 0x04,
        H_MOVE_TO = 0x16,
        R_LINE_TO = 0x05,
        V_LINE_TO = 0x07,
        H_LINE_TO = 0x06,
        HV_QUADRATIC_TO = 0x1F,
        VH_QUADRATIC_TO = 0x1E,
        RR_QUADRATIC_TO = 0x08,
        R_CURVE_LINE = 0x18,
        R_LINE_CURVE = 0x19,
        VV_QUADRATIV_TO = 0x1A,
        HH_QUADRATIC_TO = 0x1B,
        CALL_SUBROUTINE = 0x0A,
        CALL_GLOBAL_SUBROUTINE = 0x1D,
        /// return
        RETURN = 0x0B,
        END_CHAR = 0x0E,
        TWO_BYTE_ESCAPE = 0x0C,
        H_FLEX = 0x22,
        FLEX = 0x23,
        H_FLEX_1 = 0x24,
        FLEX_1 = 0x25,

        pub fn raw(i: Instruction) u16 {
            return @backingInt(i);
        }
    };

    fn run_charstring(cff_data: *const CffData, glyph: GlyphIndex, ctx: *CharstringCtx) !void {
        var maskbits: u32 = 0;
        var in_header = true;
        var has_subrs = false;
        var clear_stack = false;
        var s: [48]f32 = @splat(0); // stack
        var sp: u32 = 0; // stack pointer
        var subr_buf: [10]DataBuf = undefined;
        var subr_stack: List(DataBuf) = .from_slice_set_empty(subr_buf[0..]);
        var subrs = cff_data.subrs;
        // this currently ignores the initial width value, which isn't needed if we have hmtx
        var b = cff_data.charstrings.cff_index_get(glyph);

        while (b.cursor < b.size) {
            var i: u32 = 0;
            clear_stack = true;
            const b0: u16 = b.get8();
            // const tag_name = if (@IntToEnum(Instruction, b0)) |t| @tagName(t) else |_| "other";
            // std.log.debug("{}/{} b0 {s}/{}/0x{x} num_vertices {}", .{ b.cursor, b.size, tag_name, b0, b0, ctx.num_vertices });

            sw: switch (b0) {
                //TODO implement hinting
                Instruction.HINT_MASK.raw(), // 0x13
                Instruction.CNTR_MASK.raw(), // 0x14
                => {
                    if (in_header) maskbits += (sp / 2); // implicit "vstem"
                    in_header = false;
                    b.skip((maskbits + 7) / 8);
                },
                Instruction.H_STEM.raw(), // 0x01
                Instruction.V_STEM.raw(), // 0x03
                Instruction.H_STEM_HM.raw(), // 0x12
                Instruction.V_STEM_HM.raw(), // 0x17
                => {
                    maskbits += (sp / 2);
                },
                Instruction.R_MOVE_TO.raw() => { // 0x15
                    in_header = false;
                    if (sp < 2) return error.r_move_to_stack;
                    try ctx.r_move_to(s[sp - 2], s[sp - 1]);
                },
                Instruction.V_MOVE_TO.raw() => { // 0x04
                    in_header = false;
                    if (sp < 1) return error.v_move_to_stack;
                    try ctx.r_move_to(0, s[sp - 1]);
                },
                Instruction.H_MOVE_TO.raw() => { // 0x16
                    in_header = false;
                    if (sp < 1) return error.h_move_to_stack;
                    try ctx.r_move_to(s[sp - 1], 0);
                },
                Instruction.R_LINE_TO.raw() => { // 0x05
                    if (sp < 2) return error.r_line_to_stack;
                    while (i + 1 < sp) : (i += 2)
                        try ctx.r_line_to(s[i], s[i + 1]);
                },
                // hlineto/vlineto and vhcurveto/hvcurveto alternate horizontal and vertical
                // starting from a different place.
                Instruction.V_LINE_TO.raw() => { // 0x07
                    if (sp < 1) return error.v_line_to_stack;
                    // std.log.debug("vlineto i {} sp {}", .{ i, sp });
                    while (true) {
                        if (i >= sp) break;
                        try ctx.r_line_to(0, s[i]);
                        i += 1;
                        if (i >= sp) break;
                        try ctx.r_line_to(s[i], 0);
                        i += 1;
                    }
                },
                Instruction.H_LINE_TO.raw() => { // 0x06
                    if (sp < 1) return error.h_line_to_stack;
                    // std.log.debug("hlineto i {} sp {}", .{ i, sp });
                    while (true) {
                        if (i >= sp) break;
                        try ctx.r_line_to(s[i], 0);
                        i += 1;
                        if (i >= sp) break;
                        try ctx.r_line_to(0, s[i]);
                        i += 1;
                    }
                },
                Instruction.HV_QUADRATIC_TO.raw() => { // 0x1F
                    if (sp < 4) return error.h_curve_to_stack;
                    while (true) {
                        // std.log.debug("hvcurveto i {} sp {}", .{ i, sp });
                        if (i + 3 >= sp) break;
                        try ctx.rc_curve_to(s[i], 0, s[i + 1], s[i + 2], if (sp - i == 5) s[i + 4] else 0.0, s[i + 3]);
                        i += 4;
                        if (i + 3 >= sp) break;
                        try ctx.rc_curve_to(0, s[i], s[i + 1], s[i + 2], s[i + 3], if (sp - i == 5) s[i + 4] else 0.0);
                        i += 4;
                    }
                },
                Instruction.VH_QUADRATIC_TO.raw() => { // 0x1E
                    if (sp < 4) return error.h_curve_to_stack;
                    while (true) {
                        // std.log.debug("vhcurveto i {} sp {}", .{ i, sp });
                        if (i + 3 >= sp) break;
                        try ctx.rc_curve_to(0, s[i], s[i + 1], s[i + 2], s[i + 3], if (sp - i == 5) s[i + 4] else 0.0);
                        i += 4;
                        if (i + 3 >= sp) break;
                        try ctx.rc_curve_to(s[i], 0, s[i + 1], s[i + 2], if (sp - i == 5) s[i + 4] else 0.0, s[i + 3]);
                        i += 4;
                    }
                },
                Instruction.RR_QUADRATIC_TO.raw() => { // 0x08
                    if (sp < 6) return error.r_curve_to_stack;
                    while (i + 5 < sp) : (i += 6)
                        try ctx.rc_curve_to(s[i], s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5]);
                },
                Instruction.R_CURVE_LINE.raw() => { // 0x18
                    if (sp < 8) return error.r_curve_line_stack;
                    while (i + 5 < sp - 2) : (i += 6)
                        try ctx.rc_curve_to(s[i], s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5]);
                    if (i + 1 >= sp) return error.curve_line_stack;
                    try ctx.r_line_to(s[i], s[i + 1]);
                },
                Instruction.R_LINE_CURVE.raw() => { // 0x19
                    if (sp < 8) return error.r_line_curve_stack;
                    while (i + 1 < sp - 6) : (i += 2)
                        try ctx.r_line_to(s[i], s[i + 1]);
                    if (i + 5 >= sp) return error.r_line_curve_stack;
                    try ctx.rc_curve_to(s[i], s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5]);
                },
                Instruction.VV_QUADRATIV_TO.raw(), // 0x1A
                Instruction.HH_QUADRATIC_TO.raw(), // 0x1B
                => {
                    if (sp < 4) return error.curve_to_stack;
                    var f: f32 = 0.0;
                    if (sp & 1 != 0) {
                        f = s[i];
                        i += 1;
                    }
                    while (i + 3 < sp) : (i += 4) {
                        if (b0 == Instruction.HH_QUADRATIC_TO.raw()) //  0x1B
                            try ctx.rc_curve_to(s[i], f, s[i + 1], s[i + 2], s[i + 3], 0.0)
                        else
                            try ctx.rc_curve_to(f, s[i], s[i + 1], s[i + 2], 0.0, s[i + 3]);
                        f = 0.0;
                    }
                },
                Instruction.CALL_SUBROUTINE.raw() => { // 0x0A
                    if (!has_subrs) {
                        if (cff_data.fdselect.size != 0)
                            subrs = get_glyph_subroutines(cff_data, glyph);
                        has_subrs = true;
                    }
                    continue :sw Instruction.CALL_GLOBAL_SUBROUTINE.raw();
                    // FALLTHROUGH
                },
                Instruction.CALL_GLOBAL_SUBROUTINE.raw() => { // 0x1D
                    sp = std.math.sub(u32, sp, 1) catch return error.call_global_subroutines_stack;
                    const v: i32 = @intFromFloat(@trunc(s[sp]));
                    if (subr_stack.get_len() == subr_stack.get_cap()) return error.recursion_limit;
                    _ = subr_stack.append_one_assume_cap(b);
                    b = (if (b0 == Instruction.CALL_SUBROUTINE.raw()) // 0x0A
                        subrs
                    else
                        cff_data.gsubrs).get_subroutine(@bitCast(v));
                    if (b.size == 0) return error.subroutine_not_found;
                    b.cursor = 0;
                    clear_stack = false;
                },
                Instruction.RETURN.raw() => { // 0x0B
                    b = subr_stack.try_pop() orelse return error.return_outside_subroutine;
                    clear_stack = false;
                },
                Instruction.END_CHAR.raw() => { // 0x0E
                    try ctx.close_shape();
                    return;
                },
                Instruction.TWO_BYTE_ESCAPE.raw() => { // 0x0C
                    const b1 = b.get8();
                    switch (b1) {
                        //TODO These "flex" implementations ignore the flex-depth and resolution,
                        // and always draw beziers.
                        Instruction.H_FLEX.raw() => { // 0x22
                            if (sp < 7) return error.h_flex_stack;
                            const dx1 = s[0];
                            const dx2 = s[1];
                            const dy2 = s[2];
                            const dx3 = s[3];
                            const dx4 = s[4];
                            const dx5 = s[5];
                            const dx6 = s[6];
                            try ctx.rc_curve_to(dx1, 0, dx2, dy2, dx3, 0);
                            try ctx.rc_curve_to(dx4, 0, dx5, -dy2, dx6, 0);
                        },
                        Instruction.FLEX.raw() => { // 0x23
                            if (sp < 13) return error.flex_stack;
                            const dx1 = s[0];
                            const dy1 = s[1];
                            const dx2 = s[2];
                            const dy2 = s[3];
                            const dx3 = s[4];
                            const dy3 = s[5];
                            const dx4 = s[6];
                            const dy4 = s[7];
                            const dx5 = s[8];
                            const dy5 = s[9];
                            const dx6 = s[10];
                            const dy6 = s[11];
                            //fd is s[12]
                            try ctx.rc_curve_to(dx1, dy1, dx2, dy2, dx3, dy3);
                            try ctx.rc_curve_to(dx4, dy4, dx5, dy5, dx6, dy6);
                        },
                        Instruction.H_FLEX_1.raw() => { // 0x24
                            if (sp < 9) return error.h_flex_1_stack;
                            const dx1 = s[0];
                            const dy1 = s[1];
                            const dx2 = s[2];
                            const dy2 = s[3];
                            const dx3 = s[4];
                            const dx4 = s[5];
                            const dx5 = s[6];
                            const dy5 = s[7];
                            const dx6 = s[8];
                            try ctx.rc_curve_to(dx1, dy1, dx2, dy2, dx3, 0);
                            try ctx.rc_curve_to(dx4, 0, dx5, dy5, dx6, -(dy1 + dy2 + dy5));
                        },
                        Instruction.FLEX_1.raw() => { // 0x25
                            if (sp < 11) return error.flex_1_stack;
                            const dx1 = s[0];
                            const dy1 = s[1];
                            const dx2 = s[2];
                            const dy2 = s[3];
                            const dx3 = s[4];
                            const dy3 = s[5];
                            const dx4 = s[6];
                            const dy4 = s[7];
                            const dx5 = s[8];
                            const dy5 = s[9];
                            var dx6 = s[10];
                            var dy6 = s[10];
                            const dx = dx1 + dx2 + dx3 + dx4 + dx5;
                            const dy = dy1 + dy2 + dy3 + dy4 + dy5;
                            if (@abs(dx) > @abs(dy))
                                dy6 = -dy
                            else
                                dx6 = -dx;
                            try ctx.rc_curve_to(dx1, dy1, dx2, dy2, dx3, dy3);
                            try ctx.rc_curve_to(dx4, dy4, dx5, dy5, dx6, dy6);
                        },

                        else => return error.unimplemented,
                    }
                },
                else => {
                    if (b0 != 255 and b0 != 28 and b0 < 32)
                        return error.reserved_operator;

                    // push immediate
                    const f: f32 = if (b0 == 255)
                        @floatFromInt(@as(i32, @intCast(b.get32() / 0x10000)))
                    else blk: {
                        b.cursor -= 1;
                        break :blk @floatFromInt(@as(i16, @truncate(@as(i32, @bitCast(b.cff_int())))));
                    };
                    if (sp >= 48) return error.push_stack_overflow;
                    s[sp] = f;
                    sp += 1;
                    clear_stack = false;
                },
            }
            if (clear_stack) sp = 0;
        }
        return error.no_end_char;
    }

    fn get_glyph_subroutines(cff_data: *const CffData, glyph: GlyphIndex) DataBuf {
        var fdselector: u32 = std.math.maxInt(u32);
        var fdselect = cff_data.fdselect;
        fdselect.seek(0);

        const fmt = fdselect.get8();
        if (fmt == 0) {
            // untested
            fdselect.skip(@backingInt(glyph));
            fdselector = fdselect.get8();
        } else if (fmt == 3) {
            const nranges = fdselect.get16();
            var start = fdselect.get16();
            for (0..nranges) |_| {
                const v = fdselect.get8();
                const end = fdselect.get16();
                const glyph_int = @backingInt(glyph);
                if (glyph_int >= start and glyph_int < end) {
                    fdselector = v;
                    break;
                }
                start = end;
            }
        }
        //VERIFY what was this line? it does nothing. why was it in the original c code?
        // if (fdselector == -1) new_buf(NULL, 0);
        return cff_data.cff.get_subroutines(cff_data.fontdicts.cff_index_get(@fromBackingInt(@intCast(fdselector))));
    }
};

pub const ShapeConvertError = error{
    invalid_vertex_type,
};

pub fn convert_vertex_list_to_new_shape_with_userdata(vertex_list: *List(Vertex), comptime T: type, comptime EDGE_USERDATA: type, comptime EDGE_USERDATA_DEFAULT: EDGE_USERDATA, shape_allocator: Allocator) ShapeConvertError!Shape(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT) {
    var shape = Shape(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT).allocate_new(2, shape_allocator);
    try convert_vertex_list_to_shape(vertex_list, T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT, &shape, shape_allocator);
    return shape;
}

pub fn convert_vertex_list_to_new_shape(vertex_list: *List(Vertex), comptime T: type, shape_allocator: Allocator) ShapeConvertError!Shape(T, void, {}) {
    return convert_vertex_list_to_new_shape_with_userdata(vertex_list, T, void, {}, shape_allocator);
}

pub fn convert_vertex_list_to_shape(vertex_list: *List(Vertex), comptime T: type, shape: *Shape(T, void, {}), shape_allocator: Allocator) ShapeConvertError!void {
    return convert_vertex_list_to_shape_with_userdata(vertex_list, T, void, {}, shape, shape_allocator);
}

pub fn convert_vertex_list_to_shape_with_userdata(vertex_list: *List(Vertex), comptime T: type, comptime EDGE_USERDATA: type, comptime EDGE_USERDATA_DEFAULT: EDGE_USERDATA, shape: *Shape(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT), shape_allocator: Allocator) ShapeConvertError!void {
    const VEC = Vec2.define_vec2_type(T);
    const EDGE = ShapeModule.EdgeWithUserdata(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT);
    const CONTOUR = Contour(T, EDGE_USERDATA, EDGE_USERDATA_DEFAULT);
    var started_a_contour: bool = false;
    var p1: VEC = .ZERO;
    var curr_contour: CONTOUR = .allocate_new(8, shape_allocator);
    shape.clear(shape_allocator);
    for (vertex_list.zig_slice_entire()) |vert| {
        switch (vert.type) {
            .MOVE_TO => {
                if (started_a_contour) {
                    started_a_contour = false;
                    shape.append_contour(curr_contour, shape_allocator);
                    curr_contour = .allocate_new(8, shape_allocator);
                }
                p1 = Vec_f32.new_any(vert.x, vert.y);
            },
            .LINE => {
                started_a_contour = true;
                const p2 = Vec_f32.new_any(vert.x, vert.y);
                const edge = EDGE.new_line(p1, p2);
                curr_contour.append_edge(edge, shape_allocator);
                p1 = p2;
            },
            .QUADRATIC => {
                started_a_contour = true;
                const p2 = Vec_f32.new_any(vert.cx, vert.cy);
                const p3 = Vec_f32.new_any(vert.x, vert.y);
                const edge = EDGE.new_quadratic_bezier(p1, p2, p3);
                curr_contour.append_edge(edge, shape_allocator);
                p1 = p3;
            },
            .CUBIC => {
                started_a_contour = true;
                const p2 = Vec_f32.new_any(vert.cx, vert.cy);
                const p3 = Vec_f32.new_any(vert.cx1, vert.cy1);
                const p4 = Vec_f32.new_any(vert.x, vert.y);
                const edge = EDGE.new_cubic_bezier(p1, p2, p3, p4);
                curr_contour.append_edge(edge, shape_allocator);
                p1 = p4;
            },
            else => return ShapeConvertError.invalid_vertex_type,
        }
    }
    if (started_a_contour) {
        started_a_contour = false;
        shape.append_contour(curr_contour, shape_allocator);
    }
}

fn debug_set_cell_if_within_bounds(vert_x: i32, vert_y: i32, scale: f32, translate: Vec_f32, output_grid: DataGrid_u8, set_val: u8) void {
    var p = Vec_f32.new_any(vert_x, vert_y);
    p = p.scale(scale);
    p = p.add(translate);
    p = p.floor();
    const width: f32 = @floatFromInt(output_grid.width);
    const height: f32 = @floatFromInt(output_grid.height);
    if (p.x >= 0 and p.x < width and p.y >= 0 and p.y < height) {
        const p_int = p.to_new_type(u32);
        output_grid.set_cell(p_int.x, p_int.y, set_val);
    } else {
        std.debug.print("\nvertex out of bounds: x = {d: <5}, y = {d: <5}", .{ p.x, p.y });
    }
}

pub fn debug_rasterize_vertex_list_control_points_to_data_grid(vertices: *List(Vertex), output_grid: DataGrid_u8, scale: f32, translate: Vec_f32, empty_val: u8, point_val: u8) void {
    std.debug.print("\nDEBUGGING VERTEX LIST\noutput bitmap size    w = {d: <5}, h = {d: <5}", .{ output_grid.width, output_grid.height });
    output_grid.fill_all(empty_val);
    for (vertices.zig_slice_entire()) |vert| {
        switch (vert.type) {
            .MOVE_TO => {
                debug_set_cell_if_within_bounds(vert.x, vert.y, scale, translate, output_grid, point_val);
            },
            .LINE => {
                debug_set_cell_if_within_bounds(vert.x, vert.y, scale, translate, output_grid, point_val);
            },
            .QUADRATIC => {
                debug_set_cell_if_within_bounds(vert.cx, vert.cy, scale, translate, output_grid, point_val);
                debug_set_cell_if_within_bounds(vert.x, vert.y, scale, translate, output_grid, point_val);
            },
            .CUBIC => {
                debug_set_cell_if_within_bounds(vert.cx, vert.cy, scale, translate, output_grid, point_val);
                debug_set_cell_if_within_bounds(vert.cx1, vert.cy1, scale, translate, output_grid, point_val);
                debug_set_cell_if_within_bounds(vert.x, vert.y, scale, translate, output_grid, point_val);
            },
            else => {},
        }
    }
    std.debug.print("\n", .{});
}

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
    try font.shape_text("ABcdEfGg&ć", 2.0, &text_shape_list, alloc);
}
