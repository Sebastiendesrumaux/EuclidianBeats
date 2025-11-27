#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour de MainActivity pour steps bleus variables (2..32) avec boutons +/-"

cat > app/src/main/java/com/example/appdummy/MainActivity.java << 'JAVAEOF'
package com.example.appdummy;

import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;

import androidx.appcompat.app.AppCompatActivity;

import java.util.ArrayList;
import java.util.List;

/**
 * EuclidianBeats :
 * - steps bleus variables (2..32) = KICK, tempo maître
 * - pulses oranges euclidiens = SNARE
 * - pulses verts euclidiens   = HI-HAT OUVERT
 * - pulses roses euclidiens   = HI-HAT FERMÉ
 * - BPM initial = 60 (1 step = 1 beat)
 * - Tap tempo
 * - Bouton bleu "-"  : diminue le nombre de steps bleus (min 2)
 * - Bouton bleu "+"  : augmente le nombre de steps bleus (max 32)
 * - Bouton orange : random pulses oranges (0..steps)
 * - Bouton vert   : random pulses verts   (0..steps)
 * - Bouton rose   : random pulses roses  (0..steps)
 * - La boucle continue même écran éteint (onPause ne stoppe pas la loop)
 */
public class MainActivity extends AppCompatActivity {

    private static final int MIN_STEPS = 2;
    private static final int MAX_STEPS = 32;

    private static final int INITIAL_STEPS         = 16;
    private static final int INITIAL_PULSES_ORANGE = 5;
    private static final int INITIAL_PULSES_GREEN  = 0;
    private static final int INITIAL_PULSES_PINK   = 0;

    private static final double DEFAULT_BPM = 60.0;
    private static final double MIN_BPM = 40.0;
    private static final double MAX_BPM = 260.0;

    private RhythmCircleView circleView;
    private SoundEngine soundEngine;

    private int steps        = INITIAL_STEPS;
    private int pulsesOrange = INITIAL_PULSES_ORANGE;
    private int pulsesGreen  = INITIAL_PULSES_GREEN;
    private int pulsesPink   = INITIAL_PULSES_PINK;

    private boolean[] patternOrange;
    private boolean[] patternGreen;
    private boolean[] patternPink;

    private double secondsPerStep;
    private double currentBpm = DEFAULT_BPM;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private int currentStep = 0;

    private final List<Long> tapTimes = new ArrayList<>();
    private static final int MAX_TAPS_MEMORY = 8;
    private static final long MAX_INTERVAL_MS = 2000;

