#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour pour :"
echo "   - 16 steps bleus (kick)"
echo "   - 5 pulses oranges (snare euclidien)"
echo "   - BPM initial = 60"

cat > app/src/main/java/com/example/appdummy/MainActivity.java << 'JAVAEOF'
package com.example.appdummy;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;

import androidx.appcompat.app.AppCompatActivity;

import java.util.ArrayList;
import java.util.List;

/**
 * Version EuclideanBeats (claire et fidèle à ton intention) :
 *
 * - 16 points bleus = steps réguliers = kick
 * - 5 points oranges = pulses euclidiens = snare
 * - BPM initial = 60
 * - Tap tempo actif pour ajuster ce BPM
 */
public class MainActivity extends AppCompatActivity {

    private static final int STEPS  = 16;  // points bleus
    private static final int PULSES = 5;   // pulses euclidiens oranges

    private static final double STEPS_PER_BEAT = 1.0;  // 1 bleu = 1 beat
    private static final double DEFAULT_BPM = 60.0;

    private static final double MIN_BPM = 40.0;
    private static final double MAX_BPM = 260.0;

    private RhythmCircleView circleView;
    private SoundEngine soundEngine;

    private boolean[] pattern;    // motif euclidien
    private double secondsPerStep;
    private double currentBpm = DEFAULT_BPM;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private int currentStep = 0;

    private final List<Long> tapTimes = new ArrayList<>();
    private static final int MAX_TAPS_MEMORY = 8;
    private static final long MAX_INTERVAL_MS = 2000;

    private final Runnable tickRunnable = new Runnable() {
        @Override public void run() {
            // avancer dans les steps
            currentStep = (currentStep + 1) % STEPS;
            circleView.setCurrentStep(currentStep);

            // BLEU = toujours un kick
            soundEngine.playStep();

            // ORANGE = snare si motif euclidien dit true
            if (pattern[currentStep]) {
                soundEngine.playPulse();
            }

            long delayMs = (long) Math.round(secondsPerStep * 1000.0);
            handler.postDelayed(this, delayMs);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        circleView = new RhythmCircleView(this, null);
        setContentView(circleView);

        // BPM initial
        applyBpm(DEFAULT_BPM);

        // motif E(16,5)
        pattern = makeEuclideanPattern(STEPS, PULSES);

        // envoyer l'information au cercle (pour dessiner aussi les pulses oranges)
        circleView.updatePattern(pattern, STEPS, secondsPerStep);

        // KICK + SNARE
        soundEngine = new SoundEngine(
                44_100,
                SoundEngine.Waveform.KICK, 80.0, 160, 2, 140,
                SoundEngine.Waveform.SNARE, 200.0, 140, 2, 120
        );

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
    }

    @Override protected void onResume() { super.onResume(); startLoop(); }
    @Override protected void onPause()  { super.onPause();  stopLoop();  }
    @Override protected void onDestroy(){ super.onDestroy(); stopLoop(); soundEngine.release(); }

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
        secondsPerStep = 60.0 / currentBpm; // 1 bleu = 1 battement
        circleView.setBpm(currentBpm);
        stopLoop();
        startLoop();
    }

    // --- Algorithme d'Euclide E(steps, pulses) ---
    private static boolean[] makeEuclideanPattern(int steps, int pulses) {
        boolean[] pattern = new boolean[steps];
        if (pulses <= 0) return pattern;

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

echo "✔️ EuclideanBeats (16 bleus, 5 oranges, BPM=60) mis à jour."
