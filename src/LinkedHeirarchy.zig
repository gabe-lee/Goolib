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
const Flags = Root.Flags;
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
/// - Singly Linked List
/// - Binary Tree
/// - Heirarchy/DOM
pub const ForwardLinkedHeirarchyOptions = struct {
    /// Options for the underlying `List` that holds all the element memory
    /// for this `LinkedHeirarchy`
    element_memory_options: Root.List.ListOptions,
    /// Options for the `List` that holds the traversal stack trace when
    /// traversing/iterating the `LinkedHeirarchy`
    traversal_trace_options: Root.List.ListOptionsWithoutElem,
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
    /// increases by one. Any other code trying to aquire an item by id will additionaly check
    /// that the generation packed with the index matches the current generation.
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
    /// The field on the user element type that will hold the 'next' sibling
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    next_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'first child on the left side'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    left_children_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'first child on the right side'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    right_children_field: ?[]const u8 = null,
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
    /// Add additional O(N) time asserts in some functions. Most of these validate
    /// that inputs are in the state the user claimed (are siblings in order, child of parent, no cyclic references, etc.)
    strong_asserts: bool = true,
    /// If your Heirarchy has a guaranteed max-depth, you can provide the max depth here
    /// to cause heirarchy traversal to use memory directly allocated on the stack frame instead of the heap.
    traverse_with_stack_memory_and_max_depth: ?usize = null,
};

pub const GenerationDetails = struct {
    index_bits: comptime_int,
    generation_bits: comptime_int,
};

fn assert_field_type_matches_index_type(comptime elem: type, comptime index: type, comptime field: ?[]const u8) usize {
    if (field) |F| {
        assert_with_reason(@hasField(elem, F), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(elem), F });
        const T = @FieldType(elem, F);
        assert_with_reason(T == index, @src(), "field `{s}` on element type `{s}` is not type `{s}`", .{ F, @typeName(elem), @typeName(index) });
        return 1;
    }
    return 0;
}

