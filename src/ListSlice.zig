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

const std = @import("std");
const build = @import("builtin");

/// std imports
const Allocator = std.mem.Allocator;
const DEBUG = std.debug.print;
const math = std.math;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Type = Root.Types;
const Math = Root.Math;
const KindInfo = Type.KindInfo;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Common = Root.CommonTypes;
const Test = Root.Testing;
const dummy_alloc = Root.DummyAllocator.allocator_panic_free_noop;
const Random = std.Random;
const Io = std.Io;
const Growth = Common.GrowthModel;
const FuncParamType = Common.FuncParamType;
const ErrorBehavior = Common.ErrorBehavior;
const AllocErr = Utils.Alloc.AllocErr;

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const assert_unreachable_err_always_panic = Assert.assert_unreachable_err_always_panic;
const num_cast = Cast.num_cast;
const real_type_of = Type.real_type_of;
const real_type = Type.real_type;
const real_cast = Cast.real_cast;
const kind_info = KindInfo.get_kind_info;

const INTERNAL = @import("./ListSlice_Internal.zig");
comptime {
    if (build.is_test) {
        _ = @import("./ListSlice_Tests.zig");
    }
}

pub const BinaryInsertBias = enum {
    /// New items inserted on the left of items they are equal to
    LEFT_BIASED,
    /// New items inserted on the right of items they are equal to
    RIGHT_BIASED,
};

pub const FieldLayout = enum {
    WHOLE_STRUCTS,
    SPLIT_FIELDS,
};

pub const IndexLayout = enum {
    SERIAL_INDEXES,
};

pub const AllocMode = enum {
    ASSUME_CAP,
    REALLOC,
};

pub const GrowthMode = enum {
    DEFAULT_GROWTH,
    CUSTOM_GROWTH,
};

const MoveOneDisplaceMode = enum {
    PRESERVE_VAL,
    IGNORE_VAL,
};

pub const DeleteMode = enum {
    ORDERED,
    SWAP,
};

pub const DeleteReturnMode = enum {
    RETURN_VAL,
    IGNORE_VAL,
};

pub const RetainOriginal = enum {
    RETAIN_ORIGINAL_PTR,
    PTR_CAN_BE_OFFSET,
};

pub const Ownership = enum {
    OWNED_NOT_ALLOCATED,
    OWNED_ALLOCATED,
    REFERENCED_MUTABLE,
    REFERENCED_IMMUTABLE,
};

pub const FilterMode = enum {
    NO_FILTERING,
    USE_FILTERING_FUNC,
};

pub const SortOrder = enum(u8) {
    NORMAL,
    REVERSE,
};

pub const HeapKind = enum(u8) {
    MIN_HEAP,
    MAX_HEAP,
};

pub const TrackMaxStackMode = enum {
    MAX_STACK_LEN_NOT_IMPORTANT,
    TRACK_MAX_STACK_LEN,
};

pub const Order = enum {
    CHILDREN_FIRST,
    PARENTS_FIRST,
    ANY_ORDER_MIGHT_HAVE_IDX_GAPS,
    ANY_ORDER_NO_IDX_GAPS_ROOT_IDX_TO_LAST_IDX,
};

pub const FindOneMode = enum {
    FIRST,
    LAST,
};

pub const TraverserError = error{
    index_out_of_bounds,
};

pub const ReturnMode = enum {
    RETURN_PTR_OR_SLICE,
    RETURN_PTR_OR_SLICE_IDX,
    RETURN_IDX,
    RETURN_VOID,

    pub fn returns_ptr(comptime self: ReturnMode) bool {
        return switch (comptime self) {
            .RETURN_PTR_OR_SLICE, .RETURN_PTR_OR_SLICE_IDX => true,
            else => false,
        };
    }

    pub fn RetType(comptime self: ReturnMode, comptime PTR: type, comptime IDX: type) type {
        return switch (comptime self) {
            .RETURN_PTR_OR_SLICE => PTR,
            .RETURN_PTR_OR_SLICE_IDX => struct { PTR, IDX },
            .RETURN_IDX => IDX,
            .RETURN_VOID => void,
        };
    }
    pub fn ret_val(comptime self: ReturnMode, comptime PTR: type, comptime IDX: type, ptr: PTR, idx: IDX) self.RetType(PTR, IDX) {
        return switch (comptime self) {
            .RETURN_PTR_OR_SLICE => ptr,
            .RETURN_PTR_OR_SLICE_IDX => .{ ptr, idx },
            .RETURN_IDX => idx,
            .RETURN_VOID => {},
        };
    }
};

pub const QuicksortSettings = struct {
    /// `34` (32 + 2) = max input len of 2^32 items,
    /// if you really need more than this you can increase it, each
    /// additional 1 added doubles the max input len (`35` (33 + 2) = 2^33 max)
    QUICKSORT_MAX_STACK: u8 = 34,
    /// Signals to use a different partitioning scheme depending on whether you
    /// expect the data to have many items with equal order,
    /// or whether it is rare or impossible to occur
    SAME_ORDER_EXPECTATIONS: ManySameOrderExpectation = .DYNAMIC_BASED_ON_SAME_ORDER_DENSITY,
    /// The max size of a partition (sub-slice) to use quicksort.
    /// Under this length, partitions will intead use insertion sort
    QUICKSORT_TO_INSERTION_THRESHOLD: comptime_int = 24,
    /// If the quicksort partition depth exceeds `DEGENERATE_DETECTION_FACTOR * log2(input_len)`,
    /// it likely has a degenerate state (approaching worst case scenario).
    /// Switch to insertion sort (if small total input) or heapsort instead,
    ///
    /// If the total input len is <= `FALLBACK_WHEN_DEGENERATE_INSERTION_SORT_MAX_INPUT_LEN` (default 128)
    /// it falls back to insertion sort (lower overhead than heapsort, especially when quicksort has already
    /// partially sorted the data to some degree)
    ///
    /// Otherwise, fallback to heapsort
    FALLBACK_WHEN_DEGENERATE: bool = true,
    /// When degenerate fallback is enable, this value controls how degenerate
    /// the input needs to be before the fallback is triggered:
    ///
    /// ```zig
    /// const MAX_PARTITION_DEPTH = DEGENERATE_DETECTION_FACTOR * log2(input_len);
    /// ```
    DEGENERATE_DETECTION_FACTOR: comptime_int = 2,
    /// When the quicksort depth is more than twice the expected average depth (`DEGENERATE_DETECTION_FACTOR * log2(input_len)`),
    /// if the total input len is less than this value it will
    /// fallback to insertion sort on the entire input
    /// (already partially sorted, lower overhead than heapsort for small lists)
    ///
    /// Otherwise fallback to heapsort.
    FALLBACK_WHEN_DEGENERATE_INSERTION_SORT_MAX_INPUT_LEN: comptime_int = 128,
    /// When using partition mode `.DYNAMIC_BASED_ON_SAME_ORDER_DENSITY`, this is
    /// a percent threshold equal to `num_items_same_order_as_pivot / length_of_partition`,
    /// above which a counter of `partitions_ith_many_dupes` is incremented.
    ///
    /// When that counter exceeds a threshold, the partition mode permanently swaps
    /// to the 3-way scheme
    DYNAMIC_PARTITION_SWAP_TO_3_WAY_THRESHOLD: f32 = 0.33,
    /// When using partition mode `.DYNAMIC_BASED_ON_SAME_ORDER_DENSITY`, this is
    /// the number of times a partion with a high number of items with
    /// an equal order to the pivot are allowed before the partition mode
    /// permanently swaps to the 3-way scheme
    DYNAMIC_PARTITION_SWAP_TO_3_WAY_MAX_COUNT: comptime_int = 3,
};

pub const ManySameOrderExpectation = enum(u8) {
    /// Starts with normal 2-way partition mode, but if
    /// many items with the same order are detected
    /// it swaps to the 3-way partition mode
    DYNAMIC_BASED_ON_SAME_ORDER_DENSITY,
    /// Same as `.USE_DUTCH_FLAG_3_WAY_PARTITION`
    MANY_ITEMS_WITH_SAME_ORDER_LIKELY,
    /// Same as `.MANY_ITEMS_WITH_SAME_ORDER_LIKELY`
    USE_DUTCH_FLAG_3_WAY_PARTITION,
    /// Same as `.USE_HOARE_2_WAY_PARTITION`
    MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE,
    /// Same as `.MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE`
    USE_HOARE_2_WAY_PARTITION,
};

pub const ListDefNoElem = struct {
    IDX: type = u32,
    FIELD_LAYOUT: FieldLayout = .WHOLE_STRUCTS,
    INDEX_LAYOUT: IndexLayout = .SERIAL_INDEXES,
    OWNERSHIP: Ownership = .REFERENCED_IMMUTABLE,

    pub inline fn List(comptime self: ListDefNoElem, comptime T: type) type {
        return ListFullDefinition(T, self.IDX, self.FIELD_LAYOUT, self.INDEX_LAYOUT, self.OWNERSHIP);
    }

    pub fn with_type(comptime self: ListDefNoElem, comptime new_type: type) ListDef {
        return ListDef{
            .ELEM = new_type,
            .IDX = self.IDX,
            .FIELD_LAYOUT = self.FIELD_LAYOUT,
            .INDEX_LAYOUT = self.INDEX_LAYOUT,
            .OWNERSHIP = self.OWNERSHIP,
        };
    }
    pub fn with_ownership(comptime self: ListDefNoElem, comptime new_ownership: Root.ListSlice.Ownership) ListDefNoElem {
        return ListDefNoElem{
            .IDX = self.IDX,
            .FIELD_LAYOUT = self.FIELD_LAYOUT,
            .INDEX_LAYOUT = self.INDEX_LAYOUT,
            .OWNERSHIP = new_ownership,
        };
    }
};

