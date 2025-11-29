//! //TODO Documentation
//! #### License: Zlib

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
const math = std.math;
const Root = @import("./_root.zig");
const SliceAdapter = Root.IList_SliceAdapter;
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const IList = Root.IList.IList;
const List = Root.IList_List.List;
const Range = Root.IList.Range;
const Flags = Root.Flags;
const MSList = Root.IList.MultiSortList;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const assert_field_is_type = Assert.assert_field_is_type;

const ParamTable = Root.ParamTable;
const ParamCalc = ParamTable.Calc.ParamCalc;
const ParamId = ParamTable.Meta.ParamId;
const Table = ParamTable.Table;
const ParamFactorySlot = ParamTable.ParamFactorySlot;
const PTList = ParamTable.PTList;
const PTPtr = ParamTable.PTPtr;

pub const ElementSorts = enum(u8) {
    free,
    visible_by_zindex,
    mouse_hover_unhover_by_zindex,
    mouse_down_up_by_zindex,
    mouse_click_by_zindex,
};

const ElementList = MSList(Element, Element{}, u16, ElementSorts, *Table);
const SortInit = ElementList.SortInit;

fn element_equal(a: Element, b: Element, _: *Table) bool {
    return a.self_idx == b.self_idx;
}
fn zindex_greater_than(a: Element, b: Element, t: *Table) bool {
    const a_zindex = t.get_u32(a.z_index);
    const b_zindex = t.get_u32(b.z_index);
    return a_zindex > b_zindex;
}
fn zindex_equal(a: Element, b: Element, t: *Table) bool {
    const a_zindex = t.get_u32(a.z_index);
    const b_zindex = t.get_u32(b.z_index);
    return a_zindex == b_zindex;
}
fn visible_filter(elem: Element, t: *Table) bool {
    const flags = PanelFlags.from_raw(t.get_u32(elem.flags));
    return !flags.has_flag(.is_free_memory) and flags.has_flag(.visible);
}
fn mouse_hover_unhover_filter(elem: Element, t: *Table) bool {
    const flags = PanelFlags.from_raw(t.get_u32(elem.flags));
    return !flags.has_flag(.is_free_memory) and flags.has_raw(PanelFlagsEnum.visible_and_use_mouse_hover);
}
fn mouse_down_up_filter(elem: Element, t: *Table) bool {
    const flags = PanelFlags.from_raw(t.get_u32(elem.flags));
    return !flags.has_flag(.is_free_memory) and flags.has_raw(PanelFlagsEnum.visible_and_use_mouse_down);
}
fn mouse_click_filter(elem: Element, t: *Table) bool {
    const flags = PanelFlags.from_raw(t.get_u32(elem.flags));
    return !flags.has_flag(.is_free_memory) and flags.has_raw(PanelFlagsEnum.visible_and_use_mouse_click);
}
fn free_memory_filter(elem: Element, t: *Table) bool {
    const flags = PanelFlags.from_raw(t.get_u32(elem.flags));
    return flags.has_flag(.is_free_memory);
}
const FILTER_FREE_MEM = SortInit{
    .equal = element_equal,
    .greater_than = null,
    .filter = free_memory_filter,
    .name = .free,
};
const SORT_VISIBLE = SortInit{
    .equal = zindex_equal,
    .greater_than = zindex_greater_than,
    .filter = visible_filter,
    .name = .visible_by_zindex,
};
const SORT_MOUSE_HOVER = SortInit{
    .equal = zindex_equal,
    .greater_than = zindex_greater_than,
    .filter = mouse_hover_unhover_filter,
    .name = .mouse_hover_unhover_by_zindex,
};
const SORT_MOUSE_CLICK = SortInit{
    .equal = zindex_equal,
    .greater_than = zindex_greater_than,
    .filter = mouse_click_filter,
    .name = .mouse_click_by_zindex,
};
const SORT_MOUSE_DOWN = SortInit{
    .equal = zindex_equal,
    .greater_than = zindex_greater_than,
    .filter = mouse_down_up_filter,
    .name = .mouse_down_up_by_zindex,
};
const SORT_INITS = [_]SortInit{
    FILTER_FREE_MEM,
    SORT_VISIBLE,
    SORT_MOUSE_HOVER,
    SORT_MOUSE_CLICK,
    SORT_MOUSE_DOWN,
};
pub const UI_Manager = struct {
    table: *Table,
    element_list_alloc: Allocator,
    elements: ElementList,

    pub fn init_capacity(element_cap: u16, table: *Table, element_alloc: Allocator) UI_Manager {
        return UI_Manager{
            .table = table,
            .element_list_alloc = element_alloc,
            .elements = ElementList.init_capacity(@intCast(element_cap), @intCast(element_cap), element_alloc, element_equal, table, &SORT_INITS),
        };
    }

    pub fn free(self: UI_Manager) void {
        // TODO: go through and delete all parameters from ParamTable (right now deletion isnt possible)
        self.element_list_alloc.free(self.element_list_alloc);
    }
};

