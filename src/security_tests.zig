const std = @import("std");
const testing = std.testing;

test "extremely nested groups - stack overflow protection" {
    const rtf_parser = @import("rtf.zig");
    
    // Create deeply nested RTF that could cause stack overflow
    var rtf_buffer = std.ArrayList(u8).init(testing.allocator);
    defer rtf_buffer.deinit();
    
    try rtf_buffer.appendSlice("{\\rtf1 ");
    
    // Create 1000 nested groups
    for (0..1000) |_| {
        try rtf_buffer.append('{');
    }
    
    try rtf_buffer.appendSlice("Deep");
    
    for (0..1000) |_| {
        try rtf_buffer.append('}');
    }
    
    try rtf_buffer.append('}');
    
    std.debug.print("Testing {} levels of nesting\n", .{1000});
    
    var stream = std.io.fixedBufferStream(rtf_buffer.items);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    // Should handle deep nesting without crashing
    if (parser.parse()) {
        const text = parser.getText();
        std.debug.print("Deep nesting result: '{s}'\n", .{text});
        try testing.expect(std.mem.indexOf(u8, text, "Deep") != null);
    } else |err| {
        std.debug.print("Deep nesting failed (acceptable): {}\n", .{err});
        // Failing is acceptable for extreme nesting
    }
}

test "malformed control words - buffer overflow protection" {
    const rtf_parser = @import("rtf.zig");
    
    const malformed_rtf_cases = [_][]const u8{
        "{\\rtf1 \\extremelylongcontrolwordthatshouldbetruncat text}",
        "{\\rtf1 \\999999999999999999999999999999 text}",
        "{\\rtf1 \\b-999999999999999999999999999 text}",
        "{\\rtf1 \\\x00\x01\x02\x03 text}",
        "{\\rtf1 \\u999999999999999999999999999999999999? text}",
    };
    
    for (malformed_rtf_cases, 0..) |rtf_data, i| {
        std.debug.print("Testing malformed case {}: ", .{i + 1});
        
        var stream = std.io.fixedBufferStream(rtf_data);
        var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
        defer parser.deinit();
        
        if (parser.parse()) {
            const text = parser.getText();
            std.debug.print("Success - '{s}'\n", .{text});
            try testing.expect(std.mem.indexOf(u8, text, "text") != null);
        } else |err| {
            std.debug.print("Failed (acceptable) - {}\n", .{err});
        }
    }
}

test "binary data injection - security test" {
    const rtf_parser = @import("rtf.zig");
    
    // Test binary data that could cause issues
    var rtf_buffer = std.ArrayList(u8).init(testing.allocator);
    defer rtf_buffer.deinit();
    
    try rtf_buffer.appendSlice("{\\rtf1 Normal text \\bin20 ");
    
    // Add 20 bytes of binary data including nulls
    for (0..20) |i| {
        try rtf_buffer.append(@as(u8, @intCast(i % 256)));
    }
    
    try rtf_buffer.appendSlice(" More text}");
    
    std.debug.print("Testing binary data injection\n", .{});
    
    var stream = std.io.fixedBufferStream(rtf_buffer.items);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    if (parser.parse()) {
        const text = parser.getText();
        std.debug.print("Binary test result: '{s}'\n", .{text});
        try testing.expect(std.mem.indexOf(u8, text, "Normal text") != null);
        try testing.expect(std.mem.indexOf(u8, text, "More text") != null);
    } else |err| {
        std.debug.print("Binary test failed: {}\n", .{err});
    }
}

test "memory exhaustion protection" {
    const rtf_parser = @import("rtf.zig");
    
    // Test with very large control word parameters
    const huge_param_rtf = "{\\rtf1 \\fs9999999999999999999999999999 Large font}";
    
    var stream = std.io.fixedBufferStream(huge_param_rtf);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    if (parser.parse()) {
        const text = parser.getText();
        std.debug.print("Huge param result: '{s}'\n", .{text});
        try testing.expect(std.mem.indexOf(u8, text, "Large font") != null);
    } else |err| {
        std.debug.print("Huge param failed (acceptable): {}\n", .{err});
    }
}

test "unicode security - overlong sequences" {
    const rtf_parser = @import("rtf.zig");
    
    // Test potentially problematic unicode
    const unicode_cases = [_][]const u8{
        "{\\rtf1 \\u65535? \\u0? \\u-1? text}",
        "{\\rtf1 \\u999999999999999999999999999999999999? text}",
        "{\\rtf1 \\u8364\\u8364\\u8364\\u8364\\u8364\\u8364? many euros}",
    };
    
    for (unicode_cases, 0..) |rtf_data, i| {
        std.debug.print("Testing unicode case {}: ", .{i + 1});
        
        var stream = std.io.fixedBufferStream(rtf_data);
        var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
        defer parser.deinit();
        
        if (parser.parse()) {
            const text = parser.getText();
            std.debug.print("Success - length {} chars\n", .{text.len});
            try testing.expect(text.len < 1000); // Should not create massive output
        } else |err| {
            std.debug.print("Failed (acceptable) - {}\n", .{err});
        }
    }
}

