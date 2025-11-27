#!/data/data/com.termux/files/usr/bin/bash
set -e
PROJECT_DIR="$(pwd)"

{
  echo "===== DUMP PROJET ANDROID SOUS TERMUX ====="
  echo
  echo "=== Date ==="
  date
  echo
  echo "=== Répertoire courant ==="
  echo "$PROJECT_DIR"
  echo

  echo "=== termux-info ==="
  termux-info 2>/dev/null || echo "termux-info indisponible"
  echo

  echo "=== java -version ==="
  java -version 2>&1 || echo "java non trouvé"
  echo

  echo "=== ls (racine du projet) ==="
  ls -la
  echo

  echo "=== Arborescence (profondeur 5) ==="
  find . -maxdepth 5 -type f | sort
  echo

  for f in \
    "settings.gradle" \
    "build.gradle" \
    "gradle.properties" \
    "app/build.gradle" \
    "app/proguard-rules.pro"
  do
    if [ -f "$f" ]; then
      echo "===== CONTENU: $f ====="
      cat "$f"
      echo
    fi
  done

  if [ -f "app/src/main/AndroidManifest.xml" ]; then
    echo "===== CONTENU: app/src/main/AndroidManifest.xml ====="
    cat app/src/main/AndroidManifest.xml
    echo
  fi

  echo "=== LISTE DES FICHIERS JAVA ==="
  find app/src -type f -name "*.java" | sort
  echo

  while IFS= read -r jf; do
    echo "===== CONTENU JAVA: $jf ====="
    cat "$jf"
    echo
  done < <(find app/src -type f -name "*.java" | sort)

  echo "===== FIN DU DUMP ====="
} | termux-clipboard-set
