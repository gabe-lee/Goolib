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
const Flags = Root.Flags;
const IList = Root.IList.IList;
const List = Root.IList_List.List;
const Range = Root.IList.Range;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

const IList8 = IList(u8);
const IList16 = IList(u16);
const IList32 = IList(u32);
const IList64 = IList(u64);
const IListPtr = IList(*anyopaque);
const List8 = List(u8);
const List16 = List(u16);
const List32 = List(u32);
const List64 = List(u64);
const ListPtr = List(*anyopaque);

pub const Meta = @import("./ParamTable_Meta.zig");
pub const Calc = @import("./ParamTable_Calc.zig");
pub const _PTList = @import("./ParamTable_List.zig");
const PTListOpaque = _PTList.PTListOpaque;
const PTList = _PTList.PTList;
const PTPtr = _PTList.PTPtr;

const ListPTList = List(PTListOpaque);

const ListCalcs = List(*const Calc.ParamCalc);
const ListMeta = List(Meta.Metadata);

const RingList = Root.IList.RingList;
const UpdateList = RingList(Meta.ParamId);

const ParamId = Meta.ParamId;
const ParamType = Meta.ParamType;
const Metadata = Meta.Metadata;

const e_init = enum(u8) {
    must_be_init,
    can_be_uninit,
};

const e_derived = enum(u8) {
    cannot_be_derived,
    can_be_derived,
};

const e_root = enum(u8) {
    cannot_be_root,
    can_be_root,
};

