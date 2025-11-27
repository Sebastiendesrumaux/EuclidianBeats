#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour de MainActivity (tap tempo)…"

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
 * MainActivity "EuclidianBeats" :
 * - Affiche un RhythmCircleView plein écran
 * - Génère un motif euclidien (steps / pulses)
 * - Fait tourner une aiguille
 * - Joue un son à chaque step (pulse ou non)
 * - Permet de régler le BPM en tapant sur l'écran (tap tempo)
 */
public class MainActivity extends AppCompatActivity {

    // --- paramètres du motif ---
    private static final int STEPS  = 16;   // divisions du cercle
    private static final int PULSES = 12;   // coups "actifs"
    private static final double STEPS_PER_BEAT = 4.0; // 4 steps par temps
    private static final double DEFAULT_BPM = 120.0;

    // bornes du BPM détecté
    private static final double MIN_BPM = 40.0;
    private static final double MAX_BPM = 260.0;

    private RhythmCircleView circleView;
    private SoundEngine soundEngine;

    private boolean[] pattern;
    private double secondsPerStep;
    private double currentBpm = DEFAULT_BPM;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private int currentStep = 0;

    // mémorisation des derniers taps pour calculer un BPM moyen
    private final List<Long> tapTimes = new ArrayList<>();
    private static final int MAX_TAPS_MEMORY = 8;      // on garde au plus 8 taps
    private static final long MAX_INTERVAL_MS = 2000;  // au-delà, on considère que le tempo est cassé

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

        // 2) BPM initial
        applyBpm(DEFAULT_BPM);

        // 3) Générer un motif euclidien simple
        pattern = makeEuclideanPattern(STEPS, PULSES);
        circleView.updatePattern(pattern, STEPS, secondsPerStep);

        // 4) Préparer le moteur sonore
        soundEngine = new SoundEngine(
                44_100,
                // STEP : timbre discret
                SoundEngine.Waveform.CLICK, 2000.0, 40, 2, 20,
                // PULSE : timbre plus chantant
                SoundEngine.Waveform.SINE, 880.0, 80, 5, 40
        );

