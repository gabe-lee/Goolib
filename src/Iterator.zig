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

pub fn Iterator(comptime T: type, comptime bi_directional: bool, comptime can_reset: bool) type {
    return switch (bi_directional) {
        false => switch (can_reset) {
            false => struct {
                implementor: *anyopaque,
                vtable: *const VTable,

                pub const VTable = struct {
                    /// Return whether at least one more item can be returned
                    /// in the forward direction
                    has_next: *const fn (inplementor: *anyopaque) bool,
                    /// Return next item or panic if none exists,
                    /// and increment iterator
                    get_next: *const fn (inplementor: *anyopaque) *T,
                    /// Return next item or null if none exists,
                    /// and increment iterator
                    get_next_or_null: *const fn (inplementor: *anyopaque) ?*T,
                };
                const Self = @This();

                pub inline fn has_next(self: Self) bool {
                    return self.vtable.has_next(self.implementor);
                }
                pub inline fn get_next(self: Self) *T {
                    return self.vtable.get_next(self.implementor);
                }
                pub inline fn get_next_or_null(self: Self) ?*T {
                    return self.vtable.get_next_or_null(self.implementor);
                }
            },
            true => struct {
                implementor: *anyopaque,
                vtable: *const VTable,

                pub const VTable = struct {
                    /// Reset the Iterator to its initial state
                    reset: *const fn (inplementor: *anyopaque) void,
                    /// Return whether at least one more item can be returned
                    /// in the forward direction
                    has_next: *const fn (inplementor: *anyopaque) bool,
                    /// Return next item or panic if none exists,
                    /// and increment iterator
                    get_next: *const fn (inplementor: *anyopaque) *T,
                    /// Return next item or null if none exists,
                    /// and increment iterator
                    get_next_or_null: *const fn (inplementor: *anyopaque) ?*T,
                };
                const Self = @This();

                pub inline fn reset(self: Self) bool {
                    return self.vtable.reset(self.implementor);
                }
                pub inline fn has_next(self: Self) bool {
                    return self.vtable.has_next(self.implementor);
                }
                pub inline fn get_next(self: Self) *T {
                    return self.vtable.get_next(self.implementor);
                }
                pub inline fn get_next_or_null(self: Self) ?*T {
                    return self.vtable.get_next_or_null(self.implementor);
                }
            },
        },
        true => switch (can_reset) {
            false => struct {
                implementor: *anyopaque,
                vtable: *const VTable,

                pub const VTable = struct {
                    /// Return whether at least one more item can be returned
                    /// in the forward direction
                    has_next: *const fn (inplementor: *anyopaque) bool,
                    /// Return next item or panic if none exists,
                    /// and increment iterator
                    get_next: *const fn (inplementor: *anyopaque) *T,
                    /// Return next item or null if none exists,
                    /// and increment iterator
                    get_next_or_null: *const fn (inplementor: *anyopaque) ?*T,
                    /// Return whether at least one more item can be returned
                    /// in the backward direction
                    has_prev: *const fn (inplementor: *anyopaque) bool,
                    /// Return prev item or panic if none exists,
                    /// and increment iterator
                    get_prev: *const fn (inplementor: *anyopaque) *T,
                    /// Return prev item or null if none exists,
                    /// and increment iterator
                    get_prev_or_null: *const fn (inplementor: *anyopaque) ?*T,
                };
                const Self = @This();

                pub inline fn has_next(self: Self) bool {
                    return self.vtable.has_next(self.implementor);
                }
                pub inline fn get_next(self: Self) *T {
                    return self.vtable.get_next(self.implementor);
                }
                pub inline fn get_next_or_null(self: Self) ?*T {
                    return self.vtable.get_next_or_null(self.implementor);
                }
                pub inline fn has_prev(self: Self) bool {
                    return self.vtable.has_prev(self.implementor);
                }
                pub inline fn get_prev(self: Self) *T {
                    return self.vtable.get_prev(self.implementor);
                }
                pub inline fn get_prev_or_null(self: Self) ?*T {
                    return self.vtable.get_prev_or_null(self.implementor);
                }
            },
            true => struct {
                implementor: *anyopaque,
                vtable: *const VTable,

                pub const VTable = struct {
                    /// Reset the Iterator to its initial state
                    reset: *const fn (inplementor: *anyopaque) void,
                    /// Return whether at least one more item can be returned
                    /// in the forward direction
                    has_next: *const fn (inplementor: *anyopaque) bool,
                    /// Return next item or panic if none exists,
                    /// and increment iterator
                    get_next: *const fn (inplementor: *anyopaque) *T,
                    /// Return next item or null if none exists,
                    /// and increment iterator
                    get_next_or_null: *const fn (inplementor: *anyopaque) ?*T,
                    /// Return whether at least one more item can be returned
                    /// in the backward direction
                    has_prev: *const fn (inplementor: *anyopaque) bool,
                    /// Return prev item or panic if none exists,
                    /// and increment iterator
                    get_prev: *const fn (inplementor: *anyopaque) *T,
                    /// Return prev item or null if none exists,
                    /// and increment iterator
                    get_prev_or_null: *const fn (inplementor: *anyopaque) ?*T,
                };
                const Self = @This();

                pub inline fn reset(self: Self) bool {
                    return self.vtable.reset(self.implementor);
                }
                pub inline fn has_next(self: Self) bool {
                    return self.vtable.has_next(self.implementor);
                }
                pub inline fn get_next(self: Self) *T {
                    return self.vtable.get_next(self.implementor);
                }
                pub inline fn get_next_or_null(self: Self) ?*T {
                    return self.vtable.get_next_or_null(self.implementor);
                }
                pub inline fn has_prev(self: Self) bool {
                    return self.vtable.has_prev(self.implementor);
                }
                pub inline fn get_prev(self: Self) *T {
                    return self.vtable.get_prev(self.implementor);
                }
                pub inline fn get_prev_or_null(self: Self) ?*T {
                    return self.vtable.get_prev_or_null(self.implementor);
                }
            },
        },
    };
}
