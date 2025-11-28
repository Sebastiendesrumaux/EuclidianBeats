#!/data/data/com.termux/files/usr/bin/bash
set -e

FILE="app/src/main/java/com/example/appdummy/MainActivity.java"

echo "📄 Patch glitch horizontal sur $FILE"

########################################
# A) Champ glitchLevel
########################################
sed -i '/private double currentBpm = DEFAULT_BPM;/a\
    private double glitchLevel = 0.0;' "$FILE"

########################################
# B) Champs glitchSeek / glitchLabel
########################################
sed -i '/private TextView noteLabel;/a\
    private SeekBar glitchSeek;\
    private TextView glitchLabel;' "$FILE"

########################################
# C) Création du label/slider glitch dans onCreate
#    (après noteSeek.setProgress(50);)
########################################
sed -i '/noteSeek.setProgress(50);/a\
        glitchLabel = new TextView(this);\
        glitchLabel.setTextColor(Color.WHITE);\
        glitchLabel.setTextSize(16f);\
        glitchLabel.setText("Glitch : 0 %");\
\
        glitchSeek = new SeekBar(this);\
        glitchSeek.setMax(100);\
        glitchSeek.setProgress(0);' "$FILE"

########################################
# D) Ajout du glitch dans le layout (au-dessus du Save)
########################################
sed -i 's@        root.addView(noteLabel);@        root.addView(noteLabel);\
        root.addView(noteSeek);\
        root.addView(glitchLabel);\
        root.addView(glitchSeek);@' "$FILE"

# On enlève l'ancien root.addView(noteSeek); doublé
sed -i '/root.addView(noteSeek);/{
    x
    /noteSeek/{
        n
    }
}' "$FILE"

########################################
# E) Listener pour glitchSeek (après le listener de noteSeek)
########################################
sed -i '/noteSeek.setOnSeekBarChangeListener/,/});/ {
  /});/a\
        glitchSeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {\
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {\
                glitchLevel = progress / 100.0;\
                if (glitchLabel != null) {\
                    glitchLabel.setText("Glitch : " + progress + " %");\
                }\
            }\
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}\
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}\
        });
}' "$FILE"

########################################
# F) playSampleWithGlitch() avant la section Sauvegarde
########################################
sed -i '/\/\/ --- Sauvegarde \/ restauration de l état ---/i\
    // --- Lecture de samples avec glitch (pitch + volume) ---\
    private void playSampleWithGlitch(int soundId) {\
        if (soundPool == null || soundId == 0) return;\
\
        // variation de pitch ±8 % modulée par glitchLevel\
        double p = (Math.random() * 2.0 - 1.0) * glitchLevel * 0.08;\
        float rate = (float)(1.0 + p);\
        if (rate < 0.5f) rate = 0.5f;\
        if (rate > 2.0f) rate = 2.0f;\
\
        // variation de volume ±30 % modulée par glitchLevel, basée sur le volume drums\
        float baseVol = 1.0f;\
        if (drumSeek != null) {\
            baseVol = drumSeek.getProgress() / 100.0f;\
        }\
        double a = (Math.random() * 2.0 - 1.0) * glitchLevel * 0.30;\
        float vol = (float)(baseVol * (1.0 + a));\
        if (vol < 0f) vol = 0f;\
        if (vol > 1f) vol = 1f;\
\
        soundPool.play(soundId, vol, vol, 1, 0, rate);\
    }\
\
' "$FILE"

########################################
# G) Rediriger les play*Voice() samples vers playSampleWithGlitch()
########################################
sed -i 's@soundPool.play(sampleKickId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleKickId);@' "$FILE"
sed -i 's@soundPool.play(sampleSnareId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleSnareId);@' "$FILE"
sed -i 's@soundPool.play(sampleHatOpenId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleHatOpenId);@' "$FILE"
sed -i 's@soundPool.play(sampleHatClosedId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleHatClosedId);@' "$FILE"

########################################
# H) Sauvegarder glitchLevel
########################################
sed -i '/if (noteSeek != null) e.putInt("noteVol", noteSeek.getProgress());/a\
        e.putFloat("glitchLevel", (float) glitchLevel);' "$FILE"

########################################
# I) Restaurer glitchLevel
########################################
sed -i '/int noteVol = prefs.getInt("noteVol", 50);/a\
        glitchLevel = prefs.getFloat("glitchLevel", 0f);' "$FILE"

sed -i '/if (noteSeek != null) noteSeek.setProgress(noteVol);/a\
        if (glitchSeek != null) glitchSeek.setProgress((int)(glitchLevel * 100));\
        if (glitchLabel != null) glitchLabel.setText("Glitch : " + (int)(glitchLevel * 100) + " %");' "$FILE"

echo "✅ Patch glitch horizontal appliqué."
