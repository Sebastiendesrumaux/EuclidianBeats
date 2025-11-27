#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "▶️ Mise à jour de SoundEngine (La / Do / Mi / Sol par cercle)…"

cat > app/src/main/java/com/example/appdummy/SoundEngine.java << 'JAVAEOF'
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
 * Les méthodes utilisées par l'appli :
 *  - playKick()
 *  - playSnare()
 *  - playHatOpen()
 *  - playHatClosed()
 */
public class SoundEngine {

    private enum Waveform { KICK, SNARE, HAT_OPEN, HAT_CLOSED }

    private final int sampleRate;
    private final AudioTrack kickTrack;
    private final AudioTrack snareTrack;
    private final AudioTrack hatOpenTrack;
    private final AudioTrack hatClosedTrack;

    public SoundEngine(int sampleRateHz) {
        this.sampleRate = sampleRateHz;

        // Durées et enveloppes adaptées aux percussions
        short[] kickBuf      = synthBuffer(Waveform.KICK,       80.0,   180,  2, 150);
        short[] snareBuf     = synthBuffer(Waveform.SNARE,    2000.0,   140,  1, 120);
        short[] hatOpenBuf   = synthBuffer(Waveform.HAT_OPEN,  8000.0,  120,  1, 100);
        short[] hatClosedBuf = synthBuffer(Waveform.HAT_CLOSED,8000.0,   60,  1,  40);

        kickTrack      = makeStaticTrack(kickBuf);
        snareTrack     = makeStaticTrack(snareBuf);
        hatOpenTrack   = makeStaticTrack(hatOpenBuf);
        hatClosedTrack = makeStaticTrack(hatClosedBuf);
    }

    public void playKick()      { playOnce(kickTrack); }
    public void playSnare()     { playOnce(snareTrack); }
    public void playHatOpen()   { playOnce(hatOpenTrack); }
    public void playHatClosed() { playOnce(hatClosedTrack); }

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

    /**
     * Synthèse d'un buffer percussif avec une note mélangée :
     * - KICK       → basse + LA
     * - SNARE      → bruit + DO
     * - HAT_OPEN   → bruit + MI
     * - HAT_CLOSED → bruit court + SOL
     */
    private short[] synthBuffer(Waveform wf,
                                double baseFreqHz,
                                int durMs,
                                int attackMs,
                                int decayMs) {

        int n = (int) Math.round(durMs * sampleRate / 1000.0);
        if (n < 1) n = 1;

        double twoPiBase = 2.0 * Math.PI * baseFreqHz / sampleRate;

        // Fréquences des notes (octave choisie pour être bien audible)
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
            // enveloppe
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
                case KICK: {
                    // grave + note LA + un peu de bruit
                    double toneLow  = Math.sin(twoPiBase * i);   // ~80 Hz
                    double toneNote = Math.sin(twoPiNote * i);   // 440 Hz
                    double noise    = (Math.random() * 2.0 - 1.0);
                    x = 0.65 * toneLow + 0.25 * toneNote + 0.10 * noise;
                    break;
                }
                case SNARE: {
                    // bruit + DO
                    double noise    = (Math.random() * 2.0 - 1.0);
                    double toneNote = Math.sin(twoPiNote * i);
                    x = 0.75 * noise + 0.25 * toneNote;
                    break;
                }
                case HAT_OPEN: {
                    // bruit aigu + MI
                    double noise    = (Math.random() * 2.0 - 1.0);
                    double toneNote = Math.sin(twoPiNote * i);
                    x = 0.7 * noise + 0.3 * toneNote;
                    break;
                }
                case HAT_CLOSED: {
                    // petit clic + SOL
                    double noise    = (Math.random() * 2.0 - 1.0);
                    double toneNote = Math.sin(twoPiNote * i);
                    x = 0.6 * noise + 0.4 * toneNote;
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

echo "✅ SoundEngine mis à jour (La/Do/Mi/Sol intégrés)."
