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
        window = new Kavis.Tools.EmojiWindow ();
        break;
    case "capture":
        /* PrtScr akışı kendi ana döngüsünü yönetir: seçici pencere,
         * ardından pano bekleyişi ya da kayıt çubuğu. */
        if (args.length > 2 && args[2] == "--quick") {
            return Kavis.Tools.Capture.quick ();
        }
        return Kavis.Tools.Capture.snip ();
    case "tasks":
        window = new Kavis.Tools.TaskManagerWindow ();
        break;
    default:
        stderr.printf ("kullanim: kavis-tools [tasks|calc|emoji|capture]\n");
        return 2;
    }
    window.destroy.connect (Gtk.main_quit);
    window.show_all ();
    Gtk.main ();
    return 0;
}
