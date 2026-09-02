/* UI strings (business logic — no widget code here).
 *
 * NO TEXT IS INVENTED HERE. Every entry mirrors a row of the tables in
 * docs/kavis-arayuz-metinleri.md, keyed by the same keys. If a needed
 * text has no table row, the table is extended first.
 *
 * Language selection: from the system locale. Turkish is the default;
 * anything not starting with "tr" gets English.
 */

namespace Kavis.Strings {

    private struct Entry {
        public unowned string key;
        public unowned string tr;
        public unowned string en;
    }

    /* panel.* — docs/kavis-arayuz-metinleri.md, "Görev çubuğu ve başlat
     * menüsü" table. */
    private const Entry[] TABLE = {
        { "panel.start",              "Başlat",                    "Start" },
        { "panel.search_placeholder", "Uygulama veya dosya ara",   "Search apps and files" },
        { "panel.all_apps",           "Tüm uygulamalar",           "All apps" },
        { "panel.pinned",             "Sabitlenenler",             "Pinned" },
        { "panel.recent",             "Son kullanılanlar",         "Recent" },
        { "panel.pin",                "Görev çubuğuna sabitle",    "Pin to taskbar" },
        { "panel.unpin",              "Sabitlemeyi kaldır",        "Unpin" },
        { "panel.power",              "Güç",                       "Power" },
        { "panel.shutdown",           "Kapat",                     "Shut down" },
        { "panel.restart",            "Yeniden başlat",            "Restart" },
        { "panel.logout",             "Oturumu kapat",             "Sign out" },
        { "panel.lock",               "Kilitle",                   "Lock" },
        { "panel.sleep",              "Uyku",                      "Sleep" },
        { "panel.show_desktop",       "Masaüstünü göster",         "Show desktop" },
        { "panel.task_manager",       "Görev Yöneticisi",          "Task Manager" },
        { "panel.taskbar_settings",   "Görev çubuğu ayarları",     "Taskbar settings" },
        { "panel.no_results",         "Sonuç bulunamadı",          "No results found" },

        /* Sağ tık menüsü (madde 5). */
        { "panel.menu_position",      "Konum",                     "Position" },
        { "panel.position_bottom",    "Alt",                       "Bottom" },
        { "panel.position_top",       "Üst",                       "Top" },
        { "panel.position_left",      "Sol",                       "Left" },
        { "panel.position_right",     "Sağ",                       "Right" },
        { "panel.menu_size",          "Boyut",                     "Size" },
        { "panel.size_thin",          "İnce",                      "Thin" },
        { "panel.size_medium",        "Orta",                      "Medium" },
        { "panel.size_thick",         "Kalın",                     "Thick" },
        { "panel.menu_monitor",       "Ekran",                     "Monitor" },
        { "panel.monitor_primary",    "Birincil ekran",            "Primary monitor" },
        { "panel.menu_autohide",      "Otomatik gizle",            "Auto-hide" },
        { "panel.display_settings",   "Ekran ayarları",            "Display settings" },

        /* Gösterge popup'ları (Aşama 4) — "Güç", "Ses / Ekran /
         * Klavye" ve "İlk kurulum" tablolarından. */
        { "power.charging",           "Şarj oluyor",               "Charging" },
        { "power.remaining",          "%s kaldı",                  "%s remaining" },
        { "power.hours_short",        "sa",                        "h" },
        { "power.minutes_short",      "dk",                        "min" },
        { "power.plan",               "Güç planı",                 "Power plan" },
        { "power.plan_performance",   "Tam performans",            "High performance" },
        { "power.plan_normal",        "Normal",                    "Balanced" },
        { "power.plan_saver",         "Tasarruf",                  "Power saver" },
        { "power.when_plugged",       "Şarjdayken",                "When plugged in" },
        { "power.when_battery",       "Şarjda değilken",           "On battery" },
        { "sound.volume",             "Ses seviyesi",              "Volume" },
        { "sound.mute",               "Sessize al",                "Mute" },
        { "keyboard.layout",          "Klavye düzeni",             "Keyboard layout" },
        { "setup.keyboard_trq",       "Türkçe Q",                  "Turkish Q" },
        { "setup.keyboard_en",        "İngilizce (ABD)",           "English (US)" },
    };

    private bool turkish_selected;
    private bool language_ready = false;

    /* Decide the UI language once, from the message locale.
     * Empty/unset locale counts as Turkish — the product default. */
    private void select_language () {
        if (language_ready) {
            return;
        }
        unowned string? locale = Intl.setlocale (LocaleCategory.MESSAGES, null);
        string code = (locale ?? "").down ();
        turkish_selected = (code == "" || code == "c" || code == "posix"
                            || code.has_prefix ("tr"));
        language_ready = true;
    }

    /* Whether the UI is shown in Turkish. Exposed for texts that live
     * outside the table but still need one consistent language choice
     * (e.g. XDG category names in apps.vala). */
    public bool is_turkish () {
        select_language ();
        return turkish_selected;
    }

    /* Look up a key. Unknown keys return the key itself so a missing
     * entry shows up as a literal "panel.foo" in the UI instead of a
     * silently wrong text. */
    public unowned string get (string key) {
        select_language ();
        foreach (unowned Entry e in TABLE) {
            if (e.key == key) {
                return turkish_selected ? e.tr : e.en;
            }
        }
        warning ("kavis-panel: metin tablosunda yok: %s", key);
        return key;
    }

    /* Self-check used by CI (kavis-panel --metin-denetimi): every key
     * must resolve to a non-empty text in both languages. Returns the
     * number of problems found (0 = table is consistent). */
    public int self_check () {
        int errors = 0;
        foreach (unowned Entry e in TABLE) {
            if (e.tr.length == 0 || e.en.length == 0) {
                stderr.printf ("bos metin: %s\n", e.key);
                errors++;
            }
            /* Keys must come from a table the panel actually mirrors —
             * a typo'd prefix would silently bypass the doc tables. */
            bool known_prefix = e.key.has_prefix ("panel.")
                || e.key.has_prefix ("power.")
                || e.key.has_prefix ("sound.")
                || e.key.has_prefix ("keyboard.")
                || e.key.has_prefix ("setup.");
            if (!known_prefix) {
                stderr.printf ("beklenmeyen anahtar oneki: %s\n", e.key);
                errors++;
            }
        }
        stdout.printf ("metin tablosu: %d anahtar, %d hata\n",
                       (int) TABLE.length, errors);
        return errors;
    }
}
