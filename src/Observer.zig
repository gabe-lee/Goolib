// //! //TODO Documentation
// //! #### License: Zlib

// // zlib license
// //
// // Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
// //
// // This software is provided 'as-is', without any express or implied
// // warranty. In no event will the authors be held liable for any damages
// // arising from the use of this software.
// //
// // Permission is granted to anyone to use this software for any purpose,
// // including commercial applications, and to alter it and redistribute it
// // freely, subject to the following restrictions:
// //
// // 1. The origin of this software must not be misrepresented; you must not
// //    claim that you wrote the original software. If you use this software
// //    in a product, an acknowledgment in the product documentation would be
// //    appreciated but is not required.
// // 2. Altered source versions must be plainly marked as such, and must not be
// //    misrepresented as being the original software.
// // 3. This notice may not be removed or altered from any source distribution.

// const std = @import("std");
// const build = @import("builtin");

// /// std imports
// const Allocator = std.mem.Allocator;
// const Io = std.Io;
// const math = std.math;
// const DEBUG = std.debug.print;

// /// Goolib imports
// const Root = @import("./_root.zig");
// const Cast = Root.Cast;
// const Type = Root.Types;
// const Math = Root.Math;
// const Assert = Root.Assert;
// const Utils = Root.Utils;
// const Common = Root.CommonTypes;
// const Test = Root.Testing;
// const AllocatorModule = Root.Allocator;
// const ListSlice = Root.ListSlice;

// const dummy_alloc = AllocatorModule.Dummy.allocator_panic_free_noop;
// const assert_with_reason = Assert.assert_with_reason;
// const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
// const assert_unreachable = Assert.assert_unreachable;
// const assert_unreachable_err = Assert.assert_unreachable_err;
// const num_cast = Cast.num_cast;

// const DEBUG_VAL = Utils.DebugPrint.debug_val;

// pub const ValueChange = enum(u64) {
//     CREATED = 0,
//     CHANGED = 1,
//     DELETED = 2,
// };

// pub const NotifyMode = enum {
//     DONT_NOTIFY,
//     ALWAYS_NOTIFY,
//     NOTIFY_IF_EXISTS,
// };

// pub fn Observer(comptime NOTIFICATION: type) type {
//     return struct {
//         const Self = @This();
//         observer_opaque: ?*anyopaque = null,
//         notify_impl: *const fn (observer_opaque: *anyopaque, notif: NOTIFICATION) void,

//         pub inline fn notify(self: Self, notif: NOTIFICATION) void {
//             assert_with_reason(self.observer_opaque != null, @src(), "the observing object was null", .{});
//             self.notify_impl(self.observer_opaque.?, notif);
//         }
//         pub inline fn notify_with_mode(self: Self, notif: NOTIFICATION, mode: NotifyMode) void {
//             switch (mode) {
//                 .DONT_NOTIFY => {},
//                 .ALWAYS_NOTIFY => self.notify(notif),
//                 .NOTIFY_IF_EXISTS => self.notify_if_exists(notif),
//             }
//         }
//         pub inline fn notify_with_ct_mode(self: Self, notif: NOTIFICATION, comptime mode: NotifyMode) void {
//             switch (comptime mode) {
//                 .DONT_NOTIFY => {},
//                 .ALWAYS_NOTIFY => self.notify(notif),
//                 .NOTIFY_IF_EXISTS => self.notify_if_exists(notif),
//             }
//         }
//         pub inline fn notify_if_exists(self: Self, notif: NOTIFICATION) void {
//             if (self.observer_opaque) |obs_opq| {
//                 self.notify_impl(obs_opq, notif);
//             }
//         }
//         pub inline fn notify_if_exists_and_report_exists(self: Self, notif: NOTIFICATION) bool {
//             if (self.observer_opaque) |obs_opq| {
//                 self.notify_impl(obs_opq, notif);
//                 return true;
//             }
//             return false;
//         }

//         pub inline fn exists(self: Self) bool {
//             return self.observer_opaque != null;
//         }
//         pub inline fn doesnt_exist(self: Self) bool {
//             return self.observer_opaque == null;
//         }
//     };
// }

// pub const ValueChangeObserver = Observer(ValueChange);

// pub fn AccessFuncs(comptime TYPE_SET: TypeSet) type {
//     return struct {
//         const Self = @This();

//         get: fn (TYPE_SET.PRIVATE) TYPE_SET.PUBLIC,
//         get_ptr: fn (*TYPE_SET.PRIVATE) *TYPE_SET.PUBLIC,
//         get_const_ptr: fn (*const TYPE_SET.PRIVATE) *const TYPE_SET.PUBLIC,
//         set: fn (*TYPE_SET.PRIVATE, TYPE_SET.PUBLIC) void,

