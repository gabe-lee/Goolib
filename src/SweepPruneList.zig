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
const Assert = Root.Assert;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;

const Root = @import("./_root.zig");
// const LOG_PREFIX = Root.LOG_PREFIX;
// const AABB2 = Root.AABB2;
const List = Root.IList.List;
// const InsertionSort = Root.InsertionSort;
// const insertion_sort = InsertionSort.insertion_sort_with_transform;
// const ListAllocErrorBehavior = Root.CommonTypes.AllocErrorBehavior;
// const GrowthModel = Root.CommonTypes.GrowthModel;
// const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
// const Compare = Root.Compare;
const DummyAllocator = Root.DummyAllocator;
// const BinarySearch = Root.BinarySearch;
// const CompareFn = Compare.CompareFn;
// const ComparePackage = Compare.ComparePackage;
const Utils = Root.Utils;
const ParamTable = Root.ParamTable.Table;
const InsertionSort = Root.Sort.InsertionSort;

pub const SweepPruneListOptions = struct {
    UNIT_TYPE: type,
    ID_TYPE: type,
    SWEEP_MODE: SweepMode = .X_THEN_Y,
};

pub const SweepMode = enum(u8) {
    X_ONLY,
    X_THEN_Y,
    Y_ONLY,
    Y_THEN_X,
};

// pub const ParamToGet = enum(u8) {
//     X_MIN,
//     X_MAX,
//     Y_MIN,
//     Y_MAX,
// };

const ActiveOrNextFree = enum(u8) {
    ACTIVE,
    NEXT_FREE,
};

const MinOrMax = enum(u8) {
    MIN,
    MAX,
};

pub const ParamTableSweepPruneListOptions = struct {
    DISTANCE_TYPE: type,
    OBJECT_IDENTIFIER_TYPE: type,
    SWEEP_MODE: SweepMode = .X_THEN_Y,
};

const ParamId = Root.ParamTable.ParamId;