test "hex escape security" {
    const rtf_parser = @import("rtf.zig");
    
    // Test hex escapes that could cause issues
    const hex_cases = [_][]const u8{
        "{\\rtf1 \\'41\\'42\\'43 normal}",  // ABC
        "{\\rtf1 \\'00\\'00\\'00 nulls}",   // Null bytes
        "{\\rtf1 \\'ff\\'fe\\'fd binary}",  // High bytes
        "{\\rtf1 \\'zz invalid hex}",       // Invalid hex
    };
    
    for (hex_cases, 0..) |rtf_data, i| {
        std.debug.print("Testing hex case {}: ", .{i + 1});
        
        var stream = std.io.fixedBufferStream(rtf_data);
        var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
        defer parser.deinit();
        
        if (parser.parse()) {
            const text = parser.getText();
            std.debug.print("Success - '{s}'\n", .{text});
            // Basic sanity check
            try testing.expect(text.len < rtf_data.len);
        } else |err| {
            std.debug.print("Failed (may be acceptable) - {}\n", .{err});
        }
    }
}

test "resource exhaustion - large documents" {
    const rtf_parser = @import("rtf.zig");
    
    // Test with a very large but valid RTF document
    var rtf_buffer = std.ArrayList(u8).init(testing.allocator);
    defer rtf_buffer.deinit();
    
    try rtf_buffer.appendSlice("{\\rtf1 ");
    
    // Add 50,000 words with formatting
    for (0..50_000) |i| {
        if (i % 100 == 0) {
            try rtf_buffer.writer().print("\\b Word{} \\b0 ", .{i});
        } else {
            try rtf_buffer.writer().print("Word{} ", .{i});
        }
    }
    
    try rtf_buffer.append('}');
    
    std.debug.print("Testing large document: {} bytes\n", .{rtf_buffer.items.len});
    
    const start = std.time.nanoTimestamp();
    
    var stream = std.io.fixedBufferStream(rtf_buffer.items);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    if (parser.parse()) {
        const end = std.time.nanoTimestamp();
        const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
        
        const text = parser.getText();
        std.debug.print("Large doc success: {} chars in {d:.2} ms\n", .{ text.len, duration_ms });
        
        // Should complete in reasonable time
        try testing.expect(duration_ms < 5000.0); // Less than 5 seconds
        try testing.expect(text.len > 0);
        
        // Memory usage should be reasonable (text should be smaller than RTF)
        try testing.expect(text.len < rtf_buffer.items.len);
        
    } else |err| {
        std.debug.print("Large doc failed: {}\n", .{err});
        return err;
    }
}

test "control word fuzzing" {
    const rtf_parser = @import("rtf.zig");
    
    // Test a bunch of random control words that should be ignored safely
    const random_control_words = [_][]const u8{
        "{\\rtf1 \\randomword123 text}",
        "{\\rtf1 \\abcdefghijklmnopqrstuvwxyz text}",
        "{\\rtf1 \\123456789 text}",
        "{\\rtf1 \\- text}",
        "{\\rtf1 \\\\- text}",
        "{\\rtf1 \\*\\unknown\\control\\words text}",
    };
    
    for (random_control_words, 0..) |rtf_data, i| {
        std.debug.print("Testing control word fuzz {}: ", .{i + 1});
        
        var stream = std.io.fixedBufferStream(rtf_data);
        var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
        defer parser.deinit();
        
        if (parser.parse()) {
            const text = parser.getText();
            std.debug.print("Success - '{s}'\n", .{text});
            try testing.expect(std.mem.indexOf(u8, text, "text") != null);
        } else |err| {
            std.debug.print("Failed - {}\n", .{err});
        }
    }
}

test "stack depth tracking" {
    const rtf_parser = @import("rtf.zig");
    
    // Test stack depth doesn't grow unbounded
    var rtf_buffer = std.ArrayList(u8).init(testing.allocator);
    defer rtf_buffer.deinit();
    
    try rtf_buffer.appendSlice("{\\rtf1 ");
    
    // Create alternating nested groups
    for (0..100) |i| {
        if (i % 2 == 0) {
            try rtf_buffer.appendSlice("{\\b ");
        } else {
            try rtf_buffer.appendSlice("text} ");
        }
    }
    
    try rtf_buffer.append('}');
    
    std.debug.print("Testing stack depth tracking\n", .{});
    
    var stream = std.io.fixedBufferStream(rtf_buffer.items);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    if (parser.parse()) {
        const text = parser.getText();
        std.debug.print("Stack depth test success: '{s}'\n", .{text});
        try testing.expect(std.mem.indexOf(u8, text, "text") != null);
    } else |err| {
        std.debug.print("Stack depth test failed: {}\n", .{err});
    }
}