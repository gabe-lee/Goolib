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
const Utils = Root.Utils;
const inline_swap = Utils.inline_swap;

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

    pub fn raw_slice(comptime List: type, self: List) SoftSlice(List.Elem, List.Idx) {
        return SoftSlice(List.Elem, List.Idx).new(self.ptr, self.cap);
    }

    pub fn full_cap_slices_in_order(comptime List: type, self: List) DisjointSlicePair(List.Idx, List.Elem) {
        return DisjointSlicePair(List.Idx, List.Elem){
            .first = SoftSlice(List.Elem, List.Idx).new(self.ptr + self.start, self.cap - self.start),
            .second = SoftSlice(List.Elem, List.Idx).new(self.ptr, self.start),
        };
    }

    pub fn slices_in_order_with_cap(comptime List: type, self: List) DisjointSlicePairWithCap(List.Idx, List.Elem) {
        const start_to_cap = self.cap - self.start;
        const len_1 = @min(self.len, start_to_cap);
        const len_1_room_before_end = start_to_cap - len_1;
        const len_2 = self.len - len_1;
        const len_2_room_before_end = self.start - len_2;
        return DisjointSlicePairWithCap(List.Idx, List.Elem){
            .first = SoftSlice(List.Elem, List.Idx).new(self.ptr + self.start, len_1),
            .first_extra_cap = len_1_room_before_end,
            .second = SoftSlice(List.Elem, List.Idx).new(self.ptr, len_2),
            .second_extra_cap = len_2_room_before_end,
        };
    }

    pub fn slices_in_order(comptime List: type, self: List) DisjointSlicePair(List.Idx, List.Elem) {
        const start_to_cap = self.cap - self.start;
        const len_1 = @min(self.len, start_to_cap);
        const len_2 = self.len - len_1;
        return DisjointSlicePair(List.Idx, List.Elem){
            .first = SoftSlice(List.Elem, List.Idx).new(self.ptr + self.start, len_1),
            .second = SoftSlice(List.Elem, List.Idx).new(self.ptr, len_2),
        };
    }

    pub inline fn get_range_start_end(comptime List: type, self: List, start_offset: List.Idx, end_offset: List.Idx) DisjointSlicePair(List.Idx, List.Elem) {
        assert(end_offset >= start_offset);
        return get_range_start_len(List, self, start_offset, end_offset - start_offset);
    }

    pub inline fn get_range_start_end_with_cap(comptime List: type, self: List, start_offset: List.Idx, end_offset: List.Idx) DisjointSlicePairWithCap(List.Idx, List.Elem) {
        assert(end_offset >= start_offset);
        return get_range_start_len_with_cap(List, self, start_offset, end_offset - start_offset);
    }

    pub fn get_range_start_len(comptime List: type, self: List, start_offset: List.Idx, len: List.Idx) DisjointSlicePair(List.Idx, List.Elem) {
        assert(start_offset + len <= self.len);
        const start_1 = @min(self.start + start_offset, self.cap);
        const len_1 = @min(len, self.cap - start_1);
        const len_2 = len - len_1;
        return DisjointSlicePair(List.Idx, List.Elem){
            .first = SoftSlice(List.Elem, List.Idx).new(self.ptr + start_1, len_1),
            .second = SoftSlice(List.Elem, List.Idx).new(self.ptr, len_2),
        };
    }

    pub fn get_range_start_len_with_cap(comptime List: type, self: List, start_offset: List.Idx, len: List.Idx) DisjointSlicePairWithCap(List.Idx, List.Elem) {
        assert(start_offset + len <= self.len);
        const start_1 = @min(self.start + start_offset, self.cap);
        const len_1 = @min(len, self.cap - start_1);
        const extra_room_1 = self.cap - (start_1 + len_1);
        const len_2 = len - len_1;
        const extra_room_2 = self.start - len_2;
        return DisjointSlicePairWithCap(List.Idx, List.Elem){
            .first = SoftSlice(List.Elem, List.Idx).new(self.ptr + start_1, len_1),
            .first_extra_cap = extra_room_1,
            .second = SoftSlice(List.Elem, List.Idx).new(self.ptr, len_2),
            .second_extra_cap = extra_room_2,
        };
    }

    pub fn get_val(comptime List: type, self: List, idx: List.Idx) List.Elem {
        assert(idx < self.len);
        const real_idx = @mod(self.start + idx, self.cap);
        return self.ptr[real_idx];
    }

    pub fn get_val_ptr(comptime List: type, self: List, idx: List.Idx) *List.Elem {
        assert(idx < self.len);
        const real_idx = @mod(self.start + idx, self.cap);
        return &self.ptr[real_idx];
    }

    pub fn set_val(comptime List: type, self: List, idx: List.Idx, val: List.Elem) void {
        assert(idx < self.len);
        const real_idx = @mod(self.start + idx, self.cap);
        self.ptr[real_idx] = val;
    }

    pub fn set_range_start_len(comptime List: type, self: List, start_offset: List.Idx, len: List.Idx, src_buf: []const List.Elem) void {
        assert(start_offset + len <= self.len);
        assert(len <= src_buf.len);
        const slices = get_range_start_len(List, self, start_offset, len);
        const src_1 = SoftSlice(List.Elem, List.Idx).new(src_buf.ptr, slices.first.len);
        const src_2 = src_1.new_slice_after(slices.second.len);
        src_1.memcopy_to(slices.first.to_native());
        src_2.memcopy_to(slices.second.to_native());
    }

    pub inline fn set_range_start_end(comptime List: type, self: List, start_offset: List.Idx, end_offset: List.Idx, src_buf: []const List.Elem) void {
        assert(end_offset >= start_offset);
        return set_range_start_len(List, self, start_offset, end_offset - start_offset, src_buf);
    }

    pub fn realign_to_start(comptime List: type, self: *List) void {
        if (self.start == 0) return;
        const slices = slices_in_order_with_cap(List, self);
        if (slices.second.len == 0) {
            if (self.start >= self.len) {
                if (List.SECURE_WIPE) {
                    _ = slices.first.copy_leftward_and_zero_old(self.start);
                } else {
                    _ = slices.first.copy_leftward(self.start);
                }
            } else {
                if (List.SECURE_WIPE) {
                    _ = slices.first.copy_leftward_and_zero_old(self.start);
                } else {
                    _ = slices.first.copy_leftward(self.start);
                }
            }
            self.start = 0;
            return;
        }
        if (self.start >= self.len) {
            _ = slices.second.copy_rightward(slices.first.len);
            if (List.SECURE_WIPE) {
                _ = slices.first.copy_leftward_and_zero_old(self.start);
            } else {
                _ = slices.first.copy_leftward(self.start);
            }
            self.start = 0;
            return;
        }
        const slice = raw_slice(List, self);
        var write_idx: List.Idx = 0;
        var read_idx: List.Idx = self.start;
        var temp: List.Elem = undefined;
        while (write_idx < self.start) {
            slice.swap(read_idx, write_idx);
            read_idx += 1;
            write_idx += 1;
            if (read_idx == self.cap) read_idx = self.start;
        }
        if (write_idx < read_idx) {
            if (read_idx == self.cap - 1) {
                temp = slice.get_item(read_idx);
                _ = slice.sub_slice_start_end(write_idx, read_idx).copy_rightward(1);
                slice.set_item(write_idx, temp);
            } else if (read_idx == write_idx + 1) {
                temp = slice.get_item(write_idx);
                _ = slice.sub_slice_start_end(read_idx, self.cap).copy_leftward(1);
                slice.set_last_item(temp);
            } else {
                while (read_idx < self.cap) {
                    slice.swap(read_idx, write_idx);
                    read_idx += 1;
                    write_idx += 1;
                }
                read_idx = write_idx + 1;
                temp = slice.get_item(write_idx);
                _ = slice.sub_slice_start_end(read_idx, self.cap).copy_leftward(1);
                slice.set_last_item(temp);
            }
        }
        if (List.SECURE_WIPE) {
            slice.sub_slice_start_end(self.len, self.cap).secure_zero();
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
            var slices = slices_in_order_with_cap(List, self);
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
            const slices = slices_in_order_with_cap(List, self);
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

    pub fn prepend_slot(comptime List: type, self: *List, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!*List.Elem else *List.Elem {
        const new_len = self.len + 1;
        if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
        return prepend_slot_assume_capacity(List, self);
    }

    pub fn prepend_slot_assume_capacity(comptime List: type, self: *List) *List.Elem {
        assert(self.len < self.cap);
        const new_start = @mod((@as(isize, @intCast(self.start)) - 1), self.cap);
        self.len += 1;
        self.start = @intCast(new_start);
        return &self.ptr[@intCast(self.start)];
    }

    pub fn prepend(comptime List: type, self: *List, item: List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slot = if (List.RETURN_ERRORS) try prepend_slot(List, self, alloc) else prepend_slot(List, self, alloc);
        slot.* = item;
    }

    pub fn prepend_assume_capacity(comptime List: type, self: *List, item: List.Elem) void {
        const slot = prepend_slot_assume_capacity(List, self);
        slot.* = item;
    }

    pub fn prepend_many_slots(comptime List: type, self: *List, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!DisjointSlicePair(List.Idx, List.Elem) else DisjointSlicePair(List.Idx, List.Elem) {
        const new_len = self.len + count;
        if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
        return prepend_many_slots_assume_capacity(List, self, count);
    }

    pub fn prepend_many_slots_assume_capacity(comptime List: type, self: *List, count: List.Idx) DisjointSlicePair(List.Idx, List.Elem) {
        const new_len = self.len + count;
        assert(new_len <= self.cap);
        const new_start = @mod((@as(isize, @intCast(self.start)) - @as(isize, @intCast(count))), self.cap);
        self.len = new_len;
        self.start = @intCast(new_start);
        return get_range_start_len(List, self, self.start, count).no_cap();
    }

    pub fn prepend_slice(comptime List: type, self: *List, items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try prepend_many_slots(List, self, @intCast(items.len), alloc) else prepend_many_slots(List, self, @intCast(items.len), alloc);
        Utils.memcopy(items.ptr, slots.first.ptr, slots.first.len);
        Utils.memcopy(items.ptr + slots.first.len, slots.second.ptr, slots.second.len);
    }

    pub fn prepend_slice_assume_capacity(comptime List: type, self: *List, items: []const List.Elem) void {
        const slots = prepend_many_slots_assume_capacity(List, self, @intCast(items.len));
        Utils.memcopy(items.ptr, slots.first.ptr, slots.first.len);
        Utils.memcopy(items.ptr + slots.first.len, slots.second.ptr, slots.second.len);
    }

    pub fn prepend_n_times(comptime List: type, self: *List, value: List.Elem, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try prepend_many_slots(List, self, count, alloc) else prepend_many_slots(List, self, count, alloc);
        slots.first.memset(value);
        slots.second.memset(value);
    }

    pub fn prepend_n_times_assume_capacity(comptime List: type, self: *List, value: List.Elem, count: List.Idx) void {
        const slots = prepend_many_slots_assume_capacity(List, self, count);
        slots.first.memset(value);
        slots.second.memset(value);
    }

    pub fn append_slot(comptime List: type, self: *List, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!*List.Elem else *List.Elem {
        const new_len = self.len + 1;
        if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
        return append_slot_assume_capacity(List, self);
    }

    pub fn append_slot_assume_capacity(comptime List: type, self: *List) *List.Elem {
        assert(self.len < self.cap);
        const idx = @mod((self.start + self.len), self.cap);
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

    pub fn append_many_slots(comptime List: type, self: *List, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!DisjointSlicePair(List.Idx, List.Elem) else DisjointSlicePair(List.Idx, List.Elem) {
        const new_len = self.len + count;
        if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
        return append_many_slots_assume_capacity(List, self, count);
    }

    pub fn append_many_slots_assume_capacity(comptime List: type, self: *List, count: List.Idx) DisjointSlicePair(List.Idx, List.Elem) {
        const new_len = self.len + count;
        assert(new_len <= self.cap);
        const appended_start = self.len;
        self.len = new_len;
        return get_range_start_len(List, self, appended_start, count).no_cap();
    }

    pub fn append_slice(comptime List: type, self: *List, items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, @intCast(items.len), alloc) else append_many_slots(List, self, @intCast(items.len), alloc);
        Utils.memcopy(items.ptr, slots.first.ptr, slots.first.len);
        Utils.memcopy(items.ptr + slots.first.len, slots.second.ptr, slots.second.len);
    }

    pub fn append_slice_assume_capacity(comptime List: type, self: *List, items: []const List.Elem) void {
        const slots = append_many_slots_assume_capacity(List, self, @intCast(items.len));
        Utils.memcopy(items.ptr, slots.first.ptr, slots.first.len);
        Utils.memcopy(items.ptr + slots.first.len, slots.second.ptr, slots.second.len);
    }

    pub fn append_n_times(comptime List: type, self: *List, value: List.Elem, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, count, alloc) else append_many_slots(List, self, count, alloc);
        slots.first.memset(value);
        slots.second.memset(value);
    }

    pub fn append_n_times_assume_capacity(comptime List: type, self: *List, value: List.Elem, count: List.Idx) void {
        const slots = append_many_slots_assume_capacity(List, self, count);
        slots.first.memset(value);
        slots.second.memset(value);
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
        const slices = get_range_start_len(List, self, idx, self.len - idx);
        if (slices.first_extra_cap >= 1) {
            _ = slices.first.copy_rightward(1);
            self.len += 1;
            return slices.first.get_item_ptr(0);
        }
        if (slices.second.len > 0) {
            _ = slices.second.copy_rightward(1);
        }
        slices.second.set_item(0, slices.first.get_item_from_end(0));
        const slice_1_shrunk = slices.first.shrink_right(1);
        slice_1_shrunk.copy_rightward(1);
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

    pub fn insert_many_slots(comptime List: type, self: *List, idx: List.Idx, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!DisjointSlicePair(List.Idx, List.Elem) else DisjointSlicePair(List.Idx, List.Elem) {
        if (List.RETURN_ERRORS) {
            try ensure_unused_capacity(List, self, count, alloc);
        } else {
            ensure_unused_capacity(List, self, count, alloc);
        }
        return insert_many_slots_assume_capacity(List, self, idx, count);
    }

    pub fn insert_many_slots_assume_capacity(comptime List: type, self: *List, idx: List.Idx, count: List.Idx) DisjointSlicePair(List.Idx, List.Elem) {
        assert(idx + count <= self.len);
        const slices = get_range_start_len(List, self, idx, self.len - idx);
        if (slices.first_extra_cap >= count) {
            _ = slices.first.copy_rightward(count);
            self.len += count;
            return DisjointSlicePair(List.Idx, List.Elem).new_first_only(slices.first.sub_slice_from_start(count));
        }
        if (slices.second.len > 0) {
            _ = slices.second.copy_rightward(count);
        }
        if (slices.first.len >= count) {
            const end_of_1 = slices.first.sub_slice_from_end(count);
            const begin_of_2 = slices.second.sub_slice_from_start(count);
            end_of_1.memcopy_to(begin_of_2);
            const slice_1_shrunk = slices.first.shrink_right(count);
            slice_1_shrunk.copy_rightward(count);
            self.len += count;
            return DisjointSlicePair(List.Idx, List.Elem).new_first_only(slices.first.sub_slice_from_start(count));
        }
        const remaining_after_1 = count - slices.first.len;
        const return_2 = slices.second.sub_slice_from_start(remaining_after_1);
        const new_spot_for_1 = return_2.new_slice_after(slices.first.len);
        slices.first.memcopy_to(new_spot_for_1, false);
        return DisjointSlicePair(List.Idx, List.Elem).new_both(slices.first, return_2);
    }

    pub fn insert_slice(comptime List: type, self: *List, idx: List.Idx, items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try insert_many_slots(List, self, idx, @intCast(items.len), alloc) else insert_many_slots(List, self, idx, @intCast(items.len), alloc);
        @memcpy(slots.first.to_native(), items[0..slots.first.len]);
        @memcpy(slots.second.to_native(), items[0..slots.second.len]);
    }

    pub fn insert_slice_assume_capacity(comptime List: type, self: *List, idx: List.Idx, items: []const List.Elem) void {
        const slots = insert_many_slots_assume_capacity(List, self, idx, @intCast(items.len));
        @memcpy(slots.first.to_native(), items[0..slots.first.len]);
        @memcpy(slots.second.to_native(), items[0..slots.second.len]);
    }

    pub fn insert_n_times(comptime List: type, self: *List, value: List.Elem, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
        const slots = if (List.RETURN_ERRORS) try insert_many_slots(List, self, count, alloc) else insert_many_slots(List, self, count, alloc);
        slots.first.memset(value);
        slots.second.memset(value);
    }

    pub fn insert_n_times_assume_capacity(comptime List: type, self: *List, value: List.Elem, count: List.Idx) void {
        const slots = insert_many_slots_assume_capacity(List, self, count);
        slots.first.memset(value);
        slots.second.memset(value);
    }

    pub fn pop_last(comptime List: type, self: *List) List.Elem {
        assert(self.len >= 1);
        const val = self.ptr[@mod(self.start + self.len - 1, self.cap)];
        trim_end(List, self, 1);
        return val;
    }

    pub fn pop_first(comptime List: type, self: *List) List.Elem {
        assert(self.len >= 1);
        const val = self.ptr[self.start];
        trim_start(List, self, 1);
        return val;
    }

    pub fn pop_last_n_array(comptime List: type, self: *List, comptime count: List.Idx) [count]List.Elem {
        assert(self.len >= count);
        const result: [count]List.Elem = undefined;
        const slices = get_range_start_len(List, self, self.len - count, count);
        const result_slice_1 = SoftSlice(List.Elem, List.Idx).new(result[0..count].ptr, slices.first.len);
        const result_slice_2 = result_slice_1.new_slice_after(slices.second.len);
        slices.first.memcopy_to(result_slice_1.to_native());
        slices.second.memcopy_to(result_slice_2.to_native());
        trim_end(List, self, count);
        return result;
    }

    pub fn pop_first_n_array(comptime List: type, self: *List, comptime count: List.Idx) [count]List.Elem {
        assert(self.len >= count);
        const result: [count]List.Elem = undefined;
        const slices = get_range_start_len(List, self, 0, count);
        const result_slice_1 = SoftSlice(List.Elem, List.Idx).new(result[0..count].ptr, slices.first.len);
        const result_slice_2 = result_slice_1.new_slice_after(slices.second.len);
        slices.first.memcopy_to(result_slice_1.to_native());
        slices.second.memcopy_to(result_slice_2.to_native());
        trim_start(List, self, count);
        return result;
    }

    pub fn pop_last_n_to_buf(comptime List: type, self: *List, count: List.Idx, dst_buf: []List.Elem) void {
        assert(self.len >= count);
        assert(dst_buf.len >= count);
        const slices = get_range_start_len(List, self, self.len - count, count);
        const result_slice_1 = SoftSlice(List.Elem, List.Idx).new(dst_buf.ptr, slices.first.len);
        const result_slice_2 = result_slice_1.new_slice_after(slices.second.len);
        slices.first.memcopy_to(result_slice_1.to_native());
        slices.second.memcopy_to(result_slice_2.to_native());
        trim_end(List, self, count);
    }

    pub fn pop_first_n_to_buf(comptime List: type, self: *List, comptime count: List.Idx, dst_buf: []List.Elem) void {
        assert(self.len >= count);
        assert(dst_buf.len >= count);
        const slices = get_range_start_len(List, self, 0, count);
        const result_slice_1 = SoftSlice(List.Elem, List.Idx).new(dst_buf.ptr, slices.first.len);
        const result_slice_2 = result_slice_1.new_slice_after(slices.second.len);
        slices.first.memcopy_to(result_slice_1.to_native());
        slices.second.memcopy_to(result_slice_2.to_native());
        trim_start(List, self, count);
    }

    pub fn trim_end(comptime List: type, self: *List, count: List.Idx) List.Elem {
        assert(self.len >= count);
        self.len -= count;
    }

    pub fn trim_start(comptime List: type, self: *List, count: List.Idx) List.Elem {
        assert(self.len >= count);
        self.start = @mod(self.start + count, self.cap);
        self.len -= count;
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

pub fn define_static_allocator_ring_buffer_type(comptime options: RingListOptions, alloc_ptr: *const Allocator) type {
    return extern struct {
        const List = @This();

        ptr: Ptr,
        start: Idx,
        len: Idx,
        cap: Idx,

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
        pub const Slice = SoftSlice(Elem, Idx);
        pub const DisjointSlice = DisjointSlicePair(Idx, Elem);

        pub inline fn new_empty() List {
            return Impl.new_empty(List);
        }

        pub inline fn new_with_capacity(cap: Idx) List {
            return Impl.new_with_capacity(List, cap, ALLOC.*);
        }

        pub inline fn raw_slice(self: List) Slice {
            return Impl.raw_slice(List, self);
        }

        pub inline fn full_cap_slices_in_order(self: List) DisjointSlice {
            return Impl.full_cap_slices_in_order(List, self);
        }

        pub inline fn slices_in_order(self: List) DisjointSlice {
            return Impl.slices_in_order_with_cap(List, self).no_cap();
        }

        pub inline fn slices_in_order_from_range(self: List, start: Idx, count: Idx) DisjointSlice {
            return Impl.get_range_start_len(List, self, start, count).no_cap();
        }

        pub inline fn get_range_start_end(self: List, start_offset: List.Idx, end_offset: List.Idx) DisjointSlicePair {
            return Impl.get_range_start_end(List, self, start_offset, end_offset);
        }

        pub inline fn get_range_start_count(self: List, start_offset: Idx, count: Idx) DisjointSlicePair {
            return Impl.get_range_start_len(List, self, start_offset, count);
        }

        pub inline fn get_val(self: List, idx: Idx) Elem {
            return Impl.get_val(List, self, idx);
        }

        pub inline fn get_val_ptr(self: List, idx: Idx) *Elem {
            return Impl.get_val_ptr(List, self, idx);
        }

        pub inline fn set_val(self: List, idx: Idx, val: Elem) void {
            return Impl.set_val(List, self, idx, val);
        }

        pub inline fn set_range_start_len(self: List, start_offset: Idx, len: Idx, src_buf: []const Elem) void {
            return Impl.set_range_start_len(List, self, start_offset, len, src_buf);
        }

        pub inline fn set_range_start_end(self: List, start_offset: Idx, end_offset: Idx, src_buf: []const Elem) void {
            return Impl.set_range_start_end(List, self, start_offset, end_offset, src_buf);
        }

        pub inline fn realign_to_start(self: *List) void {
            return Impl.realign_to_start(List, self);
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

        pub inline fn prepend_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.prepend_slot(List, self, ALLOC.*);
        }

        pub inline fn prepend_slot_assume_capacity(self: *List) *Elem {
            return Impl.prepend_slot_assume_capacity(List, self);
        }

        pub inline fn prepend(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.prepend(List, self, item, ALLOC.*);
        }

        pub inline fn prepend_assume_capacity(self: *List, item: Elem) void {
            return Impl.prepend_assume_capacity(List, self, item);
        }

        pub inline fn prepend_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error!DisjointSlice else DisjointSlice {
            return Impl.prepend_many_slots(List, self, count, ALLOC.*);
        }

        pub inline fn prepend_many_slots_assume_capacity(self: *List, count: Idx) DisjointSlice {
            return Impl.prepend_many_slots_assume_capacity(List, self, count);
        }

        pub inline fn prepend_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.prepend_slice(List, self, items, ALLOC.*);
        }

        pub inline fn prepend_slice_assume_capacity(self: *List, items: []const Elem) void {
            return Impl.prepend_slice_assume_capacity(List, self, items);
        }

        pub inline fn prepend_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.prepend_n_times(List, self, value, count, ALLOC.*);
        }

        pub inline fn prepend_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.prepend_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn append_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.append_slot(List, self, ALLOC.*);
        }

        pub inline fn append_slot_assume_capacity(self: *List) *Elem {
            return Impl.append_slot_assume_capacity(List, self);
        }

        pub inline fn append(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append(List, self, item, ALLOC.*);
        }

        pub inline fn append_assume_capacity(self: *List, item: Elem) void {
            return Impl.append_assume_capacity(List, self, item);
        }

        pub inline fn append_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error!DisjointSlice else DisjointSlice {
            return Impl.append_many_slots(List, self, count, ALLOC.*);
        }

        pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) DisjointSlice {
            return Impl.append_many_slots_assume_capacity(List, self, count);
        }

        pub inline fn append_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_slice(List, self, items, ALLOC.*);
        }

        pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            return Impl.append_slice_assume_capacity(List, self, items);
        }

        pub inline fn append_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_n_times(List, self, value, count, ALLOC.*);
        }

        pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.append_n_times_assume_capacity(List, self, value, count);
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

        pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx) if (RETURN_ERRORS) Error!DisjointSlice else DisjointSlice {
            return Impl.insert_many_slots(List, self, idx, count, ALLOC.*);
        }

        pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) DisjointSlice {
            return Impl.insert_many_slots_assume_capacity(List, self, idx, count);
        }

        pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert_slice(List, self, idx, items, ALLOC.*);
        }

        pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
            return Impl.insert_slice_assume_capacity(List, self, idx, items);
        }

        pub inline fn insert_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert_n_times(List, self, value, count, ALLOC.*);
        }

        pub inline fn insert_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.insert_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn pop_last(self: *List) Elem {
            return Impl.pop_last(List, self);
        }

        pub inline fn pop_first(self: *List) Elem {
            return Impl.pop_first(List, self);
        }

        pub inline fn pop_last_n_array(self: *List, comptime count: Idx) [count]Elem {
            return Impl.pop_last_n_array(List, self, count);
        }

        pub inline fn pop_first_n_array(self: *List, comptime count: Idx) [count]Elem {
            return Impl.pop_first_n_array(List, self, count);
        }

        pub inline fn pop_last_n_to_buf(self: *List, count: Idx, dst_buf: []Elem) void {
            return Impl.pop_last_n_to_buf(List, self, count, dst_buf);
        }

        pub inline fn pop_first_n_to_buf(self: *List, comptime count: Idx, dst_buf: []Elem) void {
            return Impl.pop_first_n_to_buf(List, self, count, dst_buf);
        }

        pub inline fn trim_end(self: *List, count: Idx) Elem {
            return Impl.trim_end(List, self, count);
        }

        pub inline fn trim_start(self: *List, count: Idx) Elem {
            return Impl.trim_start(List, self, count);
        }
    };
}

