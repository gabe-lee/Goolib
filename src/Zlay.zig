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
const dummy_alloc= DummyAlloc.allocator_panic_free_noop;

const assert_with_reason = Assert.assert_with_reason;
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

    pub inline fn with_driving(self: AxisRelative, comptime IS_DRIVING: bool)  AxisRelativeDriving {
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

pub const AlignX = enum(u2) {
    LEFT,
    MIDDLE,
    RIGHT,
    JUSTIFY,
};

pub const AlignY = enum(u2) {
    TOP,
    CENTER,
    BOTTOM,
    JUSTIFY,
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
    SHRINK,
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
                return @floatFromInt(self.left + self.right);
            },
            .Y => {
                return @floatFromInt(self.top + self.bottom);
            },
        }
    }

    pub inline fn h_padding(self: Padding) f32 {
        return @floatFromInt(self.left + self.right);
    }
    pub inline fn v_padding(self: Padding) f32 {
        return @floatFromInt(self.top + self.bottom);
    }
};

pub const Gap = struct {
    vertical: u16,
    horizontal: u16,

    pub inline fn uniform(gap: u16) Gap {
        return Gap{
            .vertical = gap,
            .horizontal = gap,
        };
    }

    pub inline fn vert_horiz(gap_vert: u16, gap_horiz: u16) Gap {
        return Gap{
            .vertical = gap_vert,
            .horizontal = gap_horiz,
        };
    }

    pub inline fn h_gap(self: Gap) f32 {
        return @floatFromInt(self.horizontal);
    }
    pub inline fn total_h_gap(self: Gap, num_gaps: f32) f32 {
        return @as(f32, @floatFromInt(self.horizontal)) * num_gaps;
    }
    pub inline fn v_gap(self: Gap) f32 {
        return @floatFromInt(self.vertical);
    }
    pub inline fn total_v_gap(self: Gap, num_gaps: f32) f32 {
        return @as(f32, @floatFromInt(self.vertical)) * num_gaps;
    }
    pub fn get(self: Gap, comptime AXIS: Axis) f32 {
        switch (comptime AXIS) {
            .X => {
                return @floatFromInt(self.horizontal);
            },
            .Y => {
                return @floatFromInt(self.vertical);
            },
        }
    }
    pub fn get_total(self: Gap, comptime AXIS: Axis, num_gaps: f32) f32 {
        switch (comptime AXIS) {
            .X => {
                return @as(f32, @floatFromInt(self.horizontal)) * num_gaps;
            },
            .Y => {
                return @as(f32, @floatFromInt(self.vertical)) * num_gaps;
            },
        }
    }
};

