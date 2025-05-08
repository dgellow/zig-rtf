#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "zigrtf_improved.h"

// For convenience, rename functions to rtf_* to avoid changing the entire file
#define rtf_get_version rtf2_get_version
#define rtf_parser_create rtf2_parser_create
#define rtf_parser_destroy rtf2_parser_destroy
#define rtf_parser_set_callbacks rtf2_parser_set_callbacks
#define rtf_parser_set_content_callbacks rtf2_parser_set_content_callbacks
#define rtf_parser_configure rtf2_parser_configure
#define rtf_parse_options_create rtf2_parse_options_create
#define rtf_parser_parse_memory rtf2_parser_parse_memory
#define rtf_parser_parse_memory_with_options rtf2_parser_parse_memory_with_options
#define rtf_parser_parse_file rtf2_parser_parse_file
#define rtf_parser_parse_file_with_options rtf2_parser_parse_file_with_options
#define rtf_parser_get_error_message rtf2_parser_get_error_message
#define rtf_parser_get_last_error rtf2_parser_get_last_error
#define rtf_parser_cancel rtf2_parser_cancel
#define rtf_parser_get_metadata rtf2_parser_get_metadata
#define rtf_parser_get_progress rtf2_parser_get_progress
#define rtf_detect_document_type rtf2_detect_document_type
#define rtf_options_set_strict_mode rtf2_options_set_strict_mode
#define rtf_options_set_max_depth rtf2_options_set_max_depth
#define rtf_options_set_memory_mapping rtf2_options_set_memory_mapping
#define rtf_options_set_progress_interval rtf2_options_set_progress_interval
#define rtf_options_set_extract_metadata rtf2_options_set_extract_metadata
#define rtf_options_set_detect_document_type rtf2_options_set_detect_document_type
#define rtf_options_set_auto_fix_errors rtf2_options_set_auto_fix_errors

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
    int binary_count;
    
    /* Last error information */
    char last_error[256];
    
    /* Metadata */
    RtfMetadata metadata;
    
    /* Parsing status */
    bool canceled;
    clock_t start_time;
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
 * Callback for binary data
 */
void binary_callback(void* user_data, RtfBinaryData binary) {
    UserData* data = (UserData*)user_data;
    data->binary_count++;
    
    const char* type_str = "Unknown";
    switch (binary.type) {
        case RTF_BINARY_IMAGE: type_str = "Image"; break;
        case RTF_BINARY_OBJECT: type_str = "Object"; break;
        case RTF_BINARY_FONT: type_str = "Font"; break;
        case RTF_BINARY_OTHER: type_str = "Other"; break;
        default: break;
    }
    
    printf("BINARY: %s data, %zu bytes\n", type_str, binary.size);
}

/**
 * Callback for metadata
 */
void metadata_callback(void* user_data, const RtfMetadata* metadata) {
    UserData* data = (UserData*)user_data;
    
    // Copy metadata to user data
    memcpy(&data->metadata, metadata, sizeof(RtfMetadata));
    
    // Print basic metadata
    printf("METADATA: Document type: %d\n", metadata->document_type);
    
    if (metadata->title[0] != '\0')
        printf("  - Title: %s\n", metadata->title);
    if (metadata->author[0] != '\0')
        printf("  - Author: %s\n", metadata->author);
    if (metadata->subject[0] != '\0')
        printf("  - Subject: %s\n", metadata->subject);
    
    printf("  - Word count: %u\n", metadata->word_count);
    printf("  - Character count: %u\n", metadata->character_count);
    printf("  - Has pictures: %s\n", metadata->has_pictures ? "Yes" : "No");
    printf("  - Has tables: %s\n", metadata->has_tables ? "Yes" : "No");
}

/**
 * Callback for progress reporting
 */
