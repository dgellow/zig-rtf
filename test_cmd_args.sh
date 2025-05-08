#!/bin/bash
# Test script to demonstrate command-line arguments

# Build the project
echo "Building the project..."
zig build

# Run with default test file (should auto-detect)
echo -e "\n\nRunning with auto-detected test file:"
./zig-out/bin/zig_rtf | head -n 10

# Run with specific test file
echo -e "\n\nRunning with specified test file:"
./zig-out/bin/zig_rtf test/data/simple.rtf | head -n 10

# Try with a non-existent file - should show error
echo -e "\n\nRunning with non-existent file (should show error):"
./zig-out/bin/zig_rtf non_existent_file.rtf