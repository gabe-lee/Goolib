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
const Hash = std.hash.XxHash64;

pub const TypeIdMode = enum(u8) {
    LINKSECTION_ADDRESS,
    DISCRIMINANT_ADDRESS,
    TYPE_NAME_HASH,
};

pub const MODE = TypeIdMode.LINKSECTION_ADDRESS;
pub const TypeId = u64;

const TYPE_ID_SECTION_NAME = ".bss.GoolibTypeIds";
const @"GoolibTypeIds.head": u8 linksection(TYPE_ID_SECTION_NAME ++ "0") = 0;

pub fn get_type_id(comptime T: type) TypeId {
    switch (MODE) {
        .LINKSECTION_ADDRESS => {
            const DESCRIMINANT_TYPE = struct {
                const byte: u8 linksection(TYPE_ID_SECTION_NAME ++ "1") = 0;
                const _ = T;
            };
            const LINK_SECTION_OFFSET = &DESCRIMINANT_TYPE.byte - &@"GoolibTypeIds.head";
            return @intCast(LINK_SECTION_OFFSET);
        },
        .DISCRIMINANT_ADDRESS => {
            const DESCRIMINANT_TYPE = struct {
                const byte: u8 = 0;
                const _ = T;
            };
            const DISCRIMINANT_ADDR = @intFromPtr(&DESCRIMINANT_TYPE.byte);
            return @ptrCast(DISCRIMINANT_ADDR);
        },
        .TYPE_NAME_HASH => {
            const hash = Hash.hash(0, @typeName(T));
            return @intCast(hash);
        },
    }
}
