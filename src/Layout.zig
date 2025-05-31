//! TODO Documentation
//! #### License: Zlib
//! #### Referenced Work Licenses:
//! - CLAY: (Zlib) https://github.com/nicbarker/clay/blob/main/LICENSE.md

// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
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
const builtin = std.builtin;
const build = @import("builtin");
const math = std.math;
const Allocator = std.mem.Allocator;

const Root = @import("./_root.zig");
const Flags = Root.Flags.Flags;
const Utils = Root.Utils;
const GrowthModel = Root.CommonTypes.GrowthModel;
const AllocErrorBehavior = Root.CommonTypes.AllocErrorBehavior;
const ListDef = Root.List;
const Rect2 = Root.Rect2;
const AABB2 = Root.AABB2;
const Vec2 = Root.Vec2;
const Types = Root.Types;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

// zig fmt: off
pub const PanelFlags = Flags(enum(u64) {
    IS_USED                         = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    IS_FREE                         = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_1,

    X_SIZE_FIT                      = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    X_SIZE_EXPAND                   = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_01_0,
    X_SIZE_PERCENT                  = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_10_0,
    X_SIZE_PIXELS                   = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_11_0,

    Y_SIZE_FIT                      = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    Y_SIZE_EXPAND                   = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_01_00_0,
    Y_SIZE_PERCENT                  = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_10_00_0,
    Y_SIZE_PIXELS                   = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_11_00_0,

    LAYOUT_FREE_FLOATING            = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    LAYOUT_GRID                     = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0001_00_00_0,
    LAYOUT_LEFT_TO_RIGHT_TOP_TO_BOT = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0010_00_00_0,
    LAYOUT_LEFT_TO_RIGHT_BOT_TO_TOP = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0011_00_00_0,
    LAYOUT_RIGHT_TO_LEFT_TOP_TO_BOT = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0100_00_00_0,
    LAYOUT_RIGHT_TO_LEFT_BOT_TO_TOP = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0101_00_00_0,
    LAYOUT_TOP_TO_BOT_LEFT_TO_RIGHT = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0110_00_00_0,
    LAYOUT_TOP_TO_BOT_RIGHT_TO_LEFT = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0111_00_00_0,
    LAYOUT_BOT_TO_TOP_LEFT_TO_RIGHT = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_1000_00_00_0,
    LAYOUT_BOT_TO_TOP_RIGHT_TO_LEFT = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_1001_00_00_0,
    //LAYOUT_UNUSED                 = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_1111_00_00_0,

    X_OFFSET_PIXELS_RELATIVE        = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    X_OFFSET_PIXELS_ABSOLUTE        = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_01_0000_00_00_0,
    X_OFFSET_PERCENT_PARENT_WIDTH   = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_10_0000_00_00_0,
    X_OFFSET_PERCENT_OWN_WIDTH      = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_11_0000_00_00_0,

    Y_OFFSET_PIXELS_RELATIVE        = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    Y_OFFSET_PIXELS_ABSOLUTE        = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_01_00_0000_00_00_0,   
    Y_OFFSET_PERCENT_PARENT_HEIGHT  = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_10_00_0000_00_00_0,   
    Y_OFFSET_PERCENT_OWN_HEIGHT     = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_11_00_0000_00_00_0, 

    PARENT_ANCHOR_TOP_LEFT          = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    PARENT_ANCHOR_TOP_CENTER        = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0001_00_00_0000_00_00_0,
    PARENT_ANCHOR_TOP_RIGHT         = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0010_00_00_0000_00_00_0,
    PARENT_ANCHOR_MIDDLE_LEFT       = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0011_00_00_0000_00_00_0,
    PARENT_ANCHOR_MIDDLE_CENTER     = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0100_00_00_0000_00_00_0,
    PARENT_ANCHOR_MIDDLE_RIGHT      = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0101_00_00_0000_00_00_0,
    PARENT_ANCHOR_BOT_LEFT          = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0110_00_00_0000_00_00_0,
    PARENT_ANCHOR_BOT_CENTER        = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0111_00_00_0000_00_00_0,
    PARENT_ANCHOR_BOT_RIGHT         = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_1000_00_00_0000_00_00_0,   
    //PARENT_ANCHOR_UNUSED          = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_1111_00_00_0000_00_00_0,

    X_MIN_PIXELS                    = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    X_MIN_PERCENT_PARENT_WIDTH      = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_1_0000_00_00_0000_00_00_0,

    X_MAX_PIXELS                    = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    X_MAX_PERCENT_PARENT_WIDTH      = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_1_0_0000_00_00_0000_00_00_0,

    Y_MIN_PIXELS                    = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    Y_MIN_PERCENT_PARENT_WIDTH      = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_1_0_0_0000_00_00_0000_00_00_0,

    Y_MAX_PIXELS                    = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    Y_MAX_PERCENT_PARENT_WIDTH      = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_1_0_0_0_0000_00_00_0000_00_00_0,

    LIMIT_CHILDREN_NONE             = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    LIMIT_CHILDREN_CLIP             = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_01_0_0_0_0_0000_00_00_0000_00_00_0,
    LIMIT_CHILDREN_FORCE_MAX        = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_10_0_0_0_0_0000_00_00_0000_00_00_0,
    //LIMIT_CHILDREN_UNUSED         = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_11_0_0_0_0_0000_00_00_0000_00_00_0,

    SPACING_TAKE_SPACE              = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    SPACING_IGNORE                  = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_1_00_0_0_0_0_0000_00_00_0000_00_00_0,

    PADDING_DIRECT                  = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    PADDING_REF                     = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_1_0_00_0_0_0_0_0000_00_00_0000_00_00_0,

    CHILD_GAP_DIRECT                = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    CHILD_GAP_REF                   = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_1_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,

    X_SIZE_DIRECT                   = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    X_SIZE_REF                      = 0b0000000000000000000000000000000_0_0_0_0_0_0_1_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,

    Y_SIZE_DIRECT                   = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    Y_SIZE_REF                      = 0b0000000000000000000000000000000_0_0_0_0_0_1_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,

    X_OFFSET_DIRECT                 = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    X_OFFSET_REF                    = 0b0000000000000000000000000000000_0_0_0_0_1_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,

    Y_OFFSET_DIRECT                 = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    Y_OFFSET_REF                    = 0b0000000000000000000000000000000_0_0_0_1_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,

    LIMIT_X_DIRECT                  = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    LIMIT_X_REF                     = 0b0000000000000000000000000000000_0_0_1_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,

    LIMIT_Y_DIRECT                  = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    LIMIT_Y_REF                     = 0b0000000000000000000000000000000_0_1_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    
    UPDATE_INCLUDE                  = 0b0000000000000000000000000000000_0_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    UPDATE_IGNORE                   = 0b0000000000000000000000000000000_1_0_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
},  
enum(u32) {
    FREE           = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_1,
    X_SIZE         = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_11_0,
    Y_SIZE         = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_11_00_0,
    LAYOUT         = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_1111_00_00_0,
    X_OFFSET       = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_11_0000_00_00_0,
    Y_OFFSET       = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_0_0_0_0000_11_00_0000_00_00_0,
    PARENT_ANCHOR  = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_0_0_0_1111_00_00_0000_00_00_0,
    X_MIN          = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_0_0_1_0000_00_00_0000_00_00_0,
    X_MAX          = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_0_1_0_0000_00_00_0000_00_00_0,
    Y_MIN          = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_0_1_0_0_0000_00_00_0000_00_00_0,
    Y_MAX          = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_00_1_0_0_0_0000_00_00_0000_00_00_0,
    LIMIT_CHILDREN = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_0_11_0_0_0_0_0000_00_00_0000_00_00_0,
    SPACING        = 0b000000000000000000000000000000000_0_0_0_0_0_0_0_1_00_0_0_0_0_0000_00_00_0000_00_00_0,
    PADDING        = 0b000000000000000000000000000000000_0_0_0_0_0_0_1_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    CHILD_GAP      = 0b000000000000000000000000000000000_0_0_0_0_0_1_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    SIZE           = 0b000000000000000000000000000000000_0_0_0_0_1_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    OFFSET         = 0b000000000000000000000000000000000_0_0_0_1_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    LIMIT_X        = 0b000000000000000000000000000000000_0_0_1_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    LIMIT_Y        = 0b000000000000000000000000000000000_0_1_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
    UPDATE         = 0b000000000000000000000000000000000_1_0_0_0_0_0_0_0_00_0_0_0_0_0000_00_00_0000_00_00_0,
});
// zig fmt: on

