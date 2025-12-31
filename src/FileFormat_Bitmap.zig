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
const BitmapModule = Root.Bitmap;
const Bitmap = BitmapModule.Bitmap;
const BitmapDef = BitmapModule.BitmapDefinition;
const File = std.fs.File;
const Resulution = Root.ImageUtils.Reslution_DPM(u32);

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

pub const YOrder = BitmapModule.YOrder;
pub const XOrder = BitmapModule.XOrder;

pub const BitsPerPixel = enum(u16) {
    BPP_1 = 1,
    BPP_4 = 4,
    BPP_8 = 8,
    BPP_16 = 16,
    BPP_24 = 24,
    BPP_32 = 32,

    pub fn bytes_per_pixel(self: BitsPerPixel) u32 {
        return @as(u32, @intCast(@intFromEnum(self))) >> 3;
    }
    pub fn raw(self: BitsPerPixel) u16 {
        return @intFromEnum(self);
    }
};

pub const CompressionMode = enum(u32) {
    NONE = 0,
    RUN_LENGTH_4_BIT = 1,
    RUN_LENGTH_8_BIT = 2,
    BIT_FIELDS = 3,
};

pub const ColorSpace = enum(u32) {
    CALIBRATED_RGB = 0,
    LCS_WINDOWS = 0x57696e20, // 'Win '
    SRGB = 0x73524742, // 'sRGB'
    PROFILE_LINKED = 0x4C494E4B, // 'LINK'
    PROFILE_EMBEDDED = 0x4D424544, // 'MBED'
};

pub const ImageIntent = enum(u32) {
    BUSINESS = 1,
    GRAPHICS = 2,
    IMAGES = 4,
    ABS_COLORIMETRIC = 8,
};

pub const Compression = union(CompressionMode) {
    NONE: void,
    RUN_LENGTH_4_BIT: void,
    RUN_LENGTH_8_BIT: void,
    BIT_FIELDS: BitfieldMasks,

    pub fn none() Compression {
        return Compression{ .NONE = void{} };
    }
    pub fn run_length_4_bit() Compression {
        return Compression{ .RUN_LENGTH_4_BIT = void{} };
    }
    pub fn run_length_8_bit() Compression {
        return Compression{ .RUN_LENGTH_8_BIT = void{} };
    }
    pub fn bit_fields(masks: BitfieldMasks) Compression {
        return Compression{ .BITFIELDS = masks };
    }
};

pub const BitfieldMasks = struct {
    red_mask: u32 = 0,
    green_mask: u32 = 0,
    blue_mask: u32 = 0,
    alpha_mask: u32 = 0,

    pub fn new_rgba(red: u32, green: u32, blue: u32, alpha: u32) BitfieldMasks {
        return BitfieldMasks{
            .red_mask = red,
            .green_mask = green,
            .blue_mask = blue,
            .alpha_mask = alpha,
        };
    }
    pub fn new_bgra(blue: u32, green: u32, red: u32, alpha: u32) BitfieldMasks {
        return BitfieldMasks{
            .red_mask = red,
            .green_mask = green,
            .blue_mask = blue,
            .alpha_mask = alpha,
        };
    }
    pub fn new_argb(alpha: u32, red: u32, green: u32, blue: u32) BitfieldMasks {
        return BitfieldMasks{
            .red_mask = red,
            .green_mask = green,
            .blue_mask = blue,
            .alpha_mask = alpha,
        };
    }
    pub fn new_abgr(alpha: u32, blue: u32, green: u32, red: u32) BitfieldMasks {
        return BitfieldMasks{
            .red_mask = red,
            .green_mask = green,
            .blue_mask = blue,
            .alpha_mask = alpha,
        };
    }
};

pub const BitmapSaveSettings = struct {
    bits_per_pixel: BitsPerPixel = .BPP_32,
    color_planes: u16 = 1,
    color_space: ColorSpace = .SRGB,
    compression: Compression = Compression{ .NONE = void{} },
    horizontal_resolution: Resulution = Resulution.new_dpi(72),
    vertical_resolution: Resulution = Resulution.new_dpi(72),
    colors_in_palette: u32 = 0,
    important_colors_in_palette: u32 = 0,
    color_space_type: ColorSpace = .LINEAR,
    intent: ImageIntent = .GRAPHICS,
};

const BMP_CORE_HEADER_SIZE = 14;
const BMP_DIB_HEADER_V5_SIZE = 124;

const IndexPixelEnum = enum(u8) {
    index,
};

const PAD_BYTES = [4]u8{ 0, 0, 0, 0 };

