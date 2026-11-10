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

const std = @import("std");
const testing = std.testing;

const Root = @import("./_root.zig");
const ObserverModule = Root.Observer;
const Observer = ObserverModule.Observer;
const Observable = ObserverModule.Observable;
const NotifyMode = ObserverModule.NotifyMode;
const ObservingAction = ObserverModule.ObservingAction;
const ObservingActionDef = ObserverModule.ObservingActionDef;
const ObservingActionSource = ObserverModule.ObservingActionSource;
const AllocSource = Root.Allocator.AllocSource;

const Notification = enum {
    CHANGED,
    RESET,
};

const ObserverIface = Observer(Notification);
const ALLOC = AllocSource.passed_allocator_interface();
const TestObservable = Observable(u32, Notification, ALLOC);

const ObserveState = struct {
    count: u32 = 0,
    last: ?Notification = null,

    fn on_notify(opaque_ptr: *anyopaque, notif: Notification) void {
        const self: *ObserveState = @ptrCast(@alignCast(opaque_ptr));
        self.count += 1;
        self.last = notif;
    }

    fn observer(self: *ObserveState) ObserverIface {
        return .{
            .observer_opaque = @ptrCast(@alignCast(self)),
            .notify_impl = on_notify,
        };
    }
};

fn null_observer() ObserverIface {
    return .{
        .observer_opaque = null,
        .notify_impl = ObserveState.on_notify,
    };
}

test "Observer -> exists checks and notify_if_exists do not call a missing observer" {
    var state = ObserveState{};
    var observer = state.observer();
    const missing = null_observer();

    try testing.expect(observer.exists());
    try testing.expect(!observer.doesnt_exist());
    try testing.expect(!missing.exists());
    try testing.expect(missing.doesnt_exist());

    observer.notify_if_exists(.CHANGED);
    try testing.expectEqual(@as(u32, 1), state.count);
    try testing.expectEqual(Notification.CHANGED, state.last.?);

    missing.notify_if_exists(.RESET);
    try testing.expectEqual(@as(u32, 1), state.count);

    try testing.expect(observer.notify_if_exists_and_report_exists(.RESET));
    try testing.expectEqual(@as(u32, 2), state.count);
    try testing.expectEqual(Notification.RESET, state.last.?);

    try testing.expect(!missing.notify_if_exists_and_report_exists(.RESET));
    try testing.expectEqual(@as(u32, 2), state.count);
}

test "Observer -> notify and notify_with_mode notify the wrapped object" {
    var state = ObserveState{};
    var observer = state.observer();

    observer.notify(.CHANGED);
    try testing.expectEqual(@as(u32, 1), state.count);
    try testing.expectEqual(Notification.CHANGED, state.last.?);

    observer.notify_with_mode(.RESET, .DONT_NOTIFY);
    try testing.expectEqual(@as(u32, 1), state.count);

    observer.notify_with_mode(.RESET, .ALWAYS_NOTIFY);
    try testing.expectEqual(@as(u32, 2), state.count);
    try testing.expectEqual(Notification.RESET, state.last.?);

    observer.notify_with_mode(.CHANGED, .NOTIFY_IF_EXISTS);
    try testing.expectEqual(@as(u32, 3), state.count);
    try testing.expectEqual(Notification.CHANGED, state.last.?);

    observer.notify_with_ct_mode(.RESET, .DONT_NOTIFY);
    try testing.expectEqual(@as(u32, 3), state.count);

    observer.notify_with_ct_mode(.RESET, .ALWAYS_NOTIFY);
    try testing.expectEqual(@as(u32, 4), state.count);
    try testing.expectEqual(Notification.RESET, state.last.?);
}

