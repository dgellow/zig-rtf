const std = @import("std");
const Style = @import("parser.zig").Style;

/// Error types specific to the document model operations
pub const DocumentError = error{
    InvalidElementType,
    InvalidParent,
    ElementMismatch,
    InvalidValue,
    InvalidState,
};

/// The different types of elements that can be part of a document
pub const ElementType = enum {
    PARAGRAPH,
    TEXT_RUN,
    TABLE,
    TABLE_ROW,
    TABLE_CELL,
    IMAGE,
    HYPERLINK,
    FIELD,
    LIST,
    LIST_ITEM,
};

/// Base element struct that all document elements inherit from
pub const Element = struct {
    type: ElementType,
    parent: ?*Element = null,

    // Common methods
    pub fn destroy(self: *Element, allocator: std.mem.Allocator) void {
        switch (self.type) {
            .PARAGRAPH => {
                // Calculate the offset manually
                const offset = @offsetOf(Paragraph, "element");
                // Convert the self pointer to an address
                const self_addr = @intFromPtr(self);
                // Subtract the offset to get the address of the Paragraph
                const paragraph_addr = self_addr - offset;
                // Convert the address back to a pointer
                const paragraph = @as(*Paragraph, @ptrFromInt(paragraph_addr));
                paragraph.deinit(allocator);
                allocator.destroy(paragraph);
            },
            .TEXT_RUN => {
                const offset = @offsetOf(TextRun, "element");
                const self_addr = @intFromPtr(self);
                const text_run_addr = self_addr - offset;
                const text_run = @as(*TextRun, @ptrFromInt(text_run_addr));
                text_run.deinit(allocator);
                allocator.destroy(text_run);
            },
            .TABLE => {
                const offset = @offsetOf(Table, "element");
                const self_addr = @intFromPtr(self);
                const table_addr = self_addr - offset;
                const table = @as(*Table, @ptrFromInt(table_addr));
                table.deinit(allocator);
                allocator.destroy(table);
            },
            .TABLE_ROW => {
                const offset = @offsetOf(TableRow, "element");
                const self_addr = @intFromPtr(self);
                const row_addr = self_addr - offset;
                const row = @as(*TableRow, @ptrFromInt(row_addr));
                row.deinit(allocator);
                allocator.destroy(row);
            },
            .TABLE_CELL => {
                const offset = @offsetOf(TableCell, "element");
                const self_addr = @intFromPtr(self);
                const cell_addr = self_addr - offset;
                const cell = @as(*TableCell, @ptrFromInt(cell_addr));
                cell.deinit(allocator);
                allocator.destroy(cell);
            },
            .IMAGE => {
                const offset = @offsetOf(Image, "element");
                const self_addr = @intFromPtr(self);
                const image_addr = self_addr - offset;
                const image = @as(*Image, @ptrFromInt(image_addr));
                image.deinit(allocator);
                allocator.destroy(image);
            },
            .HYPERLINK => {
                const offset = @offsetOf(Hyperlink, "element");
                const self_addr = @intFromPtr(self);
                const hyperlink_addr = self_addr - offset;
                const hyperlink = @as(*Hyperlink, @ptrFromInt(hyperlink_addr));
                hyperlink.deinit(allocator);
                allocator.destroy(hyperlink);
            },
            .FIELD => {
                const offset = @offsetOf(Field, "element");
                const self_addr = @intFromPtr(self);
                const field_addr = self_addr - offset;
                const field = @as(*Field, @ptrFromInt(field_addr));
                field.deinit(allocator);
                allocator.destroy(field);
            },
            .LIST => {
                const offset = @offsetOf(List, "element");
                const self_addr = @intFromPtr(self);
                const list_addr = self_addr - offset;
                const list = @as(*List, @ptrFromInt(list_addr));
                list.deinit(allocator);
                allocator.destroy(list);
            },
            .LIST_ITEM => {
                const offset = @offsetOf(ListItem, "element");
                const self_addr = @intFromPtr(self);
                const list_item_addr = self_addr - offset;
                const list_item = @as(*ListItem, @ptrFromInt(list_item_addr));
                list_item.deinit(allocator);
                allocator.destroy(list_item);
            },
        }
    }

    /// Verify the element is of the expected type
    pub fn verifyType(self: *Element, expected: ElementType) !void {
        if (self.type != expected) {
            return DocumentError.InvalidElementType;
        }
    }

    /// Cast element to specific type (with type checking)
    pub fn as(self: *Element, comptime T: type) !*T {
        const expected_type = switch (T) {
            Paragraph => ElementType.PARAGRAPH,
            TextRun => ElementType.TEXT_RUN,
            Table => ElementType.TABLE,
            TableRow => ElementType.TABLE_ROW,
            TableCell => ElementType.TABLE_CELL,
            Image => ElementType.IMAGE,
            Hyperlink => ElementType.HYPERLINK,
            Field => ElementType.FIELD,
            List => ElementType.LIST,
            ListItem => ElementType.LIST_ITEM,
            else => @compileError("Unsupported element type: " ++ @typeName(T)),
        };

        try self.verifyType(expected_type);
        
        // Perform the same calculation as in destroy
        const offset = @offsetOf(T, "element");
        const self_addr = @intFromPtr(self);
        const parent_addr = self_addr - offset;
        return @as(*T, @ptrFromInt(parent_addr));
    }

    /// Cast const element to specific type (with type checking)
    pub fn asConst(self: *const Element, comptime T: type) !*const T {
        const expected_type = switch (T) {
            Paragraph => ElementType.PARAGRAPH,
            TextRun => ElementType.TEXT_RUN,
            Table => ElementType.TABLE,
            TableRow => ElementType.TABLE_ROW,
            TableCell => ElementType.TABLE_CELL,
            Image => ElementType.IMAGE,
            Hyperlink => ElementType.HYPERLINK,
            Field => ElementType.FIELD,
            List => ElementType.LIST,
            ListItem => ElementType.LIST_ITEM,
            else => @compileError("Unsupported element type: " ++ @typeName(T)),
        };

        if (self.type != expected_type) {
            return DocumentError.InvalidElementType;
        }
        
        // Perform the same calculation as in destroy but for const
        const offset = @offsetOf(T, "element");
        const self_addr = @intFromPtr(self);
        const parent_addr = self_addr - offset;
        return @as(*const T, @ptrFromInt(parent_addr));
    }
};

