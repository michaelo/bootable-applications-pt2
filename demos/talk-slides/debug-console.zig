const drawing = @import("../lib/drawing.zig");
const Box = @import("../talk-slides.zig").Box;
const std = @import("std");

pub fn DebugConsole(comptime size: usize) type {
    return struct {
        const Self = @This();

        data: [size][128]u8 = undefined,
        lengths: [size]usize = undefined,

        len: usize = 0,
        next_idx: usize = 0,

        fg: drawing.Pixel = drawing.Colors.black,
        bg: drawing.Pixel = drawing.Colors.white,

        pub fn write(self: *Self, comptime format: []const u8, params: anytype) void {
            // TBD: break to new line?
            const str = std.fmt.bufPrint(&self.data[self.next_idx], format, params) catch self.data[self.next_idx][0..];
            self.lengths[self.next_idx] = str.len;

            // We've reached capacity
            if (self.len < size) {
                self.len += 1;
            }

            self.next_idx += 1;

            if (self.next_idx >= self.data.len) {
                self.next_idx = 0;
            }
        }

        pub fn render(self: Self, bitmap: drawing.Bitmap, box: Box, text_size: u16) void {
            // Starting at bottom, draw last line, then fill upwards, backwards
            const line_spacing = 2;
            const padding = 2;

            drawing.drawBoxFilled(bitmap, box.x, box.y, box.w, box.h, self.bg, self.bg, 0);

            if (self.len == 0) return;

            var line_y: f32 = box.y + box.h - text_size - padding;

            var line_idx: i32 = 0;
            const lines_total: i32 = @intCast(self.len);
            // var lines_printed: i32 = 0;
            while (line_idx < lines_total) : (line_idx += 1) {
                // var data_idx: i32 = @intCast(if(self.next_idx == 0) self.len-1 else self.next_idx-1);
                var data_idx: i32 = @as(i32, @intCast(self.next_idx)) - line_idx - 1;
                if (data_idx < 0) {
                    data_idx += @intCast(self.len);
                }

                _ = drawing.drawString(
                    bitmap,
                    box.x + padding,
                    line_y,
                    self.bg,
                    self.fg,
                    text_size,
                    self.data[@intCast(data_idx)][0..self.lengths[@intCast(data_idx)]],
                );
                line_y -= text_size + line_spacing;

                if (line_y < box.y) {
                    break;
                }
            }
        }
    };
}

test "DebugConsole" {
    var console_uut: DebugConsole(3) = .{};
    try std.testing.expectEqual(0, console_uut.len);
    try std.testing.expectEqual(0, console_uut.next_idx);

    console_uut.write("data: {d}", .{1});
    try std.testing.expectEqual(1, console_uut.len);
    try std.testing.expectEqual(1, console_uut.next_idx);

    console_uut.write("data: {d}", .{2});
    try std.testing.expectEqual(2, console_uut.len);
    try std.testing.expectEqual(2, console_uut.next_idx);

    console_uut.write("data: {d}", .{3});
    try std.testing.expectEqual(3, console_uut.len);
    try std.testing.expectEqual(0, console_uut.next_idx);

    console_uut.write("data: {d}", .{4});
    try std.testing.expectEqual(3, console_uut.len);
    try std.testing.expectEqual(1, console_uut.next_idx);

    console_uut.write("data: {d}", .{5});
    try std.testing.expectEqual(3, console_uut.len);
    try std.testing.expectEqual(2, console_uut.next_idx);
}
