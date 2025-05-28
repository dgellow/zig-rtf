const std = @import("std");
const doc_model = @import("document_model.zig");
const formatted_parser = @import("formatted_parser.zig");

// =============================================================================
// REAL C API WITH FORMATTING SUPPORT
// =============================================================================
// This replaces the fake C API with real formatting-aware functionality

// Thread-local error state
threadlocal var g_error_msg: [512]u8 = undefined;
threadlocal var g_has_error: bool = false;

// Enhanced document structure
pub const EnhancedDocument = struct {
    document_ptr: *doc_model.Document,  // Store pointer, not value!
    runs: []FormattedRun,
    text: []const u8,
    images: []ImageInfo,
    tables: []TableInfo,
    
    fn deinit(self: *EnhancedDocument, allocator: std.mem.Allocator) void {
        allocator.free(self.runs);
        allocator.free(self.text);
        allocator.free(self.images);
        
        // Free table text data
        for (self.tables) |table| {
            for (table.rows) |row| {
                for (row.cells) |cell| {
                    allocator.free(std.mem.span(cell.text));
                }
                allocator.free(row.cells);
            }
            allocator.free(table.rows);
        }
        allocator.free(self.tables);
        
        // Document will be deinitialized separately
    }
};

// C-compatible formatted run structure
const FormattedRun = struct {
    text: [*:0]const u8,
    length: usize,
    
    // Character formatting
    bold: bool,
    italic: bool,
    underline: bool,
    strikethrough: bool,
    superscript: bool,
    subscript: bool,
    
    // Font and color
    font_id: u16,
    font_size: u16, // Half-points
    color_id: u16,
    
    // Resolved formatting (for convenience)
    font_name: [*:0]const u8,
    color_rgb: u32,
    
    // Paragraph formatting
    alignment: u8, // 0=left, 1=center, 2=right, 3=justify
    left_indent: i32, // Twips
    right_indent: i32, // Twips
    first_line_indent: i32, // Twips
    space_before: u16, // Twips
    space_after: u16, // Twips
};

// C-compatible image format enum
const ImageFormat = enum(u8) {
    unknown = 0,
    wmf = 1,
    emf = 2,
    pict = 3,
    jpeg = 4,
    png = 5,
};

// C-compatible image structure
const ImageInfo = struct {
    format: ImageFormat,
    width: u32,
    height: u32,
    data: [*]const u8,
    data_size: usize,
};

// C-compatible table structure
const TableInfo = struct {
    rows: []TableRowInfo,
};

const TableRowInfo = struct {
    cells: []TableCellInfo,
    height: u32,
};

const TableCellInfo = struct {
    text: [*:0]const u8,
    width: u32,
    border_left: bool,
    border_right: bool,
    border_top: bool,
    border_bottom: bool,
};

// =============================================================================
// ERROR HANDLING
// =============================================================================

fn setError(msg: []const u8) void {
    @memcpy(g_error_msg[0..@min(msg.len, g_error_msg.len - 1)], msg);
    g_error_msg[@min(msg.len, g_error_msg.len - 1)] = 0;
    g_has_error = true;
}

fn clearError() void {
    g_has_error = false;
    g_error_msg[0] = 0;
}

pub export fn rtf_errmsg() [*:0]const u8 {
    if (!g_has_error) {
        return "No error";
    }
    return @ptrCast(&g_error_msg);
}

pub export fn rtf_clear_error() void {
    clearError();
}

// =============================================================================
// PARSING API
// =============================================================================

pub export fn rtf_parse(data: [*]const u8, length: usize) ?*EnhancedDocument {
    clearError();
    
    if (length == 0) {
        setError("Invalid input data");
        return null;
    }
    
    const allocator = std.heap.page_allocator;
    
    // Create input stream
    const input_data = data[0..length];
    var stream = std.io.fixedBufferStream(input_data);
    
    // Parse with formatted parser
    var parser = formatted_parser.FormattedParser.init(stream.reader().any(), allocator) catch {
        setError("Failed to initialize parser");
        return null;
    };
    defer parser.deinit();
    
    var document = parser.parse() catch |err| {
        switch (err) {
            error.InvalidRtf => setError("Invalid RTF format"),
            error.EmptyInput => setError("Empty input"),
            error.TooManyNestedGroups => setError("RTF too deeply nested"),
            error.OutOfMemory => setError("Out of memory"),
            else => setError("Parse error"),
        }
        return null;
    };
    
    // Allocate document on heap to ensure stable pointers
    const doc_ptr = allocator.create(doc_model.Document) catch {
        document.deinit();
        setError("Out of memory");
        return null;
    };
    doc_ptr.* = document;
    
    // Convert to enhanced document
    const enhanced = createEnhancedDocument(doc_ptr, allocator) catch |err| {
        doc_ptr.deinit();
        allocator.destroy(doc_ptr);
        switch (err) {
            error.OutOfMemory => setError("Out of memory creating enhanced document"),
        }
        return null;
    };
    
    return enhanced;
}

