//! //TODO Documentation
//! #### Credits
//! This module is heavily inspired-by/derived-from the Clay layout library (https://github.com/nicbarker/clay)
//! under the zlib/libpng license (https://github.com/nicbarker/clay/blob/main/LICENSE.md)
//! Some of the code is converted directly to zig, and some of it is replaced by other utility functions/structs provided by Goolib.
//! Properties related to rendering and text layout are omitted, instead each element holds
//! a `LayoutElementData` that has an opaque pointer to the concrete object with a `check_size` and `handle_final_size`
//! function pointer that lets the implementer choose what to do and how to do it given the relevant layout data.
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
const DummyAlloc = Root.DummyAllocator.allocator_panic_free_noop;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;
const kind_info = KindInfo.get_kind_info;

const Size = Root.Vec2.define_vec2_type(f32);
const Pos = Root.Vec2.define_vec2_type(f32);
const Rect = Root.Rect2.define_rect2_type(f32);
const AABB = Root.AABB2.define_aabb2_type(f32);

pub const String = struct {
    ptr: ?*u8 = null,
    len: u32 = 0,
    is_static: bool = false,
};

pub const StringSlice = struct {
    ptr: ?*u8 = null,
    base_ptr: ?*u8 = null,
    len: u32 = 0,
};

pub const MemoryArena = struct {
    mem: ?*u8 = null,
    cap: u32 = 0,
    next_addr: usize = 0,
};

pub const ElementID = struct {
    id: u32,
    offset: u32,
    base_id: u32,
};

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
        return @enumFromInt(@as(u1, @truncate(@intFromEnum(self) >> 2)));
    }
    pub inline fn relative_axis_for_primary(self: LayoutDirection, comptime COMP: Size.Comp) AxisRelative {
        switch (comptime COMP) {
            .X => switch (self.primary_axis()) {
                .HORIZONTAL => return .SAME,
                .VERTICAL => return .DIFFERENT,
            },
            .Y => switch (self.primary_axis()) {
                .VERTICAL => return .SAME,
                .HORIZONTAL => return .DIFFERENT,
            },
        }
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
    SAME = 0b0,
    DIFFERENT = 0b1,
};

