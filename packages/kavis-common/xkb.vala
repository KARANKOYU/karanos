/* Keyboard layout catalogue (shared logic — no widget code here).
 *
 * The FULL xkeyboard-config list (every layout AND every variant:
 * AZERTY, QWERTZ, Dvorak, Colemak, ...) is read at RUNTIME from
 * xkb-data's own /usr/share/X11/xkb/rules/base.lst — decision 7. The
 * file is never vendored: an xkb-data upgrade brings new layouts with
 * it and nothing here has to change.
 *
 * ONE GLOBAL layout, no per-window groups (decision 2F): an entry is a
 * layout plus an optional variant, written to kavis.conf as the
 * [keyboard] layout/variant pair and applied with setxkbmap. The id
 * used in lists and in the [keyboard] layouts history is xkb's own
 * notation: "us" or "us(dvorak)".
 */

namespace Kavis.Xkb {

    public struct Entry {
        public string id;           /* "us" / "us(dvorak)"       */
        public string layout;       /* "us"                      */
        public string variant;      /* "" / "dvorak"             */
        public string description;  /* "English (Dvorak)"        */
    }

    private const string RULES = "/usr/share/X11/xkb/rules/base.lst";

    private Entry[] cache;
    private bool loaded = false;

    /* "us" + "dvorak" -> "us(dvorak)". */
    public string make_id (string layout, string variant) {
        if (variant == "") {
            return layout;
        }
        return "%s(%s)".printf (layout, variant);
    }

    /* The inverse of make_id. */
    public void split_id (string id, out string layout,
                          out string variant) {
        int open = id.index_of_char ('(');
        if (open < 0) {
            layout = id;
            variant = "";
            return;
        }
        layout = id.substring (0, open);
        variant = id.substring (open + 1).replace (")", "").strip ();
    }

    /* Every layout, each immediately followed by its own variants —
     * base.lst is already sorted by description, so this keeps the
     * xkeyboard-config order the user sees in every other desktop. */
    public unowned Entry[] list () {
        if (!loaded) {
            loaded = true;
            cache = parse ();
        }
        return cache;
    }

    /* Human readable name for an id; the id itself when the catalogue
     * does not know it (a hand-edited kavis.conf, or xkb-data missing). */
    public string describe (string id) {
        foreach (unowned Entry entry in list ()) {
            if (entry.id == id) {
                return entry.description;
            }
        }
        return id;
    }

    private Entry[] parse () {
        Entry[] result = {};
        string contents;
        try {
            FileUtils.get_contents (RULES, out contents);
        } catch (Error e) {
            /* xkb-data is a package dependency, so this only happens on
             * a broken install: the caller falls back to the configured
             * layout alone. */
            warning ("kavis: cannot read %s: %s", RULES, e.message);
            return result;
        }

        Entry[] layouts = {};
        Entry[] variants = {};
        string section = "";
        foreach (unowned string raw in contents.split ("\n")) {
            if (raw.has_prefix ("!")) {
                section = raw.substring (1).strip ();
                continue;
            }
            if (section != "layout" && section != "variant") {
                continue;
            }
            string line = raw.strip ();
            if (line == "") {
                continue;
            }
            /* "  us              English (US)" and
             * "  dvorak          us: English (Dvorak)" */
            int cut = 0;
            while (cut < line.length && !line[cut].isspace ()) {
                cut++;
            }
            if (cut >= line.length) {
                continue;
            }
            string name = line.substring (0, cut);
            string rest = line.substring (cut).strip ();
            if (rest == "") {
                continue;
            }
            if (section == "layout") {
                Entry entry = { name, name, "", rest };
                layouts += entry;
            } else {
                int colon = rest.index_of (": ");
                if (colon < 0) {
                    continue;
                }
                string parent = rest.substring (0, colon).strip ();
                string desc = rest.substring (colon + 2).strip ();
                /* The variant description in base.lst already names the
                 * language ("French (AZERTY)"), so it is shown as-is;
                 * the parent layout is visible in the id column. */
                Entry entry = {
                    make_id (parent, name), parent, name, desc
                };
                variants += entry;
            }
        }

        foreach (unowned Entry layout in layouts) {
            result += layout;
            foreach (unowned Entry variant in variants) {
                if (variant.layout == layout.layout) {
                    result += variant;
                }
            }
        }
        return result;
    }
}
