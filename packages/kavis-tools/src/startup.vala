/* Task Manager — Startup tab (v0.4-test1 H2).
 *
 * Kavis' own autostart manager. Entries are the XDG autostart
 * .desktop files: /etc/xdg/autostart (system) and
 * ~/.config/autostart (user; same basename overrides the system one —
 * the freedesktop rule). The session launcher
 * (/usr/lib/kavis/kavis-session-autostart) reads the same two
 * directories, so what this list shows is exactly what starts.
 *
 * Disable = write a user copy with Hidden=true (system entries stay
 * untouched, package updates cannot re-enable them). Enable = drop the
 * user override when it only existed to hide, else Hidden=false.
 */

namespace Kavis.Tools {

    public class StartupPage : Gtk.Box {

        private const string SYSTEM_DIR = "/etc/xdg/autostart";

        private class Entry : Object {
            public string basename;
            public string name;
            public string exec;
            public bool enabled;
            public bool user_file;      /* exists in ~/.config/autostart */
            public bool system_file;    /* exists in /etc/xdg/autostart */
        }

        private Gtk.ListBox list;
        private Entry[] entries = {};

        public StartupPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            margin = 12;

            var bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var hint = new Gtk.Label (
                _("Apps that start with your session. Turn one off to skip it next time."));
            hint.set_xalign (0);
            hint.set_line_wrap (true);
            hint.get_style_context ().add_class ("dim-label");
            bar.pack_start (hint, true, true, 0);
            var add = new Gtk.Button.with_label (_("Add"));
            add.clicked.connect (on_add);
            bar.pack_end (add, false, false, 0);
            pack_start (bar, false, false, 0);

            list = new Gtk.ListBox ();
            list.selection_mode = Gtk.SelectionMode.NONE;
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.add (list);
            pack_start (scroll, true, true, 0);

            reload ();
        }

        private static string user_dir () {
            return Path.build_filename (Environment.get_user_config_dir (),
                                        "autostart");
        }

        private void reload () {
            foreach (var child in list.get_children ()) {
                list.remove (child);
            }
            entries = {};
            var by_name = new HashTable<string, Entry> (str_hash, str_equal);
            scan (SYSTEM_DIR, false, by_name);
            scan (user_dir (), true, by_name);
            var names = by_name.get_keys ();
            names.sort (strcmp);
            foreach (unowned string key in names) {
                var e = by_name.lookup (key);
                entries += e;
                list.add (make_row (e));
            }
            list.show_all ();
        }

        private void scan (string dir, bool user,
                           HashTable<string, Entry> by_name) {
            try {
                var d = Dir.open (dir);
                string? f;
                while ((f = d.read_name ()) != null) {
                    if (!f.has_suffix (".desktop")) {
                        continue;
                    }
                    var kf = new KeyFile ();
                    try {
                        kf.load_from_file (Path.build_filename (dir, f),
                                           KeyFileFlags.NONE);
                    } catch (Error e) {
                        continue;
                    }
                    var e = by_name.lookup (f) ?? new Entry ();
                    e.basename = f;
                    try {
                        e.name = kf.get_locale_string ("Desktop Entry", "Name");
                    } catch (Error err) {
                        e.name = f;
                    }
                    try {
                        e.exec = kf.get_string ("Desktop Entry", "Exec");
                    } catch (Error err) {
                        e.exec = "";
                    }
                    bool hidden = false;
                    try {
                        hidden = kf.get_boolean ("Desktop Entry", "Hidden");
                    } catch (Error err) { }
                    e.enabled = !hidden;
                    if (user) {
                        e.user_file = true;
                    } else {
                        e.system_file = true;
                    }
                    by_name.insert (f, e);
                }
            } catch (Error e) { }
        }

        private Gtk.Widget make_row (Entry e) {
            var row = new Gtk.ListBoxRow ();
            row.activatable = false;
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            box.margin = 6;
            var sw = new Gtk.Switch ();
            sw.active = e.enabled;
            sw.valign = Gtk.Align.CENTER;
            sw.notify["active"].connect (() => set_enabled (e, sw.active));
            box.pack_start (sw, false, false, 0);
            var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            var name = new Gtk.Label (e.name);
            name.set_xalign (0);
            text.pack_start (name, false, false, 0);
            var sub = new Gtk.Label ("%s — %s".printf (
                e.system_file ? _("System") : _("User"), e.exec));
            sub.set_xalign (0);
            sub.set_ellipsize (Pango.EllipsizeMode.END);
            sub.get_style_context ().add_class ("dim-label");
            text.pack_start (sub, false, false, 0);
            box.pack_start (text, true, true, 0);
            var remove = new Gtk.Button.from_icon_name (
                "edit-delete-symbolic", Gtk.IconSize.BUTTON);
            remove.set_relief (Gtk.ReliefStyle.NONE);
            remove.set_tooltip_text (_("Remove"));
            remove.clicked.connect (() => on_remove (e));
            box.pack_end (remove, false, false, 0);
            row.add (box);
            return row;
        }

        private void set_enabled (Entry e, bool on) {
            string user_path = Path.build_filename (user_dir (), e.basename);
            DirUtils.create_with_parents (user_dir (), 0755);
            var kf = new KeyFile ();
            string source = (e.user_file) ? user_path
                : Path.build_filename (SYSTEM_DIR, e.basename);
            try {
                kf.load_from_file (source, KeyFileFlags.KEEP_TRANSLATIONS
                                           | KeyFileFlags.KEEP_COMMENTS);
            } catch (Error err) {
                return;
            }
            if (on && e.system_file) {
                /* The user copy existed only to hide: delete it, the
                 * system entry comes back as is. */
                FileUtils.remove (user_path);
                e.user_file = false;
            } else {
                kf.set_boolean ("Desktop Entry", "Hidden", !on);
                try {
                    FileUtils.set_contents (user_path, kf.to_data ());
                    e.user_file = true;
                } catch (Error err) {
                    warning ("kavis-tools: could not write autostart: %s", err.message);
                }
            }
            e.enabled = on;
        }

        private void on_remove (Entry e) {
            if (e.user_file && !e.system_file) {
                FileUtils.remove (Path.build_filename (user_dir (), e.basename));
            } else {
                set_enabled (e, false);
            }
            reload ();
        }

        /* Pick from installed applications (the menu list). */
        private void on_add () {
            var dialog = new Gtk.AppChooserDialog.for_content_type (
                get_toplevel () as Gtk.Window, Gtk.DialogFlags.MODAL,
                "application/x-executable");
            dialog.set_heading (_("Choose an app to start with your session"));
            var widget = dialog.get_widget () as Gtk.AppChooserWidget;
            if (widget != null) {
                widget.show_all = true;
                widget.show_default = false;
                widget.show_recommended = false;
                widget.show_fallback = false;
                widget.show_other = true;
            }
            if (dialog.run () == Gtk.ResponseType.OK) {
                var info = dialog.get_app_info () as GLib.DesktopAppInfo;
                if (info != null && info.get_filename () != null) {
                    DirUtils.create_with_parents (user_dir (), 0755);
                    string dest = Path.build_filename (
                        user_dir (), Path.get_basename (info.get_filename ()));
                    try {
                        File.new_for_path (info.get_filename ()).copy (
                            File.new_for_path (dest), FileCopyFlags.OVERWRITE);
                    } catch (Error err) {
                        warning ("kavis-tools: could not copy: %s", err.message);
                    }
                }
            }
            dialog.destroy ();
            reload ();
        }
    }
}
