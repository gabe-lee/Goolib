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
const build = @import("builtin");
const assert = std.debug.assert;
const math = std.math;

const Root = @import("./_root.zig");
const Types = Root.Types;
const CommonTypes = Root.CommonTypes;
const Mutability = CommonTypes.Mutability;
const Nullability = CommonTypes.Nullability;
const NullPropagation = CommonTypes.NullPropagation;
const NullOperation = CommonTypes.NullOperation;
const Utils = Root.Utils;
const Cast = Root.Cast;
const Hash = std.hash.XxHash64;
const Assert = Root.Assert;
const Sort = Root.Sort;
const Allocator = std.mem.Allocator;
const KindInfo = Types.KindInfo;
const StructField = std.builtin.Type.StructField;
const EnumField = std.builtin.Type.EnumField;
const IoWriter = std.Io.Writer;
const IoReader = std.Io.Reader;
const util_secure_memset = Utils.Mem.secure_memset;
const util_secure_zero = Utils.Mem.secure_zero;
const util_secure_memset_undefined = Utils.Mem.secure_memset_undefined;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;
const ll = std.DoublyLinkedList.Node

pub const SeekError = error{
    invalid_data_source,
    attempt_to_seek_before_start,
    attempt_to_seek_after_end,
    cannot_seek,
    cannot_seek_forward,
    cannot_seek_backward,
};
pub const SeekForwardError = error{
    invalid_data_source,
    attempt_to_seek_after_end,
    cannot_seek,
    cannot_seek_forward,
};
pub const CannotSeekForwardError = error{
    invalid_data_source,
    cannot_seek,
    cannot_seek_forward,
};
pub const SeekBackwardError = error{
    invalid_data_source,
    attempt_to_seek_before_start,
    cannot_seek,
    cannot_seek_backward,
};
pub const CannotSeekBackwardError = error{
    invalid_data_source,
    cannot_seek,
    cannot_seek_backward,
};
pub const CannotSeekError = error{
    invalid_data_source,
    cannot_seek,
    cannot_seek_forward,
    cannot_seek_backward,
};
pub const ReadError = error{
    cannot_read,
    invalid_data_source,
    read_timeout,
    read_canceled,
    too_few_items_available_to_read,
};

pub const ReadConstrainedError = error{
    cannot_read,
    invalid_data_source,
    read_timeout,
    read_canceled,
};
pub const WriteError = error{
    cannot_write,
    invalid_data_destination,
    write_canceled,
    write_timeout,
    not_enough_space_to_write,
};
pub const WriteConstrainedError = error{
    cannot_write,
    invalid_data_destination,
    write_canceled,
    write_timeout,
};

pub const ReadWriteError = error{
    // read
    cannot_read,
    invalid_data_source,
    read_timeout,
    read_canceled,
    too_few_items_available_to_read,
    // write
    cannot_write,
    invalid_data_destination,
    write_canceled,
    write_timeout,
    not_enough_space_to_write,
};

pub const ReadWriteErrorConstrained = error{
    // read
    cannot_read,
    invalid_data_source,
    read_timeout,
    read_canceled,
    // write
    cannot_write,
    invalid_data_destination,
    write_canceled,
    write_timeout,
};

pub const SeekResult = struct {
    delta: isize = 0,
    err: ?SeekError = null,

    pub fn check_error(self: SeekResult) SeekError!void {
        if (self.err) |err| return err;
    }
    pub fn assert_no_error(self: SeekResult, comptime src: std.builtin.SourceLocation) void {
        self.check_error() catch |err| assert_unreachable_err(src, err);
    }
    pub fn check_error_constrained(self: SeekResult) CannotSeekError!void {
        if (self.err) |err| switch (err) {
            SeekError.attempt_to_seek_after_end, SeekError.attempt_to_seek_before_start => {},
            else => |e| return @errorCast(e),
        };
    }
    pub fn assert_no_error_constrained(self: SeekResult, comptime src: std.builtin.SourceLocation) void {
        self.check_error_constrained() catch |err| assert_unreachable_err(src, err);
    }
};

pub const ReadResult = struct {
    num: usize = 0,
    err: ?ReadError = null,

    pub fn check_error(self: ReadResult) ReadError!void {
        if (self.err) |err| return err;
    }
    pub fn assert_no_error(self: ReadResult, comptime src: std.builtin.SourceLocation) void {
        self.check_error() catch |err| assert_unreachable_err(src, err);
    }
};

