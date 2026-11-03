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

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
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
    /// Unsigned integer type used for each group of slot state bits.
    STATE_UINT: type = usize,
    /// Must be a positive multiple of `@bitSizeOf(STATE_UINT)` so that every state
    /// bit maps to a real slot.
    SLOTS_PER_BLOCK: comptime_int = 64,
    ALLOC_MODE: CachedAllocMode = .MANUAL_ALLOC,
    BACK_POINT_STRATEGY: BackPointStrategy = .SORTED_BLOCKS_BINARY_SEARCH,
};

pub const PoolLockMode = enum {
    CHECK_POOL_LOCKS,
    IGNORE_POOL_LOCKS,
};

pub const BlockLockMode = enum {
    CHECK_BLOCK_LOCKS,
    IGNORE_BLOCK_LOCKS,
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

pub const BackPointStrategy = enum {
    /// Each block aligns its 'values' array to the TOTAL SIZE of the 'values'
    /// array, and the *DataBlock pointer can be calculated from any *ELEM
    /// pointer with a single bitwise AND (and possible, but unlikely, integer subtraction).
    ///
    /// PROS:
    ///   - O(1) pointer reversal to get *DataBlock from any *ELEM
    ///
    /// CONS:
    ///   - The alignment of each DataBlock can end up being very very large,
    /// which may cause some allocators to fail to find memory that meets the alignments and sizes,
    /// or may vastly over-allocate and waste space.
    SUPER_ALIGN_AND_MASK,
    /// Every element slot also has a paired index field that stores the slot's index WITHIN its DataBlock,
    /// that can be reversed with some integer math to get the *DataBlock pointer from any *ELEM pointer.
    ///
    /// PROS:
    ///   - O(1) pointer reversal to get *DataBlock from any *ELEM
    ///
    /// CONS:
    ///   - Every slot also stores the smallest unsigned integer type that can hold its
    /// within-block index, which may add padding and therefore extra bytes per slot.
    AUXILLIARY_INDEX_FIELD,
    /// DataBlocks are sorted by their starting address, and when releasing a slot, a binary search is performed
    /// to locate the DataBlock it belongs to.
    ///
    /// PROS:
    ///   - Most memory-efficient and allocator-friendly solution
    ///
    /// CONS:
    ///   - O(log NUM_DATA_BLOCKS) lookup when releasing slots
    ///   - Insertion sort every time new block(s) are allocated (minimal impact, blocks are already partially sorted
    /// and large block sizes make the cost amortized)
    SORTED_BLOCKS_BINARY_SEARCH,
};

pub const IterSlotMode = enum {
    VAL,
    PTR,
    CONST_PTR,
};

/// Smallest power of two that is >= `n` and at least 2. The lower bound of 2
/// is required so that masking an address actually clears at least one bit.
fn ceil_pow2_at_least_2(comptime n: usize) usize {
    if (n <= 2) return 2;
    return @as(usize, 1) << @intCast(std.math.log2_int_ceil(usize, n));
}

pub fn BitTrackedPool(comptime DEF: PoolDef) type {
    assert_with_reason(Types.type_is_unsigned_int(DEF.IDX), @src(), "type `IDX` must be an unsigned integer type, got type `{s}`", .{@typeName(DEF.IDX)});
    assert_with_reason(@sizeOf(DEF.ELEM) > 0, @src(), "type `ELEM` must have a non-zero size so that every slot has a distinct address", .{});
    assert_with_reason(DEF.SLOTS_PER_BLOCK > 0, @src(), "`SLOTS_PER_BLOCK` must be greater than zero", .{});
    assert_with_reason(DEF.SLOTS_PER_BLOCK <= math.maxInt(DEF.IDX), @src(), "`SLOTS_PER_BLOCK` ({d}) must be <= `math.maxInt(IDX)` ({d})", .{ DEF.SLOTS_PER_BLOCK, math.maxInt(DEF.IDX) });
    assert_with_reason(DEF.SLOTS_PER_BLOCK >= @bitSizeOf(DEF.STATE_UINT), @src(), "`SLOTS_PER_BLOCK` ({d}) must be at least {d} (the number of bits in `STATE_UINT`) so the state array has at least one full group", .{ DEF.SLOTS_PER_BLOCK, @bitSizeOf(DEF.STATE_UINT) });
    assert_with_reason(DEF.SLOTS_PER_BLOCK % @bitSizeOf(DEF.STATE_UINT) == 0, @src(), "`SLOTS_PER_BLOCK` ({d}) must be a multiple of {d} (the number of bits in `STATE_UINT`) so every state bit maps to a real slot", .{ DEF.SLOTS_PER_BLOCK, @bitSizeOf(DEF.STATE_UINT) });
    const ELEM_SIZE_ = @sizeOf(DEF.ELEM);
    assert_with_reason(@as(u128, DEF.SLOTS_PER_BLOCK) * ELEM_SIZE_ <= math.maxInt(usize), @src(), "`SLOTS_PER_BLOCK` * `@sizeOf(ELEM)` overflows `usize`", .{});
    const VALS_BYTE_SIZE_ = @as(usize, DEF.SLOTS_PER_BLOCK) * ELEM_SIZE_;
    const AUX_IDX_INT_ = calc: {
        const bits_needed: u16 = @intCast(std.math.log2_int_ceil(usize, @as(usize, DEF.SLOTS_PER_BLOCK)));
        break :calc @Int(.unsigned, bits_needed);
    };
    const Slot_ = struct {
        elem: DEF.ELEM = undefined,
        idx: if (DEF.BACK_POINT_STRATEGY == .AUXILLIARY_INDEX_FIELD) AUX_IDX_INT_ else void = if (DEF.BACK_POINT_STRATEGY == .AUXILLIARY_INDEX_FIELD) 0 else {},
    };
    const VALS_ALIGN_ = if (DEF.BACK_POINT_STRATEGY == .SUPER_ALIGN_AND_MASK) ceil_pow2_at_least_2(VALS_BYTE_SIZE_) else @alignOf(Slot_);
    const DATA_BLOCK_STATE_GROUP_LENGTH_ = @divExact(@as(usize, DEF.SLOTS_PER_BLOCK), @bitSizeOf(DEF.STATE_UINT));
    return struct {
        const Self = @This();
        pub const POOL_DEF = DEF;
        pub const ELEM = DEF.ELEM;
        pub const IDX = DEF.IDX;
        const SlotContainer = Slot_;
        const STATE_INT = DEF.STATE_UINT;
        const LOCK_MODE = DEF.LOCK_MODE;
        const MASTER_LOCK = LOCK_MODE == .MASTER_LOCK or LOCK_MODE == .MASTER_AND_BLOCK_LOCK;
        pub const DATA_BLOCK_SLOT_LENGTH: IDX = DEF.SLOTS_PER_BLOCK;
        const DATA_BLOCK_STATE_GROUP_LENGTH: IDX = @intCast(DATA_BLOCK_STATE_GROUP_LENGTH_);
        const INVALID_IDX = math.maxInt(IDX);
        const USED_STATE: STATE_INT = 0b0;
        const STATE_SIMD_WIDTH = @min(64, std.simd.suggestVectorLength(STATE_INT) orelse 1);
        const USE_SIMD = STATE_SIMD_WIDTH > 1 and DATA_BLOCK_STATE_GROUP_LENGTH >= STATE_SIMD_WIDTH;
        const StateVector = @Vector(STATE_SIMD_WIDTH, STATE_INT);
        const BoolVector = @Vector(STATE_SIMD_WIDTH, bool);
        const BoolVectorInt = @Int(.unsigned, STATE_SIMD_WIDTH);
        const STATE_VEC_ALIGN = if (USE_SIMD) @alignOf(StateVector) else @alignOf(STATE_INT);
        const STATE_INT_BITS: u16 = @bitSizeOf(STATE_INT);
        const STATE_INT_BITS_SHIFT: math.Log2Int(IDX) = @intCast(@ctz(STATE_INT_BITS));
        const STATE_INT_BITS_MINUS_ONE: IDX = @intCast(STATE_INT_BITS - 1);
        const ALLOC_MODE = DEF.ALLOC_MODE;
        const CachedAlloc = ALLOC_MODE.CachedAlloc();
        const FuncAlloc = ALLOC_MODE.FuncParamAlloc();
        const CACHED_ALLOC_DEFAULT = ALLOC_MODE.CACHED_ALLOC_DEFAULT();
        const FULL_STATE_VEC_ALL_ZEROES: StateVector = @splat(0);
        const EMPTY_STATE_BLOCK: STATE_INT = math.maxInt(STATE_INT);
        const SLOT_STEP_PER_STATE_GROUP: IDX = @intCast(STATE_INT_BITS);
        const STATE_STEP_PER_VEC: IDX = @intCast(STATE_SIMD_WIDTH);
        const BLOCK_LOCK = DEF.LOCK_MODE == .MASTER_AND_BLOCK_LOCK;
        const VALS_ALIGN = VALS_ALIGN_;
        const VALS_ARRAY_PTR_MASK = ~(VALS_ALIGN - 1);
        const BACK_STRAT = DEF.BACK_POINT_STRATEGY;
        const DataBlockSlice = ListSliceMoule.ListFullDefinition(*DataBlock, IDX, .WHOLE_STRUCTS, .SERIAL_INDEXES, .REFERENCED_MUTABLE, .MANUAL_ALLOC);

        const DataBlock = struct {
            vals: [DATA_BLOCK_SLOT_LENGTH]SlotContainer align(VALS_ALIGN) = undefined,
            state: [DATA_BLOCK_STATE_GROUP_LENGTH]STATE_INT align(STATE_VEC_ALIGN) = @splat(EMPTY_STATE_BLOCK),
            num_free: IDX = @intCast(DATA_BLOCK_SLOT_LENGTH),
            self_idx: IDX = INVALID_IDX,
            lock: if (BLOCK_LOCK) RwLock else void = if (BLOCK_LOCK) RwLock.init else {},
            pool: ?*Self = null,
            io: if (BLOCK_LOCK) Io else void = if (BLOCK_LOCK) undefined else {},

            pub fn lock_for_read(self: *DataBlock) void {
                if (comptime BLOCK_LOCK) {
                    self.lock.lockSharedUncancelable(self.io);
                }
            }
            pub fn unlock_for_read(self: *DataBlock) void {
                if (comptime BLOCK_LOCK) {
                    self.lock.unlockShared(self.io);
                }
            }
            pub fn lock_for_write(self: *DataBlock) void {
                if (comptime BLOCK_LOCK) {
                    self.lock.lockUncancelable(self.io);
                }
            }
            pub fn unlock_for_write(self: *DataBlock) void {
                if (comptime BLOCK_LOCK) {
                    self.lock.unlock(self.io);
                }
            }
        };
        pub const DATA_BLOCK_BYTE_SIZE = @sizeOf(DataBlock);
        pub const DATA_BLOCK_ALIGNMENT = @alignOf(DataBlock);
        comptime {
            if (DEF.BACK_POINT_STRATEGY == .SUPER_ALIGN_AND_MASK) {
                assert_with_reason(VALS_ALIGN >= 2, null, "`vals` alignment must be at least 2 so pointer masking clears at least one bit", .{});
                assert_with_reason(VALS_BYTE_SIZE_ <= VALS_ALIGN, null, "`vals` array ({d} bytes) must fit inside one {d}-byte aligned extent", .{ VALS_BYTE_SIZE_, VALS_ALIGN });
            }
            assert_with_reason(@offsetOf(DataBlock, "vals") % VALS_ALIGN == 0, null, "`vals` offset ({d}) must be a multiple of its alignment ({d})", .{ @offsetOf(DataBlock, "vals"), VALS_ALIGN });
            assert_with_reason(@alignOf(DataBlock) >= VALS_ALIGN, null, "`DataBlock` alignment ({d}) must be at least `VALS_ALIGN` ({d})", .{ @alignOf(DataBlock), VALS_ALIGN });
        }

        blocks: [*]*DataBlock = invalid_ptr_many(*DataBlock),
        blocks_cap: IDX = 0,
        num_free: IDX = 0,
        cached_alloc: CachedAlloc = CACHED_ALLOC_DEFAULT,
        lock: if (MASTER_LOCK) RwLock else void = if (MASTER_LOCK) RwLock.init else {},
        io: if (MASTER_LOCK) Io else void = if (MASTER_LOCK) undefined else {},

        pub inline fn lock_for_write(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.lock.lockUncancelable(self.io);
            }
        }
        pub inline fn unlock_for_write(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.lock.unlock(self.io);
            }
        }
        pub inline fn lock_for_read(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.lock.lockSharedUncancelable(self.io);
            }
        }
        pub inline fn unlock_for_read(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.lock.unlockShared(self.io);
            }
        }
        pub fn ensure_free_slots_ignore_pool_locks(self: *Self, needed_free_slots: IDX, fn_alloc: FuncAlloc) void {
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
                for (self.blocks[old_blocks_cap..new_blocks_cap], old_blocks_cap..) |*block, block_idx| {
                    const new_block = alloc.create(DataBlock) catch |e| assert_allocation_failure(@src(), DataBlock, 1, e);
                    new_block.* = DataBlock{};
                    if (comptime BACK_STRAT != .SORTED_BLOCKS_BINARY_SEARCH) {
                        new_block.self_idx = @intCast(block_idx);
                    }
                    new_block.pool = self;
                    if (comptime BLOCK_LOCK) {
                        new_block.io = self.io;
                    }
                    block.* = new_block;
                }
                if (comptime BACK_STRAT == .SORTED_BLOCKS_BINARY_SEARCH) {
                    const blocks = DataBlockSlice.from_slice_keep_data(self.blocks[0..self.blocks_cap]);
                    blocks.insertion_sort_advanced({}, {}, .COMPTIME_FN_BODY, {}, data_block_addr_greater);
                    for (self.blocks[0..self.blocks_cap], 0..) |block, idx| {
                        block.lock_for_write();
                        defer block.unlock_for_write();
                        block.self_idx = @intCast(idx);
                    }
                }
                self.num_free += needed_blocks * DATA_BLOCK_SLOT_LENGTH;
            }
        }

        pub inline fn ensure_free_slots(self: *Self, needed_free_slots: IDX, fn_alloc: FuncAlloc) void {
            self.lock_for_write();
            self.ensure_free_slots_ignore_pool_locks(needed_free_slots, fn_alloc);
            self.unlock_for_write();
        }
        pub fn get_num_free_ignore_locks(self: *Self) IDX {
            return self.num_free;
        }
        pub fn get_num_free(self: *Self) IDX {
            self.lock_for_read();
            const num = self.num_free;
            self.unlock_for_read();
            return num;
        }

        fn data_block_addr_greater(slice: DataBlockSlice, block_idx: IDX, block_to_compare: *DataBlock, _: void, comptime _: void) bool {
            return @intFromPtr(slice.get(block_idx)) > @intFromPtr(block_to_compare);
        }

        /// Initializes `self` in place. Call this on a fresh value or after
        /// `uninit`. The pool must not be moved or copied after this call,
        /// because its data blocks retain a pointer to it.
        pub fn init(self: *Self, init_capacity: IDX, allocator: Allocator, init_io: if (MASTER_LOCK) Io else void) void {
            self.* = .{
                .cached_alloc = ALLOC_MODE.alloc_to_cached_alloc(allocator),
                .io = init_io,
            };
            self.ensure_free_slots_ignore_pool_locks(init_capacity, ALLOC_MODE.alloc_to_func_alloc(allocator));
        }

        pub fn uninit(self: *Self, fn_alloc: FuncAlloc) void {
            self.lock_for_write();
            if (self.blocks_cap > 0) {
                const alloc = ALLOC_MODE.get_alloc(fn_alloc, self.cached_alloc);
                for (self.blocks[0..self.blocks_cap]) |block| {
                    alloc.destroy(block);
                }
                alloc.free(self.blocks[0..self.blocks_cap]);
            }
            self.unlock_for_write();
            self.* = .{};
        }

        pub fn claim_slot_advanced(self: *Self, fn_alloc: FuncAlloc, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode) *ELEM {
            switch (comptime pool_lock) {
                .CHECK_POOL_LOCKS => self.lock_for_write(),
                .IGNORE_POOL_LOCKS => {},
            }
            defer switch (comptime pool_lock) {
                .CHECK_POOL_LOCKS => self.unlock_for_write(),
                .IGNORE_POOL_LOCKS => {},
            };
            self.ensure_free_slots_ignore_pool_locks(1, fn_alloc);
            for (self.blocks[0..self.blocks_cap]) |block| {
                switch (comptime block_lock) {
                    .CHECK_BLOCK_LOCKS => block.lock_for_write(),
                    .IGNORE_BLOCK_LOCKS => {},
                }
                defer switch (comptime block_lock) {
                    .CHECK_BLOCK_LOCKS => block.unlock_for_write(),
                    .IGNORE_BLOCK_LOCKS => {},
                };
                if (block.num_free == 0) continue;
                var state_idx: IDX = 0;
                if (comptime USE_SIMD) {
                    var state_vec_ptr: [*]StateVector = @ptrCast(@alignCast(&block.state));
                    while (state_idx + STATE_STEP_PER_VEC <= DATA_BLOCK_STATE_GROUP_LENGTH) : (state_idx += STATE_STEP_PER_VEC) {
                        const state_vec: StateVector = state_vec_ptr[0];
                        const any_in_vec_empty = state_vec > FULL_STATE_VEC_ALL_ZEROES;
                        const any_in_vec_empty_int: BoolVectorInt = @bitCast(any_in_vec_empty);
                        if (any_in_vec_empty_int != 0) {
                            const first_group_with_empty: IDX = @intCast(@ctz(any_in_vec_empty_int));
                            var state_block_ptr: [*]STATE_INT = @ptrCast(@alignCast(state_vec_ptr));
                            state_block_ptr += first_group_with_empty;
                            const first_emtpy_slot_in_block: IDX = @intCast(@ctz(state_block_ptr[0]));
                            const true_idx = ((state_idx + first_group_with_empty) * SLOT_STEP_PER_STATE_GROUP) + first_emtpy_slot_in_block;
                            assert_with_reason(true_idx < DATA_BLOCK_SLOT_LENGTH, @src(), "claim found a free state bit beyond the configured slots per block", .{});
                            if (comptime BACK_STRAT == .AUXILLIARY_INDEX_FIELD) {
                                block.vals[true_idx].idx = @intCast(true_idx);
                            }
                            const slot_ptr: *ELEM = &block.vals[true_idx].elem;
                            state_block_ptr[0] &= state_block_ptr[0] - 1;
                            self.num_free -= 1;
                            block.num_free -= 1;
                            return slot_ptr;
                        }
                        state_vec_ptr += 1;
                    }
                }
                while (state_idx < DATA_BLOCK_STATE_GROUP_LENGTH) : (state_idx += 1) {
                    const state = block.state[state_idx];
                    if (state != 0) {
                        const first_emtpy_slot_in_block: IDX = @intCast(@ctz(state));
                        const true_idx = (state_idx * SLOT_STEP_PER_STATE_GROUP) + first_emtpy_slot_in_block;
                        assert_with_reason(true_idx < DATA_BLOCK_SLOT_LENGTH, @src(), "claim found a free state bit beyond the configured slots per block", .{});
                        if (comptime BACK_STRAT == .AUXILLIARY_INDEX_FIELD) {
                            block.vals[true_idx].idx = @intCast(true_idx);
                        }
                        const slot_ptr: *ELEM = &block.vals[true_idx].elem;
                        block.state[state_idx] &= block.state[state_idx] - 1;
                        self.num_free -= 1;
                        block.num_free -= 1;
                        return slot_ptr;
                    }
                }
            }
            assert_unreachable(@src(), "no blocks had free slots: either the pool was corrupted or `ensure_free_slots(1)` failed to actually ensure free slots", .{});
            return undefined;
        }

        pub inline fn claim_slot(self: *Self, fn_alloc: FuncAlloc) *ELEM {
            return self.claim_slot_advanced(fn_alloc, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS);
        }

        fn slot_data_block_and_idx(self: *Self, slot: *const ELEM) struct { *DataBlock, IDX } {
            switch (comptime BACK_STRAT) {
                .SUPER_ALIGN_AND_MASK => {
                    const ptr_addr = @intFromPtr(slot);
                    const vals_addr = @intFromPtr(slot) & VALS_ARRAY_PTR_MASK;
                    const byte_offset = ptr_addr - vals_addr;
                    const slot_idx: IDX = @intCast(byte_offset / @sizeOf(SlotContainer));
                    return .{ @ptrFromInt(vals_addr - @offsetOf(DataBlock, "vals")), slot_idx };
                },
                .AUXILLIARY_INDEX_FIELD => {
                    const slot_holder_ptr: *const SlotContainer = @fieldParentPtr("elem", slot);
                    const slot_idx: IDX = @intCast(slot_holder_ptr.idx);
                    const offset_elem_to_vals = @as(usize, slot_idx) * @sizeOf(SlotContainer);
                    const offset_vals_to_block = @offsetOf(DataBlock, "vals");
                    const data_block_addr: usize = @intFromPtr(slot) - offset_elem_to_vals - offset_vals_to_block;
                    const block: *DataBlock = @ptrFromInt(data_block_addr);
                    return .{ block, slot_idx };
                },
                .SORTED_BLOCKS_BINARY_SEARCH => {
                    const slot_addr = @intFromPtr(slot);
                    var lo: IDX = 0;
                    var hi: IDX = self.blocks_cap;
                    while (lo < hi) {
                        const mid = lo + ((hi - lo) / 2);
                        const block = self.blocks[mid];
                        const block_addr = @intFromPtr(block);
                        if (slot_addr < block_addr) {
                            hi = mid;
                        } else if (slot_addr - block_addr < @sizeOf(DataBlock)) {
                            const vals_addr = @intFromPtr(&block.vals[0].elem);
                            const slot_idx: IDX = @intCast((slot_addr - vals_addr) / @sizeOf(SlotContainer));
                            return .{ block, slot_idx };
                        } else {
                            lo = mid + 1;
                        }
                    }
                    assert_unreachable(@src(), "slot does not belong to any data block", .{});
                    return .{ undefined, undefined };
                },
            }
        }

        pub inline fn assert_slot_valid(self: *Self, slot: *const ELEM, comptime src: ?std.builtin.SourceLocation) void {
            if (comptime Assert.SHOULD_ASSERT) {
                _ = self.unwrap_slot_info(slot, src, .READ_POOL_TRANSIENT, .READ_BLOCK_TRANSIENT);
            }
        }
        pub inline fn slot_pool(self: *Self, slot: *const ELEM) *Self {
            return self.unwrap_slot_info(slot, @src(), .READ_POOL_TRANSIENT, .READ_BLOCK_TRANSIENT).pool;
        }
        const SlotInfo = struct {
            block: *DataBlock,
            pool: *Self,
            slot_idx: IDX,
            state_idx: IDX,
            state_bit_idx: IDX,
            state_bit_empty: STATE_INT,
        };
        fn unwrap_slot_info(self: *Self, slot: *const ELEM, comptime src: ?std.builtin.SourceLocation, comptime pool_lock: PoolLockModeAdv, comptime block_lock: BlockLockModeAdv) SlotInfo {
            switch (comptime pool_lock) {
                .IGNORE_POOL_LOCK => {},
                .READ_POOL_KEEP_LOCKED, .READ_POOL_TRANSIENT => self.lock_for_read(),
                .WRITE_POOL_KEEP_LOCKED, .WRITE_POOL_TRANSIENT => self.lock_for_write(),
            }
            defer switch (comptime pool_lock) {
                .IGNORE_POOL_LOCK, .READ_POOL_KEEP_LOCKED, .WRITE_POOL_KEEP_LOCKED => {},
                .READ_POOL_TRANSIENT => self.unlock_for_read(),
                .WRITE_POOL_TRANSIENT => self.unlock_for_write(),
            };
            const block, const slot_idx = self.slot_data_block_and_idx(slot);
            assert_with_reason(block.pool != null, src, "block.pool for slot was null, block is invalid -> slot is invalid", .{});
            const pool = block.pool.?;
            assert_with_reason(@intFromPtr(pool) == @intFromPtr(self), src, "block's `pool: *Pool` back-pointer does not match the known pool pointer", .{});
            switch (comptime block_lock) {
                .IGNORE_BLOCK_LOCK => {},
                .READ_BLOCK_KEEP_LOCKED, .READ_BLOCK_TRANSIENT => block.lock_for_read(),
                .WRITE_BLOCK_KEEP_LOCKED, .WRITE_BLOCK_TRANSIENT => block.lock_for_write(),
            }
            defer switch (comptime block_lock) {
                .IGNORE_BLOCK_LOCK, .READ_BLOCK_KEEP_LOCKED, .WRITE_BLOCK_KEEP_LOCKED => {},
                .READ_BLOCK_TRANSIENT => block.unlock_for_read(),
                .WRITE_BLOCK_TRANSIENT => block.unlock_for_write(),
            };
            assert_with_reason(block.self_idx < pool.blocks_cap, src, "block.self_idx ({d}) is >= block.pool.?.blocks_cap ({d}), block is invalid -> slot is invalid", .{ block.self_idx, pool.blocks_cap });
            assert_with_reason(pool.blocks[block.self_idx] == block, src, "this block ptr did not match the block ptr held at `block.pool.?.blocks[block.self_idx]`, block is invalid -> slot is invalid", .{});
            const state_block_idx = slot_idx >> STATE_INT_BITS_SHIFT;
            const state_bit_offset = slot_idx & STATE_INT_BITS_MINUS_ONE;
            const state_bit_emtpy = @as(STATE_INT, 1) << @intCast(state_bit_offset);
            const state = block.state[state_block_idx];
            assert_with_reason(state & state_bit_emtpy == USED_STATE, src, "slot was not flagged as used, slot invalid", .{});
            return SlotInfo{
                .block = block,
                .pool = pool,
                .slot_idx = slot_idx,
                .state_idx = state_block_idx,
                .state_bit_idx = state_bit_offset,
                .state_bit_empty = state_bit_emtpy,
            };
        }

        pub fn release_slot_advanced(self: *Self, slot: *const ELEM, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode) void {
            const pool_lock_adv = switch (comptime pool_lock) {
                .CHECK_POOL_LOCKS => PoolLockModeAdv.WRITE_POOL_KEEP_LOCKED,
                .IGNORE_POOL_LOCKS => PoolLockModeAdv.IGNORE_POOL_LOCK,
            };
            const block_lock_adv = switch (comptime block_lock) {
                .CHECK_BLOCK_LOCKS => BlockLockModeAdv.WRITE_BLOCK_KEEP_LOCKED,
                .IGNORE_BLOCK_LOCKS => BlockLockModeAdv.IGNORE_BLOCK_LOCK,
            };
            const slot_info = self.unwrap_slot_info(slot, @src(), pool_lock_adv, block_lock_adv);
            defer switch (comptime pool_lock) {
                .CHECK_POOL_LOCKS => self.unlock_for_write(),
                .IGNORE_POOL_LOCKS => {},
            };
            defer switch (comptime block_lock) {
                .CHECK_BLOCK_LOCKS => slot_info.block.unlock_for_write(),
                .IGNORE_BLOCK_LOCKS => {},
            };
            slot_info.block.state[slot_info.state_idx] |= slot_info.state_bit_empty;
            slot_info.block.num_free += 1;
            self.num_free += 1;
        }
        pub fn release_slot(self: *Self, slot: *const ELEM) void {
            self.release_slot_advanced(slot, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS);
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
                curr_state_inverted: STATE_INT = 0,
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
                        .CHECK_POOL_LOCKS => pool.lock_for_read(),
                        .IGNORE_POOL_LOCKS => {},
                    }
                    if (pool.blocks_cap > 0) {
                        self.block = pool.blocks[0];
                        switch (comptime block_lock) {
                            .CHECK_BLOCK_LOCKS => switch (comptime slot_mode) {
                                .VAL, .CONST_PTR => self.block.lock_for_read(),
                                .PTR => self.block.lock_for_write(),
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
                                    .VAL => self.block.vals[first_used_slot_within_block].elem,
                                    .PTR, .CONST_PTR => &self.block.vals[first_used_slot_within_block].elem,
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
                                    .VAL, .CONST_PTR => self.block.unlock_for_read(),
                                    .PTR => self.block.unlock_for_write(),
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
                                    .VAL, .CONST_PTR => self.block.lock_for_read(),
                                    .PTR => self.block.lock_for_write(),
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
                                .VAL, .CONST_PTR => self.block.unlock_for_read(),
                                .PTR => self.block.unlock_for_write(),
                            },
                            .IGNORE_BLOCK_LOCKS => {},
                        }
                    }
                    switch (comptime pool_lock) {
                        .CHECK_POOL_LOCKS => self.pool.unlock_for_read(),
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
