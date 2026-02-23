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

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;

pub const SecondaryListSettings = struct {
    elem_type: type = void,
    memset_claimed: ?*const anyopaque = null,
    clear_released: ?*const anyopaque = null,
};

pub fn SimplePool(comptime T: type, comptime IDX: type, comptime BUILTIN_ALLOC: bool, comptime MEMSET_CLAIMED: ?T, comptime CLEAR_RELEASED: ?T, comptime SECONDARY_LIST: ?SecondaryListSettings) type {
    assert_with_reason(Types.type_is_unsigned_int(IDX), @src(), "type `IDX` must be an unsigned int type, got type `{s}`", .{@typeName(IDX)});
    const HAS_SECONDARY = SECONDARY_LIST != null;
    return extern struct {
        const Pool = @This();

        ptr: [*]T = Utils.invalid_ptr_many(T),
        ptr_2: if (HAS_SECONDARY) [*]SECONDARY_LIST.?.elem_type else void = if (HAS_SECONDARY) @ptrCast(Utils.invalid_ptr_many(SECONDARY_LIST.?.elem_type)) else void{},
        alloc: if (BUILTIN_ALLOC) Allocator else void = if (BUILTIN_ALLOC) DummyAlloc.allocator_panic_free_noop else void{},
        free_list: FreeList = .{},
        len: IDX = 0,
        cap: IDX = 0,

        pub fn to_opaque(self: Pool) SimplePoolOpaque(IDX, BUILTIN_ALLOC) {
            return @bitCast(self);
        }
        pub fn to_opaque_ptr(self: *Pool) *SimplePoolOpaque(IDX, BUILTIN_ALLOC) {
            return @ptrCast(@alignCast(self));
        }

        pub fn slice(self: Pool) []T {
            return self.ptr[0..self.len];
        }

        pub fn init_capacity(cap: IDX, alloc: Allocator) Pool {
            const mem = alloc.alloc(T, cap) catch |err| assert_allocation_failure(@src(), T, @intCast(cap), err);
            var pool = Pool{
                .ptr = mem.ptr,
                .len = 0,
                .cap = @intCast(mem.len),
                .free_list = .init_capacity(@intCast(cap), alloc),
            };
            if (BUILTIN_ALLOC) pool.alloc = alloc;
            if (HAS_SECONDARY) {
                const mem_2 = alloc.alloc(SECONDARY_LIST.?.elem_type, cap) catch |err| assert_allocation_failure(@src(), SECONDARY_LIST.?.elem_type, @intCast(cap), err);
                pool.ptr_2 = mem_2.ptr;
            }
            return pool;
        }

        pub fn free_builtin(self: *Pool) void {
            if (BUILTIN_ALLOC) {
                self.free(self.alloc);
            } else {
                unreachable;
            }
        }
        pub fn free(self: *Pool, alloc: Allocator) void {
            Utils.Alloc.realloc_custom(alloc, self.ptr[0..self.cap], 0, .ALIGN_TO_TYPE, .DONT_COPY_EXISTING_DATA, .dont_memset_new(), .dont_memset_old());
            if (HAS_SECONDARY) Utils.Alloc.realloc_custom(alloc, self.ptr_2[0..self.cap], 0, .ALIGN_TO_TYPE, .DONT_COPY_EXISTING_DATA, .dont_memset_new(), .dont_memset_old());
            self.free_list.free_bits.list.free(alloc);
            self.* = undefined;
        }

        pub const ClaimedItem = struct {
            ptr: *T,
            idx: IDX,
        };
        pub const ClaimedRange = struct {
            slice: []T,
            start_idx: IDX,
        };

        pub fn ensure_capacity_builtin(self: *Pool, cap: IDX) void {
            if (BUILTIN_ALLOC) {
                ensure_capacity(self, cap, self.alloc);
            } else {
                unreachable;
            }
        }
        pub fn ensure_capacity(self: *Pool, cap: IDX, alloc: Allocator) void {
            if (self.cap >= cap) return;
            const new_mem = Utils.Alloc.realloc_custom(alloc, self.ptr[0..self.cap], @intCast(cap), .ALIGN_TO_TYPE, .COPY_EXISTING_DATA, .dont_memset_new(), .dont_memset_old()) catch |err| assert_allocation_failure(@src(), T, @intCast(cap), err);
            self.ptr = new_mem.ptr;
            self.cap = @intCast(new_mem.len);
            if (HAS_SECONDARY) {
                const new_mem_2 = Utils.Alloc.realloc_custom(alloc, self.ptr_2[0..self.cap], @intCast(cap), .ALIGN_TO_TYPE, .COPY_EXISTING_DATA, .dont_memset_new(), .dont_memset_old()) catch |err| assert_allocation_failure(@src(), SECONDARY_LIST.?.elem_type, @intCast(cap), err);
                self.ptr_2 = new_mem_2.ptr;
            }
        }

        pub fn claim_one_builtin(self: *Pool) void {
            if (BUILTIN_ALLOC) return claim_one(self, self.alloc);
            unreachable;
        }
        pub fn claim_one(self: *Pool, alloc: Allocator) ClaimedItem {
            if (self.free_list.find_1_free_and_set_used()) |new_idx| {
                return ClaimedItem{
                    .ptr = @ptrCast(self.ptr + new_idx),
                    .idx = new_idx,
                };
            }
            self.ensure_capacity_no_builtin(self.len + 1, alloc);
            self.free_list.set_len(@intCast(self.len + 1), alloc);
            const new_idx = self.len;
            self.len += 1;
            if (MEMSET_CLAIMED) |val| {
                self.ptr[new_idx] = val;
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.memset_claimed != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.memset_claimed));
                self.ptr_2[new_idx] = t_ptr.*;
            }
            return ClaimedItem{
                .ptr = @ptrCast(self.ptr + new_idx),
                .idx = new_idx,
            };
        }

        pub fn claim_range_builtin(self: *Pool) void {
            if (BUILTIN_ALLOC) return claim_range(self, self.alloc);
            unreachable;
        }
        pub fn claim_range(self: *Pool, count: IDX, alloc: Allocator) ClaimedRange {
            if (self.free_list.find_range_free_and_set_used(@intCast(count))) |new_idx| {
                return ClaimedRange{
                    .slice = (self.ptr + new_idx)[0..count],
                    .start_idx = new_idx,
                };
            }
            self.ensure_capacity_no_builtin(self.len + count, alloc);
            self.free_list.set_len(@intCast(self.len + count), alloc);
            const new_idx = self.len;
            self.len += count;
            if (MEMSET_CLAIMED) |val| {
                @memset(self.ptr[new_idx .. new_idx + count], val);
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.memset_claimed != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.memset_claimed));
                const t_set = t_ptr.*;
                @memset(self.ptr_2[new_idx .. new_idx + count], t_set);
            }
            return ClaimedRange{
                .slice = (self.ptr + new_idx)[0..count],
                .start_idx = new_idx,
            };
        }

        pub fn release_one_ptr(self: *Pool, ptr: *const T) void {
            self.release_one(self.find_index_for_ptr(ptr));
        }
        pub fn release_one(self: *Pool, idx: IDX) void {
            self.free_list.set_free(idx);
            if (CLEAR_RELEASED) |val| {
                self.ptr[idx] = val;
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.clear_released != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.clear_released));
                self.ptr_2[idx] = t_ptr.*;
            }
        }
        pub fn release_range_slice(self: *Pool, _slice: []const T) void {
            const range = self.find_range_for_slice(_slice);
            self.release_range(range.start, range.count);
        }
        pub fn release_range(self: *Pool, idx: IDX, count: IDX) void {
            self.free_list.set_range_free(@intCast(idx), @intCast(count));
            if (CLEAR_RELEASED) |val| {
                @memset(self.ptr[idx .. idx + count], val);
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.clear_released != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.clear_released));
                const t_set = t_ptr.*;
                @memset(self.ptr_2[idx .. idx + count], t_set);
            }
        }

        pub fn resize_range_slice(self: *Pool, old_slice: []const T, new_count: IDX, alloc: Allocator) ClaimedRange {
            const range = self.find_range_for_slice(old_slice);
            return self.resize_range(range.start, range.count, new_count, alloc);
        }
        pub fn resize_range(self: *Pool, idx: IDX, old_count: IDX, new_count: IDX, alloc: Allocator) ClaimedRange {
            if (new_count == old_count) return;
            const old_end = idx + old_count;
            if (new_count < old_count) {
                self.release_range(old_end, old_count - new_count);
                return;
            }
            const grow_count = new_count - old_count;
            if (self.free_list.has_n_consecutive_frees_at_idx(old_end, grow_count)) {
                _ = self.free_list.set_range_used(old_end, grow_count);
                return ClaimedRange{
                    .slice = self.ptr[idx .. old_end + grow_count],
                    .start_idx = idx,
                };
            }
            const new_range = self.claim_range(new_count, alloc);
            @memcpy(new_range.slice[0..old_count], self.ptr[idx..old_end]);
            if (HAS_SECONDARY) {
                @memcpy(self.ptr_2[new_range.start_idx .. new_range.start_idx + old_count], self.ptr_2[idx..old_end]);
            }
            self.release_range(idx, old_count);
            return new_range;
        }

        pub fn resize_range_slice_builtin(self: *Pool, old_slice: []const T, new_count: IDX) ClaimedRange {
            if (BUILTIN_ALLOC) return self.resize_range_slice(old_slice, new_count, self.alloc);
            unreachable;
        }
        pub fn resize_range_builtin(self: *Pool, idx: IDX, old_count: IDX, new_count: IDX) ClaimedRange {
            if (BUILTIN_ALLOC) return self.resize_range(idx, old_count, new_count, self.alloc);
            unreachable;
        }

        pub fn find_index_for_ptr(self: Pool, ptr: *const T) IDX {
            const ptr_addr = @intFromPtr(ptr);
            const pool_addr = @intFromPtr(self.ptr);
            if (Assert.should_assert()) {
                const addr_limit = pool_addr + (num_cast(self.len, usize) * @sizeOf(usize));
                assert_with_reason(pool_addr <= ptr_addr and ptr_addr < addr_limit, @src(), "pointer is not within pool", .{});
            }
            const delta_addr = ptr_addr - pool_addr;
            const idx = delta_addr / @sizeOf(T);
            return @intCast(idx);
        }

        const Range = struct {
            start: IDX,
            count: IDX,
        };

        pub fn find_range_for_slice(self: Pool, _slice: []const T) Range {
            const ptr_addr = @intFromPtr(_slice.ptr);
            const pool_addr = @intFromPtr(self.ptr);
            if (Assert.should_assert()) {
                const ptr_addr_end = @intFromPtr(_slice.ptr + _slice.len);
                const addr_limit = pool_addr + (num_cast(self.len, usize) * @sizeOf(usize));
                assert_with_reason(pool_addr <= ptr_addr and ptr_addr < addr_limit, @src(), "slice is not within pool", .{});
                assert_with_reason(ptr_addr_end <= addr_limit, @src(), "slice extends beyond pool", .{});
            }
            const delta_addr = ptr_addr - pool_addr;
            const idx = delta_addr / @sizeOf(T);
            return Range{
                .start = @intCast(idx),
                .count = @intCast(_slice.len),
            };
        }
    };
}

