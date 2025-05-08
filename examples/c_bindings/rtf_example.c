#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zigrtf.h"

/**
 * User data structure to track parsing results
 */
typedef struct {
    /* Statistics */
    int text_count;
    int bold_count;
    int italic_count;
    int strikethrough_count;
    int group_count;
    int superscript_count;
    int subscript_count;
    int error_count;
    int color_count;
    int font_count;
    
    /* Last error information */
    char last_error[256];
} UserData;

/**
 * Helper function to print style information
 */
void print_style(RtfStyleInfo style) {
    printf("Style: [");
    
    if (style.bold) printf("BOLD ");
    if (style.italic) printf("ITALIC ");
    if (style.underline) printf("UNDERLINE ");
    if (style.strikethrough) printf("STRIKETHROUGH ");
    if (style.superscript) printf("SUPERSCRIPT ");
    if (style.subscript) printf("SUBSCRIPT ");
    if (style.hidden) printf("HIDDEN ");
    if (style.all_caps) printf("ALL_CAPS ");
    if (style.small_caps) printf("SMALL_CAPS ");
    
    printf("Font: %d Size: %d ", style.font_index, style.font_size);
    
    if (style.foreground_color_index >= 0)
        printf("FG: %d ", style.foreground_color_index);
        
    if (style.background_color_index >= 0)
        printf("BG: %d ", style.background_color_index);
        
    printf("]");
}

/**
 * Callback for text events
 */
void text_callback(void* user_data, const char* text, size_t length, RtfStyleInfo style) {
    UserData* data = (UserData*)user_data;
    data->text_count++;
    
    if (style.bold) data->bold_count++;
    if (style.italic) data->italic_count++;
    if (style.strikethrough) data->strikethrough_count++;
    if (style.superscript) data->superscript_count++;
    if (style.subscript) data->subscript_count++;
    
    printf("TEXT: \"");
    fwrite(text, 1, length, stdout);
    printf("\" ");
    print_style(style);
    printf("\n");
}

/**
 * Callback for group start events
 */
void group_start_callback(void* user_data) {
    UserData* data = (UserData*)user_data;
    data->group_count++;
    printf("GROUP START\n");
}

/**
 * Callback for group end events
 */
void group_end_callback(void* user_data) {
    printf("GROUP END\n");
}

/**
 * Callback for error events
 */
void error_callback(void* user_data, RtfError error, const char* message) {
    UserData* data = (UserData*)user_data;
    data->error_count++;
    
    printf("ERROR: %s (code: %d)\n", message, error);
    
    // Store the last error message
    strncpy(data->last_error, message, sizeof(data->last_error) - 1);
    data->last_error[sizeof(data->last_error) - 1] = '\0';
}

/**
 * Callback for font table entries
 */
void font_callback(void* user_data, RtfFontInfo font) {
    UserData* data = (UserData*)user_data;
    data->font_count++;
    
    printf("FONT: %s (index: %d, charset: %d)\n", 
           font.name, font.index, font.charset);
}

/**
 * Callback for color table entries
 */
void color_callback(void* user_data, uint32_t index, RtfColor color) {
    UserData* data = (UserData*)user_data;
    data->color_count++;
    
    printf("COLOR: %d (RGB: %d,%d,%d)\n", 
           index, color.red, color.green, color.blue);
}

/**
 * Read a file into memory
 */
char* read_file(const char* filename, size_t* size) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        perror("Failed to open file");
        return NULL;
    }
    
    /* Get file size */
    fseek(file, 0, SEEK_END);
    *size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    /* Allocate buffer */
    char* buffer = (char*)malloc(*size);
    if (!buffer) {
        perror("Failed to allocate memory");
        fclose(file);
        return NULL;
    }
    
    /* Read file into buffer */
    if (fread(buffer, 1, *size, file) != *size) {
        perror("Failed to read file");
        free(buffer);
        fclose(file);
        return NULL;
    }
    
    fclose(file);
    return buffer;
}

/**
 * Print API version information
 */
void print_version(void) {
    int major, minor, patch;
    rtf_get_version(&major, &minor, &patch);
    printf("ZigRTF C API Version: %d.%d.%d\n", major, minor, patch);
}

