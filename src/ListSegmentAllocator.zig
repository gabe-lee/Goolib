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
const Types = Root.Types;
const Assert = Root.Assert;
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;

const List = Root.IList_List.List;
const MSList = Root.IList.MultiSortList;

pub const Internal = struct {
    pub fn seg_to_seg_internal(seg: Segment) SegmentInternal {
        return seg.to_internal_seg();
    }
    pub const Fuzzer = @import("./ListSegmentAllocator_Fuzz.zig");
};

const SegmentInternal = struct {
    start: u32 = math.maxInt(u32),
    len_and_free_flag: u32 = FREE_BIT,

    const FREE_BIT: u32 = 1 << 31;
    const LEN_MASK: u32 = ~FREE_BIT;

    pub inline fn get_len(self: SegmentInternal) u32 {
        return self.len_and_free_flag & LEN_MASK;
    }
    pub inline fn set_len(self: *SegmentInternal, len: u32) void {
        Assert.assert_with_reason(len < FREE_BIT, @src(), "ListSegmentAllocator can only support allocations up to 2,147,483,648 items long, got len {d}", .{len});
        const f = self.len_and_free_flag & FREE_BIT;
        self.len_and_free_flag = len | f;
    }
    pub inline fn incr_len(self: *SegmentInternal, n: u32) void {
        const curr_len = self.get_len();
        Assert.assert_with_reason(LEN_MASK - curr_len >= n, @src(), "ListSegmentAllocator can only support allocations up to 2,147,483,648 items long, got len {d}", .{curr_len + n});
        const f = self.len_and_free_flag & FREE_BIT;
        self.len_and_free_flag = (curr_len + n) | f;
    }
    pub inline fn decr_len(self: *SegmentInternal, n: u32) void {
        const curr_len = self.get_len();
        Assert.assert_with_reason(curr_len >= n, @src(), "cannot decrease segment len by `{d}`, current len is `{d}`", .{ n, curr_len });
        const f = self.len_and_free_flag & FREE_BIT;
        self.len_and_free_flag = (curr_len - n) | f;
    }

    pub inline fn is_free(self: SegmentInternal) bool {
        return self.len_and_free_flag & FREE_BIT == FREE_BIT;
    }
    pub inline fn set_free(self: *SegmentInternal) void {
        self.len_and_free_flag = self.len_and_free_flag | FREE_BIT;
    }
    pub inline fn set_used(self: *SegmentInternal) void {
        self.len_and_free_flag = self.len_and_free_flag & LEN_MASK;
    }

    pub inline fn is_zero_len_and_free(self: SegmentInternal) bool {
        return self.len_and_free_flag == FREE_BIT;
    }

    pub inline fn to_alloc_seg(self: SegmentInternal) Segment {
        return Segment{
            .start = self.start,
            .len = self.len_and_free_flag,
        };
    }
};

pub const Segment = struct {
    start: u32 = math.maxInt(u32),
    len: u32 = 0,

    inline fn to_internal_seg(self: Segment) SegmentInternal {
        return SegmentInternal{
            .start = self.start,
            .len_and_free_flag = self.len,
        };
    }
};

pub const SORT_NAMES = enum(u8) {
    FREE,
    LOGICAL,
};
fn free_greater_than(a: SegmentInternal, b: SegmentInternal) bool {
    return a.get_len() > b.get_len();
}
fn free_equal(a: SegmentInternal, b: SegmentInternal) bool {
    return a.get_len() == b.get_len();
}
fn free_filter(seg: SegmentInternal) bool {
    return seg.is_free();
}
fn free_fits_needed(a: SegmentInternal, b: SegmentInternal) bool {
    return a.get_len() >= b.get_len();
}
fn logical_greater_than(a: SegmentInternal, b: SegmentInternal) bool {
    return a.start > b.start;
}
fn logical_equal(a: SegmentInternal, b: SegmentInternal) bool {
    return a.start == b.start;
}
fn exact_equal(a: SegmentInternal, b: SegmentInternal) bool {
    return a.start == b.start and a.len_and_free_flag == b.len_and_free_flag;
}

const SegList = MSList(SegmentInternal, SegmentInternal{}, u32, SORT_NAMES);

