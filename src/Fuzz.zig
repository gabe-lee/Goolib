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
const build = @import("builtin");
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
const LineList = std.ArrayList(SeedLine);
const FailList = std.ArrayList(SeedFailure);
const U8List = std.ArrayList(u8);
const Atomic = std.atomic;
const Thread = std.Thread;

pub var FUZZ_CACHE_DIR: []const u8 = ".zig-fuzz-goolib";
const EXT = ".seeds";
const SEP = std.fs.path.sep;
const NEWLINE: u8 = "\n";
const FILE_OP_COUNT: u8 = '#';
const FUZZ_BATCH_HEADER_ = "~~~~~~BEGINNING FUZZ TESTS~~~~~~   TIME:    15s  30s  45s  60s  75s  90s  105s 120s 135s 150s 165s 180s SEEDS      OPS";
const FUZZ_BATCH_INTERLD = "                                   TIME:    15s  30s  45s  60s  75s  90s  105s 120s 135s 150s 165s 180s SEEDS      OPS";
const FUZZ_LINE_TEMPLATE = "┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┨     :    :    :    :    :    :    :    :    :    :    :    : ┃";
const FUZZ_BATCH_FOOTER_ = "~~~~~~FUZZ TESTS COMPLETE~~~~~~~   TIME:    15s  30s  45s  60s  75s  90s  105s 120s 135s 150s 165s 180s SEEDS      OPS";
const DEFAULT_SECS = 10;
const LINES_BEFORE_INTERLUDE = 10;
pub const MAX_THREAD_COUNT = 8;

const Atom = Atomic.Value(usize);

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
    pub fn rand_seed_domain(self: *FuzzSeed, thread_num: u64, thread_total: u64) void {
        const PER_THREAD = math.maxInt(u64) / thread_total;
        std.posix.getrandom(std.mem.asBytes(&self.seed)) catch {
            const nseed: u128 = @bitCast(std.time.nanoTimestamp());
            self.seed = @as(u64, @intCast(nseed & 0xFFFFFFFFFFFFFFFF));
            self.seed = self.seed % PER_THREAD;
            self.seed = self.seed + (thread_num * PER_THREAD);
        };
        self.prng = Prng.init(self.seed);
    }
};

pub const FuzzOptions = struct {
    name: []const u8 = "<none>",
    min_ops_per_seed: u64 = 10,
    max_ops_per_seed: u64 = 100,
};

pub const FuzzTest = struct {
    options: FuzzOptions,
    /// Run once at the beginning of every fuzz test, usually used to instantiate the objects to be tested
    /// on the stack/heap using the provided allocator
    init_func: *const fn (state_opq: **anyopaque, alloc: Allocator) anyerror!void = noop_init,
    /// Run once at the beginning of every seed, usually used to reset the test objects and fill them with new values
    /// as a starting point for the seed
    start_seed_func: *const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8 = noop_start_seed,
    /// A table of operations to randomly select to perform on the test objects
    op_table: []const *const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8 = noop_table[0..0],
    /// Run once at the end of every fuzz test, used to deallocate/deinit any resources created during the fuzz test,
    /// including those created during the init function
    deinit_func: *const fn (state_opq: *anyopaque, alloc: Allocator) void = noop_deinit,
};

