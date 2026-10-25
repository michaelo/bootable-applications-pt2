const END_WITH_PRESENTATION_SLIDE = false;
const std = @import("std");
const Io = std.Io;
const puredoom = @import("puredoom");
const uefi = std.os.uefi;
const file_io = @import("file_mock.zig");
const drawing = @import("drawing.zig");

var alloc = uefi.pool_allocator;
var con_out: ?*uefi.protocol.SimpleTextOutput = null;

fn formatToU16(buf8: []u8, buf16: []u16, comptime format: []const u8, vars: anytype) [:0]const u16 {
    const formatted = std.fmt.bufPrint(buf8, format, vars) catch "";
    _ = std.unicode.utf8ToUtf16Le(buf16, formatted) catch 0;
    buf16[formatted.len] = 0;
    return buf16[0..formatted.len :0];
}

pub fn debug(comptime format: []const u8, vars: anytype) void {
    var scrap: [128]u8 = undefined;
    var scrap16: [128]u16 = undefined;

    _ = con_out.?.outputString(formatToU16(&scrap, &scrap16, format, vars)) catch {};
}

fn my_getenv(name: [*c]const u8) callconv(.c) [*c]u8 {
    if (std.mem.orderZ(u8, name, "DOOMWADDIR") == .eq) {
        return @ptrCast(@constCast("."));
    }

    if (std.mem.orderZ(u8, name, "HOME") == .eq) {
        return @ptrCast(@constCast("."));
    }

    return @ptrCast(@constCast("."));
}

fn my_malloc(size: c_int) callconv(.c) ?*anyopaque {
    const value = alloc.alloc(u8, @intCast(size)) catch {
        return null;
    };
    return @ptrCast(value.ptr);
}

fn my_free(ptr: ?*anyopaque) callconv(.c) void {
    _ = ptr;
    // TODO: Implement proper free
}

fn my_print(val: [*c]const u8) callconv(.c) void {
    debug("{s}", .{val});
}

var time: f32 = 0;
fn my_time(sec: [*c]c_int, usec: [*c]c_int) callconv(.c) void {
    // TODO: Integrate with time protocol if found, otherwise provide fallback?
    // var time = uefi.system_table.boot_services.?
    //     .locateProtocol(uefi.protocol, null) catch null orelse unreachable;
    const secs = @floor(time);
    sec.* = @intFromFloat(secs);
    usec.* = @intFromFloat((time - secs) * 1_000_000);
}

const InputParams = struct {
    current_state: bool = false,
    last_press: f32 = 0,
    active_interval: f32 = 0.25,
    doom_key: c_int = 0,

    // fn active(this: @This(), t: f32) bool {
    //     return this.last_press + this.active_interval > t;
    // }
    fn sync(this: *@This(), t: f32) void {
        if (!this.current_state and this.last_press + this.active_interval >= t) {
            puredoom.doom_key_down(this.doom_key);
            this.current_state = true;
        } else if (this.current_state and this.last_press + this.active_interval < t) {
            puredoom.doom_key_up(this.doom_key);
            this.current_state = false;
        }
    }
    fn poke(this: *@This(), t: f32) void {
        this.last_press = t;
    }
};
// Alternative approach: have any key invalidate any others. Except perhaps fire.
const InputState = struct {
    // Register time of last press, then check against this for each iteration if it has "timed out"
    // TBD: allow different timeouts for different keys?
    up: InputParams = .{
        .active_interval = 0.001,
        .doom_key = puredoom.DOOM_KEY_UP_ARROW,
    },
    down: InputParams = .{
        .active_interval = 0.001,
        .doom_key = puredoom.DOOM_KEY_DOWN_ARROW,
    },
    rotate_left: InputParams = .{
        .active_interval = 0.4,
        .doom_key = puredoom.DOOM_KEY_LEFT_ARROW,
    },
    rotate_right: InputParams = .{
        .active_interval = 0.4,
        .doom_key = puredoom.DOOM_KEY_RIGHT_ARROW,
    },
    forward: InputParams = .{
        .active_interval = 0.4,
        .doom_key = puredoom.DOOM_KEY_W,
    },
    backward: InputParams = .{
        .active_interval = 0.4,
        .doom_key = puredoom.DOOM_KEY_S,
    },
    strafe_right: InputParams = .{
        .active_interval = 0.4,
        .doom_key = puredoom.DOOM_KEY_D,
    },
    strafe_left: InputParams = .{
        .active_interval = 0.4,
        .doom_key = puredoom.DOOM_KEY_A,
    },
    fire: InputParams = .{
        .active_interval = 0.3,
        .doom_key = puredoom.DOOM_KEY_F,
    },
    confirm: InputParams = .{
        .active_interval = 0.001,
        .doom_key = puredoom.DOOM_KEY_Y,
    },
    select: InputParams = .{
        .active_interval = 0.001,
        .doom_key = puredoom.DOOM_KEY_ENTER,
    },
    use: InputParams = .{
        .active_interval = 0.001,
        .doom_key = puredoom.DOOM_KEY_E,
    },
    esc: InputParams = .{
        .active_interval = 0.001,
        .doom_key = puredoom.DOOM_KEY_ESCAPE,
    },
};