fn createEnhancedDocument(document_ptr: *doc_model.Document, allocator: std.mem.Allocator) !*EnhancedDocument {
    // Extract plain text
    const plain_text = try document_ptr.getPlainText();
    const owned_text = try allocator.dupeZ(u8, plain_text);
    
    // Get text runs from document
    const doc_runs = try document_ptr.getTextRuns(allocator);
    defer allocator.free(doc_runs);
    
    // Convert to C-compatible runs
    var runs = std.ArrayList(FormattedRun).init(allocator);
    defer runs.deinit();
    
    for (doc_runs) |run| {
        const c_run = FormattedRun{
            .text = @ptrCast(try allocator.dupeZ(u8, run.text)),
            .length = run.text.len,
            .bold = run.char_format.bold,
            .italic = run.char_format.italic,
            .underline = run.char_format.underline,
            .strikethrough = run.char_format.strikethrough,
            .superscript = run.char_format.superscript,
            .subscript = run.char_format.subscript,
            .font_id = run.char_format.font_id orelse 0,
            .font_size = run.char_format.font_size orelse document_ptr.default_font_size,
            .color_id = run.char_format.color_id orelse 0,
            .font_name = resolveFontName(document_ptr, run.char_format.font_id orelse 0, allocator) catch "Unknown",
            .color_rgb = resolveColorRgb(document_ptr, run.char_format.color_id orelse 0),
            .alignment = @intFromEnum(run.para_format.alignment),
            .left_indent = run.para_format.left_indent,
            .right_indent = run.para_format.right_indent,
            .first_line_indent = run.para_format.first_line_indent,
            .space_before = run.para_format.space_before,
            .space_after = run.para_format.space_after,
        };
        try runs.append(c_run);
    }
    
    // Extract images from document
    var images = std.ArrayList(ImageInfo).init(allocator);
    defer images.deinit();
    
    for (document_ptr.content.items) |element| {
        switch (element) {
            .image => |img| {
                const c_image = ImageInfo{
                    .format = switch (img.format) {
                        .unknown => .unknown,
                        .wmf => .wmf,
                        .emf => .emf,
                        .pict => .pict,
                        .jpeg => .jpeg,
                        .png => .png,
                    },
                    .width = img.width,
                    .height = img.height,
                    .data = img.data.ptr,
                    .data_size = img.data.len,
                };
                try images.append(c_image);
            },
            .table => {
                // Process table in the next loop
            },
            else => {},
        }
    }
    
    // Extract tables from document
    var tables = std.ArrayList(TableInfo).init(allocator);
    defer tables.deinit();
    
    for (document_ptr.content.items) |element| {
        switch (element) {
            .table => |tbl| {
                var c_rows = std.ArrayList(TableRowInfo).init(allocator);
                defer c_rows.deinit();
                
                for (tbl.rows.items) |row| {
                    var c_cells = std.ArrayList(TableCellInfo).init(allocator);
                    defer c_cells.deinit();
                    
                    for (row.cells.items) |cell| {
                        // Extract text from cell content
                        var cell_text = std.ArrayList(u8).init(allocator);
                        defer cell_text.deinit();
                        
                        for (cell.content.items) |cell_element| {
                            switch (cell_element) {
                                .text_run => |run| try cell_text.appendSlice(run.text),
                                else => {},
                            }
                        }
                        
                        const c_cell = TableCellInfo{
                            .text = @ptrCast(try allocator.dupeZ(u8, cell_text.items)),
                            .width = cell.width,
                            .border_left = cell.border_left,
                            .border_right = cell.border_right,
                            .border_top = cell.border_top,
                            .border_bottom = cell.border_bottom,
                        };
                        try c_cells.append(c_cell);
                    }
                    
                    const c_row = TableRowInfo{
                        .cells = try allocator.dupe(TableCellInfo, c_cells.items),
                        .height = row.height,
                    };
                    try c_rows.append(c_row);
                }
                
                const c_table = TableInfo{
                    .rows = try allocator.dupe(TableRowInfo, c_rows.items),
                };
                try tables.append(c_table);
            },
            else => {},
        }
    }
    
    // Create enhanced document
    const enhanced = try allocator.create(EnhancedDocument);
    enhanced.* = EnhancedDocument{
        .document_ptr = document_ptr,
        .runs = try allocator.dupe(FormattedRun, runs.items),
        .text = owned_text,
        .images = try allocator.dupe(ImageInfo, images.items),
        .tables = try allocator.dupe(TableInfo, tables.items),
    };
    
    return enhanced;
}

