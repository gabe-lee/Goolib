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
const SimplePool = Root.Pool.Simple.SimplePool;
const SimplePoolOpaque = Root.Pool.Simple.SimplePoolOpaque;
const UniqueQueue = Root.UniqueQueue.UniqueQueue;
const UniqueQueueModule = Root.UniqueQueue;
const Mutex = std.Thread.Mutex;
const KeyedMutex = Root.KeyedMutex.KeyedMutex;
const EnumeratedDefinitions = Utils.EnumeratedDefs.EnumeratedDefinitions;

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
const BitListModule = Root.BitList;
const FreeList = BitListModule.FreeBitList;
const BoolList = BitListModule.BoolList;

pub const AlwaysUpdateMode = enum(u8) {
    ONLY_UPDATE_ON_VALUE_CHANGE,
    ALWAYS_UPDATE_EVEN_IF_VALUE_UNCHANGED,
};

pub const ParentDeleteMode = enum(u8) {
    DELETE_WHEN_PARENT_IS_DELETED,
    DEFAULT_VALUE_WHEN_PARENT_IS_DELETED,
};

// pub const ParamFlags = Flags.Flags(enum(u2) {
//     ALWAYS_UPDATE = 1 << 0,
//     DEFAULT_WHEN_PARENT_DELETE = 1 << 1,
// }, enum(u2) {});

// pub const ParamFlagsList = BitListModule.BitList(2, ParamFlags);

pub fn CategoryTypeDef(comptime CATEGORIES: type) type {
    return struct {
        category: CATEGORIES,
        param_type: type,
        expected_maximum_num_params: usize,
        maximum_is_guaranteed: bool = false,
        allow_free_slots: bool = true,
        default_value_for_type: ?*const anyopaque,
        /// MUST be a function pointer in the form `fn(a: param_type, b: param_type) bool`
        /// that returns `true` when the values are equal, `false` otherwise
        type_equality_func: *const anyopaque,
    };
}
pub const CategoryTypeDefUnnamed = struct {
    param_type: type,
    expected_maximum_num_params: usize = 0,
    maximum_is_guaranteed: bool = false,
    allow_free_slots: bool = true,
    default_value_for_type: ?*const anyopaque,
    /// MUST be a function pointer in the form `fn(a: param_type, b: param_type) bool`
    /// that returns `true` when the values are equal, `false` otherwise
    type_equality_func: *const anyopaque,
};

pub fn ParamDefList(comptime PARAM_CATEGORIES: type) type {
    return EnumeratedDefinitions(PARAM_CATEGORIES, CategoryTypeDef(PARAM_CATEGORIES), "category", CategoryTypeDefUnnamed);
}

pub const GenerationMode = enum(u8) {
    NO_INDEX_GENERATIONS,
    PER_PARAMETER_INDEX_GENERATION_INT_POWER,
};

pub const GenerationSetting = union(GenerationMode) {
    NO_INDEX_GENERATIONS,
    PER_PARAMETER_INDEX_GENERATION_INT_POWER: PowerOf2,
};

