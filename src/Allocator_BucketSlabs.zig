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

const build = @import("builtin");
const std = @import("std");
const Root = @import("./_root.zig");
const Assert = Root.Assert;
const mem = std.mem;
const math = std.math;
const Allocator = std.mem.Allocator;
const PageAllocator = std.heap.PageAllocator;
const List = Root.ListSlice.ListFullDefinition;
const BranchHint = std.builtin.BranchHint;
const Type = std.builtin.Type;
const PowerOf2 = Root.Math.PowerOf2;
const Types = Root.Types;
const Cast = Root.Cast;
const Log2Usize = math.Log2Int(usize);

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_always_panic = Assert.assert_unreachable_always_panic;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Cast.num_cast;

pub const LargeAllocBehavior = enum {
    USE_PAGE_ALLOCATOR,
    PANIC,
    UNREACHABLE,
};

pub const Def = struct {
    /// A list of all allocation size buckets desired for this allocator. Any requested allocation will be
    /// sent to the smallest bucket that can hold it, and take exactly one single block from that bucket.
    ///
    /// This list MUST follow the following rules:
    /// - all buckets in sorted order from smallest block_size to largest block_size, with no gaps in sizes
    /// - all block sizes different
    /// - smallest block size is >= @sizeOf(usize)
    /// - all slab sizes >= their respective block sizes
    /// - all slab sizes >= std.heap.page_size_min
    BUCKETS: []const BucketDef,
    /// The unsigned integer type to use for indexing.
    ///
    /// This type places a maximum limit on how many total blocks any single bucket can have. A smaller integer type will save
    /// a small amount of memory footprint. Choosing `usize` is effectively the same as `unlimited` blocks, as
    /// the system will run out of address space long before it runs out of block indexes to use
    ///
    /// For most use cases, `u16` (65536 maximum blocks per bucket) or `u32` (4294967296 maximum blocks per bucket) are good choices
    INDEX_UINT_TYPE: type = u32,
    /// The unsigned integer type to use for block/slab sizes.
    ///
    /// This type places a maximum limit on the largest block/slab size. A smaller integer type will save
    /// a small amount of memory footprint. Choosing `usize` is effectively the same as `unlimited` block/slab size, as
    /// any block or slab size of the maximum value of `usize` would completely exhaust the system address space anyway
    ///
    /// For most use cases, `u16` (max block/slab size of 32 kilobytes) or `u32` (max block/slab size of 2 gigabytes) are good choices
    SIZE_UINT_TYPE: type = u32,
    /// If a requested allocation exceeds the maximum block size, how should this allocator respond
    ///
    /// the `.UNREACHABLE` option will slightly reduce the processing overhead of checking whether a
    /// requested allocation does or does not fall into the 'large' category and prevent branching
    LARGE_ALLOCATION_BEHAVIOR: LargeAllocBehavior = LargeAllocBehavior.USE_PAGE_ALLOCATOR,
    /// Enable additional tracking for allocation usage.
    ///
    /// This option allows logging functions to report additional statistics,
    /// (or for the user to inspect the stats themselves). This adds a moderate amount of processing overhead to all
    /// allocation functions and increases the memory footprint of the allocator by around 3x.
    ///
    /// It provides no additional behavioral functionality or performance.
    TRACK_ALLOCATION_STATS: bool = false,
};

pub const BucketDef = struct {
    /// The size of the memory region requested from the backing allocator when this bucket does not have
    /// any more blocks left. This size will then be divided into individual blocks and appended to this bucket
    /// free list.
    ///
    /// This value must follow the following rules:
    /// - SLAB_SIZE >= BUCKET_SIZE
    /// - SLAB_SIZE >= std.heap.page_size_min
    SLAB_SIZE: PowerOf2,
    /// The size of individiual memory blocks for this bucket. The slab_size is divided into individual blocks
    /// for this bucket to use, but it WILL NOT use multiple blocks for a single allocation.
    ///
    /// Instead an allocation larger than this will be sent to the next largest bucket that can hold the requested bytes.
    ///
    /// This value must follow the following rules:
    /// - BUCKET_SIZE is >= @sizeOf(usize)
    /// - BUCKET_SIZE is <= SLAB_SIZE
    BUCKET_SIZE: PowerOf2,
};

const BucketSlice = List(BucketDef, usize, .WHOLE_STRUCTS, .SERIAL_INDEXES, .REFERENCED_MUTABLE, .MANUAL_ALLOC);

fn bucket_greater(slice: BucketSlice, idx_a: usize, val_b: BucketDef, _: void, comptime _: void) bool {
    return slice.get(idx_a).BUCKET_SIZE.greater_than(val_b.BUCKET_SIZE);
}

pub fn ComptimeAllocInfo(comptime N: usize) type {
    return struct {
        min_bucket_power: PowerOf2,
        max_bucket_power: PowerOf2,
        ordered_block_sizes: [N]usize,
        ordered_slab_sizes: [N]usize,
        ordered_blocks_per_slab: [N]usize,
        ordered_slab_masks: [N]usize,
        ordered_leftover_blocks_after_new_alloc: [N]usize,
        num_buckets: usize,
        ordered_slab_alignments: [N]mem.Alignment,
    };
}

