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

const Root = @import("./_root.zig");

const Assert = Root.Assert;

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
pub fn dummy_alloc(_: *anyopaque, _: usize, _: mem.Alignment, _: usize) ?[*]u8 {
    return null;
}
pub fn dummy_resize(_: *anyopaque, _: []u8, _: mem.Alignment, _: usize, _: usize) bool {
    return false;
}
pub fn dummy_remap(_: *anyopaque, _: []u8, _: mem.Alignment, _: usize, _: usize) ?[*]u8 {
    return null;
}
pub fn dummy_free(_: *anyopaque, _: []u8, _: mem.Alignment, _: usize) void {
    return;
}

pub const allocator_shrink_only = Allocator{
    .ptr = undefined,
    .vtable = &DUMMY_VTABLE_SHRINK_ONLY,
};
pub const DUMMY_VTABLE_SHRINK_ONLY = Allocator.VTable{
    .alloc = dummy_alloc,
    .resize = dummy_resize_shrink_only,
    .remap = dummy_remap_shrink_only,
    .free = dummy_free,
};
pub fn dummy_resize_shrink_only(_: *anyopaque, memory: []u8, _: mem.Alignment, new_len: usize, _: usize) bool {
    return new_len <= memory.len;
}
pub fn dummy_remap_shrink_only(_: *anyopaque, memory: []u8, _: mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
    if (new_len <= memory.len) return memory.ptr;
    return null;
}

pub const allocator_panic = Allocator{
    .ptr = undefined,
    .vtable = &DUMMY_VTABLE_PANIC,
};
pub const DUMMY_VTABLE_PANIC = Allocator.VTable{
    .alloc = panic_alloc,
    .resize = panic_resize,
    .remap = panic_remap,
    .free = panic_free,
};

pub fn panic_alloc(_: *anyopaque, _: usize, _: mem.Alignment, _: usize) ?[*]u8 {
    Assert.assert_unreachable(@src(), "dummy allocator `alloc()` was called!", .{});
}
pub fn panic_resize(_: *anyopaque, _: []u8, _: mem.Alignment, _: usize, _: usize) bool {
    Assert.assert_unreachable(@src(), "dummy allocator `resize()` was called!", .{});
}
pub fn panic_remap(_: *anyopaque, _: []u8, _: mem.Alignment, _: usize, _: usize) ?[*]u8 {
    Assert.assert_unreachable(@src(), "dummy allocator `remap()` was called!", .{});
}
pub fn panic_free(_: *anyopaque, _: []u8, _: mem.Alignment, _: usize) void {
    Assert.assert_unreachable(@src(), "dummy allocator `free()` was called!", .{});
}
