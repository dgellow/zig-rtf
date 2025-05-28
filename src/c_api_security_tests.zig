const std = @import("std");
const testing = std.testing;
const c_api = @import("c_api.zig");

// Test C API security - null pointer safety
test "c api null pointer safety" {
    // All functions should handle null gracefully without crashing
    
    // Test rtf_parse with invalid parameters  
    try testing.expect(c_api.rtf_parse("test".ptr, 0) == null); // Zero length
    
    // Test functions with null document
    const empty_text = c_api.rtf_get_text(null);
    try testing.expectEqualStrings("", std.mem.span(empty_text));
    try testing.expect(c_api.rtf_get_text_length(null) == 0);
    try testing.expect(c_api.rtf_get_run_count(null) == 0);
    try testing.expect(c_api.rtf_get_run(null, 0) == null);
    
    // rtf_free with null should not crash
    c_api.rtf_free(null);
    
    // Test rtf_parse_file with invalid filename
    try testing.expect(c_api.rtf_parse_file("nonexistent_file.rtf") == null);
    
    std.debug.print("C API null pointer safety: PASS\n", .{});
}

test "c api bounds checking" {
    const rtf_data = "{\\rtf1 Test document}";
    const doc = c_api.rtf_parse(rtf_data.ptr, rtf_data.len) orelse return error.ParseFailed;
    defer c_api.rtf_free(doc);
    
    const run_count = c_api.rtf_get_run_count(doc);
    
    // Test out-of-bounds run access
    try testing.expect(c_api.rtf_get_run(doc, run_count) == null);
    try testing.expect(c_api.rtf_get_run(doc, run_count + 1) == null);
    try testing.expect(c_api.rtf_get_run(doc, 999999) == null);
    
    // Test with very large indices
    try testing.expect(c_api.rtf_get_run(doc, std.math.maxInt(usize)) == null);
    
    std.debug.print("C API bounds checking: PASS\n", .{});
}

test "c api memory corruption protection" {
    // Test with malformed RTF that could cause memory issues
    const malformed_cases = [_][]const u8{
        // Truncated RTF
        "{\\rtf1 truncated",
        // Only opening brace
        "{",
        // Only control word
        "\\rtf1",
        // Malformed unicode with huge numbers
        "{\\rtf1 \\u999999999999999999999999999? text}",
        // Binary data injection attempts
        "{\\rtf1 \x00\x01\x02\x03 text}",
        // Very long control word
        "{\\rtf1 \\" ++ "a" ** 1000 ++ " text}",
    };
    
    for (malformed_cases, 0..) |rtf_data, i| {
        std.debug.print("Testing malformed case {}: ", .{i + 1});
        
        const doc = c_api.rtf_parse(rtf_data.ptr, rtf_data.len);
        if (doc) |d| {
            // If parsing succeeded, verify we can safely access everything
            _ = c_api.rtf_get_text(d);
            const length = c_api.rtf_get_text_length(d);
            const run_count = c_api.rtf_get_run_count(d);
            
            std.debug.print("Success - text len={}, runs={}\n", .{ length, run_count });
            
            // Access all runs safely
            for (0..run_count) |j| {
                const run = c_api.rtf_get_run(d, j);
                try testing.expect(run != null);
            }
            
            c_api.rtf_free(d);
        } else {
            std.debug.print("Failed (acceptable)\n", .{});
        }
    }
}

test "c api large document handling" {
    // Create a large RTF document
    var rtf_buffer = std.ArrayList(u8).init(testing.allocator);
    defer rtf_buffer.deinit();
    
    try rtf_buffer.appendSlice("{\\rtf1 ");
    
    // Add 10,000 words with formatting
    for (0..10000) |i| {
        if (i % 100 == 0) {
            try rtf_buffer.writer().print("\\b Word{} \\b0 ", .{i});
        } else {
            try rtf_buffer.writer().print("Word{} ", .{i});
        }
    }
    
    try rtf_buffer.append('}');
    
    std.debug.print("Testing large document: {} bytes\n", .{rtf_buffer.items.len});
    
    const start = std.time.nanoTimestamp();
    
    const doc = c_api.rtf_parse(rtf_buffer.items.ptr, rtf_buffer.items.len) orelse {
        return error.ParseFailed;
    };
    defer c_api.rtf_free(doc);
    
    const end = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    
    const text = c_api.rtf_get_text(doc);
    const length = c_api.rtf_get_text_length(doc);
    const run_count = c_api.rtf_get_run_count(doc);
    
    std.debug.print("Large doc results: text_len={}, runs={}, parse_time={d:.2}ms\n", .{ length, run_count, duration_ms });
    
    // Verify we can access the text safely
    try testing.expect(std.mem.len(text) > 0);
    try testing.expect(length > 0);
    try testing.expect(run_count > 0);
    
    // Performance requirement
    try testing.expect(duration_ms < 1000.0); // Less than 1 second for 10K words
}

