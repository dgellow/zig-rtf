#include <stdio.h>
#include "header.h"

int main() {
    // Display version information
    printf("Using %s\n\n", rtf_get_version());
    
    // Sample RTF content (simplified for demonstration)
    const char* rtf_sample = "{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Times New Roman;}}\\f0 "
                          "This is \\b bold\\b0 and \\i italic\\i0 text.}";
    
    printf("Sample RTF content:\n%s\n\n", rtf_sample);
    
    // Analyze RTF content
    RtfInfo info;
    if (rtf_parse_string(rtf_sample, &info)) {
        printf("RTF Analysis:\n");
        printf("- Text segments:  %d\n", info.text_segments);
        printf("- Bold segments:  %d\n", info.bold_segments);
        printf("- Italic segments: %d\n", info.italic_segments);
        printf("- Nesting depth:   %d\n", info.depth);
        
        return 0;
    } else {
        fprintf(stderr, "Failed to parse RTF content\n");
        return 1;
    }
}