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
const Time = Root.Time;
const Secs = Time.Secs;
const Assert = Root.Assert;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Utils = Root.Utils;
const _Flags = Root.Flags;
const File = std.fs.File;
const Writer = std.Io.Writer;
const Prng = std.Random.DefaultPrng;
const FixedAlloc = std.heap.FixedBufferAllocator;
const Random = std.Random;
const ErrList = std.ArrayList(anyerror);
const TestList = std.ArrayList(FuzzTest);
const StrList = std.ArrayList([]const u8);

pub var FUZZ_CACHE_DIR: []const u8 = ".zig-fuzz-goolib";
const EXT = ".seeds";
const SEP = std.fs.path.sep;
const NEWLINE: u8 = "\n";
const FILE_OP_COUNT: u8 = '#';
const FUZZ_BATCH_HEADER_ = "~~~~~~BEGINNING FUZZ TESTS~~~~~~   TIME:    15s  30s  45s  60s  75s  90s  105s 120s 135s 150s 165s 180s";
const FUZZ_BATCH_INTERLD = "                                   TIME:    15s  30s  45s  60s  75s  90s  105s 120s 135s 150s 165s 180s";
const FUZZ_LINE_TEMPLATE = "┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┨     :    :    :    :    :    :    :    :    :    :    :    : ┃";
const FUZZ_BATCH_FOOTER_ = "~~~~~~FUZZ TESTS COMPLETE~~~~~~~   TIME:    15s  30s  45s  60s  75s  90s  105s 120s 135s 150s 165s 180s";

pub const FuzzSeed = struct {
    seed: u64 = 0,
    prng: Prng = .{ .s = @splat(0) },

    pub fn new() FuzzSeed {
        var new_inputs = FuzzSeed{};
        new_inputs.rand_seed();
        return new_inputs;
    }
    pub fn rand_seed(self: *FuzzSeed) void {
        std.posix.getrandom(std.mem.asBytes(&self.seed)) catch {
            const nseed: u128 = @bitCast(std.time.nanoTimestamp());
            self.seed = @as(u64, @intCast(nseed & 0xFFFFFFFFFFFFFFFF));
        };
        self.prng = Prng.init(self.seed);
    }
    pub fn set_seed(self: *FuzzSeed, seed: u64) void {
        self.seed = seed;
        self.prng = Prng.init(self.seed);
    }
};

pub const FuzzOptions = struct {
    name: []const u8 = "<none>",
    max_failures: u64 = 1,
    min_ops_per_seed: u64 = 10,
    max_ops_per_seed: u64 = 100,
};

pub const FuzzTest = struct {
    options: FuzzOptions,
    init_func: *const fn (rand: Random, state_opq: OpaqueState, alloc: Allocator) ?anyerror = noop_init,
    op_table: []const *const fn (rand: Random, state_opq: OpaqueState, alloc: Allocator) ?anyerror = noop_table[0..0],
    deinit_func: *const fn (state_opq: OpaqueState, alloc: Allocator) void = noop_deinit,
};

fn noop_init(rand: Random, state_opq: OpaqueState, alloc: Allocator) ?anyerror {
    _ = rand;
    _ = state_opq;
    _ = alloc;
    return null;
}

fn noop_deinit(state_opq: OpaqueState, alloc: Allocator) void {
    _ = state_opq;
    _ = alloc;
}

const noop_table: [0]*const fn (rand: Random, state_opq: OpaqueState, alloc: Allocator) ?anyerror = undefined;

pub const OpaqueState = struct {
    pub fn OPENED(comptime REF_OBJ: type, comptime TEST_OBJ: type, comptime AUX_STATE: type) type {
        return *CONCRETE(REF_OBJ, TEST_OBJ, AUX_STATE);
    }
    pub fn CONCRETE(comptime REF_OBJ: type, comptime TEST_OBJ: type, comptime AUX_STATE: type) type {
        return struct {
            ref_obj: REF_OBJ,
            test_obj: TEST_OBJ,
            aux_state: AUX_STATE,
        };
    }

    pub fn open(state_opq: *anyopaque, comptime REF_OBJ: type, comptime TEST_OBJ: type, comptime AUX_STATE: type) OPENED(REF_OBJ, TEST_OBJ, AUX_STATE) {
        return @ptrCast(@alignCast(state_opq));
    }
};

