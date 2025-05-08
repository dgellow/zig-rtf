const std = @import("std");
const testing = std.testing;
const Document = @import("document_improved.zig").Document;
const Style = @import("parser.zig").Style;
const ElementType = @import("document_improved.zig").ElementType;
const ListType = @import("document_improved.zig").ListType;
const ImageFormat = @import("document_improved.zig").ImageFormat;
const FieldType = @import("document_improved.zig").FieldType;

test "Document basic creation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    try testing.expectEqual(@as(usize, 0), doc.content.items.len);
}

test "Document paragraph creation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a paragraph
    const paragraph = try doc.createParagraph();
    try testing.expectEqual(@as(usize, 1), doc.content.items.len);
    try testing.expectEqual(ElementType.PARAGRAPH, doc.content.items[0].type);
    
    // Add some text to the paragraph
    const style = Style{ .bold = true };
    _ = try paragraph.createTextRun(allocator, "Hello, World!", style);
    try testing.expectEqual(@as(usize, 1), paragraph.content.items.len);
    
    const text_run = try paragraph.content.items[0].as(
        @import("document_improved.zig").TextRun
    );
    try testing.expectEqualStrings("Hello, World!", text_run.text);
    try testing.expect(text_run.style.bold);
}

test "Document table creation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a simple table
    const Table = @import("document_improved.zig").Table;
    const table = try Table.createSimpleTable(allocator, 2, 3);
    try doc.addElement(&table.element);
    
    try testing.expectEqual(@as(usize, 1), doc.content.items.len);
    try testing.expectEqual(ElementType.TABLE, doc.content.items[0].type);
    
    // Verify table dimensions
    try testing.expectEqual(@as(usize, 2), table.rows.items.len);
    try testing.expectEqual(@as(usize, 3), table.rows.items[0].cells.items.len);
    try testing.expectEqual(@as(usize, 3), table.rows.items[1].cells.items.len);
    
    // Add content to a cell
    const cell = table.rows.items[0].cells.items[0];
    const paragraph = try cell.createParagraph(allocator);
    _ = try paragraph.createTextRun(allocator, "Cell content", .{});
    
    // Test accessing a cell through path
    if (try doc.findElement(&[_]usize{0, 0, 0, 0, 0})) |elem| {
        const found_text_run = try elem.as(@import("document_improved.zig").TextRun);
        try testing.expectEqualStrings("Cell content", found_text_run.text);
    } else {
        try testing.expect(false); // Element should be found
    }
}

test "Document hyperlink" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a paragraph with a hyperlink
    const paragraph = try doc.createParagraph();
    const hyperlink = try paragraph.createHyperlink(allocator, "https://example.com");
    _ = try hyperlink.createTextRun(allocator, "Visit Example", .{ .bold = true });
    
    // Verify structure
    try testing.expectEqual(@as(usize, 1), doc.content.items.len);
    try testing.expectEqual(@as(usize, 1), paragraph.content.items.len);
    try testing.expectEqual(ElementType.HYPERLINK, paragraph.content.items[0].type);
    
    const Hyperlink = @import("document_improved.zig").Hyperlink;
    const found_hyperlink = try paragraph.content.items[0].as(Hyperlink);
    try testing.expectEqualStrings("https://example.com", found_hyperlink.url);
    try testing.expectEqual(@as(usize, 1), found_hyperlink.content.items.len);
    
    // Update the URL
    try found_hyperlink.setUrl(allocator, "https://updated-example.com");
    try testing.expectEqualStrings("https://updated-example.com", found_hyperlink.url);
}

test "Document nested formatting" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create paragraph with multiple styled text runs
    const paragraph = try doc.createParagraph();
    
    // Regular text
    _ = try paragraph.createTextRun(allocator, "Normal text. ", .{});
    
    // Bold text
    _ = try paragraph.createTextRun(allocator, "Bold text. ", .{ .bold = true });
    
    // Italic text
    _ = try paragraph.createTextRun(allocator, "Italic text. ", .{ .italic = true });
    
    // Bold and italic text
    _ = try paragraph.createTextRun(allocator, "Bold and italic.", .{ .bold = true, .italic = true });
    
    try testing.expectEqual(@as(usize, 4), paragraph.content.items.len);
    
    // Test HTML output (indirectly test the styling)
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    try doc.toHtml(buffer.writer());
    
    const html = buffer.items;
    try testing.expect(std.mem.indexOf(u8, html, "<strong>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<em>") != null);
}

