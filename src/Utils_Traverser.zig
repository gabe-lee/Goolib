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

/// std imports
const Allocator = std.mem.Allocator;
const DEBUG = std.debug.print;
const math = std.math;
// const mem = std.mem;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Type = Root.Types;
const Math = Root.Math;
const KindInfo = Type.KindInfo;
const Assert = Root.Assert;
const Utils = Root.Utils;
const CommonTypes = Root.CommonTypes;
const Test = Root.Testing;
const DummyAlloc = Root.DummyAllocator;
const dummy_alloc = DummyAlloc.allocator_panic_free_noop;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;
const kind_info = KindInfo.get_kind_info;

pub const Error = Utils.Alloc.AllocErr || error{
    index_out_of_bounds,
};

pub const ErrorOld = Utils.Alloc.AllocErr || error{
    index_out_of_bounds,
    stack_mem_out_of_space,
    stack_mem_reallocation_error,
};

pub fn ReallocPackageDef(comptime T: type) type {
    return struct {
        alloc: Allocator,
        settings: Utils.Alloc.SmartAllocSettings(T),
    };
}
pub const MemRealloc = enum {
    STATIC_MEM,
    ALLOW_MEM_REALLOC,

    pub fn T_PKG(comptime self: MemRealloc, comptime ELEM: type) type {
        switch (self) {
            .STATIC_MEM => return void,
            .ALLOW_MEM_REALLOC => return ReallocPackageDef(ELEM),
        }
    }

    pub fn UNION(comptime ELEM: type) type {
        return union(MemRealloc) {
            const Self = @This();

            STATIC_MEM: void,
            ALLOW_MEM_REALLOC: T_PKG(.ALLOW_MEM_REALLOC, ELEM),

            pub fn static_mem() Self {
                return Self{ .STATIC_MEM = void{} };
            }
            pub fn allow_mem_realloc(alloc: Allocator, settings: Utils.Alloc.SmartAllocSettings(ELEM)) Self {
                return Self{ .ALLOW_MEM_REALLOC = T_PKG(.ALLOW_MEM_REALLOC, ELEM){
                    .alloc = alloc,
                    .settings = settings,
                } };
            }
        };
    }
};

