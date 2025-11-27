#!/data/data/com.termux/files/usr/bin/bash
set -e

TARGET="app/src/main/java/com/example/appdummy/MainActivity.java"

echo "▶️ Écriture de $TARGET (version EuclidianBeats)…"

cat > "$TARGET" << 'JAVAEOF'
package com.example.appdummy;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.appcompat.app.AppCompatActivity;

/**
 * MainActivity "EuclidianBeats" :
 * - Affiche un RhythmCircleView plein écran
 * - Génère un motif euclidien (steps / pulses)
 * - Fait tourner une aiguille
 * - Joue un son à chaque step (pulse ou non)
 */
public class MainActivity extends AppCompatActivity {

    // --- paramètres du motif ---
    private static final int STEPS  = 16;   // divisions du cercle
    private static final int PULSES = 12;   // coups "actifs"
    private static final double BPM = 120.0;

    // on suppose 4 steps par temps → 16 steps = 1 mesure en 4/4
    private static final double STEPS_PER_BEAT = 4.0;

    private RhythmCircleView circleView;
    private SoundEngine soundEngine;

    private boolean[] pattern;
    private double secondsPerStep;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private int currentStep = 0;

    private final Runnable tickRunnable = new Runnable() {
        @Override public void run() {
            // avancer d'un step
            currentStep = (currentStep + 1) % STEPS;
            circleView.setCurrentStep(currentStep);

            // jouer le son correspondant
            if (pattern != null && currentStep < pattern.length && pattern[currentStep]) {
                // step "actif" (pulse)
                soundEngine.playPulse();
            } else {
                // step "passif"
                soundEngine.playStep();
            }

            // reprogrammer le tick suivant
            long delayMs = (long) Math.round(secondsPerStep * 1000.0);
            handler.postDelayed(this, delayMs);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.i("EuclidianBeats", "onCreate()");

        // 1) Créer la vue rythmique en plein écran
        circleView = new RhythmCircleView(this, null);
        setContentView(circleView);

        // 2) Calculer la durée d'un step à partir du BPM
        //    BPM = battements par minute
        //    1 beat = 60 / BPM secondes
        //    1 step = (1 / STEPS_PER_BEAT) beat
        secondsPerStep = (60.0 / BPM) / STEPS_PER_BEAT;

        // 3) Générer un motif euclidien simple
        pattern = makeEuclideanPattern(STEPS, PULSES);

        // informer la vue
        circleView.updatePattern(pattern, STEPS, secondsPerStep);

        // 4) Préparer le moteur sonore
        soundEngine = new SoundEngine(
                44_100,
                // STEP : timbre discret
                SoundEngine.Waveform.CLICK, 2000.0, 40, 2, 20,
                // PULSE : timbre plus chantant
                SoundEngine.Waveform.SINE, 880.0, 80, 5, 40
        );
    }

    @Override
    protected void onResume() {
        super.onResume();
        Log.i("EuclidianBeats", "onResume()");
        startLoop();
    }

    @Override
    protected void onPause() {
        super.onPause();
        Log.i("EuclidianBeats", "onPause()");
        stopLoop();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        Log.i("EuclidianBeats", "onDestroy()");
        stopLoop();
        if (soundEngine != null) {
            soundEngine.release();
        }
    }

    // --- gestion de la boucle de ticks ---

    private void startLoop() {
        handler.removeCallbacks(tickRunnable);
        currentStep = -1; // pour que le premier tick mette à 0
        long delayMs = (long) Math.round(secondsPerStep * 1000.0);
        handler.postDelayed(tickRunnable, delayMs);
    }

    private void stopLoop() {
        handler.removeCallbacks(tickRunnable);
    }

    // --- génération d'un motif euclidien simple ---
    //
    // On remplit un tableau de "steps" avec PULSES true
    // répartis aussi régulièrement que possible sur STEPS.
    //
    private static boolean[] makeEuclideanPattern(int steps, int pulses) {
        if (steps < 1) steps = 1;
        if (pulses < 0) pulses = 0;
        if (pulses > steps) pulses = steps;

        boolean[] pat = new boolean[steps];
        if (pulses == 0) return pat;

        for (int i = 0; i < pulses; i++) {
            // distribution régulière par floor(i * steps / pulses)
            int idx = (int) Math.floor(i * (steps / (double) pulses));
            if (idx < 0) idx = 0;
            if (idx >= steps) idx = steps - 1;
            pat[idx] = true;
        }
        return pat;
    }
}
JAVAEOF

echo "✅ MainActivity mise à jour pour EuclidianBeats."
