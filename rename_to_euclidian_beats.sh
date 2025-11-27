#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[1/3] Changement du nom de projet Gradle…"
sed -i 's/rootProject.name = "AppDummy"/rootProject.name = "EuclidianBeats"/' settings.gradle

echo "[2/3] Changement du label de l’application (nom affiché sous l’icône)…"
sed -i 's/android:label="AppDummy"/android:label="EuclidianBeats"/' app/src/main/AndroidManifest.xml

echo "[3/3] Ajustements optionnels dans MainActivity (log et éventuel texte)…"
if [ -f "app/src/main/java/com/example/appdummy/MainActivity.java" ]; then
  sed -i 's/"AppDummy"/"EuclidianBeats"/g' app/src/main/java/com/example/appdummy/MainActivity.java
  sed -i 's/Hello AppDummy/EuclidianBeats/' app/src/main/java/com/example/appdummy/MainActivity.java 2>/dev/null || true
fi

echo "✅ Renommage terminé : projet & app s’appellent maintenant EuclidianBeats."
