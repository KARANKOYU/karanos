/* Pinned taskbar apps (business logic — no widget code).
 * Sonraki-isler bölüm 2.
 *
 * Storage: ~/.config/kavis/pinned.conf — one .desktop id per line,
 * order = taskbar order. Missing file falls back to the default set
 * (ids that are not installed are simply not drawn; they stay in the
 * list so the icon appears the day the app arrives — kavis-settings
 * and the store ship in later groups).
 */

namespace Kavis.Pinned {

    private const string[] DEFAULTS = {
        "nemo.desktop",            /* dosya yöneticisi (madde 39) */
        "firefox-esr.desktop",
        "com.gexperts.Tilix.desktop", /* terminal (madde 40: tilix) */
        "kavis-settings.desktop",  /* Grup F'de gelecek — o güne dek gizli */
        "kavis-store.desktop",     /* Grup G'de gelecek — o güne dek gizli */
    };

    private string config_path () {
        return Path.build_filename (
            Environment.get_user_config_dir (), "kavis", "pinned.conf");
    }

    public string[] load () {
        string contents;
        try {
            FileUtils.get_contents (config_path (), out contents);
        } catch (Error e) {
            return DEFAULTS;
        }
        string[] result = {};
        foreach (unowned string line in contents.split ("\n")) {
            string id = line.strip ();
            if (id != "" && !id.has_prefix ("#")) {
                result += id;
            }
        }
        return result;
    }

    public void save (string[] ids) {
        string path = config_path ();
        DirUtils.create_with_parents (Path.get_dirname (path), 0755);
        try {
            FileUtils.set_contents (path,
                string.joinv ("\n", ids) + "\n");
        } catch (Error e) {
            warning ("kavis-panel: pinned.conf yazilamadi: %s", e.message);
        }
    }

    public bool contains (string id) {
        foreach (unowned string known in load ()) {
            if (known == id) {
                return true;
            }
        }
        return false;
    }

    public void add (string id) {
        if (contains (id)) {
            return;
        }
        string[] ids = load ();
        ids += id;
        save (ids);
    }

    public void remove (string id) {
        string[] result = {};
        foreach (unowned string known in load ()) {
            if (known != id) {
                result += known;
            }
        }
        save (result);
    }

    /* Reorder: move `id` so it sits before `before` (or to the end
     * when `before` is null). Used by drag-and-drop. */
    public void move_before (string id, string? before) {
        string[] result = {};
        foreach (unowned string known in load ()) {
            if (known == id) {
                continue;
            }
            if (before != null && known == before) {
                result += id;
            }
            result += known;
        }
        if (before == null || !(id in result)) {
            result += id;
        }
        save (result);
    }
}
