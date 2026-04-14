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
const build = @import("builtin");
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const fmt = std.fmt;

const Root = @import("./_root.zig");
const object_equals = Root.Utils.object_equals;
const Assert = Root.Assert;
const Types = Root.Types;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const bit_cast = Root.Cast.bit_cast;

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;

pub const HEX_PREFIX = "0x";
pub const NIBBLE_TO_HEX_UPPER = [16]u8{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };
pub const NIBBLE_TO_HEX_LOWER = [16]u8{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };

pub fn num_to_hex_char_count(comptime NUM_TYPE: type) comptime_int {
    const bits = @bitSizeOf(NUM_TYPE);
    const bytes = (bits + 7) >> 3;
    const nibbles = bytes << 1;
    return nibbles;
}
pub fn num_to_hex_char_count_with_prefix_and_spacing(comptime NUM_TYPE: type, comptime SETTINGS: NumToHexSettings) u32 {
    const bits = @bitSizeOf(NUM_TYPE);
    const bytes = (bits + 7) >> 3;
    const nibbles = bytes << 1;
    const chars_with_seps = if (SETTINGS.separate_every_n_bytes) |N| calc: {
        const NN = @max(1, N);
        const whole_seps = nibbles / NN;
        const whole_sep_chunks = whole_seps * NN;
        const leftover_chucks = nibbles - whole_sep_chunks;
        const seps = whole_seps + if (leftover_chucks > 0) 1 else 0;
        break :calc nibbles + seps;
    } else nibbles;
    const chars_with_prefix = if (SETTINGS.include_prefix) chars_with_seps + 2 else chars_with_seps;
    const KIND = KindInfo.get_kind_info(NUM_TYPE);
    const sign_char: u32 = switch (KIND) {
        .INT => |INT| if (INT.signedness == .signed) 1 else 0,
        .FLOAT => 1,
        else => 0,
    };
    return sign_char + chars_with_prefix;
}

pub fn NumToHexResult(comptime T: type, comptime S: NumToHexSettings) type {
    return struct {
        const Self = @This();

        bytes: [MAX_BYTE_LEN]u8 = @splat(' '),
        start: u32 = 0,

        pub const MAX_BYTE_LEN = num_to_hex_char_count_with_prefix_and_spacing(T, S);
        pub const MAX_HEX_CHARS = num_to_hex_char_count(T);

        pub fn slice(self: Self) []const u8 {
            return self.bytes[self.start..];
        }
    };
}

pub const NumToHexCase = enum {
    UPPER,
    LOWER,
};

pub const NumToHexSettings = struct {
    include_prefix: bool = true,
    alpha_case: NumToHexCase = .UPPER,
    print_leading_zeroes: bool = true,
    leading_zeros_fill_char: u8 = '0',
    separate_every_n_nibbles: ?u32 = null,
    separator_char_between_every_n_nibbles: u8 = '_',
};

pub fn num_to_hex(num: anytype, comptime SETTINGS: NumToHexSettings) NumToHexResult(@TypeOf(num), SETTINGS) {
    const T = @TypeOf(num);
    const UINT = Types.UnsignedIntegerWithSameSize(T);
    const KIND = KindInfo.get_kind_info(T);
    const RESULT = NumToHexResult(T, SETTINGS);
    var result = RESULT{};
    var nibbles_since_last_sep: u32 = 0;
    var char_idx: u32 = RESULT.MAX_BYTE_LEN - 1;
    var hex_remaining = RESULT.MAX_HEX_CHARS;
    var val_remaining: Types.UnsignedIntegerWithSameSize(T), const is_neg: bool = switch (KIND) {
        .INT, .FLOAT => if (num < 0) .{ bit_cast(@abs(num), UINT), true } else .{ bit_cast(num, UINT), false },
        else => .{ bit_cast(num, UINT), false },
    };
    const USE_SEPS = SETTINGS.separate_every_n_nibbles != null;
    const SEP_EVERY_N = if (SETTINGS.separate_every_n_bytes) |N| @max(1, N);

    while (val_remaining > 0) {
        if (USE_SEPS and nibbles_since_last_sep >= SEP_EVERY_N) {
            result.bytes[char_idx] = SETTINGS.separator_char_between_every_n_nibbles;
            char_idx -= 1;
            nibbles_since_last_sep = 0;
        }
        const nib = val_remaining & 0b1111;
        val_remaining >>= 4;
        const char = switch (SETTINGS.alpha_case) {
            .UPPER => NIBBLE_TO_HEX_UPPER[nib],
            .LOWER => NIBBLE_TO_HEX_LOWER[nib],
        };
        result.bytes[char_idx] = char;
        char_idx -= 1;
        nibbles_since_last_sep += 1;
        hex_remaining -= 1;
    }
    if (SETTINGS.print_leading_zeroes) {
        while (hex_remaining > 0) {
            if (USE_SEPS and nibbles_since_last_sep >= SEP_EVERY_N) {
                result.bytes[char_idx] = SETTINGS.separator_char_between_every_n_nibbles;
                char_idx -= 1;
                nibbles_since_last_sep = 0;
            }
            result.bytes[char_idx] = SETTINGS.leading_zeros_fill_char;
            char_idx -= 1;
            nibbles_since_last_sep += 1;
            hex_remaining -= 1;
        }
    }
    if (SETTINGS.include_prefix) {
        result.bytes[char_idx] = 'x';
        char_idx -= 1;
        result.bytes[char_idx] = '0';
        char_idx -= 1;
    }
    if (is_neg) {
        result.bytes[char_idx] = '-';
        char_idx -= 1;
    }
    result.start = char_idx + 1;
    return result;
}

test num_to_hex {
    const Test = Root.Testing;
    const IN_A: u32 = 0xABCD;
    const EXP_A = "0xABCD";
    const GOT_A_RES = num_to_hex(IN_A, .{ .print_leading_zeroes = false });
    const GOT_A = GOT_A_RES.slice();
    try Test.expect_strings_equal(EXP_A, "EXP_A", GOT_A, "GOT_A", "fail", .{});
    const EXP_B = "0x0000ABCD";
    const GOT_B_RES = num_to_hex(IN_A, .{ .print_leading_zeroes = true });
    const GOT_B = GOT_B_RES.slice();
    try Test.expect_strings_equal(EXP_B, "EXP_B", GOT_B, "GOT_B", "fail", .{});
    const EXP_C = "0x00_00_AB_CD";
    const GOT_C_RES = num_to_hex(IN_A, .{ .print_leading_zeroes = true, .separate_every_n_nibbles = 2 });
    const GOT_C = GOT_C_RES.slice();
    try Test.expect_strings_equal(EXP_C, "EXP_C", GOT_C, "GOT_C", "fail", .{});
}
