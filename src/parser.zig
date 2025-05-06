const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const TokenType = @import("tokenizer.zig").TokenType;
const Token = @import("tokenizer.zig").Token;

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

    // Style management
    current_style: Style = .{},
    
    // Unicode handling
    unicode_skip_count: usize = 1,

    // Group state management
    group_level: usize = 0,
    
    pub fn init() ParserState {
        return .{};
    }

    pub fn processControlWord(self: *ParserState, name: []const u8, parameter: ?i32) void {
        // Implement basic control word handling
        if (std.mem.eql(u8, name, "b")) {
            self.current_style.bold = parameter != 0;
        } else if (std.mem.eql(u8, name, "i")) {
            self.current_style.italic = parameter != 0;
        } else if (std.mem.eql(u8, name, "ul")) {
            self.current_style.underline = parameter != 0;
        } else if (std.mem.eql(u8, name, "strike")) {
            self.current_style.strikethrough = parameter != 0;
        } else if (std.mem.eql(u8, name, "f")) {
            if (parameter) |font_id| {
                if (font_id >= 0) {
                    self.current_style.font_family = @as(u16, @intCast(@as(u32, @intCast(font_id))));
                }
            }
        } else if (std.mem.eql(u8, name, "fs")) {
            if (parameter) |size| {
                if (size >= 0) {
                    self.current_style.font_size = @as(u16, @intCast(@as(u32, @intCast(size))));
                }
            }
        } else if (std.mem.eql(u8, name, "cf")) {
            if (parameter) |color| {
                if (color >= 0) {
                    self.current_style.foreground_color = @as(u16, @intCast(@as(u32, @intCast(color))));
                }
            }
        } else if (std.mem.eql(u8, name, "cb")) {
            if (parameter) |color| {
                if (color >= 0) {
                    self.current_style.background_color = @as(u16, @intCast(@as(u32, @intCast(color))));
                }
            }
        }
        // More control words will be implemented in a full parser
    }
};

pub const EventHandler = struct {
    onGroupStart: ?*const fn() anyerror!void,
    onGroupEnd: ?*const fn() anyerror!void,
    onText: ?*const fn(text: []const u8, style: Style) anyerror!void,
    onCharacter: ?*const fn(char: u8, style: Style) anyerror!void,
    onError: ?*const fn(position: []const u8, message: []const u8) anyerror!void,

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

    pub fn init(tokenizer: *Tokenizer, allocator: std.mem.Allocator, handler: EventHandler) !Parser {
        return .{
            .tokenizer = tokenizer,
            .state = ParserState.init(),
            .handler = handler,
            .allocator = allocator,
            .group_stack = std.ArrayList(ParserState).init(allocator),
        };
    }

    pub fn deinit(self: *Parser) void {
        self.group_stack.deinit();
    }

    pub fn parse(self: *Parser) !void {
        while (true) {
            const token = try self.tokenizer.nextToken();
            
            switch (token.type) {
                .EOF => break,
                
                .ERROR => {
                    // TODO: Error handling
                },
                
                .GROUP_START => {
                    // Save current state when entering a group
                    try self.group_stack.append(self.state);
                    self.state.group_level += 1;
                    
                    if (self.handler.onGroupStart) |callback| {
                        try callback();
                    }
                },
                
                .GROUP_END => {
                    // Restore state when exiting a group
                    if (self.group_stack.items.len > 0) {
                        const maybe_state = self.group_stack.pop();
                        if (maybe_state) |state| {
                            self.state = state;
                        }
                    }
                    
                    if (self.handler.onGroupEnd) |callback| {
                        try callback();
                    }
                },
                
                .CONTROL_WORD => {
                    const control = token.data.control_word;
                    self.state.processControlWord(control.name, control.parameter);
                    
                    // Free the name memory
                    self.allocator.free(control.name);
                },
                
                .CONTROL_SYMBOL => {
                    // TODO: Handle control symbols
                },
                
                .TEXT => {
                    if (self.handler.onText) |callback| {
                        try callback(token.data.text, self.state.current_style);
                    }
                    
                    // Free the text memory
                    self.allocator.free(token.data.text);
                },
                
                .HEX_CHAR => {
                    if (self.handler.onCharacter) |callback| {
                        try callback(token.data.hex, self.state.current_style);
                    }
                },
                
                .BINARY_DATA => {
                    // TODO: Handle binary data
                },
            }
        }
    }
};