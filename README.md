# ZigRTF

Thread-safe RTF parser written in Zig with a C API.

## Features

- Text extraction from RTF documents
- Character formatting (bold, italic, underline, font size, color)
- Thread-safe parsing and document access
- Memory-safe with arena allocation
- C API for cross-language integration
- Handles malformed RTF gracefully

## Building

```sh
zig build
```

Output:
- `zig-out/lib/libzigrtf.a` - Static library
- `zig-out/lib/libzigrtf.so` - Shared library  
- `src/c_api.h` - C header file

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

- Text content extraction
- Character formatting preservation
- Group nesting and state management
- Control word parsing
- Binary data handling (`\bin`)
- Hex escape sequences (`\'XX`)
- Unicode support (`\uNNNN`)
- Font and color table parsing
- Ignorable destinations (`{\*\...}`)

## Architecture

Single-module design (`src/rtf.zig`) with:
- `ByteReader` - 1KB buffered input
- `Parser` - State machine with format stack
- `Document` - Text runs with formatting
- Arena allocation for memory safety

C API (`src/c_api.zig`) provides SQLite-style interface with opaque handles and clear ownership.

## Testing

```sh
zig build test
```

Includes 100+ tests covering:
- Real-world RTF files (WordPad, TextEdit, RichEdit)
- Complex content (images, tables, hyperlinks) 
- Malformed input handling
- Thread safety
- C API security

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

~9000 lines of Zig code total.