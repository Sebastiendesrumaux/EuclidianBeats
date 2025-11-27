#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour de MainActivity avec bouton orange aléatoire (0..16 pulses)…"

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
 * - 16 points bleus = steps réguliers = kick
 * - pulses oranges euclidiens = snare
 * - BPM initial = 60 (1 step = 1 beat)
 * - Tap tempo
 * - Bouton orange : choisit aléatoirement le nombre de pulses (0..16),
 *   recalcule le motif euclidien et met à jour la vue.
 */
public class MainActivity extends AppCompatActivity {

    private static final int STEPS = 16;         // points bleus
    private static final int INITIAL_PULSES = 5; // nombre de pulses au démarrage

    private static final double STEPS_PER_BEAT = 1.0;  // 1 bleu = 1 battement
    private static final double DEFAULT_BPM = 60.0;

    private static final double MIN_BPM = 40.0;
    private static final double MAX_BPM = 260.0;

    private RhythmCircleView circleView;
    private SoundEngine soundEngine;

    private int pulses = INITIAL_PULSES; // nombre de pulses courants (oranges)
    private boolean[] pattern;           // motif euclidien
    private double secondsPerStep;
    private double currentBpm = DEFAULT_BPM;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private int currentStep = 0;

    private final List<Long> tapTimes = new ArrayList<>();
    private static final int MAX_TAPS_MEMORY = 8;
    private static final long MAX_INTERVAL_MS = 2000;

    private final Runnable tickRunnable = new Runnable() {
        @Override public void run() {
            currentStep = (currentStep + 1) % STEPS;
            circleView.setCurrentStep(currentStep);

            // BLEU : kick à chaque step
            soundEngine.playStep();

            // ORANGE : snare si le motif le demande
            if (pattern != null && currentStep < pattern.length && pattern[currentStep]) {
                soundEngine.playPulse();
            }

            long delayMs = (long) Math.round(secondsPerStep * 1000.0);
            handler.postDelayed(this, delayMs);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // --- UI : layout vertical, cercle + bouton ---
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.BLACK);
        root.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT));

        circleView = new RhythmCircleView(this, null);
        circleView.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f)); // occupe tout l'espace disponible

        Button randomButton = new Button(this);
        randomButton.setAllCaps(false);
        randomButton.setTextColor(Color.BLACK);
        randomButton.setBackgroundColor(0xFFFF9800); // orange
        randomButton.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        // texte initial
        randomButton.setText("Pulses oranges : " + pulses + " (tap pour random 0..16)");

        root.addView(circleView);
        root.addView(randomButton);
        setContentView(root);

        // BPM initial
        applyBpm(DEFAULT_BPM);

        // motif euclidien initial
        pattern = makeEuclideanPattern(STEPS, pulses);
        circleView.updatePattern(pattern, STEPS, secondsPerStep);

        // KICK + SNARE
        soundEngine = new SoundEngine(
                44_100,
                SoundEngine.Waveform.KICK, 80.0, 160, 2, 140,
                SoundEngine.Waveform.SNARE, 200.0, 140, 2, 120
        );

        // Tap tempo sur tout le cercle
        circleView.setOnTouchListener(new View.OnTouchListener() {
            @Override public boolean onTouch(View v, MotionEvent e) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) {
                    handleTapTempo(e.getEventTime());
                    return true;
                }
                return false;
            }
        });

        // Bouton orange : random pulses entre 0 et 16
        randomButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                int newPulses = (int) Math.floor(Math.random() * (STEPS + 1)); // 0..16
                pulses = newPulses;
                pattern = makeEuclideanPattern(STEPS, pulses);
                circleView.updatePattern(pattern, STEPS, secondsPerStep);
                randomButton.setText("Pulses oranges : " + pulses + " (tap pour random 0..16)");
            }
        });
    }

    @Override protected void onResume() { super.onResume(); startLoop(); }
    @Override protected void onPause()  { super.onPause();  stopLoop();  }
    @Override protected void onDestroy(){
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

    // --- TAP TEMPO ---
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

    // --- Algorithme d'Euclide E(steps, pulses) ---
    private static boolean[] makeEuclideanPattern(int steps, int pulses) {
        boolean[] pattern = new boolean[steps];
        if (pulses <= 0) return pattern;
        if (pulses > steps) pulses = steps;

        for (int i = 0; i < pulses; i++) {
            int index = (int) Math.floor(i * (steps / (double) pulses));
            if (index < 0) index = 0;
            if (index >= steps) index = steps - 1;
            pattern[index] = true;
        }
        return pattern;
    }
}
JAVAEOF

echo "✅ MainActivity mise à jour avec bouton orange aléatoire."
