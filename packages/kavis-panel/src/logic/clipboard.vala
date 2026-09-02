/* Clipboard history (business logic) — madde 7 (Win+V).
 *
 * X11 pano tuzakları madde 59 taramasından tasarım kuralı oldu
 * (docs/referans/grup-d-taramasi.md):
 *   - içerik owner-change ANINDA kendi belleğimize kopyalanır (X'te
 *     panonun sahibi kopyalayan uygulamadır; uygulama kapanınca pano
 *     boşalır — geçmiş bizim kopyamızdan yaşar);
 *   - yalnız CLIPBOARD izlenir, PRIMARY (fare seçimi) asla — her
 *     seçimi kaydetmek hem gürültü hem gizlilik sorunu;
 *   - şifre yöneticisi ipucu (x-kde-passwordManagerHint hedefi)
 *     taşıyan içerik geçmişe ALINMAZ;
 *   - kendi set ettiğimiz içerik geri yakalanıp döngü olmasın diye
 *     son yazdığımız işaretlenir.
 *
 * Sabitlenenler kalıcıdır (~/.config/kavis/clipboard-pinned, KeyFile —
 * kullanıcı bilerek sabitledi); geçmişin kendisi oturumla ölür.
 */

namespace Kavis {

    public class ClipboardHistory : Object {

        public signal void changed ();

        public GenericArray<string> items = new GenericArray<string> ();
        public GenericArray<string> pinned = new GenericArray<string> ();

        private Gtk.Clipboard clipboard;
        private string? last_set = null;
        private int limit = 25;

        public ClipboardHistory () {
            load_limit ();
            load_pinned ();
            clipboard = Gtk.Clipboard.get_default (
                Gdk.Display.get_default ());
            clipboard.owner_change.connect (() => on_owner_change ());
        }

        /* Öğe sayısı ayarı (madde 7): panel.conf [clipboard] limit=N.
         * Ayarlar (Grup F) aynı anahtarı düzenleyecek. */
        private void load_limit () {
            var file = new KeyFile ();
            try {
                file.load_from_file (Path.build_filename (
                    Environment.get_user_config_dir (), "kavis",
                    "panel.conf"), KeyFileFlags.NONE);
                limit = file.get_integer ("clipboard", "limit");
            } catch (Error e) {
                /* varsayılan kalır */
            }
            limit = limit.clamp (5, 100);
        }

        private void on_owner_change () {
            clipboard.request_targets ((clip, atoms) => {
                foreach (var atom in atoms) {
                    if (atom.name () == "x-kde-passwordManagerHint") {
                        return;   /* şifre — geçmişe girmez */
                    }
                }
                clip.request_text ((c, text) => {
                    store (text);
                });
            });
        }

        private void store (string? text) {
            if (text == null || text.strip () == "") {
                return;
            }
            if (last_set != null && text == last_set) {
                return;   /* bizim yazdığımız geri geldi */
            }
            /* Aynı içerik tekrar kopyalandıysa üste taşı. */
            for (int i = 0; i < items.length; i++) {
                if (items[i] == text) {
                    items.remove_index (i);
                    break;
                }
            }
            items.insert (0, text);
            while (items.length > limit) {
                items.remove_index (items.length - 1);
            }
            changed ();
        }

        /* Seçilen öğeyi panoya koy (popup 'tıkla-yapıştır' bunun
         * üstüne xdotool ile Ctrl+V basar). */
        public void activate_item (string text) {
            last_set = text;
            clipboard.set_text (text, -1);
        }

        public void clear () {
            items.remove_range (0, items.length);
            changed ();
        }

        public bool is_pinned (string text) {
            for (int i = 0; i < pinned.length; i++) {
                if (pinned[i] == text) {
                    return true;
                }
            }
            return false;
        }

        public void toggle_pin (string text) {
            for (int i = 0; i < pinned.length; i++) {
                if (pinned[i] == text) {
                    pinned.remove_index (i);
                    save_pinned ();
                    changed ();
                    return;
                }
            }
            pinned.insert (0, text);
            save_pinned ();
            changed ();
        }

        private string pinned_path () {
            return Path.build_filename (
                Environment.get_user_config_dir (), "kavis",
                "clipboard-pinned");
        }

        private void load_pinned () {
            var file = new KeyFile ();
            try {
                file.load_from_file (pinned_path (), KeyFileFlags.NONE);
                int count = file.get_integer ("pinned", "count");
                for (int i = 0; i < count && i < 50; i++) {
                    pinned.add (file.get_string ("pinned",
                                                 "item%d".printf (i)));
                }
            } catch (Error e) {
                /* ilk çalıştırma */
            }
        }

        private void save_pinned () {
            var file = new KeyFile ();
            file.set_integer ("pinned", "count", (int) pinned.length);
            for (int i = 0; i < pinned.length; i++) {
                file.set_string ("pinned", "item%d".printf (i), pinned[i]);
            }
            string path = pinned_path ();
            DirUtils.create_with_parents (Path.get_dirname (path), 0700);
            try {
                FileUtils.set_contents (path, file.to_data ());
                FileUtils.chmod (path, 0600);   /* pano içeriği hassas */
            } catch (Error e) {
                warning ("kavis-panel: sabitlenenler yazilamadi: %s",
                         e.message);
            }
        }
    }
}
