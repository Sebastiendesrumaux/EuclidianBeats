#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour de SoundEngine avec KICK + SNARE…"

cat > app/src/main/java/com/example/appdummy/SoundEngine.java << 'JAVAEOF'
package com.example.appdummy; // ← ajuste si ton package diffère

import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;

public class SoundEngine {

    public enum Waveform { SINE, SQUARE, TRIANGLE, CLICK, NOISE, SNARE, KICK }

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

        // Sur le volume "média"
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
                    // Kick simple : sinus grave + un peu de bruit
                    double tone  = Math.sin(twoPiF * i);
                    double noise = (Math.random() * 2.0 - 1.0);
                    x = 0.85 * tone + 0.15 * noise;
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

echo "▶️ Mise à jour de MainActivity pour KICK sur les bleus, SNARE sur les oranges…"

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
 * - Cercle rythmique
 * - Motif euclidien
 * - KICK sur les steps (points bleus)
 * - SNARE sur les pulses (points orange)
 * - Tap tempo (BPM au centre)
 */
public class MainActivity extends AppCompatActivity {

    private static final int STEPS  = 16;
    private static final int PULSES = 12;
    private static final double STEPS_PER_BEAT = 4.0;
    private static final double DEFAULT_BPM = 120.0;

    private static final double MIN_BPM = 40.0;
    private static final double MAX_BPM = 260.0;

    private RhythmCircleView circleView;
    private SoundEngine soundEngine;

    private boolean[] pattern;
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

            if (pattern != null && currentStep < pattern.length && pattern[currentStep]) {
                soundEngine.playPulse(); // SNARE sur pulses (oranges)
            } else {
                soundEngine.playStep();  // KICK sur steps (bleus)
            }

            long delayMs = (long) Math.round(secondsPerStep * 1000.0);
            handler.postDelayed(this, delayMs);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.i("EuclidianBeats", "onCreate()");

        circleView = new RhythmCircleView(this, null);
        setContentView(circleView);

        applyBpm(DEFAULT_BPM);

        pattern = makeEuclideanPattern(STEPS, PULSES);
        circleView.updatePattern(pattern, STEPS, secondsPerStep);

        // BLEU : KICK grave
        // ORANGE : SNARE
        soundEngine = new SoundEngine(
                44_100,
                SoundEngine.Waveform.KICK, 80.0, 160, 2, 140,
                SoundEngine.Waveform.SNARE, 200.0, 140, 2, 120
        );

        circleView.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                if (event.getAction() == MotionEvent.ACTION_DOWN) {
                    handleTapTempo(event.getEventTime());
                    return true;
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
        if (soundEngine != null) soundEngine.release();
    }

    private void startLoop() {
        handler.removeCallbacks(tickRunnable);
        currentStep = -1;
        long delayMs = (long) Math.round(secondsPerStep * 1000.0);
        handler.postDelayed(tickRunnable, delayMs);
    }

    private void stopLoop() {
        handler.removeCallbacks(tickRunnable);
    }

    // TAP TEMPO
    private void handleTapTempo(long tapTimeMs) {
        if (!tapTimes.isEmpty()) {
            long last = tapTimes.get(tapTimes.size() - 1);
            if (tapTimeMs - last > MAX_INTERVAL_MS) {
                tapTimes.clear();
            }
        }

        tapTimes.add(tapTimeMs);
        while (tapTimes.size() > MAX_TAPS_MEMORY) {
            tapTimes.remove(0);
        }

        if (tapTimes.size() < 2) return;

        double sumIntervals = 0.0;
        int count = 0;
        for (int i = 1; i < tapTimes.size(); i++) {
            long dt = tapTimes.get(i) - tapTimes.get(i - 1);
            if (dt <= 0 || dt > MAX_INTERVAL_MS) continue;
            sumIntervals += dt;
            count++;
        }

        if (count == 0) return;

        double avgIntervalMs = sumIntervals / count;
        double bpm = 60000.0 / avgIntervalMs;

        if (bpm < MIN_BPM || bpm > MAX_BPM) return;

        applyBpm(bpm);
    }

    private void applyBpm(double bpm) {
        currentBpm = bpm;
        secondsPerStep = (60.0 / currentBpm) / STEPS_PER_BEAT;
        circleView.setBpm(currentBpm);
        stopLoop();
        startLoop();
    }

    private static boolean[] makeEuclideanPattern(int steps, int pulses) {
        if (steps < 1) steps = 1;
        if (pulses < 0) pulses = 0;
        if (pulses > steps) pulses = steps;

        boolean[] pat = new boolean[steps];
        if (pulses == 0) return pat;

        for (int i = 0; i < pulses; i++) {
            int idx = (int) Math.floor(i * (steps / (double) pulses));
            if (idx < 0) idx = 0;
            if (idx >= steps) idx = steps - 1;
            pat[idx] = true;
        }
        return pat;
    }
}
JAVAEOF

echo "✅ SoundEngine + MainActivity mis à jour (KICK bleu / SNARE orange)."
