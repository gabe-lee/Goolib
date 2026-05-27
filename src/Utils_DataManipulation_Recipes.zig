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
    VALID_ID,
    INVALID_ID_AFTER_LAST_ID,
    INVALID_ID_BEFORE_FIRST_ID,
    // Data move
    SWAP,
    REVERSE_RANGE,
    ROTATE_RANGE_LEFT,
    ROTATE_RANGE_RIGHT,
    MOVE_ONE_RIGHT_DISPLACE,
    MOVE_ONE_LEFT_DISPLACE,
    MOVE_RANGE_RIGHT_DISPLACE,
    MOVE_RANGE_LEFT_DISPLACE,
    MOVE_ONE_OVERWRITE,
    MOVE_RANGE_RIGHT_OVERWRITE,
    MOVE_RANGE_LEFT_OVERWRITE,
    SCRAMBLE,
    // List-like
    APPEND_ONE_SLOT_ASSUME_CAP,
    APPEND_MANY_SLOTS_ASSUME_CAP,
    PREPEND_ONE_SLOT_ASSUME_CAP,
    PREPEND_MANY_SLOTS_ASSUME_CAP,
    INSERT_ONE_SLOT_ASSUME_CAP,
    INSERT_MANY_SLOTS_ASSUME_CAP,
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
    infer_first_id_less_equal,
    infer_first_id_greater_equal,
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
};

