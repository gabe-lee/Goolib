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
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Utils = Root.Utils;

const num_cast = Root.Cast.num_cast;

const List = Root.IList.List;

const TrueIndex = struct {
    block_index: usize = 0,
    bit_offset: math.Log2Int(usize) = 0,
};

pub fn BitList(comptime BITS_PER_INDEX: comptime_int) type {
    Assert.assert_with_reason(BITS_PER_INDEX <= @bitSizeOf(usize), @src(), "`BITS_PER_INDEX` must be less than or equal to the number of bits in a `usize`, got {d} > {d}", .{ BITS_PER_INDEX, @bitSizeOf(usize) });
    return struct {
        const Self = @This();

        list: List(usize) = .{},
        index_len: usize = 0,

        pub const BITS = std.meta.Int(.unsigned, BITS_PER_INDEX);
        const USIZEBITS = @bitSizeOf(usize);
        const EVENLY_DIVISIBLE = USIZEBITS % BITS_PER_INDEX == 0;
        const OFFSHIFT = if (USIZEBITS == 32) 5 else 6;
        const OFFMASK = (1 << OFFSHIFT) - 1;
        const BITMASK = (@as(usize, 1) << BITS_PER_INDEX) - 1;

        pub fn init_capacity(cap: usize, alloc: Allocator) Self {
            const bits_needed = BITS_PER_INDEX * cap;
            const real_cap = std.mem.alignForward(usize, bits_needed, USIZEBITS) >> OFFSHIFT;
            return Self{
                .list = List(usize).init_capacity(real_cap, alloc),
                .index_len = 0,
            };
        }

        fn block_offset(idx: usize) TrueIndex {
            var out: TrueIndex = undefined;
            const bit_idx = idx * BITS_PER_INDEX;
            out.block_index = bit_idx >> OFFSHIFT;
            out.bit_offset = @intCast(bit_idx & OFFMASK);
            return out;
        }

        pub fn get(self: Self, idx: usize) BITS {
            Assert.assert_idx_less_than_len(idx, self.index_len, @src());
            const index = block_offset(idx);
            if (EVENLY_DIVISIBLE) {
                var value = self.list.ptr[index.block_index];
                value >>= index.bit_offset;
                value &= BITMASK;
                return @intCast(value);
            } else {
                var value = self.list.ptr[index.block_index];
                value >>= index.bit_offset;
                var value_2 = self.list.ptr[index.block_index + 1];
                const offset_2: math.Log2Int(usize) = num_cast((USIZEBITS - 1) - num_cast(index.bit_offset, usize), math.Log2Int(usize));
                value_2 <<= offset_2;
                value_2 <<= 1;
                value |= value_2;
                value &= BITMASK;
                return @intCast(value);
            }
        }

        const SetMode = enum(u8) {
            CLEAR_AND_BIT_OR,
            BIT_OR_ONLY,
            CLEAR_ONLY,
        };

        fn set_internal(self: Self, idx: usize, val: BITS, comptime mode: SetMode) void {
            Assert.assert_idx_less_than_len(idx, self.index_len, @src());
            const index = block_offset(idx);
            if (EVENLY_DIVISIBLE) {
                var block = self.list.ptr[index.block_index];
                var value: usize = @intCast(val);
                const mask = BITMASK << index.bit_offset;
                value <<= index.bit_offset;
                if (mode != .BIT_OR_ONLY) {
                    block &= ~mask;
                }
                if (mode != .CLEAR_ONLY) {
                    block |= value;
                }
                self.list.ptr[index.block_index] = block;
            } else {
                var block = self.list.ptr[index.block_index];
                var value: usize = @intCast(val);
                var mask = BITMASK << index.bit_offset;
                value <<= index.bit_offset;
                if (mode != .BIT_OR_ONLY) {
                    block &= ~mask;
                }
                if (mode != .CLEAR_ONLY) {
                    block |= value;
                }
                self.list.ptr[index.block_index] = block;
                const offset_2: math.Log2Int(usize) = num_cast((USIZEBITS - 1) - num_cast(index.bit_offset, usize), math.Log2Int(usize));
                block = self.list.ptr[index.block_index + 1];
                value = @intCast(val);
                mask = BITMASK >> offset_2;
                mask >>= 1;
                value >>= offset_2;
                value >>= 1;
                if (mode != .BIT_OR_ONLY) {
                    block &= ~mask;
                }
                if (mode != .CLEAR_ONLY) {
                    block |= value;
                }
                self.list.ptr[index.block_index + 1] = block;
            }
        }

        pub fn set(self: Self, idx: usize, val: BITS) void {
            self.set_internal(idx, val, .CLEAR_AND_BIT_OR);
        }
        pub fn set_no_clear(self: Self, idx: usize, val: BITS) void {
            self.set_internal(idx, val, .BIT_OR_ONLY);
        }
        pub fn clear(self: Self, idx: usize) void {
            self.set_internal(idx, 0, .CLEAR_ONLY);
        }

        pub fn ensure_capacity_and_zero_new(self: *Self, cap: usize, alloc: Allocator) void {
            const old_cap = self.list.cap;
            const index = block_offset(cap - 1);
            const real_cap = if (EVENLY_DIVISIBLE) index.block_index + 1 else index.block_index + 2;
            self.list.ensure_free_slots(real_cap, alloc);
            const new_cap = self.list.cap;
            @memset(self.list.ptr[old_cap..new_cap], 0);
        }
        pub fn set_len(self: *Self, len: usize, alloc: Allocator) void {
            self.ensure_capacity_and_zero_new(len, alloc);
            self.index_len = len;
        }

        fn find_first_n_consecutive_set_bits_starting_at_internal(self: Self, idx: usize, n: usize, comptime FROM_START: bool, comptime MUST_FIND_AT_INDEX: bool) ?usize {
            Assert.assert_with_reason(BITS_PER_INDEX == 1, @src(), "this function can only be used when `BITS_PER_INDEX == 1,`", .{});
            const start_block: TrueIndex = if (FROM_START) .{} else block_offset(idx);
            var block_idx: usize = if (FROM_START) 0 else start_block.block_index;
            var bits_idx: usize = if (FROM_START) 0 else idx;
            var bits_left: usize = if (FROM_START) undefined else USIZEBITS - num_cast(start_block.bit_offset, usize);
            var consecutive_ones: usize = 0;
            var consecutive_ones_start: usize = if (FROM_START) 0 else idx;
            if (!FROM_START) {
                var block = self.list.ptr[block_idx] >> start_block.bit_offset;
                while (true) {
                    const skip_zeroes: usize = @min(bits_left, num_cast(@ctz(block), usize));
                    bits_idx += skip_zeroes;
                    if (skip_zeroes == bits_left) break;
                    bits_left -= skip_zeroes;
                    block >>= @intCast(skip_zeroes);
                    block = ~block;
                    if (skip_zeroes > 0) {
                        if (MUST_FIND_AT_INDEX) return null;
                        consecutive_ones_start = bits_idx;
                        consecutive_ones = 0;
                    }
                    const next_ones = @min(bits_left, @ctz(block));
                    consecutive_ones += next_ones;
                    bits_idx += next_ones;
                    if (next_ones == bits_left or consecutive_ones >= n) break;
                    bits_left -= next_ones;
                    block >>= @intCast(next_ones);
                    block = ~block;
                }
                if (consecutive_ones >= n) return consecutive_ones_start;
            }
            while (bits_idx < self.index_len) {
                var block = self.list.ptr[block_idx];
                bits_left = @min(USIZEBITS, self.index_len - bits_idx);
                while (true) {
                    const skip_zeroes: usize = @min(bits_left, num_cast(@ctz(block), usize));
                    bits_idx += skip_zeroes;
                    if (skip_zeroes == bits_left) break;
                    bits_left -= skip_zeroes;
                    block >>= @intCast(skip_zeroes);
                    block = ~block;
                    if (skip_zeroes > 0) {
                        if (MUST_FIND_AT_INDEX) return null;
                        consecutive_ones_start = bits_idx;
                        consecutive_ones = 0;
                    }
                    const next_ones = @min(bits_left, @ctz(block));
                    consecutive_ones += next_ones;
                    bits_idx += next_ones;
                    if (next_ones == bits_left or consecutive_ones >= n) break;
                    bits_left -= next_ones;
                    block >>= @intCast(next_ones);
                    block = ~block;
                }
                if (consecutive_ones >= n) return consecutive_ones_start;
                block_idx += 1;
            }
            return null;
        }
        pub fn find_first_n_consecutive_set_bits(self: Self, n: usize) ?usize {
            return self.find_first_n_consecutive_set_bits_starting_at_internal(0, n, true, false);
        }
        pub fn find_first_n_consecutive_set_bits_starting_at(self: Self, idx: usize, n: usize) ?usize {
            return self.find_first_n_consecutive_set_bits_starting_at_internal(idx, n, false, false);
        }
        pub fn idx_has_n_consecutive_set_bits(self: Self, idx: usize, n: usize) bool {
            return self.find_first_n_consecutive_set_bits_starting_at_internal(idx, n, false, true) != null;
        }

        fn find_first_n_consecutive_unset_bits_starting_at_internal(self: Self, idx: usize, n: usize, comptime FROM_START: bool, comptime MUST_FIND_AT_INDEX: bool) ?usize {
            Assert.assert_with_reason(BITS_PER_INDEX == 1, @src(), "this function can only be used when `BITS_PER_INDEX == 1,`", .{});
            const start_block: TrueIndex = if (FROM_START) .{} else block_offset(idx);
            var block_idx: usize = if (FROM_START) 0 else start_block.block_index;
            var bits_idx: usize = if (FROM_START) 0 else idx;
            var bits_left: usize = if (FROM_START) undefined else USIZEBITS - num_cast(start_block.bit_offset, usize);
            var consecutive_zeroes: usize = 0;
            var consecutive_zeroes_start: usize = if (FROM_START) 0 else idx;
            if (!FROM_START) {
                var block = (~self.list.ptr[block_idx]) >> start_block.bit_offset;
                while (true) {
                    const skip_ones: usize = @min(bits_left, num_cast(@ctz(block), usize));
                    bits_idx += skip_ones;
                    if (skip_ones == bits_left) break;
                    bits_left -= skip_ones;
                    block >>= @intCast(skip_ones);
                    block = ~block;
                    if (skip_ones > 0) {
                        if (MUST_FIND_AT_INDEX) return null;
                        consecutive_zeroes_start = bits_idx;
                        consecutive_zeroes = 0;
                    }
                    const next_zeroes = @min(bits_left, @ctz(block));
                    consecutive_zeroes += next_zeroes;
                    bits_idx += next_zeroes;
                    if (next_zeroes == bits_left or consecutive_zeroes >= n) break;
                    bits_left -= next_zeroes;
                    block >>= @intCast(next_zeroes);
                    block = ~block;
                }
                if (consecutive_zeroes >= n) return consecutive_zeroes_start;
            }
            while (bits_idx < self.index_len) {
                var block = ~self.list.ptr[block_idx];
                bits_left = @min(USIZEBITS, self.index_len - bits_idx);
                while (true) {
                    const skip_ones: usize = @min(bits_left, num_cast(@ctz(block), usize));
                    bits_idx += skip_ones;
                    if (skip_ones == bits_left) break;
                    bits_left -= skip_ones;
                    block >>= @intCast(skip_ones);
                    block = ~block;
                    if (skip_ones > 0) {
                        if (MUST_FIND_AT_INDEX) return null;
                        consecutive_zeroes_start = bits_idx;
                        consecutive_zeroes = 0;
                    }
                    const next_zeroes = @min(bits_left, @ctz(block));
                    consecutive_zeroes += next_zeroes;
                    bits_idx += next_zeroes;
                    if (next_zeroes == bits_left or consecutive_zeroes >= n) break;
                    bits_left -= next_zeroes;
                    block >>= @intCast(next_zeroes);
                    block = ~block;
                }
                if (consecutive_zeroes >= n) return consecutive_zeroes_start;
                block_idx += 1;
            }
            return null;
        }
        pub fn find_first_n_consecutive_unset_bits(self: Self, n: usize) ?usize {
            return self.find_first_n_consecutive_unset_bits_starting_at_internal(0, n, true, false);
        }
        pub fn find_first_n_consecutive_unset_bits_starting_at(self: Self, idx: usize, n: usize) ?usize {
            return self.find_first_n_consecutive_unset_bits_starting_at_internal(idx, n, false, false);
        }
        pub fn idx_has_n_consecutive_unset_bits(self: Self, idx: usize, n: usize) bool {
            return self.find_first_n_consecutive_unset_bits_starting_at_internal(idx, n, false, true) != null;
        }

        pub fn find_first_bit_set(self: Self) ?usize {
            Assert.assert_with_reason(BITS_PER_INDEX == 1, @src(), "this function can only be used when `BITS_PER_INDEX == 1,`", .{});
            if (self.index_len == 0) return null;
            for (self.list.slice(), 0..) |block, b| {
                if (block > 0) {
                    const offset = @ctz(block);
                    const idx = offset + (b * USIZEBITS);
                    if (idx < self.index_len) return idx;
                    return null;
                }
            }
            return null;
        }
        pub fn find_first_bit_set_starting_at(self: Self, idx: usize) ?usize {
            Assert.assert_with_reason(BITS_PER_INDEX == 1, @src(), "this function can only be used when `BITS_PER_INDEX == 1,`", .{});
            if (self.index_len == 0) return null;
            const start_block = block_offset(idx);
            var first_block = self.list.ptr[start_block.block_index];
            first_block >>= start_block.bit_offset;
            if (first_block > 0) {
                const offset = @ctz(first_block);
                const _idx = idx + offset;
                if (_idx < self.index_len) return idx;
                return null;
            }
            for (self.list.slice()[start_block.block_index..], start_block.block_index..) |block, b| {
                if (block > 0) {
                    const offset = @ctz(block);
                    const _idx = offset + (b * USIZEBITS);
                    if (_idx < self.index_len) return idx;
                    return null;
                }
            }
            return null;
        }
        pub fn find_first_bit_unset(self: Self) ?usize {
            Assert.assert_with_reason(BITS_PER_INDEX == 1, @src(), "this function can only be used when `BITS_PER_INDEX == 1,`", .{});
            if (self.index_len == 0) return null;
            for (self.list.slice(), 0..) |block, b| {
                if (block < math.maxInt(usize)) {
                    const inverse_block = ~block;
                    const offset = @ctz(inverse_block);
                    const idx = offset + (b * USIZEBITS);
                    if (idx < self.index_len) return idx;
                    return null;
                }
            }
            return null;
        }
        pub fn find_first_bit_unset_starting_at(self: Self, idx: usize) ?usize {
            Assert.assert_with_reason(BITS_PER_INDEX == 1, @src(), "this function can only be used when `BITS_PER_INDEX == 1,`", .{});
            if (self.index_len == 0) return null;
            const start_block = block_offset(idx);
            var first_block = self.list.ptr[start_block.block_index];
            first_block >>= start_block.bit_offset;
            const fill_ones = math.maxInt(usize) << (USIZEBITS - start_block.bit_offset);
            first_block |= fill_ones;
            if (first_block < math.maxInt(usize)) {
                const inverse_block = ~first_block;
                const offset = @ctz(inverse_block);
                const _idx = idx + offset;
                if (_idx < self.index_len) return _idx;
                return null;
            }
            for (self.list.slice()[start_block.block_index..], start_block.block_index..) |block, b| {
                if (block < math.maxInt(usize)) {
                    const inverse_block = ~block;
                    const offset = @ctz(inverse_block);
                    const _idx = offset + (b * USIZEBITS);
                    if (_idx < self.index_len) return _idx;
                    return null;
                }
            }
            return null;
        }
        const SetOneZeroMode = enum(u8) {
            SET_1,
            SET_0,
        };
        pub fn set_range_bits(self: Self, start: usize, count: usize, comptime mode: SetOneZeroMode) void {
            Assert.assert_with_reason(BITS_PER_INDEX == 1, @src(), "this function can only be used when `BITS_PER_INDEX == 1,`", .{});
            const end = start + count;
            Assert.assert_with_reason(end <= self.index_len, @src(), "start {d} + count {d} ({d}) is greater than the max index len {d}", .{ start, count, end, self.index_len });
            const real_start = block_offset(start);
            const val_in_first_block = Utils.first_n_bits_set(usize, @intCast(@min(USIZEBITS, count))) << real_start.bit_offset;
            switch (mode) {
                .SET_1 => self.list.ptr[real_start.block_index] |= val_in_first_block,
                .SET_0 => self.list.ptr[real_start.block_index] &= ~val_in_first_block,
            }
            const available_for_first_block = USIZEBITS - real_start.bit_offset;
            if (available_for_first_block < count) {
                var bits_left = count - available_for_first_block;
                var next_block = real_start.block_index + 1;
                while (bits_left >= USIZEBITS) {
                    switch (mode) {
                        .SET_1 => self.list.ptr[next_block] = math.maxInt(usize),
                        .SET_0 => self.list.ptr[next_block] = 0,
                    }
                    next_block += 1;
                    bits_left -= USIZEBITS;
                }
                if (bits_left > 0) {
                    const val_in_last_block = Utils.first_n_bits_set(usize, @intCast(@min(USIZEBITS, bits_left)));
                    switch (mode) {
                        .SET_1 => self.list.ptr[next_block] |= val_in_last_block,
                        .SET_0 => self.list.ptr[next_block] &= ~val_in_last_block,
                    }
                }
            }
        }
    };
}

