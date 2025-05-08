const std = @import("std");
const ByteStream = @import("byte_stream.zig").ByteStream;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Style = @import("parser.zig").Style;
const EventHandler = @import("parser.zig").EventHandler;
const RecoveryStrategy = @import("parser.zig").RecoveryStrategy;

/// RTF Parser C API
///
/// This module provides a clean, thread-safe C API for the ZigRTF parser.
/// It follows modern C API design principles:
/// - Thread safety - no global state
/// - Context-based callbacks
/// - Comprehensive error handling
/// - Consistent naming conventions
/// - Clear memory ownership rules

// API version info - follows Semantic Versioning
pub const RTF_API_VERSION_MAJOR = 1;
pub const RTF_API_VERSION_MINOR = 0;
pub const RTF_API_VERSION_PATCH = 0;

// Error codes
pub const RtfError = enum(c_int) {
    RTF_OK = 0,
    RTF_ERROR_MEMORY = -1,
    RTF_ERROR_INVALID_PARAMETER = -2,
    RTF_ERROR_PARSE_FAILED = -3,
    RTF_ERROR_FILE_NOT_FOUND = -4,
    RTF_ERROR_FILE_ACCESS = -5,
    RTF_ERROR_UNSUPPORTED_FEATURE = -6,
    RTF_ERROR_INVALID_FORMAT = -7,
};

// Parse options - modifies parser behavior
pub const RtfParseOptions = packed struct {
    // Error handling strategy
    strict_mode: bool = false, // When true, stops on first error
    
    // Max nesting depth for RTF groups
    max_depth: u16 = 100,
    
    // Whether to use memory mapping for large files
    use_memory_mapping: bool = true,
    
    // Memory mapping threshold in bytes (default: 1MB)
    memory_mapping_threshold: u32 = 1024 * 1024,
    
    // Reserved bits for future options
    _reserved: u16 = 0,
};

// Comprehensive style information
pub const RtfStyleInfo = extern struct {
    // Basic formatting
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    strikethrough: bool = false,
    
    // Font information
    font_size: u16 = 0, // Size in half-points (0 = default)
    font_index: i16 = -1, // Font index in font table (-1 = default)
    
    // Color information
    foreground_color_index: i16 = -1, // Color index in color table (-1 = default)
    background_color_index: i16 = -1, // Color index in color table (-1 = default)
    
    // Special formatting
    superscript: bool = false,
    subscript: bool = false,
    hidden: bool = false,
    
    // Additional options
    all_caps: bool = false,
    small_caps: bool = false,
    
    // Reserved for future extension
    _reserved1: u8 = 0,
    _reserved2: u8 = 0,
    _reserved3: u16 = 0,
};

// A color represented in RGB
pub const RtfColor = extern struct {
    red: u8,
    green: u8,
    blue: u8,
    _reserved: u8 = 0, // For alignment/future use
};

// Font information
pub const RtfFontInfo = extern struct {
    index: i32, // Font index
    name: [64]u8, // Null-terminated font name
    charset: i32, // Character set
};

// RTF parser context - opaque to C code
pub const RtfParser = struct {
    // Internal allocator for memory management
    allocator: std.mem.Allocator,
    
    // Parser internals
    stream: ?*ByteStream = null,
    tokenizer: ?*Tokenizer = null,
    parser: ?*Parser = null,
    
    // Last error code
    last_error: RtfError = .RTF_OK,
    
    // Last error message (for detailed error reporting)
    error_message: ?[]u8 = null,
    
    // User-provided callback functions
    callbacks: RtfCallbacks = .{},
    
    // User data pointer passed to callbacks
    user_data: ?*anyopaque = null,
    
    // Clean up all resources
    pub fn deinit(self: *RtfParser) void {
        // Clean up error message
        if (self.error_message != null) {
            self.allocator.free(self.error_message.?);
            self.error_message = null;
        }
    
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
            self.stream.?.deinit();
            self.allocator.destroy(self.stream.?);
            self.stream = null;
        }
    }
    
    // Set an error with a message
    pub fn setError(self: *RtfParser, error_code: RtfError, message: []const u8) void {
        self.last_error = error_code;
        
        // Free any existing error message
        if (self.error_message != null) {
            self.allocator.free(self.error_message.?);
            self.error_message = null;
        }
        
        // Copy the new error message
        self.error_message = self.allocator.dupe(u8, message) catch {
            // If allocation fails, we can't store the message
            return;
        };
    }
};

