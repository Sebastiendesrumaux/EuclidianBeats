package com.example.appdummy;
import android.graphics.Color;
import android.content.Context;
import android.Manifest;
import android.app.AlertDialog;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.AudioRecord;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.SeekBar;


import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.view.View;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

public class MicSampleRecorder {

    public interface OnSampleReadyListener {
        void onSampleReady(File wavFile);
    }

    private final MainActivity activity;
    private final String name;
    private final OnSampleReadyListener callback;

    private boolean recording = false;
    private AudioRecord audioRecord;
    private Thread recordThread;

    private short[] buffer;
    private int length;

    private File outputFile;
    private MediaPlayer mediaPlayer;



    private WaveformView waveformView; // <--- AJOUT
private AlertDialog dialog;
    private Button btnRec;
    private Button btnStop;
    private Button btnPlay;
    private Button btnOk;
    private TextView label;

    

    // --- AJOUTS ---
    private short[] currentPcm = null;   // dernier buffer audio en mémoire

    private SeekBar trimSeek;
    private TextView trimLabel;
    private double trimThreshold = 0.05; // 5% de la pleine échelle par défaut

    private static final int SAMPLE_RATE = 44100;

    public MicSampleRecorder(MainActivity activity, String name, OnSampleReadyListener cb) {
        this.activity = activity;
        this.name = name;
        this.callback = cb;
    }

    public void show() {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                    activity,
                    new String[]{ Manifest.permission.RECORD_AUDIO },
                    1234
            );
            return;
        }

        LinearLayout root = new LinearLayout(activity);
        root.setOrientation(LinearLayout.VERTICAL);

        label = new TextView(activity);
        label.setText("Prêt à enregistrer…");
        root.addView(label);
// Vue de forme d'onde (initialement vide)
        waveformView = new WaveformView(activity);
        LinearLayout.LayoutParams wfLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(120)  // hauteur raisonnable
        );
        wfLp.topMargin = dpToPx(8);
        wfLp.bottomMargin = dpToPx(8);
        root.addView(waveformView, wfLp);
        
        // --- Ligne Trim / Normalize ---
        LinearLayout rowEdit = new LinearLayout(activity);
        rowEdit.setOrientation(LinearLayout.HORIZONTAL);
        root.addView(rowEdit);

        Button btnTrim = new Button(activity);
        btnTrim.setText("Trim");
        Button btnNorm = new Button(activity);
        btnNorm.setText("Normalize");

        LinearLayout.LayoutParams lpEdit =
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        rowEdit.addView(btnTrim, lpEdit);
        rowEdit.addView(btnNorm, lpEdit);

        // --- Seuil de trim ---
        trimLabel = new TextView(activity);
        trimLabel.setText("Trim threshold : 5 %");
        root.addView(trimLabel);

        trimSeek = new SeekBar(activity);
        trimSeek.setMax(100);
        trimSeek.setProgress(5); // 5% par défaut
        root.addView(trimSeek);

        trimSeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (progress < 0) progress = 0;
                if (progress > 100) progress = 100;
                trimThreshold = progress / 100.0; // 0.00 à 1.00
                trimLabel.setText("Trim threshold : " + progress + " %");
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });
        
        LinearLayout row = new LinearLayout(activity);
        row.setOrientation(LinearLayout.HORIZONTAL);
        root.addView(row);

        btnRec  = new Button(activity);
        btnStop = new Button(activity);
        btnPlay = new Button(activity);
        btnOk   = new Button(activity);

        btnRec.setText("Rec");
        btnStop.setText("Stop");
        btnPlay.setText("Play");
        btnOk.setText("OK");

        LinearLayout.LayoutParams lp =
                new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        row.addView(btnRec,  lp);
        row.addView(btnStop, lp);
        row.addView(btnPlay, lp);
        row.addView(btnOk,   lp);

        btnStop.setEnabled(false);
        btnPlay.setEnabled(false);
        btnOk.setEnabled(false);

        btnRec.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { startRecord(); }
        });
        btnStop.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { stopRecord(); }
        });
        btnPlay.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { togglePlay(); }
        });
        btnOk.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { confirm(); }
        });