/// Container is a mixin that adds child element management capabilities
pub fn Container(comptime Self: type) type {
    return struct {
        /// Add an element to this container
        pub fn addElement(self: *Self, element: *Element) !void {
            try self.content.append(element);
            element.parent = &self.element;
        }

        /// Create and add a paragraph
        pub fn createParagraph(self: *Self, allocator: std.mem.Allocator) !*Paragraph {
            var paragraph = try allocator.create(Paragraph);
            paragraph.* = Paragraph.init(allocator);
            try self.addElement(&paragraph.element);
            return paragraph;
        }

        /// Create and add a text run
        pub fn createTextRun(self: *Self, allocator: std.mem.Allocator, text: []const u8, style: Style) !*TextRun {
            var text_run = try allocator.create(TextRun);
            text_run.* = try TextRun.init(allocator, text, style);
            try self.addElement(&text_run.element);
            return text_run;
        }

        /// Create and add a hyperlink
        pub fn createHyperlink(self: *Self, allocator: std.mem.Allocator, url: []const u8) !*Hyperlink {
            var hyperlink = try allocator.create(Hyperlink);
            hyperlink.* = try Hyperlink.init(allocator, url);
            try self.addElement(&hyperlink.element);
            return hyperlink;
        }

        /// Create and add an image
        pub fn createImage(self: *Self, allocator: std.mem.Allocator, width: u16, height: u16, format: ImageFormat, data: []const u8) !*Image {
            var image = try allocator.create(Image);
            image.* = try Image.init(allocator, width, height, format, data);
            try self.addElement(&image.element);
            return image;
        }

        /// Create and add a field
        pub fn createField(self: *Self, allocator: std.mem.Allocator, field_type: FieldType, instructions: []const u8) !*Field {
            var field = try allocator.create(Field);
            field.* = try Field.init(allocator, field_type, instructions);
            try self.addElement(&field.element);
            return field;
        }

        /// Remove an element (without destroying it)
        pub fn removeElement(self: *Self, element: *Element) !void {
            // Verify this element is a child of this container
            if (element.parent != &self.element) {
                return DocumentError.InvalidParent;
            }

            // Find and remove the element
            for (self.content.items, 0..) |item, i| {
                if (item == element) {
                    _ = self.content.orderedRemove(i);
                    element.parent = null;
                    return;
                }
            }

            return DocumentError.ElementMismatch;
        }
    };
}

/// Alignment options for paragraphs
pub const Alignment = enum {
    left,
    center,
    right,
    justified,
};

/// Border styling properties
pub const BorderProperties = struct {
    top: bool = false,
    right: bool = false,
    bottom: bool = false,
    left: bool = false,
    width: u8 = 1, // in points
    color: ?u16 = null,

    /// Set all borders at once
    pub fn setAll(self: *BorderProperties, enabled: bool) void {
        self.top = enabled;
        self.right = enabled;
        self.bottom = enabled;
        self.left = enabled;
    }
};

/// Shading properties for paragraphs or cells
pub const ShadingProperties = struct {
    foreground_color: ?u16 = null,
    background_color: ?u16 = null,
    pattern: u8 = 0, // 0-100 percentage
};

/// Properties that apply to a paragraph
pub const ParagraphProperties = struct {
    // Alignment
    alignment: Alignment = .left,
    
    // Spacing
    space_before: ?u16 = null, // In points * 20
    space_after: ?u16 = null, // In points * 20
    line_spacing: ?u16 = null, // In points * 20
    
    // Indentation
    first_line_indent: ?i16 = null, // In twips
    left_indent: ?i16 = null, // In twips
    right_indent: ?i16 = null, // In twips
    
    // Borders and shading
    border: BorderProperties = .{},
    shading: ShadingProperties = .{},
    
    // List formatting
    list_level: ?u8 = null,
    list_id: ?u16 = null,

    /// Create a copy of these properties
    pub fn clone(self: ParagraphProperties) ParagraphProperties {
        return .{
            .alignment = self.alignment,
            .space_before = self.space_before,
            .space_after = self.space_after,
            .line_spacing = self.line_spacing,
            .first_line_indent = self.first_line_indent,
            .left_indent = self.left_indent,
            .right_indent = self.right_indent,
            .border = self.border,
            .shading = self.shading,
            .list_level = self.list_level,
            .list_id = self.list_id,
        };
    }

    /// Reset properties to defaults
    pub fn reset(self: *ParagraphProperties) void {
        self.* = .{};
    }

    /// Set indentation values in convenient points (converted to twips)
    pub fn setIndents(self: *ParagraphProperties, first_line: ?i16, left: ?i16, right: ?i16) void {
        if (first_line) |val| self.first_line_indent = val * 20;
        if (left) |val| self.left_indent = val * 20;
        if (right) |val| self.right_indent = val * 20;
    }
};

