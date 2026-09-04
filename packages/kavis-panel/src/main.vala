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
    /* Night light schedule (F-Display): one process applies it, and
     * the panel is the one that is always running. Settings and the
     * quick toggle only write kavis.conf. */
    Kavis.NightLight.start ();
    /* Item 51: the two things that have to keep watching — what the
     * machine does when nobody touches it, and what happens when the
     * battery runs down. Both read kavis.conf; Settings only writes. */
    Kavis.IdleWatch.start (() => Kavis.Battery.on_ac ());
    /* Item 70: logind's Lock signal — `loginctl lock-session` and the
     * lid, when Settings > Power says the lid locks. */
    Kavis.LockWatch.start ();
    Kavis.BatteryWarning.start ();
    Gtk.main ();
    return 0;
}
