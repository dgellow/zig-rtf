const std = @import("std");
const testing = std.testing;
const Parser = @import("parser.zig").Parser;
const ParserState = @import("parser.zig").ParserState;
const Style = @import("parser.zig").Style;
const EventHandler = @import("parser.zig").EventHandler;
const ByteStream = @import("byte_stream.zig").ByteStream;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const getHandler = @import("control_word_handlers.zig").getHandler;
const handleBold = @import("control_word_handlers.zig").handleBold;
const handleItalic = @import("control_word_handlers.zig").handleItalic;
const handleFont = @import("control_word_handlers.zig").handleFont;
const handleFontSize = @import("control_word_handlers.zig").handleFontSize;
const handleForeColor = @import("control_word_handlers.zig").handleForeColor;
const handleBackColor = @import("control_word_handlers.zig").handleBackColor;
const handleSuperscript = @import("control_word_handlers.zig").handleSuperscript;
const handleSubscript = @import("control_word_handlers.zig").handleSubscript;
const handleSmallCaps = @import("control_word_handlers.zig").handleSmallCaps;
const handleAllCaps = @import("control_word_handlers.zig").handleAllCaps;
const handlePlain = @import("control_word_handlers.zig").handlePlain;
const handleUc = @import("control_word_handlers.zig").handleUc;
const handleU = @import("control_word_handlers.zig").handleU;
const handleUnimplemented = @import("control_word_handlers.zig").handleUnimplemented;

test "Control word - basic style handling" {
    var state = ParserState.init();
    
    // Initially all style properties should be false/default
    try testing.expectEqual(false, state.current_style.bold);
    try testing.expectEqual(false, state.current_style.italic);
    
    // Test bold control word
    handleBold(&state, 1);
    try testing.expectEqual(true, state.current_style.bold);
    
    // Turn off bold
    handleBold(&state, 0);
    try testing.expectEqual(false, state.current_style.bold);
    
    // Test italic
    handleItalic(&state, null); // Default parameter is 1 (on)
    try testing.expectEqual(true, state.current_style.italic);
}

test "Control word - font and size" {
    var state = ParserState.init();
    
    // Test font family
    const font_id: i32 = 2;
    handleFont(&state, font_id);
    try testing.expectEqual(@as(?u16, 2), state.current_style.font_family);
    
    // Test font size (RTF stores half-points)
    const font_size: i32 = 24; // 12pt
    handleFontSize(&state, font_size);
    try testing.expectEqual(@as(?u16, 24), state.current_style.font_size);
}

test "Control word - colors" {
    var state = ParserState.init();
    
    // Test foreground color
    const fg_color: i32 = 2;
    handleForeColor(&state, fg_color);
    try testing.expectEqual(@as(?u16, 2), state.current_style.foreground_color);
    
    // Test background color
    const bg_color: i32 = 3;
    handleBackColor(&state, bg_color);
    try testing.expectEqual(@as(?u16, 3), state.current_style.background_color);
}

test "Control word - special formatting" {
    var state = ParserState.init();
    
    // Test superscript
    handleSuperscript(&state, 1);
    try testing.expectEqual(true, state.current_style.superscript);
    try testing.expectEqual(false, state.current_style.subscript); // Should be exclusive
    
    // Test subscript
    handleSubscript(&state, 1);
    try testing.expectEqual(true, state.current_style.subscript);
    try testing.expectEqual(false, state.current_style.superscript); // Should be turned off
    
    // Test small caps
    handleSmallCaps(&state, 1);
    try testing.expectEqual(true, state.current_style.smallcaps);
    
    // Test all caps
    handleAllCaps(&state, 1);
    try testing.expectEqual(true, state.current_style.allcaps);
}

test "Control word - reset with \\plain" {
    var state = ParserState.init();
    
    // Setup some formatting
    state.current_style.bold = true;
    state.current_style.italic = true;
    state.current_style.underline = true;
    state.current_style.font_size = 24;
    state.current_style.foreground_color = 2;
    
    // Apply \plain
    handlePlain(&state, null);
    
    // Character attributes should be reset
    try testing.expectEqual(false, state.current_style.bold);
    try testing.expectEqual(false, state.current_style.italic);
    try testing.expectEqual(false, state.current_style.underline);
    
    // Font and colors should remain
    try testing.expectEqual(@as(?u16, 24), state.current_style.font_size);
    try testing.expectEqual(@as(?u16, 2), state.current_style.foreground_color);
}

test "Control word - lookup table coverage" {
    const expected_control_words = [_][]const u8{
        "b", "i", "ul", "strike", "f", "fs", "cf", "cb",
        "super", "sub", "scaps", "caps", "plain", "ansi",
        "mac", "pard"
    };
    
    for (expected_control_words) |word| {
        // Test that we get a valid handler function for expected control words
        const handler = getHandler(word);
        try testing.expect(handler != handleUnimplemented);
    }
}

test "Control word - unicode handling" {
    var state = ParserState.init();
    
    // Test unicode skip count
    const skip_count: i32 = 2;
    handleUc(&state, skip_count);
    try testing.expectEqual(@as(usize, 2), state.unicode_skip_count);
    
    // Test unicode character storage
    const unicode_char: i32 = 8364; // Euro symbol
    handleU(&state, unicode_char);
    try testing.expectEqual(@as(?i32, 8364), state.last_unicode_char);
}

// Global variables for integration test
var g_styles: [10]Style = undefined;
var g_style_count: usize = 0;
var g_texts: [10][]u8 = undefined;
var g_text_count: usize = 0;

fn testTextCallback(ctx: *anyopaque, text: []const u8, style: Style) anyerror!void {
    _ = ctx;
    if (g_text_count < g_texts.len) {
        g_texts[g_text_count] = testing.allocator.dupe(u8, text) catch unreachable;
        g_styles[g_text_count] = style;
        g_text_count += 1;
    }
}

test "Control Word - integration with parser" {
    const rtf_content = "{\\rtf1{\\b Bold text}{\\i Italic text}}";
    
    // Reset global counters
    g_text_count = 0;
    g_style_count = 0;
    
    var stream = ByteStream.initMemory(rtf_content);
    var tokenizer = Tokenizer.init(&stream, testing.allocator);
    defer tokenizer.deinit();
    
    // Setup handler with test callback
    const handler = EventHandler{
        .context = null,
        .onText = testTextCallback,
    };
    
    var parser = try Parser.init(&tokenizer, testing.allocator, handler);
    defer parser.deinit();
    
    try parser.parse();
    
    // Free captured text
    defer {
        for (0..g_text_count) |i| {
            testing.allocator.free(g_texts[i]);
        }
    }
    
    // Verify text and styles were captured
    try testing.expectEqual(@as(usize, 2), g_text_count);
    try testing.expectEqualStrings("Bold text", g_texts[0]);
    try testing.expectEqualStrings("Italic text", g_texts[1]);
    
    // First style should have bold=true
    try testing.expectEqual(true, g_styles[0].bold);
    try testing.expectEqual(false, g_styles[0].italic);
    
    // Second style should have italic=true
    try testing.expectEqual(false, g_styles[1].bold);
    try testing.expectEqual(true, g_styles[1].italic);
}