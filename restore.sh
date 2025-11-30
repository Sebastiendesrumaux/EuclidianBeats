#!/data/data/com.termux/files/usr/bin/bash

# Se placer dans le dossier où se trouve ce script (normalement Euclide)
cd "$(dirname "$0")" || exit 1

echo "[RESTORE] Retour à la dernière version sauvée dans Git…"

# Récupère l'état du dépôt distant (si connexion dispo, sinon ça continuera avec ce qu'il connaît déjà)
git fetch origin

# Remet TOUT le projet exactement comme sur le dernier commit de origin/main
git reset --hard origin/main

# Supprime tous les fichiers non suivis (les MainActivity_partX.java, etc.)
git clean -fd

echo "[RESTORE] Terminé. Projet remis au dernier commit Git."
