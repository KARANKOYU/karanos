/* Keyboard layout (business logic — no widget code here).
 *
 * Talks to setxkbmap (x11-xkb-utils, a panel dependency). 2F kararı:
 * TEK GLOBAL düzen, pencere başına grup YOK. Kaynak öncelik sırası:
 * kavis.conf [keyboard] layout → /etc/default/keyboard XKBLAYOUT →
 * "tr". X sunucusu klavye yeniden takılınca (VM'de sanal klavye bunu
 * yapar) düzeni KENDİ varsayılanına sıfırlayabilir — gösterge her
 * yoklamada enforce() çağırıp yapılandırılmış düzene geri çeker.
 */

namespace Kavis.Keyboard {

    /* Current layout code ("tr", "us", ...). Failure falls back to
     * "tr" — the product default. */
    public string current_layout () {
        string output;
        try {
            Process.spawn_sync (null,
                { "setxkbmap", "-query" }, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, out output, null, null);
        } catch (SpawnError e) {
            return "tr";
        }
        foreach (unowned string line in output.split ("\n")) {
            if (line.has_prefix ("layout:")) {
                var value = line.substring (7).strip ();
                return value.split (",")[0];
            }
        }
        return "tr";
    }

    /* The layout the USER chose (not what X happens to run). */
    public string configured_layout () {
        try {
            return Config.load ().get_string ("keyboard", "layout");
        } catch (Error e) { }
        try {
            string contents;
            FileUtils.get_contents ("/etc/default/keyboard",
                                    out contents);
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix ("XKBLAYOUT=")) {
                    string value = line.substring (10)
                        .replace ("\"", "").strip ();
                    if (value != "") {
                        return value.split (",")[0];
                    }
                }
            }
        } catch (Error e) { }
        return "tr";
    }

    /* X'in düzeni yapılandırılandan saptıysa geri çek (2F: klavye
     * yeniden takılınca X kendi varsayılanına dönebiliyor). */
    public void enforce () {
        string wanted = configured_layout ();
        if (current_layout () != wanted) {
            apply (wanted);
        }
    }

    /* Switch to the given layout code, persist it (kavis.conf) and
     * apply. Fire-and-forget: the indicator re-reads right after. */
    public void set_layout (string layout) {
        var file = Config.load ();
        file.set_string ("keyboard", "layout", layout);
        Config.save (file);
        apply (layout);
    }

    private void apply (string layout) {
        try {
            /* -option "": grup/karma seçenek kalıntısı temizlenir —
             * tek global düzen kuralı. */
            Process.spawn_async (null,
                { "setxkbmap", "-layout", layout, "-option", "" },
                null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, null);
        } catch (SpawnError e) {
            warning ("kavis-panel: setxkbmap calistirilamadi: %s", e.message);
        }
    }
}
