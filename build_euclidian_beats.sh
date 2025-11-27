#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Build via build.sh…"
bash build.sh

APK_DIR="/storage/emulated/0/Download"
SRC_APK="$APK_DIR/AppDummy-debug.apk"
DST_APK="$APK_DIR/EuclidianBeats-debug.apk"

if [ -f "$SRC_APK" ]; then
  cp "$SRC_APK" "$DST_APK"
  echo "✅ APK copié vers : $DST_APK"
else
  echo "❌ APK source introuvable : $SRC_APK"
fi
