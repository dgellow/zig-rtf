#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ZigRTF C API declarations
typedef struct RtfParser RtfParser;

typedef struct {
    int bold;
    int italic;
    int underline;
    int font_size;
} RtfStyle;

typedef void (*RtfTextCallback)(void* user_data, const char* text, size_t length, RtfStyle style);
typedef void (*RtfGroupCallback)(void* user_data);

extern RtfParser* rtf_parser_create(void);
extern void rtf_parser_destroy(RtfParser* parser);
extern void rtf_parser_set_callbacks(
    RtfParser* parser,
    RtfTextCallback text_callback,
    RtfGroupCallback group_start_callback,
    RtfGroupCallback group_end_callback,
    void* user_data
);
extern int rtf_parser_parse_memory(RtfParser* parser, const char* data, size_t length);

// User context struct
typedef struct {
    int text_count;
    int bold_count;
    int italic_count;
} UserContext;

// Callback function for text events
void on_text(void* user_data, const char* text, size_t length, RtfStyle style) {
    UserContext* ctx = (UserContext*)user_data;
    ctx->text_count++;
    
    if (style.bold) ctx->bold_count++;
    if (style.italic) ctx->italic_count++;
    
    printf("TEXT: ");
    fwrite(text, 1, length, stdout);
    printf(" (bold=%d, italic=%d)\n", style.bold, style.italic);
}

// Simple RTF sample
const char* sample_rtf = "{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0\\froman\\fcharset0 Times New Roman;}}\\f0\\fs24 This is \\b bold\\b0 and \\i italic\\i0 text.}";

int main() {
    // Initialize user context
    UserContext ctx = {0};
    
    // Create RTF parser
    RtfParser* parser = rtf_parser_create();
    if (!parser) {
        fprintf(stderr, "Failed to create RTF parser\n");
        return 1;
    }
    
    // Set up callbacks
    rtf_parser_set_callbacks(
        parser,
        on_text,
        NULL,  // No group start callback
        NULL,  // No group end callback
        &ctx
    );
    
    // Parse the RTF data
    printf("Parsing sample RTF...\n");
    int success = rtf_parser_parse_memory(parser, sample_rtf, strlen(sample_rtf));
    
    // Check result and print statistics
    if (success) {
        printf("\nSUMMARY:\n");
        printf("- Text segments: %d\n", ctx.text_count);
        printf("- Bold segments: %d\n", ctx.bold_count);
        printf("- Italic segments: %d\n", ctx.italic_count);
        printf("\nParsing completed successfully!\n");
    } else {
        fprintf(stderr, "Failed to parse RTF data\n");
    }
    
    // Clean up
    rtf_parser_destroy(parser);
    
    return success ? 0 : 1;
}