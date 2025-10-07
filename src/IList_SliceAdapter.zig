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

pub fn SliceAdapter(comptime T: type) type {
    return struct {
        pub fn adapt(slice: []T) Adapter {
            return Adapter{
                .slice = slice,
            };
        }
        pub fn adapt_with_alloc(slice: []T, allocator: Allocator) AdapterWithAlloc {
            return AdapterWithAlloc{
                .slice = slice,
                .alloc = allocator,
            };
        }
        pub const Adapter = struct {
            slice: []T,

            pub fn interface(self: *Adapter) ILIST {
                return ILIST{
                    .object = @ptrCast(@alignCast(self)),
                    .vtable = &ILIST_VTABLE_ALLOC,
                };
            }
        };
        pub const AdapterWithAlloc = struct {
            slice: []T,
            alloc: Allocator,

            pub fn interface(self: *AdapterWithAlloc) ILIST {
                return ILIST{
                    .object = @ptrCast(@alignCast(self)),
                    .vtable = &ILIST_VTABLE_ALLOC,
                };
            }
        };
        const ILIST = IList.IList(T);
        const ILIST_VTABLE_ALLOC = ILIST.VTable{
            .all_indexes_zero_to_len_valid = true,
            .consecutive_indexes_in_order = true,
            .prefer_linear_ops = false,
            .ensure_free_doesnt_change_cap = true,
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
            .increment_start = impl_increment_start,
            .free = impl_free,
        };
        fn impl_idx_valid(object: *anyopaque, idx: usize) bool {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            return idx < self.slice.len;
        }
        fn impl_range_valid(object: *anyopaque, range: IList.Range) bool {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            return range.first_idx <= range.last_idx and range.last_idx < self.slice.len;
        }
        fn impl_split_range(object: *anyopaque, range: IList.Range) usize {
            _ = object;
            return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
        }
        fn impl_get(object: *anyopaque, idx: usize) T {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            return self.slice[idx];
        }
        fn impl_get_ptr(object: *anyopaque, idx: usize) *T {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            return &self.slice[idx];
        }
        fn impl_set(object: *anyopaque, idx: usize, val: T) void {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            self.slice[idx] = val;
        }
        fn impl_move(object: *anyopaque, old_idx: usize, new_idx: usize) void {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            Utils.slice_move_one(self.slice, old_idx, new_idx);
        }
        fn impl_move_range(object: *anyopaque, range: IList.Range, new_first_idx: usize) void {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            Utils.slice_move_many(self.slice, range.first_idx, range.last_idx, new_first_idx);
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
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            return self.slice.len -% 1;
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
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            return self.slice.len;
        }
        fn impl_range_len(object: *anyopaque, range: IList.Range) usize {
            _ = object;
            return (range.last_idx - range.first_idx) + 1;
        }
        fn impl_ensure_free(object: *anyopaque, count: usize) bool {
            _ = object;
            _ = count;
            return true;
        }
        fn impl_append(object: *anyopaque, count: usize) IList.Range {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            const new_len = self.slice.len + count;
            const remaped_slice = self.alloc.remap(self.slice, new_len);
            const start = self.slice.len;
            const end = new_len;
            if (remaped_slice) |reslice| {
                self.slice = reslice;
            } else {
                const new_alloc = self.alloc.alloc(T, new_len) catch {
                    Assert.assert_with_reason(false, @src(), "failed to allocate new memory", .{});
                };
                @memcpy(new_alloc[0..self.slice.len], self.slice[0..]);
                self.alloc.free(self.slice);
                self.slice = new_alloc;
            }
            return IList.Range.new_range(start, end - 1);
        }
        fn impl_insert(object: *anyopaque, idx: usize, count: usize) IList.Range {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            const new_len = self.slice.len + count;
            const remaped_slice = self.alloc.remap(self.slice, new_len);
            const old_len = self.slice.len;
            const start = idx;
            const end = idx + count;
            if (remaped_slice) |reslice| {
                self.slice = reslice;
                std.mem.copyBackwards(T, self.slice[idx + count .. new_len], self.slice[idx..old_len]);
            } else {
                const new_slice = self.alloc.alloc(T, new_len) catch {
                    Assert.assert_with_reason(false, @src(), "failed to allocate new memory", .{});
                };
                @memcpy(new_slice[0..start], self.slice[0..start]);
                @memcpy(new_slice[end..], self.slice[start..]);
                self.alloc.free(self.slice);
                self.slice = new_slice;
            }
            return IList.Range.new_range(start, end - 1);
        }
        fn impl_delete(object: *anyopaque, range: IList.Range) void {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            std.mem.copyForwards(T, self.slice[range.first_idx..], self.slice[range.last_idx + 1 ..]);
            const rem_count = (range.last_idx - range.first_idx) + 1;
            const new_len = self.slice.len - rem_count;
            if (self.alloc.remap(self.slice, new_len)) |reslice| {
                self.slice = reslice;
            } else {
                self.slice.len = new_len;
            }
        }
        fn impl_clear(object: *anyopaque) void {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            if (self.alloc.remap(self.slice, 0)) |reslice| {
                self.slice = reslice;
            } else {
                self.slice.len = 0;
            }
        }
        fn impl_cap(object: *anyopaque) usize {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            return self.slice.len;
        }
        fn impl_increment_start(object: *anyopaque, count: usize) void {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            const rcount = @min(count, self.slice.len);
            const old_slice = self.slice;
            self.slice.ptr = self.slice.ptr + rcount;
            self.slice.len -= rcount;
            if (self.slice.len == 0) {
                self.alloc.free(old_slice);
            }
        }
        fn impl_free(object: *anyopaque) void {
            const self: *AdapterWithAlloc = @ptrCast(@alignCast(object));
            self.alloc.free(self.slice);
            self.slice.len = 0;
        }
    };
}
