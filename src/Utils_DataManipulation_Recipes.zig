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
const build = @import("builtin");
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const math = std.math;
const fmt = std.fmt;
const Random = std.Random;
// const pq = std.PriorityQueue;

const Root = @import("./_root.zig");
const object_equals = Root.Utils.Compare.shallow_equals;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const Endian = Root.CommonTypes.Endian;
const Math = Root.Math;
const Common = Root.CommonTypes;

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;

const DEBUG = std.debug.print;

pub const PackageFlags = enum {
    // Core access
    GET_BASE_PTR,
    GET_BASE_CONST_PTR,
    SET_BASE_PTR,
    GET_LEN,
    SET_LEN,
    GET_CAP,
    SET_CAP,
    GET_RANGE_SLICE,
    GET_RANGE_CONST_SLICE,
    // Val access
    GET,
    GET_PTR,
    GET_CONST_PTR,
    SET,
    // Val compare
    GREATER_THAN,
    GREATER_THAN_OR_EQUAL,
    LESS_THAN,
    LESS_THAN_OR_EQUAL,
    ORDER_EQUALS,
    EXACT_EQUALS,
    // ID access
    FIRST_ID,
    LAST_ID,
    NTH_ID_FROM_START,
    NTH_ID_FROM_END,
    PREV_ID,
    NEXT_ID,
    NTH_PREV_ID,
    NTH_NEXT_ID,
    FIRST_CHILD_ID,
    LAST_CHILD_ID,
    NTH_CHILD_ID,
    PARENT_ID,
    // Len
    RANGE_LEN,
    LIMIT_LEN,
    // ID compare
    ID_LESS_THAN,
    ID_LESS_THAN_OR_EQUAL,
    ID_GREATER_THAN,
    ID_GREATER_THAN_OR_EQUAL,
    ID_EQUALS,
    ID_VALID,
    INVALID_ID_AFTER_LAST_ID,
    INVALID_ID_BEFORE_FIRST_ID,
    // Data move
    SWAP,
    REVERSE_RANGE,
    ROTATE_RANGE_LEFT,
    ROTATE_RANGE_RIGHT,
    MOVE_ONE_OVERWRITE,
    MOVE_ONE_RIGHT_DISPLACE,
    MOVE_ONE_LEFT_DISPLACE,
    MOVE_RANGE_RIGHT_OVERWRITE,
    MOVE_RANGE_LEFT_OVERWRITE,
    MOVE_RANGE_RIGHT_DISPLACE,
    MOVE_RANGE_LEFT_DISPLACE,
    SCRAMBLE,
    // List-like
    APPEND_ONE_SLOT_ASSUME_CAP,
    APPEND_MANY_SLOTS_ASSUME_CAP,
    PREPEND_ONE_SLOT_ASSUME_CAP,
    PREPEND_MANY_SLOTS_ASSUME_CAP,
    INSERT_ONE_SLOT_BEFORE_ASSUME_CAP,
    INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP,
    DELETE_ONE,
    DELETE_RANGE,
    ENSURE_FREE_SPACE,
    TRIM_FREE_SPACE,
    // Properties
    ID_IS_NUMERIC,
    ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR,
    ID_0_IS_FIRST_ITEM,
    ID_0_IS_AT_BASE_PTR_ADDRESS,
    ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER,
    INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES,
    ID_AFTER_LAST_IS_EQUAL_TO_LEN,
    ELEMENTS_ARE_NUMERIC,

    pub const NUM_FLAGS = @intFromEnum(PackageFlags.ELEMENTS_ARE_NUMERIC) + 1;
};

