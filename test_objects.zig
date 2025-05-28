const std = @import("std");
const rtf = @import("src/formatted_parser.zig");
const doc_model = @import("src/document_model.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Read the RTF file with objects
    const file = try std.fs.cwd().openFile("test/data/rtf_with_objects.rtf", .{});
    defer file.close();
    
    var parser = rtf.FormattedParser.init(file.reader().any(), allocator);
    defer parser.deinit();
    
    const document = try parser.parse();
    
    std.debug.print("Document parsed successfully!\n", .{});
    std.debug.print("Number of elements: {}\n", .{document.content.items.len});
    
    // Print all elements
    for (document.content.items, 0..) |element, i| {
        switch (element) {
            .text_run => |run| {
                std.debug.print("Element {}: Text run: '{s}'\n", .{i, run.text});
            },
            .paragraph_break => {
                std.debug.print("Element {}: Paragraph break\n", .{i});
            },
            .line_break => {
                std.debug.print("Element {}: Line break\n", .{i});
            },
            .page_break => {
                std.debug.print("Element {}: Page break\n", .{i});
            },
            .image => |img| {
                std.debug.print("Element {}: Image/Object - format: {}, size: {}x{}, data_len: {}\n", 
                    .{i, img.format, img.width, img.height, img.data.len});
            },
            .table => |tbl| {
                std.debug.print("Element {}: Table with {} rows\n", .{i, tbl.rows.items.len});
            },
            .hyperlink => |link| {
                std.debug.print("Element {}: Hyperlink to '{s}'\n", .{i, link.url});
            },
        }
    }
}