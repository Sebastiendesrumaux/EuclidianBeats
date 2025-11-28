#!/data/data/com.termux/files/usr/bin/bash
set -e

FILE="app/src/main/java/com/example/appdummy/MainActivity.java"

echo "🎨 Patch couleurs du slider glitch"

# Ajout des couleurs juste après l’instanciation du glitchSeek
sed -i '/glitchSeek = new SeekBar(this);/a\
        glitchSeek.getProgressDrawable().setColorFilter(0xFFCCCCCC, android.graphics.PorterDuff.Mode.SRC_IN); \
        glitchSeek.getThumb().setColorFilter(0xFF00BCD4, android.graphics.PorterDuff.Mode.SRC_IN);' "$FILE"

echo "✅ Couleurs appliquées."
