const std = @import("std");
const lib = @import("zig_rtf_lib");
const time = std.time;
const fs = std.fs;
const testing = std.testing;

// Import components from the library
const ByteStream = lib.ByteStream;
const Tokenizer = lib.Tokenizer;
const Parser = lib.Parser;
const EventHandler = lib.EventHandler;

/// Basic benchmark configuration
pub const BenchmarkConfig = struct {
    name: []const u8,
    file_path: []const u8,
    iterations: usize = 10,
    warmup_iterations: usize = 2,
    use_mmap: bool = false, // Whether to use memory mapping
};

/// Determine how many iterations to run based on file size
fn getIterationCount(file_size: usize) usize {
    if (file_size < 1024) {
        return 3000; // Very small files need many iterations for accurate timing
    } else if (file_size < 10 * 1024) {
        return 1000; // Small files
    } else if (file_size < 100 * 1024) {
        return 100; // Medium files
    } else {
        return 10; // Large files
    }
}

/// Benchmark result
pub const BenchmarkResult = struct {
    name: []const u8,
    file_size: usize,
    total_time_ns: u64,
    iterations: usize,
    avg_time_ns: u64,
    throughput_mbps: f64,
    
    // Keep track of peak memory usage
    peak_memory_bytes: usize = 0,
    memory_ratio: f64 = 0.0,
    
    pub fn format(
        self: BenchmarkResult,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        
        // Convert file size to appropriate unit
        const file_size_kb = @as(f64, @floatFromInt(self.file_size)) / 1024.0;
        
        // Convert nanoseconds to appropriate time unit
        var time_value: f64 = 0;
        var time_unit: []const u8 = "";
        
        const time_ns = @as(f64, @floatFromInt(self.avg_time_ns));
        if (time_ns < 1_000.0) {
            time_value = time_ns;
            time_unit = "ns";
        } else if (time_ns < 1_000_000.0) {
            time_value = time_ns / 1_000.0;
            time_unit = "μs";
        } else {
            time_value = time_ns / 1_000_000.0;
            time_unit = "ms";
        }
        
        // Direct printing without allocations
        try writer.print("{s:<20} | Size: {d:.2} KB | Iterations: {d} | Avg: {d:.3} {s} | Throughput: {d:.2} MB/s", 
            .{
                self.name,
                file_size_kb,
                self.iterations,
                time_value,
                time_unit,
                self.throughput_mbps,
            }
        );
        
        // If we have memory usage info, include it
        if (self.peak_memory_bytes > 0) {
            try writer.print(" | Memory: {d:.2} KB (ratio: {d:.1}x)",
                .{
                    @as(f64, @floatFromInt(self.peak_memory_bytes)) / 1024.0,
                    self.memory_ratio,
                }
            );
        }
    }
};

/// Silent event handler that doesn't produce any output
const SilentEventHandler = struct {
    allocator: std.mem.Allocator,
    
    // Counter to verify parsing is working
    text_count: usize = 0,
    group_start_count: usize = 0,
    group_end_count: usize = 0,
    
    fn onText(self_ctx: *anyopaque, text: []const u8, style: lib.Style) !void {
        _ = style;
        _ = text;
        
        // We don't want to allocate/append and generate output
        // Just verify we're getting callbacks to ensure real work is done
        var self = @as(*SilentEventHandler, @ptrCast(@alignCast(self_ctx)));
        self.text_count += 1;
    }
    
    fn onGroupStart(self_ctx: *anyopaque) !void {
        var self = @as(*SilentEventHandler, @ptrCast(@alignCast(self_ctx)));
        self.group_start_count += 1;
    }
    
    fn onGroupEnd(self_ctx: *anyopaque) !void {
        var self = @as(*SilentEventHandler, @ptrCast(@alignCast(self_ctx)));
        self.group_end_count += 1;
    }
    
    pub fn handler(self: *SilentEventHandler) EventHandler {
        return .{
            .context = self,
            .onGroupStart = onGroupStart,
            .onGroupEnd = onGroupEnd,
            .onText = onText,
            .onCharacter = null,
            .onError = null,
        };
    }
};