test "Observable -> init/new variants and duplicate observer registration" {
    var initialized: TestObservable = undefined;
    initialized.init(11, {});
    defer initialized.observers.free(testing.allocator);
    try testing.expectEqual(@as(u32, 11), initialized.val);
    try testing.expectEqual(@as(u32, 0), initialized.observers.get_len());

    const allocated = TestObservable.new_with_cap(22, 4, testing.allocator);
    var allocated_mut = allocated;
    defer allocated_mut.observers.free(testing.allocator);
    try testing.expectEqual(@as(u32, 22), allocated_mut.val);
    try testing.expectEqual(@as(u32, 0), allocated_mut.observers.get_len());

    var state_a = ObserveState{};
    var state_b = ObserveState{};
    const observer_a = state_a.observer();
    const observer_b = state_b.observer();

    initialized.add_observer(observer_a, testing.allocator);
    initialized.add_observer(observer_a, testing.allocator);
    try testing.expectEqual(@as(u32, 1), initialized.observers.get_len());

    initialized.add_observer(observer_b, testing.allocator);
    try testing.expectEqual(@as(u32, 2), initialized.observers.get_len());

    initialized.notify_all_observers(.CHANGED);
    try testing.expectEqual(@as(u32, 1), state_a.count);
    try testing.expectEqual(@as(u32, 1), state_b.count);

    initialized.remove_observer(observer_a);
    try testing.expectEqual(@as(u32, 1), initialized.observers.get_len());

    initialized.notify_all_observers(.RESET);
    try testing.expectEqual(@as(u32, 1), state_a.count);
    try testing.expectEqual(@as(u32, 2), state_b.count);
    try testing.expectEqual(Notification.RESET, state_b.last.?);

    // Removing an observer that is no longer registered is a no-op.
    initialized.remove_observer(observer_a);
    try testing.expectEqual(@as(u32, 1), initialized.observers.get_len());
}

test "Observable -> notify_all_observers_that_exist skips missing observers" {
    var observable = TestObservable.new(0, {});
    defer observable.observers.free(testing.allocator);

    var state = ObserveState{};
    observable.add_observer(null_observer(), testing.allocator);
    observable.add_observer(state.observer(), testing.allocator);
    try testing.expectEqual(@as(u32, 2), observable.observers.get_len());

    observable.notify_all_observers_that_exist(.CHANGED);
    try testing.expectEqual(@as(u32, 1), state.count);
    try testing.expectEqual(Notification.CHANGED, state.last.?);
}

test "Observable -> report_if_all_exist still notifies every existing observer" {
    var observable = TestObservable.new(0, {});
    defer observable.observers.free(testing.allocator);

    var first = ObserveState{};
    var second = ObserveState{};

    // The missing observer is deliberately first. The implementation must not
    // short-circuit after discovering that not every observer exists.
    observable.add_observer(null_observer(), testing.allocator);
    observable.add_observer(first.observer(), testing.allocator);
    observable.add_observer(second.observer(), testing.allocator);

    try testing.expect(!observable.notify_all_observers_that_exist_report_if_all_exist(.CHANGED));
    try testing.expectEqual(@as(u32, 1), first.count);
    try testing.expectEqual(@as(u32, 1), second.count);

    var all_exist = TestObservable.new(0, {});
    defer all_exist.observers.free(testing.allocator);
    all_exist.add_observer(first.observer(), testing.allocator);
    all_exist.add_observer(second.observer(), testing.allocator);

    try testing.expect(all_exist.notify_all_observers_that_exist_report_if_all_exist(.RESET));
    try testing.expectEqual(@as(u32, 2), first.count);
    try testing.expectEqual(@as(u32, 2), second.count);
}

fn action_body(_: *TestObservable, out: *u32, _: Notification) void {
    out.* += 1;
}

fn runtime_action_body(_: *TestObservable, out: *u32, _: Notification) void {
    out.* += 1;
}

const SingleActionDef = ObservingActionDef{
    .INPUTS = *TestObservable,
    .OUTPUTS = *u32,
    .NOTIFICATION = Notification,
    .ALLOC_SOURCE_FOR_OBSERVABLES = ALLOC,
};

