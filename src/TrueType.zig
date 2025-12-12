//! This is Largely a direct translation of stb_truetype.h
//!
//! Many of the methods/fields have be `zigified`
//!
//! Some features are not translated at all as they are deemed unneccessary,
//! are part of the stb_truetype legacy api, or are fulfilled by other portions of Goolib
//!
//! #### License: Zlib
//! #### Adapted From https://github.com/nothings/stb/blob/master/stb_truetype.h
//! #### License for original source from which this source was adapted: MIT or Public Domain (https://github.com/nothings/stb/blob/master/LICENSE)

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
const Vec2 = Root.Vec2;
const AABB2 = Root.AABB2;
const MathX = Root.Math;
const Bezier = Root.Bezier;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

pub const FontData = struct {
    data: []const u8,

    pub fn read_u8(self: FontData, offset: u32) u8 {
        return self.data[offset];
    }
    pub fn read_i8(self: FontData, offset: u32) i8 {
        return @bitCast(self.read_u8(offset));
    }
    pub fn read_u16(self: FontData, offset: u32) u16 {
        return (@as(u16, @intCast(self.data[offset])) << 8) + @as(u16, @intCast(self.data[offset + 1]));
    }
    pub fn read_i16(self: FontData, offset: u32) i16 {
        return @bitCast(self.read_u16(offset));
    }
    pub fn read_u32(self: FontData, offset: u32) u32 {
        return (@as(u32, @intCast(self.data[offset])) << 24) + (@as(u32, @intCast(self.data[offset + 1])) << 16) + (@as(u32, @intCast(self.data[offset + 2])) << 8) + @as(u32, @intCast(self.data[offset + 3]));
    }
    pub fn read_i32(self: FontData, offset: u32) i32 {
        return @bitCast(self.read_u32(offset));
    }
    pub fn read_N(self: FontData, offset: u32, size: u8) u32 {
        var i: u8 = 0;
        var o = offset;
        var v: u32 = 0;
        while (i < size) {
            v <<= 8;
            v |= @as(u32, @intCast(self.data[offset]));
            i += 1;
            o += 1;
        }
        return v;
    }
    pub fn has_tag_str(self: FontData, offset: u32, comptime tag: []const u8) void {
        return self.data[offset] == tag[0] and self.data[offset + 1] == tag[1] and self.data[offset + 2] == tag[2] and self.data[offset + 3] == tag[3];
    }
    pub fn has_tag_raw(self: FontData, offset: u32, comptime b0: u8, comptime b1: u8, comptime b2: u8, comptime b3: u8) bool {
        return self.data[offset] == b0 and self.data[offset + 1] == b1 and self.data[offset + 2] == b2 and self.data[offset + 3] == b3;
    }

    pub fn new_with_offset(self: FontData, offset: u32) FontData {
        assert_with_reason(offset < self.data.len, @src(), "cannot create sub FontData at offset {d}, total FontData length is {d}", .{ offset, self.data.len });
        return FontData{
            .data = self.data[offset..],
        };
    }
    pub fn new_with_offset_and_size(self: FontData, offset: u32, size: u32) FontData {
        assert_with_reason(offset + size <= self.data.len, @src(), "cannot create sub FontData at offset {d} with size {d} (end location = {d}), total FontData length is {d}", .{ offset, size, offset + size, self.data.len });
        return FontData{
            .data = self.data[offset .. offset + size],
        };
    }
    pub fn new_with_offset_and_end(self: FontData, offset: u32, end: u32) FontData {
        assert_with_reason(end <= self.data.len, @src(), "cannot create sub FontData at offset {d} with end {d}, total FontData length is {d}", .{ offset, end, self.data.len });
        return FontData{
            .data = self.data[offset..end],
        };
    }
};

