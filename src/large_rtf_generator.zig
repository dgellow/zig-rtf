const std = @import("std");

// Generator for massive, complex RTF files for benchmarking
pub const LargeRtfGenerator = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .output = std.ArrayList(u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.output.deinit();
    }
    
    pub fn generate(self: *Self, target_size_mb: u32) ![]const u8 {
        const writer = self.output.writer();
        
        // RTF header with comprehensive font and color tables
        try writer.writeAll("{\\rtf1\\ansi\\deff0");
        
        // Generate large font table (50 fonts)
        try self.generateFontTable(writer);
        
        // Generate large color table (100 colors)
        try self.generateColorTable(writer);
        
        // Calculate how much content we need
        const target_bytes = target_size_mb * 1024 * 1024;
        const header_size = self.output.items.len;
        const content_target = target_bytes - header_size - 1000; // Reserve space for closing
        
        std.debug.print("Generating ~{}MB of complex RTF content...\n", .{target_size_mb});
        
        var content_generated: usize = 0;
        var section_counter: u32 = 0;
        
        while (content_generated < content_target) {
            section_counter += 1;
            
            switch (section_counter % 6) {
                0 => try self.generateFormattedText(writer, section_counter),
                1 => try self.generateTable(writer, section_counter),
                2 => try self.generateImageSection(writer, section_counter),
                3 => try self.generateHyperlinkSection(writer, section_counter),
                4 => try self.generateComplexFormatting(writer, section_counter),
                5 => try self.generateParagraphFormatting(writer, section_counter),
                else => unreachable,
            }
            
            content_generated = self.output.items.len - header_size;
            
            if (section_counter % 100 == 0) {
                const current_mb = @as(f64, @floatFromInt(self.output.items.len)) / 1024.0 / 1024.0;
                std.debug.print("Generated: {d:.1}MB (section {})...\n", .{current_mb, section_counter});
            }
        }
        
        // Close RTF
        try writer.writeAll("}");
        
        const final_size = @as(f64, @floatFromInt(self.output.items.len)) / 1024.0 / 1024.0;
        std.debug.print("Generated {d:.1}MB RTF file with {} sections\n", .{final_size, section_counter});
        
        return self.output.items;
    }
    
    fn generateFontTable(self: *Self, writer: anytype) !void {
        _ = self;
        try writer.writeAll("{\\fonttbl");
        
        const fonts = [_]struct { name: []const u8, family: []const u8 }{
            .{ .name = "Arial", .family = "swiss" },
            .{ .name = "Times New Roman", .family = "roman" },
            .{ .name = "Courier New", .family = "modern" },
            .{ .name = "Comic Sans MS", .family = "script" },
            .{ .name = "Impact", .family = "swiss" },
            .{ .name = "Georgia", .family = "roman" },
            .{ .name = "Verdana", .family = "swiss" },
            .{ .name = "Trebuchet MS", .family = "swiss" },
            .{ .name = "Palatino", .family = "roman" },
            .{ .name = "Garamond", .family = "roman" },
        };
        
        // Generate 50 font entries (5 cycles of 10 fonts)
        for (0..50) |i| {
            const font = fonts[i % fonts.len];
            try writer.print("{{\\f{}\\f{s} {s} Font {};}}", .{i, font.family, font.name, i});
        }
        
        try writer.writeAll("}");
    }
    
    fn generateColorTable(self: *Self, writer: anytype) !void {
        _ = self;
        try writer.writeAll("{\\colortbl;"); // Auto color first
        
        // Generate 100 colors - rainbow spectrum plus variations
        for (0..100) |i| {
            const hue = @as(f32, @floatFromInt(i)) * 360.0 / 100.0;
            const rgb = hsvToRgb(hue, 0.8, 0.9);
            try writer.print("\\red{}\\green{}\\blue{};", .{rgb.r, rgb.g, rgb.b});
        }
        
        try writer.writeAll("}");
    }
    
    fn generateFormattedText(self: *Self, writer: anytype, section: u32) !void {
        _ = self;
        try writer.writeAll("\\par\\par");
        try writer.print("\\fs32\\b Section {}: Complex Formatted Text\\b0\\fs24\\par\\par", .{section});
        
        // Generate much simpler paragraphs - no nested groups
        for (0..5) |para| {
            const font_id = para % 10;  // Use fewer fonts
            const color_id = (para * 3) % 20 + 1;  // Use fewer colors
            
            try writer.print("\\f{}\\cf{}", .{font_id, color_id});
            if (para % 2 == 0) try writer.writeAll("\\b");
            try writer.print(" This is paragraph {} with formatting. ", .{para + 1});
            try writer.writeAll("Lorem ipsum dolor sit amet, consectetur adipiscing elit. ");
            if (para % 2 == 0) try writer.writeAll("\\b0");
            try writer.writeAll("\\par");
        }
    }
    
    fn generateTable(self: *Self, writer: anytype, section: u32) !void {
        _ = self;
        try writer.writeAll("\\par\\par");
        try writer.print("\\fs28\\b Table {} - Simple Data Table\\b0\\fs24\\par\\par", .{section});
        
        // Generate a simple 3x3 table - no nested groups
        for (0..3) |row| {
            try writer.writeAll("\\trowd\\cellx2880\\cellx5760\\cellx8640");
            
            // Simple table row content
            for (0..3) |col| {
                if (row == 0) try writer.writeAll("\\b");
                if (row == 0) {
                    try writer.print(" Header {} ", .{col + 1});
                } else {
                    try writer.print(" R{}C{} ", .{row, col + 1});
                }
                if (row == 0) try writer.writeAll("\\b0");
                try writer.writeAll("\\cell");
            }
            
            try writer.writeAll("\\row");
        }
        
        try writer.writeAll("\\par");
    }
    
    fn generateImageSection(self: *Self, writer: anytype, section: u32) !void {
        _ = self;
        try writer.writeAll("\\par\\par");
        try writer.print("\\fs28\\b Image Section {}\\b0\\fs24\\par\\par", .{section});
        
        // Generate one simple image
        try writer.writeAll("Image 1 - ");
        try writer.writeAll("{\\pict\\pngblip\\picw100\\pich75 ");
        
        // Much smaller hex pattern (simulates 100 bytes)
        for (0..50) |i| {
            const byte = @as(u8, @intCast((i + section) % 256));
            try writer.print("{x:0>2}", .{byte});
        }
        
        try writer.writeAll("}\\par");
    }
    
    fn generateHyperlinkSection(self: *Self, writer: anytype, section: u32) !void {
        _ = self;
        try writer.writeAll("\\par\\par");
        try writer.print("\\fs24\\b Hyperlink Section {}\\b0\\fs24\\par\\par", .{section});
        
        // Just two simple hyperlinks
        try writer.print("Visit \\cf2\\ul https://example{}.com\\cf0\\ul0 for more info.\\par", .{section});
        try writer.writeAll("Check \\cf3\\ul https://test.org\\cf0\\ul0 as well.\\par");
    }
    
    fn generateComplexFormatting(self: *Self, writer: anytype, section: u32) !void {
        _ = self;
        try writer.writeAll("\\par\\par");
        try writer.print("\\fs30\\b Complex Formatting {}\\b0\\fs24\\par\\par", .{section});
        
        // Very simple formatting - no nested groups at all
        try writer.writeAll("This text has \\b bold\\b0 and \\i italic\\i0 and \\ul underline\\ul0 formatting.\\par\\par");
        
        // Simple font size changes
        try writer.writeAll("\\fs16 Small\\fs24 medium\\fs36 LARGE\\fs24 text sizes.\\par\\par");
        
        // Simple color changes
        try writer.writeAll("\\cf2 Red\\cf3 Green\\cf4 Blue\\cf0 text.\\par\\par");
    }
    
    fn generateParagraphFormatting(self: *Self, writer: anytype, section: u32) !void {
        _ = self;
        try writer.writeAll("\\par\\par");
        try writer.print("\\fs26\\b Paragraph Formatting {}\\b0\\fs24\\par\\par", .{section});
        
        // Simple alignment without nested groups
        try writer.writeAll("\\ql This paragraph is left-aligned.\\par");
        try writer.writeAll("\\qc This paragraph is center-aligned.\\par");
        try writer.writeAll("\\qr This paragraph is right-aligned.\\par");
        try writer.writeAll("\\qj This paragraph is justified.\\par");
    }
};

// Helper function to convert HSV to RGB
fn hsvToRgb(h: f32, s: f32, v: f32) struct { r: u8, g: u8, b: u8 } {
    const c = v * s;
    const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
    const m = v - c;
    
    var r: f32 = 0;
    var g: f32 = 0;  
    var b: f32 = 0;
    
    if (h < 60) {
        r = c; g = x; b = 0;
    } else if (h < 120) {
        r = x; g = c; b = 0;
    } else if (h < 180) {
        r = 0; g = c; b = x;
    } else if (h < 240) {
        r = 0; g = x; b = c;
    } else if (h < 300) {
        r = x; g = 0; b = c;
    } else {
        r = c; g = 0; b = x;
    }
    
    return .{
        .r = @intFromFloat((r + m) * 255.0),
        .g = @intFromFloat((g + m) * 255.0),
        .b = @intFromFloat((b + m) * 255.0),
    };
}