pub const InferEngine = Utils.RecipeInference.RecipeInferenceEngine(PackageFlags, InferFuncNames, null);
pub const FuncFlag = InferEngine.Target;
pub const RecipeList = InferEngine.RecipeList;
pub const Recipe = InferEngine.Recipe;
pub const RECIPES: []const InferEngine.RecipeList = &.{
    .recipe_list(.GET_BASE_PTR, &.{
        .recipe(.infer_ptr, &.{
            .depends_on(.GET_PTR),
            .depends_on(.FIRST_ID),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
    }),
    .recipe_list(.GET_BASE_CONST_PTR, &.{
        .recipe(.infer_base_ptr, &.{
            .depends_on(.GET_BASE_PTR),
        }),
        .recipe(.infer_const_ptr, &.{
            .depends_on(.GET_CONST_PTR),
            .depends_on(.FIRST_ID),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_ptr, &.{
            .depends_on(.GET_PTR),
            .depends_on(.FIRST_ID),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
    }),
    .recipe_list(.GET_RANGE_SLICE, &.{
        .recipe(.infer_base_ptr, &.{
            .depends_on(.GET_BASE_PTR),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_ptr, &.{
            .depends_on(.GET_PTR),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
    }),
    .recipe_list(.GET_RANGE_CONST_SLICE, &.{
        .recipe(.infer_base_const_ptr, &.{
            .depends_on(.GET_BASE_CONST_PTR),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_const_ptr, &.{
            .depends_on(.GET_CONST_PTR),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
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
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_base_ptr, &.{
            .depends_on(.GET_BASE_PTR),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
    }),
    .recipe_list(.GET_PTR, &.{
        .recipe(.infer_base_ptr, &.{
            .depends_on(.GET_BASE_PTR),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
    }),
    .recipe_list(.GET_CONST_PTR, &.{
        .recipe(.infer_ptr, &.{
            .depends_on(.GET_PTR),
        }),
        .recipe(.infer_base_const_ptr, &.{
            .depends_on(.GET_BASE_CONST_PTR),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_base_ptr, &.{
            .depends_on(.GET_BASE_PTR),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
    }),
    .recipe_list(.SET, &.{
        .recipe(.infer_ptr, &.{
            .depends_on(.GET_PTR),
        }),
        .recipe(.infer_base_ptr, &.{
            .depends_on(.GET_BASE_PTR),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
    }),
    .recipe_list(.SWAP, &.{
        .recipe(.infer_get_set, &.{
            .depends_on(.GET),
            .depends_on(.SET),
        }),
    }),
    .recipe_list(.GREATER_THAN, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ELEMENTS_ARE_NUMERIC),
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
            .depends_on(.ELEMENTS_ARE_NUMERIC),
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
    .recipe_list(.EXACT_EQUALS, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ELEMENTS_ARE_NUMERIC),
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
            .depends_on(.ELEMENTS_ARE_NUMERIC),
        }),
        .recipe(.infer_eq, &.{
            .depends_on(.EXACT_EQUALS),
        }),
        .recipe(.infer_gt_lt, &.{
            .depends_on(.GREATER_THAN),
            .depends_on(.LESS_THAN),
        }),
    }),
    .recipe_list(.GREATER_THAN_OR_EQUAL, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ELEMENTS_ARE_NUMERIC),
        }),
        .recipe(.infer_lt, &.{
            .depends_on(.LESS_THAN),
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
    .recipe_list(.LESS_THAN_OR_EQUAL, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ELEMENTS_ARE_NUMERIC),
        }),
        .recipe(.infer_gt, &.{
            .depends_on(.GREATER_THAN),
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
    .recipe_list(.ID_GREATER_THAN, &.{
        .recipe(.infer_native, &.{
            // Classic indexing
            .depends_on(.ID_IS_NUMERIC),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
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
            // Classic indexing
            .depends_on(.ID_IS_NUMERIC),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_gteq, &.{
            .depends_on(.ID_GREATER_THAN_OR_EQUAL),
        }),
        .recipe(.infer_gt_eq, &.{
            .depends_on(.ID_GREATER_THAN),
            .depends_on(.ID_EQUALS),
        }),
    }),
    .recipe_list(.ID_EQUALS, &.{
        .recipe(.infer_native, &.{
            // Classic indexing
            .depends_on(.ID_IS_NUMERIC),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_gt_lt, &.{
            .depends_on(.ID_GREATER_THAN),
            .depends_on(.ID_LESS_THAN),
        }),
    }),
    .recipe_list(.ID_GREATER_THAN_OR_EQUAL, &.{
        .recipe(.infer_native, &.{
            // Classic indexing
            .depends_on(.ID_IS_NUMERIC),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
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
            // Classic indexing
            .depends_on(.ID_IS_NUMERIC),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_gt, &.{
            .depends_on(.ID_GREATER_THAN),
        }),
        .recipe(.infer_lt_eq, &.{
            .depends_on(.ID_LESS_THAN),
            .depends_on(.ID_EQUALS),
        }),
    }),
    .recipe_list(.VALID_ID, &.{
        .recipe(.infer_native, &.{
            .depends_on(.GET_LEN),
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_native_offset, &.{
            .depends_on(.GET_LEN),
            .depends_on(.FIRST_ID),
            // Classic offset indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_native_range, &.{
            .depends_on(.LAST_ID),
            .depends_on(.FIRST_ID),
            // Classic offset indexing
            .depends_on(.ID_IS_NUMERIC),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_first_id_less_equal, &.{
            .depends_on(.LAST_ID),
            .depends_on(.FIRST_ID),
            .depends_on(.ID_LESS_THAN_OR_EQUAL),
        }),
        .recipe(.infer_first_id_greater_equal, &.{
            .depends_on(.LAST_ID),
            .depends_on(.FIRST_ID),
            .depends_on(.ID_GREATER_THAN_OR_EQUAL),
        }),
    }),
    .recipe_list(.NEXT_ID, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_nth_next, &.{
            .depends_on(.NTH_NEXT_ID),
        }),
        .recipe(.infer_last_prev, &.{
            .depends_on(.LAST_ID),
            .depends_on(.PREV_ID),
        }),
    }),
    .recipe_list(.NTH_NEXT_ID, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_next, &.{
            .depends_on(.NEXT_ID),
        }),
        .recipe(.infer_last_prev, &.{
            .depends_on(.LAST_ID),
            .depends_on(.PREV_ID),
        }),
    }),
    .recipe_list(.PREV_ID, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_nth_prev, &.{
            .depends_on(.NTH_PREV_ID),
        }),
        .recipe(.infer_first_next, &.{
            .depends_on(.FIRST_ID),
            .depends_on(.NEXT_ID),
        }),
    }),
    .recipe_list(.NTH_PREV_ID, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_prev, &.{
            .depends_on(.PREV_ID),
        }),
        .recipe(.infer_first_next, &.{
            .depends_on(.FIRST_ID),
            .depends_on(.NEXT_ID),
        }),
    }),
    .recipe_list(.NTH_CHILD_ID, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_native_offset, &.{
            .depends_on(.LIMIT_LEN),
            .depends_on(.FIRST_ID),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
    }),
    .recipe_list(.PARENT_ID, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_native_offset, &.{
            .depends_on(.LIMIT_LEN),
            .depends_on(.FIRST_ID),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
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
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_limit, &.{
            .depends_on(.LIMIT_LEN),
        }),
        .recipe(.infer_next, &.{
            .depends_on(.NEXT_ID),
            .depends_on(.ID_EQUALS),
        }),
        .recipe(.infer_prev, &.{
            .depends_on(.PREV_ID),
            .depends_on(.ID_EQUALS),
        }),
    }),
    .recipe_list(.INVALID_ID_AFTER_LAST_ID, &.{
        .recipe(.infer_native_last, &.{
            .depends_on(.LAST_ID),
            .depends_on(.NEXT_ID),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_native_len, &.{
            .depends_on(.GET_LEN),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
    }),
    .recipe_list(.INVALID_ID_BEFORE_FIRST_ID, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_native_offset, &.{
            .depends_on(.FIRST_ID),
            .depends_on(.PREV_ID),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
    }),
    .recipe_list(.LIMIT_LEN, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_range, &.{
            .depends_on(.RANGE_LEN),
        }),
        .recipe(.infer_next, &.{
            .depends_on(.NEXT_ID),
            .depends_on(.ID_EQUALS),
        }),
        .recipe(.infer_prev, &.{
            .depends_on(.PREV_ID),
            .depends_on(.ID_EQUALS),
        }),
    }),
    .recipe_list(.GET_LEN, &.{
        .recipe(.infer_native, &.{
            // Classic indexing
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_native_last, &.{
            .depends_on(.LAST_ID),
            // Classic indexing
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
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
            // Classic indexing
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
        }),
        .recipe(.infer_nth_from_end, &.{
            .depends_on(.NTH_ID_FROM_END),
        }),
        .recipe(.infer_len_nth_from_start, &.{
            .depends_on(.NTH_ID_FROM_START),
            .depends_on(.GET_LEN),
        }),
        .recipe(.infer_first_len_nth_next, &.{
            .depends_on(.FIRST_ID),
            .depends_on(.GET_LEN),
            .depends_on(.NTH_NEXT_ID),
        }),
    }),
    .recipe_list(.FIRST_ID, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
            .depends_on(.ID_AFTER_LAST_IS_EQUAL_TO_LEN),
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
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_last_nth_prev, &.{
            .depends_on(.LAST_ID),
            .depends_on(.NTH_PREV_ID),
        }),
    }),
    .recipe_list(.NTH_ID_FROM_START, &.{
        .recipe(.infer_native, &.{
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ID_0_IS_FIRST_ITEM),
            .depends_on(.ID_0_IS_AT_BASE_PTR_ADDRESS),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_native_first, &.{
            .depends_on(.FIRST_ID),
            .depends_on(.ID_IS_INTEGER_TYPE_THAT_DIRECTLY_INDEXES_BASE_PTR),
            .depends_on(.ALL_ELEMENTS_IN_CONTIGUOUS_MEMORY_IN_ORDER),
            .depends_on(.INCREASING_IDS_DIRECTLY_CORRESPOND_TO_INCREASING_ADDRESSES),
        }),
        .recipe(.infer_first_nth_next, &.{
            .depends_on(.FIRST_ID),
            .depends_on(.NTH_NEXT_ID),
        }),
    }),
    .recipe_list(.REVERSE_RANGE, &.{
        .recipe(.infer_slice, &.{
            .depends_on(.GET_RANGE_SLICE),
        }),
        .recipe(.infer_swap, &.{
            .depends_on(.SWAP),
        }),
    }),
    .recipe_list(.ROTATE_RANGE_LEFT, &.{
        .recipe(.infer_rot_right, &.{
            .depends_on(.ROTATE_RANGE_RIGHT),
        }),
        .recipe(.infer_reverse_nth_next, &.{
            .depends_on(.REVERSE_RANGE),
            .depends_on(.NTH_NEXT_ID),
        }),
        .recipe(.infer_reverse_nth_prev, &.{
            .depends_on(.REVERSE_RANGE),
            .depends_on(.NTH_PREV_ID),
        }),
    }),
    .recipe_list(.ROTATE_RANGE_RIGHT, &.{
        .recipe(.infer_rot_left, &.{
            .depends_on(.ROTATE_RANGE_LEFT),
        }),
        .recipe(.infer_reverse_nth_next, &.{
            .depends_on(.REVERSE_RANGE),
            .depends_on(.NTH_NEXT_ID),
        }),
        .recipe(.infer_reverse_nth_prev, &.{
            .depends_on(.REVERSE_RANGE),
            .depends_on(.NTH_PREV_ID),
        }),
    }),
    .recipe_list(.MOVE_ONE_RIGHT_DISPLACE, &.{
        .recipe(.infer_get_set_move_block_left_overwrite, &.{
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
        .recipe(.infer_rot_right, &.{
            .depends_on(.ROTATE_RANGE_RIGHT),
            .depends_on(.RANGE_LEN),
        }),
    }),
    .recipe_list(.MOVE_ONE_LEFT_DISPLACE, &.{
        .recipe(.infer_get_set_move_block_right_overwrite, &.{
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
        .recipe(.infer_rot_left, &.{
            .depends_on(.ROTATE_RANGE_LEFT),
            .depends_on(.RANGE_LEN),
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
        }),
        .recipe(.infer_rot_right, &.{
            .depends_on(.ROTATE_RANGE_RIGHT),
            .depends_on(.RANGE_LEN),
        }),
    }),
    .recipe_list(.MOVE_RANGE_LEFT_DISPLACE, &.{
        .recipe(.infer_rot_left, &.{
            .depends_on(.ROTATE_RANGE_LEFT),
            .depends_on(.RANGE_LEN),
        }),
        .recipe(.infer_rot_right, &.{
            .depends_on(.ROTATE_RANGE_RIGHT),
            .depends_on(.RANGE_LEN),
        }),
    }),
    .recipe_list(.MOVE_RANGE_RIGHT_OVERWRITE, &.{
        .recipe(.infer_get_set, &.{
            .depends_on(.GET),
            .depends_on(.SET),
            .depends_on(.PREV_ID),
            .depends_on(.ID_EQUALS),
        }),
    }),
    .recipe_list(.MOVE_RANGE_LEFT_OVERWRITE, &.{
        .recipe(.infer_get_set, &.{
            .depends_on(.GET),
            .depends_on(.SET),
            .depends_on(.NEXT_ID),
            .depends_on(.ID_EQUALS),
        }),
    }),
    .recipe_list(.SCRAMBLE, &.{
        .recipe(.infer_get_set, &.{
            .depends_on(.GET),
            .depends_on(.SET),
            .depends_on(.NTH_NEXT_ID),
            .depends_on(.ID_EQUALS),
        }),
    }),
};

// const INFER = struct {
//     pub const APPEND_ONE = struct {
//         const FROM_APPEND_MANY = F.APPEND_MANY_SLOTS_ASSUME_CAP;
//     };
//     pub const APPEND_MANY = struct {
//         const FROM_APPEND_ONE = F.APPEND_ONE_SLOT_ASSUME_CAP;
//     };
//     pub const INSERT_ONE = struct {
//         const FROM_INSERT_MANY = F.INSERT_MANY_SLOTS_ASSUME_CAP;
//         const FROM_APPEND_ONE_MOVE_ONE_GET_SET = F.APPEND_ONE_SLOT_ASSUME_CAP | F.GET | F.SET | F.PREV_ID;
//         const FROM_APPEND_ONE_MOVE_ONE_MOVE = F.APPEND_ONE_SLOT_ASSUME_CAP | F.MOVE_BLOCK_RIGHT_NO_PRESERVE;
//     };
//     pub const INSERT_MANY = struct {
//         const FROM_INSERT_ONE = F.INSERT_ONE_SLOT_ASSUME_CAP;
//         const FROM_APPEND_MANY_MOVE_BLOCK = F.APPEND_MANY_SLOTS_ASSUME_CAP;
//         const FROM_APPEND_ONE_MOVE_ONE_GET_SET = F.APPEND_ONE_SLOT_ASSUME_CAP | F.GET | F.SET | F.PREV_ID;
//     };
//     pub const DELETE_ONE = struct {
//         const FROM_DELETE_RANGE = F.DELETE_RANGE;
//     };
//     pub const DELETE_RANGE = struct {
//         const FROM_DELETE_ONE = F.DELETE_ONE;
//     };
//     pub const MOVE_BLOCK_RIGHT_NO_PRESERVE = struct {
//         const FROM_GET_SET_PREV = F.GET | F.SET | F.PREV_ID;
//     };
//     pub const MOVE_BLOCK_LEFT_NO_PRESERVE = struct {
//         const FROM_GET_SET_NEXT = F.GET | F.SET | F.NEXT_ID;
//     };
//     pub const GET_BASE_PTR_CONST = struct {
//         const FROM_BASE_PTR = F.GET_BASE_PTR;
//     };
//     pub const GET_RANGE_SLICE = struct {
//         const FROM_BASE_PTR_CLASSIC_INDEX = F.GET_BASE_PTR | PROPERTY.CLASSIC_INDEXING_SCHEME;
//         const FROM_PTR_OFFSET_CLASSIC_INDEX = F.GET_PTR | PROPERTY.OFFSET_CLASSIC_INDEXING_SCHEME;
//     };
//     pub const GET_RANGE_CONST_SLICE = struct {
//         const FROM_BASE_PTR_CLASSIC_INDEX = F.GET_BASE_PTR | PROPERTY.CLASSIC_INDEXING_SCHEME;
//         const FROM_BASE_CONST_PTR_CLASSIC_INDEX = F.GET_BASE_CONST_PTR | PROPERTY.CLASSIC_INDEXING_SCHEME;
//         const FROM_PTR_OFFSET_CLASSIC_INDEX = F.GET_PTR | PROPERTY.OFFSET_CLASSIC_INDEXING_SCHEME;
//         const FROM_CONST_PTR_OFFSET_CLASSIC_INDEX = F.GET_PTR | PROPERTY.OFFSET_CLASSIC_INDEXING_SCHEME;
//         const FROM_RANGE_SLICE = F.GET_RANGE_SLICE;
//     };
//     pub const FIRST_CHILD_ID = struct {
//         const FROM_NTH_CHILD_ID = F.NTH_CHILD_ID;
//     };
//     pub const LAST_CHILD_ID = struct {
//         const FROM_NTH_CHILD_ID = F.NTH_CHILD_ID;
//     };
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
