package com.example.appdummy;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * Charge un fichier WAV 16-bit PCM (mono ou stéréo),
 * le convertit en mono interne,
 * puis génère une onde stéréo "placée" dans l'espace
 * selon un pan (azimut), un tilt (élévation) et un rayon.
 *
 * Convention :
 *  - panDeg  : -90° (plein gauche) à +90° (plein droite)
 *  - tiltDeg : -90° (en dessous) à +90° (au-dessus)
 *  - radius  : 1.0 = proche, >1.0 = plus loin (atténué)
 *
 * apply(...) retourne un tableau short[] stéréo INTERLEAVÉ :
 *   [L0, R0, L1, R1, L2, R2, ...]
 */
public class Sound3DEngine {

    private final Map<String, short[]> cache = new HashMap<>();
    private short[] monoPcm;   // buffer mono interne (16-bit)
    private int sampleRate;    // tiré du WAV

    public Sound3DEngine(String path) throws IOException {
        this(new File(path));
    }

    public Sound3DEngine(File wavFile) throws IOException {
        loadWavAsMono(wavFile);
    }

    /**
     * Applique une spatialisation simple (ILD + ITD + distance + EQ tilt)
     * et retourne un buffer stéréo intercalé.
     */
    public short[] apply(double panDeg, double tiltDeg, double radius) {
        if (monoPcm == null || monoPcm.length == 0) {
            return new short[0];
        }

        // Quantification pour éviter une infinité de clés
        int panQ  = (int) Math.round(panDeg);
        int tiltQ = (int) Math.round(tiltDeg);
        double radiusQ = Math.round(radius * 100.0) / 100.0; // précision 1 cm

        String key = panQ + "_" + tiltQ + "_" + radiusQ;

        // --- CACHE : retourne immédiatement si déjà calculé ---
        short[] cached = cache.get(key);
        if (cached != null) {
            return cached;
        }

        // --- Sinon : on calcule pour de vrai ---
        short[] stereo = computeSpatialized(panDeg, tiltDeg, radius);

        // On le range dans le cache
        cache.put(key, stereo);

        return stereo;
    }

    public int getSampleRate() {
        return sampleRate;
    }

    // -------------------------------------------------
    // Cœur DSP : spatialisation + tilt EQ
    // -------------------------------------------------

    /**
     * Applique une égalisation simple en fonction du tilt :
     *   tilt > 0  => plus d'aigus, un peu moins de graves (source au-dessus)
     *   tilt < 0  => plus de graves, un peu moins d'aigus (source en dessous)
     *
     * inOut : buffer mono -1..+1 (float)
     */
    private void applyTiltEq(float[] inOut, double tiltDeg) {
        if (inOut == null || inOut.length == 0) return;

        // On borne le tilt à [-60°, +60°] pour éviter les extrêmes
        double t = Math.max(-60.0, Math.min(60.0, tiltDeg));
        double tNorm = t / 60.0; // -1 .. +1

        // Coeff du low-pass : plus petit => filtre plus "lent" (coupure plus basse)
        double alpha = 0.06; // à ajuster si tu veux (0.03 = plus grave, 0.1 = plus brillant)

        float low = 0f;

        for (int i = 0; i < inOut.length; i++) {
            float x = inOut[i];

            // Low-pass 1er ordre très simple
            low = (float)(low + alpha * (x - low));
            float high = x - low;

            double lowGain;
            double highGain;

            if (tNorm >= 0.0) {
                // Au-dessus : on rend le son plus brillant
                lowGain  = 1.0 - 0.4 * tNorm;  // à +60° => 0.6
                highGain = 1.0 + 1.0 * tNorm;  // à +60° => 2.0
            } else {
                // En dessous : on rend le son plus sombre, plus "bas"
                double u = -tNorm;             // 0..1
                lowGain  = 1.0 + 1.0 * u;      // à -60° => 2.0
                highGain = 1.0 - 0.6 * u;      // à -60° => 0.4
            }

            double y = lowGain * low + highGain * high;

            // Limitation douce
            if (y >  1.0) y =  1.0;
            if (y < -1.0) y = -1.0;

            inOut[i] = (float)y;
        }
    }

