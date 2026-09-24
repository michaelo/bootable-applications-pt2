/// Highly narrow, use-case specific BMP support.
/// Currently only supports uncompressed, 32bit
/// https://gibberlings3.github.io/iesdp/file_formats/ie_formats/bmp.htm
const std = @import("std");
const testing = std.testing;
const drawing = @import("drawing.zig");

pub const BitmapHeader = extern struct {
    signature: u16 align(1) = 0x4d42,
    size: u32 align(1) = 0, // Att! User must add size of pixel array
    reserved: u32 align(1) = 0,
    file_offset_to_pixel_array: u32 align(1) = 0, // size of entire BmpHeader (bitmap + dib)...
};

pub const DibHeader = extern struct {
    dib_header_size: u32 = 0, //@sizeOf(DibHeader), // >=40
    w: i32,
    h: i32, // tip: if negative, file is ordered "top to bottom"
    planes: u16 = 1,
    bits_pr_pixel: u16 = 32, // 1, 4, 8, 16, 24, or 32
    compression: u32 = 0, // 0 = uncompressed
    image_size: u32 = 0, // OK with 0 for uncompressed images
    x_pixels_pr_meter: u32 = 0, // no preference
    y_pixels_pr_meter: u32 = 0, // no preference
    colors_in_color_table: u32 = 0, // for no color table // TODO: Perf: can reduce data a lot by going indexed.
    important_color_count: u32 = 0, // TBD
};

pub const BmpHeader = extern struct {
    bitmap_header: BitmapHeader align(1) = .{},
    dib_header: DibHeader align(1),
};

pub fn loadBmpToBitmapFromReader(allocator: std.mem.Allocator, reader: *std.Io.Reader) !drawing.Bitmap {
    // Read and evaluate key header fields
    const bmp_header = try reader.takeStruct(BmpHeader, .little);

    if (bmp_header.bitmap_header.signature != 0x4d42) return error.UnsupportedFormat;

    if (bmp_header.dib_header.compression != 0) return error.UnsupportedCompression;
    if (bmp_header.dib_header.bits_pr_pixel != 32 and bmp_header.dib_header.bits_pr_pixel != 24) return error.UnsupportedBitdepth;
    const bytes_pr_pixel: i32 = if (bmp_header.dib_header.bits_pr_pixel == 32) 4 else 3;
    const bytes_pr_pixel_usize: usize = @intCast(bytes_pr_pixel);

    const w: usize = @intCast(bmp_header.dib_header.w);
    const h: usize = @intCast(bmp_header.dib_header.h);

    // Read and evaluate pixel data
    var raw_data = try allocator.alloc(u8, w * h * bytes_pr_pixel_usize);
    defer allocator.free(raw_data);

    try reader.readSliceAll(raw_data[0..]);
    if (raw_data.len != bmp_header.bitmap_header.size - (@sizeOf(BitmapHeader) + @sizeOf(DibHeader))) return error.UnexpectedSize;

    // Allocate result-array, parse pixel data to it and return. Caller owns allocation upon success.
    var data = try allocator.alloc(drawing.BltPixel, w * h);
    errdefer allocator.free(data);

    var y: usize = 0;
    while (y < h) : (y += 1) {
        // BMPs with positive height are ordered bottom-top, we turn it around

        var x: usize = 0;
        // Highly inefficient - but it works for now. Consider if we can SIMD-handle the field switching
        while (x < w) : (x += 1) {
            const begin = (h - 1 - y) * (w * bytes_pr_pixel_usize) + (x * bytes_pr_pixel_usize);
            const px = raw_data[begin .. begin + bytes_pr_pixel_usize];
            // _ = begin;
            data[y * w + x] = switch (bmp_header.dib_header.bits_pr_pixel) {
                // Highly inefficient to switch in inner loop (TODO)!
                24 => drawing.BltPixel{
                    .red = px[2],
                    .green = px[1],
                    .blue = px[0],
                    .reserved = 255,
                },
                // This could likely be copied as is, row by row. Depending on if reserved is on proper end. (TODO)
                32 => drawing.BltPixel{
                    .red = px[2],
                    .green = px[1],
                    .blue = px[0],
                    .reserved = 255,
                },
                else => return error.UnsupportedBitdepth,
            };
        }
    }

    return .{
        .width = @floatFromInt(w),
        .stride = @floatFromInt(w),
        .height = @floatFromInt(h),
        .buffer = @ptrCast(data),
    };
}

// TODO: add test to verify colors
test "loadBmpToBitmapFromReader" {
    // Initiate file/reader
    const file = try std.Io.Dir.cwd().openFile(std.testing.io, "testfiles/pbn_heart_9x8.bmp", .{});
    defer file.close(std.testing.io);

    var buf: [128]u8 = undefined;
    var reader = file.reader(std.testing.io, &buf);
    var bmp = try loadBmpToBitmapFromReader(testing.allocator, &reader.interface);
    defer bmp.free(std.testing.allocator);
    // testing.allocator.free(bmp.data);

    try testing.expect(bmp.width == 9);
    try testing.expect(bmp.height == 8);
    // try testing.expect(bmp.data.len == bmp.width * bmp.height);

    // Spot tests
    const b = drawing.Colors.black.argb;
    const w = drawing.Colors.white.argb;
    try drawing.expectBitmap(&[_]drawing.BltPixel{
        w, w, w, w, w, w, w, w, w,
        w, w, b, b, w, b, b, w, w,
        w, b, w, w, b, w, w, b, w,
        w, b, w, w, w, w, w, b, w,
        w, w, b, w, w, w, b, w, w,
        w, w, w, b, w, b, w, w, w,
        w, w, w, w, b, w, w, w, w,
        w, w, w, w, w, w, w, w, w,
    }, bmp);
}
