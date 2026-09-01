/* Keyboard layout (business logic — no widget code here).
 *
 * Talks to setxkbmap (x11-xkb-utils, a panel dependency). With several
 * layouts configured the first listed is reported, not necessarily the
 * active XKB group; reading the active group needs an XKB call and is
 * fixed together with the settings app (item 10/34).
 */

namespace Kavis.Keyboard {

    /* Current layout code ("tr", "us", ...). Failure falls back to
     * "tr" — the product default. */
    public string current_layout () {
        string output;
        try {
            Process.spawn_sync (null,
                { "setxkbmap", "-query" }, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, out output, null, null);
        } catch (SpawnError e) {
            return "tr";
        }
        foreach (unowned string line in output.split ("\n")) {
            if (line.has_prefix ("layout:")) {
                var value = line.substring (7).strip ();
                return value.split (",")[0];
            }
        }
        return "tr";
    }

    /* Switch to the given layout code. Fire-and-forget: the indicator
     * re-reads the layout right after, so a failed spawn simply leaves
     * the display unchanged. */
    public void set_layout (string layout) {
        try {
            Process.spawn_async (null,
                { "setxkbmap", layout }, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, null);
        } catch (SpawnError e) {
            warning ("kavis-panel: setxkbmap calistirilamadi: %s", e.message);
        }
    }
}