test "BitList" {
    const Test = Root.Testing;
    const BList = BitList(1);
    var data = [_]usize{
        //        55        45  41       32      24       15     8      1
        0b1111111110000011111111101111111101111111000111111001111100011110,
        //           116
        0b1111111111110000000000000000000000000000000000000000000000000011,
        0b1111111111111111111111111111111111111111111111111111111111111111,
    };
    const list = BList{
        .list = .{ .ptr = @ptrCast(&data), .cap = 3, .len = 3 },
        .index_len = 192,
    };
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(4), "list.find_first_n_consecutive_set_bits(4)", 1, "1", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(5), "list.find_first_n_consecutive_set_bits(5)", 8, "8", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(6), "list.find_first_n_consecutive_set_bits(6)", 15, "15", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(8), "list.find_first_n_consecutive_set_bits(8)", 32, "32", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(9), "list.find_first_n_consecutive_set_bits(9)", 41, "41", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(10), "list.find_first_n_consecutive_set_bits(10)", 55, "55", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(20), "list.find_first_n_consecutive_set_bits(20)", 116, "116", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(76), "list.find_first_n_consecutive_set_bits(76)", 116, "116", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(77), "list.find_first_n_consecutive_set_bits(77)", null, "null", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits(78), "list.find_first_n_consecutive_set_bits(78)", null, "null", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits_starting_at(45, 5), "list.find_first_n_consecutive_set_bits_starting_at(45, 5)", 45, "45", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_set_bits_starting_at(45, 6), "list.find_first_n_consecutive_set_bits_starting_at(45, 6)", 55, "55", "wrong result", .{});
    try Test.expect_equal(list.idx_has_n_consecutive_set_bits(45, 5), "list.idx_has_n_consecutive_set_bits(45, 5)", true, "true", "wrong result", .{});
    try Test.expect_equal(list.idx_has_n_consecutive_set_bits(45, 6), "list.idx_has_n_consecutive_set_bits(45, 6)", false, "false", "wrong result", .{});
    data[0] = ~data[0];
    data[1] = ~data[1];
    data[2] = ~data[2];
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(4), "list.find_first_n_consecutive_unset_bits(4)", 1, "1", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(5), "list.find_first_n_consecutive_unset_bits(5)", 8, "8", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(6), "list.find_first_n_consecutive_unset_bits(6)", 15, "15", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(8), "list.find_first_n_consecutive_unset_bits(8)", 32, "32", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(9), "list.find_first_n_consecutive_unset_bits(9)", 41, "41", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(10), "list.find_first_n_consecutive_unset_bits(10)", 55, "55", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(20), "list.find_first_n_consecutive_unset_bits(20)", 116, "116", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(76), "list.find_first_n_consecutive_unset_bits(76)", 116, "116", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(77), "list.find_first_n_consecutive_unset_bits(77)", null, "null", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits(78), "list.find_first_n_consecutive_unset_bits(78)", null, "null", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits_starting_at(45, 5), "list.find_first_n_consecutive_unset_bits_starting_at(45, 5)", 45, "45", "wrong result", .{});
    try Test.expect_equal(list.find_first_n_consecutive_unset_bits_starting_at(45, 6), "list.find_first_n_consecutive_unset_bits_starting_at(45, 6)", 55, "55", "wrong result", .{});
    try Test.expect_equal(list.idx_has_n_consecutive_unset_bits(45, 5), "list.idx_has_n_consecutive_unset_bits(45, 5)", true, "true", "wrong result", .{});
    try Test.expect_equal(list.idx_has_n_consecutive_unset_bits(45, 6), "list.idx_has_n_consecutive_unset_bits(45, 6)", false, "false", "wrong result", .{});
}

