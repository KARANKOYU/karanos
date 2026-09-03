/* Keyboard layout (business logic — no widget code here).
 *
 * Talks to setxkbmap (x11-xkb-utils, a panel dependency). 2F decision:
 * ONE GLOBAL layout, NO per-window group. Source priority order:
 * kavis.conf [keyboard] layout/variant → /etc/default/keyboard
 * XKBLAYOUT/XKBVARIANT → "tr". The X server may reset the layout to
 * ITS OWN default when the keyboard is re-plugged (the virtual
 * keyboard in a VM does this) — the indicator calls enforce() on every
 * poll to pull it back to the configured layout.
 *
 * F4: the user can collect several layouts in Settings; they are kept
 * in [keyboard] layouts as a comma separated id list ("tr,us(dvorak)")
 * and the panel indicator's right-click menu switches between exactly
 * those — never the whole 590 entry catalogue.
 */

namespace Kavis.Keyboard {

    /* How many entries the right-click menu keeps; older ones drop off
     * so the menu stays a menu. */
    private const int HISTORY_MAX = 8;

    /* Current layout code ("tr", "us", ...). Failure falls back to
     * "tr" — the product default. */
    public string current_layout () {
        string layout, variant;
        split_current (out layout, out variant);
        return layout;
    }

    /* Current layout WITH its variant, as an Xkb id ("us(dvorak)"). */
    public string current_id () {
        string layout, variant;
        split_current (out layout, out variant);
        return Xkb.make_id (layout, variant);
    }

    private void split_current (out string layout, out string variant) {
        layout = "tr";
        variant = "";
        string output;
        try {
            Process.spawn_sync (null,
                { "setxkbmap", "-query" }, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, out output, null, null);
        } catch (SpawnError e) {
            return;
        }
        foreach (unowned string line in output.split ("\n")) {
            if (line.has_prefix ("layout:")) {
                layout = line.substring (7).strip ().split (",")[0];
            } else if (line.has_prefix ("variant:")) {
                variant = line.substring (8).strip ().split (",")[0];
            }
        }
    }

    /* The layout the USER chose (not what X happens to run). */
    public string configured_layout () {
        string layout, variant;
        Xkb.split_id (configured_id (), out layout, out variant);
        return layout;
    }

    /* The chosen layout as an Xkb id. */
    public string configured_id () {
        try {
            var file = Config.load ();
            string layout = file.get_string ("keyboard", "layout");
            if (layout != "") {
                string variant = "";
                try {
                    variant = file.get_string ("keyboard", "variant");
                } catch (Error e) { }
                return Xkb.make_id (layout, variant);
            }
        } catch (Error e) { }
        try {
            string contents;
            FileUtils.get_contents ("/etc/default/keyboard",
                                    out contents);
            string layout = "";
            string variant = "";
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix ("XKBLAYOUT=")) {
                    layout = line.substring (10)
                        .replace ("\"", "").strip ().split (",")[0];
                } else if (line.has_prefix ("XKBVARIANT=")) {
                    variant = line.substring (11)
                        .replace ("\"", "").strip ().split (",")[0];
                }
            }
            if (layout != "") {
                return Xkb.make_id (layout, variant);
            }
        } catch (Error e) { }
        return "tr";
    }

    /* The layouts offered by the indicator's right-click menu: the ones
     * Settings has collected in kavis.conf, plus the configured and the
     * running one so the menu is never empty and always shows a mark. */
    public string[] menu_ids () {
        string[] ids = {};
        string history = "";
        try {
            history = Config.load ().get_string ("keyboard", "layouts");
        } catch (Error e) { }
        foreach (unowned string raw in history.split (",")) {
            string id = raw.strip ();
            if (id != "" && !contains (ids, id)
                && ids.length < HISTORY_MAX) {
                ids += id;
            }
        }
        string configured = configured_id ();
        if (!contains (ids, configured)) {
            ids += configured;
        }
        string running = current_id ();
        if (!contains (ids, running)) {
            ids += running;
        }
        return ids;
    }

    private bool contains (string[] ids, string id) {
        foreach (unowned string existing in ids) {
            if (existing == id) {
                return true;
            }
        }
        return false;
    }

    /* If X's layout drifted from the configured one, pull it back (2F:
     * X may return to its own default when the keyboard is re-plugged). */
    public void enforce () {
        string wanted = configured_id ();
        if (current_id () != wanted) {
            apply (wanted);
        }
    }

    /* Switch to the given layout id, persist it (kavis.conf) and apply.
     * Fire-and-forget: the indicator re-reads right after. */
    public void set_layout (string id) {
        string layout, variant;
        Xkb.split_id (id, out layout, out variant);
        var file = Config.load ();
        file.set_string ("keyboard", "layout", layout);
        file.set_string ("keyboard", "variant", variant);
        Config.save (file);
        apply (id);
    }

    private void apply (string id) {
        string layout, variant;
        Xkb.split_id (id, out layout, out variant);
        try {
            /* -option "": clears any leftover group/toggle options —
             * the single global layout rule. */
            string[] argv = { "setxkbmap", "-layout", layout };
            if (variant != "") {
                argv += "-variant";
                argv += variant;
            }
            argv += "-option";
            argv += "";
            Process.spawn_async (null, argv, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, null);
        } catch (SpawnError e) {
            warning ("kavis-panel: could not run setxkbmap: %s", e.message);
        }
    }
}