pub fn IndexBasedFirstChildNextSiblingTraverser(comptime NODE: type, comptime IDX: type, comptime NULL_IDX: IDX, comptime FIRST_CHILD_FIELD: []const u8, comptime NEXT_SIBLING_FIELD: []const u8) type {
    return struct {
        pub const StackFrame = struct {
            this: IDX,
            next_child: IDX,
        };
        pub const Nodes = struct {
            ptr: [*]NODE,
            len: IDX = 0,
            cap: IDX,
        };
        pub const Stack = struct {
            ptr: [*]StackFrame,
            len: IDX = 0,
            cap: IDX,
        };

        pub fn do_action_on_all_nodes_children_first_comptime_action_body(nodes_: Nodes, stack_: Stack, root: IDX, comptime STACK_REALLOC: MemRealloc, alloc_pkg: STACK_REALLOC.T_PKG(StackFrame), action_userdata: anytype, comptime action: fn (nodes: Nodes, idx: IDX, userdata: @TypeOf(action_userdata)) Nodes) struct { Nodes, Stack, ?ErrorOld } {
            var nodes: Nodes = nodes_;
            var stack: Stack = stack_;
            var err: ?ErrorOld = null;
            if (root == NULL_IDX) {
                return .{ nodes, stack, null };
            }
            if (root >= nodes.len) {
                return .{ nodes, stack, ErrorOld.index_out_of_bounds };
            }
            assert_with_reason(stack.cap >= 2, @src(), "stack capacity must be >= 2", .{});
            stack.ptr[0] = StackFrame{
                .this = root,
                .next_child = @field(&nodes.ptr[root], FIRST_CHILD_FIELD),
            };
            stack.len = 1;
            var curr_depth: IDX = 0;
            var curr_child_idx: IDX = stack.ptr[0].next_child;
            while (true) {
                if (curr_child_idx != NULL_IDX) {
                    if (curr_child_idx >= nodes.len) {
                        err = ErrorOld.index_out_of_bounds;
                        break;
                    }
                    if (stack.len >= stack.cap) {
                        if (comptime STACK_REALLOC == .ALLOW_MEM_REALLOC) {
                            const result = Utils.Alloc.smart_alloc(alloc_pkg.alloc, &stack.ptr, &stack.len, &stack.cap, stack.len + 1, alloc_pkg.settings, .{ .ERROR_MODE = .RETURN_ERRORS });
                            if (result) |_| {} else |_| {
                                err = ErrorOld.stack_mem_reallocation_error;
                                break;
                            }
                        } else {
                            err = ErrorOld.stack_mem_out_of_space;
                            break;
                        }
                    }
                    stack.ptr[curr_depth].next_child = @field(&nodes.ptr[curr_child_idx], NEXT_SIBLING_FIELD);
                    stack.ptr[stack.len] = StackFrame{
                        .this = curr_child_idx,
                        .next_child = @field(&nodes.ptr[curr_child_idx], FIRST_CHILD_FIELD),
                    };
                    curr_depth = stack.len;
                    stack.len += 1;
                    curr_child_idx = stack.ptr[curr_depth].next_child;
                } else {
                    const idx_to_process = stack.ptr[curr_depth].this;
                    nodes = action(nodes, idx_to_process, action_userdata);
                    stack.len = curr_depth;
                    if (curr_depth == 0) break;
                    curr_depth -= 1;
                    curr_child_idx = stack.ptr[curr_depth].next_child;
                }
            }
            return .{ nodes, stack, err };
        }

        pub fn do_action_on_all_nodes_children_first(nodes_: Nodes, stack_: Stack, root: IDX, comptime STACK_REALLOC: MemRealloc, alloc_pkg: STACK_REALLOC.T_PKG(StackFrame), action_userdata: anytype, comptime action: *const fn (nodes: Nodes, idx: IDX, userdata: @TypeOf(action_userdata)) Nodes) struct { Nodes, Stack, ?ErrorOld } {
            var nodes: Nodes = nodes_;
            var stack: Stack = stack_;
            var err: ?ErrorOld = null;
            if (root == NULL_IDX) {
                return .{ nodes, stack, null };
            }
            if (root >= nodes.len) {
                return .{ nodes, stack, ErrorOld.index_out_of_bounds };
            }
            assert_with_reason(stack.cap >= 2, @src(), "stack capacity must be >= 2", .{});
            stack.ptr[0] = StackFrame{
                .this = root,
                .next_child = @field(&nodes.ptr[root], FIRST_CHILD_FIELD),
            };
            stack.len = 1;
            var curr_depth: IDX = 0;
            var curr_child_idx: IDX = stack.ptr[0].next_child;
            while (true) {
                if (curr_child_idx != NULL_IDX) {
                    if (curr_child_idx >= nodes.len) {
                        err = ErrorOld.index_out_of_bounds;
                        break;
                    }
                    if (stack.len >= stack.cap) {
                        if (comptime STACK_REALLOC == .ALLOW_MEM_REALLOC) {
                            const result = Utils.Alloc.smart_alloc(alloc_pkg.alloc, &stack.ptr, &stack.len, &stack.cap, stack.len + 1, alloc_pkg.settings, .{ .ERROR_MODE = .RETURN_ERRORS });
                            if (result) |_| {} else |_| {
                                err = ErrorOld.stack_mem_reallocation_error;
                                break;
                            }
                        } else {
                            err = ErrorOld.stack_mem_out_of_space;
                            break;
                        }
                    }
                    stack.ptr[curr_depth].next_child = @field(&nodes.ptr[curr_child_idx], NEXT_SIBLING_FIELD);
                    stack.ptr[stack.len] = StackFrame{
                        .this = curr_child_idx,
                        .next_child = @field(&nodes.ptr[curr_child_idx], FIRST_CHILD_FIELD),
                    };
                    curr_depth = stack.len;
                    stack.len += 1;
                    curr_child_idx = stack.ptr[curr_depth].next_child;
                } else {
                    const idx_to_process = stack.ptr[curr_depth].this;
                    nodes = action(nodes, idx_to_process, action_userdata);
                    stack.len = curr_depth;
                    if (curr_depth == 0) break;
                    curr_depth -= 1;
                    curr_child_idx = stack.ptr[curr_depth].next_child;
                }
            }
            return .{ nodes, stack, err };
        }

        pub fn do_action_on_all_nodes_parents_first_comptime_action_body(nodes_: Nodes, stack_: Stack, root: IDX, comptime STACK_REALLOC: MemRealloc, alloc_pkg: STACK_REALLOC.T_PKG(StackFrame), action_userdata: anytype, comptime action: fn (nodes: Nodes, idx: IDX, userdata: @TypeOf(action_userdata)) Nodes) struct { Nodes, Stack, ?ErrorOld } {
            var nodes: Nodes = nodes_;
            var stack: Stack = stack_;
            var err: ?ErrorOld = null;
            if (root == NULL_IDX) {
                return .{ nodes, stack, null };
            }
            if (root >= nodes.len) {
                return .{ nodes, stack, ErrorOld.index_out_of_bounds };
            }
            assert_with_reason(stack.cap >= 2, @src(), "stack capacity must be >= 2", .{});
            nodes = action(nodes, root, action_userdata);
            stack.ptr[0] = StackFrame{
                .this = root,
                .next_child = @field(&nodes.ptr[root], FIRST_CHILD_FIELD),
            };
            stack.len = 1;
            var curr_depth: IDX = 0;
            var curr_child_idx: IDX = stack.ptr[0].next_child;
            while (true) {
                if (curr_child_idx != NULL_IDX) {
                    if (curr_child_idx >= nodes.len) {
                        err = ErrorOld.index_out_of_bounds;
                        break;
                    }
                    if (stack.len >= stack.cap) {
                        if (comptime STACK_REALLOC == .ALLOW_MEM_REALLOC) {
                            const result = Utils.Alloc.smart_alloc(alloc_pkg.alloc, &stack.ptr, &stack.len, &stack.cap, stack.len + 1, alloc_pkg.settings, .{ .ERROR_MODE = .RETURN_ERRORS });
                            if (result) |_| {} else |_| {
                                err = ErrorOld.stack_mem_reallocation_error;
                                break;
                            }
                        } else {
                            err = ErrorOld.stack_mem_out_of_space;
                            break;
                        }
                    }
                    stack.ptr[curr_depth].next_child = @field(&nodes.ptr[curr_child_idx], NEXT_SIBLING_FIELD);
                    const idx_to_process = curr_child_idx;
                    nodes = action(nodes, idx_to_process, action_userdata);
                    stack.ptr[stack.len] = StackFrame{
                        .this = curr_child_idx,
                        .next_child = @field(&nodes.ptr[curr_child_idx], FIRST_CHILD_FIELD),
                    };
                    curr_depth = stack.len;
                    stack.len += 1;
                    curr_child_idx = stack.ptr[curr_depth].next_child;
                } else {
                    stack.len = curr_depth;
                    if (curr_depth == 0) break;
                    curr_depth -= 1;
                    curr_child_idx = stack.ptr[curr_depth].next_child;
                }
            }
            return .{ nodes, stack, err };
        }

        pub fn do_action_on_all_nodes_parents_first(nodes_: Nodes, stack_: Stack, root: IDX, comptime STACK_REALLOC: MemRealloc, alloc_pkg: STACK_REALLOC.T_PKG(StackFrame), action_userdata: anytype, comptime action: *const fn (nodes: Nodes, idx: IDX, userdata: @TypeOf(action_userdata)) Nodes) struct { Nodes, Stack, ?ErrorOld } {
            var nodes: Nodes = nodes_;
            var stack: Stack = stack_;
            var err: ?ErrorOld = null;
            if (root == NULL_IDX) {
                return .{ nodes, stack, null };
            }
            if (root >= nodes.len) {
                return .{ nodes, stack, ErrorOld.index_out_of_bounds };
            }
            assert_with_reason(stack.cap >= 2, @src(), "stack capacity must be >= 2", .{});
            nodes = action(nodes, root, action_userdata);
            stack.ptr[0] = StackFrame{
                .this = root,
                .next_child = @field(&nodes.ptr[root], FIRST_CHILD_FIELD),
            };
            stack.len = 1;
            var curr_depth: IDX = 0;
            var curr_child_idx: IDX = stack.ptr[0].next_child;
            while (true) {
                if (curr_child_idx != NULL_IDX) {
                    if (curr_child_idx >= nodes.len) {
                        err = ErrorOld.index_out_of_bounds;
                        break;
                    }
                    if (stack.len >= stack.cap) {
                        if (comptime STACK_REALLOC == .ALLOW_MEM_REALLOC) {
                            const result = Utils.Alloc.smart_alloc(alloc_pkg.alloc, &stack.ptr, &stack.len, &stack.cap, stack.len + 1, alloc_pkg.settings, .{ .ERROR_MODE = .RETURN_ERRORS });
                            if (result) |_| {} else |_| {
                                err = ErrorOld.stack_mem_reallocation_error;
                                break;
                            }
                        } else {
                            err = ErrorOld.stack_mem_out_of_space;
                            break;
                        }
                    }
                    stack.ptr[curr_depth].next_child = @field(&nodes.ptr[curr_child_idx], NEXT_SIBLING_FIELD);
                    const idx_to_process = curr_child_idx;
                    nodes = action(nodes, idx_to_process, action_userdata);
                    stack.ptr[stack.len] = StackFrame{
                        .this = curr_child_idx,
                        .next_child = @field(&nodes.ptr[curr_child_idx], FIRST_CHILD_FIELD),
                    };
                    curr_depth = stack.len;
                    stack.len += 1;
                    curr_child_idx = stack.ptr[curr_depth].next_child;
                } else {
                    stack.len = curr_depth;
                    if (curr_depth == 0) break;
                    curr_depth -= 1;
                    curr_child_idx = stack.ptr[curr_depth].next_child;
                }
            }
            return .{ nodes, stack, err };
        }
    };
}

