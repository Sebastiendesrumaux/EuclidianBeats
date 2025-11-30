package com.example.appdummy;

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

    private AlertDialog dialog;
    private Button btnRec;
    private Button btnStop;
    private Button btnPlay;
    private Button btnOk;
    private TextView label;

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
        normalize(pcm);
        saveWav(pcm);

        btnPlay.setEnabled(true);
        btnOk.setEnabled(true);
        label.setText("Fichier prêt.");
    }

    private void normalize(short[] pcm) {
        int max = 1;
        for (short s : pcm) {
            int a = Math.abs(s);
            if (a > max) max = a;
        }
        double gain = 0.9 * 32767.0 / max;
        for (int i = 0; i < pcm.length; i++) {
            double x = pcm[i] * gain;
            if (x > 32767) x = 32767;
            if (x < -32768) x = -32768;
            pcm[i] = (short) x;
        }
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
}
