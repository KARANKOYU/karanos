/* Clipboard history (business logic) — madde 7, sonraki-isler 5 ile
 * kalıcı depoya dönüştü.
 *
 * X11 pano tuzakları madde 59 taramasından tasarım kuralı oldu
 * (docs/referans/grup-d-taramasi.md):
 *   - içerik owner-change ANINDA kendi belleğimize kopyalanır (X'te
 *     panonun sahibi kopyalayan uygulamadır; uygulama kapanınca pano
 *     boşalır — geçmiş bizim kopyamızdan yaşar);
 *   - yalnız CLIPBOARD izlenir, PRIMARY (fare seçimi) asla;
 *   - şifre yöneticisi ipucu (x-kde-passwordManagerHint) taşıyan
 *     içerik geçmişe ALINMAZ;
 *   - kendi set ettiğimiz içerik geri yakalanıp döngü olmasın diye
 *     işaretlenir.
 *
 * Kalıcılık (bölüm 5): her öğe ~/.cache/kavis/clipboard/ altında bir
 * dosya (<mikrosaniye>.txt ya da .png, 0600). GÖRSELLER de girer —
 * ekran görüntüsü kopyalanınca geçmişin başına düşer; bilinen-sorun
 * 10'un (60 sn pano ömrü) kalıcı cevabı bu. Saklama: 7 gün ve toplam
 * 200 MB — pinliler hariç en eskiden silinir. Pin kaydı aynı dizinde
 * pinned.list.
 */

namespace Kavis {

    public class ClipEntry {
        public string id;          /* dosya adı gövdesi */
        public bool is_image;
        public string text = "";   /* metin öğesinde içerik */
        public string path = "";   /* diskteki dosya */
        public int64 timestamp;    /* unix saniye */
        public bool pinned;
    }

    public class ClipboardHistory : Object {

        public signal void changed ();

        private const int RETENTION_DAYS = 7;
        private const int64 MAX_TOTAL_BYTES = 200 * 1024 * 1024;

        public GenericArray<ClipEntry> items =
            new GenericArray<ClipEntry> ();

        private Gtk.Clipboard clipboard;
        private string? last_set_text = null;
        /* Görselde içerik karşılaştırması pahalı: kendi set ettiğimiz
         * görselin geri yakalanmasını kısa bir bastırma penceresi
         * çözer. */
        private int64 suppress_image_until = 0;

        public ClipboardHistory () {
            load ();
            clipboard = Gtk.Clipboard.get_default (
                Gdk.Display.get_default ());
            clipboard.owner_change.connect (() => on_owner_change ());
        }

        private string store_dir () {
            return Path.build_filename (
                Environment.get_user_cache_dir (), "kavis", "clipboard");
        }

        private string pinned_path () {
            return Path.build_filename (store_dir (), "pinned.list");
        }

        /* --- diskten yükleme ----------------------------------------- */

        private void load () {
            var pinned_ids = new GenericArray<string> ();
            string pin_data;
            try {
                FileUtils.get_contents (pinned_path (), out pin_data);
                foreach (unowned string line in pin_data.split ("\n")) {
                    if (line.strip () != "") {
                        pinned_ids.add (line.strip ());
                    }
                }
            } catch (Error e) { }

            try {
                var dir = Dir.open (store_dir ());
                unowned string? name;
                while ((name = dir.read_name ()) != null) {
                    bool image = name.has_suffix (".png");
                    if (!image && !name.has_suffix (".txt")) {
                        continue;
                    }
                    var entry = new ClipEntry ();
                    entry.id = name.substring (0, name.length - 4);
                    entry.is_image = image;
                    entry.path = Path.build_filename (store_dir (), name);
                    entry.timestamp = int64.parse (entry.id) / 1000000;
                    for (int i = 0; i < pinned_ids.length; i++) {
                        if (pinned_ids[i] == entry.id) {
                            entry.pinned = true;
                        }
                    }
                    if (!image) {
                        try {
                            string text;
                            FileUtils.get_contents (entry.path, out text);
                            entry.text = text;
                        } catch (Error e) {
                            continue;
                        }
                    }
                    items.add (entry);
                }
            } catch (Error e) {
                /* ilk çalıştırma */
            }
            items.sort ((a, b) => {
                int64 diff = int64.parse (b.id) - int64.parse (a.id);
                return (diff > 0) ? 1 : ((diff < 0) ? -1 : 0);
            });
            prune ();
        }

        private void save_pinned () {
            var builder = new StringBuilder ();
            for (int i = 0; i < items.length; i++) {
                if (items[i].pinned) {
                    builder.append (items[i].id).append_c ('\n');
                }
            }
            DirUtils.create_with_parents (store_dir (), 0700);
            try {
                FileUtils.set_contents (pinned_path (), builder.str);
                FileUtils.chmod (pinned_path (), 0600);
            } catch (Error e) {
                warning ("kavis-panel: pinned.list yazilamadi: %s",
                         e.message);
            }
        }

