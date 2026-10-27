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
const unicode = std.unicode;

pub const Surrogates = enum {
    cannot_encode_surrogate_half,
    can_encode_surrogate_half,
};

/// This function is exactly like `std.unicode.utf8ValidateSliceImpl`, but it also simultaneously counts the number of characters.
///
/// After all, if you need to allocate a buffer for codepoints or some other structure, why should you have to go back for a second pass
/// just to do all these same calculations again.
pub fn utf8_validate_slice_and_count_codepoints(input: []const u8, comptime surrogates: Surrogates) struct { bool, usize } {
    var remaining = input;
    var char_count: usize = 0;
    if (std.simd.suggestVectorLength(u8)) |chunk_len| {
        const Chunk = @Vector(chunk_len, u8);

        // Fast path. Check for and skip ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(0x80);
            if (@reduce(.Or, chunk & mask == mask)) {
                // found a non ASCII byte
                break;
            }
            remaining = remaining[chunk_len..];
            char_count += chunk_len;
        }
    }

    // default lowest and highest continuation byte
    const lo_cb = 0b10000000;
    const hi_cb = 0b10111111;

    const min_non_ascii_codepoint = 0x80;

    // The first nibble is used to identify the continuation byte range to
    // accept. The second nibble is the size.
    const xx = 0xF1; // invalid: size 1
    const as = 0xF0; // ASCII: size 1
    const s1 = 0x02; // accept 0, size 2
    const s2 = switch (surrogates) {
        .cannot_encode_surrogate_half => 0x13, // accept 1, size 3
        .can_encode_surrogate_half => 0x03, // accept 0, size 3
    };
    const s3 = 0x03; // accept 0, size 3
    const s4 = switch (surrogates) {
        .cannot_encode_surrogate_half => 0x23, // accept 2, size 3
        .can_encode_surrogate_half => 0x03, // accept 0, size 3
    };
    const s5 = 0x34; // accept 3, size 4
    const s6 = 0x04; // accept 0, size 4
    const s7 = 0x44; // accept 4, size 4

    // Information about the first byte in a UTF-8 sequence.
    const first = comptime first: {
        const a: [128]u8 = @splat(as);
        const b: [64]u8 = @splat(xx);
        const c: [64]u8 = .{
            xx, xx, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1,
            s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1,
            s2, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s4, s3, s3,
            s5, s6, s6, s6, s7, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
        };
        break :first a ++ b ++ c;
    };

    const n = remaining.len;
    var i: usize = 0;
    while (i < n) {
        const first_byte = remaining[i];
        if (first_byte < min_non_ascii_codepoint) {
            i += 1;
            char_count += 1;
            continue;
        }

        const info = first[first_byte];
        if (info == xx) {
            return .{ false, char_count }; // Illegal starter byte.
        }

        const size = info & 7;
        if (i + size > n) {
            return .{ false, char_count }; // Short or invalid.
        }

        // Figure out the acceptable low and high continuation bytes, starting
        // with our defaults.
        var accept_lo: u8 = lo_cb;
        var accept_hi: u8 = hi_cb;

        switch (info >> 4) {
            0 => {},
            1 => accept_lo = 0xA0,
            2 => accept_hi = 0x9F,
            3 => accept_lo = 0x90,
            4 => accept_hi = 0x8F,
            else => unreachable,
        }

        const c1 = remaining[i + 1];
        if (c1 < accept_lo or accept_hi < c1) {
            return .{ false, char_count };
        }

        switch (size) {
            2 => i += 2,
            3 => {
                const c2 = remaining[i + 2];
                if (c2 < lo_cb or hi_cb < c2) {
                    return .{ false, char_count };
                }
                i += 3;
            },
            4 => {
                const c2 = remaining[i + 2];
                if (c2 < lo_cb or hi_cb < c2) {
                    return .{ false, char_count };
                }
                const c3 = remaining[i + 3];
                if (c3 < lo_cb or hi_cb < c3) {
                    return .{ false, char_count };
                }
                i += 4;
            },
            else => unreachable,
        }
        char_count += 1;
    }

    return .{ true, char_count };
}
