#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PROCESS_NAME="BilingualSubtitle"
DISPLAY_NAME="双语字幕镜"
BUNDLE_ID="com.goldkingstar.BilingualSubtitle"
SIGNING_IDENTITY="${BILINGUAL_SUBTITLE_SIGNING_IDENTITY:-Bilingual Subtitle Local Code Signing}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/work/direct-build"
STAGING_ROOT="/private/tmp/com.goldkingstar.BilingualSubtitle-build"
APP_BUNDLE="$STAGING_ROOT/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PROCESS_NAME"
OUTPUT_ZIP="$ROOT_DIR/outputs/$DISPLAY_NAME.zip"

MODULE_CACHE="$ROOT_DIR/work/module-cache"

pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true

mkdir -p "$BUILD_DIR" "$MODULE_CACHE"
SOURCE_FILES=()
while IFS= read -r source_file; do
    SOURCE_FILES+=("$source_file")
done < <(find "$ROOT_DIR/Sources/BilingualSubtitle" -name '*.swift' -type f -print | sort)

xcrun swiftc \
    -parse-as-library \
    -O \
    -target arm64-apple-macos14.0 \
    -module-name BilingualSubtitle \
    -module-cache-path "$MODULE_CACHE" \
    "${SOURCE_FILES[@]}" \
    -framework AppKit \
    -framework CoreGraphics \
    -framework Foundation \
    -framework ScreenCaptureKit \
    -framework SwiftUI \
    -framework Vision \
    -o "$BUILD_DIR/$PROCESS_NAME"
BUILD_BINARY="$BUILD_DIR/$PROCESS_NAME"

xcrun swiftc \
    -module-cache-path "$MODULE_CACHE" \
    "$ROOT_DIR/script/generate_icon.swift" \
    -framework AppKit \
    -o "$BUILD_DIR/IconGenerator"
rm -rf "$BUILD_DIR/AppIcon.iconset"
"$BUILD_DIR/IconGenerator" "$BUILD_DIR/AppIcon.iconset" "$BUILD_DIR/AppIcon.icns"

if [[ -e "$STAGING_ROOT" ]]; then
    rm -rf "$STAGING_ROOT"
fi
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
chmod +x "$APP_BINARY"
xattr -cr "$APP_BUNDLE"
if ! security find-identity -p codesigning -v | grep -Fq "\"$SIGNING_IDENTITY\""; then
    echo "缺少稳定签名身份：$SIGNING_IDENTITY" >&2
    echo "为避免覆盖后再次丢失录屏权限，已停止构建。" >&2
    exit 1
fi
codesign \
    --force \
    --sign "$SIGNING_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    --timestamp=none \
    "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

rm -f "$OUTPUT_ZIP"
(
    cd "$STAGING_ROOT"
    /usr/bin/zip -qry -X "$OUTPUT_ZIP" "$DISPLAY_NAME.app"
)

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        open_app
        sleep 2
        pgrep -x "$PROCESS_NAME" >/dev/null
        ;;
    --build-only|build-only)
        ;;
    *)
        echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
