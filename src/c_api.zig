const std = @import("std");
const Parser = @import("rtf.zig").Parser;

// Thread-local error storage
threadlocal var last_error: ?[]const u8 = null;
threadlocal var error_arena: ?std.heap.ArenaAllocator = null;

// Document structure matching C API
const RtfRun = extern struct {
    text: [*:0]const u8,
    length: usize,
    
    // Bitfields
    bold: u32,      // We'll pack these manually
    italic: u32,
    underline: u32,
    reserved: u32,
    
    font_size: c_int,
    color: u32,
};

pub const RtfDocument = struct {
    allocator: std.mem.Allocator,
    text: [:0]u8,
    runs: []RtfRun,
    
    fn deinit(self: *RtfDocument) void {
        self.allocator.free(self.text);
        self.allocator.free(self.runs);
        self.allocator.destroy(self);
    }
};

const RtfReader = extern struct {
    read: *const fn (context: ?*anyopaque, buffer: ?*anyopaque, count: usize) callconv(.C) c_int,
    context: ?*anyopaque,
};

// Enhanced parser that tracks formatting
const EnhancedParser = struct {
    text: std.ArrayList(u8),
    runs: std.ArrayList(RtfRun),
    current_format: FormatState,
    current_run_start: usize,
    
    const FormatState = struct {
        bold: bool = false,
        italic: bool = false,
        underline: bool = false,
        font_size: i32 = 0,
        color: u32 = 0,
    };
    
    fn init(allocator: std.mem.Allocator) EnhancedParser {
        return .{
            .text = std.ArrayList(u8).init(allocator),
            .runs = std.ArrayList(RtfRun).init(allocator),
            .current_format = .{},
            .current_run_start = 0,
        };
    }
    
    fn deinit(self: *EnhancedParser) void {
        self.text.deinit();
        self.runs.deinit();
    }
    
    fn addText(self: *EnhancedParser, text: []const u8) !void {
        try self.text.appendSlice(text);
    }
    
    fn addFormattedText(self: *EnhancedParser, text: []const u8, format: FormatState) !void {
        // If format changed, finish current run
        if (!std.meta.eql(format, self.current_format)) {
            try self.finishCurrentRun();
            self.current_format = format;
            self.current_run_start = self.text.items.len;
        }
        
        try self.text.appendSlice(text);
    }
    
    fn finishCurrentRun(self: *EnhancedParser) !void {
        if (self.text.items.len == self.current_run_start) return; // Empty run
        
        const start = self.current_run_start;
        const end = self.text.items.len;
        const run_text = self.text.items[start..end];
        
        // Add null terminator for this run
        try self.text.append(0);
        
        const run = RtfRun{
            .text = @ptrCast(self.text.items[start..end + 1].ptr),
            .length = run_text.len,
            .bold = if (self.current_format.bold) 1 else 0,
            .italic = if (self.current_format.italic) 1 else 0,
            .underline = if (self.current_format.underline) 1 else 0,
            .reserved = 0,
            .font_size = self.current_format.font_size,
            .color = self.current_format.color,
        };
        
        try self.runs.append(run);
        self.current_run_start = self.text.items.len;
    }
    
    fn finish(self: *EnhancedParser) !void {
        try self.finishCurrentRun();
        // Add final null terminator for the entire text
        if (self.text.items.len == 0 or self.text.items[self.text.items.len - 1] != 0) {
            try self.text.append(0);
        }
    }
};

// Error handling
fn setError(comptime fmt: []const u8, args: anytype) void {
    if (error_arena == null) {
        error_arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    }
    
    last_error = std.fmt.allocPrint(error_arena.?.allocator(), fmt, args) catch "Out of memory";
}

fn clearError() void {
    if (error_arena) |*arena| {
        arena.deinit();
        error_arena = null;
    }
    last_error = null;
}

// Stream reader wrapper
const StreamReader = struct {
    rtf_reader: *const RtfReader,
    
    const ReadError = error{EndOfStream};
    
    fn read(self: StreamReader, buffer: []u8) ReadError!usize {
        const bytes_read = self.rtf_reader.read(self.rtf_reader.context, buffer.ptr, buffer.len);
        if (bytes_read < 0) return ReadError.EndOfStream;
        return @intCast(bytes_read);
    }
    
    fn reader(self: StreamReader) std.io.Reader(StreamReader, ReadError, read) {
        return .{ .context = self };
    }
};


