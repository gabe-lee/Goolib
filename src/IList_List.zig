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
const Types = Root.Types;
const Assert = Root.Assert;
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;

pub fn List(comptime T: type, comptime IDX: type) type {
    return struct {
        const Self = @This();

        ptr: [*]T,
        len: IDX,
        cap: IDX,

        const ILIST = IList.IList(T, *T, IDX);
        const ILIST_VTABLE = ILIST.VTable{
            .all_indexes_zero_to_len_valid = impl_true,
            .consecutive_indexes_in_order = impl_true,
            .prefer_linear_ops = impl_false,
            .idx_valid = impl_idx_valid,
            .range_valid = impl_range_valid,
            .get = impl_get,
            .get_ptr = impl_get_ptr,
            .set = impl_set,
            .split_range = impl_split_range,
            .move = impl_move,
            .move_range = impl_move_range,
            .first_idx = impl_first,
            .last_idx = impl_last,
            .next_idx = impl_next,
            .prev_idx = impl_prev,
            .nth_next_idx = impl_nth_next,
            .nth_prev_idx = impl_nth_prev,
            .len = impl_len,
            .range_len = impl_range_len,
            .try_ensure_free_slots = impl_ensure_free,
            .append_slots_assume_capacity = impl_append,
            .insert_slots_assume_capacity = impl_insert,
            .delete_range = impl_delete,
            .clear = impl_clear,
            .cap = impl_cap,
            .free = impl_free,
        };

        fn impl_true() bool {
            return true;
        }
        fn impl_false() bool {
            return false;
        }
        fn impl_idx_valid(object: *anyopaque, idx: IDX) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            return idx < self.len;
        }
        fn impl_range_valid(object: *anyopaque, range: ILIST.Range) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            return range.first_idx <= range.last_idx and range.last_idx < self.len;
        }
        fn impl_split_range(object: *anyopaque, range: ILIST.Range) IDX {
            _ = object;
            return ((range.last_idx - range.first_idx) >> 1) + range.last_idx;
        }
        fn impl_get(object: *anyopaque, idx: IDX) T {
            const self: *Self = @ptrCast(@alignCast(object));
            return self.ptr[idx];
        }
        fn impl_get_ptr(object: *anyopaque, idx: IDX) *T {
            const self: *Self = @ptrCast(@alignCast(object));
            return &self.ptr[idx];
        }
        fn impl_set(object: *anyopaque, idx: IDX, val: T) void {
            const self: *Self = @ptrCast(@alignCast(object));
            self.ptr[idx] = val;
        }
        fn impl_move(object: *anyopaque, old_idx: IDX, new_idx: IDX) void {
            const self: *Self = @ptrCast(@alignCast(object));
            Utils.slice_move_one(T, self.ptr[0..self.len], old_idx, new_idx);
        }
        fn impl_move_range(object: *anyopaque, range: ILIST.Range, new_first_idx: IDX) void {
            const self: *Self = @ptrCast(@alignCast(object));
            Utils.slice_move_many(T, self.ptr[0..self.len], range.first_idx, range.last_idx, new_first_idx);
        }
        fn impl_first(object: *anyopaque) IDX {
            _ = object;
            return 0;
        }
        fn impl_next(object: *anyopaque, idx: IDX) IDX {
            _ = object;
            return idx + 1;
        }
        fn impl_nth_next(object: *anyopaque, idx: IDX, n: IDX) IDX {
            _ = object;
            return idx + n;
        }
        fn impl_last(object: *anyopaque) IDX {
            const self: *Self = @ptrCast(@alignCast(object));
            return self.len -% 1;
        }
        fn impl_prev(object: *anyopaque, idx: IDX) IDX {
            _ = object;
            return idx -% 1;
        }
        fn impl_nth_prev(object: *anyopaque, idx: IDX, n: IDX) IDX {
            _ = object;
            return idx -% n;
        }
        fn impl_len(object: *anyopaque) IDX {
            const self: *Self = @ptrCast(@alignCast(object));
            return self.len;
        }
        fn impl_range_len(object: *anyopaque, first: IDX, last: IDX) IDX {
            _ = object;
            return (last - first) + 1;
        }
        fn impl_ensure_free(object: *anyopaque, count: IDX, alloc: Allocator) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            const free_ = self.cap - self.len;
            if (free_ >= count) {
                return true;
            }
            const new_cap = (self.len + count);
            const new_cap_with_extra = new_cap + (new_cap >> 2);
            if (alloc.remap(self.ptr[0..self.cap], new_cap_with_extra)) |new_mem| {
                self.ptr = new_mem.ptr;
                self.cap = @intCast(new_mem.len);
            } else {
                const new_mem = alloc.alloc(T, new_cap_with_extra) catch {
                    return false;
                };
                @memcpy(new_mem.ptr[0..self.len], self.ptr[0..self.len]);
                alloc.free(self.ptr[0..self.cap]);
                self.ptr = new_mem.ptr;
                self.cap = @intCast(new_mem.len);
            }
            return true;
        }
        fn impl_append(object: *anyopaque, count: IDX, alloc: Allocator) ILIST.Range {
            _ = alloc;
            const self: *Self = @ptrCast(@alignCast(object));
            Assert.assert_with_reason(count <= self.cap - self.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.len, self.cap, self.cap - self.len, count, count });
            self.len += count;
            return ILIST.Range.new_range(self.len - count, self.len - 1);
        }
        fn impl_insert(object: *anyopaque, idx: IDX, count: IDX, alloc: Allocator) ILIST.Range {
            const self: *Self = @ptrCast(@alignCast(object));
            if (idx == self.len) {
                return impl_append(object, count, alloc);
            }
            Assert.assert_with_reason(count <= self.cap - self.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.len, self.cap, self.cap - self.len, count, count });
            const old_len = self.len;
            self.len += count;
            const start = idx;
            const end = idx + count;
            var ridx = old_len - 1;
            var widx = self.len - 1;
            while (widx >= end) {
                self.ptr[widx] = self.ptr[ridx];
                ridx -= 1;
                widx -= 1;
            }
            return ILIST.Range.new_range(start, end - 1);
        }
        fn impl_delete(object: *anyopaque, range: ILIST.Range, alloc: Allocator) void {
            _ = alloc;
            const self: *Self = @ptrCast(@alignCast(object));
            var widx = range.first_idx;
            var ridx = range.last_idx + 1;
            while (ridx < self.len) {
                self.ptr[widx] = self.ptr[ridx];
                widx += 1;
                ridx += 1;
            }
            const rem_count = (range.last_idx - range.first_idx) + 1;
            const new_len = self.len - rem_count;
            self.len = new_len;
        }
        fn impl_clear(object: *anyopaque, alloc: Allocator) void {
            _ = alloc;
            const self: *Self = @ptrCast(@alignCast(object));
            self.len = 0;
        }
        fn impl_cap(object: *anyopaque) IDX {
            const self: *Self = @ptrCast(@alignCast(object));
            return self.cap;
        }
        fn impl_free(object: *anyopaque, mem_alloc: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            mem_alloc.free(self.ptr[0..self.cap]);
            self.len = 0;
            self.cap = 0;
        }
    };
}
