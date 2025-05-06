const std = @import("std");
const testing = std.testing;
const ByteStream = @import("byte_stream.zig").ByteStream;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Style = @import("parser.zig").Style;
const EventHandler = @import("parser.zig").EventHandler;

test "Parser - initialization" {
    const content = "Hello, World!";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    const handler = EventHandler.init();
    var parser = try Parser.init(&tokenizer, testing.allocator, handler);
    defer parser.deinit();
    
    try testing.expect(parser.tokenizer == &tokenizer);
}

test "Parser - simple text processing" {
    const content = "Hello, World!";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    // Use global variables for callback access
    var text_result = std.ArrayList(u8).init(testing.allocator);
    defer text_result.deinit();
    var style_bold = false;
    
    // Use function pointer for callback
    fn onTextCallback(text: []const u8, style: Style) !void {
        try text_result.appendSlice(text);
        style_bold = style.bold;
    }
    
    const handler = EventHandler{
        .onGroupStart = null,
        .onGroupEnd = null,
        .onText = onTextCallback,
        .onCharacter = null,
        .onError = null,
    };
    
    var parser = try Parser.init(&tokenizer, testing.allocator, handler);
    defer parser.deinit();
    
    try parser.parse();
    
    try testing.expectEqualStrings("Hello, World!", text_result.items);
    try testing.expectEqual(false, style_bold);
}

test "Parser - style handling" {
    const content = "{\\rtf1\\ansi{\\b Hello} World!}";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    // Global storage for test results
    var texts_global = std.ArrayList([]const u8).init(testing.allocator);
    defer {
        for (texts_global.items) |text| {
            testing.allocator.free(text);
        }
        texts_global.deinit();
    }
    
    var styles_global = std.ArrayList(Style).init(testing.allocator);
    defer styles_global.deinit();
    
    // Callback function to capture text and style
    fn onTextCallback(text: []const u8, style: Style) !void {
        const text_copy = try testing.allocator.dupe(u8, text);
        try texts_global.append(text_copy);
        try styles_global.append(style);
    }
    
    const handler = EventHandler{
        .onGroupStart = null,
        .onGroupEnd = null,
        .onText = onTextCallback,
        .onCharacter = null,
        .onError = null,
    };
    
    var parser = try Parser.init(&tokenizer, testing.allocator, handler);
    defer parser.deinit();
    
    try parser.parse();
    
    // We should have captured two text segments
    try testing.expectEqual(@as(usize, 2), texts_global.items.len);
    try testing.expectEqual(@as(usize, 2), styles_global.items.len);
    
    // First text should be "Hello" with bold style
    try testing.expectEqualStrings(" Hello", texts_global.items[0]);
    try testing.expectEqual(true, styles_global.items[0].bold);
    
    // Second text should be " World!" with normal style
    try testing.expectEqualStrings(" World!", texts_global.items[1]);
    try testing.expectEqual(false, styles_global.items[1].bold);
}