fn syncState(state: *InputState, t: f32) void {
    state.up.sync(t);
    state.down.sync(t);
    state.rotate_left.sync(t);
    state.rotate_right.sync(t);
    state.strafe_left.sync(t);
    state.strafe_right.sync(t);
    state.forward.sync(t);
    state.backward.sync(t);
    state.select.sync(t);
    state.use.sync(t);
    state.fire.sync(t);
    state.esc.sync(t);
    state.confirm.sync(t);
}

var inputState: InputState = .{};

fn handleEvent() void {
    // TODO: implement "push bursts" - have a complete state of all buttons, registert time og push down, then have it "auto-lift" after given time interval
    const con_in = uefi.system_table.con_in.?;
    const stroke: ?uefi.protocol.SimpleTextInput.Key.Input = con_in.readKeyStroke() catch null;
    if (stroke) |s| {
        switch (s.scan_code) {
            // left
            4 => inputState.rotate_left.poke(time),
            // right
            3 => inputState.rotate_right.poke(time),
            // up
            1 => inputState.up.poke(time),
            // down
            2 => inputState.down.poke(time),
            else => {},
        }
        switch (s.unicode_char) {
            'q' => inputState.esc.poke(time),
            'w' => inputState.forward.poke(time),
            'a' => inputState.strafe_left.poke(time),
            's' => inputState.backward.poke(time),
            'd' => inputState.strafe_right.poke(time),
            'f' => inputState.fire.poke(time),
            'y' => inputState.confirm.poke(time),
            'z' => inputState.rotate_left.poke(time),
            'c' => inputState.rotate_right.poke(time),
            'e' => inputState.use.poke(time),
            ' ' => inputState.fire.poke(time),
            '\r' => inputState.select.poke(time),
            else => {},
        }
    }
    syncState(&inputState, time);
}

var game_is_running: bool = true;

fn my_exit(_: c_int) callconv(.c) void {
    game_is_running = false;
}

const BltPixel = uefi.protocol.GraphicsOutput.BltPixel;
// pub fn main() uefi.Status {
pub fn main() uefi.Status {
    const white: BltPixel = .{ .blue = 255, .green = 255, .red = 255, .reserved = 255 };
    con_out = uefi.system_table.con_out;
    var gfx_out = uefi.system_table.boot_services.?
        .locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;
    gfx_out.setMode(0) catch unreachable;
    gfx_out.blt(
        @as(?[*]BltPixel, @ptrCast(@constCast(&white))),
        uefi.protocol.GraphicsOutput.BltOperation.blt_video_fill,
        0,
        0,
        0,
        0,
        gfx_out.mode.info.horizontal_resolution,
        gfx_out.mode.info.vertical_resolution,
        gfx_out.mode.info.pixels_per_scan_line,
    ) catch {};

    // Default res: 320x200
    // puredoom.doom_set_resolution(320, 240);
    puredoom.doom_set_getenv(my_getenv);
    puredoom.doom_set_malloc(my_malloc, my_free);
    puredoom.doom_set_print(my_print);
    puredoom.doom_set_file_io(
        file_io.open,
        file_io.close,
        file_io.read,
        file_io.write,
        file_io.seek,
        file_io.tell,
        file_io.eof,
    );
    puredoom.doom_set_gettime(my_time);
    puredoom.doom_set_exit(my_exit);

    // Map to WASD
    puredoom.doom_set_default_int("key_up", puredoom.DOOM_KEY_W);
    puredoom.doom_set_default_int("key_down", puredoom.DOOM_KEY_S);
    puredoom.doom_set_default_int("key_strafeleft", puredoom.DOOM_KEY_A);
    puredoom.doom_set_default_int("key_straferight", puredoom.DOOM_KEY_D);
    puredoom.doom_set_default_int("key_left", puredoom.DOOM_KEY_LEFT_ARROW);
    puredoom.doom_set_default_int("key_right", puredoom.DOOM_KEY_RIGHT_ARROW);
    puredoom.doom_set_default_int("key_use", puredoom.DOOM_KEY_E);
    puredoom.doom_set_default_int("key_fire", puredoom.DOOM_KEY_F);
    // puredoom.doom_set_default_int("mouse_move", 0); // Mouse will not move forward

    var args = [_][*c]u8{@ptrCast(@constCast("test"))};
    puredoom.doom_init(1, @ptrCast(&args), 0);
    const screen = drawing.bitmapFromScreenbuffer(gfx_out);
    const backbuffer = drawing.bitmapCreate(uefi.pool_allocator, screen.width, screen.height) catch unreachable;

    const fps = 20.0;
    const loopEvent = uefi.system_table.boot_services.?.createEvent(.{ .timer = true }, .{ .function = null }) catch unreachable;
    uefi.system_table.boot_services.?.setTimer(loopEvent, .periodic, 10000000 / fps) catch unreachable;

    while (game_is_running) {
        _ = uefi.system_table.boot_services.?.waitForEvent(&[_]uefi.Event{loopEvent}) catch continue;
        // Check UEFI keystate and forward to
        handleEvent();

        // Hacketyhack - TODO: add timer with known target fps
        time += 1.0 / fps;
        puredoom.doom_update();
        const framebuffer = puredoom.doom_get_framebuffer(4);
        drawing.bltBitmapScaledEx(backbuffer, .{
            .buffer = @ptrCast(@constCast(framebuffer)),
            .height = 200,
            .width = 320,
            .stride = 320,
        }, 0, 0, backbuffer.width, backbuffer.height);

        drawing.bltToScreen(gfx_out, backbuffer, 0, 0);
    }

    if (END_WITH_PRESENTATION_SLIDE) {
        // Show finishing slide and hang for 3x enter
        slideFinal(backbuffer);
        drawing.bltToScreen(gfx_out, backbuffer, 0, 0);
        hangForKey(13);
        hangForKey(13);
        hangForKey(13);
    }

    return .success;
}

