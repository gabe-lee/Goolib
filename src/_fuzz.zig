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
const Goolib = @import("Goolib");
const opts = @import("opts");
const Random = std.Random;
const math = std.math;
const Allocator = std.mem.Allocator;

const Fuzz = Goolib.Fuzz;
const Time = Goolib.Time;
const Utils = Goolib.Utils;
const CCAS = Goolib.CompactCoupledAllocationSystem;
const SBA = Goolib.SlabBucketAllocator;

const Utils_quick_hex_dec_u64 = Utils._Fuzzer.Utils_quick_hex_dec_u64;
const IList = Goolib.IList;
const IListFuzzer = IList._Fuzzer;
const IList_SliceAdapter_u8 = IList._Fuzzer.IList_SliceAdapter_u8;
const IList_ArrayListAdapter_u8 = IList._Fuzzer.IList_ArrayListAdapter_u8;
const IList_RingList_u8 = IList._Fuzzer.IList_RingList_u8;
const IList_List_u8 = IList._Fuzzer.IList_List_u8;
const IList_MultiSortList_u8 = IList._Fuzzer.IList_MultiSortList_u8;
const IList_CCASList_mutexed_zeroed_u8 = CCAS.CompactCoupledAllocationSystem(.new("FUZZ_TEST_CCAS_MS_Z", u32, u16, .multi_threaded_shared, .explicitly_zero_freed_data)).Debug.make_list_interface_test(u8);
const IList_CCASList_threadlocal_unzeroed_u8 = CCAS.CompactCoupledAllocationSystem(.new("FUZZ_TEST_CCAS_MU_NZ", u32, u16, .multi_threaded_separate, .do_not_explicitly_zero_freed_data)).Debug.make_list_interface_test(u8);
const SlabBucketAllocator_multi_threaded = SBA.SimpleBucketAllocator(.new(.multi_threaded, 16)).Debug.make_two_list_test();

// const ListSegmentAllocator_u8 = Goolib.ListSegmentAllocator.Internal.Fuzzer.make_list_segment_allocator_test(u8);
pub fn main() anyerror!void {
    var fuzzer = try Fuzz.DiffFuzzer.init_fuzz(
        std.process.args(),
        std.heap.smp_allocator,
        &.{
            // Fuzz.FAILURE_TEST,
            // Fuzz.OVERHEAD_TEST,
            Utils_quick_hex_dec_u64,
            IList_SliceAdapter_u8,
            IList_ArrayListAdapter_u8,
            IList_RingList_u8,
            IList_List_u8,
            IList_MultiSortList_u8,
            // ListSegmentAllocator_u8,
            IList_CCASList_mutexed_zeroed_u8,
            IList_CCASList_threadlocal_unzeroed_u8,
            SlabBucketAllocator_multi_threaded,
        },
        &.{
            .new_group("IList", &.{
                IList_SliceAdapter_u8,
                IList_ArrayListAdapter_u8,
                IList_RingList_u8,
                IList_List_u8,
                IList_MultiSortList_u8,
                IList_CCASList_mutexed_zeroed_u8,
                IList_CCASList_threadlocal_unzeroed_u8,
            }),
            .new_group("Allocators", &.{
                SlabBucketAllocator_multi_threaded,
            }),
            .new_group("Utils", &.{
                Utils_quick_hex_dec_u64,
            }),
        },
    );
    defer fuzzer.deinit();
    try fuzzer.fuzz_all();
}
