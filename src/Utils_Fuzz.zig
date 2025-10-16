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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const build = @import("builtin");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const fmt = std.fmt;
const Random = std.Random;

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const Fuzz = Root.Fuzz;

pub const Utils_quick_hex_dec_u64 = make_quick_dec_hex_fuzzer(u64);

pub fn make_quick_dec_hex_fuzzer(comptime T: type) Fuzz.FuzzTest {
    const PROTO = struct {
        fn check_round_trip(rand: Random, _: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
            const val = rand.int(u64);
            const bytes1 = Utils.quick_hex(val);
            const trip_1 = Utils.quick_unhex(bytes1[0..], u64);
            if (val != trip_1) return Utils.alloc_fail_str(alloc, @src(), "val -> quick_hex -> quick_unhex failed:\n{d} -> {s} -> {d}", .{ val, bytes1, trip_1 });
            const bytes2 = Utils.quick_dec(val);
            const trip_2 = Utils.quick_undec(bytes2.bytes(), u64);
            if (val != trip_2) return Utils.alloc_fail_str(alloc, @src(), "val -> quick_dec -> quick_undec failed:\n{d} -> {s} -> {d}", .{ val, bytes2.bytes(), trip_2 });
            return null;
        }
        const STATE = struct {
            none: bool,
        };
        pub fn INIT(_: **anyopaque, _: Allocator) anyerror!void {
            return;
        }
        pub fn START_SEED(_: Random, _: *anyopaque, _: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
            return null;
        }

        pub fn DEINIT(_: *anyopaque, _: Allocator) void {
            return;
        }

        pub const OPS = [_]*const fn (rand: Random, state_opaque: *anyopaque, alloc: Allocator, bench_time: *Fuzz.BenchTime) ?[]const u8{
            check_round_trip,
        };
    };
    return Fuzz.FuzzTest{
        .options = Fuzz.FuzzOptions{
            .name = "Utils_quick_hex_dec_" ++ @typeName(T),
            .min_ops_per_seed = 1000,
            .max_ops_per_seed = 1000,
        },
        .init_func = PROTO.INIT,
        .start_seed_func = PROTO.START_SEED,
        .op_table = PROTO.OPS[0..],
        .deinit_func = PROTO.DEINIT,
    };
}
