//! This simply prints "Hello!" to the console output.
//! Att! Not all UEFI-realizations renders console output to the screen. qemu and several tested PCs do, whereas MacBook Pros do not.
const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");

pub fn main() uefi.Status {
    // _ = init;
    const con_out = uefi.system_table.con_out.?;
    con_out.reset(false) catch {};
    con_out.setCursorPosition(2, 2) catch {};
    _ = con_out.outputString(utils.W("Hello!\r\n")) catch {};

    utils.hangForKey(13);

    return .success;
}
