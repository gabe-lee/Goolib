const std = @import("std");
const Goolib = @import("Goolib");
const opts = @import("opts");
const Random = std.Random;
const math = std.math;
const Allocator = std.mem.Allocator;

const Fuzz = Goolib.Fuzz;
const Time = Goolib.Time;
const Utils = Goolib.Utils;

const IList = Goolib.IList;
const IListFuzzer = IList._Fuzzer;
const IList_SliceAdapter_no_alloc_u8 = IList._Fuzzer.SLICE_ADAPTER_U8_NO_ALLOC;
const IList_SliceAdapter_alloc_u8 = IList._Fuzzer.SLICE_ADAPTER_U8_ALLOC;
const IList_ArrayListAdapter_u8 = IList._Fuzzer.ARRAY_LIST_ADAPTER_U8;
const Utils_quick_hex_dec_u64 = Utils._Fuzzer.Utils_quick_hex_dec_u64;
pub fn main() anyerror!void {
    var fuzzer = try Fuzz.DiffFuzzer.init(std.process.args(), std.heap.smp_allocator, Fuzz.MAX_THREAD_COUNT, &.{
        // Fuzz.FAILURE_TEST,
        // Fuzz.OVERHEAD_TEST,
        Utils_quick_hex_dec_u64,
        IList_SliceAdapter_no_alloc_u8,
        IList_SliceAdapter_alloc_u8,
        IList_ArrayListAdapter_u8,
    });
    defer fuzzer.deinit();
    try fuzzer.fuzz_all();
}