pub const DiffFuzzer = struct {
    const Self = @This();
    state_opq: *anyopaque = undefined,
    fuzz_seed: FuzzSeed = undefined,
    fail_count: u64 = 0,
    seeds_file: File = undefined,
    err_list: ErrList = undefined,
    test_list: []const FuzzTest = undefined,
    next_sec: Time.MSecs = undefined,
    end_time: Time.MSecs = undefined,
    block_num: u8 = 0,
    first_block: bool = true,
    is_init: bool = false,
    name: []const u8 = "<none>",
    duration: Secs = Secs.new(10),
    max_failures: u64 = 5,
    one_seed: ?u64 = null,
    min_ops_per_seed: u64 = 10,
    max_ops_per_seed: u64 = 100,
    total: u64 = 0,
    pass: u64 = 0,
    fail: u64 = 0,
    alloc: Allocator,
    pass_list: StrList,
    fail_list: StrList,
    fail_reason: StrList,
    console: File,
    init_func: *const fn (rand: Random, state_opq: OpaqueState, alloc: Allocator) ?anyerror = noop_init,
    op_table: []const *const fn (rand: Random, state_opq: OpaqueState, alloc: Allocator) ?anyerror = noop_table[0..0],
    deinit_func: *const fn (state_opq: OpaqueState, alloc: Allocator) void = noop_deinit,

    pub fn init(alloc: Allocator, test_list: []const FuzzTest) anyerror!Self {
        return Self{
            .alloc = alloc,
            .pass_list = try StrList.initCapacity(alloc, test_list.len),
            .fail_list = try StrList.initCapacity(alloc, test_list.len),
            .fail_reason = try StrList.initCapacity(alloc, test_list.len),
            .console = std.fs.File.stdout(),
            .err_list = try ErrList.initCapacity(alloc, 8),
            .test_list = test_list,
        };
    }

    pub fn deinit(self: *Self) void {
        self.pass_list.deinit(self.alloc);
        self.fail_list.deinit(self.alloc);
        self.fail_reason.deinit(self.alloc);
        self.err_list.deinit(self.alloc);
    }

    pub fn fuzz_all(self: *Self) anyerror!void {
        for (self.test_list) |t| {
            try self.fuzz(t);
        }
    }

    pub fn fuzz(self: *Self, fuzz_test: FuzzTest) anyerror!void {
        self.init_func = fuzz_test.init_func;
        self.op_table = fuzz_test.op_table;
        self.deinit_func = fuzz_test.deinit_func;
        self.name = fuzz_test.options.name;
        self.max_failures = fuzz_test.options.max_failures;
        self.min_ops_per_seed = fuzz_test.options.min_ops_per_seed;
        self.max_ops_per_seed = fuzz_test.options.max_ops_per_seed;
        defer self.deinit_func(self.state_opq, self.alloc);
        defer self.err_list.clearRetainingCapacity();
        self.next_sec = Time.MSecs.now();
        self.end_time = self.next_sec.add(self.duration.to_msecs());
        self.next_sec = self.next_sec.add(.new(1000));
        _ = try self.console.write("\n");
        _ = try self.console.write(FUZZ_LINE_TEMPLATE);
        _ = try self.console.write("\x1b[1G");
        _ = try self.console.write(self.name);
        _ = try self.console.write("\x1b[1G\x1b[40C");
        const cwd = std.fs.cwd();
        var path_buf: [128]u8 = undefined;
        var path_writer = Root.QuickWriter.writer(path_buf[0..]);
        _ = try path_writer.write(FUZZ_CACHE_DIR);
        try cwd.makePath(path_writer.buffered());
        _ = try path_writer.writeByte(SEP);
        _ = try path_writer.write(self.name);
        _ = try path_writer.write(EXT);
        self.seeds_file = try cwd.createFile(path_writer.buffered(), .{
            .truncate = false,
            .read = true,
        });
        defer self.seeds_file.close();
        var line_buf: [32]u8 = undefined;
        var line_bytes = try self.seeds_file.read(line_buf[0..32]);
        var seed: u64 = undefined;
        var count: u64 = undefined;
        var more: bool = true;
        self.first_block = true;
        self.block_num = 0;
        while (more and line_bytes == 32) {
            seed = Utils.quick_unhex(line_buf[0..16], u64);
            count = Utils.quick_unhex(line_buf[16..32], u64);
            more = try self._run_seed(seed, true, count);
            try discard_until_newline(self.seeds_file);
            line_bytes = try self.seeds_file.read(line_buf[0..32]);
            more = more and try self._check_time();
        }
        while (more) {
            self.fuzz_seed.rand_seed();
            seed = self.fuzz_seed.seed;
            more = try self._run_seed(seed, false, 0);
            more = more and try self._check_time();
        }
    }

    fn _add_pass(self: *Self, name: []const u8) anyerror!void {
        try self.pass_list.append(self.alloc, name);
        self.total += 1;
        self.pass += 1;
    }

    fn _add_fail(self: *Self, name: []const u8, reason: []const u8) anyerror!void {
        try self.fail_list.append(self.alloc, name);
        try self.fail_reason.append(self.alloc, reason);
        self.total += 1;
        self.fail += 1;
    }

    fn _print_success(self: *Self, name: []const u8) anyerror!void {
        _ = try self.console.write("\x1b[1G\x1b[32m┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈\x1b[0m");
        _ = try self.console.write("\x1b[1G\x1b[32m");
        _ = try self.console.write(name);
        _ = try self.console.write("\x1b[0m\n");
    }

    fn _print_failure(self: *Self, name: []const u8) anyerror!void {
        _ = try self.console.write("\x1b[1G\x1b[31m┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈\x1b[0m");
        _ = try self.console.write("\x1b[1G\x1b[31m");
        _ = try self.console.write(name);
        _ = try self.console.write("\x1b[0m\n");
    }

    pub fn print_header(self: *Self) anyerror!void {
        _ = try self.console.write("\x1b[?25l");
        _ = try self.console.write(FUZZ_BATCH_HEADER_);
    }
    pub fn print_footer(self: *Self) anyerror!void {
        _ = try self.console.write(FUZZ_BATCH_FOOTER_);
        _ = try self.console.write("\n");
        var num: Utils.QuickDecResult = undefined;
        if (self.pass > 0) {
            _ = try self.console.write("\x1b[32mSUCCESS: ");
            num = Utils.quick_dec(self.pass);
            _ = try self.console.write(num.bytes());
            _ = try self.console.write(" / ");
            num = Utils.quick_dec(self.total);
            _ = try self.console.write(num.bytes());
            for (self.pass_list.items) |pass_name| {
                _ = try self.console.write("\n  ✓ ");
                _ = try self.console.write(pass_name);
            }
            _ = try self.console.write("\x1b[0m\n");
        }
        if (self.fail > 0) {
            _ = try self.console.write("\x1b[31mFAILURE: ");
            num = Utils.quick_dec(self.fail);
            _ = try self.console.write(num.bytes());
            _ = try self.console.write(" / ");
            num = Utils.quick_dec(self.total);
            _ = try self.console.write(num.bytes());
            var i: usize = 0;
            while (i < self.fail_list.items.len) {
                const fail_name = self.fail_list.items[i];
                const fail_reason = self.fail_reason.items[i];
                _ = try self.console.write("\n  X ");
                _ = try self.console.write(fail_name);
                _ = try self.console.write(": ");
                _ = try self.console.write(fail_reason);
                i += 1;
            }
            _ = try self.console.write("\x1b[0m\n");
        }
        if (self.pass == self.total) {
            _ = try self.console.write("\x1b[0;32mALL TESTS PASS!\x1b[0m");
        }
        _ = try self.console.write("\x1b[?25h\n");
    }

    pub fn _check_time(self: *Self) anyerror!bool {
        const now = Time.MSecs.now();
        if (now.val >= self.next_sec.val) {
            switch (self.block_num) {
                0 => {
                    if (self.first_block) {
                        self.first_block = false;
                        _ = try self.console.write("▍");
                    } else {
                        _ = try self.console.write("\x1b[1D▒▍");
                    }
                    self.block_num = 1;
                },
                1 => {
                    _ = try self.console.write("\x1b[1D▊");
                    self.block_num = 2;
                },
                2 => {
                    _ = try self.console.write("\x1b[1D█");
                    self.block_num = 0;
                },
                else => unreachable,
            }
            self.next_sec = self.next_sec.add(.new(1000));
        }
        if (now.val >= self.end_time.val) {
            if (self.fail_count > 0) {
                try self._print_failure(self.name);
                return false;
            }
            try self._add_pass(self.name);
            try self._print_success(self.name);
            return false;
        }
        return true;
    }

    fn _run_seed(self: *Self, seed: u64, comptime from_file: bool, file_min: u64) anyerror!bool {
        var seed_result: SeedResult = undefined;
        self.fuzz_seed.set_seed(seed);
        seed_result = run: {
            var random = self.fuzz_seed.prng.random();
            var result = SeedResult{};
            result.err = self.init_func(random, self.state_opq, self.alloc);
            if (result.err != null) {
                break :run result;
            }
            const total_ops = @max(self.min_ops_per_seed, random.uintAtMost(u64, self.max_ops_per_seed), file_min);
            while (result.op_count < total_ops) {
                result.op_count += 1;
                const op_idx = random.uintLessThan(usize, self.op_table.len);
                result.err = self.op_table[op_idx](random, self.state_opq, self.alloc);
                if (result.err != null) {
                    break :run result;
                }
            }
            break :run result;
        };
        if (seed_result.err) |err| {
            try self.err_list.append(self.alloc, err);
            self.fail_count += 1;
            if (from_file) {
                if (seed_result.op_count > file_min) {
                    const new_count = Utils.quick_hex(seed_result.op_count);
                    try self.seeds_file.seekBy(-16);
                    _ = try self.seeds_file.write(new_count[0..16]);
                }
            } else {
                const seed_hex = Utils.quick_hex(seed);
                const count_hex = Utils.quick_hex(seed_result.op_count);
                _ = try self.seeds_file.write(seed_hex[0..16]);
                _ = try self.seeds_file.write(count_hex[0..16]);
                _ = try self.seeds_file.write("\n");
            }
            try self._add_fail(self.name, @errorName(err));
            if (self.fail_count >= self.max_failures) {
                try self._print_failure(self.name);
                return false;
            }
        }
        return true;
    }
};

pub const SeedResult = struct {
    op_count: u64 = 0,
    err: ?anyerror = null,
};

pub fn discard_until_newline(file: File) anyerror!void {
    var b: [1]u8 = .{1};
    while (b[0] != '\n' and b[0] != '\r') {
        const n = try file.read(b[0..1]);
        if (n == 0) {
            return;
        }
        if (b[0] == '\r') {
            _ = try file.read(b[0..1]);
        }
    }
    return;
}
