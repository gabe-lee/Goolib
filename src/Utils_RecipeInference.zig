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

const GraphColor = enum(u2) {
    WHITE = 0,
    GREY = 1,
    BLACK = 2,

    pub fn set_in_int(self: GraphColor, comptime INT: type, position_index: math.Log2Int(INT)) INT {
        const self_int: INT = @intCast(@intFromEnum(self));
        const true_offset: math.Log2Int(INT) = position_index << 1;
        return self_int << true_offset;
    }
    pub fn get_from_int(comptime INT: type, int: INT, position_index: math.Log2Int(INT)) GraphColor {
        const true_offset = position_index << 1;
        const self_int = int >> true_offset;
        const self_int_masked = self_int & 0b11;
        return @enumFromInt(@as(u2, @intCast(self_int_masked)));
    }
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
        pub const RecipeWeightType = if (OptionalWeightInfo) |INFO| INFO.weight_type else void;
        pub const MAX_RECIPE_WEIGHT: RecipeWeightType = if (HAS_WEIGHT) get: {
            if (Types.type_is_int(RecipeWeightType)) break :get math.maxInt(RecipeWeightType);
            if (Types.type_is_float(RecipeWeightType)) break :get math.inf(RecipeWeightType);
            assert_unreachable(null, "`OptionalRecipeWeightType` was not `null`, but the type provided wasn't an integer or float, got type `{s}`", .{@typeName(RecipeWeightType)});
        } else void{};
        const recipe_tags_equal: *const fn (a: SolutionTag, b: SolutionTag) bool = if (OptionalWeightInfo != null and OptionalWeightInfo.?.tags_equal != null) OptionalWeightInfo.?.tags_equal.? else &defualt_tags_equal;
        fn defualt_tags_equal(a: SolutionTag, b: SolutionTag) bool {
            return Utils.shallow_equal(a, b);
        }
        pub const NEUTRAL_RECIPE_WEIGHT: RecipeWeightType = if (HAS_WEIGHT) 1 else void{};
        pub const ZERO_RECIPE_WEIGHT: RecipeWeightType = if (HAS_WEIGHT) 0 else void{};
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
        pub const Dependancy = struct {
            target: TargetEnum,
            weight_multiplier: RecipeWeightType,

            pub fn depends_on(target: TargetEnum) Dependancy {
                return Dependancy{
                    .target = target,
                    .weight_multiplier = NEUTRAL_RECIPE_WEIGHT,
                };
            }
            pub fn depends_on_with_weight(target: TargetEnum, weight: RecipeWeightType) Dependancy {
                return Dependancy{
                    .target = target,
                    .weight_multiplier = weight,
                };
            }
        };
        pub const Recipe = struct {
            dependancies: []const Dependancy,
            variant_tag: SolutionTag,
            special_mult_factor: RecipeWeightType = NEUTRAL_RECIPE_WEIGHT,
            special_flat_add_factor: RecipeWeightType = ZERO_RECIPE_WEIGHT,

            pub fn recipe(variant: SolutionTag, dependancies: []const Dependancy) Recipe {
                return Recipe{
                    .variant_tag = variant,
                    .dependancies = dependancies,
                };
            }
            pub fn recipe_with_special_factors(variant: SolutionTag, special_multiplier: RecipeWeightType, special_flat_add: RecipeWeightType, dependancies: []const Dependancy) Recipe {
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
            native_weight: RecipeWeightType = if (HAS_WEIGHT) 1 else void{},

            pub fn user_provided(tar: TargetEnum) Target {
                return Target{ .target_enum = tar };
            }
            pub fn set_property(tar: TargetEnum) Target {
                return Target{ .target_enum = tar };
            }
            pub fn user_provided_with_weight(tar: TargetEnum, weight: RecipeWeightType) Target {
                return Target{
                    .target_enum = tar,
                    .native_weight = weight,
                };
            }
        };
        fn weight_approx_equal(a: RecipeWeightType, b: RecipeWeightType) bool {
            if (comptime HAS_WEIGHT) {
                if (Types.type_is_int(RecipeWeightType)) return a == b;
                return math.approxEqRel(RecipeWeightType, a, b, 4 * math.floatEpsAt(RecipeWeightType, @min(a, b)));
            } else {
                return true;
            }
        }

        pub fn resolve_recipes_by_weight(user_provided_entities: []const Target, recipes: []const RecipeList) AllSolutions {
            return resolve_recipes_internal(user_provided_entities, recipes, true);
        }
        pub fn resolve_recipes_by_order(user_provided_entities: []const Target, recipes: []const RecipeList) AllSolutions {
            return resolve_recipes_internal(user_provided_entities, recipes, false);
        }

        fn resolve_recipes_internal(user_provided_entities: []const Target, provided_recipes: []const RecipeList, comptime USE_WEIGHT_IF_AVAILABLE: bool) AllSolutions {
            const USE_WEIGHT = comptime HAS_WEIGHT and USE_WEIGHT_IF_AVAILABLE;
            var available_bits: BitFlagInt = 0;
            var resolutions: AllSolutions = @splat(RecipeSolution.unavailable());
            var recipe_lists_found: BitFlagInt = 0;
            var best_recipe_weights: [NUM_BITS]RecipeWeightType = @splat(MAX_RECIPE_WEIGHT);
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
                                var total_recipe_weight: RecipeWeightType = ZERO_RECIPE_WEIGHT;
                                if (comptime USE_WEIGHT) {
                                    for (recipe.dependancies) |dep| {
                                        const dep_bit_idx: Log2BitFlagInt = @intCast(@intFromEnum(dep.target));
                                        const current_dep_weight = best_recipe_weights[dep_bit_idx];
                                        // TODO provide some more complex way to calculate weight? User provided weight function on a per-recipe basis?
                                        total_recipe_weight += dep.weight_multiplier * current_dep_weight;
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
    const N = 32;
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
    const Engine = RecipeInferenceEngine(Op, Tag, .{
        .tags_equal = PROTO.tag_equal,
        .weight_type = f32,
    });
    const RecipeList = Engine.RecipeList;
    const Target = Engine.Target;
    const recipes: []const RecipeList = &.{
        .recipe_list(.ADD, &.{
            .recipe("a - (-b)", &.{
                .depends_on_with_weight(.SUB, 1),
                .depends_on_with_weight(.NEG, 1),
            }),
            .recipe("a - (0 - b)", &.{
                .depends_on_with_weight(.SUB, 2),
            }),
        }),
        .recipe_list(.SUB, &.{
            .recipe("a + ((~b) + 1)", &.{
                .depends_on_with_weight(.ADD, 2),
                .depends_on_with_weight(.INV, 1),
            }),
            .recipe("a + (-b)", &.{
                .depends_on_with_weight(.ADD, 1),
                .depends_on_with_weight(.NEG, 1),
            }),
        }),
        .recipe_list(.MUL, &.{
            .recipe("bit_shifts and add", &.{
                .depends_on_with_weight(.ADD, N / 2),
                .depends_on_with_weight(.SHR, N / 2),
                .depends_on_with_weight(.SHL, N / 2),
            }),
            .recipe("a + a + a + a...", &.{
                .depends_on_with_weight(.ADD, N * N),
            }),
        }),
        .recipe_list(.DIV, &.{
            .recipe("bit_shifts and sub", &.{
                .depends_on_with_weight(.SUB, N),
                .depends_on_with_weight(.SHR, N / 2),
                .depends_on_with_weight(.SHL, N / 2),
            }),
            .recipe("a - a - a - a...", &.{
                .depends_on_with_weight(.SUB, N + (N * CMP_WEIGHT)),
            }),
        }),
        .recipe_list(.NEG, &.{
            .recipe("0 - a", &.{
                .depends_on_with_weight(.SUB, 1),
            }),
        }),
        .recipe_list(.MOD, &.{
            .recipe("a - (a / b) * b", &.{
                .depends_on_with_weight(.SUB, 1),
                .depends_on_with_weight(.DIV, 1),
                .depends_on_with_weight(.MUL, 1),
            }),
            .recipe("(a - (a / b)) + (a - (a / b)) + ...", &.{
                .depends_on_with_weight(.SUB, 1),
                .depends_on_with_weight(.DIV, 1),
                .depends_on_with_weight(.ADD, N),
            }),
            .recipe("a - a - a - a...", &.{
                .depends_on_with_weight(.SUB, N + (N * CMP_WEIGHT)),
            }),
        }),
        .recipe_list(.SHL, &.{
            .recipe("a * pow(2, b)", &.{
                .depends_on_with_weight(.MUL, 1),
                .depends_on_with_weight(.POW, 1),
            }),
            .recipe("a * (2 * 2 * 2 * 2 * ...)", &.{
                .depends_on_with_weight(.MUL, 1 + (N)),
            }),
        }),
        .recipe_list(.SHR, &.{
            .recipe("a / pow(2, b)", &.{
                .depends_on_with_weight(.DIV, 1),
                .depends_on_with_weight(.POW, 1),
            }),
            .recipe("a / (2 / 2 / 2 / 2 / ...)", &.{
                .depends_on_with_weight(.DIV, 1 + (N)),
            }),
        }),
        .recipe_list(.POW, &.{
            .recipe("binary exponentiation by squaring", &.{
                .depends_on_with_weight(.MUL, N + (N / 2)),
                .depends_on_with_weight(.SHR, N),
            }),
            .recipe("a * a * a * a...", &.{
                .depends_on_with_weight(.MUL, N),
            }),
            .recipe_with_special_factors("magic ASIC power", 0, 0.5, &.{}),
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
    var results = Engine.resolve_recipes_by_weight(UNDER_PROVIDED, recipes);
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
    results = Engine.resolve_recipes_by_weight(MIN_PROVIDED_ONE_HEAVY, recipes);
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
