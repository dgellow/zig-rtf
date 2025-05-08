#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zigrtf_unified.h"

// Sample RTF document for testing
const char* SAMPLE_RTF = "{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0\\froman\\fcharset0 Times New Roman;}}"
                         "\\viewkind4\\uc1\\pard\\f0\\fs24 This is normal text. "
                         "\\b This is bold text. \\b0 "
                         "\\i This is italic text. \\i0 "
                         "\\ul This is underlined text. \\ulnone "
                         "\\b\\i This is bold-italic text. \\i0\\b0 "
                         "}";

// Structure for user data
typedef struct {
    // Common statistics
    int text_segments;
    int characters;
    
    // Style statistics
    int bold_segments;
    int italic_segments;
    int underline_segments;
    
    // Error tracking
    int error_count;
    char last_error[256];
    char last_error_position[64];
} UserData;

/****************************************************************************
 * Simple API example functions
 ****************************************************************************/

// Simple API text callback
void simple_text_callback(void* user_data, const char* text, size_t length, RtfStyleInt style) {
    UserData* data = (UserData*)user_data;
    data->text_segments++;
    data->characters += length;
    
    if (style.bold) data->bold_segments++;
    if (style.italic) data->italic_segments++;
    if (style.underline) data->underline_segments++;
    
    printf("[SIMPLE] Text: '");
    fwrite(text, 1, length, stdout);
    printf("' (bold=%d, italic=%d, underline=%d)\n", 
           style.bold, style.italic, style.underline);
}

// Simple API group start callback
void simple_group_start_callback(void* user_data) {
    (void)user_data; // Unused
    printf("[SIMPLE] Group start\n");
}

// Simple API group end callback
void simple_group_end_callback(void* user_data) {
    (void)user_data; // Unused
    printf("[SIMPLE] Group end\n");
}

// Function to demonstrate the simple API
void demonstrate_simple_api(void) {
    printf("\n====== DEMONSTRATING SIMPLE API ======\n\n");
    
    // Initialize user data
    UserData user_data = {0};
    
    // Create parser
    RtfParser* parser = rtf_unified_simple_create();
    if (!parser) {
        fprintf(stderr, "Error: Failed to create RTF parser\n");
        return;
    }
    
    // Set callbacks
    rtf_unified_simple_set_callbacks(
        parser,
        simple_text_callback,
        simple_group_start_callback,
        simple_group_end_callback,
        &user_data
    );
    
    // Parse RTF data
    printf("Parsing RTF data with simple API...\n\n");
    int success = rtf_unified_simple_parse_memory(parser, SAMPLE_RTF, strlen(SAMPLE_RTF));
    
    // Print results
    printf("\nSimple API Results:\n");
    printf("- Parse %s\n", success ? "succeeded" : "failed");
    printf("- Text segments: %d\n", user_data.text_segments);
    printf("- Total characters: %d\n", user_data.characters);
    printf("- Bold segments: %d\n", user_data.bold_segments);
    printf("- Italic segments: %d\n", user_data.italic_segments);
    printf("- Underline segments: %d\n", user_data.underline_segments);
    
    // Clean up
    rtf_unified_simple_destroy(parser);
}

/****************************************************************************
 * Advanced API example functions
 ****************************************************************************/

// Advanced API text callback
void advanced_text_callback(void* user_data, const char* text, size_t length, RtfStyle style) {
    UserData* data = (UserData*)user_data;
    data->text_segments++;
    data->characters += length;
    
    if (style.bold) data->bold_segments++;
    if (style.italic) data->italic_segments++;
    if (style.underline) data->underline_segments++;
    
    printf("[ADVANCED] Text: '");
    fwrite(text, 1, length, stdout);
    printf("' (bold=%s, italic=%s, underline=%s, font_size=%u)\n", 
           style.bold ? "true" : "false", 
           style.italic ? "true" : "false", 
           style.underline ? "true" : "false",
           style.font_size);
}

// Advanced API group start callback
void advanced_group_start_callback(void* user_data) {
    (void)user_data; // Unused
    printf("[ADVANCED] Group start\n");
}

// Advanced API group end callback
void advanced_group_end_callback(void* user_data) {
    (void)user_data; // Unused
    printf("[ADVANCED] Group end\n");
}

// Advanced API error callback
void advanced_error_callback(void* user_data, const char* position, const char* message) {
    UserData* data = (UserData*)user_data;
    data->error_count++;
    
    snprintf(data->last_error, sizeof(data->last_error), "%s", message);
    snprintf(data->last_error_position, sizeof(data->last_error_position), "%s", position);
    
    printf("[ADVANCED] Error at %s: %s\n", position, message);
}

// Advanced API character callback
void advanced_char_callback(void* user_data, uint8_t character, RtfStyle style) {
    (void)user_data; // Unused
    printf("[ADVANCED] Character: '%c' (bold=%s, italic=%s, underline=%s)\n", 
           character,
           style.bold ? "true" : "false", 
           style.italic ? "true" : "false", 
           style.underline ? "true" : "false");
}

