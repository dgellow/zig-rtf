#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "zigrtf.h"

/* User data structure */
typedef struct {
    int text_count;
    int bold_count;
    int italic_count;
    int group_count;
} UserData;

/* Callback for text events */
void text_callback(void* user_data, const char* text, size_t length, RtfStyle style) {
    UserData* data = (UserData*)user_data;
    data->text_count++;
    
    if (style.bold) data->bold_count++;
    if (style.italic) data->italic_count++;
    
    printf("TEXT: \"");
    fwrite(text, 1, length, stdout);
    printf("\" (bold=%d, italic=%d)\n", style.bold, style.italic);
}

/* Callback for group start events */
void group_start_callback(void* user_data) {
    UserData* data = (UserData*)user_data;
    data->group_count++;
    printf("GROUP START\n");
}

/* Callback for group end events */
void group_end_callback(void* user_data) {
    printf("GROUP END\n");
}

/* Read a file into memory */
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

int main(int argc, char** argv) {
    /* Check arguments */
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <rtf_file>\n", argv[0]);
        return 1;
    }
    
    /* Read RTF file */
    size_t file_size;
    char* rtf_data = read_file(argv[1], &file_size);
    if (!rtf_data) {
        return 1;
    }
    
    /* Initialize user data */
    UserData user_data = {0};
    
    /* Create RTF parser */
    RtfParser* parser = rtf_parser_create();
    if (!parser) {
        fprintf(stderr, "Failed to create RTF parser\n");
        free(rtf_data);
        return 1;
    }
    
    /* Set callbacks */
    rtf_parser_set_callbacks(
        parser,
        text_callback,
        group_start_callback,
        group_end_callback,
        &user_data
    );
    
    /* Parse RTF data */
    printf("Parsing RTF file: %s (%zu bytes)\n", argv[1], file_size);
    bool success = rtf_parser_parse_memory(parser, rtf_data, file_size);
    
    /* Check result */
    if (success) {
        printf("\nSUMMARY:\n");
        printf("- Text segments: %d\n", user_data.text_count);
        printf("- Bold segments: %d\n", user_data.bold_count);
        printf("- Italic segments: %d\n", user_data.italic_count);
        printf("- Groups: %d\n", user_data.group_count);
        printf("\nParsing completed successfully\n");
    } else {
        fprintf(stderr, "Error parsing RTF file\n");
    }
    
    /* Cleanup */
    rtf_parser_destroy(parser);
    free(rtf_data);
    
    return success ? 0 : 1;
}