#!/usr/bin/env bash
# Build APK release + siapkan folder upload (apkstock.apk).
#
# Alur rilis update:
#   1. Naikkan `version:` di pubspec.yaml — angka build (setelah +) HARUS naik.
#        contoh: 1.0.1+2  ->  1.0.2+3
#   2. Jalankan: ./build_apk.sh
#   3. Edit build/release/update.json (samakan "version" & "build" dgn pubspec,
#      tulis "notes" perubahan).
#   4. Upload 2 file di build/release/ ke cPanel: public_html/apkstock/
#
# Kunci: field "build" di update.json harus > build yang terpasang di HP user,
# kalau tidak dialog update tak muncul.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> flutter build apk --release"
flutter build apk --release

OUT="$ROOT/build/release"
mkdir -p "$OUT"
cp "$ROOT/build/app/outputs/flutter-apk/app-release.apk" "$OUT/apkstock.apk"

# Ambil versi dari pubspec buat ditampilkan sbg pengingat.
VER_LINE="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
NAME="${VER_LINE%+*}"
BUILD="${VER_LINE#*+}"

echo ""
echo "==> APK siap: $OUT/apkstock.apk"
echo "==> pubspec version: $NAME (build $BUILD)"
echo ""
echo "JANGAN LUPA edit $OUT/update.json ->  \"version\": \"$NAME\",  \"build\": $BUILD"
echo "lalu upload apkstock.apk + update.json ke cPanel: public_html/apkstock/"
ls -lh "$OUT"
