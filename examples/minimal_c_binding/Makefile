all: build example

build:
	zig build

example: 
	gcc -Wall -o example example.c -L./zig-out/lib -Wl,-rpath,./zig-out/lib -lzigrtf_minimal

run: example
	LD_LIBRARY_PATH=./zig-out/lib ./example

clean:
	rm -f example
	rm -rf zig-out zig-cache