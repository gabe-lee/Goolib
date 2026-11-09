//! //TODO Documentation
//! #### License: zlib

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

/// Returns a unique identifier for the given type, which can be used at runtime.
///
/// This uses a trick where a unique phantom type is generated for every
/// call of this function with a unique `T` value, then taking a pointer
/// to a single const byte on the phantom type, and using the usize address
/// of that byte pointer as the 'type id' for the original type
pub fn get_type_id(comptime T: type) usize {
    const UNIQUE_TYPE = struct {
        const byte: u8 = 0;
        const _ = T;
    };
    return @intFromPtr(&UNIQUE_TYPE.byte);
}
