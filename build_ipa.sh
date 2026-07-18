#!/usr/bin/env bash
# Rebuild unsigned IPA untuk sideload (Sideloadly).
# Pakai: ./build_ipa.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> flutter build ipa (no codesign)"
flutter build ipa --no-codesign

APP="$ROOT/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
STG="$ROOT/build/ios/ipa_manual"
OUT="$ROOT/build/ios/apk_stock-unsigned.ipa"

echo "==> packaging IPA"
rm -rf "$STG"
mkdir -p "$STG/Payload"
cp -R "$APP" "$STG/Payload/"
( cd "$STG" && zip -qr "$OUT" Payload )
rm -rf "$STG"

echo "==> done: $OUT"
ls -lh "$OUT"
