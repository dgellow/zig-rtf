const std = @import("std");

// =============================================================================
// COMPLETE RTF DOCUMENT MODEL
// =============================================================================
// This replaces the simple text-only approach with a full document model
// that preserves all formatting and structure information.

// Font table entry
pub const FontInfo = struct {
    id: u16,
    name: []const u8,
    family: FontFamily = .dontcare,
    charset: u8 = 0,
    
    pub const FontFamily = enum(u8) {
        dontcare = 0,
        roman = 1,
        swiss = 2,
        modern = 3,
        script = 4,
        decorative = 5,
    };
};

// Color table entry
pub const ColorInfo = struct {
    id: u16,
    red: u8,
    green: u8,
    blue: u8,
    
    pub fn fromRgb(r: u8, g: u8, b: u8) ColorInfo {
        return .{ .id = 0, .red = r, .green = g, .blue = b };
    }
    
    pub fn toU32(self: ColorInfo) u32 {
        return (@as(u32, self.red) << 16) | (@as(u32, self.green) << 8) | @as(u32, self.blue);
    }
};

// Character formatting state
pub const CharFormat = struct {
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    strikethrough: bool = false,
    superscript: bool = false,
    subscript: bool = false,
    
    font_id: ?u16 = null,
    font_size: ?u16 = null, // Half-points (24 = 12pt)
    color_id: ?u16 = null,
    
    // Copy constructor for format stack
    pub fn copy(self: CharFormat) CharFormat {
        return .{
            .bold = self.bold,
            .italic = self.italic,
            .underline = self.underline,
            .strikethrough = self.strikethrough,
            .superscript = self.superscript,
            .subscript = self.subscript,
            .font_id = self.font_id,
            .font_size = self.font_size,
            .color_id = self.color_id,
        };
    }
    
    // Check if two formats are equivalent
    pub fn equals(self: CharFormat, other: CharFormat) bool {
        return self.bold == other.bold and
               self.italic == other.italic and
               self.underline == other.underline and
               self.strikethrough == other.strikethrough and
               self.superscript == other.superscript and
               self.subscript == other.subscript and
               self.font_id == other.font_id and
               self.font_size == other.font_size and
               self.color_id == other.color_id;
    }
};

// Paragraph formatting state
pub const ParaFormat = struct {
    alignment: Alignment = .left,
    left_indent: i32 = 0,    // Twips (1/1440 inch)
    right_indent: i32 = 0,   // Twips
    first_line_indent: i32 = 0, // Twips
    space_before: u16 = 0,   // Twips
    space_after: u16 = 0,    // Twips
    line_spacing: LineSpacing = .single,
    
    pub const Alignment = enum(u8) {
        left = 0,
        center = 1,
        right = 2,
        justify = 3,
    };
    
    pub const LineSpacing = enum(u8) {
        single = 0,
        one_and_half = 1,
        double = 2,
        exact = 3,    // Exact spacing in twips
        multiple = 4, // Multiple of single spacing
    };
    
    pub fn copy(self: ParaFormat) ParaFormat {
        return .{
            .alignment = self.alignment,
            .left_indent = self.left_indent,
            .right_indent = self.right_indent,
            .first_line_indent = self.first_line_indent,
            .space_before = self.space_before,
            .space_after = self.space_after,
            .line_spacing = self.line_spacing,
        };
    }
};

// Table cell information
pub const TableCell = struct {
    content: std.ArrayList(ContentElement),
    width: u32, // Twips
    border_left: bool = false,
    border_right: bool = false,
    border_top: bool = false,
    border_bottom: bool = false,
    
    pub fn init(allocator: std.mem.Allocator) TableCell {
        return .{ .content = std.ArrayList(ContentElement).init(allocator), .width = 0 };
    }
    
    pub fn deinit(self: *TableCell) void {
        for (self.content.items) |*element| {
            element.deinit();
        }
        self.content.deinit();
    }
};

// Table row information
pub const TableRow = struct {
    cells: std.ArrayList(TableCell),
    height: u32 = 0, // Twips
    
    pub fn init(allocator: std.mem.Allocator) TableRow {
        return .{ .cells = std.ArrayList(TableCell).init(allocator) };
    }
    
    pub fn deinit(self: *TableRow) void {
        for (self.cells.items) |*cell| {
            cell.deinit();
        }
        self.cells.deinit();
    }
};

// Image/object information
pub const ImageInfo = struct {
    format: ImageFormat,
    width: u32,  // Twips
    height: u32, // Twips
    data: []const u8,
    
    pub const ImageFormat = enum {
        emf,
        wmf,
        pict,
        jpeg,
        png,
        unknown,
    };
    
    // No deinit needed - data is allocated in document arena
};

