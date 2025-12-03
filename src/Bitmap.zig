//! //TODO Documentation
//! #### License: Zlib
//! #### License for original source from which this source was adapted: MIT (https://github.com/Chlumsky/msdfgen/blob/master/LICENSE.txt)

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

pub const YOrientaion = enum(u8) {
    top_down,
    bottom_up,
};

pub const ResizeAnchor = enum(u8) {
    top_left,
    top_center,
    top_right,
    middle_left,
    middle_center,
    middle_right,
    bottom_left,
    bottom_center,
    bottom_right,
};

const ResizeEffect = enum(u8) {
    shrink,
    no_change,
    grow,
};

pub fn Bitmap(comptime CHANNEL_UINT: type, comptime CHANNELS_ENUM: type) type {
    return struct {
        const Self = @This();

        pixels: [*]Pixel,
        width: usize = 0,
        height: usize = 0,

        pub const Pixel = Color_.define_arbitrary_color_type(CHANNEL_UINT, CHANNELS_ENUM);
        pub const NUM_CHANNELS = Pixel.CHANNEL_COUNT;
        pub const PIXEL_STRIDE = Pixel.BYTE_SIZE;

        pub fn init(width: usize, height: usize, alloc: Allocator) Self {
            const total = width * height * PIXEL_STRIDE;
            const mem = alloc.alloc(Pixel, total) catch |err| Assert.assert_allocation_failure(@src(), Pixel, total, err);
            return Self{
                .pixels = mem.ptr,
                .width = width,
                .height = height,
            };
        }
        pub fn free(self: Self, alloc: Allocator) void {
            const total = self.width * self.height * PIXEL_STRIDE;
            alloc.free(self.pixels[0..total]);
        }

        pub fn get_idx(self: Self, x: usize, y: usize) usize {
            return x + (y * self.width);
        }
        pub fn get_pixel(self: Self, x: usize, y: usize) Pixel {
            const idx = self.get_idx(x, y);
            return self.pixels[idx];
        }
        pub fn set_pixel(self: Self, x: usize, y: usize, val: Pixel) void {
            const idx = self.get_idx(x, y);
            self.pixels[idx] = val;
        }

        pub fn resize(self: Self, new_width: usize, new_height: usize, anchor: ResizeAnchor, alloc: Allocator) Self {
            var w_delta: usize = undefined;
            var w_shrink: bool = undefined;
            var h_delta: usize = undefined;
            var h_shrink: bool = undefined;
            if (new_width < self.width) 
        }
    };
}
