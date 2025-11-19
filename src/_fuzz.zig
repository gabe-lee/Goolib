const std = @import("std");
const Goolib = @import("Goolib");
const opts = @import("opts");
const Random = std.Random;
const math = std.math;
const Allocator = std.mem.Allocator;

const Fuzz = Goolib.Fuzz;
const Time = Goolib.Time;
const Utils = Goolib.Utils;

const Utils_quick_hex_dec_u64 = Utils._Fuzzer.Utils_quick_hex_dec_u64;
const IList = Goolib.IList;
const IListFuzzer = IList._Fuzzer;
const IList_SliceAdapter_u8 = IList._Fuzzer.IList_SliceAdapter_u8;
const IList_ArrayListAdapter_u8 = IList._Fuzzer.IList_ArrayListAdapter_u8;
const IList_RingList_u8 = IList._Fuzzer.IList_RingList_u8;
const IList_List_u8 = IList._Fuzzer.IList_List_u8;
const IList_MultiSortList_u8 = IList._Fuzzer.IList_MultiSortList_u8;

const ListSegmentAllocator_u8 = Goolib.ListSegmentAllocator.Internal.Fuzzer.make_list_segment_allocator_test(u8);
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
            ListSegmentAllocator_u8,
        },
        &.{
            .new_group("IList", &.{
                IList_SliceAdapter_u8,
                IList_ArrayListAdapter_u8,
                IList_RingList_u8,
                IList_List_u8,
                IList_MultiSortList_u8,
            }),
            .new_group("Utils", &.{
                Utils_quick_hex_dec_u64,
            }),
        },
    );
    defer fuzzer.deinit();
    try fuzzer.fuzz_all();
}
