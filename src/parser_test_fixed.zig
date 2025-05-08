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

// Global variables for simple test
var text_result: []u8 = undefined;
var style_is_bold: bool = false;

fn onTextCallbackSimple(ctx: *anyopaque, text: []const u8, style: Style) !void {
    _ = ctx; // Ignore context
    text_result = testing.allocator.dupe(u8, text) catch unreachable;
    style_is_bold = style.bold;
}

test "Parser - simple text processing" {
    const content = "Hello, World!";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    const handler = EventHandler{
        .onGroupStart = null,
        .onGroupEnd = null,
        .onText = onTextCallbackSimple,
        .onCharacter = null,
        .onError = null,
    };
    
    var parser = try Parser.init(&tokenizer, testing.allocator, handler);
    defer parser.deinit();
    
    try parser.parse();
    defer testing.allocator.free(text_result);
    
    try testing.expectEqualStrings("Hello, World!", text_result);
    try testing.expectEqual(false, style_is_bold);
}

// Global variables for style test
var texts: std.ArrayList([]const u8) = undefined;
var styles: std.ArrayList(Style) = undefined;

fn onTextCallbackStyleTest(ctx: *anyopaque, text: []const u8, style: Style) !void {
    _ = ctx; // Ignore context
    const text_copy = testing.allocator.dupe(u8, text) catch unreachable;
    texts.append(text_copy) catch unreachable;
    styles.append(style) catch unreachable;
}

test "Parser - style handling" {
    // Initialize globals
    texts = std.ArrayList([]const u8).init(testing.allocator);
    defer {
        for (texts.items) |text| {
            testing.allocator.free(text);
        }
        texts.deinit();
    }
    
    styles = std.ArrayList(Style).init(testing.allocator);
    defer styles.deinit();
    
    const content = "{\\rtf1\\ansi{\\b Hello} World!}";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    const handler = EventHandler{
        .onGroupStart = null,
        .onGroupEnd = null,
        .onText = onTextCallbackStyleTest,
        .onCharacter = null,
        .onError = null,
    };
    
    var parser = try Parser.init(&tokenizer, testing.allocator, handler);
    defer parser.deinit();
    
    try parser.parse();
    
    // We should have captured two text segments
    try testing.expectEqual(@as(usize, 2), texts.items.len);
    try testing.expectEqual(@as(usize, 2), styles.items.len);
    
    // First text should be "Hello" with bold style (but might have different whitespace)
    try testing.expect(std.mem.indexOf(u8, texts.items[0], "Hello") != null);
    try testing.expectEqual(true, styles.items[0].bold);
    
    // Second text should be " World!" with normal style (but might have different whitespace)
    try testing.expect(std.mem.indexOf(u8, texts.items[1], "World") != null);
    try testing.expectEqual(false, styles.items[1].bold);
}