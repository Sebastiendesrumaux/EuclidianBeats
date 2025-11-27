#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour de RhythmCircleView (points activables)…"

cat > app/src/main/java/com/example/appdummy/RhythmCircleView.java << 'JAVAEOF'
package com.example.appdummy;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.view.View;

import java.util.Arrays;

/**
 * Vue circulaire :
 * - steps bleus (kick)
 * - pulses oranges (snare)
 * - pulses verts (hat open)
 * - pulses roses (hat closed)
 * - chaque point peut être actif/inactif (entouré d’un cercle quand actif)
 * - fournit shouldPlay* et togglePointAt(x,y)
 */
public class RhythmCircleView extends View {

    private int steps = 16;
    private double secondsPerStep = 0.5;

    private boolean[] patternOrange = null;
    private boolean[] patternGreen  = null;
    private boolean[] patternPink   = null;

    // états actifs/inactifs
    private boolean[] activeBlue   = null;
    private boolean[] activeOrange = null;
    private boolean[] activeGreen  = null;
    private boolean[] activePink   = null;

    private float angleStep;

    private final Paint stepPaint    = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint orangePaint  = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint greenPaint   = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pinkPaint    = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint handPaint    = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textPaint    = new Paint(Paint.ANTI_ALIAS_FLAG);

    private final Paint outlineBlue   = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint outlineOrange = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint outlineGreen  = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint outlinePink   = new Paint(Paint.ANTI_ALIAS_FLAG);

    private int currentStep = 0;
    private double currentBpm = 0.0;

    public RhythmCircleView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    private void init() {
        stepPaint.setColor(Color.parseColor("#00BCD4"));
        stepPaint.setStyle(Paint.Style.FILL);

        orangePaint.setColor(Color.parseColor("#FFC107"));
        orangePaint.setStyle(Paint.Style.FILL);

        greenPaint.setColor(Color.parseColor("#8BC34A"));
        greenPaint.setStyle(Paint.Style.FILL);

        pinkPaint.setColor(Color.parseColor("#E91E63"));
        pinkPaint.setStyle(Paint.Style.FILL);

        handPaint.setColor(Color.WHITE);
        handPaint.setStrokeWidth(6f);

        textPaint.setColor(Color.RED);
        textPaint.setTextAlign(Paint.Align.CENTER);
        textPaint.setTextSize(80f);

        outlineBlue.setColor(Color.WHITE);
        outlineBlue.setStyle(Paint.Style.STROKE);
        outlineBlue.setStrokeWidth(3f);

        outlineOrange.setColor(Color.WHITE);
        outlineOrange.setStyle(Paint.Style.STROKE);
        outlineOrange.setStrokeWidth(3f);

        outlineGreen.setColor(Color.WHITE);
        outlineGreen.setStyle(Paint.Style.STROKE);
        outlineGreen.setStrokeWidth(3f);

        outlinePink.setColor(Color.WHITE);
        outlinePink.setStyle(Paint.Style.STROKE);
        outlinePink.setStrokeWidth(3f);

        recalc();
    }

    private void recalc() {
        angleStep = 360f / Math.max(1, (float) steps);
        ensureActiveArrays();
        invalidate();
    }

    private void ensureActiveArrays() {
        if (activeBlue == null || activeBlue.length != steps) {
            activeBlue = new boolean[steps];
            Arrays.fill(activeBlue, true);
        }
        if (activeOrange == null || activeOrange.length != steps) {
            activeOrange = new boolean[steps];
            Arrays.fill(activeOrange, true);
        }
        if (activeGreen == null || activeGreen.length != steps) {
            activeGreen = new boolean[steps];
            Arrays.fill(activeGreen, true);
        }
        if (activePink == null || activePink.length != steps) {
            activePink = new boolean[steps];
            Arrays.fill(activePink, true);
        }
    }