pub const ListDef = struct {
    ELEM: type,
    IDX: type = u32,
    FIELD_LAYOUT: FieldLayout = .WHOLE_STRUCTS,
    INDEX_LAYOUT: IndexLayout = .SERIAL_INDEXES,
    OWNERSHIP: Ownership = .REFERENCED_IMMUTABLE,

    pub inline fn List(comptime self: ListDef) type {
        return ListFullDefinition(self.ELEM, self.IDX, self.FIELD_LAYOUT, self.INDEX_LAYOUT, self.OWNERSHIP);
    }

    pub fn with_type(comptime self: ListDef, comptime new_type: type) ListDef {
        return ListDef{
            .ELEM = new_type,
            .IDX = self.IDX,
            .FIELD_LAYOUT = self.FIELD_LAYOUT,
            .INDEX_LAYOUT = self.INDEX_LAYOUT,
            .OWNERSHIP = self.OWNERSHIP,
        };
    }
    pub fn with_ownership(comptime self: ListDef, comptime new_ownership: Root.ListSlice.Ownership) ListDef {
        return ListDef{
            .ELEM = self.ELEM,
            .IDX = self.IDX,
            .FIELD_LAYOUT = self.FIELD_LAYOUT,
            .INDEX_LAYOUT = self.INDEX_LAYOUT,
            .OWNERSHIP = new_ownership,
        };
    }
};
pub fn ListNotAllocated(comptime T: type) type {
    return ListFullDefinition(T, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_NOT_ALLOCATED);
}
pub fn ListAllocated(comptime T: type) type {
    return ListFullDefinition(T, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
}
pub fn SliceMutable(comptime T: type) type {
    return ListFullDefinition(T, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .REFERENCED_MUTABLE);
}
pub fn SliceImmutable(comptime T: type) type {
    return ListFullDefinition(T, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .REFERENCED_IMMUTABLE);
}
pub fn ListNotAllocatedAdvanced(comptime T: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout) type {
    return ListFullDefinition(T, u32, FIELD_LAYOUT, INDEX_LAYOUT, .OWNED_NOT_ALLOCATED);
}
pub fn ListAllocatedAdvanced(comptime T: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout) type {
    return ListFullDefinition(T, u32, FIELD_LAYOUT, INDEX_LAYOUT, .OWNED_ALLOCATED);
}
pub fn SliceMutableAdvanced(comptime T: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout) type {
    return ListFullDefinition(T, u32, FIELD_LAYOUT, INDEX_LAYOUT, .REFERENCED_MUTABLE);
}
pub fn SliceImmutableAdvanced(comptime T: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout) type {
    return ListFullDefinition(T, u32, FIELD_LAYOUT, INDEX_LAYOUT, .REFERENCED_IMMUTABLE);
}

pub fn ListFullDefinition(comptime ELEM: type, comptime IDX: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout, comptime OWNERSHIP: Ownership) type {
    assert_with_reason(Type.type_is_unsigned_int(IDX), @src(), "IDX type must be an unsigned integer, got type `{s}`", .{@typeName(IDX)});
    if (FIELD_LAYOUT == .SPLIT_FIELDS) {
        assert_with_reason(!Type.type_is_comptime_only(ELEM), @src(), ".SPLIT_FIELDS not compatible with comptime-only elements, type `{s}` is comptime-only", .{@typeName(ELEM)});
        assert_with_reason(@sizeOf(ELEM) > 0, @src(), ".SPLIT_FIELDS not compatible with zero-size elements, type `{s}` is zero-sized", .{@typeName(ELEM)});
    }
    const _NUM_FIELDS: usize = switch (@typeInfo(ELEM)) {
        .@"struct" => |s| s.field_names.len,
        else => 1,
    };
    if (FIELD_LAYOUT == .SPLIT_FIELDS) {
        assert_with_reason(Type.type_is_struct(ELEM), @src(), ".SPLIT_FIELDS is only valid on struct types", .{});
    }
    if (Type.type_is_struct(ELEM)) {
        assert_with_reason(@typeInfo(ELEM).@"struct".field_names.len > 0, @src(), "not compatible with zero-field structs", .{});
    }
    const _E_INT = @Int(.unsigned, @intCast(std.math.log2_int_ceil(usize, _NUM_FIELDS)));
    const _PROTO = struct {
        fn field_a_should_have_memory_offset_after_field_b(a: Type.StructFieldTypeAttrPkg, b: Type.StructFieldTypeAttrPkg) bool {
            return (@sizeOf(a.type) == 0) or @alignOf(a.type) < @alignOf(b.type);
        }
    };
    const _ORDERED_FIELD_NAMES, const _ORDERED_FIELD_TYPES, const _ORDERED_FIELD_OFFSETS, const _FIELD_ENUM = get: {
        switch (@typeInfo(ELEM)) {
            .@"struct" => {
                var info = Type.extract_struct_info(ELEM);
                var bundles: [_NUM_FIELDS]Type.StructFieldTypeAttrPkg = undefined;
                for (info.field_types[0..], info.field_names[0..], info.field_attrs[0..], 0..) |t, n, a, i| {
                    bundles[i] = Type.StructFieldTypeAttrPkg{
                        .type = t,
                        .name = n,
                        .attr = a,
                    };
                }
                if (FIELD_LAYOUT == .SPLIT_FIELDS) {
                    Root.Sort.InsertionSort.insertion_sort_with_func(bundles[0..], _PROTO.field_a_should_have_memory_offset_after_field_b);
                }
                var e_val: [_NUM_FIELDS]_E_INT = undefined;
                var names: [_NUM_FIELDS][]const u8 = undefined;
                var types: [_NUM_FIELDS]type = undefined;
                var offs: [_NUM_FIELDS + 1]IDX = undefined;
                var off_total: IDX = 0;
                inline for (bundles[0..], 0..) |bundle, i| {
                    e_val[i] = @intCast(i);
                    names[i] = bundle.name;
                    types[i] = bundle.type;
                    if (FIELD_LAYOUT == .SPLIT_FIELDS) {
                        offs[i] = off_total;
                        off_total += @sizeOf(bundle.type);
                    }
                }
                if (FIELD_LAYOUT == .SPLIT_FIELDS) {
                    offs[_NUM_FIELDS] = off_total;
                }
                break :get .{ names, types, offs, @Enum(_E_INT, .exhaustive, info.field_names[0..], e_val[0..]) };
            },
            else => break :get .{ [1][]const u8{"$SELF"}, [1]type{ELEM}, [2]IDX{ 0, @sizeOf(ELEM) }, @Enum(u1, .exhaustive, &.{"$SELF"}, &.{0}) },
        }
    };
    return struct {
        const ListSelf = @This();
        pub const LIST_DEF = ListDef{
            .ELEM = ELEM,
            .IDX = IDX,
            .FIELD_LAYOUT = FIELD_LAYOUT,
            .INDEX_LAYOUT = INDEX_LAYOUT,
            .OWNERSHIP = OWNERSHIP,
        };

        pub const Field = _FIELD_ENUM;
        pub const MemPtr = IMPL.MemPtr;
        pub const ElemPtr = IMPL.ElemPtr;
        pub const ElemPtrMany = IMPL.ElemPtrMany;
        pub const ElemPtrConst = IMPL.ElemPtrConst;
        pub const ElemPtrManyConst = IMPL.ElemPtrManyConst;
        pub const Slice = IMPL.Slice;
        pub const SliceConst = IMPL.SliceConst;
        pub const ListAlloc = IMPL.ListAlloc;
        pub const ListNotAlloc = IMPL.ListNotAlloc;
        pub const IdxElemPair = IMPL.IdxElemPair;
        pub const NULL_IDX = math.maxInt(IDX);
        pub const MAX_LEN = math.maxInt(IDX);

        pub const IMPL = INTERNAL.GLSInternal(LIST_DEF, _NUM_FIELDS, _E_INT, _FIELD_ENUM, _ORDERED_FIELD_NAMES, _ORDERED_FIELD_TYPES, _ORDERED_FIELD_OFFSETS);
        const HAS_ROOT_OFFSET = IMPL.HAS_ROOT_OFFSET;
        const IS_REFERENCE = IMPL.IS_REFERENCE;
        pub const FieldType = IMPL.FieldType;
        pub const FilterFnRT = IMPL.FilterFnRT;
        pub const FilterFnCT = IMPL.FilterFnCT;
        pub const CompareIdxIdxFnRT = IMPL.CompareIdxIdxFnRT;
        pub const CompareIdxIdxFnCT = IMPL.CompareIdxIdxFnCT;
        pub const CompareIdxValFnRT = IMPL.CompareIdxValFnRT;
        pub const CompareIdxValFnCT = IMPL.CompareIdxValFnCT;
        pub const ForEachActionRT = IMPL.ForEachActionRT;
        pub const ForEachActionCT = IMPL.ForEachActionCT;
        pub const NextIdxFnRT = IMPL.NextIdxFnRT;
        pub const NextIdxFnCT = IMPL.NextIdxFnCT;
        pub const ForEachReturn = IMPL.ForEachReturn;

        /// The root memory pointer of the memory region
        root_ptr: MemPtr = undefined,
        /// The root capacity of the memory region
        root_cap: IDX = 0,
        /// The offset from the root pointer that represents
        /// the 'first' element in the data. For example, this would be used
        /// in a Ring Buffer configuration, to denote the current starting position
        /// where index `0` sits
        root_offset: if (HAS_ROOT_OFFSET) IDX else void = if (HAS_ROOT_OFFSET) 0 else {},
        /// The length of the data, either its entirety or as a slice
        data_len: IDX = 0,
        /// If the list is a slice, this is the offset from index
        /// `0` where the slice starts
        slice_offset: if (IS_REFERENCE) IDX else void = if (IS_REFERENCE) 0 else {},

        //****************
        // INITIALIZE
        //****************
        pub inline fn new() ListSelf {
            return IMPL.new();
        }
        pub inline fn from_slice_keep_data(data_slice: []ELEM) ListSelf {
            return IMPL.from_slice_keep_data(data_slice);
        }
        pub inline fn from_slice_set_empty(data_slice: []ELEM) ListSelf {
            return IMPL.from_slice_set_empty(data_slice);
        }
        pub inline fn from_slice_const_keep_data(data_slice: []const ELEM) SliceConst {
            return IMPL.from_slice_const_keep_data(data_slice);
        }
        pub inline fn allocate_new(init_cap: IDX, alloc: Allocator) ListAlloc {
            return IMPL.allocate_new(init_cap, alloc);
        }
        pub inline fn allocate_new_set_len(init_cap: IDX, alloc: Allocator) ListAlloc {
            return IMPL.allocate_new_set_len(init_cap, alloc);
        }
        pub inline fn allocate_new_might_error(init_cap: IDX, alloc: Allocator) AllocErr!ListAlloc {
            return IMPL.allocate_new_might_error(init_cap, alloc);
        }
        pub inline fn from_allocated_slice_keep_data(data_slice: []ELEM) ListAlloc {
            return IMPL.from_allocated_slice_keep_data(data_slice);
        }
        pub inline fn from_allocated_slice_set_empty(data_slice: []ELEM) ListAlloc {
            return IMPL.from_allocated_slice_set_empty(data_slice);
        }

        //****************
        // SET
        //****************
        pub inline fn set(self: ListSelf, idx: IDX, val: ELEM) void {
            return IMPL.set(self, idx, val);
        }
        pub inline fn set_field(self: ListSelf, comptime field: Field, idx: IDX, val: FieldType(field)) void {
            return IMPL.set_field(self, field, idx, val);
        }
        pub inline fn set_last(self: ListSelf, val: ELEM) void {
            return IMPL.set_last(self, val);
        }
        pub inline fn set_nth_from_end(self: ListSelf, n: IDX, val: ELEM) void {
            return IMPL.set_nth_from_end(self, n, val);
        }
        pub inline fn memset_range(self: ListSelf, val: ELEM, start: IDX, end_exclusive: IDX) void {
            return IMPL.memset_range(self, val, start, end_exclusive);
        }
        pub inline fn memset_len(self: ListSelf, val: ELEM) void {
            return IMPL.memset_len(self, val);
        }
        pub inline fn memset_cap(self: ListSelf, val: ELEM) void {
            return IMPL.memset_cap(self, val);
        }
        //****************
        // GET
        //****************
        pub inline fn get(self: ListSelf, idx: IDX) ELEM {
            return IMPL.get(self, idx);
        }
        pub inline fn get_ptr(self: ListSelf, idx: IDX) ElemPtr {
            return IMPL.get_ptr(self, idx);
        }
        pub inline fn get_ptr_const(self: ListSelf, idx: IDX) ElemPtrConst {
            return IMPL.get_ptr_const(self, idx);
        }
        pub inline fn get_field(self: ListSelf, comptime field: Field, idx: IDX) FieldType(field) {
            return IMPL.get_field(self, field, idx);
        }
        pub inline fn get_field_ptr(self: ListSelf, comptime field: Field, idx: IDX) *FieldType(field) {
            return IMPL.get_field_ptr(self, field, idx);
        }
        pub inline fn get_field_ptr_const(self: ListSelf, comptime field: Field, idx: IDX) *const FieldType(field) {
            return IMPL.get_field_ptr_const(self, field, idx);
        }
        pub inline fn get_last(self: ListSelf) ELEM {
            return IMPL.get_last(self);
        }
        pub inline fn get_last_ptr(self: ListSelf) ElemPtr {
            return IMPL.get_last_ptr(self);
        }
        pub inline fn get_last_ptr_const(self: ListSelf) ElemPtrConst {
            return IMPL.get_last_ptr_const(self);
        }
        pub inline fn get_nth_from_end(self: ListSelf, n: IDX) ELEM {
            return IMPL.get_nth_from_end(self, n);
        }
        pub inline fn get_nth_from_end_ptr(self: ListSelf, n: IDX) ElemPtr {
            return IMPL.get_nth_from_end_ptr(self, n);
        }
        pub inline fn get_nth_from_end_ptr_const(self: ListSelf, n: IDX) ElemPtrConst {
            return IMPL.get_nth_from_end_ptr_const(self, n);
        }
        //****************
        // SPECIAL PTRS
        //****************
        pub inline fn get_many_item_ptr(self: ListSelf, idx: IDX) ElemPtrMany {
            return IMPL.get_many_item_ptr(self, idx);
        }
        pub inline fn get_many_item_ptr_const(self: ListSelf, idx: IDX) ElemPtrManyConst {
            return IMPL.get_many_item_ptr_const(self, idx);
        }
        pub inline fn get_field_zig_slice(self: ListSelf, comptime field: Field) []FieldType(field) {
            return IMPL.get_field_zig_slice(self, field);
        }
        pub inline fn get_field_zig_slice_const(self: ListSelf, comptime field: Field) []const FieldType(field) {
            return IMPL.get_field_zig_slice_const(self, field);
        }
        pub inline fn get_field_many_item_ptr(self: ListSelf, comptime field: Field, idx: IDX) [*]FieldType(field) {
            return IMPL.get_field_many_item_ptr(self, field, idx);
        }
        pub inline fn get_field_many_item_ptr_const(self: ListSelf, comptime field: Field, idx: IDX) [*]const FieldType(field) {
            return IMPL.get_field_many_item_ptr_const(self, field, idx);
        }
        pub inline fn incr_many_item_pointer(ptr: ElemPtrMany, delta: IDX) ElemPtrMany {
            return IMPL.incr_many_item_pointer(ptr, delta);
        }
        pub inline fn decr_many_item_pointer(ptr: ElemPtrMany, delta: IDX) ElemPtrMany {
            return IMPL.decr_many_item_pointer(ptr, delta);
        }
        pub inline fn move_many_item_pointer(ptr: ElemPtrMany, delta: isize) ElemPtrMany {
            return IMPL.move_many_item_pointer(ptr, delta);
        }
        pub inline fn incr_many_item_pointer_const(ptr: ElemPtrManyConst, delta: IDX) ElemPtrManyConst {
            return IMPL.incr_many_item_pointer_const(ptr, delta);
        }
        pub inline fn decr_many_item_pointer_const(ptr: ElemPtrManyConst, delta: IDX) ElemPtrManyConst {
            return IMPL.decr_many_item_pointer_const(ptr, delta);
        }
        pub inline fn move_many_item_pointer_const(ptr: ElemPtrManyConst, delta: isize) ElemPtrManyConst {
            return IMPL.move_many_item_pointer_const(ptr, delta);
        }
        pub inline fn cast_ptr_to_many_item_ptr(ptr: ElemPtr) ElemPtrMany {
            return IMPL.cast_ptr_to_many_item_ptr(ptr);
        }
        pub inline fn cast_ptr_to_many_item_ptr_const(ptr: ElemPtrConst) ElemPtrManyConst {
            return IMPL.cast_ptr_to_many_item_ptr_const(ptr);
        }
        pub inline fn cast_many_item_ptr_to_ptr(ptrs: ElemPtrMany) ElemPtr {
            return IMPL.cast_many_item_ptr_to_ptr(ptrs);
        }
        pub inline fn cast_many_item_ptr_to_ptr_const(ptrs: ElemPtrManyConst) ElemPtrConst {
            return IMPL.cast_many_item_ptr_to_ptr_const(ptrs);
        }
        //****************
        // LEN/CAP
        //****************
        pub inline fn is_empty(self: ListSelf) bool {
            return IMPL.is_empty(self);
        }
        pub inline fn not_empty(self: ListSelf) bool {
            return IMPL.not_empty(self);
        }
        pub inline fn get_len(self: ListSelf) IDX {
            return IMPL.get_len(self);
        }
        pub inline fn set_len(self: *ListSelf, new_len: IDX) void {
            return IMPL.set_len(self, new_len);
        }
        pub inline fn incr_len(self: *ListSelf, count: IDX) void {
            return IMPL.incr_len(self, count);
        }
        pub inline fn set_len_unchecked(self: *ListSelf, new_len: IDX) void {
            return IMPL.set_len_unchecked(self, new_len);
        }
        pub inline fn incr_len_unchecked(self: *ListSelf, count: IDX) void {
            return IMPL.incr_len_unchecked(self, count);
        }
        pub inline fn incr_len_to_cap(self: *ListSelf) void {
            return IMPL.incr_len_to_cap(self);
        }
        pub inline fn set_len_clamped(self: *ListSelf, new_len: IDX) void {
            return IMPL.set_len_clamped(self, new_len);
        }
        pub inline fn incr_len_clamped(self: *ListSelf, count: IDX) void {
            return IMPL.incr_len_clamped(self, count);
        }
        pub inline fn decr_len(self: *ListSelf, count: IDX) void {
            return IMPL.decr_len(self, count);
        }
        pub inline fn decr_len_unchecked(self: *ListSelf, count: IDX) void {
            return IMPL.decr_len_unchecked(self, count);
        }
        pub inline fn decr_len_clamped(self: *ListSelf, count: IDX) void {
            return IMPL.decr_len_clamped(self, count);
        }
        pub inline fn get_cap(self: ListSelf) IDX {
            return IMPL.get_cap(self);
        }
        pub inline fn set_root_cap(self: *ListSelf, new_cap: IDX) void {
            return IMPL.set_root_cap(self, new_cap);
        }
        pub inline fn incr_root_cap(self: *ListSelf, count: IDX) void {
            return IMPL.incr_root_cap(self, count);
        }
        pub inline fn incr_root_cap_clamped(self: *ListSelf, count: IDX) void {
            return IMPL.incr_root_cap_clamped(self, count);
        }
        pub inline fn decr_root_cap(self: *ListSelf, count: IDX) void {
            return IMPL.decr_root_cap(self, count);
        }
        pub inline fn decr_root_cap_clamped(self: *ListSelf, count: IDX) void {
            return IMPL.decr_root_cap_clamped(self, count);
        }
        pub inline fn get_unused_space(self: ListSelf) IDX {
            return IMPL.get_unused_space(self);
        }
        pub inline fn clear(self: *ListSelf) void {
            return IMPL.clear(self);
        }
        //****************
        // SLICE
        //****************

        pub inline fn slice(self: ListSelf, start: IDX, end_exclusive: IDX) Slice {
            return IMPL.slice(self, start, end_exclusive);
        }
        pub inline fn slice_const(self: ListSelf, start: IDX, end_exclusive: IDX) SliceConst {
            return IMPL.slice_const(self, start, end_exclusive);
        }
        pub inline fn slice_from_start(self: ListSelf, end_exclusive: IDX) Slice {
            return IMPL.slice_from_start(self, end_exclusive);
        }
        pub inline fn slice_from_start_const(self: ListSelf, end_exclusive: IDX) SliceConst {
            return IMPL.slice_from_start_const(self, end_exclusive);
        }
        pub inline fn slice_to_end(self: ListSelf, start: IDX) Slice {
            return IMPL.slice_to_end(self, start);
        }
        pub inline fn slice_to_end_const(self: ListSelf, start: IDX) SliceConst {
            return IMPL.slice_to_end_const(self, start);
        }
        pub inline fn slice_entire(self: ListSelf) Slice {
            return IMPL.slice_entire(self);
        }
        pub inline fn slice_entire_const(self: ListSelf) SliceConst {
            return IMPL.slice_entire_const(self);
        }
        pub inline fn zig_slice(self: ListSelf, start: IDX, end_exclusive: IDX) []ELEM {
            return IMPL.zig_slice(self, start, end_exclusive);
        }
        pub inline fn zig_slice_const(self: ListSelf, start: IDX, end_exclusive: IDX) []const ELEM {
            return IMPL.zig_slice_const(self, start, end_exclusive);
        }
        pub inline fn zig_slice_from_start(self: ListSelf, end_exclusive: IDX) []ELEM {
            return IMPL.zig_slice_from_start(self, end_exclusive);
        }
        pub inline fn zig_slice_from_start_const(self: ListSelf, end_exclusive: IDX) []const ELEM {
            return IMPL.zig_slice_from_start_const(self, end_exclusive);
        }
        pub inline fn zig_slice_to_end(self: ListSelf, start: IDX) []ELEM {
            return IMPL.zig_slice_to_end(self, start);
        }
        pub inline fn zig_slice_to_end_const(self: ListSelf, start: IDX) []const ELEM {
            return IMPL.zig_slice_to_end_const(self, start);
        }
        pub inline fn zig_slice_entire(self: ListSelf) []ELEM {
            return IMPL.zig_slice_entire(self);
        }
        pub inline fn zig_slice_entire_const(self: ListSelf) []const ELEM {
            return IMPL.zig_slice_entire_const(self);
        }
        //****************
        // SLICE MOVEMENT
        //****************
        pub inline fn incr_slice_start(self: *ListSelf, count: IDX) void {
            return IMPL.incr_slice_start(self, count);
        }
        pub inline fn decr_slice_start(self: *ListSelf, count: IDX) void {
            return IMPL.decr_slice_start(self, count);
        }
        pub inline fn incr_slice_end(self: *ListSelf, count: IDX) void {
            return IMPL.incr_slice_end(self, count);
        }
        pub inline fn decr_slice_end(self: *ListSelf, count: IDX) void {
            return IMPL.decr_slice_end(self, count);
        }
        pub inline fn slide_slice_lower(self: *ListSelf, count: IDX) void {
            return IMPL.slide_slice_lower(self, count);
        }
        pub inline fn slide_slice_higher(self: *ListSelf, count: IDX) void {
            return IMPL.slide_slice_higher(self, count);
        }
        pub inline fn split_off_slice_from_start(self: *ListSelf, count: IDX) Slice {
            return IMPL.split_off_slice_from_start(self, count);
        }
        pub inline fn split_off_slice_from_start_const(self: *ListSelf, count: IDX) SliceConst {
            return IMPL.split_off_slice_from_start_const(self, count);
        }
        pub inline fn split_off_slice_from_end(self: *ListSelf, count: IDX) Slice {
            return IMPL.split_off_slice_from_end(self, count);
        }
        pub inline fn split_off_slice_from_end_const(self: *ListSelf, count: IDX) SliceConst {
            return IMPL.split_off_slice_from_end_const(self, count);
        }
        pub inline fn split_off_zig_slice_from_start(self: *ListSelf, count: IDX) []ELEM {
            return IMPL.split_off_zig_slice_from_start(self, count);
        }
        pub inline fn split_off_zig_slice_from_start_const(self: *ListSelf, count: IDX) []const ELEM {
            return IMPL.split_off_zig_slice_from_start_const(self, count);
        }
        pub inline fn split_off_zig_slice_from_end(self: *ListSelf, count: IDX) []ELEM {
            return IMPL.split_off_zig_slice_from_end(self, count);
        }
        pub inline fn split_off_zig_slice_from_end_const(self: *ListSelf, count: IDX) []const ELEM {
            return IMPL.split_off_zig_slice_from_end_const(self, count);
        }
        //****************
        // REVERSE/ROTATE
        //****************
        pub inline fn reverse_range(self: ListSelf, start: IDX, end_exclusive: IDX) void {
            return IMPL.reverse_range(self, start, end_exclusive);
        }
        pub inline fn reverse(self: ListSelf) void {
            return IMPL.reverse(self);
        }
        pub inline fn rotate_range(self: ListSelf, start: IDX, end_exclusive: IDX, delta: i64) void {
            return IMPL.rotate_range(self, start, end_exclusive, delta);
        }
        pub inline fn rotate(self: ListSelf, delta: i64) void {
            return IMPL.rotate(self, delta);
        }
        pub inline fn rotate_range_right(self: ListSelf, start: IDX, end_exclusive: IDX, count: IDX) void {
            return IMPL.rotate_range_right(self, start, end_exclusive, count);
        }
        pub inline fn rotate_right(self: ListSelf, count: IDX) void {
            return IMPL.rotate_right(self, count);
        }
        pub inline fn rotate_range_left(self: ListSelf, start: IDX, end_exclusive: IDX, count: IDX) void {
            return IMPL.rotate_range_left(self, start, end_exclusive, count);
        }
        pub inline fn rotate_left(self: ListSelf, count: IDX) void {
            return IMPL.rotate_left(self, count);
        }
        pub inline fn move_block_displace(self: ListSelf, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            return IMPL.move_block_displace(self, old_start, old_end_exclusive, new_start);
        }
        //****************
        // MOVE ONE/BLOCK
        //****************
        pub inline fn move_block_right_displace(self: ListSelf, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            return IMPL.move_block_right_displace(self, old_start, old_end_exclusive, new_start);
        }
        pub inline fn move_block_left_displace(self: ListSelf, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            return IMPL.move_block_left_displace(self, old_start, old_end_exclusive, new_start);
        }
        pub inline fn move_block_right_overwrite(self: ListSelf, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            return IMPL.move_block_right_overwrite(self, old_start, old_end_exclusive, new_start);
        }
        pub inline fn move_block_left_overwrite(self: ListSelf, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            return IMPL.move_block_left_overwrite(self, old_start, old_end_exclusive, new_start);
        }
        pub inline fn move_one_displace(self: ListSelf, old_idx: IDX, new_idx: IDX) void {
            return IMPL.move_one_displace(self, old_idx, new_idx);
        }
        pub inline fn move_one_right_displace(self: ListSelf, old_idx: IDX, new_idx: IDX) void {
            return IMPL.move_one_right_displace(self, old_idx, new_idx);
        }
        pub inline fn move_one_left_displace(self: ListSelf, old_idx: IDX, new_idx: IDX) void {
            return IMPL.move_one_left_displace(self, old_idx, new_idx);
        }
        pub inline fn move_one_overwrite(self: ListSelf, old_idx: IDX, new_idx: IDX) void {
            return IMPL.move_one_overwrite(self, old_idx, new_idx);
        }
        pub inline fn swap(self: ListSelf, idx_a: IDX, idx_b: IDX) void {
            return IMPL.swap(self, idx_a, idx_b);
        }
        pub inline fn swap_already_have_b(self: ListSelf, idx_a: IDX, idx_b: IDX, val_b: ELEM) void {
            return IMPL.swap_already_have_b(self, idx_a, idx_b, val_b);
        }
        //****************
        // SHUFFLE
        //****************
        pub inline fn shuffle_range_biased(self: ListSelf, start: IDX, end_exclusive: IDX, iterations: IDX, rand: Random) void {
            return IMPL.shuffle_range_biased(self, start, end_exclusive, iterations, rand);
        }
        pub inline fn shuffle_biased(self: ListSelf, iterations: IDX, rand: Random) void {
            return IMPL.shuffle_biased(self, iterations, rand);
        }
        pub inline fn shuffle_range_unbiased(self: ListSelf, start: IDX, end_exclusive: IDX, iterations: IDX, rand: Random) void {
            return IMPL.shuffle_range_unbiased(self, start, end_exclusive, iterations, rand);
        }
        pub inline fn shuffle_unbiased(self: ListSelf, iterations: IDX, rand: Random) void {
            return IMPL.shuffle_unbiased(self, iterations, rand);
        }
        pub inline fn shuffle_range_unbiased_once(self: ListSelf, start: IDX, end_exclusive: IDX, rand: Random) void {
            return IMPL.shuffle_range_unbiased_once(self, start, end_exclusive, rand);
        }
        pub inline fn shuffle_unbiased_once(self: ListSelf, rand: Random) void {
            return IMPL.shuffle_unbiased_once(self, rand);
        }
        //**************
        // ALLOC/REALLOC
        //**************
        pub inline fn grow_capacity_if_needed(self: *ListSelf, need_capacity: IDX, growth: Growth, alloc: Allocator) void {
            return IMPL.grow_capacity_if_needed(self, need_capacity, growth, alloc);
        }
        pub inline fn grow_capacity_if_needed_for_n_more_elems(self: *ListSelf, count: IDX, growth: Growth, alloc: Allocator) void {
            return IMPL.grow_capacity_if_needed_for_n_more_elems(self, count, growth, alloc);
        }
        pub inline fn shrink_capacity_to_at_most(self: *ListSelf, new_max_cap: IDX, alloc: Allocator) void {
            return IMPL.shrink_capacity_to_at_most(self, new_max_cap, alloc);
        }
        pub inline fn shrink_capacity_reserve_at_most_n_free_space(self: *ListSelf, at_most_n_free_space: IDX, alloc: Allocator) void {
            return IMPL.shrink_capacity_reserve_at_most_n_free_space(self, at_most_n_free_space, alloc);
        }
        pub inline fn resize_capacity_exact(self: *ListSelf, exact_cap: IDX, alloc: Allocator) void {
            return IMPL.resize_capacity_exact(self, exact_cap, alloc);
        }
        pub inline fn grow_capacity_if_needed_might_error(self: *ListSelf, need_capacity: IDX, growth: Growth, alloc: Allocator) AllocErr!void {
            return IMPL.grow_capacity_if_needed_might_error(self, need_capacity, growth, alloc);
        }
        pub inline fn grow_capacity_if_needed_for_n_more_elems_might_error(self: *ListSelf, count: IDX, growth: Growth, alloc: Allocator) AllocErr!void {
            return IMPL.grow_capacity_if_needed_for_n_more_elems_might_error(self, count, growth, alloc);
        }
        pub inline fn shrink_capacity_to_at_most_might_error(self: *ListSelf, new_max_cap: IDX, alloc: Allocator) AllocErr!void {
            return IMPL.shrink_capacity_to_at_most_might_error(self, new_max_cap, alloc);
        }
        pub inline fn shrink_capacity_reserve_at_most_n_free_space_might_error(self: *ListSelf, at_most_n_free_space: IDX, alloc: Allocator) AllocErr!void {
            return IMPL.shrink_capacity_reserve_at_most_n_free_space_might_error(self, at_most_n_free_space, alloc);
        }
        pub inline fn resize_capacity_exact_might_error(self: *ListSelf, exact_cap: IDX, alloc: Allocator) AllocErr!void {
            return IMPL.resize_capacity_exact_might_error(self, exact_cap, alloc);
        }
        pub inline fn free(self: *ListSelf, alloc: Allocator) void {
            return IMPL.free(self, alloc);
        }
        pub inline fn free_if_non_zero(self: *ListSelf, alloc: Allocator) void {
            return IMPL.free_if_non_zero(self, alloc);
        }
        pub inline fn free_if_owned(self: *ListSelf, alloc: Allocator) void {
            return IMPL.free_if_owned(self, alloc);
        }
        pub inline fn free_if_owned_and_non_zero(self: *ListSelf, alloc: Allocator) void {
            return IMPL.free_if_owned_and_non_zero(self, alloc);
        }
        //*********
        // COPY TO
        //*********
        pub inline fn copy_self_range_to_dest_range(self: ListSelf, self_start: IDX, self_end_exclusive: IDX, dest_: anytype, dest_start_: anytype) void {
            return IMPL.copy_self_range_to_dest_range(self, self_start, self_end_exclusive, dest_, dest_start_);
        }
        pub inline fn copy_self_range_to_dest_start(self: ListSelf, self_start: IDX, self_end_exclusive: IDX, dest_: anytype) void {
            return IMPL.copy_self_range_to_dest_start(self, self_start, self_end_exclusive, dest_);
        }
        pub inline fn copy_self_range_to_dest_end(self: ListSelf, self_start: IDX, self_end_exclusive: IDX, dest_: anytype) void {
            return IMPL.copy_self_range_to_dest_end(self, self_start, self_end_exclusive, dest_);
        }
        pub inline fn copy_self_start_to_dest_range(self: ListSelf, count: IDX, dest_: anytype, dest_start: anytype) void {
            return IMPL.copy_self_start_to_dest_range(self, count, dest_, dest_start);
        }
        pub inline fn copy_self_start_to_dest_start(self: ListSelf, count: IDX, dest_: anytype) void {
            return IMPL.copy_self_start_to_dest_start(self, count, dest_);
        }
        pub inline fn copy_self_start_to_dest_end(self: ListSelf, count: IDX, dest_: anytype) void {
            return IMPL.copy_self_start_to_dest_end(self, count, dest_);
        }
        pub inline fn copy_self_end_to_dest_range(self: ListSelf, count: IDX, dest_: anytype, dest_start: anytype) void {
            return IMPL.copy_self_end_to_dest_range(self, count, dest_, dest_start);
        }
        pub inline fn copy_self_end_to_dest_start(self: ListSelf, count: IDX, dest_: anytype) void {
            return IMPL.copy_self_end_to_dest_start(self, count, dest_);
        }
        pub inline fn copy_self_end_to_dest_end(self: ListSelf, count: IDX, dest_: anytype) void {
            return IMPL.copy_self_end_to_dest_end(self, count, dest_);
        }
        pub inline fn copy_entire_self_to_dest_range(self: ListSelf, dest_: anytype, dest_start: anytype) void {
            return IMPL.copy_entire_self_to_dest_range(self, dest_, dest_start);
        }
        pub inline fn copy_entire_self_to_dest_start(self: ListSelf, dest_: anytype) void {
            return IMPL.copy_entire_self_to_dest_start(self, dest_);
        }
        pub inline fn copy_entire_self_to_dest_end(self: ListSelf, dest_: anytype) void {
            return IMPL.copy_entire_self_to_dest_end(self, dest_);
        }
        //************s
        // APPEND ONE
        //************
        pub inline fn append_one_slot_assume_cap_get_ptr(self: *ListSelf) ElemPtr {
            return IMPL.append_one_slot_assume_cap_get_ptr(self);
        }
        pub inline fn append_one_slot_with_growth_get_ptr(self: *ListSelf, growth: Growth, alloc: Allocator) ElemPtr {
            return IMPL.append_one_slot_with_growth_get_ptr(self, growth, alloc);
        }
        pub inline fn append_one_slot_get_ptr(self: *ListSelf, alloc: Allocator) ElemPtr {
            return IMPL.append_one_slot_get_ptr(self, alloc);
        }
        pub inline fn append_one_slot_assume_cap_get_ptr_idx(self: *ListSelf) struct { ElemPtr, IDX } {
            return IMPL.append_one_slot_assume_cap_get_ptr_idx(self);
        }
        pub inline fn append_one_slot_with_growth_get_ptr_idx(self: *ListSelf, growth: Growth, alloc: Allocator) struct { ElemPtr, IDX } {
            return IMPL.append_one_slot_with_growth_get_ptr_idx(self, growth, alloc);
        }
        pub inline fn append_one_slot_get_ptr_idx(self: *ListSelf, alloc: Allocator) struct { ElemPtr, IDX } {
            return IMPL.append_one_slot_get_ptr_idx(self, alloc);
        }
        pub inline fn append_one_slot_assume_cap_get_idx(self: *ListSelf) IDX {
            return IMPL.append_one_slot_assume_cap_get_idx(self);
        }
        pub inline fn append_one_slot_with_growth_get_idx(self: *ListSelf, growth: Growth, alloc: Allocator) IDX {
            return IMPL.append_one_slot_with_growth_get_idx(self, growth, alloc);
        }
        pub inline fn append_one_slot_get_idx(self: *ListSelf, alloc: Allocator) IDX {
            return IMPL.append_one_slot_get_idx(self, alloc);
        }
        pub inline fn append_one_slot_assume_cap(self: *ListSelf) void {
            return IMPL.append_one_slot_assume_cap(self);
        }
        pub inline fn append_one_slot_with_growth(self: *ListSelf, growth: Growth, alloc: Allocator) void {
            return IMPL.append_one_slot_with_growth(self, growth, alloc);
        }
        pub inline fn append_one_slot(self: *ListSelf, alloc: Allocator) void {
            return IMPL.append_one_slot(self, alloc);
        }
        pub inline fn append_one_assume_cap_get_ptr(self: *ListSelf, val: ELEM) ElemPtr {
            return IMPL.append_one_assume_cap_get_ptr(self, val);
        }
        pub inline fn append_one_with_growth_get_ptr(self: *ListSelf, val: ELEM, growth: Growth, alloc: Allocator) ElemPtr {
            return IMPL.append_one_with_growth_get_ptr(self, val, growth, alloc);
        }
        pub inline fn append_one_get_ptr(self: *ListSelf, val: ELEM, alloc: Allocator) ElemPtr {
            return IMPL.append_one_get_ptr(self, val, alloc);
        }
        pub inline fn append_one_assume_cap_get_ptr_idx(self: *ListSelf, val: ELEM) struct { ElemPtr, IDX } {
            return IMPL.append_one_assume_cap_get_ptr_idx(self, val);
        }
        pub inline fn append_one_with_growth_get_ptr_idx(self: *ListSelf, val: ELEM, growth: Growth, alloc: Allocator) struct { ElemPtr, IDX } {
            return IMPL.append_one_with_growth_get_ptr_idx(self, val, growth, alloc);
        }
        pub inline fn append_one_get_ptr_idx(self: *ListSelf, val: ELEM, alloc: Allocator) struct { ElemPtr, IDX } {
            return IMPL.append_one_get_ptr_idx(self, val, alloc);
        }
        pub inline fn append_one_assume_cap_get_idx(self: *ListSelf, val: ELEM) IDX {
            return IMPL.append_one_assume_cap_get_idx(self, val);
        }
        pub inline fn append_one_with_growth_get_idx(self: *ListSelf, val: ELEM, growth: Growth, alloc: Allocator) IDX {
            return IMPL.append_one_with_growth_get_idx(self, val, growth, alloc);
        }
        pub inline fn append_one_get_idx(self: *ListSelf, val: ELEM, alloc: Allocator) IDX {
            return IMPL.append_one_get_idx(self, val, alloc);
        }
        pub inline fn append_one_assume_cap(self: *ListSelf, val: ELEM) void {
            return IMPL.append_one_assume_cap(self, val);
        }
        pub inline fn append_one_with_growth(self: *ListSelf, val: ELEM, growth: Growth, alloc: Allocator) void {
            return IMPL.append_one_with_growth(self, val, growth, alloc);
        }
        pub inline fn append_one(self: *ListSelf, val: ELEM, alloc: Allocator) void {
            return IMPL.append_one(self, val, alloc);
        }
        //*************
        // APPEND MANY
        //*************
        pub inline fn append_many_slots_assume_cap_get_slice(self: *ListSelf, count: IDX) Slice {
            return IMPL.append_many_slots_assume_cap_get_slice(self, count);
        }
        pub inline fn append_many_slots_with_growth_get_slice(self: *ListSelf, count: IDX, growth: Growth, alloc: Allocator) Slice {
            return IMPL.append_many_slots_with_growth_get_slice(self, count, growth, alloc);
        }
        pub inline fn append_many_slots_get_slice(self: *ListSelf, count: IDX, alloc: Allocator) Slice {
            return IMPL.append_many_slots_get_slice(self, count, alloc);
        }
        pub inline fn append_many_slots_assume_cap_get_slice_idx(self: *ListSelf, count: IDX) struct { Slice, IDX } {
            return IMPL.append_many_slots_assume_cap_get_slice_idx(self, count);
        }
        pub inline fn append_many_slots_with_growth_get_slice_idx(self: *ListSelf, count: IDX, growth: Growth, alloc: Allocator) struct { Slice, IDX } {
            return IMPL.append_many_slots_with_growth_get_slice_idx(self, count, growth, alloc);
        }
        pub inline fn append_many_slots_get_slice_idx(self: *ListSelf, count: IDX, alloc: Allocator) struct { Slice, IDX } {
            return IMPL.append_many_slots_get_slice_idx(self, count, alloc);
        }
        pub inline fn append_many_slots_assume_cap_get_idx(self: *ListSelf, count: IDX) IDX {
            return IMPL.append_many_slots_assume_cap_get_idx(self, count);
        }
        pub inline fn append_many_slots_with_growth_get_idx(self: *ListSelf, count: IDX, growth: Growth, alloc: Allocator) IDX {
            return IMPL.append_many_slots_with_growth_get_idx(self, count, growth, alloc);
        }
        pub inline fn append_many_slots_get_idx(self: *ListSelf, count: IDX, alloc: Allocator) IDX {
            return IMPL.append_many_slots_get_idx(self, count, alloc);
        }
        pub inline fn append_many_slots_assume_cap(self: *ListSelf, count: IDX) void {
            return IMPL.append_many_slots_assume_cap(self, count);
        }
        pub inline fn append_many_slots_with_growth(self: *ListSelf, count: IDX, growth: Growth, alloc: Allocator) void {
            return IMPL.append_many_slots_with_growth(self, count, growth, alloc);
        }
        pub inline fn append_many_slots(self: *ListSelf, count: IDX, alloc: Allocator) void {
            return IMPL.append_many_slots(self, count, alloc);
        }
        pub inline fn append_many_assume_cap_get_slice(self: *ListSelf, vals_: anytype) Slice {
            return IMPL.append_many_assume_cap_get_slice(self, vals_);
        }
        pub inline fn append_many_with_growth_get_slice(self: *ListSelf, vals_: anytype, growth: Growth, alloc: Allocator) Slice {
            return IMPL.append_many_with_growth_get_slice(self, vals_, growth, alloc);
        }
        pub inline fn append_many_get_slice(self: *ListSelf, vals_: anytype, alloc: Allocator) Slice {
            return IMPL.append_many_get_slice(self, vals_, alloc);
        }
        pub inline fn append_many_assume_cap_get_ptr_idx(self: *ListSelf, vals_: anytype) struct { Slice, IDX } {
            return IMPL.append_many_assume_cap_get_ptr_idx(self, vals_);
        }
        pub inline fn append_many_with_growth_get_ptr_idx(self: *ListSelf, vals_: anytype, growth: Growth, alloc: Allocator) struct { Slice, IDX } {
            return IMPL.append_many_with_growth_get_ptr_idx(self, vals_, growth, alloc);
        }
        pub inline fn append_many_get_ptr_idx(self: *ListSelf, vals_: anytype, alloc: Allocator) struct { Slice, IDX } {
            return IMPL.append_many_get_ptr_idx(self, vals_, alloc);
        }
        pub inline fn append_many_assume_cap_get_idx(self: *ListSelf, vals_: anytype) IDX {
            return IMPL.append_many_assume_cap_get_idx(self, vals_);
        }
        pub inline fn append_many_with_growth_get_idx(self: *ListSelf, vals_: anytype, growth: Growth, alloc: Allocator) IDX {
            return IMPL.append_many_with_growth_get_idx(self, vals_, growth, alloc);
        }
        pub inline fn append_many_get_idx(self: *ListSelf, vals_: anytype, alloc: Allocator) IDX {
            return IMPL.append_many_get_idx(self, vals_, alloc);
        }
        pub inline fn append_many_assume_cap(self: *ListSelf, vals_: anytype) void {
            return IMPL.append_many_assume_cap(self, vals_);
        }
        pub inline fn append_many_with_growth(self: *ListSelf, vals_: anytype, growth: Growth, alloc: Allocator) void {
            return IMPL.append_many_with_growth(self, vals_, growth, alloc);
        }
        pub inline fn append_many(self: *ListSelf, vals_: anytype, alloc: Allocator) void {
            return IMPL.append_many(self, vals_, alloc);
        }
        //*************
        // PREPEND ONE
        //*************
        pub inline fn prepend_one_slot_assume_cap_get_ptr(self: *ListSelf) ElemPtr {
            return IMPL.prepend_one_slot_assume_cap_get_ptr(self);
        }
        pub inline fn prepend_one_slot_with_growth_get_ptr(self: *ListSelf, growth: Growth, alloc: Allocator) ElemPtr {
            return IMPL.prepend_one_slot_with_growth_get_ptr(self, growth, alloc);
        }
        pub inline fn prepend_one_slot_get_ptr(self: *ListSelf, alloc: Allocator) ElemPtr {
            return IMPL.prepend_one_slot_get_ptr(self, alloc);
        }
        pub inline fn prepend_one_slot_assume_cap(self: *ListSelf) void {
            return IMPL.prepend_one_slot_assume_cap(self);
        }
        pub inline fn prepend_one_slot_with_growth(self: *ListSelf, growth: Growth, alloc: Allocator) void {
            return IMPL.prepend_one_slot_with_growth(self, growth, alloc);
        }
        pub inline fn prepend_one_slot(self: *ListSelf, alloc: Allocator) void {
            return IMPL.prepend_one_slot(self, alloc);
        }
        pub inline fn prepend_one_assume_cap_get_ptr(self: *ListSelf, val: ELEM) ElemPtr {
            return IMPL.prepend_one_assume_cap_get_ptr(self, val);
        }
        pub inline fn prepend_one_with_growth_get_ptr(self: *ListSelf, val: ELEM, growth: Growth, alloc: Allocator) ElemPtr {
            return IMPL.prepend_one_with_growth_get_ptr(self, val, growth, alloc);
        }
        pub inline fn prepend_one_get_ptr(self: *ListSelf, val: ELEM, alloc: Allocator) ElemPtr {
            return IMPL.prepend_one_get_ptr(self, val, alloc);
        }
        pub inline fn prepend_one_assume_cap(self: *ListSelf, val: ELEM) void {
            return IMPL.prepend_one_assume_cap(self, val);
        }
        pub inline fn prepend_one_with_growth(self: *ListSelf, val: ELEM, growth: Growth, alloc: Allocator) void {
            return IMPL.prepend_one_with_growth(self, val, growth, alloc);
        }
        pub inline fn prepend_one(self: *ListSelf, val: ELEM, alloc: Allocator) void {
            return IMPL.prepend_one(self, val, alloc);
        }
        //**************
        // PREPEND MANY
        //**************
        pub inline fn prepend_many_slots_assume_cap_get_slice(self: *ListSelf, count: IDX) Slice {
            return IMPL.prepend_many_slots_assume_cap_get_slice(self, count);
        }
        pub inline fn prepend_many_slots_with_growth_get_slice(self: *ListSelf, count: IDX, growth: Growth, alloc: Allocator) Slice {
            return IMPL.prepend_many_slots_with_growth_get_slice(self, count, growth, alloc);
        }
        pub inline fn prepend_many_slots_get_slice(self: *ListSelf, count: IDX, alloc: Allocator) Slice {
            return IMPL.prepend_many_slots_get_slice(self, count, alloc);
        }
        pub inline fn prepend_many_slots_assume_cap(self: *ListSelf, count: IDX) void {
            return IMPL.prepend_many_slots_assume_cap(self, count);
        }
        pub inline fn prepend_many_slots_with_growth(self: *ListSelf, count: IDX, growth: Growth, alloc: Allocator) void {
            return IMPL.prepend_many_slots_with_growth(self, count, growth, alloc);
        }
        pub inline fn prepend_many_slots(self: *ListSelf, count: IDX, alloc: Allocator) void {
            return IMPL.prepend_many_slots(self, count, alloc);
        }
        pub inline fn prepend_many_assume_cap_get_slice(self: *ListSelf, vals_: anytype) Slice {
            return IMPL.prepend_many_assume_cap_get_slice(self, vals_);
        }
        pub inline fn prepend_many_with_growth_get_slice(self: *ListSelf, vals_: anytype, growth: Growth, alloc: Allocator) Slice {
            return IMPL.prepend_many_with_growth_get_slice(self, vals_, growth, alloc);
        }
        pub inline fn prepend_many_get_slice(self: *ListSelf, vals_: anytype, alloc: Allocator) Slice {
            return IMPL.prepend_many_get_slice(self, vals_, alloc);
        }
        pub inline fn prepend_many_assume_cap(self: *ListSelf, vals_: anytype) void {
            return IMPL.prepend_many_assume_cap(self, vals_);
        }
        pub inline fn prepend_many_with_growth(self: *ListSelf, vals_: anytype, growth: Growth, alloc: Allocator) void {
            return IMPL.prepend_many_with_growth(self, vals_, growth, alloc);
        }
        pub inline fn prepend_many(self: *ListSelf, vals_: anytype, alloc: Allocator) void {
            return IMPL.prepend_many(self, vals_, alloc);
        }
        //**************
        // INSERT ONE
        //**************
        pub inline fn insert_one_slot_assume_cap_get_ptr(self: *ListSelf, idx: IDX) ElemPtr {
            return IMPL.insert_one_slot_assume_cap_get_ptr(self, idx);
        }
        pub inline fn insert_one_slot_with_growth_get_ptr(self: *ListSelf, idx: IDX, growth: Growth, alloc: Allocator) ElemPtr {
            return IMPL.insert_one_slot_with_growth_get_ptr(self, idx, growth, alloc);
        }
        pub inline fn insert_one_slot_get_ptr(self: *ListSelf, idx: IDX, alloc: Allocator) ElemPtr {
            return IMPL.insert_one_slot_get_ptr(self, idx, alloc);
        }
        pub inline fn insert_one_slot_assume_cap(self: *ListSelf, idx: IDX) void {
            return IMPL.insert_one_slot_assume_cap(self, idx);
        }
        pub inline fn insert_one_slot_with_growth(self: *ListSelf, idx: IDX, growth: Growth, alloc: Allocator) void {
            return IMPL.insert_one_slot_with_growth(self, idx, growth, alloc);
        }
        pub inline fn insert_one_slot(self: *ListSelf, idx: IDX, alloc: Allocator) void {
            return IMPL.insert_one_slot(self, idx, alloc);
        }
        pub inline fn insert_one_assume_cap_get_ptr(self: *ListSelf, idx: IDX, val: ELEM) ElemPtr {
            return IMPL.insert_one_assume_cap_get_ptr(self, idx, val);
        }
        pub inline fn insert_one_with_growth_get_ptr(self: *ListSelf, idx: IDX, val: ELEM, growth: Growth, alloc: Allocator) ElemPtr {
            return IMPL.insert_one_with_growth_get_ptr(self, idx, val, growth, alloc);
        }
        pub inline fn insert_one_get_ptr(self: *ListSelf, idx: IDX, val: ELEM, alloc: Allocator) ElemPtr {
            return IMPL.insert_one_get_ptr(self, idx, val, alloc);
        }
        pub inline fn insert_one_assume_cap(self: *ListSelf, idx: IDX, val: ELEM) void {
            return IMPL.insert_one_assume_cap(self, idx, val);
        }
        pub inline fn insert_one_with_growth(self: *ListSelf, idx: IDX, val: ELEM, growth: Growth, alloc: Allocator) void {
            return IMPL.insert_one_with_growth(self, idx, val, growth, alloc);
        }
        pub inline fn insert_one(self: *ListSelf, idx: IDX, val: ELEM, alloc: Allocator) void {
            return IMPL.insert_one(self, idx, val, alloc);
        }
        //**************
        // INSERT MANY
        //**************
        pub inline fn insert_many_slots_assume_cap_get_slice(self: *ListSelf, idx: IDX, count: IDX) Slice {
            return IMPL.insert_many_slots_assume_cap_get_slice(self, idx, count);
        }
        pub inline fn insert_many_slots_with_growth_get_slice(self: *ListSelf, idx: IDX, count: IDX, growth: Growth, alloc: Allocator) Slice {
            return IMPL.insert_many_slots_with_growth_get_slice(self, idx, count, growth, alloc);
        }
        pub inline fn insert_many_slots_get_slice(self: *ListSelf, idx: IDX, count: IDX, alloc: Allocator) Slice {
            return IMPL.insert_many_slots_get_slice(self, idx, count, alloc);
        }
        pub inline fn insert_many_slots_assume_cap(self: *ListSelf, idx: IDX, count: IDX) void {
            return IMPL.insert_many_slots_assume_cap(self, idx, count);
        }
        pub inline fn insert_many_slots_with_growth(self: *ListSelf, idx: IDX, count: IDX, growth: Growth, alloc: Allocator) void {
            return IMPL.insert_many_slots_with_growth(self, idx, count, growth, alloc);
        }
        pub inline fn insert_many_slots(self: *ListSelf, idx: IDX, count: IDX, alloc: Allocator) void {
            return IMPL.insert_many_slots(self, idx, count, alloc);
        }
        pub inline fn insert_many_assume_cap_get_ptr(self: *ListSelf, idx: IDX, vals_: anytype) Slice {
            return IMPL.insert_many_assume_cap_get_ptr(self, idx, vals_);
        }
        pub inline fn insert_many_with_growth_get_ptr(self: *ListSelf, idx: IDX, vals_: anytype, growth: Growth, alloc: Allocator) Slice {
            return IMPL.insert_many_with_growth_get_ptr(self, idx, vals_, growth, alloc);
        }
        pub inline fn insert_many_get_ptr(self: *ListSelf, idx: IDX, vals_: anytype, alloc: Allocator) Slice {
            return IMPL.insert_many_get_ptr(self, idx, vals_, alloc);
        }
        pub inline fn insert_many_assume_cap(self: *ListSelf, idx: IDX, vals_: anytype) void {
            return IMPL.insert_many_assume_cap(self, idx, vals_);
        }
        pub inline fn insert_many_with_growth(self: *ListSelf, idx: IDX, vals_: anytype, growth: Growth, alloc: Allocator) void {
            return IMPL.insert_many_with_growth(self, idx, vals_, growth, alloc);
        }
        pub inline fn insert_many(self: *ListSelf, idx: IDX, vals_: anytype, alloc: Allocator) void {
            return IMPL.insert_many(self, idx, vals_, alloc);
        }
        //**************
        // DELETE ONE
        //**************
        pub inline fn delete_one(self: *ListSelf, idx: IDX) void {
            return IMPL.delete_one(self, idx);
        }
        pub inline fn remove_one(self: *ListSelf, idx: IDX) ELEM {
            return IMPL.remove_one(self, idx);
        }
        pub inline fn swap_delete_one(self: *ListSelf, idx: IDX) void {
            return IMPL.swap_delete_one(self, idx);
        }
        pub inline fn swap_remove_one(self: *ListSelf, idx: IDX) ELEM {
            return IMPL.swap_remove_one(self, idx);
        }
        pub inline fn pop(self: *ListSelf) ELEM {
            return IMPL.pop(self);
        }
        pub inline fn try_pop(self: *ListSelf) ?ELEM {
            return IMPL.try_pop(self);
        }
        //**************
        // DELETE MANY
        //**************
        pub inline fn delete_range(self: *ListSelf, start_idx: IDX, end_idx_exclusive: IDX) void {
            return IMPL.delete_range(self, start_idx, end_idx_exclusive);
        }
        pub inline fn delete_count(self: *ListSelf, start_idx: IDX, count: IDX) void {
            return IMPL.delete_count(self, start_idx, count);
        }
        /// Remove range of elements from this list into destination list
        ///
        /// Elements overwrite beginning of destination list/slice
        pub inline fn remove_range(self: *ListSelf, start_idx: IDX, end_idx_exclusive: IDX, dest: anytype) void {
            return IMPL.remove_range(self, start_idx, end_idx_exclusive, dest);
        }
        /// Remove range of elements from this list into destination list
        ///
        /// Elements overwrite beginning of destination list/slice
        pub inline fn remove_count(self: *ListSelf, start_idx: IDX, count: IDX, dest: anytype) void {
            return IMPL.remove_count(self, start_idx, count, dest);
        }
        pub inline fn swap_delete_range(self: *ListSelf, start_idx: IDX, end_idx_exclusive: IDX) void {
            return IMPL.swap_delete_range(self, start_idx, end_idx_exclusive);
        }
        pub inline fn swap_delete_count(self: *ListSelf, start_idx: IDX, count: IDX) void {
            return IMPL.swap_delete_count(self, start_idx, count);
        }
        /// Remove range of elements from this list into destination list
        ///
        /// Elements overwrite beginning of destination list/slice
        pub inline fn swap_remove_range(self: *ListSelf, start_idx: IDX, end_idx_exclusive: IDX, dest: anytype) void {
            return IMPL.swap_remove_range(self, start_idx, end_idx_exclusive, dest);
        }
        /// Remove range of elements from this list into destination list
        ///
        /// Elements overwrite beginning of destination list/slice
        pub inline fn swap_remove_count(self: *ListSelf, start_idx: IDX, count: IDX, dest: anytype) void {
            return IMPL.swap_remove_count(self, start_idx, count, dest);
        }
        //*****************
        // DELETE FILTERED
        //*****************
        pub inline fn delete_range_filtered(
            self: *ListSelf,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.delete_range_filtered(self, start_idx, end_idx_exclusive, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_delete_range_filtered(
            self: *ListSelf,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.swap_delete_range_filtered(self, start_idx, end_idx_exclusive, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn remove_range_filtered_assume_dest_cap(
            self: *ListSelf,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            dest: anytype,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.remove_range_filtered_assume_dest_cap(self, start_idx, end_idx_exclusive, dest, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_remove_range_filtered_assume_dest_cap(
            self: *ListSelf,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            dest: anytype,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.swap_remove_range_filtered_assume_dest_cap(self, start_idx, end_idx_exclusive, dest, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn remove_range_filtered(
            self: *ListSelf,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            dest: anytype,
            dest_alloc: Allocator,
            dest_growth: Growth,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.remove_range_filtered(self, start_idx, end_idx_exclusive, dest, dest_alloc, dest_growth, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_remove_range_filtered(
            self: *ListSelf,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            dest: anytype,
            dest_alloc: Allocator,
            dest_growth: Growth,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.swap_remove_range_filtered(self, start_idx, end_idx_exclusive, dest, dest_alloc, dest_growth, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn delete_filtered(
            self: *ListSelf,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.delete_filtered(self, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_delete_filtered(
            self: *ListSelf,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.swap_delete_filtered(self, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn remove_filtered_assume_dest_cap(
            self: *ListSelf,
            dest: anytype,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.remove_filtered_assume_dest_cap(self, dest, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_remove_filtered_assume_dest_cap(
            self: *ListSelf,
            dest: anytype,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.swap_remove_filtered_assume_dest_cap(self, dest, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn remove_filtered(
            self: *ListSelf,
            dest: anytype,
            dest_alloc: Allocator,
            dest_growth: Growth,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.remove_filtered(self, dest, dest_alloc, dest_growth, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_remove_filtered(
            self: *ListSelf,
            dest: anytype,
            dest_alloc: Allocator,
            dest_growth: Growth,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
            comptime FILTER: FilterFnCT(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX), null),
        ) IDX {
            return IMPL.swap_remove_filtered(self, dest, dest_alloc, dest_growth, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        //*****************
        // ROOT FLAT TREE
        //*****************
        /// Elements MUST be laid out in a 'n-ary flat array tree',
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub inline fn root_tree__parent_idx_unchecked(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) IDX {
            return IMPL.root_tree__parent_idx_unchecked(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub inline fn root_tree__parent_idx_if_exists(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return IMPL.root_tree__parent_idx_if_exists(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub inline fn root_tree__nth_child_idx_unchecked(self: ListSelf, idx: IDX, max_num_children_per_element: IDX, nth_child: IDX) IDX {
            return IMPL.root_tree__nth_child_idx_unchecked(self, idx, max_num_children_per_element, nth_child);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub inline fn root_tree__nth_child_idx_if_exists(self: ListSelf, idx: IDX, max_num_children_per_element: IDX, nth_child: IDX) ?IDX {
            return IMPL.root_tree__nth_child_idx_if_exists(self, idx, max_num_children_per_element, nth_child);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub inline fn root_tree__first_child_idx_unchecked(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) IDX {
            return IMPL.root_tree__first_child_idx_unchecked(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub inline fn root_tree__first_child_idx_if_exists(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return IMPL.root_tree__first_child_idx_if_exists(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub inline fn root_tree__last_child_idx_unchecked(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) IDX {
            return IMPL.root_tree__last_child_idx_unchecked(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub inline fn root_tree__last_child_idx_if_exists(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return IMPL.root_tree__last_child_idx_if_exists(self, idx, max_num_children_per_element);
        }
        //*****************
        // LOCAL FLAT TREE
        //*****************
        /// Elements MUST be laid out in a 'n-ary flat array tree',
        /// starting at the start of the slice
        pub inline fn local_tree__parent_idx_unchecked(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) IDX {
            return IMPL.local_tree__parent_idx_unchecked(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub inline fn local_tree__parent_idx_if_exists(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return IMPL.local_tree__parent_idx_if_exists(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub inline fn local_tree__nth_child_idx_unchecked(self: ListSelf, idx: IDX, max_num_children_per_element: IDX, nth_child: IDX) IDX {
            return IMPL.local_tree__nth_child_idx_unchecked(self, idx, max_num_children_per_element, nth_child);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub inline fn local_tree__nth_child_idx_if_exists(self: ListSelf, idx: IDX, max_num_children_per_element: IDX, nth_child: IDX) ?IDX {
            return IMPL.local_tree__nth_child_idx_if_exists(self, idx, max_num_children_per_element, nth_child);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub inline fn local_tree__first_child_idx_unchecked(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) IDX {
            return IMPL.local_tree__first_child_idx_unchecked(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub inline fn local_tree__first_child_idx_if_exists(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return IMPL.local_tree__first_child_idx_if_exists(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub inline fn local_tree__last_child_idx_unchecked(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) IDX {
            return IMPL.local_tree__last_child_idx_unchecked(self, idx, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub inline fn local_tree__last_child_idx_if_exists(self: ListSelf, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return IMPL.local_tree__last_child_idx_if_exists(self, idx, max_num_children_per_element);
        }
        //*****************
        // FIND/BIN SEARCH
        //*****************
        pub inline fn find_advanced(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            comptime MODE: FindOneMode,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_FN_KIND: FuncParamType,
            equal_idx_val: CompareIdxIdxFnRT(COMPARE_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL: CompareIdxIdxFnCT(COMPARE_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) ?IDX {
            return IMPL.find_advanced(self, val, start, end_excluded, MODE, compare_ctx, COMPARE_CTX, COMPARE_FN_KIND, equal_idx_val, EQUAL_IDX_VAL);
        }

        pub inline fn find_first_in_range(self: ListSelf, val: ELEM, start: IDX, end_excluded: IDX, equal_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool) ?IDX {
            return IMPL.find_first_in_range(self, val, start, end_excluded, equal_idx_val);
        }
        pub inline fn find_first_in_range_implicit(self: ListSelf, val: ELEM, start: IDX, end_excluded: IDX) ?IDX {
            return IMPL.find_first_in_range_implicit(self, val, start, end_excluded);
        }
        pub inline fn find_first(self: ListSelf, val: ELEM, equal_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool) ?IDX {
            return IMPL.find_first(self, val, equal_idx_val);
        }
        pub inline fn find_first_implicit(self: ListSelf, val: ELEM) ?IDX {
            return IMPL.find_first_implicit(self, val);
        }
        pub inline fn find_last_in_range(self: ListSelf, val: ELEM, start: IDX, end_excluded: IDX, equal_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool) ?IDX {
            return IMPL.find_last_in_range(self, val, start, end_excluded, equal_idx_val);
        }
        pub inline fn find_last_in_range_implicit(self: ListSelf, val: ELEM, start: IDX, end_excluded: IDX) ?IDX {
            return IMPL.find_last_in_range_implicit(self, val, start, end_excluded);
        }
        pub inline fn find_last(self: ListSelf, val: ELEM, equal_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool) ?IDX {
            return IMPL.find_last(self, val, equal_idx_val);
        }
        pub inline fn find_last_implicit(self: ListSelf, val: ELEM) ?IDX {
            return IMPL.find_last_implicit(self, val);
        }

        pub inline fn binary_search_advanced(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime EQUAL_FN_KIND: FuncParamType,
            equal_idx_val: CompareIdxValFnRT(EQUAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL: CompareIdxValFnCT(EQUAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_FN_KIND: FuncParamType,
            greater_idx_val: CompareIdxValFnRT(GREATER_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_VAL: CompareIdxValFnCT(GREATER_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) ?IDX {
            return IMPL.binary_search_advanced(self, val, start, end_excluded, compare_ctx, COMPARE_CTX, EQUAL_FN_KIND, equal_idx_val, EQUAL_IDX_VAL, GREATER_FN_KIND, greater_idx_val, GREATER_IDX_VAL);
        }

        pub inline fn binary_search_range(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            equal_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
            greater_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) ?IDX {
            return IMPL.binary_search_range(self, val, start, end_excluded, equal_idx_val, greater_idx_val);
        }
        pub inline fn binary_search(
            self: ListSelf,
            val: ELEM,
            equal_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
            greater_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) ?IDX {
            return IMPL.binary_search(self, val, equal_idx_val, greater_idx_val);
        }
        pub inline fn binary_search_range_implicit(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
        ) ?IDX {
            return IMPL.binary_search_range_implicit(self, val, start, end_excluded);
        }
        pub inline fn binary_search_implicit(self: ListSelf, val: ELEM) ?IDX {
            return IMPL.binary_search_implicit(self, val);
        }

        pub inline fn binary_insert_location_advanced_right_bias(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime GREATER_FN_KIND: FuncParamType,
            greater_idx_val: CompareIdxValFnRT(GREATER_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_VAL: CompareIdxValFnCT(GREATER_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) IDX {
            return IMPL.binary_insert_location_advanced_right_bias(self, val, start, end_excluded, compare_ctx, COMPARE_CTX, GREATER_FN_KIND, greater_idx_val, GREATER_IDX_VAL);
        }
        pub inline fn binary_insert_location_advanced_left_bias(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime LESS_THAN_FN_KIND: FuncParamType,
            less_than_idx_val: CompareIdxValFnRT(LESS_THAN_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime LESS_THAN_IDX_VAL: CompareIdxValFnCT(LESS_THAN_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) IDX {
            return IMPL.binary_insert_location_advanced_left_bias(self, val, start, end_excluded, compare_ctx, COMPARE_CTX, LESS_THAN_FN_KIND, less_than_idx_val, LESS_THAN_IDX_VAL);
        }
        pub inline fn binary_insert_location_in_range(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            greater_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) IDX {
            return IMPL.binary_insert_location_in_range(self, val, start, end_excluded, greater_idx_val);
        }
        pub inline fn binary_insert_location(
            self: ListSelf,
            val: ELEM,
            greater_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) IDX {
            return IMPL.binary_insert_location(self, val, greater_idx_val);
        }
        pub inline fn binary_insert_location_in_range_implicit(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
        ) IDX {
            return IMPL.binary_insert_location_in_range_implicit(self, val, start, end_excluded);
        }
        pub inline fn binary_insert_location_implicit(
            self: ListSelf,
            val: ELEM,
        ) IDX {
            return IMPL.binary_insert_location_implicit(self, val);
        }
        pub inline fn binary_insert_advanced_right_bias(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            alloc: Allocator,
            growth: GrowthMode,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime GREATER_FN_KIND: FuncParamType,
            greater_idx_val: CompareIdxValFnRT(GREATER_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_VAL: CompareIdxValFnCT(GREATER_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) IDX {
            return IMPL.binary_insert_advanced_right_bias(self, val, start, end_excluded, alloc, growth, compare_ctx, COMPARE_CTX, GREATER_FN_KIND, greater_idx_val, GREATER_IDX_VAL);
        }
        pub inline fn binary_insert_advanced_left_bias(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            alloc: Allocator,
            growth: GrowthMode,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime LESS_THAN_FN_KIND: FuncParamType,
            less_than_idx_val: CompareIdxValFnRT(LESS_THAN_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime LESS_THAN_IDX_VAL: CompareIdxValFnCT(LESS_THAN_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) IDX {
            return IMPL.binary_insert_advanced_left_bias(self, val, start, end_excluded, alloc, growth, compare_ctx, COMPARE_CTX, LESS_THAN_FN_KIND, less_than_idx_val, LESS_THAN_IDX_VAL);
        }
        pub inline fn binary_insert_in_range(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            alloc: Allocator,
            greater_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) IDX {
            return IMPL.binary_insert_in_range(self, val, start, end_excluded, alloc, greater_idx_val);
        }
        pub inline fn binary_insert(
            self: ListSelf,
            val: ELEM,
            alloc: Allocator,
            greater_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) IDX {
            return IMPL.binary_insert(self, val, alloc, greater_idx_val);
        }
        pub inline fn binary_insert_in_range_implicit(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            alloc: Allocator,
        ) IDX {
            return IMPL.binary_insert_in_range_implicit(self, val, start, end_excluded, alloc);
        }
        pub inline fn binary_insert_implicit(
            self: ListSelf,
            val: ELEM,
            alloc: Allocator,
        ) IDX {
            return IMPL.binary_insert_implicit(self, val, alloc);
        }
        pub inline fn binary_insert_in_range_assume_cap(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
            greater_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) IDX {
            return IMPL.binary_insert_in_range_assume_cap(self, val, start, end_excluded, greater_idx_val);
        }
        pub inline fn binary_insert_assume_cap(
            self: ListSelf,
            val: ELEM,
            greater_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) IDX {
            return IMPL.binary_insert_assume_cap(self, val, greater_idx_val);
        }
        pub inline fn binary_insert_in_range_implicit_assume_cap(
            self: ListSelf,
            val: ELEM,
            start: IDX,
            end_excluded: IDX,
        ) IDX {
            return IMPL.binary_insert_in_range_implicit_assume_cap(self, val, start, end_excluded);
        }
        pub inline fn binary_insert_implicit_assume_cap(
            self: ListSelf,
            val: ELEM,
        ) IDX {
            return IMPL.binary_insert_implicit_assume_cap(self, val);
        }

        //*****************
        // SORTING
        //*****************

        pub inline fn median_index_of_3_advanced(
            self: ListSelf,
            idxs: [3]IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRT(COMPARE_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCT(COMPARE_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) IDX {
            return IMPL.median_index_of_3_advanced(self, idxs, compare_ctx, COMPARE_CTX, COMPARE_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX);
        }
        pub inline fn median_index_of_3(self: ListSelf, idxs: [3]IDX, greater_than_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool) IDX {
            return IMPL.median_index_of_3(self, idxs, greater_than_idx_idx);
        }

        pub inline fn heap_sift_down_within_range_avanced(
            self: ListSelf,
            heap_first_idx: IDX,
            heap_len: IDX,
            idx: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.heap_sift_down_within_range_avanced(self, heap_first_idx, heap_len, idx, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL);
        }
        pub inline fn heap_sift_down_avanced(
            self: ListSelf,
            idx: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.heap_sift_down_avanced(self, idx, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL);
        }
        pub inline fn heap_sift_down_within_range(
            self: ListSelf,
            heap_first_idx: IDX,
            heap_len: IDX,
            idx: IDX,
            higher_in_heap_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
            higher_in_heap_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) void {
            return IMPL.heap_sift_down_within_range(self, heap_first_idx, heap_len, idx, higher_in_heap_idx_idx, higher_in_heap_idx_val);
        }
        pub inline fn heap_sift_down(
            self: ListSelf,
            idx: IDX,
            higher_in_heap_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
            higher_in_heap_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) void {
            return IMPL.heap_sift_down(self, idx, higher_in_heap_idx_idx, higher_in_heap_idx_val);
        }
        // TODO more heap operations

        pub inline fn build_heap_within_range_advanced(
            self: ListSelf,
            start: IDX,
            end_excluded: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.build_heap_within_range_advanced(self, start, end_excluded, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL);
        }

        pub inline fn build_heap_advanced(
            self: ListSelf,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.build_heap_advanced(self, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL);
        }

        pub inline fn build_heap_within_range(
            self: ListSelf,
            start: IDX,
            end_excluded: IDX,
            higher_in_heap_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
            higher_in_heap_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) void {
            return IMPL.build_heap_within_range(self, start, end_excluded, higher_in_heap_idx_idx, higher_in_heap_idx_val);
        }

        pub inline fn build_heap(
            self: ListSelf,
            higher_in_heap_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
            higher_in_heap_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) void {
            return IMPL.build_heap(self, higher_in_heap_idx_idx, higher_in_heap_idx_val);
        }

        pub inline fn is_range_a_valid_heap_advanced(
            self: ListSelf,
            heap_first_idx: IDX,
            heap_last_idx_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) bool {
            return IMPL.is_range_a_valid_heap_advanced(self, heap_first_idx, heap_last_idx_exclusive, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX);
        }
        pub inline fn is_a_valid_heap_advanced(
            self: ListSelf,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) bool {
            return IMPL.is_a_valid_heap_advanced(self, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX);
        }
        pub inline fn is_range_a_valid_heap(
            self: ListSelf,
            heap_first_idx: IDX,
            heap_last_idx_exclusive: IDX,
            greater_than_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
        ) bool {
            return IMPL.is_range_a_valid_heap(self, heap_first_idx, heap_last_idx_exclusive, greater_than_idx_idx);
        }
        pub inline fn is_a_valid_heap(
            self: ListSelf,
            greater_than_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
        ) bool {
            return IMPL.is_a_valid_heap(self, greater_than_idx_idx);
        }

        pub inline fn is_range_sorted_advanced(
            self: ListSelf,
            start: IDX,
            end_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime GREATER_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRT(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCT(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) bool {
            return IMPL.is_range_sorted_advanced(self, start, end_exclusive, compare_ctx, COMPARE_CTX, GREATER_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX);
        }

        pub inline fn is_sorted_advanced(
            self: ListSelf,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime GREATER_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRT(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCT(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) bool {
            return IMPL.is_sorted_advanced(self, compare_ctx, COMPARE_CTX, GREATER_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX);
        }

        pub inline fn is_sorted(self: ListSelf, greater_than_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool) bool {
            return IMPL.is_sorted(self, greater_than_idx_idx);
        }

        pub inline fn is_range_sorted(self: ListSelf, start: IDX, end_exclusive: IDX, greater_than_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool) bool {
            return IMPL.is_range_sorted(self, start, end_exclusive, greater_than_idx_idx);
        }

        /// Builds a max-heap out of the given data range using the provided 'greater-than' comparisons,
        /// then iteratively removes the max value from the heap, and re-heapifies the remaining elements
        ///
        /// Stable:
        ///   - NO
        ///
        /// Cache Locality:
        ///   - Poor
        ///
        /// Initialization Overhead:
        ///   - Medium
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Always = O(n log n)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn heapsort_range_advanced(
            self: ListSelf,
            start: IDX,
            end_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.heapsort_range_advanced(self, start, end_exclusive, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL);
        }

        /// Builds a max-heap from the entire data slice using the provided 'greater-than' comparisons,
        /// then iteratively removes the max value from the heap, and re-heapifies the remaining elements
        ///
        /// Stable:
        ///   - NO
        ///
        /// Cache Locality:
        ///   - Poor
        ///
        /// Initialization Overhead:
        ///   - Medium
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Always = O(n log n)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn heapsort_advanced(
            self: ListSelf,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCT(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.heapsort_advanced(self, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL);
        }
        /// Builds a max-heap out of the given data range using the provided 'greater-than' comparisons,
        /// then iteratively removes the max value from the heap, and re-heapifies the remaining elements
        ///
        /// Stable:
        ///   - NO
        ///
        /// Cache Locality:
        ///   - Poor
        ///
        /// Initialization Overhead:
        ///   - Medium
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Always = O(n log n)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn heapsort_range(
            self: ListSelf,
            start: IDX,
            end_exclusive: IDX,
            greater_than_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
            greater_than_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) void {
            return IMPL.heapsort_range(self, start, end_exclusive, greater_than_idx_idx, greater_than_idx_val);
        }
        /// Builds a max-heap out of the given data range using the provided 'greater-than' comparisons,
        /// then iteratively removes the max value from the heap, and re-heapifies the remaining elements
        ///
        /// Stable:
        ///   - NO
        ///
        /// Cache Locality:
        ///   - Poor
        ///
        /// Initialization Overhead:
        ///   - Medium
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Always = O(n log n)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn heapsort_range_implicit(
            self: ListSelf,
            start: IDX,
            end_exclusive: IDX,
        ) void {
            return IMPL.heapsort_range_implicit(self, start, end_exclusive);
        }

        /// Builds a max-heap from the entire data slice using the provided 'greater-than' comparisons,
        /// then iteratively removes the max value from the heap, and re-heapifies the remaining elements
        ///
        /// Stable:
        ///   - NO
        ///
        /// Cache Locality:
        ///   - Poor
        ///
        /// Initialization Overhead:
        ///   - Medium
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Always = O(n log n)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn heapsort(
            self: ListSelf,
            greater_than_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
            greater_than_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) void {
            return IMPL.heapsort(self, greater_than_idx_idx, greater_than_idx_val);
        }
        /// Builds a max-heap from the entire data slice using the provided 'greater-than' comparisons,
        /// then iteratively removes the max value from the heap, and re-heapifies the remaining elements
        ///
        /// Stable:
        ///   - NO
        ///
        /// Cache Locality:
        ///   - Poor
        ///
        /// Initialization Overhead:
        ///   - Medium
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Always = O(n log n)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn heapsort_implicit(
            self: ListSelf,
        ) void {
            return IMPL.heapsort_implicit(self);
        }

        /// Filters smaller ordered items down until they find an index where they would be
        /// in the correct order. Simple, stable, and very fast for fully-sorted or nearly-sorted lists, and for small
        /// lists.
        ///
        /// Stable:
        ///   - YES
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - None
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n) (already sorted)
        ///   - Average = O(n^2)
        ///   - Worst   = O(n^2)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn insertion_sort_range_advanced(
            self: ListSelf,
            start: IDX,
            end_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.insertion_sort_range_advanced(self, start, end_exclusive, compare_ctx, COMPARE_CTX, COMPARE_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL);
        }

        /// Filters smaller ordered items down until they find an index where they would be
        /// in the correct order. Simple, stable, and very fast for fully-sorted or nearly-sorted lists, and for small
        /// lists.
        ///
        /// Stable:
        ///   - YES
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - None
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n) (already sorted)
        ///   - Average = O(n^2)
        ///   - Worst   = O(n^2)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn insertion_sort_advanced(
            self: ListSelf,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCT(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.insertion_sort_advanced(self, compare_ctx, COMPARE_CTX, COMPARE_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL);
        }

        /// Filters smaller ordered items down until they find an index where they would be
        /// in the correct order. Simple, stable, and very fast for fully-sorted or nearly-sorted lists, and for small
        /// lists.
        ///
        /// Stable:
        ///   - YES
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - None
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n) (already sorted)
        ///   - Average = O(n^2)
        ///   - Worst   = O(n^2)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn insertion_sort_range(self: ListSelf, start: IDX, end_exclusive: IDX, greater_than_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool) void {
            return IMPL.insertion_sort_range(self, start, end_exclusive, greater_than_idx_val);
        }
        /// Filters smaller ordered items down until they find an index where they would be
        /// in the correct order. Simple, stable, and very fast for fully-sorted or nearly-sorted lists, and for small
        /// lists.
        ///
        /// Stable:
        ///   - YES
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - None
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n) (already sorted)
        ///   - Average = O(n^2)
        ///   - Worst   = O(n^2)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn insertion_sort_range_implicit(self: ListSelf, start: IDX, end_exclusive: IDX) void {
            return IMPL.insertion_sort_range_implicit(self, start, end_exclusive);
        }

        /// Filters smaller ordered items down until they find an index where they would be
        /// in the correct order. Simple, stable, and very fast for fully-sorted or nearly-sorted lists, and for small
        /// lists.
        ///
        /// Stable:
        ///   - YES
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - None
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n) (already sorted)
        ///   - Average = O(n^2)
        ///   - Worst   = O(n^2)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn insertion_sort(self: ListSelf, greater_than_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool) void {
            return IMPL.insertion_sort(self, greater_than_idx_val);
        }
        /// Filters smaller ordered items down until they find an index where they would be
        /// in the correct order. Simple, stable, and very fast for fully-sorted or nearly-sorted lists, and for small
        /// lists.
        ///
        /// Stable:
        ///   - YES
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - None
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n) (already sorted)
        ///   - Average = O(n^2)
        ///   - Worst   = O(n^2)
        ///
        /// Space:
        ///   - O(1)
        pub inline fn insertion_sort_implicit(self: ListSelf) void {
            return IMPL.insertion_sort_implicit(self);
        }

        pub inline fn QuicksortPartition(comptime DEGENERATE_FALLBACK: bool) type {
            return IMPL.QuicksortPartition(DEGENERATE_FALLBACK);
        }

        /// Quicksort using a number of optimizations (similar to Introsort):
        ///   - Use Insertion Sort when partitions become small
        ///   - Median-of-three pivot (not random, always first, middle, last)
        ///   - User can choose a partition scheme based on stated expectations about items with equal order
        ///     - Unknown likelyhood of equal order items = Start with 2-way, but if many duplicates are detected change to 3-way
        ///     - Many items same order unlikely = 2-way Hoare scheme
        ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
        ///   - No recursion, only a comptime sized stack of partition index ranges and a while loop
        ///   - (Optional) Fallback to Heapsort/Insertion sort if partition degeneracy detected (more than N x the average partition depth)
        ///
        /// Stable:
        ///   - No
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - Low
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n log n)
        ///   - Average = O(n log n)
        ///   - Worst:
        ///     - With fallback enabled = (heapsort init overhead) + O(n log n)
        ///     - No fallback enabled   = O(n^2) (fully/nearly sorted or adversarial input)
        ///
        /// Space:
        ///   - O(log n) (implemented as a stack-allocated array)
        pub inline fn quicksort_range_advanced(
            self: ListSelf,
            start: IDX,
            end_excluded: IDX,
            comptime SETTINGS: QuicksortSettings,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime LESSER_IDX_VAL_FN_KIND: FuncParamType,
            less_than_idx_val: CompareIdxValFnRT(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime LESS_THAN_IDX_VAL: CompareIdxValFnCT(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRT(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCT(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRT(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCT(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL_FN_KIND: FuncParamType,
            equal_idx_val: CompareIdxValFnRT(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL: CompareIdxValFnCT(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.quicksort_range_advanced(self, start, end_excluded, SETTINGS, compare_ctx, COMPARE_CTX, LESSER_IDX_VAL_FN_KIND, less_than_idx_val, LESS_THAN_IDX_VAL, GREATER_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX, GREATER_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL, EQUAL_IDX_VAL_FN_KIND, equal_idx_val, EQUAL_IDX_VAL);
        }
        /// Quicksort using a number of optimizations (similar to Introsort):
        ///   - Use Insertion Sort when partitions become small
        ///   - Median-of-three pivot (not random, always first, middle, last)
        ///   - User can choose a partition scheme based on stated expectations about items with equal order
        ///     - Unknown likelyhood of equal order items = Start with 2-way, but if many duplicates are detected change to 3-way
        ///     - Many items same order unlikely = 2-way Hoare scheme
        ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
        ///   - No recursion, only a comptime sized stack of partition index ranges and a while loop
        ///   - (Optional) Fallback to Heapsort/Insertion sort if partition degeneracy detected (more than N x the average partition depth)
        ///
        /// Stable:
        ///   - No
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - Low
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n log n)
        ///   - Average = O(n log n)
        ///   - Worst:
        ///     - With fallback enabled = (heapsort init overhead) + O(n log n)
        ///     - No fallback enabled   = O(n^2) (fully/nearly sorted or adversarial input)
        ///
        /// Space:
        ///   - O(log n) (implemented as a stack-allocated array)
        pub inline fn quicksort_advanced(
            self: ListSelf,
            start: IDX,
            end_excluded: IDX,
            comptime SETTINGS: QuicksortSettings,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime LESSER_IDX_VAL_FN_KIND: FuncParamType,
            less_than_idx_val: CompareIdxValFnRT(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime LESS_THAN_IDX_VAL: CompareIdxValFnCT(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRT(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCT(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRT(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCT(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL_FN_KIND: FuncParamType,
            equal_idx_val: CompareIdxValFnRT(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL: CompareIdxValFnCT(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            return IMPL.quicksort_advanced(self, start, end_excluded, SETTINGS, compare_ctx, COMPARE_CTX, LESSER_IDX_VAL_FN_KIND, less_than_idx_val, LESS_THAN_IDX_VAL, GREATER_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX, GREATER_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL, EQUAL_IDX_VAL_FN_KIND, equal_idx_val, EQUAL_IDX_VAL);
        }
        /// Quicksort using a number of optimizations (similar to Introsort):
        ///   - Use Insertion Sort when partitions become small
        ///   - Median-of-three pivot (not random, always first, middle, last)
        ///   - User can choose a partition scheme based on stated expectations about items with equal order
        ///     - Unknown likelyhood of equal order items = Start with 2-way, but if many duplicates are detected change to 3-way
        ///     - Many items same order unlikely = 2-way Hoare scheme
        ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
        ///   - No recursion, only a comptime sized stack of partition index ranges and a while loop
        ///   - (Optional) Fallback to Heapsort/Insertion sort if partition degeneracy detected (more than N x the average partition depth)
        ///
        /// Stable:
        ///   - No
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - Low
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n log n)
        ///   - Average = O(n log n)
        ///   - Worst:
        ///     - With fallback enabled = (heapsort init overhead) + O(n log n)
        ///     - No fallback enabled   = O(n^2) (fully/nearly sorted or adversarial input)
        ///
        /// Space:
        ///   - O(log n) (implemented as a stack-allocated array)
        pub inline fn quicksort_range(
            self: ListSelf,
            start: IDX,
            end_excluded: IDX,
            less_than_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
            greater_than_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
            greater_than_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
            equal_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) void {
            return IMPL.quicksort_range(self, start, end_excluded, less_than_idx_val, greater_than_idx_idx, greater_than_idx_val, equal_idx_val);
        }
        /// Quicksort using a number of optimizations (similar to Introsort):
        ///   - Use Insertion Sort when partitions become small
        ///   - Median-of-three pivot (not random, always first, middle, last)
        ///   - User can choose a partition scheme based on stated expectations about items with equal order
        ///     - Unknown likelyhood of equal order items = Start with 2-way, but if many duplicates are detected change to 3-way
        ///     - Many items same order unlikely = 2-way Hoare scheme
        ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
        ///   - No recursion, only a comptime sized stack of partition index ranges and a while loop
        ///   - (Optional) Fallback to Heapsort/Insertion sort if partition degeneracy detected (more than N x the average partition depth)
        ///
        /// Stable:
        ///   - No
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - Low
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n log n)
        ///   - Average = O(n log n)
        ///   - Worst:
        ///     - With fallback enabled = (heapsort init overhead) + O(n log n)
        ///     - No fallback enabled   = O(n^2) (fully/nearly sorted or adversarial input)
        ///
        /// Space:
        ///   - O(log n) (implemented as a stack-allocated array)
        pub inline fn quicksort_range_implicit(
            self: ListSelf,
            start: IDX,
            end_excluded: IDX,
        ) void {
            return IMPL.quicksort_range_implicit(self, start, end_excluded);
        }
        /// Quicksort using a number of optimizations (similar to Introsort):
        ///   - Use Insertion Sort when partitions become small
        ///   - Median-of-three pivot (not random, always first, middle, last)
        ///   - User can choose a partition scheme based on stated expectations about items with equal order
        ///     - Unknown likelyhood of equal order items = Start with 2-way, but if many duplicates are detected change to 3-way
        ///     - Many items same order unlikely = 2-way Hoare scheme
        ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
        ///   - No recursion, only a comptime sized stack of partition index ranges and a while loop
        ///   - (Optional) Fallback to Heapsort/Insertion sort if partition degeneracy detected (more than N x the average partition depth)
        ///
        /// Stable:
        ///   - No
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - Low
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n log n)
        ///   - Average = O(n log n)
        ///   - Worst:
        ///     - With fallback enabled = (heapsort init overhead) + O(n log n)
        ///     - No fallback enabled   = O(n^2) (fully/nearly sorted or adversarial input)
        ///
        /// Space:
        ///   - O(log n) (implemented as a stack-allocated array)
        pub inline fn quicksort(
            self: ListSelf,
            less_than_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
            greater_than_idx_idx: *const fn (ListSelf, IDX, IDX, void, void) bool,
            greater_than_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
            equal_idx_val: *const fn (ListSelf, IDX, ELEM, void, void) bool,
        ) void {
            return IMPL.quicksort(self, less_than_idx_val, greater_than_idx_idx, greater_than_idx_val, equal_idx_val);
        }
        /// Quicksort using a number of optimizations (similar to Introsort):
        ///   - Use Insertion Sort when partitions become small
        ///   - Median-of-three pivot (not random, always first, middle, last)
        ///   - User can choose a partition scheme based on stated expectations about items with equal order
        ///     - Unknown likelyhood of equal order items = Start with 2-way, but if many duplicates are detected change to 3-way
        ///     - Many items same order unlikely = 2-way Hoare scheme
        ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
        ///   - No recursion, only a comptime sized stack of partition index ranges and a while loop
        ///   - (Optional) Fallback to Heapsort/Insertion sort if partition degeneracy detected (more than N x the average partition depth)
        ///
        /// Stable:
        ///   - No
        ///
        /// Cache Locality:
        ///   - Great
        ///
        /// Initialization Overhead:
        ///   - Low
        ///
        /// Per-Step Overhead:
        ///   - Low
        ///
        /// Time:
        ///   - Best    = O(n log n)
        ///   - Average = O(n log n)
        ///   - Worst:
        ///     - With fallback enabled = (heapsort init overhead) + O(n log n)
        ///     - No fallback enabled   = O(n^2) (fully/nearly sorted or adversarial input)
        ///
        /// Space:
        ///   - O(log n) (implemented as a stack-allocated array)
        pub inline fn quicksort_implicit(
            self: ListSelf,
        ) void {
            return IMPL.quicksort_implicit(self);
        }

        const CT_IdxFn = IMPL.CT_IdxFn;
        pub inline fn simple_next_idx(comptime RT_CTX: type, comptime CT_CTX: type) CT_IdxFn(RT_CTX, CT_CTX) {
            return IMPL.simple_next_idx(RT_CTX, CT_CTX);
        }
        pub inline fn simple_prev_idx(comptime RT_CTX: type, comptime CT_CTX: type) CT_IdxFn(RT_CTX, CT_CTX) {
            return IMPL.simple_prev_idx(RT_CTX, CT_CTX);
        }

        pub inline fn for_each_complete_advanced(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            action_ctx: anytype,
            comptime ACTION_CTX: anytype,
            comptime NEXT_FN_KIND: FuncParamType,
            next: NextIdxFnRT(NEXT_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX)),
            comptime NEXT: NextIdxFnCT(NEXT_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX)),
            comptime ACTION_ERROR: ?type,
            comptime ACTION_FN_KIND: FuncParamType,
            action: ForEachActionRT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime ACTION: ForEachActionCT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime FILTER_MODE: FilterMode,
            comptime FILTER_ERROR: if (FILTER_MODE == .USE_FILTERING_FUNC) ?type else void,
            comptime FILTER_FN_KIND: if (FILTER_MODE == .USE_FILTERING_FUNC) FuncParamType else void,
            filter: if (FILTER_MODE == .USE_FILTERING_FUNC) FilterFnRT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR) else void,
            comptime FILTER: if (FILTER_MODE == .USE_FILTERING_FUNC) FilterFnCT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR) else void,
        ) ForEachReturn(FILTER_MODE, FILTER_ERROR, ACTION_ERROR) {
            return IMPL.for_each_complete_advanced(self, start, end_excluded, max_count, action_ctx, ACTION_CTX, NEXT_FN_KIND, next, NEXT, ACTION_ERROR, ACTION_FN_KIND, action, ACTION, FILTER_MODE, FILTER_ERROR, FILTER_FN_KIND, filter, FILTER);
        }

        pub inline fn for_each_in_range_filtered_advanced(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            action_ctx: anytype,
            comptime ACTION_CTX: anytype,
            comptime ACTION_ERROR: ?type,
            comptime ACTION_FN_KIND: FuncParamType,
            action: ForEachActionRT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime ACTION: ForEachActionCT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime FILTER_ERROR: ?type,
            comptime FILTER_FN_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR),
            comptime FILTER: FilterFnCT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR),
        ) ForEachReturn(.USE_FILTERING_FUNC, FILTER_ERROR, ACTION_ERROR) {
            return IMPL.for_each_in_range_filtered_advanced(self, start, end_excluded, max_count, action_ctx, ACTION_CTX, ACTION_ERROR, ACTION_FN_KIND, action, ACTION, FILTER_ERROR, FILTER_FN_KIND, filter, FILTER);
        }
        pub inline fn for_each_in_range_filtered(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            action: *const fn (ListSelf, IDX, void, void) void,
            filter: *const fn (ListSelf, IDX, void, void) bool,
        ) ForEachReturn(.USE_FILTERING_FUNC, null, null) {
            return IMPL.for_each_in_range_filtered(self, start, end_excluded, max_count, action, filter);
        }
        pub inline fn for_each_in_range_filtered_with_context(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            context: anytype,
            action: *const fn (ListSelf, IDX, @TypeOf(context), void) void,
            filter: *const fn (ListSelf, IDX, @TypeOf(context), void) bool,
        ) ForEachReturn(.USE_FILTERING_FUNC, null, null) {
            return IMPL.for_each_in_range_filtered_with_context(self, start, end_excluded, max_count, context, action, filter);
        }

        pub inline fn for_each_filtered_advanced(
            self: ListSelf,
            max_count: IDX,
            action_ctx: anytype,
            comptime ACTION_CTX: anytype,
            comptime ACTION_ERROR: ?type,
            comptime ACTION_FN_KIND: FuncParamType,
            action: ForEachActionRT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime ACTION: ForEachActionCT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime FILTER_ERROR: ?type,
            comptime FILTER_FN_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR),
            comptime FILTER: FilterFnCT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR),
        ) ForEachReturn(.USE_FILTERING_FUNC, FILTER_ERROR, ACTION_ERROR) {
            return IMPL.for_each_filtered_advanced(self, max_count, action_ctx, ACTION_CTX, ACTION_ERROR, ACTION_FN_KIND, action, ACTION, FILTER_ERROR, FILTER_FN_KIND, filter, FILTER);
        }

        pub inline fn for_each_filtered(
            self: ListSelf,
            max_count: IDX,
            action: *const fn (ListSelf, IDX, void, void) void,
            filter: *const fn (ListSelf, IDX, void, void) bool,
        ) ForEachReturn(.USE_FILTERING_FUNC, null, null) {
            return IMPL.for_each_filtered(self, max_count, action, filter);
        }
        pub inline fn for_each_filtered_with_context(
            self: ListSelf,
            max_count: IDX,
            context: anytype,
            action: *const fn (ListSelf, IDX, @TypeOf(context), void) void,
            filter: *const fn (ListSelf, IDX, @TypeOf(context), void) bool,
        ) ForEachReturn(.USE_FILTERING_FUNC, null, null) {
            return IMPL.for_each_filtered_with_context(self, max_count, context, action, filter);
        }

        pub inline fn for_each_in_range_advanced(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            action_ctx: anytype,
            comptime ACTION_CTX: anytype,
            comptime ACTION_ERROR: ?type,
            comptime ACTION_FN_KIND: FuncParamType,
            action: ForEachActionRT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime ACTION: ForEachActionCT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
        ) ForEachReturn(.NO_FILTERING, {}, ACTION_ERROR) {
            return IMPL.for_each_in_range_advanced(self, start, end_excluded, max_count, action_ctx, ACTION_CTX, ACTION_ERROR, ACTION_FN_KIND, action, ACTION);
        }
        pub inline fn for_each_in_range(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            action: *const fn (ListSelf, IDX, void, void) void,
        ) ForEachReturn(.NO_FILTERING, {}, null) {
            return IMPL.for_each_in_range(self, start, end_excluded, max_count, action);
        }
        pub inline fn for_each_in_range_with_context(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            context: anytype,
            action: *const fn (ListSelf, IDX, @TypeOf(context), void) void,
        ) ForEachReturn(.NO_FILTERING, {}, null) {
            return IMPL.for_each_in_range_with_context(self, start, end_excluded, max_count, context, action);
        }

        pub inline fn for_each_advanced(
            self: ListSelf,
            max_count: IDX,
            action_ctx: anytype,
            comptime ACTION_CTX: anytype,
            comptime ACTION_ERROR: ?type,
            comptime ACTION_FN_KIND: FuncParamType,
            action: ForEachActionRT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime ACTION: ForEachActionCT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
        ) ForEachReturn(.NO_FILTERING, {}, ACTION_ERROR) {
            return IMPL.for_each_advanced(self, max_count, action_ctx, ACTION_CTX, ACTION_ERROR, ACTION_FN_KIND, action, ACTION);
        }

        pub inline fn for_each(
            self: ListSelf,
            max_count: IDX,
            action: *const fn (ListSelf, IDX, void, void) void,
        ) ForEachReturn(.NO_FILTERING, {}, null) {
            return IMPL.for_each(self, max_count, action);
        }
        pub inline fn for_each_with_context(
            self: ListSelf,
            max_count: IDX,
            context: anytype,
            action: *const fn (ListSelf, IDX, @TypeOf(context), void) void,
        ) ForEachReturn(.NO_FILTERING, {}, null) {
            return IMPL.for_each_with_context(self, max_count, context, action);
        }
        pub inline fn for_each_in_range_filtered_reverse_advanced(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            action_ctx: anytype,
            comptime ACTION_CTX: anytype,
            comptime ACTION_ERROR: ?type,
            comptime ACTION_FN_KIND: FuncParamType,
            action: ForEachActionRT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime ACTION: ForEachActionCT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime FILTER_ERROR: ?type,
            comptime FILTER_FN_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR),
            comptime FILTER: FilterFnCT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR),
        ) ForEachReturn(.USE_FILTERING_FUNC, FILTER_ERROR, ACTION_ERROR) {
            return IMPL.for_each_in_range_filtered_reverse_advanced(self, start, end_excluded, max_count, action_ctx, ACTION_CTX, ACTION_ERROR, ACTION_FN_KIND, action, ACTION, FILTER_ERROR, FILTER_FN_KIND, filter, FILTER);
        }
        pub inline fn for_each_in_range_filtered_reverse(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            action: *const fn (ListSelf, IDX, void, void) void,
            filter: *const fn (ListSelf, IDX, void, void) bool,
        ) ForEachReturn(.USE_FILTERING_FUNC, null, null) {
            return IMPL.for_each_in_range_filtered_reverse(self, start, end_excluded, max_count, action, filter);
        }

        pub inline fn for_each_in_range_filtered_reverse_with_context(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            context: anytype,
            action: *const fn (ListSelf, IDX, @TypeOf(context), void) void,
            filter: *const fn (ListSelf, IDX, @TypeOf(context), void) bool,
        ) ForEachReturn(.USE_FILTERING_FUNC, null, null) {
            return IMPL.for_each_in_range_filtered_reverse_with_context(self, start, end_excluded, max_count, context, action, filter);
        }

        pub inline fn for_each_filtered_reverse_advanced(
            self: ListSelf,
            max_count: IDX,
            action_ctx: anytype,
            comptime ACTION_CTX: anytype,
            comptime ACTION_ERROR: ?type,
            comptime ACTION_FN_KIND: FuncParamType,
            action: ForEachActionRT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime ACTION: ForEachActionCT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime FILTER_ERROR: ?type,
            comptime FILTER_FN_KIND: FuncParamType,
            filter: FilterFnRT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR),
            comptime FILTER: FilterFnCT(FILTER_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), FILTER_ERROR),
        ) ForEachReturn(.USE_FILTERING_FUNC, FILTER_ERROR, ACTION_ERROR) {
            return IMPL.for_each_filtered_reverse_advanced(self, max_count, action_ctx, ACTION_CTX, ACTION_ERROR, ACTION_FN_KIND, action, ACTION, FILTER_ERROR, FILTER_FN_KIND, filter, FILTER);
        }

        pub inline fn for_each_filtered_reverse(
            self: ListSelf,
            max_count: IDX,
            action: *const fn (ListSelf, IDX, void, void) void,
            filter: *const fn (ListSelf, IDX, void, void) bool,
        ) ForEachReturn(.USE_FILTERING_FUNC, null, null) {
            return IMPL.for_each_filtered_reverse(self, max_count, action, filter);
        }
        pub inline fn for_each_filtered_reverse_with_context(
            self: ListSelf,
            max_count: IDX,
            context: anytype,
            action: *const fn (ListSelf, IDX, @TypeOf(context), void) void,
            filter: *const fn (ListSelf, IDX, @TypeOf(context), void) bool,
        ) ForEachReturn(.USE_FILTERING_FUNC, null, null) {
            return IMPL.for_each_filtered_reverse_with_context(self, max_count, context, action, filter);
        }

        pub inline fn for_each_in_range_reverse_advanced(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            action_ctx: anytype,
            comptime ACTION_CTX: anytype,
            comptime ACTION_ERROR: ?type,
            comptime ACTION_FN_KIND: FuncParamType,
            action: ForEachActionRT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime ACTION: ForEachActionCT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
        ) ForEachReturn(.NO_FILTERING, {}, ACTION_ERROR) {
            return IMPL.for_each_in_range_reverse_advanced(self, start, end_excluded, max_count, action_ctx, ACTION_CTX, ACTION_ERROR, ACTION_FN_KIND, action, ACTION);
        }
        pub inline fn for_each_in_range_reverse(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            action: *const fn (ListSelf, IDX, void, void) void,
        ) ForEachReturn(.NO_FILTERING, {}, null) {
            return IMPL.for_each_in_range_reverse(self, start, end_excluded, max_count, action);
        }

        pub inline fn for_each_in_range_reverse_with_context(
            self: ListSelf,
            start: IDX,
            end_excluded: ?IDX,
            max_count: IDX,
            context: anytype,
            action: *const fn (ListSelf, IDX, @TypeOf(context), void) void,
        ) ForEachReturn(.NO_FILTERING, {}, null) {
            return IMPL.for_each_in_range_reverse_with_context(self, start, end_excluded, max_count, context, action);
        }

        pub inline fn for_each_reverse_advanced(
            self: ListSelf,
            max_count: IDX,
            action_ctx: anytype,
            comptime ACTION_CTX: anytype,
            comptime ACTION_ERROR: ?type,
            comptime ACTION_FN_KIND: FuncParamType,
            action: ForEachActionRT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
            comptime ACTION: ForEachActionCT(ACTION_FN_KIND, @TypeOf(action_ctx), @TypeOf(ACTION_CTX), ACTION_ERROR),
        ) ForEachReturn(.NO_FILTERING, {}, ACTION_ERROR) {
            return IMPL.for_each_reverse_advanced(self, max_count, action_ctx, ACTION_CTX, ACTION_ERROR, ACTION_FN_KIND, action, ACTION);
        }

        pub inline fn for_each_reverse(
            self: ListSelf,
            max_count: IDX,
            action: *const fn (ListSelf, IDX, void, void) void,
        ) ForEachReturn(.NO_FILTERING, {}, null) {
            return IMPL.for_each_reverse(self, max_count, action);
        }
        pub inline fn for_each_reverse_with_context(
            self: ListSelf,
            max_count: IDX,
            context: anytype,
            action: *const fn (ListSelf, IDX, @TypeOf(context), void) void,
        ) ForEachReturn(.NO_FILTERING, {}, null) {
            return IMPL.for_each_reverse_with_context(self, max_count, context, action);
        }

        pub inline fn std_reader(self: ListSelf, buffer: []u8) StdReader {
            return IMPL.std_reader(self, buffer);
        }
        pub const StdReader = IMPL.StdReader;

        pub inline fn std_writer(self: *ListSelf, buffer: []u8) StdWriter {
            return IMPL.std_writer(self, buffer);
        }
        pub inline fn std_writer_with_alloc(self: *ListSelf, buffer: []u8, alloc: Allocator, growth: Growth) StdWriter {
            return IMPL.std_writer_with_alloc(self, buffer, alloc, growth);
        }

        pub const StdWriter = IMPL.StdWriter;

        pub inline fn forward_linked_traverser_static_stack(
            self: ListSelf,
            comptime FIRST_CHILD_FIELDS: []const Field,
            comptime OPT_NEXT_SIBLING_FIELD: ?Field,
            comptime MAX_STACK_MODE: TrackMaxStackMode,
            stack: ForwardLinkedTraverser(FIRST_CHILD_FIELDS, OPT_NEXT_SIBLING_FIELD, MAX_STACK_MODE).Stack,
        ) ForwardLinkedTraverser(FIRST_CHILD_FIELDS, OPT_NEXT_SIBLING_FIELD, MAX_STACK_MODE) {
            return IMPL.forward_linked_traverser_static_stack(self, FIRST_CHILD_FIELDS, OPT_NEXT_SIBLING_FIELD, MAX_STACK_MODE, stack);
        }
        pub inline fn forward_linked_traverser_pre_allocated_stack(
            self: ListSelf,
            comptime FIRST_CHILD_FIELDS: []const Field,
            comptime OPT_NEXT_SIBLING_FIELD: ?Field,
            comptime MAX_STACK_MODE: TrackMaxStackMode,
            stack: ForwardLinkedTraverser(FIRST_CHILD_FIELDS, OPT_NEXT_SIBLING_FIELD, MAX_STACK_MODE).Stack,
            stack_alloc: Allocator,
            stack_growth: Growth,
        ) ForwardLinkedTraverser(FIRST_CHILD_FIELDS, OPT_NEXT_SIBLING_FIELD, MAX_STACK_MODE) {
            return IMPL.forward_linked_traverser_pre_allocated_stack(self, FIRST_CHILD_FIELDS, OPT_NEXT_SIBLING_FIELD, MAX_STACK_MODE, stack, stack_alloc, stack_growth);
        }
        pub inline fn forward_linked_traverser_allocate_new_stack(
            self: ListSelf,
            comptime FIRST_CHILD_FIELDS: []const Field,
            comptime OPT_NEXT_SIBLING_FIELD: ?Field,
            comptime MAX_STACK_MODE: TrackMaxStackMode,
            stack_capacity: IDX,
            stack_alloc: Allocator,
            stack_growth: Growth,
        ) ForwardLinkedTraverser(FIRST_CHILD_FIELDS, OPT_NEXT_SIBLING_FIELD, MAX_STACK_MODE) {
            return IMPL.forward_linked_traverser_allocate_new_stack(self, FIRST_CHILD_FIELDS, OPT_NEXT_SIBLING_FIELD, MAX_STACK_MODE, stack_capacity, stack_alloc, stack_growth);
        }
        pub inline fn ForwardLinkedTraverser(comptime FIRST_CHILD_FIELDS: []const Field, comptime OPT_NEXT_SIBLING_FIELD: ?Field, comptime MAX_STACK_MODE: TrackMaxStackMode) type {
            return IMPL.ForwardLinkedTraverser(FIRST_CHILD_FIELDS, OPT_NEXT_SIBLING_FIELD, MAX_STACK_MODE);
        }
    };
}
