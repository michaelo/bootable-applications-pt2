const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");

const Vector2 = struct {
    x: f32,
    y: f32,
};

const State = struct {
    // lowres: utils.Bitmap,
    backbuffer: utils.Bitmap,
    screen: utils.Bitmap,
    showDebugConsole: bool = false,
    slideIdx: usize = 0,
    // displaySize: Vector2 = .{ 0, 0 },
    pointerPos: Vector2 = .{ .x = 0, .y = 0 },
    // rendermode: scale up | backbuffer | raw (assumes screen is directly manipulated, do nothing)
};

const EventType = enum {
    key_down,
    key_up,
    pointer_down,
    pointer_up,
    pointer_move,
};

const Event = union(EventType) {
    key_down: void,
    key_up: void,
    pointer_down: void,
    pointer_up: void,
    pointer_move: void,
};

// TODO: Create a convenient "debug console" which can be shown/hidden with a key.
// fn console(text: []const u8) void {
//     // render a textbox with whatever contents in the text buffer, makes sure to clear anything previously rendered
// }

fn slide1(state: *State, t: f32, td: f32) void {
    _ = td;
    drawing.bitmapFill(state.backbuffer, utils.Colors.black);
    const size: u16 = 16 + @as(u16, @intFromFloat(16 * @abs(@sin(t))));

    _ = utils.renderStringOutlined(state.backbuffer, 100, 100, utils.Colors.transparent, utils.Colors.black, utils.Colors.red, 2, size, "Slide 1");
}

// TODO: Have slides be able to return a state to e.g. auto-transition
fn animateBoxEdge(state: *State, t: f32, td: f32) void {
    // _ = td;
    // drawing.bitmapFill(state.backbuffer, utils.Colors.black);
    // const size: u16 = 16 + @as(u16, @intFromFloat(16 * @abs(@sin(t))));

    // _ = utils.renderStringOutlined(state.backbuffer, 100, 100, utils.Colors.transparent, utils.Colors.black, utils.Colors.red, 2, size, "Slide 1");
}

/// provide main loop with main event handling (mouse, keyboard)
/// pass detected events in normalized struct to each slide, which then can choose to respect them or not
/// solve as game loop, provide delta-time and total time
fn presentation() void {}

/// Will check any relevant events and provide a normalized, easily actionable definition
/// TODO: return both the current event as well as composite state?
fn checkEvents(events: []const uefi.Event) void {
    const result = uefi.system_table.boot_services.?.waitForEvent(events) catch unreachable;
    // const event = result.@"0";
    const event_idx = result.@"1";
    switch (event_idx) {
        0 => {
            // animation frame timer
        },
        1 => {
            // key
            // const key = uefi.protocol.SimpleTextInputEx.registerKeyNotify(self: *SimpleTextInputEx, key_data: *const Key, notify: *const fn (*const Key) Status) .readKeyStroke() catch unreachable;
            const key = uefi.system_table.con_in.?.readKeyStroke() catch unreachable;
            _ = key;
        },
        else => {},
    }
}

// fn getFirstOfProtocolOptimistic(comptime protocol: type) ?*protocol {
//     return uefi.system_table.boot_services.?.locateProtocol(protocol, null) catch null orelse null;
// }

pub fn main() uefi.Status {
    const boot_services = uefi.system_table.boot_services orelse unreachable;
    const gfx_out = boot_services.locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;

    // TODO: initiate with gfx selector

    // Setup events: we want a constant tick, but allow key/pointer events to
    const loopEvent = boot_services.createEvent(.{ .timer = true }, .{ .function = null }) catch unreachable;
    boot_services.setTimer(loopEvent, .periodic, 10000000 / 30) catch unreachable;

    const screen = drawing.bitmapFromScreenbuffer(gfx_out);

    var state: State = .{
        .backbuffer = drawing.bitmapCreate(uefi.pool_allocator, screen.width, screen.height) catch unreachable,
        .screen = screen,
        .pointerPos = .{ .x = 100, .y = 100 },
        .showDebugConsole = false,
        .slideIdx = 0,
    };

    drawing.bitmapFill(state.backbuffer, utils.Colors.black);

    const events = [_]uefi.Event{
        loopEvent,
        uefi.system_table.con_in.?.wait_for_key,
    };

    var t: f32 = 0;

    // "Game loop"
    // TODO: include time delta and time total
    while (true) {
        // Event handling
        // Take a normalized event and pay it forward
        checkEvents(events[0..]);
        const td = 1.0 / 30.0; // *hackety-hack*
        t += td;

        // Update state
        slide1(&state, t, td);

        // Render to screen
        drawing.blitToScreen(gfx_out, state.backbuffer, 0, 0);
    }
    utils.hangForKey(13);

    return .success;
}
