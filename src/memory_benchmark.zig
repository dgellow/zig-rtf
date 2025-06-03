const std = @import("std");
const formatted_parser = @import("formatted_parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("=== ZigRTF Memory Usage Analysis ===\n\n", .{});
    
    // Read the large file
    const file = std.fs.cwd().openFile("test/data/large.rtf", .{}) catch |err| {
        std.debug.print("Could not open large.rtf: {}\n", .{err});
        return;
    };
    defer file.close();
    
    const file_size = try file.getEndPos();
    std.debug.print("📄 File size: {d:.2} MB ({} bytes)\n", .{
        @as(f64, @floatFromInt(file_size)) / 1024.0 / 1024.0,
        file_size
    });
    
    // Read file into memory
    const content = try file.readToEndAlloc(allocator, 10_000_000);
    defer allocator.free(content);
    
    std.debug.print("💾 Raw file in memory: {d:.2} MB\n", .{
        @as(f64, @floatFromInt(content.len)) / 1024.0 / 1024.0
    });
    
    // Parse the RTF with timing
    var stream = std.io.fixedBufferStream(content);
    const start_time = std.time.nanoTimestamp();
    
    var parser = try formatted_parser.FormattedParser.init(stream.reader().any(), allocator);
    defer parser.deinit();
    
    var document = try parser.parse();
    defer document.deinit();
    
    const end_time = std.time.nanoTimestamp();
    const parse_time_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    
    // Analyze the parsed document
    const text = try document.getPlainText();
    const runs = try document.getTextRuns(allocator);
    defer allocator.free(runs);
    
    std.debug.print("\n📊 Parse Results:\n", .{});
    std.debug.print("  ⏱️  Parse time: {d:.2} ms\n", .{parse_time_ms});
    std.debug.print("  📝 Extracted text: {} chars ({d:.2} MB)\n", .{
        text.len,
        @as(f64, @floatFromInt(text.len)) / 1024.0 / 1024.0
    });
    std.debug.print("  🎨 Text runs: {}\n", .{runs.len});
    std.debug.print("  🔤 Font table entries: {}\n", .{document.font_table.items.len});
    std.debug.print("  🌈 Color table entries: {}\n", .{document.color_table.items.len});
    std.debug.print("  📄 Total content elements: {}\n", .{document.content.items.len});
    
    // Estimate memory usage
    const text_overhead = text.len;
    const runs_overhead = runs.len * @sizeOf(@TypeOf(runs[0]));
    const font_overhead = document.font_table.items.len * 100; // Average font name + metadata
    const color_overhead = document.color_table.items.len * 16; // Color info
    const structure_overhead = 1024 * 512; // Parser, ArrayLists, etc.
    
    const total_estimated_memory = content.len + text_overhead + runs_overhead + 
                                 font_overhead + color_overhead + structure_overhead;
    
    std.debug.print("\n🧮 Memory Usage Estimates:\n", .{});
    std.debug.print("  📄 Raw file data: {d:.2} MB\n", .{@as(f64, @floatFromInt(content.len)) / 1024.0 / 1024.0});
    std.debug.print("  📝 Extracted text: {d:.2} MB\n", .{@as(f64, @floatFromInt(text_overhead)) / 1024.0 / 1024.0});
    std.debug.print("  🎨 Text runs: {d:.2} MB\n", .{@as(f64, @floatFromInt(runs_overhead)) / 1024.0 / 1024.0});
    std.debug.print("  🔤 Font table: {d:.2} MB\n", .{@as(f64, @floatFromInt(font_overhead)) / 1024.0 / 1024.0});
    std.debug.print("  🌈 Color table: {d:.2} MB\n", .{@as(f64, @floatFromInt(color_overhead)) / 1024.0 / 1024.0});
    std.debug.print("  🏗️  Parser structures: {d:.2} MB\n", .{@as(f64, @floatFromInt(structure_overhead)) / 1024.0 / 1024.0});
    std.debug.print("  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("  📊 Total estimated: {d:.2} MB\n", .{@as(f64, @floatFromInt(total_estimated_memory)) / 1024.0 / 1024.0});
    
    // Efficiency metrics
    const memory_overhead_ratio = @as(f64, @floatFromInt(total_estimated_memory)) / @as(f64, @floatFromInt(file_size));
    const processing_rate = @as(f64, @floatFromInt(file_size)) / 1024.0 / 1024.0 / (parse_time_ms / 1000.0);
    
    std.debug.print("\n⚡ Performance Metrics:\n", .{});
    std.debug.print("  📈 Memory overhead: {d:.1}x file size\n", .{memory_overhead_ratio});
    std.debug.print("  🚀 Processing rate: {d:.1} MB/sec\n", .{processing_rate});
    std.debug.print("  💡 Text extraction ratio: {d:.1}% of file size\n", .{
        @as(f64, @floatFromInt(text.len)) / @as(f64, @floatFromInt(file_size)) * 100.0
    });
    
    // Show first few characters of extracted text
    const preview_len = @min(100, text.len);
    std.debug.print("\n📖 Text preview ({} chars):\n", .{preview_len});
    std.debug.print("'{s}...'\n", .{text[0..preview_len]});
    
    std.debug.print("\n✅ Analysis complete!\n", .{});
}