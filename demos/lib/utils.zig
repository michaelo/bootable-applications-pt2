const std = @import("std");
const uefi = std.os.uefi;

pub const W = std.unicode.utf8ToUtf16LeStringLiteral;

/// Simple helper to - utilizing pre-allocated buffers - provide a slice of formatted utf16-string ready to pass to e.g. outputString()
pub fn formatToU16(buf8: []u8, buf16: []u16, comptime format: []const u8, vars: anytype) [:0]const u16 {
    const formatted = std.fmt.bufPrint(buf8, format, vars) catch "";
    _ = std.unicode.utf8ToUtf16Le(buf16, formatted) catch 0;
    buf16[formatted.len] = 0;
    return buf16[0..formatted.len :0];
}

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

pub fn getFirstOfProtocolOptimistic(comptime protocol: type) ?*protocol {
    return uefi.system_table.boot_services.?.locateProtocol(protocol, null) catch null orelse null;
}

fn getVolumeFromImageHandle(handle: uefi.Handle) !*uefi.protocol.File {
    const bs = uefi.system_table.boot_services orelse return error.Fatal;
    const loaded_image = try bs.handleProtocol(uefi.protocol.LoadedImage, handle) orelse return error.Fatal;
    const volume = try bs.handleProtocol(uefi.protocol.SimpleFileSystem, loaded_image.device_handle.?) orelse return error.Fatal;
    return try volume.openVolume();
}
