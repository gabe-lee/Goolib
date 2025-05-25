//! //TODO Documentation
//! #### License: Zlib

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

// const std = @import("std");
// const math = std.math;
// const Writer = std.io.AnyWriter;
// const Type = std.builtin.Type;
// const Fmt = std.fmt;
// const FormatFloat = Fmt.format_float;
// const assert = std.debug.assert;
// const meta = std.meta;

// const Root = @import("./_root.zig");

// const MAX_BYTES_FLOAT = 53;
// const FMT_ESCAPE = '`';

// /// Renders fmt string with args, calling `writer` with slices of bytes.
// /// If `writer` returns an error, the error is returned from `format` and
// /// `writer` is not called again.
// ///
// /// The format string must be comptime-known and may contain placeholders following
// /// this format:
// /// `{[argument][specifier]:[fill][alignment][width].[precision]}`
// ///
// /// Above, each word including its surrounding [ and ] is a parameter which you have to replace with something:
// ///
// /// - *argument* is the field name of the argument that should be inserted, enclosed in square brackets
// ///   - `{[field_name]...}`
// /// - *specifier* is a type-dependent formatting option that determines how a type should formatted (see below)
// ///   - `x` and `X`: output numeric value in hexadecimal notation
// ///   - `s`:
// ///     - for pointer-to-many and C pointers of u8, print as a C-string using zero-termination
// ///     - for slices of u8, print the entire slice as a string without zero-termination
// ///   - `e`: output floating point value in scientific notation
// ///   - `d`: output numeric value in decimal notation
// ///   - `b`: output integer value in binary notation
// ///   - `o`: output integer value in octal notation
// ///   - `c`: output integer as an ASCII character. Integer type must have 8 bits at max.
// ///   - `u`: output integer as an UTF-8 sequence. Integer type must have 21 bits at max.
// ///   - `?`: output optional value as either the unwrapped value, or `null`; may be followed by a format specifier for the underlying value.
// ///   - `!`: output error union value as either the unwrapped value, or the formatted error value; may be followed by a format specifier for the underlying value.
// ///   - `*`: output the address of the value instead of the value itself.
// ///   - `any`: output a value of any type using its default format.
// /// - *fill* is a single unicode codepoint which is used to pad the formatted text
// ///   - example: fill with space char ` `: `{[field_name]s: }`
// ///   - example: fill with underscore char `_`: `{[field_name]s:_}`
// ///   - example: fill with zero char `0`: `{[field_name]d:0}`
// /// - *alignment* is one of the three bytes '<', '^', or '>' to make the text left-, center-, or right-aligned, respectively
// /// - *width* is the total width of the field in unicode codepoints
// /// - *precision* specifies how many decimals a formatted number should have
// ///
// /// Note that most of the parameters are optional and may be omitted. Also you can leave out separators like `:` and `.` when
// /// all parameters after the separator are omitted.
// /// Only exception is the *fill* parameter. If a non-zero *fill* character is required at the same time as *width* is specified,
// /// one has to specify *alignment* as well, as otherwise the digit following `:` is interpreted as *width*, not *fill*.
// ///
// /// The *specifier* has several options for types:
// /// - `x` and `X`: output numeric value in hexadecimal notation
// /// - `s`:
// ///   - for pointer-to-many and C pointers of u8, print as a C-string using zero-termination
// ///   - for slices of u8, print the entire slice as a string without zero-termination
// /// - `e`: output floating point value in scientific notation
// /// - `d`: output numeric value in decimal notation
// /// - `b`: output integer value in binary notation
// /// - `o`: output integer value in octal notation
// /// - `c`: output integer as an ASCII character. Integer type must have 8 bits at max.
// /// - `u`: output integer as an UTF-8 sequence. Integer type must have 21 bits at max.
// /// - `?`: output optional value as either the unwrapped value, or `null`; may be followed by a format specifier for the underlying value.
// /// - `!`: output error union value as either the unwrapped value, or the formatted error value; may be followed by a format specifier for the underlying value.
// /// - `*`: output the address of the value instead of the value itself.
// /// - `any`: output a value of any type using its default format.
// ///
// /// If a formatted user type contains a function of the type
// /// ```
// /// pub fn format(value: ?, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void
// /// ```
// /// with `?` being the type formatted, this function will be called instead of the default implementation.
// /// This allows user types to be formatted in a logical manner instead of dumping all fields of the type.
// ///
// /// A user type may be a `struct`, `vector`, `union` or `enum` type.
// ///
// /// To print literal curly braces, escape them by writing them twice, e.g. `{{` or `}}`.
// pub fn comptime_format_using_struct(writer: anytype, comptime fmt: []const u8, args: anytype) !void {
//     const ArgsType = @TypeOf(args);
//     const args_type_info = @typeInfo(ArgsType);
//     if (args_type_info != .@"struct" or args_type_info.@"struct".is_tuple) {
//         @compileError("expected struct args type (no tuples), found " ++ @typeName(ArgsType));
//     }

