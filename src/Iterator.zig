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
const InterfaceSignature2 = Types.InterfaceSignature2;
const MethodDefinition2 = Types.MethodDefinition2;
const StaticFunctionDefinition = Types.StaticFunctionDefinition;

/// INTERFACE:
///   - `pub fn has_next(obj: OBJECT) bool`
///   - `pub fn next(obj: OBJECT) T`
///   - `pub fn next_ptr(obj: OBJECT) *T`
///   - `pub fn peek_next(obj: OBJECT) T`
///   - `pub fn peek_next_ptr(obj: OBJECT) *T`
///   - `pub fn has_prev(obj: OBJECT) bool`
///   - `pub fn prev(obj: OBJECT) T`
///   - `pub fn prev_ptr(obj: OBJECT) *T`
///   - `pub fn peek_prev(obj: OBJECT) T`
///   - `pub fn peek_prev_ptr(obj: OBJECT) *T`
pub fn Iterator(comptime T: type) type {
    return struct {
        const Signature = InterfaceSignature2{
            .interface_name = "Iterator",
            .methods = &.{
                MethodDefinition2.define_method("has_next", fn (*anyopaque) bool),
                MethodDefinition2.define_method("next", fn (*anyopaque) T),
                MethodDefinition2.define_method("next_ptr", fn (*anyopaque) *T),
                MethodDefinition2.define_method("peek_next", fn (*anyopaque) T),
                MethodDefinition2.define_method("peek_next_ptr", fn (*anyopaque) *T),
                MethodDefinition2.define_method("has_prev", fn (*anyopaque) bool),
                MethodDefinition2.define_method("prev", fn (*anyopaque) T),
                MethodDefinition2.define_method("prev_ptr", fn (*anyopaque) *T),
                MethodDefinition2.define_method("peek_prev", fn (*anyopaque) T),
                MethodDefinition2.define_method("peek_prev_ptr", fn (*anyopaque) *T),
            },
        };

        pub fn adapter(object: anytype) Adapter(@TypeOf(object)) {
            return Adapter(@TypeOf(object)){ ._obj = object };
        }

        pub fn Adapter(comptime OBJECT: type) type {
            return struct {
                const ADAPTER = @This();
                const BASE_TYPE = Signature.assert_type_fulfills_return_base_type(OBJECT, null);

                _obj: OBJECT,

                pub inline fn has_next(self: ADAPTER) bool {
                    return @call(.auto, @field(BASE_TYPE, "has_next"), .{self._obj});
                }
                pub inline fn next(self: ADAPTER) T {
                    return @call(.auto, @field(BASE_TYPE, "next"), .{self._obj});
                }
                pub inline fn next_ptr(self: ADAPTER) *T {
                    return @call(.auto, @field(BASE_TYPE, "next_ptr"), .{self._obj});
                }
                pub inline fn peek_next(self: ADAPTER) T {
                    return @call(.auto, @field(BASE_TYPE, "peek_next"), .{self._obj});
                }
                pub inline fn peek_next_ptr(self: ADAPTER) *T {
                    return @call(.auto, @field(BASE_TYPE, "peek_next_ptr"), .{self._obj});
                }

                pub inline fn has_prev(self: ADAPTER) bool {
                    return @call(.auto, @field(BASE_TYPE, "has_prev"), .{self._obj});
                }
                pub inline fn prev(self: ADAPTER) T {
                    return @call(.auto, @field(BASE_TYPE, "prev"), .{self._obj});
                }
                pub inline fn prev_ptr(self: ADAPTER) *T {
                    return @call(.auto, @field(BASE_TYPE, "prev_ptr"), .{self._obj});
                }
                pub inline fn peek_prev(self: ADAPTER) T {
                    return @call(.auto, @field(BASE_TYPE, "peek_prev"), .{self._obj});
                }
                pub inline fn peek_prev_ptr(self: ADAPTER) *T {
                    return @call(.auto, @field(BASE_TYPE, "peek_prev_ptr"), .{self._obj});
                }
            };
        }

        pub const Interface = struct {
            object: *anyopaque,
            vtable: *const VTable,

            pub const VTable = struct {
                has_next: *const fn (object: *anyopaque) bool = _not_implemented_bool,
                next: *const fn (object: *anyopaque) T = _not_implemented_val,
                next_ptr: *const fn (object: *anyopaque) *T = _not_implemented_ptr,
                peek_next: *const fn (object: *anyopaque) T = _not_implemented_val,
                peek_next_ptr: *const fn (object: *anyopaque) *T = _not_implemented_ptr,
                has_prev: *const fn (object: *anyopaque) bool = _not_implemented_bool,
                prev: *const fn (object: *anyopaque) T = _not_implemented_val,
                prev_ptr: *const fn (object: *anyopaque) *T = _not_implemented_ptr,
                peek_prev: *const fn (object: *anyopaque) T = _not_implemented_val,
                peek_prev_ptr: *const fn (object: *anyopaque) *T = _not_implemented_ptr,
            };

            fn _not_implemented_val(_: *anyopaque) T {
                @panic("not implemented");
            }
            fn _not_implemented_ptr(_: *anyopaque) *T {
                @panic("not implemented");
            }
            fn _not_implemented_void(_: *anyopaque) void {
                @panic("not implemented");
            }
            fn _not_implemented_bool(_: *anyopaque) bool {
                @panic("not implemented");
            }

            pub fn has_next(self: Interface) bool {
                return self.vtable.has_next(self.object);
            }
            pub fn next(self: Interface) T {
                return self.vtable.next(self.object);
            }
            pub fn next_ptr(self: Interface) *T {
                return self.vtable.next_ptr(self.object);
            }
            pub fn peek_next(self: Interface) T {
                return self.vtable.peek_next(self.object);
            }
            pub fn peek_next_ptr(self: Interface) *T {
                return self.vtable.peek_next_ptr(self.object);
            }

            pub fn has_prev(self: Interface) bool {
                return self.vtable.has_prev(self.object);
            }
            pub fn prev(self: Interface) T {
                return self.vtable.prev(self.object);
            }
            pub fn prev_ptr(self: Interface) *T {
                return self.vtable.prev_ptr(self.object);
            }
            pub fn peek_prev(self: Interface) T {
                return self.vtable.peek_prev(self.object);
            }
            pub fn peek_prev_ptr(self: Interface) *T {
                return self.vtable.peek_prev_ptr(self.object);
            }
        };
    };
}

