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

const ParamTable = Root.ParamTable;

const IList16 = IList(u16);
const ListParamId = List(ParamId);

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

const intcast = Types.intcast;

pub const Metadata = struct {
    hookups_raw: ListParamId,
    calc_id: CalcID,
    val_idx: u16,
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
    pub fn set_used(self: *Metadata) void {
        self.flags.clear(.FREE);
    }
    pub fn set_free(self: *Metadata) void {
        self.flags.set(.FREE);
    }

    pub fn should_always_update(self: Metadata) bool {
        return self.flags.has_flag(.ALWAYS_UPDATE);
    }
    pub fn only_update_on_change(self: Metadata) bool {
        return !self.flags.has_flag(.ALWAYS_UPDATE);
    }
    pub fn set_always_update(self: *Metadata) void {
        self.flags.set(.ALWAYS_UPDATE);
    }
    pub fn set_only_update_on_change(self: *Metadata) void {
        self.flags.clear(.ALWAYS_UPDATE);
    }

    pub fn has_siblings(self: Metadata) bool {
        return self.flags.has_flag(.HAS_SIBLINGS);
    }
    pub fn no_siblings(self: Metadata) bool {
        return !self.flags.has_flag(.HAS_SIBLINGS);
    }
    pub fn set_has_siblings(self: *Metadata) void {
        self.flags.set(.HAS_SIBLINGS);
    }
    pub fn set_no_siblings(self: *Metadata) void {
        self.flags.clear(.HAS_SIBLINGS);
    }

    pub fn has_parent(self: Metadata) bool {
        return self.flags.has_flag(.HAS_PARENT);
    }
    pub fn no_parent(self: Metadata) bool {
        return !self.flags.has_flag(.HAS_PARENT);
    }
    pub fn set_has_parent(self: *Metadata) void {
        self.flags.set(.HAS_PARENT);
    }
    pub fn set_no_parent(self: *Metadata) void {
        self.flags.clear(.HAS_PARENT);
    }

    pub fn has_children(self: Metadata) bool {
        return self.flags.has_flag(.HAS_CHILDREN);
    }
    pub fn no_children(self: Metadata) bool {
        return !self.flags.has_flag(.HAS_CHILDREN);
    }
    pub fn set_has_children(self: *Metadata) void {
        self.flags.set(.HAS_CHILDREN);
    }
    pub fn set_no_children(self: *Metadata) void {
        self.flags.clear(.HAS_CHILDREN);
    }

    pub fn has_calc(self: Metadata) bool {
        return self.flags.has_flag(.HAS_CALC);
    }
    pub fn no_calc(self: Metadata) bool {
        return !self.flags.has_flag(.HAS_CALC);
    }
    pub fn set_has_calc(self: *Metadata) void {
        self.flags.set(.HAS_CALC);
    }
    pub fn set_no_calc(self: *Metadata) void {
        self.flags.clear(.HAS_CALC);
    }

    pub fn is_type(self: Metadata, t: ParamType) bool {
        return self.param_type == t;
    }

    pub fn get_hookups(self: Metadata, table: *ParamTable.Table) Hookups {
        return Hookups{
            .parents = self.hookups_raw.slice()[0..self.siblings_start],
            .siblings = self.hookups_raw.slice()[self.siblings_start..self.children_start],
            .children = self.hookups_raw.slice()[self.children_start..],
            .calc = if (self.has_calc()) table.calcs.get(@intCast(self.calc_id.id)) else null,
        };
    }

    pub fn get_children(self: Metadata) []ParamId {
        return self.hookups_raw.slice()[self.children_start..];
    }

    fn doesnt_have_child(self: *Metadata, child: ParamId) bool {
        const children = self.get_children();
        for (children) |c| {
            if (c.id == child.id) return false;
        }
        return true;
    }

    pub fn append_child(self: *Metadata, child: ParamId, alloc: Allocator) void {
        if (self.doesnt_have_child(child)) {
            _ = self.hookups_raw.append(child, alloc);
            // const real_idx: u16 = @intCast(self.hookups_raw.append(child, alloc));
            // return real_idx - Types.intcast(self.children_start, u16);
        }
    }

    pub fn append_children(self: *Metadata, children: []const ParamId, alloc: Allocator) void {
        for (children) |c| {
            self.append_child(c, alloc);
        }
        // const real_idx: u16 = @intCast(self.hookups_raw.append_zig_slice(alloc, children).first_idx);
        // return real_idx - Types.intcast(self.children_start, u16);
    }

    // pub fn insert_child(self: *Metadata, idx: u16, child: ParamId, alloc: Allocator) void {
    //     const real_idx = Types.intcast(self.children_start, usize) + Types.intcast(idx, usize);
    //     self.hookups_raw.insert(real_idx, child.id, alloc);
    // }

    // pub fn insert_children(self: *Metadata, idx: u16, children: []const ParamId, alloc: Allocator) void {
    //     const real_idx = Types.intcast(self.children_start, usize) + Types.intcast(idx, usize);
    //     self.hookups_raw.insert_zig_slice(real_idx, alloc, children);
    // }

    // pub fn delete_child(self: *Metadata, idx: u16) void {
    //     const real_idx = Types.intcast(self.children_start, usize) + Types.intcast(idx, usize);
    //     self.hookups_raw.delete(real_idx);
    // }

    // pub fn delete_children(self: *Metadata, idx: u16, count: u16) void {
    //     const real_idx = Types.intcast(self.children_start, usize) + Types.intcast(idx, usize);
    //     self.hookups_raw.delete_range(.from_idx_count(real_idx, count));
    // }

    pub fn assert_can_add_parents_or_siblings(self: Metadata, n: u16, comptime src: std.builtin.SourceLocation) void {
        assert_with_reason(intcast(self.children_start, u16) + n <= 255, src, "adding {d} more parents or siblings will exceed the limit (current children_start = {d}, only room for {d} more) (ParamType = {s}, ValIdx = {d})", .{ n, self.children_start, 255 - self.children_start, self.param_type.name(), self.val_idx });
    }

    pub fn assert_can_delete_siblings(self: Metadata, start: u16, count: u16, comptime src: std.builtin.SourceLocation) void {
        const sib_start = intcast(self.siblings_start, u16) + start;
        const sib_end = sib_start + count;
        assert_with_reason(sib_end <= intcast(self.children_start, u16), src, "cannot delete {d} siblings starting at sibling index {d}, only {d} siblings exist aftet that index (ParamType = {s}, ValIdx = {d})", .{ count, start, intcast(self.children_start, u16) - sib_start, self.param_type.name(), self.val_idx });
    }

    pub fn assert_can_delete_parents(self: Metadata, start: u16, count: u16, comptime src: std.builtin.SourceLocation) void {
        const par_start = start;
        const par_end = par_start + count;
        assert_with_reason(par_end <= intcast(self.siblings_start, u16), src, "cannot delete {d} parents starting at parent index {d}, only {d} parents exist aftet that index (ParamType = {s}, ValIdx = {d})", .{ count, start, intcast(self.siblings_start, u16) - par_start, self.param_type.name(), self.val_idx });
    }

    pub fn append_sibling(self: *Metadata, sibling: ParamId, alloc: Allocator) void {
        const real_idx = intcast(self.children_start, u16);
        self.assert_can_add_parents_or_siblings(1, @src());
        self.children_start += 1;
        _ = self.hookups_raw.insert(real_idx, sibling, alloc);
        // return real_idx - intcast(self.siblings_start, u16);
    }

    pub fn append_siblings(self: *Metadata, siblings: []const ParamId, alloc: Allocator) void {
        const real_idx = intcast(self.children_start, u16);
        self.assert_can_add_parents_or_siblings(@intCast(siblings.len), @src());
        self.children_start += @intCast(siblings.len);
        _ = self.hookups_raw.insert_zig_slice(real_idx, alloc, siblings);
        // return real_idx - intcast(self.siblings_start, u16);
    }

    // pub fn insert_sibling(self: *Metadata, idx: u16, sibling: ParamId, alloc: Allocator) u16 {
    //     const real_idx = intcast(self.siblings_start, u16) + idx;
    //     self.assert_can_add_parents_or_siblings(1, @src());
    //     self.children_start += 1;
    //     _ = self.hookups_raw.insert(real_idx, sibling.id, alloc);
    //     return real_idx - intcast(self.siblings_start, u16);
    // }

    // pub fn insert_siblings(self: *Metadata, idx: u16, siblings: []const ParamId, alloc: Allocator) u16 {
    //     const real_idx = intcast(self.siblings_start, u16) + idx;
    //     self.assert_can_add_parents_or_siblings(@intCast(siblings.len), @src());
    //     self.children_start += @intCast(siblings.len);
    //     _ = self.hookups_raw.insert_zig_slice(real_idx, alloc, siblings);
    //     return real_idx - intcast(self.siblings_start, u16);
    // }

    // pub fn delete_sibling(self: *Metadata, idx: u16) void {
    //     const real_idx = intcast(self.siblings_start, u16) + idx;
    //     self.assert_can_delete_siblings(1, @src());
    //     self.children_start -= @intCast(1);
    //     _ = self.hookups_raw.delte(real_idx);
    // }

    // pub fn delete_siblings(self: *Metadata, idx: u16, count: u16) void {
    //     const real_idx = intcast(self.siblings_start, u16) + idx;
    //     self.assert_can_delete_siblings(count, @src());
    //     self.children_start -= @intCast(count);
    //     _ = self.hookups_raw.delte_range(.from_idx_count(@intCast(real_idx), @intCast(count)));
    // }

    pub fn append_parent(self: *Metadata, parent: ParamId, alloc: Allocator) void {
        const real_idx = intcast(self.siblings_start, u16);
        self.assert_can_add_parents_or_siblings(1, @src());
        self.children_start += 1;
        self.siblings_start += 1;
        _ = self.hookups_raw.insert(real_idx, parent.id, alloc);
        // return real_idx;
    }

    pub fn append_parents(self: *Metadata, parents: []const ParamId, alloc: Allocator) void {
        const real_idx = intcast(self.siblings_start, u16);
        self.assert_can_add_parents_or_siblings(@intCast(parents.len), @src());
        self.children_start += @intCast(parents.len);
        self.siblings_start += @intCast(parents.len);
        _ = self.hookups_raw.insert_zig_slice(real_idx, alloc, parents);
        // return real_idx;
    }

    // pub fn insert_parent(self: *Metadata, idx: u16, parent: ParamId, alloc: Allocator) void {
    //     self.assert_can_add_parents_or_siblings(1, @src());
    //     self.children_start += 1;
    //     self.siblings_start += 1;
    //     _ = self.hookups_raw.insert(@intCast(idx), parent.id, alloc);
    // }

    // pub fn insert_parents(self: *Metadata, idx: u16, parents: []const ParamId, alloc: Allocator) void {
    //     self.assert_can_add_parents_or_siblings(@intCast(parents.len), @src());
    //     self.children_start += @intCast(parents.len);
    //     self.siblings_start += @intCast(parents.len);
    //     _ = self.hookups_raw.insert_zig_slice(@intCast(idx), alloc, parents);
    // }

    // pub fn delete_parent(self: *Metadata, idx: u16) void {
    //     self.assert_can_delete_parents(1, @src());
    //     self.children_start -= @intCast(1);
    //     self.siblings_start -= @intCast(1);
    //     _ = self.hookups_raw.delete(@intCast(idx));
    // }

    // pub fn delete_parents(self: *Metadata, idx: u16, count: u16) void {
    //     self.assert_can_delete_parents(count, @src());
    //     self.children_start -= @intCast(count);
    //     self.siblings_start -= @intCast(count);
    //     _ = self.hookups_raw.delte_range(.from_idx_count(@intCast(idx), @intCast(count)));
    // }
};

pub const CalcID = struct {
    id: u16 = 0,
};

pub const ParamId = struct {
    id: u16 = 0,

    pub const NULL = ParamId{ .id = math.maxInt(u16) };
    pub inline fn new_null() ParamId {
        return NULL;
    }
};

pub const @"u16" = struct {
    idx: u16 = 0,
};

pub const ParamType = enum(u8) {
    INVALID,
    COLOR,
    // U128,
    // X96,
    U64,
    I64,
    F64,
    PTR,
    PTR_OR_NULL,
    LIST,
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
        "COLOR",
        // "U128",
        // "X96",
        "U64",
        "I64",
        "F64",
        "PTR",
        "PTR_OR_NULL",
        "LIST",
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

pub const Hookups = struct {
    calc: ?*const Root.ParamTable.Calc.ParamCalc,
    parents: []ParamId,
    siblings: []ParamId,
    children: []ParamId,
};
