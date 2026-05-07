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
const HashMap = std.HashMapUnmanaged;

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
const Sort = Root.Sort;
const DummyAlloc = Root.DummyAllocator.allocator_panic_free_noop;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;
const kind_info = KindInfo.get_kind_info;

const CompareFn = Utils.Compare.CompareFn;
const CompareFnUserdata = Utils.Compare.CompareFnUserdata;
const Pool = Root.Pool.Simple.SimplePool;
const List = Root.GooListSlice.GooListSlice;
const HashFn = CommonTypes.HashFn;
const HashFnUserdata = CommonTypes.HashFnUserdata;


pub fn BranchSearchStrategy(comptime BRANCH_TYPE: type, comptime USERDATA_TYPE: type) type {
    return union(enum) {
        LINEAR: struct {
            equals: CompareFn(BRANCH_TYPE, BRANCH_TYPE),
        },
        LINEAR_WITH_USERDATA: struct {
            equals: CompareFnUserdata(BRANCH_TYPE, BRANCH_TYPE, USERDATA_TYPE),
        },
        BINARY: struct {
            greater_than: CompareFn(BRANCH_TYPE, BRANCH_TYPE),
            equals: CompareFn(BRANCH_TYPE, BRANCH_TYPE),
        },
        BINARY_WITH_USERDATA: struct {
            greater_than: CompareFnUserdata(BRANCH_TYPE, BRANCH_TYPE, USERDATA_TYPE),
            equals: CompareFnUserdata(BRANCH_TYPE, BRANCH_TYPE, USERDATA_TYPE),
        },
        HASH: struct {
            hash: HashFn(BRANCH_TYPE),
            equals: CompareFn(BRANCH_TYPE, BRANCH_TYPE),
            max_load_percent: u64 = 80,
        },
        HASH_WITH_USERDATA: struct {
            hash: HashFnUserdata(BRANCH_TYPE, USERDATA_TYPE),
            equals: CompareFnUserdata(BRANCH_TYPE, BRANCH_TYPE, USERDATA_TYPE),
            max_load_percent: u64 = 80,
        },
    };
}

pub fn HashContext(comptime IDX_TYPE: type, comptime BRANCH_TYPE: type, comptime HASH: fn (branch_key: BRANCH_TYPE) u64, comptime EQUALS: CompareFn(BRANCH_TYPE, BRANCH_TYPE)) type {
    return struct {
        pub fn hash(_: @This(), key: BRANCH_TYPE) u64 {
            return HASH(key);
        }
        pub fn eql(_: @This(), a: BRANCH_TYPE, b: BRANCH_TYPE) bool {
            return EQUALS(a, b);
        }
    };
}

pub fn HashContextUserdata(comptime IDX_TYPE: type, comptime BRANCH_TYPE: type, comptime USERDATA: type, comptime HASH: fn (branch_key: BRANCH_TYPE, userdata: USERDATA) u64, comptime EQUALS: CompareFnUserdata(BRANCH_TYPE, BRANCH_TYPE, USERDATA)) type {
    return struct {
        userdata: USERDATA,

        pub fn hash(self: @This(), key: BRANCH_TYPE) u64 {
            return HASH(key, self.userdata);
        }
        pub fn eql(self: @This(), a: BRANCH_TYPE, b: BRANCH_TYPE) bool {
            return EQUALS(a, b, self.userdata);
        }
    };
}

