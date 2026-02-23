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
const Types = Root.Types;
const Assert = Root.Assert;
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;
const FreeList = Root.BitList.FreeBitList;
const PowerOf2 = Root.Math.PowerOf2;
// const ContinueMode = Root.CommonTypes.ContinueModeWithUnreachable;

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;

pub const PreviousQueueResult = enum(u8) {
    CONTINUE_TO_CHECK_CURRENTLY_QUEUED,
    DO_NOT_QUEUE,
    UNREACHABLE,
};
pub const CurrentlyQueuedResult = enum(u8) {
    QUEUE,
    DO_NOT_QUEUE,
    UNREACHABLE,
};

pub const SkipUniqueChecksMode = enum(u8) {
    CHECK_PREVIOUSLY_QUEUED_UNIQUES,
    SKIP_CHECKING_PREVIOUS_UNIQUE_LIST,
};

pub fn UniqueQueue(
    comptime T_QUEUE: type,
    comptime T_UNIQUE: type,
    comptime QUEUED_EQUALS_QUEUED_FUNC: fn (a: T_QUEUE, b: T_QUEUE) bool,
    comptime QUEUED_EQUALS_UNIQUE_FUNC: fn (a: T_QUEUE, b: T_UNIQUE) bool,
    comptime HANDLE_PREVIOUSLY_QUEUED: fn (item_to_queue: *T_QUEUE, previously_queued: *T_UNIQUE) PreviousQueueResult,
    comptime HANDLE_CURRENTLY_QUEUED: fn (item_to_queue: *T_QUEUE, currently_queued: *T_QUEUE) CurrentlyQueuedResult,
    comptime CREATE_NEW_UNIQUE: fn (to_queue: T_QUEUE) T_UNIQUE,
    comptime UNIQUE_CHECKS: SkipUniqueChecksMode,
) type {
    return struct {
        const Queue = @This();

        queue_ptr: [*]T_QUEUE = Utils.invalid_ptr_many(T_QUEUE),
        unique_ptr: if (DO_UNIQUE) [*]T_UNIQUE else void = if (DO_UNIQUE) Utils.invalid_ptr_many(T_UNIQUE) else void,
        queue_len: u32 = 0,
        queue_cap: u32 = 0,
        unique_len: if (DO_UNIQUE) u32 else void = if (DO_UNIQUE) 0 else void{},
        unique_cap: if (DO_UNIQUE) u32 else void = if (DO_UNIQUE) 0 else void{},
        queue_cursor: u32 = 0,

        pub const DO_UNIQUE = UNIQUE_CHECKS == .CHECK_PREVIOUSLY_QUEUED_UNIQUES;

        pub fn init_capacity(queue_cap: u32, unique_cap: u32, alloc: Allocator) Queue {
            var _queue = Queue{};
            if (queue_cap > 0) {
                const queue_mem = alloc.alloc(T_QUEUE, @intCast(queue_cap)) catch |err| assert_allocation_failure(@src(), T_QUEUE, @intCast(queue_cap), err);
                _queue.queue_ptr = queue_mem.ptr;
                _queue.queue_cap = @intCast(queue_mem.len);
            }
            if (DO_UNIQUE and unique_cap > 0) {
                const unique_mem = alloc.alloc(T_UNIQUE, @intCast(unique_cap)) catch |err| assert_allocation_failure(@src(), T_UNIQUE, @intCast(unique_cap), err);
                _queue.unique_ptr = unique_mem.ptr;
                _queue.unique_cap = @intCast(unique_mem.len);
            }
            return _queue;
        }

        pub fn reset(self: *Queue) void {
            self.queue_len = 0;
            if (DO_UNIQUE) self.unique_len = 0;
            self.queue_cursor = 0;
        }

        pub fn free(self: *Queue, alloc: Allocator) void {
            alloc.free(self.queue_ptr[0..self.queue_cap]);
            if (DO_UNIQUE) alloc.free(self.unique_ptr[0..self.unique_cap]);
            self.* = undefined;
        }

        pub fn ensure_queue_capacity(self: *Queue, queue_cap: u32, alloc: Allocator) void {
            if (self.queue_cap < queue_cap) {
                Utils.Alloc.realloc_custom_with_ptr_ptrs(alloc, &self.queue_ptr, &self.queue_cap, @intCast(queue_cap), .ALIGN_TO_TYPE, .COPY_EXISTING_DATA, .dont_memset_new(), .DONT_MEMSET_OLD) catch |err| assert_allocation_failure(@src(), T_QUEUE, @intCast(queue_cap), err);
            }
        }

        pub fn ensure_unique_capacity(self: *Queue, unique_cap: u32, alloc: Allocator) void {
            if (DO_UNIQUE and self.unique_cap < unique_cap) {
                Utils.Alloc.realloc_custom_with_ptr_ptrs(alloc, &self.unique_ptr, &self.unique_cap, @intCast(unique_cap), .ALIGN_TO_TYPE, .COPY_EXISTING_DATA, .dont_memset_new(), .DONT_MEMSET_OLD) catch |err| assert_allocation_failure(@src(), T_UNIQUE, @intCast(unique_cap), err);
            }
        }

        fn add_unique(self: *Queue, val: T_UNIQUE, alloc: Allocator) void {
            if (DO_UNIQUE) {
                self.ensure_unique_capacity(self.unique_len + 1, alloc);
                self.unique_ptr[self.unique_len] = val;
                self.unique_len += 1;
            }
        }

        fn queue_internal(self: *Queue, val: T_QUEUE, alloc: Allocator) void {
            self.ensure_queue_capacity(self.queue_len + 1, alloc);
            self.queue_ptr[self.queue_len] = val;
            self.queue_len += 1;
        }

        pub fn queue(self: *Queue, val: T_QUEUE, alloc: Allocator) void {
            var to_queue = val;
            if (DO_UNIQUE) {
                var is_unique: bool = true;
                for (self.unique_ptr[0..self.unique_len]) |*unique| {
                    if (QUEUED_EQUALS_UNIQUE_FUNC(to_queue, unique.*)) {
                        const result = HANDLE_PREVIOUSLY_QUEUED(&to_queue, unique);
                        switch (result) {
                            .UNREACHABLE => {
                                assert_unreachable(@src(), "cannot queue an item that was previously queued and processed\npreviously queued: {any}\nattempted to queue: {any}\n", .{ unique.*, val });
                                return;
                            },
                            .DO_NOT_QUEUE => {
                                return;
                            },
                            .CONTINUE_TO_CHECK_CURRENTLY_QUEUED => {},
                        }
                        is_unique = false;
                        break;
                    }
                }
                if (is_unique) {
                    const new_unique = CREATE_NEW_UNIQUE(to_queue);
                    self.add_unique(new_unique, alloc);
                }
            }
            for (self.queue_ptr[self.queue_cursor..self.queue_len]) |*current| {
                if (QUEUED_EQUALS_QUEUED_FUNC(to_queue, current.*)) {
                    const result = HANDLE_CURRENTLY_QUEUED(&to_queue, current);
                    switch (result) {
                        .UNREACHABLE => {
                            assert_unreachable(@src(), "cannot queue an item that is currently queued\nalready queued: {any}\nattempted to queue: {any}\n", .{ current.*, val });
                            return;
                        },
                        .DO_NOT_QUEUE => {
                            return;
                        },
                        .QUEUE => {},
                    }
                    break;
                }
            }
            self.queue_internal(val, alloc);
        }

        pub fn has_queued_items(self: Queue) bool {
            return self.queue_cursor < self.queue_len;
        }

        pub fn get_next_queued(self: Queue) ?T_QUEUE {
            if (self.queue_cursor < self.len) {
                const val = self.queue_ptr[self.queue_cursor];
                self.queue_cursor += 1;
                return val;
            }
            return null;
        }

        pub fn get_next_queued_guaranteed(self: Queue) T_QUEUE {
            const val = self.queue_ptr[self.queue_cursor];
            self.queue_cursor += 1;
            return val;
        }
    };
}