/// A paragraph element that can contain text runs and other inline elements
pub const Paragraph = struct {
    element: Element,
    properties: ParagraphProperties,
    content: std.ArrayList(*Element),
    
    pub fn init(allocator: std.mem.Allocator) Paragraph {
        return .{
            .element = .{ .type = .PARAGRAPH },
            .properties = ParagraphProperties{},
            .content = std.ArrayList(*Element).init(allocator),
        };
    }
    
    pub fn deinit(self: *Paragraph, allocator: std.mem.Allocator) void {
        for (self.content.items) |element| {
            element.destroy(allocator);
        }
        self.content.deinit();
    }

    /// Apply a set of properties to this paragraph
    pub fn applyProperties(self: *Paragraph, props: ParagraphProperties) void {
        self.properties = props.clone();
    }

    /// Reset this paragraph's properties to defaults
    pub fn resetProperties(self: *Paragraph) void {
        self.properties.reset();
    }

    // Implement container functionality
    pub usingnamespace Container(Paragraph);
};

/// A text run is a span of text with consistent styling
pub const TextRun = struct {
    element: Element,
    text: []const u8,
    style: Style,
    owns_text: bool, // Track whether we own the text memory
    
    /// Initialize a text run with a copy of the provided text
    /// This is the preferred initialization method as it ensures the text run
    /// manages its own memory independent of the source
    pub fn init(allocator: std.mem.Allocator, text: []const u8, style: Style) !TextRun {
        const text_copy = try allocator.dupe(u8, text);
        
        return .{
            .element = .{ .type = .TEXT_RUN },
            .text = text_copy,
            .style = style,
            .owns_text = true, // We own this memory and must free it
        };
    }
    
    /// Initialize with a reference to existing text
    /// CAUTION: The caller is responsible for ensuring the text remains valid
    /// for the lifetime of the TextRun
    pub fn initReference(text: []const u8, style: Style) TextRun {
        return .{
            .element = .{ .type = .TEXT_RUN },
            .text = text,
            .style = style,
            .owns_text = false, // We don't own this memory
        };
    }
    
    pub fn deinit(self: *TextRun, allocator: std.mem.Allocator) void {
        if (self.owns_text) {
            allocator.free(self.text);
        }
    }

    /// Update the text content (deallocates old text if owned)
    pub fn setText(self: *TextRun, allocator: std.mem.Allocator, text: []const u8) !void {
        if (self.owns_text) {
            allocator.free(self.text);
        }
        
        const text_copy = try allocator.dupe(u8, text);
        self.text = text_copy;
        self.owns_text = true;
    }

    /// Apply additional styling to this text run
    pub fn applyStyle(self: *TextRun, additional_style: Style) void {
        self.style = Style.merge(self.style, additional_style);
    }
};

/// Image data embedded in the document
pub const ImageData = struct {
    width: u16,
    height: u16,
    format: ImageFormat,
    data: []const u8,
};

/// Supported image formats
pub const ImageFormat = enum {
    BMP,
    WMF,
    EMF,
    JPEG,
    PNG,
    OTHER,
};

/// An image element
pub const Image = struct {
    element: Element,
    image_data: ImageData,
    
    pub fn init(allocator: std.mem.Allocator, width: u16, height: u16, format: ImageFormat, data: []const u8) !Image {
        const data_copy = try allocator.dupe(u8, data);
        
        return .{
            .element = .{ .type = .IMAGE },
            .image_data = .{
                .width = width,
                .height = height,
                .format = format,
                .data = data_copy,
            },
        };
    }
    
    pub fn deinit(self: *Image, allocator: std.mem.Allocator) void {
        allocator.free(self.image_data.data);
    }

    /// Replace the image data with new data
    pub fn updateImageData(self: *Image, allocator: std.mem.Allocator, width: u16, height: u16, format: ImageFormat, data: []const u8) !void {
        // Free the old data
        allocator.free(self.image_data.data);
        
        // Copy the new data
        const data_copy = try allocator.dupe(u8, data);
        
        // Update the image data
        self.image_data = .{
            .width = width,
            .height = height,
            .format = format,
            .data = data_copy,
        };
    }
};

