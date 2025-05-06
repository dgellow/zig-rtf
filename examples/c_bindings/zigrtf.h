#ifndef ZIG_RTF_H
#define ZIG_RTF_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque type for the RTF parser */
typedef struct RtfParser RtfParser;

/* C-compatible style structure */
typedef struct {
    bool bold;
    bool italic;
    bool underline;
    uint16_t font_size;
} RtfStyle;

/* Callback function types */
typedef void (*RtfTextCallback)(void* user_data, const char* text, size_t length, RtfStyle style);
typedef void (*RtfGroupCallback)(void* user_data);

/* Create a new RTF parser */
RtfParser* rtf_parser_create(void);

/* Free resources used by the parser */
void rtf_parser_destroy(RtfParser* parser);

/* Set callbacks for parser events */
void rtf_parser_set_callbacks(
    RtfParser* parser,
    RtfTextCallback text_callback,
    RtfGroupCallback group_start_callback,
    RtfGroupCallback group_end_callback,
    void* user_data
);

/* Parse RTF data from memory */
bool rtf_parser_parse_memory(RtfParser* parser, const char* data, size_t length);

#ifdef __cplusplus
}
#endif

#endif /* ZIG_RTF_H */