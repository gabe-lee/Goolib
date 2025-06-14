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
const GrowthModel = Root.CommonTypes.GrowthModel;
const Flags = Root.Flags.Flags;
const List = Root.List.List;
const ListOpts = Root.List.ListOptions;
const AllocInfal = Root.AllocatorInfallible;

pub const TraverserOptions = struct {
    elem_type: type,
    reset: bool = false,
    goto_left_sibling: bool = false,
    goto_right_sibling: bool = false,
    goto_left_children: bool = false,
    goto_right_children: bool = false,
    goto_parent: bool = false,
    state_slots: u32 = 0,
};

pub fn Traverser(comptime options: TraverserOptions) type {
    return struct {
        implementor: *anyopaque,
        vtable: *const VTable,

        const RESET = options.reset;
        const GOTO_PREV = options.goto_left_sibling;
        const GOTO_NEXT = options.goto_right_sibling;
        const GOTO_LEFT = options.goto_left_children;
        const GOTO_RIGHT = options.goto_right_sibling;
        const GOTO_PARENT = options.goto_parent;
        const HAS_SLOTS = options.state_slots > 0;
        const SLOTS = options.state_slots;
        pub const T = options.elem_type;

        pub const VTable = struct {
            /// Reset the Traverser to its initial state,
            /// returning `false` if the implementation cannot
            /// reset or some other condition prevented it,
            reset: *const fn (implementor: *anyopaque) bool,
            /// Save the current Traverser state for future reload,
            /// return `false` if implementation does not support
            /// saving state or some other condition prevented it
            save_state: *const fn (implementor: *anyopaque, state_slot: u32) bool,
            /// Reload the state saved in specified slot,
            /// return `false` if implementation does not support
            /// reloading state or some other condition prevented it
            /// (for example no state was previously saved to the slot)
            load_state: *const fn (implementor: *anyopaque, state_slot: u32) bool,
            /// Return the value at the current traverser position
            get_current: *const fn (implementor: *anyopaque) T,
            /// Move traverser position to the next 'sibling' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            goto_next: *const fn (implementor: *anyopaque) bool,
            /// Move traverser position to the prev 'sibling' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            goto_prev: *const fn (implementor: *anyopaque) bool,
            /// Move traverser position to the 'left child(ren)' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            goto_left_child: *const fn (implementor: *anyopaque) bool,
            /// Move traverser position to the 'right child(ren)' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            goto_right_child: *const fn (implementor: *anyopaque) bool,
            /// Move traverser position to the 'parent' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            goto_parent: *const fn (implementor: *anyopaque) bool,
        };
        const Self = @This();
        pub const NO_FN = struct {
            fn reset(implementor: *anyopaque) bool {
                _ = implementor;
                return false;
            }
            fn save_state(implementor: *anyopaque, state_slot: u32) bool {
                _ = implementor;
                _ = state_slot;
                return false;
            }
            fn load_state(implementor: *anyopaque, state_slot: u32) bool {
                _ = implementor;
                _ = state_slot;
                return false;
            }
            /// Return the value at the current traverser position
            fn get_current(implementor: *anyopaque) T {
                _ = implementor;
                return undefined;
            }
            /// Move traverser position to the next 'sibling' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            fn goto_next(implementor: *anyopaque) bool {
                _ = implementor;
                return false;
            }
            /// Move traverser position to the prev 'sibling' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            fn goto_prev(implementor: *anyopaque) bool {
                _ = implementor;
                return false;
            }
            /// Move traverser position to the 'left child(ren)' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            fn goto_left_child(implementor: *anyopaque) bool {
                _ = implementor;
                return false;
            }
            /// Move traverser position to the 'right child(ren)' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            fn goto_right_child(implementor: *anyopaque) bool {
                _ = implementor;
                return false;
            }
            /// Move traverser position to the 'parent' position,
            ///
            /// Returns `true` if the movement suceeded, `false` otherwise
            fn goto_parent(implementor: *anyopaque) bool {
                _ = implementor;
                return false;
            }
        };
        pub const NO_OPS = VTable{
            .reset = NO_FN.reset,
            .save_state = NO_FN.save_state,
            .load_state = NO_FN.load_state,
            .get_current = NO_FN.get_current,
            .goto_next = NO_FN.goto_next,
            .goto_prev = NO_FN.goto_prev,
            .goto_left_child = NO_FN.goto_left_child,
            .goto_right_child = NO_FN.goto_right_child,
            .goto_parent = NO_FN.goto_parent,
        };
        pub const ForwardTraversalOptions = struct {
            before_left_children: ?*const fn (stack: []const TraverseStackFrame, userdata: ?*anyopaque) void,
            after_left_children_before_right_children: ?*const fn (stack: []const TraverseStackFrame, userdata: ?*anyopaque) void,
            after_right_children: ?*const fn (stack: []const TraverseStackFrame, userdata: ?*anyopaque) void,
            initial_stack_capacity: comptime_int = 8,
            stack_growth_model: GrowthModel = .GROW_BY_25_PERCENT,
            stack_index_type: type = u16,
        };
        pub const BackwardTraversalOptions = struct {
            before_right_children: ?*const fn (stack: []const TraverseStackFrame, userdata: ?*anyopaque) void,
            after_right_children_before_left_children: ?*const fn (stack: []const TraverseStackFrame, userdata: ?*anyopaque) void,
            after_left_children: ?*const fn (stack: []const TraverseStackFrame, userdata: ?*anyopaque) void,
            initial_stack_capacity: comptime_int = 8,
            stack_growth_model: GrowthModel = .GROW_BY_25_PERCENT,
            stack_index_type: type = u16,
        };

        pub inline fn reset(self: Self) bool {
            return self.vtable.reset(self.implementor);
        }
        pub inline fn save_state(self: Self, state_slot: usize) bool {
            return self.vtable.save_state(self.implementor, state_slot);
        }
        pub inline fn load_state(self: Self, state_slot: usize) bool {
            return self.vtable.load_state(self.implementor, state_slot);
        }
        pub inline fn get_current(self: Self) T {
            return self.vtable.get_current(self.implementor);
        }
        pub inline fn goto_next(self: Self) bool {
            return self.vtable.goto_next(self.implementor);
        }
        pub inline fn goto_prev(self: Self) bool {
            return self.vtable.goto_prev(self.implementor);
        }
        pub inline fn goto_left_child(self: Self) bool {
            return self.vtable.goto_left_child(self.implementor);
        }
        pub inline fn goto_right_child(self: Self) bool {
            return self.vtable.goto_right_child(self.implementor);
        }
        pub inline fn goto_parent(self: Self) bool {
            return self.vtable.goto_parent(self.implementor);
        }
        pub fn goto_nth_next(self: Self, count: usize) usize {
            var i: usize = 0;
            while (i < count) {
                if (self.vtable.goto_next(self.implementor)) {
                    i += 1;
                } else break;
            }
            return i;
        }
        pub fn goto_nth_prev(self: Self, count: usize) usize {
            var i: usize = 0;
            while (i < count) {
                if (self.vtable.goto_prev(self.implementor)) {
                    i += 1;
                } else break;
            }
            return i;
        }
        pub const TraverseStackFrame = struct {
            curr_item: T,
            pos: TraversePos,
        };
        fn curr_trav_frame(self: *Self, pos: TraversePos) TraverseStackFrame {
            return TraverseStackFrame{
                .curr_item = self.vtable.get_current(self.implementor),
                .pos = pos,
            };
        }
        pub fn traverse_forward_and_perform_actions_on_all_items_depth_first(self: Self, comptime fwd_options: ForwardTraversalOptions, userdata: ?*anyopaque, stack_allocator: AllocInfal) bool {
            var stack = Root.List.List(Root.List.ListOptions{
                .alignment = null,
                .assert_correct_allocator = false,
                .element_type = TraverseStackFrame,
                .growth_model = fwd_options.stack_growth_model,
                .index_type = fwd_options.stack_index_type,
                .memset_uninit_val = null,
                .secure_wipe_bytes = false,
            }).new_with_capacity(fwd_options.initial_stack_capacity, stack_allocator);
            defer stack.clear_and_free(stack_allocator);
            stack.append(self.curr_trav_frame(.LEFTMOST), stack_allocator);
            loop: while (true) {
                const last_stack: *TraverseStackFrame = stack.get_last_ptr();
                if (last_stack.pos == .LEFTMOST) {
                    if (fwd_options.before_left_children != null) {
                        fwd_options.before_left_children(stack.slice(), userdata);
                    }
                    last_stack.pos = .ON_LEFT_CHILD;
                    if (GOTO_LEFT and self.vtable.goto_left_child(self.implementor)) {
                        stack.append(self.curr_trav_frame(.LEFTMOST), stack_allocator);
                        continue :loop;
                    }
                }
                if (last_stack.pos == .ON_LEFT_CHILD) {
                    last_stack.pos = .BETWEEN_LEFT_AND_RIGHT;
                    if (fwd_options.after_left_children_before_right_children != null) {
                        fwd_options.after_left_children_before_right_children(stack.slice(), userdata);
                    }
                    last_stack.pos = .ON_RIGHT_CHILD;
                    if (GOTO_RIGHT and self.vtable.goto_right_child(self.implementor)) {
                        stack.append(self.curr_trav_frame(.LEFTMOST), stack_allocator);
                        continue :loop;
                    }
                }
                if (last_stack.pos == .ON_RIGHT_CHILD) {
                    last_stack.pos = .RIGHTMOST;
                    if (fwd_options.after_right_children != null) {
                        fwd_options.after_right_children(stack.slice(), userdata);
                    }
                }
                if (GOTO_NEXT and self.vtable.goto_next(self.implementor)) {
                    last_stack.* = self.curr_trav_frame(.LEFTMOST);
                    continue :loop;
                }
                if (GOTO_PARENT and self.vtable.goto_parent(self.implementor)) {
                    stack.len -= 1;
                    continue :loop;
                }
                break;
            }
        }
        pub fn traverse_backward_and_perform_actions_on_all_items_depth_first(self: Self, comptime bkwd_options: BackwardTraversalOptions, userdata: ?*anyopaque, stack_allocator: AllocInfal) bool {
            var stack = Root.List.List(Root.List.ListOptions{
                .alignment = null,
                .assert_correct_allocator = false,
                .element_type = TraverseStackFrame,
                .growth_model = bkwd_options.stack_growth_model,
                .index_type = bkwd_options.stack_index_type,
                .memset_uninit_val = null,
                .secure_wipe_bytes = false,
            }).new_with_capacity(bkwd_options.initial_stack_capacity, stack_allocator);
            stack.append(self.curr_trav_frame(.RIGHTMOST), stack_allocator);
            loop: while (true) {
                const last_stack: *TraverseStackFrame = stack.get_last_ptr();
                if (last_stack.pos == .RIGHTMOST) {
                    if (bkwd_options.before_right_children != null) {
                        bkwd_options.before_right_children(stack.slice(), userdata);
                    }
                    last_stack.pos = .ON_RIGHT_CHILD;
                    if (GOTO_RIGHT and self.vtable.goto_right_child(self.implementor)) {
                        stack.append(self.curr_trav_frame(.RIGHTMOST), stack_allocator);
                        continue :loop;
                    }
                }
                if (last_stack.pos == .ON_RIGHT_CHILD) {
                    last_stack.pos = .BETWEEN_LEFT_AND_RIGHT;
                    if (bkwd_options.after_right_children_before_left_children != null) {
                        bkwd_options.after_right_children_before_left_children(stack.slice(), userdata);
                    }
                    last_stack.pos = .ON_LEFT_CHILD;
                    if (GOTO_LEFT and self.vtable.goto_left_child(self.implementor)) {
                        stack.append(self.curr_trav_frame(.RIGHTMOST), stack_allocator);
                        continue :loop;
                    }
                }
                if (last_stack.pos == .ON_LEFT_CHILD) {
                    last_stack.pos = .LEFTMOST;
                    if (bkwd_options.after_left_children != null) {
                        bkwd_options.after_left_children(stack.slice(), userdata);
                    }
                }
                if (GOTO_PREV and self.vtable.goto_prev(self.implementor)) {
                    last_stack.* = self.curr_trav_frame(.RIGHTMOST);
                    continue :loop;
                }
                if (GOTO_PARENT and self.vtable.goto_parent(self.implementor)) {
                    stack.len -= 1;
                    continue :loop;
                }
                break;
            }
        }
        // pub fn perform_action_on_next_n_items(self: Self, count: usize, action: *const fn (item: T, userdata: ?*anyopaque) void, userdata: ?*anyopaque) usize {
        //     var item_or_null: ?T = self.vtable.peek_next_or_null(self.implementor);
        //     if (item_or_null == null) return 0;
        //     var i: usize = 0;
        //     while (item_or_null != null and i < count) {
        //         _ = self.vtable.advance_next(self.implementor);
        //         action(item_or_null.?, userdata);
        //         item_or_null = self.vtable.peek_next_or_null(self.implementor);
        //         i += 1;
        //     }
        //     return i;
        // }
        // pub fn perform_action_on_all_prev_items(self: Self, action: *const fn (item: T, userdata: ?*anyopaque) void, userdata: ?*anyopaque) bool {
        //     var item_or_null: ?T = self.vtable.peek_prev_or_null(self.implementor);
        //     if (item_or_null == null) return false;
        //     while (item_or_null != null) {
        //         _ = self.vtable.advance_prev(self.implementor);
        //         action(item_or_null.?, userdata);
        //         item_or_null = self.vtable.peek_prev_or_null(self.implementor);
        //     }
        //     return true;
        // }
        // pub fn perform_action_on_prev_n_items(self: Self, count: usize, action: *const fn (item: T, userdata: ?*anyopaque) void, userdata: ?*anyopaque) usize {
        //     var item_or_null: ?T = self.vtable.peek_prev_or_null(self.implementor);
        //     if (item_or_null == null) return 0;
        //     var i: usize = 0;
        //     while (item_or_null != null and i < count) {
        //         _ = self.vtable.advance_prev(self.implementor);
        //         action(item_or_null.?, userdata);
        //         item_or_null = self.vtable.peek_prev_or_null(self.implementor);
        //         i += 1;
        //     }
        //     return i;
        // }
        // pub fn find_next_item_that_matches_filter(self: Self, filter: *const fn (item: T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) ?T {
        //     var item_or_null: ?T = self.vtable.peek_next_or_null(self.implementor);
        //     if (item_or_null == null) return null;
        //     while (item_or_null != null) {
        //         _ = self.vtable.advance_next(self.implementor);
        //         if (filter(item_or_null.?, userdata)) return item_or_null.?;
        //         item_or_null = self.vtable.peek_next_or_null(self.implementor);
        //     }
        //     return null;
        // }
        // pub fn find_next_n_items_that_match_filter(self: Self, count: usize, out_buffer: []T, filter: *const fn (item: T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) usize {
        //     assert_with_reason(count <= out_buffer.len, @src(), "`out_buffer` is too small to hold the requested {d} values", .{count});
        //     var item_or_null: ?T = self.vtable.peek_next_or_null(self.implementor);
        //     if (item_or_null == null) return 0;
        //     var i: usize = 0;
        //     while (item_or_null != null and i < count) {
        //         _ = self.vtable.advance_next(self.implementor);
        //         if (filter(item_or_null.?, userdata)) {
        //             out_buffer[i] = item_or_null.?;
        //             i += 1;
        //         }
        //         item_or_null = self.vtable.peek_next_or_null(self.implementor);
        //     }
        //     return i;
        // }
        // pub fn find_next_n_items_that_match_filter_to_array(self: Self, comptime count: usize, filter: *const fn (item: T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) ArrayLen(count, T) {
        //     var item_or_null: ?T = self.vtable.peek_next_or_null(self.implementor);
        //     if (item_or_null == null) return 0;
        //     var result = ArrayLen(count, *T){ .arr = undefined, .len = 0 };
        //     while (item_or_null != null and result.len < count) {
        //         _ = self.vtable.advance_next(self.implementor);
        //         if (filter(item_or_null.?, userdata)) {
        //             result.arr[result.len] = item_or_null.?;
        //             result.len += 1;
        //         }
        //         item_or_null = self.vtable.peek_next_or_null(self.implementor);
        //     }
        //     return result;
        // }
        // pub fn find_prev_item_that_matches_filter(self: Self, filter: *const fn (item: T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) ?T {
        //     var item_or_null: ?T = self.vtable.peek_prev_or_null(self.implementor);
        //     if (item_or_null == null) return null;
        //     while (item_or_null != null) {
        //         _ = self.vtable.advance_prev(self.implementor);
        //         if (filter(item_or_null.?, userdata)) return item_or_null.?;
        //         item_or_null = self.vtable.peek_prev_or_null(self.implementor);
        //     }
        //     return null;
        // }
        // pub fn find_prev_n_items_that_match_filter(self: Self, count: usize, out_buffer: []T, filter: *const fn (item: T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) usize {
        //     assert_with_reason(count <= out_buffer.len, @src(), "`out_buffer` is too small to hold the requested {d} values", .{count});
        //     var item_or_null: ?T = self.vtable.peek_prev_or_null(self.implementor);
        //     if (item_or_null == null) return 0;
        //     var i: usize = 0;
        //     while (item_or_null != null and i < count) {
        //         _ = self.vtable.advance_prev(self.implementor);
        //         if (filter(item_or_null.?, userdata)) {
        //             out_buffer[i] = item_or_null.?;
        //             i += 1;
        //         }
        //         item_or_null = self.vtable.peek_prev_or_null(self.implementor);
        //     }
        //     return i;
        // }
        // pub fn find_prev_n_items_that_match_filter_to_array(self: Self, comptime count: usize, filter: *const fn (item: T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) ArrayLen(count, T) {
        //     var item_or_null: ?T = self.vtable.peek_prev_or_null(self.implementor);
        //     if (item_or_null == null) return 0;
        //     var result = ArrayLen(count, T){ .arr = undefined, .len = 0 };
        //     while (item_or_null != null and result.len < count) {
        //         _ = self.vtable.advance_prev(self.implementor);
        //         if (filter(item_or_null.?, userdata)) {
        //             result.arr[result.len] = item_or_null.?;
        //             result.len += 1;
        //         }
        //         item_or_null = self.vtable.peek_prev_or_null(self.implementor);
        //     }
        //     return result;
        // }
    };
}

pub const TraversePos = enum(u8) {
    LEFTMOST = 0,
    ON_LEFT_CHILD = 1,
    BETWEEN_LEFT_AND_RIGHT = 2,
    ON_RIGHT_CHILD = 3,
    RIGHTMOST = 4,
};
