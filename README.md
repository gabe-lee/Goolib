# Goolib
## "If you wish to make an apple pie from scratch, you must first invent the universe." -Carl Sagan

### Library Status: Unstable
##### Minimum Zig version: 0.17.0
##### Library version: 0.8.0
This library is usable, but it has MANY older modules that are deprecated or do not meet current standards of testing and API,
and the API is changing frequently.

## Table of Contents
* [The purpose of this library](#the-purpose-of-this-library)
* [Contribution](#contribution)
* [AI Disclosure](#ai-disclosure)

## The purpose of this library
This Zig library was made with one primary goal in mind: I wanted a single, unified Zig library that simplified creating applications.
There are countless very good zig libraries out there and there is basically no use case that is not covered by some combination of them.

However, finding a way to vendor in all those separate libraries and get them to mesh together well is a very non-trivial task. Developer
friction is a very real factor that affects what software actually gets made and what gets left on the cutting room floor. For myself especially, I constantly found myself dismayed by how irritating it was to try and find a collection of packages that would successfuly work together to achieve what I wanted. Thus, I did the even more difficult task, making my own core codebase that could fulfill any use case I needed.

My goals for the library are:
* __Have as few external dependencies as possible__, and only for things I just can't make myself. For example, I vendor in SDL3 for cross-platform graphics, audio, and user input events, because that is an extremely complicated undertaking.
* __External dependencies should have the least restrictive licenses possible__, or at the very least offer a less-restrictive version by default and an opt-in less permisive module. For example, instead of vendoring in 'FreeType', which has a free but viral license that requires all downstream consumers to disclaim their use of FreeType in their project. Instead I provide a native zig adaptation of 'stb_truetype' for reading .ttf files, which is much less full-featured but has an MIT license. I may offer 'FreeType/Harfbuzz' as an opt-in module in the future via a comptime option.
* __Prefer dependency injection via generics over dynamic-dispatch interfaces__. Almost all of the basic data stucture types provided by this library take comptime generics for fine tuning and for providing external dependencies to the type. The major benefit here is that the compiler has better knowledge of exactly what code is being called, and ha more opportunities for inlining functions and other optimizations. Note that _dynamic-dispatch interfaces can ALSO fullfil the static-dispatch injections if the user still wants to use them_.
* __Provide the user many comptime options to tweak data structure behavior and memory footprint, while providing simple sane defaults__. One of my biggest personal gripes is that data structures provided by other libraries and the standard library are often 'you get what you get, and you just have to work around it'. It often led me to make one-off versions of certain data strucures for specific use-cases, but inevitably those one-off versions did not have the edge-case testing and full-featuredness of the standard counterparts. I want to give users more agency in how the 'stanard' data strucutres they use function internally, as long as it makes sense to do so. If a user chooses setting that perform poorly for their use case, that is on the user.
* __Use a lot of assert statements, and give the user a control over whether a data structure returns errors or panics__. This is a goal of the library I have not quite followed through on. I have a lot of assert statements, and I think assert statements are a keystone of robust code. But I have flip-flopped on what degree of freedom the user should have over whether the data structure panics or returns an error code. Right now almost all data structures panic when they encounter invalid state, but that requires users to handle invalid state _before_ they call a function that can panic due to bad input or internal state, if it is expected that invalid state may be encountered.

## Library Overview
#### Math and Geometry
* [Math](./src/Math.zig)
* [Vec2](./src/Vec2.zig)
* [Vec3](./src/Vec3.zig)
* [Vec4](./src/Vec4.zig)
* [AABB2](./src/AABB2.zig)
* [Rect2](./src/Rect2.zig)
* [Matrix](./src/Matrix.zig)
* [Bezier](./src/Bezier.zig)
#### Shapes and Rasterization
* [Shape](./src/Shape.zig)
  * [Shape Rasterizer](./src/Shape_ACSA_Rasterizer.zig)
#### Text
* [TrueType](./src/TrueType.zig)
  * [GlyphManager](./src/TrueType_TextManager.zig)
#### Allocator/Pointer alternatives
* [Allocator](./src/Allocator.zig)
  * AllocatorSource - A definition of a source of memory allocation. Accepts the zig Allocator interface as well as compliant concrete types
  * AllocatorAdapter - An adapter around an AllocatorSource that provides a unified public API
  * [BucketSlab Allocator](./src/Allocator_BucketSlabs.zig)
  * [QuickBucket Allocator](./src/Allocator_QuickBucket.zig)
  * [AllocatorInfallible interface](./src/Allocator_Infallible.zig)
  * [Allocator dummy interfaces](./src/Allocator_Dummy.zig)
* [Pointer](./src/Pointer.zig) - A wrapper type that can wrap either native pointers, or arbitrary integer handles that can be resolved to memory adresses, depending on its PointerSource 
  * PointerSource - A definition of a source of memory pointers. Can be defined as native pointers, or a set of static resolver functions that resolve integer handles to memory addresses
#### Data Structures
* [ListSlice](./src/ListSlice.zig) - A more flexible, tunable, full-featured replacement for ArrayList and native slices
* Hash Maps
  * [SwissHashMap](./src/HashMap_SwissTable.zig) - A tunable implementation of a Swiss-Table hash map
* [DataGrid](./src/DataGrid.zig) - A 2D grid view of a memory region
* Pools - Single-type object pools
  * [MappedKeyPool](./src/Pool_MappedKeyPool.zig) - A pool where you are given a 'Key' that provides stable access to the object memory, even if the memory is reallocated
    * Global version implemented, instanced version not yet implemented
  * [BitTrackedBlocksPool](./src/Pool_BitTrackedBlocksPool.zig) - A pool where backing memory is allocated in stable blocks to keep pointers stable
    * Instanced and Global Versions
* [Observer](./src/Observer.zig) - A generic implementation of the Observer-pattern
#### UI/Generic Rectangle Layout
* [Layout](./src/Layout.zig) - An immediate-mode rectangle heirarchy layout system. Does not handle events or drawing, but provides functions to traverse and act on the resulting heirarchy.
#### Graphics/Audio/Input
* [SDL3](./src/SDL3.zig) - An SDL3 wrapper with zig-ified language bindings (in the flavor of this library)
  * [GraphicsControler](./src/SDL3_GraphicsController.zig) - A complete SDL3 GPU API controller that build on the SDL3 wrapper for simplified user experience
    * [ShaderUtils](./src/SDL3_GraphicsController_ShaderUtils.zig) - Utility functions for GPU-CPU type contracts, struct field layout compliance, and automatic HLSL shader stub generation.
#### Physics/Collision
* [Box2D](./src/Physics_Box2D.zig) - Zig bindings around Box2D
* [SweepPruneList](./src/SweepPruneList.zig) - A generic 2d sweep-and-prune list
#### FileFormats
* [Bitmap](./src/FileFormat_Bitmap.zig) - (Limited) Support for the bitmap file format
  * Write-only support, read support not yet implemented
#### Threading/Thread-Safety
* [Locks](./src/Threading_Locks.zig) - A collection of 
#### Other Utilities
* [Utils](./src/Utils.zig) - Various utility functions
* [Types](./src/Types.zig) - Type reflection, type manipulation utilities
* [Time](./src/Time.zig) - Utilities for time 
* [Testing](./src/Testing.zig) - Testing utility functions
* [Fuzz](./src/Fuzz.zig) - Fuzzing utilities for manual/semi-automatic fuzzing
* [ANSI](./src/ANSI.zig) - ANSI console code utilities
* [Assert](./src/Assert.zig) - Assert statement utilities
* [Cast](./src/Cast.zig) - Utilities for type casting
* [Rand](./src/Rand.zig) - Utilities for random values

## Licenses and Attibutions
#### Goolib (this library): [Zlib license](./LICENSE.txt)
The original code in _this_ library (excluding code in the /vendor directory) is covered by the Zlib license. This license is mostly compatable with the MIT license, with a few differences in attribution:
* Software is provided 'as-is' with no warranty, and there is no author liability for damages arising from using this software
* You can modify the code freely, use it in commercial products, and redistribute it, in whole or in part.
* Compiled software does not need the Goolib license attatched, but source code does.
* Re-distributed source code must include the original ZLib license, and if the source code was altered it must plainly state what parts/files were altered from the original.
#### SDL3: [Zlib license](https://github.com/libsdl-org/SDL/blob/main/LICENSE.txt)
* Note that although SDL3 is licensed under Zlib, it includes individual files and snippets from many other sources within it, with their own permissive licenses. The Castholm SDL3-for-Zig adapter library I use is much more complete with its license documentation (see below)
#### SDL3: Castholm's SDL3-for-Zig adapter library: [Many](./vendor/github.com/castholm/SDL/LICENSE.txt)
* SDL3 is provided via the castholm zig library for simplicity, which provides the licenses for all included SDL3 sources, as well as for the needed headers for cross-compiling on certain platforms. For maximum compliance, this should be considered the complete license list if using SDL3.
#### Box2D: [MIT License](./vendor/github.com/erincatto/box2d/LICENSE)
#### Other Attributions:
* The code in [src/TrueType.zig](./src/TrueType.zig) is heavily based on/dervied from the [Andrew Kelley TrueType](https://codeberg.org/andrewrk/TrueType) repo under the [MIT License](https://codeberg.org/andrewrk/TrueType/src/commit/4fea1e7c0f9d4d79348d0302c7628f485301b6ac/LICENSE), which _itself_ was heavily derived from the [stb_truetype](https://github.com/nothings/stb/blob/master/stb_truetype.h) header file, available under the [MIT or Unlicense](https://github.com/nothings/stb/blob/master/LICENSE).
* The code in [src/MSDF_Generator_Bezier.zig](./src/MSDF_Generator_Bezier.zig) is based on the original work by Victor Chlumsky in his [MSDFgen](https://github.com/chlumsky/msdfgen) repo. The original version is provided under the [MIT License](https://github.com/Chlumsky/msdfgen/blob/master/LICENSE.txt), but the code in this library was completely converted into Zig by hand.

## Contribution
There are no expectations for endorsement, monetary compensation, or
contribution to the source code by users of this software.

However, if you find value in this library, any and all support
to myself and/or the few external libraries this library depends on
would be greatly appreciated.

## AI Disclosure
This library did/does use LLM AI technology to ASSIST in development, but no part of this code
is purely AI coded with no human oversight. 

I have not ever told an AI to reverse-engineer code from another non-open-source library into this library. Whether the
AI has drawn on non-open-source training data when formulating its results is impossible for me to know,
but I always either write an initial version myself, or ask it to implement a well-known and widespread algorithm or data structure.

The typical use for AI is as follows:
* I write an initial version of a module/struct/functionality I want.
* I ask the AI to look at my code for logical errors and fix them with annotations in the comments where it fixed code (unless it is something simple like a type error). The AI works in an isolated worktree that is cloned from the repo
* I review the code diffs, read the comments it left, and either accept them or make some final tweaks for personal preference.
* I ask the AI to write test cases for the (fixed) code. __Unit tests are the largest AI contribution to this library by far. I just don't have time to write/re-write unit tests whenever I make breaking changes to a part of the library__
* I __manually__ copy the altered files over into the main repo and make the commits