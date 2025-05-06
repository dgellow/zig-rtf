#ifndef ZIGRTF_MINIMAL_H
#define ZIGRTF_MINIMAL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* RTF style flags */
extern const int RTF_BOLD;
extern const int RTF_ITALIC;
extern const int RTF_UNDERLINE;

/* Simple RTF information structure */
typedef struct {
    int text_segments;
    int bold_segments;
    int italic_segments;
    int depth;
} RtfInfo;

/* Parse an RTF string and fill the info structure */
int rtf_parse_string(const char* text, RtfInfo* info);

/* Get library version string */
const char* rtf_get_version(void);

#ifdef __cplusplus
}
#endif

#endif /* ZIGRTF_MINIMAL_H */