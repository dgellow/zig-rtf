const std = @import("std");
const testing = std.testing;

// First, let's test the basic RTF parser works
test "basic rtf text extraction" {
    const rtf_parser = @import("rtf.zig");
    const rtf_data = "{\\rtf1 Hello World}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    std.debug.print("RTF input: '{s}'\n", .{rtf_data});
    std.debug.print("Extracted text: '{s}'\n", .{text});
    
    try testing.expect(std.mem.indexOf(u8, text, "Hello World") != null);
}

test "rtf with formatting control words" {
    const rtf_parser = @import("rtf.zig");
    const rtf_data = "{\\rtf1 Hello \\b bold\\b0 text}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    std.debug.print("RTF input: '{s}'\n", .{rtf_data});
    std.debug.print("Extracted text: '{s}'\n", .{text});
    
    // Should extract clean text without RTF markup
    try testing.expect(std.mem.indexOf(u8, text, "Hello") != null);
    try testing.expect(std.mem.indexOf(u8, text, "bold") != null);
    try testing.expect(std.mem.indexOf(u8, text, "text") != null);
    try testing.expect(std.mem.indexOf(u8, text, "\\b") == null); // No RTF markup
}

test "rtf with nested groups" {
    const rtf_parser = @import("rtf.zig");
    const rtf_data = "{\\rtf1 Normal {\\b bold {\\i bold italic} bold} normal}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    std.debug.print("RTF input: '{s}'\n", .{rtf_data});
    std.debug.print("Extracted text: '{s}'\n", .{text});
    
    // Should handle nested groups and extract text
    try testing.expect(std.mem.indexOf(u8, text, "Normal") != null);
    try testing.expect(std.mem.indexOf(u8, text, "bold") != null);
    try testing.expect(std.mem.indexOf(u8, text, "italic") != null);
}

test "complex real world rtf" {
    const rtf_parser = @import("rtf.zig");
    // Simulate RTF that WordPad might generate
    const rtf_data = 
        \\{\rtf1\ansi\deff0{\fonttbl{\f0\froman Times New Roman;}}
        \\{\colortbl;\red0\green0\blue0;}
        \\This is \b bold\b0 text and \i italic\i0 text.
        \\}
    ;
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    std.debug.print("Complex RTF input: '{s}'\n", .{rtf_data});
    std.debug.print("Extracted text: '{s}'\n", .{text});
    
    // Should extract proper text without RTF markup
    try testing.expect(std.mem.indexOf(u8, text, "This is") != null);
    try testing.expect(std.mem.indexOf(u8, text, "bold") != null);
    try testing.expect(std.mem.indexOf(u8, text, "italic") != null);
    try testing.expect(std.mem.indexOf(u8, text, "\\b") == null); // No RTF markup in output
    try testing.expect(std.mem.indexOf(u8, text, "\\fonttbl") == null); // No font table markup
}

test "malformed rtf handling" {
    const rtf_parser = @import("rtf.zig");
    const rtf_data = "{\\rtf1 \\b bold text without closing group";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    // Should handle malformed RTF gracefully
    if (parser.parse()) {
        const text = parser.getText();
        std.debug.print("Malformed RTF output: '{s}'\n", .{text});
        // If it succeeds, at least verify we got some text
        try testing.expect(text.len > 0);
    } else |err| {
        std.debug.print("Malformed RTF failed as expected: {}\n", .{err});
        // Failing is also acceptable for malformed RTF
    }
}

test "empty and edge cases" {
    const rtf_parser = @import("rtf.zig");
    
    // Empty RTF
    {
        const rtf_data = "{\\rtf1}";
        var stream = std.io.fixedBufferStream(rtf_data);
        var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
        defer parser.deinit();
        
        try parser.parse();
        const text = parser.getText();
        std.debug.print("Empty RTF text: '{s}'\n", .{text});
    }
    
    // RTF with only formatting, no text
    {
        const rtf_data = "{\\rtf1 \\b\\i\\ul\\b0\\i0\\ulnone}";
        var stream = std.io.fixedBufferStream(rtf_data);
        var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
        defer parser.deinit();
        
        try parser.parse();
        const text = parser.getText();
        std.debug.print("Formatting-only RTF text: '{s}'\n", .{text});
    }
}

// Test performance with larger document
test "performance test" {
    const rtf_parser = @import("rtf.zig");
    
    // Build a larger RTF document
    var rtf_buffer = std.ArrayList(u8).init(testing.allocator);
    defer rtf_buffer.deinit();
    
    try rtf_buffer.appendSlice("{\\rtf1 ");
    
    // Add lots of formatted text
    for (0..1000) |i| {
        try rtf_buffer.writer().print("Word{} \\b bold{} \\b0 ", .{ i, i });
    }
    
    try rtf_buffer.append('}');
    
    const start = std.time.nanoTimestamp();
    
    var stream = std.io.fixedBufferStream(rtf_buffer.items);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    const end = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    
    std.debug.print("Performance test:\n", .{});
    std.debug.print("  RTF size: {} bytes\n", .{rtf_buffer.items.len});
    std.debug.print("  Text extracted: {} bytes\n", .{text.len});
    std.debug.print("  Parse time: {d:.2} ms\n", .{duration_ms});
    
    // Should be reasonably fast
    try testing.expect(duration_ms < 100.0); // Less than 100ms for 1000 words
    try testing.expect(text.len > 0);
}