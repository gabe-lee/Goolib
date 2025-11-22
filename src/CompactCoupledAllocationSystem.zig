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

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

const GROW_BUCKET_AMOUNT = 8;
const NO_ALLOC = void{};

pub const ThreadingMode = enum(u8) {
    single_threaded,
    multi_threaded_separate,
    multi_threaded_shared,
};

pub const DataSecurityMode = enum(u8) {
    do_not_explicitly_zero_freed_data,
    explicitly_zero_freed_data,
};

pub const CCAS_Definition = struct {
    UNIQUE_IDENTIFIER: []const u8 = "DEFAULT",
    ADDRESS_UINT: type = u32,
    LEN_UINT: type = u32,
    THREADING_MODE: ThreadingMode = .single_threaded,
    SECURITY_MODE: DataSecurityMode = .do_not_explicitly_zero_freed_data,

    pub fn new(comptime UNIQUE_IDENTIFIER: []const u8, comptime ADDRESS_UINT: type, comptime LEN_UINT: type, comptime THREADING_MODE: ThreadingMode, comptime SECURITY_MODE: DataSecurityMode) CCAS_Definition {
        return CCAS_Definition{
            .UNIQUE_IDENTIFIER = UNIQUE_IDENTIFIER,
            .ADDRESS_UINT = ADDRESS_UINT,
            .LEN_UINT = LEN_UINT,
            .THREADING_MODE = THREADING_MODE,
            .SECURITY_MODE = SECURITY_MODE,
        };
    }
};