pub const Order = enum {
    CHILDREN_FIRST,
    PARENTS_FIRST,
    ANY_ORDER_MIGHT_HAVE_IDX_GAPS,
    ANY_ORDER_NO_IDX_GAPS_ROOT_IDX_TO_LAST_IDX,
};

pub const FuncType = enum {
    RUNTIME_FN_PTR,
    COMPTIME_FN_PTR,
    COMPTIME_FN_BODY,
};

pub fn IndexBasedMultiFirstChildNextSiblingTraverser(comptime NODE: type, comptime IDX: type, comptime NULL_IDX: IDX, comptime FIRST_CHILD_FIELDS: []const []const u8, comptime NEXT_SIBLING_FIELD: []const u8) type {
    return struct {
        const NUM_CHILD_PATHS = FIRST_CHILD_FIELDS.len;
        pub fn CTFN(comptime self: FuncType, comptime USERDATA_RT: type, comptime USERDATA_CT: type) type {
            return switch (self) {
                .RUNTIME_FN_PTR => void,
                .COMPTIME_FN_PTR => *const fn (nodes: Nodes, idx: IDX, userdata: USERDATA_RT, comptime USERDATA: USERDATA_CT) anyerror!Nodes,
                .COMPTIME_FN_BODY => fn (nodes: Nodes, idx: IDX, userdata: USERDATA_RT, comptime USERDATA: USERDATA_CT) anyerror!Nodes,
            };
        }
        pub fn RTFN(comptime self: FuncType, comptime USERDATA_RT: type, comptime USERDATA_CT: type) type {
            return switch (self) {
                .RUNTIME_FN_PTR => *const fn (nodes: Nodes, idx: IDX, userdata: USERDATA_RT, USERDATA: USERDATA_CT) anyerror!Nodes,
                .COMPTIME_FN_PTR => void,
                .COMPTIME_FN_BODY => void,
            };
        }

        pub const StackReallocator = struct {
            object: *anyopaque,
            realloc_impl: *const fn (obj: *anyopaque, old_stack: Stack, needed_extra_frames: u32) Utils.Alloc.AllocErr!Stack,

            pub fn realloc(self: StackReallocator, old_stack: Stack, needed_extra_frames: u32) Utils.Alloc.AllocErr!Stack {
                return self.realloc_impl(self.object, old_stack, needed_extra_frames);
            }

            pub fn no_stack_reallocation() StackReallocator {
                return StackReallocator{
                    .object = @ptrCast(Utils.invalid_ptr(u8)),
                    .realloc_impl = realloc_always_err,
                };
            }
        };
        fn realloc_always_err(_: *anyopaque, _: Stack, _: u32) Utils.Alloc.AllocErr!Stack {
            return Utils.Alloc.AllocErr.OutOfMemory;
        }

        pub const StackFrame = struct {
            this: IDX,
            next_child_for_each_path: [NUM_CHILD_PATHS]IDX,
            curr_path: IDX,
        };
        pub const Nodes = struct {
            ptr: [*]NODE = Utils.invalid_ptr_many(NODE),
            len: IDX = 0,
            cap: IDX = 0,
        };
        pub const Stack = struct {
            ptr: [*]StackFrame = Utils.invalid_ptr_many(StackFrame),
            len: IDX = 0,
            cap: IDX = 0,
        };
        pub const AllowedPaths = union(enum) {
            ALL: void,
            WHITELIST: [NUM_CHILD_PATHS]bool,

            pub fn all_child_paths() AllowedPaths {
                return AllowedPaths{ .ALL = void{} };
            }
            pub fn only_child_paths(comptime paths: []const []const u8) AllowedPaths {
                return AllowedPaths{ .WHITELIST = comptime make: {
                    var out: [NUM_CHILD_PATHS]bool = @splat(false);
                    next_allowed: for (paths) |allowed_path| {
                        for (FIRST_CHILD_FIELDS, 0..) |path, p| {
                            if (std.mem.eql(u8, path, allowed_path)) {
                                out[p] = true;
                                continue :next_allowed;
                            }
                        }
                    }
                    break :make out;
                } };
            }
            pub fn exclude_child_paths(comptime paths: []const []const u8) AllowedPaths {
                return AllowedPaths{
                    .WHITELIST = comptime make: {
                        var out: [NUM_CHILD_PATHS]bool = @splat(true);
                        next_excluded: for (paths) |excluded_path| {
                            for (FIRST_CHILD_FIELDS, 0..) |path, p| {
                                if (std.mem.eql(u8, path, excluded_path)) {
                                    out[p] = false;
                                    continue :next_excluded;
                                }
                            }
                        }
                        break :make out;
                    },
                };
            }
            inline fn path_is_allowed(comptime self: AllowedPaths, comptime path_idx: IDX) bool {
                switch (comptime self) {
                    .ALL => {
                        return true;
                    },
                    .WHITELIST => |ALLOWED| {
                        return ALLOWED[path_idx];
                    },
                }
            }
        };

        inline fn get_next_child(stack: Stack, depth: IDX) IDX {
            return stack.ptr[depth].next_child_for_each_path[stack.ptr[depth].curr_path];
        }
        inline fn push_stack_frame(nodes: Nodes, stack: Stack, realloc: StackReallocator, root: IDX, comptime allowed_paths: AllowedPaths) anyerror!struct { Stack, IDX } {
            var new_stack = stack;
            try grow_stack_if_needed(&new_stack, realloc);
            new_stack.ptr[new_stack.len] = StackFrame{
                .this = root,
                .next_child_for_each_path = make: {
                    var out: [NUM_CHILD_PATHS]IDX = undefined;
                    inline for (FIRST_CHILD_FIELDS, 0..) |FIRST_CHILD_FIELD, i| {
                        if (comptime allowed_paths.path_is_allowed(@intCast(i))) {
                            out[i] = @field(&nodes.ptr[root], FIRST_CHILD_FIELD);
                        } else {
                            out[i] = NULL_IDX;
                        }
                    }
                    break :make out;
                },
                .curr_path = 0,
            };
            const new_depth = new_stack.len;
            new_stack.len += 1;
            return .{ new_stack, new_depth };
        }
        inline fn increment_next_child(nodes: Nodes, stack: Stack, depth: IDX, curr_child_idx: IDX) void {
            var next = @field(&nodes.ptr[curr_child_idx], NEXT_SIBLING_FIELD);
            stack.ptr[depth].next_child_for_each_path[stack.ptr[depth].curr_path] = next;
            while (next == NULL_IDX and stack.ptr[depth].curr_path < (NUM_CHILD_PATHS - 1)) {
                stack.ptr[depth].curr_path += 1;
                next = stack.ptr[depth].next_child_for_each_path[stack.ptr[depth].curr_path];
            }
        }
        inline fn grow_stack_if_needed(stack: *Stack, realloc: StackReallocator) Utils.Alloc.AllocErr!void {
            if (stack.len >= stack.cap) {
                stack.* = try realloc.realloc(stack.*, 1);
            }
        }
        inline fn pop_stack_frame(stack: Stack, depth: IDX) struct { Stack, IDX, bool } {
            var new_stack = stack;
            new_stack.len = depth;
            const more_to_process = depth > 0;
            const new_depth = @max(1, depth) - 1;
            return .{ new_stack, new_depth, more_to_process };
        }
        inline fn do_action(nodes: Nodes, idx: IDX, userdata: anytype, comptime USERDATA_CT: anytype, comptime FN_TYPE: FuncType, comptime FUNC: CTFN(FN_TYPE, @TypeOf(userdata), @TypeOf(USERDATA_CT)), func: RTFN(FN_TYPE, @TypeOf(userdata), @TypeOf(USERDATA_CT))) anyerror!Nodes {
            return switch (comptime FN_TYPE) {
                .RUNTIME_FN_PTR => try func(nodes, idx, userdata, USERDATA_CT),
                .COMPTIME_FN_BODY, .COMPTIME_FN_PTR => try FUNC(nodes, idx, userdata, USERDATA_CT),
            };
        }
        inline fn do_action_on_all_nodes_unordered_no_gaps(nodes_: Nodes, root: u32, action_context_rt: anytype, comptime ACTION_CONTEXT_CT: anytype, comptime FN_TYPE: FuncType, comptime ACTION_CT: CTFN(FN_TYPE, @TypeOf(action_context_rt), @TypeOf(ACTION_CONTEXT_CT)), action_rt: RTFN(FN_TYPE, @TypeOf(action_context_rt), @TypeOf(ACTION_CONTEXT_CT))) anyerror!Nodes {
            var nodes: Nodes = nodes_;
            var idx: u32 = root;
            while (idx < nodes.len) : (idx += 1) {
                nodes = try do_action(nodes, idx, action_context_rt, ACTION_CONTEXT_CT, FN_TYPE, ACTION_CT, action_rt);
            }
        }
        pub fn do_action_on_all_nodes(nodes_: Nodes, stack_: Stack, stack_realloc: StackReallocator, comptime ORDER: Order, comptime allowed_paths: AllowedPaths, root: IDX, action_context_rt: anytype, comptime ACTION_CONTEXT_CT: anytype, comptime FN_TYPE: FuncType, comptime ACTION_CT: CTFN(FN_TYPE, @TypeOf(action_context_rt), @TypeOf(ACTION_CONTEXT_CT)), action_rt: RTFN(FN_TYPE, @TypeOf(action_context_rt), @TypeOf(ACTION_CONTEXT_CT))) anyerror!struct { Nodes, Stack } {
            var nodes: Nodes = nodes_;
            if (comptime ORDER == .ANY_ORDER_NO_IDX_GAPS_ROOT_IDX_TO_LAST_IDX) {
                nodes = try do_action_on_all_nodes_unordered_no_gaps(nodes, root, action_context_rt, ACTION_CONTEXT_CT, FN_TYPE, ACTION_CT, action_rt);
                return .{ nodes, stack_ };
            }
            var stack: Stack = stack_;
            stack.len = 0;
            if (root == NULL_IDX) {
                return .{ nodes, stack };
            }
            if (root >= nodes.len) {
                return Error.index_out_of_bounds;
            }
            assert_with_reason(stack.cap >= 2, @src(), "stack capacity must be >= 2", .{});
            if (comptime ORDER == .PARENTS_FIRST or ORDER == .ANY_ORDER_MIGHT_HAVE_IDX_GAPS) {
                nodes = try do_action(nodes, root, action_context_rt, ACTION_CONTEXT_CT, FN_TYPE, ACTION_CT, action_rt);
            }
            stack, var depth = try push_stack_frame(nodes, stack, stack_realloc, root, allowed_paths);
            var more_to_process: bool = true;
            loop: while (more_to_process) {
                const curr_child_idx = get_next_child(stack, depth);
                if (curr_child_idx != NULL_IDX) {
                    if (curr_child_idx >= nodes.len) {
                        return Error.index_out_of_bounds;
                    }
                    try grow_stack_if_needed(&stack, stack_realloc);
                    increment_next_child(nodes, stack, depth, curr_child_idx);
                    if (comptime ORDER == .PARENTS_FIRST or ORDER == .ANY_ORDER_MIGHT_HAVE_IDX_GAPS) {
                        nodes = try do_action(nodes, curr_child_idx, action_context_rt, ACTION_CONTEXT_CT, FN_TYPE, ACTION_CT, action_rt);
                    }
                    stack, depth = try push_stack_frame(nodes, stack, stack_realloc, curr_child_idx, allowed_paths);
                    continue :loop;
                }
                if (comptime ORDER == .CHILDREN_FIRST) {
                    nodes = try do_action(nodes, stack.ptr[depth].this, action_context_rt, ACTION_CONTEXT_CT, FN_TYPE, ACTION_CT, action_rt);
                }
                stack, depth, more_to_process = pop_stack_frame(stack, depth);
            }
            return .{ nodes, stack };
        }
    };
}

