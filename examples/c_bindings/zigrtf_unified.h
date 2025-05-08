/**
 * @file zigrtf.h
 * @brief ZigRTF C API Header File
 * 
 * This header defines the C API for the ZigRTF library, a high-performance
 * RTF parser implemented in Zig. This API provides both simple and advanced
 * interfaces for using the ZigRTF parser from C code.
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
 * @brief Opaque type for the RTF parser
 */
typedef struct RtfParser RtfParser;

/**
 * @brief Error codes returned by RTF parser functions
 */
enum RtfErrorCode {
    RTF_NO_ERROR = 0,           /**< No error */
    RTF_MEMORY_ERROR = 1,       /**< Memory allocation failed */
    RTF_PARSE_ERROR = 2,        /**< Error during RTF parsing */
    RTF_INVALID_PARAM = 3,      /**< Invalid parameter provided */
    RTF_UNSUPPORTED_FEATURE = 4 /**< Feature not implemented yet */
};

/**
 * @brief C-compatible style structure for RTF text formatting
 * 
 * This structure is used with the advanced API to represent text formatting.
 */
typedef struct {
    bool bold;         /**< Whether the text is bold */
    bool italic;       /**< Whether the text is italic */
    bool underline;    /**< Whether the text is underlined */
    uint16_t font_size; /**< Font size in half-points (0 if not specified) */
} RtfStyle;

/**
 * @brief C-compatible style structure using integers for maximum compatibility
 * 
 * This structure is used with the simple API to represent text formatting.
 * All boolean values are represented as integers (0 = false, non-zero = true).
 */
typedef struct {
    int bold;         /**< Whether the text is bold (0 = false, non-zero = true) */
    int italic;       /**< Whether the text is italic (0 = false, non-zero = true) */
    int underline;    /**< Whether the text is underlined (0 = false, non-zero = true) */
    int font_size;    /**< Font size in half-points (0 if not specified) */
} RtfStyleInt;

/**
 * @brief Advanced API callback function types
 */
typedef void (*RtfTextCallback)(void* user_data, const char* text, size_t length, RtfStyle style);
typedef void (*RtfGroupCallback)(void* user_data);
typedef void (*RtfErrorCallback)(void* user_data, const char* position, const char* message);
typedef void (*RtfCharCallback)(void* user_data, uint8_t character, RtfStyle style);

/**
 * @brief Simple API callback function types
 */
typedef void (*RtfSimpleTextCallback)(void* user_data, const char* text, size_t length, RtfStyleInt style);

/* ===== ADVANCED API FUNCTIONS ===== */

/**
 * @brief Create a new RTF parser
 * 
 * @return A pointer to a new RtfParser instance, or NULL if memory allocation failed
 */
RtfParser* rtf_unified_create(void);

/**
 * @brief Free resources used by the parser
 * 
 * @param parser The parser to destroy
 */
void rtf_unified_destroy(RtfParser* parser);

/**
 * @brief Set callbacks for RTF parsing events
 * 
 * @param parser The parser instance
 * @param text_callback Callback for text events
 * @param group_start_callback Callback for group start events ('{')
 * @param group_end_callback Callback for group end events ('}')
 * @param user_data User data to pass to callbacks
 */
void rtf_unified_set_callbacks(
    RtfParser* parser,
    RtfTextCallback text_callback,
    RtfGroupCallback group_start_callback,
    RtfGroupCallback group_end_callback,
    void* user_data
);

/**
 * @brief Set extended callbacks for advanced RTF parsing events
 * 
 * @param parser The parser instance
 * @param error_callback Callback for error events
 * @param char_callback Callback for individual character events
 */
void rtf_unified_set_extended_callbacks(
    RtfParser* parser,
    RtfErrorCallback error_callback,
    RtfCharCallback char_callback
);

/**
 * @brief Parse RTF data from memory
 * 
 * @param parser The parser instance
 * @param data Pointer to RTF data
 * @param length Length of RTF data in bytes
 * @return true on success, false on failure
 */
