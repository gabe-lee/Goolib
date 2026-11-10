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

comptime {
    if (build.is_test) {
        _ = @import("./Observer_Tests.zig");
    }
}

const std = @import("std");
const build = @import("builtin");

/// std imports
const Allocator = std.mem.Allocator;
const Io = std.Io;
const math = std.math;
const DEBUG = std.debug.print;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Type = Root.Types;
const Math = Root.Math;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Common = Root.CommonTypes;
const Test = Root.Testing;
const AllocatorModule = Root.Allocator;
const ListSlice = Root.ListSlice;
const SourceLocation = std.builtin.SourceLocation;
const AllocSource = AllocatorModule.AllocSource;
const AllocAdapter = AllocatorModule.AllocatorAdapter;
const Types = Root.Types;

const dummy_alloc = AllocatorModule.Dummy.allocator_panic_free_noop;
const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;

const DEBUG_VAL = Utils.DebugPrint.debug_val;

pub const NotifyMode = enum {
    DONT_NOTIFY,
    ALWAYS_NOTIFY,
    NOTIFY_IF_EXISTS,
};

pub fn Observer(comptime NOTIFICATION: type) type {
    return struct {
        const Self = @This();
        observer_opaque: ?*anyopaque = null,
        notify_impl: *const fn (observer_opaque: *anyopaque, notif: NOTIFICATION) void,

        pub inline fn notify(self: Self, notif: NOTIFICATION) void {
            assert_with_reason(self.observer_opaque != null, @src(), "the observing object was null", .{});
            self.notify_impl(self.observer_opaque.?, notif);
        }
        pub inline fn notify_with_mode(self: Self, notif: NOTIFICATION, mode: NotifyMode) void {
            switch (mode) {
                .DONT_NOTIFY => {},
                .ALWAYS_NOTIFY => self.notify(notif),
                .NOTIFY_IF_EXISTS => self.notify_if_exists(notif),
            }
        }
        pub inline fn notify_with_ct_mode(self: Self, notif: NOTIFICATION, comptime mode: NotifyMode) void {
            switch (comptime mode) {
                .DONT_NOTIFY => {},
                .ALWAYS_NOTIFY => self.notify(notif),
                .NOTIFY_IF_EXISTS => self.notify_if_exists(notif),
            }
        }
        pub inline fn notify_if_exists(self: Self, notif: NOTIFICATION) void {
            if (self.observer_opaque) |obs_opq| {
                self.notify_impl(obs_opq, notif);
            }
        }
        pub inline fn notify_if_exists_and_report_exists(self: Self, notif: NOTIFICATION) bool {
            if (self.observer_opaque) |obs_opq| {
                self.notify_impl(obs_opq, notif);
                return true;
            }
            return false;
        }

        pub inline fn exists(self: Self) bool {
            return self.observer_opaque != null;
        }
        pub inline fn doesnt_exist(self: Self) bool {
            return self.observer_opaque == null;
        }
    };
}

