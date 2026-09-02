/* kavis-panel entry point.
 *
 * Normal mode starts the taskbar. `--metin-denetimi` runs the string
 * table self-check without touching the display — CI uses it to catch
 * an inconsistent table in seconds instead of after a 40-minute ISO
 * build. (The flag itself is Turkish on purpose: command-line flags are
 * user-facing surface, identifiers in code are English.)
 */

int main (string[] args) {
    /* Locale first: the TR/EN choice in Strings reads it. */
    Intl.setlocale (LocaleCategory.ALL, "");

    if (args.length > 1 && args[1] == "--metin-denetimi") {
        return Kavis.Strings.self_check () == 0 ? 0 : 1;
    }

    /* Shared startup for all kavis GTK apps (madde 61): GDK_GL=disable
     * and whatever future traps accumulate — the rationale lives in
     * packages/kavis-common/appinit.vala (canonical copy). */
    Kavis.AppInit.init ();

    Gtk.init (ref args);

    var panel = new Kavis.Ui.Panel ();
    panel.show_all ();
    panel.refresh_windows ();
    Gtk.main ();
    return 0;
}
