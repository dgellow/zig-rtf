const std = @import("std");
const Style = @import("parser.zig").Style;

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
};

/// Base element struct that all document elements inherit from
pub const Element = struct {
    type: ElementType,
    
    // Non-const helper functions to safely get parent pointer
    fn toParagraph(self: *Element) *Paragraph {
        // Calculate the offset of the 'element' field within Paragraph
        const offset = @offsetOf(Paragraph, "element");
        // Convert the self pointer to an address
        const self_addr = @intFromPtr(self);
        // Subtract the offset to get the address of the Paragraph
        const paragraph_addr = self_addr - offset;
        // Convert the address back to a pointer
        return @ptrFromInt(paragraph_addr);
    }
    
    fn toTextRun(self: *Element) *TextRun {
        const offset = @offsetOf(TextRun, "element");
        const self_addr = @intFromPtr(self);
        const text_run_addr = self_addr - offset;
        return @ptrFromInt(text_run_addr);
    }
    
    fn toTable(self: *Element) *Table {
        const offset = @offsetOf(Table, "element");
        const self_addr = @intFromPtr(self);
        const table_addr = self_addr - offset;
        return @ptrFromInt(table_addr);
    }
    
    fn toTableRow(self: *Element) *TableRow {
        const offset = @offsetOf(TableRow, "element");
        const self_addr = @intFromPtr(self);
        const row_addr = self_addr - offset;
        return @ptrFromInt(row_addr);
    }
    
    fn toTableCell(self: *Element) *TableCell {
        const offset = @offsetOf(TableCell, "element");
        const self_addr = @intFromPtr(self);
        const cell_addr = self_addr - offset;
        return @ptrFromInt(cell_addr);
    }
    
    fn toImage(self: *Element) *Image {
        const offset = @offsetOf(Image, "element");
        const self_addr = @intFromPtr(self);
        const image_addr = self_addr - offset;
        return @ptrFromInt(image_addr);
    }
    
    fn toHyperlink(self: *Element) *Hyperlink {
        const offset = @offsetOf(Hyperlink, "element");
        const self_addr = @intFromPtr(self);
        const hyperlink_addr = self_addr - offset;
        return @ptrFromInt(hyperlink_addr);
    }
    
    fn toField(self: *Element) *Field {
        const offset = @offsetOf(Field, "element");
        const self_addr = @intFromPtr(self);
        const field_addr = self_addr - offset;
        return @ptrFromInt(field_addr);
    }
    
    // Const helper functions to safely get parent pointer
    fn toParagraphConst(self: *const Element) *const Paragraph {
        const offset = @offsetOf(Paragraph, "element");
        const self_addr = @intFromPtr(self);
        const paragraph_addr = self_addr - offset;
        return @ptrFromInt(paragraph_addr);
    }
    
    fn toTextRunConst(self: *const Element) *const TextRun {
        const offset = @offsetOf(TextRun, "element");
        const self_addr = @intFromPtr(self);
        const text_run_addr = self_addr - offset;
        return @ptrFromInt(text_run_addr);
    }
    
    fn toTableConst(self: *const Element) *const Table {
        const offset = @offsetOf(Table, "element");
        const self_addr = @intFromPtr(self);
        const table_addr = self_addr - offset;
        return @ptrFromInt(table_addr);
    }
    
    fn toTableRowConst(self: *const Element) *const TableRow {
        const offset = @offsetOf(TableRow, "element");
        const self_addr = @intFromPtr(self);
        const row_addr = self_addr - offset;
        return @ptrFromInt(row_addr);
    }
    
    fn toTableCellConst(self: *const Element) *const TableCell {
        const offset = @offsetOf(TableCell, "element");
        const self_addr = @intFromPtr(self);
        const cell_addr = self_addr - offset;
        return @ptrFromInt(cell_addr);
    }
    
    fn toImageConst(self: *const Element) *const Image {
        const offset = @offsetOf(Image, "element");
        const self_addr = @intFromPtr(self);
        const image_addr = self_addr - offset;
        return @ptrFromInt(image_addr);
    }
    
    fn toHyperlinkConst(self: *const Element) *const Hyperlink {
        const offset = @offsetOf(Hyperlink, "element");
        const self_addr = @intFromPtr(self);
        const hyperlink_addr = self_addr - offset;
        return @ptrFromInt(hyperlink_addr);
    }
    
    fn toFieldConst(self: *const Element) *const Field {
        const offset = @offsetOf(Field, "element");
        const self_addr = @intFromPtr(self);
        const field_addr = self_addr - offset;
        return @ptrFromInt(field_addr);
    }
    
    // Common methods
    pub fn destroy(self: *Element, allocator: std.mem.Allocator) void {
        switch (self.type) {
            .PARAGRAPH => {
                const paragraph = self.toParagraph();
                paragraph.deinit(allocator);
                allocator.destroy(paragraph);
            },
            .TEXT_RUN => {
                const text_run = self.toTextRun();
                text_run.deinit(allocator);
                allocator.destroy(text_run);
            },
            .TABLE => {
                const table = self.toTable();
                table.deinit(allocator);
                allocator.destroy(table);
            },
            .TABLE_ROW => {
                const row = self.toTableRow();
                row.deinit(allocator);
                allocator.destroy(row);
            },
            .TABLE_CELL => {
                const cell = self.toTableCell();
                cell.deinit(allocator);
                allocator.destroy(cell);
            },
            .IMAGE => {
                const image = self.toImage();
                image.deinit(allocator);
                allocator.destroy(image);
            },
            .HYPERLINK => {
                const hyperlink = self.toHyperlink();
                hyperlink.deinit(allocator);
                allocator.destroy(hyperlink);
            },
            .FIELD => {
                const field = self.toField();
                field.deinit(allocator);
                allocator.destroy(field);
            },
        }
    }
};

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
    
    pub fn addElement(self: *Paragraph, element: *Element) !void {
        try self.content.append(element);
    }
    
    pub fn createTextRun(self: *Paragraph, allocator: std.mem.Allocator, text: []const u8, style: Style) !void {
        var text_run = try allocator.create(TextRun);
        text_run.* = try TextRun.init(allocator, text, style);
        try self.addElement(&text_run.element);
    }
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
    
    pub fn addElement(self: *Hyperlink, element: *Element) !void {
        try self.content.append(element);
    }
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
    }
    
    pub fn createRow(self: *Table, allocator: std.mem.Allocator) !*TableRow {
        const row = try allocator.create(TableRow);
        row.* = TableRow.init(allocator);
        try self.rows.append(row);
        return row;
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
    }
    
    pub fn createCell(self: *TableRow, allocator: std.mem.Allocator) !*TableCell {
        const cell = try allocator.create(TableCell);
        cell.* = TableCell.init(allocator);
        try self.cells.append(cell);
        return cell;
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
    
    pub fn addElement(self: *TableCell, element: *Element) !void {
        try self.content.append(element);
    }
    
    pub fn createParagraph(self: *TableCell, allocator: std.mem.Allocator) !*Paragraph {
        var paragraph = try allocator.create(Paragraph);
        paragraph.* = Paragraph.init(allocator);
        try self.content.append(&paragraph.element);
        return paragraph;
    }
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
    }
    
    pub fn createParagraph(self: *Document) !*Paragraph {
        var paragraph = try self.allocator.create(Paragraph);
        paragraph.* = Paragraph.init(self.allocator);
        try self.content.append(&paragraph.element);
        return paragraph;
    }
    
    pub fn createTable(self: *Document) !*Table {
        var table = try self.allocator.create(Table);
        table.* = Table.init(self.allocator);
        try self.content.append(&table.element);
        return table;
    }
    
    /// Convert the document to plain text
    pub fn toPlainText(self: *const Document, writer: anytype) !void {
        for (self.content.items) |element| {
            try self.elementToPlainText(@as(*const Element, element), writer, 0);
        }
    }
    
    /// Convert a specific element to plain text
    fn elementToPlainText(self: *const Document, element: *const Element, writer: anytype, indent: usize) !void {
        switch (element.type) {
            .PARAGRAPH => {
                const paragraph = element.toParagraphConst();
                
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
                const text_run = element.toTextRunConst();
                try writer.writeAll(text_run.text);
            },
            .TABLE => {
                const table = element.toTableConst();
                try writer.writeByte('\n');
                
                for (table.rows.items) |row| {
                    try self.elementToPlainText(&row.element, writer, indent);
                }
                
                try writer.writeByte('\n');
            },
            .TABLE_ROW => {
                const row = element.toTableRowConst();
                
                // Add row separator
                try writer.writeByte('|');
                
                for (row.cells.items) |cell| {
                    try self.elementToPlainText(&cell.element, writer, indent);
                    try writer.writeByte('|');
                }
                
                try writer.writeByte('\n');
            },
            .TABLE_CELL => {
                const cell = element.toTableCellConst();
                
                // Write cell content
                for (cell.content.items) |child| {
                    try self.elementToPlainText(child, writer, indent + 2);
                }
            },
            .IMAGE => {
                try writer.writeAll("[IMAGE]");
            },
            .HYPERLINK => {
                const hyperlink = element.toHyperlinkConst();
                
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
                const field = element.toFieldConst();
                
                if (field.result) |result| {
                    try writer.writeAll(result);
                } else {
                    try writer.writeAll("[FIELD]");
                }
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
        try writer.writeAll("</style>\n");
        
        try writer.writeAll("</head>\n<body>\n");
        
        // Write document content
        for (self.content.items) |element| {
            try self.elementToHtml(@as(*const Element, element), writer);
        }
        
        try writer.writeAll("</body>\n</html>");
    }
    
    /// Convert a specific element to HTML
    fn elementToHtml(self: *const Document, element: *const Element, writer: anytype) !void {
        switch (element.type) {
            .PARAGRAPH => {
                const paragraph = element.toParagraphConst();
                
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
                const text_run = element.toTextRunConst();
                
                // Add style open tags
                if (text_run.style.bold) try writer.writeAll("<strong>");
                if (text_run.style.italic) try writer.writeAll("<em>");
                if (text_run.style.underline) try writer.writeAll("<u>");
                if (text_run.style.strikethrough) try writer.writeAll("<s>");
                
                // Write the text (should escape HTML special chars in a real implementation)
                try writer.writeAll(text_run.text);
                
                // Add style close tags (in reverse order)
                if (text_run.style.strikethrough) try writer.writeAll("</s>");
                if (text_run.style.underline) try writer.writeAll("</u>");
                if (text_run.style.italic) try writer.writeAll("</em>");
                if (text_run.style.bold) try writer.writeAll("</strong>");
            },
            .TABLE => {
                const table = element.toTableConst();
                
                try writer.writeAll("<table>\n");
                
                for (table.rows.items) |row| {
                    try self.elementToHtml(&row.element, writer);
                }
                
                try writer.writeAll("</table>\n");
            },
            .TABLE_ROW => {
                const row = element.toTableRowConst();
                
                try writer.writeAll("<tr>\n");
                
                for (row.cells.items) |cell| {
                    try self.elementToHtml(&cell.element, writer);
                }
                
                try writer.writeAll("</tr>\n");
            },
            .TABLE_CELL => {
                const cell = element.toTableCellConst();
                
                try writer.writeAll("<td");
                
                // Add colspan and rowspan if needed
                if (cell.col_span > 1) {
                    try writer.print(" colspan=\"{d}\"", .{cell.col_span});
                }
                if (cell.row_span > 1) {
                    try writer.print(" rowspan=\"{d}\"", .{cell.row_span});
                }
                
                try writer.writeAll(">\n");
                
                // Write cell content
                for (cell.content.items) |child| {
                    try self.elementToHtml(child, writer);
                }
                
                try writer.writeAll("</td>\n");
            },
            .IMAGE => {
                const image = element.toImageConst();
                
                // In a real implementation, we would encode the image data
                // or save it to a file and reference it
                try writer.print("<img alt=\"Image\" width=\"{d}\" height=\"{d}\" />", 
                    .{image.image_data.width, image.image_data.height});
            },
            .HYPERLINK => {
                const hyperlink = element.toHyperlinkConst();
                
                try writer.writeAll("<a href=\"");
                try writer.writeAll(hyperlink.url);
                try writer.writeAll("\">");
                
                // Write hyperlink content
                for (hyperlink.content.items) |child| {
                    try self.elementToHtml(child, writer);
                }
                
                try writer.writeAll("</a>");
            },
            .FIELD => {
                const field = element.toFieldConst();
                
                if (field.result) |result| {
                    try writer.writeAll(result);
                } else {
                    try writer.writeAll("<span class=\"field\">[FIELD]</span>");
                }
            },
        }
    }
};