    /**
     * Spatialisation complète : EQ tilt + ILD + ITD + distance.
     */
    private short[] computeSpatialized(double panDeg, double tiltDeg, double radius) {
        if (monoPcm == null || monoPcm.length == 0) {
            return new short[0];
        }

        int monoLen = monoPcm.length;

        // --- 1) On part d'une copie float normalisée -1..+1 ---
        float[] work = new float[monoLen];
        for (int i = 0; i < monoLen; i++) {
            work[i] = monoPcm[i] / 32768f;
        }

        // --- 2) EQ dépendante du tilt (haut/bas) ---
        applyTiltEq(work, tiltDeg);

        // --- 3) Paramètres de pan (azimut) ---
        // On borne le pan entre -90° et +90°
        double pan = Math.max(-90.0, Math.min(90.0, panDeg));
        double panRad = Math.toRadians(pan);
        // x ~ [-1, 1], -1 = gauche, +1 = droite
        double x = Math.sin(panRad);

        // ILD simple : on bias les gains gauche/droite, puis on renormalise.
        double gL = 1.0 - 0.5 * x;
        double gR = 1.0 + 0.5 * x;
        double maxG = Math.max(gL, gR);
        if (maxG < 1e-6) maxG = 1.0;
        gL /= maxG;
        gR /= maxG;

        // --- 4) Distance : atténuation douce ---
        if (radius < 0.1) radius = 0.1;
        double distanceGain = 1.0 / (1.0 + 0.5 * (radius - 1.0));
        if (distanceGain < 0.05) distanceGain = 0.05;

        // On garde un petit tiltFactor global très subtil
        double tilt = Math.max(-90.0, Math.min(90.0, tiltDeg));
        double tiltRad = Math.toRadians(tilt);
        double tiltFactor = 0.9 + 0.1 * Math.cos(tiltRad); // effet très léger
        double globalGain = distanceGain * tiltFactor;

        // --- 5) ITD : petit décalage temporel entre les oreilles ---
        // max ~0.7 ms => ~31 samples à 44.1 kHz
        int maxDelaySamples = (int) Math.round(0.0007 * sampleRate);
        int delaySamples = (int) Math.round(maxDelaySamples * x);

        int delayLeft  = (delaySamples > 0) ? 0 : -delaySamples;
        int delayRight = (delaySamples > 0) ? delaySamples : 0;

        int outLen = monoLen + Math.max(delayLeft, delayRight);
        short[] stereo = new short[outLen * 2]; // L,R interleavés

        for (int i = 0; i < monoLen; i++) {
            int idxL = i + delayLeft;
            int idxR = i + delayRight;
            if (idxL < 0 || idxL >= outLen) continue;
            if (idxR < 0 || idxR >= outLen) continue;

            // On repart de work[i] (-1..+1), EQ tilt déjà appliquée
            double base = work[i] * globalGain;

            double sampleL = base * gL;
            double sampleR = base * gR;

            int sL = (int) Math.round(sampleL * 32767.0);
            int sR = (int) Math.round(sampleR * 32767.0);

            if (sL > Short.MAX_VALUE) sL = Short.MAX_VALUE;
            if (sL < Short.MIN_VALUE) sL = Short.MIN_VALUE;
            if (sR > Short.MAX_VALUE) sR = Short.MAX_VALUE;
            if (sR < Short.MIN_VALUE) sR = Short.MIN_VALUE;

            int posL = 2 * idxL;
            int posR = 2 * idxR + 1;

            int accL = stereo[posL] + sL;
            int accR = stereo[posR] + sR;

            if (accL > Short.MAX_VALUE) accL = Short.MAX_VALUE;
            if (accL < Short.MIN_VALUE) accL = Short.MIN_VALUE;
            if (accR > Short.MAX_VALUE) accR = Short.MAX_VALUE;
            if (accR < Short.MIN_VALUE) accR = Short.MIN_VALUE;

            stereo[posL] = (short) accL;
            stereo[posR] = (short) accR;
        }

        return stereo;
    }

