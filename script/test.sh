#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$ROOT_DIR/work/direct-tests"
MODULE_CACHE="$ROOT_DIR/work/module-cache"
mkdir -p "$TEST_DIR" "$MODULE_CACHE"

xcrun swiftc \
    -parse-as-library \
    -target arm64-apple-macos14.0 \
    -module-cache-path "$MODULE_CACHE" \
    "$ROOT_DIR/Sources/BilingualSubtitle/Models/SubtitleModels.swift" \
    "$ROOT_DIR/Sources/BilingualSubtitle/Support/SubtitlePresentationPolicy.swift" \
    "$ROOT_DIR/Sources/BilingualSubtitle/Support/SubtitleTextNormalizer.swift" \
    "$ROOT_DIR/Sources/BilingualSubtitle/Services/GoogleTranslateService.swift" \
    "$ROOT_DIR/Tests/DirectTests.swift" \
    -framework AppKit \
    -framework Foundation \
    -o "$TEST_DIR/DirectTests"

"$TEST_DIR/DirectTests"

xcrun swiftc \
    -parse-as-library \
    -target arm64-apple-macos14.0 \
    -module-cache-path "$MODULE_CACHE" \
    "$ROOT_DIR/Sources/BilingualSubtitle/Models/SubtitleModels.swift" \
    "$ROOT_DIR/Sources/BilingualSubtitle/Support/SubtitleTextNormalizer.swift" \
    "$ROOT_DIR/Sources/BilingualSubtitle/Support/SubtitleStyleEstimator.swift" \
    "$ROOT_DIR/Sources/BilingualSubtitle/Services/OCRService.swift" \
    "$ROOT_DIR/Tests/OCRSmokeTests.swift" \
    -framework AppKit \
    -framework CoreGraphics \
    -framework Foundation \
    -framework Vision \
    -o "$TEST_DIR/OCRSmokeTests"

"$TEST_DIR/OCRSmokeTests"
