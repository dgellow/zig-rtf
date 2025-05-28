const std = @import("std");
const testing = std.testing;
const doc_model = @import("document_model.zig");
const formatted_parser = @import("formatted_parser.zig");
const c_api = @import("c_api.zig");

// =============================================================================
// RTF GENERATION TESTS
// =============================================================================
// Tests for RTF generation functionality including round-trip parsing

test "basic RTF generation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a simple document
    var document = try doc_model.Document.init(allocator);
    defer document.deinit();
    
    // Add font
    try document.addFont(.{ .id = 0, .name = "Times New Roman", .family = .roman });
    
    // Add color
    try document.addColor(.{ .id = 1, .red = 255, .green = 0, .blue = 0 });
    
    // Add formatted text run
    const run = doc_model.TextRun{
        .text = "Hello, World!",
        .char_format = .{
            .bold = true,
            .italic = false,
            .underline = false,
            .font_id = 0,
            .color_id = 1,
            .font_size = 24, // 12pt
        },
        .para_format = .{},
    };
    
    try document.addElement(.{ .text_run = run });
    
    // Generate RTF
    const rtf_data = try document.generateRtf(allocator);
    defer allocator.free(rtf_data);
    
    // Should contain RTF header
    try testing.expect(std.mem.startsWith(u8, rtf_data, "{\\rtf1\\ansi\\deff0"));
    
    // Should contain font table
    try testing.expect(std.mem.indexOf(u8, rtf_data, "{\\fonttbl") != null);
    try testing.expect(std.mem.indexOf(u8, rtf_data, "Times New Roman") != null);
    
    // Should contain color table
    try testing.expect(std.mem.indexOf(u8, rtf_data, "{\\colortbl") != null);
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\red255\\green0\\blue0;") != null);
    
    // Should contain formatted text
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\b") != null); // Bold
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\fs24") != null); // Font size
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\cf1") != null); // Color
    try testing.expect(std.mem.indexOf(u8, rtf_data, "Hello, World!") != null); // Text
    
    // Should end with closing brace
    try testing.expect(std.mem.endsWith(u8, rtf_data, "}"));
}

test "RTF text escaping" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var document = try doc_model.Document.init(allocator);
    defer document.deinit();
    
    // Add text with special characters
    const run = doc_model.TextRun{
        .text = "Test\\{braces}\\and\\backslash\nNewline",
        .char_format = .{},
        .para_format = .{},
    };
    
    try document.addElement(.{ .text_run = run });
    
    const rtf_data = try document.generateRtf(allocator);
    defer allocator.free(rtf_data);
    
    // Should escape special characters
    try testing.expect(std.mem.indexOf(u8, rtf_data, "Test\\\\") != null); // Backslash
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\{braces\\}") != null); // Braces
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\line") != null); // Newline
}

test "table generation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var document = try doc_model.Document.init(allocator);
    defer document.deinit();
    
    // Create a 2x2 table
    var table = doc_model.Table.init(allocator);
    
    // First row
    var row1 = doc_model.TableRow{
        .cells = std.ArrayList(doc_model.TableCell).init(allocator),
    };
    var cell1_1 = doc_model.TableCell.init(allocator);
    cell1_1.width = 1440;
    try cell1_1.content.append(.{ .text_run = .{ .text = "Cell 1,1", .char_format = .{}, .para_format = .{} } });
    try row1.cells.append(cell1_1);
    
    var cell1_2 = doc_model.TableCell.init(allocator);
    cell1_2.width = 1440;
    try cell1_2.content.append(.{ .text_run = .{ .text = "Cell 1,2", .char_format = .{}, .para_format = .{} } });
    try row1.cells.append(cell1_2);
    try table.rows.append(row1);
    
    // Second row
    var row2 = doc_model.TableRow{
        .cells = std.ArrayList(doc_model.TableCell).init(allocator),
    };
    var cell2_1 = doc_model.TableCell.init(allocator);
    cell2_1.width = 1440;
    try cell2_1.content.append(.{ .text_run = .{ .text = "Cell 2,1", .char_format = .{}, .para_format = .{} } });
    try row2.cells.append(cell2_1);
    
    var cell2_2 = doc_model.TableCell.init(allocator);
    cell2_2.width = 1440;
    try cell2_2.content.append(.{ .text_run = .{ .text = "Cell 2,2", .char_format = .{}, .para_format = .{} } });
    try row2.cells.append(cell2_2);
    try table.rows.append(row2);
    
    try document.addElement(.{ .table = table });
    
    const rtf_data = try document.generateRtf(allocator);
    defer allocator.free(rtf_data);
    
    // Should contain table control words
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\trowd") != null); // Table row
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\cellx") != null); // Cell position
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\cell") != null); // Cell delimiter
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\row") != null); // Row end
    
    // Should contain cell text
    try testing.expect(std.mem.indexOf(u8, rtf_data, "Cell 1,1") != null);
    try testing.expect(std.mem.indexOf(u8, rtf_data, "Cell 2,2") != null);
}

