const std = @import("std");
const document = @import("document.zig");
const Document = document.Document;
const Paragraph = document.Paragraph;
const TextRun = document.TextRun;
const Table = document.Table;
const TableRow = document.TableRow;
const TableCell = document.TableCell;
const Image = document.Image;
const Hyperlink = document.Hyperlink;
const Field = document.Field;
const Element = document.Element;
const ParagraphProperties = document.ParagraphProperties;
const ImageData = document.ImageData;

const parser = @import("parser.zig");
const Style = parser.Style;
const EventHandler = parser.EventHandler;

/// The DocumentBuilder processes events from the parser and constructs
/// a Document object with a complete element hierarchy.
pub const DocumentBuilder = struct {
    allocator: std.mem.Allocator,
    document: ?*Document = null,
    current_paragraph: ?*Paragraph = null,
    current_table: ?*Table = null,
    current_row: ?*TableRow = null,
    current_cell: ?*TableCell = null,
    current_hyperlink: ?*Hyperlink = null,
    group_stack: std.ArrayList(GroupState),

    // Track the current state of the builder
    in_header: bool = false,
    in_footer: bool = false,
    in_footnote: bool = false,
    
    pub fn init(allocator: std.mem.Allocator) !DocumentBuilder {
        const document_ptr = try allocator.create(Document);
        document_ptr.* = Document.init(allocator);

        return .{
            .allocator = allocator,
            .document = document_ptr,
            .group_stack = std.ArrayList(GroupState).init(allocator),
        };
    }
    
    /// Detach and return the document, transferring ownership to the caller
    /// After calling this method, the builder will no longer own the document
    /// The caller is responsible for calling both deinit() and destroy() on the document
    pub fn detachDocument(self: *DocumentBuilder) ?*Document {
        const doc = self.document;
        self.document = null;
        return doc;
    }
    
    /// Cleanup resources used by the DocumentBuilder
    /// This deinitializes and frees the document object if still owned by the builder
    pub fn deinit(self: *DocumentBuilder) void {
        self.group_stack.deinit();
        
        // Clean up the document we allocated if we still own it
        if (self.document != null) {
            self.document.?.deinit();
            self.allocator.destroy(self.document.?);
        }
    }
    
    /// Convert the builder to an EventHandler for use with the parser
    pub fn handler(self: *DocumentBuilder) EventHandler {
        const Context = @TypeOf(self);

        // Group start callback
        const onGroupStartFn = struct {
            fn callback(ctx: *anyopaque) anyerror!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onGroupStart();
            }
        }.callback;

        // Group end callback
        const onGroupEndFn = struct {
            fn callback(ctx: *anyopaque) anyerror!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onGroupEnd();
            }
        }.callback;

        // Text callback
        const onTextFn = struct {
            fn callback(ctx: *anyopaque, text: []const u8, style: Style) anyerror!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onText(text, style);
            }
        }.callback;

        // Character callback
        const onCharacterFn = struct {
            fn callback(ctx: *anyopaque, char: u8, style: Style) anyerror!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onCharacter(char, style);
            }
        }.callback;

        // Binary data callback
        const onBinaryFn = struct {
            fn callback(ctx: *anyopaque, data: []const u8, length: usize) anyerror!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onBinary(data, length);
            }
        }.callback;

        // Error callback
        const onErrorFn = struct {
            fn callback(ctx: *anyopaque, position: []const u8, message: []const u8) anyerror!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onError(position, message);
            }
        }.callback;

        return .{
            .context = self,
            .onGroupStart = onGroupStartFn,
            .onGroupEnd = onGroupEndFn,
            .onText = onTextFn,
            .onCharacter = onCharacterFn,
            .onBinary = onBinaryFn,
            .onError = onErrorFn,
        };
    }
    
    /// Called when a group starts in the RTF document
    fn onGroupStart(self: *DocumentBuilder) !void {
        // Save current state before entering a new group
        const state = GroupState{
            .current_paragraph = self.current_paragraph,
            .current_table = self.current_table,
            .current_row = self.current_row,
            .current_cell = self.current_cell,
            .current_hyperlink = self.current_hyperlink,
            .in_header = self.in_header,
            .in_footer = self.in_footer,
            .in_footnote = self.in_footnote,
        };
        
        try self.group_stack.append(state);
    }
    
    /// Called when a group ends in the RTF document
    fn onGroupEnd(self: *DocumentBuilder) !void {
        // Restore state when exiting a group
        if (self.group_stack.items.len > 0) {
            const state = self.group_stack.pop().?;
            self.current_paragraph = state.current_paragraph;
            self.current_table = state.current_table;
            self.current_row = state.current_row;
            self.current_cell = state.current_cell;
            self.current_hyperlink = state.current_hyperlink;
            self.in_header = state.in_header;
            self.in_footer = state.in_footer;
            self.in_footnote = state.in_footnote;
        }
    }
    
    /// Called when text is encountered in the RTF document
    fn onText(self: *DocumentBuilder, text: []const u8, style: Style) !void {
        // Ensure we have a paragraph to add text to
        if (self.current_paragraph == null) {
            // Create a new paragraph at the appropriate level
            if (self.current_cell) |cell| {
                self.current_paragraph = try cell.createParagraph(self.allocator);
            } else if (self.document) |doc| {
                self.current_paragraph = try doc.createParagraph();
            } else {
                return error.NoDocument;
            }
        }
        
        // Add the text as a text run to the current paragraph
        if (self.current_paragraph) |para| {
            // If we're in a hyperlink, add the text run to the hyperlink
            if (self.current_hyperlink) |hyperlink| {
                var text_run = try self.allocator.create(TextRun);
                text_run.* = try TextRun.init(self.allocator, text, style);
                try hyperlink.addElement(&text_run.element);
            } else {
                try para.createTextRun(self.allocator, text, style);
            }
        }
    }
    
    /// Called when a single character is encountered in the RTF document
    fn onCharacter(self: *DocumentBuilder, char: u8, style: Style) !void {
        // Convert the character to a string and handle it like text
        var buffer: [1]u8 = undefined;
        buffer[0] = char;
        try self.onText(buffer[0..], style);
    }
    
    /// Called when binary data is encountered in the RTF document
    fn onBinary(self: *DocumentBuilder, data: []const u8, length: usize) !void {
        // Ensure we have a paragraph to add the image to
        if (self.current_paragraph == null) {
            // Create a new paragraph at the appropriate level
            if (self.current_cell) |cell| {
                self.current_paragraph = try cell.createParagraph(self.allocator);
            } else if (self.document) |doc| {
                self.current_paragraph = try doc.createParagraph();
            } else {
                return error.NoDocument;
            }
        }
        
        // Create an image element and add it to the current paragraph
        var image = try self.allocator.create(Image);
        image.* = try Image.init(
            self.allocator,
            100, // Default width
            100, // Default height
            .OTHER, // Default format
            data[0..length]
        );
        
        // Add the image to the appropriate container
        if (self.current_paragraph) |para| {
            try para.addElement(&image.element);
        } else if (self.document) |doc| {
            try doc.addElement(&image.element);
        } else {
            // Can't add the image, clean it up
            image.deinit(self.allocator);
            self.allocator.destroy(image);
            return error.NoDocument;
        }
    }
    
    /// Called when an error is encountered during parsing
    fn onError(self: *DocumentBuilder, position: []const u8, message: []const u8) !void {
        // In a real implementation, we might log the error or add it to the document
        _ = self;
        _ = position;
        _ = message;
    }
    
    /// Creates a new table in the document
    pub fn createTable(self: *DocumentBuilder) !void {
        if (self.document) |doc| {
            self.current_table = try doc.createTable();
            self.current_row = null;
            self.current_cell = null;
        } else {
            return error.NoDocument;
        }
    }
    
    /// Creates a new row in the current table
    pub fn createRow(self: *DocumentBuilder) !void {
        if (self.current_table) |table| {
            self.current_row = try table.createRow(self.allocator);
            self.current_cell = null;
        }
    }
    
    /// Creates a new cell in the current row
    pub fn createCell(self: *DocumentBuilder) !void {
        if (self.current_row) |row| {
            self.current_cell = try row.createCell(self.allocator);
            self.current_paragraph = null;
        }
    }
    
    /// Creates a new hyperlink
    pub fn createHyperlink(self: *DocumentBuilder, url: []const u8) !void {
        // Ensure we have a paragraph to add the hyperlink to
        if (self.current_paragraph == null) {
            // Create a new paragraph at the appropriate level
            if (self.current_cell) |cell| {
                self.current_paragraph = try cell.createParagraph(self.allocator);
            } else if (self.document) |doc| {
                self.current_paragraph = try doc.createParagraph();
            } else {
                return error.NoDocument;
            }
        }
        
        // Create the hyperlink
        var hyperlink = try self.allocator.create(Hyperlink);
        hyperlink.* = try Hyperlink.init(self.allocator, url);
        
        // Add the hyperlink to the current paragraph
        if (self.current_paragraph) |para| {
            try para.addElement(&hyperlink.element);
        }
        
        // Set as the current hyperlink
        self.current_hyperlink = hyperlink;
    }
};

/// Tracks the state of the builder during group processing
const GroupState = struct {
    current_paragraph: ?*Paragraph,
    current_table: ?*Table,
    current_row: ?*TableRow,
    current_cell: ?*TableCell,
    current_hyperlink: ?*Hyperlink,
    in_header: bool,
    in_footer: bool,
    in_footnote: bool,
};