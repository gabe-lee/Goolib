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
