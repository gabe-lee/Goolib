//! A dependency-driven parametric state system.
//!
//! The user declares parameter *categories* (each holding one value type), a set
//! of *update functions*, then creates:
//!   - root parameters (values set directly by the user), and
//!   - derived parameters (values computed by an update function from other params).
//!
//! Derived params register themselves as dependants of every input param.  Setting
//! an input queues the update packages that read it; draining the queue may queue
//! more packages (a cascade).  This file intentionally keeps the cascade bookkeeping
//! and the packed "payload" layout explicit, because those are the tricky parts.
//!
//! Value storage is backed by `Pool_MappedKeyPool.GlobalMappedKeyPool`: exactly
//! one pool per category.  A category's handle index is the pool key index, so a
//! category can be iterated directly without filtering values from other
//! categories and without a category-index side table.
//!
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
const Assert_ = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const DummyAllocator = Root.Allocator.Dummy;
const MathX = Root.Math;
const PowerOf2 = MathX.PowerOf2;
const KeyedMutex = Root.KeyedMutex.KeyedMutex;
const MappedKeyPoolModule = Root.Pool.MappedKeyModule;
const GlobalMappedKeyPool = Root.Pool.GlobalMappedKeyPool;
const BitTrackedPool = Root.Pool.BitTrackedBlocksPool;
const BitTrackedBlocksGlobalModule = Root.Pool.BitTrackedBlocksGlobalModule;
const GlobalMultiTypeBitTrackedPool = BitTrackedBlocksGlobalModule.GlobalMultiTypeBitTrackedPool;
const GlobalPoolDef = BitTrackedBlocksGlobalModule.GlobalDef;
const SubPoolDef = BitTrackedBlocksGlobalModule.SubPoolDef;
const ThreadSafteyModel = BitTrackedBlocksGlobalModule.ThreadSafteyModel;
const AssertBehavior = Root.CommonTypes.AssertBehavior;

const ct_assert_with_reason = Assert_.assert_with_reason;
const ct_assert_unreachable = Assert_.assert_unreachable;
const ct_assert_unreachable_err = Assert_.assert_unreachable_err;
const ct_assert_allocation_failure = Assert_.assert_allocation_failure;

const num_cast = Root.Cast.num_cast;

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

pub const GenerationMode = enum(u8) {
    NO_INDEX_GENERATIONS,
    PER_PARAMETER_INDEX_GENERATION_INT_POWER,
};

pub const GenerationSetting = union(GenerationMode) {
    NO_INDEX_GENERATIONS,
    PER_PARAMETER_INDEX_GENERATION_INT_POWER: PowerOf2,

    pub fn no_index_generations() GenerationSetting {
        return GenerationSetting{ .NO_INDEX_GENERATIONS = {} };
    }
    pub fn per_parameter_index_generation_int_power(power: PowerOf2) GenerationSetting {
        return GenerationSetting{ .PER_PARAMETER_INDEX_GENERATION_INT_POWER = power };
    }
};

pub const MetaChangeMode = enum(u8) {
    NO_META_CATEGORY,
    META_CATEGORY_LENGTH_CHANGE_ONLY,
    META_CATEGORY_LENGTH_AND_VALUE_CHANGE,
};

pub const LockMode = enum {
    NO_LOCKS,
    MASTER_LOCK,
};

pub const SubPoolDefPSS = struct {
    /// The element type for the pool
    TYPE: type,
    /// The number of bits in each state-tracking integer,
    /// where each bit represents the used/free state
    /// of one of the elements. Must be >= 8 and <= `ELEMENTS_PER_BLOCK`
    ELEMENTS_PER_STATE_GROUP: PowerOf2 = .USIZE_POWER,
    /// The number of elements per block. MUST be >= `ELEMENTS_PER_STATE_GROUP`
    ELEMENTS_PER_BLOCK: PowerOf2 = ._64,
    /// The value to initialize newly created parameters to,
    /// or to return if a parameter no longer exists and the
    /// param setting allows returning a default value hen none exists
    DEFAULT_VALUE_FOR_TYPE: ?*const anyopaque,
    /// MUST be a function pointer in the form `fn(a: param_type, b: param_type) bool`
    /// that returns `true` when the values are equal, `false` otherwise
    TYPE_EQUALITY_FUNC: *const anyopaque,

    pub inline fn to_sub_pool_def(comptime self: SubPoolDefPSS) SubPoolDef {
        return SubPoolDef{
            .TYPE = self.TYPE,
            .ELEMENTS_PER_BLOCK = self.ELEMENTS_PER_BLOCK,
            .ELEMENTS_PER_STATE_GROUP = self.ELEMENTS_PER_STATE_GROUP,
        };
    }
};

pub const Settings = struct {
    MASTER_ASSERT_MODE: AssertBehavior = .PANIC_IN_SAFE_MODES,
    RECURSION_ASSERT_MODE: AssertBehavior = .PANIC_IN_SAFE_MODES,
    ELEM_STATE_ASSERT_MODE: AssertBehavior = .PANIC_IN_SAFE_MODES,
    MAX_NUM_ELEMS_PER_TYPE: PowerOf2 = ._4_294_967_296,
    MAX_GENERATION: PowerOf2 = ._4_294_967_296,
    TYPE_POOL_DEFS: []const SubPoolDefPSS,
    THREAD_SAFETY: ThreadSafteyModel = .no_thread_safety(),
    UNIQUE_NAME: []const u8 = "<DEFAULT>",
    ALLOW_FUNCTION_DELETION: bool = false,
    ALLOW_FUNCTION_REPLACEMENT: bool = false,
    DELETE_DEPENDANT_PARAMETERS_WHEN_FUNCTION_DELETED: bool = true,
    MAX_NUM_UNIQUE_FUNCTION_PAYLOADS: PowerOf2 = ._65_536,
    MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE: PowerOf2 = ._256,
    ALLOWED_RECURSIVE_UPDATES: usize = 0,
    MAX_PAYLOAD_LIST_LIMIT: PowerOf2 = ._2_097_152,

    pub fn make_pool_type(comptime self: Settings) type {
        comptime var defs: [self.TYPE_POOL_DEFS.len]SubPoolDef = undefined;
        inline for (self.TYPE_POOL_DEFS, 0..) |def, i| {
            defs[i] = def.to_sub_pool_def();
        }
        return GlobalMultiTypeBitTrackedPool(GlobalPoolDef{
            .POOL_DEFS = defs[0..],
            .ELEM_STATE_ASSERT_MODE = self.ELEM_STATE_ASSERT_MODE,
            .MAX_GENERATION = self.MAX_GENERATION,
            .MAX_NUM_ELEMS = self.MAX_NUM_ELEMS_PER_TYPE,
            .THREAD_SAFETY = self.THREAD_SAFETY,
            .UNIQUE_NAME = self.UNIQUE_NAME ++ "_DATA_POOLS",
        });
    }
};

const FuncInOuts = struct {
    fn_type: type,
    in: type,
    out: type,
    num_ins: usize,
    num_outs: usize,
};

pub fn FuncDefinition(comptime FN_NAME: type) type {
    return struct {
        const Self = @This();
        NAME: FN_NAME,
        INPUT_STRUCT: type,
        OUTPUT_STRUCT: type,

        pub fn make_func_in_outs(comptime self: Self, comptime PSS: type) FuncInOuts {
            ct_assert_with_reason(Types.type_is_struct(self.INPUT_STRUCT), @src(), "function `{s}` input type was not a struct, got type `{s}`", .{ @tagName(self.NAME), @typeName(self.INPUT_STRUCT) });
            ct_assert_with_reason(Types.type_is_struct(self.OUTPUT_STRUCT), @src(), "function `{s}` output type was not a struct, got type `{s}`", .{ @tagName(self.NAME), @typeName(self.OUTPUT_STRUCT) });
            const IN_INFO = @typeInfo(self.INPUT_STRUCT).@"struct";
            const OUT_INFO = @typeInfo(self.OUTPUT_STRUCT).@"struct";
            comptime var in_keys: [IN_INFO.field_types.len]type = undefined;
            comptime var in_attrs: [IN_INFO.field_types.len]std.builtin.Type.Struct.FieldAttributes = undefined;
            inline for (IN_INFO.field_types, 0..) |real_t, i| {
                in_attrs[i] = std.builtin.Type.Struct.FieldAttributes{
                    .@"align" = null,
                    .@"comptime" = false,
                    .default_value_ptr = @ptrCast(&PSS.ConstKey(real_t).INVALID),
                };
                in_keys[i] = PSS.ConstKey(real_t);
            }
            const IN_STRUCT = @Struct(.auto, null, IN_INFO.field_names, &in_keys, &in_attrs);
            comptime var out_keys: [IN_INFO.field_types.len]type = undefined;
            comptime var out_attrs: [IN_INFO.field_types.len]std.builtin.Type.Struct.FieldAttributes = undefined;
            inline for (OUT_INFO.field_types, 0..) |real_t, i| {
                out_attrs[i] = std.builtin.Type.Struct.FieldAttributes{
                    .@"align" = null,
                    .@"comptime" = false,
                    .default_value_ptr = @ptrCast(&PSS.Key(real_t).INVALID),
                };
                out_keys[i] = PSS.Key(real_t);
            }
            const OUT_STRUCT = @Struct(.auto, null, OUT_INFO.field_names, &out_keys, &out_attrs);
            const FN_PARAM_TYPES = [2]type{ IN_STRUCT, OUT_STRUCT };
            const FN_PARAM_ATTRS = [2]std.builtin.Type.Fn.ParamAttributes{
                std.builtin.Type.Fn.ParamAttributes{ .@"noalias" = false },
                std.builtin.Type.Fn.ParamAttributes{ .@"noalias" = false },
            };
            const FN = @Fn(FN_PARAM_TYPES[0..], &FN_PARAM_ATTRS, void, .{ .@"callconv" = .auto, .varargs = false });
            return FuncInOuts{
                .in = IN_STRUCT,
                .out = OUT_STRUCT,
                .fn_type = FN,
                .num_ins = in_keys.len,
                .num_outs = out_keys.len,
            };
        }
    };
}

