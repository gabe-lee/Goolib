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

const build = @import("builtin");
const std = @import("std");
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const math = std.math;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ArrayList = std.ArrayListUnmanaged;
const Type = std.builtin.Type;

const Root = @import("./_root.zig");
const Auto = Root.CommonTypes.Auto;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const assert_pointer_resides_in_slice = Assert.assert_pointer_resides_in_slice;
const assert_slice_resides_in_slice = Assert.assert_slice_resides_in_slice;
const assert_idx_less_than_len = Assert.assert_idx_less_than_len;
const assert_idx_and_pointer_reside_in_slice_and_match = Assert.assert_idx_and_pointer_reside_in_slice_and_match;
const Utils = Root.Utils;
const debug_switch = Utils.debug_switch;
const safe_switch = Utils.safe_switch;
const comp_switch = Utils.comp_switch;
const Types = Root.Types;
const Iterator = Root.Iterator.Iterator;
const IterCaps = Root.Iterator.IteratorCapabilities;
const FlexSlice = Root.FlexSlice.FlexSlice;
const Mutability = Root.CommonTypes.Mutability;
const Quicksort = Root.Quicksort;
const Pivot = Quicksort.Pivot;
const InsertionSort = Root.InsertionSort;
const insertion_sort = InsertionSort.insertion_sort;
const ErrorBehavior = Root.CommonTypes.ErrorBehavior;
const GrowthModel = Root.CommonTypes.GrowthModel;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const DummyAllocator = Root.DummyAllocator;
const BinarySearch = Root.BinarySearch;
const AllocInfal = Root.AllocatorInfallible;

/// Options that define the fundamental behavior and capabilities of the `LinkedHeirarchy`
///
/// Different combinations of these options can fulfill any of the following graph types:
/// - Singly Linked List (Forward AND Backward)
/// - Doubly Linked List
/// - Binary Tree (with or without parent ref)
/// - N-ary/B tree/B+ tree (with specific user care/constraints)
/// - Heirarchy/DOM
/// - Any generic graph where each node has 7 or fewer links
///   - (NOT ideal, but possible, requires careful manual use of functions in `Internal`)
pub const LinkedHeirarchyOptions = struct {
    /// Options for the underlying `List` that holds all the element memory
    /// for this `LinkedHeirarchy`
    element_memory_options: Root.List.ListOptions,
    /// The unsigned integer type used to identify a node
    ///
    /// This must be one of two forms:
    /// - An unsigned integer type exactly equal to `element_memory_options.index_type`
    /// - If `generation_details` != `null`, an unsigned integer type that holds
    /// the index in the lower bits and the generation in the higher bits, as described in
    /// the `generation_details` settings.
    element_id_type: type,
    /// Whether or not items include their generation inside their Id
    ///
    /// If this is not `null`, the option `own_id_field` must also not be null
    ///
    /// When an element caches its 'generation', any time it is sent to the 'free' pool it's generation
    /// increases by one. Any other code trying to aquire an item by index can additionaly check
    /// that the generation they originaly got with the index matches the current generation.
    ///
    /// If they match then it is the 'same' item as originally referenced, if not it should be considered
    /// a 'different' object entirely, which would normally be a kind of 'use-after-free'
    /// error if not caught.
    ///
    /// The generation wraps around to 0 after it reaches its max value, which means there is a *small*
    /// possibility that user code holding an index with an old generation is once again a 'valid'
    /// generation despite being a 'different' item, but the odds are lower the larger the max value for generation is,
    /// and will *never* happen if the generation never rolls over.
    generation_details: ?GenerationDetails = null,
    /// The field on the user element type that will hold the 'prev' sibling
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    prev_sibling_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the 'next' sibling
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    next_sibling_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'parent'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    parent_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'first child on the left side'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    first_left_child_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'last child on the left side'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    last_left_child_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'first child on the right side'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    first_right_child_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'last child on the right side'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    last_right_child_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's own id (if desired).
    /// This should be a field with the same type as `element_id_type`
    ///
    /// This must not be `null` if `generation_details` is also not `null`
    own_id_field: ?[]const u8 = null,
    /// A custom callback that will copy ONLY the 'value' portion of the user element type,
    /// and none of the 'connection' or 'id' fields
    ///
    /// Use this if your user type has a relatively small 'value/data' field(s) in comparison to the size of
    /// all the 'connection/id' type fields, otherwise a less-efficient default copy implementation will
    /// be used
    custom_copy_only_value_fn: ?*const fn (from_elem_ptr: *anyopaque, to_elem_ptr: *anyopaque) void,
    /// Allow slower O(N) fallback routines for finding connecting nodes when elements do no normally
    /// cache the node connection themselves
    allow_slow_fallbacks: bool = false,
};

// pub const GenerationDetailsKind = enum(u8) {
//     NoGeneration = 0,
//     SeparateField = 1,
//     PackedWithCachedIndex = 2,
// };

// pub const SeparateGenerationDetails = struct {
//     field: []const u8,
//     field_type: type,
// };

pub const GenerationDetails = struct {
    index_bits: comptime_int,
    generation_bits: comptime_int,
};

// pub const GenerationDetails = union(GenerationDetailsKind) {
//     NoGeneration: void,
//     SeparateField: SeparateGenerationDetails,
//     PackedWithCachedIndex: PackedGenerationDetails,
// };

// pub const Direction = enum {
//     FORWARD,
//     BACKWARD,
// };

fn assert_field_type_matches_index_type(comptime elem: type, comptime index: type, comptime field: ?[]const u8) usize {
    if (field) |F| {
        assert_with_reason(@hasField(elem, F), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(elem), F });
        const T = @FieldType(elem, F);
        assert_with_reason(T == index, @src(), "field `{s}` on element type `{s}` is not type `{s}`", .{ F, @typeName(elem), @typeName(index) });
        return 1;
    }
    return 0;
}

