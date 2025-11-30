package com.example.appdummy;

import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

/**
 * SpatialSamplePlayer :
 *  - charge un WAV (via Sound3DEngine)
 *  - applique une spatialisation 3D (pan/tilt/radius)
 *  - met en cache les AudioTracks stéréo déjà calculés
 *  - joue immédiatement et proprement chaque version
 */
public class SpatialSamplePlayer {

    private final Sound3DEngine engine;
    private final int sampleRate;

    // Cache : clé spatio → AudioTrack prêt-à-jouer
    private final Map<String, AudioTrack> trackCache = new HashMap<>();

    public SpatialSamplePlayer(File wavFile) throws Exception {
        this.engine = new Sound3DEngine(wavFile);
        this.sampleRate = engine.getSampleRate();
    }

    /**
     * Lecture avec spatialisation angulaire + tilt + distance.
     * Les versions déjà calculées sont rejouées directement.
     */
    public void play(double panDeg, double tiltDeg, double radius) {
        String key = makeKey(panDeg, tiltDeg, radius);

        AudioTrack track = trackCache.get(key);
        if (track == null) {
            // Pas encore calculé → spatialisation + création AudioTrack
            short[] stereo = engine.apply(panDeg, tiltDeg, radius);
            track = buildTrack(stereo);
            trackCache.put(key, track);
        }

        playOnce(track);
    }

    /**
     * Libère tous les AudioTracks en cache.
     */
    public void release() {
        for (AudioTrack t : trackCache.values()) {
            try { t.release(); } catch (Exception ignored) {}
        }
        trackCache.clear();
    }

    // -------------------------------------------------------------
    // --- Implémentation interne ---
    // -------------------------------------------------------------

    private String makeKey(double panDeg, double tiltDeg, double radius) {
        int panQ  = (int) Math.round(panDeg);
        int tiltQ = (int) Math.round(tiltDeg);
        double radiusQ = Math.round(radius * 100.0) / 100.0;
        return panQ + "_" + tiltQ + "_" + radiusQ;
    }

    private AudioTrack buildTrack(short[] stereo) {

        int bufferBytes = stereo.length * 2;

        AudioAttributes attrs = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build();

        AudioFormat format = new AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                .build();

        AudioTrack track = new AudioTrack(
                attrs,
                format,
                bufferBytes,
                AudioTrack.MODE_STATIC,
                AudioManager.AUDIO_SESSION_ID_GENERATE
        );

        track.write(stereo, 0, stereo.length);
        return track;
    }

    /**
     * Lecture courte et robuste (comme dans ton SoundEngine).
     */
    private void playOnce(AudioTrack t) {
        if (t == null) return;
        if (t.getState() != AudioTrack.STATE_INITIALIZED) return;
        try {
            t.pause();
            t.flush();
            t.setPlaybackHeadPosition(0);
            t.play();
        } catch (IllegalStateException ignored) {}
    }
}