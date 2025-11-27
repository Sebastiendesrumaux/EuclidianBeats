package com.example.appdummy;

import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;

/**
 * Moteur sonore :
 * - Bleu  : KICK  + note LA
 * - Orange: SNARE + note DO
 * - Vert  : HAT_OPEN  + note MI
 * - Rose  : HAT_CLOSED+ note SOL
 *
 * Volumes relatifs réglables :
 *   - setDrumGain(0..1)  : intensité des percussions
 *   - setNoteGain(0..1)  : intensité des notes
 */
public class SoundEngine {

    private enum Waveform { KICK, SNARE, HAT_OPEN, HAT_CLOSED }

    private final int sampleRate;

    // gains
    private double drumGain = 1.0;
    private double noteGain = 0.5;

    private AudioTrack kickTrack;
    private AudioTrack snareTrack;
    private AudioTrack hatOpenTrack;
    private AudioTrack hatClosedTrack;

    public SoundEngine(int sampleRateHz) {
        this.sampleRate = sampleRateHz;
        rebuildTracks();
    }

    public void setDrumGain(double gain) {
        drumGain = Math.max(0.0, Math.min(1.0, gain));
        rebuildTracks();
    }

    public void setNoteGain(double gain) {
        noteGain = Math.max(0.0, Math.min(1.0, gain));
        rebuildTracks();
    }

    public void playKick()      { playOnce(kickTrack); }
    public void playSnare()     { playOnce(snareTrack); }
    public void playHatOpen()   { playOnce(hatOpenTrack); }
    public void playHatClosed() { playOnce(hatClosedTrack); }

    public void release() {
        releaseInternal();
    }

    private void rebuildTracks() {
        releaseInternal();

        short[] kickBuf      = synthBuffer(Waveform.KICK,       80.0,   180,  2, 150);
        short[] snareBuf     = synthBuffer(Waveform.SNARE,    2000.0,   140,  1, 120);
        short[] hatOpenBuf   = synthBuffer(Waveform.HAT_OPEN,  8000.0,  120,  1, 100);
        short[] hatClosedBuf = synthBuffer(Waveform.HAT_CLOSED,8000.0,   60,  1,  40);

        kickTrack      = makeStaticTrack(kickBuf);
        snareTrack     = makeStaticTrack(snareBuf);
        hatOpenTrack   = makeStaticTrack(hatOpenBuf);
        hatClosedTrack = makeStaticTrack(hatClosedBuf);
    }

    private void releaseInternal() {
        try { if (kickTrack      != null) { kickTrack.release();      kickTrack = null; } } catch (Throwable ignored) {}
        try { if (snareTrack     != null) { snareTrack.release();     snareTrack = null; } } catch (Throwable ignored) {}
        try { if (hatOpenTrack   != null) { hatOpenTrack.release();   hatOpenTrack = null; } } catch (Throwable ignored) {}
        try { if (hatClosedTrack != null) { hatClosedTrack.release(); hatClosedTrack = null; } } catch (Throwable ignored) {}
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
        if (t == null) return;
        try {
            if (t.getPlayState() == AudioTrack.PLAYSTATE_PLAYING) {
                t.stop();
            }
            t.setPlaybackHeadPosition(0);
            t.play();
        } catch (IllegalStateException ignored) {}
    }

    /**
     * Synthèse d'un buffer percussif + note :
     *   x = drumGain * drum + noteGain * note
     */
    private short[] synthBuffer(Waveform wf,
                                double baseFreqHz,
                                int durMs,
                                int attackMs,
                                int decayMs) {

        int n = (int) Math.round(durMs * sampleRate / 1000.0);
        if (n < 1) n = 1;

        double twoPiBase = 2.0 * Math.PI * baseFreqHz / sampleRate;

        double noteFreqHz;
        switch (wf) {
            case KICK:       noteFreqHz = 440.0;  break; // LA
            case SNARE:      noteFreqHz = 261.63; break; // DO
            case HAT_OPEN:   noteFreqHz = 329.63; break; // MI
            case HAT_CLOSED: noteFreqHz = 392.00; break; // SOL
            default:         noteFreqHz = baseFreqHz;    break;
        }
        double twoPiNote = 2.0 * Math.PI * noteFreqHz / sampleRate;

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

            double toneBase = Math.sin(twoPiBase * i);
            double toneNote = Math.sin(twoPiNote * i);
            double noise    = (Math.random() * 2.0 - 1.0);

            double drum;
            double note;

            switch (wf) {
                case KICK:
                    drum = 0.7 * toneBase + 0.1 * noise;
                    note = 0.3 * toneNote;
                    break;
                case SNARE:
                    drum = 0.8 * noise;
                    note = 0.3 * toneNote;
                    break;
                case HAT_OPEN:
                    drum = 0.8 * noise;
                    note = 0.35 * toneNote;
                    break;
                case HAT_CLOSED:
                    drum = 0.7 * noise;
                    note = 0.4 * toneNote;
                    break;
                default:
                    drum = 0.0;
                    note = 0.0;
            }

            double x = drumGain * drum + noteGain * note;

            double y = env * x;
            int s = (int) Math.round(y * 0.9 * Short.MAX_VALUE);
            if (s > Short.MAX_VALUE) s = Short.MAX_VALUE;
            if (s < Short.MIN_VALUE) s = Short.MIN_VALUE;
            pcm[i] = (short) s;
        }

        return pcm;
    }
}