btnTrim.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                trimCurrentPcm();
            }
        });

        btnNorm.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                normalizeCurrentPcm();
            }
        });
        dialog = new AlertDialog.Builder(activity)
                .setTitle("Enregistrement micro")
                .setView(root)
                .setNegativeButton("Annuler", null)
                .create();
        dialog.show();
    }

    private void startRecord() {
        if (recording) return;

        int min = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
        );
        if (min <= 0) min = 2048;

        buffer = new short[SAMPLE_RATE * 10]; // max ~10s
        length = 0;

        audioRecord = new AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                min
        );

        recording = true;
        btnRec.setEnabled(false);
        btnStop.setEnabled(true);
        label.setText("Enregistrement…");

        audioRecord.startRecording();

        recordThread = new Thread(new Runnable() {
            @Override public void run() {
                short[] tmp = new short[1024];
                while (recording) {
                    int n = audioRecord.read(tmp, 0, tmp.length);
                    if (n > 0 && length + n <= buffer.length) {
                        System.arraycopy(tmp, 0, buffer, length, n);
                        length += n;
                    }
                }
            }
        });
        recordThread.start();
    }

    private void stopRecord() {
        if (!recording) return;
        recording = false;

        try { recordThread.join(200); } catch (Exception ignored) {}

        try {
            audioRecord.stop();
        } catch (Exception ignored) {}
        audioRecord.release();
        audioRecord = null;

        btnRec.setEnabled(true);
        btnStop.setEnabled(false);

            
        short[] pcm = new short[length];
        System.arraycopy(buffer, 0, pcm, 0, length);

        // On garde le buffer en mémoire
        currentPcm = pcm;

        // Normalisation automatique de base (tu peux l’enlever si tu veux un flux brut)
        normalize(currentPcm);

        // Sauvegarde sur disque
        saveWav(currentPcm);

        // Mise à jour visuelle
        if (waveformView != null) {
            waveformView.setWaveform(currentPcm);
        }

        btnPlay.setEnabled(true);
        btnOk.setEnabled(true);
        label.setText("Fichier prêt.");
        
        
    }

    /**
     * Retire la composante continue et normalise le signal
     * au plus près du max sans saturer (marge de 5%).
     */
    private void normalize(short[] pcm) {
        if (pcm == null || pcm.length == 0) return;

        // 1) Moyenne (DC)
        double sum = 0.0;
        for (short s : pcm) {
            sum += s;
        }
        double mean = sum / pcm.length;

        // 2) Recherche du max après retrait de la moyenne
        double maxAbs = 0.0;
        for (short s : pcm) {
            double v = s - mean;
            double a = Math.abs(v);
            if (a > maxAbs) maxAbs = a;
        }
        if (maxAbs < 1.0) {
            // signal trop faible ou nul, on évite des gains monstrueux
            return;
        }

        // 3) Gain pour aller frôler la saturation (95% du max)
        double gain = 0.95 * 32767.0 / maxAbs;

        for (int i = 0; i < pcm.length; i++) {
            double v = (pcm[i] - mean) * gain;
            if (v > 32767.0) v = 32767.0;
            if (v < -32768.0) v = -32768.0;
            pcm[i] = (short) Math.round(v);
        }
    }
