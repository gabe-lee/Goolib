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
const Root = @import("./_root.zig");
const opts = @import("opts");
const Random = std.Random;
const math = std.math;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const SliceAdapter = Root.IList_SliceAdapter.SliceAdapter;
const Assert = Root.Assert;
const Types = Root.Types;
const IList = Root.IList;
const Fuzz = Root.DiffFuzz;
const Utils = Root.Utils;

const LARGEST_LEN: usize = 1023;
const LARGEST_COPY: usize = 127;

pub const Error = error{
    len_mismatch,
    valid_first_idx_in_empty_list,
    valid_last_idx_in_empty_list,
    invalid_first_idx_in_filled_list,
    invalid_last_idx_in_filled_list,
    invalid_idx_in_middle_of_list_traversing_forward,
    invalid_idx_in_middle_of_list_traversing_backward,
    value_mismatch,
    pointer_mismatch,
    valid_idx_beyond_list_len,
    valid_idx_before_list_start,
    cap_less_than_len,
    invalid_range_reported_valid,
    valid_range_reported_invalid,
    invalid_idx_reported_valid,
    valid_idx_reported_invalid,
    always_invalid_idx_was_valid,
    split_range_idx_wasnt_between_ends,
    range_len_incorrect_result,
    ensure_free_slots_didnt_result_in_enough_capacity,
    append_returned_invalid_range,
    insert_returned_invalid_range,
    append_count_zero_returned_valid_range,
    insert_count_zero_returned_valid_range,
};

pub const SLICE_ADAPTER_U8_ALLOC = make_slice_adapter_alloc_test(u8);

pub fn make_slice_adapter_alloc_test(comptime T: type) Fuzz.FuzzTest {
    const PROTO = struct {
        const T_IList = Root.IList.IList(T);
        const T_List = std.ArrayList(T);
        const STATE = struct {
            ref_list: T_List,
            test_list: T_IList,
            slice_adapter: SliceAdapter(T).AdapterWithAlloc,
        };
        pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
            var state = try alloc.create(STATE);
            state.ref_list = try T_List.initCapacity(alloc, LARGEST_LEN);
            var s: []T = undefined;
            s.len = 0;
            state.slice_adapter = SliceAdapter(T).adapt_with_alloc(s, alloc);
            state.test_list = state.slice_adapter.interface();
            state_opaque.* = @ptrCast(state);
        }
        pub fn START_SEED(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            var state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = rand.uintLessThan(usize, 256);
            state.ref_list.clearRetainingCapacity();
            if (alloc.remap(state.slice_adapter.slice, len)) |new| {
                state.slice_adapter.slice = new;
            } else {
                alloc.free(state.slice_adapter.slice);
                state.slice_adapter.slice = try alloc.alloc(u8, len);
            }
            try state.ref_list.ensureTotalCapacity(alloc, len);
            state.ref_list.items.len = len;
            if (len > 0) {
                rand.bytes(state.ref_list.items);
                @memcpy(state.slice_adapter.slice[0..len], state.ref_list.items[0..len]);
            }
            return _OPS.verify_whole_state(state);
        }

        pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            state.ref_list.clearAndFree(alloc);
            alloc.free(state.slice_adapter.slice);
            alloc.destroy(state);
        }

        const _OPS = make_op_table(T, STATE, 0);
        pub const OPS = _OPS.OPS;
    };
    return Fuzz.FuzzTest{
        .options = Fuzz.FuzzOptions{
            .name = "IList_SliceAdapter_" ++ @typeName(T),
        },
        .init_func = PROTO.INIT,
        .start_seed_func = PROTO.START_SEED,
        .op_table = PROTO.OPS[0..],
        .deinit_func = PROTO.DEINIT,
    };
}

