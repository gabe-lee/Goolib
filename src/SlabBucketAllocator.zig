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
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const Random = std.Random;

const Root = @import("./_root.zig");
const Types = Root.Types;
const Assert = Root.Assert;
const Fuzz = Root.Fuzz;
const IList = Root.IList;
const IListConcrete = IList.Concrete;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;
const testing = std.testing;
const Test = Root.Testing;
const Range = IListConcrete.Range;
const ListError = IListConcrete.ListError;
const GenericAllocator = Root.GenericAllocator.GenericAllocator;
const Alignment = Root.CommonTypes.Alignment;
const List = IList.List;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

const GROW_BUCKET_AMOUNT = 8;
const NO_ALLOC = void{};

pub const ThreadingMode = enum(u8) {
    single_threaded,
    multi_threaded,
};

pub const SBA_Definition = struct {
    THREADING_MODE: ThreadingMode = .single_threaded,
    BUCKET_COUNT: usize = 16,

    pub fn new(comptime THREADING_MODE: ThreadingMode, comptime BUCKET_COUNT: usize) SBA_Definition {
        return SBA_Definition{
            .THREADING_MODE = THREADING_MODE,
            .BUCKET_COUNT = BUCKET_COUNT,
        };
    }
};

const Bucket = struct {
    start: usize = 0,
    len: usize = 0,
    cap: usize = 0,
};
const Block = struct {
    start: usize = math.maxInt(usize),
    len: usize = 0,

    pub fn from_mem(mem: []u8) Block {
        return Block{
            .start = @intFromPtr(mem.ptr),
            .len = mem.len,
        };
    }
    pub fn to_mem(self: Block) []u8 {
        const ptr: [*]u8 = @ptrFromInt(self.start);
        return ptr[0..self.len];
    }
};
const Slab = struct {
    mem: []u8 = undefined,
    free_bytes: usize = 0,
    free_blocks: usize = 0,

    pub inline fn addr_start(self: Slab) usize {
        return @intFromPtr(self.mem.ptr);
    }
    pub inline fn addr_end_excl(self: Slab) usize {
        return @intFromPtr(self.mem.ptr) + self.mem.len;
    }
    pub inline fn fully_free(self: Slab) bool {
        return self.free_bytes == self.mem.len;
    }
    pub inline fn entire_block(self: Slab) Block {
        return Block{
            .start = self.addr_start(),
            .len = self.mem.len,
        };
    }
    pub inline fn has_one_block(self: Slab) bool {
        return self.free_blocks == 1;
    }
};

