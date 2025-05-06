# RTF Parser in Zig

> Note: This project is a work in progress and is likely to be broken.

## Project Status

The project is in active development and currently implements:

- ByteStream: Low-level input handling with position tracking and efficient buffering
- Tokenizer: RTF token identification and extraction
- Parser: Basic state machine that processes tokens into semantic RTF elements
- Style handling: Support for basic text styling (bold, italic, etc.)
- Event-based callbacks: SAX-style processing of RTF content

## Design Goals

- **Performance-first**: Maximize throughput for both small and large documents
- **Memory efficiency**: Process multi-megabyte documents with minimal allocation
- **Completeness**: Support the full RTF v1.9 specification
- **Developer experience**: Intuitive API with excellent error reporting
- **Robustness**: Graceful handling of malformed RTF
- **Streaming capability**: Process documents incrementally without loading everything into memory

## Architecture

The architecture follows a layered approach:

1. **ByteStream**: Low-level input handling with lookahead and position tracking
2. **Tokenizer**: RTF token identification including control words, groups, and text
3. **Parser**: State machine that processes tokens into semantic RTF elements
4. **Event Handler System**: SAX-style callbacks for streaming processing

## Building and Running

To build the project:

```bash
zig build
```

To run the tests:

```bash
zig build test
```

To run the demo application:

```bash
./zig-out/bin/zig_rtf
```

## Example Usage

### Using ZigRTF in Zig

```zig
// Initialize the parser components
var stream = ByteStream.initMemory(rtf_content);
var tokenizer = Tokenizer.init(&stream, allocator);
defer tokenizer.deinit();

// Create an event handler with callbacks
const handler = EventHandler{
    .onGroupStart = null,
    .onGroupEnd = null,
    .onText = textCallback,
    .onCharacter = null,
    .onError = null,
};

// Create and run the parser
var parser = try Parser.init(&tokenizer, allocator, handler);
defer parser.deinit();
try parser.parse();
```

### Using ZigRTF from C

ZigRTF provides C bindings that make it easy to use the library from C applications:

```c
// Create a parser
RtfParser* parser = rtf_parser_create();

// Set up callbacks for events
rtf_parser_set_callbacks(
    parser,
    text_callback,
    group_start_callback,
    group_end_callback,
    user_data
);

// Parse an RTF document from memory
bool success = rtf_parser_parse_memory(parser, rtf_data, file_size);

// Clean up when done
rtf_parser_destroy(parser);
```

See the [C bindings example](examples/c_bindings/README.md) for more details.

A simpler, working [minimal C binding example](examples/minimal_c_binding/README.md) is also available.

## Roadmap

- Font and color table support
- Table formatting
- Advanced text and paragraph formatting
- Image handling
- Document object model (DOM) support
- HTML and plain text output
- Unicode and other character set support
