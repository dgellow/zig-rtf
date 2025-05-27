const std = @import("std");
const rtf = @import("rtf");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len != 2) {
        std.debug.print("ZigRTF Reader Demo\n", .{});
        std.debug.print("Usage: {s} <rtf_file>\n", .{args[0]});
        std.debug.print("\nExample RTF files in test/data/:\n", .{});
        std.debug.print("  - simple.rtf\n", .{});
        std.debug.print("  - wordpad_sample.rtf\n", .{});
        std.debug.print("  - complex_mixed.rtf\n", .{});
        return;
    }
    
    const filename = args[1];
    
    // Read RTF file
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        std.debug.print("Error: Could not open file '{s}': {}\n", .{ filename, err });
        return;
    };
    defer file.close();
    
    const content = file.readToEndAlloc(allocator, 1_000_000) catch |err| {
        std.debug.print("Error: Could not read file '{s}': {}\n", .{ filename, err });
        return;
    };
    defer allocator.free(content);
    
    // Parse RTF
    var stream = std.io.fixedBufferStream(content);
    var parser = rtf.Parser.init(stream.reader().any(), allocator);
    defer parser.deinit();
    
    const start_time = std.time.nanoTimestamp();
    
    parser.parse() catch |err| {
        std.debug.print("Error: Failed to parse RTF: {}\n", .{err});
        return;
    };
    
    const end_time = std.time.nanoTimestamp();
    const parse_time_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    
    const text = parser.getText();
    
    // Display results
    printHeader();
    std.debug.print("File: {s}\n", .{filename});
    std.debug.print("RTF Size: {} bytes\n", .{content.len});
    std.debug.print("Text Length: {} characters\n", .{text.len});
    std.debug.print("Parse Time: {d:.2} ms\n", .{parse_time_ms});
    printSeparator();
    
    std.debug.print("Extracted Text:\n", .{});
    printSeparator();
    
    if (text.len == 0) {
        std.debug.print("(No text content found)\n", .{});
    } else {
        // Print text with line numbers for better readability
        var line_num: u32 = 1;
        var line_start: usize = 0;
        
        for (text, 0..) |char, i| {
            if (char == '\n' or i == text.len - 1) {
                const line_end = if (char == '\n') i else i + 1;
                const line = text[line_start..line_end];
                
                // Clean up the line (remove excessive whitespace)
                const cleaned_line = std.mem.trim(u8, line, " \t\r\n");
                
                if (cleaned_line.len > 0) {
                    std.debug.print("{:3}: {s}\n", .{ line_num, cleaned_line });
                    line_num += 1;
                }
                
                line_start = i + 1;
            }
        }
    }
    
    printSeparator();
    std.debug.print("✓ Successfully parsed RTF document!\n", .{});
    std.debug.print("  Powered by ZigRTF - The Ultimate RTF Library\n", .{});
}

fn printHeader() void {
    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                            ZigRTF Reader Demo                             ║\n", .{});
    std.debug.print("║                     The Ultimate RTF Parsing Library                     ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
}

fn printSeparator() void {
    std.debug.print("────────────────────────────────────────────────────────────────────────────\n", .{});
}