//     const fields_info = args_type_info.@"struct".fields;

//     @setEvalBranchQuota(2000000);
//     comptime var i = 0;
//     comptime var literal: []const u8 = "";
//     inline while (true) {
//         const start_index = i;

//         inline while (i < fmt.len) : (i += 1) {
//             switch (fmt[i]) {
//                 FMT_ESCAPE => break,
//                 else => {},
//             }
//         }

//         comptime var end_index = i;
//         comptime var unescape = false;

//         if (i + 1 < fmt.len and fmt[i + 1] == FMT_ESCAPE) {
//             unescape = true;
//             end_index += 1;
//             i += 2;
//         }

//         literal = literal ++ fmt[start_index..end_index];

//         // We've already skipped the other escape char, restart the loop
//         if (unescape) continue;

//         // Write out the literal
//         if (literal.len != 0) {
//             try writer.writeAll(literal);
//             literal = "";
//         }

//         if (i >= fmt.len) break;

//         // Get past the open escape char
//         comptime assert(fmt[i] == FMT_ESCAPE);
//         i += 1;

//         const fmt_begin = i;
//         // Find the other escape char
//         inline while (i < fmt.len and fmt[i] != FMT_ESCAPE) : (i += 1) {}
//         const fmt_end = i;

//         if (i >= fmt.len) {
//             @compileError("missing closing format escape char");
//         }

//         // Get past the close escape char
//         comptime assert(fmt[i] == FMT_ESCAPE);
//         i += 1;

//         comptime var width: ?usize = null;
//         comptime var precision: ?usize = null;
//         comptime var alignment: Fmt.Alignment = Fmt.Alignment.right;
//         comptime var format_style: []const u8 = "_";
//         comptime var fill: u21 = ' ';

//         comptime var f: usize = fmt_begin;
//         inline while (f < i) {
//             switch (fmt[f]) {
//                 '_', 'A'...'Z', 'a'...'z', '0'...'9' => f += 1,
//                 else => break,
//             }
//         }
//         const field_name_end = f;
//         if (field_name_end == fmt_begin) @compileError("missing field name for replacement argument: " ++ fmt[fmt_begin..i]);
//         inline while (f < i) {
//             switch (fmt[f]) {
//                 ' ' => f += 1,
//                 else => break,
//             }
//         }
//         if (f < fmt_end and fmt[f] == ':') {
//             get_format_options: {
//                 f += 1;
//                 const format_style_begin = f;
//                 if (f >= fmt_end) @compileError("missing formatting options after colon: " ++ fmt[fmt_begin..i]);
//                 switch (fmt[f]) {
//                     'x', 'X', 's', 'e', 'd', 'b', 'o', 'c', 'u', '*', '_' => f += 1,
//                     '?', '!' => {
//                         f += 1;
//                         if (f >= fmt_end) @compileError("formating styles '?' (maybe null) and '!' (maybe error) must be followed by style for the does-exist/good-value: " ++ fmt[fmt_begin..i]);
//                         switch (fmt[f]) {
//                             'x', 'X', 's', 'e', 'd', 'b', 'o', 'c', 'u', '*', '_' => f += 1,
//                             else => @compileError("invalid formating style specifier '" ++ fmt[format_style_begin .. f + 1] ++ "' : " ++ fmt[fmt_begin..i]),
//                         }
//                     },
//                     else => @compileError("invalid formating style specifier '" ++ fmt[format_style_begin .. f + 1] ++ "' : " ++ fmt[fmt_begin..i]),
//                 }
//                 format_style = fmt[format_style_begin..f];
//                 if (f >= fmt_end) break :get_format_options;
//                 const fill_begin = f;
//             }
//         }

