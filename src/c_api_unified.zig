const std = @import("std");
const ByteStream = @import("byte_stream.zig").ByteStream;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Style = @import("parser.zig").Style;
const EventHandler = @import("parser.zig").EventHandler;
const RecoveryStrategy = @import("parser.zig").RecoveryStrategy;

/// Unified C API for ZigRTF library
/// 
/// This API provides both simple and advanced interfaces for using the
/// ZigRTF parser from C code. All functions are exported with C calling
/// conventions for easy interoperation with C code.

// Error codes
pub const RtfErrorCode = enum(c_int) {
    RTF_NO_ERROR = 0,
    RTF_MEMORY_ERROR = 1,
    RTF_PARSE_ERROR = 2,
    RTF_INVALID_PARAM = 3,
    RTF_UNSUPPORTED_FEATURE = 4,
};

/// The main RTF parser structure that holds the state of parsing
pub const RtfParser = struct {
    allocator: std.mem.Allocator,
    stream: ?*ByteStream = null,
    tokenizer: ?*Tokenizer = null,
    parser: ?*Parser = null,
    last_error: RtfErrorCode = .RTF_NO_ERROR,
    
    pub fn deinit(self: *RtfParser) void {
        // Clean up parser
        if (self.parser != null) {
            self.parser.?.deinit();
            self.allocator.destroy(self.parser.?);
            self.parser = null;
        }
        
        // Clean up tokenizer
        if (self.tokenizer != null) {
            self.tokenizer.?.deinit();
            self.allocator.destroy(self.tokenizer.?);
            self.tokenizer = null;
        }
        
        // Clean up stream
        if (self.stream != null) {
            self.allocator.destroy(self.stream.?);
            self.stream = null;
        }
    }
};

/// C-compatible style structure
/// This matches the zigrtf.h RtfStyle struct
pub const RtfStyle = extern struct {
    bold: bool,
    italic: bool,
    underline: bool,
    font_size: u16,
};

/// C-compatible style structure with ints for older C compilers
/// This is used by the "simple" interface for maximum compatibility
pub const RtfStyleInt = extern struct {
    bold: c_int,
    italic: c_int,
    underline: c_int,
    font_size: c_int,
};

/// Callback function types
/// Note: These functions use void* (anyopaque) instead of explicit types
/// to provide a more C-like interface
pub const RtfTextCallbackFn = fn (?*anyopaque, [*c]const u8, usize, RtfStyle) callconv(.C) void;
pub const RtfGroupCallbackFn = fn (?*anyopaque) callconv(.C) void;
pub const RtfErrorCallbackFn = fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.C) void;
pub const RtfCharCallbackFn = fn (?*anyopaque, u8, RtfStyle) callconv(.C) void;

/// Simple interface callback function types (using int-based style)
pub const RtfSimpleTextCallbackFn = fn (?*anyopaque, [*c]const u8, usize, RtfStyleInt) callconv(.C) void;

// Global variables for simple and advanced callbacks
var g_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const g_gpa = g_allocator.allocator();

// Global state for advanced interface callbacks
var g_text_callback: ?*const fn (?*anyopaque, [*c]const u8, usize, RtfStyle) callconv(.C) void = null;
var g_group_start_callback: ?*const fn (?*anyopaque) callconv(.C) void = null;
var g_group_end_callback: ?*const fn (?*anyopaque) callconv(.C) void = null;
var g_error_callback: ?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.C) void = null;
var g_char_callback: ?*const fn (?*anyopaque, u8, RtfStyle) callconv(.C) void = null;
var g_user_data: ?*anyopaque = null;

// Global state for simple interface callbacks
var g_simple_text_callback: ?*const fn (?*anyopaque, [*c]const u8, usize, RtfStyleInt) callconv(.C) void = null;
var g_simple_group_start_callback: ?*const fn (?*anyopaque) callconv(.C) void = null;
var g_simple_group_end_callback: ?*const fn (?*anyopaque) callconv(.C) void = null;
var g_simple_user_data: ?*anyopaque = null;

