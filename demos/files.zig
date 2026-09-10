//! Lists and opens files from the UEFI image/partition
const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");

// Att: assumes single threaded execution
var debug_row: usize = 0;
var scratch8: [128]u8 = undefined;
var scratch16: [128]u16 = undefined;

fn debug(comptime format: []const u8, params: anytype) void {
    const out = uefi.system_table.con_out.?;
    out.setCursorPosition(0, debug_row) catch {};
    _ = out.outputString(utils.formatToU16(&scratch8, &scratch16, format, params)) catch {};
    debug_row += 1;
}

fn getVolume(handle: uefi.Handle) !*uefi.protocol.File {
    const bs = uefi.system_table.boot_services orelse return error.Fatal;
    const loaded_image = try bs.handleProtocol(uefi.protocol.LoadedImage, handle) orelse return error.Fatal;
    const volume = try bs.handleProtocol(uefi.protocol.SimpleFileSystem, loaded_image.device_handle.?) orelse return error.Fatal;
    return try volume.openVolume();
}

/// Showcase open, read and write file
fn do() !void {
    uefi.system_table.con_out.?.reset(false) catch {};
    const volume = getVolume(uefi.handle) catch {
        debug("Could not get volume from image handle. Aborting", .{});
        return error.cant_read_volume;
    };

    // Read contents of some file. ATT! Requires file to be preexisting in mounted dir/image. Currently not
    //
    {
        var file = volume.open(utils.W("readme.txt"), .read, .{}) catch {
            debug("Could not open file. Aborting", .{});
            utils.hangForKey(13);
            return error.cant_open_file;
        };
        var buf: [128]u8 = undefined;
        const read_bytes = file.read(&buf) catch {
            debug("Could not read from file. Aborting", .{});
            return error.cant_read_file;
        };
        debug("Read from file: {s} ({d} bytes)", .{ buf[0..read_bytes], read_bytes });
        file.close() catch debug("Could not close", .{});
    }

    // Create new file and write to it
    {
        debug("Open file...", .{});
        var file = volume.open(utils.W("test.txt"), .read_write_create, .{}) catch {
            debug("Could not open file. Aborting", .{});
            return error.cant_open_file;
        };

        // Att: this only writes from start and does not truncate what (if anything) comes after
        _ = file.write("data goes here") catch {
            debug("Could not write to file. Aborting", .{});
            return error.cant_write_file;
        };

        file.flush() catch debug("Could not flush", .{});
        file.close() catch debug("Could not close", .{});
    }
}

pub fn main() uefi.Status {
    do() catch {
        debug("Got errors. Aborting. Press enter to continue.", .{});
        utils.hangForKey(13);
        return .aborted;
    };

    debug("All good. Press enter continue.", .{});
    utils.hangForKey(13);
    return .success;
}
