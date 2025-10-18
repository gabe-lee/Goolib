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
const Flags = Root.Flags.Flags;
const IList = Root.IList.IList;
const List = Root.IList_List.List;
const Range = Root.IList.Range;

const IList16 = IList(u16);
const List16 = List(u16);

pub const Metadata = struct {
    hookups_raw: List16,
    calc_id: CalcID,
    val_idx: ValIdx,
    param_type: ParamType,
    flags: PFlags,
    children_start: u8,
    siblings_start: u8,

    pub fn is_free(self: Metadata) bool {
        return self.flags.has_flag(.FREE);
    }
    pub fn is_used(self: Metadata) bool {
        return !self.flags.has_flag(.FREE);
    }
    pub fn set_used(self: Metadata) void {
        self.flags.clear(.FREE);
    }
    pub fn set_free(self: Metadata) void {
        self.flags.set(.FREE);
    }

    pub fn should_always_update(self: Metadata) bool {
        return self.flags.has_flag(.ALWAYS_UPDATE);
    }
    pub fn only_update_on_change(self: Metadata) bool {
        return !self.flags.has_flag(.ALWAYS_UPDATE);
    }
    pub fn set_always_update(self: Metadata) void {
        self.flags.set(.ALWAYS_UPDATE);
    }
    pub fn set_only_update_on_change(self: Metadata) void {
        self.flags.clear(.ALWAYS_UPDATE);
    }

    pub fn has_siblings(self: Metadata) bool {
        return self.flags.has_flag(.HAS_SIBLINGS);
    }
    pub fn no_siblings(self: Metadata) bool {
        return !self.flags.has_flag(.HAS_SIBLINGS);
    }
    pub fn set_siblings(self: Metadata) void {
        self.flags.set(.HAS_SIBLINGS);
    }
    pub fn set_no_siblings(self: Metadata) void {
        self.flags.clear(.HAS_SIBLINGS);
    }

    pub fn has_parent(self: Metadata) bool {
        return self.flags.has_flag(.HAS_PARENT);
    }
    pub fn no_parent(self: Metadata) bool {
        return !self.flags.has_flag(.HAS_PARENT);
    }
    pub fn set_has_parent(self: Metadata) void {
        self.flags.set(.HAS_PARENT);
    }
    pub fn set_no_parent(self: Metadata) void {
        self.flags.clear(.HAS_PARENT);
    }

    pub fn has_children(self: Metadata) bool {
        return self.flags.has_flag(.HAS_CHILDREN);
    }
    pub fn no_children(self: Metadata) bool {
        return !self.flags.has_flag(.HAS_CHILDREN);
    }
    pub fn set_has_children(self: Metadata) void {
        self.flags.set(.HAS_CHILDREN);
    }
    pub fn set_no_children(self: Metadata) void {
        self.flags.clear(.HAS_CHILDREN);
    }

    pub fn has_calc(self: Metadata) bool {
        return self.flags.has_flag(.HAS_CALC);
    }
    pub fn no_calc(self: Metadata) bool {
        return !self.flags.has_flag(.HAS_CALC);
    }
    pub fn set_has_calc(self: Metadata) void {
        self.flags.set(.HAS_CALC);
    }
    pub fn set_no_calc(self: Metadata) void {
        self.flags.clear(.HAS_CALC);
    }

    pub fn is_type(self: Metadata, t: ParamType) bool {
        return self.param_type == t;
    }
};

pub const Hookups = struct {

};

pub const CalcID = struct {
    id: u16 = 0,
};

pub const ParamId = struct {
    id: u16 = 0,
};

pub const ValIdx = struct {
    idx: u16 = 0,
};

pub const ParamType = enum(u8) {
    INVALID,
    U64,
    I64,
    F64,
    USIZE,
    ISIZE,
    U32,
    I32,
    F32,
    U16,
    I16,
    F16,
    U8,
    I8,
    BOOL,

    const _COUNT: u8 = @intFromEnum(ParamType.BOOL) + 1;

    pub const NAMES = [_COUNT][]const u8{
        "<INVALID>",
        "U64",
        "I64",
        "F64",
        "USIZE",
        "ISIZE",
        "U32",
        "I32",
        "F32",
        "U16",
        "I16",
        "F16",
        "U8",
        "I8",
        "BOOL",
    };

    pub fn name(self: ParamType) []const u8 {
        return NAMES[@intFromEnum(self)];
    }
};

pub const PFlags: type = Flags(enum(u8) {
    FREE = 1 << 0,
    ALWAYS_UPDATE = 1 << 1,
    HAS_CHILDREN = 1 << 2,
    HAS_SIBLINGS = 1 << 3,
    HAS_PARENT = 1 << 4,
    HAS_CALC = 1 << 5,
}, enum(u8) {});