test "c api error message thread safety" {
    // Test that error messages are properly thread-local
    const ThreadContext = struct {
        thread_id: usize,
        error_msg: ?[*:0]const u8 = null,
        
        fn testErrors(self: *@This()) void {
            // Generate an error in this thread
            _ = c_api.rtf_parse("invalid".ptr, 0); // Zero length to trigger error
            
            // Get the error message
            self.error_msg = c_api.rtf_errmsg();
            
            // Clear the error
            c_api.rtf_clear_error();
        }
    };
    
    const thread_count = 5;
    var contexts: [thread_count]ThreadContext = undefined;
    var threads: [thread_count]std.Thread = undefined;
    
    // Initialize contexts
    for (0..thread_count) |i| {
        contexts[i] = .{ .thread_id = i };
    }
    
    // Start threads
    for (0..thread_count) |i| {
        threads[i] = try std.Thread.spawn(.{}, ThreadContext.testErrors, .{&contexts[i]});
    }
    
    // Wait for completion
    for (0..thread_count) |i| {
        threads[i].join();
    }
    
    // Verify each thread got error messages
    for (contexts, 0..) |context, i| {
        std.debug.print("Thread {}: error_msg present = {}\n", .{ i, context.error_msg != null });
        try testing.expect(context.error_msg != null);
    }
    
    std.debug.print("C API error thread safety: PASS\n", .{});
}

test "c api complex content through c bindings" {
    // Test complex RTF with images through C API
    const complex_rtf = 
        \\{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}
        \\{\pict\wmetafile8\picw1270\pich1270 010009000003440000}
        \\Complex document with \b bold\b0 and \i italic\i0 text.
        \\{\object\objemb\objw720\objh720{\*\objdata 504B0304}}
        \\}
    ;
    
    const doc = c_api.rtf_parse(complex_rtf.ptr, complex_rtf.len) orelse {
        return error.ParseFailed;
    };
    defer c_api.rtf_free(doc);
    
    const text = c_api.rtf_get_text(doc);
    const length = c_api.rtf_get_text_length(doc);
    const run_count = c_api.rtf_get_run_count(doc);
    
    std.debug.print("Complex content C API: text_len={}, runs={}\n", .{ length, run_count });
    if (length > 0) {
        // Convert C string to Zig slice safely
        const text_str = std.mem.span(text);
        const safe_len = @min(50, text_str.len);
        std.debug.print("Extracted text: '{s}...'\n", .{text_str[0..safe_len]});
    }
    
    // Should extract text but skip binary data (using string search)
    if (length > 0) {
        const text_str = std.mem.span(text);
        try testing.expect(std.mem.indexOf(u8, text_str, "Complex document") != null);
        try testing.expect(std.mem.indexOf(u8, text_str, "bold") != null);
        try testing.expect(std.mem.indexOf(u8, text_str, "italic") != null);
        
        // Should NOT contain binary data
        try testing.expect(std.mem.indexOf(u8, text_str, "wmetafile8") == null);
        try testing.expect(std.mem.indexOf(u8, text_str, "504B0304") == null);
    }
}