test "ObservingAction -> comptime function body registers, notifies, and unregisters" {
    const Source = ObservingActionSource(SingleActionDef);
    const Action = ObservingAction(SingleActionDef, Source.comptime_func_body(action_body));

    var observable = TestObservable.new(0, {});
    defer observable.observers.free(testing.allocator);

    var out: u32 = 0;
    var action: Action = .{};

    action.init(&observable, &out, {}, testing.allocator);
    try testing.expectEqual(@as(u32, 1), observable.observers.get_len());

    observable.notify_all_observers(.CHANGED);
    try testing.expectEqual(@as(u32, 1), out);

    action.notify_action(.RESET);
    try testing.expectEqual(@as(u32, 2), out);

    action.uninit();
    try testing.expectEqual(@as(u32, 0), observable.observers.get_len());

    observable.notify_all_observers(.CHANGED);
    try testing.expectEqual(@as(u32, 2), out);
}

test "ObservingAction -> runtime function pointer source" {
    const Source = ObservingActionSource(SingleActionDef);
    const Action = ObservingAction(SingleActionDef, Source.runtime_func());

    var observable = TestObservable.new(0, {});
    defer observable.observers.free(testing.allocator);

    var out: u32 = 0;
    var action: Action = .{};

    action.init(&observable, &out, &runtime_action_body, testing.allocator);
    try testing.expectEqual(@as(u32, 1), observable.observers.get_len());

    observable.notify_all_observers(.CHANGED);
    try testing.expectEqual(@as(u32, 1), out);

    action.uninit();
    try testing.expectEqual(@as(u32, 0), observable.observers.get_len());
}

test "ObservingAction -> comptime function pointer source" {
    const Source = ObservingActionSource(SingleActionDef);
    const Action = ObservingAction(SingleActionDef, Source.comptime_func_ptr(&action_body));

    var observable = TestObservable.new(0, {});
    defer observable.observers.free(testing.allocator);

    var out: u32 = 0;
    var action: Action = .{};

    action.init(&observable, &out, {}, testing.allocator);
    try testing.expectEqual(@as(u32, 1), observable.observers.get_len());

    observable.notify_all_observers(.RESET);
    try testing.expectEqual(@as(u32, 1), out);

    action.uninit();
    try testing.expectEqual(@as(u32, 0), observable.observers.get_len());
}

const CACHED_ALLOC = AllocSource.cached_allocator_interface();
const CachedObservable = Observable(u8, Notification, CACHED_ALLOC);

fn cached_action_body(_: *CachedObservable, out: *u32, _: Notification) void {
    out.* += 1;
}

test "ObservingAction -> cached allocator source" {
    const DEF = ObservingActionDef{
        .INPUTS = *CachedObservable,
        .OUTPUTS = *u32,
        .NOTIFICATION = Notification,
        .ALLOC_SOURCE_FOR_OBSERVABLES = CACHED_ALLOC,
    };
    const Source = ObservingActionSource(DEF);
    const Action = ObservingAction(DEF, Source.comptime_func_body(cached_action_body));

    var observable = CachedObservable.new(0, testing.allocator);
    defer observable.observers.free({});

    var out: u32 = 0;
    var action: Action = .{};
    action.init(&observable, &out, {}, {});
    try testing.expectEqual(@as(u32, 1), observable.observers.get_len());

    observable.notify_all_observers(.CHANGED);
    try testing.expectEqual(@as(u32, 1), out);

    action.uninit();
    try testing.expectEqual(@as(u32, 0), observable.observers.get_len());
}

fn MakeContainerAction(comptime INPUTS: type, comptime ALLOW_NON_OBSERVABLE_INPUTS: bool) type {
    const DEF = ObservingActionDef{
        .INPUTS = INPUTS,
        .OUTPUTS = *u32,
        .ALLOW_NON_OBSERVABLE_INPUTS = ALLOW_NON_OBSERVABLE_INPUTS,
        .NOTIFICATION = Notification,
        .ALLOC_SOURCE_FOR_OBSERVABLES = ALLOC,
    };
    const Body = struct {
        fn body(_: INPUTS, out: *u32, _: Notification) void {
            out.* += 1;
        }
    };
    const Source = ObservingActionSource(DEF);
    return ObservingAction(DEF, Source.comptime_func_body(Body.body));
}

