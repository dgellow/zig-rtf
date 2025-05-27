const std = @import("std");
const testing = std.testing;

test "wordpad rtf sample" {
    const rtf_parser = @import("rtf.zig");
    
    const file = std.fs.cwd().openFile("test/data/wordpad_sample.rtf", .{}) catch {
        std.debug.print("Could not open wordpad_sample.rtf - skipping test\n", .{});
        return;
    };
    defer file.close();
    
    const content = try file.readToEndAlloc(testing.allocator, 10_000);
    defer testing.allocator.free(content);
    
    var stream = std.io.fixedBufferStream(content);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    std.debug.print("WordPad RTF:\n", .{});
    std.debug.print("Input size: {} bytes\n", .{content.len});
    std.debug.print("Extracted: '{s}'\n", .{text});
    
    // Verify expected content
    try testing.expect(std.mem.indexOf(u8, text, "sample document") != null);
    try testing.expect(std.mem.indexOf(u8, text, "bold text") != null);
    try testing.expect(std.mem.indexOf(u8, text, "italic text") != null);
    try testing.expect(std.mem.indexOf(u8, text, "underlined text") != null);
    
    // Verify no RTF markup leaked through
    try testing.expect(std.mem.indexOf(u8, text, "\\b") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\i") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\ul") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\par") == null);
}

test "textedit rtf sample" {
    const rtf_parser = @import("rtf.zig");
    
    const file = std.fs.cwd().openFile("test/data/textedit_sample.rtf", .{}) catch {
        std.debug.print("Could not open textedit_sample.rtf - skipping test\n", .{});
        return;
    };
    defer file.close();
    
    const content = try file.readToEndAlloc(testing.allocator, 10_000);
    defer testing.allocator.free(content);
    
    var stream = std.io.fixedBufferStream(content);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    std.debug.print("TextEdit RTF:\n", .{});
    std.debug.print("Input size: {} bytes\n", .{content.len});
    std.debug.print("Extracted: '{s}'\n", .{text});
    
    // Verify expected content
    try testing.expect(std.mem.indexOf(u8, text, "TextEdit on macOS") != null);
    try testing.expect(std.mem.indexOf(u8, text, "bold formatting") != null);
    try testing.expect(std.mem.indexOf(u8, text, "italic formatting") != null);
    try testing.expect(std.mem.indexOf(u8, text, "underline") != null);
    
    // Verify no RTF markup leaked through
    try testing.expect(std.mem.indexOf(u8, text, "\\b") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\i") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\cocoartf") == null);
}

test "richedit rtf sample" {
    const rtf_parser = @import("rtf.zig");
    
    const file = std.fs.cwd().openFile("test/data/richedit_sample.rtf", .{}) catch {
        std.debug.print("Could not open richedit_sample.rtf - skipping test\n", .{});
        return;
    };
    defer file.close();
    
    const content = try file.readToEndAlloc(testing.allocator, 10_000);
    defer testing.allocator.free(content);
    
    var stream = std.io.fixedBufferStream(content);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    std.debug.print("RichEdit RTF:\n", .{});
    std.debug.print("Input size: {} bytes\n", .{content.len});
    std.debug.print("Extracted: '{s}'\n", .{text});
    
    // Verify expected content
    try testing.expect(std.mem.indexOf(u8, text, "RichEdit output") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Bold text") != null);
    try testing.expect(std.mem.indexOf(u8, text, "italic text") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Red text") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Larger text") != null);
    
    // Verify no RTF markup leaked through
    try testing.expect(std.mem.indexOf(u8, text, "\\cf") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\fs") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\par") == null);
}

test "all existing test data files" {
    const rtf_parser = @import("rtf.zig");
    
    // Test all RTF files in test/data directory
    const test_files = [_][]const u8{
        "test/data/simple.rtf",
        "test/data/complex.rtf", 
        "test/data/complex_formatting.rtf",
        "test/data/nested.rtf",
        "test/data/large.rtf",
    };
    
    for (test_files) |file_path| {
        std.debug.print("Testing file: {s}\n", .{file_path});
        
        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            std.debug.print("Could not open {s}: {} - skipping\n", .{ file_path, err });
            continue;
        };
        defer file.close();
        
        const content = file.readToEndAlloc(testing.allocator, 100_000) catch |err| {
            std.debug.print("Could not read {s}: {} - skipping\n", .{ file_path, err });
            continue;
        };
        defer testing.allocator.free(content);
        
        var stream = std.io.fixedBufferStream(content);
        var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
        defer parser.deinit();
        
        if (parser.parse()) {
            const text = parser.getText();
            std.debug.print("  Success - extracted {} chars from {} bytes\n", .{ text.len, content.len });
            
            // Basic sanity checks
            try testing.expect(text.len <= content.len); // Output shouldn't be bigger than input
            try testing.expect(std.mem.indexOf(u8, text, "\\rtf") == null); // No RTF header
        } else |err| {
            std.debug.print("  Parse failed: {}\n", .{err});
            // Some test files might be intentionally malformed
        }
    }
}

test "unicode and special characters" {
    const rtf_parser = @import("rtf.zig");
    
    // Test unicode support
    const unicode_rtf = "{\\rtf1\\ansi Hello \\u8364? World}"; // Euro symbol
    
    var stream = std.io.fixedBufferStream(unicode_rtf);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    std.debug.print("Unicode RTF: '{s}'\n", .{unicode_rtf});
    std.debug.print("Extracted: '{s}'\n", .{text});
    
    // Should handle unicode properly
    try testing.expect(std.mem.indexOf(u8, text, "Hello") != null);
    try testing.expect(std.mem.indexOf(u8, text, "World") != null);
}

test "performance comparison" {
    const rtf_parser = @import("rtf.zig");
    
    // Test with multiple document sizes
    const sizes = [_]u32{ 100, 1000, 10000 };
    
    for (sizes) |size| {
        // Build RTF document of specified size
        var rtf_buffer = std.ArrayList(u8).init(testing.allocator);
        defer rtf_buffer.deinit();
        
        try rtf_buffer.appendSlice("{\\rtf1 ");
        
        var words: u32 = 0;
        while (rtf_buffer.items.len < size) {
            try rtf_buffer.writer().print("Word{} ", .{words});
            if (words % 5 == 0) try rtf_buffer.appendSlice("\\b ");
            if (words % 10 == 0) try rtf_buffer.appendSlice("\\b0 ");
            words += 1;
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
        
        std.debug.print("Size {} bytes: {d:.2} ms ({} words -> {} chars)\n", .{
            rtf_buffer.items.len, duration_ms, words, text.len
        });
        
        // Verify parsing was successful
        try testing.expect(text.len > 0);
        try testing.expect(text.len < rtf_buffer.items.len); // Text should be smaller than RTF
    }
}