/**
     * Coupe les silences au début et à la fin selon trimThreshold (0..1).
     * Met à jour le WAV et l’oscilloscope.
     */
    private void trimCurrentPcm() {
        if (currentPcm == null || currentPcm.length == 0) {
            label.setText("Rien à trimmer.");
            return;
        }

        double th = trimThreshold;
        if (th < 0.0) th = 0.0;
        if (th > 1.0) th = 1.0;

        int threshold = (int) Math.round(th * 32767.0);

        int n = currentPcm.length;
        int start = 0;
        int end   = n - 1;

        // Cherche premier échantillon au-dessus du seuil
        while (start < n) {
            int a = Math.abs(currentPcm[start]);
            if (a >= threshold) break;
            start++;
        }

        // Cherche dernier échantillon au-dessus du seuil
        while (end >= 0) {
            int a = Math.abs(currentPcm[end]);
            if (a >= threshold) break;
            end--;
        }

        if (start >= end) {
            // tout est en dessous du seuil : on garde tel quel
            label.setText("Signal trop faible pour trim.");
            return;
        }

        int newLen = end - start + 1;
        short[] trimmed = new short[newLen];
        System.arraycopy(currentPcm, start, trimmed, 0, newLen);
        currentPcm = trimmed;

        // Réécriture du fichier WAV
        saveWav(currentPcm);

        // Mise à jour visuelle
        if (waveformView != null) {
            waveformView.setWaveform(currentPcm);
        }

        label.setText("Trim OK (" + newLen + " échantillons).");
    }

    /**
     * Applique normalize() sur currentPcm, resauvegarde le WAV,
     * met à jour l’oscilloscope.
     */
    private void normalizeCurrentPcm() {
        if (currentPcm == null || currentPcm.length == 0) {
            label.setText("Rien à normaliser.");
            return;
        }

        normalize(currentPcm);
        saveWav(currentPcm);

        if (waveformView != null) {
            waveformView.setWaveform(currentPcm);
        }

        label.setText("Normalize OK.");
    }
    private void saveWav(short[] pcm) {
        try {
            outputFile = new File(activity.getFilesDir(), name + ".wav");
            BufferedOutputStream out =
                    new BufferedOutputStream(new FileOutputStream(outputFile));

            int dataLen = pcm.length * 2;
            int sampleRate = SAMPLE_RATE;
            int channels = 1;
            int byteRate = sampleRate * channels * 2;

            // RIFF header
            out.write(new byte[]{ 'R','I','F','F' });
            writeInt(out, 36 + dataLen);
            out.write(new byte[]{ 'W','A','V','E','f','m','t',' ' });
            writeInt(out, 16); // PCM chunk
            writeShort(out, (short) 1); // PCM
            writeShort(out, (short) channels);
            writeInt(out, sampleRate);
            writeInt(out, byteRate);
            writeShort(out, (short) (channels * 2));
            writeShort(out, (short) 16); // bits
            out.write(new byte[]{ 'd','a','t','a' });
            writeInt(out, dataLen);

            for (short s : pcm) {
                writeShort(out, s);
            }
            out.close();
        } catch (IOException ignored) {}
    }

    private void writeInt(OutputStream out, int v) throws IOException {
        out.write(v & 0xFF);
        out.write((v >> 8) & 0xFF);
        out.write((v >> 16) & 0xFF);
        out.write((v >> 24) & 0xFF);
    }

    private void writeShort(OutputStream out, short v) throws IOException {
        out.write(v & 0xFF);
        out.write((v >> 8) & 0xFF);
    }

    private void togglePlay() {
        if (outputFile == null) return;

        if (mediaPlayer != null && mediaPlayer.isPlaying()) {
            mediaPlayer.stop();
            mediaPlayer.release();
            mediaPlayer = null;
            btnPlay.setText("Play");
            return;
        }

        try {
            mediaPlayer = new MediaPlayer();
            mediaPlayer.setDataSource(outputFile.getPath());
            mediaPlayer.prepare();
            mediaPlayer.start();
            btnPlay.setText("Stop");
            mediaPlayer.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
                @Override public void onCompletion(MediaPlayer mp) {
                    btnPlay.setText("Play");
                }
            });
        } catch (IOException e) {
            label.setText("Erreur lecture.");
        }
    }

    private void confirm() {
        if (callback != null && outputFile != null) {
            callback.onSampleReady(outputFile);
        }
        if (dialog != null) {
            dialog.dismiss();
        }
    }
    private int dpToPx(int dp) {
        float d = activity.getResources().getDisplayMetrics().density;
        return (int) (dp * d + 0.5f);
    }
    /**
     * Petite vue d’oscilloscope : trace la forme d'onde normalisée
     * à partir d'un tableau de short[].
     */
    private static class WaveformView extends View {

        private float[] samples = null; // valeurs dans [-1, 1]
        private final Paint linePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint bgPaint   = new Paint(Paint.ANTI_ALIAS_FLAG);

        public WaveformView(Context context) {
            super(context);
            init();
        }

        public WaveformView(Context context, AttributeSet attrs) {
            super(context, attrs);
            init();
        }

        private void init() {
            bgPaint.setColor(Color.BLACK);
            bgPaint.setStyle(Paint.Style.FILL);

            linePaint.setColor(Color.GREEN);
            linePaint.setStyle(Paint.Style.STROKE);
            linePaint.setStrokeWidth(2f);
        }

        /**
         * Fournit un buffer PCM 16 bits, qu'on convertit en
         * tableau flottant [-1,1] avec décimation pour ne pas surcharger le dessin.
         */
        public void setWaveform(short[] pcm) {
            if (pcm == null || pcm.length == 0) {
                samples = null;
                invalidate();
                return;
            }

            int maxPoints = 1000; // on ne dessine pas plus de 1000 points
            int len = pcm.length;
            if (len <= maxPoints) {
                samples = new float[len];
                for (int i = 0; i < len; i++) {
                    samples[i] = pcm[i] / 32768f;
                }
            } else {
                samples = new float[maxPoints];
                double step = len / (double) maxPoints;
                for (int i = 0; i < maxPoints; i++) {
                    int idx = (int) Math.round(i * step);
                    if (idx < 0) idx = 0;
                    if (idx >= len) idx = len - 1;
                    samples[i] = pcm[idx] / 32768f;
                }
            }
            invalidate();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);

            int w = getWidth();
            int h = getHeight();

            canvas.drawRect(0, 0, w, h, bgPaint);

            if (samples == null || samples.length < 2) return;

            float midY = h / 2f;
            float scaleY = (h * 0.45f); // marge en haut/bas

            int n = samples.length;
            float dx = (w - 1f) / (float) (n - 1);

            float prevX = 0f;
            float prevY = midY - samples[0] * scaleY;

            for (int i = 1; i < n; i++) {
                float x = i * dx;
                float y = midY - samples[i] * scaleY;
                canvas.drawLine(prevX, prevY, x, y, linePaint);
                prevX = x;
                prevY = y;
            }
        }
    }
    
}
