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

pub const AllocatorC99 = struct {
    self_opaque: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Should return a pointer to the new memory or `null` on error
        malloc: *const fn (self_opaque: *anyopaque, bytes: usize) callconv(.c) ?*anyopaque,

        /// Should return a pointer to the new memory or `null` on error
        calloc: *const fn (self_opaque: *anyopaque, element_count: usize, element_size: usize) callconv(.c) ?*anyopaque,

        /// Should return a pointer to the new memory or `null` on error
        realloc: *const fn (self_opaque: *anyopaque, mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque,

        /// Free the memory unconditionally
        free: *const fn (*anyopaque, mem: ?*anyopaque) callconv(.c) void,
    };

    pub fn define_comptime(comptime allocator: AllocatorC99) type {
        return struct {
            pub const ALLOC = allocator;

            pub fn malloc(bytes: usize) callconv(.c) ?*anyopaque {
                return ALLOC.vtable.malloc(ALLOC.self_opaque, bytes);
            }
            pub fn calloc(element_count: usize, element_size: usize) callconv(.c) ?*anyopaque {
                return ALLOC.vtable.calloc(ALLOC.self_opaque, element_count, element_size);
            }
            pub fn realloc(mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque {
                return ALLOC.vtable.calloc(ALLOC.self_opaque, mem, new_bytes);
            }
            pub fn free(mem: ?*anyopaque) callconv(.c) ?*anyopaque {
                return ALLOC.vtable.free(ALLOC.self_opaque, mem);
            }
        };
    }

    pub fn malloc(self: *AllocatorC99, bytes: usize) callconv(.c) ?*anyopaque {
        return self.vtable.malloc(self, bytes);
    }
    pub fn calloc(self: *AllocatorC99, element_count: usize, element_size: usize) callconv(.c) ?*anyopaque {
        return self.vtable.calloc(self, element_count, element_size);
    }
    pub fn realloc(self: *AllocatorC99, mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque {
        return self.vtable.realloc(self, mem, new_bytes);
    }
    pub fn free(self: *AllocatorC99, mem: ?*anyopaque) callconv(.c) void {
        return self.vtable.free(self, mem);
    }
};

// /// Should return a pointer to the new memory or `null` on error
//     alligned_alloc: *const fn (self_opaque: *anyopaque, alignment: usize, bytes: usize) callconv(.c) ?*anyopaque,
