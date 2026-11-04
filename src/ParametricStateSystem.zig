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
    return struct {
        // IMPLEMENTATION
    };
}

test "ParametricStateSystem" {
    const Test = Root.Testing;
    const do_debug = false;
    const settings = Settings{
        .ALLOW_FUNCTION_DELETION = true,
        .ALLOW_FUNCTION_REPLACEMENT = true,
        .ALLOWED_RECURSIVE_UPDATES = 0,
        .INCLUDE_META_CATEGORY = .META_CATEGORY_LENGTH_AND_VALUE_CHANGE,
        .DELETE_DEPENDANT_PARAMETERS_WHEN_FUNCTION_DELETED = true,
        .ENABLE_THREAD_SAFETY = true,
        .INDEX_GENERATION_MODE = .per_parameter_index_generation_int_power(._256),
        .MASTER_ASSERT_MODE = .ALWAYS_PANIC,
        .MAX_NUM_FUNCTION_INPUTS = 8,
        .MAX_NUM_FUNCTION_OUTPUTS = 8,
        .MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE = 16,
        .MAX_NUM_UNIQUE_FUNCTION_PAYLOADS = 65536,
        .MAX_NUM_VALUES_IN_ANY_CATEGORY = 65536,
        .MAX_PAYLOAD_LIST_LIMIT = 65536,
        .RECURSION_ASSERT_MODE = .ALWAYS_PANIC,
    };
    const Cats = enum(u2) {
        POSITIONS,
        SIZES,
        AREAS,
        SCALARS,
    };
    const Funcs = enum(u3) {
        VEC_PLUS_SCALAR,
        HALF_VEC_MINUS_2_SCALAR,
        LINKED_AREA_PARENT_AND_BUTTON,
        BOT_LEFT_AND_FAR_CORNER_PLUS_MARGIN,
        TOP_RIGHT_PLUS_MARGIN,
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
            .param_type = Vec,
            .type_equality_func = Vec.equals,
        },
        CatDef{
            .category = .SIZES,
            .allow_free_slots = true,
            .default_value_for_type = @ptrCast(&Vec.ZERO),
            .param_type = Vec,
            .type_equality_func = Vec.equals,
        },
        CatDef{
            .category = .AREAS,
            .allow_free_slots = true,
            .default_value_for_type = @ptrCast(&F32_ZERO),
            .param_type = f32,
            .type_equality_func = PROTO.f32_equals,
        },
        CatDef{
            .category = .SCALARS,
            .allow_free_slots = true,
            .default_value_for_type = @ptrCast(&F32_ZERO),
            .param_type = f32,
            .type_equality_func = PROTO.f32_equals,
        },
    }, Funcs);
    const DebugAlloc = std.heap.DebugAllocator(.{});
    var debug_alloc = DebugAlloc.init;
    const alloc = debug_alloc.allocator();
    PSS.initialize_memory(.{
        .delete_queue_memory = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
        .payload_data_pool_memory = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
        .update_package_pool_memory = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
        .update_queue_memory = .allocated(AllocInitWithSecondary{ .alloc = alloc, .init_capacity_main = 0, .init_capacity_secondary = 0 }),
        .function_dependants_memory = .{
            PSS.InitializeFuncDependantsMem{
                .func_name = .VEC_PLUS_SCALAR,
                .init_mem = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
            },
            PSS.InitializeFuncDependantsMem{
                .func_name = .HALF_VEC_MINUS_2_SCALAR,
                .init_mem = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
            },
            PSS.InitializeFuncDependantsMem{
                .func_name = .LINKED_AREA_PARENT_AND_BUTTON,
                .init_mem = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
            },
            PSS.InitializeFuncDependantsMem{
                .func_name = .BOT_LEFT_AND_FAR_CORNER_PLUS_MARGIN,
                .init_mem = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
            },
            PSS.InitializeFuncDependantsMem{
                .func_name = .TOP_RIGHT_PLUS_MARGIN,
                .init_mem = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
            },
        },
        .parameter_memory = .{
            PSS.InitializeCategoryMem{
                .category_name = .POSITIONS,
                .init_mem = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
            },
            PSS.InitializeCategoryMem{
                .category_name = .SIZES,
                .init_mem = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
            },
            PSS.InitializeCategoryMem{
                .category_name = .AREAS,
                .init_mem = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
            },
            PSS.InitializeCategoryMem{
                .category_name = .SCALARS,
                .init_mem = .allocated(AllocInit{ .alloc = alloc, .init_capacity = 0 }),
            },
        },
    });
    defer PSS.free_memory();
    const CalcIface = PSS.UpdateInterface;
    const ParamReadWrite = PSS.ParamReadWrite;
    const ParamReadOnly = PSS.ParamReadOnly;
    const ParamUpdateInput = PSS.ParamUpdateInput;
    const ParamUpdateOutput = PSS.ParamUpdateOutput;
    const ParamReadOnlyDef = PSS.ParamReadOnlyDef;
    const VecAndScalar_UpdateIn = struct {
        vec: ParamUpdateInput(Vec),
        scalar: ParamUpdateInput(f32),
    };
    const PosSizeMargin_UpdateIn = struct {
        pos: ParamUpdateInput(Vec),
        size: ParamUpdateInput(Vec),
        margin: ParamUpdateInput(f32),
    };
    const Vec_UpdateOut = struct {
        vec: ParamUpdateOutput(Vec),
    };
    const ParentSizeButtonSize_UpdateIn = struct {
        parent_size: ParamUpdateInput(Vec),
        button_size: ParamUpdateInput(Vec),
    };
    const ParentAreaButtonAreaOutDef = struct {
        parent_area: ParamReadOnlyDef,
        button_area: ParamReadOnlyDef,
        total_area: ParamReadOnlyDef,
    };
    const ParentAreaButtonArea_UpdateOut = struct {
        parent_area: ParamUpdateOutput(f32),
        button_area: ParamUpdateOutput(f32),
        total_area: ParamUpdateOutput(f32),
    };
    const ParentAreaButtonAreaOut = struct {
        parent_area: ParamReadOnly(f32),
        button_area: ParamReadOnly(f32),
        total_area: ParamReadOnly(f32),
    };
    const VecAndVec_UpdateOut = struct {
        vec_1: ParamUpdateOutput(Vec),
        vec_2: ParamUpdateOutput(Vec),
    };
    const OneVec_UpdateOut = struct {
        vec: ParamUpdateOutput(Vec),
    };

    const CALC = struct {
        fn vec_plus_scalar(iface: CalcIface) void {
            const in = iface.make_input_struct(VecAndScalar_UpdateIn);
            const out = iface.make_output_struct(Vec_UpdateOut);
            const vec_in = in.vec.get();
            const scalar = in.scalar.get();
            const vec_out = vec_in.add(Vec{ .x = scalar, .y = scalar });

            out.vec.set(vec_out);
            iface.commit_deletions_and_changes();
        }
        fn half_vec_minus_2_scalar(iface: CalcIface) void {
            const in = iface.make_input_struct(VecAndScalar_UpdateIn);
            const out = iface.make_output_struct(Vec_UpdateOut);
            const vec_in = in.vec.get();
            const scalar = in.scalar.get();
            const vec_out = vec_in.scale(0.5).subtract_scale(Vec{ .x = scalar, .y = scalar }, 2);
            out.vec.set(vec_out);
            iface.commit_deletions_and_changes();
        }
        fn linked_area_parent_and_button(iface: CalcIface) void {
            const in = iface.make_input_struct(ParentSizeButtonSize_UpdateIn);
            const out = iface.make_output_struct(ParentAreaButtonArea_UpdateOut);
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
        fn vec_plus_vec_plus_margin_out_vec_0Y_and_vec_XY(iface: CalcIface) void {
            const in = iface.make_input_struct(PosSizeMargin_UpdateIn);
            const out = iface.make_output_struct(VecAndVec_UpdateOut);
            const pos = in.pos.get();
            const size = in.size.get();
            const margin = in.margin.get();
            const far_corner = pos.add(size).add(Vec{ .x = margin, .y = margin });
            const bot_left = Vec{ .x = 0, .y = far_corner.y };
            out.vec_1.set(bot_left);
            out.vec_2.set(far_corner);
            iface.commit_deletions_and_changes();
        }
        fn vec_plus_vec_plus_margin_out_vec_X0(iface: CalcIface) void {
            const in = iface.make_input_struct(PosSizeMargin_UpdateIn);
            const out = iface.make_output_struct(OneVec_UpdateOut);
            const pos = in.pos.get();
            const size = in.size.get();
            const margin = in.margin.get();
            const far_corner = pos.add(size).add(Vec{ .x = margin, .y = margin });
            const top_right = Vec{ .x = far_corner.x, .y = 0 };
            out.vec.set(top_right);
            iface.commit_deletions_and_changes();
        }
    };

    PSS.initialize_update_function(.VEC_PLUS_SCALAR, CALC.vec_plus_scalar);
    PSS.initialize_update_function(.HALF_VEC_MINUS_2_SCALAR, CALC.half_vec_minus_2_scalar);
    PSS.initialize_update_function(.LINKED_AREA_PARENT_AND_BUTTON, CALC.linked_area_parent_and_button);
    PSS.initialize_update_function(.BOT_LEFT_AND_FAR_CORNER_PLUS_MARGIN, CALC.vec_plus_vec_plus_margin_out_vec_0Y_and_vec_XY);
    PSS.initialize_update_function(.TOP_RIGHT_PLUS_MARGIN, CALC.vec_plus_vec_plus_margin_out_vec_X0);

    const ParentPos = PSS.create_new_root_param(.POSITIONS, Vec{ .x = 100.0, .y = 200.0 }, .default());
    const ParentSize = PSS.create_new_root_param(.SIZES, Vec{ .x = 800.0, .y = 600.0 }, .default());

    const Margin = PSS.create_new_root_param(.SCALARS, 32.0, .default());

    const ButtonPos = PSS.create_new_derived_param_from_input_struct(.VEC_PLUS_SCALAR, VecAndScalar_UpdateIn{
        .scalar = Margin.as_update_input(.{}),
        .vec = ParentPos.as_update_input(.{}),
    }, PSS.ParamReadOnlyDef.new_def(.POSITIONS).default_value_when_deleted(), Vec);

    const ButtonSize = PSS.create_new_derived_param_from_input_struct(.HALF_VEC_MINUS_2_SCALAR, VecAndScalar_UpdateIn{
        .scalar = Margin.as_update_input(.{}),
        .vec = ParentSize.as_update_input(.{}),
    }, PSS.ParamReadOnlyDef.new_def(.SIZES).default_value_when_deleted(), Vec);

    const Areas = PSS.create_new_derived_param_set_from_struct(.LINKED_AREA_PARENT_AND_BUTTON, ParentSizeButtonSize_UpdateIn{
        .parent_size = ParentSize.as_update_input(.{}),
        .button_size = ButtonSize.as_update_input(.{}),
    }, ParentAreaButtonAreaOutDef{
        .parent_area = PSS.ParamReadOnlyDef.new_def(.AREAS).no_access_when_deleted(),
        .button_area = PSS.ParamReadOnlyDef.new_def(.AREAS).no_access_when_deleted().with_parent_delete_mode(.TRIGGER_UPDATE_WHEN_PARENT_DELETED),
        .total_area = PSS.ParamReadOnlyDef.new_def(.AREAS).no_access_when_deleted(),
    }, ParentAreaButtonAreaOut);

    const debug = struct {
        pub fn print_vals(parent_pos: ParamReadWrite(Vec), parent_size: ParamReadWrite(Vec), parent_area: ParamReadOnly(f32), button_pos: ParamReadOnly(Vec), button_size: ParamReadOnly(Vec), button_area: ParamReadOnly(f32), total_area: ParamReadOnly(f32)) void {
            std.debug.print("       X     Y     W     H       A\nP: {d: >5} {d: >5} {d: >5} {d: >5} {d: >7}\nB: {d: >5} {d: >5} {d: >5} {d: >5} {d: >7}\nT:                         {d: >7}\n", .{
                parent_pos.get().x, parent_pos.get().y, parent_size.get().x, parent_size.get().y, parent_area.get(),
                button_pos.get().x, button_pos.get().y, button_size.get().x, button_size.get().y, button_area.get(),
                total_area.get(),
            });
        }
        pub fn print_ids(parent_pos: ParamReadWrite(Vec), parent_size: ParamReadWrite(Vec), parent_area: ParamReadOnly(f32), button_pos: ParamReadOnly(Vec), button_size: ParamReadOnly(Vec), button_area: ParamReadOnly(f32), total_area: ParamReadOnly(f32)) void {
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
    try Test.expect_equal(ButtonPos.get().y, "ButtonPos.get().y", 248.0, "248.0", "failed automatic update", .{});
    try Test.expect_equal(ButtonSize.get().x, "ButtonSize.get().x", 399.0, "399.0", "failed automatic update", .{});
    try Test.expect_equal(ButtonSize.get().y, "ButtonSize.get().y", 70.5, "70.5", "failed automatic update", .{});

    try Test.expect_equal(Areas.parent_area.get(), "Areas.parent_area.get()", 329670.0, "329670.0", "failed automatic update", .{});
    try Test.expect_equal(Areas.button_area.get(), "Areas.button_area.get()", 28129.5, "28129.5", "failed automatic update", .{});
    try Test.expect_equal(Areas.total_area.get(), "Areas.total_area.get()", 357799.5, "357799.5", "failed automatic update", .{});

    ButtonPos.delete();
    ButtonSize.delete();

    try Test.expect_equal(Areas.parent_area.get(), "Areas.parent_area.get()", 329670.0, "329670.0", "failed automatic update", .{});
    try Test.expect_equal(Areas.button_area.get(), "Areas.button_area.get()", 0, "0", "failed automatic update", .{});
    try Test.expect_equal(Areas.total_area.get(), "Areas.total_area.get()", 329670.0, "329670.0", "failed automatic update", .{});

    var RectCorners: [4]PSS.Param(Vec) = undefined;
    PSS.create_consecutive_indexed_params(.POSITIONS, null, &.{
        PSS.ParamDefConsecutive(Vec).root(.new_def(.ZERO)),
        PSS.ParamDefConsecutive(Vec).derived_group(.{
            .inputs = &.{ ParentPos.to_opaque_read_only(), ParentSize.to_opaque_read_only(), Margin.to_opaque_read_only() },
            .output_defs = &.{
                PSS.ParamReadOnlyDefNoCategoryOrIndex{},
                PSS.ParamReadOnlyDefNoCategoryOrIndex{},
            },
            .update_function = .BOT_LEFT_AND_FAR_CORNER_PLUS_MARGIN,
        }),
        PSS.ParamDefConsecutive(Vec).derived_single(.{
            .inputs = &.{ ParentPos.to_opaque_read_only(), ParentSize.to_opaque_read_only(), Margin.to_opaque_read_only() },
            .output_def = PSS.ParamReadOnlyDefNoCategoryOrIndex{},
            .update_function = .TOP_RIGHT_PLUS_MARGIN,
        }),
    }, RectCorners[0..]);
    const TopLeft = RectCorners[0].ROOT;
    const BotLeft = RectCorners[1].DERIVED;
    const BotRight = RectCorners[2].DERIVED;
    const TopRight = RectCorners[3].DERIVED;
    const CornersFirstIdx = TopLeft.index;
    const CornersSecondIdx = BotLeft.index;
    const CornersThirdIdx = BotRight.index;
    const CornersFourthIdx = TopRight.index;

    if (do_debug) {
        std.debug.print("\nTOP LEFT: {any}\nBOT LEFT: {any}\nBOT RIGHT: {any}\nTOP RIGHT: {any}\n", .{
            TopLeft.get(),
            BotLeft.get(),
            BotRight.get(),
            TopRight.get(),
        });
    }

    try Test.expect_equal(TopLeft.get(), "TopLeft.get()", Vec{ .x = 0, .y = 0 }, "Vec{ .x = 0, .y = 0 }", "failed automatic update", .{});
    try Test.expect_equal(BotLeft.get(), "BotLeft.get()", Vec{ .x = 0, .y = 581 }, "Vec{ .x = 0, .y = 581 }", "failed automatic update", .{});
    try Test.expect_equal(BotRight.get(), "BotRight.get()", Vec{ .x = 1138, .y = 581 }, "Vec{ .x = 1138, .y = 581 }", "failed automatic update", .{});
    try Test.expect_equal(TopRight.get(), "TopRight.get()", Vec{ .x = 1138, .y = 0 }, "Vec{ .x = 1138, .y = 0 }", "failed automatic update", .{});

    try Test.expect_equal(CornersSecondIdx, "CornersSecondIdx", CornersFirstIdx + 1, "CornersFirstIdx + 1", "failed automatic update", .{});
    try Test.expect_equal(CornersThirdIdx, "CornersThirdIdx", CornersFirstIdx + 2, "CornersFirstIdx + 2", "failed automatic update", .{});
    try Test.expect_equal(CornersFourthIdx, "CornersFourthIdx", CornersFirstIdx + 3, "CornersFirstIdx + 3", "failed automatic update", .{});

    // if (do_debug) {
    //     std.debug.print("TestTable MEM: {d} bytes\n", .{my_param_table.total_memory_footprint()});
    // }
}