// pub fn UniqueQueueWtihSeparateTrackList(
//     comptime T_QUEUE: type,
//     comptime T_TRACK: type,
//     comptime MAX_TRACKS_PER_QUEUE: comptime_int,
//     comptime QUEUE_TO_TRACKS_FUNC: fn (to_queue: T_QUEUE) .{ [MAX_TRACKS_PER_QUEUE]T_TRACK, u32 },
//     comptime QUEUED_EQUALS_FUNC: fn (a: T_QUEUE, b: T_QUEUE) bool,
//     comptime TRACKED_EQUALS_FUNC: fn (a: T_TRACK, b: T_TRACK) bool,
//     comptime HANDLE_PREVIOUSLY_TRACKED: fn (item_to_queue: *T_QUEUE, full_tracked_list: []T_TRACK, previous_track_match_idx: *u32, track_list_cursor: *u32, full_tracked_list_len: *u32, to_track_list: []T_TRACK, to_track_match_idx: *u32, to_track_list_len: *u32) QueueResult,
//     comptime HANDLE_CURRENTLY_QUEUED: fn (item_to_queue: *T_QUEUE, queue: []T_QUEUE, currently_queued_start: *u32, currently_queued_match_idx: *u32, queue_list_len: *u32, to_track_list: []T_TRACK, to_track_idx: *u32, to_track_list_len: *u32) QueueResult,
//     comptime HANDLE_CURRENTLY_TRACKED: fn (item_to_queue: *T_QUEUE, full_tracked_list: []T_TRACK, current_track_match_idx: *u32, track_list_cursor: *u32, full_tracked_list_len: *u32, to_track_list: []T_TRACK, to_track_match_idx: *u32, to_track_list_len: *u32) QueueResult,
// ) type {
//     return struct {
//         const Queue = @This();
//         queue_ptr: [*]T_QUEUE = Utils.invalid_ptr_many(T_QUEUE),
//         tracked_advance_ptr: [*]u32 = Utils.invalid_ptr_many(u32),
//         queue_len: u32 = 0,
//         queue_cap: u32 = 0,
//         track_ptr: [*]T_TRACK = Utils.invalid_ptr_many(T_TRACK),
//         track_len: u32 = 0,
//         track_cap: u32 = 0,
//         queue_cursor: u32 = 0,
//         track_cursor: u32 = 0,

