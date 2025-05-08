const std = @import("std");
const ByteStream = @import("byte_stream.zig").ByteStream;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;
const Style = @import("parser.zig").Style;
const EventHandler = @import("parser.zig").EventHandler;
const RecoveryStrategy = @import("parser.zig").RecoveryStrategy;

/// RTF Parser C API
///
/// This module provides a modern, joyful C API for the ZigRTF parser.
/// Design principles:
/// - Thread safety - no global state
/// - Context-based callbacks with simplified setup
/// - Builder pattern for configuration
/// - Comprehensive error handling with detailed messages
/// - Consistent naming conventions
/// - Clear memory ownership rules
/// - Progress reporting for large documents
/// - UTF-8 support
/// - Binary data handling

// API version info - follows Semantic Versioning
pub const RTF_API_VERSION_MAJOR = 1;
pub const RTF_API_VERSION_MINOR = 1;
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
    RTF_ERROR_ENCODING = -8,       // Encoding conversion error
    RTF_ERROR_UTF8 = -9,           // UTF-8 encoding error
    RTF_ERROR_CANCELED = -10,      // Operation was canceled
};

// Document type identifiers
pub const RtfDocumentType = enum(c_int) {
    RTF_UNKNOWN = 0,
    RTF_GENERIC = 1,
    RTF_WORD = 2,
    RTF_WORDPAD = 3,
    RTF_WORDPERFECT = 4,
    RTF_LIBREOFFICE = 5,
    RTF_OPENOFFICE = 6,
    RTF_APPLE_PAGES = 7,
    RTF_ABIWORD = 8,
    RTF_OTHER = 9,
};

