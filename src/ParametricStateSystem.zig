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
const math = std.math;
const Root = @import("./_root.zig");
const SliceAdapter = Root.IList_SliceAdapter;
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Flags = Root.Flags;
const IList = Root.IList.IList;
const List = Root.IList_List.List;
const Range = Root.IList.Range;
const MathX = Root.Math;
const PowerOf2 = MathX.PowerOf2;
const InterfaceSignature = Types.InterfaceSignature;
const NamedFuncDefinition = Types.NamedFuncDefinition;

const ct_assert_with_reason = Assert.assert_with_reason;
const ct_assert_unreachable = Assert.assert_unreachable;
const ct_assert_allocation_failure = Assert.assert_allocation_failure;
const ct_assert_field_is_type = Assert.assert_field_is_type;

const num_cast = Root.Cast.num_cast;

const List8 = List(u8);
const List16 = List(u16);
const List32 = List(u32);
const List64 = List(u64);
const List128 = List(u128);
const ListPtr = List(?*anyopaque);

const OpaqueList = List(anyopaque);
const BitList = Root.BitList.BitList(1);

pub fn CategoryTypeDef(comptime CATEGORIES: type) type {
    return struct {
        category: CATEGORIES,
        param_type: type,
        expected_maximum_num_params: usize,
        maximum_is_guaranteed: bool = false,
        allow_free_slots: bool = false,
    };
}
pub const CategoryTypeDefUnamed = struct {
    param_type: type,
    expected_maximum_num_params: usize = 0,
    maximum_is_guaranteed: bool = false,
    allow_free_slots: bool = false,
};

