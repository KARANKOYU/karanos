/* kavis-tools entry point (madde 7).
 *
 * One binary for the small tools: `calc` (calculator), `emoji` (emoji
 * picker), the capture flow, the previewer and the session dialogs.
 * One binary keeps packaging, the shared string table and the GTK
 * startup (madde 61) in one place; each tool is its own window class
 * in its own file.
 *
 * The task manager left in feedback G1: it is a full application with
 * four pages, so it became the separate kavis-taskmanager binary.
 */

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);
    /* Palette (B2): component CSS takes the @kavis_* names from here. */
    Kavis.Theme.install ();

    /* No default tool since G1: the task manager used to be it, and a
     * bare `kavis-tools` silently opening some other window would be a
     * surprise. Without a subcommand, print the usage line. */
    string tool = (args.length > 1) ? args[1] : "";
    Gtk.Window window;
    switch (tool) {
    case "calc":
        window = new Kavis.Tools.CalculatorWindow ();
        break;
    case "emoji":
        /* The emoji picker moved into the unified panel (sonraki-isler
         * 5): the .desktop entry opens the picker in the running panel. */
        try {
            Process.spawn_sync (null, {
                "gdbus", "call", "--session",
                "--dest", "org.kavis.Panel",
                "--object-path", "/org/kavis/Panel",
                "--method", "org.kavis.Panel.ShowPicker", "emoji"
            }, null, SpawnFlags.SEARCH_PATH
               | SpawnFlags.STDOUT_TO_DEV_NULL, null, null);
        } catch (Error e) {
            warning ("kavis-tools: could not reach the panel: %s", e.message);
        }
        return 0;
    case "capture":
        /* The PrtScr flow runs its own main loop: the selector window,
         * then the clipboard wait or the recording bar. */
        if (args.length > 2 && args[2] == "--quick") {
            return Kavis.Tools.Capture.quick ();
        }
        /* --color: Win+Shift+C — the selector starts directly in color
         * mode (sonraki-isler 5c). */
        return Kavis.Tools.Capture.snip (
            args.length > 2 && args[2] == "--color");
    case "alt-f4":
        /* Alt+F4 on the desktop (6e): the focused window is closed
         * FIRST; the power dialog opens ONLY when no window has focus.
         * Holding the key down spawns a new process per repeat — the
         * single-instance lock (2B): if open, the existing window is
         * raised and no new one opens. */
        if (Kavis.Tools.AltF4.close_focused_window ()) {
            return 0;
        }
        if (!Kavis.Tools.SingleInstance.acquire ("kavis-power")) {
            return 0;
        }
        window = new Kavis.Tools.ShutdownDialog ();
        break;
    case "power-dialog":
        /* The same dialog without the focus check — called by the
         * Ctrl+Alt+Del screen's power button (2D: one component). */
        if (!Kavis.Tools.SingleInstance.acquire ("kavis-power")) {
            return 0;
        }
        window = new Kavis.Tools.ShutdownDialog ();
        break;
    case "secure-menu":
        /* Ctrl+Alt+Del (sonraki-isler 6d) — independent of the panel.
         * The same single-instance guard: holding the keys must not
         * stack dimming layers on top of each other. */
        if (!Kavis.Tools.SingleInstance.acquire ("kavis-secure")) {
            return 0;
        }
        window = new Kavis.Tools.SecureMenuWindow ();
        break;
    case "open-with":
        /* "Open with" window (sonraki-isler 6c). */
        if (args.length < 3) {
            stderr.printf (_("usage: kavis-tools open-with <file>\n"));
            return 2;
        }
        window = new Kavis.Tools.OpenWithWindow (args[2]);
        break;
    case "repair-drive":
        /* Repair of a USB drive that fails to mount (madde 64) — the
         * panel notification opens it. */
        if (args.length < 3) {
            stderr.printf (_("usage: kavis-tools repair-drive <device>\n"));
            return 2;
        }
        window = new Kavis.Tools.RepairDriveWindow (args[2]);
        break;
    case "preview":
        /* Quick preview (madde 36): the org.nemo.Preview service. A call
         * without a file comes from D-Bus activation. */
        return Kavis.Tools.Preview.run (
            (args.length > 2) ? args[2] : null);
    default:
        stderr.printf (_("usage: kavis-tools [calc|emoji|capture|preview|repair-drive|open-with|secure-menu|alt-f4]\n"));
        return 2;
    }
    window.destroy.connect (Gtk.main_quit);
    window.show_all ();
    Gtk.main ();
    return 0;
}
