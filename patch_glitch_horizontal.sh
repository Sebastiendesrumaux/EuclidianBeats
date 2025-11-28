#!/data/data/com.termux/files/usr/bin/bash
set -e

FILE="app/src/main/java/com/example/appdummy/MainActivity.java"

echo "📄 Patch glitch horizontal sur \$FILE"

########################################
# (A) Ajout champ glitchLevel si absent
########################################

grep -q "glitchLevel" "$FILE" || sed -i '/private double secondsPerStep;/a\
    private double glitchLevel = 0.0;' "$FILE"

########################################
# (B) Ajout glitchSeek + glitchLabel
########################################

grep -q "glitchSeek" "$FILE" || sed -i '/private SeekBar noteSeek;/a\
    private SeekBar glitchSeek;\
    private TextView glitchLabel;' "$FILE"

########################################
# (C) Ajout du slider horizontal glitch sous les volumes
########################################

# On insère juste après noteLabel + noteSeek
sed -i '/root.addView(noteSeek);/a\
        glitchLabel = new TextView(this);\
        glitchLabel.setTextColor(Color.WHITE);\
        glitchLabel.setTextSize(16f);\
        glitchLabel.setText("Glitch : " + (int)(glitchLevel * 100) + " %");\
\
        glitchSeek = new SeekBar(this);\
        glitchSeek.setMax(100);\
        glitchSeek.setProgress((int)(glitchLevel * 100));\
\
        root.addView(glitchLabel);\
        root.addView(glitchSeek);\
' "$FILE"

########################################
# (D) Listener glitchSeek
########################################

sed -i '/noteSeek.setOnSeekBarChangeListener/,/});/ {
  /});/a\
        glitchSeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {\
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {\
                glitchLevel = progress / 100.0;\
                glitchLabel.setText("Glitch : " + progress + " %");\
            }\
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}\
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}\
        });
}' "$FILE"


########################################
# (E) Ajouter playSampleWithGlitch() si absent
########################################

grep -q "playSampleWithGlitch" "$FILE" || sed -i '/\/\/ --- Sauvegarde \/ restauration de l état ---/i\
    // --- Lecture de samples avec glitch (pitch + volume) ---\
    private void playSampleWithGlitch(int soundId) {\
        if (soundPool == null || soundId == 0) return;\
\
        // variation de pitch ±8 % modulée par glitchLevel\
        double p = (Math.random() * 2 - 1) * glitchLevel * 0.08;\
        float rate = (float)(1.0 + p);\
        if (rate < 0.5f) rate = 0.5f;\
        if (rate > 2.0f) rate = 2.0f;\
\
        // variation de volume ±30 % modulée par glitchLevel\
        double a = (Math.random() * 2 - 1) * glitchLevel * 0.30;\
        float vol = (float)(1.0 + a);\
        if (vol < 0f) vol = 0f;\
        if (vol > 1f) vol = 1f;\
\
        soundPool.play(soundId, vol, vol, 1, 0, rate);\
    }\
' "$FILE"


########################################
# (F) Redirection des playSample vers playSampleWithGlitch
########################################

sed -i 's@soundPool.play(sampleKickId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleKickId);@' "$FILE"
sed -i 's@soundPool.play(sampleSnareId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleSnareId);@' "$FILE"
sed -i 's@soundPool.play(sampleHatOpenId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleHatOpenId);@' "$FILE"
sed -i 's@soundPool.play(sampleHatClosedId, 1f, 1f, 1, 0, 1f);@playSampleWithGlitch(sampleHatClosedId);@' "$FILE"


########################################
# (G) Ajouter glitchLevel à la SAUVEGARDE
########################################

sed -i '/e.putInt("noteVol"/a\
        e.putFloat("glitchLevel", (float) glitchLevel);' "$FILE"


########################################
# (H) Ajouter glitchLevel à la RESTAURATION
########################################

sed -i '/int noteVol = prefs.getInt("noteVol"/a\
        glitchLevel = prefs.getFloat("glitchLevel", 0f);' "$FILE"

sed -i '/glitchLevel = prefs.getFloat("glitchLevel"/a\
        if (glitchSeek != null) glitchSeek.setProgress((int)(glitchLevel * 100));\
        if (glitchLabel != null) glitchLabel.setText("Glitch : " + (int)(glitchLevel * 100) + " %");' "$FILE"


echo "✅ Patch glitch horizontal appliqué."