pub noinline fn OBSERVABLE_GEN_ID() u64 {
    return comptime Utils.src_loc_hash(@src());
}
pub fn Observable(comptime T: type, comptime NOTIFICATION_: type, comptime ALLOC_SOURCE_: AllocSource) type {
    return struct {
        pub const GENERIC_ID = OBSERVABLE_GEN_ID();
        pub const NOTIFICATION = NOTIFICATION_;
        pub const ALLOC_SOURCE = ALLOC_SOURCE_;
        const Self = @This();
        const ObserverIface = Observer(NOTIFICATION);
        const ObserverList = ListSlice.ListFullDefinition(ObserverIface, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, ALLOC_SOURCE);
        const Alloc = AllocAdapter(ALLOC_SOURCE);
        const PassedAlloc = Alloc.PassedAlloc;
        const InitAlloc = Alloc.InitAlloc;
        const CachedAlloc = Alloc.CachedAlloc;

        val: T = undefined,
        observers: ObserverList = .{},

        pub inline fn init(self: *Self, initial_val: T, cached_alloc: CachedAlloc) void {
            self.val = initial_val;
            self.observers = ObserverList.new(cached_alloc);
        }
        pub inline fn init_with_cap(self: *Self, initial_val: T, observer_cap: u32, init_alloc: InitAlloc) void {
            self.val = initial_val;
            self.observers = ObserverList.allocate_new(observer_cap, init_alloc);
        }
        pub inline fn new(initial_val: T, cached_alloc: CachedAlloc) Self {
            return Self{ .val = initial_val, .observers = ObserverList.new(cached_alloc) };
        }
        pub inline fn new_with_cap(initial_val: T, observer_cap: u32, init_alloc: InitAlloc) Self {
            return Self{ .val = initial_val, .observers = ObserverList.allocate_new(observer_cap, init_alloc) };
        }

        pub inline fn add_observer(self: *Self, observer: ObserverIface, alloc: PassedAlloc) void {
            if (self.observers.find_advanced(observer, 0, self.observers.get_len(), .FIRST, {}, {}, .COMPTIME_FN_BODY, {}, observers_equal)) |_| {
                return;
            } else {
                self.observers.append_one(observer, alloc);
            }
        }
        pub inline fn remove_observer(self: *Self, observer: ObserverIface) void {
            if (self.observers.find_advanced(observer, 0, self.observers.get_len(), .FIRST, {}, {}, .COMPTIME_FN_BODY, {}, observers_equal)) |idx| {
                self.observers.swap_delete_one(idx);
            }
        }
        fn observers_equal(slice: ObserverList, idx_a: u32, val: ObserverIface, _: void, comptime _: void) bool {
            return @intFromPtr(slice.get(idx_a).observer_opaque) == @intFromPtr(val.observer_opaque);
        }
        pub fn notify_all_observers(self: Self, notif: NOTIFICATION) void {
            for (self.observers.zig_slice_entire_const()) |observer| {
                observer.notify(notif);
            }
        }
        pub fn notify_all_observers_that_exist(self: Self, notif: NOTIFICATION) void {
            for (self.observers.zig_slice_entire_const()) |observer| {
                observer.notify_if_exists(notif);
            }
        }
        pub fn notify_all_observers_that_exist_report_if_all_exist(self: Self, notif: NOTIFICATION) bool {
            var all_exist: bool = true;
            for (self.observers.zig_slice_entire_const()) |observer| {
                const exists = observer.notify_if_exists_and_report_exists(notif);
                all_exist = all_exist and exists;
            }
            return all_exist;
        }
    };
}

pub const ObservingActionSourceKind = enum {
    RUNTIME_FN_PTR,
    COMPTIME_FN_PTR,
    COMPTIME_FN_BODY,
};

pub const ObservingActionDef = struct {
    INPUTS: type,
    OUTPUTS: type,
    ALLOW_NON_OBSERVABLE_INPUTS: bool = false,
    NOTIFICATION: type,
    ALLOC_SOURCE_FOR_OBSERVABLES: AllocSource,
};

pub fn ObservingActionSource(comptime DEF: ObservingActionDef) type {
    return union(ObservingActionSourceKind) {
        const Self = @This();
        pub const INPUTS = DEF.INPUTS;
        pub const OUTPUTS = DEF.OUTPUTS;
        pub const NOTIF = DEF.NOTIFICATION;

        RUNTIME_FN_PTR: void,
        COMPTIME_FN_PTR: *const fn (INPUTS, OUTPUTS, NOTIF) void,
        COMPTIME_FN_BODY: fn (INPUTS, OUTPUTS, NOTIF) void,

        pub fn runtime_func() Self {
            return Self{ .RUNTIME_FN_PTR = {} };
        }
        pub fn comptime_func_ptr(comptime func: *const fn (INPUTS, OUTPUTS, NOTIF) void) Self {
            return Self{ .COMPTIME_FN_PTR = func };
        }
        pub fn comptime_func_body(comptime func: fn (INPUTS, OUTPUTS, NOTIF) void) Self {
            return Self{ .COMPTIME_FN_BODY = func };
        }

        pub fn CACHED_FN(comptime self: Self) type {
            return switch (comptime self) {
                .RUNTIME_FN_PTR => *const fn (INPUTS, OUTPUTS, NOTIF) void,
                .COMPTIME_FN_BODY, .COMPTIME_FN_PTR => void,
            };
        }
        pub fn CACHED_FN_INIT(comptime self: Self) self.CACHED_FN() {
            return switch (comptime self) {
                .RUNTIME_FN_PTR => noop,
                .COMPTIME_FN_BODY, .COMPTIME_FN_PTR => {},
            };
        }
        pub fn CONST_FN(comptime self: Self) type {
            return switch (comptime self) {
                .RUNTIME_FN_PTR => void,
                .COMPTIME_FN_PTR => *const fn (INPUTS, OUTPUTS, NOTIF) void,
                .COMPTIME_FN_BODY => fn (INPUTS, OUTPUTS, NOTIF) void,
            };
        }
        pub fn CONST_FN_INIT(comptime self: Self) self.CONST_FN() {
            return switch (comptime self) {
                .RUNTIME_FN_PTR => {},
                .COMPTIME_FN_PTR => |FN| FN,
                .COMPTIME_FN_BODY => |FN| FN,
            };
        }

        fn noop(_: INPUTS, _: OUTPUTS, _: NOTIF) void {
            return;
        }
    };
}

