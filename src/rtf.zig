const std = @import("std");

// Simple byte reader with minimal buffering
const ByteReader = struct {
    source: std.io.AnyReader,
    buffer: [1024]u8 = undefined, // Larger buffer for better performance
    pos: usize = 0,
    len: usize = 0,
    eof: bool = false,
    
    fn init(source: std.io.AnyReader) ByteReader {
        return .{ .source = source };
    }
    
    fn fillBuffer(self: *ByteReader) !void {
        if (self.eof) return;
        
        // Move remaining bytes to start
        if (self.pos > 0 and self.pos < self.len) {
            std.mem.copyForwards(u8, self.buffer[0..], self.buffer[self.pos..self.len]);
            self.len -= self.pos;
            self.pos = 0;
        } else if (self.pos >= self.len) {
            self.pos = 0;
            self.len = 0;
        }
        
        // Fill remaining space
        const space = self.buffer.len - self.len;
        if (space > 0) {
            const bytes_read = self.source.read(self.buffer[self.len..]) catch |err| switch (err) {
                error.EndOfStream => 0,
                else => return err,
            };
            
            if (bytes_read == 0) {
                self.eof = true;
            } else {
                self.len += bytes_read;
            }
        }
    }
    
    fn peek(self: *ByteReader) !?u8 {
        if (self.pos >= self.len) {
            try self.fillBuffer();
            if (self.pos >= self.len) return null;
        }
        return self.buffer[self.pos];
    }
    
    fn next(self: *ByteReader) !?u8 {
        const byte = try self.peek() orelse return null;
        self.pos += 1;
        return byte;
    }
    
    fn skipWhitespace(self: *ByteReader) !void {
        while (try self.peek()) |byte| {
            if (!std.ascii.isWhitespace(byte)) break;
            _ = try self.next();
        }
    }
};

// Control word lookup for fast processing
const ControlWord = enum {
    // Character formatting
    b, i, ul, ulnone, plain, fs, f,
    // Special characters  
    par, line, tab,
    // Unicode and binary
    u, bin,
    // Destinations to skip
    fonttbl, colortbl, stylesheet, info, pict, field, fldinst, fldrslt, generator,
    // Character sets
    ansi, mac, pc, pca,
    // Misc
    deff, rtf,
    // Table elements
    trowd, cellx, cell, row,
    // Unknown
    unknown,
    
    fn fromString(word: []const u8) ControlWord {
        // Fast lookup for common control words
        return switch (word[0]) {
            'a' => if (std.mem.eql(u8, word, "ansi")) .ansi else .unknown,
            'b' => if (std.mem.eql(u8, word, "b") and word.len == 1) .b 
                   else if (std.mem.eql(u8, word, "bin")) .bin else .unknown,
            'c' => if (std.mem.eql(u8, word, "colortbl")) .colortbl
                   else if (std.mem.eql(u8, word, "cell")) .cell
                   else if (std.mem.eql(u8, word, "cellx")) .cellx else .unknown,
            'd' => if (std.mem.eql(u8, word, "deff")) .deff else .unknown,
            'f' => if (std.mem.eql(u8, word, "f") and word.len == 1) .f
                   else if (std.mem.eql(u8, word, "fonttbl")) .fonttbl
                   else if (std.mem.eql(u8, word, "fs")) .fs
                   else if (std.mem.eql(u8, word, "field")) .field
                   else if (std.mem.eql(u8, word, "fldinst")) .fldinst
                   else if (std.mem.eql(u8, word, "fldrslt")) .fldrslt else .unknown,
            'g' => if (std.mem.eql(u8, word, "generator")) .generator else .unknown,
            'i' => if (std.mem.eql(u8, word, "i") and word.len == 1) .i
                   else if (std.mem.eql(u8, word, "info")) .info else .unknown,
            'l' => if (std.mem.eql(u8, word, "line")) .line else .unknown,
            'm' => if (std.mem.eql(u8, word, "mac")) .mac else .unknown,
            'p' => if (std.mem.eql(u8, word, "par")) .par
                   else if (std.mem.eql(u8, word, "plain")) .plain
                   else if (std.mem.eql(u8, word, "pict")) .pict
                   else if (std.mem.eql(u8, word, "pc")) .pc
                   else if (std.mem.eql(u8, word, "pca")) .pca else .unknown,
            'r' => if (std.mem.eql(u8, word, "rtf")) .rtf
                   else if (std.mem.eql(u8, word, "row")) .row else .unknown,
            's' => if (std.mem.eql(u8, word, "stylesheet")) .stylesheet else .unknown,
            't' => if (std.mem.eql(u8, word, "tab")) .tab
                   else if (std.mem.eql(u8, word, "trowd")) .trowd else .unknown,
            'u' => if (std.mem.eql(u8, word, "u") and word.len == 1) .u
                   else if (std.mem.eql(u8, word, "ul")) .ul
                   else if (std.mem.eql(u8, word, "ulnone")) .ulnone else .unknown,
            else => .unknown,
        };
    }
};

