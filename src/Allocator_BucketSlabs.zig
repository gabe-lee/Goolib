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
const Allocator = mem.Allocator;
const Alignment = mem.Alignment;
const PageAllocator = std.heap.PageAllocator;
const List = Root.ListSlice.ListFullDefinition;
const BranchHint = std.builtin.BranchHint;
const Type = std.builtin.Type;
const PowerOf2 = Root.Math.PowerOf2;
const Types = Root.Types;
const Cast = Root.Cast;
const Log2Usize = math.Log2Int(usize);
const Utils = Root.Utils;

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_always_panic = Assert.assert_unreachable_always_panic;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Cast.num_cast;

pub const BackingAllocatorMode = enum {
    DIRECT_PAGE_ALLOCATE,
    USE_BACKING_ALLOCATOR,
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
    /// Whether to use the `std.heap.PageAllocator` class directly for the backing allocator,
    /// or to use a provided backing allocator interface.
    BACKING_ALLOCATOR_MODE: BackingAllocatorMode = BackingAllocatorMode.DIRECT_PAGE_ALLOCATE,
    /// Enable additional tracking for allocation usage.
    ///
    /// This option allows logging functions to report additional statistics,
    /// (or for the user to inspect the stats themselves). This adds a small amount of processing overhead to all
    /// allocation functions and increases the memory footprint of the allocator by around 3x
    /// (NOT incluing actual memory allocations, just 3x the metadata size).
    ///
    /// It provides no additional behavioral functionality or performance.
    TRACK_ALLOCATION_STATS: bool = false,
    /// If true, when attempting to resize from a larger bucket size to a smaller bucket size,
    /// the larger bucket will be binary sub-divided into a series of 'one-size-smaller' buckets starting from
    /// its end and the new sub-divided buckets will be added to their respective free lists
    /// until only one bucket of the specified smaller size exists in-place at the same original
    /// memory location.
    ///
    /// This setting reduces memory reallocs when shrinking memory, but also has the side-effect of
    /// slowly tending to decrease the total available larger bucket slots and increase the total
    /// available smaller bucket slots
    ALLOW_RESIZE_IN_PLACE_TO_SMALLER_BUCKET: bool = true,
};

