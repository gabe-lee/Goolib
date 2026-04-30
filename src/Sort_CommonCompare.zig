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
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const Types = Root.Types;
const Utils = Root.Utils;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const inline_swap = Root.Utils.inline_swap;
const Iterator = Root.Iterator;
// const greater_than = Compare.greater_than;

pub const StructField = struct {
    const Field = std.builtin.Type.StructField;
    pub fn match(a: Field, b: Field) bool {
        return std.mem.eql(u8, a.name, b.name);
    }
    pub fn smaller_align_to_the_right_gt(a: Field, b: Field) bool {
        return a.alignment < b.alignment;
    }
    pub fn smaller_align_to_the_left_gt(a: Field, b: Field) bool {
        return a.alignment > b.alignment;
    }
    pub fn smaller_size_to_the_right_gt(a: Field, b: Field) bool {
        return @sizeOf(a.type) < @sizeOf(b.type);
    }
    pub fn smaller_size_to_the_left_gt(a: Field, b: Field) bool {
        return @sizeOf(a.type) > @sizeOf(b.type);
    }
};