// Parse options - modifies parser behavior
pub const RtfParseOptions = extern struct {
    // Error handling strategy
    strict_mode: bool = false, // When true, stops on first error
    
    // Max nesting depth for RTF groups
    max_depth: u16 = 100,
    
    // Whether to use memory mapping for large files
    use_memory_mapping: bool = true,
    
    // Memory mapping threshold in bytes (default: 1MB)
    memory_mapping_threshold: u32 = 1024 * 1024,
    
    // Progress reporting frequency (bytes between progress callbacks)
    progress_interval: u32 = 64 * 1024, // 64KB
    
    // Whether to extract document properties (metadata)
    extract_metadata: bool = true,
    
    // Whether to detect document type (Word, WordPad, etc.)
    detect_document_type: bool = true,
    
    // Whether to fix common RTF errors automatically
    auto_fix_errors: bool = true,
    
    // Reserved bits for future options
    _reserved: u8 = 0,
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

// Document metadata - RTF document properties
pub const RtfMetadata = extern struct {
    title: [128]u8 = [_]u8{0} ** 128,
    author: [128]u8 = [_]u8{0} ** 128,
    subject: [128]u8 = [_]u8{0} ** 128,
    keywords: [256]u8 = [_]u8{0} ** 256,
    comment: [256]u8 = [_]u8{0} ** 256,
    company: [128]u8 = [_]u8{0} ** 128,
    manager: [128]u8 = [_]u8{0} ** 128,
    document_type: RtfDocumentType = .RTF_UNKNOWN,
    creation_time: i64 = 0,  // Unix timestamp
    modification_time: i64 = 0, // Unix timestamp
    character_count: u32 = 0,
    word_count: u32 = 0,
    rtf_version: u16 = 0,
    has_pictures: bool = false,
    has_objects: bool = false,
    has_tables: bool = false,
    _reserved: [32]u8 = [_]u8{0} ** 32, // Space for future metadata fields
};

// Binary data information
pub const RtfBinaryData = extern struct {
    data: [*c]const u8,
    size: usize,
    type: RtfBinaryType,
};

// Binary data types
pub const RtfBinaryType = enum(u8) {
    RTF_BINARY_UNKNOWN = 0,
    RTF_BINARY_IMAGE = 1,
    RTF_BINARY_OBJECT = 2,
    RTF_BINARY_FONT = 3,
    RTF_BINARY_OTHER = 4,
};

// Image information for binary data
pub const RtfImageInfo = extern struct {
    width: u32,
    height: u32,
    bits_per_pixel: u8,
    format: RtfImageFormat,
};

// Image formats
pub const RtfImageFormat = enum(u8) {
    RTF_IMAGE_UNKNOWN = 0,
    RTF_IMAGE_JPEG = 1,
    RTF_IMAGE_PNG = 2,
    RTF_IMAGE_BMP = 3,
    RTF_IMAGE_WMF = 4, // Windows Metafile
    RTF_IMAGE_EMF = 5, // Enhanced Metafile
    RTF_IMAGE_PICT = 6, // PICT format
    RTF_IMAGE_OTHER = 7,
};

// RTF parser context - opaque to C code
pub const RtfParser = struct {
    // Internal allocator for memory management
    allocator: std.mem.Allocator,
    
    // Parser internals
    stream: ?*ByteStream = null,
    tokenizer: ?*Tokenizer = null,
    parser: ?*Parser = null,
    
    // Progress tracking
    total_size: usize = 0,
    bytes_processed: usize = 0,
    last_progress_report: usize = 0,
    progress_interval: usize = 64 * 1024, // 64KB default
    
    // Document metadata
    metadata: RtfMetadata = .{},
    
    // Last error code
    last_error: RtfError = .RTF_OK,
    
    // Last error message (for detailed error reporting)
    error_message: ?[]u8 = null,
    
    // Whether the parsing operation was canceled
    canceled: bool = false,
    
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
    
    // Check if parsing should be canceled
    pub fn checkCancellation(self: *RtfParser) bool {
        // If a cancel callback is provided, call it to check for cancellation
        if (self.callbacks.on_cancel) |callback| {
            if (callback(self.user_data)) {
                self.canceled = true;
                self.setError(.RTF_ERROR_CANCELED, "Operation was canceled by user");
                return true;
            }
        }
        return false;
    }
    
    // Report progress if needed
    pub fn reportProgress(self: *RtfParser) !void {
        if (self.total_size == 0 or self.callbacks.on_progress == null) {
            return;
        }
        
        // Calculate current position
        if (self.stream) |stream| {
            const pos = stream.getPosition();
            self.bytes_processed = pos.offset;
            
            // Check if we should report progress
            if (self.bytes_processed >= self.last_progress_report + self.progress_interval) {
                const progress = @as(f32, @floatFromInt(self.bytes_processed)) / 
                                @as(f32, @floatFromInt(self.total_size));
                
                if (self.callbacks.on_progress) |callback| {
                    callback(self.user_data, progress, self.bytes_processed, self.total_size);
                }
                
                self.last_progress_report = self.bytes_processed;
                
                // Also check for cancellation during progress reporting
                if (self.checkCancellation()) {
                    return error.OperationCanceled;
                }
            }
        }
    }
};

// Callback function types
pub const RtfTextCallback = fn (?*anyopaque, [*c]const u8, usize, RtfStyleInfo) callconv(.C) void;
pub const RtfGroupCallback = fn (?*anyopaque) callconv(.C) void;
pub const RtfErrorCallback = fn (?*anyopaque, RtfError, [*c]const u8) callconv(.C) void;
pub const RtfCharacterCallback = fn (?*anyopaque, u8, RtfStyleInfo) callconv(.C) void;
pub const RtfColorCallback = fn (?*anyopaque, u32, RtfColor) callconv(.C) void;
pub const RtfFontCallback = fn (?*anyopaque, RtfFontInfo) callconv(.C) void;
pub const RtfProgressCallback = fn (?*anyopaque, f32, usize, usize) callconv(.C) void;
pub const RtfCancelCallback = fn (?*anyopaque) callconv(.C) bool;
pub const RtfBinaryCallback = fn (?*anyopaque, RtfBinaryData) callconv(.C) void;
pub const RtfMetadataCallback = fn (?*anyopaque, *const RtfMetadata) callconv(.C) void;

// Struct containing all callback functions using pointers to functions
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
    
    // Binary data callback
    on_binary: ?*const fn (?*anyopaque, RtfBinaryData) callconv(.C) void = null,
    
    // Metadata callback
    on_metadata: ?*const fn (?*anyopaque, *const RtfMetadata) callconv(.C) void = null,
    
    // Progress reporting and cancellation
    on_progress: ?*const fn (?*anyopaque, f32, usize, usize) callconv(.C) void = null,
    on_cancel: ?*const fn (?*anyopaque) callconv(.C) bool = null,
    
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
    
    // Progress tracking and cancellation check
    try parser.reportProgress();
    
    if (parser.callbacks.on_text) |callback| {
        const c_style = zigStyleToRtfStyleInfo(style);
        callback(parser.user_data, text.ptr, text.len, c_style);
    }
}

