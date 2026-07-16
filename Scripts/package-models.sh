#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT="$ROOT/dist/model-packs"
STAGING="$OUTPUT/staging"
RELEASE_BASE_URL=${MODEL_RELEASE_BASE_URL:-"https://github.com/sb4yd3e/Image-Pro/releases/download/models-v1"}

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT" "$STAGING"

package_coreml() {
    ID=$1
    SOURCE=$2
    COMPILED_NAME=$3
    MANIFEST=$4
    PACKAGE="$STAGING/$ID.imagepromodel"
    mkdir -p "$PACKAGE/payload"
    xcrun coremlcompiler compile "$SOURCE" "$PACKAGE/payload"
    test -d "$PACKAGE/payload/$COMPILED_NAME.mlmodelc"
    cp "$MANIFEST" "$PACKAGE/model.json"
    /usr/bin/ditto -c -k --keepParent "$PACKAGE" "$OUTPUT/$ID.zip"
}

package_directory() {
    ID=$1
    SOURCE=$2
    DESTINATION_NAME=$3
    MANIFEST=$4
    PACKAGE="$STAGING/$ID.imagepromodel"
    mkdir -p "$PACKAGE/payload"
    /usr/bin/ditto "$SOURCE" "$PACKAGE/payload/$DESTINATION_NAME"
    cp "$MANIFEST" "$PACKAGE/model.json"
    /usr/bin/ditto -c -k --keepParent "$PACKAGE" "$OUTPUT/$ID.zip"
}

package_coreml \
    "lama-coreml" \
    "$ROOT/Models/Bundled/LaMa.mlpackage" \
    "LaMa" \
    "$ROOT/Models/Manifests/lama-coreml.json"

package_coreml \
    "realesrgan-x4plus-coreml" \
    "$ROOT/Models/Bundled/RealESRGAN-x4plus.mlpackage" \
    "RealESRGAN-x4plus" \
    "$ROOT/Models/Manifests/realesrgan-x4plus-coreml.json"

package_directory \
    "stable-diffusion-15-coreml" \
    "$ROOT/Models/Optional/StableDiffusion" \
    "StableDiffusion" \
    "$ROOT/Models/Manifests/stable-diffusion-15-coreml.json"

for ARCHIVE in "$OUTPUT"/*.zip; do
    HASH=$(/usr/bin/shasum -a 256 "$ARCHIVE" | /usr/bin/awk '{print $1}')
    /usr/bin/printf '%s  %s\n' "$HASH" "$(basename "$ARCHIVE")" > "$ARCHIVE.sha256"
done

/usr/bin/python3 "$ROOT/Scripts/write-model-catalog.py" \
    "$OUTPUT" "$ROOT/Models/Manifests" "$RELEASE_BASE_URL" "$OUTPUT/catalog.json"

rm -rf "$STAGING"
/usr/bin/printf '%s\n' "$OUTPUT"