//         const placeholder = comptime Fmt.Placeholder.parse(fmt[fmt_begin..fmt_end].*);
//         const arg_name = comptime switch (placeholder.arg) {
//             .named => |name| name,
//             else => @compileError("only named placeholders are allowed, found placeholder type " ++ @tagName(placeholder.arg)),
//         };

//         const width = switch (placeholder.width) {
//             .none => null,
//             .number => |v| v,
//             .named => |width_name| @field(args, width_name),
//         };

//         const precision = switch (placeholder.precision) {
//             .none => null,
//             .number => |v| v,
//             .named => |precision_name| @field(args, precision_name),
//         };

//         try Fmt.formatType(
//             @field(args, arg_name),
//             placeholder.specifier_arg,
//             Fmt.FormatOptions{
//                 .fill = placeholder.fill,
//                 .alignment = placeholder.alignment,
//                 .width = width,
//                 .precision = precision,
//             },
//             writer,
//             std.options.fmt_max_depth,
//         );
//     }

//     if (comptime arg_state.hasUnusedArgs()) {
//         const missing_count = arg_state.args_len - @popCount(arg_state.used_args);
//         switch (missing_count) {
//             0 => unreachable,
//             1 => @compileError("unused argument in '" ++ fmt ++ "'"),
//             else => @compileError(comptimePrint("{d}", .{missing_count}) ++ " unused arguments in '" ++ fmt ++ "'"),
//         }
//     }
// }

// pub const StrSource = union(enum) {
//     literal: []const u8,
//     field: []const u8,
// };
// pub const IntSource = union(enum) {
//     int: usize,
//     field: []const u8,
// };

// pub const Placeholder = struct {
//     field_name: []const u8,
//     format: CharSource,
//     fill: CharSource,
//     alignment: CharSource,
//     width: IntSource,
//     precision: IntSource,

//     pub fn parse(comptime str: []const u8) Placeholder {
//         var idx: usize = 0;

//         // Parse the positional argument number
//         const arg = comptime parser.specifier() catch |err|
//             @compileError(@errorName(err));

//         // Parse the format specifier
//         const specifier_arg = comptime parser.until(':');

//         // Skip the colon, if present
//         if (comptime parser.char()) |ch| {
//             if (ch != ':') {
//                 @compileError("expected : or }, found '" ++ unicode.utf8EncodeComptime(ch) ++ "'");
//             }
//         }

//         // Parse the fill character, if present.
//         // When the width field is also specified, the fill character must
//         // be followed by an alignment specifier, unless it's '0' (zero)
//         // (in which case it's handled as part of the width specifier)
//         var fill: ?u21 = comptime if (parser.peek(1)) |ch|
//             switch (ch) {
//                 '<', '^', '>' => parser.char(),
//                 else => null,
//             }
//         else
//             null;

//         // Parse the alignment parameter
//         const alignment: ?Alignment = comptime if (parser.peek(0)) |ch| init: {
//             switch (ch) {
//                 '<', '^', '>' => {
//                     // consume the character
//                     break :init switch (parser.char().?) {
//                         '<' => .left,
//                         '^' => .center,
//                         else => .right,
//                     };
//                 },
//                 else => break :init null,
//             }
//         } else null;

//         // When none of the fill character and the alignment specifier have
//         // been provided, check whether the width starts with a zero.
//         if (fill == null and alignment == null) {
//             fill = comptime if (parser.peek(0) == '0') '0' else null;
//         }

//         // Parse the width parameter
//         const width = comptime parser.specifier() catch |err|
//             @compileError(@errorName(err));

//         // Skip the dot, if present
//         if (comptime parser.char()) |ch| {
//             if (ch != '.') {
//                 @compileError("expected . or }, found '" ++ unicode.utf8EncodeComptime(ch) ++ "'");
//             }
//         }

//         // Parse the precision parameter
//         const precision = comptime parser.specifier() catch |err|
//             @compileError(@errorName(err));

//         if (comptime parser.char()) |ch| {
//             @compileError("extraneous trailing character '" ++ unicode.utf8EncodeComptime(ch) ++ "'");
//         }