//         pub fn init_capacity(queue_cap: u32, track_cap: u32, alloc: Allocator) Queue {
//             const queue_mem = alloc.alloc(T_QUEUE, @intCast(queue_cap)) catch |err| assert_allocation_failure(@src(), T_QUEUE, @intCast(queue_cap), err);
//             const track_mem = alloc.alloc(T_TRACK, @intCast(track_cap)) catch |err| assert_allocation_failure(@src(), T_TRACK, @intCast(track_cap), err);
//             return Queue{
//                 .queue_ptr = queue_mem.ptr,
//                 .queue_len = 0,
//                 .queue_cap = @intCast(queue_mem.len),
//                 .queue_cursor = 0,
//                 .track_ptr = track_mem.ptr,
//                 .track_len = 0,
//                 .track_cap = @intCast(track_mem.len),
//             };
//         }

//         pub fn free(self: *Queue, alloc: Allocator) void {
//             alloc.free(self.queue_ptr[0..self.queue_cap]);
//             alloc.free(self.track_cap[0..self.track_cap]);
//             self.* = undefined;
//         }

//         pub fn ensure_capacity(self: *Queue, queue_cap: u32, track_cap: u32, alloc: Allocator) void {
//             if (self.queue_cap < queue_cap) {
//                 Utils.Alloc.realloc_custom(alloc, self.tracked_advance_ptr[0..self.queue_cap], @intCast(queue_cap), .ALIGN_TO_TYPE, .COPY_EXISTING_DATA, .dont_memset_new(), .DONT_MEMSET_OLD) catch |err| assert_allocation_failure(@src(), u32, @intCast(queue_cap), err);
//                 Utils.Alloc.realloc_custom_with_ptr_ptrs(alloc, &self.queue_ptr, &self.queue_cap, @intCast(queue_cap), .ALIGN_TO_TYPE, .COPY_EXISTING_DATA, .dont_memset_new(), .DONT_MEMSET_OLD) catch |err| assert_allocation_failure(@src(), T_QUEUE, @intCast(queue_cap), err);
//             }
//             if (self.track_cap < track_cap) {
//                 Utils.Alloc.realloc_custom_with_ptr_ptrs(alloc, &self.track_ptr, &self.track_cap, @intCast(track_cap), .ALIGN_TO_TYPE, .COPY_EXISTING_DATA, .dont_memset_new(), .DONT_MEMSET_OLD) catch |err| assert_allocation_failure(@src(), T_TRACK, @intCast(track_cap), err);
//             }
//         }

//         fn queue_internal(self: *Queue, val: T_QUEUE, new_tracks: []const T_TRACK, alloc: Allocator) void {
//             const add_tracks_len = num_cast(new_tracks.len, u32);
//             const new_track_len = self.track_len + add_tracks_len;
//             const new_queue_len = self.queue_len + 1;
//             self.ensure_capacity(new_queue_len, new_track_len, alloc);
//             self.queue_ptr[self.queue_len] = val;
//             self.tracked_advance_ptr[self.queue_len] = add_tracks_len;
//             self.queue_len = new_queue_len;
//             @memcpy(self.track_ptr[self.track_len..new_track_len], new_tracks);
//             self.track_len = new_track_len;
//         }

