const std = @import("std");

pub const Position = struct {
    offset: usize,
    line: usize,
    column: usize,
};

pub const ByteStream = struct {
    // Source variants - file, memory, or streaming
    source: union(enum) {
        file: std.fs.File,
        memory: []const u8,
        // reader will be implemented later
    },

    // Current read position state
    position: usize,
    line: usize,
    column: usize,

    // Optimized read-ahead buffer
    buffer: [4096]u8,
    buffer_start: usize,
    buffer_end: usize,

    pub fn initMemory(content: []const u8) ByteStream {
        return .{
            .source = .{ .memory = content },
            .position = 0,
            .line = 1,
            .column = 1,
            .buffer = undefined,
            .buffer_start = 0,
            .buffer_end = 0,
        };
    }

    pub fn initFile(file: std.fs.File) ByteStream {
        return .{
            .source = .{ .file = file },
            .position = 0,
            .line = 1,
            .column = 1,
            .buffer = undefined,
            .buffer_start = 0,
            .buffer_end = 0,
        };
    }

    // Core operations
    pub fn peek(self: *ByteStream) !?u8 {
        return self.peekOffset(0);
    }

    pub fn peekOffset(self: *ByteStream, offset: usize) !?u8 {
        switch (self.source) {
            .memory => |mem| {
                if (self.position + offset >= mem.len) return null;
                return mem[self.position + offset];
            },
            .file => {
                if (self.buffer_start + offset >= self.buffer_end) {
                    try self.fillBuffer();
                    if (self.buffer_start + offset >= self.buffer_end) {
                        return null; // EOF
                    }
                }
                return self.buffer[self.buffer_start + offset];
            },
        }
    }

    pub fn consume(self: *ByteStream) !?u8 {
        const byte = try self.peek();
        if (byte) |b| {
            self.position += 1;
            
            if (self.source == .file) {
                self.buffer_start += 1;
            }

            if (b == '\n') {
                self.line += 1;
                self.column = 1;
            } else {
                self.column += 1;
            }
        }
        return byte;
    }

    pub fn consumeIf(self: *ByteStream, expected: u8) !bool {
        if ((try self.peek()) == expected) {
            _ = try self.consume();
            return true;
        }
        return false;
    }

    // Position tracking for error reporting
    pub fn getPosition(self: *const ByteStream) Position {
        return .{
            .offset = self.position,
            .line = self.line,
            .column = self.column,
        };
    }

    // Buffer management
    fn fillBuffer(self: *ByteStream) !void {
        switch (self.source) {
            .memory => |mem| {
                // For memory source, we just adjust buffer pointers to the memory slice
                if (self.buffer_end == 0) {
                    // First fill - just point to the beginning of the memory
                    self.buffer_start = 0;
                    self.buffer_end = mem.len;
                } else {
                    // Already at end of memory
                    return;
                }
            },
            .file => |file| {
                // For file source, read from file
                const n = try file.read(self.buffer[0..]);
                self.buffer_start = 0;
                self.buffer_end = n;
            },
        }
    }
};