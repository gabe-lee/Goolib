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
const ct_assert_unreachable_err = Assert.assert_unreachable_err;
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
        allow_free_slots: bool = true,
    };
}
pub const CategoryTypeDefUnnamed = struct {
    param_type: type,
    expected_maximum_num_params: usize = 0,
    maximum_is_guaranteed: bool = false,
    allow_free_slots: bool = true,
};

// pub fn FunctionDef(comptime FUNCTIONS: type) type {
//     return struct {
//         name: FUNCTIONS,
//         /// The function signature MUST be a comptime function body with a specific format:
//         ///   - One single input with a struct type
//         ///   - One single output with a struct type
//         ///   - Each field on the input and output structs MUST have a valid target category in the ParametricStateSystem
//         func_pointer: *const fn(inputs: []const ),
//     };
// }

// pub const FunctionDefUnnamed = struct {
//     func_body: type,
//     input_struct: type,
//     output_struct: type,
// };

pub const Settings = struct {
    MASTER_ASSERT_MODE: Root.CommonTypes.AssertBehavior,
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
    /// The maximum number of unique function pointers that can be used for parameter update functions
    MAX_NUM_UNIQUE_FUNCTION_POINTERS: PowerOf2 = ._256,
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
    // /// A list of names for function definitions to be attatched to
    // comptime FUNCTION_NAMES: type,
    // /// An array of function definitions describing the function signatures
    // ///
    // /// The function signatures MUST be comptime function bodies with a specific format:
    // ///   - One single input with a struct type
    // ///   - One single output with a struct type
    // ///   - Each field on the input and output structs MUST have a valid target category in the ParametricStateSystem
    // comptime FUNCTIONS: [Types.enum_defined_field_count(FUNCTION_NAMES)]FunctionDef(FUNCTION_NAMES),
) type {
    ct_assert_with_reason(Types.type_is_enum(PARAM_CATEGORIES) and Types.all_enum_values_start_from_zero_with_no_gaps(PARAM_CATEGORIES), @src(), "type `PARAM_CATEGORIES` must be an enum type with tag values from 0 to max with no gaps, got type `{s}`", .{@typeName(PARAM_CATEGORIES)});
    // ct_assert_with_reason(Types.type_is_enum(FUNCTION_NAMES) and Types.all_enum_values_start_from_zero_with_no_gaps(FUNCTION_NAMES), @src(), "type `FUNCTION_NAMES` must be an enum type with tag values from 0 to max with no gaps, got type `{s}`", .{@typeName(FUNCTION_NAMES)});
    const __NUM_CATEGORIES = Types.enum_defined_field_count(PARAM_CATEGORIES);
    // const __NUM_FUNCTIONS = Types.enum_defined_field_count(FUNCTION_NAMES);
    const _MAX_CATEGORIES_IDX = PowerOf2.round_up_to_power_of_2(@as(usize, __NUM_CATEGORIES));
    // const _MAX_FUNCTIONS_IDX = PowerOf2.round_up_to_power_of_2(@as(usize, __NUM_FUNCTIONS));
    const idx_int = SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.unsigned_integer_type_that_holds_all_values_less_than();
    const cat_int = _MAX_CATEGORIES_IDX.unsigned_integer_type_that_holds_all_values_less_than();
    const func_idx = SETTINGS.MAX_NUM_UNIQUE_FUNCTION_POINTERS.unsigned_integer_type_that_holds_all_values_less_than();
    const func_input_count_int = SETTINGS.MAX_NUM_FUNCTION_INPUTS.unsigned_integer_type_that_holds_all_values_less_than();
    const func_output_count_int = SETTINGS.MAX_NUM_FUNCTION_OUTPUTS.unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_int = SETTINGS.MAX_NUM_UNIQUE_FUNCTION_PAYLOADS.unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_offset_int = SETTINGS.MAX_PAYLOAD_LIST_OFFSET.unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_count_int = SETTINGS.MAX_NUM_TRIGGERED_FUNCTIONS_ON_PARAM_CHANGE.unsigned_integer_type_that_holds_all_values_less_than();
    const SUBROUTINE = struct {
        fn param_cat_align_lesser(a: PARAM_CATEGORIES, b: PARAM_CATEGORIES, userdata: [__NUM_CATEGORIES]CategoryTypeDefUnnamed) bool {
            return @alignOf(userdata[@intFromEnum(a)].param_type) < @alignOf(userdata[@intFromEnum(b)].param_type);
        }
    };
    comptime var categories_defined: [__NUM_CATEGORIES]bool = @splat(false);
    comptime var ordered_category_defs: [__NUM_CATEGORIES]CategoryTypeDefUnnamed = undefined;
    comptime var ordered_category_type_sizes: [__NUM_CATEGORIES]comptime_int = undefined;
    comptime var total_static_mem_bytes: usize = 0;
    comptime var static_mem_largest_align: usize = 1;
    comptime var static_categories_ordered_by_param_align: [__NUM_CATEGORIES]PARAM_CATEGORIES = undefined;
    comptime var static_categories_ordered_by_param_align_len: usize = 0;
    inline for (PARAM_CATEGORY_DEFS[0..]) |def| {
        const cat_idx = @intFromEnum(def.category);
        ct_assert_with_reason(categories_defined[cat_idx] == false, @src(), "category `{s}` was defined more than once", .{@tagName(def.category)});
        categories_defined[cat_idx] = true;
        ct_assert_with_reason(num_cast(def.expected_maximum_num_params, u64) <= SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value(), @src(), "category `{s}` has a `.expected_maximum_num_params` ({d}) greater than the maximum possible number in any category ({d})", .{ def.expected_maximum_num_params, SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value() });
        ordered_category_defs[cat_idx] = CategoryTypeDefUnnamed{
            .param_type = def.param_type,
            .expected_maximum_num_params = def.expected_maximum_num_params,
            .maximum_is_guaranteed = def.maximum_is_guaranteed,
            .allow_free_slots = def.allow_free_slots,
        };
        ordered_category_type_sizes[cat_idx] = @sizeOf(def.param_type);
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
    const ordered_category_type_sizes_const = ordered_category_type_sizes;
    if (SETTINGS.CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES) {
        ct_assert_with_reason(SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value() >= __NUM_CATEGORIES, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, `SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value() >= _NUM_CATEGORIES` must ALSO be true, but got {d} < {d}", .{ SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value(), __NUM_CATEGORIES });
        const last_def_idx = __NUM_CATEGORIES - 1;
        const last_def_name: PARAM_CATEGORIES = @enumFromInt(last_def_idx);
        const last_def = ordered_category_defs_const[last_def_idx];
        ct_assert_with_reason(last_def.param_type == SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.unsigned_integer_type_that_holds_all_values_up_to_and_including(), @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.param_type == SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.unsigned_integer_type_that_holds_all_values_up_to_and_including()`", .{ @tagName(last_def_name), last_def_idx });
        ct_assert_with_reason(last_def.expected_maximum_num_params == last_def_idx, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.expected_maximum_num_params == Types.enum_defined_field_count(PARAM_CATEGORIES) - 1` ({d})", .{ @tagName(last_def_name), last_def_idx, last_def_idx });
        ct_assert_with_reason(last_def.maximum_is_guaranteed == true, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.maximum_is_guaranteed == true`", .{@tagName(last_def_name)});
        ct_assert_with_reason(last_def.allow_free_slots == false, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.allow_free_slots == false`", .{@tagName(last_def_name)});
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
    comptime var functions_defined: [__NUM_FUNCTIONS]bool = @splat(false);
    comptime var ordered_function_defs: [__NUM_FUNCTIONS]FunctionDefUnnamed = undefined;
    inline for (FUNCTIONS[0..]) |def| {
        const idx = @intFromEnum(def.name);
        ct_assert_with_reason(functions_defined[idx] == false, @src(), "function `{s}` was defined more than once", .{@tagName(def.name)});
        functions_defined[idx] = true;
        const INFO = @typeInfo(def.func_body);
        ct_assert_with_reason(INFO == .@"fn", @src(), "function `{s}` definition did not have a function body type, got type `{s}`", .{ @tagName(def.name), @typeName(def.func_body) });
        const FUNC = INFO.@"fn";
        ct_assert_with_reason(FUNC.is_generic == false and FUNC.is_var_args == false, @src(), "function `{s}` cannot be `.is_generic` or `.is_var_args`", .{@tagName(def.name)});
        ct_assert_with_reason(FUNC.params.len == 1 and !FUNC.params[0].is_generic and !FUNC.params[0].is_noalias and Types.type_is_struct(FUNC.params[0].type.?), @src(), "function `{s}` must have exactly one input type that is a struct type", .{@tagName(def.name)});
        const IN_STRUCT = @typeInfo(FUNC.params[0].type.?).@"struct";
        next_field: inline for (IN_STRUCT.fields) |field| {
            inline for (ordered_category_defs_const) |category| {
                if (category.param_type == field.type) continue :next_field;
            }
            ct_assert_unreachable(@src(), "function `{s}` definition input field `{s}` (type `{s}`) does not have any valid category target in the ParametricStateSystem", .{ @tagName(def.name), field.name, @typeName(field.type) });
        }
        ct_assert_with_reason(FUNC.return_type != null and Types.type_is_struct(FUNC.return_type.?), @src(), "function `{s}` must have an output type that is a struct type, got type `{s}`", .{ @tagName(def.name), @typeName(FUNC.return_type.?) });
        const OUT_STRUCT = @typeInfo(FUNC.return_type.?).@"struct";
        next_field: inline for (OUT_STRUCT.fields) |field| {
            inline for (ordered_category_defs_const) |category| {
                if (category.param_type == field.type) continue :next_field;
            }
            ct_assert_unreachable(@src(), "function `{s}` definition output field `{s}` (type `{s}`) does not have any valid category target in the ParametricStateSystem", .{ @tagName(def.name), field.name, @typeName(field.type) });
        }
        ordered_function_defs[idx] = FunctionDefUnnamed{
            .func_body = def.func_body,
            .input_struct = FUNC.params[0].type.?,
            .output_struct = FUNC.return_type.?,
        };
    }
    const ordered_function_defs_const = ordered_function_defs;
    return struct {
        const System = @This();

        var internal_state: InternalState = .{};
        var alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
        var categories: [NUM_CATEGORIES]Category = @splat(.{});
        var payloads: [NUM_FUNCTIONS]FunctionPayloads = @splat(.{});

        const NUM_CATEGORIES = INTERNAL._NUM_CATEGORIES;
        const NUM_FUNCTIONS = INTERNAL._NUM_FUNCTIONS;
        const CategoryId: type = INTERNAL._CategoryId;
        const IndexId: type = INTERNAL._IndexId;
        const FuncId: type = INTERNAL._FuncId;
        const PayloadId: type = INTERNAL._PayloadId;
        const PayloadOffset: type = INTERNAL._PayloadOffset;
        const PayloadCount: type = INTERNAL._PayloadTriggerCount;
        const PayloadDataLocation = INTERNAL._PayloadDataLocation;
        const CATEGORY_DEFS = INTERNAL._CATEGORY_DEFS;
        const FUNCTION_DEFS = INTERNAL._FUNCTION_DEFS;
        const OpaqueTriggerFunc = INTERNAL._OpaqueTriggerFunc;
        const InternalState = INTERNAL._InternalState;
        const STATIC_MEM_LEN = INTERNAL._STATIC_MEM_LEN;
        const STATIC_MEM_ALIGN = INTERNAL._STATIC_MEM_ALIGN;
        const STATIC_FUNC_COUNT = INTERNAL._STATIC_FUNC_COUNT;
        const FUNC_COUNT_IS_STATIC = INTERNAL._FUNC_COUNT_IS_STATIC;
        const STATIC_MEM_STARTS = INTERNAL._STATIC_MEM_STARTS;
        const Category = INTERNAL._Category;
        const FunctionPayloads = INTERNAL._FunctionPayloads;
        const ParamOpaque = INTERNAL._ParamOpaque;
        const FunctionName = INTERNAL._FunctionName;
        const CategoryName = INTERNAL._CategoryName;

        const _Assert = Assert.AssertHandler(SETTINGS.MASTER_ASSERT_MODE);
        const assert_with_reason = _Assert._with_reason;
        const assert_unreachable = _Assert._unreachable;
        const assert_unreachable_err = _Assert._unreachable_err;
        const assert_index_in_range = _Assert._index_in_range;
        const assert_allocation_failure = _Assert._allocation_failure;

        pub fn ParamReadWrite(comptime T: type) type {
            return packed struct {
                const ParamSelf = @This();
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
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
        pub const ParamReadWriteOpaque = packed struct {
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            category: CategoryId,
            index: IndexId,

            pub fn with_type(self: ParamReadWriteOpaque, comptime T: type) ParamReadWrite(T) {
                assert_with_reason(CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{@tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(CATEGORY_DEFS[self.category].param_type), @typeName(T)});
                return @bitCast(self);
            }
        };
        pub fn ParamReadOnly(comptime T: type) type {
            return packed struct {
                const ParamSelf = @This();
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                category: CategoryId,
                index: IndexId,

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
        pub const ParamReadOnlyOpaque = packed struct {
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            category: CategoryId,
            index: IndexId,

            pub fn with_type(self: ParamReadOnlyOpaque, comptime T: type) ParamReadOnly(T) {
                assert_with_reason(CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{@tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(CATEGORY_DEFS[self.category].param_type), @typeName(T)});
                return @bitCast(self);
            }
        };
        const PayloadShim = INTERNAL.in_out_type;

        pub const INTERNAL = struct {
            pub const _CategoryId: type = cat_int;
            pub const _IndexId: type = idx_int;
            
            pub const _PayloadIndex = packed struct {
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                function: _FuncId,
                index: _PayloadId,

                pub fn get_payload_shim(comptime self: _PayloadIndex) PayloadShim(@enumFromInt(self.function)) {
                    const name: FunctionName = @enumFromInt(self.function);
                    return payloads[self.function].payloads.get_shim(name, self.index);
                }
                pub fn get_payload_shim_runtime(self: _PayloadIndex, comptime FUNC_NAME: FunctionName) PayloadShim(FUNC_NAME) {
                    assert_with_reason(@intFromEnum(name) == self.function, @src(), "_: []const u8", _: anytype)
                    return payloads[self.function].payloads.get_shim(name, self.index);
                }
            };

            pub const _PayloadFree: type = std.meta.Int(.unsigned, @min(32, (@typeInfo(CategoryId).int.bits + @typeInfo(IndexId).int.bits) * 2));
            pub const _PayloadFreeBytes = @sizeOf(_PayloadFree);
            pub const _FunctionName = FUNCTION_NAMES;
            pub const _CategoryName = PARAM_CATEGORIES;
            pub const _FuncId: type = func_idx;
            pub const _PayloadId: type = func_payload_int;
            pub const _PayloadOffset: type = func_payload_offset_int;
            pub const _PayloadTriggerCount: type = func_payload_count_int;
            pub const _PayloadInCount: type = func_input_count_int;
            pub const _PayloadOutCount: type = func_output_count_int;
            pub const _PayloadDataLocation = packed struct {
                offset: _PayloadOffset,
                in_count: _PayloadInCount,
                out_count: _PayloadOutCount,
            };
            pub const _CATEGORY_DEFS = ordered_category_defs_const;
            pub const _CATEGORY_TYPE_SIZES = ordered_category_type_sizes_const;
            pub const _FUNCTION_DEFS = ordered_function_defs_const;
            pub const _NUM_CATEGORIES = __NUM_CATEGORIES;
            pub const _NUM_FUNCTIONS = __NUM_FUNCTIONS;
            pub const _STATIC_MEM_LEN = total_static_mem_bytes;
            pub const _STATIC_MEM_ALIGN = static_mem_largest_align_const;
            // pub const _OpaqueTriggerFunc = fn (self: *System, inputs: []const ParamId, outputs: []const ParamId) void;
            pub const _FUNC_COUNT_IS_STATIC = SETTINGS.COMPTIME_KNOWN_NUM_UNIQUE_FUNCTIONS != null;
            pub const _STATIC_FUNC_COUNT = if (SETTINGS.COMPTIME_KNOWN_NUM_UNIQUE_FUNCTIONS) |n| n else 0;
            pub const _STATIC_MEM_STARTS = static_category_mem_starts_const;
            pub const _InternalState = struct {
                // func_pointers_static_mem: [STATIC_FUNC_COUNT]*const OpaqueTriggerFunc = undefined,
                static_memory: [STATIC_MEM_LEN]u8 align(STATIC_MEM_ALIGN) = undefined,
            };
            pub const _Category = struct {
                data: OpaqueList = .{},
                frees: BitList = .{},
            };
            pub const _FunctionPayloads = struct {
                payloads: _PayloadList = .{},
            };
            pub const _FunctionInShims: [NUM_FUNCTIONS]type = build: {
                var out: [NUM_FUNCTIONS]type = undefined;
                for (FUNCTION_DEFS[0..], 0..) |def, i| {
                    var IN_SHIM = @typeInfo(def.input_struct).@"struct";
                    for (IN_SHIM.fields, 0..) |field, f| {
                        const T = field.type;
                        const P = ParamReadOnly(T);
                        IN_SHIM.fields[f] = std.builtin.Type.StructField{
                            .alignment = @alignOf(P),
                            .default_value_ptr = null,
                            .is_comptime = false,
                            .name = field.name,
                            .type = P,
                        };
                    }
                    out[i] = @Type(IN_SHIM);
                }
                break :build out;
            };
            pub const _FunctionOutShims: [NUM_FUNCTIONS]type = build: {
                var out: [NUM_FUNCTIONS]type = undefined;
                for (FUNCTION_DEFS[0..], 0..) |def, i| {
                    var OUT_SHIM = @typeInfo(def.output_struct).@"struct";
                    for (OUT_SHIM.fields, 0..) |field, f| {
                        const T = field.type;
                        const P = ParamReadOnly(T);
                        OUT_SHIM.fields[f] = std.builtin.Type.StructField{
                            .alignment = @alignOf(P),
                            .default_value_ptr = null,
                            .is_comptime = false,
                            .name = field.name,
                            .type = P,
                        };
                    }
                    out[i] = @Type(OUT_SHIM);
                }
                break :build out;
            };

            pub const _FunctionOutShimOffsets: [NUM_FUNCTIONS]comptime_int = build: {
                var out: [NUM_FUNCTIONS]comptime_int = undefined;
                for (_FunctionInShims[0..], 0..) |shim_in, i| {
                    const offset = @sizeOf(shim_in);
                    out[i] = offset;
                }
                break :build out;
            };

            const InOutTypes = struct {
                input: type,
                output: type,
            };

            pub const _FuncShimPackages: [NUM_FUNCTIONS]InOutTypes = build: {
                var out: [NUM_FUNCTIONS]InOutTypes = undefined;
                for (_FunctionInShims[0..], _FunctionOutShims[0..], 0..) |shim_in, shim_out, i| {
                    out[i] = InOutTypes{
                        .input = shim_in,
                        .output = shim_out,
                    };
                }
                break :build out;
            };

            pub const _FunctionInOutShimStrides: [NUM_FUNCTIONS]comptime_int = build: {
                var out: [NUM_FUNCTIONS]comptime_int = undefined;
                for (_FuncShimPackages[0..], 0..) |shim, i| {
                    const size = @sizeOf(shim);
                    out[i] = size;
                }
                break :build out;
            };
            pub const _FunctionInOutShimCounts: [NUM_FUNCTIONS]usize = build: {
                var out: [NUM_FUNCTIONS]usize = undefined;
                for (_FuncShimPackages[0..], 0..) |shim, i| {
                    const count = @typeInfo(shim.input).@"struct".fields.len + @typeInfo(shim.output).@"struct".fields.len;
                    out[i] = count;
                }
                break :build out;
            };

            pub fn in_out_type(comptime FUNC_NAME: FunctionName) type {
                const idx = @intFromEnum(FUNC_NAME);
                const Ts = _FuncShimPackages[idx];
                return struct {
                    input: Ts.input,
                    output: Ts.output,
                };
            }

            pub fn in_out_mult(FUNC_NAME: FunctionName) usize {
                const idx = @intFromEnum(FUNC_NAME);
                return _FunctionInOutShimCounts[idx];
            }

            pub const _PayloadList = struct {
                ptr: [*]ParamOpaque = Utils.invalid_ptr_many(ParamOpaque),
                len: _PayloadId = 0,
                cap: _PayloadId = 0,
                num_free: _PayloadId = 0,
                next_free: _PayloadFree = 0,

                pub fn ensure_free_space(self: *_PayloadList, mult: usize, _payloads: usize, _alloc: Allocator) void {
                    const real_num = mult * _payloads;
                    if (real_num > num_cast(self.cap, usize)) {
                        const new_mem = Utils.Alloc.realloc_custom(_alloc, self.ptr, real_num, .ALIGN_TO_TYPE, .COPY_EXISTING_DATA, .dont_memset_new(), .dont_memset_old()) catch |err| ct_assert_unreachable_err(@src(), err);
                        self.ptr = new_mem.ptr;
                        self.cap = @intCast(new_mem.len);
                    }
                }

                pub fn get_shim(self: *const _PayloadList, comptime FUNC_NAME: FunctionName, index: _PayloadId) PayloadShim(FUNC_NAME) {
                    const mult = in_out_mult(FUNC_NAME);
                    const INOUT = in_out_type(FUNC_NAME);
                    const real_idx = mult * num_cast(index, usize);
                    const ptr: [*]ParamOpaque = self.ptr + real_idx;
                    const ptr_typed: *INOUT = @ptrCast(ptr);
                    return ptr_typed.*;
                }

                pub fn add_payload(self: *_PayloadList, FUNC_NAME: FunctionName, payload: in_out_type(FUNC_NAME), _alloc: Allocator) usize {
                    const mult = in_out_mult(FUNC_NAME);
                    const INOUT = in_out_type(FUNC_NAME);
                    if (self.num_free > 0) {
                        const next_free: usize = @intCast(self.next_free);
                        const real_idx = mult * next_free;
                        const next_free_ptr: *ParamOpaque = &self.ptr[real_idx];
                        const next_free_addr = @intFromPtr(next_free_ptr);
                        const next_free_bytes: *[_PayloadFreeBytes]u8 = @ptrFromInt(next_free_addr);
                        const next_next_free: _PayloadFree = std.mem.readInt(_PayloadFree, next_free_bytes, Root.CommonTypes.Endian.NATIVE.to_zig());
                        self.next_free = next_next_free;
                        self.num_free -= 1;
                        const ptr: [*]ParamOpaque = self.ptr + real_idx;
                        const ptr_typed: *INOUT = @ptrCast(ptr);
                        ptr_typed.* = payload;
                        return next_free;
                    } else {
                        const idx = self.len;
                        self.ensure_free_space(mult, self.len + 1, _alloc);
                        const real_idx = mult * self.len;
                        const ptr: [*]ParamOpaque = self.ptr + real_idx;
                        const ptr_typed: *INOUT = @ptrCast(ptr);
                        ptr_typed.* = payload;
                        self.len += 1;
                        return idx;
                    }
                }
                pub fn free_payload(self: *_PayloadList, FUNC_NAME: FunctionName, payload_idx: usize) void {
                    const mult = in_out_mult(FUNC_NAME);
                    const next_free_cast: _PayloadFree = @intCast(payload_idx);
                    const real_idx = mult * payload_idx;
                    const next_free_ptr: *ParamOpaque = &self.ptr[real_idx];
                    const next_free_addr = @intFromPtr(next_free_ptr);
                    const next_free_bytes: *[_PayloadFreeBytes]u8 = @ptrFromInt(next_free_addr);
                    std.mem.writeInt(_PayloadFree, next_free_bytes, next_free_cast, Root.CommonTypes.Endian.NATIVE.to_zig());
                    self.next_free = next_free_cast;
                    self.num_free += 1;
                }
            };
        };
    };
}