test IndexBasedFirstChildNextSiblingTraverser {
    //    I
    //   / \
    //  G   H
    // /|\ /|\
    // ABC DEF
    const I: u8 = 0;
    const G: u8 = 1;
    const H: u8 = 2;
    const A: u8 = 3;
    const B: u8 = 4;
    const C: u8 = 5;
    const D: u8 = 6;
    const E: u8 = 7;
    const F: u8 = 8;
    const AA: u8 = 9;
    const BB: u8 = 10;
    const CC: u8 = 11;
    const DD: u8 = 12;
    const EE: u8 = 13;
    const FF: u8 = 14;
    const NULL: u8 = 255;
    const Node = struct {
        char: u8,
        first_child: u8,
        next_sibling: u8,
    };
    const NodeDual = struct {
        char: u8,
        first_child_lower: u8,
        first_child_upper: u8,
        next_sibling: u8,
    };
    var mem: [9]Node = undefined;
    var mem_dual: [15]NodeDual = undefined;
    mem[I] = Node{
        .char = 'i',
        .first_child = G,
        .next_sibling = NULL,
    };
    mem[G] = Node{
        .char = 'g',
        .first_child = A,
        .next_sibling = H,
    };
    mem[H] = Node{
        .char = 'h',
        .first_child = D,
        .next_sibling = NULL,
    };
    mem[A] = Node{
        .char = 'a',
        .first_child = NULL,
        .next_sibling = B,
    };
    mem[B] = Node{
        .char = 'b',
        .first_child = NULL,
        .next_sibling = C,
    };
    mem[C] = Node{
        .char = 'c',
        .first_child = NULL,
        .next_sibling = NULL,
    };
    mem[D] = Node{
        .char = 'd',
        .first_child = NULL,
        .next_sibling = E,
    };
    mem[E] = Node{
        .char = 'e',
        .first_child = NULL,
        .next_sibling = F,
    };
    mem[F] = Node{
        .char = 'f',
        .first_child = NULL,
        .next_sibling = NULL,
    };
    mem_dual[I] = NodeDual{
        .char = 'i',
        .first_child_lower = G,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    mem_dual[G] = NodeDual{
        .char = 'g',
        .first_child_lower = A,
        .first_child_upper = AA,
        .next_sibling = H,
    };
    mem_dual[H] = NodeDual{
        .char = 'h',
        .first_child_lower = D,
        .first_child_upper = DD,
        .next_sibling = NULL,
    };
    mem_dual[A] = NodeDual{
        .char = 'a',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = B,
    };
    mem_dual[B] = NodeDual{
        .char = 'b',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = C,
    };
    mem_dual[C] = NodeDual{
        .char = 'c',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    mem_dual[D] = NodeDual{
        .char = 'd',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = E,
    };
    mem_dual[E] = NodeDual{
        .char = 'e',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = F,
    };
    mem_dual[F] = NodeDual{
        .char = 'f',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    mem_dual[AA] = NodeDual{
        .char = 'A',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = BB,
    };
    mem_dual[BB] = NodeDual{
        .char = 'B',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = CC,
    };
    mem_dual[CC] = NodeDual{
        .char = 'C',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    mem_dual[DD] = NodeDual{
        .char = 'D',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = EE,
    };
    mem_dual[EE] = NodeDual{
        .char = 'E',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = FF,
    };
    mem_dual[FF] = NodeDual{
        .char = 'F',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    const Out = struct {
        buf: [15]u8 = undefined,
        idx: u8 = 0,
    };
    const Trav = IndexBasedFirstChildNextSiblingTraverser(Node, u8, NULL, "first_child", "next_sibling");
    const TravDual = IndexBasedMultiFirstChildNextSiblingTraverser(NodeDual, u8, NULL, &.{ "first_child_lower", "first_child_upper" }, "next_sibling");
    const PROTO = struct {
        fn act(m: Trav.Nodes, idx: u8, out: *Out) Trav.Nodes {
            out.buf[out.idx] = m.ptr[idx].char;
            out.idx += 1;
            return m;
        }
        fn act_dual(m: TravDual.Nodes, idx: u8, out: *Out, comptime _: void) anyerror!TravDual.Nodes {
            out.buf[out.idx] = m.ptr[idx].char;
            out.idx += 1;
            return m;
        }
        fn act_dual_rt(m: TravDual.Nodes, idx: u8, out: *Out, _: void) anyerror!TravDual.Nodes {
            out.buf[out.idx] = m.ptr[idx].char;
            out.idx += 1;
            return m;
        }
    };
    var stack_mem: [4]Trav.StackFrame = undefined;
    var stack_mem_dual: [4]TravDual.StackFrame = undefined;
    var stack = Trav.Stack{
        .ptr = @ptrCast(&stack_mem[0]),
        .cap = 4,
        .len = 0,
    };
    var stack_dual = TravDual.Stack{
        .ptr = @ptrCast(&stack_mem_dual[0]),
        .cap = 4,
        .len = 0,
    };
    var nodes = Trav.Nodes{
        .ptr = @ptrCast(&mem[0]),
        .cap = 9,
        .len = 9,
    };
    var nodes_dual = TravDual.Nodes{
        .ptr = @ptrCast(&mem_dual[0]),
        .cap = 15,
        .len = 15,
    };
    var err: ?ErrorOld = null;
    var out = Out{};
    nodes, stack, err = Trav.do_action_on_all_nodes_children_first_comptime_action_body(nodes, stack, I, .STATIC_MEM, void{}, &out, PROTO.act);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
    nodes, stack, err = Trav.do_action_on_all_nodes_children_first(nodes, stack, I, .STATIC_MEM, void{}, &out, PROTO.act);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
    nodes, stack, err = Trav.do_action_on_all_nodes_parents_first_comptime_action_body(nodes, stack, I, .STATIC_MEM, void{}, &out, PROTO.act);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "igabchdef", "expected", "", .{});
    out.idx = 0;
    nodes, stack, err = Trav.do_action_on_all_nodes_parents_first(nodes, stack, I, .STATIC_MEM, void{}, &out, PROTO.act);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "igabchdef", "expected", "", .{});
    out.idx = 0;
    nodes_dual, stack_dual = try TravDual.do_action_on_all_nodes(nodes_dual, stack_dual, .no_stack_reallocation(), .CHILDREN_FIRST, .all_child_paths(), I, &out, void{}, .COMPTIME_FN_BODY, PROTO.act_dual, void{});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcABCgdefDEFhi", "expected", "", .{});
    out.idx = 0;
    nodes_dual, stack_dual = try TravDual.do_action_on_all_nodes(nodes_dual, stack_dual, .no_stack_reallocation(), .CHILDREN_FIRST, .all_child_paths(), I, &out, void{}, .COMPTIME_FN_PTR, PROTO.act_dual, void{});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcABCgdefDEFhi", "expected", "", .{});
    out.idx = 0;
    nodes_dual, stack_dual = try TravDual.do_action_on_all_nodes(nodes_dual, stack_dual, .no_stack_reallocation(), .CHILDREN_FIRST, .all_child_paths(), I, &out, void{}, .RUNTIME_FN_PTR, void{}, PROTO.act_dual_rt);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcABCgdefDEFhi", "expected", "", .{});
    out.idx = 0;
    nodes_dual, stack_dual = try TravDual.do_action_on_all_nodes(nodes_dual, stack_dual, .no_stack_reallocation(), .PARENTS_FIRST, .all_child_paths(), I, &out, void{}, .COMPTIME_FN_BODY, PROTO.act_dual, void{});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "igabcABChdefDEF", "expected", "", .{});
    out.idx = 0;
    nodes_dual, stack_dual = try TravDual.do_action_on_all_nodes(nodes_dual, stack_dual, .no_stack_reallocation(), .PARENTS_FIRST, .all_child_paths(), I, &out, void{}, .RUNTIME_FN_PTR, void{}, PROTO.act_dual_rt);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "igabcABChdefDEF", "expected", "", .{});
    out.idx = 0;
    nodes_dual, stack_dual = try TravDual.do_action_on_all_nodes(nodes_dual, stack_dual, .no_stack_reallocation(), .CHILDREN_FIRST, .only_child_paths(&.{"first_child_lower"}), I, &out, void{}, .COMPTIME_FN_BODY, PROTO.act_dual, void{});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
    nodes_dual, stack_dual = try TravDual.do_action_on_all_nodes(nodes_dual, stack_dual, .no_stack_reallocation(), .PARENTS_FIRST, .exclude_child_paths(&.{"first_child_lower"}), I, &out, void{}, .COMPTIME_FN_BODY, PROTO.act_dual, void{});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "i", "expected", "", .{});
    out.idx = 0;
    nodes_dual, stack_dual = try TravDual.do_action_on_all_nodes(nodes_dual, stack_dual, .no_stack_reallocation(), .PARENTS_FIRST, .only_child_paths(&.{"first_child_upper"}), I, &out, void{}, .COMPTIME_FN_BODY, PROTO.act_dual, void{});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "i", "expected", "", .{});
    out.idx = 0;
    nodes_dual, stack_dual = try TravDual.do_action_on_all_nodes(nodes_dual, stack_dual, .no_stack_reallocation(), .CHILDREN_FIRST, .exclude_child_paths(&.{"first_child_upper"}), I, &out, void{}, .COMPTIME_FN_BODY, PROTO.act_dual, void{});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
}