pub fn CompactCoupledAllocationSystem(comptime _DEFINITION: CCAS_Definition) type {
    assert_with_reason(Types.type_is_unsigned_int(_DEFINITION.ADDRESS_UINT), @src(), "type `OFFSET_UINT` must be an unsigned integer type, got type {s}", .{@typeName(_DEFINITION.ADDRESS_UINT)});
    assert_with_reason(Types.type_is_unsigned_int(_DEFINITION.LEN_UINT), @src(), "type `LEN_UINT` must be an unsigned integer type, got type {s}", .{@typeName(_DEFINITION.LEN_UINT)});
    assert_with_reason(Types.integer_type_A_has_bits_greater_than_or_equal_to_B(_DEFINITION.ADDRESS_UINT, _DEFINITION.LEN_UINT), @src(), "type `OFFSET_UINT` must have a bit count >= type `LEN_UINT`, got {d} < {d}", .{ @typeInfo(_DEFINITION.ADDRESS_UINT).int.bits, @typeInfo(_DEFINITION.LEN_UINT).int.bits });
    return struct {
        const UNIQUE_IDENTIFIER = _DEFINITION.UNIQUE_IDENTIFIER;
        const ADDRESS_UINT = _DEFINITION.ADDRESS_UINT;
        const LEN_UINT = _DEFINITION.LEN_UINT;
        const THREADING_MODE = _DEFINITION.THREADING_MODE;
        const SECURITY_MODE = _DEFINITION.SECURITY_MODE;
        const ALLOC_UINT_BITS: usize = @intCast(@typeInfo(ADDRESS_UINT).int.bits);
        const ALLOC_UINT_BITS_MINUS_ONE = ALLOC_UINT_BITS - 1;
        const BUCKET_COUNT = (ALLOC_UINT_BITS >> 1) + 1;
        const USE_MUTEX = THREADING_MODE == .multi_threaded_shared;
        const ZERO_DATA = SECURITY_MODE == .explicitly_zero_freed_data;
        const BUCKET_MAX_SIZES: [BUCKET_COUNT]LEN_UINT = make: {
            var sizes: [BUCKET_COUNT]LEN_UINT = undefined;
            sizes[0] = 1;
            sizes[BUCKET_COUNT - 1] = math.maxInt(LEN_UINT);
            var size: LEN_UINT = 1;
            for (1..BUCKET_COUNT - 1) |size_idx| {
                size = size << 2;
                sizes[size_idx] = size;
            }
            break :make sizes;
        };

        pub const DEFINITION = _DEFINITION;

        const STATE = switch (THREADING_MODE) {
            .single_threaded => struct {
                var data_ptr: [*]u8 = undefined;
                var data_len: ADDRESS_UINT = 0;
                var meta_ptr: [*]Block = undefined;
                var meta_len: ADDRESS_UINT = 0;
                var meta_cap: ADDRESS_UINT = 0;
                var buckets: [BUCKET_COUNT]Bucket = @splat(Bucket{ .start = 0, .len = 0, .cap = 0 });
            },
            .multi_threaded_separate => struct {
                threadlocal var data_ptr: [*]u8 = undefined;
                threadlocal var data_len: ADDRESS_UINT = 0;
                threadlocal var meta_ptr: [*]Block = undefined;
                threadlocal var meta_len: ADDRESS_UINT = 0;
                threadlocal var meta_cap: ADDRESS_UINT = 0;
                threadlocal var buckets: [BUCKET_COUNT]Bucket = @splat(Bucket{ .start = 0, .len = 0, .cap = 0 });
            },
            .multi_threaded_shared => struct {
                var data_ptr: [*]u8 = undefined;
                var data_len: ADDRESS_UINT = 0;
                var data_lock: Mutex = Mutex{};
                var meta_ptr: [*]Block = undefined;
                var meta_len: ADDRESS_UINT = 0;
                var meta_cap: ADDRESS_UINT = 0;
                var meta_lock: Mutex = Mutex{};
                var buckets: [BUCKET_COUNT]Bucket = @splat(Bucket{ .start = 0, .len = 0, .cap = 0 });
            },
        };

        inline fn lock_data() void {
            if (USE_MUTEX) STATE.data_lock.lock();
        }

        inline fn unlock_data() void {
            if (USE_MUTEX) STATE.data_lock.unlock();
        }

        inline fn lock_meta() void {
            if (USE_MUTEX) STATE.meta_lock.lock();
        }

        inline fn unlock_meta() void {
            if (USE_MUTEX) STATE.meta_lock.unlock();
        }

        fn impl_gen_alloc(_: *anyopaque, len: LEN_UINT, alignement: Alignment) ADDRESS_UINT {
            const block = claim_data_block(len, alignement.to_uint(LEN_UINT));
            return block.start;
        }
        fn impl_gen_resize(_: *anyopaque, old_address: ADDRESS_UINT, old_len: LEN_UINT, new_len: LEN_UINT, _: Alignment) bool {
            if (new_len >= old_len) return false;
            const freed_block = Block{
                .start = old_address + Types.intcast(new_len, ADDRESS_UINT),
                .len = old_len - new_len,
            };
            release_data_block(freed_block);
            return true;
        }
        fn impl_gen_remap(object: *anyopaque, old_address: ADDRESS_UINT, old_len: LEN_UINT, new_len: LEN_UINT, alignement: Alignment) ?ADDRESS_UINT {
            if (impl_gen_resize(object, old_address, old_len, new_len, alignement)) return old_address;
            return null;
        }
        fn impl_gen_free(_: *anyopaque, address: ADDRESS_UINT, len: LEN_UINT) void {
            const freed_block = Block{
                .start = address,
                .len = len,
            };
            release_data_block(freed_block);
        }
        fn impl_gen_addr_to_usize(_: *anyopaque, address: ADDRESS_UINT) usize {
            lock_data();
            const real_addr: usize = @intFromPtr(STATE.data_ptr) + Types.intcast(address, usize);
            unlock_data();
            return real_addr;
        }

        pub fn generic_allocator() GenericAllocator(ADDRESS_UINT, LEN_UINT) {
            return GenericAllocator(ADDRESS_UINT, LEN_UINT){
                .object = @ptrFromInt(math.maxInt(usize)),
                .vtable = GenericAllocator(ADDRESS_UINT, LEN_UINT).VTABLE{
                    .alloc = impl_gen_alloc,
                    .resize = impl_gen_resize,
                    .remap = impl_gen_remap,
                    .free = impl_gen_free,
                    .addr_to_usize = impl_gen_addr_to_usize,
                },
            };
        }

        fn remove_free_block_that_can_hold_size_at_align(size: LEN_UINT, alignment: LEN_UINT) ?Block {
            const bucket_idx = bucket_for_size(size);
            var block: Block = undefined;
            for (STATE.buckets[bucket_idx..]) |*bucket| {
                if (bucket.len == 0) continue;
                var b: ADDRESS_UINT = (bucket.len - 1);
                var i: ADDRESS_UINT = bucket.start + b;
                while (true) {
                    block = STATE.meta_ptr[i];
                    if (block_can_hold_size_with_align(block, size, alignment)) |aligned_start| {
                        Utils.mem_remove(STATE.meta_ptr + bucket.start, &bucket.len, @intCast(b), 1);
                        const free_block = release_unused_portions_of_free_block_and_return_used_block(block, size, aligned_start);
                        return free_block;
                    }
                    if (i == bucket.start) break;
                    i -= 1;
                    b -= 1;
                }
            }
            return null;
        }
        fn block_can_hold_size_with_align(block: Block, size: ADDRESS_UINT, alignment: ADDRESS_UINT) ?ADDRESS_UINT {
            if (block.len < size) return null;
            const aligned_start = std.mem.alignForward(ADDRESS_UINT, block.start, alignment);
            const aligned_delta = aligned_start - block.start;
            if (block.len - aligned_delta < size) return null;
            return aligned_start;
        }

        fn release_unused_portions_of_free_block_and_return_used_block(block: Block, size: ADDRESS_UINT, aligned_start: ADDRESS_UINT) Block {
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
            const bucket_idx = bucket_for_size(@intCast(block.len));
            var bucket: *Bucket = &STATE.buckets[bucket_idx];
            const end = bucket.start + bucket.len;
            if (bucket.len == bucket.cap) {
                if (STATE.meta_cap == STATE.meta_len) {
                    const page_size = std.heap.pageSize();
                    const new_meta_cap = std.mem.alignForward(usize, Types.intcast(STATE.meta_cap, usize) + page_size, page_size);
                    const new_meta: []Block = std.heap.page_allocator.realloc(STATE.meta_ptr[0..STATE.meta_cap], new_meta_cap) catch |err| assert_allocation_failure(@src(), Block, new_meta_cap, err);
                    STATE.meta_ptr = new_meta.ptr;
                    STATE.meta_cap = @intCast(new_meta.len);
                }
                const grow_amount = @min(STATE.meta_cap - STATE.meta_len, GROW_BUCKET_AMOUNT);
                Utils.mem_insert(STATE.meta_ptr, &STATE.meta_len, @intCast(end), grow_amount);
                bucket.cap += grow_amount;
                for (STATE.buckets[bucket_idx + 1 ..]) |*bucket_after| {
                    bucket_after.start += grow_amount;
                }
            }
            STATE.meta_ptr[end] = block;
            bucket.len += 1;
        }

        fn split_new_free_block_for_size_and_align(free_block: Block, size: ADDRESS_UINT, alignment: ADDRESS_UINT) Block {
            const aligned_start = block_can_hold_size_with_align(free_block, size, alignment) orelse assert_unreachable(@src(), "a brand new block was allocated for size {d} align {d}, but the block was found to be unable to hold the needed space: {any}", .{ size, alignment, free_block });
            return release_unused_portions_of_free_block_and_return_used_block(free_block, size, aligned_start);
        }

        fn claim_data_block(size: LEN_UINT, alignment: LEN_UINT) Block {
            lock_meta();
            if (remove_free_block_that_can_hold_size_at_align(size, alignment)) |free_block| {
                unlock_meta();
                return free_block;
            } else {
                lock_data();
                const page_size = std.heap.pageSize();
                const old_len = STATE.data_len;
                const grow_amount = @max(size, alignment);
                const new_data_len = @min(std.mem.alignForward(usize, Types.intcast(STATE.data_len, usize) + grow_amount, page_size), math.maxInt(ADDRESS_UINT));
                const new_block_len = Types.intcast(new_data_len, ADDRESS_UINT) - STATE.data_len;
                const new_data: []u8 = std.heap.page_allocator.realloc(STATE.data_ptr[0..STATE.data_len], new_data_len) catch |err| assert_allocation_failure(@src(), u8, new_data_len, err);
                STATE.data_ptr = new_data.ptr;
                STATE.data_len = @intCast(new_data.len);

                const new_free_block = Block{
                    .start = old_len,
                    .len = new_block_len,
                };
                unlock_data();
                const used_block = split_new_free_block_for_size_and_align(new_free_block, size, alignment);
                unlock_meta();
                return used_block;
            }
        }
        fn release_data_block(block: Block) void {
            if (block.len == 0) return;
            lock_meta();
            if (ZERO_DATA) {
                lock_data();
                Utils.secure_memset_undefined(u8, STATE.data_ptr[block.start .. block.start + block.len]);
                unlock_data();
            }
            push_free_block(block);
            unlock_meta();
        }

        pub fn recombine_free_blocks() void {
            lock_meta();
            const real_len = init_all_uninit_blocks_to_max_start_and_return_real_len();
            insertion_sort_by_start();
            STATE.meta_len = real_len;
            const delta = combine_adjacent_free_blocks_and_return_len_delta();
            STATE.meta_len -= delta;
            insertion_sort_by_size();
            reindex_all_buckets();
            unlock_meta();
        }

        fn init_all_uninit_blocks_to_max_start_and_return_real_len() ADDRESS_UINT {
            var real_len: ADDRESS_UINT = 0;
            for (STATE.buckets[0..]) |*bucket| {
                const end = bucket.start + bucket.len;
                const cap = bucket.start + bucket.cap;
                real_len += bucket.len;
                @memset(STATE.meta_ptr[end..cap], Block{ .start = math.maxInt(ADDRESS_UINT), .len = 0 });
            }
            return real_len;
        }

        fn insertion_sort_by_start() void {
            if (STATE.meta_len < 2) return;
            var i: ADDRESS_UINT = 1;
            var j: ADDRESS_UINT = undefined;
            var jj: ADDRESS_UINT = undefined;
            var x: Block = undefined;
            while (i < STATE.meta_len) {
                x = STATE.meta_ptr[i];
                j = i;
                inner: while (j > 0) {
                    jj = j - 1;
                    if (STATE.meta_ptr[jj].start > x.start) {
                        STATE.meta_ptr[j] = STATE.meta_ptr[jj];
                        j -= 1;
                    } else {
                        break :inner;
                    }
                }
                STATE.meta_ptr[j] = x;
                i += 1;
            }
        }
        fn insertion_sort_by_size() void {
            if (STATE.meta_len < 2) return;
            var i: ADDRESS_UINT = 1;
            var j: ADDRESS_UINT = undefined;
            var jj: ADDRESS_UINT = undefined;
            var x: Block = undefined;
            while (i < STATE.meta_len) {
                x = STATE.meta_ptr[i];
                j = i;
                inner: while (j > 0) {
                    jj = j - 1;
                    if (STATE.meta_ptr[jj].len > x.len) {
                        STATE.meta_ptr[j] = STATE.meta_ptr[jj];
                        j -= 1;
                    } else {
                        break :inner;
                    }
                }
                STATE.meta_ptr[j] = x;
                i += 1;
            }
        }

        fn combine_adjacent_free_blocks_and_return_len_delta() ADDRESS_UINT {
            if (STATE.meta_len < 2) return 0;
            var delta: ADDRESS_UINT = 0;
            var check_idx: ADDRESS_UINT = 1;
            var combine_idx: ADDRESS_UINT = 0;
            var dont_combine_idx: ADDRESS_UINT = 1;
            while (check_idx < STATE.meta_len) {
                const combine_end = STATE.meta_ptr[combine_idx].start + STATE.meta_ptr[combine_idx].len;
                if (combine_end == STATE.meta_ptr[check_idx].start) {
                    STATE.meta_ptr[combine_idx].len += STATE.meta_ptr[check_idx].len;
                    check_idx += 1;
                    delta += 1;
                } else {
                    STATE.meta_ptr[dont_combine_idx] = STATE.meta_ptr[check_idx];
                    check_idx += 1;
                    dont_combine_idx += 1;
                    combine_idx += 1;
                }
            }
            return delta;
        }

        fn reindex_all_buckets() void {
            var start: ADDRESS_UINT = 0;
            var bucket: usize = 0;
            var max: ADDRESS_UINT = BUCKET_MAX_SIZES[bucket];
            var end: ADDRESS_UINT = 0;
            var len: ADDRESS_UINT = 0;
            var size: ADDRESS_UINT = undefined;
            while (end < STATE.meta_len) {
                size = STATE.meta_ptr[end].len;
                if (size <= max) {
                    end += 1;
                    len += 1;
                } else {
                    STATE.buckets[bucket].start = start;
                    STATE.buckets[bucket].len = len;
                    STATE.buckets[bucket].cap = len;
                    start = end;
                    len = 0;
                    bucket += 1;
                    max = BUCKET_MAX_SIZES[bucket];
                }
            }
        }

        pub fn create_ptr(comptime T: type) Ptr(T) {
            const size = @sizeOf(T);
            const alignment = Alignment.from_type(T).to_uint(LEN_UINT);
            const block = claim_data_block(size, alignment);
            return Ptr(T){ .addr = Addr{ .val = block.start } };
        }

        pub fn alloc_slice(comptime T: type, len: LEN_UINT) Slice(T) {
            const size = @sizeOf(T) * len;
            const block = claim_data_block(@intCast(size));
            return Slice(T){ .ptr = Ptr(T){ .addr = Addr{ .val = block.start } }, .len = len };
        }

        const Bucket = struct {
            start: ADDRESS_UINT,
            len: ADDRESS_UINT,
            cap: ADDRESS_UINT,
        };
        const Block = struct {
            start: ADDRESS_UINT,
            len: ADDRESS_UINT,
        };
        fn bucket_for_size(size: ADDRESS_UINT) usize {
            assert_with_reason(size != 0, @src(), "size cannot be 0", .{});
            const log2 = ALLOC_UINT_BITS_MINUS_ONE - @clz(size);
            const add_one = @as(usize, @intCast(@intFromBool(log2 > 0)));
            const bucket_idx = (log2 >> 1) + add_one;
            return bucket_idx;
        }
        pub const Addr = struct {
            val: ADDRESS_UINT = math.maxInt(ADDRESS_UINT),

            pub fn new(val: ADDRESS_UINT) Addr {
                return Addr{ .val = val };
            }

            pub fn add(self: Addr, n: ADDRESS_UINT) Addr {
                return Addr{ .val = self.val + n };
            }

            pub fn sub(self: Addr, n: ADDRESS_UINT) Addr {
                return Addr{ .val = self.val - n };
            }

            pub fn to_ptr(self: Addr, comptime T: type) Ptr(T) {
                return Ptr(T){ .addr = self };
            }
        };

        pub fn Ptr(comptime T: type) type {
            return struct {
                const PtrSelf = @This();
                const SIZE: comptime_int = @sizeOf(T);

                addr: Addr = Addr{},

                inline fn check_address(self: PtrSelf) void {
                    assert_with_reason(self.addr.val + @sizeOf(T) <= STATE.data_len, @src(), "attempted to access memory out of bounds for `{s}` (GlobalCompactAllocatorSystem): address start = {d} address end = {d}, allocator end = {d}", .{ UNIQUE_IDENTIFIER, self.addr.val, self.addr.val + @sizeOf(T), STATE.data_len });
                }

                inline fn get_ptr_no_lock(self: PtrSelf) *T {
                    self.check_address();
                    return @ptrCast(@alignCast(&STATE.data_ptr[self.addr.val]));
                }

                pub inline fn get_ptr(self: PtrSelf) *T {
                    lock_data();
                    const ptr: *T = self.get_ptr_no_lock();
                    unlock_data();
                    return ptr;
                }

                inline fn get_many_item_ptr_no_lock(self: PtrSelf) [*]T {
                    self.check_address();
                    return @ptrCast(@alignCast(&STATE.data_ptr[self.addr.val]));
                }

                inline fn get_many_item_ptr(self: PtrSelf) [*]T {
                    lock_data();
                    const ptr: *T = self.get_ptr_no_lock();
                    unlock_data();
                    return ptr;
                }

                inline fn get_no_lock(self: PtrSelf) T {
                    self.check_address();
                    return @as(*T, @ptrCast(@alignCast(&STATE.data_ptr[self.addr.val]))).*;
                }

                pub inline fn get(self: PtrSelf) T {
                    lock_data();
                    const val: T = self.get_no_lock();
                    unlock_data();
                    return val;
                }

                fn set_no_lock(self: PtrSelf, val: T) void {
                    self.check_address();
                    const val_ptr: *T = @ptrCast(@alignCast(&STATE.data_ptr[self.addr.val]));
                    val_ptr.* = val;
                }

                pub fn set(self: PtrSelf, val: T) void {
                    lock_data();
                    self.set_no_lock(val);
                    unlock_data();
                }

                pub fn add_offset(self: PtrSelf, n: usize) PtrSelf {
                    const nn = n * SIZE;
                    return PtrSelf{ .addr = self.addr.add(@intCast(nn)) };
                }

                pub fn sub_offset(self: PtrSelf, n: usize) PtrSelf {
                    const nn = n * SIZE;
                    return PtrSelf{ .addr = self.addr.sub(@intCast(nn)) };
                }

                pub fn to_slice(self: PtrSelf, len: usize) Slice(T) {
                    return Slice(T){
                        .ptr = self,
                        .len = @intCast(len),
                    };
                }

                pub fn destroy(ptr: *PtrSelf) void {
                    const block = Block{
                        .start = ptr.addr.val,
                        .len = SIZE,
                    };
                    release_data_block(block);
                    ptr.addr.val = math.maxInt(ADDRESS_UINT);
                }
            };
        }
        pub fn Slice(comptime T: type) type {
            return struct {
                const SliceSelf = @This();
                const SIZE: comptime_int = @sizeOf(T);

                ptr: Ptr(T) = Ptr(T){},
                len: LEN_UINT = 0,

                inline fn to_block(self: SliceSelf) Block {
                    return Block{
                        .start = self.ptr.addr.val,
                        .len = self.len,
                    };
                }

                inline fn check_index(self: SliceSelf, idx: usize) Ptr(T) {
                    assert_with_reason(idx < self.len, @src(), "attempted to access an index beyond the range of the `Slice({s})`, idx = {d}, len = {d}", .{ @typeName(T), idx, self.len });
                    return self.ptr.add_offset(idx);
                }

                fn zig_slice_no_lock(self: SliceSelf) []T {
                    const ptr: [*]T = @ptrCast(self.ptr.get_ptr_no_lock());
                    const slice = ptr[0..self.len];
                    return slice;
                }

                pub fn zig_slice(self: SliceSelf) []T {
                    lock_data();
                    const slice = self.zig_slice_no_lock();
                    unlock_data();
                    return slice;
                }

                fn zig_sub_slice_no_lock(self: SliceSelf, start: usize, end_exclude: usize) []T {
                    _ = self.check_index(end_exclude - 1);
                    const ptr: [*]T = @ptrCast(self.ptr.get_ptr_no_lock());
                    const slice = ptr[start..end_exclude];
                    return slice;
                }

                pub fn zig_sub_slice(self: SliceSelf, start: usize, end_exclude: usize) []T {
                    lock_data();
                    const slice = self.zig_sub_slice_no_lock(start, end_exclude);
                    unlock_data();
                    return slice;
                }

                pub fn sub_slice(self: SliceSelf, start: usize, end_exclude: usize) Slice(T) {
                    _ = self.check_index(end_exclude - 1);
                    const len = end_exclude - start;
                    return Slice(T){
                        .ptr = self.ptr.add_offset(start),
                        .len = len,
                    };
                }

                //*** BEGIN PROTOTYPE ***
                const P_FUNCS = struct {
                    fn p_get(self: *SliceSelf, idx: usize, _: void) T {
                        return self.get(idx);
                    }
                    fn p_get_ptr(self: *SliceSelf, idx: usize, _: void) *T {
                        return self.get_ptr(idx);
                    }
                    fn p_set(self: *SliceSelf, idx: usize, val: T, _: void) void {
                        return self.set(idx, val);
                    }
                    fn p_move(self: *SliceSelf, old_idx: usize, new_idx: usize, _: void) void {
                        lock_data();
                        const slice = self.zig_slice_no_lock();
                        Utils.slice_move_one(slice, old_idx, new_idx);
                        unlock_data();
                    }
                    fn p_move_range(self: *SliceSelf, range: IList.Range, new_first_idx: usize, _: void) void {
                        lock_data();
                        const slice = self.zig_slice_no_lock();
                        Utils.slice_move_many(slice, range.first_idx, range.last_idx, new_first_idx);
                        unlock_data();
                    }
                    fn p_try_ensure_free_slots(_: *SliceSelf, _: usize, _: void) error{failed_to_grow_list}!void {
                        return;
                    }
                    fn p_shrink_cap_reserve_at_most(_: *SliceSelf, _: usize, _: void) void {
                        return;
                    }
                    fn p_append_slots_assume_capacity(self: *SliceSelf, count: usize, _: void) IList.Range {
                        const first: usize = @intCast(self.len);
                        const new_len = (self.len + count);
                        self.realloc(new_len);
                        return IList.Range.new_range(first, @intCast(self.slice.len - 1));
                    }
                    fn p_insert_slots_assume_capacity(self: *SliceSelf, idx: usize, count: usize, alloc: void) IList.Range {
                        if (idx == self.len) {
                            return p_append_slots_assume_capacity(self, count, alloc);
                        }
                        const new_len = (self.len + count);
                        self.realloc(new_len);
                        lock_data();
                        Utils.mem_insert(self.ptr.get_many_item_ptr_no_lock(), &self.len, idx, count);
                        unlock_data();
                        return IList.Range.new_range(idx, idx + count - 1);
                    }
                    fn p_trim_len(self: *SliceSelf, trim_n: usize, _: void) void {
                        self.len -= @intCast(trim_n);
                    }
                    fn p_delete(self: *SliceSelf, idx: usize, _: void) void {
                        if (idx == self.len - 1) {
                            self.len -= 1;
                            return;
                        }
                        lock_data();
                        Utils.mem_remove(self.ptr.get_many_item_ptr_no_lock(), &self.len, idx, 1);
                        unlock_data();
                    }
                    fn p_delete_range(self: *SliceSelf, range: IList.Range, _: void) void {
                        const rlen = range.consecutive_len();
                        if (range.last_idx == self.len - 1) {
                            self.len -= @intCast(rlen);
                            return;
                        }
                        lock_data();
                        Utils.mem_remove(self.ptr.get_many_item_ptr_no_lock(), &self.len, range.first_idx, rlen);
                        unlock_data();
                    }
                    fn p_clear(self: *SliceSelf, alloc: void) void {
                        p_free(self, alloc);
                    }
                    fn p_free(self: *SliceSelf, _: void) void {
                        const block = self.to_block();
                        release_data_block(block);
                        self.len = 0;
                        self.ptr.addr.val = math.maxInt(LEN_UINT);
                    }
                    fn p_has_native_slice(_: *SliceSelf) bool {
                        return true;
                    }
                    fn p_native_slice(self: *SliceSelf, range: IListConcrete.Range) []T {
                        self.zig_sub_slice(range.first_idx, range.last_idx + 1);
                    }
                    fn p_prefer_linear_ops(_: *SliceSelf) bool {
                        return false;
                    }
                    fn p_all_indexes_zero_to_len_valid(_: *SliceSelf) bool {
                        return true;
                    }
                    fn p_consecutive_indexes_in_order(_: *SliceSelf) bool {
                        return true;
                    }
                    fn p_ensure_free_doesnt_change_cap(_: *SliceSelf) bool {
                        return true;
                    }
                    fn p_always_invalid_idx(_: *SliceSelf) usize {
                        return math.maxInt(usize);
                    }
                    fn p_len(self: *SliceSelf) usize {
                        return @intCast(self.len);
                    }
                    fn p_cap(self: *SliceSelf) usize {
                        return @intCast(self.cap);
                    }
                    fn p_first_idx(_: *SliceSelf) usize {
                        return 0;
                    }
                    fn p_last_idx(self: *SliceSelf) usize {
                        return Types.intcast(self.len, usize) -% 1;
                    }
                    fn p_next_idx(_: *SliceSelf, this_idx: usize) usize {
                        return this_idx + 1;
                    }
                    fn p_nth_next_idx(_: *SliceSelf, this_idx: usize, n: usize) usize {
                        return this_idx + n;
                    }
                    fn p_prev_idx(_: *SliceSelf, this_idx: usize) usize {
                        return this_idx -% 1;
                    }
                    fn p_nth_prev_idx(_: *SliceSelf, this_idx: usize, n: usize) usize {
                        return this_idx -% n;
                    }
                    fn p_idx_valid(self: *SliceSelf, idx: usize) bool {
                        return idx < self.len;
                    }
                    fn p_range_valid(self: *SliceSelf, range: IListConcrete.Range) bool {
                        return range.first_idx <= range.last_idx and range.last_idx < self.len;
                    }
                    fn p_idx_in_range(_: *SliceSelf, idx: usize, range: IListConcrete.Range) bool {
                        return range.first_idx <= idx and idx <= range.last_idx;
                    }
                    fn p_split_range(_: *SliceSelf, range: IListConcrete.Range) usize {
                        return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
                    }
                    fn p_range_len(_: *SliceSelf, range: IListConcrete.Range) usize {
                        return (range.last_idx - range.first_idx) + 1;
                    }
                };
                const VFX = IList.IListConcrete.ConcreteTableValueFuncs(T, *SliceSelf, void){
                    .get = P_FUNCS.p_get,
                    .get_ptr = P_FUNCS.p_get_ptr,
                    .set = P_FUNCS.p_set,
                    .move = P_FUNCS.p_move,
                    .move_range = P_FUNCS.p_move_range,
                    .try_ensure_free_slots = P_FUNCS.p_try_ensure_free_slots,
                    .shrink_cap_reserve_at_most = P_FUNCS.p_shrink_cap_reserve_at_most,
                    .append_slots_assume_capacity = P_FUNCS.p_append_slots_assume_capacity,
                    .insert_slots_assume_capacity = P_FUNCS.p_insert_slots_assume_capacity,
                    .trim_len = P_FUNCS.p_trim_len,
                    .delete = P_FUNCS.p_delete,
                    .delete_range = P_FUNCS.p_delete_range,
                    .clear = P_FUNCS.p_clear,
                    .free = P_FUNCS.p_free,
                };
                const NFX = IListConcrete.ConcreteTableNativeSliceFuncs(T, *SliceSelf){
                    .has_native_slice = P_FUNCS.p_has_native_slice,
                    .native_slice = P_FUNCS.p_native_slice,
                };
                const IFX = IListConcrete.ConcreteTableIndexFuncs(*SliceSelf){
                    .all_indexes_zero_to_len_valid = P_FUNCS.p_all_indexes_zero_to_len_valid,
                    .always_invalid_idx = P_FUNCS.p_always_invalid_idx,
                    .cap = P_FUNCS.p_cap,
                    .consecutive_indexes_in_order = P_FUNCS.p_consecutive_indexes_in_order,
                    .ensure_free_doesnt_change_cap = P_FUNCS.p_ensure_free_doesnt_change_cap,
                    .first_idx = P_FUNCS.p_first_idx,
                    .idx_in_range = P_FUNCS.p_idx_in_range,
                    .idx_valid = P_FUNCS.p_idx_valid,
                    .last_idx = P_FUNCS.p_last_idx,
                    .len = P_FUNCS.p_len,
                    .next_idx = P_FUNCS.p_next_idx,
                    .nth_next_idx = P_FUNCS.p_nth_next_idx,
                    .nth_prev_idx = P_FUNCS.p_nth_prev_idx,
                    .prefer_linear_ops = P_FUNCS.p_prefer_linear_ops,
                    .prev_idx = P_FUNCS.p_prev_idx,
                    .range_len = P_FUNCS.p_range_len,
                    .range_valid = P_FUNCS.p_range_valid,
                    .split_range = P_FUNCS.p_split_range,
                };
                const P = IListConcrete.CreateConcretePrototype(T, *SliceSelf, void, VFX, IFX, NFX);
                const VTABLE = P.VTABLE(true, true, false, math.maxInt(usize));
                //*** END PROTOTYPE***

                pub fn interface(self: *SliceSelf) IList.IList(T) {
                    return IList.IList(T){
                        .alloc = DummyAlloc.allocator_panic,
                        .object = @ptrCast(self),
                        .vtable = &VTABLE,
                    };
                }

                pub fn realloc(self: *SliceSelf, new_len: usize) void {
                    const size = @sizeOf(T) * new_len;
                    const new_block = claim_data_block(@intCast(size));
                    const old_block = Block{
                        .start = self.ptr.addr.val,
                        .len = self.len,
                    };
                    const min_len = @min(self.len, new_len);
                    const min_len_u8 = min_len * SIZE;
                    lock_data();
                    @memcpy(STATE.data_ptr[new_block.start .. new_block.start + min_len_u8], STATE.data_ptr[old_block.start .. old_block.start + min_len_u8]);
                    unlock_data();
                    release_data_block(old_block);
                    self.ptr.addr.val = new_block.start;
                    self.len = new_block.len;
                }

                /// Return the number of items in the list
                pub fn len_usize(self: *SliceSelf) usize {
                    return P.len(self);
                }
                /// Reduce the number of items in the list by
                /// dropping/deleting them from the end of the list
                pub fn trim_len(self: *SliceSelf, trim_n: usize) void {
                    return P.trim_len(self, trim_n, NO_ALLOC);
                }
                /// Return the total number of items the list can hold
                /// without reallocation
                pub fn cap_usize(self: *SliceSelf) usize {
                    return P.cap(self);
                }
                /// Return the first index in the list
                pub fn first_idx(self: *SliceSelf) usize {
                    return P.first_idx(self);
                }
                /// Return the last valid index in the list
                pub fn last_idx(self: *SliceSelf) usize {
                    return P.last_idx(self);
                }
                /// Return the index directly after the given index in the list
                pub fn next_idx(self: *SliceSelf, this_idx: usize) usize {
                    return P.next_idx(self, this_idx);
                }
                /// Return the index `n` places after the given index in the list,
                /// which may be 0 (returning the given index)
                pub fn nth_next_idx(self: *SliceSelf, this_idx: usize, n: usize) usize {
                    return P.nth_next_idx(self, this_idx, n);
                }
                /// Return the index directly before the given index in the list
                pub fn prev_idx(self: *SliceSelf, this_idx: usize) usize {
                    return P.prev_idx(self, this_idx);
                }
                /// Return the index `n` places before the given index in the list,
                /// which may be 0 (returning the given index)
                pub fn nth_prev_idx(self: *SliceSelf, this_idx: usize, n: usize) usize {
                    return P.nth_prev_idx(self, this_idx, n);
                }
                /// Return `true` if the index is valid for the current state
                /// of the list, `false` otherwise
                pub fn idx_valid(self: *SliceSelf, idx: usize) bool {
                    return P.idx_valid(self, idx);
                }
                /// Return `true` if the range is valid for the current state
                /// of the list, `false` otherwise. The first index must
                /// come before or be equal to the last index, and all
                /// indexes in between must also be valid
                pub fn range_valid(self: *SliceSelf, range: Range) bool {
                    return P.range_valid(self, range);
                }
                /// Return whether the given index falls within the given range,
                /// inclusive
                pub fn idx_in_range(self: *SliceSelf, range: Range, idx: usize) bool {
                    return P.idx_in_range(self, range, idx);
                }
                /// Split a range roughly in half, returning an index
                /// as close to the true center point as possible.
                /// Implementations may choose not to return an index
                /// close to the actual middle of the range if
                /// finding that middle index is expensive
                pub fn split_range(self: *SliceSelf, range: Range) usize {
                    return P.split_range(self, range);
                }
                /// Return the number of indexes included within a range,
                /// inclusive of the last index
                pub fn range_len(self: *SliceSelf, range: Range) usize {
                    return P.range_len(self, range);
                }

                inline fn get_no_lock(self: SliceSelf, idx: usize) T {
                    const ptr = self.check_index(idx);
                    return ptr.get_no_lock();
                }

                /// Return the value at the given index
                pub inline fn get(self: SliceSelf, idx: usize) T {
                    lock_data();
                    const val: T = self.get_no_lock(idx);
                    unlock_data();
                    return val;
                }

                inline fn get_ptr_no_lock(self: SliceSelf, idx: usize) *T {
                    const ptr = self.check_index(idx);
                    return ptr.get_ptr_no_lock();
                }

                /// Return a pointer to the value at a given index
                pub inline fn get_ptr(self: SliceSelf, idx: usize) *T {
                    lock_data();
                    const ptr: *T = self.get_ptr_no_lock(idx);
                    unlock_data();
                    return ptr;
                }

                inline fn set_no_lock(self: SliceSelf, idx: usize, val: T) void {
                    const ptr = self.check_index(idx);
                    ptr.set_no_lock(val);
                }

                /// Set the value at the given index
                pub inline fn set(self: SliceSelf, idx: usize, val: T) void {
                    lock_data();
                    self.set_no_lock(idx, val);
                    unlock_data();
                }

                /// Move one value to a new location within the list,
                /// moving the values in between the old and new location
                /// out of the way while maintaining their order
                pub fn move(self: *SliceSelf, old_idx: usize, new_idx: usize) void {
                    return P.move(self, old_idx, new_idx, NO_ALLOC);
                }
                /// Move a range of values to a new location within the list,
                /// moving the values in between the old and new location
                /// out of the way while maintaining their order
                pub fn move_range(self: *SliceSelf, range: Range, new_first_idx: usize) void {
                    return P.move_range(self, range, new_first_idx, NO_ALLOC);
                }
                /// Attempt to ensure at least 'n' free slots exist for adding new items,
                /// returning error `failed_to_grow_list` if adding `n` new items will
                /// definitely cause undefined behavior or some other error
                pub fn try_ensure_free_slots(self: *SliceSelf, count: usize) error{failed_to_grow_list}!void {
                    return P.try_ensure_free_slots(self, count, NO_ALLOC);
                }
                /// Shrink capacity while reserving at most `n` free slots
                /// for new items. Will not shrink below list length, and
                /// does nothing if `n`is greater than the existing free space.
                pub fn shrink_cap_reserve_at_most(self: *SliceSelf, reserve_at_most: usize) void {
                    return P.shrink_cap_reserve_at_most(self, reserve_at_most, NO_ALLOC);
                }
                /// Insert `n` value slots with undefined values at the given index,
                /// moving other items at or after that index to after the new ones.
                /// Assumes free space has already been ensured, though the allocator may
                /// be used for some auxilliary purpose
                pub fn insert_slots_assume_capacity(self: *SliceSelf, idx: usize, count: usize) Range {
                    return P.insert_slots_assume_capacity(self, idx, count, NO_ALLOC);
                }
                /// Append `n` value slots with undefined values at the end of the list.
                /// Assumes free space has already been ensured, though the allocator may
                /// be used for some auxilliary purpose
                pub fn append_slots_assume_capacity(self: *SliceSelf, count: usize) Range {
                    return P.append_slots_assume_capacity(self, count, NO_ALLOC);
                }
                /// Delete one value at given index
                pub fn delete(self: *SliceSelf, idx: usize) void {
                    return P.delete(self, idx, NO_ALLOC);
                }
                /// Delete many values within given range, inclusive
                pub fn delete_range(self: *SliceSelf, range: Range) void {
                    return P.delete_range(self, range, NO_ALLOC);
                }
                /// Set list to an empty state, but retain existing capacity, if possible
                pub fn clear(self: *SliceSelf) void {
                    return P.clear(self, NO_ALLOC);
                }
                /// Set list to an empty state and return memory to allocator
                pub fn free(self: *SliceSelf) void {
                    return P.free(self, NO_ALLOC);
                }
                pub fn is_empty(self: *SliceSelf) bool {
                    return P.is_empty(self);
                }
                pub fn try_first_idx(self: *SliceSelf) ListError!usize {
                    return P.try_first_idx(self);
                }
                pub fn try_last_idx(self: *SliceSelf) ListError!usize {
                    return P.try_last_idx(self);
                }
                pub fn try_next_idx(self: *SliceSelf, this_idx: usize) ListError!usize {
                    return P.try_next_idx(self, this_idx);
                }
                pub fn try_prev_idx(self: *SliceSelf, this_idx: usize) ListError!usize {
                    return P.try_prev_idx(self, this_idx);
                }
                pub fn try_nth_next_idx(self: *SliceSelf, this_idx: usize, n: usize) ListError!usize {
                    return P.try_nth_next_idx(self, this_idx, n);
                }
                pub fn try_nth_prev_idx(self: *SliceSelf, this_idx: usize, n: usize) ListError!usize {
                    return P.try_nth_prev_idx(self, this_idx, n);
                }
                pub fn try_get(self: *SliceSelf, idx: usize) ListError!T {
                    return P.try_get(self, idx, NO_ALLOC);
                }
                pub fn try_get_ptr(self: *SliceSelf, idx: usize) ListError!*T {
                    return P.try_get_ptr(self, idx, NO_ALLOC);
                }
                pub fn try_set(self: *SliceSelf, idx: usize, val: T) ListError!void {
                    return P.try_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_move(self: *SliceSelf, old_idx: usize, new_idx: usize) ListError!void {
                    return P.try_move(self, old_idx, new_idx, NO_ALLOC);
                }
                pub fn try_move_range(self: *SliceSelf, range: Range, new_first_idx: usize) ListError!void {
                    return P.try_move_range(self, range, new_first_idx, NO_ALLOC);
                }
                pub fn nth_idx(self: *SliceSelf, n: usize) usize {
                    return P.nth_idx(self, n);
                }
                pub fn nth_idx_from_end(self: *SliceSelf, n: usize) usize {
                    return P.nth_idx_from_end(self, n);
                }
                pub fn try_nth_idx(self: *SliceSelf, n: usize) ListError!usize {
                    return P.try_nth_idx(self, n);
                }
                pub fn try_nth_idx_from_end(self: *SliceSelf, n: usize) ListError!usize {
                    return P.try_nth_idx_from_end(self, n);
                }
                pub fn get_last(self: *SliceSelf) T {
                    return P.get_last(self, NO_ALLOC);
                }
                pub fn try_get_last(self: *SliceSelf) ListError!T {
                    return P.try_get_last(self, NO_ALLOC);
                }
                pub fn get_last_ptr(self: *SliceSelf) *T {
                    return P.get_last_ptr(self, NO_ALLOC);
                }
                pub fn try_get_last_ptr(self: *SliceSelf) ListError!*T {
                    return P.try_get_last_ptr(self, NO_ALLOC);
                }
                pub fn set_last(self: *SliceSelf, val: T) void {
                    return P.set_last(self, val, NO_ALLOC);
                }
                pub fn try_set_last(self: *SliceSelf, val: T) ListError!void {
                    return P.try_set_last(self, val, NO_ALLOC);
                }
                pub fn get_first(self: *SliceSelf) T {
                    return P.get_first(self, NO_ALLOC);
                }
                pub fn try_get_first(self: *SliceSelf) ListError!T {
                    return P.try_get_first(self, NO_ALLOC);
                }
                pub fn get_first_ptr(self: *SliceSelf) *T {
                    return P.get_first_ptr(self, NO_ALLOC);
                }
                pub fn try_get_first_ptr(self: *SliceSelf) ListError!*T {
                    return P.try_get_first_ptr(self, NO_ALLOC);
                }
                pub fn set_first(self: *SliceSelf, val: T) void {
                    return P.set_first(self, val, NO_ALLOC);
                }
                pub fn try_set_first(self: *SliceSelf, val: T) ListError!void {
                    return P.try_set_first(self, val, NO_ALLOC);
                }
                pub fn get_nth(self: *SliceSelf, n: usize) T {
                    return P.get_nth(self, n, NO_ALLOC);
                }
                pub fn try_get_nth(self: *SliceSelf, n: usize) ListError!T {
                    return P.try_get_nth(self, n, NO_ALLOC);
                }
                pub fn get_nth_ptr(self: *SliceSelf, n: usize) *T {
                    return P.get_nth_ptr(self, n, NO_ALLOC);
                }
                pub fn try_get_nth_ptr(self: *SliceSelf, n: usize) ListError!*T {
                    return P.try_get_nth_ptr(self, n, NO_ALLOC);
                }
                pub fn set_nth(self: *SliceSelf, n: usize, val: T) void {
                    return P.set_nth(self, n, val, NO_ALLOC);
                }
                pub fn try_set_nth(self: *SliceSelf, n: usize, val: T) ListError!void {
                    return P.try_set_nth(self, n, val, NO_ALLOC);
                }
                pub fn get_nth_from_end(self: *SliceSelf, n: usize) T {
                    return P.get_nth_from_end(self, n, NO_ALLOC);
                }
                pub fn try_get_nth_from_end(self: *SliceSelf, n: usize) ListError!T {
                    return P.try_get_nth_from_end(self, n, NO_ALLOC);
                }
                pub fn get_nth_ptr_from_end(self: *SliceSelf, n: usize) *T {
                    return P.get_nth_ptr_from_end(self, n, NO_ALLOC);
                }
                pub fn try_get_nth_ptr_from_end(self: *SliceSelf, n: usize) ListError!*T {
                    return P.try_get_nth_ptr_from_end(self, n, NO_ALLOC);
                }
                pub fn set_nth_from_end(self: *SliceSelf, n: usize, val: T) void {
                    return P.set_nth_from_end(self, n, val, NO_ALLOC);
                }
                pub fn try_set_nth_from_end(self: *SliceSelf, n: usize, val: T) ListError!void {
                    return P.try_set_nth_from_end(self, n, val, NO_ALLOC);
                }
                pub fn set_from(self: *SliceSelf, self_idx: usize, source: *SliceSelf, source_idx: usize) void {
                    return P.set_from(self, self_idx, NO_ALLOC, source, source_idx, NO_ALLOC);
                }
                pub fn try_set_from(self: *SliceSelf, self_idx: usize, source: *SliceSelf, source_idx: usize) ListError!void {
                    return P.try_set_from(self, self_idx, NO_ALLOC, source, source_idx, NO_ALLOC);
                }
                pub fn exchange(self: *SliceSelf, self_idx: usize, other: *SliceSelf, other_idx: usize) void {
                    return P.exchange(self, self_idx, NO_ALLOC, other, other_idx, NO_ALLOC);
                }
                pub fn try_exchange(self: *SliceSelf, self_idx: usize, other: *SliceSelf, other_idx: usize) ListError!void {
                    return P.try_exchange(self, self_idx, NO_ALLOC, other, other_idx, NO_ALLOC);
                }
                pub fn overwrite(self: *SliceSelf, source_idx: usize, dest_idx: usize) void {
                    return P.overwrite(self, source_idx, dest_idx, NO_ALLOC);
                }
                pub fn try_overwrite(self: *SliceSelf, source_idx: usize, dest_idx: usize) ListError!void {
                    return P.try_overwrite(self, source_idx, dest_idx, NO_ALLOC);
                }
                pub fn reverse(self: *SliceSelf, range: P.PartialRangeIter) void {
                    return P.reverse(self, range, NO_ALLOC);
                }
                pub fn rotate(self: *SliceSelf, range: P.PartialRangeIter, delta: isize) void {
                    return P.rotate(self, range, delta, NO_ALLOC);
                }
                pub fn fill(self: *SliceSelf, range: P.PartialRangeIter, val: T) usize {
                    return P.fill(self, range, val, NO_ALLOC);
                }
                pub fn copy(source: P.RangeIter, dest: P.RangeIter) usize {
                    return P.copy(source, dest);
                }
                pub fn copy_to(self: *SliceSelf, self_range: P.PartialRangeIter, dest: P.RangeIter) usize {
                    return P.copy_to(self, self_range, dest);
                }
                pub fn is_sorted(self: *SliceSelf, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
                    return P.is_sorted(self, range, greater_than, NO_ALLOC);
                }
                pub fn is_sorted_implicit(self: *SliceSelf, range: P.PartialRangeIter) bool {
                    return P.is_sorted_implicit(self, range, NO_ALLOC);
                }
                pub fn insertion_sort(self: *SliceSelf, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
                    return P.insertion_sort(self, range, greater_than, NO_ALLOC);
                }
                pub fn insertion_sort_implicit(self: *SliceSelf, range: P.PartialRangeIter) bool {
                    return P.insertion_sort_implicit(self, range, NO_ALLOC);
                }
                pub fn quicksort(self: *SliceSelf, range: P.PartialRangeIter, greater_than: *const P.CompareFunc, less_than: *const P.CompareFunc, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
                    return P.quicksort(self, range, NO_ALLOC, greater_than, less_than, PARTITION_IDX, partition_stack);
                }
                pub fn quicksort_implicit(self: *SliceSelf, range: P.PartialRangeIter, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
                    return P.quicksort_implicit(self, range, NO_ALLOC, PARTITION_IDX, partition_stack);
                }
                pub fn range_iterator(self: *SliceSelf, range: P.PartialRangeIter) P.RangeIter {
                    return P.range_iterator(self, range);
                }
                pub fn for_each(
                    self: *SliceSelf,
                    range: P.PartialRangeIter,
                    userdata: anytype,
                    action: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
                    comptime filter: IListConcrete.FilterMode,
                    filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
                ) usize {
                    return P.for_each(self, range, userdata, action, filter, filter_func);
                }
                pub fn filter_indexes(
                    self: *SliceSelf,
                    range: P.PartialRangeIter,
                    userdata: anytype,
                    filter_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
                    comptime OUT_IDX: type,
                    out_list: IList(OUT_IDX),
                ) usize {
                    return P.filter_indexes(self, range, userdata, filter_func, OUT_IDX, out_list);
                }
                pub fn transform_values(
                    self: *SliceSelf,
                    range: P.PartialRangeIter,
                    userdata: anytype,
                    comptime OUT_TYPE: type,
                    transform_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) OUT_TYPE,
                    out_list: IList(OUT_TYPE),
                    comptime filter: IListConcrete.FilterMode,
                    filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
                ) usize {
                    return P.transform_values(self, range, userdata, OUT_TYPE, transform_func, out_list, filter, filter_func);
                }
                pub fn accumulate_result(
                    self: *SliceSelf,
                    range: P.PartialRangeIter,
                    initial_accumulation: anytype,
                    userdata: anytype,
                    accumulate_func: *const fn (item: P.IterItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
                    comptime filter: IListConcrete.FilterMode,
                    filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
                ) @TypeOf(initial_accumulation) {
                    return P.accumulate_result(self, range, initial_accumulation, userdata, accumulate_func, filter, filter_func);
                }
                pub fn ensure_free_slots(self: *SliceSelf, count: usize) void {
                    return P.ensure_free_slots(self, count, NO_ALLOC);
                }
                pub fn append_slots(self: *SliceSelf, count: usize) Range {
                    return P.append_slots(self, count, NO_ALLOC);
                }
                pub fn try_append_slots(self: *SliceSelf, count: usize) ListError!Range {
                    return P.try_append_slots(self, count, NO_ALLOC);
                }
                pub fn append_zig_slice(self: *SliceSelf, source: []const T) Range {
                    return P.append_zig_slice(self, source, NO_ALLOC);
                }
                pub fn try_append_zig_slice(self: *SliceSelf, source: []const T) ListError!Range {
                    return P.try_append_zig_slice(self, source, NO_ALLOC);
                }
                pub fn append(self: *SliceSelf, val: T) usize {
                    return P.append(self, val, NO_ALLOC);
                }
                pub fn try_append(self: *SliceSelf, val: T) ListError!usize {
                    return P.try_append(self, val, NO_ALLOC);
                }
                pub fn append_many(self: *SliceSelf, source: P.RangeIter) Range {
                    return P.append_many(self, NO_ALLOC, source);
                }
                pub fn try_append_many(self: *SliceSelf, source: P.RangeIter) ListError!Range {
                    return P.try_append_many(self, NO_ALLOC, source);
                }
                pub fn insert_slots(self: *SliceSelf, idx: usize, count: usize) Range {
                    return P.insert_slots(self, idx, count, NO_ALLOC);
                }
                pub fn try_insert_slots(self: *SliceSelf, idx: usize, count: usize) ListError!Range {
                    return P.try_insert_slots(self, idx, count, NO_ALLOC);
                }
                pub fn insert_zig_slice(self: *SliceSelf, idx: usize, source: []T) Range {
                    return P.insert_zig_slice(self, idx, source, NO_ALLOC);
                }
                pub fn try_insert_zig_slice(self: *SliceSelf, idx: usize, source: []T) ListError!Range {
                    return P.try_insert_zig_slice(self, idx, source, NO_ALLOC);
                }
                pub fn insert(self: *SliceSelf, idx: usize, val: T) usize {
                    return P.insert(self, idx, val, NO_ALLOC);
                }
                pub fn try_insert(self: *SliceSelf, idx: usize, val: T) ListError!usize {
                    return P.try_insert(self, idx, val, NO_ALLOC);
                }
                pub fn insert_many(self: *SliceSelf, idx: usize, source: P.RangeIter) Range {
                    return P.insert_many(self, idx, NO_ALLOC, source);
                }
                pub fn try_insert_many(self: *SliceSelf, idx: usize, source: P.RangeIter) ListError!Range {
                    return P.try_insert_many(self, idx, NO_ALLOC, source);
                }
                pub fn try_delete_range(self: *SliceSelf, range: Range) ListError!void {
                    return P.try_delete_range(self, range, NO_ALLOC);
                }
                pub fn delete_many(self: *SliceSelf, range: P.PartialRangeIter) void {
                    return P.delete_many(self, range);
                }
                pub fn try_delete_many(self: *SliceSelf, range: P.PartialRangeIter) ListError!void {
                    return P.try_delete_many(self, range);
                }
                pub fn try_delete(self: *SliceSelf, idx: usize) ListError!void {
                    return P.try_delete(self, idx, NO_ALLOC);
                }
                pub fn swap_delete(self: *SliceSelf, idx: usize) void {
                    return P.swap_delete(self, idx, NO_ALLOC);
                }
                pub fn try_swap_delete(self: *SliceSelf, idx: usize) ListError!void {
                    return P.try_swap_delete(self, idx, NO_ALLOC);
                }
                pub fn swap_delete_many(self: *SliceSelf, range: P.PartialRangeIter) void {
                    return P.swap_delete_many(self, range);
                }
                pub fn try_swap_delete_many(self: *SliceSelf, range: P.PartialRangeIter) ListError!void {
                    return P.try_swap_delete_many(self, range);
                }
                pub fn remove_range(self: *SliceSelf, self_range: P.PartialRangeIter, dest: *SliceSelf, dest_alloc: Allocator) Range {
                    return P.remove_range(self, self_range, dest, dest_alloc);
                }
                pub fn try_remove_range(self: *SliceSelf, self_range: P.PartialRangeIter, dest: *SliceSelf, dest_alloc: Allocator) ListError!Range {
                    return P.try_remove_range(self, self_range, dest, dest_alloc);
                }
                pub fn remove(self: *SliceSelf, idx: usize) T {
                    return P.remove(self, idx, NO_ALLOC);
                }
                pub fn try_remove(self: *SliceSelf, idx: usize) ListError!T {
                    return P.try_remove(self, idx, NO_ALLOC);
                }
                pub fn swap_remove(self: *SliceSelf, idx: usize) T {
                    return P.swap_remove(self, idx, NO_ALLOC);
                }
                pub fn try_swap_remove(self: *SliceSelf, idx: usize) ListError!T {
                    return P.try_swap_remove(self, idx, NO_ALLOC);
                }
                pub fn pop(self: *SliceSelf) T {
                    return P.pop(self, NO_ALLOC);
                }
                pub fn try_pop(self: *SliceSelf) ListError!T {
                    return P.try_pop(self, NO_ALLOC);
                }
                pub fn pop_many(self: *SliceSelf, count: usize, dest: *SliceSelf, dest_alloc: Allocator) Range {
                    return P.pop_many(self, count, NO_ALLOC, dest, dest_alloc);
                }
                pub fn try_pop_many(self: *SliceSelf, count: usize, dest: *SliceSelf, dest_alloc: Allocator) ListError!Range {
                    return P.try_pop_many(self, count, NO_ALLOC, dest, dest_alloc);
                }
                pub fn sorted_insert(
                    self: *SliceSelf,
                    val: T,
                    equal_func: *const fn (this_val: T, find_val: T) bool,
                    greater_than_func: *const fn (this_val: T, find_val: T) bool,
                ) usize {
                    return P.sorted_insert(self, NO_ALLOC, val, equal_func, greater_than_func);
                }
                pub fn sorted_insert_implicit(self: *SliceSelf, val: T) usize {
                    return P.sorted_insert_implicit(self, val, NO_ALLOC);
                }
                pub fn sorted_insert_index(
                    self: *SliceSelf,
                    val: T,
                    equal_func: *const fn (this_val: T, find_val: T) bool,
                    greater_than_func: *const fn (this_val: T, find_val: T) bool,
                ) IListConcrete.InsertIndexResult {
                    return P.sorted_insert_index(self, NO_ALLOC, val, equal_func, greater_than_func);
                }
                pub fn sorted_insert_index_implicit(self: *SliceSelf, val: T) IListConcrete.InsertIndexResult {
                    return P.sorted_insert_index_implicit(self, val, NO_ALLOC);
                }
                pub fn sorted_search(
                    self: *SliceSelf,
                    val: T,
                    equal_func: *const fn (this_val: T, find_val: T) bool,
                    greater_than_func: *const fn (this_val: T, find_val: T) bool,
                ) IListConcrete.SearchResult {
                    return P.sorted_search(self, NO_ALLOC, val, equal_func, greater_than_func);
                }
                pub fn sorted_search_implicit(self: *SliceSelf, val: T) IListConcrete.SearchResult {
                    return P.sorted_search_implicit(self, val, NO_ALLOC);
                }
                pub fn sorted_set_and_resort(self: *SliceSelf, idx: usize, val: T, greater_than_func: *const fn (this_val: T, find_val: T) bool) usize {
                    return P.sorted_set_and_resort(self, idx, val, NO_ALLOC, greater_than_func);
                }
                pub fn sorted_set_and_resort_implicit(self: *SliceSelf, idx: usize, val: T) usize {
                    return P.sorted_set_and_resort_implicit(self, idx, val, NO_ALLOC);
                }
                pub fn search(self: *SliceSelf, find_val: anytype, equal_func: *const fn (this_val: T, find_val: @TypeOf(find_val)) bool) IListConcrete.SearchResult {
                    return P.search(self, find_val, NO_ALLOC, equal_func);
                }
                pub fn search_implicit(self: *SliceSelf, find_val: anytype) IListConcrete.SearchResult {
                    return P.search_implicit(self, find_val, NO_ALLOC);
                }
                pub fn add_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.add_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_add_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_add_get(self, idx, val, NO_ALLOC);
                }
                pub fn add_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.add_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_add_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_add_set(self, idx, val, NO_ALLOC);
                }
                pub fn subtract_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.subtract_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_subtract_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_subtract_get(self, idx, val, NO_ALLOC);
                }
                pub fn subtract_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.subtract_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_subtract_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_subtract_set(self, idx, val, NO_ALLOC);
                }
                pub fn multiply_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.multiply_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_multiply_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_multiply_get(self, idx, val, NO_ALLOC);
                }
                pub fn multiply_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.multiply_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_multiply_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_multiply_set(self, idx, val, NO_ALLOC);
                }
                pub fn divide_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.divide_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_divide_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_divide_get(self, idx, val, NO_ALLOC);
                }
                pub fn divide_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.divide_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_divide_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_divide_set(self, idx, val, NO_ALLOC);
                }
                pub fn modulo_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.modulo_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_modulo_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_modulo_get(self, idx, val, NO_ALLOC);
                }
                pub fn modulo_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.modulo_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_modulo_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_modulo_set(self, idx, val, NO_ALLOC);
                }
                pub fn mod_rem_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.mod_rem_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_mod_rem_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_mod_rem_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_and_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.bit_and_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_and_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_and_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_and_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.bit_and_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_and_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_and_set(self, idx, val, NO_ALLOC);
                }
                pub fn bit_or_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.bit_or_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_or_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_or_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_or_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.bit_or_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_or_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_or_set(self, idx, val, NO_ALLOC);
                }
                pub fn bit_xor_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.bit_xor_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_xor_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_xor_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_xor_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.bit_xor_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_xor_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_xor_set(self, idx, val, NO_ALLOC);
                }
                pub fn bit_invert_get(self: *SliceSelf, idx: usize) T {
                    return P.bit_invert_get(self, idx, NO_ALLOC);
                }
                pub fn try_bit_invert_get(self: *SliceSelf, idx: usize) ListError!T {
                    return P.try_bit_invert_get(self, idx, NO_ALLOC);
                }
                pub fn bit_invert_set(self: *SliceSelf, idx: usize) void {
                    return P.bit_invert_set(self, idx, NO_ALLOC);
                }
                pub fn try_bit_invert_set(self: *SliceSelf, idx: usize) ListError!void {
                    return P.try_bit_invert_set(self, idx, NO_ALLOC);
                }
                pub fn bool_and_get(self: *SliceSelf, idx: usize, val: bool) T {
                    return P.bool_and_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_and_get(self: *SliceSelf, idx: usize, val: bool) ListError!T {
                    return P.try_bool_and_get(self, idx, val, NO_ALLOC);
                }
                pub fn bool_and_set(self: *SliceSelf, idx: usize, val: bool) void {
                    return P.bool_and_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_and_set(self: *SliceSelf, idx: usize, val: bool) ListError!void {
                    return P.try_bool_and_set(self, idx, val, NO_ALLOC);
                }
                pub fn bool_or_get(self: *SliceSelf, idx: usize, val: bool) T {
                    return P.bool_or_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_or_get(self: *SliceSelf, idx: usize, val: bool) ListError!T {
                    return P.try_bool_or_get(self, idx, val, NO_ALLOC);
                }
                pub fn bool_or_set(self: *SliceSelf, idx: usize, val: bool) void {
                    return P.bool_or_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_or_set(self: *SliceSelf, idx: usize, val: bool) ListError!void {
                    return P.try_bool_or_set(self, idx, val, NO_ALLOC);
                }
                pub fn bool_xor_get(self: *SliceSelf, idx: usize, val: bool) T {
                    return P.bool_xor_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_xor_get(self: *SliceSelf, idx: usize, val: bool) ListError!T {
                    return P.try_bool_xor_get(self, idx, val, NO_ALLOC);
                }
                pub fn bool_xor_set(self: *SliceSelf, idx: usize, val: bool) void {
                    return P.bool_xor_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_xor_set(self: *SliceSelf, idx: usize, val: bool) ListError!void {
                    return P.try_bool_xor_set(self, idx, val, NO_ALLOC);
                }
                pub fn bool_invert_get(self: *SliceSelf, idx: usize) T {
                    return P.bool_invert_get(self, idx, NO_ALLOC);
                }
                pub fn try_bool_invert_get(self: *SliceSelf, idx: usize) ListError!T {
                    return P.try_bool_invert_get(self, idx, NO_ALLOC);
                }
                pub fn bool_invert_set(self: *SliceSelf, idx: usize) void {
                    return P.bool_invert_set(self, idx, NO_ALLOC);
                }
                pub fn try_bool_invert_set(self: *SliceSelf, idx: usize) ListError!void {
                    return P.try_bool_invert_set(self, idx, NO_ALLOC);
                }
                pub fn bit_l_shift_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.bit_l_shift_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_l_shift_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_l_shift_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_l_shift_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.bit_l_shift_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_l_shift_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_l_shift_set(self, idx, val, NO_ALLOC);
                }
                pub fn bit_r_shift_get(self: *SliceSelf, idx: usize, val: anytype) T {
                    return P.bit_r_shift_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_r_shift_get(self: *SliceSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_r_shift_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_r_shift_set(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.bit_r_shift_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_r_shift_set(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_r_shift_set(self, idx, val, NO_ALLOC);
                }
                pub fn less_than_get(self: *SliceSelf, idx: usize, val: anytype) bool {
                    return P.less_than_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_less_than_get(self: *SliceSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_less_than_get(self, idx, val, NO_ALLOC);
                }
                pub fn less_than_equal_get(self: *SliceSelf, idx: usize, val: anytype) bool {
                    return P.less_than_equal_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_less_than_equal_get(self: *SliceSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_less_than_equal_get(self, idx, val, NO_ALLOC);
                }
                pub fn greater_than_get(self: *SliceSelf, idx: usize, val: anytype) bool {
                    return P.greater_than_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_greater_than_get(self: *SliceSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_greater_than_get(self, idx, val, NO_ALLOC);
                }
                pub fn greater_than_equal_get(self: *SliceSelf, idx: usize, val: anytype) bool {
                    return P.greater_than_equal_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_greater_than_equal_get(self: *SliceSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_greater_than_equal_get(self, idx, val, NO_ALLOC);
                }
                pub fn equals_get(self: *SliceSelf, idx: usize, val: anytype) bool {
                    return P.equals_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_equals_get(self: *SliceSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_equals_get(self, idx, val, NO_ALLOC);
                }
                pub fn not_equals_get(self: *SliceSelf, idx: usize, val: anytype) bool {
                    return P.not_equals_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_not_equals_get(self: *SliceSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_not_equals_get(self, idx, val, NO_ALLOC);
                }
                pub fn get_min_in_range(self: *SliceSelf, range: P.PartialRangeIter) P.Item {
                    return P.get_min_in_range(self, range);
                }
                pub fn try_get_min_in_range(self: *SliceSelf, range: P.PartialRangeIter) ListError!P.Item {
                    return P.try_get_min_in_range(self, range);
                }
                pub fn get_max_in_range(self: *SliceSelf, range: P.PartialRangeIter) P.Item {
                    return P.get_max_in_range(self, range);
                }
                pub fn try_get_max_in_range(self: *SliceSelf, range: P.PartialRangeIter) ListError!P.Item {
                    return P.try_get_max_in_range(self, range);
                }
                pub fn get_clamped(self: *SliceSelf, idx: usize, min: T, max: T) T {
                    return P.get_clamped(self, idx, min, max, NO_ALLOC);
                }
                pub fn try_get_clamped(self: *SliceSelf, idx: usize, min: T, max: T) ListError!T {
                    return P.try_get_clamped(self, idx, min, max, NO_ALLOC);
                }
                pub fn set_clamped(self: *SliceSelf, idx: usize, min: T, max: T) void {
                    return P.set_clamped(self, idx, min, max, NO_ALLOC);
                }
                pub fn try_set_clamped(self: *SliceSelf, idx: usize, min: T, max: T) ListError!void {
                    return P.try_set_clamped(self, idx, min, max, NO_ALLOC);
                }
                pub fn set_report_change(self: *SliceSelf, idx: usize, val: T) bool {
                    return P.set_report_change(self, idx, val, NO_ALLOC);
                }
                pub fn try_set_report_change(self: *SliceSelf, idx: usize, val: T) bool {
                    return P.try_set_report_change(self, idx, val, NO_ALLOC);
                }
                pub fn get_unsafe_cast(self: *SliceSelf, idx: usize, comptime TT: type) TT {
                    return P.get_unsafe_cast(self, idx, TT, NO_ALLOC);
                }
                pub fn try_get_unsafe_cast(self: *SliceSelf, idx: usize, comptime TT: type) ListError!TT {
                    return P.try_get_unsafe_cast(self, idx, TT, NO_ALLOC);
                }
                pub fn get_unsafe_ptr_cast(self: *SliceSelf, idx: usize, comptime TT: type) *TT {
                    return P.get_unsafe_ptr_cast(self, idx, TT, NO_ALLOC);
                }
                pub fn try_get_unsafe_ptr_cast(self: *SliceSelf, idx: usize, comptime TT: type) ListError!*TT {
                    return P.try_get_unsafe_ptr_cast(self, idx, TT, NO_ALLOC);
                }
                pub fn set_unsafe_cast(self: *SliceSelf, idx: usize, val: anytype) void {
                    return P.set_unsafe_cast(self, idx, val, NO_ALLOC);
                }
                pub fn try_set_unsafe_cast(self: *SliceSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_set_unsafe_cast(self, idx, val, NO_ALLOC);
                }
                pub fn set_unsafe_cast_report_change(self: *SliceSelf, idx: usize, val: anytype) bool {
                    return P.set_unsafe_cast_report_change(self, idx, val, NO_ALLOC);
                }
                pub fn try_set_unsafe_cast_report_change(self: *SliceSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_set_unsafe_cast_report_change(self, idx, val, NO_ALLOC);
                }
            };
        }

        pub fn List(comptime T: type) type {
            return struct {
                const ListSelf = @This();
                const SIZE = @sizeOf(T);
                const ALIGN = @alignOf(T);

                slice: Slice(T) = Slice(T){},
                cap: LEN_UINT = 0,

                pub fn init_empty() ListSelf {
                    return ListSelf{};
                }

                pub fn init_capacity(cap: usize) ListSelf {
                    const block = claim_data_block(@intCast(cap * SIZE), ALIGN);
                    const addr = Addr{ .val = block.start };
                    return ListSelf{
                        .slice = addr.to_ptr(T).to_slice(0),
                        .cap = @intCast(cap),
                    };
                }

                inline fn to_block(self: ListSelf) Block {
                    return Block{
                        .start = self.slice.ptr.addr.val,
                        .len = self.cap,
                    };
                }

                pub fn zig_slice(self: ListSelf) []T {
                    return self.slice.zig_slice();
                }

                fn zig_slice_no_lock(self: ListSelf) []T {
                    return self.slice.zig_slice_no_lock();
                }

                fn zig_sub_slice_no_lock(self: ListSelf, start: usize, end_exclude: usize) []T {
                    return self.slice.zig_sub_slice_no_lock(start, end_exclude);
                }

                pub fn zig_sub_slice(self: ListSelf, start: usize, end_exclude: usize) []T {
                    return self.slice.zig_sub_slice(start, end_exclude);
                }

                pub fn sub_slice(self: ListSelf, start: usize, end_exclude: usize) Slice(T) {
                    return self.slice.sub_slice(start, end_exclude);
                }

                //*** BEGIN PROTOTYPE ***
                const P_FUNCS = struct {
                    fn p_get(self: *ListSelf, idx: usize, _: void) T {
                        return self.slice.get(idx);
                    }
                    fn p_get_ptr(self: *ListSelf, idx: usize, _: void) *T {
                        return self.slice.get_ptr(idx);
                    }
                    fn p_set(self: *ListSelf, idx: usize, val: T, _: void) void {
                        return self.slice.set(idx, val);
                    }
                    fn p_move(self: *ListSelf, old_idx: usize, new_idx: usize, _: void) void {
                        lock_data();
                        const slice = self.zig_slice_no_lock();
                        Utils.slice_move_one(slice, old_idx, new_idx);
                        unlock_data();
                    }
                    fn p_move_range(self: *ListSelf, range: IList.Range, new_first_idx: usize, _: void) void {
                        lock_data();
                        const slice = self.zig_slice_no_lock();
                        Utils.slice_move_many(slice, range.first_idx, range.last_idx, new_first_idx);
                        unlock_data();
                    }
                    fn p_try_ensure_free_slots(self: *ListSelf, count: usize, _: void) error{failed_to_grow_list}!void {
                        const have = self.cap - self.slice.len;
                        if (have >= count) {
                            return;
                        }
                        const new_cap = (self.slice.len + count);
                        self.realloc(new_cap);
                        return;
                    }
                    fn p_shrink_cap_reserve_at_most(self: *ListSelf, reserve_at_most: usize, _: void) void {
                        const space: usize = @intCast(self.cap - self.slice.len);
                        if (space <= reserve_at_most) return;
                        const new_cap = Types.intcast(self.slice.len, usize) + reserve_at_most;
                        self.realloc(new_cap);
                    }
                    fn p_append_slots_assume_capacity(self: *ListSelf, count: usize, _: void) IList.Range {
                        Assert.assert_with_reason(count <= self.cap - self.slice.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.slice.len, self.cap, self.cap - self.slice.len, count, count });
                        const first: usize = @intCast(self.slice.len);
                        self.slice.len += @intCast(count);
                        return IList.Range.new_range(first, @intCast(self.slice.len - 1));
                    }
                    fn p_insert_slots_assume_capacity(self: *ListSelf, idx: usize, count: usize, alloc: void) IList.Range {
                        if (idx == self.slice.len) {
                            return p_append_slots_assume_capacity(self, count, alloc);
                        }
                        Assert.assert_with_reason(count <= self.cap - self.slice.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.slice.len, self.cap, self.cap - self.slice.len, count, count });
                        lock_data();
                        Utils.mem_insert(self.slice.ptr.get_many_item_ptr_no_lock(), &self.slice.len, idx, count);
                        unlock_data();
                        return IList.Range.new_range(idx, idx + count - 1);
                    }
                    fn p_trim_len(self: *ListSelf, trim_n: usize, _: void) void {
                        self.slice.len -= @intCast(trim_n);
                    }
                    fn p_delete(self: *ListSelf, idx: usize, _: void) void {
                        if (idx == self.slice.len - 1) {
                            self.slice.len -= 1;
                            return;
                        }
                        lock_data();
                        Utils.mem_remove(self.slice.ptr.get_many_item_ptr_no_lock(), &self.slice.len, idx, 1);
                        unlock_data();
                    }
                    fn p_delete_range(self: *ListSelf, range: IList.Range, _: void) void {
                        const rlen = range.consecutive_len();
                        if (range.last_idx == self.slice.len - 1) {
                            self.slice.len -= @intCast(rlen);
                            return;
                        }
                        lock_data();
                        Utils.mem_remove(self.slice.ptr.get_many_item_ptr_no_lock(), &self.slice.len, range.first_idx, rlen);
                        unlock_data();
                    }
                    fn p_clear(self: *ListSelf, _: void) void {
                        self.slice.len = 0;
                    }
                    fn p_free(self: *ListSelf, _: void) void {
                        const block = self.to_block();
                        release_data_block(block);
                        self.cap = 0;
                        self.slice.len = 0;
                        self.slice.ptr.addr.val = math.maxInt(LEN_UINT);
                    }
                    fn p_has_native_slice(_: *ListSelf) bool {
                        return true;
                    }
                    fn p_native_slice(self: *ListSelf, range: IListConcrete.Range) []T {
                        self.zig_sub_slice(range.first_idx, range.last_idx + 1);
                    }
                    fn p_prefer_linear_ops(_: *ListSelf) bool {
                        return false;
                    }
                    fn p_all_indexes_zero_to_len_valid(_: *ListSelf) bool {
                        return true;
                    }
                    fn p_consecutive_indexes_in_order(_: *ListSelf) bool {
                        return true;
                    }
                    fn p_ensure_free_doesnt_change_cap(_: *ListSelf) bool {
                        return false;
                    }
                    fn p_always_invalid_idx(_: *ListSelf) usize {
                        return math.maxInt(usize);
                    }
                    fn p_len(self: *ListSelf) usize {
                        return @intCast(self.slice.len);
                    }
                    fn p_cap(self: *ListSelf) usize {
                        return @intCast(self.cap);
                    }
                    fn p_first_idx(_: *ListSelf) usize {
                        return 0;
                    }
                    fn p_last_idx(self: *ListSelf) usize {
                        return Types.intcast(self.slice.len, usize) -% 1;
                    }
                    fn p_next_idx(_: *ListSelf, this_idx: usize) usize {
                        return this_idx + 1;
                    }
                    fn p_nth_next_idx(_: *ListSelf, this_idx: usize, n: usize) usize {
                        return this_idx + n;
                    }
                    fn p_prev_idx(_: *ListSelf, this_idx: usize) usize {
                        return this_idx -% 1;
                    }
                    fn p_nth_prev_idx(_: *ListSelf, this_idx: usize, n: usize) usize {
                        return this_idx -% n;
                    }
                    fn p_idx_valid(self: *ListSelf, idx: usize) bool {
                        return idx < self.slice.len;
                    }
                    fn p_range_valid(self: *ListSelf, range: IListConcrete.Range) bool {
                        return range.first_idx <= range.last_idx and range.last_idx < self.slice.len;
                    }
                    fn p_idx_in_range(_: *ListSelf, idx: usize, range: IListConcrete.Range) bool {
                        return range.first_idx <= idx and idx <= range.last_idx;
                    }
                    fn p_split_range(_: *ListSelf, range: IListConcrete.Range) usize {
                        return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
                    }
                    fn p_range_len(_: *ListSelf, range: IListConcrete.Range) usize {
                        return (range.last_idx - range.first_idx) + 1;
                    }
                };
                const VFX = IListConcrete.ConcreteTableValueFuncs(T, *ListSelf, void){
                    .get = P_FUNCS.p_get,
                    .get_ptr = P_FUNCS.p_get_ptr,
                    .set = P_FUNCS.p_set,
                    .move = P_FUNCS.p_move,
                    .move_range = P_FUNCS.p_move_range,
                    .try_ensure_free_slots = P_FUNCS.p_try_ensure_free_slots,
                    .shrink_cap_reserve_at_most = P_FUNCS.p_shrink_cap_reserve_at_most,
                    .append_slots_assume_capacity = P_FUNCS.p_append_slots_assume_capacity,
                    .insert_slots_assume_capacity = P_FUNCS.p_insert_slots_assume_capacity,
                    .trim_len = P_FUNCS.p_trim_len,
                    .delete = P_FUNCS.p_delete,
                    .delete_range = P_FUNCS.p_delete_range,
                    .clear = P_FUNCS.p_clear,
                    .free = P_FUNCS.p_free,
                };
                const NFX = IListConcrete.ConcreteTableNativeSliceFuncs(T, *ListSelf){
                    .has_native_slice = P_FUNCS.p_has_native_slice,
                    .native_slice = P_FUNCS.p_native_slice,
                };
                const IFX = IListConcrete.ConcreteTableIndexFuncs(*ListSelf){
                    .all_indexes_zero_to_len_valid = P_FUNCS.p_all_indexes_zero_to_len_valid,
                    .always_invalid_idx = P_FUNCS.p_always_invalid_idx,
                    .cap = P_FUNCS.p_cap,
                    .consecutive_indexes_in_order = P_FUNCS.p_consecutive_indexes_in_order,
                    .ensure_free_doesnt_change_cap = P_FUNCS.p_ensure_free_doesnt_change_cap,
                    .first_idx = P_FUNCS.p_first_idx,
                    .idx_in_range = P_FUNCS.p_idx_in_range,
                    .idx_valid = P_FUNCS.p_idx_valid,
                    .last_idx = P_FUNCS.p_last_idx,
                    .len = P_FUNCS.p_len,
                    .next_idx = P_FUNCS.p_next_idx,
                    .nth_next_idx = P_FUNCS.p_nth_next_idx,
                    .nth_prev_idx = P_FUNCS.p_nth_prev_idx,
                    .prefer_linear_ops = P_FUNCS.p_prefer_linear_ops,
                    .prev_idx = P_FUNCS.p_prev_idx,
                    .range_len = P_FUNCS.p_range_len,
                    .range_valid = P_FUNCS.p_range_valid,
                    .split_range = P_FUNCS.p_split_range,
                };
                const P = IListConcrete.CreateConcretePrototype(T, *ListSelf, void, VFX, IFX, NFX);
                const VTABLE = P.VTABLE_ALLOC_STATIC(true, false, false, math.maxInt(usize), void{});
                //*** END PROTOTYPE***

                pub fn interface(self: *ListSelf) IList.IList(T) {
                    return IList.IList(T){
                        .alloc = DummyAlloc.allocator_panic,
                        .object = @ptrCast(self),
                        .vtable = &VTABLE,
                    };
                }

                pub fn realloc(self: *ListSelf, new_cap: usize) void {
                    const size = SIZE * new_cap;
                    const new_block = claim_data_block(@intCast(size), ALIGN);
                    const old_block = self.to_block();
                    const min_len = @min(self.slice.len, new_cap);
                    const min_len_u8 = min_len * SIZE;
                    lock_data();
                    @memcpy(STATE.data_ptr[new_block.start .. new_block.start + min_len_u8], STATE.data_ptr[old_block.start .. old_block.start + min_len_u8]);
                    unlock_data();
                    release_data_block(old_block);
                    self.slice.ptr.addr.val = new_block.start;
                    self.slice.len = min_len;
                    self.cap = @intCast(new_block.len);
                }

                /// Return the number of items in the list
                pub fn len_usize(self: *ListSelf) usize {
                    return P.len(self);
                }
                /// Reduce the number of items in the list by
                /// dropping/deleting them from the end of the list
                pub fn trim_len(self: *ListSelf, trim_n: usize) void {
                    return P.trim_len(self, trim_n, NO_ALLOC);
                }
                /// Return the total number of items the list can hold
                /// without reallocation
                pub fn cap_usize(self: *ListSelf) usize {
                    return P.cap(self);
                }
                /// Return the first index in the list
                pub fn first_idx(self: *ListSelf) usize {
                    return P.first_idx(self);
                }
                /// Return the last valid index in the list
                pub fn last_idx(self: *ListSelf) usize {
                    return P.last_idx(self);
                }
                /// Return the index directly after the given index in the list
                pub fn next_idx(self: *ListSelf, this_idx: usize) usize {
                    return P.next_idx(self, this_idx);
                }
                /// Return the index `n` places after the given index in the list,
                /// which may be 0 (returning the given index)
                pub fn nth_next_idx(self: *ListSelf, this_idx: usize, n: usize) usize {
                    return P.nth_next_idx(self, this_idx, n);
                }
                /// Return the index directly before the given index in the list
                pub fn prev_idx(self: *ListSelf, this_idx: usize) usize {
                    return P.prev_idx(self, this_idx);
                }
                /// Return the index `n` places before the given index in the list,
                /// which may be 0 (returning the given index)
                pub fn nth_prev_idx(self: *ListSelf, this_idx: usize, n: usize) usize {
                    return P.nth_prev_idx(self, this_idx, n);
                }
                /// Return `true` if the index is valid for the current state
                /// of the list, `false` otherwise
                pub fn idx_valid(self: *ListSelf, idx: usize) bool {
                    return P.idx_valid(self, idx);
                }
                /// Return `true` if the range is valid for the current state
                /// of the list, `false` otherwise. The first index must
                /// come before or be equal to the last index, and all
                /// indexes in between must also be valid
                pub fn range_valid(self: *ListSelf, range: Range) bool {
                    return P.range_valid(self, range);
                }
                /// Return whether the given index falls within the given range,
                /// inclusive
                pub fn idx_in_range(self: *ListSelf, range: Range, idx: usize) bool {
                    return P.idx_in_range(self, range, idx);
                }
                /// Split a range roughly in half, returning an index
                /// as close to the true center point as possible.
                /// Implementations may choose not to return an index
                /// close to the actual middle of the range if
                /// finding that middle index is expensive
                pub fn split_range(self: *ListSelf, range: Range) usize {
                    return P.split_range(self, range);
                }
                /// Return the number of indexes included within a range,
                /// inclusive of the last index
                pub fn range_len(self: *ListSelf, range: Range) usize {
                    return P.range_len(self, range);
                }
                /// Return the value at the given index
                pub fn get(self: *ListSelf, idx: usize) T {
                    return P.get(self, idx, NO_ALLOC);
                }
                /// Return a pointer to the value at a given index
                pub fn get_ptr(self: *ListSelf, idx: usize) *T {
                    return P.get_ptr(self, idx, NO_ALLOC);
                }
                /// Set the value at the given index
                pub fn set(self: *ListSelf, idx: usize, val: T) void {
                    return P.set(self, idx, val, NO_ALLOC);
                }
                /// Move one value to a new location within the list,
                /// moving the values in between the old and new location
                /// out of the way while maintaining their order
                pub fn move(self: *ListSelf, old_idx: usize, new_idx: usize) void {
                    return P.move(self, old_idx, new_idx, NO_ALLOC);
                }
                /// Move a range of values to a new location within the list,
                /// moving the values in between the old and new location
                /// out of the way while maintaining their order
                pub fn move_range(self: *ListSelf, range: Range, new_first_idx: usize) void {
                    return P.move_range(self, range, new_first_idx, NO_ALLOC);
                }
                /// Attempt to ensure at least 'n' free slots exist for adding new items,
                /// returning error `failed_to_grow_list` if adding `n` new items will
                /// definitely cause undefined behavior or some other error
                pub fn try_ensure_free_slots(self: *ListSelf, count: usize) error{failed_to_grow_list}!void {
                    return P.try_ensure_free_slots(self, count, NO_ALLOC);
                }
                /// Shrink capacity while reserving at most `n` free slots
                /// for new items. Will not shrink below list length, and
                /// does nothing if `n`is greater than the existing free space.
                pub fn shrink_cap_reserve_at_most(self: *ListSelf, reserve_at_most: usize) void {
                    return P.shrink_cap_reserve_at_most(self, reserve_at_most, NO_ALLOC);
                }
                /// Insert `n` value slots with undefined values at the given index,
                /// moving other items at or after that index to after the new ones.
                /// Assumes free space has already been ensured, though the allocator may
                /// be used for some auxilliary purpose
                pub fn insert_slots_assume_capacity(self: *ListSelf, idx: usize, count: usize) Range {
                    return P.insert_slots_assume_capacity(self, idx, count, NO_ALLOC);
                }
                /// Append `n` value slots with undefined values at the end of the list.
                /// Assumes free space has already been ensured, though the allocator may
                /// be used for some auxilliary purpose
                pub fn append_slots_assume_capacity(self: *ListSelf, count: usize) Range {
                    return P.append_slots_assume_capacity(self, count, NO_ALLOC);
                }
                /// Delete one value at given index
                pub fn delete(self: *ListSelf, idx: usize) void {
                    return P.delete(self, idx, NO_ALLOC);
                }
                /// Delete many values within given range, inclusive
                pub fn delete_range(self: *ListSelf, range: Range) void {
                    return P.delete_range(self, range, NO_ALLOC);
                }
                /// Set list to an empty state, but retain existing capacity, if possible
                pub fn clear(self: *ListSelf) void {
                    return P.clear(self, NO_ALLOC);
                }
                /// Set list to an empty state and return memory to allocator
                pub fn free(self: *ListSelf) void {
                    return P.free(self, NO_ALLOC);
                }
                pub fn is_empty(self: *ListSelf) bool {
                    return P.is_empty(self);
                }
                pub fn try_first_idx(self: *ListSelf) ListError!usize {
                    return P.try_first_idx(self);
                }
                pub fn try_last_idx(self: *ListSelf) ListError!usize {
                    return P.try_last_idx(self);
                }
                pub fn try_next_idx(self: *ListSelf, this_idx: usize) ListError!usize {
                    return P.try_next_idx(self, this_idx);
                }
                pub fn try_prev_idx(self: *ListSelf, this_idx: usize) ListError!usize {
                    return P.try_prev_idx(self, this_idx);
                }
                pub fn try_nth_next_idx(self: *ListSelf, this_idx: usize, n: usize) ListError!usize {
                    return P.try_nth_next_idx(self, this_idx, n);
                }
                pub fn try_nth_prev_idx(self: *ListSelf, this_idx: usize, n: usize) ListError!usize {
                    return P.try_nth_prev_idx(self, this_idx, n);
                }
                pub fn try_get(self: *ListSelf, idx: usize) ListError!T {
                    return P.try_get(self, idx, NO_ALLOC);
                }
                pub fn try_get_ptr(self: *ListSelf, idx: usize) ListError!*T {
                    return P.try_get_ptr(self, idx, NO_ALLOC);
                }
                pub fn try_set(self: *ListSelf, idx: usize, val: T) ListError!void {
                    return P.try_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_move(self: *ListSelf, old_idx: usize, new_idx: usize) ListError!void {
                    return P.try_move(self, old_idx, new_idx, NO_ALLOC);
                }
                pub fn try_move_range(self: *ListSelf, range: Range, new_first_idx: usize) ListError!void {
                    return P.try_move_range(self, range, new_first_idx, NO_ALLOC);
                }
                pub fn nth_idx(self: *ListSelf, n: usize) usize {
                    return P.nth_idx(self, n);
                }
                pub fn nth_idx_from_end(self: *ListSelf, n: usize) usize {
                    return P.nth_idx_from_end(self, n);
                }
                pub fn try_nth_idx(self: *ListSelf, n: usize) ListError!usize {
                    return P.try_nth_idx(self, n);
                }
                pub fn try_nth_idx_from_end(self: *ListSelf, n: usize) ListError!usize {
                    return P.try_nth_idx_from_end(self, n);
                }
                pub fn get_last(self: *ListSelf) T {
                    return P.get_last(self, NO_ALLOC);
                }
                pub fn try_get_last(self: *ListSelf) ListError!T {
                    return P.try_get_last(self, NO_ALLOC);
                }
                pub fn get_last_ptr(self: *ListSelf) *T {
                    return P.get_last_ptr(self, NO_ALLOC);
                }
                pub fn try_get_last_ptr(self: *ListSelf) ListError!*T {
                    return P.try_get_last_ptr(self, NO_ALLOC);
                }
                pub fn set_last(self: *ListSelf, val: T) void {
                    return P.set_last(self, val, NO_ALLOC);
                }
                pub fn try_set_last(self: *ListSelf, val: T) ListError!void {
                    return P.try_set_last(self, val, NO_ALLOC);
                }
                pub fn get_first(self: *ListSelf) T {
                    return P.get_first(self, NO_ALLOC);
                }
                pub fn try_get_first(self: *ListSelf) ListError!T {
                    return P.try_get_first(self, NO_ALLOC);
                }
                pub fn get_first_ptr(self: *ListSelf) *T {
                    return P.get_first_ptr(self, NO_ALLOC);
                }
                pub fn try_get_first_ptr(self: *ListSelf) ListError!*T {
                    return P.try_get_first_ptr(self, NO_ALLOC);
                }
                pub fn set_first(self: *ListSelf, val: T) void {
                    return P.set_first(self, val, NO_ALLOC);
                }
                pub fn try_set_first(self: *ListSelf, val: T) ListError!void {
                    return P.try_set_first(self, val, NO_ALLOC);
                }
                pub fn get_nth(self: *ListSelf, n: usize) T {
                    return P.get_nth(self, n, NO_ALLOC);
                }
                pub fn try_get_nth(self: *ListSelf, n: usize) ListError!T {
                    return P.try_get_nth(self, n, NO_ALLOC);
                }
                pub fn get_nth_ptr(self: *ListSelf, n: usize) *T {
                    return P.get_nth_ptr(self, n, NO_ALLOC);
                }
                pub fn try_get_nth_ptr(self: *ListSelf, n: usize) ListError!*T {
                    return P.try_get_nth_ptr(self, n, NO_ALLOC);
                }
                pub fn set_nth(self: *ListSelf, n: usize, val: T) void {
                    return P.set_nth(self, n, val, NO_ALLOC);
                }
                pub fn try_set_nth(self: *ListSelf, n: usize, val: T) ListError!void {
                    return P.try_set_nth(self, n, val, NO_ALLOC);
                }
                pub fn get_nth_from_end(self: *ListSelf, n: usize) T {
                    return P.get_nth_from_end(self, n, NO_ALLOC);
                }
                pub fn try_get_nth_from_end(self: *ListSelf, n: usize) ListError!T {
                    return P.try_get_nth_from_end(self, n, NO_ALLOC);
                }
                pub fn get_nth_ptr_from_end(self: *ListSelf, n: usize) *T {
                    return P.get_nth_ptr_from_end(self, n, NO_ALLOC);
                }
                pub fn try_get_nth_ptr_from_end(self: *ListSelf, n: usize) ListError!*T {
                    return P.try_get_nth_ptr_from_end(self, n, NO_ALLOC);
                }
                pub fn set_nth_from_end(self: *ListSelf, n: usize, val: T) void {
                    return P.set_nth_from_end(self, n, val, NO_ALLOC);
                }
                pub fn try_set_nth_from_end(self: *ListSelf, n: usize, val: T) ListError!void {
                    return P.try_set_nth_from_end(self, n, val, NO_ALLOC);
                }
                pub fn set_from(self: *ListSelf, self_idx: usize, source: *ListSelf, source_idx: usize) void {
                    return P.set_from(self, self_idx, NO_ALLOC, source, source_idx, NO_ALLOC);
                }
                pub fn try_set_from(self: *ListSelf, self_idx: usize, source: *ListSelf, source_idx: usize) ListError!void {
                    return P.try_set_from(self, self_idx, NO_ALLOC, source, source_idx, NO_ALLOC);
                }
                pub fn exchange(self: *ListSelf, self_idx: usize, other: *ListSelf, other_idx: usize) void {
                    return P.exchange(self, self_idx, NO_ALLOC, other, other_idx, NO_ALLOC);
                }
                pub fn try_exchange(self: *ListSelf, self_idx: usize, other: *ListSelf, other_idx: usize) ListError!void {
                    return P.try_exchange(self, self_idx, NO_ALLOC, other, other_idx, NO_ALLOC);
                }
                pub fn overwrite(self: *ListSelf, source_idx: usize, dest_idx: usize) void {
                    return P.overwrite(self, source_idx, dest_idx, NO_ALLOC);
                }
                pub fn try_overwrite(self: *ListSelf, source_idx: usize, dest_idx: usize) ListError!void {
                    return P.try_overwrite(self, source_idx, dest_idx, NO_ALLOC);
                }
                pub fn reverse(self: *ListSelf, range: P.PartialRangeIter) void {
                    return P.reverse(self, range, NO_ALLOC);
                }
                pub fn rotate(self: *ListSelf, range: P.PartialRangeIter, delta: isize) void {
                    return P.rotate(self, range, delta, NO_ALLOC);
                }
                pub fn fill(self: *ListSelf, range: P.PartialRangeIter, val: T) usize {
                    return P.fill(self, range, val, NO_ALLOC);
                }
                pub fn copy(source: P.RangeIter, dest: P.RangeIter) usize {
                    return P.copy(source, dest);
                }
                pub fn copy_to(self: *ListSelf, self_range: P.PartialRangeIter, dest: P.RangeIter) usize {
                    return P.copy_to(self, self_range, dest);
                }
                pub fn is_sorted(self: *ListSelf, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
                    return P.is_sorted(self, range, greater_than, NO_ALLOC);
                }
                pub fn is_sorted_implicit(self: *ListSelf, range: P.PartialRangeIter) bool {
                    return P.is_sorted_implicit(self, range, NO_ALLOC);
                }
                pub fn insertion_sort(self: *ListSelf, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
                    return P.insertion_sort(self, range, greater_than, NO_ALLOC);
                }
                pub fn insertion_sort_implicit(self: *ListSelf, range: P.PartialRangeIter) bool {
                    return P.insertion_sort_implicit(self, range, NO_ALLOC);
                }
                pub fn quicksort(self: *ListSelf, range: P.PartialRangeIter, greater_than: *const P.CompareFunc, less_than: *const P.CompareFunc, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
                    return P.quicksort(self, range, NO_ALLOC, greater_than, less_than, PARTITION_IDX, partition_stack);
                }
                pub fn quicksort_implicit(self: *ListSelf, range: P.PartialRangeIter, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
                    return P.quicksort_implicit(self, range, NO_ALLOC, PARTITION_IDX, partition_stack);
                }
                pub fn range_iterator(self: *ListSelf, range: P.PartialRangeIter) P.RangeIter {
                    return P.range_iterator(self, range);
                }
                pub fn for_each(
                    self: *ListSelf,
                    range: P.PartialRangeIter,
                    userdata: anytype,
                    action: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
                    comptime filter: IListConcrete.FilterMode,
                    filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
                ) usize {
                    return P.for_each(self, range, userdata, action, filter, filter_func);
                }
                pub fn filter_indexes(
                    self: *ListSelf,
                    range: P.PartialRangeIter,
                    userdata: anytype,
                    filter_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
                    comptime OUT_IDX: type,
                    out_list: IList(OUT_IDX),
                ) usize {
                    return P.filter_indexes(self, range, userdata, filter_func, OUT_IDX, out_list);
                }
                pub fn transform_values(
                    self: *ListSelf,
                    range: P.PartialRangeIter,
                    userdata: anytype,
                    comptime OUT_TYPE: type,
                    transform_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) OUT_TYPE,
                    out_list: IList(OUT_TYPE),
                    comptime filter: IListConcrete.FilterMode,
                    filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
                ) usize {
                    return P.transform_values(self, range, userdata, OUT_TYPE, transform_func, out_list, filter, filter_func);
                }
                pub fn accumulate_result(
                    self: *ListSelf,
                    range: P.PartialRangeIter,
                    initial_accumulation: anytype,
                    userdata: anytype,
                    accumulate_func: *const fn (item: P.IterItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
                    comptime filter: IListConcrete.FilterMode,
                    filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
                ) @TypeOf(initial_accumulation) {
                    return P.accumulate_result(self, range, initial_accumulation, userdata, accumulate_func, filter, filter_func);
                }
                pub fn ensure_free_slots(self: *ListSelf, count: usize) void {
                    return P.ensure_free_slots(self, count, NO_ALLOC);
                }
                pub fn append_slots(self: *ListSelf, count: usize) Range {
                    return P.append_slots(self, count, NO_ALLOC);
                }
                pub fn try_append_slots(self: *ListSelf, count: usize) ListError!Range {
                    return P.try_append_slots(self, count, NO_ALLOC);
                }
                pub fn append_zig_slice(self: *ListSelf, source: []const T) Range {
                    return P.append_zig_slice(self, source, NO_ALLOC);
                }
                pub fn try_append_zig_slice(self: *ListSelf, source: []const T) ListError!Range {
                    return P.try_append_zig_slice(self, source, NO_ALLOC);
                }
                pub fn append(self: *ListSelf, val: T) usize {
                    return P.append(self, val, NO_ALLOC);
                }
                pub fn try_append(self: *ListSelf, val: T) ListError!usize {
                    return P.try_append(self, val, NO_ALLOC);
                }
                pub fn append_many(self: *ListSelf, source: P.RangeIter) Range {
                    return P.append_many(self, NO_ALLOC, source);
                }
                pub fn try_append_many(self: *ListSelf, source: P.RangeIter) ListError!Range {
                    return P.try_append_many(self, NO_ALLOC, source);
                }
                pub fn insert_slots(self: *ListSelf, idx: usize, count: usize) Range {
                    return P.insert_slots(self, idx, count, NO_ALLOC);
                }
                pub fn try_insert_slots(self: *ListSelf, idx: usize, count: usize) ListError!Range {
                    return P.try_insert_slots(self, idx, count, NO_ALLOC);
                }
                pub fn insert_zig_slice(self: *ListSelf, idx: usize, source: []T) Range {
                    return P.insert_zig_slice(self, idx, source, NO_ALLOC);
                }
                pub fn try_insert_zig_slice(self: *ListSelf, idx: usize, source: []T) ListError!Range {
                    return P.try_insert_zig_slice(self, idx, source, NO_ALLOC);
                }
                pub fn insert(self: *ListSelf, idx: usize, val: T) usize {
                    return P.insert(self, idx, val, NO_ALLOC);
                }
                pub fn try_insert(self: *ListSelf, idx: usize, val: T) ListError!usize {
                    return P.try_insert(self, idx, val, NO_ALLOC);
                }
                pub fn insert_many(self: *ListSelf, idx: usize, source: P.RangeIter) Range {
                    return P.insert_many(self, idx, NO_ALLOC, source);
                }
                pub fn try_insert_many(self: *ListSelf, idx: usize, source: P.RangeIter) ListError!Range {
                    return P.try_insert_many(self, idx, NO_ALLOC, source);
                }
                pub fn try_delete_range(self: *ListSelf, range: Range) ListError!void {
                    return P.try_delete_range(self, range, NO_ALLOC);
                }
                pub fn delete_many(self: *ListSelf, range: P.PartialRangeIter) void {
                    return P.delete_many(self, range);
                }
                pub fn try_delete_many(self: *ListSelf, range: P.PartialRangeIter) ListError!void {
                    return P.try_delete_many(self, range);
                }
                pub fn try_delete(self: *ListSelf, idx: usize) ListError!void {
                    return P.try_delete(self, idx, NO_ALLOC);
                }
                pub fn swap_delete(self: *ListSelf, idx: usize) void {
                    return P.swap_delete(self, idx, NO_ALLOC);
                }
                pub fn try_swap_delete(self: *ListSelf, idx: usize) ListError!void {
                    return P.try_swap_delete(self, idx, NO_ALLOC);
                }
                pub fn swap_delete_many(self: *ListSelf, range: P.PartialRangeIter) void {
                    return P.swap_delete_many(self, range);
                }
                pub fn try_swap_delete_many(self: *ListSelf, range: P.PartialRangeIter) ListError!void {
                    return P.try_swap_delete_many(self, range);
                }
                pub fn remove_range(self: *ListSelf, self_range: P.PartialRangeIter, dest: *ListSelf, dest_alloc: Allocator) Range {
                    return P.remove_range(self, self_range, dest, dest_alloc);
                }
                pub fn try_remove_range(self: *ListSelf, self_range: P.PartialRangeIter, dest: *ListSelf, dest_alloc: Allocator) ListError!Range {
                    return P.try_remove_range(self, self_range, dest, dest_alloc);
                }
                pub fn remove(self: *ListSelf, idx: usize) T {
                    return P.remove(self, idx, NO_ALLOC);
                }
                pub fn try_remove(self: *ListSelf, idx: usize) ListError!T {
                    return P.try_remove(self, idx, NO_ALLOC);
                }
                pub fn swap_remove(self: *ListSelf, idx: usize) T {
                    return P.swap_remove(self, idx, NO_ALLOC);
                }
                pub fn try_swap_remove(self: *ListSelf, idx: usize) ListError!T {
                    return P.try_swap_remove(self, idx, NO_ALLOC);
                }
                pub fn pop(self: *ListSelf) T {
                    return P.pop(self, NO_ALLOC);
                }
                pub fn try_pop(self: *ListSelf) ListError!T {
                    return P.try_pop(self, NO_ALLOC);
                }
                pub fn pop_many(self: *ListSelf, count: usize, dest: *ListSelf, dest_alloc: Allocator) Range {
                    return P.pop_many(self, count, NO_ALLOC, dest, dest_alloc);
                }
                pub fn try_pop_many(self: *ListSelf, count: usize, dest: *ListSelf, dest_alloc: Allocator) ListError!Range {
                    return P.try_pop_many(self, count, NO_ALLOC, dest, dest_alloc);
                }
                pub fn sorted_insert(
                    self: *ListSelf,
                    val: T,
                    equal_func: *const fn (this_val: T, find_val: T) bool,
                    greater_than_func: *const fn (this_val: T, find_val: T) bool,
                ) usize {
                    return P.sorted_insert(self, NO_ALLOC, val, equal_func, greater_than_func);
                }
                pub fn sorted_insert_implicit(self: *ListSelf, val: T) usize {
                    return P.sorted_insert_implicit(self, val, NO_ALLOC);
                }
                pub fn sorted_insert_index(
                    self: *ListSelf,
                    val: T,
                    equal_func: *const fn (this_val: T, find_val: T) bool,
                    greater_than_func: *const fn (this_val: T, find_val: T) bool,
                ) IListConcrete.InsertIndexResult {
                    return P.sorted_insert_index(self, NO_ALLOC, val, equal_func, greater_than_func);
                }
                pub fn sorted_insert_index_implicit(self: *ListSelf, val: T) IListConcrete.InsertIndexResult {
                    return P.sorted_insert_index_implicit(self, val, NO_ALLOC);
                }
                pub fn sorted_search(
                    self: *ListSelf,
                    val: T,
                    equal_func: *const fn (this_val: T, find_val: T) bool,
                    greater_than_func: *const fn (this_val: T, find_val: T) bool,
                ) IListConcrete.SearchResult {
                    return P.sorted_search(self, NO_ALLOC, val, equal_func, greater_than_func);
                }
                pub fn sorted_search_implicit(self: *ListSelf, val: T) IListConcrete.SearchResult {
                    return P.sorted_search_implicit(self, val, NO_ALLOC);
                }
                pub fn sorted_set_and_resort(self: *ListSelf, idx: usize, val: T, greater_than_func: *const fn (this_val: T, find_val: T) bool) usize {
                    return P.sorted_set_and_resort(self, idx, val, NO_ALLOC, greater_than_func);
                }
                pub fn sorted_set_and_resort_implicit(self: *ListSelf, idx: usize, val: T) usize {
                    return P.sorted_set_and_resort_implicit(self, idx, val, NO_ALLOC);
                }
                pub fn search(self: *ListSelf, find_val: anytype, equal_func: *const fn (this_val: T, find_val: @TypeOf(find_val)) bool) IListConcrete.SearchResult {
                    return P.search(self, find_val, NO_ALLOC, equal_func);
                }
                pub fn search_implicit(self: *ListSelf, find_val: anytype) IListConcrete.SearchResult {
                    return P.search_implicit(self, find_val, NO_ALLOC);
                }
                pub fn add_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.add_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_add_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_add_get(self, idx, val, NO_ALLOC);
                }
                pub fn add_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.add_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_add_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_add_set(self, idx, val, NO_ALLOC);
                }
                pub fn subtract_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.subtract_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_subtract_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_subtract_get(self, idx, val, NO_ALLOC);
                }
                pub fn subtract_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.subtract_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_subtract_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_subtract_set(self, idx, val, NO_ALLOC);
                }
                pub fn multiply_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.multiply_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_multiply_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_multiply_get(self, idx, val, NO_ALLOC);
                }
                pub fn multiply_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.multiply_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_multiply_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_multiply_set(self, idx, val, NO_ALLOC);
                }
                pub fn divide_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.divide_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_divide_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_divide_get(self, idx, val, NO_ALLOC);
                }
                pub fn divide_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.divide_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_divide_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_divide_set(self, idx, val, NO_ALLOC);
                }
                pub fn modulo_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.modulo_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_modulo_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_modulo_get(self, idx, val, NO_ALLOC);
                }
                pub fn modulo_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.modulo_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_modulo_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_modulo_set(self, idx, val, NO_ALLOC);
                }
                pub fn mod_rem_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.mod_rem_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_mod_rem_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_mod_rem_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_and_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.bit_and_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_and_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_and_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_and_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.bit_and_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_and_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_and_set(self, idx, val, NO_ALLOC);
                }
                pub fn bit_or_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.bit_or_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_or_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_or_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_or_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.bit_or_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_or_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_or_set(self, idx, val, NO_ALLOC);
                }
                pub fn bit_xor_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.bit_xor_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_xor_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_xor_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_xor_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.bit_xor_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_xor_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_xor_set(self, idx, val, NO_ALLOC);
                }
                pub fn bit_invert_get(self: *ListSelf, idx: usize) T {
                    return P.bit_invert_get(self, idx, NO_ALLOC);
                }
                pub fn try_bit_invert_get(self: *ListSelf, idx: usize) ListError!T {
                    return P.try_bit_invert_get(self, idx, NO_ALLOC);
                }
                pub fn bit_invert_set(self: *ListSelf, idx: usize) void {
                    return P.bit_invert_set(self, idx, NO_ALLOC);
                }
                pub fn try_bit_invert_set(self: *ListSelf, idx: usize) ListError!void {
                    return P.try_bit_invert_set(self, idx, NO_ALLOC);
                }
                pub fn bool_and_get(self: *ListSelf, idx: usize, val: bool) T {
                    return P.bool_and_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_and_get(self: *ListSelf, idx: usize, val: bool) ListError!T {
                    return P.try_bool_and_get(self, idx, val, NO_ALLOC);
                }
                pub fn bool_and_set(self: *ListSelf, idx: usize, val: bool) void {
                    return P.bool_and_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_and_set(self: *ListSelf, idx: usize, val: bool) ListError!void {
                    return P.try_bool_and_set(self, idx, val, NO_ALLOC);
                }
                pub fn bool_or_get(self: *ListSelf, idx: usize, val: bool) T {
                    return P.bool_or_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_or_get(self: *ListSelf, idx: usize, val: bool) ListError!T {
                    return P.try_bool_or_get(self, idx, val, NO_ALLOC);
                }
                pub fn bool_or_set(self: *ListSelf, idx: usize, val: bool) void {
                    return P.bool_or_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_or_set(self: *ListSelf, idx: usize, val: bool) ListError!void {
                    return P.try_bool_or_set(self, idx, val, NO_ALLOC);
                }
                pub fn bool_xor_get(self: *ListSelf, idx: usize, val: bool) T {
                    return P.bool_xor_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_xor_get(self: *ListSelf, idx: usize, val: bool) ListError!T {
                    return P.try_bool_xor_get(self, idx, val, NO_ALLOC);
                }
                pub fn bool_xor_set(self: *ListSelf, idx: usize, val: bool) void {
                    return P.bool_xor_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bool_xor_set(self: *ListSelf, idx: usize, val: bool) ListError!void {
                    return P.try_bool_xor_set(self, idx, val, NO_ALLOC);
                }
                pub fn bool_invert_get(self: *ListSelf, idx: usize) T {
                    return P.bool_invert_get(self, idx, NO_ALLOC);
                }
                pub fn try_bool_invert_get(self: *ListSelf, idx: usize) ListError!T {
                    return P.try_bool_invert_get(self, idx, NO_ALLOC);
                }
                pub fn bool_invert_set(self: *ListSelf, idx: usize) void {
                    return P.bool_invert_set(self, idx, NO_ALLOC);
                }
                pub fn try_bool_invert_set(self: *ListSelf, idx: usize) ListError!void {
                    return P.try_bool_invert_set(self, idx, NO_ALLOC);
                }
                pub fn bit_l_shift_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.bit_l_shift_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_l_shift_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_l_shift_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_l_shift_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.bit_l_shift_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_l_shift_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_l_shift_set(self, idx, val, NO_ALLOC);
                }
                pub fn bit_r_shift_get(self: *ListSelf, idx: usize, val: anytype) T {
                    return P.bit_r_shift_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_r_shift_get(self: *ListSelf, idx: usize, val: anytype) ListError!T {
                    return P.try_bit_r_shift_get(self, idx, val, NO_ALLOC);
                }
                pub fn bit_r_shift_set(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.bit_r_shift_set(self, idx, val, NO_ALLOC);
                }
                pub fn try_bit_r_shift_set(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_bit_r_shift_set(self, idx, val, NO_ALLOC);
                }
                pub fn less_than_get(self: *ListSelf, idx: usize, val: anytype) bool {
                    return P.less_than_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_less_than_get(self: *ListSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_less_than_get(self, idx, val, NO_ALLOC);
                }
                pub fn less_than_equal_get(self: *ListSelf, idx: usize, val: anytype) bool {
                    return P.less_than_equal_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_less_than_equal_get(self: *ListSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_less_than_equal_get(self, idx, val, NO_ALLOC);
                }
                pub fn greater_than_get(self: *ListSelf, idx: usize, val: anytype) bool {
                    return P.greater_than_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_greater_than_get(self: *ListSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_greater_than_get(self, idx, val, NO_ALLOC);
                }
                pub fn greater_than_equal_get(self: *ListSelf, idx: usize, val: anytype) bool {
                    return P.greater_than_equal_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_greater_than_equal_get(self: *ListSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_greater_than_equal_get(self, idx, val, NO_ALLOC);
                }
                pub fn equals_get(self: *ListSelf, idx: usize, val: anytype) bool {
                    return P.equals_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_equals_get(self: *ListSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_equals_get(self, idx, val, NO_ALLOC);
                }
                pub fn not_equals_get(self: *ListSelf, idx: usize, val: anytype) bool {
                    return P.not_equals_get(self, idx, val, NO_ALLOC);
                }
                pub fn try_not_equals_get(self: *ListSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_not_equals_get(self, idx, val, NO_ALLOC);
                }
                pub fn get_min_in_range(self: *ListSelf, range: P.PartialRangeIter) P.Item {
                    return P.get_min_in_range(self, range);
                }
                pub fn try_get_min_in_range(self: *ListSelf, range: P.PartialRangeIter) ListError!P.Item {
                    return P.try_get_min_in_range(self, range);
                }
                pub fn get_max_in_range(self: *ListSelf, range: P.PartialRangeIter) P.Item {
                    return P.get_max_in_range(self, range);
                }
                pub fn try_get_max_in_range(self: *ListSelf, range: P.PartialRangeIter) ListError!P.Item {
                    return P.try_get_max_in_range(self, range);
                }
                pub fn get_clamped(self: *ListSelf, idx: usize, min: T, max: T) T {
                    return P.get_clamped(self, idx, min, max, NO_ALLOC);
                }
                pub fn try_get_clamped(self: *ListSelf, idx: usize, min: T, max: T) ListError!T {
                    return P.try_get_clamped(self, idx, min, max, NO_ALLOC);
                }
                pub fn set_clamped(self: *ListSelf, idx: usize, min: T, max: T) void {
                    return P.set_clamped(self, idx, min, max, NO_ALLOC);
                }
                pub fn try_set_clamped(self: *ListSelf, idx: usize, min: T, max: T) ListError!void {
                    return P.try_set_clamped(self, idx, min, max, NO_ALLOC);
                }
                pub fn set_report_change(self: *ListSelf, idx: usize, val: T) bool {
                    return P.set_report_change(self, idx, val, NO_ALLOC);
                }
                pub fn try_set_report_change(self: *ListSelf, idx: usize, val: T) bool {
                    return P.try_set_report_change(self, idx, val, NO_ALLOC);
                }
                pub fn get_unsafe_cast(self: *ListSelf, idx: usize, comptime TT: type) TT {
                    return P.get_unsafe_cast(self, idx, TT, NO_ALLOC);
                }
                pub fn try_get_unsafe_cast(self: *ListSelf, idx: usize, comptime TT: type) ListError!TT {
                    return P.try_get_unsafe_cast(self, idx, TT, NO_ALLOC);
                }
                pub fn get_unsafe_ptr_cast(self: *ListSelf, idx: usize, comptime TT: type) *TT {
                    return P.get_unsafe_ptr_cast(self, idx, TT, NO_ALLOC);
                }
                pub fn try_get_unsafe_ptr_cast(self: *ListSelf, idx: usize, comptime TT: type) ListError!*TT {
                    return P.try_get_unsafe_ptr_cast(self, idx, TT, NO_ALLOC);
                }
                pub fn set_unsafe_cast(self: *ListSelf, idx: usize, val: anytype) void {
                    return P.set_unsafe_cast(self, idx, val, NO_ALLOC);
                }
                pub fn try_set_unsafe_cast(self: *ListSelf, idx: usize, val: anytype) ListError!void {
                    return P.try_set_unsafe_cast(self, idx, val, NO_ALLOC);
                }
                pub fn set_unsafe_cast_report_change(self: *ListSelf, idx: usize, val: anytype) bool {
                    return P.set_unsafe_cast_report_change(self, idx, val, NO_ALLOC);
                }
                pub fn try_set_unsafe_cast_report_change(self: *ListSelf, idx: usize, val: anytype) ListError!bool {
                    return P.try_set_unsafe_cast_report_change(self, idx, val, NO_ALLOC);
                }
            };
        }

        pub const Debug = struct {
            const NeedLock = enum(u8) {
                no_locks_needed,
                lock_meta,
                lock_data,
                lock_data_and_meta,
            };
            pub fn check_buckets_and_blocks(comptime src: std.builtin.SourceLocation, comptime need_lock: NeedLock) void {
                if (need_lock == .lock_meta or need_lock == .lock_data_and_meta) lock_meta();
                if (need_lock == .lock_data or need_lock == .lock_data_and_meta) lock_data();
                for (STATE.buckets[0..], 0..) |bucket, b| {
                    const bidx: u6 = @intCast(b);
                    assert_with_reason(bucket.len <= bucket.cap, src, "bucket {d} has a len greater than its cap, bucket = {any}, index = {d}, size = {d}", .{ bidx, bucket, b, (@as(usize, 1) << (bidx << 1)) - 1 });
                    const bucket_end = Types.intcast(bucket.start, usize) + Types.intcast(bucket.len, usize);
                    assert_with_reason(bucket_end <= STATE.meta_len, src, "a free bucket has a range outside the meta_len, bucket = {any}, meta_len = {d}", .{ bucket, STATE.meta_len });
                    for (STATE.meta_ptr[bucket.start .. bucket.start + bucket.len], 0..) |block, bb| {
                        const bbidx: ADDRESS_UINT = @intCast(bb);
                        const block_end = Types.intcast(block.start, usize) + Types.intcast(block.len, usize);
                        assert_with_reason(block_end <= STATE.data_len, src, "a free block has a range outside the data_len, bucket = {d}, bucket size = {d}, bucket block idx = {d}, true block idx = {d}, block = {any}, data_len = {d}", .{ bidx, (@as(usize, 1) << (bidx << 1)) - 1, bbidx, bbidx + bucket.start, block, STATE.data_len });
                    }
                }
                if (need_lock == .lock_data or need_lock == .lock_data_and_meta) unlock_data();
                if (need_lock == .lock_meta or need_lock == .lock_data_and_meta) unlock_meta();
            }
            const LARGEST_FUZZ_LEN = 1024;
            const SMALL_FUZZ_LEN = 256;
            const MICRO_FUZZ_LEN = 16;
            const LARGEST_FUZZ_COPY = 128;
            pub fn make_list_interface_test(comptime T: type) Fuzz.FuzzTest {
                const PROTO = struct {
                    const T_IList = Root.IList.IList(T);
                    const T_List = std.ArrayList(T);
                    pub const FSTATE = struct {
                        ref_list: std.ArrayList(T),
                        test_list: Root.IList.IList(T),
                        list: List(T),
                    };
                    pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
                        var fstate = try alloc.create(FSTATE);
                        fstate.ref_list = try T_List.initCapacity(alloc, LARGEST_FUZZ_LEN);
                        fstate.list = List(T).init_capacity(MICRO_FUZZ_LEN);
                        fstate.test_list = fstate.list.interface();
                        state_opaque.* = @ptrCast(fstate);
                    }
                    pub fn START_SEED(rand: Random, state_opaque: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                        var fstate: *FSTATE = @ptrCast(@alignCast(state_opaque));
                        const len = rand.uintLessThan(usize, SMALL_FUZZ_LEN);
                        fstate.ref_list.clearRetainingCapacity();
                        fstate.list.slice.len = 0;
                        fstate.ref_list.ensureTotalCapacity(alloc, len) catch |err| return Utils.alloc_fail_err(alloc, @src(), err);
                        const ok = Utils.not_error(fstate.test_list.try_ensure_free_slots(len));
                        if (!ok) return Utils.alloc_fail_str(alloc, @src(), "failed to ensure free slots", .{});
                        fstate.ref_list.items.len = len;
                        if (T == u8 and len < fstate.list.slice.len) {
                            const ulen = Types.intcast(fstate.list.slice.len, usize);
                            const delta = ulen - len;
                            lock_data();
                            const slice = fstate.list.zig_slice_no_lock();
                            const erase_slice = slice[ulen - delta .. ulen];
                            Utils.secure_memset_undefined(u8, erase_slice);
                            unlock_data();
                        }
                        fstate.list.slice.len = @intCast(len);
                        if (len > 0) {
                            rand.bytes(fstate.ref_list.items);
                            if (T == u8) {
                                Utils.replace_key_value_in_buffer(T, fstate.ref_list.items, 0xAA, 0x11);
                            }
                            lock_data();
                            @memcpy(fstate.list.zig_slice_no_lock(), fstate.ref_list.items[0..len]);
                            unlock_data();
                        }
                        return _OPS.verify_whole_state(fstate, "start_seed", 0, 0, 0, alloc);
                    }

                    pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
                        const fstate: *FSTATE = @ptrCast(@alignCast(state_opaque));
                        fstate.ref_list.clearAndFree(alloc);
                        fstate.list.free();
                        alloc.destroy(fstate);
                    }

                    fn extra_checks(fstate: *FSTATE, comptime op_name: []const u8, param_1: usize, param_2: usize, param_3: usize, alloc: Allocator) ?[]const u8 {
                        if (T == u8) {
                            lock_data();
                            for (fstate.list.slice.zig_slice_no_lock(), 0..) |v, i| {
                                if (v == 0xAA) return Utils.alloc_fail_str(alloc, @src(), ": {s}({d}, {d}, {d}): one of the bytes in the list was set to the undefined byte `0xAA`, meaning that portion of the allocated list is recorded as 'free' by the allocator, idx = {d}, list len = {d}", .{ op_name, param_1, param_2, param_3, i, fstate.list.slice.len });
                            }
                            unlock_data();
                        }
                        lock_meta();
                        lock_data();
                        for (STATE.buckets[0..]) |bucket| {
                            if (bucket.start + bucket.cap > STATE.meta_len) return Utils.alloc_fail_str(alloc, @src(), ": {s}({d}, {d}, {d}): a free bucket has a range outside the meta_len, bucket = {any}, meta_len = {d}", .{ op_name, param_1, param_2, param_3, bucket, STATE.meta_len });
                            for (STATE.meta_ptr[bucket.start .. bucket.start + bucket.len]) |block| {
                                if (block.start + block.len > STATE.data_len) return Utils.alloc_fail_str(alloc, @src(), ": {s}({d}, {d}, {d}): a free block has a range outside the data_len, bucket = {any}, meta_len = {d}", .{ op_name, param_1, param_2, param_3, block, STATE.data_len });
                            }
                        }
                        unlock_data();
                        unlock_meta();
                        return null;
                    }

                    const _OPS = IList._Fuzzer.make_op_table(
                        T,
                        FSTATE,
                        0,
                        // FIXME with the current implementation, there is a possiblity that pointers are invalidated
                        // before they can be tested for data access by another thread forcing a reallocation.
                        // This could be fixed by implementing a sharding system so only the relevant memory is relocated
                        // (to a new/different 'shard' with enough space)
                        .no_access_to_pointers,
                        .list_can_grow_and_shrink,
                        extra_checks,
                        if (T == u8) IList._Fuzzer.DisallowVal(T){ .disallowed = 0xAA, .replacement = 0x11 } else null,
                    );
                    pub const OPS = _OPS.OPS;
                };
                const thread_string = switch (THREADING_MODE) {
                    .single_threaded => "single_threaded_",
                    .multi_threaded_separate => "threadlocal_",
                    .multi_threaded_shared => "mutexed_",
                };
                const zero_string = switch (SECURITY_MODE) {
                    .do_not_explicitly_zero_freed_data => "unzeroed_",
                    .explicitly_zero_freed_data => "zeroed_",
                };
                return Fuzz.FuzzTest{
                    .options = Fuzz.FuzzOptions{
                        .name = "IList_CCASList_" ++ thread_string ++ zero_string ++ @typeName(T),
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
