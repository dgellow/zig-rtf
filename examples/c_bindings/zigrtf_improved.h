/**
 * ZigRTF - High Performance RTF Parser
 * C API Header
 * 
 * Version 1.1.0
 */

#ifndef ZIG_RTF_IMPROVED_H
#define ZIG_RTF_IMPROVED_H

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
#define RTF_API_VERSION_MINOR 1
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
    RTF_ERROR_INVALID_FORMAT = -7,      // Invalid RTF format
    RTF_ERROR_ENCODING = -8,            // Encoding conversion error
    RTF_ERROR_UTF8 = -9,                // UTF-8 encoding error
    RTF_ERROR_CANCELED = -10            // Operation was canceled
} RtfError;

/**
 * Document type identifiers
 */
typedef enum RtfDocumentType {
    RTF_UNKNOWN = 0,     // Unknown document type
    RTF_GENERIC = 1,     // Generic RTF document
    RTF_WORD = 2,        // Microsoft Word
    RTF_WORDPAD = 3,     // Microsoft WordPad
    RTF_WORDPERFECT = 4, // WordPerfect
    RTF_LIBREOFFICE = 5, // LibreOffice
    RTF_OPENOFFICE = 6,  // OpenOffice
    RTF_APPLE_PAGES = 7, // Apple Pages
    RTF_ABIWORD = 8,     // AbiWord
    RTF_OTHER = 9        // Other RTF producer
} RtfDocumentType;

/**
 * Binary data types
 */
typedef enum RtfBinaryType {
    RTF_BINARY_UNKNOWN = 0, // Unknown binary data
    RTF_BINARY_IMAGE = 1,   // Image data
    RTF_BINARY_OBJECT = 2,  // Embedded object
    RTF_BINARY_FONT = 3,    // Font data
    RTF_BINARY_OTHER = 4    // Other binary data
} RtfBinaryType;

/**
 * Image formats
 */
typedef enum RtfImageFormat {
    RTF_IMAGE_UNKNOWN = 0, // Unknown image format
    RTF_IMAGE_JPEG = 1,    // JPEG image
    RTF_IMAGE_PNG = 2,     // PNG image
    RTF_IMAGE_BMP = 3,     // BMP image
    RTF_IMAGE_WMF = 4,     // Windows Metafile
    RTF_IMAGE_EMF = 5,     // Enhanced Metafile
    RTF_IMAGE_PICT = 6,    // PICT format
    RTF_IMAGE_OTHER = 7    // Other image format
} RtfImageFormat;

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
    
    /* Progress reporting frequency (bytes between progress callbacks) */
    uint32_t progress_interval;
    
    /* Whether to extract document properties (metadata) */
    bool extract_metadata;
    
    /* Whether to detect document type (Word, WordPad, etc.) */
    bool detect_document_type;
    
    /* Whether to fix common RTF errors automatically */
    bool auto_fix_errors;
    
    /* Reserved for future use */
    uint8_t _reserved;
} RtfParseOptions;

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
 * Binary data information
 */
typedef struct {
    const char* data;  /* Pointer to binary data */
    size_t size;       /* Size of binary data in bytes */
    RtfBinaryType type; /* Type of binary data */
} RtfBinaryData;

/**
 * Image information
 */
typedef struct {
    uint32_t width;          /* Image width */
    uint32_t height;         /* Image height */
    uint8_t bits_per_pixel;  /* Bits per pixel */
    RtfImageFormat format;   /* Image format */
} RtfImageInfo;

/**
 * Document metadata - RTF document properties
 */
