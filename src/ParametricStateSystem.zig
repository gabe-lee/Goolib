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
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const DummyAllocator = Root.Allocator.Dummy;
const Flags = Root.Flags;
const MathX = Root.Math;
const PowerOf2 = MathX.PowerOf2;
const InterfaceSignature = Types.InterfaceSignature;
const UniqueQueue = Root.UniqueQueue.UniqueQueue;
const UniqueQueueModule = Root.UniqueQueue;
const KeyedMutex = Root.KeyedMutex.KeyedMutex;
const MappedKeyPoolModule = Root.Pool.MappedKeyModule;
const GlobalMappedKeyPool = Root.Pool.GlobalMappedKeyPool;
const PoolDef = MappedKeyPoolModule.PoolDef;

const ct_assert_with_reason = Assert.assert_with_reason;
const ct_assert_unreachable = Assert.assert_unreachable;
const ct_assert_unreachable_err = Assert.assert_unreachable_err;
const ct_assert_allocation_failure = Assert.assert_allocation_failure;
const ct_assert_field_is_type = Assert.assert_field_is_type;

const num_cast = Root.Cast.num_cast;
const name_cast = Root.Cast.name_cast;

const DEBUG_VAL = Root.Utils.DebugPrint.debug_val;
const DEBUG = std.debug.print;

pub const UpdateMode = enum(u2) {
    NEVER_TRIGGER_UPDATES = 0,
    ONLY_TRIGGER_UPDATES_ON_VALUE_CHANGE = 1,
    ALWAYS_TRIGGER_UPDATES_EVEN_IF_VALUE_UNCHANGED = 2,
};

pub const ParentDeleteMode = enum(u2) {
    DELETE_WHEN_PARENT_IS_DELETED = 0,
    SET_DEFAULT_VALUE_WHEN_PARENT_IS_DELETED = 1,
    RETAIN_LAST_VALUE_WHEN_PARENT_DELETED = 2,
    TRIGGER_UPDATE_WHEN_PARENT_DELETED = 3,
};

pub const GetDeletedParamMode = enum(u2) {
    CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED = 0,
    RETURN_DEFAULT_VALUE_WHEN_GET_DELETED = 1,
    RETURN_DEFAULT_VALUE_WHEN_GET_DELETED_AND_WARN = 2,
};

pub const SetDeletedParamMode = enum(u2) {
    CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED = 0,
    IGNORE_SETTING_PARAM_WHEN_DELETED = 1,
    IGNORE_SETTING_PARAM_WHEN_DELETED_AND_WARN = 2,
};

pub const ParamDefKind = enum(u8) {
    ROOT,
    DERIVED,
};
pub const ParamDefKindWithGroup = enum(u8) {
    ROOT,
    DERIVED_SINGLE,
    DERIVED_GROUP,
};

pub const InitializeMode = enum(u8) {
    ALLOCATED,
    STATIC_MEMORY,
};

pub const MetaChangeMode = enum(u8) {
    /// Do not include a meta-category
    NO_META_CATEGORY,
    /// Largest category tag-value is a category that tracks
    /// the length of the other categories in each index
    /// (matching the category index) and triggers updates
    /// for derived parameters when a category length changes
    META_CATEGORY_LENGTH_CHANGE_ONLY,
    /// Largest category tag-value is a category that tracks
    /// the length of the other categories in each index
    /// (matching the category index) and triggers updates
    /// for derived parameters when a category length changes
    /// OR when ANY value in the category changes
    META_CATEGORY_LENGTH_AND_VALUE_CHANGE,
};

pub const LockMode = enum {
    NO_LOCKS,
    MASTER_LOCK,
};

