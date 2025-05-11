pub const BEGIN = "\x1b[";
pub const END = 'm';
const BEG_END_LEN = BEGIN.len + 1;

pub fn ansi(comptime params: []const PARAM) []const u8 {
    const len = comptime calc: {
        var total_len: usize = BEG_END_LEN;
        for (params) |param| {
            total_len += TABLE[@intFromEnum(param)].len;
        }
        break :calc total_len;
    };
    var str: [len]u8 = undefined;
    @memcpy(str[0..BEGIN.len], BEGIN);
    var i: usize = BEGIN.len;
    inline for (params) |param| {
        const this_str = TABLE[@intFromEnum(param)];
        @memcpy(str[i..][0..this_str.len], this_str);
        i += this_str.len;
    }
    str[i] = END;
    return str[0..len];
}
pub const PARAM = enum(u8) {
    RESET = 0,
    BOLD = 1,
    FAINT = 2,
    UNDERLINE = 3,
    BLINK = 4,
    FG_BLACK = 5,
    FG_RED = 6,
    FG_GREEN = 7,
    FG_YELLOW = 8,
    FG_BLUE = 9,
    FG_MAGENTA = 10,
    FG_CYAN = 11,
    FG_WHITE = 12,
    BG_BLACK = 13,
    BG_RED = 14,
    BG_GREEN = 15,
    BG_YELLOW = 16,
    BG_BLUE = 17,
    BG_MAGENTA = 18,
    BG_CYAN = 19,
    BG_WHITE = 20,
};
pub const TABLE = [21][]const u8{
    "0;",
    "1;",
    "2;",
    "4;",
    "5;",
    "30;",
    "31;",
    "32;",
    "33;",
    "34;",
    "35;",
    "36;",
    "37;",
    "40;",
    "41;",
    "42;",
    "43;",
    "44;",
    "45;",
    "46;",
    "47;",
};
