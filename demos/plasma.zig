/// Zig-port of C-version of plasma-example from original BA-repo as added by TerjeW
const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");

fn dist(a: f32, b: f32, c: f32, d: f32) f32 {
    return @sqrt((a - c) * (a - c) + (b - d) * (b - d));
}

fn waveFunc(x: f32, y: f32, px: f32, py: f32, scaleFactor: f32) f32 {
    return @sin(dist(x, y, px, py) / scaleFactor);
}

/// Returned buffer is owned by caller
fn initializeStaticData(alloc: std.mem.Allocator, bitmap: utils.Bitmap) ![]f32 {
    var data = try alloc.alloc(f32, @intFromFloat(bitmap.width * bitmap.height));
    errdefer alloc.free(data);

    const width: f32 = bitmap.width;
    const height: f32 = bitmap.height;

    //Position of the static points
    const p1x: f32 = width * 0.25;
    const p2x: f32 = width * 0.75;
    const p1y: f32 = height * 0.25;
    const p2y: f32 = height * 0.375;
    const scaleFactor: f32 = (width / 20);

    var y: f32 = 0;
    while (y < height) : (y += 1) {
        var x: f32 = 0;
        while (x < width) : (x += 1) {
            data[@intFromFloat(y * width + x)] =
                waveFunc(x, y, p1x, p1y, scaleFactor) + // constant for each x,y. Distance from the static point p1
                waveFunc(x, y, p2x, p2y, scaleFactor); // constant for each x,y. Distance from the static point p2
        }
    }
    return data;
}

fn hueToRgb(hue: u16) utils.Pixel {
    var bgra = utils.Colors.black;
    const region = hue / 43;
    const remainder = (hue % 43) * 6;
    const max = 255;

    const p: u8 = 0;
    const q: u16 = max - ((max * remainder) >> 8);
    const t: u8 = @intCast((max * remainder) >> 8);

    switch (region) {
        0 => {
            bgra.argb.red = max;
            bgra.argb.green = t;
            bgra.argb.blue = p;
        },
        1 => {
            bgra.argb.red = @intCast(q);
            bgra.argb.green = max;
            bgra.argb.blue = p;
        },
        2 => {
            bgra.argb.red = p;
            bgra.argb.green = max;
            bgra.argb.blue = t;
        },
        3 => {
            bgra.argb.red = p;
            bgra.argb.green = @intCast(q);
            bgra.argb.blue = max;
        },
        4 => {
            bgra.argb.red = t;
            bgra.argb.green = p;
            bgra.argb.blue = max;
        },
        else => {
            bgra.argb.red = max;
            bgra.argb.green = p;
            bgra.argb.blue = @intCast(q);
        },
    }

    return bgra;
}

fn plasma(staticData: []f32, backbuffer: utils.Bitmap, time: f32) void {
    const w: f32 = (backbuffer.width);
    const h: f32 = (backbuffer.height);
    const xPos: f32 = w / 2 + (w * @cos(time / 13));
    const yPos: f32 = h / 3 + (h * @cos(time / 17));

    const p3x: f32 = w * 0.75;
    const p4y: f32 = h * 0.5;

    const scaleFactor: f32 = (w / 20);

    var y: f32 = 0;

    while (y < h) : (y += 1) {
        var x: f32 = 0;
        while (x < w) : (x += 1) {
            const pos: usize = @intFromFloat(y * w + x);
            var value =
                staticData[pos] + waveFunc(x, y, p3x, yPos, scaleFactor) //Distance from point p3, which is moving vertically
                + waveFunc(x, y, xPos, p4y, scaleFactor); //Distance from point p4, which is moving horizontally

            //value is the sum of 4 sine waves, which leaves it in the range [-4, 4]
            value += 3.5; //shift into something more visually appealing, with deep red on one end and deep purple on the other
            value = @mod(value + 8, 8) / 8; // Normalize to [0, 1]
            backbuffer.buffer[pos] = hueToRgb(@intFromFloat(value * 255)).argb;
        }
    }
}

pub fn main() uefi.Status {
    const gfx_out = uefi.system_table.boot_services.?.locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;
    const boot_serviecs = uefi.system_table.boot_services orelse unreachable;

    const screen = drawing.bitmapFromScreenbuffer(gfx_out);
    const bitmap = drawing.bitmapCreate(uefi.pool_allocator, 240, 180) catch unreachable;
    const backbuffer = drawing.bitmapCreate(uefi.pool_allocator, screen.width, screen.height) catch unreachable;

    const staticData = initializeStaticData(uefi.pool_allocator, bitmap) catch unreachable;
    var t: f32 = 0;
    const speed: f32 = 0.07;

    const fps = 60;
    const loopEvent = boot_serviecs.createEvent(.{ .timer = true }, .{ .function = null }) catch unreachable;
    boot_serviecs.setTimer(loopEvent, .periodic, 10000000 / fps) catch unreachable;

    while (true) {
        _ = boot_serviecs.waitForEvent(&[_]uefi.Event{loopEvent}) catch continue;
        plasma(staticData, bitmap, t);
        drawing.bltBitmapScaled(backbuffer, bitmap, 0, 0, (backbuffer.width), (backbuffer.height));
        drawing.blitToScreen(gfx_out, backbuffer, 0, 0);
        t += speed;
    }

    return .success;
}
