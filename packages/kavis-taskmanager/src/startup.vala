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
 *
 * G6: the list is the applications menu, every one of them OFF until
 * the user turns it on — the old list was whatever happened to sit in
 * the autostart directories, which meant the session's own plumbing
 * showed up as togglable "apps". Session infrastructure (ESSENTIAL) is
 * filtered out completely: turning off the policy agent or the panel
 * from a task manager is never what someone means, and an accessibility
 * bus that does not start breaks the screen reader silently.
 *
 * D2 (v0.4-test4): the name filter was not enough — a plumbing entry
 * under a name nobody predicted still showed up as a deletable app. The
 * rule is now structural: a SYSTEM autostart entry is listed only if it
 * is also an application in the menu, and plumbing ships NoDisplay=true
 * precisely so it is not. On top of that, administration tools (disk,
 * partition, scanner utilities) are left out even though they are menu
 * applications: nobody starts GParted with their session, and four of
 * them in a row was most of what made the list look like a dump. The
 * user's own autostart files are always listed, menu app or not — one
 * they added themselves has to remain switchable.
 */

namespace Kavis.TaskManager {

    public class StartupPage : Gtk.Box {

        private const string SYSTEM_DIR = "/etc/xdg/autostart";

        /* Session infrastructure: never listed, never switchable. Matched
         * on the .desktop basename, which is what both autostart
         * directories and the menu are keyed by. */
        private const string[] ESSENTIAL = {
            "at-spi-dbus-bus.desktop",
            "gnome-disk-utility.desktop",
            "gsd-disk-utility-notify.desktop",
            "kavis-osd.desktop",
            "kavis-panel.desktop",
            "kavis-power.desktop",
            "kavis-session-autostart.desktop",
            "kavis-snap.desktop",
            "lxpolkit.desktop",
            "nemo-autostart.desktop",
            "picom.desktop",
            "print-applet.desktop",
            "system-config-printer.desktop",
            "xdg-user-dirs.desktop",
            "xfce-polkit.desktop"
        };

        /* D2: administration tools. They ARE menu applications, so no
         * rule about the menu can exclude them, but "start GParted with
         * every session" is not a thing anyone wants and four of them
         * in a row is what made the list look like a dump. Named ones
         * first, then the categories that describe the same kind of
         * thing so a newly installed disk or scanner utility does not
         * have to be added here by hand. */
        private const string[] ADMIN_TOOLS = {
            "gparted.desktop",
            "org.gnome.baobab.desktop",
            "org.gnome.DiskUtility.desktop",
            "simple-scan.desktop"
        };

        private const string[] ADMIN_CATEGORIES = {
            "Settings", "HardwareSettings", "PackageManager",
            "Filesystem", "Scanning"
        };

        private static bool essential (string basename) {
            foreach (unowned string name in ESSENTIAL) {
                if (basename == name) {
                    return true;
                }
            }
            foreach (unowned string name in ADMIN_TOOLS) {
                if (basename == name) {
                    return true;
                }
            }
            /* Our own components ship several .desktop files and more may
             * arrive; none of them belong in a user-facing list. */
            return basename.has_prefix ("kavis-");
        }

        private static bool admin_categories (string? categories) {
            if (categories == null) {
                return false;
            }
            foreach (unowned string c in categories.split (";")) {
                foreach (unowned string bad in ADMIN_CATEGORIES) {
                    if (c == bad) {
                        return true;
                    }
                }
            }
            return false;
        }

        /* The basenames of everything in the applications menu that is
         * eligible for this list. Built once per reload. */
        private HashTable<string, bool> menu_apps () {
            var set = new HashTable<string, bool> (str_hash, str_equal);
            foreach (GLib.AppInfo info in GLib.AppInfo.get_all ()) {
                var desktop = info as GLib.DesktopAppInfo;
                if (desktop == null || !desktop.should_show ()) {
                    continue;
                }
                string? filename = desktop.get_filename ();
                if (filename == null) {
                    continue;
                }
                string basename = Path.get_basename (filename);
                if (essential (basename)
                    || admin_categories (desktop.get_categories ())) {
                    continue;
                }
                set.insert (basename, true);
            }
            return set;
        }

