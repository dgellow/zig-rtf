const std = @import("std");
const ByteStream = @import("byte_stream.zig").ByteStream;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Style = @import("parser.zig").Style;
const EventHandler = @import("parser.zig").EventHandler;

// Basic structures to maintain RTF parser state
pub const RtfParser = struct {
    allocator: std.mem.Allocator,
    stream: ?*ByteStream,
    tokenizer: ?*Tokenizer,
    parser: ?*Parser,
};

// Simple C-compatible style structure
pub const RtfStyle = extern struct {
    bold: c_int,
    italic: c_int,
    underline: c_int,
    font_size: c_int,
};

// Callback function types
pub const RtfTextCallback = ?*const fn (?*anyopaque, [*c]const u8, usize, RtfStyle) callconv(.C) void;
pub const RtfGroupCallback = ?*const fn (?*anyopaque) callconv(.C) void;

// Global state for callbacks
var g_text_callback: RtfTextCallback = null;
var g_group_start_callback: RtfGroupCallback = null;
var g_group_end_callback: RtfGroupCallback = null;
var g_user_data: ?*anyopaque = null;

// Text callback wrapper
fn onText(text: []const u8, style: Style) !void {
    if (g_text_callback) |callback_ptr| {
        const c_style = RtfStyle{
            .bold = if (style.bold) 1 else 0,
            .italic = if (style.italic) 1 else 0,
            .underline = if (style.underline) 1 else 0,
            .font_size = @as(c_int, @intCast(style.font_size orelse 0)),
        };
        callback_ptr(g_user_data, text.ptr, text.len, c_style);
    }
}

// Group callbacks
fn onGroupStart() !void {
    if (g_group_start_callback) |callback_ptr| {
        callback_ptr(g_user_data);
    }
}

fn onGroupEnd() !void {
    if (g_group_end_callback) |callback_ptr| {
        callback_ptr(g_user_data);
    }
}

// Create a new RTF parser
export fn rtf_parser_create() callconv(.C) ?*RtfParser {
    const parser = std.heap.c_allocator.create(RtfParser) catch return null;
    
    parser.* = RtfParser{
        .allocator = std.heap.c_allocator,
        .stream = null,
        .tokenizer = null,
        .parser = null,
    };
    
    return parser;
}

// Free resources used by the parser
export fn rtf_parser_destroy(parser: ?*RtfParser) callconv(.C) void {
    if (parser) |p| {
        if (p.parser != null) {
            p.parser.?.deinit();
            p.allocator.destroy(p.parser.?);
        }
        
        if (p.tokenizer != null) {
            p.tokenizer.?.deinit();
            p.allocator.destroy(p.tokenizer.?);
        }
        
        if (p.stream != null) {
            p.allocator.destroy(p.stream.?);
        }
        
        std.heap.c_allocator.destroy(p);
    }
}

// Set callbacks for RTF parsing events
export fn rtf_parser_set_callbacks(
    parser: ?*RtfParser,
    text_callback: RtfTextCallback,
    group_start_callback: RtfGroupCallback,
    group_end_callback: RtfGroupCallback,
    user_data: ?*anyopaque
) callconv(.C) void {
    _ = parser; // Unused but kept for API consistency
    
    g_text_callback = text_callback;
    g_group_start_callback = group_start_callback;
    g_group_end_callback = group_end_callback;
    g_user_data = user_data;
}

// Parse RTF data from memory
export fn rtf_parser_parse_memory(
    parser: ?*RtfParser,
    data: [*c]const u8,
    length: usize
) callconv(.C) c_int {
    if (parser == null) return 0;
    
    const p = parser.?;
    
    // Create ByteStream from memory
    p.stream = p.allocator.create(ByteStream) catch return 0;
    p.stream.?.* = ByteStream.initMemory(data[0..length]);
    
    // Create Tokenizer
    p.tokenizer = p.allocator.create(Tokenizer) catch return 0;
    p.tokenizer.?.* = Tokenizer.init(p.stream.?, p.allocator);
    
    // Set up event handler with our callbacks
    const handler = EventHandler{
        .onGroupStart = onGroupStart,
        .onGroupEnd = onGroupEnd,
        .onText = onText,
        .onCharacter = null,
        .onError = null,
    };
    
    // Create Parser
    p.parser = p.allocator.create(Parser) catch return 0;
    p.parser.?.* = Parser.init(p.tokenizer.?, p.allocator, handler) catch return 0;
    
    // Parse the document
    p.parser.?.parse() catch return 0;
    
    return 1; // Success
}