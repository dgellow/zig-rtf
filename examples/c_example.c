/*
 * ZigRTF C API Example
 * 
 * Demonstrates the joy of parsing RTF with a SQLite-inspired API
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../src/c_api.h"

void print_separator(void) {
    printf("================================================================================\n");
}

void example_parse_memory(void) {
    printf("Example 1: Parse RTF from memory\n");
    print_separator();
    
    // Sample RTF data
    const char* rtf_data = "{\\rtf1\\ansi Hello \\b bold\\b0 and \\i italic\\i0 world!}";
    
    // Parse it - dead simple!
    rtf_document* doc = rtf_parse(rtf_data, strlen(rtf_data));
    if (!doc) {
        printf("Parse error: %s\n", rtf_errmsg());
        return;
    }
    
    // Get plain text
    printf("Plain text: '%s'\n", rtf_get_text(doc));
    printf("Text length: %zu bytes\n", rtf_get_text_length(doc));
    
    // Show formatted runs
    size_t run_count = rtf_get_run_count(doc);
    printf("Number of runs: %zu\n", run_count);
    
    for (size_t i = 0; i < run_count; i++) {
        const rtf_run* run = rtf_get_run(doc, i);
        printf("Run %zu: '%s'", i, run->text);
        
        if (run->bold) printf(" [BOLD]");
        if (run->italic) printf(" [ITALIC]");
        if (run->underline) printf(" [UNDERLINE]");
        if (run->font_size > 0) printf(" [SIZE=%d]", run->font_size);
        if (run->color > 0) printf(" [COLOR=0x%06X]", run->color);
        
        printf("\n");
    }
    
    // Clean up - one call frees everything
    rtf_free(doc);
    printf("\n");
}

void example_parse_file(void) {
    printf("Example 2: Parse RTF from file\n");
    print_separator();
    
    // Try to parse a test file
    rtf_document* doc = rtf_parse_file("../test/data/simple.rtf");
    if (!doc) {
        printf("Could not parse file: %s\n", rtf_errmsg());
        printf("(This is expected if test file doesn't exist)\n\n");
        return;
    }
    
    printf("Successfully parsed file!\n");
    printf("Text length: %zu bytes\n", rtf_get_text_length(doc));
    printf("Number of runs: %zu\n", rtf_get_run_count(doc));
    
    // Show first 100 characters
    const char* text = rtf_get_text(doc);
    size_t len = rtf_get_text_length(doc);
    size_t preview_len = len > 100 ? 100 : len;
    
    printf("Preview: '");
    for (size_t i = 0; i < preview_len; i++) {
        if (text[i] == '\n') printf("\\n");
        else if (text[i] == '\t') printf("\\t");
        else printf("%c", text[i]);
    }
    if (len > 100) printf("...");
    printf("'\n");
    
    rtf_free(doc);
    printf("\n");
}

void example_parse_stream(void) {
    printf("Example 3: Parse RTF from stream (FILE*)\n");
    print_separator();
    
    // Create a temporary RTF file
    FILE* temp_file = fopen("temp_example.rtf", "w");
    if (!temp_file) {
        printf("Could not create temporary file\n\n");
        return;
    }
    
    // Write some RTF content
    const char* content = "{\\rtf1\\ansi\\deff0 "
                         "This is a \\b streaming\\b0 example with \\i multiple\\i0 formats!\\par "
                         "Second paragraph with \\ul underlined\\ul0 text.}";
    fwrite(content, 1, strlen(content), temp_file);
    fclose(temp_file);
    
    // Now parse using stream API
    FILE* read_file = fopen("temp_example.rtf", "rb");
    if (!read_file) {
        printf("Could not open file for reading\n\n");
        return;
    }
    
    rtf_reader reader = rtf_file_reader(read_file);
    rtf_document* doc = rtf_parse_stream(&reader);
    fclose(read_file);
    
    if (!doc) {
        printf("Parse error: %s\n", rtf_errmsg());
        remove("temp_example.rtf");
        return;
    }
    
    printf("Parsed from stream successfully!\n");
    printf("Text: '%s'\n", rtf_get_text(doc));
    printf("Runs: %zu\n", rtf_get_run_count(doc));
    
    rtf_free(doc);
    remove("temp_example.rtf");
    printf("\n");
}

void example_error_handling(void) {
    printf("Example 4: Error handling\n");
    print_separator();
    
    // Try to parse invalid RTF
    const char* bad_rtf = "This is not RTF at all!";
    rtf_document* doc = rtf_parse(bad_rtf, strlen(bad_rtf));
    
    if (!doc) {
        printf("Expected error occurred: %s\n", rtf_errmsg());
    } else {
        printf("Unexpected: invalid RTF was parsed!\n");
        rtf_free(doc);
    }
    
    // Clear error state
    rtf_clear_error();
    printf("Error cleared. New error: %s\n", rtf_errmsg());
    printf("\n");
}

int main(void) {
    printf("ZigRTF C API Demo - The Joy of RTF Parsing\n");
    printf("Version: %s\n", rtf_version());
    print_separator();
    printf("\n");
    
    example_parse_memory();
    example_parse_file();
    example_parse_stream();
    example_error_handling();
    
    printf("Demo complete! Notice how simple and predictable the API is.\n");
    printf("No UI thread binding, no configuration, just parse and go!\n");
    
    return 0;
}