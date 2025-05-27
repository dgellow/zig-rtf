const std = @import("std");
const doc_model = @import("document_model.zig");

// =============================================================================
// SPECIALIZED TABLE PARSING
// =============================================================================
// Proper parsing for font tables, color tables, and RTF tables

// Font table parser state
pub const FontTableParser = struct {
    allocator: std.mem.Allocator,
    current_font: doc_model.FontInfo = .{ .id = 0, .name = "", .family = .dontcare, .charset = 0 },
    name_buffer: std.ArrayList(u8),
    in_font_entry: bool = false,
    
    pub fn init(allocator: std.mem.Allocator) FontTableParser {
        return .{
            .allocator = allocator,
            .name_buffer = std.ArrayList(u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *FontTableParser) void {
        self.name_buffer.deinit();
    }
    
    pub fn startFontEntry(self: *FontTableParser, font_id: u16) void {
        // Reset for new font entry
        self.current_font = .{
            .id = font_id,
            .name = "",
            .family = .dontcare,
            .charset = 0,
        };
        self.name_buffer.clearRetainingCapacity();
        self.in_font_entry = true;
    }
    
    pub fn setFontFamily(self: *FontTableParser, family: doc_model.FontInfo.FontFamily) void {
        if (self.in_font_entry) {
            self.current_font.family = family;
        }
    }
    
    pub fn addNameChar(self: *FontTableParser, char: u8) !void {
        if (self.in_font_entry) {
            try self.name_buffer.append(char);
        }
    }
    
    pub fn finishFontEntry(self: *FontTableParser) !doc_model.FontInfo {
        if (!self.in_font_entry) {
            return error.NotInFontEntry;
        }
        
        // Process the collected name
        var name = self.name_buffer.items;
        
        // Remove trailing semicolon if present
        if (name.len > 0 and name[name.len - 1] == ';') {
            name = name[0..name.len - 1];
        }
        
        // Trim whitespace
        const trimmed_name = std.mem.trim(u8, name, " \t\n\r");
        
        const font = doc_model.FontInfo{
            .id = self.current_font.id,
            .name = try self.allocator.dupe(u8, trimmed_name),
            .family = self.current_font.family,
            .charset = self.current_font.charset,
        };
        
        self.in_font_entry = false;
        return font;
    }
};

// Color table parser state
pub const ColorTableParser = struct {
    current_color: doc_model.ColorInfo = .{ .id = 0, .red = 0, .green = 0, .blue = 0 },
    next_color_id: u16 = 0,
    
    pub fn init() ColorTableParser {
        return .{};
    }
    
    pub fn startColorTable(self: *ColorTableParser) doc_model.ColorInfo {
        // First color is always auto/default (black)
        const auto_color = doc_model.ColorInfo{ .id = 0, .red = 0, .green = 0, .blue = 0 };
        self.next_color_id = 1;
        self.current_color = .{ .id = 1, .red = 0, .green = 0, .blue = 0 };
        return auto_color;
    }
    
    pub fn setRed(self: *ColorTableParser, value: u8) void {
        self.current_color.red = value;
    }
    
    pub fn setGreen(self: *ColorTableParser, value: u8) void {
        self.current_color.green = value;
    }
    
    pub fn setBlue(self: *ColorTableParser, value: u8) void {
        self.current_color.blue = value;
    }
    
    pub fn finishColorEntry(self: *ColorTableParser) doc_model.ColorInfo {
        const color = self.current_color;
        
        // Prepare for next color
        self.next_color_id += 1;
        self.current_color = .{
            .id = self.next_color_id,
            .red = 0,
            .green = 0,
            .blue = 0,
        };
        
        return color;
    }
};

// RTF table parser state
pub const TableParser = struct {
    allocator: std.mem.Allocator,
    current_table: ?doc_model.Table = null,
    current_row: ?doc_model.TableRow = null,
    current_cell: ?doc_model.TableCell = null,
    cell_widths: std.ArrayList(u32),
    
    pub fn init(allocator: std.mem.Allocator) TableParser {
        return .{
            .allocator = allocator,
            .cell_widths = std.ArrayList(u32).init(allocator),
        };
    }
    
    pub fn deinit(self: *TableParser) void {
        self.cell_widths.deinit();
        if (self.current_table) |*table| table.deinit();
        if (self.current_row) |*row| row.deinit();
        if (self.current_cell) |*cell| cell.deinit();
    }
    
    pub fn startTable(self: *TableParser) !void {
        if (self.current_table != null) {
            return error.TableAlreadyStarted;
        }
        
        self.current_table = doc_model.Table.init(self.allocator);
        self.cell_widths.clearRetainingCapacity();
    }
    
    pub fn startRow(self: *TableParser) !void {
        if (self.current_table == null) {
            try self.startTable();
        }
        
        // Finish previous row if exists
        if (self.current_row) |*row| {
            try self.current_table.?.rows.append(row.*);
        }
        
        self.current_row = doc_model.TableRow.init(self.allocator);
        self.cell_widths.clearRetainingCapacity();
    }
    
    pub fn setCellWidth(self: *TableParser, width: u32) !void {
        try self.cell_widths.append(width);
    }
    
    pub fn addCellContent(self: *TableParser, element: doc_model.ContentElement) !void {
        if (self.current_cell == null) {
            self.current_cell = doc_model.TableCell.init(self.allocator);
            
            // Set width if available
            if (self.cell_widths.items.len > 0) {
                const cell_index = if (self.current_row) |*row| row.cells.items.len else 0;
                if (cell_index < self.cell_widths.items.len) {
                    self.current_cell.?.width = self.cell_widths.items[cell_index];
                }
            }
        }
        
        try self.current_cell.?.content.append(element);
    }
    
    pub fn finishCell(self: *TableParser) !void {
        if (self.current_cell) |*cell| {
            if (self.current_row == null) {
                try self.startRow();
            }
            try self.current_row.?.cells.append(cell.*);
            self.current_cell = null;
        }
    }
    
    pub fn finishRow(self: *TableParser) !void {
        // Finish current cell if exists
        try self.finishCell();
        
        if (self.current_row) |*row| {
            if (self.current_table == null) {
                try self.startTable();
            }
            try self.current_table.?.rows.append(row.*);
            self.current_row = null;
        }
    }
    
    pub fn finishTable(self: *TableParser) !?doc_model.Table {
        try self.finishRow();
        
        if (self.current_table) |table| {
            self.current_table = null;
            return table;
        }
        
        return null;
    }
};

// Tests
test "font table parser" {
    const testing = std.testing;
    
    var parser = FontTableParser.init(testing.allocator);
    defer parser.deinit();
    
    // Simulate parsing {\f0\fswiss Arial;}
    parser.startFontEntry(0);
    parser.setFontFamily(.swiss);
    try parser.addNameChar('A');
    try parser.addNameChar('r');
    try parser.addNameChar('i');
    try parser.addNameChar('a');
    try parser.addNameChar('l');
    try parser.addNameChar(';');
    
    const font = try parser.finishFontEntry();
    defer testing.allocator.free(font.name);
    
    try testing.expectEqual(@as(u16, 0), font.id);
    try testing.expectEqualStrings("Arial", font.name);
    try testing.expectEqual(doc_model.FontInfo.FontFamily.swiss, font.family);
}

test "color table parser" {
    const testing = std.testing;
    
    var parser = ColorTableParser.init();
    
    // Start color table (gets auto color)
    const auto_color = parser.startColorTable();
    try testing.expectEqual(@as(u8, 0), auto_color.red);
    
    // Add red color
    parser.setRed(255);
    parser.setGreen(0);
    parser.setBlue(0);
    const red_color = parser.finishColorEntry();
    
    try testing.expectEqual(@as(u16, 1), red_color.id);
    try testing.expectEqual(@as(u8, 255), red_color.red);
    try testing.expectEqual(@as(u8, 0), red_color.green);
    try testing.expectEqual(@as(u8, 0), red_color.blue);
}

test "table parser basic" {
    const testing = std.testing;
    
    var parser = TableParser.init(testing.allocator);
    defer parser.deinit();
    
    try parser.startTable();
    try parser.startRow();
    try parser.setCellWidth(1000);
    
    // Add some content to cell
    const text_run = doc_model.TextRun.init("Cell 1", .{}, .{});
    try parser.addCellContent(.{ .text_run = text_run });
    
    try parser.finishCell();
    try parser.finishRow();
    
    var table = try parser.finishTable();
    defer if (table) |*t| t.deinit();
    
    try testing.expect(table != null);
    try testing.expectEqual(@as(usize, 1), table.?.rows.items.len);
    try testing.expectEqual(@as(usize, 1), table.?.rows.items[0].cells.items.len);
    try testing.expectEqual(@as(u32, 1000), table.?.rows.items[0].cells.items[0].width);
}