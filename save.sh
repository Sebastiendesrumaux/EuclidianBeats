#!/data/data/com.termux/files/usr/bin/bash

git config --global --add safe.directory /storage/emulated/0/AndroidIDE/AppProjects/Euclide

git add -A

msg="Save $(date '+%Y-%m-%d %H:%M:%S')"
git commit -m "$msg"

git push origin main