//         return Placeholder{
//             .specifier_arg = cacheString(specifier_arg[0..specifier_arg.len].*),
//             .fill = fill orelse default_fill_char,
//             .alignment = alignment orelse default_alignment,
//             .field_name = arg,
//             .width = width,
//             .precision = precision,
//         };
//     }
// };

// pub const Parser = struct {
//     buffer: []const u8,
//     index: usize = 0,

//     pub fn new(buffer: []const u8) Parser {
//         return Parser{
//             .buffer = buffer,
//         };
//     }

//     pub fn next_field_name(self: *Parser) []const u8 {
//         const start = self.index;
//         loop: while (self.index < self.buffer.len) {
//             switch (self.buffer[self.index]) {
//                 '_', 'A'...'Z', 'a'...'z', '0'...'9' => self.index += 1,
//                 else => break :loop,
//             }
//         }
//         return self.buffer[start..self.index];
//     }

//     pub fn skip_whitespace(self: *Parser) void {
//         loop: while (self.index < self.buffer.len) {
//             switch (self.buffer[self.index]) {
//                 ' ', '\t', '\n' => self.index += 1,
//                 else => break :loop,
//             }
//         }
//     }

//     pub fn next_segment_before_fmt_escape(self: *Parser) []const u8 {
//         const start = self.index;
//         loop: while (self.index < self.buffer.len) {
//             switch (self.buffer[self.index]) {
//                 FMT_ESCAPE => break :loop,
//                 else => self.index += 1,
//             }
//         }
//         return self.buffer[start..self.index];
//     }
// };

// pub fn float_to_str(base: FloatBase, suffix: FloatSuffix, precision: ?usize, val: anytype) FloatToStrResult {
//     const T = @TypeOf(val);
//     const cast_type = switch (@typeInfo(T)) {
//         Type.float => T,
//         Type.comptime_float => f128,
//         else => @compileError("float_to_str can only take floats or comptime-floats as input"),
//     };
//     const cast_val = @as(cast_type, val);
//     const cast_int = @Type(.{ .int = .{ .signedness = .unsigned, .bits = @bitSizeOf(cast_type) } });
//     var result = FloatToStrResult{};

//     if (math.isInf(cast_val)) {
//         if (cast_val < 0) return FloatToStrResult.NEG_INF;
//         return FloatToStrResult.POS_INF;
//     } else if (math.isNan(cast_val)) {
//         return FloatToStrResult.NAN;
//     }

//     switch (base) {
//         FloatBase.Dec => {
//             const DecimalType = if (@bitSizeOf(cast_type) <= 64) u64 else u128;
//             const tables = switch (DecimalType) {
//                 u64 => if (@import("builtin").mode == .ReleaseSmall) &FormatFloat.Backend64_TablesSmall else &FormatFloat.Backend64_TablesFull,
//                 u128 => &FormatFloat.Backend128_Tables,
//                 else => unreachable,
//             };

//             const has_explicit_leading_bit = std.math.floatMantissaBits(cast_type) - std.math.floatFractionalBits(cast_type) != 0;
//             const float_decimal = FormatFloat.binaryToDecimal(DecimalType, @as(cast_int, @bitCast(cast_val)), std.math.floatMantissaBits(cast_type), std.math.floatExponentBits(cast_type), has_explicit_leading_bit, tables);
//             choose_suffix: switch (suffix) {
//                 FloatSuffix.Normal => {
//                     const decimal_len = FormatFloat.decimalLength(float_decimal.mantissa);
//                     const needed_bytes = if (float_decimal.exponent >= 0)
//                         @as(usize, 2) + @abs(float_decimal.exponent) + decimal_len + (precision orelse 0)
//                     else
//                         @as(usize, 2) + @max(@abs(float_decimal.exponent) + decimal_len, precision orelse 0);
//                     if (needed_bytes > MAX_BYTES_FLOAT) continue :choose_suffix FloatSuffix.Scientific;
//                     var output = float_decimal.mantissa;
//                     if (float_decimal.sign) {
//                         result.buf[result.len] = '-';
//                         result.len += 1;
//                     }

//                     const dp_offset = float_decimal.exponent + cast_i32(decimal_len);
//                     if (dp_offset <= 0) {
//                         // 0.000001234
//                         result.buf[result.len] = '0';
//                         result.buf[result.len + 1] = '.';
//                         result.len += 2;
//                         const dp_index = result.len;

