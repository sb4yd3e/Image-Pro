#ifndef IMAGEPRO_CWEBPBRIDGE_H
#define IMAGEPRO_CWEBPBRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int imagepro_webp_encode_rgba(
    const uint8_t *rgba,
    int width,
    int height,
    int stride,
    float quality,
    int lossless,
    uint8_t **output,
    size_t *output_size
);

void imagepro_webp_free(void *pointer);

const char *imagepro_webp_version(void);

#ifdef __cplusplus
}
#endif

#endif
