const std = @import("std");
const ByteStream = @import("byte_stream.zig").ByteStream;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Style = @import("parser.zig").Style;
const EventHandler = @import("parser.zig").EventHandler;

// Define C structs that will store our Zig objects
pub const RtfParser = struct {
    allocator: std.mem.Allocator,
    stream: ?*ByteStream,
    tokenizer: ?*Tokenizer,
    parser: ?*Parser,
    
    pub fn deinit(self: *RtfParser) void {
        if (self.parser != null) {
            self.parser.?.deinit();
            self.allocator.destroy(self.parser.?);
            self.parser = null;
        }
        
        if (self.tokenizer != null) {
            self.tokenizer.?.deinit();
            self.allocator.destroy(self.tokenizer.?);
            self.tokenizer = null;
        }
        
        if (self.stream != null) {
            self.allocator.destroy(self.stream.?);
            self.stream = null;
        }
    }
};

// Define the C-compatible style structure
pub const CStyle = extern struct {
    bold: bool,
    italic: bool,
    underline: bool,
    font_size: u16,
};

// Define callback function types
pub const TextCallbackFn = fn (?*anyopaque, [*c]const u8, usize, CStyle) callconv(.C) void;
pub const GroupCallbackFn = fn (?*anyopaque) callconv(.C) void;

// Global variables to hold callback and context
var g_text_callback: ?TextCallbackFn = null;
var g_group_start_callback: ?GroupCallbackFn = null;
var g_group_end_callback: ?GroupCallbackFn = null;
var g_user_data: ?*anyopaque = null;

// Global allocator for C API
var g_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const g_gpa = g_allocator.allocator();

// Zig callback that will forward to C
fn textCallback(ctx: *anyopaque, text: []const u8, style: Style) !void {
    _ = ctx; // We're using global variables
    
    if (g_text_callback) |callback| {
        // Convert Zig style to C style
        const c_style = CStyle{
            .bold = style.bold,
            .italic = style.italic,
            .underline = style.underline,
            .font_size = style.font_size orelse 0,
        };
        
        callback(g_user_data, text.ptr, text.len, c_style);
    }
}

fn groupStartCallback(ctx: *anyopaque) !void {
    _ = ctx; // We're using global variables
    
    if (g_group_start_callback) |callback| {
        callback(g_user_data);
    }
}

fn groupEndCallback(ctx: *anyopaque) !void {
    _ = ctx; // We're using global variables
    
    if (g_group_end_callback) |callback| {
        callback(g_user_data);
    }
}

// Export C API functions with proper linkage
pub export fn rtf_parser_create() callconv(.C) ?*RtfParser {
    const parser = g_gpa.create(RtfParser) catch return null;
    parser.* = .{
        .allocator = g_gpa,
        .stream = null,
        .tokenizer = null,
        .parser = null,
    };
    return parser;
}

pub export fn rtf_parser_destroy(parser: ?*RtfParser) callconv(.C) void {
    if (parser) |p| {
        p.deinit();
        g_gpa.destroy(p);
    }
}

pub export fn rtf_parser_set_callbacks(
    parser: ?*RtfParser,
    text_callback: ?TextCallbackFn,
    group_start_callback: ?GroupCallbackFn,
    group_end_callback: ?GroupCallbackFn,
    user_data: ?*anyopaque
) callconv(.C) void {
    _ = parser; // Parser parameter is unused but kept for API consistency
    g_text_callback = text_callback;
    g_group_start_callback = group_start_callback;
    g_group_end_callback = group_end_callback;
    g_user_data = user_data;
}

pub export fn rtf_parser_parse_memory(parser: ?*RtfParser, data: [*c]const u8, length: usize) callconv(.C) bool {
    if (parser == null) return false;
    
    const p = parser.?;
    
    // Create ByteStream, Tokenizer, and Parser
    p.stream = p.allocator.create(ByteStream) catch return false;
    p.stream.?.* = ByteStream.initMemory(data[0..length]);
    
    p.tokenizer = p.allocator.create(Tokenizer) catch return false;
    p.tokenizer.?.* = Tokenizer.init(p.stream.?, p.allocator);
    
    // Create event handler
    const handler = EventHandler{
        .context = null, // Using global variables instead
        .onGroupStart = groupStartCallback,
        .onGroupEnd = groupEndCallback,
        .onText = textCallback,
        .onCharacter = null,
        .onError = null,
    };
    
    p.parser = p.allocator.create(Parser) catch return false;
    p.parser.?.* = Parser.init(p.tokenizer.?, p.allocator, handler) catch return false;
    
    // Parse the document
    p.parser.?.parse() catch return false;
    
    return true;
}