pub fn LinkedHeirarchy(comptime options: LinkedHeirarchyOptions) type {
    const E = options.element_memory_options.element_type;
    const I = options.element_memory_options.index_type;
    var linkage_count = assert_field_type_matches_index_type(E, I, options.prev_sibling_field);
    linkage_count += assert_field_type_matches_index_type(E, I, options.next_sibling_field);
    linkage_count += assert_field_type_matches_index_type(E, I, options.parent_field);
    linkage_count += assert_field_type_matches_index_type(E, I, options.first_left_child_field);
    linkage_count += assert_field_type_matches_index_type(E, I, options.first_right_child_field);
    linkage_count += assert_field_type_matches_index_type(E, I, options.last_left_child_field);
    linkage_count += assert_field_type_matches_index_type(E, I, options.last_right_child_field);
    assert_with_reason(Types.both_or_neither_null(options.depth_field, options.depth_field_type), @src(), "if `depth_field` is not null, `depth_field_type` must also not be null, and vice-versa", .{});
    if (options.depth_field) |DF| {
        assert_with_reason(Types.type_is_unsigned_int(options.depth_field_type.?), @src(), "`depth_field_type` must be an unsigned integer type", .{});
        _ = assert_field_type_matches_index_type(E, options.depth_field_type.?, DF);
    }
    assert_with_reason(linkage_count > 0, @src(), "LinkedHeirarchy must have at least 1 linkage field", .{});
    const F_LINK = get: {
        if (options.first_left_child_field) |F| break :get F;
        if (options.last_left_child_field) |F| break :get F;
        if (options.first_right_child_field) |F| break :get F;
        if (options.last_right_child_field) |F| break :get F;
        if (options.prev_sibling_field) |F| break :get F;
        if (options.next_sibling_field) |F| break :get F;
        if (options.parent_field) |F| break :get F;
        unreachable;
    };
    assert_with_reason(Types.type_is_unsigned_int(options.element_id_type), @src(), "`options.element_id_type` MUST be an unsigned integer type", .{});
    if (options.generation_details != null) {
        assert_with_reason(options.own_id_field != null, @src(), "`options.generation_details` can only be used when `options.own_id_field` is not null", .{});
        const details = options.generation_details.?;
        const total_bits = details.index_bits + details.generation_bits;
        assert_with_reason(details.index_bits == @bitSizeOf(options.element_memory_options.index_type), @src(), "`options.generation_details.index_bits` MUST equal `@bitSizeOf(options.element_memory_options.index_type)`", .{});
        assert_with_reason(total_bits == @bitSizeOf(options.element_id_type), @src(), "the total bits in `options.generation_details` MUST equal `@bitSizeOf(options.element_id_type)`", .{});
    }
    return struct {
        list: List = List.UNINIT,
        first_free_id: Id = NULL_ID,
        last_free_id: Id = NULL_ID,
        free_count: Id = 0,
        first_root_id: Id = NULL_ID,
        last_root_id: Id = NULL_ID,

        const HAS_NEXT = options.next_sibling_field != null;
        const NEXT_FIELD = if (HAS_NEXT) options.next_sibling_field.? else "";
        const HAS_PREV = options.prev_sibling_field != null;
        const PREV_FIELD = if (HAS_PREV) options.prev_sibling_field.? else "";
        const HAS_PARENT = options.parent_field != null;
        const PARENT_FIELD = if (HAS_PARENT) options.parent_field.? else "";
        const HAS_FIRST_L_CHILD = options.first_left_child_field != null;
        const FIRST_L_CHILD_FIELD = if (HAS_FIRST_L_CHILD) options.first_left_child_field.? else "";
        const HAS_LAST_L_CHILD = options.last_left_child_field != null;
        const LAST_L_CHILD_FIELD = if (HAS_LAST_L_CHILD) options.last_left_child_field.? else "";
        const HAS_FIRST_R_CHILD = options.first_right_child_field != null;
        const FIRST_R_CHILD_FIELD = if (HAS_FIRST_R_CHILD) options.first_right_child_field.? else "";
        const HAS_LAST_R_CHILD = options.last_right_child_field != null;
        const LAST_R_CHILD_FIELD = if (HAS_LAST_R_CHILD) options.last_right_child_field.? else "";
        const FREE_FIELD = F_LINK;
        const ALLOW_SLOW = options.allow_slow_fallbacks;
        const HAS_OWN_ID = options.own_id_field != null;
        const OWN_ID_FIELD = if (HAS_OWN_ID) options.own_id_field.? else "";
        const HAS_GEN = options.generation_details != null;
        const GEN_OFFSET = if (HAS_GEN) options.generation_details.PackedWithCachedIndex.index_bits else 0;
        const IDX_MASK: Id = if (HAS_GEN) (@as(Id, 1) << GEN_OFFSET) - 1 else math.maxInt(Id);
        const IDX_CLEAR: Id = if (HAS_GEN) ~IDX_MASK else 0;
        const GEN_MASK: Id = if (HAS_GEN) ~IDX_MASK else 0;
        const GEN_CLEAR: Id = if (HAS_GEN) IDX_MASK else 0;
        const FREE_FROM_END = options.free_item_order == .FIRST_IN_LAST_OUT;
        const UNINIT = Heirarchy{};
        const UNINIT_ELEM: Elem = make: {
            var elem: Elem = undefined;
            Internal.set_own_id(&elem, NULL_ID);
            Internal.set_prev_sib_id(&elem, NULL_ID);
            Internal.set_next_sib_id(&elem, NULL_ID);
            Internal.set_parent_id(&elem, NULL_ID);
            Internal.set_first_l_child_id(&elem, NULL_ID);
            Internal.set_first_r_child_id(&elem, NULL_ID);
            Internal.set_last_l_child_id(&elem, NULL_ID);
            Internal.set_last_r_child_id(&elem, NULL_ID);
            break :make elem;
        };
        const NULL_ID = math.maxInt(Id);
        const NULL_INDEX = math.maxInt(Index);
        const NULL_GEN = if (HAS_GEN) (NULL_ID & ~IDX_MASK) else 0;
        const GEN_ONE: Id = if (HAS_GEN) @as(Id, 1) << GEN_OFFSET else 1;
        const MUST_PROVIDE_PREV_ID = !HAS_PREV;
        const MUST_PROVIDE_NEXT_ID = !HAS_NEXT;
        const MUST_PROVIDE_PARENT_ID = (HAS_FIRST_L_CHILD or HAS_FIRST_R_CHILD or HAS_LAST_L_CHILD or HAS_LAST_R_CHILD) and !HAS_PARENT;
        const MUST_CHECK_CHILD_KEY_POSITIONS = HAS_PARENT and (HAS_FIRST_L_CHILD or HAS_FIRST_R_CHILD or HAS_LAST_L_CHILD or HAS_LAST_R_CHILD);
        const MUST_CHECK_CHILD_IS_FIRST_LEFT = HAS_PARENT and HAS_FIRST_L_CHILD;
        const MUST_CHECK_CHILD_IS_FIRST_RIGHT = HAS_PARENT and HAS_FIRST_R_CHILD;
        const MUST_CHECK_CHILD_IS_LAST_LEFT = HAS_PARENT and HAS_LAST_L_CHILD;
        const MUST_CHECK_CHILD_IS_LAST_RIGHT = HAS_PARENT and HAS_LAST_R_CHILD;
        const MUST_CHECK_CHILD_IS_FIRST = MUST_CHECK_CHILD_IS_LAST_LEFT or MUST_CHECK_CHILD_IS_LAST_RIGHT;
        const MUST_CHECK_CHILD_IS_LAST = MUST_CHECK_CHILD_IS_LAST_LEFT or MUST_CHECK_CHILD_IS_LAST_RIGHT;
        const CHILD_NODES_COUNT: u8 = @as(u8, @intCast(@intFromBool(HAS_FIRST_L_CHILD))) + @as(u8, @intCast(@intFromBool(HAS_LAST_L_CHILD))) + @as(u8, @intCast(@intFromBool(HAS_FIRST_R_CHILD))) + @as(u8, @intCast(@intFromBool(HAS_LAST_R_CHILD)));
        const MULTIPLE_CHILD_NODES = CHILD_NODES_COUNT > 1;
        const HAS_LEFT_CHILDREN = HAS_FIRST_L_CHILD or HAS_LAST_L_CHILD;
        const HAS_RIGHT_CHILDREN = HAS_FIRST_R_CHILD or HAS_LAST_R_CHILD;
        const HAS_ONLY_ONE_CHILD_SIDE = (HAS_LEFT_CHILDREN and !HAS_RIGHT_CHILDREN) or (HAS_RIGHT_CHILDREN and !HAS_LEFT_CHILDREN);
        const HAS_CHILD_NODES = CHILD_NODES_COUNT > 0;
        const COPY_VAL_FN = options.custom_copy_only_value_fn;
        // const ALLOW_SLOW = options.allow_slow_fallbacks;

        const Heirarchy = @This();
        pub const List = Root.List.List(options.base_memory_options);
        pub const Elem = options.element_memory_options.element_type;
        pub const Index = options.element_memory_options.index_type;
        pub const Id = options.element_id_type;
        pub const GenIndex = struct {
            index: Index = NULL_INDEX,
            gen: if (HAS_GEN) Id else void = if (HAS_GEN) NULL_GEN else void{},
        };
        pub const Item = struct {
            id: Id,
            ptr: *Elem,
        };
        const IdPtrId = struct {
            id_ptr: *Id = &DUMMY_ID,
            id: Id = NULL_ID,
        };
        const FirstLast = struct {
            first: Id = NULL_ID,
            last: Id = NULL_ID,
        };
        const FirstLastParent = struct {
            first: Id = NULL_ID,
            last: Id = NULL_ID,
            parent: Id = NULL_ID,
        };
        const ConnPrev = choose: {
            if (HAS_NEXT and HAS_PREV) break :choose IdPtrId;
            if (HAS_NEXT) break :choose *Id;
            if (HAS_PREV) break :choose Id;
            break :choose void;
        };
        const ConnNext = choose: {
            if (HAS_NEXT and HAS_PREV) break :choose IdPtrId;
            if (HAS_PREV) break :choose *Id;
            if (HAS_NEXT) break :choose Id;
            break :choose void;
        };
        const ConnParent_FirstLeft = choose: {
            if (HAS_PARENT and HAS_FIRST_L_CHILD) break :choose IdPtrId;
            if (HAS_FIRST_L_CHILD) break :choose *Id;
            if (HAS_PARENT) break :choose Id;
            break :choose void;
        };
        const ConnParent_LastLeft = choose: {
            if (HAS_PARENT and HAS_LAST_L_CHILD) break :choose IdPtrId;
            if (HAS_LAST_L_CHILD) break :choose *Id;
            if (HAS_PARENT) break :choose Id;
            break :choose void;
        };
        const ConnParent_FirstRight = choose: {
            if (HAS_PARENT and HAS_FIRST_R_CHILD) break :choose IdPtrId;
            if (HAS_FIRST_R_CHILD) break :choose *Id;
            if (HAS_PARENT) break :choose Id;
            break :choose void;
        };
        const ConnParent_LastRight = choose: {
            if (HAS_PARENT and HAS_LAST_R_CHILD) break :choose IdPtrId;
            if (HAS_LAST_R_CHILD) break :choose *Id;
            if (HAS_PARENT) break :choose Id;
            break :choose void;
        };
        const ConnChild_FirstLeft = choose: {
            if (HAS_PARENT and HAS_FIRST_L_CHILD) break :choose IdPtrId;
            if (HAS_FIRST_L_CHILD) break :choose Id;
            if (HAS_PARENT) break :choose *Id;
            break :choose void;
        };
        const ConnChild_LastLeft = choose: {
            if (HAS_PARENT and HAS_LAST_L_CHILD) break :choose IdPtrId;
            if (HAS_LAST_L_CHILD) break :choose Id;
            if (HAS_PARENT) break :choose *Id;
            break :choose void;
        };
        const ConnChild_FirstRight = choose: {
            if (HAS_PARENT and HAS_FIRST_R_CHILD) break :choose IdPtrId;
            if (HAS_FIRST_R_CHILD) break :choose Id;
            if (HAS_PARENT) break :choose *Id;
            break :choose void;
        };
        const ConnChild_LastRight = choose: {
            if (HAS_PARENT and HAS_LAST_R_CHILD) break :choose IdPtrId;
            if (HAS_LAST_R_CHILD) break :choose Id;
            if (HAS_PARENT) break :choose *Id;
            break :choose void;
        };
        var DUMMY_ID: Id = NULL_ID;
        // var DUMMY_ELEM: Elem = undefined;

        pub inline fn get_gen_index(id: Id) GenIndex {
            if (HAS_GEN) return GenIndex{
                .index = @intCast(id & IDX_MASK),
                .gen = id & GEN_MASK,
            };
            return GenIndex{ .index = @intCast(id & IDX_MASK) };
        }
        pub inline fn same_gen(a: Id, b: Id) bool {
            if (HAS_GEN) return a & GEN_MASK == b & GEN_MASK;
            return true;
        }
        pub inline fn get_index(id: Id) Index {
            return @intCast(id & IDX_MASK);
        }
        pub inline fn get_own_id(ptr: *const Elem) Id {
            if (!HAS_OWN_ID) return NULL_ID;
            return @field(ptr, OWN_ID_FIELD);
        }
        pub inline fn get_index_from_ptr(self: *const Heirarchy, ptr: *const Elem) Index {
            return Utils.index_from_pointer(Elem, Index, self.list.ptr, ptr);
        }
        pub inline fn get_ptr(self: *Heirarchy, id: Id) *Elem {
            const idx = get_index(id);
            assert_idx_less_than_len(idx, self.list.len, @src());
            const ptr = &self.list.ptr[idx];
            if (HAS_GEN) {
                const own_id = get_own_id(ptr);
                assert_with_reason(same_gen(id, own_id), @src(), "generation on id requested did not match the generation stored on element", .{});
            }
            return ptr;
        }
        pub inline fn get_ptr_const(self: *const Heirarchy, id: Id) *const Elem {
            const idx = get_index(id);
            assert_idx_less_than_len(idx, self.list.len, @src());
            const ptr = &self.list.ptr[idx];
            if (HAS_GEN) {
                const own_id = get_own_id(ptr);
                assert_with_reason(same_gen(id, own_id), @src(), "generation on id requested did not match the generation stored on element", .{});
            }
            return ptr;
        }
        pub inline fn get_prev_sib_id(ptr: *const Elem) Id {
            if (!HAS_PREV) return NULL_ID;
            return @field(ptr, PREV_FIELD);
        }
        pub inline fn get_next_sib_id(ptr: *const Elem) Id {
            if (!HAS_NEXT) return NULL_ID;
            return @field(ptr, NEXT_FIELD);
        }
        pub inline fn get_first_left_child_id(ptr: *const Elem) Id {
            if (!HAS_FIRST_L_CHILD) return NULL_ID;
            return @field(ptr, FIRST_L_CHILD_FIELD);
        }
        pub inline fn get_first_right_child_id(ptr: *const Elem) Id {
            if (!HAS_FIRST_R_CHILD) return NULL_ID;
            return @field(ptr, FIRST_R_CHILD_FIELD);
        }
        pub inline fn get_last_left_child_id(ptr: *const Elem) Id {
            if (!HAS_LAST_L_CHILD) return NULL_ID;
            return @field(ptr, LAST_L_CHILD_FIELD);
        }
        pub inline fn get_last_right_child_id(ptr: *const Elem) Id {
            if (!HAS_LAST_R_CHILD) return NULL_ID;
            return @field(ptr, LAST_R_CHILD_FIELD);
        }
        pub inline fn get_parent_id(ptr: *const Elem) Id {
            if (!HAS_PARENT) return NULL_ID;
            return @field(ptr, PARENT_FIELD);
        }

        /// All functions/structs in this namespace fall in at least one of 3 categories:
        /// - DANGEROUS to use if you do not manually manage and maintain a valid linked state
        /// - Are only useful for asserting/creating intenal state
        /// - Cover VERY niche use cases (used internally) and are placed here to keep the top-level namespace less polluted
        ///
        /// They are provided here publicly to facilitate opt-in special user use cases
        pub const Internal = struct {
            pub inline fn set_prev_sib_id(ptr: *Elem, val: Id) void {
                if (!HAS_PREV) return;
                @field(ptr, PREV_FIELD).* = val;
            }
            pub inline fn set_next_sib_id(ptr: *Elem, val: Id) void {
                if (!HAS_NEXT) return;
                @field(ptr, NEXT_FIELD).* = val;
            }
            pub inline fn set_first_l_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_FIRST_L_CHILD) return;
                @field(ptr, FIRST_L_CHILD_FIELD).* = val;
            }
            pub inline fn set_first_r_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_FIRST_R_CHILD) return;
                @field(ptr, FIRST_R_CHILD_FIELD).* = val;
            }
            pub inline fn set_last_l_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_LAST_L_CHILD) return;
                @field(ptr, LAST_L_CHILD_FIELD).* = val;
            }
            pub inline fn set_last_r_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_LAST_R_CHILD) return;
                @field(ptr, LAST_R_CHILD_FIELD).* = val;
            }
            pub inline fn set_parent_id(ptr: *Elem, val: Id) void {
                if (!HAS_PARENT) return;
                @field(ptr, PARENT_FIELD).* = val;
            }
            pub inline fn set_own_id(ptr: *Elem, val: Id) void {
                if (!HAS_OWN_ID) return;
                @field(ptr, OWN_ID_FIELD).* = val;
            }
            pub inline fn set_index(ptr: *Elem, val: Index) void {
                if (!HAS_OWN_ID) return;
                if (HAS_GEN) {
                    @field(ptr, OWN_ID_FIELD).* &= IDX_CLEAR;
                    @field(ptr, OWN_ID_FIELD).* |= @as(Id, @intCast(val));
                } else {
                    @field(ptr, OWN_ID_FIELD).* = @as(Id, @intCast(val));
                }
            }
            pub inline fn increment_gen(ptr: *Elem) void {
                if (!HAS_GEN) return;
                @field(ptr, OWN_ID_FIELD).* += GEN_ONE;
                if (@field(ptr, OWN_ID_FIELD).* & GEN_MASK == GEN_MASK) @field(ptr, OWN_ID_FIELD).* &= GEN_CLEAR;
            }
            pub fn swap_data_only(a: *Elem, b: *Elem) void {
                if (COPY_VAL_FN) |copy| {
                    var temp: Elem = undefined;
                    copy(a, &temp);
                    copy(b, a);
                    copy(&temp, b);
                } else {
                    const old_a = a.*;
                    const old_b = b.*;
                    a.* = old_b;
                    b.* = old_a;
                    if (HAS_PREV) {
                        set_prev_sib_id(a, get_prev_sib_id(old_a));
                        set_prev_sib_id(b, get_prev_sib_id(old_b));
                    }
                    if (HAS_NEXT) {
                        set_next_sib_id(a, get_next_sib_id(old_a));
                        set_next_sib_id(b, get_next_sib_id(old_b));
                    }
                    if (HAS_FIRST_L_CHILD) {
                        set_first_l_child_id(a, get_first_left_child_id(old_a));
                        set_first_l_child_id(b, get_first_left_child_id(old_b));
                    }
                    if (HAS_FIRST_R_CHILD) {
                        set_first_r_child_id(a, get_first_right_child_id(old_a));
                        set_first_r_child_id(b, get_first_right_child_id(old_b));
                    }
                    if (HAS_LAST_L_CHILD) {
                        set_last_l_child_id(a, get_last_left_child_id(old_a));
                        set_last_l_child_id(b, get_last_left_child_id(old_b));
                    }
                    if (HAS_LAST_R_CHILD) {
                        set_last_r_child_id(a, get_last_right_child_id(old_a));
                        set_last_r_child_id(b, get_last_right_child_id(old_b));
                    }
                    if (HAS_PARENT) {
                        set_parent_id(a, get_parent_id(old_a));
                        set_parent_id(b, get_parent_id(old_b));
                    }
                    if (HAS_OWN_ID) {
                        set_own_id(a, get_own_id(old_a));
                        set_own_id(b, get_own_id(old_b));
                    }
                }
            }

            pub inline fn get_conn_prev(self: *const Heirarchy, this_id: Id) ConnPrev {
                if (HAS_NEXT and HAS_PREV) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), NEXT_FIELD),
                };
                if (HAS_NEXT) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), NEXT_FIELD);
                if (HAS_PREV) return this_id;
                return void{};
            }
            pub inline fn get_conn_next(self: *const Heirarchy, this_id: Id) ConnNext {
                if (HAS_NEXT and HAS_PREV) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), NEXT_FIELD),
                };
                if (HAS_PREV) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), NEXT_FIELD);
                if (HAS_NEXT) return this_id;
                return void{};
            }
            pub inline fn get_conn_parent_first_left(self: *const Heirarchy, this_id: Id) ConnParent_FirstLeft {
                if (HAS_PARENT and HAS_FIRST_L_CHILD) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), FIRST_L_CHILD_FIELD),
                };
                if (HAS_FIRST_L_CHILD) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), FIRST_L_CHILD_FIELD);
                if (HAS_PARENT) return this_id;
                return void{};
            }
            pub inline fn get_conn_parent_last_left(self: *const Heirarchy, this_id: Id) ConnParent_LastLeft {
                if (HAS_PARENT and HAS_LAST_L_CHILD) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), LAST_L_CHILD_FIELD),
                };
                if (HAS_LAST_L_CHILD) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), LAST_L_CHILD_FIELD);
                if (HAS_PARENT) return this_id;
                return void{};
            }
            pub inline fn get_conn_parent_first_right(self: *const Heirarchy, this_id: Id) ConnParent_FirstRight {
                if (HAS_PARENT and HAS_FIRST_R_CHILD) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), FIRST_R_CHILD_FIELD),
                };
                if (HAS_FIRST_R_CHILD) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), FIRST_R_CHILD_FIELD);
                if (HAS_PARENT) return this_id;
                return void{};
            }
            pub inline fn get_conn_parent_last_right(self: *const Heirarchy, this_id: Id) ConnParent_LastRight {
                if (HAS_PARENT and HAS_LAST_R_CHILD) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), LAST_R_CHILD_FIELD),
                };
                if (HAS_LAST_R_CHILD) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), LAST_R_CHILD_FIELD);
                if (HAS_PARENT) return this_id;
                return void{};
            }
            pub inline fn get_conn_child_first_left(self: *const Heirarchy, this_id: Id) ConnChild_FirstLeft {
                if (HAS_PARENT and HAS_FIRST_L_CHILD) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), PARENT_FIELD),
                };
                if (HAS_PARENT) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), PARENT_FIELD);
                if (HAS_FIRST_L_CHILD) return this_id;
                return void{};
            }
            pub inline fn get_conn_child_last_left(self: *const Heirarchy, this_id: Id) ConnChild_LastLeft {
                if (HAS_PARENT and HAS_LAST_L_CHILD) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), PARENT_FIELD),
                };
                if (HAS_PARENT) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), PARENT_FIELD);
                if (HAS_LAST_L_CHILD) return this_id;
                return void{};
            }
            pub inline fn get_conn_child_first_right(self: *const Heirarchy, this_id: Id) ConnChild_FirstRight {
                if (HAS_PARENT and HAS_FIRST_R_CHILD) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), PARENT_FIELD),
                };
                if (HAS_PARENT) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), PARENT_FIELD);
                if (HAS_FIRST_R_CHILD) return this_id;
                return void{};
            }
            pub inline fn get_conn_child_last_right(self: *const Heirarchy, this_id: Id) ConnChild_LastRight {
                if (HAS_PARENT and HAS_LAST_R_CHILD) return IdPtrId{
                    .id = this_id,
                    .id_ptr = if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), PARENT_FIELD),
                };
                if (HAS_PARENT) return if (this_id == NULL_ID) &DUMMY_ID else &@field(self.get_ptr(this_id), PARENT_FIELD);
                if (HAS_LAST_R_CHILD) return this_id;
                return void{};
            }
            pub inline fn connect(a: anytype, b: anytype) void {
                const A = @TypeOf(a);
                const B = @TypeOf(b);
                if (A == void and B == void) return;
                if (A == IdPtrId and B == IdPtrId) {
                    a.id_ptr.* = b.id;
                    b.id_ptr.* = a.id;
                    return;
                }
                if (A == Id and B == *Id) {
                    b.* = a;
                    return;
                }
                if (A == *Id and B == Id) {
                    a.* = b;
                    return;
                }
                assert_with_reason(false, @src(), "invalid type pair:  a = {s}, b = {s}", .{ @typeName(A), @typeName(B) });
            }

            pub inline fn connect_siblings(self: *const Heirarchy, prev: Id, next: Id) void {
                const a = get_conn_prev(self, prev);
                const b = get_conn_next(self, next);
                connect(a, b);
            }
            pub inline fn connect_parent_first_left(self: *const Heirarchy, parent: Id, child: Id) void {
                const a = get_conn_parent_first_left(self, parent);
                const b = get_conn_child_first_left(self, child);
                connect(a, b);
            }
            pub inline fn connect_parent_first_right(self: *const Heirarchy, parent: Id, child: Id) void {
                const a = get_conn_parent_first_right(self, parent);
                const b = get_conn_child_first_right(self, child);
                connect(a, b);
            }
            pub inline fn connect_parent_last_left(self: *const Heirarchy, parent: Id, child: Id) void {
                const a = get_conn_parent_last_left(self, parent);
                const b = get_conn_child_last_left(self, child);
                connect(a, b);
            }
            pub inline fn connect_parent_last_right(self: *const Heirarchy, parent: Id, child: Id) void {
                const a = get_conn_parent_last_right(self, parent);
                const b = get_conn_child_last_right(self, child);
                connect(a, b);
            }

            pub fn update_parent_from_siblings(self: *Heirarchy, this_id: Id) void {
                if (HAS_PARENT) {
                    const this_ptr = self.get_ptr(this_id);
                    if (HAS_PREV) {
                        const prev_id = get_prev_sib_id(this_ptr);
                        if (prev_id != NULL_ID) {
                            const prev_ptr = self.get_ptr(prev_id);
                            const parent_id = self.get_parent_id(prev_ptr);
                            set_parent_id(this_ptr, parent_id);
                            return;
                        }
                    }
                    if (HAS_NEXT) {
                        const next_id = get_next_sib_id(this_ptr);
                        if (next_id != NULL_ID) {
                            const next_ptr = self.get_ptr(next_id);
                            const parent_id = self.get_parent_id(next_ptr);
                            set_parent_id(this_ptr, parent_id);
                            return;
                        }
                    }
                    assert_with_reason(false, @src(), "failed to set parent from siblings: no siblings", .{});
                }
            }

            pub fn initialize_new_index(self: *Heirarchy, parent_id: Id) Id {
                const new_id: Id = @intCast(self.list.len);
                var new_elem = UNINIT_ELEM;
                set_own_id(&new_elem, new_id);
                set_parent_id(&new_elem, parent_id);
                _ = self.list.append_assume_capacity(new_elem);
                return new_id;
            }

            pub fn initialize_new_indexes_as_siblings(self: *Heirarchy, count: Index, parent_id: Id) FirstLast {
                const first_id: Id = @intCast(self.list.len);
                var left_id: Id = first_id;
                _ = self.list.append_n_times_assume_capacity(UNINIT_ELEM, count);
                var right_id: Id = left_id + 1;
                const left_ptr = self.get_ptr(left_id);
                var right_ptr = undefined;
                set_own_id(left_ptr, left_id);
                set_parent_id(left_ptr, parent_id);
                const c: Index = 1;
                while (c < count) : (c += 1) {
                    right_ptr = self.get_ptr(right_id);
                    set_own_id(right_ptr, right_id);
                    set_parent_id(right_ptr, parent_id);
                    const left = get_conn_prev(self, left_id);
                    const right = get_conn_next(self, right_id);
                    connect(left, right);
                    left_id += 1;
                    right_id += 1;
                }
                return FirstLast{
                    .first = first_id,
                    .last = left_id,
                };
            }

            pub fn initialize_new_indexes_as_first_left_children(self: *Heirarchy, count: Index, root_parent_id: Id) FirstLast {
                const first_id: Id = @intCast(self.list.len);
                var next_parent_id: Id = first_id;
                _ = self.list.append_n_times_assume_capacity(UNINIT_ELEM, count);
                var child_id: Id = next_parent_id + 1;
                const next_parent_ptr = self.get_ptr(next_parent_id);
                var child_ptr = undefined;
                set_own_id(next_parent_ptr, next_parent_id);
                set_parent_id(next_parent_ptr, root_parent_id);
                var parent_conn = get_conn_parent_first_left(self, root_parent_id);
                var child_conn = get_conn_child_first_left(self, next_parent_id);
                connect(parent_conn, child_conn);
                const c: Index = 1;
                while (c < count) : (c += 1) {
                    child_ptr = self.get_ptr(child_id);
                    set_own_id(child_ptr, child_id);
                    set_parent_id(child_ptr, next_parent_id);
                    parent_conn = get_conn_parent_first_left(self, next_parent_id);
                    child_conn = get_conn_child_first_left(self, child_id);
                    connect(parent_conn, child_conn);
                    next_parent_id += 1;
                    child_id += 1;
                }
                return FirstLast{
                    .first = first_id,
                    .last = next_parent_id,
                };
            }
            pub fn initialize_new_indexes_as_last_left_children(self: *Heirarchy, count: Index, root_parent_id: Id) FirstLast {
                const first_id: Id = @intCast(self.list.len);
                var next_parent_id: Id = first_id;
                _ = self.list.append_n_times_assume_capacity(UNINIT_ELEM, count);
                var child_id: Id = next_parent_id + 1;
                const next_parent_ptr = self.get_ptr(next_parent_id);
                var child_ptr = undefined;
                set_own_id(next_parent_ptr, next_parent_id);
                set_parent_id(next_parent_ptr, root_parent_id);
                var parent_conn = get_conn_parent_last_left(self, root_parent_id);
                var child_conn = get_conn_child_last_left(self, next_parent_id);
                connect(parent_conn, child_conn);
                const c: Index = 1;
                while (c < count) : (c += 1) {
                    child_ptr = self.get_ptr(child_id);
                    set_own_id(child_ptr, child_id);
                    set_parent_id(child_ptr, next_parent_id);
                    parent_conn = get_conn_parent_last_left(self, next_parent_id);
                    child_conn = get_conn_child_last_left(self, child_id);
                    connect(parent_conn, child_conn);
                    next_parent_id += 1;
                    child_id += 1;
                }
                return FirstLast{
                    .first = first_id,
                    .last = next_parent_id,
                };
            }
            pub fn initialize_new_indexes_as_first_right_children(self: *Heirarchy, count: Index, root_parent_id: Id) FirstLast {
                const first_id: Id = @intCast(self.list.len);
                var next_parent_id: Id = first_id;
                _ = self.list.append_n_times_assume_capacity(UNINIT_ELEM, count);
                var child_id: Id = next_parent_id + 1;
                const next_parent_ptr = self.get_ptr(next_parent_id);
                var child_ptr = undefined;
                set_own_id(next_parent_ptr, next_parent_id);
                set_parent_id(next_parent_ptr, root_parent_id);
                var parent_conn = get_conn_parent_first_right(self, root_parent_id);
                var child_conn = get_conn_child_first_right(self, next_parent_id);
                connect(parent_conn, child_conn);
                const c: Index = 1;
                while (c < count) : (c += 1) {
                    child_ptr = self.get_ptr(child_id);
                    set_own_id(child_ptr, child_id);
                    set_parent_id(child_ptr, next_parent_id);
                    parent_conn = get_conn_parent_first_right(self, next_parent_id);
                    child_conn = get_conn_child_first_right(self, child_id);
                    connect(parent_conn, child_conn);
                    next_parent_id += 1;
                    child_id += 1;
                }
                return FirstLast{
                    .first = first_id,
                    .last = next_parent_id,
                };
            }
            pub fn initialize_new_indexes_as_last_right_children(self: *Heirarchy, count: Index, root_parent_id: Id) FirstLast {
                const first_id: Id = @intCast(self.list.len);
                var next_parent_id: Id = first_id;
                _ = self.list.append_n_times_assume_capacity(UNINIT_ELEM, count);
                var child_id: Id = next_parent_id + 1;
                const next_parent_ptr = self.get_ptr(next_parent_id);
                var child_ptr = undefined;
                set_own_id(next_parent_ptr, next_parent_id);
                set_parent_id(next_parent_ptr, root_parent_id);
                var parent_conn = get_conn_parent_last_right(self, root_parent_id);
                var child_conn = get_conn_child_last_right(self, next_parent_id);
                connect(parent_conn, child_conn);
                const c: Index = 1;
                while (c < count) : (c += 1) {
                    child_ptr = self.get_ptr(child_id);
                    set_own_id(child_ptr, child_id);
                    set_parent_id(child_ptr, next_parent_id);
                    parent_conn = get_conn_parent_last_right(self, next_parent_id);
                    child_conn = get_conn_child_last_right(self, child_id);
                    connect(parent_conn, child_conn);
                    next_parent_id += 1;
                    child_id += 1;
                }
                return FirstLast{
                    .first = first_id,
                    .last = next_parent_id,
                };
            }

            pub fn pop_free_item(self: *Heirarchy) Id {
                assert_with_reason(self.free_count > 0 and self.first_free_id != NULL_ID, @src(), "no free items to pop", .{});
                const id = self.first_free_id;
                const ptr = self.get_ptr(id);
                const next_free = @field(ptr, FREE_FIELD);
                self.first_free_id = next_free;
                self.free_count -= 1;
                return id;
            }

            pub fn pop_free_item_set_parent(self: *Heirarchy, parent_id: Id) Id {
                assert_with_reason(self.free_count > 0 and self.first_free_id != NULL_ID, @src(), "no free items to pop", .{});
                const id = self.first_free_id;
                const ptr = self.get_ptr(id);
                const next_free = @field(ptr, FREE_FIELD);
                self.first_free_id = next_free;
                set_parent_id(ptr, parent_id);
                self.free_count -= 1;
                return id;
            }

            pub fn push_free_item(self: *Heirarchy, id: Id) void {
                assert_with_reason(id != NULL_ID, @src(), "cannot push NULL_ID to free list", .{});
                const ptr = self.get_ptr(id);
                if (options.element_memory_options.secure_wipe_bytes) {
                    ptr.* = UNINIT_ELEM;
                } else {
                    set_last_l_child_id(ptr, NULL_ID);
                    set_last_r_child_id(ptr, NULL_ID);
                    set_first_l_child_id(ptr, NULL_ID);
                    set_first_r_child_id(ptr, NULL_ID);
                    set_prev_sib_id(ptr, NULL_ID);
                    set_next_sib_id(ptr, NULL_ID);
                    set_parent_id(ptr, NULL_ID);
                }
                @field(ptr, FREE_FIELD).* = self.first_free_id;
                self.first_free_id = id;
                self.free_count += 1;
            }

            pub fn pop_and_initialize_free_items_as_siblings(self: *Heirarchy, count: Index, parent_id: Id) FirstLast {
                assert_with_reason(count > 0, @src(), "cannot pop 0 free items", .{});
                assert_with_reason(self.free_count >= count, @src(), "too few free items", .{});
                const first_free = pop_free_item(self);
                const prev_ptr = self.get_ptr(first_free);
                set_parent_id(prev_ptr, parent_id);
                var c: Index = 1;
                var prev_id = first_free;
                while (c < count) : (c += 1) {
                    const next_id = pop_free_item(self);
                    const next_ptr = self.get_ptr(next_id);
                    set_parent_id(next_ptr, parent_id);
                    const left = get_conn_prev(self, prev_id);
                    const right = get_conn_next(self, next_id);
                    connect(left, right);
                    prev_id = next_id;
                }
                return FirstLast{
                    .first = first_free,
                    .last = prev_id,
                };
            }

            pub fn pop_and_initialize_free_items_as_first_left_children(self: *Heirarchy, count: Index, first_parent_id: Id) FirstLast {
                assert_with_reason(count > 0, @src(), "cannot pop 0 free items", .{});
                assert_with_reason(self.free_count >= count, @src(), "too few free items", .{});
                const first_free = pop_free_item(self);
                var parent = get_conn_parent_first_left(self, first_parent_id);
                var child = get_conn_child_first_left(self, first_free);
                connect(parent, child);
                var c: Index = 1;
                var prev_id = first_free;
                while (c < count) : (c += 1) {
                    const next_id = pop_free_item(self);
                    parent = get_conn_parent_first_left(self, prev_id);
                    child = get_conn_child_first_left(self, next_id);
                    connect(parent, child);
                    prev_id = next_id;
                }
                return FirstLast{
                    .first = first_free,
                    .last = prev_id,
                };
            }

            pub fn pop_and_initialize_free_items_as_first_right_children(self: *Heirarchy, count: Index, first_parent_id: Id) FirstLast {
                assert_with_reason(count > 0, @src(), "cannot pop 0 free items", .{});
                assert_with_reason(self.free_count >= count, @src(), "too few free items", .{});
                const first_free = pop_free_item(self);
                var parent = get_conn_parent_first_right(self, first_parent_id);
                var child = get_conn_child_first_right(self, first_free);
                connect(parent, child);
                var c: Index = 1;
                var prev_id = first_free;
                while (c < count) : (c += 1) {
                    const next_id = pop_free_item(self);
                    parent = get_conn_parent_first_right(self, prev_id);
                    child = get_conn_child_first_right(self, next_id);
                    connect(parent, child);
                    prev_id = next_id;
                }
                return FirstLast{
                    .first = first_free,
                    .last = prev_id,
                };
            }

            pub fn pop_and_initialize_free_items_as_last_left_children(self: *Heirarchy, count: Index, first_parent_id: Id) FirstLast {
                assert_with_reason(count > 0, @src(), "cannot pop 0 free items", .{});
                assert_with_reason(self.free_count >= count, @src(), "too few free items", .{});
                const first_free = pop_free_item(self);
                var parent = get_conn_parent_last_left(self, first_parent_id);
                var child = get_conn_child_last_left(self, first_free);
                connect(parent, child);
                var c: Index = 1;
                var prev_id = first_free;
                while (c < count) : (c += 1) {
                    const next_id = pop_free_item(self);
                    parent = get_conn_parent_last_left(self, prev_id);
                    child = get_conn_child_last_left(self, next_id);
                    connect(parent, child);
                    prev_id = next_id;
                }
                return FirstLast{
                    .first = first_free,
                    .last = prev_id,
                };
            }

            pub fn pop_and_initialize_free_items_as_last_right_children(self: *Heirarchy, count: Index, first_parent_id: Id) FirstLast {
                assert_with_reason(count > 0, @src(), "cannot pop 0 free items", .{});
                assert_with_reason(self.free_count >= count, @src(), "too few free items", .{});
                const first_free = pop_free_item(self);
                var parent = get_conn_parent_last_right(self, first_parent_id);
                var child = get_conn_child_last_right(self, first_free);
                connect(parent, child);
                var c: Index = 1;
                var prev_id = first_free;
                while (c < count) : (c += 1) {
                    const next_id = pop_free_item(self);
                    parent = get_conn_parent_last_right(self, prev_id);
                    child = get_conn_child_last_right(self, next_id);
                    connect(parent, child);
                    prev_id = next_id;
                }
                return FirstLast{
                    .first = first_free,
                    .last = prev_id,
                };
            }

            pub fn initialize_one_item(self: *Heirarchy, parent_id: Id) Id {
                if (self.free_count > 0) {
                    return pop_free_item_set_parent(self, parent_id);
                } else {
                    const id: Id = @intCast(self.list.len);
                    var new: Elem = UNINIT_ELEM;
                    set_own_id(&new, id);
                    set_parent_id(&new, parent_id);
                    self.list.append_assume_capacity(UNINIT_ELEM);
                    return id;
                }
            }

            pub fn initialize_items_as_siblings(self: *Heirarchy, count: Index, parent_id: Id) FirstLast {
                var result: FirstLast = undefined;
                const from_free = @min(count, self.free_count);
                const from_new = count - from_free;
                if (from_free > 0) {
                    result = pop_and_initialize_free_items_as_siblings(self, from_free, parent_id);
                }
                if (from_new > 0) {
                    const new_result = initialize_new_indexes_as_siblings(self, count, parent_id);
                    if (from_free == 0) {
                        result = new_result;
                    } else {
                        const left = get_conn_prev(self, result.last);
                        const right = get_conn_next(self, new_result.first);
                        connect(left, right);
                        result.last = new_result.last;
                    }
                }
                return result;
            }

            pub fn initialize_items_as_first_left_children(self: *Heirarchy, count: Index, first_parent_id: Id) FirstLast {
                var result: FirstLast = undefined;
                const from_free = @min(count, self.free_count);
                const from_new = count - from_free;
                if (from_free > 0) {
                    result = pop_and_initialize_free_items_as_first_left_children(self, from_free, first_parent_id);
                }
                if (from_new > 0) {
                    if (from_free == 0) {
                        const new_result = pop_and_initialize_free_items_as_first_left_children(self, count, first_parent_id);
                        result = new_result;
                    } else {
                        const new_result = pop_and_initialize_free_items_as_first_left_children(self, count, result.last);
                        result.last = new_result.last;
                    }
                }
                return result;
            }

            pub fn initialize_items_as_first_right_children(self: *Heirarchy, count: Index, first_parent_id: Id) FirstLast {
                var result: FirstLast = undefined;
                const from_free = @min(count, self.free_count);
                const from_new = count - from_free;
                if (from_free > 0) {
                    result = pop_and_initialize_free_items_as_first_right_children(self, from_free, first_parent_id);
                }
                if (from_new > 0) {
                    if (from_free == 0) {
                        const new_result = pop_and_initialize_free_items_as_first_right_children(self, count, first_parent_id);
                        result = new_result;
                    } else {
                        const new_result = pop_and_initialize_free_items_as_first_right_children(self, count, result.last);
                        result.last = new_result.last;
                    }
                }
                return result;
            }

            pub fn initialize_items_as_last_left_children(self: *Heirarchy, count: Index, first_parent_id: Id) FirstLast {
                var result: FirstLast = undefined;
                const from_free = @min(count, self.free_count);
                const from_new = count - from_free;
                if (from_free > 0) {
                    result = pop_and_initialize_free_items_as_last_left_children(self, from_free, first_parent_id);
                }
                if (from_new > 0) {
                    if (from_free == 0) {
                        const new_result = pop_and_initialize_free_items_as_last_left_children(self, count, first_parent_id);
                        result = new_result;
                    } else {
                        const new_result = pop_and_initialize_free_items_as_last_left_children(self, count, result.last);
                        result.last = new_result.last;
                    }
                }
                return result;
            }

            pub fn initialize_items_as_last_right_children(self: *Heirarchy, count: Index, first_parent_id: Id) FirstLast {
                var result: FirstLast = undefined;
                const from_free = @min(count, self.free_count);
                const from_new = count - from_free;
                if (from_free > 0) {
                    result = pop_and_initialize_free_items_as_last_right_children(self, from_free, first_parent_id);
                }
                if (from_new > 0) {
                    if (from_free == 0) {
                        const new_result = pop_and_initialize_free_items_as_last_right_children(self, count, first_parent_id);
                        result = new_result;
                    } else {
                        const new_result = pop_and_initialize_free_items_as_last_right_children(self, count, result.last);
                        result.last = new_result.last;
                    }
                }
                return result;
            }

            // pub fn get_left_right_parent_from_auto_or_ids(self: *Heirarchy, left: anytype, right: anytype, parent: anytype) FirstLastParent {
            //     const L = @TypeOf(left);
            //     const R = @TypeOf(right);
            //     const P = @TypeOf(parent);
            //     assert_with_reason((L == Auto or L == Id), @src(), "invalid type for `left`: {s}, can only be an Auto or Id", .{@typeName(L)});
            //     assert_with_reason((R == Auto or R == Id), @src(), "invalid type for `right`: {s}, can only be an Auto or Id", .{@typeName(R)});
            //     assert_with_reason((P == Auto or P == Id), @src(), "invalid type for `parent`: {s}, can only be an Auto or Id", .{@typeName(P)});
            //     const branch = comptime Utils.bools_to_switchable_integer(3, .{ L != Auto, R != Auto, P != Auto });
            //     var result = FirstLastParent{};
            //     switch (branch) {
            //         // L == Auto, R == Auto, P == Auto
            //         // L == Auto, R == Auto, P == Id
            //         0, 4 => {
            //             assert_with_reason(false, @src(), "cannot infer (Auto) `left` and (Auto) `right`: if parent is `Auto` or NULL_ID this will overwrite and forget entire current heirarchy, and even if Parent is non-null, there is no way to infer at what child position to insert at", .{});
            //         },
            //         1 => { // L == Id, R == Auto, P == Auto
            //             if (left != NULL_ID) {
            //                 result.first = left;
            //                 const l_ptr = self.get_ptr(left);
            //                 if (HAS_PARENT) result.parent = get_parent_id(l_ptr);
            //                 if (HAS_NEXT) result.last = get_next_sib_id(l_ptr);
            //             }
            //         },
            //         2 => { // L == Auto, R == Id, P == Auto
            //             if (right != NULL_ID) {
            //                 result.last = right;
            //                 const r_ptr = self.get_ptr(right);
            //                 if (HAS_PARENT) result.parent = get_parent_id(r_ptr);
            //                 if (HAS_PREV) result.first = get_prev_sib_id(r_ptr);
            //             }
            //         },
            //         3 => { // L == Id, R == Id, P == Auto
            //             const right_non_null = right != null;
            //             const left_non_null = left != null;
            //             if (right_non_null) {
            //                 result.last = right;
            //                 const r_ptr = self.get_ptr(right);
            //                 if (HAS_PARENT) result.parent = get_parent_id(r_ptr);
            //                 if (HAS_PREV) {
            //                     Internal.assert_real_prev_cached_prev_match(self, left, right, @src());
            //                     result.first = get_prev_sib_id(r_ptr);
            //                 }
            //             }
            //             if (left_non_null) {
            //                 result.first = left;
            //                 const l_ptr = self.get_ptr(left);
            //                 if (HAS_PARENT) result.parent = get_parent_id(l_ptr);
            //                 if (HAS_NEXT) {
            //                     Internal.assert_real_next_cached_next_match(self, left, right, @src());
            //                     result.last = get_next_sib_id(l_ptr);
            //                 }
            //             }
            //             if (left_non_null and right_non_null) {
            //                 Internal.assert_siblings_same_parent(self, left, right, @src());
            //             }
            //         },
            //         5 => { // L == Id, R == Auto, P == Id
            //             if (left != NULL_ID) {
            //                 result.first = left;
            //                 result.parent = parent;
            //                 const l_ptr = self.get_ptr(left);
            //                 if (HAS_PARENT) result.parent = get_parent_id(l_ptr);
            //                 if (HAS_NEXT) result.last = get_next_sib_id(l_ptr);
            //             }
            //         },
            //         6 => { // L == Auto, R == Id, P == Id

            //         },
            //         7 => { // L == Id, R == Id, P == Id

            //         },
            //         else => unreachable,
            //     }
            //     const l: Id = switch (L) {
            //         Auto => if (R == Auto) NULL_ID else get_prev: {
            //             assert_with_reason(HAS_PREV, @src(), "`left_id` was type `Auto`, but elements do not cache their 'prev sibling', cannot automatically get `left_id` from `right_id`", .{});
            //             const r_ptr = self.get_ptr(right);
            //             break :get_prev get_prev_sib_id(r_ptr);
            //         },
            //         Id => left,
            //         else => assert_with_reason(false, @src(), "invalid type for `left_id` {s}, can only be an `Id` or `Auto`", .{@typeName(L)}),
            //     };
            //     const r: Id = switch (R) {
            //         Auto => if (L == Auto) NULL_ID else get_next: {
            //             assert_with_reason(HAS_NEXT, @src(), "`right_id` was type `Auto`, but elements do not cache their 'next sibling', cannot automatically get `right_id` from `left_id`", .{});
            //             const l_ptr = self.get_ptr(left);
            //             break :get_next get_next_sib_id(l_ptr);
            //         },
            //         Id => right,
            //         else => assert_with_reason(false, @src(), "invalid type for `right_id` {s}, can only be an `Id` or `Auto`", .{@typeName(R)}),
            //     };
            //     return FirstLast{
            //         .first = l,
            //         .last = r,
            //     };
            // }

            // pub fn get_parent_from_auto_or_ids(self: *Heirarchy, child_a: anytype, child_b: anytype, parent_id: anytype) Id {}

            pub fn get_left_right_from_auto_or_ids(self: *Heirarchy, left: anytype, right: anytype) FirstLast {
                const L = @TypeOf(left);
                const R = @TypeOf(right);
                assert_with_reason((L == Auto or L == Id), @src(), "invalid type for `left`: {s}, can only be an Auto or Id", .{@typeName(L)});
                assert_with_reason((R == Auto or R == Id), @src(), "invalid type for `right`: {s}, can only be an Auto or Id", .{@typeName(R)});
                assert_with_reason(L != Auto or R != Auto, @src(), "cannot infer (Auto) `left` and (Auto) `right`", .{});
                const branch = comptime Utils.bools_to_switchable_integer(2, .{ L != Auto, R != Auto });
                var result = FirstLast{};
                switch (branch) {
                    1 => { // L == Id, R == Auto
                        assert_with_reason(HAS_NEXT, @src(), "cannot find (Auto) right if elements do not cache their 'next' siblings", .{});
                        if (left != NULL_ID) {
                            result.first = left;
                            const l_ptr = self.get_ptr(left);
                            result.last = get_next_sib_id(l_ptr);
                        }
                    },
                    2 => { // L == Auto, R == Id
                        assert_with_reason(HAS_PREV, @src(), "cannot find (Auto) left if elements do not cache their 'prev' siblings", .{});
                        if (right != NULL_ID) {
                            result.last = right;
                            const r_ptr = self.get_ptr(right);
                            result.first = get_prev_sib_id(r_ptr);
                        }
                    },
                    3 => { // L == Id, R == Id
                        if (right != NULL_ID) {
                            result.last = right;
                            if (HAS_PREV) Internal.assert_real_prev_cached_prev_match(self, left, right, @src());
                        }
                        if (left != NULL_ID) {
                            result.first = left;
                            if (HAS_NEXT) Internal.assert_real_next_cached_next_match(self, left, right, @src());
                        }
                    },
                    else => unreachable,
                }
                return result;
            }

            pub fn insert_slots_between_siblings_internal(self: *Heirarchy, left_id: Id, first_new_id: Id, last_new_id: Id, right_id: Id, parent_id: Id) void {
                assert_with_reason(first_new_id != NULL_ID and last_new_id != NULL_ID, @src(), "neither first_new_id nor last_new_id can be NULL_ID", .{});
                Internal.assert_adjacent_siblings_link_to_each_other_and_have_parent(self, left_id, right_id, parent_id, @src());
                const was_first = left_id == NULL_ID;
                const was_last = right_id == NULL_ID;
                const branch = Utils.bools_to_switchable_integer(2, .{ was_first, was_last });
                switch (branch) {
                    0 => { // neither first nor last
                        Internal.connect_siblings(self, left_id, first_new_id);
                        Internal.connect_siblings(self, last_new_id, right_id);
                    },
                    1 => { // first, not last
                        Internal.connect_siblings(self, last_new_id, right_id);
                        if (parent_id != NULL_ID) {
                            if (MUST_CHECK_CHILD_IS_FIRST) {
                                const parent_ptr = self.get_ptr(parent_id);
                                var found_first = false;
                                if (MUST_CHECK_CHILD_IS_LAST_LEFT) {
                                    const parent_first_left = get_first_left_child_id(parent_ptr);
                                    if (parent_first_left == right_id) {
                                        Internal.set_first_l_child_id(parent_ptr, first_new_id);
                                        found_first = true;
                                    }
                                }
                                if (MUST_CHECK_CHILD_IS_LAST_RIGHT) {
                                    const parent_first_right = get_first_right_child_id(parent_ptr);
                                    if (parent_first_right == right_id) {
                                        Internal.set_first_r_child_id(parent_ptr, first_new_id);
                                        found_first = true;
                                    }
                                }
                                assert_with_reason(found_first, @src(), "item (index {d}) was the first sibling with a non-null parent (index {d}), but parent didn't have it cached in either the 'first-left' or 'first-right' field", .{ get_index(right_id), get_index(parent_id) });
                            }
                        } else {
                            assert_with_reason(self.first_root_id == right_id, @src(), "item (index {d}) was the 'first sibling' with a NULL parent, but it wasnt the index cached in 'Heriarchy.first_root_id' ({d})", .{ get_index(right_id), get_index(self.first_root_id) });
                            self.first_root_id = first_new_id;
                        }
                    },
                    2 => { // last, not first
                        Internal.connect_siblings(self, left_id, first_new_id);
                        if (parent_id != NULL_ID) {
                            if (MUST_CHECK_CHILD_IS_LAST) {
                                const parent_ptr = self.get_ptr(parent_id);
                                var found_last = false;
                                if (MUST_CHECK_CHILD_IS_LAST_LEFT) {
                                    const parent_last_left = get_last_left_child_id(parent_ptr);
                                    if (parent_last_left == left_id) {
                                        Internal.set_last_l_child_id(parent_ptr, last_new_id);
                                        found_last = true;
                                    }
                                }
                                if (MUST_CHECK_CHILD_IS_LAST_RIGHT) {
                                    const parent_last_right = get_last_right_child_id(parent_ptr);
                                    if (parent_last_right == left_id) {
                                        Internal.set_last_r_child_id(parent_ptr, last_new_id);
                                        found_last = true;
                                    }
                                }
                                assert_with_reason(false, @src(), "item (index {d}) was the last sibling with a non-null parent (index {d}), but parent didn't have it cached in either the 'last-left' or 'last-right' field", .{ get_index(left_id), get_index(parent_id) });
                            }
                        } else {
                            assert_with_reason(self.last_root_id == left_id, @src(), "item (index {d}) was the 'last sibling' with a NULL parent, but it wasnt the index cached in 'Heriarchy.first_root_id' ({d})", .{ get_index(left_id), get_index(self.last_root_id) });
                            self.last_root_id = last_new_id;
                        }
                    },
                    3 => { // last AND first
                        if (parent_id != null) {
                            const parent_ptr = self.get_ptr(parent_id);
                            assert_with_reason(HAS_ONLY_ONE_CHILD_SIDE, @src(), "cannot infer which side (left/right) to add new child node to on parent with multiple child sides when no siblings exist for new child node to infer the correct side", .{});
                            if (HAS_FIRST_L_CHILD) set_first_l_child_id(parent_ptr, first_new_id);
                            if (HAS_FIRST_R_CHILD) set_first_r_child_id(parent_ptr, first_new_id);
                            if (HAS_LAST_L_CHILD) set_last_l_child_id(parent_ptr, last_new_id);
                            if (HAS_LAST_R_CHILD) set_last_r_child_id(parent_ptr, last_new_id);
                        } else {
                            assert_with_reason(self.first_root_id == NULL_ID and self.last_root_id == NULL_ID, @src(), "adding a 'new sibling' between 2 NULL_ID siblings, and with a NULL_ID parent implies that you are adding the first node to the root of the list. HOWEVER, `first_root_id` and `last_root_id` did not equal NULL_ID. This would cause the entire existing list to be 'leaked' and forgotten/lost and replaced with the new node", .{});
                            self.first_root_id = first_new_id;
                            self.last_root_id = last_new_id;
                        }
                    },
                    else => unreachable,
                }
            }

            pub fn insert_slot_as_next_sibling_internal(self: *Heirarchy, this_id: Id, parent_id: Id) Id {
                assert_with_reason(HAS_NEXT, @src(), "cannot directly insert slot to next sibling when items are not linked to their next sibling", .{});
                const index = get_index(this_id);
                assert_with_reason(index < self.list.len, @src(), "id {x}: index {d} out of bounds for element memory list (len = {d})", .{ this_id, index, self.list.len });
                const this_ptr = get_ptr(self, this_id);
                const old_next_id = self.get_next_sib_id(this_ptr);
                const was_last = old_next_id == NULL_ID;
                const new_next_id = Internal.initialize_one_item(self, parent_id);
                Internal.connect_siblings(self, this_id, new_next_id);
                if (was_last) {
                    if (parent_id != NULL_ID) {
                        if (MUST_CHECK_CHILD_IS_LAST) {
                            const parent_ptr = self.get_ptr(this_id);
                            var found_last: bool = false;
                            if (MUST_CHECK_CHILD_IS_LAST_LEFT) {
                                const parent_last_left = get_last_left_child_id(parent_ptr);
                                if (parent_last_left == this_id) {
                                    Internal.set_last_l_child_id(parent_ptr, new_next_id);
                                    found_last = true;
                                }
                            }
                            if (MUST_CHECK_CHILD_IS_LAST_RIGHT) {
                                const parent_last_right = get_last_right_child_id(parent_ptr);
                                if (parent_last_right == this_id) {
                                    Internal.set_last_r_child_id(parent_ptr, new_next_id);
                                    found_last = true;
                                }
                            }
                            assert_with_reason(false, @src(), "item (index {d}) was the last sibling with a non-null parent (index {d}), but parent didn't have it cached in either the 'last-left' or 'last-right' field", .{ get_index(this_id), get_index(parent_id) });
                        }
                    } else {
                        assert_with_reason(self.last_root_id == this_id, @src(), "item (index {d}) was the 'last sibling' with a NULL parent, but it wasnt the index cached in 'Heriarchy.last_root_id' ({d})", .{ get_index(this_id), get_index(self.last_root_id) });
                        self.last_root_id = new_next_id;
                    }
                } else {
                    Internal.connect_siblings(self, new_next_id, old_next_id);
                }
                return new_next_id;
            }

            pub fn disconnect_sibling_internal(self: *Heirarchy, prev_id: Id, this_id: Id, next_id: Id, parent_id: Id) void {
                const conn_left: ConnPrev = get_conn_prev(self, prev_id);
                const conn_right: ConnPrev = get_conn_next(self, next_id);
                if (prev_id == NULL_ID) {
                    if (parent_id != NULL_ID) {
                        if (MUST_CHECK_CHILD_IS_FIRST) {
                            const parent_ptr = self.get_ptr(this_id);
                            var found_first: bool = false;
                            if (MUST_CHECK_CHILD_IS_LAST_LEFT) {
                                const parent_first_left = get_first_left_child_id(parent_ptr);
                                if (parent_first_left == this_id) {
                                    Internal.set_first_l_child_id(parent_ptr, next_id);
                                    found_first = true;
                                }
                            }
                            if (MUST_CHECK_CHILD_IS_LAST_RIGHT) {
                                const parent_first_right = get_first_right_child_id(parent_ptr);
                                if (parent_first_right == this_id) {
                                    Internal.set_first_r_child_id(parent_ptr, next_id);
                                    found_first = true;
                                }
                            }
                            assert_with_reason(false, @src(), "item (index {d}) was the first sibling with a non-null parent (index {d}), but parent didn't have it cached in either the 'first-left' or 'first-right' field", .{ get_index(this_id), get_index(parent_id) });
                        }
                    } else {
                        assert_with_reason(self.first_root_id == this_id, @src(), "item (index {d}) was the 'first sibling' with a NULL parent, but it wasnt the index cached in 'Heriarchy.first_root_id' ({d})", .{ get_index(this_id), get_index(self.first_root_id) });
                        self.first_root_id = next_id;
                    }
                }
                if (next_id == NULL_ID) {
                    if (parent_id != NULL_ID) {
                        if (MUST_CHECK_CHILD_IS_LAST) {
                            const parent_ptr = self.get_ptr(this_id);
                            var found_last: bool = false;
                            if (MUST_CHECK_CHILD_IS_LAST_LEFT) {
                                const parent_last_left = get_last_left_child_id(parent_ptr);
                                if (parent_last_left == this_id) {
                                    Internal.set_last_l_child_id(parent_ptr, prev_id);
                                    found_last = true;
                                }
                            }
                            if (MUST_CHECK_CHILD_IS_LAST_RIGHT) {
                                const parent_last_right = get_last_right_child_id(parent_ptr);
                                if (parent_last_right == this_id) {
                                    Internal.set_last_r_child_id(parent_ptr, prev_id);
                                    found_last = true;
                                }
                            }
                            assert_with_reason(false, @src(), "item (index {d}) was the ;last sibling with a non-null parent (index {d}), but parent didn't have it cached in either the 'last-left' or 'last-right' field", .{ get_index(this_id), get_index(parent_id) });
                        }
                    } else {
                        assert_with_reason(self.last_root_id == this_id, @src(), "item (index {d}) was the 'last sibling' with a NULL parent, but it wasnt the index cached in 'Heriarchy.last_root_id' ({d})", .{ get_index(this_id), get_index(self.last_root_id) });
                        self.last_root_id = next_id;
                    }
                }
                Internal.connect(conn_left, conn_right);
                const this_ptr = self.get_ptr(this_id);
                set_parent_id(this_ptr, NULL_ID);
                set_prev_sib_id(this_ptr, NULL_ID);
                set_next_sib_id(this_ptr, NULL_ID);
            }

            fn assert_real_prev_cached_prev_match(self: *Heirarchy, real_prev: Id, real_next: Id, src_loc: ?SourceLocation) void {
                const cached_prev = get_prev_sib_id(self.get_ptr(real_next));
                assert_with_reason(real_prev == cached_prev, src_loc, "real prev id (gen = {d}, idx = {d}) does not match the cached prev id (gen = {d}, idx = {d}) on the next sibling (gen = {d}, idx = {d})", .{ get_gen_index(real_prev).gen, get_index(real_prev), get_gen_index(cached_prev).gen, get_index(cached_prev), get_gen_index(real_next).gen, get_index(real_next) });
            }

            fn assert_real_next_cached_next_match(self: *Heirarchy, real_prev: Id, real_next: Id, src_loc: ?SourceLocation) void {
                const cached_next = get_next_sib_id(self.get_ptr(real_prev));
                assert_with_reason(real_next == cached_next, src_loc, "real next id (gen = {d}, idx = {d}) does not match the cached next id (gen = {d}, idx = {d}) on the prev sibling (gen = {d}, idx = {d})", .{ get_gen_index(real_next).gen, get_index(real_next), get_gen_index(cached_next).gen, get_index(cached_next), get_gen_index(real_prev).gen, get_index(real_prev) });
            }

            fn assert_adjacent_siblings_link_to_each_other_and_have_parent(self: *Heirarchy, left: Id, right: Id, parent: Id, src_loc: ?SourceLocation) void {
                if (HAS_NEXT and left != NULL_ID) assert_real_next_cached_next_match(self, left, right, src_loc);
                if (HAS_PREV and right != NULL_ID) assert_real_prev_cached_prev_match(self, left, right, src_loc);
                if (HAS_PARENT and left != NULL_ID) assert_cached_parent_matches_provided(self, left, parent, src_loc);
                if (HAS_PARENT and right != NULL_ID) assert_cached_parent_matches_provided(self, right, parent, src_loc);
            }

            fn assert_cached_parent_matches_provided(self: *Heirarchy, child: Id, parent: Id, src_loc: ?SourceLocation) void {
                const parent_cached = get_parent_id(self.get_ptr(child));
                assert_with_reason(parent_cached == parent, src_loc, "child (gen = {d}, idx = {d}) -> parent (gen = {d}, idx = {d}) does not match the given parent (gen = {d}, idx = {d})", .{ get_gen_index(child).gen, get_index(child), get_gen_index(parent_cached).gen, get_index(parent_cached), get_gen_index(parent).gen, get_index(parent) });
            }

            fn assert_siblings_same_parent(self: *Heirarchy, a: Id, b: Id, src_loc: ?SourceLocation) void {
                const a_parent = get_parent_id(self.get_ptr(a));
                const b_parent = get_parent_id(self.get_ptr(b));
                assert_with_reason(a == b, src_loc, "sibling id A (gen = {d}, idx = {d}) -> parent (gen = {d}, idx = {d}) does not match the sibling id B (gen = {d}, idx = {d}) -> parent (gen = {d}, idx = {d})", .{ get_gen_index(a).gen, get_index(a), get_gen_index(a_parent).gen, get_index(a_parent), get_gen_index(b).gen, get_index(b), get_gen_index(b_parent).gen, get_index(b_parent) });
            }

            // pub fn disconnect_one(self: *Heirarchy, list: ListTag, idx: Index) void {
            //     const disconn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, idx, idx, list);
            //     Internal.connect(disconn.left, disconn.right);
            //     Internal.decrease_link_set_count(self, list, 1);
            // }

            // pub fn disconnect_many_first_last(self: *Heirarchy, list: ListTag, first_idx: Index, last_idx: Index, count: Index) void {
            //     const disconn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, first_idx, last_idx, list);
            //     Internal.connect(disconn.left, disconn.right);
            //     Internal.decrease_link_set_count(self, list, count);
            // }

            // pub fn get_conn_left_right_directly_before_this_valid_index(self: *Heirarchy, this_idx: Index, list: ListTag) ConnLeftRight {
            //     var result: ConnLeftRight = undefined;
            //     const prev_idx = self.get_prev_idx(this_idx);
            //     result.right = Internal.get_conn_right_valid_index(self, this_idx);
            //     result.left = Internal.get_conn_left(self, list, prev_idx, this_idx);
            //     return result;
            // }

            // pub fn get_conn_left_right_from_first_child_position(self: *Heirarchy, parent_idx: Index) ConnLeftRight {
            //     var result: ConnLeftRight = undefined;
            //     result.left = Internal.get_conn_left_from_first_child(self, parent_idx);
            //     const first_child_idx = self.get_first_child(parent_idx);
            //     if (first_child_idx != NULL_ID) {
            //         result.right = Internal.get_conn_right_valid_index(self, first_child_idx);
            //     } else if (LAST_CHILD) {
            //         result.right = Internal.get_conn_right_from_last_child(self, parent_idx);
            //     } else {
            //         result.right = Internal.get_conn_right_dummy_end();
            //     }
            //     return result;
            // }

            // pub fn get_conn_left_right_from_last_child_position(self: *Heirarchy, parent_idx: Index) ConnLeftRight {
            //     var result: ConnLeftRight = undefined;
            //     result.right = Internal.get_conn_right_from_last_child(self, parent_idx);
            //     const last_child_idx = self.get_last_child(parent_idx);
            //     if (last_child_idx != NULL_ID) {
            //         result.left = Internal.get_conn_left_valid_index(self, last_child_idx);
            //     } else if (FIRST_CHILD) {
            //         result.left = Internal.get_conn_left_from_first_child(self, parent_idx);
            //     } else {
            //         result.left = Internal.get_conn_left_dummy_end();
            //     }
            //     return result;
            // }

            // pub fn get_conn_left_right_directly_after_this_valid_index(self: *Heirarchy, this_idx: Index, list: ListTag) ConnLeftRight {
            //     var result: ConnLeftRight = undefined;
            //     const next_idx = self.get_next_idx(this_idx);
            //     result.left = Internal.get_conn_left_valid_index(self, this_idx);
            //     result.right = Internal.get_conn_right(self, list, next_idx, this_idx);
            //     return result;
            // }

            // pub fn get_conn_left_right_before_first_and_after_last_valid_indexes(self: *Heirarchy, first_idx: Index, last_idx: Index, list: ListTag) ConnLeftRight {
            //     var result: ConnLeftRight = undefined;
            //     const left_idx = self.get_prev_idx(list, first_idx);
            //     const right_idx = self.get_next_idx(list, last_idx);
            //     result.left = Internal.get_conn_left(self, list, left_idx, first_idx);
            //     result.right = Internal.get_conn_right(self, list, right_idx, last_idx);
            //     return result;
            // }

            // pub fn get_conn_left_right_for_tail_of_list(self: *Heirarchy, list: ListTag) ConnLeftRight {
            //     const last_index = self.get_last_index_in_list(list);
            //     var conn: ConnLeftRight = undefined;
            //     conn.right = Internal.get_conn_right_from_list_tail(self, list);
            //     if (last_index != NULL_ID) {
            //         conn.left = Internal.get_conn_left_valid_index(self, last_index);
            //     } else {
            //         conn.left = Internal.get_conn_left_from_list_head(self, list);
            //     }
            //     return conn;
            // }

            // pub fn get_conn_left_right_for_head_of_list(self: *Heirarchy, list: ListTag) ConnLeftRight {
            //     const first_index = self.get_first_index_in_list(list);
            //     var conn: ConnLeftRight = undefined;
            //     conn.left = Internal.get_conn_left_from_list_head(self, list);
            //     if (first_index != NULL_ID) {
            //         conn.right = Internal.get_conn_right_valid_index(self, first_index);
            //     } else {
            //         conn.right = Internal.get_conn_right_from_list_tail(self, list);
            //     }
            //     return conn;
            // }

            // pub fn traverse_backward_to_get_first_index_in_list_from_start_index(self: *const Heirarchy, start_idx: Index) Index {
            //     var first_idx: Index = NULL_ID;
            //     var curr_idx = start_idx;
            //     var c: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) 0 else void{};
            //     const limit: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) @as(Index, @intCast(self.list.len)) else void{};
            //     while (curr_idx != NULL_ID) {
            //         first_idx = curr_idx;
            //         if (STRONG_ASSERT) c += 1;
            //         curr_idx = get_prev_idx(self, curr_idx.ptr);
            //     }
            //     if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in backward direction without finding a NULL_IDX: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx });
            //     return first_idx;
            // }

            // pub fn traverse_forward_to_get_last_index_in_list_from_start_index(self: *const Heirarchy, start_idx: Index) Index {
            //     var last_idx: Index = NULL_ID;
            //     var curr_idx = start_idx;
            //     var c: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) 0 else void{};
            //     const limit: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) @as(Index, @intCast(self.list.len)) else void{};
            //     while (curr_idx != NULL_ID) {
            //         last_idx = curr_idx;
            //         if (STRONG_ASSERT) c += 1;
            //         curr_idx = get_next_idx(self, curr_idx.ptr);
            //     }
            //     if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in forward direction without finding a NULL_IDX: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx });
            //     return last_idx;
            // }

            // pub fn traverse_forward_from_idx_and_report_if_found_target_idx(self: *Heirarchy, start_idx: Index, target_idx: Index) bool {
            //     var curr_idx: Index = start_idx;
            //     var c: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) 0 else void{};
            //     const limit: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) @as(Index, @intCast(self.list.len)) else void{};
            //     while (curr_idx != NULL_ID and (if (STRONG_ASSERT) c <= limit else true)) {
            //         if (curr_idx == target_idx) return true;
            //         curr_idx = get_next_idx(self, curr_idx);
            //         if (STRONG_ASSERT) c += 1;
            //     }
            //     if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in forward direction without finding target index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx, target_idx });
            //     return false;
            // }

            // pub fn traverse_all_lists_forward_and_report_list_found_in(self: *Heirarchy, this_idx: Index) ListTag {
            //     var t: ListTagInt = 0;
            //     var idx: Index = undefined;
            //     while (t < UNTRACKED_LIST_RAW) : (t += 1) {
            //         idx = self.get_first_index_in_list(@enumFromInt(t));
            //         while (idx != NULL_ID) {
            //             if (idx == this_idx) return @enumFromInt(t);
            //             idx = self.get_next_idx(idx);
            //         }
            //     }
            //     return UNTRACKED_LIST;
            // }
            // pub fn traverse_all_lists_backward_and_report_list_found_in(self: *Heirarchy, this_idx: Index) ListTag {
            //     var t: ListTagInt = 0;
            //     var idx: Index = undefined;
            //     while (t < UNTRACKED_LIST_RAW) : (t += 1) {
            //         idx = self.get_last_index_in_list(@enumFromInt(t));
            //         while (idx != NULL_ID) {
            //             if (idx == this_idx) return @enumFromInt(t);
            //             idx = self.get_prev_idx(idx);
            //         }
            //     }
            //     return UNTRACKED_LIST;
            // }

            // pub fn traverse_backward_from_idx_and_report_if_found_target_idx(self: *Heirarchy, start_idx: Index, target_idx: Index) bool {
            //     var curr_idx: Index = start_idx;
            //     var c: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) 0 else void{};
            //     const limit: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) @as(Index, @intCast(self.list.len)) else void{};
            //     while (curr_idx != NULL_ID and (if (STRONG_ASSERT) c <= limit else true)) {
            //         if (curr_idx == target_idx) return true;
            //         curr_idx = get_prev_idx(self, curr_idx);
            //         if (STRONG_ASSERT) c += 1;
            //     }
            //     if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in forward direction without finding target index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx, target_idx });
            //     return false;
            // }

            // pub fn traverse_to_find_index_before_this_one_forward_from_known_idx_before(self: Heirarchy, this_idx: Index, known_prev: Index) Index {
            //     var curr_idx: Index = known_prev;
            //     var c: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) 0 else void{};
            //     const limit: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) @as(Index, @intCast(self.list.len)) else void{};
            //     while (curr_idx != NULL_ID and (if (STRONG_ASSERT) c <= limit else true)) {
            //         assert_with_reason(curr_idx < self.list.len, @src(), "while traversing forward from index {d}, index {d} was found, which is out of bounds for list.len {d}, but is not NULL_IDX", .{ known_prev, curr_idx, self.list.len });
            //         const next_idx = self.get_next_idx(curr_idx);
            //         if (next_idx == this_idx) return curr_idx;
            //         curr_idx = next_idx;
            //         if (STRONG_ASSERT) c += 1;
            //     }
            //     if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from 'known prev' index {d} in forward direction without finding this index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, known_prev, this_idx });
            //     assert_with_reason(false, @src(), "no item found referencing index {d} while traversing from index {d} in forward direction: broken list or `known_prev` wasn't actually before `idx`", .{ this_idx, known_prev });
            // }

            // pub fn traverse_to_find_index_after_this_one_backward_from_known_idx_after(self: Heirarchy, this_idx: Index, known_next: Index) Index {
            //     var curr_idx: Index = undefined;
            //     var c: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) 0 else void{};
            //     const limit: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) @as(Index, @intCast(self.list.len)) else void{};
            //     curr_idx = known_next;
            //     while (curr_idx != NULL_ID and (if (STRONG_ASSERT) c <= limit else true)) {
            //         assert_with_reason(curr_idx < self.list.len, @src(), "while traversing backward from index {d}, index {d} was found, which is out of bounds for list.len {d}, but is not NULL_IDX", .{ known_next, curr_idx, self.list.len });
            //         const prev_idx = self.get_prev_idx(curr_idx);
            //         if (prev_idx == this_idx) return curr_idx;
            //         curr_idx = prev_idx;
            //         if (STRONG_ASSERT) c += 1;
            //     }
            //     if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from 'known next' index {d} in backward direction without finding this index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, known_next, this_idx });
            //     assert_with_reason(false, @src(), "no item found referencing index {d} while traversing from index {d} in backward direction: broken list or `known_next` wasn't actually after `idx`", .{ this_idx, known_next });
            // }

            // pub inline fn get_list_tag_raw(ptr: *const Elem) ListTagInt {
            //     return @as(ListTagInt, @intCast((@field(ptr, STATE_FIELD) & STATE_MASK) >> STATE_OFFSET));
            // }

            // pub fn assert_valid_list_idx(self: *Heirarchy, idx: Index, list: ListTag, comptime src_loc: ?SourceLocation) void {
            //     if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
            //         assert_idx_less_than_len(idx, self.list.len, src_loc);
            //         const ptr = get_ptr(self, idx);
            //         if (STATE) assert_with_reason(get_list_tag_raw(ptr) == @intFromEnum(list), src_loc, "set {s} on SetIdx does not match list on elem at idx {d}", .{ @tagName(list), idx });
            //         if (STRONG_ASSERT) {
            //             const found_in_list = if (FORWARD) Internal.traverse_forward_from_idx_and_report_if_found_target_idx(self, self.get_first_index_in_list(list), idx) else Internal.traverse_backward_from_idx_and_report_if_found_target_idx(self, self.get_last_index_in_list(list), idx);
            //             assert_with_reason(found_in_list, src_loc, "while verifying idx {d} is in set {s}, the idx was not found when traversing the set", .{ idx, @tagName(list) });
            //         }
            //     }
            // }
            // pub fn assert_valid_list_idx_list(self: *Heirarchy, list: ListTag, indexes: []const Index, comptime src_loc: ?SourceLocation) void {
            //     if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
            //         for (indexes) |idx| {
            //             Internal.assert_valid_list_idx(self, idx, list, src_loc);
            //         }
            //     }
            // }
            // pub fn assert_valid_list_of_list_idxs(self: *Heirarchy, set_idx_list: []const ListIdx, comptime src_loc: ?SourceLocation) void {
            //     if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
            //         for (set_idx_list) |list_idx| {
            //             Internal.assert_valid_list_idx(self, list_idx.idx, list_idx.list, src_loc);
            //         }
            //     }
            // }

            // pub fn assert_valid_slice(self: *Heirarchy, slice: LLSlice, comptime src_loc: ?SourceLocation) void {
            //     assert_idx_less_than_len(slice.first, self.list.len, src_loc);
            //     assert_idx_less_than_len(slice.last, self.list.len, src_loc);
            //     if (!STRONG_ASSERT and STATE) {
            //         assert_with_reason(self.index_is_in_list(slice.first, slice.list), src_loc, "first index {d} is not in list `{s}`", .{ slice.first, @tagName(slice.list) });
            //         assert_with_reason(self.index_is_in_list(slice.last, slice.list), src_loc, "last index {d} is not in list `{s}`", .{ slice.last, @tagName(slice.list) });
            //     }
            //     if (STRONG_ASSERT) {
            //         var c: Index = 1;
            //         var idx = if (FORWARD) slice.first else slice.last;
            //         assert_idx_less_than_len(idx, self.list.len, @src());
            //         const list = slice.list;
            //         const last_idx = if (FORWARD) slice.last else slice.first;
            //         Internal.assert_valid_list_idx(self, IndexInList{ .list = list, .idx = idx }, src_loc);
            //         while (idx != last_idx and idx != NULL_ID) {
            //             idx = if (FORWARD) self.get_next_idx(slice.list, idx) else self.get_prev_idx(idx);
            //             c += 1;
            //             Internal.assert_valid_list_idx(self, IndexInList{ .list = list, .idx = idx }, src_loc);
            //         }
            //         assert_with_reason(idx == last_idx, src_loc, "idx `first` ({d}) is not linked with idx `last` ({d})", .{ slice.first, slice.last });
            //         assert_with_reason(c == slice.count, src_loc, "the slice count {d} did not match the number of traversed items between `first` and `last` ({d})", .{ slice.count, c });
            //     }
            // }

            // fn get_items_and_insert_at_internal(self: *Heirarchy, get_from: anytype, insert_to: anytype, alloc: Allocator, comptime ASSUME_CAP: bool) if (!ASSUME_CAP and RETURN_ERRORS) Error!LLSlice else LLSlice {
            //     const FROM = @TypeOf(get_from);
            //     const TO = @TypeOf(insert_to);
            //     var insert_edges: ConnLeftRight = undefined;
            //     var insert_list: ListTag = undefined;
            //     var insert_untracked: bool = false;
            //     var insert_parent: Index = NULL_ID;
            //     switch (TO) {
            //         Insert.AfterIndex => {
            //             const idx: Index = insert_to.idx;
            //             assert_idx_less_than_len(idx, self.list.len, @src());
            //             const list: ListTag = self.get_list_tag(idx);
            //             insert_edges = Internal.get_conn_left_right_directly_after_this_valid_index(self, idx, list);
            //             insert_list = list;
            //             insert_parent = self.get_parent_idx(idx);
            //         },
            //         Insert.AfterIndexInList => {
            //             const idx: Index = insert_to.idx;
            //             const list: Index = insert_to.list;
            //             assert_valid_list_idx(self, idx, list, @src());
            //             insert_edges = Internal.get_conn_left_right_directly_after_this_valid_index(self, idx, list);
            //             insert_list = list;
            //             insert_parent = self.get_parent_idx(idx);
            //         },
            //         Insert.BeforeIndex => {
            //             const idx: Index = insert_to.idx;
            //             assert_idx_less_than_len(idx, self.list.len, @src());
            //             const list: ListTag = self.get_list_tag(idx);
            //             insert_edges = Internal.get_conn_left_right_directly_before_this_valid_index(self, idx, list);
            //             insert_list = list;
            //             insert_parent = self.get_parent_idx(idx);
            //         },
            //         Insert.BeforeIndexInList => {
            //             const idx: Index = insert_to.idx;
            //             const list: Index = insert_to.list;
            //             assert_valid_list_idx(self, idx, list, @src());
            //             insert_edges = Internal.get_conn_left_right_directly_before_this_valid_index(self, idx, list);
            //             insert_list = list;
            //             insert_parent = self.get_parent_idx(idx);
            //         },
            //         Insert.AtBeginningOfList => {
            //             const list: ListTag = insert_to.list;
            //             assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot insert to beginning of the 'untracked' list (it has no begining or end)", .{});
            //             insert_edges = Internal.get_conn_left_right_for_head_of_list(self, list);
            //             insert_list = list;
            //         },
            //         Insert.AtEndOfList => {
            //             const list: ListTag = insert_to.list;
            //             assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot insert to end of the 'untracked' list (it has no begining or end)", .{});
            //             insert_edges = Internal.get_conn_left_right_for_tail_of_list(self, list);
            //             insert_list = list;
            //         },
            //         Insert.AtBeginningOfChildren => {
            //             assert_with_reason(FIRST_CHILD or (LAST_CHILD and BACKWARD), @src(), "cannot insert at beginning of children when items do not cache either the first child index, or last child index and is also linked in backward direction", .{});
            //             const parent_idx: Index = insert_to.parent_idx;
            //             assert_idx_less_than_len(parent_idx, self.list.len, @src());
            //             insert_parent = parent_idx;
            //             if (FIRST_CHILD) {
            //                 insert_edges = Internal.get_conn_left_right_from_first_child_position(self, parent_idx);
            //                 insert_list = UNTRACKED_LIST;
            //             } else {
            //                 assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks not allowed", .{});
            //                 const last_child_idx = self.get_last_child(parent_idx);
            //                 const first_child_idx = Internal.traverse_backward_to_get_first_index_in_list_from_start_index(self, last_child_idx);
            //                 insert_edges.left = Internal.get_conn_left_dummy_end();
            //                 insert_edges.right = if (first_child_idx != NULL_ID) Internal.get_conn_right_valid_index(self, first_child_idx) else Internal.get_conn_right_from_last_child(self, parent_idx);
            //                 insert_list = UNTRACKED_LIST;
            //             }
            //         },
            //         Insert.AtEndOfChildren => {
            //             assert_with_reason(LAST_CHILD or (FIRST_CHILD and FORWARD), @src(), "cannot insert children when items do not cache either the first child index, or last child index and is also linked in backward direction", .{});
            //             const parent_idx: Index = insert_to.parent_idx;
            //             assert_idx_less_than_len(parent_idx, self.list.len, @src());
            //             insert_parent = parent_idx;
            //             if (LAST_CHILD) {
            //                 insert_edges = Internal.get_conn_left_right_from_last_child_position(self, parent_idx);
            //                 insert_list = UNTRACKED_LIST;
            //             } else {
            //                 assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks not allowed", .{});
            //                 const first_child_idx = self.get_first_child(parent_idx);
            //                 const last_child_idx = Internal.traverse_forward_to_get_last_index_in_list_from_start_index(self, first_child_idx);
            //                 insert_edges.right = Internal.get_conn_right_dummy_end();
            //                 insert_edges.left = if (last_child_idx != NULL_ID) Internal.get_conn_left_valid_index(self, last_child_idx) else Internal.get_conn_left_from_first_child(self, parent_idx);
            //                 insert_list = UNTRACKED_LIST;
            //             }
            //         },
            //         Insert.Untracked => {
            //             insert_list = UNTRACKED_LIST;
            //             insert_untracked = true;
            //         },
            //         else => assert_with_reason(false, @src(), "invalid type `{s}` input for parameter `insert_to`. All valid input types are contained in `Insert`", .{@typeName(TO)}),
            //     }
            //     var return_items: LLSlice = undefined;
            //     switch (FROM) {
            //         Get.CreateOneNew => {
            //             const new_idx = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
            //             return_items.first = new_idx;
            //             return_items.last = new_idx;
            //             return_items.count = 1;
            //         },
            //         Get.FirstFromList, Get.FirstFromListElseCreateNew => {
            //             const list: ListTag = get_from.list;
            //             assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot get items from the 'untracked' list without specific indexes", .{});
            //             const list_count: debug_switch(Index, void) = debug_switch(self.get_list_len(list), void{});
            //             const first_idx = self.get_first_index_in_list(list);
            //             if (FROM == Get.FirstFromListElseCreateNew and (debug_switch(list_count == 0, false) or first_idx == NULL_ID)) {
            //                 const new_idx = self.list.len;
            //                 _ = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
            //                 return_items.first = new_idx;
            //                 return_items.last = new_idx;
            //                 return_items.count = 1;
            //             } else {
            //                 assert_with_reason(debug_switch(list_count > 0, true) and first_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(list), debug_switch(list_count, 0), first_idx, self.list.len });
            //                 return_items.first = first_idx;
            //                 return_items.last = first_idx;
            //                 return_items.count = 1;
            //                 Internal.disconnect_one(self, list, first_idx);
            //             }
            //         },
            //         Get.LastFromList, Get.LastFromListElseCreateNew => {
            //             const list: ListTag = get_from.list;
            //             assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot get items from the 'untracked' list without specific indexes", .{});
            //             const list_count: debug_switch(Index, void) = debug_switch(self.get_list_len(list), void{});
            //             const last_idx = self.get_last_index_in_list(list);
            //             if (FROM == Get.LastFromListElseCreateNew and (debug_switch(list_count == 0, false) or last_idx == NULL_ID)) {
            //                 const new_idx = self.list.len;
            //                 _ = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
            //                 return_items.first = new_idx;
            //                 return_items.last = new_idx;
            //                 return_items.count = 1;
            //             } else {
            //                 assert_with_reason(debug_switch(list_count > 0, true) and last_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(list), debug_switch(list_count, 0), last_idx, self.list.len });
            //                 return_items.first = last_idx;
            //                 return_items.last = last_idx;
            //                 return_items.count = 1;
            //                 Internal.disconnect_one(self, list, last_idx);
            //             }
            //         },
            //         Get.OneIndex => {
            //             const idx: Index = get_from.idx;
            //             assert_idx_less_than_len(idx, self.list.len, @src());
            //             const list: ListTag = self.get_list_tag(idx);
            //             return_items.first = idx;
            //             return_items.last = idx;
            //             return_items.count = 1;
            //             Internal.disconnect_one(self, list, idx);
            //         },
            //         Get.OneIndexInList => {
            //             const idx: Index = get_from.idx;
            //             const list: ListTag = get_from.list;
            //             assert_valid_list_idx(self, idx, list, @src());
            //             return_items.first = idx;
            //             return_items.last = idx;
            //             return_items.count = 1;
            //             Internal.disconnect_one(self, list, idx);
            //         },
            //         Get.CreateManyNew => {
            //             const count: Index = get_from.count;
            //             assert_with_reason(count > 0, @src(), "cannot create `0` new items", .{});
            //             const first_idx = self.list.len;
            //             const last_idx = self.list.len + count - 1;
            //             _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count) else (if (RETURN_ERRORS) try self.list.append_many_slots(count, alloc) else self.list.append_many_slots(count, alloc));
            //             Internal.initialize_concurrent_indexes(self, first_idx, last_idx, true, false, insert_list, false, NULL_ID);
            //             return_items.first = first_idx;
            //             return_items.last = last_idx;
            //             return_items.count = count;
            //         },
            //         Get.FirstCountFromList => {
            //             const list: ListTag = get_from.list;
            //             const count: Index = get_from.count;
            //             assert_with_reason(count > 0, @src(), "cannot get `0` items", .{});
            //             assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot get items from the 'untracked' list without specific indexes", .{});
            //             assert_with_reason(self.get_list_len(list) >= count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ count, @tagName(list), self.get_list_len(list) });
            //             return_items.first = self.get_first_index_in_list(list);
            //             return_items.last = self.get_nth_index_from_start_of_list(list, count - 1);
            //             return_items.count = count;
            //             Internal.disconnect_many_first_last(self, list, return_items.first, return_items.last, count);
            //         },
            //         Get.LastCountFromList => {
            //             const list: ListTag = get_from.list;
            //             const count: Index = get_from.count;
            //             assert_with_reason(count > 0, @src(), "cannot get `0` items", .{});
            //             assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot get items from the 'untracked' list without specific indexes", .{});
            //             assert_with_reason(self.get_list_len(list) >= count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ count, @tagName(list), self.get_list_len(list) });
            //             return_items.last = self.get_last_index_in_list(list);
            //             return_items.first = self.get_nth_index_from_end_of_list(list, count - 1);
            //             return_items.count = count;
            //             Internal.disconnect_many_first_last(self, list, return_items.first, return_items.last, count);
            //         },
            //         Get.FirstCountFromListElseCreateNew => {
            //             const list: ListTag = get_from.list;
            //             const count: Index = get_from.count;
            //             assert_with_reason(count > 0, @src(), "cannot get `0` items", .{});
            //             const count_from_list = @min(self.get_list_len(list), count);
            //             const count_from_new = count - count_from_list;
            //             var first_new_idx: Index = undefined;
            //             var last_moved_idx: Index = undefined;
            //             const needs_new = count_from_new > 0;
            //             const needs_move = count_from_list > 0;
            //             if (needs_new) {
            //                 first_new_idx = self.list.len;
            //                 const last_new_idx = self.list.len + count_from_new - 1;
            //                 _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
            //                 Internal.initialize_concurrent_indexes(self, first_new_idx, last_new_idx, true, false, insert_list, false, NULL_ID);
            //                 if (needs_move) {
            //                     first_new_idx = first_new_idx;
            //                 } else {
            //                     return_items.first = first_new_idx;
            //                 }
            //                 return_items.last = last_new_idx;
            //             }
            //             if (needs_move) {
            //                 return_items.first = self.get_first_index_in_list(list);
            //                 if (needs_new) {
            //                     last_moved_idx = self.get_nth_index_from_start_of_list(list, count_from_list - 1);
            //                     Internal.disconnect_many_first_last(self, list, return_items.first, last_moved_idx, count_from_list);
            //                 } else {
            //                     return_items.last = self.get_nth_index_from_start_of_list(list, count_from_list - 1);
            //                     Internal.disconnect_many_first_last(self, list, return_items.first, return_items.last, count_from_list);
            //                 }
            //             }
            //             if (needs_new and needs_move) {
            //                 const mid_conn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, last_moved_idx, first_new_idx, list);
            //                 Internal.connect(mid_conn.left, mid_conn.right);
            //             }
            //             return_items.count = count;
            //         },
            //         Get.LastCountFromListElseCreateNew => {
            //             const list: ListTag = get_from.list;
            //             const count: Index = get_from.count;
            //             assert_with_reason(count > 0, @src(), "cannot get `0` items", .{});
            //             const count_from_list = @min(self.get_list_len(list), count);
            //             const count_from_new = count - count_from_list;
            //             var first_new_idx: Index = undefined;
            //             var last_moved_idx: Index = undefined;
            //             const needs_new = count_from_new > 0;
            //             const needs_move = count_from_list > 0;
            //             if (needs_new) {
            //                 first_new_idx = self.list.len;
            //                 const last_new_idx = self.list.len + count_from_new - 1;
            //                 _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
            //                 Internal.initialize_concurrent_indexes(self, first_new_idx, last_new_idx, true, false, insert_list, false, NULL_ID);
            //                 if (needs_move) {
            //                     first_new_idx = first_new_idx;
            //                 } else {
            //                     return_items.first = first_new_idx;
            //                 }
            //                 return_items.last = last_new_idx;
            //             }
            //             if (needs_move) {
            //                 return_items.first = self.get_nth_index_from_end_of_list(list, count_from_list - 1);
            //                 if (needs_new) {
            //                     last_moved_idx = self.get_last_index_in_list(list);
            //                     Internal.disconnect_many_first_last(self, list, return_items.first, last_moved_idx, count_from_list);
            //                 } else {
            //                     return_items.last = self.get_last_index_in_list(list);
            //                     Internal.disconnect_many_first_last(self, list, return_items.first, return_items.last, count_from_list);
            //                 }
            //             }
            //             if (needs_new and needs_move) {
            //                 const mid_conn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, last_moved_idx, first_new_idx, list);
            //                 Internal.connect(mid_conn.left, mid_conn.right);
            //             }
            //             return_items.count = count;
            //         },
            //         Get.SparseIndexesFromSameList => {
            //             const list: ListTag = get_from.list;
            //             const indexes: []const Index = get_from.indexes;
            //             Internal.assert_valid_list_idx_list(self, list, indexes, @src());
            //             return_items.first = indexes[0];
            //             Internal.disconnect_one(self, list, return_items.first);
            //             var prev_idx: Index = return_items.first;
            //             for (indexes[1..]) |this_idx| {
            //                 const conn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, prev_idx, this_idx, list);
            //                 Internal.disconnect_one(self, list, this_idx);
            //                 Internal.connect(conn.left, conn.right);
            //                 prev_idx = this_idx;
            //             }
            //             return_items.last = prev_idx;
            //             return_items.count = @intCast(indexes.len);
            //         },
            //         Get.SparseIndexes => {
            //             const indexes: []const Index = get_from.indexes;
            //             assert_with_reason(indexes.len > 0, @src(), "cannot get 0 items", .{});
            //             assert_idx_less_than_len(indexes[0], self.list.len, @src());
            //             var list = self.get_list_tag(indexes[0]);
            //             Internal.disconnect_one(self, list, indexes[0]);
            //             return_items.first = indexes[0];
            //             var prev_idx = indexes[0];
            //             for (indexes[1..]) |idx| {
            //                 assert_idx_less_than_len(idx, self.list.len, @src());
            //                 list = self.get_list_tag(idx);
            //                 const conn_left = Internal.get_conn_left(self, list, prev_idx, idx);
            //                 const conn_right = Internal.get_conn_right(self, list, idx, prev_idx);
            //                 Internal.disconnect_one(self, list, idx);
            //                 Internal.connect(conn_left, conn_right);
            //                 prev_idx = idx;
            //             }
            //             return_items.last = prev_idx;
            //             return_items.count = @intCast(indexes.len);
            //         },
            //         Get.SparseIndexesFromAnyList => {
            //             const indexes: []const ListIdx = get_from.indexes;
            //             Internal.assert_valid_list_of_list_idxs(self, indexes, @src());
            //             return_items.first = indexes[0].idx;
            //             Internal.disconnect_one(self, indexes[0].list, return_items.first);
            //             var prev_idx: Index = return_items.first;
            //             for (indexes[1..]) |list_idx| {
            //                 const this_idx = list_idx.idx;
            //                 Internal.disconnect_one(self, list_idx.list, this_idx);
            //                 const conn_left = Internal.get_conn_left(self, list_idx.list, prev_idx);
            //                 const conn_right = Internal.get_conn_right(self, list_idx.list, this_idx);
            //                 Internal.connect(conn_left, conn_right);
            //                 prev_idx = this_idx;
            //             }
            //             return_items.last = prev_idx;
            //             return_items.count = @intCast(indexes.len);
            //         },
            //         //CHECKPOINT
            //         .FROM_SLICE => {
            //             const slice: LLSlice = get_val;
            //             Internal.assert_valid_slice(self, slice, @src());
            //             return_items.first = slice.first;
            //             return_items.last = slice.last;
            //             return_items.count = slice.count;
            //         },
            //         .FROM_SLICE_ELSE_CREATE_NEW => {
            //             const supp_slice: LLSliceWithTotalNeeded = get_val;
            //             Internal.assert_valid_slice(self, supp_slice.slice, @src());
            //             const count_from_slice = @min(supp_slice.slice.count, supp_slice.total_needed);
            //             const count_from_new = supp_slice.total_needed - count_from_slice;
            //             var first_new_idx: Index = undefined;
            //             var last_moved_idx: Index = undefined;
            //             const needs_new = count_from_new > 0;
            //             const needs_move = count_from_slice > 0;
            //             if (needs_new) {
            //                 first_new_idx = self.list.len;
            //                 const last_new_idx = self.list.len + count_from_new - 1;
            //                 _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
            //                 Internal.initialize_new_indexes(self, supp_slice.slice.list, first_new_idx, last_new_idx);
            //                 if (needs_move) {
            //                     first_new_idx = first_new_idx;
            //                 } else {
            //                     return_items.first = first_new_idx;
            //                 }
            //                 return_items.last = last_new_idx;
            //             }
            //             if (needs_move) {
            //                 return_items.first = supp_slice.slice.first;
            //                 if (needs_new) {
            //                     last_moved_idx = supp_slice.slice.last;
            //                 } else {
            //                     return_items.last = supp_slice.slice.last;
            //                 }
            //                 Internal.disconnect_many_first_last(self, supp_slice.slice.list, supp_slice.slice.first, supp_slice.slice.last, count_from_slice);
            //             }
            //             if (needs_new and needs_move) {
            //                 const mid_left = Internal.get_conn_left(self, supp_slice.slice.list, last_moved_idx);
            //                 const mid_right = Internal.get_conn_right(self, supp_slice.slice.list, first_new_idx);
            //                 Internal.connect(mid_left, mid_right);
            //             }
            //             return_items.count = supp_slice.total_needed;
            //         },
            //     }
            //     const insert_first = Internal.get_conn_right(self, insert_list, return_items.first);
            //     const insert_last = Internal.get_conn_left(self, insert_list, return_items.last);
            //     Internal.connect_with_insert(insert_edges.left, insert_first, insert_last, insert_edges.right);
            //     Internal.increase_link_set_count(self, insert_list, return_items.count);
            //     Internal.set_list_on_indexes_first_last(self, return_items.first, return_items.last, insert_list);
            //     return_items.list = insert_list;
            //     return return_items;
            // }

            // fn iter_peek_prev_or_null(self: *anyopaque) ?*Elem {
            //     if (!BACKWARD) return false;
            //     const iter: *IteratorState = @ptrCast(@alignCast(self));
            //     if (iter.left_idx == NULL_ID) return null;
            //     return iter.linked_list.get_ptr(iter.left_idx);
            // }
            // fn iter_advance_prev(self: *anyopaque) bool {
            //     if (!BACKWARD) return false;
            //     const iter: *IteratorState = @ptrCast(@alignCast(self));
            //     if (iter.left_idx == NULL_ID) return false;
            //     iter.right_idx = iter.left_idx;
            //     iter.left_idx = iter.linked_list.get_prev_idx(iter.list, iter.left_idx);
            //     return true;
            // }
            // fn iter_peek_next_or_null(self: *anyopaque) ?*Elem {
            //     if (!FORWARD) return false;
            //     const iter: *IteratorState = @ptrCast(@alignCast(self));
            //     if (iter.right_idx == NULL_ID) return null;
            //     return iter.linked_list.get_ptr(iter.right_idx);
            // }
            // fn iter_advance_next(self: *anyopaque) bool {
            //     if (!FORWARD) return false;
            //     const iter: *IteratorState = @ptrCast(@alignCast(self));
            //     if (iter.right_idx == NULL_ID) return false;
            //     iter.left_idx = iter.right_idx;
            //     iter.right_idx = iter.linked_list.get_next_idx(iter.list, iter.right_idx);
            //     return true;
            // }
            // fn iter_reset(self: *anyopaque) bool {
            //     const iter: *IteratorState = @ptrCast(@alignCast(self));
            //     if (FORWARD) {
            //         iter.right_idx = iter.linked_list.get_first_index_in_list(iter.list);
            //         iter.left_idx = NULL_ID;
            //     } else {
            //         iter.left_idx = iter.linked_list.get_last_index_in_list(iter.list);
            //         iter.right_idx = NULL_ID;
            //     }
            //     return true;
            // }

            // pub fn traverse_to_find_what_list_idx_is_in(self: *Heirarchy, idx: Index) ListTag {
            //     var c: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) 0 else void{};
            //     const limit: if (STRONG_ASSERT) Index else void = if (STRONG_ASSERT) @as(Index, @intCast(self.list.len)) else void{};
            //     if ((FORWARD and TAIL) or (BACKWARD and HEAD)) {
            //         var left_idx: Index = idx;
            //         var right_idx: Index = idx;
            //         while (if (STRONG_ASSERT) c <= limit else true) {
            //             if (BACKWARD and HEAD) {
            //                 const next_left = self.get_prev_idx(left_idx);
            //                 if (left_idx != NULL_ID) {
            //                     left_idx = next_left;
            //                 } else {
            //                     for (self.lists, 0..) |list, tag_raw| {
            //                         if (list.first_idx == left_idx) return @enumFromInt(@as(ListTagInt, @intCast(tag_raw)));
            //                     }
            //                     return UNTRACKED_LIST;
            //                 }
            //             }
            //             if (FORWARD and TAIL) {
            //                 const next_right = self.get_next_idx(left_idx);
            //                 if (right_idx != NULL_ID) {
            //                     right_idx = next_right;
            //                 } else {
            //                     for (self.lists, 0..) |list, tag_raw| {
            //                         if (list.last_idx == left_idx) return @enumFromInt(@as(ListTagInt, @intCast(tag_raw)));
            //                     }
            //                     return UNTRACKED_LIST;
            //                 }
            //             }
            //             if (STRONG_ASSERT) c += 1;
            //         }
            //         assert_with_reason(false, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in either forward or backward direction without finding a NULL_IDX: list is cyclic and using this function will create an infinite loop", .{ limit, idx });
            //     } else {
            //         for (self.lists, 0..) |list, tag_raw| {
            //             const list_tag = @as(ListTag, @enumFromInt(@as(ListTagInt, @intCast(tag_raw))));
            //             if (FORWARD) {
            //                 var curr_idx: Index = self.get_first_index_in_list(list);
            //                 while (curr_idx != NULL_ID and (if (STRONG_ASSERT) c <= limit else true)) {
            //                     if (curr_idx == idx) return list_tag;
            //                     curr_idx = self.get_next_idx(curr_idx);
            //                     c += 1;
            //                 }
            //             } else {
            //                 var curr_idx: Index = self.get_last_index_in_list(list);
            //                 while (curr_idx != NULL_ID and (if (STRONG_ASSERT) c <= limit else true)) {
            //                     if (curr_idx == idx) return list_tag;
            //                     curr_idx = self.get_next_idx(curr_idx);
            //                     c += 1;
            //                 }
            //             }
            //         }
            //         if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) through all lists without finding index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, idx });
            //         return UNTRACKED_LIST;
            //     }
            // }
        };

        // pub const IteratorState = struct {
        //     linked_list: *Heirarchy,
        //     list: ListTag,
        //     left_idx: Index,
        //     right_idx: Index,

        //     pub fn iterator(self: *IteratorState) Iterator(Elem, true, true) {
        //         return Iterator(Elem, true, true){
        //             .implementor = @ptrCast(self),
        //             .vtable = Iterator(Elem).VTable{
        //                 .reset = Internal.iter_reset,
        //                 .advance_forward = Internal.iter_advance_next,
        //                 .peek_next_or_null = Internal.iter_peek_next_or_null,
        //                 .advance_prev = Internal.iter_advance_prev,
        //                 .peek_prev_or_null = Internal.iter_peek_prev_or_null,
        //             },
        //         };
        //     }
        // };

        // pub inline fn new_iterator_state_at_start_of_list(self: *Heirarchy, list: ListTag) IteratorState {
        //     return IteratorState{
        //         .linked_list = self,
        //         .list = list,
        //         .left_idx = NULL_ID,
        //         .right_idx = if (HEAD) self.get_first_index_in_list(list) else NULL_ID,
        //     };
        // }
        // pub inline fn new_iterator_state_at_end_of_list(self: *Heirarchy, list: ListTag) IteratorState {
        //     return IteratorState{
        //         .linked_list = self,
        //         .list = list,
        //         .left_idx = if (TAIL) self.get_last_index_in_list(list) else NULL_ID,
        //         .right_idx = NULL_ID,
        //     };
        // }

        pub fn new_empty(assert_alloc: AllocInfal) Heirarchy {
            var uninit = UNINIT;
            uninit.list = List.new_empty(assert_alloc);
            return uninit;
        }

        pub fn new_with_capacity(capacity: Index, alloc: AllocInfal) Heirarchy {
            var self = UNINIT;
            self.list.ensure_total_capacity_exact(capacity, alloc);
            return self;
        }

        pub fn clone(self: *const Heirarchy, alloc: Allocator) Heirarchy {
            var new_list = self.*;
            new_list.list = self.list.clone(alloc);
            return new_list;
        }

        pub inline fn insert_slot_between_siblings(self: *Heirarchy, prev_sibling_id: Id, next_sibling_id: Id, parent_id: Id, alloc: AllocInfal) Id {
            self.list.ensure_unused_capacity(1, alloc);
            return self.insert_slot_between_siblings_assume_capacity(prev_sibling_id, next_sibling_id, parent_id);
        }

        pub inline fn insert_slot_between_siblings_assume_capacity(self: *Heirarchy, prev_sibling_id: Id, next_sibling_id: Id, parent_id: Id) Id {
            const new_id = Internal.initialize_new_index(self, parent_id);
            Internal.insert_slots_between_siblings_internal(self, prev_sibling_id, new_id, new_id, next_sibling_id, parent_id);
            return new_id;
        }

        pub inline fn insert_many_slots_between_siblings(self: *Heirarchy, count: Index, prev_sibling_id: Id, next_sibling_id: Id, parent_id: Id, alloc: AllocInfal) FirstLast {
            self.list.ensure_unused_capacity(count, alloc);
            return self.insert_many_slots_between_siblings_assume_capacity(count, prev_sibling_id, next_sibling_id, parent_id);
        }

        pub inline fn insert_many_slots_between_siblings_assume_capacity(self: *Heirarchy, count: Index, prev_sibling_id: Id, next_sibling_id: Id, parent_id: Id) FirstLast {
            const first_last = Internal.initialize_items_as_siblings(self, count, parent_id);
            Internal.insert_slots_between_siblings_internal(self, prev_sibling_id, first_last.first, first_last.last, next_sibling_id, parent_id);
            return first_last;
        }

        //CHECKPOINT ... before/after variations, then parent/child variations

        // pub fn list_is_cyclic_forward(self: *Heirarchy, list: ListTag) bool {
        //     if (FORWARD) {
        //         const start_idx = self.get_first_index_in_list(list);
        //         if (start_idx == NULL_ID) return false;
        //         if (STATE or STRONG_ASSERT) assert_with_reason(self.index_is_in_list(start_idx, list), @src(), "provided idx {d} was not in list `{s}`", .{ start_idx, @tagName(list) });
        //         var slow_idx = start_idx;
        //         var fast_idx = start_idx;
        //         var next_fast: Index = undefined;
        //         while (true) {
        //             next_fast = self.get_next_idx(list, fast_idx);
        //             if (next_fast == NULL_ID) return false;
        //             next_fast = self.get_next_idx(list, next_fast);
        //             if (next_fast == NULL_ID) return false;
        //             fast_idx = next_fast;
        //             slow_idx = self.get_next_idx(list, slow_idx);
        //             if (slow_idx == fast_idx) return true;
        //         }
        //     } else {
        //         return false;
        //     }
        // }

        // pub fn list_is_cyclic_backward(self: *Heirarchy, list: ListTag) bool {
        //     if (FORWARD) {
        //         const start_idx = self.get_last_index_in_list(list);
        //         if (start_idx == NULL_ID) return false;
        //         if (STATE or STRONG_ASSERT) assert_with_reason(self.index_is_in_list(start_idx, list), @src(), "provided idx {d} was not in list `{s}`", .{ start_idx, @tagName(list) });
        //         var slow_idx = start_idx;
        //         var fast_idx = start_idx;
        //         var next_fast: Index = undefined;
        //         while (true) {
        //             next_fast = self.get_prev_idx(list, fast_idx);
        //             if (next_fast == NULL_ID) return false;
        //             next_fast = self.get_prev_idx(list, next_fast);
        //             if (next_fast == NULL_ID) return false;
        //             fast_idx = next_fast;
        //             slow_idx = self.get_prev_idx(list, slow_idx);
        //             if (slow_idx == fast_idx) return true;
        //         }
        //     } else {
        //         return false;
        //     }
        // }

        // pub fn find_idx(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Idx {
        //     for (self.slice(), 0..) |*item, idx| {
        //         if (match_fn(param, item)) return @intCast(idx);
        //     }
        //     return null;
        // }

        // pub fn find_ptr(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*Elem {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         return &self.ptr[idx];
        //     }
        //     return null;
        // }

        // pub fn find_const_ptr(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*const Elem {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         return &self.ptr[idx];
        //     }
        //     return null;
        // }

        // pub fn find_and_copy(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         return self.ptr[idx];
        //     }
        //     return null;
        // }

        // pub fn find_and_remove(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         return self.remove(idx);
        //     }
        //     return null;
        // }

        // pub fn find_and_delete(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) bool {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         self.delete(idx);
        //         return true;
        //     }
        //     return false;
        // }

        // pub inline fn find_exactly_n_item_indexes_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Idx) bool {
        //     return self.flex_slice(.immutable).find_exactly_n_item_indexes_from_n_params_in_order(Param, params, match_fn, output_buf);
        // }

        // pub inline fn find_exactly_n_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*Elem) bool {
        //     return self.flex_slice(.mutable).find_exactly_n_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        // }

        // pub inline fn find_exactly_n_const_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*const Elem) bool {
        //     return self.flex_slice(.immutable).find_exactly_n_const_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        // }

        // pub inline fn find_exactly_n_item_copies_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Elem) bool {
        //     return self.flex_slice(.immutable).find_exactly_n_item_copies_from_n_params_in_order(Param, params, match_fn, output_buf);
        // }

        // pub fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
        //     assert_with_reason(indexes.len <= self.len, @src(), "more indexes provided ({d}) than exist in list ({d})", .{ indexes.len, self.len });
        //     assert_with_reason(check: {
        //         var i: usize = 1;
        //         while (i < indexes.len) : (i += 1) {
        //             if (indexes[i - 1] >= indexes[i]) break :check false;
        //         }
        //         break :check true;
        //     }, @src(), "not all indexes are in increasing order (with no duplicates) as is required by this function", .{});
        //     assert_with_reason(check: {
        //         var i: usize = 0;
        //         while (i < indexes.len) : (i += 1) {
        //             if (indexes[i] >= self.len) break :check false;
        //         }
        //         break :check true;
        //     }, @src(), "some indexes provided are out of bounds for list len ({d})", .{self.len});
        //     var shift_down: usize = 0;
        //     var i: usize = 0;
        //     var src_start: Idx = undefined;
        //     var src_end: Idx = undefined;
        //     var dst_start: Idx = undefined;
        //     var dst_end: Idx = undefined;
        //     while (i < indexes.len) {
        //         var consecutive: Idx = 1;
        //         var end_index: Idx = i + consecutive;
        //         while (end_index < indexes.len) {
        //             if (indexes[end_index] != indexes[end_index - 1] + 1) break;
        //             consecutive += 1;
        //             end_index += 1;
        //         }
        //         const start_idx = end_index - 1;
        //         shift_down += consecutive;
        //         src_start = indexes[start_idx];
        //         src_end = if (end_index >= indexes.len) self.len else indexes[end_index];
        //         dst_start = src_start - shift_down;
        //         dst_end = src_end - shift_down;
        //         std.mem.copyForwards(Idx, self.ptr[dst_start..dst_end], self.ptr[src_start..src_end]);
        //         i += consecutive;
        //     }
        //     self.len -= indexes.len;
        // }

        // //TODO pub fn insert_slots_at_ordered_indexes()

        // pub inline fn insertion_sort(self: *List) void {
        //     return self.flex_slice(.mutable).insertion_sort();
        // }

        // pub inline fn insertion_sort_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) void {
        //     return self.flex_slice(.mutable).insertion_sort_with_transform(TX, transform_fn);
        // }

        // pub inline fn insertion_sort_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) void {
        //     return self.flex_slice(.mutable).insertion_sort_with_transform_and_user_data(TX, transform_fn, userdata);
        // }

        // pub inline fn is_sorted(self: *List) bool {
        //     return self.flex_slice(.immutable).is_sorted();
        // }

        // pub inline fn is_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
        //     return self.flex_slice(.immutable).is_sorted_with_transform(TX, transform_fn);
        // }

        // pub inline fn is_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
        //     return self.flex_slice(.immutable).is_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        // }

        // pub inline fn is_reverse_sorted(self: *List) bool {
        //     return self.flex_slice(.immutable).is_reverse_sorted();
        // }

        // pub inline fn is_reverse_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
        //     return self.flex_slice(.immutable).is_reverse_sorted_with_transform(TX, transform_fn);
        // }

        // pub inline fn is_reverse_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
        //     return self.flex_slice(.immutable).is_reverse_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        // }

        // // pub inline fn insert_one_sorted( self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        // //     return insert_one_sorted_custom(List, self, item, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN, alloc);
        // // }

        // // pub fn insert_one_sorted_custom( self: *List, item: Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        // //     const insert_idx: Idx = @intCast(BinarySearch.binary_search_insert_index(Elem, &item, self.ptr[0..self.len], greater_than_fn, equal_order_fn));
        // //     if (RETURN_ERRORS) try insert(List, self, insert_idx, item, alloc) else insert(List, self, insert_idx, item, alloc);
        // //     return insert_idx;
        // // }

        // // pub inline fn find_equal_order_idx_sorted( self: *List, item_to_compare: *const Elem) ?Idx {
        // //     return find_equal_order_idx_sorted_custom(List, self, item_to_compare, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN);
        // // }

        // // pub fn find_equal_order_idx_sorted_custom( self: *List, item_to_compare: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem)) ?Idx {
        // //     const insert_idx = BinarySearch.binary_search_by_order(Elem, item_to_compare, self.ptr[0..self.len], greater_than_fn, equal_order_fn);
        // //     if (insert_idx) |idx| return @intCast(idx);
        // //     return null;
        // // }

        // // pub inline fn find_matching_item_idx_sorted( self: *List, item_to_find: *const Elem) ?Idx {
        // //     return find_matching_item_idx_sorted_custom(List, self, item_to_find, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_COMPARE_PKG.equals, DEFAULT_MATCH_FN);
        // // }

        // // pub fn find_matching_item_idx_sorted_custom( self: *List, item_to_find: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), exact_match_fn: *const CompareFn(Elem)) ?Idx {
        // //     const insert_idx = BinarySearch.binary_search_exact_match(Elem, item_to_find, self.ptr[0..self.len], greater_than_fn, equal_order_fn, exact_match_fn);
        // //     if (insert_idx) |idx| return @intCast(idx);
        // //     return null;
        // // }

        // // pub inline fn find_matching_item_idx( self: *List, item_to_find: *const Elem) ?Idx {
        // //     return find_matching_item_idx_custom(List, self, item_to_find, DEFAULT_MATCH_FN);
        // // }

        // // pub fn find_matching_item_idx_custom( self: *List, item_to_find: *const Elem, exact_match_fn: *const CompareFn(Elem)) ?Idx {
        // //     if (self.len == 0) return null;
        // //     const buf = self.ptr[0..self.len];
        // //     var idx: Idx = 0;
        // //     var found_exact = exact_match_fn(item_to_find, &buf[idx]);
        // //     const limit = self.len - 1;
        // //     while (!found_exact and idx < limit) {
        // //         idx += 1;
        // //         found_exact = exact_match_fn(item_to_find, &buf[idx]);
        // //     }
        // //     if (found_exact) return idx;
        // //     return null;
        // // }

        // pub fn handle_alloc_error(err: Allocator.Error) if (RETURN_ERRORS) Error else noreturn {
        //     switch (ALLOC_ERROR_BEHAVIOR) {
        //         ErrorBehavior.RETURN_ERRORS => return err,
        //         ErrorBehavior.ERRORS_PANIC => std.debug.panic("List's backing allocator failed to allocate memory: Allocator.Error.{s}", .{@errorName(err)}),
        //         ErrorBehavior.ERRORS_ARE_UNREACHABLE => unreachable,
        //     }
        // }

        // //**************************
        // // std.io.Writer interface *
        // //**************************
        // const StdWriterHandle = struct {
        //     list: *List,
        //     alloc: Allocator,
        // };
        // const StdWriterHandleNoGrow = struct {
        //     list: *List,
        // };

        // pub const StdWriter = if (Elem != u8)
        //     @compileError("The Writer interface is only defined for child type `u8` " ++
        //         "but the given type is " ++ @typeName(Elem))
        // else
        //     std.io.Writer(StdWriterHandle, Allocator.Error, std_write);

        // pub fn get_std_writer(self: *List, alloc: Allocator) StdWriter {
        //     return StdWriter{ .context = .{ .list = self, .alloc = alloc } };
        // }

        // fn std_write(handle: StdWriterHandle, bytes: []const u8) Allocator.Error!usize {
        //     try handle.list.append_slice(bytes, handle.alloc);
        //     return bytes.len;
        // }

        // pub const StdWriterNoGrow = if (Elem != u8)
        //     @compileError("The Writer interface is only defined for child type `u8` " ++
        //         "but the given type is " ++ @typeName(Elem))
        // else
        //     std.io.Writer(StdWriterHandleNoGrow, Allocator.Error, std_write_no_grow);

        // pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
        //     return StdWriterNoGrow{ .context = .{ .list = self } };
        // }

        // fn std_write_no_grow(handle: StdWriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
        //     const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
        //     if (bytes.len > available_capacity) return error.OutOfMemory;
        //     handle.list.append_slice_assume_capacity(bytes);
        //     return bytes.len;
        // }
    };
}

