/* kavis-taskmanager entry point (feedback G1).
 *
 * The task manager used to be `kavis-tools tasks`. It is a full
 * application — four pages, its own icon, its own taskbar identity —
 * so it now lives in its own package and its own binary. No
 * subcommands: the .desktop entry, the panel menu, the Ctrl+Alt+Del
 * screen and Ctrl+Shift+Esc all run plain `kavis-taskmanager`.
 */

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);
    /* Palette (B2): component CSS takes the @kavis_* names from here. */
    Kavis.Theme.install ();

    var window = new Kavis.TaskManager.TaskManagerWindow ();
    window.destroy.connect (Gtk.main_quit);
    window.show_all ();
    Gtk.main ();
    return 0;
}
