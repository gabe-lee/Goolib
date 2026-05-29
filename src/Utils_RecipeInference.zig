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
const build = @import("builtin");
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const math = std.math;
const fmt = std.fmt;
const Random = std.Random;
// const pq = std.PriorityQueue;

const Root = @import("./_root.zig");
const object_equals = Root.Utils.Compare.shallow_equals;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const Endian = Root.CommonTypes.Endian;
const Math = Root.Math;
const Common = Root.CommonTypes;

const DEBUG = std.debug.print;

pub const WeightVsUserProvidedMode = enum(u8) {
    ALLOW_LOW_WEIGHT_INFER_TO_OVERRIDE_USER_PROVIDED,
    ALWAYS_USE_USER_PROVIDED,
};

pub const RecipeResolutionKind = enum(u8) {
    USER_PROVIDED,
    INFERED_BY_RECIPE,
    UNAVAILABLE,
};

pub const RecipeResolveBranch = enum(u2) {
    CHECKING = 0,
    NOT_AVAILABLE = 1,
    IS_AVAILABLE = 2,
};

pub const WeightO = enum {
    one,
    n,
    log_n,
    n_log_n,
    n_squared,
    exponential,
};

pub fn WeightModeInfo(comptime RecipeTag: type) type {
    return struct {
        tags_equal: ?*const fn (a: RecipeTag, b: RecipeTag) bool = null,
        weight_type: type = f32,
    };
}

