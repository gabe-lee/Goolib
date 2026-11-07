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
pub const LockModule = Root.Threading.LocksModule;
pub const LockKind = LockModule.LockKind;

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const invalid_ptr = Utils.invalid_ptr;
const invalid_ptr_many = Utils.invalid_ptr_many;

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

pub const IterSlotMode = enum {
    VAL,
    PTR,
    CONST_PTR,
};

const FieldAccessMode = enum {
    NOT_SUPPORTED,
    UNION_TAGGED,
    UNION_UNTAGGED,
    STRUCT,
};

const LockedMode = enum {
    NONE,
    READ,
    WRITE,
};

fn FieldIntType(comptime num_fields: usize) type {
    if (num_fields <= math.maxInt(u8)) return u8;
    if (num_fields <= math.maxInt(u16)) return u16;
    if (num_fields <= math.maxInt(u32)) return u32;
    return u64;
}

pub const ThreadSafteyModelKind = enum {
    /// No thead safety. Either the application is always single-threaded,
    /// or there will NEVER be any cross-thread access of the pool
    NO_THREAD_SAFETY,
    /// Global vars are prefixed with the `threadlocal` keyword,
    /// meaning each thread gets it own, completely separate set of Pools
    THREADLOCAL_VARS,
    /// Data access is controlled by a series of locks, optionally
    /// defining a differnt kind for Pool, Block, and ELement level access
    DATA_LOCKS,
};

pub const ThreadSafteyModel = union(ThreadSafteyModelKind) {
    /// No thead safety. Either the application is always single-threaded,
    /// or there will NEVER be any cross-thread access of the pool
    NO_THREAD_SAFETY: void,
    /// Global vars are prefixed with the `threadlocal` keyword,
    /// meaning each thread gets it own, completely separate set of Pools
    THREADLOCAL_VARS: void,
    /// Data access is controlled by a series of locks, optionally
    /// defining a differnt kind for Pool, Block, and ELement level access
    DATA_LOCKS: AllLockModes,

    /// No thead safety. Either the application is always single-threaded,
    /// or there will NEVER be any cross-thread access of the pool
    pub inline fn no_thread_safety() ThreadSafteyModel {
        return ThreadSafteyModel{ .NO_THREAD_SAFETY = {} };
    }
    /// Global vars are prefixed with the `threadlocal` keyword,
    /// meaning each thread gets it own, completely separate set of Pools
    pub inline fn threadlocal_vars() ThreadSafteyModel {
        return ThreadSafteyModel{ .THREADLOCAL_VARS = {} };
    }
    /// Data access is controlled by a series of locks, optionally
    /// defining a differnt kind for Pool, Block, and ELement level access
    pub inline fn data_locks(comptime all_locks: AllLockModes) ThreadSafteyModel {
        return ThreadSafteyModel{ .DATA_LOCKS = all_locks };
    }

    pub inline fn get_all_locks(comptime self: ThreadSafteyModel) AllLockModes {
        return switch (comptime self) {
            .NO_THREAD_SAFETY, .THREADLOCAL_VARS => AllLockModes{},
            .DATA_LOCKS => |all_locks| all_locks,
        };
    }
    pub inline fn use_threadlocal(comptime self: ThreadSafteyModel) bool {
        return switch (comptime self) {
            .THREADLOCAL_VARS => true,
            .NO_THREAD_SAFETY, .DATA_LOCKS => false,
        };
    }
};

pub const AllLockModes = struct {
    /// The locking mechanism to use for each type pool, as a whole
    POOL_LOCK_MODE: LockKind = .NONE,
    /// The locking mechanism to use for each data block of elements
    BLOCK_LOCK_MODE: LockKind = .NONE,
    /// The locking mechanism to use for each individial element
    ELEM_LOCK_MODE: LockKind = .NONE,
};

pub const GlobalDef = struct {
    /// Max number of elements per type catagory
    MAX_NUM_ELEMS: PowerOf2 = ._4_294_967_296,
    /// Max generation before generation rollover
    MAX_GENERATION: PowerOf2 = ._4_294_967_296,
    /// A list of all types for the Global Multi-Type Pool
    POOL_DEFS: []const SubPoolDef,
    /// If included, every element will have this metadata type
    /// paired along side it, regardless of pool type.
    ELEM_METADATA_TYPE: ?type = null,
    /// If included and `ELEM_METADATA_TYPE != null`,
    /// the element metadata will be initialized to the
    /// value pointed to by this pointer on element claim
    ELEM_METADATA_TYPE_DEFAULT: ?*const anyopaque = null,
    /// The thead safety model to use for the global pool
    THREAD_SAFETY: ThreadSafteyModel = .no_thread_safety(),
    /// How to handle assertions for element state
    ELEM_STATE_ASSERT_MODE: Assert.AssertBehavior = .PANIC_IN_SAFE_MODES,
    /// If you want 2 separate global multi-type pools, even if they
    /// have exactly the same settings, you can use this unique name
    /// to force them to be compiled as separate types, and have separate
    /// data.
    UNIQUE_NAME: []const u8 = "<DEFAULT>",
};