//                         const dp_poffset: u32 = @intCast(-dp_offset);
//                         @memset(result.buf[result.len..][0..dp_poffset], '0');
//                         result.len += dp_poffset;
//                         FormatFloat.writeDecimal(result.buf[result.len..], &output, decimal_len);
//                         result.len += decimal_len;

//                         if (precision) |prec| {
//                             const dp_written = result.len - dp_index;
//                             if (prec > dp_written) {
//                                 @memset(result.buf[result.len..][0 .. prec - dp_written], '0');
//                             }
//                             result.len = dp_index + prec - @intFromBool(prec == 0);
//                         }
//                     } else {
//                         // 123456000
//                         const dp_uoffset: usize = @intCast(dp_offset);
//                         if (dp_uoffset >= decimal_len) {
//                             FormatFloat.writeDecimal(result.buf[result.len..], &output, decimal_len);
//                             result.len += decimal_len;
//                             @memset(result.buf[result.len..][0 .. dp_uoffset - decimal_len], '0');
//                             result.len += dp_uoffset - decimal_len;

//                             if (precision) |prec| {
//                                 if (prec != 0) {
//                                     result.buf[result.len] = '.';
//                                     result.len += 1;
//                                     @memset(result.buf[result.len..][0..prec], '0');
//                                     result.len += prec;
//                                 }
//                             }
//                         } else {
//                             // 12345.6789
//                             FormatFloat.writeDecimal(result.buf[result.len + dp_uoffset + 1 ..], &output, decimal_len - dp_uoffset);
//                             result.buf[result.len + dp_uoffset] = '.';
//                             const dp_index = result.len + dp_uoffset + 1;
//                             FormatFloat.writeDecimal(result.buf[result.len..], &output, dp_uoffset);
//                             result.len += decimal_len + 1;

//                             if (precision) |prec| {
//                                 const dp_written = decimal_len - dp_uoffset;
//                                 if (prec > dp_written) {
//                                     @memset(result.buf[result.len..][0 .. prec - dp_written], '0');
//                                 }
//                                 result.len = dp_index + prec - @intFromBool(prec == 0);
//                             }
//                         }
//                     }
//                 },
//                 FloatSuffix.Scientific => {},
//             }
//         },
//         FloatBase.Hex => {},
//     }
//     return result;
// }

// pub fn int_to_str(base: IntBase, val: anytype) IntToStrResult(base, @TypeOf(val), val) {
//     const Result = IntToStrResult(base, @TypeOf(val), val);
//     var result = Result{};
//     const cast_val = @as(Result.INT_T, val);

//     const abs_value = @abs(cast_val);

//     var abs_remaining: Result.MIN_INT = abs_value;

//     switch (base) {
//         IntBase.Dec => {
//             while (abs_remaining >= 100) : (abs_remaining = @divTrunc(abs_remaining, 100)) {
//                 result.start -= 2;
//                 result.buf[result.start..][0..2].* = std.fmt.digits2(@intCast(abs_remaining % 100));
//             }

//             if (abs_remaining < 10) {
//                 result.start -= 1;
//                 result.buf[result.start] = '0' + @as(u8, @intCast(abs_remaining));
//             } else {
//                 result.start -= 2;
//                 result.buf[result.start..][0..2].* = std.fmt.digits2(@intCast(abs_remaining));
//             }
//         },
//         IntBase.Bin => {
//             while (true) {
//                 const digit: u8 = @intCast(abs_remaining & 0b1);
//                 result.start -= 1;
//                 result.buf[result.start] = '0' + digit;
//                 abs_remaining >>= 1;
//                 if (abs_remaining == 0) break;
//             }
//         },
//         IntBase.Oct => {
//             while (true) {
//                 const digit: u8 = @intCast(abs_remaining & 0b111);
//                 result.start -= 1;
//                 result.buf[result.start] = '0' + digit;
//                 abs_remaining >>= 3;
//                 if (abs_remaining == 0) break;
//             }
//         },
//         IntBase.Hex => {
//             while (true) {
//                 const digit: u8 = @intCast(abs_remaining & 0b1111);
//                 result.start -= 1;
//                 result.buf[result.start] = switch (digit) {
//                     0...9 => '0' + digit,
//                     10...15 => 'A' + digit - 10,
//                     else => unreachable,
//                 };
//                 abs_remaining >>= 4;
//                 if (abs_remaining == 0) break;
//             }
//         },
//     }