// Callback function types
pub const RtfTextCallback = fn (?*anyopaque, [*c]const u8, usize, RtfStyleInfo) callconv(.C) void;
pub const RtfGroupCallback = fn (?*anyopaque) callconv(.C) void;
pub const RtfErrorCallback = fn (?*anyopaque, RtfError, [*c]const u8) callconv(.C) void;
pub const RtfCharacterCallback = fn (?*anyopaque, u8, RtfStyleInfo) callconv(.C) void;
pub const RtfColorCallback = fn (?*anyopaque, u32, RtfColor) callconv(.C) void;
pub const RtfFontCallback = fn (?*anyopaque, RtfFontInfo) callconv(.C) void;

// Struct containing all callback functions using pointers to functions
// This is needed because extern structs can't have direct function type fields
pub const RtfCallbacks = extern struct {
    // Basic RTF content callbacks
    on_text: ?*const fn (?*anyopaque, [*c]const u8, usize, RtfStyleInfo) callconv(.C) void = null,
    on_group_start: ?*const fn (?*anyopaque) callconv(.C) void = null,
    on_group_end: ?*const fn (?*anyopaque) callconv(.C) void = null,
    
    // Advanced RTF content callbacks
    on_character: ?*const fn (?*anyopaque, u8, RtfStyleInfo) callconv(.C) void = null,
    on_error: ?*const fn (?*anyopaque, RtfError, [*c]const u8) callconv(.C) void = null,
    on_color_table: ?*const fn (?*anyopaque, u32, RtfColor) callconv(.C) void = null,
    on_font_table: ?*const fn (?*anyopaque, RtfFontInfo) callconv(.C) void = null,
    
    // Reserved for future extension
    _reserved1: ?*anyopaque = null,
    _reserved2: ?*anyopaque = null,
};

// Create a heap-allocated GPA for the C API
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// Convert Zig Style to C-compatible RtfStyleInfo
fn zigStyleToRtfStyleInfo(style: Style) RtfStyleInfo {
    return RtfStyleInfo{
        .bold = style.bold,
        .italic = style.italic,
        .underline = style.underline,
        .strikethrough = style.strikethrough,
        .font_size = style.font_size orelse 0,
        .font_index = if (style.font_family) |id| @as(i16, @intCast(id)) else -1,
        .foreground_color_index = if (style.foreground_color) |id| @as(i16, @intCast(id)) else -1,
        .background_color_index = if (style.background_color) |id| @as(i16, @intCast(id)) else -1,
        .superscript = style.superscript,
        .subscript = style.subscript,
        .hidden = style.hidden,
        .all_caps = style.allcaps,
        .small_caps = style.smallcaps,
    };
}

// ===== Event handler callbacks =====

fn textCallback(ctx: *anyopaque, text: []const u8, style: Style) !void {
    // In newer Zig, we use @as with alignment as needed
    const parser = @as(*RtfParser, @alignCast(@ptrCast(ctx)));
    
    if (parser.callbacks.on_text) |callback| {
        const c_style = zigStyleToRtfStyleInfo(style);
        callback(parser.user_data, text.ptr, text.len, c_style);
    }
}

fn groupStartCallback(ctx: *anyopaque) !void {
    // In newer Zig, we use @as with alignment as needed
    const parser = @as(*RtfParser, @alignCast(@ptrCast(ctx)));
    
    if (parser.callbacks.on_group_start) |callback| {
        callback(parser.user_data);
    }
}

