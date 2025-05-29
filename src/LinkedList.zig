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
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const FlexSlice = Root.FlexSlice.FlexSlice;
const Mutability = Root.CommonTypes.Mutability;
const Quicksort = Root.Quicksort;
const Pivot = Quicksort.Pivot;
const InsertionSort = Root.InsertionSort;
const insertion_sort = InsertionSort.insertion_sort;
const AllocErrorBehavior = Root.CommonTypes.AllocErrorBehavior;
const GrowthModel = Root.CommonTypes.GrowthModel;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const DummyAllocator = Root.DummyAllocator;
const BinarySearch = Root.BinarySearch;

pub const ListOptions = struct {
    element_type: type,
    alignment: ?u29 = null,
    alloc_error_behavior: AllocErrorBehavior = .ALLOCATION_ERRORS_PANIC,
    growth_model: GrowthModel = .GROW_BY_50_PERCENT_ATOMIC_PADDING,
    index_type: type = usize,
    secure_wipe_bytes: bool = false,
};

/// A struct containing all common operations used internally for the various LinkedList
/// paradigms
///
/// These are not intended for normal use, but are provided here for ease of use
/// when implementing a custom list/collection type
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

    pub fn clone(comptime List: type, self: List, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!List else List {
        var new_list = if (List.RETURN_ERRORS) try new_with_capacity(List, self.cap, alloc) else new_with_capacity(List, self.cap, alloc);
        append_slice_assume_capacity(List, &new_list, self.ptr[0..self.len]);
        return new_list;
    }
    //CHECKPOINT rework/prune normal list funcs
    pub fn insert_slot(comptime List: type, self: *List, idx: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!*List.Elem else *List.Elem {
        if (List.RETURN_ERRORS) {
            try ensure_unused_capacity(List, self, 1, alloc);
        } else {
            ensure_unused_capacity(List, self, 1, alloc);
        }
        return insert_slot_assume_capacity(List, self, idx);
    }

    pub fn insert_slot_assume_capacity(comptime List: type, self: *List, idx: List.Idx) *List.Elem {
        assert(idx <= self.len);
        mem.copyBackwards(List.Elem, self.ptr[idx + 1 .. self.len + 1], self.ptr[idx..self.len]);
        self.len += 1;
        return &self.ptr[idx];
    }

    pub fn insert(comptime List: type, self: *List, idx: List.Idx, item: List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const ptr = if (List.RETURN_ERRORS) try insert_slot(List, self, idx, alloc) else insert_slot(List, self, idx, alloc);
        ptr.* = item;
    }

    pub fn insert_assume_capacity(comptime List: type, self: *List, idx: List.Idx, item: List.Elem) void {
        const ptr = insert_slot_assume_capacity(List, self, idx);
        ptr.* = item;
    }

    pub fn insert_many_slots(comptime List: type, self: *List, idx: List.Idx, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error![]List.Elem else []List.Elem {
        if (List.RETURN_ERRORS) {
            try ensure_unused_capacity(List, self, count, alloc);
        } else {
            ensure_unused_capacity(List, self, count, alloc);
        }
        return insert_many_slots_assume_capacity(List, self, idx, count);
    }

    pub fn insert_many_slots_assume_capacity(comptime List: type, self: *List, idx: List.Idx, count: List.Idx) []List.Elem {
        assert(idx + count <= self.len);
        mem.copyBackwards(List.Elem, self.ptr[idx + count .. self.len + count], self.ptr[idx..self.len]);
        self.len += count;
        return self.ptr[idx .. idx + count];
    }

    pub fn insert_slice(comptime List: type, self: *List, idx: List.Idx, items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try insert_many_slots(List, self, idx, @intCast(items.len), alloc) else insert_many_slots(List, self, idx, @intCast(items.len), alloc);
        @memcpy(slots, items);
    }

    pub fn insert_slice_assume_capacity(comptime List: type, self: *List, idx: List.Idx, items: []const List.Elem) void {
        const slots = insert_many_slots_assume_capacity(List, self, idx, @intCast(items.len));
        @memcpy(slots, items);
    }

    pub fn replace_range(comptime List: type, self: *List, start: List.Idx, length: List.Idx, new_items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        if (new_items.len > length) {
            const additional_needed: List.Idx = @as(List.Idx, @intCast(new_items.len)) - length;
            if (List.RETURN_ERRORS) {
                try ensure_unused_capacity(List, self, additional_needed, alloc);
            } else {
                ensure_unused_capacity(List, self, additional_needed, alloc);
            }
        }
        replace_range_assume_capacity(List, self, start, length, new_items);
    }

    pub fn replace_range_assume_capacity(comptime List: type, self: *List, start: List.Idx, length: List.Idx, new_items: []const List.Elem) void {
        const end_of_range = start + length;
        assert(end_of_range <= self.len);
        const range = self.ptr[start..end_of_range];
        if (range.len == new_items.len)
            @memcpy(range[0..new_items.len], new_items)
        else if (range.len < new_items.len) {
            const within_range = new_items[0..range.len];
            const leftover = new_items[range.len..];
            @memcpy(range[0..within_range.len], within_range);
            const new_slots = insert_many_slots_assume_capacity(List, self, end_of_range, @intCast(leftover.len));
            @memcpy(new_slots, leftover);
        } else {
            const unused_slots: List.Idx = @intCast(range.len - new_items.len);
            @memcpy(range[0..new_items.len], new_items);
            std.mem.copyForwards(List.Elem, self.ptr[end_of_range - unused_slots .. self.len], self.ptr[end_of_range..self.len]);
            if (List.SECURE_WIPE) {
                crypto.secureZero(List.Elem, self.ptr[self.len - unused_slots .. self.len]);
            }
            self.len -= unused_slots;
        }
    }

    pub fn append(comptime List: type, self: *List, item: List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slot = if (List.RETURN_ERRORS) try append_slot(List, self, alloc) else append_slot(List, self, alloc);
        slot.* = item;
    }

    pub fn append_assume_capacity(comptime List: type, self: *List, item: List.Elem) void {
        const slot = append_slot_assume_capacity(List, self);
        slot.* = item;
    }

    pub fn remove(comptime List: type, self: *List, idx: List.Idx) List.Elem {
        const val: List.Elem = self.ptr[idx];
        delete(List, self, idx);
        return val;
    }

    pub fn swap_remove(comptime List: type, self: *List, idx: List.Idx) List.Elem {
        const val: List.Elem = self.ptr[idx];
        swap_delete(List, self, idx);
        return val;
    }

    pub fn delete(comptime List: type, self: *List, idx: List.Idx) void {
        assert(idx < self.len);
        std.mem.copyForwards(List.Elem, self.ptr[idx..self.len], self.ptr[idx + 1 .. self.len]);
        if (List.SECURE_WIPE) {
            crypto.secureZero(List.Elem, self.ptr[self.len - 1 .. self.len]);
        }
        self.len -= 1;
    }

    pub fn delete_range(comptime List: type, self: *List, start: List.Idx, length: List.Idx) void {
        const end_of_range = start + length;
        assert(end_of_range <= self.len);
        std.mem.copyForwards(List.Elem, self.ptr[start..self.len], self.ptr[end_of_range..self.len]);
        if (List.SECURE_WIPE) {
            crypto.secureZero(List.Elem, self.ptr[self.len - length .. self.len]);
        }
        self.len -= length;
    }

    pub fn swap_delete(comptime List: type, self: *List, idx: List.Idx) void {
        assert(idx < self.len);
        self.ptr[idx] = self.ptr[self.list.items.len - 1];
        if (List.SECURE_WIPE) {
            crypto.secureZero(List.Elem, self.ptr[self.len - 1 .. self.len]);
        }
        self.len -= 1;
    }

    pub fn append_slice(comptime List: type, self: *List, items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, @intCast(items.len), alloc) else append_many_slots(List, self, @intCast(items.len), alloc);
        @memcpy(slots, items);
    }

    pub fn append_slice_assume_capacity(comptime List: type, self: *List, items: []const List.Elem) void {
        const slots = append_many_slots_assume_capacity(List, self, @intCast(items.len));
        @memcpy(slots, items);
    }

    pub fn append_slice_unaligned(comptime List: type, self: *List, items: []align(1) const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, @intCast(items.len), alloc) else append_many_slots(List, self, @intCast(items.len), alloc);
        @memcpy(slots, items);
    }

    pub fn append_slice_unaligned_assume_capacity(comptime List: type, self: *List, items: []align(1) const List.Elem) void {
        const slots = append_many_slots_assume_capacity(List, self, @intCast(items.len));
        @memcpy(slots, items);
    }

    pub fn append_n_times(comptime List: type, self: *List, value: List.Elem, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, count, alloc) else append_many_slots(List, self, count, alloc);
        @memset(slots, value);
    }

    pub fn append_n_times_assume_capacity(comptime List: type, self: *List, value: List.Elem, count: List.Idx) void {
        const slots = append_many_slots_assume_capacity(List, self, count);
        @memset(slots, value);
    }

    pub fn resize(comptime List: type, self: *List, new_len: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        if (List.RETURN_ERRORS) {
            try ensure_total_capacity(List, self, new_len, alloc);
        } else {
            ensure_total_capacity(List, self, new_len, alloc);
        }
        if (List.SECURE_WIPE and new_len < self.len) {
            crypto.secureZero(List.Elem, self.ptr[new_len..self.len]);
        }
        self.len = new_len;
    }

    pub fn shrink_and_free(comptime List: type, self: *List, new_len: List.Idx, alloc: Allocator) void {
        assert(new_len <= self.len);

        if (@sizeOf(List.Elem) == 0) {
            self.items.len = new_len;
            return;
        }

        if (List.SECURE_WIPE) {
            crypto.secureZero(List.Elem, self.ptr[new_len..self.len]);
        }

        const old_memory = self.ptr[0..self.cap];
        if (alloc.remap(old_memory, new_len)) |new_items| {
            self.ptr = new_items.ptr;
            self.len = new_items.len;
            self.cap = new_items.len;
            return;
        }

        const new_memory = alloc.alignedAlloc(List.Elem, List.ALIGN, new_len) catch |err| return handle_alloc_error(List, err);

        @memcpy(new_memory, self.ptr[0..new_len]);
        alloc.free(old_memory);
        self.ptr = new_memory.ptr;
        self.len = new_memory.len;
        self.cap = new_memory.len;
    }

    pub fn shrink_retaining_capacity(comptime List: type, self: *List, new_len: List.Idx) void {
        assert(new_len <= self.len);
        if (List.SECURE_WIPE) {
            crypto.secureZero(List.Elem, self.ptr[new_len..self.len]);
        }
        self.len = new_len;
    }

    pub fn clear_retaining_capacity(comptime List: type, self: *List) void {
        if (List.SECURE_WIPE) {
            std.crypto.secureZero(List.Elem, self.ptr[0..self.len]);
        }
        self.len = 0;
    }

    pub fn clear_and_free(comptime List: type, self: *List, alloc: Allocator) void {
        if (List.SECURE_WIPE) {
            std.crypto.secureZero(List.Elem, self.ptr[0..self.len]);
        }
        alloc.free(self.ptr[0..self.cap]);
        self.* = List.EMPTY;
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

    pub fn expand_to_capacity(comptime List: type, self: *List) void {
        self.len = self.cap;
    }

    pub fn append_slot(comptime List: type, self: *List, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!*List.Elem else *List.Elem {
        const new_len = self.len + 1;
        if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
        return append_slot_assume_capacity(List, self);
    }

    pub fn append_slot_assume_capacity(comptime List: type, self: *List) *List.Elem {
        assert(self.len < self.cap);
        const idx = self.len;
        self.len += 1;
        return &self.ptr[idx];
    }

    pub fn append_many_slots(comptime List: type, self: *List, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error![]List.Elem else []List.Elem {
        const new_len = self.len + count;
        if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
        return append_many_slots_assume_capacity(List, self, count);
    }

    pub fn append_many_slots_assume_capacity(comptime List: type, self: *List, count: List.Idx) []List.Elem {
        const new_len = self.len + count;
        assert(new_len <= self.cap);
        const prev_len = self.len;
        self.len = new_len;
        return self.ptr[prev_len..][0..count];
    }

    pub fn append_many_slots_as_array(comptime List: type, self: *List, comptime count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!*[count]List.Elem else *[count]List.Elem {
        const new_len = self.len + count;
        if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
        return append_many_slots_as_array_assume_capacity(List, self, count);
    }

    pub fn append_many_slots_as_array_assume_capacity(comptime List: type, self: *List, comptime count: List.Idx) *[count]List.Elem {
        const new_len = self.len + count;
        assert(new_len <= self.cap);
        const prev_len = self.len;
        self.len = new_len;
        return self.ptr[prev_len..][0..count];
    }

    pub fn pop(comptime List: type, self: *List) List.Elem {
        assert(self.len > 0);
        const new_len = self.len - 1;
        self.len = new_len;
        return self.ptr[new_len];
    }

    pub fn pop_or_null(comptime List: type, self: *List) ?List.Elem {
        if (self.len == 0) return null;
        return pop(List, self);
    }

    pub fn get_last(comptime List: type, self: List) List.Elem {
        assert(self.len > 0);
        return self.ptr[self.len - 1];
    }

    pub fn get_last_or_null(comptime List: type, self: List) ?List.Elem {
        if (self.len == 0) return null;
        return get_last(List, self);
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

    pub fn find_idx(comptime List: type, self: List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?List.Idx {
        for (slice(List, self), 0..) |*item, idx| {
            if (match_fn(param, item)) return @intCast(idx);
        }
        return null;
    }

    pub fn find_ptr(comptime List: type, self: List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?*List.Elem {
        if (find_idx(List, self, P, param, match_fn)) |idx| {
            return &self.ptr[idx];
        }
        return null;
    }

    pub fn find_const_ptr(comptime List: type, self: List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?*const List.Elem {
        if (find_idx(List, self, P, param, match_fn)) |idx| {
            return &self.ptr[idx];
        }
        return null;
    }

    pub fn find_and_copy(comptime List: type, self: *List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?List.Elem {
        if (find_idx(List, self, P, param, match_fn)) |idx| {
            return self.ptr[idx];
        }
        return null;
    }

    pub fn find_and_remove(comptime List: type, self: *List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?List.Elem {
        if (find_idx(List, self, P, param, match_fn)) |idx| {
            return remove(List, self, idx);
        }
        return null;
    }

    pub fn find_and_delete(comptime List: type, self: *List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) bool {
        if (find_idx(List, self, P, param, match_fn)) |idx| {
            delete(List, self, idx);
            return true;
        }
        return false;
    }

    pub fn find_exactly_n_ordered_indexes_from_n_ordered_params(comptime List: type, self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const List.Elem) bool, output_buf: []List.Idx) bool {
        assert(output_buf.len >= params.len);
        var i: usize = 0;
        for (slice(List, self), 0..) |*item, idx| {
            if (match_fn(params[i], item)) {
                output_buf[i] = idx;
                i += 1;
                if (i == params.len) return true;
            }
        }
        return false;
    }

    pub fn find_exactly_n_ordered_pointers_from_n_ordered_params(comptime List: type, self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const List.Elem) bool, output_buf: []*List.Elem) bool {
        assert(output_buf.len >= params.len);
        var i: usize = 0;
        for (slice(List, self)) |*item| {
            if (match_fn(params[i], item)) {
                output_buf[i] = item;
                i += 1;
                if (i == params.len) return true;
            }
        }
        return false;
    }

    pub fn find_exactly_n_ordered_const_pointers_from_n_ordered_params(comptime List: type, self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const List.Elem) bool, output_buf: []*const List.Elem) bool {
        assert(output_buf.len >= params.len);
        var i: usize = 0;
        for (slice(List, self)) |*item| {
            if (match_fn(params[i], item)) {
                output_buf[i] = item;
                i += 1;
                if (i == params.len) return true;
            }
        }
        return false;
    }

    pub fn find_exactly_n_ordered_copies_from_n_ordered_params(comptime List: type, self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const List.Elem) bool, output_buf: []List.Elem) bool {
        assert(output_buf.len >= params.len);
        var i: usize = 0;
        for (slice(List, self)) |*item| {
            if (match_fn(params[i], item)) {
                output_buf[i] = item.*;
                i += 1;
                if (i == params.len) return true;
            }
        }
        return false;
    }

    pub fn delete_ordered_indexes(comptime List: type, self: *List, indexes: []const List.Idx) void {
        assert(indexes.len <= self.len);
        assert(check: {
            var i: usize = 1;
            while (i < indexes.len) : (i += 1) {
                if (indexes[i - 1] >= indexes[i]) break :check false;
            }
            break :check true;
        });
        var shift_down: usize = 1;
        var i: usize = 1;
        var src_start: List.Idx = undefined;
        var src_end: List.Idx = undefined;
        var dst_start: List.Idx = undefined;
        var dst_end: List.Idx = undefined;
        while (i < indexes.len) : (i += 1) {
            src_start = indexes[i - 1] + 1;
            src_end = indexes[i];
            dst_start = src_start - shift_down;
            dst_end = src_end - shift_down;
            std.mem.copyForwards(List.Idx, self.ptr[dst_start..dst_end], self.ptr[src_start..src_end]);
            shift_down += 1;
        }
        src_start = indexes[i] + 1;
        src_end = @intCast(self.len);
        dst_start = src_start - shift_down;
        dst_end = src_end - shift_down;
        std.mem.copyForwards(List.Idx, self.ptr[dst_start..dst_end], self.ptr[src_start..src_end]);
        self.len -= indexes.len;
    }

    // pub inline fn sort(comptime List: type, self: *List) void {
    //     custom_sort(List, self, List.DEFAULT_SORT_ALGO, List.DEFAULT_COMPARE_PKG);
    // }

    // pub fn custom_sort(comptime List: type, self: *List, algorithm: SortAlgorithm, compare_pkg: ComparePackage(List.Elem)) void {
    //     if (self.len < 2) return;
    //     switch (algorithm) {
    //         // SortAlgorithm.HEAP_SORT => {},
    //         .INSERTION_SORT => InsertionSort.insertion_sort(List.Elem, compare_pkg.greater_than, self.ptr[0..self.len]),
    //         .QUICK_SORT_PIVOT_FIRST => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.FIRST, self.ptr[0..self.len]),
    //         .QUICK_SORT_PIVOT_LAST => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.LAST, self.ptr[0..self.len]),
    //         .QUICK_SORT_PIVOT_MIDDLE => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.MIDDLE, self.ptr[0..self.len]),
    //         .QUICK_SORT_PIVOT_RANDOM => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.RANDOM, self.ptr[0..self.len]),
    //         .QUICK_SORT_PIVOT_MEDIAN_OF_3 => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.MEDIAN_OF_3, self.ptr[0..self.len]),
    //         .QUICK_SORT_PIVOT_MEDIAN_OF_3_RANDOM => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.MEDIAN_OF_3_RANDOM, self.ptr[0..self.len]),
    //     }
    // }

    // pub inline fn is_sorted(comptime List: type, self: *List) bool {
    //     return is_sorted_custom(List, self, List.DEFAULT_COMPARE_PKG.greater_than);
    // }

    // pub fn is_sorted_custom(comptime List: type, self: *List, greater_than_fn: *const CompareFn(List.Elem)) bool {
    //     if (self.len < 2) return true;
    //     var idx: List.Idx = 0;
    //     const limit = self.len - 1;
    //     while (idx < limit) : (idx += 1) {
    //         const next_idx = idx + 1;
    //         if (greater_than_fn(&self.ptr[idx], &self.ptr[next_idx])) return false;
    //     }
    //     return true;
    // }

    // pub inline fn insert_one_sorted(comptime List: type, self: *List, item: List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!List.Idx else List.Idx {
    //     return insert_one_sorted_custom(List, self, item, List.DEFAULT_COMPARE_PKG.greater_than, List.DEFAULT_MATCH_FN, alloc);
    // }

    // pub fn insert_one_sorted_custom(comptime List: type, self: *List, item: List.Elem, greater_than_fn: *const CompareFn(List.Elem), equal_order_fn: *const CompareFn(List.Elem), alloc: Allocator) if (List.RETURN_ERRORS) List.Error!List.Idx else List.Idx {
    //     const insert_idx: List.Idx = @intCast(BinarySearch.binary_search_insert_index(List.Elem, &item, self.ptr[0..self.len], greater_than_fn, equal_order_fn));
    //     if (List.RETURN_ERRORS) try insert(List, self, insert_idx, item, alloc) else insert(List, self, insert_idx, item, alloc);
    //     return insert_idx;
    // }

    // pub inline fn find_equal_order_idx_sorted(comptime List: type, self: *List, item_to_compare: *const List.Elem) ?List.Idx {
    //     return find_equal_order_idx_sorted_custom(List, self, item_to_compare, List.DEFAULT_COMPARE_PKG.greater_than, List.DEFAULT_MATCH_FN);
    // }

    // pub fn find_equal_order_idx_sorted_custom(comptime List: type, self: *List, item_to_compare: *const List.Elem, greater_than_fn: *const CompareFn(List.Elem), equal_order_fn: *const CompareFn(List.Elem)) ?List.Idx {
    //     const insert_idx = BinarySearch.binary_search_by_order(List.Elem, item_to_compare, self.ptr[0..self.len], greater_than_fn, equal_order_fn);
    //     if (insert_idx) |idx| return @intCast(idx);
    //     return null;
    // }

    // pub inline fn find_matching_item_idx_sorted(comptime List: type, self: *List, item_to_find: *const List.Elem) ?List.Idx {
    //     return find_matching_item_idx_sorted_custom(List, self, item_to_find, List.DEFAULT_COMPARE_PKG.greater_than, List.DEFAULT_COMPARE_PKG.equals, List.DEFAULT_MATCH_FN);
    // }

    // pub fn find_matching_item_idx_sorted_custom(comptime List: type, self: *List, item_to_find: *const List.Elem, greater_than_fn: *const CompareFn(List.Elem), equal_order_fn: *const CompareFn(List.Elem), exact_match_fn: *const CompareFn(List.Elem)) ?List.Idx {
    //     const insert_idx = BinarySearch.binary_search_exact_match(List.Elem, item_to_find, self.ptr[0..self.len], greater_than_fn, equal_order_fn, exact_match_fn);
    //     if (insert_idx) |idx| return @intCast(idx);
    //     return null;
    // }

    // pub inline fn find_matching_item_idx(comptime List: type, self: *List, item_to_find: *const List.Elem) ?List.Idx {
    //     return find_matching_item_idx_custom(List, self, item_to_find, List.DEFAULT_MATCH_FN);
    // }

    // pub fn find_matching_item_idx_custom(comptime List: type, self: *List, item_to_find: *const List.Elem, exact_match_fn: *const CompareFn(List.Elem)) ?List.Idx {
    //     if (self.len == 0) return null;
    //     const buf = self.ptr[0..self.len];
    //     var idx: List.Idx = 0;
    //     var found_exact = exact_match_fn(item_to_find, &buf[idx]);
    //     const limit = self.len - 1;
    //     while (!found_exact and idx < limit) {
    //         idx += 1;
    //         found_exact = exact_match_fn(item_to_find, &buf[idx]);
    //     }
    //     if (found_exact) return idx;
    //     return null;
    // }

    pub fn handle_alloc_error(comptime List: type, err: Allocator.Error) if (List.RETURN_ERRORS) List.Error else noreturn {
        switch (List.ALLOC_ERROR_BEHAVIOR) {
            AllocErrorBehavior.ALLOCATION_ERRORS_RETURN_ERROR => return err,
            AllocErrorBehavior.ALLOCATION_ERRORS_PANIC => std.debug.panic("List's backing allocator failed to allocate memory: Allocator.Error.{s}", .{@errorName(err)}),
            AllocErrorBehavior.ALLOCATION_ERRORS_ARE_UNREACHABLE => unreachable,
        }
    }
};

pub fn define_manually_managed_list_type(comptime options: ListOptions) type {
    const opt = comptime check: {
        var opts = options;
        if (opts.alignment) |a| {
            if (a == @alignOf(opts.T)) {
                opts.alignment = null;
            }
        }
        break :check opts;
    };
    if (opt.alignment) |a| {
        if (!math.isPowerOfTwo(a)) @panic("alignment must be a power of 2");
    }
    if (@typeInfo(opt.index_type) != Type.int or @typeInfo(opt.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
    return extern struct {
        ptr: Ptr = UNINIT_PTR,
        len: Idx = 0,
        cap: Idx = 0,

        pub const ALIGN = options.alignment;
        pub const ALLOC_ERROR_BEHAVIOR = options.alloc_error_behavior;
        pub const GROWTH = options.growth_model;
        pub const RETURN_ERRORS = options.alloc_error_behavior == .ALLOCATION_ERRORS_RETURN_ERROR;
        pub const SECURE_WIPE = options.secure_wipe_bytes;
        pub const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
        pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
        pub const EMPTY = List{};

        const List = @This();
        pub const Error = Allocator.Error;
        pub const Elem = options.element_type;
        pub const Idx = options.index_type;
        pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
        pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
        pub fn SentinelSlice(comptime sentinel: Elem) type {
            return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
        }

        pub inline fn flex_slice(self: List, comptime mutability: Mutability) FlexSlice(Elem, Idx, mutability) {
            return Impl.flex_slice(List, self, mutability);
        }

        pub inline fn slice(self: List) Slice {
            return Impl.zig_slice(List, self);
        }

        pub inline fn array_ptr(self: List, start: Idx, comptime length: Idx) *[length]Elem {
            return Impl.array_ptr(List, self, start, length);
        }

        pub inline fn vector_ptr(self: List, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
            return Impl.vector_ptr(List, self, start, length);
        }

        pub inline fn slice_with_sentinel(self: List, comptime sentinel: Elem) SentinelSlice(Elem) {
            return Impl.slice_with_sentinel(List, self, sentinel);
        }

        pub inline fn slice_full_capacity(self: List) Slice {
            return Impl.slice_full_capacity(List, self);
        }

        pub inline fn slice_unused_capacity(self: List) []Elem {
            return Impl.slice_unused_capacity(List, self);
        }

        pub inline fn set_len(self: *List, new_len: Idx) void {
            return Impl.set_len(List, self, new_len);
        }

        pub inline fn new_empty() List {
            return Impl.new_empty(List);
        }

        pub inline fn new_with_capacity(capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
            return Impl.new_with_capacity(List, capacity, alloc);
        }

        pub inline fn clone(self: List, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
            return Impl.clone(List, self, alloc);
        }

        pub inline fn to_owned_slice(self: *List, alloc: Allocator) if (RETURN_ERRORS) Error!Slice else Slice {
            return Impl.to_owned_slice(List, self, alloc);
        }

        pub inline fn to_owned_slice_sentinel(self: *List, alloc: Allocator, comptime sentinel: Elem) if (RETURN_ERRORS) Error!SentinelSlice(sentinel) else SentinelSlice(sentinel) {
            return Impl.to_owned_slice_sentinel(List, self, alloc, sentinel);
        }

        pub inline fn from_owned_slice(from_slice: Slice) List {
            return Impl.from_owned_slice(List, from_slice);
        }

        pub inline fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) List {
            return Impl.from_owned_slice_sentinel(List, sentinel, from_slice);
        }

        pub inline fn insert_slot(self: *List, idx: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.insert_slot(List, self, idx, alloc);
        }

        pub inline fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
            return Impl.insert_slot_assume_capacity(List, self, idx);
        }

        pub inline fn insert(self: *List, idx: Idx, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert(List, self, idx, item, alloc);
        }

        pub inline fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
            return Impl.insert_assume_capacity(List, self, idx, item);
        }

        pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return Impl.insert_many_slots(List, self, idx, count, alloc);
        }

        pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
            return Impl.insert_many_slots_assume_capacity(List, self, idx, count);
        }

        pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert_slice(List, self, idx, items, alloc);
        }

        pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
            return Impl.insert_slice_assume_capacity(List, self, idx, items);
        }

        pub inline fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.replace_range(List, self, start, length, new_items, alloc);
        }

        pub inline fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
            return Impl.replace_range_assume_capacity(List, self, start, length, new_items);
        }

        pub inline fn append(self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.append(List, self, item, alloc);
        }

        pub inline fn append_assume_capacity(self: *List, item: Elem) void {
            return Impl.append_assume_capacity(List, self, item);
        }

        pub inline fn remove(self: *List, idx: Idx) Elem {
            return Impl.remove(List, self, idx);
        }

        pub inline fn swap_remove(self: *List, idx: Idx) Elem {
            return Impl.swap_remove(List, self, idx);
        }

        pub inline fn delete(self: *List, idx: Idx) void {
            return Impl.delete(List, self, idx);
        }

        pub inline fn delete_range(self: *List, start: Idx, length: Idx) void {
            return Impl.delete_range(List, self, start, length);
        }

        pub inline fn swap_delete(self: *List, idx: Idx) void {
            return Impl.swap_delete(List, self, idx);
        }

        pub inline fn append_slice(self: *List, items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_slice(List, self, items, alloc);
        }

        pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            return Impl.append_slice_assume_capacity(List, self, items);
        }

        pub inline fn append_slice_unaligned(self: *List, items: []align(1) const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_slice_unaligned(List, self, items, alloc);
        }

        pub inline fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
            return Impl.append_slice_unaligned_assume_capacity(List, self, items);
        }

        pub inline fn append_n_times(self: *List, value: Elem, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_n_times(List, self, value, count, alloc);
        }

        pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.append_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn resize(self: *List, new_len: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.resize(List, self, new_len, alloc);
        }

        pub inline fn shrink_and_free(self: *List, new_len: Idx, alloc: Allocator) void {
            return Impl.shrink_and_free(List, self, new_len, alloc);
        }

        pub inline fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
            return Impl.shrink_retaining_capacity(List, self, new_len);
        }

        pub inline fn clear_retaining_capacity(self: *List) void {
            return Impl.clear_retaining_capacity(List, self);
        }

        pub inline fn clear_and_free(self: *List, alloc: Allocator) void {
            return Impl.clear_and_free(List, self, alloc);
        }

        pub inline fn ensure_total_capacity(self: *List, new_capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_total_capacity(List, self, new_capacity, alloc);
        }

        pub inline fn ensure_total_capacity_exact(self: *List, new_capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_total_capacity_exact(List, self, new_capacity, alloc);
        }

        pub inline fn ensure_unused_capacity(self: *List, additional_count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_unused_capacity(List, self, additional_count, alloc);
        }

        pub inline fn expand_to_capacity(self: *List) void {
            return Impl.expand_to_capacity(List, self);
        }

        pub inline fn append_slot(self: *List, alloc: Allocator) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.append_slot(List, self, alloc);
        }

        pub inline fn append_slot_assume_capacity(self: *List) *Elem {
            return Impl.append_slot_assume_capacity(List, self);
        }

        pub inline fn append_many_slots(self: *List, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return Impl.append_many_slots(List, self, count, alloc);
        }

        pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
            return Impl.append_many_slots_assume_capacity(List, self, count);
        }

        pub inline fn append_many_slots_as_array(self: *List, comptime count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
            return Impl.append_many_slots_as_array(List, self, count, alloc);
        }

        pub inline fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
            return Impl.append_many_slots_as_array_assume_capacity(List, self, count);
        }

        pub inline fn pop_or_null(self: *List) ?Elem {
            return Impl.pop_or_null(List, self);
        }

        pub inline fn pop(self: *List) Elem {
            return Impl.pop(List, self);
        }

        pub inline fn get_last(self: List) Elem {
            return Impl.get_last(List, self);
        }

        pub inline fn get_last_or_null(self: List) ?Elem {
            return Impl.get_last_or_null(List, self);
        }

        pub inline fn find_idx(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Idx {
            return Impl.find_idx(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*Elem {
            return Impl.find_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_const_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*const Elem {
            return Impl.find_const_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_and_copy(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
            return Impl.find_and_copy(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_and_remove(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
            return Impl.find_and_remove(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_and_delete(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) bool {
            return Impl.find_and_delete(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_exactly_n_ordered_indexes_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Idx) bool {
            return Impl.find_exactly_n_ordered_indexes_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_ordered_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*Elem) bool {
            return Impl.find_exactly_n_ordered_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_ordered_const_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*const Elem) bool {
            return Impl.find_exactly_n_ordered_const_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_ordered_copies_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Elem) bool {
            return Impl.find_exactly_n_ordered_copies_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
            return Impl.delete_ordered_indexes(List, self, indexes);
        }

        // pub inline fn sort(self: *List) void {
        //     return Internal.sort(List, self);
        // }

        // pub inline fn custom_sort(self: *List, algorithm: SortAlgorithm, order_func: *const CompareFn(Elem)) void {
        //     return Internal.custom_sort(List, self, algorithm, order_func);
        // }

        // pub inline fn is_sorted(self: *List) bool {
        //     return Internal.is_sorted(List, self);
        // }

        // pub inline fn is_sorted_custom(self: *List, compare_fn: *const CompareFn(Elem)) bool {
        //     return Internal.is_sorted_custom(List, self, compare_fn);
        // }

        // pub inline fn insert_one_sorted(self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted(List, self, item, alloc);
        // }

        // pub inline fn insert_one_sorted_custom(self: *List, item: Elem, compare_fn: *const CompareFn(Elem), comptime shortcut_equal_order: bool, alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted_custom(List, self, item, compare_fn, shortcut_equal_order, alloc);
        // }

        // pub inline fn find_equal_order_idx_sorted(self: *const List, item_to_compare: *const Elem) ?Idx {
        //     return Internal.find_equal_order_idx_sorted(List, self, item_to_compare);
        // }

        // pub fn find_equal_order_idx_sorted_custom(self: *const List, item_to_compare: *const Elem, compare_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_equal_order_idx_sorted_custom(List, self, item_to_compare, compare_fn);
        // }

        // pub inline fn find_matching_item_idx_sorted(self: *const List, item_to_find: *const Elem) ?Idx {
        //     return Internal.find_matching_item_idx_sorted(List, self, item_to_find);
        // }

        // pub fn find_matching_item_idx_sorted_custom(self: *const List, item_to_find: *const Elem, compare_fn: *const CompareFn(Elem), match_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_matching_item_idx_sorted_custom(List, self, item_to_find, compare_fn, match_fn);
        // }

        // pub inline fn find_matching_item_idx(self: *const List, item_to_find: *const Elem) ?Idx {
        //     return Internal.find_matching_item_idx(List, self, item_to_find);
        // }

        // pub fn find_matching_item_idx_custom(self: *const List, item_to_find: *const Elem, match_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_matching_item_idx_custom(List, self, item_to_find, match_fn);
        // }

        //**************************
        // std.io.Writer interface *
        //**************************
        const WriterHandle = struct {
            list: *List,
            alloc: Allocator,
        };
        const WriterHandleNoGrow = struct {
            list: *List,
        };

        pub const StdWriter = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(WriterHandle, Allocator.Error, write);

        pub fn get_std_writer(self: *List, alloc: Allocator) StdWriter {
            return StdWriter{ .context = .{ .list = self, .alloc = alloc } };
        }

        fn write(handle: WriterHandle, bytes: []const u8) Allocator.Error!usize {
            try handle.list.append_slice(bytes, handle.alloc);
            return bytes.len;
        }

        pub const StdWriterNoGrow = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(WriterHandleNoGrow, Allocator.Error, write_no_grow);

        pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
            return StdWriterNoGrow{ .context = .{ .list = self } };
        }

        fn write_no_grow(handle: WriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
            const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
            if (bytes.len > available_capacity) return error.OutOfMemory;
            handle.list.append_slice_assume_capacity(bytes);
            return bytes.len;
        }
    };
}

pub fn define_static_allocator_list_type(comptime base_options: ListOptions, comptime alloc_ptr: *const Allocator) type {
    const opt = comptime check: {
        var opts = base_options;
        if (opts.alignment) |a| {
            if (a == @alignOf(opts.T)) {
                opts.alignment = null;
            }
        }
        break :check opts;
    };
    if (opt.alignment) |a| {
        if (!math.isPowerOfTwo(a)) @panic("alignment must be a power of 2");
    }
    if (@typeInfo(opt.index_type) != Type.int or @typeInfo(opt.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
    return extern struct {
        ptr: Ptr = UNINIT_PTR,
        len: Idx = 0,
        cap: Idx = 0,

        pub const ALLOC = alloc_ptr;
        pub const ALIGN = base_options.alignment;
        pub const ALLOC_ERROR_BEHAVIOR = base_options.alloc_error_behavior;
        pub const GROWTH = base_options.growth_model;
        pub const RETURN_ERRORS = base_options.alloc_error_behavior == .ALLOCATION_ERRORS_RETURN_ERROR;
        pub const SECURE_WIPE = base_options.secure_wipe_bytes;
        pub const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
        pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
        pub const EMPTY = List{
            .ptr = UNINIT_PTR,
            .len = 0,
            .cap = 0,
        };

        const List = @This();
        pub const Error = Allocator.Error;
        pub const Elem = base_options.element_type;
        pub const Idx = base_options.index_type;
        pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
        pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
        pub fn SentinelSlice(comptime sentinel: Elem) type {
            return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
        }

        pub inline fn flex_slice(self: List, comptime mutability: Mutability) FlexSlice(Elem, Idx, mutability) {
            return Impl.flex_slice(List, self, mutability);
        }

        pub inline fn slice(self: List) Slice {
            return Impl.slice(List, self);
        }

        pub inline fn array_ptr(self: List, start: Idx, comptime length: Idx) *[length]Elem {
            return Impl.array_ptr(List, self, start, length);
        }

        pub inline fn vector_ptr(self: List, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
            return Impl.vector_ptr(List, self, start, length);
        }

        pub inline fn slice_with_sentinel(self: List, comptime sentinel: Elem) SentinelSlice(Elem) {
            return Impl.slice_with_sentinel(List, self, sentinel);
        }

        pub inline fn slice_full_capacity(self: List) Slice {
            return Impl.slice_full_capacity(List, self);
        }

        pub inline fn slice_unused_capacity(self: List) []Elem {
            return Impl.slice_unused_capacity(List, self);
        }

        pub inline fn set_len(self: *List, new_len: Idx) void {
            return Impl.set_len(List, self, new_len);
        }

        pub inline fn new_empty() List {
            return Impl.new_empty(List);
        }

        pub inline fn new_with_capacity(capacity: Idx) if (RETURN_ERRORS) Error!List else List {
            return Impl.new_with_capacity(List, capacity, ALLOC.*);
        }

        pub inline fn clone(self: List) if (RETURN_ERRORS) Error!List else List {
            return Impl.clone(List, self, ALLOC.*);
        }

        pub inline fn to_owned_slice(self: *List) if (RETURN_ERRORS) Error!Slice else Slice {
            return Impl.to_owned_slice(List, self, ALLOC.*);
        }

        pub inline fn to_owned_slice_sentinel(self: *List, comptime sentinel: Elem) if (RETURN_ERRORS) Error!SentinelSlice(sentinel) else SentinelSlice(sentinel) {
            return Impl.to_owned_slice_sentinel(List, self, sentinel, ALLOC.*);
        }

        pub inline fn from_owned_slice(from_slice: Slice) List {
            return Impl.from_owned_slice(List, from_slice);
        }

        pub inline fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) List {
            return Impl.from_owned_slice_sentinel(List, sentinel, from_slice);
        }

        pub inline fn insert_slot(self: *List, idx: Idx) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.insert_slot(List, self, idx, ALLOC.*);
        }

        pub inline fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
            return Impl.insert_slot_assume_capacity(List, self, idx);
        }

        pub inline fn insert(self: *List, idx: Idx, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert(List, self, idx, item, ALLOC.*);
        }

        pub inline fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
            return Impl.insert_assume_capacity(List, self, idx, item);
        }

        pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return Impl.insert_many_slots(List, self, idx, count, ALLOC.*);
        }

        pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
            return Impl.insert_many_slots_assume_capacity(List, self, idx, count);
        }

        pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert_slice(List, self, idx, items, ALLOC.*);
        }

        pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
            return Impl.insert_slice_assume_capacity(List, self, idx, items);
        }

        pub inline fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.replace_range(List, self, start, length, new_items, ALLOC.*);
        }

        pub inline fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
            return Impl.replace_range_assume_capacity(List, self, start, length, new_items);
        }

        pub inline fn append(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append(List, self, item, ALLOC.*);
        }

        pub inline fn append_assume_capacity(self: *List, item: Elem) void {
            return Impl.append_assume_capacity(List, self, item);
        }

        pub inline fn remove(self: *List, idx: Idx) Elem {
            return Impl.remove(List, self, idx);
        }

        pub inline fn swap_remove(self: *List, idx: Idx) Elem {
            return Impl.swap_remove(List, self, idx);
        }

        pub inline fn delete(self: *List, idx: Idx) void {
            return Impl.delete(List, self, idx);
        }

        pub inline fn delete_range(self: *List, start: Idx, length: Idx) void {
            return Impl.delete_range(List, self, start, length);
        }

        pub inline fn swap_delete(self: *List, idx: Idx) void {
            return Impl.swap_delete(List, self, idx);
        }

        pub inline fn append_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_slice(List, self, items, ALLOC.*);
        }

        pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            return Impl.append_slice_assume_capacity(List, self, items);
        }

        pub inline fn append_slice_unaligned(self: *List, items: []align(1) const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_slice_unaligned(List, self, items, ALLOC.*);
        }

        pub inline fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
            return Impl.append_slice_unaligned_assume_capacity(List, self, items);
        }

        pub inline fn append_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_n_times(List, self, value, count, ALLOC.*);
        }

        pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.append_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn resize(self: *List, new_len: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.resize(List, self, new_len, ALLOC.*);
        }

        pub inline fn shrink_and_free(self: *List, new_len: Idx) void {
            return Impl.shrink_and_free(List, self, new_len, ALLOC.*);
        }

        pub inline fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
            return Impl.shrink_retaining_capacity(List, self, new_len);
        }

        pub inline fn clear_retaining_capacity(self: *List) void {
            return Impl.clear_retaining_capacity(List, self);
        }

        pub inline fn clear_and_free(self: *List) void {
            return Impl.clear_and_free(List, self, ALLOC.*);
        }

        pub inline fn ensure_total_capacity(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_total_capacity(List, self, new_capacity, ALLOC.*);
        }

        pub inline fn ensure_total_capacity_exact(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_total_capacity_exact(List, self, new_capacity, ALLOC.*);
        }

        pub inline fn ensure_unused_capacity(self: *List, additional_count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_unused_capacity(List, self, additional_count, ALLOC.*);
        }

        pub inline fn expand_to_capacity(self: *List) void {
            return Impl.expand_to_capacity(List, self);
        }

        pub inline fn append_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.append_slot(List, self, ALLOC.*);
        }

        pub inline fn append_slot_assume_capacity(self: *List) *Elem {
            return Impl.append_slot_assume_capacity(List, self);
        }

        pub inline fn append_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return Impl.append_many_slots(List, self, count, ALLOC.*);
        }

        pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
            return Impl.append_many_slots_assume_capacity(List, self, count);
        }

        pub inline fn append_many_slots_as_array(self: *List, comptime count: Idx) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
            return Impl.append_many_slots_as_array(List, self, count, ALLOC.*);
        }

        pub inline fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
            return Impl.append_many_slots_as_array_assume_capacity(List, self, count);
        }

        pub inline fn pop_or_null(self: *List) ?Elem {
            return Impl.pop_or_null(List, self);
        }

        pub inline fn pop(self: *List) Elem {
            return Impl.pop(List, self);
        }

        pub inline fn get_last(self: List) Elem {
            return Impl.get_last(List, self);
        }

        pub inline fn get_last_or_null(self: List) ?Elem {
            return Impl.get_last_or_null(List, self);
        }

        pub inline fn find_idx(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Idx {
            return Impl.find_idx(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*Elem {
            return Impl.find_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_const_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*const Elem {
            return Impl.find_const_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_and_copy(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
            return Impl.find_and_copy(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_and_remove(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
            return Impl.find_and_remove(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_and_delete(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) bool {
            return Impl.find_and_delete(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_exactly_n_ordered_indexes_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Idx) bool {
            return Impl.find_exactly_n_ordered_indexes_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_ordered_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*Elem) bool {
            return Impl.find_exactly_n_ordered_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_ordered_const_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*const Elem) bool {
            return Impl.find_exactly_n_ordered_const_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_ordered_copies_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Elem) bool {
            return Impl.find_exactly_n_ordered_copies_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
            return Impl.delete_ordered_indexes(List, self, indexes);
        }

        // pub inline fn sort(self: *List) void {
        //     return Internal.sort(List, self);
        // }

        // pub inline fn custom_sort(self: *List, algorithm: SortAlgorithm, order_func: *const fn (a: *const List.Elem, b: *const List.Elem) Compare.Order) void {
        //     return Internal.custom_sort(List, self, algorithm, order_func);
        // }

        // pub inline fn is_sorted(self: *List) bool {
        //     return Internal.is_sorted(List, self);
        // }

        // pub inline fn is_sorted_custom(self: *List, greater_than_fn: *const CompareFn(Elem)) bool {
        //     return Internal.is_sorted_custom(List, self, greater_than_fn);
        // }

        // pub inline fn insert_one_sorted(self: *List, item: Elem) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted(List, self, item, ALLOC.*);
        // }

        // pub inline fn insert_one_sorted_custom(self: *List, item: Elem, compare_fn: *const CompareFn(Elem), comptime shortcut_equal_order: bool) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted_custom(List, self, item, compare_fn, shortcut_equal_order, ALLOC.*);
        // }

        // pub inline fn find_equal_order_idx_sorted(self: *const List, item_to_compare: *const Elem) ?Idx {
        //     return Internal.find_equal_order_idx_sorted(List, self, item_to_compare);
        // }

        // pub fn find_equal_order_idx_sorted_custom(self: *const List, item_to_compare: *const Elem, compare_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_equal_order_idx_sorted_custom(List, self, item_to_compare, compare_fn);
        // }

        // pub inline fn find_matching_item_idx_sorted(self: *const List, item_to_find: *const Elem) ?Idx {
        //     return Internal.find_matching_item_idx_sorted(List, self, item_to_find);
        // }

        // pub fn find_matching_item_idx_sorted_custom(self: *const List, item_to_find: *const Elem, compare_fn: *const CompareFn(Elem), match_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_matching_item_idx_sorted_custom(List, self, item_to_find, compare_fn, match_fn);
        // }

        // pub inline fn find_matching_item_idx(self: *const List, item_to_find: *const Elem) ?Idx {
        //     return Internal.find_matching_item_idx(List, self, item_to_find);
        // }

        // pub fn find_matching_item_idx_custom(self: *const List, item_to_find: *const Elem, match_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_matching_item_idx_custom(List, self, item_to_find, match_fn);
        // }

        //**************************
        // std.io.Writer interface *
        //**************************
        const WriterHandle = struct {
            list: *List,
        };

        pub const StdWriter = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(WriterHandle, Allocator.Error, write);

        pub fn get_std_writer(self: *List, alloc: Allocator) StdWriter {
            return StdWriter{ .context = .{ .list = self, .alloc = alloc } };
        }

        fn write(handle: WriterHandle, bytes: []const u8) Allocator.Error!usize {
            try handle.list.append_slice(bytes);
            return bytes.len;
        }

        pub const StdWriterNoGrow = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(WriterHandle, Allocator.Error, write_no_grow);

        pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
            return StdWriterNoGrow{ .context = .{ .list = self } };
        }

        fn write_no_grow(handle: WriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
            const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
            if (bytes.len > available_capacity) return error.OutOfMemory;
            handle.list.append_slice_assume_capacity(bytes);
            return bytes.len;
        }
    };
}

pub fn define_cached_allocator_list_type(comptime base_options: ListOptions) type {
    const opt = comptime check: {
        var opts = base_options;
        if (opts.alignment) |a| {
            if (a == @alignOf(opts.T)) {
                opts.alignment = null;
            }
        }
        break :check opts;
    };
    if (opt.alignment) |a| {
        if (!math.isPowerOfTwo(a)) @panic("alignment must be a power of 2");
    }
    if (@typeInfo(opt.index_type) != Type.int or @typeInfo(opt.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
    return extern struct {
        ptr: Ptr = UNINIT_PTR,
        alloc_ptr: *anyopaque,
        alloc_vtable: *const Allocator.VTable,
        len: Idx = 0,
        cap: Idx = 0,

        pub const ALIGN = base_options.alignment;
        pub const ALLOC_ERROR_BEHAVIOR = base_options.alloc_error_behavior;
        pub const GROWTH = base_options.growth_model;
        pub const RETURN_ERRORS = base_options.alloc_error_behavior == .ALLOCATION_ERRORS_RETURN_ERROR;
        pub const SECURE_WIPE = base_options.secure_wipe_bytes;
        pub const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
        pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
        pub const EMPTY = List{
            .ptr = UNINIT_PTR,
            .alloc_ptr = DummyAllocator.allocator.ptr,
            .alloc_vtable = DummyAllocator.allocator.vtable,
            .len = 0,
            .cap = 0,
        };

        const List = @This();
        pub const Error = Allocator.Error;
        pub const Elem = base_options.element_type;
        pub const Idx = base_options.index_type;
        pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
        pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
        pub fn SentinelSlice(comptime sentinel: Elem) type {
            return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
        }

        pub inline fn get_alloc(self: List) Allocator {
            return Allocator{
                .ptr = self.alloc_ptr,
                .vtable = self.alloc_vtable,
            };
        }

        pub inline fn set_alloc(self: *List, alloc: Allocator) void {
            self.alloc_ptr = alloc.ptr;
            self.alloc_vtable = alloc.vtable;
        }

        pub inline fn flex_slice(self: List, comptime mutability: Mutability) FlexSlice(Elem, Idx, mutability) {
            return Impl.flex_slice(List, self, mutability);
        }

        pub inline fn slice(self: List) Slice {
            return Impl.slice(List, self);
        }

        pub inline fn array_ptr(self: List, start: Idx, comptime length: Idx) *[length]Elem {
            return Impl.array_ptr(List, self, start, length);
        }

        pub inline fn vector_ptr(self: List, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
            return Impl.vector_ptr(List, self, start, length);
        }

        pub inline fn slice_with_sentinel(self: List, comptime sentinel: Elem) SentinelSlice(Elem) {
            return Impl.slice_with_sentinel(List, self, sentinel);
        }

        pub inline fn slice_full_capacity(self: List) Slice {
            return Impl.slice_full_capacity(List, self);
        }

        pub inline fn slice_unused_capacity(self: List) []Elem {
            return Impl.slice_unused_capacity(List, self);
        }

        pub inline fn set_len(self: *List, new_len: Idx) void {
            return Impl.set_len(List, self, new_len);
        }

        pub inline fn new_empty(alloc: Allocator) List {
            const list: List = Impl.new_empty(List);
            list.set_alloc(alloc);
            return list;
        }

        pub inline fn new_with_capacity(capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
            const list: List = try Impl.new_with_capacity(List, capacity, alloc);
            list.set_alloc(alloc);
            return list;
        }

        pub inline fn clone(self: List) if (RETURN_ERRORS) Error!List else List {
            return Impl.clone(List, self, self.get_alloc());
        }

        pub inline fn to_owned_slice(self: *List) if (RETURN_ERRORS) Error!Slice else Slice {
            return Impl.to_owned_slice(List, self, self.get_alloc());
        }

        pub inline fn to_owned_slice_sentinel(self: *List, comptime sentinel: Elem) if (RETURN_ERRORS) Error!SentinelSlice(sentinel) else SentinelSlice(sentinel) {
            return Impl.to_owned_slice_sentinel(List, self, sentinel, self.get_alloc());
        }

        pub inline fn from_owned_slice(from_slice: Slice) List {
            return Impl.from_owned_slice(List, from_slice);
        }

        pub inline fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) List {
            return Impl.from_owned_slice_sentinel(List, sentinel, from_slice);
        }

        pub inline fn insert_slot(self: *List, idx: Idx) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.insert_slot(List, self, idx, self.get_alloc());
        }

        pub inline fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
            return Impl.insert_slot_assume_capacity(List, self, idx);
        }

        pub inline fn insert(self: *List, idx: Idx, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert(List, self, idx, item, self.get_alloc());
        }

        pub inline fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
            return Impl.insert_assume_capacity(List, self, idx, item);
        }

        pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return Impl.insert_many_slots(List, self, idx, count, self.get_alloc());
        }

        pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
            return Impl.insert_many_slots_assume_capacity(List, self, idx, count);
        }

        pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert_slice(List, self, idx, items, self.get_alloc());
        }

        pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
            return Impl.insert_slice_assume_capacity(List, self, idx, items);
        }

        pub inline fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.replace_range(List, self, start, length, new_items, self.get_alloc());
        }

        pub inline fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
            return Impl.replace_range_assume_capacity(List, self, start, length, new_items);
        }

        pub inline fn append(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append(List, self, item, self.get_alloc());
        }

        pub inline fn append_assume_capacity(self: *List, item: Elem) void {
            return Impl.append_assume_capacity(List, self, item);
        }

        pub inline fn remove(self: *List, idx: Idx) Elem {
            return Impl.remove(List, self, idx);
        }

        pub inline fn swap_remove(self: *List, idx: Idx) Elem {
            return Impl.swap_remove(List, self, idx);
        }

        pub inline fn delete(self: *List, idx: Idx) void {
            return Impl.delete(List, self, idx);
        }

        pub inline fn delete_range(self: *List, start: Idx, length: Idx) void {
            return Impl.delete_range(List, self, start, length);
        }

        pub inline fn swap_delete(self: *List, idx: Idx) void {
            return Impl.swap_delete(List, self, idx);
        }

        pub inline fn append_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_slice(List, self, items, self.get_alloc());
        }

        pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            return Impl.append_slice_assume_capacity(List, self, items);
        }

        pub inline fn append_slice_unaligned(self: *List, items: []align(1) const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_slice_unaligned(List, self, items, self.get_alloc());
        }

        pub inline fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
            return Impl.append_slice_unaligned_assume_capacity(List, self, items);
        }

        pub inline fn append_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_n_times(List, self, value, count, self.get_alloc());
        }

        pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.append_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn resize(self: *List, new_len: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.resize(List, self, new_len, self.get_alloc());
        }

        pub inline fn shrink_and_free(self: *List, new_len: Idx) void {
            return Impl.shrink_and_free(List, self, new_len, self.get_alloc());
        }

        pub inline fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
            return Impl.shrink_retaining_capacity(List, self, new_len);
        }

        pub inline fn clear_retaining_capacity(self: *List) void {
            return Impl.clear_retaining_capacity(List, self);
        }

        pub inline fn clear_and_free(self: *List) void {
            return Impl.clear_and_free(List, self, self.get_alloc());
        }

        pub inline fn ensure_total_capacity(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_total_capacity(List, self, new_capacity, self.get_alloc());
        }

        pub inline fn ensure_total_capacity_exact(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_total_capacity_exact(List, self, new_capacity, self.get_alloc());
        }

        pub inline fn ensure_unused_capacity(self: *List, additional_count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_unused_capacity(List, self, additional_count, self.get_alloc());
        }

        pub inline fn expand_to_capacity(self: *List) void {
            return Impl.expand_to_capacity(List, self);
        }

        pub inline fn append_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.append_slot(List, self, self.get_alloc());
        }

        pub inline fn append_slot_assume_capacity(self: *List) *Elem {
            return Impl.append_slot_assume_capacity(List, self);
        }

        pub inline fn append_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return Impl.append_many_slots(List, self, count, self.get_alloc());
        }

        pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
            return Impl.append_many_slots_assume_capacity(List, self, count);
        }

        pub inline fn append_many_slots_as_array(self: *List, comptime count: Idx) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
            return Impl.append_many_slots_as_array(List, self, count, self.get_alloc());
        }

        pub inline fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
            return Impl.append_many_slots_as_array_assume_capacity(List, self, count);
        }

        pub inline fn pop_or_null(self: *List) ?Elem {
            return Impl.pop_or_null(List, self);
        }

        pub inline fn pop(self: *List) Elem {
            return Impl.pop(List, self);
        }

        pub inline fn get_last(self: List) Elem {
            return Impl.get_last(List, self);
        }

        pub inline fn get_last_or_null(self: List) ?Elem {
            return Impl.get_last_or_null(List, self);
        }

        pub inline fn find_idx(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Idx {
            return Impl.find_idx(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*Elem {
            return Impl.find_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_const_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*const Elem {
            return Impl.find_const_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_and_copy(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
            return Impl.find_and_copy(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_and_remove(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
            return Impl.find_and_remove(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_and_delete(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) bool {
            return Impl.find_and_delete(List, self, @TypeOf(match_param), match_param, match_fn);
        }

        pub inline fn find_exactly_n_ordered_indexes_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Idx) bool {
            return Impl.find_exactly_n_ordered_indexes_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_ordered_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*Elem) bool {
            return Impl.find_exactly_n_ordered_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_ordered_const_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*const Elem) bool {
            return Impl.find_exactly_n_ordered_const_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_ordered_copies_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Elem) bool {
            return Impl.find_exactly_n_ordered_copies_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
        }

        pub inline fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
            return Impl.delete_ordered_indexes(List, self, indexes);
        }

        // pub inline fn sort(self: *List) void {
        //     return Internal.sort(List, self);
        // }

        // pub inline fn custom_sort(self: *List, algorithm: SortAlgorithm, order_func: *const fn (a: *const List.Elem, b: *const List.Elem) Compare.Order) void {
        //     return Internal.custom_sort(List, self, algorithm, order_func);
        // }

        // pub inline fn is_sorted(self: *List) bool {
        //     return Internal.is_sorted(List, self);
        // }

        // pub inline fn is_sorted_custom(self: *List, compare_fn: *const CompareFn(Elem)) bool {
        //     return Internal.is_sorted_custom(List, self, compare_fn);
        // }

        // pub inline fn insert_one_sorted(self: *List, item: Elem) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted(List, self, item, self.get_alloc());
        // }

        // pub inline fn insert_one_sorted_custom(self: *List, item: Elem, compare_fn: *const CompareFn(Elem), comptime shortcut_equal_order: bool) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted_custom(List, self, item, compare_fn, shortcut_equal_order, self.get_alloc());
        // }

        // pub inline fn find_equal_order_idx_sorted(self: *const List, item_to_compare: *const Elem) ?Idx {
        //     return Internal.find_equal_order_idx_sorted(List, self, item_to_compare);
        // }

        // pub fn find_equal_order_idx_sorted_custom(self: *const List, item_to_compare: *const Elem, compare_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_equal_order_idx_sorted_custom(List, self, item_to_compare, compare_fn);
        // }

        // pub inline fn find_matching_item_idx_sorted(self: *const List, item_to_find: *const Elem) ?Idx {
        //     return Internal.find_matching_item_idx_sorted(List, self, item_to_find);
        // }

        // pub fn find_matching_item_idx_sorted_custom(self: *const List, item_to_find: *const Elem, compare_fn: *const CompareFn(Elem), match_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_matching_item_idx_sorted_custom(List, self, item_to_find, compare_fn, match_fn);
        // }

        // pub inline fn find_matching_item_idx(self: *const List, item_to_find: *const Elem) ?Idx {
        //     return Internal.find_matching_item_idx(List, self, item_to_find);
        // }

        // pub fn find_matching_item_idx_custom(self: *const List, item_to_find: *const Elem, match_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_matching_item_idx_custom(List, self, item_to_find, match_fn);
        // }

        //**************************
        // std.io.Writer interface *
        //**************************
        const WriterHandle = struct {
            list: *List,
        };

        pub const StdWriter = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(WriterHandle, Allocator.Error, write);

        pub fn get_std_writer(self: *List) StdWriter {
            return StdWriter{ .context = .{ .list = self } };
        }

        fn write(handle: WriterHandle, bytes: []const u8) Allocator.Error!usize {
            try handle.list.append_slice(bytes);
            return bytes.len;
        }

        pub const StdWriterNoGrow = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(WriterHandle, Allocator.Error, write_no_grow);

        pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
            return StdWriterNoGrow{ .context = .{ .list = self } };
        }

        fn write_no_grow(handle: WriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
            const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
            if (bytes.len > available_capacity) return error.OutOfMemory;
            handle.list.append_slice_assume_capacity(bytes);
            return bytes.len;
        }
    };
}

test "LinkedList.zig" {
    const t = std.testing;
    const alloc = std.heap.page_allocator;
    const base_opts = ListOptions{
        .alloc_error_behavior = .ALLOCATION_ERRORS_PANIC,
        .element_type = u8,
        .index_type = u32,
    };
    const List = define_manually_managed_list_type(base_opts);
    var list = List.new_empty();
    list.append('H', alloc);
    list.append('e', alloc);
    list.append('l', alloc);
    list.append('l', alloc);
    list.append('o', alloc);
    list.append(' ', alloc);
    list.append_slice("World", alloc);
    try t.expectEqualStrings("Hello World", list.slice().to_zig_slice());
    const letter_l = list.remove(2);
    try t.expectEqual('l', letter_l);
    try t.expectEqualStrings("Helo World", list.slice().to_zig_slice());
    list.replace_range(3, 3, &.{ 'a', 'b', 'c' }, alloc);
    try t.expectEqualStrings("Helabcorld", list.slice().to_zig_slice());
}