//     if (Result.signed and cast_val < 0) {
//         result.start -= 1;
//         result.buf[result.start] = '-';
//     }

//     return result;
// }

// pub const FloatToStrResult = struct {
//     buf: [MAX_BYTES_FLOAT]u8 = @splat(0),
//     len: usize = 0,

//     pub const POS_INF = make: {
//         var result = FloatToStrResult{};
//         result.buf[0] = 'I';
//         result.buf[1] = 'N';
//         result.buf[2] = 'F';
//         result.len = 3;
//         break :make result;
//     };
//     pub const NEG_INF = make: {
//         var result = FloatToStrResult{};
//         result.buf[0] = '-';
//         result.buf[1] = 'I';
//         result.buf[2] = 'N';
//         result.buf[3] = 'F';
//         result.len = 4;
//         break :make result;
//     };
//     pub const NAN = make: {
//         var result = FloatToStrResult{};
//         result.buf[0] = 'N';
//         result.buf[1] = 'a';
//         result.buf[2] = 'N';
//         result.len = 3;
//         break :make result;
//     };
// };

// pub fn IntToStrResult(comptime base: IntBase, comptime T: type, val: T) type {
//     const int_type = switch (@typeInfo(T)) {
//         Type.int => T,
//         Type.comptime_int => math.IntFittingRange(val, val),
//         else => @compileError("int_to_str can only take integers or comptime-integers as input"),
//     };

//     const INFO = @typeInfo(int_type);
//     const min_int = @max(INFO.int.bits, 8);
//     const MAX_DIGITS = switch (base) {
//         IntBase.Bin => @as(comptime_int, INFO.bits),
//         IntBase.Dec, IntBase.Oct => @as(comptime_int, INFO.bits >> 3),
//         IntBase.Hex => @as(comptime_int, INFO.bits >> 4),
//     };
//     const MAX_SIZE = 1 + @max(MAX_DIGITS, 1);
//     return struct {
//         buf: [MAX_SIZE]u8 = @splat(0),
//         start: u8 = MAX_SIZE,

//         const Self = @This();
//         const INT_T = int_type;
//         const MIN_INT = min_int;
//         const signed = INFO.int.signedness == .signed;

//         pub inline fn slice(self: Self) []const u8 {
//             return self.buf[self.start..];
//         }
//     };
// }

// pub const IntBase = enum {
//     Bin,
//     Oct,
//     Dec,
//     Hex,
// };

// pub const FloatBase = enum {
//     Dec,
//     Hex,
// };

// pub const FloatSuffix = enum {
//     Normal,
//     Scientific,
// };

// fn cast_i32(v: anytype) i32 {
//     return @intCast(v);
// }

// fn round(comptime T: type, float_decimal: FormatFloat.FloatDecimal(T), mode: FloatSuffix, precision: usize) FormatFloat.FloatDecimal(T) {
//     var round_digit: usize = 0;
//     var output = float_decimal.mantissa;
//     var exp = float_decimal.exponent;
//     const output_len = FormatFloat.decimalLength(output);

//     switch (mode) {
//         .Normal => {
//             if (float_decimal.exponent > 0) {
//                 round_digit = (output_len - 1) + precision + @as(usize, @intCast(float_decimal.exponent));
//             } else {
//                 const min_exp_required = @as(usize, @intCast(-float_decimal.exponent));
//                 if (precision + output_len > min_exp_required) {
//                     round_digit = precision + output_len - min_exp_required;
//                 }
//             }
//         },
//         .Scientific => {
//             round_digit = 1 + precision;
//         },
//     }

//     if (round_digit < output_len) {
//         var nlength = output_len;
//         for (round_digit + 1..output_len) |_| {
//             output /= 10;
//             exp += 1;
//             nlength -= 1;
//         }

//         if (output % 10 >= 5) {
//             output /= 10;
//             output += 1;
//             exp += 1;

//             // e.g. 9999 -> 10000
//             if (isPowerOf10(output)) {
//                 output /= 10;
//                 exp += 1;
//             }
//         }
//     }

