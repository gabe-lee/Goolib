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
const DummyAlloc = Root.DummyAllocator;

pub fn List(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr: [*]T = @ptrFromInt(std.mem.alignBackward(usize, math.maxInt(usize), @alignOf(T))),
        len: u32 = 0,
        cap: u32 = 0,

        pub fn init_empty() Self {
            return Self{};
        }

        pub fn init_capacity(cap: usize, alloc: Allocator) Self {
            const mem = alloc.alloc(T, cap) catch |err| Assert.assert_allocation_failure(@src(), T, cap, err);
            return Self{
                .ptr = mem.ptr,
                .cap = @intCast(mem.len),
                .len = 0,
            };
        }

        pub fn free(self: *Self, alloc: Allocator) void {
            alloc.free(self.ptr[0..self.cap]);
            self.len = 0;
            self.cap = 0;
        }

        pub fn interface(self: *Self, alloc: Allocator) ILIST {
            return ILIST{
                .alloc = alloc,
                .object = @ptrCast(self),
                .vtable = &ILIST_VTABLE,
            };
        }
        pub fn interface_no_alloc(self: *Self) ILIST {
            return ILIST{
                .alloc = DummyAlloc.allocator_shrink_only,
                .object = @ptrCast(self),
                .vtable = &ILIST_VTABLE,
            };
        }

        const ILIST = IList.IList(T);
        const ILIST_VTABLE = ILIST.VTable{
            .all_indexes_zero_to_len_valid = true,
            .consecutive_indexes_in_order = true,
            .ensure_free_doesnt_change_cap = false,
            .prefer_linear_ops = false,
            .always_invalid_idx = math.maxInt(usize),
            .idx_valid = impl_idx_valid,
            .range_valid = impl_range_valid,
            .split_range = impl_split_range,
            .range_len = impl_range_len,
            .len = impl_len,
            .cap = impl_cap,
            .get = impl_get,
            .get_ptr = impl_get_ptr,
            .set = impl_set,
            .move = impl_move,
            .move_range = impl_move_range,
            .first_idx = impl_first,
            .last_idx = impl_last,
            .next_idx = impl_next,
            .nth_next_idx = impl_nth_next,
            .prev_idx = impl_prev,
            .nth_prev_idx = impl_nth_prev,
            .try_ensure_free_slots = impl_ensure_free,
            .append_slots_assume_capacity = impl_append,
            .insert_slots_assume_capacity = impl_insert,
            .delete_range = impl_delete,
            .clear = impl_clear,
            .free = impl_free,
            .shrink_cap_reserve_at_most = impl_shrink_reserve,
        };

        fn impl_idx_valid(object: *anyopaque, idx: usize) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            return idx < self.len;
        }
        fn impl_range_valid(object: *anyopaque, range: IList.Range) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            return range.first_idx <= range.last_idx and range.last_idx < self.len;
        }
        fn impl_split_range(_: *anyopaque, range: IList.Range) usize {
            return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
        }
        fn impl_range_len(_: *anyopaque, range: IList.Range) usize {
            return range.consecutive_len();
        }
        fn impl_get(object: *anyopaque, idx: usize) T {
            const self: *Self = @ptrCast(@alignCast(object));
            Assert.assert_idx_less_than_len(idx, Types.intcast(self.len, usize), @src());
            return self.ptr[idx];
        }
        fn impl_get_ptr(object: *anyopaque, idx: usize) *T {
            const self: *Self = @ptrCast(@alignCast(object));
            Assert.assert_idx_less_than_len(idx, Types.intcast(self.len, usize), @src());
            return &self.ptr[idx];
        }
        fn impl_set(object: *anyopaque, idx: usize, val: T) void {
            const self: *Self = @ptrCast(@alignCast(object));
            Assert.assert_idx_less_than_len(idx, Types.intcast(self.len, usize), @src());
            self.ptr[idx] = val;
        }
        fn impl_move(object: *anyopaque, old_idx: usize, new_idx: usize) void {
            const self: *Self = @ptrCast(@alignCast(object));
            Utils.slice_move_one(self.ptr[0..self.len], old_idx, new_idx);
        }
        fn impl_move_range(object: *anyopaque, range: IList.Range, new_first_idx: usize) void {
            const self: *Self = @ptrCast(@alignCast(object));
            Utils.slice_move_many(self.ptr[0..self.len], range.first_idx, range.last_idx, new_first_idx);
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
            const self: *Self = @ptrCast(@alignCast(object));
            return @intCast(self.len -% 1);
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
            const self: *Self = @ptrCast(@alignCast(object));
            return @intCast(self.len);
        }
        fn impl_ensure_free(object: *anyopaque, count: usize, alloc: Allocator) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            const have = self.cap - self.len;
            if (have >= count) {
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
        fn impl_append(object: *anyopaque, count: usize, alloc: Allocator) IList.Range {
            _ = alloc;
            const self: *Self = @ptrCast(@alignCast(object));
            Assert.assert_with_reason(count <= self.cap - self.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.len, self.cap, self.cap - self.len, count, count });
            const first: usize = @intCast(self.len);
            self.len += @intCast(count);
            return IList.Range.new_range(first, @intCast(self.len - 1));
        }
        fn impl_insert(object: *anyopaque, idx: usize, count: usize, alloc: Allocator) IList.Range {
            const self: *Self = @ptrCast(@alignCast(object));
            if (idx == self.len) {
                return impl_append(object, count, alloc);
            }
            Assert.assert_with_reason(count <= self.cap - self.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.len, self.cap, self.cap - self.len, count, count });
            Utils.mem_insert(self.ptr, &self.len, idx, count);
            return IList.Range.new_range(idx, idx + count - 1);
        }
        fn impl_delete(object: *anyopaque, range: IList.Range, alloc: Allocator) void {
            _ = alloc;
            const self: *Self = @ptrCast(@alignCast(object));
            const rlen = range.consecutive_len();
            Utils.mem_remove(self.ptr, &self.len, range.first_idx, rlen);
        }
        fn impl_shrink_reserve(object: *anyopaque, reserve_at_most: usize, alloc: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            const space: usize = @intCast(self.cap - self.len);
            if (space <= reserve_at_most) return;
            const new_cap = Types.intcast(self.len, usize) + reserve_at_most;
            if (alloc.remap(self.ptr[0..self.cap], new_cap)) |new_mem| {
                self.ptr = new_mem.ptr;
                self.cap = @intCast(new_mem.len);
            } else {
                const new_mem = alloc.alloc(T, new_cap) catch return;
                @memcpy(new_mem[0..self.len], self.ptr[0..self.len]);
                alloc.free(self.ptr[0..self.cap]);
                self.ptr = new_mem.ptr;
                self.cap = @intCast(new_mem.len);
            }
        }
        fn impl_clear(object: *anyopaque, alloc: Allocator) void {
            _ = alloc;
            const self: *Self = @ptrCast(@alignCast(object));
            self.len = 0;
        }
        fn impl_cap(object: *anyopaque) usize {
            const self: *Self = @ptrCast(@alignCast(object));
            return self.cap;
        }
        fn impl_free(object: *anyopaque, alloc: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            self.free(alloc);
        }
    };
}