// Enhanced RTF parser that builds document with formatting
fn parseRtfToDocument(allocator: std.mem.Allocator, source: std.io.AnyReader) !*RtfDocument {
    // Use the main RTF parser for robust, tested parsing
    const rtf_parser = @import("rtf.zig");
    var parser = rtf_parser.Parser.init(source, allocator);
    defer parser.deinit();
    
    try parser.parse();
    const text = parser.getText();
    
    // For now, create a single run with the extracted text
    // Future: enhance to track formatting during parsing
    var enhanced = EnhancedParser.init(allocator);
    defer enhanced.deinit();
    
    try enhanced.addFormattedText(text, .{});
    try enhanced.finish();
    
    // Create document
    const document = try allocator.create(RtfDocument);
    document.* = .{
        .allocator = allocator,
        .text = try allocator.dupeZ(u8, enhanced.text.items[0..enhanced.text.items.len - 1]), // Remove trailing null
        .runs = try allocator.dupe(RtfRun, enhanced.runs.items),
    };
    
    // Fix run text pointers to point into document text
    var offset: usize = 0;
    for (document.runs) |*run| {
        run.text = @ptrCast(document.text[offset..offset + run.length + 1].ptr);
        offset += run.length + 1; // +1 for null terminator
    }
    
    return document;
}

// C API exports
pub export fn rtf_parse(data: ?*const anyopaque, length: usize) ?*RtfDocument {
    clearError();
    
    if (data == null or length == 0) {
        setError("Invalid input data", .{});
        return null;
    }
    
    const bytes = @as([*]const u8, @ptrCast(data))[0..length];
    var stream = std.io.fixedBufferStream(bytes);
    
    return parseRtfToDocument(std.heap.c_allocator, stream.reader().any()) catch null;
}

pub export fn rtf_parse_stream(reader: ?*const RtfReader) ?*RtfDocument {
    clearError();
    
    if (reader == null) {
        setError("NULL reader provided", .{});
        return null;
    }
    
    const stream_reader = StreamReader{ .rtf_reader = reader.? };
    
    return parseRtfToDocument(std.heap.c_allocator, stream_reader.reader().any()) catch null;
}

pub export fn rtf_free(doc: ?*RtfDocument) void {
    if (doc) |d| {
        d.deinit();
    }
}

pub export fn rtf_get_text(doc: ?*const RtfDocument) ?[*:0]const u8 {
    if (doc) |d| {
        return d.text.ptr;
    }
    return null;
}

pub export fn rtf_get_text_length(doc: ?*const RtfDocument) usize {
    if (doc) |d| {
        return d.text.len;
    }
    return 0;
}

pub export fn rtf_get_run_count(doc: ?*const RtfDocument) usize {
    if (doc) |d| {
        return d.runs.len;
    }
    return 0;
}

pub export fn rtf_get_run(doc: ?*const RtfDocument, index: usize) ?*const RtfRun {
    if (doc) |d| {
        if (index < d.runs.len) {
            return &d.runs[index];
        }
    }
    return null;
}

pub export fn rtf_errmsg() ?[*:0]const u8 {
    if (last_error) |err| {
        return @ptrCast(err.ptr);
    }
    return "No error";
}

pub export fn rtf_clear_error() void {
    clearError();
}

pub export fn rtf_parse_file(filename: ?[*:0]const u8) ?*RtfDocument {
    clearError();
    
    if (filename == null) {
        setError("NULL filename provided", .{});
        return null;
    }
    
    const file = std.c.fopen(filename.?, "rb") orelse {
        setError("Could not open file", .{});
        return null;
    };
    defer _ = std.c.fclose(file);
    
    const reader = rtf_file_reader(file);
    return rtf_parse_stream(&reader);
}

pub export fn rtf_file_reader(file_handle: ?*anyopaque) RtfReader {
    // For file readers, we don't allocate context since FILE* is managed by caller
    // Use the FILE* directly as context to avoid memory leaks
    return .{
        .read = struct {
            fn read_file(context: ?*anyopaque, buffer: ?*anyopaque, count: usize) callconv(.C) c_int {
                const file = @as(*std.c.FILE, @ptrCast(@alignCast(context)));
                const bytes_read = std.c.fread(@ptrCast(buffer), 1, count, file);
                return @intCast(bytes_read);
            }
        }.read_file,
        .context = file_handle,
    };
}

pub export fn rtf_version() [*:0]const u8 {
    return "1.0.0";
}

// Result codes
pub export const RTF_OK: c_int = 0;
pub export const RTF_ERROR: c_int = 1;
pub export const RTF_NOMEM: c_int = 2;
pub export const RTF_INVALID: c_int = 3;
pub export const RTF_TOOBIG: c_int = 4;