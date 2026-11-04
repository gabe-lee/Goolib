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
const Allocator = std.mem.Allocator;
const Utils = Root.Utils;
const Growth = Root.CommonTypes.GrowthModel;
const RwLock = std.Io.RwLock;
const Io = std.Io;
const CachedAllocMode = Root.CommonTypes.CachedAllocMode;
const ListSliceMoule = Root.ListSlice;
const PowerOf2 = Root.Math.PowerOf2;
pub const LockModule = Root.Lock;
pub const LockKind = LockModule.LockKind;

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const invalid_ptr = Utils.invalid_ptr;
const invalid_ptr_many = Utils.invalid_ptr_many;

pub const MultiPoolDef = struct {
    ELEM: type,
};

pub const PoolLockMode = enum {
    CHECK_POOL_LOCKS,
    IGNORE_POOL_LOCKS,
};

pub const BlockLockMode = enum {
    CHECK_BLOCK_LOCKS,
    IGNORE_BLOCK_LOCKS,
};

pub const ElemLockMode = enum {
    CHECK_ELEM_LOCKS,
    IGNORE_ELEM_LOCKS,
};

pub const PoolLockModeAdv = enum {
    IGNORE_POOL_LOCK,
    READ_POOL_TRANSIENT,
    READ_POOL_KEEP_LOCKED,
    WRITE_POOL_TRANSIENT,
    WRITE_POOL_KEEP_LOCKED,
};

pub const BlockLockModeAdv = enum {
    IGNORE_BLOCK_LOCK,
    READ_BLOCK_TRANSIENT,
    READ_BLOCK_KEEP_LOCKED,
    WRITE_BLOCK_TRANSIENT,
    WRITE_BLOCK_KEEP_LOCKED,
};

pub const IterSlotMode = enum {
    VAL,
    PTR,
    CONST_PTR,
};

pub const GlobalDef = struct {
    /// Max number of elements per type catagory
    MAX_NUM_ELEMS: PowerOf2 = ._4_294_967_296,
    /// Max generation before generation rollover
    MAX_GENERATION: PowerOf2 = ._4_294_967_296,
    /// A list of all types for the Global Multi-Type Pool
    POOL_DEFS: []const SubPoolDef,
    /// The locking mechanism to use for each pool, as a whole
    POOL_LOCK_MODE: LockKind = .NONE,
    /// The locking mechanism to use for each block of elements
    BLOCK_LOCK_MODE: LockKind = .NONE,
    /// The locking mechanism to use for each individial element
    ELEM_LOCK_MODE: LockKind = .NONE,
    /// How to handle assertions for element state
    ELEM_STATE_ASSERT_MODE: Assert.AssertBehavior = .PANIC_IN_SAFE_MODES,
};

pub const SubPoolDef = struct {
    /// The elem type for the pool
    TYPE: type,
    /// the uint type to use for state
    STATE_UINT: type = usize,
    /// The number of blocks per block. MUST be a positive multiple of @bitSizeOf(STATE_UINT)
    SLOTS_PER_BLOCK: PowerOf2 = ._64,
};

