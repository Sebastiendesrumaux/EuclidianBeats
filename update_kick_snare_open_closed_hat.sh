#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour : SoundEngine + RhythmCircleView + MainActivity (closed hat rose ajouté)"

########################################
# SoundEngine : KICK + SNARE + HAT (vert) + CLOSED HAT (rose)
########################################
cat > app/src/main/java/com/example/appdummy/SoundEngine.java << 'JAVAEOF'
package com.example.appdummy;

import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;

public class SoundEngine {

    public enum Waveform { SINE, SQUARE, TRIANGLE, CLICK, NOISE, SNARE, KICK, HAT_OPEN, HAT_CLOSED }

    private final int sampleRate;
    private final AudioTrack kickTrack;
    private final AudioTrack snareTrack;
    private final AudioTrack hatOpenTrack;
    private final AudioTrack hatClosedTrack;

    public SoundEngine(int sampleRateHz) {
        this.sampleRate = sampleRateHz;

        short[] kickBuf       = synthBuffer(Waveform.KICK,       80.0,   180,  2, 150);
        short[] snareBuf      = synthBuffer(Waveform.SNARE,    2000.0,   140,  1, 120);
        short[] hatOpenBuf    = synthBuffer(Waveform.HAT_OPEN,  8000.0,  120,  1, 100);
        short[] hatClosedBuf  = synthBuffer(Waveform.HAT_CLOSED,8000.0,   60,  1,  40);

        kickTrack      = makeStaticTrack(kickBuf);
        snareTrack     = makeStaticTrack(snareBuf);
        hatOpenTrack   = makeStaticTrack(hatOpenBuf);
        hatClosedTrack = makeStaticTrack(hatClosedBuf);
    }

    public void playKick()       { playOnce(kickTrack);      }
    public void playSnare()      { playOnce(snareTrack);     }
    public void playHatOpen()    { playOnce(hatOpenTrack);   }
    public void playHatClosed()  { playOnce(hatClosedTrack); }

    public void release() {
        try { kickTrack.release();      } catch (Throwable ignored) {}
        try { snareTrack.release();     } catch (Throwable ignored) {}
        try { hatOpenTrack.release();   } catch (Throwable ignored) {}
        try { hatClosedTrack.release(); } catch (Throwable ignored) {}
    }

    private AudioTrack makeStaticTrack(short[] pcm) {
        int bufferBytes = pcm.length * 2;

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
                    int clickLen = Math.max(1, (int) Math.round(2.0 * sampleRate / 1000.0));
                    x = (i < clickLen) ? 1.0 : 0.0;
                    break;
                }
                case NOISE:
                    x = (Math.random() * 2.0 - 1.0);
                    break;
                case SNARE: {
                    double noise = (Math.random() * 2.0 - 1.0);
                    double tone  = Math.sin(twoPiF * i);
                    x = 0.8 * noise + 0.2 * tone;
                    break;
                }
                case KICK: {
                    double tone  = Math.sin(twoPiF * i);
                    double noise = (Math.random() * 2.0 - 1.0);
                    x = 0.85 * tone + 0.15 * noise;
                    break;
                }
                case HAT_OPEN: {
                    double noise = (Math.random() * 2.0 - 1.0);
                    x = noise;
                    break;
                }
                case HAT_CLOSED: {
                    double noise = (Math.random() * 2.0 - 1.0);
                    x = noise;
                    break;
                }
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

########################################
# RhythmCircleView : bleu + orange + vert + rose
########################################
cat > app/src/main/java/com/example/appdummy/RhythmCircleView.java << 'JAVAEOF'
package com.example.appdummy;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.view.View;

/**
 * Vue circulaire :
 * - steps bleus (tempo / kick)
 * - pulses oranges (snare)
 * - pulses verts (hi-hat ouvert)
 * - pulses roses (hi-hat fermé)
 * - aiguille sur le step courant
 * - BPM rouge au centre
 */
public class RhythmCircleView extends View {

    private int steps = 16;
    private double secondsPerStep = 0.5;

    private boolean[] patternOrange = null;
    private boolean[] patternGreen  = null;
    private boolean[] patternPink   = null;

    private float angleStep;

    private final Paint stepPaint    = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint orangePaint  = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint greenPaint   = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pinkPaint    = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint handPaint    = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textPaint    = new Paint(Paint.ANTI_ALIAS_FLAG);

    private int currentStep = 0;
    private double currentBpm = 0.0;

