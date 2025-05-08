const std = @import("std");
const ByteStream = @import("src/byte_stream.zig").ByteStream;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Test file
    const file_path = "test/data/large.rtf";
    
    // Output info about file
    const file = try std.fs.cwd().openFile(file_path, .{});
    const file_stat = try file.stat();
    file.close();
    
    std.debug.print("Testing file: {s}\nFile size: {d} bytes\n\n", .{
        file_path, file_stat.size
    });
    
    // Benchmark standard I/O
    const standard_time = try benchmarkStandardIO(allocator, file_path);
    
    // Benchmark memory mapping (with 1KB threshold to ensure it's used)
    const mmap_time = try benchmarkMemoryMapping(allocator, file_path, 1024);
    
    // Print results
    std.debug.print("\nPerformance comparison:\n", .{});
    std.debug.print("Standard I/O:   {d:.3} ms\n", .{@as(f64, @floatFromInt(standard_time)) / 1_000_000.0});
    std.debug.print("Memory Mapping: {d:.3} ms\n", .{@as(f64, @floatFromInt(mmap_time)) / 1_000_000.0});
    std.debug.print("Improvement:    {d:.2}%\n", .{
        (1.0 - @as(f64, @floatFromInt(mmap_time)) / @as(f64, @floatFromInt(standard_time))) * 100.0
    });
}

fn benchmarkStandardIO(_: std.mem.Allocator, file_path: []const u8) !u64 {
    const iterations = 10;
    var total_time: u64 = 0;
    
    std.debug.print("Running standard I/O benchmark ({d} iterations)...\n", .{iterations});
    
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var timer = try std.time.Timer.start();
        
        // Create ByteStream with standard I/O
        var stream = ByteStream.initFileStandard(try std.fs.cwd().openFile(file_path, .{}));
        defer stream.deinit();
        
        // Process the file
        var byte_count: usize = 0;
        while (try stream.consume()) |_| {
            byte_count += 1;
        }
        
        const elapsed = timer.lap();
        total_time += elapsed;
        
        std.debug.print("  Iteration {d}: {d:.3} ms ({d} bytes)\n", .{
            i + 1, @as(f64, @floatFromInt(elapsed)) / 1_000_000.0, byte_count
        });
    }
    
    const avg_time = total_time / iterations;
    std.debug.print("Average time: {d:.3} ms\n", .{@as(f64, @floatFromInt(avg_time)) / 1_000_000.0});
    
    return avg_time;
}

fn benchmarkMemoryMapping(allocator: std.mem.Allocator, file_path: []const u8, threshold: usize) !u64 {
    const iterations = 10;
    var total_time: u64 = 0;
    
    std.debug.print("\nRunning memory mapping benchmark ({d} iterations)...\n", .{iterations});
    
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var timer = try std.time.Timer.start();
        
        // Create ByteStream with memory mapping
        var stream = try ByteStream.openFile(file_path, allocator, threshold);
        defer stream.deinit();
        
        // Process the file
        var byte_count: usize = 0;
        while (try stream.consume()) |_| {
            byte_count += 1;
        }
        
        const elapsed = timer.lap();
        total_time += elapsed;
        
        // Print mapping type
        var mapping_type: []const u8 = "None";
        if (stream.isMemoryMapped()) {
            if (stream.getMemoryMapType()) |mtype| {
                mapping_type = switch (mtype) {
                    .os_mmap => "os_mmap",
                    .file_loaded => "file_loaded",
                };
            }
        }
        
        std.debug.print("  Iteration {d}: {d:.3} ms ({d} bytes) [Mapping: {s}]\n", .{
            i + 1, @as(f64, @floatFromInt(elapsed)) / 1_000_000.0, byte_count, mapping_type
        });
    }
    
    const avg_time = total_time / iterations;
    std.debug.print("Average time: {d:.3} ms\n", .{@as(f64, @floatFromInt(avg_time)) / 1_000_000.0});
    
    return avg_time;
}