const std = @import("std");
const testing = std.testing;

pub const byte_stream = @import("byte_stream.zig");
pub const ByteStream = byte_stream.ByteStream;
pub const Position = byte_stream.Position;
pub const DEFAULT_MMAP_THRESHOLD = byte_stream.DEFAULT_MMAP_THRESHOLD;
pub const MemoryMapType = byte_stream.MemoryMapType;

pub const tokenizer = @import("tokenizer.zig");
pub const Tokenizer = tokenizer.Tokenizer;
pub const Token = tokenizer.Token;
pub const TokenType = tokenizer.TokenType;

pub const parser = @import("parser.zig");
pub const Parser = parser.Parser;
pub const ParserState = parser.ParserState;
pub const Style = parser.Style;
pub const EventHandler = parser.EventHandler;
pub const CharacterSet = parser.CharacterSet;

// Document model (legacy)
pub const document = @import("document.zig");
pub const Document = document.Document;
pub const Paragraph = document.Paragraph;
pub const TextRun = document.TextRun;
pub const Table = document.Table;
pub const TableRow = document.TableRow;
pub const TableCell = document.TableCell;
pub const Image = document.Image;
pub const Hyperlink = document.Hyperlink;
pub const Field = document.Field;
pub const Element = document.Element;
pub const ParagraphProperties = document.ParagraphProperties;
pub const Alignment = document.Alignment;
pub const ElementType = document.ElementType;

// Improved Document model (recommended)
pub const document_improved = @import("document_improved.zig");
pub const DocumentImproved = document_improved.Document;
pub const ParagraphImproved = document_improved.Paragraph;
pub const TextRunImproved = document_improved.TextRun;
pub const TableImproved = document_improved.Table;
pub const TableRowImproved = document_improved.TableRow;
pub const TableCellImproved = document_improved.TableCell;
pub const ImageImproved = document_improved.Image;
pub const HyperlinkImproved = document_improved.Hyperlink;
pub const FieldImproved = document_improved.Field;
pub const ElementImproved = document_improved.Element;
pub const ParagraphPropertiesImproved = document_improved.ParagraphProperties;
pub const AlignmentImproved = document_improved.Alignment;
pub const ElementTypeImproved = document_improved.ElementType;
pub const DocumentError = document_improved.DocumentError;
pub const ListImproved = document_improved.List;
pub const ListItemImproved = document_improved.ListItem;
pub const ListType = document_improved.ListType;

// Document processors (legacy)
pub const document_builder = @import("document_builder.zig");
pub const DocumentBuilder = document_builder.DocumentBuilder;

pub const html_converter = @import("html_converter.zig");
pub const HtmlConverter = html_converter.HtmlConverter;

// Improved document processors (recommended)
pub const event_handler_improved = @import("event_handler_improved.zig");
pub const ImprovedEventHandler = event_handler_improved.ImprovedEventHandler;
pub const ImprovedDocumentBuilder = event_handler_improved.ImprovedDocumentBuilder;
pub const ImprovedHtmlConverter = event_handler_improved.ImprovedHtmlConverter;
pub const EventHandlerError = event_handler_improved.EventHandlerError;

// Export C API
pub const c_api = @import("c_api.zig");
pub usingnamespace @import("c_api.zig");

// Export Improved C API
pub const c_api_improved = @import("c_api_improved.zig");
pub usingnamespace @import("c_api_improved.zig");

// Export test files
test {
    // Run all the tests from these modules
    _ = @import("byte_stream_test.zig");
    _ = @import("byte_stream_mmap_test.zig");
    _ = @import("tokenizer_test.zig");
    _ = @import("parser_test_fixed.zig");
    _ = @import("document_test.zig");
    _ = @import("document_improved_test.zig");
    _ = @import("event_handler_improved_test.zig");
    _ = @import("html_converter_test.zig");
}