/// Run a single benchmark with the given configuration
pub fn runBenchmark(allocator: std.mem.Allocator, config: BenchmarkConfig) !BenchmarkResult {
    // Get file size for reporting
    const file_info = try fs.cwd().statFile(config.file_path);
    const file_size = file_info.size;
    
    // Calculate how many iterations to use - more for smaller files
    const actual_iterations = getIterationCount(@intCast(file_size));
    
    // Create counters to verify work is being done
    var total_text_count: usize = 0;
    var total_group_start_count: usize = 0;
    var total_group_end_count: usize = 0;
    
    // Timing variables
    var total_time: u64 = 0;
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    
    // Track whether true OS memory mapping was used
    var used_os_mmap = false;
    var used_file_load = false;
    var used_standard_io = false;
    
    // Setup for test depending on mode
    if (config.use_mmap) {
        // Memory-mapped mode
        
        // Do warmup runs first (not timed)
        for (0..3) |_| {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();
            
            // Open the file with memory mapping
            const file = try fs.cwd().openFile(config.file_path, .{});
            var stream = try ByteStream.initFile(file, arena_allocator, 0); // 0 threshold forces memory mapping
            defer stream.deinit();
            
            // Check what type of memory mapping was used
            if (stream.getMemoryMapType()) |map_type| {
                if (map_type == .os_mmap) {
                    used_os_mmap = true;
                } else if (map_type == .file_loaded) {
                    used_file_load = true;
                }
            } else {
                used_standard_io = true;
            }
            
            // Create a handler that counts parsing events
            var handler = SilentEventHandler{ .allocator = arena_allocator };
            
            // Set up the parser pipeline
            var tokenizer = Tokenizer.init(&stream, arena_allocator);
            var parser = try Parser.init(&tokenizer, arena_allocator, handler.handler());
            
            // Parse (not timed)
            try parser.parse();
        }
        
        // Now do the timed runs using memory mapping
        for (0..actual_iterations) |_| {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();
            
            // Open the file with memory mapping
            const file = try fs.cwd().openFile(config.file_path, .{});
            var stream = try ByteStream.initFile(file, arena_allocator, 0); // 0 threshold forces memory mapping
            defer stream.deinit();
            
            // Create a handler that counts parsing events
            var handler = SilentEventHandler{ .allocator = arena_allocator };
            
            // Set up the parser pipeline
            var tokenizer = Tokenizer.init(&stream, arena_allocator);
            var parser = try Parser.init(&tokenizer, arena_allocator, handler.handler());
            
            // Measure just the parse operation
            const start = time.nanoTimestamp();
            try parser.parse();
            const end = time.nanoTimestamp();
            
            // Record timing
            const elapsed = @as(u64, @intCast(end - start));
            total_time += elapsed;
            min_time = @min(min_time, elapsed);
            max_time = @max(max_time, elapsed);
            
            // Accumulate event counts to verify parsing worked
            total_text_count += handler.text_count;
            total_group_start_count += handler.group_start_count;
            total_group_end_count += handler.group_end_count;
        }
    } else {
        // Standard I/O mode - use traditional file I/O
        
        // Do warmup runs first (not timed)
        for (0..3) |_| {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();
            
            // Open the file with standard I/O
            const file = try fs.cwd().openFile(config.file_path, .{});
            var stream = ByteStream.initFileStandard(file);
            used_standard_io = true;
            
            // Create a handler that counts parsing events
            var handler = SilentEventHandler{ .allocator = arena_allocator };
            
            // Set up the parser pipeline
            var tokenizer = Tokenizer.init(&stream, arena_allocator);
            var parser = try Parser.init(&tokenizer, arena_allocator, handler.handler());
            
            // Parse (not timed)
            try parser.parse();
        }
        
        // Now do the timed runs using standard I/O
        for (0..actual_iterations) |_| {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();
            
            // Open the file with standard I/O
            const file = try fs.cwd().openFile(config.file_path, .{});
            var stream = ByteStream.initFileStandard(file);
            
            // Create a handler that counts parsing events
            var handler = SilentEventHandler{ .allocator = arena_allocator };
            
            // Set up the parser pipeline
            var tokenizer = Tokenizer.init(&stream, arena_allocator);
            var parser = try Parser.init(&tokenizer, arena_allocator, handler.handler());
            
            // Measure just the parse operation
            const start = time.nanoTimestamp();
            try parser.parse();
            const end = time.nanoTimestamp();
            
            // Record timing
            const elapsed = @as(u64, @intCast(end - start));
            total_time += elapsed;
            min_time = @min(min_time, elapsed);
            max_time = @max(max_time, elapsed);
            
            // Accumulate event counts to verify parsing worked
            total_text_count += handler.text_count;
            total_group_start_count += handler.group_start_count;
            total_group_end_count += handler.group_end_count;
        }
    }
    
    // Verify that parsing produced something
    if (total_text_count == 0 or total_group_start_count == 0 or total_group_end_count == 0) {
        return error.ParseDidNothing;
    }
    
    // Calculate results - use average time for consistency
    const avg_time = total_time / actual_iterations;
    
    // Calculate throughput in MB/s (bytes per nanosecond * 10^9 / 10^6)
    const throughput = @as(f64, @floatFromInt(file_size)) / 
                        @as(f64, @floatFromInt(avg_time)) * 1000.0;
    
    // For future implementation: track peak memory usage
    // We'll leave these at 0 for now, but the infrastructure is in place for later
    const peak_memory = 0; // In a future implementation, we would measure this
    const memory_ratio = if (peak_memory > 0 and file_size > 0) 
        @as(f64, @floatFromInt(peak_memory)) / @as(f64, @floatFromInt(file_size))
        else 0.0;
    
    // Create a name with memory mapping mode appended
    var name_buffer: [100]u8 = undefined; // Fixed buffer for name - should be large enough
    var benchmark_name: []const u8 = config.name;
    
    if (config.use_mmap) {
        var name_with_suffix: []const u8 = undefined;
        if (used_os_mmap) {
            name_with_suffix = " (OS mmap)";
        } else if (used_file_load) {
            name_with_suffix = " (File Load)";
        } else {
            name_with_suffix = " (Memory Mapped)";
        }
        
        // Format into the fixed buffer
        benchmark_name = std.fmt.bufPrint(&name_buffer, "{s}{s}", .{config.name, name_with_suffix}) catch config.name;
    }
    
    return BenchmarkResult{
        .name = benchmark_name,
        .file_size = @intCast(file_size),
        .total_time_ns = total_time,
        .iterations = actual_iterations,
        .avg_time_ns = avg_time,
        .throughput_mbps = throughput,
        .peak_memory_bytes = peak_memory,
        .memory_ratio = memory_ratio,
    };
}