    public void reactivateAll() {
        if (activeBlue   != null) Arrays.fill(activeBlue,   true);
        if (activeOrange != null) Arrays.fill(activeOrange, true);
        if (activeGreen  != null) Arrays.fill(activeGreen,  true);
        if (activePink   != null) Arrays.fill(activePink,   true);
        invalidate();
    }

    // API appelées depuis l'activité

    public void setCurrentStep(int s) {
        currentStep = ((s % Math.max(1, steps)) + steps) % steps;
        invalidate();
    }

    public void setBpm(double bpm) {
        currentBpm = bpm;
        invalidate();
    }

    public void updatePatterns(boolean[] orange, boolean[] green, boolean[] pink,
                               int steps, double secondsPerStep) {
        this.steps = Math.max(1, steps);
        this.secondsPerStep = Math.max(1e-6, secondsPerStep);

        this.patternOrange = (orange != null) ? orange.clone() : null;
        this.patternGreen  = (green  != null) ? green.clone()  : null;
        this.patternPink   = (pink   != null) ? pink.clone()   : null;

        activeBlue = activeOrange = activeGreen = activePink = null;
        recalc();
    }

    // Logiciels de décision pour le son

    public boolean shouldPlayKick(int step) {
        if (activeBlue == null) return true;
        if (step < 0 || step >= activeBlue.length) return false;
        return activeBlue[step];
    }

    public boolean shouldPlaySnare(int step) {
        if (patternOrange == null || activeOrange == null) return false;
        if (step < 0 || step >= patternOrange.length || step >= activeOrange.length) return false;
        return patternOrange[step] && activeOrange[step];
    }

    public boolean shouldPlayHatOpen(int step) {
        if (patternGreen == null || activeGreen == null) return false;
        if (step < 0 || step >= patternGreen.length || step >= activeGreen.length) return false;
        return patternGreen[step] && activeGreen[step];
    }

    public boolean shouldPlayHatClosed(int step) {
        if (patternPink == null || activePink == null) return false;
        if (step < 0 || step >= patternPink.length || step >= activePink.length) return false;
        return patternPink[step] && activePink[step];
    }

