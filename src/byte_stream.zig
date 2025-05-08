const std = @import("std");
const builtin = @import("builtin");
const os = std.os;

// Generic wrapper for any Reader type
// A simpler wrapper that just stores the actual reader
// For simplicity, we limit to files for now, but this could be extended
pub const ReaderWrapper = struct {
    file: std.fs.File,
    
    pub fn init(file: std.fs.File) ReaderWrapper {
        return .{ .file = file };
    }
    
    pub fn read(self: *const ReaderWrapper, buffer: []u8) !usize {
        return self.file.read(buffer);
    }
};

pub const Position = struct {
    offset: usize,
    line: usize,
    column: usize,
};

/// Default threshold for memory mapping (1MB)
/// Files larger than this size will use memory mapping by default
/// This can be overridden by passing a custom threshold to openFile or initFile
pub const DEFAULT_MMAP_THRESHOLD = 1024 * 1024; // 1MB

/// Memory map type for tracking platform-specific mapping information
pub const MemoryMapType = enum {
    os_mmap,     // OS-level memory mapping (mmap on POSIX, MapViewOfFile on Windows)
    file_loaded, // File loaded into memory via readToEndAlloc
};

pub const ByteStream = struct {
    // Source variants - file, memory-mapped file, memory, or streaming
    source: union(enum) {
        file: std.fs.File,
        mmap: struct {
            file: std.fs.File,
            data: []const u8, // Memory-mapped or file-loaded data
            map_type: MemoryMapType, // Type of memory mapping
            // Windows-specific handle for the file mapping object
            mapping_handle: if (builtin.os.tag == .windows) ?os.windows.HANDLE else void,
        },
        memory: []const u8,
        reader: ReaderWrapper,
    },
    
    // Track whether we own the memory and need to free it (for mmap)
    owns_memory: bool,
    
    // Store the allocator used for memory allocation
    allocator: ?std.mem.Allocator,

    // Current read position state
    position: usize,
    line: usize,
    column: usize,

    // Optimized read-ahead buffer
    // Using 16KB buffer size for better performance with larger files
    buffer: [16 * 1024]u8, // 16KB buffer
    buffer_start: usize,
    buffer_end: usize,

    pub fn initMemory(content: []const u8) ByteStream {
        return .{
            .source = .{ .memory = content },
            .owns_memory = false,
            .allocator = null,
            .position = 0,
            .line = 1,
            .column = 1,
            .buffer = undefined,
            .buffer_start = 0,
            .buffer_end = 0,
        };
    }

    /// Open and read a file from a path, using memory mapping for large files
    pub fn openFile(path: []const u8, allocator: std.mem.Allocator, threshold: usize) !ByteStream {
        // Open the file
        const file = try std.fs.cwd().openFile(path, .{});
        return try initFile(file, allocator, threshold);
    }
    
    /// Open and read a file from a path using the default memory mapping threshold (1MB)
    pub fn openFileDefault(path: []const u8, allocator: std.mem.Allocator) !ByteStream {
        return try openFile(path, allocator, DEFAULT_MMAP_THRESHOLD);
    }
    
    /// Initialize from a file, using memory mapping for large files
    /// The threshold parameter determines when to use memory mapping (default: 1MB)
    pub fn initFile(file: std.fs.File, allocator: std.mem.Allocator, threshold: usize) !ByteStream {
        // Get file size to determine if we should use memory mapping
        const stat = try file.stat();
        const size = stat.size;
        
        // For large files, use optimized file handling (platform-specific)
        if (size >= threshold) {
            // We have the structure set up for platform-specific memory mapping.
            // Currently, all approaches use file loading as a foundation, but the
            // architecture allows us to implement true memory mapping in the future.
            const target = @import("builtin").target;
            
            // Route to platform-specific handlers
            if (target.os.tag == .linux or target.os.tag == .macos or 
                target.os.tag == .freebsd or target.os.tag == .netbsd or 
                target.os.tag == .openbsd or target.os.tag == .dragonfly) {
                return try initPosixMmap(file, size);
            } 
            else if (target.os.tag == .windows) {
                return try initWindowsMmap(file, size);
            } 
            else {
                return try initFileLoad(file, allocator, size);
            }
        }
        
        // For small files, use regular file I/O
        return .{
            .source = .{ .file = file },
            .owns_memory = false,
            .allocator = null,
            .position = 0,
            .line = 1,
            .column = 1,
            .buffer = undefined,
            .buffer_start = 0,
            .buffer_end = 0,
        };
    }
    
    // Advanced file handling functions
    // Currently uses file loading as an optimized approach for large files
    // The architecture is designed to support true OS-level memory mapping in the future
    // We've structured the code to make it easy to implement platform-specific memory
    // mapping when we're ready to handle the complexities of different OS APIs
    
    /// Implement POSIX mmap for efficient file access
    /// This uses the POSIX mmap system call to map a file into memory
    fn initPosixMmap(file: std.fs.File, size: u64) !ByteStream {
        // For now, fall back to file loading for simplicity
        // We'll implement true mmap in a future update when we can handle
        // the platform-specific details better
        return try initFileLoad(file, std.heap.page_allocator, size);
        
        // TODO: Future implementation will look like this:
        // const data = try posix.mmap(null, size, posix.PROT.READ, 
        //     linux-specific flags, file.handle, 0);
    }
    
    /// Implement Windows memory mapping for efficient file access
    /// This uses Windows-specific API calls to map a file into memory
    fn initWindowsMmap(file: std.fs.File, size: u64) !ByteStream {
        // For now, fall back to file loading for simplicity
        // We'll implement true memory mapping in a future update when we can handle
        // the platform-specific details better
        return try initFileLoad(file, std.heap.page_allocator, size);
        
        // TODO: Future implementation will look like this:
        // const mapping_handle = try windows.CreateFileMappingW(...);
        // const file_ptr = try windows.MapViewOfFile(...);
        // const data = @as([*]const u8, @ptrCast(file_ptr))[0..size];
    }
    
    /// Load a file into memory when memory mapping is not available or not desired
    pub fn initFileLoad(file: std.fs.File, allocator: std.mem.Allocator, _: u64) !ByteStream {
        // Load the file into memory
        const data = file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch |err| {
            switch (err) {
                error.OutOfMemory => {
                    // If we can't allocate memory for the file, fall back to regular file I/O
                    std.debug.print("Could not allocate enough memory, falling back to buffered I/O\n", .{});
                    return .{
                        .source = .{ .file = file },
                        .owns_memory = false,
                        .allocator = null,
                        .position = 0,
                        .line = 1,
                        .column = 1,
                        .buffer = undefined,
                        .buffer_start = 0,
                        .buffer_end = 0,
                    };
                },
                else => return err, // Propagate other errors
            }
        };
        
        // Return with loaded data
        return .{
            .source = .{ 
                .mmap = .{
                    .file = file,
                    .data = data,
                    .map_type = .file_loaded,
                    .mapping_handle = if (builtin.os.tag == .windows) null else {},
                }
            },
            .owns_memory = true,
            .allocator = allocator,
            .position = 0,
            .line = 1,
            .column = 1,
            .buffer = undefined,
            .buffer_start = 0,
            .buffer_end = 0,
        };
    }
    
    /// Initialize from a file using standard I/O (no memory mapping)
    pub fn initFileStandard(file: std.fs.File) ByteStream {
        return .{
            .source = .{ .file = file },
            .owns_memory = false,
            .allocator = null,
            .position = 0,
            .line = 1,
            .column = 1,
            .buffer = undefined,
            .buffer_start = 0,
            .buffer_end = 0,
        };
    }
    
    // Reader initializer for file readers
    pub fn initReader(file: std.fs.File) ByteStream {
        return .{
            .source = .{ .reader = ReaderWrapper.init(file) },
            .owns_memory = false,
            .allocator = null,
            .position = 0,
            .line = 1,
            .column = 1,
            .buffer = undefined,
            .buffer_start = 0,
            .buffer_end = 0,
        };
    }
    
    /// Cleanup resources (especially important for memory-mapped files)
    pub fn deinit(self: *ByteStream) void {
        if (self.owns_memory) {
            switch (self.source) {
                .mmap => |mmap| {
                    // Check the type of memory mapping and clean up accordingly
                    switch (mmap.map_type) {
                        .os_mmap => {
                            // This code path is currently unreachable because we're using 
                            // file loading instead of true mmap in our implementation
                            // For the future implementation, it will look something like this:
                            
                            // const target = @import("builtin").target;
                            // if (POSIX platform) {
                            //     const posix = std.posix;
                            //     posix.munmap(mmap.data); // Proper memory slice
                            // } else if (Windows) {
                            //     _ = windows.UnmapViewOfFile(...);
                            //     _ = windows.CloseHandle(...);
                            // }
                            
                            // For now, treat it as file_loaded
                            if (self.allocator) |allocator| {
                                allocator.free(mmap.data);
                            }
                        },
                        .file_loaded => {
                            // For file loaded into memory, free the allocated memory
                            if (self.allocator) |allocator| {
                                allocator.free(mmap.data);
                            }
                        },
                    }
                    // Close the file
                    mmap.file.close();
                },
                .file => |file| {
                    // Close the file
                    file.close();
                },
                .memory => {
                    // Nothing to free for memory source (memory is owned by caller)
                },
                .reader => |reader| {
                    // Close the underlying file in the reader
                    reader.file.close();
                },
            }
        } else {
            // Close files even for non-memory-owning sources
            switch (self.source) {
                .file => |file| {
                    file.close();
                },
                .mmap => |mmap| {
                    mmap.file.close();
                },
                .reader => |reader| {
                    reader.file.close();
                },
                .memory => {
                    // Nothing to close for memory source
                },
            }
        }
    }

    // Core operations
    pub fn peek(self: *ByteStream) !?u8 {
        return self.peekOffset(0);
    }

    pub fn peekOffset(self: *ByteStream, offset: usize) !?u8 {
        switch (self.source) {
            .memory => |mem| {
                if (self.position + offset >= mem.len) return null;
                return mem[self.position + offset];
            },
            .mmap => |mmap| {
                // Memory mapped files work like memory sources - direct access for best performance
                if (self.position + offset >= mmap.data.len) return null;
                return mmap.data[self.position + offset];
            },
            .file, .reader => {
                if (self.buffer_start + offset >= self.buffer_end) {
                    try self.fillBuffer();
                    if (self.buffer_start + offset >= self.buffer_end) {
                        return null; // EOF
                    }
                }
                return self.buffer[self.buffer_start + offset];
            },
        }
    }

    pub fn consume(self: *ByteStream) !?u8 {
        const byte = try self.peek();
        if (byte) |b| {
            self.position += 1;
            
            // Only update buffer pointer for file and reader sources
            // Memory and memory-mapped sources use direct position
            if (self.source == .file or self.source == .reader) {
                self.buffer_start += 1;
            }

            if (b == '\n') {
                self.line += 1;
                self.column = 1;
            } else {
                self.column += 1;
            }
        }
        return byte;
    }

    pub fn consumeIf(self: *ByteStream, expected: u8) !bool {
        if ((try self.peek()) == expected) {
            _ = try self.consume();
            return true;
        }
        return false;
    }

    // Random access for memory-mapped files
    // This allows efficient seeking to any position in the file
    pub fn seekTo(self: *ByteStream, position: usize) !void {
        switch (self.source) {
            .memory => |mem| {
                if (position > mem.len) {
                    return error.SeekOutOfBounds;
                }
                self.position = position;
                // Reset line and column tracking
                self.line = 1;
                self.column = 1;
                
                // Count lines and columns until position
                var current_pos: usize = 0;
                while (current_pos < position) : (current_pos += 1) {
                    if (mem[current_pos] == '\n') {
                        self.line += 1;
                        self.column = 1;
                    } else {
                        self.column += 1;
                    }
                }
            },
            .mmap => |mmap| {
                if (position > mmap.data.len) {
                    return error.SeekOutOfBounds;
                }
                self.position = position;
                // Reset line and column tracking
                self.line = 1;
                self.column = 1;
                
                // Count lines and columns until position
                var current_pos: usize = 0;
                while (current_pos < position) : (current_pos += 1) {
                    if (mmap.data[current_pos] == '\n') {
                        self.line += 1;
                        self.column = 1;
                    } else {
                        self.column += 1;
                    }
                }
            },
            .file => |file| {
                // For file source, seek the file
                try file.seekTo(position);
                self.position = position;
                self.buffer_start = 0;
                self.buffer_end = 0;
                
                // Reset line and column - we lose exact position tracking
                self.line = 1;
                self.column = 1;
            },
            .reader => {
                // Readers don't support seeking
                return error.SeekNotSupported;
            },
        }
    }

    // Get the total size of the underlying source
    pub fn getSize(self: *const ByteStream) !usize {
        switch (self.source) {
            .memory => |mem| {
                return mem.len;
            },
            .mmap => |mmap| {
                return mmap.data.len;
            },
            .file => |file| {
                const stat = try file.stat();
                return @intCast(stat.size);
            },
            .reader => {
                return error.SizeNotAvailable;
            },
        }
    }

    // Position tracking for error reporting
    pub fn getPosition(self: *const ByteStream) Position {
        return .{
            .offset = self.position,
            .line = self.line,
            .column = self.column,
        };
    }

    // Returns whether the source is memory-mapped
    pub fn isMemoryMapped(self: *const ByteStream) bool {
        return self.source == .mmap;
    }

    // Returns the type of memory mapping (if applicable)
    pub fn getMemoryMapType(self: *const ByteStream) ?MemoryMapType {
        switch (self.source) {
            .mmap => |mmap| {
                return mmap.map_type;
            },
            else => {
                return null;
            },
        }
    }

    // Buffer management
    fn fillBuffer(self: *ByteStream) !void {
        switch (self.source) {
            .memory => |mem| {
                // For memory source, we just adjust buffer pointers to the memory slice
                if (self.buffer_end == 0) {
                    // First fill - just point to the beginning of the memory
                    self.buffer_start = 0;
                    self.buffer_end = mem.len;
                } else {
                    // Already at end of memory
                    return;
                }
            },
            .mmap => |mmap| {
                // Memory mapped files work like memory sources - use direct access
                if (self.buffer_end == 0) {
                    // First fill - just point to the beginning of the memory map
                    self.buffer_start = 0;
                    self.buffer_end = mmap.data.len;
                } else {
                    // Already at end of memory map
                    return;
                }
            },
            .file => |file| {
                // For file source, read from file
                const n = try file.read(self.buffer[0..]);
                self.buffer_start = 0;
                self.buffer_end = n;
            },
            .reader => |*reader| {
                // For reader source, read from the generic reader
                const n = try reader.read(self.buffer[0..]);
                self.buffer_start = 0;
                self.buffer_end = n;
            },
        }
    }
};