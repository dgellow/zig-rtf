CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -I. -I../../zig-out/include
LDFLAGS = -L../../zig-out/lib -Wl,-rpath,../../zig-out/lib -lzig_rtf

# Default target
all: rtf_example

# Build the C example
rtf_example: rtf_example.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Build the Zig library
../../zig-out/lib/libzig_rtf.a:
	@echo "Building ZigRTF library..."
	@cd ../../ && zig build

# Clean up
clean:
	rm -f rtf_example

# Run the example with simple.rtf
run: rtf_example
	@echo "Running example with ../../test/data/simple.rtf"
	@LD_LIBRARY_PATH=../../zig-out/lib ./rtf_example ../../test/data/simple.rtf

.PHONY: all clean run