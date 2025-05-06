#!/bin/bash
set -e

# Build the Zig library
echo "=== Building ZigRTF library ==="
cd ../../
zig build

# Build the C example
echo -e "\n=== Building C example ==="
cd examples/c_bindings
make clean
make

# Run the example
echo -e "\n=== Running C example ==="
LD_LIBRARY_PATH=../../zig-out/lib ./rtf_example ../../test/data/simple.rtf