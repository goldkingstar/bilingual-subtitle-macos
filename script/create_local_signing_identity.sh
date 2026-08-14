#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="Bilingual Subtitle Local Code Signing"
LOGIN_KEYCHAIN="$(security default-keychain -d user | tr -d '\"[:space:]')"
CONFIG_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Resources/local-code-signing.cnf"
TEMP_DIR="$(mktemp -d /private/tmp/com.goldkingstar.BilingualSubtitle-signing.XXXXXX)"

cleanup() {
    if [[ -n "${TEMP_DIR:-}" && "$TEMP_DIR" == /private/tmp/com.goldkingstar.BilingualSubtitle-signing.* ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
}
trap cleanup EXIT

if security find-identity -p codesigning -v | grep -Fq "\"$IDENTITY_NAME\""; then
    echo "稳定签名身份已存在：$IDENTITY_NAME"
    exit 0
fi

P12_PASSWORD="$(openssl rand -hex 24)"

openssl req \
    -x509 \
    -newkey rsa:2048 \
    -nodes \
    -days 3650 \
    -config "$CONFIG_PATH" \
    -keyout "$TEMP_DIR/private-key.pem" \
    -out "$TEMP_DIR/certificate.pem"

openssl pkcs12 \
    -export \
    -out "$TEMP_DIR/identity.p12" \
    -inkey "$TEMP_DIR/private-key.pem" \
    -in "$TEMP_DIR/certificate.pem" \
    -passout "pass:$P12_PASSWORD"

security import "$TEMP_DIR/identity.p12" \
    -k "$LOGIN_KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign

# Scope trust to code signing.  This identity is local to this Mac and is used
# only to give successive builds the same designated requirement.
security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$LOGIN_KEYCHAIN" \
    "$TEMP_DIR/certificate.pem"

if ! security find-identity -p codesigning -v | grep -Fq "\"$IDENTITY_NAME\""; then
    echo "签名身份已导入，但 macOS 未把它识别为有效的代码签名身份。" >&2
    exit 1
fi

echo "稳定签名身份创建成功：$IDENTITY_NAME"
