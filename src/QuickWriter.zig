//! This module provides a quick implementation of `std.Io.Writer`
//! that has NO flush location. It simply writes to the provided
//! buffer, and returns an error if a write would overfill the buffer
//! (cause a flush/drain)
//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
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
const std = @import("std");
const Writer = std.Io.Writer;
const File = std.fs.File;

pub fn writer(buf: []u8) Writer {
    return Writer{
        .buffer = buf,
        .end = 0,
        .vtable = &VTABLE,
    };
}

const VTABLE = Writer.VTable{
    .drain = impl_drain,
    .flush = impl_flush,
};

fn impl_drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
    _ = w;
    _ = data;
    _ = splat;
    return Writer.Error.WriteFailed;
}
fn impl_flush(w: *Writer) Writer.Error!void {
    _ = w;
    return Writer.Error.WriteFailed;
}
