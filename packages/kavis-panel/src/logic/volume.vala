/* Master volume (business logic — no widget code here).
 *
 * Backend is amixer from alsa-utils (already on the ISO for the boot
 * sound; also a panel dependency now). ALSA is the lowest common
 * denominator: it works with or without PipeWire/PulseAudio on top,
 * costs no daemon connection, and one spawn per user action is cheap.
 * A richer backend (per-app streams, output switching) belongs to the
 * sound settings page (item 9), not the panel popup.
 */

namespace Kavis.Volume {

    public struct State {
        public int percent;     /* 0-100, -1 when unreadable */
        public bool muted;
    }

    /* Whether a usable mixer control exists; decides if the volume
     * indicator is shown at all. Cached: the sound card does not
     * appear or vanish mid-session. */
    private bool checked = false;
    private bool usable = false;

    public bool available () {
        if (checked) {
            return usable;
        }
        checked = true;
        usable = read ().percent >= 0;
        return usable;
    }

    /* Read volume and mute state ("[57%]" / "[on]" tokens of
     * `amixer -M get Master`). */
    public State read () {
        State state = { -1, false };
        string output;
        try {
            Process.spawn_sync (null,
                { "amixer", "-M", "get", "Master" }, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, out output, null, null);
        } catch (SpawnError e) {
            return state;
        }
        int start = output.index_of ("[");
        while (start >= 0) {
            int end = output.index_of ("]", start);
            if (end < 0) {
                break;
            }
            var token = output.substring (start + 1, end - start - 1);
            if (token.has_suffix ("%")) {
                state.percent = int.parse (token.substring (0, token.length - 1));
            } else if (token == "off") {
                state.muted = true;
            } else if (token == "on") {
                state.muted = false;
            }
            start = output.index_of ("[", end);
        }
        return state;
    }

    public void set_percent (int percent) {
        spawn ({ "amixer", "-M", "-q", "set", "Master",
                 "%d%%".printf (percent.clamp (0, 100)), "unmute" });
    }

    public void toggle_mute () {
        spawn ({ "amixer", "-q", "set", "Master", "toggle" });
    }

    private void spawn (string[] argv) {
        try {
            Process.spawn_async (null, argv, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, null);
        } catch (SpawnError e) {
            warning ("kavis-panel: amixer calistirilamadi: %s", e.message);
        }
    }
}
