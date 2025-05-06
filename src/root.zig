const std = @import("std");
const testing = std.testing;

pub const byte_stream = @import("byte_stream.zig");
pub const ByteStream = byte_stream.ByteStream;
pub const Position = byte_stream.Position;

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

// Export C API
pub const c_api = @import("c_api.zig");

// Export simplified C API
pub usingnamespace @import("c_api_simple.zig");

// Export test files
test {
    // Run all the tests from these modules
    _ = @import("byte_stream_test.zig");
    _ = @import("tokenizer_test.zig");
    _ = @import("parser_test_fixed.zig");
}