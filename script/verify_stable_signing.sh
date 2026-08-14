#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="Bilingual Subtitle Local Code Signing"
SOURCE_APP="/private/tmp/com.goldkingstar.BilingualSubtitle-build/双语字幕镜.app"
TEMP_DIR="$(mktemp -d /private/tmp/com.goldkingstar.BilingualSubtitle-verify.XXXXXX)"
TEST_APP="$TEMP_DIR/双语字幕镜.app"

cleanup() {
    if [[ -n "${TEMP_DIR:-}" && "$TEMP_DIR" == /private/tmp/com.goldkingstar.BilingualSubtitle-verify.* ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
}
trap cleanup EXIT

/usr/bin/ditto "$SOURCE_APP" "$TEST_APP"

ORIGINAL_REQUIREMENT="$(codesign -d -r- "$SOURCE_APP" 2>&1 | grep 'designated =>')"
ORIGINAL_HASH="$(codesign -dvvv "$SOURCE_APP" 2>&1 | awk -F= '/^CDHash=/{print $2}')"

plutil -replace CFBundleVersion -string 9001 "$TEST_APP/Contents/Info.plist"
codesign \
    --force \
    --sign "$IDENTITY_NAME" \
    --identifier com.goldkingstar.BilingualSubtitle \
    --timestamp=none \
    "$TEST_APP"

UPDATED_REQUIREMENT="$(codesign -d -r- "$TEST_APP" 2>&1 | grep 'designated =>')"
UPDATED_HASH="$(codesign -dvvv "$TEST_APP" 2>&1 | awk -F= '/^CDHash=/{print $2}')"

if [[ "$ORIGINAL_REQUIREMENT" != "$UPDATED_REQUIREMENT" ]]; then
    echo "指定要求发生变化，稳定签名验证失败。" >&2
    exit 1
fi

if [[ "$ORIGINAL_HASH" == "$UPDATED_HASH" ]]; then
    echo "测试副本的代码哈希没有变化，无法证明跨版本稳定性。" >&2
    exit 1
fi

echo "稳定签名验证通过"
echo "原始 CDHash: $ORIGINAL_HASH"
echo "测试 CDHash: $UPDATED_HASH"
echo "$ORIGINAL_REQUIREMENT"