pub const Table = struct {
    alloc: Allocator,
    list_8: List8,
    list_16: List16,
    list_32: List32,
    list_64: List64,
    list_ptr: ListPtr,
    list_list: ListPTList,
    calcs: ListCalcs,
    metadata: ListMeta,
    update_list: UpdateList,

    pub fn get_meta_with_check(self: *Table, id: ParamId, valid_type: ParamType, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) Meta.Metadata {
        assert_with_reason(id.id < self.metadata.len, @src(), "id {d} is outside bounds of metadata list (len = {d})", .{ id.id, self.metadata.len });
        const meta = self.metadata.get(@intCast(id.id));
        assert_with_reason(must_be_init != .must_be_init or meta.is_used(), @src(), "id {d} is a free metadata index (previously used, but deleted)", .{id.id});
        assert_with_reason(meta.is_type(valid_type), @src(), "id {d} is not a {s} value (found {s} value)", .{ id.id, valid_type.name(), meta.param_type.name() });
        assert_with_reason(cannot_be_derived != .cannot_be_derived or (meta.no_parent() and meta.no_calc()), @src(), "id {d} is a derived value (has parents and/or calculation func), expected root value", .{id.id});
        assert_with_reason(cannot_be_root != .cannot_be_root or (meta.has_parent() or meta.has_calc()), @src(), "id {d} is a root value (has NO parents and/or calculation func), expected derived value", .{id.id});
        return meta;
    }

    pub fn get_u8(self: *Table, id: ParamId) u8 {
        const meta = self.get_meta_with_check(id, .U8, .must_be_init, .can_be_derived, .can_be_root);
        return self.list_8.get(@intCast(meta.val_idx.idx));
    }
    pub fn get_i8(self: *Table, id: ParamId) i8 {
        const meta = self.get_meta_with_check(id, .I8, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_8.get(@intCast(meta.val_idx.idx)));
    }
    pub fn get_bool(self: *Table, id: ParamId) bool {
        const meta = self.get_meta_with_check(id, .BOOL, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_8.get(@intCast(meta.val_idx.idx)));
    }
    pub fn get_u16(self: *Table, id: ParamId) u16 {
        const meta = self.get_meta_with_check(id, .U16, .must_be_init, .can_be_derived, .can_be_root);
        return self.list_16.get(@intCast(meta.val_idx.idx));
    }
    pub fn get_i16(self: *Table, id: ParamId) i16 {
        const meta = self.get_meta_with_check(id, .I16, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_16.get(@intCast(meta.val_idx.idx)));
    }
    pub fn get_f16(self: *Table, id: ParamId) f16 {
        const meta = self.get_meta_with_check(id, .F16, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_16.get(@intCast(meta.val_idx.idx)));
    }
    pub fn get_u32(self: *Table, id: ParamId) u32 {
        const meta = self.get_meta_with_check(id, .U32, .must_be_init, .can_be_derived, .can_be_root);
        return self.list_32.get(@intCast(meta.val_idx.idx));
    }
    pub fn get_i32(self: *Table, id: ParamId) i32 {
        const meta = self.get_meta_with_check(id, .I32, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_32.get(@intCast(meta.val_idx.idx)));
    }
    pub fn get_f32(self: *Table, id: ParamId) f32 {
        const meta = self.get_meta_with_check(id, .F32, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_32.get(@intCast(meta.val_idx.idx)));
    }
    pub fn get_u64(self: *Table, id: ParamId) u64 {
        const meta = self.get_meta_with_check(id, .U64, .must_be_init, .can_be_derived, .can_be_root);
        return self.list_64.get(@intCast(meta.val_idx.idx));
    }
    pub fn get_i64(self: *Table, id: ParamId) i64 {
        const meta = self.get_meta_with_check(id, .I64, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_64.get(@intCast(meta.val_idx.idx)));
    }
    pub fn get_f64(self: *Table, id: ParamId) f64 {
        const meta = self.get_meta_with_check(id, .F64, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_64.get(@intCast(meta.val_idx.idx)));
    }
    pub fn get_ptr(self: *Table, id: ParamId, comptime T: type) PTPtr(T) {
        const meta = self.get_meta_with_check(id, .PTR, .must_be_init, .can_be_derived, .can_be_root);
        const opq = self.list_ptr.get(@intCast(meta.val_idx.idx));
        return PTPtr(T).from_opaque(opq);
    }
    pub fn get_list(self: *Table, id: ParamId, comptime T: type) PTList(T) {
        const meta = self.get_meta_with_check(id, .PTR, .must_be_init, .can_be_derived, .can_be_root);
        const opq = self.list_list.get(@intCast(meta.val_idx.idx));
        return PTList(T).from_opaque(opq);
    }

    pub fn queue_children(self: *Table, meta: Metadata) void {
        const children = meta.get_children();
        self.update_list.append_zig_slice(self.alloc, children);
    }

    fn begin_update(self: *Table) void {
        self.update_list.clear();
    }

    fn finish_update(self: *Table) void {
        var has_next = self.update_list.len > 0;
        var next_id: ParamId = undefined;
        var meta: Metadata = undefined;
        while (has_next) {
            next_id = self.update_list.remove(0);
            meta = self.metadata.get(@intCast(next_id.id));
            self.do_update(meta);
            has_next = self.update_list.len > 0;
        }
    }

    fn do_update(self: *Table, meta: Metadata) void {
        const hooks = meta.get_hookups(self);
        const iface = Calc.CalcInterface{
            .table = self,
            .inputs = hooks.parents,
            .outputs = hooks.siblings,
        };
        assert_with_reason(hooks.calc != null, @src(), "a child parameter added to the update queue (ValueIdx = {d}, type = {s}) had no calculation function atatched to it", .{ meta.val_idx.idx, meta.param_type.name() });
        hooks.calc.?(&iface);
    }

    pub fn set_root_u8(self: *Table, id: ParamId, val: u8) void {
        self.begin_update();
        Internal._set_u8(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_i8(self: *Table, id: ParamId, val: i8) void {
        self.begin_update();
        Internal._set_i8(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_bool(self: *Table, id: ParamId, val: bool) void {
        self.begin_update();
        Internal._set_bool(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_u16(self: *Table, id: ParamId, val: u16) void {
        self.begin_update();
        Internal._set_u16(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_i16(self: *Table, id: ParamId, val: i16) void {
        self.begin_update();
        Internal._set_i16(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_f16(self: *Table, id: ParamId, val: f16) void {
        self.begin_update();
        Internal._set_f16(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_u32(self: *Table, id: ParamId, val: u32) void {
        self.begin_update();
        Internal._set_u32(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_i32(self: *Table, id: ParamId, val: i32) void {
        self.begin_update();
        Internal._set_i32(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_f32(self: *Table, id: ParamId, val: f32) void {
        self.begin_update();
        Internal._set_f32(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_u64(self: *Table, id: ParamId, val: u64) void {
        self.begin_update();
        Internal._set_u64(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_i64(self: *Table, id: ParamId, val: i64) void {
        self.begin_update();
        Internal._set_i64(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_f64(self: *Table, id: ParamId, val: f64) void {
        self.begin_update();
        Internal._set_f64(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_ptr(self: *Table, id: ParamId, comptime T: type, val: PTPtr(T)) void {
        self.begin_update();
        Internal._set_ptr(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_list(self: *Table, id: ParamId, comptime T: type, val: PTList(T)) void {
        self.begin_update();
        Internal._set_list(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    fn new_metadata_root(self: *Table, val_idx: u16, set_type: Meta.ParamType, always_update: bool) ParamId {
        var meta = Metadata{
            .hookups_raw = List16.init_empty(),
            .calc_id = Meta.CalcID{ .id = math.maxInt(u16) },
            .children_start = 0,
            .siblings_start = 0,
            .val_idx = val_idx,
            .param_type = set_type,
            .flags = Meta.PFlags.blank(),
        };
        if (always_update) meta.set_always_update();
        meta.set_used();
        const id: u16 = @intCast(self.metadata.append(meta, self.alloc));
        return ParamId{ .id = id };
    }

    const MetaAndId = struct {
        meta: Metadata,
        id: ParamId,
    };

    fn new_metadata_derived_single(self: *Table, val_idx: u16, set_type: Meta.ParamType, always_update: bool, calc_id: Meta.CalcID, parents: []const ParamId) MetaAndId {
        var meta = Metadata{
            .hookups_raw = List16.init_empty(),
            .calc_id = calc_id,
            .children_start = 0,
            .siblings_start = 0,
            .val_idx = val_idx,
            .param_type = set_type,
            .flags = Meta.PFlags.blank(),
        };
        if (always_update) meta.set_always_update();
        meta.set_used();
        meta.set_has_calc();
        meta.set_has_parent();
        meta.set_has_siblings();
        meta.append_parents(parents, self.alloc);
        const id: u16 = @intCast(self.metadata.append(meta, self.alloc));
        const pid = ParamId{ .id = id };
        for (parents) |p| {
            const pmeta = self.metadata.get(@intCast(p.id));
            pmeta.append_child(pid, self.alloc);
            self.metadata.set(@intCast(p.id), pmeta);
        }
        meta.append_sibling(pid, self.alloc);
        self.metadata.set(@intCast(pid.id), meta);
        return MetaAndId{
            .meta = meta,
            .id = pid,
        };
    }

    fn new_metadata_derived_linked_uninit(self: *Table, val_idx: u16, set_type: Meta.ParamType, always_update: bool, calc_id: Meta.CalcID, parents: []const ParamId) ParamId {
        var meta = Metadata{
            .hookups_raw = List16.init_empty(),
            .calc_id = calc_id,
            .children_start = 0,
            .siblings_start = 0,
            .val_idx = val_idx,
            .param_type = set_type,
            .flags = Meta.PFlags.blank(),
        };
        if (always_update) meta.set_always_update();
        meta.set_used();
        meta.set_has_calc();
        meta.set_has_parent();
        meta.set_has_siblings();
        meta.append_parents(parents, self.alloc);
        const id: u16 = @intCast(self.metadata.append(meta, self.alloc));
        return ParamId{ .id = id };
    }

    pub const UpdateMode = enum(u8) {
        always_update,
        only_update_when_value_changes,
    };

    pub fn init_root_u8(self: *Table, val: u8, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_u8(self, val);
        const id = self.new_metadata_root(val_idx, .U8, always_update == .always_update);
        return id;
    }
    pub fn init_root_i8(self: *Table, val: i8, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_i8(self, val);
        const id = self.new_metadata_root(val_idx, .I8, always_update == .always_update);
        return id;
    }
    pub fn init_root_bool(self: *Table, val: bool, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_bool(self, val);
        const id = self.new_metadata_root(val_idx, .BOOL, always_update == .always_update);
        return id;
    }
    pub fn init_root_u16(self: *Table, val: u16, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_u16(self, val);
        const id = self.new_metadata_root(val_idx, .U16, always_update == .always_update);
        return id;
    }
    pub fn init_root_i16(self: *Table, val: i16, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_i16(self, val);
        const id = self.new_metadata_root(val_idx, .I16, always_update == .always_update);
        return id;
    }
    pub fn init_root_f16(self: *Table, val: f16, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_f16(self, val);
        const id = self.new_metadata_root(val_idx, .F16, always_update == .always_update);
        return id;
    }
    pub fn init_root_u32(self: *Table, val: u32, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_u32(self, val);
        const id = self.new_metadata_root(val_idx, .U32, always_update == .always_update);
        return id;
    }
    pub fn init_root_i32(self: *Table, val: i32, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_i32(self, val);
        const id = self.new_metadata_root(val_idx, .I32, always_update == .always_update);
        return id;
    }
    pub fn init_root_f32(self: *Table, val: f32, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_f32(self, val);
        const id = self.new_metadata_root(val_idx, .F32, always_update == .always_update);
        return id;
    }
    pub fn init_root_u64(self: *Table, val: u64, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_u64(self, val);
        const id = self.new_metadata_root(val_idx, .U64, always_update == .always_update);
        return id;
    }
    pub fn init_root_i64(self: *Table, val: i64, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_i64(self, val);
        const id = self.new_metadata_root(val_idx, .I64, always_update == .always_update);
        return id;
    }
    pub fn init_root_f64(self: *Table, val: f64, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_f64(self, val);
        const id = self.new_metadata_root(val_idx, .F64, always_update == .always_update);
        return id;
    }
    pub fn init_root_ptr(self: *Table, comptime T: type, val: PTPtr(T), always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_ptr(self, T, val);
        const id = self.new_metadata_root(val_idx, .PTR, always_update == .always_update);
        return id;
    }
    pub fn init_root_list(self: *Table, comptime T: type, val: PTList(T), always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_list(self, T, val);
        const id = self.new_metadata_root(val_idx, .LIST, always_update);
        return id;
    }

    pub fn register_calc(self: *Table, calc: *const Calc.ParamCalc) Meta.CalcID {
        const idx = self.calcs.append(calc, self.alloc);
        return Meta.CalcID{ .id = idx };
    }

    pub const TypeInit = struct {
        param_type: Meta.ParamType = .INVALID,
        update: UpdateMode = .only_update_when_value_changes,

        pub fn new(param_type: Meta.ParamType, update: UpdateMode) TypeInit {
            return TypeInit{
                .param_type = param_type,
                .update = update,
            };
        }
    };

    pub fn init_derived_u8(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_u8(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .U8, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_i8(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_i8(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .I8, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_bool(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_bool(self, false);
        const meta_id = self.new_metadata_derived_single(val_idx, .BOOL, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_u16(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_u16(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .U16, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_i16(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_i16(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .I16, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_f16(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_f16(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .F16, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_u32(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_u32(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .U32, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_i32(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_i32(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .I32, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_f32(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_f32(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .F32, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_u64(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_u64(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .U64, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_i64(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_i64(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .I64, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_f64(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_f64(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .F64, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_ptr(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_ptr(self, PTPtr(u8).from_opaque(@ptrFromInt(math.maxInt(usize))));
        const meta_id = self.new_metadata_derived_single(val_idx, .PTR, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_list(self: *Table, always_update: bool, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_list(self, PTList(u8).from_opaque(PTListOpaque{}));
        const meta_id = self.new_metadata_derived_single(val_idx, .LIST, always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }

    pub fn init_derived_linked(self: *Table, calc_idx: Meta.CalcID, inputs: []const Meta.ParamId, output_types: []const TypeInit) List16 {
        var output_ids = List16.init_capacity(output_types.len, self.alloc);
        for (output_types, 0..) |out, i| {
            const val_idx: u16 = switch (out.param_type) {
                .U8, .I8, .BOOL => Internal._new_val_u8(self, 0),
                .U16, .I16, .F16 => Internal._new_val_u16(self, 0),
                .U32, .I32, .F32 => Internal._new_val_u32(self, 0),
                .U64, .I64, .F64 => Internal._new_val_u64(self, 0),
                .PTR => Internal._new_val_ptr(self, PTPtr(u8).from_opaque(@ptrFromInt(math.maxInt(usize)))),
                .LIST => Internal._new_val_list(self, PTList(u8).from_opaque(PTListOpaque{})),
                .INVALID => assert_unreachable(@src(), "output value at idx {d} had invalid ParamType `INVALID`", .{i}),
            };
            const id = self.new_metadata_derived_linked_uninit(val_idx, out.param_type, out.update == .always_update, calc_idx, inputs);
            output_ids.append(id, self.alloc);
        }
        for (inputs) |p| {
            var pmeta = self.metadata.get(@intCast(p.id));
            pmeta.append_children(output_ids.slice(), self.alloc);
            self.metadata.set(@intCast(p.id), pmeta);
        }
        for (output_ids.slice(), 0..) |id, i| {
            var meta = self.metadata.get(@intCast(id.id));
            meta.append_siblings(output_ids.slice(), self.alloc);
            self.metadata.set(@intCast(id.id), meta);
        }
        const iface = Calc.CalcInterface{
            .table = self,
            .inputs = inputs,
            .outputs = output_ids.slice(),
        };
        const calc = self.calcs.get(@intCast(calc_idx.id));
        calc(&iface);
        return output_ids;
    }

    pub const Internal = struct {
        pub fn _new_val_u8(self: *Table, val: u8) u16 {
            return @intCast(self.list_8.append(val, self.alloc));
        }
        pub fn _new_val_i8(self: *Table, val: i8) u16 {
            return @intCast(self.list_8.append(@bitCast(val), self.alloc));
        }
        pub fn _new_val_bool(self: *Table, val: bool) u16 {
            return @intCast(self.list_8.append(@bitCast(val), self.alloc));
        }
        pub fn _new_val_u16(self: *Table, val: u16) u16 {
            return @intCast(self.list_16.append(val, self.alloc));
        }
        pub fn _new_val_i16(self: *Table, val: i16) u16 {
            return @intCast(self.list_16.append(@bitCast(val), self.alloc));
        }
        pub fn _new_val_f16(self: *Table, val: f16) u16 {
            return @intCast(self.list_16.append(@bitCast(val), self.alloc));
        }
        pub fn _new_val_u32(self: *Table, val: u32) u16 {
            return @intCast(self.list_32.append(val, self.alloc));
        }
        pub fn _new_val_i32(self: *Table, val: i32) u16 {
            return @intCast(self.list_32.append(@bitCast(val), self.alloc));
        }
        pub fn _new_val_f32(self: *Table, val: f32) u16 {
            return @intCast(self.list_32.append(@bitCast(val), self.alloc));
        }
        pub fn _new_val_u64(self: *Table, val: u64) u16 {
            return @intCast(self.list_64.append(val, self.alloc));
        }
        pub fn _new_val_i64(self: *Table, val: i64) u16 {
            return @intCast(self.list_64.append(@bitCast(val), self.alloc));
        }
        pub fn _new_val_f64(self: *Table, val: f64) u16 {
            return @intCast(self.list_64.append(@bitCast(val), self.alloc));
        }
        pub fn _new_val_ptr(self: *Table, comptime T: type, val: PTPtr(T)) u16 {
            return @intCast(self.list_ptr.append(val.to_opaque(), self.alloc));
        }
        pub fn _new_val_list(self: *Table, comptime T: type, val: PTList(T)) u16 {
            return @intCast(self.list_list.append(val.to_opaque(), self.alloc));
        }
        pub fn _set_u8(self: *Table, id: ParamId, val: u8, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .U8, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_8.set_report_change(@intCast(meta.val_idx), val);
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_i8(self: *Table, id: ParamId, val: i8, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .I8, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_8.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_bool(self: *Table, id: ParamId, val: bool, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .BOOL, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_8.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_u16(self: *Table, id: ParamId, val: u16, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .U16, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_16.set_report_change(@intCast(meta.val_idx), val);
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_i16(self: *Table, id: ParamId, val: i16, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .I16, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_16.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_f16(self: *Table, id: ParamId, val: f16, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .F16, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_16.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_u32(self: *Table, id: ParamId, val: u32, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .U32, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_32.set_report_change(@intCast(meta.val_idx), val);
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_i32(self: *Table, id: ParamId, val: i32, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .I32, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_32.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_f32(self: *Table, id: ParamId, val: f32, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .F32, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_32.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_u64(self: *Table, id: ParamId, val: u64, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .U64, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_64.set_report_change(@intCast(meta.val_idx), val);
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_i64(self: *Table, id: ParamId, val: i64, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .I64, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_64.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_f64(self: *Table, id: ParamId, val: f64, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .F64, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_64.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_ptr(self: *Table, id: ParamId, comptime T: type, val: PTPtr(T), comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .PTR, must_be_init, cannot_be_derived, cannot_be_root);
            self.list_ptr.set(@intCast(meta.val_idx), val.to_opaque());
            if (val.val_changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_list(self: *Table, id: ParamId, comptime T: type, val: PTList(T), comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id.id, .LIST, must_be_init, cannot_be_derived, cannot_be_root);
            self.list_ptr.set(@intCast(meta.val_idx), val.to_opaque());
            if (val.vals_changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
    };
};