    /**
     * Toggle du point le plus proche d'un tap (si dans la couronne d'un anneau).
     * Retourne true si un point a été effectivement togglé.
     */
    public boolean togglePointAt(float xTouch, float yTouch) {
        int w = getWidth();
        int h = getHeight();
        if (w <= 0 || h <= 0) return false;

        float cx = w / 2f;
        float cy = h / 2f;
        float r  = Math.min(w, h) * 0.4f;

        float dx = xTouch - cx;
        float dy = yTouch - cy;
        float dist = (float) Math.sqrt(dx * dx + dy * dy);

        float rBlue   = r;
        float rOrange = r * 0.85f;
        float rGreen  = r * 0.7f;
        float rPink   = r * 0.55f;

        float tol = r * 0.12f;

        float dBlue   = Math.abs(dist - rBlue);
        float dOrange = Math.abs(dist - rOrange);
        float dGreen  = Math.abs(dist - rGreen);
        float dPink   = Math.abs(dist - rPink);

        if (dBlue > tol && dOrange > tol && dGreen > tol && dPink > tol) {
            return false;
        }

        float angleDeg = (float) Math.toDegrees(Math.atan2(dy, dx)) + 90f;
        if (angleDeg < 0f) angleDeg += 360f;
        int index = Math.round(angleDeg / angleStep) % steps;

        ensureActiveArrays();

        int ring = 0;
        float minD = dBlue;
        if (dOrange < minD) { minD = dOrange; ring = 1; }
        if (dGreen  < minD) { minD = dGreen;  ring = 2; }
        if (dPink   < minD) { minD = dPink;   ring = 3; }

        switch (ring) {
            case 0:
                activeBlue[index] = !activeBlue[index];
                invalidate();
                return true;
            case 1:
                if (patternOrange != null &&
                    index < patternOrange.length &&
                    patternOrange[index]) {
                    activeOrange[index] = !activeOrange[index];
                    invalidate();
                    return true;
                }
                return false;
            case 2:
                if (patternGreen != null &&
                    index < patternGreen.length &&
                    patternGreen[index]) {
                    activeGreen[index] = !activeGreen[index];
                    invalidate();
                    return true;
                }
                return false;
            case 3:
                if (patternPink != null &&
                    index < patternPink.length &&
                    patternPink[index]) {
                    activePink[index] = !activePink[index];
                    invalidate();
                    return true;
                }
                return false;
            default:
                return false;
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        canvas.drawColor(Color.BLACK);

        int w = getWidth();
        int h = getHeight();
        float cx = w / 2f;
        float cy = h / 2f;
        float r  = Math.min(w, h) * 0.4f;

        ensureActiveArrays();

        float rBlue   = r;
        float rOrange = r * 0.85f;
        float rGreen  = r * 0.7f;
        float rPink   = r * 0.55f;

        float baseBlueRadius   = 9f;
        float baseOrangeRadius = 6f;
        float baseGreenRadius  = 5f;
        float basePinkRadius   = 5f;
        float outlineDelta     = 4f;

        // steps bleus
        for (int i = 0; i < steps; i++) {
            double rad = Math.toRadians(i * angleStep - 90);
            float x = (float) (cx + rBlue * Math.cos(rad));
            float y = (float) (cy + rBlue * Math.sin(rad));
            canvas.drawCircle(x, y, baseBlueRadius, stepPaint);
            if (activeBlue[i]) {
                canvas.drawCircle(x, y, baseBlueRadius + outlineDelta, outlineBlue);
            }
        }

        // orange
        if (patternOrange != null) {
            for (int i = 0; i < steps && i < patternOrange.length; i++) {
                if (!patternOrange[i]) continue;
                double rad = Math.toRadians(i * angleStep - 90);
                float x = (float) (cx + rOrange * Math.cos(rad));
                float y = (float) (cy + rOrange * Math.sin(rad));
                canvas.drawCircle(x, y, baseOrangeRadius, orangePaint);
                if (activeOrange != null && activeOrange[i]) {
                    canvas.drawCircle(x, y, baseOrangeRadius + outlineDelta, outlineOrange);
                }
            }
        }

        // vert
        if (patternGreen != null) {
            for (int i = 0; i < steps && i < patternGreen.length; i++) {
                if (!patternGreen[i]) continue;
                double rad = Math.toRadians(i * angleStep - 90);
                float x = (float) (cx + rGreen * Math.cos(rad));
                float y = (float) (cy + rGreen * Math.sin(rad));
                canvas.drawCircle(x, y, baseGreenRadius, greenPaint);
                if (activeGreen != null && activeGreen[i]) {
                    canvas.drawCircle(x, y, baseGreenRadius + outlineDelta, outlineGreen);
                }
            }
        }

        // rose
        if (patternPink != null) {
            for (int i = 0; i < steps && i < patternPink.length; i++) {
                if (!patternPink[i]) continue;
                double rad = Math.toRadians(i * angleStep - 90);
                float x = (float) (cx + rPink * Math.cos(rad));
                float y = (float) (cy + rPink * Math.sin(rad));
                canvas.drawCircle(x, y, basePinkRadius, pinkPaint);
                if (activePink != null && activePink[i]) {
                    canvas.drawCircle(x, y, basePinkRadius + outlineDelta, outlinePink);
                }
            }
        }

        // aiguille
        double rad = Math.toRadians(currentStep * angleStep - 90);
        float hx = (float) (cx + rBlue * Math.cos(rad));
        float hy = (float) (cy + rBlue * Math.sin(rad));
        canvas.drawLine(cx, cy, hx, hy, handPaint);

        // BPM
        if (currentBpm > 0.0) {
            String txt = String.format("%d BPM", Math.round(currentBpm));
            Paint.FontMetrics fm = textPaint.getFontMetrics();
            float textY = cy - (fm.ascent + fm.descent) / 2f;
            canvas.drawText(txt, cx, textY, textPaint);
        }
    }
}
JAVAEOF

echo "✅ RhythmCircleView mis à jour."
