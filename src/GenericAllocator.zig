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
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const Random = std.Random;

const Root = @import("./_root.zig");
const Types = Root.Types;
const Assert = Root.Assert;
const Fuzz = Root.Fuzz;
const IList = Root.IList;
const IListConcrete = IList.Concrete;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;
const testing = std.testing;
const Test = Root.Testing;
const Range = IListConcrete.Range;
const ListError = IListConcrete.ListError;
const Alignment = Root.CommonTypes.Alignment;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

pub fn GenericAllocator(comptime ADDRESS_TYPE: type, comptime LENGTH_UINT: type) type {
    return struct {
        const Self = @This();

        object: *anyopaque = undefined,
        vtable: *const VTABLE = undefined,

        pub const VTABLE = struct {
            /// Allocate a new memory range of at least `len` bytes.
            ///
            /// Any allocation failures must be handled or otherwise panic within the implementation.
            ///
            /// Allocating 0 bytes may have implementation-specific behavior
            alloc: *const fn (object: *anyopaque, len: LENGTH_UINT, alignment: Alignment) ADDRESS_TYPE,
            /// Resize the memory region without moving its location in memory.
            ///
            /// Returns `true` if successful, meaning the existing address now has at least `new_len` bytes allocated to it
            ///
            /// Returns `false` if impossible to resize without reallocation/remapping
            ///
            /// Resizing to 0 bytes may have implementation-specific behavior
            resize: *const fn (object: *anyopaque, address: ADDRESS_TYPE, old_len: LENGTH_UINT, new_len: LENGTH_UINT, new_alignment: Alignment) bool,
            /// Resize the memory region without performing any data copy, but possibly moving its location in the system's virtual memory.
            ///
            /// Returns the new address if successful (which may or may not be identical to the old one),
            /// meaning the returned address now has at least `new_len` bytes allocated to it
            ///
            /// Returns `null` if impossible to remap without reallocation
            ///
            /// The implementation should always return the same address if a call to `resize()` would have resulted in `true`
            ///
            /// Remapping to 0 bytes may have implementation-specific behavior
            remap: *const fn (object: *anyopaque, old_address: ADDRESS_TYPE, old_len: LENGTH_UINT, new_len: LENGTH_UINT, new_alignment: Alignment) ?ADDRESS_TYPE,
            /// Return the memory back to the allocator. Attempting to use this memory region after freeing it
            /// should be considered unsafe/undefined behavior.
            ///
            /// Freeing 0 bytes may have implementation-specific behavior
            free: *const fn (object: *anyopaque, address: ADDRESS_TYPE, len: LENGTH_UINT) void,
            /// Convert the given address of type `ADDRESS_TYPE` to a `usize` that holds the TRUE
            /// native address of the memory.
            ///
            /// This may be a no-op for an implementation that already
            /// provides native addresses, or it may involve an implementation-specific
            /// layer of indirection to calculate and return the true address.
            ///
            /// In all cases, the user should ALWAYS get a true reference to
            /// the data via `addr_to_usize()`, `addr_to_ptr()` or `addr_to_many_item_ptr()`
            addr_to_usize: *const fn (object: *anyopaque, address: ADDRESS_TYPE) usize,
        };

        /// Convert the given address of type `ADDRESS_TYPE` to a `usize` that holds the TRUE
        /// native address of the memory.
        ///
        /// This may be a no-op for an implementation that already
        /// provides native addresses, or it may involve an implementation-specific
        /// layer of indirection to calculate and return the true address.
        ///
        /// In all cases, the user should ALWAYS get a true reference to
        /// the data via `addr_to_usize()`, `addr_to_ptr()` or `addr_to_many_item_ptr()`
        pub fn addr_to_usize(self: Self, addr: ADDRESS_TYPE) usize {
            return self.vtable.addr_to_usize(self.object, addr);
        }
        /// Convert the given address of type `ADDRESS_TYPE` to a `*T` that holds the TRUE
        /// data.
        ///
        /// This may be a no-op for an implementation that already
        /// provides native addresses, or it may involve an implementation-specific
        /// layer of indirection to calculate and return the true address and cast it to a pointer
        /// of the given type.
        ///
        /// In all cases, the user should ALWAYS get a true reference to
        /// the data via `addr_to_usize()`, `addr_to_ptr()` or `addr_to_many_item_ptr()`
        pub fn addr_to_ptr(self: Self, addr: ADDRESS_TYPE, comptime T: type) *T {
            return @ptrFromInt(self.vtable.addr_to_usize(self.object, addr));
        }
        /// Convert the given address of type `ADDRESS_TYPE` to a `[*]T` that holds the TRUE
        /// data.
        ///
        /// This may be a no-op for an implementation that already
        /// provides native addresses, or it may involve an implementation-specific
        /// layer of indirection to calculate and return the true address and cast it to a pointer
        /// of the given type.
        ///
        /// In all cases, the user should ALWAYS get a true reference to
        /// the data via `addr_to_usize()`, `addr_to_ptr()` or `addr_to_many_item_ptr()`
        pub fn addr_to_many_item_ptr(self: Self, addr: ADDRESS_TYPE, comptime T: type) [*]T {
            return @ptrFromInt(self.vtable.addr_to_usize(self.object, addr));
        }

        /// Allocate a new memory range of at least `len` bytes.
        ///
        /// Any allocation failures must be handled or otherwise panic within the implementation.
        ///
        /// Allocating 0 bytes may have implementation-specific behavior
        pub fn alloc_bytes(self: Self, len: LENGTH_UINT, alignment: Alignment) ADDRESS_TYPE {
            return self.vtable.alloc(self.object, len, alignment);
        }
        /// Resize the memory region without moving its location in memory.
        ///
        /// Returns `true` if successful, meaning the existing address now has at least `new_len` bytes allocated to it
        ///
        /// Returns `false` if impossible to resize without reallocation/remapping
        ///
        /// Resizing to 0 bytes may have implementation-specific behavior
        pub fn resize_bytes(self: Self, old_address: ADDRESS_TYPE, old_len: LENGTH_UINT, new_len: LENGTH_UINT, new_alignment: Alignment) bool {
            return self.vtable.resize(self.object, old_address, old_len, new_len, new_alignment);
        }
        /// Resize the memory region without performing any data copy, but possibly moving its location in the system's virtual memory.
        ///
        /// Returns the new address if successful (which may or may not be identical to the old one),
        /// meaning the returned address now has at least `new_len` bytes allocated to it
        ///
        /// Returns `null` if impossible to remap without reallocation
        ///
        /// The implementation should always return the same address if a call to `resize()` would have resulted in `true`
        ///
        /// Remapping to 0 bytes may have implementation-specific behavior
        pub fn remap_bytes(self: Self, old_address: ADDRESS_TYPE, old_len: LENGTH_UINT, new_len: LENGTH_UINT, new_alignment: Alignment) ?ADDRESS_TYPE {
            return self.vtable.remap(self.object, old_address, old_len, new_len, new_alignment);
        }
        /// Return the memory back to the allocator. Attempting to use this memory region after freeing it
        /// should be considered unsafe/undefined behavior.
        ///
        /// Freeing 0 bytes may have implementation-specific behavior
        pub fn free_bytes(self: Self, address: ADDRESS_TYPE, len: LENGTH_UINT) void {
            return self.vtable.free(self.object, address, len);
        }

        /// Allocate a new memory range of at least `len` elements of type `T`.
        ///
        /// Any allocation failures must be handled or otherwise panic within the implementation.
        ///
        /// Allocating 0 elements may have implementation-specific behavior
        pub fn alloc(self: Self, comptime T: type, len: LENGTH_UINT) ADDRESS_TYPE {
            const real_len = @sizeOf(T) * len;
            const alignment = Alignment.from_type(T);
            return self.vtable.alloc(self.object, real_len, alignment);
        }
        /// Resize the memory region without moving its location in memory.
        ///
        /// Returns `true` if successful, meaning the existing address now has
        /// at least `new_len` elements of type `T` allocated to it
        ///
        /// Returns `false` if impossible to resize without reallocation/remapping
        ///
        /// Resizing to 0 bytes may have implementation-specific behavior
        pub fn resize(self: Self, comptime T: type, old_address: ADDRESS_TYPE, old_len: LENGTH_UINT, new_len: LENGTH_UINT) bool {
            const real_old_len = @sizeOf(T) * old_len;
            const real_new_len = @sizeOf(T) * new_len;
            const new_alignment = Alignment.from_type(T);
            return self.vtable.resize(self.object, old_address, real_old_len, real_new_len, new_alignment);
        }
        /// Resize the memory region without performing any data copy,
        /// but possibly moving its location in the system's virtual memory.
        ///
        /// Returns the new address if successful (which may or may not be identical to the old one),
        /// meaning the returned address now has at least `new_len` elements of type `T` allocated to it
        ///
        /// Returns `null` if impossible to remap without reallocation
        ///
        /// The implementation should always return the same address if a call to `resize()` would have resulted in `true`
        ///
        /// Remapping to 0 bytes may have implementation-specific behavior
        pub fn remap(self: Self, comptime T: type, old_address: ADDRESS_TYPE, old_len: LENGTH_UINT, new_len: LENGTH_UINT) ?ADDRESS_TYPE {
            const real_old_len = @sizeOf(T) * old_len;
            const real_new_len = @sizeOf(T) * new_len;
            const new_alignment = Alignment.from_type(T);
            return self.vtable.remap(self.object, old_address, real_old_len, real_new_len, new_alignment);
        }
        /// Return the memory back to the allocator. Attempting to use this memory region after freeing it
        /// should be considered unsafe/undefined behavior.
        ///
        /// Freeing 0 elements may have implementation-specific behavior
        pub fn free(self: Self, comptime T: type, address: ADDRESS_TYPE, len: LENGTH_UINT) void {
            const real_len = @sizeOf(T) * len;
            return self.vtable.free(self.object, address, real_len);
        }

        /// Allocate a single item of type `T`
        ///
        /// Any allocation failures must be handled or otherwise panic within the implementation.
        pub fn create(self: Self, comptime T: type) ADDRESS_TYPE {
            return self.alloc(T, 1);
        }

        /// Free a single item of type `T`
        ///
        /// Returns the memory back to the allocator. Attempting to use this memory region after freeing it
        /// should be considered unsafe/undefined behavior.
        pub fn destroy(self: Self, comptime T: type, addr: ADDRESS_TYPE) void {
            return self.free(T, addr, 1);
        }

        /// A multipurpose method that handles the following cases:
        ///   - if `old_len == 0` -> calls `alloc_bytes(new_len)`
        ///   - if 'new_len == 0' -> calls `free_bytes(old_address, old_len)` (returns old address)
        ///   - else attempts to `remap_bytes(old_address, old_len, new_len)` memory
        ///   - else calls `alloc_bytes(new_len)`, copies over data, calls `free_bytes(old_address, old_len)` on old memory, and returns new address
        ///
        /// Allocating/Resizing/Remapping/Freeing 0 bytes may have implementation-specific behavior
        pub fn realloc_bytes(self: Self, old_address: ADDRESS_TYPE, old_len: LENGTH_UINT, new_len: LENGTH_UINT, alignment: Alignment) ADDRESS_TYPE {
            if (old_len == 0) return self.alloc_bytes(new_len, alignment);
            if (new_len == 0) {
                self.free_bytes(old_address, old_len);
                return old_address;
            }
            if (self.remap_bytes(old_address, old_len, new_len, alignment)) |new_addr| {
                return new_addr;
            } else {
                const new_addr = self.alloc_bytes(new_len, alignment);
                const new_ptr = self.addr_to_many_item_ptr(new_addr, u8);
                const old_ptr = self.addr_to_many_item_ptr(old_address, u8);
                const min_len = @min(old_len, new_len);
                @memcpy(new_ptr[0..min_len], old_ptr[0..min_len]);
                self.free_bytes(old_address, old_len);
                return new_addr;
            }
        }

        /// A multipurpose method that handles the following cases:
        ///   - if `old_len == 0` -> calls `alloc(T, new_len)`
        ///   - if 'new_len == 0' -> calls `free(T, old_address, old_len)` (returns old address)
        ///   - else attempts to `remap(T, old_address, old_len, new_len)` memory
        ///   - else calls `alloc(T, new_len)`, copies over data, calls `free(T, old_address, old_len)` on old memory, and returns new address
        ///
        /// Allocating/Resizing/Remapping/Freeing 0 bytes may have implementation-specific behavior
        pub fn realloc(self: Self, comptime T: type, old_address: ADDRESS_TYPE, old_len: LENGTH_UINT, new_len: LENGTH_UINT) ADDRESS_TYPE {
            const alignment = Alignment.from_type(T);
            const real_old_len = @sizeOf(T) * old_len;
            const real_new_len = @sizeOf(T) * new_len;
            return self.realloc_bytes(old_address, real_old_len, real_new_len, alignment);
        }
    };
}