/// Convert Zig Style to C-compatible RtfStyle
fn zigStyleToRtfStyle(style: Style) RtfStyle {
    return RtfStyle{
        .bold = style.bold,
        .italic = style.italic,
        .underline = style.underline,
        .font_size = style.font_size orelse 0,
    };
}

/// Convert Zig Style to C-compatible RtfStyleInt
fn zigStyleToRtfStyleInt(style: Style) RtfStyleInt {
    return RtfStyleInt{
        .bold = if (style.bold) 1 else 0,
        .italic = if (style.italic) 1 else 0,
        .underline = if (style.underline) 1 else 0,
        .font_size = @as(c_int, @intCast(style.font_size orelse 0)),
    };
}

// ===== Advanced API callback wrappers =====

fn advancedTextCallback(ctx: *anyopaque, text: []const u8, style: Style) !void {
    _ = ctx; // Using global variables

    if (g_text_callback) |callback| {
        const c_style = zigStyleToRtfStyle(style);
        callback(g_user_data, text.ptr, text.len, c_style);
    }
}

fn advancedGroupStartCallback(ctx: *anyopaque) !void {
    _ = ctx; // Using global variables

    if (g_group_start_callback) |callback| {
        callback(g_user_data);
    }
}

fn advancedGroupEndCallback(ctx: *anyopaque) !void {
    _ = ctx; // Using global variables

    if (g_group_end_callback) |callback| {
        callback(g_user_data);
    }
}

fn advancedErrorCallback(ctx: *anyopaque, position: []const u8, message: []const u8) !void {
    _ = ctx; // Using global variables

    if (g_error_callback) |callback| {
        callback(g_user_data, position.ptr, message.ptr);
    }
}

fn advancedCharCallback(ctx: *anyopaque, char: u8, style: Style) !void {
    _ = ctx; // Using global variables

    if (g_char_callback) |callback| {
        const c_style = zigStyleToRtfStyle(style);
        callback(g_user_data, char, c_style);
    }
}

// ===== Simple API callback wrappers =====

fn simpleTextCallback(ctx: *anyopaque, text: []const u8, style: Style) !void {
    _ = ctx; // Using global variables

    if (g_simple_text_callback) |callback| {
        const c_style = zigStyleToRtfStyleInt(style);
        callback(g_simple_user_data, text.ptr, text.len, c_style);
    }
}

fn simpleGroupStartCallback(ctx: *anyopaque) !void {
    _ = ctx; // Using global variables

    if (g_simple_group_start_callback) |callback| {
        callback(g_simple_user_data);
    }
}

fn simpleGroupEndCallback(ctx: *anyopaque) !void {
    _ = ctx; // Using global variables

    if (g_simple_group_end_callback) |callback| {
        callback(g_simple_user_data);
    }
}

// ===== ADVANCED C API FUNCTIONS =====

/// Create a new RTF parser with advanced interface
/// The returned parser must be freed with rtf_unified_destroy
pub export fn rtf_unified_create() callconv(.C) ?*RtfParser {
    const parser = g_gpa.create(RtfParser) catch return null;
    parser.* = .{
        .allocator = g_gpa,
    };
    return parser;
}

/// Free resources used by the parser
pub export fn rtf_unified_destroy(parser: ?*RtfParser) callconv(.C) void {
    if (parser) |p| {
        p.deinit();
        g_gpa.destroy(p);
    }
}

/// Set callbacks for parser events (advanced interface)
pub export fn rtf_unified_set_callbacks(
    parser: ?*RtfParser,
    text_callback: ?*const fn (?*anyopaque, [*c]const u8, usize, RtfStyle) callconv(.C) void,
    group_start_callback: ?*const fn (?*anyopaque) callconv(.C) void,
    group_end_callback: ?*const fn (?*anyopaque) callconv(.C) void,
    user_data: ?*anyopaque
) callconv(.C) void {
    _ = parser; // Kept for API consistency
    g_text_callback = text_callback;
    g_group_start_callback = group_start_callback;
    g_group_end_callback = group_end_callback;
    g_user_data = user_data;
}

