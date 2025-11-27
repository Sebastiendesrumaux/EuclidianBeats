#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour de RhythmCircleView + MainActivity pour points activables/désactivables…"

########################################
# RhythmCircleView : active/inactive + hit-test
########################################
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
 * - steps bleus (tempo / kick)
 * - pulses oranges (snare)
 * - pulses verts (hi-hat ouvert)
 * - pulses roses (hi-hat fermé)
 * - chaque point peut être actif/inactif (petit cercle autour quand actif)
 * - aiguille sur le step courant
 * - BPM rouge au centre
 *
 * La logique "qui sonne ?" est aussi portée ici :
 *  - shouldPlayKick(step)
 *  - shouldPlaySnare(step)
 *  - shouldPlayHatOpen(step)
 *  - shouldPlayHatClosed(step)
 *
 * + méthode togglePointAt(x,y) pour activer/désactiver le point le plus proche d'un tap.
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

    // contours des points actifs
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

        // contours
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

    // Assure que les tableaux active* existent et sont tous à true
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

    // Appelé par l'activité pour tout réactiver (par ex. après clamp des steps)
    public void reactivateAll() {
        if (activeBlue != null)   Arrays.fill(activeBlue,   true);
        if (activeOrange != null) Arrays.fill(activeOrange, true);
        if (activeGreen != null)  Arrays.fill(activeGreen,  true);
        if (activePink != null)   Arrays.fill(activePink,   true);
        invalidate();
    }

    // --- API depuis l'activité ---

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

        // réinitialiser tous les points comme actifs
        activeBlue   = null;
        activeOrange = null;
        activeGreen  = null;
        activePink   = null;
        recalc();
    }

    // Logique : qui doit jouer ?

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
     * Toggle du point le plus proche d'un tap.
     * Retourne true si quelque chose a été modifié (un point trouvé).
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

        // Rayons des anneaux
        float rBlue   = r;
        float rOrange = r * 0.85f;
        float rGreen  = r * 0.7f;
        float rPink   = r * 0.55f;

        // Tolérance radiale
        float tol = r * 0.12f;

        // On calcule la différence de distance à chaque anneau
        float dBlue   = Math.abs(dist - rBlue);
        float dOrange = Math.abs(dist - rOrange);
        float dGreen  = Math.abs(dist - rGreen);
        float dPink   = Math.abs(dist - rPink);

        // Si on est trop loin de tous les anneaux, on ne toggle rien
        if (dBlue > tol && dOrange > tol && dGreen > tol && dPink > tol) {
            return false;
        }

        // Angle pour trouver l'index
        float angleDeg = (float) Math.toDegrees(Math.atan2(dy, dx)) + 90f;
        if (angleDeg < 0f) angleDeg += 360f;
        int index = Math.round(angleDeg / angleStep) % steps;

        // Déterminer quel anneau est le plus proche
        float minD = dBlue;
        int ring = 0; // 0=bleu, 1=orange, 2=vert, 3=rose

        if (dOrange < minD) { minD = dOrange; ring = 1; }
        if (dGreen  < minD) { minD = dGreen;  ring = 2; }
        if (dPink   < minD) { minD = dPink;   ring = 3; }

        ensureActiveArrays();

        switch (ring) {
            case 0: // bleu : toujours existant
                activeBlue[index] = !activeBlue[index];
                invalidate();
                return true;
            case 1: // orange : seulement si il y a un pulse euclidien ici
                if (patternOrange != null &&
                    index < patternOrange.length &&
                    patternOrange[index]) {
                    activeOrange[index] = !activeOrange[index];
                    invalidate();
                    return true;
                }
                return false;
            case 2: // vert
                if (patternGreen != null &&
                    index < patternGreen.length &&
                    patternGreen[index]) {
                    activeGreen[index] = !activeGreen[index];
                    invalidate();
                    return true;
                }
                return false;
            case 3: // rose
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

        float outlineDelta = 4f;

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

        // anneau orange (snare)
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

        // anneau vert (hat ouvert)
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

        // anneau rose (hat fermé)
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
# MainActivity : utilise shouldPlay* + togglePointAt + réactivation après clamp
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
 * - steps bleus variables (2..32) = KICK, tempo maître
 * - pulses oranges euclidiens = SNARE
 * - pulses verts euclidiens   = HI-HAT OUVERT
 * - pulses roses euclidiens   = HI-HAT FERMÉ
 * - chaque point peut être activé/inactivé (petit cercle autour)
 * - BPM initial = 60 (1 step = 1 beat)
 * - Tap tempo (si le tap ne tombe pas sur un point)
 * - Bouton bleu "-"  : steps--
 * - Bouton bleu "+"  : steps++
 * - Boutons orange / vert / rose : random pulses (0..steps)
 * - après clamp ou random, tous les points des cercles concernés sont réactivés
 * - la boucle continue écran éteint
 */
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

            if (circleView.shouldPlayKick(currentStep)) {
                soundEngine.playKick();
            }
            if (circleView.shouldPlaySnare(currentStep)) {
                soundEngine.playSnare();
            }
            if (circleView.shouldPlayHatOpen(currentStep)) {
                soundEngine.playHatOpen();
            }
            if (circleView.shouldPlayHatClosed(currentStep)) {
                soundEngine.playHatClosed();
            }

            long delayMs = (long) Math.round(secondsPerStep * 1000.0);
            handler.postDelayed(this, delayMs);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // --- UI racine ---
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.BLACK);
        root.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT));

        // Vue cercle
        circleView = new RhythmCircleView(this, null);
        circleView.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f));

        // Barre des boutons bleus (+/-)
        LinearLayout blueBar = new LinearLayout(this);
        blueBar.setOrientation(LinearLayout.HORIZONTAL);
        blueBar.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button minusBlue = new Button(this);
        minusBlue.setAllCaps(false);
        minusBlue.setTextColor(Color.WHITE);
        minusBlue.setBackgroundColor(0xFF2196F3); // bleu
        minusBlue.setText("- steps");

        Button plusBlue = new Button(this);
        plusBlue.setAllCaps(false);
        plusBlue.setTextColor(Color.WHITE);
        plusBlue.setBackgroundColor(0xFF2196F3); // bleu
        plusBlue.setText("+ steps");

        LinearLayout.LayoutParams lpWeight =
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        minusBlue.setLayoutParams(lpWeight);
        plusBlue.setLayoutParams(lpWeight);

        blueBar.addView(minusBlue);
        blueBar.addView(plusBlue);

        // Boutons orange / vert / rose
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
        root.addView(blueBar);
        root.addView(orangeButton);
        root.addView(greenButton);
        root.addView(pinkButton);
        setContentView(root);

        // BPM initial
        applyBpm(DEFAULT_BPM);

        // Motifs initiaux
        clampPulsesToSteps();
        recomputePatternsAndUpdateView();

        // Son
        soundEngine = new SoundEngine(44_100);

        // Touch : toggle si on tape sur un point, sinon tap-tempo
        circleView.setOnTouchListener(new View.OnTouchListener() {
            @Override public boolean onTouch(View v, MotionEvent e) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) {
                    float x = e.getX();
                    float y = e.getY();
                    boolean toggled = circleView.togglePointAt(x, y);
                    if (!toggled) {
                        handleTapTempo(e.getEventTime());
                    }
                    return true;
                }
                return false;
            }
        });

        // Labels init
        updateButtonLabels(orangeButton, greenButton, pinkButton);

        // --- Actions des boutons ---

        // Steps bleus --
        minusBlue.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (steps > MIN_STEPS) {
                    steps--;
                    clampPulsesToSteps();
                    recomputePatternsAndUpdateView();
                    circleView.reactivateAll(); // tous les points des cercles modifiés réactivés
                    updateButtonLabels(orangeButton, greenButton, pinkButton);
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
                    updateButtonLabels(orangeButton, greenButton, pinkButton);
                }
            }
        });

        // Random pulses oranges (0..steps)
        orangeButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesOrange = (int) Math.floor(Math.random() * (steps + 1)); // 0..steps
                clampPulsesToSteps();
                recomputePatternsAndUpdateView();
                circleView.reactivateAll();
                updateButtonLabels(orangeButton, greenButton, pinkButton);
            }
        });

        // Random pulses verts
        greenButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesGreen = (int) Math.floor(Math.random() * (steps + 1)); // 0..steps
                clampPulsesToSteps();
                recomputePatternsAndUpdateView();
                circleView.reactivateAll();
                updateButtonLabels(orangeButton, greenButton, pinkButton);
            }
        });

        // Random pulses roses
        pinkButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pulsesPink = (int) Math.floor(Math.random() * (steps + 1)); // 0..steps
                clampPulsesToSteps();
                recomputePatternsAndUpdateView();
                circleView.reactivateAll();
                updateButtonLabels(orangeButton, greenButton, pinkButton);
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

    // TAP TEMPO (si le tap ne tombe pas sur un point cliquable)
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

    // Assure pulses <= steps
    private void clampPulsesToSteps() {
        if (pulsesOrange > steps) pulsesOrange = steps;
        if (pulsesGreen  > steps) pulsesGreen  = steps;
        if (pulsesPink   > steps) pulsesPink   = steps;
        if (pulsesOrange < 0) pulsesOrange = 0;
        if (pulsesGreen  < 0) pulsesGreen  = 0;
        if (pulsesPink   < 0) pulsesPink   = 0;
    }

    // Recalcule les motifs euclidiens et synchronise la vue
    private void recomputePatternsAndUpdateView() {
        patternOrange = makeEuclideanPattern(steps, pulsesOrange);
        patternGreen  = makeEuclideanPattern(steps, pulsesGreen);
        patternPink   = makeEuclideanPattern(steps, pulsesPink);
        circleView.updatePatterns(patternOrange, patternGreen, patternPink, steps, secondsPerStep);
    }

    // Met à jour les labels des boutons
    private void updateButtonLabels(Button orangeButton, Button greenButton, Button pinkButton) {
        orangeButton.setText("Pulses oranges : " + pulsesOrange + " (0.." + steps + ", sur " + steps + " bleus)");
        greenButton.setText("Pulses verts : " + pulsesGreen + " (0.." + steps + ", sur " + steps + " bleus)");
        pinkButton.setText("Pulses roses : " + pulsesPink + " (0.." + steps + ", sur " + steps + " bleus)");
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

echo "✅ Mise à jour terminée (points cliquables + réactivation après clamp)."
