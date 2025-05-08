const std = @import("std");
const parser = @import("parser.zig");
const Style = parser.Style;
const EventHandler = parser.EventHandler;

/// Group state tracking for the HTML converter
const GroupState = struct {
    in_paragraph: bool,
    in_table: bool,
    in_row: bool,
    in_cell: bool,
    in_hyperlink: bool,
};

/// The HtmlConverter processes events from the parser and generates HTML output directly
/// without constructing an intermediate document model.
pub const HtmlConverter = struct {
    allocator: std.mem.Allocator,
    writer: std.ArrayList(u8).Writer,
    style_stack: std.ArrayList(Style),
    
    // State tracking
    in_paragraph: bool,
    in_table: bool,
    in_row: bool,
    in_cell: bool,
    in_hyperlink: bool,
    
    // Group tracking
    group_stack: std.ArrayList(GroupState),
    
    pub fn init(allocator: std.mem.Allocator, writer: std.ArrayList(u8).Writer) HtmlConverter {
        return .{
            .allocator = allocator,
            .writer = writer,
            .style_stack = std.ArrayList(Style).init(allocator),
            .group_stack = std.ArrayList(GroupState).init(allocator),
            .in_paragraph = false,
            .in_table = false,
            .in_row = false,
            .in_cell = false,
            .in_hyperlink = false,
        };
    }
    
    pub fn deinit(self: *HtmlConverter) void {
        self.style_stack.deinit();
        self.group_stack.deinit();
    }
    
    /// Convert the converter to an EventHandler for use with the parser
    pub fn handler(self: *HtmlConverter) EventHandler {
        const Context = @TypeOf(self);

        // Group start callback
        const onGroupStartFn = struct {
            fn callback(ctx: *anyopaque) anyerror!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onGroupStart();
            }
        }.callback;

        // Group end callback
        const onGroupEndFn = struct {
            fn callback(ctx: *anyopaque) anyerror!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onGroupEnd();
            }
        }.callback;

        // Text callback
        const onTextFn = struct {
            fn callback(ctx: *anyopaque, text: []const u8, style: Style) anyerror!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onText(text, style);
            }
        }.callback;

        // Character callback
        const onCharacterFn = struct {
            fn callback(ctx: *anyopaque, char: u8, style: Style) anyerror!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onCharacter(char, style);
            }
        }.callback;

        // Binary data callback
        const onBinaryFn = struct {
            fn callback(ctx: *anyopaque, data: []const u8, length: usize) anyerror!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onBinary(data, length);
            }
        }.callback;

        // Error callback
        const onErrorFn = struct {
            fn callback(ctx: *anyopaque, position: []const u8, message: []const u8) anyerror!void {
                const converter = @as(Context, @ptrCast(@alignCast(ctx)));
                try converter.onError(position, message);
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
    
    /// Initialize HTML document
    pub fn beginDocument(self: *HtmlConverter) !void {
        try self.writer.writeAll("<!DOCTYPE html>\n");
        try self.writer.writeAll("<html>\n<head>\n");
        try self.writer.writeAll("<meta charset=\"UTF-8\">\n");
        try self.writer.writeAll("<title>RTF Document</title>\n");
        try self.writer.writeAll("<style>\n");
        try self.writer.writeAll("body { font-family: Arial, sans-serif; }\n");
        try self.writer.writeAll("table { border-collapse: collapse; width: 100%; }\n");
        try self.writer.writeAll("td, th { border: 1px solid #ddd; padding: 8px; }\n");
        try self.writer.writeAll("</style>\n");
        try self.writer.writeAll("</head>\n<body>\n");
    }
    
    /// Close HTML document
    pub fn endDocument(self: *HtmlConverter) !void {
        // Close any open tags
        if (self.in_paragraph) {
            try self.writer.writeAll("</p>\n");
            self.in_paragraph = false;
        }
        
        if (self.in_table) {
            if (self.in_row) {
                if (self.in_cell) {
                    try self.writer.writeAll("</td>\n");
                    self.in_cell = false;
                }
                try self.writer.writeAll("</tr>\n");
                self.in_row = false;
            }
            try self.writer.writeAll("</table>\n");
            self.in_table = false;
        }
        
        try self.writer.writeAll("</body>\n</html>");
    }
    
    /// Called when a group starts in the RTF document
    fn onGroupStart(self: *HtmlConverter) !void {
        // Save current state before entering a new group
        const state = GroupState{
            .in_paragraph = self.in_paragraph,
            .in_table = self.in_table,
            .in_row = self.in_row,
            .in_cell = self.in_cell,
            .in_hyperlink = self.in_hyperlink,
        };
        
        try self.group_stack.append(state);
        
        // Also save the current style
        const current_style = if (self.style_stack.items.len > 0) 
            self.style_stack.items[self.style_stack.items.len - 1] 
        else 
            Style{};
            
        try self.style_stack.append(current_style);
    }
    
    /// Called when a group ends in the RTF document
    fn onGroupEnd(self: *HtmlConverter) !void {
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
            
            if (self.in_hyperlink and !state.in_hyperlink) {
                try self.writer.writeAll("</a>");
            }
            
            // Restore state
            self.in_paragraph = state.in_paragraph;
            self.in_table = state.in_table;
            self.in_row = state.in_row;
            self.in_cell = state.in_cell;
            self.in_hyperlink = state.in_hyperlink;
        }
    }
    
    /// Called when text is encountered in the RTF document
    fn onText(self: *HtmlConverter, text: []const u8, style: Style) !void {
        // Ensure we have a paragraph to add text to
        if (!self.in_paragraph) {
            try self.writer.writeAll("<p>");
            self.in_paragraph = true;
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
        
        // Write the text (should escape HTML special chars in a real implementation)
        try self.writer.writeAll(text);
    }
    
    /// Called when a single character is encountered in the RTF document
    fn onCharacter(self: *HtmlConverter, char: u8, style: Style) !void {
        // Convert the character to a string and handle it like text
        var buffer: [1]u8 = undefined;
        buffer[0] = char;
        try self.onText(buffer[0..], style);
    }
    
    /// Called when binary data is encountered in the RTF document
    fn onBinary(self: *HtmlConverter, data: []const u8, length: usize) !void {
        // In a real implementation, we might encode the image data
        // or save it to a file and reference it
        _ = data;
        try self.writer.print("<img alt=\"Image\" width=\"100\" height=\"100\" data-size=\"{d}\" />", 
            .{length});
    }
    
    /// Called when an error is encountered during parsing
    fn onError(self: *HtmlConverter, position: []const u8, message: []const u8) !void {
        // In a real implementation, we might add a comment to the HTML output
        try self.writer.writeAll("<!-- Error at ");
        try self.writer.writeAll(position);
        try self.writer.writeAll(": ");
        try self.writer.writeAll(message);
        try self.writer.writeAll(" -->\n");
    }
    
    /// Open style tags for a given style
    fn openStyle(self: *HtmlConverter, style: Style) !void {
        if (style.bold) try self.writer.writeAll("<strong>");
        if (style.italic) try self.writer.writeAll("<em>");
        if (style.underline) try self.writer.writeAll("<u>");
        if (style.strikethrough) try self.writer.writeAll("<s>");
        
        // Handle other style properties as needed
        if (style.foreground_color) |color| {
            try self.writer.print("<span style=\"color:#{x:0>6};\">", .{color});
        }
    }
    
    /// Close style tags for a given style
    fn closeStyle(self: *HtmlConverter, style: Style) !void {
        // Close tags in reverse order
        if (style.foreground_color != null) try self.writer.writeAll("</span>");
        if (style.strikethrough) try self.writer.writeAll("</s>");
        if (style.underline) try self.writer.writeAll("</u>");
        if (style.italic) try self.writer.writeAll("</em>");
        if (style.bold) try self.writer.writeAll("</strong>");
    }
    
    /// Update style tags when style changes
    fn updateStyleTags(self: *HtmlConverter, old_style: Style, new_style: Style) !void {
        // Close tags that are no longer needed
        try self.closeStyleDifferences(old_style, new_style);
        
        // Open new tags as needed
        if (!old_style.bold and new_style.bold) try self.writer.writeAll("<strong>");
        if (!old_style.italic and new_style.italic) try self.writer.writeAll("<em>");
        if (!old_style.underline and new_style.underline) try self.writer.writeAll("<u>");
        if (!old_style.strikethrough and new_style.strikethrough) try self.writer.writeAll("<s>");
        
        // Handle color changes
        if (old_style.foreground_color == null and new_style.foreground_color != null) {
            try self.writer.print("<span style=\"color:#{x:0>6};\">", .{new_style.foreground_color.?});
        } else if (old_style.foreground_color != null and new_style.foreground_color != null and
                  old_style.foreground_color.? != new_style.foreground_color.?) {
            try self.writer.writeAll("</span>");
            try self.writer.print("<span style=\"color:#{x:0>6};\">", .{new_style.foreground_color.?});
        }
    }
    
    /// Close style tags that are different between old and new styles
    fn closeStyleDifferences(self: *HtmlConverter, old_style: Style, new_style: Style) !void {
        // Close tags in reverse order
        if (old_style.foreground_color != null and 
            (new_style.foreground_color == null or old_style.foreground_color.? != new_style.foreground_color.?)) {
            try self.writer.writeAll("</span>");
        }
        
        if (old_style.strikethrough and !new_style.strikethrough) try self.writer.writeAll("</s>");
        if (old_style.underline and !new_style.underline) try self.writer.writeAll("</u>");
        if (old_style.italic and !new_style.italic) try self.writer.writeAll("</em>");
        if (old_style.bold and !new_style.bold) try self.writer.writeAll("</strong>");
    }
};