typedef struct {
    char title[128];      /* Document title */
    char author[128];     /* Document author */
    char subject[128];    /* Document subject */
    char keywords[256];   /* Document keywords */
    char comment[256];    /* Document comment */
    char company[128];    /* Company name */
    char manager[128];    /* Manager name */
    
    RtfDocumentType document_type; /* Type of RTF document */
    
    int64_t creation_time;     /* Creation time (Unix timestamp) */
    int64_t modification_time; /* Last modification time (Unix timestamp) */
    
    uint32_t character_count;  /* Character count */
    uint32_t word_count;       /* Word count */
    uint16_t rtf_version;      /* RTF version */
    
    bool has_pictures;         /* Document contains pictures */
    bool has_objects;          /* Document contains embedded objects */
    bool has_tables;           /* Document contains tables */
    
    uint8_t _reserved[32];     /* Reserved for future use */
} RtfMetadata;

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
typedef void (*RtfBinaryCallback)(void* user_data, RtfBinaryData binary);
typedef void (*RtfMetadataCallback)(void* user_data, const RtfMetadata* metadata);
typedef void (*RtfProgressCallback)(void* user_data, float progress, size_t bytes_processed, size_t total_bytes);
typedef bool (*RtfCancelCallback)(void* user_data);

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
    
    /* Binary data callback */
    RtfBinaryCallback on_binary;
    
    /* Metadata callback */
    RtfMetadataCallback on_metadata;
    
    /* Progress reporting and cancellation */
    RtfProgressCallback on_progress;
    RtfCancelCallback on_cancel;
    
    /* Reserved for future extensions */
    void* _reserved1;
    void* _reserved2;
} RtfCallbacks;

/**
 * Default parser options
 * Use this to initialize options with defaults.
 */
static const RtfParseOptions RTF_DEFAULT_OPTIONS = {
    .strict_mode = false,
    .max_depth = 100,
    .use_memory_mapping = true,
    .memory_mapping_threshold = 1024 * 1024, /* 1MB */
    .progress_interval = 64 * 1024, /* 64KB */
    .extract_metadata = true,
    .detect_document_type = true,
    .auto_fix_errors = true,
    ._reserved = 0
};

//=============================================================================
// CORE API FUNCTIONS
//=============================================================================

/**
 * Get the API version information
 * 
 * @param major Pointer to receive major version number (can be NULL)
 * @param minor Pointer to receive minor version number (can be NULL)
 * @param patch Pointer to receive patch version number (can be NULL)
 */
void rtf2_get_version(int* major, int* minor, int* patch);

/**
 * Create a new RTF parser instance
 * 
 * @return A pointer to the new parser, or NULL if creation failed
 */
RtfParser* rtf2_parser_create(void);

/**
 * Destroy an RTF parser instance and free all resources
 * 
 * @param parser The parser to destroy
 */
void rtf2_parser_destroy(RtfParser* parser);

/**
 * Set callback functions for RTF events
 * 
 * @param parser The parser instance
 * @param callbacks Pointer to a structure containing callback functions
 * @param user_data User data pointer to pass to callbacks
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf2_parser_set_callbacks(
    RtfParser* parser,
    const RtfCallbacks* callbacks,
    void* user_data
);

/**
 * Set content callback functions - simplified API for basic callbacks
 * 
 * @param parser The parser instance
 * @param text_callback Callback for text events
 * @param group_start_callback Callback for group start events
 * @param group_end_callback Callback for group end events
 * @param error_callback Callback for error events
 * @param user_data User data pointer to pass to callbacks
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf2_parser_set_content_callbacks(
    RtfParser* parser,
    RtfTextCallback text_callback,
    RtfGroupCallback group_start_callback,
    RtfGroupCallback group_end_callback,
    RtfErrorCallback error_callback,
    void* user_data
);

/**
 * Configure parser options
 * 
 * @param parser The parser instance
 * @param options Pointer to options structure
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf2_parser_configure(
    RtfParser* parser,
    const RtfParseOptions* options
);

/**
 * Create default parse options
 * 
 * @return A new RtfParseOptions structure with default values
 */
RtfParseOptions rtf2_parse_options_create(void);