int main(int argc, char** argv) {
    /* Print version info */
    print_version();
    
    /* Check arguments */
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <rtf_file> [--file-direct] [--strict]\n", argv[0]);
        fprintf(stderr, "\n");
        fprintf(stderr, "Options:\n");
        fprintf(stderr, "  --file-direct    Parse the file directly (don't read into memory first)\n");
        fprintf(stderr, "  --strict         Enable strict parsing mode (stops on first error)\n");
        return 1;
    }
    
    /* Parse command line options */
    bool use_file_direct = false;
    bool use_strict_mode = false;
    
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "--file-direct") == 0) {
            use_file_direct = true;
        } else if (strcmp(argv[i], "--strict") == 0) {
            use_strict_mode = true;
        } else {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            return 1;
        }
    }
    
    /* Initialize user data */
    UserData user_data = {0};
    
    /* Create RTF parser */
    RtfParser* parser = rtf_parser_create();
    if (!parser) {
        fprintf(stderr, "Failed to create RTF parser\n");
        return 1;
    }
    
    /* Create callback structure */
    RtfCallbacks callbacks = {
        .on_text = text_callback,
        .on_group_start = group_start_callback,
        .on_group_end = group_end_callback,
        .on_error = error_callback,
        .on_font_table = font_callback,
        .on_color_table = color_callback,
    };
    
    /* Set callbacks */
    RtfError result = rtf_parser_set_callbacks(parser, &callbacks, &user_data);
    if (result != RTF_OK) {
        fprintf(stderr, "Failed to set callbacks: %d\n", result);
        rtf_parser_destroy(parser);
        return 1;
    }
    
    /* Parse the file */
    printf("Parsing RTF file: %s%s%s\n", 
           argv[1],
           use_file_direct ? " (direct file access)" : "",
           use_strict_mode ? " (strict mode)" : "");
           
    RtfError parse_result;
    
    if (use_file_direct) {
        /* Parse the file directly with options */
        RtfParseOptions options = RTF_DEFAULT_OPTIONS;
        options.strict_mode = use_strict_mode;
        
        parse_result = rtf_parser_parse_file_with_options(parser, argv[1], &options);
    } else {
        /* Read the file into memory first */
        size_t file_size;
        char* rtf_data = read_file(argv[1], &file_size);
        
        if (!rtf_data) {
            rtf_parser_destroy(parser);
            return 1;
        }
        
        /* Parse with options */
        RtfParseOptions options = RTF_DEFAULT_OPTIONS;
        options.strict_mode = use_strict_mode;
        
        parse_result = rtf_parser_parse_memory_with_options(
            parser, rtf_data, file_size, &options);
            
        /* Free the file data */
        free(rtf_data);
    }
    
    /* Check parse result */
    if (parse_result != RTF_OK) {
        fprintf(stderr, "Error parsing RTF file: %d\n", parse_result);
        
        /* Get detailed error message */
        char error_message[256];
        rtf_parser_get_error_message(parser, error_message, sizeof(error_message));
        fprintf(stderr, "Error details: %s\n", error_message);
        
        rtf_parser_destroy(parser);
        return 1;
    }
    
    /* Print summary */
    printf("\nSUMMARY:\n");
    printf("- Text segments: %d\n", user_data.text_count);
    printf("- Bold segments: %d\n", user_data.bold_count);
    printf("- Italic segments: %d\n", user_data.italic_count);
    printf("- Strikethrough segments: %d\n", user_data.strikethrough_count);
    printf("- Superscript segments: %d\n", user_data.superscript_count);
    printf("- Subscript segments: %d\n", user_data.subscript_count);
    printf("- Groups: %d\n", user_data.group_count);
    printf("- Fonts: %d\n", user_data.font_count);
    printf("- Colors: %d\n", user_data.color_count);
    printf("- Errors: %d\n", user_data.error_count);
    
    if (user_data.error_count > 0) {
        printf("- Last error: %s\n", user_data.last_error);
    }
    
    printf("\nParsing completed successfully\n");
    
    /* Clean up */
    rtf_parser_destroy(parser);
    
    return 0;
}