pub const Axis = enum(u1) {
    HORIZONTAL = 0b0,
    VERTICAL = 0b1,
};
pub const HorizontalDirection = enum(u1) {
    LEFT_TO_RIGHT = 0b0,
    RIGHT_TO_LEFT = 0b1,
};
pub const VerticalDirection = enum(u1) {
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

// pub const SizeModeData = union(SizeMode) {
//     FIT: SizeLimits,
//     GROW: SizeLimits,
//     PERCENT: SizeLimits,
//     FIXED: SizeLimits,

//     pub inline fn fit(limits: SizeLimits) SizeModeData {
//         return SizeModeData{ .FIT = limits };
//     }
//     pub inline fn grow(limits: SizeLimits) SizeModeData {
//         return SizeModeData{ .GROW = limits };
//     }
//     pub inline fn fixed(size: f32) SizeModeData {
//         return SizeModeData{ .FIXED = .min_max(size, size) };
//     }
//     pub inline fn percent(percent_: f32) SizeModeData {
//         return SizeModeData{ .PERCENT = .min_max(0, percent_) };
//     }
//     pub inline fn percent_with_min(percent_: f32, min_: f32) SizeModeData {
//         return SizeModeData{ .PERCENT = .min_max(min_, percent_) };
//     }

//     inline fn flat_val(self: SizeModeData) SizeModeDataFlat {
//         switch (self) {
//             .FIT => |lim| return SizeModeDataFlat{ .FIT = lim },
//             .GROW => |lim| return SizeModeDataFlat{ .GROW = lim },
//             .PERCENT => |per| return SizeModeDataFlat{ .PERCENT = per },
//             .FIXED => |lim| return SizeModeDataFlat{ .FIXED = lim },
//         }
//     }
//     inline fn flat_min(self: SizeModeData) f32 {
//         switch (self) {
//             .FIT => |lim| return lim.min_,
//             .GROW => |lim| return lim.min_,
//             .PERCENT => |per| return per.min_,
//             .FIXED => |lim| return lim.min_,
//         }
//     }
//     inline fn flat_max(self: SizeModeData) f32 {
//         switch (self) {
//             .FIT => |lim| return lim.max_,
//             .GROW => |lim| return lim.max_,
//             .PERCENT => |per| return per.max_,
//             .FIXED => |lim| return lim.max_,
//         }
//     }
//     inline fn flat_tag(self: SizeModeData) SizeMode {
//         switch (self) {
//             .FIT => return SizeMode.FIT,
//             .GROW => return SizeMode.GROW,
//             .PERCENT => return SizeMode.PERCENT,
//             .FIXED => return SizeMode.FIXED,
//         }
//     }
// };

// pub const SizeModeDataFlat = extern union {
//     FIT: SizeLimits,
//     GROW: SizeLimits,
//     PERCENT: SizeLimits,
//     FIXED: SizeLimits,
// };

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
    pub fn get(self: Padding, comptime COMP: Size.Comp) f32 {
        switch (comptime COMP) {
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
    pub fn get(self: Gap, comptime COMP: Size.Comp) f32 {
        switch (comptime COMP) {
            .X => {
                return @floatFromInt(self.horizontal);
            },
            .Y => {
                return @floatFromInt(self.vertical);
            },
        }
    }
    pub fn get_total(self: Gap, comptime COMP: Size.Comp, num_gaps: f32) f32 {
        switch (comptime COMP) {
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
    };

    fn get_id_not_impl(_: *anyopaque) usize {
        @panic("get_user_id() not implemented on the LayoutRequester");
    }
    fn get_type_not_impl(_: *anyopaque) usize {
        @panic("get_user_type() not implemented on the LayoutRequester");
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

const MinSize = struct {
    from_self_or_leftover: Size,
    from_children_or_final_size: Size = .ZERO,
};

const MinSize_OR_FinalAABB = union {
    min_size: MinSize,
    final_aabb: AABB,
    final_rect: Rect,

    pub fn new(min_x: f32, min_y: f32) MinSize_OR_FinalAABB {
        return MinSize_OR_FinalAABB{ .min_size = .{ .from_self_or_leftover = .new(min_x, min_y) } };
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

const LayoutElement = struct {
    requester: LayoutRequester,
    _ms_fbb: MinSize_OR_FinalAABB,
    _mg_fcbb: MaxSizeGrowRatio_OR_FinalClipAABB,
    relative_pos: Pos = .ZERO,
    padding: Padding,
    child_gaps: Gap,
    first_child: u32 = NULL_IDX,
    last_child: u32 = NULL_IDX,
    parent_idx: u32,
    depth: u32,
    child_align: ChildAlignment,
    float_parent_attach: AttachPoint,
    float_child_attach: AttachPoint,
    layout_dir: LayoutDirection,
    is_floating: bool,
    clip_to_parent: bool,
    grow_mode_w: GrowMode,
    grow_mode_h: GrowMode,
    completely_clipped: bool = false,

    inline fn set_min_self(self: *LayoutElement, comptime COMP: Size.Comp, val: f32) void {
        self._ms_fbb.min_size.from_self_or_leftover.set(COMP, val);
    }
    inline fn get_min_self(self: LayoutElement, comptime COMP: Size.Comp) f32 {
        return self._ms_fbb.min_size.from_self_or_leftover.get(COMP);
    }
    inline fn set_space_leftover(self: *LayoutElement, comptime COMP: Size.Comp, val: f32) void {
        self._ms_fbb.min_size.from_self_or_leftover.set(COMP, val);
    }
    inline fn get_space_leftover(self: LayoutElement, comptime COMP: Size.Comp) f32 {
        return self._ms_fbb.min_size.from_self_or_leftover.get(COMP);
    }
    inline fn set_min_children(self: *LayoutElement, comptime COMP: Size.Comp, val: f32) void {
        self._ms_fbb.min_size.from_children_or_final_size.set(COMP, val);
    }
    inline fn add_min_children(self: *LayoutElement, comptime COMP: Size.Comp, val: f32) void {
        self._ms_fbb.min_size.from_children_or_final_size.set(COMP, self._ms_fbb.min_size.from_children_or_final_size.get(COMP) + val);
    }
    inline fn max_min_children(self: *LayoutElement, comptime COMP: Size.Comp, val: f32) void {
        self._ms_fbb.min_size.from_children_or_final_size.set(COMP, @max(self._ms_fbb.min_size.from_children_or_final_size.get(COMP), val));
    }
    inline fn get_min_children(self: LayoutElement, comptime COMP: Size.Comp) f32 {
        return self._ms_fbb.min_size.from_children_or_final_size.get(COMP);
    }
    inline fn set_final_size(self: *LayoutElement, comptime COMP: Size.Comp, val: f32) void {
        self._ms_fbb.min_size.from_children_or_final_size.set(COMP, val);
    }
    inline fn get_final_size(self: LayoutElement, comptime COMP: Size.Comp) f32 {
        return self._ms_fbb.min_size.from_children_or_final_size.get(COMP);
    }
    inline fn set_max(self: *LayoutElement, comptime COMP: Size.Comp, val: f32) void {
        self._mg_fcbb.size_grow.max.set(COMP, val);
    }
    inline fn get_max(self: LayoutElement, comptime COMP: Size.Comp) f32 {
        return self._mg_fcbb.size_grow.max.get(COMP);
    }
    inline fn set_grow_ratio(self: *LayoutElement, comptime COMP: Size.Comp, val: f32) void {
        self._mg_fcbb.size_grow.ratio.set(COMP, val);
    }
    inline fn get_grow_ratio(self: LayoutElement, comptime COMP: Size.Comp) f32 {
        return self._mg_fcbb.size_grow.ratio.get(COMP);
    }
    inline fn set_final_aabb(self: *LayoutElement, parent_abs: Pos) void {
        const final_size = self._ms_fbb.min_size.from_children_or_final_size;
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
};

const Error = error{
    NONE,
    PERCENT_NOT_IN_0_TO_1_RANGE,
    ELEMENT_ARENA_OUT_OF_SPACE,
    ID_MAP_OUT_OF_SPACE,
    INTERNAL_ERROR,
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

fn ArenaDef(comptime MAX_LEN: u32, comptime ELEM: type) type {
    return struct {
        const Self = @This();

        mem: [MAX_LEN]ELEM = undefined,
        len: u32 = 0,

        pub inline fn last(self: *Self) *ELEM {
            return &self.mem[self.len - 1];
        }
        pub inline fn get(self: *Self, idx: u32) *ELEM {
            return &self.mem[idx];
        }
        pub inline fn has_room_for_n_more(self: *const Self, n: u32) bool {
            return self.len + n <= MAX_LEN;
        }
        pub inline fn push(self: *Self, val: ELEM) void {
            self.mem[self.len] = val;
            self.len += 1;
        }
        pub inline fn pop(self: *Self) void {
            self.len -= 1;
        }
        pub inline fn restart(self: *Self, val: ELEM) void {
            self.len = 1;
            self.mem[0] = val;
        }

        pub const Util = Utils.DataManipulation.Defaults.classically_indexed_mem_not_allocated_package(*Self, u32, LayoutElement, &.{"mem"}, &.{"len"});
    };
}

const TraverseFrame = struct {
    this_idx: u32,
    children_remaining: u32,
    next_relative_child_idx: u32 = 0,
    last_child_added_idx: u32 = NULL_IDX,
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

pub fn LayoutManager(comptime MAX_NUM_ELEMENTS: u32) type {
    assert_with_reason(MAX_NUM_ELEMENTS >= 1, @src(), "MAX_NUM_ELEMENTS must be at least 1", .{});
    return struct {
        const Self = @This();

        elements: [MAX_NUM_ELEMENTS]LayoutElement = undefined,
        elements_len: u32 = 0,
        real_max_elements: u32 = 1,
        real_max_depth: u32 = 1,
        err: Error = Error.NONE,

        inline fn append_new_layout_from_elem_and_parent(self: *Self, requester: LayoutRequester, parent: u32) *LayoutElement {
            assert_with_reason(self.elements_len < MAX_NUM_ELEMENTS, @src(), "out of space for layout elements: increase MAX_NUM_ELEMENTS comptime input to at least {d}", .{MAX_NUM_ELEMENTS + 1});
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
            };
            if (parent != NULL_IDX) {
                var par: *LayoutElement = &self.elements[parent];
                par.first_child = self.elements_len;
                if (par.last_child == NULL_IDX) {
                    par.last_child = self.elements_len;
                }
            }
            self.elements[self.elements_len] = elem;
            self.elements_len += 1;
            return &self.elements[self.elements_len - 1];
        }

        pub fn collect_element_heirarchy_in_breadth_first_children_first_order_reversed(self: *Self, root_element: LayoutRequester) void {
            self.elements_len = 0;
            self.append_new_layout_from_elem_and_parent(root_element, NULL_IDX);
            var next_layout_idx_with_unchecked_children: u32 = 0;

            while (next_layout_idx_with_unchecked_children < self.layout_len) {
                const parent_layout: *LayoutElement = &self.elements[next_layout_idx_with_unchecked_children];
                var possible_child_element = parent_layout.requester.get_last_child();
                while (possible_child_element) |child_element| {
                    const child_layout = self.append_new_layout_from_elem_and_parent(child_element, next_layout_idx_with_unchecked_children);
                    possible_child_element = child_layout.requester.get_prev_sibling();
                }
                next_layout_idx_with_unchecked_children += 1;
            }
            self.real_max_elements = @max(self.real_max_elements, self.elements_len);
        }

        pub fn recalculate_layout(self: *Self, comptime DRIVING_AXIS: Size.Comp) Error {
            const SECONDARY_AXIS = comptime switch (DRIVING_AXIS) {
                .X => Size.Comp.Y,
                .Y => Size.Comp.X,
            };
            if (self.elements_len == 0) return self.err;
            self.propogate_minimums_to_parents(DRIVING_AXIS);
            self.grow_and_shrink(DRIVING_AXIS);
            self.recheck_element_sizes_with_with_known_primary_size(DRIVING_AXIS);
            self.propogate_minimums_to_parents(SECONDARY_AXIS);
            self.grow_and_shrink(SECONDARY_AXIS);
            self.position_and_align_all_elements();
            return self.err;
        }

        fn propogate_minimums_to_parents(self: *Self, comptime COMP: Size.Comp) void {
            var this_idx: u32 = self.elements_len;
            while (this_idx > 1) {
                this_idx -= 1;
                self.elements[this_idx].add_min_children(COMP, self.elements[this_idx].padding.get(COMP));
                self.elements[this_idx].set_min_self(COMP, @min(@max(self.elements[this_idx].get_min_self(COMP), self.elements[this_idx].get_min_children(COMP)), self.elements[this_idx].get_max(COMP)));
                if (self.elements[this_idx].is_floating) continue;
                const parent_idx = self.elements[this_idx].parent_idx;
                if (self.elements[parent_idx].grow_mode_w != .EXACT) {
                    switch (self.elements[parent_idx].layout_dir.relative_axis_for_primary(COMP)) {
                        .SAME => {
                            // TODO implement flex (min only needs to be as large as widest)
                            if (self.elements[parent_idx].first_child != this_idx) {
                                self.elements[parent_idx].add_min_children(COMP, self.elements[parent_idx].child_gaps.get(COMP) + self.elements[this_idx].get_min_self(COMP));
                            } else {
                                self.elements[parent_idx].add_min_children(COMP, self.elements[this_idx].get_min_self(COMP));
                            }
                        },
                        .DIFFERENT => {
                            self.elements[parent_idx].max_min_children(COMP, self.elements[this_idx].get_min_self(COMP));
                        },
                    }
                }
            }
        }

        //breadth top_to_bottom
        fn grow_and_shrink(self: *Self, comptime COMP: Size.Comp) void {
            var parent_idx: u32 = 0;
            //CHECKPOINT update to use COMP
            while (parent_idx < self.elements_len) : (parent_idx += 1) {
                const first_child_idx = self.elements[parent_idx].first_child;
                const last_child_idx = self.elements[parent_idx].last_child;
                const parent_padding = self.elements[parent_idx].padding;
                const parent_gaps = self.elements[parent_idx].child_gaps;
                const num_gaps = @as(f32, @floatFromInt(last_child_idx - first_child_idx));
                var child_idx: u32 = first_child_idx;
                if (child_idx != NULL_IDX) {
                    switch (self.elements[parent_idx].layout_dir.primary_axis()) {
                        .HORIZONTAL => {
                            var remaining_free_horiz_space = self.elements[parent_idx].min_width_from_children_or_final_width - parent_padding.h_padding() - parent_gaps.total_h_gap(num_gaps);
                            var total_min_width: f32 = 0;
                            var has_at_least_one_grow: bool = false;
                            while (child_idx <= last_child_idx) : (child_idx += 1) {
                                const child_min = self.elements[child_idx].min_size_width_or_leftover_horiz;
                                self.elements[child_idx].min_width_from_children_or_final_width = child_min;
                                total_min_width += child_min;
                                has_at_least_one_grow = has_at_least_one_grow or self.elements[child_idx].grow_mode_w == .GROW;
                            }
                            remaining_free_horiz_space = remaining_free_horiz_space - total_min_width;
                            if (has_at_least_one_grow and total_min_width < remaining_free_horiz_space) {
                                while (remaining_free_horiz_space >= 0.001) {
                                    var total_grow_weight_this_pass: f32 = 0;
                                    var num_elements_to_distrubute_across: f32 = 0;
                                    var total_space_claimed_this_pass: f32 = 0;
                                    child_idx = first_child_idx;
                                    while (child_idx <= last_child_idx) : (child_idx += 1) {
                                        if (self.elements[child_idx].grow_mode_w == .GROW and self.elements[child_idx].min_width_from_children_or_final_width < self.elements[child_idx].max_size_width) {
                                            total_grow_weight_this_pass += self.elements[child_idx].grow_ratio_w;
                                            num_elements_to_distrubute_across += 1;
                                        }
                                    }
                                    if (num_elements_to_distrubute_across == 0 or total_grow_weight_this_pass == 0) break;
                                    child_idx = first_child_idx;
                                    while (child_idx <= last_child_idx) : (child_idx += 1) {
                                        if (self.elements[child_idx].grow_mode_w == .GROW and self.elements[child_idx].min_width_from_children_or_final_width < self.elements[child_idx].max_size_width) {
                                            var space_to_claim = remaining_free_horiz_space * (self.elements[child_idx].grow_ratio_w / total_grow_weight_this_pass);
                                            var new_width = self.elements[child_idx].min_width_from_children_or_final_width + space_to_claim;
                                            if (new_width >= self.elements[child_idx].max_size_width) {
                                                new_width = self.elements[child_idx].max_size_width;
                                                space_to_claim = new_width - self.elements[child_idx].min_width_from_children_or_final_width;
                                            }
                                            total_space_claimed_this_pass += space_to_claim;
                                            self.elements[child_idx].min_width_from_children_or_final_width = new_width;
                                        }
                                    }
                                    remaining_free_horiz_space -= total_space_claimed_this_pass;
                                    if (total_space_claimed_this_pass < 0.001) break;
                                }
                            }
                            self.elements[parent_idx].min_size_width_or_leftover_horiz = remaining_free_horiz_space;
                        },
                        .VERTICAL => {
                            const free_horiz_space = self.elements[parent_idx].min_width_from_children_or_final_width - parent_padding.h_padding();
                            var max_horiz_space_used: f32 = 0;
                            while (child_idx <= last_child_idx) : (child_idx += 1) {
                                switch (self.elements[child_idx].grow_mode_w) {
                                    .EXACT, .SHRINK => {
                                        self.elements[child_idx].min_width_from_children_or_final_width = self.elements[child_idx].min_size_width_or_leftover_horiz;
                                    },
                                    .GROW => {
                                        self.elements[child_idx].min_width_from_children_or_final_width = @max(@min(free_horiz_space, self.elements[child_idx].max_size_width), self.elements[child_idx].min_size_width_or_leftover_horiz);
                                    },
                                }
                                max_horiz_space_used = @max(max_horiz_space_used, self.elements[child_idx].min_width_from_children_or_final_width);
                            }
                            const leftover_horiz = max_horiz_space_used - free_horiz_space;
                            self.elements[parent_idx].min_size_width_or_leftover_horiz = leftover_horiz;
                        },
                    }
                }
                var free_space: f32 = self.elements[parent_idx].max_size_width - self.elements[parent_idx].min_width_from_children_or_final_width;
                var total_grow_weight: f32 = 0;

                while (child_idx <= self.elements[parent_idx].last_child) : (child_idx += 1) {
                    if (self.elements[child_idx].is_floating) continue;
                    switch (self.elements[parent_idx].grow_mode_w) {
                        .EXACT, .SHRINK => {
                            self.elements[parent_idx].min_width_from_children_or_final_width = self.elements[parent_idx].min_size_width_or_leftover_horiz;
                        },
                        .GROW => {
                            total_grow_weight += self.elements[child_idx].grow_ratio_w;
                        },
                    }
                }
                child_idx = self.elements[parent_idx].first_child;
                while (child_idx <= self.elements[parent_idx].last_child) : (child_idx += 1) {
                    if (self.elements[child_idx].is_floating or self.elements[child_idx].grow_mode_w != .GROW) continue;
                    var free_space_used = free_space * (self.elements[child_idx].grow_ratio_w / total_grow_weight);
                    var new_width = self.elements[child_idx].min_size_width_or_leftover_horiz + free_space_used;
                    new_width = @min(new_width, self.elements[child_idx].max_size_width);
                    free_space_used = new_width - self.elements[child_idx].min_size_width_or_leftover_horiz;
                    free_space -= free_space_used;
                    self.elements[child_idx].min_width_from_children_or_final_width = new_width;
                }
            }
        }

        fn recheck_element_sizes_with_with_known_primary_size(self: *Self, comptime DRIVING_AXIS: Size.Comp) void {
            //CHECKPOINT COMP
            var i: u32 = self.elements_len;
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
        fn propogate_minimum_heights_to_parents(self: *Self) void {
            var i: u32 = self.elements_len;
            while (i > 1) : (i -= 1) {
                var this_layout: *LayoutElement = &self.elements[i];
                this_layout.min_height_from_children_or_final_height += this_layout.padding.top + this_layout.padding.bottom;
                this_layout.min_size_height_or_leftover_vert = @min(@max(this_layout.min_size_height_or_leftover_vert, this_layout.min_height_from_children_or_final_height), this_layout.max_size_height);
                if (this_layout.is_floating) continue;
                var parent: *LayoutElement = &self.elements[this_layout.parent_idx];
                if (parent.grow_mode_h != .EXACT) {
                    switch (parent.layout_dir.primary_axis()) {
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
        fn grow_and_shrink_heights(self: *Self) void {
            var parent_idx: u32 = 0;
            while (parent_idx < self.elements_len) : (parent_idx += 1) {
                const first_child_idx = self.elements[parent_idx].first_child;
                const last_child_idx = self.elements[parent_idx].last_child;
                const parent_padding = self.elements[parent_idx].padding;
                const parent_gaps = self.elements[parent_idx].child_gaps;
                const num_gaps = @as(f32, @floatFromInt(last_child_idx - first_child_idx));
                var child_idx: u32 = first_child_idx;
                if (child_idx != NULL_IDX) {
                    switch (self.elements[parent_idx].layout_dir.primary_axis()) {
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

        fn position_and_align_all_elements(self: *Self) void {
            var parent_idx: u32 = 0;
            while (parent_idx < self.elements_len) : (parent_idx += 1) {
                const parent_abs_pos = self.elements[parent_idx].absolute_pos;
                const first_child_idx = self.elements[parent_idx].first_child;
                const last_child_idx = self.elements[parent_idx].last_child;
                const parent_padding = self.elements[parent_idx].padding;
                const parent_gaps = self.elements[parent_idx].child_gaps;
                const num_gaps = @as(f32, @floatFromInt(last_child_idx - first_child_idx));
                const primary_axis = self.elements[parent_idx].layout_dir.primary_axis();
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

        pub fn handle_events_on_heirarchy_from_children_to_parents(self: *const Self, events: []EventAtLocation) void {
            var i: u32 = self.elements_len;
            while (i > 0) {
                i -= 1;
                const elem = self.elements[i];
                for (events) |*e| {}
            }
        }

        pub fn execute_final_layout_handlers_for_all_elements_parents_first(self: *const Self) void {
            var i: u32 = 0;
            while (i < self.elements_len) : (i += 1) {
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
}
