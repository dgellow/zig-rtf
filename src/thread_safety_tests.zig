const std = @import("std");
const testing = std.testing;

test "concurrent rtf parsing - thread safety" {
    const rtf_parser = @import("rtf.zig");
    
    // Test data for concurrent parsing
    const test_rtf_documents = [_][]const u8{
        "{\\rtf1 Document 1 with \\b bold\\b0 text}",
        "{\\rtf1 Document 2 with \\i italic\\i0 text}",
        "{\\rtf1 Document 3 with \\ul underlined\\ulnone text}",
        "{\\rtf1 Document 4 with mixed \\b\\i bold italic\\i0\\b0 text}",
        "{\\rtf1 Document 5 with {\\b nested {\\i formatting} groups}}",
    };
    
    // Function to parse RTF in a thread
    const ParseContext = struct {
        rtf_data: []const u8,
        result: ?[]u8 = null,
        error_occurred: bool = false,
        allocator: std.mem.Allocator,
        
        fn parseRtf(self: *@This()) void {
            var stream = std.io.fixedBufferStream(self.rtf_data);
            var parser = rtf_parser.Parser.init(stream.reader().any(), self.allocator);
            defer parser.deinit();
            
            if (parser.parse()) {
                const text = parser.getText();
                self.result = self.allocator.dupe(u8, text) catch {
                    self.error_occurred = true;
                    return;
                };
            } else |_| {
                self.error_occurred = true;
            }
        }
    };
    
    // Create thread contexts
    var contexts: [test_rtf_documents.len]ParseContext = undefined;
    var threads: [test_rtf_documents.len]std.Thread = undefined;
    
    for (test_rtf_documents, 0..) |rtf_data, i| {
        contexts[i] = ParseContext{
            .rtf_data = rtf_data,
            .allocator = testing.allocator,
        };
    }
    
    // Start all threads
    for (0..test_rtf_documents.len) |i| {
        threads[i] = try std.Thread.spawn(.{}, ParseContext.parseRtf, .{&contexts[i]});
    }
    
    // Wait for all threads to complete
    for (0..test_rtf_documents.len) |i| {
        threads[i].join();
    }
    
    // Verify results
    for (contexts, 0..) |context, i| {
        try testing.expect(!context.error_occurred);
        try testing.expect(context.result != null);
        
        const result = context.result.?;
        defer testing.allocator.free(result);
        
        std.debug.print("Thread {} result: '{s}'\n", .{ i, result });
        
        // Verify each document parsed correctly
        switch (i) {
            0 => {
                try testing.expect(std.mem.indexOf(u8, result, "Document 1") != null);
                try testing.expect(std.mem.indexOf(u8, result, "bold") != null);
            },
            1 => {
                try testing.expect(std.mem.indexOf(u8, result, "Document 2") != null);
                try testing.expect(std.mem.indexOf(u8, result, "italic") != null);
            },
            2 => {
                try testing.expect(std.mem.indexOf(u8, result, "Document 3") != null);
                try testing.expect(std.mem.indexOf(u8, result, "underlined") != null);
            },
            3 => {
                try testing.expect(std.mem.indexOf(u8, result, "Document 4") != null);
                try testing.expect(std.mem.indexOf(u8, result, "bold italic") != null);
            },
            4 => {
                try testing.expect(std.mem.indexOf(u8, result, "Document 5") != null);
                try testing.expect(std.mem.indexOf(u8, result, "formatting") != null);
            },
            else => {},
        }
    }
}

