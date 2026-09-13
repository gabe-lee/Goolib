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

pub const RESET = "\x1b[0m";
pub const BOLD = "\x1b[1m";
pub const FAINT = "\x1b[2m";
pub const UNDERLINE = "\x1b[4m";
pub const BLINK = "\x1b[5m";
pub const FG_BLACK = "\x1b[30m";
pub const FG_RED = "\x1b[31m";
pub const FG_GREEN = "\x1b[32m";
pub const FG_YELLOW = "\x1b[33m";
pub const FG_BLUE = "\x1b[34m";
pub const FG_MAGENTA = "\x1b[35m";
pub const FG_CYAN = "\x1b[36m";
pub const FG_WHITE = "\x1b[37m";
pub const BG_BLACK = "\x1b[40m";
pub const BG_RED = "\x1b[41m";
pub const BG_GREEN = "\x1b[42m";
pub const BG_YELLOW = "\x1b[43m";
pub const BG_BLUE = "\x1b[44m";
pub const BG_MAGENTA = "\x1b[45m";
pub const BG_CYAN = "\x1b[46m";
pub const BG_WHITE = "\x1b[47m";