fn groupEndCallback(ctx: *anyopaque) !void {
    // In newer Zig, we use @as with alignment as needed
    const parser = @as(*RtfParser, @alignCast(@ptrCast(ctx)));
    
    if (parser.callbacks.on_group_end) |callback| {
        callback(parser.user_data);
    }
}

fn characterCallback(ctx: *anyopaque, char: u8, style: Style) !void {
    // In newer Zig, we use @as with alignment as needed
    const parser = @as(*RtfParser, @alignCast(@ptrCast(ctx)));
    
    if (parser.callbacks.on_character) |callback| {
        const c_style = zigStyleToRtfStyleInfo(style);
        callback(parser.user_data, char, c_style);
    }
}

fn errorCallback(ctx: *anyopaque, position: []const u8, message: []const u8) !void {
    // In newer Zig, we use @as with alignment as needed
    const parser = @as(*RtfParser, @alignCast(@ptrCast(ctx)));
    
    if (parser.callbacks.on_error) |callback| {
        // Create a combined error message with position info
        var error_message = std.ArrayList(u8).init(parser.allocator);
        defer error_message.deinit();
        
        try error_message.appendSlice(position);
        try error_message.appendSlice(": ");
        try error_message.appendSlice(message);
        try error_message.append(0); // Null terminator
        
        callback(parser.user_data, .RTF_ERROR_PARSE_FAILED, error_message.items.ptr);
    }
}

// ===== C API functions =====

/// Get the API version
pub export fn rtf_get_version(major: [*c]c_int, minor: [*c]c_int, patch: [*c]c_int) callconv(.C) void {
    if (major != null) major.* = RTF_API_VERSION_MAJOR;
    if (minor != null) minor.* = RTF_API_VERSION_MINOR;
    if (patch != null) patch.* = RTF_API_VERSION_PATCH;
}

/// Create a new RTF parser
pub export fn rtf_parser_create() callconv(.C) ?*RtfParser {
    // Use global allocator to simplify memory management
    const parser = gpa.allocator().create(RtfParser) catch return null;
    parser.* = .{
        .allocator = gpa.allocator(),
    };
    return parser;
}

/// Destroy an RTF parser and free all resources
pub export fn rtf_parser_destroy(parser: ?*RtfParser) callconv(.C) void {
    if (parser) |p| {
        p.deinit();
        gpa.allocator().destroy(p);
    }
}

/// Set callback functions for RTF events
pub export fn rtf_parser_set_callbacks(
    parser: ?*RtfParser,
    callbacks: ?*const RtfCallbacks,
    user_data: ?*anyopaque
) callconv(.C) RtfError {
    if (parser == null or callbacks == null) {
        return .RTF_ERROR_INVALID_PARAMETER;
    }
    
    var p = parser.?;
    
    // Copy each callback individually to avoid pointer dereferencing issues
    p.callbacks.on_text = callbacks.?.on_text;
    p.callbacks.on_group_start = callbacks.?.on_group_start;
    p.callbacks.on_group_end = callbacks.?.on_group_end;
    p.callbacks.on_character = callbacks.?.on_character;
    p.callbacks.on_error = callbacks.?.on_error;
    p.callbacks.on_color_table = callbacks.?.on_color_table;
    p.callbacks.on_font_table = callbacks.?.on_font_table;
    p.callbacks._reserved1 = callbacks.?._reserved1;
    p.callbacks._reserved2 = callbacks.?._reserved2;
    
    p.user_data = user_data;
    
    return .RTF_OK;
}