pub const SizeCheckInfo = struct {
    driving_axis: LayoutDrivingAxis,
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

pub const AttachPoint = enum(u5) {
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

pub const Mouse = enum(u2) {
    PASSTHROUGH,
    CAPTURE,
};

pub const MouseState = enum(u2) {
    NOT_HOVERED,
    HOVERED,
    CLICKED,
};

pub const FloatMode = enum(u2) {
    NO_FLOAT,
    FLOAT_FROM_PARENT,
    FLOAT_FROM_ELEMENT_ID,
    FLOT_FROM_ROOT,
};

pub const FloatClipping = enum(u1) {
    NO_FLOAT_CLIPPING,
    CLIP_TO_ATTACHED,
};

pub const PointerClickState = enum(u2) {
    NOT_PRESSED,
    JUST_PRESSED,
    HELD_PRESSED,
    JUST_RELEASED,
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
    size: SizeInfo,
    float: Floating = .in_line(),
    padding: Padding = .uniform(0),
    child_gaps: Gap = .uniform(0),
    child_align: ChildAlignment = .x_y(.LEFT, .TOP),
    layout_dir: LayoutDirection = .LEFT_TO_RIGHT__TOP_TO_BOTTOM,
    clip_to_parent: bool = false,
    use_flow_mode: bool = false,
};

pub const PointerState = struct {
    pos: Pos = .ZERO,
    buttons: PointerButtons = .{},
};

pub const PointerButtons = struct {
    left: PointerClickState = .NOT_PRESSED,
    right: PointerClickState = .NOT_PRESSED,
};

pub const PointerStateOverElementInProcess = struct {
    buttons: PointerButtons = .{},
    is_over: bool = false,
};

pub const PointerStateOverElementFinal = struct {
    buttons: PointerButtons = .{},
    abs_pos: Pos,
    rel_pos: Pos,
    is_over: bool = false,
};

const NULL_IDX: u32 = 0xFFFFFFFF;

const MinLeftoverFinal = struct {
    min_self_or_leftover: Size,
    min_children_or_final: Size = .ZERO,
};

const MinLeftoverFinal_OR_FinalAABB = union {
    size: MinLeftoverFinal,
    final_aabb: AABB,
    final_rect: Rect,

    pub fn new(min_x: f32, min_y: f32) MinLeftoverFinal_OR_FinalAABB {
        return MinLeftoverFinal_OR_FinalAABB{ .size = .{ .min_self_or_leftover = .new(min_x, min_y) } };
    }
};

const MaxSizeGrowRatio = struct {
    max: Size,
    ratio: Size,
};

const MaxSizeGrowRatio_OR_FinalClipAABB = union {
    size_grow: MaxSizeGrowRatio,
    final_clip_aabb: AABB,

    pub fn new(max_x: f32, max_y: f32, grow_x: f32, grow_y: f32) MaxSizeGrowRatio_OR_FinalClipAABB {
        return MaxSizeGrowRatio_OR_FinalClipAABB{ .size_grow = .{
            .max = .new(max_x, max_y),
            .ratio = .new(grow_x, grow_y),
        } };
    }
};


const Traverse = Utils.Traverser.IndexBasedMultiFirstChildNextSiblingTraverser(LayoutElement, u32, NULL_IDX, &.{"first_inline_child", "first_floating_child"}, "next_sibling");
const Elems = Traverse.Elems;
const Stack = Traverse.Stack;
const StackFrame = Traverse.StackFrame;
const AllowedPaths = Traverse.AllowedPaths;
const TraverseError = Utils.Traverser.Error;
const MemRealloc = Utils.Traverser.MemRealloc;

const LayoutElement = struct {
    requester: LayoutRequester, // 16
    _ms_fbb: MinLeftoverFinal_OR_FinalAABB, // 16
    _mg_fcbb: MaxSizeGrowRatio_OR_FinalClipAABB, // 16
    relative_pos: Pos = .ZERO, // 8
    padding: Padding, // 8
    child_gaps: Gap, // 4
    first_inline_child: u32 = NULL_IDX, // 4
    first_floating_child: u32 = NULL_IDX, // 4
    first_axis_line: u32 = NULL_IDX, // 4
    num_inline_children: u32 = 0, // 4
    num_axis_lines: u32 = 0, // 4
    next_sibling: u32 = NULL_IDX, // 4
    parent_idx: u32, // 4
    depth: u32, // 4
    child_align: ChildAlignment, // 2
    float_parent_attach: AttachPoint, // 1
    float_child_attach: AttachPoint, // 1
    layout_dir: LayoutDirection, // 1
    is_floating: bool, // 1
    clip_to_parent: bool, // 1
    grow_mode_w: GrowMode, // 1
    grow_mode_h: GrowMode, // 1
    completely_clipped: bool = false, // 1
    use_flow_mode: bool = false, // 1

    const SIZE = @sizeOf(LayoutElement);

    pub inline fn has_children(self: LayoutElement) bool {
        return self.first_child != NULL_IDX;
    }
    pub inline fn get_children(self: LayoutElement, manager_list: []LayoutElement) SiblingSlice {
        assert_with_reason(self.has_children(), @src(), "no children on element", .{});
        const num_children = (self.first_child - self.last_child) + 1;
        return SiblingSlice{
            .first_sibling_abs_idx = self.first_child,
            .len = num_children,
            .last_to_first = manager_list.ptr + self.last_child,
        };
    }
    inline fn set_axis_line_idx_on_parent(self: *LayoutElement, val: u32) void {
        self.num_floating_siblings_on_axis_line = val;
    }
    inline fn get_axis_line_idx_on_parent(self: *LayoutElement) u32 {
        return self.num_floating_siblings_on_axis_line;
    }
    inline fn set_axis_line_num_sibs_on_parent(self: *LayoutElement, val: u32) void {
        self.num_total_siblings_on_sib_axis_line = val;
    }
    inline fn get_axis_line_num_sibs_on_parent(self: *LayoutElement) u32 {
        return self.num_total_siblings_on_sib_axis_line;
    }
    inline fn set_axis_line_leftover_space_on_parent(self: *LayoutElement, val: f32) void {
        self.leftover_space_on_sib_axis_line = val;
    }
    inline fn get_axis_line_leftover_space_on_parent(self: *LayoutElement) f32 {
        return self.leftover_space_on_sib_axis_line;
    }
    inline fn set_min_self_size(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._ms_fbb.size.min_self_or_leftover.set(AXIS, val);
    }
    inline fn get_min_self_size(self: LayoutElement, comptime AXIS: Axis) f32 {
        return self._ms_fbb.size.min_self_or_leftover.get(AXIS);
    }
    inline fn update_min_size_if_larger(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._ms_fbb.size.min_self_or_leftover.set(AXIS, @max(self._ms_fbb.size.min_self_or_leftover.get(AXIS), val));
    }
    inline fn set_space_leftover(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._ms_fbb.size.min_self_or_leftover.set(AXIS, val);
    }
    inline fn get_space_leftover(self: LayoutElement, comptime AXIS: Axis) f32 {
        return self._ms_fbb.size.min_self_or_leftover.get(AXIS);
    }
    inline fn set_min_children(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._ms_fbb.size.min_children_or_final.set(AXIS, val);
    }
    inline fn add_to_min_children_size(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._ms_fbb.size.min_children_or_final.set(AXIS, self._ms_fbb.size.min_children_or_final.get(AXIS) + val);
    }
    inline fn max_of_min_children_size(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._ms_fbb.size.min_children_or_final.set(AXIS, @max(self._ms_fbb.size.min_children_or_final.get(AXIS), val));
    }
    inline fn get_min_children(self: LayoutElement, comptime AXIS: Axis) f32 {
        return self._ms_fbb.size.min_children_or_final.get(AXIS);
    }
    inline fn set_final_size(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._ms_fbb.size.min_children_or_final.set(AXIS, val);
    }
    inline fn get_final_size(self: LayoutElement, comptime AXIS: Axis) f32 {
        return self._ms_fbb.size.min_children_or_final.get(AXIS);
    }
    inline fn set_max(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._mg_fcbb.size_grow.max.set(AXIS, val);
    }
    inline fn get_max_size(self: LayoutElement, comptime AXIS: Axis) f32 {
        return self._mg_fcbb.size_grow.max.get(AXIS);
    }
    inline fn set_grow_ratio(self: *LayoutElement, comptime AXIS: Axis, val: f32) void {
        self._mg_fcbb.size_grow.ratio.set(AXIS, val);
    }
    inline fn get_grow_ratio(self: LayoutElement, comptime AXIS: Axis) f32 {
        return self._mg_fcbb.size_grow.ratio.get(AXIS);
    }
    inline fn set_final_aabb(self: *LayoutElement, parent_abs: Pos) void {
        const final_size = self._ms_fbb.size.min_children_or_final;
        const abs_pos = parent_abs.add(self.relative_pos);
        self._ms_fbb.final_aabb = AABB.new_from_pos_size(abs_pos, final_size);
    }
    inline fn set_clip_aabb(self: *LayoutElement, parent_clip: AABB) void {
        const overlap_aabb, const not_completely_clipped = self.get_aabb().overlap_area_and_overlap_greater_than_zero(parent_clip);
        self._mg_fcbb.final_clip_aabb = overlap_aabb;
        self.completely_clipped = !not_completely_clipped;
    }
    pub inline fn get_aabb(self: LayoutElement) AABB {
        return self._ms_fbb.final_aabb;
    }
    pub inline fn get_clip_aabb(self: LayoutElement) AABB {
        return self._mg_fcbb.final_clip_aabb;
    }
    inline fn get_grow_mode(self: LayoutElement, comptime AXIS: Axis) GrowMode {
        switch (comptime AXIS) {
            .X => return self.grow_mode_w,
            .Y => return self.grow_mode_h,
        }
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

const ChildIter = struct {
    nodes: *Elems,
    curr_child_idx: u32,

    pub fn has_more_children(self: ChildIter) bool {
        return self.curr_child_idx != NULL_IDX;
    }
    pub fn get_child(self: ChildIter)
};

const AxisStage = struct {
    AXIS: Axis,
    STAGE: LayoutStage,

    pub inline fn mode(comptime AXIS: Axis, comptime STAGE: LayoutStage) AxisStage {
        return AxisStage{
            .AXIS = AXIS,
            .STAGE = STAGE,
        };
    }
};

pub const AxisLine = struct {
    first_elem: u32 = NULL_IDX,
    num_elems: u32 = 0,
    next_line: u32 = NULL_IDX,
    min_size: Size = .ZERO,
};

const Action = struct {
    fn set_root_final_size(elems: Elems, root_idx: u32, comptime AXIS: axis) void {
        const root = get_elem_ptr(elems, root_idx);
        const final_size = @min(root.get_min_self_size(AXIS), root.get_max_size(AXIS));
        root.set_final_size(AXIS, final_size);
    }
    fn propagate_min_size_to_parent(elems: Elems, idx: u32, _: void, comptime CT: AxisStage) Elems {
        const child = get_elem_ptr(elems, idx);
        child.add_to_min_children_size(CT.AXIS, child.padding.get(CT.AXIS));
        child.set_min_self_size(CT.AXIS, @max(child.get_min_self_size(CT.AXIS), child.get_min_children(CT.AXIS)));
        if (child.is_floating or child.parent_idx == NULL_IDX) return elems;
        const parent = get_parent_ptr(elems, idx);
        const gap = parent.child_gaps.get(CT.AXIS);
        if (parent.layout_dir.primary_dir() == CT.AXIS and !parent.is_flow_virtual) {
            var size = child.get_min_self_size(CT.AXIS);
            if (parent.first_inline_child != idx) {
                size += gap;
            }
            parent.add_to_min_children_size(CT.AXIS, size);
        } else {
            const size = child.get_min_self_size(CT.AXIS);
            parent.max_of_min_children_size(CT.AXIS, size);
        }
        return elems;
    }
    fn fit_and_expand_children_to_fill_parent(nodes_: Elems, idx: u32, manager: *LayoutManager, comptime CT: AxisStage) Elems {
        var nodes = nodes_;
        const parent = get_elem_ptr(nodes, idx);
        if (parent.is_floating or parent.parent_idx == NULL_IDX) {
            const final_size = @min(parent.get_min_self_size(AXIS), parent.get_max_size(AXIS));
            parent.set_final_size(AXIS, final_size);
        }
        const final_size_with_pad = parent.get_final_size(CT.AXIS);
        const final_size_for_children = final_size_with_pad - parent.padding.get(CT.AXIS);
        if (parent.first_inline_child != NULL_IDX) {
            var curr_child_idx = parent.first_inline_child;
            if (CT.STAGE == .PRIMARY_STAGE and parent.is_flow_virtual) {
                const gap = parent.child_gaps.get(CT.AXIS);
                const grand_parent = get_parent_ptr(nodes, idx);
                var current_min_size: f32 = 0;
                var added_min_size: f32 = 0;
                var num_this_line: u32 = 0;
                while (curr_child_idx != NULL_IDX) {
                    const child = get_elem_ptr(nodes, curr_child_idx);
                    num_this_line += 1;
                    added_min_size += child.get_min_self_size(CT.AXIS);
                    if (num_this_line > 1) {
                        added_min_size += gap;
                    }
                    current_min_size += added_min_size;
                    if (current_min_size > final_size_for_children) {
                        // Make new sibling of paren
                    }
                    curr_child_idx = get_next_sibling(nodes, curr_child_idx);
                }
            } else {
                while (curr_child_idx != NULL_IDX) {
                    const child = get_elem_ptr(nodes, curr_child_idx);
                    curr_child_idx = get_next_sibling(nodes, curr_child_idx);
                }
            }
        }
        return nodes;
    }
    fn propagate_min_size_to_parent_y(nodes_: Elems, idx: u32, _: void, comptime phase: LayoutStage) Elems {
        const child = get_elem_ptr(nodes, idx);
        if (child.parent_idx == NULL_IDX) return nodes;
        const parent = get_parent_ptr(nodes, idx);
        const gap = parent.child_gaps.vertical;
        if (parent.layout_dir.primary_dir() == .Y and !parent.is_flow_virtual) {
            var size = child.get_min_self_size(.Y);
            if (parent.first_inline_child != idx) {
                size += gap;
            }
            parent.add_to_min_children_size(.Y, size);
        } else {
            const size = child.get_min_self_size(.Y);
            parent.max_of_min_children_size(.Y, size);
        }
        return nodes;
    }
    fn fit_and_expand_children_to_fill_parent_y(nodes_: Elems, idx: u32, manager: *LayoutManager, comptime phase: LayoutStage) Elems {
        var nodes = nodes_;
        const parent = get_elem_ptr(nodes, idx);
        if (phase == .PRIMARY_STAGE and parent.is_flow_virtual) {

        } else {

        }
        return nodes;
    }
    fn recheck_min_y_from_final_x(nodes_: Elems, idx: u32, _: void) Elems {
        var nodes = nodes_;
        return nodes;
    }
    fn recheck_min_x_from_final_y(nodes_: Elems, idx: u32, _: void) Elems {
        var nodes = nodes_;
        return nodes;
    }
    fn position_and_align_element(nodes_: Elems, idx: u32, _: void) Elems {
        var nodes = nodes_;
        return nodes;
    }
    fn check_aabb_overlap(nodes: Elems, idx: u32, context: *OverlapCheck) Elems {
        const elem = get_elem_ptr(nodes, idx);
        context.did_overlap = get_elem_ptr(nodes, idx).get_clip_aabb().overlaps(context.aabb);
        return nodes;
    }

    //UTILS 
    inline fn get_elem_ptr(nodes: Elems, idx: u32) *LayoutElement {
        return &nodes.ptr[idx];
    }
    inline fn get_elem(nodes: Elems, idx: u32) LayoutElement {
        return nodes.ptr[idx];
    }
    inline fn has_parent(nodes: Elems, idx: u32) bool {
        return nodes.ptr[idx].parent_idx != NULL_IDX;
    }
    inline fn get_parent_ptr(nodes: Elems, idx: u32) *LayoutElement {
        return &nodes.ptr[nodes.ptr[idx].parent_idx];
    }
    inline fn get_parent(nodes: Elems, idx: u32) LayoutElement {
        return nodes.ptr[nodes.ptr[idx].parent_idx];
    }
    inline fn get_next_sibling(nodes: Elems, idx: u32) u32 {
        return nodes.ptr[idx].next_sibling;
    }
    // inline fn set_next_sibling(nodes: Nodes, idx: u32, next: u32) void {
    //     nodes.ptr[idx].next_sibling = void;
    // }
    inline fn split_virtual_sibling(elems_: Elems, elem_idx: u32, elem: *LayoutElement, parent: *LayoutElement, manager: *LayoutManager) Elems {
        var elems = elems_realloc_if_needed_for_1_more(elems_, manager);
        if (manager.err) return elems;
        const next_idx = elems.len;
        elems.len += 1;
        elem.next_sibling = next_idx;
        var cloned_elem = elem.*;
        elems.ptr[next_idx] = sib_info;
    }
    inline fn elems_realloc_if_needed_for_1_more(elems_: Elems, manager: *LayoutManager) Elems {
        var elems = elems_;
        if (elems.len >= elems.cap) {
            switch (manager.elem_ralloc) {
                .STATIC_MEM => {
                    manager.err = Error.element_mem_out_of_space;
                },
                .ALLOW_MEM_REALLOC => |pkg| {
                    const err: ?Utils.Alloc.AllocErr = Utils.Alloc.smart_alloc_ptr_ptrs(pkg.alloc, &elems.ptr, &elems.len, &elems.cap, elems.len + 1, pkg.settings, .{.ERROR_MODE = .RETURN_ERRORS});
                    if (err) |e| {
                        manager.err = Error.element_mem_reallocation_error;
                    }
                }
            }
        }
        return elems;
    }
};

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

pub const LayoutStage = enum {
    PRIMARY_STAGE,
    SECONDARY_PHASE,
};

const Lines = struct {
    ptr: [*]AxisLine,
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

pub const LayoutManager = struct {
    mem: [*]u8,
    elems: [*]LayoutElement,
    lines: [*]AxisLine,
    stack: [*]StackFrame,
    mem_cap: u32 = 0,
    mem_len: u32 = 0,
    elems_byte_len: u32 = 0,
    elems_len: u32 = 0,
    elems_byte_cap: u32 = 0,
    elems_cap: u32 = 0,
    lines_byte_len: u32 = 0,
    lines_len: u32 = 0,
    lines_byte_cap: u32 = 0,
    lines_cap: u32 = 0,
    stack_byte_len: u32 = 0,
    stack_len: u32 = 0,
    stack_byte_cap: u32 = 0,
    stack_cap: u32 = 0,
    mem_static: bool = true,
    mem_alloc: Allocator = dummy_alloc,
    max_bytes_used: u32 = 0,

    const ALLOC_SETTINGS = Utils.Alloc.SmartAllocComptimeSettings(u8){
        .CLEAR_OLD_MODE = .DONT_MEMSET_OLD,
        .COPY_MODE = .DONT_COPY_EXISTING_DATA,
        .ERROR_MODE = .RETURN_ERRORS,
        .GROW_MODE = .GROW_EXACT_NEEDED,
        .INIT_NEW_MODE = .DONT_MEMSET_NEW,
        .OLD_ALIGN = .align_to_type(MemUnit),
        .NEW_ALIGN = .align_to_type(MemUnit),
    };

    fn grow_elems_if_needed(self: *LayoutManager, add_elems: u32) Error!void {
        const new_elem_len = self.elems_len + add_elems;
        if (new_elem_len > self.elems_cap) {
            const bytes_for_elems = new_elem_len * @sizeOf(LayoutElement);
            try self.grow(bytes_for_elems, self.lines_byte_cap, self.stack_byte_cap);
        }
        return;
    }

    fn grow(self: *LayoutManager, bytes_for_elems: u32, bytes_for_lines: u32, bytes_for_stack: u32) Error!void {
        const new_total_len = bytes_for_elems + bytes_for_lines + bytes_for_stack;
            const new_mem = try Utils.Alloc.smart_alloc(self.mem_alloc, self.mem, self.mem_len, self.mem_cap, new_total_len, .{}, ALLOC_SETTINGS);
            const new_mem_ptr = new_mem.ptr;
            const new_mem_end = new_mem_ptr + new_mem.len;
            const new_stack_ptr_opq = new_mem_end - bytes_for_stack;
            const new_stack_ptr: [*]StackFrame = @ptrCast(@alignCast(new_stack_ptr_opq));
            @memcpy(new_stack_ptr[0..self.stack_byte_len], self.stack[0..self.stack_byte_len]);
            const new_lines_ptr: [*]AxisLine = @ptrCast(@alignCast(new_stack_ptr_opq - bytes_for_lines))
            self.stack = new_stack_ptr;
            //CHECKPOINT
    }

    fn append_elem_slot(self: *LayoutManager) struct {*LayoutElement, u32} {

    }

    inline fn handle_elem_mem_error(self: *LayoutManager, err: Utils.Alloc.AllocErr) void {
        if (err == Utils.Alloc.AllocErr.OutOfMemory) {
            self.err = Error.ELEMENT_MEMORY_OUT_OF_SPACE;
        }
    }
    inline fn handle_depth_mem_error(self: *LayoutManager, err: Utils.Alloc.AllocErr) void {
        if (err == Utils.Alloc.AllocErr.OutOfMemory) {
            self.err = Error.DEPTH_MEMORY_OUT_OF_SPACE;
        }
    }
    inline fn realloc_elem_mem(self: *LayoutManager, new_cap: u32) bool {
        const err: Utils.Alloc.AllocErr = Utils.Alloc.smart_alloc_ptr_ptrs(mgr.alloc, &mgr.elem_memory, &mgr.elem_len, &mgr.elem_cap, new_cap, mgr.elem_alloc_settings, .{.ERROR_MODE = .RETURN_ERRORS});
        if (err == Utils.Alloc.AllocErr.OutOfMemory) {
            self.err = Error.ELEMENT_MEMORY_OUT_OF_SPACE;
            return false;
        }
        return true;
    }
    inline fn realloc_depth_mem(self: *LayoutManager, new_cap: u32) bool {
        const err: Utils.Alloc.AllocErr = Utils.Alloc.smart_alloc_ptr_ptrs(mgr.alloc, &mgr.depth_memory, &mgr.depth_len, &mgr.depth_cap, new_cap, mgr.depth_alloc_settings, .{.ERROR_MODE = .RETURN_ERRORS});
        if (err == Utils.Alloc.AllocErr.OutOfMemory) {
            self.err = Error.DEPTH_MEMORY_OUT_OF_SPACE;
            return false;
        }
        return true;
    }

    pub fn new_static_mem(elem_memory: []LayoutElement, depth_memory: []DepthFrame) LayoutManager {
        return LayoutManager{
            .elem_memory = elem_memory.ptr,
            .depth_memory = depth_memory.ptr,
            .elem_cap = @intCast(elem_memory.len),
            .depth_cap = @intCast(elem_memory.len),
        };
    }
    pub fn new_allocated_mem(initial_elem_cap: u32, initial_depth_cap: u32, alloc: Allocator, elem_alloc_settings: Utils.Alloc.SmartAllocSettings(LayoutElement), depth_alloc_settings: Utils.Alloc.SmartAllocSettings(DepthFrame)) struct{LayoutManager, bool} {
        var mgr = LayoutManager{
            .alloc = alloc,
            .elem_alloc_settings = elem_alloc_settings,
            .stack_alloc_settings = depth_alloc_settings,
        };

        if (initial_elem_cap > 0) {
            if (!mgr.realloc_elem_mem(initial_elem_cap)) {
                return .{mgr, false};
            }
        }
        if (initial_depth_cap > 0) {
            if (!mgr.realloc_depth_mem(initial_depth_cap)) {
                return .{mgr, false};
            }
        }
        return .{mgr, true};
    }

    inline fn get_elem_list_top_to_bottom(self: *LayoutManager) ElemList {
        return ElemList{
            .breadth_first_parents_first_siblings_reverse_order = @ptrCast(&self.all_elements_in_breadth_first_parents_first_siblings_reversed_order[0]),
            .len = self.elem_len,
            .head_idx = 0,
            ._debug_dir_top_to_bottom = if (comptime Assert.IS_DEBUG) true else void{},
        };
    }
    inline fn get_elem_list_bottom_to_top(self: *LayoutManager) ElemList {
        return ElemList{
            .breadth_first_parents_first_siblings_reverse_order = @ptrCast(&self.all_elements_in_breadth_first_parents_first_siblings_reversed_order[0]),
            .len = self.elem_len,
            .head_idx = 0,
            ._debug_dir_top_to_bottom = if (comptime Assert.IS_DEBUG) false else void{},
        };
    }
    inline fn get_child_slice(self: *LayoutManager, parent_idx: u32) SiblingSlice {
        const parent = self.all_elements_in_breadth_first_parents_first_siblings_reversed_order[parent_idx];
        return SiblingSlice{
            .last_to_first = @ptrCast(&self.all_elements_in_breadth_first_parents_first_siblings_reversed_order[parent.last_child]),
            .len = (parent.first_child - parent.last_child) + 1,
            .first_sibling_abs_idx = parent.first_child,
        };
    }

    inline fn append_new_elem_from_requester_and_parent_prev_sibling(self: *LayoutManager, requester: LayoutRequester, parent: u32, prev_sibling: u32) ?*LayoutElement {
        if (self.elem_len >= self.elem_cap) {
            if (self.can_realloc) {
                Utils.Alloc.smart_alloc_ptr_ptrs(self.alloc, &self.elem_memory, &self.elem_len, &self.elem_cap, self.elem_len + 1, self.elem_alloc_settings, .{.ERROR_MODE = .RETURN_ERRORS});
            } else {
                self.err = Error.ELEMENT_MEMORY_OUT_OF_SPACE;
            }
        }
        assert_with_reason(self.elem_len < MAX_NUM_ELEMENTS, @src(), "out of space for layout elements: increase MAX_NUM_ELEMENTS comptime input to at least {d}", .{MAX_NUM_ELEMENTS + 1});
        const req: LayoutRequest = requester.get_layout_request();
        assert_with_reason(parent != NULL_IDX or (req.size.width.mode == .EXACT and req.size.height.mode == .EXACT), @src(), "the root element must have `size.width.mode == .EXACT` and `size.height.mode == .EXACT`", .{});
        const new_depth = if (parent == NULL_IDX) 0 else (self.elements[parent].depth + 1);
        self.real_max_depth = @max(new_depth, self.real_max_depth);
        const elem = LayoutElement{
            .requester = requester,
            ._ms_fbb = .new(req.size.width.min, req.size.height.min),
            ._mg_fcbb = .new(req.size.width.max, req.size.height.max, req.size.width.ratio, req.size.height.ratio),
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
            .relative_pos = if (req.float.use_floating) req.float.offest else .ZERO,
            .use_flow_mode = req.use_flow_mode,
        };
        if (parent != NULL_IDX) {
            var par: *LayoutElement = &self.elements[parent];
            par.first_child = self.elem_len;
            if (par.last_child == NULL_IDX) {
                par.last_child = self.elem_len;
            }
            assert_with_reason(par.first_child >= par.last_child, @src(), "sanity check: first child always greater or equal last child", .{}); //DEBUG
        }
        self.elements[self.elem_len] = elem;
        self.elem_len += 1;
        return &self.elements[self.elem_len - 1];
    }

    pub fn collect_element_heirarchy(self: *LayoutManager, root_element: LayoutRequester) void {
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

    pub fn recalculate_layout(self: *LayoutManager, comptime DRIVING_AXIS: Axis, comptime STACK_REALLOC: StackRealloc, stack_realloc: STACK_REALLOC.T_PKG(StackFrame)) ?Error {
        switch (comptime DRIVING_AXIS) {
            .X => {
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .CHILDREN_FIRST, .exclude_child_paths(&.{""}), 0, STACK_REALLOC, stack_realloc, void{}, LayoutStage.PRIMARY_STAGE, .COMPTIME_FN_BODY, Action.propagate_min_size_to_parent_x, void{});
                if (self.err) |e| return e;
                Action.set_root_final_size_x(self.elems, 0);
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .PARENTS_FIRST, 0, STACK_REALLOC, stack_realloc, self, LayoutStage.PRIMARY_STAGE, .COMPTIME_FN_BODY, Action.fit_and_expand_children_to_fill_parent_x, void{});
                if (self.err) |e| return e;
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .PARENTS_FIRST, 0, STACK_REALLOC, stack_realloc, void{}, void{}, .COMPTIME_FN_BODY, Action.recheck_min_y_from_final_x, void{});
                if (self.err) |e| return e;
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .CHILDREN_FIRST, 0,  STACK_REALLOC, stack_realloc, void{}, LayoutStage.SECONDARY_PHASE, .COMPTIME_FN_BODY, Action.propagate_min_size_to_parent_y, void{});
                if (self.err) |e| return e;
                Action.set_root_final_size_y(self.elems, 0);
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .PARENTS_FIRST, 0, STACK_REALLOC, stack_realloc, self, LayoutStage.SECONDARY_PHASE, .COMPTIME_FN_BODY, Action.fit_and_expand_children_to_fill_parent_y, void{});
            },
            .Y => {
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .CHILDREN_FIRST, 0, STACK_REALLOC, stack_realloc, void{}, LayoutStage.PRIMARY_STAGE, .COMPTIME_FN_BODY, Action.propagate_min_size_to_parent_y, void{});
                if (self.err) |e| return e;
                Action.set_root_final_size_y(self.elems, 0);
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .PARENTS_FIRST, 0, STACK_REALLOC, stack_realloc, self, LayoutStage.PRIMARY_STAGE, .COMPTIME_FN_BODY, Action.fit_and_expand_children_to_fill_parent_y, void{});
                if (self.err) |e| return e;
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .PARENTS_FIRST, 0, STACK_REALLOC, stack_realloc, void{}, void{}, .COMPTIME_FN_BODY, Action.recheck_min_x_from_final_y, void{});
                if (self.err) |e| return e;
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .CHILDREN_FIRST, 0, STACK_REALLOC, stack_realloc, void{}, LayoutStage.SECONDARY_PHASE, .COMPTIME_FN_BODY, Action.propagate_min_size_to_parent_x, void{});
                if (self.err) |e| return e;
                Action.set_root_final_size_x(self.elems, 0);
                self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .PARENTS_FIRST, 0, STACK_REALLOC, stack_realloc, self, LayoutStage.SECONDARY_PHASE, .COMPTIME_FN_BODY, Action.fit_and_expand_children_to_fill_parent_x, void{});
            },
        }
        if (self.err) |e| return e;
        self.elems, self.stack, self.err = Traverse.do_action_on_all_nodes(self.elems, self.stack, .PARENTS_FIRST, 0, STACK_REALLOC, stack_realloc, void{}, void{}, .COMPTIME_FN_BODY, Action.position_and_align_element, void{});
        return self.err;
    }

    fn propogate_minimums_to_parents(self: *LayoutManager, comptime AXIS: Axis, comptime IS_DRIVING_AXIS: bool) void {
        var remaining_elems = self.get_elem_list_bottom_to_top();
        var curr_siblings: SiblingSlice = undefined;
        while (remaining_elems.has_more_elements()) {
            remaining_elems, curr_siblings = remaining_elems.split_off_deepest_sibling_slice();
            if (curr_siblings.has_parent()) {
                var curr_elem: *LayoutElement, var curr_idx: u32 = curr_siblings.get_first_ptr_and_idx();
                var parent_elem = curr_siblings.get_parent_ptr(self.all_elements_in_breadth_first_parents_first_siblings_reversed_order[0..]);
                const parent_grow = parent_elem.get_grow_mode(AXIS);
                if (parent_grow != .EXACT) {
                    switch (parent_elem.layout_dir.relative_to_axis(AXIS)) {
                        .SAME_LAYOUT_DIRECTION_AS_CURRENT_AXIS => {
                            if (parent_elem.use_flow_mode) {
                                if (comptime IS_DRIVING_AXIS) {
                                    var min_size_from_children: f32 = 0;
                                    while (true) {
                                        min_size_from_children = @max(min_size_from_children, curr_elem.get_min_self_size(AXIS));
                                        if (!curr_siblings.has_next(curr_idx)) break;
                                        curr_elem, curr_idx = curr_siblings.get_next_ptr_and_idx(curr_idx);
                                    }
                                    min_size_from_children += parent_elem.padding.get(AXIS);
                                    parent_elem.update_min_size_if_larger(AXIS, min_size_from_children);
                                } else {
                                    while (curr_siblings.has_another_axis_line()) {
                                        //FIXME
                                    }
                                }
                            } else {
                                const gap = parent_elem.child_gaps.get(AXIS);
                                var min_size_from_children: f32 = 0;
                                var not_first_child: bool = false;
                                while (true) {
                                    min_size_from_children += curr_elem.get_min_self_size(AXIS);
                                    if (not_first_child) {
                                        min_size_from_children += gap;
                                    }
                                    not_first_child = true;
                                    if (!curr_siblings.has_next(curr_idx)) break;
                                    curr_elem, curr_idx = curr_siblings.get_next_ptr_and_idx(curr_idx);
                                }
                                min_size_from_children += parent_elem.padding.get(AXIS);
                                parent_elem.update_min_size_if_larger(AXIS, min_size_from_children);
                            }
                        },
                        .OPPOSITE_LAYOUT_DIRECTION_OF_CURRENT_AXIS => {
                            if ()
                            var min_size_from_children: f32 = 0;
                            while (true) {
                                min_size_from_children = @max(min_size_from_children, curr_elem.get_min_self_size(AXIS));
                                if (!curr_siblings.has_next(curr_idx)) break;
                                curr_elem, curr_idx = curr_siblings.get_next_ptr_and_idx(curr_idx);
                            }
                            min_size_from_children += parent_elem.padding.get(AXIS);
                            parent_elem.update_min_size_if_larger(AXIS, min_size_from_children);
                        },
                    }
                }
            }
        }
    }

    //breadth top_to_bottom
    fn grow_and_shrink(self: *LayoutManager, comptime AXIS: Axis, comptime IS_DRIVING_AXIS: bool) void {
        var remaining_elems = self.get_elem_list_top_to_bottom();
        var curr_parent_siblings: SiblingSlice = undefined;
        while (remaining_elems.has_more_elements()) {
            remaining_elems, curr_parent_siblings = remaining_elems.split_off_shallowest_sibling_slice();
            var curr_parent, var parent_local_idx = curr_parent_siblings.get_first_ptr_and_idx();
            while (true) {
                if (curr_parent.has_children()) {
                    var remaining_children = self.get_child_slice(curr_parent_siblings.abs_idx(parent_local_idx));
                    var curr_child, var child_local_idx = remaining_children.get_first_ptr_and_idx();
                    while (true) {
                        // GROW/SHRINK CHILD
                        if (!remaining_children.has_next(child_local_idx)) break;
                        curr_child, child_local_idx = remaining_children.get_next_ptr_and_idx(child_local_idx);
                    }
                }
                if (!curr_parent_siblings.has_next(parent_local_idx)) break;
                curr_parent, parent_local_idx = curr_parent_siblings.get_next_ptr_and_idx(parent_local_idx);
            }
        }
        var parent_idx: u32 = 0;
        //CHECKPOINT update to use AXIS
        while (parent_idx < self.elem_len) : (parent_idx += 1) {
            const first_child_idx = self.elements[parent_idx].first_child;
            const last_child_idx = self.elements[parent_idx].last_child;
            const parent_padding = self.elements[parent_idx].padding;
            const parent_gaps = self.elements[parent_idx].child_gaps;
            const num_gaps = @as(f32, @floatFromInt(first_child_idx - last_child_idx));
            var child_idx: u32 = first_child_idx;
            if (child_idx != NULL_IDX) {
                switch (self.elements[parent_idx].layout_dir.relative_to_axis(AXIS)) {
                    .SAME_DIRECTION_AS_CURRENT_AXIS => {
                        var remaining_free_space = self.elements[parent_idx].get_min_children(AXIS) - parent_padding.get(AXIS) - parent_gaps.get_total(AXIS, num_gaps);
                        var total_min: f32 = 0;
                        var has_at_least_one_grow: bool = false;
                        while (child_idx >= last_child_idx) : (child_idx -= 1) {
                            const child_min = self.elements[child_idx].get_min_self(AXIS);
                            self.elements[child_idx].set_final_size(AXIS, child_min);
                            total_min += child_min;
                            has_at_least_one_grow = has_at_least_one_grow or self.elements[child_idx].get_grow_mode(AXIS) == .GROW;
                        }
                        remaining_free_space = remaining_free_space - total_min;
                        if (has_at_least_one_grow and total_min < remaining_free_space) {
                            while (remaining_free_space >= 0.001) {
                                var total_grow_weight_this_pass: f32 = 0;
                                var num_elements_to_distrubute_across: f32 = 0;
                                var total_space_claimed_this_pass: f32 = 0;
                                child_idx = first_child_idx;
                                while (child_idx >= last_child_idx) : (child_idx -= 1) {
                                    if (self.elements[child_idx].get_grow_mode(AXIS) == .GROW and self.elements[child_idx].get_min_children(AXIS) < self.elements[child_idx].get_max(AXIS)) {
                                        total_grow_weight_this_pass += self.elements[child_idx].get_grow_ratio(AXIS);
                                        num_elements_to_distrubute_across += 1;
                                    }
                                }
                                if (num_elements_to_distrubute_across == 0 or total_grow_weight_this_pass == 0) break;
                                child_idx = first_child_idx;
                                while (child_idx >= last_child_idx) : (child_idx -= 1) {
                                    if (self.elements[child_idx].get_grow_mode(AXIS) == .GROW and self.elements[child_idx].get_min_children(AXIS) < self.elements[child_idx].get_max(AXIS)) {
                                        var space_to_claim = remaining_free_space * (self.elements[child_idx].get_grow_ratio(AXIS) / total_grow_weight_this_pass);
                                        var new_size = self.elements[child_idx].get_min_children(AXIS) + space_to_claim;
                                        if (new_size >= self.elements[child_idx].get_max(AXIS)) {
                                            new_size = self.elements[child_idx].get_max(AXIS);
                                            space_to_claim = new_size - self.elements[child_idx].get_min_children(AXIS);
                                        }
                                        total_space_claimed_this_pass += space_to_claim;
                                        self.elements[child_idx].get_min_children(AXIS) = new_size;
                                    }
                                }
                                remaining_free_space -= total_space_claimed_this_pass;
                                if (total_space_claimed_this_pass < 0.001) break;
                            }
                        }
                        self.elements[parent_idx].get_min_self(AXIS) = remaining_free_space;
                    },
                    .OPPOSITE_DIRECTION_OF_CURRENT_AXIS => {
                        const free_space = self.elements[parent_idx].get_min_children(AXIS) - parent_padding.get(AXIS)();
                        var max_space_used: f32 = 0;
                        while (child_idx >= last_child_idx) : (child_idx -= 1) {
                            switch (self.elements[child_idx].get_grow_mode(AXIS)) {
                                .EXACT, .SHRINK => {
                                    self.elements[child_idx].get_min_children(AXIS) = self.elements[child_idx].get_min_self(AXIS);
                                },
                                .GROW => {
                                    self.elements[child_idx].get_min_children(AXIS) = @max(@min(free_space, self.elements[child_idx].get_max(AXIS)), self.elements[child_idx].get_min_self(AXIS));
                                },
                            }
                            max_space_used = @max(max_space_used, self.elements[child_idx].get_min_children(AXIS));
                        }
                        const leftover_space = max_space_used - free_space;
                        self.elements[parent_idx].get_min_self(AXIS) = leftover_space;
                    },
                }
            }
            var free_space: f32 = self.elements[parent_idx].get_max(AXIS) - self.elements[parent_idx].get_min_children(AXIS);
            var total_grow_weight: f32 = 0;
            child_idx = first_child_idx;
            while (child_idx >= last_child_idx) : (child_idx -= 1) {
                if (self.elements[child_idx].is_floating) continue;
                switch (self.elements[parent_idx].get_grow_mode(AXIS)) {
                    .EXACT, .SHRINK => {
                        self.elements[parent_idx].get_min_children(AXIS) = self.elements[parent_idx].get_min_self(AXIS);
                    },
                    .GROW => {
                        total_grow_weight += self.elements[child_idx].get_grow_ratio(AXIS);
                    },
                }
            }
            child_idx = first_child_idx;
            while (child_idx >= last_child_idx) : (child_idx -= 1) {
                if (self.elements[child_idx].is_floating or self.elements[child_idx].get_grow_mode(AXIS) != .GROW) continue;
                var free_space_used = free_space * (self.elements[child_idx].get_grow_ratio(AXIS) / total_grow_weight);
                var new_size = self.elements[child_idx].get_min_self(AXIS) + free_space_used;
                new_size = @min(new_size, self.elements[child_idx].get_max(AXIS));
                free_space_used = new_size - self.elements[child_idx].get_min_self(AXIS);
                free_space -= free_space_used;
                self.elements[child_idx].get_min_children(AXIS) = new_size;
            }
        }
    }

    fn recheck_element_sizes_with_with_known_primary_size(self: *LayoutManager, comptime DRIVING_AXIS: Axis) void {
        //CHECKPOINT AXIS
        var i: u32 = self.elem_len;
        while (i > 1) : (i -= 1) {
            const check_info: SizeCheckInfo = switch (DRIVING_AXIS) {
                .WIDTH_DRIVES_HEIGHT => SizeCheckInfo{
                    .driving_axis = DRIVING_AXIS,
                    .driving_size = self.elements[i].min_width_from_children_or_final_width,
                    .old_secondary_min = self.elements[i].min_size_height_or_leftover_vert,
                    .old_secondary_max = self.elements[i].max_size_height,
                },
                .HEIGHT_DRIVES_WIDTH => SizeCheckInfo{
                    .driving_axis = DRIVING_AXIS,
                    .driving_size = self.elements[i].min_height_from_children_or_final_height,
                    .old_secondary_min = self.elements[i].min_size_width_or_leftover_horiz,
                    .old_secondary_max = self.elements[i].max_size_width,
                },
            };
            const new_secondary_size = self.elements[i].requester.check_size(check_info);
            switch (comptime DRIVING_AXIS) {
                .WIDTH_DRIVES_HEIGHT => {
                    self.elements[i].min_size_height_or_leftover_vert = new_secondary_size.min;
                    self.elements[i].max_size_height = new_secondary_size.max;
                },
                .HEIGHT_DRIVES_WIDTH => {
                    self.elements[i].min_size_width_or_leftover_horiz = new_secondary_size.min;
                    self.elements[i].max_size_width = new_secondary_size.max;
                },
            }
        }
    }

    //breadth bottom-to-top
    fn propogate_minimum_heights_to_parents(self: *LayoutManager) void {
        var i: u32 = self.elem_len;
        while (i > 1) : (i -= 1) {
            var this_layout: *LayoutElement = &self.elements[i];
            this_layout.min_height_from_children_or_final_height += this_layout.padding.top + this_layout.padding.bottom;
            this_layout.min_size_height_or_leftover_vert = @min(@max(this_layout.min_size_height_or_leftover_vert, this_layout.min_height_from_children_or_final_height), this_layout.max_size_height);
            if (this_layout.is_floating) continue;
            var parent: *LayoutElement = &self.elements[this_layout.parent_idx];
            if (parent.grow_mode_h != .EXACT) {
                switch (parent.layout_dir.primary_dir()) {
                    .HORIZONTAL => {
                        parent.min_height_from_children_or_final_height = @max(parent.min_height_from_children_or_final_height, this_layout.min_size_height_or_leftover_vert);
                    },
                    .VERTICAL => {
                        if (parent.first_child != i) {
                            parent.min_height_from_children_or_final_height += parent.child_gaps.vertical + this_layout.min_size_height_or_leftover_vert;
                        } else {
                            parent.min_height_from_children_or_final_height += this_layout.min_size_height_or_leftover_vert;
                        }
                    },
                }
            }
        }
        var root_layout: *LayoutElement = &self.elements[0];
        root_layout.min_height_from_children_or_final_height += root_layout.padding.top + root_layout.padding.bottom;
        root_layout.min_size_height_or_leftover_vert = @min(@max(root_layout.min_size_height_or_leftover_vert, root_layout.min_height_from_children_or_final_height), root_layout.max_size_height);
    }

    //breadth top_to_bottom
    fn grow_and_shrink_heights(self: *LayoutManager) void {
        var parent_idx: u32 = 0;
        while (parent_idx < self.elem_len) : (parent_idx += 1) {
            const first_child_idx = self.elements[parent_idx].first_child;
            const last_child_idx = self.elements[parent_idx].last_child;
            const parent_padding = self.elements[parent_idx].padding;
            const parent_gaps = self.elements[parent_idx].child_gaps;
            const num_gaps = @as(f32, @floatFromInt(last_child_idx - first_child_idx));
            var child_idx: u32 = first_child_idx;
            if (child_idx != NULL_IDX) {
                switch (self.elements[parent_idx].layout_dir.primary_dir()) {
                    .VERTICAL => {
                        var remaining_free_vert_space = self.elements[parent_idx].min_height_from_children_or_final_height - parent_padding.v_padding() - parent_gaps.total_v_gap(num_gaps);
                        var total_min_height: f32 = 0;
                        var has_at_least_one_grow: bool = false;
                        while (child_idx <= last_child_idx) : (child_idx += 1) {
                            const child_min = self.elements[child_idx].min_size_height_or_leftover_vert;
                            self.elements[child_idx].min_height_from_children_or_final_height = child_min;
                            total_min_height += child_min;
                            has_at_least_one_grow = has_at_least_one_grow or self.elements[child_idx].grow_mode_h == .GROW;
                        }
                        remaining_free_vert_space = remaining_free_vert_space - total_min_height;
                        if (has_at_least_one_grow and total_min_height < remaining_free_vert_space) {
                            while (remaining_free_vert_space >= 0.001) {
                                var total_grow_weight_this_pass: f32 = 0;
                                var num_elements_to_distrubute_across: f32 = 0;
                                var total_space_claimed_this_pass: f32 = 0;
                                child_idx = first_child_idx;
                                while (child_idx <= last_child_idx) : (child_idx += 1) {
                                    if (self.elements[child_idx].grow_mode_h == .GROW and self.elements[child_idx].min_height_from_children_or_final_height < self.elements[child_idx].max_size_height) {
                                        total_grow_weight_this_pass += self.elements[child_idx].grow_ratio_h;
                                        num_elements_to_distrubute_across += 1;
                                    }
                                }
                                if (num_elements_to_distrubute_across == 0 or total_grow_weight_this_pass == 0) break;
                                child_idx = first_child_idx;
                                while (child_idx <= last_child_idx) : (child_idx += 1) {
                                    if (self.elements[child_idx].grow_mode_h == .GROW and self.elements[child_idx].min_height_from_children_or_final_height < self.elements[child_idx].max_size_height) {
                                        var space_to_claim = remaining_free_vert_space * (self.elements[child_idx].grow_ratio_h / total_grow_weight_this_pass);
                                        var new_height = self.elements[child_idx].min_height_from_children_or_final_height + space_to_claim;
                                        if (new_height >= self.elements[child_idx].max_size_height) {
                                            new_height = self.elements[child_idx].max_size_height;
                                            space_to_claim = new_height - self.elements[child_idx].min_height_from_children_or_final_height;
                                        }
                                        total_space_claimed_this_pass += space_to_claim;
                                        self.elements[child_idx].min_height_from_children_or_final_height = new_height;
                                    }
                                }
                                remaining_free_vert_space -= total_space_claimed_this_pass;
                                if (total_space_claimed_this_pass < 0.001) break;
                            }
                        }
                        self.elements[parent_idx].min_size_height_or_leftover_vert = remaining_free_vert_space;
                    },
                    .HORIZONTAL => {
                        const free_vert_space = self.elements[parent_idx].min_height_from_children_or_final_height - parent_padding.v_padding();
                        var max_vert_space_used: f32 = 0;
                        while (child_idx <= last_child_idx) : (child_idx += 1) {
                            switch (self.elements[child_idx].grow_mode_h) {
                                .EXACT, .SHRINK => {
                                    self.elements[child_idx].min_height_from_children_or_final_height = self.elements[child_idx].min_size_height_or_leftover_vert;
                                },
                                .GROW => {
                                    self.elements[child_idx].min_height_from_children_or_final_height = @max(@min(free_vert_space, self.elements[child_idx].max_size_height), self.elements[child_idx].min_size_height_or_leftover_vert);
                                },
                            }
                            max_vert_space_used = @max(max_vert_space_used, self.elements[child_idx].min_height_from_children_or_final_height);
                        }
                        const leftover_vert = free_vert_space - max_vert_space_used;
                        self.elements[parent_idx].min_size_height_or_leftover_vert = leftover_vert;
                    },
                }
            }
            var free_space: f32 = self.elements[parent_idx].max_size_height - self.elements[parent_idx].min_height_from_children_or_final_height;
            var total_grow_weight: f32 = 0;

            while (child_idx <= self.elements[parent_idx].last_child) : (child_idx += 1) {
                if (self.elements[child_idx].is_floating) continue;
                switch (self.elements[parent_idx].grow_mode_h) {
                    .EXACT, .SHRINK => {
                        self.elements[parent_idx].min_height_from_children_or_final_height = self.elements[parent_idx].min_size_height_or_leftover_vert;
                    },
                    .GROW => {
                        total_grow_weight += self.elements[child_idx].grow_ratio_h;
                    },
                }
            }
            child_idx = self.elements[parent_idx].first_child;
            while (child_idx <= self.elements[parent_idx].last_child) : (child_idx += 1) {
                if (self.elements[child_idx].is_floating or self.elements[child_idx].grow_mode_h != .GROW) continue;
                var free_space_used = free_space * (self.elements[child_idx].grow_ratio_h / total_grow_weight);
                var new_height = self.elements[child_idx].min_size_height_or_leftover_vert + free_space_used;
                new_height = @min(new_height, self.elements[child_idx].max_size_height);
                free_space_used = new_height - self.elements[child_idx].min_size_height_or_leftover_vert;
                free_space -= free_space_used;
                self.elements[child_idx].min_height_from_children_or_final_height = new_height;
            }
        }
    }

    fn position_and_align_all_elements(self: *LayoutManager) void {
        var parent_idx: u32 = 0;
        while (parent_idx < self.elem_len) : (parent_idx += 1) {
            const parent_abs_pos = self.elements[parent_idx].absolute_pos;
            const first_child_idx = self.elements[parent_idx].first_child;
            const last_child_idx = self.elements[parent_idx].last_child;
            const parent_padding = self.elements[parent_idx].padding;
            const parent_gaps = self.elements[parent_idx].child_gaps;
            const num_gaps = @as(f32, @floatFromInt(last_child_idx - first_child_idx));
            const primary_axis = self.elements[parent_idx].layout_dir.primary_dir();
            const num_h_gaps = switch (primary_axis) { // TODO implement flow-box
                .HORIZONTAL => num_gaps,
                .VERTICAL => 0,
            };
            const num_v_gaps = switch (primary_axis) { // TODO implement flow-box
                .HORIZONTAL => 0,
                .VERTICAL => num_gaps,
            };
            const h_dir = self.elements[parent_idx].layout_dir.horizontal_dir();
            const v_dir = self.elements[parent_idx].layout_dir.vertical_dir();
            const child_align = self.elements[parent_idx].child_align;
            var child_idx: u32 = first_child_idx;
            var x_cursor: f32 = 0;
            var y_cursor: f32 = 0;
            var x_add_width: f32 = 0;
            var y_add_height: f32 = 0;
            var x_dir_mult: f32 = 1;
            var y_dir_mult: f32 = 1;
            var h_gap_step: f32 = parent_gaps.h_gap();
            var v_gap_step: f32 = parent_gaps.v_gap();
            switch (h_dir) {
                .LEFT_TO_RIGHT => {
                    x_cursor = parent_padding.left;
                    switch (child_align.x) {
                        .LEFT => {},
                        .JUSTIFY => {
                            h_gap_step += (@max(0, self.elements[parent_idx].min_size_width_or_leftover_horiz) / num_h_gaps);
                        },
                        .MIDDLE => {
                            x_cursor += (self.elements[parent_idx].min_size_width_or_leftover_horiz / 2.0);
                        },
                        .RIGHT => {
                            x_cursor += self.elements[parent_idx].min_size_width_or_leftover_horiz;
                        },
                    }
                },
                .RIGHT_TO_LEFT => {
                    x_cursor = parent_padding.right;
                    x_add_width = -1.0;
                    x_dir_mult = -1.0;
                    switch (child_align.x) {
                        .LEFT => {},
                        .JUSTIFY => {
                            h_gap_step += (@max(0, self.elements[parent_idx].min_size_width_or_leftover_horiz) / num_v_gaps);
                        },
                        .MIDDLE => {
                            x_cursor -= (self.elements[parent_idx].min_size_width_or_leftover_horiz / 2.0);
                        },
                        .RIGHT => {
                            x_cursor -= self.elements[parent_idx].min_size_width_or_leftover_horiz;
                        },
                    }
                },
            }
            switch (v_dir) {
                .TOP_TO_BOTTOM => {
                    y_cursor = parent_padding.top;
                    switch (child_align.y) {
                        .TOP => {},
                        .JUSTIFY => {
                            v_gap_step += (@max(0, self.elements[parent_idx].min_size_height_or_leftover_vert) / num_v_gaps);
                        },
                        .CENTER => {
                            y_cursor += (self.elements[parent_idx].min_size_height_or_leftover_vert / 2.0);
                        },
                        .BOTTOM => {
                            y_cursor += self.elements[parent_idx].min_size_height_or_leftover_vert;
                        },
                    }
                },
                .RIGHT_TO_LEFT => {
                    y_cursor = parent_padding.bottom;
                    y_add_height = -1.0;
                    y_dir_mult = -1.0;
                    switch (child_align.y) {
                        .TOP => {},
                        .JUSTIFY => {
                            v_gap_step += (@max(0, self.elements[parent_idx].min_size_height_or_leftover_vert) / num_v_gaps);
                        },
                        .CENTER => {
                            y_cursor -= (self.elements[parent_idx].min_size_height_or_leftover_vert / 2.0);
                        },
                        .BOTTOM => {
                            y_cursor -= self.elements[parent_idx].min_size_height_or_leftover_vert;
                        },
                    }
                },
            }
            if (child_idx != NULL_IDX) {
                while (child_idx <= last_child_idx) : (child_idx += 1) {
                    const child_w = self.elements[child_idx].min_width_from_children_or_final_width;
                    const child_h = self.elements[child_idx].min_height_from_children_or_final_height;
                    const x_pos_rel = x_cursor + (x_add_width * child_w);
                    const y_pos_rel = y_cursor + (y_add_height * child_h);
                    const rel_pos = Pos.new(x_pos_rel, y_pos_rel);
                    const abs_pos = parent_abs_pos + rel_pos;
                    self.elements[child_idx].relative_pos = rel_pos;
                    self.elements[child_idx].absolute_pos = abs_pos;
                    switch (primary_axis) {
                        .HORIZONTAL => {
                            const abs_step = child_w + h_gap_step;
                            x_cursor += (abs_step * x_dir_mult);
                        },
                        .VERTICAL => {
                            const abs_step = child_h + v_gap_step;
                            y_cursor += (abs_step * y_dir_mult);
                        },
                    }
                }
            }
        }
    }

    pub fn handle_events_on_heirarchy_from_children_to_parents(self: *const LayoutManager, events: []EventAtLocation) void {
        var i: u32 = self.elem_len;
        while (i > 0) {
            i -= 1;
            const elem = self.elements[i];
            for (events) |*e| {}
        }
    }

    pub fn execute_final_layout_handlers_for_all_elements_parents_first(self: *const LayoutManager) void {
        var i: u32 = 0;
        while (i < self.elem_len) : (i += 1) {
            const inter_layout = self.elements[i];
            const final_layout: LayoutResult = LayoutResult{
                .pos = inter_layout.absolute_pos,
                .size = Size(inter_layout.min_width_from_children_or_final_width, inter_layout.min_height_from_children_or_final_height),
                .z_index = inter_layout.depth,
                .has_clip = inter_layout.clip_to_parent,
                .clip_aabb = if (inter_layout.clip_to_parent) get: {
                    var out: AABB = AABB{};
                    out.x_min = self.elements[inter_layout.parent_idx].absolute_pos.x;
                    out.y_min = self.elements[inter_layout.parent_idx].absolute_pos.y;
                    out.x_max = out.x_min + self.elements[inter_layout.parent_idx].min_width_from_children_or_final_width;
                    out.y_max = out.y_min + self.elements[inter_layout.parent_idx].min_height_from_children_or_final_height;
                    break :get out;
                } else AABB{},
                .sibling_edges = 0, //TODO implement sibling edge checks
            };
            self.elements[i].requester.handle_layout_result(final_layout);
        }
    }
};