test "image generation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var document = try doc_model.Document.init(allocator);
    defer document.deinit();
    
    // Create image with dummy PNG data
    const png_data = [_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }; // PNG header
    const image = doc_model.ImageInfo{
        .format = .png,
        .width = 100,
        .height = 50,
        .data = &png_data,
    };
    
    try document.addElement(.{ .image = image });
    
    const rtf_data = try document.generateRtf(allocator);
    defer allocator.free(rtf_data);
    
    // Should contain picture control words
    try testing.expect(std.mem.indexOf(u8, rtf_data, "{\\pict") != null);
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\pngblip") != null); // PNG format
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\picw100") != null); // Width
    try testing.expect(std.mem.indexOf(u8, rtf_data, "\\pich50") != null); // Height
    
    // Should contain hex-encoded data
    try testing.expect(std.mem.indexOf(u8, rtf_data, "89504e47") != null); // PNG header in hex
}

test "round-trip parsing" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create original document
    var original = try doc_model.Document.init(allocator);
    defer original.deinit();
    
    // Add font and color
    try original.addFont(.{ .id = 0, .name = "Arial", .family = .swiss });
    try original.addColor(.{ .id = 1, .red = 0, .green = 128, .blue = 255 });
    
    // Add formatted text
    const run1 = doc_model.TextRun{
        .text = "Bold text",
        .char_format = .{
            .bold = true,
            .font_id = 0,
            .color_id = 1,
            .font_size = 20,
        },
        .para_format = .{},
    };
    try original.addElement(.{ .text_run = run1 });
    
    const run2 = doc_model.TextRun{
        .text = " and italic text",
        .char_format = .{
            .italic = true,
            .font_id = 0,
        },
        .para_format = .{},
    };
    try original.addElement(.{ .text_run = run2 });
    
    // Generate RTF
    const rtf_data = try original.generateRtf(allocator);
    defer allocator.free(rtf_data);
    
    // Parse the generated RTF
    var fbs = std.io.fixedBufferStream(rtf_data);
    const reader = fbs.reader().any();
    var parser = formatted_parser.FormattedParser.init(reader, allocator);
    defer parser.deinit();
    
    var parsed = try parser.parse();
    defer parsed.deinit();
    
    // Get text runs from parsed document
    const parsed_runs = try parsed.getTextRuns(allocator);
    defer allocator.free(parsed_runs);
    
    // Verify the parsed document has content
    try testing.expect(parsed_runs.len >= 2);
    
    // Check first run (bold)
    const parsed_run1 = parsed_runs[0];
    try testing.expectEqualStrings("Bold text", parsed_run1.text);
    try testing.expect(parsed_run1.char_format.bold);
    try testing.expect(!parsed_run1.char_format.italic);
    
    // Check second run (italic)
    const parsed_run2 = parsed_runs[1];
    try testing.expectEqualStrings(" and italic text", parsed_run2.text);
    try testing.expect(!parsed_run2.char_format.bold);
    try testing.expect(parsed_run2.char_format.italic);
}

test "C API RTF generation" {
    // Test the C API generation functions
    const simple_rtf = "{\\rtf1\\ansi Simple text}";
    
    // Parse RTF using C API
    const doc = c_api.rtf_parse(simple_rtf.ptr, simple_rtf.len);
    try testing.expect(doc != null);
    defer c_api.rtf_free(doc);
    
    // Generate RTF back
    const generated = c_api.rtf_generate(doc);
    try testing.expect(generated != null);
    defer c_api.rtf_free_string(generated);
    
    // Should contain RTF header
    const generated_str = std.mem.span(generated.?);
    try testing.expect(std.mem.startsWith(u8, generated_str, "{\\rtf1\\ansi"));
    try testing.expect(std.mem.endsWith(u8, generated_str, "}"));
    try testing.expect(std.mem.indexOf(u8, generated_str, "Simple text") != null);
}