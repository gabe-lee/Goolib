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
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const Alignment = std.mem.Alignment;
const AllocatorInfal = @This();

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const DummyAlloc = Root.Allocator.Dummy;

pub const Infallible = @import("./Allocator_Infallible.zig");
pub const Dummy = @import("./Allocator_Dummy.zig");

comptime {
    if (build.is_test) {
        _ = @import("./Allocator_Dummy.zig");
        _ = @import("./Allocator_Infallible.zig");
    }
}