        // 5) Tap tempo : on intercepte les taps sur toute la vue
        circleView.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                if (event.getAction() == MotionEvent.ACTION_DOWN) {
                    handleTapTempo(event.getEventTime());
                    return true; // on consomme l'évènement
                }
                return false;
            }
        });
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

    // --- TAP TEMPO ---

    private void handleTapTempo(long tapTimeMs) {
        // si le dernier tap est trop ancien, on repart de zéro
        if (!tapTimes.isEmpty()) {
            long last = tapTimes.get(tapTimes.size() - 1);
            if (tapTimeMs - last > MAX_INTERVAL_MS) {
                tapTimes.clear();
            }
        }

        tapTimes.add(tapTimeMs);
        // on garde au plus MAX_TAPS_MEMORY taps
        while (tapTimes.size() > MAX_TAPS_MEMORY) {
            tapTimes.remove(0);
        }

        if (tapTimes.size() < 2) {
            return; // pas encore assez d'info
        }

        // calcul des intervalles successifs
        double sumIntervals = 0.0;
        int count = 0;
        for (int i = 1; i < tapTimes.size(); i++) {
            long dt = tapTimes.get(i) - tapTimes.get(i - 1);
            if (dt <= 0 || dt > MAX_INTERVAL_MS) {
                continue;
            }
            sumIntervals += dt;
            count++;
        }

        if (count == 0) return;

        double avgIntervalMs = sumIntervals / count;
        double bpm = 60000.0 / avgIntervalMs;

        if (bpm < MIN_BPM || bpm > MAX_BPM) {
            return; // valeur aberrante, on ignore
        }

        applyBpm(bpm);
    }

    private void applyBpm(double bpm) {
        currentBpm = bpm;
        // 1 beat = 60 / bpm secondes
        // 1 step = (1 / STEPS_PER_BEAT) beat
        secondsPerStep = (60.0 / currentBpm) / STEPS_PER_BEAT;

        circleView.setBpm(currentBpm);

        // si la boucle tourne déjà, on la recale
        stopLoop();
        startLoop();
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

echo "▶️ Mise à jour de RhythmCircleView (fond noir + BPM rouge)…"

cat > app/src/main/java/com/example/appdummy/RhythmCircleView.java << 'JAVAEOF'
package com.example.appdummy;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.view.View;

import java.util.ArrayList;
import java.util.List;

/**
 * Vue circulaire rythmique — fournit les méthodes utilisées par MainActivity:
 * - updatePattern(boolean[] pattern, int steps, double secondsPerStep)
 * - updateTaps(List<Double> stepsTaps, List<Double> pulsesTaps)
 * - setBpm(double bpm) pour afficher le BPM courant en rouge au centre.
 */
public class RhythmCircleView extends View {

    private int steps = 16;
    private int pulses = 12;
    private double secondsPerStep = 0.5; // par défaut
    private boolean[] pattern = null;

    private float angleStep;

    private final Paint stepPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pulsePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint handPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint tapPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private int currentStep = 0;

    // BPM courant pour affichage
    private double currentBpm = 0.0;

    // on stocke les taps en degrés [0..360)
    private final List<Float> tapSteps = new ArrayList<>();
    private final List<Float> tapPulses = new ArrayList<>();

    public RhythmCircleView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    private void init() {
        // couleurs pensées pour un fond NOIR
        stepPaint.setColor(Color.parseColor("#00BCD4"));  // turquoise
        stepPaint.setStyle(Paint.Style.FILL);

        pulsePaint.setColor(Color.parseColor("#FFC107")); // ambre
        pulsePaint.setStyle(Paint.Style.FILL);

        tapPaint.setColor(Color.parseColor("#FF4081"));   // rose vif
        tapPaint.setStyle(Paint.Style.STROKE);
        tapPaint.setStrokeWidth(4f);

        handPaint.setColor(Color.WHITE);
        handPaint.setStrokeWidth(6f);

        textPaint.setColor(Color.RED);
        textPaint.setTextAlign(Paint.Align.CENTER);
        textPaint.setTextSize(80f);

        recalc();
    }

    private void recalc() {
        angleStep = 360f / Math.max(1, (float) steps);
        invalidate();
    }

    // --- API utilitaire ---
    public void setSteps(int s) {
        steps = Math.max(1, s);
        recalc();
    }

    public void setPulses(int p) {
        pulses = Math.max(0, p);
        invalidate();
    }

    public void setCurrentStep(int s) {
        currentStep = ((s % Math.max(1, steps)) + steps) % steps;
        invalidate();
    }

    public void addTapStep(float angleDeg) {
        tapSteps.add(norm(angleDeg));
        invalidate();
    }

    public void addTapPulse(float angleDeg) {
        tapPulses.add(norm(angleDeg));
        invalidate();
    }

    public void clearTaps() {
        tapSteps.clear();
        tapPulses.clear();
        invalidate();
    }

    public void setBpm(double bpm) {
        this.currentBpm = bpm;
        invalidate();
    }

    // --- Méthodes attendues par MainActivity ---

    /**
     * Met à jour le motif logique + paramètres temporels.
     */
    public void updatePattern(boolean[] pattern, int steps, double secondsPerStep) {
        this.pattern = (pattern != null) ? pattern.clone() : null;
        this.steps = Math.max(1, steps);
        this.secondsPerStep = Math.max(1e-6, secondsPerStep);
        recalc();
    }

    /**
     * Met à jour la mémoire des taps (steps/pulses) à partir de List<Double>.
     * (pas encore utilisée ici, mais disponible)
     */
    public void updateTaps(List<Double> stepsTaps, List<Double> pulsesTaps) {
        tapSteps.clear();
        tapPulses.clear();
        if (stepsTaps != null) {
            for (Double d : stepsTaps) if (d != null) tapSteps.add(norm(d.floatValue()));
        }
        if (pulsesTaps != null) {
            for (Double d : pulsesTaps) if (d != null) tapPulses.add(norm(d.floatValue()));
        }
        invalidate();
    }

    // --- Dessin ---
    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        // FOND NOIR
        canvas.drawColor(Color.BLACK);

        int w = getWidth();
        int h = getHeight();
        float cx = w / 2f;
        float cy = h / 2f;
        float r  = Math.min(w, h) * 0.4f;

        // anneau des steps
        for (int i = 0; i < steps; i++) {
            double rad = Math.toRadians(i * angleStep - 90);
            float x = (float) (cx + r * Math.cos(rad));
            float y = (float) (cy + r * Math.sin(rad));
            canvas.drawCircle(x, y, (pattern != null && i < pattern.length && pattern[i]) ? 12 : 9, stepPaint);
        }

        // anneau des pulses
        final int p = Math.max(1, pulses);
        for (int i = 0; i < pulses; i++) {
            double rad = Math.toRadians(i * (360f / p) - 90);
            float x = (float) (cx + r * 0.8f * Math.cos(rad));
            float y = (float) (cy + r * 0.8f * Math.sin(rad));
            canvas.drawCircle(x, y, 6, pulsePaint);
        }

        // taps steps (sur grand rayon)
        for (float a : tapSteps) {
            double rad = Math.toRadians(a - 90);
            float x = (float) (cx + r * Math.cos(rad));
            float y = (float) (cy + r * Math.sin(rad));
            canvas.drawCircle(x, y, 14, tapPaint);
        }

        // taps pulses (sur rayon 0.8)
        for (float a : tapPulses) {
            double rad = Math.toRadians(a - 90);
            float x = (float) (cx + r * 0.8f * Math.cos(rad));
            float y = (float) (cy + r * 0.8f * Math.sin(rad));
            canvas.drawCircle(x, y, 10, tapPaint);
        }

        // aiguille (positionnée sur currentStep)
        double rad = Math.toRadians(currentStep * angleStep - 90);
        float hx = (float) (cx + r * Math.cos(rad));
        float hy = (float) (cy + r * Math.sin(rad));
        canvas.drawLine(cx, cy, hx, hy, handPaint);

        // BPM au centre, en rouge
        if (currentBpm > 0.0) {
            String txt = String.format("%d BPM", Math.round(currentBpm));
            // aligné verticalement à peu près au centre
            Paint.FontMetrics fm = textPaint.getFontMetrics();
            float textY = cy - (fm.ascent + fm.descent) / 2f;
            canvas.drawText(txt, cx, textY, textPaint);
        }
    }

    // --- util ---
    private float norm(float deg) {
        float a = deg % 360f;
        if (a < 0f) a += 360f;
        return a;
    }
}
JAVAEOF

echo "✅ MainActivity + RhythmCircleView mis à jour pour tap tempo."