pub fn ParametricStateSystem(
    /// The main settings for the ParametricStateSystem
    comptime SETTINGS_: Settings,
    /// An enum type with a tag name for each function that will be used for updates.
    comptime FUNCTION_NAMES: type,
    /// A list of function definitions that define the inputs and outputs
    /// for each defined function name
    comptime FUNCTION_DEFS: [Types.enum_defined_field_count(FUNCTION_NAMES)]FuncDefinition(FUNCTION_NAMES),
) type {
    ct_assert_with_reason(Types.type_is_enum(FUNCTION_NAMES) and Types.all_enum_values_start_from_zero_with_no_gaps(FUNCTION_NAMES), @src(), "type `FUNCTION_NAMES` must be an enum type with tag values from 0 to max with no gaps, got type `{s}`", .{@typeName(FUNCTION_NAMES)});
    const NUM_FUNCTIONS = Types.enum_defined_field_count(FUNCTION_NAMES);
    comptime var ordered_func_defs: [NUM_FUNCTIONS]FuncDefinition(FUNCTION_NAMES) = undefined;
    comptime var func_defs_defined: [NUM_FUNCTIONS]bool = @splat(false);
    comptime var ordered_func_names: [NUM_FUNCTIONS][]const u8 = undefined;
    inline for (FUNCTION_DEFS) |fn_def| {
        const idx = @backingInt(fn_def.NAME);
        ct_assert_with_reason(func_defs_defined[idx] == false, @src(), "func name `{s}` was defined more than once", .{@tagName(fn_def.NAME)});
        func_defs_defined[idx] = true;
        ordered_func_names[idx] = @tagName(fn_def.NAME);
        ordered_func_defs[idx] = fn_def;
    }
    const ordered_func_defs_const = ordered_func_defs;
    const ordered_func_names_const = ordered_func_names;

    return struct {
        const SelfPSS = @This();

        pub const SETTINGS = SETTINGS_;
        pub const GlobalDataPool = SETTINGS.make_pool_type();
        pub const OpaqueKey = GlobalDataPool.OpaqueKey;
        pub fn Key(comptime T: type) type {
            return struct {
                const KeySelf = @This();
                const PKey = GlobalDataPool.Key(T);
                const Field = PKey.Field;
                pub inline fn FieldType(comptime field: Field) type {
                    return PKey.FieldType(field);
                }
                const FA_MODE = PKey.FA_MODE;
                const DEF_IDX: usize = get: {
                    for (SETTINGS.TYPE_POOL_DEFS, 0..) |type_def, i| {
                        if (type_def.TYPE == T) {
                            break :get i;
                        }
                        ct_assert_unreachable(@src(), "type `{s}` is not a valid type for any type pool in the ParametricStateSystem `{s}`", .{ @typeName(T), SETTINGS.UNIQUE_NAME });
                    }
                };
                const DEFAULT: T = get: {
                    const type_def = SETTINGS.TYPE_POOL_DEFS[DEF_IDX];
                    if (type_def.DEFAULT_VALUE_FOR_TYPE) |default_ptr| {
                        break :get @as(*const T, @ptrCast(@alignCast(default_ptr))).*;
                    } else {
                        break :get undefined;
                    }
                };
                const val_equal: *const fn (T, T) bool = get: {
                    const type_def = SETTINGS.TYPE_POOL_DEFS[DEF_IDX];
                    break :get @ptrCast(@alignCast(type_def.TYPE_EQUALITY_FUNC));
                };

                pkey: PKey,

                pub fn to_opaque(self: KeySelf) OpaqueKey {
                    return self.pkey.to_opaque();
                }
                pub fn from_opaque(opq: OpaqueKey) KeySelf {
                    return KeySelf{ .pkey = PKey.from_opaque(opq) };
                }

                pub fn queue_update(self: KeySelf) void {
                    //FIXME
                }

                pub fn is_valid(self: KeySelf) bool {
                    return self.pkey.is_valid();
                }

                pub inline fn get(self: KeySelf) T {
                    return self.pkey.get();
                }
                pub inline fn get_or_default(self: KeySelf) T {
                    if (self.is_valid()) {
                        return self.pkey.get();
                    } else {
                        return DEFAULT;
                    }
                }
                pub inline fn get_field(self: KeySelf, comptime field: Field) FieldType(field) {
                    return self.pkey.get_field(field);
                }
                pub inline fn get_field_or_default(self: KeySelf, comptime field: Field) FieldType(field) {
                    if (self.is_valid()) {
                        return self.pkey.get_field(field);
                    } else {
                        @field(DEFAULT, @tagName(field));
                    }
                }
                

                pub inline fn set(self: KeySelf, val: T) void {
                    const old = self.pkey.get();
                    self.set_known_old(old, val);
                }
                pub inline fn set_known_old(self: KeySelf, old: T, val: T) void {
                    self.pkey.set(val);
                    if (!val_equal(old, val)) {
                        self.queue_update();
                    }
                }
                pub inline fn set_force_update(self: KeySelf, val: T) void {
                    self.pkey.set(val);
                    self.queue_update();
                }
                pub inline fn set_ignore_update(self: KeySelf, val: T) void {
                    self.pkey.set(val);
                }
                pub inline fn set_field(self: KeySelf, comptime field: Field, val: FieldType(field)) void {
                    const old = self.pkey.get();
                    self.set_field_known_old(old, field, val);
                }
                pub inline fn set_field_known_old(self: KeySelf, old: T, comptime field: Field, val: FieldType(field)) void {
                    self.pkey.set_field(val);
                    switch (comptime FA_MODE) {
                        .STRUCT => {
                            var new = old;
                            @field(new, @tagName(field)) = val;
                            if (!val_equal(old, new)) {
                                self.queue_update();
                            }
                        },
                        .UNION_TAGGED, .UNION_UNTAGGED => {
                            const new = @unionInit(T, @tagName(field), val);
                            if (!val_equal(old, new)) {
                                self.queue_update();
                            }
                        },
                        .NOT_SUPPORTED => unreachable,
                    }
                }
                pub inline fn set_force_update(self: KeySelf, comptime field: Field, val: FieldType(field)) void {
                    self.pkey.set_field(field, val);
                    self.queue_update();
                }
                pub inline fn set_ignore_update(self: KeySelf, comptime field: Field, val: FieldType(field)) void {
                    self.pkey.set_field(field, val);
                }
            };
        }
        pub fn ConstKey(comptime T: type) type {
            return struct {
                const KeySelf = @This();
                const PKey = GlobalDataPool.ConstKey(T);
                const Field = PKey.Field;
                pub inline fn FieldType(comptime field: Field) type {
                    return PKey.FieldType(field);
                }
                const FA_MODE = PKey.FA_MODE;
                const DEF_IDX: usize = get: {
                    for (SETTINGS.TYPE_POOL_DEFS, 0..) |type_def, i| {
                        if (type_def.TYPE == T) {
                            break :get i;
                        }
                        ct_assert_unreachable(@src(), "type `{s}` is not a valid type for any type pool in the ParametricStateSystem `{s}`", .{ @typeName(T), SETTINGS.UNIQUE_NAME });
                    }
                };
                const DEFAULT: T = get: {
                    const type_def = SETTINGS.TYPE_POOL_DEFS[DEF_IDX];
                    if (type_def.DEFAULT_VALUE_FOR_TYPE) |default_ptr| {
                        break :get @as(*const T, @ptrCast(@alignCast(default_ptr))).*;
                    } else {
                        break :get undefined;
                    }
                };
                const val_equal: *const fn (T, T) bool = get: {
                    const type_def = SETTINGS.TYPE_POOL_DEFS[DEF_IDX];
                    break :get @ptrCast(@alignCast(type_def.TYPE_EQUALITY_FUNC));
                };

                pkey: PKey,

                pub fn to_opaque(self: KeySelf) OpaqueKey {
                    return self.pkey.to_opaque();
                }
                pub fn from_opaque(opq: OpaqueKey) KeySelf {
                    return KeySelf{ .pkey = PKey.from_opaque(opq) };
                }

                pub fn is_valid(self: KeySelf) bool {
                    return self.pkey.is_valid();
                }

                pub inline fn get(self: KeySelf) T {
                    return self.pkey.get();
                }
                pub inline fn get_field(self: KeySelf, comptime field: Field) FieldType(field) {
                    return self.pkey.get_field(field);
                }
                pub inline fn get_or_default(self: KeySelf) T {
                    if (self.is_valid()) {
                        return self.pkey.get();
                    } else {
                        return DEFAULT;
                    }
                }
                pub inline fn get_field_or_default(self: KeySelf, comptime field: Field) FieldType(field) {
                    if (self.is_valid()) {
                        return self.pkey.get_field(field);
                    } else {
                        @field(DEFAULT, @tagName(field));
                    }
                }
                pub inline fn get_field(self: KeySelf, comptime field: Field) FieldType(field) {
                    return self.pkey.get_field(field);
                }
            };
        }
        const FUNC_DEFS = ordered_func_defs_const;
        const FUNC_IN_OUTS = make: {
            var vals: [NUM_FUNCTIONS]FuncInOuts = undefined;
            for (FUNC_DEFS, 0..) |def, i| {
                vals[i] = def.make_func_in_outs(SelfPSS);
            }
            break :make vals;
        };
        const FUNC_NAMES = ordered_func_names_const;
        const FUNC_PTR_TYPES = get: {
            var vals: [NUM_FUNCTIONS]type = undefined;
            for (FUNC_IN_OUTS, 0..) |in_out, i| {
                vals[i] = *const in_out.fn_type;
            }
            break :get vals;
        };
        const FUNC_INS = get: {
            var vals: [NUM_FUNCTIONS]type = undefined;
            for (FUNC_IN_OUTS, 0..) |in_out, i| {
                vals[i] = in_out.in;
            }
            break :get vals;
        };
        const FUNC_IN_COUNTS = get: {
            var vals: [NUM_FUNCTIONS]usize = undefined;
            for (FUNC_IN_OUTS, 0..) |in_out, i| {
                vals[i] = in_out.num_ins;
            }
            break :get vals;
        };
        const FUNC_OUTS = get: {
            var vals: [NUM_FUNCTIONS]type = undefined;
            for (FUNC_IN_OUTS, 0..) |in_out, i| {
                vals[i] = in_out.out;
            }
            break :get vals;
        };
        const FUNC_OUT_COUNTS = get: {
            var vals: [NUM_FUNCTIONS]usize = undefined;
            for (FUNC_IN_OUTS, 0..) |in_out, i| {
                vals[i] = in_out.num_outs;
            }
            break :get vals;
        };
        const MAX_FN_INPUTS = check: {
            var max: usize = 0;
            for (FUNC_IN_OUTS) |in_out| {
                max = @max(max, in_out.num_ins);
            }
            break :check max;
        };
        const MAX_FN_OUTPUTS = check: {
            var max: usize = 0;
            for (FUNC_IN_OUTS) |in_out| {
                max = @max(max, in_out.num_outs);
            }
            break :check max;
        };

        const FnInIdx = PowerOf2.round_up_to_power_of_2(MAX_FN_INPUTS).unsigned_integer_type_that_holds_all_values_less_than();
        const FnOutIdx = PowerOf2.round_up_to_power_of_2(MAX_FN_OUTPUTS).unsigned_integer_type_that_holds_all_values_less_than();
        const PayloadListIdx = SETTINGS.MAX_PAYLOAD_LIST_LIMIT.unsigned_integer_type_that_holds_all_values_less_than();
        const UpdateTriggerIdx = SETTINGS.MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE.unsigned_integer_type_that_holds_all_values_less_than();
        const UniquePayloadIdx = SETTINGS.MAX_NUM_UNIQUE_FUNCTION_PAYLOADS.unsigned_integer_type_that_holds_all_values_less_than();
        const RecursionCounter = if (RECURSION_ALLOWED) PowerOf2.round_down_to_power_of_2(RECURSION_LIMIT).unsigned_integer_type_that_holds_all_values_less_than() else void;
        const RecursionCounterDefault = if (RECURSION_ALLOWED) 0 else {};
        const FnName = FUNCTION_NAMES;
        pub fn FnType(comptime FUNC_NAME: FnName) type {
            return FUNC_PTR_TYPES[@backingInt(FUNC_NAME)];
        }
        pub fn InStruct(comptime FUNC_NAME: FnName) type {
            return FUNC_INS[@backingInt(FUNC_NAME)];
        }
        pub fn OutStruct(comptime FUNC_NAME: FnName) type {
            return FUNC_OUTS[@backingInt(FUNC_NAME)];
        }
        pub fn InCount(comptime FUNC_NAME: FnName) usize {
            return FUNC_IN_COUNTS[@backingInt(FUNC_NAME)];
        }
        pub fn OutCount(comptime FUNC_NAME: FnName) usize {
            return FUNC_OUT_COUNTS[@backingInt(FUNC_NAME)];
        }
        const FUNC_POINTERS_STRUCT = build: {
            const ATTRS: [NUM_FUNCTIONS]std.builtin.Type.Struct.FieldAttributes = @splat(std.builtin.Type.Struct.FieldAttributes{
                .@"align" = null,
                .@"comptime" = true,
                .default_value_ptr = null,
            });
            break :build @Struct(.auto, null, FUNC_NAMES[0..], &FUNC_PTR_TYPES, &ATTRS);
        };
        var FUNC_POINTERS: FUNC_POINTERS_STRUCT = undefined;
        pub inline fn get_fn(comptime FUNC_NAME: FnName) FnType(FUNC_NAME) {
            return @field(FUNC_POINTERS, @tagName(FUNC_NAME));
        }
        pub inline fn call_fn(comptime FUNC_NAME: FnName, in: InStruct(FUNC_NAME), out: OutStruct(FUNC_NAME)) void {
            return @field(FUNC_POINTERS, @tagName(FUNC_NAME))(in, out);
        }

        pub const RECURSION_ALLOWED = SETTINGS.ALLOWED_RECURSIVE_UPDATES > 0;
        pub const RECURSION_LIMIT: u32 = if (SETTINGS.ALLOWED_RECURSIVE_UPDATES > 0) @intCast(SETTINGS.ALLOWED_RECURSIVE_UPDATES) else 0;

        pub const Assert = Assert_.AssertHandler(SETTINGS.MASTER_ASSERT_MODE);
        pub const RecursionAssert = Assert_.AssertHandler(SETTINGS.RECURSION_ASSERT_MODE);

        pub const PoolKey = struct {
            idx: IndexType,
            gen: GenId,
        };

        pub const ParamMeta = struct {
            update_mode: UpdateMode = .ONLY_TRIGGER_UPDATES_ON_VALUE_CHANGE,
            parent_delete_behavior: ParentDeleteMode = .TRIGGER_UPDATE_WHEN_PARENT_DELETED,
            get_deleted_behavior: GetDeletedParamMode = .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED,
            set_deleted_behavior: SetDeletedParamMode = .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED,
            generation: GenId = 0,
            first_dep: ?*DependantNode = null,
            last_dep: ?*DependantNode = null,
        };

        pub const PayloadBlock = struct {
            refs: [SETTINGS.MAX_NUM_FUNCTION_INPUTS + SETTINGS.MAX_NUM_FUNCTION_OUTPUTS]ParamRef = undefined,
            in_count: InputCount = 0,
            out_count: OutputCount = 0,
        };

        pub const UpdatePackage = struct {
            func_idx: FuncId,
            payload: *PayloadBlock,
            in_count: InputCount,
            out_count: OutputCount,
            alive: bool = false,
            queued_epoch: u32 = 0,
            pending: bool = false,
            recursion_count: u32 = 0,
        };

        pub const FunctionDependants = *UpdatePackage;
        pub const UpdateQueueItem = *UpdatePackage;
        pub const UpdateQueueUnique = *UpdatePackage;

        pub const DependantNode = struct {
            package: *UpdatePackage,
            next: ?*DependantNode = null,
        };

        const CATEGORY_POOLS: [NUM_CATEGORIES]type = build: {
            var out: [NUM_CATEGORIES]type = undefined;
            for (CATEGORY_DEFS, 0..) |def, cat| {
                const name = std.fmt.comptimePrint("{s}|cat{d}", .{ @typeName(PARAM_CATEGORIES), cat });
                out[cat] = GlobalMappedKeyPool(.{
                    .ELEM = def.param_type,
                    .IDX = IndexType,
                    .LOCK_MODE = .NO_LOCKS,
                    .GLOBAL_POOL_NAME = name,
                });
            }
            break :build out;
        };

        const PayloadPool = BitTrackedPool(.{ .ELEM = PayloadBlock, .IDX = u32, .LOCK_MODE = .NO_LOCKS, .SLOTS_PER_BLOCK = 64 });
        const PackagePool = BitTrackedPool(.{ .ELEM = UpdatePackage, .IDX = u32, .LOCK_MODE = .NO_LOCKS, .SLOTS_PER_BLOCK = 64 });
        const DepPool = BitTrackedPool(.{ .ELEM = DependantNode, .IDX = u32, .LOCK_MODE = .NO_LOCKS, .SLOTS_PER_BLOCK = 64 });

        const ListAlloc = Root.ListSlice.ListFullDefinition;
        const MetaList = ListAlloc(ParamMeta, IndexType, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, .MANUAL_ALLOC);
        const QueueList = ListAlloc(UpdateQueueItem, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, .MANUAL_ALLOC);
        const DeleteList = ListAlloc(ParamRef, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, .MANUAL_ALLOC);
        const FuncList = ListAlloc(FunctionDependants, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, .MANUAL_ALLOC);

        pub var initialized: bool = false;
        var system_allocator: Allocator = DummyAllocator.allocator_panic_free_noop;

        var payload_pool: PayloadPool = .{};

        var package_pool: PackagePool = .{};
        var dep_pool: DepPool = .{};

        var update_queue: QueueList = QueueList.new();
        var update_queue_cursor: usize = 0;

        var delete_queue: DeleteList = DeleteList.new();

        var funcs: [NUM_FUNCTIONS]*const UpdateFunction = @splat(Utils.invalid_ptr_const(UpdateFunction));
        var funcs_init: [NUM_FUNCTIONS]bool = @splat(false);
        var func_packages: [NUM_FUNCTIONS]FuncList = @splat(FuncList.new());
        var func_packages_init: [NUM_FUNCTIONS]bool = @splat(false);

        var metas: [NUM_CATEGORIES]MetaList = @splat(MetaList.new());

        var category_counts: [NUM_CATEGORIES]IndexType = @splat(0);

        // Meta category side storage.  Slot `i` tracks user category `i`.
        var meta_values: [NUM_USER_CATEGORIES]IndexType = @splat(0);
        var meta_first_deps: [NUM_USER_CATEGORIES]?*DependantNode = @splat(null);
        var meta_last_deps: [NUM_USER_CATEGORIES]?*DependantNode = @splat(null);
        var meta_metas: [NUM_USER_CATEGORIES]ParamMeta = @splat(.{});

        var current_epoch: u32 = 0;
        var cascade_active: bool = false;
        var updates_in_progress: bool = false;
        var deletes_in_progress: bool = false;

        inline fn assert_initialized() void {
            assert_with_reason(initialized, @src(), "ParametricStateSystem memory has not been initialized (call `init` first)", .{});
        }

        inline fn to_pool_key(key: anytype) PoolKey {
            return .{ .idx = @intCast(key.idx), .gen = @intCast(key.gen) };
        }
        inline fn to_typed_key(comptime P: type, key: PoolKey) P.Key {
            return .{ .idx = @intCast(key.idx), .gen = @intCast(key.gen) };
        }

        fn claim_pool_key_for_category(cat: CategoryId) PoolKey {
            inline for (0..NUM_CATEGORIES) |c| {
                if (cat == c) {
                    const P = CATEGORY_POOLS[c];
                    return to_pool_key(P.claim_key());
                }
            }
            unreachable;
        }
        fn claim_pool_key_consecutive(cat: CategoryId, count: IndexType) PoolKey {
            inline for (0..NUM_CATEGORIES) |c| {
                if (cat == c) {
                    const P = CATEGORY_POOLS[c];
                    return to_pool_key(P.claim_consecutive(count));
                }
            }
            unreachable;
        }
        fn release_pool_key_for_category(cat: CategoryId, key: PoolKey) void {
            inline for (0..NUM_CATEGORIES) |c| {
                if (cat == c) {
                    const P = CATEGORY_POOLS[c];
                    P.release_key(to_typed_key(P, key));
                    return;
                }
            }
            unreachable;
        }
        fn pool_key_is_valid(cat: CategoryId, key: PoolKey) bool {
            inline for (0..NUM_CATEGORIES) |c| {
                if (cat == c) {
                    const P = CATEGORY_POOLS[c];
                    return to_typed_key(P, key).is_valid();
                }
            }
            unreachable;
        }
        fn key_is_valid(cat: CategoryId, key: PoolKey) bool {
            if (INCLUDE_META and cat == META_CAT_IDX) return key.idx < NUM_USER_CATEGORIES;
            return pool_key_is_valid(cat, key);
        }

        fn get_value_bytes(ref: ParamRef, out: []u8) void {
            if (INCLUDE_META and ref.category == META_CAT_IDX) {
                const bytes = std.mem.asBytes(&meta_values[ref.index]);
                @memcpy(out[0..bytes.len], bytes);
                return;
            }
            inline for (0..NUM_CATEGORIES) |c| {
                if (ref.category == c) {
                    const P = CATEGORY_POOLS[c];
                    const key = to_typed_key(P, .{ .idx = ref.index, .gen = ref.generation });
                    const value = key.get();
                    const bytes = std.mem.asBytes(&value);
                    @memcpy(out[0..CATEGORY_TYPE_SIZES[ref.category]], bytes);
                    return;
                }
            }
            unreachable;
        }
        fn set_value_bytes(ref: ParamRef, bytes: []const u8) void {
            if (INCLUDE_META and ref.category == META_CAT_IDX) {
                const dst = std.mem.asBytes(&meta_values[ref.index]);
                @memcpy(dst, bytes[0..dst.len]);
                return;
            }
            inline for (0..NUM_CATEGORIES) |c| {
                if (ref.category == c) {
                    const T = CATEGORY_DEFS[c].param_type;
                    const P = CATEGORY_POOLS[c];
                    var value: T = undefined;
                    @memcpy(std.mem.asBytes(&value), bytes[0..@sizeOf(T)]);
                    to_typed_key(P, .{ .idx = ref.index, .gen = ref.generation }).set(value);
                    return;
                }
            }
            unreachable;
        }

        fn ensure_meta_len(cat: CategoryId, index: IndexType) void {
            const list = &metas[cat];
            const old_len = list.get_len();
            const new_len = index + 1;
            if (new_len <= old_len) return;
            list.grow_capacity_if_needed(new_len, .GROW_BY_25_PERCENT, system_allocator);
            list.set_len(new_len);
            list.memset_range(ParamMeta{}, old_len, new_len);
        }

        fn get_meta_at(cat: CategoryId, index: IndexType) ParamMeta {
            if (INCLUDE_META and cat == META_CAT_IDX) {
                assert_with_reason(index < NUM_USER_CATEGORIES, @src(), "meta parameter index {d} out of range", .{index});
                return meta_metas[index];
            }
            const list = &metas[cat];
            if (index >= list.get_len()) return .{};
            return list.get_ptr(index).*;
        }
        fn set_meta_at(cat: CategoryId, index: IndexType, meta: ParamMeta) void {
            if (INCLUDE_META and cat == META_CAT_IDX) {
                assert_with_reason(index < NUM_USER_CATEGORIES, @src(), "meta parameter index {d} out of range", .{index});
                meta_metas[index] = meta;
                return;
            }
            ensure_meta_len(cat, index);
            metas[cat].get_ptr(index).* = meta;
        }
        fn ensure_meta_index(cat: CategoryId, index: IndexType) void {
            if (INCLUDE_META and cat == META_CAT_IDX) return;
            ensure_meta_len(cat, index);
        }

        fn read_typed_direct(comptime T: type, ref: ParamRef) T {
            if (INCLUDE_META and ref.category == META_CAT_IDX) {
                if (comptime T == IndexType) return @intCast(meta_values[ref.index]);
                unreachable;
            }
            inline for (0..NUM_CATEGORIES) |c| {
                if (comptime CATEGORY_DEFS[c].param_type == T) {
                    if (ref.category == c) {
                        const P = CATEGORY_POOLS[c];
                        return to_typed_key(P, .{ .idx = ref.index, .gen = ref.generation }).get();
                    }
                }
            }
            unreachable;
        }

        fn begin_cascade() void {
            if (!cascade_active) {
                cascade_active = true;
                current_epoch +%= 1;
                if (current_epoch == 0) current_epoch = 1;
            }
        }
        fn try_end_cascade() void {
            if (!updates_in_progress and !deletes_in_progress and update_queue_cursor >= update_queue.get_len() and delete_queue.get_len() == 0) {
                cascade_active = false;
                update_queue.clear();
                update_queue_cursor = 0;
            }
        }
        fn queue_package(pkg: *UpdatePackage) void {
            begin_cascade();
            if (!pkg.alive) return;
            if (pkg.pending) return;
            if (pkg.queued_epoch == current_epoch) {
                if (RECURSION_ALLOWED) {
                    if (pkg.recursion_count < RECURSION_LIMIT) {
                        pkg.recursion_count += 1;
                    } else {
                        RecursionAssert._unreachable(@src(), "recursive parameter update detected (limit {d}) for package {*}", .{ RECURSION_LIMIT, pkg });
                        return;
                    }
                } else {
                    RecursionAssert._unreachable(@src(), "recursive parameter update detected: package {*} was already processed in this cascade (set ALLOWED_RECURSIVE_UPDATES to permit this)", .{pkg});
                    return;
                }
            } else {
                pkg.recursion_count = 0;
            }
            pkg.pending = true;
            update_queue.append_one(pkg, system_allocator);
        }

        fn trigger_dependants(ref: ParamRef) void {
            var dep = if (INCLUDE_META and ref.category == META_CAT_IDX)
                meta_first_deps[ref.index]
            else
                get_meta_at(ref.category, ref.index).first_dep;
            while (dep) |node| {
                queue_package(node.package);
                dep = node.next;
            }
        }

        fn update_meta_for_category(cat: CategoryId) void {
            if (!INCLUDE_META or cat >= NUM_USER_CATEGORIES) return;
            const new_len = category_counts[cat];
            const always = SETTINGS.INCLUDE_META_CATEGORY == .META_CATEGORY_LENGTH_AND_VALUE_CHANGE;
            if (meta_values[cat] != new_len or always) {
                meta_values[cat] = new_len;
                trigger_dependants(.{ .category = @intCast(META_CAT_IDX), .index = cat, .generation = 0 });
            }
        }

        fn add_dependant(ref: ParamRef, pkg: *UpdatePackage) void {
            const node = dep_pool.claim_slot(system_allocator);
            node.* = .{ .package = pkg, .next = null };
            if (INCLUDE_META and ref.category == META_CAT_IDX) {
                if (meta_first_deps[ref.index]) |last| {
                    last.next = node;
                } else {
                    meta_first_deps[ref.index] = node;
                }
                meta_last_deps[ref.index] = node;
            } else {
                var meta = get_meta_at(ref.category, ref.index);
                if (meta.last_dep) |last| {
                    last.next = node;
                } else {
                    meta.first_dep = node;
                }
                meta.last_dep = node;
                set_meta_at(ref.category, ref.index, meta);
            }
        }

        fn release_dependant_node_chain(first: ?*DependantNode) void {
            var dep = first;
            while (dep) |node| {
                const next = node.next;
                dep_pool.release_slot(node);
                dep = next;
            }
        }

        fn remove_package_from_queue(pkg: *UpdatePackage) void {
            var i: u32 = @intCast(update_queue_cursor);
            while (i < update_queue.get_len()) {
                if (update_queue.get_ptr(i).* == pkg) {
                    var j = i;
                    while (j + 1 < update_queue.get_len()) : (j += 1) {
                        update_queue.get_ptr(j).* = update_queue.get_ptr(j + 1).*;
                    }
                    update_queue.decr_len(1);
                } else {
                    i += 1;
                }
            }
            pkg.pending = false;
        }

        fn create_package(func_idx: FuncId, inputs: []const ParamRef, output_refs: []ParamRef) *UpdatePackage {
            const block = payload_pool.claim_slot(system_allocator);
            @memcpy(block.refs[0..inputs.len], inputs);
            @memcpy(block.refs[inputs.len .. inputs.len + output_refs.len], output_refs);
            block.in_count = @intCast(inputs.len);
            block.out_count = @intCast(output_refs.len);

            const pkg = package_pool.claim_slot(system_allocator);
            pkg.* = .{
                .func_idx = func_idx,
                .payload = block,
                .in_count = @intCast(inputs.len),
                .out_count = @intCast(output_refs.len),
                .alive = true,
            };
            return pkg;
        }

        fn register_package(pkg: *UpdatePackage, inputs: []const ParamRef) void {
            for (inputs) |input| add_dependant(input, pkg);
            const f: usize = @intCast(pkg.func_idx);
            func_packages[f].append_one(pkg, system_allocator);
        }

        fn remove_package_from_input_dependants(pkg: *UpdatePackage) void {
            const block = pkg.payload;
            for (0..pkg.in_count) |i| {
                const ref = block.refs[i];
                if (INCLUDE_META and ref.category == META_CAT_IDX) {
                    remove_dep_node_for_package(&meta_first_deps[ref.index], &meta_last_deps[ref.index], pkg);
                } else {
                    var meta = get_meta_at(ref.category, ref.index);
                    remove_dep_node_for_package(&meta.first_dep, &meta.last_dep, pkg);
                    set_meta_at(ref.category, ref.index, meta);
                }
            }
        }

        fn remove_dep_node_for_package(first: *?*DependantNode, last: *?*DependantNode, pkg: *UpdatePackage) void {
            var prev: ?*DependantNode = null;
            var cur = first.*;
            while (cur) |node| {
                const next = node.next;
                if (node.package == pkg) {
                    if (prev) |p| {
                        p.next = next;
                    } else {
                        first.* = next;
                    }
                    if (last.* == node) last.* = prev;
                    dep_pool.release_slot(node);
                    return;
                }
                prev = node;
                cur = next;
            }
        }

        fn destroy_package(pkg: *UpdatePackage) void {
            if (!pkg.alive) return;
            remove_package_from_input_dependants(pkg);
            remove_package_from_queue(pkg);
            payload_pool.release_slot(pkg.payload);
            pkg.alive = false;
            package_pool.release_slot(pkg);
        }

        fn get_typed_locked(comptime T: type, ref: ParamRef, mutex_key: MutexKey, comptime SKIP_GEN_CHECK: bool) T {
            var key: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer key.unlock_if_needed(owns);
            _ = SKIP_GEN_CHECK;
            assert_with_reason(CATEGORY_TYPE_IDS[ref.category] == id_for_type(T), @src(), "category type does not match the parameter type", .{});
            if (key_is_valid(ref.category, .{ .idx = ref.index, .gen = ref.generation })) {
                return read_typed_direct(T, ref);
            }
            const meta = get_meta_at(ref.category, ref.index);
            switch (meta.get_deleted_behavior) {
                .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED => assert_unreachable(@src(), "attempted to access parameter (category `{s}` index {d}) that is not used (or uses a stale generation)", .{ @tagName(@as(PARAM_CATEGORIES, @fromBackingInt(@intCast(ref.category)))), ref.index }),
                else => {
                    assert_with_reason(CATEGORY_DEFAULT_VALUES[ref.category] != null, @src(), "getting parameter `{s}` index {d} that is not used (settings set to return default value), but category has no default value", .{ @tagName(@as(PARAM_CATEGORIES, @fromBackingInt(@intCast(ref.category)))), ref.index });
                    if (meta.get_deleted_behavior == .RETURN_DEFAULT_VALUE_WHEN_GET_DELETED_AND_WARN) {
                        Assert_.warn_unconditional_always(@src(), "get parameter that was not used (or stale generation) `{s}` index {d}", .{ @tagName(@as(PARAM_CATEGORIES, @fromBackingInt(@intCast(ref.category)))), ref.index });
                    }
                    const default_ptr: *const T = @ptrCast(@alignCast(CATEGORY_DEFAULT_VALUES[ref.category].?));
                    return default_ptr.*;
                },
            }
        }

        fn values_equal(comptime T: type, cat: CategoryId, a: T, b: T) bool {
            const eq: *const fn (T, T) bool = @ptrCast(@alignCast(CATEGORY_EQUALITY_FUNCS[cat]));
            return eq(a, b);
        }

        fn set_typed_locked(comptime T: type, ref: ParamRef, val: T, mutex_key: MutexKey, comptime SKIP_PROCESS: bool) void {
            var key: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer key.unlock_if_needed(owns);
            assert_with_reason(CATEGORY_TYPE_IDS[ref.category] == id_for_type(T), @src(), "category type does not match the parameter type", .{});
            const meta = get_meta_at(ref.category, ref.index);
            if (!key_is_valid(ref.category, .{ .idx = ref.index, .gen = ref.generation })) {
                switch (meta.set_deleted_behavior) {
                    .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED => assert_unreachable(@src(), "attempted to set parameter (category `{s}` index {d}) that is not used (or uses a stale generation)", .{ @tagName(@as(PARAM_CATEGORIES, @fromBackingInt(@intCast(ref.category)))), ref.index }),
                    .IGNORE_SETTING_PARAM_WHEN_DELETED => return,
                    .IGNORE_SETTING_PARAM_WHEN_DELETED_AND_WARN => {
                        Assert_.warn_unconditional_always(@src(), "set parameter that was not used (or stale generation) `{s}` index {d}", .{ @tagName(@as(PARAM_CATEGORIES, @fromBackingInt(@intCast(ref.category)))), ref.index });
                        return;
                    },
                }
            }
            const old = read_typed_direct(T, ref);
            const changed = !values_equal(T, ref.category, old, val);
            const bytes = std.mem.asBytes(&val);
            set_value_bytes(ref, bytes[0..@sizeOf(T)]);
            if (changed) {
                if (meta.update_mode != .NEVER_TRIGGER_UPDATES) {
                    trigger_dependants(ref);
                }
                if (INCLUDE_META and SETTINGS.INCLUDE_META_CATEGORY == .META_CATEGORY_LENGTH_AND_VALUE_CHANGE) {
                    update_meta_for_category(ref.category);
                }
            } else if (meta.update_mode == .ALWAYS_TRIGGER_UPDATES_EVEN_IF_VALUE_UNCHANGED) {
                trigger_dependants(ref);
                if (INCLUDE_META and SETTINGS.INCLUDE_META_CATEGORY == .META_CATEGORY_LENGTH_AND_VALUE_CHANGE) {
                    update_meta_for_category(ref.category);
                }
            }
            if (!SKIP_PROCESS) process_all_updates_if_needed(key);
        }

        fn set_opaque_locked(ref: ParamRef, bytes: []const u8, mutex_key: MutexKey, comptime SKIP_PROCESS: bool) void {
            var key: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer key.unlock_if_needed(owns);
            const meta = get_meta_at(ref.category, ref.index);
            if (!key_is_valid(ref.category, .{ .idx = ref.index, .gen = ref.generation })) {
                switch (meta.set_deleted_behavior) {
                    .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED => assert_unreachable(@src(), "attempted to set parameter (category index {d}) that is not used (or uses a stale generation)", .{ref.index}),
                    .IGNORE_SETTING_PARAM_WHEN_DELETED => return,
                    .IGNORE_SETTING_PARAM_WHEN_DELETED_AND_WARN => return,
                }
            }
            const size = CATEGORY_TYPE_SIZES[ref.category];
            var old: [LARGEST_CATEGORY_TYPE_SIZE]u8 = undefined;
            get_value_bytes(ref, old[0..size]);
            const changed = !std.mem.eql(u8, old[0..size], bytes[0..size]);
            set_value_bytes(ref, bytes[0..size]);
            if (changed) {
                if (meta.update_mode != .NEVER_TRIGGER_UPDATES) trigger_dependants(ref);
                if (INCLUDE_META and SETTINGS.INCLUDE_META_CATEGORY == .META_CATEGORY_LENGTH_AND_VALUE_CHANGE) {
                    update_meta_for_category(ref.category);
                }
            } else if (meta.update_mode == .ALWAYS_TRIGGER_UPDATES_EVEN_IF_VALUE_UNCHANGED) {
                trigger_dependants(ref);
            }
            if (!SKIP_PROCESS) process_all_updates_if_needed(key);
        }

        fn set_default_locked(ref: ParamRef, mutex_key: MutexKey, comptime SKIP_PROCESS: bool) void {
            const default_ptr = CATEGORY_DEFAULT_VALUES[ref.category];
            assert_with_reason(default_ptr != null, @src(), "parameter index {d} needs its default value, but the category has no default value", .{ref.index});
            const size = CATEGORY_TYPE_SIZES[ref.category];
            const bytes: [*]const u8 = @ptrCast(default_ptr.?);
            set_opaque_locked(ref, bytes[0..size], mutex_key, SKIP_PROCESS);
        }

        // ---- meta category helpers -----------------------------------------
        // ---- update processing ---------------------------------------------
        fn process_one_update(mutex_key: MutexKey, pkg: *UpdatePackage) void {
            if (!pkg.alive) return;
            const f: usize = @intCast(pkg.func_idx);
            if (!funcs_init[f]) return;
            const block = pkg.payload;
            const in_count: usize = @intCast(pkg.in_count);
            const out_count: usize = @intCast(pkg.out_count);
            const inputs = block.refs[0..in_count];
            const outputs = block.refs[in_count .. in_count + out_count];
            const iface = UpdateInterface{
                .inputs = inputs,
                .outputs = outputs,
                .key = mutex_key,
            };
            funcs[f](iface);
        }

        fn process_all_updates_if_needed(mutex_key: MutexKey) void {
            if (updates_in_progress) return;
            updates_in_progress = true;
            defer {
                updates_in_progress = false;
                try_end_cascade();
            }
            while (update_queue_cursor < update_queue.get_len()) {
                const pkg = update_queue.get_ptr(@intCast(update_queue_cursor)).*;
                update_queue_cursor += 1;
                pkg.pending = false;
                pkg.queued_epoch = current_epoch;
                process_one_update(mutex_key, pkg);
            }
            update_queue.clear();
            update_queue_cursor = 0;
        }

        fn process_one_delete(ref: ParamRef, mutex_key: MutexKey) void {
            if (!key_is_valid(ref.category, .{ .idx = ref.index, .gen = ref.generation })) return;
            var meta = get_meta_at(ref.category, ref.index);
            var dep = meta.first_dep;
            while (dep) |node| {
                dep = node.next;
                const pkg = node.package;
                if (pkg.alive) {
                    const block = pkg.payload;
                    const in_count: usize = @intCast(pkg.in_count);
                    var trigger = false;
                    for (0..pkg.out_count) |i| {
                        const out_ref = block.refs[in_count + i];
                        if (!key_is_valid(out_ref.category, .{ .idx = out_ref.index, .gen = out_ref.generation })) continue;
                        const out_meta = get_meta_at(out_ref.category, out_ref.index);
                        switch (out_meta.parent_delete_behavior) {
                            .DELETE_WHEN_PARENT_IS_DELETED => delete_queue.append_one(out_ref, system_allocator),
                            .SET_DEFAULT_VALUE_WHEN_PARENT_IS_DELETED => set_default_locked(out_ref, mutex_key, true),
                            .RETAIN_LAST_VALUE_WHEN_PARENT_DELETED => {},
                            .TRIGGER_UPDATE_WHEN_PARENT_DELETED => trigger = true,
                        }
                    }
                    if (trigger) queue_package(pkg);
                }
            }
            release_dependant_node_chain(meta.first_dep);
            meta.first_dep = null;
            meta.last_dep = null;
            set_meta_at(ref.category, ref.index, meta);

            release_pool_key_for_category(ref.category, .{ .idx = ref.index, .gen = ref.generation });
            if (category_counts[ref.category] > 0) category_counts[ref.category] -= 1;
            update_meta_for_category(ref.category);
        }

        fn process_all_deletes_if_needed(mutex_key: MutexKey, comptime SKIP_FIRST_GEN_CHECK: bool) void {
            if (deletes_in_progress) return;
            _ = SKIP_FIRST_GEN_CHECK;
            deletes_in_progress = true;
            defer deletes_in_progress = false;
            var cursor: usize = 0;
            while (cursor < delete_queue.get_len()) : (cursor += 1) {
                process_one_delete(delete_queue.get_ptr(@intCast(cursor)).*, mutex_key);
            }
            delete_queue.clear();
            process_all_updates_if_needed(mutex_key);
            try_end_cascade();
        }

        fn delete_param_internal(ref: ParamRef, mutex_key: MutexKey, comptime SKIP_FIRST_GEN_CHECK: bool, comptime SKIP_PROCESS: bool) void {
            var mk: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            begin_cascade();
            delete_queue.append_one(ref, system_allocator);
            if (!SKIP_PROCESS) process_all_deletes_if_needed(mk, SKIP_FIRST_GEN_CHECK);
        }

        fn create_root_with_key(cat: CategoryId, key: PoolKey, initial_val: anytype, settings: ParamReadWriteSettings, mutex_key: MutexKey, comptime SKIP_PROCESS: bool) ParamRef {
            var mk: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            ensure_meta_index(cat, key.idx);
            const meta = ParamMeta{
                .update_mode = settings.update_mode,
                .parent_delete_behavior = .RETAIN_LAST_VALUE_WHEN_PARENT_DELETED,
                .get_deleted_behavior = settings.get_deleted_mode,
                .set_deleted_behavior = settings.set_deleted_mode,
                .generation = key.gen,
            };
            set_meta_at(cat, key.idx, meta);
            const ref = ParamRef{ .category = cat, .index = key.idx, .generation = key.gen };
            set_value_bytes(ref, std.mem.asBytes(&initial_val));
            category_counts[cat] += 1;
            update_meta_for_category(cat);
            if (!SKIP_PROCESS) process_all_updates_if_needed(mk);
            return ref;
        }

        fn create_root_internal(comptime category: CategoryName, initial_val: CategoryType(category), settings: ParamReadWriteSettings, mutex_key: MutexKey) ParamRef {
            var mk: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            const cat: CategoryId = @intCast(@backingInt(category));
            const key = claim_pool_key_for_category(cat);
            return create_root_with_key(cat, key, initial_val, settings, mk, false);
        }

        fn create_derived_set_internal(
            func_name: FuncName,
            inputs: []const ParamRef,
            output_defs: []const ParamReadOnlyDef,
            output_refs: []ParamRef,
            preclaimed_first: ?PoolKey,
            preclaimed_offset: usize,
            mutex_key: MutexKey,
            comptime SKIP_PROCESS: bool,
        ) void {
            var mk: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            const func_idx: FuncId = @intCast(@backingInt(func_name));
            assert_with_reason(funcs_init[func_idx], @src(), "function `{s}` was not initialized", .{@tagName(func_name)});
            assert_with_reason(output_defs.len == output_refs.len, @src(), "`output_defs.len` must equal `output_refs.len`, got {d} != {d}", .{ output_defs.len, output_refs.len });
            assert_with_reason(inputs.len <= MAX_INPUTS, @src(), "the number of inputs ({d}) exceeds the maximum ({d})", .{ inputs.len, MAX_INPUTS });
            assert_with_reason(output_defs.len <= MAX_OUTPUTS, @src(), "the number of outputs ({d}) exceeds the maximum ({d})", .{ output_defs.len, MAX_OUTPUTS });
            for (inputs) |input| {
                assert_with_reason(key_is_valid(input.category, .{ .idx = input.index, .gen = input.generation }), @src(), "an input parameter was not in a used state", .{});
            }

            var touched_categories: [MAX_OUTPUTS]CategoryId = undefined;
            var touched_len: usize = 0;

            for (output_defs, output_refs, 0..) |def, *out_ref, out_i| {
                const cat: CategoryId = @intCast(@backingInt(def.category));
                const key = if (preclaimed_first) |first| PoolKey{
                    .idx = first.idx + @as(IndexType, @intCast(preclaimed_offset + out_i)),
                    .gen = first.gen,
                } else claim_pool_key_for_category(cat);
                ensure_meta_index(cat, key.idx);
                set_meta_at(cat, key.idx, .{
                    .update_mode = def.update_mode,
                    .parent_delete_behavior = def.parent_delete_mode,
                    .get_deleted_behavior = def.get_deleted_mode,
                    .set_deleted_behavior = def.set_deleted_mode,
                    .generation = key.gen,
                });
                out_ref.* = .{ .category = cat, .index = key.idx, .generation = key.gen };
                category_counts[cat] += 1;
                if (CATEGORY_DEFAULT_VALUES[cat]) |default_ptr| {
                    const bytes: [*]const u8 = @ptrCast(default_ptr);
                    set_value_bytes(out_ref.*, bytes[0..CATEGORY_TYPE_SIZES[cat]]);
                } else {
                    const zeros: [LARGEST_CATEGORY_TYPE_SIZE]u8 = @splat(0);
                    set_value_bytes(out_ref.*, zeros[0..CATEGORY_TYPE_SIZES[cat]]);
                }
                var already = false;
                for (touched_categories[0..touched_len]) |c| {
                    if (c == cat) {
                        already = true;
                        break;
                    }
                }
                if (!already) {
                    touched_categories[touched_len] = cat;
                    touched_len += 1;
                }
            }

            for (touched_categories[0..touched_len]) |cat| update_meta_for_category(cat);

            const pkg = create_package(func_idx, inputs, output_refs);
            register_package(pkg, inputs);
            queue_package(pkg);
            if (!SKIP_PROCESS) process_all_updates_if_needed(mk);
        }

        fn create_derived_set_from_struct(
            func_name: FuncName,
            inputs: anytype,
            output_defs: anytype,
            comptime OUTPUT_STRUCT: type,
            mutex_key: MutexKey,
            comptime SKIP_PROCESS: bool,
        ) OUTPUT_STRUCT {
            const INS = @TypeOf(inputs);
            const DEFS = @TypeOf(output_defs);
            ct_assert_with_reason(Types.type_is_struct(INS), @src(), "`inputs` must be a struct type", .{});
            ct_assert_with_reason(@typeInfo(INS).@"struct".field_names.len <= MAX_INPUTS, @src(), "the number of inputs ({d}) exceeds the maximum ({d})", .{ @typeInfo(INS).@"struct".field_names.len, MAX_INPUTS });
            ct_assert_with_reason(Types.type_is_struct(DEFS), @src(), "`output_defs` must be a struct type", .{});
            ct_assert_with_reason(Types.type_is_struct(OUTPUT_STRUCT), @src(), "`OUTPUT_STRUCT` must be a struct type", .{});
            ct_assert_with_reason(Types.two_structs_have_exact_same_field_names_and_order(DEFS, OUTPUT_STRUCT), @src(), "`OUTPUT_STRUCT` and `output_defs` must have the same field names in the same order", .{});

            var input_refs: [@typeInfo(INS).@"struct".field_names.len]ParamRef = undefined;
            inline for (@typeInfo(INS).@"struct".field_names, @typeInfo(INS).@"struct".field_types, 0..) |field_name, field_type, i| {
                ct_assert_with_reason(@hasDecl(field_type, "TYPE"), @src(), "field `{s}` on the input struct has no `TYPE` declaration (expected ParamReadOnly/ParamReadWrite/ParamUpdateInput)", .{field_name});
                const value = @field(inputs, field_name);
                input_refs[i] = ParamRef.from_opaque_read_only(value.to_opaque_read_only());
            }

            var defs_flat: [@typeInfo(DEFS).@"struct".field_names.len]ParamReadOnlyDef = undefined;
            inline for (@typeInfo(DEFS).@"struct".field_names, @typeInfo(DEFS).@"struct".field_types, 0..) |field_name, field_type, i| {
                ct_assert_with_reason(field_type == ParamReadOnlyDef, @src(), "field `{s}` on the output def struct is not a `ParamReadOnlyDef`", .{field_name});
                defs_flat[i] = @field(output_defs, field_name);
            }

            var output_refs: [@typeInfo(OUTPUT_STRUCT).@"struct".field_names.len]ParamRef = undefined;
            create_derived_set_internal(func_name, input_refs[0..], defs_flat[0..], output_refs[0..], null, 0, mutex_key, SKIP_PROCESS);

            var out_struct: OUTPUT_STRUCT = undefined;
            inline for (@typeInfo(OUTPUT_STRUCT).@"struct".field_names, @typeInfo(OUTPUT_STRUCT).@"struct".field_types, 0..) |field_name, field_type, i| {
                ct_assert_with_reason(@hasDecl(field_type, "TYPE"), @src(), "field `{s}` on the output struct has no `TYPE` declaration (expected ParamReadOnly(T))", .{field_name});
                const T = @field(field_type, "TYPE");
                @field(out_struct, field_name) = output_refs[i].to_read_only(T);
            }
            return out_struct;
        }

        fn create_consecutive_internal(comptime category: CategoryName, defs: []const ParamDefConsecutive(type_for_category(category)), outputs: []Param(type_for_category(category)), mutex_key: MutexKey) void {
            var mk: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            const cat: CategoryId = @intCast(@backingInt(category));
            const T = CategoryType(category);

            const count: IndexType = build: {
                var c: usize = 0;
                for (defs) |def| {
                    switch (def) {
                        .ROOT => c += 1,
                        .DERIVED_SINGLE => c += 1,
                        .DERIVED_GROUP => |group| c += group.output_defs.len,
                    }
                }
                break :build @intCast(c);
            };
            assert_with_reason(count == outputs.len, @src(), "the total number of parameter outputs ({d}) must equal `outputs.len` ({d})", .{ count, outputs.len });
            if (count == 0) return;
            const first_key = claim_pool_key_consecutive(cat, count);

            var param_offset: usize = 0;
            var out_idx: usize = 0;
            for (defs) |def| {
                switch (def) {
                    .ROOT => |root_def| {
                        const key = PoolKey{ .idx = first_key.idx + @as(IndexType, @intCast(param_offset)), .gen = first_key.gen };
                        const ref = create_root_with_key(cat, key, root_def.initial_value, .{
                            .update_mode = root_def.update_mode,
                            .get_deleted_mode = root_def.get_deleted_mode,
                            .set_deleted_mode = root_def.set_deleted_mode,
                        }, mk, true);
                        outputs[out_idx] = Param(T).root(ref.to_read_write(T));
                        param_offset += 1;
                        out_idx += 1;
                    },
                    .DERIVED_SINGLE => |d| {
                        const defs_arr: [1]ParamReadOnlyDef = .{.{
                            .category = category,
                            .update_mode = d.output_def.update_mode,
                            .parent_delete_mode = d.output_def.parent_delete_mode,
                            .get_deleted_mode = d.output_def.get_deleted_mode,
                            .set_deleted_mode = d.output_def.set_deleted_mode,
                        }};
                        var out_refs: [1]ParamRef = undefined;
                        var in_refs: [MAX_INPUTS]ParamRef = undefined;
                        assert_with_reason(d.inputs.len <= MAX_INPUTS, @src(), "the number of inputs ({d}) exceeds the maximum ({d})", .{ d.inputs.len, MAX_INPUTS });
                        for (d.inputs, 0..) |in, i| in_refs[i] = ParamRef.from_opaque_read_only(in);
                        create_derived_set_internal(d.update_function, in_refs[0..d.inputs.len], defs_arr[0..1], out_refs[0..1], first_key, param_offset, mk, true);
                        outputs[out_idx] = Param(T).derived(out_refs[0].to_read_only(T));
                        param_offset += 1;
                        out_idx += 1;
                    },
                    .DERIVED_GROUP => |d| {
                        assert_with_reason(d.output_defs.len <= MAX_OUTPUTS, @src(), "group output count {d} exceeds maximum {d}", .{ d.output_defs.len, MAX_OUTPUTS });
                        var defs_arr: [MAX_OUTPUTS]ParamReadOnlyDef = undefined;
                        var out_refs: [MAX_OUTPUTS]ParamRef = undefined;
                        var in_refs: [MAX_INPUTS]ParamRef = undefined;
                        assert_with_reason(d.inputs.len <= MAX_INPUTS, @src(), "the number of inputs ({d}) exceeds the maximum ({d})", .{ d.inputs.len, MAX_INPUTS });
                        for (d.inputs, 0..) |in, i| in_refs[i] = ParamRef.from_opaque_read_only(in);
                        for (d.output_defs, 0..) |out_def, i| {
                            defs_arr[i] = .{
                                .category = category,
                                .update_mode = out_def.update_mode,
                                .parent_delete_mode = out_def.parent_delete_mode,
                                .get_deleted_mode = out_def.get_deleted_mode,
                                .set_deleted_mode = out_def.set_deleted_mode,
                            };
                        }
                        create_derived_set_internal(d.update_function, in_refs[0..d.inputs.len], defs_arr[0..d.output_defs.len], out_refs[0..d.output_defs.len], first_key, param_offset, mk, true);
                        for (out_refs[0..d.output_defs.len]) |ref| {
                            outputs[out_idx] = Param(T).derived(ref.to_read_only(T));
                            out_idx += 1;
                        }
                        param_offset += d.output_defs.len;
                    },
                }
            }
            process_all_updates_if_needed(mk);
        }

        fn initialize_function_internal(comptime func_name: FuncName, func: *const UpdateFunction, mutex_key: MutexKey) void {
            var mk: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            const idx: usize = @intCast(@backingInt(func_name));
            assert_with_reason(!funcs_init[idx], @src(), "function `{s}` was already initialized. Use `replace_update_function` to replace it", .{@tagName(func_name)});
            funcs_init[idx] = true;
            funcs[idx] = func;
        }

        fn delete_function_internal(comptime func_name: FuncName, mutex_key: MutexKey) void {
            comptime assert_with_reason(SETTINGS.ALLOW_FUNCTION_DELETION, @src(), "cannot call this function if `ALLOW_FUNCTION_DELETION` is false", .{});
            var mk: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            const idx: usize = @intCast(@backingInt(func_name));
            assert_with_reason(funcs_init[idx], @src(), "function `{s}` was not initialized", .{@tagName(func_name)});
            const list = &func_packages[idx];
            var li: u32 = 0;
            while (li < list.get_len()) : (li += 1) {
                const pkg = list.get_ptr(li).*;
                if (!pkg.alive) continue;
                const block = pkg.payload;
                const in_count: usize = @intCast(pkg.in_count);
                for (0..pkg.out_count) |i| {
                    const out_ref = block.refs[in_count + i];
                    if (!key_is_valid(out_ref.category, .{ .idx = out_ref.index, .gen = out_ref.generation })) continue;
                    const out_meta = get_meta_at(out_ref.category, out_ref.index);
                    if (SETTINGS.DELETE_DEPENDANT_PARAMETERS_WHEN_FUNCTION_DELETED) {
                        switch (out_meta.parent_delete_behavior) {
                            .DELETE_WHEN_PARENT_IS_DELETED => delete_queue.append_one(out_ref, system_allocator),
                            .SET_DEFAULT_VALUE_WHEN_PARENT_IS_DELETED => set_default_locked(out_ref, mk, true),
                            .RETAIN_LAST_VALUE_WHEN_PARENT_DELETED => {},
                            .TRIGGER_UPDATE_WHEN_PARENT_DELETED => {},
                        }
                    }
                }
                destroy_package(pkg);
            }
            list.clear();
            funcs_init[idx] = false;
            funcs[idx] = Utils.invalid_ptr_const(UpdateFunction);
            process_all_deletes_if_needed(mk, false);
        }

        fn replace_function_internal(comptime func_name: FuncName, new_func: *const UpdateFunction, mutex_key: MutexKey) void {
            comptime assert_with_reason(SETTINGS.ALLOW_FUNCTION_REPLACEMENT, @src(), "cannot call this function if `ALLOW_FUNCTION_REPLACEMENT` is false", .{});
            var mk: MutexKey, const owns = mutex_key.lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            const idx: usize = @intCast(@backingInt(func_name));
            assert_with_reason(funcs_init[idx], @src(), "function `{s}` was not initialized", .{@tagName(func_name)});
            funcs[idx] = new_func;
            const list = &func_packages[idx];
            var li: u32 = 0;
            while (li < list.get_len()) : (li += 1) queue_package(list.get_ptr(li).*);
            process_all_updates_if_needed(mk);
        }

        /// Optional per-category initial capacity hint for `init`.
        pub const CategoryCapacity = struct {
            category: CategoryName,
            capacity: usize,
        };

        /// Initialize the system.  `io` is accepted for parity with the pool
        /// types; the state system uses its own `KeyedMutex` for synchronization.
        /// `category_capacities` may be null; omitted categories start at zero
        /// capacity and grow on demand.
        pub fn init(allocator: Allocator, io: Io, category_capacities: ?[]const CategoryCapacity) void {
            var mk: MutexKey, const owns = (MutexKey{}).lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            assert_with_reason(!initialized, @src(), "`init` was called twice without `deinit`", .{});
            _ = io;

            var caps: [NUM_CATEGORIES]usize = @splat(0);
            if (category_capacities) |list| {
                var seen: [NUM_CATEGORIES]bool = @splat(false);
                for (list) |cc| {
                    const cat: usize = @intCast(@backingInt(cc.category));
                    assert_with_reason(!seen[cat], @src(), "category `{s}` was provided more than once", .{@tagName(cc.category)});
                    seen[cat] = true;
                    caps[cat] = cc.capacity;
                }
            }

            inline for (0..NUM_CATEGORIES) |c| {
                const P = CATEGORY_POOLS[c];
                P.init(@intCast(caps[c]), allocator, {});
                metas[c] = MetaList.allocate_new(@intCast(caps[c]), allocator);
            }

            system_allocator = allocator;
            payload_pool.init(0, allocator, {});
            package_pool.init(0, allocator, {});
            dep_pool.init(0, allocator, {});
            update_queue = QueueList.allocate_new(0, allocator);
            delete_queue = DeleteList.allocate_new(0, allocator);
            for (0..NUM_FUNCTIONS) |f| {
                func_packages[f] = FuncList.allocate_new(0, allocator);
                func_packages_init[f] = true;
            }

            for (0..NUM_USER_CATEGORIES) |cat| {
                meta_values[cat] = 0;
                meta_first_deps[cat] = null;
                meta_last_deps[cat] = null;
                meta_metas[cat] = .{
                    .update_mode = if (SETTINGS.INCLUDE_META_CATEGORY == .META_CATEGORY_LENGTH_AND_VALUE_CHANGE)
                        .ALWAYS_TRIGGER_UPDATES_EVEN_IF_VALUE_UNCHANGED
                    else
                        .ONLY_TRIGGER_UPDATES_ON_VALUE_CHANGE,
                    .parent_delete_behavior = .RETAIN_LAST_VALUE_WHEN_PARENT_DELETED,
                };
            }
            category_counts = @splat(0);
            current_epoch = 0;
            cascade_active = false;
            updates_in_progress = false;
            deletes_in_progress = false;
            update_queue_cursor = 0;
            initialized = true;
        }

        pub fn deinit() void {
            var mk: MutexKey, const owns = (MutexKey{}).lock_if_needed(&access_lock);
            defer mk.unlock_if_needed(owns);
            if (!initialized) return;

            inline for (0..NUM_CATEGORIES) |c| {
                const P = CATEGORY_POOLS[c];
                P.uninit();
                metas[c].free_if_non_zero(system_allocator);
            }
            payload_pool.uninit(system_allocator);
            package_pool.uninit(system_allocator);
            dep_pool.uninit(system_allocator);

            update_queue.free_if_non_zero(system_allocator);
            delete_queue.free_if_non_zero(system_allocator);
            for (0..NUM_FUNCTIONS) |f| {
                func_packages[f].free_if_non_zero(system_allocator);
                func_packages_init[f] = false;
            }

            funcs_init = @splat(false);
            funcs = @splat(Utils.invalid_ptr_const(UpdateFunction));
            category_counts = @splat(0);
            system_allocator = DummyAllocator.allocator_panic_free_noop;
            initialized = false;
        }

        // ---- public types ---------------------------------------------------
        pub const CategoryName = PARAM_CATEGORIES;
        pub const FuncName = FUNCTION_NAMES;
        pub const Index = IndexType;
        pub const Gen = GenId;
        pub const UpdateFunction = fn (iface: UpdateInterface) void;

        pub fn CategoryType(comptime name: CategoryName) type {
            return CATEGORY_DEFS[@backingInt(name)].param_type;
        }
        pub fn type_for_category(comptime category: CategoryName) type {
            return CategoryType(category);
        }

        pub const ParamReadWriteOpaque = packed struct {
            category: CategoryId,
            index: IndexType,
            generation: GenId,

            fn delete(self: ParamReadWriteOpaque) void {
                delete_param_internal(.{ .category = self.category, .index = self.index, .generation = self.generation }, .{}, false, false);
            }
            fn with_type(self: ParamReadWriteOpaque, comptime T: type) ParamReadWrite(T) {
                assert_with_reason(CATEGORY_TYPE_IDS[self.category] == id_for_type(T), @src(), "invalid category for converting to param with type `{s}`", .{@typeName(T)});
                return .{ .category = self.category, .index = self.index, .generation = self.generation };
            }
            fn as_update_output(self: ParamReadWriteOpaque, key: MutexKey, comptime T: type) ParamUpdateOutput(T) {
                return self.with_type(T).as_update_output(key);
            }
        };

        pub const ParamReadOnlyOpaque = packed struct {
            category: CategoryId,
            index: IndexType,
            generation: GenId,

            fn delete(self: ParamReadOnlyOpaque) void {
                delete_param_internal(.{ .category = self.category, .index = self.index, .generation = self.generation }, .{}, false, false);
            }
            fn with_type(self: ParamReadOnlyOpaque, comptime T: type) ParamReadOnly(T) {
                assert_with_reason(CATEGORY_TYPE_IDS[self.category] == id_for_type(T), @src(), "invalid category for converting to param with type `{s}`", .{@typeName(T)});
                return .{ .category = self.category, .index = self.index, .generation = self.generation };
            }
            fn as_update_input(self: ParamReadOnlyOpaque, key: MutexKey, comptime T: type) ParamUpdateInput(T) {
                return self.with_type(T).as_update_input(key);
            }
            fn as_update_output(self: ParamReadOnlyOpaque, key: MutexKey, comptime T: type) ParamUpdateOutput(T) {
                return ParamUpdateOutput(T){
                    .param = self.with_type(T),
                    .key = key,
                };
            }
        };

        pub fn ParamReadWrite(comptime T: type) type {
            return packed struct {
                pub const TYPE = T;
                const THIS_TYPE_ID: CategoryId = id_for_type(T);
                const ParamSelf = @This();

                category: CategoryId,
                index: IndexType,
                generation: GenId,

                fn to_opaque_read_only(self: ParamSelf) ParamReadOnlyOpaque {
                    return .{ .category = self.category, .index = self.index, .generation = self.generation };
                }
                fn to_opaque(self: ParamSelf) ParamReadWriteOpaque {
                    return .{ .category = self.category, .index = self.index, .generation = self.generation };
                }
                fn to_opaque_read_write(self: ParamSelf) ParamReadWriteOpaque {
                    return self.to_opaque();
                }
                pub fn to_read_only(self: ParamSelf) ParamReadOnly(T) {
                    return .{ .category = self.category, .index = self.index, .generation = self.generation };
                }
                fn to_read_write(self: ParamSelf) ParamSelf {
                    return self;
                }
                fn as_update_input(self: ParamSelf, key: MutexKey) ParamUpdateInput(T) {
                    return .{ .param = self.to_read_only(), .key = key };
                }
                fn as_update_output(self: ParamSelf, key: MutexKey) ParamUpdateOutput(T) {
                    return .{ .param = self.to_read_only(), .key = key };
                }
                pub fn delete(self: ParamSelf) void {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    delete_param_internal(.{ .category = self.category, .index = self.index, .generation = self.generation }, .{}, false, false);
                }
                pub fn set(self: ParamSelf, val: T) void {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    set_typed_locked(T, .{ .category = self.category, .index = self.index, .generation = self.generation }, val, .{}, false);
                }
                pub fn set_and_get_old(self: ParamSelf, val: T) T {
                    const old = self.get();
                    self.set(val);
                    return old;
                }
                pub fn get(self: ParamSelf) T {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    return get_typed_locked(T, .{ .category = self.category, .index = self.index, .generation = self.generation }, .{}, false);
                }
            };
        }

        pub fn ParamReadOnly(comptime T: type) type {
            return packed struct {
                pub const TYPE = T;
                const THIS_TYPE_ID: CategoryId = id_for_type(T);
                const ParamSelf = @This();

                category: CategoryId,
                index: IndexType,
                generation: GenId,

                fn to_opaque_read_only(self: ParamSelf) ParamReadOnlyOpaque {
                    return .{ .category = self.category, .index = self.index, .generation = self.generation };
                }
                fn to_opaque(self: ParamSelf) ParamReadOnlyOpaque {
                    return self.to_opaque_read_only();
                }
                pub fn to_read_only(self: ParamSelf) ParamSelf {
                    return self;
                }
                fn to_read_write(self: ParamSelf) ParamReadWrite(T) {
                    return .{ .category = self.category, .index = self.index, .generation = self.generation };
                }
                fn as_update_input(self: ParamSelf, key: MutexKey) ParamUpdateInput(T) {
                    return .{ .param = self, .key = key };
                }
                pub fn delete(self: ParamSelf) void {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    delete_param_internal(.{ .category = self.category, .index = self.index, .generation = self.generation }, .{}, false, false);
                }
                pub fn get(self: ParamSelf) T {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    return get_typed_locked(T, .{ .category = self.category, .index = self.index, .generation = self.generation }, .{}, false);
                }
            };
        }

        pub fn ParamUpdateInput(comptime T: type) type {
            return struct {
                pub const TYPE = T;
                const THIS_TYPE_ID: CategoryId = id_for_type(T);
                const ParamSelf = @This();

                param: ParamReadOnly(T),
                key: MutexKey,

                pub fn delete(self: ParamSelf) void {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    delete_param_internal(.{ .category = self.param.category, .index = self.param.index, .generation = self.param.generation }, self.key, false, true);
                }
                pub fn get(self: ParamSelf) T {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    return get_typed_locked(T, .{ .category = self.param.category, .index = self.param.index, .generation = self.param.generation }, self.key, false);
                }
                fn to_opaque_read_only(self: ParamSelf) ParamReadOnlyOpaque {
                    return self.param.to_opaque_read_only();
                }
                fn to_opaque(self: ParamSelf) ParamReadOnlyOpaque {
                    return self.to_opaque_read_only();
                }
                fn to_read_only(self: ParamSelf) ParamReadOnly(T) {
                    return self.param;
                }
            };
        }

        pub fn ParamUpdateOutput(comptime T: type) type {
            return struct {
                pub const TYPE = T;
                const THIS_TYPE_ID: CategoryId = id_for_type(T);
                const ParamSelf = @This();

                param: ParamReadOnly(T),
                key: MutexKey,

                pub fn delete(self: ParamSelf) void {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    delete_param_internal(.{ .category = self.param.category, .index = self.param.index, .generation = self.param.generation }, self.key, false, true);
                }
                pub fn set(self: ParamSelf, val: T) void {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    set_typed_locked(T, .{ .category = self.param.category, .index = self.param.index, .generation = self.param.generation }, val, self.key, true);
                }
                pub fn set_and_get_old(self: ParamSelf, val: T) T {
                    const old = self.get();
                    self.set(val);
                    return old;
                }
                pub fn get(self: ParamSelf) T {
                    assert_with_reason(CATEGORY_TYPE_IDS[self.param.category] == THIS_TYPE_ID, @src(), "category type does not match the parameter type", .{});
                    return get_typed_locked(T, .{ .category = self.param.category, .index = self.param.index, .generation = self.param.generation }, self.key, false);
                }
                fn to_opaque_read_only(self: ParamSelf) ParamReadOnlyOpaque {
                    return self.param.to_opaque_read_only();
                }
            };
        }

        pub const ParamReadWriteSettings = struct {
            update_mode: UpdateMode = .ONLY_TRIGGER_UPDATES_ON_VALUE_CHANGE,
            get_deleted_mode: GetDeletedParamMode = .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED,
            set_deleted_mode: SetDeletedParamMode = .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED,

            pub fn default() ParamReadWriteSettings {
                return .{};
            }
            pub fn no_access_when_deleted(self: ParamReadWriteSettings) ParamReadWriteSettings {
                var def = self;
                def.get_deleted_mode = .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED;
                def.set_deleted_mode = .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED;
                return def;
            }
            pub fn default_value_when_deleted(self: ParamReadWriteSettings) ParamReadWriteSettings {
                var def = self;
                def.get_deleted_mode = .RETURN_DEFAULT_VALUE_WHEN_GET_DELETED;
                def.set_deleted_mode = .IGNORE_SETTING_PARAM_WHEN_DELETED;
                return def;
            }
            pub fn allow_access_when_deleted_but_warn(self: ParamReadWriteSettings) ParamReadWriteSettings {
                var def = self;
                def.get_deleted_mode = .RETURN_DEFAULT_VALUE_WHEN_GET_DELETED_AND_WARN;
                def.set_deleted_mode = .IGNORE_SETTING_PARAM_WHEN_DELETED_AND_WARN;
                return def;
            }
            pub fn with_update_mode(self: ParamReadWriteSettings, update_mode: UpdateMode) ParamReadWriteSettings {
                var def = self;
                def.update_mode = update_mode;
                return def;
            }
        };

        pub const ParamReadOnlyDef = struct {
            category: CategoryName,
            update_mode: UpdateMode = .ONLY_TRIGGER_UPDATES_ON_VALUE_CHANGE,
            parent_delete_mode: ParentDeleteMode = .TRIGGER_UPDATE_WHEN_PARENT_DELETED,
            get_deleted_mode: GetDeletedParamMode = .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED,
            set_deleted_mode: SetDeletedParamMode = .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED,

            pub fn new_def(category: CategoryName) ParamReadOnlyDef {
                return .{ .category = category };
            }
            pub fn with_parent_delete_mode(self: ParamReadOnlyDef, parent_delete_mode: ParentDeleteMode) ParamReadOnlyDef {
                var def = self;
                def.parent_delete_mode = parent_delete_mode;
                return def;
            }
            pub fn no_access_when_deleted(self: ParamReadOnlyDef) ParamReadOnlyDef {
                var def = self;
                def.get_deleted_mode = .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED;
                def.set_deleted_mode = .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED;
                return def;
            }
            pub fn default_value_when_deleted(self: ParamReadOnlyDef) ParamReadOnlyDef {
                var def = self;
                def.get_deleted_mode = .RETURN_DEFAULT_VALUE_WHEN_GET_DELETED;
                def.set_deleted_mode = .IGNORE_SETTING_PARAM_WHEN_DELETED;
                return def;
            }
            pub fn default_value_when_deleted_but_warn(self: ParamReadOnlyDef) ParamReadOnlyDef {
                var def = self;
                def.get_deleted_mode = .RETURN_DEFAULT_VALUE_WHEN_GET_DELETED_AND_WARN;
                def.set_deleted_mode = .IGNORE_SETTING_PARAM_WHEN_DELETED_AND_WARN;
                return def;
            }
            pub fn with_update_mode(self: ParamReadOnlyDef, update_mode: UpdateMode) ParamReadOnlyDef {
                var def = self;
                def.update_mode = update_mode;
                return def;
            }
        };

        pub fn ParamReadWriteDefConsecutive(comptime T: type) type {
            return struct {
                initial_value: T,
                update_mode: UpdateMode = .ONLY_TRIGGER_UPDATES_ON_VALUE_CHANGE,
                get_deleted_mode: GetDeletedParamMode = .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED,
                set_deleted_mode: SetDeletedParamMode = .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED,

                pub fn new_def(initial_value: T) @This() {
                    return .{ .initial_value = initial_value };
                }
                pub fn no_access_when_deleted(self: @This()) @This() {
                    var def = self;
                    def.get_deleted_mode = .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED;
                    def.set_deleted_mode = .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED;
                    return def;
                }
                pub fn allow_access_when_deleted(self: @This()) @This() {
                    var def = self;
                    def.get_deleted_mode = .RETURN_DEFAULT_VALUE_WHEN_GET_DELETED;
                    def.set_deleted_mode = .IGNORE_SETTING_PARAM_WHEN_DELETED;
                    return def;
                }
                pub fn allow_access_when_deleted_but_warn(self: @This()) @This() {
                    var def = self;
                    def.get_deleted_mode = .RETURN_DEFAULT_VALUE_WHEN_GET_DELETED_AND_WARN;
                    def.set_deleted_mode = .IGNORE_SETTING_PARAM_WHEN_DELETED_AND_WARN;
                    return def;
                }
                pub fn with_update_mode(self: @This(), update_mode: UpdateMode) @This() {
                    var def = self;
                    def.update_mode = update_mode;
                    return def;
                }
            };
        }

        pub const ParamReadOnlyDefNoCategoryOrIndex = struct {
            update_mode: UpdateMode = .ONLY_TRIGGER_UPDATES_ON_VALUE_CHANGE,
            parent_delete_mode: ParentDeleteMode = .TRIGGER_UPDATE_WHEN_PARENT_DELETED,
            get_deleted_mode: GetDeletedParamMode = .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED,
            set_deleted_mode: SetDeletedParamMode = .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED,

            pub fn new_def() ParamReadOnlyDefNoCategoryOrIndex {
                return .{};
            }
            pub fn with_parent_delete_mode(self: ParamReadOnlyDefNoCategoryOrIndex, parent_delete_mode: ParentDeleteMode) ParamReadOnlyDefNoCategoryOrIndex {
                var def = self;
                def.parent_delete_mode = parent_delete_mode;
                return def;
            }
            pub fn no_access_when_deleted(self: ParamReadOnlyDefNoCategoryOrIndex) ParamReadOnlyDefNoCategoryOrIndex {
                var def = self;
                def.get_deleted_mode = .CAN_NEVER_GET_THIS_PARAM_WHEN_DELETED;
                def.set_deleted_mode = .CAN_NEVER_SET_THIS_PARAM_WHEN_DELETED;
                return def;
            }
            pub fn allow_access_when_deleted(self: ParamReadOnlyDefNoCategoryOrIndex) ParamReadOnlyDefNoCategoryOrIndex {
                var def = self;
                def.get_deleted_mode = .RETURN_DEFAULT_VALUE_WHEN_GET_DELETED;
                def.set_deleted_mode = .IGNORE_SETTING_PARAM_WHEN_DELETED;
                return def;
            }
            pub fn allow_access_when_deleted_but_warn(self: ParamReadOnlyDefNoCategoryOrIndex) ParamReadOnlyDefNoCategoryOrIndex {
                var def = self;
                def.get_deleted_mode = .RETURN_DEFAULT_VALUE_WHEN_GET_DELETED_AND_WARN;
                def.set_deleted_mode = .IGNORE_SETTING_PARAM_WHEN_DELETED_AND_WARN;
                return def;
            }
            pub fn with_update_mode(self: ParamReadOnlyDefNoCategoryOrIndex, update_mode: UpdateMode) ParamReadOnlyDefNoCategoryOrIndex {
                var def = self;
                def.update_mode = update_mode;
                return def;
            }
        };

        pub const ParamReadOnlyDefConsecutiveSingle = struct {
            update_function: FuncName,
            inputs: []const ParamReadOnlyOpaque,
            output_def: ParamReadOnlyDefNoCategoryOrIndex,
        };
        pub const ParamReadOnlyDefConsecutiveGroup = struct {
            update_function: FuncName,
            inputs: []const ParamReadOnlyOpaque,
            output_defs: []const ParamReadOnlyDefNoCategoryOrIndex,
        };

        pub fn ParamDefConsecutive(comptime T: type) type {
            return union(ParamDefKindWithGroup) {
                ROOT: ParamReadWriteDefConsecutive(T),
                DERIVED_SINGLE: ParamReadOnlyDefConsecutiveSingle,
                DERIVED_GROUP: ParamReadOnlyDefConsecutiveGroup,

                pub fn root(def: ParamReadWriteDefConsecutive(T)) ParamDefConsecutive(T) {
                    return .{ .ROOT = def };
                }
                pub fn derived_single(def: ParamReadOnlyDefConsecutiveSingle) ParamDefConsecutive(T) {
                    return .{ .DERIVED_SINGLE = def };
                }
                pub fn derived_group(def: ParamReadOnlyDefConsecutiveGroup) ParamDefConsecutive(T) {
                    return .{ .DERIVED_GROUP = def };
                }
            };
        }

        pub const ParamOpaque = union(ParamDefKind) {
            ROOT: ParamReadWriteOpaque,
            DERIVED: ParamReadOnlyOpaque,

            pub fn root(param: ParamReadWriteOpaque) ParamOpaque {
                return .{ .ROOT = param };
            }
            pub fn derived(param: ParamReadOnlyOpaque) ParamOpaque {
                return .{ .DERIVED = param };
            }
        };

        pub fn Param(comptime T: type) type {
            return union(ParamDefKind) {
                ROOT: ParamReadWrite(T),
                DERIVED: ParamReadOnly(T),

                pub fn root(param: ParamReadWrite(T)) @This() {
                    return .{ .ROOT = param };
                }
                pub fn derived(param: ParamReadOnly(T)) @This() {
                    return .{ .DERIVED = param };
                }
            };
        }

        // ---- public API -----------------------------------------------------
        pub fn initialize_update_function(comptime func_name: FuncName, func: *const UpdateFunction) void {
            assert_initialized();
            initialize_function_internal(func_name, func, .{});
        }
        pub fn initialize_update_function_during_update(comptime func_name: FuncName, func: *const UpdateFunction, mutex_key: MutexKey) void {
            assert_initialized();
            initialize_function_internal(func_name, func, mutex_key);
        }
        pub fn delete_update_function(comptime func_name: FuncName) void {
            assert_initialized();
            delete_function_internal(func_name, .{});
        }
        pub fn delete_update_function_during_update(comptime func_name: FuncName, mutex_key: MutexKey) void {
            assert_initialized();
            delete_function_internal(func_name, mutex_key);
        }
        pub fn replace_update_function(comptime func_name: FuncName, new_func: *const UpdateFunction) void {
            assert_initialized();
            replace_function_internal(func_name, new_func, .{});
        }
        pub fn replace_update_function_during_update(comptime func_name: FuncName, new_func: *const UpdateFunction, mutex_key: MutexKey) void {
            assert_initialized();
            replace_function_internal(func_name, new_func, mutex_key);
        }

        pub fn CategoryIterator(comptime T: type, comptime cat: usize) type {
            const P = CATEGORY_POOLS[cat];
            return struct {
                inner: P.Iterator,
                pub fn next(self: *@This()) ?ParamReadOnly(T) {
                    const key = self.inner.next() orelse return null;
                    return .{ .category = @intCast(cat), .index = @intCast(key.idx), .generation = @intCast(key.gen) };
                }
            };
        }

        /// Iterate only the live values of one category.  Each category owns its
        /// pool, so this is a direct pool walk with no side-table filtering.
        pub fn iterator(comptime category: CategoryName) CategoryIterator(CategoryType(category), @backingInt(category)) {
            assert_initialized();
            const cat = @backingInt(category);
            return .{ .inner = CATEGORY_POOLS[cat].iterator() };
        }

        pub fn create_new_root_param(comptime category: CategoryName, initial_val: CategoryType(category), settings: ParamReadWriteSettings) ParamReadWrite(CategoryType(category)) {
            assert_initialized();
            const ref = create_root_internal(category, initial_val, settings, .{});
            return ref.to_read_write(CategoryType(category));
        }

        pub fn create_new_derived_param_from_input_struct(update_function: FuncName, inputs: anytype, output_def: ParamReadOnlyDef, comptime OUTPUT_TYPE: type) ParamReadOnly(OUTPUT_TYPE) {
            assert_initialized();
            const DefsStruct = struct { param: ParamReadOnlyDef };
            const OutStruct = struct { param: ParamReadOnly(OUTPUT_TYPE) };
            const out = create_derived_set_from_struct(update_function, inputs, DefsStruct{ .param = output_def }, OutStruct, .{}, false);
            return out.param;
        }

        pub fn create_new_derived_param_set_from_struct(update_function: FuncName, inputs: anytype, output_defs: anytype, comptime OUTPUT_STRUCT: type) OUTPUT_STRUCT {
            assert_initialized();
            return create_derived_set_from_struct(update_function, inputs, output_defs, OUTPUT_STRUCT, .{}, false);
        }

        pub fn create_new_derived_param_set(update_function: FuncName, inputs: []const ParamReadOnlyOpaque, output_defs: []const ParamReadOnlyDef, outputs: []ParamReadOnlyOpaque) void {
            assert_initialized();
            assert_with_reason(inputs.len <= MAX_INPUTS, @src(), "the number of inputs ({d}) exceeds the maximum ({d})", .{ inputs.len, MAX_INPUTS });
            assert_with_reason(outputs.len <= MAX_OUTPUTS and output_defs.len == outputs.len, @src(), "the number of outputs ({d}) must match `output_defs.len` ({d}) and be at most {d}", .{ outputs.len, output_defs.len, MAX_OUTPUTS });
            var in_refs: [MAX_INPUTS]ParamRef = undefined;
            for (inputs, 0..) |in, i| in_refs[i] = ParamRef.from_opaque_read_only(in);
            var out_refs: [MAX_OUTPUTS]ParamRef = undefined;
            create_derived_set_internal(update_function, in_refs[0..inputs.len], output_defs, out_refs[0..outputs.len], null, 0, .{}, false);
            for (out_refs[0..outputs.len], outputs) |ref, *out| out.* = ref.to_opaque_read_only();
        }

        pub fn create_new_derived_param(update_function: FuncName, inputs: []const ParamReadOnlyOpaque, output_def: ParamReadOnlyDef, comptime OUTPUT_TYPE: type) ParamReadOnly(OUTPUT_TYPE) {
            assert_initialized();
            assert_with_reason(inputs.len <= MAX_INPUTS, @src(), "the number of inputs ({d}) exceeds the maximum ({d})", .{ inputs.len, MAX_INPUTS });
            var in_refs: [MAX_INPUTS]ParamRef = undefined;
            for (inputs, 0..) |in, i| in_refs[i] = ParamRef.from_opaque_read_only(in);
            const defs: [1]ParamReadOnlyDef = .{output_def};
            var out_refs: [1]ParamRef = undefined;
            create_derived_set_internal(update_function, in_refs[0..inputs.len], defs[0..1], out_refs[0..1], null, 0, .{}, false);
            return out_refs[0].to_read_only(OUTPUT_TYPE);
        }

        pub fn create_consecutive_indexed_params(comptime category: CategoryName, defs: []const ParamDefConsecutive(type_for_category(category)), outputs: []Param(type_for_category(category))) void {
            assert_initialized();
            create_consecutive_internal(category, defs, outputs, .{});
        }

        pub fn get_meta_param(comptime category: CategoryName) ParamReadOnly(IndexType) {
            comptime assert_with_reason(INCLUDE_META, @src(), "meta category is not enabled", .{});
            return .{
                .category = @intCast(META_CAT_IDX),
                .index = @intCast(@backingInt(category)),
                .generation = 0,
            };
        }

        pub fn get_param_in_category(comptime category: CategoryName, index: IndexType) CategoryType(category) {
            assert_initialized();
            const cat: CategoryId = @intCast(@backingInt(category));
            const meta = get_meta_at(cat, index);
            return get_typed_locked(CategoryType(category), .{ .category = cat, .index = index, .generation = meta.generation }, .{}, true);
        }
        pub fn get_param_in_category_during_update(comptime category: CategoryName, index: IndexType, mutex_key: MutexKey) CategoryType(category) {
            assert_initialized();
            const cat: CategoryId = @intCast(@backingInt(category));
            const meta = get_meta_at(cat, index);
            return get_typed_locked(CategoryType(category), .{ .category = cat, .index = index, .generation = meta.generation }, mutex_key, true);
        }
        pub fn set_param_in_category(comptime category: CategoryName, index: IndexType, val: CategoryType(category)) void {
            assert_initialized();
            const cat: CategoryId = @intCast(@backingInt(category));
            const meta = get_meta_at(cat, index);
            set_typed_locked(CategoryType(category), .{ .category = cat, .index = index, .generation = meta.generation }, val, .{}, false);
        }
        pub fn set_param_in_category_during_update(comptime category: CategoryName, index: IndexType, val: CategoryType(category), mutex_key: MutexKey) void {
            assert_initialized();
            const cat: CategoryId = @intCast(@backingInt(category));
            const meta = get_meta_at(cat, index);
            set_typed_locked(CategoryType(category), .{ .category = cat, .index = index, .generation = meta.generation }, val, mutex_key, true);
        }
        pub fn set_param_get_old_in_category(comptime category: CategoryName, index: IndexType, val: CategoryType(category)) CategoryType(category) {
            const old = get_param_in_category(category, index);
            set_param_in_category(category, index, val);
            return old;
        }
        pub fn set_param_get_old_in_category_during_update(comptime category: CategoryName, index: IndexType, val: CategoryType(category), mutex_key: MutexKey) CategoryType(category) {
            const old = get_param_in_category_during_update(category, index, mutex_key);
            set_param_in_category_during_update(category, index, val, mutex_key);
            return old;
        }
        pub fn delete_param_in_category(comptime category: CategoryName, index: IndexType) void {
            assert_initialized();
            const cat: CategoryId = @intCast(@backingInt(category));
            const meta = get_meta_at(cat, index);
            delete_param_internal(.{ .category = cat, .index = index, .generation = meta.generation }, .{}, true, false);
        }
        pub fn delete_param_in_category_during_update(comptime category: CategoryName, index: IndexType, mutex_key: MutexKey) void {
            assert_initialized();
            const cat: CategoryId = @intCast(@backingInt(category));
            const meta = get_meta_at(cat, index);
            delete_param_internal(.{ .category = cat, .index = index, .generation = meta.generation }, mutex_key, true, true);
        }

        pub fn make_read_only_param_struct(read_only_params_opaque: []const ParamReadOnlyOpaque, comptime STRUCT: type) STRUCT {
            ct_assert_with_reason(Types.type_is_struct(STRUCT), @src(), "type `STRUCT` must be a struct type", .{});
            ct_assert_with_reason(read_only_params_opaque.len == @typeInfo(STRUCT).@"struct".field_names.len, @src(), "field count mismatch", .{});
            var object: STRUCT = undefined;
            inline for (@typeInfo(STRUCT).@"struct".field_names, @typeInfo(STRUCT).@"struct".field_types, 0..) |field_name, field_type, f| {
                const T = @field(field_type, "TYPE");
                @field(object, field_name) = read_only_params_opaque[f].with_type(T);
            }
            return object;
        }
        pub fn make_read_write_param_struct(read_write_params_opaque: []const ParamReadWriteOpaque, comptime STRUCT: type) STRUCT {
            ct_assert_with_reason(Types.type_is_struct(STRUCT), @src(), "type `STRUCT` must be a struct type", .{});
            ct_assert_with_reason(read_write_params_opaque.len == @typeInfo(STRUCT).@"struct".field_names.len, @src(), "field count mismatch", .{});
            var object: STRUCT = undefined;
            inline for (@typeInfo(STRUCT).@"struct".field_names, @typeInfo(STRUCT).@"struct".field_types, 0..) |field_name, field_type, f| {
                const T = @field(field_type, "TYPE");
                @field(object, field_name) = read_write_params_opaque[f].with_type(T);
            }
            return object;
        }

        pub const UpdateInterface = struct {
            inputs: []const ParamRef,
            outputs: []const ParamRef,
            key: MutexKey,

            pub fn create_new_root_param_during_update(self: UpdateInterface, comptime category: CategoryName, initial_val: CategoryType(category), update_mode: UpdateMode) ParamReadWrite(CategoryType(category)) {
                const ref = create_root_internal(category, initial_val, .{ .update_mode = update_mode }, self.key);
                return ref.to_read_write(CategoryType(category));
            }
            pub fn create_new_derived_param_set_from_struct_during_update(self: UpdateInterface, update_function: FuncName, inputs: anytype, output_defs: anytype, comptime OUTPUT_STRUCT: type) OUTPUT_STRUCT {
                return create_derived_set_from_struct(update_function, inputs, output_defs, OUTPUT_STRUCT, self.key, false);
            }
            pub fn create_new_derived_param_set_during_update(self: UpdateInterface, update_function: FuncName, inputs: []const ParamReadOnlyOpaque, output_defs: []const ParamReadOnlyDef, outputs: []ParamReadOnlyOpaque) void {
                assert_with_reason(inputs.len <= MAX_INPUTS, @src(), "the number of inputs ({d}) exceeds the maximum ({d})", .{ inputs.len, MAX_INPUTS });
                assert_with_reason(outputs.len <= MAX_OUTPUTS and output_defs.len == outputs.len, @src(), "the number of outputs ({d}) must match `output_defs.len` ({d}) and be at most {d}", .{ outputs.len, output_defs.len, MAX_OUTPUTS });
                var in_refs: [MAX_INPUTS]ParamRef = undefined;
                for (inputs, 0..) |in, i| in_refs[i] = ParamRef.from_opaque_read_only(in);
                var out_refs: [MAX_OUTPUTS]ParamRef = undefined;
                create_derived_set_internal(update_function, in_refs[0..inputs.len], output_defs, out_refs[0..outputs.len], null, 0, self.key, false);
                for (out_refs[0..outputs.len], outputs) |ref, *out| out.* = ref.to_opaque_read_only();
            }
            pub fn create_new_derived_param_during_update(self: UpdateInterface, update_function: FuncName, inputs: anytype, output_def: ParamReadOnlyDef, comptime OUTPUT_TYPE: type) ParamReadOnly(OUTPUT_TYPE) {
                const DefsStruct = struct { param: ParamReadOnlyDef };
                const OutStruct = struct { param: ParamReadOnly(OUTPUT_TYPE) };
                const out = create_derived_set_from_struct(update_function, inputs, DefsStruct{ .param = output_def }, OutStruct, self.key, false);
                return out.param;
            }

            pub fn make_input_struct(self: UpdateInterface, comptime IN_STRUCT: type) IN_STRUCT {
                ct_assert_with_reason(Types.type_is_struct(IN_STRUCT), @src(), "type `IN_STRUCT` must be a struct type", .{});
                ct_assert_with_reason(self.inputs.len == @typeInfo(IN_STRUCT).@"struct".field_names.len, @src(), "field count mismatch", .{});
                var object: IN_STRUCT = undefined;
                inline for (@typeInfo(IN_STRUCT).@"struct".field_names, @typeInfo(IN_STRUCT).@"struct".field_types, 0..) |field_name, field_type, f| {
                    const T = @field(field_type, "TYPE");
                    @field(object, field_name) = self.inputs[f].as_update_input(self.key, T);
                }
                return object;
            }
            pub fn make_output_struct(self: UpdateInterface, comptime OUT_STRUCT: type) OUT_STRUCT {
                ct_assert_with_reason(Types.type_is_struct(OUT_STRUCT), @src(), "type `OUT_STRUCT` must be a struct type", .{});
                ct_assert_with_reason(self.outputs.len == @typeInfo(OUT_STRUCT).@"struct".field_names.len, @src(), "field count mismatch", .{});
                var object: OUT_STRUCT = undefined;
                inline for (@typeInfo(OUT_STRUCT).@"struct".field_names, @typeInfo(OUT_STRUCT).@"struct".field_types, 0..) |field_name, field_type, f| {
                    const T = @field(field_type, "TYPE");
                    @field(object, field_name) = self.outputs[f].as_update_output(self.key, T);
                }
                return object;
            }

            pub fn commit_deletions_and_changes(self: UpdateInterface) void {
                process_all_deletes_if_needed(self.key, false);
                process_all_updates_if_needed(self.key);
            }
        };
    };
}

