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
const assert_idx_less_than_len = Assert.assert_idx_less_than_len;
const assert_idx_with_count_in_bounds = Assert.assert_idx_with_count_in_bounds;
const num_cast = Root.Cast.num_cast;
const smart_alloc = Utils.Alloc.smart_alloc;
const smart_alloc_ptr_ptrs = Utils.Alloc.smart_alloc_ptr_ptrs;

const DEBUG = std.debug.print;

pub const SecondaryListSettings = struct {
    elem_type: type = void,
    memset_claimed: ?*const anyopaque = null,
    clear_released: ?*const anyopaque = null,
};

pub fn SimplePool(comptime T: type, comptime IDX: type, comptime MEMSET_CLAIMED: ?T, comptime CLEAR_RELEASED: ?T, comptime SECONDARY_LIST: ?SecondaryListSettings) type {
    assert_with_reason(Types.type_is_unsigned_int(IDX), @src(), "type `IDX` must be an unsigned int type, got type `{s}`", .{@typeName(IDX)});
    const HAS_SECONDARY = SECONDARY_LIST != null;
    return extern struct {
        const Pool = @This();

        ptr: [*]T = Utils.invalid_ptr_many(T),
        ptr_2: if (HAS_SECONDARY) [*]SECONDARY_LIST.?.elem_type else void = if (HAS_SECONDARY) @ptrCast(Utils.invalid_ptr_many(SECONDARY_LIST.?.elem_type)) else void{},
        free_list: FreeList = .{},
        len: IDX = 0,
        cap: IDX = 0,

        const SET: T = if (MEMSET_CLAIMED) |S| S else undefined;
        const CLEAR: T = if (CLEAR_RELEASED) |C| C else undefined;

        pub fn to_opaque(self: Pool) SimplePoolOpaque(IDX, Utils.scalar_ptr_as_byte_slice_const(&SET), Utils.scalar_ptr_as_byte_slice_const(&CLEAR), SECONDARY_LIST) {
            return @bitCast(self);
        }
        pub fn to_opaque_ptr(self: *Pool) *SimplePoolOpaque(IDX, Utils.scalar_ptr_as_byte_slice_const(&SET), Utils.scalar_ptr_as_byte_slice_const(&CLEAR), SECONDARY_LIST) {
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
            if (HAS_SECONDARY) {
                const mem_2 = alloc.alloc(SECONDARY_LIST.?.elem_type, cap) catch |err| assert_allocation_failure(@src(), SECONDARY_LIST.?.elem_type, @intCast(cap), err);
                pool.ptr_2 = mem_2.ptr;
            }
            return pool;
        }

        pub fn init_static(main_buffer: []T, free_buffer: []usize, secondary_buffer: if (HAS_SECONDARY) []SECONDARY_LIST.?.elem_type else void) Pool {
            assert_with_reason(free_buffer.len * @bitSizeOf(usize) >= main_buffer.len, @src(), "free buffer is not large enough for main buffer, free buffer has {d} bits, need {d} bits", .{ free_buffer.len * @bitSizeOf(usize), main_buffer.len });
            if (HAS_SECONDARY) {
                assert_with_reason(secondary_buffer.len >= main_buffer.len, @src(), "secondary buffer len ({d}) is smaller than main buffer len ({d})", .{ secondary_buffer.len, main_buffer.len });
            }
            return Pool{
                .ptr = main_buffer.ptr,
                .cap = @intCast(main_buffer.len),
                .len = 0,
                .free_list = .{
                    .free_bits = .{
                        .list = .{
                            .ptr = free_buffer,
                            .cap = free_buffer.len,
                            .len = 0,
                        },
                        .index_len = 0,
                    },
                    .free_count = 0,
                },
                .ptr_2 = if (HAS_SECONDARY) secondary_buffer.ptr else void{},
            };
        }

        pub fn free(self: *Pool, alloc: Allocator) void {
            _ = Utils.Alloc.smart_alloc(alloc, self.ptr[0..self.cap], 0, .{}, .{});
            if (HAS_SECONDARY) {
                _ = Utils.Alloc.smart_alloc(alloc, self.ptr_2[0..self.cap], 0, .{}, .{});
            }
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

        fn ensure_capacity(self: *Pool, cap: IDX, alloc: Allocator) void {
            if (self.cap >= cap) return;
            if (HAS_SECONDARY) {
                const new_mem_2 = smart_alloc(alloc, self.ptr_2[0..self.cap], @intCast(cap), .{}, .{});
                self.ptr_2 = new_mem_2.ptr;
            }
            const new_mem = smart_alloc(alloc, self.ptr[0..self.cap], @intCast(cap), .{}, .{});
            self.ptr = new_mem.ptr;
            self.cap = @intCast(new_mem.len);
        }
        pub fn set_len(self: *Pool, len: IDX, alloc: Allocator) void {
            self.free_list.set_len(len, alloc);
            self.ensure_capacity(len, alloc);
            self.len = len;
        }
        pub fn grow_len_if_needed(self: *Pool, len: IDX, alloc: Allocator) void {
            if (self.len < len) {
                self.set_len(len, alloc);
            }
        }
        pub fn grow_len_if_needed_for_idx(self: *Pool, idx: IDX, alloc: Allocator) void {
            const len = idx + 1;
            if (self.len < len) {
                self.set_len(len, alloc);
            }
        }
        pub fn claim_one_specific(self: *Pool, idx: IDX, alloc: Allocator) ClaimedItem {
            assert_with_reason(idx >= self.free_list.free_bits.index_len or self.free_list.idx_is_free(@intCast(idx)), @src(), "index {d} was not free, cannot claim it", .{idx});
            self.grow_len_if_needed_for_idx(idx, alloc);
            self.free_list.set_used(idx);
            if (MEMSET_CLAIMED) |val| {
                self.ptr[idx] = val;
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.memset_claimed != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.memset_claimed));
                self.ptr_2[idx] = t_ptr.*;
            }
            return ClaimedItem{
                .ptr = @ptrCast(self.ptr + idx),
                .idx = idx,
            };
        }
        pub fn claim_one(self: *Pool, alloc: Allocator) ClaimedItem {
            if (self.free_list.find_1_free_and_set_used()) |new_idx| {
                return ClaimedItem{
                    .ptr = @ptrCast(self.ptr + new_idx),
                    .idx = @intCast(new_idx),
                };
            }
            const new_idx = self.len;
            self.grow_len_if_needed_for_idx(new_idx, alloc);
            self.free_list.set_used(new_idx);
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

        pub fn claim_range(self: *Pool, count: IDX, alloc: Allocator) ClaimedRange {
            if (self.free_list.find_range_free_and_set_used(@intCast(count))) |new_idx| {
                return ClaimedRange{
                    .slice = (self.ptr + new_idx)[0..count],
                    .start_idx = @intCast(new_idx),
                };
            }
            const new_idx = self.len;
            self.grow_len_if_needed(self.len + count, alloc);
            self.free_list.set_range_used(@intCast(new_idx), @intCast(count));
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
        pub fn claim_range_specific(self: *Pool, idx: IDX, count: IDX, alloc: Allocator) ClaimedRange {
            assert_with_reason(idx >= self.free_list.free_bits.index_len or self.free_list.has_n_consecutive_frees_at_idx(@intCast(idx), @intCast(@min(count, self.len - idx))), @src(), "{d} indices starting from index {d} were not all free, cannot claim them", .{ count, idx });
            const end = idx + count;
            self.grow_len_if_needed(end, alloc);
            self.free_list.set_range_used(@intCast(idx), @intCast(count));
            if (MEMSET_CLAIMED) |val| {
                @memset(self.ptr[idx .. idx + count], val);
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.memset_claimed != null) {
                const sec_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.memset_claimed));
                const sec_set = sec_ptr.*;
                @memset(self.ptr_2[idx .. idx + count], sec_set);
            }
            return ClaimedRange{
                .slice = (self.ptr + idx)[0..count],
                .start_idx = idx,
            };
        }

        pub fn release_one_ptr(self: *Pool, ptr: *const T) void {
            self.release_one(self.find_index_for_ptr(ptr));
        }
        pub fn release_one(self: *Pool, idx: IDX) void {
            assert_idx_less_than_len(idx, self.len, @src());
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
            assert_idx_with_count_in_bounds(idx, count, self.len, @src());
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
            assert_idx_with_count_in_bounds(idx, old_count, self.len, @src());
            const old_end = idx + old_count;
            if (new_count == old_count) return ClaimedRange{
                .slice = self.ptr[idx..old_end],
                .start_idx = idx,
            };

            if (new_count < old_count) {
                self.release_range(old_end, old_count - new_count);
                return ClaimedRange{
                    .slice = self.ptr[idx .. idx + new_count],
                    .start_idx = idx,
                };
            }
            const grow_count = new_count - old_count;
            if (self.free_list.has_n_consecutive_frees_at_idx(old_end, grow_count)) {
                self.free_list.set_range_used(old_end, grow_count);
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

pub fn SimplePoolOpaque(comptime IDX: type, comptime MEMSET_CLAIMED: ?[]const u8, comptime CLEAR_RELEASED: ?[]const u8, comptime SECONDARY_LIST: ?SecondaryListSettings) type {
    assert_with_reason(Types.type_is_unsigned_int(IDX), @src(), "type `IDX` must be an unsigned int type, got type `{s}`", .{@typeName(IDX)});
    const HAS_SECONDARY = SECONDARY_LIST != null;
    return extern struct {
        const Pool = @This();

        ptr: [*]u8 = @ptrCast(Utils.invalid_ptr_many(u8)),
        ptr_2: if (HAS_SECONDARY) [*]SECONDARY_LIST.?.elem_type else void = if (HAS_SECONDARY) @ptrCast(Utils.invalid_ptr_many(SECONDARY_LIST.?.elem_type)) else void{},
        free_list: FreeList = .{},
        len: IDX = 0,
        cap: IDX = 0,

        const SET: []const u8 = if (MEMSET_CLAIMED) |S| S else undefined;
        const CLEAR: []const u8 = if (CLEAR_RELEASED) |C| C else undefined;

        pub fn PoolTyped(comptime T: type) type {
            return SimplePool(T, IDX, if (MEMSET_CLAIMED != null) @as(*const T, @ptrCast(@alignCast(SET.ptr))).* else null, if (CLEAR_RELEASED != null) @as(*const T, @ptrCast(@alignCast(CLEAR.ptr))).* else null, SECONDARY_LIST);
        }
        pub fn ClaimedItemTyped(comptime T: type) type {
            return PoolTyped(T).ClaimedItem;
        }
        pub fn ClaimedRangeTyped(comptime T: type) type {
            return PoolTyped(T).ClaimedRange;
        }

        pub fn init_capacity(type_cap: usize, elem_size: usize, elem_align: usize, alloc: Allocator) Pool {
            const real_cap = type_cap * elem_size;
            var pool = Pool{
                .free_list = .init_capacity(type_cap, alloc),
            };
            smart_alloc_ptr_ptrs(alloc, &pool.ptr, &pool.cap, real_cap, .{ .align_mode = .custom_align(elem_align) }, .{});
            if (HAS_SECONDARY) {
                var dummy_cap: IDX = 0;
                smart_alloc_ptr_ptrs(alloc, &pool.ptr_2, &dummy_cap, real_cap, .{}, .{});
            }
            return pool;
        }
        pub fn free(self: *Pool, elem_size: usize, elem_align: usize, alloc: Allocator) void {
            var real_cap = self.cap * elem_size;
            smart_alloc_ptr_ptrs(alloc, &self.ptr, &real_cap, 0, .{ .align_mode = .custom_align(elem_align) }, .{});
            alloc.free(self.ptr[0..real_cap]);
            if (HAS_SECONDARY) {
                smart_alloc_ptr_ptrs(alloc, &self.ptr_2, &self.cap, 0, .{}, .{});
            }
            self.free_list.free_memory(alloc);
            self.* = undefined;
        }

        pub const ClaimedItem = struct {
            ptr: *u8,
            idx: IDX,
        };
        pub const ClaimedRange = struct {
            slice: []u8,
            start_idx: IDX,
        };

        pub fn opaque_elem_ptr(self: Pool, index: usize, elem_size: usize) [*]u8 {
            assert_idx_less_than_len(index, self.len, @src());
            const byte_index = index * elem_size;
            return self.ptr + byte_index;
        }
        pub fn opaque_elem_bytes(self: Pool, index: usize, elem_size: usize) []u8 {
            assert_idx_less_than_len(index, self.len, @src());
            const byte_index = index * elem_size;
            return (self.ptr + byte_index)[0..elem_size];
        }
        fn ensure_capacity(self: *Pool, cap: IDX, elem_size: usize, elem_align: usize, alloc: Allocator) void {
            if (self.cap >= cap) return;
            const real_cap = num_cast(self.cap, usize) * elem_size;
            const real_cap_new = num_cast(cap, usize) * elem_size;
            if (HAS_SECONDARY) {
                const new_mem_2 = smart_alloc(alloc, self.ptr_2[0..self.cap], @intCast(cap), .{}, .{});
                self.ptr_2 = new_mem_2.ptr;
            }
            const new_mem = smart_alloc(alloc, self.ptr[0..real_cap], @intCast(real_cap_new), .{ .align_mode = .custom_align(elem_align) }, .{});
            self.ptr = new_mem.ptr;
            self.cap = cap;
        }
        pub fn set_len(self: *Pool, len: IDX, elem_size: usize, elem_align: usize, alloc: Allocator) void {
            self.free_list.set_len(len, alloc);
            self.ensure_capacity(len, elem_size, elem_align, alloc);
            self.len = len;
        }
        pub fn grow_len_if_needed(self: *Pool, len: IDX, elem_size: usize, elem_align: usize, alloc: Allocator) void {
            if (self.len < len) {
                self.set_len(len, elem_size, elem_align, alloc);
            }
        }
        pub fn grow_len_if_needed_for_idx(self: *Pool, idx: IDX, elem_size: usize, elem_align: usize, alloc: Allocator) void {
            const len = idx + 1;
            if (self.len < len) {
                self.set_len(len, elem_size, elem_align, alloc);
            }
        }
        pub fn claim_one_specific(self: *Pool, idx: IDX, elem_size: usize, elem_align: usize, alloc: Allocator) ClaimedItem {
            assert_with_reason(idx >= self.free_list.free_bits.index_len or self.free_list.idx_is_free(@intCast(idx)), @src(), "index {d} was not free, cannot claim it", .{idx});
            const byte_idx = (idx * elem_size);
            self.grow_len_if_needed_for_idx(idx, elem_size, elem_align, alloc);
            if (MEMSET_CLAIMED) |bytes| {
                @memcpy(self.ptr[byte_idx..(byte_idx + bytes.len)], bytes);
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.memset_claimed != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.memset_claimed));
                self.ptr_2[idx] = t_ptr.*;
            }
            return ClaimedItem{
                .ptr = @ptrCast(self.ptr + byte_idx),
                .idx = idx,
            };
        }
        pub fn claim_one(self: *Pool, elem_size: usize, elem_align: usize, alloc: Allocator) ClaimedItem {
            if (self.free_list.find_1_free_and_set_used()) |new_idx| {
                return ClaimedItem{
                    .ptr = @ptrCast(self.ptr + (new_idx * elem_size)),
                    .idx = @intCast(new_idx),
                };
            }
            const new_idx = self.len;
            self.grow_len_if_needed_for_idx(new_idx, elem_size, elem_align, alloc);
            self.free_list.set_used(new_idx);
            const byte_idx = (new_idx * elem_size);
            if (MEMSET_CLAIMED) |bytes| {
                @memcpy(self.ptr[byte_idx..(byte_idx + bytes.len)], bytes);
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.memset_claimed != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.memset_claimed));
                self.ptr_2[new_idx] = t_ptr.*;
            }
            return ClaimedItem{
                .ptr = @ptrCast(self.ptr + byte_idx),
                .idx = new_idx,
            };
        }

        pub fn claim_range(self: *Pool, count: IDX, elem_size: usize, elem_align: usize, alloc: Allocator) ClaimedRange {
            if (self.free_list.find_range_free_and_set_used(@intCast(count))) |new_idx| {
                return ClaimedRange{
                    .slice = (self.ptr + (new_idx * elem_size))[0..(count * elem_size)],
                    .start_idx = new_idx,
                };
            }
            self.grow_len_if_needed(self.len + count, elem_size, elem_align, alloc);
            const new_idx = self.len;
            const byte_idx = new_idx * elem_size;
            if (MEMSET_CLAIMED) |bytes| {
                var offset = byte_idx;
                for (0..count) |_| {
                    @memset(self.ptr[offset .. offset + elem_size], bytes);
                    offset += elem_size;
                }
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.memset_claimed != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.memset_claimed));
                const t_set = t_ptr.*;
                @memset(self.ptr_2[new_idx .. new_idx + count], t_set);
            }
            return ClaimedRange{
                .slice = (self.ptr + byte_idx)[0..(count * elem_size)],
                .start_idx = new_idx,
            };
        }
        pub fn claim_range_specific(self: *Pool, idx: IDX, count: IDX, elem_size: usize, elem_align: usize, alloc: Allocator) ClaimedRange {
            assert_with_reason(idx >= self.free_list.free_bits.index_len or self.free_list.has_n_consecutive_frees_at_idx(@intCast(idx), @intCast(@min(count, self.len - idx))), @src(), "{d} indices starting from index {d} were not all free, cannot claim them", .{ count, idx });
            const end = idx + count;
            self.grow_len_if_needed(end, elem_size, elem_align, alloc);
            const byte_idx = idx * elem_size;
            if (MEMSET_CLAIMED) |bytes| {
                var offset = byte_idx;
                for (0..count) |_| {
                    @memset(self.ptr[offset .. offset + elem_size], bytes);
                    offset += elem_size;
                }
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.memset_claimed != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.memset_claimed));
                const t_set = t_ptr.*;
                @memset(self.ptr_2[idx .. idx + count], t_set);
            }
            return ClaimedRange{
                .slice = (self.ptr + byte_idx)[0..(count * elem_size)],
                .start_idx = idx,
            };
        }

        pub fn release_one(self: *Pool, index: usize, elem_size: usize) void {
            const byte_index = index * elem_size;
            assert_idx_less_than_len(index, self.len, @src());
            self.free_list.set_free(index);
            if (CLEAR_RELEASED) |bytes| {
                const elem_bytes = (self.ptr + byte_index)[0..elem_size];
                @memset(elem_bytes, bytes);
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.clear_released != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.clear_released));
                self.ptr_2[index] = t_ptr.*;
            }
        }

        pub fn release_range(self: *Pool, idx: IDX, count: IDX, elem_size: usize) void {
            assert_idx_with_count_in_bounds(idx, count, self.len, @src());
            self.free_list.set_range_free(@intCast(idx), @intCast(count));
            const byte_idx = num_cast(idx, usize) + elem_size;
            if (CLEAR_RELEASED) |bytes| {
                var offset = byte_idx;
                for (0..count) |_| {
                    @memset(self.ptr[offset .. offset + elem_size], bytes);
                    offset += elem_size;
                }
            }
            if (HAS_SECONDARY and SECONDARY_LIST.?.clear_released != null) {
                const t_ptr: *const SECONDARY_LIST.?.elem_type = @ptrCast(@alignCast(SECONDARY_LIST.?.clear_released));
                const t_set = t_ptr.*;
                @memset(self.ptr_2[idx .. idx + count], t_set);
            }
        }

        pub fn to_typed(self: Pool, comptime T: type) PoolTyped(T) {
            return @bitCast(self);
        }
        pub fn to_typed_ptr(self: *Pool, comptime T: type) *PoolTyped(T) {
            return @ptrCast(@alignCast(self));
        }
    };
}