pub fn param_table_sweep_and_prune_list(comptime options: ParamTableSweepPruneListOptions) type {
    return struct {
        const Self = @This();

        param_table: *const ParamTable,
        allocator_edge_list_primary: Allocator = std.heap.page_allocator,
        allocator_edge_list_secondary: if (SWEEP_2) Allocator else void = if (SWEEP_2) std.heap.page_allocator else void{},
        allocator_sweep_list: Allocator = std.heap.page_allocator,
        allocator_result_list: Allocator = std.heap.page_allocator,
        primary_edge_list: PrimaryEdgeList = .{},
        secondary_edge_list: if (SWEEP_2) SecondaryEdgeList else void = if (SWEEP_2) SecondaryEdgeList{} else void{},
        sweep_list: SweepList = .{},
        result_list: ResultList = .{},
        sweep_list_next_free: u32 = 0,
        sweep_list_free_count: u32 = 0,
        sweep_list_member_count: u32 = 0,
        object_id_equal_func: *const fn (id_a: ObjId, id_b: ObjId) bool,

        pub const InitOptions = struct {
            param_table: *const ParamTable,
            initial_capacity_edge_list_primary: u32 = 0,
            initial_capacity_edge_list_secondary: if (SWEEP_2) u32 else void = if (SWEEP_2) 0 else void{},
            initial_capacity_sweep_list: u32 = 0,
            initial_capacity_result_list: u32 = 0,
            allocator_edge_list_primary: Allocator = std.heap.page_allocator,
            allocator_edge_list_secondary: if (SWEEP_2) Allocator else void = if (SWEEP_2) std.heap.page_allocator else void{},
            allocator_sweep_list: Allocator = std.heap.page_allocator,
            allocator_result_list: Allocator = std.heap.page_allocator,
            object_id_equal_func: *const fn (id_a: ObjId, id_b: ObjId) bool,
        };

        pub const ObjectInitOptions = struct {
            obj_id: ObjId,
            x_min_param: if (SWEEP_X) ParamId else void,
            x_max_param: if (SWEEP_X) ParamId else void,
            y_min_param: if (SWEEP_Y) ParamId else void,
            y_max_param: if (SWEEP_Y) ParamId else void,
        };

        const get_position = switch (options.DISTANCE_TYPE) {
            u8 => ParamTable.get_u8,
            i8 => ParamTable.get_i8,
            u16 => ParamTable.get_u16,
            i16 => ParamTable.get_i16,
            f16 => ParamTable.get_f16,
            u32 => ParamTable.get_u32,
            i32 => ParamTable.get_i32,
            f32 => ParamTable.get_f32,
            u64 => ParamTable.get_u64,
            i64 => ParamTable.get_i64,
            f64 => ParamTable.get_f64,
            else => assert_unreachable(null, "type `{s}` is not a valid type for sweep-and-prune distance", .{@typeName(options.DISTANCE_TYPE)}),
        };

        pub const Distance = options.DISTANCE_TYPE;
        pub const SWEEP_MODE = options.SWEEP_MODE;
        const SWEEP_X = SWEEP_MODE != .Y_ONLY;
        const SWEEP_Y = SWEEP_MODE != .X_ONLY;
        const SWEEP_2 = SWEEP_X and SWEEP_Y;
        const SWEEP_X_FIRST = SWEEP_MODE == .X_THEN_Y or SWEEP_MODE == .X_ONLY;
        const SWEEP_X_SECOND = SWEEP_MODE == .Y_THEN_X;
        const SWEEP_Y_FIRST = SWEEP_MODE == .Y_THEN_X or SWEEP_MODE == .Y_ONLY;
        const SWEEP_Y_SECOND = SWEEP_MODE == .X_THEN_Y;
        pub const ObjId = options.OBJECT_IDENTIFIER_TYPE;
        pub const PrimaryEdgeList = List(PrimaryEdge);
        pub const SecondaryEdgeList = List(SecondaryEdge);
        pub const SweepList = List(SweepMember);
        pub const ResultList = List(PossibleTouchPair);
        pub const PrimaryEdge = struct {
            obj_id: ObjId,
            val_id: ParamId,
            next_min_val_id: if (SWEEP_2) ParamId else void = if (SWEEP_2) .{} else void{},
            next_max_val_id: if (SWEEP_2) ParamId else void = if (SWEEP_2) .{} else void{},
            is_max: bool,
        };
        pub const SecondaryEdge = struct {
            obj_id: ObjId,
            val_id: ParamId,
            is_max: bool,
        };
        pub const ActiveSweepMember = struct {
            obj_id: ObjId,
            next_min_val_id: if (SWEEP_2) ParamId else void = if (SWEEP_2) .{} else void{},
            next_max_val_id: if (SWEEP_2) ParamId else void = if (SWEEP_2) .{} else void{},
        };
        pub const SweepMember = union(ActiveOrNextFree) {
            ACTIVE: ActiveSweepMember,
            NEXT_FREE: u32,
        };
        pub const PossibleTouchPair = struct {
            obj_a: ObjId,
            obj_b: ObjId,
        };

        pub fn init(opts: InitOptions) Self {
            return Self{
                .param_table = opts.param_table,
                .allocator_edge_list_primary = opts.allocator_edge_list_primary,
                .allocator_edge_list_secondary = opts.allocator_edge_list_secondary,
                .allocator_result_list = opts.allocator_result_list,
                .allocator_sweep_list = opts.allocator_sweep_list,
                .sweep_list_free_count = 0,
                .sweep_list_member_count = 0,
                .sweep_list_next_free = 0,
                .sweep_list = SweepList.init_capacity(opts.initial_capacity_sweep_list, opts.allocator_sweep_list),
                .result_list = ResultList.init_capacity(opts.initial_capacity_result_list, opts.allocator_result_list),
                .primary_edge_list = PrimaryEdgeList.init_capacity(opts.initial_capacity_edge_list_primary, opts.allocator_edge_list_primary),
                .secondary_edge_list = if (SWEEP_2) SecondaryEdgeList.init_capacity(opts.initial_capacity_edge_list_secondary, opts.allocator_edge_list_secondary) else void{},
                .object_id_equal_func = opts.object_id_equal_func,
            };
        }

        pub fn clear(self: *Self) void {
            self.result_list.clear();
            self.sweep_list.clear();
            self.primary_edge_list.clear();
            if (SWEEP_2) self.secondary_edge_list.clear();
            self.sweep_list_free_count = 0;
            self.sweep_list_member_count = 0;
            self.sweep_list_next_free = 0;
        }

        pub fn free(self: *Self) void {
            self.result_list.free(self.allocator_result_list);
            self.sweep_list.free(self.allocator_sweep_list);
            self.primary_edge_list.free(self.allocator_edge_list_primary);
            if (SWEEP_2) self.secondary_edge_list.free(self.allocator_edge_list_secondary);
            self.sweep_list_free_count = 0;
            self.sweep_list_member_count = 0;
            self.sweep_list_next_free = 0;
            self.allocator_sweep_list = DummyAllocator.allocator_panic;
            self.allocator_result_list = DummyAllocator.allocator_panic;
            self.primary_edge_list = DummyAllocator.allocator_panic;
            if (SWEEP_2) self.allocator_edge_list_secondary = DummyAllocator.allocator_panic;
        }

        fn add_object_to_sweep_and_prune(self: *Self, obj: ObjectInitOptions) void {
            if (SWEEP_X_FIRST) {
                const edge_min = PrimaryEdge{
                    .is_max = false,
                    .obj_id = obj.obj_id,
                    .val_id = obj.x_min_param,
                    .next_min_val_id = obj.y_min_param,
                    .next_max_val_id = obj.y_max_param,
                };
                const edge_max = PrimaryEdge{
                    .is_max = true,
                    .obj_id = obj.obj_id,
                    .val_id = obj.x_max_param,
                    .next_axis_val_id = obj.y_max_param,
                };
                _ = self.primary_edge_list.append(edge_min, self.allocator_edge_list_primary);
                _ = self.primary_edge_list.append(edge_max, self.allocator_edge_list_primary);
            } else {
                const edge_min = PrimaryEdge{
                    .is_max = false,
                    .obj_id = obj.obj_id,
                    .val_id = obj.y_min_param,
                    .next_axis_val_id = obj.x_min_param,
                };
                const edge_max = PrimaryEdge{
                    .is_max = true,
                    .obj_id = obj.obj_id,
                    .val_id = obj.y_max_param,
                    .next_axis_val_id = obj.x_max_param,
                };
                _ = self.primary_edge_list.append(edge_min, self.allocator_edge_list_primary);
                _ = self.primary_edge_list.append(edge_max, self.allocator_edge_list_primary);
            }
        }

        fn remove_id_from_sweep_list(self: *Self, find_id: ObjId) void {
            for (self.sweep_list.slice(), 0..) |*sweep_member, s| {
                switch (sweep_member) {
                    .OBJ_ID => |id| {
                        if (self.object_id_equal_func(id, find_id)) {
                            sweep_member.* = SweepMember{ .NEXT_FREE = self.sweep_list_next_free };
                            self.sweep_list_free_count += 1;
                            self.sweep_list_member_count -= 1;
                            self.sweep_list_next_free = @intCast(s);
                            return;
                        }
                    },
                    .NEXT_FREE => {},
                }
            }
            assert_unreachable(@src(), "object id `{any}` should have been in primary sweep list, but was not found", .{find_id});
        }

        fn add_primary_edge_to_sweep_list(self: *Self, edge: PrimaryEdge) void {
            const new_member = SweepMember{ .ACTIVE = .{
                .obj_id = edge.obj_id,
                .next_min_val_id = edge.next_min_val_id,
                .next_max_val_id = edge.next_max_val_id,
            } };
            if (self.sweep_list_free_count > 0) {
                const free_sweep_member: *SweepMember = &self.sweep_list.ptr[self.sweep_list_next_free];
                self.sweep_list_next_free = free_sweep_member.NEXT_FREE;
                self.sweep_list_free_count -= 1;
                free_sweep_member.* = new_member;
            } else {
                _ = self.sweep_list.append(new_member, self.allocator_sweep_list);
            }
            self.sweep_list_member_count += 1;
        }
        fn add_secondary_edge_to_sweep_list(self: *Self, edge: SecondaryEdge) void {
            const new_member = SweepMember{ .ACTIVE = .{ .obj_id = edge.obj_id } };
            if (self.sweep_list_free_count > 0) {
                const free_sweep_member: *SweepMember = &self.sweep_list.ptr[self.sweep_list_next_free];
                self.sweep_list_next_free = free_sweep_member.NEXT_FREE;
                self.sweep_list_free_count -= 1;
                free_sweep_member.* = new_member;
            } else {
                _ = self.sweep_list.append(new_member, self.allocator_sweep_list);
            }
            self.sweep_list_member_count += 1;
        }

        fn primary_edge_greater_than(a: PrimaryEdge, b: PrimaryEdge, table: *const ParamTable) bool {
            const table_cast: *ParamTable = @constCast(table);
            return get_position(table_cast, a.val_id) > get_position(table_cast, b.val_id);
        }
        fn secondary_edge_greater_than(a: SecondaryEdge, b: SecondaryEdge, table: *const ParamTable) bool {
            const table_cast: *ParamTable = @constCast(table);
            return get_position(table_cast, a.val_id) > get_position(table_cast, b.val_id);
        }

        fn add_new_touch_pairs_to_results(self: *Self, added_id: ObjId) void {
            if (self.sweep_list_member_count > 1) {
                var pairs_left = self.sweep_list_member_count - 1;
                for (self.sweep_list.slice()) |other_member| {
                    switch (other_member) {
                        .ACTIVE => |other_id| {
                            if (self.object_id_equal_func(other_id, added_id)) {
                                pairs_left -= 1;
                                _ = self.result_list.append(PossibleTouchPair{
                                    .obj_a = added_id,
                                    .obj_b = other_id,
                                }, self.allocator_result_list);
                                if (pairs_left == 0) return;
                            }
                        },
                        .NEXT_FREE => {},
                    }
                }
            }
        }

        fn add_primary_edge_to_secondary_edge_list(self: *Self, edge: PrimaryEdge) void {
            if (self.sweep_list_member_count > 1) {
                self.secondary_edge_list.ensure_free_slots(2, self.allocator_edge_list_secondary);
                self.secondary_edge_list.append_assume_capacity(SecondaryEdge{
                    .obj_id = edge.obj_id,
                    .is_max = false,
                    .val_id = edge.next_min_val_id,
                });
                self.secondary_edge_list.append_assume_capacity(SecondaryEdge{
                    .obj_id = edge.obj_id,
                    .is_max = true,
                    .val_id = edge.next_max_val_id,
                });
            }
            if (self.sweep_list_member_count == 2) {
                // The first active member in the sweep list had no overlaps, so was not added to the secondary sweep list,
                // but now we know it needed to be, so we do it now
                for (self.sweep_list.slice()) |other_member| {
                    switch (other_member) {
                        .ACTIVE => |other| {
                            if (other.obj_id != edge.obj_id) {
                                self.secondary_edge_list.ensure_free_slots(2, self.allocator_edge_list_secondary);
                                self.secondary_edge_list.append_assume_capacity(SecondaryEdge{
                                    .obj_id = other.obj_id,
                                    .is_max = false,
                                    .val_id = other.next_min_val_id,
                                });
                                self.secondary_edge_list.append_assume_capacity(SecondaryEdge{
                                    .obj_id = other.obj_id,
                                    .is_max = true,
                                    .val_id = other.next_max_val_id,
                                });
                                return;
                            }
                        },
                        .NEXT_FREE => {},
                    }
                }
            }
        }

        pub fn perform_sweep(self: *Self) []PossibleTouchPair {
            if (SWEEP_2) self.secondary_edge_list.clear();
            self.sweep_list.clear();
            self.sweep_list_free_count = 0;
            self.sweep_list_member_count = 0;
            self.sweep_list_next_free = 0;
            self.result_list.clear();
            InsertionSort.insertion_sort_with_func_and_userdata(PrimaryEdge, self.primary_edge_list.slice(), self.param_table, primary_edge_greater_than);
            for (self.primary_edge_list.slice()) |pri_edge| {
                if (pri_edge.is_max) {
                    self.remove_id_from_sweep_list(pri_edge.obj_id);
                } else {
                    self.add_primary_edge_to_sweep_list(pri_edge.obj_id);
                    if (SWEEP_2) {
                        self.add_primary_edge_to_secondary_edge_list(pri_edge);
                    } else {
                        self.add_new_touch_pairs_to_results(pri_edge.obj_id);
                    }
                }
            }
            if (SWEEP_2) {
                self.sweep_list.clear();
                self.sweep_list_free_count = 0;
                self.sweep_list_member_count = 0;
                self.sweep_list_next_free = 0;
                for (self.secondary_edge_list.slice()) |sec_edge| {
                    if (sec_edge.is_max) {
                        self.remove_id_from_sweep_list(sec_edge.obj_id);
                    } else {
                        self.add_secondary_edge_to_sweep_list(sec_edge);
                        self.add_new_touch_pairs_to_results(sec_edge.obj_id);
                    }
                }
            }
            return self.result_list.slice();
        }
    };
}

