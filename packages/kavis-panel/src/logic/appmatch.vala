/* Window ↔ .desktop matching (business logic — no widget code).
 * Sonraki-isler section 2 — "the hard part of the job".
 *
 * A lookup table is built ONCE (not per window event): for every
 * desktop entry, these keys map to its id, first writer wins in this
 * priority order:
 *   1. /etc/kavis/wmclass-map.conf manual overrides (Electron/Java/
 *      Wine report inconsistent classes; the table is the fix)
 *   2. StartupWMClass
 *   3. desktop file basename (without .desktop)
 *   4. first word of Exec (basename)
 * Windows are looked up by WM_CLASS group and instance names.
 * No match → the caller shows a plain unpinned button.
 */

namespace Kavis.AppMatch {

    private HashTable<string, string>? table = null;

    private void learn (string? key, string id) {
        if (key == null) {
            return;
        }
        string normalized = key.strip ().down ();
        if (normalized != "" && table.lookup (normalized) == null) {
            table.insert (normalized, id);
        }
    }

    private void build () {
        table = new HashTable<string, string> (str_hash, str_equal);

        /* 1. manual mapping file: one "wmclass=desktop-id" per line. */
        string contents;
        try {
            FileUtils.get_contents ("/etc/kavis/wmclass-map.conf",
                                    out contents);
            foreach (unowned string line in contents.split ("\n")) {
                string trimmed = line.strip ();
                if (trimmed == "" || trimmed.has_prefix ("#")) {
                    continue;
                }
                int eq = trimmed.index_of ("=");
                if (eq > 0) {
                    learn (trimmed.substring (0, eq),
                           trimmed.substring (eq + 1).strip ());
                }
            }
        } catch (Error e) {
            /* a missing file is fine */
        }

        /* 2-4. installed .desktop entries. */
        foreach (AppInfo info in AppInfo.get_all ()) {
            var desktop = info as DesktopAppInfo;
            if (desktop == null) {
                continue;
            }
            string id = desktop.get_id () ?? "";
            if (id == "") {
                continue;
            }
            learn (desktop.get_startup_wm_class (), id);
            if (id.has_suffix (".desktop")) {
                learn (id.substring (0, id.length - 8), id);
            }
            string exec = desktop.get_string ("Exec") ?? "";
            if (exec != "") {
                learn (Path.get_basename (exec.split (" ")[0]), id);
            }
        }
    }

    /* The .desktop id for a window, or null when nothing matches. */
    public string? desktop_id_for_window (Wnck.Window window) {
        if (table == null) {
            build ();
        }
        unowned string? group = window.get_class_group_name ();
        if (group != null) {
            string? hit = table.lookup (group.down ());
            if (hit != null) {
                return hit;
            }
        }
        unowned string? instance = window.get_class_instance_name ();
        if (instance != null) {
            return table.lookup (instance.down ());
        }
        return null;
    }

    public DesktopAppInfo? info_for (string id) {
        return new DesktopAppInfo (id);
    }
}
