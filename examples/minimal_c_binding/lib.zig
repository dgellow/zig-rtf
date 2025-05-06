const std = @import("std");

// Simple structure to demonstrate C interop
pub export const RTF_BOLD: c_int = 1;
pub export const RTF_ITALIC: c_int = 2;
pub export const RTF_UNDERLINE: c_int = 4;

// Simple C-compatible RTF information structure
pub const RtfInfo = extern struct {
    text_segments: c_int,
    bold_segments: c_int,
    italic_segments: c_int,
    depth: c_int,
};

// Simplified function that "parses" an RTF string (just counts specific strings)
export fn rtf_parse_string(text: [*c]const u8, info: [*c]RtfInfo) callconv(.C) c_int {
    if (text == null or info == null) return 0;
    
    const str = std.mem.span(text);
    
    // Initialize the info structure
    info.*.text_segments = 0;
    info.*.bold_segments = 0;
    info.*.italic_segments = 0;
    info.*.depth = 0;
    
    var max_depth: c_int = 0;
    var current_depth: c_int = 0;
    
    // Simple counting - not a real parser, just for demonstration
    info.*.text_segments = countSubstring(str, "\\f");
    info.*.bold_segments = countSubstring(str, "\\b");
    info.*.italic_segments = countSubstring(str, "\\i");
    
    // Count brace depth
    for (str) |c| {
        if (c == '{') {
            current_depth += 1;
            if (current_depth > max_depth) {
                max_depth = current_depth;
            }
        } else if (c == '}') {
            current_depth -= 1;
        }
    }
    
    info.*.depth = max_depth;
    
    return 1; // Success
}

// Simple function to count occurrences of a substring
fn countSubstring(haystack: []const u8, needle: []const u8) c_int {
    var count: c_int = 0;
    var i: usize = 0;
    
    while (i + needle.len <= haystack.len) {
        if (std.mem.eql(u8, haystack[i..i+needle.len], needle)) {
            count += 1;
            i += needle.len;
        } else {
            i += 1;
        }
    }
    
    return count;
}

// Version information function
export fn rtf_get_version() callconv(.C) [*:0]const u8 {
    return "ZigRTF 0.1.0 Minimal C Binding";
}