/// Set extended callbacks for advanced parser events
pub export fn rtf_unified_set_extended_callbacks(
    parser: ?*RtfParser,
    error_callback: ?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.C) void,
    char_callback: ?*const fn (?*anyopaque, u8, RtfStyle) callconv(.C) void
) callconv(.C) void {
    _ = parser; // Kept for API consistency
    g_error_callback = error_callback;
    g_char_callback = char_callback;
}

/// Parse RTF data from memory buffer (advanced interface)
pub export fn rtf_unified_parse_memory(
    parser: ?*RtfParser,
    data: [*c]const u8,
    length: usize
) callconv(.C) bool {
    if (parser == null) return false;
    
    const p = parser.?;
    p.last_error = .RTF_NO_ERROR;
    
    // Create ByteStream
    p.stream = p.allocator.create(ByteStream) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return false;
    };
    p.stream.?.* = ByteStream.initMemory(data[0..length]);
    
    // Create Tokenizer
    p.tokenizer = p.allocator.create(Tokenizer) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return false;
    };
    p.tokenizer.?.* = Tokenizer.init(p.stream.?, p.allocator);
    
    // Set up event handler
    const handler = EventHandler{
        .context = null, // Using global variables
        .onGroupStart = advancedGroupStartCallback,
        .onGroupEnd = advancedGroupEndCallback,
        .onText = advancedTextCallback,
        .onCharacter = advancedCharCallback,
        .onError = advancedErrorCallback,
        .onBinary = null,
    };
    
    // Create Parser with default recovery strategy
    p.parser = p.allocator.create(Parser) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return false;
    };
    p.parser.?.* = Parser.initWithStrategy(p.tokenizer.?, p.allocator, handler, .tolerant, 100) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return false;
    };
    
    // Parse the document
    p.parser.?.parse() catch {
        p.last_error = .RTF_PARSE_ERROR;
        return false;
    };
    
    return true;
}

/// Parse RTF data with specific error recovery strategy
pub export fn rtf_unified_parse_memory_with_recovery(
    parser: ?*RtfParser,
    data: [*c]const u8,
    length: usize,
    strict_mode: bool
) callconv(.C) bool {
    if (parser == null) return false;
    
    const p = parser.?;
    p.last_error = .RTF_NO_ERROR;
    
    // Create ByteStream
    p.stream = p.allocator.create(ByteStream) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return false;
    };
    p.stream.?.* = ByteStream.initMemory(data[0..length]);
    
    // Create Tokenizer
    p.tokenizer = p.allocator.create(Tokenizer) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return false;
    };
    p.tokenizer.?.* = Tokenizer.init(p.stream.?, p.allocator);
    
    // Set up event handler
    const handler = EventHandler{
        .context = null, // Using global variables
        .onGroupStart = advancedGroupStartCallback,
        .onGroupEnd = advancedGroupEndCallback,
        .onText = advancedTextCallback,
        .onCharacter = advancedCharCallback,
        .onError = advancedErrorCallback,
        .onBinary = null,
    };
    
    // Create Parser with specified recovery strategy
    p.parser = p.allocator.create(Parser) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return false;
    };
    
    const strategy = if (strict_mode) RecoveryStrategy.strict else RecoveryStrategy.tolerant;
    p.parser.?.* = Parser.initWithStrategy(p.tokenizer.?, p.allocator, handler, strategy, 100) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return false;
    };
    
    // Parse the document
    p.parser.?.parse() catch {
        p.last_error = .RTF_PARSE_ERROR;
        return false;
    };
    
    return true;
}

/// Get the last error code from the parser
pub export fn rtf_unified_get_last_error(parser: ?*RtfParser) callconv(.C) c_int {
    if (parser == null) return @intFromEnum(RtfErrorCode.RTF_INVALID_PARAM);
    return @intFromEnum(parser.?.last_error);
}

