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
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;
const Growth = Root.CommonTypes.GrowthModel;
const RwLock = std.Io.RwLock;
const Io = std.Io;
const CachedAllocMode = Root.CommonTypes.CachedAllocMode;
const PowerOf2 = Root.Math.PowerOf2;
const ListSliceModule = Root.ListSlice;

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;
const invalid_ptr = Utils.invalid_ptr;
const invalid_ptr_many = Utils.invalid_ptr_many;

pub const MutexMode = enum {
    NO_LOCKS,
    MASTER_LOCK,
    MASTER_AND_BLOCK_LOCK,
};

pub const PoolDef = struct {
    ELEM: type,
    IDX: type = u32,
    LOCK_MODE: MutexMode = .NO_LOCKS,
    DATA_BLOCK_BYTE_SIZE_AND_ALIGNMENT: PowerOf2 = ._4_096,
    ALLOC_MODE: CachedAllocMode = .MANUAL_ALLOC,
};

pub const PoolLockMode = enum {
    CHECK_POOL_LOCKS,
    IGNORE_POOL_LOCKS,
};

pub const BlockLockMode = enum {
    CHECK_BLOCK_LOCKS,
    IGNORE_BLOCK_LOCKS,
};

pub const IterSlotMode = enum { VAL, PTR, CONST_PTR };

const FieldAccessMode = enum {
    NOT_SUPPORTED,
    UNION_TAGGED,
    UNION_UNTAGGED,
    STRUCT,
};

const KeyMode = enum {
    KEY_PTR,
    KEY_VAL,
};

fn FieldIntType(comptime num_fields: usize) type {
    if (num_fields <= math.maxInt(u8)) return u8;
    if (num_fields <= math.maxInt(u16)) return u16;
    if (num_fields <= math.maxInt(u32)) return u32;
    return u64;
}

