const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const TokenType = @import("tokenizer.zig").TokenType;
const Token = @import("tokenizer.zig").Token;
const getHandler = @import("control_word_handlers.zig").getHandler;

// Error recovery strategy options
pub const RecoveryStrategy = enum {
    strict,     // Fail on first error
    tolerant,   // Try to recover and continue
    permissive, // Accept malformed RTF and do best effort parsing
};

pub const CharacterSet = enum {
    ansi,
    mac,
    pc,
    pca,
    ansicpg,
};

pub const Style = struct {
    // Character formatting
    font_family: ?u16 = null,
    font_size: ?u16 = null,
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    strikethrough: bool = false,
    foreground_color: ?u16 = null,
    background_color: ?u16 = null,

    // Additional character formatting properties
    superscript: bool = false,
    subscript: bool = false,
    smallcaps: bool = false,
    allcaps: bool = false,
    hidden: bool = false,

    pub fn merge(self: Style, other: Style) Style {
        var result = self;

        // Apply non-null properties from other
        if (other.font_family != null) result.font_family = other.font_family;
        if (other.font_size != null) result.font_size = other.font_size;
        if (other.foreground_color != null) result.foreground_color = other.foreground_color;
        if (other.background_color != null) result.background_color = other.background_color;
        
        // Apply boolean properties
        result.bold = other.bold;
        result.italic = other.italic;
        result.underline = other.underline;
        result.strikethrough = other.strikethrough;
        result.superscript = other.superscript;
        result.subscript = other.subscript;
        result.smallcaps = other.smallcaps;
        result.allcaps = other.allcaps;
        result.hidden = other.hidden;

        return result;
    }
};

pub const ParserState = struct {
    // Document-level state
    character_set: CharacterSet = .ansi,
    default_language: u16 = 1033, // English (US)
    code_page: u32 = 1252, // Default Windows code page (Western Latin)

    // Style management
    current_style: Style = .{},
    
    // Unicode handling
    unicode_skip_count: usize = 1,
    last_unicode_char: ?i32 = null, // For tracking Unicode characters from \u control word
    
    // Destination tracking
    in_header: bool = false,
    in_footer: bool = false,
    in_footnote: bool = false,
    in_table: bool = false,
    in_field: bool = false,
    in_pict: bool = false,
    
    // Group state management
    group_level: usize = 0,
    
    // Document structure state
    in_paragraph: bool = false,
    in_section: bool = false,
    
    pub fn init() ParserState {
        return .{};
    }

    pub fn processControlWord(self: *ParserState, name: []const u8, parameter: ?i32) void {
        // Get the appropriate handler for this control word
        const handler = getHandler(name);
        
        // Execute the handler
        handler(self, parameter);
    }
};

pub const EventHandler = struct {
    context: ?*anyopaque = null,
    onGroupStart: ?*const fn(*anyopaque) anyerror!void = null,
    onGroupEnd: ?*const fn(*anyopaque) anyerror!void = null,
    onText: ?*const fn(*anyopaque, text: []const u8, style: Style) anyerror!void = null,
    onCharacter: ?*const fn(*anyopaque, char: u8, style: Style) anyerror!void = null,
    onError: ?*const fn(*anyopaque, position: []const u8, message: []const u8) anyerror!void = null,
    onBinary: ?*const fn(*anyopaque, data: []const u8, length: usize) anyerror!void = null,

    pub fn init() EventHandler {
        return .{
            .onGroupStart = null,
            .onGroupEnd = null,
            .onText = null,
            .onCharacter = null,
            .onError = null,
        };
    }
};

