const std = @import("std");
const formatted_parser = @import("formatted_parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("🚀 Quick Large RTF Test\n\n", .{});
    
    // Generate a moderately large RTF (5MB) manually
    var rtf_content = std.ArrayList(u8).init(allocator);
    defer rtf_content.deinit();
    
    const writer = rtf_content.writer();
    
    std.debug.print("📝 Generating complex RTF content...\n", .{});
    
    // RTF header
    try writer.writeAll("{\\rtf1\\ansi\\deff0");
    
    // Font table with 20 fonts
    try writer.writeAll("{\\fonttbl");
    for (0..20) |i| {
        try writer.print("{{\\f{}\\fswiss Arial {};}}", .{i, i});
    }
    try writer.writeAll("}");
    
    // Color table with 50 colors
    try writer.writeAll("{\\colortbl;");
    for (0..50) |i| {
        const red = (i * 5) % 256;
        const green = (i * 7) % 256;
        const blue = (i * 11) % 256;
        try writer.print("\\red{}\\green{}\\blue{};", .{red, green, blue});
    }
    try writer.writeAll("}");
    
    // Generate content until we reach ~5MB
    const target_size = 5 * 1024 * 1024; // 5MB
    var content_section = 0;
    
    while (rtf_content.items.len < target_size) {
        content_section += 1;
        
        // Add a section with formatting, tables, and images
        try writer.print("\\par\\par{{\\fs32\\b Section {} - Complex Content}}\\par\\par", .{content_section});
        
        // Add formatted paragraphs
        for (0..10) |para| {
            const font_id = para % 20;
            const color_id = (para * 3) % 50 + 1;
            
            try writer.print("{{\\f{}\\cf{}\\fs24", .{font_id, color_id});
            if (para % 2 == 0) try writer.writeAll("\\b");
            if (para % 3 == 0) try writer.writeAll("\\i");
            
            try writer.print(" Paragraph {} with various formatting. ", .{para + 1});
            try writer.writeAll("Lorem ipsum dolor sit amet, consectetur adipiscing elit. ");
            try writer.writeAll("Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ");
            try writer.writeAll("Ut enim ad minim veniam, quis nostrud exercitation ullamco. ");
            try writer.writeAll("}\\par");
        }
        
        // Add a table every few sections
        if (content_section % 3 == 0) {
            try writer.writeAll("\\par\\par{{\\fs28\\b Data Table}}\\par\\par");
            
            for (0..5) |row| {
                try writer.writeAll("\\trowd");
                for (0..4) |col| {
                    const pos = (col + 1) * 1800;
                    try writer.print("\\cellx{}", .{pos});
                }
                
                for (0..4) |col| {
                    const color_id = ((row * 4 + col) % 50) + 1;
                    try writer.print("{{\\cf{} Cell R{}C{} }}", .{color_id, row + 1, col + 1});
                    try writer.writeAll("\\cell");
                }
                try writer.writeAll("\\row");
            }
        }
        
        // Add fake images 
        if (content_section % 5 == 0) {
            try writer.writeAll("\\par\\par{{\\fs24\\b Image Section}}\\par\\par");
            
            for (0..3) |img| {
                try writer.print("Image {} - ", .{img + 1});
                try writer.writeAll("{\\pict\\pngblip\\picw150\\pich100 ");
                
                // Generate 256 bytes of hex data (simulates small image)
                for (0..128) |_| {
                    const byte = @as(u8, @intCast((content_section * 17 + img * 23) % 256));
                    try writer.print("{x:0>2}", .{byte});
                }
                try writer.writeAll("}\\par");
            }
        }
        
        if (content_section % 50 == 0) {
            const current_mb = @as(f64, @floatFromInt(rtf_content.items.len)) / 1024.0 / 1024.0;
            std.debug.print("Generated: {d:.1}MB (section {})...\n", .{current_mb, content_section});
        }
    }
    
    // Close RTF
    try writer.writeAll("}");
    
    const final_size_mb = @as(f64, @floatFromInt(rtf_content.items.len)) / 1024.0 / 1024.0;
    std.debug.print("✅ Generated: {d:.2}MB RTF with {} sections\n\n", .{final_size_mb, content_section});
    
    // Save to file
    const file = try std.fs.cwd().createFile("large_test.rtf", .{});
    defer file.close();
    try file.writeAll(rtf_content.items);
    std.debug.print("💾 Saved as: large_test.rtf\n\n", .{});
    
    // Parse and benchmark
    std.debug.print("⚡ Parsing the generated RTF...\n", .{});
    
    var stream = std.io.fixedBufferStream(rtf_content.items);
    
    const parse_start = std.time.nanoTimestamp();
    
    var parser = try formatted_parser.FormattedParser.init(stream.reader().any(), allocator);
    defer parser.deinit();
    
    var document = try parser.parse();
    defer document.deinit();
    
    const parse_end = std.time.nanoTimestamp();
    const parse_time_ms = @as(f64, @floatFromInt(parse_end - parse_start)) / 1_000_000.0;
    
    // Analyze results
    const text = try document.getPlainText();
    const runs = try document.getTextRuns(allocator);
    defer allocator.free(runs);
    
    std.debug.print("\n🎯 === RESULTS ===\n", .{});
    std.debug.print("📄 File size: {d:.2} MB\n", .{final_size_mb});
    std.debug.print("⏱️  Parse time: {d:.2} ms\n", .{parse_time_ms});
    std.debug.print("🚀 Parse rate: {d:.1} MB/sec\n", .{final_size_mb / (parse_time_ms / 1000.0)});
    std.debug.print("📝 Extracted text: {} chars ({d:.2} MB)\n", .{
        text.len,
        @as(f64, @floatFromInt(text.len)) / 1024.0 / 1024.0
    });
    std.debug.print("🎨 Text runs: {}\n", .{runs.len});
    std.debug.print("🔤 Fonts: {}\n", .{document.font_table.items.len});
    std.debug.print("🌈 Colors: {}\n", .{document.color_table.items.len});
    std.debug.print("📄 Elements: {}\n", .{document.content.items.len});
    
    // Memory estimates
    const file_memory = rtf_content.items.len;
    const text_memory = text.len;
    const runs_memory = runs.len * 64; // Estimate per run
    const parser_memory = 2 * 1024 * 1024; // 2MB estimate
    const total_memory = file_memory + text_memory + runs_memory + parser_memory;
    
    std.debug.print("\n💾 Memory Usage (Estimated):\n", .{});
    std.debug.print("  Raw file: {d:.2} MB\n", .{@as(f64, @floatFromInt(file_memory)) / 1024.0 / 1024.0});
    std.debug.print("  Parsed data: {d:.2} MB\n", .{@as(f64, @floatFromInt(text_memory + runs_memory)) / 1024.0 / 1024.0});
    std.debug.print("  Parser overhead: {d:.2} MB\n", .{@as(f64, @floatFromInt(parser_memory)) / 1024.0 / 1024.0});
    std.debug.print("  Total: {d:.2} MB\n", .{@as(f64, @floatFromInt(total_memory)) / 1024.0 / 1024.0});
    
    const memory_ratio = @as(f64, @floatFromInt(total_memory)) / @as(f64, @floatFromInt(file_memory));
    std.debug.print("  Overhead: {d:.1}x file size\n", .{memory_ratio});
    
    // Show sample text
    const preview_len = @min(150, text.len);
    std.debug.print("\n📖 Sample text:\n'{s}...'\n", .{text[0..preview_len]});
    
    std.debug.print("\n✅ Test complete!\n", .{});
}