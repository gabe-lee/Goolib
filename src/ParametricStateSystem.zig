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
    /// How to handle assertions in internal functions
    MASTER_ASSERT_MODE: Root.CommonTypes.AssertBehavior,
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
    /// the maximum number of unique function pointers that can be used to update parameters
    ///
    /// The same function pointer can take different payloads, so this should be less than `MAX_NUM_UNIQUE_FUNCTION_PAYLOADS`
    MAX_NUM_UNIQUE_FUNCTION_POINTERS: comptime_int = 256,
    /// If set to `true`, the function pointer list will use a static memory block attatched to the
    /// `ParametricStateSystem` type. The size of this list will be `@sizeOf(usize) * MAX_NUM_UNIQUE_FUNCTION_POINTERS`
    FUNCTION_LIST_USES_STATIC_MEMORY: bool = true,
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
    /// The maximum total number of values that have derivative values
    ///
    /// This is only used when `UPDATE_TRIGGER_LIST_USES_STATIC_MEMORY == true`,
    /// otherwise the technical limit is actually `<number of categories> * MAX_NUM_VALUES_IN_ANY_CATEGORY`
    MAX_NUM_TOTAL_VALUES_THAT_CAN_TRIGGER_UPDATES_FOR_STATIC_UPDATE_LIST: comptime_int = 65535,
    /// If set to `true`, the trigger update list will use a static memory block attatched to the
    /// `ParametricStateSystem` type. The size of this list will be `(<size of integer that holds both payload location index and number of updates>) * MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE`
    UPDATE_TRIGGER_LIST_USES_STATIC_MEMORY: bool = false,
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
) type {
    ct_assert_with_reason(Types.type_is_enum(PARAM_CATEGORIES) and Types.all_enum_values_start_from_zero_with_no_gaps(PARAM_CATEGORIES), @src(), "type `PARAM_CATEGORIES` must be an enum type with tag values from 0 to max with no gaps, got type `{s}`", .{@typeName(PARAM_CATEGORIES)});
    // ct_assert_with_reason(Types.type_is_enum(FUNCTION_NAMES) and Types.all_enum_values_start_from_zero_with_no_gaps(FUNCTION_NAMES), @src(), "type `FUNCTION_NAMES` must be an enum type with tag values from 0 to max with no gaps, got type `{s}`", .{@typeName(FUNCTION_NAMES)});
    const _NUM_CATEGORIES = Types.enum_defined_field_count(PARAM_CATEGORIES);
    // const __NUM_FUNCTIONS = Types.enum_defined_field_count(FUNCTION_NAMES);
    const _MAX_CATEGORIES_IDX = PowerOf2.round_up_to_power_of_2(@as(usize, _NUM_CATEGORIES));
    // const _MAX_FUNCTIONS_IDX = PowerOf2.round_up_to_power_of_2(@as(usize, __NUM_FUNCTIONS));
    const idx_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY).unsigned_integer_type_that_holds_all_values_less_than();
    const cat_int = _MAX_CATEGORIES_IDX.unsigned_integer_type_that_holds_all_values_less_than();
    const func_idx = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_UNIQUE_FUNCTION_POINTERS).unsigned_integer_type_that_holds_all_values_less_than();
    const func_input_count_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_FUNCTION_INPUTS).unsigned_integer_type_that_holds_all_values_less_than();
    const func_output_count_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_FUNCTION_OUTPUTS).unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_UNIQUE_FUNCTION_PAYLOADS).unsigned_integer_type_that_holds_all_values_less_than();
    const func_payload_offset_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_PAYLOAD_LIST_LIMIT).unsigned_integer_type_that_holds_all_values_less_than();
    const update_count_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE).unsigned_integer_type_that_holds_all_values_less_than();
    const SUBROUTINE = struct {
        fn param_cat_align_lesser(a: PARAM_CATEGORIES, b: PARAM_CATEGORIES, userdata: [_NUM_CATEGORIES]CategoryTypeDefUnnamed) bool {
            return @alignOf(userdata[@intFromEnum(a)].param_type) < @alignOf(userdata[@intFromEnum(b)].param_type);
        }
    };
    comptime var categories_defined: [_NUM_CATEGORIES]bool = @splat(false);
    comptime var ordered_category_defs: [_NUM_CATEGORIES]CategoryTypeDefUnnamed = undefined;
    comptime var ordered_category_type_sizes: [_NUM_CATEGORIES]comptime_int = undefined;
    comptime var total_static_mem_bytes: usize = 0;
    comptime var total_static_free_bit_blocks: usize = 0;
    comptime var static_mem_largest_align: usize = 1;
    comptime var static_categories_ordered_by_param_align: [_NUM_CATEGORIES]PARAM_CATEGORIES = undefined;
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
            total_static_free_bit_blocks += PowerOf2.USIZE_POWER.align_value_forward(def.expected_maximum_num_params) >> PowerOf2.USIZE_BITS_SHIFT;
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
        ct_assert_with_reason(SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value() >= _NUM_CATEGORIES, @src(), "when `CATEGORY_WITH_LARGEST_INDEX_IS_META_CATEGORY_DESCRIBING_THE_PARAMETER_LENGTHS_OF_OTHER_CATEGORIES` is true, `SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value() >= _NUM_CATEGORIES` must ALSO be true, but got {d} < {d}", .{ SETTINGS.MAX_NUM_VALUES_IN_ANY_CATEGORY.value(), _NUM_CATEGORIES });
        const last_def_idx = _NUM_CATEGORIES - 1;
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
    comptime var static_category_free_bit_block_starts: [static_categories_ordered_by_param_align_len_const + 1]usize = undefined;
    comptime var static_category_mem_starts_current_start: usize = 0;
    comptime var static_category_free_bit_block_starts_current_start: usize = 0;
    if (static_categories_ordered_by_param_align_len > 0) {
        inline for (static_categories_ordered_by_param_align_const[0..], 0..) |cat, i| {
            const cat_idx = @intFromEnum(cat);
            const mem_size = @sizeOf(ordered_category_defs_const[cat_idx].param_type) * ordered_category_defs_const[cat_idx].expected_maximum_num_params;
            static_category_mem_starts[i] = static_category_mem_starts_current_start;
            static_category_free_bit_block_starts[i] = static_category_free_bit_block_starts_current_start;
            static_category_mem_starts_current_start += mem_size;
            static_category_free_bit_block_starts_current_start += PowerOf2.USIZE_POWER.align_value_forward(ordered_category_defs_const[cat_idx].expected_maximum_num_params) >> PowerOf2.USIZE_BITS_SHIFT;
        }
        static_category_mem_starts[static_categories_ordered_by_param_align_len_const] = static_category_mem_starts_current_start;
    }
    static_category_mem_starts[static_categories_ordered_by_param_align_len_const] = static_category_mem_starts_current_start;
    static_category_free_bit_block_starts[static_categories_ordered_by_param_align_len_const] = static_category_free_bit_block_starts_current_start;
    const static_category_mem_starts_const = static_category_mem_starts;
    const static_category_free_bit_block_starts_const = static_category_free_bit_block_starts;
    const total_static_mem_bytes_const = total_static_mem_bytes;
    const total_static_free_bit_blocks_const = total_static_free_bit_blocks;
    return struct {
        const System = @This();
        // CATEGORIES
        pub const CATEGORY_DEFS = ordered_category_defs_const;
        pub const CATEGORY_SIZES = ordered_category_type_sizes_const;
        pub const CategoryName = PARAM_CATEGORIES;
        pub const NUM_CATEGORIES = _NUM_CATEGORIES;
        pub const CategoryPool = SimplePoolOpaque(IndexId, false);
        pub const Category = struct {
            pool: CategoryPool = .{},
            alloc: Allocator = DummyAllocator.allocator_panic_free_noop,
        };
        pub const CategoryId: type = cat_int;
        pub const IndexId: type = idx_int;
        pub const STATIC_MEM_LEN = total_static_mem_bytes_const;
        pub const STATIC_FREE_BIT_BLOCK_LEN = total_static_free_bit_blocks_const;
        pub const STATIC_MEM_ALIGN = static_mem_largest_align_const;
        pub const STATIC_MEM_STARTS = static_category_mem_starts_const;
        pub const STATIC_FREE_BIT_BLOCK_STARTS = static_category_free_bit_block_starts_const;
        pub var static_param_memory: [STATIC_MEM_LEN]u8 align(STATIC_MEM_ALIGN) = undefined;
        pub var static_free_block_memory: [STATIC_FREE_BIT_BLOCK_LEN]usize = @splat(math.maxInt(usize));
        pub var categories: [NUM_CATEGORIES]Category = build: {
            var out: [NUM_CATEGORIES]Category = undefined;
            next_cat: for (0..NUM_CATEGORIES) |cat_idx| {
                const cat: CategoryName = @enumFromInt(cat_idx);
                const def = CATEGORY_DEFS[cat_idx];
                for (static_categories_ordered_by_param_align_const[0..], 0..) |cat_with_static_mem, static_idx| {
                    if (cat == cat_with_static_mem) {
                        const static_start = STATIC_MEM_STARTS[static_idx];
                        const free_bit_block_start = STATIC_FREE_BIT_BLOCK_STARTS[static_idx];
                        const free_bit_block_end = STATIC_FREE_BIT_BLOCK_STARTS[static_idx + 1];
                        out[cat_idx] = Category{
                            .alloc = DummyAllocator.allocator_panic_free_noop,
                            .pool = .{
                                .ptr = @ptrCast(@alignCast(&static_param_memory[static_start])),
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
                        };
                        continue :next_cat;
                    }
                }
                out[cat_idx] = Category{};
            }
            break :build out;
        };
        // UPDATE TRIGGERS
        pub const UpdateTriggerCount: type = update_count_int;
        pub const PayloadId: type = func_payload_int;
        pub const MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE = SETTINGS.MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE;
        pub const MAX_NUM_TOTAL_VALUES_THAT_CAN_TRIGGER_UPDATES_FOR_STATIC_UPDATE_LIST = SETTINGS.MAX_NUM_TOTAL_VALUES_THAT_CAN_TRIGGER_UPDATES_FOR_STATIC_UPDATE_LIST;
        pub const UpdateSlice = packed struct {
            first_update: PayloadId,
            update_count: UpdateTriggerCount,
        };
        pub var update_list_alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
        pub var update_static_mem: if (SETTINGS.UPDATE_TRIGGER_LIST_USES_STATIC_MEMORY) [MAX_NUM_TOTAL_VALUES_THAT_CAN_TRIGGER_UPDATES_FOR_STATIC_UPDATE_LIST]UpdateSlice else void = if (SETTINGS.PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY) undefined else void{};
        // CHECKPOINT
        // PAYLOAD LOCATIONS
        pub const PayloadInCount: type = func_input_count_int;
        pub const PayloadOutCount: type = func_output_count_int;
        pub const PayloadLocation = packed struct {
            func_idx: FuncId,
            offset: PayloadOffset,
            in_count: PayloadInCount,
            out_count: PayloadOutCount,
        };
        pub const MAX_NUM_UNIQUE_FUNCTION_PAYLOADS = SETTINGS.MAX_NUM_UNIQUE_FUNCTION_PAYLOADS;
        pub const MAX_FREE_BLOCKS_FOR_UNIQUE_FUNCTION_PAYLOADS = PowerOf2.USIZE_POWER.align_value_forward(MAX_NUM_UNIQUE_FUNCTION_PAYLOADS) >> PowerOf2.USIZE_BITS_SHIFT;
        pub const PayloadLocationPool = SimplePool(PayloadLocation, PayloadId, false, null, null);
        pub var payload_location_list_alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
        pub var payload_location_static_mem: if (SETTINGS.PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY) [MAX_NUM_UNIQUE_FUNCTION_PAYLOADS]PayloadLocation else void = if (SETTINGS.PAYLOAD_LOCATION_LIST_USES_STATIC_MEMORY) undefined else void{};
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
        pub const PayloadDataPool = SimplePool(ParamReadWriteOpaque, PayloadOffset, false, null, null);
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
        pub const FuncId: type = func_idx;
        pub const MAX_NUM_UNIQUE_FUNCTION_POINTERS = SETTINGS.MAX_NUM_UNIQUE_FUNCTION_POINTERS;
        pub const MAX_FREE_BLOCKS_FOR_FUNC_POINTERS = PowerOf2.USIZE_POWER.align_value_forward(MAX_NUM_UNIQUE_FUNCTION_POINTERS) >> PowerOf2.USIZE_BITS_SHIFT;
        pub const FunctionPool = SimplePool(*const UpdateFunction, FuncId, false, null, null);
        pub var function_list_alloc: Allocator = DummyAllocator.allocator_panic_free_noop;
        pub var func_pointers_static_mem: if (SETTINGS.FUNCTION_LIST_USES_STATIC_MEMORY) [SETTINGS.MAX_NUM_UNIQUE_FUNCTION_POINTERS]*const UpdateFunction else void = if (SETTINGS.FUNCTION_LIST_USES_STATIC_MEMORY) undefined else void{};
        pub var func_pointers_free_static_mem: if (SETTINGS.FUNCTION_LIST_USES_STATIC_MEMORY) [MAX_FREE_BLOCKS_FOR_FUNC_POINTERS]usize else void = if (SETTINGS.FUNCTION_LIST_USES_STATIC_MEMORY) @splat(math.maxInt(usize)) else void{};
        pub var functions: FunctionPool = if (SETTINGS.FUNCTION_LIST_USES_STATIC_MEMORY) FunctionPool{
            .ptr = @ptrCast(&func_pointers_static_mem[0]),
            .len = 0,
            .cap = SETTINGS.MAX_NUM_UNIQUE_FUNCTION_POINTERS,
            .free_list = FreeList{
                .free_bits = .{
                    .list = .{
                        .ptr = @ptrCast(&func_pointers_free_static_mem[0]),
                        .len = MAX_FREE_BLOCKS_FOR_FUNC_POINTERS,
                        .cap = MAX_FREE_BLOCKS_FOR_FUNC_POINTERS,
                    },
                    .index_len = 0,
                },
                .free_count = 0,
            },
        } else FunctionPool{};

        pub const _Assert = Assert.AssertHandler(SETTINGS.MASTER_ASSERT_MODE);
        const assert_with_reason = _Assert._with_reason;
        const assert_unreachable = _Assert._unreachable;
        const assert_unreachable_err = _Assert._unreachable_err;
        const assert_index_in_range = _Assert._index_in_range;
        const assert_allocation_failure = _Assert._allocation_failure;

        pub const UpdateFunction = fn (inputs: []const ParamReadOnlyOpaque, outputs: []const ParamReadWriteOpaque) void;
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
                assert_with_reason(CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{ @tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(CATEGORY_DEFS[self.category].param_type), @typeName(T) });
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
                assert_with_reason(CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{ @tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(CATEGORY_DEFS[self.category].param_type), @typeName(T) });
                return @bitCast(self);
            }
        };
    };
}
