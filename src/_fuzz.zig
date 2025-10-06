const std = @import("std");
const Goolib = @import("Goolib");
const opts = @import("opts");
const Random = std.Random;
const math = std.math;
const Allocator = std.mem.Allocator;

const Fuzz = Goolib.DiffFuzz;
const Time = Goolib.Time;

const IList = Goolib.IList;
const IListFuzzer = IList._Fuzzer;
const IListFuzzerSliceAdapterU8Alloc = IList._Fuzzer.SLICE_ADAPTER_U8_ALLOC;
pub fn main() anyerror!void {
    var fuzzer = try Fuzz.DiffFuzzer.init(std.heap.smp_allocator, Time.Secs.new(@intCast(opts.time_opt)), &.{
        // Fuzz.OVERHEAD_TEST,
        IListFuzzerSliceAdapterU8Alloc,
    });
    defer fuzzer.deinit();
    try fuzzer.fuzz_all();
}
