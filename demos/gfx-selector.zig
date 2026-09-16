/// Showcases basic
const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");

const BltPixel = uefi.protocol.GraphicsOutput.BltPixel;

pub fn main() uefi.Status {
    const boot_services = uefi.system_table.boot_services.?;

    // Query modes
    // Look up handlers for all devices of gfxout protocol
    const gfx_out_handlers: []uefi.Handle = @ptrCast(boot_services.locateHandleBuffer(.{ .by_protocol = &uefi.protocol.GraphicsOutput.guid }) catch null orelse unreachable);

    var scratch8: [128]u8 = undefined;
    var mode_idx: u32 = 0;
    var device_idx: usize = 0;

    while (true) {
        // Get first graphics protocol and set first mode to get any display
        // Open protocol by handler
        const gfx_out = boot_services.openProtocol(uefi.protocol.GraphicsOutput, gfx_out_handlers[device_idx], .{ .by_handle_protocol = .{} }) catch null orelse unreachable;
        gfx_out.setMode(mode_idx) catch unreachable;
        const screen = drawing.bitmapFromScreenbuffer(gfx_out);
        drawing.bitmapFill(screen, drawing.Colors.black);
        // TOOD: support formatting and newline
        _ = drawing.drawString(
            screen,
            10.0,
            @floatFromInt(1 * 16),
            drawing.Colors.transparent,
            drawing.Colors.white,
            16,
            std.fmt.bufPrint(&scratch8, "L/R to iterate device, U/D to iterate mode", .{}) catch "...",
        );

        _ = drawing.drawString(
            screen,
            10.0,
            @floatFromInt(3 * 16),
            drawing.Colors.transparent,
            drawing.Colors.white,
            16,
            std.fmt.bufPrint(&scratch8, "{d}/{d}:{d}/{d} -> {d}x{d}", .{ device_idx + 1, gfx_out_handlers.len, mode_idx + 1, gfx_out.mode.max_mode, gfx_out.mode.info.horizontal_resolution, gfx_out.mode.info.vertical_resolution }) catch "...",
        );

        _ = boot_services.waitForEvent(@as([]const uefi.Event, @ptrCast(&uefi.system_table.con_in.?.wait_for_key))) catch continue;
        const key = uefi.system_table.con_in.?.readKeyStroke() catch continue;
        switch (key.scan_code) {
            1 => { // up?
                mode_idx = if (mode_idx > 0) mode_idx - 1 else 0;
            },
            2 => { // down?
                mode_idx = std.math.clamp(mode_idx + 1, 0, gfx_out.mode.max_mode - 1);
            },
            3 => { // right
                device_idx = std.math.clamp(device_idx + 1, 0, gfx_out_handlers.len - 1);
                mode_idx = 0;
            },
            4 => { // left
                device_idx = if (device_idx > 0) device_idx - 1 else 0;
                mode_idx = 0;
            },
            else => {},
        }

        switch (key.unicode_char) {
            'q' => {
                break;
            },
            else => {},
        }
    }
    return .success;
}
