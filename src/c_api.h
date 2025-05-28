/*
 * ZigRTF - The Ultimate RTF Parsing Library
 * 
 * Inspired by SQLite's elegant API design:
 * - Simple, obvious functions
 * - Clear memory ownership
 * - Predictable error handling
 * - Zero configuration required
 * 
 * Thread-safe and designed to replace Windows RichEdit disasters.
 */

#ifndef ZIGRTF_H
#define ZIGRTF_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * ============================================================================
 * CORE TYPES
 * ============================================================================
 */

/* Opaque document handle - like sqlite3* */
typedef struct rtf_document rtf_document;

/* Text run with formatting - minimal, cache-friendly */
typedef struct rtf_run {
    const char* text;        /* Zero-terminated text content */
    size_t      length;      /* Text length in bytes */
    
    /* Formatting flags - packed for efficiency */
    uint32_t    bold      : 1;
    uint32_t    italic    : 1; 
    uint32_t    underline : 1;
    uint32_t    reserved  : 29;
    
    /* Font and color */
    int         font_size;   /* Half-points (24 = 12pt), 0 = default */
    uint32_t    color;       /* RGB color, 0 = default */
} rtf_run;

/* Table structure - opaque, access via rtf_table_* functions */
typedef struct rtf_table rtf_table;

/* Image formats */
typedef enum rtf_image_format {
    RTF_IMAGE_UNKNOWN = 0,
    RTF_IMAGE_WMF     = 1,
    RTF_IMAGE_EMF     = 2,
    RTF_IMAGE_PICT    = 3,
    RTF_IMAGE_JPEG    = 4,
    RTF_IMAGE_PNG     = 5
} rtf_image_format;

/* Image information */
typedef struct rtf_image {
    rtf_image_format format;    /* Image format */
    uint32_t         width;     /* Width in pixels/twips */
    uint32_t         height;    /* Height in pixels/twips */
    const void*      data;      /* Binary image data */
    size_t           data_size; /* Size of data in bytes */
} rtf_image;

/* Reader interface - like Redis's rio */
typedef struct rtf_reader {
    /* Read function - return bytes read, 0 for EOF, -1 for error */
    int (*read)(void* context, void* buffer, size_t count);
    void* context;
} rtf_reader;

/* Result codes - simple like SQLite */
#define RTF_OK          0
#define RTF_ERROR       1
#define RTF_NOMEM       2
#define RTF_INVALID     3
#define RTF_TOOBIG      4

/*
 * ============================================================================
 * PARSING API
 * ============================================================================
 */

/*
 * Parse RTF from memory buffer.
 * 
 * The parser copies all necessary data - caller can free 'data' immediately.
 * Returns NULL on error (check rtf_errmsg() for details).
 * 
 * Thread-safe. Can be called from any thread.
 */
rtf_document* rtf_parse(const void* data, size_t length);

/*
 * Parse RTF from reader stream.
 * 
 * Calls reader->read() until EOF or error.
 * Returns NULL on error (check rtf_errmsg() for details).
 * 
 * Thread-safe. Reader callbacks may be called from parsing thread.
 */
rtf_document* rtf_parse_stream(rtf_reader* reader);

/*
 * Free document and all associated memory.
 * Safe to call with NULL pointer.
 * 
 * Thread-safe. Document can be freed from any thread.
 */
void rtf_free(rtf_document* doc);

/*
 * ============================================================================
 * DOCUMENT ACCESS
 * ============================================================================
 */

/*
 * Get plain text content.
 * 
 * Returns pointer to internal buffer - valid until rtf_free().
 * Text is UTF-8 encoded and zero-terminated.
 * 
 * Thread-safe for read access.
 */
const char* rtf_get_text(rtf_document* doc);

/*
 * Get text length in bytes (not including terminator).
 * 
 * Thread-safe.
 */
size_t rtf_get_text_length(rtf_document* doc);

/*
 * Get number of formatted runs in document.
 * 
 * Thread-safe.
 */
size_t rtf_get_run_count(rtf_document* doc);

/*
 * Get formatted run by index.
 * 
 * Returns NULL if index >= rtf_get_run_count().
 * Returned pointer valid until rtf_free().
 * 
 * Thread-safe for read access.
 */
const rtf_run* rtf_get_run(rtf_document* doc, size_t index);

/*
 * Get number of images in document.
 * 
 * Thread-safe.
 */
size_t rtf_get_image_count(rtf_document* doc);

/*
 * Get image by index.
 * 
 * Returns NULL if index >= rtf_get_image_count().
 * Returned pointer valid until rtf_free().
 * 
 * Thread-safe for read access.
 */