test "Document list creation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a bullet list
    const list = try doc.createList(ListType.BULLET);
    
    // Add list items
    const item1 = try list.createItem(allocator);
    _ = try item1.createTextRun(allocator, "First item", .{});
    
    const item2 = try list.createItem(allocator);
    _ = try item2.createTextRun(allocator, "Second item", .{});
    
    const item3 = try list.createItem(allocator);
    item3.level = 2; // Nest this item
    _ = try item3.createTextRun(allocator, "Nested item", .{});
    
    try testing.expectEqual(@as(usize, 1), doc.content.items.len);
    try testing.expectEqual(ElementType.LIST, doc.content.items[0].type);
    
    const List = @import("document_improved.zig").List;
    const found_list = try doc.content.items[0].as(List);
    try testing.expectEqual(ListType.BULLET, found_list.list_type);
    try testing.expectEqual(@as(usize, 3), found_list.items.items.len);
    try testing.expectEqual(@as(u8, 2), found_list.items.items[2].level);
}

test "Document from plain text" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    const plain_text = 
        \\First paragraph with some text.
        \\
        \\Second paragraph after a blank line.
        \\This is still part of the second paragraph.
        \\
        \\Third paragraph.
    ;
    
    var doc = try Document.createFromPlainText(allocator, plain_text);
    defer doc.deinit();
    
    try testing.expectEqual(@as(usize, 3), doc.content.items.len);
    
    // Check that each paragraph has the correct content
    const Paragraph = @import("document_improved.zig").Paragraph;
    const TextRun = @import("document_improved.zig").TextRun;
    
    const para1 = try doc.content.items[0].as(Paragraph);
    try testing.expectEqual(@as(usize, 1), para1.content.items.len);
    const text1 = try para1.content.items[0].as(TextRun);
    try testing.expectEqualStrings("First paragraph with some text.", text1.text);
    
    const para2 = try doc.content.items[1].as(Paragraph);
    try testing.expectEqual(@as(usize, 2), para2.content.items.len);
    
    const para3 = try doc.content.items[2].as(Paragraph);
    try testing.expectEqual(@as(usize, 1), para3.content.items.len);
    const text3 = try para3.content.items[0].as(TextRun);
    try testing.expectEqualStrings("Third paragraph.", text3.text);
}

test "Document element removal" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a few paragraphs
    const para1 = try doc.createParagraph();
    _ = try para1.createTextRun(allocator, "Paragraph 1", .{});
    
    const para2 = try doc.createParagraph();
    _ = try para2.createTextRun(allocator, "Paragraph 2", .{});
    
    const para3 = try doc.createParagraph();
    _ = try para3.createTextRun(allocator, "Paragraph 3", .{});
    
    try testing.expectEqual(@as(usize, 3), doc.content.items.len);
    
    // Remove the middle paragraph
    try doc.removeElement(&para2.element);
    
    try testing.expectEqual(@as(usize, 2), doc.content.items.len);
    
    // Verify remaining paragraphs
    const TextRun = @import("document_improved.zig").TextRun;
    
    const found_para1 = try doc.content.items[0].as(@import("document_improved.zig").Paragraph);
    const text1 = try found_para1.content.items[0].as(TextRun);
    try testing.expectEqualStrings("Paragraph 1", text1.text);
    
    const found_para3 = try doc.content.items[1].as(@import("document_improved.zig").Paragraph);
    const text3 = try found_para3.content.items[0].as(TextRun);
    try testing.expectEqualStrings("Paragraph 3", text3.text);
}

test "Document image creation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a paragraph
    const paragraph = try doc.createParagraph();
    
    // Add an image
    const image_data = [_]u8{0, 1, 2, 3, 4}; // Fake image data
    const image = try paragraph.createImage(allocator, 100, 200, ImageFormat.JPEG, &image_data);
    
    try testing.expectEqual(@as(usize, 1), paragraph.content.items.len);
    try testing.expectEqual(ElementType.IMAGE, paragraph.content.items[0].type);
    
    try testing.expectEqual(@as(u16, 100), image.image_data.width);
    try testing.expectEqual(@as(u16, 200), image.image_data.height);
    try testing.expectEqual(ImageFormat.JPEG, image.image_data.format);
    try testing.expectEqual(@as(usize, 5), image.image_data.data.len);
    
    // Update image data
    const new_image_data = [_]u8{5, 6, 7, 8, 9, 10}; // New fake image data
    try image.updateImageData(allocator, 150, 250, ImageFormat.PNG, &new_image_data);
    
    try testing.expectEqual(@as(u16, 150), image.image_data.width);
    try testing.expectEqual(@as(u16, 250), image.image_data.height);
    try testing.expectEqual(ImageFormat.PNG, image.image_data.format);
    try testing.expectEqual(@as(usize, 6), image.image_data.data.len);
}