// RTF Text Parser - focused on text extraction
pub const Parser = struct {
    reader: ByteReader,
    arena: std.heap.ArenaAllocator,
    
    // Text output only
    text: std.ArrayList(u8),
    
    // Simple parsing state
    group_depth: u32 = 0,
    skip_group: bool = false,
    max_depth: u32 = 128,
    
    pub fn init(source: std.io.AnyReader, allocator: std.mem.Allocator) Parser {
        return .{
            .reader = ByteReader.init(source),
            .arena = std.heap.ArenaAllocator.init(allocator),
            .text = std.ArrayList(u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *Parser) void {
        self.text.deinit();
        self.arena.deinit();
    }
    
    pub fn getText(self: *const Parser) []const u8 {
        return self.text.items;
    }
    
    pub fn parse(self: *Parser) !void {
        try self.reader.skipWhitespace();
        
        // RTF must start with {
        const first = try self.reader.next() orelse return error.EmptyInput;
        if (first != '{') return error.InvalidRtf;
        
        self.group_depth = 1;
        
        // Must have \rtf
        try self.reader.skipWhitespace();
        if (!try self.expectControl("rtf")) return error.InvalidRtf;
        
        // Parse content until end
        while (self.group_depth > 0) {
            const byte = try self.reader.next() orelse break;
            
            switch (byte) {
                '{' => {
                    self.group_depth += 1;
                    if (self.group_depth > self.max_depth) {
                        return error.TooManyNestedGroups;
                    }
                    try self.handleGroupStart();
                },
                '}' => {
                    self.group_depth -= 1;
                    self.skip_group = false; // Reset skip when leaving group
                },
                '\\' => try self.parseControl(),
                else => {
                    if (!self.skip_group) {
                        try self.addChar(byte);
                    }
                },
            }
        }
    }
    
    fn handleGroupStart(self: *Parser) !void {
        // Check for ignorable group {\*\...}
        try self.reader.skipWhitespace();
        if (try self.reader.peek() == '\\') {
            const saved_pos = self.reader.pos;
            _ = try self.reader.next(); // consume '\'
            
            if (try self.reader.peek() == '*') {
                _ = try self.reader.next(); // consume '*'
                self.skip_group = true;
                return;
            } else {
                // Restore position
                self.reader.pos = saved_pos;
            }
        }
    }
    
    fn parseControl(self: *Parser) !void {
        const first = try self.reader.peek() orelse return;
        
        // Handle control symbols
        if (!std.ascii.isAlphabetic(first)) {
            const symbol = (try self.reader.next()).?;
            switch (symbol) {
                '\\', '{', '}' => {
                    if (!self.skip_group) try self.addChar(symbol);
                },
                '\n', '\r' => {
                    if (!self.skip_group) try self.addParagraphBreak();
                },
                '\'' => try self.parseHexByte(),
                else => {}, // Ignore other symbols
            }
            return;
        }
        
        // Parse control word
        var word_buf: [32]u8 = undefined;
        var word_len: usize = 0;
        
        // Read control word
        while (word_len < word_buf.len) {
            const byte = try self.reader.peek() orelse break;
            if (!std.ascii.isAlphabetic(byte)) break;
            word_buf[word_len] = (try self.reader.next()).?;
            word_len += 1;
        }
        
        if (word_len == 0) return;
        const word = word_buf[0..word_len];
        
        // Read optional parameter
        var param: ?i32 = null;
        if (try self.reader.peek()) |byte| {
            if (std.ascii.isDigit(byte) or byte == '-') {
                param = try self.readNumber();
            }
        }
        
        // Skip delimiter space after control word
        if (try self.reader.peek() == ' ') {
            _ = try self.reader.next();
        }
        
        try self.handleControlWord(word, param);
    }
    
    fn handleControlWord(self: *Parser, word: []const u8, param: ?i32) !void {
        const control = ControlWord.fromString(word);
        
        switch (control) {
            // Destinations to skip completely
            .fonttbl, .colortbl, .stylesheet, .info, .pict, 
            .fldinst, .generator => {
                self.skip_group = true;
            },
            
            // Field containers - don't skip, let content through
            .field, .fldrslt => {
                // Don't skip these, they may contain visible text
            },
            
            // Special characters
            .par => {
                if (!self.skip_group) try self.addParagraphBreak();
            },
            .line => {
                if (!self.skip_group) try self.addChar('\n');
            },
            .tab => {
                if (!self.skip_group) try self.addChar('\t');
            },
            
            // Unicode
            .u => {
                if (!self.skip_group and param != null) {
                    // Clamp unicode values to u16 range (0-65535)
                    const safe_param = @max(0, @min(65535, param.?));
                    try self.handleUnicode(@intCast(safe_param));
                }
            },
            
            // Binary data
            .bin => {
                if (param != null) {
                    try self.skipBinaryData(@intCast(@max(0, param.?)));
                }
            },
            
            // Ignore formatting, fonts, charsets, tables - we only want text
            .b, .i, .ul, .ulnone, .plain, .fs, .f, .ansi, .mac, .pc, .pca, 
            .deff, .trowd, .cellx, .cell, .row => {
                // Skip - we don't track formatting for text-only output
            },
            
            .unknown => {
                // Gracefully ignore unknown control words
            },
            
            .rtf => {}, // Already handled in main parse
        }
    }
    
    fn addChar(self: *Parser, char: u8) !void {
        try self.text.append(char);
    }
    
    fn addParagraphBreak(self: *Parser) !void {
        try self.text.appendSlice("\n\n");
    }
    
    fn handleUnicode(self: *Parser, unicode_val: u16) !void {
        // Convert Unicode code point to UTF-8
        var utf8_buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(unicode_val, &utf8_buf) catch {
            // Invalid Unicode, skip
            return;
        };
        
        try self.text.appendSlice(utf8_buf[0..len]);
        
        // Skip the replacement character that follows \u
        if (try self.reader.peek() == '?') {
            _ = try self.reader.next();
        }
    }
    
    fn skipBinaryData(self: *Parser, byte_count: u32) !void {
        var i: u32 = 0;
        while (i < byte_count) : (i += 1) {
            _ = try self.reader.next() orelse break;
        }
    }
    
    fn parseHexByte(self: *Parser) !void {
        if (self.skip_group) return;
        
        const hex1 = try self.reader.next() orelse return;
        const hex2 = try self.reader.next() orelse return;
        
        const byte_val = (hexToValue(hex1) << 4) | hexToValue(hex2);
        try self.addChar(byte_val);
    }
    
    fn hexToValue(digit: u8) u8 {
        return switch (digit) {
            '0'...'9' => digit - '0',
            'A'...'F' => digit - 'A' + 10,
            'a'...'f' => digit - 'a' + 10,
            else => 0,
        };
    }
    
    fn expectControl(self: *Parser, expected: []const u8) !bool {
        if (try self.reader.peek() != '\\') return false;
        _ = try self.reader.next();
        
        for (expected) |expected_char| {
            const actual = try self.reader.next() orelse return false;
            if (actual != expected_char) return false;
        }
        
        // Skip optional parameter and space
        if (try self.reader.peek()) |byte| {
            if (std.ascii.isDigit(byte)) {
                _ = try self.readNumber();
            }
        }
        if (try self.reader.peek() == ' ') {
            _ = try self.reader.next();
        }
        
        return true;
    }
    
    fn readNumber(self: *Parser) !i32 {
        var result: i64 = 0;
        var negative = false;
        var digit_count: u32 = 0;
        const MAX_DIGITS = 10;
        
        if (try self.reader.peek() == '-') {
            negative = true;
            _ = try self.reader.next();
        }
        
        while (try self.reader.peek()) |byte| {
            if (!std.ascii.isDigit(byte)) break;
            if (digit_count >= MAX_DIGITS) {
                _ = try self.reader.next();
                continue;
            }
            
            const digit: i64 = byte - '0';
            result = result * 10 + digit;
            
            // Check for i32 overflow
            if (result > std.math.maxInt(i32)) {
                // Skip remaining digits
                _ = try self.reader.next();
                while (try self.reader.peek()) |next_byte| {
                    if (!std.ascii.isDigit(next_byte)) break;
                    _ = try self.reader.next();
                }
                return if (negative) std.math.minInt(i32) else std.math.maxInt(i32);
            }
            
            _ = try self.reader.next();
            digit_count += 1;
        }
        
        const final_result: i32 = @intCast(result);
        return if (negative) -final_result else final_result;
    }
};

// Tests
test "simple RTF text extraction" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Hello World!}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expectEqualStrings("Hello World!", text);
}

test "RTF with formatting - text only" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Hello \\b bold\\b0  and \\i italic\\i0  text!}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expectEqualStrings("Hello bold and italic text!", text);
}

test "RTF with paragraphs" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 First paragraph\\par Second paragraph}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expectEqualStrings("First paragraph\n\nSecond paragraph", text);
}