pub const UI_Id = u16;
const NULL_ID: u16 = math.maxInt(u16);

pub const Element = struct {
    self_idx: ParamId = .new_null(),
    parent_idx: ParamId = .new_null(),
    north_sibling_idx: ParamId = .new_null(),
    east_sibling_idx: ParamId = .new_null(),
    south_sibling_idx: ParamId = .new_null(),
    west_sibling_idx: ParamId = .new_null(),
    children_idxs: ParamId = .new_null(),
    z_index: ParamId = .new_null(),
    x_pos: ParamId = .new_null(),
    y_pos: ParamId = .new_null(),
    width: ParamId = .new_null(),
    height: ParamId = .new_null(),
    color_1: ParamId = .new_null(),
    color_2: ParamId = .new_null(),
    border_w: ParamId = .new_null(),
    flags: ParamId = .new_null(),
    on_mouse_action: ParamId = .new_null(),
    on_key_action: ParamId = .new_null(),
    on_focus_unfocus: ParamId = .new_null(),
    on_disable_enable: ParamId = .new_null(),
    extra_data_mode: ParamId = .new_null(),
    extra_data_1: ParamId = .new_null(),
    extra_data_2: ParamId = .new_null(),
    extra_data_3: ParamId = .new_null(),
    extra_data_4: ParamId = .new_null(),
    extra_data_5: ParamId = .new_null(),
    extra_data_6: ParamId = .new_null(),
};

pub const MouseActionState = Flags.Flags(enum(u32) {
    left_held_up = 0b00 << 0,
    left_just_pressed = 0b01 << 0,
    left_held_down = 0b10 << 0,
    left_just_released = 0b11 << 0,
    middle_held_up = 0b00 << 2,
    middle_just_pressed = 0b01 << 2,
    middle_held_down = 0b10 << 2,
    middle_just_released = 0b11 << 2,
    right_held_up = 0b00 << 4,
    right_just_pressed = 0b01 << 4,
    right_held_down = 0b10 << 4,
    right_just_released = 0b11 << 4,
    button_4_held_up = 0b00 << 6,
    button_4_just_pressed = 0b01 << 6,
    button_4_held_down = 0b10 << 6,
    button_4_just_released = 0b11 << 6,
    button_5_held_up = 0b00 << 8,
    button_5_just_pressed = 0b01 << 8,
    button_5_held_down = 0b10 << 8,
    button_5_just_released = 0b11 << 8,
    button_6_held_up = 0b00 << 10,
    button_6_just_pressed = 0b01 << 10,
    button_6_held_down = 0b10 << 10,
    button_6_just_released = 0b11 << 10,
    button_7_held_up = 0b00 << 12,
    button_7_just_pressed = 0b01 << 12,
    button_7_held_down = 0b10 << 12,
    button_7_just_released = 0b11 << 12,
    button_8_held_up = 0b00 << 14,
    button_8_just_pressed = 0b01 << 14,
    button_8_held_down = 0b10 << 14,
    button_8_just_released = 0b11 << 14,
}, enum(u8) {});

pub const KeyboardActionMode = enum(u8) {
    keycode,
    character,
};

pub const KeyState = enum(u8) {
    up_position = 0,
    just_pressed = 1,
    held_down = 2,
    just_released = 3,
};

pub const KeyboardActionState = union(KeyboardActionMode) {
    keycode: struct {
        code: u32,
        mods: u32,
        state: KeyState,
    },
    character: u32,
};

pub const FocusState = enum(u8) {
    unfocused = 0b100,
    just_focused = 0b011,
    still_focused = 0b001,
    just_unfocused = 0b110,
};

pub const EnabledState = enum(u8) {
    disabled = 0b100,
    just_enabled = 0b011,
    still_enabled = 0b001,
    just_disabled = 0b110,
};

pub const ExtraDataModes = enum(u8) {
    none,
    text,
    sprite,
};

pub const MouseActionFn = fn (table: *Table, element: Element, x_pos: f32, y_pos: f32, x_delta: f32, y_delta: f32, state: MouseActionState) void;
pub const KeyboardActionFn = fn (table: *Table, element: Element, state: KeyboardActionState) void;
pub const FocusActionFn = fn (table: *Table, element: Element, state: FocusState) void;
pub const EnableActionFn = fn (table: *Table, element: Element, state: EnabledState) void;

pub const SizeParams = struct {
    width: ParamId,
    height: ParamId,
};