test "Document field creation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a paragraph
    const paragraph = try doc.createParagraph();
    
    // Add a date field
    const field = try paragraph.createField(allocator, FieldType.DATE, "\\date");
    
    try testing.expectEqual(@as(usize, 1), paragraph.content.items.len);
    try testing.expectEqual(ElementType.FIELD, paragraph.content.items[0].type);
    
    try testing.expectEqual(FieldType.DATE, field.field_type);
    try testing.expectEqualStrings("\\date", field.instructions);
    try testing.expect(field.result == null);
    
    // Set field result
    try field.setResult(allocator, "May 8, 2025");
    try testing.expectEqualStrings("May 8, 2025", field.result.?);
    
    // Update field instructions
    try field.setInstructions(allocator, "\\date \\@ \"MMMM d, yyyy\"");
    try testing.expectEqualStrings("\\date \\@ \"MMMM d, yyyy\"", field.instructions);
}

test "Document element type checking" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create different element types
    const paragraph = try doc.createParagraph();
    const table = try doc.createTable();
    
    // Try correct type casting
    _ = try paragraph.element.as(@import("document_improved.zig").Paragraph);
    _ = try table.element.as(@import("document_improved.zig").Table);
    
    // Try incorrect type casting (should fail)
    const DocumentError = @import("document_improved.zig").DocumentError;
    try testing.expectError(DocumentError.InvalidElementType, paragraph.element.as(@import("document_improved.zig").Table));
    try testing.expectError(DocumentError.InvalidElementType, table.element.as(@import("document_improved.zig").Paragraph));
}

test "Document parent-child relationships" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a table with nested elements
    const table = try doc.createTable();
    const row = try table.createRow(allocator);
    const cell = try row.createCell(allocator);
    const paragraph = try cell.createParagraph(allocator);
    const text_run = try paragraph.createTextRun(allocator, "Nested content", .{});
    
    // Check parent relationships
    try testing.expect(table.element.parent == null); // Top-level element has no parent
    try testing.expect(row.element.parent == &table.element);
    try testing.expect(cell.element.parent == &row.element);
    try testing.expect(paragraph.element.parent == &cell.element);
    try testing.expect(text_run.element.parent == &paragraph.element);
}

test "Document HTML escaping" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a paragraph with text containing HTML special characters
    const paragraph = try doc.createParagraph();
    _ = try paragraph.createTextRun(allocator, "<script>alert('XSS');</script> & other \"special\" chars", .{});
    
    // Generate HTML and check escaping
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    try doc.toHtml(buffer.writer());
    
    const html = buffer.items;
    try testing.expect(std.mem.indexOf(u8, html, "&lt;script&gt;alert(&#39;XSS&#39;);&lt;/script&gt; &amp; other &quot;special&quot; chars") != null);
    try testing.expect(std.mem.indexOf(u8, html, "<script>alert") == null); // Shouldn't contain unescaped script
}

test "Document paragraph properties" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a paragraph with custom properties
    const paragraph = try doc.createParagraph();
    
    var props = @import("document_improved.zig").ParagraphProperties{
        .alignment = .center,
        .space_before = 240, // 12pt
        .space_after = 240,  // 12pt
    };
    props.setIndents(24, 48, 48); // 24pt first line, 48pt left/right
    
    paragraph.applyProperties(props);
    
    try testing.expectEqual(@import("document_improved.zig").Alignment.center, paragraph.properties.alignment);
    try testing.expectEqual(@as(?u16, 240), paragraph.properties.space_before);
    try testing.expectEqual(@as(?i16, 480), paragraph.properties.first_line_indent); // 24pt * 20
    try testing.expectEqual(@as(?i16, 960), paragraph.properties.left_indent); // 48pt * 20
    
    // Reset properties
    paragraph.resetProperties();
    try testing.expectEqual(@import("document_improved.zig").Alignment.left, paragraph.properties.alignment);
    try testing.expect(paragraph.properties.space_before == null);
}

test "Document simple text joining" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    
    // Create a document with some paragraph text
    var doc = Document.init(allocator);
    defer doc.deinit();
    
    // Create a paragraph with plain text followed by formatted text
    const para1 = try doc.createParagraphWithText("Hello ", .{});
    _ = try para1.createTextRun(allocator, "World", .{ .bold = true });
    _ = try para1.createTextRun(allocator, "!", .{});
    
    // Convert to plain text to check
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();
    
    try doc.toPlainText(output.writer());
    
    const expected = "Hello World!\n";
    try testing.expectEqualStrings(expected, output.items);
}