        private class Entry : Object {
            public string basename;
            public string name;
            public string exec;
            public bool enabled;
            public bool user_file;      /* exists in ~/.config/autostart */
            public bool system_file;    /* exists in /etc/xdg/autostart */
            public string menu_path = ""; /* menu entry, when it autostarts nowhere yet */
        }

        private Gtk.ListBox list;
        private Entry[] entries = {};

        public StartupPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            margin = 12;

            var bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var hint = new Gtk.Label (
                _("Apps you can start with your session. Everything is off until you turn it on."));
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
            var menu = menu_apps ();
            /* D2: a system autostart entry is listed only if it is also
             * an application in the menu. Session plumbing ships with
             * NoDisplay=true, so it is not in the menu and never
             * reaches this list — which is how "gnome-disk-utility
             * notification plugin" appeared as a deletable app despite
             * the name filter. A rule beats a list of names here.
             * The user's OWN autostart files are always listed, menu
             * app or not: otherwise something they added themselves
             * could not be switched off again. */
            scan (SYSTEM_DIR, false, by_name, menu);
            scan (user_dir (), true, by_name, null);
            add_menu_apps (by_name, menu);
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
                           HashTable<string, Entry> by_name,
                           HashTable<string, bool>? menu) {
            try {
                var d = Dir.open (dir);
                string? f;
                while ((f = d.read_name ()) != null) {
                    if (!f.has_suffix (".desktop") || essential (f)) {
                        continue;
                    }
                    if (menu != null && !menu.contains (f)) {
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

        /* Everything in the applications menu, switched off unless an
         * autostart file already exists for it. should_show() applies
         * NoDisplay and the OnlyShowIn/NotShowIn rules against
         * XDG_CURRENT_DESKTOP, so the list matches the start menu. */
        private void add_menu_apps (HashTable<string, Entry> by_name,
                                    HashTable<string, bool> menu) {
            foreach (GLib.AppInfo info in GLib.AppInfo.get_all ()) {
                var desktop = info as GLib.DesktopAppInfo;
                if (desktop == null) {
                    continue;
                }
                string? filename = desktop.get_filename ();
                if (filename == null) {
                    continue;
                }
                string basename = Path.get_basename (filename);
                if (!menu.contains (basename)
                    || by_name.contains (basename)) {
                    continue;
                }
                var e = new Entry ();
                e.basename = basename;
                e.name = desktop.get_display_name ();
                e.exec = desktop.get_commandline () ?? "";
                e.enabled = false;
                e.menu_path = filename;
                by_name.insert (basename, e);
            }
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
                e.system_file ? _("System")
                              : (e.user_file ? _("User") : _("App")), e.exec));
            sub.set_xalign (0);
            sub.set_ellipsize (Pango.EllipsizeMode.END);
            sub.get_style_context ().add_class ("dim-label");
            text.pack_start (sub, false, false, 0);
            box.pack_start (text, true, true, 0);
            if (e.user_file || e.system_file) {
                var remove = new Gtk.Button.from_icon_name (
                    "edit-delete-symbolic", Gtk.IconSize.BUTTON);
                remove.set_relief (Gtk.ReliefStyle.NONE);
                remove.set_tooltip_text (_("Remove"));
                remove.clicked.connect (() => on_remove (e));
                box.pack_end (remove, false, false, 0);
            }
            row.add (box);
            return row;
        }

        private void set_enabled (Entry e, bool on) {
            string user_path = Path.build_filename (user_dir (), e.basename);
            DirUtils.create_with_parents (user_dir (), 0755);
            var kf = new KeyFile ();
            string source = (e.user_file) ? user_path
                : (e.system_file ? Path.build_filename (SYSTEM_DIR, e.basename)
                                 : e.menu_path);
            try {
                kf.load_from_file (source, KeyFileFlags.KEEP_TRANSLATIONS
                                           | KeyFileFlags.KEEP_COMMENTS);
            } catch (Error err) {
                return;
            }
            if (!on && !e.system_file && e.user_file) {
                /* A menu app the user had switched on: the autostart file
                 * exists only because of that switch, so drop it instead
                 * of leaving a Hidden=true stub behind. */
                FileUtils.remove (user_path);
                e.user_file = false;
                e.enabled = false;
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