/// A hyperlink element
pub const Hyperlink = struct {
    element: Element,
    url: []const u8,
    content: std.ArrayList(*Element),
    
    pub fn init(allocator: std.mem.Allocator, url: []const u8) !Hyperlink {
        const url_copy = try allocator.dupe(u8, url);
        
        return .{
            .element = .{ .type = .HYPERLINK },
            .url = url_copy,
            .content = std.ArrayList(*Element).init(allocator),
        };
    }
    
    pub fn deinit(self: *Hyperlink, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        
        for (self.content.items) |element| {
            element.destroy(allocator);
        }
        self.content.deinit();
    }

    /// Update the URL
    pub fn setUrl(self: *Hyperlink, allocator: std.mem.Allocator, url: []const u8) !void {
        allocator.free(self.url);
        self.url = try allocator.dupe(u8, url);
    }

    // Implement container functionality
    pub usingnamespace Container(Hyperlink);
};

/// Field types that can be embedded in RTF
pub const FieldType = enum {
    DATE,
    TIME,
    PAGE,
    NUMPAGES,
    AUTHOR,
    TITLE,
    SUBJECT,
    HYPERLINK,
    OTHER,
};

/// A field element for dynamic content
pub const Field = struct {
    element: Element,
    field_type: FieldType,
    instructions: []const u8,
    result: ?[]const u8,
    
    pub fn init(allocator: std.mem.Allocator, field_type: FieldType, instructions: []const u8) !Field {
        const instr_copy = try allocator.dupe(u8, instructions);
        
        return .{
            .element = .{ .type = .FIELD },
            .field_type = field_type,
            .instructions = instr_copy,
            .result = null,
        };
    }
    
    pub fn deinit(self: *Field, allocator: std.mem.Allocator) void {
        allocator.free(self.instructions);
        if (self.result) |result| {
            allocator.free(result);
        }
    }
    
    pub fn setResult(self: *Field, allocator: std.mem.Allocator, result: []const u8) !void {
        if (self.result) |old_result| {
            allocator.free(old_result);
        }
        
        self.result = try allocator.dupe(u8, result);
    }

    /// Update the field instructions
    pub fn setInstructions(self: *Field, allocator: std.mem.Allocator, instructions: []const u8) !void {
        allocator.free(self.instructions);
        self.instructions = try allocator.dupe(u8, instructions);
    }
};

/// A table element that contains rows
pub const Table = struct {
    element: Element,
    rows: std.ArrayList(*TableRow),
    
    pub fn init(allocator: std.mem.Allocator) Table {
        return .{
            .element = .{ .type = .TABLE },
            .rows = std.ArrayList(*TableRow).init(allocator),
        };
    }
    
    pub fn deinit(self: *Table, allocator: std.mem.Allocator) void {
        for (self.rows.items) |row| {
            row.element.destroy(allocator);
        }
        self.rows.deinit();
    }
    
    pub fn addRow(self: *Table, row: *TableRow) !void {
        try self.rows.append(row);
        row.element.parent = &self.element;
    }
    
    pub fn createRow(self: *Table, allocator: std.mem.Allocator) !*TableRow {
        const row = try allocator.create(TableRow);
        row.* = TableRow.init(allocator);
        try self.addRow(row);
        return row;
    }

    /// Create a simple table with the specified dimensions
    pub fn createSimpleTable(allocator: std.mem.Allocator, rows: usize, cols: usize) !*Table {
        var table = try allocator.create(Table);
        table.* = Table.init(allocator);

        // Create the rows and cells
        for (0..rows) |_| {
            const row = try table.createRow(allocator);
            
            for (0..cols) |_| {
                _ = try row.createCell(allocator);
            }
        }

        return table;
    }

    /// Remove a row (without destroying it)
    pub fn removeRow(self: *Table, row: *TableRow) !void {
        // Verify this row is a child of this table
        if (row.element.parent != &self.element) {
            return DocumentError.InvalidParent;
        }

        // Find and remove the row
        for (self.rows.items, 0..) |item, i| {
            if (item == row) {
                _ = self.rows.orderedRemove(i);
                row.element.parent = null;
                return;
            }
        }

        return DocumentError.ElementMismatch;
    }
};

/// A table row that contains cells
pub const TableRow = struct {
    element: Element,
    cells: std.ArrayList(*TableCell),
    
    pub fn init(allocator: std.mem.Allocator) TableRow {
        return .{
            .element = .{ .type = .TABLE_ROW },
            .cells = std.ArrayList(*TableCell).init(allocator),
        };
    }
    
    pub fn deinit(self: *TableRow, allocator: std.mem.Allocator) void {
        for (self.cells.items) |cell| {
            cell.element.destroy(allocator);
        }
        self.cells.deinit();
    }
    
    pub fn addCell(self: *TableRow, cell: *TableCell) !void {
        try self.cells.append(cell);
        cell.element.parent = &self.element;
    }
    
    pub fn createCell(self: *TableRow, allocator: std.mem.Allocator) !*TableCell {
        const cell = try allocator.create(TableCell);
        cell.* = TableCell.init(allocator);
        try self.addCell(cell);
        return cell;
    }

    /// Remove a cell (without destroying it)
    pub fn removeCell(self: *TableRow, cell: *TableCell) !void {
        // Verify this cell is a child of this row
        if (cell.element.parent != &self.element) {
            return DocumentError.InvalidParent;
        }

        // Find and remove the cell
        for (self.cells.items, 0..) |item, i| {
            if (item == cell) {
                _ = self.cells.orderedRemove(i);
                cell.element.parent = null;
                return;
            }
        }

        return DocumentError.ElementMismatch;
    }
};

