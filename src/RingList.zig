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
const SoftSlice = Root.SoftSlice.SoftSlice;
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

    pub fn cap_slices_in_order(comptime List: type, self: List) SliceSegments(List.Idx, List.Elem) {
        return SliceSegments(List.Idx, List.Elem){
            .first = self.ptr[self.start..self.cap],
            .first_extra_cap = 0,
            .second = self.ptr[0..self.start],
            .second_extra_cap = 0,
        };
    }

    pub fn slices_in_order(comptime List: type, self: List) SliceSegments(List.Idx, List.Elem) {
        const start_to_cap = self.cap - self.start;
        const len_1 = @min(self.len, start_to_cap);
        const len_1_room_before_end = start_to_cap - len_1;
        const len_2 = self.len - len_1;
        const len_2_room_before_end = self.start - len_2;
        return SliceSegments(List.Idx, List.Elem){
            .first = self.ptr[self.start..(self.start + len_1)],
            .first_extra_cap = len_1_room_before_end,
            .second = self.ptr[0..len_2],
            .second_extra_cap = len_2_room_before_end,
        };
    }

    pub fn slices_in_order_from_range(comptime List: type, self: List, start: List.IDX, count: List.Idx) SliceSegments(List.Idx, List.Elem) {
        assert(start + count <= self.len);
        const start_1 = @min(self.start + start, self.cap);
        const len_1 = @min(count, self.cap - start_1);
        const extra_room_1 = self.cap - (start_1 + len_1);
        const len_2 = count - len_1;
        const extra_room_2 = self.start - len_2;
        return SliceSegments{
            .first = self.ptr[start_1..(start_1 + len_1)],
            .first_extra_cap = extra_room_1,
            .second = self.ptr[0..len_2],
            .second_extra_cap = extra_room_2,
        };
    }

    pub fn realign_to_start(comptime List: type, self: *List) void {
        if (self.start == 0) return;
        const slices: SliceSegments(List.Idx, List.Elem) = slices_in_order(List, self);
        if (slices.second.len == 0) {
            if (self.start >= self.len) {
                @memcpy(self.ptr[0..self.len], slices.first);
                if (List.SECURE_WIPE) {
                    std.crypto.secureZero(List.Elem, slices.first);
                }
            } else {
                std.mem.copyForwards(List.Elem, self.ptr[0..self.len], slices.first[0..self.len]);
                if (List.SECURE_WIPE) {
                    std.crypto.secureZero(List.Elem, self.ptr[self.len..(self.start + self.len)]);
                }
            }
            self.start = 0;
            return;
        }
        if (self.start >= self.len) {
            if (slices.first.len >= slices.second.len) {
                @memcpy(self.ptr[slices.first.len..self.cap], slices.second);
            } else {
                std.mem.copyBackwards(List.Elem, self.ptr[slices.first.len..self.cap], slices.second);
            }
            @memcpy(self.ptr[0..self.cap], slices.first);
            if (List.SECURE_WIPE) {
                std.crypto.secureZero(List.Elem, slices.first);
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

    pub fn ensure_total_capacity(comptime List: type, self: *List, new_capacity: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        if (self.cap >= new_capacity) return;
        return ensure_total_capacity_exact(List, self, true_capacity_for_grow(List, self.cap, new_capacity), alloc);
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
            var slices = slices_in_order(List, self);
            if (slices.second.len > 0 and new_capacity > self.cap) {
                const extra = new_capacity - self.cap;
                const s1_copy_count = @min(extra, slices.second.len);
                slices.first.len += extra;
                @memcpy(slices.first[slices.first.len .. slices.first.len + extra], slices.second[0..s1_copy_count]);
                std.mem.copyForwards(List.Elem, slices.second[0..], slices.second[s1_copy_count..]);
                if (List.SECURE_WIPE) {
                    const s1_leftover = extra - s1_copy_count;
                    std.crypto.secureZero(List.Elem, slices.second[s1_leftover..]);
                }
            }
            self.cap = @intCast(new_memory.len);
        } else {
            const new_memory = alloc.alignedAlloc(List.Elem, List.ALIGN, new_capacity) catch |err| return handle_alloc_error(List, err);
            const slices = slices_in_order(List, self);
            @memcpy(new_memory[0..slices.first.len], slices.first);
            @memcpy(new_memory[slices.first.len..], slices.second);
            if (List.SECURE_WIPE) {
                crypto.secureZero(List.Elem, slices.first);
                crypto.secureZero(List.Elem, slices.second);
            }
            alloc.free(old_memory);
            self.ptr = new_memory.ptr;
            self.cap = @as(List.Idx, @intCast(new_memory.len));
        }
    }

    pub fn ensure_unused_capacity(comptime List: type, self: *List, additional_count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const new_total_cap = if (List.RETURN_ERRORS) try add_or_error(List, self.len, additional_count) else add_or_error(List, self.len, additional_count);
        return ensure_total_capacity(List, self, new_total_cap, alloc);
    }

    pub fn append_slot(comptime List: type, self: *List, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!*List.Elem else *List.Elem {
        const new_len = self.len + 1;
        if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
        return append_slot_assume_capacity(List, self);
    }

    pub fn insert_slot(comptime List: type, self: *List, idx: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!*List.Elem else *List.Elem {
        if (List.RETURN_ERRORS) {
            try ensure_unused_capacity(List, self, 1, alloc);
        } else {
            ensure_unused_capacity(List, self, 1, alloc);
        }
        return insert_slot_assume_capacity(List, self, idx);
    }

    pub fn insert_slot_assume_capacity(comptime List: type, self: *List, idx: List.Idx) *List.Elem {
        assert(idx < self.len);
        const slices = slices_in_order_from_range(List, self, idx, self.len - idx);
        if (slices.first_extra_cap >= 1) {
            _ = slices.first.copy_rightward(1, false);
            self.len += 1;
            return slices.first.get_item_ptr(0);
        }
        if (slices.second.len > 0) {
            _ = slices.second.copy_rightward(1, false);
        }
        slices.second.set_item(0, slices.first.get_item_from_end(0));
        const slice_1_shrunk = slices.first.shrink_right(1);
        slice_1_shrunk.copy_rightward(1, false);
        return slices.first.get_item_ptr(0);
    }

    pub fn insert(comptime List: type, self: *List, idx: List.Idx, item: List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const ptr = if (List.RETURN_ERRORS) try insert_slot(List, self, idx, alloc) else insert_slot(List, self, idx, alloc);
        ptr.* = item;
    }

    pub fn insert_assume_capacity(comptime List: type, self: *List, idx: List.Idx, item: List.Elem) void {
        const ptr = insert_slot_assume_capacity(List, self, idx);
        ptr.* = item;
    }

    // pub fn insert_many_slots(comptime List: type, self: *List, idx: List.Idx, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error![]List.Elem else []List.Elem {
    //     if (List.RETURN_ERRORS) {
    //         try ensure_unused_capacity(List, self, count, alloc);
    //     } else {
    //         ensure_unused_capacity(List, self, count, alloc);
    //     }
    //     return insert_many_slots_assume_capacity(List, self, idx, count);
    // }

    pub fn insert_many_slots_assume_capacity(comptime List: type, self: *List, idx: List.Idx, count: List.Idx) SliceSegments(List.Idx, List.Elem) {
        assert(idx + count <= self.len);
        const slices = slices_in_order_from_range(List, self, idx, self.len - idx);
        if (slices.first_extra_cap >= count) {
            _ = slices.first.copy_rightward(count, false);
            self.len += count;
            return SliceSegments(List.Idx, List.Elem){
                .first = slices.first.sub_slice_from_start(count),
                .first_extra_cap = slices.first_extra_cap - 1,
                .second = SoftSlice(List.Elem, List.Idx).EMPTY,
                .second_extra_cap = 0,
            };
        }
        if (slices.second.len > 0) {
            _ = slices.second.copy_rightward(count, false);
        }
        //FIXME count might be larger than slice_1 size
        const end_of_1 = slices.first.sub_slice_from_end(count);
        const begin_of_2 = slices.second.sub_slice_from_start(count);
        end_of_1.memcopy_to(begin_of_2);
        const slice_1_shrunk = slices.first.shrink_right(count);
        slice_1_shrunk.copy_rightward(count, false);
        return slices.first.sub_slice_from_start(count);
    }

    // pub fn insert_slice(comptime List: type, self: *List, idx: List.Idx, items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
    //     const slots = if (List.RETURN_ERRORS) try insert_many_slots(List, self, idx, @intCast(items.len), alloc) else insert_slot(List, self, idx, @intCast(items.len), alloc);
    //     @memcpy(slots, items);
    // }

    // pub fn insert_slice_assume_capacity(comptime List: type, self: *List, idx: List.Idx, items: []const List.Elem) void {
    //     const slots = insert_many_slots_assume_capacity(List, self, idx, @intCast(items.len));
    //     @memcpy(slots, items);
    // }

    pub fn append_slot_assume_capacity(comptime List: type, self: *List) *List.Elem {
        assert(self.len < self.cap);
        const idx = (self.start + self.len) % self.cap;
        self.len += 1;
        return &self.ptr[idx];
    }

    pub fn append(comptime List: type, self: *List, item: List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slot = if (List.RETURN_ERRORS) try append_slot(List, self, alloc) else append_slot(List, self, alloc);
        slot.* = item;
    }

    pub fn append_assume_capacity(comptime List: type, self: *List, item: List.Elem) void {
        const slot = append_slot_assume_capacity(List, self);
        slot.* = item;
    }

    pub fn append_many_slots(comptime List: type, self: *List, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error![2][]List.Elem else [2][]List.Elem {
        const new_len = self.len + count;
        if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
        return append_many_slots_assume_capacity(List, self, count);
    }

    pub fn append_many_slots_assume_capacity(comptime List: type, self: *List, count: List.Idx) [2][]List.Elem {
        const new_len = self.len + count;
        assert(new_len <= self.cap);
        const appended_start = self.len;
        self.len = new_len;
        return slices_in_order_from_range(List, self, appended_start, count);
    }

    pub fn append_slice(comptime List: type, self: *List, items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, @intCast(items.len), alloc) else append_many_slots(List, self, @intCast(items.len), alloc);
        @memcpy(slots[0], items[0..slots[0..slots[0].len]]);
        @memcpy(slots[1], items[slots[slots[0].len..]]);
    }

    pub fn append_slice_assume_capacity(comptime List: type, self: *List, items: []const List.Elem) void {
        const slots = append_many_slots_assume_capacity(List, self, @intCast(items.len));
        @memcpy(slots[0], items[0..slots[0..slots[0].len]]);
        @memcpy(slots[1], items[slots[slots[0].len..]]);
    }

    pub fn append_n_times(comptime List: type, self: *List, value: List.Elem, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, count, alloc) else append_many_slots(List, self, count, alloc);
        @memset(slots[0], value);
        @memset(slots[1], value);
    }

    pub fn append_n_times_assume_capacity(comptime List: type, self: *List, value: List.Elem, count: List.Idx) void {
        const slots = append_many_slots_assume_capacity(List, self, count);
        @memset(slots[0], value);
        @memset(slots[1], value);
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

    pub fn handle_alloc_error(comptime List: type, err: Allocator.Error) if (List.RETURN_ERRORS) List.Error else noreturn {
        switch (List.ALLOC_ERROR_BEHAVIOR) {
            AllocErrorBehavior.ALLOCATION_ERRORS_RETURN_ERROR => return err,
            AllocErrorBehavior.ALLOCATION_ERRORS_PANIC => std.debug.panic("List's backing allocator failed to allocate memory: Allocator.Error.{s}", .{@errorName(err)}),
            AllocErrorBehavior.ALLOCATION_ERRORS_ARE_UNREACHABLE => unreachable,
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

pub fn SliceSegments(comptime Idx: type, comptime Elem: type) type {
    return struct {
        first: SoftSlice(Elem, Idx),
        first_extra_cap: Idx,
        second: SoftSlice(Elem, Idx),
        second_extra_cap: Idx,
    };
}
