const std = @import("std");
const testing = std.testing;
const ByteStream = @import("byte_stream.zig").ByteStream;

test "ByteStream - initialize with memory" {
    const content = "Hello, World!";
    const stream = ByteStream.initMemory(content);
    
    try testing.expectEqual(@as(usize, 1), stream.line);
    try testing.expectEqual(@as(usize, 1), stream.column);
    try testing.expectEqual(@as(usize, 0), stream.position);
}

test "ByteStream - peek and consume" {
    const content = "ABC";
    var stream = ByteStream.initMemory(content);
    
    const first = try stream.peek();
    try testing.expectEqual(@as(?u8, 'A'), first);
    
    const consumed = try stream.consume();
    try testing.expectEqual(@as(?u8, 'A'), consumed);
    try testing.expectEqual(@as(usize, 1), stream.position);
    
    const second = try stream.peek();
    try testing.expectEqual(@as(?u8, 'B'), second);
}

test "ByteStream - peekOffset" {
    const content = "ABCDEF";
    var stream = ByteStream.initMemory(content);
    
    const third = try stream.peekOffset(2);
    try testing.expectEqual(@as(?u8, 'C'), third);
    
    // Position should not change after peekOffset
    try testing.expectEqual(@as(usize, 0), stream.position);
}

test "ByteStream - consumeIf success" {
    const content = "ABCDEF";
    var stream = ByteStream.initMemory(content);
    
    const result = try stream.consumeIf('A');
    try testing.expectEqual(true, result);
    try testing.expectEqual(@as(usize, 1), stream.position);
    
    const next = try stream.peek();
    try testing.expectEqual(@as(?u8, 'B'), next);
}

test "ByteStream - consumeIf failure" {
    const content = "ABCDEF";
    var stream = ByteStream.initMemory(content);
    
    const result = try stream.consumeIf('X');
    try testing.expectEqual(false, result);
    try testing.expectEqual(@as(usize, 0), stream.position);
    
    const next = try stream.peek();
    try testing.expectEqual(@as(?u8, 'A'), next);
}

test "ByteStream - line and column tracking" {
    const content = "AB\nC\nDE";
    var stream = ByteStream.initMemory(content);
    
    _ = try stream.consume(); // A
    _ = try stream.consume(); // B
    _ = try stream.consume(); // \n
    
    try testing.expectEqual(@as(usize, 2), stream.line);
    try testing.expectEqual(@as(usize, 1), stream.column);
    
    _ = try stream.consume(); // C
    _ = try stream.consume(); // \n
    
    try testing.expectEqual(@as(usize, 3), stream.line);
    try testing.expectEqual(@as(usize, 1), stream.column);
    
    _ = try stream.consume(); // D
    
    try testing.expectEqual(@as(usize, 3), stream.line);
    try testing.expectEqual(@as(usize, 2), stream.column);
}

test "ByteStream - read to end" {
    const content = "ABC";
    var stream = ByteStream.initMemory(content);
    
    _ = try stream.consume(); // A
    _ = try stream.consume(); // B
    _ = try stream.consume(); // C
    
    const eof = try stream.peek();
    try testing.expectEqual(@as(?u8, null), eof);
}

test "ByteStream - getPosition" {
    const content = "A\nBC";
    var stream = ByteStream.initMemory(content);
    
    _ = try stream.consume(); // A
    _ = try stream.consume(); // \n
    _ = try stream.consume(); // B
    
    const pos = stream.getPosition();
    try testing.expectEqual(@as(usize, 3), pos.offset);
    try testing.expectEqual(@as(usize, 2), pos.line);
    try testing.expectEqual(@as(usize, 2), pos.column);
}