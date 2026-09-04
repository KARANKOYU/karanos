/* "Emoji and more" panel stores (business logic — no widget code).
 * Sonraki-isler section 5: recent (mixed last 30 across tabs), starred
 * items, and user snippets.
 *
 * recent / starred: one item per line under ~/.config/kavis/
 * (picker-recent, picker-starred). Snippets: KeyFile
 * ~/.config/kavis/snippets.conf, one group per snippet ([1], [2]…)
 * with a `text` key — multi-line survives KeyFile escaping.
 */

namespace Kavis.PickerStore {

    /* Feedback item I: 30 was one short row of the new 8-column grid;
     * 64 fills the "Recently used" tab without turning it into a
     * second emoji table. */
    private const int RECENT_LIMIT = 64;

    private string config_file (string name) {
        return Path.build_filename (
            Environment.get_user_config_dir (), "kavis", name);
    }

    private string[] read_lines (string name) {
        string contents;
        try {
            FileUtils.get_contents (config_file (name), out contents);
        } catch (Error e) {
            return {};
        }
        string[] result = {};
        foreach (unowned string line in contents.split ("\n")) {
            if (line.strip () != "") {
                result += line;
            }
        }
        return result;
    }

    private void write_lines (string name, string[] lines) {
        string path = config_file (name);
        DirUtils.create_with_parents (Path.get_dirname (path), 0755);
        try {
            FileUtils.set_contents (path,
                string.joinv ("\n", lines) + "\n");
        } catch (Error e) {
            warning ("kavis-panel: could not write %s: %s", name, e.message);
        }
    }

    /* --- recently used (mixed across tabs) --------------------------- */

    /* Feedback item I: the list moved into kavis.conf ([picker] recent)
     * so the picker keeps all of its state in the one settings file the
     * Settings app edits. The old picker-recent file is imported once
     * and then left alone as a backup. */
    public string[] recent () {
        var file = Config.load ();
        try {
            return file.get_string_list ("picker", "recent");
        } catch (Error e) {
            string[] old = read_lines ("picker-recent");
            if (old.length > 0) {
                write_recent (old);
            }
            return old;
        }
    }

    private void write_recent (string[] items) {
        var file = Config.load ();
        file.set_string_list ("picker", "recent", items);
        Config.save (file);
    }

    public void remember (string item) {
        string[] updated = { item };
        foreach (unowned string old in recent ()) {
            if (old != item && updated.length < RECENT_LIMIT) {
                updated += old;
            }
        }
        write_recent (updated);
    }

    /* --- favorites (starred) ----------------------------------------- */

    public string[] starred () {
        return read_lines ("picker-starred");
    }

    public bool is_starred (string item) {
        foreach (unowned string known in starred ()) {
            if (known == item) {
                return true;
            }
        }
        return false;
    }

    public void toggle_star (string item) {
        if (is_starred (item)) {
            string[] result = {};
            foreach (unowned string known in starred ()) {
                if (known != item) {
                    result += known;
                }
            }
            write_lines ("picker-starred", result);
        } else {
            string[] result = starred ();
            result += item;
            write_lines ("picker-starred", result);
        }
    }

    /* --- short texts (snippets) -------------------------------------- */

    public struct Snippet {
        public string id;
        public string text;
    }

    private string snippets_path () {
        return config_file ("snippets.conf");
    }

    public Snippet[] snippets () {
        Snippet[] result = {};
        var file = new KeyFile ();
        try {
            file.load_from_file (snippets_path (), KeyFileFlags.NONE);
        } catch (Error e) {
            return result;
        }
        foreach (unowned string group in file.get_groups ()) {
            try {
                Snippet snippet = {
                    group, file.get_string (group, "text")
                };
                result += snippet;
            } catch (Error e) { }
        }
        return result;
    }

    private void save_snippets (Snippet[] all) {
        var file = new KeyFile ();
        foreach (unowned Snippet snippet in all) {
            file.set_string (snippet.id, "text", snippet.text);
        }
        string path = snippets_path ();
        DirUtils.create_with_parents (Path.get_dirname (path), 0755);
        try {
            FileUtils.set_contents (path, file.to_data ());
            FileUtils.chmod (path, 0600);   /* may be sensitive, e.g. IBAN */
        } catch (Error e) {
            warning ("kavis-panel: could not write snippets.conf: %s",
                     e.message);
        }
    }

    public void add_snippet (string text) {
        var all = snippets ();
        int max_id = 0;
        foreach (unowned Snippet snippet in all) {
            max_id = int.max (max_id, int.parse (snippet.id));
        }
        Snippet fresh = { "%d".printf (max_id + 1), text };
        all += fresh;
        save_snippets (all);
    }

    public void update_snippet (string id, string text) {
        var all = snippets ();
        for (int i = 0; i < all.length; i++) {
            if (all[i].id == id) {
                all[i].text = text;
            }
        }
        save_snippets (all);
    }

    public void delete_snippet (string id) {
        Snippet[] result = {};
        foreach (unowned Snippet snippet in snippets ()) {
            if (snippet.id != id) {
                result += snippet;
            }
        }
        save_snippets (result);
    }
}
