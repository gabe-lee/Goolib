const std = @import("std");

const LITERAL_TAG = (1 << 15);
const MAX_LITERAL_LEN = LITERAL_TAG - 1;
const FMT_ESCAPE_LEFT = '`';
const FMT_ESCAPE_RIGHT = '`';
// const SegmentData = struct {
//     is_literal: bool,
//     len: u16,

//     fn next(buf: []const u8) SegmentData {}
// };
// const InsertData = packed struct {
//     segment_data: SegmentData,
// };

pub fn define_template(comptime name: []const u8, comptime keys_type: type, comptime content: []const u8) type {
    return struct {
        pub const KEYS_TYPE = keys_type;
        pub const NAME = name;
        pub const CONTENT = content;

        pub inline fn write(writer: anytype, keys: KEYS_TYPE) void {
            std.fmt.format(writer, CONTENT, keys) catch |err| std.debug.panic("Template `{s}` failed to process input: {s}", .{ NAME, @errorName(err) });
        }
    };
}
