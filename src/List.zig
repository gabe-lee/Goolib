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

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const assert_unreachable_err_always_panic = Assert.assert_unreachable_err_always_panic;
const num_cast = Cast.num_cast;
const kind_info = KindInfo.get_kind_info;

pub const FieldLayout = enum {
    WHOLE_STRUCTS,
    SPLIT_FIELDS,
};

pub const IndexLayout = enum {
    SERIAL_INDEXES,
};

const AllocMode = enum {
    ASSUME_CAP,
    REALLOC,
};

const GrowthMode = enum {
    DEFAULT_GROWTH,
    CUSTOM_GROWTH,
};

const MoveOneDisplaceMode = enum {
    PRESERVE_VAL,
    IGNORE_VAL,
};

const DeleteMode = enum {
    ORDERED,
    SWAP,
};

const DeleteReturnMode = enum {
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

pub const SortOrder = enum(u8) {
    NORMAL,
    REVERSE,
};

pub const HeapKind = enum(u8) {
    MIN_HEAP,
    MAX_HEAP,
};

const ReturnMode = enum {
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
            .RETURN_VOID => void{},
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

pub const ListDef = struct {
    ELEM: type,
    IDX: type,
    FIELD_LAYOUT: FieldLayout,
    INDEX_LAYOUT: IndexLayout,
    OWNERSHIP: Ownership,

    pub inline fn List(comptime self: ListDef) type {
        return ListFullDefinition(self.ELEM, self.IDX, self.FIELD_LAYOUT, self.INDEX_LAYOUT, self.OWNERSHIP);
    }
};

pub fn ListNotAllocated(comptime T: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout) type {
    return ListFullDefinition(T, u32, FIELD_LAYOUT, INDEX_LAYOUT, .OWNED_NOT_ALLOCATED);
}
pub fn ListAllocated(comptime T: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout) type {
    return ListFullDefinition(T, u32, FIELD_LAYOUT, INDEX_LAYOUT, .OWNED_ALLOCATED);
}
pub fn SliceMutable(comptime T: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout) type {
    return ListFullDefinition(T, u32, FIELD_LAYOUT, INDEX_LAYOUT, .REFERENCED_MUTABLE);
}
pub fn SliceImmutable(comptime T: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout) type {
    return ListFullDefinition(T, u32, FIELD_LAYOUT, INDEX_LAYOUT, .REFERENCED_IMMUTABLE);
}

pub fn ListFullDefinition(comptime ELEM: type, comptime IDX: type, comptime FIELD_LAYOUT: FieldLayout, comptime INDEX_LAYOUT: IndexLayout, comptime OWNERSHIP: Ownership) type {
    assert_with_reason(Type.type_is_unsigned_int(IDX), @src(), "IDX type must be an unsigned integer, got type `{s}`", .{@typeName(IDX)});
    assert_with_reason(@sizeOf(ELEM) > 0, @src(), "not compatible with zero-size elements, type `{s}` is zer-sized", .{@typeName(ELEM)});
    const _NUM_FIELDS: usize = switch (@typeInfo(ELEM)) {
        .@"struct" => |s| s.fields.len,
        else => 1,
    };
    if (FIELD_LAYOUT == .SPLIT_FIELDS) {
        assert_with_reason(Type.type_is_struct(ELEM), @src(), ".SPLIT_FIELDS is only valid on struct types", .{});
    }
    if (Type.type_is_struct(ELEM)) {
        assert_with_reason(@typeInfo(ELEM).@"struct".fields.len > 0, @src(), "not compatible with zero-field structs", .{});
    }
    const _E_INT = std.meta.Int(.unsigned, @intCast(std.math.log2_int_ceil(usize, _NUM_FIELDS)));
    const _PROTO = struct {
        fn field_a_should_have_memory_offset_after_field_b(a: type, b: type) bool {
            return (@sizeOf(a) == 0) or @alignOf(a) < @alignOf(b);
        }
    };

    const _ORDERED_FIELD_NAMES, const _ORDERED_FIELD_TYPES, const _ORDERED_FIELD_OFFSETS, const _FIELD_ENUM = get: {
        switch (@typeInfo(ELEM)) {
            .@"struct" => {
                var info = Type.extract_struct_info(ELEM);
                Root.Sort.InsertionSort.insertion_sort_with_func_and_matching_buffers(info.field_types[0..], &.{ info.field_names[0..], info.field_attrs[0..] }, _PROTO.field_a_should_have_memory_offset_after_field_b);
                var e_val: [_NUM_FIELDS]_E_INT = undefined;
                var off: [_NUM_FIELDS + 1]IDX = undefined;
                var off_total: IDX = 0;
                inline for (info.field_types[0..], 0..) |t, i| {
                    e_val[i] = @intCast(i);
                    off[i] = off_total;
                    off_total += @sizeOf(t);
                }
                off[_NUM_FIELDS] = off_total;
                break :get .{ info.field_names, info.field_types, off, @Enum(_E_INT, .exhaustive, info.field_names[0..], e_val[0..]) };
            },
            else => break :get .{ [1][]const u8{"$SELF"}, [1]type{ELEM}, [2]IDX{ 0, @sizeOf(ELEM) }, @Enum(u1, .exhaustive, &.{"$SELF"}, &.{0}) },
        }
    };
    return struct {
        const Self = @This();
        pub const GOOLIB_LIST_DEF = ListDef{
            .ELEM = ELEM,
            .IDX = IDX,
            .FIELD_LAYOUT = FIELD_LAYOUT,
            .INDEX_LAYOUT = INDEX_LAYOUT,
            .OWNERSHIP = OWNERSHIP,
        };
        const NUM_FIELDS = _NUM_FIELDS;
        const ORDERED_FIELD_NAMES = _ORDERED_FIELD_NAMES;
        const ORDERED_FIELD_TYPES = _ORDERED_FIELD_TYPES;
        const ORDERED_FIELD_OFFSETS = _ORDERED_FIELD_OFFSETS;
        const SPLIT = FIELD_LAYOUT == .SPLIT_FIELDS;
        const IS_STRUCT = Type.type_is_struct(ELEM);
        const IS_UNION = Type.type_is_union(ELEM);
        const MAX_ALIGN = @alignOf(ELEM);
        const SERIAL_IDXS = switch (INDEX_LAYOUT) {
            .SERIAL_INDEXES => true,
            else => false,
        };
        const IS_OWNED = OWNERSHIP != .REFERENCED_MUTABLE and OWNERSHIP != .REFERENCED_IMMUTABLE;
        const IS_OWNED_ALLOCATED = OWNERSHIP == .OWNED_ALLOCATED;
        const IS_REFERENCE = !IS_OWNED;
        const IS_CONST = OWNERSHIP == .REFERENCED_IMMUTABLE;
        const HAS_ROOT_OFFSET = switch (INDEX_LAYOUT) {
            .SERIAL_INDEXES => false,
        };
        const IS_MUTABLE = !IS_CONST;
        const ENUM_INT = _E_INT;
        pub const Field = _FIELD_ENUM;
        const MemPtr = if (SPLIT) (if (IS_CONST) [*]align(MAX_ALIGN) const u8 else [*]align(MAX_ALIGN) u8) else (if (IS_CONST) [*]const ELEM else [*]ELEM);
        const ElemPtr = if (SPLIT) build: {
            if (IS_STRUCT) {
                const old_info = Type.extract_struct_info(ELEM);
                var new_info = old_info;
                for (old_info.field_types[0..], new_info.field_types[0..], new_info.field_attrs[0..]) |old_t, *new_t, *new_attr| {
                    new_t.* = @Pointer(.one, .{}, old_t, null);
                    new_attr.* = .{};
                }
                const PtrStruct = new_info.build_struct_type();
                break :build PtrStruct;
            } else if (IS_UNION) {
                const old_info = Type.extract_union_info(ELEM);
                var new_info = old_info;
                for (old_info.field_types[0..], new_info.field_types[0..], new_info.field_attrs[0..]) |old_t, *new_t, *new_attr| {
                    new_t.* = @Pointer(.one, .{}, old_t, null);
                    new_attr.* = .{};
                }
                const UnionStruct = new_info.build_union_type();
                break :build UnionStruct;
            } else {
                break :build *ELEM;
            }
        } else *ELEM;
        const ElemPtrConst = if (SPLIT) build: {
            if (IS_STRUCT) {
                const old_info = Type.extract_struct_info(ELEM);
                var new_info = old_info;
                for (old_info.field_types[0..], new_info.field_types[0..], new_info.field_attrs[0..]) |old_t, *new_t, *new_attr| {
                    new_t.* = @Pointer(.one, .{ .@"const" = true }, old_t, null);
                    new_attr.* = .{};
                }
                const PtrStruct = new_info.build_struct_type();
                break :build PtrStruct;
            } else if (IS_UNION) {
                const old_info = Type.extract_union_info(ELEM);
                var new_info = old_info;
                for (old_info.field_types[0..], new_info.field_types[0..], new_info.field_attrs[0..]) |old_t, *new_t, *new_attr| {
                    new_t.* = @Pointer(.one, .{ .@"const" = true }, old_t, null);
                    new_attr.* = .{};
                }
                const UnionStruct = new_info.build_union_type();
                break :build UnionStruct;
            } else {
                break :build *const ELEM;
            }
        } else *const ELEM;
        const TrueIdx = struct {
            idx: IDX,

            pub inline fn new(idx: IDX) TrueIdx {
                return TrueIdx{ .idx = idx };
            }
        };
        pub const IdxElemPair = struct { IDX, ELEM };

        // Root memory region
        /// The root memory pointer of the memory region
        root_ptr: MemPtr = undefined,
        /// The root capacity of the memory region
        root_cap: IDX = 0,
        /// The offset from the root pointer that represents
        /// the 'first' element in the data. For example, this would be used
        /// in a Ring Buffer configuration, to denote the current starting position
        /// where index `0` sits
        root_offset: if (HAS_ROOT_OFFSET) IDX else void = if (HAS_ROOT_OFFSET) 0 else void{},
        // Usable data slice
        /// The length of the data, either its entirety or as a slice
        data_len: IDX = 0,
        /// If the list is a slice, this is the offset from index
        /// `0` where the slice starts
        slice_offset: if (IS_REFERENCE) IDX else void = if (IS_REFERENCE) 0 else void{},

        //****************
        // ASSERT/UTILS
        //****************
        fn assert_valid_idx(self: Self, idx: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(idx < self.data_len, src, "index `{d}` is out of bounds (len = {d})", .{ idx, self.data_len });
        }
        fn assert_idx_plus_count_less_equal_len(self: Self, idx: IDX, count: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(idx + count <= self.data_len, src, "index plus count `{d} + {d}` is out of bounds (len = {d})", .{ idx, count, self.data_len });
        }
        fn assert_valid_idx_or_zero_if_len_is_zero(self: Self, idx: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason((self.data_len == 0 and idx == 0) or (idx < self.data_len), src, "index `{d}` is out of bounds (len = {d})", .{ idx, self.data_len });
        }
        fn assert_valid_range(self: Self, start: IDX, end_exclusive: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(start <= end_exclusive, src, "start index is after end index exclusive ({d} > {d})", .{ start, end_exclusive });
            assert_with_reason(end_exclusive <= self.get_len(), src, "end_exclusive index is after data len ({d} > {d})", .{ end_exclusive, self.get_len() });
        }
        fn assert_valid_range_3(self: Self, start: IDX, middle: IDX, end_exclusive: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(start <= middle, src, "start index is after middle index ({d} > {d})", .{ start, middle });
            assert_with_reason(middle <= end_exclusive, src, "middle index is after end_exclusive index ({d} > {d})", .{ middle, end_exclusive });
            assert_with_reason(end_exclusive <= self.get_len(), src, "end_exclusive index is after data len ({d} > {d})", .{ end_exclusive, self.get_len() });
        }
        fn assert_valid_idx_or_len(self: Self, idx: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(idx <= self.data_len, src, "index `{d}` is out of bounds (len = {d})", .{ idx, self.data_len });
        }
        fn assert_count_less_equal_slice_offset(self: Self, count: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(count <= self.get_slice_offset(), src, "count `{d}` greater than slice offset (offset = {d})", .{ count, self.get_slice_offset() });
        }
        fn assert_count_less_equal_len(self: Self, count: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(count <= self.data_len, src, "count `{d}` is greater than len (len = {d})", .{ count, self.data_len });
        }
        fn assert_count_less_equal_data_unused_space(self: Self, count: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(count <= (self.get_cap() - self.get_len()), src, "count `{d}` greater than data cap minus data len (free space = {d})", .{ count, self.get_cap() - self.get_len() });
        }
        fn assert_count_less_equal_data_unused_space_for_overlapping_copy(self: Self, count: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(count <= (self.get_cap() - self.get_len()), src, "memory region to append/prepend/insert overlaps with own memory region, but copy len `{d}` is greater than data cap minus data len (free space = {d}): self needs to be reallocated, but reallocating invalidates the memory region to copy. Call `grow_capacity_if_needed_for_n_more_elems(vals.get_len())` first then re-aquire the new vals slice before attempting to copy over.", .{ count, self.get_cap() - self.get_len() });
        }
        fn assert_whole_struct_for_ptr(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(!SPLIT, src, "cannot get whole struct pointer in .SPLIT_FIELDS mode", .{});
        }
        fn assert_whole_struct_for_zig_slice(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(!SPLIT, src, "cannot get normal slice in .SPLIT_FIELDS mode", .{});
        }
        fn assert_start_less_end_exclusive(start: IDX, end_excl: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(start < end_excl, src, "start must be <= end_exclusive, got {d} > {d}", .{ start, end_excl });
        }
        fn assert_start_less_or_equal_end_exclusive(start: IDX, end_excl: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(start <= end_excl, src, "start must be <= end_exclusive, got {d} > {d}", .{ start, end_excl });
        }
        fn assert_serial_indexes(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(SERIAL_IDXS, src, "indexes must be serially in order at this point", .{});
        }
        fn assert_owned(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(IS_OWNED, src, "slice is not owned (reference to memory only)", .{});
        }
        fn assert_owned_not_allocated(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(IS_OWNED and !IS_OWNED_ALLOCATED, src, "slice is not owned OR list is allocated", .{});
        }
        fn assert_reference(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(IS_REFERENCE, src, "list is not a reference to owned memory", .{});
        }
        fn assert_reference_mutable(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(IS_REFERENCE and IS_MUTABLE, src, "list/slice is not a mutable reference to owned memory", .{});
        }
        fn assert_owned_allocated(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(IS_OWNED_ALLOCATED, src, "cannot alter capacity/memory pointer on non-owned or non-allocated memory", .{});
        }
        fn assert_len_less_equal_cap(self: Self, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.get_len() <= self.get_cap(), src, "len is > cap ({d} > {d})", .{ self.data_len, self.get_cap() });
        }
        fn assert_len_greater_equal_count(self: Self, count: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(count <= self.get_len(), src, "count is > len ({d} > {d})", .{ count, self.data_len });
        }
        fn assert_len_plus_count_less_equal_cap(self: Self, count: IDX, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason((self.data_len + count) <= self.get_cap(), src, "(len + count) is > cap (({d} + {d}) > {d})", .{ self.data_len, count, self.get_cap() });
        }
        fn assert_mutable(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(IS_MUTABLE, src, "pointer is not mutable", .{});
        }
        fn assert_stack_can_support_sort_len(comptime SETTINGS: QuicksortSettings, data_len: IDX, comptime src: ?std.builtin.SourceLocation) void {
            const needed_stack_len: u8 = @intCast(std.math.log2_int(IDX, data_len) + 2);
            assert_with_reason(SETTINGS.QUICKSORT_MAX_STACK >= needed_stack_len, src, "the provided `.QUICKSORT_MAX_STACK` setting ({d}) is too small, need stack len {d} for given the data len {d}", .{ SETTINGS.QUICKSORT_MAX_STACK, needed_stack_len, data_len });
        }
        fn assert_goolib_list(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(@hasDecl(T, "GOOLIB_LIST_DEF"), src, "type is not a Goolib List, got type `{s}`", .{@typeName(T)});
            assert_with_reason(@TypeOf(@field(T, "GOOLIB_LIST_DEF")) == ListDef, src, "type is not a Goolib List (`GOOLIB_LIST_DEF` decl is type `{s}`), got type `{s}`", .{ @typeName(@TypeOf(@field(T, "GOOLIB_LIST_DEF"))), @typeName(T) });
            assert_with_reason(T == T.GOOLIB_LIST_DEF.List(), src, "type is not a Goolib List (`T` != `T.GOOLIB_LIST_DEF.List()`, got type `{s}`", .{@typeName(T)});
        }
        fn assert_goolib_list_ptr(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(Type.type_is_pointer_or_slice(T), src, "type is not a pointer to Goolib List, got type `{s}`", .{@typeName(T)});
            const TT = @typeInfo(T).pointer.child;
            assert_goolib_list(TT, src);
        }
        fn assert_goolib_list_ptr_get_list_type(comptime T: type, comptime src: ?std.builtin.SourceLocation) type {
            assert_with_reason(Type.type_is_pointer_or_slice(T), src, "type is not a pointer to Goolib List, got type `{s}`", .{@typeName(T)});
            const TT = @typeInfo(T).pointer.child;
            assert_goolib_list(TT, src);
            return TT;
        }
        fn assert_goolib_list_ptr_with_same_elem_type_get_list_type(comptime T: type, comptime src: ?std.builtin.SourceLocation) type {
            assert_with_reason(Type.type_is_pointer_or_slice(T), src, "type is not a pointer to Goolib List, got type `{s}`", .{@typeName(T)});
            const TT = @typeInfo(T).pointer.child;
            assert_goolib_list_with_same_elem(TT, src);
            return TT;
        }
        fn assert_goolib_list_with_same_elem(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
            assert_goolib_list(T, src);
            assert_with_reason(T.GOOLIB_LIST_DEF.ELEM == ELEM, src, "Goolib list does not have matching element type (got `{s}`, need `{s}`)", .{ @typeName(T.GOOLIB_LIST_DEF.ELEM), @typeName(ELEM) });
        }
        fn assert_goolib_list_ptr_with_same_elem(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
            const TT = assert_goolib_list_ptr_get_list_type(T, src);
            assert_with_reason(TT.GOOLIB_LIST_DEF.ELEM == ELEM, src, "Goolib list does not have matching element type (got `{s}`, need `{s}`)", .{ @typeName(TT.GOOLIB_LIST_DEF.ELEM), @typeName(ELEM) });
        }
        inline fn assert_no_mem_overlap(a: []const ELEM, b: []const ELEM, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(!memory_overlaps(ELEM, a, b), src, "memory slices cannot alias (overlap)", .{});
        }
        inline fn memory_overlaps(comptime T: type, a: []const T, b: []const T) bool {
            return (@intFromPtr(a.ptr) < @intFromPtr(b.ptr + b.len)) and (@intFromPtr(b.ptr) < @intFromPtr(a.ptr + a.len));
        }
        inline fn list_memory_overlaps(a: anytype, b: anytype) bool {
            const aa, const AA = coerce_anytype_to_list_or_list_ptr_with_same_elem_type_get_list_type(a);
            const bb, const BB = coerce_anytype_to_list_or_list_ptr_with_same_elem_type_get_list_type(b);
            if (aa.root_cap == 0 or bb.root_cap == 0) return false;
            if (AA.GOOLIB_LIST_DEF.FIELD_LAYOUT != BB.GOOLIB_LIST_DEF.FIELD_LAYOUT) {
                return false;
            }
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return (@intFromPtr(aa.root_ptr) < @intFromPtr(bb.root_ptr + bb.root_cap)) and (@intFromPtr(bb.root_ptr) < @intFromPtr(aa.root_ptr + aa.root_cap));
                },
                .SPLIT_FIELDS => {
                    return (@intFromPtr(aa.root_ptr) < @intFromPtr(bb.root_ptr + (bb.end_stride() * bb.root_cap))) and (@intFromPtr(bb.root_ptr) < @intFromPtr(aa.root_ptr + (aa.end_stride() * aa.root_cap)));
                },
            }
        }

        inline fn end_stride() IDX {
            return ORDERED_FIELD_OFFSETS[NUM_FIELDS];
        }
        inline fn field_begin_stride(comptime field: Field) IDX {
            return ORDERED_FIELD_OFFSETS[@intFromEnum(field)];
        }
        inline fn field_begin_stride_fidx(comptime fidx: usize) IDX {
            return ORDERED_FIELD_OFFSETS[fidx];
        }
        inline fn FieldType(comptime field: Field) type {
            return ORDERED_FIELD_TYPES[@intFromEnum(field)];
        }
        inline fn FieldTypeFidx(comptime fidx: usize) type {
            return ORDERED_FIELD_TYPES[fidx];
        }
        inline fn get_root_offset(self: Self) IDX {
            if (comptime HAS_ROOT_OFFSET) return self.root_offset;
            return 0;
        }
        inline fn get_slice_offset(self: Self) IDX {
            if (comptime IS_REFERENCE) return self.slice_offset;
            return 0;
        }
        inline fn true_idx(self: Self, idx: IDX) TrueIdx {
            return switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES => TrueIdx.new(idx + self.get_root_offset() + self.get_slice_offset()),
            };
        }
        inline fn slice_idx_to_root_idx(self: Self, idx: IDX) IDX {
            return idx + self.get_slice_offset();
        }
        inline fn root_idx_to_slice_idx(self: Self, idx: IDX) IDX {
            return idx - self.get_slice_offset();
        }
        inline fn assign_val_to_elem_ptr(elem_ptr: ElemPtr, val: ELEM) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    elem_ptr.* = val;
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_NAMES[0..]) |fname| {
                        @field(elem_ptr, fname).* = @field(val, fname);
                    }
                },
            }
        }
        inline fn field_slice_from_field_idx(self: Self, comptime FIDX: usize) if (IS_CONST) [*]const FieldTypeFidx(FIDX) else [*]FieldTypeFidx(FIDX) {
            const stride = ORDERED_FIELD_OFFSETS[FIDX] * self.root_cap;
            return @ptrCast(@alignCast(self.root_ptr + stride));
        }
        inline fn root_field_ptr(self: Self, comptime FIELD: Field) if (IS_CONST) [*]const FieldType(FIELD) else [*]FieldType(FIELD) {
            return self.field_slice_from_field_idx(@intFromEnum(FIELD));
        }
        inline fn contiguous_indexes_after_index_inclusive(self: Self, start: IDX) IDX {
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES => return self.data_len - start,
            }
        }
        inline fn contiguous_indexes_after_index_inclusive_max(self: Self, start: IDX, max: IDX) IDX {
            return @min(max, self.contiguous_indexes_after_index_inclusive(start));
        }
        inline fn get_list_def(comptime TT: type) ListDef {
            assert_goolib_list(TT, @src());
            return TT.GOOLIB_LIST_DEF;
        }
        inline fn coerce_anytype_to_list_with_same_elem_type(val_: anytype) get_list_def(@TypeOf(val_)).List() {
            const VAL_ = @TypeOf(val_);
            assert_goolib_list_with_same_elem(VAL_, @src());
            const VAL_DEF: ListDef = VAL_.GOOLIB_LIST_DEF;
            const VAL = VAL_DEF.List();
            return @as(VAL, val_);
        }
        inline fn coerce_anytype_to_list_ptr_with_same_elem_type(val_: anytype) *get_list_def(@typeInfo(@TypeOf(val_)).pointer.child).List() {
            const T_VAL = @TypeOf(val_);
            const T_VAL_LIST = assert_goolib_list_ptr_with_same_elem_type_get_list_type(T_VAL, @src());
            const VAL_LIST_DEF: ListDef = T_VAL_LIST.GOOLIB_LIST_DEF;
            const VAL_LIST = VAL_LIST_DEF.List();
            return @as(*VAL_LIST, val_);
        }
        inline fn coerce_anytype_to_list_ptr_const_with_same_elem_type(val_: anytype) *const get_list_def(@typeInfo(@TypeOf(val_)).pointer.child).List() {
            const T_VAL = @TypeOf(val_);
            const T_VAL_LIST = assert_goolib_list_ptr_with_same_elem_type_get_list_type(T_VAL, @src());
            const VAL_LIST_DEF: ListDef = T_VAL_LIST.GOOLIB_LIST_DEF;
            const VAL_LIST = VAL_LIST_DEF.List();
            return @as(*const VAL_LIST, val_);
        }
        inline fn coerce_anytype_to_list_or_list_ptr_with_same_elem_type(val_: anytype) switch (@typeInfo(@TypeOf(val_))) {
            .pointer => |p| if (p.is_const) *const get_list_def(p.child).List() else *get_list_def(p.child).List(),
            .@"struct" => get_list_def(@TypeOf(val_)).List(),
            else => unreachable,
        } {
            const V = @TypeOf(val_);
            return switch (@typeInfo(V)) {
                .pointer => |p| if (p.is_const) coerce_anytype_to_list_ptr_const_with_same_elem_type(val_) else coerce_anytype_to_list_ptr_with_same_elem_type(val_),
                .@"struct" => coerce_anytype_to_list_with_same_elem_type(val_),
                else => assert_unreachable(@src(), "type `{s}` cannot be coerced to a Goolib List with elem type `{s}`", .{ @typeName(@TypeOf(val_)), @typeName(ELEM) }),
            };
        }
        inline fn coerce_anytype_to_list_or_list_ptr_with_same_elem_type_get_list_type(val_: anytype) switch (@typeInfo(@TypeOf(val_))) {
            .pointer => |p| if (p.is_const) struct { *const get_list_def(p.child).List(), type } else struct { *get_list_def(p.child).List(), type },
            .@"struct" => struct { get_list_def(@TypeOf(val_)).List(), type },
            else => unreachable,
        } {
            const V = @TypeOf(val_);
            return switch (@typeInfo(V)) {
                .pointer => |p| if (p.is_const) .{ coerce_anytype_to_list_ptr_const_with_same_elem_type(val_), V } else .{ coerce_anytype_to_list_ptr_with_same_elem_type(val_), V },
                .@"struct" => .{coerce_anytype_to_list_with_same_elem_type(val_).V},
                else => assert_unreachable(@src(), "type `{s}` cannot be coerced to a Goolib List with elem type `{s}`", .{ @typeName(@TypeOf(val_)), @typeName(ELEM) }),
            };
        }

        inline fn FilterFnRt(comptime KIND: FuncParamType, comptime RT_CTX: type, comptime CT_CTX: type) type {
            return switch (comptime KIND) {
                .RUNTIME_FN_PTR => *const fn (Self, IDX, RT_CTX, CT_CTX) bool,
                .COMPTIME_FN_BODY, .COMPTIME_FN_PTR => void,
            };
        }
        inline fn FilterFnCt(comptime KIND: FuncParamType, comptime RT_CTX: type, comptime CT_CTX: type) type {
            return switch (comptime KIND) {
                .RUNTIME_FN_PTR => void,
                .COMPTIME_FN_BODY => fn (Self, IDX, RT_CTX, comptime CT_CTX) bool,
                .COMPTIME_FN_PTR => *const fn (Self, IDX, RT_CTX, comptime CT_CTX) bool,
            };
        }
        inline fn eval_filter(self: Self, idx: IDX, comptime KIND: FuncParamType, filter_ctx: anytype, comptime FILTER_CTX: anytype, filter: FilterFnRt(KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)), comptime FILTER: FilterFnCt(KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX))) bool {
            switch (comptime KIND) {
                .RUNTIME_FN_PTR => {
                    return filter(self, idx, filter_ctx, FILTER_CTX);
                },
                .COMPTIME_FN_BODY, .COMPTIME_FN_PTR => {
                    return FILTER(self, idx, filter_ctx, FILTER_CTX);
                },
            }
        }
        inline fn CompareIdxIdxFnRt(comptime KIND: FuncParamType, comptime RT_CTX: type, comptime CT_CTX: type) type {
            return switch (comptime KIND) {
                .RUNTIME_FN_PTR => *const fn (Self, IDX, IDX, RT_CTX, CT_CTX) bool,
                .COMPTIME_FN_BODY, .COMPTIME_FN_PTR => void,
            };
        }
        inline fn CompareIdxIdxFnCt(comptime KIND: FuncParamType, comptime RT_CTX: type, comptime CT_CTX: type) type {
            return switch (comptime KIND) {
                .RUNTIME_FN_PTR => void,
                .COMPTIME_FN_BODY => fn (Self, IDX, IDX, RT_CTX, comptime CT_CTX) bool,
                .COMPTIME_FN_PTR => *const fn (Self, IDX, IDX, RT_CTX, comptime CT_CTX) bool,
            };
        }
        inline fn eval_compare_idx_idx(self: Self, idx_a: IDX, idx_b: IDX, comptime KIND: FuncParamType, compare_ctx: anytype, comptime COMPARE_CTX: anytype, compare: CompareIdxIdxFnRt(KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)), comptime COMPARE: CompareIdxIdxFnCt(KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX))) bool {
            switch (comptime KIND) {
                .RUNTIME_FN_PTR => {
                    return compare(self, idx_a, idx_b, compare_ctx, COMPARE_CTX);
                },
                .COMPTIME_FN_BODY, .COMPTIME_FN_PTR => {
                    return COMPARE(self, idx_a, idx_b, compare_ctx, COMPARE_CTX);
                },
            }
        }
        inline fn CompareIdxValFnRt(comptime KIND: FuncParamType, comptime RT_CTX: type, comptime CT_CTX: type) type {
            return switch (comptime KIND) {
                .RUNTIME_FN_PTR => *const fn (Self, IDX, ELEM, RT_CTX, CT_CTX) bool,
                .COMPTIME_FN_BODY, .COMPTIME_FN_PTR => void,
            };
        }
        inline fn CompareIdxValFnCt(comptime KIND: FuncParamType, comptime RT_CTX: type, comptime CT_CTX: type) type {
            return switch (comptime KIND) {
                .RUNTIME_FN_PTR => void,
                .COMPTIME_FN_BODY => fn (Self, IDX, ELEM, RT_CTX, comptime CT_CTX) bool,
                .COMPTIME_FN_PTR => *const fn (Self, IDX, ELEM, RT_CTX, comptime CT_CTX) bool,
            };
        }
        inline fn eval_compare_idx_val(self: Self, idx_a: IDX, val_b: ELEM, comptime KIND: FuncParamType, compare_ctx: anytype, comptime COMPARE_CTX: anytype, compare: CompareIdxValFnRt(KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)), comptime COMPARE: CompareIdxValFnCt(KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX))) bool {
            switch (comptime KIND) {
                .RUNTIME_FN_PTR => {
                    return compare(self, idx_a, val_b, compare_ctx, COMPARE_CTX);
                },
                .COMPTIME_FN_BODY, .COMPTIME_FN_PTR => {
                    return COMPARE(self, idx_a, val_b, compare_ctx, COMPARE_CTX);
                },
            }
        }

        //****************
        // SET
        //****************
        fn set_true_idx(self: Self, tidx: TrueIdx, val: ELEM) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    self.root_ptr[tidx.idx] = val;
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_NAMES[0..], 0..) |name, fidx| {
                        const field_slice = self.field_slice_from_field_idx(fidx);
                        field_slice[tidx.idx] = @field(val, name);
                    }
                },
            }
        }
        pub fn set(self: Self, idx: IDX, val: ELEM) void {
            self.assert_valid_idx(idx, @src());
            self.set_true_idx(self.true_idx(idx), val);
        }
        fn set_field_true_idx(self: Self, comptime field: Field, tidx: TrueIdx, val: FieldType(field)) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    if (comptime IS_STRUCT) {
                        @field(&self.root_ptr[tidx.idx], @tagName(field)) = val;
                    } else {
                        self.root_ptr[tidx.idx] = val;
                    }
                },
                .SPLIT_FIELDS => {
                    const field_slice = self.root_field_ptr(field);
                    field_slice[tidx.idx] = val;
                },
            }
        }
        pub fn set_field(self: Self, comptime field: Field, idx: IDX, val: FieldType(field)) void {
            self.assert_valid_idx(idx, @src());
            self.set_field_true_idx(field, self.true_idx(idx), val);
        }
        //****************
        // GET
        //****************
        fn get_true_idx(self: Self, tidx: TrueIdx) ELEM {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return self.root_ptr[tidx.idx];
                },
                .SPLIT_FIELDS => {
                    var val: ELEM = undefined;
                    inline for (ORDERED_FIELD_NAMES[0..], 0..) |name, fidx| {
                        const field_slice = self.field_slice_from_field_idx(fidx);
                        @field(val, name) = field_slice[tidx.idx];
                    }
                    return val;
                },
            }
        }
        pub fn get(self: Self, idx: IDX) ELEM {
            self.assert_valid_idx(idx, @src());
            return self.get_true_idx(self.true_idx(idx));
        }
        fn get_ptr_true_idx(self: Self, tidx: TrueIdx) ElemPtr {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return &self.root_ptr[tidx.idx];
                },
                .SPLIT_FIELDS => {
                    var ptr_container: ElemPtr = undefined;
                    inline for (ORDERED_FIELD_NAMES[0..NUM_FIELDS], 0..) |f_name, fidx| {
                        const field_slice = self.field_slice_from_field_idx(fidx);
                        @field(ptr_container, f_name) = &field_slice[tidx.idx];
                    }
                    return ptr_container;
                },
            }
        }
        pub fn get_ptr(self: Self, idx: IDX) ElemPtr {
            self.assert_valid_idx(idx, @src());
            assert_mutable(@src());
            return self.get_ptr_true_idx(self.true_idx(idx));
        }
        fn get_ptr_const_true_idx(self: Self, tidx: TrueIdx) ElemPtrConst {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return &self.root_ptr[tidx.idx];
                },
                .SPLIT_FIELDS => {
                    var ptr_container: ElemPtrConst = undefined;
                    inline for (ORDERED_FIELD_NAMES[0..NUM_FIELDS], 0..) |f_name, fidx| {
                        const field_slice = self.field_slice_from_field_idx(fidx);
                        @field(ptr_container, f_name) = &field_slice[tidx.idx];
                    }
                    return ptr_container;
                },
            }
        }
        pub fn get_ptr_const(self: Self, idx: IDX) ElemPtrConst {
            self.assert_valid_idx(idx, @src());
            return self.get_ptr_const_true_idx(self.true_idx(idx));
        }
        fn get_field_true_idx(self: Self, comptime field: Field, tidx: TrueIdx) FieldType(field) {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    if (IS_STRUCT) {
                        return @field(&self.root_ptr[tidx.idx], @tagName(field));
                    } else {
                        return self.root_ptr[tidx.idx];
                    }
                },
                .SPLIT_FIELDS => {
                    const field_slice = self.root_field_ptr(field);
                    return field_slice[tidx.idx];
                },
            }
        }
        pub fn get_field(self: Self, comptime field: Field, idx: IDX) FieldType(field) {
            self.assert_valid_idx(idx, @src());
            return self.get_field_true_idx(field, self.true_idx(idx));
        }
        fn get_field_ptr_true_idx(self: Self, comptime field: Field, tidx: TrueIdx) *FieldType(field) {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    if (comptime IS_STRUCT) {
                        return &@field(&self.root_ptr[tidx.idx], @tagName(field));
                    } else {
                        return &self.root_ptr[tidx.idx];
                    }
                },
                .SPLIT_FIELDS => {
                    const field_slice = self.root_field_ptr(field);
                    return &field_slice[tidx.idx];
                },
            }
        }
        pub fn get_field_ptr(self: Self, comptime field: Field, idx: IDX) *FieldType(field) {
            self.assert_valid_idx(idx, @src());
            assert_mutable(@src());
            return self.get_field_ptr_true_idx(field, self.true_idx(idx));
        }
        fn get_field_ptr_const_true_idx(self: Self, comptime field: Field, tidx: TrueIdx) *const FieldType(field) {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    if (comptime IS_STRUCT) {
                        return &@field(&self.root_ptr[tidx.idx], @tagName(field));
                    } else {
                        return &self.root_ptr[tidx.idx];
                    }
                },
                .SPLIT_FIELDS => {
                    const field_slice = self.root_field_ptr(field);
                    return &field_slice[tidx.idx];
                },
            }
        }
        pub fn get_field_ptr_const(self: Self, comptime field: Field, idx: IDX) *const FieldType(field) {
            self.assert_valid_idx(idx, @src());
            return self.get_field_ptr_const_true_idx(field, self.true_idx(idx));
        }
        //****************
        // LEN/CAP
        //****************
        pub inline fn get_len(self: Self) IDX {
            return self.data_len;
        }
        pub inline fn set_len(self: *Self, new_len: IDX) void {
            self.data_len = new_len;
            self.assert_len_less_equal_cap(@src());
        }
        pub inline fn incr_len(self: *Self, count: IDX) void {
            self.data_len += count;
            self.assert_len_less_equal_cap(@src());
        }
        pub inline fn set_len_unchecked(self: *Self, new_len: IDX) void {
            self.data_len = new_len;
        }
        pub inline fn incr_len_unchecked(self: *Self, count: IDX) void {
            self.data_len += count;
        }
        pub inline fn set_len_clamped(self: *Self, new_len: IDX) void {
            self.data_len = @min(new_len, self.get_cap());
        }
        pub inline fn incr_len_clamped(self: *Self, count: IDX) void {
            self.data_len +|= count;
            self.data_len = @min(self.data_len, self.get_cap());
        }
        pub inline fn decr_len(self: *Self, count: IDX) void {
            self.assert_len_greater_equal_count(count, @src());
            self.data_len -= count;
        }
        pub inline fn decr_len_unchecked(self: *Self, count: IDX) void {
            self.data_len -= count;
        }
        pub inline fn decr_len_clamped(self: *Self, count: IDX) void {
            self.data_len -|= count;
        }
        pub inline fn get_cap(self: Self) IDX {
            if (comptime IS_REFERENCE) return self.root_cap - self.get_slice_offset();
            return self.root_cap;
        }
        pub inline fn set_root_cap(self: *Self, new_cap: IDX) void {
            assert_owned_not_allocated(@src());
            self.root_cap = new_cap;
            self.data_len = @min(self.data_len, self.root_cap);
        }
        pub inline fn incr_root_cap(self: *Self, count: IDX) void {
            assert_owned_not_allocated(@src());
            self.root_cap += count;
        }
        pub inline fn incr_root_cap_clamped(self: *Self, count: IDX) void {
            assert_owned_not_allocated(@src());
            self.root_cap +|= count;
        }
        pub inline fn decr_root_cap(self: *Self, count: IDX) void {
            assert_owned_not_allocated(@src());
            self.root_cap -= count;
            self.data_len = @min(self.data_len, self.root_cap);
        }
        pub inline fn decr_root_cap_clamped(self: *Self, count: IDX) void {
            assert_owned_not_allocated(@src());
            self.root_cap -|= count;
            self.data_len = @min(self.data_len, self.root_cap);
        }
        inline fn incr_root_offset(self: *Self, count: IDX) void {
            self.root_offset += count;
        }
        inline fn decr_root_offset(self: *Self, count: IDX) void {
            self.root_offset -= count;
        }
        inline fn set_root_offset(self: *Self, offset: IDX) void {
            self.root_offset = offset;
        }
        pub inline fn get_unused_space(self: Self) IDX {
            return self.get_cap() - self.get_len();
        }
        //****************
        // SLICE
        //****************
        pub const Slice = ListFullDefinition(ELEM, IDX, FIELD_LAYOUT, INDEX_LAYOUT, .REFERENCED_MUTABLE);
        pub const SliceConst = ListFullDefinition(ELEM, IDX, FIELD_LAYOUT, INDEX_LAYOUT, .REFERENCED_IMMUTABLE);
        pub fn slice(self: Self, start: IDX, end_exclusive: IDX) Slice {
            self.assert_valid_range(start, end_exclusive, @src());
            assert_mutable(@src());
            return Slice{
                .root_ptr = self.root_ptr,
                .root_cap = self.root_cap,
                .root_offset = self.root_offset,
                .data_len = end_exclusive - start,
                .slice_offset = self.get_slice_offset() + start,
            };
        }
        pub fn slice_const(self: Self, start: IDX, end_exclusive: IDX) SliceConst {
            self.assert_valid_range(start, end_exclusive, @src());
            return SliceConst{
                .root_ptr = self.root_ptr,
                .root_cap = self.root_cap,
                .root_offset = self.root_offset,
                .data_len = end_exclusive - start,
                .slice_offset = self.get_slice_offset() + start,
            };
        }
        pub fn slice_from_start(self: Self, end_exclusive: IDX) Slice {
            return self.slice(0, end_exclusive);
        }
        pub fn slice_from_start_const(self: Self, end_exclusive: IDX) SliceConst {
            return self.slice_const(0, end_exclusive);
        }
        pub fn slice_to_end(self: Self, start: IDX) Slice {
            return self.slice(start, self.data_len);
        }
        pub fn slice_to_end_const(self: Self, start: IDX) SliceConst {
            return self.slice_const(start, self.data_len);
        }
        pub fn slice_entire(self: Self) Slice {
            return self.slice(0, self.data_len);
        }
        pub fn slice_entire_const(self: Self) SliceConst {
            return self.slice_const(0, self.data_len);
        }
        pub fn zig_slice(self: Self, start: IDX, end_exclusive: IDX) []ELEM {
            self.assert_valid_range(start, end_exclusive, @src());
            assert_mutable(@src());
            assert_whole_struct_for_zig_slice(@src());
            if (self.root_cap == 0) return &.{};
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES => {
                    return @as([*]ELEM, @ptrCast(self.get_ptr_true_idx(self.true_idx(0))))[start..end_exclusive];
                },
            }
        }
        pub fn zig_slice_const(self: Self, start: IDX, end_exclusive: IDX) []const ELEM {
            self.assert_valid_range(start, end_exclusive, @src());
            assert_whole_struct_for_zig_slice(@src());
            if (self.root_cap == 0) return &.{};
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES => {
                    return @as([*]const ELEM, @ptrCast(self.get_ptr_const_true_idx(self.true_idx(0))))[start..end_exclusive];
                },
            }
        }
        pub fn zig_slice_from_start(self: Self, end_exclusive: IDX) []ELEM {
            return self.zig_slice(0, end_exclusive);
        }
        pub fn zig_slice_from_start_const(self: Self, end_exclusive: IDX) []const ELEM {
            return self.zig_slice_const(0, end_exclusive);
        }
        pub fn zig_slice_to_end(self: Self, start: IDX) []ELEM {
            return self.zig_slice(start, self.data_len);
        }
        pub fn zig_slice_to_end_const(self: Self, start: IDX) []const ELEM {
            return self.zig_slice_const(start, self.data_len);
        }
        pub fn zig_slice_entire(self: Self) []ELEM {
            return self.zig_slice(0, self.data_len);
        }
        pub fn zig_slice_entire_const(self: Self) []const ELEM {
            return self.zig_slice_const(0, self.data_len);
        }
        //****************
        // SLICE MOVEMENT
        //****************
        pub fn incr_slice_start(self: *Self, count: IDX) void {
            assert_reference(@src());
            self.assert_count_less_equal_len(count, @src());
            self.slice_offset += count;
            self.decr_len(count);
        }
        pub fn decr_slice_start(self: *Self, count: IDX) void {
            assert_reference(@src());
            self.assert_count_less_equal_slice_offset(count, @src());
            self.slice_offset -= count;
            self.incr_len(count);
        }
        pub fn incr_slice_end(self: *Self, count: IDX) void {
            assert_reference(@src());
            self.assert_count_less_equal_data_unused_space(count, @src());
            self.incr_len(count);
        }
        pub fn decr_slice_end(self: *Self, count: IDX) void {
            assert_reference(@src());
            self.assert_count_less_equal_len(count, @src());
            self.decr_len(count);
        }
        pub fn slide_slice_lower(self: *Self, count: IDX) void {
            assert_reference(@src());
            self.assert_count_less_equal_slice_offset(count, @src());
            self.decr_root_offset(count);
        }
        pub fn slide_slice_higher(self: *Self, count: IDX) void {
            assert_reference(@src());
            self.assert_count_less_equal_data_unused_space(count, @src());
            self.incr_root_offset(count);
        }
        pub fn split_off_slice_from_start(self: *Self, count: IDX) Slice {
            assert_reference(@src());
            assert_mutable(@src());
            self.assert_count_less_equal_len(count, @src());
            const new_slice = Slice{
                .root_ptr = self.root_ptr,
                .root_cap = self.root_cap,
                .root_offset = self.root_offset,
                .data_len = count,
                .slice_offset = self.get_slice_offset(),
            };
            self.incr_root_offset(count);
            self.decr_len_unchecked(count);
            return new_slice;
        }
        pub fn split_off_slice_from_start_const(self: *Self, count: IDX) SliceConst {
            assert_reference(@src());
            self.assert_count_less_equal_len(count, @src());
            const new_slice = SliceConst{
                .root_ptr = self.root_ptr,
                .root_cap = self.root_cap,
                .root_offset = self.root_offset,
                .data_len = count,
                .slice_offset = self.get_slice_offset(),
            };
            self.incr_root_offset(count);
            self.decr_len_unchecked(count);
            return new_slice;
        }
        pub fn split_off_slice_from_end(self: *Self, count: IDX) Slice {
            assert_mutable(@src());
            self.assert_count_less_equal_len(count, @src());
            const new_slice = Slice{
                .root_ptr = self.root_ptr,
                .root_cap = self.root_cap,
                .root_offset = self.root_offset,
                .data_len = count,
                .slice_offset = self.get_slice_offset() + (self.get_len() - count),
            };
            self.decr_len_unchecked(count);
            return new_slice;
        }
        pub fn split_off_slice_from_end_const(self: *Self, count: IDX) SliceConst {
            self.assert_count_less_equal_len(count, @src());
            const new_slice = SliceConst{
                .root_ptr = self.root_ptr,
                .root_cap = self.root_cap,
                .root_offset = self.root_offset,
                .data_len = count,
                .slice_offset = self.get_slice_offset() + (self.get_len() - count),
            };
            self.decr_len_unchecked(count);
            return new_slice;
        }
        pub fn split_off_zig_slice_from_start(self: *Self, count: IDX) []ELEM {
            assert_reference(@src());
            self.assert_count_less_equal_len(count, @src());
            const new_slice = self.zig_slice(0, count);
            self.incr_root_offset(count);
            self.decr_len_unchecked(count);
            return new_slice;
        }
        pub fn split_off_zig_slice_from_start_const(self: *Self, count: IDX) []const ELEM {
            assert_reference(@src());
            self.assert_count_less_equal_len(count, @src());
            const new_slice = self.zig_slice_const(0, count);
            self.incr_root_offset(count);
            self.decr_len_unchecked(count);
            return new_slice;
        }
        pub fn split_off_zig_slice_from_end(self: *Self, count: IDX) []ELEM {
            self.assert_count_less_equal_len(count, @src());
            const new_slice = self.zig_slice(self.data_len - count, self.data_len);
            self.decr_len_unchecked(count);
            return new_slice;
        }
        pub fn split_off_zig_slice_from_end_const(self: *Self, count: IDX) []const ELEM {
            self.assert_count_less_equal_len(count, @src());
            const new_slice = self.zig_slice_const(self.data_len - count, self.data_len);
            self.decr_len_unchecked(count);
            return new_slice;
        }
        //****************
        // REVERSE/ROTATE
        //****************
        fn reverse_range_internal(self: Self, start: IDX, end_exclusive: IDX) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    switch (comptime INDEX_LAYOUT) {
                        .SERIAL_INDEXES => {
                            const tstart = self.true_idx(start);
                            const tend = self.true_idx(end_exclusive);
                            std.mem.reverse(ELEM, self.root_ptr[tstart.idx..tend.idx]);
                        },
                    }
                },
                .SPLIT_FIELDS => {
                    inline for (0..NUM_FIELDS) |fidx| {
                        const field_slice = self.field_slice_from_field_idx(fidx);
                        switch (comptime INDEX_LAYOUT) {
                            .SERIAL_INDEXES => {
                                const tstart = self.true_idx(start);
                                const tend = self.true_idx(end_exclusive);
                                std.mem.reverse(FieldTypeFidx(fidx), field_slice[tstart.idx..tend.idx]);
                            },
                        }
                    }
                },
            }
        }
        pub fn reverse_range(self: Self, start: IDX, end_exclusive: IDX) void {
            self.assert_valid_range(start, end_exclusive, @src());
            if (start == end_exclusive) return;
            self.reverse_range_internal(start, end_exclusive);
        }
        fn reverse_range_field_idx(self: Self, comptime fidx: usize, start: IDX, end_exclusive: IDX) void {
            const field_ptr = self.field_slice_from_field_idx(fidx);
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES => {
                    const tstart = self.true_idx(start);
                    const tend = self.true_idx(end_exclusive);
                    std.mem.reverse(FieldTypeFidx(fidx), field_ptr[tstart.idx..tend.idx]);
                },
            }
        }
        pub fn reverse(self: Self) void {
            self.reverse_range(0, self.data_len);
        }
        fn rotate_range_internal(self: Self, start: IDX, end_exclusive: IDX, delta: i64) void {
            assert_with_reason(end_exclusive - start <= std.math.maxInt(i64), @src(), "range is too large (end_exclusive - start > std.math.maxInt(i64))", .{});
            const len: i64 = end_exclusive - start;
            const shift: IDX = @intCast(@mod(delta, len));
            self.rotate_range_right_internal(start, end_exclusive, shift);
        }
        pub fn rotate_range(self: Self, start: IDX, end_exclusive: IDX, delta: i64) void {
            self.assert_valid_range(start, end_exclusive, @src());
            if (start == end_exclusive) return;
            self.rotate_range_internal(start, end_exclusive, delta);
        }
        pub fn rotate(self: Self, delta: i64) void {
            return self.rotate_range(0, self.data_len, delta);
        }
        fn rotate_range_right_internal(self: Self, start: IDX, end_exclusive: IDX, count: IDX) void {
            const len = end_exclusive - start;
            const shift = count % len;
            if (shift == 0) return;
            if (shift == 1) {
                self.move_one_left_displace_internal(end_exclusive - 1, start);
                return;
            }
            if (shift == len - 1) {
                self.move_one_right_displace_internal(start, end_exclusive - 1);
                return;
            }
            const boundary = end_exclusive - shift;
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    self.reverse_range_internal(start, boundary);
                    self.reverse_range_internal(boundary, end_exclusive);
                    self.reverse_range_internal(start, end_exclusive);
                },
                .SPLIT_FIELDS => {
                    inline for (0..NUM_FIELDS) |FIDX| {
                        self.reverse_range_field_idx(FIDX, start, boundary);
                        self.reverse_range_field_idx(FIDX, boundary, end_exclusive);
                        self.reverse_range_field_idx(FIDX, start, end_exclusive);
                    }
                },
            }
        }
        pub fn rotate_range_right(self: Self, start: IDX, end_exclusive: IDX, count: IDX) void {
            self.assert_valid_range(start, end_exclusive, @src());
            if (start == end_exclusive or count == 0) return;
            return self.rotate_range_right_internal(start, end_exclusive, count);
        }
        pub fn rotate_right(self: Self, count: IDX) void {
            self.rotate_range_right(0, self.data_len, count);
        }
        fn rotate_range_left_internal(self: Self, start: IDX, end_exclusive: IDX, count: IDX) void {
            const len = end_exclusive - start;
            const shift = count % len;
            if (shift == 0) return;
            if (shift == 1) {
                self.move_one_right_displace(start, end_exclusive - 1);
                return;
            }
            if (shift == len - 1) {
                self.move_one_left_displace(end_exclusive - 1, start);
                return;
            }
            const boundary = start + shift;
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    self.reverse_range_internal(start, boundary);
                    self.reverse_range_internal(boundary, end_exclusive);
                    self.reverse_range_internal(start, end_exclusive);
                },
                .SPLIT_FIELDS => {
                    inline for (0..NUM_FIELDS) |FIDX| {
                        self.reverse_range_field_idx(FIDX, start, boundary);
                        self.reverse_range_field_idx(FIDX, boundary, end_exclusive);
                        self.reverse_range_field_idx(FIDX, start, end_exclusive);
                    }
                },
            }
        }
        pub fn rotate_range_left(self: Self, start: IDX, end_exclusive: IDX, count: IDX) void {
            self.assert_valid_range(start, end_exclusive, @src());
            if (start == end_exclusive or count == 0) return;
            return self.rotate_range_left_internal(start, end_exclusive, count);
        }
        pub fn rotate_left(self: Self, count: IDX) void {
            self.rotate_range_left(0, self.data_len, count);
        }
        pub fn move_block_displace(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            if (old_start < new_start) {
                self.move_block_right_displace(old_start, old_end_exclusive, new_start);
            } else {
                self.move_block_left_displace(old_start, old_end_exclusive, new_start);
            }
        }
        //****************
        // MOVE ONE/BLOCK
        //****************
        pub fn move_block_right_displace(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            self.assert_valid_range(old_start, old_end_exclusive, @src());
            self.assert_valid_idx(new_start, @src());
            assert_with_reason(old_start <= new_start, @src(), "old start must be <= new_start to move block right, got {d} > {d}", .{ old_start, new_start });
            if (old_start == new_start or old_start == old_end_exclusive) return;
            const block_len = old_end_exclusive - old_start;
            const new_end_exclusive = new_start + block_len;
            assert_with_reason(new_end_exclusive <= self.data_len, @src(), "end of block will exceed list length, len = {d}, new_end_exclusive = {d}", .{ self.data_len, new_end_exclusive });
            self.rotate_range_left_internal(old_start, new_end_exclusive, block_len);
        }
        pub fn move_block_left_displace(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            self.assert_valid_range(old_start, old_end_exclusive, @src());
            self.assert_valid_idx(new_start, @src());
            assert_with_reason(old_start >= new_start, @src(), "old start must be >= new_start to move block left, got {d} < {d}", .{ old_start, new_start });
            if (old_start == new_start or old_start == old_end_exclusive) return;
            const block_len = old_end_exclusive - old_start;
            self.rotate_range_right_internal(new_start, old_end_exclusive, block_len);
        }
        fn move_block_overwrite_internal(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            const len = old_end_exclusive - old_start;
            const new_end_exclusive = new_start + len;
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES => {
                    const t_old_start = self.true_idx(old_start);
                    const t_old_end_exclusive = self.true_idx(old_end_exclusive);
                    const t_new_start = self.true_idx(new_start);
                    const t_new_end_exclusive = self.true_idx(new_end_exclusive);
                    switch (comptime FIELD_LAYOUT) {
                        .WHOLE_STRUCTS => {
                            @memmove(self.root_ptr[t_new_start.idx..t_new_end_exclusive.idx], self.root_ptr[t_old_start.idx..t_old_end_exclusive.idx]);
                        },
                        .SPLIT_FIELDS => {
                            inline for (0..NUM_FIELDS) |fidx| {
                                const field_slice = self.field_slice_from_field_idx(fidx);
                                @memmove(field_slice[t_new_start.idx..t_new_end_exclusive.idx], field_slice[t_old_start.idx..t_old_end_exclusive.idx]);
                            }
                        },
                    }
                },
            }
        }
        pub fn move_block_right_overwrite(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            self.assert_valid_range(old_start, old_end_exclusive, @src());
            self.assert_valid_range(new_start, new_start + (old_end_exclusive - old_start), @src());
            if (old_start == new_start or old_start == old_end_exclusive) return;
            assert_with_reason(old_start < new_start, @src(), "old start must be <= new_start to move block right, got {d} > {d}", .{ old_start, new_start });
            self.move_block_overwrite_internal(old_start, old_end_exclusive, new_start);
        }
        pub fn move_block_left_overwrite(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            self.assert_valid_range(old_start, old_end_exclusive, @src());
            self.assert_valid_range(new_start, new_start + (old_end_exclusive - old_start), @src());
            if (old_start == new_start or old_start == old_end_exclusive) return;
            assert_with_reason(old_start > new_start, @src(), "old start must be >= new_start to move block left, got {d} < {d}", .{ old_start, new_start });
            self.move_block_overwrite_internal(old_start, old_end_exclusive, new_start);
        }
        pub fn move_one_displace(self: Self, old_idx: IDX, new_idx: IDX) void {
            if (old_idx < new_idx) {
                self.move_one_right_displace(old_idx, new_idx);
            } else {
                self.move_one_left_displace(old_idx, new_idx);
            }
        }
        fn move_one_right_displace_internal(self: Self, old_idx: IDX, new_idx: IDX) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    switch (comptime INDEX_LAYOUT) {
                        .SERIAL_INDEXES => {
                            const t_old_idx = self.true_idx(old_idx);
                            const t_new_idx = self.true_idx(new_idx);
                            const temp = self.root_ptr[t_old_idx.idx];
                            @memmove(self.root_ptr[t_old_idx.idx..t_new_idx.idx], self.root_ptr[(t_old_idx.idx + 1)..(t_new_idx.idx + 1)]);
                            self.root_ptr[t_new_idx.idx] = temp;
                        },
                    }
                },
                .SPLIT_FIELDS => {
                    const t_old_idx = self.true_idx(old_idx);
                    const t_new_idx = self.true_idx(new_idx);
                    inline for (0..NUM_FIELDS) |fidx| {
                        const field_slice = self.field_slice_from_field_idx(fidx);
                        switch (comptime INDEX_LAYOUT) {
                            .SERIAL_INDEXES => {
                                const temp = field_slice[t_old_idx.idx];
                                @memmove(field_slice[t_old_idx.idx..t_new_idx.idx], field_slice[(t_old_idx.idx + 1)..(t_new_idx.idx + 1)]);
                                field_slice[t_new_idx.idx] = temp;
                            },
                        }
                    }
                },
            }
        }
        pub fn move_one_right_displace(self: Self, old_idx: IDX, new_idx: IDX) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            if (old_idx == new_idx) return;
            assert_with_reason(old_idx < new_idx, @src(), "old_idx must be <= new_idx, got {d} > {d}", .{ old_idx, new_idx });
            self.move_one_right_displace_internal(old_idx, new_idx);
        }
        fn move_one_left_displace_internal(self: Self, old_idx: IDX, new_idx: IDX) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    switch (comptime INDEX_LAYOUT) {
                        .SERIAL_INDEXES => {
                            const t_old_idx = self.true_idx(old_idx);
                            const t_new_idx = self.true_idx(new_idx);
                            const temp = self.root_ptr[t_old_idx.idx];
                            @memmove(self.root_ptr[(t_new_idx.idx + 1)..(t_old_idx.idx + 1)], self.root_ptr[t_new_idx.idx..t_old_idx.idx]);
                            self.root_ptr[t_new_idx.idx] = temp;
                        },
                    }
                },
                .SPLIT_FIELDS => {
                    const t_old_idx = self.true_idx(old_idx);
                    const t_new_idx = self.true_idx(new_idx);
                    inline for (0..NUM_FIELDS) |fidx| {
                        const field_slice = self.field_slice_from_field_idx(fidx);
                        switch (comptime INDEX_LAYOUT) {
                            .SERIAL_INDEXES => {
                                const temp = field_slice[t_old_idx.idx];
                                @memmove(field_slice[(t_new_idx.idx + 1)..(t_old_idx.idx + 1)], field_slice[t_new_idx.idx..t_old_idx.idx]);
                                field_slice[t_new_idx.idx] = temp;
                            },
                        }
                    }
                },
            }
        }
        pub fn move_one_left_displace(self: Self, old_idx: IDX, new_idx: IDX) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            if (old_idx == new_idx) return;
            assert_with_reason(old_idx > new_idx, @src(), "old_idx must be >= new_idx, got {d} < {d}", .{ old_idx, new_idx });
            self.move_one_left_displace_internal(old_idx, new_idx);
        }
        fn move_one_overwrite_true_idx(self: Self, t_old_idx: TrueIdx, t_new_idx: TrueIdx) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    self.root_ptr[t_new_idx.idx] = self.root_ptr[t_old_idx.idx];
                },
                .SPLIT_FIELDS => {
                    inline for (0..NUM_FIELDS) |fidx| {
                        const field_slice = self.field_slice_from_field_idx(fidx);
                        field_slice[t_new_idx.idx] = field_slice[t_old_idx.idx];
                    }
                },
            }
        }
        pub fn move_one_overwrite(self: Self, old_idx: IDX, new_idx: IDX) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            self.move_one_overwrite_true_idx(self.true_idx(old_idx), self.true_idx(new_idx));
        }
        fn swap_true_idx(self: Self, idx_a: TrueIdx, idx_b: TrueIdx) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    const tmp = self.root_ptr[idx_a.idx];
                    self.root_ptr[idx_a.idx] = self.root_ptr[idx_b.idx];
                    self.root_ptr[idx_b.idx] = tmp;
                },
                .SPLIT_FIELDS => {
                    inline for (0..NUM_FIELDS) |fidx| {
                        const field_slice = self.field_slice_from_field_idx(fidx);
                        const tmp = field_slice[idx_a.idx];
                        field_slice[idx_a.idx] = field_slice[idx_b.idx];
                        field_slice[idx_b.idx] = tmp;
                    }
                },
            }
        }
        pub fn swap(self: Self, idx_a: IDX, idx_b: IDX) void {
            self.assert_valid_idx(idx_a, @src());
            self.assert_valid_idx(idx_b, @src());
            self.swap_true_idx(self.true_idx(idx_a), self.true_idx(idx_b));
        }
        pub fn swap_already_have_b(self: Self, idx_a: IDX, idx_b: IDX, val_b: ELEM) void {
            self.assert_valid_idx(idx_a, @src());
            self.assert_valid_idx(idx_b, @src());
            const tidx_a = self.true_idx(idx_a);
            const tidx_b = self.true_idx(idx_b);
            self.move_one_overwrite_true_idx(tidx_a, tidx_b);
            self.set_true_idx(tidx_a, val_b);
        }
        //****************
        // SHUFFLE
        //****************
        fn shuffle_range_biased_internal(self: Self, start: IDX, end_exclusive: IDX, iterations: IDX, rand: Random) void {
            const len = end_exclusive - start;
            if (len <= 1) return;
            if (len == 2) {
                if (rand.boolean()) {
                    self.swap_true_idx(self.true_idx(start), self.true_idx(end_exclusive - 1));
                }
                return;
            }
            var n: IDX = 0;
            const first_idx = rand.intRangeLessThan(IDX, start, end_exclusive);
            var empty_idx: IDX = first_idx;
            var empty_true_idx: TrueIdx = self.true_idx(first_idx);
            const first_val = self.get_true_idx(empty_true_idx);
            while (n < iterations) : (n += 1) {
                const move_idx = find_different_idx: {
                    while (true) {
                        const possible_different_idx = rand.intRangeLessThan(IDX, start, end_exclusive);
                        if (possible_different_idx != empty_idx) break :find_different_idx possible_different_idx;
                    }
                };
                const move_true_idx: TrueIdx = self.true_idx(move_idx);
                self.move_one_overwrite_true_idx(move_true_idx, empty_true_idx);
                empty_idx = move_idx;
                empty_true_idx = move_true_idx;
            }
            self.set_true_idx(empty_true_idx, first_val);
        }
        pub fn shuffle_range_biased(self: Self, start: IDX, end_exclusive: IDX, iterations: IDX, rand: Random) void {
            self.assert_valid_range(start, end_exclusive, @src());
            if (iterations == 0 or start == end_exclusive) return;
            self.shuffle_range_biased_internal(start, end_exclusive, iterations, rand);
        }
        pub fn shuffle_biased(self: Self, iterations: IDX, rand: Random) void {
            self.shuffle_range_biased(0, self.data_len, iterations, rand);
        }
        fn shuffle_range_unbiased_internal(self: Self, start: IDX, end_exclusive: IDX, min_iterations: IDX, rand: Random) void {
            self.assert_valid_range(start, end_exclusive, @src());
            const max_len = end_exclusive - start;
            if (max_len <= 1) return;
            var n: IDX = 0;
            // Do full Fisher-Yates shuffles until at least min_iterations items have been swapped
            while (n < min_iterations) {
                var len = max_len;
                while (len > 1) {
                    const start_plus_len = start + len;
                    const last_idx = start_plus_len - 1;
                    const rand_idx = rand.intRangeLessThan(IDX, start, start_plus_len);
                    if (last_idx != rand_idx) {
                        self.swap(last_idx, rand_idx);
                    }
                    n += 1;
                    len -= 1;
                }
            }
        }
        pub fn shuffle_range_unbiased(self: Self, start: IDX, end_exclusive: IDX, iterations: IDX, rand: Random) void {
            self.assert_valid_range(start, end_exclusive, @src());
            if (iterations == 0 or start == end_exclusive) return;
            self.shuffle_range_unbiased_internal(start, end_exclusive, iterations, rand);
        }
        pub fn shuffle_unbiased(self: Self, iterations: IDX, rand: Random) void {
            self.shuffle_range_unbiased(0, self.data_len, iterations, rand);
        }
        pub fn shuffle_range_unbiased_once(self: Self, start: IDX, end_exclusive: IDX, rand: Random) void {
            self.assert_valid_range(start, end_exclusive, @src());
            self.shuffle_range_unbiased_internal(start, end_exclusive, 1, rand);
        }
        pub fn shuffle_unbiased_once(self: Self, rand: Random) void {
            self.shuffle_range_unbiased(0, self.data_len, 1, rand);
        }
        //**************
        // ALLOC/REALLOC
        //**************
        fn realloc_internal(self: *Self, new_exact_cap: IDX, alloc: Allocator) void {
            assert_owned_allocated(@src());
            self.data_len = @min(self.data_len, new_exact_cap);
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    if (self.data_len > 0) {
                        if (alloc.remap(self.root_ptr[0..self.root_cap], new_exact_cap)) |new_mem| {
                            self.root_ptr = new_mem.ptr;
                            self.root_cap = @intCast(new_mem.len);
                            return;
                        }
                    }
                    const new_mem = alloc.alloc(ELEM, new_exact_cap) catch |e| assert_unreachable_err(@src(), e);
                    if (self.data_len > 0) {
                        @memcpy(new_mem[0..self.data_len], self.root_ptr[0..self.data_len]);
                    }
                    if (self.root_cap > 0) {
                        alloc.free(self.root_ptr[0..self.root_cap]);
                    }
                    self.root_ptr = new_mem.ptr;
                    self.root_cap = @intCast(new_mem.len);
                },
                .SPLIT_FIELDS => {
                    const old_byte_cap = end_stride() * self.root_cap;
                    const new_byte_cap = end_stride() * new_exact_cap;
                    // remap would require doing a @memmove on each field region to correctly reposition them,
                    // so might as well just alloc and go for the potentially faster @memcpy
                    const new_mem = alloc.alignedAlloc(u8, .fromByteUnits(@alignOf(ELEM)), new_byte_cap) catch |e| assert_unreachable_err(@src(), e);
                    if (self.data_len > 0) {
                        inline for (ORDERED_FIELD_OFFSETS[0..NUM_FIELDS], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                            const field_start_offset_old = offset * self.root_cap;
                            const field_start_offset_new = offset * new_exact_cap;
                            const field_ptr_old: [*]t = @ptrCast(@alignCast(self.root_ptr + field_start_offset_old));
                            const field_ptr_new: [*]t = @ptrCast(@alignCast(new_mem.ptr + field_start_offset_new));
                            @memcpy(field_ptr_new[0..self.data_len], field_ptr_old[0..self.data_len]);
                        }
                    }
                    if (self.root_cap > 0) {
                        alloc.free(self.root_ptr[0..old_byte_cap]);
                    }
                    self.root_ptr = @alignCast(new_mem.ptr);
                    self.root_cap = new_exact_cap;
                },
            }
        }
        pub fn grow_capacity_if_needed(self: *Self, need_capacity: IDX, growth: Growth, alloc: Allocator) void {
            if (self.root_cap < need_capacity) {
                const adjusted_need_capacity = growth.calc(need_capacity);
                self.realloc_internal(adjusted_need_capacity, alloc);
            }
        }
        pub fn grow_capacity_if_needed_for_n_more_elems(self: *Self, count: IDX, growth: Growth, alloc: Allocator) void {
            const need_cap = self.data_len + count;
            self.grow_capacity_if_needed(need_cap, growth, alloc);
        }
        pub fn shrink_capacity_to_at_most(self: *Self, new_max_cap: IDX, alloc: Allocator) void {
            if (self.root_cap > new_max_cap) {
                self.realloc_internal(new_max_cap, alloc);
            }
        }
        pub fn shrink_capacity_reserve_at_most_n_free_space(self: *Self, at_most_n_free_space: IDX, alloc: Allocator) void {
            const curr_free_space = self.root_cap - self.data_len;
            if (curr_free_space > at_most_n_free_space) {
                const new_cap = self.data_len + at_most_n_free_space;
                self.realloc_internal(new_cap, alloc);
            }
        }
        pub fn resize_capacity_exact(self: *Self, exact_cap: IDX, alloc: Allocator) void {
            if (self.root_cap == exact_cap) return;
            self.realloc_internal(exact_cap, alloc);
        }
        fn free_internal(self: *Self, alloc: Allocator) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    alloc.free(self.root_ptr[0..self.root_cap]);
                    self.root_ptr = undefined;
                    self.data_len = 0;
                    self.root_cap = 0;
                },
                .SPLIT_FIELDS => {
                    const byte_cap = end_stride() * self.root_cap;
                    alloc.free(self.root_ptr[0..byte_cap]);
                    self.root_ptr = undefined;
                    self.data_len = 0;
                    self.root_cap = 0;
                },
            }
        }
        pub fn free(self: *Self, alloc: Allocator) void {
            assert_owned_allocated(@src());
            assert_with_reason(self.root_cap > 0, @src(), "cannot free zero-capacity memory", .{});
            self.free_internal(alloc);
        }
        pub fn free_if_non_zero(self: *Self, alloc: Allocator) void {
            assert_owned_allocated(@src());
            if (self.root_cap > 0) {
                self.free_internal(alloc);
            }
        }
        pub fn free_if_owned(self: *Self, alloc: Allocator) void {
            if (comptime IS_OWNED_ALLOCATED) {
                assert_with_reason(self.root_cap > 0, @src(), "cannot free zero-capacity memory", .{});
                self.free_internal(alloc);
            }
        }
        pub fn free_if_owned_and_non_zero(self: *Self, alloc: Allocator) void {
            if (comptime IS_OWNED_ALLOCATED) {
                if (self.root_cap > 0) {
                    self.free_internal(alloc);
                }
            }
        }
        //*********
        // COPY TO
        //*********
        pub fn copy_self_range_to_dest_range(self: Self, self_start: IDX, self_end_exclusive: IDX, dest_: anytype, dest_start: anytype) void {
            self.assert_valid_range(self_start, self_end_exclusive, @src());
            if (comptime @sizeOf(ELEM) == 0) return;
            var remaining_count = self_end_exclusive - self_start;
            if (remaining_count == 0) return;
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            const DEST = @TypeOf(dest);
            DEST.assert_mutable(@src());
            dest.assert_idx_plus_count_less_equal_len(@intCast(dest_start), @intCast(remaining_count), @src());
            const dest_end_exclusive: @TypeOf(dest_start) = dest_start + num_cast(remaining_count, @TypeOf(dest_start));
            dest.assert_valid_idx_or_len(dest_end_exclusive, @src());
            if (comptime (FIELD_LAYOUT == .WHOLE_STRUCTS and DEST.GOOLIB_LIST_DEF.FIELD_LAYOUT == .WHOLE_STRUCTS) or (FIELD_LAYOUT == .SPLIT_FIELDS and DEST.GOOLIB_LIST_DEF.FIELD_LAYOUT == .SPLIT_FIELDS)) {
                var remaining_self = self.slice_const(self_start, self_end_exclusive);
                var remaining_dest = dest.slice(dest_start, dest_end_exclusive);
                while (remaining_count > 0) {
                    const contiguous_self = remaining_self.contiguous_indexes_after_index_inclusive_max(0, remaining_count);
                    const contiguous_dest: IDX = @intCast(remaining_dest.contiguous_indexes_after_index_inclusive_max(0, remaining_count));
                    const copy_len = @min(contiguous_self, contiguous_dest);
                    switch (comptime FIELD_LAYOUT) {
                        .WHOLE_STRUCTS => {
                            const copy_src = remaining_self.split_off_zig_slice_from_start_const(copy_len);
                            const copy_dst = remaining_dest.split_off_zig_slice_from_start(copy_len);
                            if (memory_overlaps(ELEM, copy_src, copy_dst)) {
                                @memmove(copy_dst, copy_src);
                            } else {
                                @memcpy(copy_dst, copy_src);
                            }
                        },
                        .SPLIT_FIELDS => {
                            var mem_does_overlap: bool = undefined;
                            {
                                const copy_src_ptr: [*]FieldTypeFidx(0) = @ptrCast(remaining_self.get_field_ptr_const(@enumFromInt(0), 0));
                                const copy_dst_ptr: [*]FieldTypeFidx(0) = @ptrCast(remaining_dest.get_field_ptr(@enumFromInt(0), 0));
                                const copy_src = copy_src_ptr[0..copy_len];
                                const copy_dst = copy_dst_ptr[0..copy_len];
                                mem_does_overlap = memory_overlaps(FieldTypeFidx(0), copy_src, copy_dst);
                                if (mem_does_overlap) {
                                    @memmove(copy_dst, copy_src);
                                } else {
                                    @memcpy(copy_dst, copy_src);
                                }
                            }
                            inline for (1..NUM_FIELDS) |FIDX| {
                                const copy_src_ptr: [*]FieldTypeFidx(FIDX) = @ptrCast(remaining_self.get_field_ptr_const(@enumFromInt(FIDX), 0));
                                const copy_dst_ptr: [*]FieldTypeFidx(FIDX) = @ptrCast(remaining_dest.get_field_ptr(@enumFromInt(FIDX), 0));
                                const copy_src = copy_src_ptr[0..copy_len];
                                const copy_dst = copy_dst_ptr[0..copy_len];
                                if (mem_does_overlap) {
                                    @memmove(copy_dst, copy_src);
                                } else {
                                    @memcpy(copy_dst, copy_src);
                                }
                            }
                            remaining_self.incr_slice_start(copy_len);
                            remaining_dest.incr_slice_start(copy_len);
                        },
                    }
                    remaining_count -= copy_len;
                }
            } else {
                var read_idx = self_start;
                var write_idx = dest_start;
                while (remaining_count > 0) {
                    dest.set(write_idx, self.get(read_idx));
                    read_idx += 1;
                    write_idx += 1;
                    remaining_count -= 1;
                }
            }
        }
        pub fn copy_self_range_to_dest_start(self: Self, self_start: IDX, self_end_exclusive: IDX, dest_: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            self.copy_self_range_to_dest_range(self_start, self_end_exclusive, dest, 0);
        }
        pub fn copy_self_range_to_dest_end(self: Self, self_start: IDX, self_end_exclusive: IDX, dest_: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            self.assert_valid_range(self_start, self_end_exclusive, @src());
            const count = num_cast(self_end_exclusive - self_start, @TypeOf(dest.data_len));
            dest.assert_count_less_equal_len(count, @src());
            self.copy_self_range_to_dest_range(self_start, self_end_exclusive, dest, dest.data_len - count);
        }
        pub fn copy_self_start_to_dest_range(self: Self, count: IDX, dest_: anytype, dest_start: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            self.copy_self_range_to_dest_range(0, count, dest, dest_start);
        }
        pub fn copy_self_start_to_dest_start(self: Self, count: IDX, dest_: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            self.copy_self_range_to_dest_range(0, count, dest, 0);
        }
        pub fn copy_self_start_to_dest_end(self: Self, count: IDX, dest_: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            const cast_count = num_cast(count, @TypeOf(dest.data_len));
            dest.assert_count_less_equal_len(cast_count, @src());
            self.copy_self_range_to_dest_range(0, count, dest, dest.data_len - cast_count);
        }
        pub fn copy_self_end_to_dest_range(self: Self, count: IDX, dest_: anytype, dest_start: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            self.assert_count_less_equal_len(count, @src());
            self.copy_self_range_to_dest_range(self.data_len - count, self.data_len, dest, dest_start);
        }
        pub fn copy_self_end_to_dest_start(self: Self, count: IDX, dest_: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            self.assert_count_less_equal_len(count, @src());
            self.copy_self_range_to_dest_range(self.data_len - count, self.data_len, dest, 0);
        }
        pub fn copy_self_end_to_dest_end(self: Self, count: IDX, dest_: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            const cast_count = num_cast(count, @TypeOf(dest.data_len));
            dest.assert_count_less_equal_len(cast_count, @src());
            self.assert_count_less_equal_len(count, @src());
            self.copy_self_range_to_dest_range(self.data_len - count, self.data_len, dest, dest.data_len - cast_count);
        }
        pub fn copy_entire_self_to_dest_range(self: Self, dest_: anytype, dest_start: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            self.copy_self_range_to_dest_range(0, self.data_len, dest, dest_start);
        }
        pub fn copy_entire_self_to_dest_start(self: Self, dest_: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            self.copy_self_range_to_dest_range(0, self.data_len, dest, 0);
        }
        pub fn copy_entire_self_to_dest_end(self: Self, dest_: anytype) void {
            const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
            const cast_len = num_cast(self.data_len, @TypeOf(dest.data_len));
            dest.assert_count_less_equal_len(cast_len, @src());
            self.copy_self_range_to_dest_range(0, self.data_len, dest, dest.data_len - cast_len);
        }
        //************s
        // APPEND ONE
        //************
        fn append_idxs_internal(self: *Self, n: IDX, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth) IDX {
            switch (ALLOC) {
                .ASSUME_CAP => {
                    assert_with_reason(self.data_len + n <= self.root_cap, @src(), "appending {d} slots would exceed capacity, len = {d}, cap = {d}", .{ n, self.data_len, self.root_cap });
                },
                .REALLOC => {
                    self.grow_capacity_if_needed_for_n_more_elems(n, if (GROWTH_MODE == .CUSTOM_GROWTH) growth else Growth.GROW_BY_25_PERCENT, alloc);
                },
            }
            const first_idx = self.data_len;
            self.data_len += n;
            return first_idx;
        }
        fn append_one_slot_internal(self: *Self, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(ElemPtr, IDX) {
            var first_new_idx: IDX = undefined;
            if (comptime IS_REFERENCE) {
                first_new_idx = self.data_len;
                self.incr_slice_end(1);
            } else {
                first_new_idx = self.append_idxs_internal(1, ALLOC, alloc, GROWTH_MODE, growth);
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {},
                }
            }
            return RETURN.ret_val(ElemPtr, IDX, if (comptime RETURN.returns_ptr()) self.get_ptr(first_new_idx) else undefined, first_new_idx);
        }
        pub inline fn append_one_slot_assume_cap_get_ptr(self: *Self) ElemPtr {
            return self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn append_one_slot_with_growth_get_ptr(self: *Self, growth: Growth, alloc: Allocator) ElemPtr {
            return self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn append_one_slot_get_ptr(self: *Self, alloc: Allocator) ElemPtr {
            return self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn append_one_slot_assume_cap_get_ptr_idx(self: *Self) struct { ElemPtr, IDX } {
            return self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE_IDX);
        }
        pub inline fn append_one_slot_with_growth_get_ptr_idx(self: *Self, growth: Growth, alloc: Allocator) struct { ElemPtr, IDX } {
            return self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE_IDX);
        }
        pub inline fn append_one_slot_get_ptr_idx(self: *Self, alloc: Allocator) struct { ElemPtr, IDX } {
            return self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE_IDX);
        }
        pub inline fn append_one_slot_assume_cap_get_idx(self: *Self) IDX {
            return self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
        }
        pub inline fn append_one_slot_with_growth_get_idx(self: *Self, growth: Growth, alloc: Allocator) IDX {
            return self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
        }
        pub inline fn append_one_slot_get_idx(self: *Self, alloc: Allocator) IDX {
            return self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
        }
        pub inline fn append_one_slot_assume_cap(self: *Self) void {
            return self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn append_one_slot_with_growth(self: *Self, growth: Growth, alloc: Allocator) void {
            return self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn append_one_slot(self: *Self, alloc: Allocator) void {
            return self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        pub fn append_one_assume_cap_get_ptr(self: *Self, val: ELEM) ElemPtr {
            const elem_ptr = self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub fn append_one_with_growth_get_ptr(self: *Self, val: ELEM, growth: Growth, alloc: Allocator) ElemPtr {
            const elem_ptr = self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub fn append_one_get_ptr(self: *Self, val: ELEM, alloc: Allocator) ElemPtr {
            const elem_ptr = self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub fn append_one_assume_cap_get_ptr_idx(self: *Self, val: ELEM) struct { ElemPtr, IDX } {
            const elem_ptr, const slot_idx = self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE_IDX);
            assign_val_to_elem_ptr(elem_ptr, val);
            return .{ elem_ptr, slot_idx };
        }
        pub fn append_one_with_growth_get_ptr_idx(self: *Self, val: ELEM, growth: Growth, alloc: Allocator) struct { ElemPtr, IDX } {
            const elem_ptr, const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE_IDX);
            assign_val_to_elem_ptr(elem_ptr, val);
            return .{ elem_ptr, slot_idx };
        }
        pub fn append_one_get_ptr_idx(self: *Self, val: ELEM, alloc: Allocator) struct { ElemPtr, IDX } {
            const elem_ptr, const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE_IDX);
            assign_val_to_elem_ptr(elem_ptr, val);
            return .{ elem_ptr, slot_idx };
        }
        pub fn append_one_assume_cap_get_idx(self: *Self, val: ELEM) IDX {
            const slot_idx = self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
            return slot_idx;
        }
        pub fn append_one_with_growth_get_idx(self: *Self, val: ELEM, growth: Growth, alloc: Allocator) IDX {
            const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
            return slot_idx;
        }
        pub fn append_one_get_idx(self: *Self, val: ELEM, alloc: Allocator) IDX {
            const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
            return slot_idx;
        }
        pub fn append_one_assume_cap(self: *Self, val: ELEM) void {
            const slot_idx = self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        pub fn append_one_with_growth(self: *Self, val: ELEM, growth: Growth, alloc: Allocator) void {
            const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        pub fn append_one(self: *Self, val: ELEM, alloc: Allocator) void {
            const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        //*************
        // APPEND MANY
        //*************
        fn append_many_slots_internal(self: *Self, count: IDX, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(Slice, IDX) {
            var first_new_idx: IDX = undefined;
            if (comptime IS_REFERENCE) {
                first_new_idx = self.data_len;
                self.incr_slice_end(count);
            } else {
                first_new_idx = self.append_idxs_internal(count, ALLOC, alloc, GROWTH_MODE, growth);
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {},
                }
            }
            return RETURN.ret_val(Slice, IDX, if (comptime RETURN.returns_ptr()) self.slice(first_new_idx, self.data_len) else undefined, first_new_idx);
        }
        pub inline fn append_many_slots_assume_cap_get_slice(self: *Self, count: IDX) Slice {
            return self.append_many_slots_internal(count, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn append_many_slots_with_growth_get_slice(self: *Self, count: IDX, growth: Growth, alloc: Allocator) Slice {
            return self.append_many_slots_internal(count, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn append_many_slots_get_slice(self: *Self, count: IDX, alloc: Allocator) Slice {
            return self.append_many_slots_internal(count, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn append_many_slots_assume_cap_get_slice_idx(self: *Self, count: IDX) struct { Slice, IDX } {
            return self.append_many_slots_internal(count, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE_IDX);
        }
        pub inline fn append_many_slots_with_growth_get_slice_idx(self: *Self, count: IDX, growth: Growth, alloc: Allocator) struct { Slice, IDX } {
            return self.append_many_slots_internal(count, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE_IDX);
        }
        pub inline fn append_many_slots_get_slice_idx(self: *Self, count: IDX, alloc: Allocator) struct { Slice, IDX } {
            return self.append_many_slots_internal(count, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE_IDX);
        }
        pub inline fn append_many_slots_assume_cap_get_idx(self: *Self, count: IDX) IDX {
            return self.append_many_slots_internal(count, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
        }
        pub inline fn append_many_slots_with_growth_get_idx(self: *Self, count: IDX, growth: Growth, alloc: Allocator) IDX {
            return self.append_many_slots_internal(count, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
        }
        pub inline fn append_many_slots_get_idx(self: *Self, count: IDX, alloc: Allocator) IDX {
            return self.append_many_slots_internal(count, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
        }
        pub inline fn append_many_slots_assume_cap(self: *Self, count: IDX) void {
            return self.append_many_slots_internal(count, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn append_many_slots_with_growth(self: *Self, count: IDX, growth: Growth, alloc: Allocator) void {
            return self.append_many_slots_internal(count, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn append_many_slots(self: *Self, count: IDX, alloc: Allocator) void {
            return self.append_many_slots_internal(count, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        fn append_many_internal(self: *Self, vals_: anytype, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(Slice, IDX) {
            const vals = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(vals_);
            const vals_len = vals.get_len();
            if (comptime ALLOC == .REALLOC and Assert.SHOULD_ASSERT) {
                if (list_memory_overlaps(self, vals)) {
                    self.assert_count_less_equal_data_unused_space_for_overlapping_copy(@intCast(vals_len), @src());
                }
            }
            const appended_slice, const first_new_idx = self.append_many_slots_internal(@intCast(vals_len), ALLOC, alloc, GROWTH_MODE, growth, .RETURN_PTR_OR_SLICE_IDX);
            vals.copy_entire_self_to_dest_start(appended_slice);
            return RETURN.ret_val(Slice, IDX, if (comptime RETURN.returns_ptr()) appended_slice else undefined, first_new_idx);
        }
        pub inline fn append_many_assume_cap_get_slice(self: *Self, vals_: anytype) Slice {
            return self.append_many_internal(vals_, .ASSUME_CAP, dummy_alloc, .CUSTOM_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn append_many_with_growth_get_slice(self: *Self, vals_: anytype, growth: Growth, alloc: Allocator) Slice {
            return self.append_many_internal(vals_, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn append_many_get_slice(self: *Self, vals_: anytype, alloc: Allocator) Slice {
            return self.append_many_internal(vals_, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn append_many_assume_cap_get_ptr_idx(self: *Self, vals_: anytype) struct { Slice, IDX } {
            return self.append_many_internal(vals_, .ASSUME_CAP, dummy_alloc, .CUSTOM_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE_IDX);
        }
        pub inline fn append_many_with_growth_get_ptr_idx(self: *Self, vals_: anytype, growth: Growth, alloc: Allocator) struct { Slice, IDX } {
            return self.append_many_internal(vals_, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE_IDX);
        }
        pub inline fn append_many_get_ptr_idx(self: *Self, vals_: anytype, alloc: Allocator) struct { Slice, IDX } {
            return self.append_many_internal(vals_, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE_IDX);
        }
        pub inline fn append_many_assume_cap_get_idx(self: *Self, vals_: anytype) IDX {
            return self.append_many_internal(vals_, .ASSUME_CAP, dummy_alloc, .CUSTOM_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
        }
        pub inline fn append_many_with_growth_get_idx(self: *Self, vals_: anytype, growth: Growth, alloc: Allocator) IDX {
            return self.append_many_internal(vals_, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
        }
        pub inline fn append_many_get_idx(self: *Self, vals_: anytype, alloc: Allocator) IDX {
            return self.append_many_internal(vals_, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
        }
        pub inline fn append_many_assume_cap(self: *Self, vals_: anytype) void {
            return self.append_many_internal(vals_, .ASSUME_CAP, dummy_alloc, .CUSTOM_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn append_many_with_growth(self: *Self, vals_: anytype, growth: Growth, alloc: Allocator) void {
            return self.append_many_internal(vals_, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn append_many(self: *Self, vals_: anytype, alloc: Allocator) void {
            return self.append_many_internal(vals_, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }

        //*************
        // PREPEND ONE
        //*************
        fn prepend_one_slot_internal(self: *Self, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(ElemPtr, IDX) {
            if (comptime IS_REFERENCE) {
                self.decr_slice_start(1);
            } else {
                const first_appended_idx = self.append_idxs_internal(1, ALLOC, alloc, GROWTH_MODE, growth);
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {
                        self.move_block_right_overwrite(0, first_appended_idx, 1);
                    },
                }
            }
            return RETURN.ret_val(ElemPtr, IDX, if (comptime RETURN.returns_ptr()) self.get_ptr(0) else undefined, 0);
        }
        pub inline fn prepend_one_slot_assume_cap_get_ptr(self: *Self) ElemPtr {
            return self.prepend_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn prepend_one_slot_with_growth_get_ptr(self: *Self, growth: Growth, alloc: Allocator) ElemPtr {
            return self.prepend_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn prepend_one_slot_get_ptr(self: *Self, alloc: Allocator) ElemPtr {
            return self.prepend_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn prepend_one_slot_assume_cap(self: *Self) void {
            return self.prepend_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn prepend_one_slot_with_growth(self: *Self, growth: Growth, alloc: Allocator) void {
            return self.prepend_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn prepend_one_slot(self: *Self, alloc: Allocator) void {
            return self.prepend_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        pub fn prepend_one_assume_cap_get_ptr(self: *Self, val: ELEM) ElemPtr {
            const elem_ptr = self.prepend_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub fn prepend_one_with_growth_get_ptr(self: *Self, val: ELEM, growth: Growth, alloc: Allocator) ElemPtr {
            const elem_ptr = self.prepend_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub fn prepend_one_get_ptr(self: *Self, val: ELEM, alloc: Allocator) ElemPtr {
            const elem_ptr = self.prepend_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub fn prepend_one_assume_cap(self: *Self, val: ELEM) void {
            self.prepend_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
            self.set_true_idx(self.true_idx(0), val);
        }
        pub fn prepend_one_with_growth(self: *Self, val: ELEM, growth: Growth, alloc: Allocator) void {
            self.prepend_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
            self.set_true_idx(self.true_idx(0), val);
        }
        pub fn prepend_one(self: *Self, val: ELEM, alloc: Allocator) void {
            self.prepend_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
            self.set_true_idx(self.true_idx(0), val);
        }
        //**************
        // PREPEND MANY
        //**************
        fn prepend_many_slots_internal(self: *Self, count: IDX, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(Slice, IDX) {
            if (count > 0) {
                if (comptime IS_REFERENCE) {
                    self.insert_many_slots_internal(0, count, ALLOC, alloc, GROWTH_MODE, growth, RETURN);
                } else {
                    const first_appended_idx = self.append_idxs_internal(count, ALLOC, alloc, GROWTH_MODE, growth);
                    switch (comptime INDEX_LAYOUT) {
                        .SERIAL_INDEXES => {
                            self.move_block_right_overwrite(0, first_appended_idx, count);
                        },
                    }
                }
            }
            return RETURN.ret_val(Slice, IDX, if (comptime RETURN.returns_ptr()) self.slice(0, count) else undefined, 0);
        }
        pub inline fn prepend_many_slots_assume_cap_get_slice(self: *Self, count: IDX) Slice {
            return self.prepend_many_slots_internal(count, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn prepend_many_slots_with_growth_get_slice(self: *Self, count: IDX, growth: Growth, alloc: Allocator) Slice {
            return self.prepend_many_slots_internal(count, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn prepend_many_slots_get_slice(self: *Self, count: IDX, alloc: Allocator) Slice {
            return self.prepend_many_slots_internal(count, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn prepend_many_slots_assume_cap(self: *Self, count: IDX) void {
            return self.prepend_many_slots_internal(count, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn prepend_many_slots_with_growth(self: *Self, count: IDX, growth: Growth, alloc: Allocator) void {
            return self.prepend_many_slots_internal(count, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn prepend_many_slots(self: *Self, count: IDX, alloc: Allocator) void {
            return self.prepend_many_slots_internal(count, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        fn prepend_many_internal(self: *Self, vals_: anytype, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(Slice, IDX) {
            const vals = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(vals_);
            const vals_len = vals.get_len();
            if (comptime ALLOC == .REALLOC and Assert.SHOULD_ASSERT) {
                if (list_memory_overlaps(self, vals)) {
                    self.assert_count_less_equal_data_unused_space_for_overlapping_copy(@intCast(vals_len), @src());
                }
            }
            const prepended_slice = self.prepend_many_slots_internal(@intCast(vals_len), ALLOC, alloc, GROWTH_MODE, growth, .RETURN_PTR_OR_SLICE);
            vals.copy_entire_self_to_dest_start(prepended_slice);
            return RETURN.ret_val(Slice, IDX, if (comptime RETURN.returns_ptr()) prepended_slice else undefined, 0);
        }
        pub inline fn prepend_many_assume_cap_get_slice(self: *Self, vals_: anytype) Slice {
            return self.prepend_many_internal(vals_, .ASSUME_CAP, dummy_alloc, .CUSTOM_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn prepend_many_with_growth_get_slice(self: *Self, vals_: anytype, growth: Growth, alloc: Allocator) Slice {
            return self.prepend_many_internal(vals_, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn prepend_many_get_slice(self: *Self, vals_: anytype, alloc: Allocator) Slice {
            return self.prepend_many_internal(vals_, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn prepend_many_assume_cap(self: *Self, vals_: anytype) void {
            return self.prepend_many_internal(vals_, .ASSUME_CAP, dummy_alloc, .CUSTOM_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn prepend_many_with_growth(self: *Self, vals_: anytype, growth: Growth, alloc: Allocator) void {
            return self.prepend_many_internal(vals_, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn prepend_many(self: *Self, vals_: anytype, alloc: Allocator) void {
            return self.prepend_many_internal(vals_, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        //**************
        // INSERT ONE
        //**************
        fn insert_one_slot_internal(self: *Self, idx: IDX, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(ElemPtr, IDX) {
            if (idx == self.data_len) {
                return self.append_one_slot_internal(ALLOC, alloc, GROWTH_MODE, growth, RETURN);
            } else if (IS_OWNED and idx == 0) {
                self.assert_valid_idx(idx, @src());
                return self.prepend_one_slot_internal(ALLOC, alloc, GROWTH_MODE, growth, RETURN);
            } else {
                self.assert_valid_idx(idx, @src());
                var first_appended_idx: IDX = undefined;
                if (comptime IS_REFERENCE) {
                    first_appended_idx = self.data_len;
                    self.incr_slice_end(1);
                } else {
                    first_appended_idx = self.append_idxs_internal(1, ALLOC, alloc, GROWTH_MODE, growth);
                }
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {
                        self.move_block_right_overwrite(idx, first_appended_idx, idx + 1);
                    },
                }
                return RETURN.ret_val(ElemPtr, IDX, if (comptime RETURN.returns_ptr()) self.get_ptr(idx) else undefined, idx);
            }
        }
        pub inline fn insert_one_slot_assume_cap_get_ptr(self: *Self, idx: IDX) ElemPtr {
            return self.insert_one_slot_internal(idx, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn insert_one_slot_with_growth_get_ptr(self: *Self, idx: IDX, growth: Growth, alloc: Allocator) ElemPtr {
            return self.insert_one_slot_internal(idx, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn insert_one_slot_get_ptr(self: *Self, idx: IDX, alloc: Allocator) ElemPtr {
            return self.insert_one_slot_internal(idx, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn insert_one_slot_assume_cap(self: *Self, idx: IDX) void {
            return self.insert_one_slot_internal(idx, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn insert_one_slot_with_growth(self: *Self, idx: IDX, growth: Growth, alloc: Allocator) void {
            return self.insert_one_slot_internal(idx, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn insert_one_slot(self: *Self, idx: IDX, alloc: Allocator) void {
            return self.insert_one_slot_internal(idx, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        pub fn insert_one_assume_cap_get_ptr(self: *Self, idx: IDX, val: ELEM) ElemPtr {
            const elem_ptr = self.insert_one_slot_internal(idx, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub fn insert_one_with_growth_get_ptr(self: *Self, idx: IDX, val: ELEM, growth: Growth, alloc: Allocator) ElemPtr {
            const elem_ptr = self.insert_one_slot_internal(idx, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub fn insert_one_get_ptr(self: *Self, idx: IDX, val: ELEM, alloc: Allocator) ElemPtr {
            const elem_ptr = self.insert_one_slot_internal(idx, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub fn insert_one_assume_cap(self: *Self, idx: IDX, val: ELEM) void {
            const slot_idx = self.insert_one_slot_internal(idx, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        pub fn insert_one_with_growth(self: *Self, idx: IDX, val: ELEM, growth: Growth, alloc: Allocator) void {
            const slot_idx = self.insert_one_slot_internal(idx, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        pub fn insert_one(self: *Self, idx: IDX, val: ELEM, alloc: Allocator) void {
            const slot_idx = self.insert_one_slot_internal(idx, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        //**************
        // INSERT MANY
        //**************
        fn insert_many_slots_internal(self: *Self, idx: IDX, count: IDX, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(Slice, IDX) {
            if (idx == self.data_len) {
                return self.append_many_slots_internal(count, ALLOC, alloc, GROWTH_MODE, growth, RETURN);
            } else if (IS_OWNED and idx == 0) {
                self.assert_valid_idx(idx, @src());
                return self.prepend_many_slots_internal(count, ALLOC, alloc, GROWTH_MODE, growth, RETURN);
            } else {
                self.assert_valid_idx(idx, @src());
                const end_idx_exclusive = idx + count;
                var first_appended_idx: IDX = undefined;
                if (comptime IS_REFERENCE) {
                    first_appended_idx = self.data_len;
                    self.incr_slice_end(count);
                } else {
                    first_appended_idx = self.append_idxs_internal(count, ALLOC, alloc, GROWTH_MODE, growth);
                }
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {
                        self.move_block_overwrite_internal(idx, first_appended_idx, end_idx_exclusive);
                    },
                }
                return RETURN.ret_val(Slice, IDX, if (comptime RETURN.returns_ptr()) self.slice(idx, end_idx_exclusive) else undefined, idx);
            }
        }
        pub inline fn insert_many_slots_assume_cap_get_slice(self: *Self, idx: IDX, count: IDX) Slice {
            return self.insert_many_slots_internal(idx, count, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn insert_many_slots_with_growth_get_slice(self: *Self, idx: IDX, count: IDX, growth: Growth, alloc: Allocator) Slice {
            return self.insert_many_slots_internal(idx, count, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn insert_many_slots_get_slice(self: *Self, idx: IDX, count: IDX, alloc: Allocator) Slice {
            return self.insert_many_slots_internal(idx, count, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn insert_many_slots_assume_cap(self: *Self, idx: IDX, count: IDX) void {
            return self.insert_many_slots_internal(idx, count, .ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn insert_many_slots_with_growth(self: *Self, idx: IDX, count: IDX, growth: Growth, alloc: Allocator) void {
            return self.insert_many_slots_internal(idx, count, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn insert_many_slots(self: *Self, idx: IDX, count: IDX, alloc: Allocator) void {
            return self.insert_many_slots_internal(idx, count, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        fn insert_many_internal(self: *Self, idx: IDX, vals_: anytype, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(Slice, IDX) {
            const vals = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(vals_);
            const vals_len = vals.get_len();
            if (comptime ALLOC == .REALLOC and Assert.SHOULD_ASSERT) {
                if (list_memory_overlaps(self, vals)) {
                    self.assert_count_less_equal_data_unused_space_for_overlapping_copy(@intCast(vals_len), @src());
                }
            }
            const inserted_slice = self.insert_many_slots_internal(idx, @intCast(vals_len), ALLOC, alloc, GROWTH_MODE, growth, .RETURN_PTR_OR_SLICE);
            vals.copy_entire_self_to_dest_start(inserted_slice);
            return RETURN.ret_val(Slice, IDX, inserted_slice, idx);
        }
        pub inline fn insert_many_assume_cap_get_ptr(self: *Self, idx: IDX, vals_: anytype) Slice {
            return self.insert_many_internal(idx, vals_, .ASSUME_CAP, dummy_alloc, .CUSTOM_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn insert_many_with_growth_get_ptr(self: *Self, idx: IDX, vals_: anytype, growth: Growth, alloc: Allocator) Slice {
            return self.insert_many_internal(idx, vals_, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn insert_many_get_ptr(self: *Self, idx: IDX, vals_: anytype, alloc: Allocator) Slice {
            return self.insert_many_internal(idx, vals_, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_OR_SLICE);
        }
        pub inline fn insert_many_assume_cap(self: *Self, idx: IDX, vals_: anytype) void {
            return self.insert_many_internal(idx, vals_, .ASSUME_CAP, dummy_alloc, .CUSTOM_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn insert_many_with_growth(self: *Self, idx: IDX, vals_: anytype, growth: Growth, alloc: Allocator) void {
            return self.insert_many_internal(idx, vals_, .REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn insert_many(self: *Self, idx: IDX, vals_: anytype, alloc: Allocator) void {
            return self.insert_many_internal(idx, vals_, .REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        //**************
        // DELETE ONE
        //**************
        fn delete_one_internal(self: *Self, idx: IDX, comptime STRATEGY: DeleteMode, comptime RETURN: DeleteReturnMode) if (RETURN == .RETURN_VAL) ELEM else void {
            self.assert_valid_idx(idx, @src());
            const val_or_void: if (RETURN == .RETURN_VAL) ELEM else void = if (RETURN == .RETURN_VAL) self.get(idx) else void{};
            if (idx == self.data_len - 1) {
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {},
                }
            } else if (idx == 0) {
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {
                        switch (comptime STRATEGY) {
                            .ORDERED => {
                                self.move_block_overwrite_internal(1, self.data_len, 0);
                            },
                            .SWAP => {
                                const last_idx = self.data_len - 1;
                                self.move_one_overwrite(last_idx, 0);
                            },
                        }
                    },
                }
            } else {
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {
                        switch (comptime STRATEGY) {
                            .ORDERED => {
                                self.move_block_overwrite_internal(idx + 1, self.data_len, idx);
                            },
                            .SWAP => {
                                const last_idx = self.data_len - 1;
                                self.move_one_overwrite(last_idx, idx);
                            },
                        }
                    },
                }
            }
            self.decr_len_unchecked(1);
            return val_or_void;
        }
        pub fn delete_one(self: *Self, idx: IDX) void {
            self.assert_valid_idx(idx, @src());
            self.delete_one_internal(idx, .ORDERED, .IGNORE_VAL);
        }
        pub fn remove_one(self: *Self, idx: IDX) ELEM {
            self.assert_valid_idx(idx, @src());
            return self.delete_one_internal(idx, .ORDERED, .RETURN_VAL);
        }
        pub fn swap_delete_one(self: *Self, idx: IDX) void {
            self.assert_valid_idx(idx, @src());
            self.delete_one_internal(idx, .SWAP, .IGNORE_VAL);
        }
        pub fn swap_remove_one(self: *Self, idx: IDX) ELEM {
            self.assert_valid_idx(idx, @src());
            return self.delete_one_internal(idx, .SWAP, .RETURN_VAL);
        }
        //**************
        // DELETE MANY
        //**************
        fn delete_many_internal(self: *Self, start_idx: IDX, end_idx_exclusive: IDX, comptime STRATEGY: DeleteMode, comptime RETURN: DeleteReturnMode, dest_: anytype, comptime ALLOC: AllocMode, dest_alloc: Allocator, dest_growth: Growth) void {
            const count = end_idx_exclusive - start_idx;
            if (comptime RETURN == .RETURN_VAL) {
                const slice_to_copy = self.slice_const(start_idx, end_idx_exclusive);
                switch (comptime ALLOC) {
                    .ASSUME_CAP => {
                        const dest = coerce_anytype_to_list_or_list_ptr_with_same_elem_type(dest_);
                        dest.append_many_assume_cap(slice_to_copy);
                    },
                    .REALLOC => {
                        const dest = coerce_anytype_to_list_ptr_with_same_elem_type(dest_);
                        dest.append_many_with_growth(slice_to_copy, dest_growth, dest_alloc);
                    },
                }
            }
            if (start_idx == self.data_len - count) {
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {},
                }
            } else if (start_idx == 0) {
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {
                        switch (comptime STRATEGY) {
                            .ORDERED => {
                                self.move_block_overwrite_internal(count, self.data_len, 0);
                            },
                            .SWAP => {
                                const tail_count = self.data_len - end_idx_exclusive;
                                const num_to_move = @min(count, tail_count);
                                if (num_to_move > 0) {
                                    self.move_block_overwrite_internal(self.data_len - num_to_move, self.data_len, 0);
                                }
                            },
                        }
                    },
                }
            } else {
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES => {
                        switch (comptime STRATEGY) {
                            .ORDERED => {
                                self.move_block_overwrite_internal(end_idx_exclusive, self.data_len, start_idx);
                            },
                            .SWAP => {
                                const tail_count = self.data_len - end_idx_exclusive;
                                const num_to_move = @min(count, tail_count);
                                if (num_to_move > 0) {
                                    self.move_block_overwrite_internal(self.data_len - num_to_move, self.data_len, start_idx);
                                }
                            },
                        }
                    },
                }
            }
            self.decr_len_unchecked(count);
        }
        pub fn delete_range(self: *Self, start_idx: IDX, end_idx_exclusive: IDX) void {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            if (start_idx == end_idx_exclusive) return;
            self.delete_many_internal(start_idx, end_idx_exclusive, .ORDERED, .IGNORE_VAL, void{});
        }
        pub fn delete_count(self: *Self, start_idx: IDX, count: IDX) void {
            const end_idx_exclusive = start_idx + count;
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            if (count == 0) return;
            self.delete_many_internal(start_idx, end_idx_exclusive, .ORDERED, .IGNORE_VAL, void{});
        }
        /// Remove range of elements from this list into destination list
        ///
        /// Elements overwrite beginning of destination list/slice
        pub fn remove_range(self: *Self, start_idx: IDX, end_idx_exclusive: IDX, dest: anytype) void {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            if (start_idx == end_idx_exclusive) return;
            self.delete_many_internal(start_idx, end_idx_exclusive, .ORDERED, .RETURN_VAL, dest);
        }
        /// Remove range of elements from this list into destination list
        ///
        /// Elements overwrite beginning of destination list/slice
        pub fn remove_count(self: *Self, start_idx: IDX, count: IDX, dest: anytype) void {
            const end_idx_exclusive = start_idx + count;
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            if (count == 0) return;
            self.delete_many_internal(start_idx, end_idx_exclusive, .ORDERED, .RETURN_VAL, dest);
        }
        pub fn swap_delete_range(self: *Self, start_idx: IDX, end_idx_exclusive: IDX) void {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            if (start_idx == end_idx_exclusive) return;
            self.delete_many_internal(start_idx, end_idx_exclusive, .SWAP, .IGNORE_VAL, void{});
        }
        pub fn swap_delete_count(self: *Self, start_idx: IDX, count: IDX) void {
            const end_idx_exclusive = start_idx + count;
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            if (count == 0) return;
            self.delete_many_internal(start_idx, end_idx_exclusive, .SWAP, .IGNORE_VAL, void{});
        }
        /// Remove range of elements from this list into destination list
        ///
        /// Elements overwrite beginning of destination list/slice
        pub fn swap_remove_range(self: *Self, start_idx: IDX, end_idx_exclusive: IDX, dest: anytype) void {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            if (start_idx == end_idx_exclusive) return;
            self.delete_many_internal(start_idx, end_idx_exclusive, .SWAP, .RETURN_VAL, dest);
        }
        /// Remove range of elements from this list into destination list
        ///
        /// Elements overwrite beginning of destination list/slice
        pub fn swap_remove_count(self: *Self, start_idx: IDX, count: IDX, dest: anytype) void {
            const end_idx_exclusive = start_idx + count;
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            if (count == 0) return;
            self.delete_many_internal(start_idx, end_idx_exclusive, .SWAP, .RETURN_VAL, dest);
        }
        //*****************
        // DELETE FILTERED
        //*****************
        fn delete_filtered_internal(
            self: *Self,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            comptime STRATEGY: DeleteMode,
            comptime RETURN: DeleteReturnMode,
            comptime ALLOC: AllocMode,
            dest_: anytype,
            dest_alloc: Allocator,
            dest_growth: Growth,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            const dest = coerce_anytype_to_list_ptr_with_same_elem_type(dest_);
            if (start_idx == end_idx_exclusive) return 0;
            switch (comptime STRATEGY) {
                .ORDERED => {
                    var idx_to_check = start_idx;
                    var idx_to_place_kept_elem = start_idx;
                    var num_deleted: IDX = 0;
                    while (idx_to_check < end_idx_exclusive) {
                        const should_delete = self.eval_filter(idx_to_check, FILTER_FUNC_KIND, filter_ctx, FILTER_CTX, filter, FILTER);
                        if (should_delete) {
                            switch (comptime RETURN) {
                                .RETURN_VAL => {
                                    switch (comptime ALLOC) {
                                        .REALLOC => {
                                            dest.append_one_with_growth(self.get(idx_to_check), dest_growth, dest_alloc);
                                        },
                                        .ASSUME_CAP => {
                                            dest.append_one_assume_cap(self.get(idx_to_check));
                                        },
                                    }
                                },
                                .IGNORE_VAL => {},
                            }
                            num_deleted += 1;
                            idx_to_check += 1;
                            break;
                        } else {
                            idx_to_check += 1;
                            idx_to_place_kept_elem += 1;
                        }
                    }
                    while (idx_to_check < end_idx_exclusive) {
                        const should_delete = self.eval_filter(idx_to_check, FILTER_FUNC_KIND, filter_ctx, FILTER_CTX, filter, FILTER);
                        if (should_delete) {
                            switch (comptime RETURN) {
                                .RETURN_VAL => {
                                    switch (comptime ALLOC) {
                                        .REALLOC => {
                                            dest.append_one_with_growth(self.get(idx_to_check), dest_growth, dest_alloc);
                                        },
                                        .ASSUME_CAP => {
                                            dest.append_one_assume_cap(self.get(idx_to_check));
                                        },
                                    }
                                },
                                .IGNORE_VAL => {},
                            }
                            num_deleted += 1;
                            idx_to_check += 1;
                        } else {
                            self.move_one_overwrite(idx_to_check, idx_to_place_kept_elem);
                            idx_to_check += 1;
                            idx_to_place_kept_elem += 1;
                        }
                    }
                    if (num_deleted > 0) {
                        self.move_block_left_overwrite(idx_to_check, self.get_len(), idx_to_place_kept_elem);
                    }
                    self.decr_len_unchecked(num_deleted);
                    return num_deleted;
                },
                .SWAP => {
                    var last_idx_in_list = self.get_len() - 1;
                    var idx_to_check = start_idx;
                    var num_deleted: IDX = 0;
                    while (idx_to_check < end_idx_exclusive and last_idx_in_list >= end_idx_exclusive) {
                        const should_delete = self.eval_filter(idx_to_check, FILTER_FUNC_KIND, filter_ctx, FILTER_CTX, filter, FILTER);
                        if (should_delete) {
                            switch (comptime RETURN) {
                                .RETURN_VAL => {
                                    switch (comptime ALLOC) {
                                        .REALLOC => {
                                            dest.append_one_with_growth(self.get(idx_to_check), dest_growth, dest_alloc);
                                        },
                                        .ASSUME_CAP => {
                                            dest.append_one_assume_cap(self.get(idx_to_check));
                                        },
                                    }
                                },
                                .IGNORE_VAL => {},
                            }
                            self.move_one_overwrite(last_idx_in_list, idx_to_check);
                            num_deleted += 1;
                            idx_to_check += 1;
                            last_idx_in_list -= 1;
                        } else {
                            idx_to_check += 1;
                        }
                    }
                    if (idx_to_check < end_idx_exclusive) {
                        while (idx_to_check <= last_idx_in_list) {
                            const should_delete = self.eval_filter(idx_to_check, FILTER_FUNC_KIND, filter_ctx, FILTER_CTX, filter, FILTER);
                            if (should_delete) {
                                switch (comptime RETURN) {
                                    .RETURN_VAL => {
                                        switch (comptime ALLOC) {
                                            .REALLOC => {
                                                dest.append_one_with_growth(self.get(idx_to_check), dest_growth, dest_alloc);
                                            },
                                            .ASSUME_CAP => {
                                                dest.append_one_assume_cap(self.get(idx_to_check));
                                            },
                                        }
                                    },
                                    .IGNORE_VAL => {},
                                }
                                self.move_one_overwrite(last_idx_in_list, idx_to_check);
                                num_deleted += 1;
                                if (idx_to_check == last_idx_in_list) break;
                                last_idx_in_list -= 1;
                            } else {
                                idx_to_check += 1;
                            }
                        }
                    }
                    self.decr_len_unchecked(num_deleted);
                    return num_deleted;
                },
            }
        }
        pub inline fn delete_range_filtered(
            self: *Self,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            return self.delete_filtered_internal(start_idx, end_idx_exclusive, .ORDERED, .IGNORE_VAL, .ASSUME_CAP, void{}, dummy_alloc, .GROW_EXACT_NEEDED, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_delete_range_filtered(
            self: *Self,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            return self.delete_filtered_internal(start_idx, end_idx_exclusive, .SWAP, .IGNORE_VAL, .ASSUME_CAP, void{}, dummy_alloc, .GROW_EXACT_NEEDED, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn remove_range_filtered_assume_dest_cap(
            self: *Self,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            dest: anytype,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            return self.delete_filtered_internal(start_idx, end_idx_exclusive, .ORDERED, .RETURN_VAL, .ASSUME_CAP, dest, dummy_alloc, .GROW_EXACT_NEEDED, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_remove_range_filtered_assume_dest_cap(
            self: *Self,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            dest: anytype,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            return self.delete_filtered_internal(start_idx, end_idx_exclusive, .SWAP, .RETURN_VAL, .ASSUME_CAP, dest, dummy_alloc, .GROW_EXACT_NEEDED, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn remove_range_filtered(
            self: *Self,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            dest: anytype,
            dest_alloc: Allocator,
            dest_growth: Growth,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            return self.delete_filtered_internal(start_idx, end_idx_exclusive, .ORDERED, .RETURN_VAL, .REALLOC, dest, dest_alloc, dest_growth, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_remove_range_filtered(
            self: *Self,
            start_idx: IDX,
            end_idx_exclusive: IDX,
            dest: anytype,
            dest_alloc: Allocator,
            dest_growth: Growth,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            self.assert_valid_range(start_idx, end_idx_exclusive, @src());
            return self.delete_filtered_internal(start_idx, end_idx_exclusive, .SWAP, .RETURN_VAL, .REALLOC, dest, dest_alloc, dest_growth, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn delete_filtered(
            self: *Self,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            return self.delete_filtered_internal(0, self.get_len(), .ORDERED, .IGNORE_VAL, .ASSUME_CAP, void{}, dummy_alloc, .GROW_EXACT_NEEDED, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_delete_filtered(
            self: *Self,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            return self.delete_filtered_internal(0, self.get_len(), .SWAP, .IGNORE_VAL, .ASSUME_CAP, void{}, dummy_alloc, .GROW_EXACT_NEEDED, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn remove_filtered_assume_dest_cap(
            self: *Self,
            dest: anytype,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            return self.delete_filtered_internal(0, self.get_len(), .ORDERED, .RETURN_VAL, .ASSUME_CAP, dest, dummy_alloc, .GROW_EXACT_NEEDED, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_remove_filtered_assume_dest_cap(
            self: *Self,
            dest: anytype,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            return self.delete_filtered_internal(0, self.get_len(), .SWAP, .RETURN_VAL, .ASSUME_CAP, dest, dummy_alloc, .GROW_EXACT_NEEDED, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn remove_filtered(
            self: *Self,
            dest: anytype,
            dest_alloc: Allocator,
            dest_growth: Growth,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            return self.delete_filtered_internal(0, self.get_len(), .ORDERED, .RETURN_VAL, .REALLOC, dest, dest_alloc, dest_growth, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        pub inline fn swap_remove_filtered(
            self: *Self,
            dest: anytype,
            dest_alloc: Allocator,
            dest_growth: Growth,
            filter_ctx: anytype,
            comptime FILTER_CTX: anytype,
            comptime FILTER_FUNC_KIND: FuncParamType,
            filter: FilterFnRt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
            comptime FILTER: FilterFnCt(FILTER_FUNC_KIND, @TypeOf(filter_ctx), @TypeOf(FILTER_CTX)),
        ) IDX {
            return self.delete_filtered_internal(0, self.get_len(), .SWAP, .RETURN_VAL, .REALLOC, dest, dest_alloc, dest_growth, filter_ctx, FILTER_CTX, FILTER_FUNC_KIND, filter, FILTER);
        }
        //*****************
        // ROOT FLAT TREE
        //*****************
        /// Elements MUST be laid out in a 'n-ary flat array tree',
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub fn root_tree__parent_idx_unchecked(self: Self, idx: IDX, max_num_children_per_element: IDX) IDX {
            const new_idx_ = self.slice_idx_to_root_idx(idx);
            return self.root_idx_to_slice_idx(@divFloor(new_idx_ - 1, max_num_children_per_element));
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub fn root_tree__parent_idx_if_exists(self: Self, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            self.assert_valid_idx(idx, @src());
            var new_idx = self.slice_idx_to_root_idx(idx);
            if (new_idx == 0) return null;
            new_idx = @divFloor(new_idx - 1, max_num_children_per_element);
            return self.root_idx_to_slice_idx(new_idx);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub fn root_tree__nth_child_idx_unchecked(self: Self, idx: IDX, max_num_children_per_element: IDX, nth_child: IDX) IDX {
            const new_idx_ = self.slice_idx_to_root_idx(idx);
            return self.root_idx_to_slice_idx((new_idx_ * max_num_children_per_element) + nth_child + 1);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub fn root_tree__nth_child_idx_if_exists(self: Self, idx: IDX, max_num_children_per_element: IDX, nth_child: IDX) ?IDX {
            self.assert_valid_idx(idx, @src());
            assert_with_reason(nth_child < max_num_children_per_element, @src(), "nth_child ({d}) exceeds maximum children per element ({d})", .{ nth_child, max_num_children_per_element });
            var new_idx_ = self.slice_idx_to_root_idx(idx);
            new_idx_ = self.root_idx_to_slice_idx((new_idx_ * max_num_children_per_element) + nth_child + 1);
            if (new_idx_ >= self.get_len()) return null;
            return new_idx_;
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub fn root_tree__first_child_idx_unchecked(self: Self, idx: IDX, max_num_children_per_element: IDX) IDX {
            return self.root_tree__nth_child_idx_unchecked(idx, max_num_children_per_element, 0);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub fn root_tree__first_child_idx_if_exists(self: Self, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return self.root_tree__nth_child_idx_if_exists(idx, max_num_children_per_element, 0);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub fn root_tree__last_child_idx_unchecked(self: Self, idx: IDX, max_num_children_per_element: IDX) IDX {
            return self.root_tree__nth_child_idx_unchecked(idx, max_num_children_per_element, max_num_children_per_element - 1);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the root of the data
        /// and it is expected that if the data is a slice, it spans
        /// the entire data length
        pub fn root_tree__last_child_idx_if_exists(self: Self, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return self.root_tree__nth_child_idx_if_exists(idx, max_num_children_per_element, max_num_children_per_element - 1);
        }
        //*****************
        // LOCAL FLAT TREE
        //*****************
        /// Elements MUST be laid out in a 'n-ary flat array tree',
        /// starting at the start of the slice
        pub fn local_tree__parent_idx_unchecked(self: Self, idx: IDX, max_num_children_per_element: IDX) IDX {
            return self.root_idx_to_slice_idx(@divFloor(idx - 1, max_num_children_per_element));
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub fn local_tree__parent_idx_if_exists(self: Self, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            self.assert_valid_idx(idx, @src());
            if (idx == 0) return null;
            return @divFloor(idx - 1, max_num_children_per_element);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub fn local_tree__nth_child_idx_unchecked(self: Self, idx: IDX, max_num_children_per_element: IDX, nth_child: IDX) IDX {
            return self.root_idx_to_slice_idx((idx * max_num_children_per_element) + nth_child + 1);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub fn local_tree__nth_child_idx_if_exists(self: Self, idx: IDX, max_num_children_per_element: IDX, nth_child: IDX) ?IDX {
            self.assert_valid_idx(idx, @src());
            assert_with_reason(nth_child < max_num_children_per_element, @src(), "nth_child ({d}) exceeds maximum children per element ({d})", .{ nth_child, max_num_children_per_element });
            const new_idx = self.root_idx_to_slice_idx((idx * max_num_children_per_element) + nth_child + 1);
            if (new_idx >= self.get_len()) return null;
            return new_idx;
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub fn local_tree__first_child_idx_unchecked(self: Self, idx: IDX, max_num_children_per_element: IDX) IDX {
            return self.local_tree__nth_child_idx_unchecked(idx, max_num_children_per_element, 0);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub fn local_tree__first_child_idx_if_exists(self: Self, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return self.local_tree__nth_child_idx_if_exists(idx, max_num_children_per_element, 0);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub fn local_tree__last_child_idx_unchecked(self: Self, idx: IDX, max_num_children_per_element: IDX) IDX {
            return self.local_tree__nth_child_idx_unchecked(idx, max_num_children_per_element, max_num_children_per_element - 1);
        }
        /// Elements MUST be laid out in a 'n-ary flat array tree'
        /// starting at the start of the slice
        pub fn local_tree__last_child_idx_if_exists(self: Self, idx: IDX, max_num_children_per_element: IDX) ?IDX {
            return self.local_tree__nth_child_idx_if_exists(idx, max_num_children_per_element, max_num_children_per_element - 1);
        }
        pub fn median_index_of_3_indexes_with_elem(self: Self, idxs_: [3]IDX) IdxElemPair {
            var idxs = idxs_;
            var tmp: IDX = undefined;
            if (idxs[1] < idxs[0]) {
                tmp = idxs[0];
                idxs[0] = idxs[1];
                idxs[1] = tmp;
            }
            if (idxs[2] < idxs[0]) {
                tmp = idxs[0];
                idxs[0] = idxs[2];
                idxs[2] = tmp;
            }
            if (idxs[2] < idxs[1]) {
                return .{ idxs[2], self.get(2) };
            }
            return .{ idxs[1], self.get(1) };
        }

        fn build_heap_within_range_internal(
            self: Self,
            heap_first_idx: IDX,
            heap_last_idx_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            const heap_len = heap_last_idx_exclusive - heap_first_idx;
            if (heap_len < 2) return;
            const position_of_first_elem_with_no_children = heap_len >> 1;
            var curr_parent_idx = heap_first_idx + position_of_first_elem_with_no_children;
            while (curr_parent_idx > heap_first_idx) {
                curr_parent_idx -= 1;
                self.heap_sift_down_within_range_internal(heap_first_idx, heap_len, curr_parent_idx, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL);
            }
        }

        fn heap_sift_down_within_range_internal(
            self: Self,
            heap_first_idx: IDX,
            heap_len: IDX,
            idx: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            var hole_idx: IDX = idx;
            var hole_n: IDX = idx - heap_first_idx;
            const target_val = self.get(idx);
            const half_len = heap_len >> 1;
            while (hole_n < half_len) {
                var highest_child_n = (hole_n << 1) | 1; // Left child relative index
                var highest_child_idx = heap_first_idx + highest_child_n; // Left child absolute index
                const right_child_n = highest_child_n + 1;
                if (right_child_n < heap_len) {
                    const right_child_idx = highest_child_idx + 1;
                    if (self.eval_compare_idx_idx(right_child_idx, highest_child_idx, COMPARE_IDX_IDX_FN_KIND, compare_ctx, COMPARE_CTX, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX)) {
                        highest_child_n = right_child_n;
                        highest_child_idx = right_child_idx;
                    }
                }
                if (!self.eval_compare_idx_val(highest_child_idx, target_val, COMPARE_IDX_VAL_FN_KIND, compare_ctx, COMPARE_CTX, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL)) {
                    break;
                }
                self.move_one_overwrite(highest_child_idx, hole_idx);
                hole_idx = highest_child_idx;
                hole_n = highest_child_n;
            }
            self.set(hole_idx, target_val);
        }
        pub inline fn heap_sift_down_within_range_avanced(
            self: Self,
            heap_first_idx: IDX,
            heap_len: IDX,
            idx: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            self.heap_sift_down_within_range_internal(heap_first_idx, heap_len, idx, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL);
        }
        pub inline fn heap_sift_down_avanced(
            self: Self,
            idx: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            self.heap_sift_down_within_range_internal(0, self.get_len(), idx, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL);
        }
        pub inline fn heap_sift_down_within_range(
            self: Self,
            heap_first_idx: IDX,
            heap_len: IDX,
            idx: IDX,
            higher_in_heap_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
            higher_in_heap_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
        ) void {
            self.heap_sift_down_within_range_internal(heap_first_idx, heap_len, idx, void{}, void{}, .RUNTIME_FN_PTR, higher_in_heap_idx_idx, void{}, .RUNTIME_FN_PTR, higher_in_heap_idx_val, void{});
        }
        pub inline fn heap_sift_down(
            self: Self,
            idx: IDX,
            higher_in_heap_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
            higher_in_heap_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
        ) void {
            self.heap_sift_down_within_range_internal(0, self.get_len(), idx, void{}, void{}, .RUNTIME_FN_PTR, higher_in_heap_idx_idx, void{}, .RUNTIME_FN_PTR, higher_in_heap_idx_val, void{});
        }
        // TODO more heap operations

        pub inline fn build_heap_within_range_advanced(
            self: Self,
            start: IDX,
            end_excluded: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            self.assert_valid_range(start, end_excluded, @src());
            if (start == end_excluded) return;
            self.build_heap_within_range_internal(start, end_excluded, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL);
        }

        pub inline fn build_heap_advanced(
            self: Self,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            higher_in_heap_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            if (self.get_len() < 2) return;
            self.build_heap_within_range_internal(0, self.get_len(), compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, higher_in_heap_idx_val, HIGHER_IN_HEAP_IDX_VAL);
        }

        pub inline fn build_heap_within_range(
            self: Self,
            start: IDX,
            end_excluded: IDX,
            higher_in_heap_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
            higher_in_heap_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
        ) void {
            self.assert_valid_range(start, end_excluded, @src());
            if (start == end_excluded) return;
            self.build_heap_within_range_internal(start, end_excluded, void{}, void{}, .RUNTIME_FN_PTR, higher_in_heap_idx_idx, void{}, .RUNTIME_FN_PTR, higher_in_heap_idx_val, void{});
        }

        pub inline fn build_heap(
            self: Self,
            higher_in_heap_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
            higher_in_heap_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
        ) void {
            if (self.get_len() < 2) return;
            self.build_heap_within_range_internal(0, self.get_len(), void{}, void{}, .RUNTIME_FN_PTR, higher_in_heap_idx_idx, void{}, .RUNTIME_FN_PTR, higher_in_heap_idx_val, void{});
        }

        fn is_range_a_valid_heap_internal(
            self: Self,
            heap_first_idx: IDX,
            heap_last_idx_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) bool {
            const heap_len = heap_last_idx_exclusive - heap_first_idx;
            if (heap_len < 2) return true;
            var child_n: IDX = 1;
            while (child_n < heap_len) : (child_n += 1) {
                const parent_n = (child_n - 1) >> 1;
                const child_idx = heap_first_idx + child_n;
                const parent_idx = heap_first_idx + parent_n;
                if (self.eval_compare_idx_idx(child_idx, parent_idx, COMPARE_IDX_IDX_FN_KIND, compare_ctx, COMPARE_CTX, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX)) {
                    return false;
                }
            }
            return true;
        }
        pub fn is_range_a_valid_heap_advanced(
            self: Self,
            heap_first_idx: IDX,
            heap_last_idx_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) bool {
            self.assert_valid_range(heap_first_idx, heap_last_idx_exclusive, @src());
            return self.is_range_a_valid_heap_internal(heap_first_idx, heap_last_idx_exclusive, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX);
        }
        pub fn is_a_valid_heap_advanced(
            self: Self,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            higher_in_heap_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime HIGHER_IN_HEAP_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) bool {
            return self.is_range_a_valid_heap_internal(0, self.get_len(), compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, higher_in_heap_idx_idx, HIGHER_IN_HEAP_IDX_IDX);
        }
        pub fn is_range_a_valid_heap(
            self: Self,
            heap_first_idx: IDX,
            heap_last_idx_exclusive: IDX,
            greater_than_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
        ) bool {
            self.assert_valid_range(heap_first_idx, heap_last_idx_exclusive, @src());
            return self.is_range_a_valid_heap_internal(heap_first_idx, heap_last_idx_exclusive, void{}, void{}, .RUNTIME_FN_PTR, greater_than_idx_idx, void{});
        }
        pub fn is_a_valid_heap(
            self: Self,
            greater_than_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
        ) bool {
            return self.is_range_a_valid_heap_internal(0, self.get_len(), void{}, void{}, .RUNTIME_FN_PTR, greater_than_idx_idx, void{});
        }

        pub fn is_range_sorted_advanced(
            self: Self,
            start: IDX,
            end_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime GREATER_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRt(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCt(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) bool {
            self.assert_valid_range(start, end_exclusive, @src());
            const len = end_exclusive - start;
            if (len < 2) return true;
            var left_idx = start;
            var right_idx = left_idx + 1;
            while (true) {
                if (self.eval_compare_idx_idx(
                    left_idx,
                    right_idx,
                    GREATER_IDX_IDX_FN_KIND,
                    compare_ctx,
                    COMPARE_CTX,
                    greater_than_idx_idx,
                    GREATER_THAN_IDX_IDX,
                )) return false;
                left_idx += 1;
                right_idx += 1;
                if (right_idx >= end_exclusive) return true;
            }
        }

        pub inline fn is_sorted_advanced(
            self: Self,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime GREATER_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRt(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCt(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) bool {
            self.is_range_sorted_advanced(0, self.get_len(), compare_ctx, COMPARE_CTX, GREATER_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX);
        }

        pub inline fn is_sorted(
            self: Self,
            greater_than_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
        ) bool {
            self.is_range_sorted_advanced(0, self.get_len(), void{}, void{}, .RUNTIME_FN_PTR, greater_than_idx_idx, void{});
        }
        
        pub inline fn is_range_sorted(
            self: Self,
            start: IDX,
            end_exclusive: IDX,
            greater_than_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
        ) bool {
            self.is_range_sorted_advanced(start, end_exclusive, void{}, void{}, .RUNTIME_FN_PTR, greater_than_idx_idx, void{});
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
        pub fn heapsort_range_advanced(
            self: Self,
            start: IDX,
            end_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            self.assert_valid_range(start, end_exclusive, @src());
            var heap_len = end_exclusive - start;
            if (heap_len < 2) return;
            self.build_heap_within_range_internal(start, end_exclusive, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL);
            var heap_last_idx = end_exclusive - 1;
            while (heap_len > 2) {
                self.swap(start, heap_last_idx);
                heap_last_idx -= 1;
                heap_len -= 1;
                self.heap_sift_down_within_range_internal(start, heap_len, start, compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL);
            }
            self.swap(start, start + 1);
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
            self: Self,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCt(COMPARE_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            self.heapsort_range_advanced(0, self.get_len(), compare_ctx, COMPARE_CTX, COMPARE_IDX_IDX_FN_KIND, greater_than_idx_idx, GREATER_THAN_IDX_IDX, COMPARE_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL);
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
        pub fn heapsort_range(
            self: Self,
            start: IDX,
            end_exclusive: IDX,
            greater_than_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
            greater_than_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
        ) void {
            self.heapsort_range_advanced(start, end_exclusive, void{}, void{}, .RUNTIME_FN_PTR, greater_than_idx_idx, void{}, .RUNTIME_FN_PTR, greater_than_idx_val, void{});
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
            self: Self,
            greater_than_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
            greater_than_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
        ) void {
            self.heapsort_advanced(void{}, void{}, .RUNTIME_FN_PTR, greater_than_idx_idx, void{}, .RUNTIME_FN_PTR, greater_than_idx_val, void{});
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
        pub fn insertion_sort_range_advanced(
            self: Self,
            start: IDX,
            end_exclusive: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            self.assert_valid_range(start, end_exclusive, @src());
            const len = end_exclusive - start;
            if (len < 2) return;
            var idx_to_sort: IDX = start + 1;
            var idx_right: IDX = undefined;
            var idx_left: IDX = undefined;
            var val_to_sort: ELEM = undefined;
            while (true) {
                val_to_sort = self.get(idx_to_sort);
                idx_right = idx_to_sort;
                inner: while (true) {
                    idx_left = idx_right - 1;
                    if (self.eval_compare_idx_val(idx_left, val_to_sort, COMPARE_IDX_VAL_FN_KIND, compare_ctx, COMPARE_CTX, greater_than_idx_val, GREATER_THAN_IDX_VAL)) {
                        self.move_one_overwrite(idx_left, idx_right);
                        idx_right = idx_left;
                    } else {
                        break :inner;
                    }
                    if (idx_left == start) {
                        break :inner;
                    }
                }
                if (idx_right != idx_to_sort) {
                    self.set(idx_right, val_to_sort);
                }
                idx_to_sort += 1;
                if (idx_to_sort == end_exclusive) {
                    return;
                }
            }
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
            self: Self,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime COMPARE_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCt(COMPARE_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            self.insertion_sort_range_advanced(0, self.get_len(), compare_ctx, COMPARE_CTX, COMPARE_IDX_VAL_FN_KIND, greater_than_idx_val, GREATER_THAN_IDX_VAL);
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
        pub inline fn insertion_sort_range(self: Self, start: IDX, end_exclusive: IDX, greater_than_idx_val: *const fn (Self, IDX, ELEM) bool) void {
            self.insertion_sort_range_advanced(start, end_exclusive, void{}, void{}, .RUNTIME_FN_PTR, greater_than_idx_val, void{});
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
        pub inline fn insertion_sort(self: Self, greater_than_idx_val: *const fn (Self, IDX, ELEM) bool) void {
            self.insertion_sort_range_advanced(0, self.get_len(), void{}, void{}, .RUNTIME_FN_PTR, greater_than_idx_val, void{});
        }

        const PartitionResult = struct {
            sub_partition_left_hi: IDX,
            sub_partition_right_lo: IDX,
        };

        pub fn QuicksortPartition(comptime DEGENERATE_FALLBACK: bool) type {
            return struct {
                lo_idx: IDX,
                hi_idx: IDX,
                budget: if (DEGENERATE_FALLBACK) IDX else void = if (DEGENERATE_FALLBACK) undefined else void{},

                pub fn new(lo: IDX, hi: IDX, budget: IDX) @This() {
                    var this = @This(){
                        .lo_idx = lo,
                        .hi_idx = hi,
                    };
                    if (DEGENERATE_FALLBACK) {
                        this.budget = budget;
                    }
                    return this;
                }

                pub inline fn empty(partition: @This()) bool {
                    return partition.lo_idx > partition.hi_idx;
                }

                pub inline fn len(partition: @This()) IDX {
                    return (partition.hi_idx + 1) - partition.lo_idx;
                }
            };
        }

        fn sort_partition_median_of_3(self: Self, first: IDX, last: IDX) IdxElemPair {
            const len = (last + 1) - first;
            const mid = first + (len >> 1);
            const unsorted_idxs = [3]IDX{ first, mid, last };
            return self.median_index_of_3_indexes_with_elem(unsorted_idxs);
        }

        fn sort_partition_hoare(
            self: Self,
            first: IDX,
            last: IDX,
            comptime COUNT_PIVOT_DUPES: bool,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime LESSER_IDX_VAL_FN_KIND: FuncParamType,
            less_than_idx_val: CompareIdxValFnRt(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime LESS_THAN_IDX_VAL: CompareIdxValFnCt(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRt(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCt(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL_FN_KIND: FuncParamType,
            equal_idx_val: CompareIdxValFnRt(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL: CompareIdxValFnCt(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) if (COUNT_PIVOT_DUPES) struct { PartitionResult, IDX } else PartitionResult {
            const median_idx, const pivot_elem = self.sort_partition_median_of_3(first, last);
            self.swap_already_have_b(first, median_idx, pivot_elem);
            var left_idx = first;
            var right_idx = last;
            var pivot_dupes: if (COUNT_PIVOT_DUPES) IDX else void = if (COUNT_PIVOT_DUPES) 0 else {};
            while (true) {
                while (self.eval_compare_idx_val(left_idx, pivot_elem, LESSER_IDX_VAL_FN_KIND, compare_ctx, COMPARE_CTX, less_than_idx_val, LESS_THAN_IDX_VAL)) {
                    left_idx += 1;
                }
                if (comptime COUNT_PIVOT_DUPES) {
                    const is_dupe = self.eval_compare_idx_val(left_idx, pivot_elem, EQUAL_IDX_VAL_FN_KIND, compare_ctx, COMPARE_CTX, equal_idx_val, EQUAL_IDX_VAL);
                    pivot_dupes += @as(IDX, @intCast(@intFromBool(is_dupe)));
                }
                while (self.eval_compare_idx_val(right_idx, pivot_elem, GREATER_IDX_VAL_FN_KIND, compare_ctx, COMPARE_CTX, greater_than_idx_val, GREATER_THAN_IDX_VAL)) {
                    right_idx -= 1;
                }
                if (comptime COUNT_PIVOT_DUPES) {
                    const is_dupe = self.eval_compare_idx_val(right_idx, pivot_elem, EQUAL_IDX_VAL_FN_KIND, compare_ctx, COMPARE_CTX, equal_idx_val, EQUAL_IDX_VAL);
                    pivot_dupes += @as(IDX, @intCast(@intFromBool(is_dupe)));
                }
                if (left_idx >= right_idx) break;
                self.swap(left_idx, right_idx);
                left_idx += 1;
                right_idx -= 1;
            }
            if (comptime COUNT_PIVOT_DUPES) {
                return .{
                    PartitionResult{
                        .sub_partition_left_hi = right_idx,
                        .sub_partition_right_lo = right_idx + 1,
                    },
                    pivot_dupes,
                };
            } else {
                return PartitionResult{
                    .sub_partition_left_hi = right_idx,
                    .sub_partition_right_lo = right_idx + 1,
                };
            }
        }

        fn quicksort_partition_dutch_flag(
            self: Self,
            first: IDX,
            last: IDX,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime LESSER_IDX_VAL_FN_KIND: FuncParamType,
            less_than_idx_val: CompareIdxValFnRt(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime LESS_THAN_IDX_VAL: CompareIdxValFnCt(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRt(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCt(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) PartitionResult {
            const median_idx, const pivot_elem = self.sort_partition_median_of_3(first, last);
            self.swap_already_have_b(first, median_idx, pivot_elem);
            var smallest_idx_with_same_order_as_pivot = first;
            var check_idx = first;
            var largest_idx_with_same_order_as_pivot = last;
            while (check_idx <= largest_idx_with_same_order_as_pivot) {
                if (self.eval_compare_idx_val(check_idx, pivot_elem, LESSER_IDX_VAL_FN_KIND, compare_ctx, COMPARE_CTX, less_than_idx_val, LESS_THAN_IDX_VAL)) {
                    self.swap(smallest_idx_with_same_order_as_pivot, check_idx);
                    smallest_idx_with_same_order_as_pivot += 1;
                    check_idx += 1;
                } else if (self.eval_compare_idx_val(check_idx, pivot_elem, GREATER_IDX_VAL_FN_KIND, compare_ctx, COMPARE_CTX, greater_than_idx_val, GREATER_THAN_IDX_VAL)) {
                    self.swap(largest_idx_with_same_order_as_pivot, check_idx);
                    largest_idx_with_same_order_as_pivot -= 1;
                } else {
                    check_idx += 1;
                }
            }
            return PartitionResult{
                .sub_partition_left_hi = smallest_idx_with_same_order_as_pivot - @as(IDX, @intCast(@intFromBool(smallest_idx_with_same_order_as_pivot > first))),
                .sub_partition_right_lo = largest_idx_with_same_order_as_pivot + 1,
            };
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
        pub fn quicksort_range_advanced(
            self: Self,
            start: IDX,
            end_excluded: IDX,
            comptime SETTINGS: QuicksortSettings,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime LESSER_IDX_VAL_FN_KIND: FuncParamType,
            less_than_idx_val: CompareIdxValFnRt(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime LESS_THAN_IDX_VAL: CompareIdxValFnCt(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRt(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCt(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRt(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCt(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL_FN_KIND: FuncParamType,
            equal_idx_val: CompareIdxValFnRt(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL: CompareIdxValFnCt(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            self.assert_valid_range(start, end_excluded);
            const len = end_excluded - start;
            if (len < 2) return;
            const last = end_excluded - 1;
            assert_stack_can_support_sort_len(SETTINGS, len, @src());
            const Partition = QuicksortPartition(SETTINGS.FALLBACK_WHEN_DEGENERATE);
            const degenerate_limit: IDX = if (comptime SETTINGS.FALLBACK_WHEN_DEGENERATE) (SETTINGS.DEGENERATE_DETECTION_FACTOR * @as(IDX, @intCast(math.log2_int(IDX, len)))) else math.maxInt(IDX);
            var stack: [SETTINGS.QUICKSORT_MAX_STACK]Partition = undefined;
            stack[0] = Partition.new(start, last, degenerate_limit);
            var stack_len: u8 = 1;
            var force_3_way = if (SETTINGS.SAME_ORDER_EXPECTATIONS == .DYNAMIC_BASED_ON_SAME_ORDER_DENSITY) false else void{};
            var force_3_way_counter = if (SETTINGS.SAME_ORDER_EXPECTATIONS == .DYNAMIC_BASED_ON_SAME_ORDER_DENSITY) @as(IDX, 0) else void{};
            next_partition: while (stack_len > 0) {
                stack_len -= 1;
                const part = stack[stack_len];
                if (SETTINGS.FALLBACK_WHEN_DEGENERATE and part.budget <= 0) {
                    if (len <= SETTINGS.FALLBACK_WHEN_DEGENERATE_INSERTION_SORT_MAX_INPUT_LEN) {
                        return self.insertion_sort_range_advanced(
                            start,
                            end_excluded,
                            compare_ctx,
                            COMPARE_CTX,
                            GREATER_IDX_VAL_FN_KIND,
                            greater_than_idx_val,
                            GREATER_THAN_IDX_VAL,
                        );
                    } else {
                        return self.heapsort_range_advanced(
                            start,
                            end_excluded,
                            compare_ctx,
                            COMPARE_CTX,
                            GREATER_IDX_IDX_FN_KIND,
                            greater_than_idx_idx,
                            GREATER_THAN_IDX_IDX,
                            GREATER_IDX_VAL_FN_KIND,
                            greater_than_idx_val,
                            GREATER_THAN_IDX_VAL,
                        );
                    }
                }
                assert_with_reason(!part.empty(), @src(), "it should be impossible to have an empty partition here", .{});
                if (part.len() <= SETTINGS.QUICKSORT_TO_INSERTION_THRESHOLD) {
                    self.insertion_sort_range(
                        part.lo_idx,
                        part.hi_idx + 1,
                        compare_ctx,
                        COMPARE_CTX,
                        GREATER_IDX_VAL_FN_KIND,
                        greater_than_idx_val,
                        GREATER_THAN_IDX_VAL,
                    );
                    continue :next_partition;
                }
                const partition_result = switch (comptime SETTINGS.SAME_ORDER_EXPECTATIONS) {
                    .MANY_ITEMS_WITH_SAME_ORDER_LIKELY, .USE_DUTCH_FLAG_3_WAY_PARTITION => quicksort_partition_dutch_flag(
                        self,
                        part.lo_idx,
                        part.hi_idx,
                        compare_ctx,
                        COMPARE_CTX,
                        LESSER_IDX_VAL_FN_KIND,
                        less_than_idx_val,
                        LESS_THAN_IDX_VAL,
                        GREATER_IDX_VAL_FN_KIND,
                        greater_than_idx_val,
                        GREATER_THAN_IDX_VAL,
                    ),
                    .MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE, .USE_HOARE_2_WAY_PARTITION => sort_partition_hoare(
                        self,
                        part.lo_idx,
                        part.hi_idx,
                        false,
                        compare_ctx,
                        COMPARE_CTX,
                        LESSER_IDX_VAL_FN_KIND,
                        less_than_idx_val,
                        LESS_THAN_IDX_VAL,
                        GREATER_IDX_VAL_FN_KIND,
                        greater_than_idx_val,
                        GREATER_THAN_IDX_VAL,
                        EQUAL_IDX_VAL_FN_KIND,
                        equal_idx_val,
                        EQUAL_IDX_VAL,
                    ),
                    .DYNAMIC_BASED_ON_SAME_ORDER_DENSITY => blk: {
                        if (force_3_way) {
                            break :blk quicksort_partition_dutch_flag(
                                self,
                                part.lo_idx,
                                part.hi_idx,
                                compare_ctx,
                                COMPARE_CTX,
                                LESSER_IDX_VAL_FN_KIND,
                                less_than_idx_val,
                                LESS_THAN_IDX_VAL,
                                GREATER_IDX_VAL_FN_KIND,
                                greater_than_idx_val,
                                GREATER_THAN_IDX_VAL,
                            );
                        } else {
                            const partition, const dupes = sort_partition_hoare(
                                self,
                                part.lo_idx,
                                part.hi_idx,
                                true,
                                compare_ctx,
                                COMPARE_CTX,
                                LESSER_IDX_VAL_FN_KIND,
                                less_than_idx_val,
                                LESS_THAN_IDX_VAL,
                                GREATER_IDX_VAL_FN_KIND,
                                greater_than_idx_val,
                                GREATER_THAN_IDX_VAL,
                                EQUAL_IDX_VAL_FN_KIND,
                                equal_idx_val,
                                EQUAL_IDX_VAL,
                            );
                            const parent_len_float: f32 = @floatFromInt(part.len());
                            const dupes_float: f32 = @floatFromInt(dupes);
                            const density = dupes_float / parent_len_float;
                            if (density >= SETTINGS.DYNAMIC_PARTITION_SWAP_TO_3_WAY_THRESHOLD) {
                                force_3_way_counter += 1;
                                if (force_3_way_counter > SETTINGS.DYNAMIC_PARTITION_SWAP_TO_3_WAY_MAX_COUNT) {
                                    force_3_way = true;
                                }
                            }
                            break :blk partition;
                        }
                    },
                };
                const left_partition = Partition.new(part.lo_idx, partition_result.sub_partition_left_hi, if (SETTINGS.FALLBACK_WHEN_DEGENERATE) part.budget - 1 else 0);
                const right_partition = Partition.new(partition_result.sub_partition_right_lo, part.hi_idx, if (SETTINGS.FALLBACK_WHEN_DEGENERATE) part.budget - 1 else 0);
                const left_len = left_partition.len();
                const right_len = right_partition.len();
                const left_empty: u8 = @intCast(@intFromBool(left_len == 0));
                const right_empty: u8 = @intCast(@intFromBool(right_len == 0));
                const larger_partition, const larger_empty, const smaller_partition, const smaller_empty = if (left_len < right_len) .{
                    right_partition,
                    right_empty,
                    left_partition,
                    left_empty,
                } else .{
                    left_partition,
                    left_empty,
                    right_partition,
                    right_empty,
                };
                // add partitions larger first, smaller second,
                // and use the `larger_empty` and `smaller_empty` vars
                // to cull empty partitions. This ensures a stack of
                // size `log2(len) + 2` is always large enough
                stack[stack_len] = larger_partition;
                stack_len = stack_len + 1 - larger_empty;
                stack[stack_len] = smaller_partition;
                stack_len = stack_len + 1 - smaller_empty;
            }
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
        pub fn quicksort_advanced(
            self: Self,
            start: IDX,
            end_excluded: IDX,
            comptime SETTINGS: QuicksortSettings,
            compare_ctx: anytype,
            comptime COMPARE_CTX: anytype,
            comptime LESSER_IDX_VAL_FN_KIND: FuncParamType,
            less_than_idx_val: CompareIdxValFnRt(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime LESS_THAN_IDX_VAL: CompareIdxValFnCt(LESSER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_IDX_FN_KIND: FuncParamType,
            greater_than_idx_idx: CompareIdxIdxFnRt(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_IDX: CompareIdxIdxFnCt(GREATER_IDX_IDX_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_IDX_VAL_FN_KIND: FuncParamType,
            greater_than_idx_val: CompareIdxValFnRt(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime GREATER_THAN_IDX_VAL: CompareIdxValFnCt(GREATER_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL_FN_KIND: FuncParamType,
            equal_idx_val: CompareIdxValFnRt(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
            comptime EQUAL_IDX_VAL: CompareIdxValFnCt(EQUAL_IDX_VAL_FN_KIND, @TypeOf(compare_ctx), @TypeOf(COMPARE_CTX)),
        ) void {
            self.quicksort_range_advanced(
                start,
                end_excluded,
                SETTINGS,
                compare_ctx,
                COMPARE_CTX,
                LESSER_IDX_VAL_FN_KIND,
                less_than_idx_val,
                LESS_THAN_IDX_VAL,
                GREATER_IDX_IDX_FN_KIND,
                greater_than_idx_idx,
                GREATER_THAN_IDX_IDX,
                GREATER_IDX_VAL_FN_KIND,
                greater_than_idx_val,
                GREATER_THAN_IDX_VAL,
                EQUAL_IDX_VAL_FN_KIND,
                equal_idx_val,
                EQUAL_IDX_VAL,
            );
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
        pub fn quicksort_range(
            self: Self,
            start: IDX,
            end_excluded: IDX,
            less_than_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
            greater_than_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
            greater_than_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
            equal_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
        ) void {
            self.quicksort_range_advanced(
                start,
                end_excluded,
                .{},
                void{},
                void{},
                .RUNTIME_FN_PTR,
                less_than_idx_val,
                void{},
                .RUNTIME_FN_PTR,
                greater_than_idx_idx,
                void{},
                .RUNTIME_FN_PTR,
                greater_than_idx_val,
                void{},
                .RUNTIME_FN_PTR,
                equal_idx_val,
                void{},
            );
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
        pub fn quicksort(
            self: Self,
            less_than_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
            greater_than_idx_idx: *const fn (Self, IDX, IDX, void, void) bool,
            greater_than_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
            equal_idx_val: *const fn (Self, IDX, ELEM, void, void) bool,
        ) void {
            self.quicksort_range_advanced(
                0,
                self.get_len(),
                .{},
                void{},
                void{},
                .RUNTIME_FN_PTR,
                less_than_idx_val,
                void{},
                .RUNTIME_FN_PTR,
                greater_than_idx_idx,
                void{},
                .RUNTIME_FN_PTR,
                greater_than_idx_val,
                void{},
                .RUNTIME_FN_PTR,
                equal_idx_val,
                void{},
            );
        }
    };
}
