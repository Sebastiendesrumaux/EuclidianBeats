#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Build direct avec Gradle (assembleDebug)…"
# Sur /storage/emulated/0 on ne peut pas exécuter ./gradlew (noexec),
# donc on passe par bash :
bash ./gradlew assembleDebug

echo "▶️ Recherche de l'APK debug produit par Gradle…"

APK_SRC=""

if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
  APK_SRC="app/build/outputs/apk/debug/app-debug.apk"
else
  # plan B : chercher n'importe quel *debug.apk dans app/
  APK_SRC="$(find app -name '*debug.apk' | head -n 1 || true)"
fi

if [ -z "$APK_SRC" ] || [ ! -f "$APK_SRC" ]; then
  echo "❌ Impossible de trouver un APK debug dans app/."
  echo "   Tu peux essayer manuellement :  find app -name '*debug.apk'"
  exit 1
fi

echo "   APK trouvé : $APK_SRC"

APK_DST="/storage/emulated/0/Download/EuclidianBeats-fresh-debug.apk"

echo "▶️ Copie de $APK_SRC vers $APK_DST…"
cp "$APK_SRC" "$APK_DST"

echo "▶️ Ouverture de l'APK fraîchement construit…"
termux-open "$APK_DST"

echo
echo "ℹ️ L'installateur Android devrait s'ouvrir."
echo "   Choisis « Installer », puis « Ouvrir » pour lancer la nouvelle version."