pub fn SimpleBucketAllocator(comptime _DEFINITION: SBA_Definition) type {
    return struct {
        const THREADING_MODE = _DEFINITION.THREADING_MODE;
        const SECURITY_MODE = _DEFINITION.SECURITY_MODE;
        const USE_MUTEX = THREADING_MODE == .multi_threaded;
        const BUCKET_COUNT = _DEFINITION.BUCKET_COUNT;
        const BUCKET_MAX_SIZES: [BUCKET_COUNT]usize = make: {
            var sizes: [BUCKET_COUNT]usize = undefined;
            for (0..BUCKET_COUNT) |i| {
                sizes[i] = (@as(usize, 1) << @intCast(i));
            }
            break :make sizes;
        };
        const Lock = if (USE_MUTEX) Mutex else void;
        pub const DEFINITION = _DEFINITION;
        const Self = @This();

        meta_alloc: Allocator,
        slabs: List(Slab),
        blocklist: List(Block),
        buckets: [BUCKET_COUNT]Bucket = @splat(Bucket{}),
        meta_lock: Lock = Lock{},

        pub fn init(meta_alloc: Allocator) Self {
            var self = Self{
                .meta_alloc = meta_alloc,
                .slabs = List(Slab).init_capacity(32, meta_alloc),
                .blocklist = List(Block).init_capacity(32, meta_alloc),
            };
            const first_mem = std.heap.page_allocator.alloc(u8, std.heap.pageSize()) catch |err| assert_allocation_failure(@src(), u8, std.heap.pageSize(), err);
            const first_block = Block.from_mem(first_mem);
            _ = self.slabs.append(Slab{ .mem = first_mem }, meta_alloc);
            self.release_data_block(first_block);
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.lock_meta();
            defer self.unlock_meta();
            for (self.slabs.slice()) |slab| {
                const block = slab.entire_block();
                const mem = block.to_mem();
                std.heap.page_allocator.free(mem);
            }
            self.buckets = @splat(Bucket{});
            self.blocklist.free(self.meta_alloc);
            self.slabs.free(self.meta_alloc);
        }

        inline fn lock_meta(self: *Self) void {
            if (USE_MUTEX) self.meta_lock.lock();
        }

        inline fn unlock_meta(self: *Self) void {
            if (USE_MUTEX) self.meta_lock.unlock();
        }

        fn impl_alloc(self_opq: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
            var self: *Self = @ptrCast(@alignCast(self_opq));
            const block = self.claim_data_block(len, alignment.toByteUnits());
            return @as([*]u8, @ptrFromInt(block.start));
        }
        fn impl_resize(self_opq: *anyopaque, mem: []u8, a: std.mem.Alignment, new_len: usize, _: usize) bool {
            if (new_len >= mem.len) return false;
            const block = Block.from_mem(mem);
            if (Alignment.from_address(block.start).to_usize() < a.toByteUnits()) return false;
            var self: *Self = @ptrCast(@alignCast(self_opq));
            const old_address: usize = @intFromPtr(mem.ptr);
            const freed_block = Block{
                .start = old_address + new_len,
                .len = mem.len - new_len,
            };
            self.release_data_block(freed_block);
            return true;
        }

        fn impl_remap(self_opq: *anyopaque, mem: []u8, a: std.mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
            if (new_len >= mem.len) return null;
            const block = Block.from_mem(mem);
            if (block_can_hold_size_with_align(block, new_len, a.toByteUnits())) |aligned_start| {
                var self: *Self = @ptrCast(@alignCast(self_opq));
                const new_block = self.trim_and_return_data_block_ends(block, aligned_start, new_len);
                return new_block.to_mem().ptr;
            } else {
                return null;
            }
        }

        fn impl_free(self_opq: *anyopaque, mem: []u8, _: std.mem.Alignment, _: usize) void {
            var self: *Self = @ptrCast(@alignCast(self_opq));
            const block = Block.from_mem(mem);
            self.release_data_block(block);
        }

        pub fn allocator(self: *Self) Allocator {
            return Allocator{
                .ptr = @ptrCast(self),
                .vtable = &Allocator.VTable{
                    .alloc = impl_alloc,
                    .resize = impl_resize,
                    .remap = impl_remap,
                    .free = impl_free,
                },
            };
        }

        fn find_slab_for_address(self: *Self, address: usize) usize {
            var hi: usize = self.slabs.len - 1;
            var lo: usize = 0;
            var slab: Slab = undefined;
            var s_start: usize = undefined;
            var s_end: usize = undefined;
            var idx: usize = undefined;
            while (true) {
                idx = ((hi - lo) >> 1) + lo;
                slab = self.slabs.ptr[idx];
                s_start = @intFromPtr(slab.mem.ptr);
                s_end = s_start + slab.mem.len;
                if (s_start <= address and address < s_end) {
                    return idx;
                }
                if (address < s_start) {
                    assert_with_reason(idx != lo, @src(), "address not found in ANY slabs, address = {d}, slabs = {any}", .{ address, self.slabs });
                    hi = idx - 1;
                } else {
                    assert_with_reason(idx != hi, @src(), "address not found in ANY slabs, address = {d}, slabs = {any}", .{ address, self.slabs });
                    lo = idx + 1;
                }
            }
        }

        fn remove_free_block_that_can_hold_size_at_align(self: *Self, size: usize, alignment: usize) ?Block {
            const bucket_idx = bucket_for_size(size);
            var block: Block = undefined;
            for (self.buckets[bucket_idx..]) |*bucket| {
                if (bucket.len == 0) continue;
                var b: usize = (bucket.len - 1);
                var i: usize = bucket.start + b;
                while (true) {
                    block = self.blocklist.ptr[i];
                    if (block_can_hold_size_with_align(block, size, alignment)) |aligned_start| {
                        const slab_idx = self.find_slab_for_address(block.start);
                        const slab: *Slab = &self.slabs.ptr[slab_idx];
                        Utils.mem_remove(self.blocklist.ptr + bucket.start, &bucket.len, @intCast(b), 1);
                        slab.free_blocks -= 1;
                        slab.free_bytes -= block.len;
                        const free_block = self.release_unused_portions_of_free_block_and_return_used_block_known_slab(slab, block, size, aligned_start);
                        return free_block;
                    }
                    if (i == bucket.start) break;
                    i -= 1;
                    b -= 1;
                }
            }
            return null;
        }

        fn block_can_hold_size_with_align(block: Block, size: usize, alignment: usize) ?usize {
            if (block.len < size) return null;
            const aligned_start = std.mem.alignForward(usize, block.start, alignment);
            const aligned_delta = aligned_start - block.start;
            if (block.len - aligned_delta < size) return null;
            return aligned_start;
        }

        fn release_unused_portions_of_free_block_and_return_used_block(self: *Self, block: Block, size: usize, aligned_start: usize) Block {
            const slab_idx = self.find_slab_for_address(block.start);
            const slab: *Slab = &self.slabs.ptr[slab_idx];
            return self.release_unused_portions_of_free_block_and_return_used_block_known_slab(slab, block, size, aligned_start);
        }

        fn release_unused_portions_of_free_block_and_return_used_block_known_slab(self: *Self, slab: *Slab, block: Block, size: usize, aligned_start: usize) Block {
            const block_before = Block{
                .start = block.start,
                .len = aligned_start - block.start,
            };
            const block_to_use = Block{
                .start = aligned_start,
                .len = size,
            };
            const block_after = Block{
                .start = aligned_start + size,
                .len = block.len - block_before.len - block_to_use.len,
            };
            self.push_free_block(slab, block_before);
            self.push_free_block(slab, block_after);
            return block_to_use;
        }

        fn push_free_block(self: *Self, slab: *Slab, block: Block) void {
            if (block.len == 0) return;
            const bucket_idx = bucket_for_size(@intCast(block.len));
            var bucket: *Bucket = &self.buckets[bucket_idx];
            const end = bucket.start + bucket.len;
            if (bucket.len == bucket.cap) {
                if (self.blocklist.cap == self.blocklist.len) {
                    const page_size = std.heap.pageSize();
                    const new_meta_cap = std.mem.alignForward(usize, Types.intcast(self.blocklist.cap, usize) + 1, page_size);
                    const new_meta: []Block = Utils.Alloc.realloc_no_memset(self.meta_alloc, self.blocklist.ptr[0..self.blocklist.cap], new_meta_cap) catch |err| assert_allocation_failure(@src(), Block, new_meta_cap, err);
                    self.blocklist.ptr = new_meta.ptr;
                    self.blocklist.cap = @intCast(new_meta.len);
                }
                const grow_amount = @min(self.blocklist.cap - self.blocklist.len, GROW_BUCKET_AMOUNT);
                Utils.mem_insert(self.blocklist.ptr, &self.blocklist.len, @intCast(end), grow_amount);
                bucket.cap += grow_amount;
                for (self.buckets[bucket_idx + 1 ..]) |*bucket_after| {
                    bucket_after.start += grow_amount;
                }
            }
            self.blocklist.ptr[end] = block;
            bucket.len += 1;
            slab.free_blocks += 1;
            slab.free_bytes += block.len;
        }

        fn split_new_free_block_for_size_and_align(free_block: Block, size: usize, alignment: usize) Block {
            const aligned_start = block_can_hold_size_with_align(free_block, size, alignment) orelse assert_unreachable(@src(), "a brand new block was allocated for size {d} align {d}, but the block was found to be unable to hold the needed space: {any}", .{ size, alignment, free_block });
            return release_unused_portions_of_free_block_and_return_used_block(free_block, size, aligned_start);
        }

        fn find_unused_slab_index(self: *Self) ?usize {
            for (self.slabs.ptr[0..self.slabs.len], 0..) |slab, i| {
                if (slab.fully_free()) return i;
            }
            return null;
        }

        fn block_is_in_slab(block: Block, slab: *Slab) Utils.FilterResult {
            var result = Utils.FilterResult{};
            result.is_true = slab.addr_start() <= block.start and block.start < slab.addr_end_excl();
            if (result.is_true) {
                slab.free_blocks -= 1;
            }
            if (slab.free_blocks == 0) {
                result.more_items = false;
            }
            return result;
        }

        fn remove_all_blocks_in_slab(self: *Self, slab: *Slab) void {
            for (self.buckets[0..]) |*bucket| {
                const block_slice_ptr = self.blocklist.ptr + bucket.start;
                Utils.mem_remove_sparse_by_filter_func(Block, block_slice_ptr, &bucket.len, 0, slab, block_is_in_slab);
            }
        }

        fn remove_known_single_block_in_slab(self: *Self, slab: *Slab, entire_block: Block) void {
            const bucket_idx = bucket_for_size(entire_block.len);
            var bucket: *Bucket = &self.buckets[bucket_idx];
            const block_slice_ptr = self.blocklist.ptr + bucket.start;
            Utils.mem_remove_sparse_by_filter_func(Block, block_slice_ptr, &bucket.len, 0, slab, block_is_in_slab);
        }

        fn slab_addr_greater(a: Slab, b: Slab) bool {
            return a.addr_start() > b.addr_start();
        }

        fn claim_data_block(self: *Self, size: usize, alignment: usize) Block {
            self.lock_meta();
            defer self.unlock_meta();
            if (remove_free_block_that_can_hold_size_at_align(self, size, alignment)) |claimed_block| {
                return claimed_block;
            } else {
                const page_size = std.heap.pageSize();
                if (self.find_unused_slab_index()) |slab_idx| {
                    var slab: *Slab = &self.slabs.ptr[slab_idx];
                    var block = slab.entire_block();
                    if (slab.has_one_block()) {
                        self.remove_known_single_block_in_slab(slab, block);
                    } else {
                        self.remove_all_blocks_in_slab(slab);
                    }
                    slab.free_blocks = 0;
                    slab.free_bytes = 0;
                    if (block_can_hold_size_with_align(block, size, alignment)) |aligned_start| {
                        const claimed_block = self.release_unused_portions_of_free_block_and_return_used_block_known_slab(slab, block, size, aligned_start);
                        return claimed_block;
                    } else {
                        const new_slab_size = std.mem.alignForward(usize, size + alignment, page_size);
                        var new_slab = Slab{};
                        new_slab.mem = Utils.Alloc.realloc_no_memset(std.heap.page_allocator, slab.mem, new_slab_size) catch |err| assert_allocation_failure(@src(), u8, new_slab_size, err);
                        const new_slab_idx = self.slabs.sorted_set_and_resort(slab_idx, new_slab, slab_addr_greater);
                        slab = &self.slabs.ptr[new_slab_idx];
                        block = slab.entire_block();
                        const aligned_start = block_can_hold_size_with_align(block, size, alignment) orelse {
                            assert_unreachable(@src(), "allocated at least size+align bytes, but resulting memory could not support an allocation of size {d} at align {d}", .{ size, alignment });
                        };
                        const claimed_block = self.release_unused_portions_of_free_block_and_return_used_block_known_slab(slab, block, size, aligned_start);
                        return claimed_block;
                    }
                } else {
                    const new_slab_size = std.mem.alignForward(usize, size + alignment, page_size);
                    const slot = self.slabs.append_slots(1, self.meta_alloc).first_idx;
                    const mem = std.heap.page_allocator.alloc(u8, new_slab_size) catch |err| assert_allocation_failure(@src(), u8, new_slab_size, err);
                    const new_slab = Slab{
                        .mem = mem,
                    };
                    const slab_idx = self.slabs.sorted_set_and_resort(slot, new_slab, slab_addr_greater);
                    const slab: *Slab = &self.slabs.ptr[slab_idx];
                    const block = slab.entire_block();
                    const aligned_start = block_can_hold_size_with_align(block, size, alignment) orelse {
                        assert_unreachable(@src(), "allocated at least size+align bytes, but resulting memory could not support an allocation of size {d} at align {d}", .{ size, alignment });
                    };
                    const claimed_block = self.release_unused_portions_of_free_block_and_return_used_block_known_slab(slab, block, size, aligned_start);
                    return claimed_block;
                }
            }
        }

        fn release_data_block(self: *Self, block: Block) void {
            if (block.len == 0) return;
            self.lock_meta();
            defer self.unlock_meta();
            const slab_idx = self.find_slab_for_address(block.start);
            const slab: *Slab = &self.slabs.ptr[slab_idx];
            self.push_free_block(slab, block);
        }

        fn trim_and_return_data_block_ends(self: *Self, old_block: Block, aligned_start: usize, size: usize) Block {
            if (old_block.len == 0) return Block{};
            if (size == 0) {
                self.release_data_block(old_block);
                return Block{};
            }
            self.lock_meta();
            defer self.unlock_meta();
            return self.release_unused_portions_of_free_block_and_return_used_block(old_block, size, aligned_start);
        }

        fn recombine_free_blocks(self: *Self) void {
            //FIXME this doesnt work right somewhere...
            self.lock_meta();
            defer self.unlock_meta();
            const real_len = self.init_all_uninit_blocks_to_max_start_and_return_real_len();
            self.insertion_sort_blocks_by_start();
            self.blocklist.len = @intCast(real_len);
            const delta = self.combine_adjacent_free_blocks_and_return_len_delta();
            self.blocklist.len -= @intCast(delta);
            self.insertion_sort_blocks_by_size();
            self.reindex_all_buckets();
            // Debug.check_buckets_and_blocks(self, @src()); //DEBUG
        }

        fn init_all_uninit_blocks_to_max_start_and_return_real_len(self: *Self) usize {
            var real_len: usize = 0;
            for (self.buckets[0..]) |*bucket| {
                const end = bucket.start + bucket.len;
                const cap = bucket.start + bucket.cap;
                real_len += bucket.len;
                @memset(self.blocklist.ptr[end..cap], Block{ .start = math.maxInt(usize), .len = 0 });
            }
            return real_len;
        }

        fn insertion_sort_blocks_by_start(self: *Self) void {
            if (self.blocklist.len < 2) return;
            var i: usize = 1;
            var j: usize = undefined;
            var jj: usize = undefined;
            var x: Block = undefined;
            while (i < self.blocklist.len) {
                x = self.blocklist.ptr[i];
                j = i;
                inner: while (j > 0) {
                    jj = j - 1;
                    if (self.blocklist.ptr[jj].start > x.start) {
                        self.blocklist.ptr[j] = self.blocklist.ptr[jj];
                        j -= 1;
                    } else {
                        break :inner;
                    }
                }
                self.blocklist.ptr[j] = x;
                i += 1;
            }
        }
        fn insertion_sort_blocks_by_size(self: *Self) void {
            if (self.blocklist.len < 2) return;
            var i: usize = 1;
            var j: usize = undefined;
            var jj: usize = undefined;
            var x: Block = undefined;
            while (i < self.blocklist.len) {
                x = self.blocklist.ptr[i];
                j = i;
                inner: while (j > 0) {
                    jj = j - 1;
                    if (self.blocklist.ptr[jj].len > x.len) {
                        self.blocklist.ptr[j] = self.blocklist.ptr[jj];
                        j -= 1;
                    } else {
                        break :inner;
                    }
                }
                self.blocklist.ptr[j] = x;
                i += 1;
            }
        }

        fn combine_adjacent_free_blocks_and_return_len_delta(self: *Self) usize {
            if (self.blocklist.len < 2) return 0;
            var delta: usize = 0;
            var check_idx: usize = 1;
            var combine_idx: usize = 0;
            var dont_combine_idx: usize = 1;
            while (check_idx < self.blocklist.len) {
                const check_block = self.blocklist.ptr[check_idx];
                const combine_block = self.blocklist.ptr[combine_idx];
                const combine_end = combine_block.start + combine_block.len;
                const check_slab = self.find_slab_for_address(check_block.start);
                const combine_slab = self.find_slab_for_address(combine_block.start);
                if (combine_end == check_block.start and check_slab == combine_slab) {
                    self.blocklist.ptr[combine_idx].len += check_block.len;
                    check_idx += 1;
                    delta += 1;
                } else {
                    self.blocklist.ptr[dont_combine_idx] = check_block;
                    check_idx += 1;
                    dont_combine_idx += 1;
                    combine_idx += 1;
                }
            }
            return delta;
        }

        fn reindex_all_buckets(self: *Self) void {
            var start: usize = 0;
            var bucket: usize = 0;
            var max: usize = BUCKET_MAX_SIZES[bucket];
            var end: usize = 0;
            var len: usize = 0;
            var size: usize = undefined;
            while (end < self.blocklist.len) {
                size = self.blocklist.ptr[end].len;
                if (size <= max) {
                    end += 1;
                    len += 1;
                } else {
                    self.buckets[bucket].start = start;
                    self.buckets[bucket].len = len;
                    self.buckets[bucket].cap = len;
                    start = end;
                    len = 0;
                    bucket += 1;
                    max = BUCKET_MAX_SIZES[bucket];
                }
            }
        }

        fn bucket_for_size(size: usize) usize {
            assert_with_reason(size != 0, @src(), "size cannot be 0", .{});
            const log2 = @bitSizeOf(usize) - @clz(size);
            const add_one = @as(usize, @intCast(@intFromBool(log2 > 0)));
            const bucket_idx = (log2 >> 1) + add_one;
            return bucket_idx;
        }

        pub const Debug = struct {
            pub fn print_bucket_usage(self: *Self) void {
                std.debug.print("SBA ALLOCATOR BUCKET USAGE:\nSIZE   BLOCKS_FREE BYTES_FREE\n", .{});
                var bk: usize = 0;
                var bb: usize = 0;
                for (self.buckets[0..], 0..) |b, i| {
                    const size = @as(usize, 1) << @intCast(i);
                    bk += b.len;
                    var kk: usize = 0;
                    for (self.blocklist.ptr[b.start .. b.start + b.len]) |k| {
                        kk += k.len;
                    }
                    bb += kk;
                    std.debug.print("{d: >6} {d: >11} {d: >10}\n", .{ size, b.len, kk });
                }
                std.debug.print(".....................................\n", .{});
                std.debug.print("       {d: >11} {d: >10}\n", .{ bk, bb });
                var st: usize = 0;
                var sk: usize = 0;
                var sb: usize = 0;
                std.debug.print("SBA ALLOCATOR SLAB USAGE:\nTOTAL_SIZE BLOCKS_FREE BYTES_FREE\n", .{});
                for (self.slabs.slice()) |s| {
                    st += s.mem.len;
                    sk += s.free_blocks;
                    sb += s.free_bytes;
                    std.debug.print("{d: >10} {d: >11} {d: >10}\n", .{ s.mem.len, s.free_blocks, s.free_bytes });
                }
                std.debug.print(".....................................\n", .{});
                std.debug.print("{d: >10} {d: >11} {d: >10}\n", .{ st, sk, sb });
            }
            const NeedLock = enum(u8) {
                no_locks_needed,
                lock_meta,
                lock_data,
                lock_data_and_meta,
            };
            const BlockAndLen = struct {
                blocks: usize = 0,
                len: usize = 0,
            };
            pub fn check_buckets_and_blocks(self: *Self, comptime src: std.builtin.SourceLocation) void {
                var slab_size_list: List(BlockAndLen) = List(BlockAndLen).init_capacity(self.slabs.len, self.meta_alloc);
                defer slab_size_list.free(self.meta_alloc);
                slab_size_list.len = self.slabs.len;
                @memset(slab_size_list.slice(), BlockAndLen{});
                for (self.buckets[0..], 0..) |bucket, b| {
                    const bidx: u6 = @intCast(b);
                    assert_with_reason(bucket.len <= bucket.cap, src, "bucket {d} has a len greater than its cap, bucket = {any}, index = {d}, size = {d}", .{ bidx, bucket, b, (@as(usize, 1) << (bidx << 1)) - 1 });
                    const bucket_end = Types.intcast(bucket.start, usize) + Types.intcast(bucket.len, usize);
                    assert_with_reason(bucket_end <= self.blocklist.len, src, "a free bucket has a range outside the blocklist.len, bucket = {any},  blocklist.len = {d}", .{ bucket, self.blocklist.len });
                    for (self.blocklist.ptr[bucket.start .. bucket.start + bucket.len], 0..) |block, bb| {
                        const bbidx: usize = @intCast(bb);
                        const slab_idx = self.find_slab_for_address(block.start);
                        const slab = self.slabs.ptr[slab_idx];
                        const block_end = Types.intcast(block.start, usize) + Types.intcast(block.len, usize);
                        slab_size_list.ptr[slab_idx].len += block.len;
                        slab_size_list.ptr[slab_idx].blocks += 1;
                        const slab_end = slab.addr_end_excl();
                        assert_with_reason(block_end <= slab_end, src, "a free block has a range outside its slab len, bucket = {d}, bucket size = {d}, bucket block idx = {d}, true block idx = {d}, block = {any}, slab_end = {d}", .{ bidx, (@as(usize, 1) << (bidx)), bbidx, bbidx + bucket.start, block, slab_end });
                    }
                }
                for (self.slabs.slice(), slab_size_list.slice(), 0..) |slab, reported, i| {
                    assert_with_reason(slab.free_bytes == reported.len, src, "the total number of free bytes found assigned to slab {d} did not match: from debug check = {d}, in slab = {d}", .{ i, slab.free_bytes, reported.len });
                    assert_with_reason(slab.free_blocks == reported.blocks, src, "the total number of free blocks found assigned to slab {d} did not match: from debug check = {d}, in slab = {d}", .{ i, slab.free_blocks, reported.blocks });
                }
            }
            const LARGEST_FUZZ_LEN = 4096;
            const SMALL_FUZZ_LEN = 256;
            const MICRO_FUZZ_LEN = 16;
            const LARGEST_FUZZ_COPY = 128;
            pub fn make_two_list_test() Fuzz.FuzzTest {
                const PROTO = struct {
                    pub const STATE = struct {
                        ref_list_8: std.ArrayList(u8),
                        ref_list_32: std.ArrayList(u32),
                        test_list_8: std.ArrayList(u8),
                        test_list_32: std.ArrayList(u32),
                        this_alloc_concrete: Self,
                        this_alloc: Allocator,
                    };
                    pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
                        var state = try alloc.create(STATE);
                        state.this_alloc_concrete = Self.init(alloc);
                        state.this_alloc = state.this_alloc_concrete.allocator();
                        state.ref_list_8 = try std.ArrayList(u8).initCapacity(alloc, LARGEST_FUZZ_LEN);
                        state.ref_list_32 = try std.ArrayList(u32).initCapacity(alloc, LARGEST_FUZZ_LEN);
                        state.test_list_8 = try std.ArrayList(u8).initCapacity(state.this_alloc, MICRO_FUZZ_LEN);
                        state.test_list_32 = try std.ArrayList(u32).initCapacity(state.this_alloc, MICRO_FUZZ_LEN);
                        state_opaque.* = @ptrCast(state);
                    }

                    pub fn START_SEED(_: Random, state_opaque: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                        var state: *STATE = @ptrCast(@alignCast(state_opaque));
                        state.ref_list_8.clearRetainingCapacity();
                        state.ref_list_32.clearRetainingCapacity();
                        state.test_list_8.clearAndFree(state.this_alloc);
                        state.test_list_32.clearAndFree(state.this_alloc);
                        state.test_list_8 = std.ArrayList(u8).initCapacity(state.this_alloc, MICRO_FUZZ_LEN) catch unreachable;
                        state.test_list_32 = std.ArrayList(u32).initCapacity(state.this_alloc, MICRO_FUZZ_LEN) catch unreachable;
                        return verify_whole_state(state, "start_seed", alloc);
                    }

                    pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
                        const state: *STATE = @ptrCast(@alignCast(state_opaque));
                        state.ref_list_8.clearAndFree(alloc);
                        state.ref_list_32.clearAndFree(alloc);
                        state.test_list_8.clearAndFree(state.this_alloc);
                        state.test_list_32.clearAndFree(state.this_alloc);
                        // print_bucket_usage(&state.this_alloc_concrete);
                        // state.this_alloc_concrete.recombine_free_blocks();
                        // print_bucket_usage(&state.this_alloc_concrete);
                        state.this_alloc_concrete.deinit();
                        alloc.destroy(state);
                    }

                    pub fn verify_whole_state(state: *STATE, comptime op_name: []const u8, alloc: Allocator) ?[]const u8 {
                        const u8Align = Alignment.from_pointer(state.test_list_8.items.ptr);
                        if (u8Align.to_usize() < 1) {
                            return Utils.alloc_fail_str(alloc, @src(), "{s}: u8 test list did not have a pointer alignment of 1, got alignment {s}", .{ op_name, @tagName(u8Align) });
                        }
                        if (state.ref_list_8.items.len != state.test_list_8.items.len) {
                            return Utils.alloc_fail_str(alloc, @src(), "{s}: in u8 lists, ref list len {d} != test list len {d}", .{ op_name, state.ref_list_8.items.len, state.test_list_8.items.len });
                        }
                        for (state.ref_list_8.items, state.test_list_8.items, 0..) |r, t, i| {
                            if (r != t) return Utils.alloc_fail_str(alloc, @src(), "{s}: in u8 lists at index {d}, ref list val {d} != test list val {d}", .{ op_name, i, r, t });
                            // if (t == 0xAA) return Utils.alloc_fail_str(alloc, @src(), "{s}: in u8 lists at index {d}, test list contained forbidden byte 0xAA, indicating the allocator has freed that byte", .{ op_name, i });
                        }
                        const u32Align = Alignment.from_pointer(state.test_list_32.items.ptr);
                        if (u32Align.to_usize() < 4) {
                            return Utils.alloc_fail_str(alloc, @src(), "{s}: u32 test list did not have a pointer alignment of 4, got alignment {s}", .{ op_name, @tagName(u32Align) });
                        }
                        if (state.ref_list_32.items.len != state.test_list_32.items.len) {
                            return Utils.alloc_fail_str(alloc, @src(), "{s}: in u32 lists, ref list len {d} != test list len {d}", .{ op_name, state.ref_list_32.items.len, state.test_list_32.items.len });
                        }
                        for (state.ref_list_32.items, state.test_list_32.items, 0..) |r, t, i| {
                            if (r != t) return Utils.alloc_fail_str(alloc, @src(), "{s}: in u32 lists at index {d}, ref list val {d} != test list val {d}", .{ op_name, i, r, t });
                            // const as_bytes: [4]u8 = @bitCast(t);
                            // for (as_bytes[0..]) |tt| {
                            //     if (tt == 0xAA) return Utils.alloc_fail_str(alloc, @src(), "{s}: in u32 lists at index {d}, test list contained forbidden byte 0xAA, indicating the allocator has freed that byte", .{ op_name, i });
                            // }
                        }
                        var slab_size_list: List(BlockAndLen) = List(BlockAndLen).init_capacity(state.this_alloc_concrete.slabs.len, state.this_alloc_concrete.meta_alloc);
                        defer slab_size_list.free(state.this_alloc_concrete.meta_alloc);
                        slab_size_list.len = state.this_alloc_concrete.slabs.len;
                        @memset(slab_size_list.slice(), BlockAndLen{});
                        for (state.this_alloc_concrete.buckets[0..], 0..) |bucket, b| {
                            const bidx: u6 = @intCast(b);
                            if (bucket.len > bucket.cap) {
                                return Utils.alloc_fail_str(alloc, @src(), "{s}, bucket {d} has a len greater than its cap, bucket = {any}, index = {d}, size = {d}", .{ op_name, bidx, bucket, b, (@as(usize, 1) << (bidx << 1)) - 1 });
                            }
                            const bucket_end = Types.intcast(bucket.start, usize) + Types.intcast(bucket.len, usize);
                            if (bucket_end > state.this_alloc_concrete.blocklist.len) {
                                return Utils.alloc_fail_str(alloc, @src(), "{s}, a free bucket has a range outside the blocklist.len, bucket = {any},  blocklist.len = {d}", .{ op_name, bucket, state.this_alloc_concrete.blocklist.len });
                            }
                            for (state.this_alloc_concrete.blocklist.ptr[bucket.start .. bucket.start + bucket.len], 0..) |block, bb| {
                                const bbidx: usize = @intCast(bb);
                                const slab_idx = state.this_alloc_concrete.find_slab_for_address(block.start);
                                const slab = state.this_alloc_concrete.slabs.ptr[slab_idx];
                                const block_end = Types.intcast(block.start, usize) + Types.intcast(block.len, usize);
                                // const mem = block.to_mem();
                                // for (mem, 0..) |m, mm| {
                                //     if (m != 0xAA) return Utils.alloc_fail_str(alloc, @src(), "{s}: in free bucket {d}, free block {d}, index {d}, the memory contained a byte that WASNT byte 0xAA (got {d}), indicating the allocator has freed memory that is still in use", .{ op_name, b, bb, mm, m });
                                // }
                                slab_size_list.ptr[slab_idx].len += block.len;
                                slab_size_list.ptr[slab_idx].blocks += 1;
                                if (block.start < slab.addr_start()) {
                                    return Utils.alloc_fail_str(alloc, @src(), "{s}, a free block has a start before its slab start, bucket = {d}, bucket size = {d}, bucket block idx = {d}, true block idx = {d}, block = {any}, slab_start = {d}", .{ op_name, bidx, (@as(usize, 1) << (bidx)), bbidx, bbidx + bucket.start, block, slab.addr_start() });
                                }
                                const slab_end = slab.addr_end_excl();
                                if (block_end > slab_end) {
                                    return Utils.alloc_fail_str(alloc, @src(), "{s}, a free block has a range outside its slab len, bucket = {d}, bucket size = {d}, bucket block idx = {d}, true block idx = {d}, block = {any}, slab_end = {d}", .{ op_name, bidx, (@as(usize, 1) << (bidx)), bbidx, bbidx + bucket.start, block, slab_end });
                                }
                            }
                        }
                        for (state.this_alloc_concrete.slabs.slice(), slab_size_list.slice(), 0..) |slab, reported, i| {
                            if (slab.free_bytes != reported.len) {
                                return Utils.alloc_fail_str(alloc, @src(), "{s}, the total number of free bytes found assigned to slab {d} did not match: from debug check = {d}, in slab = {d}", .{ op_name, i, slab.free_bytes, reported.len });
                            }
                            if (slab.free_blocks != reported.blocks) {
                                return Utils.alloc_fail_str(alloc, @src(), "{s}, the total number of free blocks found assigned to slab {d} did not match: from debug check = {d}, in slab = {d}", .{ op_name, i, slab.free_blocks, reported.blocks });
                            }
                        }
                        return null;
                    }

                    pub fn append_u8_force_realloc(rand: Random, state_opq: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                        const state: *STATE = @ptrCast(@alignCast(state_opq));
                        if (state.test_list_8.items.len >= LARGEST_FUZZ_LEN) return null;
                        const space_to_grow = LARGEST_FUZZ_LEN - state.test_list_8.items.len;
                        const n_to_force_realloc = @min(space_to_grow, rand.uintAtMost(usize, state.test_list_8.items.len) + 1);
                        const new_ref = state.ref_list_8.addManyAsSlice(alloc, n_to_force_realloc) catch unreachable;
                        // const old_test = state.test_list_8.items.ptr[0..state.test_list_8.capacity];
                        const new_test = state.test_list_8.addManyAsSlice(state.this_alloc, n_to_force_realloc) catch unreachable;
                        // Utils.secure_memset(u8, old_test, 0xAA);
                        rand.bytes(new_ref);
                        // Utils.replace_key_value_in_buffer(u8, new_ref, 0xAA, 0x11);
                        @memcpy(new_test, new_ref);
                        return verify_whole_state(state, "Append_U8_ForceRealloc", alloc);
                    }

                    pub fn append_u32_force_realloc(rand: Random, state_opq: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                        const state: *STATE = @ptrCast(@alignCast(state_opq));
                        if (state.test_list_32.items.len >= LARGEST_FUZZ_LEN) return null;
                        const space_to_grow = LARGEST_FUZZ_LEN - state.test_list_32.items.len;
                        const n_to_force_realloc = @min(space_to_grow, rand.uintAtMost(usize, state.test_list_32.items.len) + 1);
                        const new_ref = state.ref_list_32.addManyAsSlice(alloc, n_to_force_realloc) catch unreachable;
                        // const old_test = state.test_list_32.items.ptr[0..state.test_list_32.capacity];
                        const new_test = state.test_list_32.addManyAsSlice(state.this_alloc, n_to_force_realloc) catch unreachable;
                        // const old_test_as_bytes: []u8 = @as([*]u8, @ptrCast(old_test.ptr))[0 .. old_test.len * 4];
                        // Utils.secure_memset(u8, old_test_as_bytes, 0xAA);
                        const new_ref_as_bytes: []u8 = @as([*]u8, @ptrCast(new_ref.ptr))[0 .. new_ref.len * 4];
                        const new_test_as_bytes: []u8 = @as([*]u8, @ptrCast(new_test.ptr))[0 .. new_test.len * 4];
                        rand.bytes(new_ref_as_bytes);
                        // Utils.replace_key_value_in_buffer(u8, new_ref_as_bytes, 0xAA, 0x11);
                        @memcpy(new_test_as_bytes, new_ref_as_bytes);
                        return verify_whole_state(state, "Append_U32_ForceRealloc", alloc);
                    }

                    pub fn trim_u8_force_shrink(rand: Random, state_opq: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                        const state: *STATE = @ptrCast(@alignCast(state_opq));
                        if (state.test_list_8.items.len <= 0) return null;
                        const n_to_force_realloc = rand.uintLessThan(usize, state.test_list_8.items.len);
                        state.ref_list_8.items.len = n_to_force_realloc;
                        const old_mem = state.test_list_8.items.ptr[0..state.test_list_8.capacity];
                        // const dropped_portion = old_mem[n_to_force_realloc..];
                        // Utils.secure_memset(u8, dropped_portion, 0xAA);
                        const new_mem = Utils.Alloc.realloc_no_memset(state.this_alloc, old_mem, n_to_force_realloc) catch unreachable;
                        state.test_list_8.items.ptr = new_mem.ptr;
                        state.test_list_8.items.len = n_to_force_realloc;
                        state.test_list_8.capacity = new_mem.len;
                        return verify_whole_state(state, "Trim_U8_ForceRealloc", alloc);
                    }
                    pub fn trim_u32_force_shrink(rand: Random, state_opq: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                        const state: *STATE = @ptrCast(@alignCast(state_opq));
                        if (state.test_list_32.items.len <= 0) return null;
                        const n_to_force_realloc = rand.uintLessThan(usize, state.test_list_32.items.len);
                        state.ref_list_32.items.len = n_to_force_realloc;
                        const old_mem = state.test_list_32.items.ptr[0..state.test_list_32.capacity];
                        // const dropped_portion = old_mem[n_to_force_realloc..];
                        // const dropped_portion_as_bytes: []u8 = @as([*]u8, @ptrCast(@alignCast(dropped_portion.ptr)))[0 .. dropped_portion.len * 4];
                        // Utils.secure_memset(u8, dropped_portion_as_bytes, 0xAA);
                        const new_mem = Utils.Alloc.realloc_no_memset(state.this_alloc, old_mem, n_to_force_realloc) catch unreachable;
                        state.test_list_32.items.ptr = new_mem.ptr;
                        state.test_list_32.items.len = n_to_force_realloc;
                        state.test_list_32.capacity = new_mem.len;
                        return verify_whole_state(state, "Trim_U32_ForceRealloc", alloc);
                    }

                    pub const OPS = [_]*const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8{
                        append_u8_force_realloc,
                        append_u32_force_realloc,
                        trim_u8_force_shrink,
                        trim_u32_force_shrink,
                    };
                };
                const thread_string = switch (THREADING_MODE) {
                    .single_threaded => "single_threaded",
                    .multi_threaded => "multi_threaded",
                };
                return Fuzz.FuzzTest{
                    .options = Fuzz.FuzzOptions{
                        .name = "SlabBucketAllocator_" ++ thread_string,
                        .min_ops_per_seed = 100,
                        .max_ops_per_seed = 1000,
                    },
                    .init_func = PROTO.INIT,
                    .start_seed_func = PROTO.START_SEED,
                    .op_table = PROTO.OPS[0..],
                    .deinit_func = PROTO.DEINIT,
                };
            }
        };
    };
}
