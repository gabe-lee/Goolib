const std = @import("std");
const fmt = std.fmt;

const Goolib = @import("Goolib");

pub fn gen(filegen: *Goolib.Filegen) anyerror!void {
    filegen.start_generating_file(.{ .RELATIVE_CWD = "/src/ListGen.zig" });
}
