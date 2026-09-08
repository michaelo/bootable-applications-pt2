/// Replaces the render entirety of small bitmap -> scale up to backbuffer -> blit backbuffer to screen with xor drawing directly to backbuffer
const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");

pub fn main() uefi.Status {
    const bg = utils.Pixel{ .int = 0xff000000 };

    const boot_serviecs = uefi.system_table.boot_services orelse unreachable;
    const gfx_out = uefi.system_table.boot_services.?.locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;
    const screen = drawing.bitmapFromScreenbuffer(gfx_out);
    drawing.bitmapFill(screen, bg.argb);
    // const bitmap = drawing.bitmapCreate(uefi.pool_allocator, 320, 240) catch unreachable;
    const backbuffer = drawing.bitmapCreate(uefi.pool_allocator, screen.width, screen.height) catch unreachable;
    drawing.bitmapFill(backbuffer, bg.argb);

    const fps = 240;
    const loopEvent = boot_serviecs.createEvent(.{ .timer = true }, .{ .function = null }) catch unreachable;
    boot_serviecs.setTimer(loopEvent, .periodic, 10000000 / fps) catch unreachable;

    const Circle = struct {
        x: f32 = 0,
        y: f32 = 0,
        w: f32 = 0,
        h: f32 = 0,
        dx: f32 = 0,
        dy: f32 = 0,
        c: utils.Pixel = utils.Colors.white,
    };
    var circles = [_]Circle{
        Circle{
            .x = 0,
            .y = 0,
            .w = 40,
            .h = 40,
            .dx = 3,
            .dy = 5,
            .c = utils.Colors.green,
        },
        Circle{
            .x = 30,
            .y = 80,
            .w = 40,
            .h = 40,
            .dx = 2,
            .dy = -2,
            .c = utils.Colors.blue,
        },
        Circle{
            .x = 30,
            .y = 80,
            .w = 50,
            .h = 50,
            .dx = -3,
            .dy = -1,
            .c = utils.Colors.red,
        },
    };

    // Initial draw to ensure future xor behaves as expected
    for (circles) |s| {
        drawing.drawCircleXor(backbuffer, s.x, s.y, s.w, s.h, s.c);
    }

    while (true) {
        _ = boot_serviecs.waitForEvent(&[_]uefi.Event{loopEvent}) catch continue;
        // Remove all objects
        for (circles) |s| {
            drawing.drawCircleXor(backbuffer, s.x, s.y, s.w, s.h, s.c);
        }

        // Update state
        for (&circles) |*s| {
            s.x += s.dx;
            s.y += s.dy;

            if (s.x < 0) {
                s.dx = -s.dx;
                s.x = 0;
            }
            if (s.x + s.w > backbuffer.width - 1) {
                s.dx = -s.dx;
                s.x = backbuffer.width - s.w - 1;
            }

            if (s.y < 0) {
                s.dy = -s.dy;
                s.y = 0;
            }
            if (s.y + s.h > backbuffer.height - 1) {
                s.dy = -s.dy;
                s.y = backbuffer.height - s.h - 1;
            }
        }

        // Render all objects
        for (circles) |s| {
            drawing.drawCircleXor(backbuffer, s.x, s.y, s.w, s.h, s.c);
        }

        // Scale and transfer to screen
        // drawing.bltBitmapScaled(backbuffer, bitmap, 0, 0, @intCast(backbuffer.width), @intCast(backbuffer.height));
        drawing.blitToScreen(gfx_out, backbuffer, 0, 0);
    }
}
