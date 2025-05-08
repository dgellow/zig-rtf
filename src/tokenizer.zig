const std = @import("std");
const ByteStream = @import("byte_stream.zig").ByteStream;
const Position = @import("byte_stream.zig").Position;

pub const TokenType = enum {
    TEXT,
    CONTROL_WORD,
    CONTROL_SYMBOL,
    GROUP_START,
    GROUP_END,
    BINARY_DATA,
    HEX_CHAR,
    EOF,
    ERROR,
};

pub const Token = struct {
    type: TokenType,
    position: Position,

    // Token data based on type
    data: union {
        text: []const u8,
        control_word: struct {
            name: []const u8,
            parameter: ?i32,
        },
        control_symbol: u8,
        binary: struct {
            length: usize,
            offset: usize,  // Offset in source for delayed processing
        },
        hex: u8,
        error_message: []const u8,
    },
};

pub const Tokenizer = struct {
    stream: *ByteStream,
    text_buffer: std.ArrayList(u8),

    pub fn init(stream: *ByteStream, allocator: std.mem.Allocator) Tokenizer {
        return .{
            .stream = stream,
            .text_buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        self.text_buffer.deinit();
    }

    pub fn nextToken(self: *Tokenizer) !Token {
        // Reset buffer for next token
        self.text_buffer.items.len = 0;
        
        const byte = try self.stream.peek();
        if (byte == null) return Token{
            .type = .EOF,
            .position = self.stream.getPosition(),
            .data = undefined,
        };

        const position = self.stream.getPosition();

        switch (byte.?) {
            '{' => {
                _ = try self.stream.consume();
                return Token{
                    .type = .GROUP_START,
                    .position = position,
                    .data = undefined,
                };
            },
            '}' => {
                _ = try self.stream.consume();
                return Token{
                    .type = .GROUP_END,
                    .position = position,
                    .data = undefined,
                };
            },
            '\\' => {
                _ = try self.stream.consume();
                return try self.parseControlSequence();
            },
            else => {
                return try self.parseText();
            },
        }
    }

    // Helper methods for specific token types
    fn parseControlSequence(self: *Tokenizer) !Token {
        const first_char = try self.stream.peek() orelse return self.errorToken("Unexpected end of input after backslash");

        // Handle control symbols (single character after backslash)
        if (!isAlpha(first_char)) {
            const start_pos = self.stream.getPosition();
            _ = try self.stream.consume();

            // Special handling for hex character \'XX
            if (first_char == '\'') {
                return try self.parseHexChar();
            }

            // Special handling for binary data \*\bin
            if (first_char == '*') {
                // RTF spec: \*\<control word> indicates a destination
                _ = try self.stream.consume(); // Consume '*'
                
                // Check if next char is \ (indicating a control word follows)
                if ((try self.stream.peek()) == '\\') {
                    _ = try self.stream.consume(); // Consume '\'
                    
                    // Now check if this is \bin
                    const next_char = try self.stream.peek() orelse return self.errorToken("Unexpected end of input");
                    if (next_char == 'b') {
                        // This might be \bin - let's read the word
                        var bin_buffer = std.ArrayList(u8).init(self.text_buffer.allocator);
                        defer bin_buffer.deinit();
                        
                        // Consume 'b'
                        _ = try self.stream.consume();
                        try bin_buffer.append('b');
                        
                        // Read the rest of the word
                        while (true) {
                            const c = try self.stream.peek() orelse break;
                            if (!isAlpha(c)) break;
                            
                            try bin_buffer.append(c);
                            _ = try self.stream.consume();
                        }
                        
                        const bin_word = bin_buffer.items;
                        
                        // Check if it's "bin"
                        if (std.mem.eql(u8, bin_word, "bin")) {
                            // Now parse the length parameter
                            var length: usize = 0;
                            var has_digits = false;
                            
                            // Skip optional space
                            _ = try self.stream.consumeIf(' ');
                            
                            // Parse digits
                            while (true) {
                                const c = try self.stream.peek() orelse break;
                                if (!isDigit(c)) break;
                                
                                has_digits = true;
                                length = length * 10 + @as(usize, c - '0');
                                _ = try self.stream.consume();
                            }
                            
                            if (!has_digits) {
                                return self.errorToken("\\bin requires a length parameter");
                            }
                            
                            // Skip space after the length
                            _ = try self.stream.consumeIf(' ');
                            
                            // Record the current position as the binary data offset
                            const offset = self.stream.position;
                            
                            // Skip over the binary data
                            for (0..length) |_| {
                                _ = try self.stream.consume();
                            }
                            
                            // Return a BINARY_DATA token
                            return Token{
                                .type = .BINARY_DATA,
                                .position = start_pos,
                                .data = .{
                                    .binary = .{
                                        .length = length,
                                        .offset = offset,
                                    },
                                },
                            };
                        }
                    }
                }
                
                // If we reach here, it wasn't \*\bin, so treat it as a regular control symbol
                return Token{
                    .type = .CONTROL_SYMBOL,
                    .position = start_pos,
                    .data = .{ .control_symbol = first_char },
                };
            }

            // Regular control symbol
            return Token{
                .type = .CONTROL_SYMBOL,
                .position = self.stream.getPosition(),
                .data = .{ .control_symbol = first_char },
            };
        }

        // Handle control words (alphabetic sequence)
        // Buffer already reset in nextToken

        while (true) {
            const c = try self.stream.peek() orelse break;
            if (!isAlpha(c)) break;

            try self.text_buffer.append(c);
            _ = try self.stream.consume();
        }

        // Parse optional numeric parameter
        var parameter: ?i32 = null;
        var negative = false;

        // Check for sign
        if ((try self.stream.peek()) == '-') {
            negative = true;
            _ = try self.stream.consume();
        } else if ((try self.stream.peek()) == '+') {
            _ = try self.stream.consume();
        }

        // Parse digits
        var has_digits = false;
        var value: i32 = 0;

        while (true) {
            const c = try self.stream.peek() orelse break;
            if (!isDigit(c)) break;

            has_digits = true;
            value = value * 10 + @as(i32, c - '0');
            _ = try self.stream.consume();
        }

        // Set parameter if digits were found
        if (has_digits) {
            parameter = if (negative) -value else value;
        }

        // Consume optional space after control word
        _ = try self.stream.consumeIf(' ');

        // Make a copy of the control word name
        const name_copy = try self.text_buffer.allocator.dupe(u8, self.text_buffer.items);

        return Token{
            .type = .CONTROL_WORD,
            .position = self.stream.getPosition(),
            .data = .{
                .control_word = .{
                    .name = name_copy,
                    .parameter = parameter,
                },
            },
        };
    }

    fn parseText(self: *Tokenizer) !Token {
        // Buffer already reset in nextToken
        const start_pos = self.stream.getPosition();

        while (true) {
            const c = try self.stream.peek() orelse break;
            if (c == '{' or c == '}' or c == '\\') break;

            try self.text_buffer.append(c);
            _ = try self.stream.consume();
        }

        // We need to make a copy of the text because we reuse the text buffer
        // Note: The parser is responsible for freeing this memory, see parser.zig:294
        const text_copy = try self.text_buffer.allocator.dupe(u8, self.text_buffer.items);

        return Token{
            .type = .TEXT,
            .position = start_pos,
            .data = .{
                .text = text_copy,
            },
        };
    }

    fn parseHexChar(self: *Tokenizer) !Token {
        // Expect two hex digits
        const high = try self.stream.peek() orelse return self.errorToken("Unexpected end of input in hex char");
        if (!isHexDigit(high)) return self.errorToken("Invalid hex digit");
        _ = try self.stream.consume();

        const low = try self.stream.peek() orelse return self.errorToken("Unexpected end of input in hex char");
        if (!isHexDigit(low)) return self.errorToken("Invalid hex digit");
        _ = try self.stream.consume();

        // Convert hex digits to a byte
        const value = (hexValue(high) << 4) | hexValue(low);

        return Token{
            .type = .HEX_CHAR,
            .position = self.stream.getPosition(),
            .data = .{
                .hex = value,
            },
        };
    }

    fn errorToken(self: *Tokenizer, message: []const u8) Token {
        return Token{
            .type = .ERROR,
            .position = self.stream.getPosition(),
            .data = .{
                .error_message = message,
            },
        };
    }
};

// Helper functions
fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isHexDigit(c: u8) bool {
    return isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

fn hexValue(c: u8) u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return 10 + (c - 'a');
    if (c >= 'A' and c <= 'F') return 10 + (c - 'A');
    return 0; // Should never happen if isHexDigit is checked first
}