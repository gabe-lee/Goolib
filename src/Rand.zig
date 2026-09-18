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
const Random = std.Random;

pub threadlocal var default_rand_core: Random.DefaultPrng = Random.DefaultPrng.init(0);
pub threadlocal var default_rand: Random = undefined;

pub fn seed_default_global_rand(seed: u64) void {
    default_rand_core = Random.DefaultPrng.init(seed);
    default_rand = default_rand_core.random();
}
pub fn seed_default_global_rand_and_get(seed: u64) Random {
    default_rand_core = Random.DefaultPrng.init(seed);
    default_rand = default_rand_core.random();
    return default_rand;
}
pub fn seed_default_global_rand_time_now(io: std.Io) void {
    default_rand_core = Random.DefaultPrng.init(@bitCast(std.Io.Clock.real.now(io).toMilliseconds()));
    default_rand = default_rand_core.random();
}
pub fn seed_default_global_rand_time_now_and_get(io: std.Io) Random {
    default_rand_core = Random.DefaultPrng.init(@bitCast(std.Io.Clock.real.now(io).toMilliseconds()));
    default_rand = default_rand_core.random();
    return default_rand;
}

pub fn create_new_default_prng_seeded_from_time(io: std.Io) Random.DefaultPrng {
    return Random.DefaultPrng.init(@bitCast(std.Io.Clock.real.now(io).toMilliseconds()));
}
pub fn create_new_default_prng_seeded_from_num(seed: u64) Random.DefaultPrng {
    return Random.DefaultPrng.init(seed);
}