pub const FontFile = struct {
    data: FontData,

    const TTFC_VERSION_OFFSET = 4;
    const TTFC_COUNT_OFFSET = 8;
    const TTFC_FONT_OFFSETS_OFFSET = 12;
    const TTFC_FONT_OFFSET_SIZE = 4;

    pub fn new(file_data: []const u8) FontFile {
        return FontFile{
            .data = FontData{ .data = file_data },
        };
    }

    pub fn get_font_count(self: FontFile) u32 {
        if (self.is_font()) {
            return 1;
        }
        if (self.has_tag_str("ttcf")) {
            const version: u32 = self.data.read_u32(TTFC_VERSION_OFFSET);
            if (version == 0x00010000 or version == 0x00020000) {
                const count: u32 = self.data.read_u32(TTFC_COUNT_OFFSET);
                return count;
            }
        }
        return 0;
    }
    pub fn get_font_index_offset(self: FontFile, index: u32) u32 {
        if (self.is_font()) {
            assert_with_reason(index == 0, @src(), "single font files only have an index 0 font, requested index {d}", .{index});
            return 0;
        }
        if (self.has_tag_str("ttcf")) {
            const version: u32 = self.data.read_u32(TTFC_VERSION_OFFSET);
            if (version == 0x00010000 or version == 0x00020000) {
                const count: u32 = self.data.read_u32(TTFC_COUNT_OFFSET);
                assert_with_reason(index < count, @src(), "this font collection only has {d} fonts, requested index {d}", .{ count, index });
                const offset: u32 = self.data.read_u32(TTFC_FONT_OFFSETS_OFFSET + (index * TTFC_FONT_OFFSET_SIZE));
                return offset;
            }
        }
        @panic("font file was either not a font file/collection, or had some unsupported format");
    }
    pub fn init_font_info_by_index(self: FontFile, index: u32, allocator: Allocator) FontInfo {
        const offset = self.get_font_index_offset(index);
        const data = self.data.new_with_offset(offset);
        return FontInfo.init(data, allocator);
    }

    pub fn has_tag_str(self: FontFile, comptime tag: []const u8) void {
        return self.data.has_tag_str(0, tag);
    }
    pub fn has_tag_raw(self: FontFile, comptime b0: u8, comptime b1: u8, comptime b2: u8, comptime b3: u8) bool {
        return self.data.has_tag_raw(0, b0, b1, b2, b3);
    }

    pub fn is_font(self: FontFile) bool {
        if (self.has_tag_raw('1', 0, 0, 0)) return true; // TrueType 1
        if (self.has_tag_str("typ1")) return true; // TrueType with type 1 font (unsupported)
        if (self.has_tag_str("OTTO")) return true; // OpenType with CFF
        if (self.has_tag_raw(0, 1, 0, 0)) return true; // OpenType 1.0
        if (self.has_tag_str("true")) return true; // Apple specification for TrueType fonts
        return false;
    }
};

fn assert_offset_size(off_size: anytype, src: ?std.builtin.SourceLocation) void {
    assert_with_reason(off_size >= 1 and off_size <= 4, src, "offset size MUST be between 1 and 4, got {d}", .{off_size});
}