pub fn define_manual_allocator_ring_buffer_type(comptime options: RingListOptions) type {
    return extern struct {
        const List = @This();

        ptr: Ptr,
        start: Idx,
        len: Idx,
        cap: Idx,

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
        pub const Slice = SoftSlice(Elem, Idx);
        pub const DisjointSlice = DisjointSlicePair(Idx, Elem);

        pub inline fn new_empty() List {
            return Impl.new_empty(List);
        }

        pub inline fn new_with_capacity(cap: Idx, alloc: Allocator) List {
            return Impl.new_with_capacity(List, cap, alloc);
        }

        pub inline fn raw_slice(self: List) Slice {
            return Impl.raw_slice(List, self);
        }

        pub inline fn full_cap_slices_in_order(self: List) DisjointSlice {
            return Impl.full_cap_slices_in_order(List, self);
        }

        pub inline fn slices_in_order(self: List) DisjointSlice {
            return Impl.slices_in_order_with_cap(List, self).no_cap();
        }

        pub inline fn slices_in_order_from_range(self: List, start: Idx, count: Idx) DisjointSlice {
            return Impl.get_range_start_len(List, self, start, count).no_cap();
        }

        pub inline fn get_range_start_end(self: List, start_offset: List.Idx, end_offset: List.Idx) DisjointSlicePair {
            return Impl.get_range_start_end(List, self, start_offset, end_offset);
        }

        pub inline fn get_range_start_count(self: List, start_offset: Idx, count: Idx) DisjointSlicePair {
            return Impl.get_range_start_len(List, self, start_offset, count);
        }

        pub inline fn get_val(self: List, idx: Idx) Elem {
            return Impl.get_val(List, self, idx);
        }

        pub inline fn get_val_ptr(self: List, idx: Idx) *Elem {
            return Impl.get_val_ptr(List, self, idx);
        }

        pub inline fn set_val(self: List, idx: Idx, val: Elem) void {
            return Impl.set_val(List, self, idx, val);
        }

        pub inline fn set_range_start_len(self: List, start_offset: Idx, len: Idx, src_buf: []const Elem) void {
            return Impl.set_range_start_len(List, self, start_offset, len, src_buf);
        }

        pub inline fn set_range_start_end(self: List, start_offset: Idx, end_offset: Idx, src_buf: []const Elem) void {
            return Impl.set_range_start_end(List, self, start_offset, end_offset, src_buf);
        }

        pub inline fn realign_to_start(self: *List) void {
            return Impl.realign_to_start(List, self);
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

        pub inline fn prepend_slot(self: *List, alloc: Allocator) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.prepend_slot(List, self, alloc);
        }

        pub inline fn prepend_slot_assume_capacity(self: *List) *Elem {
            return Impl.prepend_slot_assume_capacity(List, self);
        }

        pub inline fn prepend(self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.prepend(List, self, item, alloc);
        }

        pub inline fn prepend_assume_capacity(self: *List, item: Elem) void {
            return Impl.prepend_assume_capacity(List, self, item);
        }

        pub inline fn prepend_many_slots(self: *List, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!DisjointSlice else DisjointSlice {
            return Impl.prepend_many_slots(List, self, count, alloc);
        }

        pub inline fn prepend_many_slots_assume_capacity(self: *List, count: Idx) DisjointSlice {
            return Impl.prepend_many_slots_assume_capacity(List, self, count);
        }

        pub inline fn prepend_slice(self: *List, items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.prepend_slice(List, self, items, alloc);
        }

        pub inline fn prepend_slice_assume_capacity(self: *List, items: []const Elem) void {
            return Impl.prepend_slice_assume_capacity(List, self, items);
        }

        pub inline fn prepend_n_times(self: *List, value: Elem, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.prepend_n_times(List, self, value, count, alloc);
        }

        pub inline fn prepend_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.prepend_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn append_slot(self: *List, alloc: Allocator) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.append_slot(List, self, alloc);
        }

        pub inline fn append_slot_assume_capacity(self: *List) *Elem {
            return Impl.append_slot_assume_capacity(List, self);
        }

        pub inline fn append(self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.append(List, self, item, alloc);
        }

        pub inline fn append_assume_capacity(self: *List, item: Elem) void {
            return Impl.append_assume_capacity(List, self, item);
        }

        pub inline fn append_many_slots(self: *List, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!DisjointSlice else DisjointSlice {
            return Impl.append_many_slots(List, self, count, alloc);
        }

        pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) DisjointSlice {
            return Impl.append_many_slots_assume_capacity(List, self, count);
        }

        pub inline fn append_slice(self: *List, items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_slice(List, self, items, alloc);
        }

        pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            return Impl.append_slice_assume_capacity(List, self, items);
        }

        pub inline fn append_n_times(self: *List, value: Elem, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_n_times(List, self, value, count, alloc);
        }

        pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.append_n_times_assume_capacity(List, self, value, count);
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

        pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!DisjointSlice else DisjointSlice {
            return Impl.insert_many_slots(List, self, idx, count, alloc);
        }

        pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) DisjointSlice {
            return Impl.insert_many_slots_assume_capacity(List, self, idx, count);
        }

        pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert_slice(List, self, idx, items, alloc);
        }

        pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
            return Impl.insert_slice_assume_capacity(List, self, idx, items);
        }

        pub inline fn insert_n_times(self: *List, value: Elem, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert_n_times(List, self, value, count, alloc);
        }

        pub inline fn insert_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.insert_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn pop_last(self: *List) Elem {
            return Impl.pop_last(List, self);
        }

        pub inline fn pop_first(self: *List) Elem {
            return Impl.pop_first(List, self);
        }

        pub inline fn pop_last_n_array(self: *List, comptime count: Idx) [count]Elem {
            return Impl.pop_last_n_array(List, self, count);
        }

        pub inline fn pop_first_n_array(self: *List, comptime count: Idx) [count]Elem {
            return Impl.pop_first_n_array(List, self, count);
        }

        pub inline fn pop_last_n_to_buf(self: *List, count: Idx, dst_buf: []Elem) void {
            return Impl.pop_last_n_to_buf(List, self, count, dst_buf);
        }

        pub inline fn pop_first_n_to_buf(self: *List, comptime count: Idx, dst_buf: []Elem) void {
            return Impl.pop_first_n_to_buf(List, self, count, dst_buf);
        }

        pub inline fn trim_end(self: *List, count: Idx) Elem {
            return Impl.trim_end(List, self, count);
        }

        pub inline fn trim_start(self: *List, count: Idx) Elem {
            return Impl.trim_start(List, self, count);
        }
    };
}