pub fn LinkedHeirarchy(comptime options: ForwardLinkedHeirarchyOptions) type {
    const E = options.element_memory_options.element_type;
    const I = options.element_memory_options.index_type;
    var linkage_count = assert_field_type_matches_index_type(E, I, options.prev_sibling_field);
    linkage_count += assert_field_type_matches_index_type(E, I, options.next_field);
    linkage_count += assert_field_type_matches_index_type(E, I, options.left_children_field);
    linkage_count += assert_field_type_matches_index_type(E, I, options.right_children_field);
    assert_with_reason(linkage_count > 0, @src(), "LinkedHeirarchy must have at least 1 linkage field", .{});
    const F_IS_LEFT = options.left_children_field != null;
    const F_IS_RIGHT = options.right_children_field != null;
    const F_IS_NEXT = options.next_field != null;
    const F_LINK = get: {
        if (options.left_children_field) |F| break :get F;
        if (options.right_children_field) |F| break :get F;
        if (options.next_field) |F| break :get F;
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
        free_count: Id = 0,
        first_root_id: Id = NULL_ID,

        const HAS_NEXT = options.next_sibling_field != null;
        const NEXT_FIELD = if (HAS_NEXT) options.next_sibling_field.? else "";
        const HAS_LEFT_CHILDREN = options.left_children_field != null;
        const LEFT_CHILDREN_FIELD = if (HAS_LEFT_CHILDREN) options.left_children_field.? else "";
        const HAS_RIGHT_CHILDREN = options.right_children_field != null;
        const RIGHT_CHILDREN_FIELD = if (HAS_RIGHT_CHILDREN) options.right_children_field.? else "";
        const FREE_FIELD = F_LINK;
        const HAS_OWN_ID = options.own_id_field != null;
        const OWN_ID_FIELD = if (HAS_OWN_ID) options.own_id_field.? else "";
        const HAS_GEN = options.generation_details != null;
        const GEN_OFFSET = if (HAS_GEN) options.generation_details.PackedWithCachedIndex.index_bits else 0;
        const IDX_MASK: Id = if (HAS_GEN) (@as(Id, 1) << GEN_OFFSET) - 1 else math.maxInt(Id);
        const IDX_CLEAR: Id = if (HAS_GEN) ~IDX_MASK else 0;
        const GEN_MASK: Id = if (HAS_GEN) ~IDX_MASK else 0;
        const GEN_CLEAR: Id = if (HAS_GEN) IDX_MASK else 0;
        const FREE_IS_NEXT = F_IS_NEXT;
        const FREE_IS_LEFT = F_IS_LEFT;
        const FREE_IS_RIGHT = F_IS_RIGHT;
        const STRONG_ASSERTS = options.strong_asserts;
        const HAS_MAX_DEPTH = options.traverse_with_stack_memory_and_max_depth != null;
        const MAX_DEPTH = if (HAS_MAX_DEPTH) options.traverse_with_stack_memory_and_max_depth.? else 0;
        const UNINIT = Heirarchy{};
        const UNINIT_ELEM: Elem = make: {
            var elem: [1]Elem = undefined;
            if (options.element_memory_options.secure_wipe_bytes) {
                Utils.secure_zero(Elem, &elem);
            }
            Internal.set_own_id(&elem[0], NULL_ID);
            Internal.set_next_id(&elem[0], NULL_ID);
            Internal.set_left_child_id(&elem[0], NULL_ID);
            Internal.set_right_child_id(&elem[0], NULL_ID);
            break :make elem[0];
        };
        const NULL_ID = math.maxInt(Id);
        const NULL_INDEX = math.maxInt(Index);
        const NULL_GEN = if (HAS_GEN) (NULL_ID & ~IDX_MASK) else 0;
        const GEN_ONE: Id = if (HAS_GEN) @as(Id, 1) << GEN_OFFSET else 1;
        const HAS_ONLY_ONE_CHILD_SIDE = (HAS_LEFT_CHILDREN and !HAS_RIGHT_CHILDREN) or (HAS_RIGHT_CHILDREN and !HAS_LEFT_CHILDREN);
        const HAS_CHILD_NODES = HAS_LEFT_CHILDREN or HAS_RIGHT_CHILDREN;
        const COPY_VAL_FN = options.custom_copy_only_value_fn;
        const UNINIT_TRACE_FRAME = HeirarchyTraverseFrame{};
        const TRACE_LIST_OPTIONS = Root.List.ListOptions.from_options_without_elem(options.traversal_trace_options, HeirarchyTraverseFrame, @ptrCast(&UNINIT_TRACE_FRAME));

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
        const Range = struct {
            first: Id = NULL_ID,
            last: Id = NULL_ID,
        };
        const FirstLastParent = struct {
            first: Id = NULL_ID,
            last: Id = NULL_ID,
            parent: Id = NULL_ID,
        };

        // pub const CursorOptions = struct {
        //     cache_first_sibling: bool = false,
        //     cache_last_sibling: bool = false,
        //     cache_prev_sibling: bool = false,

        //     pub inline fn this_id_only() CursorOptions {
        //         return CursorOptions{
        //             .cache_first_sibling = false,
        //             .cache_last_sibling = false,
        //             .cache_prev_sibling = false,
        //         };
        //     }
        //     pub inline fn this_and_first_id() CursorOptions {
        //         return CursorOptions{
        //             .cache_first_sibling = true,
        //             .cache_last_sibling = false,
        //             .cache_prev_sibling = false,
        //         };
        //     }
        //     pub inline fn this_and_last_id() CursorOptions {
        //         return CursorOptions{
        //             .cache_first_sibling = false,
        //             .cache_last_sibling = true,
        //             .cache_prev_sibling = false,
        //         };
        //     }
        //     pub inline fn this_and_prev_id() CursorOptions {
        //         return CursorOptions{
        //             .cache_first_sibling = false,
        //             .cache_last_sibling = false,
        //             .cache_prev_sibling = true,
        //         };
        //     }
        //     pub inline fn this_first_and_last_id() CursorOptions {
        //         return CursorOptions{
        //             .cache_first_sibling = true,
        //             .cache_last_sibling = true,
        //             .cache_prev_sibling = false,
        //         };
        //     }
        //     pub inline fn this_first_and_prev_id() CursorOptions {
        //         return CursorOptions{
        //             .cache_first_sibling = true,
        //             .cache_last_sibling = false,
        //             .cache_prev_sibling = true,
        //         };
        //     }
        //     pub inline fn this_last_and_prev_id() CursorOptions {
        //         return CursorOptions{
        //             .cache_first_sibling = false,
        //             .cache_last_sibling = true,
        //             .cache_prev_sibling = true,
        //         };
        //     }
        //     pub inline fn this_first_last_and_prev_id() CursorOptions {
        //         return CursorOptions{
        //             .cache_first_sibling = true,
        //             .cache_last_sibling = true,
        //             .cache_prev_sibling = true,
        //         };
        //     }
        // };
        // zig fmt: off
        // pub const CursorOptions = enum(u3) {
        //     THIS_ID_ONLY                  = 0b000,
        //     THIS_AND_FIRST_ID             = 0b001,
        //     THIS_AND_LAST_ID              = 0b010,
        //     THIS_AND_PREV_ID              = 0b100,
        //     THIS_FIRST_AND_LAST_ID        = 0b011,
        //     THIS_FIRST_AND_PREV_ID        = 0b101,
        //     THIS_LAST_AND_PREV_ID         = 0b110,
        //     THIS_FIRST_LAST_AND_PREV_ID   = 0b111,

        // };
        // // zig fmt: on
        // pub fn Cursor(comptime opts: CursorOptions) type {
        //     return struct {
        //         const Self = @This();
        //         pub const FIRST = @intFromEnum(opts) & 0b001 == 0b001;
        //         pub const LAST = @intFromEnum(opts) & 0b010 == 0b010;
        //         pub const PREV = @intFromEnum(opts) & 0b100 == 0b100;
        //         pub const OPTS = opts;

        //         this_id: Id = NULL_ID,
        //         /// #### WARNING
        //         /// It is not intended for the user to manually update this value,
        //         /// let methods on `Cursor` and `LinkedHeirarchy` manage this field
        //         /// unless you are *positive* you know what you are doing
        //         prev_sibling_id: if (PREV) Id else void = if (PREV) NULL_ID else void{},
        //         /// #### WARNING
        //         /// It is not intended for the user to manually update this value,
        //         /// let methods on `Cursor` and `LinkedHeirarchy` manage this field
        //         /// unless you are *positive* you know what you are doing
        //         first_sibling_id: if (FIRST) Id else void = if (FIRST) NULL_ID else void{},
        //         /// #### WARNING
        //         /// It is not intended for the user to manually update this value,
        //         /// let methods on `Cursor` and `LinkedHeirarchy` manage this field
        //         /// unless you are *positive* you know what you are doing
        //         last_sibling_id: if (LAST) Id else void = if (LAST) NULL_ID else void{},

        //         pub inline fn this_id_only(id: Id) Self {
        //             return Self{ .this_id = id };
        //         }
        //         pub inline fn this_and_first_id(this_id: Id, first_sibling_id: Id) Self {
        //             assert_with_reason(FIRST, @src(), "Cursor({s}) does not cache first sibling id", .{@tagName(opts)});
        //             return Self{ .this_id = this_id, .first_sibling_id = first_sibling_id };
        //         }
        //         pub inline fn this_and_last_id(this_id: Id, last_sibling_id: Id) Self {
        //             assert_with_reason(LAST, @src(), "Cursor({s}) does not cache last sibling id", .{@tagName(opts)});
        //             return Self{ .this_id = this_id, .last_sibling_id = last_sibling_id };
        //         }
        //         pub inline fn this_and_prev_id(this_id: Id, prev_sibling_id: Id) Self {
        //             assert_with_reason(PREV, @src(), "Cursor({s}) does not cache prev sibling id", .{@tagName(opts)});
        //             return Self{ .this_id = this_id, .prev_sibling_id = prev_sibling_id };
        //         }
        //         pub inline fn this_first_and_last_id(this_id: Id, first_sibling_id: Id, last_sibling_id: Id) Self {
        //             assert_with_reason(LAST, @src(), "Cursor({s}) does not cache last sibling id", .{@tagName(opts)});
        //             assert_with_reason(FIRST, @src(), "Cursor({s}) does not cache first sibling id", .{@tagName(opts)});
        //             return Self{ .this_id = this_id, .first_sibling_id = first_sibling_id, .last_sibling_id = last_sibling_id };
        //         }
        //         pub inline fn this_first_and_prev_id(this_id: Id, first_sibling_id: Id, prev_sibling_id: Id) Self {
        //             assert_with_reason(PREV, @src(), "Cursor({s}) does not cache prev sibling id", .{@tagName(opts)});
        //             assert_with_reason(FIRST, @src(), "Cursor({s}) does not cache first sibling id", .{@tagName(opts)});
        //             return Self{ .this_id = this_id, .first_sibling_id = first_sibling_id, .prev_sibling_id = prev_sibling_id };
        //         }
        //         pub inline fn this_last_and_prev_id(this_id: Id, last_sibling_id: Id, prev_sibling_id: Id) Self {
        //             assert_with_reason(LAST, @src(), "Cursor({s}) does not cache last sibling id", .{@tagName(opts)});
        //             assert_with_reason(PREV, @src(), "Cursor({s}) does not cache prev sibling id", .{@tagName(opts)});
        //             return Self{ .this_id = this_id, .prev_sibling_id = prev_sibling_id, .last_sibling_id = last_sibling_id };
        //         }
        //         pub inline fn this_first_last_and_prev_id(this_id: Id, first_sibling_id: Id, last_sibling_id: Id, prev_sibling_id: Id) Self {
        //             assert_with_reason(LAST, @src(), "Cursor({s}) does not cache last sibling id", .{@tagName(opts)});
        //             assert_with_reason(FIRST, @src(), "Cursor({s}) does not cache first sibling id", .{@tagName(opts)});
        //             assert_with_reason(PREV, @src(), "Cursor({s}) does not cache prev sibling id", .{@tagName(opts)});
        //             return Self{ .this_id = this_id, .first_sibling_id = first_sibling_id, .last_sibling_id = last_sibling_id, .prev_sibling_id = prev_sibling_id };
        //         }

        //         pub inline fn init_last_sibling(self: *Self, heirarchy: *Heirarchy) void {
        //             if (Self.LAST and self.last_sibling_id == NULL_ID) {
        //                 self.last_sibling_id = heirarchy.find_last_sibling(self.this_id);
        //             }
        //         }

        //         pub inline fn to_range(self: Self) CursorRange(opts) {
        //             return CursorRange(opts){
        //                 .range_first_id = self.this_id,
        //                 .range_last_id = self.this_id,
        //                 .first_sibling_id = self.first_sibling_id,
        //                 .last_sibling_id = self.last_sibling_id,
        //                 .prev_sibling_id = self.prev_sibling_id,
        //             };
        //         }
        //         pub inline fn with_new_id(self: Self, new_id: Id) Self {
        //             var new = self;
        //             new.this_id = new_id;
        //             return new;
        //         }
        //         pub inline fn with_new_options(self: Self, comptime new_opts: CursorOptions) Cursor(new_opts) {
        //             var new = Cursor(new_opts){};
        //             new.this_id = self.this_id;
        //             if (Self.LAST and Cursor(new_opts).LAST) {
        //                 new.last_sibling_id = self.last_sibling_id;
        //             }
        //             if (Self.FIRST and Cursor(new_opts).FIRST) {
        //                 new.first_sibling_id = self.first_sibling_id;
        //             }
        //             if (Self.PREV and Cursor(new_opts).PREV) {
        //                 new.prev_sibling_id = self.prev_sibling_id;
        //             }
        //             return new;
        //         }
        //     };
        // }
        // pub fn CursorRange(comptime opts: CursorOptions) type {
        //     return struct {
        //         const Self = @This();
        //         pub const FIRST = @intFromEnum(opts) & 0b001 == 0b001;
        //         pub const LAST = @intFromEnum(opts) & 0b010 == 0b010;
        //         pub const PREV = @intFromEnum(opts) & 0b100 == 0b100;
        //         pub const OPTS = opts;

        //         range_first_id: Id = NULL_ID,
        //         range_last_id: Id = NULL_ID,
        //         /// #### WARNING
        //         /// It is not intended for the user to manually update this value,
        //         /// let methods on `Cursor` and `LinkedHeirarchy` manage this field
        //         /// unless you are *positive* you know what you are doing
        //         prev_sibling_id: if (PREV) Id else void = if (PREV) NULL_ID else void{},
        //         /// #### WARNING
        //         /// It is not intended for the user to manually update this value,
        //         /// let methods on `Cursor` and `LinkedHeirarchy` manage this field
        //         /// unless you are *positive* you know what you are doing
        //         first_sibling_id: if (FIRST) Id else void = if (FIRST) NULL_ID else void{},
        //         /// #### WARNING
        //         /// It is not intended for the user to manually update this value,
        //         /// let methods on `Cursor` and `LinkedHeirarchy` manage this field
        //         /// unless you are *positive* you know what you are doing
        //         last_sibling_id: if (LAST) Id else void = if (LAST) NULL_ID else void{},

        //         pub inline fn range_only(range_first_id: Id, range_last_id: Id) Self {
        //             return Self{ .range_first_id = range_first_id, .range_last_id = range_last_id };
        //         }
        //         pub inline fn range_and_first_id(range_first_id: Id, range_last_id: Id, first_sibling_id: Id) Self {
        //             assert_with_reason(FIRST, @src(), "Cursor({s}) does not cache first sibling id", .{@tagName(opts)});
        //             return Self{ .range_first_id = range_first_id, .range_last_id = range_last_id, .first_sibling_id = first_sibling_id };
        //         }
        //         pub inline fn range_and_last_id(range_first_id: Id, range_last_id: Id, last_sibling_id: Id) Self {
        //             assert_with_reason(LAST, @src(), "Cursor({s}) does not cache last sibling id", .{@tagName(opts)});
        //             return Self{ .range_first_id = range_first_id, .range_last_id = range_last_id, .last_sibling_id = last_sibling_id };
        //         }
        //         pub inline fn range_and_prev_id(range_first_id: Id, range_last_id: Id, prev_sibling_id: Id) Self {
        //             assert_with_reason(PREV, @src(), "Cursor({s}) does not cache prev sibling id", .{@tagName(opts)});
        //             return Self{ .range_first_id = range_first_id, .range_last_id = range_last_id, .prev_sibling_id = prev_sibling_id };
        //         }
        //         pub inline fn range_first_and_last_id(range_first_id: Id, range_last_id: Id, first_sibling_id: Id, last_sibling_id: Id) Self {
        //             assert_with_reason(LAST, @src(), "Cursor({s}) does not cache last sibling id", .{@tagName(opts)});
        //             assert_with_reason(FIRST, @src(), "Cursor({s}) does not cache first sibling id", .{@tagName(opts)});
        //             return Self{ .range_first_id = range_first_id, .range_last_id = range_last_id, .first_sibling_id = first_sibling_id, .last_sibling_id = last_sibling_id };
        //         }
        //         pub inline fn range_first_and_prev_id(range_first_id: Id, range_last_id: Id, first_sibling_id: Id, prev_sibling_id: Id) Self {
        //             assert_with_reason(PREV, @src(), "Cursor({s}) does not cache prev sibling id", .{@tagName(opts)});
        //             assert_with_reason(FIRST, @src(), "Cursor({s}) does not cache first sibling id", .{@tagName(opts)});
        //             return Self{ .range_first_id = range_first_id, .range_last_id = range_last_id, .first_sibling_id = first_sibling_id, .prev_sibling_id = prev_sibling_id };
        //         }
        //         pub inline fn range_last_and_prev_id(range_first_id: Id, range_last_id: Id, last_sibling_id: Id, prev_sibling_id: Id) Self {
        //             assert_with_reason(LAST, @src(), "Cursor({s}) does not cache last sibling id", .{@tagName(opts)});
        //             assert_with_reason(PREV, @src(), "Cursor({s}) does not cache prev sibling id", .{@tagName(opts)});
        //             return Self{ .range_first_id = range_first_id, .range_last_id = range_last_id, .prev_sibling_id = prev_sibling_id, .last_sibling_id = last_sibling_id };
        //         }
        //         pub inline fn range_first_last_and_prev_id(range_first_id: Id, range_last_id: Id, first_sibling_id: Id, last_sibling_id: Id, prev_sibling_id: Id) Self {
        //             assert_with_reason(LAST, @src(), "Cursor({s}) does not cache last sibling id", .{@tagName(opts)});
        //             assert_with_reason(FIRST, @src(), "Cursor({s}) does not cache first sibling id", .{@tagName(opts)});
        //             assert_with_reason(PREV, @src(), "Cursor({s}) does not cache prev sibling id", .{@tagName(opts)});
        //             return Self{ .range_first_id = range_first_id, .range_last_id = range_last_id, .first_sibling_id = first_sibling_id, .last_sibling_id = last_sibling_id, .prev_sibling_id = prev_sibling_id };
        //         }

        //         pub inline fn init_last_sibling(self: *Self, heirarchy: *Heirarchy) void {
        //             if (Self.LAST and self.last_sibling_id == NULL_ID) {
        //                 self.last_sibling_id = heirarchy.find_last_sibling(self.range_last_id);
        //             }
        //         }

        //         pub inline fn to_cursor_first(self: Self) Cursor(opts) {
        //             return Cursor(opts){
        //                 .this_id = self.range_first_id,
        //                 .first_sibling_id = self.first_sibling_id,
        //                 .last_sibling_id = self.last_sibling_id,
        //                 .prev_sibling_id = self.prev_sibling_id,
        //             };
        //         }
        //         pub inline fn to_cursor_last(self: Self) Cursor(opts) {
        //             return Cursor(opts){
        //                 .this_id = self.range_last_id,
        //                 .first_sibling_id = self.first_sibling_id,
        //                 .last_sibling_id = self.last_sibling_id,
        //                 .prev_sibling_id = self.prev_sibling_id,
        //             };
        //         }
        //         pub inline fn with_new_first(self: Self, new_first: Id) Self {
        //             var new = self;
        //             new.range_first_id = new_first;
        //             return new;
        //         }
        //         pub inline fn with_new_last(self: Self, new_last: Id) Self {
        //             var new = self;
        //             new.range_last_id = new_last;
        //             return new;
        //         }
        //         pub inline fn with_new_first_last(self: Self, new_first: Id, new_last: Id) Self {
        //             var new = self;
        //             new.range_first_id = new_first;
        //             new.range_last_id = new_last;
        //             return new;
        //         }
        //         pub inline fn with_new_options(self: Self, comptime new_opts: CursorOptions) CursorRange(new_opts) {
        //             var new = CursorRange(new_opts){};
        //             new.range_first_id = self.range_first_id;
        //             new.range_last_id = self.range_last_id;
        //             if (Self.LAST and CursorRange(new_opts).LAST) {
        //                 new.last_sibling_id = self.last_sibling_id;
        //             }
        //             if (Self.FIRST and CursorRange(new_opts).FIRST) {
        //                 new.first_sibling_id = self.first_sibling_id;
        //             }
        //             if (Self.PREV and CursorRange(new_opts).PREV) {
        //                 new.prev_sibling_id = self.prev_sibling_id;
        //             }
        //             return new;
        //         }
        //     };
        // }
        // pub const StackFrameOptions = struct {
        //     cache_first_sibling: bool = false,
        //     cache_last_sibling: bool = false,
        //     cache_prev_sibling: bool = false,
        // };
        // pub fn StackFrame(comptime frame_options: ?StackFrameOptions) type {
        //     const E = frame_options != null;
        //     const opts = if (EXISTS) frame_options.? else void{};
        //     return struct {
        //         pub const EXISTS = E;
        //         pub const FIRST = if (EXISTS) opts.cache_first_sibling == true else false;
        //         pub const LAST = if (EXISTS) opts.cache_last_sibling == true else false;
        //         pub const PREV = if (EXISTS) opts.cache_prev_sibling == true else false;

        //         curr_id: if (EXISTS) Id else void = if (EXISTS) NULL_ID else void{},
        //         first_sibling_id: if (FIRST) Id else void = if (FIRST) NULL_ID else void{},
        //         last_sibling_id: if (LAST) Id else void = if (LAST) NULL_ID else void{},
        //         prev_sibling_id: if (PREV) Id else void = if (PREV) NULL_ID else void{},
        //     };
        // }

        var DUMMY_ID: Id = NULL_ID;
        // var DUMMY_ELEM: Elem = undefined;

        pub inline fn get_gen_index(id: Id) GenIndex {
            if (HAS_GEN) return GenIndex{
                .index = @intCast(id & IDX_MASK),
                .gen = id & GEN_MASK,
            };
            return GenIndex{ .index = @intCast(id & IDX_MASK) };
        }
        pub inline fn get_gen(id: Id) Id {
            if (HAS_GEN) return id & GEN_MASK;
            return NULL_GEN;
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
        pub inline fn get_next_id(ptr: *const Elem) Id {
            if (!HAS_NEXT) return NULL_ID;
            return @field(ptr, NEXT_FIELD);
        }
        pub inline fn get_left_child_id(ptr: *const Elem) Id {
            if (!HAS_LEFT_CHILDREN) return NULL_ID;
            return @field(ptr, LEFT_CHILDREN_FIELD);
        }
        pub inline fn get_right_child_id(ptr: *const Elem) Id {
            if (!HAS_RIGHT_CHILDREN) return NULL_ID;
            return @field(ptr, RIGHT_CHILDREN_FIELD);
        }

        /// All functions/structs in this namespace fall in at least one of 3 categories:
        /// - DANGEROUS to use if you do not manually manage and maintain a valid linked state
        /// - Are only useful for asserting/creating intenal state
        /// - Cover VERY niche use cases (used internally) and are placed here to keep the top-level namespace less polluted
        ///
        /// They are provided here publicly to facilitate opt-in special user use cases
        pub const Internal = struct {
            pub inline fn set_next_id(ptr: *Elem, val: Id) void {
                if (!HAS_NEXT) return;
                @field(ptr, NEXT_FIELD).* = val;
            }
            pub inline fn set_left_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_LEFT_CHILDREN) return;
                @field(ptr, LEFT_CHILDREN_FIELD).* = val;
            }
            pub inline fn set_right_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_RIGHT_CHILDREN) return;
                @field(ptr, RIGHT_CHILDREN_FIELD).* = val;
            }
            pub inline fn set_own_id(ptr: *Elem, val: Id) void {
                if (!HAS_OWN_ID) return;
                @field(ptr, OWN_ID_FIELD).* = val;
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
                    if (HAS_NEXT) {
                        set_next_id(a, get_next_id(old_a));
                        set_next_id(b, get_next_id(old_b));
                    }
                    if (HAS_LEFT_CHILDREN) {
                        set_left_child_id(a, get_left_child_id(old_a));
                        set_left_child_id(b, get_left_child_id(old_b));
                    }
                    if (HAS_RIGHT_CHILDREN) {
                        set_right_child_id(a, get_right_child_id(old_a));
                        set_right_child_id(b, get_right_child_id(old_b));
                    }
                    if (HAS_OWN_ID) {
                        set_own_id(a, get_own_id(old_a));
                        set_own_id(b, get_own_id(old_b));
                    }
                }
            }

            pub fn initialize_new_index(self: *Heirarchy) Id {
                const new_id: Id = @intCast(self.list.len);
                var new_elem = UNINIT_ELEM;
                set_own_id(&new_elem, new_id);
                _ = self.list.append_assume_capacity(new_elem);
                return new_id;
            }

            pub fn initialize_new_indexes_as_siblings(self: *Heirarchy, count: Index) Range {
                assert_siblings_mode(@src());
                const first_id: Id = @intCast(self.list.len);
                const last_id: Id = first_id + @as(Id, @intCast(count - 1));
                var this_id: Id = first_id;
                _ = self.list.append_n_times_assume_capacity(UNINIT_ELEM, count);
                while (this_id < last_id) {
                    const this_ptr = self.get_ptr(this_id);
                    set_own_id(this_ptr, this_id);
                    this_id += 1;
                    set_next_id(this_ptr, this_id);
                }
                const this_ptr = self.get_ptr(this_id);
                set_own_id(this_ptr, this_id);
                return Range{
                    .first = first_id,
                    .last = last_id,
                };
            }

            pub fn pop_free_item(self: *Heirarchy) Id {
                assert_with_reason(self.free_count > 0 and self.first_free_id != NULL_ID, @src(), "no free items to pop", .{});
                const id = self.first_free_id;
                const ptr = self.get_ptr(id);
                const next_free = @field(ptr, FREE_FIELD);
                @field(ptr, FREE_FIELD).* = NULL_ID;
                self.first_free_id = next_free;
                self.free_count -= 1;
                return id;
            }

            pub fn push_free_item(self: *Heirarchy, id: Id) void {
                assert_with_reason(id != NULL_ID, @src(), "cannot push NULL_ID to free list", .{});
                const ptr = self.get_ptr(id);
                if (options.element_memory_options.secure_wipe_bytes) {
                    ptr.* = UNINIT_ELEM;
                } else {
                    if (!FREE_IS_LEFT) set_left_child_id(ptr, NULL_ID);
                    if (!FREE_IS_RIGHT) set_right_child_id(ptr, NULL_ID);
                    if (!FREE_IS_NEXT) set_next_id(ptr, NULL_ID);
                }
                @field(ptr, FREE_FIELD).* = self.first_free_id;
                self.first_free_id = id;
                self.free_count += 1;
            }

            pub fn pop_and_initialize_free_items_as_siblings(self: *Heirarchy, count: Index) Range {
                assert_with_reason(count > 0, @src(), "cannot pop 0 free items", .{});
                assert_with_reason(self.free_count >= count, @src(), "too few free items", .{});
                const first_free = pop_free_item(self);
                var c: Index = 0;
                var this_id = first_free;
                const limit = count - 1;
                while (c < limit) : (c += 1) {
                    const next_id = pop_free_item(self);
                    const this_ptr = self.get_ptr(this_id);
                    set_next_id(this_ptr, next_id);
                    this_id = next_id;
                }
                return Range{
                    .first = first_free,
                    .last = this_id,
                };
            }

            pub fn initialize_one_item(self: *Heirarchy) Id {
                if (self.free_count > 0) {
                    return pop_free_item(self);
                } else {
                    return initialize_new_index(self);
                }
            }

            pub fn initialize_items_as_siblings(self: *Heirarchy, count: Index) Range {
                var result: Range = undefined;
                const from_free = @min(count, self.free_count);
                const from_new = count - from_free;
                if (from_free > 0) {
                    result = pop_and_initialize_free_items_as_siblings(self, from_free);
                }
                if (from_new > 0) {
                    const new_result = initialize_new_indexes_as_siblings(self, count);
                    if (from_free == 0) {
                        result = new_result;
                    } else {
                        const last_free_ptr = self.get_ptr(result.last);
                        set_next_id(last_free_ptr, new_result.first);
                        result.last = new_result.last;
                    }
                }
                return result;
            }

            pub fn connect_new_slots_between_siblings(self: *Heirarchy, left_id: Id, first_new_id: Id, last_new_id: Id, right_id: Id) void {
                assert_siblings_mode(@src());
                assert_with_reason(left_id != NULL_ID, @src(), "left_id cannot be NULL_ID", .{});
                assert_with_reason(first_new_id != NULL_ID and last_new_id != NULL_ID, @src(), "neither first_new_id nor last_new_id can be NULL_ID", .{});
                Internal.assert_real_next_cached_next_match(self, left_id, right_id, @src());
                Internal.assert_2_siblings_in_order_no_cycles(self, first_new_id, last_new_id, true, false, @src());
                const left_ptr = self.get_ptr(left_id);
                set_next_id(left_ptr, first_new_id);
                const last_new_ptr = self.get_ptr(last_new_id);
                set_next_id(last_new_ptr, right_id);
            }

            pub fn disconnect_items_between_siblings(self: *Heirarchy, left_id: Id, first_removed_id: Id, last_removed_id: Id, right_id: Id) void {
                assert_siblings_mode(@src());
                assert_with_reason(left_id != NULL_ID, @src(), "left_id cannot be NULL_ID", .{});
                assert_with_reason(first_removed_id != NULL_ID and last_removed_id != NULL_ID, @src(), "neither first_removed_id nor last_removed_id can be NULL_ID", .{});
                Internal.assert_4_siblings_in_order_no_cycles_b_c_can_be_same_d_can_be_null(self, left_id, first_removed_id, last_removed_id, right_id, @src());
                const left_ptr = self.get_ptr(left_id);
                set_next_id(left_ptr, right_id);
                const last_removed_ptr = self.get_ptr(last_removed_id);
                set_next_id(last_removed_ptr, NULL_ID);
            }

            pub fn disconnect_all_items_after(self: *Heirarchy, left_id: Id, first_removed_id: Id, last_removed_id: Id, right_id: Id) void {
                assert_siblings_mode(@src());
                assert_with_reason(left_id != NULL_ID, @src(), "left_id cannot be NULL_ID", .{});
                assert_with_reason(first_removed_id != NULL_ID and last_removed_id != NULL_ID, @src(), "neither first_removed_id nor last_removed_id can be NULL_ID", .{});
                Internal.assert_4_siblings_in_order_no_cycles_b_c_can_be_same_d_can_be_null(self, left_id, first_removed_id, last_removed_id, right_id, @src());
                const left_ptr = self.get_ptr(left_id);
                set_next_id(left_ptr, right_id);
                const last_removed_ptr = self.get_ptr(last_removed_id);
                set_next_id(last_removed_ptr, NULL_ID);
            }

            // pub fn disconnect_sibling_internal(self: *Heirarchy, prev_id: Id, this_id: Id, next_id: Id, parent_id: Id) void {
            //     const conn_left: ConnPrev = get_conn_prev(self, prev_id);
            //     const conn_right: ConnPrev = get_conn_next(self, next_id);
            //     if (prev_id == NULL_ID) {
            //         if (parent_id != NULL_ID) {
            //             if (MUST_CHECK_CHILD_IS_FIRST) {
            //                 const parent_ptr = self.get_ptr(this_id);
            //                 var found_first: bool = false;
            //                 if (MUST_CHECK_CHILD_IS_LAST_LEFT) {
            //                     const parent_first_left = get_left_child_id(parent_ptr);
            //                     if (parent_first_left == this_id) {
            //                         Internal.set_left_child_id(parent_ptr, next_id);
            //                         found_first = true;
            //                     }
            //                 }
            //                 if (MUST_CHECK_CHILD_IS_LAST_RIGHT) {
            //                     const parent_first_right = get_right_child_id(parent_ptr);
            //                     if (parent_first_right == this_id) {
            //                         Internal.set_right_child_id(parent_ptr, next_id);
            //                         found_first = true;
            //                     }
            //                 }
            //                 assert_with_reason(false, @src(), "item (index {d}) was the first sibling with a non-null parent (index {d}), but parent didn't have it cached in either the 'first-left' or 'first-right' field", .{ get_index(this_id), get_index(parent_id) });
            //             }
            //         } else {
            //             assert_with_reason(self.first_root_id == this_id, @src(), "item (index {d}) was the 'first sibling' with a NULL parent, but it wasnt the index cached in 'Heriarchy.first_root_id' ({d})", .{ get_index(this_id), get_index(self.first_root_id) });
            //             self.first_root_id = next_id;
            //         }
            //     }
            //     if (next_id == NULL_ID) {
            //         if (parent_id != NULL_ID) {
            //             if (MUST_CHECK_CHILD_IS_LAST) {
            //                 const parent_ptr = self.get_ptr(this_id);
            //                 var found_last: bool = false;
            //                 if (MUST_CHECK_CHILD_IS_LAST_LEFT) {
            //                     const parent_last_left = get_last_left_child_id(parent_ptr);
            //                     if (parent_last_left == this_id) {
            //                         Internal.set_last_l_child_id(parent_ptr, prev_id);
            //                         found_last = true;
            //                     }
            //                 }
            //                 if (MUST_CHECK_CHILD_IS_LAST_RIGHT) {
            //                     const parent_last_right = get_last_right_child_id(parent_ptr);
            //                     if (parent_last_right == this_id) {
            //                         Internal.set_last_r_child_id(parent_ptr, prev_id);
            //                         found_last = true;
            //                     }
            //                 }
            //                 assert_with_reason(false, @src(), "item (index {d}) was the ;last sibling with a non-null parent (index {d}), but parent didn't have it cached in either the 'last-left' or 'last-right' field", .{ get_index(this_id), get_index(parent_id) });
            //             }
            //         } else {
            //             assert_with_reason(self.last_root_id == this_id, @src(), "item (index {d}) was the 'last sibling' with a NULL parent, but it wasnt the index cached in 'Heriarchy.last_root_id' ({d})", .{ get_index(this_id), get_index(self.last_root_id) });
            //             self.last_root_id = next_id;
            //         }
            //     }
            //     Internal.connect(conn_left, conn_right);
            //     const this_ptr = self.get_ptr(this_id);
            //     set_parent_id(this_ptr, NULL_ID);
            //     set_prev_sib_id(this_ptr, NULL_ID);
            //     set_next_id(this_ptr, NULL_ID);
            // }

            fn assert_real_next_cached_next_match(self: *Heirarchy, this_id: Id, real_next: Id, src_loc: ?SourceLocation) void {
                const cached_next = get_next_id(self.get_ptr(this_id));
                assert_with_reason(real_next == cached_next, src_loc, "real next id (gen = {d}, idx = {d}) does not match the cached next id (gen = {d}, idx = {d}) on the prev sibling (gen = {d}, idx = {d})", .{ get_gen_index(real_next).gen, get_index(real_next), get_gen_index(cached_next).gen, get_index(cached_next), get_gen_index(this_id).gen, get_index(this_id) });
            }

            fn assert_siblings_mode(src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_NEXT, src_loc, "cannot connect elements as siblings when tree/linked-list does not allow siblings (no 'next' field)", .{});
            }

            fn assert_tree_left_mode(src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_LEFT_CHILDREN, src_loc, "cannot connect elements as left children when tree/linked-list/heirarchy does not allow left children (no 'left children' field)", .{});
            }

            fn assert_tree_right_mode(src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_RIGHT_CHILDREN, src_loc, "cannot connect elements as right children when tree/linked-list/heirarchy does not allow right children (no 'right children' field)", .{});
            }

            fn assert_2_siblings_in_order_no_cycles(self: *Heirarchy, a: Id, b: Id, comptime a_b_can_equal: bool, comptime b_can_be_null: bool, src_loc: ?SourceLocation) void {
                assert_idx_less_than_len(get_index(a), self.list.len, src_loc);
                assert_idx_less_than_len(get_index(b), self.list.len, src_loc);
                assert_with_reason(a != NULL_ID, src_loc, "id 'a' was NULL_ID", .{});
                if (!b_can_be_null) assert_with_reason(b != NULL_ID, src_loc, "id 'b' was NULL_ID", .{});
                if (a_b_can_equal and get_index(a) == get_index(b)) {
                    assert_with_reason(same_gen(a, b), src_loc, "same indexes {d} had mimatched generations {d}, {d}", .{ get_index(a), get_gen(a), get_gen(b) });
                    return;
                }
                if (!a_b_can_equal) assert_with_reason(get_index(a) != get_index(b), src_loc, "duplicate Id indexes {d}", .{get_index(a)});
                if (STRONG_ASSERTS) {
                    var slow = a;
                    var fast = a;
                    var fast_ptr = undefined;
                    while (true) {
                        fast_ptr = self.get_ptr(fast);
                        fast = get_next_id(fast_ptr);
                        assert_with_reason(fast != slow, src_loc, "fast pointer matched slow pointer: list is cyclic starting from index {d} and following 'next' fields", .{get_index(a)});
                        if (fast == b or fast == NULL_INDEX) break;
                        fast_ptr = self.get_ptr(fast);
                        fast = get_next_id(fast_ptr);
                        assert_with_reason(fast != slow, src_loc, "fast pointer matched slow pointer: list is cyclic starting from index {d} and following 'next' fields", .{get_index(a)});
                        if (fast == b or fast == NULL_INDEX) break;
                        slow = get_next_id(self.get_ptr(slow));
                    }
                    assert_with_reason(fast == b, @src(), "fast pointer reached end of siblings (NULL_ID) without finding b (index = {d})", .{get_index(b)});
                }
            }

            fn assert_4_siblings_in_order_no_cycles_b_c_can_be_same_d_can_be_null(self: *Heirarchy, a: Id, b: Id, c: Id, d: Id, src_loc: ?SourceLocation) void {
                assert_with_reason(get_index(a) != get_index(b) and get_index(a) != get_index(c) and get_index(a) != get_index(d) and get_index(d) != get_index(b) and get_index(d) != get_index(c), src_loc, "duplicate Id indexes a == (b, c, or d) or d == (a, b, or c): {d}, {d}, {d}, {d}", .{ get_index(a), get_index(b), get_index(c), get_index(d) });
                assert_with_reason(a != NULL_ID, src_loc, "id 'a' was NULL_ID", .{});
                assert_with_reason(b != NULL_ID, src_loc, "id 'b' was NULL_ID", .{});
                assert_with_reason(c != NULL_ID, src_loc, "id 'c' was NULL_ID", .{});
                if (get_index(b) == get_index(c)) {
                    assert_with_reason(same_gen(b, c), src_loc, "same indexes {d} had mimatched generations {d}, {d}", .{ get_index(b), get_gen(b), get_gen(c) });
                    return;
                }
                if (STRONG_ASSERTS) {
                    const ids: [3]Id = .{ b, c, d };
                    var slow = a;
                    var fast = a;
                    var fast_ptr = undefined;
                    var next_match: usize = 0;
                    while (true) {
                        fast_ptr = self.get_ptr(fast);
                        fast = get_next_id(fast_ptr);
                        assert_with_reason(fast != slow, src_loc, "fast pointer matched slow pointer: list is cyclic starting from index {d} and following 'next' fields", .{get_index(a)});
                        if (fast == ids[next_match]) next_match += 1;
                        if (next_match == 3 or fast == NULL_ID) break;
                        if (fast == ids[next_match]) next_match += 1;
                        if (next_match == 3 or fast == NULL_ID) break;
                        fast_ptr = self.get_ptr(fast);
                        fast = get_next_id(fast_ptr);
                        assert_with_reason(fast != slow, src_loc, "fast pointer matched slow pointer: list is cyclic starting from index {d} and following 'next' fields", .{get_index(a)});
                        if (fast == ids[next_match]) next_match += 1;
                        if (next_match == 3 or fast == NULL_ID) break;
                        if (fast == ids[next_match]) next_match += 1;
                        if (next_match == 3 or fast == NULL_ID) break;
                        slow = get_next_id(self.get_ptr(slow));
                    }
                    assert_with_reason(next_match == 3, @src(), "fast pointer reached end of siblings (NULL_ID) without finding all indexes in order ({d}, {d}, {d})", .{ get_index(b), get_index(c), get_index(d) });
                }
            }

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

        };

        pub inline fn new_empty(assert_alloc: AllocInfal) Heirarchy {
            var uninit = UNINIT;
            uninit.list = List.new_empty(assert_alloc);
            return uninit;
        }

        pub inline fn new_with_capacity(capacity: Index, alloc: AllocInfal) Heirarchy {
            var self = UNINIT;
            self.list.ensure_total_capacity_exact(capacity, alloc);
            return self;
        }

        pub inline fn clone(self: *const Heirarchy, alloc: Allocator) Heirarchy {
            var new_list = self.*;
            new_list.list = self.list.clone(alloc);
            return new_list;
        }

        pub inline fn insert_slot_after(self: *Heirarchy, this_id: Id, alloc: AllocInfal) Id {
            self.list.ensure_unused_capacity(1, alloc);
            return self.insert_slot_after_assume_capacity(this_id);
        }

        pub fn insert_slot_after_assume_capacity(self: *Heirarchy, this_id: Id) Id {
            const new_id = Internal.initialize_new_index(self);
            const right_id = get_next_id(self.get_ptr(this_id));
            Internal.connect_new_slots_between_siblings(self, this_id, new_id, new_id, right_id);
            return new_id;
        }

        pub inline fn insert_many_slots_after(self: *Heirarchy, this_id: Id, count: Index, alloc: AllocInfal) Range {
            self.list.ensure_unused_capacity(count, alloc);
            return self.insert_many_slots_after_assume_capacity(this_id, count);
        }

        pub fn insert_many_slots_after_assume_capacity(self: *Heirarchy, this_id: Id, count: Index) Range {
            const range = Internal.initialize_items_as_siblings(self, count);
            const right_id = get_next_id(self.get_ptr(this_id));
            Internal.connect_new_slots_between_siblings(self, this_id, range.first, range.last, right_id);
            return range;
        }

        pub fn insert_disconnected_items_after(self: *Heirarchy, this_id: Id, disconnected_items: Range) void {
            const right_id = get_next_id(self.get_ptr(this_id));
            assert_with_reason(get_next_id(self.get_ptr(disconnected_items.last)) == NULL_ID, @src(), "last disconnected item (index {d}) did not have a 'next' field that pointed to NULL_ID, it wasnt fully disconnected", .{get_index(disconnected_items.last)});
            Internal.connect_new_slots_between_siblings(self, this_id, disconnected_items.first, disconnected_items.last, right_id);
        }

        pub fn disconnect_item_range_after(self: *Heirarchy, this_id: Id, last_disconnect_id: Id) Range {
            const right_id = get_next_id(self.get_ptr(last_disconnect_id));
            const first_disconnect_id = get_next_id(self.get_ptr(this_id));
            Internal.disconnect_items_between_siblings(self, this_id, first_disconnect_id, last_disconnect_id, right_id);
            return Range{.first = first_disconnect_id, .last = last_disconnect_id};
        }

        pub fn insert_slot_at_beginning_of_left_children_assume_capacity(self: *Heirarchy, parent_id: Id) Id {
            Internal.assert_tree_left_mode(@src());
            const new_id = Internal.initialize_new_index(self);
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_left = get_left_child_id(parent_ptr);
            const new_ptr = self.get_ptr(new_id);
            Internal.set_next_id(new_ptr, old_first_left);
            Internal.set_left_child_id(parent_ptr, new_id);
            return new_id;
        }

        pub inline fn insert_many_slots_at_beginning_of_left_children(self: *Heirarchy, parent_id: Id, count: Index, alloc: AllocInfal) Range {
            self.list.ensure_unused_capacity(count, alloc);
            return self.insert_many_slots_at_beginning_of_left_children_assume_capacity(parent_id, count);
        }

        pub fn insert_many_slots_at_beginning_of_left_children_assume_capacity(self: *Heirarchy, parent_id: Id, count: Index) Range {
            Internal.assert_tree_left_mode(@src());
            const range = Internal.initialize_new_indexes_as_siblings(self, count);
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_left = get_left_child_id(parent_ptr);
            const new_last_ptr = self.get_ptr(range.last);
            Internal.set_next_id(new_last_ptr, old_first_left);
            Internal.set_left_child_id(parent_ptr, range.first);
            return range;
        }

        pub inline fn insert_slot_at_beginning_of_right_children(self: *Heirarchy, parent_id: Id, alloc: AllocInfal) Id {
            self.list.ensure_unused_capacity(1, alloc);
            return self.insert_slot_at_beginning_of_right_children_assume_capacity(parent_id);
        }

        pub fn insert_slot_at_beginning_of_right_children_assume_capacity(self: *Heirarchy, parent_id: Id) Id {
            Internal.assert_tree_right_mode(@src());
            const new_id = Internal.initialize_new_index(self);
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_right = get_right_child_id(parent_ptr);
            const new_ptr = self.get_ptr(new_id);
            Internal.set_next_id(new_ptr, old_first_right);
            Internal.set_right_child_id(parent_ptr, new_id);
            return new_id;
        }

        pub inline fn insert_many_slots_at_beginning_of_right_children(self: *Heirarchy, parent_id: Id, count: Index, alloc: AllocInfal) Range {
            self.list.ensure_unused_capacity(count, alloc);
            return self.insert_many_slots_at_beginning_of_right_children_assume_capacity(parent_id, count);
        }

        pub fn insert_many_slots_at_beginning_of_right_children_assume_capacity(self: *Heirarchy, parent_id: Id, count: Index) Range {
            Internal.assert_tree_right_mode(@src());
            const range = Internal.initialize_new_indexes_as_siblings(self, count);
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_right = get_right_child_id(parent_ptr);
            const new_last_ptr = self.get_ptr(range.last);
            Internal.set_next_id(new_last_ptr, old_first_right);
            Internal.set_right_child_id(parent_ptr, range.first);
            return range;
        }

        //CHECKPOINT remove children funcs

        pub inline fn free_disconnected_items_with_new_heap_traverser(self: *Heirarchy, first_disconected_id: Id, alloc: AllocInfal) void {
            var new_traverser = self.create_heirarchy_traverser_on_heap(alloc);
            defer new_traverser.free();
            self.free_disconnected_items_with_traverser(first_disconected_id, &new_traverser);
        }

        pub inline fn free_disconnected_items_with_new_stack_traverser(self: *Heirarchy, first_disconected_id: Id, buffer: []HeirarchyTraverseFrame) void {
            var new_traverser = self.create_heirarchy_traverser_on_stack(buffer);
            defer new_traverser.free();
            self.free_disconnected_items_with_traverser(first_disconected_id, &new_traverser);
        }

        fn add_to_free_action(traverser: *const HeirarchyTraverser, exit_id: Id, exit_kind: TraversalExitKind, userdata: ?*anyopaque) bool {
            _ = exit_kind;
            _ = traverser;
            Internal.push_free_item(traverser.heirarchy, exit_id);
            return true;
        }

        pub inline fn free_disconnected_items_with_traverser(self: *Heirarchy, first_disconected_id: Id, traverser: *HeirarchyTraverser) void {
            traverser.custom_start_traverse_through_heirarchy_depth_first_and_do_actions_on_all_items(first_disconected_id, TraverseActions{
                .action_after_exiting_item = add_to_free_action,
            }, null);
        }

        pub inline fn insert_slot_at_beginning_of_left_children(self: *Heirarchy, parent_id: Id, alloc: AllocInfal) Id {
            self.list.ensure_unused_capacity(1, alloc);
            return self.insert_slot_at_beginning_of_left_children_assume_capacity(parent_id);
        }

        pub fn find_last_sibling(self: *Heirarchy, this_id: Id) Id {
            var curr_id = this_id;
            while (true) {
                const curr_ptr = self.get_ptr(curr_id);
                const next_id = get_next_id(curr_ptr);
                if (next_id == NULL_ID) break;
                curr_id = next_id;
            }
            return curr_id;
        }

        pub fn create_heirarchy_traverser_on_heap(self: *Heirarchy, alloc: AllocInfal) HeirarchyTraverser {
            return HeirarchyTraverser{
                .alloc = alloc,
                .frames = HeirarchyTraverser.FramesList.new_empty(alloc),
                .should_continue = true,
                .heirarchy = self,
            };
        }

        pub fn create_heirarchy_traverser_on_stack(self: *Heirarchy, buffer: []HeirarchyTraverseFrame) HeirarchyTraverser {
            return HeirarchyTraverser{
                .frames = HeirarchyTraverser.FramesList{
                    .assert_alloc = AllocInfal.DummyAllocInfal,
                    .cap = buffer.len,
                    .len = 0,
                    .ptr = buffer.ptr,
                },
                .should_continue = true,
                .heirarchy = self,
            };
        }

        //zig fmt: off
        pub const HeirarchyTraverseFlags = Flags.Flags(enum(u8) {
            BEFORE_LEFT_CHILDREN            = 0b00_0_0_00_00,
            BETWEEN_LEFT_AND_RIGHT_CHILDREN = 0b00_0_0_00_01,
            AFTER_RIGHT_CHILDREN            = 0b00_0_0_00_10,
            IS_FIRST_CHILD                  = 0b00_0_1_00_00,
            IS_LAST_CHILD                   = 0b00_1_0_00_00,
            
        }, enum (u8) {
            PROGRESS      = 0b00_0_0_00_11,
        });
        pub const HeirarchyTraverseProg = enum(u8) {
            BEFORE_LEFT_CHILDREN            = 0b00_0_0_00_00,
            BETWEEN_LEFT_AND_RIGHT_CHILDREN = 0b00_0_0_00_01,
            AFTER_RIGHT_CHILDREN            = 0b00_0_0_00_10,
        };
        // zig fmt: on

        pub const HeirarchyTraverseFrame = struct {
            curr_id: Id = NULL_ID,
            flags: HeirarchyTraverseFlags = HeirarchyTraverseFlags.from_flags(if (HAS_NEXT) &.{ .IS_FIRST_CHILD, .NEXT_BETWEEN_LEFT_AND_RIGHT } else &.{ .IS_FIRST_CHILD, .IS_LAST_CHILD, .NEXT_BETWEEN_LEFT_AND_RIGHT }),

            pub inline fn set_progress_at_least(self: *HeirarchyTraverseFrame, new_prog: HeirarchyTraverseProg) void {
                const prog = self.flags.isolate_group(.PROGRESS);
                const max_prog: HeirarchyTraverseFlags.RawInt = @max(@intFromEnum(prog), @intFromEnum(new_prog));
                self.flags.clear_group_then_set_raw(.PROGRESS, max_prog);
            }

            pub inline fn set_progress(self: *HeirarchyTraverseFrame, new_prog: HeirarchyTraverseProg) void {
                self.flags.clear_group_then_set_raw(.PROGRESS, @intFromEnum(new_prog));
            }
        };

        pub const HeirarchyTraverser = struct {
            frames: FramesList = FramesList.UNINIT,
            heirarchy: *Heirarchy,
            alloc: AllocInfal = AllocInfal.DummyAllocInfal,

            pub const FramesList = Root.List.List(TRACE_LIST_OPTIONS);

            pub inline fn free(self: *HeirarchyTraverser) void {
                self.frames.clear_and_free(self.alloc);
            }

            pub inline fn get_current_id(self: *const HeirarchyTraverser) Id {
                if (self.frames.len == 0) return NULL_ID;
                return self.frames.get_last().curr_id;
            }

            pub inline fn get_current_ptr(self: *const HeirarchyTraverser) *Elem {
                return self.heirarchy.get_ptr(self.get_current_id());
            }

            pub inline fn get_current_progress(self: *const HeirarchyTraverser) HeirarchyTraverseProg {
                const last_flags: HeirarchyTraverseFlags = self.frames.get_last().flags;
                return @enumFromInt(last_flags.isolate_group(.PROGRESS).raw);
            }

            pub inline fn set_current_progress(self: *HeirarchyTraverser, prog: HeirarchyTraverseProg) void {
                const last_frame: *HeirarchyTraverseFrame = self.frames.get_last_ptr();
                last_frame.flags.clear_group_then_set_raw(.PROGRESS, @intFromEnum(prog));
            }

            pub fn clone_to_stack(self: *const HeirarchyTraverser, buffer: []HeirarchyTraverseFrame) HeirarchyTraverser {
                var new = self.heirarchy.create_heirarchy_traverser_on_stack(buffer);
                @memcpy(new.frames.ptr[0..self.frames.len], self.frames.ptr[0..self.frames.len]);
                new.frames.len = self.frames.len;
                return new;
            }

            pub fn clone_to_heap(self: *const HeirarchyTraverser, alloc: AllocInfal) HeirarchyTraverser {
                var new = self.heirarchy.create_heirarchy_traverser_on_heap(alloc);
                @memcpy(new.frames.ptr[0..self.frames.len], self.frames.ptr[0..self.frames.len]);
                new.frames.len = self.frames.len;
                return new;
            }

            pub inline fn goto_next(self: *HeirarchyTraverser) bool {
                if (!HAS_NEXT or self.frames.len == 0) return false;
                const last_frame: *HeirarchyTraverseFrame = self.frames.get_last_ptr();
                const curr_id = last_frame.curr_id;
                const curr_ptr = self.heirarchy.get_ptr(curr_id);
                const next_id = get_next_id(curr_ptr);
                if (next_id == NULL_ID) return false;
                last_frame.curr_id = next_id;
                last_frame.flags.clear_group_then_set(.PROGRESS, .BEFORE_LEFT_CHILDREN);
                last_frame.flags.clear(.IS_FIRST_CHILD);
                const next_next_id = get_next_id(self.heirarchy.get_ptr(next_id));
                if (next_next_id == NULL_ID) last_frame.flags.set(.IS_LAST_CHILD);
                return true;
            }

            pub fn goto_first_left_child(self: *HeirarchyTraverser) bool {
                if (self.frames.len == 0) return false;
                const last_frame: *HeirarchyTraverseFrame = self.frames.get_last_ptr();
                defer last_frame.set_progress(.BETWEEN_LEFT_AND_RIGHT_CHILDREN);
                if (!HAS_LEFT_CHILDREN) return false;
                const curr_id = last_frame.curr_id;
                const curr_ptr = self.heirarchy.get_ptr(curr_id);
                const left_child_id = get_left_child_id(curr_ptr);
                if (left_child_id == NULL_ID) return false;
                self.frames.append(HeirarchyTraverseFrame{ .curr_id = left_child_id });
                const new_last_frame: *HeirarchyTraverseFrame = self.frames.get_last_ptr();
                const next_id = get_next_id(self.heirarchy.get_ptr(left_child_id));
                if (next_id == NULL_ID) new_last_frame.flags.set(.IS_LAST_CHILD);
                return true;
            }

            pub fn goto_first_right_child(self: *HeirarchyTraverser) bool {
                if (self.frames.len == 0) return false;
                var last_frame: *HeirarchyTraverseFrame = self.frames.get_last_ptr();
                defer last_frame.set_progress(.AFTER_RIGHT_CHILDREN);
                if (!HAS_RIGHT_CHILDREN) return false;
                const curr_id = last_frame.curr_id;
                const curr_ptr = self.heirarchy.get_ptr(curr_id);
                const right_child_id = get_right_child_id(curr_ptr);
                if (right_child_id == NULL_ID) return false;
                self.frames.append(HeirarchyTraverseFrame{ .curr_id = right_child_id });
                const new_last_frame: *HeirarchyTraverseFrame = self.frames.get_last_ptr();
                const next_id = get_next_id(self.heirarchy.get_ptr(right_child_id));
                if (next_id == NULL_ID) new_last_frame.flags.set(.IS_LAST_CHILD);
                last_frame = self.frames.ptr[self.frames.len - 2];
                return true;
            }

            pub fn goto_parent(self: *HeirarchyTraverser) bool {
                if (!HAS_LEFT_CHILDREN or !HAS_RIGHT_CHILDREN or self.frames.len == 0) return false;
                const curr_id = self.frames.get_last().curr_id;
                if (curr_id == self.custom_last_id) return false;
                self.frames.set_len(self.frames.len - 1);
                if (self.frames.len == 0) return false;
                return true;
            }

            fn init(self: *HeirarchyTraverser, start_id: Id) void {
                self.frames.clear_retaining_capacity();
                if (start_id == NULL_ID) return;
                self.frames.append(HeirarchyTraverseFrame{ .curr_id = start_id }, self.alloc);
                var last_frame: *HeirarchyTraverseFrame = self.frames.get_last_ptr();
                if (get_next_id(self.heirarchy.get_ptr(last_frame.curr_id)) == NULL_ID) {
                    last_frame.flags.set(.IS_LAST_CHILD);
                }
            }

            pub fn reset_and_traverse_through_heirarchy_depth_first_and_do_actions_on_all_items(self: *HeirarchyTraverser, comptime actions: TraverseActions, userdata: ?*anyopaque) void {
                self.init(self.heirarchy.first_root_id);
                if (self.frames.len == 0) return;
                self.traverse_through_heirarchy_depth_first_and_do_actions_on_items(actions, false, NULL_ID, userdata);
            }

            pub fn reset_and_traverse_through_heirarchy_depth_first_and_do_actions_on_items_before_id(self: *HeirarchyTraverser, stop_before_id: Id, comptime actions: TraverseActions, userdata: ?*anyopaque) void {
                self.init(self.heirarchy.first_root_id);
                if (self.frames.len == 0) return;
                self.traverse_through_heirarchy_depth_first_and_do_actions_on_items(actions, true, stop_before_id, userdata);
            }

            pub fn continue_to_traverse_through_heirarchy_depth_first_and_do_actions_on_all_remaining_items(self: *HeirarchyTraverser, comptime actions: TraverseActions, userdata: ?*anyopaque) void {
                if (self.frames.len == 0) return;
                self.traverse_through_heirarchy_depth_first_and_do_actions_on_items(actions, false, NULL_ID, userdata);
            }

            pub fn continue_to_traverse_through_heirarchy_depth_first_and_do_actions_on_remaining_items_before_id(self: *HeirarchyTraverser, stop_before_id: Id, comptime actions: TraverseActions, userdata: ?*anyopaque) void {
                if (self.frames.len == 0) return;
                self.traverse_through_heirarchy_depth_first_and_do_actions_on_items(actions, true, stop_before_id, userdata);
            }

            pub fn custom_start_traverse_through_heirarchy_depth_first_and_do_actions_on_all_items(self: *HeirarchyTraverser, start_id: Id, comptime actions: TraverseActions, userdata: ?*anyopaque) void {
                self.init(start_id);
                if (self.frames.len == 0) return;
                self.traverse_through_heirarchy_depth_first_and_do_actions_on_items(actions, false, NULL_ID, userdata);
            }

            pub fn custom_start_traverse_through_heirarchy_depth_first_and_do_actions_on_items_before_id(self: *HeirarchyTraverser, start_id: Id, stop_before_id: Id, comptime actions: TraverseActions, userdata: ?*anyopaque) void {
                self.init(start_id);
                if (self.frames.len == 0) return;
                self.traverse_through_heirarchy_depth_first_and_do_actions_on_items(actions, true, stop_before_id, userdata);
            }

            fn traverse_through_heirarchy_depth_first_and_do_actions_on_items(self: *HeirarchyTraverser, comptime actions: TraverseActions, comptime use_stop_id: bool, stop_id: Id, userdata: ?*anyopaque) void {
                loop: while (true) {
                    const last_frame: *HeirarchyTraverseFrame = self.frames.get_last_ptr();
                    if (use_stop_id and last_frame.curr_id == stop_id) break :loop;
                    if (last_frame.flags.has_flag(.BEFORE_LEFT_CHILDREN)) {
                        if (actions.action_before_left_children) |before_action| {
                            if (!before_action(self, userdata)) break :loop;
                        }
                        if (self.goto_first_left_child()) continue :loop;
                    }
                    if (last_frame.flags.has_flag(.BETWEEN_LEFT_AND_RIGHT_CHILDREN)) {
                        if (actions.action_after_left_before_right_children) |middle_action| {
                            if (!middle_action(self, userdata)) break :loop;
                        }
                        if (self.goto_first_right_child()) continue :loop;
                    }
                    if (actions.action_after_right_children) |after_action| {
                        if (!after_action(self.heirarchy, self.frames.slice(), userdata)) break :loop;
                    }
                    if (actions.action_after_exiting_item) |exit_action| {
                        const exit_id = last_frame.curr_id;
                        var exit_kind: TraversalExitKind = .EXITED_BY_HITTING_END_OF_TRAVERSAL;
                        var did_move = false;
                        if (self.goto_next()) {
                            did_move = true;
                            exit_kind = .EXITED_BY_MOVING_TO_NEXT_SIBLING;
                        } else if (self.goto_parent()) {
                            did_move = true;
                            exit_kind == .EXITED_BY_MOVING_TO_PARENT;
                        }
                        if (!exit_action(self, exit_id, exit_kind, userdata)) break :loop;
                        if (did_move) continue :loop;
                    } else {
                        if (self.goto_next()) continue :loop;
                        if (self.goto_parent()) continue :loop;
                    }

                    break :loop;
                }
            }
        };

        pub const TraverseActions = struct {
            action_before_left_children: ?*const fn (traverser: *const HeirarchyTraverser, userdata: ?*anyopaque) bool,
            action_after_left_before_right_children: ?*const fn (traverser: *const HeirarchyTraverser, userdata: ?*anyopaque) bool,
            action_after_right_children: ?*const fn (traverser: *const HeirarchyTraverser, userdata: ?*anyopaque) bool,
            action_after_exiting_item: ?*const fn (traverser: *const HeirarchyTraverser, exited_id: Id, exit_kind: TraversalExitKind, userdata: ?*anyopaque) bool,
        };

        // pub fn traverse_and_do_actions_on_each(self: *Heirarchy) void {}

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

pub const TraversalExitKind = enum(u8) {
    EXITED_BY_MOVING_TO_NEXT_SIBLING,
    EXITED_BY_MOVING_TO_PARENT,
    EXITED_BY_HITTING_END_OF_TRAVERSAL,
};