pub const Parser = struct {
    tokenizer: *Tokenizer,
    state: ParserState,
    handler: EventHandler,
    allocator: std.mem.Allocator,
    
    // Group stack for state preservation
    group_stack: std.ArrayList(ParserState),
    
    // Error recovery settings
    recovery_strategy: RecoveryStrategy = .tolerant,
    
    // Maximum allowed group nesting depth
    max_group_depth: usize = 100,

    pub fn init(tokenizer: *Tokenizer, allocator: std.mem.Allocator, handler: EventHandler) !Parser {
        return initWithStrategy(tokenizer, allocator, handler, .tolerant, 100);
    }
    
    pub fn initWithStrategy(
        tokenizer: *Tokenizer, 
        allocator: std.mem.Allocator, 
        handler: EventHandler, 
        strategy: RecoveryStrategy,
        max_depth: usize,
    ) !Parser {
        return .{
            .tokenizer = tokenizer,
            .state = ParserState.init(),
            .handler = handler,
            .allocator = allocator,
            .group_stack = std.ArrayList(ParserState).init(allocator),
            .recovery_strategy = strategy,
            .max_group_depth = max_depth,
        };
    }
    
    pub fn initWithOptions(
        tokenizer: *Tokenizer, 
        allocator: std.mem.Allocator, 
        handler: EventHandler, 
        options: struct {
            recovery_strategy: RecoveryStrategy = .tolerant,
            max_group_depth: usize = 100,
        },
    ) !Parser {
        return .{
            .tokenizer = tokenizer,
            .state = ParserState.init(),
            .handler = handler,
            .allocator = allocator,
            .group_stack = std.ArrayList(ParserState).init(allocator),
            .recovery_strategy = options.recovery_strategy,
            .max_group_depth = options.max_group_depth,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.group_stack.deinit();
        
        // Clean up any other resources here if needed as the parser state grows
    }
    
    // Find a synchronization point after an error
    fn synchronize(self: *Parser) !void {
        // Skip tokens until we find a good synchronization point
        var depth: isize = 0;
        
        while (true) {
            const token = self.tokenizer.nextToken() catch |err| {
                // If we hit an error while trying to recover, just bail out
                return err;
            };
            
            switch (token.type) {
                .EOF => break, // Reached end of file
                
                .GROUP_START => {
                    depth += 1;
                },
                
                .GROUP_END => {
                    depth -= 1;
                    if (depth < 0) {
                        // We've found an unmatched group end, use it as a sync point
                        // This likely indicates we're at a good boundary
                        break;
                    }
                },
                
                .CONTROL_WORD => {
                    // Free the control word name to avoid memory leaks
                    defer self.allocator.free(token.data.control_word.name);
                    
                    // These control words often indicate structure boundaries
                    const name = token.data.control_word.name;
                    const is_boundary = std.mem.eql(u8, name, "par") or
                                     std.mem.eql(u8, name, "pard") or
                                     std.mem.eql(u8, name, "sect") or
                                     std.mem.eql(u8, name, "sectd") or
                                     std.mem.eql(u8, name, "plain") or
                                     std.mem.eql(u8, name, "page");
                                     
                    if (is_boundary and depth <= 0) {
                        // Found a good boundary at a balanced group level
                        break;
                    }
                },
                
                .TEXT, .HEX_CHAR, .BINARY_DATA, .CONTROL_SYMBOL, .ERROR => {
                    // Skip these tokens during synchronization
                    if (token.type == .TEXT) {
                        self.allocator.free(token.data.text);
                    }
                },
            }
        }
    }

    pub fn parse(self: *Parser) !void {
        errdefer {
            // Clean up group stack if we exit with an error
            self.group_stack.clearRetainingCapacity();
        }
        
        while (true) {
            // Get the next token and handle errors
            const token = self.tokenizer.nextToken() catch |err| {
                // Handle tokenization errors according to recovery strategy
                if (self.handler.onError) |callback| {
                    // Create a generic error message since we don't have token position
                    var err_buf: [128]u8 = undefined;
                    const err_str = std.fmt.bufPrint(&err_buf, "Tokenization error: {s}", .{@errorName(err)}) catch "Tokenization error";
                    
                    // Use a placeholder position since we don't have token position
                    try callback(
                        self.handler.context orelse undefined,
                        "Unknown position",
                        err_str
                    );
                }
                
                // Apply recovery strategy
                switch (self.recovery_strategy) {
                    .strict => return err, // In strict mode, propagate the error
                    .tolerant, .permissive => {
                        // Try to recover by attempting to synchronize
                        self.synchronize() catch |sync_err| {
                            // If synchronization fails, we have to give up
                            if (self.recovery_strategy == .tolerant) {
                                return sync_err;
                            }
                            // In permissive mode, try to continue anyway
                        };
                        // Create a synthetic EOF token if we can't recover
                        // to avoid infinite loops
                        if (err == error.EndOfStream) {
                            break;
                        }
                        // Skip to the next iteration, trying to get another token
                        continue;
                    },
                }
            };
            
            // We're using inline switch so we can add defer blocks for token memory cleanup
            switch (token.type) {
                .EOF => {
                    // Check for unclosed groups at EOF
                    if (self.group_stack.items.len > 0) {
                        if (self.handler.onError) |callback| {
                            try callback(
                                self.handler.context orelse undefined,
                                "End of file",
                                "Unclosed groups detected: document has more opening braces than closing braces"
                            );
                        }
                        
                        // In strict mode, this is an error
                        if (self.recovery_strategy == .strict) {
                            return error.UnclosedGroups;
                        }
                        
                        // In tolerant or permissive mode, we'll continue and let the parser
                        // clean up the group stack
                    }
                    break;
                },
                
                .ERROR => {
                    // Handle error tokens by calling the error handler
                    if (self.handler.onError) |callback| {
                        // Convert position to string for the callback
                        var pos_buf: [64]u8 = undefined;
                        const pos_str = try std.fmt.bufPrint(
                            &pos_buf, 
                            "Line {d}, Column {d}", 
                            .{token.position.line, token.position.column}
                        );
                        
                        try callback(
                            self.handler.context orelse undefined,
                            pos_str,
                            token.data.error_message
                        );
                    }
                    
                    // Apply the configured recovery strategy
                    switch (self.recovery_strategy) {
                        .strict => {
                            // In strict mode, fail on first error
                            return error.ParseError;
                        },
                        .tolerant => {
                            // In tolerant mode, try to find a synchronization point and continue
                            try self.synchronize();
                        },
                        .permissive => {
                            // In permissive mode, just continue parsing from the next token
                            // This is the most lenient approach
                        },
                    }
                },
                
                .GROUP_START => {
                    // Check for excessive nesting which could indicate malformed RTF
                    // or a malicious document trying to cause stack overflow
                    if (self.group_stack.items.len >= self.max_group_depth) {
                        if (self.handler.onError) |callback| {
                            var pos_buf: [64]u8 = undefined;
                            const pos_str = try std.fmt.bufPrint(
                                &pos_buf, 
                                "Line {d}, Column {d}", 
                                .{token.position.line, token.position.column}
                            );
                            
                            try callback(
                                self.handler.context orelse undefined,
                                pos_str,
                                "Maximum group nesting depth exceeded"
                            );
                        }
                        
                        // Handle according to recovery strategy
                        switch (self.recovery_strategy) {
                            .strict => {
                                return error.NestingTooDeep;
                            },
                            .tolerant => {
                                // In tolerant mode, try to skip to a balancing group end
                                try self.synchronize();
                                continue;
                            },
                            .permissive => {
                                // In permissive mode, treat it as a normal character
                                if (self.handler.onText) |text_callback| {
                                    try text_callback(
                                        self.handler.context orelse undefined,
                                        "{",
                                        self.state.current_style
                                    );
                                }
                                continue;
                            },
                        }
                    }
                    
                    // Save current state when entering a group
                    try self.group_stack.append(self.state);
                    self.state.group_level += 1;
                    
                    if (self.handler.onGroupStart) |callback| {
                        try callback(self.handler.context orelse undefined);
                    }
                },
                
                .GROUP_END => {
                    // Restore state when exiting a group
                    if (self.group_stack.items.len > 0) {
                        const maybe_state = self.group_stack.pop();
                        if (maybe_state) |state| {
                            self.state = state;
                        }
                        
                        if (self.handler.onGroupEnd) |callback| {
                            try callback(self.handler.context orelse undefined);
                        }
                    } else {
                        // Unbalanced group - too many closing braces
                        if (self.handler.onError) |callback| {
                            var pos_buf: [64]u8 = undefined;
                            const pos_str = try std.fmt.bufPrint(
                                &pos_buf, 
                                "Line {d}, Column {d}", 
                                .{token.position.line, token.position.column}
                            );
                            
                            try callback(
                                self.handler.context orelse undefined,
                                pos_str,
                                "Unbalanced group: extra closing brace"
                            );
                        }
                        
                        // Handle according to recovery strategy
                        switch (self.recovery_strategy) {
                            .strict => {
                                return error.UnbalancedGroup;
                            },
                            .tolerant, .permissive => {
                                // In tolerant and permissive modes, we'll ignore the unbalanced brace
                                // and continue parsing
                            },
                        }
                    }
                },
                
                .CONTROL_WORD => {
                    const control = token.data.control_word;
                    
                    // Use defer to ensure memory is freed even if processing fails
                    defer self.allocator.free(control.name);
                    
                    // Special handling for Unicode character control word (\u)
                    if (std.mem.eql(u8, control.name, "u") and control.parameter != null) {
                        // Process Unicode character
                        const unicode_char = control.parameter.?;
                        
                        // Store for later use
                        self.state.last_unicode_char = unicode_char;
                        
                        // If we have a character handler, send the Unicode character
                        if (self.handler.onCharacter) |callback| {
                            // Convert signed 16-bit Unicode to unsigned byte if in ASCII range
                            if (unicode_char >= 0 and unicode_char <= 255) {
                                const byte_char = @as(u8, @intCast(@as(u32, @intCast(unicode_char))));
                                try callback(self.handler.context orelse undefined, byte_char, self.state.current_style);
                            } else {
                                // For non-ASCII Unicode, we'd need proper UTF-8 encoding
                                // For now, just send a placeholder character
                                try callback(self.handler.context orelse undefined, '?', self.state.current_style);
                            }
                        }
                        
                        // Skip the next N characters as per the Unicode skip count
                        var skip_count = self.state.unicode_skip_count;
                        while (skip_count > 0) : (skip_count -= 1) {
                            _ = try self.tokenizer.nextToken(); // Skip token
                        }
                    } else {
                        // Regular control word handling
                        self.state.processControlWord(control.name, control.parameter);
                    }
                },
                
                .CONTROL_SYMBOL => {
                    // Handle RTF control symbols
                    const symbol = token.data.control_symbol;
                    
                    // Apply style changes based on control symbols
                    switch (symbol) {
                        // Common RTF control symbols
                        '~' => { // Non-breaking space
                            if (self.handler.onText) |callback| {
                                try callback(self.handler.context orelse undefined, " ", self.state.current_style);
                            }
                        },
                        '-' => { // Optional hyphen
                            if (self.handler.onText) |callback| {
                                try callback(self.handler.context orelse undefined, "-", self.state.current_style);
                            }
                        },
                        '_' => { // Non-breaking hyphen
                            if (self.handler.onText) |callback| {
                                try callback(self.handler.context orelse undefined, "-", self.state.current_style);
                            }
                        },
                        '*' => { // Annotation marker - for now, just ignore
                            // Used with \annotation control word
                        },
                        ':' => { // Subentry in index entry - for now, just ignore
                            // Used with index entries
                        },
                        '|' => { // Formula character - for now, just ignore
                            // Used in equations
                        },
                        '\\' => { // Literal backslash
                            if (self.handler.onText) |callback| {
                                try callback(self.handler.context orelse undefined, "\\", self.state.current_style);
                            }
                        },
                        '{' => { // Literal opening brace
                            if (self.handler.onText) |callback| {
                                try callback(self.handler.context orelse undefined, "{", self.state.current_style);
                            }
                        },
                        '}' => { // Literal closing brace
                            if (self.handler.onText) |callback| {
                                try callback(self.handler.context orelse undefined, "}", self.state.current_style);
                            }
                        },
                        // Other symbols might be handled in future extensions
                        else => {
                            // Unknown control symbol - for now, we'll ignore it
                            // Future versions could report these as warnings
                        }
                    }
                },
                
                .TEXT => {
                    // Use defer to ensure memory is freed even if callback fails
                    defer self.allocator.free(token.data.text);
                    
                    if (self.handler.onText) |callback| {
                        try callback(self.handler.context orelse undefined, token.data.text, self.state.current_style);
                    }
                },
                
                .HEX_CHAR => {
                    if (self.handler.onCharacter) |callback| {
                        try callback(self.handler.context orelse undefined, token.data.hex, self.state.current_style);
                    }
                },
                
                .BINARY_DATA => {
                    // Handle binary data (e.g., embedded images)
                    // The tokenizer has already identified this as binary data
                    // with a specific length and offset in the source
                    
                    // Get the binary data information
                    const binary_info = token.data.binary;
                    
                    // Check if we have a binary data handler
                    if (self.handler.onBinary) |callback| {
                        // For now, create a placeholder buffer for the binary data
                        // In a real implementation, we would extract the actual binary data
                        // from the original source
                        const binary_buffer = try self.allocator.alloc(u8, binary_info.length);
                        defer self.allocator.free(binary_buffer);
                        
                        // Initialize with dummy data
                        @memset(binary_buffer, 0);
                        
                        // Call the binary handler
                        try callback(
                            self.handler.context orelse undefined,
                            binary_buffer,
                            binary_info.length
                        );
                    } else if (self.handler.onText) |text_callback| {
                        // Fallback: notify that binary data was encountered via text
                        var info_buffer: [64]u8 = undefined;
                        const info_str = try std.fmt.bufPrint(
                            &info_buffer, 
                            "[Binary data: {d} bytes]", 
                            .{binary_info.length}
                        );
                        
                        try text_callback(
                            self.handler.context orelse undefined, 
                            info_str, 
                            self.state.current_style
                        );
                    }
                },
            }
        }
    }
};