    public RhythmCircleView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    private void init() {
        stepPaint.setColor(Color.parseColor("#00BCD4"));   // bleu/turquoise
        stepPaint.setStyle(Paint.Style.FILL);

        orangePaint.setColor(Color.parseColor("#FFC107")); // orange/ambre
        orangePaint.setStyle(Paint.Style.FILL);

        greenPaint.setColor(Color.parseColor("#8BC34A"));  // vert
        greenPaint.setStyle(Paint.Style.FILL);

        pinkPaint.setColor(Color.parseColor("#E91E63"));   // rose
        pinkPaint.setStyle(Paint.Style.FILL);

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

    // --- API ---

    public void setCurrentStep(int s) {
        currentStep = ((s % Math.max(1, steps)) + steps) % steps;
        invalidate();
    }

    public void setBpm(double bpm) {
        this.currentBpm = bpm;
        invalidate();
    }

    public void updatePatterns(boolean[] orange, boolean[] green, boolean[] pink,
                               int steps, double secondsPerStep) {
        this.steps = Math.max(1, steps);
        this.secondsPerStep = Math.max(1e-6, secondsPerStep);
        this.patternOrange = (orange != null) ? orange.clone() : null;
        this.patternGreen  = (green  != null) ? green.clone()  : null;
        this.patternPink   = (pink   != null) ? pink.clone()   : null;
        recalc();
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

        // steps bleus
        for (int i = 0; i < steps; i++) {
            double rad = Math.toRadians(i * angleStep - 90);
            float x = (float) (cx + r * Math.cos(rad));
            float y = (float) (cy + r * Math.sin(rad));
            canvas.drawCircle(x, y, 9, stepPaint);
        }

        // anneau orange (snare) à 0.85 r
        if (patternOrange != null) {
            for (int i = 0; i < steps && i < patternOrange.length; i++) {
                if (!patternOrange[i]) continue;
                double rad = Math.toRadians(i * angleStep - 90);
                float x = (float) (cx + r * 0.85f * Math.cos(rad));
                float y = (float) (cy + r * 0.85f * Math.sin(rad));
                canvas.drawCircle(x, y, 6, orangePaint);
            }
        }

        // anneau vert (hat ouvert) à 0.7 r
        if (patternGreen != null) {
            for (int i = 0; i < steps && i < patternGreen.length; i++) {
                if (!patternGreen[i]) continue;
                double rad = Math.toRadians(i * angleStep - 90);
                float x = (float) (cx + r * 0.7f * Math.cos(rad));
                float y = (float) (cy + r * 0.7f * Math.sin(rad));
                canvas.drawCircle(x, y, 5, greenPaint);
            }
        }

        // anneau rose (hat fermé) à 0.55 r
        if (patternPink != null) {
            for (int i = 0; i < steps && i < patternPink.length; i++) {
                if (!patternPink[i]) continue;
                double rad = Math.toRadians(i * angleStep - 90);
                float x = (float) (cx + r * 0.55f * Math.cos(rad));
                float y = (float) (cy + r * 0.55f * Math.sin(rad));
                canvas.drawCircle(x, y, 5, pinkPaint);
            }
        }

        // aiguille
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
}
JAVAEOF

########################################
# MainActivity : 4 cercles + 3 boutons
########################################
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
 * - 16 steps bleus = KICK, tempo maître
 * - pulses oranges euclidiens = SNARE
 * - pulses verts euclidiens   = HI-HAT OUVERT
 * - pulses roses euclidiens   = HI-HAT FERMÉ
 * - BPM initial = 60
 * - Tap tempo
 * - Bouton orange : random pulses oranges (0..16 sur 16 bleus)
 * - Bouton vert   : random pulses verts   (0..16 sur 16 bleus)
 * - Bouton rose   : random pulses roses  (0..16 sur 16 bleus)
 * - La boucle continue même écran éteint (onPause ne stoppe pas la loop)
 */
public class MainActivity extends AppCompatActivity {

    private static final int STEPS = 16;

    private static final int INITIAL_PULSES_ORANGE = 5;
    private static final int INITIAL_PULSES_GREEN  = 0;
    private static final int INITIAL_PULSES_PINK   = 0;

    private static final double DEFAULT_BPM = 60.0;
    private static final double MIN_BPM = 40.0;
    private static final double MAX_BPM = 260.0;

    private RhythmCircleView circleView;
    private SoundEngine soundEngine;

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
            currentStep = (currentStep + 1) % STEPS;
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

        // --- UI ---
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
                1f));

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

        root.addView(circleView);
        root.addView(orangeButton);
        root.addView(greenButton);
        root.addView(pinkButton);
        setContentView(root);

        // BPM initial
        applyBpm(DEFAULT_BPM);

        // Motifs initiaux
        patternOrange = makeEuclideanPattern(STEPS, pulsesOrange);
        patternGreen  = makeEuclideanPattern(STEPS, pulsesGreen);
        patternPink   = makeEuclideanPattern(STEPS, pulsesPink);
        circleView.updatePatterns(patternOrange, patternGreen, patternPink, STEPS, secondsPerStep);

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
        orangeButton.setText("Pulses oranges : " + pulsesOrange + " (0..16, sur 16 bleus)");
        greenButton.setText("Pulses verts : " + pulsesGreen + " (0..16, sur 16 bleus)");
        pinkButton.setText("Pulses roses : " + pulsesPink + " (0..16, sur 16 bleus)");

        // Bouton orange : random pulses oranges
        orangeButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesOrange = (int) Math.floor(Math.random() * (STEPS + 1)); // 0..16
                patternOrange = makeEuclideanPattern(STEPS, pulsesOrange);
                circleView.updatePatterns(patternOrange, patternGreen, patternPink, STEPS, secondsPerStep);
                orangeButton.setText("Pulses oranges : " + pulsesOrange + " (0..16, sur 16 bleus)");
            }
        });

        // Bouton vert : random pulses verts
        greenButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesGreen = (int) Math.floor(Math.random() * (STEPS + 1)); // 0..16
                patternGreen = makeEuclideanPattern(STEPS, pulsesGreen);
                circleView.updatePatterns(patternOrange, patternGreen, patternPink, STEPS, secondsPerStep);
                greenButton.setText("Pulses verts : " + pulsesGreen + " (0..16, sur 16 bleus)");
            }
        });

        // Bouton rose : random pulses roses
        pinkButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesPink = (int) Math.floor(Math.random() * (STEPS + 1)); // 0..16
                patternPink = makeEuclideanPattern(STEPS, pulsesPink);
                circleView.updatePatterns(patternOrange, patternGreen, patternPink, STEPS, secondsPerStep);
                pinkButton.setText("Pulses roses : " + pulsesPink + " (0..16, sur 16 bleus)");
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

echo "✅ Mise à jour terminée (closed hat rose + boutons mis à jour)."
