# ZigRTF 2.0 Makefile
# Simple wrapper around zig build

.PHONY: all build test run clean c-example

all: build

build:
	zig build

test:
	zig build test

run:
	zig build run

c-example:
	zig build c-example

clean:
	rm -rf zig-cache zig-out .zig-cache
	rm -f test_*.rtf
	rm -f c_example
	rm -f extreme_benchmark
	rm -f quick_large_test

help:
	@echo "ZigRTF 2.0 - Fast RTF Parser"
	@echo ""
	@echo "Available targets:"
	@echo "  make         - Build libraries and executable"
	@echo "  make test    - Run tests"
	@echo "  make run     - Run demo application"
	@echo "  make c-example - Build C example"
	@echo "  make clean   - Remove build artifacts"