const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const byte_stream = @import("byte_stream.zig");
const ByteStream = @import("byte_stream.zig").ByteStream;
const Position = @import("byte_stream.zig").Position;
const MemoryMapType = @import("byte_stream.zig").MemoryMapType;

test "Memory mapping correctly loads file contents" {
    // Create a temporary directory for our test files
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create a test file with known content
    const test_content = "This is test content for memory mapping";
    {
        const file = try tmp_dir.dir.createFile("test.txt", .{});
        defer file.close();
        try file.writeAll(test_content);
    }

    // Now open the file and try memory mapping it
    {
        const file = try tmp_dir.dir.openFile("test.txt", .{});
        defer file.close();

        var stream = try ByteStream.initFile(file, testing.allocator, 0); // Force memory mapping
        defer stream.deinit();

        // Verify we're using memory mapping
        try testing.expect(stream.isMemoryMapped());

        // Check the memory map type
        const map_type = stream.getMemoryMapType() orelse return error.NoMemoryMapping;
        std.debug.print("\nMemory map type: {}\n", .{map_type});

        // Check the content
        switch (stream.source) {
            .mmap => |mmap| {
                try testing.expectEqualStrings(test_content, mmap.data);
            },
            else => {
                return error.ExpectedMemoryMapping;
            },
        }

        // Test basic read operations
        var i: usize = 0;
        while (i < test_content.len) : (i += 1) {
            const byte = try stream.peek();
            try testing.expect(byte != null);
            try testing.expectEqual(test_content[i], byte.?);
            _ = try stream.consume();
        }

        // Should be at EOF now
        try testing.expectEqual(@as(?u8, null), try stream.peek());
    }
}

test "Memory mapping large file" {
    // Skip this test if the OS doesn't support memory mapping
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and
        builtin.os.tag != .windows and builtin.os.tag != .freebsd)
    {
        return error.SkipZigTest;
    }

    // Create a temporary directory for our test files
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create a larger test file (4MB) to force OS-level memory mapping
    const buffer_size = 4 * 1024 * 1024; // 4MB
    var large_content = try testing.allocator.alloc(u8, buffer_size);
    defer testing.allocator.free(large_content);

    // Fill with pattern data
    for (0..buffer_size) |i| {
        large_content[i] = @truncate((i % 26) + 'a');
    }

    // Write the test file
    {
        const file = try tmp_dir.dir.createFile("large.txt", .{});
        defer file.close();
        try file.writeAll(large_content);
    }

    // Now open the file and try memory mapping it
    {
        const file = try tmp_dir.dir.openFile("large.txt", .{});
        defer file.close();

        // Use the default memory mapping threshold (1MB) to test OS mmap activation
        var stream = try ByteStream.initFile(file, testing.allocator, byte_stream.DEFAULT_MMAP_THRESHOLD);
        defer stream.deinit();

        // Verify we're using memory mapping
        try testing.expect(stream.isMemoryMapped());

        // Check memory map type - with large file, should be OS-level memory mapping
        const map_type = stream.getMemoryMapType() orelse return error.NoMemoryMapping;
        std.debug.print("\nLarge file memory map type: {}\n", .{map_type});

        // Don't require OS memory mapping in tests as it might fall back to file loading
        // if mmap fails or platform doesn't support it

        // Check the content matches
        switch (stream.source) {
            .mmap => |mmap| {
                try testing.expectEqual(buffer_size, mmap.data.len);

                // Don't compare the whole 4MB content as it would be slow
                // Just check a few random positions
                const positions = [_]usize{ 0, 1023, 1024, 1025, buffer_size / 2, buffer_size - 2, buffer_size - 1 };
                for (positions) |pos| {
                    try testing.expectEqual(large_content[pos], mmap.data[pos]);
                }
            },
            else => {
                return error.ExpectedMemoryMapping;
            },
        }

        // Test random access by seeking to different positions
        const positions = [_]usize{ 0, 1024, buffer_size / 4, buffer_size / 2, buffer_size - 1024, buffer_size - 1 };

        for (positions) |pos| {
            try stream.seekTo(pos);
            const byte = try stream.peek();
            try testing.expectEqual(large_content[pos], byte.?);

            // Consume a few bytes from this position
            var i: usize = 0;
            while (i < 10 and pos + i < buffer_size) : (i += 1) {
                const b = try stream.peek();
                try testing.expectEqual(large_content[pos + i], b.?);
                _ = try stream.consume();
            }
        }

        // Test getting the file size
        try testing.expectEqual(buffer_size, try stream.getSize());
    }
}