fn eval_def(comptime DEF: Def) ComptimeAllocInfo(DEF.BUCKETS.len) {
    assert_with_reason(DEF.BUCKETS.len > 0, @src(), "must provide at least one allocation bucket", .{});
    assert_with_reason(Types.type_is_unsigned_int(DEF.INDEX_UINT_TYPE), @src(), "`INDEX_UINT_TYPE` MUST be an unsigned integer, got type `{s}`", .{@typeName(DEF.INDEX_UINT_TYPE)});
    assert_with_reason(Types.type_is_unsigned_int(DEF.SIZE_UINT_TYPE), @src(), "`SIZE_UINT_TYPE` MUST be an unsigned integer, got type `{s}`", .{@typeName(DEF.SIZE_UINT_TYPE)});
    comptime var ordered_bucket_defs: [DEF.BUCKETS.len]BucketDef = undefined;
    @memcpy(ordered_bucket_defs[0..], DEF.BUCKETS);
    {
        const bucket_slice = BucketSlice.from_slice_keep_data(ordered_bucket_defs[0..]);
        bucket_slice.insertion_sort_advanced({}, {}, .COMPTIME_FN_BODY, {}, bucket_greater);
    }
    comptime var min_bucket_power: PowerOf2 = ._18_446_744_073_709_551_616;
    comptime var max_bucket_power: PowerOf2 = ._1;
    comptime var ordered_block_sizes: [DEF.BUCKETS.len]usize = undefined;
    comptime var ordered_slab_sizes: [DEF.BUCKETS.len]usize = undefined;
    comptime var ordered_blocks_per_slab: [DEF.BUCKETS.len]usize = undefined;
    comptime var ordered_slab_masks: [DEF.BUCKETS.len]usize = undefined;
    comptime var ordered_leftover_blocks_after_new_alloc: [DEF.BUCKETS.len]usize = undefined;
    comptime var ordered_slab_alignments: [DEF.BUCKETS.len]mem.Alignment = undefined;
    for (ordered_bucket_defs, 0..) |def, i| {
        assert_with_reason(def.BUCKET_SIZE.less_than_or_equal(def.SLAB_SIZE), "BUCKET_SIZE ({d}) mus be <= SLAB_SIZE ({d})", .{ def.BUCKET_SIZE.value(), def.SLAB_SIZE.value() });
        assert_with_reason(def.BUCKET_SIZE.greater_than_or_equal(PowerOf2.USIZE_BYTES), "BUCKET_SIZE ({d}) mus be >= USIZE_BYTES ({d})", .{ def.BUCKET_SIZE.value(), PowerOf2.USIZE_BYTES.value() });
        assert_with_reason(def.SLAB_SIZE.greater_than_or_equal(std.heap.page_size_min), "SLAB_SIZE ({d}) must be >= std.heap.page_size_min ({d})", .{ def.SLAB_SIZE.value(), std.heap.page_size_min });
        min_bucket_power = min_bucket_power.min(def.BUCKET_SIZE);
        max_bucket_power = max_bucket_power.max(def.BUCKET_SIZE);
        ordered_block_sizes[i] = def.BUCKET_SIZE.value();
        ordered_slab_sizes[i] = def.SLAB_SIZE.value();
        ordered_slab_masks[i] = def.SLAB_SIZE.value() - 1;
        ordered_blocks_per_slab[i] = def.SLAB_SIZE.divide_value(def.BUCKET_SIZE).value();
        ordered_leftover_blocks_after_new_alloc[i] = def.SLAB_SIZE.divide_value(def.BUCKET_SIZE).value() - 1;
        ordered_slab_alignments[i] = def.BUCKET_SIZE.to_alloc_align();
    }
    const num_buckets = max_bucket_power.raw_int() - min_bucket_power.raw_int() + 1;
    for (ordered_bucket_defs, 0..) |def, i| {
        assert_with_reason(def.BUCKET_SIZE.raw_int() - min_bucket_power.raw_int() == num_cast(i, u8), @src(), "buckets are not in order with no gaps: either there are gaps in bucket sizes, or there are duplicates of the same bucket size", .{});
    }
    assert_with_reason(num_cast(num_buckets, usize) == DEF.BUCKETS.len, @src(), "num buckets as calculated by power range ({d}) does not match the length of DEF.BUCKETS ({d})", .{ num_buckets, DEF.BUCKETS.len });
    return ComptimeAllocInfo(DEF.BUCKETS.len){
        .num_buckets = num_buckets,
        .max_bucket_power = max_bucket_power,
        .min_bucket_power = min_bucket_power,
        .ordered_block_sizes = ordered_block_sizes,
        .ordered_blocks_per_slab = ordered_blocks_per_slab,
        .ordered_leftover_blocks_after_new_alloc = ordered_leftover_blocks_after_new_alloc,
        .ordered_slab_masks = ordered_slab_masks,
        .ordered_slab_sizes = ordered_slab_sizes,
        .ordered_slab_alignments = ordered_slab_alignments,
    };
}