pub const BucketDef = struct {
    /// The size of the memory region requested from the backing allocator when this bucket does not have
    /// any more blocks left. This size will then be divided into individual blocks and appended to this bucket
    /// free list.
    ///
    /// This value must follow the following rules:
    /// - SLAB_SIZE >= BUCKET_SIZE
    /// - SLAB_SIZE >= std.heap.page_size_min
    SLAB_SIZE: PowerOf2 = PowerOf2.STD_HEAP_MIN_PAGE_SIZE,
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
const SlabList = List([]u8, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, .MANUAL_ALLOC);

fn bucket_greater(slice: BucketSlice, idx_a: usize, val_b: BucketDef, _: void, comptime _: void) bool {
    return slice.get(idx_a).BUCKET_SIZE.greater_than(val_b.BUCKET_SIZE);
}

pub fn ComptimeAllocInfo(comptime N: usize) type {
    return struct {
        min_bucket_power: PowerOf2,
        max_bucket_power: PowerOf2,
        largest_blocks_per_slab: usize,
        ordered_block_sizes: [N]usize,
        ordered_slab_sizes: [N]usize,
        ordered_blocks_per_slab: [N]usize,
        ordered_slab_masks: [N]usize,
        ordered_leftover_blocks_after_new_alloc: [N]usize,
        num_buckets: usize,
        ordered_slab_alignments: [N]Alignment,
    };
}

fn eval_def(comptime DEF: Def) ComptimeAllocInfo(DEF.BUCKETS.len) {
    assert_with_reason(DEF.BUCKETS.len > 0, @src(), "must provide at least one allocation bucket", .{});
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
    comptime var ordered_slab_alignments: [DEF.BUCKETS.len]Alignment = undefined;
    comptime var largest_blocks_per_slab: usize = 0;
    for (ordered_bucket_defs, 0..) |def, i| {
        assert_with_reason(def.BUCKET_SIZE.less_than_or_equal(def.SLAB_SIZE), @src(), "BUCKET_SIZE ({d}) must be <= SLAB_SIZE ({d})", .{ def.BUCKET_SIZE.value(), def.SLAB_SIZE.value() });
        assert_with_reason(def.BUCKET_SIZE.greater_than_or_equal(PowerOf2.USIZE_BYTES), @src(), "BUCKET_SIZE ({d}) must be >= USIZE_BYTES ({d})", .{ def.BUCKET_SIZE.value(), PowerOf2.USIZE_BYTES.value() });
        assert_with_reason(def.SLAB_SIZE.greater_than_or_equal(PowerOf2.STD_HEAP_MIN_PAGE_SIZE), @src(), "SLAB_SIZE ({d}) must be >= std.heap.page_size_min ({d})", .{ def.SLAB_SIZE.value(), std.heap.page_size_min });
        min_bucket_power = min_bucket_power.min(def.BUCKET_SIZE);
        max_bucket_power = max_bucket_power.max(def.BUCKET_SIZE);
        const blocks_per_slab = def.SLAB_SIZE.divide_value(def.BUCKET_SIZE).value_as_type(usize);
        ordered_block_sizes[i] = def.BUCKET_SIZE.value_as_type(usize);
        ordered_slab_sizes[i] = def.SLAB_SIZE.value_as_type(usize);
        ordered_slab_masks[i] = def.SLAB_SIZE.value_as_type(usize) - 1;
        ordered_blocks_per_slab[i] = blocks_per_slab;
        largest_blocks_per_slab = @max(largest_blocks_per_slab, blocks_per_slab);
        ordered_leftover_blocks_after_new_alloc[i] = blocks_per_slab - 1;
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
        .largest_blocks_per_slab = largest_blocks_per_slab,
    };
}

pub fn BucketSlabAlloc(comptime DEF: Def) type {
    const INFO = eval_def(DEF);
    return struct {
        const Self = @This();

        first_free_block: [NUM_BUCKETS]?*FreeSlot = @splat(null),
        first_untouched_block: [NUM_BUCKETS]?[*]u8 = @splat(null),
        remaining_untouched_blocks: [NUM_BUCKETS]usize = @splat(0),
        slab_tracker_ptr: [*]SlabRecord = Utils.invalid_ptr_many(SlabRecord),
        slab_tracker_len: usize = 0,
        slab_tracker_cap: usize = 0,
        stats: if (TRACK_STATS) AllocStats else void = if (TRACK_STATS) AllocStats{} else {},
        back_alloc: if (BACKING_ALLOC) Allocator else void = if (BACKING_ALLOC) std.heap.page_allocator else {},

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
        const MIN_BUCKET_POWER = INFO.min_bucket_power;
        const MIN_BUCKET_SIZE = MIN_BUCKET_POWER.value_as_type(usize);
        const MIN_BUCKET_RAW = MIN_BUCKET_POWER.raw_int();
        const TRACK_STATS = DEF.TRACK_ALLOCATION_STATS;
        const RESIZE_SHRINK = DEF.ALLOW_RESIZE_IN_PLACE_TO_SMALLER_BUCKET;
        const BACKING_ALLOC = DEF.BACKING_ALLOCATOR_MODE == .USE_BACKING_ALLOCATOR;

        pub const AllocStats = struct {
            num_free_blocks: [NUM_BUCKETS]usize = @splat(0),
            current_total_memory_allocated: usize = 0,
            largest_total_memory_allocated: usize = 0,
            smallest_allocation_request_ever: usize = math.maxInt(usize),
            largest_allocation_request_ever: usize = 0,
            largest_allocation_request_by_bucket: [NUM_BUCKETS]usize = @splat(0),
            smallest_allocation_request_by_bucket: [NUM_BUCKETS]usize = @splat(math.maxInt(usize)),
            most_blocks_ever_used_by_bucket: [NUM_BUCKETS]usize = @splat(0),
            num_used_blocks: [NUM_BUCKETS]usize = @splat(0),
            most_slabs_ever_used_by_bucket: [NUM_BUCKETS]usize = @splat(0),
            current_slabs_used_by_bucket: [NUM_BUCKETS]usize = @splat(0),
            number_of_attempted_resizes_to_smaller_buckets_by_bucket: [NUM_BUCKETS]u64 = @splat(0),
            number_of_attempted_resizes_to_larger_buckets_by_bucket: [NUM_BUCKETS]u64 = @splat(0),
            largest_fallback_request_ever: usize = 0,
            smallest_fallback_request_ever: usize = math.maxInt(usize),
            largest_total_bytes_allocated_from_fallback: usize = 0,
            current_total_bytes_allocated_from_fallback: usize = 0,
            largest_number_of_fallback_allocations: usize = 0,
            current_number_of_fallback_allocations: usize = 0,
            largest_attempted_fallback_resize_delta_grow: usize = 0,
            largest_attempted_fallback_resize_delta_shrink: usize = 0,
        };

        const FreeSlot = struct {
            next_free: ?*FreeSlot = null,

            inline fn to_raw(self: *FreeSlot) [*]u8 {
                return @ptrCast(@alignCast(self));
            }
            inline fn from_raw(raw: [*]u8) *FreeSlot {
                return @ptrCast(@alignCast(raw));
            }

            comptime {
                assert_with_reason(@sizeOf(FreeSlot) == @sizeOf(usize), null, "`FreeSlot` was not `usize` sized, {d} != {d}", .{ @sizeOf(FreeSlot), @sizeOf(usize) });
            }
        };

        const SlabRecord = struct {
            memory: []u8,
            alignment: Alignment,
        };

        pub const VTABLE: Allocator.VTable = .{
            .alloc = alloc_impl,
            .resize = resize_impl,
            .remap = remap_impl,
            .free = free_impl,
        };

        pub inline fn init(back_alloc: if (BACKING_ALLOC) Allocator else void) Self {
            if (comptime BACKING_ALLOC) {
                return Self{ .back_alloc = back_alloc };
            } else {
                return Self{};
            }
        }

        pub inline fn allocator(self: *Self) Allocator {
            return Allocator{ .ptr = @ptrCast(@alignCast(self)), .vtable = &VTABLE };
        }

        pub fn deinit(self: *Self) void {
            for (self.slab_tracker_ptr[0..self.slab_tracker_len]) |slab| {
                self.backing_free(slab.memory, slab.alignment);
            }
            if (self.slab_tracker_cap > 0) {
                const tracker_memory = @as([*]u8, @ptrCast(self.slab_tracker_ptr))[0 .. self.slab_tracker_cap * @sizeOf(SlabRecord)];
                self.backing_free(tracker_memory, Alignment.fromByteUnits(@alignOf(SlabRecord)));
            }
            const back_alloc = self.back_alloc;
            if (comptime BACKING_ALLOC) {
                self.* = .{ .back_alloc = back_alloc };
            } else {
                self.* = .{};
            }
        }

        fn backing_alloc(self: *Self, len: usize, alignment: Alignment) ?[*]u8 {
            switch (comptime DEF.BACKING_ALLOCATOR_MODE) {
                .DIRECT_PAGE_ALLOCATE => {
                    return PageAllocator.map(len, alignment);
                },
                .USE_BACKING_ALLOCATOR => {
                    return self.back_alloc.rawAlloc(len, alignment, @returnAddress());
                },
            }
        }
        fn backing_realloc(self: *Self, memory: []u8, old_len: usize, new_cap: usize, alignment: Alignment) ?[*]u8 {
            switch (comptime DEF.BACKING_ALLOCATOR_MODE) {
                .DIRECT_PAGE_ALLOCATE => {
                    if (PageAllocator.realloc(memory, alignment, new_cap, true)) |new_mem| {
                        return new_mem;
                    }
                    if (PageAllocator.map(new_cap, alignment)) |new_mem| {
                        const copy_len = @min(old_len, new_cap);
                        @memcpy(new_mem[0..copy_len], memory[0..copy_len]);
                        PageAllocator.unmap(@alignCast(memory));
                        return new_mem;
                    }
                    return null;
                },
                .USE_BACKING_ALLOCATOR => {
                    if (self.back_alloc.rawResize(memory, alignment, new_cap, @returnAddress())) return memory.ptr;
                    if (self.back_alloc.rawRemap(memory, alignment, new_cap, @returnAddress())) |new_mem| {
                        return new_mem;
                    }
                    if (self.back_alloc.rawAlloc(new_cap, alignment, @returnAddress())) |new_mem| {
                        const copy_len = @min(old_len, new_cap);
                        @memcpy(new_mem[0..copy_len], memory[0..copy_len]);
                        self.back_alloc.rawFree(memory, alignment, @returnAddress());
                        return new_mem;
                    }
                    return null;
                },
            }
        }
        fn backing_free(self: *Self, memory: []u8, alignment: Alignment) void {
            switch (comptime DEF.BACKING_ALLOCATOR_MODE) {
                .DIRECT_PAGE_ALLOCATE => {
                    PageAllocator.unmap(@alignCast(memory));
                },
                .USE_BACKING_ALLOCATOR => {
                    self.back_alloc.rawFree(memory, alignment, @returnAddress());
                },
            }
        }

        inline fn bucket_index_from_size_align(size: usize, alignment: Alignment) u8 {
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

        fn alloc_impl(self_opaque: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            return self.alloc_internal(len, alignment);
        }
        pub inline fn alloc_types(self: *Self, comptime T: type, count: usize) ?[]T {
            const ptr = self.alloc_internal(@sizeOf(T) * count, Alignment.fromByteUnits(@alignOf(T))) orelse return null;
            const t_ptr: [*]T = @ptrCast(@alignCast(ptr));
            return t_ptr[0..count];
        }
        pub inline fn alloc_types_with_align(self: *Self, comptime T: type, count: usize, comptime alignment: Alignment) ?[]align(alignment.toByteUnits()) T {
            const ptr = self.alloc_internal(@sizeOf(T) * count, alignment) orelse return null;
            const t_ptr: [*]align(alignment.toByteUnits()) T = @ptrCast(@alignCast(ptr));
            return t_ptr[0..count];
        }
        pub inline fn alloc_bytes(self: *Self, size: usize) ?[]u8 {
            const ptr = self.alloc_internal(size, null) orelse return null;
            return ptr[0..size];
        }
        pub inline fn alloc_bytes_with_align(self: *Self, size: usize, comptime alignment: Alignment) ?[]align(alignment.toByteUnits()) u8 {
            const ptr: [*]align(alignment.toByteUnits()) u8 = @alignCast(self.alloc_internal(size, alignment) orelse return null);
            return ptr[0..size];
        }
        inline fn note_block_used(self: *Self, bucket_idx: usize) void {
            if (comptime TRACK_STATS) {
                self.stats.num_used_blocks[bucket_idx] += 1;
                self.stats.most_blocks_ever_used_by_bucket[bucket_idx] = @max(self.stats.most_blocks_ever_used_by_bucket[bucket_idx], self.stats.num_used_blocks[bucket_idx]);
                self.stats.current_total_memory_allocated += BLOCK_BYTES[bucket_idx];
                self.stats.largest_total_memory_allocated = @max(self.stats.largest_total_memory_allocated, self.stats.current_total_memory_allocated);
            }
        }
        fn alloc_internal(self: *Self, size: usize, alignment: ?Alignment) ?[*]u8 {
            const bucket_idx = if (alignment) |a| bucket_index_from_size_align(size, a) else bucket_index_from_size(size);
            if (comptime TRACK_STATS) {
                self.stats.smallest_allocation_request_ever = @min(self.stats.smallest_allocation_request_ever, size);
                self.stats.largest_allocation_request_ever = @max(self.stats.largest_allocation_request_ever, size);
            }
            if (bucket_idx < NUM_BUCKETS) {
                if (comptime TRACK_STATS) {
                    self.stats.largest_allocation_request_by_bucket[bucket_idx] = @max(self.stats.largest_allocation_request_by_bucket[bucket_idx], size);
                    self.stats.smallest_allocation_request_by_bucket[bucket_idx] = @min(self.stats.smallest_allocation_request_by_bucket[bucket_idx], size);
                }
                if (self.first_free_block[bucket_idx]) |free_slot| {
                    self.first_free_block[bucket_idx] = free_slot.next_free;
                    if (comptime TRACK_STATS) {
                        self.stats.num_free_blocks[bucket_idx] -= 1;
                    }
                    self.note_block_used(bucket_idx);
                    return free_slot.to_raw();
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
                    }
                    self.note_block_used(bucket_idx);
                    return block_ptr;
                }
                if (self.slab_tracker_len == self.slab_tracker_cap) {
                    const record_align = Alignment.fromByteUnits(@alignOf(SlabRecord));
                    const new_cap = if (self.slab_tracker_cap == 0) 16 else self.slab_tracker_cap * 2;
                    const new_bytes = new_cap * @sizeOf(SlabRecord);
                    const new_raw = if (self.slab_tracker_cap == 0) blk: {
                        break :blk self.backing_alloc(new_bytes, record_align) orelse return null;
                    } else blk: {
                        const old_bytes = self.slab_tracker_cap * @sizeOf(SlabRecord);
                        const old_raw = @as([*]u8, @ptrCast(self.slab_tracker_ptr))[0..old_bytes];
                        break :blk self.backing_realloc(old_raw, self.slab_tracker_len * @sizeOf(SlabRecord), new_bytes, record_align) orelse return null;
                    };
                    self.slab_tracker_ptr = @ptrCast(@alignCast(new_raw));
                    self.slab_tracker_cap = new_cap;
                }
                const block_size = BLOCK_BYTES[bucket_idx];
                const new_slab_ptr = self.backing_alloc(SLAB_BYTES[bucket_idx], SLAB_ALIGNS[bucket_idx]) orelse return null;
                self.slab_tracker_ptr[self.slab_tracker_len] = .{
                    .memory = new_slab_ptr[0..SLAB_BYTES[bucket_idx]],
                    .alignment = SLAB_ALIGNS[bucket_idx],
                };
                self.slab_tracker_len += 1;
                const leftover_blocks = LEFTOVER_BLOCKS_AFTER_NEW_SLAB_ALLOC[bucket_idx];
                self.remaining_untouched_blocks[bucket_idx] = leftover_blocks;
                self.first_untouched_block[bucket_idx] = if (leftover_blocks == 0) null else new_slab_ptr + block_size;
                if (comptime TRACK_STATS) {
                    self.stats.num_free_blocks[bucket_idx] += leftover_blocks;
                    self.stats.current_slabs_used_by_bucket[bucket_idx] += 1;
                    self.stats.most_slabs_ever_used_by_bucket[bucket_idx] = @max(self.stats.most_slabs_ever_used_by_bucket[bucket_idx], self.stats.current_slabs_used_by_bucket[bucket_idx]);
                }
                self.note_block_used(bucket_idx);
                return new_slab_ptr;
            }
            if (comptime TRACK_STATS) {
                self.stats.largest_fallback_request_ever = @max(self.stats.largest_fallback_request_ever, size);
                self.stats.smallest_fallback_request_ever = @min(self.stats.smallest_fallback_request_ever, size);
                self.stats.current_number_of_fallback_allocations += 1;
                self.stats.largest_number_of_fallback_allocations = @max(self.stats.largest_number_of_fallback_allocations, self.stats.current_number_of_fallback_allocations);
                self.stats.current_total_bytes_allocated_from_fallback += size;
                self.stats.largest_total_bytes_allocated_from_fallback = @max(self.stats.largest_total_bytes_allocated_from_fallback, self.stats.current_total_bytes_allocated_from_fallback);
                self.stats.current_total_memory_allocated += size;
                self.stats.largest_total_memory_allocated = @max(self.stats.largest_total_memory_allocated, self.stats.current_total_memory_allocated);
            }
            const ptr = self.backing_alloc(size, alignment orelse Alignment.@"1") orelse return null;
            return ptr;
        }

        fn resize_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            _ = ret_addr;
            return self.resize_internal(memory, new_len, alignment);
        }
        pub inline fn resize_types(self: *Self, comptime T: type, memory: []T, new_count: usize) bool {
            return self.resize_internal(@as([*]u8, @ptrCast(memory.ptr))[0 .. memory.len * @sizeOf(T)], new_count * @sizeOf(T), Alignment.fromByteUnits(@alignOf(T)));
        }
        pub inline fn resize_types_with_align(self: *Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, new_count: usize) bool {
            return self.resize_internal(@as([*]u8, @ptrCast(@alignCast(memory.ptr)))[0 .. memory.len * @sizeOf(T)], new_count * @sizeOf(T), alignment);
        }
        pub inline fn resize_bytes(self: *Self, memory: []u8, new_len: usize) bool {
            return self.resize_internal(memory, new_len, null);
        }
        pub inline fn resize_bytes_with_align(self: *Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, new_len: usize) bool {
            return self.resize_internal(@alignCast(memory), new_len, alignment);
        }
        fn resize_internal(self: *Self, memory: []u8, new_len: usize, alignment: ?Alignment) bool {
            const old_bucket, const new_bucket = get: {
                if (alignment) |a| break :get .{ bucket_index_from_size_align(memory.len, a), bucket_index_from_size_align(new_len, a) };
                break :get .{ bucket_index_from_size(memory.len), bucket_index_from_size(new_len) };
            };
            if (new_len == memory.len) {
                return true;
            }
            if (old_bucket >= NUM_BUCKETS or new_bucket >= NUM_BUCKETS) {
                return false;
            }
            if (comptime TRACK_STATS) {
                self.stats.largest_allocation_request_by_bucket[new_bucket] = @max(self.stats.largest_allocation_request_by_bucket[new_bucket], new_len);
                self.stats.smallest_allocation_request_by_bucket[new_bucket] = @min(self.stats.smallest_allocation_request_by_bucket[new_bucket], new_len);
            }
            if (old_bucket == new_bucket) {
                return true;
            }
            if (new_bucket < old_bucket) {
                if (comptime TRACK_STATS) {
                    self.stats.number_of_attempted_resizes_to_smaller_buckets_by_bucket[old_bucket] += 1;
                }
                if (comptime RESIZE_SHRINK) {
                    // Since (new_bucket + MIN_BUCKET_RAW) and (old_bucket + MIN_BUCKET_RAW) is the Log2 of their true sizes,
                    // subtracting the larger and the smaller yields the Log2 differance between them,
                    // Which is the number of times the bucket can be sub-divided into two smaller buckets
                    // one-size-smaller.
                    var num_subdivisions = old_bucket - new_bucket;
                    var subdiv_bucket = old_bucket;
                    var bucket_end: [*]u8 = memory.ptr + BLOCK_BYTES[old_bucket];
                    while (num_subdivisions > 0) {
                        num_subdivisions -= 1;
                        subdiv_bucket -= 1;
                        bucket_end -= BLOCK_BYTES[subdiv_bucket];
                        const old_first_free_in_bucket = self.first_free_block[subdiv_bucket];
                        const new_bucket_next_free_ptr: *FreeSlot = @ptrCast(@alignCast(bucket_end));
                        new_bucket_next_free_ptr.next_free = old_first_free_in_bucket;
                        self.first_free_block[subdiv_bucket] = new_bucket_next_free_ptr;
                        if (comptime TRACK_STATS) {
                            self.stats.num_free_blocks[subdiv_bucket] += 1;
                        }
                    }
                    if (comptime TRACK_STATS) {
                        self.stats.num_used_blocks[old_bucket] -= 1;
                        self.stats.num_used_blocks[new_bucket] += 1;
                        self.stats.most_blocks_ever_used_by_bucket[new_bucket] = @max(self.stats.most_blocks_ever_used_by_bucket[new_bucket], self.stats.num_used_blocks[new_bucket]);
                        self.stats.current_total_memory_allocated -= BLOCK_BYTES[old_bucket];
                        self.stats.current_total_memory_allocated += BLOCK_BYTES[new_bucket];
                    }
                    assert_with_reason_debug_only(bucket_end == memory.ptr + BLOCK_BYTES[new_bucket], @src(), "bucket shrink subdivision algorithm failed", .{});
                    return true;
                } else {
                    return false;
                }
            }
            if (comptime TRACK_STATS) {
                self.stats.number_of_attempted_resizes_to_larger_buckets_by_bucket[old_bucket] += 1;
            }
            return false;
        }

        fn remap_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            if (self.resize_internal(memory, new_len, alignment)) {
                return memory.ptr;
            }
            return null;
        }
        pub inline fn remap_bytes(self: *Self, memory: []u8, new_len: usize) ?[]u8 {
            if (self.resize_bytes(memory, new_len)) {
                return memory.ptr[0..new_len];
            }
            return null;
        }
        pub inline fn remap_bytes_with_align(self: *Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, new_len: usize) ?[]align(alignment.toByteUnits()) u8 {
            if (self.resize_bytes_with_align(alignment, memory, new_len)) {
                return memory.ptr[0..new_len];
            }
            return null;
        }
        pub fn remap_types(self: *Self, comptime T: type, memory: []T, new_count: usize) ?[]T {
            if (self.resize_types(T, memory, new_count)) {
                return memory.ptr[0..new_count];
            }
            return null;
        }
        pub fn remap_types_with_align(self: *Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, new_count: usize) ?[]align(alignment.toByteUnits()) T {
            if (self.resize_types_with_align(alignment, T, memory, new_count)) {
                return memory.ptr[0..new_count];
            }
            return null;
        }

        fn free_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            self.free_internal(memory, alignment);
        }

        pub inline fn free_types(self: *Self, comptime T: type, memory: []T) void {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len = memory.len * @sizeOf(T);
            self.free_internal(raw_ptr[0..raw_len], Alignment.fromByteUnits(@alignOf(T)));
        }
        pub inline fn free_types_with_align(self: *Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T) void {
            const raw_ptr: [*]u8 = @ptrCast(@alignCast(memory.ptr));
            const raw_len = memory.len * @sizeOf(T);
            self.free_internal(raw_ptr[0..raw_len], alignment);
        }
        pub inline fn free_bytes(self: *Self, memory: []u8) void {
            self.free_internal(memory, null);
        }
        pub inline fn free_bytes_with_align(self: *Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8) void {
            self.free_internal(@alignCast(memory), alignment);
        }
        fn free_internal(self: *Self, memory: []u8, alignment: ?Alignment) void {
            const bucket_idx = if (alignment) |a| bucket_index_from_size_align(memory.len, a) else bucket_index_from_size(memory.len);
            if (bucket_idx < NUM_BUCKETS) {
                const prev_first_free = self.first_free_block[bucket_idx];
                const this_ptr_as_free_block: *FreeSlot = @ptrCast(@alignCast(memory.ptr));
                this_ptr_as_free_block.next_free = prev_first_free;
                self.first_free_block[bucket_idx] = this_ptr_as_free_block;
                if (comptime TRACK_STATS) {
                    self.stats.num_free_blocks[bucket_idx] += 1;
                    self.stats.num_used_blocks[bucket_idx] -= 1;
                    self.stats.current_total_memory_allocated -= BLOCK_BYTES[bucket_idx];
                }
                return;
            }
            self.backing_free(memory, alignment orelse Alignment.@"1");
            if (comptime TRACK_STATS) {
                self.stats.current_number_of_fallback_allocations -= 1;
                self.stats.current_total_bytes_allocated_from_fallback -= memory.len;
                self.stats.current_total_memory_allocated -= memory.len;
            }
        }

        pub inline fn create_with_align(self: *Self, comptime T: type, comptime alignment: Alignment) ?*align(alignment.toByteUnits()) T {
            if (self.alloc_types_with_align(T, 1, alignment)) |slice| {
                return @ptrCast(slice.ptr);
            }
            return null;
        }
        pub inline fn create(self: *Self, comptime T: type) ?*T {
            if (self.alloc_types(T, 1)) |slice| {
                return @ptrCast(slice.ptr);
            }
            return null;
        }
        pub inline fn destroy_with_align(self: *Self, comptime alignment: Alignment, comptime T: type, ptr: *align(alignment.toByteUnits()) T) void {
            const slice = @as([*]align(alignment.toByteUnits()) T, @ptrCast(ptr))[0..1];
            self.free_types_with_align(alignment, T, slice);
        }
        pub inline fn destroy(self: *Self, comptime T: type, ptr: *T) void {
            const slice = @as([*]T, @ptrCast(ptr))[0..1];
            self.free_types(T, slice);
        }

        /// Formats a usage summary into `log_buffer` and emits it through `std.log.info`.
        ///
        /// `log_buffer` is scratch storage owned by the caller; it is cleared first and
        /// left holding the last report. Free-list lengths are counted directly, so the
        /// report works whether or not `TRACK_ALLOCATION_STATS` is enabled. The richer
        /// used/slab counters are only included when stats tracking is enabled.
        pub fn log_usage_statistics(
            self: *const Self,
            log_buffer: *std.ArrayList(u8),
            log_alloc: Allocator,
            comptime log_name: []const u8,
        ) void {
            log_buffer.clearRetainingCapacity();

            var total_slab_bytes: usize = 0;
            if (self.slab_tracker_len > 0) {
                for (self.slab_tracker_ptr[0..self.slab_tracker_len]) |slab| {
                    total_slab_bytes += slab.memory.len;
                }
            }

            log_buffer.print(
                log_alloc,
                "\n[BucketSlabAlloc] Usage Statistics ({s})\n" ++
                    "============================================================\n" ++
                    "Buckets: {d}\n" ++
                    "Backing: {s}\n" ++
                    "Slabs: {d}\n" ++
                    "Slab bytes: {d}\n\n" ++
                    "   BLOCK |  SLAB  | BLOCKS/SLAB | FREE LIST | UNTOUCHED | FREE BYTES\n" ++
                    "---------+--------+-------------+-----------+-----------+-----------\n",
                .{ log_name, NUM_BUCKETS, @tagName(DEF.BACKING_ALLOCATOR_MODE), self.slab_tracker_len, total_slab_bytes },
            ) catch @panic(LOG_FAIL_MSG);

            var total_free_list_blocks: usize = 0;
            var total_untouched_blocks: usize = 0;
            var total_free_bytes: usize = 0;
            var i: usize = 0;
            while (i < NUM_BUCKETS) : (i += 1) {
                var free_list_blocks: usize = 0;
                var next = self.first_free_block[i];
                while (next) |node| : (next = node.next_free) free_list_blocks += 1;

                const untouched_blocks = self.remaining_untouched_blocks[i];
                const free_blocks = free_list_blocks + untouched_blocks;
                const bucket_free_bytes = free_blocks * BLOCK_BYTES[i];

                total_free_list_blocks += free_list_blocks;
                total_untouched_blocks += untouched_blocks;
                total_free_bytes += bucket_free_bytes;

                log_buffer.print(log_alloc, "{d: >8} | {d: >6} | {d: >11} | {d: >9} | {d: >9} | {d: >10}\n", .{
                    BLOCK_BYTES[i],
                    SLAB_BYTES[i],
                    BLOCKS_PER_SLAB[i],
                    free_list_blocks,
                    untouched_blocks,
                    bucket_free_bytes,
                }) catch @panic(LOG_FAIL_MSG);
            }
            log_buffer.print(log_alloc, "\nFree-list blocks: {d}\nUntouched blocks: {d}\nFree bytes: {d}\n", .{
                total_free_list_blocks,
                total_untouched_blocks,
                total_free_bytes,
            }) catch @panic(LOG_FAIL_MSG);

            if (comptime TRACK_STATS) {
                log_buffer.print(
                    log_alloc,
                    "\nIn-use bytes: {d}\n" ++
                        "Peak in-use bytes: {d}\n" ++
                        "Smallest request: {d}\n" ++
                        "Largest request: {d}\n" ++
                        "\n   BLOCK | USED | MOST USED | SLABS | MOST SLABS | REQUEST RANGE  | SHRINKS | GROWS\n" ++
                        "---------+------+-----------+-------+------------+----------------+---------+-------\n",
                    .{
                        self.stats.current_total_memory_allocated,
                        self.stats.largest_total_memory_allocated,
                        stat_value_or_zero(self.stats.smallest_allocation_request_ever),
                        self.stats.largest_allocation_request_ever,
                    },
                ) catch @panic(LOG_FAIL_MSG);

                i = 0;
                while (i < NUM_BUCKETS) : (i += 1) {
                    log_buffer.print(log_alloc, "{d: >8} | {d: >4} | {d: >9} | {d: >5} | {d: >10} | {d: >6}..{d: <6} | {d: >7} | {d: >5}\n", .{
                        BLOCK_BYTES[i],
                        self.stats.num_used_blocks[i],
                        self.stats.most_blocks_ever_used_by_bucket[i],
                        self.stats.current_slabs_used_by_bucket[i],
                        self.stats.most_slabs_ever_used_by_bucket[i],
                        stat_value_or_zero(self.stats.smallest_allocation_request_by_bucket[i]),
                        self.stats.largest_allocation_request_by_bucket[i],
                        self.stats.number_of_attempted_resizes_to_smaller_buckets_by_bucket[i],
                        self.stats.number_of_attempted_resizes_to_larger_buckets_by_bucket[i],
                    }) catch @panic(LOG_FAIL_MSG);
                }

                log_buffer.print(
                    log_alloc,
                    "\nFallback allocations\n" ++
                        "--------------------\n" ++
                        "Current allocations: {d}\n" ++
                        "Peak allocations: {d}\n" ++
                        "Current bytes: {d}\n" ++
                        "Peak bytes: {d}\n" ++
                        "Smallest request: {d}\n" ++
                        "Largest request: {d}\n",
                    .{
                        self.stats.current_number_of_fallback_allocations,
                        self.stats.largest_number_of_fallback_allocations,
                        self.stats.current_total_bytes_allocated_from_fallback,
                        self.stats.largest_total_bytes_allocated_from_fallback,
                        stat_value_or_zero(self.stats.smallest_fallback_request_ever),
                        self.stats.largest_fallback_request_ever,
                    },
                ) catch @panic(LOG_FAIL_MSG);
            }

            std.log.info("{s}", .{log_buffer.items});
        }
    };
}

const LOG_FAIL_MSG = "failed to allocate memory for BucketSlabAlloc usage logging";

inline fn stat_value_or_zero(value: usize) usize {
    return if (value == math.maxInt(usize)) 0 else value;
}
