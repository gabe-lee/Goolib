const std = @import("std");

const Goolib = @import("Goolib");

const List = @import("./List.zig");
pub fn main() !void {
    var filegen = try Goolib.Filegen.create(std.heap.page_allocator);
    defer filegen.destroy();

    try List.gen(&filegen);
}