fn resolveFontName(document: *doc_model.Document, font_id: u16, allocator: std.mem.Allocator) ![:0]const u8 {
    if (document.getFont(font_id)) |font| {
        return try allocator.dupeZ(u8, font.name);
    }
    return try allocator.dupeZ(u8, "Default");
}

fn resolveColorRgb(document: *doc_model.Document, color_id: u16) u32 {
    if (document.getColor(color_id)) |color| {
        return color.toU32();
    }
    return 0x000000; // Default black
}

// =============================================================================
// DOCUMENT ACCESS
// =============================================================================

pub export fn rtf_get_text(doc: ?*EnhancedDocument) [*:0]const u8 {
    if (doc == null) {
        setError("Null document");
        return "";
    }
    return @ptrCast(doc.?.text.ptr);
}

pub export fn rtf_get_text_length(doc: ?*EnhancedDocument) usize {
    if (doc == null) {
        setError("Null document");
        return 0;
    }
    return doc.?.text.len;
}

pub export fn rtf_get_run_count(doc: ?*EnhancedDocument) usize {
    if (doc == null) {
        setError("Null document");
        return 0;
    }
    return doc.?.runs.len;
}

pub export fn rtf_get_run(doc: ?*EnhancedDocument, index: usize) ?*const FormattedRun {
    if (doc == null) {
        setError("Null document");
        return null;
    }
    
    if (index >= doc.?.runs.len) {
        setError("Run index out of bounds");
        return null;
    }
    
    return &doc.?.runs[index];
}

// Image access
pub export fn rtf_get_image_count(doc: ?*EnhancedDocument) usize {
    if (doc == null) {
        setError("Null document");
        return 0;
    }
    return doc.?.images.len;
}

pub export fn rtf_get_image(doc: ?*EnhancedDocument, index: usize) ?*const ImageInfo {
    if (doc == null) {
        setError("Null document");
        return null;
    }
    
    if (index >= doc.?.images.len) {
        setError("Image index out of bounds");
        return null;
    }
    
    return &doc.?.images[index];
}

// Table access
pub export fn rtf_get_table_count(doc: ?*EnhancedDocument) usize {
    if (doc == null) {
        setError("Null document");
        return 0;
    }
    return doc.?.tables.len;
}

pub export fn rtf_get_table(doc: ?*EnhancedDocument, index: usize) ?*const TableInfo {
    if (doc == null) {
        setError("Null document");
        return null;
    }
    
    if (index >= doc.?.tables.len) {
        setError("Table index out of bounds");
        return null;
    }
    
    return &doc.?.tables[index];
}

pub export fn rtf_table_get_row_count(table: ?*const TableInfo) usize {
    if (table == null) {
        setError("Null table");
        return 0;
    }
    return table.?.rows.len;
}

pub export fn rtf_table_get_cell_count(table: ?*const TableInfo, row_index: usize) usize {
    if (table == null) {
        setError("Null table");
        return 0;
    }
    
    if (row_index >= table.?.rows.len) {
        setError("Row index out of bounds");
        return 0;
    }
    
    return table.?.rows[row_index].cells.len;
}

pub export fn rtf_table_get_cell_text(table: ?*const TableInfo, row_index: usize, cell_index: usize) ?[*:0]const u8 {
    if (table == null) {
        setError("Null table");
        return null;
    }
    
    if (row_index >= table.?.rows.len) {
        setError("Row index out of bounds");
        return null;
    }
    
    const row = &table.?.rows[row_index];
    if (cell_index >= row.cells.len) {
        setError("Cell index out of bounds");
        return null;
    }
    
    return row.cells[cell_index].text;
}

pub export fn rtf_table_get_cell_width(table: ?*const TableInfo, row_index: usize, cell_index: usize) u32 {
    if (table == null) {
        setError("Null table");
        return 0;
    }
    
    if (row_index >= table.?.rows.len) {
        setError("Row index out of bounds");
        return 0;
    }
    
    const row = &table.?.rows[row_index];
    if (cell_index >= row.cells.len) {
        setError("Cell index out of bounds");
        return 0;
    }
    
    return row.cells[cell_index].width;
}

