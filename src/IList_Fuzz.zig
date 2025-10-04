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
        const AUX_STATE = struct {
            is_init: bool = false,
            slice_adapter: SliceAdapter(u8).AdapterWithAlloc,
        };
        pub fn INIT(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?anyerror {
            const len = rand.uintLessThan(usize, 256);
            if (!state.aux_state.is_init) { //CHECKPOINT
                var state = alloc.create(Fuzz.OpaqueState.CONCRETE(T_List, T_IList, AUX_STATE));
                state.ref_obj.* = std.ArrayList(u8).initCapacity(alloc, len) catch |err| return err;
                const new_test_slice = alloc.alloc(u8, len) catch |err| return err;
                state.aux_state.slice_adapter = SliceAdapter(u8).adapt_with_alloc(new_test_slice, alloc);
                state.test_obj.* = state.aux_state.slice_adapter.interface();
                state.aux_state.is_init = true;
            } else {
                state.ref_obj.clearRetainingCapacity();
                if (alloc.remap(state.aux_state.slice_adapter.slice, len)) |new| {
                    state.aux_state.slice_adapter.slice = new;
                } else {
                    alloc.free(state.aux_state.slice_adapter.slice);
                    state.aux_state.slice_adapter.slice = alloc.alloc(u8, len) catch |err| return err;
                }
            }
            state.ref_obj.ensureTotalCapacity(alloc, len) catch |err| return err;
            state.ref_obj.items.len = len;
            if (len > 0) {
                rand.bytes(state.ref_obj.items);
                @memcpy(state.aux_state.slice_adapter.slice[0..len], state.ref_obj.items[0..len]);
                state.test_obj.* = state.aux_state.slice_adapter.interface();
            }
            return _OPS.verify_whole_state(state_opaque);
        }

        pub fn DEINIT(state_opaque: Fuzz.OpaqueState, alloc: Allocator) void {
            const state = state_opaque.open(T_List, T_IList, AUX_STATE);
            if (state.aux_state.is_init) {
                state.ref_obj.clearAndFree(alloc);
                alloc.free(state.aux_state.slice_adapter.slice);
            }
        }

        const _OPS = make_op_table(u8, AUX_STATE);
        pub const OPS = _OPS.OPS;
    };
    return Fuzz.FuzzTest{
        .options = Fuzz.FuzzOptions{
            .name = "SliceAdapter_alloc_" ++ @typeName(T),
        },
        .init_func = PROTO.INIT,
        .op_table = PROTO.OPS[0..],
        .deinit_func = PROTO.DEINIT,
    };
}