// pub fn define_sweep_and_prune_list(comptime options: SweepPruneListOptions) type {
//     return struct {
//         const Self = @This();

//         pub const T = options.UNIT_TYPE;
//         pub const ID = options.ID_TYPE;
//         pub const GetParamFunc = fn (object_collection: *const anyopaque, id: ID, param: ParamToGet) T;
//         pub const SWEEP_MODE = options.SWEEP_MODE;
//         const SWEEP_X = SWEEP_MODE != .Y_ONLY;
//         const SWEEP_Y = SWEEP_MODE != .X_ONLY;
//         const SWEEP_BOTH = SWEEP_X and SWEEP_Y;
//         const SWEEP_X_FIRST = SWEEP_MODE == .X_THEN_Y or SWEEP_MODE == .X_ONLY;
//         const SWEEP_X_SECOND = SWEEP_MODE == .Y_THEN_X;
//         const SWEEP_Y_FIRST = SWEEP_MODE == .Y_THEN_X or SWEEP_MODE == .Y_ONLY;
//         const SWEEP_Y_SECOND = SWEEP_MODE == .X_THEN_Y;
//         pub const EdgeList = List(Edge);
//         pub const SweepList = List(SweepMember);
//         pub const ResultList = List(TouchPair);
//         pub const Edge = struct {
//             id: ID,
//             val: T,
//             is_max: bool,
//         };
//         pub const SweepMember =  struct {
//             id: ID,
//             is_null: bool,
//         };
//         pub const TouchPair = struct {
//             a: ID,
//             b: ID,
//         };
//         pub const EdgeRefs = struct {
//             min_val: *T,
//             max_val: *T,
//             is_x_axis: bool,
//         };

