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
    ///
    /// This stack holds a record of all of the current node's parents,
    /// (and in the case of iterators each node's 'progress' through its children),
    /// allowing traversal back up through the tree/heriarchy without
    /// caching each node's parent id and/or tree depth on the elements
    /// directly
    ///
    /// If elements include a 'parent' field, 'traversers' will ignore
    /// this and not allocate any memory anywhere,
    traversal_stack_options: Root.List.ListOptionsWithoutElem,
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
    /// The field on the user element type that will hold the 'prev' sibling
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    prev_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'parent'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    parent_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'first child on the left side'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    first_left_child_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'first child on the right side'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    first_right_child_field: ?[]const u8 = null,
    /// The field on the user element type that will hold the element's 'last child on the left side'
    /// in the heirarchy, if any. This should be a field with the same type as `element_id_type`
    last_left_child_field: ?[]const u8 = null,
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
    custom_copy_only_value_fn: ?*const fn (from_elem_ptr: *const anyopaque, to_elem_ptr: *anyopaque) void,
    /// Whether or not the LinkedHeirarchy should cache the last/tail item at the top(root) level.
    cache_last_root_sibling: bool = false,
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

fn assert_field_type_matches_id_type(comptime elem: type, comptime index: type, comptime field: ?[]const u8) usize {
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
    const I = options.element_id_type;
    var linkage_count = assert_field_type_matches_id_type(E, I, options.next_field);
    linkage_count += assert_field_type_matches_id_type(E, I, options.prev_field);
    linkage_count += assert_field_type_matches_id_type(E, I, options.parent_field);
    linkage_count += assert_field_type_matches_id_type(E, I, options.first_left_child_field);
    linkage_count += assert_field_type_matches_id_type(E, I, options.first_right_child_field);
    linkage_count += assert_field_type_matches_id_type(E, I, options.last_left_child_field);
    linkage_count += assert_field_type_matches_id_type(E, I, options.last_right_child_field);
    assert_with_reason(linkage_count > 0, @src(), "LinkedHeirarchy must have at least 1 linkage field", .{});
    const F_IS_NEXT = options.next_field != null;
    const F_IS_FIRST_LEFT = !F_IS_NEXT and options.first_left_child_field != null;
    const F_IS_FIRST_RIGHT = (!F_IS_NEXT and !F_IS_FIRST_LEFT) and options.first_right_child_field != null;
    const F_IS_LAST_LEFT = (!F_IS_NEXT and !F_IS_FIRST_LEFT and !F_IS_FIRST_RIGHT) and options.last_left_child_field != null;
    const F_IS_LAST_RIGHT = (!F_IS_NEXT and !F_IS_FIRST_LEFT and !F_IS_FIRST_RIGHT and !F_IS_LAST_LEFT) and options.last_right_child_field != null;
    const F_IS_PREV = (!F_IS_NEXT and !F_IS_FIRST_LEFT and !F_IS_FIRST_RIGHT and !F_IS_LAST_LEFT and !F_IS_LAST_RIGHT) and options.prev_field != null;
    const F_IS_PARENT = (!F_IS_NEXT and !F_IS_FIRST_LEFT and !F_IS_FIRST_RIGHT and !F_IS_LAST_LEFT and !F_IS_LAST_RIGHT and !F_IS_PREV) and options.parent_field != null;
    const F_LINK = get: {
        if (options.next_field) |F| break :get F;
        if (options.first_left_child_field) |F| break :get F;
        if (options.first_right_child_field) |F| break :get F;
        if (options.last_left_child_field) |F| break :get F;
        if (options.last_right_child_field) |F| break :get F;
        if (options.prev_field) |F| break :get F;
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
        free_count: Id = 0,
        first_root_id: Id = NULL_ID,
        last_root_id: if (HAS_LAST_ROOT) Id else void = if (HAS_LAST_ROOT) NULL_ID else void{},

        const HAS_NEXT = options.next_field != null;
        const NEXT_FIELD = if (HAS_NEXT) options.next_field.? else "";
        const HAS_PREV = options.prev_field != null;
        const PREV_FIELD = if (HAS_PREV) options.prev_field.? else "";
        const HAS_PARENT = options.parent_field != null;
        const PARENT_FIELD = if (HAS_PREV) options.parent_field.? else "";
        const HAS_FIRST_LEFT_CHILD = options.first_left_child_field != null;
        const FIRST_LEFT_CHILD_FIELD = if (HAS_FIRST_LEFT_CHILD) options.first_left_child_field.? else "";
        const HAS_FIRST_RIGHT_CHILD = options.first_right_child_field != null;
        const FIRST_RIGHT_CHILD_FIELD = if (HAS_FIRST_RIGHT_CHILD) options.first_right_child_field.? else "";
        const HAS_LAST_LEFT_CHILD = options.last_left_child_field != null;
        const LAST_LEFT_CHILD_FIELD = if (HAS_LAST_LEFT_CHILD) options.last_left_child_field.? else "";
        const HAS_LAST_RIGHT_CHILD = options.last_right_child_field != null;
        const LAST_RIGHT_CHILD_FIELD = if (HAS_LAST_RIGHT_CHILD) options.last_right_child_field.? else "";
        const HAS_DEPTH = HAS_FIRST_CHILD_NODES or HAS_LAST_CHILD_NODES or HAS_PARENT;
        const HAS_SIBLINGS = HAS_PREV or HAS_NEXT;
        const FREE_FIELD = F_LINK;
        const HAS_OWN_ID = options.own_id_field != null;
        const OWN_ID_FIELD = if (HAS_OWN_ID) options.own_id_field.? else "";
        const HAS_GEN = options.generation_details != null;
        const GEN_OFFSET = if (HAS_GEN) options.generation_details.?.index_bits else 0;
        const IDX_MASK: Id = if (HAS_GEN) (@as(Id, 1) << GEN_OFFSET) - 1 else math.maxInt(Id);
        const IDX_CLEAR: Id = if (HAS_GEN) ~IDX_MASK else 0;
        const GEN_MASK: Id = if (HAS_GEN) ~IDX_MASK else 0;
        const GEN_CLEAR: Id = if (HAS_GEN) IDX_MASK else 0;
        const FREE_IS_NEXT = F_IS_NEXT;
        const FREE_IS_FIRST_LEFT = F_IS_FIRST_LEFT;
        const FREE_IS_FIRST_RIGHT = F_IS_FIRST_RIGHT;
        const FREE_IS_LAST_LEFT = F_IS_LAST_LEFT;
        const FREE_IS_LAST_RIGHT = F_IS_LAST_RIGHT;
        const FREE_IS_PREV = F_IS_PREV;
        const FREE_IS_PARENT = F_IS_PARENT;
        const HAS_LAST_ROOT = options.cache_last_root_sibling;
        const STRONG_ASSERTS = options.strong_asserts;
        const HAS_MAX_DEPTH = options.traverse_with_stack_memory_and_max_depth != null;
        const MAX_DEPTH = if (HAS_MAX_DEPTH) options.traverse_with_stack_memory_and_max_depth.? else 0;
        const UNINIT = Heirarchy{};
        const UNINIT_ELEM: Elem = make: {
            var elem: Elem = undefined;
            if (options.element_memory_options.memset_uninit_val) |uninit_val| {
                const uninit_elem: *const Elem = @ptrCast(@alignCast(uninit_val));
                elem = uninit_elem.*;
            }
            Internal.set_own_id(&elem, NULL_ID);
            Internal.set_next_id(&elem, NULL_ID);
            Internal.set_prev_id(&elem, NULL_ID);
            Internal.set_parent_id(&elem, NULL_ID);
            Internal.set_first_left_child_id(&elem, NULL_ID);
            Internal.set_last_left_child_id(&elem, NULL_ID);
            Internal.set_first_right_child_id(&elem, NULL_ID);
            Internal.set_last_right_child_id(&elem, NULL_ID);
            break :make elem;
        };
        const NULL_ID = math.maxInt(Id);
        const NULL_INDEX = math.maxInt(Index);
        const NULL_GEN = if (HAS_GEN) (NULL_ID & ~IDX_MASK) else 0;
        const GEN_ONE: Id = if (HAS_GEN) @as(Id, 1) << GEN_OFFSET else 1;
        const HAS_ONLY_ONE_CHILD_SIDE = (HAS_FIRST_LEFT_CHILD and !HAS_FIRST_RIGHT_CHILD) or (HAS_FIRST_RIGHT_CHILD and !HAS_FIRST_LEFT_CHILD);
        const HAS_FIRST_CHILD_NODES = HAS_FIRST_LEFT_CHILD or HAS_FIRST_RIGHT_CHILD;
        const HAS_LAST_CHILD_NODES = HAS_LAST_LEFT_CHILD or HAS_LAST_RIGHT_CHILD;
        const COPY_VAL_FN = options.custom_copy_only_value_fn;
        const UNINIT_ITER_FRAME = IteratorFrame{};
        const UNINIT_TRAV_FRAME = TraverserFrame{};
        const ITER_STACK_OPTIONS = Root.List.ListOptions.from_options_without_elem(options.traversal_stack_options, IteratorFrame, @ptrCast(&UNINIT_ITER_FRAME));
        const TRAV_STACK_OPTIONS = Root.List.ListOptions.from_options_without_elem(options.traversal_stack_options, TraverserFrame, @ptrCast(&UNINIT_TRAV_FRAME));

        const Heirarchy = @This();
        pub const List = Root.List.List(options.element_memory_options);
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
                assert_with_reason(same_gen(id, own_id), @src(), "generation on id requested (index {d}, gen {d}) did not match the generation stored on element {d}", .{get_index(id), get_gen(id), get_gen(own_id)});
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
            Internal.assert_has_next(@src());
            if (!HAS_NEXT) return NULL_ID;
            return @field(ptr, NEXT_FIELD);
        }
        pub inline fn get_prev_id(ptr: *const Elem) Id {
            Internal.assert_has_prev(@src());
            if (!HAS_PREV) return NULL_ID;
            return @field(ptr, HAS_PREV);
        }
        pub inline fn get_parent_id(ptr: *const Elem) Id {
            Internal.assert_has_parent(@src());
            if (!HAS_PARENT) return NULL_ID;
            return @field(ptr, HAS_PARENT);
        }
        pub inline fn get_first_left_child_id(ptr: *const Elem) Id {
            Internal.assert_has_first_left(@src());
            if (!HAS_FIRST_LEFT_CHILD) return NULL_ID;
            return @field(ptr, FIRST_LEFT_CHILD_FIELD);
        }
        pub inline fn get_first_right_child_id(ptr: *const Elem) Id {
            Internal.assert_has_first_right(@src());
            if (!HAS_FIRST_RIGHT_CHILD) return NULL_ID;
            return @field(ptr, FIRST_RIGHT_CHILD_FIELD);
        }
        pub inline fn get_last_left_child_id(ptr: *const Elem) Id {
            Internal.assert_has_last_left(@src());
            if (!HAS_LAST_LEFT_CHILD) return NULL_ID;
            return @field(ptr, LAST_LEFT_CHILD_FIELD);
        }
        pub inline fn get_last_right_child_id(ptr: *const Elem) Id {
            Internal.assert_has_last_right(@src());
            if (!HAS_LAST_LEFT_CHILD) return NULL_ID;
            return @field(ptr, LAST_RIGHT_CHILD_FIELD);
        }

        /// All functions/structs in this namespace fall in at least one of 3 categories:
        /// - DANGEROUS to use if you do not manually manage and maintain a valid linked state
        /// - Are only useful for asserting/creating intenal state
        /// - Cover VERY niche use cases (used internally) and are placed here to keep the top-level namespace less polluted
        ///
        /// They are provided here publicly to facilitate opt-in special user use cases
        pub const Internal = struct {
            pub inline fn get_ptr_ignore_gen(self: *Heirarchy, id: Id) *Elem {
                const idx = get_index(id);
                assert_idx_less_than_len(idx, self.list.len, @src());
                const ptr = &self.list.ptr[idx];
                return ptr;
            }
            pub inline fn get_ptr_const_ignore_gen(self: *const Heirarchy, id: Id) *const Elem {
                const idx = get_index(id);
                assert_idx_less_than_len(idx, self.list.len, @src());
                const ptr = &self.list.ptr[idx];
                return ptr;
            }
            pub inline fn set_next_id(ptr: *Elem, val: Id) void {
                if (!HAS_NEXT) return;
                const field_ptr: *Id = &@field(ptr, NEXT_FIELD);
                field_ptr.* = val;
            }
            pub inline fn set_prev_id(ptr: *Elem, val: Id) void {
                if (!PREV_FIELD) return;
                const field_ptr: *Id = &@field(ptr, PREV_FIELD);
                field_ptr.* = val;
            }
            pub inline fn set_parent_id(ptr: *Elem, val: Id) void {
                if (!PARENT_FIELD) return;
                const field_ptr: *Id = &@field(ptr, PARENT_FIELD);
                field_ptr.* = val;
            }
            pub inline fn set_first_left_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_FIRST_LEFT_CHILD) return;
                const field_ptr: *Id = &@field(ptr, FIRST_LEFT_CHILD_FIELD);
                field_ptr.* = val;
            }
            pub inline fn set_first_right_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_FIRST_RIGHT_CHILD) return;
                const field_ptr: *Id = &@field(ptr, FIRST_RIGHT_CHILD_FIELD);
                field_ptr.* = val;
            }
            pub inline fn set_last_left_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_LAST_LEFT_CHILD) return;
                const field_ptr: *Id = &@field(ptr, LAST_LEFT_CHILD_FIELD);
                field_ptr.* = val;
            }
            pub inline fn set_last_right_child_id(ptr: *Elem, val: Id) void {
                if (!HAS_LAST_RIGHT_CHILD) return;
                const field_ptr: *Id = &@field(ptr, LAST_RIGHT_CHILD_FIELD);
                field_ptr.* = val;
            }
            pub inline fn set_own_id(ptr: *Elem, val: Id) void {
                if (!HAS_OWN_ID) return;
                const field_ptr: *Id = &@field(ptr, OWN_ID_FIELD);
                field_ptr.* = val;
            }
            pub inline fn increment_gen(ptr: *Elem) void {
                if (!HAS_GEN) return;
                const field_ptr: *Id = &@field(ptr, OWN_ID_FIELD);
                field_ptr.* += GEN_ONE;
                if (field_ptr.* & GEN_MASK == GEN_MASK) field_ptr.* &= GEN_CLEAR;
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
                    if (HAS_PREV) {
                        set_prev_id(a, get_prev_id(old_a));
                        set_prev_id(b, get_prev_id(old_b));
                    }
                    if (HAS_PARENT) {
                        set_parent_id(a, get_parent_id(old_a));
                        set_parent_id(b, get_parent_id(old_b));
                    }
                    if (HAS_FIRST_LEFT_CHILD) {
                        set_first_left_child_id(a, get_first_left_child_id(old_a));
                        set_first_left_child_id(b, get_first_left_child_id(old_b));
                    }
                    if (HAS_FIRST_RIGHT_CHILD) {
                        set_first_right_child_id(a, get_first_right_child_id(old_a));
                        set_first_right_child_id(b, get_first_right_child_id(old_b));
                    }
                    if (HAS_LAST_LEFT_CHILD) {
                        set_last_left_child_id(a, get_last_left_child_id(old_a));
                        set_last_left_child_id(b, get_last_left_child_id(old_b));
                    }
                    if (HAS_LAST_RIGHT_CHILD) {
                        set_last_right_child_id(a, get_last_right_child_id(old_a));
                        set_last_right_child_id(b, get_last_right_child_id(old_b));
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
                assert_has_next(@src());
                const first_id: Id = @intCast(self.list.len);
                const last_id: Id = first_id + @as(Id, @intCast(count - 1));
                var this_id: Id = first_id;
                _ = self.list.append_n_times_assume_capacity(UNINIT_ELEM, count);
                while (this_id < last_id) {
                    const this_ptr = Internal.get_ptr_ignore_gen(self, this_id);
                    set_own_id(this_ptr, this_id);
                    this_id += 1;
                    set_next_id(this_ptr, this_id);
                }
                const this_ptr = Internal.get_ptr_ignore_gen(self, this_id);
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
                const free_ptr = &@field(ptr, FREE_FIELD);
                const next_free = free_ptr.*;
                free_ptr.* = NULL_ID;
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
                    if (!FREE_IS_FIRST_LEFT) set_first_left_child_id(ptr, NULL_ID);
                    if (!FREE_IS_FIRST_RIGHT) set_first_right_child_id(ptr, NULL_ID);
                    if (!FREE_IS_NEXT) set_next_id(ptr, NULL_ID);
                }
                const free_ptr = &@field(ptr, FREE_FIELD);
                free_ptr.* = self.first_free_id;
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

            pub fn insert_new_ids_as_siblings(self: *Heirarchy, leftmost: Id, first_new: Id, last_new: Id, rightmost: Id) void {
                assert_with_reason(first_new != NULL_ID and last_new != NULL_ID, @src(), "cannot insert NULL_ID's between items", .{});
                if (leftmost == NULL_ID and rightmost == NULL_ID) {
                    assert_with_reason(self.first_root_id == NULL_ID, @src(), "an attempt to insert new id's between 2 NULL_ID's implies inserting to an empty root, but root wasn't empty", .{});
                    if (HAS_LAST_ROOT) assert_with_reason(self.last_root_id == NULL_ID, @src(), "an attempt to insert new id's between 2 NULL_ID's implies inserting to an empty root, but root wasn't empty", .{});
                    self.first_root_id = first_new;
                    if (HAS_LAST_ROOT) {
                        self.last_root_id = last_new;
                    }
                    return;
                }
                if (HAS_NEXT) {
                    const last_new_ptr = self.get_ptr(last_new);
                    Internal.set_next_id(last_new_ptr, rightmost);
                    if (leftmost != NULL_ID) {
                        const left_ptr = self.get_ptr(leftmost);
                        Internal.set_next_id(left_ptr, first_new);
                    } else {
                        if (!HAS_PARENT) {
                            assert_with_reason(self.first_root_id == rightmost, @src(), "an attempt to insert new id's after a NULL_ID as the leftmost id (and no parent) implies inserting to the beginning of the root level, but the previous 'first root id' didn't match the provided rightmost id", .{});
                            self.first_root_id = first_new;
                        } else {
                            const parent_id = self.get_parent_id(self.get_ptr(rightmost));
                            if (parent_id == NULL_ID) {
                                assert_with_reason(self.first_root_id == rightmost, @src(), "an attempt to insert new id's after a NULL_ID as the leftmost id (and no parent) implies inserting to the beginning of the root level, but the previous 'first root id' didn't match the provided rightmost id", .{});
                                self.first_root_id = first_new;
                            } else if (HAS_FIRST_CHILD_NODES) {
                                const parent_ptr = self.get_ptr(parent_id);
                                const found: usize = 0;
                                if (HAS_FIRST_LEFT_CHILD) {
                                    const old_first_left = self.get_first_left_child_id(parent_ptr);
                                    if (old_first_left == rightmost) {
                                        Internal.set_first_left_child_id(parent_ptr, first_new);
                                        found += 1;
                                    }
                                }
                                if (HAS_FIRST_RIGHT_CHILD) {
                                    const old_first_right = self.get_first_right_child_id(parent_ptr);
                                    if (old_first_right == rightmost) {
                                        Internal.set_first_right_child_id(parent_ptr, first_new);
                                        found += 1;
                                    }
                                }
                                assert_with_reason(found != 2, @src(), "found id (index {d}, gen {d}) on both the first-left-child and first-right-child connections simultaneously, tree is broken", .{get_index(rightmost), get_gen(rightmost)});
                                assert_with_reason(found != 0, @src(), "did not find id (index {d}, gen {d}) on either the first-left-child or first-right-child connections, but it was the first sibling (has parent, no prev id), tree is broken", .{get_index(rightmost), get_gen(rightmost)});
                            }
                        }
                    }
                }
                if (HAS_PREV) {
                    const first_new_ptr = self.get_ptr(first_new);
                    Internal.set_prev_id(first_new_ptr, leftmost);
                    if (rightmost != NULL_ID) {
                        const right_ptr = self.get_ptr(rightmost);
                        Internal.set_prev_id(right_ptr, last_new);
                    } else {
                        if (!HAS_PARENT) {
                            if (HAS_LAST_ROOT) {
                                assert_with_reason(self.last_root_id == leftmost, @src(), "an attempt to insert new id's before a NULL_ID as the rightmost id (and no parent) implies inserting to the end of the root level, but the previous 'lest root id' didn't match the provided leftmost id", .{});
                                self.last_root_id = last_new;
                            }
                        } else {
                            const parent_id = self.get_parent_id(self.get_ptr(leftmost));
                            if (parent_id == NULL_ID) {
                                if (HAS_LAST_ROOT) {
                                    assert_with_reason(self.last_root_id == leftmost, @src(), "an attempt to insert new id's before a NULL_ID as the rightmost id (and no parent) implies inserting to the end of the root level, but the previous 'lest root id' didn't match the provided leftmost id", .{});
                                    self.last_root_id = last_new;
                                }
                            } else if (HAS_LAST_CHILD_NODES) {
                                const parent_ptr = self.get_ptr(parent_id);
                                const found: usize = 0;
                                if (HAS_LAST_LEFT_CHILD) {
                                    const old_last_left = self.get_last_left_child_id(parent_ptr);
                                    if (old_last_left == leftmost) {
                                        Internal.set_last_left_child_id(parent_ptr, last_new);
                                        found += 1;
                                    }
                                }
                                if (HAS_LAST_RIGHT_CHILD) {
                                    const old_last_right = self.get_last_right_child_id(parent_ptr);
                                    if (old_last_right == leftmost) {
                                        Internal.set_last_right_child_id(parent_ptr, last_new);
                                        found += 1;
                                    }
                                }
                                assert_with_reason(found != 2, @src(), "found id (index {d}, gen {d}) on both the last-left-child and lasr-right-child connections simultaneously, tree is broken", .{get_index(leftmost), get_gen(leftmost)});
                                assert_with_reason(found != 0, @src(), "did not find id (index {d}, gen {d}) on either the last-left-child or last-right-child connections, but it was the last sibling (has parent, no next id), tree is broken", .{get_index(leftmost), get_gen(leftmost)});
                            }
                        }
                    }
                }
                if (HAS_PARENT and (HAS_NEXT or HAS_PREV)) {
                    const parent_id = if (leftmost != NULL_ID) self.get_parent_id(self.get_ptr(leftmost)) else self.get_parent_id(self.get_ptr(rightmost));
                    Internal.set_parent_on_range(self, parent_id, leftmost, first_new, last_new, rightmost);
                }
            }

            pub fn set_parent_on_range(self: *Heirarchy, parent_id: Id, left_limit: Id, first_new: Id, last_new: Id, right_limit: Id) void {
                if (HAS_NEXT) {
                    var id = first_new;
                    while (id != right_limit) {
                        const ptr = self.get_ptr(id);
                        Internal.set_parent_id(ptr, parent_id);
                        id = self.get_next_id(ptr);
                    }
                } else if (HAS_PREV) {
                    var id = last_new;
                    while (id != left_limit) {
                        const ptr = self.get_ptr(id);
                        Internal.set_parent_id(ptr, parent_id);
                        id = self.get_prev_id(ptr);
                    }
                }
            }

            pub fn remove_id_range(self: *Heirarchy, leftmost: Id, first_removed_id: Id, last_removed_id: Id, rightmost: Id, known_parent_id: ?Id) void {
                assert_with_reason(first_removed_id != NULL_ID and last_removed_id != NULL_ID, @src(), "cannot remove NULL_ID's between items", .{});
                Internal.assert_range_and_ends_adjacent_siblings(self, leftmost, first_removed_id, last_removed_id, rightmost, @src());
                const branch = Utils.bools_to_switchable_integer(2, .{leftmost != NULL_ID, rightmost != NULL_ID});
                const parent_id = get: {
                    if (HAS_PARENT) {
                        const parent = self.get_parent_id(self.get_ptr(first_removed_id));
                        if (known_parent_id) |k_parent| {
                            assert_with_reason(parent == k_parent, @src(), "cached parent on 'first removed id' (idx = {d}) did not match the provided 'known parent id' (idx = {d})", .{get_index(parent), get_index(k_parent)});
                        }
                        break :get parent;
                    } else if (HAS_DEPTH) {
                        assert_with_reason(known_parent_id != null, @src(), "if heirarchy has depth (parents and children) but items do not cache their parent id on them, a known parent id must be provided", .{});
                        break :get known_parent_id.?;
                    } else break :get NULL_ID;
                };
                switch (branch) {
                    0 => {// left and right == NULL_ID
                        if (HAS_DEPTH) {
                            Internal.assert_has_parent(@src());
                            if (parent_id == NULL_ID) {
                                self.first_root_id = NULL_ID;
                                if (HAS_LAST_ROOT) self.last_root_id = NULL_ID;
                            } else {
                                const parent_ptr = self.get_ptr(parent_id);
                                var found: usize = 0;
                                if (HAS_FIRST_LEFT_CHILD) {
                                    const cached_first_left = self.get_first_left_child_id(parent_ptr);
                                    if (cached_first_left == first_removed_id) {
                                        Internal.set_first_left_child_id(parent_ptr, NULL_ID);
                                        Internal.set_last_left_child_id(parent_ptr, NULL_ID);
                                        found += 1;
                                    }
                                } else if (HAS_LAST_LEFT_CHILD) {
                                    const cached_last_left = self.get_last_left_child_id(parent_ptr);
                                    if (cached_last_left == last_removed_id) {
                                        Internal.set_first_left_child_id(parent_ptr, NULL_ID);
                                        Internal.set_last_left_child_id(parent_ptr, NULL_ID);
                                        found += 1;
                                    }
                                }
                                if (HAS_FIRST_RIGHT_CHILD) {
                                    const cached_first_right = self.get_first_right_child_id(parent_ptr);
                                    if (cached_first_right == first_removed_id) {
                                        Internal.set_first_right_child_id(parent_ptr, NULL_ID);
                                        Internal.set_last_right_child_id(parent_ptr, NULL_ID);
                                        found += 1;
                                    }
                                } else if (HAS_LAST_RIGHT_CHILD) {
                                    const cached_last_right = self.get_last_right_child_id(parent_ptr);
                                    if (cached_last_right == last_removed_id) {
                                        Internal.set_first_right_child_id(parent_ptr, NULL_ID);
                                        Internal.set_last_right_child_id(parent_ptr, NULL_ID);
                                        found += 1;
                                    }
                                }
                                assert_with_reason(found > 0, @src(), "did not find first or last item in range on parent (idx = {d}) connections", .{get_index(parent_id)});
                            }
                        } else {
                            self.first_root_id = NULL_ID;
                            if (HAS_LAST_ROOT) self.last_root_id = NULL_ID;
                        }
                    },
                    1 => {// left valid, right == NULL_ID
                        if (HAS_NEXT) {
                            const left_ptr = self.get_ptr(leftmost);
                            Internal.set_next_id(left_ptr, rightmost);
                        }
                        if (HAS_PREV) {
                            const first_ptr = self.get_ptr(first_removed_id);
                            Internal.set_prev_id(first_ptr, NULL_ID);
                        }
                        if (HAS_DEPTH) {
                            Internal.assert_has_parent(@src());
                            if (parent_id == NULL_ID) {
                                if (HAS_LAST_ROOT) self.last_root_id = NULL_ID;
                            } else {
                                const parent_ptr = self.get_ptr(parent_id);
                                var found: usize = 0;
                                if (HAS_FIRST_RIGHT_CHILD) {
                                    const cached_first_right = self.get_first_right_child_id(parent_ptr);
                                    if (cached_first_right == first_removed_id) {
                                        Internal.set_first_right_child_id(parent_ptr, NULL_ID);
                                        Internal.set_last_right_child_id(parent_ptr, NULL_ID);
                                        found += 1;
                                    }
                                } else if (HAS_LAST_RIGHT_CHILD) {
                                    const cached_last_right = self.get_last_right_child_id(parent_ptr);
                                    if (cached_last_right == last_removed_id) {
                                        Internal.set_first_right_child_id(parent_ptr, NULL_ID);
                                        Internal.set_last_right_child_id(parent_ptr, NULL_ID);
                                        found += 1;
                                    }
                                }
                                assert_with_reason(found > 0, @src(), "did not find first or last item in range on parent (idx = {d}) connections", .{get_index(parent_id)});
                            }
                        } else {
                            if (HAS_LAST_ROOT) self.last_root_id = NULL_ID;
                        }
                    },
                    2 => {// right valid, left == NULL_ID
                    if (HAS_DEPTH) {
                            Internal.assert_has_parent(@src());
                            if (parent_id == NULL_ID) {
                                self.first_root_id = NULL_ID;
                            } else {
                                const parent_ptr = self.get_ptr(parent_id);
                                var found: usize = 0;
                                if (HAS_FIRST_LEFT_CHILD) {
                                    const cached_first_left = self.get_first_left_child_id(parent_ptr);
                                    if (cached_first_left == first_removed_id) {
                                        Internal.set_first_left_child_id(parent_ptr, NULL_ID);
                                        Internal.set_last_left_child_id(parent_ptr, NULL_ID);
                                        found += 1;
                                    }
                                } else if (HAS_LAST_LEFT_CHILD) {
                                    const cached_last_left = self.get_last_left_child_id(parent_ptr);
                                    if (cached_last_left == last_removed_id) {
                                        Internal.set_first_left_child_id(parent_ptr, NULL_ID);
                                        Internal.set_last_left_child_id(parent_ptr, NULL_ID);
                                        found += 1;
                                    }
                                }
                                assert_with_reason(found > 0, @src(), "did not find first or last item in range on parent (idx = {d}) connections", .{get_index(parent_id)});
                            }
                        } else {
                            self.first_root_id = NULL_ID;
                        }
                        if (HAS_NEXT) {
                            const last_ptr = self.get_ptr(last_removed_id);
                            Internal.set_next_id(last_ptr, NULL_ID);
                        }
                        if (HAS_PREV) {
                            const right_ptr = self.get_ptr(rightmost);
                            Internal.set_prev_id(right_ptr, last_removed_id);
                        }
                    },
                    3 => {// laft and right valid
                        if (HAS_NEXT) {
                            const left_ptr = self.get_ptr(leftmost);
                            Internal.set_next_id(left_ptr, rightmost);
                            const last_ptr = self.get_ptr(last_removed_id);
                            Internal.set_next_id(last_ptr, NULL_ID);
                        }
                        if (HAS_PREV) {
                            const first_ptr = self.get_ptr(first_removed_id);
                            Internal.set_prev_id(first_ptr, NULL_ID);
                            const right_ptr = self.get_ptr(rightmost);
                            Internal.set_prev_id(right_ptr, last_removed_id);
                        }
                    },
                    else => unreachable,
                }
                if (HAS_PARENT) {
                    Internal.set_parent_on_range(self, NULL_ID, NULL_ID, first_removed_id, last_removed_id, NULL_ID);
                }
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

            pub fn assert_real_next_cached_next_match(self: *Heirarchy, this_id: Id, real_next: Id, comptime src_loc: ?SourceLocation) void {
                const cached_next = get_next_id(self.get_ptr(this_id));
                assert_with_reason(real_next == cached_next, src_loc, "real next id (gen = {d}, idx = {d}) does not match the cached next id (gen = {d}, idx = {d}) on the prev sibling (gen = {d}, idx = {d})", .{ get_gen_index(real_next).gen, get_index(real_next), get_gen_index(cached_next).gen, get_index(cached_next), get_gen_index(this_id).gen, get_index(this_id) });
            }

            pub fn assert_has_next(comptime src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_NEXT, src_loc, "cannot connect element as next sibling when elements do not have a 'next' field", .{});
            }

            pub fn assert_has_prev(comptime src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_PREV, src_loc, "cannot connect element as next sibling when elements do not have a 'prev' field", .{});
            }

            pub fn assert_has_parent(comptime src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_PARENT, src_loc, "cannot connect element as parent when elements do not have a 'parent' field", .{});
            }

            pub fn assert_has_first_left(comptime src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_FIRST_LEFT_CHILD, src_loc, "cannot connect element as first left child when elements do not have a 'first left child' field", .{});
            }

            pub fn assert_has_first_right(comptime src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_FIRST_RIGHT_CHILD, src_loc, "cannot connect element as first right child when elements do not have a 'first right child' field", .{});
            }

            pub fn assert_has_last_left(comptime src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_LAST_LEFT_CHILD, src_loc, "cannot connect element as last left child when elements do not have a 'last left child' field", .{});
            }

            pub fn assert_has_last_right(comptime src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_LAST_RIGHT_CHILD, src_loc, "cannot connect element as last right child when elements do not have a 'last right child' field", .{});
            }

            pub fn assert_has_root_last(comptime src_loc: ?SourceLocation) void {
                assert_with_reason(HAS_LAST_ROOT, src_loc, "cannot access 'last root sibling' because the Heirarchy does not cache it", .{});
            }

            pub fn assert_range_and_ends_adjacent_siblings(self: *Heirarchy, leftmost: Id, range_first: Id, range_last: Id, rightmost: Id, comptime src_loc: ?SourceLocation) void {
                if (HAS_NEXT) {
                    const right_cached = self.get_next_id(self.get_ptr(range_last));
                    assert_with_reason(right_cached == rightmost, src_loc, "last item in range (idx = {d}) did not point to rightmost item (idx = {d})", .{get_index(range_last), get_index(rightmost)});
                    if (leftmost != NULL_ID) {
                        const first_cached = self.get_next_id(self.get_ptr(leftmost));
                        assert_with_reason(first_cached == range_first, src_loc, "leftmost item (idx = {d}) did not point to first item in range (idx = {d})", .{get_index(leftmost), get_index(range_first)});
                    }
                }
                if (HAS_PREV) {
                    const left_cached = self.get_prev_id(self.get_ptr(range_first));
                    assert_with_reason(left_cached == leftmost, src_loc, "first item in range (idx = {d}) did not point to leftmost item (idx = {d})", .{get_index(range_first), get_index(leftmost)});
                    if (rightmost != NULL_ID) {
                        const last_cached = self.get_prev_id(self.get_ptr(rightmost));
                        assert_with_reason(last_cached == range_last, src_loc, "rightmost item (idx = {d}) did not point to last item in range (idx = {d})", .{get_index(rightmost), get_index(range_last)});
                    }
                }
            }

            pub fn assert_disconnect_range_is_isolated(self: *Heirarchy, range: Range, comptime src_loc: ?SourceLocation) void {
                if (HAS_NEXT) assert_with_reason(get_next_id(self.get_ptr(range.last)) == NULL_ID, src_loc, "last disconnected item (index {d}) did not have a 'next' field that pointed to NULL_ID, it wasnt fully disconnected", .{get_index(range.last)});
                if (HAS_PREV) assert_with_reason(get_prev_id(self.get_ptr(range.first)) == NULL_ID, src_loc, "first disconnected item (index {d}) did not have a 'prev' field that pointed to NULL_ID, it wasnt fully disconnected", .{get_index(range.first)});
            }

            pub fn assert_2_siblings_in_order_no_cycles(self: *Heirarchy, a: Id, b: Id, comptime a_b_can_equal: bool, comptime b_can_be_null: bool, comptime src_loc: ?SourceLocation) void {
                assert_idx_less_than_len(get_index(a), self.list.len, src_loc);
                assert_idx_less_than_len(get_index(b), self.list.len, src_loc);
                assert_with_reason(a != NULL_ID, src_loc, "id 'a' was NULL_ID", .{});
                if (!b_can_be_null) assert_with_reason(b != NULL_ID, src_loc, "id 'b' was NULL_ID", .{});
                if (a_b_can_equal and get_index(a) == get_index(b)) {
                    assert_with_reason(same_gen(a, b), src_loc, "same indexes {d} had mismatched generations {d}, {d}", .{ get_index(a), get_gen(a), get_gen(b) });
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

            pub fn assert_4_siblings_in_order_no_cycles_b_c_can_be_same_d_can_be_null(self: *Heirarchy, a: Id, b: Id, c: Id, d: Id, comptime src_loc: ?SourceLocation) void {
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
                    var fast_ptr: *Elem = undefined;
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

        pub fn insert_slot_after(self: *Heirarchy, this_id: Id, alloc_else_assume_cap: ?AllocInfal) Id {
            Internal.assert_has_next(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(1, alloc);
            }
            const new_id = Internal.initialize_new_index(self);
            const right_id = get_next_id(self.get_ptr(this_id));
            Internal.insert_new_ids_as_siblings(self, this_id, new_id, new_id, right_id);
            return new_id;
        }

        pub fn insert_many_slots_after(self: *Heirarchy, this_id: Id, count: Index, alloc_else_assume_cap: ?AllocInfal) Range {
            Internal.assert_has_next(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(count, alloc);
            }
            const range = Internal.initialize_items_as_siblings(self, count);
            const right_id = get_next_id(self.get_ptr(this_id));
            Internal.insert_new_ids_as_siblings(self, this_id, range.first, range.last, right_id);
            return range;
        }

        pub fn insert_disconnected_items_after(self: *Heirarchy, this_id: Id, disconnected_items: Range) void {
            Internal.assert_has_next(@src());
            Internal.assert_disconnect_range_is_isolated(self, disconnected_items, @src());
            const right_id = get_next_id(self.get_ptr(this_id));
            Internal.insert_new_ids_as_siblings(self, this_id, disconnected_items.first, disconnected_items.last, right_id);
        }

        pub fn insert_slot_before(self: *Heirarchy, this_id: Id, alloc_else_assume_cap: ?AllocInfal) Id {
            Internal.assert_has_prev(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(1, alloc);
            }
            const new_id = Internal.initialize_new_index(self);
            const left_id = get_prev_id(self.get_ptr(this_id));
            Internal.insert_new_ids_as_siblings(self, left_id, new_id, new_id, this_id);
            return new_id;
        }

        pub fn insert_many_slots_before(self: *Heirarchy, this_id: Id, count: Index, alloc_else_assume_cap: ?AllocInfal) Range {
            Internal.assert_has_prev(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(count, alloc);
            }
            const range = Internal.initialize_items_as_siblings(self, count);
            const left_id = get_prev_id(self.get_ptr(this_id));
            Internal.insert_new_ids_as_siblings(self, left_id, range.first, range.last, this_id);
            return range;
        }

        pub fn insert_disconnected_items_before(self: *Heirarchy, this_id: Id, disconnected_items: Range) void {
            Internal.assert_has_prev(@src());
            Internal.assert_disconnect_range_is_isolated(self, disconnected_items, @src());
            const left_id = get_prev_id(self.get_ptr(this_id));
            Internal.insert_new_ids_as_siblings(self, left_id, disconnected_items.first, disconnected_items.last, this_id);
        }

        pub fn insert_slot_at_beginning_of_left_children(self: *Heirarchy, parent_id: Id, alloc_else_assume_cap: ?AllocInfal) Id {
            Internal.assert_has_first_left(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(1, alloc);
            }
            const new_id = Internal.initialize_new_index(self);
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_left = get_first_left_child_id(parent_ptr);
            const new_ptr = self.get_ptr(new_id);
            Internal.set_next_id(new_ptr, old_first_left);
            Internal.set_first_left_child_id(parent_ptr, new_id);
            if (HAS_PARENT) {
                Internal.set_parent_id(new_ptr, parent_id);
            }
            return new_id;
        }

        pub fn insert_many_slots_at_beginning_of_left_children(self: *Heirarchy, parent_id: Id, count: Index, alloc_else_assume_cap: ?AllocInfal) Range {
            Internal.assert_has_first_left(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(count, alloc);
            }
            const range = Internal.initialize_new_indexes_as_siblings(self, count);
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_left = get_first_left_child_id(parent_ptr);
            const new_last_ptr = self.get_ptr(range.last);
            Internal.set_next_id(new_last_ptr, old_first_left);
            Internal.set_first_left_child_id(parent_ptr, range.first);
            if (HAS_PARENT) {
                Internal.set_parent_on_range(self, parent_id, NULL_ID, range.first, range.last, old_first_left);
            }
            return range;
        }

        pub fn insert_disconnected_items_at_beginning_of_left_children(self: *Heirarchy, parent_id: Id, disconnected_items: Range) void {
            Internal.assert_has_first_left(@src());
            Internal.assert_disconnect_range_is_isolated(self, disconnected_items, @src());
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_left = get_first_left_child_id(parent_ptr);
            const last_disconn_ptr = self.get_ptr(disconnected_items.last);
            Internal.set_next_id(last_disconn_ptr, old_first_left);
            Internal.set_first_left_child_id(parent_ptr, disconnected_items.first);
            if (HAS_PARENT) {
                Internal.set_parent_on_range(self, parent_id, NULL_ID, disconnected_items.first, disconnected_items.last, old_first_left);
            }
        }

        pub fn insert_slot_at_beginning_of_right_children(self: *Heirarchy, parent_id: Id, alloc_else_assume_cap: ?AllocInfal) Id {
            Internal.assert_has_first_right(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(1, alloc);
            }
            const new_id = Internal.initialize_new_index(self);
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_right = get_first_right_child_id(parent_ptr);
            const new_ptr = self.get_ptr(new_id);
            Internal.set_next_id(new_ptr, old_first_right);
            Internal.set_first_right_child_id(parent_ptr, new_id);
            if (HAS_PARENT) {
                Internal.set_parent_id(new_ptr, parent_id);
            }
            return new_id;
        }

        pub fn insert_many_slots_at_beginning_of_right_children(self: *Heirarchy, parent_id: Id, count: Index, alloc_else_assume_cap: ?AllocInfal) Range {
            Internal.assert_has_first_right(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(count, alloc);
            }
            const range = Internal.initialize_new_indexes_as_siblings(self, count);
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_right = get_first_right_child_id(parent_ptr);
            const new_last_ptr = self.get_ptr(range.last);
            Internal.set_next_id(new_last_ptr, old_first_right);
            Internal.set_first_right_child_id(parent_ptr, range.first);
            if (HAS_PARENT) {
                Internal.set_parent_on_range(self, parent_id, old_first_right, range.first, range.last, NULL_ID);
            }
            return range;
        }

        pub fn insert_disconnected_items_at_beginning_of_right_children(self: *Heirarchy, parent_id: Id, disconnected_items: Range) void {
            Internal.assert_has_first_right(@src());
            Internal.assert_disconnect_range_is_isolated(self, disconnected_items, @src());
            const parent_ptr = self.get_ptr(parent_id);
            const old_first_right = get_first_right_child_id(parent_ptr);
            const last_disconn_ptr = self.get_ptr(disconnected_items.last);
            Internal.set_next_id(last_disconn_ptr, old_first_right);
            Internal.set_first_left_child_id(parent_ptr, disconnected_items.first);
            if (HAS_PARENT) {
                Internal.set_parent_on_range(self, parent_id, old_first_right, disconnected_items.first, disconnected_items.last, NULL_ID);
            }
        }

        pub fn insert_slot_at_beginning_of_heirarchy_root(self: *Heirarchy, alloc_else_assume_cap: ?AllocInfal) Id {
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(1, alloc);
            }
            const new_id = Internal.initialize_new_index(self);
            const new_ptr = self.get_ptr(new_id);
            Internal.set_next_id(new_ptr, self.first_root_id);
            self.first_root_id = new_id;
            return new_id;
        }

        pub fn insert_many_slots_at_beginning_of_heirarchy_root(self: *Heirarchy,  count: Index, alloc_else_assume_cap: ?AllocInfal) Range {
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(count, alloc);
            }
            const range = Internal.initialize_new_indexes_as_siblings(self, count);
            const new_last_ptr = self.get_ptr(range.last);
            Internal.set_next_id(new_last_ptr, self.first_root_id);
            self.first_root_id = range.first;
            return range;
        }

        pub fn insert_disconnected_items_at_beginning_of_heirarchy_root(self: *Heirarchy, disconnected_items: Range) void {
            const last_disconn_ptr = self.get_ptr(disconnected_items.last);
            Internal.assert_disconnect_range_is_isolated(self, disconnected_items, @src());
            Internal.set_next_id(last_disconn_ptr, self.first_root_id);
            self.first_root_id = disconnected_items.first;
        }

        pub fn insert_slot_at_end_of_heirarchy_root(self: *Heirarchy, alloc_else_assume_cap: ?AllocInfal) Id {
            Internal.assert_has_root_last(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(1, alloc);
            }
            const new_id = Internal.initialize_new_index(self);
            const new_ptr = self.get_ptr(new_id);
            Internal.set_next_id(new_ptr, self.last_root_id);
            self.last_root_id = new_id;        
            return new_id;
        }

        pub fn insert_many_slots_at_end_of_heirarchy_root(self: *Heirarchy,  count: Index, alloc_else_assume_cap: ?AllocInfal) Range {
            Internal.assert_has_root_last(@src());
            if (alloc_else_assume_cap) |alloc| {
                self.list.ensure_unused_capacity(count, alloc);
            }
            const range = Internal.initialize_new_indexes_as_siblings(self, count);
            const new_last_ptr = self.get_ptr(range.last);
            Internal.set_next_id(new_last_ptr, self.last_root_id);
            self.last_root_id = range.first;
            return range;
        }

        pub fn insert_disconnected_items_at_end_of_heirarchy_root(self: *Heirarchy, disconnected_items: Range) void {
            Internal.assert_has_root_last(@src());
            Internal.assert_disconnect_range_is_isolated(self, disconnected_items, @src());
            const last_disconn_ptr = self.get_ptr(disconnected_items.last);
            Internal.set_next_id(last_disconn_ptr, self.last_root_id);
            self.last_root_id = disconnected_items.first;
        }

        pub fn disconnect_item_range_after(self: *Heirarchy, this_id: Id, last_disconnect_id: Id) Range {
            Internal.assert_has_next(@src());
            const right_id = get_next_id(self.get_ptr(last_disconnect_id));
            const first_disconnect_id = get_next_id(self.get_ptr(this_id));
            Internal.remove_id_range(self, this_id, first_disconnect_id, last_disconnect_id, right_id);
            return Range{.first = first_disconnect_id, .last = last_disconnect_id};
        }

        pub fn disconnect_item_range_from_beginning_of_left_children(self: *Heirarchy, parent_id: Id, last_disconnect_id: Id) Range {
            Internal.assert_has_first_left(@src());
            const right_id = get_next_id(self.get_ptr(last_disconnect_id));
            const first_disconnect_id = get_first_left_child_id(self.get_ptr(parent_id));
            Internal.assert_2_siblings_in_order_no_cycles(self, first_disconnect_id, last_disconnect_id, true, false, @src());
            const last_ptr = self.get_ptr(last_disconnect_id);
            Internal.set_next_id(last_ptr, NULL_ID);
            const parent_ptr = self.get_ptr(parent_id);
            Internal.set_first_left_child_id(parent_ptr, right_id);
            return Range{.first = first_disconnect_id, .last = last_disconnect_id};
        }

        pub fn disconnect_item_range_from_beginning_of_right_children(self: *Heirarchy, parent_id: Id, last_disconnect_id: Id) Range {
            Internal.assert_has_first_right(@src());
            const right_id = get_next_id(self.get_ptr(last_disconnect_id));
            const first_disconnect_id = get_first_right_child_id(self.get_ptr(parent_id));
            Internal.assert_2_siblings_in_order_no_cycles(self, first_disconnect_id, last_disconnect_id, true, false, @src());
            const last_ptr = self.get_ptr(last_disconnect_id);
            Internal.set_next_id(last_ptr, NULL_ID);
            const parent_ptr = self.get_ptr(parent_id);
            Internal.set_first_right_child_id(parent_ptr, right_id);
            return Range{.first = first_disconnect_id, .last = last_disconnect_id};
        }

        pub inline fn free_disconnected_items_with_new_heap_iterator(self: *Heirarchy, first_disconected_id: Id, alloc: AllocInfal) void {
            var new_iterator = self.create_iterator_on_heap(alloc);
            defer new_iterator.free();
            new_iterator.free_disconnected_items(first_disconected_id);
        }

        pub inline fn free_disconnected_items_with_new_stack_iterator(self: *Heirarchy, first_disconected_id: Id, buffer: []IteratorFrame) void {
            var new_iterator = self.create_iterator_on_stack(buffer);
            defer new_iterator.free();
            new_iterator.free_disconnected_items(first_disconected_id);
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

        pub fn create_iterator_on_heap(self: *Heirarchy, alloc: AllocInfal) Iterator {
            return Iterator{
                .alloc = alloc,
                .frames = Iterator.FramesList.new_empty(alloc),
                .heirarchy = self,
            };
        }

        pub fn create_iterator_on_stack(self: *Heirarchy, buffer: []IteratorFrame) Iterator {
            return Iterator{
                .frames = Iterator.FramesList{
                    .assert_alloc = AllocInfal.DummyAllocInfal,
                    .cap = @intCast(buffer.len),
                    .len = 0,
                    .ptr = buffer.ptr,
                },
                .heirarchy = self,
            };
        }

        pub fn create_traverser_on_heap(self: *Heirarchy, alloc: AllocInfal) Traverser {
            return Traverser{
                .alloc = alloc,
                .frames = Traverser.FramesList.new_empty(alloc),
                .heirarchy = self,
            };
        }

        pub fn create_traverser_on_stack(self: *Heirarchy, buffer: []TraverserFrame) Traverser {
            return Traverser{
                .frames = Traverser.FramesList{
                    .assert_alloc = AllocInfal.DummyAllocInfal,
                    .cap = @intCast(buffer.len),
                    .len = 0,
                    .ptr = buffer.ptr,
                },
                .heirarchy = self,
            };
        }

        //zig fmt: off
        pub const NodeProgress = enum(u8) {
            BEFORE_LEFT_CHILDREN            = 0b00,
            BETWEEN_LEFT_AND_RIGHT_CHILDREN = 0b01,
            AFTER_RIGHT_CHILDREN            = 0b10,
            EXITED                          = 0b11,
        };
        // zig fmt: on

        pub const IteratorFrame = struct {
            curr_id: Id = NULL_ID,
            progress: NodeProgress = .BEFORE_LEFT_CHILDREN,

            pub inline fn set_progress_at_least(self: *IteratorFrame, new_prog: NodeProgress) void {
                self.progress = @enumFromInt(@max(@intFromEnum(self.progress), @intFromEnum(new_prog)));
            }
        };

        pub const Iterator = struct {
            frames: FramesList = FramesList.UNINIT,
            heirarchy: *Heirarchy,
            alloc: AllocInfal = AllocInfal.DummyAllocInfal,

            pub const FramesList = Root.List.List(ITER_STACK_OPTIONS);

            pub inline fn free(self: *Iterator) void {
                self.frames.clear_and_free(self.alloc);
            }

            pub inline fn get_current_id(self: *const Iterator) Id {
                if (self.frames.len == 0) return NULL_ID;
                return self.frames.get_last().curr_id;
            }

            pub inline fn get_current_ptr(self: *const Iterator) *Elem {
                return self.heirarchy.get_ptr(self.get_current_id());
            }

            pub inline fn get_current_progress(self: *const Iterator) NodeProgress {
                return self.frames.get_last().progress;
            }

            pub inline fn get_parent_progress(self: *const Iterator) NodeProgress {
                if (self.frames.len == 1) return NodeProgress.EXITED;
                return self.frames.ptr[self.frames.len - 2].progress;
            }

            pub fn clone_to_stack(self: *const Iterator, buffer: []IteratorFrame) Iterator {
                var new = self.heirarchy.create_iterator_on_stack(buffer);
                @memcpy(new.frames.ptr[0..self.frames.len], self.frames.ptr[0..self.frames.len]);
                new.frames.len = self.frames.len;
                return new;
            }

            pub fn clone_to_heap(self: *const Iterator, alloc: AllocInfal) Iterator {
                var new = self.heirarchy.create_iterator_on_heap(alloc);
                new.frames.ensure_total_capacity(self.frames.cap, alloc);
                @memcpy(new.frames.ptr[0..self.frames.len], self.frames.ptr[0..self.frames.len]);
                new.frames.len = self.frames.len;
                return new;
            }

            pub fn clone_to_stack_as_traverser(self: *const Iterator, buffer: []IteratorFrame) Traverser {
                var new = self.heirarchy.create_traverser_on_stack(buffer);
                for (self.frames.slice(), 0..) |elem, idx| {
                    new.frames.ptr[idx] = elem.curr_id;
                }
                new.frames.len = self.frames.len;
                return new;
            }

            pub fn clone_to_heap_as_traverser(self: *const Iterator, alloc: AllocInfal) Traverser {
                var new = self.heirarchy.create_traverser_on_heap(alloc);
                new.frames.ensure_total_capacity(self.frames.cap, alloc);
                for (self.frames.slice(), 0..) |elem, idx| {
                    new.frames.ptr[idx] = elem.curr_id;
                }
                new.frames.len = self.frames.len;
                return new;
            }

            fn goto_next(self: *Iterator) bool {
                if (!HAS_NEXT or self.frames.len == 0) return false;
                const last_frame: *IteratorFrame = self.frames.get_last_ptr();
                const curr_id = last_frame.curr_id;
                const curr_ptr = self.heirarchy.get_ptr(curr_id);
                const next_id = get_next_id(curr_ptr);
                if (next_id == NULL_ID) return false;
                last_frame.curr_id = next_id;
                return true;
            }

            fn goto_first_left_child(self: *Iterator) bool {
                if (!HAS_FIRST_LEFT_CHILD or self.frames.len == 0) return false;
                const last_frame: *IteratorFrame = self.frames.get_last_ptr();
                const curr_id = last_frame.curr_id;
                const curr_ptr = self.heirarchy.get_ptr(curr_id);
                const left_child_id = get_first_left_child_id(curr_ptr);
                if (left_child_id == NULL_ID) return false;
                self.frames.append(IteratorFrame{ .curr_id = left_child_id }, self.alloc);
                return true;
            }

            fn goto_first_right_child(self: *Iterator) bool {
                if (!HAS_FIRST_RIGHT_CHILD or self.frames.len == 0) return false;
                const last_frame: *IteratorFrame = self.frames.get_last_ptr();
                const curr_id = last_frame.curr_id;
                const curr_ptr = self.heirarchy.get_ptr(curr_id);
                const right_child_id = get_first_right_child_id(curr_ptr);
                if (right_child_id == NULL_ID) return false;
                self.frames.append(IteratorFrame{ .curr_id = right_child_id }, self.alloc);
                return true;
            }

            fn goto_parent(self: *Iterator) bool {
                if (!(HAS_FIRST_LEFT_CHILD or HAS_FIRST_RIGHT_CHILD) or self.frames.len < 2) return false;
                self.frames.set_len(self.frames.len - 1);
                return self.frames.len > 0;
            }

            fn init(self: *Iterator, start_id: Id) bool {
                self.frames.clear_retaining_capacity();
                if (start_id == NULL_ID) return false;
                self.frames.append(IteratorFrame{ .curr_id = start_id }, self.alloc);
                return true;
            }

            pub fn reset_and_iterate_depth_first_and_do_actions_on_all_items(self: *Iterator, comptime actions: IteratorActions, userdata: ?*anyopaque) void {
                if (!self.init(self.heirarchy.first_root_id)) return;
                self.iterate_through_heirarchy_depth_first_and_do_actions_on_items(actions, false, NULL_ID, userdata);
            }

            pub fn reset_and_iterate_depth_first_and_do_actions_on_items_before_id(self: *Iterator, stop_before_id: Id, comptime actions: IteratorActions, userdata: ?*anyopaque) void {
                if (!self.init(self.heirarchy.first_root_id)) return;
                self.iterate_through_heirarchy_depth_first_and_do_actions_on_items(actions, true, stop_before_id, userdata);
            }

            pub fn continue_to_iterate_depth_first_and_do_actions_on_all_remaining_items(self: *Iterator, comptime actions: IteratorActions, userdata: ?*anyopaque) void {
                if (self.frames.len == 0) return;
                self.iterate_through_heirarchy_depth_first_and_do_actions_on_items(actions, false, NULL_ID, userdata);
            }

            pub fn continue_to_iterate_depth_first_and_do_actions_on_remaining_items_before_id(self: *Iterator, stop_before_id: Id, comptime actions: IteratorActions, userdata: ?*anyopaque) void {
                if (self.frames.len == 0) return;
                self.iterate_through_heirarchy_depth_first_and_do_actions_on_items(actions, true, stop_before_id, userdata);
            }

            pub fn custom_start_iterate_depth_first_and_do_actions_on_all_items(self: *Iterator, start_id: Id, comptime actions: IteratorActions, userdata: ?*anyopaque) void {
                if (!self.init(start_id)) return;
                self.iterate_through_heirarchy_depth_first_and_do_actions_on_items(actions, false, NULL_ID, userdata);
            }

            pub fn custom_start_iterate_depth_first_and_do_actions_on_items_before_id(self: *Iterator, start_id: Id, stop_before_id: Id, comptime actions: IteratorActions, userdata: ?*anyopaque) void {
                if (!self.init(start_id)) return;
                self.iterate_through_heirarchy_depth_first_and_do_actions_on_items(actions, true, stop_before_id, userdata);
            }

            fn add_to_free_action(traverser: *const Iterator, exit_id: Id, exit_kind: NodeExitKind, userdata: ?*anyopaque) bool {
                _ = exit_kind;
                _ = userdata;
                Internal.push_free_item(traverser.heirarchy, exit_id);
                return true;
            }

            pub fn free_disconnected_items(self: *Iterator, first_disconected_id: Id) void {
                self.custom_start_iterate_depth_first_and_do_actions_on_all_items(first_disconected_id, IteratorActions{
                    .after_exiting_item = add_to_free_action,
                }, null);
            }

            fn iterate_through_heirarchy_depth_first_and_do_actions_on_items(self: *Iterator, actions: IteratorActions, comptime use_stop_id: bool, stop_id: Id, userdata: ?*anyopaque) void {
                var last_frame: *IteratorFrame = self.frames.get_last_ptr();
                traversal: switch (last_frame.progress) {
                    NodeProgress.BEFORE_LEFT_CHILDREN => {
                        if (use_stop_id and last_frame.curr_id == stop_id) break :traversal;
                        if (actions.before_left_children) |before_action| {
                            if (!before_action(self, userdata)) break :traversal;
                        }
                        last_frame.progress = .BETWEEN_LEFT_AND_RIGHT_CHILDREN;
                        if (self.goto_first_left_child()) {
                            last_frame = self.frames.get_last_ptr();
                            last_frame.progress = .BEFORE_LEFT_CHILDREN;
                            continue :traversal NodeProgress.BEFORE_LEFT_CHILDREN;
                        }
                        continue :traversal NodeProgress.BETWEEN_LEFT_AND_RIGHT_CHILDREN;
                    },
                    NodeProgress.BETWEEN_LEFT_AND_RIGHT_CHILDREN => {
                        if (use_stop_id and last_frame.curr_id == stop_id) break :traversal;
                        if (actions.after_left_before_right_children) |middle_action| {
                            if (!middle_action(self, userdata)) break :traversal;
                        }
                        last_frame.progress = .AFTER_RIGHT_CHILDREN;
                        if (self.goto_first_right_child()) {
                            last_frame = self.frames.get_last_ptr();
                            last_frame.progress = .BEFORE_LEFT_CHILDREN;
                            continue :traversal NodeProgress.BEFORE_LEFT_CHILDREN;
                        }
                        continue :traversal NodeProgress.AFTER_RIGHT_CHILDREN;
                    },
                    NodeProgress.AFTER_RIGHT_CHILDREN => {
                        if (use_stop_id and last_frame.curr_id == stop_id) break :traversal;
                        if (actions.after_right_children) |after_action| {
                            if (!after_action(self, userdata)) break :traversal;
                        }
                        last_frame.progress = .EXITED;
                        if (actions.after_exiting_item) |exit_action| {
                            const exit_id = last_frame.curr_id;
                            var exit_kind: NodeExitKind = .EXITED_BY_HITTING_END_OF_ITERATOR;
                            var did_move = false;
                            if (self.goto_next()) {
                                did_move = true;
                                exit_kind = .EXITED_BY_MOVING_TO_NEXT_SIBLING;
                                last_frame.progress = .BEFORE_LEFT_CHILDREN;
                            } else if (self.goto_parent()) {
                                did_move = true;
                                last_frame = self.frames.get_last_ptr();
                                exit_kind = .EXITED_BY_RETURNING_TO_PARENT;
                            }
                            if (!exit_action(self, exit_id, exit_kind, userdata)) break :traversal;
                            if (did_move) {
                                continue :traversal last_frame.progress;
                            }
                        } else {
                            if (self.goto_next()) {
                                last_frame.progress = .BEFORE_LEFT_CHILDREN;
                                continue :traversal NodeProgress.BEFORE_LEFT_CHILDREN;
                            }
                            if (self.goto_parent()) {
                                last_frame = self.frames.get_last_ptr();
                                continue :traversal last_frame.progress;
                            }
                        }
                    },
                    NodeProgress.EXITED => {
                        assert_with_reason(false, @src(), "iteration should never return to an 'exited' node", .{});
                    },
                }
            }
        };

        pub const IteratorActions = struct {
            // action_before_entering_item: ?*const fn (traverser: *const HeirarchyTraverser, entering_id: Id, enter_kind: TraversalEnterKind, userdata: ?*anyopaque) bool,
            before_left_children: ?*const fn (traverser: *const Iterator, userdata: ?*anyopaque) bool = null,
            after_left_before_right_children: ?*const fn (traverser: *const Iterator, userdata: ?*anyopaque) bool = null,
            after_right_children: ?*const fn (traverser: *const Iterator, userdata: ?*anyopaque) bool = null,
            after_exiting_item: ?*const fn (traverser: *const Iterator, exited_id: Id, exit_kind: NodeExitKind, userdata: ?*anyopaque) bool = null,
        };

        pub const TraverserFrame = struct {
            curr_id: Id = NULL_ID,
        };

        pub const Traverser = struct {
            frames: FramesList = FramesList.UNINIT,
            heirarchy: *Heirarchy,
            alloc: AllocInfal = AllocInfal.DummyAllocInfal,

            pub const FramesList = Root.List.List(TRAV_STACK_OPTIONS);

            pub inline fn free(self: *Traverser) void {
                self.frames.clear_and_free(self.alloc);
            }

            pub inline fn get_current_id(self: *const Traverser) Id {
                assert_with_reason(self.frames.len > 0, @src(), "no current location, traversal frames empty", .{});
                return self.frames.get_last().curr_id;
            }

            pub inline fn get_current_index(self: *const Traverser) Index {
                assert_with_reason(self.frames.len > 0, @src(), "no current location, traversal frames empty", .{});
                return get_index(self.frames.get_last().curr_id);
            }

            pub inline fn get_current_ptr(self: *const Traverser) *Elem {
                assert_with_reason(self.frames.len > 0, @src(), "no current location, traversal frames empty", .{});
                return self.heirarchy.get_ptr(self.get_current_id());
            }

            pub inline fn get_parent_id(self: *const Traverser) Id {
                assert_with_reason(self.frames.len > 1, @src(), "no parent in traversal stack, either already at top level, or traverser at the same lever it was 'started' at (no parents saved above start location)", .{});
                return self.frames.ptr[self.frames.len - 2].curr_id;
            }

            pub inline fn get_parent_index(self: *const Traverser) Index {
                assert_with_reason(self.frames.len > 1, @src(), "no parent in traversal stack, either already at top level, or traverser at the same lever it was 'started' at (no parents saved above start location)", .{});
                return get_index(self.frames.ptr[self.frames.len - 2].curr_id);
            }

            pub inline fn get_parent_ptr(self: *const Traverser) *Elem {
                assert_with_reason(self.frames.len > 1, @src(), "no parent in traversal stack, either already at top level, or traverser at the same lever it was 'started' at (no parents saved above start location)", .{});
                return self.heirarchy.get_ptr(self.frames.ptr[self.frames.len - 2].curr_id);
            }

            pub inline fn get_nth_parent_id(self: *const Traverser, n: Index) Id {
                assert_with_reason(self.frames.len > n, @src(), "no {d}-th parent in traversal stack, only {d} more parents above current", .{ n, self.frames.len -| 1 });
                if (self.frames.len == 0) return NULL_ID;
                return self.frames.ptr[self.frames.len - n - 1].curr_id;
            }

            pub inline fn get_nth_parent_index(self: *const Traverser, n: Index) Index {
                assert_with_reason(self.frames.len > n, @src(), "no {d}-th parent in traversal stack, only {d} more parents above current", .{ n, self.frames.len -| 1 });
                if (self.frames.len == 0) return NULL_ID;
                return get_index(self.frames.ptr[self.frames.len - n - 1].curr_id);
            }

            pub inline fn get_nth_parent_ptr(self: *const Traverser, n: Index) *Elem {
                assert_with_reason(self.frames.len > n, @src(), "no {d}-th parent in traversal stack, only {d} more parents above current", .{ n, self.frames.len -| 1 });
                return self.heirarchy.get_ptr(self.frames.ptr[self.frames.len - n - 1].curr_id);
            }

            pub fn clone_to_stack(self: *const Traverser, buffer: []TraverserFrame) Traverser {
                var new = self.heirarchy.create_traverser_on_stack(buffer);
                @memcpy(new.frames.ptr[0..self.frames.len], self.frames.ptr[0..self.frames.len]);
                new.frames.len = self.frames.len;
                return new;
            }

            pub fn clone_to_heap(self: *const Traverser, alloc: AllocInfal) Traverser {
                var new = self.heirarchy.create_traverser_on_heap(alloc);
                @memcpy(new.frames.ptr[0..self.frames.len], self.frames.ptr[0..self.frames.len]);
                new.frames.len = self.frames.len;
                return new;
            }

            pub fn goto_next(self: *Traverser) bool {
                if (!HAS_NEXT or self.frames.len == 0) return false;
                const last_frame: *TraverserFrame = self.frames.get_last_ptr();
                const curr_id = last_frame.curr_id;
                const curr_ptr = self.heirarchy.get_ptr(curr_id);
                const next_id = get_next_id(curr_ptr);
                if (next_id == NULL_ID) return false;
                last_frame.curr_id = next_id;
                return true;
            }

            pub fn goto_nth_next(self: *Traverser, count: Index) usize {
                var c: Index = 0;
                while (c < count) {
                    if (self.goto_next()) {
                        c += 1;
                    } else break;
                }
                return c;
            }

            pub fn goto_last_sibling(self: *Traverser) usize {
                var c: Index = 0;
                while (true) {
                    if (self.goto_next()) {
                        c += 1;
                    } else break;
                }
                return c;
            }

            pub fn goto_first_left_child(self: *Traverser) bool {
                if (!HAS_FIRST_LEFT_CHILD or self.frames.len == 0) return false;
                const last_frame: *TraverserFrame = self.frames.get_last_ptr();
                const curr_id = last_frame.curr_id;
                const curr_ptr = self.heirarchy.get_ptr(curr_id);
                const left_child_id = get_first_left_child_id(curr_ptr);
                if (left_child_id == NULL_ID) return false;
                self.frames.append(TraverserFrame{ .curr_id = left_child_id }, self.alloc);
                return true;
            }

            pub fn goto_nth_first_left_child(self: *Traverser, count: Index) usize {
                var c: Index = 0;
                while (c < count) {
                    if (self.goto_first_left_child()) {
                        c += 1;
                    } else break;
                }
                return c;
            }

            pub fn goto_bottom_first_left_child(self: *Traverser) usize {
                var c: Index = 0;
                while (true) {
                    if (self.goto_first_left_child()) {
                        c += 1;
                    } else break;
                }
                return c;
            }

            pub fn goto_first_right_child(self: *Traverser) bool {
                if (!HAS_FIRST_RIGHT_CHILD or self.frames.len == 0) return false;
                const last_frame: *TraverserFrame = self.frames.get_last_ptr();
                const curr_id = last_frame.curr_id;
                const curr_ptr = self.heirarchy.get_ptr(curr_id);
                const right_child_id = get_first_right_child_id(curr_ptr);
                if (right_child_id == NULL_ID) return false;
                self.frames.append(TraverserFrame{ .curr_id = right_child_id }, self.alloc);
                return true;
            }

            pub fn goto_nth_first_right_child(self: *Traverser, count: Index) usize {
                var c: Index = 0;
                while (c < count) {
                    if (self.goto_first_right_child()) {
                        c += 1;
                    } else break;
                }
                return c;
            }

            pub fn goto_bottom_first_right_child(self: *Traverser) usize {
                var c: Index = 0;
                while (true) {
                    if (self.goto_first_right_child()) {
                        c += 1;
                    } else break;
                }
                return c;
            }

            pub fn goto_parent(self: *Traverser) bool {
                if (!HAS_FIRST_CHILD_NODES or self.frames.len < 2) return false;
                self.frames.set_len(self.frames.len - 1);
                return self.frames.len > 0;
            }

            pub fn goto_nth_parent(self: *Traverser, count: Index) usize {
                var c: Index = 0;
                while (c < count) {
                    if (self.goto_parent()) {
                        c += 1;
                    } else break;
                }
                return c;
            }

            pub fn goto_top_parent(self: *Traverser) usize {
                var c: Index = 0;
                while (true) {
                    if (self.goto_parent()) {
                        c += 1;
                    } else break;
                }
                return c;
            }

            pub fn start_from_root(self: *Traverser) void {
                return self.start_from(self.heirarchy.first_root_id);
            }

            pub fn start_from(self: *Traverser, start_id: Id) bool {
                self.frames.clear_retaining_capacity();
                if (start_id == NULL_ID) return false;
                self.frames.append(TraverserFrame{ .curr_id = start_id }, self.alloc);
                return true;
            }
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

const Test = if (build.mode == .Debug) struct {
    const t = Root.Testing;
    const alloc = AllocInfal{ .allocator = std.heap.page_allocator };
    const TestElem = struct {
        id: u32,
        next: u32,
        left: u32,
        right: u32,
        val: u8,
    };
    const uninit_val = TestElem{
        .id = 0xAAAAAAAA,
        .next = 0xAAAA,
        .left = 0xAAAA,
        .right = 0xAAAA,
        .val = 0,
    };
    const Copy = struct {
        fn action(from_item: *const anyopaque, to_item: *anyopaque) void {
            const from_cast: *const TestElem = @ptrCast(@alignCast(from_item));
            const to_cast: *TestElem = @ptrCast(@alignCast(to_item));
            to_cast.val = from_cast.val;
        }
    };
    const opts = ForwardLinkedHeirarchyOptions{
        .element_memory_options = Root.List.ListOptions{
            .alignment = null,
            .assert_correct_allocator = true,
            .element_type = TestElem,
            .growth_model = .GROW_BY_25_PERCENT,
            .index_type = u16,
            .secure_wipe_bytes = true,
            .memset_uninit_val = &uninit_val,
        },
        .next_field = "next",
        .first_left_child_field = "left",
        .first_right_child_field = "right",
        .custom_copy_only_value_fn = Copy.action,
        .element_id_type = u32,
        .generation_details = GenerationDetails{
            .generation_bits = 16,
            .index_bits = 16,
        },
        .own_id_field = "id",
        .strong_asserts = true,
        .traversal_stack_options = Root.List.ListOptionsWithoutElem{
            .alignment = null,
            .assert_correct_allocator = true,
            .growth_model = .GROW_EXACT_NEEDED,
            .index_type = u8,
            .secure_wipe_bytes = true,
        },
    };
    const List = LinkedHeirarchy(opts);
    const node_tracker_ids_opts = Root.List.ListOptions{
        .alignment = null,
        .assert_correct_allocator = true,
        .element_type = u32,
        .growth_model = .GROW_BY_25_PERCENT,
        .index_type = u16,
        .memset_uninit_val = null,
        .secure_wipe_bytes = true,
    };
    const node_tracker_chars_opts = Root.List.ListOptions{
        .alignment = null,
        .assert_correct_allocator = true,
        .element_type = u8,
        .growth_model = .GROW_BY_25_PERCENT,
        .index_type = u16,
        .memset_uninit_val = null,
        .secure_wipe_bytes = true,
    };
    const NodeTrackerIdList = Root.List.List(node_tracker_ids_opts);
    const NodeTrackerCharList = Root.List.List(node_tracker_chars_opts);
    const NodeTracker = struct {
        ids: NodeTrackerIdList,
        chars: NodeTrackerCharList,
        expected: []const u8,
        name: []const u8,
    };
    const NodeTrackerSet = struct {
        before: NodeTracker,
        middle: NodeTracker,
        after: NodeTracker,
        exit: NodeTracker,
        errors: bool = false,
    };
    const Action = struct {
        fn set_value_from_string(traverser: *const List.Iterator, userdata: ?*anyopaque) bool {
            const string: *[]const u8 = @ptrCast(@alignCast(userdata.?));
            const curr_ptr = traverser.get_current_ptr();
            curr_ptr.val = string.*[0];
            string.* = string.*[1..];
            return string.len > 0;
        }
        fn greater_than(a: *const TestElem, b: *const TestElem, userdata: ?*anyopaque) bool {
            _ = userdata;
            return a.val > b.val;
        }
        fn node_match(param: NodeTrackerIdList.Elem, item: *const NodeTrackerIdList.Elem) bool {
            return item.* == param;
        }
        fn assert_node_before(traverser: *const List.Iterator, userdata: ?*anyopaque) bool {
            var tracker_set: *NodeTrackerSet = @ptrCast(@alignCast(userdata.?));
            var tracker = &tracker_set.before;
            const curr_ptr: *TestElem = traverser.get_current_ptr();
            const duplicate = tracker.ids.find_idx(NodeTrackerIdList.Elem, curr_ptr.id, node_match);
            if (duplicate) |dupe| {
                t.expect_null(duplicate, "duplicate_id", "tracker {s} found duplicate id (index = {d}, gen = {d})", .{ tracker.name, List.get_index(dupe), List.get_gen(dupe) }) catch {
                    tracker_set.errors = true;
                    return false;
                };
            }
            t.expect_less_than(tracker.ids.len, "tracker.list.len", tracker.expected.len, "tracker.expected.len", "found more nodes than expected", .{}) catch {
                tracker_set.errors = true;
                return false;
            };
            tracker.ids.append(curr_ptr.id, alloc);
            tracker.chars.append(curr_ptr.val, alloc);
            return true;
        }
        fn assert_node_middle(traverser: *const List.Iterator, userdata: ?*anyopaque) bool {
            var tracker_set: *NodeTrackerSet = @ptrCast(@alignCast(userdata.?));
            var tracker = &tracker_set.middle;
            const curr_ptr: *TestElem = traverser.get_current_ptr();
            const duplicate = tracker.ids.find_idx(NodeTrackerIdList.Elem, curr_ptr.id, node_match);
            if (duplicate) |dupe| {
                t.expect_null(duplicate, "duplicate_id", "tracker {s} found duplicate id (index = {d}, gen = {d})", .{ tracker.name, List.get_index(dupe), List.get_gen(dupe) }) catch {
                    tracker_set.errors = true;
                    return false;
                };
            }
            t.expect_less_than(tracker.ids.len, "tracker.list.len", tracker.expected.len, "tracker.expected.len", "found more nodes than expected", .{}) catch {
                tracker_set.errors = true;
                return false;
            };
            tracker.ids.append(curr_ptr.id, alloc);
            tracker.chars.append(curr_ptr.val, alloc);
            return true;
        }
        fn assert_node_after(traverser: *const List.Iterator, userdata: ?*anyopaque) bool {
            var tracker_set: *NodeTrackerSet = @ptrCast(@alignCast(userdata.?));
            var tracker = &tracker_set.after;
            const curr_ptr: *TestElem = traverser.get_current_ptr();
            const duplicate = tracker.ids.find_idx(NodeTrackerIdList.Elem, curr_ptr.id, node_match);
            if (duplicate) |dupe| {
                t.expect_null(duplicate, "duplicate_id", "tracker {s} found duplicate id (index = {d}, gen = {d})", .{ tracker.name, List.get_index(dupe), List.get_gen(dupe) }) catch {
                    tracker_set.errors = true;
                    return false;
                };
            }
            t.expect_less_than(tracker.ids.len, "tracker.list.len", tracker.expected.len, "tracker.expected.len", "found more nodes than expected", .{}) catch {
                tracker_set.errors = true;
                return false;
            };
            tracker.ids.append(curr_ptr.id, alloc);
            tracker.chars.append(curr_ptr.val, alloc);
            return true;
        }
        fn assert_node_exit(traverser: *const List.Iterator, exit_id: List.Id, exit_kind: NodeExitKind, userdata: ?*anyopaque) bool {
            _ = exit_kind;
            var tracker_set: *NodeTrackerSet = @ptrCast(@alignCast(userdata.?));
            var tracker = &tracker_set.exit;
            const exit_ptr: *TestElem = &traverser.heirarchy.list.ptr[List.get_index(exit_id)];
            const duplicate = tracker.ids.find_idx(NodeTrackerIdList.Elem, exit_id, node_match);
            if (duplicate) |dupe| {
                t.expect_null(duplicate, "duplicate_id", "tracker {s} found duplicate id (index = {d}, gen = {d})", .{ tracker.name, List.get_index(dupe), List.get_gen(dupe) }) catch {
                    tracker_set.errors = true;
                    return false;
                };
            }
            t.expect_less_than(tracker.ids.len, "tracker.list.len", tracker.expected.len, "tracker.expected.len", "found more nodes than expected", .{}) catch {
                tracker_set.errors = true;
                return false;
            };
            tracker.ids.append(exit_id, alloc);
            tracker.chars.append(exit_ptr.val, alloc);
            return true;
        }
    };
    const assert_node_actions = List.IteratorActions{
        .before_left_children = Action.assert_node_before,
        .after_left_before_right_children = Action.assert_node_middle,
        .after_right_children = Action.assert_node_after,
        .after_exiting_item = Action.assert_node_exit,
    };
    const write_node_actions = List.IteratorActions{
        .after_left_before_right_children = Action.set_value_from_string,
    };
    const expect = struct {
        fn traversal_yields(traverser: *List.Iterator, node_trackers: *NodeTrackerSet, start_id: List.Id, pre_order: []const u8, in_order: []const u8, post_order: []const u8) !void {
            node_trackers.errors = false;
            node_trackers.before.ids.clear_retaining_capacity();
            node_trackers.middle.ids.clear_retaining_capacity();
            node_trackers.after.ids.clear_retaining_capacity();
            node_trackers.exit.ids.clear_retaining_capacity();
            node_trackers.before.chars.clear_retaining_capacity();
            node_trackers.middle.chars.clear_retaining_capacity();
            node_trackers.after.chars.clear_retaining_capacity();
            node_trackers.exit.chars.clear_retaining_capacity();
            node_trackers.before.expected = pre_order;
            node_trackers.middle.expected = in_order;
            node_trackers.after.expected = post_order;
            node_trackers.exit.expected = post_order;
            traverser.custom_start_iterate_depth_first_and_do_actions_on_all_items(start_id, assert_node_actions, @ptrCast(node_trackers));
            try t.expect_false(node_trackers.errors, "node_trackers.errors", "At least one error", .{});
            try t.expect_equal(node_trackers.before.ids.len, "node_trackers.before.ids.len", pre_order.len, "pre_order.len", "tracker {s} preformed actions on {d} items, but expected {d} items", .{ node_trackers.before.name, node_trackers.before.ids.len, pre_order.len });
            try t.expect_equal(node_trackers.middle.ids.len, "node_trackers.middle.ids.len", in_order.len, "in_order.len", "tracker {s} preformed actions on {d} items, but expected {d} items", .{ node_trackers.middle.name, node_trackers.middle.ids.len, in_order.len });
            try t.expect_equal(node_trackers.after.ids.len, "node_trackers.after.list.len", post_order.len, "post_order.len", "tracker {s} preformed actions on {d} items, but expected {d} items", .{ node_trackers.after.name, node_trackers.after.ids.len, post_order.len });
            try t.expect_equal(node_trackers.exit.ids.len, "node_trackers.exit.list.len", post_order.len, "post_order.len", "tracker {s} preformed actions on {d} items, but expected {d} items", .{ node_trackers.exit.name, node_trackers.exit.ids.len, post_order.len });
            try t.expect_strings_equal(node_trackers.before.chars.slice(), "node_trackers.before.chars.slice()", node_trackers.before.expected, "node_trackers.before.expected", "mismatch traversal result", .{});
            try t.expect_strings_equal(node_trackers.middle.chars.slice(), "node_trackers.middle.chars.slice()", node_trackers.middle.expected, "node_trackers.middle.expected", "mismatch traversal result", .{});
            try t.expect_strings_equal(node_trackers.after.chars.slice(), "node_trackers.after.chars.slice()", node_trackers.after.expected, "node_trackers.after.expected", "mismatch traversal result", .{});
            try t.expect_strings_equal(node_trackers.exit.chars.slice(), "node_trackers.exit.chars.slice()", node_trackers.exit.expected, "node_trackers.exit.expected", "mismatch traversal result", .{});
        }
    };
};

test "Full_Heirarchy" {
    const List = Test.List;
    const alloc = Test.alloc;
    var heirarchy = List.new_empty(Test.alloc);
    var iter_buf: [10]List.IteratorFrame = undefined;
    var trav_buf: [10]List.TraverserFrame = undefined;
    var iterator = heirarchy.create_iterator_on_stack(&iter_buf);
    defer iterator.free();
    var traverser = heirarchy.create_traverser_on_stack(&trav_buf);
    defer traverser.free();
    var node_trackers = Test.NodeTrackerSet{
        .before = Test.NodeTracker{ .ids = Test.NodeTrackerIdList.new_with_capacity(1024, alloc), .chars = Test.NodeTrackerCharList.new_with_capacity(1024, alloc), .name = "'pre-order'", .expected = "" },
        .middle = Test.NodeTracker{ .ids = Test.NodeTrackerIdList.new_with_capacity(1024, alloc), .chars = Test.NodeTrackerCharList.new_with_capacity(1024, alloc), .name = "'in-order'", .expected = "" },
        .after = Test.NodeTracker{ .ids = Test.NodeTrackerIdList.new_with_capacity(1024, alloc), .chars = Test.NodeTrackerCharList.new_with_capacity(1024, alloc), .name = "'post-order'", .expected = "" },
        .exit = Test.NodeTracker{ .ids = Test.NodeTrackerIdList.new_with_capacity(1024, alloc), .chars = Test.NodeTrackerCharList.new_with_capacity(1024, alloc), .name = "'post-order' (exit)", .expected = "" },
    };
    try Test.t.expect_equal(heirarchy.free_count, "heirarchy.free_count", 0, "0", "no items have been freed yet, but free list is not empty", .{});
    try Test.t.expect_equal(heirarchy.first_free_id, "heirarchy.first_free_id", List.NULL_ID, "NULL_ID", "no items have been freed yet, but free list is not empty", .{});
    try Test.t.expect_equal(heirarchy.first_root_id, "heirarchy.first_root_id", List.NULL_ID, "NULL_ID", "no items have been added yet, but root list is not empty", .{});
    try Test.expect.traversal_yields(&iterator, &node_trackers, heirarchy.first_root_id, "", "", "");
    var range = heirarchy.insert_many_slots_at_beginning_of_heirarchy_root(5, alloc);
    try Test.expect.traversal_yields(&iterator, &node_trackers, heirarchy.first_root_id, "\x00\x00\x00\x00\x00", "\x00\x00\x00\x00\x00", "\x00\x00\x00\x00\x00");
    var str: []const u8 = "hello";
    iterator.custom_start_iterate_depth_first_and_do_actions_on_all_items(range.first, Test.write_node_actions, @ptrCast(&str));
    try Test.expect.traversal_yields(&iterator, &node_trackers, heirarchy.first_root_id, "hello", "hello", "hello");
    range = heirarchy.insert_many_slots_at_beginning_of_left_children(heirarchy.first_root_id, 3, alloc);
    str = "123";
    iterator.custom_start_iterate_depth_first_and_do_actions_on_all_items(range.first, Test.write_node_actions, @ptrCast(&str));
    try Test.expect.traversal_yields(&iterator, &node_trackers, heirarchy.first_root_id, "h123ello", "123hello", "123hello");
    range = heirarchy.insert_many_slots_at_beginning_of_right_children(heirarchy.first_root_id, 3, alloc);
    str = "456";
    iterator.custom_start_iterate_depth_first_and_do_actions_on_all_items(range.first, Test.write_node_actions, @ptrCast(&str));
    try Test.expect.traversal_yields(&iterator, &node_trackers, heirarchy.first_root_id, "h123456ello", "123h456ello", "123456hello");
    try Test.t.expect_true(traverser.start_from(range.first), "traverser.start_from(range.first)", "failed to start from id", .{});
    try Test.t.expect_true(traverser.goto_next(), "traverser.goto_next()", "failed to move to next node", .{});
    range = heirarchy.insert_many_slots_at_beginning_of_left_children(traverser.get_current_id(), 2, alloc);
    str = "--";
    iterator.custom_start_iterate_depth_first_and_do_actions_on_all_items(range.first, Test.write_node_actions, @ptrCast(&str));
    try Test.expect.traversal_yields(&iterator, &node_trackers, heirarchy.first_root_id, "h12345--6ello", "123h4--56ello", "1234--56hello");
    range = heirarchy.insert_many_slots_at_beginning_of_right_children(traverser.get_current_id(), 2, alloc);
    str = "++";
    iterator.custom_start_iterate_depth_first_and_do_actions_on_all_items(range.first, Test.write_node_actions, @ptrCast(&str));
    try Test.expect.traversal_yields(&iterator, &node_trackers, heirarchy.first_root_id, "h12345--++6ello", "123h4--5++6ello", "1234--++56hello");
    range = heirarchy.insert_many_slots_at_beginning_of_left_children(traverser.get_current_id(), 2, alloc);
    str = "$$";
    iterator.custom_start_iterate_depth_first_and_do_actions_on_all_items(range.first, Test.write_node_actions, @ptrCast(&str));
    try Test.expect.traversal_yields(&iterator, &node_trackers, heirarchy.first_root_id, "h12345$$--++6ello", "123h4$$--5++6ello", "1234$$--++56hello");
    try Test.t.expect_equal(heirarchy.free_count, "heirarchy.free_count", 0, "0", "no items have been freed yet, but free list is not empty", .{});
    try Test.t.expect_equal(heirarchy.first_free_id, "heirarchy.first_free_id", List.NULL_ID, "NULL_ID", "no items have been freed yet, but free list is not empty", .{});
    try Test.t.expect_true(traverser.start_from(range.last), "traverser.start_from(range.last)", "failed to start from id", .{});
    const disconn_this: List.Id = traverser.get_current_id();
    try Test.t.expect_equal(traverser.goto_nth_next(2), "traverser.goto_nth_next(2)", 2, "2", "failed to move to next node", .{});
    const disconn_last: List.Id = traverser.get_current_id();
    range = heirarchy.disconnect_item_range_after(disconn_this, disconn_last);
    iterator.free_disconnected_items(range.first);
    try Test.t.expect_equal(heirarchy.free_count, "heirarchy.free_count", 2, "2", "mismatch free count", .{});
    try Test.expect.traversal_yields(&iterator, &node_trackers, heirarchy.first_root_id, "h12345$$++6ello", "123h4$$5++6ello", "1234$$++56hello");
}

pub const NodeExitKind = enum(u8) {
    EXITED_BY_HITTING_END_OF_ITERATOR,
    EXITED_BY_MOVING_TO_NEXT_SIBLING,
    EXITED_BY_RETURNING_TO_PARENT,
};

// pub const TraversalEnterKind = enum(u8) {
//     ENTERED_BY_BEGINNING_TRAVERSAL,
//     ENTERED_BY_MOVING_FROM_PREV_SIBLING,
//     ENTERED_BY_MOVING_TO_LEFT_CHILD_OF_PARENT,
//     ENTERED_BY_MOVING_TO_RIGHT_CHILD_OF_PARENT,
// };
