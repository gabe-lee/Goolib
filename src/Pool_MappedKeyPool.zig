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

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

pub const MutexMode = enum {
    NO_MUTEXES,
    MASTER_MUTEX,
    MASTER_AND_BLOCK_MUTEX,
};

pub const ReverseLookupMode = enum {
    NO_REVERSE_LOOKUP,
    ALLOW_REVERSE_LOOKUP,
    REVERSE_LOOKUP_FULL_KEY,
};

pub const PoolDef = struct {
    ELEM: type,
    IDX: type,
    MUTEX_MODE: MutexMode,
    MUTEX_BLOCK_COVERAGE: comptime_int = 64,
    REVERSE_LOOKUP: ReverseLookupMode = .NO_REVERSE_LOOKUP,
};

pub fn GlobalMappedKeyPool(comptime DEF: PoolDef) type {
    assert_with_reason(Types.type_is_unsigned_int(DEF.IDX), @src(), "type `IDX` must be an unsigned integer type, got type `{s}`", .{@typeName(DEF.IDX)});
    return struct {
        const Self = @This();

        var vals: [*]ELEM = undefined;
        var vals_to_maps: if (HAS_REVERSE) [*]IDX else void = if (HAS_REVERSE) undefined else {};
        var maps: [*]Mapping = undefined;
        var vals_len: IDX = 0;
        var maps_len: IDX = 0;
        var capacity: IDX = 0;
        var alloc: Allocator = DummyAlloc.allocator_panic_free_noop;
        var num_free_in_list: IDX = 0;
        var first_free_mapping: IDX = INVALID_IDX;
        var growth_rate: Growth = .GROW_BY_25_PERCENT;
        var maximum_grow: IDX = 1024;

        pub const POOL_DEF = DEF;
        pub const ELEM = DEF.ELEM;
        pub const IDX = DEF.IDX;
        const MUTEX = DEF.MUTEX_MODE;
        const MUTEX_BLOCK_LEN = DEF.MUTEX_BLOCK_COVERAGE;
        const MASTER_LOCK = MUTEX == .MASTER_MUTEX or MUTEX == .MASTER_AND_BLOCK_MUTEX;
        const BLOCK_LOCK = MUTEX == .MASTER_AND_BLOCK_MUTEX;
        const HAS_REVERSE = DEF.REVERSE_LOOKUP != .NO_REVERSE_LOOKUP;

        const INVALID_IDX = math.maxInt(IDX);
        const FREE_USED_BIT: IDX = 0b1;
        const FREE_STATE: IDX = 0b0;
        const USED_STATE: IDX = 0b1;

        pub const Mapping = struct {
            idx: IDX = INVALID_IDX,
            gen: IDX = 0,
        };

        pub const Key = struct {
            idx: IDX = INVALID_IDX,
            gen: IDX = 0,

            pub fn get(self: Key) ELEM {
                self.assert_valid(@src());
                return vals[maps[self.idx].idx];
            }
            pub fn set(self: Key, val: ELEM) void {
                self.assert_valid(@src());
                vals[maps[self.idx].idx] = val;
            }
            pub fn release(self: Key) void {
                release_key(self);
            }
            pub fn is_valid(self: Key) bool {
                return self.idx < maps_len and maps[self.idx].gen == self.gen and maps[self.idx].gen & FREE_USED_BIT == USED_STATE and maps[self.idx].idx < vals_len;
            }
            pub inline fn assert_valid(self: Key, comptime src: ?std.builtin.SourceLocation) void {
                assert_with_reason(self.idx < maps_len, src, "key points to mapping beyond mapping len ({d} >= len {d})", .{ self.idx, maps_len });
                assert_with_reason(maps[self.idx].gen == self.gen, src, "key generation does not match mapping generation ({d} != {d})", .{ maps[self.idx].gen, self.gen });
                assert_with_reason(maps[self.idx].gen & FREE_USED_BIT == USED_STATE, src, "key generation is not in a used state", .{});
                assert_with_reason(maps[self.idx].idx < vals_len, src, "key points to mapping that points to value index beyond values len ({d} >= len {d})", .{ maps[self.idx].idx, vals_len });
            }
        };

        pub fn ensure_capacity(cap_needed: IDX) void {
            if (capacity < cap_needed) {
                const new_cap = @max(@min(growth_rate.calc(capacity), maximum_grow), cap_needed);
                const new_vals: []ELEM = alloc.realloc(vals[0..capacity], new_cap) catch |e| assert_allocation_failure(@src(), ELEM, new_cap, e);
                vals = new_vals.ptr;
                if (comptime HAS_REVERSE) {
                    const new_vals_to_slots: []IDX = alloc.realloc(vals_to_maps[0..capacity], new_cap) catch |e| assert_allocation_failure(@src(), IDX, new_cap, e);
                    vals_to_maps = new_vals_to_slots.ptr;
                }
                const new_maps: []Mapping = alloc.realloc(maps[0..capacity], new_cap) catch |e| assert_allocation_failure(@src(), Mapping, new_cap, e);
                maps = new_maps.ptr;
                capacity = @intCast(new_cap);
            }
        }
        pub inline fn ensure_free_space(needed_free_space: IDX) void {
            const needed_cap = needed_free_space + vals_len;
            ensure_capacity(needed_cap);
        }

        pub fn init(init_capacity: IDX, allocator: Allocator) void {
            assert_with_reason(capacity == 0, @src(), "cannot be initialized when capacity is not 0", .{});
            vals_len = 0;
            maps_len = 0;
            alloc = allocator;
            num_free_in_list = 0;
            first_free_mapping = INVALID_IDX;
            ensure_capacity(init_capacity);
        }

        pub fn uninit() void {
            if (capacity > 0) {
                alloc.free(vals[0..capacity]);
                if (comptime HAS_REVERSE) {
                    alloc.free(vals_to_maps[0..capacity]);
                }
                alloc.free(maps[0..capacity]);
            }
            vals = undefined;
            vals_to_maps = if (HAS_REVERSE) undefined else {};
            maps = undefined;
            vals_len = 0;
            maps_len = 0;
            capacity = 0;
            num_free_in_list = 0;
            first_free_mapping = INVALID_IDX;
        }

        pub fn claim_key() Key {
            ensure_free_space(1);
            var map_idx: IDX = INVALID_IDX;
            if (num_free_in_list > 0) {
                map_idx = first_free_mapping;
                assert_with_reason(map_idx < maps_len, @src(), "a mapping index was in the free list that is outside the range of the maps len ({d} >= {d})", .{ map_idx, maps_len });
                first_free_mapping = maps[map_idx].idx;
                num_free_in_list -= 1;
            } else {
                assert_with_reason(maps_len < capacity, @src(), "ensure_free_space failed to ensure space for new mapping, num_free_in_list == 0 and maps_len = {d} and capacity = {d}", .{ maps_len, capacity });
                map_idx = maps_len;
                maps_len += 1;
            }
            const val_idx = vals_len;
            vals_len += 1;
            maps[map_idx].idx = val_idx;
            // Generation is increased on claim AND free
            assert_with_reason(maps[map_idx].gen & FREE_USED_BIT == FREE_STATE, @src(), "mapping was not in a free state", .{});
            maps[map_idx].gen +%= 1;
            const gen = maps[map_idx].gen;
            if (comptime HAS_REVERSE) {
                vals_to_maps[val_idx] = map_idx;
            }
            return Key{
                .idx = map_idx,
                .gen = gen,
            };
        }
        pub fn release_key(key: Key) void {
            key.assert_valid(@src());
            const val_idx = maps[key.idx].idx;
            if (vals_len > 1 and val_idx < vals_len - 1) {
                const last_val = vals[vals_len - 1];
                vals[val_idx] = last_val;
            }
            vals_len -= 1;
            // Generation is increased on claim AND free
            maps[key.idx].gen +%= 1;
            maps[key.idx].idx = first_free_mapping;
            first_free_mapping = key.idx;
            num_free_in_list += 1;
        }
    };
}