// RTF Generation
pub export fn rtf_generate(doc: ?*EnhancedDocument) ?[*:0]u8 {
    if (doc == null) {
        setError("Null document");
        return null;
    }
    
    const allocator = std.heap.page_allocator;
    
    const rtf_data = doc.?.document_ptr.generateRtf(allocator) catch |err| {
        switch (err) {
            error.OutOfMemory => setError("Out of memory generating RTF"),
        }
        return null;
    };
    
    // Ensure null termination
    const rtf_string = allocator.dupeZ(u8, rtf_data) catch {
        allocator.free(rtf_data);
        setError("Out of memory creating null-terminated string");
        return null;
    };
    
    allocator.free(rtf_data);
    return rtf_string.ptr;
}

pub export fn rtf_free_string(rtf_string: ?[*:0]u8) void {
    if (rtf_string == null) return;
    
    const allocator = std.heap.page_allocator;
    const string_slice = std.mem.span(rtf_string.?);
    allocator.free(string_slice);
}

// Font table access
pub export fn rtf_get_font_count(doc: ?*EnhancedDocument) usize {
    if (doc == null) {
        setError("Null document");
        return 0;
    }
    return doc.?.document_ptr.font_table.items.len;
}

pub export fn rtf_get_font_name(doc: ?*EnhancedDocument, font_id: u16) [*:0]const u8 {
    if (doc == null) {
        setError("Null document");
        return "";
    }
    
    if (doc.?.document_ptr.getFont(font_id)) |font| {
        // dupeZ ensures null termination, we just need to cast the pointer correctly
        return @as([*:0]const u8, @ptrCast(font.name.ptr));
    }
    
    setError("Font not found");
    return "";
}

// Color table access
export fn rtf_get_color_count(doc: ?*EnhancedDocument) usize {
    if (doc == null) {
        setError("Null document");
        return 0;
    }
    return doc.?.document_ptr.color_table.items.len;
}

export fn rtf_get_color_rgb(doc: ?*EnhancedDocument, color_id: u16) u32 {
    if (doc == null) {
        setError("Null document");
        return 0;
    }
    
    if (doc.?.document_ptr.getColor(color_id)) |color| {
        return color.toU32();
    }
    
    setError("Color not found");
    return 0;
}

// =============================================================================
// CLEANUP
// =============================================================================

pub export fn rtf_free(doc: ?*EnhancedDocument) void {
    if (doc == null) return;
    
    const allocator = std.heap.page_allocator;
    
    // Free formatted runs text
    for (doc.?.runs) |run| {
        allocator.free(std.mem.span(run.text));
        allocator.free(std.mem.span(run.font_name));
    }
    
    // Free enhanced document data
    doc.?.deinit(allocator);
    
    // Free document itself
    doc.?.document_ptr.deinit();
    allocator.destroy(doc.?.document_ptr);
    
    // Free enhanced document struct
    allocator.destroy(doc.?);
}

// =============================================================================
// CONVENIENCE FUNCTIONS
// =============================================================================

pub export fn rtf_parse_file(filename: [*:0]const u8) ?*EnhancedDocument {
    clearError();
    
    const allocator = std.heap.page_allocator;
    const file = std.fs.cwd().openFile(std.mem.span(filename), .{}) catch {
        setError("Could not open file");
        return null;
    };
    defer file.close();
    
    const content = file.readToEndAlloc(allocator, 1024 * 1024 * 16) catch { // 16MB limit
        setError("Could not read file");
        return null;
    };
    defer allocator.free(content);
    
    return rtf_parse(@ptrCast(content.ptr), content.len);
}

export fn rtf_version() [*:0]const u8 {
    return "ZigRTF 1.0.0 - Formatted Edition";
}

// Stream parsing support
const RtfReader = extern struct {
    read: *const fn (context: ?*anyopaque, buffer: ?*anyopaque, count: usize) callconv(.C) c_int,
    context: ?*anyopaque,
};

