#!/data/data/com.termux/files/usr/bin/bash
set -e

FILE="app/src/main/java/com/example/appdummy/MainActivity.java"

echo "📄 Patch glitch slider sur \$FILE"

########################################
# 1) Champ glitchLevel + champs glitchSeek / glitchLabel
########################################

# Ajoute glitchLevel après secondsPerStep
sed -i '/private double secondsPerStep;/a\
    private double glitchLevel = 0.0;' "$FILE"

# Ajoute glitchSeek et glitchLabel après noteSeek
sed -i '/private SeekBar noteSeek;/a\
    private SeekBar glitchSeek;\
    private TextView glitchLabel;' "$FILE"

########################################
# 2) Remplace root.addView(circleView) par centre + colonne droite
########################################

sed -i 's@        root.addView(circleView);@        // Centre : cercle + colonne droite (glitch)\
        LinearLayout centerRow = new LinearLayout(this);\
        centerRow.setOrientation(LinearLayout.HORIZONTAL);\
        centerRow.setLayoutParams(new LinearLayout.LayoutParams(\
                LinearLayout.LayoutParams.MATCH_PARENT,\
                0,\
                1f));\
\
        LinearLayout rightColumn = new LinearLayout(this);\
        rightColumn.setOrientation(LinearLayout.VERTICAL);\
        rightColumn.setLayoutParams(new LinearLayout.LayoutParams(\
                LinearLayout.LayoutParams.WRAP_CONTENT,\
                LinearLayout.LayoutParams.MATCH_PARENT));\
\
        glitchLabel = new TextView(this);\
        glitchLabel.setTextColor(Color.WHITE);\
        glitchLabel.setTextSize(14f);\
        glitchLabel.setText("Glitch : " + (int) Math.round(glitchLevel * 100.0) + "%");\
        glitchLabel.setRotation(90);\
\
        glitchSeek = new SeekBar(this);\
        glitchSeek.setMax(100);\
        glitchSeek.setProgress((int) Math.round(glitchLevel * 100.0));\
        glitchSeek.setRotation(-90);\
        glitchSeek.setLayoutParams(new LinearLayout.LayoutParams(\
                300,\
                LinearLayout.LayoutParams.WRAP_CONTENT));\
\
        rightColumn.addView(glitchLabel);\
        rightColumn.addView(glitchSeek);\
\
        circleView.setLayoutParams(new LinearLayout.LayoutParams(\
                0,\
                LinearLayout.LayoutParams.MATCH_PARENT,\
                1f));\
\
        centerRow.addView(circleView);\
        centerRow.addView(rightColumn);\
\
        root.addView(centerRow);@' "$FILE"

########################################
# 3) Listener pour glitchSeek (après celui de noteSeek)
########################################

sed -i '/noteSeek.setOnSeekBarChangeListener/,/});/ {
  /});/a\
        glitchSeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {\
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {\
                glitchLevel = progress / 100.0;\
                if (glitchLabel != null) {\
                    glitchLabel.setText("Glitch : " + progress + "%");\
                }\
            }\
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}\
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}\
        });
}' "$FILE"

########################################
# 4) playSampleWithGlitch() et utilisation dans play*Voice()
########################################

# Kick
sed -i 's@soundPool.play(sampleKickId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleKickId);@' "$FILE"
# Snare
sed -i 's@soundPool.play(sampleSnareId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleSnareId);@' "$FILE"
# Hat open
sed -i 's@soundPool.play(sampleHatOpenId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleHatOpenId);@' "$FILE"
# Hat closed
sed -i 's@soundPool.play(sampleHatClosedId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleHatClosedId);@' "$FILE"

# Insère la méthode playSampleWithGlitch avant le bloc de sauvegarde/restauration
sed -i '/\/\/ --- Sauvegarde \/ restauration de l état ---/i\
    // --- Lecture de samples avec glitch (pitch + volume) ---\
    private void playSampleWithGlitch(int soundId) {\
        if (soundPool == null || soundId == 0) return;\
\
        // variation de pitch ±8 % au max, modulée par glitchLevel\
        double pitchJitter = (Math.random() * 2.0 - 1.0) * glitchLevel * 0.08; \
        float rate = (float) (1.0 + pitchJitter);\
        if (rate < 0.5f) rate = 0.5f;\
        if (rate > 2.0f) rate = 2.0f;\
\
        // variation de volume ±30 % au max, modulée par glitchLevel\
        double ampJitter = (Math.random() * 2.0 - 1.0) * glitchLevel * 0.30; \
        float baseVol = 1.0f;\
        float vol = (float) (baseVol * (1.0 + ampJitter));\
        if (vol < 0f) vol = 0f;\
        if (vol > 1f) vol = 1f;\
\
        soundPool.play(soundId, vol, vol, 1, 0, rate);\
    }\
\
' "$FILE"

########################################
# 5) Sauvegarder et restaurer glitchLevel
########################################

# Sauvegarde glitchLevel
sed -i '/if (noteSeek != null) e.putInt("noteVol", noteSeek.getProgress());/a\
        e.putFloat("glitchLevel", (float) glitchLevel);' "$FILE"

# Restauration glitchLevel + synchro slider
sed -i '/int noteVol = prefs.getInt("noteVol", 50);/a\
        glitchLevel = prefs.getFloat("glitchLevel", 0f);\
        if (glitchSeek != null) {\
            glitchSeek.setProgress((int) Math.round(glitchLevel * 100.0));\
        }\
        if (glitchLabel != null) {\
            glitchLabel.setText("Glitch : " + (int) Math.round(glitchLevel * 100.0) + "%");\
        }' "$FILE"

echo "✅ Patch glitch appliqué."
