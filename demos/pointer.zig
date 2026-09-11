/// Showcases probing for pointer devices + some more advanced event handling
/// https://uefi.org/specs/UEFI/2.10/12_Protocols_Console_Support.html#simple-pointer-protocol
const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");

fn plotToBitmap(comptime W: usize, comptime H: usize, comptime ClutSize: usize, bitmap: utils.Bitmap, plot: [H][W]u8, clut: [ClutSize]utils.Pixel) void {
    const width = @min(W, @as(usize, @intFromFloat(bitmap.width)));
    const height = @min(H, @as(usize, @intFromFloat(bitmap.height)));
    const stride: usize = @intFromFloat(bitmap.stride);

    for (0..width) |y| {
        for (0..height) |x| {
            bitmap.buffer[stride * y + x] = clut[plot[y][x]].argb;
        }
    }
}

fn createPointerBitmap(alloc: std.mem.Allocator) !utils.Bitmap {
    // static EFI_INT8 pointer_plot[8][8] = {
    //     {0, 0, 0, 1, 1, 0, 0, 0},
    //     {0, 0, 0, 1, 1, 0, 0, 0},
    //     {0, 0, 0, 1, 1, 0, 0, 0},
    //     {1, 1, 1, 0, 0, 1, 1, 1},
    //     {1, 1, 1, 0, 0, 1, 1, 1},
    //     {0, 0, 0, 1, 1, 0, 0, 0},
    //     {0, 0, 0, 1, 1, 0, 0, 0},
    //     {0, 0, 0, 1, 1, 0, 0, 0},
    // };
    const pointer_plot: [8][8]u8 = .{
        [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0 },
        [_]u8{ 1, 1, 1, 1, 1, 1, 0, 0 },
        [_]u8{ 1, 1, 1, 1, 1, 0, 0, 0 },
        [_]u8{ 1, 1, 1, 1, 1, 0, 0, 0 },
        [_]u8{ 1, 1, 1, 1, 1, 1, 0, 0 },
        [_]u8{ 1, 1, 0, 0, 1, 1, 1, 0 },
        [_]u8{ 1, 0, 0, 0, 0, 1, 1, 1 },
        [_]u8{ 0, 0, 0, 0, 0, 0, 1, 1 },
    };

    const bitmap = try drawing.bitmapCreate(alloc, 8, 8);
    plotToBitmap(8, 8, 2, bitmap, pointer_plot, [2]utils.Pixel{ utils.Colors.transparent, utils.Colors.white });
    return bitmap;
}

