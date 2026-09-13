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

const build = @import("builtin");
const std = @import("std");
const builtin = std.builtin;
const mem = std.mem;
const math = std.math;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ArrayList = std.ArrayListUnmanaged;
const Type = std.builtin.Type;
const SourceLocation = builtin.SourceLocation;

const Root = @import("./_root.zig");
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
const List = Root.List;
const ListOptions = List.ListOptions;

const LIB_DEBUG = true;

pub const ChainListOptions = struct {
    element_type: type,
    alignment: ?u29 = null,
    alloc_error_behavior: ErrorBehavior = .ERRORS_PANIC,
    growth_model: GrowthModel = .GROW_BY_50_PERCENT_ATOMIC_PADDING,
    index_type: type = usize,
    secure_wipe_bytes: bool = false,
    memset_uninit_val: ?*const anyopaque = null,
    /// If set to `true`, an additional field exists on the `List` that caches the `Allocator`
    /// that should be used in all methods that may perform allocation operations.
    /// The `init` and `init_with_capacity` methods will use the provided allocator and cache it in this field,
    /// and all operations that take an `Allocator` will assert that its pointers match the one initially provided
    /// in `Debug` and `ReleaseSafe` modes.
    ///
    /// If set to `false`, *OR* when in `ReleaseFast` or `ReleaseSmall` modes, no additional field is cached, no double check is performed, and the allocator
    /// passed to `init` is discarded and ignored (`init_with_capacity` uses the provided allocator but does not cache it).
    assert_correct_allocator: bool = true,
    /// How many elements are contained in each ring buffer array. For math reasons this
    /// must be a power of 2.
    ///
    /// This directly affects the performace characteristics of the
    /// `ChainList`. This worst-case scenario is inserting a new element at index 1 (2nd position),
    /// which results in the approximate time complexity:
    ///
    /// RING_CAP + ((TOTAL_ITEMS - RING_CAP) / RING_CAP)
    ///
    /// So for a list that had 10,000 items and a ring_capacity of 256,
    /// the approximate number of item copies to shift all items up is:
    ///
    /// 256 + ((10000 - 256) / 256) = approx 294
    ring_capacity: comptime_int = 256,
};