void progress_callback(void* user_data, float progress, size_t bytes_processed, size_t total_bytes) {
    UserData* data = (UserData*)user_data;
    
    // Print progress bar (limited to 20 updates to avoid console spam)
    static int last_percent = -1;
    int percent = (int)(progress * 100);
    
    if (percent != last_percent && percent % 5 == 0) {
        printf("\rParsing progress: [");
        int bar_width = 20;
        int pos = bar_width * progress;
        for (int i = 0; i < bar_width; i++) {
            if (i < pos) printf("=");
            else if (i == pos) printf(">");
            else printf(" ");
        }
        printf("] %3d%% (%zu / %zu bytes)", percent, bytes_processed, total_bytes);
        fflush(stdout);
        last_percent = percent;
    }
}

/**
 * Callback for cancellation check
 * Returns true to cancel parsing, false to continue
 */
bool cancel_callback(void* user_data) {
    UserData* data = (UserData*)user_data;
    
    // Check if too much time has elapsed (for demo: 10 seconds)
    if (data->canceled) {
        return true;
    }
    
    // For demo purposes, we'll cancel after 10 seconds
    clock_t now = clock();
    double elapsed = (double)(now - data->start_time) / CLOCKS_PER_SEC;
    if (elapsed > 10.0) {
        printf("\nCanceling parse after %.2f seconds...\n", elapsed);
        data->canceled = true;
        return true;
    }
    
    return false;
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
    printf("ZigRTF Improved API Version: %d.%d.%d\n", major, minor, patch);
}

/**
 * Print document type name
 */
const char* get_document_type_name(RtfDocumentType type) {
    switch (type) {
        case RTF_UNKNOWN: return "Unknown";
        case RTF_GENERIC: return "Generic RTF";
        case RTF_WORD: return "Microsoft Word";
        case RTF_WORDPAD: return "Microsoft WordPad";
        case RTF_WORDPERFECT: return "WordPerfect";
        case RTF_LIBREOFFICE: return "LibreOffice";
        case RTF_OPENOFFICE: return "OpenOffice";
        case RTF_APPLE_PAGES: return "Apple Pages";
        case RTF_ABIWORD: return "AbiWord";
        case RTF_OTHER: return "Other";
        default: return "Invalid";
    }
}

/**
 * Configure parser options using the builder pattern
 */
void configure_options(RtfParseOptions* options, bool use_strict_mode, bool use_file_direct, bool enable_progress) {
    // Start with default options
    *options = rtf_parse_options_create();
    
    // Configure using builder pattern
    rtf_options_set_strict_mode(options, use_strict_mode);
    
    if (enable_progress) {
        rtf_options_set_progress_interval(options, 1024); // 1KB for demo
    } else {
        rtf_options_set_progress_interval(options, 0); // Disable progress reporting
    }
    
    if (use_file_direct) {
        rtf_options_set_memory_mapping(options, true, 0); // Use memory mapping for all files
    }
    
    rtf_options_set_extract_metadata(options, true);
    rtf_options_set_detect_document_type(options, true);
    rtf_options_set_auto_fix_errors(options, !use_strict_mode); // Auto-fix errors unless in strict mode
}

