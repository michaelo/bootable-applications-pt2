//! This simply prints "Hello!" to the console output.
//! Att! Not all UEFI-realizations renders console output to the screen. qemu and several tested PCs do, whereas MacBook Pros do not.
//! https://uefi.org/specs/UEFI/2.10/12_Protocols_Console_Support.html#simple-text-output-protocol
const std = @import("std");

const utils = @import("lib/utils.zig");

pub fn main() std.os.uefi.Status {
    // system_table.con_out is a convenience-reference to a EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL instance (if found)
    // Manual lookup will look something like: (error handling be damned)
    const con_out = std.os.uefi.system_table.boot_services.?
        .locateProtocol(std.os.uefi.protocol.SimpleTextOutput, null) catch null orelse unreachable;
    // const con_out = std.os.uefi.system_table.con_out.?;
    con_out.reset(false) catch {};
    con_out.setCursorPosition(2, 2) catch {};

    // UEFI works with wide (UTF-16) strings, (stdlib has convenient functions to convert UTF8->UTF16)
    _ = con_out.outputString(&[_:0]u16{ 'H', 'e', 'l', 'l', 'o', 0 }) catch {};

    return .success;
}
