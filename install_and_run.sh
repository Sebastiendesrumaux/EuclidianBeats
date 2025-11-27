#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Build de EuclidianBeats…"
bash build.sh

APK_DIR="/storage/emulated/0/Download"
SRC="$APK_DIR/AppDummy-debug.apk"
DST="$APK_DIR/EuclidianBeats-debug.apk"

echo "▶️ Vérification de l’APK généré…"
if [ ! -f "$SRC" ]; then
  echo "❌ APK introuvable : $SRC"
  exit 1
fi

echo "▶️ Copie et renommage de l’APK…"
cp "$SRC" "$DST"
echo "   → $DST"

echo "▶️ Ouverture de l’APK avec le système (installateur Android)…"
termux-open "$DST"

echo
echo "ℹ️ Une fenêtre d’installation Android devrait apparaître."
echo "   → Appuie sur « Installer », puis « Ouvrir » pour lancer EuclidianBeats."