pub fn GlobalMultiTypeBitTrackedPool(comptime GDEF: GlobalDef) type {
    assert_with_reason(GDEF.POOL_DEFS.len > 0, @src(), "`POOL_DEFS` must contain at least one sub-pool definition", .{});
    comptime var pool_types: [GDEF.POOL_DEFS.len]type = undefined;
    comptime var pool_defs: [GDEF.POOL_DEFS.len]SubPoolDef = undefined;
    pool_types[0] = GDEF.POOL_DEFS[0].TYPE;
    pool_defs[0] = GDEF.POOL_DEFS[0];
    inline for (GDEF.POOL_DEFS[1..], 1..) |def, i| {
        inline for (pool_types[0..i]) |type_already_defined| {
            assert_with_reason(type_already_defined != def.TYPE, @src(), "type `{s}` was already defined as a pool type", .{@typeName(def.TYPE)});
        }
        pool_types[i] = def.TYPE;
        pool_defs[i] = def;
    }
    const pool_types_const = pool_types;
    const pool_defs_const = pool_defs;
    return struct {
        const Global = @This();
        const ElemIdx = GDEF.MAX_NUM_ELEMS.unsigned_integer_type_that_holds_all_values_less_than();
        const INVALID_IDX = math.maxInt(ElemIdx);
        const GenId = GDEF.MAX_GENERATION.unsigned_integer_type_that_holds_all_values_less_than();
        const NUM_TYPES = GDEF.POOL_DEFS.len;
        const POOL_LOCK_MODE = GDEF.POOL_LOCK_MODE;
        const BLOCK_LOCK_MODE = GDEF.BLOCK_LOCK_MODE;
        const ELEM_LOCK_MODE = GDEF.ELEM_LOCK_MODE;
        const PoolLock = GDEF.POOL_LOCK_MODE.lock_type();
        const PoolLockDefault = GDEF.POOL_LOCK_MODE.init();
        const PoolLockIo = GDEF.POOL_LOCK_MODE.io_type();
        const BlockLock = GDEF.BLOCK_LOCK_MODE.lock_type();
        const BlockLockDefault = GDEF.BLOCK_LOCK_MODE.init();
        const BlockLockIo = GDEF.BLOCK_LOCK_MODE.io_type();
        const ElemLock = GDEF.ELEM_LOCK_MODE.lock_type();
        const ElemLockDefault = GDEF.ELEM_LOCK_MODE.init();
        const ElemLockIo = GDEF.ELEM_LOCK_MODE.io_type();
        const TypeId = PowerOf2.round_up_to_power_of_2(NUM_TYPES).unsigned_integer_type_that_holds_all_values_less_than();
        const PoolTypes = pool_types_const;
        const StateAssert = Assert.AssertHandler(GDEF.ELEM_STATE_ASSERT_MODE);
        const POOLS = build: {
            var out: [NUM_TYPES]type = undefined;
            for (GDEF.POOL_DEFS, 0..) |def, i| {
                out[i] = SubPool(def);
            }
            break :build out;
        };
        const POOL_DEFS = pool_defs_const;
        pub fn Key(comptime T: type) type {
            return packed struct {
                const KeySelf = @This();
                pub const TYPE = T;
                const POOL_IDX = find: {
                    for (GDEF.POOL_DEFS, 0..) |def, i| {
                        if (def.TYPE == T) break :find i;
                    }
                    assert_unreachable(null, "type `{s}` is not valid for any pool", .{@typeName(T)});
                };
                const POOL_DEF = POOL_DEFS[POOL_IDX];
                const POOL: type = POOLS[POOL_IDX];

                block_idx: POOL.BlockIdx,
                elem_idx: POOL.SubElemIdx,
                gen: GenId,

                fn assert_valid(self: KeySelf, block: *POOL.DataBlock) void {
                    StateAssert._with_reason(block.gens[self.elem_idx] == self.gen, @src(), "cached gen does not match gen on key ({d} != {d}), key invalid", .{ block.gens[self.elem_idx], self.gen });
                    if (comptime StateAssert._should_assert()) {
                        const elem_idx: usize = self.elem_idx;
                        const state_idx = elem_idx >> POOL.STATE_INT_BITS_SHIFT;
                        const state_bit_idx = elem_idx & POOL.STATE_INT_BITS_MINUS_ONE;
                        const state_bit_empty = @as(POOL.STATE_UINT, 1) << @intCast(state_bit_idx);
                        const state = block.state[state_idx];
                        const was_used = state & state_bit_empty == 0;
                        StateAssert._with_reason(was_used, @src(), "element was not in a used state, key is invalid", .{});
                    }
                }

                pub fn is_valid(self: KeySelf) bool {
                    POOL_LOCK_MODE.lock_for_read_io(if (POOL_LOCK_MODE.has_lock()) &POOL.pool_lock else {}, io);
                    defer POOL_LOCK_MODE.unlock_for_read_io(if (POOL_LOCK_MODE.has_lock()) &POOL.pool_lock else {}, io);
                    if (self.block_idx >= POOL.blocks_cap) return false;
                    const block = POOL.blocks[self.block_idx];
                    BLOCK_LOCK_MODE.lock_for_read_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                    ELEM_LOCK_MODE.lock_for_read_io(if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, io);
                    defer ELEM_LOCK_MODE.unlock_for_read_io(if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, io);
                    if (block.gens[self.elem_idx] != self.gen) return false;
                    const elem_idx: usize = self.elem_idx;
                    const state_idx = elem_idx >> POOL.STATE_INT_BITS_SHIFT;
                    const state_bit_idx = elem_idx & POOL.STATE_INT_BITS_MINUS_ONE;
                    const state_bit_empty = @as(POOL.STATE_UINT, 1) << @intCast(state_bit_idx);
                    return block.state[state_idx] & state_bit_empty == 0;
                }
                fn assert_valid_get_info(self: KeySelf, block: *POOL.DataBlock) POOL.StateInfo {
                    StateAssert._with_reason(block.gens[self.elem_idx] == self.gen, @src(), "cached gen does not match gen on key ({d} != {d}), key invalid", .{ block.gens[self.elem_idx], self.gen });
                    const elem_idx: usize = self.elem_idx;
                    const state_idx = elem_idx >> POOL.STATE_INT_BITS_SHIFT;
                    const state_bit_idx = elem_idx & POOL.STATE_INT_BITS_MINUS_ONE;
                    const state_bit_empty = @as(POOL.STATE_UINT, 1) << @intCast(state_bit_idx);
                    if (comptime StateAssert._should_assert()) {
                        const state = block.state[state_idx];
                        const was_used = state & state_bit_empty == 0;
                        StateAssert._with_reason(was_used, @src(), "element was not in a used state, key is invalid", .{});
                    }
                    return POOL.StateInfo{
                        .state_idx = state_idx,
                        .state_bit_idx = state_bit_idx,
                        .state_bit_empty = state_bit_empty,
                    };
                }

                pub fn get(self: KeySelf) T {
                    POOL_LOCK_MODE.lock_for_read_io(if (POOL_LOCK_MODE.has_lock()) &POOL.pool_lock else {}, io);
                    assert_with_reason(self.block_idx < POOL.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.blocks_cap });
                    const block = POOL.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(if (POOL_LOCK_MODE.has_lock()) &POOL.pool_lock else {}, io);
                    BLOCK_LOCK_MODE.lock_for_read_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                    ELEM_LOCK_MODE.lock_for_read_io(if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, io);
                    defer ELEM_LOCK_MODE.unlock_for_read_io(if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, io);
                    self.assert_valid(block);
                    return block.vals[self.elem_idx];
                }

                pub fn set(self: KeySelf, val: T) void {
                    POOL_LOCK_MODE.lock_for_read_io(if (POOL_LOCK_MODE.has_lock()) &POOL.pool_lock else {}, io);
                    assert_with_reason(self.block_idx < POOL.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.blocks_cap });
                    const block = POOL.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(if (POOL_LOCK_MODE.has_lock()) &POOL.pool_lock else {}, io);
                    BLOCK_LOCK_MODE.lock_for_read_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                    ELEM_LOCK_MODE.lock_for_write_io(if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, io);
                    defer ELEM_LOCK_MODE.unlock_for_write_io(if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, io);
                    self.assert_valid(block);
                    block.vals[self.elem_idx] = val;
                }

                pub fn release_advanced(self: KeySelf, comptime pool_lock_mode: PoolLockMode, comptime block_lock_mode: BlockLockMode, comptime elem_lock_mode: ElemLockMode) void {
                    switch (comptime pool_lock_mode) {
                        .CHECK_POOL_LOCKS => POOL_LOCK_MODE.lock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &POOL.pool_lock else {}, io),
                        .IGNORE_POOL_LOCKS => {},
                    }
                    defer switch (comptime pool_lock_mode) {
                        .CHECK_POOL_LOCKS => POOL_LOCK_MODE.unlock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &POOL.pool_lock else {}, io),
                        .IGNORE_POOL_LOCKS => {},
                    };
                    assert_with_reason(self.block_idx < POOL.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.blocks_cap });
                    const block = POOL.blocks[self.block_idx];
                    switch (comptime block_lock_mode) {
                        .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.lock_for_write_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io),
                        .IGNORE_BLOCK_LOCKS => {},
                    }
                    defer switch (comptime block_lock_mode) {
                        .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.unlock_for_write_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io),
                        .IGNORE_BLOCK_LOCKS => {},
                    };
                    switch (comptime elem_lock_mode) {
                        .CHECK_ELEM_LOCKS => ELEM_LOCK_MODE.lock_for_write_io(if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, io),
                        .IGNORE_ELEM_LOCKS => {},
                    }
                    defer switch (comptime elem_lock_mode) {
                        .CHECK_ELEM_LOCKS => ELEM_LOCK_MODE.unlock_for_write_io(if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, io),
                        .IGNORE_ELEM_LOCKS => {},
                    };
                    const state_info = self.assert_valid_get_info(block);
                    block.state[state_info.state_idx] |= state_info.state_bit_empty;
                    block.gens[self.elem_idx] +%= 1;
                    block.num_free += 1;
                    POOL.pool_num_free += 1;
                }
                pub inline fn release(self: KeySelf) void {
                    self.release_advanced(.CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS, .CHECK_ELEM_LOCKS);
                }
            };
        }
        fn SubPool(comptime DEF: SubPoolDef) type {
            assert_with_reason(Types.type_is_unsigned_int(ElemIdx), @src(), "type `ElemIdx` must be an unsigned integer type, got type `{s}`", .{@typeName(ElemIdx)});
            assert_with_reason(@sizeOf(DEF.TYPE) > 0, @src(), "type `TYPE` must have a non-zero size so that every slot has a distinct address", .{});
            assert_with_reason(DEF.SLOTS_PER_BLOCK.value() > 0, @src(), "`SLOTS_PER_BLOCK` must be greater than zero", .{});
            assert_with_reason(DEF.SLOTS_PER_BLOCK.value() <= math.maxInt(ElemIdx), @src(), "`SLOTS_PER_BLOCK` ({d}) must be <= `math.maxInt(ElemIdx)` ({d})", .{ DEF.SLOTS_PER_BLOCK, math.maxInt(ElemIdx) });
            assert_with_reason(DEF.SLOTS_PER_BLOCK.value() >= @bitSizeOf(DEF.STATE_UINT), @src(), "`SLOTS_PER_BLOCK` ({d}) must be at least {d} (the number of bits in `STATE_UINT`) so the state array has at least one full group", .{ DEF.SLOTS_PER_BLOCK, @bitSizeOf(DEF.STATE_UINT) });
            assert_with_reason(DEF.SLOTS_PER_BLOCK.value() % @bitSizeOf(DEF.STATE_UINT) == 0, @src(), "`SLOTS_PER_BLOCK` ({d}) must be a multiple of {d} (the number of bits in `STATE_UINT`) so every state bit maps to a real slot", .{ DEF.SLOTS_PER_BLOCK, @bitSizeOf(DEF.STATE_UINT) });
            assert_with_reason(GDEF.MAX_NUM_ELEMS.value() >= DEF.SLOTS_PER_BLOCK.value(), @src(), "`MAX_NUM_ELEMS` ({d}) must be at least `SLOTS_PER_BLOCK` ({d})", .{ GDEF.MAX_NUM_ELEMS, DEF.SLOTS_PER_BLOCK });
            return struct {
                const Sub = @This();
                const STATE_UINT = DEF.STATE_UINT;
                const SLOTS_PER_BLOCK: usize = @intCast(DEF.SLOTS_PER_BLOCK.value());
                const DATA_BLOCK_STATE_GROUP_LENGTH = @divExact(@as(usize, SLOTS_PER_BLOCK), @bitSizeOf(STATE_UINT));
                const TYPE = DEF.TYPE;
                const STATE_SIMD_WIDTH = @min(64, std.simd.suggestVectorLength(STATE_UINT) orelse 1);
                const USE_SIMD = STATE_SIMD_WIDTH > 1 and DATA_BLOCK_STATE_GROUP_LENGTH >= STATE_SIMD_WIDTH;
                const StateVector = @Vector(STATE_SIMD_WIDTH, STATE_UINT);
                const BoolVector = @Vector(STATE_SIMD_WIDTH, bool);
                const BoolVectorInt = @Int(.unsigned, STATE_SIMD_WIDTH);
                const STATE_VEC_ALIGN = if (USE_SIMD) @alignOf(StateVector) else @alignOf(STATE_UINT);
                const STATE_INT_BITS: u16 = @bitSizeOf(STATE_UINT);
                const STATE_INT_BITS_SHIFT: u8 = @intCast(@ctz(STATE_INT_BITS));
                const STATE_INT_BITS_MINUS_ONE: usize = @intCast(STATE_INT_BITS - 1);
                const FULL_STATE_VEC_ALL_ZEROES: StateVector = @splat(0);
                const EMPTY_STATE_BLOCK: STATE_UINT = math.maxInt(STATE_UINT);
                const SLOT_STEP_PER_STATE_GROUP: usize = @intCast(STATE_INT_BITS);
                const STATE_STEP_PER_VEC: usize = @intCast(STATE_SIMD_WIDTH);
                const SubElemIdx = DEF.SLOTS_PER_BLOCK.unsigned_integer_type_that_holds_all_values_less_than();
                const BLOCK_IDX_BITS = @backingInt(GDEF.MAX_NUM_ELEMS) - @backingInt(DEF.SLOTS_PER_BLOCK);
                const BlockIdx = @Int(.unsigned, @max(1, BLOCK_IDX_BITS));
                const INVALID_ELEM_IDX = math.maxInt(ElemIdx);
                const DataBlock = struct {
                    vals: [SLOTS_PER_BLOCK]DEF.TYPE = undefined,
                    gens: [SLOTS_PER_BLOCK]GenId = @splat(0),
                    state: [DATA_BLOCK_STATE_GROUP_LENGTH]STATE_UINT align(STATE_VEC_ALIGN) = @splat(EMPTY_STATE_BLOCK),
                    val_locks: [SLOTS_PER_BLOCK]ElemLock = @splat(ElemLockDefault),
                    num_free: ElemIdx = @intCast(SLOTS_PER_BLOCK),
                    lock: BlockLock = BlockLockDefault,
                };
                const StateInfo = struct {
                    state_idx: usize,
                    state_bit_idx: usize,
                    state_bit_empty: STATE_UINT,
                };
                var blocks: [*]*DataBlock = invalid_ptr_many(*DataBlock);
                var blocks_cap: BlockIdx = 0;
                var pool_num_free: ElemIdx = 0;
                var pool_lock: PoolLock = PoolLockDefault;
                var gen_base: GenId = 0;

                pub fn claim_slot_advanced(comptime pool_lock_mode: PoolLockMode, comptime block_lock_mode: BlockLockMode) Key(TYPE) {
                    switch (comptime pool_lock_mode) {
                        .CHECK_POOL_LOCKS => POOL_LOCK_MODE.lock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &pool_lock else {}, io),
                        .IGNORE_POOL_LOCKS => {},
                    }
                    defer switch (comptime pool_lock_mode) {
                        .CHECK_POOL_LOCKS => POOL_LOCK_MODE.unlock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &pool_lock else {}, io),
                        .IGNORE_POOL_LOCKS => {},
                    };
                    Sub.ensure_free_slots_ignore_pool_locks(1);
                    for (blocks[0..blocks_cap], 0..) |block, block_idx| {
                        switch (comptime block_lock_mode) {
                            .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.lock_for_write_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io),
                            .IGNORE_BLOCK_LOCKS => {},
                        }
                        defer switch (comptime block_lock_mode) {
                            .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.unlock_for_write_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io),
                            .IGNORE_BLOCK_LOCKS => {},
                        };
                        if (block.num_free == 0) continue;
                        var state_idx: usize = 0;
                        if (comptime USE_SIMD) {
                            var state_vec_ptr: [*]StateVector = @ptrCast(@alignCast(&block.state));
                            while (state_idx + STATE_STEP_PER_VEC <= DATA_BLOCK_STATE_GROUP_LENGTH) : (state_idx += STATE_STEP_PER_VEC) {
                                const state_vec: StateVector = state_vec_ptr[0];
                                const any_in_vec_empty = state_vec > FULL_STATE_VEC_ALL_ZEROES;
                                const any_in_vec_empty_int: BoolVectorInt = @bitCast(any_in_vec_empty);
                                if (any_in_vec_empty_int != 0) {
                                    const first_group_with_empty: usize = @intCast(@ctz(any_in_vec_empty_int));
                                    var state_block_ptr: [*]STATE_UINT = @ptrCast(@alignCast(state_vec_ptr));
                                    state_block_ptr += first_group_with_empty;
                                    const first_emtpy_slot_in_block: usize = @intCast(@ctz(state_block_ptr[0]));
                                    const elem_idx_wide = ((state_idx + first_group_with_empty) * SLOT_STEP_PER_STATE_GROUP) + first_emtpy_slot_in_block;
                                    assert_with_reason(elem_idx_wide < SLOTS_PER_BLOCK, @src(), "claim found a free state bit beyond the configured slots per block", .{});
                                    const elem_idx: SubElemIdx = @intCast(elem_idx_wide);
                                    const key = Key(TYPE){
                                        .block_idx = @intCast(block_idx),
                                        .elem_idx = elem_idx,
                                        .gen = block.gens[elem_idx],
                                    };
                                    state_block_ptr[0] &= state_block_ptr[0] - 1;
                                    pool_num_free -= 1;
                                    block.num_free -= 1;
                                    return key;
                                }
                                state_vec_ptr += 1;
                            }
                        }
                        while (state_idx < DATA_BLOCK_STATE_GROUP_LENGTH) : (state_idx += 1) {
                            const state = block.state[state_idx];
                            if (state != 0) {
                                const first_emtpy_slot_in_block: usize = @intCast(@ctz(state));
                                const elem_idx_wide = (state_idx * SLOT_STEP_PER_STATE_GROUP) + first_emtpy_slot_in_block;
                                assert_with_reason(elem_idx_wide < SLOTS_PER_BLOCK, @src(), "claim found a free state bit beyond the configured slots per block", .{});
                                const elem_idx: SubElemIdx = @intCast(elem_idx_wide);
                                const key = Key(TYPE){
                                    .block_idx = @intCast(block_idx),
                                    .elem_idx = elem_idx,
                                    .gen = block.gens[elem_idx],
                                };
                                block.state[state_idx] &= block.state[state_idx] - 1;
                                pool_num_free -= 1;
                                block.num_free -= 1;
                                return key;
                            }
                        }
                    }
                    assert_unreachable(@src(), "no blocks had free slots: either the pool was corrupted or `ensure_free_slots(1)` failed to actually ensure free slots", .{});
                    return undefined;
                }
                pub inline fn claim() Key(TYPE) {
                    return Sub.claim_slot_advanced(.CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS);
                }

                pub fn ensure_free_slots_ignore_pool_locks(needed_free_slots: ElemIdx) void {
                    if (pool_num_free < needed_free_slots) {
                        const deficit = needed_free_slots - pool_num_free;
                        const needed_blocks_wide: u64 = @divCeil(@as(u64, deficit), @as(u64, SLOTS_PER_BLOCK));
                        assert_with_reason(needed_blocks_wide <= @as(u64, INVALID_IDX) - @as(u64, blocks_cap), @src(), "adding {d} data blocks would overflow the block capacity integer", .{needed_blocks_wide});
                        const max_blocks_by_capacity: u64 = @divFloor(@as(u64, INVALID_ELEM_IDX), @as(u64, SLOTS_PER_BLOCK));
                        assert_with_reason(@as(u64, blocks_cap) <= max_blocks_by_capacity and needed_blocks_wide <= max_blocks_by_capacity - @as(u64, blocks_cap), @src(), "adding {d} data blocks would make the pool capacity exceed `math.maxInt(ElemIdx)` ({d})", .{ needed_blocks_wide, INVALID_ELEM_IDX });
                        const needed_blocks: BlockIdx = @intCast(needed_blocks_wide);
                        const new_blocks_cap = blocks_cap + needed_blocks;
                        const old_blocks_cap = blocks_cap;
                        const new_block_list = alloc.realloc(blocks[0..blocks_cap], new_blocks_cap) catch |e| assert_allocation_failure(@src(), *DataBlock, needed_blocks, e);
                        blocks = new_block_list.ptr;
                        blocks_cap = new_blocks_cap;
                        for (blocks[old_blocks_cap..new_blocks_cap]) |*block| {
                            const new_block = alloc.create(DataBlock) catch |e| assert_allocation_failure(@src(), DataBlock, 1, e);
                            new_block.* = DataBlock{};
                            @memset(new_block.gens[0..SLOTS_PER_BLOCK], gen_base);
                            block.* = new_block;
                        }
                        pool_num_free += @intCast(@as(u64, needed_blocks) * @as(u64, SLOTS_PER_BLOCK));
                    }
                }

                pub inline fn get_num_free_ignore_pool_locks() ElemIdx {
                    return pool_num_free;
                }

                pub inline fn get_num_free() ElemIdx {
                    POOL_LOCK_MODE.lock_for_read_io(if (POOL_LOCK_MODE.has_lock()) &pool_lock else {}, io);
                    defer POOL_LOCK_MODE.unlock_for_read_io(if (POOL_LOCK_MODE.has_lock()) &pool_lock else {}, io);
                    return pool_num_free;
                }

                pub inline fn ensure_free_slots(needed_free_slots: ElemIdx) void {
                    POOL_LOCK_MODE.lock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &pool_lock else {}, io);
                    defer POOL_LOCK_MODE.unlock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &pool_lock else {}, io);
                    Sub.ensure_free_slots_ignore_pool_locks(needed_free_slots);
                }

                pub fn init(init_capacity: ElemIdx) void {
                    assert_with_reason(Sub.blocks_cap == 0, @src(), "cannot init if blocks_cap > 0", .{});
                    blocks = invalid_ptr_many(*DataBlock);
                    blocks_cap = 0;
                    pool_lock = PoolLockDefault;
                    pool_num_free = 0;
                    gen_base +%= 1;
                    Sub.ensure_free_slots_ignore_pool_locks(init_capacity);
                }

                pub fn clear_all_blocks() void {
                    POOL_LOCK_MODE.lock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &Sub.pool_lock else {}, io);
                    defer POOL_LOCK_MODE.unlock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &Sub.pool_lock else {}, io);
                    for (blocks[0..blocks_cap]) |block| {
                        BLOCK_LOCK_MODE.lock_for_write_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                        defer BLOCK_LOCK_MODE.unlock_for_write_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                        if (comptime ELEM_LOCK_MODE.has_lock()) {
                            for (block.val_locks[0..SLOTS_PER_BLOCK]) |*elem_lock| {
                                ELEM_LOCK_MODE.lock_for_write_io(elem_lock, io);
                            }
                        }
                        block.num_free = @intCast(SLOTS_PER_BLOCK);
                        block.state = @splat(EMPTY_STATE_BLOCK);
                        for (block.gens[0..SLOTS_PER_BLOCK]) |*gen| {
                            gen.* +%= 1;
                        }
                        if (comptime ELEM_LOCK_MODE.has_lock()) {
                            for (block.val_locks[0..SLOTS_PER_BLOCK]) |*elem_lock| {
                                ELEM_LOCK_MODE.unlock_for_write_io(elem_lock, io);
                            }
                        }
                    }
                    pool_num_free = @intCast(@as(u64, blocks_cap) * @as(u64, SLOTS_PER_BLOCK));
                }

                pub fn uninit() void {
                    POOL_LOCK_MODE.lock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &Sub.pool_lock else {}, io);
                    defer POOL_LOCK_MODE.unlock_for_write_io(if (POOL_LOCK_MODE.has_lock()) &Sub.pool_lock else {}, io);
                    if (blocks_cap > 0) {
                        for (blocks[0..blocks_cap]) |block| {
                            BLOCK_LOCK_MODE.lock_for_write_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                            BLOCK_LOCK_MODE.unlock_for_write_io(if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, io);
                            alloc.destroy(block);
                        }
                        alloc.free(blocks[0..blocks_cap]);
                    }
                    blocks = invalid_ptr_many(*DataBlock);
                    blocks_cap = 0;
                    pool_num_free = 0;
                }
            };
        }
        var alloc: Allocator = Root.Allocator.Dummy.allocator_panic_free_noop;
        var io: Io = Root.DummyIo.io_undefined;
        const NONE_IO = GDEF.POOL_LOCK_MODE.io_type() == void and GDEF.BLOCK_LOCK_MODE.io_type() == void and GDEF.ELEM_LOCK_MODE.io_type() == void;
        const InitIo = if (NONE_IO) void else Io;

        pub fn init_global(allocator: Allocator, init_io: InitIo) void {
            alloc = allocator;
            if (comptime !NONE_IO) {
                io = init_io;
            }
        }
        pub fn claim_slot_advanced(comptime T: type, comptime pool_lock_mode: PoolLockMode, comptime block_lock_mode: BlockLockMode) Key(T) {
            const KEY = Key(T);
            return KEY.POOL.claim_slot_advanced(pool_lock_mode, block_lock_mode);
        }
        pub inline fn claim(comptime T: type) Key(T) {
            const KEY = Key(T);
            return KEY.POOL.claim();
        }
        pub inline fn ensure_free_slots_ignore_pool_locks(comptime T: type, needed_free_slots: ElemIdx) void {
            const KEY = Key(T);
            KEY.POOL.ensure_free_slots_ignore_pool_locks(needed_free_slots);
        }
        pub inline fn ensure_free_slots(comptime T: type, needed_free_slots: ElemIdx) void {
            const KEY = Key(T);
            KEY.POOL.ensure_free_slots(needed_free_slots);
        }
        pub inline fn get_num_free_ignore_pool_locks(comptime T: type) ElemIdx {
            const KEY = Key(T);
            return KEY.POOL.get_num_free_ignore_pool_locks();
        }
        pub inline fn get_num_free(comptime T: type) ElemIdx {
            const KEY = Key(T);
            return KEY.POOL.get_num_free();
        }

        pub inline fn init(comptime T: type, init_capacity: ElemIdx) void {
            const KEY = Key(T);
            KEY.POOL.init(init_capacity);
        }

        pub inline fn clear_all_blocks(comptime T: type) void {
            const KEY = Key(T);
            KEY.POOL.clear_all_blocks();
        }

        pub inline fn uninit(comptime T: type) void {
            const KEY = Key(T);
            KEY.POOL.uninit();
        }
    };
}

//TODO //CHECKPOINT iterators and field/ptr access