// Function to demonstrate the advanced API
void demonstrate_advanced_api(bool use_strict_mode) {
    printf("\n====== DEMONSTRATING ADVANCED API (%s MODE) ======\n\n",
           use_strict_mode ? "STRICT" : "TOLERANT");
    
    // Initialize user data
    UserData user_data = {0};
    
    // Create parser
    RtfParser* parser = rtf_unified_create();
    if (!parser) {
        fprintf(stderr, "Error: Failed to create RTF parser\n");
        return;
    }
    
    // Set callbacks
    rtf_unified_set_callbacks(
        parser,
        advanced_text_callback,
        advanced_group_start_callback,
        advanced_group_end_callback,
        &user_data
    );
    
    // Set extended callbacks
    rtf_unified_set_extended_callbacks(
        parser,
        advanced_error_callback,
        advanced_char_callback
    );
    
    // Parse RTF data with recovery options
    printf("Parsing RTF data with advanced API...\n\n");
    bool success = rtf_unified_parse_memory_with_recovery(
        parser, 
        SAMPLE_RTF, 
        strlen(SAMPLE_RTF),
        use_strict_mode
    );
    
    // Print results
    printf("\nAdvanced API Results (%s mode):\n", use_strict_mode ? "strict" : "tolerant");
    printf("- Parse %s\n", success ? "succeeded" : "failed");
    printf("- Text segments: %d\n", user_data.text_segments);
    printf("- Total characters: %d\n", user_data.characters);
    printf("- Bold segments: %d\n", user_data.bold_segments);
    printf("- Italic segments: %d\n", user_data.italic_segments);
    printf("- Underline segments: %d\n", user_data.underline_segments);
    printf("- Error count: %d\n", user_data.error_count);
    
    if (user_data.error_count > 0) {
        printf("- Last error: %s at %s\n", 
               user_data.last_error, 
               user_data.last_error_position);
    }
    
    // Get last error code
    int error_code = rtf_unified_get_last_error(parser);
    printf("- Last error code: %d\n", error_code);
    
    // Clean up
    rtf_unified_destroy(parser);
}

// Function to create and parse a malformed RTF document
void demonstrate_error_handling(void) {
    printf("\n====== DEMONSTRATING ERROR HANDLING ======\n\n");
    
    // Create a malformed RTF document (unbalanced braces)
    const char* MALFORMED_RTF = "{\\rtf1\\ansi This is {malformed RTF.}";
    
    // Initialize user data
    UserData user_data = {0};
    
    // Create parser
    RtfParser* parser = rtf_unified_create();
    if (!parser) {
        fprintf(stderr, "Error: Failed to create RTF parser\n");
        return;
    }
    
    // Set callbacks
    rtf_unified_set_callbacks(
        parser,
        advanced_text_callback,
        advanced_group_start_callback,
        advanced_group_end_callback,
        &user_data
    );
    
    // Set extended callbacks
    rtf_unified_set_extended_callbacks(
        parser,
        advanced_error_callback,
        NULL  // No character callback needed
    );
    
    // Parse with tolerant mode - should succeed despite errors
    printf("Parsing malformed RTF with tolerant mode...\n\n");
    bool tolerant_success = rtf_unified_parse_memory_with_recovery(
        parser, 
        MALFORMED_RTF, 
        strlen(MALFORMED_RTF),
        false  // tolerant mode
    );
    
    // Print results from tolerant parsing
    printf("\nError Handling Results (tolerant mode):\n");
    printf("- Parse %s\n", tolerant_success ? "succeeded" : "failed");
    printf("- Error count: %d\n", user_data.error_count);
    if (user_data.error_count > 0) {
        printf("- Last error: %s at %s\n", 
               user_data.last_error, 
               user_data.last_error_position);
    }
    
    // Reset user data
    user_data = (UserData){0};
    rtf_unified_destroy(parser);
    
    // Create a new parser for strict mode test
    parser = rtf_unified_create();
    if (!parser) {
        fprintf(stderr, "Error: Failed to create RTF parser\n");
        return;
    }
    
    // Set callbacks again for the new parser
    rtf_unified_set_callbacks(
        parser,
        advanced_text_callback,
        advanced_group_start_callback,
        advanced_group_end_callback,
        &user_data
    );
    
    // Set extended callbacks
    rtf_unified_set_extended_callbacks(
        parser,
        advanced_error_callback,
        NULL  // No character callback needed
    );
    
    // Parse with strict mode - should fail on first error
    printf("\nParsing malformed RTF with strict mode...\n\n");
    bool strict_success = rtf_unified_parse_memory_with_recovery(
        parser, 
        MALFORMED_RTF, 
        strlen(MALFORMED_RTF),
        true  // strict mode
    );
    
    // Print results from strict parsing
    printf("\nError Handling Results (strict mode):\n");
    printf("- Parse %s\n", strict_success ? "succeeded" : "failed");
    printf("- Error count: %d\n", user_data.error_count);
    if (user_data.error_count > 0) {
        printf("- Last error: %s at %s\n", 
               user_data.last_error, 
               user_data.last_error_position);
    }
    
    // Clean up
    rtf_unified_destroy(parser);
}

int main(void) {
    printf("ZigRTF Unified C API Example\n");
    printf("============================\n");
    
    // Demonstrate simple API usage
    demonstrate_simple_api();
    
    // Demonstrate advanced API usage with tolerant error recovery
    demonstrate_advanced_api(false);  // false = tolerant mode
    
    // Demonstrate advanced API usage with strict error handling
    demonstrate_advanced_api(true);   // true = strict mode
    
    // Demonstrate error handling with malformed RTF
    demonstrate_error_handling();
    
    return 0;
}