// ===== SIMPLE C API FUNCTIONS =====

/// Create a new RTF parser with simple interface
/// Same as rtf_unified_create, but explicitly labeled for the simple API
pub export fn rtf_unified_simple_create() callconv(.C) ?*RtfParser {
    return rtf_unified_create();
}

/// Free resources used by the parser
/// Same as rtf_unified_destroy, but explicitly labeled for the simple API
pub export fn rtf_unified_simple_destroy(parser: ?*RtfParser) callconv(.C) void {
    rtf_unified_destroy(parser);
}

/// Set callbacks for parser events (simple interface)
pub export fn rtf_unified_simple_set_callbacks(
    parser: ?*RtfParser,
    text_callback: ?*const fn (?*anyopaque, [*c]const u8, usize, RtfStyleInt) callconv(.C) void,
    group_start_callback: ?*const fn (?*anyopaque) callconv(.C) void,
    group_end_callback: ?*const fn (?*anyopaque) callconv(.C) void,
    user_data: ?*anyopaque
) callconv(.C) void {
    _ = parser; // Kept for API consistency
    g_simple_text_callback = text_callback;
    g_simple_group_start_callback = group_start_callback;
    g_simple_group_end_callback = group_end_callback;
    g_simple_user_data = user_data;
}

/// Parse RTF data from memory buffer (simple interface)
pub export fn rtf_unified_simple_parse_memory(
    parser: ?*RtfParser,
    data: [*c]const u8,
    length: usize
) callconv(.C) c_int {
    if (parser == null) return 0;
    
    const p = parser.?;
    p.last_error = .RTF_NO_ERROR;
    
    // Create ByteStream
    p.stream = p.allocator.create(ByteStream) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return 0;
    };
    p.stream.?.* = ByteStream.initMemory(data[0..length]);
    
    // Create Tokenizer
    p.tokenizer = p.allocator.create(Tokenizer) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return 0;
    };
    p.tokenizer.?.* = Tokenizer.init(p.stream.?, p.allocator);
    
    // Set up event handler with simple callbacks
    const handler = EventHandler{
        .context = null, // Using global variables
        .onGroupStart = simpleGroupStartCallback,
        .onGroupEnd = simpleGroupEndCallback,
        .onText = simpleTextCallback,
        .onCharacter = null,
        .onError = null,
        .onBinary = null,
    };
    
    // Create Parser with permissive recovery strategy for simple API
    p.parser = p.allocator.create(Parser) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return 0;
    };
    p.parser.?.* = Parser.initWithStrategy(p.tokenizer.?, p.allocator, handler, .permissive, 100) catch {
        p.last_error = .RTF_MEMORY_ERROR;
        return 0;
    };
    
    // Parse the document
    p.parser.?.parse() catch {
        p.last_error = .RTF_PARSE_ERROR;
        return 0;
    };
    
    return 1; // Success
}

// ===== COMPATIBILITY ALIASES =====

/// Alias for the old API function for backward compatibility
pub export fn rtf_unified_compat_set_callbacks_simple(
    parser: ?*RtfParser,
    text_callback: ?*const fn (?*anyopaque, [*c]const u8, usize, RtfStyleInt) callconv(.C) void,
    group_start_callback: ?*const fn (?*anyopaque) callconv(.C) void,
    group_end_callback: ?*const fn (?*anyopaque) callconv(.C) void,
    user_data: ?*anyopaque
) callconv(.C) void {
    rtf_unified_simple_set_callbacks(parser, text_callback, group_start_callback, group_end_callback, user_data);
}

/// Alias for the old API function for backward compatibility
pub export fn rtf_unified_compat_parse_memory_simple(
    parser: ?*RtfParser,
    data: [*c]const u8,
    length: usize
) callconv(.C) c_int {
    return rtf_unified_simple_parse_memory(parser, data, length);
}