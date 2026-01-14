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
const Allocator = std.mem.Allocator;
const Root = @import("./_root.zig");
const List = Root.IList.List;
const Utils = Root.Utils;

pub const MAX_ALIGN_C = @alignOf(std.c.max_align_t);
pub const ENOMEM = 12;

pub const AllocatorC99 = struct {
    self_opaque: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Should return a pointer to the new memory or `null` on error
        ///
        /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
        malloc: *const fn (self_opaque: *anyopaque, bytes: usize) callconv(.c) ?*anyopaque,

        /// Should return a pointer to the new memory or `null` on error
        ///
        /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
        calloc: *const fn (self_opaque: *anyopaque, element_count: usize, element_size: usize) callconv(.c) ?*anyopaque,

        /// Should return a pointer to the new memory or `null` on error
        ///
        /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
        realloc: *const fn (self_opaque: *anyopaque, mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque,

        /// Free the memory unconditionally
        free: *const fn (*anyopaque, mem: ?*anyopaque) callconv(.c) void,
    };

    /// This is one option for providing an allocator to a C library
    ///
    /// Requires comptime-known AllocatorC99, which cannot be changed at runtime
    ///
    /// (The concrete implementation can still be initialized or have its settings changed at runtime)
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
            /// Free the memory unconditionally
            pub fn free(mem: ?*anyopaque) callconv(.c) ?*anyopaque {
                return ALLOC.vtable.free(ALLOC.self_opaque, mem);
            }
        };
    }

    /// This is one option for providing an allocator to a C library
    ///
    /// Requires comptime-known pointer to where a AllocatorC99 will be, but it may be provided at runtime
    ///
    /// (The concrete implementation can also be initialized or have its settings changed at runtime)
    pub fn define_comptime_ptr(comptime allocator: *const AllocatorC99) type {
        return struct {
            pub const ALLOC = allocator;

            pub export fn malloc(bytes: usize) callconv(.c) ?*anyopaque {
                return ALLOC.vtable.malloc(ALLOC.self_opaque, bytes);
            }
            pub export fn calloc(element_count: usize, element_size: usize) callconv(.c) ?*anyopaque {
                return ALLOC.vtable.calloc(ALLOC.self_opaque, element_count, element_size);
            }
            pub export fn realloc(mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque {
                return ALLOC.vtable.calloc(ALLOC.self_opaque, mem, new_bytes);
            }
            pub export fn free(mem: ?*anyopaque) callconv(.c) ?*anyopaque {
                return ALLOC.vtable.free(ALLOC.self_opaque, mem);
            }
        };
    }

    /// Should return a pointer to the new memory or `null` on error
    ///
    /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
    pub fn malloc(self: *AllocatorC99, bytes: usize) callconv(.c) ?*anyopaque {
        return self.vtable.malloc(self, bytes);
    }
    /// Should return a pointer to the new memory or `null` on error
    ///
    /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
    pub fn calloc(self: *AllocatorC99, element_count: usize, element_size: usize) callconv(.c) ?*anyopaque {
        return self.vtable.calloc(self, element_count, element_size);
    }
    /// Should return a pointer to the new memory or `null` on error
    ///
    /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
    pub fn realloc(self: *AllocatorC99, mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque {
        return self.vtable.realloc(self, mem, new_bytes);
    }
    /// Free the memory unconditionally
    pub fn free(self: *AllocatorC99, mem: ?*anyopaque) callconv(.c) void {
        return self.vtable.free(self, mem);
    }
};

pub const ZigToC99AllocatorWrapper = struct {
    alloc: Allocator,
    allocations_list: List(Allocation) = .{},
    allocations_list_alloc: Allocator,

    pub fn new(allocator: Allocator, allocations_list_alloc: Allocator) ZigToC99AllocatorWrapper {
        return ZigToC99AllocatorWrapper{
            .alloc = allocator,
            .allocations_list_alloc = allocations_list_alloc,
        };
    }

    /// Should return a pointer to the new memory or `null` on error
    ///
    /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
    pub fn malloc(self: *ZigToC99AllocatorWrapper, bytes: usize) callconv(.c) ?*anyopaque {
        const ptr = self.alloc.rawAlloc(bytes, .fromByteUnits(MAX_ALIGN_C), @returnAddress());
        if (ptr == null) {
            // std.c._errno().* = ENOMEM;
            return null;
        }
        const new_allocation: Allocation = .new_addr(@intFromPtr(ptr), bytes);
        _ = self.allocations_list.sorted_insert(new_allocation, self.allocations_list_alloc, Allocation.addr_equal, Allocation.addr_greater);
        return @ptrCast(ptr);
    }

    /// Should return a pointer to the new memory or `null` on error
    ///
    /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
    pub fn calloc(self: *ZigToC99AllocatorWrapper, element_count: usize, element_size: usize) callconv(.c) ?*anyopaque {
        const bytes = element_count * element_size;
        return malloc(self, bytes);
    }

    /// Should return a pointer to the new memory or `null` on error
    ///
    /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
    pub fn realloc(self: *ZigToC99AllocatorWrapper, mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque {
        const old_alloc_or_null = self.find_allocation(mem);
        if (old_alloc_or_null == null) {
            // std.c._errno().* = ENOMEM;
            return null;
        }
        const old_alloc = old_alloc_or_null.?;
        const old_mem = old_alloc.allocation.to_slice();
        const new_mem: []u8 = Utils.Alloc.realloc_custom(self.alloc, old_mem, new_bytes, .custom_align(MAX_ALIGN_C), .copy_data, .dont_memset_new, .dont_memset_old) catch return null;
        const new_alloc = Allocation.from_slice(new_mem);
        _ = self.allocations_list.sorted_set_and_resort(old_alloc.idx, new_alloc, Allocation.addr_greater);
        return @ptrCast(new_mem.ptr);
    }

    /// Free the memory unconditionally
    pub fn free(self: *ZigToC99AllocatorWrapper, mem: ?*anyopaque) callconv(.c) void {
        const old_alloc_or_null = self.find_allocation(mem);
        if (old_alloc_or_null == null) return;
        const old_alloc = old_alloc_or_null.?;
        const old_mem = old_alloc.allocation.to_slice();
        self.alloc.rawFree(old_mem, .fromByteUnits(MAX_ALIGN_C), @returnAddress());
        self.allocations_list.delete(old_alloc.idx);
    }

    /// Returns a `AllocationFuncs` struct from a comptime pointer to a `ZigToC99AllocatorWrapper`
    pub fn function_pointers_from_wrapper_pointer(comptime self: *ZigToC99AllocatorWrapper) AllocationFuncs {
        const PROTO = self.define_comptime_ptr();
        return AllocationFuncs{
            .malloc = PROTO.malloc,
            .calloc = PROTO.calloc,
            .realloc = PROTO.realloc,
            .free = PROTO.free,
        };
    }
    /// Returns a `AllocationFuncs` struct from a comptime `ZigToC99AllocatorWrapper`
    pub fn function_pointers_from_wrapper(comptime self: ZigToC99AllocatorWrapper) AllocationFuncs {
        const PROTO = self.define_comptime();
        return AllocationFuncs{
            .malloc = PROTO.malloc,
            .calloc = PROTO.calloc,
            .realloc = PROTO.realloc,
            .free = PROTO.free,
        };
    }

    /// Returns a `AllocationFuncsUserdata` struct from a comptime pointer to a `ZigToC99AllocatorWrapper`
    ///
    /// Userdata is ignored
    pub fn function_pointers_from_wrapper_pointer_userdata_noop(comptime self: *ZigToC99AllocatorWrapper) AllocationFuncsUserdata {
        const PROTO = self.define_comptime_ptr_discard_userdata();
        return AllocationFuncsUserdata{
            .malloc = PROTO.malloc,
            .calloc = PROTO.calloc,
            .realloc = PROTO.realloc,
            .free = PROTO.free,
        };
    }
    /// Returns a `AllocationFuncs` struct from a comptime `ZigToC99AllocatorWrapper`
    ///
    /// Userdata is ignored
    pub fn function_pointers_from_wrapper_userdata_noop(comptime self: ZigToC99AllocatorWrapper) AllocationFuncsUserdata {
        const PROTO = self.define_comptime_discard_userdata();
        return AllocationFuncsUserdata{
            .malloc = PROTO.malloc,
            .calloc = PROTO.calloc,
            .realloc = PROTO.realloc,
            .free = PROTO.free,
        };
    }

    /// This is one option for providing an allocator to a C library
    ///
    /// Requires comptime-known ZigToC99AllocatorWrapper, which cannot be changed at runtime
    ///
    /// (The concrete implementation can still be initialized or have its settings changed at runtime)
    pub fn define_comptime(comptime wrapper: ZigToC99AllocatorWrapper) type {
        return struct {
            pub const WRAPPER = wrapper;

            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn malloc(bytes: usize) callconv(.c) ?*anyopaque {
                return wrapper.malloc(bytes);
            }
            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn calloc(element_count: usize, element_size: usize) callconv(.c) ?*anyopaque {
                return wrapper.calloc(element_count, element_size);
            }
            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn realloc(mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque {
                return wrapper.realloc(mem, new_bytes);
            }
            /// Free the memory unconditionally
            pub fn free(mem: ?*anyopaque) callconv(.c) void {
                wrapper.free(mem);
            }
        };
    }

    /// This is one option for providing an allocator to a C library
    ///
    /// Requires comptime-known pointer to where a ZigToC99AllocatorWrapper will be, but it may be provided at runtime
    ///
    /// (The concrete implementation can also be initialized or have its settings changed at runtime)
    pub fn define_comptime_ptr(comptime wrapper: *ZigToC99AllocatorWrapper) type {
        return struct {
            pub const WRAPPER = wrapper;

            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn malloc(bytes: usize) callconv(.c) ?*anyopaque {
                return wrapper.malloc(bytes);
            }
            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn calloc(element_count: usize, element_size: usize) callconv(.c) ?*anyopaque {
                return wrapper.calloc(element_count, element_size);
            }
            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn realloc(mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque {
                return wrapper.realloc(mem, new_bytes);
            }
            /// Free the memory unconditionally
            pub fn free(mem: ?*anyopaque) callconv(.c) void {
                wrapper.free(mem);
            }
        };
    }

    /// This is one option for providing an allocator to a C library
    ///
    /// Requires comptime-known ZigToC99AllocatorWrapper, which cannot be changed at runtime
    ///
    /// (The concrete implementation can still be initialized or have its settings changed at runtime)
    pub fn define_comptime_discard_userdata(comptime wrapper: ZigToC99AllocatorWrapper) type {
        return struct {
            pub const WRAPPER = wrapper;

            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn malloc(bytes: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
                return wrapper.malloc(bytes);
            }
            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn calloc(element_count: usize, element_size: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
                return wrapper.calloc(element_count, element_size);
            }
            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn realloc(mem: ?*anyopaque, new_bytes: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
                return wrapper.realloc(mem, new_bytes);
            }
            /// Free the memory unconditionally
            pub fn free(mem: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
                wrapper.free(mem);
            }
        };
    }

    /// This is one option for providing an allocator to a C library
    ///
    /// Requires comptime-known pointer to where a ZigToC99AllocatorWrapper will be, but it may be provided at runtime
    ///
    /// (The concrete implementation can also be initialized or have its settings changed at runtime)
    pub fn define_comptime_ptr_discard_userdata(comptime wrapper: *ZigToC99AllocatorWrapper) type {
        return struct {
            pub const WRAPPER = wrapper;

            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn malloc(bytes: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
                return wrapper.malloc(bytes);
            }
            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn calloc(element_count: usize, element_size: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
                return wrapper.calloc(element_count, element_size);
            }
            /// Should return a pointer to the new memory or `null` on error
            ///
            /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
            pub fn realloc(mem: ?*anyopaque, new_bytes: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
                return wrapper.realloc(mem, new_bytes);
            }
            /// Free the memory unconditionally
            pub fn free(mem: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
                wrapper.free(mem);
            }
        };
    }

    fn iface_malloc(self_opaque: *anyopaque, bytes: usize) callconv(.c) ?*anyopaque {
        var self: *ZigToC99AllocatorWrapper = @ptrCast(@alignCast(self_opaque));
        return self.malloc(bytes);
    }

    fn iface_calloc(self_opaque: *anyopaque, element_count: usize, element_size: usize) callconv(.c) ?*anyopaque {
        const bytes = element_count * element_size;
        return iface_malloc(self_opaque, bytes);
    }

    fn iface_realloc(self_opaque: *anyopaque, mem: ?*anyopaque, new_bytes: usize) callconv(.c) ?*anyopaque {
        var self: *ZigToC99AllocatorWrapper = @ptrCast(@alignCast(self_opaque));
        return self.realloc(mem, new_bytes);
    }

    fn iface_free(self_opaque: *anyopaque, mem: ?*anyopaque) callconv(.c) void {
        var self: *ZigToC99AllocatorWrapper = @ptrCast(@alignCast(self_opaque));
        self.free(mem);
    }

    pub fn find_allocation(self: *ZigToC99AllocatorWrapper, ptr: ?*anyopaque) ?AllocationWithIdx {
        const prototype_allocation = Allocation.new(ptr, 0);
        const result = self.allocations_list.sorted_search(prototype_allocation, Allocation.addr_equal, Allocation.addr_greater);
        if (!result.found) return null;
        const found_alloc = self.allocations_list.ptr[result.idx];
        return AllocationWithIdx{
            .allocation = found_alloc,
            .idx = result.idx,
        };
    }

    pub const VTABLE = AllocatorC99.VTable{
        .malloc = iface_malloc,
        .calloc = iface_calloc,
        .realloc = iface_realloc,
        .free = iface_free,
    };

    pub fn interface(self: *ZigToC99AllocatorWrapper) AllocatorC99 {
        return AllocatorC99{
            .self_opaque = @ptrCast(self),
            .vtable = &VTABLE,
        };
    }
};

pub const Allocation = struct {
    addr: usize,
    size: usize,

    fn addr_greater(a: Allocation, b: Allocation) bool {
        return a.addr > b.addr;
    }
    fn addr_equal(a: Allocation, b: Allocation) bool {
        return a.addr == b.addr;
    }

    pub fn to_slice(self: Allocation) []u8 {
        const ptr: [*]u8 = @ptrFromInt(self.addr);
        return ptr[0..self.size];
    }

    pub fn from_slice(mem: []u8) Allocation {
        return Allocation{
            .addr = @intFromPtr(mem.ptr),
            .size = mem.len,
        };
    }

    pub fn from_mem_ptr_and_size(mem: [*]u8, size: usize) Allocation {
        return Allocation{
            .addr = @intFromPtr(mem),
            .size = size,
        };
    }

    pub fn new(ptr: ?*anyopaque, size: usize) Allocation {
        return Allocation{
            .addr = @intFromPtr(ptr),
            .size = size,
        };
    }
    pub fn new_addr(addr: usize, size: usize) Allocation {
        return Allocation{
            .addr = addr,
            .size = size,
        };
    }
};

pub const AllocationWithIdx = struct {
    allocation: Allocation,
    idx: usize,
};

pub const libc = struct {
    /// Should return a pointer to the new memory or `null` on error
    ///
    /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
    pub const malloc = std.c.malloc;
    /// Should return a pointer to the new memory or `null` on error
    ///
    /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
    pub const calloc = std.c.calloc;
    /// Should return a pointer to the new memory or `null` on error
    ///
    /// Must be aligned to `MAX_ALIGN_C`, which is the align of the largest aligned type for the build target
    pub const realloc = std.c.realloc;
    /// Free the memory unconditionally
    pub const free = std.c.free;
};

/// A struct holding pointers to the 4 C99 allocation functions
///
/// Defaults to the `std.c.____` implementation
///
/// If you change one, you must change all of them to match
pub const AllocationFuncs = struct {
    malloc: *const fn (usize) callconv(.c) ?*anyopaque,
    calloc: *const fn (usize, usize) callconv(.c) ?*anyopaque,
    realloc: *const fn (?*anyopaque, usize) callconv(.c) ?*anyopaque,
    free: *const fn (?*anyopaque) callconv(.c) void,
};

/// A struct holding pointers to the 4 C99 allocation functions that also take a `?*anyopaque` userdata pointer
/// (some libraries use this function signature for their allocations)
///
/// Defaults to the `std.c.____` implementations while doing nothing with the userdata
///
/// If you change one, you must change all of them to match
pub const AllocationFuncsUserdata = struct {
    malloc: *const fn (usize, ?*anyopaque) callconv(.c) ?*anyopaque,
    calloc: *const fn (usize, usize, ?*anyopaque) callconv(.c) ?*anyopaque,
    realloc: *const fn (?*anyopaque, usize, ?*anyopaque) callconv(.c) ?*anyopaque,
    free: *const fn (?*anyopaque, ?*anyopaque) callconv(.c) void,
};

pub var PageAllocatorWrapper = ZigToC99AllocatorWrapper{
    .alloc = std.heap.page_allocator,
    .allocations_list = .{},
    .allocations_list_alloc = std.heap.page_allocator,
};

pub const PageAllocatorWrapperFuncs = PageAllocatorWrapper.function_pointers_from_wrapper_pointer();
pub const PageAllocatorWrapperFuncsUserdataNoop = PageAllocatorWrapper.function_pointers_from_wrapper_pointer_userdata_noop();

// pub fn std_c_malloc_userdata_noop(size: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
//     return std.c.malloc(size);
// }
// pub fn std_c_calloc_userdata_noop(count: usize, size: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
//     return std.c.calloc(count, size);
// }
// pub fn std_c_realloc_userdata_noop(old_ptr: ?*anyopaque, new_size: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
//     return std.c.realloc(old_ptr, new_size);
// }
// pub fn std_c_free_userdata_noop(ptr: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
//     return std.c.free(ptr);
// }
