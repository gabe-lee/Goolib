//! //TODO Documentation
//! #### Credits
//! This module is inspired by the Clay layout library (https://github.com/nicbarker/clay)
//! under the zlib/libpng license (https://github.com/nicbarker/clay/blob/main/LICENSE.md),
//! but the code and process is entirely reinvented from scratch.
//!
//! It has a more narrow focus on ONLY layout and is rendering/mouse agnostic,
//! and is more flexible in how the hierarchy can be built by relying on a `LayoutRequester`,
//! interface. This allows it to be more flexibly integrated into any user workflow, at the cost
//! of a bit of user-end setup for the interfaces. The layout evaluation process is immediate-mode,
//! but the user can choose to retain a list of `LayoutRequester` info or build one on each frame as needed.
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

/// std imports
const Allocator = std.mem.Allocator;
const DEBUG = std.debug.print;
const math = std.math;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Type = Root.Types;
const Math = Root.Math;
const KindInfo = Type.KindInfo;
const Assert = Root.Assert;
const Utils = Root.Utils;
const CommonTypes = Root.CommonTypes;
const Test = Root.Testing;
const DummyAlloc = Root.DummyAllocator;
const dummy_alloc = DummyAlloc.allocator_panic_free_noop;

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;
const kind_info = KindInfo.get_kind_info;

const SUPER_DEBUG = true;

pub const LayoutDirection = enum(u3) {
    LEFT_TO_RIGHT__TOP_TO_BOTTOM = 0b000,
    LEFT_TO_RIGHT__BOTTOM_TO_TOP = 0b001,
    RIGHT_TO_LEFT__TOP_TO_BOTTOM = 0b010,
    RIGHT_TO_LEFT__BOTTOM_TO_TOP = 0b011,
    TOP_TO_BOTTOM__LEFT_TO_RIGHT = 0b100,
    BOTTOM_TO_TOP__LEFT_TO_RIGHT = 0b101,
    TOP_TO_BOTTOM__RIGHT_TO_LEFT = 0b110,
    BOTTOM_TO_TOP__RIGHT_TO_LEFT = 0b111,

    pub inline fn primary_axis(self: LayoutDirection) Axis {
        return @enumFromInt(@as(u1, @intCast((@intFromEnum(self) >> 2) & 0b1)));
    }
    pub inline fn secondary_axis(self: LayoutDirection) Axis {
        return @enumFromInt(@as(u1, 1) ^ @as(u1, @intCast((@intFromEnum(self) >> 2) & 0b1)));
    }
    // pub inline fn relative_to_axis(self: LayoutDirection, comptime AXIS: Axis) AxisRelative {
    //     switch (comptime AXIS) {
    //         .X => switch (self.primary_dir()) {
    //             .X => return .SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS,
    //             .Y => return .OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS,
    //         },
    //         .Y => switch (self.primary_dir()) {
    //             .Y => return .SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS,
    //             .X => return .OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS,
    //         },
    //     }
    // }
    // pub inline fn relative_to_current_and_driving_axis(self: LayoutDirection, comptime AXIS: Axis, comptime IS_DRIVING: bool) AxisRelativeDriving {
    //     return self.relative_to_axis(AXIS).with_driving(IS_DRIVING);
    // }

    pub inline fn x_dir(self: LayoutDirection) XDir {
        return @enumFromInt(@as(u1, @intCast((@intFromEnum(self) >> 1) & 0b1)));
    }
    pub inline fn y_dir(self: LayoutDirection) YDir {
        return @enumFromInt(@as(u1, @intCast(@intFromEnum(self) & 0b1)));
    }
};

// pub const AxisRelative = enum(u1) {
//     SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS = 0b0,
//     OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS = 0b1,

//     pub inline fn with_driving(self: AxisRelative, comptime IS_DRIVING: bool) AxisRelativeDriving {
//         const raw: u2 = @as(u2, @intCast(@intFromEnum(self)));
//         if (comptime !IS_DRIVING) {
//             raw &= 0b10;
//         }
//         return @enumFromInt(raw);
//     }
// };
// pub const AxisRelativeDriving = enum(u2) {
//     SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS_DRIVING_PHASE = 0b00,
//     SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS_SECONDARY_PHASE = 0b10,
//     OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS_DRIVING_PHASE = 0b01,
//     OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS_SECONDARY_PHASE = 0b11,
// };

pub const Axis = Root.Vec2.Axis;

// pub const HorizontalDirection = enum(u1) {
//     LEFT_TO_RIGHT = 0b0,
//     RIGHT_TO_LEFT = 0b1,
// };
// const VerticalDirection = enum(u1) {
//     TOP_TO_BOTTOM = 0b0,
//     BOTTOM_TO_TOP = 0b1,
// };

const Align = enum(u2) {
    START = 0,
    MIDDLE = 1,
    END = 2,
    JUSTIFY = 3,
};

pub const AlignX = enum(u2) {
    LEFT = 0,
    MIDDLE = 1,
    RIGHT = 2,
    JUSTIFY = 3,

    inline fn generic(self: AlignX) Align {
        return @enumFromInt(@intFromEnum(self));
    }
};

pub const AlignY = enum(u2) {
    TOP = 0,
    CENTER = 1,
    BOTTOM = 2,
    JUSTIFY = 3,

    inline fn generic(self: AlignY) Align {
        return @enumFromInt(@intFromEnum(self));
    }
};

pub const SizeMode = enum(u2) {
    FIT,
    GROW,
    PERCENT,
    FIXED,
};

pub const ChildAlignment = struct {
    x: AlignX = .LEFT,
    y: AlignY = .TOP,

    pub inline fn x_y(x: AlignX, y: AlignY) ChildAlignment {
        return ChildAlignment{
            .x = x,
            .y = y,
        };
    }

    pub inline fn get(self: ChildAlignment, comptime AXIS: Axis) Align {
        switch (comptime AXIS) {
            .X => return self.x.generic(),
            .Y => return self.y.generic(),
        }
    }
};

pub const GrowMode = enum(u2) {
    EXACT,
    GROW,
};

pub const AttachPoint = enum(u4) {
    TOP_LEFT,
    TOP_MIDDLE,
    TOP_RIGHT,
    CENTER_LEFT,
    CENTER_MIDDLE,
    CENTER_RIGHT,
    BOTTOM_LEFT,
    BOTTOM_MIDDLE,
    BOTTOM_RIGHT,
};

pub const SiblingEdge = struct {
    pub const LEFT: u4 = 1 << 0;
    pub const RIGHT: u4 = 1 << 1;
    pub const TOP: u4 = 1 << 2;
    pub const BOTTOM: u4 = 1 << 3;
};

pub const FloatingAttachment = struct {
    parent: AttachPoint = .TOP_LEFT,
    child: AttachPoint = .TOP_LEFT,
};

pub const Floating = struct {
    /// Whether the element takes part in the layout heirarchy,
    /// or merely uses the parent position and 'floats'
    /// above (or below) the parent
    is_floating: bool = false,
    /// The attatchment points for the floating element.
    /// If `final_position_offset` is 0, the parent and child
    /// will visually touch at these points.
    attach: FloatingAttachment = .{},

    pub inline fn not_floating() Floating {
        return Floating{};
    }
    pub inline fn floating(parent_attach: AttachPoint, child_attach: AttachPoint) Floating {
        return Floating{
            .is_floating = true,
            .attach = .{
                .parent = parent_attach,
                .child = child_attach,
            },
        };
    }
};

const OffsetMode = enum(u2) {
    ABSOLUTE,
    PERCENT_OF_PARENT_SIZE,
    PERCENT_OF_SELF_SIZE,
};
const MaxMode = enum(u1) {
    ABSOLUTE,
    PERCENT_OF_PARENT_SIZE,
};

const Dir = enum(u1) {
    FORWARD,
    REVERSE,
};
const XDir = enum(u1) {
    LEFT_TO_RIGHT,
    RIGHT_TO_LEFT,
};
const YDir = enum(u1) {
    TOP_TO_BOTTOM,
    BOTTOM_TO_TOP,
};

const PackedLayoutInfo = packed struct(u32) {
    float_parent_attach: AttachPoint = .TOP_LEFT, // 4 = 4
    float_self_attach: AttachPoint = .TOP_LEFT, // 4 = 8
    children_axis_line_local_align: AxisLineLocalAlign = .INHERIT, // 2 = 10
    self_axis_line_local_align: AxisLineLocalAlign = .INHERIT, // 2 = 12
    child_align_x: AlignX = .LEFT, // 2 = 14
    child_align_y: AlignY = .TOP, // 2 = 16
    offset_mode_x: OffsetMode = .ABSOLUTE, // 2 = 18
    offset_mode_y: OffsetMode = .ABSOLUTE, // 2 = 20
    growable_x: bool = false, // 1 = 21
    growable_y: bool = false, // 1 = 22
    primary_child_axis: Axis = .X, // 1 = 23
    child_layout_dir_x: XDir = .LEFT_TO_RIGHT, // 1 = 24
    child_layout_dir_y: YDir = .TOP_TO_BOTTOM, // 1 = 25
    max_mode_x: MaxMode = .ABSOLUTE, // 1 = 26
    max_mode_y: MaxMode = .ABSOLUTE, // 1 = 27
    _unused: u5 = 0, // 5 = 32
};

const AxisStage = struct {
    AXIS: Axis,
    STAGE: LayoutStage,

    pub inline fn new(comptime AXIS: Axis, comptime STAGE: LayoutStage) AxisStage {
        return AxisStage{
            .AXIS = AXIS,
            .STAGE = STAGE,
        };
    }
};

const CombineMode = enum {
    ADD_MIN_SIZE_AND_GAP,
    UPDATE_MAX_OF_MIN_SIZE,
};
const WrapMode = enum {
    NO_WRAP,
    ALLOW_WRAP,
};

const AxisLinePass = enum {
    FIRST_PASS,
    SECOND_PASS,
};

const HANDLE_COMBINE_STAGE = enum {
    FINISH_LINE_AND_POSSIBLY_START_NEW,
    FINISH_LINE_AND_END,
    ADD_CURRENT_CHILD_TO_CURRENT_LINE,
};

const LayoutStage = enum(u1) {
    PRIMARY_STAGE = 0,
    SECONDARY_STAGE = 1,
};

pub const AxisLineLocalAlign = enum(u2) {
    INHERIT = 0,
    TOP_OR_LEFT = 1,
    CENTER = 2,
    BOTTOM_OR_RIGHT = 3,
};

const LocalAlign = enum(u2) {
    START = 1,
    CENTER = 2,
    END = 3,

    fn eval(parent_secondary_align: Align, parent_child_ALLA: AxisLineLocalAlign, child_ALLA: AxisLineLocalAlign) LocalAlign {
        switch (child_ALLA) {
            .INHERIT => switch (parent_child_ALLA) {
                .INHERIT => switch (parent_secondary_align) {
                    .START, .JUSTIFY => return LocalAlign.START,
                    .MIDDLE => return LocalAlign.CENTER,
                    .END => return LocalAlign.END,
                },
                else => return @enumFromInt(@intFromEnum(parent_child_ALLA)),
            },
            else => return @enumFromInt(@intFromEnum(child_ALLA)),
        }
    }
};