//     return .{
//         .mantissa = output,
//         .exponent = exp,
//         .sign = float_decimal.sign,
//     };
// }

// fn isPowerOf10(n_: u128) bool {
//     var n = n_;
//     while (n != 0) : (n /= 10) {
//         if (n % 10 != 0) return false;
//     }
//     return true;
// }

// // const ListU8 = Root.CollectionTypes.StaticAllocList.

// // pub fn fmt_num(temp_buffer: fmt: NumFmt)

// // pub const NumFmt = struct {
// //     base: NumBase = .Dec,
// //     base_prefix: NumPrefix = .Short,
// //     min_pad_left: u32 = 0,
// //     min_pad_right: u32 = 0,
// //     min_whole_digits: u32 = 1,
// //     max_whole_digits: u32 = math.maxInt(u32),
// //     min_width: u32 = 0,
// //     max_width: u32 = math.maxInt(u32),
// //     min_frac_digits: u32 = 2,
// //     max_frac_digits: u32 = 5,
// //     leading_zero_char: Chars = Chars.NONE,
// //     trailing_zero_char: Chars = Chars.NONE,
// //     point_chars: Chars = Chars.PERIOD,
// //     whole_separator: SepFormat = SepFormat.NONE,
// //     frac_separator: SepFormat = SepFormat.NONE,
// //     prefix_chars: Chars = Chars.NONE,
// //     suffix_chars: Chars = Chars.NONE,
// // };

// // pub const Chars = union(enum) {
// //     None: void,
// //     Str: []const u8,

// //     pub const NONE = Chars{ .None = void{} };
// //     pub const PERIOD = Chars{ .Str = "." };
// //     pub const COMMA = Chars{ .Str = "," };
// //     pub const UNDERSCORE = Chars{ .Str = "_" };
// // };

// // pub const Separator = struct {
// //     char: Chars,
// //     digits_per_sep: u32,
// // };

// // pub const SepFormat = union(enum) {
// //     None: void,
// //     Repeat: Separator,
// //     Custom: []const Separator,

// //     pub const NONE = SepFormat{ .None = void{} };
// //     pub const COMMA_EVERY_3 = SepFormat{ .Repeat = Separator{ .char = Chars.COMMA, .digits_per_sep = 3 } };
// //     pub const UNDERSCORE_EVERY_2 = SepFormat{ .Repeat = Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 2 } };
// //     pub const UNDERSCORE_EVERY_3 = SepFormat{ .Repeat = Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 3 } };
// //     pub const UNDERSCORE_EVERY_4 = SepFormat{ .Repeat = Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 4 } };
// //     pub const UNDERSCORE_EVERY_8 = SepFormat{ .Repeat = Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 8 } };
// //     pub const FLOAT_16_BIN_PARTS = SepFormat{ .Custom = &[_]Separator{
// //         Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 1 },
// //         Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 5 },
// //     } };
// //     pub const FLOAT_32_BIN_PARTS = SepFormat{ .Custom = &[_]Separator{
// //         Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 1 },
// //         Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 8 },
// //     } };
// //     pub const FLOAT_64_BIN_PARTS = SepFormat{ .Custom = &[_]Separator{
// //         Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 1 },
// //         Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 11 },
// //     } };
// //     pub const FLOAT_128_BIN_PARTS = SepFormat{ .Custom = &[_]Separator{
// //         Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 1 },
// //         Separator{ .char = Chars.UNDERSCORE, .digits_per_sep = 15 },
// //     } };
// // };

// // pub const NumPrefix = enum {
// //     None,
// //     Short,
// //     Verbose,
// // };

// // pub const Align = enum {
// //     Left,
// //     Center,
// //     Right,
// // };

// // pub const NumBase = enum {
// //     /// Binary representation
// //     Bin,
// //     /// Octal representation
// //     Oct,
// //     /// Decimal representation
// //     Dec,
// //     /// Hexidecimal representation
// //     Hex,
// // };

// // inline fn base_prefix_str(base: NumBase, prefix: NumPrefix) []const u8 {
// //     return BASE_PREFIX[@intFromEnum(prefix)][@intFromEnum(base)];
// // }
// // const BASE_PREFIX = [3][4][]const u8{
// //     .{ "", "", "", "" },
// //     .{ "0b", "0o", "", "0x" },
// //     .{ "bin", "oct", "dec", "hex" },
// // };