// pub fn LinkedListIterator(comptime List: type) type {
//     return struct {
//         next_idx: List.Idx = 0,
//         list_ref: *List,

//         const Self = @This();

//         pub inline fn reset_index_to_start(self: *Self) void {
//             self.next_idx = 0;
//         }

//         pub inline fn set_index(self: *Self, index: List.Idx) void {
//             self.next_idx = index;
//         }

//         pub inline fn decrease_index_safe(self: *Self, count: List.Idx) void {
//             self.next_idx -|= count;
//         }
//         pub inline fn decrease_index(self: *Self, count: List.Idx) void {
//             self.next_idx -= count;
//         }
//         pub inline fn increase_index(self: *Self, count: List.Idx) void {
//             self.next_idx += count;
//         }
//         pub inline fn increase_index_safe(self: *Self, count: List.Idx) void {
//             self.next_idx +|= count;
//         }

//         pub inline fn has_next(self: Self) bool {
//             return self.next_idx < self.list_ref.len;
//         }

//         pub fn get_next_copy(self: *Self) ?List.Elem {
//             if (self.next_idx >= self.list_ref.len) return null;
//             const item = self.list_ref.ptr[self.next_idx];
//             self.next_idx += 1;
//             return item;
//         }

//         pub fn get_next_copy_guaranteed(self: *Self) List.Elem {
//             assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
//             const item = self.list_ref.ptr[self.next_idx];
//             self.next_idx += 1;
//             return item;
//         }