pub fn make_op_table(comptime T: type, comptime STATE: type, comptime UNINIT: T) type {
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "ref_list", std.ArrayList(T)), @src(), "to use this automatic op generator, type `STATE` must have a field named `ref_list` that is of type `ArrayList({s})`", .{@typeName(T)});
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "test_list", IList.IList(T)), @src(), "to use this automatic op generator, type `STATE` must have a field named `test_list` that is of type `IList({s})`", .{@typeName(T)});
    return struct {
        fn verify_whole_state(state: *STATE) ?anyerror {
            if (state.ref_list.items.len != state.test_list.len()) return Error.len_mismatch;
            if (state.test_list.cap() < state.test_list.len()) return Error.cap_less_than_len;
            if (state.ref_list.items.len == 0) {
                if (state.test_list.idx_valid(state.test_list.first_idx())) return Error.valid_first_idx_in_empty_list;
                if (state.test_list.idx_valid(state.test_list.last_idx())) return Error.valid_last_idx_in_empty_list;
            } else {
                if (!state.test_list.idx_valid(state.test_list.first_idx())) return Error.invalid_first_idx_in_filled_list;
                if (!state.test_list.idx_valid(state.test_list.last_idx())) return Error.invalid_last_idx_in_filled_list;
            }
            var curr_idx = state.test_list.first_idx();
            var curr_n: usize = 0;
            while (curr_n < state.ref_list.items.len) {
                if (!state.test_list.idx_valid(curr_idx)) return Error.invalid_idx_in_middle_of_list_traversing_forward;
                const exp_val = state.ref_list.items[curr_n];
                const got_val = state.test_list.get(curr_idx);
                if (exp_val != got_val) return Error.value_mismatch;
                curr_n = curr_n + 1;
                curr_idx = state.test_list.next_idx(curr_idx);
            }
            if (state.test_list.idx_valid(curr_idx)) return Error.valid_idx_beyond_list_len;
            curr_idx = state.test_list.last_idx();
            while (curr_n > 0) {
                curr_n = curr_n - 1;
                if (!state.test_list.idx_valid(curr_idx)) return Error.invalid_idx_in_middle_of_list_traversing_backward;
                const exp_val = state.ref_list.items[curr_n];
                const got_val = state.test_list.get(curr_idx);
                if (exp_val != got_val) return Error.value_mismatch;

                curr_idx = state.test_list.prev_idx(curr_idx);
            }
            if (state.test_list.idx_valid(curr_idx)) return Error.valid_idx_before_list_start;
            curr_idx = state.test_list.first_idx();
            curr_n = 0;
            if (state.test_list.idx_valid(state.test_list.vtable.always_invalid_idx)) return Error.always_invalid_idx_was_valid;
            return null;
        }

        fn get_nth(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_list.items.len);
            const idx = state.test_list.nth_idx(n);
            const exp_val = state.ref_list.items[n];
            const got_val = state.test_list.get(idx);
            if (exp_val != got_val) return Error.value_mismatch;
            return verify_whole_state(state);
        }
        fn get_nth_ptr(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_list.items.len);
            const idx = state.test_list.nth_idx(n);
            const exp_val = state.ref_list.items[n];
            const got_ptr = state.test_list.get_ptr(idx);
            const got_val = got_ptr.*;
            if (exp_val != got_val) return Error.value_mismatch;
            got_ptr.* = 42;
            const got_val_2 = state.test_list.get(idx);
            if (got_val_2 != 42) return Error.pointer_mismatch;
            got_ptr.* = exp_val;
            const got_val_3 = state.test_list.get(idx);
            if (got_val_3 != exp_val) return Error.pointer_mismatch;
            return verify_whole_state(state);
        }
        fn set_nth(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_list.items.len);
            var b: [1]u8 = undefined;
            rand.bytes(b[0..1]);
            const idx = state.test_list.nth_idx(n);
            state.ref_list.items[n] = b[0];
            state.test_list.set(idx, b[0]);
            return verify_whole_state(state);
        }
        fn check_nth_idx(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const n = rand.uintLessThan(usize, 1 + (state.ref_list.items.len * 2));
            const idx_1 = state.test_list.nth_idx(n);
            const idx_2 = state.test_list.nth_idx_from_end(n);
            if (n >= state.ref_list.items.len) {
                if (state.test_list.idx_valid(idx_1)) return Error.valid_idx_beyond_list_len;
                if (state.test_list.idx_valid(idx_2)) return Error.valid_idx_before_list_start;
            } else {
                if (!state.test_list.idx_valid(idx_1)) return Error.invalid_idx_in_middle_of_list_traversing_forward;
                if (!state.test_list.idx_valid(idx_2)) return Error.invalid_idx_in_middle_of_list_traversing_backward;
            }
            return verify_whole_state(state);
        }
        pub fn idx_range_valid(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const n1 = rand.uintAtMost(usize, state.ref_list.items.len * 2);
            const n2 = rand.uintAtMost(usize, state.ref_list.items.len * 2);
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            if (n1 >= state.ref_list.items.len and state.test_list.idx_valid(idx_1)) {
                return Error.invalid_idx_reported_valid;
            } else if (n1 < state.ref_list.items.len and !state.test_list.idx_valid(idx_1)) {
                return Error.valid_idx_reported_invalid;
            }
            if (n2 >= state.ref_list.items.len and state.test_list.idx_valid(idx_2)) {
                return Error.invalid_idx_reported_valid;
            } else if (n2 < state.ref_list.items.len and !state.test_list.idx_valid(idx_2)) {
                return Error.valid_idx_reported_invalid;
            }
            if (n1 > n2 or n1 >= state.ref_list.items.len or n2 >= state.ref_list.items.len) {
                if (state.test_list.range_valid(.new_range(idx_1, idx_2))) return Error.invalid_range_reported_valid;
            } else if (n1 <= n2 and n1 < state.ref_list.items.len and n2 < state.ref_list.items.len) {
                if (!state.test_list.range_valid(.new_range(idx_1, idx_2))) return Error.valid_range_reported_invalid;
            }
            return verify_whole_state(state);
        }
        pub fn split_range(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            var n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            var n2 = rand.uintLessThan(usize, state.ref_list.items.len);
            if (n1 > n2) {
                const tmp = n2;
                n2 = n1;
                n1 = tmp;
            }
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_3: usize = state.test_list.nth_idx(n2);
            const idx_2: usize = state.test_list.split_range(.new_range(idx_1, idx_3));
            var idx_x = idx_1;
            while (true) {
                if (idx_x == idx_2) break;
                if (idx_x == idx_3) return Error.split_range_idx_wasnt_between_ends;
                idx_x = state.test_list.next_idx(idx_x);
                if (!state.test_list.idx_valid(idx_x)) return Error.split_range_idx_wasnt_between_ends;
            }
            return verify_whole_state(state);
        }
        pub fn move(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            const n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            const n2 = rand.uintLessThan(usize, state.ref_list.items.len);
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            Utils.slice_move_one(state.ref_list.items, n1, n2);
            state.test_list.move(idx_1, idx_2);
            return verify_whole_state(state);
        }
        pub fn move_range(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            var n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            var n2 = rand.uintLessThan(usize, state.ref_list.items.len);

            if (n1 > n2) {
                const tmp = n2;
                n2 = n1;
                n1 = tmp;
            }
            const delta = n2 - n1;
            const n3 = rand.uintLessThan(usize, state.ref_list.items.len - delta);
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            const idx_3: usize = state.test_list.nth_idx(n3);
            Utils.slice_move_many(state.ref_list.items, n1, n2, n3);
            state.test_list.move_range(.new_range(idx_1, idx_2), idx_3);
            return verify_whole_state(state);
        }
        pub fn range_len(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            var n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            var n2 = rand.uintLessThan(usize, state.ref_list.items.len);
            if (n1 > n2) {
                const tmp = n2;
                n2 = n1;
                n1 = tmp;
            }
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            const rlen = state.test_list.range_len(.new_range(idx_1, idx_2));
            if (rlen != ((n2 - n1) + 1)) return Error.range_len_incorrect_result;
            return verify_whole_state(state);
        }
        pub fn ensure_free_slots(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const count = rand.uintLessThan(usize, LARGEST_COPY);
            state.ref_list.ensureUnusedCapacity(alloc, count) catch |err| return err;
            const did_ensure = state.test_list.try_ensure_free_slots(count);
            if (did_ensure and !state.test_list.ensure_free_doesnt_change_cap() and (state.test_list.cap() - state.test_list.len() < count)) return Error.ensure_free_slots_didnt_result_in_enough_capacity;
            return verify_whole_state(state);
        }
        pub fn append_slots(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const count = @max(1, rand.uintLessThan(usize, LARGEST_COPY));
            const ref_append = try state.ref_list.addManyAt(alloc, state.ref_list.items.len, count);
            @memset(ref_append, UNINIT);
            const test_append = state.test_list.append_slots(count);
            if (count == 0) {
                if (state.test_list.range_valid(test_append)) {
                    return Error.append_count_zero_returned_valid_range;
                } else {
                    return verify_whole_state(state);
                }
            } else if (!state.test_list.range_valid(test_append)) return Error.append_returned_invalid_range;
            var idx_1 = test_append.first_idx;
            const idx_2 = test_append.last_idx;
            while (true) {
                state.test_list.set(idx_1, UNINIT);
                if (idx_1 == idx_2) break;
                idx_1 = state.test_list.next_idx(idx_1);
            }
            return verify_whole_state(state);
        }
        pub fn insert_slots(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return append_slots(rand, state, alloc);
            const count = @max(1, rand.uintLessThan(usize, LARGEST_COPY));
            const n = rand.uintLessThan(usize, state.ref_list.items.len);
            const idx = state.test_list.nth_idx(n);
            const ref_insert = try state.ref_list.addManyAt(alloc, n, count);
            @memset(ref_insert, UNINIT);
            const test_insert = state.test_list.insert_slots(idx, count);
            if (count == 0) {
                if (state.test_list.range_valid(test_insert)) {
                    return Error.insert_count_zero_returned_valid_range;
                } else {
                    return verify_whole_state(state);
                }
            } else if (!state.test_list.range_valid(test_insert)) return Error.insert_returned_invalid_range;
            var idx_1 = test_insert.first_idx;
            const idx_2 = test_insert.last_idx;
            while (true) {
                state.test_list.set(idx_1, UNINIT);
                if (idx_1 == idx_2) break;
                idx_1 = state.test_list.next_idx(idx_1);
            }
            return verify_whole_state(state);
        }
        pub fn delete_range(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            var n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            var n2 = rand.uintLessThan(usize, state.ref_list.items.len);
            if (n1 > n2) {
                const tmp = n2;
                n2 = n1;
                n1 = tmp;
            }
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            std.mem.copyForwards(T, state.ref_list.items[n1..], state.ref_list.items[n2 + 1 ..]);
            state.ref_list.items.len -= ((n2 - n1) + 1);
            state.test_list.delete_range(.new_range(idx_1, idx_2));
            return verify_whole_state(state);
        }
        pub fn clear(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            _ = alloc;
            _ = rand;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            state.ref_list.clearRetainingCapacity();
            state.test_list.clear();
            return verify_whole_state(state);
        }

        pub const OPS = [_]*const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator) ?anyerror{
            get_nth,
            get_nth_ptr,
            set_nth,
            check_nth_idx,
            idx_range_valid,
            split_range,
            move,
            move_range,
            range_len,
            ensure_free_slots,
            append_slots,
            insert_slots,
            delete_range,
            clear,
        };
    };
}