pub fn main() uefi.Status {
    var scratch8: [1024]u8 = undefined;
    var scratch16: [1024]u16 = undefined;

    const boot_services = uefi.system_table.boot_services orelse unreachable;
    const gfx_out = boot_services.locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;
    const con_out = uefi.system_table.con_out orelse unreachable;
    con_out.reset(false) catch {};
    const screen = drawing.bitmapFromScreenbuffer(gfx_out);
    drawing.bitmapFill(screen, utils.Colors.black.argb);

    var ptr_x: f32 = 10;
    var ptr_y: f32 = 10;

    const pointer = createPointerBitmap(uefi.pool_allocator) catch unreachable;
    // drawing.blitToScreen(gfx_out, pointer, ptr_x, ptr_y);

    con_out.setCursorPosition(0, 0) catch {};
    _ = con_out.outputString(utils.W("Checking for pointers")) catch unreachable;

    // Looks up all simpler plointer devices, and returns a shrunk list
    const spp = blk: {
        // Storage buffer for devices found during search
        var spp_buffer: [3]*uefi.protocol.SimplePointer = undefined;

        // Search for any pointer devices
        const handler_buffer = (boot_services.locateHandleBuffer(.{ .by_protocol = &uefi.protocol.SimplePointer.guid }) catch unreachable) orelse unreachable;

        // Open each located handle (open up until first N)
        var i: usize = 0;
        while (i < spp_buffer.len and i < handler_buffer.len) : (i += 1) {
            const handle = handler_buffer[0];
            spp_buffer[i] = boot_services.openProtocol(uefi.protocol.SimplePointer, handle, .{ .by_handle_protocol = .{} }) catch unreachable orelse unreachable;
        }
        break :blk spp_buffer[0..i];
    };
    con_out.setCursorPosition(0, 1) catch {};
    _ = con_out.outputString(utils.formatToU16(&scratch8, &scratch16, "Found devices: {}", .{spp.len})) catch unreachable;
    con_out.setCursorPosition(0, 2) catch {};
    _ = con_out.outputString(utils.W("Registering events")) catch unreachable;

    const events = blk: {
        var events_buffer: [4]uefi.Event = undefined;

        // Get events for each pointer which we later can poll for changes
        var i: usize = 0;
        while (i < spp.len) : (i += 1) {
            events_buffer[i] = spp[i].wait_for_input;
        }

        // Also add event listener for key-input for exit
        events_buffer[i] = uefi.system_table.con_in.?.wait_for_key;
        i += 1;

        break :blk events_buffer[0..i];
    };

    con_out.setCursorPosition(0, 4) catch {};
    _ = con_out.outputString(utils.formatToU16(&scratch8, &scratch16, "Registered events: {}", .{events.len})) catch unreachable;

    // Draw and animate cursor by pointer protocol
    // Main loop
    // Draw initial
    drawing.bltBitmapXor(screen, pointer, ptr_x, ptr_y, ptr_x + 20, ptr_y + 20);
    while (true) {
        const event = boot_services.waitForEvent(events) catch unreachable;
        // Check which type of event source
        // Remove on previous position
        drawing.bltBitmapXor(screen, pointer, ptr_x, ptr_y, ptr_x + 20, ptr_y + 20);
        if (event.@"1" < spp.len) {
            // Pointer event
            const state = spp[event.@"1"].getState() catch unreachable;

            // TODO: Proper scale movement to pixels
            if (state.relative_movement_x != 0 and spp[event.@"1"].mode.resolution_x != 0) {
                ptr_x += (@as(f32, @floatFromInt(state.relative_movement_x)) / @as(f32, @floatFromInt(spp[event.@"1"].mode.resolution_x))) * 5;
            }

            if (state.relative_movement_y != 0 and spp[event.@"1"].mode.resolution_y != 0) {
                ptr_y += (@as(f32, @floatFromInt(state.relative_movement_y)) / @as(f32, @floatFromInt(spp[event.@"1"].mode.resolution_y))) * 5;
            }

            // events[event.@"1"]
            con_out.setCursorPosition(0, 5) catch {};
            _ = con_out.outputString(utils.W("pointer\r\n      ")) catch unreachable;
        } else {
            // ConIn event
            const key = uefi.system_table.con_in.?.readKeyStroke() catch unreachable;
            // https://uefi.org/specs/UEFI/2.11/Apx_B_Console.html
            switch (key.scan_code) {
                // escape
                0x17 => break,
                // up
                0x01 => {
                    ptr_y -= 5;
                },
                // down
                0x02 => {
                    ptr_y += 5;
                },
                // right
                0x03 => {
                    ptr_x += 5;
                },
                // left
                0x04 => {
                    ptr_x -= 5;
                },
                else => {},
            }

            // uefi.system_table.con_in.?.wait_for_key

            con_out.setCursorPosition(0, 5) catch {};
            _ = con_out.outputString(utils.W("     \r\nconin  \r\n")) catch unreachable;
        }

        _ = utils.renderString(
            screen,
            100,
            100,
            utils.Colors.black,
            utils.Colors.white,
            32,
            std.fmt.bufPrint(&scratch8, "pos: {}, {}", .{ ptr_x, ptr_y }) catch "ERR",
        );

        ptr_x = std.math.clamp(ptr_x, 0, screen.width - 20);
        ptr_y = std.math.clamp(ptr_y, 0, screen.height - 20);
        // Write on new
        drawing.bltBitmapXor(screen, pointer, ptr_x, ptr_y, ptr_x + 20, ptr_y + 20);
    }

    utils.hangForKey(13);

    return .success;
}
