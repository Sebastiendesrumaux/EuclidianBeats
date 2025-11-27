#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour de MainActivity (boutons + / - par couleur)…"

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

            if (circleView.shouldPlayKick(currentStep))      soundEngine.playKick();
            if (circleView.shouldPlaySnare(currentStep))     soundEngine.playSnare();
            if (circleView.shouldPlayHatOpen(currentStep))   soundEngine.playHatOpen();
            if (circleView.shouldPlayHatClosed(currentStep)) soundEngine.playHatClosed();

            long delayMs = (long) Math.round(secondsPerStep * 1000.0);
            handler.postDelayed(this, delayMs);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.BLACK);
        root.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT));

        // --- Vue principale ---
        circleView = new RhythmCircleView(this, null);
        circleView.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f));

        // --- Barre bleue (steps) ---
        LinearLayout blueBar = new LinearLayout(this);
        blueBar.setOrientation(LinearLayout.HORIZONTAL);
        blueBar.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button minusBlue = new Button(this);
        minusBlue.setAllCaps(false);
        minusBlue.setTextColor(Color.WHITE);
        minusBlue.setBackgroundColor(0xFF2196F3);
        minusBlue.setText("- steps");

        Button plusBlue = new Button(this);
        plusBlue.setAllCaps(false);
        plusBlue.setTextColor(Color.WHITE);
        plusBlue.setBackgroundColor(0xFF2196F3);
        plusBlue.setText("+ steps");

        LinearLayout.LayoutParams lpWeightBlue =
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        minusBlue.setLayoutParams(lpWeightBlue);
        plusBlue.setLayoutParams(lpWeightBlue);

        blueBar.addView(minusBlue);
        blueBar.addView(plusBlue);

        // --- Rangées orange / vert / rose : [Random] [ - ] [ + ] ---

        // Orange
        LinearLayout rowOrange = new LinearLayout(this);
        rowOrange.setOrientation(LinearLayout.HORIZONTAL);
        rowOrange.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button orangeRandom = new Button(this);
        orangeRandom.setAllCaps(false);
        orangeRandom.setTextColor(Color.BLACK);
        orangeRandom.setBackgroundColor(0xFFFF9800);

        Button orangeMinus = new Button(this);
        orangeMinus.setAllCaps(false);
        orangeMinus.setTextColor(Color.BLACK);
        orangeMinus.setBackgroundColor(0xFFFFCC80);
        orangeMinus.setText("-");

        Button orangePlus = new Button(this);
        orangePlus.setAllCaps(false);
        orangePlus.setTextColor(Color.BLACK);
        orangePlus.setBackgroundColor(0xFFFFCC80);
        orangePlus.setText("+");

        LinearLayout.LayoutParams lpWeightColor =
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        orangeRandom.setLayoutParams(lpWeightColor);
        orangeMinus.setLayoutParams(lpWeightColor);
        orangePlus.setLayoutParams(lpWeightColor);

        rowOrange.addView(orangeRandom);
        rowOrange.addView(orangeMinus);
        rowOrange.addView(orangePlus);

        // Vert
        LinearLayout rowGreen = new LinearLayout(this);
        rowGreen.setOrientation(LinearLayout.HORIZONTAL);
        rowGreen.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button greenRandom = new Button(this);
        greenRandom.setAllCaps(false);
        greenRandom.setTextColor(Color.BLACK);
        greenRandom.setBackgroundColor(0xFF4CAF50);

        Button greenMinus = new Button(this);
        greenMinus.setAllCaps(false);
        greenMinus.setTextColor(Color.BLACK);
        greenMinus.setBackgroundColor(0xFFA5D6A7);
        greenMinus.setText("-");

        Button greenPlus = new Button(this);
        greenPlus.setAllCaps(false);
        greenPlus.setTextColor(Color.BLACK);
        greenPlus.setBackgroundColor(0xFFA5D6A7);
        greenPlus.setText("+");

        greenRandom.setLayoutParams(lpWeightColor);
        greenMinus.setLayoutParams(lpWeightColor);
        greenPlus.setLayoutParams(lpWeightColor);

        rowGreen.addView(greenRandom);
        rowGreen.addView(greenMinus);
        rowGreen.addView(greenPlus);

        // Rose
        LinearLayout rowPink = new LinearLayout(this);
        rowPink.setOrientation(LinearLayout.HORIZONTAL);
        rowPink.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button pinkRandom = new Button(this);
        pinkRandom.setAllCaps(false);
        pinkRandom.setTextColor(Color.BLACK);
        pinkRandom.setBackgroundColor(0xFFE91E63);

        Button pinkMinus = new Button(this);
        pinkMinus.setAllCaps(false);
        pinkMinus.setTextColor(Color.BLACK);
        pinkMinus.setBackgroundColor(0xFFF8BBD0);
        pinkMinus.setText("-");

        Button pinkPlus = new Button(this);
        pinkPlus.setAllCaps(false);
        pinkPlus.setTextColor(Color.BLACK);
        pinkPlus.setBackgroundColor(0xFFF8BBD0);
        pinkPlus.setText("+");

        pinkRandom.setLayoutParams(lpWeightColor);
        pinkMinus.setLayoutParams(lpWeightColor);
        pinkPlus.setLayoutParams(lpWeightColor);

        rowPink.addView(pinkRandom);
        rowPink.addView(pinkMinus);
        rowPink.addView(pinkPlus);

        // Assemblage dans la vue
        root.addView(circleView);
        root.addView(blueBar);
        root.addView(rowOrange);
        root.addView(rowGreen);
        root.addView(rowPink);
        setContentView(root);

        // --- Tempo initial ---
        applyBpm(DEFAULT_BPM);

        // Motifs initiaux
        clampPulsesToSteps();
        recomputePatternsAndUpdateView();

        // Son
        soundEngine = new SoundEngine(44_100);

        // --- Taps : carré central = tempo, ailleurs = toggle ---
        circleView.setOnTouchListener(new View.OnTouchListener() {
            @Override public boolean onTouch(View v, MotionEvent e) {
                if (e.getAction() != MotionEvent.ACTION_DOWN) return false;

                float x = e.getX();
                float y = e.getY();

                int w = circleView.getWidth();
                int h = circleView.getHeight();
                if (w <= 0 || h <= 0) {
                    handleTapTempo(e.getEventTime());
                    return true;
                }

                float cx = w / 2f;
                float cy = h / 2f;
                float halfSide = 0.1f * Math.min(w, h); // carré central = 20% du min

                boolean inCenterSquare =
                        (x >= cx - halfSide && x <= cx + halfSide &&
                         y >= cy - halfSide && y <= cy + halfSide);

                if (inCenterSquare) {
                    handleTapTempo(e.getEventTime());
                } else {
                    boolean toggled = circleView.togglePointAt(x, y);
                    if (!toggled) {
                        handleTapTempo(e.getEventTime());
                    }
                }
                return true;
            }
        });

        // Labels init
        updateButtonLabels(orangeRandom, greenRandom, pinkRandom);

        // --- Actions des boutons ---

        // Steps bleus --
        minusBlue.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (steps > MIN_STEPS) {
                    steps--;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    circleView.reactivateAll();
                    updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
                }
            }
        });

        // Steps bleus ++
        plusBlue.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (steps < MAX_STEPS) {
                    steps++;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    circleView.reactivateAll();
                    updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
                }
            }
        });

        // --- Orange : random / - / + ---
        orangeRandom.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesOrange = (int) Math.floor(Math.random() * (steps + 1));
                clampPulsesToSteps();
                recomputePatternsAndUpdateView();
                circleView.reactivateAll();
                updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
            }
        });

        orangeMinus.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (pulsesOrange > 0) {
                    pulsesOrange--;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    circleView.reactivateAll();
                    updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
                }
            }
        });

        orangePlus.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (pulsesOrange < steps) {
                    pulsesOrange++;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    circleView.reactivateAll();
                    updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
                }
            }
        });

        // --- Vert : random / - / + ---
        greenRandom.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesGreen = (int) Math.floor(Math.random() * (steps + 1));
                clampPulsesToSteps();
                recomputePatternsAndUpdateView();
                circleView.reactivateAll();
                updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
            }
        });

        greenMinus.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (pulsesGreen > 0) {
                    pulsesGreen--;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    circleView.reactivateAll();
                    updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
                }
            }
        });

        greenPlus.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (pulsesGreen < steps) {
                    pulsesGreen++;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    circleView.reactivateAll();
                    updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
                }
            }
        });

        // --- Rose : random / - / + ---
        pinkRandom.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesPink = (int) Math.floor(Math.random() * (steps + 1));
                clampPulsesToSteps();
                recomputePatternsAndUpdateView();
                circleView.reactivateAll();
                updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
            }
        });

        pinkMinus.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (pulsesPink > 0) {
                    pulsesPink--;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    circleView.reactivateAll();
                    updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
                }
            }
        });

        pinkPlus.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (pulsesPink < steps) {
                    pulsesPink++;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    circleView.reactivateAll();
                    updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
                }
            }
        });
    }

    @Override protected void onResume() {
        super.onResume();
        startLoop();
    }

    @Override protected void onPause() {
        super.onPause();
        // on laisse la boucle tourner pour jouer écran éteint
    }

    @Override protected void onDestroy() {
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
        secondsPerStep = 60.0 / currentBpm;
        circleView.setBpm(currentBpm);
        stopLoop();
        startLoop();
    }

    private void clampPulsesToSteps() {
        if (pulsesOrange > steps) pulsesOrange = steps;
        if (pulsesGreen  > steps) pulsesGreen  = steps;
        if (pulsesPink   > steps) pulsesPink   = steps;
        if (pulsesOrange < 0) pulsesOrange = 0;
        if (pulsesGreen  < 0) pulsesGreen  = 0;
        if (pulsesPink   < 0) pulsesPink   = 0;
    }

    private void recomputePatternsAndUpdateView() {
        patternOrange = makeEuclideanPattern(steps, pulsesOrange);
        patternGreen  = makeEuclideanPattern(steps, pulsesGreen);
        patternPink   = makeEuclideanPattern(steps, pulsesPink);
        circleView.updatePatterns(patternOrange, patternGreen, patternPink, steps, secondsPerStep);
    }

    private void updateButtonLabels(Button orangeRandom, Button greenRandom, Button pinkRandom) {
        orangeRandom.setText("Snare : " + pulsesOrange + " (0.." + steps + " / " + steps + " bleus)");
        greenRandom.setText("Hat vert : " + pulsesGreen + " (0.." + steps + " / " + steps + " bleus)");
        pinkRandom.setText("Hat rose : " + pulsesPink + " (0.." + steps + " / " + steps + " bleus)");
    }

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

echo "✅ MainActivity mis à jour (random + +/- par couleur)."
