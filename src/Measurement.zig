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

pub const FEET_TO_INCHES = 12.0;
pub const INCHES_TO_FEET = 1.0 / 12.0;

pub const YARDS_TO_FEET = 3.0;
pub const FEET_TO_YARDS = 1.0 / 3.0;

pub const YARDS_TO_INCHES = 36.0;
pub const INCHES_TO_YARDS = 1.0 / 36.0;

pub const FEET_TO_MILES = 1.0 / 5280.0;
pub const MILES_TO_FEET = 5280.0;

pub const YARDS_TO_MILES = 1.0 / 1760.0;
pub const MILES_TO_YARDS = 1760.0;

pub const INCHES_TO_MILES = 1.0 / 63360.0;
pub const MILES_TO_INCHES = 63360.0;

pub const INCHES_TO_CM = 2.54;
pub const CM_TO_INCHES = 1.0 / 2.54;

pub const YARDS_TO_METERS = 0.9144;
pub const METERS_TO_YARDS = 1.0 / 0.9144;

pub const MILES_TO_KM = 1.609344;
pub const KM_TO_MILES = 1.0 / 1.609344;

pub const METERS_TO_MM = 1000.0;
pub const MM_TO_METERS = 1.0 / 1000.0;

pub const METERS_TO_KM = 1.0 / 1000.0;
pub const KM_TO_METERS = 1000.0;

pub const METERS_TO_CM = 100.0;
pub const CM_TO_METERS = 1.0 / 100.0;

pub const CM_TO_MM = 10.0;
pub const MM_TO_CM = 1.0 / 10.0;

pub const KM_TO_CM = 100000.0;
pub const CM_TO_KM = 1.0 / 100000.0;

pub const KM_TO_MM = 1000000.0;
pub const MM_TO_KM = 1.0 / 1000000.0;



