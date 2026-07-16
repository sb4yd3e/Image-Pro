#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME="Image Pro.app"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build -c release --product ImageProApp

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/.build/release/ImageProApp" "$CONTENTS/MacOS/ImageProApp"
cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
if [ -f "$ROOT/Packaging/AppIcon.icns" ]; then
    cp "$ROOT/Packaging/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi
for LANGUAGE in en th; do
    ditto "$ROOT/Sources/ImageProApp/Resources/$LANGUAGE.lproj" "$CONTENTS/Resources/$LANGUAGE.lproj"
done
mkdir -p "$CONTENTS/Resources/Models" "$CONTENTS/Resources/ThirdPartyNotices"
xcrun coremlcompiler compile "$ROOT/Models/Bundled/LaMa.mlpackage" "$CONTENTS/Resources/Models"
if [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 15 ]; then
    xcrun coremlcompiler compile "$ROOT/Models/Bundled/RealESRGAN-x4plus.mlpackage" "$CONTENTS/Resources/Models"
fi
cp "$ROOT/Models/ThirdPartyNotices/README.md" "$CONTENTS/Resources/ThirdPartyNotices/Models.md"
if [ -d "$ROOT/Models/Optional/StableDiffusion" ]; then
    ditto "$ROOT/Models/Optional/StableDiffusion" "$CONTENTS/Resources/Models/StableDiffusion"
fi
chmod +x "$CONTENTS/MacOS/ImageProApp"

codesign --force --deep --sign - "$APP"
echo "$APP"
