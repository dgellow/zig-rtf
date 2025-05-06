# ZigRTF Minimal C Binding Example

This example demonstrates how to create a C-compatible library in Zig and use it from C code.

## Overview

The example consists of:

1. A simple Zig library that provides RTF parsing functionality
2. A C header for accessing the library
3. A C program that uses the library functions

## Building and Running

```bash
# Build the Zig library
make build

# Build the C example
make example

# Run the example
make run
```

## C API

The C API is deliberately minimal for demonstration purposes:

```c
// Constants
extern const int RTF_BOLD;
extern const int RTF_ITALIC;
extern const int RTF_UNDERLINE;

// Simple info structure
typedef struct {
    int text_segments;
    int bold_segments;
    int italic_segments;
    int depth;
} RtfInfo;

// Function to parse an RTF string
int rtf_parse_string(const char* text, RtfInfo* info);

// Function to get the library version
const char* rtf_get_version(void);
```

## Implementation Notes

This example demonstrates several important concepts:

1. Exporting Zig functions and constants to C
2. Using the `extern struct` type for C-compatible structures
3. Creating a shared library in Zig
4. Proper C calling conventions with `callconv(.C)`
5. Handling C strings with null terminators
6. Using the C library from a C program