const SORT_INITS = [2]SegList.SortInit{
    SegList.SortInit{
        .name = .FREE,
        .equal = free_equal,
        .greater_than = free_greater_than,
        .filter = free_filter,
    },
    SegList.SortInit{
        .name = .LOGICAL,
        .equal = logical_equal,
        .greater_than = logical_greater_than,
    },
};

pub fn ListSegmentAllocator(comptime T: type) type {
    return struct {
        const Self = @This();

        data: List(T),
        segment_list: SegList,

        pub fn init_empty() Self {
            return Self{
                .data = List(T).init_empty(),
                .segment_list = SegList.init_empty(exact_equal, SORT_INITS[0..]),
            };
        }

        pub fn init_capacity(data_cap: usize, segment_cap: usize, alloc: Allocator) Self {
            return Self{
                .data = List(T).init_capacity(data_cap, alloc),
                .segment_list = SegList.init_capacity(segment_cap, segment_cap, alloc, exact_equal, SORT_INITS[0..]),
            };
        }

        pub fn get_slice(self: *Self, start: anytype, len: anytype) []T {
            const end = start + len;
            return self.data.ptr[start..end];
        }

        pub fn get_ptr(self: *Self, idx: anytype) *T {
            return &self.data.ptr[idx];
        }

        const SegWithLoc = struct {
            seg: Segment,
            logical: u32,
            real_idx: u32,
            claimed_entire_free: bool,
        };

        fn claim_segment_with_location(self: *Self, len: usize, alloc: Allocator) SegWithLoc {
            const len_u32 = Types.intcast(len, u32);
            const proto_segment = SegmentInternal{
                .start = 0,
                .len_and_free_flag = SegmentInternal.FREE_BIT | len_u32,
            };
            if (self.segment_list.find_idx_for_value_using_sort(.FREE, proto_segment, free_fits_needed)) |found_free_idx| {
                const old_free_idx = found_free_idx.real_idx;
                const old_free = self.segment_list.get(old_free_idx);
                const new_claimed = SegmentInternal{
                    .start = old_free.start,
                    .len_and_free_flag = len_u32,
                };
                const new_free = SegmentInternal{
                    .start = old_free.start + len_u32,
                    .len_and_free_flag = (old_free.get_len() - len_u32) | SegmentInternal.FREE_BIT,
                };
                var new_claimed_with_loc: SegWithLoc = undefined;
                new_claimed_with_loc.seg = new_claimed.to_alloc_seg();
                if (new_free.is_zero_len_and_free()) {
                    std.debug.print("\nclaim free use entire branch\n", .{}); //DEBUG
                    self.segment_list.set(old_free_idx, new_claimed, alloc);
                    new_claimed_with_loc.claimed_entire_free = true;
                    new_claimed_with_loc.real_idx = @intCast(old_free_idx);
                    new_claimed_with_loc.logical = @intCast(found_free_idx.sort_list_idx);
                } else {
                    std.debug.print("\nclaim free use partial branch\n", .{}); //DEBUG
                    //CHECKPOINT something is wrong here
                    const new_free_logical_idx = self.segment_list.set_1_with_sort_idx(found_free_idx, new_free, .LOGICAL, alloc).?;
                    const r_idx = self.segment_list.append_1_initialized(new_claimed, alloc);
                    new_claimed_with_loc.claimed_entire_free = false;
                    new_claimed_with_loc.real_idx = @intCast(r_idx);
                    new_claimed_with_loc.logical = @intCast(new_free_logical_idx);
                }
                return new_claimed_with_loc;
            } else {
                std.debug.print("\nclaim alloc new new branch\n", .{}); //DEBUG
                const new_range = self.data.append_slots(len, alloc);
                const new_claimed = SegmentInternal{
                    .start = @intCast(new_range.first_idx),
                    .len_and_free_flag = len_u32,
                };
                const ridx = self.segment_list.append_1_initialized(new_claimed, alloc);
                return SegWithLoc{
                    .seg = new_claimed.to_alloc_seg(),
                    .real_idx = @intCast(ridx),
                    .logical = @intCast(ridx),
                    .claimed_entire_free = true,
                };
            }
        }

        /// Get a new allocated segment of the backing list
        ///
        /// May invalidate existing data slices or pointers
        pub fn claim_segment(self: *Self, len: usize, alloc: Allocator) Segment {
            return self.claim_segment_with_location(len, alloc).seg;
        }

        const COMBINE__xxxx_THIS_xxxx: u2 = 0b00;
        const COMBINE__xxxx_THIS_NEXT: u2 = 0b01;
        const COMBINE__PREV_THIS_xxxx: u2 = 0b10;
        const COMBINE__PREV_THIS_NEXT: u2 = 0b11;

        /// Return/Free an allocated segment back to the backing list
        pub fn release_segment(self: *Self, seg: Segment, alloc: Allocator) void {
            const found = self.segment_list.find_idx_for_exact_value_using_sort(.LOGICAL, seg.to_internal_seg()) orelse Assert.assert_unreachable(@src(), "attempted to release list segment that was not found in list: data_len: {d}, segment: {any}", .{ self.data.len, seg });
            var found_segment = self.segment_list.get(found.real_idx);
            const found_len = found_segment.get_len();
            Assert.assert_with_reason(!found_segment.is_free(), @src(), "attempted to release list segment that was already free: segment = {any}", .{seg});
            self.release_segment_known(found, found_segment, found_len, alloc);
        }

        fn release_segment_known(self: *Self, found: SegList.SortIdx, found_seg: SegmentInternal, found_len: u32, alloc: Allocator) void {
            var found_segment = found_seg;
            var prev_logical: SegmentInternal = undefined;
            var next_logical: SegmentInternal = undefined;
            var prev_logical_idx: usize = undefined;
            var next_logical_idx: usize = undefined;
            const prev_is_free: u2 = check: {
                if (found.sort_list_idx == 0) break :check 0;
                const prev_logical_sort_idx = found.sort_list_idx - 1;
                prev_logical_idx = self.segment_list.lookup_real_idx_from_sort_idx(.LOGICAL, prev_logical_sort_idx);
                prev_logical = self.segment_list.get(prev_logical_idx);
                break :check @as(u2, @intFromBool(prev_logical.is_free())) << 1;
            };
            const next_is_free: u2 = check: {
                if (found.sort_list_idx >= self.segment_list.get_sort_list_len(.LOGICAL) - 1) break :check 0;
                const next_logical_sort_idx = found.sort_list_idx + 1;
                next_logical_idx = self.segment_list.lookup_real_idx_from_sort_idx(.LOGICAL, next_logical_sort_idx);
                next_logical = self.segment_list.get(next_logical_idx);
                break :check @as(u2, @intFromBool(next_logical.is_free()));
            };
            const branch = prev_is_free | next_is_free;
            switch (branch) {
                COMBINE__xxxx_THIS_xxxx => {
                    found_segment.set_free();
                    self.segment_list.set(found.real_idx, found_segment, alloc);
                    self.debug_logical_no_gaps(@src()); //DEBUG
                },
                COMBINE__xxxx_THIS_NEXT => {
                    self.debug_logical_no_gaps(@src()); //DEBUG
                    self.debug_print_nearby_logicals(found.sort_list_idx, "RELEASE COMBINE THIS+NEXT: START", @src()); //DEBUG
                    std.debug.print("found_len = {d}\nnext_logical_len = {d}\nexpected new = {d}\n", .{ found_len, next_logical.get_len(), found_len + next_logical.get_len() }); //DEBUG
                    next_logical.start -= found_len;
                    next_logical.incr_len(found_len);
                    self.segment_list.set(next_logical_idx, next_logical, alloc);
                    self.debug_print_nearby_logicals(found.sort_list_idx, "RELEASE COMBINE THIS+NEXT: AFTER SET NEXT", @src()); //DEBUG
                    self.segment_list.delete(found.real_idx);
                    self.debug_print_nearby_logicals(found.sort_list_idx, "RELEASE COMBINE THIS+NEXT: AFTER DELETE THIS", @src()); //DEBUG
                    // self.segment_list.set_1_delete_1(next_logical_idx, next_logical, found.real_idx, alloc);
                    self.debug_logical_no_gaps(@src()); //DEBUG
                },
                COMBINE__PREV_THIS_xxxx => {
                    self.debug_logical_no_gaps(@src()); //DEBUG
                    self.debug_print_nearby_logicals(found.sort_list_idx, "RELEASE COMBINE PREV+THIS: START", @src()); //DEBUG
                    std.debug.print("found_len = {d}\nprev_logical_len = {d}\nexpected new = {d}\n", .{ found_len, prev_logical.get_len(), found_len + prev_logical.get_len() }); //DEBUG
                    prev_logical.incr_len(found_len);
                    self.segment_list.set(prev_logical_idx, prev_logical, alloc);
                    self.debug_print_nearby_logicals(found.sort_list_idx, "RELEASE COMBINE PREV+THIS: AFTER SET PREV", @src()); //DEBUG
                    self.segment_list.delete(found.real_idx);
                    // self.segment_list.set_1_delete_1(prev_logical_idx, prev_logical, found.real_idx, alloc);
                    self.debug_print_nearby_logicals(found.sort_list_idx, "RELEASE COMBINE PREV+THIS: AFTER DELETE THIS", @src()); //DEBUG
                    self.debug_logical_no_gaps(@src()); //DEBUG
                },
                COMBINE__PREV_THIS_NEXT => {
                    prev_logical.incr_len(found_len + next_logical.get_len());
                    self.segment_list.set_1_delete_2(prev_logical_idx, prev_logical, found.real_idx, next_logical_idx, alloc);
                    self.debug_logical_no_gaps(@src()); //DEBUG
                },
            }
        }

        /// Resize (grow OR shrink) an allocated segment, returning the new
        /// segment
        ///
        /// May invalidate existing data slices or pointers
        pub fn resize_segment(self: *Self, seg: Segment, new_len: usize, alloc: Allocator) Segment {
            @setEvalBranchQuota(4000);
            if (new_len == seg.len) return seg;
            Assert.assert_with_reason(new_len > 0, @src(), "new_len MUST be greater than 0. To free a segment, use release_segment()", .{});
            var found = self.segment_list.find_idx_for_exact_value_using_sort(.LOGICAL, seg.to_internal_seg()) orelse Assert.assert_unreachable(@src(), "attempted to release list segment that was not found in list: data_len: {d}, segment: {any}", .{ self.data.len, seg });
            var found_segment = self.segment_list.get(found.real_idx);
            const found_len = found_segment.get_len();
            std.debug.print("found_idx = {any}\nfound_seg = {any}\n", .{ found, found_segment }); //DEBUG
            Assert.assert_with_reason(!found_segment.is_free(), @src(), "attempted to resize list segment that was already free: segment = {any}", .{seg});
            var prev_logical: SegmentInternal = undefined;
            var next_logical: SegmentInternal = undefined;
            var prev_logical_idx: usize = undefined;
            var next_logical_idx: usize = undefined;
            var next_logical_len: u32 = 0;
            var prev_logical_len: u32 = 0;
            const shrink = new_len < found_len;
            if (shrink) {
                const delta = found_len - Types.intcast(new_len, u32);
                const next_is_free: bool = check: {
                    if (found.sort_list_idx >= self.segment_list.get_sort_list_len(.LOGICAL) - 1) break :check false;
                    const next_logical_sort_idx = found.sort_list_idx + 1;
                    next_logical_idx = self.segment_list.lookup_real_idx_from_sort_idx(.LOGICAL, next_logical_sort_idx);
                    next_logical = self.segment_list.get(next_logical_idx);
                    break :check next_logical.is_free();
                };
                if (next_is_free) {
                    next_logical.start -= delta;
                    next_logical.incr_len(delta);
                    found_segment.decr_len(delta);
                    self.segment_list.set(found.real_idx, found_segment, alloc);
                    self.segment_list.set(next_logical_idx, next_logical, alloc);
                    return found_segment.to_alloc_seg();
                }
                const new_free = SegmentInternal{
                    .start = found_segment.start + Types.intcast(new_len, u32),
                    .len_and_free_flag = delta | SegmentInternal.FREE_BIT,
                };
                found_segment.decr_len(delta);
                self.segment_list.set(found.real_idx, found_segment, alloc);
                _ = self.segment_list.append_1_initialized(new_free, alloc);
                return found_segment.to_alloc_seg();
            } else {
                const delta = Types.intcast(new_len, u32) - found_len;
                check_next: {
                    if (found.sort_list_idx >= self.segment_list.get_sort_list_len(.LOGICAL) - 1) break :check_next;
                    const next_logical_sort_idx = found.sort_list_idx + 1;
                    next_logical_idx = self.segment_list.lookup_real_idx_from_sort_idx(.LOGICAL, next_logical_sort_idx);
                    next_logical = self.segment_list.get(next_logical_idx);
                    const next_free = next_logical.is_free();
                    next_logical_len = if (next_free) next_logical.get_len() else 0;
                    break :check_next;
                }
                const next_has_enough = next_logical_len >= delta;
                if (next_has_enough) {
                    std.debug.print("\nbranch: next_has_enough ", .{}); //DEBUG
                    next_logical.start += delta;
                    next_logical.decr_len(delta);
                    found_segment.incr_len(delta);
                    if (next_logical.is_zero_len_and_free()) {
                        std.debug.print("set_1_delete_1\n", .{}); //DEBUG
                        self.segment_list.set_1_delete_1(found.real_idx, found_segment, next_logical_idx, alloc);
                    } else {
                        std.debug.print("set set\n", .{}); //DEBUG
                        self.segment_list.set(found.real_idx, found_segment, alloc);
                        self.segment_list.set(next_logical_idx, next_logical, alloc);
                    }
                    return found_segment.to_alloc_seg();
                }
                check_prev: {
                    if (found.sort_list_idx == 0) break :check_prev;
                    const prev_logical_sort_idx = found.sort_list_idx - 1;
                    prev_logical_idx = self.segment_list.lookup_real_idx_from_sort_idx(.LOGICAL, prev_logical_sort_idx);
                    prev_logical = self.segment_list.get(prev_logical_idx);
                    const prev_free = prev_logical.is_free();
                    prev_logical_len = if (prev_free) prev_logical.get_len() else 0;
                    break :check_prev;
                }
                const prev_has_enough = prev_logical_len >= delta;
                if (prev_has_enough) {
                    std.debug.print("\nbranch prev_has_enough ", .{}); //DEBUG
                    const old_start = found_segment.start;
                    prev_logical.decr_len(delta);
                    found_segment.start -= delta;
                    found_segment.incr_len(delta);
                    @memmove(self.data.ptr[found_segment.start .. found_segment.start + found_len], self.data.ptr[old_start .. old_start + found_len]);
                    if (prev_logical.is_zero_len_and_free()) {
                        std.debug.print("set_1_delete_1\n", .{}); //DEBUG
                        self.segment_list.set_1_delete_1(found.real_idx, found_segment, prev_logical_idx, alloc);
                    } else {
                        std.debug.print("set set\n", .{}); //DEBUG
                        self.segment_list.set(found.real_idx, found_segment, alloc);
                        self.segment_list.set(prev_logical_idx, prev_logical, alloc);
                    }
                    return found_segment.to_alloc_seg();
                }
                const next_plus_prev_have_enough = next_logical_len + prev_logical_len >= delta;
                if (next_plus_prev_have_enough) {
                    std.debug.print("\nbranch next_plus_prev_have_enough ", .{}); //DEBUG
                    // std.debug.print("\nseg_idx: {d}\nseg_logical_idx: {d}\nseg_list_len: {d}\nseg_sort_list_len: {d}\n", .{
                    //     found.real_idx,
                    //     found.sort_list_idx,
                    //     self.segment_list.primary_list.len,
                    //     self.segment_list.sort_lists[@intFromEnum(SORT_NAMES.LOGICAL)].idx_list.len,
                    // }); //DEBUG
                    @memmove(self.data.ptr[prev_logical.start .. prev_logical.start + found_len], self.data.ptr[found_segment.start .. found_segment.start + found_len]);
                    const delta_leftover = delta - prev_logical_len;
                    next_logical.start += delta_leftover;
                    next_logical.decr_len(delta_leftover);
                    prev_logical.len_and_free_flag = Types.intcast(new_len, u32);
                    if (next_logical.is_zero_len_and_free()) {
                        std.debug.print("set_1_delete_2\n", .{}); //DEBUG
                        self.segment_list.set_1_delete_2(prev_logical_idx, prev_logical, found.real_idx, next_logical_idx, alloc);
                    } else {
                        std.debug.print("set set_1_delete_1\n", .{}); //DEBUG
                        self.segment_list.set(next_logical_idx, next_logical, alloc);
                        self.segment_list.set_1_delete_1(prev_logical_idx, prev_logical, found.real_idx, alloc);
                    }
                    return prev_logical.to_alloc_seg();
                }
                std.debug.print("\nbranch realloc\n", .{}); //DEBUG
                self.debug_print_nearby_logicals(found.sort_list_idx, "REALLOC BRANCH BRFORE CLAIM NEW", @src()); //DEBUG
                const new_claim = self.claim_segment_with_location(new_len, alloc);
                const new_seg = new_claim.seg;
                self.debug_print_nearby_logicals(new_claim.logical, "REALLOC BRANCH CLAIMED SEGMENT", @src()); //DEBUG
                std.debug.print("need {d}, claimed_seg: {any}, claimed_ridx = {d}, claimed_logical = {d}", .{ new_len, new_seg, new_claim.real_idx, new_claim.logical }); //DEBUG
                self.debug_logical_no_gaps(@src()); //DEBUG
                self.debug_print_nearby_logicals(found.sort_list_idx, "REALLOC BRANCH BRFORE RELEASE OLD", @src()); //DEBUG
                @memcpy(self.data.ptr[new_seg.start .. new_seg.start + found_len], self.data.ptr[found_segment.start .. found_segment.start + found_len]);
                if (new_claim.logical < found.sort_list_idx and !new_claim.claimed_entire_free) {
                    found.sort_list_idx += 1;
                }
                self.release_segment_known(found, found_segment, found_len, alloc);
                self.debug_print_nearby_logicals(found.sort_list_idx, "REALLOC BRANCH AFTER RELEASE OLD", @src()); //DEBUG
                self.debug_logical_no_gaps(@src()); //DEBUG
                return new_seg;
            }
        }

        fn debug_logical_no_gaps(self: *Self, comptime src: std.builtin.SourceLocation) void {
            const logical_indexes = self.segment_list.sort_lists[@intFromEnum(SORT_NAMES.LOGICAL)].idx_list;
            var offset: u32 = 0;
            for (logical_indexes.ptr[0..logical_indexes.len], 0..) |idx, idx_idx| {
                const seg = self.segment_list.primary_list.ptr[idx];
                Assert.assert_with_reason(seg.start == offset, src, "there was a gap in between logical segments:\nexp segment offset = {d}\ngot segment offset = {d}\nlogical idx = {d}, segment count: {d},", .{ offset, seg.start, idx_idx, self.segment_list.primary_list.len });
                offset += seg.get_len();
            }
        }

        fn debug_print_nearby_logicals(self: *Self, logical_sort_idx: usize, comptime CONTEXT: []const u8, comptime src: std.builtin.SourceLocation) void {
            const logical_indexes = self.segment_list.sort_lists[@intFromEnum(SORT_NAMES.LOGICAL)].idx_list;
            const USED = [5]u8{ 'U', 'S', 'E', 'D', ' ' };
            const FREE = [5]u8{ 'F', 'R', 'E', 'E', ' ' };
            var buf_1: [107]u8 = @splat(' ');
            var buf_2: [107]u8 = @splat(' ');
            var buf_3: [107]u8 = @splat(' ');
            var buf_4: [107]u8 = @splat(' ');
            var buf_5: [107]u8 = @splat(' ');
            buf_1[106] = '\n';
            buf_2[106] = '\n';
            buf_3[106] = '\n';
            buf_4[106] = '\n';
            buf_5[106] = '\n';
            const idx_1 = logical_sort_idx -| 2;
            const idx_2 = idx_1 + 1;
            const idx_3 = idx_1 + 2;
            const idx_4 = idx_1 + 3;
            const idx_5 = idx_1 + 4;
            const idx_2_in_range = idx_2 < logical_indexes.len;
            const idx_3_in_range = idx_3 < logical_indexes.len;
            const idx_4_in_range = idx_4 < logical_indexes.len;
            const idx_5_in_range = idx_5 < logical_indexes.len;
            const real_idx_1 = logical_indexes.ptr[idx_1];
            const real_idx_2 = if (idx_2_in_range) logical_indexes.ptr[idx_2] else real_idx_1;
            const real_idx_3 = if (idx_3_in_range) logical_indexes.ptr[idx_3] else real_idx_2;
            const real_idx_4 = if (idx_4_in_range) logical_indexes.ptr[idx_4] else real_idx_3;
            const real_idx_5 = if (idx_5_in_range) logical_indexes.ptr[idx_5] else real_idx_4;
            const seg_1 = self.segment_list.primary_list.ptr[real_idx_1];
            const seg_2 = self.segment_list.primary_list.ptr[real_idx_2];
            const seg_3 = self.segment_list.primary_list.ptr[real_idx_3];
            const seg_4 = self.segment_list.primary_list.ptr[real_idx_4];
            const seg_5 = self.segment_list.primary_list.ptr[real_idx_5];
            const seg_1_len = seg_1.get_len();
            const seg_2_len = seg_2.get_len();
            const seg_3_len = seg_3.get_len();
            const seg_4_len = seg_4.get_len();
            const seg_5_len = seg_5.get_len();
            const start_addr = @min(seg_1.start, seg_2.start, seg_3.start, seg_4.start, seg_5.start);
            const end_addr = @max(seg_1.start + seg_1_len, seg_2.start + seg_2_len, seg_3.start + seg_3_len, seg_4.start + seg_4_len, seg_5.start + seg_5_len);
            const total_span_len = end_addr - start_addr;
            const total_span_len_f = Types.floatcast(total_span_len, f32);
            const seg_1_share_f: f32 = Types.floatcast(seg_1_len, f32) / total_span_len_f;
            const seg_2_share_f: f32 = Types.floatcast(seg_2_len, f32) / total_span_len_f;
            const seg_3_share_f: f32 = Types.floatcast(seg_3_len, f32) / total_span_len_f;
            const seg_4_share_f: f32 = Types.floatcast(seg_4_len, f32) / total_span_len_f;
            const seg_5_share_f: f32 = Types.floatcast(seg_5_len, f32) / total_span_len_f;
            const seg_1_share: u32 = @max(1, Types.intcast(seg_1_share_f * 100.0, u32));
            const seg_2_share: u32 = @max(1, Types.intcast(seg_2_share_f * 100.0, u32));
            const seg_3_share: u32 = @max(1, Types.intcast(seg_3_share_f * 100.0, u32));
            const seg_4_share: u32 = @max(1, Types.intcast(seg_4_share_f * 100.0, u32));
            const seg_5_share: u32 = @max(1, Types.intcast(seg_5_share_f * 100.0, u32));
            const seg_1_start_f: f32 = Types.floatcast(seg_1.start - start_addr, f32) / total_span_len_f;
            const seg_2_start_f: f32 = Types.floatcast(seg_2.start - start_addr, f32) / total_span_len_f;
            const seg_3_start_f: f32 = Types.floatcast(seg_3.start - start_addr, f32) / total_span_len_f;
            const seg_4_start_f: f32 = Types.floatcast(seg_4.start - start_addr, f32) / total_span_len_f;
            const seg_5_start_f: f32 = Types.floatcast(seg_5.start - start_addr, f32) / total_span_len_f;
            const seg_1_start: u32 = 5 + Types.intcast(seg_1_start_f * 100.0, u32);
            const seg_2_start: u32 = 5 + Types.intcast(seg_2_start_f * 100.0, u32);
            const seg_3_start: u32 = 5 + Types.intcast(seg_3_start_f * 100.0, u32);
            const seg_4_start: u32 = 5 + Types.intcast(seg_4_start_f * 100.0, u32);
            const seg_5_start: u32 = 5 + Types.intcast(seg_5_start_f * 100.0, u32);
            const seg_1_slice = buf_1[seg_1_start .. seg_1_start + seg_1_share];
            const seg_2_slice = buf_2[seg_2_start .. seg_2_start + seg_2_share];
            const seg_3_slice = buf_3[seg_3_start .. seg_3_start + seg_3_share];
            const seg_4_slice = buf_4[seg_4_start .. seg_4_start + seg_4_share];
            const seg_5_slice = buf_5[seg_5_start .. seg_5_start + seg_5_share];
            const total_chars = 127 - 33;
            const seg_1_char: u8 = @intCast((real_idx_1 % total_chars) + 33);
            const seg_2_char: u8 = @intCast((real_idx_2 % total_chars) + 33);
            const seg_3_char: u8 = @intCast((real_idx_3 % total_chars) + 33);
            const seg_4_char: u8 = @intCast((real_idx_4 % total_chars) + 33);
            const seg_5_char: u8 = @intCast((real_idx_5 % total_chars) + 33);
            @memset(seg_1_slice, seg_1_char);
            @memset(seg_2_slice, seg_2_char);
            @memset(seg_3_slice, seg_3_char);
            @memset(seg_4_slice, seg_4_char);
            @memset(seg_5_slice, seg_5_char);
            if (seg_1.is_free()) {
                @memcpy(buf_1[0..5], FREE[0..5]);
            } else {
                @memcpy(buf_1[0..5], USED[0..5]);
            }
            if (seg_2.is_free()) {
                @memcpy(buf_2[0..5], FREE[0..5]);
            } else {
                @memcpy(buf_2[0..5], USED[0..5]);
            }
            if (seg_3.is_free()) {
                @memcpy(buf_3[0..5], FREE[0..5]);
            } else {
                @memcpy(buf_3[0..5], USED[0..5]);
            }
            if (seg_4.is_free()) {
                @memcpy(buf_4[0..5], FREE[0..5]);
            } else {
                @memcpy(buf_4[0..5], USED[0..5]);
            }
            if (seg_5.is_free()) {
                @memcpy(buf_5[0..5], FREE[0..5]);
            } else {
                @memcpy(buf_5[0..5], USED[0..5]);
            }
            std.debug.print("\nLogical Index {d} → [{s}] → {s}\n", .{ logical_sort_idx, Utils.print_src_location(src), CONTEXT });
            std.debug.print("R_IDX {d: <3}, L_IDX {d: <3}, ADDR {d: <4}, LEN {d: <3}, END {d: <4} {s}", .{ real_idx_1, idx_1, seg_1.start, seg_1_len, seg_1.start + seg_1_len, buf_1 });
            if (idx_2_in_range) std.debug.print("R_IDX {d: <3}, L_IDX {d: <3}, ADDR {d: <4}, LEN {d: <3}, END {d: <4} {s}", .{ real_idx_2, idx_2, seg_2.start, seg_2_len, seg_2.start + seg_2_len, buf_2 });
            if (idx_3_in_range) std.debug.print("R_IDX {d: <3}, L_IDX {d: <3}, ADDR {d: <4}, LEN {d: <3}, END {d: <4} {s}", .{ real_idx_3, idx_3, seg_3.start, seg_3_len, seg_3.start + seg_3_len, buf_3 });
            if (idx_4_in_range) std.debug.print("R_IDX {d: <3}, L_IDX {d: <3}, ADDR {d: <4}, LEN {d: <3}, END {d: <4} {s}", .{ real_idx_4, idx_4, seg_4.start, seg_4_len, seg_4.start + seg_4_len, buf_4 });
            if (idx_5_in_range) std.debug.print("R_IDX {d: <3}, L_IDX {d: <3}, ADDR {d: <4}, LEN {d: <3}, END {d: <4} {s}", .{ real_idx_5, idx_5, seg_5.start, seg_5_len, seg_5.start + seg_5_len, buf_5 });
        }

        /// Return the backing list to an empty state, but retain the allocated
        /// memory for future segment allocations
        pub fn clear(self: *Self) void {
            self.data.clear();
            self.segment_list.clear();
        }

        /// Free the entire ListSegmentAllocator back to the backing Allocator
        pub fn free(self: *Self, alloc: Allocator) void {
            self.data.free(alloc);
            self.segment_list.free(alloc);
        }

        pub const Internal = struct {
            pub fn debug_print_nearby_logicals(self: *Self, logical_sort_idx: usize, comptime CONTEXT: []const u8, comptime src: std.builtin.SourceLocation) void {
                self.debug_print_nearby_logicals(logical_sort_idx, CONTEXT, src);
            }
        };
    };
}