pub fn DefineLayoutManager(comptime T_DIMENSION: type, comptime T_DIMENSION_SMALL: type, comptime T_IDX: type) type {
    return struct {
        pub const LayoutManager = @This();
        pub const AABB = Root.AABB2.define_aabb2_type(T_DIMENSION);
        pub const Pos = Root.Vec2.define_vec2_type(T_DIMENSION);
        pub const Size = Pos;
        const IDX = T_IDX;
        const T = T_DIMENSION;
        const T_SMALL = T_DIMENSION_SMALL;
        const MinSize_OR_FinalAABB = union {
            min_size: MinSize,
            final_aabb: AABB,

            pub fn new(min_x: T, min_y: T) MinSize_OR_FinalAABB {
                return MinSize_OR_FinalAABB{ .min_size = .{ .self = .new(min_x, min_y) } };
            }
        };
        const MinSize = struct {
            self: Size = .ZERO,
            children: Size = .ZERO,
        };
        const MaxSize_OR_FinalClipAABB = union {
            max_size: MaxSizeAndLayout,
            final_clip_aabb: AABB,

            pub fn new(max_x: T, max_y: T, layout_info: PackedLayoutInfo) MaxSize_OR_FinalClipAABB {
                return MaxSize_OR_FinalClipAABB{ .max_size = .{
                    .value = .new(max_x, max_y),
                    .layout = layout_info,
                    .next_this_pass = NULL_IDX,
                } };
            }
        };
        const MaxSizeAndLayout = struct {
            value: Size = .INF,
            next_this_pass: IDX = NULL_IDX,
            layout: PackedLayoutInfo = .{},

            comptime {
                assert_with_reason_debug_only(@sizeOf(MaxSizeAndLayout) <= @sizeOf(AABB), null, "MaxSize must be smaller or equal size to AABB", .{});
            }
        };
        const NULL_IDX: IDX = math.maxInt(IDX);
        const Traverse = Utils.Traverser.IndexBasedMultiFirstChildNextSiblingTraverser(LayoutElement, IDX, NULL_IDX, &.{ "first_contained_child", "first_floating_child" }, "next_sibling");
        pub const Elems = Traverse.Elems;
        pub const Stack = Traverse.Stack;
        pub const StackFrame = Traverse.StackFrame;
        const AllowedPaths = Traverse.AllowedPaths;
        const TraverseError = Utils.Traverser.Error;
        const MemRealloc = Utils.Traverser.MemRealloc;
        const StackReallocator = Traverse.StackReallocator;
        pub const Gap = struct {
            y: T_SMALL,
            x: T_SMALL,

            pub inline fn uniform(gap: T_SMALL) Gap {
                return Gap{
                    .y = gap,
                    .x = gap,
                };
            }

            pub inline fn vert_horiz(gap_vert: T_SMALL, gap_horiz: T_SMALL) Gap {
                return Gap{
                    .y = gap_vert,
                    .x = gap_horiz,
                };
            }

            pub inline fn x_gap(self: Gap) T {
                return num_cast(self.x, T);
            }
            pub inline fn total_x_gap(self: Gap, num_gaps: T) T {
                return num_cast(self.x, T) * num_gaps;
            }
            pub inline fn y_gap(self: Gap) T {
                return num_cast(self.y, T);
            }
            pub inline fn total_y_gap(self: Gap, num_gaps: T) T {
                return num_cast(self.y, T) * num_gaps;
            }
            pub fn get(self: Gap, comptime AXIS: Axis) T {
                switch (comptime AXIS) {
                    .X => {
                        return num_cast(self.x, T);
                    },
                    .Y => {
                        return num_cast(self.y, T);
                    },
                }
            }
            pub fn get_total(self: Gap, comptime AXIS: Axis, num_gaps: T) T {
                switch (comptime AXIS) {
                    .X => {
                        return num_cast(self.x, T) * num_gaps;
                    },
                    .Y => {
                        return num_cast(self.y, T) * num_gaps;
                    },
                }
            }
        };

        const Error = Utils.Alloc.AllocErr || TraverseError;
        const LayoutElement = struct {
            requester: LayoutRequester,
            _min_or_aabb: MinSize_OR_FinalAABB,
            _max_or_clip_aabb: MaxSize_OR_FinalClipAABB,
            final_position_offset: Pos = .ZERO,
            padding: Padding,
            child_gaps: Gap,
            first_contained_child: IDX = NULL_IDX,
            first_floating_child: IDX = NULL_IDX,
            first_axis_line: AxisLine = .{},
            num_contained_children: IDX = 0,
            num_axis_lines: IDX = 0,
            next_sibling: IDX = NULL_IDX,
            parent_idx: IDX,
            depth: IDX,
            is_floating: bool,
            clip_to_parent: bool,
            completely_clipped: bool = false,
            use_wrap_mode: bool,

            inline fn set_children_local_align(self: *LayoutElement, alla: AxisLineLocalAlign) void {
                self._max_or_clip_aabb.max_size.layout.children_axis_line_local_align = alla;
            }
            inline fn get_children_local_align(self: LayoutElement) AxisLineLocalAlign {
                return self._max_or_clip_aabb.max_size.layout.children_axis_line_local_align;
            }
            inline fn set_self_local_align(self: *LayoutElement, alla: AxisLineLocalAlign) void {
                self._max_or_clip_aabb.max_size.layout.self_axis_line_local_align = alla;
            }
            inline fn get_self_local_align(self: LayoutElement) AxisLineLocalAlign {
                return self._max_or_clip_aabb.max_size.layout.self_axis_line_local_align;
            }
            inline fn set_parent_float_attach(self: *LayoutElement, attach: AttachPoint) void {
                self._max_or_clip_aabb.max_size.layout.float_parent_attach = attach;
            }
            inline fn get_parent_float_attach(self: LayoutElement) AttachPoint {
                return self._max_or_clip_aabb.max_size.layout.float_parent_attach;
            }
            inline fn set_self_float_attach(self: *LayoutElement, attach: AttachPoint) void {
                self._max_or_clip_aabb.max_size.layout.float_self_attach = attach;
            }
            inline fn get_self_float_attach(self: LayoutElement) AttachPoint {
                return self._max_or_clip_aabb.max_size.layout.float_self_attach;
            }
            inline fn set_child_align(self: *LayoutElement, comptime AXIS: Axis, alignment: if (AXIS == .X) AlignX else AlignY) void {
                switch (comptime AXIS) {
                    .X => {
                        self._max_or_clip_aabb.max_size.layout.child_align_x = alignment;
                    },
                    .Y => {
                        self._max_or_clip_aabb.max_size.layout.child_align_y = alignment;
                    },
                }
            }
            inline fn get_child_align(self: *LayoutElement, comptime AXIS: Axis) if (AXIS == .X) AlignX else AlignY {
                switch (comptime AXIS) {
                    .X => {
                        return self._max_or_clip_aabb.max_size.layout.child_align_x;
                    },
                    .Y => {
                        return self._max_or_clip_aabb.max_size.layout.child_align_y;
                    },
                }
            }
            inline fn get_primary_child_axis(self: *LayoutElement) Axis {
                return self._max_or_clip_aabb.max_size.layout.primary_child_axis;
            }
            inline fn get_child_layout_dir(self: *LayoutElement, comptime AXIS: Axis) if (AXIS == .X) XDir else YDir {
                switch (comptime AXIS) {
                    .X => {
                        return self._max_or_clip_aabb.max_size.layout.child_layout_dir_x;
                    },
                    .Y => {
                        return self._max_or_clip_aabb.max_size.layout.child_layout_dir_y;
                    },
                }
            }
            inline fn get_next_growable_idx_this_pass(self: LayoutElement) IDX {
                return self._max_or_clip_aabb.max_size.next_this_pass;
            }
            inline fn set_next_growable_idx_this_pass(self: *LayoutElement, next: IDX) void {
                self._max_or_clip_aabb.max_size.next_this_pass = next;
            }
            pub inline fn has_children(self: LayoutElement) bool {
                return self.first_child != NULL_IDX;
            }
            inline fn add_to_min_self_size(self: *LayoutElement, comptime AXIS: Axis, val: T) void {
                self._min_or_aabb.min_size.self.set(AXIS, self._min_or_aabb.min_size.self.get(AXIS) + val);
            }
            inline fn add_to_min_self_size_limit_to_max_update_growable(self: *LayoutElement, comptime AXIS: Axis, val: T) void {
                self._min_or_aabb.min_size.self.set(AXIS, self._min_or_aabb.min_size.self.get(AXIS) + val);
                const max = self.get_max_size(AXIS);
                if (self._min_or_aabb.min_size.self.get(AXIS) >= max) {
                    self._min_or_aabb.min_size.self.set(AXIS, max);
                    self.set_growable_false(AXIS);
                }
            }
            inline fn set_min_size_self(self: *LayoutElement, comptime AXIS: Axis, val: T) void {
                self._min_or_aabb.min_size.self.set(AXIS, val);
            }
            inline fn set_min_size_self_limit_to_max_update_growable(self: *LayoutElement, comptime AXIS: Axis, val: T) void {
                const max = self.get_max_size(AXIS);
                if (val >= max) {
                    self._min_or_aabb.min_size.self.set(AXIS, max);
                    self.set_growable_false(AXIS);
                } else {
                    self._min_or_aabb.min_size.self.set(AXIS, val);
                }
            }
            inline fn reevaluate_growable_from_new_min_size(self: *LayoutElement, comptime AXIS: Axis) void {
                const max = self.get_max_size(AXIS);
                if (self.is_growable(AXIS) and self._min_or_aabb.min_size.self.get(AXIS) > max) {
                    self.set_growable_false(AXIS);
                    self.set_min_size_self(AXIS, max);
                }
            }
            inline fn get_min_size_self(self: LayoutElement, comptime AXIS: Axis) T {
                return self._min_or_aabb.min_size.self.get(AXIS);
            }
            inline fn update_min_size_with_children_min_size(self: *LayoutElement, comptime AXIS: Axis) void {
                self._min_or_aabb.min_size.self.set(AXIS, @max(self._min_or_aabb.min_size.self.get(AXIS), self._min_or_aabb.min_size.children.get(AXIS)));
            }
            inline fn add_to_min_children_size(self: *LayoutElement, comptime AXIS: Axis, val: T) void {
                self._min_or_aabb.min_size.children.set(AXIS, self._min_or_aabb.min_size.children.get(AXIS) + val);
            }
            inline fn update_max_of_min_children_size(self: *LayoutElement, comptime AXIS: Axis, val: T) void {
                self._min_or_aabb.min_size.children.set(AXIS, @max(self._min_or_aabb.min_size.children.get(AXIS), val));
            }
            inline fn get_min_children_size(self: LayoutElement, comptime AXIS: Axis) T {
                return self._min_or_aabb.min_size.children.get(AXIS);
            }
            inline fn get_offset_mode(self: LayoutElement, comptime AXIS: Axis) OffsetMode {
                switch (comptime AXIS) {
                    .X => return self._max_or_clip_aabb.max_size.layout.offset_mode_x,
                    .Y => return self._max_or_clip_aabb.max_size.layout.offset_mode_y,
                }
            }
            inline fn get_max_mode(self: LayoutElement, comptime AXIS: Axis) MaxMode {
                switch (comptime AXIS) {
                    .X => return self._max_or_clip_aabb.max_size.layout.max_mode_x,
                    .Y => return self._max_or_clip_aabb.max_size.layout.max_mode_y,
                }
            }
            inline fn set_max_size(self: *LayoutElement, comptime AXIS: Axis, val: T) void {
                self._max_or_clip_aabb.max_size.value.set(AXIS, val);
            }
            inline fn finalize_max_size(self: *LayoutElement, comptime AXIS: Axis, parent_space_for_children_on_axis: T) void {
                switch (self.get_max_mode(AXIS)) {
                    .ABSOLUTE => {},
                    .PERCENT_OF_PARENT_SIZE => {
                        const percent = self._max_or_clip_aabb.max_size.value.get(AXIS);
                        self.set_max_size(AXIS, parent_space_for_children_on_axis * percent);
                    },
                }
            }
            inline fn get_max_size(self: LayoutElement, comptime AXIS: Axis) T {
                return self._max_or_clip_aabb.max_size.value.get(AXIS);
            }
            inline fn is_growable(self: LayoutElement, comptime AXIS: Axis) bool {
                switch (comptime AXIS) {
                    .X => return self._max_or_clip_aabb.max_size.layout.growable_x,
                    .Y => return self._max_or_clip_aabb.max_size.layout.growable_y,
                }
            }
            inline fn set_growable_true(self: *LayoutElement, comptime AXIS: Axis) void {
                switch (comptime AXIS) {
                    .X => {
                        self._max_or_clip_aabb.max_size.layout.growable_x = true;
                    },
                    .Y => {
                        self._max_or_clip_aabb.max_size.layout.growable_y = true;
                    },
                }
            }
            inline fn set_growable_false(self: *LayoutElement, comptime AXIS: Axis) void {
                switch (comptime AXIS) {
                    .X => {
                        self._max_or_clip_aabb.max_size.layout.growable_x = false;
                    },
                    .Y => {
                        self._max_or_clip_aabb.max_size.layout.growable_y = false;
                    },
                }
            }
            inline fn set_final_aabb(self: *LayoutElement, parent_abs: Pos) void {
                const final_size = self._min_or_aabb.min_size.self;
                const abs_pos = parent_abs.add(self.final_position_offset);
                self._min_or_aabb.final_aabb = AABB.new_from_pos_size(abs_pos, final_size);
            }
            inline fn set_clip_aabb(self: *LayoutElement, parent_clip: AABB) void {
                const overlap_aabb, const not_completely_clipped = self.get_aabb().overlap_area_and_overlap_area_positive(parent_clip);
                self._max_or_clip_aabb.final_clip_aabb = overlap_aabb;
                self.completely_clipped = !not_completely_clipped;
            }
            pub inline fn get_aabb(self: LayoutElement) AABB {
                return self._min_or_aabb.final_aabb;
            }
            pub inline fn get_clip_aabb(self: LayoutElement) AABB {
                return self._max_or_clip_aabb.final_clip_aabb;
            }
            pub inline fn get_absolute_pos(self: *LayoutElement) Pos {
                return self._min_or_aabb.final_aabb.get_min_point();
            }
            pub inline fn get_center_point_component(self: *LayoutElement, comptime AXIS: Axis) T {
                return self._min_or_aabb.final_aabb.get_center_point_component(AXIS);
            }
            pub inline fn get_absolute_pos_end(self: *LayoutElement) Pos {
                return self._min_or_aabb.final_aabb.get_max_point();
            }
            pub inline fn get_final_size(self: *LayoutElement) Size {
                return self._min_or_aabb.final_aabb.get_max_point().subtract(self._min_or_aabb.final_aabb.get_min_point());
            }
            inline fn get_last_contained_child(self: LayoutElement) IDX {
                return self.first_axis_line.next_line;
            }
            inline fn set_last_contained_child(self: *LayoutElement, idx: IDX) void {
                self.first_axis_line.next_line = idx;
            }
            inline fn get_last_floating_child(self: LayoutElement) IDX {
                return self.first_axis_line.next_growable_line_this_pass;
            }
            inline fn set_last_floating_child(self: *LayoutElement, idx: IDX) void {
                self.first_axis_line.next_growable_line_this_pass = idx;
            }
            inline fn clear_last_contained_and_last_floating_child_cache(self: *LayoutElement) void {
                self.first_axis_line.next_line = NULL_IDX;
                self.first_axis_line.next_growable_line_this_pass = NULL_IDX;
            }
        };
        pub const SecondarySizeResult = struct {
            min: T,
            max: T,
        };
        pub const SizeCheckInfo = struct {
            driving_axis: Axis,
            driving_size: T,
            old_secondary_min: T,
            old_secondary_max: T,

            pub inline fn preserve_aspect_ratio_x_and_y(self: SizeCheckInfo, x: T, y: T) SecondarySizeResult {
                const ratio_x_to_y = x / y;
                return self.preserve_aspect_ratio_x_to_y(ratio_x_to_y);
            }
            pub inline fn preserve_aspect_ratio_x_to_y(self: SizeCheckInfo, ratio_x_to_y: T) SecondarySizeResult {
                switch (self.driving_axis) {
                    .X => {
                        const val = self.driving_size / ratio_x_to_y;
                        return SecondarySizeResult{
                            .min = val,
                            .max = val,
                        };
                    },
                    .Y => {
                        const val = self.driving_size * ratio_x_to_y;
                        return SecondarySizeResult{
                            .min = val,
                            .max = val,
                        };
                    },
                }
            }
            pub inline fn unchanged_secondary(self: SizeCheckInfo) SecondarySizeResult {
                return SecondarySizeResult{
                    .min = self.old_secondary_min,
                    .max = self.old_secondary_max,
                };
            }
        };
        pub const LayoutRequester = struct {
            object: *anyopaque,
            vtable: *const VTABLE,

            pub const VTABLE = struct {
                get_layout_request: *const fn (obj: *anyopaque) LayoutRequest,
                check_secondary_size: *const fn (obj: *anyopaque, check_info: SizeCheckInfo) SecondarySizeResult,
                get_first_child: *const fn (obj: *anyopaque) ?LayoutRequester,
                get_next_sibling: *const fn (obj: *anyopaque) ?LayoutRequester,
            };

            pub inline fn get_layout_request(self: LayoutRequester) LayoutRequest {
                return self.vtable.get_layout_request(self.object);
            }
            pub inline fn check_secondary_size(self: LayoutRequester, check_info: SizeCheckInfo) SecondarySizeResult {
                return self.vtable.check_secondary_size(self.object, check_info);
            }
            pub inline fn get_first_child(self: LayoutRequester) ?LayoutRequester {
                return self.vtable.get_first_child(self.object);
            }
            pub inline fn get_next_sibling(self: LayoutRequester) ?LayoutRequester {
                return self.vtable.get_next_sibling(self.object);
            }
        };
        pub const LayoutRequest = struct {
            /// The minimum size of the element
            min_size: Size = .ONE,
            /// The maximum size of the element. This always overrules min size.
            max_size: Size = .INF,
            /// After the layout position is calculated, this is added to that.
            final_position_offset: Pos = .ZERO,
            /// If the parent has free space on the x axis (within the same row),
            /// allow the element to expand to fill the space
            ///
            /// Has NO effect when element is floating
            grow_x_to_fill_parent_space: bool = false,
            /// If the parent has free space on the y axis (within the same column),
            /// allow the element to expand to fill the space
            ///
            /// Has NO effect when element is floating
            grow_y_to_fill_parent_space: bool = false,
            /// Whether the element takes part in the layout heirarchy,
            /// or merely uses the parent position and 'floats'
            /// above (or below) the parent
            float: Floating = .not_floating(),
            /// The padding around the inside edges of the element
            /// before children are positioned
            padding: Padding = .uniform(0),
            /// The gap bewteen children
            child_gaps: Gap = .uniform(0),
            /// The edges that children are overall aligned to
            child_align: ChildAlignment = .x_y(.LEFT, .TOP),
            /// The direction children are laid out in from first to last
            child_layout_dir: LayoutDirection = .LEFT_TO_RIGHT__TOP_TO_BOTTOM,
            /// If the child's final bounding box exceeds the parent's,
            /// whether the child should clip its bounding box to be within
            /// the parent's. The original bounding box and clipping bounding box are
            /// always provided, this just changes how the clipping bounding box is
            /// calculated. If `false` the clipping box is the same as the drawing box.
            clip_to_parent: bool = false,
            /// If a child row/column overflows on the primary layout axis, whether
            /// to start a new row/column for the remaining children. DUE TO
            /// ALGORITHM CONSTRAINTS, THIS IS ONLY ALLOWED WHEN THE PRIMARY
            /// LAYOUT DIRECTION MATCHES THE DRIVING AXIS OF THE LAYOUT MANAGER.
            wrap_children_that_overflow_size: bool = false,
            /// Within a child axis-line (row/column), how to align
            /// children within the local axis line on the secondary axis.
            ///
            /// For example, If an axis line is a row (primary x axis),
            /// and has 2 elements with a height (y size) of 50px and 100px,
            /// the axis line will have a y size of 100px. This setting determines
            /// how the 50px element is positioned in the y-axis using the remaining
            /// 50px space within the axis-line.
            ///
            /// `INHERIT` means to match `child_align` setting
            children_axis_line_local_align: AxisLineLocalAlign = .INHERIT,
            /// Within the axis-line (row/column) this element occupies on its parent,
            /// how to align itself within that local axis line on the secondary axis.
            ///
            /// This overrides the `children_axis_line_local_align` setting on the parent
            /// when not set to `INHERIT`
            ///
            /// For example, If an axis line is a row (primary x axis),
            /// and has 2 elements with a height (y size) of 50px and 100px,
            /// the axis line will have a y size of 100px. This setting determines
            /// how the 50px element is positioned in the y-axis using the remaining
            /// 50px y space within the axis-line.
            ///
            /// `INHERIT` means to match `children_axis_line_local_align` setting
            /// on the parent, or if the parent is also `INHERIT` it matches the
            /// `child_align` setting instead
            self_axis_line_local_align: AxisLineLocalAlign = .INHERIT,
            /// How the `final_position_offset` is interpreted for the x value
            offset_mode_x: OffsetMode = .ABSOLUTE,
            /// How the `final_position_offset` is interpreted for the y value
            offset_mode_y: OffsetMode = .ABSOLUTE,
            /// How the element max x size is interpreted.
            max_mode_x: MaxMode = .ABSOLUTE,
            /// How the element max y size is interpreted.
            max_mode_y: MaxMode = .ABSOLUTE,
        };
        pub const Padding = struct {
            left: T_SMALL = 0,
            right: T_SMALL = 0,
            top: T_SMALL = 0,
            bottom: T_SMALL = 0,

            pub inline fn uniform(pad: T_SMALL) Padding {
                return Padding{
                    .left = pad,
                    .right = pad,
                    .top = pad,
                    .bottom = pad,
                };
            }

            pub inline fn x_y(pad_x: T_SMALL, pad_y: T_SMALL) Padding {
                return Padding{
                    .left = pad_y,
                    .right = pad_y,
                    .top = pad_x,
                    .bottom = pad_x,
                };
            }

            pub inline fn left_right_top_bottom(pad_left: T_SMALL, pad_right: T_SMALL, pad_top: T_SMALL, pad_bottom: T_SMALL) Padding {
                return Padding{
                    .left = pad_left,
                    .right = pad_right,
                    .top = pad_top,
                    .bottom = pad_bottom,
                };
            }
            pub fn get(self: Padding, comptime AXIS: Axis) T {
                switch (comptime AXIS) {
                    .X => {
                        return self.x_padding();
                    },
                    .Y => {
                        return self.y_padding();
                    },
                }
            }

            pub inline fn x_padding(self: Padding) T {
                return num_cast(self.left, T) + num_cast(self.right, T);
            }
            pub inline fn y_padding(self: Padding) T {
                return num_cast(self.top, T) + num_cast(self.bottom, T);
            }
            inline fn total(self: Padding) Size {
                return Size.new(self.x_padding(), self.y_padding());
            }
            inline fn start_padding(self: Padding, comptime AXIS: Axis, comptime DIR: Dir) T {
                switch (comptime AXIS) {
                    .X => switch (comptime DIR) {
                        .FORWARD => return num_cast(self.left, T),
                        .REVERSE => return num_cast(self.right, T),
                    },
                    .Y => switch (comptime DIR) {
                        .FORWARD => return num_cast(self.top, T),
                        .REVERSE => return num_cast(self.bottom, T),
                    },
                }
            }
            inline fn end_padding(self: Padding, comptime AXIS: Axis, comptime DIR: Dir) T {
                switch (comptime AXIS) {
                    .X => switch (comptime DIR) {
                        .FORWARD => return num_cast(self.right, T),
                        .REVERSE => return num_cast(self.left, T),
                    },
                    .Y => switch (comptime DIR) {
                        .FORWARD => return num_cast(self.bottom, T),
                        .REVERSE => return num_cast(self.top, T),
                    },
                }
            }
        };
        const AxisLine = struct {
            first_elem: IDX = NULL_IDX,
            num_elems: IDX = 0,
            next_line: IDX = NULL_IDX,
            min_size: Size = .ZERO,
            next_growable_line_this_pass: IDX = NULL_IDX,

            pub fn new(first_elem: IDX, num_elems: IDX, min: T, comptime AXIS: Axis) AxisLine {
                var min_size = Size{};
                min_size.set(AXIS, min);
                return AxisLine{
                    .first_elem = first_elem,
                    .num_elems = num_elems,
                    .min_size = min_size,
                };
            }
        };
        const Lines = struct {
            ptr: [*]AxisLine = Utils.invalid_ptr_many(AxisLine),
            len: IDX = 0,
            cap: IDX = 0,
        };

        pub fn MemInit(comptime TT: type) type {
            return union(enum) {
                const Self = @This();

                STATIC: []TT,
                INIT_ALLOW_RELLOC: struct {
                    init_mem: []TT,
                    alloc: Allocator,
                },
                EMPTY_ALLOW_REALLOC: Allocator,

                pub fn static_mem(mem: []TT) Self {
                    return Self{
                        .STATIC = mem,
                    };
                }
                pub fn init_allow_realloc(mem: []TT, alloc: Allocator) Self {
                    return Self{
                        .INIT_ALLOW_RELLOC = .{
                            .alloc = alloc,
                            .init_mem = mem,
                        },
                    };
                }
                pub fn empty_allow_realloc(alloc: Allocator) Self {
                    return Self{
                        .EMPTY_ALLOW_REALLOC = alloc,
                    };
                }

                pub fn get_mem(self: Self) []TT {
                    switch (self) {
                        .STATIC, .EMPTY_ALLOW_REALLOC => return &.{},
                        .INIT_ALLOW_RELLOC => |v| return v.init_mem,
                    }
                }
                pub fn get_alloc(self: Self) Allocator {
                    switch (self) {
                        .STATIC => return dummy_alloc,
                        .EMPTY_ALLOW_REALLOC => |alloc| return alloc,
                        .INIT_ALLOW_RELLOC => |v| return v.alloc,
                    }
                }
            };
        }

        fn auto_debug(self: *LayoutManager, comptime src_loc: ?std.builtin.SourceLocation) void {
            if (SUPER_DEBUG and Assert.IS_DEBUG) {
                for (self.elems.ptr[0..self.elems.len], 0..) |elem, i| {
                    assert_with_reason_debug_only(@intFromPtr(elem.requester.object) != 0, src_loc, "elem {d} requester pointer is 0", .{i});
                    assert_with_reason_debug_only(elem.depth == 0 or elem.parent_idx < self.elems.len, src_loc, "elem {d} has invalid parent ptr", .{i});
                    assert_with_reason_debug_only(elem.next_sibling == NULL_IDX or elem.next_sibling < self.elems.len, src_loc, "elem {d} has OOB next sibling", .{i});
                }
            }
        }

        //*********
        // MANAGER
        //*********
        elems: Elems = .{},
        stack: Stack = .{},
        lines: Lines = .{},
        elems_alloc: Allocator = dummy_alloc,
        lines_alloc: Allocator = dummy_alloc,
        stack_alloc: Allocator = dummy_alloc,
        real_max_elems: IDX = 0,
        real_max_lines: IDX = 0,
        real_max_stack: IDX = 0,

        const ELEM_ALLOC_SETTINGS = Utils.Alloc.SmartAllocComptimeSettings(LayoutElement){
            .CLEAR_OLD_MODE = .DONT_MEMSET_OLD,
            .COPY_MODE = .COPY_EXISTING_DATA,
            .ERROR_MODE = .RETURN_ERRORS,
            .GROW_MODE = .GROW_BY_25_PERCENT,
            .INIT_NEW_MODE = .DONT_MEMSET_NEW,
            .OLD_ALIGN = .align_to_type(),
            .NEW_ALIGN = .align_to_type(),
        };
        const LINE_ALLOC_SETTINGS = Utils.Alloc.SmartAllocComptimeSettings(AxisLine){
            .CLEAR_OLD_MODE = .DONT_MEMSET_OLD,
            .COPY_MODE = .COPY_EXISTING_DATA,
            .ERROR_MODE = .RETURN_ERRORS,
            .GROW_MODE = .GROW_BY_25_PERCENT,
            .INIT_NEW_MODE = .DONT_MEMSET_NEW,
            .OLD_ALIGN = .align_to_type(),
            .NEW_ALIGN = .align_to_type(),
        };
        const STACK_ALLOC_SETTINGS = Utils.Alloc.SmartAllocComptimeSettings(StackFrame){
            .CLEAR_OLD_MODE = .DONT_MEMSET_OLD,
            .COPY_MODE = .COPY_EXISTING_DATA,
            .ERROR_MODE = .RETURN_ERRORS,
            .GROW_MODE = .GROW_BY_25_PERCENT,
            .INIT_NEW_MODE = .DONT_MEMSET_NEW,
            .OLD_ALIGN = .align_to_type(),
            .NEW_ALIGN = .align_to_type(),
        };

        inline fn grow_elems_if_needed(self: *LayoutManager, add_elems: IDX) Error!void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const new_cap = self.elems.len + add_elems;
            if (new_cap > self.elems.cap) {
                try Utils.Alloc.smart_alloc_ptr_ptrs(self.elems_alloc, &self.elems.ptr, &self.elems.len, &self.elems.cap, new_cap, .{}, ELEM_ALLOC_SETTINGS);
            }
        }
        inline fn grow_lines_if_needed(self: *LayoutManager, add_lines: IDX) Error!void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const new_cap = self.lines.len + add_lines;
            if (new_cap > self.lines.cap) {
                try Utils.Alloc.smart_alloc_ptr_ptrs(self.lines_alloc, &self.lines.ptr, &self.lines.len, &self.lines.cap, new_cap, .{}, LINE_ALLOC_SETTINGS);
            }
        }
        inline fn grow_stack_if_needed(self: *LayoutManager, add_stack: IDX) Utils.Alloc.AllocErr!void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const new_cap = self.stack.len + add_stack;
            if (new_cap > self.stack.cap) {
                try Utils.Alloc.smart_alloc_ptr_ptrs(self.stack_alloc, &self.stack.ptr, &self.stack.len, &self.stack.cap, new_cap, .{}, STACK_ALLOC_SETTINGS);
            }
        }

        inline fn get_elem_ptr(self: *LayoutManager, idx: IDX) *LayoutElement {
            return &self.elems.ptr[idx];
        }
        inline fn get_line_ptr(self: *LayoutManager, idx: IDX) *AxisLine {
            return &self.lines.ptr[idx];
        }
        inline fn get_stack_ptr(self: *LayoutManager, idx: IDX) *StackFrame {
            return &self.stack.ptr[idx];
        }
        inline fn get_parent_ptr(elems: Elems, idx: IDX) *LayoutElement {
            return &elems.ptr[elems.ptr[idx].parent_idx];
        }

        fn append_elem_slot(self: *LayoutManager) Error!struct { *LayoutElement, IDX } {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            try self.grow_elems_if_needed(1);
            const idx = self.elems.len;
            self.elems.len += 1;
            self.real_max_elems = @max(self.real_max_elems, self.elems.len);
            const ptr = self.get_elem_ptr(idx);
            return .{ ptr, idx };
        }
        fn append_line_comps(self: *LayoutManager, first_elem: IDX, num_elems: IDX, min_size: T, comptime AXIS: Axis) Error!struct { *AxisLine, IDX } {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            try self.grow_lines_if_needed(1);
            const idx = self.lines.len;
            self.lines.len += 1;
            self.real_max_lines = @max(self.real_max_lines, self.lines.len);
            const ptr = self.get_line_ptr(idx);
            ptr.first_elem = first_elem;
            ptr.num_elems = num_elems;
            ptr.min_size.set(AXIS, min_size);
            ptr.next_line = NULL_IDX;
            return .{ ptr, idx };
        }
        fn append_line(self: *LayoutManager, line: AxisLine) Error!IDX {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            try self.grow_lines_if_needed(1);
            const idx = self.lines.len;
            self.lines.len += 1;
            self.real_max_lines = @max(self.real_max_lines, self.lines.len);
            const ptr = self.get_line_ptr(idx);
            ptr.* = line;
            return idx;
        }
        fn append_line_get_ptr(self: *LayoutManager, line: AxisLine) Error!struct { *AxisLine, IDX } {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            try self.grow_lines_if_needed(1);
            const idx = self.lines.len;
            self.lines.len += 1;
            self.real_max_lines = @max(self.real_max_lines, self.lines.len);
            const ptr = self.get_line_ptr(idx);
            ptr.* = line;
            return .{ ptr, idx };
        }
        fn append_stack_slot(self: *LayoutManager) Error!struct { *StackFrame, IDX } {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            try self.grow_stack_if_needed(1);
            const idx = self.stack.len;
            self.stack.len += 1;
            self.real_max_stack = @max(self.real_max_stack, self.stack.len);
            const ptr = self.get_stack_ptr(idx);
            return .{ ptr, idx };
        }

        fn realloc_stack_impl(obj: *anyopaque, old_stack: Stack, needed_extra_frames: IDX) Utils.Alloc.AllocErr!Stack {
            const self: *LayoutManager = @ptrCast(@alignCast(obj));
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            assert_with_reason_debug_only(old_stack.ptr == self.stack.ptr and old_stack.cap == self.stack.cap, @src(), "`old_stack` does not match the stack on the LayoutManager", .{});
            self.stack.len = old_stack.len;
            try self.grow_stack_if_needed(needed_extra_frames);
            return Stack{
                .ptr = self.stack.ptr,
                .len = self.stack.len,
                .cap = self.stack.cap,
            };
        }

        fn stack_reallocator(self: *LayoutManager) StackReallocator {
            return StackReallocator{
                .object = @ptrCast(self),
                .realloc_impl = realloc_stack_impl,
            };
        }

        pub fn new(elem_mem: MemInit(LayoutElement), axis_line_mem: MemInit(AxisLine), stack_mem: MemInit(StackFrame)) LayoutManager {
            var self: LayoutManager = .{};
            const elem = elem_mem.get_mem();
            const line = axis_line_mem.get_mem();
            const stack = stack_mem.get_mem();
            self.elems.ptr = elem.ptr;
            self.elems.cap = elem.len;
            self.lines.ptr = line.ptr;
            self.lines.cap = line.len;
            self.stack.ptr = stack.ptr;
            self.stack.cap = stack.len;
            self.elems_alloc = elem_mem.get_alloc();
            self.lines_alloc = axis_line_mem.get_alloc();
            self.stack_alloc = stack_mem.get_alloc();
            return self;
        }

        fn append_new_elem_from_requester_and_parent_and_prev_siblings(self: *LayoutManager, requester: LayoutRequester, parent_idx: IDX, prev_contained_sibling_idx: *IDX, prev_floating_sibling_idx: *IDX) Error!struct { *LayoutElement, IDX } {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            try self.grow_elems_if_needed(1);
            const req: LayoutRequest = requester.get_layout_request();
            const new_depth = if (parent_idx == NULL_IDX) 0 else (self.get_elem_ptr(parent_idx).depth + 1);
            const layout_info = PackedLayoutInfo{
                .child_align_x = req.child_align.x,
                .child_align_y = req.child_align.y,
                .child_layout_dir_x = req.child_layout_dir.x_dir(),
                .child_layout_dir_y = req.child_layout_dir.y_dir(),
                .children_axis_line_local_align = req.children_axis_line_local_align,
                .float_parent_attach = req.float.attach.parent,
                .float_self_attach = req.float.attach.child,
                .growable_x = req.grow_x_to_fill_parent_space,
                .growable_y = req.grow_y_to_fill_parent_space,
                .max_mode_x = req.max_mode_x,
                .max_mode_y = req.max_mode_y,
                .offset_mode_x = req.offset_mode_x,
                .offset_mode_y = req.offset_mode_y,
                .primary_child_axis = req.child_layout_dir.primary_axis(),
                .self_axis_line_local_align = req.self_axis_line_local_align,
            };
            DEBUG("Requester = {*}\n", .{requester.object});
            const elem = LayoutElement{
                .requester = requester,
                ._min_or_aabb = .new(req.min_size.x, req.min_size.y),
                ._max_or_clip_aabb = .new(req.max_size.x, req.max_size.y, layout_info),
                .child_gaps = req.child_gaps,
                .depth = new_depth,
                .clip_to_parent = req.clip_to_parent,
                .is_floating = req.float.is_floating,
                .padding = req.padding,
                .parent_idx = parent_idx,
                .use_wrap_mode = req.wrap_children_that_overflow_size,
                .final_position_offset = req.final_position_offset,
            };
            DEBUG("elem.requester = {*}\n", .{elem.requester.object});
            const idx = self.elems.len;
            if (parent_idx != NULL_IDX) {
                var parent: *LayoutElement = self.get_elem_ptr(parent_idx);
                if (elem.is_floating) {
                    if (parent.first_floating_child == NULL_IDX) {
                        parent.first_floating_child = idx;
                    } else {
                        var prev_sibling = self.get_elem_ptr(prev_floating_sibling_idx.*);
                        prev_sibling.next_sibling = idx;
                    }
                    prev_floating_sibling_idx.* = idx;
                } else {
                    if (parent.first_contained_child == NULL_IDX) {
                        parent.first_contained_child = idx;
                        parent.first_axis_line.first_elem = idx;
                    } else {
                        var prev_sibling = self.get_elem_ptr(prev_contained_sibling_idx.*);
                        prev_sibling.next_sibling = idx;
                    }
                    prev_contained_sibling_idx.* = idx;
                    parent.num_contained_children += 1;
                }
            }

            self.elems.ptr[idx] = elem;
            self.elems.len += 1;
            DEBUG(" self.elems.ptr[{d}].requester = {*}\n", .{ idx, self.elems.ptr[idx].requester.object });
            return .{ &self.elems.ptr[idx], idx };
        }

        fn add_children_to_elems_list(_: Elems, parent_idx: IDX, self: *LayoutManager, comptime _: void) Error!Elems {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            var prev_contained_sibling_idx: IDX = NULL_IDX;
            var prev_floating_sibling_idx: IDX = NULL_IDX;
            var possible_child_requester: ?LayoutRequester = null;
            var parent = self.get_elem_ptr(parent_idx);
            possible_child_requester = parent.requester.get_first_child();
            while (possible_child_requester) |child_requester| {
                const child_elem, _ = try self.append_new_elem_from_requester_and_parent_and_prev_siblings(child_requester, parent_idx, &prev_contained_sibling_idx, &prev_floating_sibling_idx);
                possible_child_requester = child_elem.requester.get_next_sibling();
            }
            return self.elems;
        }

        pub fn collect_element_heirarchy(self: *LayoutManager, root_element: LayoutRequester) anyerror!void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            self.elems.len = 0;
            self.lines.len = 0;
            self.stack.len = 0;
            var dummy_idx: IDX = 0;
            _, const root_elem_idx = try self.append_new_elem_from_requester_and_parent_and_prev_siblings(root_element, NULL_IDX, &dummy_idx, &dummy_idx);
            self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, .all_child_paths(), root_elem_idx, self, void{}, .COMPTIME_FN_PTR, add_children_to_elems_list, void{}, .TRACK_MAX_STACK_LEN, &self.real_max_stack);
            self.real_max_elems = @max(self.real_max_elems, self.elems.len);
        }

        pub fn recalculate_layout(self: *LayoutManager, comptime DRIVING_AXIS: Axis) anyerror!void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            switch (comptime DRIVING_AXIS) {
                .X => {
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .CHILDREN_FIRST, .all_child_paths(), 0, self, AxisStage.new(.X, .PRIMARY_STAGE), .COMPTIME_FN_PTR, propagate_min_size_to_parent, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, .all_child_paths(), 0, self, AxisStage.new(.X, .PRIMARY_STAGE), .COMPTIME_FN_PTR, fit_and_expand_children_to_fill_parent, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .ANY_ORDER_NO_IDX_GAPS_ROOT_IDX_TO_LAST_IDX, .all_child_paths(), 0, self, Axis.X, .COMPTIME_FN_PTR, recheck_secondary_size_with_with_known_primary_size, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .CHILDREN_FIRST, .all_child_paths(), 0, self, AxisStage.new(.Y, .SECONDARY_STAGE), .COMPTIME_FN_PTR, propagate_min_size_to_parent, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, .all_child_paths(), 0, self, AxisStage.new(.Y, .SECONDARY_STAGE), .COMPTIME_FN_PTR, fit_and_expand_children_to_fill_parent, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                },
                .Y => {
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .CHILDREN_FIRST, .all_child_paths(), 0, self, AxisStage.new(.Y, .PRIMARY_STAGE), .COMPTIME_FN_PTR, propagate_min_size_to_parent, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, .all_child_paths(), 0, self, AxisStage.new(.Y, .PRIMARY_STAGE), .COMPTIME_FN_PTR, fit_and_expand_children_to_fill_parent, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .ANY_ORDER_NO_IDX_GAPS_ROOT_IDX_TO_LAST_IDX, .all_child_paths(), 0, self, Axis.Y, .COMPTIME_FN_PTR, recheck_secondary_size_with_with_known_primary_size, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .CHILDREN_FIRST, .all_child_paths(), 0, self, AxisStage.new(.X, .SECONDARY_STAGE), .COMPTIME_FN_PTR, propagate_min_size_to_parent, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                    self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, .all_child_paths(), 0, self, AxisStage.new(.X, .SECONDARY_STAGE), .COMPTIME_FN_PTR, fit_and_expand_children_to_fill_parent, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
                },
            }
            self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, .all_child_paths(), 0, self, void{}, .COMPTIME_FN_PTR, position_and_align_child_elements, void{}, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
        }

        fn propagate_min_size_to_parent(elems: Elems, idx: IDX, self: *LayoutManager, comptime CT: AxisStage) anyerror!Elems {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const child = self.get_elem_ptr(idx);
            child.add_to_min_children_size(CT.AXIS, child.padding.get(CT.AXIS));
            child.update_min_size_with_children_min_size(CT.AXIS);
            if (child.is_floating or child.parent_idx == NULL_IDX) return self.elems;
            const parent = get_parent_ptr(elems, idx);
            const gap = parent.child_gaps.get(CT.AXIS);
            if (parent.get_primary_child_axis() == CT.AXIS and !parent.use_wrap_mode) {
                const add_min_size = child.get_min_size_self(CT.AXIS) + gap;
                parent.add_to_min_children_size(CT.AXIS, add_min_size);
            } else {
                const min_size = child.get_min_size_self(CT.AXIS);
                parent.update_max_of_min_children_size(CT.AXIS, min_size);
            }
            return self.elems;
        }

        fn combine_all_children_with_axis_lines(self: *LayoutManager, parent: *LayoutElement, comptime CT: AxisStage, comptime COMBINE_MODE: CombineMode, comptime WRAP_MODE: WrapMode) anyerror!void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const max_size_for_children = parent.get_min_size_self(CT.AXIS) - parent.padding.get(CT.AXIS);
            var child: *LayoutElement = undefined;
            var child_idx = parent.first_contained_child;
            const gap = parent.child_gaps.get(CT.AXIS);
            var line = &parent.first_axis_line;
            if (CT.STAGE == .PRIMARY_STAGE) {
                line.min_size.set(CT.AXIS, -gap);
            }
            var children_left_on_parent = parent.num_contained_children;
            var children_left_on_line = line.num_elems;
            var more_children_on_parent = children_left_on_parent > 0;
            var more_children_on_line = true;
            while (more_children_on_parent) {
                children_left_on_parent -= 1;
                child = self.get_elem_ptr(child_idx);
                more_children_on_parent = children_left_on_parent > 0;
                if (CT.STAGE == .SECONDARY_STAGE) {
                    children_left_on_line -= 1;
                    more_children_on_line = children_left_on_line > 0;
                }
                line = try self.combine_child_with_axis_line(line, child, child_idx, more_children_on_parent, more_children_on_line, gap, max_size_for_children, CT.AXIS, COMBINE_MODE, WRAP_MODE, CT.STAGE);
                child_idx = child.next_sibling;
            }
            if (COMBINE_MODE == .UPDATE_MAX_OF_MIN_SIZE) {
                self.distribute_secondary_extra_space_to_all_axis_lines(parent, CT.AXIS);
            }
        }

        fn combine_child_with_axis_line(self: *LayoutManager, line: *AxisLine, child: *LayoutElement, child_idx: IDX, more_children_on_parent: bool, more_children_on_line: bool, gap: T, max_size: T, comptime AXIS: Axis, comptime COMBINE_MODE: CombineMode, comptime WRAP_MODE: WrapMode, comptime STAGE: LayoutStage) anyerror!*AxisLine {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            var size_if_combine = line.min_size.get(AXIS);
            var next_line = line;
            const child_size = child.get_min_size_self(AXIS);
            switch (comptime COMBINE_MODE) {
                .ADD_MIN_SIZE_AND_GAP => {
                    size_if_combine += child_size + gap;
                    const handle_combine_stage: HANDLE_COMBINE_STAGE = switch (WRAP_MODE) {
                        .NO_WRAP => .ADD_CURRENT_CHILD_TO_CURRENT_LINE,
                        .ALLOW_WRAP => if (line.num_elems > 0 and size_if_combine > max_size) .FINISH_LINE_AND_POSSIBLY_START_NEW else .ADD_CURRENT_CHILD_TO_CURRENT_LINE,
                    };
                    to_stage: switch (handle_combine_stage) {
                        .FINISH_LINE_AND_POSSIBLY_START_NEW => {
                            if (WRAP_MODE == .NO_WRAP) {
                                unreachable;
                            }
                            const total_gap = num_cast(line.num_elems - 1, T) * gap;
                            self.distribute_primary_extra_space_to_axis_line_members(line, max_size - total_gap, AXIS);
                            if (more_children_on_parent) {
                                switch (STAGE) {
                                    .SECONDARY_STAGE => {
                                        assert_unreachable(@src(), "cannot start new axis line in secondary stage", .{});
                                    },
                                    .PRIMARY_STAGE => {
                                        const new_line = AxisLine.new(child_idx, 1, child_size, AXIS);
                                        next_line, const next_idx = try self.append_line_get_ptr(new_line);
                                        line.next_line = next_idx;
                                    },
                                }
                            }
                        },
                        .FINISH_LINE_AND_END => {
                            const total_gap = num_cast(line.num_elems - 1, T) * gap;
                            self.distribute_primary_extra_space_to_axis_line_members(line, max_size - total_gap, AXIS);
                        },
                        .ADD_CURRENT_CHILD_TO_CURRENT_LINE => {
                            line.min_size.set(AXIS, size_if_combine);
                            if (STAGE == .PRIMARY_STAGE) {
                                line.num_elems += 1;
                            }
                            if (!more_children_on_parent) continue :to_stage .FINISH_LINE_AND_END;
                        },
                    }
                },
                .UPDATE_MAX_OF_MIN_SIZE => {
                    size_if_combine = @max(size_if_combine, child_size);
                    line.min_size.set(AXIS, size_if_combine);
                    // VERIFY does removing this code indicate some sort of logic error or old code residue elsewhere?
                    // if (child.is_growable(AXIS)) {
                    //     line.max_secondary_grow = @max(line.max_secondary_grow, child.get_grow_ratio(AXIS));
                    // }
                    switch (STAGE) {
                        .PRIMARY_STAGE => {
                            line.num_elems += 1;
                            assert_with_reason_debug_only(WRAP_MODE != .ALLOW_WRAP, @src(), "internal logic error: cannot use overflow mode when the primary layout direction does not match the driving axis", .{});
                        },
                        .SECONDARY_STAGE => {
                            if (more_children_on_parent and !more_children_on_line) {
                                assert_with_reason_debug_only(WRAP_MODE == .ALLOW_WRAP, @src(), "internal logic error: when `more_children_on_parent` and `!more_children_on_line`, the mode MUST be `ALLOW_WRAP`", .{});
                                assert_with_reason_debug_only(line.next_line != NULL_IDX, @src(), "internal logic error: a null idx found on `line.next_line` when there should exist another line", .{});
                                next_line = self.get_line_ptr(line.next_line);
                            }
                        },
                    }
                },
            }
            return next_line;
        }

        fn distribute_primary_extra_space_to_axis_line_members(self: *LayoutManager, axis_line: *AxisLine, space: T, comptime AXIS: Axis) void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            var remaining_space = space;
            while (remaining_space > 0) {
                var idx: IDX = axis_line.first_elem;
                var n: IDX = axis_line.num_elems;
                var child: *LayoutElement = undefined;
                var total_growable_children_this_pass: IDX = 0;
                var smallest_growable_child_this_pass: T = math.inf(T);
                var second_smallest_growable_child_this_pass: T = math.inf(T);
                var grow_limit_this_pass: T = math.inf(T);
                var first_growable_child_this_pass: IDX = NULL_IDX;
                var prev_growable_child_this_pass: IDX = NULL_IDX;
                while (n > 0) {
                    n -= 1;
                    child = self.get_elem_ptr(idx);
                    if (child.is_growable(AXIS)) {
                        if (Math.approx_equal(T, child.get_min_size_self(AXIS), smallest_growable_child_this_pass)) {
                            const prev_child: *LayoutElement = self.get_elem_ptr(prev_growable_child_this_pass);
                            prev_child.set_next_growable_idx_this_pass(idx);
                            prev_growable_child_this_pass = idx;
                            total_growable_children_this_pass += 1;
                            grow_limit_this_pass = @min(grow_limit_this_pass, child.get_max_size(AXIS));
                        } else if (Math.approx_less_than(T, child.get_min_size_self(AXIS), smallest_growable_child_this_pass)) {
                            second_smallest_growable_child_this_pass = smallest_growable_child_this_pass;
                            smallest_growable_child_this_pass = child.get_min_size_self(AXIS);
                            grow_limit_this_pass = @min(child.get_max_size(AXIS), second_smallest_growable_child_this_pass);
                            first_growable_child_this_pass = idx;
                            prev_growable_child_this_pass = idx;
                            child.set_next_growable_idx_this_pass(NULL_IDX);
                            total_growable_children_this_pass = 1;
                        }
                    }
                    idx = child.next_sibling;
                }
                if (total_growable_children_this_pass == 0) break;
                idx = first_growable_child_this_pass;
                n = total_growable_children_this_pass;
                const nn: T = @floatFromInt(n);
                const max_space_per_child_this_pass = grow_limit_this_pass - smallest_growable_child_this_pass;
                var space_per_child_this_pass = remaining_space / nn;
                space_per_child_this_pass = @min(space_per_child_this_pass, max_space_per_child_this_pass);
                const space_taken_this_pass = nn * space_per_child_this_pass;
                if (space_taken_this_pass <= math.floatEps(T)) break;
                while (n > 0) {
                    n -= 1;
                    child = self.get_elem_ptr(idx);
                    child.add_to_min_self_size_limit_to_max_update_growable(AXIS, space_per_child_this_pass);
                    idx = child.get_next_growable_idx_this_pass();
                }
                remaining_space -= space_taken_this_pass;
                axis_line.min_size.set(AXIS, axis_line.min_size.get(AXIS) + space_taken_this_pass);
            }
        }

        fn distribute_secondary_extra_space_to_all_axis_lines(self: *LayoutManager, parent: *LayoutElement, comptime AXIS: Axis) void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const gap = parent.child_gaps.get(AXIS);
            var line = &parent.first_axis_line;
            var lines_left: IDX = parent.num_axis_lines;
            var total_axis_lines_size: T = -gap;
            while (lines_left > 0) {
                lines_left -= 1;
                total_axis_lines_size += line.min_size.get(AXIS) + gap;
                var children_left = line.num_elems;
                var child_idx: IDX = line.first_elem;
                while (children_left > 0) {
                    children_left -= 1;
                    const child: *LayoutElement = self.get_elem_ptr(child_idx);
                    if (child.is_growable(AXIS)) {
                        child.set_min_size_self_limit_to_max_update_growable(AXIS, line.min_size.get(AXIS));
                    }
                    child_idx = child.next_sibling;
                }
                if (lines_left > 0) {
                    line = self.get_line_ptr(line.next_line);
                }
            }
            const space_for_lines = parent.get_min_size_self(AXIS) - parent.padding.get(AXIS);
            var remaining_space = space_for_lines - total_axis_lines_size;
            while (remaining_space > 0) {
                line = &parent.first_axis_line;
                lines_left = parent.num_axis_lines;
                var axis_line_idx: IDX = NULL_IDX;
                var child: *LayoutElement = undefined;
                var total_growable_lines_this_pass: IDX = 0;
                var total_growable_children_this_pass: IDX = 0;
                var child_grow_limit_this_pass: T = math.inf(T);
                var prev_growable_line_this_pass: IDX = NULL_IDX;
                var first_growable_line_this_pass: IDX = NULL_IDX;
                var smallest_growable_child_this_pass: T = math.inf(T);
                var second_smallest_growable_child_this_pass: T = math.inf(T);
                var first_growable_child_this_pass: IDX = NULL_IDX;
                var prev_growable_child_this_pass: IDX = NULL_IDX;
                var children_left: IDX = undefined;
                while (lines_left > 0) {
                    lines_left -= 1;
                    children_left = line.num_elems;
                    var child_idx: IDX = line.first_elem;
                    while (children_left > 0) {
                        children_left -= 1;
                        child = self.get_elem_ptr(child_idx);
                        if (child.is_growable(AXIS)) {
                            if (Math.approx_equal(T, child.get_min_size_self(AXIS), smallest_growable_child_this_pass)) {
                                const prev_child: *LayoutElement = self.get_elem_ptr(prev_growable_child_this_pass);
                                const prev_line: *AxisLine = if (prev_growable_line_this_pass == NULL_IDX) &parent.first_axis_line else self.get_line_ptr(prev_growable_line_this_pass);
                                prev_child.set_next_growable_idx_this_pass(child_idx);
                                prev_line.next_growable_line_this_pass = axis_line_idx;
                                prev_growable_child_this_pass = child_idx;
                                prev_growable_child_this_pass = axis_line_idx;
                                child_grow_limit_this_pass = @min(child_grow_limit_this_pass, child.get_max_size(AXIS));
                                if (total_growable_lines_this_pass == 0) {
                                    total_growable_lines_this_pass += 1;
                                } else if (axis_line_idx != prev_growable_line_this_pass) {
                                    total_growable_lines_this_pass += 1;
                                }
                                total_growable_children_this_pass += 1;
                            } else if (Math.approx_less_than(T, child.get_min_size_self(AXIS), smallest_growable_child_this_pass)) {
                                total_growable_lines_this_pass = 1;
                                total_growable_children_this_pass = 1;
                                prev_growable_line_this_pass = axis_line_idx;
                                first_growable_line_this_pass = axis_line_idx;
                                second_smallest_growable_child_this_pass = smallest_growable_child_this_pass;
                                smallest_growable_child_this_pass = child.get_min_size_self(AXIS);
                                child_grow_limit_this_pass = @min(child.get_max_size(AXIS), second_smallest_growable_child_this_pass);
                                first_growable_child_this_pass = child_idx;
                                prev_growable_child_this_pass = child_idx;
                                child.set_next_growable_idx_this_pass(NULL_IDX);
                            }
                        }
                        child_idx = child.next_sibling;
                    }
                    axis_line_idx = line.next_line;
                    if (lines_left > 0) {
                        line = self.get_line_ptr(axis_line_idx);
                    }
                }
                if (total_growable_lines_this_pass == 0) break;
                var child_idx = first_growable_child_this_pass;
                children_left = total_growable_children_this_pass;
                lines_left = total_growable_lines_this_pass;
                const total_growable_lines_this_pass_T: T = @floatFromInt(total_growable_lines_this_pass);
                const max_space_per_child_this_pass = child_grow_limit_this_pass - smallest_growable_child_this_pass;
                var space_per_child_this_pass = remaining_space / total_growable_lines_this_pass_T;
                space_per_child_this_pass = @min(space_per_child_this_pass, max_space_per_child_this_pass);
                const space_taken_this_pass = total_growable_lines_this_pass_T * space_per_child_this_pass;
                if (space_taken_this_pass <= math.floatEps(T)) break;
                while (children_left > 0) {
                    children_left -= 1;
                    child = self.get_elem_ptr(child_idx);
                    child.add_to_min_self_size_limit_to_max_update_growable(AXIS, space_per_child_this_pass);
                    child_idx = child.get_next_growable_idx_this_pass();
                }
                line = if (first_growable_line_this_pass == NULL_IDX) &parent.first_axis_line else self.get_line_ptr(first_growable_line_this_pass);
                while (lines_left > 0) {
                    lines_left -= 1;
                    line.min_size.set(AXIS, line.min_size.get(AXIS) + space_per_child_this_pass);
                    if (lines_left > 0) {
                        line = self.get_line_ptr(line.next_growable_line_this_pass);
                    }
                }
                remaining_space -= space_taken_this_pass;
            }
        }

        fn fit_and_expand_children_to_fill_parent(_: Elems, idx: IDX, self: *LayoutManager, comptime CT: AxisStage) anyerror!Elems {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const parent = self.get_elem_ptr(idx);
            if (parent.is_floating or parent.parent_idx == NULL_IDX) {
                parent.set_min_size_self_limit_to_max_update_growable(CT.AXIS, parent.get_min_size_self(CT.AXIS));
            }
            if (parent.first_contained_child != NULL_IDX) {
                assert_with_reason_debug_only(parent.num_contained_children > 0, @src(), "first child on parent wasnt NULL, but parent has no children count", .{});
                if (parent.use_wrap_mode) {
                    if (parent.get_primary_child_axis() == CT.AXIS) {
                        try self.combine_all_children_with_axis_lines(parent, CT, .ADD_MIN_SIZE_AND_GAP, .ALLOW_WRAP);
                    } else {
                        try self.combine_all_children_with_axis_lines(parent, CT, .UPDATE_MAX_OF_MIN_SIZE, .ALLOW_WRAP);
                    }
                } else {
                    if (parent.get_primary_child_axis() == CT.AXIS) {
                        try self.combine_all_children_with_axis_lines(parent, CT, .ADD_MIN_SIZE_AND_GAP, .NO_WRAP);
                    } else {
                        try self.combine_all_children_with_axis_lines(parent, CT, .UPDATE_MAX_OF_MIN_SIZE, .NO_WRAP);
                    }
                }
            }
            return self.elems;
        }

        fn recheck_secondary_size_with_with_known_primary_size(_: Elems, idx: IDX, self: *LayoutManager, comptime DRIVING_AXIS: Axis) anyerror!Elems {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const SECONDARY_AXIS = comptime DRIVING_AXIS.OPPOSITE();
            const elem = self.get_elem_ptr(idx);
            const check_info = SizeCheckInfo{
                .driving_axis = DRIVING_AXIS,
                .driving_size = elem.get_min_size_self(DRIVING_AXIS),
                .old_secondary_min = elem.get_min_size_self(SECONDARY_AXIS),
                .old_secondary_max = elem.get_max_size(SECONDARY_AXIS),
            };
            const new_secondary_size = elem.requester.check_secondary_size(check_info);
            elem.set_min_size_self(SECONDARY_AXIS, new_secondary_size.min);
            elem.set_max_size(SECONDARY_AXIS, new_secondary_size.max);
            return self.elems;
        }

        inline fn for_each_axis_line(self: *LayoutManager, parent: *LayoutElement, context: anytype, comptime CONTEXT: anytype, comptime action: fn (*LayoutManager, *LayoutElement, *AxisLine, @TypeOf(context), comptime @TypeOf(CONTEXT)) void) void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            var line: *AxisLine = &parent.first_axis_line;
            var n = parent.num_axis_lines;
            if (n == 0) return;
            action(self, parent, line, context, CONTEXT);
            n -= 1;
            while (n > 0) {
                line = self.get_line_ptr(line.next_line);
                n -= 1;
                action(self, parent, line, context, CONTEXT);
            }
        }

        inline fn for_each_child_on_axis_line(self: *LayoutManager, parent: *LayoutElement, line: *AxisLine, context: anytype, comptime CONTEXT: anytype, comptime action: fn (*LayoutManager, *LayoutElement, *AxisLine, IDX, *LayoutElement, @TypeOf(context), comptime @TypeOf(CONTEXT)) void) void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            var child_idx: IDX = line.first_elem;
            var child: *LayoutElement = undefined;
            var n: IDX = line.num_elems;
            while (n > 0) {
                n -= 1;
                child = self.get_elem_ptr(child_idx);
                action(self, parent, line, child_idx, child, context, CONTEXT);
                child_idx = child.next_sibling;
            }
        }

        inline fn for_each_floating_child(self: *LayoutManager, parent: *LayoutElement, context: anytype, comptime CONTEXT: anytype, comptime action: fn (*LayoutManager, *LayoutElement, IDX, *LayoutElement, @TypeOf(context), comptime @TypeOf(CONTEXT)) void) void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            var child_idx: IDX = parent.first_floating_child;
            var child: *LayoutElement = undefined;
            while (child_idx != NULL_IDX) {
                child = self.get_elem_ptr(child_idx);
                action(self, parent, child_idx, child, context, CONTEXT);
                child_idx = child.next_sibling;
            }
        }

        const PosAlignData_S = struct {
            cursor_axis_line_start_p: T,
            cursor_pos_s: T,
            num_gaps_s: IDX,
            base_gap_p: T,
            gap_s: T,
            parent_size: Size,
            parent_size_minus_padding: Size,
            parent_abs_pos: Pos,
            child_align_p: Align,
            child_align_s: Align,
        };
        const PosAlignData_P = struct {
            cursor_pos_p: T,
            cursor_pos_s: T,
            gap_p: T,
            gap_s: T,
        };
        const PosAlignData_CT = struct {
            PRIME_AXIS: Axis,
            SEC_AXIS: Axis,
            PRIME_DIR: Dir,
            SEC_DIR: Dir,
            NEGATIVE_DELTA_P: bool,
            NEGATIVE_DELTA_S: bool,
        };
        const AxisSizeData = struct {
            base_gap: T,
            total_size: T,
        };

        fn position_and_align_childen_on_axis_line(self: *LayoutManager, parent: *LayoutElement, line: *AxisLine, data_s: *PosAlignData_S, comptime DATA: PosAlignData_CT) void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            var cursor_p = data_s.cursor_axis_line_start_p;
            var gap_p = data_s.base_gap_p;
            switch (data_s.child_align_p) {
                .MIDDLE => {
                    var prime_size_data = AxisSizeData{
                        .base_gap = gap_p,
                        .total_size = -gap_p,
                    };
                    self.for_each_child_on_axis_line(parent, line, &prime_size_data, DATA.PRIME_AXIS, add_primary_size_to_total);
                    var leftover_primary_space = data_s.parent_size_minus_padding.get(DATA.PRIME_AXIS) - prime_size_data.total_size;
                    leftover_primary_space = leftover_primary_space / 2;
                    if (DATA.NEGATIVE_DELTA_P) {
                        cursor_p -= leftover_primary_space;
                    } else {
                        cursor_p += leftover_primary_space;
                    }
                },
                .JUSTIFY => {
                    if (line.num_elems > 1) {
                        var prime_size_data = AxisSizeData{
                            .base_gap = gap_p,
                            .total_size = -gap_p,
                        };
                        self.for_each_child_on_axis_line(parent, line, &prime_size_data, DATA.PRIME_AXIS, add_primary_size_to_total);
                        var leftover_primary_space = data_s.parent_size_minus_padding.get(DATA.PRIME_AXIS) - prime_size_data.total_size;
                        leftover_primary_space = leftover_primary_space / num_cast(line.num_elems - 1, T);
                        if (DATA.NEGATIVE_DELTA_P) {
                            gap_p -= leftover_primary_space;
                        } else {
                            gap_p += leftover_primary_space;
                        }
                    }
                },
                else => {},
            }
            var data_p = PosAlignData_P{
                .cursor_pos_p = cursor_p,
                .cursor_pos_s = data_s.cursor_pos_s,
                .gap_p = gap_p,
                .gap_s = data_s.gap_s,
            };
            self.for_each_child_on_axis_line(parent, line, &data_p, DATA, finalize_inline_child_aabb);
            if (comptime DATA.NEGATIVE_DELTA_S) {
                data_s.cursor_pos_s -= (line.min_size.get(DATA.SEC_AXIS) + data_s.gap_s);
            } else {
                data_s.cursor_pos_s += (line.min_size.get(DATA.SEC_AXIS) + data_s.gap_s);
            }
        }

        fn add_secondary_size_to_total(_: *LayoutManager, _: *LayoutElement, line: *AxisLine, data: *AxisSizeData, comptime SEC_AXIS: Axis) void {
            data.total_size += line.min_size.get(SEC_AXIS) + data.base_gap;
        }
        fn add_primary_size_to_total(_: *LayoutManager, _: *LayoutElement, _: *AxisLine, _: IDX, child: *LayoutElement, data: *AxisSizeData, comptime PRIME_AXIS: Axis) void {
            data.total_size += child.get_min_size_self(PRIME_AXIS) + data.base_gap;
        }
        fn finalize_inline_child_aabb(self: *LayoutManager, parent: *LayoutElement, line: *AxisLine, _: IDX, child: *LayoutElement, data: *PosAlignData_P, comptime DATA: PosAlignData_CT) void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const child_size_p = child.get_min_size_self(DATA.PRIME_AXIS);
            const child_size_s = child.get_min_size_self(DATA.SEC_AXIS);

            if (comptime DATA.NEGATIVE_DELTA_P) {
                data.cursor_pos_p -= child_size_p;
            }
            var child_pos_s: T = data.cursor_pos_s;
            const child_local_align = LocalAlign.eval(parent.get_child_align(DATA.SEC_AXIS).generic(), parent.get_children_local_align(), child.get_self_local_align());
            switch (child_local_align) {
                .START => {
                    if (comptime DATA.NEGATIVE_DELTA_P) {
                        child_pos_s -= line.min_size.get(DATA.SEC_AXIS);
                    }
                },
                .CENTER => {
                    var local_sec_free_space = line.min_size.get(DATA.SEC_AXIS) - child_size_s;
                    local_sec_free_space /= 2;
                    if (comptime DATA.NEGATIVE_DELTA_P) {
                        child_pos_s -= (local_sec_free_space + child_size_s);
                    } else {
                        child_pos_s += local_sec_free_space;
                    }
                },
                .END => {
                    if (comptime DATA.NEGATIVE_DELTA_P) {
                        child_pos_s -= child_size_s;
                    } else {
                        const local_sec_free_space = line.min_size.get(DATA.SEC_AXIS) - child_size_s;
                        child_pos_s += local_sec_free_space;
                    }
                },
            }
            const final_pos = Pos.new(if (comptime DATA.PRIME_AXIS == .X) data.cursor_pos_p else child_pos_s, if (comptime DATA.PRIME_AXIS == .Y) data.cursor_pos_p else child_pos_s).add(child.final_position_offset);
            const final_size = Size.new(if (comptime DATA.PRIME_AXIS == .X) child_size_p else child_size_s, if (comptime DATA.PRIME_AXIS == .Y) child_size_p else child_size_s);
            child._min_or_aabb.final_aabb = AABB.new_from_pos_size(final_pos, final_size);
            if (comptime DATA.NEGATIVE_DELTA_P) {
                data.cursor_pos_p -= data.gap_p;
            } else {
                data.cursor_pos_p += child_size_p + data.gap_p;
            }
            if (child.clip_to_parent) {
                child._max_or_clip_aabb.final_clip_aabb, child.completely_clipped = child._min_or_aabb.final_aabb.overlap_area_and_overlap_area_zero_or_negative(parent._max_or_clip_aabb.final_clip_aabb);
            } else {
                child._max_or_clip_aabb.final_clip_aabb = child._min_or_aabb.final_aabb;
            }
        }
        fn finalize_floating_child_aabb(self: *LayoutManager, parent: *LayoutElement, _: IDX, child: *LayoutElement, _: void, comptime _: void) void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const child_size = child._min_or_aabb.min_size.self;
            const parent_float_attach = child.get_parent_float_attach();
            const self_float_attach = child.get_self_float_attach();
            var child_pos_x = switch (parent_float_attach) {
                .TOP_LEFT, .CENTER_LEFT, .BOTTOM_LEFT => parent.get_aabb().x_min,
                .TOP_MIDDLE, .CENTER_MIDDLE, .BOTTOM_MIDDLE => parent.get_aabb().get_center_point_component(.X),
                .TOP_RIGHT, .CENTER_RIGHT, .BOTTOM_RIGHT => parent.get_aabb().x_max,
            };
            switch (self_float_attach) {
                .TOP_LEFT, .CENTER_LEFT, .BOTTOM_LEFT => {},
                .TOP_MIDDLE, .CENTER_MIDDLE, .BOTTOM_MIDDLE => {
                    child_pos_x -= (child_size.x / 2.0);
                },
                .TOP_RIGHT, .CENTER_RIGHT, .BOTTOM_RIGHT => {
                    child_pos_x -= child_size.x;
                },
            }
            var child_pos_y = switch (parent_float_attach) {
                .TOP_LEFT, .TOP_MIDDLE, .TOP_RIGHT => parent.get_aabb().y_min,
                .CENTER_LEFT, .CENTER_MIDDLE, .CENTER_RIGHT => parent.get_aabb().get_center_point_component(.Y),
                .BOTTOM_LEFT, .BOTTOM_MIDDLE, .BOTTOM_RIGHT => parent.get_aabb().y_max,
            };
            switch (self_float_attach) {
                .TOP_LEFT, .TOP_MIDDLE, .TOP_RIGHT => {},
                .CENTER_LEFT, .CENTER_MIDDLE, .CENTER_RIGHT => {
                    child_pos_y -= (child_size.y / 2.0);
                },
                .BOTTOM_LEFT, .BOTTOM_MIDDLE, .BOTTOM_RIGHT => {
                    child_pos_y -= child_size.y;
                },
            }
            child_pos_x += child.final_position_offset.x;
            child_pos_y += child.final_position_offset.y;
            child._min_or_aabb.final_aabb = AABB.new_from_pos_size(Pos.new(child_pos_x, child_pos_y), child_size);
            if (child.clip_to_parent) {
                child._max_or_clip_aabb.final_clip_aabb, child.completely_clipped = child._min_or_aabb.final_aabb.overlap_area_and_overlap_area_zero_or_negative(parent._max_or_clip_aabb.final_clip_aabb);
            } else {
                child._max_or_clip_aabb.final_clip_aabb = child._min_or_aabb.final_aabb;
            }
        }

        fn position_and_align_inline_child_elements_core(self: *LayoutManager, parent: *LayoutElement, comptime PRIME_AXIS: Axis, comptime SEC_AXIS: Axis, comptime PRIME_DIR: Dir, comptime SEC_DIR: Dir) void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            const DATA = comptime PosAlignData_CT{
                .PRIME_AXIS = PRIME_AXIS,
                .SEC_AXIS = SEC_AXIS,
                .PRIME_DIR = PRIME_DIR,
                .SEC_DIR = SEC_DIR,
                .NEGATIVE_DELTA_P = PRIME_DIR == .REVERSE,
                .NEGATIVE_DELTA_S = SEC_DIR == .REVERSE,
            };
            const parent_abs_pos = parent.get_absolute_pos();
            const parent_size = parent.get_final_size();
            const parent_abs_pos_end = parent.get_absolute_pos_end();
            const padding = parent.padding;
            const parent_size_minus_padding = parent_size.subtract(padding.total());
            const child_align_s = parent.get_child_align(SEC_AXIS).generic();
            var cursor_pos_s = if (DATA.NEGATIVE_DELTA_P) parent_abs_pos_end.get(SEC_AXIS) - padding.start_padding(SEC_AXIS, SEC_DIR) else parent_abs_pos.get(SEC_AXIS) + padding.start_padding(SEC_AXIS, SEC_DIR);
            var gap_s = parent.child_gaps.get(SEC_AXIS);
            const cursor_axis_line_start_p = if (DATA.NEGATIVE_DELTA_P) parent_abs_pos_end.get(PRIME_AXIS) - padding.start_padding(PRIME_AXIS, PRIME_DIR) else parent_abs_pos.get(PRIME_AXIS) + padding.start_padding(PRIME_AXIS, PRIME_DIR);
            const num_gaps_s = parent.num_axis_lines - 1;
            switch (child_align_s) {
                .MIDDLE => {
                    var sec_size_data = AxisSizeData{
                        .base_gap = gap_s,
                        .total_size = -gap_s,
                    };
                    self.for_each_axis_line(parent, &sec_size_data, SEC_AXIS, add_secondary_size_to_total);
                    var leftover_secondary_space = parent_size_minus_padding.get(SEC_AXIS) - sec_size_data.total_size;
                    leftover_secondary_space = leftover_secondary_space / 2;
                    if (DATA.NEGATIVE_DELTA_P) {
                        cursor_pos_s -= leftover_secondary_space;
                    } else {
                        cursor_pos_s += leftover_secondary_space;
                    }
                },
                .JUSTIFY => {
                    if (num_gaps_s > 0) {
                        var sec_size_data = AxisSizeData{
                            .base_gap = gap_s,
                            .total_size = -gap_s,
                        };
                        self.for_each_axis_line(parent, &sec_size_data, SEC_AXIS, add_secondary_size_to_total);
                        var leftover_secondary_space = parent_size_minus_padding.get(SEC_AXIS) - sec_size_data.total_size;
                        leftover_secondary_space = leftover_secondary_space / num_cast(num_gaps_s, T);
                        gap_s += leftover_secondary_space;
                    }
                },
                else => {},
            }
            var data = PosAlignData_S{
                .cursor_axis_line_start_p = cursor_axis_line_start_p,
                .cursor_pos_s = cursor_pos_s,
                .num_gaps_s = num_gaps_s,
                .base_gap_p = parent.child_gaps.get(PRIME_AXIS),
                .gap_s = gap_s,
                .parent_size_minus_padding = parent_size_minus_padding,
                .parent_size = parent_size,
                .parent_abs_pos = parent.get_absolute_pos(),
                .child_align_p = parent.get_child_align(PRIME_AXIS).generic(),
                .child_align_s = child_align_s,
            };
            self.for_each_axis_line(parent, &data, DATA, position_and_align_childen_on_axis_line);
        }

        fn position_and_align_child_elements(_: Elems, idx: IDX, self: *LayoutManager, comptime _: void) anyerror!Elems {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            var parent: *LayoutElement = self.get_elem_ptr(idx);
            if (parent.parent_idx == NULL_IDX) {
                @branchHint(.unlikely);
                const final_size = parent._min_or_aabb.min_size.self;
                parent._min_or_aabb.final_aabb = AABB.new(parent.final_position_offset.x, parent.final_position_offset.x + final_size.x, parent.final_position_offset.y, parent.final_position_offset.y + final_size.y);
            }
            if (parent.num_contained_children > 0) {
                switch (parent.get_primary_child_axis()) {
                    .X => switch (parent.get_child_layout_dir(.X)) {
                        .LEFT_TO_RIGHT => switch (parent.get_child_layout_dir(.Y)) {
                            .TOP_TO_BOTTOM => {
                                self.position_and_align_inline_child_elements_core(parent, .X, .Y, .FORWARD, .FORWARD);
                            },
                            .BOTTOM_TO_TOP => {
                                self.position_and_align_inline_child_elements_core(parent, .X, .Y, .FORWARD, .REVERSE);
                            },
                        },
                        .RIGHT_TO_LEFT => switch (parent.get_child_layout_dir(.Y)) {
                            .TOP_TO_BOTTOM => {
                                self.position_and_align_inline_child_elements_core(parent, .X, .Y, .REVERSE, .FORWARD);
                            },
                            .BOTTOM_TO_TOP => {
                                self.position_and_align_inline_child_elements_core(parent, .X, .Y, .REVERSE, .REVERSE);
                            },
                        },
                    },
                    .Y => switch (parent.get_child_layout_dir(.X)) {
                        .LEFT_TO_RIGHT => switch (parent.get_child_layout_dir(.Y)) {
                            .TOP_TO_BOTTOM => {
                                self.position_and_align_inline_child_elements_core(parent, .Y, .X, .FORWARD, .FORWARD);
                            },
                            .BOTTOM_TO_TOP => {
                                self.position_and_align_inline_child_elements_core(parent, .Y, .X, .REVERSE, .FORWARD);
                            },
                        },
                        .RIGHT_TO_LEFT => switch (parent.get_child_layout_dir(.Y)) {
                            .TOP_TO_BOTTOM => {
                                self.position_and_align_inline_child_elements_core(parent, .Y, .X, .FORWARD, .REVERSE);
                            },
                            .BOTTOM_TO_TOP => {
                                self.position_and_align_inline_child_elements_core(parent, .Y, .X, .REVERSE, .REVERSE);
                            },
                        },
                    },
                }
            }
            if (parent.first_floating_child != NULL_IDX) {
                self.for_each_floating_child(parent, void{}, void{}, finalize_floating_child_aabb);
            }
            return self.elems;
        }

        pub fn do_action_on_all_elements(self: *LayoutManager, comptime ORDER: Utils.Traverser.Order, context_rt: anytype, comptime CONTEXT_CT: anytype, comptime ACTION_TYPE: Utils.Traverser.FuncType, action_rt: Traverse.RTFN(ACTION_TYPE, @TypeOf(context_rt), @TypeOf(CONTEXT_CT)), comptime ACTION_CT: Traverse.CTFN(ACTION_TYPE, @TypeOf(context_rt), @TypeOf(CONTEXT_CT))) anyerror!void {
            self.auto_debug(@src());
            defer self.auto_debug(@src());
            self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), ORDER, .all_child_paths(), 0, context_rt, CONTEXT_CT, ACTION_TYPE, ACTION_CT, action_rt, .MAX_STACK_LEN_NOT_IMPORTANT, void{});
        }

        pub fn free_mem(self: *LayoutManager) void {
            _ = Utils.Alloc.smart_alloc_ptr_ptrs(self.elems_alloc, &self.elems.ptr, &self.elems.len, &self.elems.cap, 0, .{}, .{});
            _ = Utils.Alloc.smart_alloc_ptr_ptrs(self.lines_alloc, &self.lines.ptr, &self.lines.len, &self.lines.cap, 0, .{}, .{});
            _ = Utils.Alloc.smart_alloc_ptr_ptrs(self.stack_alloc, &self.stack.ptr, &self.stack.len, &self.stack.cap, 0, .{}, .{});
        }
    };
}
