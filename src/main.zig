//! ZigRTF - A high-performance RTF parser in Zig
//! Main executable for demonstrating the RTF parser capabilities

const std = @import("std");
const lib = @import("zig_rtf_lib");

// Custom errors
const FileError = error{
    TestFilesNotFound,
    FileNotFound,
};

// Import components from the library
const ByteStream = lib.ByteStream;
const Tokenizer = lib.Tokenizer;
const Parser = lib.Parser;
const EventHandler = lib.EventHandler;
const Style = lib.Style;

// Global variables for callbacks
var g_text = std.ArrayList(u8).init(std.heap.page_allocator);

// Text callback handler function
fn textCallback(ctx: *anyopaque, text: []const u8, style: Style) !void {
    _ = ctx; // We're using a global variable instead of context
    
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
    
    // Get args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    const stderr = std.io.getStdErr().writer();
    
    // Get the path to our RTF file - either from args or find a test file
    const test_file_path = if (args.len > 1) 
        blk: {
            // User provided a path, check if it exists
            const path = try allocator.dupe(u8, args[1]);
            std.fs.cwd().access(path, .{}) catch {
                try stderr.print("Error: File not found: {s}\n", .{path});
                allocator.free(path);
                return FileError.FileNotFound;
            };
            break :blk path;
        }
    else 
        blk: {
            // Try to find test files
            const path = findTestFile(allocator) catch |err| {
                if (err == FileError.TestFilesNotFound) {
                    try stderr.print("Error: Could not find any test RTF files.\n", .{});
                    try stderr.print("Usage: {s} [path_to_rtf_file]\n", .{args[0]});
                    try stderr.print("If no path is provided, the program looks for test files in the test/data directory.\n", .{});
                }
                return err;
            };
            break :blk path;
        };
    
    defer allocator.free(test_file_path);
    
    // Print info
    const stdout = std.io.getStdOut().writer();
    try stdout.print("=== ZigRTF Parser Demo ===\n", .{});
    try stdout.print("Parsing file: {s}\n", .{test_file_path});
    
    // Get file size
    const file_info = try std.fs.cwd().statFile(test_file_path);
    const file_size = file_info.size;
    try stdout.print("File size: {} bytes\n", .{file_size});
    
    // Set a low threshold for memory mapping to trigger it for most files in our test
    const mmap_threshold = 100; // 100 byte threshold for testing
    const use_mmap = file_size >= mmap_threshold;
    try stdout.print("Expecting memory mapping: {} (threshold: {} bytes, file size: {} bytes)\n", 
        .{use_mmap, mmap_threshold, file_size});
    
    // Open the file with memory mapping if appropriate
    var stream = try ByteStream.openFile(test_file_path, allocator, mmap_threshold);
    defer stream.deinit();
    
    // Get information about the actual mapping that was used
    const actually_mapped = stream.isMemoryMapped();
    var map_type_str: []const u8 = "none";
    if (stream.getMemoryMapType()) |map_type| {
        map_type_str = if (map_type == .os_mmap) "OS-level memory mapping" 
                       else "File loaded into memory";
    } else {
        map_type_str = "Standard file I/O";
    }
    
    try stdout.print("Actual memory mapping: {} (type: {s})\n\n", .{actually_mapped, map_type_str});
    var tokenizer = Tokenizer.init(&stream, allocator);
    defer tokenizer.deinit();
    
    // Create event handler with our text callback
    const handler = EventHandler{
        .context = null, // Not using context in this example
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
    
    // DEMO: Test reader source with a file reader
    try stdout.print("\nTesting reader source with file reader...\n", .{});
    
    // Reset text buffer
    g_text.clearRetainingCapacity();
    
    // Open the same file again
    var file_for_reader = try std.fs.cwd().openFile(test_file_path, .{});
    defer file_for_reader.close();
    
    // Create stream with reader source
    var reader_stream = ByteStream.initReader(file_for_reader);
    var reader_tokenizer = Tokenizer.init(&reader_stream, allocator);
    defer reader_tokenizer.deinit();
    
    var reader_parser = try Parser.init(&reader_tokenizer, allocator, handler);
    defer reader_parser.deinit();
    
    // Parse using reader source
    try stdout.print("Parsing document with reader source...\n", .{});
    try reader_parser.parse();
    
    // Display the extracted content
    try stdout.print("\nExtracted content (reader source):\n", .{});
    try stdout.print("-------------------------\n", .{});
    try stdout.print("{s}\n", .{g_text.items});
    try stdout.print("-------------------------\n", .{});
    try stdout.print("\nReader parsing complete!\n", .{});
    
    // DEMO: Test document model and builders
    try stdout.print("\nTesting document model and builders...\n", .{});
    
    // Create a DocumentBuilder
    try stdout.print("Creating document with DocumentBuilder...\n", .{});
    
    // Open the file again for document building
    var file_for_document = try std.fs.cwd().openFile(test_file_path, .{});
    defer file_for_document.close();
    var document_stream = ByteStream.initFileStandard(file_for_document);
    var document_tokenizer = Tokenizer.init(&document_stream, allocator);
    defer document_tokenizer.deinit();
    
    var document_builder = try lib.DocumentBuilder.init(allocator);
    
    var document_parser = try Parser.init(&document_tokenizer, allocator, document_builder.handler());
    defer document_parser.deinit();
    
    try document_parser.parse();
    
    var document = document_builder.document orelse {
        try stderr.print("Error: DocumentBuilder failed to create a document\n", .{});
        return error.DocumentBuilderFailed;
    };
    
    // Since we're going to handle the document ourselves, detach it from the builder
    _ = document_builder.detachDocument();
    
    // Ensure proper cleanup order: destroy document first, then clean up builder
    defer {
        document.deinit();
        allocator.destroy(document);
        document_builder.deinit();
    }
    
    // Convert document to plain text
    var plain_text = std.ArrayList(u8).init(allocator);
    defer plain_text.deinit();
    
    try document.toPlainText(plain_text.writer());
    
    try stdout.print("\nDocument as plain text:\n", .{});
    try stdout.print("-------------------------\n", .{});
    try stdout.print("{s}\n", .{plain_text.items});
    try stdout.print("-------------------------\n", .{});
    
    // Convert document to HTML
    var html_output = std.ArrayList(u8).init(allocator);
    defer html_output.deinit();
    
    try document.toHtml(html_output.writer());
    
    try stdout.print("\nDocument as HTML (preview):\n", .{});
    try stdout.print("-------------------------\n", .{});
    
    // Only show the first 500 characters of HTML to avoid cluttering the output
    const html_preview_len = @min(html_output.items.len, 500);
    try stdout.print("{s}...\n", .{html_output.items[0..html_preview_len]});
    try stdout.print("-------------------------\n", .{});
    
    // DEMO: Test HTML converter
    try stdout.print("\nTesting direct HTML conversion...\n", .{});
    
    // Open the file again for HTML conversion
    var file_for_html = try std.fs.cwd().openFile(test_file_path, .{});
    defer file_for_html.close();
    var html_stream = ByteStream.initFileStandard(file_for_html);
    var html_tokenizer = Tokenizer.init(&html_stream, allocator);
    defer html_tokenizer.deinit();
    
    var html_result = std.ArrayList(u8).init(allocator);
    defer html_result.deinit();
    
    var html_converter = lib.HtmlConverter.init(allocator, html_result.writer());
    defer html_converter.deinit();
    
    try html_converter.beginDocument();
    
    var html_parser = try Parser.init(&html_tokenizer, allocator, html_converter.handler());
    defer html_parser.deinit();
    
    try html_parser.parse();
    
    try html_converter.endDocument();
    
    try stdout.print("\nHTML converter output (preview):\n", .{});
    try stdout.print("-------------------------\n", .{});
    
    // Only show the first 500 characters of HTML to avoid cluttering the output
    const converter_preview_len = @min(html_result.items.len, 500);
    try stdout.print("{s}...\n", .{html_result.items[0..converter_preview_len]});
    try stdout.print("-------------------------\n", .{});
    
    // Free the global text buffer
    g_text.deinit();
}

// Helper function to find one of our test RTF files
fn findTestFile(allocator: std.mem.Allocator) ![]const u8 {
    // Try each possible location for test files
    const possible_paths = [_][]const u8{
        // Current directory
        "test/data/large.rtf",
        "test/data/complex_formatting.rtf",
        "test/data/simple.rtf",
        
        // One directory up (if run from build directory)
        "../test/data/large.rtf",
        "../test/data/complex_formatting.rtf",
        "../test/data/simple.rtf",
        
        // Absolute paths for project structure (fallback)
        "/home/sam/zig-rtf/test/data/large.rtf",
        "/home/sam/zig-rtf/test/data/complex_formatting.rtf",
        "/home/sam/zig-rtf/test/data/simple.rtf",
    };
    
    // Try each possible path
    for (possible_paths) |path| {
        std.fs.cwd().access(path, .{}) catch {
            continue; // File not found, try next path
        };
        
        // File exists, return it
        return try allocator.dupe(u8, path);
    }
    
    // If we get here, none of the test files were found
    return FileError.TestFilesNotFound;
}