pub const ExtraProperties = enum(Types.enum_tag_type(PackageFlags)) {
    ID_IS_NUMERIC = @intFromEnum(PackageFlags.ID_IS_NUMERIC),
    ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR = @intFromEnum(PackageFlags.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
    ID_0_IS_FIRST_ITEM = @intFromEnum(PackageFlags.ID_0_IS_FIRST_ITEM),
    ID_0_IS_AT_BASE_PTR_ADDRESS = @intFromEnum(PackageFlags.ID_0_IS_AT_BASE_PTR_ADDRESS),
    ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER = @intFromEnum(PackageFlags.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
    INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASIMG_ADDRESSES = @intFromEnum(PackageFlags.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
    ID_AFTER_LAST_IS_EQUAL_TO_LEN = @intFromEnum(PackageFlags.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
    ELEMENTS_ARE_NUMERIC = @intFromEnum(PackageFlags.ELEMENTS_ARE_NUMERIC),
};
pub const OptionalExtraProperties = struct {
    ID_IS_NUMERIC: bool = false,
    ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR: bool = false,
    ID_0_IS_FIRST_ITEM: bool = false,
    ID_0_IS_AT_BASE_PTR_ADDRESS: bool = false,
    ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER: bool = false,
    INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES: bool = false,
    ID_AFTER_LAST_IS_EQUAL_TO_LEN: bool = false,
    ELEMENTS_ARE_NUMERIC: bool = false,

    pub const classic_indexing = OptionalExtraProperties{
        .ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER = true,
        .ID_0_IS_AT_BASE_PTR_ADDRESS = true,
        .ID_0_IS_FIRST_ITEM = true,
        .ID_AFTER_LAST_IS_EQUAL_TO_LEN = true,
        .ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR = true,
        .ID_IS_NUMERIC = true,
        .INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES = true,
    };
    pub const offset_classic_indexing = OptionalExtraProperties{
        .ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER = true,
        .ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR = true,
        .ID_IS_NUMERIC = true,
        .INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES = true,
    };
    pub const numeric_element_type = OptionalExtraProperties{
        .ELEMENTS_ARE_NUMERIC = true,
    };
    pub const no_extra_properties = OptionalExtraProperties{};

    pub fn and_classic_indexing(opt: OptionalExtraProperties) OptionalExtraProperties {
        var o = opt;
        o.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER = true;
        o.ID_0_IS_AT_BASE_PTR_ADDRESS = true;
        o.ID_0_IS_FIRST_ITEM = true;
        o.ID_AFTER_LAST_IS_EQUAL_TO_LEN = true;
        o.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR = true;
        o.ID_IS_NUMERIC = true;
        o.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES = true;
        return o;
    }
    pub fn and_offset_classic_indexing(opt: OptionalExtraProperties) OptionalExtraProperties {
        var o = opt;
        o.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER = true;
        o.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR = true;
        o.ID_IS_NUMERIC = true;
        o.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES = true;
        return o;
    }
    pub fn and_numeric_element_type(opt: OptionalExtraProperties) OptionalExtraProperties {
        var o = opt;
        o.ELEMENTS_ARE_NUMERIC = true;
        return o;
    }

    pub fn add_to_func_flags(self: OptionalExtraProperties, flags: *[PackageFlags.NUM_FLAGS]FuncFlag, flags_len: *usize) void {
        next_prop: inline for (@typeInfo(OptionalExtraProperties).@"struct".fields) |opt_field| {
            if (@field(self, opt_field.name)) {
                inline for (@typeInfo(PackageFlags).@"enum".fields) |e_field| {
                    if (std.mem.eql(u8, opt_field.name, e_field.name)) {
                        const enum_tag: PackageFlags = @enumFromInt(e_field.value);
                        flags[flags_len.*] = FuncFlag.user_provided(enum_tag);
                        flags_len.* += 1;
                        continue :next_prop;
                    }
                }
                assert_unreachable(@src(), "optional extra properties struct has field `{s}` that does not match any enum field on Recipes.PackageFlags", .{opt_field.name});
            }
        }
    }
};

pub const InferFuncNames = enum {
    infer_ptr,
    infer_const_ptr,
    infer_base_const_ptr,
    infer_base_ptr,
    infer_get_set,
    infer_native,
    infer_native_offset,
    infer_native_range,
    infer_native_last,
    infer_native_first,
    infer_native_len,
    infer_lteq,
    infer_lt_eq,
    infer_lt_oq,
    infer_gteq,
    infer_gt_eq,
    infer_gt_oq,
    infer_gt_lt,
    infer_eq,
    infer_oq,
    infer_lt,
    infer_gt,
    infer_first_last_id_less_equal,
    infer_first_last_id_greater_equal,
    infer_nth_next,
    infer_last_prev,
    infer_next,
    infer_prev,
    infer_nth_prev,
    infer_first_next,
    infer_limit,
    infer_range,
    infer_nth_from_end,
    infer_len_nth_from_start,
    infer_first_len_nth_next,
    infer_nth_from_start,
    infer_len_nth_from_end,
    infer_last_len_nth_prev,
    infer_last_nth_prev,
    infer_first_nth_next,
    infer_slice,
    infer_swap,
    infer_rot_right,
    infer_rot_left,
    infer_reverse_nth_next,
    infer_reverse_nth_prev,
    infer_mv_block_right,
    infer_mv_block_left,
    infer_get_set_move_block_left_overwrite,
    infer_get_set_move_block_right_overwrite,
    infer_nth_child,
    infer_mv_one_overwrite,
    infer_set_len,
    infer_append_one,
    infer_append_many,
    infer_insert_one,
    infer_insert_many,
    infer_delete_one,
    infer_delete_range,
    infer_get_set_cap,
};
const WeightModeInfo = Utils.RecipeInference.WeightModeInfo(InferFuncNames);
const EVAL_QUOTA = 2000;
pub const InferEngine = Utils.RecipeInference.RecipeInferenceEngine(EVAL_QUOTA, PackageFlags, InferFuncNames, WeightModeInfo{
    .weight_type = f32,
});
pub const FuncFlag = InferEngine.Target;
pub const RecipeList = InferEngine.RecipeList;
pub const Recipe = InferEngine.Recipe;
const RECIPE_EVAL_QUOTA = 2000;

pub const RECIPES: []const InferEngine.RecipeList = make: {
    @setEvalBranchQuota(RECIPE_EVAL_QUOTA);
    break :make &.{
        .recipe_list(.GET_BASE_PTR, &.{
            .recipe(.infer_ptr, &.{
                .depends_on(.GET_PTR),
                .depends_on(.FIRST_ID),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
        }),
        .recipe_list(.GET_BASE_CONST_PTR, &.{
            .recipe(.infer_base_ptr, &.{
                .depends_on(.GET_BASE_PTR),
            }),
            .recipe(.infer_const_ptr, &.{
                .depends_on(.GET_CONST_PTR),
                .depends_on(.FIRST_ID),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_ptr, &.{
                .depends_on(.GET_PTR),
                .depends_on(.FIRST_ID),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
        }),
        .recipe_list(.GET_RANGE_SLICE, &.{
            .recipe(.infer_base_ptr, &.{
                .depends_on(.GET_BASE_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_ptr, &.{
                .depends_on(.GET_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
        }),
        .recipe_list(.GET_RANGE_CONST_SLICE, &.{
            .recipe(.infer_range, &.{
                .depends_on(.GET_RANGE_SLICE),
            }),
            .recipe(.infer_base_const_ptr, &.{
                .depends_on(.GET_BASE_CONST_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_const_ptr, &.{
                .depends_on(.GET_CONST_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
        }),
        .recipe_list(.GET, &.{
            .recipe(.infer_const_ptr, &.{
                .depends_on(.GET_CONST_PTR),
            }),
            .recipe(.infer_ptr, &.{
                .depends_on(.GET_PTR),
            }),
            .recipe(.infer_base_const_ptr, &.{
                .depends_on(.GET_BASE_CONST_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_base_ptr, &.{
                .depends_on(.GET_BASE_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
        }),
        .recipe_list(.GET_PTR, &.{
            .recipe(.infer_base_ptr, &.{
                .depends_on(.GET_BASE_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
        }),
        .recipe_list(.GET_CONST_PTR, &.{
            .recipe(.infer_ptr, &.{
                .depends_on(.GET_PTR),
            }),
            .recipe(.infer_base_const_ptr, &.{
                .depends_on(.GET_BASE_CONST_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_base_ptr, &.{
                .depends_on(.GET_BASE_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
        }),
        .recipe_list(.SET, &.{
            .recipe(.infer_ptr, &.{
                .depends_on(.GET_PTR),
            }),
            .recipe(.infer_base_ptr, &.{
                .depends_on(.GET_BASE_PTR),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
        }),
        .recipe_list(.SWAP, &.{
            .recipe(.infer_get_set, &.{
                .depends_on(.GET),
                .depends_on(.SET),
            }),
        }),
        .recipe_list(.EXACT_EQUALS, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ELEMENTS_ARE_NUMERIC),
            }),
            .recipe(.infer_oq, &.{
                .depends_on(.ORDER_EQUALS),
            }),
            .recipe(.infer_gt_lt, &.{
                .depends_on(.GREATER_THAN),
                .depends_on(.LESS_THAN),
            }),
        }),
        .recipe_list(.ORDER_EQUALS, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ELEMENTS_ARE_NUMERIC),
            }),
            .recipe(.infer_eq, &.{
                .depends_on(.EXACT_EQUALS),
            }),
            .recipe(.infer_gt_lt, &.{
                .depends_on(.GREATER_THAN),
                .depends_on(.LESS_THAN),
            }),
        }),
        .recipe_list(.GREATER_THAN, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ELEMENTS_ARE_NUMERIC),
            }),
            .recipe(.infer_lt, &.{
                .depends_on(.LESS_THAN),
            }),
            .recipe(.infer_lteq, &.{
                .depends_on(.LESS_THAN_OR_EQUAL),
            }),
            .recipe(.infer_lt_oq, &.{
                .depends_on(.LESS_THAN),
                .depends_on(.ORDER_EQUALS),
            }),
            .recipe(.infer_lt_eq, &.{
                .depends_on(.LESS_THAN),
                .depends_on(.EXACT_EQUALS),
            }),
        }),
        .recipe_list(.LESS_THAN, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ELEMENTS_ARE_NUMERIC),
            }),
            .recipe(.infer_gt, &.{
                .depends_on(.GREATER_THAN),
            }),
            .recipe(.infer_gteq, &.{
                .depends_on(.GREATER_THAN_OR_EQUAL),
            }),
            .recipe(.infer_gt_oq, &.{
                .depends_on(.GREATER_THAN_OR_EQUAL),
                .depends_on(.ORDER_EQUALS),
            }),
            .recipe(.infer_gt_eq, &.{
                .depends_on(.GREATER_THAN_OR_EQUAL),
                .depends_on(.EXACT_EQUALS),
            }),
        }),
        .recipe_list(.GREATER_THAN_OR_EQUAL, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ELEMENTS_ARE_NUMERIC),
            }),
            .recipe(.infer_lteq, &.{
                .depends_on(.LESS_THAN_OR_EQUAL),
            }),
            .recipe(.infer_lt, &.{
                .depends_on(.LESS_THAN),
            }),
            .recipe(.infer_gt_oq, &.{
                .depends_on(.GREATER_THAN),
                .depends_on(.ORDER_EQUALS),
            }),
            .recipe(.infer_gt_eq, &.{
                .depends_on(.GREATER_THAN),
                .depends_on(.EXACT_EQUALS),
            }),
        }),
        .recipe_list(.LESS_THAN_OR_EQUAL, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ELEMENTS_ARE_NUMERIC),
            }),
            .recipe(.infer_gteq, &.{
                .depends_on(.GREATER_THAN_OR_EQUAL),
            }),
            .recipe(.infer_gt, &.{
                .depends_on(.GREATER_THAN),
            }),
            .recipe(.infer_lt_oq, &.{
                .depends_on(.LESS_THAN),
                .depends_on(.ORDER_EQUALS),
            }),
            .recipe(.infer_lt_eq, &.{
                .depends_on(.LESS_THAN),
                .depends_on(.EXACT_EQUALS),
            }),
        }),
        .recipe_list(.ID_EQUALS, &.{
            .recipe(.infer_native, &.{
                // ID Properties
                .depends_on_zero_weight(.ID_IS_NUMERIC),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_gt_lt, &.{
                .depends_on(.ID_GREATER_THAN),
                .depends_on(.ID_LESS_THAN),
            }),
        }),
        .recipe_list(.ID_GREATER_THAN, &.{
            .recipe(.infer_native, &.{
                // ID Properties
                .depends_on_zero_weight(.ID_IS_NUMERIC),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_lt, &.{
                .depends_on(.ID_LESS_THAN),
            }),
            .recipe(.infer_lteq, &.{
                .depends_on(.ID_LESS_THAN_OR_EQUAL),
            }),
            .recipe(.infer_lt_eq, &.{
                .depends_on(.ID_LESS_THAN),
                .depends_on(.ID_EQUALS),
            }),
        }),
        .recipe_list(.ID_LESS_THAN, &.{
            .recipe(.infer_native, &.{
                // ID Properties
                .depends_on_zero_weight(.ID_IS_NUMERIC),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_gt, &.{
                .depends_on(.ID_GREATER_THAN),
            }),
            .recipe(.infer_gteq, &.{
                .depends_on(.ID_GREATER_THAN_OR_EQUAL),
            }),
            .recipe(.infer_gt_eq, &.{
                .depends_on(.ID_GREATER_THAN),
                .depends_on(.ID_EQUALS),
            }),
        }),
        .recipe_list(.ID_GREATER_THAN_OR_EQUAL, &.{
            .recipe(.infer_native, &.{
                // ID Properties
                .depends_on_zero_weight(.ID_IS_NUMERIC),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_lteq, &.{
                .depends_on(.ID_LESS_THAN_OR_EQUAL),
            }),
            .recipe(.infer_lt, &.{
                .depends_on(.ID_LESS_THAN),
            }),
            .recipe(.infer_gt_eq, &.{
                .depends_on(.ID_GREATER_THAN),
                .depends_on(.ID_EQUALS),
            }),
        }),
        .recipe_list(.ID_LESS_THAN_OR_EQUAL, &.{
            .recipe(.infer_native, &.{
                // ID Properties
                .depends_on_zero_weight(.ID_IS_NUMERIC),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_gteq, &.{
                .depends_on(.ID_GREATER_THAN_OR_EQUAL),
            }),
            .recipe(.infer_gt, &.{
                .depends_on(.ID_GREATER_THAN),
            }),
            .recipe(.infer_lt_eq, &.{
                .depends_on(.ID_LESS_THAN),
                .depends_on(.ID_EQUALS),
            }),
        }),
        .recipe_list(.ID_VALID, &.{
            .recipe(.infer_native, &.{
                .depends_on(.GET_LEN),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_native_offset, &.{
                .depends_on(.LAST_ID),
                .depends_on(.FIRST_ID),
                // Classic offset indexing
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_first_last_id_less_equal, &.{
                .depends_on(.LAST_ID),
                .depends_on(.FIRST_ID),
                .depends_on(.ID_LESS_THAN_OR_EQUAL),
            }),
            .recipe(.infer_first_last_id_greater_equal, &.{
                .depends_on(.LAST_ID),
                .depends_on(.FIRST_ID),
                .depends_on(.ID_GREATER_THAN_OR_EQUAL),
            }),
        }),
        .recipe_list(.NEXT_ID, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_nth_next, &.{
                .depends_on(.NTH_NEXT_ID),
            }),
            .recipe(.infer_last_prev, &.{
                .depends_on(.LAST_ID),
                .depends_on_with_weight(.PREV_ID, .n()),
                .depends_on_with_weight(.ID_EQUALS, .n()),
                .depends_on_with_weight(.ID_VALID, .n()),
                .depends_on(.INVALID_ID_AFTER_LAST_ID),
            }),
        }),
        .recipe_list(.NTH_NEXT_ID, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_next, &.{
                .depends_on_with_weight(.NEXT_ID, .n()),
            }),
            .recipe(.infer_last_prev, &.{
                .depends_on(.LAST_ID),
                .depends_on_with_weight(.PREV_ID, .n()),
                .depends_on_with_weight(.ID_EQUALS, .n()),
                .depends_on_with_weight(.ID_VALID, .n()),
                .depends_on(.INVALID_ID_AFTER_LAST_ID),
            }),
        }),
        .recipe_list(.PREV_ID, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_nth_prev, &.{
                .depends_on(.NTH_PREV_ID),
            }),
            .recipe(.infer_first_next, &.{
                .depends_on(.FIRST_ID),
                .depends_on(.NEXT_ID),
                .depends_on(.ID_EQUALS),
                .depends_on(.ID_VALID),
                .depends_on(.INVALID_ID_BEFORE_FIRST_ID),
            }),
        }),
        .recipe_list(.NTH_PREV_ID, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_prev, &.{
                .depends_on(.PREV_ID),
            }),
            .recipe(.infer_first_next, &.{
                .depends_on(.FIRST_ID),
                .depends_on(.NEXT_ID),
                .depends_on(.ID_EQUALS),
                .depends_on(.ID_VALID),
                .depends_on(.INVALID_ID_BEFORE_FIRST_ID),
            }),
        }),
        .recipe_list(.NTH_CHILD_ID, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_native_offset, &.{
                .depends_on(.LIMIT_LEN),
                .depends_on(.FIRST_ID),
                // ID props
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
        }),
        .recipe_list(.PARENT_ID, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_native_offset, &.{
                .depends_on(.LIMIT_LEN),
                .depends_on(.FIRST_ID),
                // ID props
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
        }),
        .recipe_list(.FIRST_CHILD_ID, &.{
            .recipe(.infer_nth_child, &.{
                .depends_on(.NTH_CHILD_ID),
            }),
        }),
        .recipe_list(.LAST_CHILD_ID, &.{
            .recipe(.infer_nth_child, &.{
                .depends_on(.NTH_CHILD_ID),
            }),
        }),
        .recipe_list(.RANGE_LEN, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_limit, &.{
                .depends_on(.LIMIT_LEN),
            }),
            .recipe(.infer_next, &.{
                .depends_on_with_weight(.NEXT_ID, .n()),
                .depends_on_with_weight(.ID_EQUALS, .n()),
                .depends_on(.ID_LESS_THAN_OR_EQUAL),
            }),
            .recipe(.infer_prev, &.{
                .depends_on_with_weight(.PREV_ID, .n()),
                .depends_on_with_weight(.ID_EQUALS, .n()),
                .depends_on(.ID_LESS_THAN_OR_EQUAL),
            }),
        }),
        .recipe_list(.INVALID_ID_AFTER_LAST_ID, &.{
            .recipe(.infer_native_last, &.{
                .depends_on(.LAST_ID),
                .depends_on(.NEXT_ID),
                // ID props
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_native_len, &.{
                .depends_on(.GET_LEN),
                // ID props
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
        }),
        .recipe_list(.INVALID_ID_BEFORE_FIRST_ID, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_native_offset, &.{
                .depends_on(.FIRST_ID),
                .depends_on(.PREV_ID),
                // ID props
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
        }),
        .recipe_list(.LIMIT_LEN, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_range, &.{
                .depends_on(.RANGE_LEN),
            }),
            .recipe(.infer_next, &.{
                .depends_on_with_weight(.NEXT_ID, .n()),
                .depends_on_with_weight(.ID_EQUALS, .n()),
            }),
            .recipe(.infer_prev, &.{
                .depends_on_with_weight(.PREV_ID, .n()),
                .depends_on_with_weight(.ID_EQUALS, .n()),
            }),
        }),
        .recipe_list(.GET_LEN, &.{
            .recipe(.infer_native_last, &.{
                .depends_on(.LAST_ID),
                // ID Properties
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_range, &.{
                .depends_on(.FIRST_ID),
                .depends_on(.LAST_ID),
                .depends_on(.RANGE_LEN),
            }),
        }),
        .recipe_list(.LAST_ID, &.{
            .recipe(.infer_native, &.{
                .depends_on(.GET_LEN),
                // ID Properties
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_nth_from_end, &.{
                .depends_on(.NTH_ID_FROM_END),
            }),
            .recipe(.infer_len_nth_from_start, &.{
                .depends_on(.NTH_ID_FROM_START),
                .depends_on(.GET_LEN),
            }),
        }),
        .recipe_list(.FIRST_ID, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
                .depends_on_zero_weight(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
            }),
            .recipe(.infer_nth_from_start, &.{
                .depends_on(.NTH_ID_FROM_START),
            }),
            .recipe(.infer_len_nth_from_end, &.{
                .depends_on(.NTH_ID_FROM_END),
                .depends_on(.GET_LEN),
            }),
            .recipe(.infer_last_len_nth_prev, &.{
                .depends_on(.LAST_ID),
                .depends_on(.GET_LEN),
                .depends_on(.NTH_PREV_ID),
            }),
        }),
        .recipe_list(.NTH_ID_FROM_END, &.{
            .recipe(.infer_native_last, &.{
                .depends_on(.LAST_ID),
                // ID props
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_last_nth_prev, &.{
                .depends_on(.LAST_ID),
                .depends_on(.NTH_PREV_ID),
            }),
        }),
        .recipe_list(.NTH_ID_FROM_START, &.{
            .recipe(.infer_native, &.{
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ID_0_IS_FIRST_ITEM),
                .depends_on_zero_weight(.ID_0_IS_AT_BASE_PTR_ADDRESS),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_native_first, &.{
                .depends_on(.FIRST_ID),
                // ID props
                .depends_on_zero_weight(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
                .depends_on_zero_weight(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
                .depends_on_zero_weight(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            }),
            .recipe(.infer_first_nth_next, &.{
                .depends_on(.FIRST_ID),
                .depends_on(.NTH_NEXT_ID),
            }),
        }),
        .recipe_list(.REVERSE_RANGE, &.{
            .recipe_with_special_factors(.infer_slice, .one(), .k_n(0.5), &.{
                .depends_on(.GET_RANGE_SLICE),
            }),
            .recipe(.infer_swap, &.{
                .depends_on_with_weight(.SWAP, .k_n(0.5)),
                .depends_on_with_weight(.ID_EQUALS, .k_n(0.5)),
                .depends_on_with_weight(.NEXT_ID, .k_n(0.5)),
                .depends_on_with_weight(.PREV_ID, .k_n(0.5)),
                .depends_on(.ID_LESS_THAN_OR_EQUAL),
            }),
        }),
        .recipe_list(.ROTATE_RANGE_LEFT, &.{
            .recipe(.infer_rot_right, &.{
                .depends_on(.RANGE_LEN),
                .depends_on(.ROTATE_RANGE_RIGHT),
            }),
            .recipe(.infer_reverse_nth_next, &.{
                .depends_on_with_weight(.REVERSE_RANGE, .flat(2)),
                .depends_on(.NTH_NEXT_ID),
                .depends_on(.PREV_ID),
                .depends_on(.ID_LESS_THAN),
                .depends_on(.RANGE_LEN),
            }),
            .recipe(.infer_reverse_nth_prev, &.{
                .depends_on_with_weight(.REVERSE_RANGE, .flat(2)),
                .depends_on(.NTH_PREV_ID),
                .depends_on(.PREV_ID),
                .depends_on(.ID_LESS_THAN),
                .depends_on(.RANGE_LEN),
            }),
        }),
        .recipe_list(.ROTATE_RANGE_RIGHT, &.{
            .recipe(.infer_rot_left, &.{
                .depends_on(.RANGE_LEN),
                .depends_on(.ROTATE_RANGE_LEFT),
            }),
            .recipe(.infer_reverse_nth_next, &.{
                .depends_on_with_weight(.REVERSE_RANGE, .flat(2)),
                .depends_on(.NTH_NEXT_ID),
                .depends_on(.NEXT_ID),
                .depends_on(.ID_LESS_THAN),
                .depends_on(.RANGE_LEN),
            }),
            .recipe(.infer_reverse_nth_prev, &.{
                .depends_on_with_weight(.REVERSE_RANGE, .flat(2)),
                .depends_on(.NTH_PREV_ID),
                .depends_on(.NEXT_ID),
                .depends_on(.ID_LESS_THAN),
                .depends_on(.RANGE_LEN),
            }),
        }),
        .recipe_list(.MOVE_ONE_RIGHT_DISPLACE, &.{
            .recipe_with_special_factors(.infer_get_set_move_block_left_overwrite, .flat(0.5), .zero(), &.{
                .depends_on(.GET),
                .depends_on(.SET),
                .depends_on(.MOVE_RANGE_LEFT_OVERWRITE),
                .depends_on(.NEXT_ID),
            }),
            .recipe(.infer_mv_block_right, &.{
                .depends_on(.MOVE_RANGE_RIGHT_DISPLACE),
            }),
            .recipe(.infer_rot_left, &.{
                .depends_on(.ROTATE_RANGE_LEFT),
            }),
        }),
        .recipe_list(.MOVE_ONE_LEFT_DISPLACE, &.{
            .recipe_with_special_factors(.infer_get_set_move_block_right_overwrite, .flat(0.5), .zero(), &.{
                .depends_on(.GET),
                .depends_on(.SET),
                .depends_on(.MOVE_RANGE_RIGHT_OVERWRITE),
                .depends_on(.PREV_ID),
            }),
            .recipe(.infer_mv_block_left, &.{
                .depends_on(.MOVE_RANGE_LEFT_DISPLACE),
            }),
            .recipe(.infer_rot_right, &.{
                .depends_on(.ROTATE_RANGE_RIGHT),
            }),
        }),
        .recipe_list(.MOVE_ONE_OVERWRITE, &.{
            .recipe(.infer_get_set, &.{
                .depends_on(.GET),
                .depends_on(.SET),
            }),
        }),
        .recipe_list(.MOVE_RANGE_RIGHT_DISPLACE, &.{
            .recipe(.infer_rot_left, &.{
                .depends_on(.ROTATE_RANGE_LEFT),
                .depends_on(.RANGE_LEN),
                .depends_on(.NTH_NEXT_ID),
                .depends_on(.ID_LESS_THAN),
                .depends_on(.ID_EQUALS),
                .depends_on(.ID_VALID),
            }),
        }),
        .recipe_list(.MOVE_RANGE_LEFT_DISPLACE, &.{
            .recipe(.infer_rot_right, &.{
                .depends_on(.ROTATE_RANGE_RIGHT),
                .depends_on(.RANGE_LEN),
                .depends_on_with_weight(.ID_LESS_THAN, .flat(3)),
                .depends_on(.ID_EQUALS),
                .depends_on_with_weight(.ID_VALID, .flat(3)),
            }),
        }),
        .recipe_list(.MOVE_RANGE_RIGHT_OVERWRITE, &.{
            .recipe(.infer_mv_one_overwrite, &.{
                .depends_on_with_weight(.MOVE_ONE_OVERWRITE, .n()),
                .depends_on(.NTH_NEXT_ID),
                .depends_on_with_weight(.ID_VALID, .flat(4)),
                .depends_on_with_weight(.PREV_ID, .k_n(2)),
                .depends_on_with_weight(.ID_EQUALS, .n()),
            }),
        }),
        .recipe_list(.MOVE_RANGE_LEFT_OVERWRITE, &.{
            .recipe(.infer_mv_one_overwrite, &.{
                .depends_on_with_weight(.MOVE_ONE_OVERWRITE, .n()),
                .depends_on(.NTH_PREV_ID),
                .depends_on_with_weight(.ID_VALID, .flat(4)),
                .depends_on_with_weight(.NEXT_ID, .k_n(2)),
                .depends_on_with_weight(.ID_EQUALS, .n()),
            }),
        }),
        .recipe_list(.SCRAMBLE, &.{
            .recipe(.infer_mv_one_overwrite, &.{
                .depends_on_with_weight(.MOVE_ONE_OVERWRITE, .n()),
                .depends_on_with_weight(.NTH_NEXT_ID, .n()),
                .depends_on_with_weight(.ID_EQUALS, .n()),
            }),
        }),
        .recipe_list(.APPEND_ONE_SLOT_ASSUME_CAP, &.{
            .recipe(.infer_append_many, &.{
                .depends_on(.APPEND_MANY_SLOTS_ASSUME_CAP),
            }),
            .recipe(.infer_set_len, &.{
                .depends_on(.GET_LEN),
                .depends_on(.SET_LEN),
                .depends_on(.LAST_ID),
            }),
        }),
        .recipe_list(.APPEND_MANY_SLOTS_ASSUME_CAP, &.{
            .recipe(.infer_append_one, &.{
                .depends_on_with_weight(.APPEND_ONE_SLOT_ASSUME_CAP, .n()),
            }),
            .recipe(.infer_set_len, &.{
                .depends_on(.GET_LEN),
                .depends_on(.SET_LEN),
                .depends_on(.LAST_ID),
            }),
        }),
        .recipe_list(.INSERT_ONE_SLOT_BEFORE_ASSUME_CAP, &.{
            .recipe(.infer_append_one, &.{
                .depends_on(.APPEND_ONE_SLOT_ASSUME_CAP),
                .depends_on(.MOVE_RANGE_RIGHT_OVERWRITE),
                .depends_on(.LAST_ID),
            }),
            .recipe(.infer_insert_many, &.{
                .depends_on(.INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP),
            }),
        }),
        .recipe_list(.INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP, &.{
            .recipe(.infer_insert_one, &.{
                .depends_on_with_weight(.INSERT_ONE_SLOT_BEFORE_ASSUME_CAP, .n()),
                .depends_on(.NTH_NEXT_ID),
            }),
            .recipe(.infer_append_many, &.{
                .depends_on(.APPEND_MANY_SLOTS_ASSUME_CAP),
                .depends_on(.LAST_ID),
                .depends_on(.MOVE_RANGE_RIGHT_OVERWRITE),
            }),
        }),
        .recipe_list(.PREPEND_ONE_SLOT_ASSUME_CAP, &.{
            .recipe(.infer_insert_one, &.{
                .depends_on(.INSERT_ONE_SLOT_BEFORE_ASSUME_CAP),
                .depends_on(.APPEND_ONE_SLOT_ASSUME_CAP),
                .depends_on(.FIRST_ID),
            }),
        }),
        .recipe_list(.PREPEND_MANY_SLOTS_ASSUME_CAP, &.{
            .recipe(.infer_insert_many, &.{
                .depends_on(.INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP),
                .depends_on(.APPEND_MANY_SLOTS_ASSUME_CAP),
                .depends_on(.FIRST_ID),
            }),
        }),
        .recipe_list(.DELETE_ONE, &.{
            .recipe(.infer_delete_range, &.{
                .depends_on(.DELETE_RANGE),
            }),
            .recipe(.infer_set_len, &.{
                .depends_on(.GET_LEN),
                .depends_on(.SET_LEN),
                .depends_on(.LAST_ID),
                .depends_on(.NEXT_ID),
                .depends_on(.ID_VALID),
                .depends_on(.ID_EQUALS),
                .depends_on(.MOVE_RANGE_LEFT_OVERWRITE),
            }),
        }),
        .recipe_list(.DELETE_RANGE, &.{
            .recipe(.infer_delete_one, &.{
                .depends_on_with_weight(.DELETE_ONE, .n()),
                .depends_on(.RANGE_LEN),
                .depends_on(.ID_EQUALS),
                .depends_on(.FIRST_ID),
                .depends_on(.PREV_ID),
                .depends_on_with_weight(.NEXT_ID, .n()),
            }),
            .recipe(.infer_set_len, &.{
                .depends_on(.GET_LEN),
                .depends_on(.SET_LEN),
                .depends_on(.RANGE_LEN),
                .depends_on(.LAST_ID),
                .depends_on(.NEXT_ID),
                .depends_on(.ID_EQUALS),
                .depends_on(.MOVE_RANGE_LEFT_OVERWRITE),
            }),
        }),
        .recipe_list(.ENSURE_FREE_SPACE, &.{
            .recipe(.infer_get_set_cap, &.{
                .depends_on(.GET_LEN),
                .depends_on(.GET_CAP),
                .depends_on(.SET_CAP),
            }),
        }),
    };
};

// const INFER = struct {
//     pub const ENSURE_FREE_SPACE = struct {
//         const FROM_GET_LEN_GET_SET_CAP = F.GET_LEN | F.SET_CAP | F.GET_CAP;
//     };
// };

test "data manipulation recipes" {
    const PRINT_SOLUTIONS = true;
    const provide: []const InferEngine.Target = &.{
        // Inherent to native memory
        .user_provided(.GET_BASE_PTR),
        .user_provided(.SET_BASE_PTR),
        .user_provided(.GET_LEN),
        .user_provided(.SET_LEN),
        .user_provided(.GET_CAP),
        .user_provided(.SET_CAP),
        // Two compare funcs
        .user_provided(.LESS_THAN),
        .user_provided(.ORDER_EQUALS),
        // Id properties inherent to native memory
        .set_property(.ID_IS_NUMERIC),
        .set_property(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
        .set_property(.ID_0_IS_FIRST_ITEM),
        .set_property(.ID_0_IS_AT_BASE_PTR_ADDRESS),
        .set_property(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
        .set_property(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        .set_property(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
    };
    const solutions = InferEngine.resolve_recipes_by_order(provide, RECIPES);
    if (PRINT_SOLUTIONS) {
        InferEngine.print_solutions(solutions);
    }
}