//         fn get_param_panic(_: *const anyopaque, _: ID) T {
//             @panic("not implemented");
//         }

//         pub const InitOptions = struct {
//             param_table: *anyopaque,
//             get_object_x_min_func: *const GetParamFunc = get_param_panic,
//             get_object_y_min_func: *const GetParamFunc = get_param_panic,
//             get_object_x_max_func: *const GetParamFunc = get_param_panic,
//             get_object_y_max_func: *const GetParamFunc = get_param_panic,
//             initial_capacity_edge_list_x: u32 = 0,
//             initial_capacity_edge_list_y: u32 = 0,
//             initial_capacity_sweep_list: u32 = 0,
//             initial_capacity_result_list: u32 = 0,
//             allocator_edge_list_x: Allocator = std.heap.page_allocator,
//             allocator_edge_list_y: Allocator = std.heap.page_allocator,
//             allocator_sweep_list: Allocator = std.heap.page_allocator,
//             allocator_result_list: Allocator = std.heap.page_allocator,
//         };

//         object_collection_ptr: *const anyopaque,
//         get_object_x_min_func: *const GetParamFunc = get_param_panic,
//         get_object_y_min_func: *const GetParamFunc = get_param_panic,
//         get_object_x_max_func: *const GetParamFunc = get_param_panic,
//         get_object_y_max_func: *const GetParamFunc = get_param_panic,
//         allocator_edge_list_x: Allocator = std.heap.page_allocator,
//         allocator_edge_list_y: Allocator = std.heap.page_allocator,
//         allocator_sweep_list: Allocator = std.heap.page_allocator,
//         allocator_result_list: Allocator = std.heap.page_allocator,
//         x_edge_list: if (SWEEP_X) EdgeList else void = if (SWEEP_X) EdgeList{} else void{},
//         y_edge_list: if (SWEEP_Y) EdgeList else void = if (SWEEP_Y) EdgeList{} else void{},
//         sweep_list: SweepList,
//         sweep_list_next_free: u32,
//         sweep_list_free_count: u32,
//         sweep_list_member_count: u32,
//         result_list: ResultList,