    // -------------------------------------------------
    // Lecture WAV -> mono 16-bit PCM
    // -------------------------------------------------
    private void loadWavAsMono(File file) throws IOException {
        FileInputStream in = new FileInputStream(file);
        try {
            byte[] header = new byte[44];
            if (in.read(header, 0, 44) != 44) {
                throw new IOException("WAV header too short");
            }

            // Vérif minimale "RIFF" / "WAVE"
            if (header[0] != 'R' || header[1] != 'I' ||
                header[2] != 'F' || header[3] != 'F') {
                throw new IOException("Not a RIFF file");
            }
            if (header[8] != 'W' || header[9] != 'A' ||
                header[10] != 'V' || header[11] != 'E') {
                throw new IOException("Not a WAVE file");
            }

            // On suppose un header PCM 16-bit "classique"
            int audioFormat = littleEndianShort(header, 20) & 0xFFFF;
            int numChannels = littleEndianShort(header, 22) & 0xFFFF;
            sampleRate      = littleEndianInt(header, 24);
            int bitsPerSample = littleEndianShort(header, 34) & 0xFFFF;

            if (audioFormat != 1) {
                throw new IOException("Only PCM WAV supported (format=" + audioFormat + ")");
            }
            if (bitsPerSample != 16) {
                throw new IOException("Only 16-bit WAV supported (bits=" + bitsPerSample + ")");
            }
            if (numChannels < 1 || numChannels > 2) {
                throw new IOException("Only mono or stereo WAV supported (channels=" + numChannels + ")");
            }

            // Chunk "data" à l'offset 36 (header standard)
            int dataSize;
            if (header[36] == 'd' && header[37] == 'a' &&
                header[38] == 't' && header[39] == 'a') {
                dataSize = littleEndianInt(header, 40);
            } else {
                throw new IOException("Unsupported WAV header (no 'data' at offset 36)");
            }

            byte[] data = new byte[dataSize];
            int read = 0;
            while (read < dataSize) {
                int r = in.read(data, read, dataSize - read);
                if (r <= 0) break;
                read += r;
            }
            if (read < dataSize) {
                throw new IOException("Could not read full WAV data");
            }

            int totalFrames = dataSize / (2 * numChannels);
            monoPcm = new short[totalFrames];

            int idx = 0;
            if (numChannels == 1) {
                // Mono direct
                for (int i = 0; i < totalFrames; i++) {
                    int b0 = data[idx] & 0xFF;
                    int b1 = data[idx + 1];
                    short s = (short) (b0 | (b1 << 8));
                    monoPcm[i] = s;
                    idx += 2;
                }
            } else {
                // Stéréo -> moyenne des deux canaux
                for (int i = 0; i < totalFrames; i++) {
                    int b0L = data[idx] & 0xFF;
                    int b1L = data[idx + 1];
                    int b0R = data[idx + 2] & 0xFF;
                    int b1R = data[idx + 3];

                    short sL = (short) (b0L | (b1L << 8));
                    short sR = (short) (b0R | (b1R << 8));

                    int m = (sL + sR) / 2;
                    if (m > Short.MAX_VALUE) m = Short.MAX_VALUE;
                    if (m < Short.MIN_VALUE) m = Short.MIN_VALUE;

                    monoPcm[i] = (short) m;
                    idx += 4;
                }
            }

        } finally {
            in.close();
        }
    }

    private static int littleEndianInt(byte[] b, int offset) {
        return (b[offset] & 0xFF) |
               ((b[offset + 1] & 0xFF) << 8) |
               ((b[offset + 2] & 0xFF) << 16) |
               ((b[offset + 3] & 0xFF) << 24);
    }

    private static short littleEndianShort(byte[] b, int offset) {
        return (short) ((b[offset] & 0xFF) | (b[offset + 1] << 8));
    }
}