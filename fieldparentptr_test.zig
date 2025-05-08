const std = @import("std");

pub fn main() !void {
    _ = @fieldParentPtr;
    std.debug.print("Hello, world!\n", .{});
}