pub fn save_bitmap_to_file(file: *File, comptime BITMAP_DEF: BitmapDef, bitmap: Bitmap(BITMAP_DEF), settings: BitmapSaveSettings, alloc: Allocator) u32 {
    assert_with_reason(settings.color_planes == 1, @src(), "color planes other than `1` (non-interleaved color channels) not implemented/supported, got `{d}`", .{settings.color_planes});
    assert_with_reason(settings.compression == .NONE, @src(), "color compression mode `{s}` not implemented/supported", .{@tagName(settings.compression)});
    assert_with_reason(settings.color_space != .CALIBRATED_RGB, @src(), "color space modes `CALIBRATED_RGB` not implemented/supported", .{});
    assert_with_reason(settings.color_space != .PROFILE_LINKED and settings.color_space != .PROFILE_EMBEDDED, @src(), "color space modes `PROFILE_LINKED` and `PROFILE_EMBEDDED` not implemented/supported (ICC color profiles)", .{});
    const IDX_BMP_DEF = BitmapDef{
        .CHANNEL_TYPE = u8,
        .CHANNELS_ENUM = IndexPixelEnum,
        .ROW_COLUMN_ORDER = .row_major,
        .X_ORDER = .left_to_right,
        .Y_ORDER = .bottom_to_top,
    };
    const ColorPalettePixel = Root.Color.define_arbitrary_color_type(u8, BitmapModule.BGRA_Channels);
    const IDX_BMP = Bitmap(IDX_BMP_DEF);
    var color_palette: [256]ColorPalettePixel = undefined;
    var color_palette_list = List(ColorPalettePixel){
        .cap = 256,
        .len = 0,
        .ptr = color_palette[0..].ptr,
    };
    var index_map: IDX_BMP = .{};
    defer index_map.free(alloc);
    var size: u32 = BMP_CORE_HEADER_SIZE + BMP_DIB_HEADER_V5_SIZE;
    const bytes_per_advance: u32 = switch (settings.bits_per_pixel) {
        .BPP_1, .BPP_4, .BPP_8 => 1,
        .BPP_16 => 2,
        .BPP_24 => 3,
        .BPP_32 => 4,
    };
    const pixels_per_advance: u32 = switch (settings.bits_per_pixel) {
        .BPP_1 => 8,
        .BPP_4 => 2,
        .BPP_8 => 1,
        .BPP_16 => 1,
        .BPP_24 => 1,
        .BPP_32 => 1,
    };
    var pixel_row_byte_width = undefined;
    var pixel_data_offset: u32 = undefined;
    var gap_before_pixel_data: u32 = 0;
    if (settings.bits_per_pixel.raw() <= 8) {
        const idx_width_naive = bitmap.width / pixels_per_advance;
        const idx_width = idx_width_naive + (if ((idx_width_naive * pixels_per_advance) < bitmap.width) 1 else 0);
        const idx_height = bitmap.height;
        index_map = IDX_BMP.init(idx_width, idx_height, alloc);
        var index_pixel_bit: u8 = 0;
        var curr_index_pixel: u8 = 0;
        var y: u32 = 0;
        var px: u32 = 0;
        var ix: u32 = 0;
        while (y < bitmap.width) : (y += 1) {
            px = 0;
            ix = 0;
            while (px < bitmap.width) : (px += 1) {
                const original_pixel = bitmap.get_pixel_with_origin(.bot_left, px, y);
                const transformed_pixel: ColorPalettePixel = original_pixel.reorder_channels_to(BitmapModule.BGRA_Channels).cast_values_normalized_to(u8);
                const color_palette_index = color_palette_list.search(transformed_pixel, ColorPalettePixel.implicit_equals);
                if (!color_palette_index.found) {
                    color_palette_index.idx = color_palette_list.len;
                    color_palette_list.len += 1;
                    color_palette_list.ptr[color_palette_index.idx] = transformed_pixel;
                }
                const color_index: u8 = @intCast(color_palette_index.idx);
                const shifted_color_index = color_index << @intCast(index_pixel_bit);
                curr_index_pixel |= shifted_color_index;
                index_pixel_bit += @intCast(settings.bits_per_pixel.raw());
                if (index_pixel_bit >= 8) {
                    const index_pixel_ptr: *u8 = index_map.get_pixel_channel_ptr_with_origin(.bot_left, ix, y, .index);
                    index_pixel_ptr.* = curr_index_pixel;
                    ix += 1;
                    index_pixel_bit = 0;
                    curr_index_pixel = 0;
                }
            }
        }
        size += color_palette_list.len * 4;
        const last_size = size;
        size = std.mem.alignForward(u32, size, 4);
        gap_before_pixel_data = size - last_size;
        pixel_data_offset = size;
        pixel_row_byte_width = index_map.width;
    } else {
        const last_size = size;
        size = std.mem.alignForward(u32, size, 4);
        gap_before_pixel_data = size - last_size;
        pixel_data_offset = size;
        const whole_advances_per_width = bitmap.width / pixels_per_advance;
        const total_advances_per_width = whole_advances_per_width + (if ((whole_advances_per_width * pixels_per_advance) < bitmap.width) 1 else 0);
        pixel_row_byte_width = total_advances_per_width * bytes_per_advance;
    }
    const row_stride_byte_width = std.mem.alignForward(u32, pixel_row_byte_width, 4);
    const gap_after_row = row_stride_byte_width - pixel_row_byte_width;
    const total_pixel_data_length = row_stride_byte_width * bitmap.height;
    size += total_pixel_data_length;
    file.seekTo(0);
    var buf: [1024]u8 = undefined;
    const writer_holder = file.writer(buf[0..]);
    var writer = writer_holder.interface;
    // Core header
    writer.writeByte('B');
    writer.writeByte('M');
    writer.writeInt(u32, size, .little);
    writer.writeByte('G'); // These 4 bytes are unused, might as well sign the library
    writer.writeByte('O');
    writer.writeByte('O');
    writer.writeByte(' ');
    writer.writeInt(u32, pixel_data_offset, .little);
    // DIB V5 header
    writer.writeInt(u32, BMP_DIB_HEADER_V5_SIZE, .little);
    writer.writeInt(u32, bitmap.width, .little);
    writer.writeInt(u32, bitmap.height, .little);
    writer.writeInt(u32, settings.color_planes, .little);
    writer.writeInt(u32, settings.bits_per_pixel.raw(), .little);
    writer.writeInt(u32, @intFromEnum(settings.compression), .little);
    writer.writeInt(u32, total_pixel_data_length, .little);
    writer.writeInt(u32, settings.horizontal_resolution.raw, .little);
    writer.writeInt(u32, settings.vertical_resolution.raw, .little);
    writer.writeInt(u32, color_palette_list.len, .little);
    writer.writeInt(u32, 0, .little);
    switch (settings.compression) {
        .BIT_FIELDS => |fields| {
            writer.writeInt(u32, fields.red_mask, .little);
            writer.writeInt(u32, fields.green_mask, .little);
            writer.writeInt(u32, fields.blue_mask, .little);
            writer.writeInt(u32, fields.alpha_mask, .little);
        },
        else => {
            writer.writeInt(u32, 0, .little);
            writer.writeInt(u32, 0, .little);
            writer.writeInt(u32, 0, .little);
            writer.writeInt(u32, 0, .little);
        },
    }
    writer.writeInt(u32, @intFromEnum(settings.color_space), .little);
    inline for (0..9) |_| {
        // Color space endpoints
        //TODO support these
        writer.writeInt(u32, 0, .little);
    }
    writer.writeInt(u32, 0, .little); // gamma red
    writer.writeInt(u32, 0, .little); // gamma rgreen
    writer.writeInt(u32, 0, .little); // gamma blue
    writer.writeInt(u32, @intFromEnum(settings.intent), .little);
    writer.writeInt(u32, 0, .little); // icc profile data offset from V5 header
    writer.writeInt(u32, 0, .little); // icc profile size
    writer.writeInt(u32, 0, .little); // reserved
    // Color Palette (if used)
    for (color_palette_list.slice()) |color| {
        const raw: u32 = @bitCast(color.raw);
        writer.writeInt(u32, raw, .little);
    }
    writer.write(PAD_BYTES[0..gap_before_pixel_data]);
    // Pixel Data
    if (settings.bits_per_pixel.raw() <= 8) {
        var y: u32 = 0;
        while (y < index_map.height) : (y += 1) {
            const row = index_map.get_h_scanline_with_origin(.bot_left, 0, y, .left_to_right, index_map.width);
            const row_bytes = std.mem.sliceAsBytes(row);
            writer.write(row_bytes);
            writer.write(PAD_BYTES[0..gap_after_row]);
        }
    } else {
        var y: u32 = 0;
        var x: u32 = undefined;
        while (y < bitmap.height) : (y += 1) {
            x = 0;
            while (x < bitmap.width) : (x += 1) {
                const original_pixel = bitmap.get_pixel_with_origin(.bot_left, x, y);
                switch (settings.bits_per_pixel) {
                    .BPP_32 => {
                        const transformed_pixel = original_pixel.reorder_channels_to(BitmapModule.BGRA_Channels).cast_values_normalized_to(u8);
                        writer.writeInt(u32, @bitCast(transformed_pixel.raw), .little);
                    },
                    .BPP_24 => {
                        const transformed_pixel = original_pixel.reorder_channels_to(BitmapModule.BGR_Channels).cast_values_normalized_to(u8);
                        writer.writeByte(transformed_pixel.raw[0]);
                        writer.writeByte(transformed_pixel.raw[1]);
                        writer.writeByte(transformed_pixel.raw[2]);
                    },
                    else => assert_unreachable(@src(), "invalid bits-per-pixel at this branch `{s}`", .{@tagName(settings.bits_per_pixel)}),
                }
            }
            writer.write(PAD_BYTES[0..gap_after_row]);
        }
    }
}