const rtf_image* rtf_get_image(rtf_document* doc, size_t index);

/*
 * Get number of tables in document.
 * 
 * Thread-safe.
 */
size_t rtf_get_table_count(rtf_document* doc);

/*
 * Get table by index.
 * 
 * Returns NULL if index >= rtf_get_table_count().
 * Returned pointer valid until rtf_free().
 * 
 * Thread-safe for read access.
 */
const struct rtf_table* rtf_get_table(rtf_document* doc, size_t index);

/*
 * Get number of rows in a table.
 * 
 * Thread-safe.
 */
size_t rtf_table_get_row_count(const struct rtf_table* table);

/*
 * Get number of cells in a table row.
 * 
 * Thread-safe.
 */
size_t rtf_table_get_cell_count(const struct rtf_table* table, size_t row_index);

/*
 * Get cell text content.
 * 
 * Returns plain text content of the cell, NULL if invalid indices.
 * Returned pointer valid until rtf_free().
 * 
 * Thread-safe for read access.
 */
const char* rtf_table_get_cell_text(const struct rtf_table* table, size_t row_index, size_t cell_index);

/*
 * Get cell width in twips (1/1440 inch).
 * 
 * Thread-safe.
 */
uint32_t rtf_table_get_cell_width(const struct rtf_table* table, size_t row_index, size_t cell_index);

/*
 * ============================================================================
 * RTF GENERATION
 * ============================================================================
 */

/*
 * Generate RTF string from document.
 * 
 * Returns newly allocated RTF string that caller must free with rtf_free_string().
 * Returns NULL on error (check rtf_errmsg() for details).
 * 
 * Thread-safe.
 */
char* rtf_generate(rtf_document* doc);

/*
 * Free string returned by rtf_generate().
 * Safe to call with NULL pointer.
 * 
 * Thread-safe.
 */
void rtf_free_string(char* rtf_string);

/*
 * ============================================================================
 * ERROR HANDLING
 * ============================================================================
 */

/*
 * Get last error message.
 * 
 * Returns human-readable error description.
 * Thread-local - each thread has its own error state.
 */
const char* rtf_errmsg(void);

/*
 * Clear error state.
 * 
 * Thread-local.
 */
void rtf_clear_error(void);

/*
 * ============================================================================
 * CONVENIENCE HELPERS
 * ============================================================================
 */

/*
 * Parse RTF file.
 * 
 * Convenience wrapper around fopen() + rtf_parse_stream().
 * Returns NULL on error (file not found, parse error, etc.).
 */
rtf_document* rtf_parse_file(const char* filename);

/*
 * Create file reader for rtf_parse_stream().
 * 
 * Caller retains ownership of FILE* - must fclose() after parsing.
 */
rtf_reader rtf_file_reader(void* file_handle); /* FILE* */

/*
 * ============================================================================
 * VERSION INFO
 * ============================================================================
 */

/* Version as single integer: major*10000 + minor*100 + patch */
#define RTF_VERSION 10000

/* Version as string */
const char* rtf_version(void);

/*
 * ============================================================================
 * USAGE EXAMPLES
 * ============================================================================
 */

#if 0
/* Example 1: Parse from memory */
char* rtf_data = load_rtf_somehow();
rtf_document* doc = rtf_parse(rtf_data, strlen(rtf_data));
if (!doc) {
    printf("Parse error: %s\n", rtf_errmsg());
    return;
}

/* Get plain text */
printf("Text: %s\n", rtf_get_text(doc));

/* Iterate formatted runs */
size_t count = rtf_get_run_count(doc);
for (size_t i = 0; i < count; i++) {
    const rtf_run* run = rtf_get_run(doc, i);
    printf("Run %zu: '%s'", i, run->text);
    if (run->bold) printf(" BOLD");
    if (run->italic) printf(" ITALIC");
    printf("\n");
}

rtf_free(doc);
free(rtf_data);

/* Example 2: Parse from file */
rtf_document* doc = rtf_parse_file("document.rtf");
if (doc) {
    printf("Parsed %zu characters\n", rtf_get_text_length(doc));
    rtf_free(doc);
}

/* Example 3: Parse from stream */
FILE* f = fopen("document.rtf", "rb");
rtf_reader reader = rtf_file_reader(f);
rtf_document* doc = rtf_parse_stream(&reader);
fclose(f);
if (doc) {
    /* use doc */
    rtf_free(doc);
}
#endif

#ifdef __cplusplus
}
#endif

#endif /* ZIGRTF_H */