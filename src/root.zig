const std = @import("std");

// Simple, joyful RTF parser
pub const Parser = @import("rtf.zig").Parser;

test {
    std.testing.refAllDecls(@This());
    _ = @import("test_cases.zig");
}