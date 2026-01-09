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
const std = @import("std");
const math = std.math;

const Root = @import("./_root.zig");
const MathX = Root.Math;
const M = Root.Measurement;

const num_cast = Root.Cast.num_cast;

pub fn Reslution_DPM(comptime T: type) type {
    return struct {
        const Self = @This();

        raw: T = 2835, // ~72 DPI,

        /// Dots(Pixels)-Per-Inch
        pub fn new_dpi(dpi: anytype) Self {
            return Self{
                .raw = MathX.upgrade_multiply_out(dpi, M.METERS_TO_YARDS * M.YARDS_TO_INCHES, T),
            };
        }

        /// Dots(Pixels)-Per-Meter
        pub fn new_dpm(dpm: anytype) Self {
            return Self{
                .raw = num_cast(dpm, T),
            };
        }
    };
}

pub fn Reslution_DPI(comptime T: type) type {
    return struct {
        const Self = @This();

        raw: T = 72,

        /// Dots(Pixels)-Per-Inch
        pub fn new_dpi(dpi: anytype) Self {
            return Self{
                .raw = num_cast(dpi, T),
            };
        }

        /// Dots(Pixels)-Per-Meter
        pub fn new_dpm(dpm: anytype) Self {
            return Self{
                .raw = MathX.upgrade_multiply_out(dpm, M.INCHES_TO_YARDS * M.YARDS_TO_METERS, T),
            };
        }
    };
}
