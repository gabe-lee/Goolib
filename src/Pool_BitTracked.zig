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
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

pub const MutexMode = enum {
    NO_LOCKS,
    MASTER_LOCK,
};

pub const PoolDef = struct {
    ELEM: type,
    IDX: type = u32,
    LOCK_MODE: MutexMode = .NO_LOCKS,
    DATA_BLOCK_SIZE: PowerOf2 = ._256,
    ALLOC_MODE: CachedAllocMode = .MANUAL_ALLOC,
};

const FieldAccessMode = enum {
    NOT_SUPPORTED,
    UNION_TAGGED,
    UNION_UNTAGGED,
    STRUCT,
};

fn FieldIntType(comptime num_fields: usize) type {
    if (num_fields <= math.maxInt(u8)) return u8;
    if (num_fields <= math.maxInt(u16)) return u16;
    if (num_fields <= math.maxInt(u32)) return u32;
    return u64;
}

const BLOCK_LIST_MIN_GROWTH = 32;

pub fn BitTrackedPool(comptime DEF: PoolDef) type {
    assert_with_reason(Types.type_is_unsigned_int(DEF.IDX), @src(), "type `IDX` must be an unsigned integer type, got type `{s}`", .{@typeName(DEF.IDX)});
    assert_with_reason(DEF.LOCK_MODE == .NO_LOCKS or DEF.LOCK_BLOCK_COVERAGE > 0, @src(), "MUTEX_BLOCK_COVERAGE must be larger than 0", .{});
    const FA_MODE_, const FIELDS_ENUM_, const FIELDS_TYPES_ = make: {
        const INFO = @typeInfo(DEF.ELEM);
        switch (INFO) {
            .@"struct" => |STRUCT_INFO| {
                const num_fields = STRUCT_INFO.field_types.len;
                assert_with_reason(num_fields > 0, @src(), "cannot store a struct with zero fields", .{});
                const E_INT = FieldIntType(num_fields);
                comptime var e_vals: [num_fields]E_INT = undefined;
                comptime var types: [num_fields]type = undefined;
                for (0..num_fields) |f| {
                    e_vals[f] = @intCast(f);
                    types[f] = STRUCT_INFO.field_types[f];
                }
                break :make .{ FieldAccessMode.STRUCT, @Enum(E_INT, .exhaustive, STRUCT_INFO.field_names, &e_vals), types };
            },
            .@"union" => |UNION_INFO| {
                const num_fields = UNION_INFO.field_types.len;
                assert_with_reason(num_fields > 0, @src(), "cannot store a union with zero fields", .{});
                const E_INT = FieldIntType(num_fields);
                comptime var e_vals: [num_fields]E_INT = undefined;
                comptime var types: [num_fields]type = undefined;
                for (0..num_fields) |f| {
                    e_vals[f] = @intCast(f);
                    types[f] = UNION_INFO.field_types[f];
                }
                break :make .{ if (UNION_INFO.tag_type != null) FieldAccessMode.UNION_TAGGED else FieldAccessMode.UNION_UNTAGGED, @Enum(E_INT, .exhaustive, UNION_INFO.field_names, &e_vals), types };
            },
            else => {
                break :make .{ FieldAccessMode.NOT_SUPPORTED, enum { @"!NOT_SUPPORTED" }, [1]type{DEF.ELEM} };
            },
        }
    };
    assert_with_reason(DEF.DATA_BLOCK_SIZE.value() <= math.maxInt(DEF.IDX), @src(), "`DATA_BLOCK_SIZE` ({d}) must be <= `math.maxInt(IDX)` ({d})", .{ DEF.DATA_BLOCK_SIZE.value(), math.maxInt(DEF.IDX) });
    return struct {
        const Self = @This();
        pub const POOL_DEF = DEF;
        pub const ELEM = DEF.ELEM;
        pub const IDX = DEF.IDX;
        const LOCK_MODE = DEF.LOCK_MODE;
        const MASTER_LOCK = LOCK_MODE == .MASTER_LOCK or LOCK_MODE == .MASTER_AND_BLOCK_LOCK;
        const NEED_IO = MASTER_LOCK;
        const FA_MODE = FA_MODE_;
        const DATA_BLOCK_SIZE_POWER = DEF.DATA_BLOCK_SIZE;
        const DATA_BLOCK_SIZE = DATA_BLOCK_SIZE_POWER.value_as_type(IDX);
        const DATA_BLOCK_STATE_BLOCK_SIZE = DATA_BLOCK_SIZE >> @intCast(USIZE_SHIFT);
        const DATA_BLOCK_STATE_VEC_SIZE = DATA_BLOCK_STATE_BLOCK_SIZE / STATE_SIMD_WIDTH;
        pub const FieldEnum = FIELDS_ENUM_;
        const FIELDS_TYPES = FIELDS_TYPES_;
        const INVALID_IDX = math.maxInt(IDX);
        const FREE_STATE: usize = 0b1;
        const USED_STATE: usize = 0b0;
        const STATE_SIMD_WIDTH = @min(64, std.simd.suggestVectorLength(usize) orelse 1);
        const USE_SIMD = STATE_SIMD_WIDTH > 1;
        const StateVector = @Vector(STATE_SIMD_WIDTH, usize);
        const BoolVector = @Vector(STATE_SIMD_WIDTH, bool);
        const BoolVectorInt = @Int(.unsigned, STATE_SIMD_WIDTH);
        const STATE_VEC_ALIGN = @alignOf(StateVector);
        const STATE_VEC_SIZE = @sizeOf(StateVector);
        const USIZE_BITS = @bitSizeOf(usize);
        const USIZE_SHIFT = PowerOf2.USIZE_BITS_SHIFT;
        const USIZE_BITS_MINUS_ONE = PowerOf2.USIZE_BITS_MINUS_ONE;
        const ALLOC_MODE = DEF.ALLOC_MODE;
        const CachedAlloc = ALLOC_MODE.CachedAlloc();
        const FuncAlloc = ALLOC_MODE.FuncParamAlloc();
        const CACHED_ALLOC_DEFAULT = ALLOC_MODE.CACHED_ALLOC_DEFAULT();
        const EMPTY_STATE_VEC_ALL_ONES: StateVector = @splat(1);
        const FULL_STATE_VEC_ALL_ZEROES: StateVector = @splat(0);
        const EMPTY_STATE_BLOCK: usize = math.maxInt(usize);
        const FULL_STATE_BLOCK: usize = 0;
        const SLOT_STEP_PER_VEC = STATE_SIMD_WIDTH * USIZE_BITS;
        const SLOT_STEP_PER_BLOCK = USIZE_BITS;
        const STATE_STEP_PER_VEC = STATE_SIMD_WIDTH;
        const DATA_BLOCK_ALIGN = @alignOf(DataBlock);
        const DataBlock = struct {
            vals: [DATA_BLOCK_SIZE]ELEM = undefined,
            state: [DATA_BLOCK_STATE_BLOCK_SIZE]usize align(STATE_VEC_ALIGN) = @splat(1),
            num_free: IDX = DATA_BLOCK_SIZE,
        };
        const DataBlockSlice = ListSliceModule.ListFullDefinition(*DataBlock, IDX, .WHOLE_STRUCTS, .SERIAL_INDEXES, .REFERENCED_MUTABLE, .MANUAL_ALLOC);

        blocks: [*]*DataBlock = Utils.invalid_ptr_many(*DataBlock),
        blocks_cap: IDX = 0,
        num_free: IDX = 0,
        cached_alloc: CachedAlloc = CACHED_ALLOC_DEFAULT,
        master_lock: if (MASTER_LOCK) RwLock else void = if (MASTER_LOCK) RwLock,
        io: if (NEED_IO) Io else void = if (NEED_IO) undefined else {},

        inline fn assert_field_access(comptime src: ?std.builtin.SourceLocation) void {
            comptime assert_with_reason(FA_MODE != .NOT_SUPPORTED, src, "field access not supported", .{});
        }
        inline fn assert_tagged_field_active(union_val: ELEM, comptime field: FieldEnum, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(std.meta.activeTag(union_val) == std.meta.activeTag(@unionInit(ELEM, @tagName(field), undefined)), src, "field `{s}` was not active on the union, cannot get it", .{@tagName(field)});
        }
        inline fn FieldType(comptime field: FieldEnum) type {
            return FIELDS_TYPES[@backingInt(field)];
        }

        pub fn lock_pool_for_write(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.master_lock.lockUncancelable(self.io);
            }
        }
        pub fn unlock_pool_for_write(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.master_lock.unlock(self.io);
            }
        }
        pub fn lock_pool_for_read(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.master_lock.lockSharedUncancelable(self.io);
            }
        }
        pub fn unlock_pool_for_read(self: *Self) void {
            if (comptime MASTER_LOCK) {
                self.master_lock.unlockShared(self.io);
            }
        }
        fn data_block_ptr_gt(slice: DataBlockSlice, idx_in_list: IDX, data_ptr_to_compare: *DataBlock, _: void, comptime _: void) bool {
            return @intFromPtr(slice.get(idx_in_list)) > @intFromPtr(data_ptr_to_compare);
        }
        fn data_block_ptr_eq_proto(slice: DataBlockSlice, idx_in_list: IDX, data_ptr_to_compare: *DataBlock, _: void, comptime _: void) bool {
            const block_in_list_ptr = slice.get(idx_in_list);
            return @intFromPtr(block_in_list_ptr) <= @intFromPtr(data_ptr_to_compare) and @intFromPtr(data_ptr_to_compare) < @intFromPtr(block_in_list_ptr) + @sizeOf(DataBlock);
        }

        inline fn ensure_free_slots_internal(self: *Self, needed_free_slots: IDX, fn_alloc: FuncAlloc) void {
            if (self.num_free < needed_free_slots) {
                const needed_blocks = @divCeil(needed_free_slots, DATA_BLOCK_SIZE);
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
                self.num_free += needed_blocks * DATA_BLOCK_SIZE;
                const blocks_slice = DataBlockSlice.from_slice_keep_data(self.blocks[0..new_blocks_cap]);
                blocks_slice.insertion_sort_advanced({}, {}, .COMPTIME_FN_BODY, {}, data_block_ptr_gt);
            }
        }

        pub inline fn ensure_free_space(self: *Self, needed_free_slots: IDX, fn_alloc: FuncAlloc) void {
            self.lock_pool_for_write();
            self.ensure_free_slots_internal(needed_free_slots, fn_alloc);
            self.unlock_pool_for_write();
        }

        pub fn get_num_free(self: *Self) IDX {
            self.lock_pool_for_read();
            const num = self.num_free;
            self.unlock_pool_for_read();
            return num;
        }
        pub fn init(init_capacity: IDX, allocator: Allocator, init_io: if (NEED_IO) Io else void) void {
            var self = Self{
                .cached_alloc = ALLOC_MODE.alloc_to_cached_alloc(allocator),
                .io = init_io,
            };
            self.ensure_free_slots_internal(init_capacity, ALLOC_MODE.alloc_to_func_alloc(allocator));
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
            self.* = .{};
        }

        pub fn claim_slot(self: *Self) *ELEM {
            self.lock_pool_for_write();
            self.ensure_free_slots_internal(1);
            for (self.blocks[0..self.blocks_cap]) |block| {
                if (block.num_free == 0) continue;
                var slot_idx: IDX = 0;
                var state_idx: IDX = 0;
                var remaining: IDX = DATA_BLOCK_SIZE;
                if (comptime USE_SIMD) {
                    var state_vec_ptr: *StateVector = @ptrCast(@alignCast(&block.state));
                    while (remaining >= SLOT_STEP_PER_VEC) {
                        const state_vec: StateVector = state_vec_ptr[0];
                        const any_in_vec_empty = state_vec > FULL_STATE_VEC_ALL_ZEROES;
                        const any_in_vec_empty_int: BoolVectorInt = @bitCast(any_in_vec_empty);
                        if (any_in_vec_empty_int != 0) {
                            const first_block_with_empty: IDX = @intCast(@ctz(any_in_vec_empty_int));
                            var state_block_ptr: [*]usize = @ptrCast(@alignCast(state_vec_ptr));
                            state_block_ptr += first_block_with_empty;
                            const first_emtpy_slot_in_block: IDX = @intCast(@ctz(state_block_ptr[0]));
                            const true_idx = slot_idx + (first_block_with_empty * SLOT_STEP_PER_BLOCK) + first_emtpy_slot_in_block;
                            const slot_ptr = &block.vals[true_idx];
                            state_block_ptr[0] &= state_block_ptr[0] - 1;
                            self.num_free -= 1;
                            block.num_free -= 1;
                            self.unlock_pool_for_write();
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
                        const slot_ptr = &block.vals[true_idx];
                        block.state[state_idx] &= block.state[state_idx] - 1;
                        self.num_free -= 1;
                        block.num_free -= 1;
                        self.unlock_pool_for_write();
                        return slot_ptr;
                    }
                    state_idx += 1;
                    remaining -= SLOT_STEP_PER_BLOCK;
                    slot_idx += SLOT_STEP_PER_BLOCK;
                }
            }
            assert_unreachable(@src(), "no blocks had free slots: either the pool was corrupted or `ensure_free_slots(1)` failed to actually ensure free slots", .{});
            self.unlock_pool_for_write();
            return undefined;
        }
        pub fn release_slot(self: *Self, slot: *ELEM) void {
            self.lock_pool_for_write();
            const proto_block_addr: usize = std.mem.alignBackward(usize, @intFromPtr(slot), DATA_BLOCK_ALIGN);
            const proto_block: *DataBlock = @ptrFromInt(proto_block_addr);
            const block_slice = DataBlockSlice.from_slice_keep_data(self.blocks[0..self.blocks_cap]);
            const possible_block_idx = block_slice.binary_search_advanced(proto_block, 0, self.blocks_cap, {}, {}, .COMPTIME_FN_BODY, {}, data_block_ptr_eq_proto, .COMPTIME_FN_BODY, {}, data_block_ptr_gt);
            if (possible_block_idx) |block_idx| {
                const block = self.blocks[block_idx];
                const vals_addr = @intFromPtr(&block.vals[0]);
                const slot_addr = @backingInt(slot);
                const slot_idx = (slot_addr - vals_addr) / @sizeOf(ELEM);
                const state_idx = slot_idx >> USIZE_SHIFT;
                const state_bit_idx = slot_idx & USIZE_BITS_MINUS_ONE;
                const state_bit = @as(usize, 1) << state_bit_idx;
                block.state[state_idx] |= state_bit;
                block.num_free += 1;
                self.num_free += 1;
            } else {
                assert_unreachable(@src(), "slot did not belong to ANY data block in the pool", .{});
            }
            self.unlock_pool_for_write();
        }

        //TODO iterators
    };
}
