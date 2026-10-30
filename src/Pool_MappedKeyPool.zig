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

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

pub const MutexMode = enum {
    NO_MUTEXES,
    MASTER_MUTEX,
    MASTER_AND_BLOCK_MUTEX,
};

pub const PoolDef = struct {
    ELEM: type,
    IDX: type,
    MUTEX_MODE: MutexMode,
    MUTEX_BLOCK_COVERAGE: comptime_int = 64,
};

pub fn GlobalMappedKeyPool(comptime DEF: PoolDef) type {
    assert_with_reason(Types.type_is_unsigned_int(DEF.IDX), @src(), "type `IDX` must be an unsigned integer type, got type `{s}`", .{@typeName(DEF.IDX)});
    assert_with_reason(DEF.MUTEX_MODE == .NO_MUTEXES or DEF.MUTEX_BLOCK_COVERAGE > 0, @src(), "MUTEX_BLOCK_COVERAGE must be larger than 0", .{});
    return struct {
        const Self = @This();

        var vals: [*]ELEM = Utils.invalid_ptr_many(ELEM);
        var vals_to_maps: [*]IDX = Utils.invalid_ptr_many(IDX);
        var maps: [*]Mapping = Utils.invalid_ptr_many(Mapping);
        var block_locks: if (BLOCK_LOCK) [*]RwLock else void = if (BLOCK_LOCK) Utils.invalid_ptr_many(RwLock) else {};
        var vals_len: IDX = 0;
        var maps_len: IDX = 0;
        var capacity: IDX = 0;
        var alloc: Allocator = DummyAlloc.allocator_panic_free_noop;
        var num_free_in_list: IDX = 0;
        var first_free_mapping: IDX = INVALID_IDX;
        var growth_rate: Growth = .GROW_BY_25_PERCENT;
        var maximum_grow: IDX = @min(4096, math.maxInt(IDX));
        var master_lock: if (MASTER_LOCK) RwLock else void = if (MASTER_LOCK) RwLock.init else {};
        var io: if (NEED_IO) Io else void = if (NEED_IO) undefined else {};

        pub const POOL_DEF = DEF;
        pub const ELEM = DEF.ELEM;
        pub const IDX = DEF.IDX;
        const MUTEX = DEF.MUTEX_MODE;
        const MUTEX_BLOCK_LEN = DEF.MUTEX_BLOCK_COVERAGE;
        const MASTER_LOCK = MUTEX == .MASTER_MUTEX or MUTEX == .MASTER_AND_BLOCK_MUTEX;
        const BLOCK_LOCK = MUTEX == .MASTER_AND_BLOCK_MUTEX;
        const NEED_IO = MASTER_LOCK;

        const INVALID_IDX = math.maxInt(IDX);
        const FREE_USED_BIT: IDX = 0b1;
        const FREE_STATE: IDX = 0b0;
        const USED_STATE: IDX = 0b1;

        inline fn mutex_block_idx(idx: IDX) IDX {
            return idx / MUTEX_BLOCK_LEN;
        }

        fn lock_pool_and_index_for_read(idx: IDX) if (BLOCK_LOCK) *RwLock else void {
            var mapping_lock: if (BLOCK_LOCK) *RwLock else void = if (comptime BLOCK_LOCK) undefined else {};
            if (comptime MASTER_LOCK) {
                master_lock.lockSharedUncancelable(io);
                if (comptime BLOCK_LOCK) {
                    const block_lock_idx = mutex_block_idx(idx);
                    mapping_lock = &block_locks[block_lock_idx];
                    mapping_lock.lockSharedUncancelable(io);
                }
            }
            return mapping_lock;
        }
        fn unlock_pool_and_index_for_read(mapping_lock: if (BLOCK_LOCK) *RwLock else void) void {
            if (comptime MASTER_LOCK) {
                if (comptime BLOCK_LOCK) {
                    mapping_lock.unlockShared(io);
                }
                master_lock.unlockShared(io);
            }
        }
        fn lock_pool_and_index_for_write(idx: IDX) if (BLOCK_LOCK) *RwLock else void {
            var mapping_lock: if (BLOCK_LOCK) *RwLock else void = if (comptime BLOCK_LOCK) undefined else {};
            if (comptime MASTER_LOCK) {
                master_lock.lockUncancelable(io);
                if (comptime BLOCK_LOCK) {
                    const block_lock_idx = mutex_block_idx(idx);
                    mapping_lock = &block_locks[block_lock_idx];
                    mapping_lock.lockUncancelable(io);
                }
            }
            return mapping_lock;
        }
        fn unlock_pool_and_index_for_write(mapping_lock: if (BLOCK_LOCK) *RwLock else void) void {
            if (comptime MASTER_LOCK) {
                if (comptime BLOCK_LOCK) {
                    mapping_lock.unlock(io);
                }
                master_lock.unlock(io);
            }
        }
        fn lock_pool_for_read_and_index_for_write(idx: IDX) if (BLOCK_LOCK) *RwLock else void {
            var mapping_lock: if (BLOCK_LOCK) *RwLock else void = if (comptime BLOCK_LOCK) undefined else {};
            if (comptime MASTER_LOCK) {
                if (comptime BLOCK_LOCK) {
                    master_lock.lockSharedUncancelable(io);
                    const block_lock_idx = mutex_block_idx(idx);
                    mapping_lock = &block_locks[block_lock_idx];
                    mapping_lock.lockUncancelable(io);
                } else {
                    master_lock.lockUncancelable(io);
                }
            }
            return mapping_lock;
        }
        fn unlock_pool_for_read_and_index_for_write(mapping_lock: if (BLOCK_LOCK) *RwLock else void) void {
            if (comptime MASTER_LOCK) {
                if (comptime BLOCK_LOCK) {
                    mapping_lock.unlock(io);
                    master_lock.unlockShared(io);
                } else {
                    master_lock.unlock(io);
                }
            }
        }
        fn lock_pool_for_write() void {
            if (comptime MASTER_LOCK) {
                master_lock.lockUncancelable(io);
            }
        }
        fn unlock_pool_for_write() void {
            if (comptime MASTER_LOCK) {
                master_lock.unlock(io);
            }
        }
        fn lock_index_for_write(idx: IDX) if (BLOCK_LOCK) *RwLock else void {
            var mapping_lock: if (BLOCK_LOCK) *RwLock else void = if (comptime BLOCK_LOCK) undefined else {};
            if (comptime BLOCK_LOCK) {
                const block_lock_idx = mutex_block_idx(idx);
                mapping_lock = &block_locks[block_lock_idx];
                mapping_lock.lockUncancelable(io);
            }
            return mapping_lock;
        }
        fn unlock_index_for_write(mapping_lock: if (BLOCK_LOCK) *RwLock else void) void {
            if (comptime BLOCK_LOCK) {
                mapping_lock.unlock(io);
            }
        }

        pub const Mapping = struct {
            idx: IDX = INVALID_IDX,
            gen: IDX = 0,
        };

        pub const Key = struct {
            idx: IDX = INVALID_IDX,
            gen: IDX = 0,

            inline fn assert_lockable_idx(self: Key, comptime src: ?std.builtin.SourceLocation) void {
                assert_with_reason(self.idx < capacity, src, "key index ({d}) is outside the pool capacity ({d})", .{ self.idx, capacity });
            }
            pub fn get(self: Key) ELEM {
                self.assert_lockable_idx(@src());
                const mapping_lock = lock_pool_and_index_for_read(self.idx);
                self.assert_valid_internal(@src());
                const val = vals[maps[self.idx].idx];
                unlock_pool_and_index_for_read(mapping_lock);
                return val;
            }
            pub fn set(self: Key, val: ELEM) void {
                self.assert_lockable_idx(@src());
                const mapping_lock = lock_pool_for_read_and_index_for_write(self.idx);
                self.assert_valid_internal(@src());
                vals[maps[self.idx].idx] = val;
                unlock_pool_for_read_and_index_for_write(mapping_lock);
            }
            pub fn release(self: Key) void {
                release_key(self);
            }
            pub fn is_valid(self: Key) bool {
                if (self.idx >= capacity) return false;
                const mapping_lock = lock_pool_and_index_for_read(self.idx);
                const result = self.idx < maps_len and maps[self.idx].gen == self.gen and maps[self.idx].gen & FREE_USED_BIT == USED_STATE and maps[self.idx].idx < vals_len;
                unlock_pool_and_index_for_read(mapping_lock);
                return result;
            }
            inline fn assert_valid_internal(self: Key, comptime src: ?std.builtin.SourceLocation) void {
                assert_with_reason(self.idx < maps_len, src, "key points to mapping beyond mapping len ({d} >= len {d})", .{ self.idx, maps_len });
                assert_with_reason(maps[self.idx].gen == self.gen, src, "key generation does not match mapping generation ({d} != {d})", .{ maps[self.idx].gen, self.gen });
                assert_with_reason(maps[self.idx].gen & FREE_USED_BIT == USED_STATE, src, "key generation is not in a used state", .{});
                assert_with_reason(maps[self.idx].idx < vals_len, src, "key points to mapping that points to value index beyond values len ({d} >= len {d})", .{ maps[self.idx].idx, vals_len });
            }
            pub inline fn assert_valid(self: Key, comptime src: ?std.builtin.SourceLocation) void {
                self.assert_lockable_idx(src);
                const mapping_lock = lock_pool_and_index_for_read(self.idx);
                assert_with_reason(self.idx < maps_len, src, "key points to mapping beyond mapping len ({d} >= len {d})", .{ self.idx, maps_len });
                assert_with_reason(maps[self.idx].gen == self.gen, src, "key generation does not match mapping generation ({d} != {d})", .{ maps[self.idx].gen, self.gen });
                assert_with_reason(maps[self.idx].gen & FREE_USED_BIT == USED_STATE, src, "key generation is not in a used state", .{});
                assert_with_reason(maps[self.idx].idx < vals_len, src, "key points to mapping that points to value index beyond values len ({d} >= len {d})", .{ maps[self.idx].idx, vals_len });
                unlock_pool_and_index_for_read(mapping_lock);
            }
        };

        fn ensure_capacity_internal(cap_needed: IDX) void {
            if (capacity < cap_needed) {
                const growth_delta = growth_rate.calc(capacity) -| capacity;
                const new_cap = @max(capacity +| @min(growth_delta, maximum_grow), cap_needed);
                const new_vals: []ELEM = alloc.realloc(vals[0..capacity], new_cap) catch |e| assert_allocation_failure(@src(), ELEM, new_cap, e);
                vals = new_vals.ptr;
                const new_vals_to_maps: []IDX = alloc.realloc(vals_to_maps[0..capacity], new_cap) catch |e| assert_allocation_failure(@src(), IDX, new_cap, e);
                vals_to_maps = new_vals_to_maps.ptr;
                const new_maps: []Mapping = alloc.realloc(maps[0..capacity], new_cap) catch |e| assert_allocation_failure(@src(), Mapping, new_cap, e);
                maps = new_maps.ptr;
                @memset(new_maps[capacity..new_cap], Mapping{});
                if (comptime BLOCK_LOCK) {
                    const new_block_cap = @divCeil(new_cap, MUTEX_BLOCK_LEN);
                    const old_block_cap = @divCeil(capacity, MUTEX_BLOCK_LEN);
                    const new_blocks: []RwLock = alloc.realloc(block_locks[0..old_block_cap], new_block_cap) catch |e| assert_allocation_failure(@src(), RwLock, new_block_cap, e);
                    block_locks = new_blocks.ptr;
                    @memset(new_blocks[old_block_cap..new_block_cap], RwLock.init);
                }
                capacity = new_cap;
            }
        }

        inline fn ensure_free_space_internal(needed_free_space: IDX) void {
            assert_with_reason(INVALID_IDX - needed_free_space >= vals_len, @src(), "{d} more items would overflow length integer, current len {d}, max len {d}", .{ needed_free_space, vals_len, INVALID_IDX });
            const needed_cap = needed_free_space + vals_len;
            ensure_capacity_internal(needed_cap);
        }

        pub inline fn ensure_capacity(cap_needed: IDX) void {
            lock_pool_for_write();
            ensure_capacity_internal(cap_needed);
            unlock_pool_for_write();
        }

        pub inline fn ensure_free_space(needed_free_space: IDX) void {
            lock_pool_for_write();
            assert_with_reason(INVALID_IDX - needed_free_space >= vals_len, @src(), "{d} more items would overflow length integer, current len {d}, max len {d}", .{ needed_free_space, vals_len, INVALID_IDX });
            const needed_cap = needed_free_space + vals_len;
            ensure_capacity_internal(needed_cap);
            unlock_pool_for_write();
        }

        pub fn init(init_capacity: IDX, allocator: Allocator, init_io: if (NEED_IO) Io else void) void {
            if (comptime NEED_IO) {
                io = init_io;
            }
            lock_pool_for_write();
            assert_with_reason(capacity == 0, @src(), "cannot be initialized when capacity is not 0", .{});
            vals_len = 0;
            maps_len = 0;
            alloc = allocator;
            num_free_in_list = 0;
            first_free_mapping = INVALID_IDX;
            ensure_capacity_internal(init_capacity);
            unlock_pool_for_write();
        }

        pub fn uninit() void {
            lock_pool_for_write();
            if (capacity > 0) {
                alloc.free(vals[0..capacity]);
                alloc.free(vals_to_maps[0..capacity]);
                alloc.free(maps[0..capacity]);
                if (comptime BLOCK_LOCK) {
                    alloc.free(block_locks[0..@divCeil(capacity, MUTEX_BLOCK_LEN)]);
                }
            }
            vals = Utils.invalid_ptr_many(ELEM);
            vals_to_maps = Utils.invalid_ptr_many(IDX);
            maps = Utils.invalid_ptr_many(Mapping);
            if (comptime BLOCK_LOCK) {
                block_locks = Utils.invalid_ptr_many(RwLock);
            }
            vals_len = 0;
            maps_len = 0;
            capacity = 0;
            num_free_in_list = 0;
            first_free_mapping = INVALID_IDX;
            unlock_pool_for_write();
        }

        pub fn claim_key() Key {
            lock_pool_for_write();
            ensure_free_space_internal(1);
            var map_idx: IDX = INVALID_IDX;
            var mapping_lock: if (BLOCK_LOCK) *RwLock else void = if (comptime BLOCK_LOCK) undefined else {};
            if (num_free_in_list > 0) {
                map_idx = first_free_mapping;
                assert_with_reason(map_idx < maps_len, @src(), "a mapping index was in the free list that is outside the range of the maps len ({d} >= {d})", .{ map_idx, maps_len });
                mapping_lock = lock_index_for_write(map_idx);
                first_free_mapping = maps[map_idx].idx;
                num_free_in_list -= 1;
            } else {
                assert_with_reason(maps_len < capacity, @src(), "ensure_free_space failed to ensure space for new mapping, num_free_in_list == 0 and maps_len = {d} and capacity = {d}", .{ maps_len, capacity });
                map_idx = maps_len;
                mapping_lock = lock_index_for_write(map_idx);
                maps_len += 1;
            }
            const val_idx = vals_len;
            vals_len += 1;
            maps[map_idx].idx = val_idx;
            // Generation is increased on claim AND free
            assert_with_reason(maps[map_idx].gen & FREE_USED_BIT == FREE_STATE, @src(), "mapping was not in a free state", .{});
            maps[map_idx].gen +%= 1;
            const gen = maps[map_idx].gen;
            vals_to_maps[val_idx] = map_idx;
            unlock_index_for_write(mapping_lock);
            unlock_pool_for_write();
            return Key{
                .idx = map_idx,
                .gen = gen,
            };
        }
        pub fn release_key(key: Key) void {
            key.assert_lockable_idx(@src());
            const mapping_lock = lock_pool_and_index_for_write(key.idx);
            key.assert_valid_internal(@src());
            const val_idx = maps[key.idx].idx;
            const last_val_idx = vals_len - 1;
            if (val_idx < last_val_idx) {
                const moved_map_idx = vals_to_maps[last_val_idx];
                vals[val_idx] = vals[last_val_idx];
                maps[moved_map_idx].idx = val_idx;
                vals_to_maps[val_idx] = moved_map_idx;
            }
            vals_len -= 1;
            // Generation is increased on claim AND free
            maps[key.idx].gen +%= 1;
            maps[key.idx].idx = first_free_mapping;
            first_free_mapping = key.idx;
            num_free_in_list += 1;
            unlock_pool_and_index_for_write(mapping_lock);
        }
    };
}