/// Parse RTF data from memory with specific options
pub export fn rtf_parser_parse_memory_with_options(
    parser: ?*RtfParser,
    data: [*c]const u8,
    length: usize,
    options: *const RtfParseOptions
) callconv(.C) RtfError {
    if (parser == null or data == null or length == 0) {
        return .RTF_ERROR_INVALID_PARAMETER;
    }
    
    const p = parser.?;
    
    // Create ByteStream for memory input
    p.stream = p.allocator.create(ByteStream) catch {
        p.setError(.RTF_ERROR_MEMORY, "Failed to allocate memory for ByteStream");
        return .RTF_ERROR_MEMORY;
    };
    p.stream.?.* = ByteStream.initMemory(data[0..length]);
    
    // Create Tokenizer
    p.tokenizer = p.allocator.create(Tokenizer) catch {
        p.setError(.RTF_ERROR_MEMORY, "Failed to allocate memory for Tokenizer");
        return .RTF_ERROR_MEMORY;
    };
    p.tokenizer.?.* = Tokenizer.init(p.stream.?, p.allocator);
    
    // Set up event handler
    const handler = EventHandler{
        .context = p,
        .onGroupStart = groupStartCallback,
        .onGroupEnd = groupEndCallback,
        .onText = textCallback,
        .onCharacter = characterCallback,
        .onError = errorCallback,
        .onBinary = null, // TODO: Add binary data callback
    };
    
    // Choose recovery strategy based on options
    const strategy = if (options.strict_mode) RecoveryStrategy.strict else RecoveryStrategy.tolerant;
    
    // Create Parser
    p.parser = p.allocator.create(Parser) catch {
        p.setError(.RTF_ERROR_MEMORY, "Failed to allocate memory for Parser");
        return .RTF_ERROR_MEMORY;
    };
    
    p.parser.?.* = try Parser.initWithStrategy(
        p.tokenizer.?, 
        p.allocator, 
        handler, 
        strategy, 
        options.max_depth
    );
    
    // Parse the document
    p.parser.?.parse() catch |err| {
        // Create a meaningful error message
        var error_message = std.ArrayList(u8).init(p.allocator);
        defer error_message.deinit();
        
        error_message.writer().print("Parse error: {s}", .{@errorName(err)}) catch {};
        
        // Only set the error if we have a valid error message
        if (error_message.items.len > 0) {
            p.setError(.RTF_ERROR_PARSE_FAILED, error_message.items);
        } else {
            p.setError(.RTF_ERROR_PARSE_FAILED, "Unknown parse error");
        }
        
        return .RTF_ERROR_PARSE_FAILED;
    };
    
    return .RTF_OK;
}

/// Parse RTF data from memory with default options
pub export fn rtf_parser_parse_memory(
    parser: ?*RtfParser,
    data: [*c]const u8,
    length: usize
) callconv(.C) RtfError {
    // Use default options
    const default_options = RtfParseOptions{};
    return rtf_parser_parse_memory_with_options(parser, data, length, &default_options);
}

/// Get the last error message if an error occurred
pub export fn rtf_parser_get_error_message(
    parser: ?*RtfParser,
    buffer: [*c]u8,
    buffer_size: usize
) callconv(.C) RtfError {
    if (parser == null) return .RTF_ERROR_INVALID_PARAMETER;
    if (buffer == null) return .RTF_ERROR_INVALID_PARAMETER;
    if (buffer_size == 0) return .RTF_ERROR_INVALID_PARAMETER;
    
    const p = parser.?;
    
    if (p.error_message) |message| {
        // Copy message to buffer, truncate if too large
        const copy_len = @min(message.len, buffer_size - 1);
        @memcpy(buffer[0..copy_len], message[0..copy_len]);
        buffer[copy_len] = 0; // Null terminate
        return .RTF_OK;
    } else {
        // No error message
        buffer[0] = 0;
        return .RTF_OK;
    }
}

/// Get the last error code
pub export fn rtf_parser_get_last_error(parser: ?*RtfParser) callconv(.C) RtfError {
    if (parser == null) {
        return .RTF_ERROR_INVALID_PARAMETER;
    }
    
    return parser.?.last_error;
}

