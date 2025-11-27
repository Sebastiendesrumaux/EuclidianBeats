#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour de RhythmCircleView (fond noir)…"

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
 * …ainsi que des setters utilitaires et le dessin.
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

    private int currentStep = 0;

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
     * Les angles sont supposés en degrés [0..360), on tolère tout et on normalise.
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
    }

    // --- util ---
    private float norm(float deg) {
        float a = deg % 360f;
        if (a < 0f) a += 360f;
        return a;
    }
}
JAVAEOF

echo "▶️ Mise à jour de SoundEngine (flux audio MEDIA)…"

cat > app/src/main/java/com/example/appdummy/SoundEngine.java << 'JAVAEOF'
package com.example.appdummy; // ← ajuste si ton package diffère

import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;

public class SoundEngine {

    public enum Waveform { SINE, SQUARE, TRIANGLE, CLICK, NOISE }

    private final int sampleRate;
    private final AudioTrack stepTrack;
    private final AudioTrack pulseTrack;

    public SoundEngine(
            int sampleRateHz,
            // STEP timbre
            Waveform stepWave, double stepFreqHz, int stepMs, int stepAttackMs, int stepDecayMs,
            // PULSE timbre
            Waveform pulseWave, double pulseFreqHz, int pulseMs, int pulseAttackMs, int pulseDecayMs
    ) {
        this.sampleRate = sampleRateHz;

        short[] stepBuf  = synthBuffer(stepWave,  stepFreqHz,  stepMs,  stepAttackMs,  stepDecayMs);
        short[] pulseBuf = synthBuffer(pulseWave, pulseFreqHz, pulseMs, pulseAttackMs, pulseDecayMs);

        stepTrack  = makeStaticTrack(stepBuf);
        pulseTrack = makeStaticTrack(pulseBuf);
    }

    public void playStep()  { playOnce(stepTrack);  }
    public void playPulse() { playOnce(pulseTrack); }

    public void release() {
        try { stepTrack.release(); } catch (Throwable ignored) {}
        try { pulseTrack.release(); } catch (Throwable ignored) {}
    }

    private AudioTrack makeStaticTrack(short[] pcm) {
        int bufferBytes = pcm.length * 2;

        // On passe en USAGE_MEDIA / CONTENT_TYPE_MUSIC pour être sur le volume "média"
        AudioAttributes attrs = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build();

        AudioFormat format = new AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build();

        AudioTrack track = new AudioTrack(
                attrs, format, bufferBytes, AudioTrack.MODE_STATIC,
                AudioManager.AUDIO_SESSION_ID_GENERATE
        );
        track.write(pcm, 0, pcm.length);
        return track;
    }

    private void playOnce(AudioTrack t) {
        try {
            if (t.getPlayState() == AudioTrack.PLAYSTATE_PLAYING) {
                t.stop();
            }
            t.setPlaybackHeadPosition(0);
            t.play();
        } catch (IllegalStateException ignored) {}
    }

    private short[] synthBuffer(Waveform wf, double freqHz, int durMs, int attackMs, int decayMs) {
        int n = (int) Math.round(durMs * sampleRate / 1000.0);
        if (n < 1) n = 1;

        double twoPiF = 2.0 * Math.PI * freqHz / sampleRate;
        short[] pcm = new short[n];

        int a = Math.max(0, Math.min(n, (int) Math.round(attackMs * sampleRate / 1000.0)));
        int d = Math.max(0, Math.min(n - a, (int) Math.round(decayMs  * sampleRate / 1000.0)));
        int releaseStart = n - d;

        for (int i = 0; i < n; i++) {
            double env;
            if (i < a) {
                env = (a == 0) ? 1.0 : (i / (double) a);
            } else if (i >= releaseStart) {
                int k = i - releaseStart;
                env = (d == 0) ? 0.0 : (1.0 - k / (double) d);
            } else {
                env = 1.0;
            }

            double x;
            switch (wf) {
                case SINE:
                    x = Math.sin(twoPiF * i);
                    break;
                case SQUARE:
                    x = Math.signum(Math.sin(twoPiF * i));
                    break;
                case TRIANGLE: {
                    double t = (i * freqHz / sampleRate) % 1.0;
                    x = 4.0 * Math.abs(t - 0.5) - 1.0;
                    break;
                }
                case CLICK: {
                    int clickLen = Math.max(1, (int) Math.round(2.0 * sampleRate / 1000.0)); // ~2 ms
                    x = (i < clickLen) ? 1.0 : 0.0;
                    break;
                }
                case NOISE:
                    x = (Math.random() * 2.0 - 1.0);
                    break;
                default:
                    x = 0.0;
            }

            double y = env * x;
            int s = (int) Math.round(y * 0.9 * Short.MAX_VALUE);
            if (s > Short.MAX_VALUE) s = Short.MAX_VALUE;
            if (s < Short.MIN_VALUE) s = Short.MIN_VALUE;
            pcm[i] = (short) s;
        }
        return pcm;
    }
}
JAVAEOF

echo "✅ Vue & son mis à jour."
