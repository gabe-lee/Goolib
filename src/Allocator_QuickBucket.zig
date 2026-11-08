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
const mem = std.mem;
const Allocator = mem.Allocator;
const Root = @import("./_root.zig");
const Math = Root.Math;
const PowerOf2 = Math.PowerOf2;
const Assert = Root.Assert;
const ListSliceModule = Root.ListSlice;
const Utils = Root.Utils;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

pub const Def = struct {
    LARGEST_BUCKET_SIZE: PowerOf2 = ._4_096,
    BACKING_BLOCK_SIZE: PowerOf2 = ._65_536,
    BACKING_META_BLOCK_SIZE: PowerOf2 = ._4_096,
};

pub fn QuickBucketAllocator(comptime DEF: Def) type {
    assert_with_reason(@backingInt(DEF.LARGEST_BUCKET_SIZE) >= @backingInt(PowerOf2._16), @src(), "`LARGEST_BUCKET_SIZE` ({d}) must be at least 16", .{DEF.LARGEST_BUCKET_SIZE.value()});
    assert_with_reason(@backingInt(DEF.LARGEST_BUCKET_SIZE) <= @backingInt(DEF.BACKING_BLOCK_SIZE), @src(), "`LARGEST_BUCKET_SIZE` ({d}) must be <= `BACKING_BLOCK_SIZE` ({d})", .{ DEF.LARGEST_BUCKET_SIZE.value(), DEF.BACKING_BLOCK_SIZE.value() });
    assert_with_reason(@backingInt(DEF.BACKING_META_BLOCK_SIZE) >= @backingInt(PowerOf2._16), @src(), "`BACKING_META_BLOCK_SIZE` ({d}) must be at least 16", .{DEF.BACKING_META_BLOCK_SIZE.value()});
    return struct {
        const Self = @This();

        pub const MIN_CLASS_POWER = PowerOf2.USIZE_BYTES;
        pub const MIN_CLASS_RAW = PowerOf2.USIZE_BYTES.raw_int_as(usize);
        pub const MIN_CLASS_SIZE = MIN_CLASS_POWER.value_as_type(usize);
        pub const MAX_CLASS_POWER = DEF.LARGEST_BUCKET_SIZE;
        pub const MAX_CLASS_RAW = MAX_CLASS_POWER.raw_int_as(usize);
        pub const MAX_CLASS_SIZE = MAX_CLASS_POWER.value_as_type(usize);
        pub const NUM_CLASSES = MAX_CLASS_POWER.raw_int() - MIN_CLASS_POWER.raw_int() + 1;
        pub const BACKING_BLOCK_POWER = DEF.BACKING_BLOCK_SIZE;
        pub const BACKING_BLOCK_SIZE = BACKING_BLOCK_POWER.value_as_type(usize);
        pub const META_BACKING_BLOCK_POWER = DEF.BACKING_META_BLOCK_SIZE;
        pub const META_BACKING_BLOCK_SIZE = META_BACKING_BLOCK_POWER.value_as_type(usize);
        pub const META_PTRS_PER_BLOCK: u32 = @intCast(META_BACKING_BLOCK_SIZE / @sizeOf([*]u8));
        pub const BACKING_BLOCK_ALIGN = MAX_CLASS_POWER.to_alloc_align();

        const FreeNode = struct {
            next: ?*FreeNode,
        };
        const BlockList = ListSliceModule.ListFullDefinition([]u8, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, .MANUAL_ALLOC);

        backing_alloc: Allocator = std.heap.page_allocator,
        free_lists: [NUM_CLASSES]?*FreeNode = @splat(null),
        remaining_block: ?[]u8 = null,
        allocated_blocks: BlockList = .{},

        pub fn init(backing: Allocator) Self {
            return .{
                .backing_alloc = backing,
            };
        }

        pub fn uninit(self: *Self) void {
            const back_alloc = self.backing_alloc;
            for (self.allocated_blocks.zig_slice_entire_const()) |block_ptr| {
                back_alloc.rawFree(block_ptr[0..BACKING_BLOCK_SIZE], BACKING_BLOCK_ALIGN, @returnAddress());
            }
            self.allocated_blocks.free_if_non_zero(back_alloc);
            self.* = .{ .backing_alloc = back_alloc };
        }

        inline fn bucket_index_size_align(byte_size: usize, alignment: usize) ?usize {
            const needed = @max(byte_size, alignment);
            if (needed > MAX_CLASS_SIZE) return null;
            const clamped = @max(needed, MIN_CLASS_SIZE);
            return std.math.log2_int_ceil(usize, clamped) - MIN_CLASS_RAW;
        }

        inline fn slot_size_for_bucket(bucket: usize) usize {
            return @as(usize, 1) << @intCast(bucket + MIN_CLASS_RAW);
        }

        pub fn alloc(self: *Self, comptime T: type, count: usize) ![]T {
            if (count == 0) return Utils.invalid_ptr_many(T)[0..0];
            const byte_size = std.math.mul(usize, @sizeOf(T), count) catch return error.OutOfMemory;
            const possible_class_bucket = bucket_index_size_align(byte_size, @alignOf(T));

            if (possible_class_bucket) |b| {
                const slot_size = slot_size_for_bucket(b);

                if (self.free_lists[b]) |node| {
                    self.free_lists[b] = node.next;
                    const ptr: [*]T = @ptrCast(@alignCast(node));
                    return ptr[0..count];
                }

                if (self.remaining_block == null or slot_size > self.remaining_block.?.len) {
                    if (self.allocated_blocks.get_unused_space() == 0) {
                        const new_cap = self.allocated_blocks.get_cap() + META_PTRS_PER_BLOCK;
                        try self.allocated_blocks.resize_capacity_exact_might_error(new_cap, self.backing_alloc);
                    }
                    const new_block_ptr = self.backing_alloc.rawAlloc(BACKING_BLOCK_SIZE, BACKING_BLOCK_ALIGN, @returnAddress()) orelse return error.OutOfMemory;
                    const new_block = new_block_ptr[0..BACKING_BLOCK_SIZE];
                    self.allocated_blocks.append_one_assume_cap(new_block);
                    self.remaining_block = new_block;
                }

                const raw_ptr = self.remaining_block.?.ptr;
                self.remaining_block.? = self.remaining_block.?[slot_size..];

                const ptr: [*]T = @ptrCast(@alignCast(raw_ptr));
                return ptr[0..count];
            }

            return self.backing_alloc.alloc(T, count);
        }
        pub inline fn alloc_no_err(self: *Self, comptime T: type, count: usize) []T {
            return self.alloc(T, count) catch |e| return assert_allocation_failure(@src(), T, count, e);
        }

        pub fn realloc(self: *Self, comptime T: type, slice: []T, new_count: usize) ![]T {
            if (new_count == 0) {
                self.free(T, slice);
                return Utils.invalid_ptr_many(T)[0..0];
            }
            if (slice.len == 0) return self.alloc(T, new_count);
            if (self.resize(T, slice, new_count)) return slice.ptr[0..new_count];
            const new_mem = try self.alloc(T, new_count);
            const copy_count = @min(new_mem.len, slice.len);
            @memcpy(new_mem[0..copy_count], slice[0..copy_count]);
            self.free(T, slice);
            return new_mem;
        }
        pub fn realloc_no_err(self: *Self, comptime T: type, slice: []T, new_count: usize) []T {
            return self.realloc(T, slice, new_count) catch |e| return assert_allocation_failure(@src(), T, new_count, e);
        }

        pub fn free(self: *Self, comptime T: type, slice: []T) void {
            if (slice.len == 0) return;
            const byte_size = slice.len * @sizeOf(T);
            const possible_class_bucket = bucket_index_size_align(byte_size, @alignOf(T));

            if (possible_class_bucket) |b| {
                if (self.remaining_block != null) {
                    const slot_size = slot_size_for_bucket(b);
                    const slot_end_addr = @intFromPtr(slice.ptr) + slot_size;
                    if (slot_end_addr == @intFromPtr(self.remaining_block.?.ptr)) {
                        self.remaining_block.?.ptr -= slot_size;
                        self.remaining_block.?.len += slot_size;
                        return;
                    }
                }
                const node: *FreeNode = @ptrCast(@alignCast(slice.ptr));
                node.next = self.free_lists[b];
                self.free_lists[b] = node;
                return;
            }

            self.backing_alloc.free(slice);
        }

        pub fn resize(self: *Self, comptime T: type, slice: []T, new_count: usize) bool {
            if (new_count == 0) {
                self.free(T, slice);
                return true;
            }
            if (slice.len == 0) return false;
            if (new_count == slice.len) return true;

            const old_bytes = slice.len * @sizeOf(T);
            const new_bytes = std.math.mul(usize, @sizeOf(T), new_count) catch return false;

            const old_bucket = bucket_index_size_align(old_bytes, @alignOf(T));
            const new_bucket = bucket_index_size_align(new_bytes, @alignOf(T));
            if (old_bucket == null or new_bucket == null) return false;

            const old_b = old_bucket.?;
            const new_b = new_bucket.?;
            if (old_b == new_b) return true;
            if (new_b < old_b) return false;

            const remaining = self.remaining_block orelse return false;
            const old_slot_size = slot_size_for_bucket(old_b);
            const new_slot_size = slot_size_for_bucket(new_b);
            const slot_end_addr = @intFromPtr(slice.ptr) + old_slot_size;
            if (slot_end_addr != @intFromPtr(remaining.ptr)) return false;
            const slot_size_byte_delta = new_slot_size - old_slot_size;
            if (slot_size_byte_delta > remaining.len) return false;
            self.remaining_block.? = remaining[slot_size_byte_delta..];
            return true;
        }
    };
}