pub const Settings = struct {
    /// The maximum number of categories
    ///
    /// Each category represents a contiguous list of elements of the same type
    MAX_NUM_CATEGORIES: PowerOf2 = ._256,
    /// The maximum number of values any one category can have
    MAX_NUM_VALUES_IN_ANY_CATEGORY: PowerOf2 = ._65_536,
    /// If true, the largest category index is enforced to be a meta category where each parameter index
    /// holds the *length* of the parameter list for the matching category index. These parameter values will autoamtically be updated
    /// by the ParametricStateSystem when the category parameter list grows or shrinks in size, and they can be used/reference
    /// by other parameters for use in their calulations.
    ///
    /// Using this feature enforces the following conditions:
    ///   - `MAX_NUM_VALUES_IN_ANY_CATEGORY` must be >= `MAX_NUM_CATEGORIES`
    ///   - The category definition for the largest-valued category enum tag MUST be:
    /// ```zig
    /// .{
    ///     .category: <ENUM TAG WITH LARGEST VALUE>,
    ///     .param_type = MAX_NUM_VALUES_IN_ANY_CATEGORY.unsigned_integer_type_that_holds_all_values_up_to_and_including(),
    ///     .expected_maximum_num_params = Types.enum_defined_field_count(PARAM_CATEGORIES) - 1,
    ///     .maximum_is_guaranteed = true,
    ///     .allow_free_slots = false,
    /// }
    /// ```
    CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES: bool = false,
    /// The maximum number of unique function (pointers) that
    /// can be used to automatically calculate parameters
    MAX_NUM_UNIQUE_FUNCTIONS: PowerOf2 = ._256,
    /// The exact number of unique functions, if known at comptime
    COMPTIME_KNOWN_NUM_UNIQUE_FUNCTIONS: ?usize = null,
    /// The maximum number of unique function payloads (input+output sets)
    /// across all functions.
    ///
    /// A safe value to choose is the maximum number of derivative parameters you
    /// expect to have in the entire table (one unique payload per derivative param),
    /// but it may be much lower if many of your functions have more than one output.
    MAX_NUM_UNIQUE_FUNCTION_PAYLOADS: PowerOf2 = ._65_536,
    /// The maximum number of functions that can trigger when a parameter changes
    ///
    /// This also affects the number of derivative parameters a single parameter can have,
    /// but a single triggered function can update more than one derivative parameter at a time
    MAX_NUM_TRIGGERED_FUNCTIONS_ON_PARAM_CHANGE: PowerOf2 = ._256,
    /// The maximum number of inputs a function can have
    MAX_NUM_FUNCTION_INPUTS: PowerOf2 = ._16,
    /// The maximum number of outputs a function can have
    MAX_NUM_FUNCTION_OUTPUTS: PowerOf2 = ._16,
    /// This may be a tough limit to define, but a safe upper bound is:
    /// ```
    /// PowerOf2.round_up_to_power_of_2(MAX_NUM_UNIQUE_FUNCTION_PAYLOADS.value() * (MAX_NUM_FUNCTION_INPUTS.value() + MAX_NUM_FUNCTION_OUTPUTS.value()))
    /// ```
    MAX_PAYLOAD_LIST_OFFSET: PowerOf2 = ._2_097_152,
};
pub fn ParametricStateSystem(
    /// Settings that affect some internal functionality
    comptime SETTINGS: Settings,
    /// An enum type with a tag for each parameter category.
    ///
    /// A parameter category holds elements of a single type in a single contiguous memory slice/region
    ///
    /// If a category runs out of space and must be reallocated, all items within that category must be copied
    ///
    /// The number of tags MUST be <= the value of `SETTINGS.MAX_NUM_CATEGORIES`, and all tag values must increase from 0 to max with no gaps
    comptime PARAM_CATEGORIES: type,
    /// An array of parameter definitions for each enum entry in `PARAM_CATEGORIES`
    comptime PARAM_CATEGORY_DEFS: [Types.enum_defined_field_count(PARAM_CATEGORIES)]CategoryTypeDef(PARAM_CATEGORIES),
) type {
    ct_assert_with_reason(Types.type_is_enum(PARAM_CATEGORIES) and Types.all_enum_values_start_from_zero_with_no_gaps(PARAM_CATEGORIES), @src(), "type `PARAM_CATEGORIES` must be an enum type with tag values from 0 to max with no gaps, got type `{s}`", .{@typeName(PARAM_CATEGORIES)});
    ct_assert_with_reason(Types.enum_max_value(PARAM_CATEGORIES) < SETTINGS.MAX_NUM_CATEGORIES.value(), @src(), "enum `PARAM_CATEGORIES` must have a maximum tag value less than {d} (from `SETTINGS.MAX_NUM_VALUES_IN_CATEGORY`)", .{SETTINGS.MAX_NUM_CATEGORIES.value()});
    const _NUM_CATEGORIES = Types.enum_defined_field_count(PARAM_CATEGORIES);
    const idx_int = SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.unsigned_integer_type_that_holds_all_values_less_than();
    const cat_int = SETTINGS.MAX_NUM_CATEGORIES.unsigned_integer_type_that_holds_all_values_less_than();
    // const total_id_bits = @typeInfo(cat_int).int.bits + @typeInfo(idx_int).int.bits;
    // const id_int = std.meta.Int(.unsigned, @intCast(total_id_bits));
    // const id_idx_mask: id_int = math.maxInt(idx_int);
    // const id_cat_shift: math.Log2Int(id_int) = @intCast(@typeInfo(idx_int).int.bits);
    const func_idx = SETTINGS.MAX_NUM_UNIQUE_FUNCTIONS.unsigned_integer_type_that_holds_all_values_less_than();
    const func_input_count_int = SETTINGS.MAX_NUM_FUNCTION_INPUTS.unsigned_integer_type_that_holds_all_values_less_than();
    const func_output_count_int = SETTINGS.MAX_NUM_FUNCTION_OUTPUTS.unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_int = SETTINGS.MAX_NUM_UNIQUE_FUNCTION_PAYLOADS.unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_offset_int = SETTINGS.MAX_PAYLOAD_LIST_OFFSET.unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_count_int = SETTINGS.MAX_NUM_TRIGGERED_FUNCTIONS_ON_PARAM_CHANGE.unsigned_integer_type_that_holds_all_values_less_than();
    const SUBROUTINE = struct {
        fn param_cat_align_lesser(a: PARAM_CATEGORIES, b: PARAM_CATEGORIES, userdata: [_NUM_CATEGORIES]CategoryTypeDefUnamed) bool {
            return @alignOf(userdata[@intFromEnum(a)].param_type) < @alignOf(userdata[@intFromEnum(b)].param_type);
        }
    };
    comptime var categories_defined: [_NUM_CATEGORIES]bool = @splat(false);
    comptime var ordered_category_defs: [_NUM_CATEGORIES]CategoryTypeDefUnamed = undefined;
    comptime var total_static_mem_bytes: usize = 0;
    comptime var static_mem_largest_align: usize = 1;
    comptime var static_categories_ordered_by_param_align: [_NUM_CATEGORIES]PARAM_CATEGORIES = undefined;
    comptime var static_categories_ordered_by_param_align_len: usize = 0;
    inline for (PARAM_CATEGORY_DEFS[0..]) |def| {
        const cat_idx = @intFromEnum(def.category);
        ct_assert_with_reason(categories_defined[cat_idx] == false, @src(), "category `{s}` was defined more than once", .{@tagName(def.category)});
        categories_defined[cat_idx] = true;
        ct_assert_with_reason(num_cast(def.expected_maximum_num_params, u64) <= SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value(), @src(), "category `{s}` has a `.expected_maximum_num_params` ({d}) greater than the maximum possible number in any category ({d})", .{ def.expected_maximum_num_params, SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value() });
        ordered_category_defs[cat_idx] = CategoryTypeDefUnamed{
            .param_type = def.param_type,
            .expected_maximum_num_params = def.expected_maximum_num_params,
            .maximum_is_guaranteed = def.maximum_is_guaranteed,
        };
        if (def.maximum_is_guaranteed) {
            total_static_mem_bytes += def.expected_maximum_num_params * @sizeOf(def.param_type);
            static_mem_largest_align = @max(static_mem_largest_align, @alignOf(def.param_type));
            static_categories_ordered_by_param_align[static_categories_ordered_by_param_align_len] = def.category;
            static_categories_ordered_by_param_align_len += 1;
        }
    }
    if (static_categories_ordered_by_param_align_len > 0) {
        Utils.mem_sort(@ptrCast(&static_categories_ordered_by_param_align), 0, static_categories_ordered_by_param_align_len, ordered_category_defs, SUBROUTINE.param_cat_align_lesser);
    }
    const static_mem_largest_align_const = static_mem_largest_align;
    const ordered_category_defs_const = ordered_category_defs;
    if (SETTINGS.CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES) {
        ct_assert_with_reason(SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.bit_shift() >= SETTINGS.MAX_NUM_CATEGORIES.bit_shift(), @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, `SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.num_bits() >= SETTINGS.MAX_NUM_CATEGORIES.num_bits()` must ALSO be true, but got {d} < {d}", .{ SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.num_bits(), SETTINGS.MAX_NUM_CATEGORIES.num_bits() });

        const last_def_idx = _NUM_CATEGORIES - 1;
        const last_def_name: PARAM_CATEGORIES = @enumFromInt(last_def_idx);
        const last_def = ordered_category_defs_const[last_def_idx];
        ct_assert_with_reason(last_def.param_type == SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.unsigned_integer_type_that_holds_all_values_up_to_and_including(), @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.param_type == SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.unsigned_integer_type_that_holds_all_values_up_to_and_including()`", .{ @tagName(last_def_name), last_def_idx });
        ct_assert_with_reason(last_def.expected_maximum_num_params == last_def_idx, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.expected_maximum_num_params == Types.enum_defined_field_count(PARAM_CATEGORIES) - 1` ({d})", .{ @tagName(last_def_name), last_def_idx, last_def_idx });
        ct_assert_with_reason(last_def.maximum_is_guaranteed == true, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.maximum_is_guaranteed == true` ({d})", .{ @tagName(last_def_name), last_def_idx });
    }
    const static_categories_ordered_by_param_align_len_const = static_categories_ordered_by_param_align_len;
    const static_categories_ordered_by_param_align_const: [static_categories_ordered_by_param_align_len_const]PARAM_CATEGORIES = make: {
        var out: [static_categories_ordered_by_param_align_len_const]PARAM_CATEGORIES = undefined;
        @memcpy(out[0..static_categories_ordered_by_param_align_len_const], static_categories_ordered_by_param_align[0..static_categories_ordered_by_param_align_len_const]);
        break :make out;
    };
    comptime var static_category_mem_starts: [static_categories_ordered_by_param_align_len_const + 1]usize = undefined;
    comptime var static_category_mem_starts_current_start: usize = 0;
    if (static_categories_ordered_by_param_align_len > 0) {
        inline for (static_categories_ordered_by_param_align_const[0..], 0..) |cat, i| {
            const cat_idx = @intFromEnum(cat);
            const mem_size = @sizeOf(ordered_category_defs_const[cat_idx].param_type) * ordered_category_defs_const[cat_idx].expected_maximum_num_params;
            static_category_mem_starts[i] = static_category_mem_starts_current_start;
            static_category_mem_starts_current_start += mem_size;
        }
        static_category_mem_starts[static_categories_ordered_by_param_align_len_const] = static_category_mem_starts_current_start;
    }
    const static_category_mem_starts_const = static_category_mem_starts;
    return struct {
        const System = @This();

        var internal_state: InternalState = .{};
        var alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
        var categories: [NUM_CATEGORIES]Category = @splat(.{});
        var funcs: List(*const OpaqueTriggerFunc) = .{};

        const NUM_CATEGORIES = _NUM_CATEGORIES;
        const CategoryId: type = INTERNAL._CategoryId;
        const IndexId: type = INTERNAL._IndexId;
        const FuncId: type = INTERNAL._FuncId;
        const PayloadId: type = INTERNAL._PayloadId;
        const PayloadOffset: type = INTERNAL._PayloadOffset;
        const PayloadCount: type = INTERNAL._PayloadCount;
        const PayloadDataLocation = INTERNAL._PayloadDataLocation;
        const CATEGORY_DEFS = INTERNAL._CATEGORY_DEFS;
        const OpaqueTriggerFunc = INTERNAL._OpaqueTriggerFunc;
        const InternalState = INTERNAL._InternalState;
        const STATIC_MEM_LEN = INTERNAL._STATIC_MEM_LEN;
        const STATIC_MEM_ALIGN = INTERNAL._STATIC_MEM_ALIGN;
        const STATIC_FUNC_COUNT = INTERNAL._STATIC_FUNC_COUNT;
        const FUNC_COUNT_IS_STATIC = INTERNAL._FUNC_COUNT_IS_STATIC;
        const STATIC_MEM_STARTS = INTERNAL._STATIC_MEM_STARTS;
        const Category = INTERNAL._Category;

        pub fn RootParam(comptime T: type) type {
            return packed struct {
                const ParamSelf = @This();

                category: CategoryId,
                index: IndexId,

                pub fn set(comptime self: ParamSelf, val: T) void {
                    const list_opaque = categories[self.category].data;
                    const list_typed = List(T){
                        .ptr = @ptrCast(@alignCast(list_opaque.ptr)),
                        .len = list_opaque.len,
                        .cap = list_opaque.cap,
                    };
                    list_typed.ptr[self.index] = val;
                }

                pub fn get(self: ParamSelf) T {
                    const list_opaque = categories[self.category].data;
                    const list_typed = List(T){
                        .ptr = @ptrCast(@alignCast(list_opaque.ptr)),
                        .len = list_opaque.len,
                        .cap = list_opaque.cap,
                    };
                    return list_typed.ptr[self.index];
                }
            };
        }
        pub fn DerivedParam(comptime T: type) type {
            return packed struct {
                const ParamSelf = @This();

                category: CategoryId,
                index: IndexId,

                pub const _INTERNAL = struct {
                    pub fn unsafe_set(self: ParamSelf, val: T) void {
                        const list_opaque = categories[self.category].data;
                        const list_typed = List(T){
                            .ptr = @ptrCast(@alignCast(list_opaque.ptr)),
                            .len = list_opaque.len,
                            .cap = list_opaque.cap,
                        };
                        list_typed.ptr[self.index] = val;
                    }

                    pub fn as_root(self: ParamSelf) RootParam(T) {
                        return RootParam(T){
                            .category = self.category,
                            .index = self.index,
                        };
                    }
                };

                fn set(comptime self: ParamSelf, val: T) void {
                    const list_opaque = categories[self.category].data;
                    const list_typed = List(T){
                        .ptr = @ptrCast(@alignCast(list_opaque.ptr)),
                        .len = list_opaque.len,
                        .cap = list_opaque.cap,
                    };
                    list_typed.ptr[self.index] = val;
                }

                pub fn get(self: ParamSelf) T {
                    const list_opaque = categories[self.category].data;
                    const list_typed = List(T){
                        .ptr = @ptrCast(@alignCast(list_opaque.ptr)),
                        .len = list_opaque.len,
                        .cap = list_opaque.cap,
                    };
                    return list_typed.ptr[self.index];
                }
            };
        }

        pub const INTERNAL = struct {
            pub const _CategoryId: type = cat_int;
            pub const _IndexId: type = idx_int;

            pub const _FuncId: type = func_idx;
            pub const _PayloadId: type = func_payload_int;
            pub const _PayloadOffset: type = func_payload_offset_int;
            pub const _PayloadCount: type = func_payload_count_int;
            pub const _PayloadInCount: type = func_input_count_int;
            pub const _PayloadOutCount: type = func_output_count_int;
            pub const _PayloadDataLocation = packed struct {
                offset: _PayloadOffset,
                in_count: _PayloadInCount,
                out_count: _PayloadOutCount,
            };
            pub const _CATEGORY_DEFS = ordered_category_defs_const;
            pub const _STATIC_MEM_LEN = total_static_mem_bytes;
            pub const _STATIC_MEM_ALIGN = static_mem_largest_align_const;
            pub const _OpaqueTriggerFunc = fn (self: *System, inputs: []const ParamId, outputs: []const ParamId) void;
            pub const _FUNC_COUNT_IS_STATIC = SETTINGS.COMPTIME_KNOWN_NUM_UNIQUE_FUNCTIONS != null;
            pub const _STATIC_FUNC_COUNT = if (SETTINGS.COMPTIME_KNOWN_NUM_UNIQUE_FUNCTIONS) |n| n else 0;
            pub const _STATIC_MEM_STARTS = static_category_mem_starts_const;
            pub const _InternalState = struct {
                func_pointers_static_mem: [STATIC_FUNC_COUNT]*const OpaqueTriggerFunc = undefined,
                static_memory: [STATIC_MEM_LEN]u8 align(STATIC_MEM_ALIGN) = undefined,
            };
            pub const _Category = struct {
                data: OpaqueList = .{},
                frees: BitList = .{},
                roots: BitList = .{},
            };
        };
    };
}
