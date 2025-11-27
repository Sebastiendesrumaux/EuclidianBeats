#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools"

PROJECT="/storage/emulated/0/AndroidIDE/AppProjects/AppDummy"
OUTDIR="$PROJECT/app/build/outputs/apk/debug"
TARGET="/storage/emulated/0/Download/AppDummy-debug.apk"

say_success() {
  local msg="Victoire cristalline : le build a tenu la cadence, capitaine Sébastien."
  termux-tts-speak "$msg" >/dev/null 2>&1 || echo "$msg"
}
say_failure() {
  local msg="Hélas, le marteau a glissé sur l’enclume : le build a trébuché."
  termux-tts-speak "$msg" >/dev/null 2>&1 || echo "$msg"
}

cd "$PROJECT"

(
  set +e
  echo "🚀 Début du build à $(date)"
  sh ./gradlew --no-daemon assembleDebug
  RC=$?

  if [ $RC -eq 0 ]; then
    OUTAPK="$OUTDIR/app-debug.apk"
    if [ -f "$OUTAPK" ]; then
      cp -f "$OUTAPK" "$TARGET" && echo "✅ Build OK → $TARGET"
      say_success
      if [ -x "$PROJECT/run.sh" ]; then
        echo "🎬 Lancement de run.sh avec capture log…"
        # OBS_SECONDS ajustable à la volée si besoin (ex: 20)
        OBS_SECONDS=12 bash "$PROJECT/run.sh"
      fi
    else
      echo "⚠️  Build OK mais APK introuvable dans $OUTDIR"
      say_failure
    fi
  else
    echo "❌ Build échoué (code $RC)"
    say_failure
  fi

  echo "⏳ Fin des logs à $(date)"
) 2>&1 | withclip --notify --trim
