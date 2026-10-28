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

const std = @import("std");
const build = @import("builtin");

/// std imports
const Allocator = std.mem.Allocator;
const DEBUG = std.debug.print;
const math = std.math;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Type = Root.Types;
const Math = Root.Math;
const KindInfo = Type.KindInfo;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Common = Root.CommonTypes;
const Test = Root.Testing;
const dummy_alloc = Root.DummyAllocator.allocator_panic_free_noop;
const Random = std.Random;
const Io = std.Io;
const Growth = Common.GrowthModel;
const FuncParamType = Common.FuncParamType;
const ErrorBehavior = Common.ErrorBehavior;
const AllocErr = Utils.Alloc.AllocErr;

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const assert_unreachable_err_always_panic = Assert.assert_unreachable_err_always_panic;
const num_cast = Cast.num_cast;
const real_type_of = Type.real_type_of;
const real_type = Type.real_type;
const real_cast = Cast.real_cast;
const kind_info = KindInfo.get_kind_info;

const GLS = Root.ListSlice;
const ListDef = GLS.ListDef;
const ListFullDefinition = GLS.ListFullDefinition;
const QuicksortSettings = GLS.QuicksortSettings;
const AllocMode = GLS.AllocMode;
const GrowthMode = GLS.GrowthMode;
const ReturnMode = GLS.ReturnMode;
const DeleteMode = GLS.DeleteMode;
const DeleteReturnMode = GLS.DeleteReturnMode;
const FilterMode = GLS.FilterMode;
const TrackMaxStackMode = GLS.TrackMaxStackMode;
const Order = GLS.Order;
const TraverserError = GLS.TraverserError;
const FindOneMode = GLS.FindOneMode;
const FieldLayout = GLS.FieldLayout;

/// A prototype struct for `BackingList`
fn BackingListSlot(comptime KEY: type, comptime VAL: type) type {
    return struct {
        state: CellState,
        key: KEY,
        val: VAL,
    };
}