bool rtf_unified_parse_memory(RtfParser* parser, const char* data, size_t length);

/**
 * @brief Parse RTF data with specific error recovery options
 * 
 * @param parser The parser instance
 * @param data Pointer to RTF data
 * @param length Length of RTF data in bytes
 * @param strict_mode If true, fail on first error; if false, try to recover from errors
 * @return true on success, false on failure
 */
bool rtf_unified_parse_memory_with_recovery(
    RtfParser* parser,
    const char* data,
    size_t length,
    bool strict_mode
);

/**
 * @brief Get the last error code from the parser
 * 
 * @param parser The parser instance
 * @return Error code from the RtfErrorCode enum
 */
int rtf_unified_get_last_error(RtfParser* parser);

/* ===== SIMPLE API FUNCTIONS ===== */

/**
 * @brief Create a new RTF parser (simple API)
 * 
 * This is identical to rtf_unified_create() but is provided
 * for API clarity when using the simple interface.
 * 
 * @return A pointer to a new RtfParser instance, or NULL if memory allocation failed
 */
RtfParser* rtf_unified_simple_create(void);

/**
 * @brief Free resources used by the parser (simple API)
 * 
 * This is identical to rtf_unified_destroy() but is provided
 * for API clarity when using the simple interface.
 * 
 * @param parser The parser to destroy
 */
void rtf_unified_simple_destroy(RtfParser* parser);

/**
 * @brief Set callbacks for RTF parsing events (simple API)
 * 
 * The simple API uses int-based style structs for maximum
 * compatibility with all C compilers.
 * 
 * @param parser The parser instance
 * @param text_callback Callback for text events
 * @param group_start_callback Callback for group start events ('{')
 * @param group_end_callback Callback for group end events ('}')
 * @param user_data User data to pass to callbacks
 */
void rtf_unified_simple_set_callbacks(
    RtfParser* parser,
    RtfSimpleTextCallback text_callback,
    RtfGroupCallback group_start_callback,
    RtfGroupCallback group_end_callback,
    void* user_data
);

/**
 * @brief Parse RTF data from memory (simple API)
 * 
 * The simple API uses an int return value (0 = failure, 1 = success)
 * for maximum compatibility with all C compilers.
 * 
 * @param parser The parser instance
 * @param data Pointer to RTF data
 * @param length Length of RTF data in bytes
 * @return 1 on success, 0 on failure
 */
int rtf_unified_simple_parse_memory(RtfParser* parser, const char* data, size_t length);

/* ===== LEGACY COMPATIBILITY FUNCTIONS ===== */

/**
 * @brief Set callbacks for RTF parsing events (legacy compatibility)
 * 
 * This function is provided for backward compatibility with existing code.
 * New code should use rtf_unified_simple_set_callbacks().
 * 
 * @param parser The parser instance
 * @param text_callback Callback for text events
 * @param group_start_callback Callback for group start events ('{')
 * @param group_end_callback Callback for group end events ('}')
 * @param user_data User data to pass to callbacks
 */
void rtf_unified_compat_set_callbacks_simple(
    RtfParser* parser,
    RtfSimpleTextCallback text_callback,
    RtfGroupCallback group_start_callback,
    RtfGroupCallback group_end_callback,
    void* user_data
);

/**
 * @brief Parse RTF data from memory (legacy compatibility)
 * 
 * This function is provided for backward compatibility with existing code.
 * New code should use rtf_unified_simple_parse_memory().
 * 
 * @param parser The parser instance
 * @param data Pointer to RTF data
 * @param length Length of RTF data in bytes
 * @return 1 on success, 0 on failure
 */
int rtf_unified_compat_parse_memory_simple(RtfParser* parser, const char* data, size_t length);

#ifdef __cplusplus
}
#endif

#endif /* ZIG_RTF_H */