test "Memory mapping performance test" {
    // Skip this test by default as it's more of a benchmark
    // Enable this test only when running performance measurements
    if (std.debug.runtime_safety) {
        return error.SkipZigTest;
    }

    // Skip this test if the OS doesn't support memory mapping
    if (builtin.os.tag != .linux and builtin.os.tag != .macos and
        builtin.os.tag != .windows and builtin.os.tag != .freebsd)
    {
        return error.SkipZigTest;
    }

    // Create a temporary directory for our test files
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create a large test file (8MB) for proper benchmarking
    const buffer_size = 8 * 1024 * 1024; // 8MB
    var content = try testing.allocator.alloc(u8, buffer_size);
    defer testing.allocator.free(content);

    // Fill with pattern data
    for (0..buffer_size) |i| {
        content[i] = @truncate((i % 94) + 33); // Printable ASCII
    }

    // Write the test file
    {
        const file = try tmp_dir.dir.createFile("benchmark.txt", .{});
        defer file.close();
        try file.writeAll(content);
    }

    // Timer for benchmarking
    var timer = try std.time.Timer.start();
    var standard_time: u64 = 0;

    // Test standard file I/O
    {
        const file = try tmp_dir.dir.openFile("benchmark.txt", .{});
        defer file.close();

        var stream = ByteStream.initFileStandard(file);
        defer stream.deinit();

        // Time how long it takes to read the entire file
        timer.reset();
        var byte_count: usize = 0;
        var checksum: u64 = 0;
        while (try stream.consume()) |byte| {
            byte_count += 1;
            checksum +%= byte; // Simple checksum to prevent optimization
        }

        standard_time = timer.lap();
        const standard_ms = @divFloor(standard_time, 1_000_000); // Convert to ms
        const standard_throughput = @divFloor(buffer_size * 1000, standard_ms) / 1024; // KB/s

        std.debug.print("\nStandard I/O: Read {d} bytes in {d} ms ({d} KB/s), Checksum: {d}\n", .{ byte_count, standard_ms, standard_throughput, checksum });

        try file.seekTo(0); // Reset for next test
    }

    // Test file-loaded memory mapping (reads entire file into memory)
    {
        const file = try tmp_dir.dir.openFile("benchmark.txt", .{});
        defer file.close();

        // Force file loading by setting threshold higher than file size
        var stream = try ByteStream.initFileLoad(file, testing.allocator, buffer_size);
        defer stream.deinit();

        // Check memory map type
        const map_type = stream.getMemoryMapType() orelse return error.NoMemoryMapping;
        try testing.expectEqual(MemoryMapType.file_loaded, map_type);

        // Time how long it takes to read the entire file
        timer.reset();
        var byte_count: usize = 0;
        var checksum: u64 = 0;
        while (try stream.consume()) |byte| {
            byte_count += 1;
            checksum +%= byte; // Simple checksum to prevent optimization
        }

        const file_loaded_time = timer.lap();
        const file_loaded_ms = @divFloor(file_loaded_time, 1_000_000); // Convert to ms
        const file_loaded_throughput = @divFloor(buffer_size * 1000, file_loaded_ms) / 1024; // KB/s

        std.debug.print("File Loaded: Read {d} bytes in {d} ms ({d} KB/s), Checksum: {d}\n", .{ byte_count, file_loaded_ms, file_loaded_throughput, checksum });

        // Calculate speedup vs standard I/O
        const file_loaded_speedup = @as(f64, @floatFromInt(standard_time)) /
            @as(f64, @floatFromInt(file_loaded_time));
        std.debug.print("File loading is {d:.2}x faster than standard I/O\n", .{file_loaded_speedup});

        try file.seekTo(0); // Reset for next test
    }

    // Test OS-level memory mapping (if available)
    if (builtin.os.tag == .linux or builtin.os.tag == .macos or
        builtin.os.tag == .windows or builtin.os.tag == .freebsd)
    {
        const file = try tmp_dir.dir.openFile("benchmark.txt", .{});
        defer file.close();

        // Use default threshold to get OS-level mapping
        var stream = try ByteStream.initFile(file, testing.allocator, ByteStream.DEFAULT_MMAP_THRESHOLD);
        defer stream.deinit();

        // Check memory map type
        const map_type = stream.getMemoryMapType() orelse return error.NoMemoryMapping;
        std.debug.print("OS Memory map type: {}\n", .{map_type});

        // Time how long it takes to read the entire file
        timer.reset();
        var byte_count: usize = 0;
        var checksum: u64 = 0;
        while (try stream.consume()) |byte| {
            byte_count += 1;
            checksum +%= byte; // Simple checksum to prevent optimization
        }

        const mmap_time = timer.lap();
        const mmap_ms = @divFloor(mmap_time, 1_000_000); // Convert to ms
        const mmap_throughput = @divFloor(buffer_size * 1000, mmap_ms) / 1024; // KB/s

        std.debug.print("OS Mmap: Read {d} bytes in {d} ms ({d} KB/s), Checksum: {d}\n", .{ byte_count, mmap_ms, mmap_throughput, checksum });

        // Calculate speedup vs standard I/O
        const mmap_speedup = @as(f64, @floatFromInt(standard_time)) /
            @as(f64, @floatFromInt(mmap_time));
        std.debug.print("OS memory mapping is {d:.2}x faster than standard I/O\n", .{mmap_speedup});
    }

    // Test random access performance
    const test_positions = [_]usize{
        0,
        1024,
        buffer_size / 4,
        buffer_size / 2,
        buffer_size - 1024,
        buffer_size - 1,
    };

    // Standard I/O seeks
    {
        const file = try tmp_dir.dir.openFile("benchmark.txt", .{});
        defer file.close();

        var stream = ByteStream.initFileStandard(file);
        defer stream.deinit();

        // Time random seeks
        timer.reset();
        var total_bytes: usize = 0;

        for (0..50) |_| {
            for (test_positions) |pos| {
                try stream.seekTo(pos);
                const byte = try stream.consume() orelse 0;
                total_bytes += byte;
            }
        }

        const seek_time = timer.lap();
        const seek_ms = @divFloor(seek_time, 1_000_000); // Convert to ms

        std.debug.print("\nStandard I/O Random Seeks: {d} ms for 300 seeks\n", .{seek_ms});
    }

    // Memory mapped seeks
    {
        const file = try tmp_dir.dir.openFile("benchmark.txt", .{});
        defer file.close();

        var stream = try ByteStream.initFile(file, testing.allocator, ByteStream.DEFAULT_MMAP_THRESHOLD);
        defer stream.deinit();

        // Time random seeks
        timer.reset();
        var total_bytes: usize = 0;

        for (0..50) |_| {
            for (test_positions) |pos| {
                try stream.seekTo(pos);
                const byte = try stream.consume() orelse 0;
                total_bytes += byte;
            }
        }

        const seek_time = timer.lap();
        const seek_ms = @divFloor(seek_time, 1_000_000); // Convert to ms

        std.debug.print("Memory Mapped Random Seeks: {d} ms for 300 seeks\n", .{seek_ms});
    }
}
