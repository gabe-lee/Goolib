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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const build = @import("builtin");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const fmt = std.fmt;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Types = Root.Types;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

pub const InsertionSort = @import("./Sort_InsertionSort.zig");
pub const QuickSort = @import("./Sort_Quicksort.zig");

pub fn is_sorted_implicit(buffer: anytype, start: anytype, end_exclusive: anytype) bool {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    assert_with_reason(Utils.can_infer_type_order(T), @src(), "cannot inherently order type " ++ @typeName(T), .{});
    var i = start;
    var ii = start + 1;
    while (ii < end_exclusive) {
        if (buffer[i] > buffer[ii]) return false;
        i = ii;
        ii += 1;
    }
    return true;
}

pub fn is_sorted_with_func(buffer: anytype, start: anytype, end_exclusive: anytype, greater_than: *const fn (a: Types.IndexableChild(@TypeOf(buffer)), b: Types.IndexableChild(@TypeOf(buffer))) bool) bool {
    const BUF = @TypeOf(buffer);
    _ = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    var i = start;
    var ii = start + 1;
    while (ii < end_exclusive) {
        if (greater_than(buffer[i], buffer[ii])) return false;
        i = ii;
        ii += 1;
    }
    return true;
}

pub fn is_sorted_with_func_and_userdata(buffer: anytype, start: anytype, end_exclusive: anytype, userdata: anytype, greater_than: *const fn (a: Types.IndexableChild(@TypeOf(buffer)), b: Types.IndexableChild(@TypeOf(buffer)), userdata: @TypeOf(userdata)) bool) bool {
    const BUF = @TypeOf(buffer);
    _ = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    var i = start;
    var ii = start + 1;
    while (ii < end_exclusive) {
        if (greater_than(buffer[i], buffer[ii], userdata)) return false;
        i = ii;
        ii += 1;
    }
    return true;
}
