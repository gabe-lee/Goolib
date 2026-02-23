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
const OneBitList = BitListModule.BitList(1);

pub fn CategoryTypeDef(comptime CATEGORIES: type) type {
    return struct {
        category: CATEGORIES,
        param_type: type,
        expected_maximum_num_params: usize,
        maximum_is_guaranteed: bool = false,
        allow_free_slots: bool = true,
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
    /// MUST be a function pointer in the form `fn(a: param_type, b: param_type) bool`
    /// that returns `true` when the values are equal, `false` otherwise
    type_equality_func: *const anyopaque,
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
    const update_length_int = PowerOf2.round_up_to_power_of_2(SETTINGS.MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE).unsigned_integer_type_that_holds_all_values_less_than();
    const update_count_int = if (SETTINGS.ALLOWED_RECURSIVE_UPDATES > 0) PowerOf2.round_up_to_power_of_2(SETTINGS.ALLOWED_RECURSIVE_UPDATES).unsigned_integer_type_that_holds_all_values_less_than() else u0;
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
    comptime var total_static_update_slots: usize = 0;
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
            total_static_update_slots += def.expected_maximum_num_params;
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
            pub var access_lock: if (MULTITHREADED) KeyedMutex else void = if (MULTITHREADED) KeyedMutex{} else void{};
            pub fn lock_system() MutexKey {
                if (MULTITHREADED) {
                    return access_lock.lock();
                } else {
                    return void{};
                }
            }
            pub fn unlock_system(key: MutexKey) void {
                if (MULTITHREADED) {
                    key.unlock();
                }
            }
            // CATEGORIES
            pub const CATEGORY_DEFS = ordered_category_defs_const;
            pub const CATEGORY_SIZES = ordered_category_type_sizes_const;
            pub const MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE = SETTINGS.MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE;
            pub const NUM_CATEGORIES = _NUM_CATEGORIES;
            pub const CategoryPool = SimplePoolOpaque(Index, false, .{
                .elem_type = UpdateSlice,
            });
            pub const Category = struct {
                data: CategoryPool = .{},
                always_update: OneBitList = .{},
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
                                .always_update = .{
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
                    _RecusionAssert._unreachable(@src(), "recursive parameter update detected:\nparam update package triggered twice: {any}\n", .{item_to_queue.*});
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
            /// USER ALTERATION NOT RECOMMENDED!!
            pub var updates_in_progress: bool = false;
            // PAYLOAD LOCATIONS
            pub const PayloadInCount: type = func_input_count_int;
            pub const PayloadOutCount: type = func_output_count_int;
            pub const UpdatePackage = packed struct {
                func_idx: FuncId,
                payload_offset: PayloadOffset,
                in_count: PayloadInCount,
                out_count: PayloadOutCount,

                pub fn equals(a: UpdatePackage, b: UpdatePackage) bool {
                    const matches = a.func_idx == b.func_idx and a.payload_offset == b.payload_offset;
                    if (_Assert._should_assert() and matches) {
                        assert_with_reason(a.in_count == b.in_count and a.out_count == b.out_count, @src(), "two update packages with the same function and payload offset DID NOT HAV THE SAME input/output count... something went wrong\nA: {any}\nB: {any}\n", .{ a, b });
                    }
                    return matches;
                }
                pub fn equals_unique(a: UpdatePackage, b: UpdatePackageUnique) bool {
                    const matches = a.func_idx == b.func_idx and a.payload_offset == b.payload_offset;
                    if (_Assert._should_assert() and matches) {
                        assert_with_reason(a.in_count == b.in_count and a.out_count == b.out_count, @src(), "two update packages with the same function and payload offset DID NOT HAV THE SAME input/output count... something went wrong\nA: {any}\nB: {any}\n", .{ a, b });
                    }
                    return matches;
                }

                pub fn to_unique(self: UpdatePackage) UpdatePackageUnique {
                    return UpdatePackageUnique{
                        .func_idx = self.func_idx,
                        .payload_offset = self.payload_offset,
                        .in_count = self.in_count,
                        .out_count = self.out_count,
                        .recursion_count = 0,
                    };
                }
            };
            pub const UpdatePackageUnique = packed struct {
                func_idx: FuncId,
                payload_offset: PayloadOffset,
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
            pub const FuncId: type = func_idx;
            pub const MAX_NUM_UNIQUE_FUNCTION_POINTERS = SETTINGS.MAX_NUM_UNIQUE_FUNCTION_POINTERS;
            pub const MAX_FREE_BLOCKS_FOR_FUNC_POINTERS = PowerOf2.USIZE_POWER.align_value_forward(MAX_NUM_UNIQUE_FUNCTION_POINTERS) >> PowerOf2.USIZE_BITS_SHIFT;
            pub const FunctionPool = SimplePool(*const UpdateFunction, FuncId, false, null, null, null);
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
            pub const assert_with_reason = _Assert._with_reason;
            pub const assert_unreachable = _Assert._unreachable;
            pub const assert_unreachable_err = _Assert._unreachable_err;
            pub const assert_index_in_range = _Assert._index_in_range;
            pub const assert_allocation_failure = _Assert._allocation_failure;

            pub const _RecusionAssert = Assert.AssertHandler(SETTINGS.RECURSION_ASSERT_MODE);

            pub fn set_internal(comptime T: type, cat_idx: CategoryId, index: Index, val: T, _update_key: MutexKey) void {
                var update_key: MutexKey, const owns_key: bool = if (MULTITHREADED and _update_key.ptr == null) .{ lock_system(), true } else .{ _update_key, false };
                defer {
                    if (MULTITHREADED and owns_key) {
                        update_key.unlock();
                    }
                }
                const list_opaque = categories[cat_idx].data;
                const list_typed = list_opaque.to_typed(T);
                const old: T = list_typed.ptr[index];
                list_typed.ptr[index] = val;
                const is_equal: *const fn (a: T, b: T) bool = @ptrCast(@alignCast(CATEGORY_DEFS[cat_idx].type_equality_func));
                if (!is_equal(old, val) or categories[cat_idx].always_update.get(@intCast(index)) == 1) {
                    const update_slice: UpdateSlice = categories[cat_idx].data.ptr_2[index];
                    if (update_slice.update_count > 0) {
                        const updates_to_trigger = payload_location_pool.ptr[update_slice.first_payload_u32()..update_slice.end_payload_u32_excluded()];
                        for (updates_to_trigger) |to_trigger| {
                            update_queue.queue(to_trigger, update_queue_alloc);
                        }
                        if (!updates_in_progress) {
                            updates_in_progress = true;
                            defer updates_in_progress = false;
                            process_all_updates(update_key);
                        }
                    }
                }
            }
            pub fn get_internal(comptime T: type, cat_idx: CategoryId, index: Index, _update_key: MutexKey) T {
                var update_key: MutexKey, const owns_key: bool = if (MULTITHREADED and _update_key.ptr == null) .{ lock_system(), true } else .{ _update_key, false };
                defer {
                    if (MULTITHREADED and owns_key) {
                        update_key.unlock();
                    }
                }
                const list_opaque = categories[cat_idx].data;
                const list_typed = list_opaque.to_typed(T);
                return list_typed.ptr[index];
            }

            pub fn process_all_updates(update_key: MutexKey) void {
                while (update_queue.has_queued_items()) {
                    const next_update = update_queue.get_next_queued_guaranteed();
                    const input_ptr: [*]const ParamReadOnlyOpaque = @ptrCast(payload_data_pool.ptr + next_update.payload_offset);
                    const output_ptr: [*]const ParamReadWriteOpaque = payload_data_pool.ptr + next_update.payload_offset + next_update.in_count;
                    const inputs: []const ParamReadOnlyOpaque = input_ptr[0..next_update.in_count];
                    const outputs: []const ParamReadWriteOpaque = output_ptr[0..next_update.out_count];
                    const func = functions.ptr[next_update.func_idx];
                    func(update_key, inputs, outputs);
                }
                update_queue.reset();
            }
        };

        pub fn get_in_category(comptime category: CategoryName, index: Index) INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            return INTERNAL.get_internal(T, cat_idx, index, .{});
        }
        pub fn get_in_category_during_update(comptime category: CategoryName, index: Index, update_key: MutexKey) INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            return INTERNAL.get_internal(T, cat_idx, index, update_key);
        }
        pub fn set_in_category(comptime category: CategoryName, index: Index, val: INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type) void {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            return INTERNAL.set_internal(T, cat_idx, index, val, .{});
        }
        pub fn set_in_category_during_update(comptime category: CategoryName, index: Index, val: INTERNAL.CATEGORY_DEFS[@intFromEnum(category)].param_type, update_key: MutexKey) void {
            const cat_idx = @intFromEnum(category);
            const T = INTERNAL.CATEGORY_DEFS[cat_idx].param_type;
            return INTERNAL.set_internal(T, cat_idx, index, val, update_key);
        }

        pub const CategoryName = PARAM_CATEGORIES;
        pub const Index: type = idx_int;
        pub const MutexKey = if (INTERNAL.MULTITHREADED) KeyedMutex.Key else void;
        pub const UpdateFunction = fn (access: MutexKey, inputs: []const ParamReadOnlyOpaque, outputs: []const ParamReadWriteOpaque) void;
        pub fn ParamReadWrite(comptime T: type) type {
            return packed struct {
                const ParamSelf = @This();
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                category: INTERNAL.CategoryId,
                index: Index,

                pub fn set_safe(comptime self: ParamSelf, val: T) void {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "type indicated by param category index (`{s}`) does not match the type of this param (`{s}`)", .{});
                    INTERNAL.set_internal(T, self.category, self.index, val, .{});
                }
                pub fn set(self: ParamSelf, val: T) void {
                    INTERNAL.set_internal(T, self.category, self.index, val, .{});
                }
                pub fn set_during_update_safe(comptime self: ParamSelf, val: T, update_key: MutexKey) void {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "type indicated by param category index (`{s}`) does not match the type of this param (`{s}`)", .{});
                    INTERNAL.set_internal(T, self.category, self.index, val, update_key);
                }
                pub fn set_during_update(self: ParamSelf, val: T, update_key: MutexKey) void {
                    INTERNAL.set_internal(T, self.category, self.index, val, update_key);
                }

                pub fn get_safe(comptime self: ParamSelf) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "type indicated by param category index (`{s}`) does not match the type of this param (`{s}`)", .{});
                    return INTERNAL.get_internal(T, self.category, self.index, .{});
                }
                pub fn get(self: ParamSelf) T {
                    return INTERNAL.get_internal(T, self.category, self.index, .{});
                }
                pub fn get_during_update_safe(comptime self: ParamSelf, update_key: MutexKey) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "type indicated by param category index (`{s}`) does not match the type of this param (`{s}`)", .{});
                    return INTERNAL.get_internal(T, self.category, self.index, update_key);
                }
                pub fn get_during_update(self: ParamSelf, update_key: MutexKey) T {
                    return INTERNAL.get_internal(T, self.category, self.index, update_key);
                }
            };
        }
        pub const ParamReadWriteOpaque = packed struct {
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            category: INTERNAL.CategoryId,
            index: Index,

            pub fn with_type(self: ParamReadWriteOpaque, comptime T: type) ParamReadWrite(T) {
                INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{ @tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(INTERNAL.CATEGORY_DEFS[self.category].param_type), @typeName(T) });
                return @bitCast(self);
            }
        };
        pub fn ParamReadOnly(comptime T: type) type {
            return packed struct {
                const ParamSelf = @This();
                /// USER ALTERATION NOT RECOMENDED AFTER CREATION
                category: INTERNAL.CategoryId,
                index: Index,

                pub fn get_safe(comptime self: ParamSelf) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "type indicated by param category index (`{s}`) does not match the type of this param (`{s}`)", .{});
                    return INTERNAL.get_internal(T, self.category, self.index, .{});
                }
                pub fn get(self: ParamSelf) T {
                    return INTERNAL.get_internal(T, self.category, self.index, .{});
                }
                pub fn get_during_update_safe(comptime self: ParamSelf, update_key: MutexKey) T {
                    INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "type indicated by param category index (`{s}`) does not match the type of this param (`{s}`)", .{});
                    return INTERNAL.get_internal(T, self.category, self.index, update_key);
                }
                pub fn get_during_update(self: ParamSelf, update_key: MutexKey) T {
                    return INTERNAL.get_internal(T, self.category, self.index, update_key);
                }
            };
        }
        pub const ParamReadOnlyOpaque = packed struct {
            /// USER ALTERATION NOT RECOMENDED AFTER CREATION
            category: INTERNAL.CategoryId,
            index: Index,

            pub fn with_type(self: ParamReadOnlyOpaque, comptime T: type) ParamReadOnly(T) {
                INTERNAL.assert_with_reason(INTERNAL.CATEGORY_DEFS[self.category].param_type == T, @src(), "invalid category `{s}` (element type `{s}`) for converting to a param with type `{s}`", .{ @tagName(@as(CategoryName, @enumFromInt(self.category))), @typeName(INTERNAL.CATEGORY_DEFS[self.category].param_type), @typeName(T) });
                return @bitCast(self);
            }
        };
    };
}