pub const Settings = struct {
    /// How to handle assertions in internal functions
    MASTER_ASSERT_MODE: Root.CommonTypes.AssertBehavior,
    /// How to handle detected recursion (if `ALLOWED_RECURSIVE_UPDATES` is 0)
    RECURSION_ASSERT_MODE: Root.CommonTypes.AssertBehavior,
    /// If `true` all access functions will first lock a global mutex on the `ParametricStateSystem`,
    /// then unlock it when done.
    ///
    /// Because the option to allow parameter update recursion exists, it is extremely hard to define what parameters update what other parameters as part of their heirarchy,
    /// (which would allow more granular thread safety and less resource contention if possible),
    /// one single global mutex is used to lock and unlock the entire system when a parameter is accessed.
    ///
    /// This may cause resource contention for heavy throughput from multiple threads, but is better than
    /// either of the alternatives:
    ///   - NO thread safety resulting in race conditions and undefined behaviour
    ///   - A (possibly poorly designed) complex mutex heirarchy tree, which will require a large amount of extra memory and has the possiblility for deadlocks
    ENABLE_THREAD_SAFETY: bool = false,
    /// If set to true, you can delete an update function that has been initialized.
    ALLOW_FUNCTION_DELETION: bool = false,
    /// If set to true, you can replace an existing function with a new one,
    /// causing all dependant parameters to also be updated.
    ALLOW_FUNCTION_REPLACEMENT: bool = false,
    /// If set to true, when an update function is deleted, all parameters that depended on it will be deleted as well
    DELETE_DEPENDANT_PARAMETERS_WHEN_FUNCTION_DELETED: bool = true,
    /// Whether or not to include index 'generations' on parameter handles.
    ///
    /// An index generation is a way to differentiate two different values that may accidentally
    /// have the same category and index. For example, you create parameter 'A' in category 'Stuff' and it is assigned to index 0,
    /// and some part of your code saves the returned parameter handle.
    ///
    /// Later, you delete Parameter 'A' but either forget to or cannot (due to technical constraints) update the saved parameter handle you
    /// previously got.
    ///
    /// Now your code has a parameter handle to an invalid 'freed' value (but that can be checked against the free bit list)
    ///
    /// After that you create parameter 'B' in category 'Stuff'. Paramter 'B' is unrelated
    /// to parameter 'A', but it is also assigned to the new free slot at index 0.
    ///
    /// Now your code has a 'valid' param handle referencing a no-longer-valid parameter 'A', which
    /// actually has the value of parameter 'B', causing very difficult to debug behavior in your program.
    ///
    /// Index generations attach a counter to the parameter handle and also within the category itself for each
    /// parameter. When you delete a parameter the counter on the category parameter slot is incremented by 1.
    /// When you attempt to get or set a parameter using the parameter handle, the program asserts that the generation
    /// on the handle and the generation on the category data slot match. If they dont, it indicates that you are accessing
    /// an invalid parameter even if valid data exists there.
    ///
    /// Generations wrap around to 0 when they reach their max value, which does still allow possible scenarios where the generations
    /// match again, but the chances of it happening can be greatly reduced (or nullified) by using a larger PowerOf2 for the generation integer type
    ///
    /// Using this setting does increase memory footprint, but provides an additional level of safety/debugging.
    INDEX_GENERATION_MODE: GenerationSetting = .NO_INDEX_GENERATIONS,
    /// The maximum number of values any one category can have
    MAX_NUM_VALUES_IN_ANY_CATEGORY: comptime_int = 65536,
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
    /// The maximum number of unique function payloads (input+output sets)
    /// across all functions.
    ///
    /// A safe value to choose is the maximum number of derivative parameters you
    /// expect to have in the entire table (one unique payload per derivative param),
    /// but it may be much lower if many of your functions have more than one output.
    MAX_NUM_UNIQUE_FUNCTION_PAYLOADS: comptime_int = 65536,
    /// If set to `true`, the payload location list will use a static memory block attatched to the
    /// `ParametricStateSystem` type. The size of this list will be `(<size of integer that holds function index, payload offset, input len, and output len>) * MAX_NUM_UNIQUE_FUNCTION_PAYLOADS`
    PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY: bool = false,
    /// The maximum number of functions that a parameter can trigger to update other params when it changes
    ///
    /// This also affects the number of derivative parameters a single parameter can have,
    /// but a single triggered function can update more than one derivative parameter at a time
    /// so the number may be larger than this
    MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE: comptime_int = 256,
    /// If non-null, the update queue (a list of all param updates that have been queued in response to user input)
    /// will use static memory of this length. The static byte size will be
    /// `(<size of integer that holds function index, payload offset, input len, and output len>) * UPDATE_QUEUE_STATIC_LENGTH`
    UPDATE_QUEUE_STATIC_LENGTH: ?comptime_int = null,
    /// If non-null, the unique update queue (a list of all params previously updated)
    /// will use static memory of this length. The static byte size will be
    /// `(<size of integer that holds function index, payload offset, input len, output len, and recursion count>) * UNIQUE_UPDATE_QUEUE_STATIC_LENGTH`
    UNIQUE_UPDATE_QUEUE_STATIC_LENGTH: ?comptime_int = null,
    /// If non-zero, an update function is allowed to be called as a result of a single parameter change a maximum of this many times.
    ///
    /// Each unique update payload will track its own number of times its been called, and stop when calling it again would exceed the
    /// limit.
    ///
    /// This setting can cause strange/unexpected effects when relying on recursive updates, and is NOT RECOMMENDED but provided regardless.
    /// For example, if one parameter update starts 2 separate update paths that lead back to a parent parameter update,
    /// it is not clearly defined how many times nor in what order each separate path will re-trigger the original param,
    /// nor that each of the paths will update in a balanced way compared to the other
    ALLOWED_RECURSIVE_UPDATES: comptime_int = 0,
    /// The maximum number of inputs a function can have
    MAX_NUM_FUNCTION_INPUTS: comptime_int = 16,
    /// The maximum number of outputs a function can have
    MAX_NUM_FUNCTION_OUTPUTS: comptime_int = 16,
    /// This may be a tough limit to define, but a safe upper bound is:
    /// ```
    /// PowerOf2.round_up_to_power_of_2(MAX_NUM_UNIQUE_FUNCTION_PAYLOADS * (MAX_NUM_FUNCTION_INPUTS + MAX_NUM_FUNCTION_OUTPUTS)).value()
    /// ```
    MAX_PAYLOAD_LIST_LIMIT: comptime_int = 2097152,
    /// If set to `true`, the payload data list will use a static memory block attatched to the
    /// `ParametricStateSystem` type. The size of this list will be `(<size of integer that holds both category and param index>) * MAX_PAYLOAD_LIST_LIMIT`
    PAYLOAD_LIST_USES_STATIC_MEMORY: bool = false,
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
    /// All tag values must increase from 0 to max with no gaps
    comptime PARAM_CATEGORIES: type,
    /// An array of parameter definitions for each enum entry in `PARAM_CATEGORIES`
    comptime PARAM_CATEGORY_DEFS: [Types.enum_defined_field_count(PARAM_CATEGORIES)]CategoryTypeDef(PARAM_CATEGORIES),
    /// An enum type with a tag name for each function that will be used for updates.
    comptime FUNCTION_NAMES: type,
) type {
    ct_assert_with_reason(Types.type_is_enum(PARAM_CATEGORIES) and Types.all_enum_values_start_from_zero_with_no_gaps(PARAM_CATEGORIES), @src(), "type `PARAM_CATEGORIES` must be an enum type with tag values from 0 to max with no gaps, got type `{s}`", .{@typeName(PARAM_CATEGORIES)});
    ct_assert_with_reason(Types.type_is_enum(FUNCTION_NAMES) and Types.all_enum_values_start_from_zero_with_no_gaps(FUNCTION_NAMES), @src(), "type `FUNCTION_NAMES` must be an enum type with tag values from 0 to max with no gaps, got type `{s}`", .{@typeName(FUNCTION_NAMES)});
    // ct_assert_with_reason(Types.type_is_enum(FUNCTION_NAMES) and Types.all_enum_values_start_from_zero_with_no_gaps(FUNCTION_NAMES), @src(), "type `FUNCTION_NAMES` must be an enum type with tag values from 0 to max with no gaps, got type `{s}`", .{@typeName(FUNCTION_NAMES)});
    const _NUM_CATEGORIES = Types.enum_defined_field_count(PARAM_CATEGORIES);
    const _NUM_FUNCTIONS = Types.enum_defined_field_count(FUNCTION_NAMES);
    const _MAX_FUNCTIONS_IDX = PowerOf2.round_up_to_power_of_2(@as(usize, _NUM_FUNCTIONS));
    // const __NUM_FUNCTIONS = Types.enum_defined_field_count(FUNCTION_NAMES);
    const _MAX_CATEGORIES_IDX = PowerOf2.round_up_to_power_of_2(@as(usize, _NUM_CATEGORIES));
    // const _MAX_FUNCTIONS_IDX = PowerOf2.round_up_to_power_of_2(@as(usize, __NUM_FUNCTIONS));
    const idx_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY).unsigned_integer_type_that_holds_all_values_less_than();
    const cat_int = _MAX_CATEGORIES_IDX.unsigned_integer_type_that_holds_all_values_less_than();
    const func_idx = _MAX_FUNCTIONS_IDX.unsigned_integer_type_that_holds_all_values_less_than();
    const gen_int = switch (SETTINGS.INDEX_GENERATION_MODE) {
        .NO_INDEX_GENERATIONS => u0,
        .PER_PARAMETER_INDEX_GENERATION_INT_POWER => |power| power.unsigned_integer_type_that_holds_all_values_less_than(),
    };
    const func_input_count_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_FUNCTION_INPUTS).unsigned_integer_type_that_holds_all_values_less_than();
    const func_output_count_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_FUNCTION_OUTPUTS).unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_UNIQUE_FUNCTION_PAYLOADS).unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_offset_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_PAYLOAD_LIST_LIMIT).unsigned_integer_type_that_holds_all_values_less_than();
    const update_length_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE).unsigned_integer_type_that_holds_all_values_less_than();
    const update_count_int = if (SETTINGS.ALLOWED_RECURSIVE_UPDATES > 0) PowerOf2.round_up_to_power_of_2(SETTINGS.ALLOWED_RECURSIVE_UPDATES).unsigned_integer_type_that_holds_all_values_less_than() else u0;
    const SUBROUTINE = struct {
        fn param_cat_align_lesser(a: PARAM_CATEGORIES, b: PARAM_CATEGORIES, userdata: [_NUM_CATEGORIES]CategoryTypeDefUnnamed) bool {
            // std.debug.print("a: {s}, b: {s}", .{ @tagName(a), @tagName(b) }); //DEBUG
            return @alignOf(userdata[@intFromEnum(a)].param_type) < @alignOf(userdata[@intFromEnum(b)].param_type);
        }
    };
    comptime var categories_defined: [_NUM_CATEGORIES]bool = @splat(false);
    comptime var ordered_category_defs: [_NUM_CATEGORIES]CategoryTypeDefUnnamed = undefined;
    comptime var ordered_category_type_sizes: [_NUM_CATEGORIES]comptime_int = undefined;
    comptime var largest_category_type_size: usize = 0;
    comptime var total_static_mem_bytes: usize = 0;
    comptime var total_static_free_bit_blocks: usize = 0;
    comptime var total_static_update_slots: usize = 0;
    comptime var static_mem_largest_align: usize = 1;
    comptime var static_categories_ordered_by_param_align: [_NUM_CATEGORIES]PARAM_CATEGORIES = undefined;
    comptime var static_categories_ordered_by_param_align_len: usize = 0;
    comptime var unique_types: [_NUM_CATEGORIES]type = undefined;
    comptime var unique_type_ids: [_NUM_CATEGORIES]cat_int = undefined;
    comptime var category_type_ids: [_NUM_CATEGORIES]cat_int = undefined;
    comptime var total_unique_types: cat_int = 0;
    inline for (PARAM_CATEGORY_DEFS[0..]) |def| {
        const cat_idx = @intFromEnum(def.category);
        ct_assert_with_reason(categories_defined[cat_idx] == false, @src(), "category `{s}` was defined more than once", .{@tagName(def.category)});
        categories_defined[cat_idx] = true;
        comptime var found_unique_match: bool = false;
        inline for (unique_types[0..total_unique_types], 0..) |unique_type, i| {
            if (unique_type == def.param_type) {
                category_type_ids[cat_idx] = unique_type_ids[i];
                found_unique_match = true;
                break;
            }
        }
        if (!found_unique_match) {
            unique_types[total_unique_types] = def.param_type;
            unique_type_ids[total_unique_types] = total_unique_types;
            category_type_ids[cat_idx] = total_unique_types;
            total_unique_types += 1;
        }
        largest_category_type_size = @max(largest_category_type_size, @sizeOf(def.param_type));
        ct_assert_with_reason(def.expected_maximum_num_params <= SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY, @src(), "category `{s}` has a `.expected_maximum_num_params` ({d}) greater than the maximum possible number in any category ({d})", .{ def.expected_maximum_num_params, SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY });
        ordered_category_defs[cat_idx] = CategoryTypeDefUnnamed{
            .param_type = def.param_type,
            .expected_maximum_num_params = def.expected_maximum_num_params,
            .maximum_is_guaranteed = def.maximum_is_guaranteed,
            .allow_free_slots = def.allow_free_slots,
            .default_value_for_type = def.default_value_for_type,
            .type_equality_func = def.type_equality_func,
        };
        ordered_category_type_sizes[cat_idx] = @sizeOf(def.param_type);
        if (def.maximum_is_guaranteed) {
            total_static_mem_bytes += def.expected_maximum_num_params * @sizeOf(def.param_type);
            total_static_free_bit_blocks += PowerOf2.USIZE_POWER.align_value_forward(def.expected_maximum_num_params) >> PowerOf2.USIZE_BITS_SHIFT;
            total_static_update_slots += def.expected_maximum_num_params;
            static_mem_largest_align = @max(static_mem_largest_align, @alignOf(def.param_type));
            static_categories_ordered_by_param_align[static_categories_ordered_by_param_align_len] = def.category;
            static_categories_ordered_by_param_align_len += 1;
        }
    }
    const ordered_category_defs_const = ordered_category_defs;
    const ordered_category_type_sizes_const = ordered_category_type_sizes;
    const largest_category_type_size_const = largest_category_type_size;
    const static_mem_largest_align_const = static_mem_largest_align;
    const static_categories_ordered_by_param_align_len_const = static_categories_ordered_by_param_align_len;
    if (static_categories_ordered_by_param_align_len_const > 0) {
        //CHECKPOINT //FIXME why are these vals undefined?
        @compileLog(static_categories_ordered_by_param_align_len_const); //DEBUG
        @compileLog(static_categories_ordered_by_param_align[0..static_categories_ordered_by_param_align_len_const]); //DEBUG
        // std.debug.print("static_categories_ordered_by_param_align: {any}", .{static_categories_ordered_by_param_align[0..static_categories_ordered_by_param_align_len_const]});
        Utils.mem_sort(&static_categories_ordered_by_param_align[0], 0, static_categories_ordered_by_param_align_len_const, ordered_category_defs_const, SUBROUTINE.param_cat_align_lesser);
    }
    const category_type_ids_const = category_type_ids;
    const unique_types_const: [total_unique_types]type = make: {
        comptime var out: [total_unique_types]type = undefined;
        @memcpy(out[0..], unique_types[0..total_unique_types]);
        break :make out;
    };
    const unique_type_ids_const: [total_unique_types]cat_int = make: {
        comptime var out: [total_unique_types]cat_int = undefined;
        @memcpy(out[0..], unique_type_ids[0..total_unique_types]);
        break :make out;
    };

    if (SETTINGS.CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES) {
        ct_assert_with_reason(SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value() >= _NUM_CATEGORIES, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, `SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value() >= _NUM_CATEGORIES` must ALSO be true, but got {d} < {d}", .{ SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value(), _NUM_CATEGORIES });
        const last_def_idx = _NUM_CATEGORIES - 1;
        const last_def_name: PARAM_CATEGORIES = @enumFromInt(last_def_idx);
        const last_def = ordered_category_defs_const[last_def_idx];
        ct_assert_with_reason(last_def.param_type == SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.unsigned_integer_type_that_holds_all_values_up_to_and_including(), @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.param_type == SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.unsigned_integer_type_that_holds_all_values_up_to_and_including()`", .{ @tagName(last_def_name), last_def_idx });
        ct_assert_with_reason(last_def.expected_maximum_num_params == last_def_idx, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.expected_maximum_num_params == Types.enum_defined_field_count(PARAM_CATEGORIES) - 1` ({d})", .{ @tagName(last_def_name), last_def_idx, last_def_idx });
        ct_assert_with_reason(last_def.maximum_is_guaranteed == true, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.maximum_is_guaranteed == true`", .{@tagName(last_def_name)});
        ct_assert_with_reason(last_def.allow_free_slots == false, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, the largest category tag (`{s}` index {d}) must have `.allow_free_slots == false`", .{@tagName(last_def_name)});
    }
    const static_categories_ordered_by_param_align_const: [static_categories_ordered_by_param_align_len_const]PARAM_CATEGORIES = make: {
        var out: [static_categories_ordered_by_param_align_len_const]PARAM_CATEGORIES = undefined;
        @memcpy(out[0..static_categories_ordered_by_param_align_len_const], static_categories_ordered_by_param_align[0..static_categories_ordered_by_param_align_len_const]);
        break :make out;
    };
    comptime var static_category_mem_starts: [static_categories_ordered_by_param_align_len_const + 1]usize = undefined;
    comptime var static_category_free_bit_block_starts: [static_categories_ordered_by_param_align_len_const + 1]usize = undefined;
    comptime var static_category_update_slot_starts: [static_categories_ordered_by_param_align_len_const + 1]usize = undefined;
    comptime var static_category_mem_starts_current_start: usize = 0;
    comptime var static_category_free_bit_block_starts_current_start: usize = 0;
    comptime var static_category_update_slot_current_start: usize = 0;
    if (static_categories_ordered_by_param_align_len > 0) {
        inline for (static_categories_ordered_by_param_align_const[0..], 0..) |cat, i| {
            const cat_idx = @intFromEnum(cat);
            const mem_size = @sizeOf(ordered_category_defs_const[cat_idx].param_type) * ordered_category_defs_const[cat_idx].expected_maximum_num_params;
            static_category_mem_starts[i] = static_category_mem_starts_current_start;
            static_category_free_bit_block_starts[i] = static_category_free_bit_block_starts_current_start;
            static_category_update_slot_starts[i] = static_category_update_slot_current_start;
            static_category_mem_starts_current_start += mem_size;
            static_category_free_bit_block_starts_current_start += PowerOf2.USIZE_POWER.align_value_forward(ordered_category_defs_const[cat_idx].expected_maximum_num_params) >> PowerOf2.USIZE_BITS_SHIFT;
            static_category_update_slot_current_start += ordered_category_defs_const[cat_idx].expected_maximum_num_params;
        }
        static_category_mem_starts[static_categories_ordered_by_param_align_len_const] = static_category_mem_starts_current_start;
    }
    static_category_mem_starts[static_categories_ordered_by_param_align_len_const] = static_category_mem_starts_current_start;
    static_category_free_bit_block_starts[static_categories_ordered_by_param_align_len_const] = static_category_free_bit_block_starts_current_start;
    static_category_update_slot_starts[static_categories_ordered_by_param_align_len_const] = static_category_update_slot_current_start;
    const static_category_mem_starts_const = static_category_mem_starts;
    const static_category_free_bit_block_starts_const = static_category_free_bit_block_starts;
    const static_category_update_slot_starts_const = static_category_update_slot_starts;
    const total_static_mem_bytes_const = total_static_mem_bytes;
    const total_static_free_bit_blocks_const = total_static_free_bit_blocks;
    const total_static_update_slots_const = total_static_update_slots;
    return struct {
        const System = @This();
        /// IT IS DISCOURAGED TO DIRECTLY ALTER THESE VARIABLES, BUT THEY ARE PROVIDED PUBLICLY IN THIS NAMESPACE IF NEEDED
        pub const INTERNAL = struct {
            pub const MULTITHREADED = SETTINGS.ENABLE_THREAD_SAFETY;
            pub var access_lock: KeyedMutex(MULTITHREADED) = .{};

            // CATEGORIES
            pub const USE_GENERATIONS = SETTINGS.INDEX_GENERATION_MODE.PER_PARAMETER_INDEX_GENERATION_INT_POWER;
            pub const CATEGORY_DEFS = ordered_category_defs_const;
            pub const CATEGORY_TYPE_SIZES = ordered_category_type_sizes_const;
            pub const CATEGORY_TYPE_IDS = category_type_ids_const;
            pub const UNIQUE_TYPES = unique_types_const;
            pub const UNIQUE_TYPE_IDS = unique_type_ids_const;
            pub const MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE = SETTINGS.MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE;
            pub const NUM_CATEGORIES = _NUM_CATEGORIES;
            pub const GenId = gen_int;
            pub const CategoryPool = SimplePoolOpaque(Index, false, .{
                .elem_type = UpdateSlice,
            });
            pub const MetaData = packed struct {
                always_update: bool,
                delete_if_parent_deleted: bool,
                if_not_deleted_set_value_default_when_parent_deleted: bool,
                generation: if (USE_GENERATIONS) GenId else u0,
            };
            pub const MetaDataBits = @bitSizeOf(MetaData);
            pub const MetaList = BitListModule.BitList(MetaDataBits, MetaData);
            pub const Category = struct {
                data: CategoryPool = .{},
                meta: MetaList = .{},
                alloc: Allocator = DummyAllocator.allocator_panic_free_noop,
            };
            pub const UpdateSlice = packed struct {
                first_payload: PayloadId = 0,
                update_count: UpdateTriggerLength = 0,

                pub fn first_payload_u32(self: UpdateSlice) u32 {
                    return @intCast(self.first_payload);
                }
                pub fn end_payload_u32_excluded(self: UpdateSlice) u32 {
                    return num_cast(self.first_payload, u32) + num_cast(self.update_count, u32);
                }
            };
            pub const CategoryId: type = cat_int;
            pub const UpdateTriggerLength: type = update_length_int;
            pub const PayloadId: type = func_payload_int;
            pub const STATIC_MEM_LEN = total_static_mem_bytes_const;
            pub const STATIC_FREE_BIT_BLOCK_LEN = total_static_free_bit_blocks_const;
            pub const STATIC_UPDATE_SLOT_LEN = total_static_update_slots_const;
            pub const STATIC_MEM_ALIGN = static_mem_largest_align_const;
            pub const STATIC_MEM_STARTS = static_category_mem_starts_const;
            pub const STATIC_FREE_BIT_BLOCK_STARTS = static_category_free_bit_block_starts_const;
            pub const STATIC_UPDATE_SLOT_STARTS = static_category_update_slot_starts_const;
            pub var static_param_memory: [STATIC_MEM_LEN]u8 align(STATIC_MEM_ALIGN) = undefined;
            pub var static_free_block_memory: [STATIC_FREE_BIT_BLOCK_LEN]usize = @splat(math.maxInt(usize));
            pub var static_always_change_memory: [STATIC_FREE_BIT_BLOCK_LEN]usize = @splat(0);
            pub var static_update_slot_memory: [STATIC_UPDATE_SLOT_LEN]UpdateSlice = undefined;
            pub var categories: [NUM_CATEGORIES]Category = build: {
                var out: [NUM_CATEGORIES]Category = undefined;
                next_cat: for (0..NUM_CATEGORIES) |cat_idx| {
                    const cat: CategoryName = @enumFromInt(cat_idx);
                    const def = CATEGORY_DEFS[cat_idx];
                    for (static_categories_ordered_by_param_align_const[0..], 0..) |cat_with_static_mem, static_idx| {
                        if (cat == cat_with_static_mem) {
                            const static_start = STATIC_MEM_STARTS[static_idx];
                            const update_start = STATIC_UPDATE_SLOT_STARTS[static_idx];
                            const free_bit_block_start = STATIC_FREE_BIT_BLOCK_STARTS[static_idx];
                            const free_bit_block_end = STATIC_FREE_BIT_BLOCK_STARTS[static_idx + 1];
                            out[cat_idx] = Category{
                                .alloc = DummyAllocator.allocator_panic_free_noop,
                                .data = .{
                                    .ptr = @ptrCast(@alignCast(&static_param_memory[static_start])),
                                    .ptr_2 = @ptrCast(&static_update_slot_memory[update_start]),
                                    .len = 0,
                                    .cap = @intCast(def.expected_maximum_num_params),
                                    .free_list = .{
                                        .free_bits = .{
                                            .list = .{
                                                .ptr = @ptrCast(&static_free_block_memory[free_bit_block_start]),
                                                .len = @intCast(free_bit_block_end - free_bit_block_start),
                                                .cap = @intCast(free_bit_block_end - free_bit_block_start),
                                            },
                                            .index_len = 0,
                                        },
                                        .free_count = 0,
                                    },
                                },
                                .meta = .{
                                    .list = .{
                                        .ptr = @ptrCast(&static_always_change_memory[free_bit_block_start]),
                                        .len = @intCast(free_bit_block_end - free_bit_block_start),
                                        .cap = @intCast(free_bit_block_end - free_bit_block_start),
                                    },
                                    .index_len = 0,
                                },
                            };
                            continue :next_cat;
                        }
                    }
                    out[cat_idx] = Category{};
                }
                break :build out;
            };

            // UPDATE QUEUE
            pub const RecursionCount: type = update_count_int;
            pub fn handle_recursion(item_to_queue: *UpdatePackage, previously_queued: *UpdatePackageUnique) UniqueQueueModule.PreviousQueueResult {
                if (RECURSION_ALLOWED) {
                    if (previously_queued.recursion_count < RECURSION_LIMIT) {
                        previously_queued.recursion_count += 1;
                        return .CONTINUE_TO_CHECK_CURRENTLY_QUEUED;
                    } else {
                        return .DO_NOT_QUEUE;
                    }
                } else {
                    _RecursionAssert._unreachable(@src(), "recursive parameter update detected:\nparam update package triggered twice: {any}\n", .{item_to_queue.*});
                    return .DO_NOT_QUEUE;
                }
            }
            pub fn handle_current_repeat(_: *UpdatePackage, _: *UpdatePackage) UniqueQueueModule.CurrentlyQueuedResult {
                return .DO_NOT_QUEUE;
            }
            pub const MAX_TRIGGERS_PER_PARAM = SETTINGS.MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE;
            pub const UpdateQueue = UniqueQueue(UpdatePackage, UpdatePackageUnique, UpdatePackage.equals, UpdatePackage.equals_unique, handle_recursion, handle_current_repeat, UpdatePackage.to_unique);
            pub const RECURSION_ALLOWED = SETTINGS.ALLOWED_RECURSIVE_UPDATES > 0;
            pub const RECURSION_LIMIT = SETTINGS.ALLOWED_RECURSIVE_UPDATES;
            pub const STATIC_UPDATE_QUEUE_LEN = if (SETTINGS.UPDATE_QUEUE_STATIC_LENGTH) |LEN| LEN else 0;
            pub const UNIQUE_STATIC_UPDATE_QUEUE_LEN = if (SETTINGS.UNIQUE_UPDATE_QUEUE_STATIC_LENGTH) |LEN| LEN else 0;
            pub var update_queue_alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
            pub var static_update_queue_mem: [STATIC_UPDATE_QUEUE_LEN]UpdatePackage = undefined;
            pub var unique_static_update_queue_mem: [UNIQUE_STATIC_UPDATE_QUEUE_LEN]UpdatePackageUnique = undefined;
            pub var update_queue: UpdateQueue = build: {
                var queue = UpdateQueue{};
                if (STATIC_UPDATE_QUEUE_LEN > 0) {
                    queue.queue_ptr = @ptrCast(&static_update_queue_mem[0]);
                    queue.queue_cap = STATIC_UPDATE_QUEUE_LEN;
                }
                if (UNIQUE_STATIC_UPDATE_QUEUE_LEN > 0) {
                    queue.unique_ptr = @ptrCast(&unique_static_update_queue_mem[0]);
                    queue.unique_cap = UNIQUE_STATIC_UPDATE_QUEUE_LEN;
                }
                break :build queue;
            };
            pub var updates_in_progress: bool = false;

            // PAYLOAD LOCATIONS
            pub const PayloadInCount: type = func_input_count_int;
            pub const PayloadOutCount: type = func_output_count_int;
            pub const UpdatePackage = packed struct {
                func_idx: FuncId,
                first_payload_index: PayloadOffset,
                in_count: PayloadInCount,
                out_count: PayloadOutCount,

                pub fn equals(a: UpdatePackage, b: UpdatePackage) bool {
                    const matches = a.func_idx == b.func_idx and a.first_payload_index == b.first_payload_index;
                    if (_Assert._should_assert() and matches) {
                        assert_with_reason(a.in_count == b.in_count and a.out_count == b.out_count, @src(), "two update packages with the same function and payload offset DID NOT HAV THE SAME input/output count... something went wrong\nA: {any}\nB: {any}\n", .{ a, b });
                    }
                    return matches;
                }
                pub fn equals_unique(a: UpdatePackage, b: UpdatePackageUnique) bool {
                    const matches = a.func_idx == b.func_idx and a.first_payload_index == b.first_payload_index;
                    if (_Assert._should_assert() and matches) {
                        assert_with_reason(a.in_count == b.in_count and a.out_count == b.out_count, @src(), "two update packages with the same function and payload offset DID NOT HAV THE SAME input/output count... something went wrong\nA: {any}\nB: {any}\n", .{ a, b });
                    }
                    return matches;
                }

                pub fn to_unique(self: UpdatePackage) UpdatePackageUnique {
                    return UpdatePackageUnique{
                        .func_idx = self.func_idx,
                        .first_payload_index = self.first_payload_index,
                        .in_count = self.in_count,
                        .out_count = self.out_count,
                        .recursion_count = 0,
                    };
                }

                pub fn start_of_inputs(self: UpdatePackage) u32 {
                    return @intCast(self.first_payload_index);
                }
                pub fn end_of_inputs_excluded(self: UpdatePackage) u32 {
                    return num_cast(self.first_payload_index, u32) + num_cast(self.in_count, u32);
                }
                pub fn start_of_outputs(self: UpdatePackage) u32 {
                    return num_cast(self.first_payload_index, u32) + num_cast(self.in_count, u32);
                }
                pub fn end_of_outputs_excluded(self: UpdatePackage) u32 {
                    return num_cast(self.first_payload_index, u32) + num_cast(self.in_count, u32) + num_cast(self.out_count, u32);
                }
            };
            pub const UpdatePackageUnique = packed struct {
                func_idx: FuncId,
                first_payload_index: PayloadOffset,
                in_count: PayloadInCount,
                out_count: PayloadOutCount,
                recursion_count: RecursionCount,
            };
            pub const MAX_NUM_UNIQUE_FUNCTION_PAYLOADS = SETTINGS.MAX_NUM_UNIQUE_FUNCTION_PAYLOADS;
            pub const MAX_FREE_BLOCKS_FOR_UNIQUE_FUNCTION_PAYLOADS = PowerOf2.USIZE_POWER.align_value_forward(MAX_NUM_UNIQUE_FUNCTION_PAYLOADS) >> PowerOf2.USIZE_BITS_SHIFT;
            pub const PayloadLocationPool = SimplePool(UpdatePackage, PayloadId, false, null, null, null);
            pub var payload_location_list_alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
            pub var payload_location_static_mem: if (SETTINGS.PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY) [MAX_NUM_UNIQUE_FUNCTION_PAYLOADS]UpdatePackage else void = if (SETTINGS.PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY) undefined else void{};
            pub var payload_location_free_static_mem: if (SETTINGS.PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY) [MAX_FREE_BLOCKS_FOR_UNIQUE_FUNCTION_PAYLOADS]usize else void = if (SETTINGS.PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY) @splat(math.maxInt(usize)) else void{};
            pub var payload_location_pool: PayloadLocationPool = if (SETTINGS.PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY) PayloadLocationPool{
                .ptr = @ptrCast(&payload_location_static_mem[0]),
                .len = 0,
                .cap = MAX_NUM_UNIQUE_FUNCTION_PAYLOADS,
                .free_list = FreeList{
                    .free_bits = .{
                        .list = .{
                            .ptr = @ptrCast(&payload_location_free_static_mem[0]),
                            .len = MAX_FREE_BLOCKS_FOR_UNIQUE_FUNCTION_PAYLOADS,
                            .cap = MAX_FREE_BLOCKS_FOR_UNIQUE_FUNCTION_PAYLOADS,
                        },
                        .index_len = 0,
                    },
                    .free_count = 0,
                },
            } else PayloadLocationPool{};

            // PAYLOAD DATA
            pub const PayloadOffset: type = func_payload_offset_int;
            pub const MAX_PAYLOAD_LIST_LIMIT = SETTINGS.MAX_PAYLOAD_LIST_LIMIT;
            pub const MAX_FREE_BLOCKS_FOR_PAYLOAD_DATA = PowerOf2.USIZE_POWER.align_value_forward(MAX_PAYLOAD_LIST_LIMIT) >> PowerOf2.USIZE_BITS_SHIFT;
            pub const PayloadDataPool = SimplePool(ParamReadWriteOpaque, PayloadOffset, false, null, null, null);
            pub var payload_data_list_alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
            pub var payload_data_static_mem: if (SETTINGS.PAYLOAD_LIST_USES_STATIC_MEMORY) [SETTINGS.MAX_PAYLOAD_LIST_LIMIT]ParamReadWriteOpaque else void = if (SETTINGS.PAYLOAD_LIST_USES_STATIC_MEMORY) undefined else void{};
            pub var payload_data_free_static_mem: if (SETTINGS.PAYLOAD_LIST_USES_STATIC_MEMORY) [MAX_FREE_BLOCKS_FOR_PAYLOAD_DATA]usize else void = if (SETTINGS.PAYLOAD_LIST_USES_STATIC_MEMORY) @splat(math.maxInt(usize)) else void{};
            pub var payload_data_pool: PayloadDataPool = if (SETTINGS.PAYLOAD_LIST_USES_STATIC_MEMORY) PayloadDataPool{
                .ptr = @ptrCast(&payload_data_static_mem[0]),
                .len = 0,
                .cap = SETTINGS.MAX_PAYLOAD_LIST_LIMIT,
                .free_list = FreeList{
                    .free_bits = .{
                        .list = .{
                            .ptr = @ptrCast(&payload_data_free_static_mem[0]),
                            .len = MAX_FREE_BLOCKS_FOR_PAYLOAD_DATA,
                            .cap = MAX_FREE_BLOCKS_FOR_PAYLOAD_DATA,
                        },
                        .index_len = 0,
                    },
                    .free_count = 0,
                },
            } else PayloadDataPool{};

            // FUNCTIONS
            pub const NUM_FUNCS = _NUM_FUNCTIONS;
            pub const FuncId: type = func_idx;
            pub const FunctionPool = SimplePool(*const UpdateFunction, FuncId, false, null, null, null);
            pub const TRACK_FUNC_DEPENDANTS = SETTINGS.ALLOW_FUNCTION_REPLACEMENT or SETTINGS.ALLOW_FUNCTION_DELETION;
            pub const MAX_INPUTS = SETTINGS.MAX_NUM_FUNCTION_INPUTS;
            pub const MAX_OUTPUTS = SETTINGS.MAX_NUM_FUNCTION_OUTPUTS;
            pub const UpdatePackageNoFunc = packed struct {
                first_payload_index: PayloadOffset,
                in_count: PayloadInCount,
                out_count: PayloadOutCount,

                pub fn from_update_package(pkg: UpdatePackage) UpdatePackageNoFunc {
                    return UpdatePackageNoFunc{
                        .first_payload_index = pkg.first_payload_index,
                        .in_count = pkg.in_count,
                        .out_count = pkg.out_count,
                    };
                }
                pub fn to_update_package(self: UpdatePackageNoFunc, func: FuncId) UpdatePackage {
                    return UpdatePackage{
                        .func_idx = func,
                        .first_payload_index = self.first_payload_index,
                        .in_count = self.in_count,
                        .out_count = self.out_count,
                    };
                }

                pub fn start_of_inputs(self: UpdatePackageNoFunc) u32 {
                    return @intCast(self.first_payload_index);
                }
                pub fn end_of_inputs_excluded(self: UpdatePackageNoFunc) u32 {
                    return num_cast(self.first_payload_index, u32) + num_cast(self.in_count, u32);
                }
                pub fn start_of_outputs(self: UpdatePackageNoFunc) u32 {
                    return num_cast(self.first_payload_index, u32) + num_cast(self.in_count, u32);
                }
                pub fn end_of_outputs_excluded(self: UpdatePackageNoFunc) u32 {
                    return num_cast(self.first_payload_index, u32) + num_cast(self.in_count, u32) + num_cast(self.out_count, u32);
                }
            };
            pub const FunctionDependants = UpdatePackageNoFunc;
            pub const FuncDependantList = List(FunctionDependants);
            pub var func_dependants: if (TRACK_FUNC_DEPENDANTS) [NUM_FUNCS]FuncDependantList else void = if (TRACK_FUNC_DEPENDANTS) @splat(.{}) else void{};
            pub var func_dep_alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
            pub var update_funcs: [NUM_FUNCS]*const UpdateFunction = undefined;
            pub var funcs_init: [NUM_FUNCS]bool = @splat(false);
            pub var func_gens: if (USE_GENERATIONS and SETTINGS.ALLOW_FUNCTION_DELETION) [NUM_FUNCS]GenId else void = if (USE_GENERATIONS and SETTINGS.ALLOW_FUNCTION_DELETION) @splat(0) else void{};

            // DELETE QUEUE
            pub const LARGEST_TYPE_SIZE = largest_category_type_size_const;
            pub var delete_queue_alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
            pub var delete_queue: List(ParamReadWriteOpaque) = undefined;
            pub var delete_queue_cursor: usize = 0;
            pub var delete_in_progress: bool = false;

            // ASSERT UTILS
            pub const _Assert = Assert.AssertHandler(SETTINGS.MASTER_ASSERT_MODE);
            pub const assert_with_reason = _Assert._with_reason;
            pub const assert_unreachable = _Assert._unreachable;
            pub const assert_unreachable_err = _Assert._unreachable_err;
            pub const assert_index_in_range = _Assert._index_in_range;
            pub const assert_allocation_failure = _Assert._allocation_failure;
            pub const _RecursionAssert = Assert.AssertHandler(SETTINGS.RECURSION_ASSERT_MODE);

            // LOGIC
            pub fn initialize_function_internal(comptime func_name: FuncName, func: *const UpdateFunction, _mutex_key: MutexKey) void {
                var mutex_key: MutexKey, const owns_key: bool = _mutex_key.lock_if_needed(&INTERNAL.access_lock);
                defer mutex_key.unlock_if_needed(owns_key);
                const _func_idx = @intFromEnum(func_name);
                INTERNAL.assert_with_reason(INTERNAL.funcs_init[_func_idx] == false, @src(), "function `{s}` was already initialized. If you want to replace it (and replacement is enabled), use `replace_update_function` instead", .{@tagName(func_name)});
                INTERNAL.funcs_init[_func_idx] = true;
                INTERNAL.update_funcs[_func_idx] = func;
            }
            pub fn delete_function_internal(comptime func_name: FuncName, _mutex_key: MutexKey) void {
                comptime assert_with_reason(SETTINGS.ALLOW_FUNCTION_DELETION, @src(), "cannot call this function if `ALLOW_FUNCTION_DELETION` is false", .{});
                if (SETTINGS.ALLOW_FUNCTION_DELETION) {
                    var mutex_key: MutexKey, const owns_key: bool = _mutex_key.lock_if_needed(&INTERNAL.access_lock);
                    defer mutex_key.unlock_if_needed(owns_key);
                    const _func_idx = @intFromEnum(func_name);
                    assert_with_reason(INTERNAL.funcs_init[_func_idx] == true, @src(), "function `{s}` was not initialized (can't delete a non-existent update function)", .{@tagName(func_name)});
                    const func_deps: *FuncDependantList = &func_dependants[_func_idx];
                    for (func_deps.slice()) |package_no_func| {
                        const outputs = payload_data_pool.ptr[package_no_func.start_of_outputs()..package_no_func.end_of_outputs_excluded()];
                        for (outputs) |out| {
                            const meta = categories[out.category].meta.get(@intCast(out.index));
                            if (meta.delete_if_parent_deleted) {
                                delete_internal(out.category, out.index, out.generation, mutex_key, false);
                            } else if (meta.if_not_deleted_set_value_default_when_parent_deleted) {
                                set_param_default_internal(out, mutex_key);
                            }
                        }
                    }
                    func_deps.clear();
                    if (USE_GENERATIONS) {
                        func_gens[_func_idx] += 1;
                    }
                    funcs_init[_func_idx] = false;
                    update_funcs[_func_idx] = Utils.invalid_ptr_const(UpdateFunction);
                }
            }

            pub fn replace_func_internal(comptime func_name: FuncName, new_func: *const UpdateFunction, _mutex_key: MutexKey) void {
                comptime assert_with_reason(SETTINGS.ALLOW_FUNCTION_REPLACEMENT, @src(), "cannot call this function if `ALLOW_FUNCTION_REPLACEMENT` is false", .{});
                if (SETTINGS.ALLOW_FUNCTION_REPLACEMENT) {
                    var mutex_key: MutexKey, const owns_key: bool = _mutex_key.lock_if_needed(&INTERNAL.access_lock);
                    defer mutex_key.unlock_if_needed(owns_key);
                    const _func_idx = @intFromEnum(func_name);
                    assert_with_reason(INTERNAL.funcs_init[_func_idx] == true, @src(), "function `{s}` was not initialized (can't replace a non-existent update function), if you wanted to initialize a function use `initialize_update_function` instead", .{@tagName(func_name)});
                    update_funcs[_func_idx] = new_func;
                    const func_deps: FuncDependantList = func_dependants[_func_idx];
                    for (func_deps.slice()) |package_no_func| {
                        const package = package_no_func.to_update_package(@intCast(_func_idx));
                        update_queue.queue(package, update_queue_alloc);
                    }
                    process_all_updates_if_needed(mutex_key);
                }
            }

            pub fn set_internal(comptime T: type, cat_idx: CategoryId, index: Index, gen: GenId, val: T, _mutex_key: MutexKey, comptime SKIP_GEN_CHECK: bool, comptime SKIP_PROCESS_CHANGES: bool) void {
                var mutex_key: MutexKey, const owns_key: bool = _mutex_key.lock_if_needed(&INTERNAL.access_lock);
                defer mutex_key.unlock_if_needed(owns_key);
                if (USE_GENERATIONS and !SKIP_GEN_CHECK and _Assert._should_assert()) {
                    const found_gen = categories[cat_idx].generations.get(@intCast(index));
                    assert_with_reason(found_gen == gen, @src(), "attempted to access parameter (category `{s}` index {d}) with mismatched generation (requested {d}, found {d})", .{ @tagName(num_cast(cat_idx, CategoryName)), index, gen, found_gen });
                }
                const list_opaque = categories[cat_idx].data;
                const list_typed = list_opaque.to_typed(T);
                const old: T = list_typed.ptr[index];
                list_typed.ptr[index] = val;
                const is_equal: *const fn (a: T, b: T) bool = @ptrCast(@alignCast(CATEGORY_DEFS[cat_idx].type_equality_func));
                if (!is_equal(old, val) or categories[cat_idx].meta.get(@intCast(index)).always_update) {
                    const update_slice: UpdateSlice = categories[cat_idx].data.ptr_2[index];
                    if (update_slice.update_count > 0) {
                        const updates_to_trigger = payload_location_pool.ptr[update_slice.first_payload_u32()..update_slice.end_payload_u32_excluded()];
                        for (updates_to_trigger) |to_trigger| {
                            update_queue.queue(to_trigger, update_queue_alloc);
                        }
                        if (!SKIP_PROCESS_CHANGES) {
                            process_all_updates_if_needed(mutex_key);
                        }
                    }
                }
            }
            pub fn set_internal_opaque(cat_idx: CategoryId, index: Index, gen: GenId, val: []const u8, _mutex_key: MutexKey, comptime SKIP_GEN_CHECK: bool, comptime SKIP_PROCESS_CHANGES: bool) void {
                var mutex_key: MutexKey, const owns_key: bool = _mutex_key.lock_if_needed(&INTERNAL.access_lock);
                defer mutex_key.unlock_if_needed(owns_key);
                if (USE_GENERATIONS and !SKIP_GEN_CHECK and _Assert._should_assert()) {
                    const found_gen = categories[cat_idx].generations.get(@intCast(index));
                    assert_with_reason(found_gen == gen, @src(), "attempted to access parameter (category `{s}` index {d}) with mismatched generation (requested {d}, found {d})", .{ @tagName(num_cast(cat_idx, CategoryName)), index, gen, found_gen });
                }
                const T_SIZE = CATEGORY_TYPE_SIZES[cat_idx];
                const elem_ptr_opaque = categories[cat_idx].data.opaque_elem_ptr(index, T_SIZE);
                const elem_bytes_opaque = elem_ptr_opaque[0..T_SIZE];
                var old: [LARGEST_TYPE_SIZE]u8 = undefined;
                @memcpy(old[0..T_SIZE], elem_bytes_opaque);
                @memcpy(elem_bytes_opaque, val[0..T_SIZE]);
                if (!bytes_are_equal(old, val[0..T_SIZE]) or categories[cat_idx].meta.get(@intCast(index)).always_update) {
                    const update_slice: UpdateSlice = categories[cat_idx].data.ptr_2[index];
                    if (update_slice.update_count > 0) {
                        const updates_to_trigger = payload_location_pool.ptr[update_slice.first_payload_u32()..update_slice.end_payload_u32_excluded()];
                        for (updates_to_trigger) |to_trigger| {
                            update_queue.queue(to_trigger, update_queue_alloc);
                        }
                        if (!SKIP_PROCESS_CHANGES) {
                            process_all_updates_if_needed(mutex_key);
                        }
                    }
                }
            }
            pub fn get_internal(comptime T: type, cat_idx: CategoryId, index: Index, gen: GenId, _mutex_key: MutexKey, comptime SKIP_GEN_CHECK: bool) T {
                var mutex_key: MutexKey, const owns_key: bool = _mutex_key.lock_if_needed(&INTERNAL.access_lock);
                defer mutex_key.unlock_if_needed(owns_key);
                if (USE_GENERATIONS and !SKIP_GEN_CHECK and _Assert._should_assert()) {
                    const found_gen = categories[cat_idx].generations.get(@intCast(index));
                    assert_with_reason(found_gen == gen, @src(), "attempted to access parameter (category `{s}` index {d}) with mismatched generation (requested {d}, found {d})", .{ @tagName(num_cast(cat_idx, CategoryName)), index, gen, found_gen });
                }
                const list_opaque = categories[cat_idx].data;
                const list_typed = list_opaque.to_typed(T);
                return list_typed.ptr[index];
            }

            pub fn process_one_update(mutex_key: MutexKey, package: UpdatePackage) void {
                const input_ptr: [*]const ParamReadOnlyOpaque = @ptrCast(payload_data_pool.ptr + package.first_payload_index);
                const output_ptr: [*]const ParamReadWriteOpaque = payload_data_pool.ptr + package.first_payload_index + package.in_count;
                const inputs: []const ParamReadOnlyOpaque = input_ptr[0..package.in_count];
                const outputs: []const ParamReadWriteOpaque = output_ptr[0..package.out_count];
                const func = update_funcs[package.func_idx];
                func(mutex_key, inputs, outputs);
            }

            pub fn process_all_updates_if_needed(mutex_key: MutexKey) void {
                if (!updates_in_progress) {
                    updates_in_progress = true;
                    defer updates_in_progress = false;
                    while (update_queue.has_queued_items()) {
                        const next_update = update_queue.get_next_queued_guaranteed();
                        process_one_update(mutex_key, next_update, false);
                    }
                    update_queue.reset();
                }
            }

            pub fn delete_internal(cat_id: CategoryId, index: Index, generation: GenId, _mutex_key: MutexKey, comptime SKIP_FIRST_GEN_CHECK: bool, comptime SKIP_PROCESS_DELETIONS: bool) void {
                var mutex_key: MutexKey, const owns_key: bool = _mutex_key.lock_if_needed(&INTERNAL.access_lock);
                defer mutex_key.unlock_if_needed(owns_key);
                const param = ParamReadWriteOpaque{
                    .category = @intCast(cat_id),
                    .index = @intCast(index),
                    .generation = if (USE_GENERATIONS) generation else 0,
                };
                _ = delete_queue.append(param, delete_queue_alloc);
                if (!SKIP_PROCESS_DELETIONS) {
                    process_all_deletes_if_needed(mutex_key, SKIP_FIRST_GEN_CHECK);
                }
            }

            pub fn process_all_deletes_if_needed(mutex_key: MutexKey, comptime SKIP_FIRST_GEN_CHECK: bool) void {
                if (delete_in_progress == false) {
                    delete_in_progress = true;
                    defer delete_in_progress = false;
                    if (SKIP_FIRST_GEN_CHECK and delete_queue_cursor < delete_queue.len) {
                        const param = delete_queue.ptr[delete_queue_cursor];
                        process_one_delete(param, mutex_key, true);
                        delete_queue_cursor += 1;
                    }
                    while (delete_queue_cursor < delete_queue.len) {
                        const param = delete_queue.ptr[delete_queue_cursor];
                        process_one_delete(param, mutex_key, false);
                        delete_queue_cursor += 1;
                    }
                    delete_queue.clear();
                    delete_queue_cursor = 0;
                }
            }

            pub fn bytes_are_equal(a: []const u8, b: []const u8) bool {
                return std.mem.eql(u8, a, b);
            }

            pub fn process_one_delete(param: ParamReadWriteOpaque, mutex_key: MutexKey, comptime SKIP_GEN_CHECK: bool, comptime SKIP_PROCESS_CHANGES: bool) void {
                if (categories[param.category].data.free_list.idx_is_used(@intCast(param.index))) {
                    var meta = categories[param.category].meta.get(@intCast(param.index));
                    if (USE_GENERATIONS) {
                        if (!SKIP_GEN_CHECK) {
                            assert_with_reason(param.generation == meta.generation, @src(), "param to delete (category `{s}` index {d}) references an older generation than the param in that location (requested {d}, found {d})", .{ @tagName(num_cast(param.category, CategoryName)), param.index, param.generation, meta.generation });
                        }
                        meta.generation += 1;
                        categories[param.category].meta.set(@intCast(param.index), meta);
                    }
                    const THIS_SIZE = CATEGORY_TYPE_SIZES[param.category];
                    categories[param.category].data.release_opaque(@intCast(param.index), THIS_SIZE);
                    const update_slice: UpdateSlice = categories[param.category].data.ptr_2[param.index];
                    categories[param.category].data.ptr_2[param.index] = .{};
                    if (update_slice.update_count > 0) {
                        const update_packages = payload_location_pool.ptr[update_slice.first_payload_u32()..update_slice.end_payload_u32_excluded()];
                        for (update_packages) |package| {
                            const out_params = payload_data_pool.ptr[package.start_of_outputs()..package.end_of_outputs_excluded()];
                            for (out_params) |out| {
                                const out_meta = categories[param.category].meta.get(@intCast(out.index));
                                if (USE_GENERATIONS) {
                                    assert_with_reason(out.generation == out_meta.generation, @src(), "param to consider deleting (category `{s}` index {d}) references an older generation than the param in that location (requested {d}, found {d})", .{ @tagName(num_cast(out.category, CategoryName)), out.index, out.generation, out_meta.generation });
                                }
                                if (out_meta.delete_if_parent_deleted) {
                                    _ = delete_queue.append(out, delete_queue_alloc);
                                } else if (out_meta.if_not_deleted_set_value_default_when_parent_deleted) {
                                    set_param_default_internal(out, mutex_key, false, SKIP_PROCESS_CHANGES);
                                }
                            }
                        }
                    }
                }
            }

            pub fn set_param_default_internal(param: ParamReadWriteOpaque, mutex_key: MutexKey, comptime SKIP_GEN_CHECK: bool, comptime SKIP_PROCESS_CHANGES: bool) void {
                const OUT_SIZE = CATEGORY_TYPE_SIZES[param.category];
                assert_with_reason(CATEGORY_DEFS[param.category].default_value_for_type != null, @src(), "parameter index {d} in category `{s}` has `delete_if_parent_deleted == false` and `if_not_deleted_set_value_default_when_parent_deleted == true` and its parent was deleted, but the category has no default value provided", .{ param.index, @tagName(num_cast(param.category, CategoryName)) });
                const default_opaque_ptr: [*]const u8 = @ptrCast(@alignCast(CATEGORY_DEFS[param.category].default_value_for_type.?));
                const default_opaque_bytes = default_opaque_ptr[0..OUT_SIZE];
                set_internal_opaque(param.category, param.index, param.generation, default_opaque_bytes, mutex_key, SKIP_GEN_CHECK, SKIP_PROCESS_CHANGES);
            }

            pub fn create_new_root_param_internal(comptime category: CategoryName, specific_index: ?Index, initial_val: CategoryType(category), update_mode: AlwaysUpdateMode, _mutex_key: MutexKey) RootParam(CategoryType(category)) {
                var mutex_key: MutexKey, const owns_key: bool = _mutex_key.lock_if_needed(&INTERNAL.access_lock);
                defer mutex_key.unlock_if_needed(owns_key);
                const cat_idx = @intFromEnum(category);
                const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
                var cat_data = INTERNAL.categories[cat_idx].data.to_typed_ptr(T);
                var cat_meta = &INTERNAL.categories[cat_idx].meta;
                const cat_alloc = INTERNAL.categories[cat_idx].alloc;
                var idx: Index = undefined;
                var ptr: *T = undefined;
                if (specific_index) |i| {
                    INTERNAL.assert_with_reason(cat_data.free_list.idx_is_free(@intCast(i)), @src(), "index {d} in category `{s}` was not free to create new root param", .{ i, @tagName(category) });
                    idx = i;
                    ptr = &cat_data.ptr[i];
                } else {
                    const claimed = cat_data.claim_one(cat_alloc);
                    idx = claimed.idx;
                    ptr = claimed.ptr;
                }
                cat_meta.ensure_capacity_and_zero_new(@intCast(idx), cat_alloc);
                var meta = cat_meta.get(idx);
                meta.always_update = update_mode == .ALWAYS_UPDATE_EVEN_IF_VALUE_UNCHANGED;
                meta.delete_if_parent_deleted = false;
                meta.if_not_deleted_set_value_default_when_parent_deleted = false;
                cat_meta.set(idx, meta);
                ptr.* = initial_val;
                return RootParam(T){
                    .category = @intCast(cat_idx),
                    .index = @intCast(idx),
                    .generation = if (INTERNAL.USE_GENERATIONS) meta.generation else 0,
                };
            }

            pub fn create_new_derived_param_set_internal(update_function: FuncName, inputs: anytype, output_defs: anytype, comptime OUTPUT_STRUCT: type, _mutex_key: MutexKey) OUTPUT_STRUCT {
                var mutex_key: MutexKey, const owns_key: bool = _mutex_key.lock_if_needed(&INTERNAL.access_lock);
                defer mutex_key.unlock_if_needed(owns_key);
                const DEFS = @TypeOf(output_defs);
                const INS = @TypeOf(inputs);
                INTERNAL.assert_with_reason(Types.type_is_struct(INS), @src(), "`inputs` must be a struct type where each field is a `ParamUpdateInput(T)`, got type `{s}`", .{@typeName(INS)});
                INTERNAL.assert_with_reason(@typeInfo(INS).@"struct".fields.len <= INTERNAL.MAX_INPUTS, @src(), "the number of inputs ({d}) exceeds the maximum number possible ({d})", .{ @typeInfo(INS).@"struct".fields.len, INTERNAL.MAX_INPUTS });
                const inputs_flat: [@typeInfo(INS).@"struct".fields.len]ParamReadOnlyOpaque = build: {
                    var out: [@typeInfo(INS).@"struct".fields.len]ParamReadOnlyOpaque = undefined;
                    inline for (@typeInfo(INS).@"struct".fields, 0..) |field, f| {
                        assert_with_reason(Types.type_has_decl_with_type(field.type, "TYPE", type), @src(), "field `{s}` on the input struct is not a `ParamUpdateInput(T)` (missing declaration `const TYPE: type = <param type>`)", .{field.name});
                        assert_with_reason(field.type == ParamUpdateInput(@field(field.type, "TYPE")), @src(), "field `{s}` on the input struct is not a `ParamUpdateInput(T)`", .{field.name});
                        out[f] = @field(inputs, field.name).to_opaque();
                    }
                    break :build out;
                };
                INTERNAL.assert_with_reason(Types.type_is_struct_with_all_fields_same_type(DEFS, DerivedParamDef), @src(), "`output_defs` must be a struct type where each field is a `DerivedParamDef`, got type `{s}`", .{@typeName(DEFS)});
                INTERNAL.assert_with_reason(Types.type_is_struct(OUTPUT_STRUCT), @src(), "type `OUTPUT_STRUCT` must be a struct type, got type `{s}`", .{@typeName(OUTPUT_STRUCT)});
                INTERNAL.assert_with_reason(@typeInfo(DEFS).@"struct".fields.len <= INTERNAL.MAX_OUTPUTS, @src(), "the number of outputs ({d}) exceeds the maximum number possible ({d})", .{ @typeInfo(DEFS).@"struct".fields.len, INTERNAL.MAX_OUTPUTS });
                INTERNAL.assert_with_reason(INTERNAL.funcs_init[@intFromEnum(update_function)] == true, @src(), "function `{s}` was not initialized", .{@tagName(update_function)});
                const _func_idx: INTERNAL.FuncId = @intFromEnum(update_function);
                const input_count = inputs_flat.len;
                const output_count = @typeInfo(DEFS).@"struct".fields.len;
                const params_count = input_count + output_count;
                var defs = output_defs;
                var gen: INTERNAL.GenId = undefined;
                inline for (@typeInfo(DEFS).@"struct".fields) |field| {
                    const def: DerivedParamDef = @field(output_defs, field.name);
                    const cat_idx = @intFromEnum(def.category);
                    const def_type = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
                    var cat_data = INTERNAL.categories[cat_idx].data.to_typed_ptr(def_type);
                    var cat_meta = &INTERNAL.categories[cat_idx].meta;
                    const cat_alloc = INTERNAL.categories[cat_idx].alloc;
                    INTERNAL.assert_with_reason(field.type == DerivedParam(def_type), @src(), "field `{s}` on output struct must be type `DerivedParam({s})`, got type `{s}`", .{@typeName(field.type)});
                    var out_field: DerivedParam(def_type) = undefined;
                    const idx = if (def.specific_index) |i| ensure_cap: {
                        cat_data.ensure_capacity(@intCast(i + 1), cat_alloc);
                        break :ensure_cap i;
                    } else cat_data.claim_one(cat_alloc).idx;
                    @field(defs, field.name).specific_index = idx;
                    cat_meta.ensure_capacity_and_zero_new(@intCast(idx + 1), cat_alloc);
                    const meta = INTERNAL.MetaData{
                        .always_update = def.always_update,
                        .delete_if_parent_deleted = def.delete_when_parent_is_deleted,
                        .if_not_deleted_set_value_default_when_parent_deleted = def.if_not_deleted_set_value_default_when_parent_deleted,
                        .generation = cat_meta.get(@intCast(idx)).generation,
                    };
                    cat_meta.set(@intCast(idx), meta);
                    out_field.category = @intCast(cat_idx);
                    out_field.index = @intCast(idx);
                    if (INTERNAL.USE_GENERATIONS) {
                        gen = @intCast(cat_meta.get(.GEN, @intCast(idx)));
                        out_field.generation = gen;
                    }
                    @field(defs, field.name) = out_field;
                }
                var out: OUTPUT_STRUCT = undefined;
                inline for (@typeInfo(DEFS).@"struct".fields) |field| {
                    const def: DerivedParamDef = @field(output_defs, field.name);
                    const cat_idx = @intFromEnum(def.category);
                    const def_type = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
                    @field(out, field.name) = DerivedParam(def_type){
                        .category = def.category,
                        .index = def.specific_index.?,
                        .generation = if (INTERNAL.USE_GENERATIONS) gen else 0,
                    };
                }
                const new_payload_package_range = INTERNAL.payload_data_pool.claim_range(@intCast(params_count), INTERNAL.payload_data_list_alloc);
                for (inputs_flat[0..], new_payload_package_range.slice[0..input_count]) |in, *opaque_param| {
                    opaque_param.* = ParamReadWriteOpaque{
                        .category = in.category,
                        .index = in.index,
                        .generation = if (INTERNAL.USE_GENERATIONS) in.generation else 0,
                    };
                }
                for (@typeInfo(DEFS).@"struct".fields, new_payload_package_range.slice[input_count..params_count]) |field, *opaque_param| {
                    opaque_param.* = ParamReadWriteOpaque{
                        .category = @field(out, field.name).category,
                        .index = @field(out, field.name).index,
                        .generation = if (INTERNAL.USE_GENERATIONS) @field(out, field.name).generation else 0,
                    };
                }
                var new_update_package: INTERNAL.UpdatePackage = undefined;
                for (inputs_flat[0..]) |input| {
                    INTERNAL.assert_with_reason(INTERNAL.categories[input.category].data.free_list.idx_is_used(@intCast(input.index)), @src(), "index {d} in category `{s}` was a free index", .{ input.index, @tagName(num_cast(input.category, CategoryName)) });
                    if (INTERNAL.USE_GENERATIONS) {
                        INTERNAL.assert_with_reason(INTERNAL.categories[input.category].meta.get(@intCast(input.index)).generation == input.generation, "index {d} in category `{s}` had mismatched generation (requested {d}, found {d})", .{ input.index, @tagName(num_cast(input.category, CategoryName)), input.generation, INTERNAL.categories[input.category].meta.get(@intCast(input.index)).generation });
                    }
                    var input_update_slice: INTERNAL.UpdateSlice = INTERNAL.categories[input.category].data.ptr_2[input.index];
                    if (input_update_slice.update_count == 0) {
                        const new_payload_slot = INTERNAL.payload_location_pool.claim_one(INTERNAL.payload_location_list_alloc);
                        input_update_slice.first_payload = @intCast(new_payload_slot.idx);
                        input_update_slice.update_count = 1;
                        new_update_package = INTERNAL.UpdatePackage{
                            .func_idx = @intCast(_func_idx),
                            .in_count = @intCast(input_count),
                            .out_count = @intCast(output_count),
                            .first_payload_index = new_payload_package_range.start_idx,
                        };
                        new_payload_slot.ptr.* = new_update_package;
                    } else {
                        const new_payload_slice = INTERNAL.payload_location_pool.resize_range(input_update_slice.first_payload, input_update_slice.update_count, input_update_slice.update_count + 1, INTERNAL.payload_location_list_alloc);
                        input_update_slice.first_payload = @intCast(new_payload_slice.start_idx);
                        input_update_slice.update_count += 1;
                        new_update_package = INTERNAL.UpdatePackage{
                            .func_idx = @intCast(_func_idx),
                            .in_count = @intCast(input_count),
                            .out_count = @intCast(output_count),
                            .first_payload_index = new_payload_package_range.start_idx,
                        };
                        new_payload_slice.slice[new_payload_slice.slice.len - 1] = new_update_package;
                    }
                }
                if (TRACK_FUNC_DEPENDANTS) {
                    var func_deps: *FuncDependantList = &func_dependants[_func_idx];
                    const package_no_func = UpdatePackageNoFunc.from_update_package(new_update_package);
                    _ = func_deps.append(package_no_func, func_dep_alloc);
                }
                INTERNAL.update_queue.queue(new_update_package, INTERNAL.update_queue_alloc);
                if (!INTERNAL.updates_in_progress) {
                    INTERNAL.updates_in_progress = true;
                    defer INTERNAL.updates_in_progress = false;
                    INTERNAL.process_all_updates_if_needed(mutex_key);
                }
            }
        };

        /// Initialize an update function.
        ///
        /// Parameters depending on a function cannot be initialized until the function is initialized
        pub fn initialize_update_function(comptime func_name: FuncName, func: *const UpdateFunction) void {
            INTERNAL.initialize_function_internal(func_name, func, .{});
        }
        /// Initialize an update function.
        ///
        /// Parameters depending on a function cannot be initialized until the function is initialized
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        pub fn initialize_update_function_during_update(comptime func_name: FuncName, func: *const UpdateFunction, mutex_key: MutexKey) void {
            INTERNAL.initialize_function_internal(func_name, func, mutex_key);
        }
        /// Delete an update function, queueing all parameters depending on it
        /// to either be deleted or set to a default value (depending on the param setting)
        pub fn delete_update_function(comptime func_name: FuncName) void {
            INTERNAL.delete_function_internal(func_name, .{});
        }
        /// Delete an update function, queueing all parameters depending on it
        /// to either be deleted or set to a default value (depending on the param setting)
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        pub fn delete_update_function_during_update(comptime func_name: FuncName, mutex_key: MutexKey) void {
            INTERNAL.delete_function_internal(func_name, mutex_key);
        }
        /// Replace an update function and queue all parameters depending on it for update
        ///
        /// This method does not increase the function generation (if enabled)
        pub fn replace_update_function(comptime func_name: FuncName, new_func: *const UpdateFunction) void {
            INTERNAL.replace_func_internal(func_name, new_func, .{});
        }
        /// Replace an update function and queue all parameters depending on it for update
        ///
        /// This method does not increase the function generation (if enabled)
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        pub fn replace_update_function_during_update(comptime func_name: FuncName, new_func: *const UpdateFunction, mutex_key: MutexKey) void {
            INTERNAL.replace_func_internal(func_name, new_func, mutex_key);
        }

        /// Get a parameter value from a specific index in a category
        ///
        /// This method skips the generation check (if enabled), whatever value
        /// is at that index is returned
        pub fn get_param_in_category(comptime category: CategoryName, index: Index) INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            return INTERNAL.get_internal(T, cat_idx, index, 0, .{}, true, false);
        }
        /// Get a parameter value from a specific index in a category
        ///
        /// This method skips the generation check (if enabled), whatever value
        /// is at that index is returned
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        pub fn get_param_in_category_during_update(comptime category: CategoryName, index: Index, mutex_key: MutexKey) INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            return INTERNAL.get_internal(T, cat_idx, index, 0, mutex_key, true, true);
        }
        /// Set a parameter value at a specific index in a category
        ///
        /// This method skips the generation check (if enabled), whatever value
        /// is at that location will be replaced unconditionally
        pub fn set_param_in_category(comptime category: CategoryName, index: Index, val: INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type) void {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            return INTERNAL.set_internal(T, cat_idx, index, 0, val, .{}, true, false);
        }
        /// Set a parameter value at a specific index in a category
        ///
        /// This method skips the generation check (if enabled), whatever value
        /// is at that location will be replaced unconditionally
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        pub fn set_param_in_category_during_update(comptime category: CategoryName, index: Index, val: INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type, mutex_key: MutexKey) void {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            return INTERNAL.set_internal(T, cat_idx, index, 0, val, mutex_key, true, true);
        }
        /// Set a parameter value at a specific index in a category,
        /// and return the old value that was there before
        ///
        /// This method skips the generation check (if enabled), whatever value
        /// is at that location will be replaced unconditionally
        pub fn set_param_get_old_in_category(comptime category: CategoryName, index: Index, val: INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type) INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            const old = INTERNAL.get_internal(T, cat_idx, index, 0, .{}, true);
            INTERNAL.set_internal(T, cat_idx, index, 0, val, .{}, true, false);
            return old;
        }
        /// Set a parameter value at a specific index in a category,
        /// and return the old value that was there before
        ///
        /// This method skips the generation check (if enabled), whatever value
        /// is at that location will be replaced unconditionally
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        pub fn set_param_get_old_in_category_during_update(comptime category: CategoryName, index: Index, val: INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type, mutex_key: MutexKey) INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            const old = INTERNAL.get_internal(T, cat_idx, index, 0, mutex_key, true);
            INTERNAL.set_internal(T, cat_idx, index, 0, val, mutex_key, true);
            return old;
        }
        /// Delete a parameter at a specific index in a category
        ///
        /// This method skips the generation check (if enabled), whatever value
        /// is at that location will be deleted unconditionally
        pub fn delete_param_in_category(comptime category: CategoryName, index: Index) void {
            const cat_idx = @intFromEnum(category);
            return INTERNAL.delete_internal(cat_idx, index, 0, .{}, true, false);
        }
        /// Delete a parameter at a specific index in a category
        ///
        /// This method skips the generation check (if enabled), whatever value
        /// is at that location will be deleted unconditionally
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        pub fn delete_param_in_category_during_update(comptime category: CategoryName, index: Index, mutex_key: MutexKey) void {
            const cat_idx = @intFromEnum(category);
            return INTERNAL.delete_internal(cat_idx, index, 0, mutex_key, true, true);
        }

        /// Make an un-ambiguous struct for read-only params
        ///
        /// The user must ensure the correct struct is used for the params:
        ///   - the struct has the same number of fields as `read_only_params_opaque.len`
        ///   - each field is in the same declared order (from top to bottom) as its matching param in the `read_only_params_opaque` list
        ///   - each field is a `DerivedParam(<param type>)`
        pub fn make_read_only_param_struct(read_only_params_opaque: []const ParamReadOnlyOpaque, comptime STRUCT: type) STRUCT {
            INTERNAL.assert_with_reason(Types.type_is_struct(STRUCT), @src(), "type `STRUCT` must be a struct type where each field is a `DerivedParam(T)`, got type `{s}`", .{@typeName(STRUCT)});
            INTERNAL.assert_with_reason(read_only_params_opaque.len == @typeInfo(STRUCT).@"struct".fields.len, @src(), "type `STRUCT` must have exactly the same number of fields as `read_only_params_opaque.len`, got fields {d} != inputs {d}", .{ @typeInfo(STRUCT).@"struct".fields.len, read_only_params_opaque.len });
            var object: STRUCT = undefined;
            inline for (@typeInfo(STRUCT).@"struct".fields, 0..) |field, f| {
                INTERNAL.assert_with_reason(Types.type_has_decl_with_type(field.type, "TYPE", type), @src(), "field `{s}` is not a valid input parameter field (missing const declaration `pub const TYPE = <param type>;`)", .{field.name});
                INTERNAL.assert_with_reason(field.type == DerivedParam(comptime @field(field.type, "TYPE")), @src(), "field `{s}` is not a valid input parameter field (is not a `DerivedParam(T)`)", .{field.name});
                @field(object, field.name) = read_only_params_opaque[f].with_type(comptime @field(field.type, "TYPE"));
            }
            return object;
        }

        /// Make an un-ambiguous struct for read-write params
        ///
        /// The user must ensure the correct struct is used for the params:
        ///   - the struct has the same number of fields as `read_write_params_opaque.len`
        ///   - each field is in the same declared order (from top to bottom) as its matching param in the `read_write_params_opaque` list
        ///   - each field is a `RootParam(<param type>)`
        pub fn make_read_write_param_struct(read_write_params_opaque: []const ParamReadWriteOpaque, comptime STRUCT: type) STRUCT {
            INTERNAL.assert_with_reason(Types.type_is_struct(STRUCT), @src(), "type `STRUCT` must be a struct type where each field is a `DerivedParam(T)`, got type `{s}`", .{@typeName(STRUCT)});
            INTERNAL.assert_with_reason(read_write_params_opaque.len == @typeInfo(STRUCT).@"struct".fields.len, @src(), "type `STRUCT` must have exactly the same number of fields as `read_write_params_opaque.len`, got fields {d} != inputs {d}", .{ @typeInfo(STRUCT).@"struct".fields.len, read_write_params_opaque.len });
            var object: STRUCT = undefined;
            inline for (@typeInfo(STRUCT).@"struct".fields, 0..) |field, f| {
                INTERNAL.assert_with_reason(Types.type_has_decl_with_type(field.type, "TYPE", type), @src(), "field `{s}` is not a valid input parameter field (missing const declaration `pub const TYPE = <param type>;`)", .{field.name});
                INTERNAL.assert_with_reason(field.type == RootParam(comptime @field(field.type, "TYPE")), @src(), "field `{s}` is not a valid input parameter field (is not a `RootParam(T)`)", .{field.name});
                @field(object, field.name) = read_write_params_opaque[f].with_type(comptime @field(field.type, "TYPE"));
            }
            return object;
        }

        pub const CategoryName = PARAM_CATEGORIES;
        pub const FuncName = FUNCTION_NAMES;
        pub const Index: type = idx_int;
        pub const MutexKey = KeyedMutex(INTERNAL.MULTITHREADED).Key;

        pub const UpdateInterface = struct {
            inputs: []const ParamReadOnlyOpaque,
            outputs: []const ParamReadWriteOpaque,
            key: MutexKey,

            /// Make an un-ambiguous struct for update function inputs
            ///
            /// The user must ensure the correct struct is used for the inputs:
            ///   - the struct has the same number of fields as `inputs.len`
            ///   - each field is in the same declared order (from top to bottom) as its matching param in the `inputs` list
            ///   - each field is a `ParamUpdateInput(<param type>)`
            pub fn make_input_struct(self: UpdateInterface, comptime IN_STRUCT: type) IN_STRUCT {
                INTERNAL.assert_with_reason(Types.type_is_struct(IN_STRUCT), @src(), "type `IN_STRUCT` must be a struct type where each field is a `ParamUpdateInput(T)`, got type `{s}`", .{@typeName(IN_STRUCT)});
                INTERNAL.assert_with_reason(self.inputs.len == @typeInfo(IN_STRUCT).@"struct".fields.len, @src(), "type `IN_STRUCT` must have exactly the same number of fields as `self.inputs.len`, got fields {d} != inputs {d}", .{ @typeInfo(IN_STRUCT).@"struct".fields.len, self.inputs.len });
                var object: IN_STRUCT = undefined;
                inline for (@typeInfo(IN_STRUCT).@"struct".fields, 0..) |field, f| {
                    INTERNAL.assert_with_reason(Types.type_has_decl_with_type(field.type, "TYPE", type), @src(), "field `{s}` is not a valid input parameter field (missing const declaration `pub const TYPE = <param type>;`)", .{field.name});
                    INTERNAL.assert_with_reason(field.type == ParamUpdateInput(comptime @field(field.type, "TYPE")), @src(), "field `{s}` is not a valid input parameter field (is not a `ParamUpdateInput(T)`)", .{field.name});
                    @field(object, field.name) = self.inputs[f].with_type_and_mutex_key(self.key, comptime @field(field.type, "TYPE"));
                }
                return object;
            }

            /// Make an un-ambiguous struct for update function outputs
            ///
            /// The user must ensure the correct struct is used for the outputs:
            ///   - the struct has the same number of fields as `outputs.len`
            ///   - each field is in the same declared order (from top to bottom) as its matching param in the `outputs` list
            ///   - each field is a `ParamUpdateOutput(<param type>)`
            pub fn make_output_struct(self: UpdateInterface, comptime OUT_STRUCT: type) OUT_STRUCT {
                INTERNAL.assert_with_reason(Types.type_is_struct(OUT_STRUCT), @src(), "type `OUT_STRUCT` must be a struct type where each field is a `ParamUpdateOutput(T)`, got type `{s}`", .{@typeName(OUT_STRUCT)});
                INTERNAL.assert_with_reason(self.outputs.len == @typeInfo(OUT_STRUCT).@"struct".fields.len, @src(), "type `OUT_STRUCT` must have exactly the same number of fields as `read_write_params_opaque.len`, got fields {d} != inputs {d}", .{ @typeInfo(OUT_STRUCT).@"struct".fields.len, self.outputs.len });
                var object: OUT_STRUCT = undefined;
                inline for (@typeInfo(OUT_STRUCT).@"struct".fields, 0..) |field, f| {
                    INTERNAL.assert_with_reason(Types.type_has_decl_with_type(field.type, "TYPE", type), @src(), "field `{s}` is not a valid input parameter field (missing const declaration `pub const TYPE = <param type>;`)", .{field.name});
                    INTERNAL.assert_with_reason(field.type == ParamUpdateOutput(comptime @field(field.type, "TYPE")), @src(), "field `{s}` is not a valid input parameter field (is not a `ParamUpdateOutput(T)`)", .{field.name});
                    @field(object, field.name) = self.outputs[f].with_type_and_mutex_key(self.key, comptime @field(field.type, "TYPE"));
                }
                return object;
            }

            /// Commits all deletions then all changes that have occured in this update, in that order.
            ///
            /// If you do not call this, no updates from any changes or deletions will be triggered,
            /// which in most cases is probably the incorrect behavior.
            pub fn commit_deletions_and_changes(self: UpdateInterface) void {
                INTERNAL.process_all_deletes_if_needed(self.key, false);
                INTERNAL.process_all_updates_if_needed(self.key);
            }
        };
        pub const UpdateFunction = fn (iface: UpdateInterface) void;
        pub fn CategoryType(comptime name: CategoryName) type {
            return INTERNAL.CATEGORY_DEFS[@intFromEnum(name)].param_type;
        }
        pub fn RootParam(comptime T: type) type {
            return packed struct {
                const TYPE = T;
                const THIS_TYPE_ID: INTERNAL.CategoryId = find: {
                    for (INTERNAL.UNIQUE_TYPES[0..], 0..) |TT, i| {
                        if (T == TT) break :find INTERNAL.UNIQUE_TYPE_IDS[i];
                    }
                    INTERNAL.assert_unreachable(null, "type `{s}` is not valid for ANY category in the ParametricStateSystem, this is not a valid Param type", .{@typeName(T)});
                    break :find 0;
                };

                const ParamSelf = @This();
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                category: INTERNAL.CategoryId,
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                index: Index,
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                generation: INTERNAL.GenId,

                pub fn to_opaque_input(self: RootParam) ParamReadOnlyOpaque {
                    return @bitCast(self);
                }
                pub fn to_opaque(self: RootParam) ParamReadWriteOpaque {
                    return @bitCast(self);
                }

                /// Delete the parameter
                pub fn delete(self: ParamSelf) void {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    INTERNAL.delete_internal(self.category, self.index, self.generation, .{}, false, false);
                }

                /// Set the parameter value
                pub fn set(self: ParamSelf, val: T) void {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    INTERNAL.set_internal(T, self.category, self.index, self.generation, val, .{}, false, false);
                }

                /// Set the parameter value and return the old value it had
                pub fn set_and_get_old(self: ParamSelf, val: T) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    const old = INTERNAL.get_internal(T, self.category, self.index, self.generation, .{}, false);
                    INTERNAL.set_internal(T, self.category, self.index, self.generation, val, .{}, false, false);
                    return old;
                }

                /// Get the parameter value
                pub fn get(self: ParamSelf) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    return INTERNAL.get_internal(T, self.category, self.index, self.generation, .{}, false);
                }

                pub fn as_input(self: ParamSelf) ParamUpdateInput(T) {
                    return @bitCast(self);
                }
            };
        }
        pub fn ParamUpdateOutput(comptime T: type) type {
            return packed struct {
                const TYPE = T;
                const THIS_TYPE_ID: INTERNAL.CategoryId = find: {
                    for (INTERNAL.UNIQUE_TYPES[0..], 0..) |TT, i| {
                        if (T == TT) break :find INTERNAL.UNIQUE_TYPE_IDS[i];
                    }
                    INTERNAL.assert_unreachable(null, "type `{s}` is not valid for ANY category in the ParametricStateSystem, this is not a valid Param type", .{@typeName(T)});
                    break :find 0;
                };

                const ParamSelf = @This();

                param: RootParam(T),
                key: MutexKey,

                /// Delete the parameter
                ///
                /// This method DOES NOT TRIGGER UPDATES until the `UpdateInterface.commit_deletions_and_changes()` method is called
                pub fn delete(self: ParamSelf) void {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    INTERNAL.delete_internal(self.param.category, self.param.index, self.param.generation, self.key, false, true);
                }

                /// Set the parameter value
                ///
                /// This method DOES NOT TRIGGER UPDATES until the `UpdateInterface.commit_deletions_and_changes()` method is called
                pub fn set(self: ParamSelf, val: T) void {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    INTERNAL.set_internal(T, self.param.category, self.param.index, self.param.generation, val, self.key, false, true);
                }

                /// Set the parameter value and return the old value it had
                ///
                /// This method DOES NOT TRIGGER UPDATES until the `UpdateInterface.commit_deletions_and_changes()` method is called
                pub fn set_and_get_old(self: ParamSelf, val: T) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    const old = INTERNAL.get_internal(T, self.param.category, self.param.index, self.param.generation, self.key, false);
                    INTERNAL.set_internal(T, self.param.category, self.param.index, self.param.generation, val, self.key, false, true);
                    return old;
                }

                /// Get the parameter value
                pub fn get(self: ParamSelf) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    return INTERNAL.get_internal(T, self.param.category, self.param.index, self.param.generation, self.key, false);
                }
            };
        }
        pub const ParamReadWriteOpaque = packed struct {
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            category: INTERNAL.CategoryId,
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            index: Index,
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            generation: INTERNAL.GenId,

            /// Delete the parameter
            pub fn delete(self: ParamReadWriteOpaque) void {
                INTERNAL.delete_internal(self.category, self.index, self.generation, .{}, false, false);
            }

            pub fn with_type(self: ParamReadWriteOpaque, comptime T: type) RootParam(T) {
                INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{ @tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(INTERNAL.CATEGORY_DEFS[self.category].param_type), @typeName(T) });
                return @bitCast(self);
            }
            pub fn with_type_and_mutex_key(self: ParamReadWriteOpaque, key: MutexKey, comptime T: type) ParamUpdateOutput(T) {
                INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{ @tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(INTERNAL.CATEGORY_DEFS[self.category].param_type), @typeName(T) });
                return ParamUpdateOutput(T){
                    .param = @bitCast(self),
                    .key = key,
                };
            }
        };
        pub fn DerivedParam(comptime T: type) type {
            return packed struct {
                const TYPE = T;
                const THIS_TYPE_ID: INTERNAL.CategoryId = find: {
                    for (INTERNAL.UNIQUE_TYPES[0..], 0..) |TT, i| {
                        if (T == TT) break :find INTERNAL.UNIQUE_TYPE_IDS[i];
                    }
                    INTERNAL.assert_unreachable(null, "type `{s}` is not valid for ANY category in the ParametricStateSystem, this is not a valid Param type", .{@typeName(T)});
                    break :find 0;
                };
                const ParamSelf = @This();

                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                category: INTERNAL.CategoryId,
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                index: Index,
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                generation: INTERNAL.GenId,

                /// Delete the parameter
                pub fn delete(self: ParamSelf) void {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    INTERNAL.delete_internal(self.category, self.index, self.generation, .{}, false, false);
                }

                /// Get the parameter value
                pub fn get(self: ParamSelf) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    return INTERNAL.get_internal(T, self.category, self.index, self.generation, .{}, false);
                }

                pub fn as_input(self: ParamSelf) ParamUpdateInput(T) {
                    return @bitCast(self);
                }
            };
        }
        pub fn ParamUpdateInput(comptime T: type) type {
            return struct {
                const TYPE = T;
                const THIS_TYPE_ID: INTERNAL.CategoryId = find: {
                    for (INTERNAL.UNIQUE_TYPES[0..], 0..) |TT, i| {
                        if (T == TT) break :find INTERNAL.UNIQUE_TYPE_IDS[i];
                    }
                    INTERNAL.assert_unreachable(null, "type `{s}` is not valid for ANY category in the ParametricStateSystem, this is not a valid Param type", .{@typeName(T)});
                    break :find 0;
                };
                const ParamSelf = @This();

                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                param: DerivedParam(T),
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                key: MutexKey,

                /// Delete the parameter
                ///
                /// This method DOES NOT TRIGGER UPDATES until the `UpdateInterface.commit_deletions_and_changes()` method is called
                pub fn delete(self: ParamSelf) void {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    INTERNAL.delete_internal(self.param.category, self.param.index, self.param.generation, self.key, false, true);
                }

                /// Get the parameter value
                pub fn get(self: ParamSelf) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    return INTERNAL.get_internal(T, self.param.category, self.param.index, self.param.generation, self.key, false);
                }

                pub fn to_opaque(self: ParamSelf) ParamReadOnlyOpaque {
                    return @bitCast(self.param);
                }
            };
        }
        pub const ParamReadOnlyOpaque = packed struct {
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            category: INTERNAL.CategoryId,
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            index: Index,
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            generation: INTERNAL.GenId,

            pub fn delete(self: ParamReadWriteOpaque) void {
                INTERNAL.delete_internal(self.category, self.index, self.generation, .{}, false, false);
            }

            pub fn with_type(self: ParamReadOnlyOpaque, comptime T: type) DerivedParam(T) {
                INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{ @tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(INTERNAL.CATEGORY_DEFS[self.category].param_type), @typeName(T) });
                return @bitCast(self);
            }
            pub fn with_type_and_mutex_key(self: ParamReadOnlyOpaque, key: MutexKey, comptime T: type) ParamUpdateInput(T) {
                INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{ @tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(INTERNAL.CATEGORY_DEFS[self.category].param_type), @typeName(T) });
                return ParamUpdateInput(T){
                    .param = @bitCast(self),
                    .key = key,
                };
            }
        };

        /// Create a new 'Root' parameter at a specific index. Root parameters are not dependant on any other parameter and
        /// are never automatically updated.
        ///
        /// Any parameter depending on a root parameter cannot be initialized if the root parameter is not initialized
        pub fn create_new_root_param_at_specific_index(comptime category: CategoryName, index: Index, initial_val: CategoryType(category), update_mode: AlwaysUpdateMode) RootParam(CategoryType(category)) {
            return INTERNAL.create_new_root_param_internal(category, index, initial_val, update_mode, .{});
        }
        /// Create a new 'Root' parameter at the next free index. Root parameters are not dependant on any other parameter and
        /// are never automatically updated.
        ///
        /// Any parameter depending on a root parameter cannot be initialized if the root parameter is not initialized
        pub fn create_new_root_param(comptime category: CategoryName, initial_val: CategoryType(category), update_mode: AlwaysUpdateMode) RootParam(CategoryType(category)) {
            return INTERNAL.create_new_root_param_internal(category, null, initial_val, update_mode, .{});
        }
        /// Create a new 'Root' parameter at a specific index. Root parameters are not dependant on any other parameter and
        /// are never automatically updated.
        ///
        /// Any parameter depending on a root parameter cannot be initialized if the root parameter is not initialized
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        pub fn create_new_root_param_at_specific_index_during_update(comptime category: CategoryName, index: Index, initial_val: CategoryType(category), update_mode: AlwaysUpdateMode, _mutex_key: MutexKey) RootParam(CategoryType(category)) {
            return INTERNAL.create_new_root_param_internal(category, index, initial_val, update_mode, _mutex_key);
        }
        /// Create a new 'Root' parameter at the next free index. Root parameters are not dependant on any other parameter and
        /// are never automatically updated.
        ///
        /// Any parameter depending on a root parameter cannot be initialized if the root parameter is not initialized
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        pub fn create_new_root_param_during_update(comptime category: CategoryName, initial_val: CategoryType(category), update_mode: AlwaysUpdateMode, _mutex_key: MutexKey) RootParam(CategoryType(category)) {
            return INTERNAL.create_new_root_param_internal(category, null, initial_val, update_mode, _mutex_key);
        }

        pub const DerivedParamDef = struct {
            category: CategoryName,
            always_update: bool = false,
            delete_when_parent_is_deleted: bool = false,
            if_not_deleted_set_value_default_when_parent_deleted: bool = false,
            specific_index: ?Index = null,
        };

        /// Create a set of related 'Derived' parameters that are all calculated by the same update function.
        /// When *any* input parameter is changed, the update function will be called, potentially changing some or all
        /// of the output parameters.
        ///
        /// Param `output_defs` MUST be a struct where every field is a `DerivedParamDef`
        ///
        /// Param `OUTPUT_STRUCT` MUST be a struct TYPE where each field name matches a field nam on `output_defs`,
        /// and each field type is a `DerivedParam(T)` where `T` is the type of the parameter Category it belonds to.
        ///
        /// When called, the function pointer associated with `update_function_name` will recieve the specified opaque read-only input param slice,
        /// as well as an opaque read/write output param slice *IN THE SAME ORDER AS THE FIELDS ON `OUTPUT_STRUCT`*
        ///
        /// `OUTPUT_STRUCT` exists soley to act as an unambiguous target for the parameters created by `output_defs` to be mapped to and returned to the user,
        /// but you can re-use that struct type within the function body
        pub fn create_new_derived_param_set(update_function: FuncName, inputs: anytype, output_defs: anytype, comptime OUTPUT_STRUCT: type) OUTPUT_STRUCT {
            INTERNAL.create_new_derived_param_set_internal(update_function, inputs, output_defs, OUTPUT_STRUCT, .{});
        }

        /// Create a set of related 'Derived' parameters that are all calculated by the same update function.
        /// When *any* input parameter is changed, the update function will be called, potentially changing some or all
        /// of the output parameters.
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        ///
        /// Param `output_defs` MUST be a struct where every field is a `DerivedParamDef`
        ///
        /// Param `OUTPUT_STRUCT` MUST be a struct TYPE where each field name matches a field nam on `output_defs`,
        /// and each field type is a `DerivedParam(T)` where `T` is the type of the parameter Category it belonds to.
        ///
        /// When called, the function pointer associated with `update_function_name` will recieve the specified opaque read-only input param slice,
        /// as well as an opaque read/write output param slice *IN THE SAME ORDER AS THE FIELDS ON `OUTPUT_STRUCT`*
        ///
        /// `OUTPUT_STRUCT` exists soley to act as an unambiguous target for the parameters created by `output_defs` to be mapped to and returned to the user,
        /// but you can re-use that struct type within the function body to re-build a set of named parameters
        pub fn create_new_derived_param_set_during_update(update_function: FuncName, inputs: anytype, output_defs: anytype, comptime OUTPUT_STRUCT: type, mutex_key: MutexKey) OUTPUT_STRUCT {
            INTERNAL.create_new_derived_param_set_internal(update_function, inputs, output_defs, OUTPUT_STRUCT, mutex_key);
        }

        /// Create a new 'Derived' parameter.
        /// When *any* input parameter is changed, the update function will be called, potentially changing the derived parameter.
        ///
        /// When called, the update function pointer associated with `update_function_name` will recieve the specified opaque read-only input param slice,
        /// as well as a single opaque read/write output param
        pub fn create_new_derived_param(update_function: FuncName, inputs: anytype, output_def: DerivedParamDef, comptime OUTPUT_TYPE: type) DerivedParam(OUTPUT_TYPE) {
            const DEF_PROTO = struct {
                param: DerivedParamDef,
            };
            const defs = DEF_PROTO{
                .param = output_def,
            };
            const OUT_PROTO = struct {
                param: DerivedParam(OUTPUT_TYPE),
            };
            const out = INTERNAL.create_new_derived_param_set_internal(update_function, inputs, defs, OUT_PROTO, .{});
            return out.param;
        }

        /// Create a new 'Derived' parameter.
        /// When *any* input parameter is changed, the update function will be called, potentially changing the derived parameter.
        ///
        /// provide the `mutex_key` from the update function you are calling this from
        ///
        /// When called, the update function pointer associated with `update_function_name` will recieve the specified opaque read-only input param slice,
        /// as well as a single opaque read/write output param
        pub fn create_new_derived_param_during_update(update_function: FuncName, inputs: anytype, output_def: DerivedParamDef, comptime OUTPUT_TYPE: type, mutex_key: MutexKey) DerivedParam(OUTPUT_TYPE) {
            const DEF_PROTO = struct {
                param: DerivedParamDef,
            };
            const defs = DEF_PROTO{
                .param = output_def,
            };
            const OUT_PROTO = struct {
                param: DerivedParam(OUTPUT_TYPE),
            };
            const out = INTERNAL.create_new_derived_param_set_internal(update_function, inputs, defs, OUT_PROTO, mutex_key);
            return out.param;
        }
    };
}

test "ParametricStateSystem" {
    const Test = Root.Testing;
    const do_debug = true;
    const settings = Settings{
        .ALLOW_FUNCTION_DELETION = true,
        .ALLOW_FUNCTION_REPLACEMENT = true,
        .ALLOWED_RECURSIVE_UPDATES = 0,
        .CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES = true,
        .DELETE_DEPENDANT_PARAMETERS_WHEN_FUNCTION_DELETED = true,
        .ENABLE_THREAD_SAFETY = true,
        .INDEX_GENERATION_MODE = .{ .PER_PARAMETER_INDEX_GENERATION_INT_POWER = ._256 },
        .MASTER_ASSERT_MODE = .ALWAYS_PANIC,
        .MAX_NUM_FUNCTION_INPUTS = 8,
        .MAX_NUM_FUNCTION_OUTPUTS = 8,
        .MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE = 16,
        .MAX_NUM_UNIQUE_FUNCTION_PAYLOADS = 65536,
        .MAX_NUM_VALUES_IN_ANY_CATEGORY = 65536,
        .MAX_PAYLOAD_LIST_LIMIT = 65536,
        .PAYLOAD_LIST_USES_STATIC_MEMORY = true,
        .PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY = true,
        .RECURSION_ASSERT_MODE = .ALWAYS_PANIC,
        .UNIQUE_UPDATE_QUEUE_STATIC_LENGTH = 1024,
        .UPDATE_QUEUE_STATIC_LENGTH = 1024,
    };
    const Cats = enum(u3) {
        POSITIONS,
        SIZES,
        AREAS,
        SCALARS,
        CAT_LENS,
    };
    const Funcs = enum(u2) {
        VEC_PLUS_SCALAR,
        HALF_VEC_MINUS_2_SCALAR,
        LINKED_AREA_PARENT_AND_BUTTON,
    };
    const CatDef = CategoryTypeDef(Cats);
    const Vec = Root.Vec2.define_vec2_type(f32);
    const F32_ZERO: f32 = 0;
    const PROTO = struct {
        fn f32_equals(a: f32, b: f32) bool {
            return a == b;
        }
        fn u2_equals(a: u2, b: u2) bool {
            return a == b;
        }
    };
    const PSS = comptime ParametricStateSystem(settings, Cats, .{
        CatDef{
            .category = .POSITIONS,
            .allow_free_slots = false,
            .default_value_for_type = @ptrCast(&Vec.ZERO),
            .expected_maximum_num_params = 2,
            .maximum_is_guaranteed = true,
            .param_type = Vec,
            .type_equality_func = Vec.equals,
        },
        CatDef{
            .category = .SIZES,
            .allow_free_slots = true,
            .default_value_for_type = @ptrCast(&Vec.ZERO),
            .expected_maximum_num_params = 2,
            .maximum_is_guaranteed = false,
            .param_type = Vec,
            .type_equality_func = Vec.equals,
        },
        CatDef{
            .category = .AREAS,
            .allow_free_slots = true,
            .default_value_for_type = @ptrCast(&F32_ZERO),
            .expected_maximum_num_params = 0,
            .maximum_is_guaranteed = false,
            .param_type = f32,
            .type_equality_func = PROTO.f32_equals,
        },
        CatDef{
            .category = .SCALARS,
            .allow_free_slots = true,
            .default_value_for_type = @ptrCast(&F32_ZERO),
            .expected_maximum_num_params = 1,
            .maximum_is_guaranteed = true,
            .param_type = f32,
            .type_equality_func = PROTO.f32_equals,
        },
        CatDef{
            .category = .CAT_LENS,
            .allow_free_slots = false,
            .default_value_for_type = null,
            .expected_maximum_num_params = 4,
            .maximum_is_guaranteed = true,
            .param_type = u2,
            .type_equality_func = PROTO.u2_equals,
        },
    }, Funcs);
    const CalcIface = PSS.UpdateInterface;
    const RootParam = PSS.RootParam;
    const DerivedParam = PSS.DerivedParam;
    const ParamUpdateInput = PSS.ParamUpdateInput;
    const ParamUpdateOutput = PSS.ParamUpdateOutput;
    const DerivedParamDef = PSS.DerivedParamDef;
    const VecAndScalarIn = struct {
        vec: ParamUpdateInput(Vec),
        scalar: ParamUpdateInput(f32),
    };
    const VecOut = struct {
        vec: ParamUpdateOutput(Vec),
    };
    // const F32Object = struct {
    //     a: f32,
    // };
    const ParentSizeButtonSizeIn = struct {
        parent_size: ParamUpdateInput(Vec),
        button_size: ParamUpdateInput(Vec),
    };
    const ParentAreaButtonAreaOutDef = struct {
        parent_area: DerivedParamDef,
        button_area: DerivedParamDef,
        total_area: DerivedParamDef,
    };
    const ParentAreaButtonAreaOut = struct {
        parent_area: ParamUpdateOutput(f32),
        button_area: ParamUpdateOutput(f32),
        total_area: ParamUpdateOutput(f32),
    };
    const CALC = struct {
        fn vec_plus_scalar(iface: CalcIface) void {
            const in = iface.make_input_struct(VecAndScalarIn);
            const out = iface.make_output_struct(VecOut);
            const vec_in = in.vec.get();
            const scalar = in.scalar.get();
            const vec_out = vec_in.add(Vec{ .x = scalar, .y = scalar });
            out.vec.set(vec_out);
            iface.commit_deletions_and_changes();
        }
        fn half_vec_minus_2_scalar(iface: CalcIface) void {
            const in = iface.make_input_struct(VecAndScalarIn);
            const out = iface.make_output_struct(VecOut);
            const vec_in = in.vec.get();
            const scalar = in.scalar.get();
            const vec_out = vec_in.scale(0.5).subtract_scale(Vec{ .x = scalar, .y = scalar }, 2);
            out.vec.set(vec_out);
            iface.commit_deletions_and_changes();
        }
        fn linked_area_parent_and_button(iface: CalcIface) void {
            const in = iface.make_input_struct(ParentSizeButtonSizeIn);
            const out = iface.make_output_struct(ParentAreaButtonAreaOut);
            const parent_size = in.parent_size.get();
            const button_size = in.button_size.get();
            const parent_area = parent_size.component_mult();
            const button_area = button_size.component_mult();
            const total_area = parent_area + button_area;
            out.parent_area.set(parent_area);
            out.button_area.set(button_area);
            out.total_area.set(total_area);
            iface.commit_deletions_and_changes();
        }
    };

    PSS.initialize_update_function(.VEC_PLUS_SCALAR, CALC.vec_plus_scalar);
    PSS.initialize_update_function(.HALF_VEC_MINUS_2_SCALAR, CALC.half_vec_minus_2_scalar);
    PSS.initialize_update_function(.LINKED_AREA_PARENT_AND_BUTTON, CALC.linked_area_parent_and_button);

    const ParentPos = PSS.create_new_root_param(.POSITIONS, Vec{ .x = 100.0, .y = 200.0 }, .ONLY_UPDATE_ON_VALUE_CHANGE);
    const ParentSize = PSS.create_new_root_param(.SIZES, Vec{ .x = 800.0, .y = 600.0 }, .ONLY_UPDATE_ON_VALUE_CHANGE);

    const Margin = PSS.create_new_root_param(.SCALARS, 32.0, .ONLY_UPDATE_ON_VALUE_CHANGE);

    const ButtonPos = PSS.create_new_derived_param(.VEC_PLUS_SCALAR, VecAndScalarIn{
        .scalar = Margin.as_input(),
        .vec = ParentPos.as_input(),
    }, PSS.DerivedParamDef{ .category = .POSITIONS }, Vec);
    const ButtonSize = PSS.create_new_derived_param(.HALF_VEC_MINUS_2_SCALAR, VecAndScalarIn{
        .scalar = Margin.as_input(),
        .vec = ParentPos.as_input(),
    }, PSS.DerivedParamDef{ .category = .SIZES }, Vec);

    const Areas = PSS.create_new_derived_param_set(.LINKED_AREA_PARENT_AND_BUTTON, ParentSizeButtonSizeIn{
        .parent_size = ParentSize.as_input(),
        .button_size = ButtonSize.as_input(),
    }, ParentAreaButtonAreaOutDef{
        .parent_area = .{ .category = .AREAS },
        .button_area = .{ .category = .AREAS },
        .total_area = .{ .category = .AREAS },
    }, ParentAreaButtonAreaOut);

    const debug = struct {
        pub fn print_vals(parent_pos: RootParam(Vec), parent_size: RootParam(Vec), parent_area: DerivedParam(f32), button_pos: RootParam(Vec), button_size: RootParam(Vec), button_area: DerivedParam(f32), total_area: DerivedParam(f32)) void {
            std.debug.print("       X     Y     W     H       A\nP: {d: >5} {d: >5} {d: >5} {d: >5} {d: >7}\nB: {d: >5} {d: >5} {d: >5} {d: >5} {d: >7}\nT:                         {d: >7}\n", .{
                parent_pos.get().x, parent_pos.get().y, parent_size.get().x, parent_size.get().y, parent_area.get(),
                button_pos.get().x, button_pos.get().y, button_size.get().x, button_size.get().y, button_area.get(),
                total_area.get(),
            });
        }
        pub fn print_ids(parent_pos: RootParam(Vec), parent_size: RootParam(Vec), parent_area: DerivedParam(f32), button_pos: RootParam(Vec), button_size: RootParam(Vec), button_area: DerivedParam(f32), total_area: DerivedParam(f32)) void {
            std.debug.print("       X     Y     W     H     A\nP: {d: >5} {d: >5} {d: >5} {d: >5} {d: >5}\nB: {d: >5} {d: >5} {d: >5} {d: >5} {d: >5}\nT:                         {d: >5}\n", .{
                parent_pos.index, parent_pos.index, parent_size.index, parent_size.index, parent_area.index,
                button_pos.index, button_pos.index, button_size.index, button_size.index, button_area.index,
                total_area.index,
            });
        }
    };

    if (do_debug) {
        debug.print_ids(ParentPos, ParentSize, Areas.parent_area, ButtonPos, ButtonSize, Areas.button_area, Areas.total_area);
        debug.print_vals(ParentPos, ParentSize, Areas.parent_area, ButtonPos, ButtonSize, Areas.button_area, Areas.total_area);
    }

    try Test.expect_equal(ButtonPos.get().x, "ButtonPos.get().x", 132.0, "132.0", "failed automatic update", .{});
    try Test.expect_equal(ButtonPos.get().y, "ButtonPos.get().y", 232.0, "232.0", "failed automatic update", .{});
    try Test.expect_equal(ButtonSize.get().x, "ButtonSize.get().x", 336.0, "336.0", "failed automatic update", .{});
    try Test.expect_equal(ButtonSize.get().y, "ButtonSize.get().y", 236.0, "236.0", "failed automatic update", .{});

    try Test.expect_equal(Areas.parent_area.get(), "Areas.parent_area.get()", 480000.0, "480000.0", "failed automatic update", .{});
    try Test.expect_equal(Areas.button_area.get(), "Areas.button_area.get()", 79296.0, "79296.0", "failed automatic update", .{});
    try Test.expect_equal(Areas.total_area.get(), "Areas.total_area.get()", 559296.0, "559296.0", "failed automatic update", .{});

    ParentSize.set(Vec{ .x = 990.0, .y = 333.0 });
    Margin.set(48.0);

    if (do_debug) {
        debug.print_ids(ParentPos, ParentSize, Areas.parent_area, ButtonPos, ButtonSize, Areas.button_area, Areas.total_area);
        debug.print_vals(ParentPos, ParentSize, Areas.parent_area, ButtonPos, ButtonSize, Areas.button_area, Areas.total_area);
    }

    try Test.expect_equal(ButtonPos.get().x, "ButtonPos.get().x", 148.0, "148.0", "failed automatic update", .{});
    try Test.expect_equal(ButtonPos.get().y, "ButtonPos.get().y", 381.0, "381.0", "failed automatic update", .{});
    try Test.expect_equal(ButtonSize.get().x, "ButtonSize.get().x", 399.0, "399.0", "failed automatic update", .{});
    try Test.expect_equal(ButtonSize.get().y, "ButtonSize.get().y", 204.0, "204.0", "failed automatic update", .{});

    try Test.expect_equal(Areas.parent_area.get(), "Areas.parent_area.get()", 594000.0, "594000.0", "failed automatic update", .{});
    try Test.expect_equal(Areas.button_area.get(), "Areas.button_area.get()", 81396.0, "81396.0", "failed automatic update", .{});
    try Test.expect_equal(Areas.total_area.get(), "Areas.total_area.get()", 675396.0, "675396.0", "failed automatic update", .{});

    // if (do_debug) {
    //     std.debug.print("TestTable MEM: {d} bytes\n", .{my_param_table.total_memory_footprint()});
    // }
}
