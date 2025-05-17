const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const math = std.math;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ArrayList = std.ArrayListUnmanaged;
const Type = std.builtin.Type;

const Root = @import("./_root.zig");
const LOG_PREFIX = Root.LOG_PREFIX;
const AABB2 = Root.AABB2;
const List = Root.List;
const InsertionSort = Root.InsertionSort;
const insertion_sort = InsertionSort.insertion_sort_with_transform;
const ListAllocErrorBehavior = Root.CommonTypes.AllocErrorBehavior;
const GrowthModel = Root.CommonTypes.GrowthModel;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const Compare = Root.Compare;
const DummyAllocator = Root.DummyAllocator;
const BinarySearch = Root.BinarySearch;
const CompareFn = Compare.CompareFn;
const ComparePackage = Compare.ComparePackage;
const Utils = Root.Utils;

pub const SweepPruneListOptions = struct {
    aabb_value_type: type,
    aabb_id_type: type,
    aabb_collection_type: type,
    sweep_mode: SweepMode = .X_THEN_Y,
    automatically_fetch_position_updates: bool = true,
    edge_index_type: type,
    edge_allocator: *const Allocator,
    edge_alloc_growth_model: Root.List.GrowthModel = .GROW_BY_50_PERCENT,
    sweep_allocator: *const Allocator,
    sweep_alloc_growth_model: Root.List.GrowthModel = .GROW_BY_25_PERCENT,
    result_allocator: *const Allocator,
    result_index_type: type,
    result_alloc_growth_model: Root.List.GrowthModel = .GROW_EXACT_NEEDED,
    alloc_error_behavior: AllocErrorBehavior = .ALLOCATION_ERRORS_PANIC,
};

pub const AllocErrorBehavior = enum {
    ALLOCATION_ERRORS_ARE_UNREACHABLE,
    ALLOCATION_ERRORS_PANIC,

    pub inline fn to_list_behavior(self: AllocErrorBehavior) ListAllocErrorBehavior {
        return switch (self) {
            AllocErrorBehavior.ALLOCATION_ERRORS_ARE_UNREACHABLE => ListAllocErrorBehavior.ALLOCATION_ERRORS_ARE_UNREACHABLE,
            AllocErrorBehavior.ALLOCATION_ERRORS_PANIC => ListAllocErrorBehavior.ALLOCATION_ERRORS_PANIC,
        };
    }
};

pub fn AABB_LookupFunc(comptime options: SweepPruneListOptions) type {
    const AABB = AABB2.define_aabb2_type(options.aabb_value_type);
    return fn (id: options.aabb_id_type, aabb_collection: *const options.aabb_collection_type) AABB;
}

pub const SweepMode = enum(u8) {
    X_ONLY = 0,
    X_THEN_Y = 1,
    Y_ONLY = 2,
    Y_THEN_X = 3,
};