    private final Runnable tickRunnable = new Runnable() {
        @Override public void run() {
            currentStep = (currentStep + 1) % steps;
            circleView.setCurrentStep(currentStep);

            // Kick à chaque step (bleu)
            soundEngine.playKick();

            // Snare sur pulses oranges
            if (patternOrange != null &&
                currentStep < patternOrange.length &&
                patternOrange[currentStep]) {
                soundEngine.playSnare();
            }

            // Hat ouvert (vert)
            if (patternGreen != null &&
                currentStep < patternGreen.length &&
                patternGreen[currentStep]) {
                soundEngine.playHatOpen();
            }

            // Hat fermé (rose)
            if (patternPink != null &&
                currentStep < patternPink.length &&
                patternPink[currentStep]) {
                soundEngine.playHatClosed();
            }

            long delayMs = (long) Math.round(secondsPerStep * 1000.0);
            handler.postDelayed(this, delayMs);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // --- UI racine ---
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.BLACK);
        root.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT));

        // Vue cercle
        circleView = new RhythmCircleView(this, null);
        circleView.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f));

        // --- Barre des boutons bleus (+/-) ---
        LinearLayout blueBar = new LinearLayout(this);
        blueBar.setOrientation(LinearLayout.HORIZONTAL);
        blueBar.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button minusBlue = new Button(this);
        minusBlue.setAllCaps(false);
        minusBlue.setTextColor(Color.WHITE);
        minusBlue.setBackgroundColor(0xFF2196F3); // bleu
        minusBlue.setText("- steps");

        Button plusBlue = new Button(this);
        plusBlue.setAllCaps(false);
        plusBlue.setTextColor(Color.WHITE);
        plusBlue.setBackgroundColor(0xFF2196F3); // bleu
        plusBlue.setText("+ steps");

        LinearLayout.LayoutParams lpWeight =
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        minusBlue.setLayoutParams(lpWeight);
        plusBlue.setLayoutParams(lpWeight);

        blueBar.addView(minusBlue);
        blueBar.addView(plusBlue);

        // --- Boutons orange / vert / rose ---
        Button orangeButton = new Button(this);
        orangeButton.setAllCaps(false);
        orangeButton.setTextColor(Color.BLACK);
        orangeButton.setBackgroundColor(0xFFFF9800); // orange
        orangeButton.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button greenButton = new Button(this);
        greenButton.setAllCaps(false);
        greenButton.setTextColor(Color.BLACK);
        greenButton.setBackgroundColor(0xFF4CAF50); // vert
        greenButton.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button pinkButton = new Button(this);
        pinkButton.setAllCaps(false);
        pinkButton.setTextColor(Color.BLACK);
        pinkButton.setBackgroundColor(0xFFE91E63); // rose
        pinkButton.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        // Assemblage
        root.addView(circleView);
        root.addView(blueBar);
        root.addView(orangeButton);
        root.addView(greenButton);
        root.addView(pinkButton);
        setContentView(root);

        // BPM initial
        applyBpm(DEFAULT_BPM);

        // Motifs initiaux
        clampPulsesToSteps();
        recomputePatternsAndUpdateView();

        // Son
        soundEngine = new SoundEngine(44_100);

        // Tap tempo
        circleView.setOnTouchListener(new View.OnTouchListener() {
            @Override public boolean onTouch(View v, MotionEvent e) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) {
                    handleTapTempo(e.getEventTime());
                    return true;
                }
                return false;
            }
        });

        // Labels init
        updateButtonLabels(orangeButton, greenButton, pinkButton);

        // --- Actions des boutons ---

        // Boutons bleus : changer le nombre de steps du cercle bleu
        minusBlue.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (steps > MIN_STEPS) {
                    steps--;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    updateButtonLabels(orangeButton, greenButton, pinkButton);
                }
            }
        });

        plusBlue.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (steps < MAX_STEPS) {
                    steps++;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    updateButtonLabels(orangeButton, greenButton, pinkButton);
                }
            }
        });

        // Bouton orange : random pulses oranges (0..steps)
        orangeButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesOrange = (int) Math.floor(Math.random() * (steps + 1)); // 0..steps
                clampPulsesToSteps();
                recomputePatternsAndUpdateView();
                updateButtonLabels(orangeButton, greenButton, pinkButton);
            }
        });

        // Bouton vert : random pulses verts (0..steps)
        greenButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesGreen = (int) Math.floor(Math.random() * (steps + 1)); // 0..steps
                clampPulsesToSteps();
                recomputePatternsAndUpdateView();
                updateButtonLabels(orangeButton, greenButton, pinkButton);
            }
        });

        // Bouton rose : random pulses roses (0..steps)
        pinkButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesPink = (int) Math.floor(Math.random() * (steps + 1)); // 0..steps
                clampPulsesToSteps();
                recomputePatternsAndUpdateView();
                updateButtonLabels(orangeButton, greenButton, pinkButton);
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        startLoop();
    }

    @Override
    protected void onPause() {
        super.onPause();
        // on NE stoppe PAS la boucle ici, pour qu'elle continue écran éteint
        // stopLoop();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        stopLoop();
        if (soundEngine != null) soundEngine.release();
    }

    private void startLoop() {
        handler.removeCallbacks(tickRunnable);
        currentStep = -1;
        handler.postDelayed(tickRunnable, (long) Math.round(secondsPerStep * 1000.0));
    }

    private void stopLoop() {
        handler.removeCallbacks(tickRunnable);
    }

    // TAP TEMPO
    private void handleTapTempo(long tapTimeMs) {
        if (!tapTimes.isEmpty()) {
            long last = tapTimes.get(tapTimes.size() - 1);
            if (tapTimeMs - last > MAX_INTERVAL_MS)
                tapTimes.clear();
        }

        tapTimes.add(tapTimeMs);
        while (tapTimes.size() > MAX_TAPS_MEMORY)
            tapTimes.remove(0);

        if (tapTimes.size() < 2) return;

        double sum = 0.0;
        int count = 0;
        for (int i = 1; i < tapTimes.size(); i++) {
            long dt = tapTimes.get(i) - tapTimes.get(i - 1);
            if (dt <= 0 || dt > MAX_INTERVAL_MS) continue;
            sum += dt;
            count++;
        }

        if (count == 0) return;

        double bpm = 60000.0 / (sum / count);
        if (bpm < MIN_BPM || bpm > MAX_BPM) return;

        applyBpm(bpm);
    }

    private void applyBpm(double bpm) {
        currentBpm = bpm;
        secondsPerStep = 60.0 / currentBpm; // 1 step = 1 beat
        circleView.setBpm(currentBpm);
        stopLoop();
        startLoop();
    }

    // Assure pulses <= steps à tout moment
    private void clampPulsesToSteps() {
        if (pulsesOrange > steps) pulsesOrange = steps;
        if (pulsesGreen  > steps) pulsesGreen  = steps;
        if (pulsesPink   > steps) pulsesPink   = steps;
        if (pulsesOrange < 0) pulsesOrange = 0;
        if (pulsesGreen  < 0) pulsesGreen  = 0;
        if (pulsesPink   < 0) pulsesPink   = 0;
    }

    // Recalcule les motifs euclidiens et rafraîchit la vue
    private void recomputePatternsAndUpdateView() {
        patternOrange = makeEuclideanPattern(steps, pulsesOrange);
        patternGreen  = makeEuclideanPattern(steps, pulsesGreen);
        patternPink   = makeEuclideanPattern(steps, pulsesPink);
        circleView.updatePatterns(patternOrange, patternGreen, patternPink, steps, secondsPerStep);
    }

    // Met à jour les labels des boutons en fonction de steps
    private void updateButtonLabels(Button orangeButton, Button greenButton, Button pinkButton) {
        orangeButton.setText("Pulses oranges : " + pulsesOrange + " (0.." + steps + ", sur " + steps + " bleus)");
        greenButton.setText("Pulses verts : " + pulsesGreen + " (0.." + steps + ", sur " + steps + " bleus)");
        pinkButton.setText("Pulses roses : " + pulsesPink + " (0.." + steps + ", sur " + steps + " bleus)");
    }

    // motif euclidien "aussi espacé que possible"
    private static boolean[] makeEuclideanPattern(int steps, int pulses) {
        boolean[] pattern = new boolean[steps];
        if (pulses <= 0) return pattern;
        if (pulses > steps) pulses = steps;

        for (int i = 0; i < pulses; i++) {
            int idx = (int) Math.floor(i * (steps / (double) pulses));
            if (idx < 0) idx = 0;
            if (idx >= steps) idx = steps - 1;
            pattern[idx] = true;
        }
        return pattern;
    }
}
JAVAEOF

echo "✅ MainActivity mise à jour (steps bleus 2..32 avec boutons +/-)."
