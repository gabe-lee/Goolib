const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

pub const allocator = Allocator{
    .ptr = &DUMMY_VTABLE,
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
pub fn dummy_free(self: *anyopaque, memory: []u8, alignment: mem.Alignment, ret_addr: usize) ?[*]u8 {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = ret_addr;
    return null;
}