//         pub fn auto_access_funcs() Self {
//             assert_with_reason(TYPE_SET.PRIVATE == TYPE_SET.PUBLIC, @src(), "`auto_access_funcs()` is only valid when `TYPE_SET.PRIVATE == TYPE_SET.PUBLIC`, got `{s}` != `{s}`", .{ @typeName(TYPE_SET.PRIVATE), @typeName(TYPE_SET.PUBLIC) });
//             const PROTO = struct {
//                 fn _get(self: TYPE_SET.PRIVATE) TYPE_SET.PUBLIC {
//                     return self;
//                 }
//                 fn _get_ptr(self: *TYPE_SET.PRIVATE) *TYPE_SET.PUBLIC {
//                     return self;
//                 }
//                 fn _get_const_ptr(self: *const TYPE_SET.PRIVATE) *const TYPE_SET.PUBLIC {
//                     return self;
//                 }
//                 fn _set(self: *TYPE_SET.PRIVATE, val: TYPE_SET.PUBLIC) void {
//                     self.* = val;
//                 }
//             };
//             return Self{
//                 .get = PROTO._get,
//                 .get_ptr = PROTO._get_ptr,
//                 .get_const_ptr = PROTO._get_const_ptr,
//                 .set = PROTO._set,
//             };
//         }
//     };
// }

// // pub fn IndirectAccessFuncs(comptime TYPE_SET: TypeSet) type {
// //     return struct {
// //         const Self = @This();

// //         get: fn (TYPE_SET.PRIVATE) TYPE_SET.PUBLIC,
// //         get_ptr: fn (TYPE_SET.PRIVATE) *TYPE_SET.PUBLIC,
// //         get_const_ptr: fn (TYPE_SET.PRIVATE) *const TYPE_SET.PUBLIC,
// //         set: fn (TYPE_SET.PRIVATE, TYPE_SET.PUBLIC) void,

// //         pub fn auto_access_funcs() Self {
// //             const PROTO = struct {
// //                 fn _get(self: TYPE_SET.PRIVATE) TYPE_SET.PUBLIC {
// //                     return self.get();
// //                 }
// //                 fn _get_ptr(self: TYPE_SET.PRIVATE) *TYPE_SET.PUBLIC {
// //                     return self.get_ptr();
// //                 }
// //                 fn _get_const_ptr(self: TYPE_SET.PRIVATE) *const TYPE_SET.PUBLIC {
// //                     return self.get_const_ptr;
// //                 }
// //                 fn _set(self: TYPE_SET.PRIVATE, val: TYPE_SET.PUBLIC) void {
// //                     self.set(val);
// //                 }
// //             };
// //             return Self{
// //                 .get = PROTO._get,
// //                 .get_ptr = PROTO._get_ptr,
// //                 .get_const_ptr = PROTO._get_const_ptr,
// //                 .set = PROTO._set,
// //             };
// //         }
// //     };
// // }

// // pub const AccessMode = enum {
// //     DIRECT,
// //     INDIRECT,
// // };

// // pub fn Access(comptime TYPE_SET: TypeSet) type {
// //     return union(AccessMode) {
// //         const Self = @This();

// //         DIRECT: DirectAccessFuncs(TYPE_SET),
// //         INDIRECT: IndirectAccessFuncs(TYPE_SET),

// //         pub fn direct_access(comptime funcs: DirectAccessFuncs(TYPE_SET)) Self {
// //             return Self{ .DIRECT = funcs };
// //         }
// //         pub fn indirect_access(comptime funcs: IndirectAccessFuncs(TYPE_SET)) Self {
// //             return Self{ .INDIRECT = funcs };
// //         }
// //     };
// // }

// pub const TypeSet = struct {
//     PRIVATE: type,
//     PUBLIC: type,

//     pub inline fn same_type(comptime T: type) TypeSet {
//         return TypeSet{
//             .PRIVATE = T,
//             .PUBLIC = T,
//         };
//     }
//     pub inline fn private_public_type(comptime PRIVATE: type, comptime PUBLIC: type) TypeSet {
//         return TypeSet{
//             .PRIVATE = PRIVATE,
//             .PUBLIC = PUBLIC,
//         };
//     }
// };
// const OBSERVABLE_GENERIC_ID = "GOOLIB_OBSERVABLE";
// pub fn Observable(comptime TYPE_SET: TypeSet, comptime ACCESS: AccessFuncs(TYPE_SET), comptime NOTIFICATION: type) type {
//     return struct {
//         const Self = @This();
//         const ObserverIface = Observer(NOTIFICATION);
//         const ObserverList = ListSlice.ListFullDefinition(ObserverIface, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, .MANUAL_ALLOC);
//         const T_PRIVATE = TYPE_SET.PRIVATE;
//         const T_PUBLIC = TYPE_SET.PUBLIC;
//         pub const TYPE_ID_GENERIC = Type.get_string_id("GOOLIB_OBSERVABLE");
//         pub const TYPE_ID = Type.get_type_id(Self);

//         val: T_PRIVATE = undefined,
//         observers: ObserverList = .{},