/// Run multiple benchmarks and print results
pub fn runBenchmarks(allocator: std.mem.Allocator, configs: []const BenchmarkConfig, build_mode: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("\n--- ZigRTF Benchmark Results ({s} Build) ---\n\n", .{build_mode});
    
    for (configs) |config| {
        const result = try runBenchmark(allocator, config);
        
        // Instead of printing the object, generate output the same way BenchmarkResult.format does
        var time_value: f64 = 0;
        var time_unit: []const u8 = "";
        
        const time_ns = @as(f64, @floatFromInt(result.avg_time_ns));
        if (time_ns < 1_000.0) {
            time_value = time_ns;
            time_unit = "ns";
        } else if (time_ns < 1_000_000.0) {
            time_value = time_ns / 1_000.0;
            time_unit = "μs";
        } else {
            time_value = time_ns / 1_000_000.0;
            time_unit = "ms";
        }
        
        try stdout.print("{s:<20} | Size: {d:.2} KB | Iterations: {d} | Avg: {d:.3} {s} | Throughput: {d:.2} MB/s\n", 
        .{
            result.name,
            @as(f64, @floatFromInt(result.file_size)) / 1024.0,
            result.iterations,
            time_value,
            time_unit,
            result.throughput_mbps,
        });
    }
    
    try stdout.print("\n", .{});
}

/// Main function
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Get build mode from args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    // Use the first command line arg as build mode, or "Debug" if not provided
    const build_mode = if (args.len > 1) args[1] else "Debug";
    
    // Define benchmark configurations
    const configs = [_]BenchmarkConfig{
        // Standard I/O benchmarks
        .{
            .name = "Simple RTF",
            .file_path = "/home/sam/zig-rtf/test/data/simple.rtf",
        },
        .{
            .name = "Nested RTF",
            .file_path = "/home/sam/zig-rtf/test/data/nested.rtf",
        },
        .{
            .name = "Complex RTF",
            .file_path = "/home/sam/zig-rtf/test/data/complex.rtf",
        },
        .{
            .name = "Complex Formatting RTF",
            .file_path = "/home/sam/zig-rtf/test/data/complex_formatting.rtf",
        },
        .{
            .name = "Large RTF",
            .file_path = "/home/sam/zig-rtf/test/data/large.rtf",
        },
        .{
            .name = "Very Large RTF",
            .file_path = "/home/sam/zig-rtf/test/data/large.rtf", // Use large.rtf as a fallback
        },
        .{
            .name = "Malformed RTF",
            .file_path = "/home/sam/zig-rtf/test/data/malformed.rtf",
        },
        
        // Memory-mapped versions for comparison
        .{
            .name = "Simple RTF",
            .file_path = "/home/sam/zig-rtf/test/data/simple.rtf",
            .use_mmap = true,
        },
        .{
            .name = "Complex RTF",
            .file_path = "/home/sam/zig-rtf/test/data/complex.rtf",
            .use_mmap = true,
        },
        .{
            .name = "Large RTF",
            .file_path = "/home/sam/zig-rtf/test/data/large.rtf",
            .use_mmap = true,
        },
        .{
            .name = "Very Large RTF",
            .file_path = "/home/sam/zig-rtf/large_file.rtf",
            .use_mmap = true,
        },
    };
    
    try runBenchmarks(allocator, &configs, build_mode);
}

test "basic benchmark run" {
    const config = BenchmarkConfig{
        .name = "Test Benchmark",
        .file_path = "/home/sam/zig-rtf/test/data/simple.rtf",
        .iterations = 5,
        .warmup_iterations = 1,
    };
    
    const result = try runBenchmark(testing.allocator, config);
    
    // Basic validation
    try testing.expect(result.file_size > 0);
    try testing.expect(result.avg_time_ns > 0);
    try testing.expect(result.throughput_mbps > 0);
    
    // Test runBenchmarks as well
    const configs = [_]BenchmarkConfig{config};
    try runBenchmarks(testing.allocator, &configs, "Test");
}