pub fn BucketSlabAlloc(comptime DEF: Def) type {
    const INFO = eval_def(DEF);
    return struct {
        const Self = @This();
        const Idx = DEF.INDEX_UINT_TYPE;

        first_free_block: [NUM_BUCKETS]?[*]u8 = @splat(0),
        first_untouched_block: [NUM_BUCKETS]?[*]u8 = @splat(0),
        remaining_untouched_blocks: [NUM_BUCKETS]DEF.INDEX_UINT_TYPE = @splat(0),
        stats: if (TRACK_STATS) AllocStats else void = if (TRACK_STATS) AllocStats{} else {},

        const NUM_BUCKETS = INFO.num_buckets;
        const BLOCK_BYTES = INFO.ordered_block_sizes;
        const SLAB_BYTES = INFO.ordered_slab_sizes;
        const SLAB_ALIGNS = INFO.ordered_slab_alignments;
        const SLAB_MASK = INFO.ordered_slab_masks;
        const BLOCKS_PER_SLAB = INFO.ordered_blocks_per_slab;
        const LEFTOVER_BLOCKS_AFTER_NEW_SLAB_ALLOC = INFO.ordered_leftover_blocks_after_new_alloc;
        const MAX_BUCKET_POWER = INFO.max_bucket_power;
        const MAX_BUCKET_SIZE = MAX_BUCKET_POWER.value_as_type(usize);
        const MAX_BUCKET_RAW = MAX_BUCKET_POWER.raw_int();
        const MIN_BUCKET_POWER = INFO.max_bucket_power;
        const MIN_BUCKET_SIZE = MIN_BUCKET_POWER.value_as_type(usize);
        const MIN_BUCKET_RAW = MIN_BUCKET_POWER.raw_int();
        const LARGE_ALLOC_BEHAVIOR = DEF.LARGE_ALLOCATION_BEHAVIOR;
        const LARGE_ALLOC: bool = LARGE_ALLOC_BEHAVIOR == .USE_PAGE_ALLOCATOR;
        const TRACK_STATS = DEF.TRACK_ALLOCATION_STATS;
        const MSG_LARGE_ALLOCATION = "Large allocation: largest bucket size is " ++ @tagName(MAX_BUCKET_POWER) ++ ", but the requested allocation would require a bucket size of {s}";
        const MSG_LARGE_RESIZE = "Large resize/remap: largest bucket size is " ++ @tagName(MAX_BUCKET_POWER) ++ ", but either the old memory allocation ({s}) or the new memory allocation ({s}) would exceed this limit";
        const MSG_LARGE_FREE = "Large free: largest bucket size is " ++ @tagName(MAX_BUCKET_POWER) ++ ", but the memory provided to free exceeds this limit: {s}";

        pub const AllocStats = struct {
            num_free_blocks: [NUM_BUCKETS]DEF.INDEX_UINT_TYPE = @splat(0),
            current_total_memory_allocated: usize = 0,
            largest_total_memory_allocated: usize = 0,
            smallest_allocation_request_ever: usize = math.maxInt(usize),
            largest_allocation_request_ever: usize = 0,
            largest_allocation_request_by_bucket: [NUM_BUCKETS]usize = @splat(0),
            smallest_allocation_request_by_bucket: [NUM_BUCKETS]usize = @splat(math.maxInt(usize)),
            most_blocks_ever_used_by_bucket: [NUM_BUCKETS]Idx = @splat(0),
            num_used_blocks: [NUM_BUCKETS]Idx = @splat(0),
            most_slabs_ever_used_by_bucket: [NUM_BUCKETS]Idx = @splat(0),
            current_slabs_used_by_bucket: [NUM_BUCKETS]Idx = @splat(0),
            number_of_attempted_resizes_to_larger_buckets_by_bucket: [NUM_BUCKETS]u64 = @splat(0),
            largest_page_allocator_fallback_request_ever: if (LARGE_ALLOC) usize else void = if (LARGE_ALLOC) 0 else {},
            smallest_page_allocator_fallback_request_ever: if (LARGE_ALLOC) usize else void = if (LARGE_ALLOC) math.maxInt(usize) else {},
            largest_total_bytes_allocated_from_page_allocator_fallback: if (LARGE_ALLOC) usize else void = if (LARGE_ALLOC) 0 else {},
            current_total_bytes_allocated_from_page_allocator_fallback: if (LARGE_ALLOC) usize else void = if (LARGE_ALLOC) 0 else {},
            largest_number_of_page_allocator_fallback_allocations: if (LARGE_ALLOC) usize else void = if (LARGE_ALLOC) 0 else {},
            current_number_of_page_allocator_fallback_allocations: if (LARGE_ALLOC) usize else void = if (LARGE_ALLOC) 0 else {},
            largest_attempted_page_allocator_fallback_resize_delta_grow: if (LARGE_ALLOC) usize else void = if (LARGE_ALLOC) 0 else {},
            largest_attempted_page_allocator_fallback_resize_delta_shrink: if (LARGE_ALLOC) usize else void = if (LARGE_ALLOC) 0 else {},
        };

        pub const VTABLE: Allocator.VTable = .{
            .alloc = alloc_impl,
            .resize = resize_impl,
            .remap = remap_impl,
            .free = free_impl,
        };

        pub inline fn allocator(self: *Self) Allocator {
            return Allocator{ .ptr = @ptrCast(@alignCast(self)), .vtable = &VTABLE };
        }

        inline fn bucket_index_from_size_align(size: usize, alignment: mem.Alignment) u8 {
            const clamped = @max(size, MIN_BUCKET_SIZE);
            const clamped_alignment = PowerOf2.from_alloc_align(alignment).max(MIN_BUCKET_POWER).raw_int();
            const biased_index_from_size = num_cast(std.math.log2_int_ceil(usize, clamped), u8) - MIN_BUCKET_RAW;
            const biased_index_from_align = clamped_alignment - MIN_BUCKET_RAW;
            return @max(biased_index_from_align, biased_index_from_size);
        }
        inline fn bucket_index_from_size(size: usize) u8 {
            const clamped = @max(size, MIN_BUCKET_SIZE);
            const biased_index_from_size = num_cast(std.math.log2_int_ceil(usize, clamped), u8) - MIN_BUCKET_RAW;
            return biased_index_from_size;
        }

        fn alloc_impl(self_opaque: *anyopaque, len: usize, alignment: mem.Alignment, ret_addr: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            const slice = self.alloc_bytes_advanced(len, alignment, ret_addr) orelse return null;
            return slice.ptr;
        }
        pub inline fn alloc_bytes(self: *Self, size: usize, alignment: mem.Alignment) ?[]u8 {
            self.alloc_bytes_advanced(size, alignment, @returnAddress());
        }
        pub inline fn alloc_type_advanced(self: *Self, comptime T: type, count: usize, alignment: mem.Alignment, ret_addr: usize) ?[]T {
            const slice = self.alloc_bytes_advanced(@sizeOf(T) * count, alignment, ret_addr) orelse return null;
            return @as([*]T, @ptrCast(@alignCast(slice.ptr)))[0..count];
        }
        pub inline fn alloc_type(self: *Self, comptime T: type, count: usize) ?[]T {
            const slice = self.alloc_bytes_advanced(@sizeOf(T) * count, mem.Alignment.fromByteUnits(@alignOf(T)), @returnAddress()) orelse return null;
            return @as([*]T, @ptrCast(@alignCast(slice.ptr)))[0..count];
        }
        pub fn alloc_bytes_advanced(self: *Self, size: usize, alignment: mem.Alignment, ret_addr: usize) ?[]u8 {
            _ = ret_addr;
            const bucket_idx = bucket_index_from_size_align(size, alignment);
            if (comptime TRACK_STATS) {
                self.stats.smallest_allocation_request_ever = @min(self.stats.smallest_allocation_request_ever, size);
                self.stats.largest_allocation_request_ever = @max(self.stats.largest_allocation_request_ever, size);
            }
            if (bucket_idx < NUM_BUCKETS) {
                if (comptime TRACK_STATS) {
                    self.stats.largest_allocation_request_by_bucket[bucket_idx] = @max(self.stats.largest_allocation_request_by_bucket[bucket_idx], size);
                    self.stats.smallest_allocation_request_by_bucket[bucket_idx] = @min(self.stats.smallest_allocation_request_by_bucket[bucket_idx], size);
                    self.stats.most_blocks_ever_used_by_bucket[bucket_idx] = @max(self.stats.most_blocks_ever_used_by_bucket[bucket_idx], self.stats.num_used_blocks[bucket_idx]);
                }
                if (self.first_free_block[bucket_idx]) |block_ptr| {
                    const next_free_block_ptr: *(?[*]u8) = @ptrCast(@alignCast(block_ptr));
                    self.first_free_block[bucket_idx] = next_free_block_ptr.*;
                    if (comptime TRACK_STATS) {
                        self.stats.num_free_blocks[bucket_idx] -= 1;
                        self.stats.num_used_blocks[bucket_idx] += 1;
                    }
                    return block_ptr[0..size];
                }
                if (self.first_untouched_block[bucket_idx]) |block_ptr| {
                    self.remaining_untouched_blocks[bucket_idx] -= 1;
                    if (self.remaining_untouched_blocks[bucket_idx] == 0) {
                        self.first_untouched_block[bucket_idx] = null;
                    } else {
                        self.first_untouched_block[bucket_idx] = block_ptr + BLOCK_BYTES[bucket_idx];
                    }
                    if (comptime TRACK_STATS) {
                        self.stats.num_free_blocks[bucket_idx] -= 1;
                        self.stats.num_used_blocks[bucket_idx] += 1;
                    }
                    return block_ptr[0..size];
                }
                const block_size = BLOCK_BYTES[bucket_idx];
                const new_slab_ptr = PageAllocator.map(SLAB_BYTES[bucket_idx], SLAB_ALIGNS[bucket_idx]) orelse return null;
                self.first_untouched_block[bucket_idx] = @intFromPtr(new_slab_ptr) + block_size;
                self.brand_new_block_count_by_bucket[bucket_idx] = LEFTOVER_BLOCKS_AFTER_NEW_SLAB_ALLOC[bucket_idx];
                if (comptime TRACK_STATS) {
                    self.stats.num_free_blocks[bucket_idx] += LEFTOVER_BLOCKS_AFTER_NEW_SLAB_ALLOC[bucket_idx];
                    self.stats.num_used_blocks[bucket_idx] += 1;
                    self.stats.current_slabs_used_by_bucket[bucket_idx] += 1;
                    self.stats.most_slabs_ever_used_by_bucket[bucket_idx] = @max(self.stats.most_slabs_ever_used_by_bucket[bucket_idx], self.stats.current_slabs_used_by_bucket[bucket_idx]);
                    self.stats.current_total_memory_allocated += SLAB_BYTES[bucket_idx];
                    self.stats.largest_total_memory_allocated = @max(self.stats.largest_total_memory_allocated, self.stats.current_total_memory_allocated);
                }
                return new_slab_ptr[0..size];
            }
            switch (LARGE_ALLOC_BEHAVIOR) {
                LargeAllocBehavior.USE_PAGE_ALLOCATOR => {
                    if (comptime TRACK_STATS) {
                        self.stats.largest_page_allocator_fallback_request_ever = @max(self.stats.largest_page_allocator_fallback_request_ever, size);
                        self.stats.smallest_page_allocator_fallback_request_ever = @min(self.stats.smallest_page_allocator_fallback_request_ever, size);
                        self.stats.current_number_of_page_allocator_fallback_allocations += 1;
                        self.stats.largest_number_of_page_allocator_fallback_allocations = @max(self.stats.largest_number_of_page_allocator_fallback_allocations, self.stats.current_number_of_page_allocator_fallback_allocations);
                        self.stats.current_total_bytes_allocated_from_page_allocator_fallback += size;
                        self.stats.largest_total_bytes_allocated_from_page_allocator_fallback = @max(self.stats.largest_total_bytes_allocated_from_page_allocator_fallback, self.stats.current_total_bytes_allocated_from_page_allocator_fallback);
                        self.stats.current_total_memory_allocated += size;
                        self.stats.largest_total_memory_allocated = @max(self.stats.largest_total_memory_allocated, self.stats.current_total_memory_allocated);
                    }
                    const ptr = PageAllocator.map(size, alignment) orelse return null;
                    return ptr[0..size];
                },
                LargeAllocBehavior.PANIC => assert_unreachable_always_panic(@src(), "Large allocation: largest bucket size is " ++ @tagName(MAX_BUCKET_POWER) ++ ", but the requested allocation would require a bucket size of {s}", .{@tagName(@as(PowerOf2, @fromBackingInt(bucket_idx + MIN_BUCKET_RAW)))}),
                LargeAllocBehavior.UNREACHABLE => assert_unreachable(@src(), "Large allocation: largest bucket size is " ++ @tagName(MAX_BUCKET_POWER) ++ ", but the requested allocation would require a bucket size of {s}", .{@tagName(@as(PowerOf2, @fromBackingInt(bucket_idx + MIN_BUCKET_RAW)))}),
            }
        }
        //CHECKPOINT
        fn resize_impl(self_opaque: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ret_addr: usize) bool {
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            const old_alloc_size_log2 = get_bytes_log2_with_align(memory.len, alignment);
            const new_alloc_size_log2 = get_bytes_log2_with_align(new_len, alignment);
            switch (LARGE_ALLOC_BEHAVIOR) {
                LargeAllocBehavior.USE_PAGE_ALLOCATOR => if (old_alloc_size_log2 > MAX_BUCKET_POWER or new_alloc_size_log2 > MAX_BUCKET_POWER) {
                    @branchHint(LARGE_ALLOC_HINT);
                    if (TRACK_STATS) {
                        if (old_alloc_size_log2 <= MAX_BUCKET_POWER and new_alloc_size_log2 > MAX_BUCKET_POWER) {
                            const old_bucket = ALLOC_SIZE_LOG2_TO_BUCKET_IDX[old_alloc_size_log2];
                            self.stats.number_of_attempted_resizes_to_larger_buckets_by_bucket[old_bucket] += 1;
                        } else if (old_alloc_size_log2 > MAX_BUCKET_POWER and new_alloc_size_log2 > MAX_BUCKET_POWER) {
                            if (new_len > memory.len) {
                                const delta = new_len - memory.len;
                                if (delta > self.stats.largest_attempted_page_allocator_fallback_resize_delta_grow) self.stats.largest_attempted_page_allocator_fallback_resize_delta_grow = delta;
                            }
                            if (new_len < memory.len) {
                                const delta = memory.len - new_len;
                                if (delta > self.stats.largest_attempted_page_allocator_fallback_resize_delta_shrink) self.stats.largest_attempted_page_allocator_fallback_resize_delta_shrink = delta;
                            }
                            if (new_len < self.stats.smallest_page_allocator_fallback_request_ever) self.stats.smallest_page_allocator_fallback_request_ever = new_len;
                            if (new_len > self.stats.largest_page_allocator_fallback_request_ever) self.stats.largest_page_allocator_fallback_request_ever = new_len;
                            const resize_result = PageAllocator.realloc(memory, new_len, false);
                            if (resize_result != null) {
                                if (new_len > memory.len) self.stats.current_total_memory_allocated += (new_len - memory.len);
                                if (new_len < memory.len) self.stats.current_total_memory_allocated -= (memory.len - new_len);
                            }
                            return resize_result != null;
                        }
                        return false;
                    }
                    if (old_alloc_size_log2 > MAX_BUCKET_POWER and new_alloc_size_log2 > MAX_BUCKET_POWER) return PageAllocator.realloc(memory, new_len, false) != null;
                    return false;
                },
                LargeAllocBehavior.PANIC => if (old_alloc_size_log2 > MAX_BUCKET_POWER or new_alloc_size_log2 > MAX_BUCKET_POWER) {
                    @branchHint(.cold);
                    std.debug.panic(MSG_LARGE_RESIZE, .{ AllocSize.get_name_from_bytes_log2(old_alloc_size_log2), AllocSize.get_name_from_bytes_log2(new_alloc_size_log2) });
                },
                LargeAllocBehavior.UNREACHABLE => if (old_alloc_size_log2 > MAX_BUCKET_POWER or new_alloc_size_log2 > MAX_BUCKET_POWER) unreachable,
            }
            const old_bucket = ALLOC_SIZE_LOG2_TO_BUCKET_IDX[old_alloc_size_log2];
            const new_bucket = ALLOC_SIZE_LOG2_TO_BUCKET_IDX[new_alloc_size_log2];
            if (TRACK_STATS) {
                if (old_bucket < new_bucket) self.stats.number_of_attempted_resizes_to_larger_buckets_by_bucket[old_bucket] += 1;
                if (old_bucket == new_bucket and new_len > self.stats.largest_allocation_request_by_bucket[old_bucket]) self.stats.largest_allocation_request_by_bucket[old_bucket] = new_len;
                if (old_bucket >= new_bucket and new_len < self.stats.smallest_allocation_request_by_bucket[old_bucket]) self.stats.smallest_allocation_request_by_bucket[old_bucket] = new_len;
            }
            return old_bucket >= new_bucket;
        }

        fn remap_impl(self_opaque: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            const old_alloc_size_log2 = get_bytes_log2_with_align(memory.len, alignment);
            const new_alloc_size_log2 = get_bytes_log2_with_align(new_len, alignment);
            switch (LARGE_ALLOC_BEHAVIOR) {
                LargeAllocBehavior.USE_PAGE_ALLOCATOR => if (old_alloc_size_log2 > MAX_BUCKET_POWER or new_alloc_size_log2 > MAX_BUCKET_POWER) {
                    @branchHint(LARGE_ALLOC_HINT);
                    if (TRACK_STATS) {
                        if (old_alloc_size_log2 <= MAX_BUCKET_POWER and new_alloc_size_log2 > MAX_BUCKET_POWER) {
                            const old_bucket = ALLOC_SIZE_LOG2_TO_BUCKET_IDX[old_alloc_size_log2];
                            self.stats.number_of_attempted_resizes_to_larger_buckets_by_bucket[old_bucket] += 1;
                        } else if (old_alloc_size_log2 > MAX_BUCKET_POWER and new_alloc_size_log2 > MAX_BUCKET_POWER) {
                            if (new_len > memory.len) {
                                const delta = new_len - memory.len;
                                if (delta > self.stats.largest_attempted_page_allocator_fallback_resize_delta_grow) self.stats.largest_attempted_page_allocator_fallback_resize_delta_grow = delta;
                            }
                            if (new_len < memory.len) {
                                const delta = memory.len - new_len;
                                if (delta > self.stats.largest_attempted_page_allocator_fallback_resize_delta_shrink) self.stats.largest_attempted_page_allocator_fallback_resize_delta_shrink = delta;
                            }
                            if (new_len < self.stats.smallest_page_allocator_fallback_request_ever) self.stats.smallest_page_allocator_fallback_request_ever = new_len;
                            if (new_len > self.stats.largest_page_allocator_fallback_request_ever) self.stats.largest_page_allocator_fallback_request_ever = new_len;
                            const resize_result = PageAllocator.realloc(memory, new_len, true);
                            if (resize_result != null) {
                                if (new_len > memory.len) self.stats.current_total_memory_allocated += (new_len - memory.len);
                                if (new_len < memory.len) self.stats.current_total_memory_allocated -= (memory.len - new_len);
                            }
                            return resize_result;
                        }
                        return null;
                    }
                    if (old_alloc_size_log2 > MAX_BUCKET_POWER and new_alloc_size_log2 > MAX_BUCKET_POWER) return PageAllocator.realloc(memory, new_len, true);
                    return null;
                },
                LargeAllocBehavior.PANIC => if (old_alloc_size_log2 > MAX_BUCKET_POWER or new_alloc_size_log2 > MAX_BUCKET_POWER) {
                    @branchHint(.cold);
                    std.debug.panic(MSG_LARGE_RESIZE, .{ AllocSize.get_name_from_bytes_log2(old_alloc_size_log2), AllocSize.get_name_from_bytes_log2(new_alloc_size_log2) });
                },
                LargeAllocBehavior.UNREACHABLE => if (old_alloc_size_log2 > MAX_BUCKET_POWER or new_alloc_size_log2 > MAX_BUCKET_POWER) unreachable,
            }
            const old_bucket = ALLOC_SIZE_LOG2_TO_BUCKET_IDX[old_alloc_size_log2];
            const new_bucket = ALLOC_SIZE_LOG2_TO_BUCKET_IDX[new_alloc_size_log2];
            if (TRACK_STATS) {
                if (old_bucket < new_bucket) self.stats.number_of_attempted_resizes_to_larger_buckets_by_bucket[old_bucket] += 1;
                if (old_bucket == new_bucket and new_len > self.stats.largest_allocation_request_by_bucket[old_bucket]) self.stats.largest_allocation_request_by_bucket[old_bucket] = new_len;
                if (old_bucket >= new_bucket and new_len < self.stats.smallest_allocation_request_by_bucket[old_bucket]) self.stats.smallest_allocation_request_by_bucket[old_bucket] = new_len;
            }
            if (old_bucket >= new_bucket) return memory.ptr;
            return null;
        }

        fn free_impl(self_opaque: *anyopaque, memory: []u8, alignment: mem.Alignment, ret_addr: usize) void {
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            const alloc_size_log2 = get_bytes_log2_with_align(memory.len, alignment);
            switch (LARGE_ALLOC_BEHAVIOR) {
                LargeAllocBehavior.USE_PAGE_ALLOCATOR => if (alloc_size_log2 > MAX_BUCKET_POWER) {
                    @branchHint(LARGE_ALLOC_HINT);
                    if (TRACK_STATS) {
                        self.stats.current_number_of_page_allocator_fallback_allocations -= 1;
                        self.stats.current_total_bytes_allocated_from_page_allocator_fallback -= memory.len;
                        self.stats.current_total_memory_allocated -= memory.len;
                    }
                    return PageAllocator.unmap(@alignCast(memory));
                },
                LargeAllocBehavior.PANIC => if (alloc_size_log2 > MAX_BUCKET_POWER) {
                    @branchHint(.cold);
                    std.debug.panic(MSG_LARGE_FREE, .{AllocSize.get_name_from_bytes_log2(alloc_size_log2)});
                },
                LargeAllocBehavior.UNREACHABLE => if (alloc_size_log2 > MAX_BUCKET_POWER) unreachable,
            }
            const bucket_idx = ALLOC_SIZE_LOG2_TO_BUCKET_IDX[alloc_size_log2];
            const prev_first_free_address = self.first_recycled_block_by_bucket[bucket_idx];
            const curr_first_free_addr: usize = @intFromPtr(memory.ptr);
            const curr_first_free_ptr: *usize = @ptrFromInt(curr_first_free_addr);
            curr_first_free_ptr.* = prev_first_free_address;
            self.first_recycled_block_by_bucket[bucket_idx] = curr_first_free_addr;
            self.recycled_block_count_by_bucket[bucket_idx] += 1;
            if (TRACK_STATS) {
                self.stats.num_used_blocks[bucket_idx] -= 1;
            }
        }

        // pub fn log_usage_statistics(self: *const QuickAlloc, log_buffer: *List(u8), log_alloc: Allocator, comptime log_name: []const u8) void {
        //     @branchHint(STAT_LOG_HINT);
        //     log_buffer.clearRetainingCapacity();
        //     var log_writer = log_buffer.writer();
        //     var i: usize = 0;
        //     log_writer.print("\n[QuickAlloc] Usage Statistics ({s})\n======== FREE MEMORY STATS =========\n   SIZE GROUP | FREE SLABS | FREE BLOCKS | FREE BYTES\n--------------+------------+-------------+--------------------------\n", .{log_name}) catch @panic(FAILED_TO_LOG ++ log_name);
        //     while (i < BUCKET_COUNT) : (i += 1) {
        //         const block_bytes_log_2: Log2Usize = BLOCK_BYTES_LOG2[i];
        //         const block_bytes: usize = BLOCK_BYTES[i];
        //         const block_count: usize = self.recycled_block_count_by_bucket[i] + self.brand_new_block_count_by_bucket[i];
        //         const bucket_slab_count = block_count / BLOCKS_PER_SLAB[i];
        //         log_writer.print("{s: >13} | {d: >10} | {d: >11} | {d: >19} bytes\n", .{ AllocSize.get_name_from_bytes_log2(block_bytes_log_2), bucket_slab_count, block_count, block_count * block_bytes }) catch @panic(FAILED_TO_LOG ++ log_name);
        //     }
        //     if (TRACK_STATS) {
        //         log_writer.print("======== USED MEMORY STATS =========\n", .{}) catch @panic("failed to allocate memory for logging: " ++ log_name);
        //         log_writer.print("Current total memory allocated: {d} bytes\nLargest total memory allocated: {d} bytes\n", .{ self.stats.current_total_memory_allocated, self.stats.largest_total_memory_allocated }) catch @panic(FAILED_TO_LOG ++ log_name);
        //         log_writer.print("Smallest allocation ever requested: {d} bytes\nLargest allocation ever requested: {d} bytes\n", .{ if (self.stats.smallest_allocation_request_ever == math.maxInt(usize)) 0 else self.stats.smallest_allocation_request_ever, self.stats.largest_allocation_request_ever }) catch @panic(FAILED_TO_LOG ++ log_name);
        //         log_writer.print("---- BUCKET STATS ----\n", .{}) catch @panic(FAILED_TO_LOG ++ log_name);
        //         i = 0;
        //         while (i < BUCKET_COUNT) : (i += 1) {
        //             const local_i = i;
        //             const block_bytes_log_2: Log2Usize = BLOCK_BYTES_LOG2[local_i];
        //             log_writer.print("  [{s}]\n", .{AllocSize.get_name_from_bytes_log2(block_bytes_log_2)}) catch @panic(FAILED_TO_LOG ++ log_name);
        //             log_writer.print("     Smallest single allocation: {d} bytes\n     Largest single allocation: {d} bytes\n", .{ if (self.stats.smallest_allocation_request_by_bucket[i] == math.maxInt(usize)) 0 else self.stats.smallest_allocation_request_by_bucket[i], self.stats.largest_allocation_request_by_bucket[i] }) catch @panic(FAILED_TO_LOG ++ log_name);
        //             log_writer.print("     Current blocks used by bucket: {d}\n     Most blocks ever used by bucket: {d}\n", .{ self.stats.current_blocks_used_by_bucket[i], self.stats.most_blocks_ever_used_by_bucket[i] }) catch @panic(FAILED_TO_LOG ++ log_name);
        //             log_writer.print("     Current slabs used by bucket: {d}\n     Most slabs ever used by bucket: {d}\n", .{ self.stats.current_slabs_used_by_bucket[i], self.stats.most_slabs_ever_used_by_bucket[i] }) catch @panic(FAILED_TO_LOG ++ log_name);
        //             log_writer.print("     Number of attempted resizes to larger buckets: {d}\n", .{self.stats.number_of_attempted_resizes_to_larger_buckets_by_bucket[i]}) catch @panic(FAILED_TO_LOG ++ log_name);
        //         }
        //         if (PAGE_ALLOC) {
        //             log_writer.print("  [Page Allocator]\n", .{}) catch @panic(FAILED_TO_LOG ++ log_name);
        //             log_writer.print("     Smallest single allocation: {d} bytes\n     Largest single allocation: {d} bytes\n", .{ if (self.stats.smallest_page_allocator_fallback_request_ever == math.maxInt(usize)) 0 else self.stats.smallest_page_allocator_fallback_request_ever, self.stats.largest_page_allocator_fallback_request_ever }) catch @panic(FAILED_TO_LOG ++ log_name);
        //             log_writer.print("     Current total bytes allocated: {d} bytes\n     Largest total bytes allocated: {d} bytes\n", .{ self.stats.current_total_bytes_allocated_from_page_allocator_fallback, self.stats.largest_total_bytes_allocated_from_page_allocator_fallback }) catch @panic(FAILED_TO_LOG ++ log_name);
        //             log_writer.print("     Current number of distinct allocations: {d}\n     Largest number of distinct allocations: {d}\n", .{ self.stats.current_number_of_page_allocator_fallback_allocations, self.stats.largest_number_of_page_allocator_fallback_allocations }) catch @panic(FAILED_TO_LOG ++ log_name);
        //             log_writer.print("     Largest attempted resize delta (grow): {d} bytes\n     Largest attempted resize delta (shrink): {d} bytes\n", .{ self.stats.largest_attempted_page_allocator_fallback_resize_delta_grow, self.stats.largest_attempted_page_allocator_fallback_resize_delta_shrink }) catch @panic(FAILED_TO_LOG ++ log_name);
        //         }
        //     }
        //     std.log.info("{s}", .{log_buffer.items[0..log_buffer.items.len]});
        // }
    };
}