pub fn define_cached_allocator_ring_buffer_type(comptime options: RingListOptions) type {
    return extern struct {
        const List = @This();

        ptr: Ptr,
        alloc: Allocator,
        start: Idx,
        len: Idx,
        cap: Idx,

        pub const ALLOC_ERROR_BEHAVIOR = options.alloc_error_behavior;
        pub const GROWTH = options.growth_model;
        pub const RETURN_ERRORS = options.alloc_error_behavior == .ALLOCATION_ERRORS_RETURN_ERROR;
        pub const SECURE_WIPE = options.secure_wipe_bytes;
        pub const UNINIT_PTR: Ptr = mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem));
        pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
        pub const EMPTY = List{
            .ptr = UNINIT_PTR,
            .alloc = DummyAllocator.allocator,
            .len = 0,
            .cap = 0,
            .start = 0,
        };

        pub const Error = Allocator.Error;
        pub const Elem = options.element_type;
        pub const Idx = options.index_type;
        pub const Ptr = [*]Elem;
        pub const Slice = SoftSlice(Elem, Idx);
        pub const DisjointSlice = DisjointSlicePair(Idx, Elem);

        pub inline fn new_empty(alloc: Allocator) List {
            var list = Impl.new_empty(List);
            list.alloc = alloc;
            return list;
        }

        pub inline fn new_with_capacity(cap: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
            var list = if (RETURN_ERRORS) try Impl.new_with_capacity(List, cap, alloc) else Impl.new_with_capacity(List, cap, alloc);
            list.alloc = alloc;
            return list;
        }

        pub inline fn raw_slice(self: List) Slice {
            return Impl.raw_slice(List, self);
        }

        pub inline fn full_cap_slices_in_order(self: List) DisjointSlice {
            return Impl.full_cap_slices_in_order(List, self);
        }

        pub inline fn slices_in_order(self: List) DisjointSlice {
            return Impl.slices_in_order_with_cap(List, self).no_cap();
        }

        pub inline fn slices_in_order_from_range(self: List, start: Idx, count: Idx) DisjointSlice {
            return Impl.get_range_start_len(List, self, start, count).no_cap();
        }

        pub inline fn get_range_start_end(self: List, start_offset: List.Idx, end_offset: List.Idx) DisjointSlicePair {
            return Impl.get_range_start_end(List, self, start_offset, end_offset);
        }

        pub inline fn get_range_start_count(self: List, start_offset: Idx, count: Idx) DisjointSlicePair {
            return Impl.get_range_start_len(List, self, start_offset, count);
        }

        pub inline fn get_val(self: List, idx: Idx) Elem {
            return Impl.get_val(List, self, idx);
        }

        pub inline fn get_val_ptr(self: List, idx: Idx) *Elem {
            return Impl.get_val_ptr(List, self, idx);
        }

        pub inline fn set_val(self: List, idx: Idx, val: Elem) void {
            return Impl.set_val(List, self, idx, val);
        }

        pub inline fn set_range_start_len(self: List, start_offset: Idx, len: Idx, src_buf: []const Elem) void {
            return Impl.set_range_start_len(List, self, start_offset, len, src_buf);
        }

        pub inline fn set_range_start_end(self: List, start_offset: Idx, end_offset: Idx, src_buf: []const Elem) void {
            return Impl.set_range_start_end(List, self, start_offset, end_offset, src_buf);
        }

        pub inline fn realign_to_start(self: *List) void {
            return Impl.realign_to_start(List, self);
        }

        pub inline fn ensure_total_capacity(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_total_capacity(List, self, new_capacity, self.alloc);
        }

        pub inline fn ensure_total_capacity_exact(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_total_capacity_exact(List, self, new_capacity, self.alloc);
        }

        pub inline fn ensure_unused_capacity(self: *List, additional_count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.ensure_unused_capacity(List, self, additional_count, self.alloc);
        }

        pub inline fn prepend_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.prepend_slot(List, self, self.alloc);
        }

        pub inline fn prepend_slot_assume_capacity(self: *List) *Elem {
            return Impl.prepend_slot_assume_capacity(List, self);
        }

        pub inline fn prepend(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.prepend(List, self, item, self.alloc);
        }

        pub inline fn prepend_assume_capacity(self: *List, item: Elem) void {
            return Impl.prepend_assume_capacity(List, self, item);
        }

        pub inline fn prepend_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error!DisjointSlice else DisjointSlice {
            return Impl.prepend_many_slots(List, self, count, self.alloc);
        }

        pub inline fn prepend_many_slots_assume_capacity(self: *List, count: Idx) DisjointSlice {
            return Impl.prepend_many_slots_assume_capacity(List, self, count);
        }

        pub inline fn prepend_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.prepend_slice(List, self, items, self.alloc);
        }

        pub inline fn prepend_slice_assume_capacity(self: *List, items: []const Elem) void {
            return Impl.prepend_slice_assume_capacity(List, self, items);
        }

        pub inline fn prepend_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.prepend_n_times(List, self, value, count, self.alloc);
        }

        pub inline fn prepend_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.prepend_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn append_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.append_slot(List, self, self.alloc);
        }

        pub inline fn append_slot_assume_capacity(self: *List) *Elem {
            return Impl.append_slot_assume_capacity(List, self);
        }

        pub inline fn append(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append(List, self, item, self.alloc);
        }

        pub inline fn append_assume_capacity(self: *List, item: Elem) void {
            return Impl.append_assume_capacity(List, self, item);
        }

        pub inline fn append_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error!DisjointSlice else DisjointSlice {
            return Impl.append_many_slots(List, self, count, self.alloc);
        }

        pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) DisjointSlice {
            return Impl.append_many_slots_assume_capacity(List, self, count);
        }

        pub inline fn append_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_slice(List, self, items, self.alloc);
        }

        pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            return Impl.append_slice_assume_capacity(List, self, items);
        }

        pub inline fn append_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.append_n_times(List, self, value, count, self.alloc);
        }

        pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.append_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn insert_slot(self: *List, idx: Idx) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return Impl.insert_slot(List, self, idx, self.alloc);
        }

        pub inline fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
            return Impl.insert_slot_assume_capacity(List, self, idx);
        }

        pub inline fn insert(self: *List, idx: Idx, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert(List, self, idx, item, self.alloc);
        }

        pub inline fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
            return Impl.insert_assume_capacity(List, self, idx, item);
        }

        pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx) if (RETURN_ERRORS) Error!DisjointSlice else DisjointSlice {
            return Impl.insert_many_slots(List, self, idx, count, self.alloc);
        }

        pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) DisjointSlice {
            return Impl.insert_many_slots_assume_capacity(List, self, idx, count);
        }

        pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert_slice(List, self, idx, items, self.alloc);
        }

        pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
            return Impl.insert_slice_assume_capacity(List, self, idx, items);
        }

        pub inline fn insert_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return Impl.insert_n_times(List, self, value, count, self.alloc);
        }

        pub inline fn insert_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return Impl.insert_n_times_assume_capacity(List, self, value, count);
        }

        pub inline fn pop_last(self: *List) Elem {
            return Impl.pop_last(List, self);
        }

        pub inline fn pop_first(self: *List) Elem {
            return Impl.pop_first(List, self);
        }

        pub inline fn pop_last_n_array(self: *List, comptime count: Idx) [count]Elem {
            return Impl.pop_last_n_array(List, self, count);
        }

        pub inline fn pop_first_n_array(self: *List, comptime count: Idx) [count]Elem {
            return Impl.pop_first_n_array(List, self, count);
        }

        pub inline fn pop_last_n_to_buf(self: *List, count: Idx, dst_buf: []Elem) void {
            return Impl.pop_last_n_to_buf(List, self, count, dst_buf);
        }

        pub inline fn pop_first_n_to_buf(self: *List, comptime count: Idx, dst_buf: []Elem) void {
            return Impl.pop_first_n_to_buf(List, self, count, dst_buf);
        }

        pub inline fn trim_end(self: *List, count: Idx) Elem {
            return Impl.trim_end(List, self, count);
        }

        pub inline fn trim_start(self: *List, count: Idx) Elem {
            return Impl.trim_start(List, self, count);
        }
    };
}