const FontDataReader = struct {
    data: FontData,
    cursor: u32 = 0,

    pub fn len(self: FontDataReader) u32 {
        return @intCast(self.data.data.len);
    }

    pub fn new(base_data: FontData, offset: u32, size: u32) FontDataReader {
        return FontDataReader{
            .data = base_data.new_with_offset_and_size(offset, size),
        };
    }
    pub fn new_unknown_size(base_data: FontData, offset: u32) FontDataReader {
        return FontDataReader{
            .data = base_data.new_with_offset(offset),
        };
    }
    pub fn slice(self: FontDataReader, offset: u32, size: u32) FontDataReader {
        return FontDataReader{
            .data = self.data.new_with_offset_and_size(offset, size),
        };
    }
    pub fn slice_with_end(self: FontDataReader, offset: u32, end: u32) FontDataReader {
        return FontDataReader{
            .data = self.data.new_with_offset_and_end(offset, end),
        };
    }

    pub fn peek_u8(self: FontDataReader) u8 {
        return self.data.read_u8(self.cursor);
    }
    pub fn peek_i8(self: FontDataReader) i8 {
        return self.data.read_i8(self.cursor);
    }
    pub fn peek_u16(self: FontDataReader) u16 {
        return self.data.read_u16(self.cursor);
    }
    pub fn peek_i16(self: FontDataReader) i16 {
        return self.data.read_i16(self.cursor);
    }
    pub fn peek_u32(self: FontDataReader) u32 {
        return self.data.read_u32(self.cursor);
    }
    pub fn peek_i32(self: FontDataReader) i32 {
        return self.data.read_i32(self.cursor);
    }
    pub fn peek_N(self: FontDataReader, size: u8) u32 {
        return self.data.read_N(self.cursor, size);
    }
    pub fn read_u8(self: *FontDataReader) u8 {
        const val = self.data.read_u8(self.cursor);
        self.cursor += 1;
        return val;
    }
    pub fn read_i8(self: *FontDataReader) i8 {
        const val = self.data.read_i8(self.cursor);
        self.cursor += 1;
        return val;
    }
    pub fn read_u16(self: *FontDataReader) u16 {
        const val = self.data.read_u16(self.cursor);
        self.cursor += 2;
        return val;
    }
    pub fn read_i16(self: *FontDataReader) i16 {
        const val = self.data.read_i16(self.cursor);
        self.cursor += 2;
        return val;
    }
    pub fn read_u32(self: *FontDataReader) u32 {
        const val = self.data.read_u32(self.cursor);
        self.cursor += 4;
        return val;
    }
    pub fn read_i32(self: *FontDataReader) i32 {
        const val = self.data.read_i32(self.cursor);
        self.cursor += 4;
        return val;
    }
    pub fn read_N(self: *FontDataReader, size: u8) u32 {
        const val = self.data.read_N(self.cursor, size);
        self.cursor += @intCast(size);
        return val;
    }

    pub fn skip(self: *FontDataReader, n: u32) void {
        self.cursor += n;
    }
    pub fn goto(self: *FontDataReader, offset: u32) void {
        assert_with_reason(offset < self.data.data.len, @src(), "cannot goto (seek) to offset {d}, total FontData length is {d}", .{ offset, self.data.data.len });
        self.cursor = offset;
    }

    pub fn get_cff_index_count(self: *FontDataReader) u32 {
        self.goto(0);
        return @intCast(self.read_u16());
    }

    pub fn get_cff_index(self: *FontDataReader) FontDataReader {
        const start: u32 = self.cursor;
        const count: u16 = self.read_u16();
        if (count > 0) {
            const off_size = self.read_u8();
            assert_offset_size(off_size, @src());
            self.skip(MathX.upgrade_multiply_out(off_size, count, u32));
            const size = self.read_N(off_size);
            self.skip(size - 1);
        }
        return self.slice(start, self.cursor - start);
    }

    pub fn cff_index_get_subindex(self: *FontDataReader, idx: u32) FontDataReader {
        self.goto(0);
        const count = self.read_u16();
        const off_size = self.read_u8();
        if (idx >= count) std.debug.panic("invalid cff_index subindex `{d}`, total count is `{d}`", .{ idx, count });
        assert_offset_size(off_size, @src());
        self.skip(idx * off_size);
        const start = self.read_N(off_size);
        const end = self.read_N(off_size);
        return self.slice(2 + ((count + 1) * off_size) + start, end - start);
    }

    pub fn read_cff_integer(self: *FontDataReader) u32 {
        const b0 = self.read_u8();
        switch (b0) {
            32...246 => return @intCast(b0 - 139),
            247...250 => return (@as(u32, @intCast(b0 - 247)) << 8) + @as(u32, @intCast(self.read_u8())) + 108,
            251...254 => return (0 -% (@as(u32, @intCast(b0 - 251)) << 8)) - @as(u32, @intCast(self.read_u8())) - 108,
            28 => return @intCast(self.read_u16()),
            29 => return @intCast(self.read_u32()),
            else => @panic("invalid CFF integer format"),
        }
    }

    pub fn skip_cff_operand(self: *FontDataReader) void {
        var v: u8 = undefined;
        const b0 = self.peek_u8();
        if (b0 < 28) @panic("can only skip CFF operand when first byte is >= 28");
        if (b0 == 30) {
            self.skip(1);
            while (self.cursor < self.data.data.len) {
                v = self.read_u8();
                if ((v & 0xF) == 0xF or (v >> 4) == 0xF) {
                    break;
                }
            }
        } else {
            _ = self.read_cff_integer();
        }
    }

    pub fn get_cff_dict_by_key(self: *FontDataReader, key: u8) FontDataReader {
        self.goto(0);
        while (self.cursor < self.data.data.len) {
            const start = self.cursor;
            while (self.peek_u8() >= 28) {
                self.skip_cff_operand();
            }
            const end = self.cursor;
            var op = self.read_u8();
            if (op == 12) {
                op = self.read_u8() | 0x100;
            }
            if (op == key) return self.slice_with_end(start, end);
        }
        return self.slice(0, 0);
    }

    pub fn read_cff_dict_ints_by_key(self: *FontDataReader, key: u8, out_data: []u32) void {
        var operands = self.get_cff_dict_by_key(key);
        var i: usize = 0;
        while (i < out_data.len and operands.cursor < operands.data.data.len) {
            out_data[i] = operands.read_cff_integer();
            i += 1;
        }
    }

    pub fn get_cff_subroutines(self: *FontDataReader, font_dict: *FontDataReader) FontDataReader {
        var subroutine_off: u32 = 0;
        var private_loc: [2]u32 = .{ 0, 0 };
        var p_dict: FontDataReader = undefined;
        font_dict.read_cff_dict_ints_by_key(18, private_loc[0..]);
        if (private_loc[1] == 0 or private_loc[0] == 0) return self.slice(0, 0);
        p_dict = self.slice(private_loc[1], private_loc[0]);
        p_dict.read_cff_dict_ints_by_key(19, Utils.scalar_ptr_as_single_item_slice(&subroutine_off));
        if (subroutine_off == 0) return self.slice(0, 0);
        self.goto(private_loc[1] + subroutine_off);
        return self.get_cff_index();
    }
};

