#!/bin/bash

# Stop on any error
set -e

echo "===== ZigRTF: Memory Mapping Benchmark ====="
echo ""

# Build our specialized test
echo "Building mmap benchmark..."
zig build-exe mmap_test.zig -lc -OReleaseFast

# Run in release mode to get the best measurements
echo ""
echo "Running memory mapping benchmark..."
./mmap_test

echo ""
echo "===== Memory Mapping Benchmark Complete ====="