int main(int argc, char** argv) {
    /* Print version info */
    print_version();
    
    /* Check arguments */
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <rtf_file> [--file-direct] [--strict] [--no-progress]\n", argv[0]);
        fprintf(stderr, "\n");
        fprintf(stderr, "Options:\n");
        fprintf(stderr, "  --file-direct    Parse the file directly (don't read into memory first)\n");
        fprintf(stderr, "  --strict         Enable strict parsing mode (stops on first error)\n");
        fprintf(stderr, "  --no-progress    Disable progress reporting\n");
        return 1;
    }
    
    /* Parse command line options */
    bool use_file_direct = false;
    bool use_strict_mode = false;
    bool enable_progress = true;
    
    for (int i = 2; i < argc; i++) {
        if (strcmp(argv[i], "--file-direct") == 0) {
            use_file_direct = true;
        } else if (strcmp(argv[i], "--strict") == 0) {
            use_strict_mode = true;
        } else if (strcmp(argv[i], "--no-progress") == 0) {
            enable_progress = false;
        } else {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            return 1;
        }
    }
    
    /* Initialize user data */
    UserData user_data = {0};
    user_data.start_time = clock();
    
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
        .on_binary = binary_callback,
        .on_metadata = metadata_callback,
        .on_progress = enable_progress ? progress_callback : NULL,
        .on_cancel = cancel_callback,
    };
    
    /* Set callbacks */
    RtfError result = rtf_parser_set_callbacks(parser, &callbacks, &user_data);
    if (result != RTF_OK) {
        fprintf(stderr, "Failed to set callbacks: %d\n", result);
        rtf_parser_destroy(parser);
        return 1;
    }
    
    /* Configure parser options */
    RtfParseOptions options;
    configure_options(&options, use_strict_mode, use_file_direct, enable_progress);
    
    /* Configure parser */
    result = rtf_parser_configure(parser, &options);
    if (result != RTF_OK) {
        fprintf(stderr, "Failed to configure parser: %d\n", result);
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
        /* Parse the file directly */
        parse_result = rtf_parser_parse_file_with_options(parser, argv[1], &options);
    } else {
        /* Read the file into memory first */
        size_t file_size;
        char* rtf_data = read_file(argv[1], &file_size);
        
        if (!rtf_data) {
            rtf_parser_destroy(parser);
            return 1;
        }
        
        /* Parse file data */
        parse_result = rtf_parser_parse_memory_with_options(parser, rtf_data, file_size, &options);
            
        /* Free the file data */
        free(rtf_data);
    }
    
    /* Print a newline after progress output */
    if (enable_progress) {
        printf("\n");
    }
    
    /* Check parse result */
    if (parse_result != RTF_OK) {
        if (parse_result == RTF_ERROR_CANCELED) {
            printf("Parsing was canceled.\n");
        } else {
            fprintf(stderr, "Error parsing RTF file: %d\n", parse_result);
            
            /* Get detailed error message */
            char error_message[256];
            rtf_parser_get_error_message(parser, error_message, sizeof(error_message));
            fprintf(stderr, "Error details: %s\n", error_message);
            
            rtf_parser_destroy(parser);
            return 1;
        }
    }
    
    /* Get document metadata if not already received through callback */
    if (user_data.metadata.document_type == RTF_UNKNOWN) {
        RtfMetadata metadata;
        if (rtf_parser_get_metadata(parser, &metadata) == RTF_OK) {
            memcpy(&user_data.metadata, &metadata, sizeof(RtfMetadata));
        }
    }
    
    /* Calculate parsing time */
    clock_t end_time = clock();
    double elapsed = (double)(end_time - user_data.start_time) / CLOCKS_PER_SEC;
    
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
    printf("- Binary objects: %d\n", user_data.binary_count);
    printf("- Errors: %d\n", user_data.error_count);
    
    if (user_data.error_count > 0) {
        printf("- Last error: %s\n", user_data.last_error);
    }
    
    printf("\nDOCUMENT INFO:\n");
    printf("- Document type: %s\n", get_document_type_name(user_data.metadata.document_type));
    if (user_data.metadata.title[0] != '\0')
        printf("- Title: %s\n", user_data.metadata.title);
    if (user_data.metadata.author[0] != '\0')
        printf("- Author: %s\n", user_data.metadata.author);
    
    printf("- Word count: %u\n", user_data.metadata.word_count);
    
    printf("\nParsing completed in %.4f seconds %s\n", 
           elapsed, 
           user_data.canceled ? "(canceled)" : "successfully");
    
    /* Clean up */
    rtf_parser_destroy(parser);
    
    return (parse_result == RTF_OK || parse_result == RTF_ERROR_CANCELED) ? 0 : 1;
}