// Hyperlink information
pub const HyperlinkInfo = struct {
    url: []const u8,
    display_text: []const u8,
    
    // No deinit needed - data is allocated in document arena
};

// Content element - represents any piece of content in the document
pub const ContentElement = union(enum) {
    text_run: TextRun,
    paragraph_break: void,
    line_break: void,
    page_break: void,
    table: Table,
    image: ImageInfo,
    hyperlink: HyperlinkInfo,
    
    pub fn deinit(self: *ContentElement) void {
        switch (self.*) {
            .text_run => |*run| run.deinit(),
            .table => |*table| table.deinit(),
            // Images and hyperlinks are allocated in the document arena,
            // so they don't need individual cleanup
            .image => {},
            .hyperlink => {},
            else => {},
        }
    }
};

// Text run with formatting
pub const TextRun = struct {
    text: []const u8,
    char_format: CharFormat,
    para_format: ParaFormat,
    
    pub fn init(text: []const u8, char_fmt: CharFormat, para_fmt: ParaFormat) TextRun {
        return .{
            .text = text,
            .char_format = char_fmt,
            .para_format = para_fmt,
        };
    }
    
    pub fn deinit(self: *TextRun) void {
        // Text is arena-allocated, no need to free
        _ = self;
    }
};

// Table structure
pub const Table = struct {
    rows: std.ArrayList(TableRow),
    
    pub fn init(allocator: std.mem.Allocator) Table {
        return .{ .rows = std.ArrayList(TableRow).init(allocator) };
    }
    
    pub fn deinit(self: *Table) void {
        for (self.rows.items) |*row| {
            row.deinit();
        }
        self.rows.deinit();
    }
};