//         pub fn get_next_ref(self: *Self) ?*List.Elem {
//             if (self.next_idx >= self.list_ref.len) return null;
//             const item: *List.Elem = &self.list_ref.ptr[self.next_idx];
//             self.next_idx += 1;
//             return item;
//         }

//         pub fn get_next_ref_guaranteed(self: *Self) *List.Elem {
//             assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
//             const item: *List.Elem = &self.list_ref.ptr[self.next_idx];
//             self.next_idx += 1;
//             return item;
//         }

//         /// Returns `true` if action was performed at least one time, `false` if iterator had zero items left
//         pub fn perform_action_on_remaining_items(self: *Self, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
//             var idx: List.Idx = self.next_idx;
//             var exec_count: List.Idx = 0;
//             var should_continue: bool = true;
//             while (should_continue and idx < self.list_ref.len) : (idx += 1) {
//                 const item: *List.Elem = &self.list_ref.ptr[idx];
//                 should_continue = callback(self.list_ref, idx, item, userdata);
//                 exec_count += 1;
//             }
//             return exec_count > 0;
//         }

//         /// Returns `true` if action was performed on exactly `count` items, `false` if iterator ran out of items early
//         pub fn perform_action_on_next_n_items(self: *Self, count: List.Idx, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
//             var idx: List.Idx = self.next_idx;
//             const limit = @min(idx + count, self.list_ref.len);
//             var exec_count: List.Idx = 0;
//             var should_continue: bool = true;
//             while (should_continue and idx < limit) : (idx += 1) {
//                 const item: *List.Elem = &self.list_ref.ptr[idx];
//                 should_continue = callback(self.list_ref, idx, item, userdata);
//                 exec_count += 1;
//             }
//             return exec_count == count;
//         }