//         pub fn init(opts: InitOptions) Self {
//             return Self{
//                 .object_collection_ptr = opts.object_collection_ptr,
//                 .get_object_x_max_func = opts.get_object_x_max_func,
//                 .get_object_x_min_func = opts.get_object_x_min_func,
//                 .get_object_y_min_func = opts.get_object_y_min_func,
//                 .get_object_y_max_func = opts.get_object_y_max_func,
//                 .x_edge_list = if (SWEEP_X) EdgeList.init_capacity(opts.initial_capacity_edge_list_x, alloc: Allocator)
//             };
//         }

//         pub fn destroy(self: *Self) void {
//             if (SWEEP_X) self.x_edge_list.clear_and_free();
//             if (SWEEP_Y) self.y_edge_list.clear_and_free();
//             self.sweep_list.clear_and_free();
//             self.result_list.clear_and_free();
//             self.sweep_list_next_free = 0;
//             self.sweep_list_free_count = 0;
//             self.sweep_list_member_count = 0;
//         }

//         fn match_sweep_member_by_id(id: ID, member: *const SweepMember) bool {
//             return member.id == id;
//         }

//         fn match_edge_by_id(id: ID, edge: *const Edge) bool {
//             return edge.id == id;
//         }

//         fn edge_xfrm(edge: Edge, data: ?*const anyopaque) T {
//             _ = data;
//             return edge.val;
//         }