const FAILED_TO_LOG = "failed to allocate memory for logging: ";

inline fn get_bytes_log2_with_align(len: usize, alignment: mem.Alignment) Log2Usize {
    const size_log2 = @max(@bitSizeOf(usize) - @clz(len - 1), @backingInt(alignment));
    return @intCast(size_log2);
}

inline fn get_bytes_log2(len: usize) Log2Usize {
    const size_log2 = @bitSizeOf(usize) - @clz(len - 1);
    return @intCast(size_log2);
}

inline fn bytes_log2_to_alignment(val: Log2Usize) mem.Alignment {
    return @fromBackingInt(@intCast(val));
}

//FIXME
// test "Does it basically work?" {
//     const t = std.testing;
//     const LOG = false; // set to `true` to log allocation data about this test
//     t.log_level = if (LOG) .info else .warn; // set to .info to log allocation data about this test
//     const ListU8 = List(u8);
//     var log_buffer = ListU8.init_empty(std.heap.page_allocator);
//     const ALLOC_OPTIONS = Options{
//         .buckets = &[_]BucketDef{
//             BucketDef{
//                 .block_size = ._128_B,
//                 .slab_size = ._4_KB,
//             },
//             BucketDef{
//                 .block_size = ._1_KB,
//                 .slab_size = ._16_KB,
//             },
//         },
//         .track_allocation_statistics = LOG,
//         .hint_log_usage_statistics = if (LOG) .VERY_LIKELY else .ALMOST_NEVER,
//         .large_allocation_behavior = .USE_PAGE_ALLOCATOR,
//         .hint_large_allocation = .VERY_LIKELY,
//     };
//     const ALLOC = define_allocator(ALLOC_OPTIONS);
//     var quick_alloc = ALLOC{};
//     const allocator = quick_alloc.allocator();
//     var text_list = ListU8.init(allocator);
//     try text_list.append('H');
//     try text_list.append('e');
//     try text_list.append('l');
//     try text_list.append('l');
//     try text_list.append('o');
//     try text_list.append(' ');
//     if (t.log_level == .info) quick_alloc.log_usage_statistics(&log_buffer, std.heap.page_allocator, "After append 'Hello ' = 6 total bytes of ListU8");
//     try text_list.appendSlice("World!");
//     if (t.log_level == .info) quick_alloc.log_usage_statistics(&log_buffer, std.heap.page_allocator, "After append 'World!' = 12 total bytes of ListU8");
//     try t.expectEqualStrings("Hello World!", text_list.items[0..text_list.items.len]);
//     try text_list.ensureTotalCapacity(129);
//     try t.expect(text_list.capacity >= 129);
//     try t.expectEqualStrings("Hello World!", text_list.items[0..text_list.items.len]);
//     if (t.log_level == .info) quick_alloc.log_usage_statistics(&log_buffer, std.heap.page_allocator, "After ensureTotalCapacity(129)");
//     text_list.clearAndFree();
//     if (t.log_level == .info) quick_alloc.log_usage_statistics(&log_buffer, std.heap.page_allocator, "After first clear and free");
//     try text_list.ensureTotalCapacity(1025);
//     try t.expect(text_list.capacity >= 1025);
//     if (t.log_level == .info) quick_alloc.log_usage_statistics(&log_buffer, std.heap.page_allocator, "After ensureTotalCapacity(1025)");
//     text_list.clearAndFree();
//     if (t.log_level == .info) quick_alloc.log_usage_statistics(&log_buffer, std.heap.page_allocator, "After second clear and free");
// }