//         /// Should return `true` if iteration should continue, or `false` if iteration should stop
//         pub const IteratorAction = fn (list: *List, index: List.Idx, item: *List.Elem, userdata: ?*anyopaque) bool;
//     };
// }

test "LinkedList.zig - Linear Doubly Linked" {
    // const t = Root.Testing;
    // const alloc = std.heap.page_allocator;
    // const TestElem = struct {
    //     prev: u16,
    //     val: u8,
    //     idx: u16,
    //     list: u8,
    //     next: u16,
    // };
    // const TestState = enum(u8) {
    //     USED,
    //     FREE,
    //     INVALID,
    //     NONE,
    // };
    // const uninit_val = TestElem{
    //     .idx = 0xAAAA,
    //     .prev = 0xAAAA,
    //     .next = 0xAAAA,
    //     .list = 0xAA,
    //     .val = 0,
    // };
    // const opts = LinkedHeirarchyManagerOptions{
    //     .base_memory_options = Root.List.ListOptions{
    //         .alignment = null,
    //         .alloc_error_behavior = .ERRORS_PANIC,
    //         .element_type = TestElem,
    //         .growth_model = .GROW_BY_25_PERCENT,
    //         .index_type = u16,
    //         .secure_wipe_bytes = true,
    //         .memset_uninit_val = &uninit_val,
    //     },
    //     .master_list_enum = TestState,
    //     .forward_linkage = "next",
    //     .backward_linkage = "prev",
    //     .element_idx_cache_field = "idx",
    //     .force_cache_first_index = true,
    //     .force_cache_last_index = true,
    //     .element_list_flag_access = ElementStateAccess{
    //         .field = "list",
    //         .field_bit_offset = 1,
    //         .field_bit_count = 2,
    //         .field_type = u8,
    //     },
    //     .stronger_asserts = true,
    // };
    // const Action = struct {
    //     fn set_value_from_string(elem: *TestElem, userdata: ?*anyopaque) void {
    //         const string: *[]const u8 = @ptrCast(@alignCast(userdata.?));
    //         elem.val = string.*[0];
    //         string.* = string.*[1..];
    //     }
    //     fn move_data(from_item: *const TestElem, to_item: *TestElem, userdata: ?*anyopaque) void {
    //         _ = userdata;
    //         to_item.val = from_item.val;
    //     }
    //     fn greater_than(a: *const TestElem, b: *const TestElem, userdata: ?*anyopaque) bool {
    //         _ = userdata;
    //         return a.val > b.val;
    //     }
    // };
    // const List = define_linked_heirarchy_manager(opts);
    // const expect = struct {
    //     fn list_is_valid(linked_list: *List, list: TestState, case_indexes: []const u16, case_vals: []const u8) !void {
    //         errdefer debug_list(linked_list, list);
    //         var i: List.Idx = 0;
    //         var c: List.Idx = 0;
    //         const list_count = linked_list.get_list_len(list);
    //         try t.expect_equal(case_indexes.len, "indexes.len", case_vals.len, "vals.len", "text case indexes and vals have different len", .{});
    //         try t.expect_equal(list_count, "list_count", case_vals.len, "vals.len", "list {s} count mismatch with test case vals len", .{@tagName(list)});
    //         //FORWARD
    //         var start_idx = linked_list.get_first_index_in_list(list);
    //         if (start_idx == List.NULL_IDX) {
    //             try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
    //         } else {
    //             try t.expect_true(linked_list.index_is_in_list(start_idx, list), "list.idx_is_in_list(start_idx, list)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
    //             var slow_idx = start_idx;
    //             var fast_idx = start_idx;
    //             var fast_ptr = linked_list.get_ptr(fast_idx);
    //             var prev_fast_idx: List.Idx = List.NULL_IDX;
    //             try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(start_ptr, List.CACHE_FIELD)", "list list {s} first idx {d} cached idx mismatch", .{ @tagName(list), start_idx });
    //             try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(start_idx)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
    //             try t.expect_equal(@field(fast_ptr, List.PREV_FIELD), "@field(fast_ptr, List.PREV_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} first idx {d} cached prev isnt NULL_IDX", .{ @tagName(list), start_idx });
    //             try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
    //             try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
    //             try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
    //             i = 1;
    //             c = 1;
    //             check: while (true) {
    //                 prev_fast_idx = fast_idx;
    //                 fast_idx = linked_list.get_next_idx(list, fast_idx);
    //                 if (fast_idx == List.NULL_IDX) {
    //                     try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
    //                     break :check;
    //                 }
    //                 try t.expect_greater_than(linked_list.list.len, "list.list.len", fast_idx, "fast_idx", "list list {s} next idx out of bounds but not NULL_IDX", .{@tagName(list)});
    //                 fast_ptr = linked_list.get_ptr(fast_idx);
    //                 try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
    //                 try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
    //                 try t.expect_equal(@field(fast_ptr, List.PREV_FIELD), "@field(fast_ptr, List.PREV_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached prev isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
    //                 try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
    //                 try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
    //                 try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
    //                 i += 1;
    //                 c += 1;
    //                 prev_fast_idx = fast_idx;
    //                 fast_idx = linked_list.get_next_idx(list, fast_idx);
    //                 if (fast_idx == List.NULL_IDX) {
    //                     try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
    //                     break :check;
    //                 }
    //                 fast_ptr = linked_list.get_ptr(fast_idx);
    //                 try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
    //                 try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
    //                 try t.expect_equal(@field(fast_ptr, List.PREV_FIELD), "@field(fast_ptr, List.PREV_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached prev isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
    //                 try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
    //                 try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
    //                 try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
    //                 i += 1;
    //                 c += 1;
    //                 slow_idx = linked_list.get_next_idx(list, slow_idx);
    //                 try t.expect_not_equal(fast_idx, "fast_idx", slow_idx, "slow_idx", "list list {s} was cyclic", .{@tagName(list)});
    //             }
    //         }
    //         //BACKWARD
    //         i = @intCast(case_indexes.len -| 1);
    //         c = 0;
    //         start_idx = linked_list.get_last_index_in_list(list);
    //         if (start_idx == List.NULL_IDX) {
    //             try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
    //         } else {
    //             try t.expect_true(linked_list.index_is_in_list(start_idx, list), "list.idx_is_in_list(start_idx, list)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
    //             var slow_idx = start_idx;
    //             var fast_idx = start_idx;
    //             var fast_ptr = linked_list.get_ptr(fast_idx);
    //             var prev_fast_idx: List.Idx = List.NULL_IDX;
    //             try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(start_ptr, List.CACHE_FIELD)", "list list {s} first idx {d} cached idx mismatch", .{ @tagName(list), start_idx });
    //             try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(start_idx)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
    //             try t.expect_equal(@field(fast_ptr, List.NEXT_FIELD), "@field(fast_ptr, List.NEXT_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} first idx {d} cached next isnt NULL_IDX", .{ @tagName(list), start_idx });
    //             try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
    //             try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
    //             try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
    //             i -|= 1;
    //             c = 1;
    //             check: while (true) {
    //                 prev_fast_idx = fast_idx;
    //                 fast_idx = linked_list.get_prev_idx(list, fast_idx);
    //                 if (fast_idx == List.NULL_IDX) {
    //                     try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
    //                     break :check;
    //                 }
    //                 try t.expect_greater_than(linked_list.list.len, "list.list.len", fast_idx, "fast_idx", "list list {s} next idx out of bounds but not NULL_IDX", .{@tagName(list)});
    //                 fast_ptr = linked_list.get_ptr(fast_idx);
    //                 try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
    //                 try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
    //                 try t.expect_equal(@field(fast_ptr, List.NEXT_FIELD), "@field(fast_ptr, List.NEXT_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached next isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
    //                 try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
    //                 try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
    //                 try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
    //                 i -|= 1;
    //                 c += 1;
    //                 prev_fast_idx = fast_idx;
    //                 fast_idx = linked_list.get_prev_idx(list, fast_idx);
    //                 if (fast_idx == List.NULL_IDX) {
    //                     try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
    //                     break :check;
    //                 }
    //                 fast_ptr = linked_list.get_ptr(fast_idx);
    //                 try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
    //                 try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
    //                 try t.expect_equal(@field(fast_ptr, List.NEXT_FIELD), "@field(fast_ptr, List.NEXT_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached prev isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
    //                 try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
    //                 try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
    //                 try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
    //                 i -|= 1;
    //                 c += 1;
    //                 slow_idx = linked_list.get_prev_idx(list, slow_idx);
    //                 try t.expect_not_equal(fast_idx, "fast_idx", slow_idx, "slow_idx", "list list {s} was cyclic", .{@tagName(list)});
    //             }
    //         }
    //     }
    //     fn full_ll_state(list: *List, used_indexes: []const u16, used_vals: []const u8, free_indexes: []const u16, free_vals: []const u8, invalid_indexes: []const u16, invalid_vals: []const u8) !void {
    //         try list_is_valid(list, .FREE, free_indexes, free_vals);
    //         try list_is_valid(list, .USED, used_indexes, used_vals);
    //         try list_is_valid(list, .INVALID, invalid_indexes, invalid_vals);
    //         if (list.get_list_len(.FREE) == 0) {
    //             try t.expect_equal(list.get_first_index_in_list(.FREE), "list.get_first_index_in_list(.FREE)", List.NULL_IDX, "List.NULL_IDX", "empty list `FREE` does not have NULL_IDX for first index", .{});
    //             try t.expect_equal(list.get_last_index_in_list(.FREE), "list.get_last_index_in_list(.FREE)", List.NULL_IDX, "List.NULL_IDX", "empty list `FREE` does not have NULL_IDX for last index", .{});
    //         }
    //         if (list.get_list_len(.USED) == 0) {
    //             try t.expect_equal(list.get_first_index_in_list(.USED), "list.get_first_index_in_list(.USED)", List.NULL_IDX, "List.NULL_IDX", "empty list `USED` does not have NULL_IDX for first index", .{});
    //             try t.expect_equal(list.get_last_index_in_list(.USED), "list.get_last_index_in_list(.USED)", List.NULL_IDX, "List.NULL_IDX", "empty list `USED` does not have NULL_IDX for last index", .{});
    //         }
    //         if (list.get_list_len(.INVALID) == 0) {
    //             try t.expect_equal(list.get_first_index_in_list(.INVALID), "list.get_first_index_in_list(.INVALID)", List.NULL_IDX, "List.NULL_IDX", "empty list `INVALID` does not have NULL_IDX for first index", .{});
    //             try t.expect_equal(list.get_last_index_in_list(.INVALID), "list.get_last_index_in_list(.INVALID)", List.NULL_IDX, "List.NULL_IDX", "empty list `INVALID` does not have NULL_IDX for last index", .{});
    //         }
    //         const total_count = list.get_list_len(.USED) + list.get_list_len(.FREE) + list.get_list_len(.INVALID);
    //         try t.expect_equal(total_count, "total_count", list.list.len, "list.list.len", "total list list counts did not equal underlying list len (leaked indexes)", .{});
    //     }
    //     fn debug_list(linked_list: *List, list: TestState) void {
    //         t.print("\nERROR STATE: {s}\ncount:     {d: >2}\nfirst_idx: {d: >2}\nlast_idx:  {d: >2}\n", .{
    //             @tagName(list),
    //             linked_list.get_list_len(list),
    //             linked_list.get_first_index_in_list(list),
    //             linked_list.get_last_index_in_list(list),
    //         });
    //         var idx = linked_list.get_first_index_in_list(list);
    //         var ptr: *List.Elem = undefined;
    //         t.print("forward:      ", .{});
    //         while (idx != List.NULL_IDX) {
    //             ptr = linked_list.get_ptr(idx);
    //             t.print("{d} -> ", .{idx});
    //             idx = @field(ptr, List.NEXT_FIELD);
    //         }

    //         t.print("NULL\n", .{});
    //         idx = linked_list.get_first_index_in_list(list);
    //         t.print("forward str:  ", .{});
    //         while (idx != List.NULL_IDX) {
    //             ptr = linked_list.get_ptr(idx);
    //             t.print("{c}", .{@field(ptr, "val")});
    //             idx = @field(ptr, List.NEXT_FIELD);
    //         }
    //         t.print("\n", .{});
    //         idx = linked_list.get_last_index_in_list(list);
    //         t.print("backward:     ", .{});
    //         while (idx != List.NULL_IDX) {
    //             ptr = linked_list.get_ptr(idx);
    //             t.print("{d} -> ", .{idx});
    //             idx = @field(ptr, List.PREV_FIELD);
    //         }
    //         t.print("NULL\n", .{});
    //         idx = linked_list.get_last_index_in_list(list);
    //         t.print("backward str: ", .{});
    //         while (idx != List.NULL_IDX) {
    //             ptr = linked_list.get_ptr(idx);
    //             t.print("{c}", .{@field(ptr, "val")});
    //             idx = @field(ptr, List.PREV_FIELD);
    //         }
    //         t.print("\n", .{});
    //     }
    // };
    // var linked_list = List.new_empty();
    // var slice_result = linked_list.get_items_and_insert_at(.CREATE_MANY_NEW, 20, .AT_BEGINNING_OF_LIST, .FREE, alloc);
    // try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.CREATE_MANY_NEW, 20, .AT_BEGINNING_OF_LIST, .FREE, alloc)", List.LLSlice{ .count = 20, .first = 0, .last = 19, .list = .FREE }, "List.LLSlice{.count = 20, .first = 0, .last = 19, .list = .FREE}", "unexpected result from function", .{});
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{}, // used_indexes
    //     &.{}, // used_vals
    //     &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
    //     &.{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
    //     &.{}, // invalid_indexes
    //     &.{}, // invalid_vals
    // );
    // // zig fmt: on
    // slice_result = linked_list.get_items_and_insert_at(.FIRST_N_FROM_LIST, List.CountFromList.new(.FREE, 8), .AT_BEGINNING_OF_LIST, .USED, alloc);
    // try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.FIRST_N_FROM_LIST, List.CountFromList.new(.FREE, 8), .AT_BEGINNING_OF_LIST, .USED, alloc)", List.LLSlice{ .count = 8, .first = 0, .last = 7, .list = .USED }, "List.LLSlice{ .count = 8, .first = 0, .last = 7, .list = .USED }", "unexpected result from function", .{});
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 0, 1, 2, 3, 4, 5, 6, 7}, // used_indexes
    //     &.{ 0, 0, 0, 0, 0, 0, 0, 0}, // used_vals
    //     &.{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
    //     &.{ 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
    //     &.{}, // invalid_indexes
    //     &.{}, // invalid_vals
    // );
    // // zig fmt: on
    // var slice_iter_state = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 0);
    // try t.expect_shallow_equal(slice_iter_state, "slice_result.new_iterator_state_at_start_of_slice(&linked_list)", List.LLSlice.SliceIteratorState(0){ .linked_list = &linked_list, .left_idx = List.NULL_IDX, .right_idx = slice_result.first, .slice = &slice_result, .state_slots = undefined }, "SliceIteratorState{ .linked_list = &linked_list, .left_idx = List.NULL_IDX, .right_idx = slice_result.first, .slice = &slice_result }", "unexpected result from function", .{});
    // var slice_iter = slice_iter_state.iterator();
    // var str: []const u8 = "abcdefgh";
    // const bool_result = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
    // try t.expect_true(bool_result, "slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, &\"abcdefghijklmnopqrst\");", "iterator set values failed", .{});
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 0, 1, 2, 3, 4, 5, 6, 7}, // used_indexes
    //     "abcdefgh", // used_vals
    //     &.{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
    //     &.{ 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
    //     &.{}, // invalid_indexes
    //     &.{}, // invalid_vals
    // );
    // // zig fmt: on
    // slice_result = linked_list.get_items_and_insert_at(.LAST_N_FROM_LIST, List.CountFromList.new(.USED, 3), .AT_BEGINNING_OF_LIST, .INVALID, alloc);
    // try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.LAST_N_FROM_LIST, List.CountFromList.new(.USED, 3), .AT_BEGINNING_OF_LIST, .INVALID, alloc)", List.LLSlice{ .count = 3, .first = 5, .last = 7, .list = .INVALID }, "LLSlice{ .count = 3, .first = 5, .last = 7, .list = .INVALID }", "unexpected result from function", .{});
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 0, 1, 2, 3, 4}, // used_indexes
    //     "abcde", // used_vals
    //     &.{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
    //     &.{ 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
    //     &.{5, 6, 7}, // invalid_indexes
    //     "fgh", // invalid_vals
    // );
    // // zig fmt: on
    // slice_result = linked_list.get_items_and_insert_at(.LAST_N_FROM_LIST, List.CountFromList.new(.FREE, 5), .AFTER_INDEX, List.IndexInList.new(.USED, 2), alloc);
    // try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.LAST_N_FROM_LIST, 5, .AFTER_INDEX, List.IndexInList.new(.USED, 2), alloc)", List.LLSlice{ .count = 5, .first = 15, .last = 19, .list = .USED }, "LLSlice{ .count = 5, .first = 15, .last = 19, .list = .USED }", "unexpected result from function", .{});
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 0, 1, 2, 15, 16, 17, 18, 19, 3, 4}, // used_indexes
    //     "abc\x00\x00\x00\x00\x00de", // used_vals
    //     &.{ 8, 9, 10, 11, 12, 13, 14 }, // free_indexes
    //     &.{ 0, 0, 0,  0,  0,  0,  0 },  // free_vals
    //     &.{5, 6, 7}, // invalid_indexes
    //     "fgh", // invalid_vals
    // );
    // // zig fmt: on
    // slice_iter_state = slice_result.new_iterator_state_at_end_of_slice(&linked_list, 0);
    // slice_iter = slice_iter_state.iterator();
    // str = "ijklm";
    // _ = slice_iter.perform_action_on_all_prev_items(Action.set_value_from_string, @ptrCast(&str));
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 0, 1, 2, 15, 16, 17, 18, 19, 3, 4}, // used_indexes
    //     "abcmlkjide", // used_vals
    //     &.{ 8, 9, 10, 11, 12, 13, 14 }, // free_indexes
    //     &.{ 0, 0, 0,  0,  0,  0,  0 },  // free_vals
    //     &.{5, 6, 7}, // invalid_indexes
    //     "fgh", // invalid_vals
    // );
    // // zig fmt: on
    // slice_result = linked_list.get_items_and_insert_at(.SPARSE_LIST_FROM_SAME_SET, List.IndexesInSameList.new(.USED, &.{ 18, 2, 15, 0 }), .BEFORE_INDEX, List.IndexInList.new(.INVALID, 6), alloc);
    // try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.SPARSE_LIST_FROM_SAME_SET, List.IndexesInSameList.new(.USED, &.{ 18, 2, 15, 0 }), .BEFORE_INDEX, List.IndexInList.new(.INVALID, 6), alloc)", List.LLSlice{ .count = 4, .first = 18, .last = 0, .list = .INVALID }, "LLSlice{ .count = 4, .first = 18, .last = 0, .list = .INVALID }", "unexpected result from function", .{});
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 1, 16, 17, 19, 3, 4}, // used_indexes
    //     "blkide", // used_vals
    //     &.{ 8, 9, 10, 11, 12, 13, 14 }, // free_indexes
    //     &.{ 0, 0, 0,  0,  0,  0,  0 },  // free_vals
    //     &.{5, 18, 2, 15, 0, 6, 7}, // invalid_indexes
    //     "fjcmagh", // invalid_vals
    // );
    // // zig fmt: on
    // slice_result = linked_list.get_items_and_insert_at(.SPARSE_LIST_FROM_ANY_SET, &.{ List.IndexInList.new(.USED, 19), List.IndexInList.new(.FREE, 11), List.IndexInList.new(.INVALID, 7), List.IndexInList.new(.FREE, 8) }, .AT_BEGINNING_OF_LIST, .USED, alloc);
    // try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.SPARSE_LIST_FROM_ANY_SET, &.{ List.IndexInList.new(.USED, 19), List.IndexInList.new(.FREE, 11), List.IndexInList.new(.INVALID, 7), List.IndexInList.new(.FREE, 8) }, .AT_BEGINNING_OF_LIST, .USED, alloc)", List.LLSlice{ .count = 4, .first = 19, .last = 8, .list = .USED }, "LLSlice{ .count = 4, .first = 19, .last = 8, .list = .USED }", "unexpected result from function", .{});
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 19, 11, 7, 8, 1, 16, 17, 3, 4}, // used_indexes
    //     "i\x00h\x00blkde", // used_vals
    //     &.{ 9, 10, 12, 13, 14 }, // free_indexes
    //     &.{ 0, 0,  0,  0,  0 },  // free_vals
    //     &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
    //     "fjcmag", // invalid_vals
    // );
    // // zig fmt: on
    // slice_iter_state = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 0);
    // slice_iter = slice_iter_state.iterator();
    // str = "wxyz";
    // _ = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 19, 11, 7, 8, 1, 16, 17, 3, 4}, // used_indexes
    //     "wxyzblkde", // used_vals
    //     &.{ 9, 10, 12, 13, 14 }, // free_indexes
    //     &.{ 0, 0,  0,  0,  0 },  // free_vals
    //     &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
    //     "fjcmag", // invalid_vals
    // );
    // // zig fmt: on
    // slice_result = linked_list.get_items_and_insert_at(.FIRST_FROM_LIST_ELSE_CREATE_NEW, .FREE, .AT_END_OF_LIST, .USED, alloc);
    // try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.FIRST_FROM_LIST_ELSE_CREATE_NEW, .FREE, .AT_END_OF_LIST, .USED, alloc)", List.LLSlice{ .count = 1, .first = 9, .last = 9, .list = .USED }, "LLSlice{ .count = 1, .first = 9, .last = 9, .list = .USED }", "unexpected result from function", .{});
    // linked_list.list.ptr[slice_result.first].val = 'v';
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 19, 11, 7, 8, 1, 16, 17, 3, 4, 9}, // used_indexes
    //     "wxyzblkdev", // used_vals
    //     &.{ 10, 12, 13, 14 }, // free_indexes
    //     &.{ 0,  0,  0,  0 },  // free_vals
    //     &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
    //     "fjcmag", // invalid_vals
    // );
    // // zig fmt: on
    // slice_result = linked_list.get_items_and_insert_at(.LAST_N_FROM_LIST_ELSE_CREATE_NEW, List.CountFromList.new(.FREE, 6), .AFTER_INDEX, List.IndexInList.new(.USED, 17), alloc);
    // try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.LAST_N_FROM_LIST_ELSE_CREATE_NEW, List.CountFromList.new(.FREE, 6), .AFTER_INDEX, List.IndexInList.new(.USED, 17), alloc)", List.LLSlice{ .count = 6, .first = 10, .last = 21, .list = .USED }, "LLSlice{ .count = 6, .first = 10, .last = 21, .list = .USED }", "unexpected result from function", .{});
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 19, 11, 7, 8, 1, 16, 17, 10, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
    //     "wxyzblk\x00\x00\x00\x00\x00\x00dev", // used_vals
    //     &.{ }, // free_indexes
    //     &.{ }, // free_vals
    //     &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
    //     "fjcmag", // invalid_vals
    // );
    // // zig fmt: on
    // slice_iter_state = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 0);
    // slice_iter = slice_iter_state.iterator();
    // str = "123456";
    // _ = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 19, 11, 7, 8, 1, 16, 17, 10, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
    //     "wxyzblk123456dev", // used_vals
    //     &.{ }, // free_indexes
    //     &.{ }, // free_vals
    //     &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
    //     "fjcmag", // invalid_vals
    // );
    // // zig fmt: on
    // slice_result.slide_left(&linked_list, 1);
    // _ = slice_iter.reset();
    // str = "123456";
    // _ = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 19, 11, 7, 8, 1, 16, 17, 10, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
    //     "wxyzbl1234566dev", // used_vals
    //     &.{ }, // free_indexes
    //     &.{ }, // free_vals
    //     &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
    //     "fjcmag", // invalid_vals
    // );
    // // zig fmt: on
    // slice_result = List.LLSlice{ .count = 3, .first = 18, .last = 15, .list = .INVALID };
    // slice_result = linked_list.get_items_and_insert_at(.FROM_SLICE_ELSE_CREATE_NEW, List.LLSliceWithTotalNeeded{ .slice = slice_result, .total_needed = 4 }, .AFTER_INDEX, List.IndexInList.new(.USED, 10), alloc);
    // try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.FROM_SLICE_ELSE_CREATE_NEW, List.LLSliceWithTotalNeeded{ .slice = slice_result, .total_needed = 4 }, .AFTER_INDEX, List.IndexInList.new(.USED, 10), alloc)", List.LLSlice{ .count = 4, .first = 18, .last = 22, .list = .USED }, "LLSlice{ .count = 4, .first = 18, .last = 22, .list = .USED }", "unexpected result from function", .{});
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 19, 11, 7, 8, 1, 16, 17, 10, 18, 2, 15, 22, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
    //     "wxyzbl12jcm\x0034566dev", // used_vals
    //     &.{ }, // free_indexes
    //     &.{ }, // free_vals
    //     &.{5, 0, 6}, // invalid_indexes
    //     &.{102, 97, 103}, // invalid_vals
    // );
    // // zig fmt: on
    // slice_iter_state = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 0);
    // slice_iter = slice_iter_state.iterator();
    // str = "7890";
    // _ = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 19, 11, 7, 8, 1, 16, 17, 10, 18, 2, 15, 22, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
    //     "wxyzbl12789034566dev", // used_vals
    //     &.{ }, // free_indexes
    //     &.{ }, // free_vals
    //     &.{5, 0, 6}, // invalid_indexes
    //     &.{102, 97, 103}, // invalid_vals
    // );
    // // zig fmt: on
    // slice_result.slide_left(&linked_list, 2);
    // slice_result.grow_end_rightward(&linked_list, 7);
    // var slice_iter_state_with_slot = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 1);
    // slice_iter = slice_iter_state_with_slot.iterator();
    // InsertionSort.insertion_sort_iterator(TestElem, slice_iter, Action.move_data, Action.greater_than, null);
    // // zig fmt: off
    // try expect.full_ll_state(
    //     &linked_list,
    //     &.{ 19, 11, 7, 8, 1, 16, 17, 10, 18, 2, 15, 22, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
    //     "wxyzbl01234566789dev", // used_vals
    //     &.{ }, // free_indexes
    //     &.{ }, // free_vals
    //     &.{5, 0, 6}, // invalid_indexes
    //     &.{102, 97, 103}, // invalid_vals
    // );
    // // zig fmt: on
}
