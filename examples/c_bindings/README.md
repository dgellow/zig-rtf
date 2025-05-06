# ZigRTF C Bindings Example

This example demonstrates how to use the ZigRTF parser from C code.

## Overview

The example shows:

1. How to create and initialize the RTF parser
2. Setting up callbacks to receive text and group events
3. Parsing an RTF file and tracking style information
4. Getting statistics from the parsed document

## Building the Example

First, build the ZigRTF library and the C example:

```bash
# Build the ZigRTF library and install headers
cd /home/sam/zig-rtf
zig build

# Build the C example
zig build c-example
```

Alternatively, you can build just the C example manually:

```bash
cd /home/sam/zig-rtf/examples/c_bindings
make
```

## Running the Example

To run the example with the included sample RTF file:

```bash
cd /home/sam/zig-rtf/examples/c_bindings
make run
```

Or run it directly with any RTF file:

```bash
LD_LIBRARY_PATH=../../zig-out/lib ./rtf_example ../../test/data/simple.rtf
```

## C API Usage

The C API provides a simple interface for parsing RTF documents and receiving events:

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

## Example Output

When run with the included sample RTF file, the example will output information about the parsed RTF document, including text content and style information:

```
Parsing RTF file: ../../test/data/simple.rtf (241 bytes)
GROUP START
TEXT: "Times New Roman;" (bold=0, italic=0)
GROUP END
GROUP START
TEXT: ";" (bold=0, italic=0)
TEXT: ";" (bold=0, italic=0)
TEXT: ";" (bold=0, italic=0)
GROUP END
TEXT: "This is some " (bold=0, italic=0)
TEXT: "bold" (bold=1, italic=0)
TEXT: " and " (bold=0, italic=0)
TEXT: "italic" (bold=0, italic=1)
TEXT: " text." (bold=0, italic=0)
TEXT: "This text is blue." (bold=0, italic=0)

SUMMARY:
- Text segments: 11
- Bold segments: 1
- Italic segments: 1
- Groups: 2

Parsing completed successfully
```