pub const LayoutManagerSettings = struct {
    panel_id_type: type = u16,
    reference_id_type: type = u16,
    dimension_type: type = f32,
    padding_dimension_type: type = u8,
    gap_dimension_type: type = u8,
    z_index_type: type = u16,
    z_index_child_growth: ZIndexChildGrowth = .{ .DEPTH_ADD_INT = 1 },
    panel_list_options: PanelListOptions = .{},
    panel_allocator: *const Allocator,
    child_id_list_options: PanelListOptions = .{},
    child_id_allocator: *const Allocator,

    pub inline fn default(comptime allocator_ptr: *const Allocator) LayoutManagerSettings {
        return LayoutManagerSettings{
            .panel_allocator = allocator_ptr,
        };
    }
};

pub const ZIndexChildGrowthKind = enum(u8) {
    DEPTH_ADD_INT,
    DEPTH_ADD_FLOAT,
    DEPTH_MULTIPLY_INT,
    DEPTH_MULTIPLY_FLOAT,
    DEPTH_POWER_INT,
    DEPTH_POWER_FLOAT,
};

pub const ZIndexChildGrowth = union(ZIndexChildGrowthKind) {
    DEPTH_ADD_INT: comptime_int,
    DEPTH_ADD_FLOAT: comptime_float,
    DEPTH_MULTIPLY_INT: comptime_int,
    DEPTH_MULTIPLY_FLOAT: comptime_float,
    DEPTH_POWER_INT: comptime_int,
    DEPTH_POWER_FLOAT: comptime_float,
};