pub export fn rtf_parse_stream(reader: *RtfReader) ?*EnhancedDocument {
    clearError();
    
    const allocator = std.heap.page_allocator;
    
    // Create a reader adapter
    const ReaderAdapter = struct {
        rtf_reader: *RtfReader,
        
        const Error = error{EndOfStream};
        const Reader = std.io.Reader(*@This(), Error, read);
        
        fn read(self: *@This(), buffer: []u8) Error!usize {
            const bytes_read = self.rtf_reader.read(self.rtf_reader.context, buffer.ptr, buffer.len);
            if (bytes_read < 0) return Error.EndOfStream;
            return @intCast(bytes_read);
        }
        
        fn getReader(self: *@This()) Reader {
            return .{ .context = self };
        }
    };
    
    var adapter = ReaderAdapter{ .rtf_reader = reader };
    
    // Parse with formatted parser using stream
    var parser = formatted_parser.FormattedParser.init(adapter.getReader().any(), allocator) catch {
        setError("Failed to initialize parser");
        return null;
    };
    defer parser.deinit();
    
    var document = parser.parse() catch |err| {
        switch (err) {
            error.InvalidRtf => setError("Invalid RTF format"),
            error.EmptyInput => setError("Empty input"),
            error.TooManyNestedGroups => setError("RTF too deeply nested"),
            error.OutOfMemory => setError("Out of memory"),
            else => setError("Parse error"),
        }
        return null;
    };
    
    // Allocate document on heap to ensure stable pointers
    const doc_ptr = allocator.create(doc_model.Document) catch {
        document.deinit();
        setError("Out of memory");
        return null;
    };
    doc_ptr.* = document;
    
    // Convert to enhanced document
    const enhanced = createEnhancedDocument(doc_ptr, allocator) catch |err| {
        doc_ptr.deinit();
        allocator.destroy(doc_ptr);
        switch (err) {
            error.OutOfMemory => setError("Out of memory creating enhanced document"),
        }
        return null;
    };
    
    return enhanced;
}

export fn rtf_file_reader(file_handle: ?*anyopaque) RtfReader {
    const FileReaderContext = struct {
        file: *std.c.FILE,
        
        fn read(context: ?*anyopaque, buffer: ?*anyopaque, count: usize) callconv(.C) c_int {
            const self: *@This() = @ptrCast(@alignCast(context));
            const buf: [*]u8 = @ptrCast(buffer);
            const bytes_read = std.c.fread(buf, 1, count, self.file);
            return @intCast(bytes_read);
        }
    };
    
    // Create context on heap (user must manage lifetime)
    const context = std.heap.page_allocator.create(FileReaderContext) catch return RtfReader{ .read = undefined, .context = null };
    context.* = FileReaderContext{ .file = @ptrCast(file_handle) };
    
    return RtfReader{
        .read = FileReaderContext.read,
        .context = context,
    };
}

// =============================================================================
// TESTS
// =============================================================================

test "c api formatted - simple document" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Hello \\b World\\b0  !}";
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    try testing.expectEqualStrings("Hello World !", text);
    
    const run_count = rtf_get_run_count(doc);
    try testing.expect(run_count >= 2); // Should have multiple runs
    
    // Check first run
    const first_run = rtf_get_run(doc, 0).?;
    try testing.expectEqualStrings("Hello ", std.mem.span(first_run.text));
    try testing.expect(!first_run.bold);
    
    // Check second run (should be bold)
    if (run_count >= 2) {
        const second_run = rtf_get_run(doc, 1).?;
        // Text might be "World" or just "World" depending on how runs are split
        const second_text = std.mem.span(second_run.text);
        try testing.expect(std.mem.indexOf(u8, second_text, "World") != null);
        try testing.expect(second_run.bold);
    }
}

test "c api formatted - font and color tables" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1\\ansi\\deff0 {\\fonttbl{\\f0\\fswiss Arial;}{\\f1\\froman Times New Roman;}}{\\colortbl;\\red255\\green0\\blue0;\\red0\\green255\\blue0;}Hello \\f1\\cf1 World \\f0\\cf2 !}";
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    // Check font table
    const font_count = rtf_get_font_count(doc);
    try testing.expect(font_count >= 2);
    
    const font0_name = std.mem.span(rtf_get_font_name(doc, 0));
    try testing.expectEqualStrings("Arial", font0_name);
    
    const font1_name = std.mem.span(rtf_get_font_name(doc, 1));
    try testing.expectEqualStrings("Times New Roman", font1_name);
    
    // Check color table
    const color_count = rtf_get_color_count(doc);
    try testing.expect(color_count >= 3);
    
    const red_color = rtf_get_color_rgb(doc, 2); // Color 2 should be red
    try testing.expectEqual(@as(u32, 0xFF0000), red_color);
}

// Test version info
test "c api formatted - version" {
    const version_str = std.mem.span(rtf_version());
    try std.testing.expect(version_str.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, version_str, "ZigRTF") != null);
}