pub const SubPoolDef = struct {
    /// The element type for the pool
    TYPE: type,
    /// The number of bits in each state-tracking integer,
    /// where each bit represents the used/free state
    /// of one of the elements. Must be >= 8 and <= `ELEMENTS_PER_BLOCK`
    ELEMENTS_PER_STATE_GROUP: PowerOf2 = .USIZE_BITS_VAL,
    /// The number of elements per block. MUST be >= `ELEMENTS_PER_STATE_GROUP`
    ELEMENTS_PER_BLOCK: PowerOf2 = ._64,
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
        pub const UNIQUE_NAME = GDEF.UNIQUE_NAME;
        pub const NEED_IO = !NONE_IO;
        const ElemIdx = GDEF.MAX_NUM_ELEMS.unsigned_integer_type_that_holds_all_values_less_than();
        const INVALID_IDX = math.maxInt(ElemIdx);
        const GenId = GDEF.MAX_GENERATION.unsigned_integer_type_that_holds_all_values_less_than();
        const NUM_TYPES = GDEF.POOL_DEFS.len;
        const USE_THREADLOCAL = GDEF.THREAD_SAFETY.use_threadlocal();
        const ALL_LOCK_MODES = GDEF.THREAD_SAFETY.get_all_locks();
        const POOL_LOCK_MODE = ALL_LOCK_MODES.POOL_LOCK_MODE;
        const BLOCK_LOCK_MODE = ALL_LOCK_MODES.BLOCK_LOCK_MODE;
        const ELEM_LOCK_MODE = ALL_LOCK_MODES.ELEM_LOCK_MODE;
        const StateAssert = Assert.AssertHandler(GDEF.ELEM_STATE_ASSERT_MODE);
        const USE_LOCK_ASSERTS = StateAssert._should_assert();
        const PoolLock = POOL_LOCK_MODE.lock_type(USE_LOCK_ASSERTS);
        const PoolLockPtr = POOL_LOCK_MODE.lock_ptr_type(USE_LOCK_ASSERTS);
        const PoolLockDefault = POOL_LOCK_MODE.init(USE_LOCK_ASSERTS);
        const PoolLockIo = POOL_LOCK_MODE.io_type();
        const BlockLock = BLOCK_LOCK_MODE.lock_type(USE_LOCK_ASSERTS);
        const BlockLockPtr = BLOCK_LOCK_MODE.lock_ptr_type(USE_LOCK_ASSERTS);
        const BlockLockDefault = BLOCK_LOCK_MODE.init(USE_LOCK_ASSERTS);
        const BlockLockIo = BLOCK_LOCK_MODE.io_type();
        const ElemLock = ELEM_LOCK_MODE.lock_type(USE_LOCK_ASSERTS);
        const ElemLockPtr = ELEM_LOCK_MODE.lock_ptr_type(USE_LOCK_ASSERTS);
        const ElemLockDefault = ELEM_LOCK_MODE.init(USE_LOCK_ASSERTS);
        const ElemLockIo = ELEM_LOCK_MODE.io_type();
        const TypeId = PowerOf2.round_up_to_power_of_2(NUM_TYPES).unsigned_integer_type_that_holds_all_values_less_than();
        const PoolTypes = pool_types_const;
        const HAS_META = GDEF.ELEM_METADATA_TYPE != null;
        const META = if (GDEF.ELEM_METADATA_TYPE) |MT| MT else void;
        const META_DEFAULT: META = if (HAS_META) (if (GDEF.ELEM_METADATA_TYPE_DEFAULT) |ptr| @as(*const META, @ptrCast(@alignCast(ptr))) else undefined) else {};
        const POOLS = build: {
            var out: [NUM_TYPES]type = undefined;
            for (GDEF.POOL_DEFS, 0..) |def, i| {
                out[i] = SubPool(def);
            }
            break :build out;
        };
        const LockPackage = struct {
            io: Io,
            pm: LockedMode,
            p: PoolLockPtr,
            bm: LockedMode,
            b: BlockLockPtr,
            em: LockedMode,
            e: ElemLockPtr,

            pub fn unlock(self: LockPackage) void {
                switch (self.em) {
                    .NONE => {},
                    .READ => ELEM_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, self.e, self.io),
                    .WRITE => ELEM_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, self.e, self.io),
                }
                switch (self.bm) {
                    .NONE => {},
                    .READ => BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, self.b, self.io),
                    .WRITE => BLOCK_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, self.b, self.io),
                }
                switch (self.pm) {
                    .NONE => {},
                    .READ => POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, self.p, self.io),
                    .WRITE => POOL_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, self.p, self.io),
                }
            }
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
                comptime {
                    assert_with_reason(@typeInfo(KeySelf).@"struct".backing_integer.? == @typeInfo(OpaqueKey).@"struct".backing_integer.?, null, "the backing integer of `Key({s})` ({s}) does not match the backing integer of `OpaqueKey` ({s})", .{ @typeName(T), @typeInfo(KeySelf).@"struct".backing_integer.?, @typeInfo(OpaqueKey).@"struct".backing_integer.? });
                    assert_with_reason(@typeInfo(KeySelf).@"struct".backing_integer.? == @typeInfo(ConstKey(T)).@"struct".backing_integer.?, null, "the backing integer of `Key({s})` ({s}) does not match the backing integer of `ConstKey({s})` ({s})", .{ @typeName(T), @typeInfo(KeySelf).@"struct".backing_integer.?, @typeName(T), @typeInfo(OpaqueKey).@"struct".backing_integer.? });
                    assert_with_reason(@bitSizeOf(POOL.BlockIdx) + @bitSizeOf(POOL.SubElemIdx) == @bitSizeOf(ElemIdx), null, "for `Key({s})`, `@bitSizeOf(POOL.BlockIdx)` ({d}) + `@bitSizeOf(POOL.SubElemIdx)` ({d}) does not match `@bitSizeOf(ElemIdx)` ({d})", .{ @typeName(T), @bitSizeOf(POOL.BlockIdx) + @bitSizeOf(POOL.SubElemIdx) == @bitSizeOf(ElemIdx) });
                }
                pub const Field = POOL.FIELD_ENUM;
                pub fn FieldType(comptime field: Field) type {
                    return POOL.field_type(field);
                }
                pub const INVALID = KeySelf{
                    .block_idx = math.maxInt(POOL.BlockIdx),
                    .elem_idx = math.maxInt(POOL.SubElemIdx),
                    .gen = math.maxInt(GenId),
                };
                pub const FA_MODE: FieldAccessMode = POOL.FA_MODE;

                block_idx: POOL.BlockIdx,
                elem_idx: POOL.SubElemIdx,
                gen: GenId,

                pub inline fn to_opaque(self: KeySelf) OpaqueKey {
                    return @fromBackingInt(@backingInt(self));
                }
                pub inline fn from_opaque(opq: OpaqueKey) KeySelf {
                    return @fromBackingInt(@backingInt(opq));
                }
                pub inline fn to_const(self: KeySelf) ConstKey(T) {
                    return @fromBackingInt(@backingInt(self));
                }

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
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    defer POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    if (self.block_idx >= POOL.pool.blocks_cap) return false;
                    const block = POOL.pool.blocks[self.block_idx];
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    defer ELEM_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
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
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    defer ELEM_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    return block.vals[self.elem_idx];
                }
                pub fn get_meta(self: KeySelf) META {
                    if (comptime !HAS_META) return {};
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    defer ELEM_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    return block.meta[self.elem_idx];
                }
                pub fn get_val_and_meta(self: KeySelf) struct { T, META } {
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    defer ELEM_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    if (comptime HAS_META) {
                        return .{ block.vals[self.elem_idx], block.meta[self.elem_idx] };
                    } else {
                        return .{ block.vals[self.elem_idx], {} };
                    }
                }
                pub fn get_const_ptr_hold_locks(self: KeySelf) struct { *const T, LockPackage } {
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    return .{ &block.vals[self.elem_idx], LockPackage{
                        .io = global.io,
                        .e = if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {},
                        .em = if (ELEM_LOCK_MODE.has_lock()) .READ else .NONE,
                        .b = if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {},
                        .bm = if (BLOCK_LOCK_MODE.has_lock()) .READ else .NONE,
                        .p = if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {},
                        .pm = if (POOL_LOCK_MODE.has_lock()) .READ else .NONE,
                    } };
                }
                pub fn get_ptr_hold_locks(self: KeySelf) struct { *T, LockPackage } {
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    return .{ &block.vals[self.elem_idx], LockPackage{
                        .io = global.io,
                        .e = if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {},
                        .em = if (ELEM_LOCK_MODE.has_lock()) .WRITE else .NONE,
                        .b = if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {},
                        .bm = if (BLOCK_LOCK_MODE.has_lock()) .READ else .NONE,
                        .p = if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {},
                        .pm = if (POOL_LOCK_MODE.has_lock()) .READ else .NONE,
                    } };
                }

                pub fn get_field(self: KeySelf, comptime field: POOL.FIELDS_ENUM) POOL.field_type(field) {
                    POOL.assert_field_access();
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    defer ELEM_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    if (comptime POOL.FA_MODE == .UNION_TAGGED) {
                        POOL.assert_tagged_field_active(std.meta.activeTag(block.vals[self.elem_idx]), field, @src());
                    }
                    return @field(&block.vals[self.elem_idx], @tagName(field));
                }
                pub fn get_field_ptr_hold_lock(self: KeySelf, comptime field: POOL.FIELDS_ENUM) struct { *POOL.field_type(field), LockPackage } {
                    POOL.assert_field_access();
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    if (comptime POOL.FA_MODE == .UNION_TAGGED) {
                        POOL.assert_tagged_field_active(std.meta.activeTag(block.vals[self.elem_idx]), field, @src());
                    }
                    const ptr: *POOL.field_type(field) = &@field(&block.vals[self.elem_idx], @tagName(field));
                    return .{ ptr, LockPackage{
                        .io = global.io,
                        .e = if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {},
                        .em = if (ELEM_LOCK_MODE.has_lock()) .WRITE else .NONE,
                        .b = if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {},
                        .bm = if (BLOCK_LOCK_MODE.has_lock()) .READ else .NONE,
                        .p = if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {},
                        .pm = if (POOL_LOCK_MODE.has_lock()) .READ else .NONE,
                    } };
                }
                pub fn get_field_const_ptr_hold_locks(self: KeySelf, comptime field: POOL.FIELDS_ENUM) struct { *const POOL.field_type(field), LockPackage } {
                    POOL.assert_field_access();
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    if (comptime POOL.FA_MODE == .UNION_TAGGED) {
                        POOL.assert_tagged_field_active(std.meta.activeTag(block.vals[self.elem_idx]), field, @src());
                    }
                    const ptr: *const POOL.field_type(field) = &@field(&block.vals[self.elem_idx], @tagName(field));
                    return .{ ptr, LockPackage{
                        .io = global.io,
                        .e = if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {},
                        .em = if (ELEM_LOCK_MODE.has_lock()) .READ else .NONE,
                        .b = if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {},
                        .bm = if (BLOCK_LOCK_MODE.has_lock()) .READ else .NONE,
                        .p = if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {},
                        .pm = if (POOL_LOCK_MODE.has_lock()) .READ else .NONE,
                    } };
                }

                pub fn set(self: KeySelf, val: T) void {
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    defer ELEM_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    block.vals[self.elem_idx] = val;
                }
                pub fn set_meta(self: KeySelf, meta: META) void {
                    if (comptime !HAS_META) return;
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    defer ELEM_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    block.meta[self.elem_idx] = meta;
                }
                pub fn set_val_and_meta(self: KeySelf, val: T, meta: META) void {
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    defer ELEM_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    block.vals[self.elem_idx] = val;
                    if (comptime HAS_META) {
                        block.meta[self.elem_idx] = meta;
                    }
                }
                pub fn set_field(self: KeySelf, comptime field: POOL.FIELDS_ENUM, val: POOL.field_type(field)) void {
                    POOL.assert_field_access();
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io);
                    BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    defer BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                    ELEM_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    defer ELEM_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io);
                    self.assert_valid(block);
                    if (comptime POOL.FA_MODE == .UNION_TAGGED or POOL.FA_MODE == .UNION_UNTAGGED) {
                        block.vals[self.elem_idx] = @unionInit(POOL.TYPE, @tagName(field), val);
                    } else {
                        @field(&block.vals[self.elem_idx], @tagName(field)) = val;
                    }
                }

                pub fn release_advanced(self: KeySelf, comptime pool_lock_mode: PoolLockMode, comptime block_lock_mode: BlockLockMode, comptime elem_lock_mode: ElemLockMode) void {
                    switch (comptime pool_lock_mode) {
                        .CHECK_POOL_LOCKS => POOL_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io),
                        .IGNORE_POOL_LOCKS => {},
                    }
                    defer switch (comptime pool_lock_mode) {
                        .CHECK_POOL_LOCKS => POOL_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &POOL.pool.pool_lock else {}, global.io),
                        .IGNORE_POOL_LOCKS => {},
                    };
                    assert_with_reason(self.block_idx < POOL.pool.blocks_cap, @src(), "key block index ({d}) is out of bounds for block count ({d})", .{ self.block_idx, POOL.pool.blocks_cap });
                    const block = POOL.pool.blocks[self.block_idx];
                    switch (comptime block_lock_mode) {
                        .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io),
                        .IGNORE_BLOCK_LOCKS => {},
                    }
                    defer switch (comptime block_lock_mode) {
                        .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io),
                        .IGNORE_BLOCK_LOCKS => {},
                    };
                    switch (comptime elem_lock_mode) {
                        .CHECK_ELEM_LOCKS => ELEM_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io),
                        .IGNORE_ELEM_LOCKS => {},
                    }
                    defer switch (comptime elem_lock_mode) {
                        .CHECK_ELEM_LOCKS => ELEM_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &block.val_locks[self.elem_idx] else {}, global.io),
                        .IGNORE_ELEM_LOCKS => {},
                    };
                    const state_info = self.assert_valid_get_info(block);
                    block.state[state_info.state_idx] |= state_info.state_bit_empty;
                    block.gens[self.elem_idx] +%= 1;
                    block.num_free += 1;
                    POOL.pool.pool_num_free += 1;
                }
                pub inline fn release(self: KeySelf) void {
                    self.release_advanced(.CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS, .CHECK_ELEM_LOCKS);
                }
            };
        }
        pub fn ConstKey(comptime T: type) type {
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
                comptime {
                    assert_with_reason(@typeInfo(KeySelf).@"struct".backing_integer.? == @typeInfo(OpaqueKey).@"struct".backing_integer.?, null, "the backing integer of `ConstKey({s})` ({s}) does not match the backing integer of `OpaqueKey` ({s})", .{ @typeName(T), @typeInfo(KeySelf).@"struct".backing_integer.?, @typeInfo(OpaqueKey).@"struct".backing_integer.? });
                    assert_with_reason(@bitSizeOf(POOL.BlockIdx) + @bitSizeOf(POOL.SubElemIdx) == @bitSizeOf(ElemIdx), null, "for `ConstKey({s})`, `@bitSizeOf(POOL.BlockIdx)` ({d}) + `@bitSizeOf(POOL.SubElemIdx)` ({d}) does not match `@bitSizeOf(ElemIdx)` ({d})", .{ @typeName(T), @bitSizeOf(POOL.BlockIdx) + @bitSizeOf(POOL.SubElemIdx) == @bitSizeOf(ElemIdx) });
                }
                pub const Field = POOL.FIELD_ENUM;
                pub fn FieldType(comptime field: Field) type {
                    return POOL.field_type(field);
                }
                pub const INVALID = KeySelf{
                    .block_idx = math.maxInt(POOL.BlockIdx),
                    .elem_idx = math.maxInt(POOL.SubElemIdx),
                    .gen = math.maxInt(GenId),
                };
                pub const FA_MODE: FieldAccessMode = POOL.FA_MODE;

                block_idx: POOL.BlockIdx,
                elem_idx: POOL.SubElemIdx,
                gen: GenId,

                inline fn to_mut(self: KeySelf) Key(T) {
                    return @fromBackingInt(@backingInt(self));
                }
                pub inline fn to_opaque(self: KeySelf) OpaqueKey {
                    return @fromBackingInt(@backingInt(self));
                }
                pub inline fn from_opaque(opq: OpaqueKey) KeySelf {
                    return @fromBackingInt(@backingInt(opq));
                }

                pub inline fn is_valid(self: KeySelf) bool {
                    return self.to_mut().is_valid();
                }

                pub inline fn get(self: KeySelf) T {
                    return self.to_mut().get();
                }
                pub inline fn get_const_ptr_hold_locks(self: KeySelf) struct { *const T, LockPackage } {
                    return self.to_mut().get_const_ptr_hold_locks();
                }
                pub inline fn get_ptr_hold_locks(self: KeySelf) struct { *T, LockPackage } {
                    return self.to_mut().get_ptr_hold_locks();
                }

                pub inline fn get_field(self: KeySelf, comptime field: POOL.FIELDS_ENUM) POOL.field_type(field) {
                    return self.to_mut().get_field(field);
                }
                pub inline fn get_field_ptr_hold_lock(self: KeySelf, comptime field: POOL.FIELDS_ENUM) struct { *POOL.field_type(field), LockPackage } {
                    return self.to_mut().get_field_ptr_hold_lock(field);
                }
                pub inline fn get_field_const_ptr_hold_locks(self: KeySelf, comptime field: POOL.FIELDS_ENUM) struct { *const POOL.field_type(field), LockPackage } {
                    return self.to_mut().get_field_const_ptr_hold_locks(field);
                }

                pub inline fn release_advanced(self: KeySelf, comptime pool_lock_mode: PoolLockMode, comptime block_lock_mode: BlockLockMode, comptime elem_lock_mode: ElemLockMode) void {
                    return self.to_mut().release_advanced(pool_lock_mode, block_lock_mode, elem_lock_mode);
                }
                pub inline fn release(self: KeySelf) void {
                    self.to_mut().release_advanced(.CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS, .CHECK_ELEM_LOCKS);
                }
            };
        }
        pub const OpaqueKey = packed struct {
            idx: ElemIdx,
            gen: GenId,

            pub inline fn to_typed(self: OpaqueKey, comptime T: type) Key(T) {
                return Key(T).from_opaque(self);
            }
            pub inline fn from_typed(comptime T: type, key: Key(T)) OpaqueKey {
                return key.to_opaque();
            }
        };
        fn SubPool(comptime DEF: SubPoolDef) type {
            assert_with_reason(Types.type_is_unsigned_int(ElemIdx), @src(), "type `ElemIdx` must be an unsigned integer type, got type `{s}`", .{@typeName(ElemIdx)});
            assert_with_reason(@sizeOf(DEF.TYPE) > 0, @src(), "type `TYPE` must have a non-zero size so that every slot has a distinct address", .{});
            assert_with_reason(DEF.ELEMENTS_PER_BLOCK.value() > 0, @src(), "`ELEMENTS_PER_BLOCK` must be greater than zero", .{});
            assert_with_reason(DEF.ELEMENTS_PER_BLOCK.value() <= math.maxInt(ElemIdx), @src(), "`ELEMENTS_PER_BLOCK` ({d}) must be <= `math.maxInt(ElemIdx)` ({d})", .{ DEF.ELEMENTS_PER_BLOCK, math.maxInt(ElemIdx) });
            assert_with_reason(DEF.ELEMENTS_PER_BLOCK.raw_int() >= DEF.ELEMENTS_PER_STATE_GROUP.raw_int(), @src(), "`ELEMENTS_PER_BLOCK` ({d}) must be >= `ELEMENTS_PER_STATE_GROUP` ({d}) so the state array has at least one full group", .{ DEF.ELEMENTS_PER_BLOCK.value(), DEF.ELEMENTS_PER_STATE_GROUP.value() });
            assert_with_reason(DEF.ELEMENTS_PER_STATE_GROUP.raw_int() >= PowerOf2._8.raw_int(), @src(), "`ELEMENTS_PER_STATE_GROUP` ({d}) must be >= 8 so that the state integer is at leas a u8", .{DEF.ELEMENTS_PER_STATE_GROUP.raw_int()});
            assert_with_reason(GDEF.MAX_NUM_ELEMS.value() >= DEF.ELEMENTS_PER_BLOCK.value(), @src(), "`MAX_NUM_ELEMS` ({d}) must be at least `ELEMENTS_PER_BLOCK` ({d})", .{ GDEF.MAX_NUM_ELEMS, DEF.ELEMENTS_PER_BLOCK });
            const FA_MODE_, const FIELDS_ENUM_, const FIELDS_TYPES_ = make: {
                const T_INFO = @typeInfo(DEF.TYPE);
                switch (T_INFO) {
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
                        break :make .{ FieldAccessMode.NOT_SUPPORTED, enum { @"!NOT_SUPPORTED" }, [1]type{DEF.TYPE} };
                    },
                }
            };
            return struct {
                const Sub = @This();
                const STATE_UINT = @Int(.unsigned, @intCast(DEF.ELEMENTS_PER_STATE_GROUP.value()));
                const ELEMENTS_PER_BLOCK: usize = @intCast(DEF.ELEMENTS_PER_BLOCK.value());
                const DATA_BLOCK_STATE_GROUP_LENGTH = @divExact(@as(usize, ELEMENTS_PER_BLOCK), @bitSizeOf(STATE_UINT));
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
                const SubElemIdx = DEF.ELEMENTS_PER_BLOCK.unsigned_integer_type_that_holds_all_values_less_than();
                const BLOCK_IDX_BITS = @backingInt(GDEF.MAX_NUM_ELEMS) - @backingInt(DEF.ELEMENTS_PER_BLOCK);
                const BlockIdx = @Int(.unsigned, @max(1, BLOCK_IDX_BITS));
                const INVALID_ELEM_IDX = math.maxInt(ElemIdx);
                const FA_MODE = FA_MODE_;
                const FIELDS_ENUM = FIELDS_ENUM_;
                const FIELDS_TYPES = FIELDS_TYPES_;
                fn assert_field_access() void {
                    comptime assert_with_reason(FA_MODE != .NOT_SUPPORTED, @src(), "field acces not supported", .{});
                }
                pub inline fn field_type(comptime field: FIELDS_ENUM) type {
                    assert_field_access();
                    return FIELDS_TYPES[@backingInt(field)];
                }
                inline fn assert_tagged_field_active(active_tag: std.meta.Tag(TYPE), comptime field: FIELDS_ENUM, comptime src: ?std.builtin.SourceLocation) void {
                    assert_with_reason(active_tag == @field(std.meta.Tag(TYPE), @tagName(field)), src, "field `{s}` was not active on the union, cannot get it", .{@tagName(field)});
                }
                const DataBlock = struct {
                    vals: [ELEMENTS_PER_BLOCK]DEF.TYPE = undefined,
                    meta: if (HAS_META) [ELEMENTS_PER_BLOCK]META else void = if (HAS_META) @splat(META_DEFAULT) else {},
                    gens: [ELEMENTS_PER_BLOCK]GenId = @splat(0),
                    state: [DATA_BLOCK_STATE_GROUP_LENGTH]STATE_UINT align(STATE_VEC_ALIGN) = @splat(EMPTY_STATE_BLOCK),
                    val_locks: [ELEMENTS_PER_BLOCK]ElemLock = @splat(ElemLockDefault),
                    num_free: ElemIdx = @intCast(ELEMENTS_PER_BLOCK),
                    lock: BlockLock = BlockLockDefault,
                };
                const StateInfo = struct {
                    state_idx: usize,
                    state_bit_idx: usize,
                    state_bit_empty: STATE_UINT,
                };
                const pool = if (USE_THREADLOCAL) struct {
                    threadlocal var blocks: [*]*DataBlock = invalid_ptr_many(*DataBlock);
                    threadlocal var blocks_cap: BlockIdx = 0;
                    threadlocal var pool_num_free: ElemIdx = 0;
                    threadlocal var pool_lock: PoolLock = PoolLockDefault;
                    threadlocal var gen_base: GenId = 0;
                } else struct {
                    var blocks: [*]*DataBlock = invalid_ptr_many(*DataBlock);
                    var blocks_cap: BlockIdx = 0;
                    var pool_num_free: ElemIdx = 0;
                    var pool_lock: PoolLock = PoolLockDefault;
                    var gen_base: GenId = 0;
                };

                pub fn claim_slot_advanced(comptime pool_lock_mode: PoolLockMode, comptime block_lock_mode: BlockLockMode) Key(TYPE) {
                    switch (comptime pool_lock_mode) {
                        .CHECK_POOL_LOCKS => POOL_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io),
                        .IGNORE_POOL_LOCKS => {},
                    }
                    defer switch (comptime pool_lock_mode) {
                        .CHECK_POOL_LOCKS => POOL_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io),
                        .IGNORE_POOL_LOCKS => {},
                    };
                    Sub.ensure_free_slots_ignore_pool_locks(1);
                    for (pool.blocks[0..pool.blocks_cap], 0..) |block, block_idx| {
                        switch (comptime block_lock_mode) {
                            .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io),
                            .IGNORE_BLOCK_LOCKS => {},
                        }
                        defer switch (comptime block_lock_mode) {
                            .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io),
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
                                    assert_with_reason(elem_idx_wide < ELEMENTS_PER_BLOCK, @src(), "claim found a free state bit beyond the configured slots per block", .{});
                                    const elem_idx: SubElemIdx = @intCast(elem_idx_wide);
                                    if (comptime HAS_META) {
                                        block.meta[elem_idx] = META_DEFAULT;
                                    }
                                    const key = Key(TYPE){
                                        .block_idx = @intCast(block_idx),
                                        .elem_idx = elem_idx,
                                        .gen = block.gens[elem_idx],
                                    };
                                    state_block_ptr[0] &= state_block_ptr[0] - 1;
                                    pool.pool_num_free -= 1;
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
                                assert_with_reason(elem_idx_wide < ELEMENTS_PER_BLOCK, @src(), "claim found a free state bit beyond the configured slots per block", .{});
                                const elem_idx: SubElemIdx = @intCast(elem_idx_wide);
                                const key = Key(TYPE){
                                    .block_idx = @intCast(block_idx),
                                    .elem_idx = elem_idx,
                                    .gen = block.gens[elem_idx],
                                };
                                block.state[state_idx] &= block.state[state_idx] - 1;
                                pool.pool_num_free -= 1;
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
                    if (pool.pool_num_free < needed_free_slots) {
                        const deficit = needed_free_slots - pool.pool_num_free;
                        const needed_blocks_wide: u64 = @divCeil(@as(u64, deficit), @as(u64, ELEMENTS_PER_BLOCK));
                        assert_with_reason(needed_blocks_wide <= @as(u64, INVALID_IDX) - @as(u64, pool.blocks_cap), @src(), "adding {d} data blocks would overflow the block capacity integer", .{needed_blocks_wide});
                        const max_blocks_by_capacity: u64 = @divFloor(@as(u64, INVALID_ELEM_IDX), @as(u64, ELEMENTS_PER_BLOCK));
                        assert_with_reason(@as(u64, pool.blocks_cap) <= max_blocks_by_capacity and needed_blocks_wide <= max_blocks_by_capacity - @as(u64, pool.blocks_cap), @src(), "adding {d} data blocks would make the pool capacity exceed `math.maxInt(ElemIdx)` ({d})", .{ needed_blocks_wide, INVALID_ELEM_IDX });
                        const needed_blocks: BlockIdx = @intCast(needed_blocks_wide);
                        const new_blocks_cap = pool.blocks_cap + needed_blocks;
                        const old_blocks_cap = pool.blocks_cap;
                        const new_block_list = global.alloc.realloc(pool.blocks[0..pool.blocks_cap], new_blocks_cap) catch |e| assert_allocation_failure(@src(), *DataBlock, needed_blocks, e);
                        pool.blocks = new_block_list.ptr;
                        pool.blocks_cap = new_blocks_cap;
                        for (pool.blocks[old_blocks_cap..new_blocks_cap]) |*block| {
                            const new_block = global.alloc.create(DataBlock) catch |e| assert_allocation_failure(@src(), DataBlock, 1, e);
                            new_block.* = DataBlock{};
                            @memset(new_block.gens[0..ELEMENTS_PER_BLOCK], pool.gen_base);
                            block.* = new_block;
                        }
                        pool.pool_num_free += @intCast(@as(u64, needed_blocks) * @as(u64, ELEMENTS_PER_BLOCK));
                    }
                }

                pub inline fn get_num_free_ignore_pool_locks() ElemIdx {
                    return pool.pool_num_free;
                }

                pub inline fn get_num_free() ElemIdx {
                    POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io);
                    defer POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io);
                    return pool.pool_num_free;
                }

                pub inline fn ensure_free_slots(needed_free_slots: ElemIdx) void {
                    POOL_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io);
                    defer POOL_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io);
                    Sub.ensure_free_slots_ignore_pool_locks(needed_free_slots);
                }

                pub fn init(init_capacity: ElemIdx) void {
                    assert_with_reason(pool.blocks_cap == 0, @src(), "cannot init if blocks_cap > 0", .{});
                    pool.blocks = invalid_ptr_many(*DataBlock);
                    pool.blocks_cap = 0;
                    pool.pool_lock = PoolLockDefault;
                    pool.pool_num_free = 0;
                    pool.gen_base +%= 1;
                    Sub.ensure_free_slots_ignore_pool_locks(init_capacity);
                }

                pub fn clear_all_blocks() void {
                    POOL_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io);
                    defer POOL_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io);
                    for (pool.blocks[0..pool.blocks_cap]) |block| {
                        BLOCK_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                        defer BLOCK_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                        if (comptime ELEM_LOCK_MODE.has_lock()) {
                            for (block.val_locks[0..ELEMENTS_PER_BLOCK]) |*elem_lock| {
                                ELEM_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, elem_lock, global.io);
                            }
                        }
                        block.num_free = @intCast(ELEMENTS_PER_BLOCK);
                        block.state = @splat(EMPTY_STATE_BLOCK);
                        for (block.gens[0..ELEMENTS_PER_BLOCK]) |*gen| {
                            gen.* +%= 1;
                        }
                        if (comptime ELEM_LOCK_MODE.has_lock()) {
                            for (block.val_locks[0..ELEMENTS_PER_BLOCK]) |*elem_lock| {
                                ELEM_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, elem_lock, global.io);
                            }
                        }
                    }
                    pool.pool_num_free = @intCast(@as(u64, pool.blocks_cap) * @as(u64, ELEMENTS_PER_BLOCK));
                }

                pub fn uninit() void {
                    POOL_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io);
                    defer POOL_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io);
                    if (pool.blocks_cap > 0) {
                        for (pool.blocks[0..pool.blocks_cap]) |block| {
                            BLOCK_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                            BLOCK_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &block.lock else {}, global.io);
                            global.alloc.destroy(block);
                        }
                        global.alloc.free(pool.blocks[0..pool.blocks_cap]);
                    }
                    pool.blocks = invalid_ptr_many(*DataBlock);
                    pool.blocks_cap = 0;
                    pool.pool_num_free = 0;
                }

                pub fn iterator_advanced(comptime slot_mode: IterSlotMode, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode, comptime elem_lock: ElemLockMode) IteratorAdvanced(slot_mode, pool_lock, block_lock, elem_lock) {
                    return IteratorAdvanced(slot_mode, pool_lock, block_lock, elem_lock).init_and_lock();
                }
                pub fn iterator(comptime slot_mode: IterSlotMode) IteratorAdvanced(slot_mode, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS, .CHECK_ELEM_LOCKS) {
                    return IteratorAdvanced(slot_mode, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS, .CHECK_ELEM_LOCKS).init_and_lock();
                }

                pub fn IteratorAdvanced(comptime slot_mode: IterSlotMode, comptime pool_lock: PoolLockMode, comptime block_lock: BlockLockMode, comptime elem_lock: ElemLockMode) type {
                    return struct {
                        const IterSelf = @This();
                        block: *DataBlock = invalid_ptr(DataBlock),
                        block_idx: BlockIdx = 0,
                        state_idx: ElemIdx = 0,
                        num_used_in_block: ElemIdx = 0,
                        num_used_in_pool: ElemIdx = 0,
                        curr_state_inverted: STATE_UINT = 0,
                        block_is_locked: bool = false,
                        elem_is_locked: bool = false,
                        locked_elem_idx: ElemIdx = 0,

                        const SlotReturn = switch (slot_mode) {
                            .VAL => ?TYPE,
                            .PTR => ?*TYPE,
                            .CONST_PTR => ?*const TYPE,
                        };

                        pub fn init_and_lock() IterSelf {
                            var self = IterSelf{};
                            switch (comptime pool_lock) {
                                .CHECK_POOL_LOCKS => POOL_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io),
                                .IGNORE_POOL_LOCKS => {},
                            }
                            if (pool.blocks_cap > 0) {
                                self.block = pool.blocks[0];
                                switch (comptime block_lock) {
                                    .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &self.block.lock else {}, global.io),
                                    .IGNORE_BLOCK_LOCKS => {},
                                }
                                self.block_is_locked = true;
                                self.num_used_in_block = @intCast(@as(u64, ELEMENTS_PER_BLOCK) - @as(u64, self.block.num_free));
                                self.num_used_in_pool = @intCast((@as(u64, ELEMENTS_PER_BLOCK) * @as(u64, pool.blocks_cap)) - @as(u64, pool.pool_num_free));
                                self.curr_state_inverted = ~self.block.state[0];
                            }
                            return self;
                        }

                        pub fn next(self: *IterSelf) SlotReturn {
                            if (self.elem_is_locked) {
                                switch (comptime elem_lock) {
                                    .CHECK_ELEM_LOCKS => switch (comptime slot_mode) {
                                        .VAL, .CONST_PTR => ELEM_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &self.block.val_locks[self.locked_elem_idx] else {}, global.io),
                                        .PTR => ELEM_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &self.block.val_locks[self.locked_elem_idx] else {}, global.io),
                                    },
                                    .IGNORE_ELEM_LOCKS => {},
                                }
                                self.elem_is_locked = false;
                            }
                            if (self.block_idx >= pool.blocks_cap) return null;
                            loop_over_data_blocks: while (self.num_used_in_pool > 0) {
                                loop_over_state_groups: while (self.num_used_in_block > 0) {
                                    while (self.curr_state_inverted != 0) { // loop_over_slots_in_group
                                        const first_used_slot_bit_offset: ElemIdx = @intCast(@ctz(self.curr_state_inverted));
                                        self.curr_state_inverted &= self.curr_state_inverted - 1;
                                        const first_used_slot_within_block: ElemIdx = @intCast((self.state_idx * SLOT_STEP_PER_STATE_GROUP) + first_used_slot_bit_offset);
                                        switch (comptime elem_lock) {
                                            .CHECK_ELEM_LOCKS => switch (comptime slot_mode) {
                                                .VAL, .CONST_PTR => ELEM_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &self.block.val_locks[first_used_slot_within_block] else {}, global.io),
                                                .PTR => ELEM_LOCK_MODE.lock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &self.block.val_locks[first_used_slot_within_block] else {}, global.io),
                                            },
                                            .IGNORE_ELEM_LOCKS => {},
                                        }
                                        self.elem_is_locked = true;
                                        self.locked_elem_idx = first_used_slot_within_block;
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
                                        .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &self.block.lock else {}, global.io),
                                        .IGNORE_BLOCK_LOCKS => {},
                                    }
                                    self.block_is_locked = false;
                                }
                                self.block_idx = @min(self.block_idx + 1, pool.blocks_cap);
                                if (self.block_idx < pool.blocks_cap) {
                                    self.block = pool.blocks[self.block_idx];
                                    switch (comptime block_lock) {
                                        .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.lock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &self.block.lock else {}, global.io),
                                        .IGNORE_BLOCK_LOCKS => {},
                                    }
                                    self.block_is_locked = true;
                                    self.num_used_in_block = @intCast(@as(u64, ELEMENTS_PER_BLOCK) - @as(u64, self.block.num_free));
                                    self.state_idx = 0;
                                    self.curr_state_inverted = ~self.block.state[0];
                                } else {
                                    break :loop_over_data_blocks;
                                }
                            }
                            return null;
                        }

                        pub fn deinit_and_unlock(self: *IterSelf) void {
                            if (self.elem_is_locked) {
                                switch (comptime elem_lock) {
                                    .CHECK_ELEM_LOCKS => switch (comptime slot_mode) {
                                        .VAL, .CONST_PTR => ELEM_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &self.block.val_locks[self.locked_elem_idx] else {}, global.io),
                                        .PTR => ELEM_LOCK_MODE.unlock_for_write_io(USE_LOCK_ASSERTS, if (ELEM_LOCK_MODE.has_lock()) &self.block.val_locks[self.locked_elem_idx] else {}, global.io),
                                    },
                                    .IGNORE_ELEM_LOCKS => {},
                                }
                            }
                            if (self.block_is_locked) {
                                switch (comptime block_lock) {
                                    .CHECK_BLOCK_LOCKS => BLOCK_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (BLOCK_LOCK_MODE.has_lock()) &self.block.lock else {}, global.io),
                                    .IGNORE_BLOCK_LOCKS => {},
                                }
                            }
                            switch (comptime pool_lock) {
                                .CHECK_POOL_LOCKS => POOL_LOCK_MODE.unlock_for_read_io(USE_LOCK_ASSERTS, if (POOL_LOCK_MODE.has_lock()) &pool.pool_lock else {}, global.io),
                                .IGNORE_POOL_LOCKS => {},
                            }
                            self.* = IterSelf{};
                        }
                    };
                }
            };
        }
        const global = if (USE_THREADLOCAL) struct {
            threadlocal var alloc: Allocator = Root.Allocator.Dummy.allocator_panic_free_noop;
            threadlocal var io: Io = Root.DummyIo.io_undefined;
        } else struct {
            var alloc: Allocator = Root.Allocator.Dummy.allocator_panic_free_noop;
            var io: Io = Root.DummyIo.io_undefined;
        };

        const NONE_IO = POOL_LOCK_MODE.io_type() == void and BLOCK_LOCK_MODE.io_type() == void and ELEM_LOCK_MODE.io_type() == void;
        const InitIo = if (NONE_IO) void else Io;

        pub fn init_global(allocator: Allocator, init_io: InitIo) void {
            global.alloc = allocator;
            if (comptime !NONE_IO) {
                global.io = init_io;
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

        pub fn iterator_advanced(comptime T: type, comptime slot_mode: IterSlotMode, comptime pool_lock_mode: PoolLockMode, comptime block_lock_mode: BlockLockMode, comptime elem_lock_mode: ElemLockMode) Key(T).POOL.IteratorAdvanced(slot_mode, pool_lock_mode, block_lock_mode, elem_lock_mode) {
            const KEY = Key(T);
            return KEY.POOL.iterator_advanced(slot_mode, pool_lock_mode, block_lock_mode, elem_lock_mode);
        }
        pub fn iterator(comptime T: type, comptime slot_mode: IterSlotMode) Key(T).POOL.IteratorAdvanced(slot_mode, .CHECK_POOL_LOCKS, .CHECK_BLOCK_LOCKS, .CHECK_ELEM_LOCKS) {
            const KEY = Key(T);
            return KEY.POOL.iterator(slot_mode);
        }
    };
}