/// A table cell that contains paragraphs
pub const TableCell = struct {
    element: Element,
    content: std.ArrayList(*Element),
    width: ?u16 = null,
    row_span: u8 = 1,
    col_span: u8 = 1,
    border: BorderProperties = .{},
    shading: ShadingProperties = .{},
    vertical_alignment: VerticalAlignment = .top,
    
    pub fn init(allocator: std.mem.Allocator) TableCell {
        return .{
            .element = .{ .type = .TABLE_CELL },
            .content = std.ArrayList(*Element).init(allocator),
        };
    }
    
    pub fn deinit(self: *TableCell, allocator: std.mem.Allocator) void {
        for (self.content.items) |element| {
            element.destroy(allocator);
        }
        self.content.deinit();
    }

    /// Set all cell borders at once
    pub fn setBorders(self: *TableCell, enabled: bool) void {
        self.border.setAll(enabled);
    }

    /// Set cell background color
    pub fn setBackgroundColor(self: *TableCell, color_index: u16) void {
        self.shading.background_color = color_index;
    }

    // Implement container functionality
    pub usingnamespace Container(TableCell);
};

/// Vertical alignment options for table cells
pub const VerticalAlignment = enum {
    top,
    center,
    bottom,
};

/// List types (bullet, number, etc.)
pub const ListType = enum {
    BULLET,
    NUMBERED,
    LETTERED,
    ROMAN,
    CUSTOM,
};

/// A list element that contains list items
pub const List = struct {
    element: Element,
    list_type: ListType,
    items: std.ArrayList(*ListItem),
    
    pub fn init(allocator: std.mem.Allocator, list_type: ListType) List {
        return .{
            .element = .{ .type = .LIST },
            .list_type = list_type,
            .items = std.ArrayList(*ListItem).init(allocator),
        };
    }
    
    pub fn deinit(self: *List, allocator: std.mem.Allocator) void {
        for (self.items.items) |item| {
            item.element.destroy(allocator);
        }
        self.items.deinit();
    }
    
    pub fn addItem(self: *List, item: *ListItem) !void {
        try self.items.append(item);
        item.element.parent = &self.element;
    }
    
    pub fn createItem(self: *List, allocator: std.mem.Allocator) !*ListItem {
        const item = try allocator.create(ListItem);
        item.* = ListItem.init(allocator);
        try self.addItem(item);
        return item;
    }
};

/// A list item element
pub const ListItem = struct {
    element: Element,
    content: std.ArrayList(*Element),
    level: u8 = 1,
    
    pub fn init(allocator: std.mem.Allocator) ListItem {
        return .{
            .element = .{ .type = .LIST_ITEM },
            .content = std.ArrayList(*Element).init(allocator),
        };
    }
    
    pub fn deinit(self: *ListItem, allocator: std.mem.Allocator) void {
        for (self.content.items) |element| {
            element.destroy(allocator);
        }
        self.content.deinit();
    }

    // Implement container functionality
    pub usingnamespace Container(ListItem);
};

/// Document metadata (title, author, etc.)
pub const DocumentMetadata = struct {
    title: ?[]const u8 = null,
    author: ?[]const u8 = null,
    company: ?[]const u8 = null,
    subject: ?[]const u8 = null,
    keywords: ?[]const u8 = null,
    comment: ?[]const u8 = null,
    creation_time: ?i64 = null,
    revision_time: ?i64 = null,
    
    pub fn deinit(self: *DocumentMetadata, allocator: std.mem.Allocator) void {
        if (self.title) |title| allocator.free(title);
        if (self.author) |author| allocator.free(author);
        if (self.company) |company| allocator.free(company);
        if (self.subject) |subject| allocator.free(subject);
        if (self.keywords) |keywords| allocator.free(keywords);
        if (self.comment) |comment| allocator.free(comment);
    }
    
    pub fn setTitle(self: *DocumentMetadata, allocator: std.mem.Allocator, title: []const u8) !void {
        if (self.title) |old_title| allocator.free(old_title);
        self.title = try allocator.dupe(u8, title);
    }
    
    pub fn setAuthor(self: *DocumentMetadata, allocator: std.mem.Allocator, author: []const u8) !void {
        if (self.author) |old_author| allocator.free(old_author);
        self.author = try allocator.dupe(u8, author);
    }
    
    pub fn setCompany(self: *DocumentMetadata, allocator: std.mem.Allocator, company: []const u8) !void {
        if (self.company) |old_company| allocator.free(old_company);
        self.company = try allocator.dupe(u8, company);
    }
    
    pub fn setSubject(self: *DocumentMetadata, allocator: std.mem.Allocator, subject: []const u8) !void {
        if (self.subject) |old_subject| allocator.free(old_subject);
        self.subject = try allocator.dupe(u8, subject);
    }
    
    pub fn setKeywords(self: *DocumentMetadata, allocator: std.mem.Allocator, keywords: []const u8) !void {
        if (self.keywords) |old_keywords| allocator.free(old_keywords);
        self.keywords = try allocator.dupe(u8, keywords);
    }
    
    pub fn setComment(self: *DocumentMetadata, allocator: std.mem.Allocator, comment: []const u8) !void {
        if (self.comment) |old_comment| allocator.free(old_comment);
        self.comment = try allocator.dupe(u8, comment);
    }
};

