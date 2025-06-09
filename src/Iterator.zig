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
const assert_with_reason = Assert.assert_with_reason;
const ArrayLen = Root.CommonTypes.ArrayLen;
const Flags = Root.Flags.Flags;

pub const IteratorCapabilities = Flags(enum(u8) {
    RESET = 1 << 0,
    FORWARD = 1 << 1,
    BACKWARD = 1 << 2,
    SAVE_LOAD_1_SLOT = 1 << 3,
    SAVE_LOAD_2_SLOTS = 2 << 3,
    SAVE_LOAD_3_SLOTS = 3 << 3,
    SAVE_LOAD_4_SLOTS = 4 << 3,
    SAVE_LOAD_5_SLOTS = 5 << 3,
    SAVE_LOAD_6_SLOTS = 6 << 3,
    SAVE_LOAD_7_SLOTS = 7 << 3,
}, enum(u8) {
    RESET = 0b1,
    DIRECTION = 0b000110,
    SAVE_LOAD = 0b111000,
});

pub fn Iterator(comptime T: type) type {
    return struct {
        implementor: *anyopaque,
        vtable: *const VTable,

        pub const VTable = struct {
            /// Report what functionality the iterator implementation
            /// supports. This method *should* always return the
            /// capability flags supported, as functions relying on the Iterator
            /// interface may rely on them for assertions or to choose
            /// alternate algorithms when fewer capabilities are available
            capabilities: *const fn () IteratorCapabilities,
            /// Reset the Iterator to its initial state,
            /// returning `false` if the implementation cannot
            /// reset or some other condition prevented it,
            reset: *const fn (implementor: *anyopaque) bool,
            /// Save the current iterator state for future reload,
            /// return `false` if implementation does not support
            /// saving state or some other consition prevented it
            save_state: *const fn (implementor: *anyopaque, state_slot: usize) bool,
            /// Reload the state saved in specified slot,
            /// return `false` if implementation does not support
            /// reloading state or some other consition prevented it
            /// (for example no state was previously saved to the slot)
            load_state: *const fn (implementor: *anyopaque, state_slot: usize) bool,
            /// Advance the iterator to the right/next position,
            /// returning `false` if the implementation does not support
            /// advancing forward, the position didn't move,
            /// or some other condition caused it to fail
            advance_next: *const fn (implementor: *anyopaque) bool,
            /// Return pointer to next item or null if none exists (or the
            /// implementation does not support peeking forward),
            /// without advancing iterator
            peek_next_or_null: *const fn (implementor: *anyopaque) ?*T,
            /// Advance the iterator to the left/prev position,
            /// returning `false` if the implementation does not support
            /// advancing forward, the position didn't move,
            /// or some other condition caused it to fail
            advance_prev: *const fn (implementor: *anyopaque) bool,
            /// Return pointer to prev item or null if none exists,
            /// without advancing iterator
            peek_prev_or_null: *const fn (implementor: *anyopaque) ?*T,
        };
        const Self = @This();

        pub inline fn capabilities(self: Self) IteratorCapabilities {
            return self.vtable.capabilities();
        }
        pub inline fn reset(self: Self) bool {
            return self.vtable.reset(self.implementor);
        }
        pub inline fn save_state(self: Self, state_slot: usize) bool {
            return self.vtable.save_state(self.implementor, state_slot);
        }
        pub inline fn load_state(self: Self, state_slot: usize) bool {
            return self.vtable.load_state(self.implementor, state_slot);
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
            const result = self.vtable.peek_next_or_null(self.implementor);
            if (result == null) return null;
            _ = self.vtable.advance_next(self.implementor);
            return result;
        }
        pub inline fn skip_next(self: Self) bool {
            return self.vtable.advance_next(self.implementor);
        }
        pub fn skip_next_count(self: Self, count: usize) usize {
            var i: usize = 0;
            var more: bool = true;
            while (i < count) {
                more = self.vtable.advance_next(self.implementor);
                if (more) {
                    i += 1;
                } else break;
            }
            return i;
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
            const result = self.vtable.peek_prev_or_null(self.implementor);
            if (result == null) return null;
            _ = self.vtable.advance_prev(self.implementor);
            return result;
        }
        pub inline fn skip_prev(self: Self) bool {
            return self.vtable.advance_prev(self.implementor);
        }
        pub fn skip_prev_count(self: Self, count: usize) usize {
            var i: usize = 0;
            var more: bool = true;
            while (i < count) {
                more = self.vtable.advance_prev(self.implementor);
                if (more) {
                    i += 1;
                } else break;
            }
            return i;
        }
        pub fn perform_action_on_all_next_items(self: Self, action: *const fn (item: *T, userdata: ?*anyopaque) void, userdata: ?*anyopaque) bool {
            var item_or_null: ?*T = self.vtable.peek_next_or_null(self.implementor);
            if (item_or_null == null) return false;
            while (item_or_null != null) {
                _ = self.vtable.advance_next(self.implementor);
                action(item_or_null.?, userdata);
                item_or_null = self.vtable.peek_next_or_null(self.implementor);
            }
            return true;
        }
        pub fn perform_action_on_next_n_items(self: Self, count: usize, action: *const fn (item: *T, userdata: ?*anyopaque) void, userdata: ?*anyopaque) usize {
            var item_or_null: ?*T = self.vtable.peek_next_or_null(self.implementor);
            if (item_or_null == null) return 0;
            var i: usize = 0;
            while (item_or_null != null and i < count) {
                _ = self.vtable.advance_next(self.implementor);
                action(item_or_null.?, userdata);
                item_or_null = self.vtable.peek_next_or_null(self.implementor);
                i += 1;
            }
            return i;
        }
        pub fn perform_action_on_all_prev_items(self: Self, action: *const fn (item: *T, userdata: ?*anyopaque) void, userdata: ?*anyopaque) bool {
            var item_or_null: ?*T = self.vtable.peek_prev_or_null(self.implementor);
            if (item_or_null == null) return false;
            while (item_or_null != null) {
                _ = self.vtable.advance_prev(self.implementor);
                action(item_or_null.?, userdata);
                item_or_null = self.vtable.peek_prev_or_null(self.implementor);
            }
            return true;
        }
        pub fn perform_action_on_prev_n_items(self: Self, count: usize, action: *const fn (item: *T, userdata: ?*anyopaque) void, userdata: ?*anyopaque) usize {
            var item_or_null: ?*T = self.vtable.peek_prev_or_null(self.implementor);
            if (item_or_null == null) return 0;
            var i: usize = 0;
            while (item_or_null != null and i < count) {
                _ = self.vtable.advance_prev(self.implementor);
                action(item_or_null.?, userdata);
                item_or_null = self.vtable.peek_prev_or_null(self.implementor);
                i += 1;
            }
            return i;
        }
        pub fn find_next_item_that_matches_filter(self: Self, filter: *const fn (item: *T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) ?*T {
            var item_or_null: ?*T = self.vtable.peek_next_or_null(self.implementor);
            if (item_or_null == null) return null;
            while (item_or_null != null) {
                _ = self.vtable.advance_next(self.implementor);
                if (filter(item_or_null.?, userdata)) return item_or_null.?;
                item_or_null = self.vtable.peek_next_or_null(self.implementor);
            }
            return null;
        }
        pub fn find_next_n_items_that_match_filter(self: Self, count: usize, out_buffer: []*T, filter: *const fn (item: *T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) usize {
            assert_with_reason(count <= out_buffer.len, @src(), "`out_buffer` is too small to hold the requested {d} values", .{count});
            var item_or_null: ?*T = self.vtable.peek_next_or_null(self.implementor);
            if (item_or_null == null) return 0;
            var i: usize = 0;
            while (item_or_null != null and i < count) {
                _ = self.vtable.advance_next(self.implementor);
                if (filter(item_or_null.?, userdata)) {
                    out_buffer[i] = item_or_null.?;
                    i += 1;
                }
                item_or_null = self.vtable.peek_next_or_null(self.implementor);
            }
            return i;
        }
        pub fn find_next_n_items_that_match_filter_to_array(self: Self, comptime count: usize, filter: *const fn (item: *T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) ArrayLen(count, *T) {
            var item_or_null: ?*T = self.vtable.peek_next_or_null(self.implementor);
            if (item_or_null == null) return 0;
            var result = ArrayLen(count, *T){ .arr = undefined, .len = 0 };
            while (item_or_null != null and result.len < count) {
                _ = self.vtable.advance_next(self.implementor);
                if (filter(item_or_null.?, userdata)) {
                    result.arr[result.len] = item_or_null.?;
                    result.len += 1;
                }
                item_or_null = self.vtable.peek_next_or_null(self.implementor);
            }
            return result;
        }
        pub fn find_prev_item_that_matches_filter(self: Self, filter: *const fn (item: *T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) ?*T {
            var item_or_null: ?*T = self.vtable.peek_prev_or_null(self.implementor);
            if (item_or_null == null) return null;
            while (item_or_null != null) {
                _ = self.vtable.advance_prev(self.implementor);
                if (filter(item_or_null.?, userdata)) return item_or_null.?;
                item_or_null = self.vtable.peek_prev_or_null(self.implementor);
            }
            return null;
        }
        pub fn find_prev_n_items_that_match_filter(self: Self, count: usize, out_buffer: []*T, filter: *const fn (item: *T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) usize {
            assert_with_reason(count <= out_buffer.len, @src(), "`out_buffer` is too small to hold the requested {d} values", .{count});
            var item_or_null: ?*T = self.vtable.peek_prev_or_null(self.implementor);
            if (item_or_null == null) return 0;
            var i: usize = 0;
            while (item_or_null != null and i < count) {
                _ = self.vtable.advance_prev(self.implementor);
                if (filter(item_or_null.?, userdata)) {
                    out_buffer[i] = item_or_null.?;
                    i += 1;
                }
                item_or_null = self.vtable.peek_prev_or_null(self.implementor);
            }
            return i;
        }
        pub fn find_prev_n_items_that_match_filter_to_array(self: Self, comptime count: usize, filter: *const fn (item: *T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) ArrayLen(count, *T) {
            var item_or_null: ?*T = self.vtable.peek_prev_or_null(self.implementor);
            if (item_or_null == null) return 0;
            var result = ArrayLen(count, *T){ .arr = undefined, .len = 0 };
            while (item_or_null != null and result.len < count) {
                _ = self.vtable.advance_prev(self.implementor);
                if (filter(item_or_null.?, userdata)) {
                    result.arr[result.len] = item_or_null.?;
                    result.len += 1;
                }
                item_or_null = self.vtable.peek_prev_or_null(self.implementor);
            }
            return result;
        }
    };
}
