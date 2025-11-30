package com.example.appdummy;

import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.AssetFileDescriptor;
import android.graphics.Color;
import android.media.SoundPool;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.CheckBox;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends AppCompatActivity {
    private boolean isPlaying = true; // état initial : le séquenceur tourne


    private static final int MIN_STEPS = 2;
    private static final int MAX_STEPS = 32;

    private static final int INITIAL_STEPS         = 16;
    private static final int INITIAL_PULSES_ORANGE = 5;
    private static final int INITIAL_PULSES_GREEN  = 0;
    private static final int INITIAL_PULSES_PINK   = 0;

    private static final double DEFAULT_BPM = 60.0;
    private static final double MIN_BPM = 40.0;
    private static final double MAX_BPM = 260.0;

    private static final int REQ_WAV_KICK       = 1;
    private static final int REQ_WAV_SNARE      = 2;
    private static final int REQ_WAV_HAT_OPEN   = 3;
    private static final int REQ_WAV_HAT_CLOSED = 4;

    private static final String PREFS_NAME = "euclidian_beats_prefs";

    private enum PlayMode { SYNTH, SAMPLE }

    private RhythmCircleView circleView;
    private SoundEngine soundEngine;

    // SoundPool pour les samples WAV
    private SoundPool soundPool;
    private int sampleKickId      = 0;
    private int sampleSnareId     = 0;
    private int sampleHatOpenId   = 0;
    private int sampleHatClosedId = 0;

    // URIs persistés des samples
    private Uri uriKick;
    private Uri uriSnare;
    private Uri uriHatOpen;
    private Uri uriHatClosed;

    // mode de lecture par voix
    private PlayMode modeKick      = PlayMode.SYNTH;
    private PlayMode modeSnare     = PlayMode.SYNTH;
    private PlayMode modeHatOpen   = PlayMode.SYNTH;
    private PlayMode modeHatClosed = PlayMode.SYNTH;

    private int steps        = INITIAL_STEPS;
    private int pulsesOrange = INITIAL_PULSES_ORANGE;
    private int pulsesGreen  = INITIAL_PULSES_GREEN;
    private int pulsesPink   = INITIAL_PULSES_PINK;

    private boolean[] patternOrange;
    private boolean[] patternGreen;
    private boolean[] patternPink;

    private boolean isBlueMuted = false;
    private TextView stepsLabel;

    private double secondsPerStep;
    private double currentBpm = DEFAULT_BPM;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private int currentStep = 0;

    private final List<Long> tapTimes = new ArrayList<>();
    private static final int MAX_TAPS_MEMORY = 8;
    private static final long MAX_INTERVAL_MS = 2000;

    // petites “leds” de debug
    private View flashKick;
    private View flashSnare;
    private View flashHatOpen;
    private View flashHatClosed;

    // sliders pour pouvoir les manipuler lors du restore/save
    private SeekBar drumSeek;
    private SeekBar noteSeek;
    private TextView drumLabel;
    private TextView noteLabel;

    // glitch : niveau 0..1, plus un SeekBar et un label
    private double glitchLevel = 0.0;
    private SeekBar glitchSeek;
    private TextView glitchLabel;

    private final Runnable tickRunnable = new Runnable() {
        @Override public void run() {
            currentStep = (currentStep + 1) % steps;

            boolean kick      = circleView.shouldPlayKick(currentStep);
        if (isBlueMuted) kick = false;
            boolean snare     = circleView.shouldPlaySnare(currentStep);
            boolean hatOpen   = circleView.shouldPlayHatOpen(currentStep);
            boolean hatClosed = circleView.shouldPlayHatClosed(currentStep);

            circleView.setCurrentStep(currentStep);

            if (kick)      playKickVoice();
            if (snare)     playSnareVoice();
            if (hatOpen)   playHatOpenVoice();
            if (hatClosed) playHatClosedVoice();

            updateFlashRow(kick, snare, hatOpen, hatClosed);

            long delayMs = (long) Math.round(secondsPerStep * 1000.0);
            handler.postDelayed(this, delayMs);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // --- Layout racine ---
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.BLACK);
        root.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT));

        // Vue principale
        circleView = new RhythmCircleView(this, null);
        circleView.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f));

        // Barre bleue (steps)
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

        Button blueSound = new Button(this);
        stepsLabel = new TextView(this);
        stepsLabel.setTextColor(Color.WHITE);
        stepsLabel.setTextSize(16f);
        stepsLabel.setText("Steps : " + steps);

        CheckBox blueMuteCheck = new CheckBox(this);
        blueMuteCheck.setText("Mute");
        blueMuteCheck.setTextColor(Color.WHITE);
        blueMuteCheck.setChecked(false);
        blueMuteCheck.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                isBlueMuted = blueMuteCheck.isChecked();
            }
        });
        blueSound.setAllCaps(false);
        blueSound.setTextColor(Color.WHITE);
        blueSound.setBackgroundColor(0xFF0D47A1);
        blueSound.setText("Sound");

        LinearLayout.LayoutParams lpWeightBlue =
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        minusBlue.setLayoutParams(lpWeightBlue);
        plusBlue.setLayoutParams(lpWeightBlue);
        blueSound.setLayoutParams(lpWeightBlue);
        stepsLabel.setLayoutParams(lpWeightBlue);
        blueMuteCheck.setLayoutParams(lpWeightBlue);

        blueBar.addView(minusBlue);
        blueBar.addView(plusBlue);
        blueBar.addView(blueSound);
        blueBar.addView(stepsLabel);
        blueBar.addView(blueMuteCheck);

        // Rangées orange / vert / rose : [Random] [ - ] [ + ] [Sound]

        // Orange
        LinearLayout rowOrange = new LinearLayout(this);
        rowOrange.setOrientation(LinearLayout.HORIZONTAL);
        rowOrange.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button orangeRandom = new Button(this);
        orangeRandom.setAllCaps(false);
        orangeRandom.setText(String.valueOf(pulsesOrange));
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

        Button orangeSound = new Button(this);
        orangeSound.setAllCaps(false);
        orangeSound.setTextColor(Color.BLACK);
        orangeSound.setBackgroundColor(0xFFBF360C);
        orangeSound.setText("Sound");

        LinearLayout.LayoutParams lpWeightColor =
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        orangeRandom.setLayoutParams(lpWeightColor);
        orangeMinus.setLayoutParams(lpWeightColor);
        orangePlus.setLayoutParams(lpWeightColor);
        orangeSound.setLayoutParams(lpWeightColor);

        rowOrange.addView(orangeRandom);
        rowOrange.addView(orangeMinus);
        rowOrange.addView(orangePlus);
        rowOrange.addView(orangeSound);

        // Vert
        LinearLayout rowGreen = new LinearLayout(this);
        rowGreen.setOrientation(LinearLayout.HORIZONTAL);
        rowGreen.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button greenRandom = new Button(this);
        greenRandom.setAllCaps(false);
        greenRandom.setText(String.valueOf(pulsesGreen));
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

        Button greenSound = new Button(this);
        greenSound.setAllCaps(false);
        greenSound.setTextColor(Color.BLACK);
        greenSound.setBackgroundColor(0xFF1B5E20);
        greenSound.setText("Sound");

        greenRandom.setLayoutParams(lpWeightColor);
        greenMinus.setLayoutParams(lpWeightColor);
        greenPlus.setLayoutParams(lpWeightColor);
        greenSound.setLayoutParams(lpWeightColor);

        rowGreen.addView(greenRandom);
        rowGreen.addView(greenMinus);
        rowGreen.addView(greenPlus);
        rowGreen.addView(greenSound);

        // Rose
        LinearLayout rowPink = new LinearLayout(this);
        rowPink.setOrientation(LinearLayout.HORIZONTAL);
        rowPink.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button pinkRandom = new Button(this);
        pinkRandom.setAllCaps(false);
        pinkRandom.setText(String.valueOf(pulsesPink));
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

        Button pinkSound = new Button(this);
        pinkSound.setAllCaps(false);
        pinkSound.setTextColor(Color.BLACK);
        pinkSound.setBackgroundColor(0xFF880E4F);
        pinkSound.setText("Sound");

        pinkRandom.setLayoutParams(lpWeightColor);
        pinkMinus.setLayoutParams(lpWeightColor);
        pinkPlus.setLayoutParams(lpWeightColor);
        pinkSound.setLayoutParams(lpWeightColor);

        rowPink.addView(pinkRandom);
        rowPink.addView(pinkMinus);
        rowPink.addView(pinkPlus);
        rowPink.addView(pinkSound);

        // --- Barre de clignotants (Kick / Snare / Hat open / Hat closed) ---
        LinearLayout flashRow = new LinearLayout(this);
        flashRow.setOrientation(LinearLayout.HORIZONTAL);
        flashRow.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                20));

        LinearLayout.LayoutParams lpFlash =
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f);

        flashKick = new View(this);
        flashKick.setLayoutParams(lpFlash);
        flashKick.setBackgroundColor(0xFF004A6F); // bleu sombre

        flashSnare = new View(this);
        flashSnare.setLayoutParams(lpFlash);
        flashSnare.setBackgroundColor(0xFF7A5A00); // ambre sombre

        flashHatOpen = new View(this);
        flashHatOpen.setLayoutParams(lpFlash);
        flashHatOpen.setBackgroundColor(0xFF1B5E20); // vert sombre

        flashHatClosed = new View(this);
        flashHatClosed.setLayoutParams(lpFlash);
        flashHatClosed.setBackgroundColor(0xFF880E4F); // rose sombre

        flashRow.addView(flashKick);
        flashRow.addView(flashSnare);
        flashRow.addView(flashHatOpen);
        flashRow.addView(flashHatClosed);

        // Widgets de volume
        drumLabel = new TextView(this);
        drumLabel.setTextColor(Color.WHITE);
        drumLabel.setTextSize(16f);
        drumLabel.setText("Volume des drums : 100 %");

        drumSeek = new SeekBar(this);
        drumSeek.setMax(100);
        drumSeek.setProgress(100);

        noteLabel = new TextView(this);
        noteLabel.setTextColor(Color.WHITE);
        noteLabel.setTextSize(16f);
        noteLabel.setText("Volume des notes : 50 %");

        noteSeek = new SeekBar(this);
        noteSeek.setMax(100);
        noteSeek.setProgress(50);

        // Glitch : label + slider horizontal
        glitchLabel = new TextView(this);
        glitchLabel.setTextColor(Color.WHITE);
        glitchLabel.setTextSize(16f);
        glitchLabel.setText("Glitch level : 0 %");

        glitchSeek = new SeekBar(this);
        glitchSeek.setMax(100);
        glitchSeek.setProgress(0);

        // Bouton SAVE
        Button saveButton = new Button(this);
        saveButton.setAllCaps(false);
        saveButton.setTextColor(Color.WHITE);
        saveButton.setBackgroundColor(0xFF616161);
        saveButton.setText("Save");

        // Assemblage du layout
        root.addView(circleView);
        root.addView(blueBar);
        root.addView(rowOrange);
        root.addView(rowGreen);
        root.addView(rowPink);
        root.addView(flashRow);
        root.addView(drumLabel);
        root.addView(drumSeek);
        root.addView(noteLabel);
        root.addView(noteSeek);
        root.addView(glitchLabel);
        root.addView(glitchSeek);
        // --- Bandeau Play/Stop + Save ---
        LinearLayout bottomBar = new LinearLayout(this);
        bottomBar.setOrientation(LinearLayout.HORIZONTAL);
        bottomBar.setLayoutParams(new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        bottomBar.setPadding(10,10,10,10);
        
        Button playStopButton = new Button(this);
        playStopButton.setAllCaps(false);
        playStopButton.setTextColor(Color.WHITE);
        playStopButton.setBackgroundColor(0xFF424242);
        playStopButton.setText(isPlaying ? "Stop" : "Play");
        playStopButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (isPlaying) {
                    isPlaying = false;
                    handler.removeCallbacks(tickRunnable);
                    playStopButton.setText("Play");
                } else {
                    isPlaying = true;
                    handler.post(tickRunnable);
                    playStopButton.setText("Stop");
                }
            }
        });
        
        bottomBar.addView(playStopButton, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        bottomBar.addView(saveButton, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        
        root.addView(bottomBar);


        setContentView(root);

        // Tempo initial
        applyBpm(DEFAULT_BPM);

        // Motifs initiaux
        clampPulsesToSteps();
        recomputePatternsAndUpdateView();

        // Son + gains initiaux
        soundEngine = new SoundEngine(44_100);
        soundEngine.setDrumGain(1.0);
        soundEngine.setNoteGain(0.5);

        // SoundPool pour les samples
        soundPool = new SoundPool.Builder()
                .setMaxStreams(4)
                .build();

        // Sliders de volume
        drumSeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (soundEngine != null) {
                    double g = progress / 100.0;
                    soundEngine.setDrumGain(g);
                }
                drumLabel.setText("Volume des drums : " + progress + " %");
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        noteSeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (soundEngine != null) {
                    double g = progress / 100.0;
                    soundEngine.setNoteGain(g);
                }
                noteLabel.setText("Volume des notes : " + progress + " %");
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        glitchSeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                glitchLevel = progress / 100.0;
                glitchLabel.setText("Glitch level : " + progress + " %");
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        // Bouton SAVE
        saveButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                saveState();
            }
        });

        // Taps : carré central = tempo, ailleurs = toggle
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

        // Labels init (texte des boutons Random)
        updateButtonLabels(orangeRandom, greenRandom, pinkRandom);

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

        // Bouton "Sound" bleu
        blueSound.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                showSoundSourceDialog("(blue)", new Runnable() {
                    @Override public void run() { modeKick = PlayMode.SYNTH; }
                }, REQ_WAV_KICK);
            }
        });

        // Orange : random / - / +
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

        orangeSound.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                showSoundSourceDialog("(orange)", new Runnable() {
                    @Override public void run() { modeSnare = PlayMode.SYNTH; }
                }, REQ_WAV_SNARE);
            }
        });

        // Vert : random / - / +
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

        greenSound.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                showSoundSourceDialog("(green)", new Runnable() {
                    @Override public void run() { modeHatOpen = PlayMode.SYNTH; }
                }, REQ_WAV_HAT_OPEN);
            }
        });

        // Rose : random / - / +
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

        pinkSound.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                showSoundSourceDialog("(pink)", new Runnable() {
                    @Override public void run() { modeHatClosed = PlayMode.SYNTH; }
                }, REQ_WAV_HAT_CLOSED);
            }
        });

        // ➜ Restaurer l'état s'il y en a un
        restoreState(orangeRandom, greenRandom, pinkRandom);
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
        if (soundPool != null) {
            soundPool.release();
            soundPool = null;
        }
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
        if (stepsLabel != null) stepsLabel.setText("Steps : " + steps);

        orangeRandom.setText(String.valueOf(pulsesOrange));
        greenRandom.setText(String.valueOf(pulsesGreen));
        pinkRandom.setText(String.valueOf(pulsesPink));
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

    // Met à jour la barre de leds pour ce step
    private void updateFlashRow(boolean kick, boolean snare,
                                boolean hatOpen, boolean hatClosed) {
        if (flashKick != null)
            flashKick.setBackgroundColor(kick ? 0xFF00BCD4 : 0xFF004A6F);
        if (flashSnare != null)
            flashSnare.setBackgroundColor(snare ? 0xFFFFC107 : 0xFF7A5A00);
        if (flashHatOpen != null)
            flashHatOpen.setBackgroundColor(hatOpen ? 0xFF4CAF50 : 0xFF1B5E20);
        if (flashHatClosed != null)
            flashHatClosed.setBackgroundColor(hatClosed ? 0xFFE91E63 : 0xFF880E4F);
    }

    // --- Gestion des sources sonores (Synth / WAV) ---

    private void showSoundSourceDialog(String title, final Runnable useSynthAction, final int requestCode) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(title);
        String[] items = new String[] {
                "Synthèse interne",
                "Choisir un fichier WAV…",
                "Enregistrer depuis le micro…"
        };
        builder.setItems(items, new DialogInterface.OnClickListener() {
            @Override public void onClick(DialogInterface dialog, int which) {
                if (which == 0) {
                    // Synthèse
                    useSynthAction.run();
                } else if (which == 1) {
                    // Sélection d'un fichier WAV
                    Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("audio/*");
                    intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[] {
                            "audio/wav", "audio/x-wav", "audio/*"
                    });
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                            | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
                    startActivityForResult(intent, requestCode);
                } else if (which == 2) {
                    MicSampleRecorder rec = new MicSampleRecorder(MainActivity.this, "mic_rec",
                        new MicSampleRecorder.OnSampleReadyListener() {
                            @Override public void onSampleReady(java.io.File wav) {
                                android.net.Uri u = android.net.Uri.fromFile(wav);
                                reloadSampleFromUri(u, requestCode);
                            }
                        }
                    );
                    rec.show();
                }
            }
        });
        builder.show();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null) return;

        Uri uri = data.getData();
        if (uri == null) return;

        final int takeFlags = data.getFlags()
                & (Intent.FLAG_GRANT_READ_URI_PERMISSION
                | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        try {
            getContentResolver().takePersistableUriPermission(uri, takeFlags);
        } catch (SecurityException ignored) {}

        // Mémoriser l'URI
        switch (requestCode) {
            case REQ_WAV_KICK:
                uriKick = uri;
                break;
            case REQ_WAV_SNARE:
                uriSnare = uri;
                break;
            case REQ_WAV_HAT_OPEN:
                uriHatOpen = uri;
                break;
            case REQ_WAV_HAT_CLOSED:
                uriHatClosed = uri;
                break;
            default:
                break;
        }

        // Charger le sample
        reloadSampleFromUri(uri, requestCode);
    }

    private void reloadSampleFromUri(Uri uri, int requestCode) {
        if (uri == null || soundPool == null) return;
        try {
            AssetFileDescriptor afd = getContentResolver().openAssetFileDescriptor(uri, "r");
            if (afd == null) return;
            int soundId = soundPool.load(afd, 1);
            afd.close();

            switch (requestCode) {
                case REQ_WAV_KICK:
                    sampleKickId = soundId;
                    modeKick = PlayMode.SAMPLE;
                    break;
                case REQ_WAV_SNARE:
                    sampleSnareId = soundId;
                    modeSnare = PlayMode.SAMPLE;
                    break;
                case REQ_WAV_HAT_OPEN:
                    sampleHatOpenId = soundId;
                    modeHatOpen = PlayMode.SAMPLE;
                    break;
                case REQ_WAV_HAT_CLOSED:
                    sampleHatClosedId = soundId;
                    modeHatClosed = PlayMode.SAMPLE;
                    break;
                default:
                    break;
            }
        } catch (IOException e) {
            // en cas d'échec, on laisse le mode synth
        }
    }

    // --- Helpers de lecture en fonction du mode + glitch ---

    private void playKickVoice() {
        if (modeKick == PlayMode.SAMPLE && soundPool != null && sampleKickId != 0) {
            float[] vAndP = makeGlitchedVolumeAndPitch();
            soundPool.play(sampleKickId, vAndP[0], vAndP[0], 1, 0, vAndP[1]);
        } else {
            soundEngine.playKick();
        }
    }

    private void playSnareVoice() {
        if (modeSnare == PlayMode.SAMPLE && soundPool != null && sampleSnareId != 0) {
            float[] vAndP = makeGlitchedVolumeAndPitch();
            soundPool.play(sampleSnareId, vAndP[0], vAndP[0], 1, 0, vAndP[1]);
        } else {
            soundEngine.playSnare();
        }
    }

    private void playHatOpenVoice() {
        if (modeHatOpen == PlayMode.SAMPLE && soundPool != null && sampleHatOpenId != 0) {
            float[] vAndP = makeGlitchedVolumeAndPitch();
            soundPool.play(sampleHatOpenId, vAndP[0], vAndP[0], 1, 0, vAndP[1]);
        } else {
            soundEngine.playHatOpen();
        }
    }

    private void playHatClosedVoice() {
        if (modeHatClosed == PlayMode.SAMPLE && soundPool != null && sampleHatClosedId != 0) {
            float[] vAndP = makeGlitchedVolumeAndPitch();
            soundPool.play(sampleHatClosedId, vAndP[0], vAndP[0], 1, 0, vAndP[1]);
        } else {
            soundEngine.playHatClosed();
        }
    }

    /**
     * Calcule un (volume, pitch) légèrement aléatoire en fonction de glitchLevel.
     * glitchLevel=0  => (1.0, 1.0)
     * glitchLevel=1  => volume ~ [0.6, 1.4], pitch ~ [0.9, 1.1]
     */
    private float[] makeGlitchedVolumeAndPitch() {
        double g = glitchLevel;
        if (g < 0.0) g = 0.0;
        if (g > 1.0) g = 1.0;

        double volJitter   = 4.0 * g;  // ±40% max
        double pitchJitter = 1.5 * g / 4;  // ±10% max

        double volFactor = 1.0 + (Math.random() * 2.0 - 1.0) * volJitter;
        double pitch     = 1.0 + (Math.random() * 2.0 - 1.0) * pitchJitter;

        if (volFactor < 0.0) volFactor = 0.0;
        if (volFactor > 2.0) volFactor = 2.0;
        if (pitch < 0.5) pitch = 0.5;
        if (pitch > 2.0) pitch = 2.0;

        return new float[] { (float) volFactor, (float) pitch };
    }

    // --- Sauvegarde / restauration de l'état ---

    private void saveState() {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        SharedPreferences.Editor e = prefs.edit();

        e.putBoolean("has_state", true);
        e.putInt("steps", steps);
        e.putInt("pulsesOrange", pulsesOrange);
        e.putInt("pulsesGreen", pulsesGreen);
        e.putInt("pulsesPink", pulsesPink);
        e.putFloat("bpm", (float) currentBpm);

        if (drumSeek != null) e.putInt("drumVol", drumSeek.getProgress());
        if (noteSeek != null) e.putInt("noteVol", noteSeek.getProgress());

        e.putFloat("glitchLevel", (float) glitchLevel);
        if (glitchSeek != null) e.putInt("glitchProgress", glitchSeek.getProgress());

        e.putInt("modeKick",      (modeKick      == PlayMode.SAMPLE) ? 1 : 0);
        e.putInt("modeSnare",     (modeSnare     == PlayMode.SAMPLE) ? 1 : 0);
        e.putInt("modeHatOpen",   (modeHatOpen   == PlayMode.SAMPLE) ? 1 : 0);
        e.putInt("modeHatClosed", (modeHatClosed == PlayMode.SAMPLE) ? 1 : 0);

        e.putString("uriKick",      (uriKick      != null) ? uriKick.toString()      : null);
        e.putString("uriSnare",     (uriSnare     != null) ? uriSnare.toString()     : null);
        e.putString("uriHatOpen",   (uriHatOpen   != null) ? uriHatOpen.toString()   : null);
        e.putString("uriHatClosed", (uriHatClosed != null) ? uriHatClosed.toString() : null);

        e.apply();

        Toast.makeText(this, "État sauvegardé", Toast.LENGTH_SHORT).show();
    }

    private void restoreState(Button orangeRandom, Button greenRandom, Button pinkRandom) {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        if (!prefs.getBoolean("has_state", false)) return;

        steps        = prefs.getInt("steps", steps);
        pulsesOrange = prefs.getInt("pulsesOrange", pulsesOrange);
        pulsesGreen  = prefs.getInt("pulsesGreen",  pulsesGreen);
        pulsesPink   = prefs.getInt("pulsesPink",   pulsesPink);

        float bpm = prefs.getFloat("bpm", (float) DEFAULT_BPM);
        applyBpm(bpm); // remet le tempo (et relance la boucle)

        int drumVol = prefs.getInt("drumVol", 100);
        int noteVol = prefs.getInt("noteVol", 50);
        if (drumSeek != null) drumSeek.setProgress(drumVol);
        if (noteSeek != null) noteSeek.setProgress(noteVol);

        glitchLevel = prefs.getFloat("glitchLevel", 0f);
        int glitchProg = prefs.getInt("glitchProgress", (int) (glitchLevel * 100f));
        if (glitchSeek != null) glitchSeek.setProgress(glitchProg);
        if (glitchLabel != null) {
            glitchLabel.setText("Glitch level : " + glitchProg + " %");
        }

        modeKick      = (prefs.getInt("modeKick", 0)      == 1) ? PlayMode.SAMPLE : PlayMode.SYNTH;
        modeSnare     = (prefs.getInt("modeSnare", 0)     == 1) ? PlayMode.SAMPLE : PlayMode.SYNTH;
        modeHatOpen   = (prefs.getInt("modeHatOpen", 0)   == 1) ? PlayMode.SAMPLE : PlayMode.SYNTH;
        modeHatClosed = (prefs.getInt("modeHatClosed", 0) == 1) ? PlayMode.SAMPLE : PlayMode.SYNTH;

        String sKick      = prefs.getString("uriKick", null);
        String sSnare     = prefs.getString("uriSnare", null);
        String sHatOpen   = prefs.getString("uriHatOpen", null);
        String sHatClosed = prefs.getString("uriHatClosed", null);

        if (sKick != null) {
            uriKick = Uri.parse(sKick);
            reloadSampleFromUri(uriKick, REQ_WAV_KICK);
        }
        if (sSnare != null) {
            uriSnare = Uri.parse(sSnare);
            reloadSampleFromUri(uriSnare, REQ_WAV_SNARE);
        }
        if (sHatOpen != null) {
            uriHatOpen = Uri.parse(sHatOpen);
            reloadSampleFromUri(uriHatOpen, REQ_WAV_HAT_OPEN);
        }
        if (sHatClosed != null) {
            uriHatClosed = Uri.parse(sHatClosed);
            reloadSampleFromUri(uriHatClosed, REQ_WAV_HAT_CLOSED);
        }

        clampPulsesToSteps();
        recomputePatternsAndUpdateView();
        circleView.reactivateAll();
        updateButtonLabels(orangeRandom, greenRandom, pinkRandom);
    }
}
