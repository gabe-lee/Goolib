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
const MathX = Root.Math;
const File = std.fs.File;
const Vec2 = Root.Vec2.define_vec2_type;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;
const read_int = std.mem.readInt;

pub const VecF32 = Vec2(f32);
pub const VecU32 = Vec2(u32);
pub const VecF16 = Vec2(f16);
pub const VecU16 = Vec2(u16);

pub const CURR_VERSION: u32 = 1;
pub const HEADER_SIZE = 16;
pub const IDENTIFIER_SIZE = 8;
pub const ENDIAN = std.builtin.Endian.little;
/// "RECT" in little-endian
pub const MAGIC: u32 = 0x54_43_45_52;
//                        T  C  E  R
pub const NATIVE_DATA_ALIGN = 4;

pub const FormatError = error{
    identifier_size_isnt_8_bytes,
    magic_file_format_identifier_wrong,
    version_in_file_exceeds_current_version_of_library,
    version_in_file_is_zero,
    header_size_isnt_16_bytes,
    point_format_does_not_match_any_valid_format,
    id_format_does_not_match_any_valid_format,
};



pub const Identifier = extern struct {
    magic: u32,
    version: u32,

    fn validate(self: Identifier) FormatError!void {
        if (self.magic != MAGIC) return FormatError.magic_file_format_identifier_wrong;
        if (self.version == 0) return FormatError.version_in_file_is_zero;
        if (self.version > CURR_VERSION) return FormatError.version_in_file_exceeds_current_version_in_library;
    }
};

pub fn parse_identifier(bytes: []const u8) FormatError!Identifier {
    if (bytes.len != IDENTIFIER_SIZE) return FormatError.identifier_size_isnt_8_bytes;
    const magic_ptr: *const [4]u8 = @ptrCast(bytes.ptr);
    const ver_ptr: *const [4]u8 = @ptrCast(bytes.ptr + 4);
    const ident = Identifier{
        .magic = read_int(u32, magic_ptr, ENDIAN),
        .version = read_int(u32, ver_ptr, ENDIAN),
    };
    try ident.validate();
    return ident;
}

pub const VersionInterfaces = struct {
    pub const Current = Version1;
    pub const Version1 = struct {
        pub const Format = enum(u8) {
            POINT_U32_ID_U32 = 0b01_001,
            POINT_F32_ID_U32 = 0b01_010,
            POINT_U16_ID_U32 = 0b01_011,
            POINT_F16_ID_U32 = 0b01_100,
            POINT_U32_ID_U16 = 0b10_001,
            POINT_F32_ID_U16 = 0b10_010,
            POINT_U16_ID_U16 = 0b10_011,
            POINT_F16_ID_U16 = 0b10_100,
            _,

            const POINT_MASK = 0b00_111;
            const POINT_MIN = 0b00_001;
            const POINT_MAX = 0b00_100;
            const ID_MASK = 0b11_000;
            const ID_MIN = 0b01_000;
            const ID_MAX = 0b10_000;

            pub fn validate(self: Format) FormatError!ValidFormat {
                const p: u8 = @intFromEnum(self) & POINT_MASK;
                if (p < POINT_MIN or p > POINT_MAX) return FormatError.point_format_does_not_match_any_valid_format;
                const i: u8 = @intFromEnum(self) & ID_MASK;
                if (i < ID_MIN or i > ID_MAX) return FormatError.id_format_does_not_match_any_valid_format;
                return @bitCast(self);
            }
        };

        pub const ValidFormat = enum(u8) {
            POINT_U32_ID_U32 = 0b01_001,
            POINT_F32_ID_U32 = 0b01_010,
            POINT_U16_ID_U32 = 0b01_011,
            POINT_F16_ID_U32 = 0b01_100,
            POINT_U32_ID_U16 = 0b10_001,
            POINT_F32_ID_U16 = 0b10_010,
            POINT_U16_ID_U16 = 0b10_011,
            POINT_F16_ID_U16 = 0b10_100,
        };

        pub const Header = struct {
            num_rects: u32,
            format: ValidFormat,
            _reserved: [11]u8 = @splat(0),

            pub const SIZE = @sizeOf(Header);

            pub fn parse_header(bytes: []const u8) FormatError!Header {
                if (bytes.len != HEADER_SIZE) return FormatError.header_size_isnt_16_bytes;
                const num_ptr: *const [4]u8 = @ptrCast(bytes.ptr);
                const format: Format = @enumFromInt(bytes.ptr[4]);
                const header = Header{
                    .num_rects = std.mem.readInt(u32, num_ptr, ENDIAN),
                    .format = try format.validate(),
                };
                return header;
            }

            pub fn read_header_from_file
        };

        pub fn 

        pub const TaggedRect_U32_U32 = struct {
            pos: VecU32,
            size: VecU32,
            tag: u32,
        };
        pub const TaggedRect_F32_U32 = struct {
            pos: VecF32,
            size: VecF32,
            tag: u32,
        };
        pub const TaggedRect_U16_U32 = struct {
            pos: VecU16,
            size: VecU16,
            tag: u32,
        };
        pub const TaggedRect_F16_U32 = struct {
            pos: VecF16,
            size: VecF16,
            tag: u32,
        };
        pub const TaggedRect_U32_U16 = struct {
            pos: VecU32,
            size: VecU32,
            tag: u16,
        };
        pub const TaggedRect_F32_U16 = struct {
            pos: VecF32,
            size: VecF32,
            tag: u16,
        };
        pub const TaggedRect_U16_U16 = struct {
            pos: VecU16,
            size: VecU16,
            tag: u16,
        };
        pub const TaggedRect_F16_U16 = struct {
            pos: VecF16,
            size: VecF16,
            tag: u16,
        };

        pub const TaggedRectSlice = union(ValidFormat) {
            POINT_U32_ID_U32: []TaggedRect_U32_U32,
            POINT_F32_ID_U32: []TaggedRect_F32_U32,
            POINT_U16_ID_U32: []TaggedRect_U16_U32,
            POINT_F16_ID_U32: []TaggedRect_F16_U32,
            POINT_U32_ID_U16: []TaggedRect_U32_U16,
            POINT_F32_ID_U16: []TaggedRect_F32_U16,
            POINT_U16_ID_U16: []TaggedRect_U16_U16,
            POINT_F16_ID_U16: []TaggedRect_F16_U16,
        };
    };
};

pub const TaggedRects = struct {
    pub const ValidFormat = VersionInterfaces.Current.ValidFormat;
    pub const Header = VersionInterfaces.Current.Header;
    pub const TaggedRectSlice = VersionInterfaces.Current.TaggedRectSlice;

    header: Header,
    rects: TaggedRectSlice,
    alloc_if_needed: ?Allocator,

    pub fn read_from_file(file: File) TaggedRects {}
};
