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
const Random = std.Random;

const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;
const List = Root.IList_List.List;
const MSList = Root.IList.MultiSortList;
const LSAlloc = Root.ListSegmentAllocator;
const Fuzz = Root.Fuzz;

const INIT_CAP = 128;
const MAX_CAP = 1024;
const MAX_COPY = 128;

pub fn make_list_segment_allocator_test(comptime T: type) Fuzz.FuzzTest {
    const PROTO = struct {
        const REF_DATA = std.ArrayList(T);
        const SEG_LIST = std.ArrayList(LSAlloc.Segment);
        const LS_ALLOC = LSAlloc.ListSegmentAllocator(T);
        const STATE = struct {
            ref_data: REF_DATA,
            ref_segs: SEG_LIST,
            lsa_segs: SEG_LIST,
            ls_alloc: LS_ALLOC,
        };
        pub fn CLAIM_REF(state: *STATE, len: usize, alloc: Allocator) LSAlloc.Segment {
            const start: u32 = @intCast(state.ref_data.items.len);
            _ = state.ref_data.addManyAsSlice(alloc, len) catch unreachable;
            return LSAlloc.Segment{
                .start = start,
                .len = @intCast(len),
            };
        }
        pub fn RESIZE_REF(state: *STATE, seg: LSAlloc.Segment, new_len: usize, alloc: Allocator) LSAlloc.Segment {
            var start: u32 = @intCast(state.ref_data.items.len);
            const new_slice = state.ref_data.addManyAsSlice(alloc, new_len) catch unreachable;
            const old_slice = state.ref_data.items[seg.start .. seg.start + seg.len];
            const n = @min(new_slice.len, old_slice.len);
            @memcpy(new_slice[0..n], old_slice[0..n]);
            for (state.ref_segs.items) |*s| {
                if (s.start > seg.start) {
                    s.start = s.start - seg.len;
                }
            }
            Utils.mem_remove(state.ref_data.items.ptr, &state.ref_data.items.len, @intCast(seg.start), @intCast(seg.len));
            start -= seg.len;
            return LSAlloc.Segment{
                .start = start,
                .len = @intCast(new_len),
            };
        }
        pub fn RELEASE_REF(state: *STATE, seg: LSAlloc.Segment) void {
            for (state.ref_segs.items) |*s| {
                if (s.start > seg.start) {
                    s.start = s.start - seg.len;
                }
            }
            Utils.mem_remove(state.ref_data.items.ptr, &state.ref_data.items.len, @intCast(seg.start), @intCast(seg.len));
        }
        pub fn verify_data_integrity(state: *STATE, comptime op_name: []const u8, alloc: Allocator) ?[]const u8 {
            if (state.ref_segs.items.len != state.lsa_segs.items.len) {
                return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: reference segment list len {d} did not match LSA segment list len {d}", .{ op_name, state.ref_segs.items.len, state.lsa_segs.items.len });
            }
            for (state.ref_segs.items, state.lsa_segs.items) |ref_seg, lsa_seg| {
                if (ref_seg.start + ref_seg.len > state.ref_data.items.len) {
                    return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: reference segment {any} extends beyond reference data list len {d}", .{ op_name, ref_seg, state.ref_data.items.len });
                }
                if (lsa_seg.start + lsa_seg.len > state.ls_alloc.data.len) {
                    return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: allocated segment {any} extends beyond LSA data len {d}", .{ op_name, lsa_seg, state.ls_alloc.data.len });
                }
                if (lsa_seg.len != ref_seg.len) {
                    return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: reference segment len ({d}) did not match the equivalent lsa segment len ({d})", .{ op_name, lsa_seg.len, ref_seg.len });
                }
                const ref_slice = state.ref_data.items[ref_seg.start .. ref_seg.start + ref_seg.len];
                const lsa_slice = state.ls_alloc.get_slice(lsa_seg.start, lsa_seg.len);
                if (ref_slice.len != lsa_slice.len) {
                    return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: reference data slice len ({d}) did not match LSA data slice len ({d})", .{ op_name, ref_slice.len, lsa_slice.len });
                }
                for (ref_slice, lsa_slice, 0..) |r, l, i| {
                    if (r != l) {
                        const i_0 = i -| 2;
                        const i_1 = i -| 1;
                        const i_2 = i;
                        const i_3 = @min(i + 1, ref_slice.len);
                        const i_4 = @min(i + 2, ref_slice.len);
                        if (T == u8) {
                            return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: reference data slice did not match LSA data slice (at index {d}):\nIDX: {d: >4} {d: >4} {d: >4} {d: >4} {d: >4}\nREF: {d: >4} {d: >4} {d: >4} {d: >4} {d: >4}\nLSA: {d: >4} {d: >4} {d: >4} {d: >4} {d: >4}", .{
                                op_name,
                                i,
                                i_0,
                                i_1,
                                i_2,
                                i_3,
                                i_4,
                                ref_slice[i_0],
                                ref_slice[i_1],
                                ref_slice[i_2],
                                ref_slice[i_3],
                                ref_slice[i_4],
                                lsa_slice[i_0],
                                lsa_slice[i_1],
                                lsa_slice[i_2],
                                lsa_slice[i_3],
                                lsa_slice[i_4],
                            });
                        } else {
                            return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: reference data slice did not match LSA data slice (at index {d}):\nIDX: {d: >4} {d: >4} {d: >4} {d: >4} {d: >4}\nREF: {any} {any} {any} {any} {any}\nLSA: {any} {any} {any} {any} {any}", .{
                                op_name,
                                i,
                                i_0,
                                i_1,
                                i_2,
                                i_3,
                                i_4,
                                ref_slice[i_0],
                                ref_slice[i_1],
                                ref_slice[i_2],
                                ref_slice[i_3],
                                ref_slice[i_4],
                                lsa_slice[i_0],
                                lsa_slice[i_1],
                                lsa_slice[i_2],
                                lsa_slice[i_3],
                                lsa_slice[i_4],
                            });
                        }
                    }
                }
                const find_seg_internal = LSAlloc.Internal.seg_to_seg_internal(lsa_seg);
                const found_seg_idx = state.ls_alloc.segment_list.find_idx_for_exact_value_using_sort(.LOGICAL, find_seg_internal) orelse {
                    var find_free_internal = find_seg_internal;
                    find_free_internal.len_and_free_flag |= 1 << 31;
                    const found_free_seg_idx = state.ls_alloc.segment_list.find_idx_for_exact_value_using_sort(.LOGICAL, find_free_internal) orelse {
                        var i: usize = 0;
                        while (i < state.ls_alloc.segment_list.primary_list.len) {
                            const ii = i + 2;
                            LS_ALLOC.Internal.debug_print_nearby_logicals(&state.ls_alloc, ii, "DUMPING FULL LOGICAL LIST", @src());
                            i += 5;
                        }
                        return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: failed to find segment {any} in list anywhere", .{ op_name, lsa_seg });
                    };
                    const found_free_seg = state.ls_alloc.segment_list.primary_list.ptr[found_free_seg_idx.real_idx];
                    return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: segment {any} should have been in a `used` state, but was found in a `free` state with internal data {any}", .{ op_name, lsa_seg, found_free_seg });
                };
                const found_seg = state.ls_alloc.segment_list.primary_list.ptr[found_seg_idx.real_idx];
                if (found_seg.is_free()) {
                    return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: segment {any} should have been in a `used` state, but was found in a `free` state with internal data {any}", .{ op_name, lsa_seg, found_seg });
                }
            }
            const logical_indexes = state.ls_alloc.segment_list.sort_lists[@intFromEnum(LSAlloc.SORT_NAMES.LOGICAL)].idx_list;
            var offset: u32 = 0;
            for (logical_indexes.ptr[0..logical_indexes.len], 0..) |idx, idx_idx| {
                const seg = state.ls_alloc.segment_list.primary_list.ptr[idx];
                if (seg.start != offset) {
                    return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: there was a gap in between logical segments: expected segment offset = {d}, got segment offset {d}, logical idx = {d}", .{ op_name, offset, seg.start, idx_idx });
                }
                offset += seg.get_len();
            }
            if (state.ls_alloc.data.len != offset) {
                return Utils.alloc_fail_str(alloc, @src(), "OP: {s}: total segment lengths added together ({d}) didn't add up to backing data length ({d}), last logical segment may be mis-sized: {any}", .{ op_name, offset, state.ls_alloc.data.len, state.ls_alloc.segment_list.primary_list.ptr[state.ls_alloc.segment_list.primary_list.len - 1] });
            }
            return null;
        }
        pub fn init(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
            var state = try alloc.create(STATE);
            state.ref_data = try REF_DATA.initCapacity(alloc, INIT_CAP);
            state.ref_segs = try SEG_LIST.initCapacity(alloc, INIT_CAP);
            state.lsa_segs = try SEG_LIST.initCapacity(alloc, INIT_CAP);
            state.ls_alloc = LS_ALLOC.init_capacity(INIT_CAP, INIT_CAP, alloc);
            state_opaque.* = @ptrCast(state);
        }
        pub fn start_seed(_: Random, state_opaque: *anyopaque, _: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
            var state: *STATE = @ptrCast(@alignCast(state_opaque));
            state.ref_data.clearRetainingCapacity();
            state.ls_alloc.clear();
            state.ref_segs.clearRetainingCapacity();
            state.lsa_segs.clearRetainingCapacity();
            return null;
        }
        pub fn deinit(state_opaque: *anyopaque, alloc: Allocator) void {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            state.ref_data.clearAndFree(alloc);
            state.ref_segs.clearAndFree(alloc);
            state.lsa_segs.clearAndFree(alloc);
            state.ls_alloc.free(alloc);
            alloc.destroy(state);
        }

        pub fn claim(rand: Random, state_opq: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
            var state: *STATE = @ptrCast(@alignCast(state_opq));
            const max_n = @min(MAX_COPY, MAX_CAP - state.ref_data.items.len);
            if (max_n == 0) return null;
            const n = @max(rand.uintAtMost(usize, max_n), 1);
            const ref_claim = CLAIM_REF(state, n, alloc);
            const lsa_claim = state.ls_alloc.claim_segment(n, alloc);
            state.ref_segs.append(alloc, ref_claim) catch unreachable;
            state.lsa_segs.append(alloc, lsa_claim) catch unreachable;
            const ref_slice = state.ref_data.items[ref_claim.start .. ref_claim.start + ref_claim.len];
            const lsa_slice = state.ls_alloc.data.ptr[lsa_claim.start .. lsa_claim.start + lsa_claim.len];
            rand.bytes(ref_slice);
            @memcpy(lsa_slice, ref_slice);
            return verify_data_integrity(state, "CLAIM", alloc);
        }
        pub fn resize(rand: Random, state_opq: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
            var state: *STATE = @ptrCast(@alignCast(state_opq));
            if (state.ref_segs.items.len == 0) return null;
            const max_add = @min(MAX_COPY, MAX_CAP - state.ref_data.items.len);
            const idx = rand.uintLessThan(usize, state.ref_segs.items.len);
            const curr_ref_seg = state.ref_segs.items.ptr[idx];
            const curr_lsa_seg = state.lsa_segs.items.ptr[idx];
            const curr_len: usize = @intCast(curr_ref_seg.len);
            const new_max_len = curr_len + max_add;
            const n = @max(rand.uintAtMost(usize, new_max_len), 1);
            const new_ref_seg = RESIZE_REF(state, curr_ref_seg, n, alloc);
            const new_lsa_seg = state.ls_alloc.resize_segment(curr_lsa_seg, n, alloc);
            state.ref_segs.items.ptr[idx] = new_ref_seg;
            state.lsa_segs.items.ptr[idx] = new_lsa_seg;
            const grow = curr_ref_seg.len < new_ref_seg.len;
            if (curr_ref_seg.len < new_ref_seg.len) {
                const delta = new_ref_seg.len - curr_ref_seg.len;
                const ref_new_slice = state.ref_data.items[new_ref_seg.start + new_ref_seg.len - delta .. new_ref_seg.start + new_ref_seg.len];
                const lsa_new_slice = state.ls_alloc.data.ptr[new_lsa_seg.start + new_lsa_seg.len - delta .. new_lsa_seg.start + new_lsa_seg.len];
                rand.bytes(ref_new_slice);
                @memcpy(lsa_new_slice, ref_new_slice);
            }
            if (grow) {
                return verify_data_integrity(state, "RESIZE (grow)", alloc);
            } else {
                return verify_data_integrity(state, "RESIZE (shrink)", alloc);
            }
        }
        pub fn release(rand: Random, state_opq: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
            var state: *STATE = @ptrCast(@alignCast(state_opq));
            if (state.ref_segs.items.len == 0) return null;
            const idx = rand.uintLessThan(usize, state.ref_segs.items.len);
            const curr_ref_seg = state.ref_segs.items.ptr[idx];
            const curr_lsa_seg = state.lsa_segs.items.ptr[idx];
            RELEASE_REF(state, curr_ref_seg);
            state.ls_alloc.release_segment(curr_lsa_seg, alloc);
            Utils.mem_remove(state.ref_segs.items.ptr, &state.ref_segs.items.len, idx, 1);
            Utils.mem_remove(state.lsa_segs.items.ptr, &state.lsa_segs.items.len, idx, 1);
            return verify_data_integrity(state, "RELEASE", alloc);
        }

        pub const OPS = [_]*const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8{
            claim,
            resize,
            release,
        };
    };
    return Fuzz.FuzzTest{
        .options = Fuzz.FuzzOptions{
            .name = "ListSegmentAllocator_" ++ @typeName(T),
        },
        .init_func = PROTO.init,
        .start_seed_func = PROTO.start_seed,
        .op_table = PROTO.OPS[0..],
        .deinit_func = PROTO.deinit,
    };
}
