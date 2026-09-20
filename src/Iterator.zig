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
const Root = @import("./_root.zig");
const Assert = Root.Assert;

const Types = Root.Types;
const InterfaceSignature = Types.InterfaceSignature;
const NamedFuncDefinition = Types.NamedFuncDefinition;

/// INTERFACE:
///   - `pub fn next(obj: OBJECT) T`
///   - `pub fn next_ptr(obj: OBJECT) *T`
///   - `pub fn has_next(obj: OBJECT) bool`
///   - `pub fn prev(obj: OBJECT) T`
///   - `pub fn prev_ptr(obj: OBJECT) *T`
///   - `pub fn has_prev(obj: OBJECT) bool`
///   - `pub fn save_state(obj: OBJECT, state_id: u8) void`
///   - `pub fn load_state(obj: OBJECT, state_id: u8) void`
pub fn Iterator(comptime T: type) type {
    return struct {
        fn ValFuncBuilder(comptime OBJ: type) type {
            return fn (OBJ) T;
        }
        fn PtrFuncBuilder(comptime OBJ: type) type {
            return fn (OBJ) *T;
        }
        fn BoolFuncBuilder(comptime OBJ: type) type {
            return fn (OBJ) bool;
        }
        fn StateFuncBuilder(comptime OBJ: type) type {
            return fn (OBJ, u8) void;
        }

        const Signature = InterfaceSignature{
            .interface_name = "Iterator",
            .functions = &.{
                NamedFuncDefinition.define_func_with_builder(
                    "next",
                    ValFuncBuilder,
                ),
                NamedFuncDefinition.define_func_with_builder(
                    "next_ptr",
                    PtrFuncBuilder,
                ),
                NamedFuncDefinition.define_func_with_builder(
                    "has_next",
                    BoolFuncBuilder,
                ),
                NamedFuncDefinition.define_func_with_builder(
                    "prev",
                    ValFuncBuilder,
                ),
                NamedFuncDefinition.define_func_with_builder(
                    "prev_ptr",
                    PtrFuncBuilder,
                ),
                NamedFuncDefinition.define_func_with_builder(
                    "has_prev",
                    BoolFuncBuilder,
                ),
                NamedFuncDefinition.define_func_with_builder(
                    "save_state",
                    StateFuncBuilder,
                ),
                NamedFuncDefinition.define_func_with_builder(
                    "load_state",
                    StateFuncBuilder,
                ),
            },
        };

        pub fn adapter(object: anytype) Adapter(@TypeOf(object)) {
            return Adapter(@TypeOf(object)){ ._obj = object };
        }

        pub fn Adapter(comptime OBJECT: type) type {
            Signature.assert_type_fulfills(OBJECT, @src());
            return struct {
                const ADAPTER = @This();

                _obj: OBJECT,

                pub inline fn next(self: ADAPTER) T {
                    return @field(OBJECT, "next")(self._obj);
                }
                pub inline fn next_ptr(self: ADAPTER) *T {
                    return @field(OBJECT, "next_ptr")(self._obj);
                }
                pub inline fn has_next(self: ADAPTER) bool {
                    return @field(OBJECT, "has_next")(self._obj);
                }
                pub inline fn prev(self: ADAPTER) T {
                    return @field(OBJECT, "prev")(self._obj);
                }
                pub inline fn prev_ptr(self: ADAPTER) *T {
                    return @field(OBJECT, "prev_ptr")(self._obj);
                }
                pub inline fn has_prev(self: ADAPTER) bool {
                    return @field(OBJECT, "has_prev")(self._obj);
                }
                pub inline fn save_state(self: ADAPTER, state_id: u8) void {
                    return @field(OBJECT, "save_state")(self._obj, state_id);
                }
                pub inline fn load_state(self: ADAPTER, state_id: u8) void {
                    return @field(OBJECT, "load_state")(self._obj, state_id);
                }
            };
        }

        pub const Interface = struct {
            object: *anyopaque,
            vtable: *const VTable,

            pub const VTable = struct {
                next: *const fn (object: *anyopaque) T = _not_implemented_val,
                next_ptr: *const fn (object: *anyopaque) *T = _not_implemented_ptr,
                has_next: *const fn (object: *anyopaque) bool = _not_implemented_bool,
                prev: *const fn (object: *anyopaque) T = _not_implemented_val,
                prev_ptr: *const fn (object: *anyopaque) *T = _not_implemented_ptr,
                has_prev: *const fn (object: *anyopaque) bool = _not_implemented_bool,
                save_state: *const fn (object: *anyopaque, state_id: u8) anyerror!void = _not_implemented_save_load,
                load_state: *const fn (object: *anyopaque, state_id: u8) anyerror!void = _not_implemented_save_load,
            };

            fn _not_implemented_val(object: *anyopaque) T {
                _ = object;
                @panic("not implemented");
            }
            fn _not_implemented_ptr(object: *anyopaque) *T {
                _ = object;
                @panic("not implemented");
            }
            fn _not_implemented_void(object: *anyopaque) void {
                _ = object;
                @panic("not implemented");
            }
            fn _not_implemented_bool(object: *anyopaque) bool {
                _ = object;
                @panic("not implemented");
            }
            fn _not_implemented_save_load(object: *anyopaque, state_id: u8) anyerror!void {
                _ = object;
                _ = state_id;
                @panic("not implemented");
            }

            pub inline fn next(self: Interface) T {
                return self.vtable.next(self.object);
            }
            pub inline fn next_ptr(self: Interface) *T {
                return self.vtable.next_ptr(self.object);
            }
            pub inline fn has_next(self: Interface) bool {
                return self.vtable.has_next(self.object);
            }
            pub inline fn prev(self: Interface) T {
                return self.vtable.prev(self.object);
            }
            pub inline fn prev_ptr(self: Interface) *T {
                return self.vtable.prev_ptr(self.object);
            }
            pub inline fn has_prev(self: Interface) bool {
                return self.vtable.has_prev(self.object);
            }
            pub inline fn save_state(self: Interface, state_id: u8) void {
                return self.vtable.save_state(self.object, state_id);
            }
            pub inline fn load_state(self: Interface, state_id: u8) void {
                return self.vtable.load_state(self.object, state_id);
            }
        };
    };
}
