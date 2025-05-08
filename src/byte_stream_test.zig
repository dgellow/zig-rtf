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

// A simple in-memory reader for testing
const TestReader = struct {
    data: []const u8,
    position: usize = 0,

    fn init(data: []const u8) TestReader {
        return .{ .data = data };
    }

    pub fn read(self: *TestReader, buffer: []u8) !usize {
        if (self.position >= self.data.len) return 0; // EOF
        
        const remaining = self.data.len - self.position;
        const to_read = @min(remaining, buffer.len);
        
        for (0..to_read) |i| {
            buffer[i] = self.data[self.position + i];
        }
        self.position += to_read;
        
        return to_read;
    }
};

test "ByteStream - file reader source" {
    // Create a temporary test file
    const temp_file_name = "test_reader.txt";
    const content = "Hello, Reader!";
    
    // Write test content to file
    {
        var file = try std.fs.cwd().createFile(temp_file_name, .{});
        defer file.close();
        _ = try file.writeAll(content);
    }
    defer std.fs.cwd().deleteFile(temp_file_name) catch {};
    
    // Open the file for reading
    var file = try std.fs.cwd().openFile(temp_file_name, .{});
    defer file.close();
    
    // Create a ByteStream with the reader
    var stream = ByteStream.initReader(file);
    
    // Read the content character by character
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();
    
    while (true) {
        const byte = try stream.consume() orelse break;
        try result.append(byte);
    }
    
    // Compare the read content with the original
    try testing.expectEqualStrings(content, result.items);
    
    // Check if we've reached EOF
    const eof = try stream.peek();
    try testing.expectEqual(@as(?u8, null), eof);
    try testing.expectEqual(@as(usize, content.len), stream.position);
}

test "ByteStream - memory mapped file" {
    // Create a temporary test file
    const temp_file_name = "test_mmap.txt";
    const content = "This is a test file for memory mapping!";
    
    // Write test content to file
    {
        var file = try std.fs.cwd().createFile(temp_file_name, .{});
        defer file.close();
        _ = try file.writeAll(content);
    }
    defer std.fs.cwd().deleteFile(temp_file_name) catch {};
    
    // Open file with memory mapping (use small threshold to ensure mmap is used)
    var file = try std.fs.cwd().openFile(temp_file_name, .{});
    defer file.close();
    
    var stream = try ByteStream.initFile(file, testing.allocator, 0); // Use 0 threshold to force memory mapping
    defer stream.deinit();
    
    // Verify it's using memory mapping
    try testing.expect(stream.source == .mmap);
    
    // Read the content character by character
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();
    
    while (true) {
        const byte = try stream.consume() orelse break;
        try result.append(byte);
    }
    
    // Compare the read content with the original
    try testing.expectEqualStrings(content, result.items);
}