        /* 7 gün + 200 MB (pinliler bağışık, en eski önce gider). */
        private void prune () {
            int64 now = new DateTime.now_utc ().to_unix ();
            int64 cutoff = now - RETENTION_DAYS * 24 * 3600;
            int64 total = 0;
            for (int i = (int) items.length - 1; i >= 0; i--) {
                var entry = items[i];
                if (!entry.pinned && entry.timestamp < cutoff) {
                    delete_entry (entry, false);
                }
            }
            for (int i = 0; i < items.length; i++) {
                total += file_size (items[i].path);
            }
            for (int i = (int) items.length - 1;
                 i >= 0 && total > MAX_TOTAL_BYTES; i--) {
                var entry = items[i];
                if (!entry.pinned) {
                    total -= file_size (entry.path);
                    delete_entry (entry, false);
                }
            }
        }

        private int64 file_size (string path) {
            try {
                var info = File.new_for_path (path).query_info (
                    FileAttribute.STANDARD_SIZE,
                    FileQueryInfoFlags.NONE);
                return info.get_size ();
            } catch (Error e) {
                return 0;
            }
        }

        /* --- pano dinleme -------------------------------------------- */

        private void on_owner_change () {
            clipboard.request_targets ((clip, atoms) => {
                bool has_image = false;
                foreach (var atom in atoms) {
                    string name = atom.name ();
                    if (name == "x-kde-passwordManagerHint") {
                        return;   /* şifre — geçmişe girmez */
                    }
                    if (name.has_prefix ("image/")) {
                        has_image = true;
                    }
                }
                clip.request_text ((c, text) => {
                    if (text != null && text.strip () != "") {
                        store_text (text);
                    } else if (has_image) {
                        c.request_image ((c2, pixbuf) => {
                            if (pixbuf != null) {
                                store_image (pixbuf);
                            }
                        });
                    }
                });
            });
        }

        private string fresh_id () {
            return "%lld".printf (
                new DateTime.now_utc ().to_unix () * 1000000
                + Random.int_range (0, 1000000));
        }

        private void store_text (string text) {
            if (last_set_text != null && text == last_set_text) {
                return;   /* bizim yazdığımız geri geldi */
            }
            /* Aynı içerik tekrar kopyalandıysa üste taşı. */
            for (int i = 0; i < items.length; i++) {
                if (!items[i].is_image && items[i].text == text) {
                    var existing = items[i];
                    items.remove_index (i);
                    items.insert (0, existing);
                    changed ();
                    return;
                }
            }
            var entry = new ClipEntry ();
            entry.id = fresh_id ();
            entry.is_image = false;
            entry.text = text;
            entry.timestamp = new DateTime.now_utc ().to_unix ();
            entry.path = Path.build_filename (store_dir (),
                                              entry.id + ".txt");
            DirUtils.create_with_parents (store_dir (), 0700);
            try {
                FileUtils.set_contents (entry.path, text);
                FileUtils.chmod (entry.path, 0600);
            } catch (Error e) {
                warning ("kavis-panel: pano ogesi yazilamadi: %s",
                         e.message);
            }
            items.insert (0, entry);
            prune ();
            changed ();
        }

        private void store_image (Gdk.Pixbuf pixbuf) {
            int64 now_us = get_real_time ();
            if (now_us < suppress_image_until) {
                return;   /* kendi koyduğumuz görsel */
            }
            var entry = new ClipEntry ();
            entry.id = fresh_id ();
            entry.is_image = true;
            entry.timestamp = new DateTime.now_utc ().to_unix ();
            entry.path = Path.build_filename (store_dir (),
                                              entry.id + ".png");
            DirUtils.create_with_parents (store_dir (), 0700);
            try {
                pixbuf.save (entry.path, "png");
                FileUtils.chmod (entry.path, 0600);
            } catch (Error e) {
                warning ("kavis-panel: pano gorseli yazilamadi: %s",
                         e.message);
                return;
            }
            items.insert (0, entry);
            prune ();
            changed ();
        }

        /* --- kullanım ------------------------------------------------- */

        /* Picker'ın emoji/snippet yerleştirmesi: panoya yaz, kendi
         * yazdığımızı geri yakalama. */
        public void set_clipboard_text (string text) {
            last_set_text = text;
            clipboard.set_text (text, -1);
        }

        /* Öğeyi panoya koy (picker üstüne xdotool ile Ctrl+V basar). */
        public void activate_entry (ClipEntry entry) {
            if (entry.is_image) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file (entry.path);
                    suppress_image_until = get_real_time () + 2000000;
                    clipboard.set_image (pixbuf);
                } catch (Error e) {
                    warning ("kavis-panel: gorsel yuklenemedi: %s",
                             e.message);
                }
            } else {
                last_set_text = entry.text;
                clipboard.set_text (entry.text, -1);
            }
        }

        public void delete_entry (ClipEntry entry, bool notify = true) {
            FileUtils.unlink (entry.path);
            for (int i = 0; i < items.length; i++) {
                if (items[i] == entry) {
                    items.remove_index (i);
                    break;
                }
            }
            if (entry.pinned) {
                save_pinned ();
            }
            if (notify) {
                changed ();
            }
        }

        /* Tümünü temizle: pinliler kalır (bölüm 5 kuralı). */
        public void clear () {
            for (int i = (int) items.length - 1; i >= 0; i--) {
                if (!items[i].pinned) {
                    delete_entry (items[i], false);
                }
            }
            changed ();
        }

        public void toggle_pin (ClipEntry entry) {
            entry.pinned = !entry.pinned;
            save_pinned ();
            changed ();
        }
    }
}