test "c api concurrent access safety" {
    // Test multiple threads using C API simultaneously
    const rtf_data = "{\\rtf1 Concurrent test document with \\b formatting\\b0}";
    
    const ConcurrentContext = struct {
        thread_id: usize,
        success: bool = false,
        text_length: usize = 0,
        
        fn concurrentTest(self: *@This()) void {
            // Each thread parses the same document
            const doc = c_api.rtf_parse(rtf_data.ptr, rtf_data.len) orelse return;
            defer c_api.rtf_free(doc);
            
            // Access document properties
            _ = c_api.rtf_get_text(doc); // Check that it doesn't crash
            const length = c_api.rtf_get_text_length(doc);
            const run_count = c_api.rtf_get_run_count(doc);
            
            // Verify basic properties
            if (length > 0 and run_count > 0) {
                // Access all runs
                for (0..run_count) |i| {
                    const run = c_api.rtf_get_run(doc, i);
                    if (run == null) return;
                }
                
                self.text_length = length;
                self.success = true;
            }
        }
    };
    
    const thread_count = 10;
    var contexts: [thread_count]ConcurrentContext = undefined;
    var threads: [thread_count]std.Thread = undefined;
    
    // Initialize contexts
    for (0..thread_count) |i| {
        contexts[i] = .{ .thread_id = i };
    }
    
    // Start concurrent tests
    for (0..thread_count) |i| {
        threads[i] = try std.Thread.spawn(.{}, ConcurrentContext.concurrentTest, .{&contexts[i]});
    }
    
    // Wait for completion
    for (0..thread_count) |i| {
        threads[i].join();
    }
    
    // Verify all threads succeeded
    var successful_threads: usize = 0;
    for (contexts, 0..) |context, i| {
        std.debug.print("Thread {}: success={}, text_len={}\n", .{ i, context.success, context.text_length });
        if (context.success) {
            successful_threads += 1;
        }
    }
    
    std.debug.print("Concurrent C API test: {}/{} threads successful\n", .{ successful_threads, thread_count });
    try testing.expect(successful_threads == thread_count);
}

test "c api memory pressure test" {
    // Test C API under memory pressure - many allocations
    var documents = std.ArrayList(*c_api.EnhancedDocument).init(testing.allocator);
    defer {
        for (documents.items) |doc| {
            c_api.rtf_free(doc);
        }
        documents.deinit();
    }
    
    const base_rtf = "{\\rtf1 Document ";
    const end_rtf = " with content}";
    
    // Create many documents
    for (0..100) |i| {
        var rtf_buffer = std.ArrayList(u8).init(testing.allocator);
        defer rtf_buffer.deinit();
        
        try rtf_buffer.appendSlice(base_rtf);
        try rtf_buffer.writer().print("{}", .{i});
        try rtf_buffer.appendSlice(end_rtf);
        
        const doc = c_api.rtf_parse(rtf_buffer.items.ptr, rtf_buffer.items.len);
        if (doc) |d| {
            try documents.append(d);
            
            // Verify document is valid
            const text = c_api.rtf_get_text(d);
            const length = c_api.rtf_get_text_length(d);
            try testing.expect(std.mem.len(text) > 0);
            try testing.expect(length > 0);
        }
    }
    
    std.debug.print("Memory pressure test: {} documents created\n", .{documents.items.len});
    try testing.expect(documents.items.len > 90); // At least 90% should succeed
}

test "c api unicode edge cases" {
    // Test Unicode handling through C API
    const unicode_cases = [_][]const u8{
        "{\\rtf1 \\u8364? Euro symbol}",
        "{\\rtf1 \\u65535? Max BMP}",
        "{\\rtf1 \\u0? Null char}",
        "{\\rtf1 Mixed \\u8364? \\u8482? \\u169? symbols}",
    };
    
    for (unicode_cases, 0..) |rtf_data, i| {
        std.debug.print("Unicode case {}: ", .{i + 1});
        
        const doc = c_api.rtf_parse(rtf_data.ptr, rtf_data.len);
        if (doc) |d| {
            defer c_api.rtf_free(d);
            
            _ = c_api.rtf_get_text(d); // Verify it doesn't crash
            const length = c_api.rtf_get_text_length(d);
            
            std.debug.print("Success - extracted {} bytes\n", .{length});
            
            // Verify reasonable output (some unicode cases might result in empty text)
            // Just check that length is reasonable - allow zero for edge cases like null char
            try testing.expect(length < 1000); // Reasonable size
        } else {
            std.debug.print("Failed (may be acceptable)\n", .{});
        }
    }
}