// Complete document structure
pub const Document = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    
    // Document content
    content: std.ArrayList(ContentElement),
    
    // Document tables
    font_table: std.ArrayList(FontInfo),
    color_table: std.ArrayList(ColorInfo),
    
    // Document properties
    default_font: u16 = 0,
    default_font_size: u16 = 24, // 12pt
    code_page: u16 = 1252, // Windows-1252
    rtf_version: u16 = 1,
    
    pub fn init(allocator: std.mem.Allocator) !Document {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .content = std.ArrayList(ContentElement).init(allocator),
            .font_table = std.ArrayList(FontInfo).init(allocator),
            .color_table = std.ArrayList(ColorInfo).init(allocator),
        };
    }
    
    pub fn deinit(self: *Document) void {
        for (self.content.items) |*element| {
            element.deinit();
        }
        self.content.deinit();
        self.font_table.deinit();
        self.color_table.deinit();
        self.arena.deinit();
    }
    
    // Add content element to document
    pub fn addElement(self: *Document, element: ContentElement) !void {
        try self.content.append(element);
    }
    
    // Add text run with current formatting
    pub fn addTextRun(self: *Document, text: []const u8, char_fmt: CharFormat, para_fmt: ParaFormat) !void {
        // Store text in arena
        const owned_text = try self.arena.allocator().dupe(u8, text);
        const run = TextRun.init(owned_text, char_fmt, para_fmt);
        try self.addElement(.{ .text_run = run });
    }
    
    // Add font to font table
    pub fn addFont(self: *Document, font: FontInfo) !void {
        try self.font_table.append(font);
    }
    
    // Add color to color table  
    pub fn addColor(self: *Document, color: ColorInfo) !void {
        try self.color_table.append(color);
    }
    
    // Get font by ID
    pub fn getFont(self: *const Document, font_id: u16) ?FontInfo {
        for (self.font_table.items) |font| {
            if (font.id == font_id) return font;
        }
        return null;
    }
    
    // Get color by ID
    pub fn getColor(self: *const Document, color_id: u16) ?ColorInfo {
        for (self.color_table.items) |color| {
            if (color.id == color_id) return color;
        }
        return null;
    }
    
    // Extract plain text from document
    pub fn getPlainText(self: *Document) ![]const u8 {
        var text = std.ArrayList(u8).init(self.allocator);
        defer text.deinit();
        
        for (self.content.items) |element| {
            switch (element) {
                .text_run => |run| try text.appendSlice(run.text),
                .paragraph_break => try text.appendSlice("\n\n"),
                .line_break => try text.append('\n'),
                .page_break => try text.appendSlice("\n\n"),
                .hyperlink => |link| try text.appendSlice(link.display_text),
                .table => |table| {
                    for (table.rows.items) |row| {
                        for (row.cells.items) |cell| {
                            for (cell.content.items) |cell_element| {
                                switch (cell_element) {
                                    .text_run => |run| try text.appendSlice(run.text),
                                    else => {},
                                }
                            }
                            try text.append('\t'); // Tab between cells
                        }
                        try text.append('\n'); // Newline after row
                    }
                },
                else => {},
            }
        }
        
        return try self.arena.allocator().dupe(u8, text.items);
    }
    
    // Get all text runs for C API compatibility
    pub fn getTextRuns(self: *Document, allocator: std.mem.Allocator) ![]TextRun {
        var runs = std.ArrayList(TextRun).init(allocator);
        defer runs.deinit();
        
        for (self.content.items) |element| {
            switch (element) {
                .text_run => |run| try runs.append(run),
                .hyperlink => |link| {
                    // Create a text run for hyperlink display text
                    const run = TextRun.init(link.display_text, .{}, .{});
                    try runs.append(run);
                },
                .table => |table| {
                    for (table.rows.items) |row| {
                        for (row.cells.items) |cell| {
                            for (cell.content.items) |cell_element| {
                                switch (cell_element) {
                                    .text_run => |run| try runs.append(run),
                                    else => {},
                                }
                            }
                        }
                    }
                },
                else => {},
            }
        }
        
        return try allocator.dupe(TextRun, runs.items);
    }
    
    // Generate RTF from document
    pub fn generateRtf(self: *const Document, allocator: std.mem.Allocator) ![]u8 {
        var rtf = std.ArrayList(u8).init(allocator);
        defer rtf.deinit();
        
        // RTF header
        try rtf.appendSlice("{\\rtf1\\ansi\\deff0");
        
        // Font table
        if (self.font_table.items.len > 0) {
            try rtf.appendSlice("{\\fonttbl");
            for (self.font_table.items) |font| {
                try rtf.writer().print("{{\\f{}\\f{s} {s};}}", .{
                    font.id,
                    switch (font.family) {
                        .swiss => "swiss",
                        .roman => "roman", 
                        .modern => "modern",
                        .script => "script",
                        .decorative => "decor",
                        .dontcare => "nil",
                    },
                    font.name
                });
            }
            try rtf.append('}');
        }
        
        // Color table
        if (self.color_table.items.len > 0) {
            try rtf.appendSlice("{\\colortbl");
            for (self.color_table.items) |color| {
                if (color.id == 0) {
                    try rtf.append(';'); // Auto color
                } else {
                    try rtf.writer().print("\\red{}\\green{}\\blue{};", .{color.red, color.green, color.blue});
                }
            }
            try rtf.append('}');
        }
        
        // Document content
        try self.generateContent(&rtf);
        
        // Close RTF
        try rtf.append('}');
        
        return rtf.toOwnedSlice();
    }
    
    fn generateContent(self: *const Document, rtf: *std.ArrayList(u8)) !void {
        for (self.content.items) |element| {
            switch (element) {
                .text_run => |run| {
                    try self.generateTextRun(rtf, run);
                },
                .paragraph_break => {
                    try rtf.appendSlice("\\par ");
                },
                .line_break => {
                    try rtf.appendSlice("\\line ");
                },
                .page_break => {
                    try rtf.appendSlice("\\page ");
                },
                .table => |table| {
                    try self.generateTable(rtf, table);
                },
                .image => |image| {
                    try self.generateImage(rtf, image);
                },
                .hyperlink => |link| {
                    try rtf.writer().print("{{\\field{{\\*\\fldinst HYPERLINK \"{s}\"}}{{\\fldrslt {s}}}}}", .{link.url, link.display_text});
                },
            }
        }
    }
    
    fn generateTextRun(self: *const Document, rtf: *std.ArrayList(u8), run: TextRun) !void {
        _ = self; // unused in this implementation
        
        // Start format group if needed
        var needs_group = false;
        
        // Check if we need formatting
        if (run.char_format.bold or run.char_format.italic or run.char_format.underline or
            run.char_format.strikethrough or run.char_format.superscript or run.char_format.subscript or
            run.char_format.font_id != null or run.char_format.font_size != null or run.char_format.color_id != null) {
            try rtf.append('{');
            needs_group = true;
        }
        
        // Character formatting
        if (run.char_format.bold) try rtf.appendSlice("\\b ");
        if (run.char_format.italic) try rtf.appendSlice("\\i ");
        if (run.char_format.underline) try rtf.appendSlice("\\ul ");
        if (run.char_format.strikethrough) try rtf.appendSlice("\\strike ");
        if (run.char_format.superscript) try rtf.appendSlice("\\super ");
        if (run.char_format.subscript) try rtf.appendSlice("\\sub ");
        
        if (run.char_format.font_id) |font_id| {
            try rtf.writer().print("\\f{} ", .{font_id});
        }
        
        if (run.char_format.font_size) |size| {
            try rtf.writer().print("\\fs{} ", .{size});
        }
        
        if (run.char_format.color_id) |color_id| {
            try rtf.writer().print("\\cf{} ", .{color_id});
        }
        
        // Paragraph formatting (only if different from default)
        if (run.para_format.alignment != .left) {
            switch (run.para_format.alignment) {
                .center => try rtf.appendSlice("\\qc "),
                .right => try rtf.appendSlice("\\qr "),
                .justify => try rtf.appendSlice("\\qj "),
                .left => {},
            }
        }
        
        if (run.para_format.left_indent != 0) {
            try rtf.writer().print("\\li{} ", .{run.para_format.left_indent});
        }
        
        if (run.para_format.right_indent != 0) {
            try rtf.writer().print("\\ri{} ", .{run.para_format.right_indent});
        }
        
        if (run.para_format.first_line_indent != 0) {
            try rtf.writer().print("\\fi{} ", .{run.para_format.first_line_indent});
        }
        
        // Escape special characters and output text
        try escapeRtfText(rtf, run.text);
        
        // Close format group
        if (needs_group) {
            try rtf.append('}');
        }
    }
    
    fn generateTable(self: *const Document, rtf: *std.ArrayList(u8), table: Table) !void {
        
        for (table.rows.items) |row| {
            // Table row definition
            try rtf.appendSlice("\\trowd ");
            
            var cell_x: u32 = 0;
            for (row.cells.items) |cell| {
                cell_x += cell.width;
                try rtf.writer().print("\\cellx{} ", .{cell_x});
            }
            
            // Table row content
            for (row.cells.items) |cell| {
                for (cell.content.items) |cell_element| {
                    switch (cell_element) {
                        .text_run => |run| try self.generateTextRun(rtf, run),
                        else => {},
                    }
                }
                try rtf.appendSlice("\\cell ");
            }
            
            try rtf.appendSlice("\\row ");
        }
    }
    
    fn generateImage(self: *const Document, rtf: *std.ArrayList(u8), image: ImageInfo) !void {
        _ = self;
        
        try rtf.appendSlice("{\\pict");
        
        // Image format
        switch (image.format) {
            .wmf => try rtf.appendSlice("\\wmetafile8"),
            .emf => try rtf.appendSlice("\\emfblip"),
            .pict => try rtf.appendSlice("\\macpict"),
            .jpeg => try rtf.appendSlice("\\jpegblip"),
            .png => try rtf.appendSlice("\\pngblip"),
            .unknown => try rtf.appendSlice("\\wmetafile8"), // Default
        }
        
        // Image dimensions
        try rtf.writer().print("\\picw{}\\pich{} ", .{image.width, image.height});
        
        // Image data as hex
        for (image.data) |byte| {
            try rtf.writer().print("{x:0>2}", .{byte});
        }
        
        try rtf.append('}');
    }
};