pub const Settings = struct {
    /// The mutex locking mechanism to use, if any
    LOCK_MODE: LockMode = .NO_LOCKS,
    /// If set to true, you can delete an update function that has been initialized.
    ALLOW_FUNCTION_DELETION: bool = false,
    /// If set to true, you can replace an existing function with a new one,
    /// causing all dependant parameters to also be updated.
    ALLOW_FUNCTION_REPLACEMENT: bool = false,
    /// If set to true, when an update function is deleted, all parameters that depended on it will be deleted as well
    DELETE_DEPENDANT_PARAMETERS_WHEN_FUNCTION_DELETED: bool = true,
    /// The maximum number of values any one category can have
    MAX_NUM_VALUES_IN_ANY_CATEGORY: PowerOf2 = ._65_536,
    /// If true, an additional read-only category is included that describes the state of the other
    /// categories and can be used as a dependancy for other parameters:
    ///   - `NO_META_CATEGORY`: feature not enabled
    ///   - `META_CATEGORY_LENGTH_CHANGE_ONLY`: when a category length changes, the ParametricStateSystem automatically sets the meta category parameter with the new category length, and any parameter using this value will be triggered for update
    ///   - `META_CATEGORY_LENGTH_AND_VALUE_CHANGE`: when a category length changes, OR when ANY value in the category changes (including being created or freed), the ParametricStateSystem automatically sets the meta category parameter with the new category length (and forces an update if a value changed but length was the same), and any parameter using this value will be triggered for update
    INCLUDE_META_CATEGORY: MetaChangeMode = .NO_META_CATEGORY,
    /// The maximum number of unique function payloads (input+output sets)
    /// across all functions.
    ///
    /// A safe value to choose is the maximum number of derivative parameters you
    /// expect to have in the entire table (one unique payload per derivative param),
    /// but it may be much lower if many of your functions have more than one output.
    MAX_NUM_UNIQUE_FUNCTION_PAYLOADS: PowerOf2 = ._65_536,
    /// The maximum number of functions that a parameter can trigger to update other params when it changes
    ///
    /// This also affects the number of derivative parameters a single parameter can have,
    /// but a single triggered function can update more than one derivative parameter at a time
    /// so the number may be larger than this
    MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE: PowerOf2 = ._256,
    /// If non-zero, an update function is allowed to be called as a result of a single parameter change a maximum of this many times.
    ///
    /// Each unique update payload will track its own number of times its been called, and stop when calling it again would exceed the
    /// limit.
    ///
    /// This setting can cause strange/unexpected effects when relying on recursive updates, and is NOT RECOMMENDED but provided regardless.
    /// For example, if one parameter update starts 2 separate update paths that lead back to a parent parameter update,
    /// it is not clearly defined how many times nor in what order each separate path will re-trigger the original param,
    /// nor that each of the paths will update the same number of times compared to the other
    ALLOWED_RECURSIVE_UPDATES: comptime_int = 0,
    /// The maximum number of inputs a function can have
    MAX_NUM_FUNCTION_INPUTS: comptime_int = 16,
    /// The maximum number of outputs a function can have
    MAX_NUM_FUNCTION_OUTPUTS: comptime_int = 16,
    /// This may be a tough limit to define, but a safe upper bound is:
    /// ```
    /// PowerOf2.round_up_to_power_of_2(MAX_NUM_UNIQUE_FUNCTION_PAYLOADS * (MAX_NUM_FUNCTION_INPUTS + MAX_NUM_FUNCTION_OUTPUTS)).value()
    /// ```
    MAX_PAYLOAD_LIST_LIMIT: PowerOf2 = ._2_097_152,
};

pub fn CategoryTypeDef(comptime CATEGORIES: type) type {
    return struct {
        category: CATEGORIES,
        param_type: type,
        allow_free_slots: bool = true,
        default_value_for_type: ?*const anyopaque,
        /// MUST be a function pointer in the form `fn(a: param_type, b: param_type) bool`
        /// that returns `true` when the values are equal, `false` otherwise
        type_equality_func: *const anyopaque,
    };
}
pub const CategoryTypeDefUnnamed = struct {
    param_type: type,
    allow_free_slots: bool = true,
    default_value_for_type: ?*const anyopaque,
    /// MUST be a function pointer in the form `fn(a: param_type, b: param_type) bool`
    /// that returns `true` when the values are equal, `false` otherwise
    type_equality_func: *const anyopaque,
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
    // COMPTIME CALCULATIONS/SYNTHESIS
    // go through all categories and create a prototype type based on every unique @sizeOf(T) + @alignOf(T) combination
    // assign each catagory to its matching prototype value. The prototype value contains the actual data,
    // and accessing a parameter looks up which prototype pool it belongs to and does a Glo
    return struct {
        // IMPLEMENTATION
        const POOLS = [NUM_POOLS]type{
            // each type is a GlobalMappedKeyPool(...) with an elem type that is on of the prototype types
        };
    };
}
