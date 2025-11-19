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
const Mutex = std.Thread.Mutex;

const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;
const testing = std.testing;
const Test = Root.Testing;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

const GROW_BUCKET_AMOUNT = 8;

pub const ThreadingMode = enum(u8) {
    single_threaded,
    multi_threaded_separate,
    multi_threaded_shared,
};

pub const DataSecurityMode = enum(u8) {
    do_not_explicitly_zero_freed_data,
    explicitly_zero_freed_data,
};

pub fn GlobalCompactAllocator(comptime MAX_MEM_UINT: type, comptime MAX_ALLOC_UINT: type, comptime THREADING_MODE: ThreadingMode, comptime SECURITY_MODE: DataSecurityMode) type {
    assert_with_reason(Types.type_is_unsigned_int(MAX_MEM_UINT), @src(), "type `MAX_MEM_UINT` must be an unsigned integer type, got type {s}", .{@typeName(MAX_MEM_UINT)});
    assert_with_reason(Types.type_is_unsigned_int(MAX_ALLOC_UINT), @src(), "type `MAX_ALLOC_UINT` must be an unsigned integer type, got type {s}", .{@typeName(MAX_MEM_UINT)});
    assert_with_reason(Types.integer_type_A_has_bits_greater_than_or_equal_to_B(MAX_MEM_UINT, MAX_ALLOC_UINT), @src(), "type `MAX_MEM_UINT` must have a bit count >= type `MAX_ALLOC_UINT`, got {d} < {d}", .{ @typeInfo(MAX_MEM_UINT).int.bits, @typeInfo(MAX_ALLOC_UINT).int.bits });
    return struct {
        const Self = @This();
        const ALLOC_UINT_BITS: usize = @intCast(@typeInfo(MAX_ALLOC_UINT).int.bits);
        const ALLOC_UINT_BITS_MINUS_ONE = ALLOC_UINT_BITS - 1;
        const BUCKET_COUNT = (ALLOC_UINT_BITS >> 1) + 1;
        const USE_MUTEX = THREADING_MODE == .multi_threaded_shared;
        const ZERO_DATA = SECURITY_MODE == .explicitly_zero_freed_data;
        const BUCKET_MAX_SIZES: [BUCKET_COUNT]MAX_ALLOC_UINT = make: {
            var sizes: [BUCKET_COUNT]MAX_ALLOC_UINT = undefined;
            sizes[0] = 1;
            sizes[BUCKET_COUNT - 1] = math.maxInt(MAX_ALLOC_UINT);
            var size: MAX_ALLOC_UINT = 1;
            for (1..BUCKET_COUNT - 1) |size_idx| {
                size = size << 2;
                sizes[size_idx] = size;
            }
            break :make sizes;
        };

        const STATE = switch (THREADING_MODE) {
            .single_threaded => struct {
                var data_ptr: [*]u8 = undefined;
                var data_len: MAX_MEM_UINT = 0;
                var meta_ptr: [*]Block = undefined;
                var meta_len: MAX_MEM_UINT = 0;
                var meta_cap: MAX_MEM_UINT = 0;
                var buckets: [BUCKET_COUNT]Bucket = @splat(Bucket{ .start = 0, .len = 0, .cap = 0 });
            },
            .multi_threaded_separate => struct {
                threadlocal var data_ptr: [*]u8 = undefined;
                threadlocal var data_len: MAX_MEM_UINT = 0;
                threadlocal var meta_ptr: [*]Block = undefined;
                threadlocal var meta_len: MAX_MEM_UINT = 0;
                threadlocal var meta_cap: MAX_MEM_UINT = 0;
                threadlocal var buckets: [BUCKET_COUNT]Bucket = @splat(Bucket{ .start = 0, .len = 0, .cap = 0 });
            },
            .multi_threaded_shared => struct {
                var data_ptr: [*]u8 = undefined;
                var data_len: MAX_MEM_UINT = 0;
                var data_lock: Mutex = Mutex{};
                var meta_ptr: [*]Block = undefined;
                var meta_len: MAX_MEM_UINT = 0;
                var meta_cap: MAX_MEM_UINT = 0;
                var meta_lock: Mutex = Mutex{};
                var buckets: [BUCKET_COUNT]Bucket = @splat(Bucket{ .start = 0, .len = 0, .cap = 0 });
            },
        };

        var state = STATE{};

        fn remove_free_block_that_can_hold_size_at_align(size: MAX_MEM_UINT, alignment: MAX_MEM_UINT) ?Block {
            const bucket_idx = bucket_for_size(size);
            var block: Block = undefined;
            for (state.buckets[bucket_idx..]) |*bucket| {
                if (bucket.len == 0) continue;
                var i: MAX_MEM_UINT = bucket.start + (bucket.len - 1);
                while (true) {
                    block = state.meta_ptr[i];
                    if (block_can_hold_size_with_align(block, size, alignment)) |aligned_start| {
                        Utils.mem_remove(state.meta_ptr, &state.meta_len, @intCast(i), 1);
                        return release_unused_portions_of_free_block_and_return_used_block(block, size, aligned_start);
                    }
                    if (i == bucket.start) break;
                    i -= 1;
                }
            }
            return null;
        }
        fn block_can_hold_size_with_align(block: Block, size: MAX_MEM_UINT, alignment: MAX_MEM_UINT) ?MAX_MEM_UINT {
            if (block.len < size) return null;
            const aligned_start = std.mem.alignForward(MAX_MEM_UINT, block.start, alignment);
            const aligned_delta = aligned_start - block.start;
            if (block.len - aligned_delta < size) return null;
            return aligned_start;
        }
        fn release_unused_portions_of_free_block_and_return_used_block(block: Block, size: MAX_MEM_UINT, aligned_start: MAX_MEM_UINT) Block {
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
            push_free_block(block_before);
            push_free_block(block_after);
            return block_to_use;
        }
        fn push_free_block(block: Block) void {
            if (block.len == 0) return;
            const bucket_idx = bucket_for_size(block.len);
            var bucket: *Bucket = &state.buckets[bucket_idx];
            const end = bucket.start + bucket.len;
            if (bucket.len == bucket.cap) {
                if (state.meta_cap - state.meta_len < GROW_BUCKET_AMOUNT) {
                    const page_size = std.heap.pageSize();
                    const new_meta_cap = std.mem.alignForward(usize, Types.intcast(state.meta_cap, usize) + page_size, page_size);
                    const new_meta: []Block = std.heap.page_allocator.realloc(state.meta_ptr[0..state.meta_cap], new_meta_cap) catch |err| assert_allocation_failure(@src(), Block, new_meta_cap, err);
                    state.meta_ptr = new_meta.ptr;
                    state.meta_cap = @intCast(new_meta.len);
                }
                Utils.mem_insert(state.meta_ptr, &state.meta_len, @intCast(end), GROW_BUCKET_AMOUNT);
                for (state.buckets[bucket_idx + 1 ..]) |*bucket_after| {
                    bucket_after.start += GROW_BUCKET_AMOUNT;
                }
            }
            state.meta_ptr[end] = block;
            bucket.len += 1;
        }

        fn split_new_free_block_for_size_and_align(free_block: Block, size: MAX_MEM_UINT, alignment: MAX_MEM_UINT) Block {
            const aligned_start = block_can_hold_size_with_align(free_block, size, alignment) orelse assert_unreachable(@src(), "a brand new block was allocated for size {d} align {d}, but the block was found to be unable to hold the needed space: {any}", .{ size, alignment, free_block });
            return release_unused_portions_of_free_block_and_return_used_block(free_block, size, aligned_start);
        }

        fn get_data_block(size: MAX_MEM_UINT, alignment: MAX_MEM_UINT) Block {
            if (USE_MUTEX) state.meta_lock.lock();
            if (remove_free_block_that_can_hold_size_at_align(size, alignment)) |free_block| {
                if (USE_MUTEX) state.meta_lock.unlock();
                return free_block;
            } else {
                if (USE_MUTEX) state.data_lock.lock();
                const page_size = std.heap.pageSize();
                const grow_amount = @max(page_size, size, alignment);
                const new_data_len = @min(std.mem.alignForward(usize, Types.intcast(state.data_len, usize) + grow_amount, page_size), math.maxInt(MAX_MEM_UINT));
                const new_block_len = Types.intcast(new_data_len, MAX_MEM_UINT) - state.data_len;
                const new_data: []u8 = std.heap.page_allocator.realloc(state.data_ptr[0..state.data_len], new_data_len) catch |err| assert_allocation_failure(@src(), u8, new_data_len, err);
                state.data_ptr = new_data.ptr;
                state.data_len = @intCast(new_data.len);
                const new_free_block = Block{
                    .start = state.data_len,
                    .len = new_block_len,
                };
                if (USE_MUTEX) state.data_lock.unlock();
                const used_block = split_new_free_block_for_size_and_align(new_free_block, size, alignment);
                if (USE_MUTEX) state.meta_lock.unlock();
                return used_block;
            }
        }
        fn return_data_block(block: Block) void {
            if (USE_MUTEX) state.meta_lock.lock();
            if (ZERO_DATA) {
                if (USE_MUTEX) state.data_lock.lock();
                Utils.secure_memset_undefined(u8, state.data_ptr[block.start .. block.start + block.len]);
                if (USE_MUTEX) state.data_lock.unlock();
            }
            push_free_block(block);
            if (USE_MUTEX) state.meta_lock.unlock();
        }

        pub fn recombine_free_blocks() void {
            if (USE_MUTEX) state.meta_lock.lock();
            const real_len = init_all_uninit_blocks_to_max_start_and_return_real_len();
            insertion_sort_by_start();
            state.meta_len = real_len;
            const delta = combine_adjacent_free_blocks_and_return_len_delta();
            state.meta_len -= delta;
            insertion_sort_by_size();
            reindex_all_buckets();
            if (USE_MUTEX) state.meta_lock.unlock();
        }

        fn init_all_uninit_blocks_to_max_start_and_return_real_len() MAX_MEM_UINT {
            var real_len: MAX_MEM_UINT = 0;
            for (state.buckets[0..]) |*bucket| {
                const end = bucket.start + bucket.len;
                const cap = bucket.start + bucket.cap;
                real_len += bucket.len;
                @memset(state.meta_ptr[end..cap], Block{ .start = math.maxInt(MAX_MEM_UINT), .len = 0 });
            }
            return real_len;
        }

        fn insertion_sort_by_start() void {
            if (state.meta_len < 2) return;
            var i: MAX_MEM_UINT = 1;
            var j: MAX_MEM_UINT = undefined;
            var jj: MAX_MEM_UINT = undefined;
            var x: Block = undefined;
            while (i < state.meta_len) {
                x = state.meta_ptr[i];
                j = i;
                inner: while (j > 0) {
                    jj = j - 1;
                    if (state.meta_ptr[jj].start > x.start) {
                        state.meta_ptr[j] = state.meta_ptr[jj];
                        j -= 1;
                    } else {
                        break :inner;
                    }
                }
                state.meta_ptr[j] = x;
                i += 1;
            }
        }
        fn insertion_sort_by_size() void {
            if (state.meta_len < 2) return;
            var i: MAX_MEM_UINT = 1;
            var j: MAX_MEM_UINT = undefined;
            var jj: MAX_MEM_UINT = undefined;
            var x: Block = undefined;
            while (i < state.meta_len) {
                x = state.meta_ptr[i];
                j = i;
                inner: while (j > 0) {
                    jj = j - 1;
                    if (state.meta_ptr[jj].len > x.len) {
                        state.meta_ptr[j] = state.meta_ptr[jj];
                        j -= 1;
                    } else {
                        break :inner;
                    }
                }
                state.meta_ptr[j] = x;
                i += 1;
            }
        }

        fn combine_adjacent_free_blocks_and_return_len_delta() MAX_MEM_UINT {
            if (state.meta_len < 2) return 0;
            var delta: MAX_MEM_UINT = 0;
            var check_idx: MAX_MEM_UINT = 1;
            var combine_idx: MAX_MEM_UINT = 0;
            var dont_combine_idx: MAX_MEM_UINT = 1;
            while (check_idx < state.meta_len) {
                const combine_end = state.meta_ptr[combine_idx].start + state.meta_ptr[combine_idx].len;
                if (combine_end == state.meta_ptr[check_idx].start) {
                    state.meta_ptr[combine_idx].len += state.meta_ptr[check_idx].len;
                    check_idx += 1;
                    delta += 1;
                } else {
                    state.meta_ptr[dont_combine_idx] = state.meta_ptr[check_idx];
                    check_idx += 1;
                    dont_combine_idx += 1;
                    combine_idx += 1;
                }
            }
            return delta;
        }

        fn reindex_all_buckets() void {
            var start: MAX_MEM_UINT = 0;
            var bucket: usize = 0;
            var max: MAX_MEM_UINT = BUCKET_MAX_SIZES[bucket];
            var end: MAX_MEM_UINT = 0;
            var len: MAX_MEM_UINT = 0;
            var size: MAX_MEM_UINT = undefined;
            while (end < state.meta_len) {
                size = state.meta_ptr[end].len;
                if (size <= max) {
                    end += 1;
                    len += 1;
                } else {
                    state.buckets[bucket].start = start;
                    state.buckets[bucket].len = len;
                    state.buckets[bucket].cap = len;
                    start = end;
                    len = 0;
                    bucket += 1;
                    max = BUCKET_MAX_SIZES[bucket];
                }
            }
        }

        pub fn create(comptime T: type) Ptr(T) {
            const size = @sizeOf(T);
            const block = get_data_block(size);
            return Ptr(T){ .addr = Addr{ .val = block.start } };
        }

        pub fn alloc(comptime T: type, len: MAX_ALLOC_UINT) Slice(T) {
            const size = @sizeOf(T) * len;
            const block = get_data_block(@intCast(size));
            return Slice(T){ .ptr = Ptr(T){ .addr = Addr{ .val = block.start } }, .len = len };
        }

        const Bucket = struct {
            start: MAX_MEM_UINT,
            len: MAX_MEM_UINT,
            cap: MAX_MEM_UINT,
        };
        const Block = struct {
            start: MAX_MEM_UINT,
            len: MAX_ALLOC_UINT,
        };
        fn bucket_for_size(size: MAX_MEM_UINT) usize {
            assert_with_reason(size != 0, @src(), "size cannot be 0", .{});
            const log2 = ALLOC_UINT_BITS_MINUS_ONE - @clz(size);
            const add_one = @as(usize, @intCast(@intFromBool(log2 > 0)));
            const bucket_idx = (log2 >> 1) + add_one;
            return bucket_idx;
        }
        pub const Addr = struct {
            val: MAX_MEM_UINT,

            pub fn new(val: MAX_MEM_UINT) Addr {
                return Addr{ .val = val };
            }

            pub fn add(self: Addr, n: MAX_MEM_UINT) Addr {
                return Addr{ .val = self.val + n };
            }

            pub fn sub(self: Addr, n: MAX_MEM_UINT) Addr {
                return Addr{ .val = self.val - n };
            }

            pub fn to_ptr(self: Addr, comptime T: type) Ptr(T) {
                return Ptr(T){ .addr = self };
            }
        };

        pub fn Ptr(comptime T: type) type {
            return struct {
                const PtrSelf = @This();
                const SIZE: MAX_ALLOC_UINT = @sizeOf(T);

                addr: Addr,

                pub fn hydrate_ptr(self: PtrSelf) *T {
                    if (USE_MUTEX) state.data_lock.lock();
                    const ptr: *T = @ptrCast(@alignCast(&state.data_ptr[self.addr.val]));
                    if (USE_MUTEX) state.data_lock.unlock();
                    return ptr;
                }

                pub fn get(self: PtrSelf) T {
                    if (USE_MUTEX) state.data_lock.lock();
                    const val: T = @as(*T, @ptrCast(@alignCast(&state.data_ptr[self.addr.val]))).*;
                    if (USE_MUTEX) state.data_lock.unlock();
                    return val;
                }

                pub fn set(self: PtrSelf, val: T) void {
                    if (USE_MUTEX) state.data_lock.lock();
                    const val_ptr: *T = @ptrCast(@alignCast(&state.data_ptr[self.addr.val]));
                    val_ptr.* = val;
                    if (USE_MUTEX) state.data_lock.unlock();
                }

                pub fn add_addr(self: PtrSelf, n: MAX_MEM_UINT) PtrSelf {
                    const nn = n * SIZE;
                    return PtrSelf{ .addr = self.addr.add(nn) };
                }

                pub fn sub_addr(self: PtrSelf, n: MAX_MEM_UINT) PtrSelf {
                    const nn = n * SIZE;
                    return PtrSelf{ .addr = self.addr.sub(nn) };
                }

                pub fn to_slice(self: PtrSelf, len: MAX_ALLOC_UINT) Slice(T) {
                    return Slice(T){
                        .ptr = self,
                        .len = len,
                    };
                }

                pub fn destroy(ptr: *PtrSelf) void {
                    const block = Block{
                        .start = ptr.addr.val,
                        .len = SIZE,
                    };
                    return_data_block(block);
                    ptr.addr.val = math.maxInt(MAX_MEM_UINT);
                }
            };
        }
        pub fn Slice(comptime T: type) type {
            return struct {
                const SliceSelf = @This();
                const SIZE = @sizeOf(T);

                ptr: Ptr(T),
                len: MAX_ALLOC_UINT,

                pub fn hydrate_slice(self: SliceSelf) []T {
                    const ptr: [*]T = @ptrCast(self.ptr.hydrate_ptr());
                    const slice = ptr[0..self.len];
                    return slice;
                }

                pub fn hydrate_ptr(self: SliceSelf, idx: MAX_ALLOC_UINT) *T {
                    var ptr: [*]T = @ptrCast(self.ptr.hydrate_ptr());
                    const val_ptr: *T = &ptr[idx];
                    return val_ptr;
                }

                pub fn get(self: SliceSelf, idx: MAX_ALLOC_UINT) T {
                    const offset = SIZE * idx;
                    if (USE_MUTEX) state.data_lock.lock();
                    const val: T = @as(*T, @ptrCast(@alignCast(&state.data_ptr[self.addr.val + offset]))).*;
                    if (USE_MUTEX) state.data_lock.unlock();
                    return val;
                }

                pub fn set(self: SliceSelf, idx: MAX_ALLOC_UINT, val: T) void {
                    const offset = SIZE * idx;
                    if (USE_MUTEX) state.data_lock.lock();
                    const val_ptr: *T = @ptrCast(@alignCast(&state.data_ptr[self.addr.val + offset]));
                    val_ptr.* = val;
                    if (USE_MUTEX) state.data_lock.unlock();
                }

                pub fn resize(slice: *SliceSelf, new_len: MAX_ALLOC_UINT) void {
                    const size = @sizeOf(T) * new_len;
                    const new_block = get_data_block(@intCast(size));
                    const old_block = Block{
                        .start = slice.ptr.addr.val,
                        .len = slice.len,
                    };
                    const min_size = @min(slice.len, new_len);
                    if (USE_MUTEX) state.data_lock.lock();
                    @memcpy(state.data_ptr[new_block.start .. new_block.start + min_size], state.data_ptr[old_block.start .. old_block.start + min_size]);
                    if (USE_MUTEX) state.data_lock.unlock();
                    return_data_block(old_block);
                    slice.ptr.addr.val = new_block.start;
                    slice.len = new_block.len;
                }

                pub fn free(slice: *SliceSelf) void {
                    const old_block = Block{
                        .start = slice.ptr.addr.val,
                        .len = slice.len,
                    };
                    return_data_block(old_block);
                    slice.ptr.addr.val = math.maxInt(MAX_MEM_UINT);
                    slice.len = 0;
                }

                // CHECKPOINT implement IList using prototype
            };
        }

        pub fn List(comptime T: type) type {
            return struct {
                const ListSelf = @This();
                const SIZE = @sizeOf(T);

                ptr: Ptr(T),
                len: MAX_ALLOC_UINT,
                cap: MAX_ALLOC_UINT,

                pub fn hydrate_slice(self: ListSelf) []T {
                    const ptr: [*]T = @ptrCast(self.ptr.hydrate_ptr());
                    const slice = ptr[0..self.len];
                    return slice;
                }

                pub fn hydrate_ptr(self: ListSelf, idx: MAX_ALLOC_UINT) *T {
                    var ptr: [*]T = @ptrCast(self.ptr.hydrate_ptr());
                    const val_ptr: *T = &ptr[idx];
                    return val_ptr;
                }

                pub fn get(self: ListSelf, idx: MAX_ALLOC_UINT) T {
                    const offset = SIZE * idx;
                    if (USE_MUTEX) state.data_lock.lock();
                    const val: T = @as(*T, @ptrCast(@alignCast(&state.data_ptr[self.addr.val + offset]))).*;
                    if (USE_MUTEX) state.data_lock.unlock();
                    return val;
                }

                pub fn set(self: ListSelf, idx: MAX_ALLOC_UINT, val: T) void {
                    const offset = SIZE * idx;
                    if (USE_MUTEX) state.data_lock.lock();
                    const val_ptr: *T = @ptrCast(@alignCast(&state.data_ptr[self.addr.val + offset]));
                    val_ptr.* = val;
                    if (USE_MUTEX) state.data_lock.unlock();
                }

                pub fn resize(slice: *ListSelf, new_len: MAX_ALLOC_UINT) void {
                    const size = @sizeOf(T) * new_len;
                    const new_block = get_data_block(@intCast(size));
                    const old_block = Block{
                        .start = slice.ptr.addr.val,
                        .len = slice.len,
                    };
                    const min_size = @min(slice.len, new_len);
                    if (USE_MUTEX) state.data_lock.lock();
                    @memcpy(state.data_ptr[new_block.start .. new_block.start + min_size], state.data_ptr[old_block.start .. old_block.start + min_size]);
                    if (USE_MUTEX) state.data_lock.unlock();
                    return_data_block(old_block);
                    slice.ptr.addr.val = new_block.start;
                    slice.len = new_block.len;
                }

                pub fn free(slice: *ListSelf) void {
                    const old_block = Block{
                        .start = slice.ptr.addr.val,
                        .len = slice.len,
                    };
                    return_data_block(old_block);
                    slice.ptr.addr.val = math.maxInt(MAX_MEM_UINT);
                    slice.len = 0;
                }

                // CHECKPOINT implement IList using prototype
            };
        }
    };
}
