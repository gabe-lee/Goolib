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
const DummyAlloc = Root.DummyAllocator.allocator;

pub fn SliceAdapter(comptime T: type) type {
    return struct {
        pub fn interface(slice_ptr: *[]T, alloc: Allocator) ILIST {
            return ILIST{
                .alloc = alloc,
                .object = @ptrCast(slice_ptr),
                .vtable = &ILIST_VTABLE,
            };
        }
        pub fn interface_no_alloc(slice_ptr: *[]T) ILIST {
            return ILIST{
                .alloc = DummyAlloc,
                .object = @ptrCast(slice_ptr),
                .vtable = &ILIST_VTABLE,
            };
        }
        const ILIST = IList.IList(T);
        const ILIST_VTABLE = ILIST.VTable{
            .all_indexes_zero_to_len_valid = true,
            .consecutive_indexes_in_order = true,
            .prefer_linear_ops = false,
            .ensure_free_doesnt_change_cap = true,
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
            .cap = impl_cap,
            .free = impl_free,
            .clear = impl_clear,
            .delete_range = impl_delete,
        };
        fn impl_idx_valid(object: *anyopaque, idx: usize) bool {
            const slice: *[]T = @ptrCast(@alignCast(object));
            return idx < slice.len;
        }
        fn impl_range_valid(object: *anyopaque, range: IList.Range) bool {
            const slice: *[]T = @ptrCast(@alignCast(object));
            return range.first_idx <= range.last_idx and range.last_idx < slice.len;
        }
        fn impl_idx_in_range(_: *anyopaque, range: IList.Range, idx: usize) bool {
            return range.first_idx <= idx and idx <= range.last_idx;
        }
        fn impl_split_range(object: *anyopaque, range: IList.Range) usize {
            _ = object;
            return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
        }
        fn impl_get(object: *anyopaque, idx: usize, _: Allocator) T {
            const slice: *[]T = @ptrCast(@alignCast(object));
            return slice.ptr[idx];
        }
        fn impl_get_ptr(object: *anyopaque, idx: usize, _: Allocator) *T {
            const slice: *[]T = @ptrCast(@alignCast(object));
            return &slice.ptr[idx];
        }
        fn impl_set(object: *anyopaque, idx: usize, val: T, _: Allocator) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            slice.ptr[idx] = val;
        }
        fn impl_move(object: *anyopaque, old_idx: usize, new_idx: usize, _: Allocator) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            Utils.slice_move_one(slice.*, old_idx, new_idx);
        }
        fn impl_move_range(object: *anyopaque, range: IList.Range, new_first_idx: usize, _: Allocator) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            Utils.slice_move_many(slice.*, range.first_idx, range.last_idx, new_first_idx);
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
            const slice: *[]T = @ptrCast(@alignCast(object));
            return slice.len -% 1;
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
            const slice: *[]T = @ptrCast(@alignCast(object));
            return slice.len;
        }
        fn impl_range_len(object: *anyopaque, range: IList.Range) usize {
            _ = object;
            return (range.last_idx - range.first_idx) + 1;
        }
        fn impl_delete(object: *anyopaque, range: IList.Range, alloc: Allocator) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            std.mem.copyForwards(T, slice.*[range.first_idx..], slice.*[range.last_idx + 1 ..]);
            const rem_count = (range.last_idx - range.first_idx) + 1;
            const new_len = slice.len - rem_count;
            if (alloc.remap(slice.*, new_len)) |new_mem| {
                slice.ptr = new_mem.ptr;
            } else {
                const new_mem = alloc.alloc(T, new_len) catch |err| Assert.assert_with_reason(false, @src(), "failed to allocate memory for {d} items of type {s}: {s}", .{ new_len, @typeName(T), @errorName(err) });
                @memcpy(new_mem[0..new_len], slice.ptr[0..new_len]);
                slice.ptr = new_mem.ptr;
            }
            slice.len = new_len;
        }
        fn impl_clear(object: *anyopaque, alloc: Allocator) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            if (alloc.remap(slice.*, 0)) |new_mem| {
                slice.ptr = new_mem.ptr;
            }
            slice.len = 0;
        }
        fn impl_cap(object: *anyopaque) usize {
            const slice: *[]T = @ptrCast(@alignCast(object));
            return slice.len;
        }
        fn impl_free(object: *anyopaque, alloc: Allocator) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            alloc.free(slice.*);
            slice.len = 0;
            slice.ptr = @ptrFromInt(std.mem.alignBackward(usize, math.maxInt(usize), @alignOf(T)));
        }
    };
}
