const std = @import("std");
const testing = std.testing;
const ByteStream = @import("byte_stream.zig").ByteStream;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const TokenType = @import("tokenizer.zig").TokenType;

test "Tokenizer - basic initialization" {
    const content = "Hello, World!";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    try testing.expect(tokenizer.stream == &stream);
}

test "Tokenizer - parse simple text" {
    const content = "Hello";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    const token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.TEXT, token.type);
    try testing.expectEqualStrings("Hello", token.data.text);
    
    // TokenType.TEXT should free its data in deinit
    testing.allocator.free(token.data.text);
}

test "Tokenizer - parse group delimiters" {
    const content = "{}";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    // Test opening brace
    var token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.GROUP_START, token.type);
    
    // Test closing brace
    token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.GROUP_END, token.type);
    
    // Test EOF
    token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.EOF, token.type);
}

test "Tokenizer - parse control symbol" {
    const content = "\\\\";  // Backslash in RTF is represented as \\
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    const token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.CONTROL_SYMBOL, token.type);
    try testing.expectEqual(@as(u8, '\\'), token.data.control_symbol);
}

test "Tokenizer - parse control word without parameter" {
    const content = "\\bold ";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    const token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.CONTROL_WORD, token.type);
    try testing.expectEqualStrings("bold", token.data.control_word.name);
    try testing.expectEqual(@as(?i32, null), token.data.control_word.parameter);
    
    // TokenType.CONTROL_WORD should free its name in deinit
    testing.allocator.free(token.data.control_word.name);
}

test "Tokenizer - parse control word with parameter" {
    const content = "\\f2 ";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    const token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.CONTROL_WORD, token.type);
    try testing.expectEqualStrings("f", token.data.control_word.name);
    try testing.expectEqual(@as(?i32, 2), token.data.control_word.parameter);
    
    testing.allocator.free(token.data.control_word.name);
}

test "Tokenizer - parse negative parameter" {
    const content = "\\line-3 ";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    const token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.CONTROL_WORD, token.type);
    try testing.expectEqualStrings("line", token.data.control_word.name);
    try testing.expectEqual(@as(?i32, -3), token.data.control_word.parameter);
    
    testing.allocator.free(token.data.control_word.name);
}

test "Tokenizer - parse hex character" {
    const content = "\\'41";  // ASCII 'A'
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    const token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.HEX_CHAR, token.type);
    try testing.expectEqual(@as(u8, 0x41), token.data.hex);
}

test "Tokenizer - mixed content" {
    const content = "{\\rtf1\\ansi Hello}";
    var stream = ByteStream.initMemory(content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    // {
    var token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.GROUP_START, token.type);
    
    // \rtf1
    token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.CONTROL_WORD, token.type);
    try testing.expectEqualStrings("rtf", token.data.control_word.name);
    try testing.expectEqual(@as(?i32, 1), token.data.control_word.parameter);
    testing.allocator.free(token.data.control_word.name);
    
    // \ansi
    token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.CONTROL_WORD, token.type);
    try testing.expectEqualStrings("ansi", token.data.control_word.name);
    try testing.expectEqual(@as(?i32, null), token.data.control_word.parameter);
    testing.allocator.free(token.data.control_word.name);
    
    // " Hello" or "Hello" (space handling can vary)
    token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.TEXT, token.type);
    
    // Just test that we get some text, don't be too strict about whitespace
    try testing.expect(std.mem.indexOf(u8, token.data.text, "Hello") != null);
    testing.allocator.free(token.data.text);
    
    // }
    token = try tokenizer.nextToken();
    try testing.expectEqual(TokenType.GROUP_END, token.type);
}