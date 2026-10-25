/// Mocks file system API to provide file-access to Doom resources
/// It solves this by embedding the files into the build artifact rather
/// than the proper way of integrating the UEFI file protocol APIs.
///
/// We're only embedding the shareware wad for Doom 1.
const std = @import("std");
const uefi = std.os.uefi;
const doom1wad = @embedFile("doom1.wad");

const File = struct {
    name: []const u8,
    data: []const u8,
    pos: usize,
};

var Doom1Wad = File{
    .name = "./doom1.wad",
    .data = doom1wad,
    .pos = 0,
};

pub fn open(path: [*c]const u8, attrs: [*c]const u8) callconv(.c) ?*anyopaque {
    _ = attrs;
    // std.debug.print("open: {s}\n", .{path});

    if (std.mem.orderZ(u8, path, "./doom1.wad") == .eq) {
        return @ptrCast(&Doom1Wad);
    }
    return null;
}
pub fn close(maybe_handle: ?*anyopaque) callconv(.c) void {
    _ = maybe_handle;
}
pub fn read(maybe_handle: ?*anyopaque, buffer: ?*anyopaque, size: c_int) callconv(.c) c_int {
    if (maybe_handle) |handle| {
        const file: *File = @ptrCast(@alignCast(handle));
        const sizeu: usize = @intCast(size);
        if (handle != @as(*anyopaque, @ptrCast(&Doom1Wad))) {
            // std.debug.print("Reading from not doom1.wad - ERROR\n", .{});
            return 0;
        }

        const checked_size = if (sizeu + file.pos < file.data.len) sizeu else file.data.len - file.pos;

        if (buffer) |b| {
            // TODO: Cast handle to File on operate on data. Currently only care about file

            @memcpy(
                @as([*]u8, @ptrCast(b))[0..checked_size],
                @as([*]const u8, @ptrCast(file.data))[file.pos .. file.pos + checked_size],
            );
            // std.debug.print("Reading {d} bytes\n", .{checked_size});
            file.pos += checked_size;
            return @intCast(checked_size);
        }
    }

    return 0;
}
pub fn write(maybe_handle: ?*anyopaque, buffer: ?*const anyopaque, size: c_int) callconv(.c) c_int {
    // std.debug.print("write - SHALL NOT BE ALLOWED?!?\n", .{});
    _ = maybe_handle;
    _ = buffer;
    _ = size;
    return 0;
}

// typedef enum
// {
//     DOOM_SEEK_CUR = 1,
//     DOOM_SEEK_END = 2,
//     DOOM_SEEK_SET = 0
// } doom_seek_t;
pub fn seek(maybe_handle: ?*anyopaque, offset: c_int, reference: c_int) callconv(.c) c_int {
    if (maybe_handle) |handle| {
        const file: *File = @ptrCast(@alignCast(handle));
        // std.debug.print("Seeking {s}: {d} {d}\n", .{ file.name, offset, reference });
        switch (reference) {
            0 => {
                file.pos = @intCast(offset);
            },
            1 => {
                file.pos += @intCast(offset);
            },
            2 => {
                file.pos = file.data.len - 1 - @as(usize, @intCast(offset));
            },
            else => {},
        }
    }
    return 0;
}
pub fn tell(maybe_handle: ?*anyopaque) callconv(.c) c_int {
    if (maybe_handle) |handle| {
        const file: *File = @ptrCast(@alignCast(handle));
        // std.debug.print("Telling {s}\n", .{file.name});
        return @intCast(file.data.len);
    }
    return 0;
}
pub fn eof(maybe_handle: ?*anyopaque) callconv(.c) c_int {
    if (maybe_handle) |handle| {
        const file: *File = @ptrCast(@alignCast(handle));
        // std.debug.print("EOF {s}: {d} >= {d}\n", .{ file.name, file.pos, file.data.len });
        return if (file.pos >= file.data.len) 1 else 0;
    }
    return 0;
}
