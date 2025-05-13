const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const math = std.math;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ArrayList = std.ArrayListUnmanaged;
const Type = std.builtin.Type;

const Root = @import("./_root.zig");
// const List = Root.List;
const Quicksort = Root.Quicksort;
const Pivot = Quicksort.Pivot;
const InsertionSort = Root.InsertionSort;
const AllocErrorBehavior = Root.CommonTypes.AllocErrorBehavior;
const GrowthModel = Root.CommonTypes.GrowthModel;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const Compare = Root.Compare;
const DummyAllocator = Root.DummyAllocator;
const BinarySearch = Root.BinarySearch;
const CompareFn = Compare.CompareFn;
const ComparePackage = Compare.ComparePackage;
const inline_swap = Root.Utils.inline_swap;

pub const RingListOptions = struct {
    element_type: type,
    alloc_error_behavior: AllocErrorBehavior = .ALLOCATION_ERRORS_PANIC,
    growth_model: GrowthModel = .GROW_BY_50_PERCENT_ATOMIC_PADDING,
    index_type: type = usize,
    secure_wipe_bytes: bool = false,
};

pub const Impl = struct {
    pub fn new_empty(comptime List: type) List {
        return List.EMPTY;
    }

    pub fn new_with_capacity(comptime List: type, capacity: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!List else List {
        var self = List.EMPTY;
        if (List.RETURN_ERRORS) {
            try ensure_total_capacity_exact(List, &self, capacity, alloc);
        } else {
            ensure_total_capacity_exact(List, &self, capacity, alloc);
        }
        return self;
    }

    pub fn logical_slices(comptime List: type, self: List) [2][]List.Elem {
        const start_to_cap = self.cap - self.start;
        const len_1 = @min(self.len, start_to_cap);
        const len_2 = self.len - len_1;
        const logical = [2][]List.Elem{ self.ptr[self.start..(self.start + len_1)], self.ptr[0..len_2] };
        return logical;
    }

    pub fn ensure_total_capacity(comptime List: type, self: *List, new_capacity: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        if (self.cap >= new_capacity) return;
        return ensure_total_capacity_exact(List, self, true_capacity_for_grow(List, self.cap, new_capacity), alloc);
    }

    pub fn realign_to_start(comptime List: type, self: *List) void {
        if (self.start == 0) return;
        const slices = logical_slices(List, self);
        if (slices[1].len == 0) {
            if (self.start >= self.len) {
                @memcpy(self.ptr[0..self.len], slices[0]);
                if (List.SECURE_WIPE) {
                    std.crypto.secureZero(List.Elem, slices[0]);
                }
            } else {
                std.mem.copyForwards(List.Elem, self.ptr[0..self.len], slices[0][0..self.len]);
                if (List.SECURE_WIPE) {
                    std.crypto.secureZero(List.Elem, self.ptr[self.len..(self.start + self.len)]);
                }
            }
            self.start = 0;
            return;
        }
        if (self.start >= self.len) {
            @memcpy(self.ptr[slices[0].len..self.cap], slices[1]);
            @memcpy(self.ptr[0..self.cap], slices[0]);
            if (List.SECURE_WIPE) {
                std.crypto.secureZero(List.Elem, slices[0]);
            }
            self.start = 0;
            return;
        }
        var write_idx: usize = 0;
        var read_idx: usize = self.start;
        var temp: List.Elem = undefined;
        while (write_idx < self.start) {
            inline_swap(List.Elem, &self.ptr[read_idx], &self.ptr[write_idx], &temp);
            read_idx += 1;
            write_idx += 1;
            if (read_idx == self.cap) read_idx = self.start;
        }
        if (write_idx < read_idx) {
            if (read_idx == self.len - 1) {
                temp = self.ptr[read_idx];
                std.mem.copyBackwards(List.Elem, self.ptr[write_idx + 1 .. read_idx + 1], self.ptr[write_idx..read_idx]);
                self.ptr[write_idx] = temp;
            } else if (read_idx == write_idx + 1) {
                temp = self.ptr[write_idx];
                std.mem.copyForwards(List.Elem, self.ptr[write_idx .. self.len - 1], self.ptr[read_idx..self.len]);
                self.ptr[self.len - 1] = temp;
            } else {
                while (read_idx < self.cap) {
                    inline_swap(List.Elem, &self.ptr[read_idx], &self.ptr[write_idx], &temp);
                    read_idx += 1;
                    write_idx += 1;
                }
                read_idx = write_idx + 1;
                temp = self.ptr[write_idx];
                std.mem.copyForwards(List.Elem, self.ptr[write_idx .. self.len - 1], self.ptr[read_idx..self.len]);
                self.ptr[self.len - 1] = temp;
            }
        }
        if (List.SECURE_WIPE) {
            std.crypto.secureZero(List.Elem, self.ptr[self.len..self.cap]);
        }
        self.start = 0;
        return;
    }

    pub fn ensure_total_capacity_exact(comptime List: type, self: *List, new_capacity: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        if (@sizeOf(List.Elem) == 0) {
            self.cap = math.maxInt(List.Idx);
            return;
        }

        if (self.cap >= new_capacity) return;

        if (new_capacity < self.len + self.start) {
            realign_to_start(List, self);
        }

        if (new_capacity < self.len) {
            if (List.SECURE_WIPE) crypto.secureZero(List.Elem, self.ptr[new_capacity..self.len]);
            self.len = new_capacity;
        }

        const old_memory = self.ptr[0..self.cap];
        if (alloc.remap(old_memory, new_capacity)) |new_memory| {
            self.ptr = new_memory.ptr;
            self.cap = @intCast(new_memory.len);
        } else {
            const new_memory = alloc.alignedAlloc(List.Elem, List.ALIGN, new_capacity) catch |err| return handle_alloc_error(List, err);
            @memcpy(new_memory[0..self.len], self.ptr[0..self.len]);
            if (List.SECURE_WIPE) crypto.secureZero(List.Elem, self.ptr[0..self.len]);
            alloc.free(old_memory);
            self.ptr = new_memory.ptr;
            self.cap = @as(List.Idx, @intCast(new_memory.len));
        }
    }

    pub fn ensure_unused_capacity(comptime List: type, self: *List, additional_count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const new_total_cap = if (List.RETURN_ERRORS) try add_or_error(List, self.len, additional_count) else add_or_error(List, self.len, additional_count);
        return ensure_total_capacity(List, self, new_total_cap, alloc);
    }

    pub fn add_or_error(comptime List: type, a: List.Idx, b: List.Idx) if (List.RETURN_ERRORS) error{OutOfMemory}!List.Idx else List.Idx {
        if (!List.RETURN_ERRORS) return a + b;
        const result, const overflow = @addWithOverflow(a, b);
        if (overflow != 0) return error.OutOfMemory;
        return result;
    }

    pub fn true_capacity_for_grow(comptime List: type, current: List.Idx, minimum: List.Idx) List.Idx {
        switch (List.GROWTH) {
            GrowthModel.GROW_EXACT_NEEDED => {
                return minimum;
            },
            GrowthModel.GROW_EXACT_NEEDED_ATOMIC_PADDING => {
                return minimum + List.ATOMIC_PADDING;
            },
            else => {
                var new = current;
                while (true) {
                    switch (List.GROWTH) {
                        GrowthModel.GROW_BY_100_PERCENT => {
                            new +|= new;
                            if (new >= minimum) return new;
                        },
                        GrowthModel.GROW_BY_100_PERCENT_ATOMIC_PADDING => {
                            new +|= new;
                            const new_with_padding = new +| List.ATOMIC_PADDING;
                            if (new_with_padding >= minimum) return new_with_padding;
                        },
                        GrowthModel.GROW_BY_50_PERCENT => {
                            new +|= new / 2;
                            if (new >= minimum) return new;
                        },
                        GrowthModel.GROW_BY_50_PERCENT_ATOMIC_PADDING => {
                            new +|= new / 2;
                            const new_with_padding = new +| List.ATOMIC_PADDING;
                            if (new_with_padding >= minimum) return new_with_padding;
                        },
                        GrowthModel.GROW_BY_25_PERCENT => {
                            new +|= new / 4;
                            if (new >= minimum) return new;
                        },
                        GrowthModel.GROW_BY_25_PERCENT_ATOMIC_PADDING => {
                            new +|= new / 4;
                            const new_with_padding = new +| List.ATOMIC_PADDING;
                            if (new_with_padding >= minimum) return new_with_padding;
                        },
                        else => unreachable,
                    }
                }
            },
        }
    }
};

pub fn define_statically_managed_ring_buffer_type(comptime options: RingListOptions, alloc_ptr: *const Allocator) type {
    return struct {
        const List = @This();

        ptr: Ptr,
        len: Idx,
        cap: Idx,
        start: Idx,

        pub const ALLOC = alloc_ptr;
        pub const ALLOC_ERROR_BEHAVIOR = options.alloc_error_behavior;
        pub const GROWTH = options.growth_model;
        pub const RETURN_ERRORS = options.alloc_error_behavior == .ALLOCATION_ERRORS_RETURN_ERROR;
        pub const SECURE_WIPE = options.secure_wipe_bytes;
        pub const UNINIT_PTR: Ptr = mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem));
        pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
        pub const EMPTY = List{
            .ptr = UNINIT_PTR,
            .len = 0,
            .cap = 0,
            .start = 0,
        };

        pub const Error = Allocator.Error;
        pub const Elem = options.element_type;
        pub const Idx = options.index_type;
        pub const Ptr = [*]Elem;

        pub fn new_empty() List {
            return Impl.new_empty(List);
        }

        pub fn new_with_capacity(cap: Idx) List {
            Impl.new_with_capacity(List, cap, ALLOC);
        }
    };
}
