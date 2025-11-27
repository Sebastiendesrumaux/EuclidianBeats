#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Réécriture de RhythmCircleView pour aligner les points oranges sur le motif euclidien…"

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
 * Vue circulaire rythmique :
 * - 16 steps bleus (tempo)
 * - pulses oranges dessinés là où pattern[i] == true (motif euclidien)
 * - BPM affiché en rouge au centre
 */
public class RhythmCircleView extends View {

    private int steps = 16;
    private int pulses = 0;               // info indicative, mais le dessin suit pattern[]
    private double secondsPerStep = 0.5;
    private boolean[] pattern = null;

    private float angleStep;

    private final Paint stepPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pulsePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint handPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint tapPaint  = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private int currentStep = 0;
    private double currentBpm = 0.0;

    // taps (pas vraiment utilisés pour l’instant mais conservés)
    private final List<Float> tapSteps  = new ArrayList<>();
    private final List<Float> tapPulses = new ArrayList<>();

    public RhythmCircleView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    private void init() {
        // couleurs pour fond noir
        stepPaint.setColor(Color.parseColor("#00BCD4"));  // bleu/turquoise
        stepPaint.setStyle(Paint.Style.FILL);

        pulsePaint.setColor(Color.parseColor("#FFC107")); // orange/ambre
        pulsePaint.setStyle(Paint.Style.FILL);

        tapPaint.setColor(Color.parseColor("#FF4081"));   // rose
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

    /**
     * Met à jour le motif logique + paramètres temporels.
     * On en profite pour mettre à jour pulses = nombre de true.
     */
    public void updatePattern(boolean[] pattern, int steps, double secondsPerStep) {
        this.pattern = (pattern != null) ? pattern.clone() : null;
        this.steps = Math.max(1, steps);
        this.secondsPerStep = Math.max(1e-6, secondsPerStep);

        // compter les pulses à partir du pattern
        int count = 0;
        if (this.pattern != null) {
            for (int i = 0; i < this.pattern.length; i++) {
                if (this.pattern[i]) count++;
            }
        }
        this.pulses = count;

        recalc();
    }

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

        // fond noir
        canvas.drawColor(Color.BLACK);

        int w = getWidth();
        int h = getHeight();
        float cx = w / 2f;
        float cy = h / 2f;
        float r  = Math.min(w, h) * 0.4f;

        // --- anneau des steps (bleus) ---
        for (int i = 0; i < steps; i++) {
            double rad = Math.toRadians(i * angleStep - 90);
            float x = (float) (cx + r * Math.cos(rad));
            float y = (float) (cy + r * Math.sin(rad));
            canvas.drawCircle(x, y, 9, stepPaint);
        }

        // --- anneau des pulses oranges, alignés sur le motif euclidien ---
        if (pattern != null) {
            for (int i = 0; i < steps && i < pattern.length; i++) {
                if (!pattern[i]) continue; // on ne dessine un point orange que si le motif dit true
                double rad = Math.toRadians(i * angleStep - 90);
                float x = (float) (cx + r * 0.8f * Math.cos(rad));
                float y = (float) (cy + r * 0.8f * Math.sin(rad));
                canvas.drawCircle(x, y, 6, pulsePaint);
            }
        }

        // taps (conservés mais secondaires visuellement)
        for (float a : tapSteps) {
            double rad = Math.toRadians(a - 90);
            float x = (float) (cx + r * Math.cos(rad));
            float y = (float) (cy + r * Math.sin(rad));
            canvas.drawCircle(x, y, 14, tapPaint);
        }

        for (float a : tapPulses) {
            double rad = Math.toRadians(a - 90);
            float x = (float) (cx + r * 0.8f * Math.cos(rad));
            float y = (float) (cy + r * 0.8f * Math.sin(rad));
            canvas.drawCircle(x, y, 10, tapPaint);
        }

        // aiguille sur le step courant
        double rad = Math.toRadians(currentStep * angleStep - 90);
        float hx = (float) (cx + r * Math.cos(rad));
        float hy = (float) (cy + r * Math.sin(rad));
        canvas.drawLine(cx, cy, hx, hy, handPaint);

        // BPM au centre
        if (currentBpm > 0.0) {
            String txt = String.format("%d BPM", Math.round(currentBpm));
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

echo "✅ RhythmCircleView mis à jour (pulses oranges euclidiens alignés sur les steps)."