pub const WriteResult = struct {
    num: usize = 0,
    err: ?WriteError = null,

    pub fn check_error(self: WriteResult) WriteError!void {
        if (self.err) |err| return err;
    }
    pub fn assert_no_error(self: WriteResult, comptime src: std.builtin.SourceLocation) void {
        self.check_error() catch |err| assert_unreachable_err(src, err);
    }
};

pub const ReadWriteResult = struct {
    num: usize = 0,
    err: ?ReadWriteError = null,

    pub fn check_error(self: ReadWriteResult) ReadWriteError!void {
        if (self.err) |err| return err;
    }
    pub fn assert_no_error(self: ReadWriteResult, comptime src: std.builtin.SourceLocation) void {
        self.check_error() catch |err| assert_unreachable_err(src, err);
    }
};

pub const Count = union(enum) {
    ALL: void,
    EXACT: usize,
    AT_LEAST: usize,
    AT_MOST: usize,
    MIN_MAX: struct { usize, usize },

    pub fn all_items() Count {
        return Count{ .ALL = void{} };
    }
    pub fn exactly_one_item() Count {
        return Count{ .EXACT = 1 };
    }
    pub fn exactly_n_items(n: usize) Count {
        return Count{ .EXACT = n };
    }
    pub fn at_least_n_items(n: usize) Count {
        return Count{ .AT_LEAST = n };
    }
    pub fn at_least_one_item() Count {
        return Count{ .AT_LEAST = 1 };
    }
    pub fn at_most_n_items(n: usize) Count {
        return Count{ .AT_MOST = n };
    }
    pub fn at_most_one_item() Count {
        return Count{ .AT_MOST = 1 };
    }
    pub fn between_min_and_max_items(min: usize, max: usize) Count {
        return Count{ .MIN_MAX = .{ min, max } };
    }
    pub fn between_one_and_max_items(max: usize) Count {
        return Count{ .MIN_MAX = .{ 1, max } };
    }

    pub fn min_num(self: Count) ?usize {
        return switch (self) {
            .ALL => null,
            .EXACT => |val| val,
            .AT_LEAST => |val| val,
            .AT_MOST => 0,
            .MIN_MAX => |vals| vals[0],
        };
    }
};

pub const SeekOrigin = enum(u8) {
    FROM_CURRENT_POSITION,
    FROM_READ_POSITION,
    FROM_WRITE_POSITION,
    FROM_START,
    FROM_END,
};

pub const SeekPos = enum(u8) {
    READ_POS,
    WRITE_POS,
};

pub const PeekRead = enum(u8) {
    PEEK,
    READ,
};

pub const SetWrite = enum(u8) {
    SET,
    WRITE,
};

const UntilDelimiterStage = enum(u8) {
    SEARCH,
    FOUND,
};
const IncludeDelimiter = enum(u8) {
    INCLIDE_DELIMITER_IN_READ,
    READ_UP_TO_DELIMITER_THEN_STOP,
    READ_UP_TO_DELIMITER_THEN_DISCARD_IT,
};