//         pub fn queue(self: *Queue, val: T_QUEUE, alloc: Allocator) void {
//             var to_queue = val;
//             var to_tracks: [MAX_TRACKS_PER_QUEUE]T_TRACK, var to_track_len: u32 = QUEUE_TO_TRACKS_FUNC(val);
//             var p: u32 = 0;
//             var t: u32 = 0;
//             check_prev: while (p < self.track_len) {
//                 const prev_tracked = self.track_ptr[p];
//                 check_to_add: while (t < to_track_len) {
//                     const to_track = to_tracks[t];
//                     if (TRACKED_EQUALS_FUNC(prev_tracked, to_track)) {
//                         const cont_mode = HANDLE_PREVIOUSLY_TRACKED(&to_queue, self.track_ptr[0..self.track_len], &p, &self.track_cursor, &self.track_len, to_tracks[0..to_track_len], &t, &to_track_len);
//                         switch (cont_mode) {
//                             .CONTINUE_TO_CHECK_NEXT_IN_TO_TRACK_LIST_INDEX_ALREADY_HANDLED => continue :check_to_add,
//                             .CONTINUE_TO_CHECK_NEXT_IN_EXISTING_LIST_INDEX_ALREADY_HANDLED => continue :check_prev,
//                             .DO_NOT_QUEUE => return,
//                             .UNREACHABLE => {
//                                 assert_unreachable(@src(), "cannot queue an item that was previously tracked and processed, item to queue: {any}, prev tracked item: {any}, this tracked item: {any}", .{ val, prev_tracked, to_track });
//                             },
//                         }
//                     }
//                     t += 1;
//                 }
//                 p += 1;
//             }
//             p = self.queue_cursor;
//             t = 0;
//             check_curr: while (p < self.track_len) {
//                 const curr_tracked = self.track_ptr[p];
//                 check_to_add: while (t < to_track_len) {
//                     const to_track = to_tracks[t];
//                     if (TRACKED_EQUALS_FUNC(curr_tracked, to_track)) {
//                         const cont_mode = HANDLE_CURRENTLY_QUEUED(&to_queue, self.track_ptr[0..self.track_len], &p, &self.track_cursor, &self.track_len, to_tracks[0..to_track_len], &t, &to_track_len);
//                         switch (cont_mode) {
//                             .CONTINUE_TO_CHECK_NEXT_IN_TO_TRACK_LIST_INDEX_ALREADY_HANDLED => continue :check_to_add,
//                             .CONTINUE_TO_CHECK_NEXT_IN_EXISTING_LIST_INDEX_ALREADY_HANDLED => continue :check_curr,
//                             .DO_NOT_QUEUE => return,
//                             .UNREACHABLE => {
//                                 assert_unreachable(@src(), "cannot queue an item that is currently being tracked, item to queue: {any}, curr tracked item: {any}, this tracked item: {any}", .{ val, curr_tracked, to_track });
//                             },
//                         }
//                     }
//                     t += 1;
//                 }
//                 p += 1;
//             }
//             self.queue_internal(to_queue, to_tracks[0..to_track_len], alloc);
//         }

//         pub fn has_queued_items(self: Queue) bool {
//             return self.queue_cursor < self.queue_len;
//         }

//         pub fn get_next_queued(self: *Queue) ?T_QUEUE {
//             if (self.queue_cursor < self.queue_len) {
//                 const val = self.queue_ptr[self.queue_cursor];
//                 const track_advance = self.tracked_advance_ptr[self.queue_cursor];
//                 self.queue_cursor += 1;
//                 self.track_cursor += track_advance;
//                 return val;
//             }
//             return null;
//         }

//         pub fn get_next_queued_guaranteed(self: *Queue) T_QUEUE {
//             const val = self.queue_ptr[self.queue_cursor];
//             const track_advance = self.tracked_advance_ptr[self.queue_cursor];
//             self.queue_cursor += 1;
//             self.track_cursor += track_advance;
//             return val;
//         }

//         pub fn reset(self: *Queue) void {
//             self.queue_cursor = 0;
//             self.queue_len = 0;
//             self.track_cursor = 0;
//             self.track_len = 0;
//         }
//     };
// }