////////////////////////////////////////
// Final slide setup
////////////////////////////////////////
const Style = struct {
    fg_color: drawing.Pixel,
    bg_color: drawing.Pixel,
    outline_color: drawing.Pixel,
    text_size: u16,
};

const defaultStyle = Style{
    .fg_color = drawing.Colors.black,
    .bg_color = drawing.Colors.white,
    .outline_color = drawing.Pixel{ .int = 0xffcccccc },
    .text_size = 16,
};

pub fn hangForKey(keycode: u16) void {
    const boot_services = uefi.system_table.boot_services.?;
    // Do we have console input?
    if (uefi.system_table.con_in) |con_in| {
        // A list of events to check for - only key for now
        const events: [1]uefi.Event = [_]uefi.Event{con_in.wait_for_key};
        while (true) {
            // If checking several events: the return value must be inspected
            _ = boot_services.waitForEvent(&events) catch continue;
            const key = con_in.readKeyStroke() catch continue;
            if (key.unicode_char == keycode) break;
        }
    }
}

fn slideFinal(backbuffer: drawing.Bitmap) void {
    const unit = backbuffer.width / 100;
    // Shows the final slide: QR to repo + final greeting
    var finalQrBitmap = drawing.Bitmap.empty;
    finalQrBitmap = drawing.bitmapCreate(uefi.pool_allocator, 33, 33) catch unreachable;
    drawing.drawPlotToBitmap(
        33,
        33,
        2,
        finalQrBitmap,
        qr_plot,
        [2]drawing.Pixel{ defaultStyle.bg_color, defaultStyle.fg_color },
    );

    drawing.bitmapFill(backbuffer, defaultStyle.bg_color);

    _ = drawing.drawStringOutlined(
        backbuffer,
        2 * unit,
        20 * unit,
        drawing.Colors.transparent,
        defaultStyle.fg_color,
        defaultStyle.outline_color,
        0.2 * unit,
        @intFromFloat(@round(5 * unit)),
        "That's all,\nfolks!",
    );

    _ = drawing.drawStringOutlined(
        backbuffer,
        2 * unit,
        40 * unit,
        drawing.Colors.transparent,
        defaultStyle.fg_color,
        defaultStyle.outline_color,
        0.1 * unit,
        @intFromFloat(@round(3 * unit)),
        "Now go do\nsomething fun!",
        // g̵o̵o̵d̵
    );

    _ = drawing.drawStringOutlined(
        backbuffer,
        2 * unit,
        backbuffer.height - 3 * unit,
        drawing.Colors.transparent,
        defaultStyle.fg_color,
        defaultStyle.outline_color,
        0 * unit,
        @intFromFloat(@round(2 * unit)),
        "(Press enter x 3 to exit)",
        // g̵o̵o̵d̵
    );

    drawing.bltBitmapScaled(
        backbuffer,
        finalQrBitmap,
        60 * unit,
        20 * unit,
        95 * unit,
        55 * unit,
    );
}

pub const qr_plot: [33][33]u8 = .{
    [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1 },
    [_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1 },
    [_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 },
    [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1 },
    [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0 },
    [_]u8{ 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1 },
    [_]u8{ 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0 },
    [_]u8{ 0, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 0 },
    [_]u8{ 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0 },
    [_]u8{ 0, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1 },
    [_]u8{ 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0 },
    [_]u8{ 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0 },
    [_]u8{ 1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1 },
    [_]u8{ 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1 },
    [_]u8{ 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0 },
    [_]u8{ 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0 },
    [_]u8{ 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0 },
    [_]u8{ 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 },
    [_]u8{ 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0 },
    [_]u8{ 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0 },
    [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1 },
    [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0 },
    [_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0 },
    [_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0 },
    [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0 },
};
