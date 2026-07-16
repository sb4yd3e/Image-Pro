#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLIST="$ROOT/Packaging/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")
RELEASE_DIR="$ROOT/dist/releases"
ARCHIVE="$RELEASE_DIR/Image-Pro-$VERSION.zip"
CHECKSUM="$ARCHIVE.sha256"

sh "$ROOT/Scripts/build-app.sh"
mkdir -p "$RELEASE_DIR"
rm -f "$ARCHIVE" "$CHECKSUM"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/Image Pro.app" "$ARCHIVE"

HASH=$(/usr/bin/shasum -a 256 "$ARCHIVE" | /usr/bin/awk '{print $1}')
/usr/bin/printf '%s  %s\n' "$HASH" "$(basename "$ARCHIVE")" > "$CHECKSUM"

/usr/bin/printf '%s\n%s\n' "$ARCHIVE" "$CHECKSUM"
