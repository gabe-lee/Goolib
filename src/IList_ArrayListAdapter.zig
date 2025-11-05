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

pub fn ArrayListAdapter(comptime T: type) type {
    const AList = std.ArrayList(T);
    return struct {
        pub fn interface(list: *std.ArrayList(T), alloc: Allocator) ILIST {
            return ILIST{
                .alloc = alloc,
                .object = @ptrCast(list),
                .vtable = &ILIST_VTABLE,
            };
        }

        const ILIST = IList.IList(T);
        const ILIST_VTABLE = ILIST.VTable{
            .all_indexes_zero_to_len_valid = true,
            .consecutive_indexes_in_order = true,
            .prefer_linear_ops = false,
            .ensure_free_doesnt_change_cap = false,
            .always_invalid_idx = math.maxInt(usize),
            .idx_valid = impl_idx_valid,
            .idx_in_range = impl_idx_in_range,
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
            .shrink_cap_reserve_at_most = impl_shrink_cap,
            .clear = impl_clear,
            .cap = impl_cap,
            .free = impl_free,
        };
        fn impl_idx_valid(object: *anyopaque, idx: usize) bool {
            const list: *AList = @ptrCast(@alignCast(object));
            return idx < list.items.len;
        }
        fn impl_range_valid(object: *anyopaque, range: IList.Range) bool {
            const list: *AList = @ptrCast(@alignCast(object));
            return range.first_idx <= range.last_idx and range.last_idx < list.items.len;
        }
        fn impl_idx_in_range(_: *anyopaque, range: IList.Range, idx: usize) bool {
            return range.first_idx <= idx and idx <= range.last_idx;
        }
        fn impl_split_range(object: *anyopaque, range: IList.Range) usize {
            _ = object;
            return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
        }
        fn impl_get(object: *anyopaque, idx: usize, _: Allocator) T {
            const list: *AList = @ptrCast(@alignCast(object));
            return list.items[idx];
        }
        fn impl_get_ptr(object: *anyopaque, idx: usize, _: Allocator) *T {
            const list: *AList = @ptrCast(@alignCast(object));
            return &list.items[idx];
        }
        fn impl_set(object: *anyopaque, idx: usize, val: T, _: Allocator) void {
            const list: *AList = @ptrCast(@alignCast(object));
            list.items[idx] = val;
        }
        fn impl_move(object: *anyopaque, old_idx: usize, new_idx: usize, _: Allocator) void {
            const list: *AList = @ptrCast(@alignCast(object));
            Utils.slice_move_one(list.items, old_idx, new_idx);
        }
        fn impl_move_range(object: *anyopaque, range: IList.Range, new_first_idx: usize, _: Allocator) void {
            const list: *AList = @ptrCast(@alignCast(object));
            Utils.slice_move_many(list.items, range.first_idx, range.last_idx, new_first_idx);
        }
        fn impl_first(object: *anyopaque) usize {
            _ = object;
            return 0;
        }
        fn impl_next(object: *anyopaque, idx: usize) usize {
            _ = object;
            return idx + 1;
        }
        fn impl_nth_next(object: *anyopaque, idx: usize, n: usize) usize {
            _ = object;
            return idx + n;
        }
        fn impl_last(object: *anyopaque) usize {
            const list: *AList = @ptrCast(@alignCast(object));
            return list.items.len -% 1;
        }
        fn impl_prev(object: *anyopaque, idx: usize) usize {
            _ = object;
            return idx -% 1;
        }
        fn impl_nth_prev(object: *anyopaque, idx: usize, n: usize) usize {
            _ = object;
            return idx -% n;
        }
        fn impl_len(object: *anyopaque) usize {
            const list: *AList = @ptrCast(@alignCast(object));
            return list.items.len;
        }
        fn impl_range_len(object: *anyopaque, range: IList.Range) usize {
            _ = object;
            return (range.last_idx - range.first_idx) + 1;
        }
        fn impl_ensure_free(object: *anyopaque, count: usize, alloc: Allocator) error{failed_to_grow_list}!void {
            const list: *AList = @ptrCast(@alignCast(object));
            list.ensureUnusedCapacity(alloc, count) catch return false;
            return;
        }
        fn impl_append(object: *anyopaque, count: usize, _: Allocator) IList.Range {
            const list: *AList = @ptrCast(@alignCast(object));
            const new_len = list.items.len + count;
            const start = list.items.len;
            const end = new_len;
            _ = list.addManyAtAssumeCapacity(list.items.len, count);
            return IList.Range.new_range(start, end - 1);
        }
        fn impl_insert(object: *anyopaque, idx: usize, count: usize, _: Allocator) IList.Range {
            const list: *AList = @ptrCast(@alignCast(object));
            const start = idx;
            const end = idx + count;
            _ = list.addManyAtAssumeCapacity(idx, count);
            return IList.Range.new_range(start, end - 1);
        }
        fn impl_delete(object: *anyopaque, range: IList.Range, _: Allocator) void {
            const list: *AList = @ptrCast(@alignCast(object));
            // list.replaceRange(alloc, range.first_idx, (range.last_idx - range.first_idx) + 1, &.{}) catch unreachable;
            std.mem.copyForwards(T, list.items[range.first_idx..], list.items[range.last_idx + 1 ..]);
            list.items.len -= (range.last_idx - range.first_idx) + 1;
        }
        fn impl_shrink_cap(object: *anyopaque, n: usize, _: Allocator) void {
            const list: *AList = @ptrCast(@alignCast(object));
            const new_cap = @min(list.items.len + n, list.capacity);
            const len = list.items.len;
            list.items.len = new_cap;
            list.shrinkRetainingCapacity(list.items.len);
            list.items.len = len;
        }
        fn impl_clear(object: *anyopaque, _: Allocator) void {
            const list: *AList = @ptrCast(@alignCast(object));
            list.clearRetainingCapacity();
        }
        fn impl_cap(object: *anyopaque) usize {
            const list: *AList = @ptrCast(@alignCast(object));
            return list.capacity;
        }
        fn impl_free(object: *anyopaque, alloc: Allocator) void {
            const list: *AList = @ptrCast(@alignCast(object));
            list.clearAndFree(alloc);
        }
    };
}
