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

comptime {
    if (build.is_test) {
        _ = @import("./Threading_Tests.zig");
    }
}

const std = @import("std");
const build = @import("builtin");

pub const LocksModule = @import("./Threading_Locks.zig");

var next_thread_id: u32 = 1;
threadlocal var this_thread_id: u32 = 0;
/// An arbitrary thread Id that is assigned by the application/library.
/// It is guaranteed to be > 0, and each thread that calls this
/// for the first time will be assigned its own unique thread Id starting from 1
pub inline fn get_this_thread_id() u32 {
    if (this_thread_id == 0) {
        this_thread_id = @atomicRmw(u32, &next_thread_id, .Add, 1, .monotonic);
    }
    return this_thread_id;
}