pub fn define_chain_list(comptime options: ChainListOptions) type {
    assert_with_reason(math.isPowerOfTwo(options.ring_capacity), @src(), "`ring_capacity` must be a power of 2", .{});
    return struct {
        const Self = @This();

        list: RingList = RingList.UNINIT,
        len: Idx = 0,
        cap: Idx = 0,
        last_ring_idx: Idx = 0,
        last_ring_len: Idx = 0,

        const RING_CAP = options.ring_capacity;
        const RING_CAP_MINUS_1 = RING_CAP - 1;
        const RING_CAP_MINUS_2 = RING_CAP - 2;
        const RING_IDX_MASK: Idx = RING_CAP - 1;
        const MEMSET = options.memset_uninit_val != null;
        const MEMSET_VAL: if (MEMSET) Elem else void = if (MEMSET) @as(*const Elem, @ptrCast(@alignCast(options.memset_uninit_val.?))).* else void{};
        const IDX_SHIFT = @ctz(RING_CAP);
        const RETURN_ERRORS = options.alloc_error_behavior == .RETURN_ERRORS;

        pub const RingList = List.define_manual_allocator_list_type(ListOptions{
            .alignment = options.alignment,
            .alloc_error_behavior = options.alloc_error_behavior,
            .assert_correct_allocator = options.assert_correct_allocator,
            .element_type = Ring,
            .growth_model = options.growth_model,
            .index_type = options.index_type,
            .memset_uninit_val = null,
            .secure_wipe_bytes = options.secure_wipe_bytes,
        });
        pub const Error = RingList.Error;
        pub const Elem = options.element_type;
        pub const Idx = options.index_type;
        pub const RingIdx = struct {
            idx: math.IntFittingRange(0, RING_IDX_MASK) = 0,

            inline fn increase_by_1(self: RingIdx) RingIdx {
                return RingIdx{ .idx = @intCast((@as(Idx, @intCast(self.idx)) + 1) & RING_IDX_MASK) };
            }
            inline fn decrease_by_1(self: RingIdx) RingIdx {
                return RingIdx{ .idx = @intCast((@as(Idx, @intCast(self.idx)) + RING_CAP_MINUS_1) & RING_IDX_MASK) };
            }
            inline fn decrease_by_N(self: RingIdx, n: Idx) RingIdx {
                return RingIdx{ .idx = @intCast((@as(Idx, @intCast(self.idx)) + RING_CAP - n) & RING_IDX_MASK) };
            }
            inline fn increase_by_N(self: RingIdx, n: Idx) RingIdx {
                return RingIdx{ .idx = @intCast((@as(Idx, @intCast(self.idx)) + n) & RING_IDX_MASK) };
            }
        };
        pub const Ring = struct {
            items: [RING_CAP]Elem = if (MEMSET) @splat(MEMSET_VAL) else undefined,
            start_idx: RingIdx = RingIdx{ .idx = 0 },

            inline fn last_idx(self: *Ring) RingIdx {
                return self.start_idx.decrease_by_1();
            }
            inline fn last_idx_not_full(self: *Ring, len: Idx) RingIdx {
                return self.start_idx.increase_by_N(len - 1);
            }
            inline fn first_empty_idx_not_full(self: *Ring, len: Idx) RingIdx {
                return self.start_idx.increase_by_N(len);
            }
            inline fn exchange(self: *Ring, idx: RingIdx, val: Elem) Elem {
                const ret = self.items[idx];
                self.items[idx] = val;
                return ret;
            }

            inline fn exchange_first(self: *Ring, val: Elem) Elem {
                const ret = self.items[self.start_idx];
                self.items[self.start_idx] = val;
                return ret;
            }

            inline fn exchange_last_full(self: *Ring, val: Elem) Elem {
                const idx = self.last_idx();
                const ret = self.items[idx];
                self.items[idx] = val;
                return ret;
            }

            inline fn decrease_start_by_1(self: *Ring) void {
                self.start_idx = self.last_idx();
            }

            inline fn increase_start_by_1(self: *Ring) void {
                self.start_idx = @intCast((@as(Idx, @intCast(self.start_idx)) + 1) & RING_IDX_MASK);
            }

            inline fn decrease_start_by_N(self: *Ring, n: Idx) void {
                self.start_idx = @intCast((@as(Idx, @intCast(self.start_idx)) + RING_CAP - n) & RING_IDX_MASK);
            }

            inline fn increase_start_by_N(self: *Ring, n: Idx) void {
                self.start_idx = @intCast((@as(Idx, @intCast(self.start_idx)) + n) & RING_IDX_MASK);
            }
        };

        const Index = struct {
            ring: Idx,
            within_ring_rel: RingIdx,
            within_ring_abs: RingIdx,
        };
        fn single_len_to_ring_len(single_len: Idx) Idx {
            return (single_len >> IDX_SHIFT) + @as(Idx, @intCast(@intFromBool(single_len & RING_IDX_MASK > 0)));
        }
        fn ring_len_to_single_len(ring_len: Idx) Idx {
            return ring_len << IDX_SHIFT;
        }
        fn real_index(self: *const Self, virtual_index: Idx) Index {
            const ring_idx: Idx = virtual_index >> IDX_SHIFT;
            const within_relative: Idx = virtual_index & RING_IDX_MASK;
            const ring_start_idx: RingIdx = @intCast(self.list.slice()[ring_idx].start_idx);
            return Index{
                .ring = ring_idx,
                .within_ring_rel = @intCast(within_relative),
                .within_ring_abs = ring_start_idx.increase_by_N(within_relative),
            };
        }

        pub fn new_empty(assert_alloc: Allocator) Self {
            var self = Self{};
            self.list = RingList.new_empty(assert_alloc);
            return self;
        }

        pub fn new_with_capacity(capacity: Idx, alloc: Allocator) Self {
            const ring_cap = single_len_to_ring_len(capacity);
            var self = Self{ .list = RingList.new_with_capacity(ring_cap, alloc) };
            self.cap = ring_len_to_single_len(self.list.cap);
            return self;
        }

        pub inline fn get_item_ptr(self: *Self, index: Idx) *Elem {
            const real_idx = self.real_index(index);
            return &self.list.ptr[real_idx.ring].items[real_idx.within_ring];
        }
        pub inline fn get_item_copy(self: *Self, index: Idx) Elem {
            const real_idx = self.real_index(index);
            return self.list.ptr[real_idx.ring].items[real_idx.within_ring];
        }

        pub inline fn insert_slot(self: *Self, index: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!*Elem else *Elem {
            self.ensure_total_capacity(self.len + 1, alloc);
            return self.insert_slot_assume_capacity(index);
        }

        pub fn insert_slot_assume_capacity(self: *Self, index: Idx) *Elem {
            const real_idx = self.real_index(index);
            if (self.last_ring_len == RING_CAP) {
                self.last_ring_idx += 1;
                self.last_ring_len = 0;
            }
            self.len += 1;
            Assert.assert_idx_less_than_len(index, self.len, @src());
            if (real_idx.ring == self.last_ring_idx) {
                if (real_idx.within_ring_rel == 0) {
                    return self.insert_slot_at_start_of_last_ring();
                } else if (real_idx.within_ring_rel == self.last_ring_len) {
                    return self.append_slot_to_end_of_last_ring();
                } else {
                    return self.insert_slot_in_last_ring(real_idx);
                }
            } else {
                var slot_pop = switch (real_idx.within_ring_rel.idx) {
                    0 => self.insert_slot_start_and_pop_end(real_idx.ring),
                    1...RING_CAP_MINUS_2 => self.insert_slot_and_pop_end(real_idx),
                    RING_CAP_MINUS_1 => self.insert_slot_replace_end(real_idx.ring),
                    else => unreachable,
                };
                var next_ring_idx = real_idx.ring + 1;
                while (next_ring_idx <= self.last_ring_idx) : (next_ring_idx += 1) {
                    slot_pop.popped = self.insert_start_pop_end(next_ring_idx, slot_pop.popped);
                }
                return slot_pop.slot;
            }
        }

        pub fn append_slot_assume_capacity(self: *Self) *Elem {
            if (self.last_ring_len == RING_CAP) {
                self.last_ring_idx += 1;
                self.last_ring_len = 0;
            }
            self.len += 1;
            return self.append_slot_to_end_of_last_ring();
        }

        pub fn prepend_slot_assume_capacity(self: *Self) *Elem {
            if (self.last_ring_len == RING_CAP) {
                self.last_ring_idx += 1;
                self.last_ring_len = 0;
            }
            self.len += 1;
            var slot_pop = self.insert_slot_start_and_pop_end(0);
            var next_ring_idx = 1;
            while (next_ring_idx <= self.last_ring_idx) : (next_ring_idx += 1) {
                slot_pop.popped = self.insert_start_pop_end(next_ring_idx, slot_pop.popped);
            }
            return slot_pop.slot;
        }

        pub fn ensure_total_capacity(self: *Self, capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            if (self.cap >= capacity) return;
            const cap_delta = capacity - self.cap;
            const ring_delta = single_len_to_ring_len(cap_delta);
            const single_delta = ring_len_to_single_len(ring_delta);
            if (RETURN_ERRORS) try self.list.append_n_times(Ring{}, ring_delta, alloc) else self.list.append_n_times(Ring{}, ring_delta, alloc);
            self.cap += single_delta;
        }

        fn insert_slot_start_of_last_ring(self: *Self, last_ring_idx: Idx) *Elem {
            assert_with_reason(self.last_ring_len < RING_CAP, @src(), "this func can only be used when last ring is not full", .{});
            const new_start_idx = (self.list.ptr[last_ring_idx].start_idx + RING_CAP - 1) & RING_IDX_MASK;
            self.list.ptr[last_ring_idx].start_idx = new_start_idx;
            self.last_ring_len += 1;
            return &self.list.ptr[last_ring_idx].items[new_start_idx];
        }

        fn insert_slot_end_of_last_ring(self: *Self, last_ring_idx: Idx) *Elem {
            assert_with_reason(self.last_ring_len < RING_CAP, @src(), "this func can only be used when last ring is not full", .{});
            const new_start_idx = (self.list.ptr[last_ring_idx].start_idx + RING_CAP - 1) & RING_IDX_MASK;
            self.list.ptr[last_ring_idx].start_idx = new_start_idx;
            self.last_ring_len += 1;
            return &self.list.ptr[last_ring_idx].items[new_start_idx];
        }

        fn insert_start_pop_end(self: *Self, ring_idx: Idx, val: Elem) Elem {
            if (LIB_DEBUG) assert_with_reason(ring_idx < self.list.len and ((ring_idx != self.list.len - 1) or (self.last_ring_len == RING_CAP)), @src(), "can only insert_start_pop_end when a ring is full, ring {d} has len {d}, (cap is {d})", .{ ring_idx, self.last_ring_len, RING_CAP });
            const ring: *Ring = &self.list.ptr[ring_idx];
            ring.decrease_start_by_1();
            return ring.exchange_first(val);
        }

        fn insert_slot_at_start_of_last_ring(self: *Self) *Elem {
            if (LIB_DEBUG) assert_with_reason(self.last_ring_len < RING_CAP, @src(), "can only insert_slot_at_start_of_last_ring when a last ring is not full", .{});
            const ring: *Ring = &self.list.ptr[self.last_ring_idx];
            ring.decrease_start_by_1();
            self.last_ring_len += 1;
            return &ring.items[ring.start_idx];
        }

        fn pop_start_fill_end(self: *Self, ring_idx: Idx, val: Elem) Elem {
            if (LIB_DEBUG) assert_with_reason(ring_idx < self.list.len and ((ring_idx != self.list.len - 1) or (self.last_ring_len == RING_CAP)), @src(), "can only pop_start_fill_end when a ring is full, ring {d} has len {d}, (cap is {d})", .{ ring_idx, self.last_ring_len, RING_CAP });
            const ring: *Ring = &self.list.ptr[ring_idx];
            const ret = ring.exchange_first(val);
            ring.increase_start_by_1();
            return ret;
        }

        const SlotPop = struct {
            slot: *Elem,
            popped: Elem,
        };

        fn insert_slot_and_pop_end(self: *Self, index: Index) SlotPop {
            if (LIB_DEBUG) assert_with_reason(index.ring < self.list.len and ((index.ring != self.list.len - 1) or (self.last_ring_len == RING_CAP)), @src(), "can only insert_slot_and_pop_end when a ring is full, ring {d} has len {d}, (cap is {d})", .{ index.ring, self.last_ring_len, RING_CAP });
            const ring: *Ring = &self.list.ptr[index.ring];
            var idx_to_replace = ring.last_idx();
            var idx_to_move_up = idx_to_replace.decrease_by_1();
            const popped = ring.items[idx_to_replace.idx];
            while (idx_to_replace.idx != index.within_ring.idx) {
                ring.items[idx_to_replace.idx] = ring.items[idx_to_move_up.idx];
                idx_to_replace = idx_to_move_up;
                idx_to_move_up = idx_to_move_up.decrease_by_1();
            }
            return SlotPop{
                .slot = &ring.items[idx_to_replace.idx],
                .popped = popped,
            };
        }

        fn insert_slot_in_last_ring(self: *Self, index: Index) *Elem {
            if (LIB_DEBUG) assert_with_reason(self.last_ring_len < RING_CAP, @src(), "can only insert_slot_in_last_ring when last ring is not full", .{});
            const ring: *Ring = &self.list.ptr[self.last_ring_idx];
            var idx_to_replace = ring.last_idx_not_full(self.last_ring_len);
            var idx_to_move_up = idx_to_replace.decrease_by_1();
            while (idx_to_replace.idx != index.within_ring.idx) {
                ring.items[idx_to_replace.idx] = ring.items[idx_to_move_up.idx];
                idx_to_replace = idx_to_move_up;
                idx_to_move_up = idx_to_move_up.decrease_by_1();
            }
            return &ring.items[idx_to_replace.idx];
        }

        fn append_slot_to_end_of_last_ring(self: *Self) *Elem {
            if (LIB_DEBUG) assert_with_reason(self.last_ring_len < RING_CAP, @src(), "can only insert_slot_at_end_of_last_ring when last ring is not full", .{});
            const ring: *Ring = &self.list.ptr[self.last_ring_idx];
            const idx = ring.first_empty_idx_not_full(self.last_ring_len);
            const ptr = &ring.items[idx];
            self.last_ring_len += 1;
            return ptr;
        }

        fn insert_slot_start_and_pop_end(self: *Self, ring_idx: Idx) SlotPop {
            if (LIB_DEBUG) Assert.assert_idx_less_than_len(ring_idx, self.list.len, @src());
            const ring: *Ring = &self.list.ptr[ring_idx];
            ring.decrease_start_by_1();
            return SlotPop{
                .popped = ring.items[ring.start_idx],
                .slot = &ring.items[ring.start_idx],
            };
        }

        fn insert_slot_replace_end(self: *Self, ring_idx: Idx) SlotPop {
            if (LIB_DEBUG) Assert.assert_idx_less_than_len(ring_idx, self.list.len, @src());
            const ring: *Ring = &self.list.ptr[ring_idx];
            ring.las();
            return SlotPop{
                .popped = ring.items[ring.start_idx],
                .slot = &ring.items[ring.start_idx],
            };
        }
    };
}
