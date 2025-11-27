#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PROJECT="/storage/emulated/0/AndroidIDE/AppProjects/AppDummy"
PKG="com.example.appdummy"
ACTIVITY=".MainActivity"
LOGFILE="$PROJECT/last_run.log"
OBS_SECONDS="${OBS_SECONDS:-12}"   # fenêtre d’observation (modifiable), 12s par défaut

say () { termux-tts-speak "$1" >/dev/null 2>&1 || echo "$1"; }

# On nettoie le logcat pour ne garder que l’instant présent
logcat -c || true

# Lancement de l’activité
am start -n "$PKG/$ACTIVITY" >/dev/null 2>&1 || true

# Si possible, on cible le PID de l’appli pour un log chirurgical
PID="$(pidof "$PKG" 2>/dev/null || true)"

# On écoute le log quelques secondes ; si PID connu, on l’utilise
if [ -n "$PID" ]; then
  # -v threadtime : horodatage riche ; --pid : filtre process
  timeout "$OBS_SECONDS" logcat -v threadtime --pid="$PID" \
  | tee "$LOGFILE" \
  | awk '/FATAL EXCEPTION|AndroidRuntime|Exception|Crash| ANR /{print $0}' \
  >/dev/null 2>&1 || true
else
  # Pas de PID ? On scrute les signaux usuels de crash
  timeout "$OBS_SECONDS" logcat -v threadtime \
  | tee "$LOGFILE" \
  | awk '/FATAL EXCEPTION|AndroidRuntime|Exception|Crash| ANR |'"$PKG"'/ {print $0}' \
  >/dev/null 2>&1 || true
fi

# On ajoute un marqueur de fin et quelques infos système utiles
{
  echo ""
  echo "---- [AppDummy run.sh] Fin de capture: $(date) ----"
  echo "Package: $PKG  Activity: $ACTIVITY  PID: ${PID:-unknown}"
} >> "$LOGFILE"

# Copie du log complet dans le presse-papiers (et notification via withclip)
cat "$LOGFILE" | withclip --notify --trim

# Petit chant d’état, selon présence d’une trace fatale
if grep -E 'FATAL EXCEPTION|AndroidRuntime| ANR ' -q "$LOGFILE"; then
  say "Aïe. Le phénix a toussé : une exception fatale a été capturée. Le log est dans le presse papiers."
else
  say "Tout semble apaisé. Pas de crash flagrant dans la fenêtre d’observation. Le log est dans le presse papiers."
fi
