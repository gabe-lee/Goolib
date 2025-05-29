//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
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
// const build = @import("builtin");
// const io = std.io;
// const fs = std.fs;
// const process = std.process;
// const DirOpenOptions = fs.Dir.OpenOptions;
// const FileCreateFlags = fs.File.CreateFlags;
// const FileOpenMode = fs.File.OpenMode;
// const TemplateMap = std.StaticStringMap([]const u8);

// const Root = @import("./_root.zig");
// const Buffer = Root.CollectionTypes.StaticAllocList.define_list_type(.{
//     .alignment = 1,
//     .alloc_error_behavior = .ALLOCATION_ERRORS_PANIC,
//     .allocator = &std.heap.page_allocator,
//     .element_type = u8,
//     .index_type = usize,
//     .growth_model = .GROW_BY_50_PERCENT,
// });
// const FILE_CREATE_FLAGS = FileCreateFlags{
//     .read = false,
//     .exclusive = false,
//     .lock = .exclusive,
//     .lock_nonblocking = false,
//     .truncate = true,
//     .mode = fs.File.default_mode,
// };

// pub const Generator = struct {
//     buffer: Buffer = Buffer{},

//     pub inline fn new() Generator {
//         return Generator{
//             .buffer = Buffer{},
//         };
//     }

//     pub inline fn fresh_writer(self: *Generator) Buffer.Writer {
//         self.buffer.clear_retaining_capacity();
//         return self.buffer.get_writer();
//     }

//     pub fn save_buffer_to_file(self: *Generator, directory_path_relative_to_cwd: []const u8, filename: []const u8) void {
//         self.buffer.clear_retaining_capacity();
//         const cwd = fs.cwd();
//         cwd.makePath(directory_path_relative_to_cwd) catch |err| std.debug.panic("Generator failed to find or create output directory `(cwd)/{s}`: {s}", .{ directory_path_relative_to_cwd, @errorName(err) });
//         const file_dir = cwd.openDir(directory_path_relative_to_cwd, .{}) catch |err| std.debug.panic("Generator failed to open output directory `(cwd)/{s}`: {s}", .{ directory_path_relative_to_cwd, @errorName(err) });
//         defer file_dir.close();
//         const file = file_dir.createFile(filename, FILE_CREATE_FLAGS) catch |err| std.debug.panic("Generator failed to create or open output file `(cwd)/{s}/{s}`: {s}", .{ directory_path_relative_to_cwd, filename, @errorName(err) });
//         defer file.close();
//         file.writeAll(self.buffer[0..self.buffer.len]) catch |err| std.debug.panic("Generator failed to write to file `(cwd)/{s}/{s}`: {s}", .{ directory_path_relative_to_cwd, filename, @errorName(err) });
//     }

//     pub inline fn release_memory(self: *Generator) void {
//         self.buffer.clear_and_free();
//     }
// };

// // pub const PACKED = "packed ";
// // pub const EXTERN = "extern ";
// // pub const PACKED_STRUCT = "packed struct {\n";
// // pub const EXTERN_STRUCT = "extern struct {\n";
// // pub const PUB = "pub ";
// // pub const INLINE = "inline ";
// // pub const PUB_INLINE_FN = "pub inline fn ";
// // pub const INLINE_FN = "inline fn ";
// // pub const PUB_FN = "pub fn ";
// // pub const EMPTY = "";
// // pub const FN = "fn ";
// // pub const CONST = "const ";
// // pub const VAR = "var ";
// // pub const STRUCT = "struct {\n";
// // pub const END_STRUCT = "\n};\n";
// // pub const END_FN = "\n}\n";
// // pub const U8 = "u8";
// // pub const I8 = "i8";
// // pub const U16 = "u16";
// // pub const I16 = "i16";
// // pub const U32 = "u32";
// // pub const I32 = "i32";
// // pub const U64 = "u64";
// // pub const I64 = "i64";
// // pub const U128 = "u128";
// // pub const I128 = "i128";
// // pub const USIZE = "usize";
// // pub const ISIZE = "isize";
// // pub const F16 = "f16";
// // pub const F32 = "f32";
// // pub const F64 = "f64";
// // pub const F80 = "f80";
// // pub const F128 = "f128";
// // pub const BOOL = "bool";
// // pub const VOID = "void";

// // pub inline fn ANY_ERROR_UNION(comptime good_type: []const u8) []const u8 {
// //     return "!" + good_type;
// // }

// // pub inline fn ERROR_UNION(comptime err_type: []const u8, comptime good_type: []const u8) []const u8 {
// //     return err_type ++ "!" + good_type;
// // }

// // pub inline fn OPTIONAL(comptime exists_type: []const u8) []const u8 {
// //     return "?" ++ exists_type;
// // }

// // pub inline fn SLICE(comptime child_type: []const u8) []const u8 {
// //     return "[]" ++ child_type;
// // }

// // pub inline fn SLICE_CONST(comptime child: []const u8) []const u8 {
// //     return "[]const " ++ child;
// // }

// // pub inline fn SLICE_ALIGN(comptime with_align: []const u8, comptime child: []const u8) []const u8 {
// //     return "[]align(" ++ with_align ++ ") " ++ child;
// // }

// // pub inline fn SLICE_CONST_ALIGN(comptime with_align: []const u8, comptime child: []const u8) []const u8 {
// //     return "[]const align(" ++ with_align ++ ") " ++ child;
// // }

// // pub fn if_else(comptime T: type, comptime cond: bool, comptime if_true: T, comptime if_false: T) T {
// //     if (cond) return if_true;
// //     return if_false;
// // }

// // pub fn INLINE_if(comptime cond: bool) []const u8 {
// //     if (cond) return INLINE;
// //     return EMPTY;
// // }
// // pub fn PUB_if(comptime cond: bool) []const u8 {
// //     if (cond) return PUB;
// //     return EMPTY;
// // }
// // pub fn PACKED_if(comptime cond: bool) []const u8 {
// //     if (cond) return PACKED;
// //     return EMPTY;
// // }
// // pub fn EXTERN_if(comptime cond: bool) []const u8 {
// //     if (cond) return EXTERN;
// //     return EMPTY;
// // }
// // pub fn CONST_if(comptime cond: bool) []const u8 {
// //     if (cond) return CONST;
// //     return VAR;
// // }