test "ParametricStateSystem - main test" {
    const Test = Root.Testing;
    const do_debug = false;
    const settings = comptime Settings{
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
        .MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE = ._16,
        .MAX_NUM_UNIQUE_FUNCTION_PAYLOADS = ._65_536,
        .MAX_NUM_VALUES_IN_ANY_CATEGORY = ._65_536,
        .MAX_PAYLOAD_LIST_LIMIT = ._65_536,
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
    var threaded: std.Io.Threaded = .init(alloc, .{});
    defer threaded.deinit();
    PSS.init(alloc, threaded.io(), &.{
        PSS.CategoryCapacity{ .category = .POSITIONS, .capacity = 16 },
        PSS.CategoryCapacity{ .category = .SIZES, .capacity = 16 },
        PSS.CategoryCapacity{ .category = .AREAS, .capacity = 16 },
        PSS.CategoryCapacity{ .category = .SCALARS, .capacity = 16 },
    });
    defer PSS.deinit();
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
        fn vec_plus_vec_plus_margin_out_vec_0y_and_vec_xy(iface: CalcIface) void {
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
        fn vec_plus_vec_plus_margin_out_vec_x0(iface: CalcIface) void {
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
    PSS.initialize_update_function(.BOT_LEFT_AND_FAR_CORNER_PLUS_MARGIN, CALC.vec_plus_vec_plus_margin_out_vec_0y_and_vec_xy);
    PSS.initialize_update_function(.TOP_RIGHT_PLUS_MARGIN, CALC.vec_plus_vec_plus_margin_out_vec_x0);

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
    PSS.create_consecutive_indexed_params(.POSITIONS, &.{
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

    // The synthetic meta category tracks each category independently, even though
    // POSITIONS and SIZES have separate pools even though both are Vec2(f32).
    try Test.expect_equal(PSS.get_meta_param(.POSITIONS).get(), "meta POSITIONS", 5, "5", "failed meta length tracking", .{});
    try Test.expect_equal(PSS.get_meta_param(.SIZES).get(), "meta SIZES", 1, "1", "failed meta length tracking", .{});
    try Test.expect_equal(PSS.get_meta_param(.AREAS).get(), "meta AREAS", 3, "3", "failed meta length tracking", .{});
    try Test.expect_equal(PSS.get_meta_param(.SCALARS).get(), "meta SCALARS", 1, "1", "failed meta length tracking", .{});

    // One category's pool is independently iterable, with no side-table filtering.
    var it = PSS.iterator(.POSITIONS);
    var iter_count: usize = 0;
    while (it.next()) |p| : (iter_count += 1) {
        _ = p.get();
    }
    try Test.expect_equal(iter_count, "POSITIONS iterator count", 5, "5", "category iteration saw the wrong number of values", .{});

    var Consecutive: [2]PSS.Param(f32) = undefined;
    PSS.create_consecutive_indexed_params(.SCALARS, &.{
        PSS.ParamDefConsecutive(f32).root(.new_def(1.0)),
        PSS.ParamDefConsecutive(f32).root(.new_def(2.0)),
    }, Consecutive[0..]);
    try Test.expect_equal(Consecutive[1].ROOT.index, "Consecutive[1].ROOT.index", Consecutive[0].ROOT.index + 1, "Consecutive[0].ROOT.index + 1", "consecutive range", .{});
}

test "ParametricStateSystem - function lifecycle" {
    const Test = Root.Testing;
    const settings = comptime Settings{
        .ALLOW_FUNCTION_DELETION = true,
        .ALLOW_FUNCTION_REPLACEMENT = true,
        .MASTER_ASSERT_MODE = .ALWAYS_PANIC,
        .RECURSION_ASSERT_MODE = .ALWAYS_PANIC,
        .MAX_NUM_VALUES_IN_ANY_CATEGORY = ._256,
        .MAX_NUM_UNIQUE_FUNCTION_PAYLOADS = ._256,
        .MAX_NUM_TRIGGERED_UPDATES_ON_PARAM_CHANGE = ._8,
        .MAX_PAYLOAD_LIST_LIMIT = ._256,
        .MAX_NUM_FUNCTION_INPUTS = 4,
        .MAX_NUM_FUNCTION_OUTPUTS = 4,
    };
    const Cats = enum(u1) { INPUT, OUTPUT };
    const Funcs = enum(u1) { ADD_ONE, ADD_TEN };
    const CatDef = CategoryTypeDef(Cats);
    const ZERO: i32 = 0;
    const PROTO = struct {
        fn equals(a: i32, b: i32) bool {
            return a == b;
        }
    };
    const PSS = comptime ParametricStateSystem(settings, Cats, .{
        CatDef{
            .category = .INPUT,
            .default_value_for_type = @ptrCast(&ZERO),
            .param_type = i32,
            .type_equality_func = PROTO.equals,
        },
        CatDef{
            .category = .OUTPUT,
            .default_value_for_type = @ptrCast(&ZERO),
            .param_type = i32,
            .type_equality_func = PROTO.equals,
        },
    }, Funcs);

    const DebugAlloc = std.heap.DebugAllocator(.{});
    var debug_alloc = DebugAlloc.init;
    const alloc = debug_alloc.allocator();
    var threaded: std.Io.Threaded = .init(alloc, .{});
    defer threaded.deinit();
    PSS.init(alloc, threaded.io(), null);
    defer PSS.deinit();

    const Iface = PSS.UpdateInterface;
    const In = struct { x: PSS.ParamUpdateInput(i32) };
    const Out = struct { y: PSS.ParamUpdateOutput(i32) };
    const CALC = struct {
        fn add_one(iface: Iface) void {
            const in = iface.make_input_struct(In);
            const out = iface.make_output_struct(Out);
            out.y.set(in.x.get() + 1);
            iface.commit_deletions_and_changes();
        }
        fn add_ten(iface: Iface) void {
            const in = iface.make_input_struct(In);
            const out = iface.make_output_struct(Out);
            out.y.set(in.x.get() + 10);
            iface.commit_deletions_and_changes();
        }
    };
    PSS.initialize_update_function(.ADD_ONE, CALC.add_one);
    PSS.initialize_update_function(.ADD_TEN, CALC.add_ten);

    const r = PSS.create_new_root_param(.INPUT, 3, .default());
    const d = PSS.create_new_derived_param_from_input_struct(.ADD_ONE, In{
        .x = r.as_update_input(.{}),
    }, PSS.ParamReadOnlyDef.new_def(.OUTPUT).with_parent_delete_mode(.SET_DEFAULT_VALUE_WHEN_PARENT_IS_DELETED).default_value_when_deleted(), i32);

    try Test.expect_equal(d.get(), "d.get()", 4, "4", "initial derived value", .{});

    PSS.replace_update_function(.ADD_ONE, CALC.add_ten);
    try Test.expect_equal(d.get(), "d.get()", 13, "13", "replacement should re-run dependants", .{});

    PSS.delete_update_function(.ADD_ONE);
    try Test.expect_equal(d.get(), "d.get()", 0, "0", "function deletion should apply the output parent-delete policy", .{});
}
