const std = @import("std");
const doc_model = @import("document_model.zig");
const table_parsers = @import("table_parser.zig");

// =============================================================================
// FORMATTED RTF PARSER 
// =============================================================================
// This replaces the simple text-only parser with a complete formatting-aware
// parser that builds a full document model.

// Same ByteReader as before (works fine)
const ByteReader = struct {
    source: std.io.AnyReader,
    buffer: [1024]u8 = undefined,
    pos: usize = 0,
    len: usize = 0,
    eof: bool = false,
    
    fn init(source: std.io.AnyReader) ByteReader {
        return .{ .source = source };
    }
    
    fn fillBuffer(self: *ByteReader) !void {
        if (self.eof) return;
        
        if (self.pos > 0 and self.pos < self.len) {
            std.mem.copyForwards(u8, self.buffer[0..], self.buffer[self.pos..self.len]);
            self.len -= self.pos;
            self.pos = 0;
        } else if (self.pos >= self.len) {
            self.pos = 0;
            self.len = 0;
        }
        
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

// Enhanced control word enum with all formatting commands
const ControlWord = enum {
    // Character formatting
    b, b0, i, i0, ul, ul0, ulnone, strike, strike0,
    super, super0, sub, sub0, plain, fs, f, cf,
    
    // Paragraph formatting  
    par, line, tab, ql, qc, qr, qj, li, ri, fi, sb, sa,
    
    // Special characters
    u, bin, lquote, rquote, ldblquote, rdblquote, bullet, emdash, endash,
    
    // Destinations
    fonttbl, colortbl, stylesheet, info, pict, field, fldinst, fldrslt, 
    generator, header, footer, footnote,
    
    // Font table
    fswiss, froman, fmodern, fscript, fdecor, ftech, fbidi,
    
    // Color table
    red, green, blue,
    
    // Tables
    trowd, cellx, cell, row, trleft, trrh,
    
    // Document properties
    ansi, mac, pc, pca, deff, rtf, uc,
    
    // Lists
    pn, pntext, pnlvl,
    
    // Images and objects
    shppict, nonshppict, objw, objh,
    
    // Unknown
    unknown,
    
    fn fromString(word: []const u8) ControlWord {
        // Optimized lookup for common formatting commands
        return switch (word[0]) {
            'a' => if (std.mem.eql(u8, word, "ansi")) .ansi else .unknown,
            'b' => {
                if (std.mem.eql(u8, word, "b") and word.len == 1) return .b;
                if (std.mem.eql(u8, word, "b0")) return .b0;
                if (std.mem.eql(u8, word, "bin")) return .bin;
                if (std.mem.eql(u8, word, "bullet")) return .bullet;
                if (std.mem.eql(u8, word, "blue")) return .blue;
                return .unknown;
            },
            'c' => {
                if (std.mem.eql(u8, word, "colortbl")) return .colortbl;
                if (std.mem.eql(u8, word, "cell")) return .cell;
                if (std.mem.eql(u8, word, "cellx")) return .cellx;
                if (std.mem.eql(u8, word, "cf")) return .cf;
                return .unknown;
            },
            'd' => if (std.mem.eql(u8, word, "deff")) .deff else .unknown,
            'f' => {
                if (std.mem.eql(u8, word, "f") and word.len == 1) return .f;
                if (std.mem.eql(u8, word, "fonttbl")) return .fonttbl;
                if (std.mem.eql(u8, word, "fs")) return .fs;
                if (std.mem.eql(u8, word, "field")) return .field;
                if (std.mem.eql(u8, word, "fldinst")) return .fldinst;
                if (std.mem.eql(u8, word, "fldrslt")) return .fldrslt;
                if (std.mem.eql(u8, word, "fi")) return .fi;
                if (std.mem.eql(u8, word, "fswiss")) return .fswiss;
                if (std.mem.eql(u8, word, "froman")) return .froman;
                if (std.mem.eql(u8, word, "fmodern")) return .fmodern;
                if (std.mem.eql(u8, word, "fscript")) return .fscript;
                if (std.mem.eql(u8, word, "fdecor")) return .fdecor;
                if (std.mem.eql(u8, word, "ftech")) return .ftech;
                if (std.mem.eql(u8, word, "fbidi")) return .fbidi;
                return .unknown;
            },
            'i' => {
                if (std.mem.eql(u8, word, "i") and word.len == 1) return .i;
                if (std.mem.eql(u8, word, "i0")) return .i0;
                if (std.mem.eql(u8, word, "info")) return .info;
                return .unknown;
            },
            'l' => {
                if (std.mem.eql(u8, word, "line")) return .line;
                if (std.mem.eql(u8, word, "li")) return .li;
                if (std.mem.eql(u8, word, "lquote")) return .lquote;
                if (std.mem.eql(u8, word, "ldblquote")) return .ldblquote;
                return .unknown;
            },
            'p' => {
                if (std.mem.eql(u8, word, "par")) return .par;
                if (std.mem.eql(u8, word, "plain")) return .plain;
                if (std.mem.eql(u8, word, "pict")) return .pict;
                return .unknown;
            },
            'q' => {
                if (std.mem.eql(u8, word, "ql")) return .ql;
                if (std.mem.eql(u8, word, "qc")) return .qc;
                if (std.mem.eql(u8, word, "qr")) return .qr;
                if (std.mem.eql(u8, word, "qj")) return .qj;
                return .unknown;
            },
            'r' => {
                if (std.mem.eql(u8, word, "rtf")) return .rtf;
                if (std.mem.eql(u8, word, "ri")) return .ri;
                if (std.mem.eql(u8, word, "row")) return .row;
                if (std.mem.eql(u8, word, "rquote")) return .rquote;
                if (std.mem.eql(u8, word, "rdblquote")) return .rdblquote;
                if (std.mem.eql(u8, word, "red")) return .red;
                return .unknown;
            },
            's' => {
                if (std.mem.eql(u8, word, "strike")) return .strike;
                if (std.mem.eql(u8, word, "strike0")) return .strike0;
                if (std.mem.eql(u8, word, "super")) return .super;
                if (std.mem.eql(u8, word, "super0")) return .super0;
                if (std.mem.eql(u8, word, "sub")) return .sub;
                if (std.mem.eql(u8, word, "sub0")) return .sub0;
                if (std.mem.eql(u8, word, "sb")) return .sb;
                if (std.mem.eql(u8, word, "sa")) return .sa;
                if (std.mem.eql(u8, word, "stylesheet")) return .stylesheet;
                return .unknown;
            },
            't' => {
                if (std.mem.eql(u8, word, "tab")) return .tab;
                if (std.mem.eql(u8, word, "trowd")) return .trowd;
                if (std.mem.eql(u8, word, "trleft")) return .trleft;
                if (std.mem.eql(u8, word, "trrh")) return .trrh;
                return .unknown;
            },
            'u' => {
                if (std.mem.eql(u8, word, "u") and word.len == 1) return .u;
                if (std.mem.eql(u8, word, "ul")) return .ul;
                if (std.mem.eql(u8, word, "ul0")) return .ul0;
                if (std.mem.eql(u8, word, "ulnone")) return .ulnone;
                if (std.mem.eql(u8, word, "uc")) return .uc;
                return .unknown;
            },
            'g' => {
                if (std.mem.eql(u8, word, "green")) return .green;
                return .unknown;
            },
            else => .unknown,
        };
    }
};

// Destination types for proper content handling
const DestinationType = enum {
    normal,        // Regular document content
    font_table,    // Font table parsing
    color_table,   // Color table parsing  
    skip,          // Skip this group entirely
    field_inst,    // Field instruction (hyperlinks, etc)
    field_result,  // Field result (visible text)
    table_content, // Inside table cell
};

// Complete formatting-aware parser
pub const FormattedParser = struct {
    reader: ByteReader,
    document: doc_model.Document,
    
    // Format state stack for group nesting
    format_stack: std.ArrayList(doc_model.FormatState),
    current_format: doc_model.FormatState = .{},
    
    // Destination stack for proper content handling
    destination_stack: std.ArrayList(DestinationType),
    current_destination: DestinationType = .normal,
    
    // Parsing state
    group_depth: u32 = 0,
    max_depth: u32 = 128,
    
    // Current text buffer (accumulated until format change)
    text_buffer: std.ArrayList(u8),
    
    // Specialized table parsers
    font_table_parser: table_parsers.FontTableParser,
    color_table_parser: table_parsers.ColorTableParser,
    table_parser: table_parsers.TableParser,
    
    // Field parsing state
    in_field: bool = false,
    field_instruction: std.ArrayList(u8),
    field_result: std.ArrayList(u8),
    
    pub fn init(source: std.io.AnyReader, allocator: std.mem.Allocator) FormattedParser {
        return .{
            .reader = ByteReader.init(source),
            .document = doc_model.Document.init(allocator),
            .format_stack = std.ArrayList(doc_model.FormatState).init(allocator),
            .destination_stack = std.ArrayList(DestinationType).init(allocator),
            .text_buffer = std.ArrayList(u8).init(allocator),
            .font_table_parser = table_parsers.FontTableParser.init(allocator), // TODO: Fix to use arena allocator
            .color_table_parser = table_parsers.ColorTableParser.init(),
            .table_parser = table_parsers.TableParser.init(allocator),
            .field_instruction = std.ArrayList(u8).init(allocator),
            .field_result = std.ArrayList(u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *FormattedParser) void {
        self.document.deinit();
        self.format_stack.deinit();
        self.destination_stack.deinit();
        self.text_buffer.deinit();
        self.font_table_parser.deinit();
        self.table_parser.deinit();
        self.field_instruction.deinit();
        self.field_result.deinit();
    }
    
    pub fn parse(self: *FormattedParser) !doc_model.Document {
        try self.reader.skipWhitespace();
        
        // RTF must start with {
        const first = try self.reader.next() orelse return error.EmptyInput;
        if (first != '{') return error.InvalidRtf;
        
        self.group_depth = 1;
        
        // Must have \rtf
        try self.reader.skipWhitespace();
        if (!try self.expectControl("rtf")) return error.InvalidRtf;
        
        // Skip RTF version number (e.g., "1" in "\rtf1")
        if (try self.reader.peek()) |byte| {
            if (std.ascii.isDigit(byte)) {
                _ = try self.readNumber(); // Consume version number
            }
        }
        
        // Skip any whitespace after RTF declaration
        try self.reader.skipWhitespace();
        
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
                    try self.handleGroupEnd();
                    self.group_depth -= 1;
                },
                '\\' => try self.parseControl(),
                else => {
                    switch (self.current_destination) {
                        .normal, .field_result, .table_content => {
                            try self.addChar(byte);
                        },
                        .font_table => {
                            // Only collect text if we're in a font entry
                            if (self.font_table_parser.in_font_entry) {
                                try self.font_table_parser.addNameChar(byte);
                            }
                            // Ignore other text (like between font entries)
                        },
                        .color_table => {
                            // Handle semicolons as color separators in color table
                            if (byte == ';') {
                                // Complete current color entry
                                const color = self.color_table_parser.finishColorEntry();
                                try self.document.addColor(color);
                            }
                            // Ignore other text in color table
                        },
                        else => {
                            // Skip text in other destinations
                        },
                    }
                },
            }
        }
        
        // Flush any remaining text
        try self.flushTextBuffer();
        
        // Return document (caller takes ownership)
        // Move ownership from parser to caller
        const result = self.document;
        
        // Create new empty document for parser to prevent double-free
        self.document = doc_model.Document.init(result.allocator);
        
        return result;
    }
    
    fn expectControl(self: *FormattedParser, expected: []const u8) !bool {
        if (try self.reader.peek() != '\\') return false;
        _ = try self.reader.next(); // consume '\\'
        
        for (expected) |char| {
            const byte = try self.reader.next() orelse return false;
            if (byte != char) return false;
        }
        
        // Skip delimiter
        if (try self.reader.peek() == ' ') {
            _ = try self.reader.next();
        }
        
        return true;
    }
    
    fn handleGroupStart(self: *FormattedParser) !void {
        // Push current state onto stacks
        try self.format_stack.append(self.current_format.copy());
        try self.destination_stack.append(self.current_destination);
        
        // Check for ignorable group {\*\...}
        try self.reader.skipWhitespace();
        if (try self.reader.peek() == '\\') {
            const saved_pos = self.reader.pos;
            _ = try self.reader.next(); // consume '\'
            
            if (try self.reader.peek() == '*') {
                _ = try self.reader.next(); // consume '*'
                self.current_destination = .skip;
                return;
            } else {
                // Restore position
                self.reader.pos = saved_pos;
            }
        }
    }
    
    fn handleGroupEnd(self: *FormattedParser) !void {
        // Handle destination-specific cleanup
        switch (self.current_destination) {
            .font_table => {
                // Finish current font entry if any (this happens for individual font entries)
                if (self.font_table_parser.in_font_entry) {
                    var temp_font = self.font_table_parser.finishFontEntry() catch |err| switch (err) {
                        error.NotInFontEntry => unreachable,
                        else => return err,
                    };
                    
                    // Move font name to document arena to avoid leak
                    const arena_name = try self.document.arena.allocator().dupe(u8, temp_font.name);
                    self.font_table_parser.allocator.free(temp_font.name); // Free the original
                    temp_font.name = arena_name;
                    
                    try self.document.addFont(temp_font);
                }
                // Note: We don't change destination here - that happens in the stack restore
                self.text_buffer.clearRetainingCapacity();
            },
            .color_table => {
                // Color table entry completed when we reach semicolon or group end
                // Each color entry is defined by \red, \green, \blue and ends with ;
                // This happens when closing a color table group or when we see a semicolon
            },
            .field_result => {
                if (self.field_result.items.len > 0) {
                    try self.flushTextBuffer();
                }
            },
            else => {},
        }
        
        // Restore previous state from stacks
        if (self.format_stack.items.len > 0) {
            if (self.format_stack.pop()) |prev_format| {
                try self.flushTextBuffer(); // Always flush when format might change
                self.current_format = prev_format;
            }
        }
        
        if (self.destination_stack.items.len > 0) {
            if (self.destination_stack.pop()) |prev_dest| {
                self.current_destination = prev_dest;
            }
        }
    }
    
    fn parseControl(self: *FormattedParser) !void {
        const first = try self.reader.peek() orelse return;
        
        // Handle control symbols
        if (!std.ascii.isAlphabetic(first)) {
            const symbol = (try self.reader.next()).?;
            switch (symbol) {
                '\\', '{', '}' => try self.addChar(symbol),
                '\n', '\r' => {
                    try self.flushTextBuffer();
                    try self.document.addElement(.paragraph_break);
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
    
    fn handleControlWord(self: *FormattedParser, word: []const u8, param: ?i32) !void {
        const control = ControlWord.fromString(word);
        
        switch (control) {
            // Destinations
            .fonttbl => {
                try self.flushTextBuffer();
                self.current_destination = .font_table;
            },
            .colortbl => {
                try self.flushTextBuffer();
                self.current_destination = .color_table;
                
                // Add auto color and initialize parser
                const auto_color = self.color_table_parser.startColorTable();
                try self.document.addColor(auto_color);
            },
            .info, .stylesheet, .generator, .header, .footer, .footnote, .pict => {
                self.current_destination = .skip;
            },
            .field => {
                self.in_field = true;
                self.field_instruction.clearRetainingCapacity();
                self.field_result.clearRetainingCapacity();
            },
            .fldinst => {
                self.current_destination = .field_inst;
            },
            .fldrslt => {
                self.current_destination = .field_result;
            },
            
            // Character formatting
            .b => {
                if (!self.current_format.char_format.equals(.{ .bold = true })) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.bold = param orelse 1 != 0;
            },
            .b0 => {
                if (self.current_format.char_format.bold) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.bold = false;
            },
            .i => {
                if (!self.current_format.char_format.italic) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.italic = param orelse 1 != 0;
            },
            .i0 => {
                if (self.current_format.char_format.italic) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.italic = false;
            },
            .ul => {
                if (!self.current_format.char_format.underline) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.underline = true;
            },
            .ul0, .ulnone => {
                if (self.current_format.char_format.underline) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.underline = false;
            },
            .strike => {
                if (!self.current_format.char_format.strikethrough) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.strikethrough = param orelse 1 != 0;
            },
            .strike0 => {
                if (self.current_format.char_format.strikethrough) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.strikethrough = false;
            },
            .super => {
                if (!self.current_format.char_format.superscript) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.superscript = true;
                self.current_format.char_format.subscript = false;
            },
            .super0 => {
                if (self.current_format.char_format.superscript) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.superscript = false;
            },
            .sub => {
                if (!self.current_format.char_format.subscript) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.subscript = true;
                self.current_format.char_format.superscript = false;
            },
            .sub0 => {
                if (self.current_format.char_format.subscript) {
                    try self.flushTextBuffer();
                }
                self.current_format.char_format.subscript = false;
            },
            .plain => {
                try self.flushTextBuffer();
                self.current_format.resetCharFormat();
            },
            .fs => {
                if (param) |size| {
                    const new_size: u16 = @intCast(@max(0, @min(32767, size)));
                    if (self.current_format.char_format.font_size != new_size) {
                        try self.flushTextBuffer();
                        self.current_format.char_format.font_size = new_size;
                    }
                }
            },
            .f => {
                if (param) |font_id| {
                    const new_font: u16 = @intCast(@max(0, @min(65535, font_id)));
                    
                    if (self.current_destination == .font_table) {
                        // In font table - start new font entry
                        self.font_table_parser.startFontEntry(new_font);
                    } else {
                        // In regular content - apply font formatting
                        if (self.current_format.char_format.font_id != new_font) {
                            try self.flushTextBuffer();
                            self.current_format.char_format.font_id = new_font;
                        }
                    }
                }
            },
            .cf => {
                if (param) |color_id| {
                    const new_color: u16 = @intCast(@max(0, @min(65535, color_id)));
                    if (self.current_format.char_format.color_id != new_color) {
                        try self.flushTextBuffer();
                        self.current_format.char_format.color_id = new_color;
                    }
                }
            },
            
            // Paragraph formatting
            .par => {
                try self.flushTextBuffer();
                try self.document.addElement(.paragraph_break);
            },
            .line => {
                try self.flushTextBuffer();
                try self.document.addElement(.line_break);
            },
            .tab => try self.addChar('\t'),
            .ql => {
                self.current_format.para_format.alignment = .left;
            },
            .qc => {
                self.current_format.para_format.alignment = .center;
            },
            .qr => {
                self.current_format.para_format.alignment = .right;
            },
            .qj => {
                self.current_format.para_format.alignment = .justify;
            },
            .li => {
                if (param) |indent| {
                    self.current_format.para_format.left_indent = indent;
                }
            },
            .ri => {
                if (param) |indent| {
                    self.current_format.para_format.right_indent = indent;
                }
            },
            .fi => {
                if (param) |indent| {
                    self.current_format.para_format.first_line_indent = indent;
                }
            },
            .sb => {
                if (param) |space| {
                    self.current_format.para_format.space_before = @intCast(@max(0, space));
                }
            },
            .sa => {
                if (param) |space| {
                    self.current_format.para_format.space_after = @intCast(@max(0, space));
                }
            },
            
            // Special characters
            .u => {
                if (param) |unicode_val| {
                    const safe_val = @max(0, @min(65535, unicode_val));
                    try self.handleUnicode(@intCast(safe_val));
                }
            },
            .bin => {
                if (param) |size| {
                    try self.skipBinaryData(@intCast(@max(0, size)));
                }
            },
            .lquote => try self.addChar('\''),
            .rquote => try self.addChar('\''),
            .ldblquote => try self.addChar('"'),
            .rdblquote => try self.addChar('"'),
            .bullet => {
                // Unicode bullet point as UTF-8
                try self.text_buffer.appendSlice("•");
            },
            .emdash => {
                // Unicode em dash as UTF-8
                try self.text_buffer.appendSlice("—");
            },
            .endash => {
                // Unicode en dash as UTF-8
                try self.text_buffer.appendSlice("–");
            },
            
            // Tables
            .trowd => {
                try self.startTableRow();
            },
            .cellx => {
                if (param) |width| {
                    try self.setCellWidth(@intCast(@max(0, width)));
                }
            },
            .cell => {
                try self.endTableCell();
            },
            .row => {
                try self.endTableRow();
            },
            
            // Document properties
            .deff => {
                if (param) |font_id| {
                    self.document.default_font = @intCast(@max(0, @min(65535, font_id)));
                }
            },
            .rtf => {
                // RTF version - don't add to text output
                if (param) |version| {
                    self.document.rtf_version = @intCast(@max(1, @min(999, version)));
                }
            },
            
            // Font family types  
            .fswiss => {
                if (self.current_destination == .font_table) {
                    self.font_table_parser.setFontFamily(.swiss);
                }
            },
            .froman => {
                if (self.current_destination == .font_table) {
                    self.font_table_parser.setFontFamily(.roman);
                }
            },
            .fmodern => {
                if (self.current_destination == .font_table) {
                    self.font_table_parser.setFontFamily(.modern);
                }
            },
            .fscript => {
                if (self.current_destination == .font_table) {
                    self.font_table_parser.setFontFamily(.script);
                }
            },
            .fdecor => {
                if (self.current_destination == .font_table) {
                    self.font_table_parser.setFontFamily(.decorative);
                }
            },
            .ftech, .fbidi => {
                // Technical and bidirectional fonts - treat as don't care
                if (self.current_destination == .font_table) {
                    self.font_table_parser.setFontFamily(.dontcare);
                }
            },
            
            // Color table RGB values
            .red => {
                if (self.current_destination == .color_table and param != null) {
                    self.color_table_parser.setRed(@intCast(@max(0, @min(255, param.?))));
                }
            },
            .green => {
                if (self.current_destination == .color_table and param != null) {
                    self.color_table_parser.setGreen(@intCast(@max(0, @min(255, param.?))));
                }
            },
            .blue => {
                if (self.current_destination == .color_table and param != null) {
                    self.color_table_parser.setBlue(@intCast(@max(0, @min(255, param.?))));
                }
            },
            
            else => {
                // Unknown control word - ignore
            },
        }
    }
    
    fn readNumber(self: *FormattedParser) !i32 {
        const MAX_DIGITS = 10;
        var result: i64 = 0;
        var negative = false;
        var digit_count: usize = 0;
        
        // Check for negative sign
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
            
            if (result > std.math.maxInt(i32)) {
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
    
    fn handleUnicode(self: *FormattedParser, code_point: u16) !void {
        var utf8_buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(code_point, &utf8_buf) catch {
            // Invalid Unicode - add replacement character
            try self.addChar('?');
            return;
        };
        
        for (utf8_buf[0..len]) |byte| {
            try self.addChar(byte);
        }
    }
    
    fn parseHexByte(self: *FormattedParser) !void {
        var hex_val: u8 = 0;
        
        for (0..2) |_| {
            const byte = try self.reader.next() orelse return;
            if (std.ascii.isHex(byte)) {
                const digit = std.fmt.charToDigit(byte, 16) catch 0;
                hex_val = hex_val * 16 + digit;
            }
        }
        
        try self.addChar(hex_val);
    }
    
    fn skipBinaryData(self: *FormattedParser, size: u32) !void {
        for (0..size) |_| {
            _ = try self.reader.next() orelse break;
        }
    }
    
    // Table handling methods using specialized parser
    fn startTableRow(self: *FormattedParser) !void {
        try self.flushTextBuffer();
        try self.table_parser.startRow();
        self.current_destination = .table_content;
    }
    
    fn setCellWidth(self: *FormattedParser, width: u32) !void {
        try self.table_parser.setCellWidth(width);
    }
    
    fn endTableCell(self: *FormattedParser) !void {
        try self.flushTextBuffer();
        try self.table_parser.finishCell();
    }
    
    fn endTableRow(self: *FormattedParser) !void {
        try self.flushTextBuffer();
        try self.table_parser.finishRow();
        
        // Add finished table to document
        if (try self.table_parser.finishTable()) |table| {
            try self.document.addElement(.{ .table = table });
        }
        
        self.current_destination = .normal;
    }
    
    fn addChar(self: *FormattedParser, char: u8) !void {
        try self.text_buffer.append(char);
    }
    
    fn flushTextBuffer(self: *FormattedParser) !void {
        if (self.text_buffer.items.len == 0) return;
        
        switch (self.current_destination) {
            .normal => {
                try self.document.addTextRun(
                    self.text_buffer.items,
                    self.current_format.char_format,
                    self.current_format.para_format
                );
            },
            .field_result => {
                try self.field_result.appendSlice(self.text_buffer.items);
            },
            .table_content => {
                // Add text run to current table cell
                const run = doc_model.TextRun.init(
                    try self.document.arena.allocator().dupe(u8, self.text_buffer.items),
                    self.current_format.char_format,
                    self.current_format.para_format
                );
                try self.table_parser.addCellContent(.{ .text_run = run });
            },
            else => {}, // Skip for other destinations
        }
        
        self.text_buffer.clearRetainingCapacity();
    }
};

// Basic tests to ensure compilation and functionality
test "formatted parser - simple text" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Hello World!}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = FormattedParser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    var document = try parser.parse();
    defer document.deinit();
    
    const text = try document.getPlainText();
    try testing.expectEqualStrings("Hello World!", text);
}

test "formatted parser - bold and italic" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Hello \\b bold\\b0  and \\i italic\\i0  text!}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = FormattedParser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    var document = try parser.parse();
    defer document.deinit();
    
    const text = try document.getPlainText();
    try testing.expectEqualStrings("Hello bold and italic text!", text);
    
    const runs = try document.getTextRuns(testing.allocator);
    defer testing.allocator.free(runs);
    
    // Should have multiple runs with different formatting
    try testing.expect(runs.len >= 3); // Hello, bold, and italic etc
}

test "formatted parser - font and color tables" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1\\ansi\\deff0 {\\fonttbl{\\f0\\fswiss Arial;}{\\f1\\froman Times New Roman;}}{\\colortbl;\\red255\\green0\\blue0;\\red0\\green255\\blue0;}Hello \\f1\\cf1 World \\f0\\cf2 !}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = FormattedParser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    var document = try parser.parse();
    defer document.deinit();
    
    const text = try document.getPlainText();
    try testing.expectEqualStrings("Hello World !", text);
    
    // Check font table
    try testing.expect(document.font_table.items.len >= 2);
    try testing.expectEqualStrings("Arial", document.font_table.items[0].name);
    try testing.expectEqualStrings("Times New Roman", document.font_table.items[1].name);
    try testing.expectEqual(doc_model.FontInfo.FontFamily.swiss, document.font_table.items[0].family);
    try testing.expectEqual(doc_model.FontInfo.FontFamily.roman, document.font_table.items[1].family);
    
    // Check color table
    try testing.expect(document.color_table.items.len >= 3);
    // Color 0: auto (black), Color 1: empty entry, Color 2: red, Color 3: green
    try testing.expectEqual(@as(u8, 255), document.color_table.items[2].red);
    try testing.expectEqual(@as(u8, 0), document.color_table.items[2].green);
    try testing.expectEqual(@as(u8, 0), document.color_table.items[2].blue);
    try testing.expectEqual(@as(u8, 0), document.color_table.items[3].red);
    try testing.expectEqual(@as(u8, 255), document.color_table.items[3].green);
    try testing.expectEqual(@as(u8, 0), document.color_table.items[3].blue);
    
    // Check text runs have formatting
    const runs = try document.getTextRuns(testing.allocator);
    defer testing.allocator.free(runs);
    try testing.expect(runs.len >= 3); // Should have multiple formatted runs
}