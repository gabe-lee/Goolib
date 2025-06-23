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
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

pub const allocator = Allocator{
    .ptr = undefined,
    .vtable = &DUMMY_VTABLE,
};
pub const DUMMY_VTABLE = Allocator.VTable{
    .alloc = dummy_alloc,
    .resize = dummy_resize,
    .remap = dummy_remap,
    .free = dummy_free,
};
pub fn dummy_alloc(self: *anyopaque, len: usize, alignment: mem.Alignment, ret_addr: usize) ?[*]u8 {
    _ = self;
    _ = len;
    _ = alignment;
    _ = ret_addr;
    return null;
}
pub fn dummy_resize(self: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ret_addr: usize) bool {
    _ = self;
    _ = memory;
    _ = new_len;
    _ = alignment;
    _ = ret_addr;
    return false;
}
pub fn dummy_remap(self: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    _ = self;
    _ = memory;
    _ = new_len;
    _ = alignment;
    _ = ret_addr;
    return null;
}
pub fn dummy_free(self: *anyopaque, memory: []u8, alignment: mem.Alignment, ret_addr: usize) void {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = ret_addr;
    return;
}
