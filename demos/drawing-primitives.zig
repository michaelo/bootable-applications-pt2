const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");

pub fn main() uefi.Status {
    const gfx_out = uefi.system_table.boot_services.?.locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;

    // Retrieve screen buffer
    const screen = drawing.bitmapFromScreenbuffer(gfx_out);
    drawing.bitmapFill(screen, utils.Colors.green);

    // Create a bitmap for intermediary drawing (can also draw directly to screen, but usually less efficient)
    const bitmap = drawing.bitmapCreate(uefi.pool_allocator, 256, 128) catch unreachable;
    drawing.bitmapFill(bitmap, utils.Colors.white);

    // Render string to bitmap
    _ = utils.renderString(bitmap, 0, 0, utils.Colors.transparent, utils.Colors.black, 16, "abc!");

    // Draw line to bitmap
    drawing.drawLineWidth(bitmap, 3, 3, 30, 30, utils.Colors.red, 1);

    // Transfer bitmap (unscaled) to display
    drawing.blitToScreen(gfx_out, bitmap, 0, 0);

    // Transfer and scale bitmap to display
    drawing.bltBitmapScaled(screen, bitmap, 150, 150, 400, 400);

    // Draw box
    drawing.drawBox(screen, 30, 20, 100, 150, utils.Colors.red, 1);
    drawing.drawBox(screen, 70, 40, 100, 150, utils.Colors.red, 4);

    // Draw circle / ellipsis

    // Draw shaded line

    utils.hangForKey(13);

    return .success;
}
