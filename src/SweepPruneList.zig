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
const AABB2 = Root.AABB2;
const List = Root.List;
const InsertionSort = Root.InsertionSort;
const AllocErrorBehavior = Root.CommonTypes.AllocErrorBehavior;
const GrowthModel = Root.CommonTypes.GrowthModel;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const Compare = Root.Compare;
const DummyAllocator = Root.DummyAllocator;
const BinarySearch = Root.BinarySearch;
const CompareFn = Compare.CompareFn;
const ComparePackage = Compare.ComparePackage;

pub const SweepPruneListOptions = struct {
    aabb_point_type: type = f32,
    aabb_container_type: type,
    aabb_id_type: type = u16,
    aabb_idx_type: type = u16,
    edge_idx_type: type = u16,
    edge_allocator: *const Allocator,
    x_overlap_allocator: *const Allocator,
    xy_overlap_allocator: *const Allocator,
    alloc_error_behavior: Root.StaticAllocList.AllocErrorBehavior = .ALLOCATION_ERRORS_PANIC,
    growth_model: Root.StaticAllocList.GrowthModel = .GROW_BY_50_PERCENT,
};

pub fn define_aabb2_sweep_and_prune_list(comptime options: SweepPruneListOptions) type {
    return struct {
        const Self = @This();
        pub const T = options.aabb_point_type;
        pub const AABB = AABB2.define_aabb2_type(options.aabb_point_type);
        pub const AABB_Id = options.aabb_id_type;
        pub const AABB_Idx = options.aabb_idx_type;
        pub const EdgeIdx = options.edge_idx_type;

        pub const Edge = extern struct {
            id: AABB_Id,
            is_right: bool,
        };
        pub const ListAdapter = struct {
            aabb_ptr_ptr: *[*]const AABB,
            aabb_len_ptr: *const AABB_Idx,
            aabb_find_fn: *const fn (id: AABB_Id, aabb_ptr_ptr: *[*]const AABB, aabb_len_ptr: *const AABB_Idx) *const AABB,
        };
        fn xfrm(edge: Edge, data: ?*const anyopaque) T {
            const adapter: *const ListAdapter = @ptrCast(@alignCast(data.?));
            const aabb = adapter.aabb_find_fn(edge.id, adapter.aabb_ptr_ptr, adapter.aabb_len_ptr);
            return if (edge.is_left) aabb.x_min else aabb.x_max;
        }
        const edge_base_opts = List.ListOptionsBase{
            .alignment = null,
            .alloc_error_behavior = options.alloc_error_behavior,
            .element_type = Edge,
            .growth_model = options.growth_model,
            .index_type = EdgeIdx,
            .secure_wipe_bytes = false,
        };
        const touch_base_opts = List.ListOptionsBase{
            .alignment = null,
            .alloc_error_behavior = options.alloc_error_behavior,
            .element_type = AABB_Id,
            .growth_model = options.growth_model,
            .index_type = EdgeIdx,
            .secure_wipe_bytes = false,
        };
        const EdgeList = List.define_statically_managed_list_type(edge_base_opts, options.edge_allocator);
        const TouchList = List.define_statically_managed_list_type(touch_base_opts, options.touch_allocator);

        adapter: ListAdapter,
        edge_list: EdgeList,
        touch_list: TouchList,

        pub fn init(adapter: ListAdapter) Self {
            return Self{
                .adapter = adapter,
                .edge_list = EdgeList.new_empty(),
                .touch_list = TouchList.new_empty(),
            };
        }
    };
}
