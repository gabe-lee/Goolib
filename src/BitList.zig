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

const num_cast = Root.Cast.num_cast;

const List = Root.IList.List;

const TrueIndex = struct {
    block_index: usize,
    bit_offset: math.Log2Int(usize),
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

        fn block_offset(idx: usize) TrueIndex {
            var out: TrueIndex = undefined;
            const bit_idx = idx * BITS_PER_INDEX;
            out.block_index = bit_idx >> OFFSHIFT;
            out.bit_offset = bit_idx & OFFMASK;
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

        pub fn set(self: Self, idx: usize, val: BITS) void {
            Assert.assert_idx_less_than_len(idx, self.index_len, @src());
            const index = block_offset(idx);
            if (EVENLY_DIVISIBLE) {
                var block = self.list.ptr[index.block_index];
                var value: usize = @intCast(val);
                const mask = BITMASK << index.bit_offset;
                value <<= index.bit_offset;
                block &= ~mask;
                block |= value;
                self.list.ptr[index.block_index] = value;
            } else {
                var block = self.list.ptr[index.block_index];
                var value: usize = @intCast(val);
                var mask = BITMASK << index.bit_offset;
                value <<= index.bit_offset;
                block &= ~mask;
                block |= value;
                self.list.ptr[index.block_index] = value;
                const offset_2: math.Log2Int(usize) = num_cast((USIZEBITS - 1) - num_cast(index.bit_offset, usize), math.Log2Int(usize));
                block = self.list.ptr[index.block_index + 1];
                value = @intCast(val);
                mask = BITMASK >> offset_2;
                mask >>= 1;
                value >>= offset_2;
                value >>= 1;
                block &= ~mask;
                block |= value;
                self.list.ptr[index.block_index + 1] = value;
            }
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

        pub fn find_first_n_consecutive_set_bits(self: *const Self, n: usize) ?usize {
            Assert.assert_with_reason(BITS_PER_INDEX == 1, @src(), "this function can only be used when `BITS_PER_INDEX == 1,`", .{});
            var block_idx: usize = 0;
            var bits_idx: usize = 0;
            var bits_left: usize = undefined;
            var consecutive_ones: usize = 0;
            var consecutive_ones_start: usize = 0;
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
        pub fn find_first_n_consecutive_unset_bits(self: *const Self, n: usize) ?usize {
            Assert.assert_with_reason(BITS_PER_INDEX == 1, @src(), "this function can only be used when `BITS_PER_INDEX == 1,`", .{});
            var block_idx: usize = 0;
            var bits_idx: usize = 0;
            var bits_left: usize = undefined;
            var consecutive_zeroes: usize = 0;
            var consecutive_zeroes_start: usize = 0;
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
    };
}

test "BitList.find_first_n_consecutive_set_bits()" {
    const Test = Root.Testing;
    const BList = BitList(1);
    var data = [_]usize{
        //        55            41       32      24       15     8      1
        0b1111111110000011111111101111111101111111000111111001111100011110,
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
}
