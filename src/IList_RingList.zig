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
const Root = @import("./_root.zig");
const Type = std.builtin.Type;
const Types = Root.Types;
const Assert = Root.Assert;
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;

pub fn RingList(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr: [*]T,
        start: u32 = 0,
        len: u32 = 0,
        cap: u32 = 0,

        pub fn init_empty() Self {
            return Self{
                .ptr = @ptrFromInt(std.mem.alignBackward(usize, math.maxInt(usize), @alignOf(T))),
            };
        }
        pub fn init_capacity(cap: usize, alloc: Allocator) Self {
            const new_mem = alloc.alloc(T, cap) catch |err| Assert.assert_allocation_failure(@src(), T, cap, err);
            return Self{
                .ptr = new_mem.ptr,
                .cap = @intCast(new_mem.len),
            };
        }

        pub fn interface(self: *Self, alloc: Allocator) ILIST {
            return ILIST{
                .object = @ptrCast(self),
                .vtable = &VTABLE,
                .alloc = alloc,
            };
        }
        pub fn interface_no_alloc(self: *Self) ILIST {
            return ILIST{
                .object = @ptrCast(self),
                .vtable = &VTABLE,
                .alloc = DummyAlloc.allocator_shrink_only,
            };
        }

        pub fn deinit(self: *Self, alloc: Allocator) void {
            self.len = 0;
            self.start = 0;
            alloc.free(self.ptr[0..self.cap]);
            self.cap = 0;
            return;
        }

        fn real_idx(self: *Self, idx: usize) u32 {
            return (@as(u32, @intCast(idx)) + self.start) % self.cap;
        }
        fn is_split(self: *Self) bool {
            return self.start + self.len > self.cap;
        }
        fn get_logical_split(self: *Self) [2][]T {
            return [2][]T{
                self.ptr[self.start..self.cap],
                self.ptr[0 .. self.end + 1],
            };
        }
        fn get_logical(self: *Self) [2][]T {
            if (self.is_split()) {
                return self.get_logical_split();
            } else {
                return [2][]T{
                    self.ptr[self.start .. self.start + self.len],
                    &.{},
                };
            }
        }
        fn copy_range_up(self: *Self, lo_idx_start: usize, lo_idx_end: usize, hi_idx_end: usize) void {
            if (lo_idx_end == hi_idx_end) return;
            var read = RIdx.init(self, lo_idx_end);
            var write = RIdx.init(self, hi_idx_end);
            const last_read = self.real_idx(lo_idx_start);
            while (true) {
                self.ptr[write.idx] = self.ptr[read.idx];
                if (read.idx == last_read) break;
                read.sub(self, 1);
                write.sub(self, 1);
            }
        }
        fn copy_range_down(self: *Self, hi_idx_start: usize, hi_idx_end: usize, lo_idx_start: usize) void {
            if (lo_idx_start == hi_idx_start) return;
            var read = RIdx.init(self, hi_idx_start);
            var write = RIdx.init(self, lo_idx_start);
            const last_read = self.real_idx(hi_idx_end);
            while (true) {
                self.ptr[write.idx] = self.ptr[read.idx];
                if (read.idx == last_read) break;
                read.add(self, 1);
                write.add(self, 1);
            }
        }
        fn reverse(self: *Self, start_idx: usize, end_idx: usize) void {
            if (start_idx == end_idx) return;
            var tmp: T = undefined;
            var start = RIdx.init(self, start_idx);
            var end = RIdx.init(self, end_idx);
            while (true) {
                tmp = self.ptr[end.idx];
                self.ptr[end.idx] = self.ptr[start.idx];
                self.ptr[start.idx] = tmp;
                start.add(self, 1);
                if (start.idx == end.idx) break;
                end.sub(self, 1);
                if (start.idx == end.idx) break;
            }
        }

        const SplitLens = struct {
            seg_1: u32 = 0,
            seg_2: u32 = 0,
        };

        fn free_space(self: *Self) u32 {
            return self.cap - self.len;
        }
        fn overhang(self: *Self) u32 {
            const first_seg = @min(self.start + self.len, self.cap) - self.start;
            return self.len - first_seg;
        }
        fn split_lens(self: *Self) SplitLens {
            const seg_1_ = @min(self.start + self.len, self.cap) - self.start;
            const seg_2_ = self.len - seg_1_;
            return SplitLens{
                .seg_1 = seg_1_,
                .seg_2 = seg_2_,
            };
        }
        fn seg_1_len(self: *Self) u32 {
            return @min(self.start + self.len, self.cap) - self.start;
        }
        fn seg_1_len_usize(self: *Self) usize {
            return @intCast(self.seg_1_len());
        }
        fn seg_1(self: *Self) []T {
            const len = @min(self.start + self.len, self.cap) - self.start;
            return self.ptr[self.start .. self.start + len];
        }

        fn realign(self: *Self) void {
            if (self.len == 0) {
                self.start = 0;
                return;
            }
            if (self.start >= self.len) {
                if (self.is_split()) {
                    const slens = self.split_lens();
                    if (slens.seg_2 <= slens.seg_1) {
                        @memcpy(self.ptr[slens.seg_1 .. slens.seg_1 + slens.seg_2], self.ptr[0..slens.seg_2]);
                    } else {
                        var move_len = slens.seg_2;
                        Utils.mem_insert(self.ptr, &move_len, 0, slens.seg_1);
                    }
                    @memcpy(self.ptr[0..slens.seg_1], self.ptr[self.start .. self.start + slens.seg_1]);
                } else {
                    @memcpy(self.ptr[0..self.len], self.ptr[self.start .. self.start + self.len]);
                }
            } else {
                if (self.is_split()) {
                    const slens = self.split_lens();
                    var tmp_len = self.cap;
                    const n_remove = self.start - slens.seg_1;
                    Utils.mem_remove(self.ptr, &tmp_len, slens.seg_1, n_remove);
                    Utils.slice_move_many(self.ptr[0..self.len], slens.seg_1, self.len - 1, 0);
                } else {
                    var tmp_len: u32 = self.start + self.len;
                    Utils.mem_remove(self.ptr, &tmp_len, 0, self.start);
                }
            }
            self.start = 0;
        }
        fn realign_if_needed(self: *Self, new_cap: u32) void {
            if (self.start + self.len <= new_cap) return;
            self.realign();
        }

        /// Assumes capacity exists, does not alter list length
        fn special_mem_insert(self: *Self, idx: usize, n: usize) void {
            const nn = Types.intcast(n, u32);
            if (idx == 0) {
                self.start += self.cap;
                self.start -= nn;
                self.start %= self.cap;
                return;
            }
            if (idx == Types.intcast(self.len, usize)) {
                return;
            }
            const items_before = idx;
            const items_after = Types.intcast(self.len, usize) - idx;
            if (items_before < items_after) { // shift items before index down
                self.start += self.cap;
                self.start -= nn;
                self.start %= self.cap;
                self.copy_range_down(n, idx + n, 0);
            } else { // shift items after index up
                const last = Types.intcast(self.len - 1, usize);
                self.copy_range_up(idx, last, last + n);
            }
        }

        /// Does not alter list length
        fn special_mem_delete(self: *Self, range: IList.Range, n: usize) void {
            const nn = Types.intcast(n, u32);
            if (range.first_idx == 0) {
                self.start += nn;
                self.start %= self.cap;
                return;
            }
            if (range.last_idx == Types.intcast(self.len - 1, usize)) {
                return;
            }
            const items_before = range.first_idx;
            const items_after = Types.intcast(self.len, usize) - (range.last_idx + 1);
            if (items_before < items_after) { // shift items before range up
                self.copy_range_up(0, range.first_idx - 1, range.last_idx);
                self.start += nn;
                self.start %= self.cap;
            } else { // shift items after range down
                const last = Types.intcast(self.len - 1, usize);
                self.copy_range_down(range.last_idx + 1, last, range.first_idx);
            }
        }

        fn special_mem_grow(self: *Self, new_cap: usize, alloc: Allocator) error{failed_to_grow_list}!void {
            const was_split = self.is_split();
            if (alloc.remap(self.ptr[0..self.cap], new_cap)) |new_mem| {
                if (was_split) {
                    const seg_1_ = self.seg_1();
                    const space_after = new_mem.len - self.cap;
                    if (space_after >= seg_1_.len) {
                        @memcpy(new_mem[new_mem.len - seg_1_.len ..], seg_1_);
                    } else {
                        var sub_len = self.cap;
                        Utils.mem_insert(self.ptr, &sub_len, @intCast(self.start), space_after);
                    }
                    self.start += Types.intcast(space_after, u32);
                }
                self.ptr = new_mem.ptr;
                self.cap = Types.intcast(new_mem.len, u32);
            } else {
                const new_mem = alloc.alloc(T, new_cap) catch return error{failed_to_grow_list}.failed_to_grow_list;
                const seg_1_ = self.seg_1();
                @memcpy(new_mem[0..seg_1_.len], seg_1_);
                if (was_split) {
                    const ulen: usize = @intCast(self.len);
                    const seg_2_ = self.ptr[0 .. ulen - seg_1_.len];
                    @memcpy(new_mem[seg_1_.len..ulen], seg_2_);
                }
                alloc.free(self.ptr[0..self.cap]);
                self.ptr = new_mem.ptr;
                self.cap = Types.intcast(new_mem.len, u32);
                self.start = 0;
            }
            return;
        }

        fn special_mem_shrink(self: *Self, new_cap: usize, alloc: Allocator) void {
            const delta = Types.intcast(self.cap, usize) - new_cap;
            var was_split = self.is_split();
            const seg_1_len_: u32 = self.seg_1_len();
            if (was_split) {
                var tmp_len = self.cap;
                Utils.mem_remove(self.ptr, &tmp_len, Types.intcast(self.start, usize) - delta, delta);
                self.start -= Types.intcast(delta, u32);
            } else {
                var end = self.start + self.len;
                const space_after = self.cap - end;
                if (space_after < delta) {
                    const space_before = self.start;
                    if (space_before >= self.len) {
                        @memcpy(self.ptr[0..self.len], self.ptr[self.start..end]);
                    } else {
                        Utils.mem_remove(self.ptr, &end, 0, @intCast(self.start));
                    }
                    self.start = 0;
                    was_split = false;
                }
            }
            if (alloc.remap(self.ptr[0..self.cap], new_cap)) |new_mem| {
                self.ptr = new_mem.ptr;
                self.cap = Types.intcast(new_mem.len, u32);
            } else {
                const new_mem = alloc.alloc(T, new_cap) catch return;
                const seg_1_ = self.ptr[self.start .. self.start + seg_1_len_];
                @memcpy(new_mem[0..seg_1_.len], seg_1_);
                if (was_split) {
                    const ulen: usize = @intCast(self.len);
                    const seg_2_ = self.ptr[0 .. ulen - seg_1_.len];
                    @memcpy(new_mem[seg_1_.len..ulen], seg_2_);
                }
                alloc.free(self.ptr[0..self.cap]);
                self.ptr = new_mem.ptr;
                self.cap = Types.intcast(new_mem.len, u32);
                self.start = 0;
            }
        }

        pub const ILIST = IList.IList(T);
        pub const VTABLE = ILIST.VTable{
            .all_indexes_zero_to_len_valid = true,
            .consecutive_indexes_in_order = true,
            .ensure_free_doesnt_change_cap = false,
            .prefer_linear_ops = false,
            .always_invalid_idx = math.maxInt(usize),
            .idx_valid = impl_idx_valid,
            .range_valid = impl_range_valid,
            .split_range = impl_split_range,
            .idx_in_range = impl_idx_in_range,
            .range_len = impl_range_len,
            .get = impl_get,
            .get_ptr = impl_get_ptr,
            .set = impl_set,
            .first_idx = impl_first_idx,
            .last_idx = impl_last_idx,
            .next_idx = impl_next_idx,
            .prev_idx = impl_prev_idx,
            .nth_next_idx = impl_nth_next_idx,
            .nth_prev_idx = impl_nth_prev_idx,
            .len = impl_len,
            .cap = impl_cap,
            .move = impl_move,
            .move_range = impl_move_range,
            .try_ensure_free_slots = impl_ensure_free,
            .append_slots_assume_capacity = impl_append,
            .insert_slots_assume_capacity = impl_insert,
            .delete_range = impl_delete,
            .clear = impl_clear,
            .free = impl_free,
            .shrink_cap_reserve_at_most = impl_shrink_cap,
        };

        const RIdx = struct {
            idx: u32 = 0,

            fn init(list: *Self, idx: usize) RIdx {
                return RIdx{
                    .idx = (@as(u32, @intCast(idx)) + list.start) % list.cap,
                };
            }

            fn add(self: *RIdx, list: *Self, n: usize) void {
                self.idx += @as(u32, @intCast(n));
                self.idx %= list.cap;
            }

            fn sub(self: *RIdx, list: *Self, n: usize) void {
                self.idx += list.cap;
                self.idx -= @as(u32, @intCast(n));
                self.idx %= list.cap;
            }
        };

        fn impl_idx_valid(object: *anyopaque, idx: usize) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            return idx < @as(usize, @intCast(self.len));
        }
        fn impl_idx_in_range(_: *anyopaque, range: IList.Range, idx: usize) bool {
            return range.first_idx <= idx and idx <= range.last_idx;
        }
        fn impl_range_valid(object: *anyopaque, range: IList.Range) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            return range.first_idx <= range.last_idx and range.last_idx < @as(usize, @intCast(self.len));
        }
        fn impl_split_range(_: *anyopaque, range: IList.Range) usize {
            return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
        }
        fn impl_range_len(_: *anyopaque, range: IList.Range) usize {
            return (range.last_idx - range.first_idx) + 1;
        }

        fn impl_get(object: *anyopaque, idx: usize, _: Allocator) T {
            const self: *Self = @ptrCast(@alignCast(object));
            return self.ptr[self.real_idx(idx)];
        }
        fn impl_get_ptr(object: *anyopaque, idx: usize, _: Allocator) *T {
            const self: *Self = @ptrCast(@alignCast(object));
            return &self.ptr[self.real_idx(idx)];
        }
        fn impl_set(object: *anyopaque, idx: usize, val: T, _: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            self.ptr[self.real_idx(idx)] = val;
        }
        fn impl_first_idx(_: *anyopaque) usize {
            return 0;
        }
        fn impl_last_idx(object: *anyopaque) usize {
            const self: *Self = @ptrCast(@alignCast(object));
            return @intCast(self.len -% 1);
        }
        fn impl_next_idx(_: *anyopaque, idx: usize) usize {
            return idx + 1;
        }
        fn impl_prev_idx(_: *anyopaque, idx: usize) usize {
            return idx -% 1;
        }
        fn impl_nth_next_idx(_: *anyopaque, idx: usize, n: usize) usize {
            return idx + n;
        }
        fn impl_nth_prev_idx(_: *anyopaque, idx: usize, n: usize) usize {
            return idx -% n;
        }
        fn impl_len(object: *anyopaque) usize {
            const self: *Self = @ptrCast(@alignCast(object));
            return @intCast(self.len);
        }
        fn impl_cap(object: *anyopaque) usize {
            const self: *Self = @ptrCast(@alignCast(object));
            return @intCast(self.cap);
        }

        fn impl_move(object: *anyopaque, old: usize, new: usize, _: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            if (old == new) return;
            const sidx = self.real_idx(new);
            var widx = RIdx.init(self, old);
            const tmp = self.ptr[widx.idx];
            var ridx: RIdx = widx;
            if (old < new) {
                ridx.add(self, 1);
                while (true) {
                    self.ptr[widx.idx] = self.ptr[ridx.idx];
                    if (ridx.idx == sidx) break;
                    widx = ridx;
                    ridx.add(self, 1);
                }
            } else {
                ridx.sub(self, 1);
                while (true) {
                    self.ptr[widx.idx] = self.ptr[ridx.idx];
                    if (ridx.idx == sidx) break;
                    widx = ridx;
                    ridx.sub(self, 1);
                }
            }
            self.ptr[ridx.idx] = tmp;
        }

        fn impl_move_range(object: *anyopaque, range: IList.Range, new_first: usize, _: Allocator) void {
            if (range.first_idx == new_first) return;
            const self: *Self = @ptrCast(@alignCast(object));
            const len_a = range.consecutive_len();
            const range_a = range;
            var total_range: IList.Range = undefined;
            var range_b: IList.Range = undefined;
            if (new_first < range.first_idx) {
                total_range = IList.Range.new_range(new_first, range.last_idx);
                range_b = IList.Range.new_range(new_first, range.first_idx - 1);
            } else {
                total_range = IList.Range.new_range(range.first_idx, new_first + len_a - 1);
                range_b = IList.Range.new_range(range.last_idx + 1, new_first + len_a - 1);
            }
            self.reverse(range_a.first_idx, range_a.last_idx);
            self.reverse(range_b.first_idx, range_b.last_idx);
            self.reverse(total_range.first_idx, total_range.last_idx);
        }

        fn impl_ensure_free(object: *anyopaque, n: usize, alloc: Allocator) error{failed_to_grow_list}!void {
            const self: *Self = @ptrCast(@alignCast(object));
            const have = @as(u32, @intCast(self.cap - self.len));
            if (have >= n) return;
            const new_cap = self.len + Types.intcast(n, u32);
            return self.special_mem_grow(new_cap, alloc);
        }

        fn impl_shrink_cap(object: *anyopaque, n: usize, alloc: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            const have = @as(u32, @intCast(self.cap - self.len));
            if (have <= n) return;
            const new_cap = self.len + Types.intcast(n, u32);
            self.special_mem_shrink(new_cap, alloc);
        }

        fn impl_append(object: *anyopaque, n: usize, _: Allocator) IList.Range {
            const self: *Self = @ptrCast(@alignCast(object));
            const nn: u32 = @intCast(n);
            const r = IList.Range{
                .first_idx = self.len,
                .last_idx = self.len + n - 1,
            };
            self.len += nn;
            return r;
        }
        fn impl_insert(object: *anyopaque, idx: usize, n: usize, _: Allocator) IList.Range {
            const self: *Self = @ptrCast(@alignCast(object));
            const nn: u32 = @intCast(n);
            const r = IList.Range{
                .first_idx = idx,
                .last_idx = idx + n - 1,
            };
            self.special_mem_insert(idx, n);
            self.len += nn;
            return r;
        }
        fn impl_delete(object: *anyopaque, range: IList.Range, _: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            const rlen: usize = range.consecutive_len();
            self.special_mem_delete(range, rlen);
            self.len -= Types.intcast(rlen, u32);
        }
        fn impl_clear(object: *anyopaque, _: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            self.len = 0;
            self.start = 0;
            return;
        }
        fn impl_free(object: *anyopaque, alloc: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            self.deinit(alloc);
        }
    };
}