pub const FreeBitList = struct {
    free_bits: BitList(1) = .{},
    free_count: usize = 0,

    pub fn init_capacity(cap: usize, alloc: Allocator) FreeBitList {
        return FreeBitList{
            .free_bits = BitList(1).init_capacity(cap, alloc),
            .free_count = 0,
        };
    }

    pub fn set_len(self: *FreeBitList, len: usize, alloc: Allocator) void {
        self.free_bits.set_len(len, alloc);
    }
    pub fn find_1_free_and_set_used(self: FreeBitList) ?usize {
        if (self.free_count == 0) return null;
        const idx = self.free_bits.find_first_bit_set();
        self.free_bits.clear(idx.?);
        self.free_count -= 1;
        return idx.?;
    }
    pub fn find_range_free_and_set_used(self: FreeBitList, count: usize) ?usize {
        if (self.free_count < count) return null;
        const idx = self.free_bits.find_first_n_consecutive_set_bits(count);
        if (idx) |i| {
            self.free_bits.set_range_bits(i, count, .SET_0);
            self.free_count -= count;
        }
        return idx;
    }
    pub fn has_n_consecutive_frees_at_idx(self: FreeBitList, idx: usize, n: usize) bool {
        return self.free_bits.idx_has_n_consecutive_set_bits(idx, n);
    }
    pub fn set_free(self: FreeBitList, idx: usize) void {
        const val = 0b1;
        self.free_bits.set_no_clear(idx, val);
        self.free_count += 1;
    }
    pub fn set_range_free(self: FreeBitList, idx: usize, count: usize) void {
        self.free_bits.set_range_bits(idx, count, .SET_1);
        self.free_count += count;
    }
    pub fn set_range_used(self: FreeBitList, idx: usize, count: usize) void {
        self.free_bits.set_range_bits(idx, count, .SET_0);
        self.free_count -= count;
    }
};
