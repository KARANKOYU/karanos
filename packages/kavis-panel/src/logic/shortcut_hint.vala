/* The key a taskbar button answers to (feedback, 8 Sep 2026).
 *
 * "Hovering a button should say what it does" — and half of what a
 * button does is which key does the same thing. Windows puts the
 * shortcut in the tooltip for exactly that reason: it is how people
 * find out the keyboard can do it.
 *
 * The keys are READ FROM THE CATALOGUE, not typed here. Item 74 moved
 * the bindings into /usr/share/kavis/shortcuts.list precisely because
 * a second copy of them drifts — the Settings list had said
 * Ctrl+Win+arrows for two rounds while the hook bound Ctrl+Alt+arrows.
 * A tooltip that names the wrong key is the same bug with a smaller
 * blast radius, so it comes from the same file. Reassignments the user
 * has made live in kavis.conf and win over the catalogue default,
 * which is the same order set-shortcuts applies them in.
 *
 * The file is read once, on the first question.
 */

namespace Kavis.ShortcutHint {

    private static HashTable<string, string>? keys = null;

    private const string CATALOG = "/usr/share/kavis/shortcuts.list";

    private void load () {
        keys = new HashTable<string, string> (str_hash, str_equal);
        string contents;
        try {
            FileUtils.get_contents (
                Environment.get_variable ("KAVIS_SHORTCUT_CATALOG")
                    ?? CATALOG, out contents);
        } catch (Error e) {
            return;   /* no catalogue: tooltips simply carry no key */
        }
        foreach (unowned string raw in contents.split ("\n")) {
            string line = raw.strip ();
            if (line == "" || line.has_prefix ("#")) {
                continue;
            }
            string[] fields = line.split ("|");
            if (fields.length != 4) {
                continue;
            }
            keys.insert (fields[0].strip (), fields[2].strip ());
        }
        /* The user's own reassignments, from the same file Settings
         * writes and set-shortcuts reads. */
        var conf = Kavis.Config.load ();
        try {
            foreach (unowned string id in conf.get_keys ("shortcuts")) {
                string key = conf.get_string ("shortcuts", id).strip ();
                if (key != "") {
                    keys.insert (id, key);
                }
            }
        } catch (Error e) {
            /* No [shortcuts] group: nothing has been reassigned. */
        }
    }

    /* openbox notation -> what a person reads. "W-S-s" -> "Win+Shift+S" */
    private string display (string binding) {
        var parts = binding.split ("-");
        var out = new StringBuilder ();
        for (int i = 0; i < parts.length; i++) {
            if (out.len > 0) {
                out.append_c ('+');
            }
            if (i < parts.length - 1) {
                switch (parts[i]) {
                case "W": out.append ("Win"); break;
                case "C": out.append ("Ctrl"); break;
                case "A": out.append ("Alt"); break;
                case "S": out.append ("Shift"); break;
                default:  out.append (parts[i]); break;
                }
            } else if (parts[i].length == 1) {
                out.append (parts[i].up ());
            } else if (parts[i] == "period") {
                out.append (".");
            } else {
                out.append (parts[i]);
            }
        }
        return out.str;
    }

    /* "Show desktop" + show-desktop -> "Show desktop (Win+D)".
     *
     * A shortcut that cannot be expressed as a key a person can press —
     * a media key on a keyboard that may not have one — is left out
     * rather than shown as XF86AudioPlay, which answers nothing. */
    public string with_key (string text, string id) {
        if (keys == null) {
            load ();
        }
        string? binding = keys.lookup (id);
        if (binding == null || binding.contains ("XF86")) {
            return text;
        }
        return "%s (%s)".printf (text, display (binding));
    }
}
