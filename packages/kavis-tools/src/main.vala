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
    case "alt-f4":
        /* Masaüstünde Alt+F4 (6e): ÖNCE odaktaki pencere kapatılır;
         * güç diyaloğu YALNIZ odakta pencere yokken açılır. Tuş
         * basılı tutulunca her tekrar yeni süreç — tek örnek kilidi
         * (2B): açıksa mevcut pencere öne gelir, yenisi açılmaz. */
        if (Kavis.Tools.AltF4.close_focused_window ()) {
            return 0;
        }
        if (!Kavis.Tools.SingleInstance.acquire ("kavis-power")) {
            return 0;
        }
        window = new Kavis.Tools.ShutdownDialog ();
        break;
    case "power-dialog":
        /* Aynı diyalog, odak kontrolü olmadan — Ctrl+Alt+Del
         * ekranının güç düğmesi çağırır (2D: tek bileşen). */
        if (!Kavis.Tools.SingleInstance.acquire ("kavis-power")) {
            return 0;
        }
        window = new Kavis.Tools.ShutdownDialog ();
        break;
    case "secure-menu":
        /* Ctrl+Alt+Del (sonraki-isler 6d) — panelden bağımsız.
         * Aynı tek örnek koruması: basılı tutunca üst üste karartma
         * katmanı yığılmasın. */
        if (!Kavis.Tools.SingleInstance.acquire ("kavis-secure")) {
            return 0;
        }
        window = new Kavis.Tools.SecureMenuWindow ();
        break;
    case "open-with":
        /* "Bununla aç" penceresi (sonraki-isler 6c). */
        if (args.length < 3) {
            stderr.printf (_("usage: kavis-tools open-with <file>\n"));
            return 2;
        }
        window = new Kavis.Tools.OpenWithWindow (args[2]);
        break;
    case "repair-drive":
        /* Bağlanamayan USB onarımı (madde 64) — panel bildirimi açar. */
        if (args.length < 3) {
            stderr.printf (_("usage: kavis-tools repair-drive <device>\n"));
            return 2;
        }
        window = new Kavis.Tools.RepairDriveWindow (args[2]);
        break;
    case "preview":
        /* Hızlı önizleme (madde 36): org.nemo.Preview servisi.
         * Dosyasız çağrı D-Bus activation'dan gelir. */
        return Kavis.Tools.Preview.run (
            (args.length > 2) ? args[2] : null);
    case "tasks":
        window = new Kavis.Tools.TaskManagerWindow ();
        break;
    default:
        stderr.printf (_("usage: kavis-tools [tasks|calc|emoji|capture|preview|repair-drive|open-with|secure-menu|alt-f4]\n"));
        return 2;
    }
    window.destroy.connect (Gtk.main_quit);
    window.show_all ();
    Gtk.main ();
    return 0;
}