/// This defines a backing list with a Struct-of-Arrays layout where the `state`, `key`, and `val`
/// fields of the prototype `BackingListSlot(VAL)` struct are all stored in separate contiguous memory regions,
fn BackingList(comptime KEY: type, comptime VAL: type) type {
    return ListFullDefinition(BackingListSlot(KEY, VAL), u64, .SPLIT_FIELDS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
}

pub const DefaultHash = std.hash.Wyhash;

const GetMode = enum {
    VAL,
    PTR,
    PTR_CONST,

    pub fn Type(comptime self: GetMode, comptime opt: OptMode, comptime T: type) type {
        return switch (comptime self) {
            .VAL => switch (comptime opt) {
                .MUST_EXIST => T,
                .OPTIONAL => ?T,
            },
            .PTR => switch (comptime opt) {
                .MUST_EXIST => *T,
                .OPTIONAL => ?*T,
            },
            .PTR_CONST => switch (comptime opt) {
                .MUST_EXIST => *const T,
                .OPTIONAL => ?*const T,
            },
        };
    }
};
const OptMode = enum {
    MUST_EXIST,
    OPTIONAL,
};

pub const Overrides = struct {
    OVERRIDE_MAX_LOAD_PERCENT: ?MaxLoadRational = null,
    OVERRIDE_SIMD_LANE_COUNT: ?comptime_int = null,
};

pub const MaxLoadRational = struct {
    numerator: comptime_int,
    denominator: comptime_int,
};
const CellState = enum(u8) {
    EMPTY = 0b10000000,
    DELETED = 0b11111110,
    _,

    const FILLED_MASK_HI: u64 = 0b01111111;
    const EMPTY_MASK_LO: u8 = 0b10000000;

    inline fn raw(self: CellState) u8 {
        return @backingInt(self);
    }
    inline fn empty() CellState {
        return CellState.EMPTY;
    }
    inline fn deleted() CellState {
        return CellState.DELETED;
    }
    inline fn filled(hash_result: u64) CellState {
        return @fromBackingInt(@as(u8, @truncate(hash_result & FILLED_MASK_HI)));
    }
    inline fn is_filled(self: CellState) bool {
        return (@backingInt(self) & EMPTY_MASK_LO) == 0;
    }
    inline fn is_empty(self: CellState) bool {
        return self == .EMPTY;
    }
    inline fn is_deleted(self: CellState) bool {
        return self == .DELETED;
    }
    inline fn is_empty_or_deleted(self: CellState) bool {
        return (@backingInt(self) & EMPTY_MASK_LO) == EMPTY_MASK_LO;
    }
};

pub fn SwissHashMap(
    comptime KEY: type,
    comptime VAL: type,
    comptime HASH: fn (KEY) u64,
    comptime KEYS_EQUAL: fn (KEY, KEY) bool,
    comptime OVERRIDES: Overrides,
) type {
    if (comptime OVERRIDES.OVERRIDE_MAX_LOAD_PERCENT) |MAX| {
        assert_with_reason(MAX.denominator > 0 and MAX.numerator > 0 and MAX.numerator <= MAX.denominator, @src(), "when overloading the max load values, `denominator` must be greater than 0, `numerator` must be greater than 0, and `numerator` must be <= `denominator`, got `{d}/{d}`", .{ MAX.numerator, MAX.denominator });
    }
    return struct {
        const Self = @This();

        val_list: [*]VAL = undefined,
        state_list: [*]CellState = undefined,
        keys_list: [*]KEY = undefined,
        len: u64 = 0,
        cap: u64 = 0,
        mask: u64 = 0,
        dead: u64 = 0,

        pub const SIMD_SIZE: comptime_int = @max(1, @min(64, if (OVERRIDES.OVERRIDE_SIMD_LANE_COUNT) |CNT| round_pow_2: {
            var out: comptime_int = @max(1, CNT);
            out -= 1;
            out |= out >> 1;
            out |= out >> 2;
            out |= out >> 4;
            out |= out >> 8;
            out |= out >> 16;
            out |= out >> 32;
            out += 1;
            break :round_pow_2 out;
        } else std.simd.suggestVectorLength(u8) orelse 1));
        pub const MAX_LOAD = if (OVERRIDES.OVERRIDE_MAX_LOAD_PERCENT) |MAX| MAX else MaxLoadRational{
            .numerator = 14,
            .denominator = 16,
        };
        const StateVector = @Vector(SIMD_SIZE, u8);
        const BoolVector = @Vector(SIMD_SIZE, bool);
        const EMPTY_STATE_VECTOR: StateVector = @splat(@backingInt(CellState.EMPTY));
        const DELETED_STATE_VECTOR: StateVector = @splat(@backingInt(CellState.DELETED));
        const BoolVectorInt = @Int(.unsigned, SIMD_SIZE);
        const INVALID_IDX = math.maxInt(u64);
        const List = BackingList(KEY, VAL);
        pub const HashParts = struct {
            code: u64,
            state: CellState,
        };
        inline fn h1(key_hash: u64) u64 {
            return key_hash >> 7;
        }
        inline fn h2(key_hash: u64) CellState {
            return CellState.filled(key_hash);
        }
        inline fn h1_h2(key_hash: u64) struct { u64, CellState } {
            return .{ h1(key_hash), CellState.filled(key_hash) };
        }
        pub inline fn hash(key: KEY) u64 {
            return HASH(key);
        }
        pub inline fn hash_parts(key: KEY) HashParts {
            const hash_ = HASH(key);
            return HashParts{
                .code = h1(hash_),
                .state = h2(hash_),
            };
        }
        pub inline fn hash_to_parts(hash_: u64) HashParts {
            return HashParts{
                .code = h1(hash_),
                .state = h2(hash_),
            };
        }
        pub inline fn keys_equal(key_a: KEY, key_b: KEY) bool {
            return KEYS_EQUAL(key_a, key_b);
        }

        inline fn set_cells_empty(self: Self, start: u64, end_exclusive: u64) void {
            @memset(self.state_list[start..end_exclusive], CellState.EMPTY);
        }

        pub fn contains_hash_parts(self: Self, key: KEY, key_hash_parts: HashParts) bool {
            if (self.cap == 0) return false;
            if (comptime SIMD_SIZE > 1) {
                var index: u64 = key_hash_parts.code & self.mask;
                const key_state_vec: StateVector = @splat(key_hash_parts.state.raw());
                while (true) {
                    const stored_state_vec: StateVector = @as(*align(1) const StateVector, @ptrCast(&self.state_list[index])).*;
                    const match_state_vec: BoolVector = stored_state_vec == key_state_vec;
                    var match_state_int: BoolVectorInt = @bitCast(match_state_vec);
                    while (match_state_int != 0) {
                        const lane: u64 = @ctz(match_state_int);
                        const pos: u64 = (index + lane) & self.mask;
                        if (KEYS_EQUAL(key, self.keys_list[pos])) return true;
                        match_state_int &= (match_state_int - 1);
                    }
                    const empty_state_vec: BoolVector = stored_state_vec == EMPTY_STATE_VECTOR;
                    const empty_state_int: BoolVectorInt = @bitCast(empty_state_vec);
                    if (empty_state_int != 0) return false;
                    index = (index + SIMD_SIZE) & self.mask;
                }
            } else {
                var index: u64 = key_hash_parts.code & self.mask;
                while (true) {
                    const stored_state = self.state_list[index];
                    if (stored_state == key_hash_parts.state) {
                        if (KEYS_EQUAL(key, self.keys_list[index])) return true;
                    }
                    if (stored_state.is_empty()) return false;
                    index = (index + 1) & self.mask;
                }
            }
        }
        pub inline fn contains_hash(self: Self, key: KEY, key_hash: u64) bool {
            return self.contains_hash_parts(key, hash_to_parts(key_hash));
        }
        pub inline fn contains(self: Self, key: KEY) bool {
            return self.contains_hash(key, HASH(key));
        }
        fn get_internal(self: Self, key: KEY, key_hash_parts: HashParts, comptime MODE: GetMode, comptime OPT: OptMode) MODE.Type(VAL, OPT) {
            assert_with_reason(self.cap > 0, @src(), "hash map contains 0 items, nothing to get", .{});
            if (comptime SIMD_SIZE > 1) {
                var index: u64 = key_hash_parts.code & self.mask;
                const key_state_vec: StateVector = @splat(key_hash_parts.state.raw());
                while (true) {
                    const stored_state_vec: StateVector = @as(*align(1) const StateVector, @ptrCast(&self.state_list[index])).*;
                    const match_state_vec: BoolVector = stored_state_vec == key_state_vec;
                    var match_state_int: BoolVectorInt = @bitCast(match_state_vec);
                    while (match_state_int != 0) {
                        const lane: u64 = @ctz(match_state_int);
                        const pos: u64 = (index + lane) & self.mask;
                        if (KEYS_EQUAL(key, self.keys_list[pos])) return switch (comptime MODE) {
                            .VAL => self.val_list[pos],
                            .PTR => &self.val_list[pos],
                            .PTR_CONST => &self.val_list[pos],
                        };
                        match_state_int &= (match_state_int - 1);
                    }
                    const empty_state_vec: BoolVector = stored_state_vec == EMPTY_STATE_VECTOR;
                    const empty_state_int: BoolVectorInt = @bitCast(empty_state_vec);
                    if (empty_state_int != 0) {
                        switch (comptime OPT) {
                            .MUST_EXIST => {
                                assert_unreachable(@src(), "key not contained in hash map", .{});
                                return undefined;
                            },
                            .OPTIONAL => {
                                return null;
                            },
                        }
                    }
                    index = (index + SIMD_SIZE) & self.mask;
                }
            } else {
                var index: u64 = key_hash_parts.code & self.mask;
                while (true) {
                    const stored_state = self.state_list[index];
                    if (stored_state == key_hash_parts.state) {
                        if (KEYS_EQUAL(key, self.keys_list[index])) switch (comptime MODE) {
                            .VAL => self.val_list[index],
                            .PTR => &self.val_list[index],
                            .PTR_CONST => &self.val_list[index],
                        };
                    }
                    if (stored_state.is_empty()) {
                        switch (comptime OPT) {
                            .MUST_EXIST => {
                                assert_unreachable(@src(), "key not contained in hash map", .{});
                                return undefined;
                            },
                            .OPTIONAL => {
                                return null;
                            },
                        }
                    }
                    index = (index + 1) & self.mask;
                }
            }
        }
        pub fn get_key_hash_parts(self: Self, key: KEY, key_hash_parts: HashParts) VAL {
            return self.get_internal(key, key_hash_parts, .VAL, .MUST_EXIST);
        }
        pub fn get_key_hash(self: Self, key: KEY, key_hash: u64) VAL {
            const parts = hash_to_parts(key_hash);
            return self.get_internal(key, parts, .VAL, .MUST_EXIST);
        }
        pub fn get(self: Self, key: KEY) VAL {
            const parts = hash_parts(key);
            return self.get_internal(key, parts, .VAL, .MUST_EXIST);
        }
        pub fn get_if_exists_key_hash_parts(self: Self, key: KEY, key_hash_parts: HashParts) ?VAL {
            return self.get_internal(key, key_hash_parts, .VAL, .OPTIONAL);
        }
        pub fn get_if_exists_key_hash(self: Self, key: KEY, key_hash: u64) ?VAL {
            const parts = hash_to_parts(key_hash);
            return self.get_internal(key, parts, .VAL, .OPTIONAL);
        }
        pub fn get_if_exists(self: Self, key: KEY) ?VAL {
            const parts = hash_parts(key);
            return self.get_internal(key, parts, .VAL, .OPTIONAL);
        }
        pub fn get_ptr_key_hash_parts(self: Self, key: KEY, key_hash_parts: HashParts) *VAL {
            return self.get_internal(key, key_hash_parts, .PTR, .MUST_EXIST);
        }
        pub fn get_ptr_key_hash(self: Self, key: KEY, key_hash: u64) *VAL {
            const parts = hash_to_parts(key_hash);
            return self.get_internal(key, parts, .PTR, .MUST_EXIST);
        }
        pub fn get_ptr(self: Self, key: KEY) *VAL {
            const parts = hash_parts(key);
            return self.get_internal(key, parts, .PTR, .MUST_EXIST);
        }
        pub fn get_ptr_if_exists_key_hash_parts(self: Self, key: KEY, key_hash_parts: HashParts) ?*VAL {
            return self.get_internal(key, key_hash_parts, .PTR, .OPTIONAL);
        }
        pub fn get_ptr_if_exists_key_hash(self: Self, key: KEY, key_hash: u64) ?*VAL {
            const parts = hash_to_parts(key_hash);
            return self.get_internal(key, parts, .PTR, .OPTIONAL);
        }
        pub fn get_ptr_if_exists(self: Self, key: KEY) ?*VAL {
            const parts = hash_parts(key);
            return self.get_internal(key, parts, .PTR, .OPTIONAL);
        }
        pub fn get_ptr_const_key_hash_parts(self: Self, key: KEY, key_hash_parts: HashParts) *const VAL {
            return self.get_internal(key, key_hash_parts, .PTR_CONST, .MUST_EXIST);
        }
        pub fn get_ptr_const_key_hash(self: Self, key: KEY, key_hash: u64) *const VAL {
            const parts = hash_to_parts(key_hash);
            return self.get_internal(key, parts, .PTR_CONST, .MUST_EXIST);
        }
        pub fn get_ptr_const(self: Self, key: KEY) *const VAL {
            const parts = hash_parts(key);
            return self.get_internal(key, parts, .PTR_CONST, .MUST_EXIST);
        }
        pub fn get_ptr_const_if_exists_key_hash_parts(self: Self, key: KEY, key_hash_parts: HashParts) ?*const VAL {
            return self.get_internal(key, key_hash_parts, .PTR_CONST, .OPTIONAL);
        }
        pub fn get_ptr_const_if_exists_key_hash(self: Self, key: KEY, key_hash: u64) ?*const VAL {
            const parts = hash_to_parts(key_hash);
            return self.get_internal(key, parts, .PTR_CONST, .OPTIONAL);
        }
        pub fn get_ptr_const_if_exists(self: Self, key: KEY) ?*const VAL {
            const parts = hash_parts(key);
            return self.get_internal(key, parts, .PTR_CONST, .OPTIONAL);
        }

        fn set_state(self: Self, index: u64, state: CellState) void {
            if (comptime SIMD_SIZE > 1) {
                const mirrored_index = ((index -% SIMD_SIZE) & self.mask) + SIMD_SIZE;
                self.state_list[index] = state;
                self.state_list[mirrored_index] = state;
            } else {
                self.state_list[index] = state;
            }
        }

        fn pow2_ceil(value: u64) u64 {
            var out = value - 1;
            out |= out >> 1;
            out |= out >> 2;
            out |= out >> 4;
            out |= out >> 8;
            out |= out >> 16;
            out |= out >> 32;
            return out + 1;
        }

        fn grow_internal(self: *Self, min_slots: u64, alloc: Allocator) void {
            var new_cap: u64 = pow2_ceil(@max(SIMD_SIZE, self.cap << 1));
            while ((new_cap * MAX_LOAD.numerator) / MAX_LOAD.denominator <= min_slots) {
                new_cap <<= 1;
            }
            const new_state_cap = new_cap + SIMD_SIZE;
            const old_vals = self.val_list;
            const old_keys = self.keys_list;
            const old_states = self.state_list;
            const old_cap = self.cap;
            const old_state_cap = self.cap + SIMD_SIZE;
            self.val_list = (alloc.alloc(VAL, new_cap) catch |e| assert_unreachable_err(@src(), e)).ptr;
            self.keys_list = (alloc.alloc(KEY, new_cap) catch |e| assert_unreachable_err(@src(), e)).ptr;
            self.state_list = (alloc.alloc(CellState, new_state_cap) catch |e| assert_unreachable_err(@src(), e)).ptr;
            self.cap = new_cap;
            self.mask = new_cap - 1;
            self.len = 0;
            self.dead = 0;
            self.set_cells_empty(0, new_state_cap);
            var old_idx: u64 = 0;
            while (old_idx < old_cap) : (old_idx += 1) {
                const old_state: CellState = old_states[old_idx];
                if (old_state.is_filled()) {
                    self.insert_remap(old_keys[old_idx], old_vals[old_idx]);
                }
            }
            if (old_cap != 0) {
                alloc.free(old_vals[0..old_cap]);
                alloc.free(old_keys[0..old_cap]);
                alloc.free(old_states[0..old_state_cap]);
            }
        }

        pub inline fn grow(self: *Self, min_capacity: u64, alloc: Allocator) void {
            if (self.cap < min_capacity) {
                return self.grow_internal(min_capacity, alloc);
            }
        }

        fn insert_remap(self: *Self, key: KEY, val: VAL) void {
            const key_hash_parts: HashParts = hash_parts(key);
            if (comptime SIMD_SIZE > 1) {
                var index = key_hash_parts.code & self.mask;
                while (true) {
                    const stored_state_vec: StateVector = @as(*align(1) const StateVector, @ptrCast(&self.state_list[index])).*;

                    const empty_state_vec: BoolVector = stored_state_vec == EMPTY_STATE_VECTOR;
                    const empty_state_int: BoolVectorInt = @bitCast(empty_state_vec);

                    if (empty_state_int != 0) {
                        const lane = @ctz(empty_state_int);
                        const true_index = (index + lane) & self.mask;

                        self.set_state(true_index, key_hash_parts.state);
                        self.keys_list[true_index] = key;
                        self.val_list[true_index] = val;
                        self.len += 1;
                        return;
                    }
                    index = (index + SIMD_SIZE) & self.mask;
                }
            } else {
                var index: u64 = key_hash_parts.code & self.mask;
                while (true) {
                    const stored_state = self.state_list[index];
                    if (stored_state.is_empty()) {
                        self.keys_list[index] = key;
                        self.set_state(index, key_hash_parts.state);
                        self.val_list[index] = val;
                        self.len += 1;
                        return;
                    }
                    index = (index + 1) & self.mask;
                }
            }
        }

        pub fn insert_key_hash_parts_get_idx_assume_cap(self: *Self, key: KEY, key_hash_parts: HashParts) u64 {
            if (comptime SIMD_SIZE > 1) {
                var index = key_hash_parts.code & self.mask;
                var first_deleted: u64 = INVALID_IDX;
                const key_state_vec: StateVector = @splat(key_hash_parts.state.raw());
                while (true) {
                    const stored_state_vec: StateVector = @as(*align(1) const StateVector, @ptrCast(&self.state_list[index])).*;
                    const match_state_vec: BoolVector = stored_state_vec == key_state_vec;
                    var match_state_int: BoolVectorInt = @bitCast(match_state_vec);
                    while (match_state_int != 0) {
                        const lane: u64 = @ctz(match_state_int);
                        const true_index: u64 = (index + lane) & self.mask;
                        if (KEYS_EQUAL(key, self.keys_list[true_index])) {
                            return true_index;
                        }
                        match_state_int &= (match_state_int - 1);
                    }
                    const empty_state_vec: BoolVector = stored_state_vec == EMPTY_STATE_VECTOR;
                    const empty_state_int: BoolVectorInt = @bitCast(empty_state_vec);
                    const deleted_state_vec: BoolVector = stored_state_vec == DELETED_STATE_VECTOR;
                    const deleted_state_int: BoolVectorInt = @bitCast(deleted_state_vec);

                    if (empty_state_int != 0) {
                        var target_index = first_deleted;
                        if (target_index == INVALID_IDX) {
                            const avail_state_int: BoolVectorInt = empty_state_int | deleted_state_int;
                            const lane = @ctz(avail_state_int);
                            target_index = (index + lane) & self.mask;
                        }

                        if (self.state_list[target_index].is_deleted()) {
                            self.dead -= 1;
                        }
                        self.set_state(target_index, key_hash_parts.state);
                        self.keys_list[target_index] = key;
                        self.len += 1;
                        return target_index;
                    }
                    if (first_deleted == INVALID_IDX and deleted_state_int != 0) {
                        const lane = @ctz(deleted_state_int);
                        first_deleted = (index + lane) & self.mask;
                    }

                    index = (index + SIMD_SIZE) & self.mask;
                }
            } else {
                var index: u64 = key_hash_parts.code & self.mask;
                var first_deleted: u64 = INVALID_IDX;
                while (true) {
                    const stored_state = self.state_list[index];
                    if (stored_state == key_hash_parts.state and KEYS_EQUAL(self.keys_list[index], key)) {
                        return index;
                    }
                    if (stored_state.is_deleted()) {
                        if (first_deleted == INVALID_IDX) {
                            first_deleted = index;
                        }
                    }
                    if (stored_state.is_empty()) {
                        const target_index = if (first_deleted != INVALID_IDX) first_deleted else index;
                        self.keys_list[target_index] = key;
                        self.set_state(target_index, key_hash_parts.state);
                        self.len += 1;
                        if (target_index == first_deleted) {
                            self.dead -= 1;
                        }
                        return target_index;
                    }
                    index = (index + 1) & self.mask;
                }
            }
        }
        pub fn insert_key_hash_parts_get_idx(self: *Self, key: KEY, key_hash_parts: HashParts, alloc: Allocator) u64 {
            const len_plus_dead_plus_one = self.len + self.dead + 1;
            if (len_plus_dead_plus_one >= ((self.cap * MAX_LOAD.numerator) / MAX_LOAD.denominator)) {
                self.grow_internal(len_plus_dead_plus_one, alloc);
            }
            return self.insert_key_hash_parts_get_idx_assume_cap(key, key_hash_parts);
        }
        pub inline fn insert_key_hash_get_idx_assume_cap(self: *Self, key: KEY, key_hash: u64) u64 {
            const key_hash_parts = hash_to_parts(key_hash);
            return self.insert_key_hash_parts_get_idx_assume_cap(key, key_hash_parts);
        }
        pub inline fn insert_key_hash_get_idx(self: *Self, key: KEY, key_hash: u64, alloc: Allocator) u64 {
            const key_hash_parts = hash_to_parts(key_hash);
            return self.insert_key_hash_parts_get_idx(key, key_hash_parts, alloc);
        }
        pub inline fn insert_key_get_idx_assume_cap(self: *Self, key: KEY) u64 {
            const key_hash_parts = hash_parts(key);
            return self.insert_key_hash_parts_get_idx_assume_cap(key, key_hash_parts);
        }
        pub inline fn insert_key_get_idx(self: *Self, key: KEY, alloc: Allocator) u64 {
            const key_hash_parts = hash_parts(key);
            return self.insert_key_hash_parts_get_idx(key, key_hash_parts, alloc);
        }
        pub inline fn insert_key_hash_parts_get_ptr_assume_cap(self: *Self, key: KEY, key_hash_parts: HashParts) *VAL {
            return &self.val_list[self.insert_key_hash_parts_get_idx_assume_cap(key, key_hash_parts)];
        }
        pub inline fn insert_key_hash_parts_get_ptr(self: *Self, key: KEY, key_hash_parts: HashParts, alloc: Allocator) *VAL {
            return &self.val_list[self.insert_key_hash_parts_get_idx(key, key_hash_parts, alloc)];
        }
        pub inline fn insert_key_hash_get_ptr_assume_cap(self: *Self, key: KEY, key_hash: u64) *VAL {
            return &self.val_list[self.insert_key_hash_get_idx_assume_cap(key, key_hash)];
        }
        pub inline fn insert_key_hash_get_ptr(self: *Self, key: KEY, key_hash: u64, alloc: Allocator) *VAL {
            return &self.val_list[self.insert_key_hash_get_idx(key, key_hash, alloc)];
        }
        pub inline fn insert_key_get_ptr_assume_cap(self: *Self, key: KEY) *VAL {
            return &self.val_list[self.insert_key_get_idx_assume_cap(key)];
        }
        pub inline fn insert_key_get_ptr(self: *Self, key: KEY, alloc: Allocator) *VAL {
            return &self.val_list[self.insert_key_get_idx(key, alloc)];
        }
        pub inline fn insert_hash_parts_assume_cap(self: *Self, key: KEY, val: VAL, key_hash_parts: HashParts) void {
            const idx = self.insert_key_hash_parts_get_idx_assume_cap(key, key_hash_parts);
            self.val_list[idx] = val;
        }
        pub inline fn insert_hash_parts(self: *Self, key: KEY, val: VAL, key_hash_parts: HashParts, alloc: Allocator) void {
            const idx = self.insert_key_hash_parts_get_idx(key, key_hash_parts, alloc);
            self.val_list[idx] = val;
        }
        pub inline fn insert_hash_assume_cap(self: *Self, key: KEY, val: VAL, key_hash: u64) void {
            const idx = self.insert_key_hash_get_idx_assume_cap(key, key_hash);
            self.val_list[idx] = val;
        }
        pub inline fn insert_hash(self: *Self, key: KEY, val: VAL, key_hash: u64, alloc: Allocator) void {
            const idx = self.insert_key_hash_get_idx(key, key_hash, alloc);
            self.val_list[idx] = val;
        }
        pub inline fn insert_assume_cap(self: *Self, key: KEY, val: VAL) void {
            const idx = self.insert_key_get_idx_assume_cap(key);
            self.val_list[idx] = val;
        }
        pub inline fn insert(self: *Self, key: KEY, val: VAL, alloc: Allocator) void {
            const idx = self.insert_key_get_idx(key, alloc);
            self.val_list[idx] = val;
        }

        pub fn remove_key_hash_parts(self: *Self, key: KEY, key_hash_parts: HashParts) VAL {
            if (self.cap == 0) {
                assert_unreachable(@src(), "key `{}` did not exist in hash map", .{key});
            }
            if (comptime SIMD_SIZE > 1) {
                var index: u64 = key_hash_parts.code & self.mask;
                const key_state_vec: StateVector = @splat(key_hash_parts.state.raw());
                while (true) {
                    const stored_state_vec: StateVector = @as(*align(1) const StateVector, @ptrCast(&self.state_list[index])).*;
                    const match_state_vec: BoolVector = stored_state_vec == key_state_vec;
                    var match_state_int: BoolVectorInt = @bitCast(match_state_vec);
                    while (match_state_int != 0) {
                        const lane: u64 = @ctz(match_state_int);
                        const pos: u64 = (index + lane) & self.mask;
                        if (KEYS_EQUAL(key, self.keys_list[pos])) {
                            self.set_state(pos, .DELETED);
                            self.len -= 1;
                            self.dead += 1;
                            return self.val_list[pos];
                        }
                        match_state_int &= (match_state_int - 1);
                    }
                    const empty_state_vec: BoolVector = stored_state_vec == EMPTY_STATE_VECTOR;
                    const empty_state_int: BoolVectorInt = @bitCast(empty_state_vec);
                    if (empty_state_int != 0) {
                        assert_unreachable(@src(), "key `{}` did not exist in hash map", .{key});
                    }

                    index = (index + SIMD_SIZE) & self.mask;
                }
            } else {
                var index: u64 = key_hash_parts.code & self.mask;
                while (true) {
                    const stored_state: CellState = self.state_list[index];
                    if (stored_state.is_empty()) {
                        assert_unreachable(@src(), "key `{}` did not exist in hash map", .{key});
                    }
                    if (stored_state == key_hash_parts.state and KEYS_EQUAL(self.keys_list[index], key)) {
                        self.set_state(index, CellState.DELETED);
                        self.len -= 1;
                        self.dead += 1;
                        return self.val_list[index];
                    }
                    index = (index + 1) & self.mask;
                }
            }
        }
        pub inline fn remove_key_hash(self: *Self, key: KEY, key_hash: u64) VAL {
            return self.remove_key_hash_parts(key, hash_to_parts(key_hash));
        }
        pub inline fn remove_key(self: *Self, key: KEY) VAL {
            return self.remove_key_hash_parts(key, hash_parts(key));
        }
        pub fn remove_key_hash_parts_if_exists(self: *Self, key: KEY, key_hash_parts: HashParts) ?VAL {
            if (self.cap == 0) return null;
            if (comptime SIMD_SIZE > 1) {
                var index: u64 = key_hash_parts.code & self.mask;
                const key_state_vec: StateVector = @splat(key_hash_parts.state.raw());
                while (true) {
                    const stored_state_vec: StateVector = @as(*align(1) const StateVector, @ptrCast(&self.state_list[index])).*;
                    const match_state_vec: BoolVector = stored_state_vec == key_state_vec;
                    var match_state_int: BoolVectorInt = @bitCast(match_state_vec);
                    while (match_state_int != 0) {
                        const lane: u64 = @ctz(match_state_int);
                        const pos: u64 = (index + lane) & self.mask;
                        if (KEYS_EQUAL(key, self.keys_list[pos])) {
                            self.set_state(pos, .DELETED);
                            self.len -= 1;
                            self.dead += 1;
                            return self.val_list[pos];
                        }
                        match_state_int &= (match_state_int - 1);
                    }
                    const empty_state_vec: BoolVector = stored_state_vec == EMPTY_STATE_VECTOR;
                    const empty_state_int: BoolVectorInt = @bitCast(empty_state_vec);
                    if (empty_state_int != 0) return null;

                    index = (index + SIMD_SIZE) & self.mask;
                }
            } else {
                var index: u64 = key_hash_parts.code & self.mask;
                while (true) {
                    const stored_state: CellState = self.state_list[index];
                    if (stored_state.is_empty()) return null;
                    if (stored_state == key_hash_parts.state and KEYS_EQUAL(self.keys_list[index], key)) {
                        self.set_state(index, CellState.DELETED);
                        self.len -= 1;
                        self.dead += 1;
                        return self.val_list[index];
                    }
                    index = (index + 1) & self.mask;
                }
            }
        }
        pub inline fn remove_key_hash_if_exists(self: *Self, key: KEY, key_hash: u64) ?VAL {
            return self.remove_key_hash_parts_if_exists(key, hash_to_parts(key_hash));
        }
        pub inline fn remove_key_if_exists(self: *Self, key: KEY) ?VAL {
            return self.remove_key_hash_parts_if_exists(key, hash_parts(key));
        }
        pub inline fn delete_key_hash_parts(self: *Self, key: KEY, key_hash_parts: HashParts) void {
            _ = self.remove_key_hash_parts(key, key_hash_parts);
        }
        pub inline fn delete_key_hash(self: *Self, key: KEY, key_hash: u64) void {
            _ = self.remove_key_hash(key, key_hash);
        }
        pub inline fn delete_key(self: *Self, key: KEY) void {
            _ = self.remove_key(key);
        }
        pub inline fn delete_key_hash_parts_report_existed(self: *Self, key: KEY, key_hash_parts: HashParts) bool {
            return self.remove_key_hash_parts_if_exists(key, key_hash_parts) != null;
        }
        pub inline fn delete_key_hash_report_existed(self: *Self, key: KEY, key_hash: u64) bool {
            return self.remove_key_hash_if_exists(key, key_hash) != null;
        }
        pub inline fn delete_key_report_existed(self: *Self, key: KEY) bool {
            return self.remove_key_if_exists(key) != null;
        }

        pub fn deinit(self: *Self, alloc: Allocator) void {
            if (self.cap != 0) {
                alloc.free(self.val_list[0..self.cap]);
                alloc.free(self.keys_list[0..self.cap]);
                alloc.free(self.state_list[0 .. self.cap + SIMD_SIZE]);
            }
            self.* = .{};
        }
    };
}
