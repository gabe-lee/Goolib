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
const assert_field_is_type = Assert.assert_field_is_type;

const List8 = List(u8);
const List16 = List(u16);
const List32 = List(u32);
const List64 = List(u64);
const List96 = List(U96);
const List128 = List(u128);
const ListPtr = List(?*anyopaque);

pub const ParamSource = enum(u8) {
    omit,
    root,
    derived_single,
    derived_linked,
    existing,
};

pub fn ParamFactorySlot(comptime N: comptime_int, comptime T: type) type {
    return union(ParamSource) {
        const Self = @This();

        omit: struct {},
        root: *const Table.InitRootFn(T),
        derived_single: *const Table.InitDerivedFunc,
        derived_linked: struct {
            func: *const Table.InitLinkedDerivedFunc(N),
            object: type,
        },
        existing: ParamId,

        pub fn just_omit() Self {
            return Self{ .omit = .{} };
        }
        pub fn new_root(func: *const Table.InitRootFn(T)) Self {
            return Self{ .root = func };
        }
        pub fn new_derived_single(func: *const Table.InitDerivedFunc) Self {
            return Self{ .derived_single = func };
        }
        pub fn new_derived_linked(func: *const Table.InitLinkedDerivedFunc(N), comptime object: type) Self {
            return Self{ .derived_linked = .{
                .func = func,
                .object = object,
            } };
        }
        pub fn use_existing(id: ParamId) Self {
            return Self{ .existing = id };
        }
    };
}

const U96 = struct {
    a: u32 = 0,
    b: u32 = 0,
    c: u32 = 0,
};

const Color32 = Root.Color.define_color_rgba_type(u32);

pub const Meta = @import("./ParamTable_Meta.zig");
const ListParamId = List(Meta.ParamId);
pub const Calc = @import("./ParamTable_Calc.zig");
pub const _PTList = @import("./ParamTable_List.zig");
const PTListOpaque = _PTList.PTListOpaque;
pub const PTList = _PTList.PTList;
pub const PTPtr = _PTList.PTPtr;
pub const PTPtrOrNull = _PTList.PTPtrOrNull;

const ListPTList = List(PTListOpaque);

const ListCalcs = List(*const Calc.ParamCalc);
const ListMeta = List(Meta.Metadata);

const RingList = Root.IList.RingList;
// const UpdateList = RingList(Meta.ParamId);
const UpdateList = List(Meta.ParamId);

const ParamId = Meta.ParamId;
const ParamType = Meta.ParamType;
const Metadata = Meta.Metadata;

