/* Product identity: name, version and logo of the running system
 * (business logic — no widget code here).
 *
 * The product name is NEVER hard-coded anywhere in the codebase. The
 * single source of truth is /etc/os-release (installed by kavis-theme);
 * this module is the only reader. If the product is renamed again, only
 * os-release and the files under assets/logo/ change.
 *
 * The one allowed constant is the fallback used when os-release is
 * missing or unreadable (broken live overlay, tests on a foreign
 * machine).
 */

namespace Kavis.Brand {

    private const string FALLBACK_NAME = "Kavis";

    /* Logos are installed by kavis-theme. File names match assets/logo/
     * in the repository on purpose: one identity, two renditions. The
     * env override exists for tools/panel-screenshot.sh, which unpacks
     * the .deb into a temporary root instead of installing it. */
    private const string LOGO_DIR = "/usr/share/kavis/logo";
    private const string LOGO_DARK = "koyu-k-logo.svg";
    private const string LOGO_LIGHT = "acik-k-logo.svg";

    private HashTable<string, string>? info = null;

    /* Parse os-release into a table (quotes stripped). A missing file
     * is reported once and leaves the table empty; callers fall back to
     * defaults instead of failing. */
    private unowned HashTable<string, string> read_os_release () {
        if (info != null) {
            return info;
        }
        info = new HashTable<string, string> (str_hash, str_equal);
        string? content = null;
        foreach (unowned string path in new string[] {
                     "/etc/os-release", "/usr/lib/os-release" }) {
            try {
                FileUtils.get_contents (path, out content);
                break;
            } catch (FileError e) {
                content = null;
            }
        }
        if (content == null) {
            warning ("kavis-panel: os-release okunamadi, varsayilan ad kullaniliyor");
            return info;
        }
        foreach (unowned string raw_line in content.split ("\n")) {
            string line = raw_line.strip ();
            if (line.length == 0 || line.has_prefix ("#")) {
                continue;
            }
            int eq = line.index_of_char ('=');
            if (eq < 1) {
                continue;
            }
            string value = line.substring (eq + 1).strip ();
            if (value.length >= 2 && value.has_prefix ("\"")
                && value.has_suffix ("\"")) {
                value = value.substring (1, value.length - 2);
            }
            info.insert (line.substring (0, eq), value);
        }
        return info;
    }

    /* Product display name (os-release NAME). */
    public string product_name () {
        return read_os_release ().lookup ("NAME") ?? FALLBACK_NAME;
    }

    /* Product name with version (os-release PRETTY_NAME). */
    public string product_name_versioned () {
        return read_os_release ().lookup ("PRETTY_NAME") ?? FALLBACK_NAME;
    }

    /* Whether the active GTK theme is dark. Kavis ships dark-only
     * today, so the answer is normally true; the check still reads the
     * live GTK settings so the light logo is picked up automatically if
     * a light theme ever becomes selectable. True when in doubt — dark
     * is the product default. */
    private bool is_dark_theme () {
        /* B2: tek kaynak kavis.conf (Theme.is_light). Eski GTK ayarı
         * sorgusu prefer-dark hep açık olduğundan hiç açık demiyordu. */
        return !Theme.is_light ();
    }

    /* Repaint an existing logo image for the current theme (the start
     * button keeps its widget across a live theme switch). */
    public void refresh_logo (Gtk.Image image, int size) {
        string path = logo_path ();
        try {
            var pixbuf = new Gdk.Pixbuf.from_file_at_size (path, size, size);
            image.set_from_pixbuf (pixbuf);
        } catch (Error e) {
            image.set_from_icon_name ("kavis", Gtk.IconSize.LARGE_TOOLBAR);
        }
    }

    /* Path of the logo matching the active theme (task item 1: boot
     * splash and GRUB always use the dark logo; the start button and
     * about dialogs — this helper — follow the theme). */
    public string logo_path () {
        unowned string dir =
            Environment.get_variable ("KAVIS_LOGO_DIZIN") ?? LOGO_DIR;
        unowned string file = is_dark_theme () ? LOGO_DARK : LOGO_LIGHT;
        return Path.build_filename (dir, file);
    }

    /* Gtk.Image with the theme-appropriate logo at the given pixel
     * size. Falls back to the icon-theme lookup ("kavis", provided by
     * kavis-theme) when the SVG cannot be loaded, so the panel still
     * shows a logo instead of a broken-image placeholder. */
    public Gtk.Image logo_image (int size) {
        string path = logo_path ();
        try {
            var pixbuf = new Gdk.Pixbuf.from_file_at_size (path, size, size);
            return new Gtk.Image.from_pixbuf (pixbuf);
        } catch (Error e) {
            warning ("kavis-panel: logo yuklenemedi (%s): %s", path, e.message);
            return new Gtk.Image.from_icon_name ("kavis",
                                                 Gtk.IconSize.LARGE_TOOLBAR);
        }
    }
}
