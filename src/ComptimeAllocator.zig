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
const meta = std.meta;
const math = std.math;

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const Alloc = Utils.Alloc;
const Allocator = std.mem.Allocator;

pub fn SingleTypeAllocator(comptime T: type) type {
    return extern struct {
        const Self = @This();

        ptr: [*]T = Utils.invalid_ptr_many(T),
        len: u32 = 0,
        cap: u32 = 0,
        alloc: ?Allocator = null,

        pub fn init_with_alloc(cap: u32, alloc: Allocator) Self {
            var self = Self{
                .alloc = alloc,
            };
            Alloc.smart_alloc_ptr_ptrs(alloc, &self.ptr, &self.cap, @intCast(cap), .{}, .{});
            return self;
        }
        pub fn init_static(cap: u32, alloc: Allocator) Self {
            var self = Self{
                .alloc = alloc,
            };
            Alloc.smart_alloc_ptr_ptrs(alloc, &self.ptr, &self.cap, @intCast(cap), .{}, .{});
            return self;
        }

        const ObjectOrFree = extern union {
            free: u32,
            object: T,
        };
    };
}