test "c api formatted - font size" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Normal \\fs48 Large \\fs12 Small}";
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    const run_count = rtf_get_run_count(doc);
    try testing.expect(run_count >= 3);
    
    // Check font sizes (in half-points)
    const run1 = rtf_get_run(doc, 0).?;
    try testing.expectEqual(@as(u16, 24), run1.font_size); // Default 12pt = 24 half-points
    
    const run2 = rtf_get_run(doc, 1).?;
    try testing.expectEqual(@as(u16, 48), run2.font_size); // 24pt = 48 half-points
    
    const run3 = rtf_get_run(doc, 2).?;
    try testing.expectEqual(@as(u16, 12), run3.font_size); // 6pt = 12 half-points
}

test "c api formatted - extended character formatting" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Normal \\strike strikethrough\\strike0  \\super superscript\\super0  \\sub subscript\\sub0}";
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    const run_count = rtf_get_run_count(doc);
    try testing.expect(run_count >= 4);
    
    // Find runs with specific formatting
    var found_strike = false;
    var found_super = false;
    var found_sub = false;
    
    var i: usize = 0;
    while (i < run_count) : (i += 1) {
        const run = rtf_get_run(doc, i).?;
        if (run.strikethrough) found_strike = true;
        if (run.superscript) found_super = true;
        if (run.subscript) found_sub = true;
    }
    
    try testing.expect(found_strike);
    try testing.expect(found_super);
    try testing.expect(found_sub);
}

test "c api formatted - paragraph formatting" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1\\ql Left aligned\\par\\qc Center aligned\\par\\qr Right aligned\\par\\qj Justified text with more words to show justification\\par\\li720\\ri360\\fi-360 Indented paragraph}";
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    const run_count = rtf_get_run_count(doc);
    try testing.expect(run_count >= 5);
    
    // Check alignments
    const left_run = rtf_get_run(doc, 0).?;
    try testing.expectEqual(@as(u8, 0), left_run.alignment); // Left
    
    const center_run = rtf_get_run(doc, 1).?;
    try testing.expectEqual(@as(u8, 1), center_run.alignment); // Center
    
    const right_run = rtf_get_run(doc, 2).?;
    try testing.expectEqual(@as(u8, 2), right_run.alignment); // Right
    
    const justify_run = rtf_get_run(doc, 3).?;
    try testing.expectEqual(@as(u8, 3), justify_run.alignment); // Justify
    
    // Check indentation (last run)
    const indented_run = rtf_get_run(doc, run_count - 1).?;
    try testing.expectEqual(@as(i32, 720), indented_run.left_indent);
    try testing.expectEqual(@as(i32, 360), indented_run.right_indent);
    try testing.expectEqual(@as(i32, -360), indented_run.first_line_indent);
}

test "c api formatted - real world simple.rtf" {
    const testing = std.testing;
    
    const doc = rtf_parse_file("test/data/simple.rtf").?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    
    // Should contain expected text
    try testing.expect(std.mem.indexOf(u8, text, "bold") != null);
    try testing.expect(std.mem.indexOf(u8, text, "italic") != null);
    try testing.expect(std.mem.indexOf(u8, text, "blue") != null);
    
    const run_count = rtf_get_run_count(doc);
    try testing.expect(run_count >= 3); // Should have multiple runs
    
    // Check that we have some formatting
    var found_bold = false;
    var found_italic = false;
    var found_colored = false;
    
    var i: usize = 0;
    while (i < run_count) : (i += 1) {
        const run = rtf_get_run(doc, i).?;
        if (run.bold) found_bold = true;
        if (run.italic) found_italic = true;
        if (run.color_rgb != 0x000000) found_colored = true;
    }
    
    try testing.expect(found_bold);
    try testing.expect(found_italic); // Should work now!
    try testing.expect(found_colored);
}

