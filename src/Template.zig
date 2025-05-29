//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
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

const LITERAL_TAG = (1 << 15);
const MAX_LITERAL_LEN = LITERAL_TAG - 1;
const FMT_ESCAPE_LEFT = '`';
const FMT_ESCAPE_RIGHT = '`';
// const SegmentData = struct {
//     is_literal: bool,
//     len: u16,

//     fn next(buf: []const u8) SegmentData {}
// };
// const InsertData = packed struct {
//     segment_data: SegmentData,
// };

pub fn define_template(comptime name: []const u8, comptime keys_type: type, comptime content: []const u8) type {
    return struct {
        pub const KEYS_TYPE = keys_type;
        pub const NAME = name;
        pub const CONTENT = content;

        pub inline fn write(writer: anytype, keys: KEYS_TYPE) void {
            std.fmt.format(writer, CONTENT, keys) catch |err| std.debug.panic("Template `{s}` failed to process input: {s}", .{ NAME, @errorName(err) });
        }
    };
}
