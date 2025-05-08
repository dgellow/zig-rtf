const std = @import("std");
const parser = @import("parser.zig");
const Style = parser.Style;
const document_improved = @import("document_improved.zig");
const Document = document_improved.Document;
const Paragraph = document_improved.Paragraph;
const TextRun = document_improved.TextRun;
const Table = document_improved.Table;
const TableRow = document_improved.TableRow;
const TableCell = document_improved.TableCell;
const Image = document_improved.Image;
const Hyperlink = document_improved.Hyperlink;
const Field = document_improved.Field;
const Element = document_improved.Element;
const List = document_improved.List;
const ListItem = document_improved.ListItem;
const ImageFormat = document_improved.ImageFormat;
const ListType = document_improved.ListType;

/// Generic error type for event handlers
pub const EventHandlerError = error{
    NoDocument,
    InvalidState,
    UnsupportedOperation,
    AllocationFailed,
    InvalidData,
    OutOfMemory, // Add this to handle std.mem.Allocator errors
};

/// Standardized event handler interface with clear event types and context
pub const ImprovedEventHandler = struct {
    /// Context pointer for the handler instance
    context: ?*anyopaque = null,

    /// Group start/end events
    onGroupStart: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onGroupEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,

    /// Content events
    onText: ?*const fn(ctx: *anyopaque, text: []const u8, style: Style) EventHandlerError!void = null,
    onCharacter: ?*const fn(ctx: *anyopaque, char: u8, style: Style) EventHandlerError!void = null,
    
    /// Structure events
    onParagraphStart: ?*const fn(ctx: *anyopaque, properties: ?*const anyopaque) EventHandlerError!void = null,
    onParagraphEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onTableStart: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onTableEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onRowStart: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onRowEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onCellStart: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onCellEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    
    /// List events
    onListStart: ?*const fn(ctx: *anyopaque, list_type: ListType) EventHandlerError!void = null,
    onListEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onListItemStart: ?*const fn(ctx: *anyopaque, level: u8) EventHandlerError!void = null,
    onListItemEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    
    /// Special content events
    onImage: ?*const fn(ctx: *anyopaque, data: []const u8, format: ImageFormat, width: u16, height: u16) EventHandlerError!void = null,
    onHyperlinkStart: ?*const fn(ctx: *anyopaque, url: []const u8) EventHandlerError!void = null,
    onHyperlinkEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onFieldStart: ?*const fn(ctx: *anyopaque, field_type: document_improved.FieldType, instructions: []const u8) EventHandlerError!void = null,
    onFieldEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    
    /// Binary data event (general purpose)
    onBinary: ?*const fn(ctx: *anyopaque, data: []const u8, length: usize) EventHandlerError!void = null,
    
    /// Error handling
    onError: ?*const fn(ctx: *anyopaque, position: []const u8, message: []const u8) EventHandlerError!void = null,
    
    /// Document metadata events
    onDocumentStart: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onDocumentEnd: ?*const fn(ctx: *anyopaque) EventHandlerError!void = null,
    onMetadata: ?*const fn(ctx: *anyopaque, key: []const u8, value: []const u8) EventHandlerError!void = null,

    /// Convert the improved event handler to the legacy event handler format
    pub fn toLegacyHandler(self: *const ImprovedEventHandler) parser.EventHandler {
        // Function to wrap our improved context in a legacy handler
        const Context = @TypeOf(self);

        // Group start wrapper
        const onGroupStartFn = struct {
            fn callback(ctx: *anyopaque) anyerror!void {
                const handler = @as(Context, @ptrCast(@alignCast(ctx)));
                if (handler.*.onGroupStart) |start_fn| {
                    try start_fn(handler.*.context orelse @ptrCast(@alignCast(@constCast(handler))));
                }
            }
        }.callback;

        // Group end wrapper
        const onGroupEndFn = struct {
            fn callback(ctx: *anyopaque) anyerror!void {
                const handler = @as(Context, @ptrCast(@alignCast(ctx)));
                if (handler.*.onGroupEnd) |end_fn| {
                    try end_fn(handler.*.context orelse @ptrCast(@alignCast(@constCast(handler))));
                }
            }
        }.callback;

        // Text wrapper
        const onTextFn = struct {
            fn callback(ctx: *anyopaque, text: []const u8, style: Style) anyerror!void {
                const handler = @as(Context, @ptrCast(@alignCast(ctx)));
                if (handler.*.onText) |text_fn| {
                    try text_fn(handler.*.context orelse @ptrCast(@alignCast(@constCast(handler))), text, style);
                }
            }
        }.callback;

        // Character wrapper
        const onCharacterFn = struct {
            fn callback(ctx: *anyopaque, char: u8, style: Style) anyerror!void {
                const handler = @as(Context, @ptrCast(@alignCast(ctx)));
                if (handler.*.onCharacter) |char_fn| {
                    try char_fn(handler.*.context orelse @ptrCast(@alignCast(@constCast(handler))), char, style);
                }
            }
        }.callback;

        // Binary data wrapper
        const onBinaryFn = struct {
            fn callback(ctx: *anyopaque, data: []const u8, length: usize) anyerror!void {
                const handler = @as(Context, @ptrCast(@alignCast(ctx)));
                if (handler.*.onBinary) |binary_fn| {
                    try binary_fn(handler.*.context orelse @ptrCast(@alignCast(@constCast(handler))), data, length);
                } else if (handler.*.onImage) |img_fn| {
                    // Try to use the image handler as a fallback
                    try img_fn(
                        handler.*.context orelse @ptrCast(@alignCast(@constCast(handler))),
                        data,
                        .OTHER,
                        100, // Default width
                        100  // Default height
                    );
                }
            }
        }.callback;

        // Error wrapper
        const onErrorFn = struct {
            fn callback(ctx: *anyopaque, position: []const u8, message: []const u8) anyerror!void {
                const handler = @as(Context, @ptrCast(@alignCast(ctx)));
                if (handler.*.onError) |error_fn| {
                    try error_fn(handler.*.context orelse @ptrCast(@alignCast(@constCast(handler))), position, message);
                }
            }
        }.callback;

        return .{
            .context = @ptrCast(@alignCast(@constCast(self))),
            .onGroupStart = onGroupStartFn,
            .onGroupEnd = onGroupEndFn,
            .onText = onTextFn,
            .onCharacter = onCharacterFn,
            .onBinary = onBinaryFn,
            .onError = onErrorFn,
        };
    }
};

