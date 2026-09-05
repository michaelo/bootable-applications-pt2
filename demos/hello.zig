const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("utils.zig");

pub fn main() uefi.Status {
    // _ = init;
    const con_out = uefi.system_table.con_out.?;
    con_out.reset(false) catch {};
    _ = con_out.outputString(utils.W("Hello!\r\n")) catch {};

    utils.hangForKey(13);

    return .success;
}
