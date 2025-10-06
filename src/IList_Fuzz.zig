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
        pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) ?anyerror {
            var state = alloc.create(STATE) catch |err| return err;
            state.ref_list = T_List.initCapacity(alloc, LARGEST_LEN) catch |err| return err;
            var s: []T = undefined;
            s.len = 0;
            state.slice_adapter = SliceAdapter(T).adapt_with_alloc(s, alloc);
            state.test_list = state.slice_adapter.interface();
            state_opaque.* = @ptrCast(state);
            return null;
        }
        pub fn START_SEED(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            var state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = rand.uintLessThan(usize, 256);
            state.ref_list.clearRetainingCapacity();
            if (alloc.remap(state.slice_adapter.slice, len)) |new| {
                state.slice_adapter.slice = new;
            } else {
                alloc.free(state.slice_adapter.slice);
                state.slice_adapter.slice = alloc.alloc(u8, len) catch |err| return err;
            }
            state.ref_list.ensureTotalCapacity(alloc, len) catch |err| return err;
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

        const _OPS = make_op_table(STATE);
        pub const OPS = _OPS.OPS;
    };
    return Fuzz.FuzzTest{
        .options = Fuzz.FuzzOptions{
            .name = "SliceAdapter_alloc_" ++ @typeName(T),
        },
        .init_func = PROTO.INIT,
        .start_seed_func = PROTO.START_SEED,
        .op_table = PROTO.OPS[0..],
        .deinit_func = PROTO.DEINIT,
    };
}

pub fn make_op_table(comptime STATE: type) type {
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
        pub const OPS = [_]*const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator) ?anyerror{
            get_nth,
            get_nth_ptr,
            set_nth,
            check_nth_idx,
        };
    };
}