fn escapeRtfText(rtf: *std.ArrayList(u8), text: []const u8) !void {
    for (text) |char| {
        switch (char) {
            '\\' => try rtf.appendSlice("\\\\"),
            '{' => try rtf.appendSlice("\\{"),
            '}' => try rtf.appendSlice("\\}"),
            '\n' => try rtf.appendSlice("\\line "),
            '\r' => {}, // Skip carriage returns
            '\t' => try rtf.appendSlice("\\tab "),
            0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F, 0x7F...0xFF => {
                // Non-ASCII characters - use hex escape
                try rtf.writer().print("\\'{x:0>2}", .{char});
            },
            else => try rtf.append(char),
        }
    }
}

// Format state for parser - tracks current formatting during parsing
pub const FormatState = struct {
    char_format: CharFormat = .{},
    para_format: ParaFormat = .{},
    
    pub fn copy(self: FormatState) FormatState {
        return .{
            .char_format = self.char_format.copy(),
            .para_format = self.para_format.copy(),
        };
    }
    
    // Reset character formatting to defaults
    pub fn resetCharFormat(self: *FormatState) void {
        self.char_format = .{};
    }
    
    // Reset paragraph formatting to defaults
    pub fn resetParaFormat(self: *FormatState) void {
        self.para_format = .{};
    }
};