pub fn DisjointSlicePairWithCap(comptime Idx: type, comptime Elem: type) type {
    return extern struct {
        first: SoftSlice(Elem, Idx),
        second: SoftSlice(Elem, Idx),
        first_extra_cap: Idx,
        second_extra_cap: Idx,

        const Self = @This();

        pub inline fn new_first_only_zero_cap(first: SoftSlice(Elem, Idx)) Self {
            return Self{
                .first = first,
                .first_extra_cap = 0,
                .second = SoftSlice(Elem, Idx).EMPTY,
                .second_extra_cap = 0,
            };
        }
        pub inline fn new_first_only(first: SoftSlice(Elem, Idx), first_extra_cap: Idx) Self {
            return Self{
                .first = first,
                .first_extra_cap = first_extra_cap,
                .second = SoftSlice(Elem, Idx).EMPTY,
                .second_extra_cap = 0,
            };
        }
        pub inline fn new_first_zero_cap(first: SoftSlice(Elem, Idx), second: SoftSlice(Elem, Idx), second_extra_cap: Idx) Self {
            return Self{
                .first = first,
                .first_extra_cap = 0,
                .second = second,
                .second_extra_cap = second_extra_cap,
            };
        }
        pub inline fn new_both_zero_cap(first: SoftSlice(Elem, Idx), second: SoftSlice(Elem, Idx)) Self {
            return Self{
                .first = first,
                .first_extra_cap = 0,
                .second = second,
                .second_extra_cap = 0,
            };
        }

        pub inline fn no_cap(self: Self) DisjointSlicePair(Idx, Elem) {
            return DisjointSlicePair(Idx, Elem){
                .first = self.first,
                .second = self.second,
            };
        }
        pub inline fn no_cap_assert(self: Self) DisjointSlicePair(Idx, Elem) {
            assert(self.first_extra_cap == 0 and self.second_extra_cap == 0);
            return DisjointSlicePair(Idx, Elem){
                .first = self.first,
                .second = self.second,
            };
        }
    };
}

pub fn DisjointSlicePair(comptime Idx: type, comptime Elem: type) type {
    return extern struct {
        first: SoftSlice(Elem, Idx),
        second: SoftSlice(Elem, Idx),

        const Self = @This();

        pub inline fn new_first_only(first: SoftSlice(Elem, Idx)) Self {
            return Self{
                .first = first,
                .second = SoftSlice(Elem, Idx).EMPTY,
            };
        }
        pub inline fn new_both(first: SoftSlice(Elem, Idx), second: SoftSlice(Elem, Idx)) Self {
            return Self{
                .first = first,
                .second = second,
            };
        }
    };
}
