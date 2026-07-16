#include "CWebPBridge.h"
#include <stdio.h>
#include <webp/encode.h>

int imagepro_webp_encode_rgba(
    const uint8_t *rgba,
    int width,
    int height,
    int stride,
    float quality,
    int lossless,
    uint8_t **output,
    size_t *output_size
) {
    if (rgba == NULL || output == NULL || output_size == NULL ||
        width <= 0 || height <= 0 || stride < width * 4) {
        return 0;
    }

    size_t size = lossless
        ? WebPEncodeLosslessRGBA(rgba, width, height, stride, output)
        : WebPEncodeRGBA(rgba, width, height, stride, quality, output);

    if (size == 0 || *output == NULL) {
        return 0;
    }
    *output_size = size;
    return 1;
}

void imagepro_webp_free(void *pointer) {
    WebPFree(pointer);
}

const char *imagepro_webp_version(void) {
    static char version[32];
    const int value = WebPGetEncoderVersion();
    snprintf(
        version,
        sizeof(version),
        "%d.%d.%d",
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff
    );
    return version;
}
