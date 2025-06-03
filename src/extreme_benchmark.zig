const std = @import("std");
const formatted_parser = @import("formatted_parser.zig");
const LargeRtfGenerator = @import("large_rtf_generator.zig").LargeRtfGenerator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("🚀 === ZigRTF Extreme Performance Benchmark ===\n\n", .{});
    
    // Test with different file sizes - going ABSOLUTELY INSANE! 🚀
    const test_sizes = [_]u32{ 1024 }; // 1GB - let's see what happens!
    
    for (test_sizes) |size_mb| {
        try runBenchmark(allocator, size_mb);
        std.debug.print("\n============================================================\n\n", .{});
    }
    
    std.debug.print("🎯 Benchmark complete! Cleaning up generated files...\n", .{});
    
    // Clean up generated files to save disk space
    for (test_sizes) |size_mb| {
        const filename = try std.fmt.allocPrint(allocator, "test_{}_mb.rtf", .{size_mb});
        defer allocator.free(filename);
        std.fs.cwd().deleteFile(filename) catch |err| {
            std.debug.print("⚠️  Could not delete {s}: {}\n", .{filename, err});
        };
    }
}

fn runBenchmark(allocator: std.mem.Allocator, size_mb: u32) !void {
    std.debug.print("🎯 Benchmarking {}MB RTF file...\n\n", .{size_mb});
    
    // === GENERATION PHASE ===
    std.debug.print("📝 Phase 1: Generating complex RTF content...\n", .{});
    
    var generator = LargeRtfGenerator.init(allocator);
    defer generator.deinit();
    
    const gen_start = std.time.nanoTimestamp();
    const rtf_content = try generator.generate(size_mb);
    const gen_end = std.time.nanoTimestamp();
    
    const gen_time_ms = @as(f64, @floatFromInt(gen_end - gen_start)) / 1_000_000.0;
    const actual_size_mb = @as(f64, @floatFromInt(rtf_content.len)) / 1024.0 / 1024.0;
    
    std.debug.print("✅ Generated: {d:.2}MB in {d:.2}ms ({d:.1}MB/sec)\n\n", .{
        actual_size_mb,
        gen_time_ms,
        actual_size_mb / (gen_time_ms / 1000.0)
    });
    
    // Save to file for inspection
    const filename = try std.fmt.allocPrint(allocator, "test_{}_mb.rtf", .{size_mb});
    defer allocator.free(filename);
    
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(rtf_content);
    
    std.debug.print("💾 Saved as: {s}\n\n", .{filename});
    
    // === PARSING PHASE ===
    std.debug.print("⚡ Phase 2: Parsing RTF with memory tracking...\n", .{});
    
    var stream = std.io.fixedBufferStream(rtf_content);
    
    const parse_start = std.time.nanoTimestamp();
    
    var parser = try formatted_parser.FormattedParser.init(stream.reader().any(), allocator);
    defer parser.deinit();
    
    var document = try parser.parse();
    defer document.deinit();
    
    const parse_end = std.time.nanoTimestamp();
    const parse_time_ms = @as(f64, @floatFromInt(parse_end - parse_start)) / 1_000_000.0;
    
    // === ANALYSIS PHASE ===
    std.debug.print("📊 Phase 3: Analyzing parsed document...\n", .{});
    
    const analysis_start = std.time.nanoTimestamp();
    
    const text = try document.getPlainText();
    const runs = try document.getTextRuns(allocator);
    defer allocator.free(runs);
    
    const analysis_end = std.time.nanoTimestamp();
    const analysis_time_ms = @as(f64, @floatFromInt(analysis_end - analysis_start)) / 1_000_000.0;
    
    // === MEMORY ESTIMATION ===
    const raw_file_memory = rtf_content.len;
    const extracted_text_memory = text.len;
    const runs_memory = runs.len * @sizeOf(@TypeOf(runs[0]));
    const font_memory = document.font_table.items.len * 100; // Estimated
    const color_memory = document.color_table.items.len * 16; // Estimated  
    const parser_memory = 1024 * 1024; // Estimated 1MB for parser structures
    const total_memory = raw_file_memory + extracted_text_memory + runs_memory + 
                        font_memory + color_memory + parser_memory;
    
    // === RESULTS ===
    std.debug.print("\n🎯 === BENCHMARK RESULTS ===\n", .{});
    
    std.debug.print("\n📄 File Statistics:\n", .{});
    std.debug.print("  Size: {d:.2} MB ({} bytes)\n", .{actual_size_mb, rtf_content.len});
    std.debug.print("  Generation time: {d:.2} ms\n", .{gen_time_ms});
    std.debug.print("  Generation rate: {d:.1} MB/sec\n", .{actual_size_mb / (gen_time_ms / 1000.0)});
    
    std.debug.print("\n⚡ Parse Performance:\n", .{});
    std.debug.print("  Parse time: {d:.2} ms\n", .{parse_time_ms});
    std.debug.print("  Parse rate: {d:.1} MB/sec\n", .{actual_size_mb / (parse_time_ms / 1000.0)});
    std.debug.print("  Analysis time: {d:.2} ms\n", .{analysis_time_ms});
    std.debug.print("  Total processing: {d:.2} ms\n", .{parse_time_ms + analysis_time_ms});
    
    std.debug.print("\n📊 Document Content:\n", .{});
    std.debug.print("  Extracted text: {} chars ({d:.2} MB)\n", .{
        text.len,
        @as(f64, @floatFromInt(text.len)) / 1024.0 / 1024.0
    });
    std.debug.print("  Text runs: {}\n", .{runs.len});
    std.debug.print("  Font table entries: {}\n", .{document.font_table.items.len});
    std.debug.print("  Color table entries: {}\n", .{document.color_table.items.len});
    std.debug.print("  Content elements: {}\n", .{document.content.items.len});
    
    std.debug.print("\n💾 Memory Usage (Estimated):\n", .{});
    std.debug.print("  Raw file: {d:.2} MB\n", .{@as(f64, @floatFromInt(raw_file_memory)) / 1024.0 / 1024.0});
    std.debug.print("  Extracted text: {d:.2} MB\n", .{@as(f64, @floatFromInt(extracted_text_memory)) / 1024.0 / 1024.0});
    std.debug.print("  Text runs: {d:.2} MB\n", .{@as(f64, @floatFromInt(runs_memory)) / 1024.0 / 1024.0});
    std.debug.print("  Font table: {d:.2} MB\n", .{@as(f64, @floatFromInt(font_memory)) / 1024.0 / 1024.0});
    std.debug.print("  Color table: {d:.2} MB\n", .{@as(f64, @floatFromInt(color_memory)) / 1024.0 / 1024.0});
    std.debug.print("  Parser overhead: {d:.2} MB\n", .{@as(f64, @floatFromInt(parser_memory)) / 1024.0 / 1024.0});
    std.debug.print("  ────────────────────────\n", .{});
    std.debug.print("  Total memory: {d:.2} MB\n", .{@as(f64, @floatFromInt(total_memory)) / 1024.0 / 1024.0});
    
    std.debug.print("\n⚡ Efficiency Metrics:\n", .{});
    const memory_overhead = @as(f64, @floatFromInt(total_memory)) / @as(f64, @floatFromInt(raw_file_memory));
    const text_extraction_ratio = @as(f64, @floatFromInt(text.len)) / @as(f64, @floatFromInt(rtf_content.len)) * 100.0;
    
    std.debug.print("  Memory overhead: {d:.1}x file size\n", .{memory_overhead});
    std.debug.print("  Text extraction: {d:.1}% of file size\n", .{text_extraction_ratio});
    std.debug.print("  Parse efficiency: {d:.1} MB/sec\n", .{actual_size_mb / (parse_time_ms / 1000.0)});
    
    // Performance classification
    if (parse_time_ms < 100) {
        std.debug.print("  🚀 Performance: EXCELLENT\n", .{});
    } else if (parse_time_ms < 500) {
        std.debug.print("  ✅ Performance: GOOD\n", .{});
    } else if (parse_time_ms < 1000) {
        std.debug.print("  ⚠️  Performance: ACCEPTABLE\n", .{});
    } else {
        std.debug.print("  ❌ Performance: NEEDS OPTIMIZATION\n", .{});
    }
    
    // Show a preview of extracted text
    const preview_len = @min(200, text.len);
    std.debug.print("\n📖 Text Preview:\n", .{});
    std.debug.print("'{s}...'\n", .{text[0..preview_len]});
}