/* Installed application list and search (business logic — no widget
 * code here).
 *
 * Source: XDG desktop entries via GLib.AppInfo. We do not write our own
 * .desktop parser — GLib already applies the language, NoDisplay,
 * OnlyShowIn and TryExec rules correctly.
 */

namespace Kavis.Apps {

    /* Start-menu category order. Keys are XDG main categories, ordered
     * by everyday usage (daily apps on top, system tools at the
     * bottom), not like Windows' alphabetical "All apps". */
    public const string[] CATEGORY_ORDER = {
        "Network", "Office", "AudioVideo", "Graphics", "Development",
        "Game", "Utility", "System", "Settings",
    };

    private struct CategoryName {
        public unowned string key;
        public unowned string tr;
        public unowned string en;
    }

    /* Category display names are not in docs/kavis-arayuz-metinleri.md
     * (store categories are a separate list); XDG's own names are
     * shown. Will be merged with store categories in item 12. */
    private const CategoryName[] CATEGORY_NAMES = {
        { "Network",     "İnternet",     "Internet" },
        { "Office",      "Ofis",         "Office" },
        { "AudioVideo",  "Ses ve Video", "Sound & Video" },
        { "Graphics",    "Grafik",       "Graphics" },
        { "Development", "Geliştirme",   "Development" },
        { "Game",        "Oyun",         "Games" },
        { "Utility",     "Araçlar",      "Accessories" },
        { "System",      "Sistem",       "System" },
        { "Settings",    "Ayarlar",      "Settings" },
        { "Other",       "Diğer",        "Other" },
    };

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
        string raw = "";
        var desktop = app_info as GLib.DesktopAppInfo;
        if (desktop != null) {
            raw = desktop.get_categories () ?? "";
        }
        var owned_categories = raw.split (";");
        foreach (unowned string key in CATEGORY_ORDER) {
            foreach (unowned string c in owned_categories) {
                if (c == key) {
                    return key;
                }
            }
        }
        return "Other";
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

    /* Display name of a category, consistent with the UI language. */
    public unowned string category_display_name (string category) {
        foreach (unowned CategoryName cn in CATEGORY_NAMES) {
            if (cn.key == category) {
                return Strings.is_turkish () ? cn.tr : cn.en;
            }
        }
        return category;
    }

    public struct CategoryGroup {
        public unowned string category;
        public GenericArray<App> apps;
    }

    /* Group by category, in CATEGORY_ORDER order ("Other" last).
     * Empty categories are omitted. */
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
        var other = buckets.lookup ("Other");
        if (other != null) {
            ordered += CategoryGroup () { category = "Other", apps = other };
        }
        return ordered;
    }
}
