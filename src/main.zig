//! ZigRTF - A high-performance RTF parser in Zig
//! Main executable for demonstrating the RTF parser capabilities

const std = @import("std");
const lib = @import("zig_rtf_lib");

// Import components from the library
const ByteStream = lib.ByteStream;
const Tokenizer = lib.Tokenizer;
const Parser = lib.Parser;
const EventHandler = lib.EventHandler;
const Style = lib.Style;

// Global variables for callbacks
var g_text = std.ArrayList(u8).init(std.heap.page_allocator);

// Text callback handler function
fn textCallback(text: []const u8, style: Style) !void {
    // Add style markers
    if (style.bold) try g_text.appendSlice("**");
    if (style.italic) try g_text.appendSlice("_");
    
    // Add the actual text
    try g_text.appendSlice(text);
    
    // Close style markers
    if (style.italic) try g_text.appendSlice("_");
    if (style.bold) try g_text.appendSlice("**");
    
    // Debug output
    std.debug.print("TEXT: '{s}', bold={}, italic={}\n", .{
        text, style.bold, style.italic
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Get the path to one of our test RTF files
    const test_file_path = try findTestFile(allocator);
    defer allocator.free(test_file_path);
    
    // Read the RTF content
    const rtf_content = try std.fs.cwd().readFileAlloc(allocator, test_file_path, 1024 * 1024); // 1MB max
    defer allocator.free(rtf_content);
    
    // Print info
    const stdout = std.io.getStdOut().writer();
    try stdout.print("=== ZigRTF Parser Demo ===\n", .{});
    try stdout.print("Parsing file: {s}\n", .{test_file_path});
    try stdout.print("File size: {} bytes\n\n", .{rtf_content.len});
    
    // Set up the parser pipeline
    var stream = ByteStream.initMemory(rtf_content);
    var tokenizer = Tokenizer.init(&stream, allocator);
    defer tokenizer.deinit();
    
    // Create event handler with our text callback
    const handler = EventHandler{
        .onGroupStart = null,
        .onGroupEnd = null,
        .onText = textCallback,
        .onCharacter = null,
        .onError = null,
    };
    
    var parser = try Parser.init(&tokenizer, allocator, handler);
    defer parser.deinit();
    
    // Parse the RTF document
    try stdout.print("Parsing document...\n", .{});
    try parser.parse();
    
    // Display the extracted content
    try stdout.print("\nExtracted formatted content:\n", .{});
    try stdout.print("-------------------------\n", .{});
    try stdout.print("{s}\n", .{g_text.items});
    try stdout.print("-------------------------\n", .{});
    try stdout.print("\nParsing complete!\n", .{});
    
    // Free the global text buffer
    g_text.deinit();
}

// Helper function to find one of our test RTF files
fn findTestFile(allocator: std.mem.Allocator) ![]const u8 {
    // Just return a path to one of our test files
    return try allocator.dupe(u8, "/home/sam/zig-rtf/test/data/simple.rtf");
}
