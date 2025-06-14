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

const build = @import("builtin");
const std = @import("std");
const builtin = std.builtin;
const mem = std.mem;
const math = std.math;
const crypto = std.crypto;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ArrayList = std.ArrayListUnmanaged;
const Type = std.builtin.Type;

const Root = @import("./_root.zig");
const AllocInfal = Root.AllocatorInfallible;
const Utils = Root.Utils;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const FlexSlice = Root.FlexSlice.FlexSlice;
const Mutability = Root.CommonTypes.Mutability;
const Quicksort = Root.Quicksort;
const Pivot = Quicksort.Pivot;
const InsertionSort = Root.InsertionSort;
const insertion_sort = InsertionSort.insertion_sort;
const ErrorBehavior = Root.CommonTypes.ErrorBehavior;
const GrowthModel = Root.CommonTypes.GrowthModel;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const DummyAllocator = Root.DummyAllocator;
const BinarySearch = Root.BinarySearch;
const SourceLocation = builtin.SourceLocation;

pub const ListOptions = struct {
    element_type: type,
    alignment: ?u29 = null,
    growth_model: GrowthModel = .GROW_BY_50_PERCENT_ATOMIC_PADDING,
    index_type: type = usize,
    secure_wipe_bytes: bool = false,
    memset_uninit_val: ?*const anyopaque = null,
    /// If set to `true`, an additional field exists on the `List` that caches the `Allocator`
    /// that should be used in all methods that may perform allocation operations.
    /// The `init` and `init_with_capacity` methods will use the provided allocator and cache it in this field,
    /// and all operations that take an `Allocator` will assert that it's pointers match the one initially provided
    /// in `Debug` and `ReleaseSafe` modes.
    ///
    /// If set to `false`, *OR* when in `ReleaseFast` or `ReleaseSmall` modes, no additional field is cached, no double check is performed, and the allocator
    /// passed to `init` is discarded and ignored (`init_with_capacity` uses the provided allocator but does not cache it).
    assert_correct_allocator: bool = true,

    pub fn from_options_without_elem(comptime opts: ListOptionsWithoutElem, comptime elem: type, comptime memset_uninit_val: ?*const anyopaque) ListOptions {
        return ListOptions{
            .element_type = elem,
            .alignment = opts.alignment,
            .growth_model = opts.growth_model,
            .index_type = opts.index_type,
            .secure_wipe_bytes = opts.secure_wipe_bytes,
            .memset_uninit_val = memset_uninit_val,
            .assert_correct_allocator = opts.assert_correct_allocator,
        };
    }
};
pub const ListOptionsWithoutElem = struct {
    alignment: ?u29 = null,
    growth_model: GrowthModel = .GROW_BY_50_PERCENT_ATOMIC_PADDING,
    index_type: type = usize,
    secure_wipe_bytes: bool = false,
    /// If set to `true`, an additional field exists on the `List` that caches the `Allocator`
    /// that should be used in all methods that may perform allocation operations.
    /// The `init` and `init_with_capacity` methods will use the provided allocator and cache it in this field,
    /// and all operations that take an `Allocator` will assert that it's pointers match the one initially provided
    /// in `Debug` and `ReleaseSafe` modes.
    ///
    /// If set to `false`, *OR* when in `ReleaseFast` or `ReleaseSmall` modes, no additional field is cached, no double check is performed, and the allocator
    /// passed to `init` is discarded and ignored (`init_with_capacity` uses the provided allocator but does not cache it).
    assert_correct_allocator: bool = true,
};

pub const ERR_START_PLUS_COUNT_OOB = "start ({d}) + count ({d}) == {d}, which is out of bounds for list.len ({d})";
pub const ERR_LEN_EQUALS_CAP_SENT = "list.len ({d}) >= list.cap ({d}): unable to make sentinel slice without an additional slot for sentinel value";
pub const ERR_LEN_EQUALS_CAP = "list.len ({d}) >= list.cap ({d}): cannot add additional item";
pub const ERR_LEN_PLUS_COUNT_GREATER_CAP = "list.len ({d}) + new_item_count ({d}) == {d} > list.cap ({d}): cannot add additional items";
pub const ERR_NEW_LEN_GREATER_CAP = "new len ({d}) > list.cap ({d}): unable to set new len";
pub const ERR_NEW_LEN_GREATER_LEN = "new len ({d}) > list.len ({d}): shrink operation must have smaller or equal new len";
pub const ERR_IDX_GREATER_LEN = "idx ({d}) > list.len ({d}): unable to insert item or slot at index";
pub const ERR_IDX_GREATER_EQL_LEN = "idx ({d}) >= list.len ({d}): unable to operate on index out of bounds";
pub const ERR_LAST_IDX_GREATER_LEN = "end of index range ({d}) > list.len ({d}): unable to operate on index out of bounds";
pub const ERR_LIST_EMPTY = "list.len == 0: unable to return any items from list";

