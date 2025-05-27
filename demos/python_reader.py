#!/usr/bin/env python3
"""
Python RTF Reader Demo
Uses ZigRTF C Library via ctypes
"""

import ctypes
import sys
import os
import time
from pathlib import Path

# Find our compiled library
def find_library():
    """Find the ZigRTF shared library"""
    # Look in zig-out/lib/ for the shared library
    lib_dir = Path(__file__).parent.parent / "zig-out" / "lib"
    
    # Try different library names/extensions
    candidates = [
        lib_dir / "libzigrtf.so",      # Linux
        lib_dir / "libzigrtf.dylib",   # macOS  
        lib_dir / "zigrtf.dll",        # Windows
        lib_dir / "libzigrtf.dll",     # Windows alternative
    ]
    
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    
    # If not found, try building it
    print("Library not found, attempting to build...")
    os.system("cd .. && zig build")
    
    # Try again
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    
    raise FileNotFoundError("Could not find ZigRTF shared library. Run 'zig build' first.")

# Load library and define C API
def setup_rtf_api():
    """Setup the RTF API using ctypes"""
    lib_path = find_library()
    lib = ctypes.CDLL(lib_path)
    
    # Define C structures and function signatures
    
    # rtf_document* rtf_parse(const void* data, size_t length)
    lib.rtf_parse.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    lib.rtf_parse.restype = ctypes.c_void_p
    
    # void rtf_free(rtf_document* doc)
    lib.rtf_free.argtypes = [ctypes.c_void_p]
    lib.rtf_free.restype = None
    
    # const char* rtf_get_text(rtf_document* doc)
    lib.rtf_get_text.argtypes = [ctypes.c_void_p]
    lib.rtf_get_text.restype = ctypes.c_char_p
    
    # size_t rtf_get_text_length(rtf_document* doc)
    lib.rtf_get_text_length.argtypes = [ctypes.c_void_p]
    lib.rtf_get_text_length.restype = ctypes.c_size_t
    
    # size_t rtf_get_run_count(rtf_document* doc)
    lib.rtf_get_run_count.argtypes = [ctypes.c_void_p]
    lib.rtf_get_run_count.restype = ctypes.c_size_t
    
    # const char* rtf_errmsg()
    lib.rtf_errmsg.argtypes = []
    lib.rtf_errmsg.restype = ctypes.c_char_p
    
    return lib

class RTFDocument:
    """Python wrapper for RTF document"""
    
    def __init__(self, rtf_data: bytes):
        self.lib = setup_rtf_api()
        self.doc_ptr = None
        
        # Parse RTF data
        data_ptr = ctypes.c_char_p(rtf_data)
        self.doc_ptr = self.lib.rtf_parse(data_ptr, len(rtf_data))
        
        if not self.doc_ptr:
            error_msg = self.lib.rtf_errmsg()
            if error_msg:
                raise RuntimeError(f"RTF parsing failed: {error_msg.decode('utf-8')}")
            else:
                raise RuntimeError("RTF parsing failed: Unknown error")
    
    def __del__(self):
        """Clean up document"""
        if self.doc_ptr:
            self.lib.rtf_free(self.doc_ptr)
    
    def get_text(self) -> str:
        """Get extracted text"""
        if not self.doc_ptr:
            return ""
        
        text_ptr = self.lib.rtf_get_text(self.doc_ptr)
        if text_ptr:
            return text_ptr.decode('utf-8')
        return ""
    
    def get_text_length(self) -> int:
        """Get text length"""
        if not self.doc_ptr:
            return 0
        return self.lib.rtf_get_text_length(self.doc_ptr)
    
    def get_run_count(self) -> int:
        """Get number of text runs"""
        if not self.doc_ptr:
            return 0
        return self.lib.rtf_get_run_count(self.doc_ptr)

def print_header():
    """Print demo header"""
    print()
    print("╔════════════════════════════════════════════════════════════════════════════╗")
    print("║                           Python RTF Reader Demo                          ║")
    print("║                     The Ultimate RTF Parsing Library                     ║")
    print("╚════════════════════════════════════════════════════════════════════════════╝")
    print()

def print_separator():
    """Print separator line"""
    print("─" * 80)

def main():
    """Main function"""
    if len(sys.argv) != 2:
        print("Python RTF Reader Demo")
        print(f"Usage: {sys.argv[0]} <rtf_file>")
        print("\nExample RTF files in test/data/:")
        print("  - simple.rtf")
        print("  - wordpad_sample.rtf") 
        print("  - complex_mixed.rtf")
        return
    
    filename = sys.argv[1]
    
    try:
        # Read RTF file
        with open(filename, 'rb') as f:
            content = f.read()
        
        # Parse RTF
        start_time = time.time()
        doc = RTFDocument(content)
        end_time = time.time()
        parse_time_ms = (end_time - start_time) * 1000
        
        text = doc.get_text()
        text_length = doc.get_text_length()
        run_count = doc.get_run_count()
        
        # Display results
        print_header()
        print(f"File: {filename}")
        print(f"RTF Size: {len(content)} bytes")
        print(f"Text Length: {text_length} characters")
        print(f"Text Runs: {run_count}")
        print(f"Parse Time: {parse_time_ms:.2f} ms")
        print_separator()
        
        print("Extracted Text:")
        print_separator()
        
        if not text:
            print("(No text content found)")
        else:
            # Print text with line numbers for better readability
            lines = text.split('\n')
            line_num = 1
            
            for line in lines:
                cleaned_line = line.strip()
                if cleaned_line:
                    print(f"{line_num:3}: {cleaned_line}")
                    line_num += 1
        
        print_separator()
        print("✓ Successfully parsed RTF document!")
        print("  Powered by ZigRTF - The Ultimate RTF Library")
        
    except FileNotFoundError:
        print(f"Error: Could not open file '{filename}'")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()