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
const FreeList = Root.BitList.FreeBitList;
const PowerOf2 = Root.Math.PowerOf2;
const Common = Root.CommonTypes;
const StaticDynamic = Common.StaticDynamic;
const CacheAllocator = Common.CacheAllocator;
const SliceRangeSmall = Common.SliceRangeSmall;

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;
const assert_unreachable = Assert.assert_unreachable;
const assert_idx_less_than_len = Assert.assert_idx_less_than_len;
const assert_idx_with_count_in_bounds = Assert.assert_idx_with_count_in_bounds;
const num_cast = Root.Cast.num_cast;
const smart_alloc = Utils.Alloc.smart_alloc;
const smart_alloc_ptr_ptrs = Utils.Alloc.smart_alloc_ptr_ptrs;

const DEBUG = std.debug.print;

pub fn StackStatic(comptime T: type) type {
    return Stack(T, .STATIC, .CACHE_ALLOCATOR);
}
pub fn StackCacheAlloc(comptime T: type) type {
    return Stack(T, .DYNAMIC, .CACHE_ALLOCATOR);
}
pub fn StackProvideAlloc(comptime T: type) type {
    return Stack(T, .DYNAMIC, .PROVIDE_ALLOCATOR_ON_FUNC_CALLS);
}

pub fn Stack(comptime T: type, comptime SIZE: StaticDynamic, comptime CACHE_ALLOC_: CacheAllocator) type {
    return struct {
        const Self = @This();

        ptr: [*]T = Utils.invalid_ptr_many(T),
        len: u32 = 0,
        cap: u32 = 0,
        alloc: T_CACHE_ALLOC = T_CACHE_ALLOC_DEFAULT,

        const IS_DYNAMIC = SIZE == .DYNAMIC;
        const CACHE_ALLOC = IS_DYNAMIC and (CACHE_ALLOC_ == .CACHE_ALLOCATOR);
        const T_CACHE_ALLOC = if (CACHE_ALLOC) Allocator else void;
        const T_CACHE_ALLOC_DEFAULT = if (CACHE_ALLOC) DummyAlloc.allocator_panic_free_noop else void{};
        const T_FUNC_ALLOC = if (CACHE_ALLOC) void else Allocator;

        pub fn init_alloc(cap: u32, alloc: Allocator) Self {
            var self = Self{
                .alloc = if (CACHE_ALLOC) alloc else void{},
            };
            Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &self.ptr, &self.cap, @intCast(cap), .{}, .{});
            return self;
        }

        pub fn init_static(buffer: []T) Self {
            return Self{
                .ptr = buffer.ptr,
                .cap = buffer.len,
            };
        }

        inline fn get_alloc(self: Self, func_alloc: T_FUNC_ALLOC) Allocator {
            if (!IS_DYNAMIC) return DummyAlloc.allocator_panic_free_noop;
            if (CACHE_ALLOC) return self.alloc;
            return func_alloc;
        }

        pub fn ensure_stack_space(self: *Self, need_n_more: u32, alloc: T_FUNC_ALLOC) void {
            const need_cap = self.len + need_n_more;
            if (!IS_DYNAMIC) {
                assert_with_reason(need_cap <= self.cap, @src(), "stack ran out of space, need at least capacity {d}, have capacity {d}", .{ need_cap, self.cap });
            } else {
                if (need_cap > self.cap) {
                    const real_alloc = self.get_alloc(alloc);
                    Utils.Alloc.smart_alloc_ptr_ptrs(real_alloc, &self.ptr, &self.cap, @intCast(need_cap), .{}, .{});
                }
            }
        }

        pub fn push_to_stack(self: *Self, item: T, alloc: T_FUNC_ALLOC) void {
            self.ensure_stack_space(1, alloc);
            self.push_to_stack_assume_capacity(item);
        }
        pub fn push_to_stack_get_idx(self: *Self, item: T, alloc: T_FUNC_ALLOC) u32 {
            self.ensure_stack_space(1, alloc);
            return self.push_to_stack_get_idx_assume_capacity(item);
        }
        pub fn push_to_stack_get_ptr(self: *Self, item: T, alloc: T_FUNC_ALLOC) *T {
            self.ensure_stack_space(1, alloc);
            return self.push_to_stack_get_ptr_assume_capacity(item);
        }
        pub fn push_to_stack_assume_capacity(self: *Self, item: T) void {
            self.ptr[self.len] = item;
            self.len += 1;
        }
        pub fn push_to_stack_get_idx_assume_capacity(self: *Self, item: T) u32 {
            const idx = self.len;
            self.ptr[self.len] = item;
            self.len += 1;
            return idx;
        }
        pub fn push_to_stack_get_ptr_assume_capacity(self: *Self, item: T) *T {
            const idx = self.len;
            self.ptr[self.len] = item;
            self.len += 1;
            return &self.ptr[idx];
        }

        pub fn push_many_to_stack(self: *Self, items: []const T, alloc: T_FUNC_ALLOC) void {
            self.ensure_stack_space(@intCast(items.len), alloc);
            self.push_many_to_stack_assume_capacity(items);
        }
        pub fn push_many_to_stack_get_range(self: *Self, items: []const T, alloc: T_FUNC_ALLOC) SliceRangeSmall {
            self.ensure_stack_space(@intCast(items.len), alloc);
            return self.push_many_to_stack_get_range_assume_capacity(items);
        }
        pub fn push_many_to_stack_get_slice(self: *Self, items: []const T, alloc: T_FUNC_ALLOC) []T {
            self.ensure_stack_space(@intCast(items.len), alloc);
            return self.push_many_to_stack_get_slice_assume_capacity(items);
        }
        pub fn push_many_to_stack_assume_capacity(self: *Self, items: []const T) void {
            const idx = self.len;
            const num = num_cast(items.len, u32);
            const end = idx + num;
            @memcpy(self.ptr[idx..end], items);
            self.len += num;
        }
        pub fn push_many_to_stack_get_range_assume_capacity(self: *Self, items: []const T) SliceRangeSmall {
            const idx = self.len;
            const num = num_cast(items.len, u32);
            const end = idx + num;
            @memcpy(self.ptr[idx..end], items);
            self.len += num;
            return .new_with_end(idx, end);
        }
        pub fn push_many_to_stack_get_slice_assume_capacity(self: *Self, items: []const T) []T {
            const idx = self.len;
            const num = num_cast(items.len, u32);
            const end = idx + num;
            @memcpy(self.ptr[idx..end], items);
            self.len += num;
            return self.ptr[idx..end];
        }

        pub fn pop_1_from_stack_maybe_null(self: *Self) ?T {
            if (self.len == 0) return null;
            const item = self.ptr[self.len - 1];
            self.len -= 1;
            return item;
        }
        pub fn pop_1_from_stack(self: *Self) T {
            const item = self.ptr[self.len - 1];
            self.len -= 1;
            return item;
        }

        pub fn get_top_item_maybe_null(self: Self) ?T {
            if (self.len == 0) return null;
            const item = self.ptr[self.len - 1];
            return item;
        }
        pub fn get_top_item(self: Self) T {
            const item = self.ptr[self.len - 1];
            return item;
        }
        pub fn get_top_item_ptr_maybe_null(self: Self) ?*T {
            if (self.len == 0) return null;
            return &self.ptr[self.len - 1];
        }
        pub fn get_top_item_ptr(self: Self) *T {
            return &self.ptr[self.len - 1];
        }

        pub fn get_item(self: Self, index: u32) T {
            return self.ptr[index];
        }
        pub fn get_item_maybe_null(self: Self, index: u32) ?T {
            if (index >= self.len) return null;
            return self.ptr[index];
        }
        pub fn get_item_ptr(self: Self, index: u32) *T {
            return &self.ptr[index];
        }
        pub fn get_item_ptr_maybe_null(self: Self, index: u32) ?*T {
            if (index >= self.len) return null;
            return &self.ptr[index];
        }

        pub fn delete_1_from_stack_maybe_empty(self: *Self) void {
            if (self.len > 0) {
                self.len -= 1;
            }
        }
        pub fn delete_1_from_stack(self: *Self) void {
            self.len -= 1;
        }

        pub fn clear(self: *Self) void {
            self.len = 0;
        }

        pub fn free(self: *Self, alloc: T_FUNC_ALLOC) void {
            if (IS_DYNAMIC) {
                const real_alloc = self.get_alloc(alloc);
                Utils.Alloc.smart_alloc_ptr_ptrs(real_alloc, &self.ptr, &self.cap, 0, .{}, .{});
            }
            self.* = Self{};
        }
    };
}