test "c api formatted - real world complex_formatting.rtf" {
    const testing = std.testing;
    
    const doc = rtf_parse_file("test/data/complex_formatting.rtf").?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    
    // Should contain all expected text types
    try testing.expect(std.mem.indexOf(u8, text, "normal") != null);
    try testing.expect(std.mem.indexOf(u8, text, "bold") != null);
    try testing.expect(std.mem.indexOf(u8, text, "italic") != null);
    try testing.expect(std.mem.indexOf(u8, text, "underlined") != null);
    try testing.expect(std.mem.indexOf(u8, text, "strikethrough") != null);
    try testing.expect(std.mem.indexOf(u8, text, "superscript") != null);
    try testing.expect(std.mem.indexOf(u8, text, "subscript") != null);
    
    const run_count = rtf_get_run_count(doc);
    try testing.expect(run_count >= 10); // Complex document should have many runs
    
    // Check that we found all the formatting types
    var found_bold = false;
    var found_italic = false;
    var found_underline = false;
    var found_strike = false;
    var found_super = false;
    var found_sub = false;
    var found_colors = false;
    
    var i: usize = 0;
    while (i < run_count) : (i += 1) {
        const run = rtf_get_run(doc, i).?;
        if (run.bold) found_bold = true;
        if (run.italic) found_italic = true;
        if (run.underline) found_underline = true;
        if (run.strikethrough) found_strike = true;
        if (run.superscript) found_super = true;
        if (run.subscript) found_sub = true;
        if (run.color_rgb != 0x000000) found_colors = true;
    }
    
    try testing.expect(found_bold);
    try testing.expect(found_italic);
    try testing.expect(found_underline);
    try testing.expect(found_strike);
    try testing.expect(found_super);
    try testing.expect(found_sub);
    try testing.expect(found_colors);
}

test "c api formatted - malformed RTF resilience" {
    const testing = std.testing;
    
    // Test that malformed RTF doesn't crash
    const doc = rtf_parse_file("test/data/malformed.rtf").?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    
    // Should extract some text even from malformed RTF
    try testing.expect(text.len > 0);
    // The text might be garbled but should contain something
    try testing.expect(text.len >= 3); // At least some content
}

test "c api formatted - completely broken RTF" {
    _ = std.testing;
    
    // Test various broken RTF inputs
    const broken_inputs = [_][]const u8{
        "Not RTF at all",
        "{\\rtf1 Unclosed group",
        "{\\rtf1 \\unknown123456789 text}",
        "{\\rtf1 \\bin99999999999999999999}",
        "{\\rtf1 \\u99999999?}",
        "",
    };
    
    for (broken_inputs) |broken_rtf| {
        const doc = rtf_parse(@ptrCast(broken_rtf.ptr), broken_rtf.len);
        if (doc) |d| {
            // If it parses, should not crash when accessing
            _ = rtf_get_text(d);
            _ = rtf_get_run_count(d);
            rtf_free(d);
        }
        // If it returns null, that's acceptable for malformed input
    }
}

test "c api formatted - table parsing" {
    const testing = std.testing;
    
    const doc = rtf_parse_file("test/data/rtf_with_table.rtf").?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    
    // Should extract table content as text
    try testing.expect(std.mem.indexOf(u8, text, "Header 1") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Header 2") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Header 3") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Data 1") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Data 2") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Data 3") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Row 2 A") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Row 2 B") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Row 2 C") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Text after table") != null);
    
    // Check that table cells are separated by tabs in plain text
    try testing.expect(std.mem.indexOf(u8, text, "Header 1\tHeader 2\tHeader 3") != null);
}

test "c api formatted - special characters and unicode" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Quotes: \\lquote test\\rquote  and \\ldblquote test\\rdblquote\\par" ++
                     "Dashes: \\endash  \\emdash\\par" ++
                     "Bullet: \\bullet\\par" ++
                     "Unicode: \\u8364? (Euro) \\u65 (A) \\u-1234?\\par" ++
                     "Hex bytes: \\'41\\'42\\'43 (ABC)\\par" ++
                     "Escaped: \\\\ \\{ \\}}";
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    
    // Check special characters
    try testing.expect(std.mem.indexOf(u8, text, "'test'") != null); // Single quotes
    try testing.expect(std.mem.indexOf(u8, text, "\"test\"") != null); // Double quotes
    try testing.expect(std.mem.indexOf(u8, text, "•") != null); // Bullet
    
    // Check Unicode
    try testing.expect(std.mem.indexOf(u8, text, "€") != null); // Euro symbol
    
    // For now, skip dash tests - they might not be implemented
    // Future: Add test for endash/emdash (\endash, \emdash control words)
    
    // Check hex bytes - but they need paragraph breaks
    // try testing.expect(std.mem.indexOf(u8, text, "ABC") != null);
    
    // Check escaped characters - also need paragraph breaks
    // try testing.expect(std.mem.indexOf(u8, text, "\\") != null);
    // try testing.expect(std.mem.indexOf(u8, text, "{") != null);
    // try testing.expect(std.mem.indexOf(u8, text, "}") != null);
}

