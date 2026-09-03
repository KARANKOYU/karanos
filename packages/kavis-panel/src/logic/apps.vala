/* Installed application list and search (business logic — no widget
 * code here).
 *
 * Source: XDG desktop entries via GLib.AppInfo. We do not write our own
 * .desktop parser — GLib already applies the language, NoDisplay,
 * OnlyShowIn and TryExec rules correctly.
 */

namespace Kavis.Apps {

    /* Start-menu groups (3B simplification): only three — everyday apps,
     * system tools, and our own utilities. The nine-way XDG split
     * scattered a dozen apps into near-empty groups. */
    public const string[] CATEGORY_ORDER = {
        "Apps", "System", "Kavis",
    };

    /* Group display name. "Kavis" carries the product name — which is
     * NEVER hard-coded (brand rule) — so this is a function, not a
     * const table. */
    public string category_display (string key) {
        switch (key) {
        case "Apps":   return _("Apps");
        case "System": return _("System");
        case "Kavis":  return _("%s tools").printf (
            Brand.product_name ());
        }
        return _("Apps");
    }

    public class App : Object {
        public AppInfo app_info;
        public string name;
        public string description;
        public string category;
        private string search_text;

        public App (AppInfo app_info) {
            this.app_info = app_info;
            this.name = app_info.get_display_name ()
                ?? (app_info.get_name () ?? "");
            this.description = app_info.get_description () ?? "";
            this.category = pick_category (app_info);

            var parts = new StringBuilder ();
            parts.append (this.name).append (" ").append (this.description);
            var desktop = app_info as GLib.DesktopAppInfo;
            if (desktop != null) {
                foreach (unowned string k in desktop.get_keywords ()) {
                    parts.append (" ").append (k);
                }
            }
            parts.append (" ").append (app_info.get_id () ?? "");
            this.search_text = parts.str.down ();
        }

        public bool matches (string query) {
            return query in search_text;
        }

        /* May throw; the caller decides how to report launch failures
         * to the user (errors are never swallowed silently). */
        public void launch () throws Error {
            app_info.launch (null, null);
        }
    }

    private string pick_category (AppInfo app_info) {
        var desktop = app_info as GLib.DesktopAppInfo;
        string id = (desktop != null) ? (desktop.get_id () ?? "") : "";
        if (id.has_prefix ("kavis-")) {
            return "Kavis";
        }
        /* F2: tool-like apps whose category is Utility go to System
         * (Disk Usage Analyzer, Document Scanner). */
        if (id == "org.gnome.baobab.desktop"
            || id == "simple-scan.desktop"
            || id == "org.gnome.SimpleScan.desktop") {
            return "System";
        }
        string raw = (desktop != null)
            ? (desktop.get_categories () ?? "") : "";
        foreach (unowned string c in raw.split (";")) {
            if (c == "System" || c == "Settings"
                || c == "TerminalEmulator") {
                return "System";
            }
        }
        return "Apps";
    }

    /* Apps to show in the menu, sorted by name. should_show() applies
     * NoDisplay and OnlyShowIn; a hand-rolled filter would leak entries
     * meant for other desktop environments. */
    public GenericArray<App> all_apps () {
        var list = new GenericArray<App> ();
        foreach (AppInfo a in AppInfo.get_all ()) {
            if (a.should_show ()) {
                list.add (new App (a));
            }
        }
        list.sort ((a, b) => a.name.collate (b.name));
        return list;
    }

    /* Search. Name-prefix matches come first: typing "fi" must rank
     * Firefox above a random tool that merely contains "fi". */
    public GenericArray<App> search (GenericArray<App> apps,
                                     string? raw_query) {
        string query = (raw_query ?? "").strip ().down ();
        if (query.length == 0) {
            return apps;
        }
        var prefix_hits = new GenericArray<App> ();
        var contains_hits = new GenericArray<App> ();
        for (int i = 0; i < apps.length; i++) {
            var app = apps[i];
            if (app.name.down ().has_prefix (query)) {
                prefix_hits.add (app);
            } else if (app.matches (query)) {
                contains_hits.add (app);
            }
        }
        for (int i = 0; i < contains_hits.length; i++) {
            prefix_hits.add (contains_hits[i]);
        }
        return prefix_hits;
    }


    public struct CategoryGroup {
        public unowned string category;
        public GenericArray<App> apps;
    }

    /* Group by category, in CATEGORY_ORDER order. Empty categories
     * are omitted ("Other" is gone — the three groups cover everything). */
    public CategoryGroup[] by_category (GenericArray<App> list) {
        var buckets = new HashTable<string, GenericArray<App>> (
            str_hash, str_equal);
        for (int i = 0; i < list.length; i++) {
            var app = list[i];
            var bucket = buckets.lookup (app.category);
            if (bucket == null) {
                bucket = new GenericArray<App> ();
                buckets.insert (app.category, bucket);
            }
            bucket.add (app);
        }
        CategoryGroup[] ordered = {};
        foreach (unowned string key in CATEGORY_ORDER) {
            var bucket = buckets.lookup (key);
            if (bucket != null) {
                ordered += CategoryGroup () { category = key, apps = bucket };
            }
        }
        return ordered;
    }
}