/// The main document structure that contains all elements
pub const Document = struct {
    allocator: std.mem.Allocator,
    metadata: DocumentMetadata,
    content: std.ArrayList(*Element),
    
    pub fn init(allocator: std.mem.Allocator) Document {
        return .{
            .allocator = allocator,
            .metadata = DocumentMetadata{},
            .content = std.ArrayList(*Element).init(allocator),
        };
    }
    
    pub fn deinit(self: *Document) void {
        self.metadata.deinit(self.allocator);
        
        for (self.content.items) |element| {
            element.destroy(self.allocator);
        }
        self.content.deinit();
    }
    
    pub fn addElement(self: *Document, element: *Element) !void {
        try self.content.append(element);
        element.parent = null; // Document elements have no parent
    }
    
    /// Create and add a paragraph
    pub fn createParagraph(self: *Document) !*Paragraph {
        var paragraph = try self.allocator.create(Paragraph);
        paragraph.* = Paragraph.init(self.allocator);
        try self.addElement(&paragraph.element);
        return paragraph;
    }
    
    /// Create and add a table
    pub fn createTable(self: *Document) !*Table {
        var table = try self.allocator.create(Table);
        table.* = Table.init(self.allocator);
        try self.addElement(&table.element);
        return table;
    }

    /// Create and add a list
    pub fn createList(self: *Document, list_type: ListType) !*List {
        var list = try self.allocator.create(List);
        list.* = List.init(self.allocator, list_type);
        try self.addElement(&list.element);
        return list;
    }

    /// Create a paragraph with text
    pub fn createParagraphWithText(self: *Document, text: []const u8, style: Style) !*Paragraph {
        var paragraph = try self.createParagraph();
        _ = try paragraph.createTextRun(self.allocator, text, style);
        return paragraph;
    }

    /// Remove an element (without destroying it)
    pub fn removeElement(self: *Document, element: *Element) !void {
        // Find and remove the element
        for (self.content.items, 0..) |item, i| {
            if (item == element) {
                _ = self.content.orderedRemove(i);
                element.parent = null;
                return;
            }
        }

        return DocumentError.ElementMismatch;
    }

    /// Convert the document to plain text
    pub fn toPlainText(self: *const Document, writer: anytype) !void {
        for (self.content.items) |element| {
            try self.elementToPlainText(element, writer, 0);
        }
    }
    
    /// Convert a specific element to plain text
    fn elementToPlainText(self: *const Document, element: *const Element, writer: anytype, indent: usize) !void {
        switch (element.type) {
            .PARAGRAPH => {
                const paragraph = try element.asConst(Paragraph);
                
                // Add indentation
                for (0..indent) |_| {
                    try writer.writeByte(' ');
                }
                
                // Write paragraph content
                for (paragraph.content.items) |child| {
                    try self.elementToPlainText(child, writer, 0);
                }
                
                // Add paragraph break
                try writer.writeByte('\n');
            },
            .TEXT_RUN => {
                const text_run = try element.asConst(TextRun);
                try writer.writeAll(text_run.text);
            },
            .TABLE => {
                const table = try element.asConst(Table);
                try writer.writeByte('\n');
                
                for (table.rows.items) |row| {
                    try self.elementToPlainText(&row.element, writer, indent);
                }
                
                try writer.writeByte('\n');
            },
            .TABLE_ROW => {
                const row = try element.asConst(TableRow);
                
                // Add row separator
                try writer.writeByte('|');
                
                for (row.cells.items) |cell| {
                    try self.elementToPlainText(&cell.element, writer, indent);
                    try writer.writeByte('|');
                }
                
                try writer.writeByte('\n');
            },
            .TABLE_CELL => {
                const cell = try element.asConst(TableCell);
                
                // Write cell content
                for (cell.content.items) |child| {
                    try self.elementToPlainText(child, writer, indent + 2);
                }
            },
            .IMAGE => {
                try writer.writeAll("[IMAGE]");
            },
            .HYPERLINK => {
                const hyperlink = try element.asConst(Hyperlink);
                
                try writer.writeByte('[');
                
                // Write hyperlink content
                for (hyperlink.content.items) |child| {
                    try self.elementToPlainText(child, writer, 0);
                }
                
                try writer.writeAll("](");
                try writer.writeAll(hyperlink.url);
                try writer.writeByte(')');
            },
            .FIELD => {
                const field = try element.asConst(Field);
                
                if (field.result) |result| {
                    try writer.writeAll(result);
                } else {
                    try writer.writeAll("[FIELD]");
                }
            },
            .LIST => {
                const list = try element.asConst(List);
                try writer.writeByte('\n');
                
                for (list.items.items) |item| {
                    try self.elementToPlainText(&item.element, writer, indent);
                }
            },
            .LIST_ITEM => {
                const item = try element.asConst(ListItem);
                
                // Add indentation based on level
                for (0..indent + (item.level - 1) * 2) |_| {
                    try writer.writeByte(' ');
                }
                
                // Add bullet
                try writer.writeAll("• ");
                
                // Write item content
                for (item.content.items) |child| {
                    try self.elementToPlainText(child, writer, 0);
                }
                
                try writer.writeByte('\n');
            },
        }
    }
    
    /// Convert the document to HTML
    pub fn toHtml(self: *const Document, writer: anytype) !void {
        try writer.writeAll("<!DOCTYPE html>\n");
        try writer.writeAll("<html>\n<head>\n");
        try writer.writeAll("<meta charset=\"UTF-8\">\n");
        
        // Add metadata
        if (self.metadata.title) |title| {
            try writer.writeAll("<title>");
            try writer.writeAll(title);
            try writer.writeAll("</title>\n");
        }
        
        try writer.writeAll("<style>\n");
        try writer.writeAll("body { font-family: Arial, sans-serif; }\n");
        try writer.writeAll("table { border-collapse: collapse; width: 100%; }\n");
        try writer.writeAll("td, th { border: 1px solid #ddd; padding: 8px; }\n");
        try writer.writeAll("ul.bullet { list-style-type: disc; }\n");
        try writer.writeAll("ul.numbered { list-style-type: decimal; }\n");
        try writer.writeAll("ul.lettered { list-style-type: lower-alpha; }\n");
        try writer.writeAll("ul.roman { list-style-type: lower-roman; }\n");
        try writer.writeAll("</style>\n");
        
        try writer.writeAll("</head>\n<body>\n");
        
        // Write document content
        for (self.content.items) |element| {
            try self.elementToHtml(element, writer);
        }
        
        try writer.writeAll("</body>\n</html>");
    }
    
    /// Convert a specific element to HTML
    fn elementToHtml(self: *const Document, element: *const Element, writer: anytype) !void {
        switch (element.type) {
            .PARAGRAPH => {
                const paragraph = try element.asConst(Paragraph);
                
                try writer.writeAll("<p");
                
                // Add alignment if not default
                if (paragraph.properties.alignment != .left) {
                    try writer.writeAll(" style=\"text-align: ");
                    try writer.writeAll(@tagName(paragraph.properties.alignment));
                    try writer.writeAll(";\"");
                }
                
                try writer.writeAll(">");
                
                // Write paragraph content
                for (paragraph.content.items) |child| {
                    try self.elementToHtml(child, writer);
                }
                
                try writer.writeAll("</p>\n");
            },
            .TEXT_RUN => {
                const text_run = try element.asConst(TextRun);
                
                // Use semantic HTML tags for styling when possible
                var open_tags = std.ArrayList([]const u8).init(self.allocator);
                defer open_tags.deinit();
                
                // Apply styles with semantic HTML elements where appropriate
                if (text_run.style.bold) {
                    try writer.writeAll("<strong>");
                    try open_tags.append("</strong>");
                }
                
                if (text_run.style.italic) {
                    try writer.writeAll("<em>");
                    try open_tags.append("</em>");
                }
                
                if (text_run.style.underline) {
                    try writer.writeAll("<u>");
                    try open_tags.append("</u>");
                }
                
                if (text_run.style.strikethrough) {
                    try writer.writeAll("<s>");
                    try open_tags.append("</s>");
                }
                
                // Additional styles that need spans
                const needs_span = text_run.style.foreground_color != null or text_run.style.background_color != null;
                
                if (needs_span) {
                    try writer.writeAll("<span style=\"");
                    
                    var needs_separator = false;
                    
                    if (text_run.style.foreground_color) |color| {
                        try writer.print("color: #{x:0>6}", .{color});
                        needs_separator = true;
                    }
                    
                    if (text_run.style.background_color) |color| {
                        if (needs_separator) try writer.writeAll("; ");
                        try writer.print("background-color: #{x:0>6}", .{color});
                    }
                    
                    try writer.writeAll("\">");
                    try open_tags.append("</span>");
                }
                
                // Write the text (with HTML escaping)
                try self.writeEscapedHtml(writer, text_run.text);
                
                // Close tags in reverse order (LIFO)
                var i: usize = open_tags.items.len;
                while (i > 0) {
                    i -= 1;
                    try writer.writeAll(open_tags.items[i]);
                }
            },
            .TABLE => {
                const table = try element.asConst(Table);
                
                try writer.writeAll("<table>\n");
                
                for (table.rows.items) |row| {
                    try self.elementToHtml(&row.element, writer);
                }
                
                try writer.writeAll("</table>\n");
            },
            .TABLE_ROW => {
                const row = try element.asConst(TableRow);
                
                try writer.writeAll("<tr>\n");
                
                for (row.cells.items) |cell| {
                    try self.elementToHtml(&cell.element, writer);
                }
                
                try writer.writeAll("</tr>\n");
            },
            .TABLE_CELL => {
                const cell = try element.asConst(TableCell);
                
                try writer.writeAll("<td");
                
                // Add colspan and rowspan if needed
                if (cell.col_span > 1) {
                    try writer.print(" colspan=\"{d}\"", .{cell.col_span});
                }
                if (cell.row_span > 1) {
                    try writer.print(" rowspan=\"{d}\"", .{cell.row_span});
                }
                
                // Add style if needed
                if (cell.shading.background_color != null) {
                    try writer.writeAll(" style=\"");
                    if (cell.shading.background_color) |color| {
                        try writer.print("background-color: #{x:0>6}", .{color});
                    }
                    try writer.writeAll("\"");
                }
                
                try writer.writeAll(">\n");
                
                // Write cell content
                for (cell.content.items) |child| {
                    try self.elementToHtml(child, writer);
                }
                
                try writer.writeAll("</td>\n");
            },
            .IMAGE => {
                const image = try element.asConst(Image);
                
                // In a real implementation, we would encode the image data
                // or save it to a file and reference it
                try writer.print("<img alt=\"Image\" width=\"{d}\" height=\"{d}\" />", 
                    .{image.image_data.width, image.image_data.height});
            },
            .HYPERLINK => {
                const hyperlink = try element.asConst(Hyperlink);
                
                try writer.writeAll("<a href=\"");
                try self.writeEscapedHtml(writer, hyperlink.url);
                try writer.writeAll("\">");
                
                // Write hyperlink content
                for (hyperlink.content.items) |child| {
                    try self.elementToHtml(child, writer);
                }
                
                try writer.writeAll("</a>");
            },
            .FIELD => {
                const field = try element.asConst(Field);
                
                if (field.result) |result| {
                    try self.writeEscapedHtml(writer, result);
                } else {
                    try writer.writeAll("<span class=\"field\">[FIELD]</span>");
                }
            },
            .LIST => {
                const list = try element.asConst(List);
                
                // Determine list type
                const list_class = switch (list.list_type) {
                    .BULLET => "bullet",
                    .NUMBERED => "numbered",
                    .LETTERED => "lettered",
                    .ROMAN => "roman",
                    .CUSTOM => "custom",
                };
                
                try writer.print("<ul class=\"{s}\">\n", .{list_class});
                
                for (list.items.items) |item| {
                    try self.elementToHtml(&item.element, writer);
                }
                
                try writer.writeAll("</ul>\n");
            },
            .LIST_ITEM => {
                const item = try element.asConst(ListItem);
                
                // Add style for nesting if needed
                if (item.level > 1) {
                    try writer.print("<li style=\"margin-left: {d}em\">", .{(item.level - 1) * 2});
                } else {
                    try writer.writeAll("<li>");
                }
                
                // Write item content
                for (item.content.items) |child| {
                    try self.elementToHtml(child, writer);
                }
                
                try writer.writeAll("</li>\n");
            },
        }
    }
    
    /// Write HTML-escaped text
    fn writeEscapedHtml(self: *const Document, writer: anytype, text: []const u8) !void {
        _ = self; // Unused
        
        for (text) |c| {
            switch (c) {
                '&' => try writer.writeAll("&amp;"),
                '<' => try writer.writeAll("&lt;"),
                '>' => try writer.writeAll("&gt;"),
                '"' => try writer.writeAll("&quot;"),
                '\'' => try writer.writeAll("&#39;"),
                else => try writer.writeByte(c),
            }
        }
    }

    /// Find an element by path
    pub fn findElement(self: *Document, path: []const usize) !?*Element {
        if (path.len == 0) return null;
        
        if (path[0] >= self.content.items.len) return null;
        
        var element = self.content.items[path[0]];
        
        for (path[1..]) |index| {
            // Navigate based on element type
            switch (element.type) {
                .PARAGRAPH => {
                    const paragraph = try element.as(Paragraph);
                    if (index >= paragraph.content.items.len) return null;
                    element = paragraph.content.items[index];
                },
                .TABLE => {
                    const table = try element.as(Table);
                    if (index >= table.rows.items.len) return null;
                    element = &table.rows.items[index].element;
                },
                .TABLE_ROW => {
                    const row = try element.as(TableRow);
                    if (index >= row.cells.items.len) return null;
                    element = &row.cells.items[index].element;
                },
                .TABLE_CELL => {
                    const cell = try element.as(TableCell);
                    if (index >= cell.content.items.len) return null;
                    element = cell.content.items[index];
                },
                .HYPERLINK => {
                    const hyperlink = try element.as(Hyperlink);
                    if (index >= hyperlink.content.items.len) return null;
                    element = hyperlink.content.items[index];
                },
                .LIST => {
                    const list = try element.as(List);
                    if (index >= list.items.items.len) return null;
                    element = &list.items.items[index].element;
                },
                .LIST_ITEM => {
                    const item = try element.as(ListItem);
                    if (index >= item.content.items.len) return null;
                    element = item.content.items[index];
                },
                else => return null, // Element doesn't support children
            }
        }
        
        return element;
    }

    /// Create a document from plain text
    pub fn createFromPlainText(allocator: std.mem.Allocator, text: []const u8) !Document {
        var document = Document.init(allocator);
        var current_paragraph: ?*Paragraph = null;
        
        var lines = std.mem.splitSequence(u8, text, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            
            if (trimmed.len == 0) {
                // Empty line: start a new paragraph for the next non-empty line
                current_paragraph = null;
                continue;
            }
            
            // Create a new paragraph if needed
            if (current_paragraph == null) {
                current_paragraph = try document.createParagraph();
            }
            
            // Add the line as a text run
            const default_style = Style{};
            _ = try current_paragraph.?.createTextRun(allocator, trimmed, default_style);
        }
        
        return document;
    }
};