//         fn remove_from_sweep_list(self: *Self, edge: Edge) void {
//             const member_idx: T_SWEEP_INDEX = self.sweep_list.find_idx(edge.id, match_sweep_member_by_id).?;
//             const member: *SweepMember = &self.sweep_list.ptr[member_idx];
//             member.is_null = true;
//             member.id = self.sweep_list_next_free;
//             self.sweep_list_next_free = member_idx;
//             self.sweep_list_free_count += 1;
//             self.sweep_list_member_count -= 1;
//         }

//         fn add_to_sweep_list(self: *Self, edge: Edge) void {
//             if (self.sweep_list_free_count > 0) {
//                 const member_idx: T_SWEEP_INDEX = self.sweep_list_next_free;
//                 const member: *SweepMember = &self.sweep_list.ptr[member_idx];
//                 self.sweep_list_next_free = member.id;
//                 self.sweep_list_free_count -= 1;
//                 member.is_null = false;
//                 member.id = edge.id;
//                 member.never_moves = edge.never_moves;
//             } else {
//                 self.sweep_list.append(SweepMember{
//                     .id = edge.id,
//                     .is_null = false,
//                     .never_moves = edge.never_moves,
//                 });
//             }
//             self.sweep_list_member_count += 1;
//         }

//         fn add_sweep_edge_to_y_edge_list(self: *Self, edge: Edge) void {
//             if (self.sweep_list_member_count > 1) {
//                 const this_aabb = LOOKUP_AABB_FN(edge.id, self.aabb_collection);
//                 self.add_aabb_to_y_edge_list(edge.id, this_aabb, edge.never_moves);
//             }
//             if (self.sweep_list_member_count == 2) {
//                 for (self.sweep_list.slice()) |m| {
//                     const last_member: SweepMember = m;
//                     if (last_member.id != edge.id and !last_member.is_null) {
//                         const last_aabb = LOOKUP_AABB_FN(last_member.id, self.aabb_collection);
//                         self.add_aabb_to_y_edge_list(last_member.id, last_aabb, last_member.never_moves);
//                     }
//                 }
//             }
//         }

//         fn add_aabb_to_x_edge_list(self: *Self, input: T_ADD_AABB) void {
//             const edges = [2]Edge{
//                 if (AUTO_UPDATE) Edge{
//                     .id = input.id,
//                     .is_max = false,
//                     .val = input.aabb.x_min,
//                     .never_moves = input.never_moves,
//                 } else Edge{
//                     .id = input.id,
//                     .is_max = false,
//                     .val = input.aabb.x_min,
//                 },
//                 if (AUTO_UPDATE) Edge{
//                     .id = input.id,
//                     .is_max = true,
//                     .val = input.aabb.x_max,
//                     .never_moves = input.never_moves,
//                 } else Edge{
//                     .id = input.id,
//                     .is_max = true,
//                     .val = input.aabb.x_max,
//                 },
//             };
//             self.x_edge_list.append_slice(edges[0..2]);
//         }