pub fn BitTrackedPool(comptime DEF: PoolDef) type {
    assert_with_reason(Types.type_is_unsigned_int(DEF.IDX), @src(), "type `IDX` must be an unsigned integer type, got type `{s}`", .{@typeName(DEF.IDX)});
    assert_with_reason(@sizeOf(DEF.ELEM) > 0, @src(), "type `ELEM` must have a non-zero size so that every slot has a distinct address", .{});
    assert_with_reason(DEF.DATA_BLOCK_BYTE_SIZE_AND_ALIGNMENT.value() >= @bitSizeOf(usize), @src(), "`DATA_BLOCK_SIZE` ({d}) must be AT LEAST {d} large (num bits in `usize`)", .{ DEF.DATA_BLOCK_BYTE_SIZE_AND_ALIGNMENT.value(), @bitSizeOf(usize) });
    assert_with_reason(DEF.DATA_BLOCK_BYTE_SIZE_AND_ALIGNMENT.value() <= math.maxInt(DEF.IDX), @src(), "`DATA_BLOCK_SIZE` ({d}) must be <= `math.maxInt(IDX)` ({d})", .{ DEF.DATA_BLOCK_BYTE_SIZE_AND_ALIGNMENT.value(), math.maxInt(DEF.IDX) });
    const ELEM_SIZE_ = @sizeOf(DEF.ELEM);
    const TARGET_BLOCK_BYTE_SIZE = DEF.DATA_BLOCK_BYTE_SIZE_AND_ALIGNMENT.value_as_type(usize);
    const STATE_INT_, const DATA_BLOCK_SLOT_LENGTH_, const DATA_BLOCK_STATE_GROUP_LENGTH_, const WASTE_BYTES_IN_BLOCK_ = calc: {
        var slot_len: usize = 0;
        var group_len: usize = 0;
        var state_int_bit_size = @bitSizeOf(usize);
        var state_int_size = state_int_bit_size >> 3;
        var total_byte_size: usize = (if (DEF.LOCK_MODE == .MASTER_AND_BLOCK_LOCK) @sizeOf(RwLock) else 0) + (@sizeOf(DEF.IDX) * 2) + @sizeOf(usize);
        var next_total_byte_size: usize = total_byte_size;
        var next_slot_len = slot_len;
        var next_group_len = group_len;
        while (true) {
            next_slot_len += state_int_bit_size;
            next_group_len += 1;
            next_total_byte_size += (ELEM_SIZE_ * state_int_bit_size);
            next_total_byte_size += state_int_size;
            if (next_total_byte_size > TARGET_BLOCK_BYTE_SIZE) break;
            slot_len = next_slot_len;
            group_len = next_group_len;
            total_byte_size = next_total_byte_size;
        }
        if (slot_len == 0) {
            next_slot_len = slot_len;
            next_group_len = group_len;
            next_total_byte_size = total_byte_size;
            while (true) {
                state_int_bit_size >>= 1;
                if (state_int_bit_size < 8) break;
                state_int_size = state_int_bit_size >> 3;
                next_slot_len += state_int_bit_size;
                next_group_len += 1;
                next_total_byte_size += (ELEM_SIZE_ * state_int_bit_size);
                next_total_byte_size += state_int_size;
                if (next_total_byte_size > TARGET_BLOCK_BYTE_SIZE) {
                    next_slot_len = slot_len;
                    next_group_len = group_len;
                    next_total_byte_size = total_byte_size;
                    continue;
                }
                slot_len = next_slot_len;
                group_len = next_group_len;
                total_byte_size = next_total_byte_size;
            }
        }
        assert_with_reason(slot_len > 0, @src(), "a target data block size of `{d}` cannot hold at least 8 elements of type `{s}` along with the necessary metadata, Either directly allocate thements with an allocator or increase the target data block size", .{ TARGET_BLOCK_BYTE_SIZE, @typeName(DEF.ELEM) });
        const waste_bytes = TARGET_BLOCK_BYTE_SIZE - total_byte_size;
        const state_int = @Int(.unsigned, state_int_bit_size);
        break :calc .{ state_int, slot_len, group_len, waste_bytes };
    };
    return struct {
        const Self = @This();
        pub const POOL_DEF = DEF;
        pub const ELEM = DEF.ELEM;
        pub const IDX = DEF.IDX;
        const STATE_INT = STATE_INT_;
        const LOCK_MODE = DEF.LOCK_MODE;
        const MASTER_LOCK = LOCK_MODE == .MASTER_LOCK or LOCK_MODE == .MASTER_AND_BLOCK_LOCK;
        const NEED_IO = MASTER_LOCK;
        const DATA_BLOCK_BYTE_SIZE_POWER = DEF.DATA_BLOCK_BYTE_SIZE_AND_ALIGNMENT;
        const DATA_BLOCK_SLOT_LENGTH: IDX = @intCast(DATA_BLOCK_SLOT_LENGTH_);
        const DATA_BLOCK_STATE_GROUP_LENGTH: IDX = @intCast(DATA_BLOCK_STATE_GROUP_LENGTH_);
        const DATA_BLOCK_STATE_VEC_SIZE = DATA_BLOCK_STATE_GROUP_LENGTH / STATE_SIMD_WIDTH;
        pub const WASTE_BYTES_PER_DATA_BLOCK = WASTE_BYTES_IN_BLOCK_;
        const INVALID_IDX = math.maxInt(IDX);
        const FREE_STATE: STATE_INT = 0b1;
        const USED_STATE: STATE_INT = 0b0;
        const STATE_SIMD_WIDTH = @min(64, std.simd.suggestVectorLength(STATE_INT) orelse 1);
        const USE_SIMD = STATE_SIMD_WIDTH > 1 and DATA_BLOCK_STATE_GROUP_LENGTH >= STATE_SIMD_WIDTH;
        const StateVector = @Vector(STATE_SIMD_WIDTH, STATE_INT);
        const BoolVector = @Vector(STATE_SIMD_WIDTH, bool);
        const BoolVectorInt = @Int(.unsigned, STATE_SIMD_WIDTH);
        const STATE_VEC_ALIGN = if (USE_SIMD) @alignOf(StateVector) else @alignOf(STATE_INT);
        const STATE_VEC_SIZE = @sizeOf(StateVector);
        const STATE_INT_BITS: u16 = @bitSizeOf(STATE_INT);
        const STATE_INT_BITS_SHIFT: math.Log2Int(IDX) = @intCast(@ctz(STATE_INT_BITS));
        const STATE_INT_BITS_MINUS_ONE = STATE_INT_BITS - 1;
        const ALLOC_MODE = DEF.ALLOC_MODE;
        const CachedAlloc = ALLOC_MODE.CachedAlloc();
        const FuncAlloc = ALLOC_MODE.FuncParamAlloc();
        const CACHED_ALLOC_DEFAULT = ALLOC_MODE.CACHED_ALLOC_DEFAULT();
        const EMPTY_STATE_VEC_ALL_ONES: StateVector = @splat(1);
        const FULL_STATE_VEC_ALL_ZEROES: StateVector = @splat(0);
        const EMPTY_STATE_BLOCK: STATE_INT = math.maxInt(STATE_INT);
        const FULL_STATE_BLOCK: STATE_INT = 0;
        const SLOT_STEP_PER_VEC = STATE_SIMD_WIDTH * STATE_INT_BITS;
        const SLOT_STEP_PER_STATE_GROUP = STATE_INT_BITS;
        const STATE_STEP_PER_VEC = STATE_SIMD_WIDTH;
        const DATA_BLOCK_ALIGN = @alignOf(DataBlock);
        const BLOCK_LOCK = DEF.LOCK_MODE == .MASTER_AND_BLOCK_LOCK;
        const DATA_BLOCK_SIZE_ALIGN = DEF.DATA_BLOCK_BYTE_SIZE_AND_ALIGNMENT.value_as_type(usize);
        const DATA_BLOCK_PTR_MASK = ~(DATA_BLOCK_SIZE_ALIGN - 1);

        const DataBlock = struct {
            vals: [DATA_BLOCK_SLOT_LENGTH]ELEM align(DATA_BLOCK_SIZE_ALIGN) = undefined,
            state: [DATA_BLOCK_STATE_GROUP_LENGTH]STATE_INT align(STATE_VEC_ALIGN) = @splat(EMPTY_STATE_BLOCK),
            num_free: IDX = @intCast(DATA_BLOCK_SLOT_LENGTH),
            self_idx: IDX = INVALID_IDX,
            lock: if (BLOCK_LOCK) RwLock else void = if (BLOCK_LOCK) RwLock.init else {},
            pool: ?*Self = null,
        };
        comptime {
            assert_with_reason(@sizeOf(DataBlock) == DATA_BLOCK_SIZE_ALIGN, null, "`DataBlock` did not have the resultant target size of `{d}`, got `{d}` instead", .{ DATA_BLOCK_SIZE_ALIGN, @sizeOf(DataBlock) });
            assert_with_reason(@alignOf(DataBlock) == DATA_BLOCK_SIZE_ALIGN, null, "`DataBlock` did not have the resultant target align of `{d}`, got `{d}` instead", .{ DATA_BLOCK_SIZE_ALIGN, @alignOf(DataBlock) });
        }
        const DataBlockSlice = ListSliceModule.ListFullDefinition(*DataBlock, IDX, .WHOLE_STRUCTS, .SERIAL_INDEXES, .REFERENCED_MUTABLE, .MANUAL_ALLOC);

        blocks: [*]*DataBlock = invalid_ptr_many(*DataBlock),
        blocks_cap: IDX = 0,
        num_free: IDX = 0,
        cached_alloc: CachedAlloc = CACHED_ALLOC_DEFAULT,
        master_lock: if (MASTER_LOCK) RwLock else void = if (MASTER_LOCK) RwLock.init else {},
        io: if (NEED_IO) Io else void = if (NEED_IO) undefined else {},

        // fn data_block_contains_slot_addr(slice: DataBlockSlice, idx_in_list: IDX, _: *DataBlock, slot_addr: usize, comptime _: void) bool {
        //     const block_addr = @intFromPtr(slice.get(idx_in_list));
        //     return block_addr <= slot_addr and slot_addr < block_addr + @sizeOf(DataBlock);
        // }
        // fn data_block_addr_gt_slot_addr(slice: DataBlockSlice, idx_in_list: IDX, _: *DataBlock, slot_addr: usize, comptime _: void) bool {
        //     return @intFromPtr(slice.get(idx_in_list)) > slot_addr;
        // }
        // fn binary_search_for_block_idx_for_slot_addr(self: *const Self, slot_addr: usize) ?IDX {
        //     const block_slice = DataBlockSlice.from_slice_keep_data(self.blocks[0..self.blocks_cap]);
        //     return block_slice.binary_search_advanced(invalid_ptr(DataBlock), 0, self.blocks_cap, slot_addr, {}, .COMPTIME_FN_BODY, {}, data_block_contains_slot_addr, .COMPTIME_FN_BODY, {}, data_block_addr_gt_slot_addr);
        // }
        // fn binary_search_for_block_idx_for_slot(self: *const Self, slot: *ELEM) ?IDX {
        //     return self.binary_search_for_block_idx_for_slot_addr(@intFromPtr(slot));
        // }
        const BlockSlotIdx = struct {
            block: IDX,
            slot: IDX,
        };
        // fn binary_search_for_block_idx_and_slot_idx_for_slot(self: *const Self, slot: *ELEM) ?BlockSlotIdx {
        //     const slot_addr = @intFromPtr(slot);
        //     if (self.binary_search_for_block_idx_for_slot_addr(slot_addr)) |block_idx| {
        //         const block = self.blocks[block_idx];
        //         const vals_addr = @intFromPtr(&block.vals[0]);
        //         const vals_end = vals_addr + (DATA_BLOCK_SLOT_LENGTH * @sizeOf(ELEM));
        //         assert_with_reason(slot_addr >= vals_addr and slot_addr < vals_end, @src(), "slot pointer is inside a data block but outside of its values array", .{});
        //         const byte_offset = slot_addr - vals_addr;
        //         assert_with_reason(byte_offset % @sizeOf(ELEM) == 0, @src(), "slot pointer is not aligned to an element boundary", .{});
        //         return BlockSlotIdx{ .block = block_idx, .slot = @intCast(byte_offset / @sizeOf(ELEM)) };
        //     } else {
        //         return null;
        //     }
        // }

        pub inline fn lock_pool_for_write(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.master_lock.lockUncancelable(self.io);
            }
        }
        pub inline fn unlock_pool_for_write(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.master_lock.unlock(self.io);
            }
        }
        pub inline fn lock_pool_for_read(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.master_lock.lockSharedUncancelable(self.io);
            }
        }
        pub inline fn unlock_pool_for_read(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.master_lock.unlockShared(self.io);
            }
        }
        pub fn lock_block_for_write(self: *Self, block: *DataBlock) void {
            if (comptime BLOCK_LOCK) {
                block.lock.lockUncancelable(self.io);
            }
        }
        pub fn unlock_block_for_write(self: *Self, block: *DataBlock) void {
            if (comptime BLOCK_LOCK) {
                block.lock.unlock(self.io);
            }
        }
        pub fn lock_block_for_read(self: *Self, block: *DataBlock) void {
            if (comptime BLOCK_LOCK) {
                block.lock.lockSharedUncancelable(self.io);
            }
        }
        pub fn unlock_block_for_read(self: *Self, block: *DataBlock) void {
            if (comptime BLOCK_LOCK) {
                block.lock.unlockShared(self.io);
            }
        }
        // fn data_block_ptr_gt(slice: DataBlockSlice, idx_in_list: IDX, data_ptr_to_compare: *DataBlock, _: void, comptime _: void) bool {
        //     return @intFromPtr(slice.get(idx_in_list)) > @intFromPtr(data_ptr_to_compare);
        // }

        pub fn ensure_free_slots_ignore_locks(self: *Self, needed_free_slots: IDX, fn_alloc: FuncAlloc) void {
            if (self.num_free < needed_free_slots) {
                const deficit = needed_free_slots - self.num_free;
                const needed_blocks = @divCeil(deficit, DATA_BLOCK_SLOT_LENGTH);
                assert_with_reason(needed_blocks <= INVALID_IDX - self.blocks_cap, @src(), "adding {d} data blocks would overflow the block capacity integer", .{needed_blocks});
                assert_with_reason(self.blocks_cap <= INVALID_IDX / DATA_BLOCK_SLOT_LENGTH and needed_blocks <= (INVALID_IDX / DATA_BLOCK_SLOT_LENGTH) - self.blocks_cap, @src(), "adding {d} data blocks would make the pool capacity exceed `math.maxInt(IDX)` ({d})", .{ needed_blocks, INVALID_IDX });
                const new_blocks_cap = self.blocks_cap + needed_blocks;
                const old_blocks_cap = self.blocks_cap;
                const alloc = ALLOC_MODE.get_alloc(fn_alloc, self.cached_alloc);
                const new_block_list = alloc.realloc(self.blocks[0..self.blocks_cap], new_blocks_cap) catch |e| assert_allocation_failure(@src(), *DataBlock, needed_blocks, e);
                self.blocks = new_block_list.ptr;
                self.blocks_cap = new_blocks_cap;
                for (self.blocks[old_blocks_cap..new_blocks_cap]) |*block| {
                    const new_block = alloc.create(DataBlock) catch |e| assert_allocation_failure(@src(), DataBlock, 1, e);
                    new_block.* = DataBlock{};
                    block.* = new_block;
                }
                self.num_free += needed_blocks * DATA_BLOCK_SLOT_LENGTH;
                const blocks_slice = DataBlockSlice.from_slice_keep_data(self.blocks[0..new_blocks_cap]);
                blocks_slice.insertion_sort_advanced({}, {}, .COMPTIME_FN_BODY, {}, data_block_ptr_gt);
            }
        }

        pub inline fn ensure_free_slots(self: *Self, needed_free_slots: IDX, fn_alloc: FuncAlloc) void {
            self.lock_pool_for_write();
            self.ensure_free_slots_ignore_locks(needed_free_slots, fn_alloc);
            self.unlock_pool_for_write();
        }
        pub fn get_num_free_ignore_locks(self: *Self) IDX {
            return self.num_free;
        }
        pub fn get_num_free(self: *Self) IDX {
            self.lock_pool_for_read();
            const num = self.num_free;
            self.unlock_pool_for_read();
            return num;
        }
        pub fn init(init_capacity: IDX, allocator: Allocator, init_io: if (NEED_IO) Io else void) Self {
            var self = Self{
                .cached_alloc = ALLOC_MODE.alloc_to_cached_alloc(allocator),
                .io = init_io,
            };
            self.ensure_free_slots_ignore_locks(init_capacity, ALLOC_MODE.alloc_to_func_alloc(allocator));
            return self;
        }

        pub fn uninit(self: *Self, fn_alloc: FuncAlloc) void {
            self.lock_pool_for_write();
            if (self.blocks_cap > 0) {
                const alloc = ALLOC_MODE.get_alloc(fn_alloc, self.cached_alloc);
                for (self.blocks[0..self.blocks_cap]) |block| {
                    alloc.destroy(block);
                }
                alloc.free(self.blocks[0..self.blocks_cap]);
            }
            self.unlock_pool_for_write();
            self.* = .{};
        }

        pub const Key = struct {
            ptr: ?*ELEM = null,

            pub inline fn to_const(self: Key) ConstKey {
                return ConstKey{
                    .ptr = self.ptr,
                };
            }

            inline fn data_block(self: Key) *DataBlock {
                const ptr_addr = @intFromPtr(self.ptr.?);
                const block_addr = ptr_addr & DATA_BLOCK_PTR_MASK;
                return @ptrFromInt(block_addr);
            }
            inline fn data_block_and_idx(self: Key) struct { *DataBlock, IDX } {
                const ptr_addr = @intFromPtr(self.ptr.?);
                const block_addr = ptr_addr & DATA_BLOCK_PTR_MASK;
                const offset_addr = @offsetOf(DataBlock, "vals");
                const vals_addr = block_addr + offset_addr;
                return .{ @ptrFromInt(block_addr), @intCast((ptr_addr - vals_addr) / @sizeOf(ELEM)) };
            }
            inline fn pool_unchecked(self: Key) *DataBlock {
                return self.data_block().pool.?;
            }
            pub inline fn pool(self: Key) *Self {
                self.assert_valid();
                return self.data_block().pool.?;
            }

            pub inline fn is_valid(self: Key) bool {
                return self.ptr != null and self.data_block().pool != null;
            }
            inline fn assert_valid(self: Key) void {
                assert_with_reason(self.is_valid(), @src(), "key is not valid (was freed)", .{});
            }

            pub fn get(self: Key) ELEM {
                self.assert_valid();
                const block = self.data_block();
                const pool_for_key = block.pool.?;
                pool_for_key.lock_block_for_read(block);
                defer pool_for_key.unlock_block_for_read(block);
                return self.ptr.?.*;
            }
            pub fn get_ignore_locks(self: Key) ELEM {
                self.assert_valid();
                return self.ptr.?.*;
            }
            pub fn set(self: Key, val: ELEM) void {
                self.assert_valid();
                const block = self.data_block();
                const pool_for_key = block.pool.?;
                pool_for_key.lock_block_for_write(block);
                defer pool_for_key.unlock_block_for_write(block);
                self.ptr.?.* = val;
            }
            pub fn set_ignore_locks(self: Key, val: ELEM) void {
                self.assert_valid();
                self.ptr.?.* = val;
            }
            pub fn release(self: *Key) void {
                self.assert_valid();
                const block, const slot_idx = self.data_block_and_idx();
                block.pool.?.release_key_internal(.KEY_PTR, self, block, slot_idx, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS);
            }
            pub fn release_without_setting_null(self: Key) void {
                self.assert_valid();
                const block, const slot_idx = self.data_block_and_idx();
                block.pool.?.release_key_internal(.KEY_VAL, self, block, slot_idx, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS);
            }
        };

        pub const ConstKey = struct {
            ptr: ?*ELEM = null,

            inline fn to_mut(self: ConstKey) Key {
                return Key{
                    .ptr = self.ptr,
                };
            }
            inline fn to_mut_ptr(self: *ConstKey) *Key {
                return @ptrCast(@alignCast(self));
            }
            pub inline fn pool(self: ConstKey) *Self {
                return self.to_mut().pool();
            }
            pub inline fn is_valid(self: ConstKey) bool {
                return self.to_mut().is_valid();
            }
            pub inline fn get(self: ConstKey) ELEM {
                return self.to_mut().get();
            }
            pub inline fn get_ignore_locks(self: ConstKey) ELEM {
                return self.to_mut().get_ignore_locks();
            }
            pub inline fn release(self: *ConstKey) void {
                return self.to_mut_ptr().release();
            }
            pub inline fn release_without_setting_null(self: ConstKey) void {
                return self.to_mut().release_without_setting_null();
            }
        };

        pub fn claim_key_advanced(self: *Self, fn_alloc: FuncAlloc, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode) Key {
            switch (comptime pool_lock) {
                .CHECK_POOL_LOCKS => self.lock_pool_for_write(),
                .IGNORE_POOL_LOCKS => {},
            }
            defer switch (comptime pool_lock) {
                .CHECK_POOL_LOCKS => self.unlock_pool_for_write(),
                .IGNORE_POOL_LOCKS => {},
            };
            self.ensure_free_slots_ignore_locks(1, fn_alloc);
            for (self.blocks[0..self.blocks_cap]) |block| {
                switch (comptime block_lock) {
                    .CHECK_BLOCK_LOCKS => self.lock_block_for_write(block),
                    .IGNORE_BLOCK_LOCKS => {},
                }
                defer switch (comptime block_lock) {
                    .CHECK_BLOCK_LOCKS => self.unlock_block_for_write(block),
                    .IGNORE_BLOCK_LOCKS => {},
                };
                if (block.num_free == 0) continue;
                var slot_idx: IDX = 0;
                var state_idx: IDX = 0;
                var remaining: IDX = DATA_BLOCK_SLOT_LENGTH;
                if (comptime USE_SIMD) {
                    var state_vec_ptr: [*]StateVector = @ptrCast(@alignCast(&block.state));
                    while (remaining >= SLOT_STEP_PER_VEC) {
                        const state_vec: StateVector = state_vec_ptr[0];
                        const any_in_vec_empty = state_vec > FULL_STATE_VEC_ALL_ZEROES;
                        const any_in_vec_empty_int: BoolVectorInt = @bitCast(any_in_vec_empty);
                        if (any_in_vec_empty_int != 0) {
                            const first_block_with_empty: IDX = @intCast(@ctz(any_in_vec_empty_int));
                            var state_block_ptr: [*]usize = @ptrCast(@alignCast(state_vec_ptr));
                            state_block_ptr += first_block_with_empty;
                            const first_emtpy_slot_in_block: IDX = @intCast(@ctz(state_block_ptr[0]));
                            const true_idx = slot_idx + (first_block_with_empty * SLOT_STEP_PER_STATE_GROUP) + first_emtpy_slot_in_block;
                            const slot_ptr = &block.vals[true_idx];
                            state_block_ptr[0] &= state_block_ptr[0] - 1;
                            self.num_free -= 1;
                            block.num_free -= 1;
                            return slot_ptr;
                        }
                        state_vec_ptr += 1;
                        state_idx += STATE_STEP_PER_VEC;
                        remaining -= SLOT_STEP_PER_VEC;
                        slot_idx += SLOT_STEP_PER_VEC;
                    }
                }
                while (remaining > 0) {
                    const state = block.state[state_idx];
                    if (state != 0) {
                        const first_emtpy_slot_in_block: IDX = @intCast(@ctz(state));
                        const true_idx = slot_idx + first_emtpy_slot_in_block;
                        const slot_ptr: *ELEM = &block.vals[true_idx];
                        block.state[state_idx] &= block.state[state_idx] - 1;
                        self.num_free -= 1;
                        block.num_free -= 1;
                        return Key{
                            .ptr = slot_ptr,
                        };
                    }
                    state_idx += 1;
                    remaining -= SLOT_STEP_PER_STATE_GROUP;
                    slot_idx += SLOT_STEP_PER_STATE_GROUP;
                }
            }
            assert_unreachable(@src(), "no blocks had free slots: either the pool was corrupted or `ensure_free_slots(1)` failed to actually ensure free slots", .{});
            return invalid_ptr(ELEM);
        }

        pub inline fn claim_slot(self: *Self, fn_alloc: FuncAlloc) Key {
            return self.claim_key_advanced(fn_alloc, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS);
        }

        fn release_key_internal(self: *Self, comptime KEY_MODE: KeyMode, key: if (KEY_MODE == .KEY_PTR) *Key else Key, block: *DataBlock, slot_idx: IDX, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode) void {
            switch (comptime pool_lock) {
                .CHECK_POOL_LOCKS => self.lock_pool_for_write(),
                .IGNORE_POOL_LOCKS => {},
            }
            defer switch (comptime pool_lock) {
                .CHECK_POOL_LOCKS => self.unlock_pool_for_write(),
                .IGNORE_POOL_LOCKS => {},
            };
            switch (comptime block_lock) {
                .CHECK_BLOCK_LOCKS => self.lock_block_for_write(block),
                .IGNORE_BLOCK_LOCKS => {},
            }
            defer switch (comptime block_lock) {
                .CHECK_BLOCK_LOCKS => self.unlock_block_for_write(block),
                .IGNORE_BLOCK_LOCKS => {},
            };
            const state_idx = slot_idx >> STATE_INT_BITS_SHIFT;
            const state_bit_idx = slot_idx & STATE_INT_BITS_MINUS_ONE;
            const state_bit = @as(STATE_INT, 1) << @intCast(state_bit_idx);
            assert_with_reason(block.state[state_idx] & state_bit == USED_STATE, @src(), "slot was already free, cannot release it again", .{});
            block.state[state_idx] |= state_bit;
            block.num_free += 1;
            self.num_free += 1;
            if (comptime KEY_MODE == .KEY_PTR) {
                key.ptr = null;
            }
        }

        pub fn release_key_advanced(self: *Self, key: *Key, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode) void {
            key.assert_valid();
            const block, const slot_idx = key.data_block_and_idx();
            self.release_key_internal(.KEY_PTR, key, block, slot_idx, pool_lock, block_lock);
        }
        pub fn release_key(self: *Self, key: *Key) void {
            self.release_key_advanced(key, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS);
        }
        pub fn release_key_val_advanced(self: *Self, key: Key, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode) void {
            key.assert_valid();
            const block, const slot_idx = key.data_block_and_idx();
            self.release_key_internal(.KEY_VAL, key, block, slot_idx, pool_lock, block_lock);
        }
        pub fn release_key_val(self: *Self, key: Key) void {
            self.release_key_advanced(key, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS);
        }

        pub fn IteratorAdvanced(comptime slot_mode: IterSlotMode, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode) type {
            return struct {
                const IterSelf = @This();
                pool: *Self = invalid_ptr(Self),
                block: *DataBlock = invalid_ptr(DataBlock),
                block_idx: IDX = 0,
                state_idx: IDX = 0,
                num_used_in_block: IDX = 0,
                num_used_in_pool: IDX = 0,
                curr_state_inverted: usize = 0,
                block_is_locked: bool = false,

                const SlotReturn = switch (slot_mode) {
                    .VAL => ?ELEM,
                    .PTR => ?*ELEM,
                    .CONST_PTR => ?*const ELEM,
                };

                pub fn init_and_lock(pool: *Self) IterSelf {
                    var self = IterSelf{
                        .pool = pool,
                    };
                    switch (comptime pool_lock) {
                        .CHECK_POOL_LOCKS => pool.lock_pool_for_read(),
                        .IGNORE_POOL_LOCKS => {},
                    }
                    if (pool.blocks_cap > 0) {
                        self.block = pool.blocks[0];
                        switch (comptime block_lock) {
                            .CHECK_BLOCK_LOCKS => switch (comptime slot_mode) {
                                .VAL, .CONST_PTR => pool.lock_block_for_read(self.block),
                                .PTR => pool.lock_block_for_write(self.block),
                            },
                            .IGNORE_BLOCK_LOCKS => {},
                        }
                        self.block_is_locked = true;
                        self.num_used_in_block = DATA_BLOCK_SLOT_LENGTH - self.block.num_free;
                        self.num_used_in_pool = (DATA_BLOCK_SLOT_LENGTH * pool.blocks_cap) - pool.num_free;
                        self.curr_state_inverted = ~self.block.state[0];
                    }
                    return self;
                }

                pub fn next(self: *IterSelf) SlotReturn {
                    if (self.block_idx >= self.pool.blocks_cap) return null;
                    loop_over_data_blocks: while (self.num_used_in_pool > 0) {
                        loop_over_state_groups: while (self.num_used_in_block > 0) {
                            while (self.curr_state_inverted != 0) { // loop_over_slots_in_group
                                const first_used_slot_bit_offset: IDX = @intCast(@ctz(self.curr_state_inverted));
                                self.curr_state_inverted &= self.curr_state_inverted - 1;
                                const first_used_slot_within_block = (self.state_idx * SLOT_STEP_PER_STATE_GROUP) + first_used_slot_bit_offset;
                                const slot: SlotReturn = switch (comptime slot_mode) {
                                    .VAL => self.block.vals[first_used_slot_within_block],
                                    .PTR, .CONST_PTR => &self.block.vals[first_used_slot_within_block],
                                };
                                self.num_used_in_block -= 1;
                                self.num_used_in_pool -= 1;
                                return slot;
                            }
                            self.state_idx += 1;
                            if (self.state_idx < DATA_BLOCK_STATE_GROUP_LENGTH) {
                                self.curr_state_inverted = ~self.block.state[self.state_idx];
                            } else {
                                break :loop_over_state_groups;
                            }
                        }
                        if (self.block_is_locked) {
                            switch (comptime block_lock) {
                                .CHECK_BLOCK_LOCKS => switch (comptime slot_mode) {
                                    .VAL, .CONST_PTR => self.pool.unlock_block_for_read(self.block),
                                    .PTR => self.pool.unlock_block_for_write(self.block),
                                },
                                .IGNORE_BLOCK_LOCKS => {},
                            }
                            self.block_is_locked = false;
                        }
                        self.block_idx = @min(self.block_idx + 1, self.pool.blocks_cap);
                        if (self.block_idx < self.pool.blocks_cap) {
                            self.block = self.pool.blocks[self.block_idx];
                            switch (comptime block_lock) {
                                .CHECK_BLOCK_LOCKS => switch (comptime slot_mode) {
                                    .VAL, .CONST_PTR => self.pool.lock_block_for_read(self.block),
                                    .PTR => self.pool.lock_block_for_write(self.block),
                                },
                                .IGNORE_BLOCK_LOCKS => {},
                            }
                            self.block_is_locked = true;
                            self.num_used_in_block = DATA_BLOCK_SLOT_LENGTH - self.block.num_free;
                            self.state_idx = 0;
                            self.curr_state_inverted = ~self.block.state[0];
                        } else {
                            break :loop_over_data_blocks;
                        }
                    }
                    return null;
                }

                pub fn deinit_and_unlock(self: *IterSelf) void {
                    if (self.block_is_locked) {
                        switch (comptime block_lock) {
                            .CHECK_BLOCK_LOCKS => switch (comptime slot_mode) {
                                .VAL, .CONST_PTR => self.pool.unlock_block_for_read(self.block),
                                .PTR => self.pool.unlock_block_for_write(self.block),
                            },
                            .IGNORE_BLOCK_LOCKS => {},
                        }
                    }
                    switch (comptime pool_lock) {
                        .CHECK_POOL_LOCKS => self.pool.unlock_pool_for_read(),
                        .IGNORE_POOL_LOCKS => {},
                    }
                    self.* = IterSelf{};
                }
            };
        }

        pub inline fn iterator_advanced(self: *Self, comptime slot_mode: IterSlotMode, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode) IteratorAdvanced(slot_mode, pool_lock, block_lock) {
            return IteratorAdvanced(slot_mode, pool_lock, block_lock).init_and_lock(self);
        }
        pub inline fn ptr_iterator(self: *Self) IteratorAdvanced(.PTR, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS) {
            return IteratorAdvanced(.PTR, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS).init_and_lock(self);
        }
        pub inline fn const_ptr_iterator(self: *Self) IteratorAdvanced(.CONST_PTR, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS) {
            return IteratorAdvanced(.CONST_PTR, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS).init_and_lock(self);
        }
        pub inline fn val_iterator(self: *Self) IteratorAdvanced(.VAL, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS) {
            return IteratorAdvanced(.VAL, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS).init_and_lock(self);
        }
        pub inline fn ptr_iterator_ignore_locks(self: *Self) IteratorAdvanced(.PTR, .IGNORE_POOL_LOCKS, .IGNORE_BLOCK_LOCKS) {
            return IteratorAdvanced(.PTR, .IGNORE_POOL_LOCKS, .IGNORE_BLOCK_LOCKS).init_and_lock(self);
        }
        pub inline fn const_ptr_iterator_ignore_locks(self: *Self) IteratorAdvanced(.CONST_PTR, .IGNORE_POOL_LOCKS, .IGNORE_BLOCK_LOCKS) {
            return IteratorAdvanced(.CONST_PTR, .IGNORE_POOL_LOCKS, .IGNORE_BLOCK_LOCKS).init_and_lock(self);
        }
        pub inline fn val_iterator_ignore_locks(self: *Self) IteratorAdvanced(.VAL, .IGNORE_POOL_LOCKS, .IGNORE_BLOCK_LOCKS) {
            return IteratorAdvanced(.VAL, .IGNORE_POOL_LOCKS, .IGNORE_BLOCK_LOCKS).init_and_lock(self);
        }
    };
}