pub const FontInfoInitError = error{
    failed_to_find_table_cmap,
    failed_to_find_table_hhea,
    failed_to_find_table_head,
    failed_to_find_table_hmtx,
    had_table_glyf_failed_to_find_table_loca,
    cff_char_strings_type_isnt_2,
    cff_char_strings_offset_missing,
    had_fd_array_offset_but_missing_fd_select_offset,
    unsuported_cmap_platform_id,
    unsupported_cmap_micosoft_encoding,
    index_map_was_zero,
};

pub const FindGlyphIndexError = error{
    glyph_not_in_font,
    unsupported_index_map_format,
};

pub const FindGlyphOffsetError = error{
    glyph_index_out_of_bounds,
    unsupported_index_to_location_format,
    glyph_zero_length,
};
pub const FindGlyphShapeError = error{
    glyph_index_out_of_bounds,
    unsupported_index_to_location_format,
    glyph_zero_length,
};

const EdgeType = enum(u8) {
    linear,
    quadratic,
    cubic,
};

pub const VecI16 = Vec2.define_vec2_type(i16);
pub const Vertex = struct {
    start: VecI16 = .{},
    control_1: VecI16 = .{},
    control_2: VecI16 = .{},
    edge_type: EdgeType = .linear,
};

pub const FontInfo = struct {
    data: FontData,
    num_tables: u16 = 0,
    num_glyphs: u16 = 0,
    offset_HEAD: u32 = 0,
    offset_HHEA: u32 = 0,
    offset_HMTX: u32 = 0,
    offset_GLYF: ?u32 = null,
    offset_LOCA: ?u32 = null,
    offset_KERN: ?u32 = null,
    offset_GPOS: ?u32 = null,
    offset_SVG_: ?u32 = null,
    index_map_offset: u32 = 0,
    index_map_format: u16 = 0,
    index_to_location_format: u32 = 0,
    cff_data: FontDataReader,
    char_strings: FontDataReader,
    global_subroutines: FontDataReader,
    private_subroutines: FontDataReader,
    font_dicts: FontDataReader,
    fd_select: FontDataReader,

    const NUM_TABLES_OFFSET = 4;
    const TABLE_DIRECTORY_OFFSET = 12;
    const TABLE_DIRECTORY_ENTRY_SIZE = 16;
    const TABLE_DIRECTORY_ENTRY_TABLE_OFFSET = 8;

    pub fn find_table_offset(self: FontInfo, comptime table_tag: []const u8) ?u32 {
        var i: u32 = 0;
        var table_entry_offset = TABLE_DIRECTORY_OFFSET;
        while (i < self.num_tables) {
            if (self.data.has_tag_str(table_entry_offset, table_tag)) {
                return self.data.read_u32(table_entry_offset + TABLE_DIRECTORY_ENTRY_TABLE_OFFSET);
            }
            i += 1;
            table_entry_offset += TABLE_DIRECTORY_ENTRY_SIZE;
        }
        return null;
    }

    pub fn init(font_data: FontData) FontInfoInitError!FontInfo {
        var self = FontInfo{
            .data = font_data,
            .cff_data = FontDataReader.new(font_data, 0, 0),
            .char_strings = FontDataReader.new(font_data, 0, 0),
            .global_subroutines = FontDataReader.new(font_data, 0, 0),
            .private_subroutines = FontDataReader.new(font_data, 0, 0),
            .font_dicts = FontDataReader.new(font_data, 0, 0),
            .fd_select = FontDataReader.new(font_data, 0, 0),
        };
        self.num_tables = self.data.read_u16(NUM_TABLES_OFFSET);
        const cmap_offset = self.find_table_offset("cmap") orelse return FontInfoInitError.failed_to_find_table_cmap;
        self.offset_HHEA = self.find_table_offset("hhea") orelse return FontInfoInitError.failed_to_find_table_hhea;
        self.offset_HEAD = self.find_table_offset("head") orelse return FontInfoInitError.failed_to_find_table_head;
        self.offset_HMTX = self.find_table_offset("hmtx") orelse return FontInfoInitError.failed_to_find_table_hmtx;
        self.offset_LOCA = self.find_table_offset("loca");
        self.offset_GLYF = self.find_table_offset("glyf");
        self.offset_KERN = self.find_table_offset("kern");
        self.offset_GPOS = self.find_table_offset("GPOS");

        if (self.offset_GLYF != null) {
            if (self.offset_LOCA == null) return FontInfoInitError.had_table_glyf_failed_to_find_table_loca;
        } else {
            var char_strings_type: u32 = 2;
            var char_strings: u32 = 0;
            var fd_array_offset: u32 = 0;
            var fd_select_offset: u32 = 0;
            const cff_offset: u32 = self.find_table_offset("CFF ") orelse assert_unreachable(@src(), "table `CFF ` is required for CFF/ Type2 fonts (OTF) but the font did not have it", .{});
            self.cff_data = FontDataReader.new_unknown_size(self.data, cff_offset);
            self.cff_data.skip(2);
            const cff_header_size = self.cff_data.peek_u8();
            self.cff_data.goto(cff_header_size);
            _ = self.cff_data.get_cff_index(); // skip the NAME index
            var top_dict_idx = self.cff_data.get_cff_index();
            var top_dict = top_dict_idx.cff_index_get_subindex(0);
            _ = self.cff_data.get_cff_index(); // skip the STRING index
            self.global_subroutines = self.cff_data.get_cff_index();
            top_dict.read_cff_dict_ints_by_key(17, Utils.scalar_ptr_as_single_item_slice(&char_strings));
            top_dict.read_cff_dict_ints_by_key(0x100 | 6, Utils.scalar_ptr_as_single_item_slice(&char_strings_type));
            top_dict.read_cff_dict_ints_by_key(0x100 | 36, Utils.scalar_ptr_as_single_item_slice(&fd_array_offset));
            top_dict.read_cff_dict_ints_by_key(0x100 | 37, Utils.scalar_ptr_as_single_item_slice(&fd_select_offset));
            self.private_subroutines = self.cff_data.get_cff_subroutines(&top_dict);
            if (char_strings_type != 2) return FontInfoInitError.cff_char_strings_type_isnt_2;
            if (char_strings == 0) return FontInfoInitError.cff_char_strings_offset_missing;
            if (fd_array_offset != 0) {
                if (fd_select_offset == 0) return FontInfoInitError.had_fd_array_offset_but_missing_fd_select_offset;
                self.cff_data.goto(fd_array_offset);
                self.font_dicts = self.cff_data.get_cff_index();
                self.fd_select = self.cff_data.slice(fd_select_offset, self.cff_data.len() - fd_select_offset);
            }
            self.cff_data.goto(char_strings);
            self.char_strings = self.cff_data.get_cff_index();
            self.cff_data.goto(0);
        }

        const maxp_table_offset = self.find_table_offset("maxp");
        if (maxp_table_offset) |off| {
            self.num_glyphs = self.data.read_u16(off + 4);
        } else {
            self.num_glyphs = 0xFFFF;
        }

        const cmap_num_tables = self.data.read_u16(cmap_offset + 2);
        var i: u32 = 0;
        while (i < cmap_num_tables) {
            const encoding_record_offset = cmap_offset + 4 + (8 * i);
            const encoding_record = self.data.read_u16(encoding_record_offset);
            switch (encoding_record) {
                PLATOFRM_ID.MICROSOFT => {
                    const encoding_id = self.data.read_u16(encoding_record_offset + 2);
                    switch (encoding_id) {
                        MICROSOFT_ENCODING_ID.UNICODE_BMP, MICROSOFT_ENCODING_ID.UNICODE_FULL => {
                            self.index_map_offset = cmap_offset + self.data.read_u32(encoding_record_offset + 4);
                        },
                        else => return FontInfoInitError.unsupported_cmap_micosoft_encoding,
                    }
                },
                PLATOFRM_ID.UNICODE => {
                    self.index_map_offset = cmap_offset + self.data.read_u32(encoding_record_offset + 4);
                },
                else => return FontInfoInitError.unsuported_cmap_platform_id,
            }
            i += 1;
        }
        if (self.index_map_offset == 0) return FontInfoInitError.index_map_was_zero;
        self.@"index_to_loc_format >= 2" = self.data.read_u16(self.offset_HEAD + 50);
        self.index_map_format = self.data.read_u16(self.index_map_offset);
        return self;
    }

    pub fn find_glyph_index(self: FontInfo, unicode_codepoint: u32) FindGlyphIndexError!u32 {
        switch (self.index_map_format) {
            0 => {
                const bytes = self.data.read_u16(self.index_map_offset + 2);
                if (unicode_codepoint < bytes - 6) {
                    return @intCast(self.data.read_u8(self.index_map_offset + 6 + unicode_codepoint));
                } else {
                    return FindGlyphIndexError.glyph_not_in_font;
                }
            },
            2 => {
                return FindGlyphIndexError.unsupported_index_map_format;
            },
            4 => {
                const segment_count = self.data.read_u16(self.index_map_offset + 6) >> 1;
                const segment_count_2 = segment_count << 1;
                const segment_count_4 = segment_count << 2;
                const segment_count_6 = segment_count * 6;
                const search_range = self.data.read_u16(self.index_map_offset + 8) >> 1;
                const entry_selector = self.data.read_u16(self.index_map_offset + 10);
                const range_shift = self.data.read_u16(self.index_map_offset + 12) >> 1;
                const range_shift_2 = range_shift << 1;
                const end_count_offset = self.index_map_offset + 14;
                const search_offset = end_count_offset;
                if (unicode_codepoint > 0xFFFF) return FindGlyphIndexError.glyph_not_in_font;
                if (unicode_codepoint > self.data.read_u16(search_offset + (range_shift_2))) {
                    search_offset += range_shift_2;
                }
                search_offset -= 2;
                while (entry_selector != 0) {
                    search_range >>= 1;
                    const search_range_2 = search_range << 1;
                    const end_codepoint = self.data.read_u16(search_offset + search_range_2);
                    if (unicode_codepoint > end_codepoint) {
                        search_offset += search_range_2;
                    }
                    entry_selector -= 1;
                }
                search_offset += 2;

                const item_offset: u16 = ((search_offset - end_count_offset) >> 1);
                const item_offset_2 = item_offset << 1;
                const first_codepoint = self.data.read_u16(end_count_offset + segment_count_2 + 2 + item_offset_2);
                const last_codepoint = self.data.read_u16(end_count_offset + segment_count_2 + 2 + item_offset_2);
                if (unicode_codepoint < first_codepoint or unicode_codepoint > last_codepoint) {
                    return FindGlyphIndexError.glyph_not_in_font;
                }
                const glyph_offset = self.data.read_u16(end_count_offset + segment_count_6 + 2 + item_offset_2);
                if (glyph_offset == 0) {
                    return @intCast(Types.intcast(unicode_codepoint, i16) + self.data.read_i16(end_count_offset + segment_count_4 + 2 + item_offset_2));
                } else {
                    return @intCast(self.data.read_u16(glyph_offset + ((unicode_codepoint - first_codepoint) << 1) + end_count_offset + segment_count_6 + 2 + item_offset_2));
                }
            },
            6 => {
                const first_codepoint = self.data.read_u16(self.index_map_offset + 6);
                const count = self.data.read_u16(self.index_map_offset + 8);
                const last_codepoint = first_codepoint + count - 1;
                if (unicode_codepoint < first_codepoint or unicode_codepoint > last_codepoint) {
                    return FindGlyphIndexError.glyph_not_in_font;
                } else {
                    return @intCast(self.data.read_u16(self.index_map_offset + 10 + ((unicode_codepoint - first_codepoint) << 1)));
                }
            },
            12, 13 => {
                const num_groups = self.data.read_u32(self.index_map_offset + 12);
                var lo: u32 = 0;
                var hi = num_groups;
                const index_map_plus_16 = self.index_map_offset + 16;
                const index_map_plus_20 = self.index_map_offset + 20;
                const index_map_plus_24 = self.index_map_offset + 14;
                while (lo < hi) {
                    const mid = lo + ((hi - lo) >> 1);
                    const mid_times_12 = mid * 12;
                    const first_codepoint_in_group = self.data.read_u32(index_map_plus_16 + mid_times_12);
                    const last_codepoint_in_group = self.data.read_u32(index_map_plus_20 + mid_times_12);
                    if (unicode_codepoint < first_codepoint_in_group) {
                        hi = mid;
                    } else if (unicode_codepoint > last_codepoint_in_group) {
                        lo = mid + 1;
                    } else {
                        const first_glyph_index = self.data.read_u32(index_map_plus_24 + mid_times_12);
                        if (self.index_map_format == 12) {
                            return first_glyph_index + (unicode_codepoint - first_codepoint_in_group);
                        } else {
                            return first_codepoint_in_group;
                        }
                    }
                }
                return FindGlyphIndexError.glyph_not_in_font;
            },
            else => return FindGlyphIndexError.unsupported_index_map_format,
        }
    }

    pub fn get_glyph_offset(self: FontInfo, glyph_index: u32) FindGlyphOffsetError!u32 {
        var glyph_offset_1: u32 = undefined;
        var glyph_offset_2: u32 = undefined;
        if (glyph_index >= self.num_glyphs) return FindGlyphOffsetError.glyph_index_out_of_bounds;
        if (self.index_to_location_format >= 2) return FindGlyphOffsetError.unsupported_index_to_location_format;
        switch (self.index_to_location_format) {
            0 => {
                const glyph_index_2 = glyph_index << 1;
                glyph_offset_1 = self.offset_GLYF.? + (Types.intcast(self.data.read_u16(self.offset_LOCA.? + glyph_index_2), u32) << 1);
                glyph_offset_2 = self.offset_GLYF.? + (Types.intcast(self.data.read_u16(self.offset_LOCA.? + glyph_index_2 + 2), u32) << 1);
            },
            1 => {
                const glyph_index_4 = glyph_index << 2;
                glyph_offset_1 = self.offset_GLYF.? + self.data.read_u32(self.offset_LOCA.? + glyph_index_4);
                glyph_offset_2 = self.offset_GLYF.? + self.data.read_u32(self.offset_LOCA.? + glyph_index_4 + 4);
            },
            else => unreachable,
        }
        if (glyph_offset_1 == glyph_offset_2) return FindGlyphOffsetError.glyph_zero_length;
        return glyph_offset_1;
    }

    pub fn get_glyph_shape_from_index(self: FontInfo, glyph_index: u32, allocator: Allocator) FindGlyphShapeError![]Vertex {
        if (self.cff_data.len() == 0) {
            return self.get_glyph_shape_true_type(glyph_index, allocator);
        } else {
            return self.get_glyph_shape_type_2(glyph_index, allocator);
        }
    }

    fn get_glyph_shape_true_type(self: *FontInfo, glyph_index: u32, allocator: Allocator) FindGlyphShapeError![]Vertex {
        var num_vertexes: u32 = 0;
        var end_of_contours_offset: u32 = undefined;
        const glyph_offset = try self.get_glyph_offset(glyph_index);
        const num_contours = self.data.read_i16(glyph_offset);
        const num_contours_2 = num_contours << 1;
        if (num_contours > 0) {
            var flags: u8 = 0;
            var flag_count: u8 = 0;
            end_of_contours_offset = glyph_offset + 10;
            var ins: u32 = undefined;
            var i: u32 = undefined;
            var j: u32 = 0;
            var m: u32 = undefined;
            var n: u32 = undefined;
            var next_move: u32 = undefined;
            var was_off: u32 = 0;
            var off: u32 = undefined;
            var start_off: u32 = 0;
            var x: i32 = undefined;
            var y: i32 = undefined;
            var cx: i32 = undefined;
            var cy: i32 = undefined;
            var sx: i32 = undefined;
            var sy: i32 = undefined;
            var scx: i32 = undefined;
            var scy: i32 = undefined;
            //CHECKPOINT
        }
    }
    fn get_glyph_shape_type_2(self: *FontInfo, glyph_index: u32, allocator: Allocator) FindGlyphShapeError![]Vertex {}
};

const PLATOFRM_ID = struct {
    pub const UNICODE = 0;
    pub const MAC = 1;
    pub const ISO = 2;
    pub const MICROSOFT = 3;
};

const MICROSOFT_ENCODING_ID = struct {
    pub const SYMBOL = 0;
    pub const UNICODE_BMP = 1;
    pub const SHIFT_JIS = 2;
    pub const UNICODE_FULL = 3;
};
