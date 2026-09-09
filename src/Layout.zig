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

const Size = Root.Vec2.define_vec2_type(f32);
const Pos = Root.Vec2.define_vec2_type(f32);
const Rect = Root.Rect2.define_rect2_type(f32);
const AABB = Root.AABB2.define_aabb2_type(f32);

pub const LayoutDirection = enum(u3) {
    LEFT_TO_RIGHT__TOP_TO_BOTTOM = 0b000,
    LEFT_TO_RIGHT__BOTTOM_TO_TOP = 0b001,
    RIGHT_TO_LEFT__TOP_TO_BOTTOM = 0b010,
    RIGHT_TO_LEFT__BOTTOM_TO_TOP = 0b011,
    TOP_TO_BOTTOM__LEFT_TO_RIGHT = 0b100,
    BOTTOM_TO_TOP__LEFT_TO_RIGHT = 0b101,
    TOP_TO_BOTTOM__RIGHT_TO_LEFT = 0b110,
    BOTTOM_TO_TOP__RIGHT_TO_LEFT = 0b111,

    pub inline fn primary_dir(self: LayoutDirection) Axis {
        return @enumFromInt(@as(u8, @intCast((@intFromEnum(self) >> 2) & 0b1)));
    }
    pub inline fn relative_to_axis(self: LayoutDirection, comptime AXIS: Axis) AxisRelative {
        switch (comptime AXIS) {
            .X => switch (self.primary_dir()) {
                .X => return .SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS,
                .Y => return .OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS,
            },
            .Y => switch (self.primary_dir()) {
                .Y => return .SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS,
                .X => return .OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS,
            },
        }
    }
    pub inline fn relative_to_current_and_driving_axis(self: LayoutDirection, comptime AXIS: Axis, comptime IS_DRIVING: bool) AxisRelativeDriving {
        return self.relative_to_axis(AXIS).with_driving(IS_DRIVING);
    }
    pub inline fn secondary_axis(self: LayoutDirection) Axis {
        return @enumFromInt(@as(u1, 1) ^ @as(u1, @truncate(@intFromEnum(self) >> 2)));
    }
    pub inline fn horizontal_dir(self: LayoutDirection) HorizontalDirection {
        return @enumFromInt(@as(u1, @truncate(@intFromEnum(self) >> 1)));
    }
    pub inline fn vertical_dir(self: LayoutDirection) VerticalDirection {
        return @enumFromInt(@as(u1, @truncate(@intFromEnum(self))));
    }
};

pub const AxisRelative = enum(u1) {
    SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS = 0b0,
    OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS = 0b1,

    pub inline fn with_driving(self: AxisRelative, comptime IS_DRIVING: bool) AxisRelativeDriving {
        const raw: u2 = @as(u2, @intCast(@intFromEnum(self)));
        if (comptime !IS_DRIVING) {
            raw &= 0b10;
        }
        return @enumFromInt(raw);
    }
};
pub const AxisRelativeDriving = enum(u2) {
    SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS_DRIVING_PHASE = 0b00,
    SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS_SECONDARY_PHASE = 0b10,
    OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS_DRIVING_PHASE = 0b01,
    OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS_SECONDARY_PHASE = 0b11,
};

pub const Axis = Root.Vec2.Axis;
pub const HorizontalDirection = enum(u1) {
    LEFT_TO_RIGHT = 0b0,
    RIGHT_TO_LEFT = 0b1,
};
const VerticalDirection = enum(u1) {
    TOP_TO_BOTTOM = 0b0,
    BOTTOM_TO_TOP = 0b1,
};

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

pub const SizeLimits = struct {
    min_: f32 = 0,
    max_: f32 = std.math.inf(f32),

    pub inline fn min(val: f32) SizeLimits {
        return SizeLimits{
            .min_ = val,
        };
    }
    pub inline fn max(val: f32) SizeLimits {
        return SizeLimits{
            .max_ = val,
        };
    }
    pub inline fn min_max(min_: f32, max_: f32) SizeLimits {
        return SizeLimits{
            .min_ = min_,
            .max_ = max_,
        };
    }
};

pub const GrowMode = enum(u2) {
    EXACT,
    GROW,
};

pub const SizeAxisInfo = struct {
    min: f32,
    max: f32,
    ratio: f32,
    mode: GrowMode,

    pub fn fit(start_at_max: f32) SizeAxisInfo {
        return SizeAxisInfo{
            .min = 0,
            .max = start_at_max,
            .ratio = 0,
            .mode = .SHRINK,
        };
    }
    pub fn fit_min(start_at_max: f32, min_size: f32) SizeAxisInfo {
        return SizeAxisInfo{
            .min = min_size,
            .max = start_at_max,
            .ratio = 0,
            .mode = .SHRINK,
        };
    }
    pub fn grow(start_at_min: f32, axis_ratio: f32) SizeAxisInfo {
        return SizeAxisInfo{
            .min = start_at_min,
            .max = math.inf(f32),
            .ratio = axis_ratio,
            .mode = .GROW,
        };
    }
    pub fn grow_max(start_at_min: f32, max_size: f32, axis_ratio: f32) SizeAxisInfo {
        return SizeAxisInfo{
            .min = start_at_min,
            .max = max_size,
            .ratio = axis_ratio,
            .mode = .GROW,
        };
    }
    pub fn exactly(size: f32) SizeAxisInfo {
        return SizeAxisInfo{
            .min = size,
            .max = size,
            .ratio = 0,
            .mode = .EXACT,
        };
    }
};

pub const SizeInfo = struct {
    width: SizeAxisInfo,
    height: SizeAxisInfo,

    pub inline fn width_height(w: SizeAxisInfo, h: SizeAxisInfo) SizeInfo {
        return SizeInfo{
            .width = w,
            .height = h,
        };
    }
};

pub const Padding = struct {
    left: u16 = 0,
    right: u16 = 0,
    top: u16 = 0,
    bottom: u16 = 0,

    pub inline fn uniform(pad: u16) Padding {
        return Padding{
            .left = pad,
            .right = pad,
            .top = pad,
            .bottom = pad,
        };
    }

    pub inline fn vert_horiz(pad_vert: u16, pad_horiz: u16) Padding {
        return Padding{
            .left = pad_horiz,
            .right = pad_horiz,
            .top = pad_vert,
            .bottom = pad_vert,
        };
    }

    pub inline fn left_right_top_bottom(pad_left: u16, pad_right: u16, pad_top: u16, pad_bottom: u16) Padding {
        return Padding{
            .left = pad_left,
            .right = pad_right,
            .top = pad_top,
            .bottom = pad_bottom,
        };
    }
    pub fn get(self: Padding, comptime AXIS: Axis) f32 {
        switch (comptime AXIS) {
            .X => {
                return self.x_padding();
            },
            .Y => {
                return self.y_padding();
            },
        }
    }

    pub inline fn x_padding(self: Padding) f32 {
        return num_cast(self.left, f32) + num_cast(self.right, f32);
    }
    pub inline fn y_padding(self: Padding) f32 {
        return num_cast(self.top, f32) + num_cast(self.bottom, f32);
    }
    inline fn total_float(self: Padding) Size {
        return Size.new(self.x_padding(), self.y_padding());
    }
    inline fn start_padding(self: Padding, comptime AXIS: Axis, comptime DIR: Dir) f32 {
        switch (comptime AXIS) {
            .X => switch (comptime DIR) {
                .FORWARD => return self.left,
                .REVERSE => return self.right,
            },
            .Y => switch (comptime DIR) {
                .FORWARD => return self.top,
                .REVERSE => return self.bottom,
            },
        }
    }
    inline fn end_padding(self: Padding, comptime AXIS: Axis, comptime DIR: Dir) f32 {
        switch (comptime AXIS) {
            .X => switch (comptime DIR) {
                .FORWARD => return self.right,
                .REVERSE => return self.left,
            },
            .Y => switch (comptime DIR) {
                .FORWARD => return self.bottom,
                .REVERSE => return self.top,
            },
        }
    }
};

pub const Gap = struct {
    y: u16,
    x: u16,

    pub inline fn uniform(gap: u16) Gap {
        return Gap{
            .y = gap,
            .x = gap,
        };
    }

    pub inline fn vert_horiz(gap_vert: u16, gap_horiz: u16) Gap {
        return Gap{
            .y = gap_vert,
            .x = gap_horiz,
        };
    }

    pub inline fn x_gap(self: Gap) f32 {
        return @floatFromInt(self.x);
    }
    pub inline fn total_h_gap(self: Gap, num_gaps: f32) f32 {
        return @as(f32, @floatFromInt(self.x)) * num_gaps;
    }
    pub inline fn y_gap(self: Gap) f32 {
        return @floatFromInt(self.y);
    }
    pub inline fn total_v_gap(self: Gap, num_gaps: f32) f32 {
        return @as(f32, @floatFromInt(self.y)) * num_gaps;
    }
    pub fn get(self: Gap, comptime AXIS: Axis) f32 {
        switch (comptime AXIS) {
            .X => {
                return @floatFromInt(self.x);
            },
            .Y => {
                return @floatFromInt(self.y);
            },
        }
    }
    pub fn get_total(self: Gap, comptime AXIS: Axis, num_gaps: f32) f32 {
        switch (comptime AXIS) {
            .X => {
                return @as(f32, @floatFromInt(self.x)) * num_gaps;
            },
            .Y => {
                return @as(f32, @floatFromInt(self.y)) * num_gaps;
            },
        }
    }
};