/// Parse RTF data from a file with specific options
pub export fn rtf_parser_parse_file_with_options(
    parser: ?*RtfParser,
    filename: [*c]const u8,
    options: *const RtfParseOptions
) callconv(.C) RtfError {
    if (parser == null or filename == null) {
        return .RTF_ERROR_INVALID_PARAMETER;
    }
    
    const p = parser.?;
    
    // Open the file
    const file = std.fs.cwd().openFile(std.mem.sliceTo(filename, 0), .{}) catch {
        p.setError(.RTF_ERROR_FILE_NOT_FOUND, "Failed to open file");
        return .RTF_ERROR_FILE_NOT_FOUND;
    };
    defer file.close();
    
    // Get file size
    const file_size = file.getEndPos() catch {
        p.setError(.RTF_ERROR_FILE_ACCESS, "Failed to determine file size");
        return .RTF_ERROR_FILE_ACCESS;
    };
    
    // For small files, read the whole file into memory and use the memory parser
    if (file_size < options.memory_mapping_threshold or !options.use_memory_mapping) {
        // Read entire file into memory
        const buffer = p.allocator.alloc(u8, @intCast(file_size)) catch {
            p.setError(.RTF_ERROR_MEMORY, "Failed to allocate memory for file contents");
            return .RTF_ERROR_MEMORY;
        };
        defer p.allocator.free(buffer);
        
        _ = file.readAll(buffer) catch {
            p.setError(.RTF_ERROR_FILE_ACCESS, "Failed to read file");
            return .RTF_ERROR_FILE_ACCESS;
        };
        
        // Use the memory parser
        return rtf_parser_parse_memory_with_options(parser, buffer.ptr, buffer.len, options);
    } else {
        // For large files, use memory mapping
        p.stream = p.allocator.create(ByteStream) catch {
            p.setError(.RTF_ERROR_MEMORY, "Failed to allocate memory for ByteStream");
            return .RTF_ERROR_MEMORY;
        };
        
        // Try to open the file with memory mapping
        p.stream.?.* = ByteStream.initFile(file, p.allocator, options.memory_mapping_threshold) catch {
            p.setError(.RTF_ERROR_FILE_ACCESS, "Failed to initialize file stream");
            return .RTF_ERROR_FILE_ACCESS;
        };
        
        // Create the tokenizer
        p.tokenizer = p.allocator.create(Tokenizer) catch {
            p.setError(.RTF_ERROR_MEMORY, "Failed to allocate memory for Tokenizer");
            return .RTF_ERROR_MEMORY;
        };
        p.tokenizer.?.* = Tokenizer.init(p.stream.?, p.allocator);
        
        // Set up event handler
        const handler = EventHandler{
            .context = p,
            .onGroupStart = groupStartCallback,
            .onGroupEnd = groupEndCallback,
            .onText = textCallback,
            .onCharacter = characterCallback,
            .onError = errorCallback,
            .onBinary = null, // TODO: Add binary data callback
        };
        
        // Choose recovery strategy based on options
        const strategy = if (options.strict_mode) RecoveryStrategy.strict else RecoveryStrategy.tolerant;
        
        // Create Parser
        p.parser = p.allocator.create(Parser) catch {
            p.setError(.RTF_ERROR_MEMORY, "Failed to allocate memory for Parser");
            return .RTF_ERROR_MEMORY;
        };
        
        p.parser.?.* = try Parser.initWithStrategy(
            p.tokenizer.?, 
            p.allocator, 
            handler, 
            strategy, 
            options.max_depth
        );
        
        // Parse the document
        p.parser.?.parse() catch |err| {
            // Create a meaningful error message
            var error_message = std.ArrayList(u8).init(p.allocator);
            defer error_message.deinit();
            
            error_message.writer().print("Parse error: {s}", .{@errorName(err)}) catch {};
            
            // Only set the error if we have a valid error message
            if (error_message.items.len > 0) {
                p.setError(.RTF_ERROR_PARSE_FAILED, error_message.items);
            } else {
                p.setError(.RTF_ERROR_PARSE_FAILED, "Unknown parse error");
            }
            
            return .RTF_ERROR_PARSE_FAILED;
        };
        
        return .RTF_OK;
    }
}

/// Parse RTF data from a file with default options
pub export fn rtf_parser_parse_file(
    parser: ?*RtfParser,
    filename: [*c]const u8
) callconv(.C) RtfError {
    // Use default options
    const default_options = RtfParseOptions{};
    return rtf_parser_parse_file_with_options(parser, filename, &default_options);
}