fn assert_correct_allocator(alloc_a: AllocInfal, alloc_b: AllocInfal, comptime src_loc: ?SourceLocation) void {
    assert_with_reason(Utils.shallow_equal(alloc_a, alloc_b), src_loc, "provided allocator does not match the one provided to `init` or `init_with_capacity`", .{});
}

pub fn List(comptime options: ListOptions) type {
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
        assert_with_reason(math.isPowerOfTwo(a), @src(), "alignment must be a power of 2", .{});
    }
    assert_with_reason(@typeInfo(opt.index_type) == Type.int and @typeInfo(opt.index_type).int.signedness == .unsigned, @src(), "index_type must be an unsigned integer type", .{});
    return extern struct {
        ptr: Ptr = UNINIT_PTR,
        len: Idx = 0,
        cap: Idx = 0,
        assert_alloc: if (ASSERT_ALLOC) AllocInfal else void = if (ASSERT_ALLOC) DummyAllocator.allocator else void{},

        const ALIGN = options.alignment;
        const ASSERT_ALLOC = options.assert_correct_allocator;
        const ALLOC_ERROR_BEHAVIOR = options.alloc_error_behavior;
        const GROWTH = options.growth_model;
        const SECURE_WIPE = options.secure_wipe_bytes;
        const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
        const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
        pub const UNINIT = Self{};
        const MEMSET = options.memset_uninit_val != null;
        const UNINIT_VAL: if (MEMSET) Elem else void = if (MEMSET) @as(*const Elem, @ptrCast(@alignCast(options.memset_uninit_val.?))).* else void{};

        const Self = @This();
        pub const Elem = options.element_type;
        pub const Idx = options.index_type;
        pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
        pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
        pub fn SentinelSlice(comptime sentinel: Elem) type {
            return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
        }
        pub const Iterator = ListIterator(Self);

        pub inline fn new_iterator(self: *Self) Iterator {
            return Iterator{
                .list_ref = self,
                .next_idx = 0,
            };
        }

        pub inline fn slice(self: Self) Slice {
            return self.ptr[0..@intCast(self.len)];
        }

        pub inline fn flex_slice(self: Self, comptime mutability: Mutability) FlexSlice(Elem, Idx, mutability) {
            return FlexSlice(Elem, Idx, mutability){
                .ptr = self.ptr,
                .len = self.len,
            };
        }

        pub fn array_ptr(self: Self, start: Idx, comptime length: Idx) *[length]Elem {
            assert_with_reason(start + length <= self.len, @src(), ERR_START_PLUS_COUNT_OOB, .{ start, length, start + length, self.len });
            return &(self.ptr[start..self.len][0..length]);
        }

        pub fn vector_ptr(self: Self, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
            assert_with_reason(start + length <= self.len, @src(), ERR_START_PLUS_COUNT_OOB, .{ start, length, start + length, self.len });
            return self.ptr[start..self.len][0..length];
        }

        pub fn slice_with_sentinel(self: Self, comptime sentinel: Elem) SentinelSlice(Elem) {
            assert_with_reason(self.len < self.cap, @src(), ERR_LEN_EQUALS_CAP_SENT, .{ self.len, self.cap });
            self.ptr[self.len] = sentinel;
            return self.ptr[0..self.len :sentinel];
        }

        pub fn slice_full_capacity(self: Self) Slice {
            return self.ptr[0..self.cap];
        }

        pub fn slice_unused_capacity(self: Self) []Elem {
            return self.ptr[self.len..self.cap];
        }

        pub fn set_len(self: *Self, new_len: Idx) void {
            assert_with_reason(new_len <= self.cap, @src(), ERR_NEW_LEN_GREATER_CAP, .{ new_len, self.cap });
            if (SECURE_WIPE and new_len < self.len) {
                Utils.secure_zero(Elem, self.ptr[new_len..self.len]);
            }
            self.len = new_len;
        }

        pub fn new_empty(assert_alloc: AllocInfal) Self {
            if (ASSERT_ALLOC) {
                var uninit = UNINIT;
                uninit.assert_alloc = assert_alloc;
                return uninit;
            }
            return UNINIT;
        }

        pub fn new_with_capacity(capacity: Idx, alloc: AllocInfal) Self {
            var self = UNINIT;
            if (ASSERT_ALLOC) {
                self.assert_alloc = alloc;
            }
            self.ensure_total_capacity_exact(capacity, alloc);

            return self;
        }

        pub fn clone(self: Self, alloc: AllocInfal) Self {
            var new_list = new_with_capacity(self.cap, alloc);
            new_list.append_slice_assume_capacity(self.ptr[0..self.len]);
            return new_list;
        }

        pub fn to_owned_slice(self: *Self, alloc: AllocInfal) Slice {
            if (ASSERT_ALLOC) assert_correct_allocator(alloc, self.assert_alloc, @src());
            const old_memory = self.ptr[0..self.cap];
            if (alloc.remap(old_memory, self.len)) |new_items| {
                self.* = UNINIT;
                return new_items;
            }
            const new_memory = alloc.alloc_align(Elem, self.len, ALIGN);
            @memcpy(new_memory, self.ptr[0..self.len]);
            self.clear_and_free();
            return new_memory;
        }

        pub fn to_owned_slice_sentinel(self: *Self, comptime sentinel: Elem, alloc: AllocInfal) SentinelSlice(sentinel) {
            self.ensure_total_capacity_exact(self.len + 1, alloc);
            self.ptr[self.len] = sentinel;
            self.len += 1;
            const result: Slice = self.to_owned_slice(alloc);
            return result[0 .. result.len - 1 :sentinel];
        }

        pub fn from_owned_slice(from_slice: Slice) Self {
            return Self{
                .ptr = from_slice.ptr,
                .len = from_slice.len,
                .cap = from_slice.len,
            };
        }

        pub fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) Self {
            return Self{
                .ptr = from_slice.ptr,
                .len = from_slice.len,
                .cap = from_slice.len,
            };
        }

        pub fn insert_slot(self: *Self, idx: Idx, alloc: AllocInfal) *Elem {
            self.ensure_unused_capacity(1, alloc);
            return self.insert_slot_assume_capacity(idx);
        }

        pub fn insert_slot_assume_capacity(self: *Self, idx: Idx) *Elem {
            assert_with_reason(idx <= self.len, @src(), ERR_IDX_GREATER_LEN, .{ idx, self.len });
            mem.copyBackwards(Elem, self.ptr[idx + 1 .. self.len + 1], self.ptr[idx..self.len]);
            self.len += 1;
            return &self.ptr[idx];
        }

        pub fn insert(self: *Self, idx: Idx, item: Elem, alloc: AllocInfal) void {
            const ptr = self.insert_slot(idx, alloc);
            ptr.* = item;
        }

        pub fn insert_assume_capacity(self: *Self, idx: Idx, item: Elem) void {
            const ptr = self.insert_slot_assume_capacity(idx);
            ptr.* = item;
        }

        pub fn insert_many_slots(self: *Self, idx: Idx, count: Idx, alloc: AllocInfal) []Elem {
            self.ensure_unused_capacity(count, alloc);
            return self.insert_many_slots_assume_capacity(idx, count);
        }

        pub fn insert_many_slots_assume_capacity(self: *Self, idx: Idx, count: Idx) []Elem {
            assert_with_reason(idx + count <= self.len, @src(), ERR_START_PLUS_COUNT_OOB, .{ idx, count, idx + count, self.len });
            mem.copyBackwards(Elem, self.ptr[idx + count .. self.len + count], self.ptr[idx..self.len]);
            self.len += count;
            return self.ptr[idx .. idx + count];
        }

        pub fn insert_slice(self: *Self, idx: Idx, items: []const Elem, alloc: AllocInfal) void {
            const slots = self.insert_many_slots(idx, @intCast(items.len), alloc);
            @memcpy(slots, items);
        }

        pub fn insert_slice_assume_capacity(self: *Self, idx: Idx, items: []const Elem) void {
            const slots = self.insert_many_slots_assume_capacity(idx, @intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn replace_range(self: *Self, start: Idx, length: Idx, new_items: []const Elem, alloc: AllocInfal) void {
            if (new_items.len > length) {
                const additional_needed: Idx = @as(Idx, @intCast(new_items.len)) - length;
                self.ensure_unused_capacity(additional_needed, alloc);
            }
            self.replace_range_assume_capacity(start, length, new_items);
        }

        pub fn replace_range_assume_capacity(self: *Self, start: Idx, length: Idx, new_items: []const Elem) void {
            const end_of_range = start + length;
            assert_with_reason(end_of_range <= self.len, @src(), ERR_LAST_IDX_GREATER_LEN, .{ end_of_range, self.len });
            const range = self.ptr[start..end_of_range];
            if (range.len == new_items.len)
                @memcpy(range[0..new_items.len], new_items)
            else if (range.len < new_items.len) {
                const within_range = new_items[0..range.len];
                const leftover = new_items[range.len..];
                @memcpy(range[0..within_range.len], within_range);
                const new_slots = self.insert_many_slots_assume_capacity(end_of_range, @intCast(leftover.len));
                @memcpy(new_slots, leftover);
            } else {
                const unused_slots: Idx = @intCast(range.len - new_items.len);
                @memcpy(range[0..new_items.len], new_items);
                std.mem.copyForwards(Elem, self.ptr[end_of_range - unused_slots .. self.len], self.ptr[end_of_range..self.len]);
                if (SECURE_WIPE) {
                    Utils.secure_zero(Elem, self.ptr[self.len - unused_slots .. self.len]);
                }
                self.len -= unused_slots;
            }
        }

        pub fn append(self: *Self, item: Elem, alloc: AllocInfal) void {
            const slot = self.append_slot(alloc);
            slot.* = item;
        }

        pub fn append_assume_capacity(self: *Self, item: Elem) void {
            const slot = self.append_slot_assume_capacity();
            slot.* = item;
        }

        pub fn remove(self: *Self, idx: Idx) Elem {
            const val: Elem = self.ptr[idx];
            self.delete(idx);
            return val;
        }

        pub fn swap_remove(self: *Self, idx: Idx) Elem {
            const val: Elem = self.ptr[idx];
            self.swap_delete(idx);
            return val;
        }

        pub fn delete(self: *Self, idx: Idx) void {
            assert_with_reason(idx < self.len, @src(), ERR_IDX_GREATER_EQL_LEN, .{ idx, self.len });
            std.mem.copyForwards(Elem, self.ptr[idx..self.len], self.ptr[idx + 1 .. self.len]);
            if (SECURE_WIPE) {
                Utils.secure_zero(Elem, self.ptr[self.len - 1 .. self.len]);
            }
            self.len -= 1;
        }

        pub fn delete_range(self: *Self, start: Idx, length: Idx) void {
            const end_of_range = start + length;
            assert_with_reason(end_of_range <= self.len, @src(), ERR_LAST_IDX_GREATER_LEN, .{ end_of_range, self.len });
            std.mem.copyForwards(Elem, self.ptr[start..self.len], self.ptr[end_of_range..self.len]);
            if (SECURE_WIPE) {
                Utils.secure_zero(Elem, self.ptr[self.len - length .. self.len]);
            }
            self.len -= length;
        }

        pub fn swap_delete(self: *Self, idx: Idx) void {
            assert_with_reason(idx < self.len, @src(), ERR_IDX_GREATER_EQL_LEN, .{ idx, self.len });
            self.ptr[idx] = self.ptr[self.list.items.len - 1];
            if (SECURE_WIPE) {
                Utils.secure_zero(Elem, self.ptr[self.len - 1 .. self.len]);
            }
            self.len -= 1;
        }

        pub fn append_slice(self: *Self, items: []const Elem, alloc: AllocInfal) void {
            const slots = self.append_many_slots(@intCast(items.len), alloc);
            @memcpy(slots, items);
        }

        pub fn append_slice_assume_capacity(self: *Self, items: []const Elem) void {
            const slots = self.append_many_slots_assume_capacity(@intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn append_slice_unaligned(self: *Self, items: []align(1) const Elem, alloc: AllocInfal) void {
            const slots = self.append_many_slots(@intCast(items.len), alloc);
            @memcpy(slots, items);
        }

        pub fn append_slice_unaligned_assume_capacity(self: *Self, items: []align(1) const Elem) void {
            const slots = self.append_many_slots_assume_capacity(@intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn append_n_times(self: *Self, value: Elem, count: Idx, alloc: AllocInfal) void {
            const slots = self.append_many_slots(count, alloc);
            @memset(slots, value);
        }

        pub fn append_n_times_assume_capacity(self: *Self, value: Elem, count: Idx) void {
            const slots = self.append_many_slots_assume_capacity(count);
            @memset(slots, value);
        }

        pub fn resize(self: *Self, new_len: Idx, alloc: AllocInfal) void {
            self.ensure_total_capacity(new_len, alloc);
            if (SECURE_WIPE and new_len < self.len) {
                Utils.secure_zero(Elem, self.ptr[new_len..self.len]);
            }
            self.len = new_len;
        }

        pub fn shrink_and_free(self: *Self, new_len: Idx, alloc: AllocInfal) void {
            if (ASSERT_ALLOC) assert_correct_allocator(alloc, self.assert_alloc, @src());
            assert_with_reason(new_len <= self.len, @src(), ERR_NEW_LEN_GREATER_LEN, .{ new_len, self.len });
            if (@sizeOf(Elem) == 0) {
                self.len = new_len;
                return;
            }

            if (SECURE_WIPE) {
                Utils.secure_zero(Elem, self.ptr[new_len..self.len]);
            }

            const old_memory = self.ptr[0..self.cap];
            if (alloc.remap(old_memory, new_len)) |new_items| {
                self.ptr = new_items.ptr;
                self.len = new_items.len;
                self.cap = new_items.len;
                return;
            }

            const new_memory = alloc.alloc_align(Elem, new_len, ALIGN);

            @memcpy(new_memory, self.ptr[0..new_len]);
            alloc.free(old_memory);
            self.ptr = new_memory.ptr;
            self.len = new_memory.len;
            self.cap = new_memory.len;
        }

        pub fn shrink_retaining_capacity(self: *Self, new_len: Idx) void {
            assert_with_reason(new_len <= self.len, @src(), ERR_NEW_LEN_GREATER_LEN, .{ new_len, self.len });
            if (SECURE_WIPE) {
                Utils.secure_zero(Elem, self.ptr[new_len..self.len]);
            }
            self.len = new_len;
        }

        pub fn clear_retaining_capacity(self: *Self) void {
            if (SECURE_WIPE) {
                std.Utils.secure_zero(Elem, self.ptr[0..self.len]);
            }
            self.len = 0;
        }

        pub fn clear_and_free(self: *Self, alloc: AllocInfal) void {
            if (ASSERT_ALLOC) assert_correct_allocator(alloc, self.assert_alloc, @src());
            if (SECURE_WIPE) {
                std.Utils.secure_zero(Elem, self.ptr[0..self.len]);
            }
            alloc.free(self.ptr[0..self.cap]);
            self.* = UNINIT;
        }

        pub fn ensure_total_capacity(self: *Self, new_capacity: Idx, alloc: AllocInfal) void {
            if (self.cap >= new_capacity) return;
            return self.ensure_total_capacity_exact(true_capacity_for_grow(self.cap, new_capacity), alloc);
        }

        pub fn ensure_total_capacity_exact(self: *Self, new_capacity: Idx, alloc: AllocInfal) void {
            if (ASSERT_ALLOC) assert_correct_allocator(alloc, self.assert_alloc, @src());
            if (@sizeOf(Elem) == 0) {
                self.cap = math.maxInt(Idx);
                return;
            }

            if (self.cap >= new_capacity) return;

            if (new_capacity < self.len) {
                if (SECURE_WIPE) Utils.secure_zero(Elem, self.ptr[new_capacity..self.len]);
                self.len = new_capacity;
            }

            const old_memory = self.ptr[0..self.cap];
            if (alloc.remap(old_memory, new_capacity)) |new_memory| {
                if (MEMSET) {
                    @memset(new_memory[self.cap..new_memory.len], UNINIT_VAL);
                }
                self.ptr = new_memory.ptr;
                self.cap = @intCast(new_memory.len);
            } else {
                const new_memory = alloc.alloc_align(Elem, new_capacity, ALIGN);
                @memcpy(new_memory[0..self.len], self.ptr[0..self.len]);
                if (MEMSET) {
                    @memset(new_memory[self.len..new_memory.len], UNINIT_VAL);
                }
                if (SECURE_WIPE) Utils.secure_zero(Elem, self.ptr[0..self.len]);
                alloc.free(old_memory);
                self.ptr = new_memory.ptr;
                self.cap = @as(Idx, @intCast(new_memory.len));
            }
        }

        pub fn ensure_unused_capacity(self: *Self, additional_count: Idx, alloc: AllocInfal) void {
            const new_total_cap = self.len + additional_count;
            return self.ensure_total_capacity(new_total_cap, alloc);
        }

        pub fn expand_to_capacity(self: *Self) void {
            self.len = self.cap;
        }

        pub fn append_slot(self: *Self, alloc: AllocInfal) *Elem {
            const new_len = self.len + 1;
            self.ensure_total_capacity(new_len, alloc);
            return self.append_slot_assume_capacity();
        }

        pub fn append_slot_assume_capacity(self: *Self) *Elem {
            assert_with_reason(self.len < self.cap, @src(), ERR_LEN_EQUALS_CAP, .{ self.len, self.cap });
            const idx = self.len;
            self.len += 1;
            return &self.ptr[idx];
        }

        pub fn append_many_slots(self: *Self, count: Idx, alloc: AllocInfal) []Elem {
            const new_len = self.len + count;
            self.ensure_total_capacity(new_len, alloc);
            return self.append_many_slots_assume_capacity(count);
        }

        pub fn append_many_slots_assume_capacity(self: *Self, count: Idx) []Elem {
            const new_len = self.len + count;
            assert_with_reason(new_len <= self.cap, @src(), ERR_LEN_PLUS_COUNT_GREATER_CAP, .{ self.len, count, self.len + count, self.cap });
            const prev_len = self.len;
            self.len = new_len;
            return self.ptr[prev_len..][0..count];
        }

        pub fn append_many_slots_as_array(self: *Self, comptime count: Idx, alloc: AllocInfal) *[count]Elem {
            const new_len = self.len + count;
            self.ensure_total_capacity(new_len, alloc);
            return self.append_many_slots_as_array_assume_capacity(count);
        }

        pub fn append_many_slots_as_array_assume_capacity(self: *Self, comptime count: Idx) *[count]Elem {
            const new_len = self.len + count;
            assert_with_reason(new_len <= self.cap, @src(), ERR_LEN_PLUS_COUNT_GREATER_CAP, .{ self.len, count, self.len + count, self.cap });
            const prev_len = self.len;
            self.len = new_len;
            return self.ptr[prev_len..][0..count];
        }

        pub fn pop(self: *Self) Elem {
            assert_with_reason(self.len > 0, @src(), ERR_LIST_EMPTY, .{});
            const new_len = self.len - 1;
            self.len = new_len;
            return self.ptr[new_len];
        }

        pub inline fn pop_or_null(self: *Self) ?Elem {
            if (self.len == 0) return null;
            return self.pop();
        }

        pub inline fn get_last(self: Self) Elem {
            assert_with_reason(self.len > 0, @src(), ERR_LIST_EMPTY, .{});
            return self.ptr[self.len - 1];
        }

        pub inline fn get_last_or_null(self: Self) ?Elem {
            if (self.len == 0) return null;
            return self.get_last();
        }

        pub inline fn get_last_ptr(self: Self) *Elem {
            assert_with_reason(self.len > 0, @src(), ERR_LIST_EMPTY, .{});
            return &self.ptr[self.len - 1];
        }

        pub inline fn get_last_ptr_or_null(self: Self) ?*Elem {
            if (self.len == 0) return null;
            return self.get_last_ptr();
        }

        pub fn true_capacity_for_grow(current: Idx, minimum: Idx) Idx {
            switch (GROWTH) {
                GrowthModel.GROW_EXACT_NEEDED => {
                    return minimum;
                },
                GrowthModel.GROW_EXACT_NEEDED_ATOMIC_PADDING => {
                    return minimum + ATOMIC_PADDING;
                },
                else => {
                    var new: Idx = current;
                    while (true) {
                        switch (GROWTH) {
                            GrowthModel.GROW_BY_100_PERCENT => {
                                new +|= @max(1, new);
                                if (new >= minimum) return new;
                            },
                            GrowthModel.GROW_BY_100_PERCENT_ATOMIC_PADDING => {
                                new +|= @max(1, new);
                                const new_with_padding = new +| ATOMIC_PADDING;
                                if (new_with_padding >= minimum) return new_with_padding;
                            },
                            GrowthModel.GROW_BY_50_PERCENT => {
                                new +|= @max(1, new / 2);
                                if (new >= minimum) return new;
                            },
                            GrowthModel.GROW_BY_50_PERCENT_ATOMIC_PADDING => {
                                new +|= @max(1, new / 2);
                                const new_with_padding = new +| ATOMIC_PADDING;
                                if (new_with_padding >= minimum) return new_with_padding;
                            },
                            GrowthModel.GROW_BY_25_PERCENT => {
                                new +|= @max(1, new / 4);
                                if (new >= minimum) return new;
                            },
                            GrowthModel.GROW_BY_25_PERCENT_ATOMIC_PADDING => {
                                new +|= @max(1, new / 4);
                                const new_with_padding = new +| ATOMIC_PADDING;
                                if (new_with_padding >= minimum) return new_with_padding;
                            },
                            else => unreachable,
                        }
                    }
                },
            }
        }

        pub fn find_idx(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Idx {
            for (self.slice(), 0..) |*item, idx| {
                if (match_fn(param, item)) return @intCast(idx);
            }
            return null;
        }

        pub fn find_ptr(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*Elem {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                return &self.ptr[idx];
            }
            return null;
        }

        pub fn find_const_ptr(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*const Elem {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                return &self.ptr[idx];
            }
            return null;
        }

        pub fn find_and_copy(self: *Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                return self.ptr[idx];
            }
            return null;
        }

        pub fn find_and_remove(self: *Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                return self.remove(idx);
            }
            return null;
        }

        pub fn find_and_delete(self: *Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) bool {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                self.delete(idx);
                return true;
            }
            return false;
        }

        pub inline fn find_exactly_n_item_indexes_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Idx) bool {
            return self.flex_slice(.immutable).find_exactly_n_item_indexes_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_item_pointers_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*Elem) bool {
            return self.flex_slice(.mutable).find_exactly_n_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_const_item_pointers_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*const Elem) bool {
            return self.flex_slice(.immutable).find_exactly_n_const_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_item_copies_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Elem) bool {
            return self.flex_slice(.immutable).find_exactly_n_item_copies_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub fn delete_ordered_indexes(self: *Self, indexes: []const Idx) void {
            assert_with_reason(indexes.len <= self.len, @src(), "more indexes provided ({d}) than exist in list ({d})", .{ indexes.len, self.len });
            assert_with_reason(check: {
                var i: usize = 1;
                while (i < indexes.len) : (i += 1) {
                    if (indexes[i - 1] >= indexes[i]) break :check false;
                }
                break :check true;
            }, @src(), "not all indexes are in increasing order (with no duplicates) as is required by this function", .{});
            assert_with_reason(check: {
                var i: usize = 0;
                while (i < indexes.len) : (i += 1) {
                    if (indexes[i] >= self.len) break :check false;
                }
                break :check true;
            }, @src(), "some indexes provided are out of bounds for list len ({d})", .{self.len});
            var shift_down: usize = 0;
            var i: usize = 0;
            var src_start: Idx = undefined;
            var src_end: Idx = undefined;
            var dst_start: Idx = undefined;
            var dst_end: Idx = undefined;
            while (i < indexes.len) {
                var consecutive: Idx = 1;
                var end_index: Idx = i + consecutive;
                while (end_index < indexes.len) {
                    if (indexes[end_index] != indexes[end_index - 1] + 1) break;
                    consecutive += 1;
                    end_index += 1;
                }
                const start_idx = end_index - 1;
                shift_down += consecutive;
                src_start = indexes[start_idx];
                src_end = if (end_index >= indexes.len) self.len else indexes[end_index];
                dst_start = src_start - shift_down;
                dst_end = src_end - shift_down;
                std.mem.copyForwards(Idx, self.ptr[dst_start..dst_end], self.ptr[src_start..src_end]);
                i += consecutive;
            }
            self.len -= indexes.len;
        }

        //TODO pub fn insert_slots_at_ordered_indexes()

        pub inline fn insertion_sort(self: *Self) void {
            return self.flex_slice(.mutable).insertion_sort();
        }

        pub inline fn insertion_sort_with_transform(self: *Self, comptime TX: type, transform_fn: *const fn (item: Elem) TX) void {
            return self.flex_slice(.mutable).insertion_sort_with_transform(TX, transform_fn);
        }

        pub inline fn insertion_sort_with_transform_and_user_data(self: *Self, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) void {
            return self.flex_slice(.mutable).insertion_sort_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        pub inline fn is_sorted(self: *Self) bool {
            return self.flex_slice(.immutable).is_sorted();
        }

        pub inline fn is_sorted_with_transform(self: *Self, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
            return self.flex_slice(.immutable).is_sorted_with_transform(TX, transform_fn);
        }

        pub inline fn is_sorted_with_transform_and_user_data(self: *Self, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
            return self.flex_slice(.immutable).is_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        pub inline fn is_reverse_sorted(self: *Self) bool {
            return self.flex_slice(.immutable).is_reverse_sorted();
        }

        pub inline fn is_reverse_sorted_with_transform(self: *Self, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
            return self.flex_slice(.immutable).is_reverse_sorted_with_transform(TX, transform_fn);
        }

        pub inline fn is_reverse_sorted_with_transform_and_user_data(self: *Self, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
            return self.flex_slice(.immutable).is_reverse_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        // pub inline fn insert_one_sorted( self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return insert_one_sorted_custom(List, self, item, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN, alloc);
        // }

        // pub fn insert_one_sorted_custom( self: *List, item: Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        //     const insert_idx: Idx = @intCast(BinarySearch.binary_search_insert_index(Elem, &item, self.ptr[0..self.len], greater_than_fn, equal_order_fn));
        //     if (RETURN_ERRORS) try insert(List, self, insert_idx, item, alloc) else insert(List, self, insert_idx, item, alloc);
        //     return insert_idx;
        // }

        // pub inline fn find_equal_order_idx_sorted( self: *List, item_to_compare: *const Elem) ?Idx {
        //     return find_equal_order_idx_sorted_custom(List, self, item_to_compare, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN);
        // }

        // pub fn find_equal_order_idx_sorted_custom( self: *List, item_to_compare: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem)) ?Idx {
        //     const insert_idx = BinarySearch.binary_search_by_order(Elem, item_to_compare, self.ptr[0..self.len], greater_than_fn, equal_order_fn);
        //     if (insert_idx) |idx| return @intCast(idx);
        //     return null;
        // }

        // pub inline fn find_matching_item_idx_sorted( self: *List, item_to_find: *const Elem) ?Idx {
        //     return find_matching_item_idx_sorted_custom(List, self, item_to_find, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_COMPARE_PKG.equals, DEFAULT_MATCH_FN);
        // }

        // pub fn find_matching_item_idx_sorted_custom( self: *List, item_to_find: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), exact_match_fn: *const CompareFn(Elem)) ?Idx {
        //     const insert_idx = BinarySearch.binary_search_exact_match(Elem, item_to_find, self.ptr[0..self.len], greater_than_fn, equal_order_fn, exact_match_fn);
        //     if (insert_idx) |idx| return @intCast(idx);
        //     return null;
        // }

        // pub inline fn find_matching_item_idx( self: *List, item_to_find: *const Elem) ?Idx {
        //     return find_matching_item_idx_custom(List, self, item_to_find, DEFAULT_MATCH_FN);
        // }

        // pub fn find_matching_item_idx_custom( self: *List, item_to_find: *const Elem, exact_match_fn: *const CompareFn(Elem)) ?Idx {
        //     if (self.len == 0) return null;
        //     const buf = self.ptr[0..self.len];
        //     var idx: Idx = 0;
        //     var found_exact = exact_match_fn(item_to_find, &buf[idx]);
        //     const limit = self.len - 1;
        //     while (!found_exact and idx < limit) {
        //         idx += 1;
        //         found_exact = exact_match_fn(item_to_find, &buf[idx]);
        //     }
        //     if (found_exact) return idx;
        //     return null;
        // }

        //**************************
        // std.io.Writer interface *
        //**************************
        const StdWriterHandle = struct {
            list: *Self,
            alloc: AllocInfal,
        };
        const StdWriterHandleNoGrow = struct {
            list: *Self,
        };

        pub const StdWriter = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(StdWriterHandle, AllocInfal.Error, std_write);

        pub fn get_std_writer(self: *Self, alloc: AllocInfal) StdWriter {
            return StdWriter{ .context = .{ .list = self, .alloc = alloc } };
        }

        fn std_write(handle: StdWriterHandle, bytes: []const u8) AllocInfal.Error!usize {
            try handle.list.append_slice(bytes, handle.alloc);
            return bytes.len;
        }

        pub const StdWriterNoGrow = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(StdWriterHandleNoGrow, AllocInfal.Error, std_write_no_grow);

        pub fn get_std_writer_no_grow(self: *Self) StdWriterNoGrow {
            return StdWriterNoGrow{ .context = .{ .list = self } };
        }

        fn std_write_no_grow(handle: StdWriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
            const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
            if (bytes.len > available_capacity) return error.OutOfMemory;
            handle.list.append_slice_assume_capacity(bytes);
            return bytes.len;
        }
    };
}

pub fn ListIterator(comptime ListType: type) type {
    return struct {
        next_idx: ListType.Idx = 0,
        list_ref: *ListType,

        const Self = @This();

        pub inline fn reset_index_to_start(self: *Self) void {
            self.next_idx = 0;
        }

        pub inline fn set_index(self: *Self, index: ListType.Idx) void {
            self.next_idx = index;
        }

        pub inline fn decrease_index_safe(self: *Self, count: ListType.Idx) void {
            self.next_idx -|= count;
        }
        pub inline fn decrease_index(self: *Self, count: ListType.Idx) void {
            self.next_idx -= count;
        }
        pub inline fn increase_index(self: *Self, count: ListType.Idx) void {
            self.next_idx += count;
        }
        pub inline fn increase_index_safe(self: *Self, count: ListType.Idx) void {
            self.next_idx +|= count;
        }

        pub inline fn has_next(self: Self) bool {
            return self.next_idx < self.list_ref.len;
        }

        pub fn get_next_copy(self: *Self) ?ListType.Elem {
            if (self.next_idx >= self.list_ref.len) return null;
            const item = self.list_ref.ptr[self.next_idx];
            self.next_idx += 1;
            return item;
        }

        pub fn get_next_copy_guaranteed(self: *Self) ListType.Elem {
            assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
            const item = self.list_ref.ptr[self.next_idx];
            self.next_idx += 1;
            return item;
        }

        pub fn get_next_ref(self: *Self) ?*ListType.Elem {
            if (self.next_idx >= self.list_ref.len) return null;
            const item: *ListType.Elem = &self.list_ref.ptr[self.next_idx];
            self.next_idx += 1;
            return item;
        }

        pub fn get_next_ref_guaranteed(self: *Self) *ListType.Elem {
            assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
            const item: *ListType.Elem = &self.list_ref.ptr[self.next_idx];
            self.next_idx += 1;
            return item;
        }

        /// Returns `true` if action was performed at least one time, `false` if iterator had zero items left
        pub fn perform_action_on_remaining_items(self: *Self, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
            var idx: ListType.Idx = self.next_idx;
            var exec_count: ListType.Idx = 0;
            var should_continue: bool = true;
            while (should_continue and idx < self.list_ref.len) : (idx += 1) {
                const item: *ListType.Elem = &self.list_ref.ptr[idx];
                should_continue = callback(self.list_ref, idx, item, userdata);
                exec_count += 1;
            }
            return exec_count > 0;
        }

        /// Returns `true` if action was performed on exactly `count` items, `false` if iterator ran out of items early
        pub fn perform_action_on_next_n_items(self: *Self, count: ListType.Idx, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
            var idx: ListType.Idx = self.next_idx;
            const limit = @min(idx + count, self.list_ref.len);
            var exec_count: ListType.Idx = 0;
            var should_continue: bool = true;
            while (should_continue and idx < limit) : (idx += 1) {
                const item: *ListType.Elem = &self.list_ref.ptr[idx];
                should_continue = callback(self.list_ref, idx, item, userdata);
                exec_count += 1;
            }
            return exec_count == count;
        }

        /// Should return `true` if iteration should continue, or `false` if iteration should stop
        pub const IteratorAction = fn (list: *ListType, index: ListType.Idx, item: *ListType.Elem, userdata: ?*anyopaque) bool;
    };
}

test "List.zig" {
    const t = std.testing;
    const alloc = std.heap.page_allocator;
    const opts = ListOptions{
        .alloc_error_behavior = .ERRORS_PANIC,
        .element_type = u8,
        .index_type = u32,
    };
    const ListType = List(opts);
    var list = ListType.new_empty();

    list.append('H', alloc);
    list.append('e', alloc);
    list.append('l', alloc);
    list.append('l', alloc);
    list.append('o', alloc);
    list.append(' ', alloc);
    list.append_slice("World", alloc);
    try t.expectEqualStrings("Hello World", list.slice());
    const letter_l = list.remove(2);
    try t.expectEqual('l', letter_l);
    try t.expectEqualStrings("Helo World", list.slice());
    list.replace_range(3, 3, &.{ 'a', 'b', 'c' }, alloc);
    try t.expectEqualStrings("Helabcorld", list.slice());
}
