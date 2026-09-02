/* UI strings (business logic — no widget code here).
 *
 * KANONİK KOPYA BURASI (kavis-common) — appinit.vala ile aynı düzen:
 * build-packages.sh her kavis GTK paketinin src ağacına kopyalar,
 * kopyalar .gitignore'dadır. Tablo bütün uygulamaların BİRLEŞİMİdir;
 * bir ikilinin kullanmadığı anahtar zararsızdır, tek kaynak kuralı
 * bölünmüş tablolardan önemlidir.
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
        { "panel.menu_align",         "Hizalama",                  "Alignment" },
        { "panel.align_left",         "Sola hizala",               "Align left" },
        { "panel.align_center",       "Ortala",                    "Center" },
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

        /* Bildirim merkezi + hızlı ayarlar (madde 37) — "Bildirimler ve
         * küçük araçlar", "Ağ", "Ayarlar", "Ses / Ekran" tabloları. */
        { "notif.center",             "Bildirimler",               "Notifications" },
        { "notif.clear_all",          "Tümünü temizle",            "Clear all" },
        { "notif.no_notifications",   "Yeni bildirim yok",         "No new notifications" },
        { "settings.coming_soon",     "Ayarlar uygulaması yakında", "Settings app coming soon" },
        { "notif.dnd",                "Rahatsız etme",             "Do not disturb" },
        { "network.wifi",             "Wi-Fi",                     "Wi-Fi" },
        { "network.airplane",         "Uçak modu",                 "Airplane mode" },
        { "network.connected",        "Bağlı",                     "Connected" },
        { "network.disconnect",       "Bağlantıyı kes",            "Disconnect" },
        { "network.no_networks",      "Ağ bulunamadı",             "No networks found" },
        { "network.settings",         "Ağ ayarları",               "Network settings" },
        { "settings.bluetooth",       "Bluetooth",                 "Bluetooth" },
        { "settings.accessibility",   "Erişilebilirlik",           "Accessibility" },
        { "bt.paired_devices",        "Eşleştirilmiş cihazlar",    "Paired devices" },
        { "sound.output",             "Çıkış aygıtı",              "Output device" },
        { "power.battery_saver",      "Pil tasarrufu",             "Battery saver" },
        { "display.night_mode",       "Gece modu",                 "Night light" },
        { "display.brightness",       "Parlaklık",                 "Brightness" },
        { "game.mode",                "Oyun Modu",                 "Game Mode" },
        { "focus.mode",               "Odaklanma",                 "Focus" },
        { "common.clear",             "Temizle",                   "Clear" },
        { "common.settings",          "Ayarlar",                   "Settings" },
        { "common.back",              "Geri",                      "Back" },

        /* Genel bakış + odaklanma (madde 55). */
        { "panel.desktop_n",          "Masaüstü %d",               "Desktop %d" },
        { "focus.finished",           "Odaklanma süresi bitti",    "Focus session finished" },
        { "notif.missed",             "%d yeni bildirim",          "%d new notifications" },

        /* Pano geçmişi (madde 7) — "Bildirimler ve küçük araçlar". */
        { "clipboard.history",        "Pano geçmişi",              "Clipboard history" },
        { "clipboard.empty",          "Pano geçmişi boş",          "Clipboard history is empty" },
        { "clipboard.pin",            "Sabitle",                   "Pin" },
        { "clipboard.unpin",          "Sabitlemeyi kaldır",        "Unpin" },

        /* Görev yöneticisi (madde 7, kavis-tools) — "Görev Yöneticisi"
         * tablosu. */
        { "tm.title",                 "Görev Yöneticisi",          "Task Manager" },
        { "tm.tab_processes",         "İşlemler",                  "Processes" },
        { "tm.name",                  "Ad",                        "Name" },
        { "tm.cpu",                   "İşlemci",                   "CPU" },
        { "tm.memory",                "Bellek",                    "Memory" },
        { "tm.disk",                  "Disk",                      "Disk" },
        { "tm.end_task",              "Görevi sonlandır",          "End task" },
        { "tm.force_end",             "Zorla sonlandır",           "Force end" },
        { "tm.critical_warning",      "Bu sistem işlemini kapatmak sorun çıkarabilir. Devam edilsin mi?",
                                      "Ending this system process may cause problems. Continue?" },

        /* Hesap makinesi + emoji (madde 7, kavis-tools). */
        { "calc.title",               "Hesap Makinesi",            "Calculator" },
        { "calc.error",               "Geçersiz ifade",            "Invalid expression" },
        { "emoji.title",              "Emoji Seçici",              "Emoji Picker" },
        { "emoji.cat_smileys",        "Yüzler",                    "Smileys" },
        { "emoji.cat_people",         "İnsanlar",                  "People" },
        { "emoji.cat_nature",         "Doğa",                      "Nature" },
        { "emoji.cat_food",           "Yiyecek",                   "Food" },
        { "emoji.cat_travel",         "Gezi",                      "Travel" },
        { "emoji.cat_objects",        "Nesneler",                  "Objects" },
        { "emoji.cat_symbols",        "Semboller",                 "Symbols" },

        /* Ekran görüntüsü ve kaydı (madde 29, kavis-tools). */
        { "capture.image",            "Görsel",                    "Image" },
        { "capture.video",            "Video",                     "Video" },
        { "capture.stop",             "Durdur",                    "Stop" },
        { "capture.recording",        "Kayıt sürüyor",             "Recording" },
        { "capture.saved_video",      "Ekran kaydı kaydedildi",    "Screen recording saved" },
        { "screenshot.saved",         "Ekran görüntüsü kaydedildi", "Screenshot saved" },
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
                || e.key.has_prefix ("setup.")
                || e.key.has_prefix ("notif.")
                || e.key.has_prefix ("network.")
                || e.key.has_prefix ("settings.")
                || e.key.has_prefix ("display.")
                || e.key.has_prefix ("game.")
                || e.key.has_prefix ("focus.")
                || e.key.has_prefix ("common.")
                || e.key.has_prefix ("bt.")
                || e.key.has_prefix ("clipboard.")
                || e.key.has_prefix ("tm.")
                || e.key.has_prefix ("calc.")
                || e.key.has_prefix ("emoji.")
                || e.key.has_prefix ("capture.")
                || e.key.has_prefix ("screenshot.");
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
