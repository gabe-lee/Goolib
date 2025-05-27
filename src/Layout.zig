//! TODO Documentation
//! #### License: Zlib
//! #### Referenced Work Licenses:
//! - CLAY: (Zlib) https://github.com/nicbarker/clay/blob/main/LICENSE.md

// // zlib license
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

// IN ADDITION:
// THIS CODE WAS PRODUCED BY REFERENCING AND MANUALLY TRANSLATING THE CLAY UI
// LIBRARY (https://github.com/nicbarker/clay/tree/main)
// EVEN THOUGH THIS CODE IS RE-WRITTEN AND NOT INCLUDED AS A DEPENDANCY,
// IN THE INTERESTS OF FAIRNESS AND GRATITUDE TOWARD THE ORIGINAL AUTHOR,
// THIS CODE SHOULD BE CONSIDERED AS ALSO LARGELY THEIR WORK:

// zlib/libpng license
//
// Copyright (c) 2024 Nic Barker
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

const Root = @import("./_root.zig");
const Rect2 = Root.Rect2;
const AABB2 = Root.AABB2;
const Vec2 = Root.Vec2;
const Types = Root.Types;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

pub const LayoutDirection = enum(u8) {
    LEFT_TO_RIGHT_THEN_TOP_TO_BOTTOM,
    RIGHT_TO_LEFT_THEN_TOP_TO_BOTTOM,
    LEFT_TO_RIGHT_THEN_BOTTOM_TO_TOP,
    RIGHT_TO_LEFT_THEN_BOTTOM_TO_TOP,
};

pub const Align_X = enum(u8) {
    ALIGN_X_LEFT,
    ALIGN_X_CENTER,
    ALIGN_X_RIGHT,
};

pub const Align_Y = enum(u8) {
    ALIGN_Y_LEFT,
    ALIGN_Y_CENTER,
    ALIGN_Y_RIGHT,
};

pub const SizeKind = enum(u8) {
    FIT,
    EXPAND,
    PERCENT,
    FIXED,
};

pub const SizeLimitKind = enum(u8) {
    PERCENT,
    PIXELS,
};

pub const FloatingAttachPoint = enum(u8) {
    TOP_LEFT,
    TOP_CENTER,
    TOP_RIGHT,
    MIDDLE_LEFT,
    MIDDLE_CENTER,
    MIDDLE_RIGHT,
    BOT_LEFT,
    BOT_CENTER,
    BOT_RIGHT,
};

pub const FloatingAttachMode = enum(u8) {
    NONE,
    ATTACH_TO_PARENT,
    ATTACH_TO_ROOT,
};

pub const FloatingClipMode = enum(u8) {
    NONE,
    CLIP_TO_PARENT,
};

pub const ChildAlignment = struct {
    x: Align_X = .ALIGN_X_CENTER,
    y: Align_Y = .ALIGN_Y_CENTER,
};

pub const FloatingAttachmentLocation = struct {
    child_attach_point: FloatingAttachPoint = .TOP_LEFT,
    parent_attach_point: FloatingAttachPoint = .BOT_LEFT,
};

pub const LayoutSystemSettings = struct {
    element_id_type: type = u16,
    dimension_type: type = f32,
    padding_type: type = u8,
    gap_type: type = u8,
    border_type: type = u8,
    z_index_type: type = u16,
    user_state_type: type,
};

pub fn define_layout_system(comptime settings: LayoutSystemSettings) type {
    assert_with_reason(Types.type_is_unsigned_int(settings.element_id_type), @src(), @This(), "`settings.element_id_type` must be an unsigned integer type, got type `{s}`", .{@typeName(settings.element_id_type)});
    assert_with_reason(Types.type_is_numeric(settings.padding_type), @src(), @This(), "`settings.padding_type` must be a numeric type, got type `{s}`", .{@typeName(settings.padding_type)});
    assert_with_reason(Types.type_is_numeric(settings.border_type), @src(), @This(), "`settings.border_type` must be a numeric type, got type `{s}`", .{@typeName(settings.border_type)});
    assert_with_reason(Types.type_is_numeric(settings.gap_type), @src(), @This(), "`settings.gap_type` must be a numeric type, got type `{s}`", .{@typeName(settings.gap_type)});
    assert_with_reason(Types.type_is_numeric(settings.dimension_type), @src(), @This(), "`settings.dimension_type` must be a numeric type, got type `{s}`", .{@typeName(settings.dimension_type)});
    assert_with_reason(Types.type_is_numeric(settings.z_index_type), @src(), @This(), "`settings.z_index_type` must be a numeric type, got type `{s}`", .{@typeName(settings.z_index_type)});
    assert_with_reason(Types.type_is_struct(settings.user_state_type), @src(), @This(), "`settings.user_state_type` must be a struct type, got type `{s}`", .{@typeName(settings.user_state_type)});
    return struct {
        const Self = @This();

        pub const T_POS = settings.dimension_type;
        pub const T_PAD = settings.padding_type;
        pub const T_GAP = settings.gap_type;
        pub const T_BORDER = settings.border_type;
        pub const T_ID = settings.element_id_type;
        pub const T_ZIDX = settings.z_index_type;
        pub const T_STATE = settings.user_state_type;

        pub const Vec = Vec2.define_vec2_type(T_POS);
        pub const Rect = Rect2.define_rect2_type(T_POS);
        pub const AABB = AABB2.define_aabb2_type(T_POS);

        pub const ElementID = struct {
            id: T_ID = NULL.id,

            pub const NULL = ElementID{ .id = math.maxInt(T_ID) };

            pub inline fn new(id: T_ID) ElementID {
                return ElementID{ .id = id };
            }

            pub inline fn is_null(self: ElementID) bool {
                return self.id == NULL.id;
            }

            pub inline fn equals(self: ElementID, other: ElementID) bool {
                return self.id == other.id;
            }
        };

        pub const ElementSize = struct {
            size: Vec = .ZERO_ZERO,
            min: Vec = .MIN_MIN,
            max: Vec = .MAX_MAX,
            size_x_kind: SizeKind = .FIT,
            size_x_limit: SizeLimitKind = .PIXELS,
            size_y_kind: SizeKind = .FIT,
            size_y_limit: SizeLimitKind = .PIXELS,
        };

        pub const Padding = struct {
            left: T_PAD,
            right: T_PAD,
            up: T_PAD,
            down: T_PAD,
        };

        pub const ElementLayout = struct {
            size: ElementSize = .{},
            padding: Padding = .{},
            child_gap: T_PAD,
            child_align: ChildAlignment = .{},
            layout_direction: LayoutDirection = .LEFT_TO_RIGHT_THEN_TOP_TO_BOTTOM,
        };

        pub const FloatingElementLayout = struct {
            offset: Vec = .ZERO_ZERO,
            expand: Vec = .ZERO_ZERO,
            parent_id: ElementID = .NULL,
            z_index: T_ZIDX = 0,
            attach_location: FloatingAttachmentLocation = .{},
            attach_mode: FloatingAttachMode = .ATTACH_TO_ROOT,
            clip_mode: FloatingClipMode = .NONE,
        };

        pub const ElementClipConfig = struct {
            clip_x: bool = true,
            clip_y: bool = true,
            offset_children: Vec = .ZERO_ZERO,
        };

        pub const ElementBorders = struct {
            left: T_BORDER = 2,
            right: T_BORDER = 2,
            top: T_BORDER = 2,
            bottom: T_BORDER = 2,
            bewteen_children_x: T_BORDER = 2,
            bewteen_children_y: T_BORDER = 2,
        };

        pub const ElementBorderColors = struct {
            //CHECKPOINT
        };
    };
}
