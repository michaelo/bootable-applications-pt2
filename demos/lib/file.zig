const std = @import("std");
const utils = @import("utils.zig");
const uefi = std.os.uefi;

pub fn getVolume(handle: uefi.Handle) !*uefi.protocol.File {
    const bs = uefi.system_table.boot_services orelse return error.Fatal;
    const loaded_image = try bs.handleProtocol(uefi.protocol.LoadedImage, handle) orelse return error.Fatal;
    const volume = try bs.handleProtocol(uefi.protocol.SimpleFileSystem, loaded_image.device_handle.?) orelse return error.Fatal;
    return try volume.openVolume();
}

pub fn readFile(alloc: std.mem.Allocator, name: []const u8) ![]u8 {
    var scratch8: [128]u8 = undefined;
    var scratch16: [128]u16 = undefined;

    const volume = getVolume(uefi.handle) catch {
        return error.cant_get_volume;
    };
    var file = volume.open(utils.formatToU16(&scratch8, &scratch16, "{s}", .{name}), .read, .{}) catch {
        return error.cant_open_file;
    };
    defer file.close() catch {};

    const size = try file.readSize();
    // if (size == 0) return error.EmptyFile;
    _ = size;

    const buf = try alloc.alloc(u8, 1024 * 1024 * 10);
    errdefer alloc.free(buf);

    const read_bytes = file.read(buf) catch {
        return error.cant_read_file;
    };
    return buf[0..read_bytes];
}