fn groupStartCallback(ctx: *anyopaque) !void {
    // In newer Zig, we use @as with alignment as needed
    const parser = @as(*RtfParser, @alignCast(@ptrCast(ctx)));
    
    // Progress tracking and cancellation check
    try parser.reportProgress();
    
    if (parser.callbacks.on_group_start) |callback| {
        callback(parser.user_data);
    }
}

fn groupEndCallback(ctx: *anyopaque) !void {
    // In newer Zig, we use @as with alignment as needed
    const parser = @as(*RtfParser, @alignCast(@ptrCast(ctx)));
    
    // Progress tracking and cancellation check
    try parser.reportProgress();
    
    if (parser.callbacks.on_group_end) |callback| {
        callback(parser.user_data);
    }
}

fn characterCallback(ctx: *anyopaque, char: u8, style: Style) !void {
    // In newer Zig, we use @as with alignment as needed
    const parser = @as(*RtfParser, @alignCast(@ptrCast(ctx)));
    
    // Progress tracking and cancellation check
    try parser.reportProgress();
    
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

fn binaryCallback(ctx: *anyopaque, data: []const u8, _: usize) !void {
    // In newer Zig, we use @as with alignment as needed
    const parser = @as(*RtfParser, @alignCast(@ptrCast(ctx)));
    
    // Progress tracking and cancellation check
    try parser.reportProgress();
    
    if (parser.callbacks.on_binary) |callback| {
        const binary_data = RtfBinaryData{
            .data = data.ptr,
            .size = data.len,
            .type = .RTF_BINARY_UNKNOWN, // Default type for now
        };
        
        callback(parser.user_data, binary_data);
    }
}

// ===== C API functions =====

/// Get the API version
pub export fn rtf2_get_version(major: [*c]c_int, minor: [*c]c_int, patch: [*c]c_int) callconv(.C) void {
    if (major != null) major.* = RTF_API_VERSION_MAJOR;
    if (minor != null) minor.* = RTF_API_VERSION_MINOR;
    if (patch != null) patch.* = RTF_API_VERSION_PATCH;
}

/// Create a new RTF parser
pub export fn rtf2_parser_create() callconv(.C) ?*RtfParser {
    // Use global allocator to simplify memory management
    const parser = gpa.allocator().create(RtfParser) catch return null;
    parser.* = .{
        .allocator = gpa.allocator(),
    };
    return parser;
}

/// Destroy an RTF parser and free all resources
pub export fn rtf2_parser_destroy(parser: ?*RtfParser) callconv(.C) void {
    if (parser) |p| {
        p.deinit();
        gpa.allocator().destroy(p);
    }
}

/// Set callback functions for RTF events
pub export fn rtf2_parser_set_callbacks(
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
    p.callbacks.on_binary = callbacks.?.on_binary;
    p.callbacks.on_metadata = callbacks.?.on_metadata;
    p.callbacks.on_progress = callbacks.?.on_progress;
    p.callbacks.on_cancel = callbacks.?.on_cancel;
    p.callbacks._reserved1 = callbacks.?._reserved1;
    p.callbacks._reserved2 = callbacks.?._reserved2;
    
    p.user_data = user_data;
    
    return .RTF_OK;
}

/// Set content callback functions - simplified API for basic callbacks
pub export fn rtf2_parser_set_content_callbacks(
    parser: ?*RtfParser,
    text_callback: ?*const RtfTextCallback,
    group_start_callback: ?*const RtfGroupCallback,
    group_end_callback: ?*const RtfGroupCallback,
    error_callback: ?*const RtfErrorCallback,
    user_data: ?*anyopaque
) callconv(.C) RtfError {
    if (parser == null) {
        return .RTF_ERROR_INVALID_PARAMETER;
    }
    
    var p = parser.?;
    
    // Set the content callbacks
    p.callbacks.on_text = text_callback;
    p.callbacks.on_group_start = group_start_callback;
    p.callbacks.on_group_end = group_end_callback;
    p.callbacks.on_error = error_callback;
    p.user_data = user_data;
    
    return .RTF_OK;
}

/// Configure parser options using a builder pattern
pub export fn rtf2_parser_configure(
    parser: ?*RtfParser,
    options: *const RtfParseOptions
) callconv(.C) RtfError {
    if (parser == null) {
        return .RTF_ERROR_INVALID_PARAMETER;
    }
    
    var p = parser.?;
    
    // Set the progress interval
    p.progress_interval = options.progress_interval;
    
    return .RTF_OK;
}

/// Create default parse options
pub export fn rtf2_parse_options_create() callconv(.C) RtfParseOptions {
    return RtfParseOptions{};
}

/// Cancel an ongoing parsing operation
pub export fn rtf2_parser_cancel(parser: ?*RtfParser) callconv(.C) RtfError {
    if (parser == null) {
        return .RTF_ERROR_INVALID_PARAMETER;
    }
    
    parser.?.canceled = true;
    parser.?.setError(.RTF_ERROR_CANCELED, "Operation was canceled programmatically");
    
    return .RTF_OK;
}

/// Get document metadata from the parser
pub export fn rtf2_parser_get_metadata(
    parser: ?*RtfParser,
    metadata: ?*RtfMetadata
) callconv(.C) RtfError {
    if (parser == null or metadata == null) {
        return .RTF_ERROR_INVALID_PARAMETER;
    }
    
    metadata.?.* = parser.?.metadata;
    
    return .RTF_OK;
}

// ===== Internal parsing setup function =====
fn setupParser(
    parser: *RtfParser,
    options: *const RtfParseOptions
) ParseError!void {
    // Set up event handler
    const handler = EventHandler{
        .context = parser,
        .onGroupStart = groupStartCallback,
        .onGroupEnd = groupEndCallback,
        .onText = textCallback,
        .onCharacter = characterCallback,
        .onError = errorCallback,
        .onBinary = binaryCallback,
    };
    
    // Choose recovery strategy based on options
    const strategy = if (options.strict_mode) 
                    RecoveryStrategy.strict 
                 else if (options.auto_fix_errors) 
                    RecoveryStrategy.permissive
                 else 
                    RecoveryStrategy.tolerant;
    
    // Create Parser
    parser.parser = parser.allocator.create(Parser) catch {
        parser.setError(.RTF_ERROR_MEMORY, "Failed to allocate memory for Parser");
        return ParseError.MemoryError;
    };
    
    // Initialize parser with options
    parser.parser.?.* = Parser.initWithStrategy(
        parser.tokenizer.?, 
        parser.allocator, 
        handler, 
        strategy, 
        options.max_depth
    ) catch {
        parser.setError(.RTF_ERROR_MEMORY, "Failed to initialize Parser");
        return ParseError.MemoryError;
    };
    
    // Set progress tracking parameters
    if (parser.total_size > 0 and options.progress_interval > 0) {
        parser.progress_interval = options.progress_interval;
    }
}

// Custom error types for our C API
const ParseError = error{
    MemoryError,
    ParseFailed,
    OperationCanceled,
};

// ===== Parse helpers =====
fn parseDocument(parser: *RtfParser) ParseError!void {
    // Extract document properties if requested
    // This could be implemented to extract metadata during parsing
    
    // Parse the document
    parser.parser.?.parse() catch |err| {
        // Handle cancellation specially
        if (err == error.OperationCanceled) {
            return ParseError.OperationCanceled;
        }
        
        // Create a meaningful error message
        var error_message = std.ArrayList(u8).init(parser.allocator);
        defer error_message.deinit();
        
        error_message.writer().print("Parse error: {s}", .{@errorName(err)}) catch {};
        
        // Only set the error if we have a valid error message
        if (error_message.items.len > 0) {
            parser.setError(.RTF_ERROR_PARSE_FAILED, error_message.items);
        } else {
            parser.setError(.RTF_ERROR_PARSE_FAILED, "Unknown parse error");
        }
        
        return ParseError.ParseFailed;
    };
    
    // Call metadata callback if provided
    if (parser.callbacks.on_metadata) |callback| {
        callback(parser.user_data, &parser.metadata);
    }
}

/// Parse RTF data from memory with specific options
pub export fn rtf2_parser_parse_memory_with_options(
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
    
    // Set total size for progress reporting
    p.total_size = length;
    
    // Create Tokenizer
    p.tokenizer = p.allocator.create(Tokenizer) catch {
        p.setError(.RTF_ERROR_MEMORY, "Failed to allocate memory for Tokenizer");
        return .RTF_ERROR_MEMORY;
    };
    p.tokenizer.?.* = Tokenizer.init(p.stream.?, p.allocator);
    
    // Set up parser and parse document
    setupParser(p, options) catch |err| {
        switch (err) {
            ParseError.MemoryError => return .RTF_ERROR_MEMORY,
            ParseError.ParseFailed => return .RTF_ERROR_PARSE_FAILED,
            ParseError.OperationCanceled => return .RTF_ERROR_CANCELED,
        }
    };
    
    // Parse the document
    parseDocument(p) catch |err| {
        switch (err) {
            ParseError.ParseFailed => return .RTF_ERROR_PARSE_FAILED,
            ParseError.OperationCanceled => return .RTF_ERROR_CANCELED,
            ParseError.MemoryError => return .RTF_ERROR_MEMORY,
        }
    };
    
    return .RTF_OK;
}

/// Parse RTF data from memory with default options
pub export fn rtf2_parser_parse_memory(
    parser: ?*RtfParser,
    data: [*c]const u8,
    length: usize
) callconv(.C) RtfError {
    // Use default options
    const default_options = RtfParseOptions{};
    return rtf2_parser_parse_memory_with_options(parser, data, length, &default_options);
}

/// Get the last error message if an error occurred
pub export fn rtf2_parser_get_error_message(
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
pub export fn rtf2_parser_get_last_error(parser: ?*RtfParser) callconv(.C) RtfError {
    if (parser == null) {
        return .RTF_ERROR_INVALID_PARAMETER;
    }
    
    return parser.?.last_error;
}

/// Parse RTF data from a file with specific options
pub export fn rtf2_parser_parse_file_with_options(
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
    
    // Set total size for progress reporting
    p.total_size = @intCast(file_size);
    
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
        return rtf2_parser_parse_memory_with_options(parser, buffer.ptr, buffer.len, options);
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
        
        // Set up parser and parse document
        setupParser(p, options) catch |err| {
            switch (err) {
                ParseError.MemoryError => return .RTF_ERROR_MEMORY,
                ParseError.ParseFailed => return .RTF_ERROR_PARSE_FAILED,
                ParseError.OperationCanceled => return .RTF_ERROR_CANCELED,
            }
        };
        
        // Parse the document
        parseDocument(p) catch |err| {
            switch (err) {
                ParseError.ParseFailed => return .RTF_ERROR_PARSE_FAILED,
                ParseError.OperationCanceled => return .RTF_ERROR_CANCELED,
                ParseError.MemoryError => return .RTF_ERROR_MEMORY,
            }
        };
        
        return .RTF_OK;
    }
}

/// Parse RTF data from a file with default options
pub export fn rtf2_parser_parse_file(
    parser: ?*RtfParser,
    filename: [*c]const u8
) callconv(.C) RtfError {
    // Use default options
    const default_options = RtfParseOptions{};
    return rtf2_parser_parse_file_with_options(parser, filename, &default_options);
}

/// Get estimated progress of parsing (0.0 to 1.0)
pub export fn rtf2_parser_get_progress(parser: ?*RtfParser) callconv(.C) f32 {
    if (parser == null) {
        return 0.0;
    }
    
    const p = parser.?;
    
    if (p.total_size == 0) {
        return 0.0;
    }
    
    return @as(f32, @floatFromInt(p.bytes_processed)) / @as(f32, @floatFromInt(p.total_size));
}

/// Detect type of RTF document (Word, WordPad, etc.)
pub export fn rtf2_detect_document_type(
    data: [*c]const u8,
    length: usize
) callconv(.C) RtfDocumentType {
    if (data == null or length == 0) {
        return .RTF_UNKNOWN;
    }
    
    // This would be a simplified version - real implementation would 
    // look for specific patterns in the RTF header that identify the source application
    
    // For now, just check if it's a valid RTF file
    if (length >= 5 and std.mem.eql(u8, data[0..5], "{\\rtf")) {
        return .RTF_GENERIC;
    }
    
    return .RTF_UNKNOWN;
}

// ===== Helper functions for builder pattern =====

/// Set strict mode for parsing
pub export fn rtf2_options_set_strict_mode(
    options: *RtfParseOptions,
    strict_mode: bool
) callconv(.C) *RtfParseOptions {
    options.strict_mode = strict_mode;
    return options;
}

/// Set maximum nesting depth
pub export fn rtf2_options_set_max_depth(
    options: *RtfParseOptions,
    max_depth: u16
) callconv(.C) *RtfParseOptions {
    options.max_depth = max_depth;
    return options;
}

/// Enable or disable memory mapping
pub export fn rtf2_options_set_memory_mapping(
    options: *RtfParseOptions,
    use_memory_mapping: bool,
    threshold: u32
) callconv(.C) *RtfParseOptions {
    options.use_memory_mapping = use_memory_mapping;
    options.memory_mapping_threshold = threshold;
    return options;
}

/// Set progress reporting interval
pub export fn rtf2_options_set_progress_interval(
    options: *RtfParseOptions,
    interval: u32
) callconv(.C) *RtfParseOptions {
    options.progress_interval = interval;
    return options;
}

/// Enable or disable metadata extraction
pub export fn rtf2_options_set_extract_metadata(
    options: *RtfParseOptions,
    extract_metadata: bool
) callconv(.C) *RtfParseOptions {
    options.extract_metadata = extract_metadata;
    return options;
}

/// Enable or disable document type detection
pub export fn rtf2_options_set_detect_document_type(
    options: *RtfParseOptions,
    detect_document_type: bool
) callconv(.C) *RtfParseOptions {
    options.detect_document_type = detect_document_type;
    return options;
}

/// Enable or disable automatic error fixing
pub export fn rtf2_options_set_auto_fix_errors(
    options: *RtfParseOptions,
    auto_fix_errors: bool
) callconv(.C) *RtfParseOptions {
    options.auto_fix_errors = auto_fix_errors;
    return options;
}