//         pub inline fn new(initial_val: T_PUBLIC) Self {
//             var self = Self{};
//             self.set_no_notify(initial_val);
//             return self;
//         }

//         pub fn notify_then_delete(self: *Self, delete_notification: NOTIFICATION, alloc: Allocator) void {
//             for (self.observers.zig_slice_entire_const()) |observer| {
//                 observer.notify(delete_notification);
//             }
//             self.observers.free_if_non_zero(alloc);
//             self.* = .{};
//         }
//         pub fn notify_if_exists_then_delete(self: *Self, delete_notification: NOTIFICATION, alloc: Allocator) void {
//             for (self.observers.zig_slice_entire_const()) |observer| {
//                 observer.notify_if_exists(delete_notification);
//             }
//             self.observers.free_if_non_zero(alloc);
//             self.* = .{};
//         }
//         pub inline fn delete_no_notify(self: *Self, alloc: Allocator) void {
//             self.observers.free_if_non_zero(alloc);
//             self.* = .{};
//         }

//         const get_access = ACCESS.get;
//         pub fn get(self: Self) T_PUBLIC {
//             return get_access(self.val);
//         }
//         const get_ptr_access = ACCESS.get_ptr;
//         pub fn get_ptr(self: *Self) *T_PUBLIC {
//             return get_ptr_access(&self.val);
//         }
//         const get_const_ptr_access = ACCESS.get_const_ptr;
//         pub fn get_const_ptr(self: *const Self) *const T_PUBLIC {
//             return get_const_ptr_access(&self.val);
//         }

//         const set_access = ACCESS.set;
//         pub fn set_no_notify(self: *Self, val: T_PUBLIC) void {
//             set_access(&self.val, val);
//         }
//         pub fn set_then_notify(self: *Self, val: T_PUBLIC, notif: NOTIFICATION) void {
//             self.set_no_notify(val);
//             for (self.observers.zig_slice_entire_const()) |observer| {
//                 observer.notify(notif);
//             }
//         }
//         pub fn set_then_notify_if_exists(self: *Self, val: T_PUBLIC, notif: NOTIFICATION) void {
//             self.set_no_notify(val);
//             for (self.observers.zig_slice_entire_const()) |observer| {
//                 observer.notify_if_exists(notif);
//             }
//         }
//         pub fn set_then_notify_if_exists_report_all_exist(self: *Self, val: T_PUBLIC, notif: NOTIFICATION) bool {
//             self.set_no_notify(val);
//             var all_exist: bool = true;
//             for (self.observers.zig_slice_entire_const()) |observer| {
//                 all_exist = all_exist and observer.notify_if_exists_and_report_exists(notif);
//             }
//             return all_exist;
//         }

//         pub inline fn register_observer(self: *Self, observer: Observer, alloc: Allocator) void {
//             self.observers.append_one(observer, alloc);
//         }
//     };
// }

// pub fn DerivedObservables(comptime INPUT_STRUCT: type, comptime OUTPUT_STRUCT: type) type {
//     inline for (@typeInfo(INPUT_STRUCT).@"struct".field_types) |f_type| {
//         Type.assert_type_generic_id_matches(f_type, OBSERVABLE_GENERIC_ID);
//     }
//     inline for (@typeInfo(OUTPUT_STRUCT).@"struct".field_types) |f_type| {
//         Type.assert_type_generic_id_matches(f_type, OBSERVABLE_GENERIC_ID);
//     }
//     return struct {
//         const Self = @This();

//         upstream: *Observable(In),
//         downstream: Observable(Out),
//         transform_fn: *const fn (In) Out,

//         pub fn init(
//             allocator: std.mem.Allocator,
//             upstream: *Observable(In),
//             transform: *const fn (In) Out,
//         ) !*Self {
//             const self = try allocator.create(Self);
//             const initial_out = transform(upstream.get());

//             self.* = .{
//                 .upstream = upstream,
//                 .downstream = Observable(Out).init(allocator, initial_out),
//                 .transform_fn = transform,
//             };

//             // Register ourselves to the upstream observable
//             try upstream.subscribe(self.asObserver());
//             return self;
//         }

//         pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
//             self.downstream.deinit();
//             allocator.destroy(self);
//         }

//         /// Exposes an `Observer` interface so this node can observe other nodes.
//         pub fn asObserver(self: *Self) Observer {
//             return .{
//                 .ptr = self,
//                 .notify_fn = onNotify,
//             };
//         }

//         /// When upstream changes, recompute and update downstream.
//         fn onNotify(ctx: *anyopaque) void {
//             const self: *Self = @ptrCast(@alignCast(ctx));
//             const new_value = self.transform_fn(self.upstream.get());
//             self.downstream.set(new_value);
//         }

//         pub fn get(self: *const Self) Out {
//             return self.downstream.get();
//         }

//         pub fn subscribe(self: *Self, obs: Observer) !void {
//             try self.downstream.subscribe(obs);
//         }
//     };
// }