pub fn RecipeInferenceEngine(comptime TargetEnum: type, comptime SolutionTag: type, comptime OptionalWeightInfo: ?WeightModeInfo(SolutionTag)) type {
    assert_with_reason(Types.all_enum_values_start_from_zero_with_no_gaps(TargetEnum), @src(), "all tags in `TargetEnum` must start from 0 and increase to max value with no gaps", .{});
    return struct {
        pub const NUM_BITS = @typeInfo(TargetEnum).@"enum".fields.len;
        pub const BitFlagInt = @Int(.unsigned, NUM_BITS);
        pub const Log2BitFlagInt = math.Log2Int(BitFlagInt);
        pub const EnumTagInt = @typeInfo(TargetEnum).@"enum".tag_type;
        pub const HAS_WEIGHT = OptionalWeightInfo != null;
        pub const WeightType = if (OptionalWeightInfo) |INFO| INFO.weight_type else void;
        pub const MAX_RECIPE_WEIGHT: WeightType = if (HAS_WEIGHT) get: {
            if (Types.type_is_int(WeightType)) break :get math.maxInt(WeightType);
            if (Types.type_is_float(WeightType)) break :get math.inf(WeightType);
            assert_unreachable(null, "`OptionalRecipeWeightType` was not `null`, but the type provided wasn't an integer or float, got type `{s}`", .{@typeName(WeightType)});
        } else void{};
        const recipe_tags_equal: *const fn (a: SolutionTag, b: SolutionTag) bool = if (OptionalWeightInfo != null and OptionalWeightInfo.?.tags_equal != null) OptionalWeightInfo.?.tags_equal.? else &defualt_tags_equal;
        fn defualt_tags_equal(a: SolutionTag, b: SolutionTag) bool {
            return Utils.shallow_equal(a, b);
        }
        pub const NEUTRAL_RECIPE_WEIGHT: WeightType = if (HAS_WEIGHT) 1 else void{};
        pub const ZERO_RECIPE_WEIGHT: WeightType = if (HAS_WEIGHT) 0 else void{};
        pub const ALL_TARGETS: [NUM_BITS]TargetEnum = make: {
            var out: [NUM_BITS]TargetEnum = undefined;
            for (0..NUM_BITS) |i| {
                out[i] = @enumFromInt(@as(Log2BitFlagInt, @intCast(i)));
            }
            break :make out;
        };
        pub const UNINIT_RECIPES: AllRecipes = make: {
            var out: AllRecipes = undefined;
            for (ALL_TARGETS, 0..) |ent, e| {
                const list = RecipeList.recipe_list(ent, &.{});
                out[e] = list;
            }
            break :make out;
        };
        fn get_log_n(n: WeightType) WeightType {
            if (comptime !HAS_WEIGHT) return ZERO_RECIPE_WEIGHT;
            if (Types.type_is_int(WeightType)) return @intCast(@ctz(n));
            if (Types.type_is_float(WeightType)) return math.log2(n);
            return NEUTRAL_RECIPE_WEIGHT;
        }
        pub const Weight = struct {
            f: WeightType = ZERO_RECIPE_WEIGHT,
            k: WeightType = NEUTRAL_RECIPE_WEIGHT,
            O: WeightO = WeightO.one,

            pub fn eval(self: Weight, target_n: WeightType) WeightType {
                if (comptime !HAS_WEIGHT) return ZERO_RECIPE_WEIGHT;
                const o: WeightType = switch (self.O) {
                    .one => 1,
                    .n => target_n,
                    .log_n => get_log_n(target_n),
                    .n_log_n => target_n * get_log_n(target_n),
                    .n_squared => target_n * target_n,
                    .exponential => math.pow(WeightType, 2, target_n),
                };
                return self.f + (self.k * o);
            }

            pub fn zero() Weight {
                return Weight{ .k = ZERO_RECIPE_WEIGHT };
            }
            pub fn flat(flat_weight: WeightType) Weight {
                return Weight{ .f = flat_weight };
            }
            pub fn one() Weight {
                return Weight{};
            }
            pub fn n() Weight {
                return Weight{ .O = .n };
            }
            pub fn k_n(k: WeightType) Weight {
                return Weight{ .k = k, .O = .n };
            }
            pub fn n_plus_k_n(k: WeightType) Weight {
                return Weight{ .k = k + 1, .O = .n };
            }
            pub fn log_n() Weight {
                return Weight{ .O = .log_n };
            }
            pub fn k_log_n(k: WeightType) Weight {
                return Weight{ .k = k, .O = .log_n };
            }
            pub fn n_log_n() Weight {
                return Weight{ .O = .n_log_n };
            }
            pub fn k_n_log_n(k: WeightType) Weight {
                return Weight{ .k = k, .O = .n_log_n };
            }
            pub fn n_squared() Weight {
                return Weight{ .O = .n_squared };
            }
            pub fn k_n_squared(k: WeightType) Weight {
                return Weight{ .k = k, .O = .n_squared };
            }
            pub fn exponential() Weight {
                return Weight{ .O = .exponential };
            }
            pub fn k_exponential(k: WeightType) Weight {
                return Weight{ .k = k, .O = .exponential };
            }
        };

        pub const Dependancy = struct {
            target: TargetEnum,
            weight: Weight,

            pub fn depends_on(target: TargetEnum) Dependancy {
                return Dependancy{
                    .target = target,
                    .weight = .one(),
                };
            }
            pub fn depends_on_with_weight(target: TargetEnum, weight: Weight) Dependancy {
                return Dependancy{
                    .target = target,
                    .weight = weight,
                };
            }
            pub fn depends_on_zero_weight(target: TargetEnum) Dependancy {
                return Dependancy{
                    .target = target,
                    .weight = .zero(),
                };
            }
        };
        pub const Recipe = struct {
            dependancies: []const Dependancy,
            variant_tag: SolutionTag,
            special_mult_factor: WeightType = NEUTRAL_RECIPE_WEIGHT,
            special_flat_add_factor: WeightType = ZERO_RECIPE_WEIGHT,

            pub fn recipe(variant: SolutionTag, dependancies: []const Dependancy) Recipe {
                return Recipe{
                    .variant_tag = variant,
                    .dependancies = dependancies,
                };
            }
            pub fn recipe_with_special_factors(variant: SolutionTag, special_multiplier: Weight, special_flat_add: Weight, dependancies: []const Dependancy) Recipe {
                return Recipe{
                    .variant_tag = variant,
                    .dependancies = dependancies,
                    .special_mult_factor = special_multiplier,
                    .special_flat_add_factor = special_flat_add,
                };
            }
        };
        pub const RecipeList = struct {
            this_target: TargetEnum,
            target_bit: BitFlagInt,
            bit_shift_for_bit: Log2BitFlagInt,
            recipes_in_prefered_order: []const Recipe,

            pub fn recipe_list(this_target: TargetEnum, recipes_in_prefered_order: []const Recipe) RecipeList {
                const shift: Log2BitFlagInt = @intCast(@intFromEnum(this_target));
                const bit: BitFlagInt = @as(BitFlagInt, 1) << shift;
                return RecipeList{
                    .this_target = this_target,
                    .bit_shift_for_bit = shift,
                    .target_bit = bit,
                    .recipes_in_prefered_order = recipes_in_prefered_order,
                };
            }
        };
        pub const RecipeSolution = union(enum) {
            USER_PROVIDED: void,
            INFERED_BY_RECIPE: SolutionTag,
            UNAVAILABLE: void,

            pub fn user_provided() RecipeSolution {
                return RecipeSolution{ .USER_PROVIDED = void{} };
            }
            pub fn infered_by_recipe(recipe: SolutionTag) RecipeSolution {
                return RecipeSolution{ .INFERED_BY_RECIPE = recipe };
            }
            pub fn unavailable() RecipeSolution {
                return RecipeSolution{ .UNAVAILABLE = void{} };
            }
        };
        pub const AllRecipes = [NUM_BITS]RecipeList;
        pub const AllSolutions = [NUM_BITS]RecipeSolution;

        pub fn print_solutions(resolutions: AllSolutions) void {
            std.debug.print("Recipe Solutions:\n", .{});
            var num_user: usize = 0;
            var num_unavailable: usize = 0;
            var num_infer: usize = 0;
            for (resolutions, ALL_TARGETS) |res, target| {
                switch (res) {
                    .USER_PROVIDED => {
                        num_user += 1;
                        std.debug.print("\t{s}: <USER>\n", .{@tagName(target)});
                    },
                    .UNAVAILABLE => {
                        num_unavailable += 1;
                        std.debug.print("\t{s}: <UNAVAILABLE>\n", .{@tagName(target)});
                    },
                    .INFERED_BY_RECIPE => |infer| {
                        num_infer += 1;
                        if (comptime Types.type_is_slice(SolutionTag) and Types.child_type(SolutionTag) == u8) {
                            std.debug.print("\t{s}: <INFER> = {s}\n", .{ @tagName(target), infer });
                        } else if (comptime Types.type_is_enum(SolutionTag)) {
                            std.debug.print("\t{s}: <INFER> = {s}\n", .{ @tagName(target), @tagName(infer) });
                        } else {
                            std.debug.print("\t{s}: <INFER> = {any}\n", .{ @tagName(target), infer });
                        }
                    },
                }
            }
            std.debug.print("\t+++++++++++++++++++++++\n\tNUM USER PROVIDED: {d}\n\tNUM INFERED: {d}\n\tNUM UNAVAILABLE: {d}\n", .{ num_user, num_infer, num_unavailable });
        }

        fn get_recipes_for_target(target: TargetEnum, recipes: AllRecipes) []const Recipe {
            const target_index = @intFromEnum(target);
            return recipes[target_index].recipes_in_prefered_order;
        }

        pub const Target = struct {
            target_enum: TargetEnum,
            native_weight: WeightType = if (HAS_WEIGHT) 1 else void{},

            pub fn user_provided(tar: TargetEnum) Target {
                return Target{ .target_enum = tar };
            }
            pub fn set_property(tar: TargetEnum) Target {
                return Target{ .target_enum = tar };
            }
            pub fn user_provided_with_weight(tar: TargetEnum, weight: WeightType) Target {
                return Target{
                    .target_enum = tar,
                    .native_weight = weight,
                };
            }
        };
        fn weight_approx_equal(a: WeightType, b: WeightType) bool {
            if (comptime HAS_WEIGHT) {
                if (Types.type_is_int(WeightType)) return a == b;
                return math.approxEqRel(WeightType, a, b, 4 * math.floatEpsAt(WeightType, @min(a, b)));
            } else {
                return true;
            }
        }

        pub fn resolve_recipes_by_weight(target_n: WeightType, weight_vs_user_provided: WeightVsUserProvidedMode, user_provided_entities: []const Target, recipes: []const RecipeList) AllSolutions {
            return resolve_recipes_internal(user_provided_entities, recipes, target_n, weight_vs_user_provided, true);
        }
        pub fn resolve_recipes_by_order(user_provided_entities: []const Target, recipes: []const RecipeList) AllSolutions {
            return resolve_recipes_internal(user_provided_entities, recipes, 0, false);
        }

        fn resolve_recipes_internal(user_provided_entities: []const Target, provided_recipes: []const RecipeList, target_n: WeightType, WEIGHT_USER_MODE: WeightVsUserProvidedMode, comptime USE_WEIGHT_IF_AVAILABLE: bool) AllSolutions {
            const USE_WEIGHT = comptime HAS_WEIGHT and USE_WEIGHT_IF_AVAILABLE;
            var available_bits: BitFlagInt = 0;
            var resolutions: AllSolutions = @splat(RecipeSolution.unavailable());
            var recipe_lists_found: BitFlagInt = 0;
            var best_recipe_weights: [NUM_BITS]WeightType = @splat(MAX_RECIPE_WEIGHT);
            var recipes: AllRecipes = UNINIT_RECIPES;
            for (user_provided_entities) |target| {
                const target_bit_shift: Log2BitFlagInt = @intCast(@intFromEnum(target.target_enum));
                const target_bit: BitFlagInt = @as(BitFlagInt, 1) << target_bit_shift;
                assert_with_reason(available_bits & target_bit == 0, @src(), "target `{s}` was provided more than once", .{@tagName(target.target_enum)});
                best_recipe_weights[target_bit_shift] = target.native_weight;
                resolutions[target_bit_shift] = .user_provided();
                available_bits |= target_bit;
            }
            for (provided_recipes) |recipe_list| {
                assert_with_reason(recipe_lists_found & recipe_list.target_bit == 0, @src(), "recipe list for target `{s}` was provided more than once", .{@tagName(recipe_list.this_target)});
                recipe_lists_found |= recipe_list.target_bit;
                for (recipe_list.recipes_in_prefered_order) |recipe| {
                    for (recipe.dependancies) |dep| {
                        const dep_bit_shift: Log2BitFlagInt = @intCast(@intFromEnum(dep.target));
                        const dep_bit: BitFlagInt = @as(BitFlagInt, 1) << dep_bit_shift;
                        assert_with_reason(recipe_list.target_bit & dep_bit == 0, @src(), "recipe variant `{any}` for target `{s}` references itself in its dependancies", .{ recipe.variant_tag, @tagName(recipe_list.this_target) });
                    }
                }
                const target_id = recipe_list.bit_shift_for_bit;
                recipes[target_id] = recipe_list;
            }
            var change_in_resolutions = true;
            while (change_in_resolutions) {
                change_in_resolutions = false;
                next_target: for (ALL_TARGETS) |target| {
                    const target_shift: Log2BitFlagInt = @intCast(@intFromEnum(target));
                    const target_bit: BitFlagInt = @as(BitFlagInt, 1) << target_shift;
                    var currently_available = available_bits & target_bit != 0;
                    if (comptime !USE_WEIGHT) {
                        if (currently_available) continue :next_target;
                    } else {
                        if (WEIGHT_USER_MODE == .ALWAYS_USE_USER_PROVIDED and resolutions[target_shift] == .USER_PROVIDED) continue :next_target;
                    }
                    var current_weight = best_recipe_weights[target_shift];
                    var current_resolution = resolutions[target_shift];
                    next_recipe: for (get_recipes_for_target(target, recipes)) |recipe| {
                        resolve: switch (RecipeResolveBranch.CHECKING) {
                            .CHECKING => {
                                for (recipe.dependancies) |dep| {
                                    const dep_bit_shift: Log2BitFlagInt = @intCast(@intFromEnum(dep.target));
                                    const dep_bit: BitFlagInt = @as(BitFlagInt, 1) << dep_bit_shift;
                                    if (available_bits & dep_bit == 0) continue :resolve .NOT_AVAILABLE;
                                }
                                continue :resolve .IS_AVAILABLE;
                            },
                            .IS_AVAILABLE => {
                                var total_recipe_weight: WeightType = ZERO_RECIPE_WEIGHT;
                                if (comptime USE_WEIGHT) {
                                    for (recipe.dependancies) |dep| {
                                        const dep_bit_idx: Log2BitFlagInt = @intCast(@intFromEnum(dep.target));
                                        const current_dep_weight = best_recipe_weights[dep_bit_idx];
                                        total_recipe_weight += dep.weight.eval(target_n) * current_dep_weight;
                                    }
                                    total_recipe_weight *= recipe.special_mult_factor;
                                    total_recipe_weight += recipe.special_flat_add_factor;
                                }

                                if (currently_available) {
                                    if (comptime !USE_WEIGHT) continue :next_recipe;
                                    if (weight_approx_equal(total_recipe_weight, current_weight)) continue :next_recipe;
                                    if (total_recipe_weight > current_weight) {
                                        switch (current_resolution) {
                                            .USER_PROVIDED => continue :next_recipe,
                                            .INFERED_BY_RECIPE => |recipe_tag| {
                                                if (!recipe_tags_equal(recipe_tag, recipe.variant_tag)) {
                                                    continue :next_recipe;
                                                }
                                            },
                                            else => unreachable,
                                        }
                                    }
                                }
                                current_weight = total_recipe_weight;
                                currently_available = true;
                                current_resolution = RecipeSolution.infered_by_recipe(recipe.variant_tag);
                                best_recipe_weights[target_shift] = total_recipe_weight;
                                available_bits |= target_bit;
                                resolutions[target_shift] = current_resolution;
                                change_in_resolutions = true;
                            },
                            .NOT_AVAILABLE => {
                                if (currently_available) {
                                    switch (current_resolution) {
                                        .USER_PROVIDED => continue :next_recipe,
                                        .INFERED_BY_RECIPE => |recipe_tag| {
                                            if (recipe_tags_equal(recipe_tag, recipe.variant_tag)) {
                                                assert_unreachable(@src(), "this should be unreachable?", .{});
                                            }
                                        },
                                        else => unreachable,
                                    }
                                }
                            },
                        }
                    }
                }
            }
            if (comptime USE_WEIGHT) {
                for (user_provided_entities) |target| {
                    const target_bit_shift: Log2BitFlagInt = @intCast(@intFromEnum(target.target_enum));
                    const target_bit: BitFlagInt = @as(BitFlagInt, 1) << target_bit_shift;
                    switch (resolutions[target_bit_shift]) {
                        .USER_PROVIDED => {},
                        .INFERED_BY_RECIPE => {
                            if (best_recipe_weights[target_bit_shift] > target.native_weight) {
                                resolutions[target_bit_shift] = .user_provided();
                                best_recipe_weights[target_bit_shift] = target.native_weight;
                            }
                        },
                        .UNAVAILABLE => {
                            resolutions[target_bit_shift] = .user_provided();
                            best_recipe_weights[target_bit_shift] = target.native_weight;
                            available_bits |= target_bit;
                        },
                    }
                }
            }

            return resolutions;
        }
    };
}