fn is_observable_type(comptime T: type, comptime NOTIF: type, comptime ALLOC_SOURCE: AllocSource) bool {
    switch (comptime @typeInfo(T)) {
        .@"struct" => {
            return Types.type_has_decl_with_type_and_val(T, "GENERIC_ID", u64, comptime OBSERVABLE_GEN_ID()) and //
                Types.type_has_decl_with_type_and_val(T, "NOTIFICATION", type, NOTIF) and //
                Types.type_has_decl_with_type(T, "ALLOC_SOURCE", AllocSource) and //
                @field(T, "ALLOC_SOURCE").equals(ALLOC_SOURCE);
        },
        else => return false,
    }
}

fn assert_observable_input(comptime ALLOW_NON_OBSERVABLE_INPUTS: bool, comptime NOTIF: type, comptime ALLOC_SOURCE: AllocSource, comptime IN: type) void {
    assert_with_reason(ALLOW_NON_OBSERVABLE_INPUTS, @src(), "if `ALLOW_NON_OBSERVABLE_INPUTS` is false, ALL input must be one of `*Observable(T, {s}, {s})`,  `*[_]Observable(T, ..., ...)`,  `[]Observable(T, ..., ...)`,  `[_]*Observable(T, ..., ...)` types (or a struct where every field is one of the previous types), got type `{s}`", .{ @typeName(NOTIF), ALLOC_SOURCE.debug_str(), @typeName(IN) });
}

