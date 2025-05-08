const std = @import("std");
const Style = @import("parser.zig").Style;
const ParserState = @import("parser.zig").ParserState;
const CharacterSet = @import("parser.zig").CharacterSet;

// Type definition for control word handler functions
pub const ControlWordFn = *const fn(state: *ParserState, parameter: ?i32) void;

// Implementation of character formatting control words
pub fn handleBold(state: *ParserState, parameter: ?i32) void {
    state.current_style.bold = (parameter orelse 1) != 0;
}

pub fn handleItalic(state: *ParserState, parameter: ?i32) void {
    state.current_style.italic = (parameter orelse 1) != 0;
}

pub fn handleUnderline(state: *ParserState, parameter: ?i32) void {
    state.current_style.underline = (parameter orelse 1) != 0;
}

pub fn handleStrikethrough(state: *ParserState, parameter: ?i32) void {
    state.current_style.strikethrough = (parameter orelse 1) != 0;
}

pub fn handleFont(state: *ParserState, parameter: ?i32) void {
    if (parameter) |font_id| {
        if (font_id >= 0) {
            state.current_style.font_family = @as(u16, @intCast(@as(u32, @intCast(font_id))));
        }
    }
}

pub fn handleFontSize(state: *ParserState, parameter: ?i32) void {
    if (parameter) |size| {
        if (size >= 0) {
            state.current_style.font_size = @as(u16, @intCast(@as(u32, @intCast(size))));
        }
    }
}

pub fn handleForeColor(state: *ParserState, parameter: ?i32) void {
    if (parameter) |color| {
        if (color >= 0) {
            state.current_style.foreground_color = @as(u16, @intCast(@as(u32, @intCast(color))));
        }
    }
}

pub fn handleBackColor(state: *ParserState, parameter: ?i32) void {
    if (parameter) |color| {
        if (color >= 0) {
            state.current_style.background_color = @as(u16, @intCast(@as(u32, @intCast(color))));
        }
    }
}

pub fn handleSuperscript(state: *ParserState, parameter: ?i32) void {
    state.current_style.superscript = (parameter orelse 1) != 0;
    // When turning on superscript, ensure subscript is turned off
    if (state.current_style.superscript) {
        state.current_style.subscript = false;
    }
}

pub fn handleSubscript(state: *ParserState, parameter: ?i32) void {
    state.current_style.subscript = (parameter orelse 1) != 0;
    // When turning on subscript, ensure superscript is turned off
    if (state.current_style.subscript) {
        state.current_style.superscript = false;
    }
}

pub fn handleSmallCaps(state: *ParserState, parameter: ?i32) void {
    state.current_style.smallcaps = (parameter orelse 1) != 0;
}

pub fn handleAllCaps(state: *ParserState, parameter: ?i32) void {
    state.current_style.allcaps = (parameter orelse 1) != 0;
}

pub fn handleHidden(state: *ParserState, parameter: ?i32) void {
    state.current_style.hidden = (parameter orelse 1) != 0;
}

// Implementation of document-level control words
pub fn handleAnsi(state: *ParserState, parameter: ?i32) void {
    _ = parameter;
    state.character_set = .ansi;
}

pub fn handleMac(state: *ParserState, parameter: ?i32) void {
    _ = parameter;
    state.character_set = .mac;
}

pub fn handlePc(state: *ParserState, parameter: ?i32) void {
    _ = parameter;
    state.character_set = .pc;
}

pub fn handlePca(state: *ParserState, parameter: ?i32) void {
    _ = parameter;
    state.character_set = .pca;
}

pub fn handleAnsicpg(state: *ParserState, parameter: ?i32) void {
    if (parameter) |code_page| {
        state.code_page = @as(u32, @intCast(code_page));
        state.character_set = .ansicpg;
    }
}

pub fn handleUc(state: *ParserState, parameter: ?i32) void {
    if (parameter) |skip_count| {
        if (skip_count >= 0) {
            state.unicode_skip_count = @as(usize, @intCast(@as(u32, @intCast(skip_count))));
        }
    }
}

pub fn handleU(state: *ParserState, parameter: ?i32) void {
    if (parameter) |unicode_char| {
        // Store the unicode character for later processing
        // The actual handling would be done in the parser
        state.last_unicode_char = unicode_char;
    }
}

pub fn handlePlain(state: *ParserState, parameter: ?i32) void {
    _ = parameter;
    
    // Reset character formatting attributes
    state.current_style.bold = false;
    state.current_style.italic = false;
    state.current_style.underline = false;
    state.current_style.strikethrough = false;
    state.current_style.superscript = false;
    state.current_style.subscript = false;
    state.current_style.smallcaps = false;
    state.current_style.allcaps = false;
    state.current_style.hidden = false;
    
    // Don't reset font and color - they are not affected by \plain
}

pub fn handlePard(state: *ParserState, parameter: ?i32) void {
    _ = parameter;
    _ = state;
    // Reset paragraph properties - to be expanded in future implementations
}

// Default handler for unimplemented control words
pub fn handleUnimplemented(state: *ParserState, parameter: ?i32) void {
    _ = state;
    _ = parameter;
    // For future: Could log unimplemented control words if tracking is enabled
}

// Function to look up the appropriate handler for a control word
pub fn getHandler(name: []const u8) ControlWordFn {
    // This simplified implementation uses if/else chains which 
    // will be replaced with a proper hash map in a production implementation
    
    if (std.mem.eql(u8, name, "b")) return handleBold;
    if (std.mem.eql(u8, name, "i")) return handleItalic;
    if (std.mem.eql(u8, name, "ul")) return handleUnderline;
    if (std.mem.eql(u8, name, "strike")) return handleStrikethrough;
    if (std.mem.eql(u8, name, "striked")) return handleStrikethrough;
    if (std.mem.eql(u8, name, "f")) return handleFont;
    if (std.mem.eql(u8, name, "fs")) return handleFontSize;
    if (std.mem.eql(u8, name, "cf")) return handleForeColor;
    if (std.mem.eql(u8, name, "cb")) return handleBackColor;
    if (std.mem.eql(u8, name, "super")) return handleSuperscript;
    if (std.mem.eql(u8, name, "sub")) return handleSubscript;
    if (std.mem.eql(u8, name, "scaps")) return handleSmallCaps;
    if (std.mem.eql(u8, name, "caps")) return handleAllCaps;
    if (std.mem.eql(u8, name, "v")) return handleHidden;
    
    if (std.mem.eql(u8, name, "ansi")) return handleAnsi;
    if (std.mem.eql(u8, name, "mac")) return handleMac;
    if (std.mem.eql(u8, name, "pc")) return handlePc;
    if (std.mem.eql(u8, name, "pca")) return handlePca;
    if (std.mem.eql(u8, name, "ansicpg")) return handleAnsicpg;
    
    if (std.mem.eql(u8, name, "uc")) return handleUc;
    if (std.mem.eql(u8, name, "u")) return handleU;
    
    if (std.mem.eql(u8, name, "plain")) return handlePlain;
    if (std.mem.eql(u8, name, "pard")) return handlePard;
    
    return handleUnimplemented;
}