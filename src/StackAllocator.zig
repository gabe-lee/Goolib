//! This is a fixed-size allocator for use allocating objects on the stack
//!
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
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;
const builtin = @import("builtin");
const AllocatorInfal = @This();

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const DummyAlloc = Root.DummyAllocator;

/// An allocator for a single object on the stack
pub fn StackObject(comptime T: type) type {
    return struct {
        const Self = @This();
        val: T = undefined,

        const ALLOC_VTABLE = Allocator.VTable{
            .alloc = impl_alloc,
            .resize = impl_resize,
            .remap = impl_remap,
            .free = impl_free,
        };
        fn impl_alloc(self: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
            _ = ret_addr;
            if (len != @sizeOf(T) or alignment.toByteUnits() != @alignOf(T)) {
                return null;
            }
            return @ptrCast(self);
        }
        fn impl_resize(self: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
            _ = ret_addr;
            if (memory.ptr != @as([*]u8, @ptrCast(self)) or new_len != @sizeOf(T) or alignment.toByteUnits() != @alignOf(T)) {
                return false;
            }
            return true;
        }
        fn impl_remap(self: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
            _ = ret_addr;
            if (memory.ptr != @as([*]u8, @ptrCast(self)) or new_len != @sizeOf(T) or alignment.toByteUnits() != @alignOf(T)) {
                return null;
            }
            return memory.ptr;
        }
        fn impl_free(self: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
            _ = self;
            _ = memory;
            _ = alignment;
            _ = ret_addr;
            return;
        }

        pub fn allocator(self: *Self) Allocator {
            return Allocator{
                .ptr = @ptrCast(self),
                .vtable = &ALLOC_VTABLE,
            };
        }
    };
}