pub fn define_aabb2_sweep_and_prune_list(comptime options: SweepPruneListOptions, comptime lookup_func: *const AABB_LookupFunc(options)) type {
    return struct {
        const Self = @This();

        const T_VAL = options.aabb_value_type;
        const T_AABB = AABB2.define_aabb2_type(T_VAL);
        const T_AABB_ID = options.aabb_id_type;
        const T_AABB_COLLECTION = options.aabb_collection_type;
        const T_EDGE_INDEX = options.edge_index_type;
        const T_SWEEP_INDEX = T_AABB_ID;
        const T_RESULT_INDEX = options.result_index_type;
        const T_EDGE = if (AUTO_UPDATE) struct {
            id: T_AABB_ID,
            val: T_VAL,
            is_max: bool,
            never_moves: bool,
        } else struct {
            id: T_AABB_ID,
            val: T_VAL,
            is_max: bool,
        };
        const T_SWEEP_MEMBER = if (AUTO_UPDATE) struct {
            id: T_AABB_ID,
            is_null: bool,
            never_moves: bool,
        } else struct {
            id: T_AABB_ID,
            is_null: bool,
        };
        const T_TOUCH_PAIR = struct {
            a: T_AABB_ID,
            b: T_AABB_ID,
        };
        const T_ADD_AABB = if (AUTO_UPDATE) struct {
            id: T_AABB_ID,
            aabb: T_AABB,
            never_moves: bool,
        } else struct {
            id: T_AABB_ID,
            aabb: T_AABB,
        };
        const T_EDGE_REFS = struct {
            is_x_axis: bool,
            min_val: *T_VAL,
            max_val: *T_VAL,
        };
        const LOOKUP_AABB_FN = lookup_func;
        const X_EDGE_ALLOC = options.x_edge_allocator;
        const X_EDGE_GROWTH = options.x_edge_alloc_growth_model;
        const Y_EDGE_ALLOC = options.y_edge_allocator;
        const Y_EDGE_GROWTH = options.y_edge_alloc_growth_model;
        const SWEEP_ALLOC = options.sweep_allocator;
        const SWEEP_GROWTH = options.sweep_alloc_growth_model;
        const RESULT_ALLOC = options.result_alloc_growth_model;
        const RESULT_GROWTH = options.result_alloc_growth_model;
        const AUTO_UPDATE = options.automatically_fetch_position_updates;
        const SWEEP_MODE = options.sweep_mode;
        const SWEEP_X = SWEEP_MODE != .Y_ONLY;
        const SWEEP_Y = SWEEP_MODE != .X_ONLY;
        const SWEEP_BOTH = SWEEP_X and SWEEP_Y;
        const SWEEP_X_FIRST = SWEEP_MODE == .X_THEN_Y or SWEEP_MODE == .X_ONLY;
        const SWEEP_X_SECOND = SWEEP_MODE == .Y_THEN_X;
        const SWEEP_Y_FIRST = SWEEP_MODE == .Y_THEN_X or SWEEP_MODE == .Y_ONLY;
        const SWEEP_Y_SECOND = SWEEP_MODE == .X_THEN_Y;
        const ALLOC_ERR = options.alloc_error_behavior.to_list_behavior();
        const X_EDGE_LIST_OPTS = List.ListOptions{
            .alignment = null,
            .alloc_error_behavior = ALLOC_ERR,
            .element_type = T_EDGE,
            .growth_model = X_EDGE_GROWTH,
            .index_type = T_EDGE_INDEX,
            .secure_wipe_bytes = false,
        };
        const Y_EDGE_LIST_OPTS = List.ListOptions{
            .alignment = null,
            .alloc_error_behavior = ALLOC_ERR,
            .element_type = T_EDGE,
            .growth_model = Y_EDGE_GROWTH,
            .index_type = T_EDGE_INDEX,
            .secure_wipe_bytes = false,
        };
        const SWEEP_LIST_OPTS = List.ListOptions{
            .alignment = null,
            .alloc_error_behavior = ALLOC_ERR,
            .element_type = T_SWEEP_MEMBER,
            .growth_model = SWEEP_GROWTH,
            .index_type = T_SWEEP_INDEX,
            .secure_wipe_bytes = false,
        };
        const RESULT_LIST_OPTS = List.ListOptions{
            .alignment = null,
            .alloc_error_behavior = ALLOC_ERR,
            .element_type = T_TOUCH_PAIR,
            .growth_model = RESULT_GROWTH,
            .index_type = T_RESULT_INDEX,
            .secure_wipe_bytes = false,
        };
        const Error = Allocator.Error;

        pub const XEdgeList = List.define_static_allocator_list_type(X_EDGE_LIST_OPTS, X_EDGE_ALLOC);
        pub const YEdgeList = List.define_static_allocator_list_type(Y_EDGE_LIST_OPTS, Y_EDGE_ALLOC);
        pub const SweepList = List.define_static_allocator_list_type(SWEEP_LIST_OPTS, SWEEP_ALLOC);
        pub const ResultList = List.define_static_allocator_list_type(RESULT_LIST_OPTS, RESULT_ALLOC);

        pub const InitOptions = struct {
            aabb_collection: *const T_AABB_COLLECTION,
            x_edge_list_init_capacity: if (SWEEP_X) T_EDGE_INDEX else void = if (SWEEP_X) 0 else void{},
            y_edge_list_init_capacity: if (SWEEP_Y) T_EDGE_INDEX else void = if (SWEEP_Y) 0 else void{},
            sweep_list_init_capacity: T_SWEEP_INDEX = 0,
            result_list_init_capacity: T_RESULT_INDEX = 0,
        };

        aabb_collection: *const T_AABB_COLLECTION,
        x_edge_list: if (SWEEP_X) XEdgeList else void,
        y_edge_list: if (SWEEP_Y) YEdgeList else void,
        sweep_list: SweepList,
        sweep_list_next_free: T_SWEEP_INDEX,
        sweep_list_free_count: T_SWEEP_INDEX,
        sweep_list_member_count: T_SWEEP_INDEX,
        result_list: ResultList,

        pub fn create(opts: InitOptions) Self {
            return Self{
                .aabb_collection = opts.aabb_collection,
                .x_edge_list = if (SWEEP_X) XEdgeList.new_with_capacity(opts.x_edge_list_init_capacity) else void{},
                .y_edge_list = if (SWEEP_Y) YEdgeList.new_with_capacity(opts.y_edge_list_init_capacity) else void{},
                .sweep_list = SweepList.new_with_capacity(opts.sweep_list_init_capacity),
                .result_list = ResultList.new_with_capacity(opts.result_list_init_capacity),
                .sweep_list_next_free = 0,
                .sweep_list_free_count = 0,
            };
        }

        pub fn destroy(self: *Self) void {
            if (SWEEP_X) self.x_edge_list.clear_and_free();
            if (SWEEP_Y) self.y_edge_list.clear_and_free();
            self.sweep_list.clear_and_free();
            self.result_list.clear_and_free();
            self.sweep_list_next_free = 0;
            self.sweep_list_free_count = 0;
            self.sweep_list_member_count = 0;
        }

        fn match_sweep_member_by_id(id: T_AABB_ID, member: *const T_SWEEP_MEMBER) bool {
            return member.id == id;
        }

        fn match_edge_by_id(id: T_AABB_ID, edge: *const T_EDGE) bool {
            return edge.id == id;
        }

        fn edge_xfrm(edge: T_EDGE, data: ?*const anyopaque) T_VAL {
            _ = data;
            return edge.val;
        }

        fn remove_from_sweep_list(self: *Self, edge: T_EDGE) void {
            const member_idx: T_SWEEP_INDEX = self.sweep_list.find_idx(edge.id, match_sweep_member_by_id).?;
            const member: *T_SWEEP_MEMBER = &self.sweep_list.ptr[member_idx];
            member.is_null = true;
            member.id = self.sweep_list_next_free;
            self.sweep_list_next_free = member_idx;
            self.sweep_list_free_count += 1;
            self.sweep_list_member_count -= 1;
        }

        fn add_to_sweep_list(self: *Self, edge: T_EDGE) void {
            if (self.sweep_list_free_count > 0) {
                const member_idx: T_SWEEP_INDEX = self.sweep_list_next_free;
                const member: *T_SWEEP_MEMBER = &self.sweep_list.ptr[member_idx];
                self.sweep_list_next_free = member.id;
                self.sweep_list_free_count -= 1;
                member.is_null = false;
                member.id = edge.id;
                member.never_moves = edge.never_moves;
            } else {
                self.sweep_list.append(T_SWEEP_MEMBER{
                    .id = edge.id,
                    .is_null = false,
                    .never_moves = edge.never_moves,
                });
            }
            self.sweep_list_member_count += 1;
        }

        fn add_sweep_edge_to_y_edge_list(self: *Self, edge: T_EDGE) void {
            if (self.sweep_list_member_count > 1) {
                const this_aabb = LOOKUP_AABB_FN(edge.id, self.aabb_collection);
                self.add_aabb_to_y_edge_list(edge.id, this_aabb, edge.never_moves);
            }
            if (self.sweep_list_member_count == 2) {
                for (self.sweep_list.slice()) |m| {
                    const last_member: T_SWEEP_MEMBER = m;
                    if (last_member.id != edge.id and !last_member.is_null) {
                        const last_aabb = LOOKUP_AABB_FN(last_member.id, self.aabb_collection);
                        self.add_aabb_to_y_edge_list(last_member.id, last_aabb, last_member.never_moves);
                    }
                }
            }
        }

        fn add_aabb_to_x_edge_list(self: *Self, input: T_ADD_AABB) void {
            const edges = [2]T_EDGE{
                if (AUTO_UPDATE) T_EDGE{
                    .id = input.id,
                    .is_max = false,
                    .val = input.aabb.x_min,
                    .never_moves = input.never_moves,
                } else T_EDGE{
                    .id = input.id,
                    .is_max = false,
                    .val = input.aabb.x_min,
                },
                if (AUTO_UPDATE) T_EDGE{
                    .id = input.id,
                    .is_max = true,
                    .val = input.aabb.x_max,
                    .never_moves = input.never_moves,
                } else T_EDGE{
                    .id = input.id,
                    .is_max = true,
                    .val = input.aabb.x_max,
                },
            };
            self.x_edge_list.append_slice(edges[0..2]);
        }

        fn add_aabb_to_y_edge_list(self: *Self, input: T_ADD_AABB) void {
            const edges = [2]T_EDGE{
                if (AUTO_UPDATE) T_EDGE{
                    .id = input.id,
                    .is_max = false,
                    .val = input.aabb.y_min,
                    .never_moves = input.never_moves,
                } else T_EDGE{
                    .id = input.id,
                    .is_max = false,
                    .val = input.aabb.y_min,
                },
                if (AUTO_UPDATE) T_EDGE{
                    .id = input.id,
                    .is_max = true,
                    .val = input.aabb.y_max,
                    .never_moves = input.never_moves,
                } else T_EDGE{
                    .id = input.id,
                    .is_max = true,
                    .val = input.aabb.y_max,
                },
            };
            self.y_edge_list.append_slice(edges[0..2]);
        }

        fn add_sweep_edge_to_x_edge_list(self: *Self, edge: T_EDGE) void {
            if (self.sweep_list_member_count > 1) {
                const this_aabb = LOOKUP_AABB_FN(edge.id, self.aabb_collection);
                self.add_aabb_to_x_edge_list(edge.id, this_aabb, edge.never_moves);
            }
            if (self.sweep_list_member_count == 2) {
                for (self.sweep_list.slice()) |m| {
                    const last_member: T_SWEEP_MEMBER = m;
                    if (last_member.id != edge.id and !last_member.is_null) {
                        const last_aabb = LOOKUP_AABB_FN(last_member.id, self.aabb_collection);
                        self.add_aabb_to_x_edge_list(last_member.id, last_aabb, last_member.never_moves);
                    }
                }
            }
        }

        fn add_new_sweep_pairs_to_results(self: *Self, edge: T_EDGE) void {
            if (self.sweep_list_member_count > 1) {
                var pairs_left = self.sweep_list_member_count - 1;
                for (self.sweep_list.slice()) |m| {
                    const other_member: T_SWEEP_MEMBER = m;
                    if (!other_member.is_null and other_member.id != edge.id) {
                        pairs_left -= 1;
                        self.result_list.append(T_TOUCH_PAIR{
                            .a = edge.id,
                            .b = other_member.id,
                        });
                        if (pairs_left == 0) return;
                    }
                }
            }
        }

        fn update_all_primary_movable_edges(self: *Self) void {
            Utils.comptime_assert_with_reason(AUTO_UPDATE, LOG_PREFIX ++ "SweepPruneList: options.automatically_fetch_position_updates == false");
            if (SWEEP_X_FIRST) {
                for (self.x_edge_list.slice()) |*edge| {
                    if (!edge.never_moves) {
                        const aabb = LOOKUP_AABB_FN(edge.id, self.aabb_collection);
                        if (edge.is_max) {
                            edge.val = aabb.x_max;
                        } else {
                            edge.val = aabb.x_min;
                        }
                    }
                }
            }
            if (SWEEP_Y_FIRST) {
                for (self.y_edge_list.slice()) |*edge| {
                    if (!edge.never_moves) {
                        const aabb = LOOKUP_AABB_FN(edge.id, self.aabb_collection);
                        if (edge.is_max) {
                            edge.val = aabb.y_max;
                        } else {
                            edge.val = aabb.y_min;
                        }
                    }
                }
            }
        }

        pub fn add_new_aabb_edges(self: *Self, input: T_ADD_AABB) void {
            if (SWEEP_X_FIRST) {
                self.add_aabb_to_x_edge_list(input);
            }
            if (SWEEP_Y_FIRST) {
                self.add_aabb_to_y_edge_list(input);
            }
        }

        pub fn remove_aabb_edges(self: *Self, id: T_AABB_ID) void {
            var ids: [2]T_AABB_ID = @splat(id);
            var rem_idxs: [2]T_EDGE_INDEX = @splat(0);
            if (SWEEP_X_FIRST) {
                self.x_edge_list.slice().find_exactly_n_item_indexes_from_n_params_in_order(T_AABB_ID, ids[0..2], match_edge_by_id, rem_idxs[0..2]);
                self.x_edge_list.delete_ordered_indexes(rem_idxs[0..2]);
            }
            if (SWEEP_Y_FIRST) {
                self.y_edge_list.slice().find_exactly_n_item_indexes_from_n_params_in_order(T_AABB_ID, ids[0..2], match_edge_by_id, rem_idxs[0..2]);
                self.y_edge_list.delete_ordered_indexes(rem_idxs[0..2]);
            }
        }

        pub fn get_edge_refs_for_update(self: *Self, id: T_AABB_ID) T_EDGE_REFS {
            var result: T_EDGE_REFS = undefined;
            var refs: [2]*T_VAL = undefined;
            const params: [2]T_AABB_ID = @splat(id);
            if (SWEEP_X_FIRST) {
                result.is_x_axis = true;
                const found = self.x_edge_list.slice().find_exactly_n_item_pointers_from_n_params_in_order(T_AABB_ID, params[0..2], match_edge_by_id, refs[0..2]);
                assert(found);
            }
            if (SWEEP_Y_FIRST) {
                result.is_x_axis = false;
                const found = self.y_edge_list.slice().find_exactly_n_item_pointers_from_n_params_in_order(T_AABB_ID, params[0..2], match_edge_by_id, refs[0..2]);
                assert(found);
            }
            result.min_val = refs[0];
            result.max_val = refs[1];
            return result;
        }

        pub fn perform_sweep(self: *Self) []T_TOUCH_PAIR {
            if (SWEEP_X_SECOND) self.x_edge_list.clear_retaining_capacity();
            if (SWEEP_Y_SECOND) self.y_edge_list.clear_retaining_capacity();
            self.sweep_list.clear_retaining_capacity();
            self.sweep_list_free_count = 0;
            self.sweep_list_member_count = 0;
            self.sweep_list_next_free = 0;
            self.result_list.clear_retaining_capacity();
            if (AUTO_UPDATE) {
                self.update_all_primary_movable_edges();
            }
            if (SWEEP_X_FIRST) {
                insertion_sort(T_EDGE, self.x_edge_list.slice(), T_VAL, edge_xfrm, null);
                for (self.x_edge_list.slice()) |e| {
                    const edge: T_EDGE = e;
                    if (edge.is_max) {
                        self.remove_from_sweep_list(edge);
                    } else {
                        self.add_to_sweep_list(edge);
                        if (SWEEP_Y_SECOND) {
                            self.add_sweep_edge_to_y_edge_list(edge);
                        } else {
                            self.add_new_sweep_pairs_to_results(edge);
                        }
                    }
                }
            }
            if (SWEEP_Y_FIRST) {
                insertion_sort(T_EDGE, self.y_edge_list.slice(), T_VAL, edge_xfrm, null);
                for (self.y_edge_list.slice()) |e| {
                    const edge: T_EDGE = e;
                    if (edge.is_max) {
                        self.remove_from_sweep_list(edge);
                    } else {
                        self.add_to_sweep_list(edge);
                        if (SWEEP_X_SECOND) {
                            self.add_sweep_edge_to_y_edge_list(edge);
                        } else {
                            self.add_new_sweep_pairs_to_results(edge);
                        }
                    }
                }
            }
            if (SWEEP_BOTH) {
                self.sweep_list.clear_retaining_capacity();
                self.sweep_list_free_count = 0;
                self.sweep_list_member_count = 0;
                self.sweep_list_next_free = 0;
            }
            if (SWEEP_Y_SECOND) {
                insertion_sort(T_EDGE, self.y_edge_list.slice(), T_VAL, edge_xfrm, null);
                for (self.y_edge_list.slice()) |e| {
                    const edge: T_EDGE = e;
                    if (edge.is_max) {
                        self.remove_from_sweep_list(edge);
                    } else {
                        self.add_to_sweep_list(edge);
                        self.add_new_sweep_pairs_to_results(edge);
                    }
                }
            }
            if (SWEEP_X_SECOND) {
                insertion_sort(T_EDGE, self.x_edge_list.slice(), T_VAL, edge_xfrm, null);
                for (self.x_edge_list.slice()) |e| {
                    const edge: T_EDGE = e;
                    if (edge.is_max) {
                        self.remove_from_sweep_list(edge);
                    } else {
                        self.add_to_sweep_list(edge);
                        self.add_new_sweep_pairs_to_results(edge);
                    }
                }
            }
        }
    };
}