fn noop_start_seed(rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8 {
    _ = rand;
    _ = state_opq;
    _ = alloc;
    return null;
}

fn noop_init(state_opq: **anyopaque, alloc: Allocator) anyerror!void {
    _ = state_opq;
    _ = alloc;
}

fn noop_deinit(state_opq: *anyopaque, alloc: Allocator) void {
    _ = state_opq;
    _ = alloc;
}

fn noop_op(rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8 {
    _ = rand;
    _ = state_opq;
    _ = alloc;
    return null;
}

fn fail_op(rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8 {
    _ = rand;
    _ = state_opq;
    return std.fmt.allocPrint(alloc, "this test always fails", .{}) catch |err| return @errorName(err);
}

pub const SeedFailure = struct {
    seed: u64 = 0,
    count: u64 = 0,
    reason: []const u8,
};

const SeedLine = struct {
    line: []const u8,
    seed: u64,
    count: u64,
    pos: u64,
};

const noop_table: [1]*const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8 = .{noop_op};
const fail_table: [1]*const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8 = .{fail_op};

pub const DiffFuzzer = struct {
    const Self = @This();
    thread_count: u64 = undefined,
    states: [MAX_THREAD_COUNT]*anyopaque = undefined,
    seeds: [MAX_THREAD_COUNT]FuzzSeed = undefined,
    seed_fails: [MAX_THREAD_COUNT]?SeedFailure = undefined,
    total_ops: [MAX_THREAD_COUNT]u64 = undefined,
    total_seeds: [MAX_THREAD_COUNT]u64 = undefined,
    all_total_ops: u64 = 0,
    all_total_seeds: u64 = 0,
    seeds_file: File = undefined,
    test_list: []const FuzzTest = undefined,
    next_sec: Time.MSecs = undefined,
    end_time: Time.MSecs = undefined,
    block_num: u8 = 0,
    first_block: bool = true,
    name: []const u8 = "<none>",
    duration: Secs = Secs.new(15),
    one_seed: ?u64 = null,
    nops: ?u64 = null,
    one_test: ?[]const u8 = null,
    min_ops_per_seed: u64 = 10,
    max_ops_per_seed: u64 = 100,
    total_fuzzes: u64 = 0,
    total_pass: u64 = 0,
    total_fail: u64 = 0,
    alloc: Allocator,
    fail_list: StrList,
    fail_details: FailList,
    console: File,
    stop_fuzz: Atom = Atom.init(0),
    threads_done: Atom = Atom.init(0),
    seed_file_string: U8List,
    seed_file_list: LineList,
    init_func: *const fn (state_opq: **anyopaque, alloc: Allocator) anyerror!void = noop_init,
    start_seed_func: *const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8 = noop_start_seed,
    op_table: []const *const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8 = noop_table[0..0],
    deinit_func: *const fn (state_opq: *anyopaque, alloc: Allocator) void = noop_deinit,

    pub fn init(args: std.process.ArgIterator, alloc: Allocator, thread_count: u64, test_list: []const FuzzTest) anyerror!Self {
        var secs: ?u64 = null;
        var seed: ?u64 = null;
        var name: ?[]const u8 = null;
        var nops: ?u64 = null;
        var args_ = args;
        _ = args_.next();
        while (args_.next()) |arg| {
            if (arg.len < 7) std.debug.panic("invalid option `{s}`", .{arg});
            if (arg[0] != '-') std.debug.panic("invalid option `{s}`", .{arg});
            if (arg[5] != '=') std.debug.panic("invalid option `{s}`", .{arg});
            const key = arg[1..5];
            const val = arg[6..];
            if (std.mem.eql(u8, key, "secs")) {
                secs = Utils.quick_undec(val, u64);
            } else if (std.mem.eql(u8, key, "seed")) {
                if (val.len < 32) std.debug.panic("invalid option (seed must be 32 chars of hexidecimal) `{s}`", .{arg});
                seed = Utils.quick_unhex(val[0..16], u64);
                nops = Utils.quick_unhex(val[16..32], u64);
            } else if (std.mem.eql(u8, key, "name")) {
                name = val;
            } else {
                std.debug.panic("invalid option `{s}`", .{arg});
            }
        }
        var s = Self{
            .alloc = alloc,
            .thread_count = @max(@min(thread_count, Thread.getCpuCount() catch 1), 1),
            .fail_list = try StrList.initCapacity(alloc, test_list.len),
            .fail_details = try FailList.initCapacity(alloc, test_list.len),
            .seed_file_string = try U8List.initCapacity(alloc, 512),
            .seed_file_list = try LineList.initCapacity(alloc, 10),
            .console = std.fs.File.stdout(),
            .test_list = test_list,
        };
        s.one_seed = seed;
        s.one_test = name;
        secs = secs orelse DEFAULT_SECS;
        s.nops = nops;
        s.duration = Time.Secs.new(@intCast(secs.?));
        return s;
    }

    pub fn deinit(self: *Self) void {
        self.fail_list.deinit(self.alloc);
        self.fail_details.deinit(self.alloc);
        self.seed_file_list.deinit(self.alloc);
        self.seed_file_string.deinit(self.alloc);
    }

    pub fn fuzz_all(self: *Self) anyerror!void {
        try self.print_header();
        var i: usize = 0;
        for (self.test_list) |t| {
            if (self.one_test) |test_name| {
                if (std.mem.eql(u8, t.options.name, test_name)) {
                    try self.fuzz(t);
                    break;
                }
            } else {
                if (i >= LINES_BEFORE_INTERLUDE) {
                    i = 0;
                    try self.print_interlude();
                }
                try self.fuzz(t);
                i += 1;
            }
        }
        try self.print_footer();
    }

    fn do_inits(self: *Self) anyerror!void {
        var i: u64 = 0;
        while (i < self.thread_count) {
            try self.init_func(&self.states[i], self.alloc);
            i += 1;
        }
    }
    fn do_deinits(self: *Self) void {
        var i: u64 = 0;
        while (i < self.thread_count) {
            self.deinit_func(self.states[i], self.alloc);
            i += 1;
        }
    }

    pub fn fuzz(self: *Self, fuzz_test: FuzzTest) anyerror!void {
        self.init_func = fuzz_test.init_func;
        self.start_seed_func = fuzz_test.start_seed_func;
        self.op_table = fuzz_test.op_table;
        self.deinit_func = fuzz_test.deinit_func;
        self.name = fuzz_test.options.name;
        self.min_ops_per_seed = fuzz_test.options.min_ops_per_seed;
        self.max_ops_per_seed = fuzz_test.options.max_ops_per_seed;
        self.next_sec = Time.MSecs.now();
        self.end_time = self.next_sec.add(self.duration.to_msecs());
        self.next_sec = self.next_sec.add(.new(1000));
        self.total_seeds = @splat(0);
        self.total_ops = @splat(0);
        self.seed_fails = @splat(null);
        self.threads_done = Atom.init(0);
        self.stop_fuzz = Atom.init(0);
        self.all_total_seeds = 0;
        self.all_total_ops = 0;
        var i: u64 = 0;
        try self.do_inits();
        defer self.do_deinits();
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
        _ = try self.seeds_file.write(self.name);
        self.seed_file_string.clearRetainingCapacity();
        const seeds_file_stat = try self.seeds_file.stat();
        try self.seed_file_string.ensureTotalCapacity(self.alloc, @intCast(seeds_file_stat.size));
        self.seed_file_string.items.len = seeds_file_stat.size;
        _ = try self.seeds_file.readAll(self.seed_file_string.items);
        self.seed_file_list.clearRetainingCapacity();
        var seed_iter = std.mem.splitScalar(u8, self.seed_file_string.items, '\n');
        var pos: usize = 0;
        while (seed_iter.next()) |seedline| {
            if (seedline.len < 32) {
                pos += 1 + seedline.len;
                continue;
            }
            const line = SeedLine{
                .line = seedline,
                .seed = Utils.quick_unhex(seedline[0..16], u64),
                .count = Utils.quick_unhex(seedline[16..32], u64),
                .pos = pos,
            };
            try self.seed_file_list.append(self.alloc, line);
            pos += 1 + seedline.len;
        }
        self.first_block = true;
        self.block_num = 0;
        i = 1;
        var failure: ?SeedFailure = null;
        if (self.one_seed) |_| {
            self.thread_count = 1;
            try self.sub_fuzz(0, self.states[0], &self.seeds[0], &self.total_seeds[0], &self.total_ops[0], &self.seed_fails[0], true);
        } else {
            while (i < self.thread_count) {
                _ = try Thread.spawn(.{ .allocator = std.heap.smp_allocator }, sub_fuzz, .{ self, i, self.states[i], &self.seeds[i], &self.total_seeds[i], &self.total_ops[i], &self.seed_fails[i], false });
                i += 1;
            }
            try self.sub_fuzz(0, self.states[0], &self.seeds[0], &self.total_seeds[0], &self.total_ops[0], &self.seed_fails[0], true);
        }
        i = 0;
        while (i < self.thread_count) {
            self.all_total_seeds += self.total_seeds[i];
            self.all_total_ops += self.total_ops[i];
            if (self.seed_fails[i]) |this_fail| {
                var was_existing: bool = false;
                for (self.seed_file_list.items) |existing_fail| {
                    if (this_fail.seed == existing_fail.seed and this_fail.count > existing_fail.count) {
                        try self.seeds_file.seekTo(existing_fail.pos + 16);
                        _ = try self.seeds_file.write(Utils.quick_hex(this_fail.count)[0..]);
                        was_existing = true;
                        break;
                    }
                }
                if (!was_existing) {
                    try self.seeds_file.seekFromEnd(0);
                    _ = try self.seeds_file.write("\n");
                    _ = try self.seeds_file.write(Utils.quick_hex(this_fail.seed)[0..]);
                    _ = try self.seeds_file.write(Utils.quick_hex(this_fail.count)[0..]);
                }
                if (failure == null) {
                    failure = this_fail;
                } else {
                    self.alloc.free(this_fail.reason);
                }
            }
            i += 1;
        }
        if (failure) |f| {
            try self._add_fail(self.name, f);
            try self._print_failure(self.name);
        } else {
            try self._add_pass();
            try self._print_success(self.name);
        }
    }

    fn sub_fuzz(self: *Self, thread_num: u64, state: *anyopaque, seed: *FuzzSeed, total_seeds: *u64, total_ops: *u64, fail: *?SeedFailure, comptime primary: bool) !void {
        var more: bool = true;
        if (primary) {
            var seed_line: SeedLine = undefined;
            var i: usize = 0;
            if (self.one_seed) |one_seed| {
                var found_in_file = false;
                for (self.seed_file_list.items) |s_line| {
                    if (s_line.seed == one_seed) {
                        found_in_file = true;
                        _ = self._run_seed(thread_num, state, seed, total_seeds, total_ops, fail, true, s_line.seed, self.nops orelse s_line.count);
                        break;
                    }
                }
                if (!found_in_file) {
                    _ = self._run_seed(thread_num, state, seed, total_seeds, total_ops, fail, true, one_seed, self.nops orelse self.max_ops_per_seed);
                }
            } else {
                while (more and i < self.seed_file_list.items.len) {
                    seed_line = self.seed_file_list.items[i];
                    i += 1;
                    more = self._run_seed(thread_num, state, seed, total_seeds, total_ops, fail, true, seed_line.seed, seed_line.count);
                    more = more and try self._check_time() and self.stop_fuzz.load(.monotonic) == 0;
                }
                while (more) {
                    more = self._run_seed(thread_num, state, seed, total_seeds, total_ops, fail, false, 0, 0);
                    more = more and try self._check_time() and self.stop_fuzz.load(.monotonic) == 0;
                }
            }
            self.stop_fuzz.store(1, .monotonic);
            _ = self.threads_done.fetchAdd(1, .monotonic);
            var all_done: bool = false;
            while (!all_done) {
                all_done = self.threads_done.load(.monotonic) == self.thread_count;
                Thread.sleep(std.time.ns_per_ms * 100);
            }
        } else {
            while (more) {
                more = self._run_seed(thread_num, state, seed, total_seeds, total_ops, fail, false, 0, 0);
                more = more and self.stop_fuzz.load(.monotonic) == 0;
            }
            self.stop_fuzz.store(1, .monotonic);
            _ = self.threads_done.fetchAdd(1, .monotonic);
        }
    }

    fn _add_pass(self: *Self) anyerror!void {
        self.total_fuzzes += 1;
        self.total_pass += 1;
    }

    fn _add_fail(self: *Self, name: []const u8, failure: SeedFailure) anyerror!void {
        try self.fail_list.append(self.alloc, name);
        try self.fail_details.append(self.alloc, failure);
        self.total_fuzzes += 1;
        self.total_fail += 1;
    }

    fn _print_success(self: *Self, name: []const u8) anyerror!void {
        _ = try self.console.write("\x1b[1G\x1b[32m┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈\x1b[0m");
        _ = try self.console.write("\x1b[1G\x1b[32m");
        _ = try self.console.write(name);
        _ = try self.console.write("\x1b[0m\x1b[106G");
        var total = Utils.quick_dec(self.all_total_seeds);
        _ = try self.console.write(total.bytes());
        _ = try self.console.write("\x1b[117G");
        total = Utils.quick_dec(self.all_total_ops);
        _ = try self.console.write(total.bytes());
        _ = try self.console.write("\n");
    }

    fn _print_failure(self: *Self, name: []const u8) anyerror!void {
        _ = try self.console.write("\x1b[1G\x1b[31m┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈\x1b[0m");
        _ = try self.console.write("\x1b[1G\x1b[31m");
        _ = try self.console.write(name);
        _ = try self.console.write("\x1b[0m\x1b[106G");
        var total = Utils.quick_dec(self.all_total_seeds);
        _ = try self.console.write(total.bytes());
        _ = try self.console.write("\x1b[117G");
        total = Utils.quick_dec(self.all_total_ops);
        _ = try self.console.write(total.bytes());
        _ = try self.console.write("\n");
    }

    pub fn print_header(self: *Self) anyerror!void {
        _ = try self.console.write("\x1b[?25l");
        _ = try self.console.write(FUZZ_BATCH_HEADER_);
        _ = try self.console.write("\n");
    }
    pub fn print_interlude(self: *Self) anyerror!void {
        _ = try self.console.write(FUZZ_BATCH_INTERLD);
        _ = try self.console.write("\n");
    }
    pub fn print_footer(self: *Self) anyerror!void {
        _ = try self.console.write(FUZZ_BATCH_FOOTER_);
        _ = try self.console.write("\n");
        var num: Utils.QuickDecResult = undefined;
        if (self.total_pass > 0) {
            _ = try self.console.write("\x1b[32mSUCCESS: ");
            num = Utils.quick_dec(self.total_pass);
            _ = try self.console.write(num.bytes());
            _ = try self.console.write(" / ");
            num = Utils.quick_dec(self.total_fuzzes);
            _ = try self.console.write(num.bytes());
            _ = try self.console.write("\x1b[0m\n");
        }
        if (self.total_fail > 0) {
            _ = try self.console.write("\x1b[31mFAILURE: ");
            num = Utils.quick_dec(self.total_fail);
            _ = try self.console.write(num.bytes());
            _ = try self.console.write(" / ");
            num = Utils.quick_dec(self.total_fuzzes);
            _ = try self.console.write(num.bytes());
            var i: usize = 0;
            while (i < self.fail_list.items.len) {
                const fail_name = self.fail_list.items[i];
                const details = self.fail_details.items[i];
                _ = try self.console.write("\n  X ");
                _ = try self.console.write(fail_name);
                _ = try self.console.write(" seed=");
                const numhex = Utils.quick_hex(details.seed);
                _ = try self.console.write(numhex[0..]);
                _ = try self.console.write(" op_num=");
                num = Utils.quick_dec(details.count);
                _ = try self.console.write(num.bytes());
                _ = try self.console.write(": ");
                _ = try self.console.write(details.reason);
                self.alloc.free(details.reason);
                i += 1;
            }
            _ = try self.console.write("\x1b[0m\n");
        }
        if (self.total_pass == self.total_fuzzes) {
            _ = try self.console.write("\x1b[0;32mALL TESTS PASS!\x1b[0m\x1b[?25h\n");
        } else {
            _ = try self.console.write("\x1b[?25h");
        }
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
            return false;
        }
        return true;
    }

    fn _run_seed(self: *Self, thread_num: u64, state: *anyopaque, seed: *FuzzSeed, total_seeds: *u64, total_ops: *u64, fail: *?SeedFailure, comptime from_file: bool, file_seed: u64, file_min: u64) bool {
        if (from_file) {
            seed.set_seed(file_seed);
        } else {
            seed.rand_seed_domain(thread_num, self.thread_count);
        }
        total_seeds.* = total_seeds.* + 1;
        var op_count: u64 = 0;
        const fail_reason: ?[]const u8 = run: {
            var random = seed.prng.random();
            var r = self.start_seed_func(random, state, self.alloc);
            if (r != null) {
                break :run r;
            }
            const max_ops = @max(1, self.min_ops_per_seed, random.uintAtMost(u64, self.max_ops_per_seed), file_min);
            while (op_count < max_ops) {
                op_count += 1;
                total_ops.* += 1;
                const op_idx = random.uintLessThan(usize, self.op_table.len);
                r = self.op_table[op_idx](random, state, self.alloc);
                if (r != null) {
                    break :run r;
                }
            }
            break :run null;
        };
        if (fail_reason) |r| {
            fail.* = SeedFailure{
                .seed = seed.seed,
                .count = op_count,
                .reason = r,
            };
            return false;
        }
        return true;
    }
};

pub const OVERHEAD_TEST = FuzzTest{
    .options = .{ .name = "FUZZ_OVERHEAD" },
    .init_func = noop_init,
    .deinit_func = noop_deinit,
    .op_table = noop_table[0..1],
    .start_seed_func = noop_start_seed,
};

pub const FAILURE_TEST = FuzzTest{
    .options = .{ .name = "FUZZ_FAILURE" },
    .init_func = noop_init,
    .deinit_func = noop_deinit,
    .op_table = fail_table[0..1],
    .start_seed_func = noop_start_seed,
};