fn add_observer_on_all_inputs(comptime NOTIF: type, comptime ALLOC_SOURCE: AllocSource, passed_alloc: ALLOC_SOURCE.PARAM_TYPE(), obs: Observer(NOTIF), comptime IN: type, in: IN, comptime ALLOW_NON_OBSERVABLE_INPUTS: bool) void {
    switch (comptime @typeInfo(IN)) {
        .pointer => |PTR| {
            const CHILD = PTR.child;
            if (comptime (is_observable_type(CHILD, NOTIF, ALLOC_SOURCE) and //
                PTR.attrs.@"const" == false and //
                (PTR.size == .one or PTR.size == .slice)))
            {
                switch (comptime PTR.size) {
                    .one => {
                        in.add_observer(obs, passed_alloc);
                    },
                    .slice => {
                        for (in) |*sub_in| {
                            sub_in.add_observer(obs, passed_alloc);
                        }
                    },
                    else => unreachable,
                }
            } else {
                const CHILD_INFO = @typeInfo(CHILD);
                switch (comptime CHILD_INFO) {
                    .array => |ARR| {
                        const CHILD2 = ARR.child;
                        const CHILD2_INFO = @typeInfo(CHILD2);
                        if (comptime CHILD2_INFO == .pointer) {
                            const CHILD_PTR2 = CHILD2_INFO.pointer;
                            if (comptime (is_observable_type(CHILD_PTR2.child, NOTIF, ALLOC_SOURCE) and //
                                CHILD_PTR2.attrs.@"const" == false and //
                                CHILD_PTR2.size == .one and //
                                PTR.attrs.@"const" == false and //
                                PTR.size == .one))
                            {
                                for (in[0..]) |sub_in| {
                                    sub_in.add_observer(obs, passed_alloc);
                                }
                            } else {
                                assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
                            }
                        } else if (comptime (is_observable_type(CHILD2, NOTIF, ALLOC_SOURCE) and //
                            PTR.attrs.@"const" == false and //
                            PTR.size == .one))
                        {
                            for (in[0..]) |*sub_in| {
                                sub_in.add_observer(obs, passed_alloc);
                            }
                        } else {
                            assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
                        }
                    },
                    .pointer => |CHILD_PTR| {
                        if (comptime (is_observable_type(CHILD_PTR.child, NOTIF, ALLOC_SOURCE) and //
                            CHILD_PTR.attrs.@"const" == false and //
                            PTR.attrs.@"const" == false and //
                            PTR.size == .slice))
                        {
                            for (in) |sub_in| {
                                sub_in.add_observer(obs, passed_alloc);
                            }
                        } else {
                            assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
                        }
                    },
                    else => {
                        assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
                    },
                }
            }
        },
        .array => |ARR| {
            inline for (0..ARR.len) |i| {
                add_observer_on_all_inputs(NOTIF, ALLOC_SOURCE, passed_alloc, obs, ARR.child, in[i], ALLOW_NON_OBSERVABLE_INPUTS);
            }
        },
        .@"struct" => |STRUCT| {
            inline for (STRUCT.field_types, STRUCT.field_names) |FIELD_T, FIELD_NAME| {
                add_observer_on_all_inputs(NOTIF, ALLOC_SOURCE, passed_alloc, obs, FIELD_T, @field(in, FIELD_NAME), ALLOW_NON_OBSERVABLE_INPUTS);
            }
        },
        else => {
            assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
        },
    }
}

fn remove_observer_on_all_inputs(comptime NOTIF: type, comptime ALLOC_SOURCE: AllocSource, obs: Observer(NOTIF), comptime IN: type, in: IN, comptime ALLOW_NON_OBSERVABLE_INPUTS: bool) void {
    switch (comptime @typeInfo(IN)) {
        .pointer => |PTR| {
            const CHILD = PTR.child;
            if (comptime (is_observable_type(CHILD, NOTIF, ALLOC_SOURCE) and //
                PTR.attrs.@"const" == false and //
                (PTR.size == .one or PTR.size == .slice)))
            {
                switch (comptime PTR.size) {
                    .one => {
                        in.remove_observer(obs);
                    },
                    .slice => {
                        for (in) |*sub_in| {
                            sub_in.remove_observer(obs);
                        }
                    },
                    else => unreachable,
                }
            } else {
                const CHILD_INFO = @typeInfo(CHILD);
                switch (comptime CHILD_INFO) {
                    .array => |ARR| {
                        const CHILD2 = ARR.child;
                        const CHILD2_INFO = @typeInfo(CHILD2);
                        if (comptime CHILD2_INFO == .pointer) {
                            const CHILD_PTR2 = CHILD2_INFO.pointer;
                            if (comptime (is_observable_type(CHILD_PTR2.child, NOTIF, ALLOC_SOURCE) and //
                                CHILD_PTR2.attrs.@"const" == false and //
                                CHILD_PTR2.size == .one and //
                                PTR.attrs.@"const" == false and //
                                PTR.size == .one))
                            {
                                for (in[0..]) |sub_in| {
                                    sub_in.remove_observer(obs);
                                }
                            } else {
                                assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
                            }
                        } else if (comptime (is_observable_type(CHILD2, NOTIF, ALLOC_SOURCE) and //
                            PTR.attrs.@"const" == false and //
                            PTR.size == .one))
                        {
                            for (in[0..]) |*sub_in| {
                                sub_in.remove_observer(obs);
                            }
                        } else {
                            assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
                        }
                    },
                    .pointer => |CHILD_PTR| {
                        if (comptime (is_observable_type(CHILD_PTR.child, NOTIF, ALLOC_SOURCE) and //
                            CHILD_PTR.attrs.@"const" == false and //
                            PTR.attrs.@"const" == false and //
                            PTR.size == .slice))
                        {
                            for (in) |sub_in| {
                                sub_in.remove_observer(obs);
                            }
                        } else {
                            assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
                        }
                    },
                    else => {
                        assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
                    },
                }
            }
        },
        .array => |ARR| {
            inline for (0..ARR.len) |i| {
                remove_observer_on_all_inputs(NOTIF, ALLOC_SOURCE, obs, ARR.child, in[i], ALLOW_NON_OBSERVABLE_INPUTS);
            }
        },
        .@"struct" => |STRUCT| {
            inline for (STRUCT.field_types, STRUCT.field_names) |FIELD_T, FIELD_NAME| {
                remove_observer_on_all_inputs(NOTIF, ALLOC_SOURCE, obs, FIELD_T, @field(in, FIELD_NAME), ALLOW_NON_OBSERVABLE_INPUTS);
            }
        },
        else => {
            assert_observable_input(ALLOW_NON_OBSERVABLE_INPUTS, NOTIF, ALLOC_SOURCE, IN);
        },
    }
}

