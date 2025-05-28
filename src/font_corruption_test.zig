const std = @import("std");
const formatted_parser = @import("formatted_parser.zig");

test "font name memory corruption isolation" {
    const testing = std.testing;
    
    // Simple RTF with two fonts
    const rtf_data = "{\\rtf1 {\\fonttbl{\\f0 Arial;}{\\f1 Times;}}Test}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = formatted_parser.FormattedParser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    var document = try parser.parse();
    defer document.deinit();
    
    // Check fonts immediately after parsing
    try testing.expectEqual(@as(usize, 2), document.font_table.items.len);
    
    const font0 = document.font_table.items[0];
    const font1 = document.font_table.items[1];
    
    std.debug.print("Font 0: id={} name='{s}' ptr={*}\n", .{font0.id, font0.name, font0.name.ptr});
    std.debug.print("Font 1: id={} name='{s}' ptr={*}\n", .{font1.id, font1.name, font1.name.ptr});
    
    // Store copies of the names
    const font0_name_copy = try testing.allocator.dupe(u8, font0.name);
    defer testing.allocator.free(font0_name_copy);
    const font1_name_copy = try testing.allocator.dupe(u8, font1.name);
    defer testing.allocator.free(font1_name_copy);
    
    // Check fonts are still valid
    try testing.expectEqualStrings("Arial", font0_name_copy);
    try testing.expectEqualStrings("Times", font1_name_copy);
    
    // Now check if the font names in the document are still valid
    try testing.expectEqualStrings("Arial", document.font_table.items[0].name);
    try testing.expectEqualStrings("Times", document.font_table.items[1].name);
    
    // Also check via getFont
    if (document.getFont(0)) |f0| {
        std.debug.print("getFont(0): name='{s}' ptr={*}\n", .{f0.name, f0.name.ptr});
        try testing.expectEqualStrings("Arial", f0.name);
    }
    if (document.getFont(1)) |f1| {
        std.debug.print("getFont(1): name='{s}' ptr={*}\n", .{f1.name, f1.name.ptr});
        try testing.expectEqualStrings("Times", f1.name);
    }
}