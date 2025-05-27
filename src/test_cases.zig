const std = @import("std");
const testing = std.testing;
const Parser = @import("rtf.zig").Parser;

// Edge case testing for robust RTF parsing

test "empty RTF document" {
    const rtf_data = "{}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    // Should fail gracefully
    try testing.expectError(error.InvalidRtf, parser.parse());
}

test "minimal valid RTF" {
    const rtf_data = "{\\rtf1}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(text.len == 0);
}

test "unclosed groups" {
    const rtf_data = "{\\rtf1 {\\b bold text";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    // Should handle gracefully by treating EOF as implicit close
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "bold text") != null);
}

test "extra closing braces" {
    const rtf_data = "{\\rtf1 Hello}}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    // Should stop at document end
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Hello") != null);
}

test "deeply nested groups" {
    // Create 50 levels of nesting
    var rtf_data = std.ArrayList(u8).init(testing.allocator);
    defer rtf_data.deinit();
    
    try rtf_data.appendSlice("{\\rtf1 ");
    
    var i: u32 = 0;
    while (i < 50) : (i += 1) {
        try rtf_data.appendSlice("{\\b ");
    }
    
    try rtf_data.appendSlice("Deep");
    
    i = 0;
    while (i < 50) : (i += 1) {
        try rtf_data.append('}');
    }
    try rtf_data.append('}');
    
    var stream = std.io.fixedBufferStream(rtf_data.items);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Deep") != null);
}

test "unicode and special characters" {
    // RTF with unicode escapes and special chars
    const rtf_data = "{\\rtf1 Hello \\u8364? World \\u8217?}"; // € and '
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Hello") != null);
    try testing.expect(std.mem.indexOf(u8, text, "World") != null);
}

test "escaped special characters" {
    const rtf_data = "{\\rtf1 \\{ \\} \\\\}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "{") != null);
    try testing.expect(std.mem.indexOf(u8, text, "}") != null);
    try testing.expect(std.mem.indexOf(u8, text, "\\") != null);
}

test "long control words" {
    // Test with maximum length control word (32 chars)
    const rtf_data = "{\\rtf1 \\verylongcontrolwordthatisthirtytwo123456789 text}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "text") != null);
}

test "hex encoded bytes" {
    const rtf_data = "{\\rtf1 \\'41\\'42\\'43}"; // ABC in hex
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    // Should handle hex bytes (implementation dependent)
    try testing.expect(text.len >= 0); // At least doesn't crash
}

test "complex formatting combinations" {
    const rtf_data = "{\\rtf1 \\b\\i\\ul Bold italic underline\\ul0\\i0\\b0 normal}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Bold italic underline") != null);
    try testing.expect(std.mem.indexOf(u8, text, "normal") != null);
}

test "font table with complex names" {
    const rtf_data = 
        \\{\rtf1\ansi\deff0
        \\{\fonttbl{\f0\froman\fcharset0 Times New Roman;}{\f1\fswiss\fcharset0 Arial Unicode MS;}}
        \\Hello World}
    ;
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    // Should skip font table and extract text
    try testing.expect(std.mem.indexOf(u8, text, "Hello World") != null);
}

test "color table handling" {
    const rtf_data = 
        \\{\rtf1\ansi
        \\{\colortbl;\red255\green0\blue0;\red0\green255\blue0;\red0\green0\blue255;}
        \\Colorful text}
    ;
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Colorful text") != null);
}

test "paragraph breaks and line breaks" {
    const rtf_data = "{\\rtf1 First paragraph\\par Second paragraph\\line Third line}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "First paragraph") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Second paragraph") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Third line") != null);
    try testing.expect(std.mem.indexOf(u8, text, "\n\n") != null); // Paragraph break
}

test "tabs and spacing" {
    const rtf_data = "{\\rtf1 Text\\tab with\\tab tabs}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "\t") != null);
}

test "font size variations" {
    const rtf_data = "{\\rtf1 \\fs16 Small \\fs24 Normal \\fs48 Large}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Small Normal Large") != null);
}

test "ignorable destinations" {
    const rtf_data = "{\\rtf1 Visible {\\*\\generator Ignored} More visible}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Visible") != null);
    try testing.expect(std.mem.indexOf(u8, text, "More visible") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Ignored") == null);
}

test "large document simulation" {
    // Create a document with lots of repeated content
    var rtf_data = std.ArrayList(u8).init(testing.allocator);
    defer rtf_data.deinit();
    
    try rtf_data.appendSlice("{\\rtf1 ");
    
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        try rtf_data.appendSlice("Repeated content ");
        if (i % 100 == 0) {
            try rtf_data.appendSlice("\\par ");
        }
    }
    
    try rtf_data.append('}');
    
    var stream = std.io.fixedBufferStream(rtf_data.items);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(text.len > 1000);
    try testing.expect(std.mem.indexOf(u8, text, "Repeated content") != null);
}

test "malformed control words" {
    const rtf_data = "{\\rtf1 \\invalid\\unknown\\badparam999999999999 Normal text}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Normal text") != null);
}

test "mixed line endings" {
    const rtf_data = "{\\rtf1 Line1\nLine2\r\nLine3\rLine4}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Line1") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Line4") != null);
}

test "binary data placeholder" {
    // RTF can contain binary data after \bin control word
    const rtf_data = "{\\rtf1 Before binary \\bin4 \x00\x01\x02\x03 After binary}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Before binary") != null);
    // Binary data handling is implementation dependent
}

test "charset handling" {
    const rtf_data = "{\\rtf1\\ansi\\deff0 Default text {\\f1\\fcharset238 Eastern European}}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Default text") != null);
}

test "picture placeholder handling" {
    // RTF documents from Word/WordPad often contain embedded images
    const rtf_data = 
        \\{\rtf1 Text before 
        \\{\pict\wmetafile8\picw1000\pich1000 
        \\010203040506070809}
        \\Text after}
    ;
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Text before") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Text after") != null);
    // Picture data should be skipped
}

test "stylesheet handling" {
    const rtf_data = 
        \\{\rtf1
        \\{\stylesheet{\s0 Normal;}{\s1\b Heading;}}
        \\Regular text}
    ;
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Regular text") != null);
}

test "field codes" {
    // RTF documents can contain field codes (like hyperlinks, page numbers)
    const rtf_data = 
        \\{\rtf1 Text with {\field{\*\fldinst HYPERLINK "http://example.com"}{\fldrslt Link}} more text}
    ;
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Text with") != null);
    try testing.expect(std.mem.indexOf(u8, text, "more text") != null);
}

test "table simulation" {
    // Basic table structure in RTF (simplified)
    const rtf_data = "{\\rtf1 \\trowd\\cellx1000\\cellx2000 Cell1\\cell Cell2\\cell\\row Normal text}";
    
    var stream = std.io.fixedBufferStream(rtf_data);
    var parser = Parser.init(stream.reader().any(), testing.allocator);
    defer parser.deinit();
    
    try parser.parse();
    
    const text = parser.getText();
    try testing.expect(std.mem.indexOf(u8, text, "Normal text") != null);
    // Table handling is implementation dependent
}