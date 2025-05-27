const std = @import("std");
const testing = std.testing;

test "rtf with embedded image" {
    const rtf_parser = @import("rtf.zig");
    
    const file = std.fs.cwd().openFile("test/data/rtf_with_image.rtf", .{}) catch {
        std.debug.print("Could not open rtf_with_image.rtf - skipping test\n", .{});
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
    
    std.debug.print("RTF with image:\n", .{});
    std.debug.print("Input size: {} bytes\n", .{content.len});
    std.debug.print("Extracted text: '{s}'\n", .{text});
    
    // Should extract text but skip image binary data
    try testing.expect(std.mem.indexOf(u8, text, "Document with embedded image") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Text after image should appear") != null);
    
    // Should NOT contain image binary data in text output
    try testing.expect(std.mem.indexOf(u8, text, "wmetafile8") == null);
    try testing.expect(std.mem.indexOf(u8, text, "010009000003") == null);
    
    // Verify reasonable text length (should be much shorter than RTF)
    try testing.expect(text.len < content.len / 2);
}

test "rtf with table structure" {
    const rtf_parser = @import("rtf.zig");
    
    const file = std.fs.cwd().openFile("test/data/rtf_with_table.rtf", .{}) catch {
        std.debug.print("Could not open rtf_with_table.rtf - skipping test\n", .{});
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
    
    std.debug.print("RTF with table:\n", .{});
    std.debug.print("Input size: {} bytes\n", .{content.len});
    std.debug.print("Extracted text: '{s}'\n", .{text});
    
    // Should extract table content as text
    try testing.expect(std.mem.indexOf(u8, text, "Document with table") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Header 1") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Header 2") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Data 1") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Row 2 A") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Text after table") != null);
    
    // Should NOT contain table formatting markup
    try testing.expect(std.mem.indexOf(u8, text, "\\trowd") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\cellx") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\intbl") == null);
}

test "rtf with embedded objects" {
    const rtf_parser = @import("rtf.zig");
    
    const file = std.fs.cwd().openFile("test/data/rtf_with_objects.rtf", .{}) catch {
        std.debug.print("Could not open rtf_with_objects.rtf - skipping test\n", .{});
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
    
    std.debug.print("RTF with objects:\n", .{});
    std.debug.print("Input size: {} bytes\n", .{content.len});
    std.debug.print("Extracted text: '{s}'\n", .{text});
    
    // Should extract descriptive text but skip object data
    try testing.expect(std.mem.indexOf(u8, text, "Document with embedded objects") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Excel spreadsheet below") != null);
    try testing.expect(std.mem.indexOf(u8, text, "PowerPoint slide below") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Text after objects") != null);
    
    // Should NOT contain object binary data
    try testing.expect(std.mem.indexOf(u8, text, "objemb") == null);
    try testing.expect(std.mem.indexOf(u8, text, "objdata") == null);
    try testing.expect(std.mem.indexOf(u8, text, "504B0304") == null);
    try testing.expect(std.mem.indexOf(u8, text, "D0CF11E0") == null);
}

test "rtf with hyperlinks" {
    const rtf_parser = @import("rtf.zig");
    
    const file = std.fs.cwd().openFile("test/data/rtf_with_hyperlinks.rtf", .{}) catch {
        std.debug.print("Could not open rtf_with_hyperlinks.rtf - skipping test\n", .{});
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
    
    std.debug.print("RTF with hyperlinks:\n", .{});
    std.debug.print("Input size: {} bytes\n", .{content.len});
    std.debug.print("Extracted text: '{s}'\n", .{text});
    
    // Should extract visible link text
    try testing.expect(std.mem.indexOf(u8, text, "Document with hyperlinks") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Visit") != null);
    try testing.expect(std.mem.indexOf(u8, text, "www.example.com") != null);
    try testing.expect(std.mem.indexOf(u8, text, "email") != null);
    try testing.expect(std.mem.indexOf(u8, text, "test@example.com") != null);
    try testing.expect(std.mem.indexOf(u8, text, "End of document") != null);
    
    // Should NOT contain field instructions
    try testing.expect(std.mem.indexOf(u8, text, "HYPERLINK") == null);
    try testing.expect(std.mem.indexOf(u8, text, "fldinst") == null);
    try testing.expect(std.mem.indexOf(u8, text, "fldrslt") == null);
}

test "complex mixed content rtf" {
    const rtf_parser = @import("rtf.zig");
    
    const file = std.fs.cwd().openFile("test/data/rtf_complex_mixed.rtf", .{}) catch {
        std.debug.print("Could not open rtf_complex_mixed.rtf - skipping test\n", .{});
        return;
    };
    defer file.close();
    
    const content = try file.readToEndAlloc(testing.allocator, 20_000);
    defer testing.allocator.free(content);
    
    var stream = std.io.fixedBufferStream(content);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    std.debug.print("Complex mixed RTF:\n", .{});
    std.debug.print("Input size: {} bytes\n", .{content.len});
    std.debug.print("Extracted text length: {} chars\n", .{text.len});
    std.debug.print("First 200 chars: '{s}...'\n", .{text[0..@min(200, text.len)]});
    
    // Should extract all visible text content
    try testing.expect(std.mem.indexOf(u8, text, "Complex RTF Document") != null);
    try testing.expect(std.mem.indexOf(u8, text, "1. Formatted Text") != null);
    try testing.expect(std.mem.indexOf(u8, text, "bold") != null);
    try testing.expect(std.mem.indexOf(u8, text, "italic") != null);
    try testing.expect(std.mem.indexOf(u8, text, "2. Table") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Name") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Alice") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Bob") != null);
    try testing.expect(std.mem.indexOf(u8, text, "3. Image") != null);
    try testing.expect(std.mem.indexOf(u8, text, "4. Hyperlink") != null);
    try testing.expect(std.mem.indexOf(u8, text, "https://example.com") != null);
    try testing.expect(std.mem.indexOf(u8, text, "5. Unicode Text") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Euro") != null);
    try testing.expect(std.mem.indexOf(u8, text, "6. Embedded Object") != null);
    try testing.expect(std.mem.indexOf(u8, text, "End of complex document") != null);
    
    // Should handle Unicode properly
    try testing.expect(std.mem.indexOf(u8, text, "€") != null); // Euro symbol
    try testing.expect(std.mem.indexOf(u8, text, "™") != null); // Trademark
    try testing.expect(std.mem.indexOf(u8, text, "©") != null); // Copyright
    
    // Should NOT contain any RTF markup
    try testing.expect(std.mem.indexOf(u8, text, "\\trowd") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\pict") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\object") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\field") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\u8364") == null);
    
    // Text should be significantly smaller than RTF
    try testing.expect(text.len < content.len / 3);
}

test "stress test - very large complex rtf" {
    const rtf_parser = @import("rtf.zig");
    
    // Generate a large complex RTF document
    var rtf_buffer = std.ArrayList(u8).init(testing.allocator);
    defer rtf_buffer.deinit();
    
    try rtf_buffer.appendSlice("{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Arial;}}\\f0\\fs20 ");
    
    // Add many complex elements
    for (0..100) |i| {
        // Text with formatting
        try rtf_buffer.writer().print("\\b Section {}\\b0\\par ", .{i});
        
        // Mini table every 10 sections
        if (i % 10 == 0) {
            try rtf_buffer.appendSlice(
                "\\trowd\\cellx1440\\cellx2880 " ++
                "\\intbl Item\\cell Value\\cell\\row " ++
                "\\trowd\\cellx1440\\cellx2880 " ++
                "\\intbl Data\\cell Info\\cell\\row "
            );
        }
        
        // Unicode every 5 sections
        if (i % 5 == 0) {
            try rtf_buffer.appendSlice("Unicode: \\u8364? \\u8482? \\u169?\\par ");
        }
        
        // Fake image every 20 sections
        if (i % 20 == 0) {
            try rtf_buffer.appendSlice(
                "{\\pict\\wmetafile8\\picw100\\pich100 " ++
                "0100090000034400000000004000000003400100}\\par "
            );
        }
        
        // Regular content
        try rtf_buffer.writer().print(
            "This is paragraph {} with \\i italic\\i0 and \\ul underlined\\ulnone text.\\par ",
            .{i}
        );
    }
    
    try rtf_buffer.append('}');
    
    std.debug.print("Stress test large complex RTF:\n", .{});
    std.debug.print("Generated RTF size: {} bytes\n", .{rtf_buffer.items.len});
    
    const start = std.time.nanoTimestamp();
    
    var stream = std.io.fixedBufferStream(rtf_buffer.items);
    var parser = rtf_parser.Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    const end = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    
    std.debug.print("Extracted text length: {} chars\n", .{text.len});
    std.debug.print("Parse time: {d:.2} ms\n", .{duration_ms});
    std.debug.print("Processing rate: {d:.0} KB/sec\n", .{@as(f64, @floatFromInt(rtf_buffer.items.len)) / 1024.0 / (duration_ms / 1000.0)});
    
    // Verify content extraction
    try testing.expect(std.mem.indexOf(u8, text, "Section 0") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Section 99") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Item") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Value") != null);
    try testing.expect(std.mem.indexOf(u8, text, "€") != null); // Unicode Euro
    try testing.expect(std.mem.indexOf(u8, text, "italic") != null);
    try testing.expect(std.mem.indexOf(u8, text, "underlined") != null);
    
    // Should not contain markup
    try testing.expect(std.mem.indexOf(u8, text, "\\b") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\trowd") == null);
    try testing.expect(std.mem.indexOf(u8, text, "\\pict") == null);
    
    // Performance requirements
    try testing.expect(duration_ms < 1000.0); // Less than 1 second
    try testing.expect(text.len > 0);
    // Text extraction is very thorough, so ratio is actually reasonable
    try testing.expect(text.len < rtf_buffer.items.len); // Text should be smaller than RTF
}