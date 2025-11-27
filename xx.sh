#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

# === CONFIG MINIMALE ===
PROJECT="/storage/emulated/0/AndroidIDE/AppProjects/AppDummy"
APK="$PROJECT/app/build/outputs/apk/debug/app-debug.apk"
# Fallback si détection automatique échoue :
FALLBACK_APP_ID="com.example.appdummy"

# --- Détection de l'applicationId dans app/build.gradle ---
APP_ID="$(awk -F'"' '/applicationId[[:space:]]+"/{print $2; found=1; exit} END{if(!found) print ""}' "$PROJECT/app/build.gradle" 2>/dev/null || true)"
if [ -z "${APP_ID:-}" ]; then
  APP_ID="$FALLBACK_APP_ID"
fi

echo "🔎 applicationId: $APP_ID"
echo "🔎 APK: $APK"

if [ ! -f "$APK" ]; then
  echo "⚠️  APK introuvable. Compile d'abord :"
  echo "    bash $PROJECT/build.sh"
  exit 1
fi

# --- Petite fonction d'essai de désinstallation silencieuse ---
try_uninstall() {
  local pkg="$1"
  echo "🧹 Tentative de désinstallation silencieuse de: $pkg"
  # Essai 1 : cmd package
  if cmd package uninstall "$pkg" >/dev/null 2>&1; then
    echo "✅ Désinstallation (cmd package) réussie."
    return 0
  fi
  # Essai 2 : pm uninstall
  if pm uninstall "$pkg" >/dev/null 2>&1; then
    echo "✅ Désinstallation (pm) réussie."
    return 0
  fi
  return 1
}

# --- Essayer de désinstaller si une version existe ---
if pm list packages | grep -q "$APP_ID"; then
  echo "ℹ️  Une version de $APP_ID est déjà installée."
  if ! try_uninstall "$APP_ID"; then
    echo "🙇  Désinstallation silencieuse impossible (droits restreints)."
    echo "📲 Ouverture de la page Système pour désinstaller manuellement…"
    am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d "package:$APP_ID" >/dev/null 2>&1 || true
    echo
    read -p "➡️  Désinstalle l’app puis appuie [Entrée] pour continuer à l’installation… " _
  fi
fi

# --- Lancer l’installateur sur l’APK ---
echo "📦 Lancement de l’installateur Android…"
termux-open "$APK" >/dev/null 2>&1 || {
  echo "⚠️  termux-open indisponible ou refusé."
  echo "   Ouvre ton Gestionnaire de fichiers → Téléchargements, puis tape sur l’APK."
}

echo "✨ Done. Si conflit de signature : désinstalle l’ancienne app puis relance ce script."
