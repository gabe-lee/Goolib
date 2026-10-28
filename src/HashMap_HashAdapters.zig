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

const std = @import("std");
const _WyHash = std.hash.Wyhash;
const _Murmur2_64 = std.hash.Murmur2_64;
const _Murmur3_32 = std.hash.Murmur3_32;
const _Fnv1a_64 = std.hash.Fnv1a_64;

/// Default is WyHash for best bit distribution
pub fn Default(comptime KEY: type) fn (KEY) u64 {
    return WyHash(KEY);
}
pub fn WyHash(comptime KEY: type) fn (KEY) u64 {
    const PROTO = struct {
        fn hash(k: KEY) u64 {
            var h = _WyHash.init(0);
            const bytes = std.mem.asBytes(&k);
            h.update(bytes);
            return h.final();
        }
    };
    return PROTO.hash;
}

pub fn Murmur3_32_to_64(comptime KEY: type) fn (KEY) u64 {
    const PROTO = struct {
        fn hash(k: KEY) u64 {
            if (comptime KEY == u32) {
                const out: u64 = @intCast(_Murmur3_32.hashUint32WithSeed(k, 0));
                return out | (out << 32);
            } else if (comptime KEY == u64) {
                const out: u64 = @intCast(_Murmur3_32.hashUint64WithSeed(k, 0));
                return out | (out << 32);
            } else {
                const bytes = std.mem.asBytes(&k);
                const out: u64 = @intCast(_Murmur3_32.hashWithSeed(bytes, 0));
                return out | (out << 32);
            }
        }
    };
    return PROTO.hash;
}
pub fn Murmur2_64(comptime KEY: type) fn (KEY) u64 {
    const PROTO = struct {
        fn hash(k: KEY) u64 {
            if (comptime KEY == u32) {
                return _Murmur2_64.hashUint32WithSeed(k, 0);
            } else if (comptime KEY == u64) {
                return _Murmur2_64.hashUint64WithSeed(k, 0);
            } else {
                const bytes = std.mem.asBytes(&k);
                return _Murmur2_64.hashWithSeed(bytes, 0);
            }
        }
    };
    return PROTO.hash;
}
pub fn Fnv1a_64(comptime KEY: type) fn (KEY) u64 {
    const PROTO = struct {
        fn hash(k: KEY) u64 {
            var h = _Fnv1a_64.init();
            const bytes = std.mem.asBytes(&k);
            h.update(bytes);
            return h.final();
        }
    };
    return PROTO.hash;
}