pub fn Trie(comptime BRANCH_TYPE: type, comptime LEAF_TYPE: type, comptime IDX_TYPE: type, comptime USERDATA_TYPE: type, comptime SEARCH_STRATEGY: BranchSearchStrategy(BRANCH_TYPE, USERDATA_TYPE), comptime GET_PREFIX: fn (val: LEAF_TYPE, idx: IDX_TYPE) BRANCH_TYPE) type {
    return struct {
        const Self = @This();

        node_pool: NodePool = .{},
        children_pool: NodeChildrenPool = .{},
        alloc: Allocator = DummyAlloc,
        count: IDX_TYPE = 0,
        root: IDX_TYPE = 0,

        const USE_HASH = SEARCH_STRATEGY == .HASH or SEARCH_STRATEGY == .HASH_WITH_USERDATA;

        const Node = struct {
            children: NodeChildren = .{},
            leaf_val: ?LEAF_TYPE,

            pub fn new(leaf_val: ?LEAF_TYPE) Node {
                return Node{ .leaf_val = leaf_val };
            }
        };
        const HASH_CONTEXT = switch (SEARCH_STRATEGY) {
            .HASH => |VALS| HashContext(IDX_TYPE, BRANCH_TYPE, VALS.hash, VALS.equals),
            .HASH_WITH_USERDATA => |VALS| HashContextUserdata(IDX_TYPE, BRANCH_TYPE, USERDATA_TYPE, VALS.hash, VALS.equals),
            else => void,
        };
        const SliceNodeChildren = struct {
            pool_start_idx: IDX_TYPE = 0,
            pool_range_len: IDX_TYPE = 0,
        };
        const HASH_MAX_LOAD = switch (SEARCH_STRATEGY) {
            .HASH => |VALS| VALS.max_load_percent,
            .HASH_WITH_USERDATA => |VALS| VALS.max_load_percent,
            .LINEAR, .LINEAR_WITH_USERDATA, .BINARY, .BINARY_WITH_USERDATA => 0,
        };
        const HashNodeChildren = HashMap(BRANCH_TYPE, IDX_TYPE, HASH_CONTEXT, HASH_MAX_LOAD);
        const NodeChildren = switch (SEARCH_STRATEGY) {
            .HASH, .HASH_WITH_USERDATA => HashNodeChildren,
            .LINEAR, .LINEAR_WITH_USERDATA, .BINARY, .BINARY_WITH_USERDATA => SliceNodeChildren,
        };
        const NodeChildrenPool = switch (SEARCH_STRATEGY) {
            .HASH, .HASH_WITH_USERDATA => void,
            .LINEAR, .LINEAR_WITH_USERDATA, .BINARY, .BINARY_WITH_USERDATA => Pool(IDX_TYPE, IDX_TYPE, null, null, null),
        };
        pub fn add_new_node(self: *Self, leaf_val: ?LEAF_TYPE) IDX_TYPE {
            const claimed = self.node_pool.claim_one(self.alloc);
            claimed.ptr.* = .new(leaf_val);
            return claimed.idx;
        }
        pub fn get_node(self: *const Self, node_idx: IDX_TYPE) Node {
            return self.node_pool.ptr[node_idx];
        }
        pub fn add_child(self: *Self, node_children: NodeChildren, child_node_idx: IDX_TYPE) NodeChildren {
            switch (SEARCH_STRATEGY) {
                .LINEAR => {
                    var children: SliceNodeChildren = node_children;
                    const new_range = self.children_pool.resize_range(children.pool_start_idx, children.pool_range_len, children.pool_range_len + 1, self.alloc);
                    children.pool_start_idx = new_range.start_idx;
                    children.pool_range_len += 1;
                    new_range.slice[new_range.slice.len - 1] = child_node_idx;
                    return children;
                },
                .LINEAR_WITH_USERDATA => |X| {
                    var children: SliceNodeChildren = node_children;
                    const new_range = self.children_pool.resize_range(children.pool_start_idx, children.pool_range_len, children.pool_range_len + 1, self.alloc);
                    children.pool_start_idx = new_range.start_idx;
                    children.pool_range_len += 1;
                    new_range.slice[new_range.slice.len - 1] = child_node_idx;
                    Sort.InsertionSort.insertion_sort_with_func(buffer: anytype, greater_than: *const fn ((unknown type), (unknown type)) bool)
                    return children;
                },
            }
        }
        const NodePool = Pool(Node, IDX_TYPE, null, null, null);
    };
}