pub fn ObservingAction(comptime DEF: ObservingActionDef, comptime ACTION_SOURCE: ObservingActionSource(DEF)) type {
    return struct {
        const Self = @This();
        const ConstFn = ACTION_SOURCE.CONST_FN();
        pub const CachedFn = ACTION_SOURCE.CACHED_FN();
        pub const Inputs = DEF.INPUTS;
        pub const Outputs = DEF.OUTPUTS;
        pub const Notification = DEF.NOTIFICATION;
        const ALLOW_NON_OBSERVE_INPUTS = DEF.ALLOW_NON_OBSERVABLE_INPUTS;
        pub const ObserverIface = Observer(Notification);
        pub const ALLOC_SOURCE = DEF.ALLOC_SOURCE_FOR_OBSERVABLES;
        pub const PassedAlloc = DEF.ALLOC_SOURCE_FOR_OBSERVABLES.PARAM_TYPE();

        const A: ACTION_SOURCE.CONST_FN() = ACTION_SOURCE.CONST_FN_INIT();
        a: ACTION_SOURCE.CACHED_FN() = ACTION_SOURCE.CACHED_FN_INIT(),
        in: Inputs = undefined,
        out: Outputs = undefined,
        is_init: if (Assert.should_assert()) bool else void = if (Assert.should_assert()) false else {},

        inline fn do_action(self: Self, in: Inputs, out: Outputs, notif: Notification) void {
            switch (comptime ACTION_SOURCE) {
                .RUNTIME_FN_PTR => self.a(in, out, notif),
                .COMPTIME_FN_PTR => A(in, out, notif),
                .COMPTIME_FN_BODY => A(in, out, notif),
            }
        }

        pub fn init(self: *Self, in: Inputs, out: Outputs, cached_action: CachedFn, passed_alloc_for_all_observables: PassedAlloc) void {
            if (comptime Assert.should_assert()) {
                assert_with_reason(self.is_init == false, @src(), "observing action was already initialized", .{});
                self.is_init = true;
            }
            self.a = cached_action;
            self.in = in;
            self.out = out;
            const obs_iface = self.observer_interface();
            add_observer_on_all_inputs(Notification, ALLOC_SOURCE, passed_alloc_for_all_observables, obs_iface, Inputs, in, ALLOW_NON_OBSERVE_INPUTS);
        }
        pub fn uninit(self: *Self) void {
            if (comptime Assert.should_assert()) {
                assert_with_reason(self.is_init == true, @src(), "observing action was not initialized, cannot uninitialize", .{});
                self.is_init = false;
            }
            const obs_iface = self.observer_interface();
            remove_observer_on_all_inputs(Notification, ALLOC_SOURCE, obs_iface, Inputs, self.in, ALLOW_NON_OBSERVE_INPUTS);
        }

        fn notify_impl(self_opaque: *anyopaque, notif: Notification) void {
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            self.do_action(self.in, self.out, notif);
        }
        pub inline fn observer_interface(self: *Self) ObserverIface {
            return ObserverIface{
                .notify_impl = notify_impl,
                .observer_opaque = @ptrCast(@alignCast(self)),
            };
        }

        pub fn notify_action(self: Self, notification: Notification) void {
            self.do_action(self.in, self.out, notification);
        }
    };
}
