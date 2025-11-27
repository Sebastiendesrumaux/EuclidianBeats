#!/data/data/com.termux/files/usr/bin/bash
set -e

FILE="app/src/main/java/com/example/appdummy/SoundEngine.java"

# On remplace entièrement le corps de playOnce(...) par une version plus sûre
tmp="$(mktemp)"
awk '
/private void playOnce\(AudioTrack t\) {/ {
    print;
    in_method=1;
    depth=0;
    next;
}
in_method {
    # Compte les { } pour savoir quand on sort de la méthode
    depth += gsub(/\{/, "{");
    depth -= gsub(/\}/, "}");
    if (depth <= 0) {
        # On vient de sortir : injecter la nouvelle implémentation et la dernière }
        print "        if (t == null) return;";
        print "        if (t.getState() != AudioTrack.STATE_INITIALIZED) return;";
        print "        try {";
        print "            t.pause();";
        print "            t.flush();";
        print "            t.setPlaybackHeadPosition(0);";
        print "            t.play();";
        print "        } catch (IllegalStateException ignored) {";
        print "            // on ignore ce tick si Android est grognon";
        print "        }";
        print "    }";
        in_method=0;
        next;
    }
    next;
}
{ print }
' "$FILE" > "$tmp"

mv "$tmp" "$FILE"
echo "✅ playOnce() patché dans $FILE"
