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
const Root = @import("./_root.zig");
const Assert = Root.Assert;

pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        object: *anyopaque,
        vtable: *const VTable,

        pub const VTable = struct {
            next: *const fn (object: *anyopaque) T = _not_implemented_val,
            next_ptr: *const fn (object: *anyopaque) *T = _not_implemented_ptr,
            has_next: *const fn (object: *anyopaque) bool = _not_implemented_bool,
            prev: *const fn (object: *anyopaque) T = _not_implemented_val,
            prev_ptr: *const fn (object: *anyopaque) *T = _not_implemented_ptr,
            has_prev: *const fn (object: *anyopaque) bool = _not_implemented_bool,
            reset: *const fn (object: *anyopaque) void = _not_implemented_void,
            save_state: *const fn (object: *anyopaque, state_id: u8) anyerror!void = _not_implemented_save_load,
            load_state: *const fn (object: *anyopaque, state_id: u8) anyerror!void = _not_implemented_save_load,
        };

        fn _not_implemented_val(object: *anyopaque) T {
            _ = object;
            @panic("not implemented");
        }
        fn _not_implemented_ptr(object: *anyopaque) *T {
            _ = object;
            @panic("not implemented");
        }
        fn _not_implemented_void(object: *anyopaque) void {
            _ = object;
            @panic("not implemented");
        }
        fn _not_implemented_bool(object: *anyopaque) bool {
            _ = object;
            @panic("not implemented");
        }
        fn _not_implemented_save_load(object: *anyopaque, state_id: u8) anyerror!void {
            _ = object;
            _ = state_id;
            @panic("not implemented");
        }

        pub fn next(self: Self) T {
            return self.vtable.next(self.object);
        }
        pub fn next_ptr(self: Self) T {
            return self.vtable.next_ptr(self.object);
        }
        pub fn has_next(self: Self) bool {
            return self.vtable.has_next(self.object);
        }
        pub fn prev(self: Self) T {
            return self.vtable.prev(self.object);
        }
        pub fn prev_ptr(self: Self) T {
            return self.vtable.prev_ptr(self.object);
        }
        pub fn has_prev(self: Self) bool {
            return self.vtable.has_prev(self.object);
        }
        pub fn reset(self: Self) void {
            return self.vtable.reset(self.object);
        }
        pub fn save_state(self: Self, state_id: u8) void {
            return self.vtable.save_state(self.object, state_id);
        }
        pub fn load_state(self: Self, state_id: u8) void {
            return self.vtable.load_state(self.object, state_id);
        }
    };
}
