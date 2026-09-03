/* Keyboard layout (business logic — no widget code here).
 *
 * Talks to setxkbmap (x11-xkb-utils, a panel dependency). 2F decision:
 * ONE GLOBAL layout, NO per-window group. Source priority order:
 * kavis.conf [keyboard] layout → /etc/default/keyboard XKBLAYOUT →
 * "tr". The X server may reset the layout to ITS OWN default when the
 * keyboard is re-plugged (the virtual keyboard in a VM does this) — the
 * indicator calls enforce() on every poll to pull it back to the
 * configured layout.
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

    /* The layout the USER chose (not what X happens to run). */
    public string configured_layout () {
        try {
            return Config.load ().get_string ("keyboard", "layout");
        } catch (Error e) { }
        try {
            string contents;
            FileUtils.get_contents ("/etc/default/keyboard",
                                    out contents);
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix ("XKBLAYOUT=")) {
                    string value = line.substring (10)
                        .replace ("\"", "").strip ();
                    if (value != "") {
                        return value.split (",")[0];
                    }
                }
            }
        } catch (Error e) { }
        return "tr";
    }

    /* If X's layout drifted from the configured one, pull it back (2F:
     * X may return to its own default when the keyboard is re-plugged). */
    public void enforce () {
        string wanted = configured_layout ();
        if (current_layout () != wanted) {
            apply (wanted);
        }
    }

    /* Switch to the given layout code, persist it (kavis.conf) and
     * apply. Fire-and-forget: the indicator re-reads right after. */
    public void set_layout (string layout) {
        var file = Config.load ();
        file.set_string ("keyboard", "layout", layout);
        Config.save (file);
        apply (layout);
    }

    private void apply (string layout) {
        try {
            /* -option "": clears any leftover group/toggle options —
             * the single global layout rule. */
            Process.spawn_async (null,
                { "setxkbmap", "-layout", layout, "-option", "" },
                null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, null);
        } catch (SpawnError e) {
            warning ("kavis-panel: could not run setxkbmap: %s", e.message);
        }
    }
}
