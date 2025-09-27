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
        pub fn adapt(slice: *[]T) ILIST {
            return ILIST{
                .object = @ptrCast(@alignCast(slice)),
                .vtable = &ILIST_VTABLE,
            };
        }
        const ILIST = IList.IList(T, *T, usize);
        const ILIST_VTABLE = ILIST.VTable{
            .all_indexes_zero_to_len_valid = impl_true,
            .consecutive_indexes_in_order = impl_true,
            .prefer_linear_ops = impl_false,
            .idx_valid = impl_idx_valid,
            .split_range = impl_split_range,
            .move = impl_move,
            .move_range = impl_move_range,
            .slice = impl_slice,
            .clone = impl_clone,
            .first_idx = impl_first,
            .last_idx = impl_last,
            .next_idx = impl_next,
            .prev_idx = impl_prev,
            .nth_next_idx = impl_nth_next,
            .nth_prev_idx = impl_nth_prev,
            .len = impl_len,
            .range_len = impl_range_len,
            .free = impl_free,
            .destroy = impl_destroy,
        };

        fn impl_true() bool {
            return true;
        }
        fn impl_false() bool {
            return false;
        }
        fn impl_idx_valid(object: *anyopaque, idx: usize) bool {
            const slice: *[]T = @ptrCast(@alignCast(object));
            return idx < slice.len;
        }
        fn impl_range_valid(object: *anyopaque, range: ILIST.Range) bool {
            const slice: *[]T = @ptrCast(@alignCast(object));
            return range.first_idx <= range.last_idx and range.last_idx < slice.len;
        }
        fn impl_split_range(object: *anyopaque, range: ILIST.Range) usize {
            _ = object;
            return ((range.last_idx - range.first_idx) >> 1) + range.last_idx;
        }
        fn impl_get(object: *anyopaque, idx: usize) T {
            const slice: *[]T = @ptrCast(@alignCast(object));
            return slice[idx];
        }
        fn impl_get_ptr(object: *anyopaque, idx: usize) *T {
            const slice: *[]T = @ptrCast(@alignCast(object));
            return &slice[idx];
        }
        fn impl_set(object: *anyopaque, idx: usize, val: T) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            slice[idx] = val;
        }
        fn impl_move(object: *anyopaque, old_idx: usize, new_idx: usize) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            Utils.slice_move_one(T, slice, old_idx, new_idx);
        }
        fn impl_move_range(object: *anyopaque, range: ILIST.Range, new_first_idx: usize) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            Utils.slice_move_many(T, slice, range.first_idx, range.last_idx, new_first_idx);
        }
        fn impl_slice(object: *anyopaque, range: ILIST.Range, obj_alloc: Allocator) ILIST {
            const slice: *[]T = @ptrCast(@alignCast(object));
            const new_slice = obj_alloc.create([]T) catch {
                Assert.assert_with_reason(false, @src(), "failed to create a new `[]T` using the supplied allocator", .{});
                unreachable;
            };
            new_slice.ptr = slice.ptr;
            new_slice.len = slice.len;
            new_slice.* = (new_slice.*)[range.first_idx .. range.last_idx + 1];
            return ILIST{
                .object = @ptrCast(new_slice),
                .vtable = &ILIST_VTABLE,
            };
        }
        fn impl_clone(object: *anyopaque, range: ILIST.Range, obj_alloc: Allocator, mem_alloc: Allocator) ILIST {
            const slice: *[]T = @ptrCast(@alignCast(object));
            const new_len = (range.last_idx - range.first_idx) + 1;
            const new_mem = mem_alloc.alloc(T, new_len) catch {
                Assert.assert_with_reason(false, @src(), "failed to create new memory for a `[]{s}` using the supplied allocator", .{@typeName(T)});
                unreachable;
            };
            const new_slice = obj_alloc.create([]T) catch {
                Assert.assert_with_reason(false, @src(), "failed to create a new `[]{s}` object using the supplied allocator", .{@typeName(T)});
                unreachable;
            };
            new_slice.ptr = new_mem.ptr;
            new_slice.len = new_mem.len;
            @memcpy(new_slice.*, (slice.*)[range.first_idx .. range.last_idx + 1]);
            return ILIST{
                .object = @ptrCast(new_slice),
                .vtable = &ILIST_VTABLE,
            };
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
        fn impl_range_len(object: *anyopaque, first: usize, last: usize) usize {
            _ = object;
            return (last - first) + 1;
        }
        fn impl_free(object: *anyopaque, mem_alloc: Allocator) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            mem_alloc.free(slice.*);
        }
        fn impl_destroy(object: *anyopaque, obj_alloc: Allocator) void {
            const slice: *[]T = @ptrCast(@alignCast(object));
            obj_alloc.destroy(slice);
        }
    };
}
