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
const build = @import("builtin");

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Types = Root.Types;
const Vec2 = Root.Vec2;
const Utils = Root.Utils;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;

pub const KeyedMutex = struct {
    mutex: std.Thread.Mutex = .{},

    pub fn lock(self: *KeyedMutex) Key {
        self.mutex.lock();
        return Key{
            .ptr = self,
        };
    }
    pub fn try_lock(self: *KeyedMutex) ?Key {
        if (self.mutex.tryLock()) {
            return Key{
                .ptr = self,
            };
        }
        return null;
    }

    pub const Key = struct {
        ptr: ?*KeyedMutex = null,

        pub fn unlock(self: *Key) void {
            assert_with_reason(self.ptr != null, @src(), "KeyedMutex Key was improperly created or was already unlocked", .{});
            self.ptr.?.mutex.unlock();
            self.ptr = null;
            self.* = undefined;
        }
    };
};