/// Improved document builder that works with the improved document model
pub const ImprovedDocumentBuilder = struct {
    allocator: std.mem.Allocator,
    document: ?*Document = null,

    // Current element tracking
    current_paragraph: ?*Paragraph = null,
    current_table: ?*Table = null,
    current_row: ?*TableRow = null,
    current_cell: ?*TableCell = null,
    current_hyperlink: ?*Hyperlink = null,
    current_list: ?*List = null,
    current_list_item: ?*ListItem = null,
    current_field: ?*Field = null,

    // State tracking
    in_header: bool = false,
    in_footer: bool = false,
    in_footnote: bool = false,

    // Group tracking
    group_stack: std.ArrayList(GroupState),

    pub fn init(allocator: std.mem.Allocator) !ImprovedDocumentBuilder {
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
    pub fn detachDocument(self: *ImprovedDocumentBuilder) ?*Document {
        const doc = self.document;
        self.document = null;
        return doc;
    }

    /// Cleanup resources used by the DocumentBuilder
    pub fn deinit(self: *ImprovedDocumentBuilder) void {
        self.group_stack.deinit();
        
        // Clean up the document we allocated if we still own it
        if (self.document != null) {
            self.document.?.deinit();
            self.allocator.destroy(self.document.?);
        }
    }

    /// Convert the builder to an ImprovedEventHandler
    pub fn handler(self: *ImprovedDocumentBuilder) ImprovedEventHandler {
        const Context = @TypeOf(self);

        // Document events
        const onDocumentStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                _ = builder; // No-op, document is already created in init
                return;
            }
        }.callback;

        const onDocumentEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                _ = builder; // No-op, document will be returned via detachDocument
                return;
            }
        }.callback;

        // Metadata
        const onMetadataFn = struct {
            fn callback(ctx: *anyopaque, key: []const u8, value: []const u8) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                if (builder.document) |doc| {
                    if (std.mem.eql(u8, key, "title")) {
                        try doc.metadata.setTitle(builder.allocator, value);
                    } else if (std.mem.eql(u8, key, "author")) {
                        try doc.metadata.setAuthor(builder.allocator, value);
                    } else if (std.mem.eql(u8, key, "subject")) {
                        try doc.metadata.setSubject(builder.allocator, value);
                    } else if (std.mem.eql(u8, key, "keywords")) {
                        try doc.metadata.setKeywords(builder.allocator, value);
                    } else if (std.mem.eql(u8, key, "comment")) {
                        try doc.metadata.setComment(builder.allocator, value);
                    } else if (std.mem.eql(u8, key, "company")) {
                        try doc.metadata.setCompany(builder.allocator, value);
                    }
                }
            }
        }.callback;

        // Group handling
        const onGroupStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onGroupStart();
            }
        }.callback;

        const onGroupEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onGroupEnd();
            }
        }.callback;

        // Content handling
        const onTextFn = struct {
            fn callback(ctx: *anyopaque, text: []const u8, style: Style) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onText(text, style);
            }
        }.callback;

        const onCharacterFn = struct {
            fn callback(ctx: *anyopaque, char: u8, style: Style) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onCharacter(char, style);
            }
        }.callback;

        // Structure handling
        const onParagraphStartFn = struct {
            fn callback(ctx: *anyopaque, properties: ?*const anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onParagraphStart(properties);
            }
        }.callback;

        const onParagraphEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                builder.current_paragraph = null;
            }
        }.callback;

        const onTableStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.createTable();
            }
        }.callback;

        const onTableEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                builder.current_table = null;
            }
        }.callback;

        const onRowStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.createRow();
            }
        }.callback;

        const onRowEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                builder.current_row = null;
            }
        }.callback;

        const onCellStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.createCell();
            }
        }.callback;

        const onCellEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                builder.current_cell = null;
            }
        }.callback;

        // List handling
        const onListStartFn = struct {
            fn callback(ctx: *anyopaque, list_type: ListType) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.createList(list_type);
            }
        }.callback;

        const onListEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                builder.current_list = null;
            }
        }.callback;

        const onListItemStartFn = struct {
            fn callback(ctx: *anyopaque, level: u8) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.createListItem(level);
            }
        }.callback;

        const onListItemEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                builder.current_list_item = null;
            }
        }.callback;

        // Special content
        const onImageFn = struct {
            fn callback(ctx: *anyopaque, data: []const u8, format: ImageFormat, width: u16, height: u16) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onImage(data, format, width, height);
            }
        }.callback;

        const onHyperlinkStartFn = struct {
            fn callback(ctx: *anyopaque, url: []const u8) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.createHyperlink(url);
            }
        }.callback;

        const onHyperlinkEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                builder.current_hyperlink = null;
            }
        }.callback;

        const onFieldStartFn = struct {
            fn callback(ctx: *anyopaque, field_type: document_improved.FieldType, instructions: []const u8) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.createField(field_type, instructions);
            }
        }.callback;

        const onFieldEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                builder.current_field = null;
            }
        }.callback;

        // Binary data
        const onBinaryFn = struct {
            fn callback(ctx: *anyopaque, data: []const u8, length: usize) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onBinary(data, length);
            }
        }.callback;

        // Error handling
        const onErrorFn = struct {
            fn callback(ctx: *anyopaque, position: []const u8, message: []const u8) EventHandlerError!void {
                const builder = @as(Context, @ptrCast(@alignCast(ctx)));
                try builder.onError(position, message);
            }
        }.callback;

        return .{
            .context = self,
            .onDocumentStart = onDocumentStartFn,
            .onDocumentEnd = onDocumentEndFn,
            .onMetadata = onMetadataFn,
            .onGroupStart = onGroupStartFn,
            .onGroupEnd = onGroupEndFn,
            .onText = onTextFn,
            .onCharacter = onCharacterFn,
            .onParagraphStart = onParagraphStartFn,
            .onParagraphEnd = onParagraphEndFn,
            .onTableStart = onTableStartFn,
            .onTableEnd = onTableEndFn,
            .onRowStart = onRowStartFn,
            .onRowEnd = onRowEndFn,
            .onCellStart = onCellStartFn,
            .onCellEnd = onCellEndFn,
            .onListStart = onListStartFn,
            .onListEnd = onListEndFn,
            .onListItemStart = onListItemStartFn,
            .onListItemEnd = onListItemEndFn,
            .onImage = onImageFn,
            .onHyperlinkStart = onHyperlinkStartFn,
            .onHyperlinkEnd = onHyperlinkEndFn,
            .onFieldStart = onFieldStartFn,
            .onFieldEnd = onFieldEndFn,
            .onBinary = onBinaryFn,
            .onError = onErrorFn,
        };
    }

    // Implementation methods
    fn onGroupStart(self: *ImprovedDocumentBuilder) !void {
        // Save current state before entering a new group
        const state = GroupState{
            .current_paragraph = self.current_paragraph,
            .current_table = self.current_table,
            .current_row = self.current_row,
            .current_cell = self.current_cell,
            .current_hyperlink = self.current_hyperlink,
            .current_list = self.current_list,
            .current_list_item = self.current_list_item,
            .current_field = self.current_field,
            .in_header = self.in_header,
            .in_footer = self.in_footer,
            .in_footnote = self.in_footnote,
        };
        
        try self.group_stack.append(state);
    }

    fn onGroupEnd(self: *ImprovedDocumentBuilder) !void {
        // Restore state when exiting a group
        if (self.group_stack.items.len > 0) {
            const state = self.group_stack.pop().?;
            self.current_paragraph = state.current_paragraph;
            self.current_table = state.current_table;
            self.current_row = state.current_row;
            self.current_cell = state.current_cell;
            self.current_hyperlink = state.current_hyperlink;
            self.current_list = state.current_list;
            self.current_list_item = state.current_list_item;
            self.current_field = state.current_field;
            self.in_header = state.in_header;
            self.in_footer = state.in_footer;
            self.in_footnote = state.in_footnote;
        }
    }

    fn onText(self: *ImprovedDocumentBuilder, text: []const u8, style: Style) !void {
        // Ensure we have a paragraph to add text to
        try self.ensureParagraph();
        
        // Add the text as a text run to the appropriate container
        if (self.current_list_item) |list_item| {
            _ = try list_item.createTextRun(self.allocator, text, style);
        } else if (self.current_hyperlink) |hyperlink| {
            _ = try hyperlink.createTextRun(self.allocator, text, style);
        } else if (self.current_paragraph) |para| {
            _ = try para.createTextRun(self.allocator, text, style);
        } else {
            return EventHandlerError.InvalidState;
        }
    }

    fn onCharacter(self: *ImprovedDocumentBuilder, char: u8, style: Style) !void {
        // Convert the character to a string and handle it like text
        var buffer: [1]u8 = undefined;
        buffer[0] = char;
        try self.onText(buffer[0..], style);
    }

    fn onParagraphStart(self: *ImprovedDocumentBuilder, properties: ?*const anyopaque) !void {
        if (self.current_cell) |cell| {
            self.current_paragraph = try cell.createParagraph(self.allocator);
        } else if (self.current_list_item) |list_item| {
            self.current_paragraph = try list_item.createParagraph(self.allocator);
        } else if (self.document) |doc| {
            self.current_paragraph = try doc.createParagraph();
        } else {
            return EventHandlerError.NoDocument;
        }

        // Apply properties if provided
        if (properties) |props| {
            if (self.current_paragraph) |para| {
                // In a real implementation, we would cast properties to ParagraphProperties
                // and apply them to the paragraph
                _ = para;
                _ = props;
            }
        }
    }

    fn createTable(self: *ImprovedDocumentBuilder) !void {
        if (self.document) |doc| {
            self.current_table = try doc.createTable();
            self.current_row = null;
            self.current_cell = null;
        } else {
            return EventHandlerError.NoDocument;
        }
    }

    fn createRow(self: *ImprovedDocumentBuilder) !void {
        if (self.current_table) |table| {
            self.current_row = try table.createRow(self.allocator);
            self.current_cell = null;
        } else {
            return EventHandlerError.InvalidState;
        }
    }

    fn createCell(self: *ImprovedDocumentBuilder) !void {
        if (self.current_row) |row| {
            self.current_cell = try row.createCell(self.allocator);
            self.current_paragraph = null;
        } else {
            return EventHandlerError.InvalidState;
        }
    }

    fn createList(self: *ImprovedDocumentBuilder, list_type: ListType) !void {
        if (self.document) |doc| {
            self.current_list = try doc.createList(list_type);
            self.current_list_item = null;
        } else {
            return EventHandlerError.NoDocument;
        }
    }

    fn createListItem(self: *ImprovedDocumentBuilder, level: u8) !void {
        if (self.current_list) |list| {
            self.current_list_item = try list.createItem(self.allocator);
            self.current_list_item.?.level = level;
            self.current_paragraph = null;
        } else {
            return EventHandlerError.InvalidState;
        }
    }

    fn onImage(self: *ImprovedDocumentBuilder, data: []const u8, format: ImageFormat, width: u16, height: u16) !void {
        // Ensure we have a paragraph to add the image to
        try self.ensureParagraph();
        
        // Add the image to the appropriate container
        if (self.current_paragraph) |para| {
            _ = try para.createImage(self.allocator, width, height, format, data);
        } else {
            return EventHandlerError.InvalidState;
        }
    }

    fn createHyperlink(self: *ImprovedDocumentBuilder, url: []const u8) !void {
        // Ensure we have a paragraph to add the hyperlink to
        try self.ensureParagraph();
        
        // Create and add the hyperlink
        if (self.current_paragraph) |para| {
            self.current_hyperlink = try para.createHyperlink(self.allocator, url);
        } else {
            return EventHandlerError.InvalidState;
        }
    }

    fn createField(self: *ImprovedDocumentBuilder, field_type: document_improved.FieldType, instructions: []const u8) !void {
        // Ensure we have a paragraph to add the field to
        try self.ensureParagraph();
        
        // Create and add the field
        if (self.current_paragraph) |para| {
            self.current_field = try para.createField(self.allocator, field_type, instructions);
        } else {
            return EventHandlerError.InvalidState;
        }
    }

    fn onBinary(self: *ImprovedDocumentBuilder, data: []const u8, length: usize) !void {
        _ = length; // Currently unused, but we might use this parameter in the future
        
        // For now, treat all binary data as generic image data
        try self.onImage(data, .OTHER, 100, 100);
    }

    fn onError(self: *ImprovedDocumentBuilder, position: []const u8, message: []const u8) !void {
        // In a real implementation, we might log the error or add it to the document
        _ = self;
        _ = position;
        _ = message;
    }

    // Helper methods
    fn ensureParagraph(self: *ImprovedDocumentBuilder) !void {
        if (self.current_paragraph != null) {
            return;
        }
        
        if (self.current_cell) |cell| {
            self.current_paragraph = try cell.createParagraph(self.allocator);
        } else if (self.current_list_item) |list_item| {
            self.current_paragraph = try list_item.createParagraph(self.allocator);
        } else if (self.document) |doc| {
            self.current_paragraph = try doc.createParagraph();
        } else {
            return EventHandlerError.NoDocument;
        }
    }
};

