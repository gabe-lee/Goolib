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

pub fn GlobalSlotMapPool(comptime DEF: PoolDef) type {
    assert_with_reason(Types.type_is_unsigned_int(DEF.IDX), @src(), "type `IDX` must be an unsigned integer type, got type `{s}`", .{@typeName(DEF.IDX)});
    return struct {
        const Self = @This();

        var vals: [*]ELEM = undefined;
        var vals_to_slots: RevLookupPtr = REV_LOOKUP_PTR_DEFAULT;
        var vals_len: IDX = 0;
        var vals_cap: IDX = 0;
        var slots: [*]Mapping = undefined;
        var slots_len: IDX = 0;
        var slots_cap: IDX = 0;
        var alloc: Allocator = DummyAlloc.allocator_panic_free_noop;

        pub const POOL_DEF = DEF;
        pub const ELEM = DEF.ELEM;
        pub const IDX = DEF.IDX;
        const MUTEX = DEF.MUTEX_MODE;
        const MUTEX_BLOCK_LEN = DEF.MUTEX_BLOCK_COVERAGE;
        const MASTER_LOCK = MUTEX == .MASTER_MUTEX or MUTEX == .MASTER_AND_BLOCK_MUTEX;
        const BLOCK_LOCK = MUTEX == .MASTER_AND_BLOCK_MUTEX;
        const HAS_REVERSE = DEF.REVERSE_LOOKUP != .NO_REVERSE_LOOKUP;

        const INVALID_IDX = math.maxInt(IDX);

        pub const Mapping = struct {
            idx: IDX = INVALID_IDX,
            gen: IDX = 0,
        };
        pub const Key = struct {
            idx: IDX = INVALID_IDX,
            gen: IDX = 0,

            pub fn get(self: Key) ELEM {}
            pub fn get_ptr(self: Key) *ELEM {}
            pub fn get_const_ptr(self: Key) *const ELEM {}
            pub fn set(self: Key, val: ELEM) void {}
            pub fn release(self: Key) void {}
        };

        pub const RevLookup = switch (DEF.REVERSE_LOOKUP) {
            .NO_REVERSE_LOOKUP => void,
            .ALLOW_REVERSE_LOOKUP => IDX,
        };
        const REV_LOOKUP_DEFAULT: RevLookup = switch (DEF.REVERSE_LOOKUP) {
            .NO_REVERSE_LOOKUP => @as(void, {}),
            .ALLOW_REVERSE_LOOKUP => @as(IDX, INVALID_IDX),
        };
        const RevLookupPtr = switch (DEF.REVERSE_LOOKUP) {
            .NO_REVERSE_LOOKUP => void,
            .ALLOW_REVERSE_LOOKUP => [*]IDX,
        };
        const REV_LOOKUP_PTR_DEFAULT: RevLookupPtr = switch (DEF.REVERSE_LOOKUP) {
            .NO_REVERSE_LOOKUP => @as(void, {}),
            .ALLOW_REVERSE_LOOKUP => @as([*]IDX, undefined),
        };

        pub fn init(init_val_cap: IDX, init_slot_cap: IDX, allocator: Allocator) void {
            assert_with_reason(vals_cap == 0 and slots_cap == 0, @src(), "cannot be initialized when capacity is not 0", .{});
            alloc = allocator;
            if (init_val_cap > 0) {
                const val_mem: []ELEM = allocator.alloc(ELEM, init_val_cap) catch |e| assert_allocation_failure(@src(), ELEM, init_val_cap, e);
                vals = val_mem.ptr;
                vals_cap = @intCast(val_mem.len);
                if (comptime HAS_REVERSE) {
                    const rev_mem: []RevLookup = allocator.alloc(RevLookup, init_val_cap) catch |e| assert_allocation_failure(@src(), RevLookup, init_val_cap, e);
                    vals_to_slots = rev_mem.ptr;
                }
            }
            if (init_slot_cap > 0) {
                const slot_mem: []Mapping = allocator.alloc(Mapping, init_slot_cap) catch |e| assert_allocation_failure(@src(), Mapping, init_slot_cap, e);
                slots = slot_mem.ptr;
                slots_cap = @intCast(slot_mem.len);
            }
        }
        pub fn uninit() void {
            if (vals_cap > 0) {
                alloc.free(vals[0..vals_cap]);
                if (comptime HAS_REVERSE) {
                    alloc.free(vals_to_slots[0..vals_cap]);
                }
            }
            if (slots_cap > 0) {
                alloc.free(Self.slots[0..slots_cap]);
            }
            vals = undefined;
            vals_to_slots = REV_LOOKUP_PTR_DEFAULT;
            vals_cap = 0;
            vals_len = 0;
            slots = undefined;
            slots_cap = 0;
            slots_len = 0;
        }

        pub fn claim_key() Key {}
        pub fn release_key(key: Key) void {}
    };
}
