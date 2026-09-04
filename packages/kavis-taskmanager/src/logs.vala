/* Task Manager — Logs tab (v0.4-test1 H3): journalctl viewer plus the
 * Kavis component logs (panel/snap/settings write to
 * $XDG_RUNTIME_DIR/*.log — the openbox autostart captures stderr
 * there). Source and priority filters, search, copy, save to file.
 * Reads at most the last 1000 lines per refresh; nothing is watched
 * in the background.
 */

namespace Kavis.TaskManager {

    public class LogsPage : Gtk.Box {

        private Gtk.ComboBoxText source;
        private Gtk.ComboBoxText level;
        private Gtk.SearchEntry search;
        private Gtk.TextView view;
        private string raw = "";

        public LogsPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            margin = 12;

            var bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            source = new Gtk.ComboBoxText ();
            source.append ("system", _("System"));
            source.append ("session", _("Session"));
            source.append ("kavis", _("Kavis components"));
            source.active_id = "system";
            source.changed.connect (() => load ());
            bar.pack_start (source, false, false, 0);
            level = new Gtk.ComboBoxText ();
            level.append ("all", _("All levels"));
            level.append ("err", _("Errors"));
            level.append ("warning", _("Warnings and errors"));
            level.append ("info", _("Info and above"));
            level.active_id = "all";
            level.changed.connect (() => load ());
            bar.pack_start (level, false, false, 0);
            search = new Gtk.SearchEntry ();
            search.placeholder_text = _("Search");
            search.search_changed.connect (() => render ());
            bar.pack_start (search, true, true, 0);
            var refresh = new Gtk.Button.from_icon_name (
                "view-refresh-symbolic", Gtk.IconSize.BUTTON);
            refresh.set_tooltip_text (_("Refresh"));
            refresh.clicked.connect (() => load ());
            bar.pack_end (refresh, false, false, 0);
            var save = new Gtk.Button.with_label (_("Save to file"));
            save.clicked.connect (on_save);
            bar.pack_end (save, false, false, 0);
            var copy = new Gtk.Button.with_label (_("Copy"));
            copy.clicked.connect (() => {
                Gtk.Clipboard.get_default (Gdk.Display.get_default ())
                    .set_text (view.buffer.text, -1);
            });
            bar.pack_end (copy, false, false, 0);
            pack_start (bar, false, false, 0);

            view = new Gtk.TextView ();
            view.editable = false;
            view.monospace = true;
            view.wrap_mode = Gtk.WrapMode.NONE;
            view.left_margin = 8;
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.add (view);
            pack_start (scroll, true, true, 0);

            map.connect (() => {
                if (raw == "") {
                    load ();
                }
            });
        }

        private void load () {
            string id = source.active_id ?? "system";
            if (id == "kavis") {
                raw = kavis_logs ();
            } else {
                string[] argv = { "journalctl", "-b", "--no-pager",
                                  "-o", "short-iso", "-n", "1000" };
                if (id == "session") {
                    argv += "--user";
                }
                string lvl = level.active_id ?? "all";
                if (lvl != "all") {
                    argv += "-p";
                    argv += lvl;
                }
                string? out_text = SysInfo.capture (argv);
                raw = out_text
                    ?? _("Could not read the journal (is the user in the adm group?).");
            }
            render ();
        }

        /* Kavis component logs: XDG_RUNTIME_DIR/*.log. */
        private string kavis_logs () {
            var sb = new StringBuilder ();
            string dir = Environment.get_variable ("XDG_RUNTIME_DIR") ?? "/tmp";
            try {
                var d = Dir.open (dir);
                string? f;
                while ((f = d.read_name ()) != null) {
                    if (f.has_prefix ("kavis") && f.has_suffix (".log")) {
                        sb.append_printf ("=== %s ===\n", f);
                        sb.append (SysInfo.read_file (Path.build_filename (dir, f)));
                        sb.append ("\n\n");
                    }
                }
            } catch (Error e) { }
            return (sb.len > 0) ? sb.str : _("No Kavis component logs in this session.");
        }

        private void render () {
            string q = search.get_text ().down ().strip ();
            if (q == "") {
                view.buffer.text = raw;
                return;
            }
            var sb = new StringBuilder ();
            foreach (unowned string line in raw.split ("\n")) {
                if (q in line.down ()) {
                    sb.append (line);
                    sb.append_c ('\n');
                }
            }
            view.buffer.text = sb.str;
        }

        private void on_save () {
            var dialog = new Gtk.FileChooserDialog (_("Save log"),
                get_toplevel () as Gtk.Window, Gtk.FileChooserAction.SAVE,
                _("Cancel"), Gtk.ResponseType.CANCEL,
                _("Save"), Gtk.ResponseType.ACCEPT);
            dialog.set_current_name ("kavis-%s.log".printf (
                new DateTime.now_local ().format ("%Y%m%d-%H%M")));
            dialog.do_overwrite_confirmation = true;
            if (dialog.run () == Gtk.ResponseType.ACCEPT) {
                try {
                    FileUtils.set_contents (dialog.get_filename (),
                                            view.buffer.text);
                } catch (Error e) {
                    warning ("kavis-tools: could not save the log: %s", e.message);
                }
            }
            dialog.destroy ();
        }
    }
}