test Iterator {
    const S = struct {
        count: u32,
        lim: u32,

        pub fn has_next(self: *const @This()) bool {
            return self.count < self.lim;
        }
        pub fn next(self: *@This()) u32 {
            const v = self.count;
            self.count += 1;
            return v;
        }
        pub fn next_ptr(_: *@This()) *u32 {
            unreachable;
        }
        pub fn peek_next(_: *@This()) u32 {
            unreachable;
        }
        pub fn peek_next_ptr(_: *@This()) *u32 {
            unreachable;
        }

        pub fn has_prev(_: *const @This()) bool {
            unreachable;
        }
        pub fn prev(_: *@This()) u32 {
            unreachable;
        }
        pub fn prev_ptr(_: *@This()) *u32 {
            unreachable;
        }
        pub fn peek_prev(_: *@This()) u32 {
            unreachable;
        }
        pub fn peek_prev_ptr(_: *@This()) *u32 {
            unreachable;
        }

        fn next_impl(obj: *anyopaque) u32 {
            const self: *@This() = @ptrCast(@alignCast(obj));
            return self.next();
        }
        fn has_next_impl(obj: *anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(obj));
            return self.has_next();
        }
    };

    var s = S{
        .count = 0,
        .lim = 10,
    };
    var n: u32 = 0;
    const I = Iterator(u32);
    const II = I.Interface;
    const VT = I.Interface.VTable{
        .next = S.next_impl,
        .has_next = S.has_next_impl,
    };
    const i = I.Interface{
        .object = @ptrCast(&s),
        .vtable = &VT,
    };
    const A = I.Adapter(*S);
    const a = A{ ._obj = &s };
    while (a.has_next()) {
        _ = a.next();
        n += 1;
    }
    try Root.Testing.expect_equal_src(n, s.lim, @src(), "", .{});
    try Root.Testing.expect_equal_src(s.count, s.lim, @src(), "", .{});
    s.count = 0;
    n = 0;
    const AA = I.Adapter(II);
    const aa = AA{ ._obj = i };
    while (aa.has_next()) {
        _ = aa.next();
        n += 1;
    }
    try Root.Testing.expect_equal_src(n, s.lim, @src(), "", .{});
    try Root.Testing.expect_equal_src(s.count, s.lim, @src(), "", .{});
}