pub fn make_op_table(comptime T: type, comptime AUX_STATE: type) type {
    return struct {
        fn verify_whole_state(state_opq: Fuzz.OpaqueState) ?anyerror {
            const state = state_opq.open(std.ArrayList(T), IList.IList(T), AUX_STATE);
            _ = state.aux_state;
            if (state.ref_obj.items.len != state.test_obj.len()) return Error.len_mismatch;
            if (state.test_obj.cap() < state.test_obj.len()) return Error.cap_less_than_len;
            if (state.ref_obj.items.len == 0) {
                if (state.test_obj.idx_valid(state.test_obj.first_idx())) return Error.valid_first_idx_in_empty_list;
                if (state.test_obj.idx_valid(state.test_obj.last_idx())) return Error.valid_last_idx_in_empty_list;
            } else {
                if (!state.test_obj.idx_valid(state.test_obj.first_idx())) return Error.invalid_first_idx_in_filled_list;
                if (!state.test_obj.idx_valid(state.test_obj.last_idx())) return Error.invalid_last_idx_in_filled_list;
            }
            var curr_idx = state.test_obj.first_idx();
            var curr_n: usize = 0;
            while (curr_n < state.ref_obj.items.len) {
                if (!state.test_obj.idx_valid(curr_idx)) return Error.invalid_idx_in_middle_of_list_traversing_forward;
                const exp_val = state.ref_obj.items[curr_n];
                const got_val = state.test_obj.get(curr_idx);
                if (exp_val != got_val) return Error.value_mismatch;
                curr_n = curr_n + 1;
                curr_idx = state.test_obj.next_idx(curr_idx);
            }
            if (state.test_obj.idx_valid(curr_idx)) return Error.valid_idx_beyond_list_len;
            curr_idx = state.test_obj.last_idx();
            while (curr_n > 0) {
                curr_n = curr_n - 1;
                if (!state.test_obj.idx_valid(curr_idx)) return Error.invalid_idx_in_middle_of_list_traversing_backward;
                const exp_val = state.ref_obj.items[curr_n];
                const got_val = state.test_obj.get(curr_idx);
                if (exp_val != got_val) return Error.value_mismatch;

                curr_idx = state.test_obj.prev_idx(curr_idx);
            }
            if (state.test_obj.idx_valid(curr_idx)) return Error.valid_idx_before_list_start;
            curr_idx = state.test_obj.first_idx();
            curr_n = 0;

            return null;
        }

        fn get_nth(rand: Random, state_opq: Fuzz.OpaqueState, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state = state_opq.open(std.ArrayList(T), IList.IList(T), AUX_STATE);
            if (state.ref_obj.items.len == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_obj.items.len);
            const idx = state.test_obj.nth_idx(n);
            const exp_val = state.ref_obj.items[n];
            const got_val = state.test_obj.get(idx);
            if (exp_val != got_val) return Error.value_mismatch;
            return verify_whole_state(state_opq);
        }
        fn get_nth_ptr(rand: Random, state_opq: Fuzz.OpaqueState, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state = state_opq.open(std.ArrayList(T), IList.IList(T), AUX_STATE);
            if (state.ref_obj.items.len == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_obj.items.len);
            const idx = state.test_obj.nth_idx(n);
            const exp_val = state.ref_obj.items[n];
            const got_ptr = state.test_obj.get_ptr(idx);
            const got_val = got_ptr.*;
            if (exp_val != got_val) return Error.value_mismatch;
            got_ptr.* = 42;
            const got_val_2 = state.test_obj.get(idx);
            if (got_val_2 != 42) return Error.pointer_mismatch;
            got_ptr.* = exp_val;
            const got_val_3 = state.test_obj.get(idx);
            if (got_val_3 != exp_val) return Error.pointer_mismatch;
            return verify_whole_state(state_opq);
        }
        fn set_nth(rand: Random, state_opq: Fuzz.OpaqueState, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state = state_opq.open(std.ArrayList(T), IList.IList(T), AUX_STATE);
            if (state.ref_obj.items.len == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_obj.items.len);
            var b: [1]u8 = undefined;
            rand.bytes(b[0..1]);
            const idx = state.test_obj.nth_idx(n);
            state.ref_obj.items[n] = b[0];
            state.test_obj.set(idx, b[0]);
            return verify_whole_state(state_opq);
        }
        fn check_nth_idx(rand: Random, state_opq: Fuzz.OpaqueState, alloc: Allocator) ?anyerror {
            _ = alloc;
            const state = state_opq.open(std.ArrayList(T), IList.IList(T), AUX_STATE);
            const n = rand.uintLessThan(usize, 1 + (state.ref_obj.items.len * 2));
            const idx_1 = state.test_obj.nth_idx(n);
            const idx_2 = state.test_obj.nth_idx_from_end(n);
            if (n >= state.ref_obj.items.len) {
                if (state.test_obj.idx_valid(idx_1)) return Error.valid_idx_beyond_list_len;
                if (state.test_obj.idx_valid(idx_2)) return Error.valid_idx_before_list_start;
            } else {
                if (!state.test_obj.idx_valid(idx_1)) return Error.invalid_idx_in_middle_of_list_traversing_forward;
                if (!state.test_obj.idx_valid(idx_2)) return Error.invalid_idx_in_middle_of_list_traversing_backward;
            }
            return verify_whole_state(state_opq);
        }
        pub const OPS = [4]*const fn (rand: Random, state_opq: Fuzz.OpaqueState, alloc: Allocator) ?anyerror{
            get_nth,
            get_nth_ptr,
            set_nth,
            check_nth_idx,
        };
    };
}
