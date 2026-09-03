/* Clipboard history (business logic) — madde 7, turned into a
 * persistent store with sonraki-isler 5.
 *
 * The X11 clipboard pitfalls became design rules through the madde 59
 * scan (docs/referans/grup-d-taramasi.md):
 *   - content is copied into our own memory the INSTANT owner-change
 *     fires (on X the clipboard owner is the copying app; when the app
 *     quits the clipboard empties — history lives on from our copy);
 *   - only CLIPBOARD is watched, never PRIMARY (mouse selection);
 *   - content carrying the password manager hint
 *     (x-kde-passwordManagerHint) is NOT taken into history;
 *   - content we set ourselves is marked so it is not captured back
 *     and does not loop.
 *
 * Persistence (section 5): every item is a file under
 * ~/.cache/kavis/clipboard/ (<microseconds>.txt or .png, 0600). IMAGES
 * go in too — copying a screenshot puts it at the head of the history;
 * this is the permanent answer to known-issue 10 (60 s clipboard
 * lifetime). Retention: 7 days and 200 MB total — the oldest are
 * deleted first, pinned items exempt. The pin record is pinned.list
 * in the same directory.
 */

namespace Kavis {

    public class ClipEntry {
        public string id;          /* file name stem */
        public bool is_image;
        public string text = "";   /* content for a text item */
        public string path = "";   /* file on disk */
        public int64 timestamp;    /* unix seconds */
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
        /* Comparing image content is expensive: a short suppression
         * window handles the image we set ourselves being captured
         * back. */
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

        /* --- loading from disk --------------------------------------- */

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
                /* first run */
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
                warning ("kavis-panel: could not write pinned.list: %s",
                         e.message);
            }
        }

        /* 7 days + 200 MB (pinned items immune, oldest goes first). */
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

        /* --- clipboard listening ------------------------------------- */

        private void on_owner_change () {
            clipboard.request_targets ((clip, atoms) => {
                bool has_image = false;
                foreach (var atom in atoms) {
                    string name = atom.name ();
                    if (name == "x-kde-passwordManagerHint") {
                        return;   /* password — stays out of history */
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
                return;   /* what we wrote came back */
            }
            /* If the same content was copied again, move it to the top. */
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
                warning ("kavis-panel: could not write clipboard item: %s",
                         e.message);
            }
            items.insert (0, entry);
            prune ();
            changed ();
        }

        private void store_image (Gdk.Pixbuf pixbuf) {
            int64 now_us = get_real_time ();
            if (now_us < suppress_image_until) {
                return;   /* the image we put there ourselves */
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
                warning ("kavis-panel: could not write clipboard image: %s",
                         e.message);
                return;
            }
            items.insert (0, entry);
            prune ();
            changed ();
        }

        /* --- usage ---------------------------------------------------- */

        /* The picker's emoji/snippet insertion: write to the clipboard,
         * do not capture back what we wrote ourselves. */
        public void set_clipboard_text (string text) {
            last_set_text = text;
            clipboard.set_text (text, -1);
        }

        /* Put the item on the clipboard (the picker then presses
         * Ctrl+V through xdotool on top). */
        public void activate_entry (ClipEntry entry) {
            if (entry.is_image) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file (entry.path);
                    suppress_image_until = get_real_time () + 2000000;
                    clipboard.set_image (pixbuf);
                } catch (Error e) {
                    warning ("kavis-panel: could not load image: %s",
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

        /* Clear all: pinned items stay (section 5 rule). */
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
