/* kavis-settings entry point (madde 9).
 *
 * One window, Windows 11 Settings layout. Shares the common GTK
 * startup (GDK_GL=disable, gettext) with every other kavis binary.
 */

int main (string[] args) {
    Kavis.AppInit.init ();
    /* Test hook (A3): print the picom config this build would write and
     * exit, so tools/check-picom.sh can feed it to the real compositor.
     * A broken rule here costs the whole desktop its compositor, and
     * the bug only shows in a VM — this is the cheap way to catch it.
     * Usage: kavis-settings --print-picom <radius> <factor> <style> <edge>
     */
    if (args.length > 1 && args[1] == "--print-picom") {
        print ("%s", Kavis.Settings.Apply.picom_config (
            args.length > 2 ? int.parse (args[2]) : 8,
            args.length > 3 ? int.parse (args[3]) : 100,
            args.length > 4 ? args[4] : "slide",
            args.length > 5 ? args[5] : "bottom"));
        return 0;
    }
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