pub const SizeCheckInfo = struct {
    driving_axis: Axis,
    driving_size: f32,
    old_secondary_min: f32,
    old_secondary_max: f32,

    pub inline fn preserve_aspect_ratio_x_and_y(self: SizeCheckInfo, x: f32, y: f32) SecondarySizeResult {
        const ratio_x_to_y = x / y;
        return self.preserve_aspect_ratio_x_to_y(ratio_x_to_y);
    }
    pub inline fn preserve_aspect_ratio_x_to_y(self: SizeCheckInfo, ratio_x_to_y: f32) SecondarySizeResult {
        switch (self.driving_axis) {
            .WIDTH_DRIVES_HEIGHT => {
                const val = self.driving_size / ratio_x_to_y;
                return SecondarySizeResult{
                    .min = val,
                    .max = val,
                };
            },
            .HEIGHT_DRIVES_WIDTH => {
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

pub const SecondarySizeResult = struct {
    min: f32,
    max: f32,
};

pub const LayoutResult = struct {
    pos: Pos,
    size: Size,
    clip_aabb: AABB,
    z_index: u32,
    sibling_edges: u4,
    has_clip: bool,
};

pub const LayoutRequester = struct {
    object: *anyopaque,
    vtable: *const VTABLE,

    pub const VTABLE = struct {
        get_layout_request: *const fn (obj: *anyopaque) LayoutRequest,
        check_secondary_size: *const fn (obj: *anyopaque, check_info: SizeCheckInfo) SecondarySizeResult,
        handle_layout_result: *const fn (obj: *anyopaque, layout_result: LayoutElement) void,
        get_parent: *const fn (obj: *anyopaque) ?LayoutRequester,
        get_last_child: *const fn (obj: *anyopaque) ?LayoutRequester,
        get_prev_sibling: *const fn (obj: *anyopaque) ?LayoutRequester,
        get_user_id: *const fn (obj: *anyopaque) usize = get_id_not_impl,
        get_user_type: *const fn (obj: *anyopaque) usize = get_type_not_impl,
        get_user_name: *const fn (obj: *anyopaque) []const u8 = get_type_not_impl,
    };

    fn get_id_not_impl(_: *anyopaque) usize {
        @panic("get_user_id() not implemented on the LayoutRequester");
    }
    fn get_type_not_impl(_: *anyopaque) usize {
        @panic("get_user_type() not implemented on the LayoutRequester");
    }
    fn get_name_not_impl(_: *anyopaque) []const u8 {
        @panic("get_user_name() not implemented on the LayoutRequester");
    }

    pub inline fn get_layout_request(self: LayoutRequester) LayoutRequest {
        return self.vtable.get_layout_request(self.object);
    }
    pub inline fn check_size(self: LayoutRequester, check_info: SizeCheckInfo) SecondarySizeResult {
        return self.vtable.check_secondary_size(self.object, check_info);
    }
    pub inline fn handle_layout_result(self: LayoutRequester, layout_result: LayoutElement) void {
        return self.vtable.handle_layout_result(self.object, layout_result);
    }
    pub inline fn get_parent(self: LayoutRequester) ?LayoutRequester {
        return self.vtable.get_parent(self.object);
    }
    pub inline fn get_last_child(self: LayoutRequester) ?LayoutRequester {
        return self.vtable.get_last_child(self.object);
    }
    pub inline fn get_prev_sibling(self: LayoutRequester) ?LayoutRequester {
        return self.vtable.get_prev_sibling(self.object);
    }
    pub inline fn get_user_id(self: LayoutRequester) usize {
        return self.vtable.get_user_id(self.object);
    }
    pub inline fn get_user_type(self: LayoutRequester) usize {
        return self.vtable.get_user_type(self.object);
    }
};

pub const EventAtLocation = struct {
    object: *anyopaque,
    /// Should return `true` if the event is 'done' or `false` if it can still interact with the heirarchy
    handle_event_impl: *const fn (obj: *anyopaque, element: LayoutElement) bool,
    event_aabb: AABB,
    event_done: bool = false,

    pub fn handle_event(self: *EventAtLocation, element: LayoutElement) void {
        if (!self.event_done) {
            self.event_done = self.handle_event_impl(self.object, element);
        }
    }
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

// pub const Mouse = enum(u2) {
//     PASSTHROUGH,
//     CAPTURE,
// };

// pub const MouseState = enum(u2) {
//     NOT_HOVERED,
//     HOVERED,
//     CLICKED,
// };

// pub const FloatMode = enum(u2) {
//     NO_FLOAT,
//     FLOAT_FROM_PARENT,
//     FLOAT_FROM_ELEMENT_ID,
//     FLOT_FROM_ROOT,
// };

// pub const FloatClipping = enum(u1) {
//     NO_FLOAT_CLIPPING,
//     CLIP_TO_ATTACHED,
// };

// pub const PointerClickState = enum(u2) {
//     NOT_PRESSED,
//     JUST_PRESSED,
//     HELD_PRESSED,
//     JUST_RELEASED,
// };

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
    use_floating: bool = false,
    attach: FloatingAttachment = .{},
    offest: Pos = .ZERO,

    pub inline fn in_line() Floating {
        return Floating{};
    }
    pub inline fn floating(parent_attach: AttachPoint, child_attach: AttachPoint, offset_from_attach: Pos) Floating {
        return Floating{
            .use_floating = true,
            .attach = .{
                .parent = parent_attach,
                .child = child_attach,
            },
            .offset = offset_from_attach,
        };
    }
};

pub const LayoutRequest = struct {
    //FIXME
    size: SizeInfo,
    float: Floating = .in_line(),
    padding: Padding = .uniform(0),
    child_gaps: Gap = .uniform(0),
    child_align: ChildAlignment = .x_y(.LEFT, .TOP),
    layout_dir: LayoutDirection = .LEFT_TO_RIGHT__TOP_TO_BOTTOM,
    clip_to_parent: bool = false,
    use_flow_mode: bool = false,
};

const NULL_IDX: u32 = 0xFFFFFFFF;

const MinSize = struct {
    self: Size = .ZERO,
    children: Size = .ZERO,
};

const MinSize_OR_FinalAABB = union {
    min_size: MinSize,
    final_aabb: AABB,

    pub fn new(min_x: f32, min_y: f32) MinSize_OR_FinalAABB {
        return MinSize_OR_FinalAABB{ .min_size = .{ .self = .new(min_x, min_y) } };
    }
};

const Growable = struct {
    const NO = 0;
    const POSSIBLE = 1;
    const THIS_PASS = 2;
};

const MaxMode = enum(u3) {
    EXACT_X_EXACT_Y,
    PERCENT_X_EXACT_Y,
    EXACT_X_PERCENT_Y,
    PERCENT_X_PERCENT_Y,
};

const MaxFlags = Root.Flags.Flags(enum(u8) {
    // zig fmt:off
    MAX_IS_PARENT_PERCENT_X = 0b0000_0001,
    GROWABLE_X = 0b0000_0010,
    GROWABLE_THIS_PASS_X = 0b0000_0100,
    PROPAGATE_FLOATING_X = 0b0000_1000,
    MAX_IS_PARENT_PERCENT_Y = 0b0001_0000,
    GROWABLE_Y = 0b0010_0000,
    GROWABLE_THIS_PASS_Y = 0b0100_0000,
    PROPAGATE_FLOATING_Y = 0b1000_0000,
    // zig fmt:on

    inline fn max_is_parent_percent(comptime AXIS: Axis) @This() {
        switch (AXIS) {
            .X => return @This().MAX_IS_PARENT_PERCENT_X,
            .Y => return @This().MAX_IS_PARENT_PERCENT_Y,
        }
    }
    inline fn growable(comptime AXIS: Axis) @This() {
        switch (AXIS) {
            .X => return @This().GROWABLE_X,
            .Y => return @This().GROWABLE_Y,
        }
    }
    inline fn growable_this_pass(comptime AXIS: Axis) @This() {
        switch (AXIS) {
            .X => return @This().GROWABLE_THIS_PASS_X,
            .Y => return @This().GROWABLE_THIS_PASS_Y,
        }
    }
    inline fn propagate_floating(comptime AXIS: Axis) @This() {
        switch (AXIS) {
            .X => return @This().PROPAGATE_FLOATING_X,
            .Y => return @This().PROPAGATE_FLOATING_Y,
        }
    }
}, enum(u8) {});

const MaxSizeAndLayout = struct {
    value: Size = .INF,
    next_this_pass: u32 = NULL_IDX,
    lay1: PackedLayoutInfo1 = .{},
    lay2: PackedLayoutInfo2 = .{},
    flags: MaxFlags = .{},

    comptime {
        assert_with_reason_debug_only(@sizeOf(MaxSizeAndLayout) <= @sizeOf(AABB), null, "MaxSize must be smaller or equal size to AABB", .{});
    }
};

const MaxSize_OR_FinalClipAABB = union {
    max_size: MaxSizeAndLayout,
    final_clip_aabb: AABB,

    pub fn new(max_x: f32, max_y: f32, grow_x: bool, grow_y: bool) MaxSize_OR_FinalClipAABB {
        return MaxSize_OR_FinalClipAABB{ .max_size = .{
            .value = .new(max_x, max_y),
            .grow_x = grow_x,
            .grow_y = grow_y,
        } };
    }
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

const PackedLayoutInfo1 = packed struct(u16) {
    float_parent_attach: AttachPoint = .TOP_LEFT, // 4
    float_self_attach: AttachPoint = .TOP_LEFT, // 4 = 8
    children_axis_line_local_align: AxisLineLocalAlign = .INHERIT, // 2 = 10
    self_axis_line_local_align: AxisLineLocalAlign = .INHERIT, // 2 = 12
    child_align_x: AlignX = .LEFT, // 2 = 14
    child_align_y: AlignY = .TOP, // 2 = 16
};

const PackedLayoutInfo2 = packed struct(u8) {
    primary_child_axis: Axis = .X, // 1
    child_layout_dir_x: XDir = .LEFT_TO_RIGHT, // 1 = 2
    child_layout_dir_y: YDir = .TOP_TO_BOTTOM, // 1 = 3
};

const Traverse = Utils.Traverser.IndexBasedMultiFirstChildNextSiblingTraverser(LayoutElement, u32, NULL_IDX, &.{ "first_inline_child", "first_floating_child" }, "next_sibling");
const Nodes = Traverse.Nodes;
const Stack = Traverse.Stack;
const StackFrame = Traverse.StackFrame;
const AllowedPaths = Traverse.AllowedPaths;
const TraverseError = Utils.Traverser.Error;
const MemRealloc = Utils.Traverser.MemRealloc;
const StackReallocator = Traverse.StackReallocator;

const LayoutElement = struct {
    requester: LayoutRequester,
    _min_or_aabb: MinSize_OR_FinalAABB,
    _max_or_clip_aabb: MaxSize_OR_FinalClipAABB,
    relative_offset: Pos = .ZERO,
    padding: Padding,
    child_gaps: Gap,
    first_inline_child: u32 = NULL_IDX,
    first_floating_child: u32 = NULL_IDX,
    first_axis_line: AxisLine = .{},
    num_inline_children: u32 = 0,
    num_axis_lines: u32 = 0,
    next_sibling: u32 = NULL_IDX,
    parent_idx: u32,
    depth: u32,
    is_floating: bool,
    clip_to_parent: bool,
    completely_clipped: bool = false,
    use_flow_mode: bool,

    const SIZE = @sizeOf(LayoutElement);
    inline fn set_children_local_align(self: *LayoutElement, alla: AxisLineLocalAlign) void {
        self._max_or_clip_aabb.max_size.lay1.children_axis_line_local_align = alla;
    }
    inline fn get_children_local_align(self: LayoutElement) AxisLineLocalAlign {
        return self._max_or_clip_aabb.max_size.lay1.children_axis_line_local_align;
    }
    inline fn set_self_local_align(self: *LayoutElement, alla: AxisLineLocalAlign) void {
        self._max_or_clip_aabb.max_size.lay1.self_axis_line_local_align = alla;
    }
    inline fn get_self_local_align(self: LayoutElement) AxisLineLocalAlign {
        return self._max_or_clip_aabb.max_size.lay1.self_axis_line_local_align;
    }
    inline fn set_parent_float_attach(self: *LayoutElement, attach: AttachPoint) void {
        self._max_or_clip_aabb.max_size.lay1.float_parent_attach = attach;
    }
    inline fn get_parent_float_attach(self: LayoutElement) AttachPoint {
        return self._max_or_clip_aabb.max_size.lay1.float_parent_attach;
    }
    inline fn set_self_float_attach(self: *LayoutElement, attach: AttachPoint) void {
        self._max_or_clip_aabb.max_size.lay1.float_self_attach = attach;
    }
    inline fn get_self_float_attach(self: LayoutElement) AttachPoint {
        return self._max_or_clip_aabb.max_size.lay1.float_self_attach;
    }
    inline fn set_child_align(self: *LayoutElement, comptime AXIS: Axis, alignment: if (AXIS == .X) AlignX else AlignY) void {
        switch (comptime AXIS) {
            .X => {
                self._max_or_clip_aabb.max_size.lay1.child_align_x = alignment;
            },
            .Y => {
                self._max_or_clip_aabb.max_size.lay1.child_align_y = alignment;
            },
        }
    }
    inline fn get_child_align(self: *LayoutElement, comptime AXIS: Axis) if (AXIS == .X) AlignX else AlignY {
        switch (comptime AXIS) {
            .X => {
                return self._max_or_clip_aabb.max_size.lay1.child_align_x;
            },
            .Y => {
                return self._max_or_clip_aabb.max_size.lay1.child_align_y;
            },
        }
    }
    inline fn set_primary_child_axis(self: *LayoutElement, axis: Axis) void {
        self._max_or_clip_aabb.max_size.lay2.primary_child_axis = axis;
    }
    inline fn get_primary_child_axis(self: *LayoutElement) Axis {
        return self._max_or_clip_aabb.max_size.lay2.primary_child_axis;
    }
    inline fn set_child_layout_dir(self: *LayoutElement, comptime AXIS: Axis, dir: if (AXIS == .X) XDir else YDir) void {
        switch (comptime AXIS) {
            .X => {
                self._max_or_clip_aabb.max_size.lay2.child_layout_dir_x = dir;
            },
            .Y => {
                self._max_or_clip_aabb.max_size.lay2.child_layout_dir_y = dir;
            },
        }
    }
    inline fn get_child_layout_dir(self: *LayoutElement, comptime AXIS: Axis) if (AXIS == .X) XDir else YDir {
        switch (comptime AXIS) {
            .X => {
                return self._max_or_clip_aabb.max_size.lay2.child_layout_dir_x;
            },
            .Y => {
                return self._max_or_clip_aabb.max_size.lay2.child_layout_dir_y;
            },
        }
    }
    inline fn flags_ptr(self: *LayoutElement) *MaxFlags {
        return &self._max_or_clip_aabb.max_size.flags;
    }
    inline fn flags(self: *LayoutElement) MaxFlags {
        return self._max_or_clip_aabb.max_size.flags;
    }
    inline fn get_next_idx_this_pass(self: LayoutElement) u32 {
        return self._max_or_clip_aabb.max_size.next_this_pass;
    }
    inline fn set_next_growable_idx_this_pass(self: *LayoutElement, next: u32) void {
        self._max_or_clip_aabb.max_size.next_this_pass = next;
    }
    pub inline fn has_children(self: LayoutElement) bool {
        return self.first_child != NULL_IDX;
    }
    inline fn add_to_min_self_size(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._min_or_aabb.min_size.self.set(AXIS, self._min_or_aabb.min_size.self.get(AXIS) + val);
    }
    inline fn add_to_min_self_size_limit_to_max_update_growable(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._min_or_aabb.min_size.self.set(AXIS, self._min_or_aabb.min_size.self.get(AXIS) + val);
        const max = self.get_max_size(AXIS);
        if (self._min_or_aabb.min_size.self.get(AXIS) >= max) {
            self._min_or_aabb.min_size.self.set(AXIS, max);
            self.clear_growable(AXIS);
        }
    }
    inline fn set_min_size_self(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._min_or_aabb.min_size.self.set(AXIS, val);
    }
    inline fn set_min_size_self_limit_to_max(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._min_or_aabb.min_size.self.set(AXIS, @min(self.get_max_size(AXIS), val));
    }
    inline fn set_min_size_self_limit_to_max_update_growable(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        const max = self.get_max_size(AXIS);
        if (val >= max) {
            self._min_or_aabb.min_size.self.set(AXIS, max);
            self.clear_growable(AXIS);
        } else {
            self._min_or_aabb.min_size.self.set(AXIS, val);
        }
    }
    inline fn reevaluate_growable_from_new_min_size(self: *LayoutElement, comptime AXIS: Axis) void {
        const max = self.get_max_size(AXIS);
        if (self.is_growable(AXIS) and self._min_or_aabb.min_size.self.get(AXIS) > max) {
            self.clear_growable(AXIS);
            self.set_min_size_self(AXIS, max);
        }
    }
    inline fn get_min_size_self(self: LayoutElement, comptime AXIS: Axis) f32 {
        return self._min_or_aabb.min_size.self.get(AXIS);
    }
    inline fn update_min_size_with_children_min_size(self: *LayoutElement, comptime AXIS: Axis) void {
        self._min_or_aabb.min_size.self.set(AXIS, @max(self._min_or_aabb.min_size.self.get(AXIS), self._min_or_aabb.min_size.children.get(AXIS)));
    }
    inline fn update_min_size_with_children_min_size_limit_to_max_update_growable(self: *LayoutElement, comptime AXIS: Axis) void {
        self._min_or_aabb.min_size.self.set(AXIS, @max(self._min_or_aabb.min_size.self.get(AXIS), self._min_or_aabb.min_size.children.get(AXIS)));
        const max = self.get_max_size(AXIS);
        if (self._min_or_aabb.min_size.self.get(AXIS) >= max) {
            self._min_or_aabb.min_size.self.set(AXIS, max);
            self.clear_growable(AXIS);
        }
    }
    inline fn add_to_min_children_size(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._min_or_aabb.min_size.children.set(AXIS, self._min_or_aabb.min_size.children.get(AXIS) + val);
    }
    inline fn update_max_of_min_children_size(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._min_or_aabb.min_size.children.set(AXIS, @max(self._min_or_aabb.min_size.children.get(AXIS), val));
    }
    inline fn get_min_children_size(self: LayoutElement, comptime AXIS: Axis) f32 {
        return self._min_or_aabb.min_size.children.get(AXIS);
    }
    inline fn set_max_size(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._max_or_clip_aabb.max_size.value.set(AXIS, val);
    }
    inline fn get_max_size(self: LayoutElement, comptime AXIS: Axis) f32 {
        return self._max_or_clip_aabb.max_size.value.get(AXIS);
    }
    inline fn set_final_aabb(self: *LayoutElement, parent_abs: Pos) void {
        const final_size = self._min_or_aabb.min_size.self;
        const abs_pos = parent_abs.add(self.relative_offset);
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
    inline fn can_grow_this_pass(self: LayoutElement, comptime AXIS: Axis) bool {
        return self._max_or_clip_aabb.max_size.flags.has_flag(.growable_this_pass(AXIS));
    }
    inline fn set_can_grow_this_pass(self: *LayoutElement, comptime AXIS: Axis) void {
        self._max_or_clip_aabb.max_size.flags.set(.growable_this_pass(AXIS));
    }
    inline fn clear_can_grow_this_pass(self: *LayoutElement, comptime AXIS: Axis) void {
        self._max_or_clip_aabb.max_size.flags.clear(.growable_this_pass(AXIS));
    }
    inline fn is_growable(self: LayoutElement, comptime AXIS: Axis) bool {
        return self._max_or_clip_aabb.max_size.flags.has_flag(.growable(AXIS));
    }
    inline fn set_growable(self: *LayoutElement, comptime AXIS: Axis) void {
        self._max_or_clip_aabb.max_size.flags.set(.growable(AXIS));
    }
    inline fn clear_growable(self: *LayoutElement, comptime AXIS: Axis) void {
        self._max_or_clip_aabb.max_size.flags.clear(.growable(AXIS));
    }
    inline fn should_propagate_floating(self: LayoutElement, comptime AXIS: Axis) bool {
        return self._max_or_clip_aabb.max_size.flags.has_flag(.propagate_floating(AXIS));
    }
    inline fn set_propagate_floating(self: *LayoutElement, comptime AXIS: Axis) void {
        self._max_or_clip_aabb.max_size.flags.set(.propagate_floating(AXIS));
    }
    inline fn max_size_is_percent_of_parent(self: LayoutElement, comptime AXIS: Axis) bool {
        return self._max_or_clip_aabb.max_size.flags.has_flag(.max_is_parent_percent(AXIS));
    }
    inline fn set_max_size_is_percent_of_parent(self: *LayoutElement, comptime AXIS: Axis) void {
        self._max_or_clip_aabb.max_size.flags.set(.max_is_parent_percent(AXIS));
    }
    pub inline fn get_absolute_pos(self: *LayoutElement) Pos {
        return self._min_or_aabb.final_aabb.get_min_point();
    }
    pub inline fn get_center_point_component(self: *LayoutElement, comptime AXIS: Axis) f32 {
        return self._min_or_aabb.final_aabb.get_center_point_component(AXIS);
    }
    pub inline fn get_absolute_pos_end(self: *LayoutElement) Pos {
        return self._min_or_aabb.final_aabb.get_max_point();
    }
    pub inline fn get_final_size(self: *LayoutElement) Size {
        return self._min_or_aabb.final_aabb.get_max_point().subtract(self._min_or_aabb.final_aabb.get_min_point());
    }
    // inline fn get_next_child_axis_line(self: LayoutElement, manager_list: []LayoutElement)
};

const Error = Utils.Alloc.AllocErr || TraverseError || error{
    percent_not_in_0_to_1_range,
    internal_error,
};

pub fn size_from_aspect_ratio(ratio_x_to_y: f32, axis: Axis, axis_dimension: f32) Size {
    switch (axis) {
        .X => {
            return axis_dimension / ratio_x_to_y;
        },
        .Y => {
            return axis_dimension * ratio_x_to_y;
        },
    }
}
pub fn size_from_aspect_ratio_xy(ratio_x: f32, ratio_y: f32, axis: Axis, axis_dimension: f32) Size {
    const ratio_x_to_y: f32 = ratio_x / ratio_y;
    switch (axis) {
        .X => {
            return axis_dimension / ratio_x_to_y;
        },
        .Y => {
            return axis_dimension * ratio_x_to_y;
        },
    }
}

pub const Id = u32;

const OverlapCheck = struct {
    aabb: AABB,
    did_overlap: bool = false,
};

// const ChildIter = struct {
//     nodes: *Elems,
//     curr_child_idx: u32,

//     pub fn has_more_children(self: ChildIter) bool {
//         return self.curr_child_idx != NULL_IDX;
//     }
//     pub fn get_child(self: ChildIter)
// };

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

// const LayoutCTInfo = struct {
//     AXIS_ORDER: [2]Axis = .{ Axis.X, Axis.Y },
//     STAGE: LayoutStage = .PRIMARY_STAGE,

//     inline fn new(comptime AXIS_1: Axis, comptime AXIS_2: Axis, comptime STAGE: LayoutStage) LayoutCTInfo {
//         return LayoutCTInfo{
//             .AXIS_ORDER = .{ AXIS_1, AXIS_2 },
//             .STAGE = STAGE,
//         };
//     }
//     inline fn AXIS(comptime self: LayoutCTInfo) Axis {
//         return self.AXIS_ORDER[@intFromEnum(self.STAGE)];
//     }
//     inline fn OPPOSITE_AXIS(comptime self: LayoutCTInfo) Axis {
//         return self.AXIS_ORDER[@intFromEnum(self.STAGE) ^ 1];
//     }
//     inline fn IN_PRIMARY_STAGE(comptime self: LayoutCTInfo) bool {
//         return self.STAGE == .PRIMARY_STAGE;
//     }
//     inline fn IN_SECONDARY_STAGE(comptime self: LayoutCTInfo) bool {
//         return self.STAGE == .SECONDARY_STAGE;
//     }
// };
// const LayoutCTInfoPlus = struct {
//     AXIS_ORDER: [2]Axis = .{ Axis.X, Axis.Y },
//     STAGE: LayoutStage = .PRIMARY_STAGE,
//     PARENT_FLOW: bool = false,
//     PARENT_PRIMARY_LAYOUT: Axis = .X,

//     inline fn new(comptime info: LayoutCTInfo, comptime PARENT_FLOW: bool, comptime PARENT_PRIMARY_LAYOUT: Axis) LayoutCTInfoPlus {
//         return LayoutCTInfo{
//             .AXIS_ORDER = info.AXIS_ORDER,
//             .STAGE = info.STAGE,
//             .PARENT_FLOW = PARENT_FLOW,
//             .PARENT_PRIMARY_LAYOUT = PARENT_PRIMARY_LAYOUT,
//         };
//     }
//     inline fn AXIS(comptime self: LayoutCTInfoPlus) Axis {
//         return self.AXIS_ORDER[@intFromEnum(self.STAGE)];
//     }
//     inline fn OPPOSITE_AXIS(comptime self: LayoutCTInfoPlus) Axis {
//         return self.AXIS_ORDER[@intFromEnum(self.STAGE) ^ 1];
//     }
//     inline fn IN_PRIMARY_STAGE(comptime self: LayoutCTInfoPlus) bool {
//         return self.STAGE == .PRIMARY_STAGE;
//     }
//     inline fn IN_SECONDARY_STAGE(comptime self: LayoutCTInfoPlus) bool {
//         return self.STAGE == .SECONDARY_STAGE;
//     }
//     inline fn PARENT_LAYOUT_SAME_DIRECTION_AS_CURRENT_STAGE(comptime self: LayoutCTInfoPlus) bool {
//         return self.AXIS() == self.PARENT_PRIMARY_LAYOUT;
//     }
//     inline fn COMBINE_ADD_SIZE_AND_GAP(comptime self: LayoutCTInfoPlus) bool {
//         return self.PARENT_LAYOUT_SAME_DIRECTION_AS_CURRENT_STAGE();
//     }
//     inline fn COMBINE_UPDATE_MAX_OF_MIN_SIZES(comptime self: LayoutCTInfoPlus) bool {
//         return !self.PARENT_LAYOUT_SAME_DIRECTION_AS_CURRENT_STAGE();
//     }
//     inline fn MIGHT_HAVE_MULTIPLE_AXIS_LINES(comptime self: LayoutCTInfoPlus) bool {
//         return !self.PARENT_LAYOUT_SAME_DIRECTION_AS_CURRENT_STAGE();
//     }
// };
// const AxisStageFlow = struct {
//     AXIS: Axis,
//     STAGE: LayoutStage,
//     FLOW: bool,

//     pub inline fn new(comptime AXIS: Axis, comptime STAGE: LayoutStage, comptime FLOW: bool) AxisStageFlow {
//         return AxisStageFlow{
//             .AXIS = AXIS,
//             .STAGE = STAGE,
//             .FLOW = FLOW,
//         };
//     }
// };

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
    START_NEW_LINE,
    ADD_CURRENT_CHILD_TO_CURRENT_LINE,
};

pub const AxisLine = struct {
    first_elem: u32 = NULL_IDX,
    num_elems: u32 = 0,
    next_line: u32 = NULL_IDX,
    min_size: Size = .ZERO,
    next_growable_line_this_pass: u32 = NULL_IDX,

    pub fn init_with_negative_gap(gap: f32, comptime PRIMARY_AXIS: Axis) AxisLine {
        var size: Size = .ZERO;
        size.set(PRIMARY_AXIS, -gap);
        size.set(PRIMARY_AXIS.OPPOSITE(), 0);
        return AxisLine{
            .min_size = size,
        };
    }

    pub fn new(first_elem: u32, num_elems: u32, min: f32, comptime AXIS: Axis) AxisLine {
        var min_size = Size{};
        min_size.set(AXIS, min);
        return AxisLine{
            .first_elem = first_elem,
            .num_elems = num_elems,
            .min_size = min_size,
        };
    }
};

// const Action = struct {
//     fn set_root_final_size(elems: Elems, root_idx: u32, comptime AXIS: axis) void {
//         const root = get_elem_ptr(elems, root_idx);
//         const final_size = @min(root.get_min_size_self(AXIS), root.get_max_size(AXIS));
//         root.set_final_size(AXIS, final_size);
//     }

//     fn propagate_min_size_to_parent_y(nodes: Elems, idx: u32, _: void, comptime phase: LayoutStage) Elems {
//         const child = get_elem_ptr(nodes, idx);
//         if (child.parent_idx == NULL_IDX) return nodes;
//         const parent = get_parent_ptr(nodes, idx);
//         const gap = parent.child_gaps.vertical;
//         if (parent.layout_dir.primary_dir() == .Y and !parent.is_flow_virtual) {
//             var size = child.get_min_size_self(.Y);
//             if (parent.first_inline_child != idx) {
//                 size += gap;
//             }
//             parent.add_to_min_children_size(.Y, size);
//         } else {
//             const size = child.get_min_size_self(.Y);
//             parent.update_max_of_min_children_size(.Y, size);
//         }
//         return nodes;
//     }
//     fn fit_and_expand_children_to_fill_parent_y(nodes_: Elems, idx: u32, manager: *LayoutManager, comptime phase: LayoutStage) Elems {
//         var nodes = nodes_;
//         const parent = get_elem_ptr(nodes, idx);
//         if (phase == .PRIMARY_STAGE and parent.is_flow_virtual) {} else {}
//         return nodes;
//     }
//     fn recheck_min_y_from_final_x(nodes_: Elems, idx: u32, _: void) Elems {
//         var nodes = nodes_;
//         return nodes;
//     }
//     fn recheck_min_x_from_final_y(nodes_: Elems, idx: u32, _: void) Elems {
//         var nodes = nodes_;
//         return nodes;
//     }
//     fn position_and_align_element(nodes_: Elems, idx: u32, _: void) Elems {
//         var nodes = nodes_;
//         return nodes;
//     }
//     fn check_aabb_overlap(nodes: Elems, idx: u32, context: *OverlapCheck) Elems {
//         const elem = get_elem_ptr(nodes, idx);
//         context.did_overlap = get_elem_ptr(nodes, idx).get_clip_aabb().overlaps(context.aabb);
//         return nodes;
//     }

//     //UTILS
//     inline fn get_elem_ptr(nodes: Elems, idx: u32) *LayoutElement {
//         return &nodes.ptr[idx];
//     }
//     inline fn get_elem(nodes: Elems, idx: u32) LayoutElement {
//         return nodes.ptr[idx];
//     }
//     inline fn has_parent(nodes: Elems, idx: u32) bool {
//         return nodes.ptr[idx].parent_idx != NULL_IDX;
//     }
//     inline fn get_parent_ptr(nodes: Elems, idx: u32) *LayoutElement {
//         return &nodes.ptr[nodes.ptr[idx].parent_idx];
//     }
//     inline fn get_parent(nodes: Elems, idx: u32) LayoutElement {
//         return nodes.ptr[nodes.ptr[idx].parent_idx];
//     }
//     inline fn get_next_sibling(nodes: Elems, idx: u32) u32 {
//         return nodes.ptr[idx].next_sibling;
//     }
//     // inline fn set_next_sibling(nodes: Nodes, idx: u32, next: u32) void {
//     //     nodes.ptr[idx].next_sibling = void;
//     // }
//     inline fn split_virtual_sibling(elems_: Elems, elem_idx: u32, elem: *LayoutElement, parent: *LayoutElement, manager: *LayoutManager) Elems {
//         var elems = elems_realloc_if_needed_for_1_more(elems_, manager);
//         if (manager.err) return elems;
//         const next_idx = elems.len;
//         elems.len += 1;
//         elem.next_sibling = next_idx;
//         var cloned_elem = elem.*;
//         elems.ptr[next_idx] = sib_info;
//     }
//     inline fn elems_realloc_if_needed_for_1_more(elems_: Elems, manager: *LayoutManager) Elems {
//         var elems = elems_;
//         if (elems.len >= elems.cap) {
//             switch (manager.elem_ralloc) {
//                 .STATIC_MEM => {
//                     manager.err = Error.element_mem_out_of_space;
//                 },
//                 .ALLOW_MEM_REALLOC => |pkg| {
//                     const err: ?Utils.Alloc.AllocErr = Utils.Alloc.smart_alloc_ptr_ptrs(pkg.alloc, &elems.ptr, &elems.len, &elems.cap, elems.len + 1, pkg.settings, .{ .ERROR_MODE = .RETURN_ERRORS });
//                     if (err) |e| {
//                         manager.err = Error.element_mem_reallocation_error;
//                     }
//                 },
//             }
//         }
//         return elems;
//     }
// };

pub const LayoutDrivingAxis = enum(u1) {
    /// Width is calculated first, then elements may choose to recalculate
    /// a new height based on the finalized width before height is finalized
    ///
    /// This is the most common case, especially if the layout elements contain text
    /// primarily in left-to-right or right-to-left direction,
    WIDTH_DRIVES_HEIGHT,
    /// Height is calculated first, then elements may choose to recalculate
    /// a new width based on the finalized height before width is finalized
    ///
    /// You MAY want to use this if, for example, you will ONLY have text elements
    /// that are in the top-to-bottom or bottom-to-top direction, or some other
    /// element that NEEDS a final height before they can report a width.
    HEIGHT_DRIVES_WIDTH,
};

pub const LayoutStage = enum(u1) {
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

const Lines = struct {
    ptr: [*]AxisLine = Utils.invalid_ptr_many(AxisLine),
    len: u32 = 0,
    cap: u32 = 0,
};

const ELEM_MEM_ALIGN = @max(@alignOf(LayoutElement), @alignOf(AxisLine));

const MemUnit = union {
    ELEM: LayoutElement,
    LINE: AxisLine,
    FRAME: StackFrame,

    const SIZE = @sizeOf(MemUnit);
    const ALIGN = @alignOf(MemUnit);
};

pub fn MemInit(comptime T: type) type {
    return union(enum) {
        const Self = @This();

        STATIC: []T,
        INIT_ALLOW_RELLOC: struct {
            init_mem: []T,
            alloc: Allocator,
        },
        EMPTY_ALLOW_REALLOC: Allocator,

        pub fn static_mem(mem: []T) Self {
            return Self{
                .STATIC = mem,
            };
        }
        pub fn init_allow_realloc(mem: []T, alloc: Allocator) Self {
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

        pub fn get_mem(self: Self) []T {
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

pub const LayoutManager = struct {
    elems: Nodes = .{},
    stack: Stack = .{},
    lines: Lines = .{},
    elems_alloc: Allocator = dummy_alloc,
    lines_alloc: Allocator = dummy_alloc,
    stack_alloc: Allocator = dummy_alloc,
    real_max_elems: u32 = 0,
    real_max_lines: u32 = 0,
    real_max_stack: u32 = 0,

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

    inline fn grow_elems_if_needed(self: *LayoutManager, add_elems: u32) Error!void {
        const new_cap = self.elems.len + add_elems;
        if (new_cap > self.elems.cap) {
            try Utils.Alloc.smart_alloc(self.elems_alloc, &self.elems.ptr, &self.elems.len, &self.elems.cap, new_cap, .{}, ELEM_ALLOC_SETTINGS);
        }
    }
    inline fn grow_lines_if_needed(self: *LayoutManager, add_lines: u32) Error!void {
        const new_cap = self.lines.len + add_lines;
        if (new_cap > self.lines.cap) {
            try Utils.Alloc.smart_alloc(self.lines_alloc, &self.lines.ptr, &self.lines.len, &self.lines.cap, new_cap, .{}, ELEM_ALLOC_SETTINGS);
        }
    }
    inline fn grow_stack_if_needed(self: *LayoutManager, add_stack: u32) Error!void {
        const new_cap = self.stack.len + add_stack;
        if (new_cap > self.stack.cap) {
            try Utils.Alloc.smart_alloc(self.stack_alloc, &self.stack.ptr, &self.stack.len, &self.stack.cap, new_cap, .{}, ELEM_ALLOC_SETTINGS);
        }
    }

    inline fn get_elem_ptr(self: *LayoutManager, idx: u32) *LayoutElement {
        return &self.elems.ptr[idx];
    }
    inline fn get_line_ptr(self: *LayoutManager, idx: u32) *AxisLine {
        return &self.lines.ptr[idx];
    }
    inline fn get_stack_ptr(self: *LayoutManager, idx: u32) *StackFrame {
        return &self.stack.ptr[idx];
    }
    inline fn get_parent_ptr(elems: Nodes, idx: u32) *LayoutElement {
        return &elems.ptr[elems.ptr[idx].parent_idx];
    }

    fn append_elem_slot(self: *LayoutManager) Error!struct { *LayoutElement, u32 } {
        try self.grow_elems_if_needed(1);
        const idx = self.elems.len;
        self.elems.len += 1;
        self.real_max_elems = @max(self.real_max_elems, self.elems.len);
        const ptr = self.get_elem_ptr(idx);
        return .{ ptr, idx };
    }
    fn append_line_comps(self: *LayoutManager, first_elem: u32, num_elems: u32, min_size: f32, comptime AXIS: Axis) Error!struct { *AxisLine, u32 } {
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
    fn append_line(self: *LayoutManager, line: AxisLine) Error!u32 {
        try self.grow_lines_if_needed(1);
        const idx = self.lines.len;
        self.lines.len += 1;
        self.real_max_lines = @max(self.real_max_lines, self.lines.len);
        const ptr = self.get_line_ptr(idx);
        ptr.* = line;
        return idx;
    }
    fn append_line_get_ptr(self: *LayoutManager, line: AxisLine) Error!struct { *AxisLine, u32 } {
        try self.grow_lines_if_needed(1);
        const idx = self.lines.len;
        self.lines.len += 1;
        self.real_max_lines = @max(self.real_max_lines, self.lines.len);
        const ptr = self.get_line_ptr(idx);
        ptr.* = line;
        return .{ ptr, idx };
    }
    fn append_stack_slot(self: *LayoutManager) Error!struct { *StackFrame, u32 } {
        try self.grow_stack_if_needed(1);
        const idx = self.stack.len;
        self.stack.len += 1;
        self.real_max_stack = @max(self.real_max_stack, self.stack.len);
        const ptr = self.get_stack_ptr(idx);
        return .{ ptr, idx };
    }

    fn realloc_stack_impl(obj: *anyopaque, old_stack: Stack, needed_extra_frames: u32) Utils.Alloc.AllocErr!Stack {
        const self: *LayoutManager = @ptrCast(@alignCast(obj));
        assert_with_reason(old_stack.ptr == self.stack and old_stack.cap == self.stack_cap, @src(), "`old_stack` does not match the stack on the LayoutManager", .{});
        self.stack.len = old_stack.len;
        try self.grow_stack_if_needed(needed_extra_frames);
        return Stack{
            .ptr = self.stack,
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
    }

    inline fn append_new_elem_from_requester_and_parent_prev_sibling(self: *LayoutManager, requester: LayoutRequester, parent: u32, prev_sibling: u32) ?*LayoutElement {
        //FIXME
        if (self.elem_len >= self.elem_cap) {
            if (self.can_realloc) {
                Utils.Alloc.smart_alloc_ptr_ptrs(self.alloc, &self.elem_memory, &self.elem_len, &self.elem_cap, self.elem_len + 1, self.elem_alloc_settings, .{ .ERROR_MODE = .RETURN_ERRORS });
            } else {
                self.err = Error.ELEMENT_MEMORY_OUT_OF_SPACE;
            }
        }
        const req: LayoutRequest = requester.get_layout_request();
        assert_with_reason(parent != NULL_IDX or (req.size.width.mode == .EXACT and req.size.height.mode == .EXACT), @src(), "the root element must have `size.width.mode == .EXACT` and `size.height.mode == .EXACT`", .{});
        const new_depth = if (parent == NULL_IDX) 0 else (self.elements[parent].depth + 1);
        self.real_max_depth = @max(new_depth, self.real_max_depth);
        const elem = LayoutElement{
            .requester = requester,
            ._min_or_aabb = .new(req.size.width.min, req.size.height.min),
            ._max_or_clip_aabb = .new(req.size.width.max, req.size.height.max, req.size.width.ratio, req.size.height.ratio),
            .padding = req.padding,
            .child_gaps = req.child_gaps,
            .parent_idx = parent,
            .child_align = req.child_align,
            .layout_dir = req.layout_dir,
            .is_floating = req.float.use_floating,
            .float_offset = req.float.offest,
            .float_child_attach = req.float.attach.child,
            .float_parent_attach = req.float.attach.parent,
            .depth = new_depth,
            .clip_to_parent = req.clip_to_parent,
            .grow_mode_w = req.size.width.mode,
            .grow_mode_h = req.size.height.mode,
            .relative_offset = if (req.float.use_floating) req.float.offest else .ZERO,
            .use_flow_mode = req.use_flow_mode,
        };
        if (parent != NULL_IDX) {
            var par: *LayoutElement = &self.elements[parent];
            par.first_child = self.elem_len;
            if (par.last_child == NULL_IDX) {
                par.last_child = self.elem_len;
            }
        }
        self.elements[self.elem_len] = elem;
        self.elem_len += 1;
        return &self.elements[self.elem_len - 1];
    }

    pub fn collect_element_heirarchy(self: *LayoutManager, root_element: LayoutRequester) void {
        //FIXME
        self.elem_len = 0;
        self.append_new_elem_from_requester_and_parent_prev_sibling(root_element, NULL_IDX);
        var next_layout_idx_with_unchecked_children: u32 = 0;
        while (next_layout_idx_with_unchecked_children < self.layout_len) {
            const parent_layout: *LayoutElement = &self.elements[next_layout_idx_with_unchecked_children];
            var possible_child_element = parent_layout.requester.get_last_child();
            while (possible_child_element) |child_element| {
                const child_layout = self.append_new_elem_from_requester_and_parent_prev_sibling(child_element, next_layout_idx_with_unchecked_children);
                possible_child_element = child_layout.requester.get_prev_sibling();
            }
            next_layout_idx_with_unchecked_children += 1;
        }
        self.real_max_elements = @max(self.real_max_elements, self.elem_len);
    }

    pub fn recalculate_layout(self: *LayoutManager, comptime DRIVING_AXIS: Axis) Error!void {
        switch (comptime DRIVING_AXIS) {
            .X => {
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .CHILDREN_FIRST, 0, self, AxisStage.new(.X, .PRIMARY_STAGE), .COMPTIME_FN_PTR, propagate_min_size_to_parent, void{});
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, 0, self, AxisStage.new(.X, .PRIMARY_STAGE), .COMPTIME_FN_PTR, fit_and_expand_children_to_fill_parent, void{});
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .ANY_ORDER_NO_IDX_GAPS_ROOT_IDX_TO_LAST_IDX, 0, self, .X, .COMPTIME_FN_PTR, recheck_element_size_with_with_known_primary_size, void{});
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .CHILDREN_FIRST, 0, self, AxisStage.new(.Y, .SECONDARY_STAGE), .COMPTIME_FN_PTR, propagate_min_size_to_parent, void{});
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, 0, self, AxisStage.new(.Y, .SECONDARY_STAGE), .COMPTIME_FN_PTR, fit_and_expand_children_to_fill_parent, void{});
            },
            .Y => {
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .CHILDREN_FIRST, 0, self, AxisStage.new(.Y, .PRIMARY_STAGE), .COMPTIME_FN_PTR, propagate_min_size_to_parent, void{});
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, 0, self, AxisStage.new(.Y, .PRIMARY_STAGE), .COMPTIME_FN_PTR, fit_and_expand_children_to_fill_parent, void{});
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .ANY_ORDER_NO_IDX_GAPS_ROOT_IDX_TO_LAST_IDX, 0, self, .Y, .COMPTIME_FN_PTR, recheck_element_size_with_with_known_primary_size, void{});
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .CHILDREN_FIRST, 0, self, AxisStage.new(.X, .SECONDARY_STAGE), .COMPTIME_FN_PTR, propagate_min_size_to_parent, void{});
                self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, 0, self, AxisStage.new(.X, .SECONDARY_STAGE), .COMPTIME_FN_BODY, fit_and_expand_children_to_fill_parent, void{});
            },
        }
        self.elems, self.stack = try Traverse.do_action_on_all_nodes(self.elems, self.stack, self.stack_reallocator(), .PARENTS_FIRST, 0, self, void{}, .COMPTIME_FN_PTR, position_and_align_child_elements, void{});
    }

    fn propagate_min_size_to_parent(elems: Nodes, idx: u32, _: *LayoutManager, comptime CT: AxisStage) anyerror!Nodes {
        const child = get_elem_ptr(elems, idx);
        child.add_to_min_children_size(CT.AXIS, child.padding.get(CT.AXIS));
        child.update_min_size_with_children_min_size(CT.AXIS);
        if (child.is_floating or child.parent_idx == NULL_IDX) return elems;
        const parent = get_parent_ptr(elems, idx);
        const gap = parent.child_gaps.get(CT.AXIS);
        if (parent.primary_child_axis == CT.AXIS and !parent.use_flow_mode) {
            const add_min_size = child.get_min_size_self(CT.AXIS) + gap;
            parent.add_to_min_children_size(CT.AXIS, add_min_size);
        } else {
            const min_size = child.get_min_size_self(CT.AXIS);
            parent.update_max_of_min_children_size(CT.AXIS, min_size);
        }
        return elems;
    }

    fn combine_all_children_with_axis_lines(self: *LayoutManager, parent: *LayoutElement, comptime CT: AxisStage, comptime COMBINE_MODE: CombineMode, comptime WRAP_MODE: WrapMode) anyerror!void {
        const max_size_for_children = parent.get_min_size_self(CT.AXIS) - parent.padding.get(CT.AXIS);
        var child: *LayoutElement = undefined;
        var child_idx = parent.first_inline_child;
        const gap = parent.child_gaps.get(Axis);
        if (CT.STAGE == .PRIMARY_STAGE) {
            parent.first_axis_line = AxisLine.init_with_negative_gap(gap, CT.AXIS);
        }
        var line = &parent.first_axis_line;
        var children_left_on_parent = parent.num_inline_children;
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

    fn combine_child_with_axis_line(self: *LayoutManager, line: *AxisLine, child: *LayoutElement, child_idx: u32, more_children_on_parent: bool, more_children_on_line: bool, gap: f32, max_size: f32, comptime AXIS: Axis, comptime COMBINE_MODE: CombineMode, comptime WRAP_MODE: WrapMode, comptime STAGE: LayoutStage) anyerror!*AxisLine {
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
                        const total_gap = (line.num_elems - 1) * gap;
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
                        const total_gap = (line.num_elems - 1) * gap;
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
                if (child.is_growable(AXIS) == .GROW) {
                    line.max_secondary_grow = @max(line.max_secondary_grow, child.get_grow_ratio(AXIS));
                }
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

    fn distribute_primary_extra_space_to_axis_line_members(self: *LayoutManager, axis_line: *AxisLine, space: f32, comptime AXIS: Axis) void {
        var remaining_space = space;
        while (remaining_space > 0) {
            var idx: u32 = axis_line.first_elem;
            var n: u32 = axis_line.num_elems;
            var child: *LayoutElement = undefined;
            var total_growable_children_this_pass: u32 = 0;
            var smallest_growable_child_this_pass: f32 = math.inf(f32);
            var second_smallest_growable_child_this_pass: f32 = math.inf(f32);
            var grow_limit_this_pass: f32 = math.inf(f32);
            var first_growable_child_this_pass: u32 = NULL_IDX;
            var prev_growable_child_this_pass: u32 = NULL_IDX;
            while (n > 0) {
                n - 1;
                child = get_elem_ptr(self.elems, idx);
                if (child.is_growable(AXIS)) {
                    if (Math.approx_equal(f32, child.get_min_size_self(AXIS), smallest_growable_child_this_pass)) {
                        const prev_child: *LayoutElement = self.get_elem_ptr(prev_growable_child_this_pass);
                        prev_child.set_next_growable_idx_this_pass(idx);
                        prev_growable_child_this_pass = idx;
                        total_growable_children_this_pass += 1;
                        grow_limit_this_pass = @min(grow_limit_this_pass, child.get_max_size(AXIS));
                    } else if (Math.approx_less_than(f32, child.get_min_size_self(AXIS), smallest_growable_child_this_pass)) {
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
            const nn: f32 = @floatFromInt(n);
            const max_space_per_child_this_pass = grow_limit_this_pass - smallest_growable_child_this_pass;
            var space_per_child_this_pass = remaining_space / nn;
            space_per_child_this_pass = @min(space_per_child_this_pass, max_space_per_child_this_pass);
            const space_taken_this_pass = nn * space_per_child_this_pass;
            if (space_taken_this_pass <= math.floatEps(f32)) break;
            while (n > 0) {
                n - 1;
                child = get_elem_ptr(self.elems, idx);
                child.add_to_min_self_size_limit_to_max_update_growable(AXIS, space_per_child_this_pass);
                idx = child.get_next_idx_this_pass();
            }
            remaining_space -= space_taken_this_pass;
            axis_line.min_size.set(AXIS, axis_line.min_size.get(AXIS) + space_taken_this_pass);
        }
    }

    fn distribute_secondary_extra_space_to_all_axis_lines(self: *LayoutManager, parent: *LayoutElement, comptime AXIS: Axis) void {
        const gap = parent.child_gaps.get(AXIS);
        var line = &parent.first_axis_line;
        var lines_left: u32 = parent.num_axis_lines;
        var total_axis_lines_size: f32 = -gap;
        while (lines_left > 0) {
            lines_left -= 1;
            total_axis_lines_size += line.min_size.get(AXIS) + gap;
            var children_left = line.num_elems;
            var child_idx: u32 = line.first_elem;
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
            var axis_line_idx: u32 = NULL_IDX;
            var child: *LayoutElement = undefined;
            var total_growable_lines_this_pass: u32 = 0;
            var total_growable_children_this_pass: u32 = 0;
            var child_grow_limit_this_pass: f32 = math.inf(f32);
            var prev_growable_line_this_pass: u32 = NULL_IDX;
            var first_growable_line_this_pass: u32 = NULL_IDX;
            var smallest_growable_child_this_pass: f32 = math.inf(f32);
            var second_smallest_growable_child_this_pass: f32 = math.inf(f32);
            var first_growable_child_this_pass: u32 = NULL_IDX;
            var prev_growable_child_this_pass: u32 = NULL_IDX;
            var children_left: u32 = undefined;
            while (lines_left > 0) {
                lines_left - 1;
                children_left = line.num_elems;
                var child_idx: u32 = line.first_elem;
                while (children_left > 0) {
                    children_left - 1;
                    child = get_elem_ptr(self.elems, child_idx);
                    if (child.is_growable(AXIS)) {
                        if (Math.approx_equal(f32, child.get_min_size_self(AXIS), smallest_growable_child_this_pass)) {
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
                        } else if (Math.approx_less_than(f32, child.get_min_size_self(AXIS), smallest_growable_child_this_pass)) {
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
            const total_growable_lines_this_pass_f32: f32 = @floatFromInt(total_growable_lines_this_pass);
            const max_space_per_child_this_pass = child_grow_limit_this_pass - smallest_growable_child_this_pass;
            var space_per_child_this_pass = remaining_space / total_growable_lines_this_pass_f32;
            space_per_child_this_pass = @min(space_per_child_this_pass, max_space_per_child_this_pass);
            const space_taken_this_pass = total_growable_lines_this_pass_f32 * space_per_child_this_pass;
            if (space_taken_this_pass <= math.floatEps(f32)) break;
            while (children_left > 0) {
                children_left - 1;
                child = get_elem_ptr(self.elems, child_idx);
                child.add_to_min_self_size_limit_to_max_update_growable(AXIS, space_per_child_this_pass);
                child_idx = child.get_next_idx_this_pass();
            }
            line = if (first_growable_line_this_pass == NULL_IDX) &parent.first_axis_line else self.get_line_ptr(first_growable_line_this_pass);
            while (lines_left > 0) {
                lines_left - 1;
                line.min_size.set(AXIS, line.min_size.get(AXIS) + space_per_child_this_pass);
                if (lines_left > 0) {
                    line = self.get_line_ptr(line.next_growable_line_this_pass);
                }
            }
            remaining_space -= space_taken_this_pass;
        }
    }

    fn fit_and_expand_children_to_fill_parent(_: Nodes, idx: u32, self: *LayoutManager, comptime CT: AxisStage) anyerror!Nodes {
        const parent = self.get_elem_ptr(idx);
        if ((parent.is_floating and !parent.should_propagate_floating(CT.AXIS)) or parent.parent_idx == NULL_IDX) {
            parent.set_min_size_self_limit_to_max_update_growable(CT.AXIS, parent.get_min_size_self(CT.AXIS));
        }
        if (parent.first_inline_child != NULL_IDX) {
            assert_with_reason_debug_only(parent.num_inline_children > 0, @src(), "first child on parent wasnt NULL, but parent has no children count", .{});
            if (parent.use_flow_mode) {
                if (parent.primary_child_axis == CT.AXIS) {
                    try self.combine_all_children_with_axis_lines(parent, CT, .ADD_MIN_SIZE_AND_GAP, .ALLOW_WRAP);
                } else {
                    try self.combine_all_children_with_axis_lines(parent, CT, .UPDATE_MAX_OF_MIN_SIZE, .ALLOW_WRAP);
                }
            } else {
                if (parent.primary_child_axis == CT.AXIS) {
                    try self.combine_all_children_with_axis_lines(parent, CT, .ADD_MIN_SIZE_AND_GAP, .NO_WRAP);
                } else {
                    try self.combine_all_children_with_axis_lines(parent, CT, .UPDATE_MAX_OF_MIN_SIZE, .NO_WRAP);
                }
            }
        }
        return self.elems;
    }

    fn recheck_element_size_with_with_known_primary_size(_: Nodes, idx: u32, self: *LayoutManager, comptime DRIVING_AXIS: Axis) anyerror!Nodes {
        const SECONDARY_AXIS = comptime DRIVING_AXIS.OPPOSITE();
        const elem = self.get_elem_ptr(idx);
        const check_info = SizeCheckInfo{
            .driving_axis = DRIVING_AXIS,
            .driving_size = elem.get_min_size_self(DRIVING_AXIS),
            .old_secondary_min = elem.get_min_size_self(SECONDARY_AXIS),
            .old_secondary_max = elem.get_max_size(SECONDARY_AXIS),
        };
        const new_secondary_size = elem.requester.check_size(check_info);
        elem.set_min_size_self(SECONDARY_AXIS, new_secondary_size.min);
        elem.set_max_size(SECONDARY_AXIS, new_secondary_size.max);
        return self.elems;
    }

    inline fn for_each_axis_line(self: *LayoutManager, parent: *LayoutElement, context: anytype, comptime CONTEXT: anytype, comptime action: fn (*LayoutManager, *LayoutElement, *AxisLine, @TypeOf(context), comptime @TypeOf(CONTEXT)) void) void {
        var line: *AxisLine = &parent.first_axis_line;
        var n = parent.num_axis_lines;
        if (n == 0) return;
        action(self, parent, line, context);
        n -= 1;
        while (n > 0) {
            line = self.get_line_ptr(line.next_line);
            n -= 1;
            action(self, parent, line, context);
        }
    }

    inline fn for_each_child_on_axis_line(self: *LayoutManager, parent: *LayoutElement, line: *AxisLine, context: anytype, comptime CONTEXT: anytype, comptime action: fn (*LayoutManager, *LayoutElement, *AxisLine, u32, *LayoutElement, @TypeOf(context), comptime @TypeOf(CONTEXT)) void) void {
        var child_idx: u32 = line.first_elem;
        var child: *LayoutElement = undefined;
        var n: u32 = line.num_elems;
        while (n > 0) {
            n -= 1;
            child = self.get_elem_ptr(child_idx);
            action(self, parent, line, child_idx, child, context);
            child_idx = child.next_sibling;
        }
    }

    inline fn for_each_floating_child(self: *LayoutManager, parent: *LayoutElement, context: anytype, comptime CONTEXT: anytype, comptime action: fn (*LayoutManager, *LayoutElement, u32, *LayoutElement, @TypeOf(context), comptime @TypeOf(CONTEXT)) void) void {
        var child_idx: u32 = parent.first_floating_child;
        var child: *LayoutElement = undefined;
        while (child_idx != NULL_IDX) {
            child = self.get_elem_ptr(child_idx);
            action(self, parent, child_idx, child, context);
            child_idx = child.next_sibling;
        }
    }

    const PosAlignData_S = struct {
        cursor_axis_line_start_p: f32,
        cursor_pos_s: f32,
        num_gaps_s: u32,
        base_gap_p: f32,
        gap_s: f32,
        parent_size: Size,
        parent_size_minus_padding: Size,
        parent_abs_pos: Pos,
        child_align_p: Align,
        child_align_s: Align,
    };
    const PosAlignData_P = struct {
        cursor_pos_p: f32,
        cursor_pos_s: f32,
        gap_p: f32,
        gap_s: f32,
    };
    const PosAlignData_CT = struct {
        PRIME_AXIS: Axis,
        SEC_AXIS: Axis,
        PRIME_DIR: Dir,
        SEC_DIR: Dir,
        NEGATIVE_DELTA_P: bool,
        NEGATIVE_DELTA_S: bool,
        SUBTRACT_CHILD_SIZE_FROM_CURSOR_P: bool,
        SUBTRACT_CHILD_SIZE_FROM_CURSOR_S: bool,
    };
    const AxisSizeData = struct {
        base_gap: f32,
        total_size: f32,
    };

    fn position_and_align_childen_on_axis_line(self: *LayoutManager, parent: *LayoutElement, line: *AxisLine, data_s: *PosAlignData_S, comptime DATA: PosAlignData_CT) void {
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
                    leftover_primary_space = leftover_primary_space / (line.num_elems - 1);
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
    fn add_primary_size_to_total(_: *LayoutManager, _: *LayoutElement, _: *AxisLine, _: u32, child: *LayoutElement, data: *AxisSizeData, comptime PRIME_AXIS: Axis) void {
        data.total_size += child.get_min_size_self(PRIME_AXIS) + data.base_gap;
    }
    fn finalize_inline_child_aabb(_: *LayoutManager, parent: *LayoutElement, line: *AxisLine, _: u32, child: *LayoutElement, data: *PosAlignData_P, comptime DATA: PosAlignData_CT) void {
        const child_size_p = child.get_min_size_self(DATA.PRIME_AXIS);
        const child_size_s = child.get_min_size_self(DATA.SEC_AXIS);

        if (comptime DATA.NEGATIVE_DELTA_P) {
            data.cursor_pos_p -= child_size_p;
        }
        var child_pos_s: f32 = data.cursor_pos_s;
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
        const final_pos = Pos.new(if (comptime DATA.PRIME_AXIS == .X) data.cursor_pos_p else child_pos_s, if (comptime DATA.PRIME_AXIS == .Y) data.cursor_pos_p else child_pos_s).add(child.relative_offset);
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
    fn finalize_floating_child_aabb(_: *LayoutManager, parent: *LayoutElement, _: u32, child: *LayoutElement, _: void, _: void) void {
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
        child_pos_x += child.relative_offset.x;
        child_pos_y += child.relative_offset.y;
        child._min_or_aabb.final_aabb == AABB.new_from_pos_size(Pos.new(child_pos_x, child_pos_y), child_size);
        if (child.clip_to_parent) {
            child._max_or_clip_aabb.final_clip_aabb, child.completely_clipped = child._min_or_aabb.final_aabb.overlap_area_and_overlap_area_zero_or_negative(parent._max_or_clip_aabb.final_clip_aabb);
        } else {
            child._max_or_clip_aabb.final_clip_aabb = child._min_or_aabb.final_aabb;
        }
    }

    fn position_and_align_inline_child_elements_core(self: *LayoutManager, parent: *LayoutElement, comptime PRIME_AXIS: Axis, comptime SEC_AXIS: Axis, comptime PRIME_DIR: Dir, comptime SEC_DIR: Dir) void {
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
        const parent_size_minus_padding = parent_size.subtract(padding.total_float());
        const child_align_s = parent.child_align.get(SEC_AXIS);
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
                    leftover_secondary_space = leftover_secondary_space / num_gaps_s;
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
            .child_align_p = parent.child_align.get(PRIME_AXIS),
            .child_align_s = child_align_s,
        };
        self.for_each_axis_line(parent, &data, DATA, position_and_align_childen_on_axis_line);
    }

    fn position_and_align_child_elements(_: Nodes, idx: u32, self: *LayoutManager, comptime _: void) anyerror!Nodes {
        var parent: *LayoutElement = self.get_elem_ptr(idx);
        if (parent.parent_idx == NULL_IDX) {
            @branchHint(.unlikely);
            const final_size = parent._min_or_aabb.min_size.self;
            parent._min_or_aabb.final_aabb = AABB.new(parent.relative_offset.x, parent.relative_offset.x + final_size.x, parent.relative_offset.y, parent.relative_offset.y + final_size.y);
        }
        if (parent.num_inline_children > 0) {
            switch (parent.primary_child_axis) {
                .X => switch (parent.child_layout_dir_x) {
                    .LEFT_TO_RIGHT => switch (parent.child_layout_dir_y) {
                        .TOP_TO_BOTTOM => {
                            self.position_and_align_inline_child_elements_core(parent, .X, .Y, .FORWARD, .FORWARD);
                        },
                        .BOTTOM_TO_TOP => {
                            self.position_and_align_inline_child_elements_core(parent, .X, .Y, .FORWARD, .REVERSE);
                        },
                    },
                    .RIGHT_TO_LEFT => switch (parent.child_layout_dir_y) {
                        .TOP_TO_BOTTOM => {
                            self.position_and_align_inline_child_elements_core(parent, .X, .Y, .REVERSE, .FORWARD);
                        },
                        .BOTTOM_TO_TOP => {
                            self.position_and_align_inline_child_elements_core(parent, .X, .Y, .REVERSE, .REVERSE);
                        },
                    },
                },
                .Y => switch (parent.child_layout_dir_x) {
                    .LEFT_TO_RIGHT => switch (parent.child_layout_dir_y) {
                        .TOP_TO_BOTTOM => {
                            self.position_and_align_inline_child_elements_core(parent, .Y, .X, .FORWARD, .FORWARD);
                        },
                        .BOTTOM_TO_TOP => {
                            self.position_and_align_inline_child_elements_core(parent, .Y, .X, .REVERSE, .FORWARD);
                        },
                    },
                    .RIGHT_TO_LEFT => switch (parent.child_layout_dir_y) {
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
};