pub fn GooReaderWriter(comptime T: type) type {
    return struct {
        vtable: *const VTABLE,

        pub const VTABLE = struct {
            /// Move the read or write position forward or backward with respect to `origin`
            ///
            /// Should always provide an error if the seek could not be completed
            /// as requested, but should attempt to move as far as possible
            seek: *const fn (interface: *Self, pos: SeekPos, origin: SeekOrigin, delta: isize) SeekResult,
            /// Copy a number of items defined by `count` starting from the current read position
            /// to the destination pointer, but do not advance the read position
            ///
            /// Should always provide an error if the minimum number of requested
            /// items are not copied, but should attempt to copy as many as possible
            peek: *const fn (interface: *Self, count: Count, dest: [*]T) ReadResult,
            /// Copy a number of items defined by `count` starting from the current read position
            /// to the destination pointer and advance the read position
            ///
            /// Should always provide an error if the minimum number of requested
            /// items are not copied, but should attempt to copy as many as possible
            read: *const fn (interface: *Self, count: Count, dest: [*]T) ReadResult,
            /// Copy a number of items defined by `count` starting at the current write position
            /// from the source pointer, but do not advance the write position
            ///
            /// Should always provide an error if the minimum number of requested
            /// items are not copied, but should attempt to copy as many as possible
            set: *const fn (interface: *Self, count: Count, source: [*]const u8) WriteResult,
            /// Copy a number of items defined by `count` starting at the current write position
            /// from the source pointer and advance the write position
            ///
            /// Should always provide an error if the minimum number of requested
            /// items are not copied, but should attempt to copy as many as possible
            write: *const fn (interface: *Self, count: Count, source: [*]const u8) WriteResult,
            /// Copy a number of items defined by `count` starting at the current read position
            /// of this `GooReaderWriter` to the current write position of the destination
            /// `GooReaderWriter`
            ///
            /// `read_mode` and `write_mode` determine whether the source read position
            /// and the destination write position are advanced, respectively
            ///
            /// Should always provide an error if the minimum number of requested
            /// items are not copied, but should attempt to copy as many as possible
            stream_to_dest: *const fn (this_interface: *Self, count: Count, read_mode: PeekRead, dest_interface: *Self, write_mode: SetWrite) ReadWriteResult,
        };
        const Self = @This();

        pub fn byte_reader(self: *Self) ByteReader {
            assert_with_reason(T == u8, @src(), "T is not u8 (got `{s}`), cannot cast to byte reader", .{@typeName(T)});
            return ByteReader{ .u8_reader = self };
        }

        //*********
        // SEEK
        //*********

        pub fn seek_full_info(self: *Self, pos: SeekPos, origin: SeekOrigin, delta: isize) SeekResult {
            return self.vtable.seek(self, pos, origin, delta);
        }
        pub fn seek_return_delta(self: *Self, pos: SeekPos, origin: SeekOrigin, delta: isize) SeekError!isize {
            const result = self.seek_full_info(pos, origin, delta);
            try result.check_error();
            return result.delta;
        }
        pub fn seek(self: *Self, pos: SeekPos, origin: SeekOrigin, delta: isize) SeekError!void {
            const result = self.seek_full_info(pos, origin, delta);
            try result.check_error();
        }
        pub fn seek_constrained_return_delta(self: *Self, pos: SeekPos, origin: SeekOrigin, delta: isize) CannotSeekError!isize {
            const result = self.seek_full_info(pos, origin, delta);
            try result.check_error_constrained();
            return result.delta;
        }
        pub fn seek_constrained(self: *Self, origin: SeekOrigin, delta: isize) CannotSeekError!void {
            const result = self.seek_full_info(origin, delta);
            try result.check_error_constrained();
        }
        pub fn seek_return_delta_never_err(self: *Self, pos: SeekPos, origin: SeekOrigin, delta: isize) isize {
            const result = self.seek_full_info(pos, origin, delta);
            result.assert_no_error(@src());
            return result.delta;
        }
        pub fn seek_never_err(self: *Self, pos: SeekPos, origin: SeekOrigin, delta: isize) void {
            const result = self.seek_full_info(pos, origin, delta);
            result.assert_no_error(@src());
        }
        pub fn seek_constrained_return_delta_never_err(self: *Self, pos: SeekPos, origin: SeekOrigin, delta: isize) isize {
            const result = self.seek_full_info(pos, origin, delta);
            result.assert_no_error_constrained(@src());
            return result.delta;
        }
        pub fn seek_constrained_never_err(self: *Self, origin: SeekOrigin, delta: isize) void {
            const result = self.seek_full_info(origin, delta);
            result.assert_no_error_constrained(@src());
        }
        pub fn advance(self: *Self, pos: SeekPos, count: usize) SeekForwardError!void {
            self.seek(pos, .FROM_CURRENT_POSITION, num_cast(count, isize)) catch |err| return @errorCast(err);
        }
        pub fn advance_constrained(self: *Self, pos: SeekPos, count: usize) CannotSeekForwardError!void {
            self.seek_constrained(pos, .FROM_CURRENT_POSITION, num_cast(count, isize)) catch |err| return @errorCast(err);
        }
        pub fn advance_never_err(self: *Self, pos: SeekPos, count: usize) void {
            self.seek_never_err(pos, .FROM_CURRENT_POSITION, num_cast(count, isize));
        }
        pub fn advance_constrained_never_err(self: *Self, pos: SeekPos, count: usize) void {
            self.seek_constrained_never_err(pos, .FROM_CURRENT_POSITION, num_cast(count, isize));
        }
        pub fn rollback(self: *Self, pos: SeekPos, count: usize) SeekBackwardError!void {
            self.seek(pos, .FROM_CURRENT_POSITION, -num_cast(count, isize)) catch |err| return @errorCast(err);
        }
        pub fn rollback_constrained(self: *Self, pos: SeekPos, count: usize) CannotSeekBackwardError!void {
            self.seek_constrained(pos, .FROM_CURRENT_POSITION, -num_cast(count, isize)) catch |err| return @errorCast(err);
        }
        pub fn rollback_never_err(self: *Self, pos: SeekPos, count: usize) void {
            self.seek_never_err(pos, .FROM_CURRENT_POSITION, -num_cast(count, isize));
        }
        pub fn rollback_constrained_never_err(self: *Self, pos: SeekPos, count: usize) void {
            self.seek_constrained_never_err(pos, .FROM_CURRENT_POSITION, -num_cast(count, isize));
        }

        //*********
        // PEEK
        //*********

        pub fn peek_full_info(self: *Self, count: Count, dest: [*]T) ReadResult {
            return self.vtable.peek(self, count, dest);
        }
        pub fn peek(self: *Self, count: Count, dest: [*]T) ReadError!void {
            const result = self.peek_full_info(count, dest);
            try result.check_error();
        }
        pub fn peek_return_num(self: *Self, count: Count, dest: [*]T) ReadError!usize {
            const result = self.peek_full_info(count, dest);
            try result.check_error();
            return result.num;
        }
        pub fn peek_never_err(self: *Self, count: Count, dest: [*]T) void {
            const result = self.peek_full_info(count, dest);
            result.assert_no_error(@src());
        }
        pub fn peek_return_num_never_err(self: *Self, count: Count, dest: [*]T) usize {
            const result = self.peek_full_info(count, dest);
            result.assert_no_error(@src());
            return result.num;
        }

        //*********
        // READ
        //*********

        pub fn read_full_info(self: *Self, count: Count, dest: [*]T) ReadResult {
            return self.vtable.read(self, count, dest);
        }
        pub fn read(self: *Self, count: Count, dest: [*]T) ReadError!void {
            const result = self.read_full_info(count, dest);
            try result.check_error();
        }
        pub fn read_return_num(self: *Self, count: Count, dest: [*]T) ReadError!usize {
            const result = self.read_full_info(count, dest);
            try result.check_error();
            return result.num;
        }
        pub fn read_never_err(self: *Self, count: Count, dest: [*]T) void {
            const result = self.read_full_info(count, dest);
            result.assert_no_error(@src());
        }
        pub fn read_return_num_never_err(self: *Self, count: Count, dest: [*]T) usize {
            const result = self.read_full_info(count, dest);
            result.assert_no_error(@src());
            return result.num;
        }

        //*********
        // SET
        //*********

        pub fn set_full_info(self: *Self, count: Count, source: [*]const T) WriteResult {
            return self.vtable.set(self, count, source);
        }
        pub fn set(self: *Self, count: Count, source: [*]const T) WriteError!void {
            const result = self.set_full_info(count, source);
            try result.check_error();
        }
        pub fn set_return_num(self: *Self, count: Count, source: [*]const T) WriteError!usize {
            const result = self.set_full_info(count, source);
            try result.check_error();
            return result.num;
        }
        pub fn set_never_err(self: *Self, count: Count, source: [*]const T) void {
            const result = self.set_full_info(count, source);
            result.assert_no_error(@src());
        }
        pub fn set_return_num_never_err(self: *Self, count: Count, source: [*]const T) usize {
            const result = self.set_full_info(count, source);
            result.assert_no_error(@src());
            return result.num;
        }

        //*********
        // WRITE
        //*********

        pub fn write_full_info(self: *Self, count: Count, source: [*]const T) WriteResult {
            return self.vtable.write(self, count, source);
        }
        pub fn write(self: *Self, count: Count, source: [*]const T) WriteError!void {
            const result = self.write_full_info(count, source);
            try result.check_error();
        }
        pub fn write_return_num(self: *Self, count: Count, source: [*]const T) WriteError!usize {
            const result = self.write_full_info(count, source);
            try result.check_error();
            return result.num;
        }
        pub fn write_never_err(self: *Self, count: Count, source: [*]const T) void {
            const result = self.write_full_info(count, source);
            result.assert_no_error(@src());
        }
        pub fn write_return_num_never_err(self: *Self, count: Count, source: [*]const T) usize {
            const result = self.write_full_info(count, source);
            result.assert_no_error(@src());
            return result.num;
        }

        //*********
        // STREAM
        //*********

        pub fn stream_to_dest_full_info(self: *Self, count: Count, read_mode: PeekRead, dest: *Self, write_mode: SetWrite) ReadWriteResult {
            return self.vtable.stream_to_dest(self, count, read_mode, dest, write_mode);
        }
        pub fn stream_to_dest(self: *Self, count: Count, read_mode: PeekRead, dest: *Self, write_mode: SetWrite) ReadWriteError!void {
            const result = self.stream_to_dest_full_info(count, read_mode, dest, write_mode);
            try result.check_error();
        }
        pub fn stream_to_dest_return_num(self: *Self, count: Count, read_mode: PeekRead, dest: *Self, write_mode: SetWrite) ReadWriteError!usize {
            const result = self.stream_to_dest_full_info(count, read_mode, dest, write_mode);
            try result.check_error();
            return result.num;
        }
        pub fn stream_to_dest_never_err(self: *Self, count: Count, read_mode: PeekRead, dest: *Self, write_mode: SetWrite) void {
            const result = self.stream_to_dest_full_info(count, read_mode, dest, write_mode);
            result.assert_no_error(@src());
        }
        pub fn stream_to_dest_return_num_never_err(self: *Self, count: Count, read_mode: PeekRead, dest: *Self, write_mode: SetWrite) usize {
            const result = self.stream_to_dest_full_info(count, read_mode, dest, write_mode);
            result.assert_no_error(@src());
            return result.num;
        }
        //*********
        // PEEK SPECIAL
        //*********

        pub const ItemPattern = union(enum) {
            ONE: T,
            PATTERN: []const T,
            ANY_ONE: []const T,
            ANY_PATTERN_FIRST_FOUND: []const []const T,
            ANY_PATTERN_LONGEST_FOUND: []const []const T,

            pub fn delimiter_val(val: T) ItemPattern {
                return ItemPattern{ .ONE = val };
            }
            pub fn delimiter_pattern(pattern: []const T) ItemPattern {
                return ItemPattern{ .PATTERN = pattern };
            }
            pub fn any_delimiter_val(vals: []const T) ItemPattern {
                return ItemPattern{ .ANY_ONE = vals };
            }
            pub fn any_delimiter_pattern_first_found(patterns: []const []const T) ItemPattern {
                return ItemPattern{ .ANY_PATTERN_FIRST_FOUND = patterns };
            }
            pub fn any_delimiter_pattern_longest_found(patterns: []const []const T) ItemPattern {
                return ItemPattern{ .ANY_PATTERN_LONGEST_FOUND = patterns };
            }

            pub fn max_buffer_size_for_check(self: ItemPattern) usize {
                switch (self) {
                    .ONE, .ANY_ONE => return 1,
                    .PATTERN => |pat| return pat.len,
                    .ANY_PATTERN_FIRST_FOUND, .ANY_PATTERN_LONGEST_FOUND => |pats| {
                        var max: usize = 0;
                        for (pats) |pat| {
                            max = @max(max, pat.len);
                        }
                        return max;
                    },
                }
            }
            pub fn comptime_max_buffer_size_for_check(comptime self: ItemPattern) usize {
                switch (comptime self) {
                    .ONE, .ANY_ONE => return 1,
                    .PATTERN => |pat| return comptime pat.len,
                    .ANY_PATTERN_FIRST_FOUND, .ANY_PATTERN_LONGEST_FOUND => |pats| {
                        var max: usize = 0;
                        inline for (pats) |pat| {
                            max = @max(max, pat.len);
                        }
                        return comptime max;
                    },
                }
            }
        };

        pub const FoundPattern = union(enum) {
            ONE: T,
            PATTERN: []const T,
        };

        pub const AdvancedReadResult = struct {
            num_items_read: usize = 0,
            num_items_skipped: usize = 0,
            delimter_found: bool = false,
            delimiter_len: usize = 0,
            delimiter: FoundPattern = undefined,
        };

        pub fn read_until_delimiter(self: *Self, delimiter: ItemPattern, read_mode: PeekRead, include: IncludeDelimiter, dest: [*]T) ReadError!FoundDelimiterResult {
            // CHECKPOINT change this to 'advance_until' with 'skip' patterns option?
            var count: usize = 0;
            var new_dest = dest;
            var found_len: usize = 0;
            var found_delim: FoundPattern = undefined;
            search_loop: while (true) {
                self.read(.exactly_one_item(), new_dest) catch |err| switch (err) {
                    ReadError.too_few_items_available_to_read => break :search_loop,
                    else => return err,
                };
                count += 1;
                switch (delimiter) {
                    .ONE => |val| {
                        if (new_dest[0] == val) {
                            found_len = 1;
                            found_delim = .{ .ONE = val };
                            break :search_loop;
                        }
                    },
                    .ANY_ONE => |vals| {
                        for (vals) |val| {
                            if (new_dest[0] == val) {
                                found_len = 1;
                                found_delim = .{ .ONE = val };
                                break :search_loop;
                            }
                        }
                    },
                    .PATTERN => |pattern| {
                        var i = pattern.len;
                        var past_dest = new_dest + 1;
                        while (i > 0) {
                            i -= 1;
                            past_dest -= 1;
                            const val = pattern[i];
                            if (val != past_dest[0]) break;
                            if (i == 0) {
                                found_len = pattern.len;
                                found_delim = .{ .PATTERN = pattern };
                                break :search_loop;
                            }
                        }
                    },
                    .ANY_PATTERN_FIRST_FOUND, .ANY_PATTERN_LONGEST_FOUND => |patterns| {
                        var longest_found: usize = 0;
                        var longest_found_delim: FoundPattern = undefined;
                        for (patterns) |pattern| {
                            if (delimiter == .ANY_PATTERN_LONGEST_FOUND and longest_found >= pattern.len) continue;
                            var i = pattern.len;
                            var past_dest = new_dest + 1;
                            while (i > 0) {
                                i -= 1;
                                past_dest -= 1;
                                const val = pattern[i];
                                if (val != past_dest[0]) break;
                                if (i == 0) {
                                    if (delimiter == .ANY_PATTERN_FIRST_FOUND) {
                                        found_len = pattern.len;
                                        found_delim = .{ .PATTERN = pattern };
                                        break :search_loop;
                                    }
                                    longest_found = pattern.len;
                                    longest_found_delim = .{ .PATTERN = pattern };
                                }
                            }
                        }
                        if (longest_found > 0) {
                            found_len = longest_found;
                            found_delim = longest_found_delim;
                            break :search_loop;
                        }
                    },
                }
                new_dest += 1;
            }
            var result = FoundDelimiterResult{
                .delimiter = found_delim,
                .delimter_found = found_len > 0,
            };
            switch (read_mode) {
                .PEEK => self.rollback_never_err(.READ_POS, count),
                .READ => switch (include) {
                    .INCLIDE_DELIMITER_IN_READ => {
                        result.num_items_read = count;
                    },
                    .READ_UP_TO_DELIMITER_THEN_DISCARD_IT => {
                        result.num_items_read = count - found_len;
                    },
                    .READ_UP_TO_DELIMITER_THEN_STOP => {
                        self.rollback_never_err(.READ_POS, found_len);
                        result.num_items_read = count - found_len;
                    },
                },
            }
            return result;
        }

        pub fn peek_until_delimiter_return_num(self: *Self, delimiter: ItemPattern, check_buffer: []T, dest: [*]T) ReadError!usize {
            assert_with_reason(check_buffer.len >= delimiter.max_buffer_size_for_check(), @src(), "check_buffer is not large enough for the largest delimiter pattern provided, have len {d}, need len {d}", .{ check_buffer.len, delimiter.max_buffer_size_for_check() });
            return self.read_until_delimiter_return_num_internal(delimiter, check_buffer, dest);
        }
    };
}

pub const ByteReader = struct {
    u8_iface: *GooReaderWriter(u8),
};