pub fn SimplePoolOpaque(comptime IDX: type, comptime BUILTIN_ALLOC: bool, comptime SECONDARY_LIST: ?SecondaryListSettings) type {
    assert_with_reason(Types.type_is_unsigned_int(IDX), @src(), "type `IDX` must be an unsigned int type, got type `{s}`", .{@typeName(IDX)});
    const HAS_SECONDARY = SECONDARY_LIST != null;
    return extern struct {
        const Pool = @This();

        ptr: [*]anyopaque = @ptrCast(Utils.invalid_ptr_many(u8)),
        ptr_2: if (HAS_SECONDARY) [*]SECONDARY_LIST.?.elem_type else void = if (HAS_SECONDARY) @ptrCast(Utils.invalid_ptr_many(SECONDARY_LIST.?.elem_type)) else void{},
        alloc: if (BUILTIN_ALLOC) Allocator else void = if (BUILTIN_ALLOC) DummyAlloc.allocator_panic_free_noop else void{},
        free_list: FreeList = .{},
        len: IDX = 0,
        cap: IDX = 0,

        pub fn to_typed(self: Pool, comptime T: type) SimplePool(T, IDX, BUILTIN_ALLOC, null, null, SECONDARY_LIST) {
            return @bitCast(self);
        }
        pub fn to_typed_ptr(self: *Pool, comptime T: type) *SimplePool(T, IDX, BUILTIN_ALLOC, null, null, SECONDARY_LIST) {
            return @ptrCast(@alignCast(self));
        }
    };
}