const intcast = Types.intcast;

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
    update_idx: u32 = 0,
    prevent_duplicate_updates: bool = true,

    pub fn init(param_cap: u16, alloc: Allocator) Table {
        return Table{
            .alloc = alloc,
            .list_8 = List8.init_empty(),
            .list_16 = List16.init_empty(),
            .list_32 = List32.init_empty(),
            .list_64 = List64.init_empty(),
            .list_ptr = ListPtr.init_empty(),
            .list_list = ListPTList.init_empty(),
            .calcs = ListCalcs.init_capacity(8, alloc),
            .metadata = ListMeta.init_capacity(@intCast(param_cap), alloc),
            .update_list = UpdateList.init_capacity(8, alloc),
        };
    }

    pub fn deinit(self: *Table) void {
        self.list_8.free(self.alloc);
        self.list_16.free(self.alloc);
        self.list_32.free(self.alloc);
        self.list_64.free(self.alloc);
        self.list_ptr.free(self.alloc);
        self.list_list.free(self.alloc);
        self.calcs.free(self.alloc);
        for (self.metadata.slice()) |m| {
            m.hookups_raw.free(self.alloc);
        }
        self.metadata.free(self.alloc);
        self.update_list.free(self.alloc);
    }

    pub fn total_memory_footprint(self: *Table) usize {
        var size: usize = @sizeOf(Table);
        size += intcast(self.metadata.cap, usize) * @sizeOf(Metadata);
        size += intcast(self.list_8.cap, usize);
        size += intcast(self.list_16.cap, usize) * 2;
        size += intcast(self.list_32.cap, usize) * 4;
        size += intcast(self.list_64.cap, usize) * 8;
        size += intcast(self.list_ptr.cap, usize) * @sizeOf(*anyopaque);
        size += intcast(self.list_list.cap, usize) * @sizeOf(PTListOpaque);
        size += intcast(self.calcs.cap, usize) * @sizeOf(*const Calc.ParamCalc);
        size += intcast(self.update_list.cap, usize) * 2;
        for (self.metadata.slice()) |m| {
            size += intcast(m.hookups_raw.cap, usize) * 2;
        }
        return size;
    }

    fn get_meta_with_check(self: *Table, id: ParamId, valid_type: ParamType, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) Meta.Metadata {
        assert_with_reason(id.id < self.metadata.len, @src(), "id {d} is outside bounds of metadata list (len = {d})", .{ id.id, self.metadata.len });
        const meta = self.metadata.get(@intCast(id.id));
        assert_with_reason(must_be_init != .must_be_init or meta.is_used(), @src(), "id {d} is a free metadata index (previously used, but deleted)", .{id.id});
        assert_with_reason(meta.is_type(valid_type), @src(), "id {d} is not a {s} value (found {s} value)", .{ id.id, valid_type.name(), meta.param_type.name() });
        assert_with_reason(cannot_be_derived != .cannot_be_derived or (meta.no_parent() and meta.no_calc()), @src(), "id {d} is a derived value (has parents and/or calculation func), expected root value", .{id.id});
        assert_with_reason(cannot_be_root != .cannot_be_root or (meta.has_parent() or meta.has_calc()), @src(), "id {d} is a root value (has NO parents and/or calculation func), expected derived value", .{id.id});
        return meta;
    }
    fn check_meta(id: ParamId, meta: Metadata, valid_type: ParamType, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
        assert_with_reason(must_be_init != .must_be_init or meta.is_used(), @src(), "id {d} is a free metadata index (previously used, but deleted)", .{id.id});
        assert_with_reason(meta.is_type(valid_type), @src(), "id {d} is not a {s} value (found {s} value)", .{ id.id, valid_type.name(), meta.param_type.name() });
        assert_with_reason(cannot_be_derived != .cannot_be_derived or (meta.no_parent() and meta.no_calc()), @src(), "id {d} is a derived value (has parents and/or calculation func), expected root value", .{id.id});
        assert_with_reason(cannot_be_root != .cannot_be_root or (meta.has_parent() or meta.has_calc()), @src(), "id {d} is a root value (has NO parents and/or calculation func), expected derived value", .{id.id});
    }
    fn check_meta_state_only(id: ParamId, meta: Metadata, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
        assert_with_reason(must_be_init != .must_be_init or meta.is_used(), @src(), "id {d} is a free metadata index (previously used, but deleted)", .{id.id});
        assert_with_reason(cannot_be_derived != .cannot_be_derived or (meta.no_parent() and meta.no_calc()), @src(), "id {d} is a derived value (has parents and/or calculation func), expected root value", .{id.id});
        assert_with_reason(cannot_be_root != .cannot_be_root or (meta.has_parent() or meta.has_calc()), @src(), "id {d} is a root value (has NO parents and/or calculation func), expected derived value", .{id.id});
    }

    pub fn get_u8(self: *Table, id: ParamId) u8 {
        const meta = self.get_meta_with_check(id, .U8, .must_be_init, .can_be_derived, .can_be_root);
        return self.list_8.get(@intCast(meta.val_idx));
    }
    pub fn get_i8(self: *Table, id: ParamId) i8 {
        const meta = self.get_meta_with_check(id, .I8, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_8.get(@intCast(meta.val_idx)));
    }
    pub fn get_bool(self: *Table, id: ParamId) bool {
        const meta = self.get_meta_with_check(id, .BOOL, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_8.get(@intCast(meta.val_idx)));
    }
    pub fn get_u16(self: *Table, id: ParamId) u16 {
        const meta = self.get_meta_with_check(id, .U16, .must_be_init, .can_be_derived, .can_be_root);
        return self.list_16.get(@intCast(meta.val_idx));
    }
    pub fn get_i16(self: *Table, id: ParamId) i16 {
        const meta = self.get_meta_with_check(id, .I16, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_16.get(@intCast(meta.val_idx)));
    }
    pub fn get_f16(self: *Table, id: ParamId) f16 {
        const meta = self.get_meta_with_check(id, .F16, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_16.get(@intCast(meta.val_idx)));
    }
    pub fn get_u32(self: *Table, id: ParamId) u32 {
        const meta = self.get_meta_with_check(id, .U32, .must_be_init, .can_be_derived, .can_be_root);
        return self.list_32.get(@intCast(meta.val_idx));
    }
    pub fn get_i32(self: *Table, id: ParamId) i32 {
        const meta = self.get_meta_with_check(id, .I32, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_32.get(@intCast(meta.val_idx)));
    }
    pub fn get_f32(self: *Table, id: ParamId) f32 {
        const meta = self.get_meta_with_check(id, .F32, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_32.get(@intCast(meta.val_idx)));
    }
    pub fn get_u64(self: *Table, id: ParamId) u64 {
        const meta = self.get_meta_with_check(id, .U64, .must_be_init, .can_be_derived, .can_be_root);
        return self.list_64.get(@intCast(meta.val_idx));
    }
    pub fn get_i64(self: *Table, id: ParamId) i64 {
        const meta = self.get_meta_with_check(id, .I64, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_64.get(@intCast(meta.val_idx)));
    }
    pub fn get_f64(self: *Table, id: ParamId) f64 {
        const meta = self.get_meta_with_check(id, .F64, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_64.get(@intCast(meta.val_idx)));
    }
    pub fn get_ptr(self: *Table, id: ParamId, comptime T: type) PTPtr(T) {
        const meta = self.get_meta_with_check(id, .PTR, .must_be_init, .can_be_derived, .can_be_root);
        const opq = self.list_ptr.get(@intCast(meta.val_idx));
        return PTPtr(T).from_opaque(opq);
    }
    pub fn get_list(self: *Table, id: ParamId, comptime T: type) PTList(T) {
        const meta = self.get_meta_with_check(id, .PTR, .must_be_init, .can_be_derived, .can_be_root);
        const opq = self.list_list.get(@intCast(meta.val_idx));
        return PTList(T).from_opaque(opq);
    }
    pub fn get_color(self: *Table, id: ParamId) Color32 {
        const meta = self.get_meta_with_check(id, .COLOR, .must_be_init, .can_be_derived, .can_be_root);
        return @bitCast(self.list_32.get(@intCast(meta.val_idx)));
    }

    fn queue_children(self: *Table, meta: Metadata) void {
        const children = meta.get_children();
        if (self.prevent_duplicate_updates) {
            for (children) |new_update| {
                var was_already_queued: bool = false;
                for (self.update_list.ptr[self.update_idx..self.update_list.len]) |already_queued| {
                    if (already_queued.id == new_update.id) {
                        was_already_queued = true;
                        break;
                    }
                }
                if (!was_already_queued) {
                    _ = self.update_list.append(new_update, self.alloc);
                }
            }
        } else {
            _ = self.update_list.append_zig_slice(self.alloc, children);
        }
    }

    fn begin_update(self: *Table) void {
        self.update_list.clear();
        self.update_idx = 0;
    }

    fn finish_update(self: *Table) void {
        var next_id: ParamId = undefined;
        var meta: Metadata = undefined;
        while (self.update_idx < self.update_list.len) {
            next_id = self.update_list.ptr[self.update_idx];
            meta = self.metadata.ptr[@intCast(next_id.id)];
            self.do_update(next_id, meta);
            self.update_idx += 1;
        }
    }

    fn do_update(self: *Table, id: ParamId, meta: Metadata) void {
        const hooks = meta.get_hookups(self);
        const iface = Calc.CalcInterface{
            .table = self,
            .inputs = hooks.parents,
            .outputs = hooks.siblings,
        };
        assert_with_reason(hooks.calc != null, @src(), "a child parameter added to the update queue (ParamId = {d}, ValueIdx = {d}, type = {s}) had no calculation function atatched to it", .{ id.id, meta.val_idx, meta.param_type.name() });
        hooks.calc.?(iface);
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

    pub fn set_root_ptr_or_null(self: *Table, id: ParamId, comptime T: type, val: PTPtr(T)) void {
        self.begin_update();
        Internal._set_ptr(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_list(self: *Table, id: ParamId, comptime T: type, val: PTList(T)) void {
        self.begin_update();
        Internal._set_list(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    pub fn set_root_color(self: *Table, id: ParamId, val: Color32) void {
        self.begin_update();
        Internal._set_color(self, id, val, .must_be_init, .cannot_be_derived, .can_be_root);
        self.finish_update();
    }

    fn new_metadata_root(self: *Table, val_idx: u16, set_type: Meta.ParamType, always_update: bool) ParamId {
        var meta = Metadata{
            .hookups_raw = ListParamId.init_empty(),
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
            .hookups_raw = ListParamId.init_empty(),
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
        _ = meta.append_parents(parents, self.alloc);
        const id: u16 = @intCast(self.metadata.append(meta, self.alloc));
        const pid = ParamId{ .id = id };
        for (parents) |p| {
            var pmeta = self.metadata.get(@intCast(p.id));
            _ = pmeta.append_child(pid, self.alloc);
            self.metadata.set(@intCast(p.id), pmeta);
        }
        _ = meta.append_sibling(pid, self.alloc);
        self.metadata.set(@intCast(pid.id), meta);
        return MetaAndId{
            .meta = meta,
            .id = pid,
        };
    }

    pub fn LinkedParamIdsObject(comptime LINKED_PARAM_OBJECT: type, comptime N: comptime_int, params: [N]ParamId) LINKED_PARAM_OBJECT {
        assert_with_reason(Types.type_is_struct_with_all_fields_same_type(LINKED_PARAM_OBJECT, ParamId), @src(), "type `LINKED_PARAM_OBJECT` MUST be a struct type with all fields of type `ParamId`, got type `{s}`", .{@typeName(LINKED_PARAM_OBJECT)});
        const INFO = @typeInfo(LINKED_PARAM_OBJECT).@"struct";
        assert_with_reason(INFO.fields.len == N, @src(), "type `LINKED_PARAM_OBJECT` must have EXACTLY the same number of fields as `N`, got {d} != {d}", .{ INFO.fields.len, N });
        var out: LINKED_PARAM_OBJECT = undefined;
        inline for (INFO.fields, 0..) |f, i| {
            const p = params[i];
            @field(out, f.name) = p;
        }
        return out;
    }

    fn new_metadata_derived_linked_uninit(self: *Table, val_idx: u16, set_type: Meta.ParamType, always_update: bool, calc_id: Meta.CalcID, parents: []const ParamId) ParamId {
        var meta = Metadata{
            .hookups_raw = ListParamId.init_empty(),
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
        _ = meta.append_parents(parents, self.alloc);
        const id: u16 = @intCast(self.metadata.append(meta, self.alloc));
        return ParamId{ .id = id };
    }

    pub const UpdateMode = enum(u8) {
        always_update,
        only_update_when_value_changes,
    };

    pub fn InitRootFn(comptime T: type) type {
        return fn (self: *Table, val: T, always_update: UpdateMode) ParamId;
    }

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
    pub fn init_root_color(self: *Table, val: Color32, always_update: UpdateMode) ParamId {
        const val_idx = Internal._new_val_color(self, val);
        const id = self.new_metadata_root(val_idx, .COLOR, always_update);
        return id;
    }

    pub fn register_calc(self: *Table, calc: *const Calc.ParamCalc) Meta.CalcID {
        const idx = self.calcs.append(calc, self.alloc);
        return Meta.CalcID{ .id = @intCast(idx) };
    }

    pub const LinkedInit = struct {
        param_type: Meta.ParamType = .INVALID,
        update: UpdateMode = .only_update_when_value_changes,

        pub fn new(param_type: Meta.ParamType, update: UpdateMode) LinkedInit {
            return LinkedInit{
                .param_type = param_type,
                .update = update,
            };
        }
        pub fn comptime_new(comptime param_type: Meta.ParamType, comptime update: UpdateMode) LinkedInit {
            return LinkedInit{
                .param_type = param_type,
                .update = update,
            };
        }
    };

    pub const InitDerivedFunc = fn (self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId;
    pub fn InitLinkedDerivedFunc(comptime N: comptime_int) type {
        return fn (self: *Table, calc_idx: Meta.CalcID, inputs: []const ParamId, comptime N: comptime_int, comptime output_types: [N]LinkedInit) [N]ParamId;
    }

    pub fn init_derived_u8(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_u8(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .U8, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_i8(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_i8(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .I8, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_bool(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_bool(self, false);
        const meta_id = self.new_metadata_derived_single(val_idx, .BOOL, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_u16(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_u16(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .U16, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_i16(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_i16(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .I16, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_f16(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_f16(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .F16, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_u32(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_u32(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .U32, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_i32(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_i32(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .I32, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_f32(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_f32(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .F32, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.id, meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_u64(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_u64(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .U64, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_i64(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_i64(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .I64, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_f64(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_f64(self, 0);
        const meta_id = self.new_metadata_derived_single(val_idx, .F64, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_ptr(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_ptr(self, PTPtr(u8).from_opaque(@ptrFromInt(math.maxInt(usize))));
        const meta_id = self.new_metadata_derived_single(val_idx, .PTR, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_list(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_list(self, PTList(u8).from_opaque(PTListOpaque{}));
        const meta_id = self.new_metadata_derived_single(val_idx, .LIST, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }
    pub fn init_derived_color(self: *Table, always_update: UpdateMode, calc_id: Meta.CalcID, inputs: []const ParamId) ParamId {
        const val_idx = Internal._new_val_color(self, Color32{});
        const meta_id = self.new_metadata_derived_single(val_idx, .COLOR, always_update == .always_update, calc_id, inputs);
        self.do_update(meta_id.meta);
        return meta_id.id;
    }

    pub fn init_derived_linked(self: *Table, calc_idx: Meta.CalcID, inputs: []const ParamId, comptime N: comptime_int, comptime output_types: [N]LinkedInit) [N]ParamId {
        var output_ids: [N]ParamId = undefined;
        for (output_types, 0..) |out, i| {
            const val_idx: u16 = switch (out.param_type) {
                .U8, .I8, .BOOL => Internal._new_val_u8(self, 0),
                .U16, .I16, .F16 => Internal._new_val_u16(self, 0),
                .U32, .I32, .F32, .COLOR => Internal._new_val_u32(self, 0),
                .U64, .I64, .F64 => Internal._new_val_u64(self, 0),
                .PTR => Internal._new_val_ptr(self, u8, PTPtr(u8).from_opaque(@ptrFromInt(math.maxInt(usize)))),
                .PTR_OR_NULL => Internal._new_val_ptr_or_null(self, u8, PTPtrOrNull(u8).from_opaque(@ptrFromInt(0))),
                .LIST => Internal._new_val_list(self, u8, PTList(u8).from_opaque(PTListOpaque{}, self)),
                .INVALID => assert_unreachable(@src(), "output value at idx {d} had invalid ParamType `INVALID`", .{i}),
            };
            const id = self.new_metadata_derived_linked_uninit(val_idx, out.param_type, out.update == .always_update, calc_idx, inputs);
            output_ids[i] = id;
        }
        for (inputs) |p| {
            var pmeta = self.metadata.get(@intCast(p.id));
            _ = pmeta.append_children(output_ids[0..], self.alloc);
            self.metadata.set(@intCast(p.id), pmeta);
        }
        for (output_ids[0..]) |id| {
            var meta = self.metadata.get(@intCast(id.id));
            _ = meta.append_siblings(output_ids[0..], self.alloc);
            self.metadata.set(@intCast(id.id), meta);
        }
        const iface = Calc.CalcInterface{
            .table = self,
            .inputs = inputs,
            .outputs = output_ids[0..],
        };
        const calc = self.calcs.get(@intCast(calc_idx.id));
        calc(iface);
        return output_ids;
    }

    pub const Internal = struct {
        pub fn assert_meta_is_type(id: Meta.ParamId, meta: Meta.Metadata, comptime t: Meta.ParamType, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(meta.is_type(t), src, "param_id `{d}` was not a `{s}`, got `{s}`", .{ id.id, t.name(), meta.param_type.name() });
        }

        pub const ListOrPtr = enum(u8) {
            list,
            ptr,
            ptr_or_null,
        };

        pub fn assert_type_ptptr_or_ptlist_and_get_base_type(comptime T: type, comptime mode: ListOrPtr) type {
            assert_with_reason(Types.type_has_decl_with_type(T, "TYPE", type), @src(), "type was not a `PTPtr(T)` or `PTList(T)` type (missing `pub const TYPE = T;`), got type `{s}`", .{@typeName(T)});
            const TT = T.TYPE;
            switch (mode) {
                .list => {
                    const TTT = PTList(TT);
                    Assert.assert_is_type(T, TTT);
                    return TT;
                },
                .ptr => {
                    const TTT = PTPtr(TT);
                    Assert.assert_is_type(T, TTT);
                    return TT;
                },
                .ptr => {
                    const TTT = PTPtrOrNull(TT);
                    Assert.assert_is_type(T, TTT);
                    return TT;
                },
            }
        }

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
        pub fn _new_val_ptr_or_null(self: *Table, comptime T: type, val: PTPtrOrNull(T)) u16 {
            return @intCast(self.list_ptr.append(val.to_opaque(), self.alloc));
        }
        pub fn _new_val_list(self: *Table, comptime T: type, val: PTList(T)) u16 {
            return @intCast(self.list_list.append(val.to_opaque(), self.alloc));
        }
        pub fn _new_val_color(self: *Table, val: Color32) u16 {
            return @intCast(self.list_32.append(@bitCast(val), self.alloc));
        }
        pub fn _set_u8(self: *Table, id: ParamId, val: u8, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .U8, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_8.set_report_change(@intCast(meta.val_idx), val);
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_i8(self: *Table, id: ParamId, val: i8, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .I8, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_8.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_bool(self: *Table, id: ParamId, val: bool, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .BOOL, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_8.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_u16(self: *Table, id: ParamId, val: u16, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .U16, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_16.set_report_change(@intCast(meta.val_idx), val);
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_i16(self: *Table, id: ParamId, val: i16, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .I16, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_16.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_f16(self: *Table, id: ParamId, val: f16, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .F16, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_16.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_u32(self: *Table, id: ParamId, val: u32, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .U32, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_32.set_report_change(@intCast(meta.val_idx), val);
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_i32(self: *Table, id: ParamId, val: i32, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .I32, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_32.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_f32(self: *Table, id: ParamId, val: f32, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .F32, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_32.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_u64(self: *Table, id: ParamId, val: u64, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .U64, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_64.set_report_change(@intCast(meta.val_idx), val);
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_i64(self: *Table, id: ParamId, val: i64, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .I64, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_64.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_f64(self: *Table, id: ParamId, val: f64, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .F64, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_64.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_ptr(self: *Table, id: ParamId, comptime T: type, val: PTPtr(T), comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .PTR, must_be_init, cannot_be_derived, cannot_be_root);
            self.list_ptr.set(@intCast(meta.val_idx), val.to_opaque());
            if (val.val_changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_ptr_or_null(self: *Table, id: ParamId, comptime T: type, val: PTPtrOrNull(T), comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .PTR_OR_NULL, must_be_init, cannot_be_derived, cannot_be_root);
            self.list_ptr.set(@intCast(meta.val_idx), val.to_opaque());
            if (val.val_changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_list(self: *Table, id: ParamId, comptime T: type, val: PTList(T), comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .LIST, must_be_init, cannot_be_derived, cannot_be_root);
            self.list_ptr.set(@intCast(meta.val_idx), val.to_opaque());
            if (val.vals_changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
        pub fn _set_color(self: *Table, id: ParamId, val: Color32, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            const meta = self.get_meta_with_check(id, .COLOR, must_be_init, cannot_be_derived, cannot_be_root);
            const changed = self.list_32.set_report_change(@intCast(meta.val_idx), @bitCast(val));
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }

        pub fn _set_meta(self: *Table, id: ParamId, meta: Metadata, comptime T: type, val: T, comptime must_be_init: e_init, comptime cannot_be_derived: e_derived, comptime cannot_be_root: e_root) void {
            check_meta_state_only(id, meta, must_be_init, cannot_be_derived, cannot_be_root);
            var changed: bool = false;
            switch (T) {
                u64 => {
                    assert_meta_is_type(id, meta, .U64, @src());
                    changed = self.list_64.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                i64 => {
                    assert_meta_is_type(id, meta, .I64, @src());
                    changed = self.list_64.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                f64 => {
                    assert_meta_is_type(id, meta, .F64, @src());
                    changed = self.list_64.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                u32 => {
                    assert_meta_is_type(id, meta, .U32, @src());
                    changed = self.list_32.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                i32 => {
                    assert_meta_is_type(id, meta, .I32, @src());
                    changed = self.list_32.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                f32 => {
                    assert_meta_is_type(id, meta, .F32, @src());
                    changed = self.list_32.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                u16 => {
                    assert_meta_is_type(id, meta, .U16, @src());
                    changed = self.list_16.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                i16 => {
                    assert_meta_is_type(id, meta, .I16, @src());
                    changed = self.list_16.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                f16 => {
                    assert_meta_is_type(id, meta, .F16, @src());
                    changed = self.list_16.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                u8 => {
                    assert_meta_is_type(id, meta, .U8, @src());
                    changed = self.list_8.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                i8 => {
                    assert_meta_is_type(id, meta, .I8, @src());
                    changed = self.list_8.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                bool => {
                    assert_meta_is_type(id, meta, .BOOL, @src());
                    changed = self.list_8.set_report_change(@intCast(meta.val_idx), @bitCast(val));
                },
                Color32 => {
                    assert_meta_is_type(id, meta, .COLOR, @src());
                },
                else => {
                    const TT = assert_type_ptptr_or_ptlist_and_get_base_type(T, .ptr);
                    const PTP = PTPtr(TT);
                    const PTPN = PTPtrOrNull(TT);
                    const PTL = PTList(TT);
                    switch (T) {
                        PTP => {
                            assert_meta_is_type(id, meta, .PTR, @src());
                            changed = self.list_ptr.set_report_change(@intCast(meta.val_idx), val.to_opaque());
                            changed = changed or val.val_changed;
                        },
                        PTPN => {
                            assert_meta_is_type(id, meta, .PTR_OR_NULL, @src());
                            changed = self.list_ptr.set_report_change(@intCast(meta.val_idx), val.to_opaque());
                            changed = changed or val.val_changed;
                        },
                        PTL => {
                            assert_meta_is_type(id, meta, .LIST, @src());
                            changed = self.list_list.set_report_change(@intCast(meta.val_idx), val.to_opaque());
                            changed = changed or val.vals_changed;
                        },
                        else => assert_unreachable(@src(), "type `T` MUST be one of the following types:\nbool, u8, i8, u16, i16, f16, u32, i32, f32, u64, i64, f64, PTPtr(TT), PTPtrOrNull(TT), or PTList(TT)\ngot type {s}", .{@typeName(T)}),
                    }
                },
            }
            if (changed or meta.should_always_update()) {
                self.queue_children(meta);
            }
        }
    };
};

test "ParamTable" {
    const Test = Root.Testing;
    const allocator_type = Root.SlabBucketAllocator.SimpleBucketAllocator(.new(.single_threaded, 16));
    var allocator_concrete = allocator_type.init(std.heap.page_allocator);
    const allocator = allocator_concrete.allocator();
    var my_param_table = Table.init(1, allocator);
    const do_debug = false;

    const TwoF32Object = struct {
        a: f32,
        b: f32,
    };
    const F32Object = struct {
        a: f32,
    };
    const ParentSizeButtonSize = struct {
        pw: f32,
        ph: f32,
        bw: f32,
        bh: f32,
    };
    const ParentAreaButtonArea = struct {
        pa: f32,
        ba: f32,
        ta: f32,
    };

    const CALC = struct {
        pub fn a_plus_b(iface: Calc.CalcInterface) void {
            const in = iface.get_inputs(TwoF32Object);
            var out = iface.get_outputs_uninit(F32Object);
            out.a = in.a + in.b;
            iface.commit_outputs(out);
        }

        pub fn half_a_minus_2b(iface: Calc.CalcInterface) void {
            const in = iface.get_inputs(TwoF32Object);
            var out = iface.get_outputs_uninit(F32Object);
            out.a = (in.a * 0.5) - (in.b * 2.0);
            iface.commit_outputs(out);
        }

        pub fn linked_area_parent_and_button(iface: Calc.CalcInterface) void {
            const in = iface.get_inputs(ParentSizeButtonSize);
            var out = iface.get_outputs_uninit(ParentAreaButtonArea);
            out.pa = in.ph * in.pw;
            out.ba = in.bh * in.bw;
            out.ta = out.pa + out.ba;
            iface.commit_outputs(out);
        }
    };

    const CALC_A_PLUS_B = my_param_table.register_calc(CALC.a_plus_b);
    const CALC_HALF_A_MINUS_2B = my_param_table.register_calc(CALC.half_a_minus_2b);
    const CALC_LINKED_AREA_PARENT_AND_BUTTON = my_param_table.register_calc(CALC.linked_area_parent_and_button);

    const Px = my_param_table.init_root_f32(100.0, .only_update_when_value_changes);
    const Py = my_param_table.init_root_f32(200.0, .only_update_when_value_changes);
    const Pw = my_param_table.init_root_f32(800.0, .only_update_when_value_changes);
    const Ph = my_param_table.init_root_f32(600.0, .only_update_when_value_changes);

    const Margin = my_param_table.init_root_f32(32.0, .only_update_when_value_changes);

    // Derived variables must be declared AFTER the calculations they use
    // and the root/derived values they are children of
    const Bx = my_param_table.init_derived_f32(.only_update_when_value_changes, CALC_A_PLUS_B, &.{ Px, Margin });
    const By = my_param_table.init_derived_f32(.only_update_when_value_changes, CALC_A_PLUS_B, &.{ Py, Margin });
    const Bw = my_param_table.init_derived_f32(.only_update_when_value_changes, CALC_HALF_A_MINUS_2B, &.{ Pw, Margin });
    const Bh = my_param_table.init_derived_f32(.only_update_when_value_changes, CALC_HALF_A_MINUS_2B, &.{ Ph, Margin });

    const Areas: [3]ParamId = my_param_table.init_derived_linked(CALC_LINKED_AREA_PARENT_AND_BUTTON, &.{ Pw, Ph, Bw, Bh }, 3, .{
        .new(.F32, .only_update_when_value_changes),
        .new(.F32, .only_update_when_value_changes),
        .new(.F32, .only_update_when_value_changes),
    });
    const Ap = Areas[0];
    const Ab = Areas[1];
    const At = Areas[2];

    const debug = struct {
        pub fn print_vals(table: *Table, px: ParamId, py: ParamId, pw: ParamId, ph: ParamId, pa: ParamId, bx: ParamId, by: ParamId, bw: ParamId, bh: ParamId, ba: ParamId, ta: ParamId) void {
            std.debug.print("       X     Y     W     H       A\nP: {d: >5} {d: >5} {d: >5} {d: >5} {d: >7}\nB: {d: >5} {d: >5} {d: >5} {d: >5} {d: >7}\nT:                         {d: >7}\n", .{
                table.get_f32(px), table.get_f32(py), table.get_f32(pw), table.get_f32(ph), table.get_f32(pa),
                table.get_f32(bx), table.get_f32(by), table.get_f32(bw), table.get_f32(bh), table.get_f32(ba),
                table.get_f32(ta),
            });
        }
        pub fn print_ids(px: ParamId, py: ParamId, pw: ParamId, ph: ParamId, pa: ParamId, bx: ParamId, by: ParamId, bw: ParamId, bh: ParamId, ba: ParamId, ta: ParamId) void {
            std.debug.print("       X     Y     W     H     A\nP: {d: >5} {d: >5} {d: >5} {d: >5} {d: >5}\nB: {d: >5} {d: >5} {d: >5} {d: >5} {d: >5}\nT:                         {d: >5}\n", .{
                px.id, py.id, pw.id, ph.id, pa.id,
                bx.id, by.id, bw.id, bh.id, ba.id,
                ta.id,
            });
        }
    };

    if (do_debug) {
        debug.print_ids(Px, Py, Pw, Ph, Ap, Bx, By, Bw, Bh, Ab, At);
        debug.print_vals(&my_param_table, Px, Py, Pw, Ph, Ap, Bx, By, Bw, Bh, Ab, At);
    }

    try Test.expect_equal(my_param_table.get_f32(Bx), "my_param_table.get_f32(Bx)", 132.0, "132.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(By), "my_param_table.get_f32(By)", 232.0, "232.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(Bw), "my_param_table.get_f32(Bw)", 336.0, "336.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(Bh), "my_param_table.get_f32(Bh)", 236.0, "236.0", "failed automatic update", .{});

    try Test.expect_equal(my_param_table.get_f32(Ap), "my_param_table.get_f32(Ap)", 480000.0, "480000.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(Ab), "my_param_table.get_f32(Ab)", 79296.0, "79296.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(At), "my_param_table.get_f32(At)", 559296.0, "559296.0", "failed automatic update", .{});

    my_param_table.set_root_f32(Pw, 990.0);
    my_param_table.set_root_f32(Py, 333.0);
    my_param_table.set_root_f32(Margin, 48.0);

    if (do_debug) {
        debug.print_ids(Px, Py, Pw, Ph, Ap, Bx, By, Bw, Bh, Ab, At);
        debug.print_vals(&my_param_table, Px, Py, Pw, Ph, Ap, Bx, By, Bw, Bh, Ab, At);
    }

    try Test.expect_equal(my_param_table.get_f32(Bx), "my_param_table.get_f32(Bx)", 148.0, "148.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(By), "my_param_table.get_f32(By)", 381.0, "381.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(Bw), "my_param_table.get_f32(Bw)", 399.0, "399.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(Bh), "my_param_table.get_f32(Bh)", 204.0, "204.0", "failed automatic update", .{});

    try Test.expect_equal(my_param_table.get_f32(Ap), "my_param_table.get_f32(Ap)", 594000.0, "594000.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(Ab), "my_param_table.get_f32(Ab)", 81396.0, "81396.0", "failed automatic update", .{});
    try Test.expect_equal(my_param_table.get_f32(At), "my_param_table.get_f32(At)", 675396.0, "675396.0", "failed automatic update", .{});

    if (do_debug) {
        std.debug.print("TestTable MEM: {d} bytes\n", .{my_param_table.total_memory_footprint()});
    }
}

pub const RootOrDerived = enum(u8) {
    root,
    derived,
};