test RecipeInferenceEngine {
    const PRINT_RESULTS = false;
    const TARGET_N = 32; // Num bits in int
    const CMP_WEIGHT = 1;
    const Op = enum {
        ADD,
        SUB,
        MUL,
        DIV,
        NEG,
        MOD,
        SHL,
        SHR,
        POW,
        INV,
    };
    const Tag = []const u8;
    const PROTO = struct {
        fn tag_equal(a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    };
    const WeightInfo = WeightModeInfo(Tag);
    const Engine = RecipeInferenceEngine(Op, Tag, WeightInfo{
        .tags_equal = PROTO.tag_equal,
        .weight_type = f32,
    });
    const RecipeList = Engine.RecipeList;
    const Target = Engine.Target;
    const recipes: []const RecipeList = &.{
        .recipe_list(.ADD, &.{
            .recipe("a - (-b)", &.{
                .depends_on_with_weight(.SUB, .one()),
                .depends_on_with_weight(.NEG, .one()),
            }),
            .recipe("a - (0 - b)", &.{
                .depends_on_with_weight(.SUB, .flat(2)),
            }),
        }),
        .recipe_list(.SUB, &.{
            .recipe("a + ((~b) + 1)", &.{
                .depends_on_with_weight(.ADD, .flat(2)),
                .depends_on_with_weight(.INV, .one()),
            }),
            .recipe("a + (-b)", &.{
                .depends_on_with_weight(.ADD, .one()),
                .depends_on_with_weight(.NEG, .one()),
            }),
        }),
        .recipe_list(.MUL, &.{
            .recipe("bit_shifts and add", &.{
                .depends_on_with_weight(.ADD, .k_n(0.5)),
                .depends_on_with_weight(.SHR, .k_n(0.5)),
                .depends_on_with_weight(.SHL, .k_n(0.5)),
            }),
            .recipe("a + a + a + a...", &.{
                .depends_on_with_weight(.ADD, .k_n(1.5)),
            }),
        }),
        .recipe_list(.DIV, &.{
            .recipe("bit_shifts and sub", &.{
                .depends_on_with_weight(.SUB, .n()),
                .depends_on_with_weight(.SHR, .k_n(0.5)),
                .depends_on_with_weight(.SHL, .k_n(0.5)),
            }),
            .recipe("a - a - a - a...", &.{
                .depends_on_with_weight(.SUB, .n_plus_k_n(CMP_WEIGHT)),
            }),
        }),
        .recipe_list(.NEG, &.{
            .recipe("0 - a", &.{
                .depends_on_with_weight(.SUB, .one()),
            }),
        }),
        .recipe_list(.MOD, &.{
            .recipe("a - (a / b) * b", &.{
                .depends_on_with_weight(.SUB, .one()),
                .depends_on_with_weight(.DIV, .one()),
                .depends_on_with_weight(.MUL, .one()),
            }),
            .recipe("(a - (a / b)) + (a - (a / b)) + ...", &.{
                .depends_on_with_weight(.SUB, .one()),
                .depends_on_with_weight(.DIV, .one()),
                .depends_on_with_weight(.ADD, .n()),
            }),
            .recipe("a - a - a - a...", &.{
                .depends_on_with_weight(.SUB, .n_plus_k_n(CMP_WEIGHT)),
            }),
        }),
        .recipe_list(.SHL, &.{
            .recipe("a * pow(2, b)", &.{
                .depends_on_with_weight(.MUL, .one()),
                .depends_on_with_weight(.POW, .one()),
            }),
            .recipe("a * (2 * 2 * 2 * 2 * ...)", &.{
                .depends_on_with_weight(.MUL, .n()),
            }),
        }),
        .recipe_list(.SHR, &.{
            .recipe("a / pow(2, b)", &.{
                .depends_on_with_weight(.DIV, .one()),
                .depends_on_with_weight(.POW, .one()),
            }),
            .recipe("a / (2 / 2 / 2 / 2 / ...)", &.{
                .depends_on_with_weight(.DIV, .n()),
            }),
        }),
        .recipe_list(.POW, &.{
            .recipe("binary exponentiation by squaring", &.{
                .depends_on_with_weight(.MUL, .n_plus_k_n(0.5)),
                .depends_on_with_weight(.SHR, .n()),
            }),
            .recipe("a * a * a * a...", &.{
                .depends_on_with_weight(.MUL, .n()),
            }),
            .recipe_with_special_factors("magic ASIC power", .zero(), .flat(0.5), &.{}),
        }),
    };
    const UNDER_PROVIDED: []const Target = &.{
        .user_provided(.INV),
        .user_provided(.SHL),
        .user_provided(.SHR),
    };
    const MIN_PROVIDED_ONE_HEAVY: []const Target = &.{
        .user_provided(.INV),
        .user_provided(.SUB),
        .user_provided_with_weight(.ADD, 100.0),
    };
    var results = Engine.resolve_recipes_by_weight(TARGET_N, UNDER_PROVIDED, recipes);
    if (PRINT_RESULTS) {
        std.debug.print("\n\ntest RecipeInferenceEngine results:\n=====================================\nunder-provided results (not enough funcs to infer all):\n", .{});
        for (results, 0..) |res, r| {
            const tag: Op = @enumFromInt(@as(Engine.EnumTagInt, @intCast(r)));
            switch (res) {
                .INFERED_BY_RECIPE => |infer| std.debug.print("\t{s}: method is infered by '{s}'\n", .{ @tagName(tag), infer }),
                .USER_PROVIDED => std.debug.print("\t{s}: method is user provided!\n", .{@tagName(tag)}),
                .UNAVAILABLE => std.debug.print("\t{s}: method is UNAVAILABLE\n", .{@tagName(tag)}),
            }
        }
    }
    results = Engine.resolve_recipes_by_weight(TARGET_N, MIN_PROVIDED_ONE_HEAVY, recipes);
    if (PRINT_RESULTS) {
        std.debug.print("\nby-weight results (select the best function based on user-provided hueristics, possibly overriding user-provided functions):\n", .{});
        for (results, 0..) |res, r| {
            const tag: Op = @enumFromInt(@as(Engine.EnumTagInt, @intCast(r)));
            switch (res) {
                .INFERED_BY_RECIPE => |infer| std.debug.print("\t{s}: method is infered by '{s}'\n", .{ @tagName(tag), infer }),
                .USER_PROVIDED => std.debug.print("\t{s}: method is user provided!\n", .{@tagName(tag)}),
                .UNAVAILABLE => std.debug.print("\t{s}: method is UNAVAILABLE\n", .{@tagName(tag)}),
            }
        }
    }
    results = Engine.resolve_recipes_by_order(MIN_PROVIDED_ONE_HEAVY, recipes);
    if (PRINT_RESULTS) {
        std.debug.print("\nby-order results (choose the first recipe in the recipe list that is available regardless of weight (only if no user func provided)):\n", .{});
        for (results, 0..) |res, r| {
            const tag: Op = @enumFromInt(@as(Engine.EnumTagInt, @intCast(r)));
            switch (res) {
                .INFERED_BY_RECIPE => |infer| std.debug.print("\t{s}: method is infered by '{s}'\n", .{ @tagName(tag), infer }),
                .USER_PROVIDED => std.debug.print("\t{s}: method is user provided!\n", .{@tagName(tag)}),
                .UNAVAILABLE => std.debug.print("\t{s}: method is UNAVAILABLE\n", .{@tagName(tag)}),
            }
        }
        std.debug.print("=====================================\n\n", .{});
    }
}