/// Improved HTML converter that works with the improved event system
pub const ImprovedHtmlConverter = struct {
    allocator: std.mem.Allocator,
    writer: std.ArrayList(u8).Writer,
    style_stack: std.ArrayList(Style),
    
    // State tracking
    in_document: bool = false,
    in_head: bool = false,
    in_body: bool = false,
    in_paragraph: bool = false,
    in_table: bool = false,
    in_row: bool = false,
    in_cell: bool = false,
    in_list: bool = false,
    in_list_item: bool = false,
    in_hyperlink: bool = false,
    in_field: bool = false,
    
    // Document metadata
    title: ?[]const u8 = null,
    
    // Group tracking
    group_stack: std.ArrayList(HtmlGroupState),
    
    pub fn init(allocator: std.mem.Allocator, writer: std.ArrayList(u8).Writer) ImprovedHtmlConverter {
        return .{
            .allocator = allocator,
            .writer = writer,
            .style_stack = std.ArrayList(Style).init(allocator),
            .group_stack = std.ArrayList(HtmlGroupState).init(allocator),
        };
    }
    
    pub fn deinit(self: *ImprovedHtmlConverter) void {
        self.style_stack.deinit();
        self.group_stack.deinit();
        if (self.title) |title| {
            self.allocator.free(title);
        }
    }
    
    /// Convert the converter to an ImprovedEventHandler
    pub fn handler(self: *ImprovedHtmlConverter) ImprovedEventHandler {
        const Context = @TypeOf(self);

        // Document events
        const onDocumentStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.beginDocument();
            }
        }.callback;

        const onDocumentEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.endDocument();
            }
        }.callback;

        // Metadata
        const onMetadataFn = struct {
            fn callback(ctx: *anyopaque, key: []const u8, value: []const u8) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                if (std.mem.eql(u8, key, "title")) {
                    if (converter.title) |old_title| {
                        converter.allocator.free(old_title);
                    }
                    converter.title = try converter.allocator.dupe(u8, value);
                }
                // Other metadata could be handled here
            }
        }.callback;

        // Group events
        const onGroupStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onGroupStart();
            }
        }.callback;

        const onGroupEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onGroupEnd();
            }
        }.callback;

        // Content events
        const onTextFn = struct {
            fn callback(ctx: *anyopaque, text: []const u8, style: Style) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onText(text, style);
            }
        }.callback;

        const onCharacterFn = struct {
            fn callback(ctx: *anyopaque, char: u8, style: Style) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onCharacter(char, style);
            }
        }.callback;

        // Structure events
        const onParagraphStartFn = struct {
            fn callback(ctx: *anyopaque, properties: ?*const anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.beginParagraph(properties);
            }
        }.callback;

        const onParagraphEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.endParagraph();
            }
        }.callback;

        const onTableStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.beginTable();
            }
        }.callback;

        const onTableEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.endTable();
            }
        }.callback;

        const onRowStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.beginRow();
            }
        }.callback;

        const onRowEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.endRow();
            }
        }.callback;

        const onCellStartFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.beginCell();
            }
        }.callback;

        const onCellEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.endCell();
            }
        }.callback;

        // List events
        const onListStartFn = struct {
            fn callback(ctx: *anyopaque, list_type: ListType) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.beginList(list_type);
            }
        }.callback;

        const onListEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.endList();
            }
        }.callback;

        const onListItemStartFn = struct {
            fn callback(ctx: *anyopaque, level: u8) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.beginListItem(level);
            }
        }.callback;

        const onListItemEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.endListItem();
            }
        }.callback;

        // Special content
        const onImageFn = struct {
            fn callback(ctx: *anyopaque, data: []const u8, format: ImageFormat, width: u16, height: u16) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.handleImage(data, format, width, height);
            }
        }.callback;

        const onHyperlinkStartFn = struct {
            fn callback(ctx: *anyopaque, url: []const u8) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.beginHyperlink(url);
            }
        }.callback;

        const onHyperlinkEndFn = struct {
            fn callback(ctx: *anyopaque) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.endHyperlink();
            }
        }.callback;

        // Binary data
        const onBinaryFn = struct {
            fn callback(ctx: *anyopaque, data: []const u8, length: usize) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.handleBinaryData(data, length);
            }
        }.callback;

        // Error handling
        const onErrorFn = struct {
            fn callback(ctx: *anyopaque, position: []const u8, message: []const u8) EventHandlerError!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.handleError(position, message);
            }
        }.callback;

        return .{
            .context = self,
            .onDocumentStart = onDocumentStartFn,
            .onDocumentEnd = onDocumentEndFn,
            .onMetadata = onMetadataFn,
            .onGroupStart = onGroupStartFn,
            .onGroupEnd = onGroupEndFn,
            .onText = onTextFn,
            .onCharacter = onCharacterFn,
            .onParagraphStart = onParagraphStartFn,
            .onParagraphEnd = onParagraphEndFn,
            .onTableStart = onTableStartFn,
            .onTableEnd = onTableEndFn,
            .onRowStart = onRowStartFn,
            .onRowEnd = onRowEndFn,
            .onCellStart = onCellStartFn,
            .onCellEnd = onCellEndFn,
            .onListStart = onListStartFn,
            .onListEnd = onListEndFn,
            .onListItemStart = onListItemStartFn,
            .onListItemEnd = onListItemEndFn,
            .onImage = onImageFn,
            .onHyperlinkStart = onHyperlinkStartFn,
            .onHyperlinkEnd = onHyperlinkEndFn,
            .onBinary = onBinaryFn,
            .onError = onErrorFn,
        };
    }

    // Implementation methods
    pub fn beginDocument(self: *ImprovedHtmlConverter) !void {
        try self.writer.writeAll("<!DOCTYPE html>\n");
        try self.writer.writeAll("<html>\n<head>\n");
        try self.writer.writeAll("<meta charset=\"UTF-8\">\n");
        
        if (self.title) |title| {
            try self.writer.writeAll("<title>");
            try self.writeEscapedHtml(title);
            try self.writer.writeAll("</title>\n");
        } else {
            try self.writer.writeAll("<title>RTF Document</title>\n");
        }
        
        try self.writer.writeAll("<style>\n");
        try self.writer.writeAll("body { font-family: Arial, sans-serif; }\n");
        try self.writer.writeAll("table { border-collapse: collapse; width: 100%; }\n");
        try self.writer.writeAll("td, th { border: 1px solid #ddd; padding: 8px; }\n");
        try self.writer.writeAll("ul.bullet { list-style-type: disc; }\n");
        try self.writer.writeAll("ul.numbered { list-style-type: decimal; }\n");
        try self.writer.writeAll("ul.lettered { list-style-type: lower-alpha; }\n");
        try self.writer.writeAll("ul.roman { list-style-type: lower-roman; }\n");
        try self.writer.writeAll("</style>\n");
        
        try self.writer.writeAll("</head>\n<body>\n");
        
        self.in_document = true;
        self.in_head = true;
        self.in_body = true;
    }

    pub fn endDocument(self: *ImprovedHtmlConverter) !void {
        // Close any open tags
        try self.ensureAllTagsClosed();
        try self.writer.writeAll("</body>\n</html>");
    }

    fn onGroupStart(self: *ImprovedHtmlConverter) !void {
        // Save current state before entering a new group
        const state = HtmlGroupState{
            .in_paragraph = self.in_paragraph,
            .in_table = self.in_table,
            .in_row = self.in_row,
            .in_cell = self.in_cell,
            .in_list = self.in_list,
            .in_list_item = self.in_list_item,
            .in_hyperlink = self.in_hyperlink,
            .in_field = self.in_field,
        };
        
        try self.group_stack.append(state);
        
        // Also save the current style
        const current_style = if (self.style_stack.items.len > 0) 
            self.style_stack.items[self.style_stack.items.len - 1] 
        else 
            Style{};
            
        try self.style_stack.append(current_style);
    }

    fn onGroupEnd(self: *ImprovedHtmlConverter) !void {
        // Close any style tags that were opened in this group
        if (self.style_stack.items.len > 0) {
            const old_style = self.style_stack.pop();
            
            // If there's a previous style, compare and close/reopen tags as needed
            if (self.style_stack.items.len > 0) {
                const new_style = self.style_stack.items[self.style_stack.items.len - 1];
                
                // Close tags for styles that are no longer active
                try self.closeStyleDifferences(old_style.?, new_style);
            } else {
                // Close all style tags
                try self.closeStyle(old_style.?);
            }
        }
        
        // Restore state when exiting a group
        if (self.group_stack.items.len > 0) {
            const state = self.group_stack.pop().?;
            
            // Close any tags that need to be closed
            if (self.in_paragraph and !state.in_paragraph) {
                try self.writer.writeAll("</p>\n");
            }
            
            if (self.in_cell and !state.in_cell) {
                try self.writer.writeAll("</td>\n");
            }
            
            if (self.in_row and !state.in_row) {
                try self.writer.writeAll("</tr>\n");
            }
            
            if (self.in_table and !state.in_table) {
                try self.writer.writeAll("</table>\n");
            }
            
            if (self.in_list_item and !state.in_list_item) {
                try self.writer.writeAll("</li>\n");
            }
            
            if (self.in_list and !state.in_list) {
                try self.writer.writeAll("</ul>\n");
            }
            
            if (self.in_hyperlink and !state.in_hyperlink) {
                try self.writer.writeAll("</a>");
            }
            
            // Restore state
            self.in_paragraph = state.in_paragraph;
            self.in_table = state.in_table;
            self.in_row = state.in_row;
            self.in_cell = state.in_cell;
            self.in_list = state.in_list;
            self.in_list_item = state.in_list_item;
            self.in_hyperlink = state.in_hyperlink;
            self.in_field = state.in_field;
        }
    }

    fn onText(self: *ImprovedHtmlConverter, text: []const u8, style: Style) !void {
        // Ensure we're in a paragraph or other container
        if (!self.in_paragraph and !self.in_list_item) {
            try self.beginParagraph(null);
        }
        
        // Apply style changes
        if (self.style_stack.items.len > 0) {
            const old_style = self.style_stack.items[self.style_stack.items.len - 1];
            
            // Update the current style with any changes
            const new_style = old_style.merge(style);
            self.style_stack.items[self.style_stack.items.len - 1] = new_style;
            
            // Close and reopen style tags as needed
            try self.updateStyleTags(old_style, new_style);
        } else {
            // First style, just open tags
            try self.openStyle(style);
            try self.style_stack.append(style);
        }
        
        // Write the text with HTML escaping
        try self.writeEscapedHtml(text);
    }

    fn onCharacter(self: *ImprovedHtmlConverter, char: u8, style: Style) !void {
        // Convert the character to a string and handle it like text
        var buffer: [1]u8 = undefined;
        buffer[0] = char;
        try self.onText(buffer[0..], style);
    }

    fn beginParagraph(self: *ImprovedHtmlConverter, properties: ?*const anyopaque) !void {
        // Close previous paragraph if needed
        if (self.in_paragraph) {
            try self.writer.writeAll("</p>\n");
        }
        
        try self.writer.writeAll("<p");
        
        // Add paragraph properties if available
        if (properties != null) {
            // In a real implementation, we would add style attributes based on properties
            // For now, we just add a default alignment
        }
        
        try self.writer.writeAll(">");
        self.in_paragraph = true;
    }

    fn endParagraph(self: *ImprovedHtmlConverter) !void {
        if (self.in_paragraph) {
            try self.writer.writeAll("</p>\n");
            self.in_paragraph = false;
        }
    }

    fn beginTable(self: *ImprovedHtmlConverter) !void {
        // Close any open paragraph
        if (self.in_paragraph) {
            try self.writer.writeAll("</p>\n");
            self.in_paragraph = false;
        }
        
        try self.writer.writeAll("<table>\n");
        self.in_table = true;
    }

    fn endTable(self: *ImprovedHtmlConverter) !void {
        // Close any open cell and row
        if (self.in_cell) {
            try self.writer.writeAll("</td>\n");
            self.in_cell = false;
        }
        
        if (self.in_row) {
            try self.writer.writeAll("</tr>\n");
            self.in_row = false;
        }
        
        if (self.in_table) {
            try self.writer.writeAll("</table>\n");
            self.in_table = false;
        }
    }

    fn beginRow(self: *ImprovedHtmlConverter) !void {
        // Close any open row
        if (self.in_row) {
            try self.writer.writeAll("</tr>\n");
        }
        
        try self.writer.writeAll("<tr>\n");
        self.in_row = true;
    }

    fn endRow(self: *ImprovedHtmlConverter) !void {
        if (self.in_cell) {
            try self.writer.writeAll("</td>\n");
            self.in_cell = false;
        }
        
        if (self.in_row) {
            try self.writer.writeAll("</tr>\n");
            self.in_row = false;
        }
    }

    fn beginCell(self: *ImprovedHtmlConverter) !void {
        // Close any open cell
        if (self.in_cell) {
            try self.writer.writeAll("</td>\n");
        }
        
        try self.writer.writeAll("<td>");
        self.in_cell = true;
    }

    fn endCell(self: *ImprovedHtmlConverter) !void {
        if (self.in_paragraph) {
            try self.writer.writeAll("</p>\n");
            self.in_paragraph = false;
        }
        
        if (self.in_cell) {
            try self.writer.writeAll("</td>\n");
            self.in_cell = false;
        }
    }

    fn beginList(self: *ImprovedHtmlConverter, list_type: ListType) !void {
        // Close any open paragraph
        if (self.in_paragraph) {
            try self.writer.writeAll("</p>\n");
            self.in_paragraph = false;
        }
        
        // Determine list class based on type
        const list_class = switch (list_type) {
            .BULLET => "bullet",
            .NUMBERED => "numbered",
            .LETTERED => "lettered",
            .ROMAN => "roman",
            .CUSTOM => "custom",
        };
        
        try self.writer.print("<ul class=\"{s}\">\n", .{list_class});
        self.in_list = true;
    }

    fn endList(self: *ImprovedHtmlConverter) !void {
        if (self.in_list_item) {
            try self.writer.writeAll("</li>\n");
            self.in_list_item = false;
        }
        
        if (self.in_list) {
            try self.writer.writeAll("</ul>\n");
            self.in_list = false;
        }
    }

    fn beginListItem(self: *ImprovedHtmlConverter, level: u8) !void {
        if (self.in_list_item) {
            try self.writer.writeAll("</li>\n");
        }
        
        if (level > 1) {
            try self.writer.print("<li style=\"margin-left: {d}em\">\n", .{(level - 1) * 2});
        } else {
            try self.writer.writeAll("<li>\n");
        }
        
        self.in_list_item = true;
    }

    fn endListItem(self: *ImprovedHtmlConverter) !void {
        if (self.in_paragraph) {
            try self.writer.writeAll("</p>\n");
            self.in_paragraph = false;
        }
        
        if (self.in_list_item) {
            try self.writer.writeAll("</li>\n");
            self.in_list_item = false;
        }
    }

    fn beginHyperlink(self: *ImprovedHtmlConverter, url: []const u8) !void {
        try self.writer.writeAll("<a href=\"");
        try self.writeEscapedHtml(url);
        try self.writer.writeAll("\">");
        
        self.in_hyperlink = true;
    }

    fn endHyperlink(self: *ImprovedHtmlConverter) !void {
        if (self.in_hyperlink) {
            try self.writer.writeAll("</a>");
            self.in_hyperlink = false;
        }
    }

    fn handleImage(self: *ImprovedHtmlConverter, data: []const u8, format: ImageFormat, width: u16, height: u16) !void {
        _ = data; // We don't actually encode the image data
        
        // In a real implementation, we might encode the image data or save it to a file
        const format_str = switch (format) {
            .BMP => "bmp",
            .WMF => "wmf",
            .EMF => "emf",
            .JPEG => "jpeg",
            .PNG => "png",
            .OTHER => "unknown",
        };
        
        try self.writer.print("<img alt=\"Image ({s})\" width=\"{d}\" height=\"{d}\" />", 
            .{format_str, width, height});
    }

    fn handleBinaryData(self: *ImprovedHtmlConverter, data: []const u8, length: usize) !void {
        _ = data;
        try self.writer.print("<img alt=\"Binary data\" width=\"100\" height=\"100\" data-size=\"{d}\" />", 
            .{length});
    }

    fn handleError(self: *ImprovedHtmlConverter, position: []const u8, message: []const u8) !void {
        try self.writer.writeAll("<!-- Error at ");
        try self.writer.writeAll(position);
        try self.writer.writeAll(": ");
        try self.writer.writeAll(message);
        try self.writer.writeAll(" -->\n");
    }

    // Helper methods
    fn writeEscapedHtml(self: *ImprovedHtmlConverter, text: []const u8) !void {
        for (text) |c| {
            switch (c) {
                '&' => try self.writer.writeAll("&amp;"),
                '<' => try self.writer.writeAll("&lt;"),
                '>' => try self.writer.writeAll("&gt;"),
                '"' => try self.writer.writeAll("&quot;"),
                '\'' => try self.writer.writeAll("&#39;"),
                else => try self.writer.writeByte(c),
            }
        }
    }

    fn openStyle(self: *ImprovedHtmlConverter, style: Style) !void {
        // Use semantic HTML tags for common formatting
        if (style.bold) try self.writer.writeAll("<strong>");
        if (style.italic) try self.writer.writeAll("<em>");
        if (style.underline) try self.writer.writeAll("<u>");
        if (style.strikethrough) try self.writer.writeAll("<s>");
        
        // Handle other style properties as needed
        if (style.foreground_color) |color| {
            try self.writer.print("<span style=\"color:#{x:0>6};\">", .{color});
        }
        
        if (style.background_color) |color| {
            try self.writer.print("<span style=\"background-color:#{x:0>6};\">", .{color});
        }
    }

    fn closeStyle(self: *ImprovedHtmlConverter, style: Style) !void {
        // Close tags in reverse order
        if (style.background_color != null) try self.writer.writeAll("</span>");
        if (style.foreground_color != null) try self.writer.writeAll("</span>");
        if (style.strikethrough) try self.writer.writeAll("</s>");
        if (style.underline) try self.writer.writeAll("</u>");
        if (style.italic) try self.writer.writeAll("</em>");
        if (style.bold) try self.writer.writeAll("</strong>");
    }

    fn updateStyleTags(self: *ImprovedHtmlConverter, old_style: Style, new_style: Style) !void {
        // Close tags that are no longer needed
        try self.closeStyleDifferences(old_style, new_style);
        
        // Open new tags as needed
        if (!old_style.bold and new_style.bold) try self.writer.writeAll("<strong>");
        if (!old_style.italic and new_style.italic) try self.writer.writeAll("<em>");
        if (!old_style.underline and new_style.underline) try self.writer.writeAll("<u>");
        if (!old_style.strikethrough and new_style.strikethrough) try self.writer.writeAll("<s>");
        
        // Handle foreground color changes
        if (old_style.foreground_color == null and new_style.foreground_color != null) {
            try self.writer.print("<span style=\"color:#{x:0>6};\">", .{new_style.foreground_color.?});
        } else if (old_style.foreground_color != null and new_style.foreground_color != null and
                  old_style.foreground_color.? != new_style.foreground_color.?) {
            try self.writer.writeAll("</span>");
            try self.writer.print("<span style=\"color:#{x:0>6};\">", .{new_style.foreground_color.?});
        }
        
        // Handle background color changes
        if (old_style.background_color == null and new_style.background_color != null) {
            try self.writer.print("<span style=\"background-color:#{x:0>6};\">", .{new_style.background_color.?});
        } else if (old_style.background_color != null and new_style.background_color != null and
                  old_style.background_color.? != new_style.background_color.?) {
            try self.writer.writeAll("</span>");
            try self.writer.print("<span style=\"background-color:#{x:0>6};\">", .{new_style.background_color.?});
        }
    }

    fn closeStyleDifferences(self: *ImprovedHtmlConverter, old_style: Style, new_style: Style) !void {
        // Close tags in reverse order
        
        // Background color
        if (old_style.background_color != null and 
            (new_style.background_color == null or old_style.background_color.? != new_style.background_color.?)) {
            try self.writer.writeAll("</span>");
        }
        
        // Foreground color
        if (old_style.foreground_color != null and 
            (new_style.foreground_color == null or old_style.foreground_color.? != new_style.foreground_color.?)) {
            try self.writer.writeAll("</span>");
        }
        
        // Semantic HTML elements
        if (old_style.strikethrough and !new_style.strikethrough) try self.writer.writeAll("</s>");
        if (old_style.underline and !new_style.underline) try self.writer.writeAll("</u>");
        if (old_style.italic and !new_style.italic) try self.writer.writeAll("</em>");
        if (old_style.bold and !new_style.bold) try self.writer.writeAll("</strong>");
    }

    fn ensureAllTagsClosed(self: *ImprovedHtmlConverter) !void {
        // Close any open style tags
        while (self.style_stack.items.len > 0) {
            const style = self.style_stack.pop().?;
            try self.closeStyle(style);
        }
        
        // Close all other tags in the correct order
        if (self.in_hyperlink) {
            try self.writer.writeAll("</a>");
            self.in_hyperlink = false;
        }
        
        if (self.in_paragraph) {
            try self.writer.writeAll("</p>\n");
            self.in_paragraph = false;
        }
        
        if (self.in_list_item) {
            try self.writer.writeAll("</li>\n");
            self.in_list_item = false;
        }
        
        if (self.in_list) {
            try self.writer.writeAll("</ul>\n");
            self.in_list = false;
        }
        
        if (self.in_cell) {
            try self.writer.writeAll("</td>\n");
            self.in_cell = false;
        }
        
        if (self.in_row) {
            try self.writer.writeAll("</tr>\n");
            self.in_row = false;
        }
        
        if (self.in_table) {
            try self.writer.writeAll("</table>\n");
            self.in_table = false;
        }
    }
};

/// Group state for document builder to maintain document structure
const GroupState = struct {
    current_paragraph: ?*Paragraph,
    current_table: ?*Table,
    current_row: ?*TableRow,
    current_cell: ?*TableCell,
    current_hyperlink: ?*Hyperlink,
    current_list: ?*List,
    current_list_item: ?*ListItem,
    current_field: ?*Field,
    in_header: bool,
    in_footer: bool,
    in_footnote: bool,
};

/// Group state for HTML converter
const HtmlGroupState = struct {
    in_paragraph: bool,
    in_table: bool,
    in_row: bool,
    in_cell: bool,
    in_list: bool,
    in_list_item: bool,
    in_hyperlink: bool,
    in_field: bool,
};