pub const TextFactory = struct {
    self_idx: ParamFactorySlot(1, u16) = .new_omit(),
    parent_idx: ParamFactorySlot(1, u16) = .new_omit(),
    north_sibling_idx: ParamFactorySlot(1, u16) = .new_omit(),
    east_sibling_idx: ParamFactorySlot(1, u16) = .new_omit(),
    south_sibling_idx: ParamFactorySlot(1, u16) = .new_omit(),
    west_sibling_idx: ParamFactorySlot(1, u16) = .new_omit(),
    children_idxs: ParamFactorySlot(1, PTList(u16)) = .new_omit(),
    z_index: ParamFactorySlot(1, u16) = .new_omit(),
    x_pos: ParamFactorySlot(1, f32) = .new_omit(),
    y_pos: ParamFactorySlot(1, f32) = .new_omit(),
    width_height: ParamFactorySlot(2, f32) = .new_omit(),
    color_1: ParamFactorySlot(1, u32) = .new_omit(),
    color_2: ParamFactorySlot(1, u32) = .new_omit(),
    border_w: ParamFactorySlot(1, f32) = .new_omit(),
    flags: ParamFactorySlot(1, u32) = .new_omit(),
    on_mouse_action: ParamFactorySlot(1, PTPtr(MouseActionFn)) = .new_omit(),
    on_keyboard_action: ParamFactorySlot(1, PTPtr(KeyboardActionFn)) = .new_omit(),
    on_focus_unfocus: ParamFactorySlot(1, PTPtr(FocusActionFn)) = .new_omit(),
    on_disable_enable: ParamFactorySlot(1, PTPtr(EnableActionFn)) = .new_omit(),
    extra_data_mode: ParamFactorySlot(1, u8) = .new_omit(),
    extra_data_1: ParamFactorySlot(1, PTList(u8)) = .new_omit(), // text content
    extra_data_2: ParamFactorySlot(1, u8) = .new_omit(), // font id
    extra_data_3: ParamFactorySlot(1, f32) = .new_omit(), // font size
    extra_data_4: ParamFactorySlot(1, u32) = .new_omit(), // cursor pos
    extra_data_5: ParamFactorySlot(1, f32) = .new_omit(), // max width
    extra_data_6: ParamFactorySlot(1, f32) = .new_omit(), // max height
};

pub const PanelFlagsEnum = enum(u32) {
    visible = 1 << 0,
    use_mouse_hover = 1 << 1,
    send_mouse_hover_to_parent = 1 << 2,
    use_mouse_hover__dont_send_to_parent = 0b01 << 1,
    dont_use_mouse_hover__send_to_parent = 0b10 << 1,
    use_mouse_hover__also_send_to_parent = 0b11 << 1,
    use_mouse_down_up = 1 << 3,
    send_mouse_down_up_to_parent = 1 << 4,
    use_mouse_down_up__dont_send_to_parent = 0b01 << 3,
    dont_use_mouse_down_up__send_to_parent = 0b10 << 3,
    use_mouse_down_up__also_send_to_parent = 0b11 << 3,
    use_mouse_click = 1 << 5,
    send_mouse_click_to_parent = 1 << 6,
    use_mouse_click__dont_send_to_parent = 0b01 << 5,
    dont_use_mouse_click__send_to_parent = 0b10 << 5,
    use_mouse_click__also_send_to_parent = 0b11 << 5,
    use_mouse_drag = 1 << 7,
    send_mouse_drag_to_parent = 1 << 8,
    use_mouse_drag__dont_send_to_parent = 0b01 << 7,
    dont_use_mouse_drag__send_to_parent = 0b10 << 7,
    use_mouse_drag__also_send_to_parent = 0b11 << 7,
    draw_border_north = 1 << 9,
    draw_border_east = 1 << 10,
    draw_border_south = 1 << 11,
    draw_border_west = 1 << 12,
    disabled = 1 << 13,
    focused = 1 << 14,
    use_key_char = 1 << 15,
    send_key_char_to_parent = 1 << 16,
    use_key_char__dont_send_to_parent = 0b01 << 15,
    dont_use_key_char__send_to_parent = 0b10 << 15,
    use_key_char__also_send_to_parent = 0b11 << 15,
    use_key_char_as_char = 1 << 17,
    mouse_is_down = 1 << 18,
    mouse_is_hovered = 1 << 19,
    is_being_dragged = 1 << 20,
    use_sprite = 1 << 21,
    is_free_memory = 1 << 22,

    pub const visible_and_use_mouse_hover = PanelFlagsEnum.visible.to_raw() | PanelFlagsEnum.use_mouse_hover.to_raw();
    pub const visible_and_use_mouse_down = PanelFlagsEnum.visible.to_raw() | PanelFlagsEnum.use_mouse_down_up.to_raw();
    pub const visible_and_use_mouse_click = PanelFlagsEnum.visible.to_raw() | PanelFlagsEnum.use_mouse_click.to_raw();

    pub fn to_raw(self: PanelFlagsEnum) u32 {
        return @intFromEnum(self);
    }
};

pub const PanelFlags = Flags.Flags(PanelFlagsEnum, enum(u32) {
    mouse_hover_mode = 0b11 << 1,
    mouse_down_up_mode = 0b11 << 3,
    mouse_click_mode = 0b11 << 5,
    mouse_drag_mode = 0b11 << 7,
    border_mode = 0b1111 << 9,
    active_state = (1 << 0) | (1 << 13) | (1 << 14) | (1 << 18) | (1 << 19) | (1 << 20) | (1 << 22),
    key_char_mode = 0b11 << 15 | (1 << 17),
});
