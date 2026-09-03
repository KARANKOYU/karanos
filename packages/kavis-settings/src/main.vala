/* kavis-settings entry point (madde 9).
 *
 * One window, Windows 11 Settings layout. Shares the common GTK
 * startup (GDK_GL=disable, gettext) with every other kavis binary.
 */

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);
    /* Palette (B2): component CSS takes the @kavis_* names from here. */
    Kavis.Theme.install ();

    var window = new Kavis.Settings.Window ();
    window.destroy.connect (Gtk.main_quit);
    window.show_all ();

    /* Deep link: `kavis-settings display` opens that section (the
     * quick-settings "›" rows and search will use this). */
    if (args.length > 1) {
        window.open_section (args[1]);
    }

    Gtk.main ();
    return 0;
}
