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

pub fn Iterator(comptime T: type) type {
    return struct {
        implementor: *anyopaque,
        vtable: *const VTable,

        pub const VTable = struct {
            /// Reset the Iterator to its initial state,
            /// returning `false` if the implementation cannot
            /// reset or some other condition prevented it,
            reset: *const fn (inplementor: *anyopaque) bool,
            /// Advance the iterator to the right/next position,
            /// returning `false` if the position didn't move
            /// or some other condition prevented it
            advance_next: *const fn (inplementor: *anyopaque) bool,
            /// Return pointer to next item or null if none exists,
            /// without advancing iterator
            peek_next_or_null: *const fn (inplementor: *anyopaque) ?*T,
            /// Advance the iterator to the left/prev position,
            /// returning `false` if the position didn't move
            /// or some other condition prevented it
            advance_prev: *const fn (inplementor: *anyopaque) bool,
            /// Return pointer to prev item or null if none exists,
            /// without advancing iterator
            peek_prev_or_null: *const fn (inplementor: *anyopaque) ?*T,
        };
        const Self = @This();

        pub inline fn reset(self: Self) bool {
            return self.vtable.reset(self.implementor);
        }
        pub inline fn has_next(self: Self) bool {
            return self.vtable.peek_next_or_null(self.implementor) != null;
        }
        pub inline fn peek_next(self: Self) *T {
            return self.vtable.peek_next_or_null(self.implementor).?;
        }
        pub inline fn peek_next_or_null(self: Self) ?*T {
            return self.vtable.peek_next_or_null(self.implementor);
        }
        pub inline fn get_next(self: Self) *T {
            const result = self.vtable.peek_next_or_null(self.implementor).?;
            self.vtable.advance_next(self.implementor);
            return result;
        }
        pub inline fn get_next_or_null(self: Self) ?*T {
            const result = self.vtable.peek_next_or_null(self.implementor).?;
            if (result == null) return null;
            _ = self.vtable.advance_next(self.implementor);
            return result;
        }
        pub inline fn skip_next(self: Self) bool {
            return self.vtable.advance_next(self.implementor);
        }
        pub inline fn has_prev(self: Self) bool {
            return self.vtable.peek_prev_or_null(self.implementor) != null;
        }
        pub inline fn peek_prev(self: Self) *T {
            return self.vtable.peek_prev_or_null(self.implementor).?;
        }
        pub inline fn peek_prev_or_null(self: Self) ?*T {
            return self.vtable.peek_prev_or_null(self.implementor);
        }
        pub inline fn get_prev(self: Self) *T {
            const result = self.vtable.peek_next_or_null(self.implementor).?;
            self.vtable.advance_next(self.implementor);
            return result;
        }
        pub inline fn get_prev_or_null(self: Self) ?*T {
            const result = self.vtable.peek_prev_or_null(self.implementor).?;
            if (result == null) return null;
            _ = self.vtable.advance_prev(self.implementor);
            return result;
        }
        pub inline fn skip_prev(self: Self) bool {
            return self.vtable.advance_prev(self.implementor);
        }
        pub fn perform_action_on_each_next_item(self: Self, action: *const fn (item: *T, userdata: ?*anyopaque) void, userdata: ?*anyopaque) bool {
            var item_or_null: ?*T = self.vtable.peek_next_or_null(self.implementor);
            if (item_or_null == null) return false;
            while (item_or_null != null) {
                _ = self.vtable.advance_next(self.implementor);
                action(item_or_null.?, userdata);
                item_or_null = self.vtable.peek_next_or_null(self.implementor);
            }
            return true;
        }
        pub fn perform_action_on_each_prev_item(self: Self, action: *const fn (item: *T, userdata: ?*anyopaque) void, userdata: ?*anyopaque) bool {
            var item_or_null: ?*T = self.vtable.peek_prev_or_null(self.implementor);
            if (item_or_null == null) return false;
            while (item_or_null != null) {
                _ = self.vtable.advance_prev(self.implementor);
                action(item_or_null.?, userdata);
                item_or_null = self.vtable.peek_prev_or_null(self.implementor);
            }
            return true;
        }
    };
}
