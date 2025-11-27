#!/data/data/com.termux/files/usr/bin/bash

# Rendre le repo sûr si nécessaire
git config --global --add safe.directory /storage/emulated/0/AndroidIDE/AppProjects/Euclide

# Ajouter tous les fichiers
git add -A

# Commit horodaté
msg="Save $(date '+%Y-%m-%d %H:%M:%S')"
git commit -m "$msg"

# Push vers main
git push origin main
