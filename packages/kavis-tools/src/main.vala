/* kavis-tools entry point (madde 7).
 *
 * One binary, three small tools: `tasks` (task manager), `calc`
 * (calculator), `emoji` (emoji picker). One binary keeps packaging,
 * the shared string table and the GTK startup (madde 61) in one
 * place; each tool is its own window class in its own file.
 */

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);

    string tool = (args.length > 1) ? args[1] : "tasks";
    Gtk.Window window;
    switch (tool) {
    case "calc":
        window = new Kavis.Tools.CalculatorWindow ();
        break;
    case "emoji":
        /* Emoji seçici birleşik panele taşındı (sonraki-isler 5):
         * .desktop girdisi çalışan paneldeki paneli açar. */
        try {
            Process.spawn_sync (null, {
                "gdbus", "call", "--session",
                "--dest", "org.kavis.Panel",
                "--object-path", "/org/kavis/Panel",
                "--method", "org.kavis.Panel.ShowPicker", "emoji"
            }, null, SpawnFlags.SEARCH_PATH
               | SpawnFlags.STDOUT_TO_DEV_NULL, null, null);
        } catch (Error e) {
            warning ("kavis-tools: panele ulasilamadi: %s", e.message);
        }
        return 0;
    case "capture":
        /* PrtScr akışı kendi ana döngüsünü yönetir: seçici pencere,
         * ardından pano bekleyişi ya da kayıt çubuğu. */
        if (args.length > 2 && args[2] == "--quick") {
            return Kavis.Tools.Capture.quick ();
        }
        /* --color: Win+Shift+C — seçici doğrudan renk modunda
         * (sonraki-isler 5c). */
        return Kavis.Tools.Capture.snip (
            args.length > 2 && args[2] == "--color");
    case "secure-menu":
        /* Ctrl+Alt+Del (sonraki-isler 6d) — panelden bağımsız. */
        window = new Kavis.Tools.SecureMenuWindow ();
        break;
    case "open-with":
        /* "Bununla aç" penceresi (sonraki-isler 6c). */
        if (args.length < 3) {
            stderr.printf ("kullanim: kavis-tools open-with <dosya>\n");
            return 2;
        }
        window = new Kavis.Tools.OpenWithWindow (args[2]);
        break;
    case "tasks":
        window = new Kavis.Tools.TaskManagerWindow ();
        break;
    default:
        stderr.printf ("kullanim: kavis-tools [tasks|calc|emoji|capture|open-with|secure-menu]\n");
        return 2;
    }
    window.destroy.connect (Gtk.main_quit);
    window.show_all ();
    Gtk.main ();
    return 0;
}
