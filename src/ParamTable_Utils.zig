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
const CalcInterface = ParamTable.Calc.CalcInterface;
const ParamType = ParamTable.Meta.ParamType;
const ParamId = ParamTable.Meta.ParamId;
const Table = ParamTable.Table;
const ParamFactorySlot = ParamTable.ParamFactorySlot;
const PTList = ParamTable.PTList;
const PTPtr = ParamTable.PTPtr;
const PTPtrOrNull = ParamTable.PTPtrOrNull;
const Metadata = ParamTable.Meta.Metadata;

// pub const InitUtilMode = enum(u8) {
//     exactly_equal_to,
//     f32_add_flat,
//     f32_add_percent_of,
//     f32_sub,
//     f32_sub_percent_of,
//     f32_mult,

//     f32_div,
//     f32_mult_a_add_b,
// };

// fn assert_param_type_is(ptype: ParamType, comptime need_ptype: ParamType, comptime src: std.builtin.SourceLocation) void {
//     assert_with_reason(ptype == need_ptype, src, "expected param_type `{s}`, got param_type `{s}`", .{ need_ptype.name(), ptype.name() });
// }
// // fn assert_param_is_type(id: ParamId, meta: Metadata, comptime t: ParamType, comptime src: std.builtin.SourceLocation) void {
// //     assert_with_reason(meta.is_type(t), src, "param_id `{d}` was not a `{s}`, got `{s}`", .{ id.id, t.name(), meta.param_type.name() });
// // }
// fn assert_type_has_TYPE_decl_and_get_type(comptime T: type) type {
//     assert_with_reason(Types.type_has_decl_with_type(T, "TYPE", type), @src(), "type `{T}` was not a `PTPtr(T)`, `PTPtrOrNull(T)`, or `PTList(T)` type (missing `pub const TYPE = T;`)", .{@typeName(field.type)});
//     const TT = field.type.TYPE;
//     return TT;
// }

// pub fn assert_real_type_and_param_type_match(comptime T: type, ptype: ParamType, comptime src: std.builtin.SourceLocation) void {
//     switch (T) {
//         u64 => {
//             assert_param_type_is(ptype, .U64, src);
//         },
//         i64 => {
//             assert_param_type_is(ptype, .I64, src);
//         },
//         f64 => {
//             assert_param_type_is(ptype, .F64, src);
//         },
//         u32 => {
//             assert_param_type_is(ptype, .U32, src);
//         },
//         i32 => {
//             assert_param_type_is(ptype, .I32, src);
//         },
//         f32 => {
//             assert_param_type_is(ptype, .F32, src);
//         },
//         u16 => {
//             assert_param_type_is(ptype, .U16, src);
//         },
//         i16 => {
//             assert_param_type_is(ptype, .I16, src);
//         },
//         f16 => {
//             assert_param_type_is(ptype, .F16, src);
//         },
//         u8 => {
//             assert_param_type_is(ptype, .U8, src);
//         },
//         i8 => {
//             assert_param_type_is(ptype, .I8, src);
//         },
//         bool => {
//             assert_param_type_is(ptype, .BOOL, src);
//         },
//         else => {
//             const TT = assert_type_has_TYPE_decl_and_get_type(T);
//             const PTP = PTPtr(TT);
//             const PTPN = PTPtrOrNull(TT);
//             const PTL = PTList(TT);
//             switch (f.type) {
//                 PTP => {
//                     assert_param_type_is(ptype, .PTR, src);
//                 },
//                 PTPN => {
//                     assert_param_type_is(ptype, .PTR_OR_NULL, src);
//                 },
//                 PTL => {
//                     assert_param_type_is(ptype, .LIST, src);
//                 },
//                 else => assert_unreachable(src, "ParamTable only supports the following types:\nbool, u8, i8, u16, i16, f16, u32, i32, f32, u64, i64, f64, PTPtr(T), PTPtrOrNull(T), or PTList(T)\ngot type {s}", .{@typeName(f.type)}),
//             }
//         },
//     }
// }
pub fn Params_T_Val(comptime T: type) type {
    return struct {
        val: T,
    };
}
pub fn Params_T_AB(comptime T: type) type {
    return struct {
        a: T,
        b: T,
    };
}
pub fn Params_T_ABC(comptime T: type) type {
    return struct {
        a: T,
        b: T,
        c: T,
    };
}
pub fn Params_T_ABCD(comptime T: type) type {
    return struct {
        a: T,
        b: T,
        c: T,
        d: T,
    };
}
pub fn Params_T_ABCDE(comptime T: type) type {
    return struct {
        a: T,
        b: T,
        c: T,
        d: T,
        e: T,
    };
}
pub fn Calc_A_plus_B(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_AB(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = in.a + in.b;
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
pub fn Calc_A_minus_B(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_AB(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = in.a - in.b;
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
pub fn Calc_A_plus_B_plus_C(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_ABC(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = in.a + in.b + in.c;
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
pub fn Calc_A_plus_B_minus_C(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_ABC(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = in.a + in.b - in.c;
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
pub fn Calc_A_plus___B_times_C(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_ABC(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = in.a + (in.b * in.c);
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
pub fn Calc_A_minus___B_times_C(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_ABC(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = in.a - (in.b * in.c);
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
pub fn Calc_A_plus_B_plus___C_times_D(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_ABCD(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = (in.a + in.b) + (in.c * in.d);
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
pub fn Calc_A_plus_B_minus___C_times_D(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_ABCD(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = (in.a + in.b) - (in.c * in.d);
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
pub fn Calc_A_plus_B_plus___C_times_D___plus_E(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_ABCDE(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = (in.a + in.b) + (in.c * in.d) + in.e;
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
pub fn Calc_A_plus_B_minus___C_times_D___minus_E(comptime T: type) ParamCalc {
    const IN_OBJ = Params_T_ABCDE(T);
    const OUT_OBJ = Params_T_Val(T);
    const P = struct {
        pub fn calc(iface: CalcInterface) void {
            const in = iface.get_all_inputs(IN_OBJ);
            var out = iface.get_outputs_uninit(OUT_OBJ);
            out.val = (in.a + in.b) - (in.c * in.d) - in.e;
            iface.commit_all_outputs(out);
        }
    };
    return P.calc;
}
