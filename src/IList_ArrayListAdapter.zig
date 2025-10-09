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
        pub fn adapt(list: AList, alloc: Allocator) Adapter {
            return Adapter{
                .list = list,
                .alloc = alloc,
            };
        }
        pub const Adapter = struct {
            list: AList,
            alloc: Allocator,

            pub fn interface(self: *Adapter) ILIST {
                return ILIST{
                    .object = @ptrCast(@alignCast(self)),
                    .vtable = &ILIST_VTABLE,
                };
            }
        };
        const ILIST = IList.IList(T);
        const ILIST_VTABLE = ILIST.VTable{
            .all_indexes_zero_to_len_valid = true,
            .consecutive_indexes_in_order = true,
            .prefer_linear_ops = false,
            .ensure_free_doesnt_change_cap = false,
            .always_invalid_idx = math.maxInt(usize),
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
        fn impl_idx_valid(object: *anyopaque, idx: usize) bool {
            const self: *Adapter = @ptrCast(@alignCast(object));
            return idx < self.list.items.len;
        }
        fn impl_range_valid(object: *anyopaque, range: IList.Range) bool {
            const self: *Adapter = @ptrCast(@alignCast(object));
            return range.first_idx <= range.last_idx and range.last_idx < self.list.items.len;
        }
        fn impl_split_range(object: *anyopaque, range: IList.Range) usize {
            _ = object;
            return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
        }
        fn impl_get(object: *anyopaque, idx: usize) T {
            const self: *Adapter = @ptrCast(@alignCast(object));
            return self.list.items[idx];
        }
        fn impl_get_ptr(object: *anyopaque, idx: usize) *T {
            const self: *Adapter = @ptrCast(@alignCast(object));
            return &self.list.items[idx];
        }
        fn impl_set(object: *anyopaque, idx: usize, val: T) void {
            const self: *Adapter = @ptrCast(@alignCast(object));
            self.list.items[idx] = val;
        }
        fn impl_move(object: *anyopaque, old_idx: usize, new_idx: usize) void {
            const self: *Adapter = @ptrCast(@alignCast(object));
            Utils.slice_move_one(self.list.items, old_idx, new_idx);
        }
        fn impl_move_range(object: *anyopaque, range: IList.Range, new_first_idx: usize) void {
            const self: *Adapter = @ptrCast(@alignCast(object));
            Utils.slice_move_many(self.list.items, range.first_idx, range.last_idx, new_first_idx);
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
            const self: *Adapter = @ptrCast(@alignCast(object));
            return self.list.items.len -% 1;
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
            const self: *Adapter = @ptrCast(@alignCast(object));
            return self.list.items.len;
        }
        fn impl_range_len(object: *anyopaque, range: IList.Range) usize {
            _ = object;
            return (range.last_idx - range.first_idx) + 1;
        }
        fn impl_ensure_free(object: *anyopaque, count: usize) bool {
            const self: *Adapter = @ptrCast(@alignCast(object));
            self.list.ensureUnusedCapacity(self.alloc, count) catch return false;
            return true;
        }
        fn impl_append(object: *anyopaque, count: usize) IList.Range {
            const self: *Adapter = @ptrCast(@alignCast(object));
            const new_len = self.list.items.len + count;
            const start = self.list.items.len;
            const end = new_len;
            _ = self.list.addManyAt(self.alloc, self.list.items.len, count) catch unreachable;
            return IList.Range.new_range(start, end - 1);
        }
        fn impl_insert(object: *anyopaque, idx: usize, count: usize) IList.Range {
            const self: *Adapter = @ptrCast(@alignCast(object));
            const start = idx;
            const end = idx + count;
            _ = self.list.addManyAt(self.alloc, idx, count) catch unreachable;
            return IList.Range.new_range(start, end - 1);
        }
        fn impl_delete(object: *anyopaque, range: IList.Range) void {
            const self: *Adapter = @ptrCast(@alignCast(object));
            self.list.replaceRange(self.alloc, range.first_idx, (range.last_idx - range.first_idx) + 1, &.{}) catch unreachable;
            // std.mem.copyForwards(T, self.list.items[range.first_idx..], self.list.items[range.last_idx + 1 ..]);
            // const rem_count = (range.last_idx - range.first_idx) + 1;
            // const new_len = self.list.items.len - rem_count;
            // self.list.items.len = new_len;
        }
        fn impl_clear(object: *anyopaque) void {
            const self: *Adapter = @ptrCast(@alignCast(object));
            self.list.clearRetainingCapacity();
        }
        fn impl_cap(object: *anyopaque) usize {
            const self: *Adapter = @ptrCast(@alignCast(object));
            return self.list.capacity;
        }
        fn impl_free(object: *anyopaque) void {
            const self: *Adapter = @ptrCast(@alignCast(object));
            self.list.clearAndFree(self.alloc);
        }
    };
}