fn exercise_container_input(comptime INPUTS: type, input: INPUTS, expected_observables: []const *TestObservable) !void {
    const Action = MakeContainerAction(INPUTS, false);

    var out: u32 = 0;
    var action: Action = .{};
    action.init(input, &out, {}, testing.allocator);

    for (expected_observables) |observable| {
        try testing.expectEqual(@as(u32, 1), observable.observers.get_len());
    }

    for (expected_observables) |observable| {
        observable.notify_all_observers(.CHANGED);
    }
    try testing.expectEqual(@as(u32, @intCast(expected_observables.len)), out);

    action.uninit();
    for (expected_observables) |observable| {
        try testing.expectEqual(@as(u32, 0), observable.observers.get_len());
    }
}

test "ObservingAction -> pointer to array of observables inputs" {
    var arr = [2]TestObservable{ TestObservable.new(0, {}), TestObservable.new(1, {}) };
    defer for (&arr) |*observable| observable.observers.free(testing.allocator);

    const expected = [_]*TestObservable{ &arr[0], &arr[1] };
    try exercise_container_input(*[2]TestObservable, &arr, &expected);
}

test "ObservingAction -> slice of observables inputs" {
    var arr = [2]TestObservable{ TestObservable.new(0, {}), TestObservable.new(1, {}) };
    defer for (&arr) |*observable| observable.observers.free(testing.allocator);

    const expected = [_]*TestObservable{ &arr[0], &arr[1] };
    try exercise_container_input([]TestObservable, arr[0..], &expected);
}

test "ObservingAction -> pointer to array of observable pointers inputs" {
    var a = TestObservable.new(0, {});
    var b = TestObservable.new(1, {});
    defer a.observers.free(testing.allocator);
    defer b.observers.free(testing.allocator);

    var arr = [2]*TestObservable{ &a, &b };
    const expected = [_]*TestObservable{ &a, &b };
    try exercise_container_input(*[2]*TestObservable, &arr, &expected);
}

test "ObservingAction -> array of observable pointers inputs" {
    var a = TestObservable.new(0, {});
    var b = TestObservable.new(1, {});
    defer a.observers.free(testing.allocator);
    defer b.observers.free(testing.allocator);

    const arr = [2]*TestObservable{ &a, &b };
    const expected = [_]*TestObservable{ &a, &b };
    try exercise_container_input([2]*TestObservable, arr, &expected);
}

test "ObservingAction -> slice of observable pointers inputs" {
    var a = TestObservable.new(0, {});
    var b = TestObservable.new(1, {});
    defer a.observers.free(testing.allocator);
    defer b.observers.free(testing.allocator);

    var arr = [2]*TestObservable{ &a, &b };
    const expected = [_]*TestObservable{ &a, &b };
    try exercise_container_input([]*TestObservable, arr[0..], &expected);
}

test "ObservingAction -> struct of observable fields inputs" {
    var a = TestObservable.new(0, {});
    var b = TestObservable.new(1, {});
    defer a.observers.free(testing.allocator);
    defer b.observers.free(testing.allocator);

    const Inputs = struct {
        first: *TestObservable,
        second: *TestObservable,
    };
    const input = Inputs{ .first = &a, .second = &b };
    const expected = [_]*TestObservable{ &a, &b };
    try exercise_container_input(Inputs, input, &expected);
}

test "ObservingAction -> non-observable inputs are allowed when requested" {
    const Inputs = struct {
        observable: *TestObservable,
        ignored: u32,
    };
    const Action = MakeContainerAction(Inputs, true);

    var observable = TestObservable.new(0, {});
    defer observable.observers.free(testing.allocator);

    const input = Inputs{ .observable = &observable, .ignored = 123 };

    var out: u32 = 0;
    var action: Action = .{};
    action.init(input, &out, {}, testing.allocator);
    try testing.expectEqual(@as(u32, 1), observable.observers.get_len());

    observable.notify_all_observers(.CHANGED);
    try testing.expectEqual(@as(u32, 1), out);

    action.uninit();
    try testing.expectEqual(@as(u32, 0), observable.observers.get_len());
}