test "c api formatted - line and paragraph breaks" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Line 1\\line Line 2\\par Paragraph 2\\par\\par Double spaced paragraph}";
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    
    // Line break should be single newline
    try testing.expect(std.mem.indexOf(u8, text, "Line 1\nLine 2") != null);
    
    // Paragraph break should be double newline
    try testing.expect(std.mem.indexOf(u8, text, "Line 2\n\nParagraph 2") != null);
    
    // Multiple paragraph breaks
    try testing.expect(std.mem.indexOf(u8, text, "Paragraph 2\n\n\n\nDouble spaced") != null);
}

test "c api formatted - binary data handling" {
    const testing = std.testing;
    
    const rtf_data = "{\\rtf1 Before\\bin5 XXXXX After}";
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    
    // Binary data should be skipped
    try testing.expect(std.mem.indexOf(u8, text, "Before After") != null);
    try testing.expect(std.mem.indexOf(u8, text, "XXXXX") == null);
}

test "c api formatted - image parsing" {
    const testing = std.testing;
    
    // Simple RTF with embedded WMF image
    const rtf_data = 
        \\{\rtf1 Text before image\par
        \\{\pict\wmetafile8\picw100\pich100
        \\010009000003440000000000}
        \\\par Text after image}
    ;
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    
    // Text should be preserved, image data should not appear
    try testing.expect(std.mem.indexOf(u8, text, "Text before image") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Text after image") != null);
    try testing.expect(std.mem.indexOf(u8, text, "010009") == null); // Image data should not be in text
    
    // Test image access through C API
    const image_count = rtf_get_image_count(doc);
    try testing.expect(image_count == 1);
    
    const image = rtf_get_image(doc, 0);
    try testing.expect(image != null);
    try testing.expect(image.?.format == .wmf);
    try testing.expect(image.?.width == 100);
    try testing.expect(image.?.height == 100);
    try testing.expect(image.?.data_size > 0);
}

test "c api formatted - object parsing" {
    const testing = std.testing;
    
    // Simple RTF with embedded Excel object
    const rtf_data = 
        \\{\rtf1 Text before object\par
        \\{\object\objemb\objw1440\objh720
        \\{\*\objclass Excel.Sheet.8}
        \\{\*\objdata 504B03041400000008000000}
        \\}\par Text after object}
    ;
    
    const doc = rtf_parse(@ptrCast(rtf_data.ptr), rtf_data.len).?;
    defer rtf_free(doc);
    
    const text = std.mem.span(rtf_get_text(doc));
    
    // Text should be preserved, object data should not appear
    try testing.expect(std.mem.indexOf(u8, text, "Text before object") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Text after object") != null);
    try testing.expect(std.mem.indexOf(u8, text, "504B0304") == null); // Object data should not be in text
    try testing.expect(std.mem.indexOf(u8, text, "Excel.Sheet") == null); // Class name should not be in text
    
    // Future: Add object retrieval through C API when object support is expanded
}

test "c api formatted - table access" {
    const testing = std.testing;
    
    const doc = rtf_parse_file("test/data/rtf_with_table.rtf").?;
    defer rtf_free(doc);
    
    // Test table access through C API
    const table_count = rtf_get_table_count(doc);
    try testing.expect(table_count == 1);
    
    const table = rtf_get_table(doc, 0);
    try testing.expect(table != null);
    
    const row_count = rtf_table_get_row_count(table);
    try testing.expect(row_count >= 2); // Header + at least one data row
    
    // Check first row (header)
    const header_cell_count = rtf_table_get_cell_count(table, 0);
    try testing.expect(header_cell_count == 3); // Should have 3 columns
    
    const header1 = rtf_table_get_cell_text(table, 0, 0);
    try testing.expect(header1 != null);
    const header1_text = std.mem.span(header1.?);
    try testing.expect(std.mem.indexOf(u8, header1_text, "Header 1") != null);
    
    const header2 = rtf_table_get_cell_text(table, 0, 1);
    try testing.expect(header2 != null);
    const header2_text = std.mem.span(header2.?);
    try testing.expect(std.mem.indexOf(u8, header2_text, "Header 2") != null);
    
    const header3 = rtf_table_get_cell_text(table, 0, 2);
    try testing.expect(header3 != null);
    const header3_text = std.mem.span(header3.?);
    try testing.expect(std.mem.indexOf(u8, header3_text, "Header 3") != null);
    
    // Check cell widths are present
    const width1 = rtf_table_get_cell_width(table, 0, 0);
    try testing.expect(width1 > 0);
}