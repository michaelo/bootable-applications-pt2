const std = @import("std");
const uefi = std.os.uefi;

pub const W = std.unicode.utf8ToUtf16LeStringLiteral;

/// Simple helper to - utilizing pre-allocated buffers - provide a slice of formatted utf16-string ready to pass to e.g. outputString()
pub fn formatToU16(buf8: []u8, buf16: []u16, comptime format: []const u8, comptime vars: anytype) [:0]const u16 {
    const formatted = std.fmt.bufPrint(buf8, format, vars) catch "";
    _ = std.unicode.utf8ToUtf16Le(buf16, formatted) catch 0;
    buf16[formatted.len] = 0;
    return buf16[0..formatted.len :0];
}

pub fn hangForKey(keycode: u16) void {
    const boot_services = uefi.system_table.boot_services.?;
    while (true) {
        const event = boot_services.waitForEvent(@as([]const uefi.Event, @ptrCast(&uefi.system_table.con_in.?.wait_for_key))) catch continue;
        _ = event;
        const key = uefi.system_table.con_in.?.readKeyStroke() catch continue;
        if (key.unicode_char == keycode) break;
    }
}
