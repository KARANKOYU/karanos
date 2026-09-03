/* kavis-panel entry point.
 *
 * UI texts go through gettext (domain "kavis", Grup D task c); the
 * old in-binary string table and its `--metin-denetimi` self-check
 * are gone — CI validates po/ with msgfmt/msgcmp instead.
 */

int main (string[] args) {
    /* Shared startup for all kavis GTK apps (madde 61): locale +
     * gettext + GDK_GL=disable — rationale in
     * packages/kavis-common/appinit.vala (canonical copy). */
    Kavis.AppInit.init ();

    Gtk.init (ref args);
    /* Palette (B2): component CSS takes the @kavis_* names from here. */
    Kavis.Theme.install ();

    var panel = new Kavis.Ui.Panel ();
    panel.show_all ();
    panel.refresh_windows ();
    Gtk.main ();
    return 0;
}
