/**
 * ZigRTF - High Performance RTF Parser
 * C API Header
 * 
 * Version 1.0.0
 */

#ifndef ZIG_RTF_H
#define ZIG_RTF_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * API version information
 * This follows semantic versioning - breaking changes increment MAJOR
 */
#define RTF_API_VERSION_MAJOR 1
#define RTF_API_VERSION_MINOR 0
#define RTF_API_VERSION_PATCH 0

/**
 * Error codes
 * All error codes below 0 indicate an error condition
 */
typedef enum RtfError {
    RTF_OK = 0,                         // Success
    RTF_ERROR_MEMORY = -1,              // Memory allocation failure
    RTF_ERROR_INVALID_PARAMETER = -2,   // Invalid parameter
    RTF_ERROR_PARSE_FAILED = -3,        // RTF parsing failed
    RTF_ERROR_FILE_NOT_FOUND = -4,      // File not found
    RTF_ERROR_FILE_ACCESS = -5,         // File access error
    RTF_ERROR_UNSUPPORTED_FEATURE = -6, // Unsupported feature
    RTF_ERROR_INVALID_FORMAT = -7       // Invalid RTF format
} RtfError;

/**
 * Parser options
 * Controls the behavior of the RTF parser
 */
typedef struct {
    /* Error handling - when true, stops on first error */
    bool strict_mode;
    
    /* Maximum nesting depth for RTF groups (default: 100) */
    uint16_t max_depth;
    
    /* Whether to use memory mapping for large files (default: true) */
    bool use_memory_mapping;
    
    /* Memory mapping threshold in bytes (default: 1MB) */
    uint32_t memory_mapping_threshold;
    
    /* Reserved for future use */
    uint16_t _reserved;
} RtfParseOptions;

/**
 * Default parser options
 * Use this to initialize options with defaults.
 */
static const RtfParseOptions RTF_DEFAULT_OPTIONS = {
    .strict_mode = false,
    .max_depth = 100,
    .use_memory_mapping = true,
    .memory_mapping_threshold = 1024 * 1024, /* 1MB */
    ._reserved = 0
};

/**
 * RTF Style Information
 * Contains comprehensive style information for text runs.
 */
typedef struct {
    /* Basic formatting */
    bool bold;
    bool italic;
    bool underline;
    bool strikethrough;
    
    /* Font information */
    uint16_t font_size;    /* Size in half-points (0 = default) */
    int16_t font_index;    /* Font index in font table (-1 = default) */
    
    /* Color information */
    int16_t foreground_color_index; /* Color index in color table (-1 = default) */
    int16_t background_color_index; /* Color index in color table (-1 = default) */
    
    /* Special formatting */
    bool superscript;
    bool subscript;
    bool hidden;
    
    /* Additional options */
    bool all_caps;
    bool small_caps;
    
    /* Reserved for future use */
    uint8_t _reserved1;
    uint8_t _reserved2;
    uint16_t _reserved3;
} RtfStyleInfo;

/**
 * RGB Color information
 */
typedef struct {
    uint8_t red;
    uint8_t green;
    uint8_t blue;
    uint8_t _reserved; /* For alignment/future use */
} RtfColor;

/**
 * Font information
 */
typedef struct {
    int32_t index;      /* Font index */
    char name[64];      /* Null-terminated font name */
    int32_t charset;    /* Character set */
} RtfFontInfo;

/**
 * Opaque RTF parser handle
 * Use rtf_parser_create() to create a new instance
 */
typedef struct RtfParser RtfParser;

/**
 * Callback function types
 */
typedef void (*RtfTextCallback)(void* user_data, const char* text, size_t length, RtfStyleInfo style);
typedef void (*RtfGroupCallback)(void* user_data);
typedef void (*RtfErrorCallback)(void* user_data, RtfError error, const char* message);
typedef void (*RtfCharacterCallback)(void* user_data, uint8_t character, RtfStyleInfo style);
typedef void (*RtfColorCallback)(void* user_data, uint32_t index, RtfColor color);
typedef void (*RtfFontCallback)(void* user_data, RtfFontInfo font);

/**
 * RTF Callback structure
 * Set the callbacks you want to receive
 */
typedef struct {
    /* Basic RTF content callbacks */
    RtfTextCallback on_text;
    RtfGroupCallback on_group_start;
    RtfGroupCallback on_group_end;
    
    /* Advanced RTF content callbacks */
    RtfCharacterCallback on_character;
    RtfErrorCallback on_error;
    RtfColorCallback on_color_table;
    RtfFontCallback on_font_table;
    
    /* Reserved for future extensions */
    void* _reserved1;
    void* _reserved2;
} RtfCallbacks;

/**
 * Get the API version information
 * 
 * @param major Pointer to receive major version number (can be NULL)
 * @param minor Pointer to receive minor version number (can be NULL)
 * @param patch Pointer to receive patch version number (can be NULL)
 */
void rtf_get_version(int* major, int* minor, int* patch);

/**
 * Create a new RTF parser instance
 * 
 * @return A pointer to the new parser, or NULL if creation failed
 */
RtfParser* rtf_parser_create(void);

/**
 * Destroy an RTF parser instance and free all resources
 * 
 * @param parser The parser to destroy
 */
void rtf_parser_destroy(RtfParser* parser);

/**
 * Set callback functions for RTF events
 * 
 * @param parser The parser instance
 * @param callbacks Pointer to a structure containing callback functions
 * @param user_data User data pointer to pass to callbacks
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf_parser_set_callbacks(
    RtfParser* parser,
    const RtfCallbacks* callbacks,
    void* user_data
);

/**
 * Parse RTF data from memory
 * 
 * @param parser The parser instance
 * @param data Pointer to RTF data in memory
 * @param length Length of the RTF data in bytes
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf_parser_parse_memory(
    RtfParser* parser,
    const char* data,
    size_t length
);

/**
 * Parse RTF data from memory with custom options
 * 
 * @param parser The parser instance
 * @param data Pointer to RTF data in memory
 * @param length Length of the RTF data in bytes
 * @param options Custom parsing options
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf_parser_parse_memory_with_options(
    RtfParser* parser,
    const char* data,
    size_t length,
    const RtfParseOptions* options
);

/**
 * Parse RTF data from a file
 * 
 * @param parser The parser instance
 * @param filename Path to the RTF file
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf_parser_parse_file(
    RtfParser* parser,
    const char* filename
);

/**
 * Parse RTF data from a file with custom options
 * 
 * @param parser The parser instance
 * @param filename Path to the RTF file
 * @param options Custom parsing options
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf_parser_parse_file_with_options(
    RtfParser* parser,
    const char* filename,
    const RtfParseOptions* options
);

/**
 * Get the last error message if an error occurred
 * 
 * @param parser The parser instance
 * @param buffer Buffer to receive the error message
 * @param buffer_size Size of the buffer in bytes
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf_parser_get_error_message(
    RtfParser* parser,
    char* buffer,
    size_t buffer_size
);

/**
 * Get the last error code
 * 
 * @param parser The parser instance
 * @return The last error code, or RTF_ERROR_INVALID_PARAMETER if parser is NULL
 */
RtfError rtf_parser_get_last_error(RtfParser* parser);

#ifdef __cplusplus
}
#endif

#endif /* ZIG_RTF_H */