//         fn add_aabb_to_y_edge_list(self: *Self, input: T_ADD_AABB) void {
//             const edges = [2]Edge{
//                 if (AUTO_UPDATE) Edge{
//                     .id = input.id,
//                     .is_max = false,
//                     .val = input.aabb.y_min,
//                     .never_moves = input.never_moves,
//                 } else Edge{
//                     .id = input.id,
//                     .is_max = false,
//                     .val = input.aabb.y_min,
//                 },
//                 if (AUTO_UPDATE) Edge{
//                     .id = input.id,
//                     .is_max = true,
//                     .val = input.aabb.y_max,
//                     .never_moves = input.never_moves,
//                 } else Edge{
//                     .id = input.id,
//                     .is_max = true,
//                     .val = input.aabb.y_max,
//                 },
//             };
//             self.y_edge_list.append_slice(edges[0..2]);
//         }

//         fn add_sweep_edge_to_x_edge_list(self: *Self, edge: Edge) void {
//             if (self.sweep_list_member_count > 1) {
//                 const this_aabb = LOOKUP_AABB_FN(edge.id, self.aabb_collection);
//                 self.add_aabb_to_x_edge_list(edge.id, this_aabb, edge.never_moves);
//             }
//             if (self.sweep_list_member_count == 2) {
//                 for (self.sweep_list.slice()) |m| {
//                     const last_member: SweepMember = m;
//                     if (last_member.id != edge.id and !last_member.is_null) {
//                         const last_aabb = LOOKUP_AABB_FN(last_member.id, self.aabb_collection);
//                         self.add_aabb_to_x_edge_list(last_member.id, last_aabb, last_member.never_moves);
//                     }
//                 }
//             }
//         }

//         fn add_new_sweep_pairs_to_results(self: *Self, edge: Edge) void {
//             if (self.sweep_list_member_count > 1) {
//                 var pairs_left = self.sweep_list_member_count - 1;
//                 for (self.sweep_list.slice()) |m| {
//                     const other_member: SweepMember = m;
//                     if (!other_member.is_null and other_member.id != edge.id) {
//                         pairs_left -= 1;
//                         self.result_list.append(TouchPair{
//                             .a = edge.id,
//                             .b = other_member.id,
//                         });
//                         if (pairs_left == 0) return;
//                     }
//                 }
//             }
//         }

//         fn update_all_primary_movable_edges(self: *Self) void {
//             Utils.comptime_assert_with_reason(AUTO_UPDATE, LOG_PREFIX ++ "SweepPruneList: options.automatically_fetch_position_updates == false");
//             if (SWEEP_X_FIRST) {
//                 for (self.x_edge_list.slice()) |*edge| {
//                     if (!edge.never_moves) {
//                         const aabb = LOOKUP_AABB_FN(edge.id, self.aabb_collection);
//                         if (edge.is_max) {
//                             edge.val = aabb.x_max;
//                         } else {
//                             edge.val = aabb.x_min;
//                         }
//                     }
//                 }
//             }
//             if (SWEEP_Y_FIRST) {
//                 for (self.y_edge_list.slice()) |*edge| {
//                     if (!edge.never_moves) {
//                         const aabb = LOOKUP_AABB_FN(edge.id, self.aabb_collection);
//                         if (edge.is_max) {
//                             edge.val = aabb.y_max;
//                         } else {
//                             edge.val = aabb.y_min;
//                         }
//                     }
//                 }
//             }
//         }

//         pub fn add_new_aabb_edges(self: *Self, input: T_ADD_AABB) void {
//             if (SWEEP_X_FIRST) {
//                 self.add_aabb_to_x_edge_list(input);
//             }
//             if (SWEEP_Y_FIRST) {
//                 self.add_aabb_to_y_edge_list(input);
//             }
//         }

//         pub fn remove_aabb_edges(self: *Self, id: ID) void {
//             var ids: [2]ID = @splat(id);
//             var rem_idxs: [2]T_EDGE_INDEX = @splat(0);
//             if (SWEEP_X_FIRST) {
//                 self.x_edge_list.slice().find_exactly_n_item_indexes_from_n_params_in_order(ID, ids[0..2], match_edge_by_id, rem_idxs[0..2]);
//                 self.x_edge_list.delete_ordered_indexes(rem_idxs[0..2]);
//             }
//             if (SWEEP_Y_FIRST) {
//                 self.y_edge_list.slice().find_exactly_n_item_indexes_from_n_params_in_order(ID, ids[0..2], match_edge_by_id, rem_idxs[0..2]);
//                 self.y_edge_list.delete_ordered_indexes(rem_idxs[0..2]);
//             }
//         }