test "stress test - many concurrent parsers" {
    const rtf_parser = @import("rtf.zig");
    
    const base_rtf = "{\\rtf1 Stress test document ";
    const end_rtf = "}";
    
    const thread_count = 10;
    const docs_per_thread = 100;
    
    const StressContext = struct {
        thread_id: usize,
        documents_processed: u32 = 0,
        errors: u32 = 0,
        allocator: std.mem.Allocator,
        
        fn stressTest(self: *@This()) void {
            for (0..docs_per_thread) |doc_id| {
                // Create unique RTF for this document
                var rtf_buffer = std.ArrayList(u8).init(self.allocator);
                defer rtf_buffer.deinit();
                
                rtf_buffer.appendSlice(base_rtf) catch {
                    self.errors += 1;
                    continue;
                };
                
                rtf_buffer.writer().print("thread {} doc {}", .{ self.thread_id, doc_id }) catch {
                    self.errors += 1;
                    continue;
                };
                
                rtf_buffer.appendSlice(end_rtf) catch {
                    self.errors += 1;
                    continue;
                };
                
                // Parse the document
                var stream = std.io.fixedBufferStream(rtf_buffer.items);
                var parser = rtf_parser.Parser.init(stream.reader().any(), self.allocator);
                defer parser.deinit();
                
                if (parser.parse()) {
                    const text = parser.getText();
                    // Verify expected content is present
                    if (std.mem.indexOf(u8, text, "Stress test document") != null and 
                        std.mem.indexOf(u8, text, "thread") != null) {
                        self.documents_processed += 1;
                    } else {
                        self.errors += 1;
                    }
                } else |_| {
                    self.errors += 1;
                }
            }
        }
    };
    
    var contexts: [thread_count]StressContext = undefined;
    var threads: [thread_count]std.Thread = undefined;
    
    // Initialize contexts
    for (0..thread_count) |i| {
        contexts[i] = StressContext{
            .thread_id = i,
            .allocator = testing.allocator,
        };
    }
    
    const start_time = std.time.nanoTimestamp();
    
    // Start all stress test threads
    for (0..thread_count) |i| {
        threads[i] = try std.Thread.spawn(.{}, StressContext.stressTest, .{&contexts[i]});
    }
    
    // Wait for completion
    for (0..thread_count) |i| {
        threads[i].join();
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    
    // Collect results
    var total_processed: u32 = 0;
    var total_errors: u32 = 0;
    
    for (contexts) |context| {
        total_processed += context.documents_processed;
        total_errors += context.errors;
        std.debug.print("Thread {}: {} processed, {} errors\n", .{ 
            context.thread_id, context.documents_processed, context.errors 
        });
    }
    
    const total_docs = thread_count * docs_per_thread;
    
    std.debug.print("Stress test results:\n", .{});
    std.debug.print("  Total documents: {}\n", .{total_docs});
    std.debug.print("  Successfully processed: {}\n", .{total_processed});
    std.debug.print("  Errors: {}\n", .{total_errors});
    std.debug.print("  Success rate: {d:.1}%\n", .{@as(f64, @floatFromInt(total_processed)) * 100.0 / @as(f64, @floatFromInt(total_docs))});
    std.debug.print("  Duration: {d:.2} ms\n", .{duration_ms});
    std.debug.print("  Rate: {d:.0} docs/sec\n", .{@as(f64, @floatFromInt(total_processed)) / (duration_ms / 1000.0)});
    
    // Verify high success rate
    try testing.expect(total_processed > total_docs * 95 / 100); // At least 95% success
    try testing.expect(total_errors < total_docs / 20); // Less than 5% error rate
}

test "thread safety - no data races" {
    const rtf_parser = @import("rtf.zig");
    
    // Test that multiple threads parsing the same document don't interfere
    const shared_rtf = "{\\rtf1 Shared document with \\b bold\\b0 and \\i italic\\i0 text}";
    const thread_count = 20;
    
    const SharedContext = struct {
        shared_data: []const u8,
        results: [thread_count]?[]u8 = [_]?[]u8{null} ** thread_count,
        thread_id: usize,
        allocator: std.mem.Allocator,
        
        fn parseShared(self: *@This()) void {
            var stream = std.io.fixedBufferStream(self.shared_data);
            var parser = rtf_parser.Parser.init(stream.reader().any(), self.allocator);
            defer parser.deinit();
            
            parser.parse() catch {
                return;
            };
            const text = parser.getText();
            self.results[self.thread_id] = self.allocator.dupe(u8, text) catch null;
        }
    };
    
    
    var threads: [thread_count]std.Thread = undefined;
    var contexts: [thread_count]*SharedContext = undefined;
    
    // Create per-thread contexts pointing to shared data
    for (0..thread_count) |i| {
        contexts[i] = try testing.allocator.create(SharedContext);
        contexts[i].* = .{
            .shared_data = shared_rtf,
            .thread_id = i,
            .allocator = testing.allocator,
        };
    }
    defer {
        for (contexts) |ctx| testing.allocator.destroy(ctx);
    }
    
    // Start threads
    for (0..thread_count) |i| {
        threads[i] = try std.Thread.spawn(.{}, SharedContext.parseShared, .{contexts[i]});
    }
    
    // Wait for completion
    for (0..thread_count) |i| {
        threads[i].join();
    }
    
    // Collect all results first, then compare (proper memory management)
    var all_results = std.ArrayList([]u8).init(testing.allocator);
    defer {
        for (all_results.items) |result| {
            testing.allocator.free(result);
        }
        all_results.deinit();
    }
    
    // Collect results from all threads
    for (0..thread_count) |i| {
        if (contexts[i].results[i]) |result| {
            try all_results.append(result);
        }
    }
    
    const successful_threads = all_results.items.len;
    std.debug.print("Thread safety test: {}/{} threads successful\n", .{ successful_threads, thread_count });
    
    // All threads should succeed
    try testing.expect(successful_threads == thread_count);
    
    // Verify all results are identical (proper comparison)
    if (all_results.items.len > 1) {
        const reference = all_results.items[0];
        
        for (all_results.items[1..], 1..) |result, i| {
            if (!std.mem.eql(u8, reference, result)) {
                std.debug.print("Thread {} result differs from thread 0:\n", .{i});
                std.debug.print("Thread 0: '{s}'\n", .{reference});
                std.debug.print("Thread {}: '{s}'\n", .{ i, result });
                return error.ThreadResultsDiffer;
            }
        }
    }
    
    // Verify content is correct (check first result)
    if (all_results.items.len > 0) {
        const result = all_results.items[0];
        try testing.expect(std.mem.indexOf(u8, result, "Shared document") != null);
        try testing.expect(std.mem.indexOf(u8, result, "bold") != null);
        try testing.expect(std.mem.indexOf(u8, result, "italic") != null);
    }
}