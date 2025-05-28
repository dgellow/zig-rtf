# ZigRTF

Thread-safe RTF parser and generator written in Zig with a C API.

## Features

- **Bidirectional RTF processing** - Parse AND generate RTF documents
- **Round-trip capability** - Parse → generate → parse perfectly
- **Complete formatting support** - Bold, italic, underline, fonts, colors
- **Complex content** - Tables, images, hyperlinks, nested structures
- **Thread-safe** - Parse/generate from any thread
- **Memory-safe** - Arena allocation with zero leaks
- **C API** - SQLite-inspired interface for any language
- **Robust** - Handles malformed RTF gracefully

## Building

```sh
zig build
```

Output:
- `zig-out/lib/libzigrtf.a` - Static library
- `zig-out/lib/libzigrtf.so` - Shared library  
- `zig-out/include/zigrtf.h` - C header file
- Demo applications in `zig-out/bin/`

## C API Usage

```c
#include "src/c_api.h"

// Parse from memory
rtf_document* doc = rtf_parse(data, length);
if (!doc) {
    printf("Error: %s\n", rtf_errmsg());
    return;
}

// Get plain text
const char* text = rtf_get_text(doc);

// Get formatted runs
size_t count = rtf_get_run_count(doc);
for (size_t i = 0; i < count; i++) {
    const rtf_run* run = rtf_get_run(doc, i);
    printf("%s", run->text);
    if (run->bold) printf(" [BOLD]");
}

// Generate RTF back
char* rtf_output = rtf_generate(doc);
printf("Generated RTF: %s\n", rtf_output);
rtf_free_string(rtf_output);

rtf_free(doc);
```

## Zig API Usage

```zig
const std = @import("std");
const rtf = @import("src/rtf.zig");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();

var reader = rtf.ByteReader.init(data);
var parser = rtf.Parser.init(arena.allocator());

const document = try parser.parse(&reader);
const text = document.getPlainText();
```

## Supported RTF Features

- **Text extraction and generation** - Clean UTF-8 output and input
- **Character formatting** - Bold, italic, underline, fonts, colors, sizes
- **Document structure** - Paragraphs, line breaks, page breaks
- **Tables** - Complete table support with cells, rows, formatting
- **Images** - PNG, JPEG, WMF, EMF with proper hex encoding
- **Hyperlinks** - URL and email links with display text
- **Group nesting** - 100+ level deep nesting support
- **Control words** - Full RTF 1.9 specification coverage
- **Binary data** - `\bin` control word handling
- **Hex escapes** - `\'XX` sequences
- **Unicode** - `\uNNNN` with proper fallback handling
- **Font/color tables** - Complete parsing and generation
- **Ignorable destinations** - `{\*\...}` handling
- **Round-trip** - Parse → generate → parse with perfect fidelity

## Architecture

Modular design with clean separation:
- `formatted_parser.zig` - Complete RTF parser with formatting
- `document_model.zig` - Document structure with generation capability
- `table_parser.zig` - Specialized table parsing
- `c_api.zig` - SQLite-style C interface

Key components:
- `ByteReader` - 1KB buffered input for optimal performance
- `FormattedParser` - State machine with format and destination stacks
- `Document` - Complete document model with arena allocation
- `generateRtf()` - Creates valid RTF from document model

C API provides opaque handles with clear ownership and thread-safe operation.

## Testing

```sh
zig build test
```

Includes 130+ tests in 8 dedicated test suites:
- **Real-world files** - WordPad, TextEdit, RichEdit samples
- **Complex content** - Images, tables, hyperlinks, objects
- **RTF generation** - Round-trip testing and validation
- **Security** - Malformed input, buffer overflows, edge cases
- **Thread safety** - Concurrent parsing and stress testing
- **C API** - Interface correctness and memory safety
- **Performance** - Large document handling and benchmarks
- **Formatting** - Complete character and paragraph formatting

## Examples

Three demo applications in `demos/`:
- `zig_reader.zig` - Native Zig implementation
- `c_reader.c` - C using the library
- `python_reader.py` - Python using ctypes

All demonstrate identical parsing behavior.

## Memory Management

- Parser copies input data - caller can free immediately
- Single `rtf_free()` call releases all memory
- Thread-safe parsing and document access
- No memory leaks under normal or error conditions

## Performance

Designed for efficiency:
- 1KB read buffer for optimal I/O
- Arena allocation minimizes malloc overhead
- Enum-based control word lookup
- Zero-copy text references where possible

~7200 lines of clean, well-tested Zig code.