//         pub fn get_edge_refs_for_update(self: *Self, id: ID) EdgeRefs {
//             var result: EdgeRefs = undefined;
//             var refs: [2]*T = undefined;
//             const params: [2]ID = @splat(id);
//             if (SWEEP_X_FIRST) {
//                 result.is_x_axis = true;
//                 const found = self.x_edge_list.slice().find_exactly_n_item_pointers_from_n_params_in_order(ID, params[0..2], match_edge_by_id, refs[0..2]);
//                 assert(found);
//             }
//             if (SWEEP_Y_FIRST) {
//                 result.is_x_axis = false;
//                 const found = self.y_edge_list.slice().find_exactly_n_item_pointers_from_n_params_in_order(ID, params[0..2], match_edge_by_id, refs[0..2]);
//                 assert(found);
//             }
//             result.min_val = refs[0];
//             result.max_val = refs[1];
//             return result;
//         }

//         pub fn perform_sweep(self: *Self) []TouchPair {
//             if (SWEEP_X_SECOND) self.x_edge_list.clear_retaining_capacity();
//             if (SWEEP_Y_SECOND) self.y_edge_list.clear_retaining_capacity();
//             self.sweep_list.clear_retaining_capacity();
//             self.sweep_list_free_count = 0;
//             self.sweep_list_member_count = 0;
//             self.sweep_list_next_free = 0;
//             self.result_list.clear_retaining_capacity();
//             if (AUTO_UPDATE) {
//                 self.update_all_primary_movable_edges();
//             }
//             if (SWEEP_X_FIRST) {
//                 insertion_sort(Edge, self.x_edge_list.slice(), T, edge_xfrm, null);
//                 for (self.x_edge_list.slice()) |e| {
//                     const edge: Edge = e;
//                     if (edge.is_max) {
//                         self.remove_from_sweep_list(edge);
//                     } else {
//                         self.add_to_sweep_list(edge);
//                         if (SWEEP_Y_SECOND) {
//                             self.add_sweep_edge_to_y_edge_list(edge);
//                         } else {
//                             self.add_new_sweep_pairs_to_results(edge);
//                         }
//                     }
//                 }
//             }
//             if (SWEEP_Y_FIRST) {
//                 insertion_sort(Edge, self.y_edge_list.slice(), T, edge_xfrm, null);
//                 for (self.y_edge_list.slice()) |e| {
//                     const edge: Edge = e;
//                     if (edge.is_max) {
//                         self.remove_from_sweep_list(edge);
//                     } else {
//                         self.add_to_sweep_list(edge);
//                         if (SWEEP_X_SECOND) {
//                             self.add_sweep_edge_to_y_edge_list(edge);
//                         } else {
//                             self.add_new_sweep_pairs_to_results(edge);
//                         }
//                     }
//                 }
//             }
//             if (SWEEP_BOTH) {
//                 self.sweep_list.clear_retaining_capacity();
//                 self.sweep_list_free_count = 0;
//                 self.sweep_list_member_count = 0;
//                 self.sweep_list_next_free = 0;
//             }
//             if (SWEEP_Y_SECOND) {
//                 insertion_sort(Edge, self.y_edge_list.slice(), T, edge_xfrm, null);
//                 for (self.y_edge_list.slice()) |e| {
//                     const edge: Edge = e;
//                     if (edge.is_max) {
//                         self.remove_from_sweep_list(edge);
//                     } else {
//                         self.add_to_sweep_list(edge);
//                         self.add_new_sweep_pairs_to_results(edge);
//                     }
//                 }
//             }
//             if (SWEEP_X_SECOND) {
//                 insertion_sort(Edge, self.x_edge_list.slice(), T, edge_xfrm, null);
//                 for (self.x_edge_list.slice()) |e| {
//                     const edge: Edge = e;
//                     if (edge.is_max) {
//                         self.remove_from_sweep_list(edge);
//                     } else {
//                         self.add_to_sweep_list(edge);
//                         self.add_new_sweep_pairs_to_results(edge);
//                     }
//                 }
//             }
//         }
//     };
// }
