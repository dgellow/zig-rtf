/*
 * C RTF Reader Demo  
 * Uses ZigRTF C API directly
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Include our RTF library header
#include "../src/c_api.h"

void print_header(void) {
    printf("\n");
    printf("╔════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                             C RTF Reader Demo                             ║\n");
    printf("║                     The Ultimate RTF Parsing Library                     ║\n");
    printf("╚════════════════════════════════════════════════════════════════════════════╝\n");
    printf("\n");
}

void print_separator(void) {
    printf("────────────────────────────────────────────────────────────────────────────\n");
}

char* read_file(const char* filename, size_t* size) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        return NULL;
    }
    
    // Get file size
    fseek(file, 0, SEEK_END);
    *size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    // Allocate buffer
    char* buffer = malloc(*size + 1);
    if (!buffer) {
        fclose(file);
        return NULL;
    }
    
    // Read file
    size_t bytes_read = fread(buffer, 1, *size, file);
    buffer[bytes_read] = '\0';
    *size = bytes_read;
    
    fclose(file);
    return buffer;
}

void print_text_with_line_numbers(const char* text) {
    if (!text || strlen(text) == 0) {
        printf("(No text content found)\n");
        return;
    }
    
    char* text_copy = strdup(text);
    char* line = strtok(text_copy, "\n");
    int line_num = 1;
    
    while (line != NULL) {
        // Trim whitespace
        while (*line && (*line == ' ' || *line == '\t' || *line == '\r')) {
            line++;
        }
        
        // Remove trailing whitespace
        int len = strlen(line);
        while (len > 0 && (line[len-1] == ' ' || line[len-1] == '\t' || line[len-1] == '\r')) {
            line[--len] = '\0';
        }
        
        if (len > 0) {
            printf("%3d: %s\n", line_num++, line);
        }
        
        line = strtok(NULL, "\n");
    }
    
    free(text_copy);
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        printf("C RTF Reader Demo\n");
        printf("Usage: %s <rtf_file>\n", argv[0]);
        printf("\nExample RTF files in test/data/:\n");
        printf("  - simple.rtf\n");
        printf("  - wordpad_sample.rtf\n");
        printf("  - complex_mixed.rtf\n");
        return 1;
    }
    
    const char* filename = argv[1];
    
    // Read RTF file
    size_t file_size;
    char* content = read_file(filename, &file_size);
    if (!content) {
        printf("Error: Could not open file '%s'\n", filename);
        return 1;
    }
    
    // Parse RTF
    clock_t start_time = clock();
    rtf_document* doc = rtf_parse(content, file_size);
    clock_t end_time = clock();
    
    if (!doc) {
        printf("Error: Failed to parse RTF: %s\n", rtf_errmsg());
        free(content);
        return 1;
    }
    
    double parse_time_ms = ((double)(end_time - start_time) / CLOCKS_PER_SEC) * 1000.0;
    
    // Get document information
    const char* text = rtf_get_text(doc);
    size_t text_length = rtf_get_text_length(doc);
    size_t run_count = rtf_get_run_count(doc);
    
    // Display results
    print_header();
    printf("File: %s\n", filename);
    printf("RTF Size: %zu bytes\n", file_size);
    printf("Text Length: %zu characters\n", text_length);
    printf("Text Runs: %zu\n", run_count);
    printf("Parse Time: %.2f ms\n", parse_time_ms);
    print_separator();
    
    printf("Extracted Text:\n");
    print_separator();
    
    print_text_with_line_numbers(text);
    
    print_separator();
    printf("✓ Successfully parsed RTF document!\n");
    printf("  Powered by ZigRTF - The Ultimate RTF Library\n");
    
    // Cleanup
    rtf_free(doc);
    free(content);
    
    return 0;
}