/**
 * Parse RTF data from memory
 * 
 * @param parser The parser instance
 * @param data Pointer to RTF data in memory
 * @param length Length of the RTF data in bytes
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf2_parser_parse_memory(
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
RtfError rtf2_parser_parse_memory_with_options(
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
RtfError rtf2_parser_parse_file(
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
RtfError rtf2_parser_parse_file_with_options(
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
RtfError rtf2_parser_get_error_message(
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
RtfError rtf2_parser_get_last_error(RtfParser* parser);

//=============================================================================
// EXTENDED API FUNCTIONS
//=============================================================================

/**
 * Cancel an ongoing parsing operation
 * 
 * @param parser The parser instance
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf2_parser_cancel(RtfParser* parser);

/**
 * Get document metadata from the parser
 * 
 * @param parser The parser instance
 * @param metadata Pointer to a metadata structure to fill
 * @return RTF_OK on success, error code otherwise
 */
RtfError rtf2_parser_get_metadata(
    RtfParser* parser,
    RtfMetadata* metadata
);

/**
 * Get estimated progress of parsing (0.0 to 1.0)
 * 
 * @param parser The parser instance
 * @return Progress as a float from 0.0 to 1.0
 */
float rtf2_parser_get_progress(RtfParser* parser);

/**
 * Detect type of RTF document (Word, WordPad, etc.)
 * 
 * @param data Pointer to RTF data in memory
 * @param length Length of the RTF data in bytes
 * @return Document type
 */
RtfDocumentType rtf2_detect_document_type(
    const char* data,
    size_t length
);

//=============================================================================
// BUILDER PATTERN FOR OPTIONS
//=============================================================================

/**
 * Set strict mode for parsing
 * 
 * @param options Pointer to options structure
 * @param strict_mode Whether to use strict mode
 * @return Pointer to the same options structure for chaining
 */
RtfParseOptions* rtf2_options_set_strict_mode(
    RtfParseOptions* options,
    bool strict_mode
);

/**
 * Set maximum nesting depth
 * 
 * @param options Pointer to options structure
 * @param max_depth Maximum nesting depth
 * @return Pointer to the same options structure for chaining
 */
RtfParseOptions* rtf2_options_set_max_depth(
    RtfParseOptions* options,
    uint16_t max_depth
);

/**
 * Enable or disable memory mapping
 * 
 * @param options Pointer to options structure
 * @param use_memory_mapping Whether to use memory mapping
 * @param threshold Memory mapping threshold in bytes
 * @return Pointer to the same options structure for chaining
 */
RtfParseOptions* rtf2_options_set_memory_mapping(
    RtfParseOptions* options,
    bool use_memory_mapping,
    uint32_t threshold
);

/**
 * Set progress reporting interval
 * 
 * @param options Pointer to options structure
 * @param interval Progress reporting interval in bytes
 * @return Pointer to the same options structure for chaining
 */
RtfParseOptions* rtf2_options_set_progress_interval(
    RtfParseOptions* options,
    uint32_t interval
);

/**
 * Enable or disable metadata extraction
 * 
 * @param options Pointer to options structure
 * @param extract_metadata Whether to extract metadata
 * @return Pointer to the same options structure for chaining
 */
RtfParseOptions* rtf2_options_set_extract_metadata(
    RtfParseOptions* options,
    bool extract_metadata
);

/**
 * Enable or disable document type detection
 * 
 * @param options Pointer to options structure
 * @param detect_document_type Whether to detect document type
 * @return Pointer to the same options structure for chaining
 */
RtfParseOptions* rtf2_options_set_detect_document_type(
    RtfParseOptions* options,
    bool detect_document_type
);

/**
 * Enable or disable automatic error fixing
 * 
 * @param options Pointer to options structure
 * @param auto_fix_errors Whether to automatically fix errors
 * @return Pointer to the same options structure for chaining
 */
RtfParseOptions* rtf2_options_set_auto_fix_errors(
    RtfParseOptions* options,
    bool auto_fix_errors
);

#ifdef __cplusplus
}
#endif

#endif /* ZIG_RTF_IMPROVED_H */