const std = @import("std");
const Goolib = @import("Goolib");
const Random = std.Random;
const math = std.math;
const Allocator = std.mem.Allocator;

const Fuzz = Goolib.Fuzz;
const Time = Goolib.Time;
const Utils = Goolib.Utils;

// const Utils_quick_hex_dec_u64 = Utils._Fuzzer.Utils_quick_hex_dec_u64;
const IList = Goolib.IList;
const Benches = IList._Bencher;
pub fn main() anyerror!void {
    var fuzzer = try Fuzz.DiffFuzzer.init_bench(
        std.process.args(),
        std.heap.smp_allocator,
        Fuzz.MAX_THREAD_COUNT,
        &.{},
        &.{
            .new_group(
                "IList_RAND_GSID_MICRO",
                &Benches.RAND_GSID_U8[Benches.MICRO],
            ),
            .new_group(
                "IList_RAND_GSID_MINI",
                &Benches.RAND_GSID_U8[Benches.MINI],
            ),
            .new_group(
                "IList_RAND_GSID_SMALL",
                &Benches.RAND_GSID_U8[Benches.SMALL],
            ),
            .new_group(
                "IList_RAND_GSID_MED",
                &Benches.RAND_GSID_U8[Benches.MED],
            ),
            .new_group(
                "IList_RAND_GSID_LARGE",
                &Benches.RAND_GSID_U8[Benches.LARGE],
            ),
            .new_group(
                "IList_RAND_GSID_HUGE",
                &Benches.RAND_GSID_U8[Benches.HUGE],
            ),
            .new_group(
                "IList_RAND_GSID_MNSTR",
                &Benches.RAND_GSID_U8[Benches.MONSTER],
            ),
            .new_group(
                "IList_Q_DQ_MANY_MICRO",
                &Benches.Q_DQ_MANY_U8[Benches.MICRO],
            ),
            .new_group(
                "IList_Q_DQ_MANY_MINI",
                &Benches.Q_DQ_MANY_U8[Benches.MINI],
            ),
            .new_group(
                "IList_Q_DQ_MANY_SMALL",
                &Benches.Q_DQ_MANY_U8[Benches.SMALL],
            ),
            .new_group(
                "IList_Q_DQ_MANY_MED",
                &Benches.Q_DQ_MANY_U8[Benches.MED],
            ),
            .new_group(
                "IList_Q_DQ_MANY_LARGE",
                &Benches.Q_DQ_MANY_U8[Benches.LARGE],
            ),
            .new_group(
                "IList_Q_DQ_MANY_HUGE",
                &Benches.Q_DQ_MANY_U8[Benches.HUGE],
            ),
            .new_group(
                "IList_Q_DQ_MANY_MNSTR",
                &Benches.Q_DQ_MANY_U8[Benches.MONSTER],
            ),
            .new_group(
                "IList_Q_DQ_ONE_MICRO",
                &Benches.Q_DQ_ONE_U8[Benches.MICRO],
            ),
            .new_group(
                "IList_Q_DQ_ONE_MINI",
                &Benches.Q_DQ_ONE_U8[Benches.MINI],
            ),
            .new_group(
                "IList_Q_DQ_ONE_SMALL",
                &Benches.Q_DQ_ONE_U8[Benches.SMALL],
            ),
            .new_group(
                "IList_Q_DQ_ONE_MED",
                &Benches.Q_DQ_ONE_U8[Benches.MED],
            ),
            .new_group(
                "IList_Q_DQ_ONE_LARGE",
                &Benches.Q_DQ_ONE_U8[Benches.LARGE],
            ),
            .new_group(
                "IList_Q_DQ_ONE_HUGE",
                &Benches.Q_DQ_ONE_U8[Benches.HUGE],
            ),
            .new_group(
                "IList_Q_DQ_ONE_MNSTR",
                &Benches.Q_DQ_ONE_U8[Benches.MONSTER],
            ),
        },
    );
    defer fuzzer.deinit();
    try fuzzer.bench_all();
}