pub const PanelListOptions = struct {
    alignment: ?u29 = null,
    alloc_error_behavior: AllocErrorBehavior = if (build.mode == .Debug or build.mode == .ReleaseSafe) .ALLOCATION_ERRORS_PANIC else .ALLOCATION_ERRORS_ARE_UNREACHABLE,
    growth_model: GrowthModel = .GROW_BY_50_PERCENT,
    secure_wipe_bytes: bool = false,
};

pub fn define_layout_manager(comptime settings: LayoutManagerSettings) type {
    assert_with_reason(Types.type_is_unsigned_int(settings.panel_id_type), @src(), "`settings.panel_id_type` must be an unsigned integer type, got type `{s}`", .{@typeName(settings.panel_id_type)});
    assert_with_reason(Types.type_is_unsigned_int(settings.reference_id_type), @src(), "`settings.reference_id_type` must be an unsigned integer type, got type `{s}`", .{@typeName(settings.panel_id_type)});
    assert_with_reason(Types.type_is_numeric(settings.padding_dimension_type), @src(), "`settings.padding_type` must be a numeric type, got type `{s}`", .{@typeName(settings.padding_dimension_type)});
    assert_with_reason(Types.type_is_numeric(settings.gap_dimension_type), @src(), "`settings.gap_type` must be a numeric type, got type `{s}`", .{@typeName(settings.gap_dimension_type)});
    assert_with_reason(Types.type_is_numeric(settings.dimension_type), @src(), "`settings.dimension_type` must be a numeric type, got type `{s}`", .{@typeName(settings.dimension_type)});
    assert_with_reason(Types.type_is_numeric(settings.z_index_type), @src(), "`settings.z_index_type` must be a numeric type, got type `{s}`", .{@typeName(settings.z_index_type)});
    assert_with_reason(Types.type_is_struct(settings.user_state_type) or Types.type_is_void(settings.user_state_type), @src(), "`settings.user_state_type` must be a struct type or void, got type `{s}`", .{@typeName(settings.user_state_type)});
    if (Types.type_is_int(settings.z_index_type)) {
        const union_tag = Types.union_tag(settings.z_index_child_growth);
        assert_with_reason(Utils.matches_any(ZIndexChildGrowthKind, union_tag, &.{ .DEPTH_ADD_INT, .DEPTH_MULTIPLY_INT, .DEPTH_POWER_INT }), @src(), "`settings.z_index_child_growth` must indicate an integer growth mode when `settings.z_index_child_growth` is an integer type, got `.{s}`", .{@tagName(union_tag)});
    } else if (Types.type_is_float(settings.z_index_type)) {
        const union_tag = Types.union_tag(settings.z_index_child_growth);
        assert_with_reason(Utils.matches_any(ZIndexChildGrowthKind, union_tag, &.{ .DEPTH_ADD_FLOAT, .DEPTH_MULTIPLY_FLOAT, .DEPTH_POWER_FLOAT }), @src(), "`settings.z_index_child_growth` must indicate a float growth mode when `settings.z_index_child_growth` is a float type, got `.{s}`", .{@tagName(union_tag)});
    }
    return struct {
        const Self = @This();

        pub const T_DIM = settings.dimension_type;
        pub const T_PAD = settings.padding_dimension_type;
        pub const T_GAP = settings.gap_dimension_type;
        pub const T_PANEL_ID = settings.panel_id_type;
        pub const T_REF_ID = settings.reference_id_type;
        pub const T_ZIDX = settings.z_index_type;

        pub const T_POS_MAX = Vec.MAX;

        pub const Vec = Vec2.define_vec2_type(T_DIM);
        pub const Rect = Rect2.define_rect2_type(T_DIM);
        pub const AABB = AABB2.define_aabb2_type(T_DIM);

        const LIST_OPTS = ListDef.ListOptions{
            .alignment = settings.panel_list_options.alignment,
            .alloc_error_behavior = settings.panel_list_options.alloc_error_behavior,
            .element_type = Panel,
            .growth_model = settings.panel_list_options.growth_model,
            .index_type = T_PANEL_ID,
            .secure_wipe_bytes = settings.panel_list_options.secure_wipe_bytes,
        };

        pub const PanelList = ListDef.define_static_allocator_list_type(LIST_OPTS, settings.panel_allocator);

        pub const Panel = struct {
            flags: PanelFlags = PanelFlags.blank(),
            parent: PanelID = PanelID.NULL,
            children: ?[]PanelID = null,
            padding: Padding = Padding.new_ref(RefID.NULL),
            child_gaps: ChildGaps = ChildGaps.new_ref(RefID.NULL),
            size_x: Dimension = Dimension.new_ref(RefID.NULL),
            size_y: Dimension = Dimension.new_ref(RefID.NULL),
            offset_x: Dimension = Dimension.new_ref(RefID.NULL),
            offset_y: Dimension = Dimension.new_ref(RefID.NULL),
            min_x: Dimension = Dimension.new_ref(RefID.NULL),
            max_x: Dimension = Dimension.new_ref(RefID.NULL),
            min_y: Dimension = Dimension.new_ref(RefID.NULL),
            max_y: Dimension = Dimension.new_ref(RefID.NULL),
            own_id: PanelID = PanelID.NULL,
            z_index: T_ZIDX,
        };

        pub const PaddingDirect = packed struct {
            left: T_PAD = 0,
            right: T_PAD = 0,
            top: T_PAD = 0,
            bottom: T_PAD = 0,
        };

        pub const Padding = union {
            direct: PaddingDirect,
            ref: RefID,

            pub inline fn new_ref(ref: RefID) Padding {
                return Padding{ .ref = ref };
            }
            pub inline fn new_direct(padding: PaddingDirect) Padding {
                return Padding{ .direct = padding };
            }
        };

        pub const Dimension = union {
            direct: T_DIM,
            ref: RefID,

            pub inline fn new_ref(ref: RefID) Dimension {
                return Dimension{ .ref = ref };
            }
            pub inline fn new_direct(size: T_DIM) Dimension {
                return Dimension{ .direct = size };
            }
        };

        pub const ChildGapsDirect = packed struct {
            horizontal: T_GAP = 0,
            vertical: T_GAP = 0,
        };

        pub const ChildGaps = union {
            direct: ChildGapsDirect,
            ref: RefID,

            pub inline fn new_ref(ref: RefID) ChildGaps {
                return ChildGaps{ .ref = ref };
            }
            pub inline fn new_direct(gaps: ChildGapsDirect) ChildGaps {
                return ChildGaps{ .direct = gaps };
            }
        };

        pub const LimitXDirect = packed struct {
            min: T_DIM = 0,
            max: T_DIM = T_POS_MAX,
        };

        pub const LimitX = union {
            direct: LimitXDirect,
            ref: RefID,

            pub inline fn new_ref(ref: RefID) LimitX {
                return LimitX{ .ref = ref };
            }
            pub inline fn new_direct(limit: LimitXDirect) LimitX {
                return LimitX{ .direct = limit };
            }
        };

        pub const LimitYDirect = packed struct {
            min: T_DIM = 0,
            max: T_DIM = T_POS_MAX,
        };

        pub const LimitY = union {
            direct: LimitYDirect,
            ref: RefID,

            pub inline fn new_ref(ref: RefID) LimitY {
                return LimitY{ .ref = ref };
            }
            pub inline fn new_direct(limit: LimitYDirect) LimitY {
                return LimitY{ .direct = limit };
            }
        };

        pub const PanelID = struct {
            id: T_PANEL_ID = NULL.id,

            pub const NULL = PanelID{ .id = math.maxInt(T_PANEL_ID) };

            pub inline fn new(id: T_PANEL_ID) PanelID {
                return PanelID{ .id = id };
            }

            pub inline fn is_null(self: PanelID) bool {
                return self.id == NULL.id;
            }

            pub inline fn equals(self: PanelID, other: PanelID) bool {
                return self.id == other.id;
            }
        };

        pub const RefID = struct {
            id: T_REF_ID = NULL.id,

            pub const NULL = RefID{ .id = math.maxInt(T_REF_ID) };

            pub inline fn new(id: T_REF_ID) RefID {
                return RefID{ .id = id };
            }

            pub inline fn is_null(self: RefID) bool {
                return self.id == NULL.id;
            }

            pub inline fn equals(self: RefID, other: RefID) bool {
                return self.id == other.id;
            }
        };
    };
}
