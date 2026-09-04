/* Task manager (madde 7): process list with CPU / RAM / disk columns,
 * totals on top, search filter. Reads /proc directly — no dependency
 * on libgtop or similar; the panel's RAM rules apply here.
 *
 * Actions (feedback G2): the "End task" button is gone — a button that
 * is dead until a row is picked is wasted toolbar. Everything hangs off
 * the row instead, the way Windows does it: right-click for End task /
 * Kill / Open file location / Properties, Delete to end and
 * Shift+Delete to kill. End task goes through without a question
 * (SIGTERM is recoverable, apps get to save); Kill asks first, because
 * SIGKILL is not.
 *
 * Cost model (optimization round): ONE file per process per tick
 * (/proc/PID/stat carries utime, stime AND rss pages), the name is
 * resolved once per pid from /proc/PID/exe (cached until the pid
 * vanishes), uid comes from a stat(2) on the /proc/PID directory, and
 * /proc/PID/io is read only for processes we own (root-owned ones are
 * unreadable anyway). Rows are updated IN PLACE keyed by pid — no
 * store.clear(): no flicker, the selection and sort order survive.
 * Kernel threads (empty cmdline) are hidden like Windows does. The
 * 2-second tick runs only while the Processes page is mapped.
 *
 * CPU% (feedback G3): delta of utime+stime against the delta of the
 * machine-wide jiffy counter between refreshes — the SAME denominator
 * the total on top uses, so the column adds up to that figure. The
 * jiffy counter of /proc/stat's first line already counts every core,
 * so the value is normalised over all of them the way Windows 11
 * reports it: one core pinned on a 4-thread machine reads 25%, and
 * nothing can pass 100%. (It used to be multiplied by the core count,
 * which is why Xorg showed 41% while the total said 11%.) First
 * refresh shows 0% by design.
 *
 * Memory (RAM cleanup item 1): the column is USS — smaps_rollup's
 * Private_* pages, the memory that is really freed when the process
 * ends. RSS counts every shared library in every process that maps
 * it, so the column summed to far more than the machine has. USS is
 * one open+read per process and is NOT readable for another user's
 * process: those rows fall back to RSS and the tooltip says so. RSS
 * and PID moved behind the "Advanced columns" toggle.
 */

namespace Kavis.TaskManager {

    public class TaskManagerWindow : Gtk.Window {

        private const int REFRESH_SECONDS = 2;
        /* Em dash: what every unreadable /proc field shows. */
        private const string MISSING = "—";

        /* G4: the sorted column has to be unmistakable. GTK's own
         * indicator is a 6px triangle the dark palette all but
         * swallows, so the arrow goes into the title text and the
         * header itself is painted in the accent color. */
        private const string CSS = """
        treeview header button.kavis-sorted {
          color: @kavis_teal;
          box-shadow: inset 0 -2px 0 @kavis_teal;
        }
        treeview header button.kavis-sorted label {
          font-weight: bold;
        }
        """;

        private Gtk.ListStore store;
        private Gtk.TreeModelFilter filtered;
        private Gtk.TreeModelSort sortable;
        private Gtk.TreeView view;
        private Gtk.SearchEntry search;
        private Gtk.Label totals;
        private Gtk.TreeViewColumn cpu_column;
        private Gtk.TreeViewColumn mem_column;
        private Gtk.TreeViewColumn pid_column;
        private Gtk.TreeViewColumn rss_column;
        /* Column list with the title WITHOUT the sort arrow: the CPU
         * and Memory titles carry a live percentage, so the arrow has
         * to be re-composed rather than appended once. */
        private Gtk.TreeViewColumn[] columns = {};
        private string[] base_titles = {};
        private uint timer = 0;

        /* Refresh cost check (RAM cleanup item 1): with
         * KAVIS_TASKMANAGER_PROFILE=1 every pass prints its wall time.
         * The budget is ~80 ms; above it the USS read would have to be
         * done lazily for the visible rows only. */
        private static bool profile =
            Environment.get_variable ("KAVIS_TASKMANAGER_PROFILE") != null;

        private class Sample : Object {
            public uint64 ticks;
            public uint64 io_bytes;
            public bool io_readable;
            /* Set once: smaps_rollup belongs to the process owner and
             * a process never changes owner, so a refused read is not
             * retried every tick. */
            public bool uss_readable;
            public string name;
            public int uid;
            public Gtk.TreeIter iter;
            public bool seen;
        }
        /* pid → last sample + row. */
        private HashTable<int, Sample> samples =
            new HashTable<int, Sample> (direct_hash, direct_equal);
        private uint64 prev_total_jiffies = 0;
        private uint64 prev_busy_jiffies = 0;
        private long page_kb = 4;
        private int cpu_count = 1;
        private int own_uid = 0;

        /* MEM_KB / MEM_TEXT hold USS (RSS where USS is refused);
         * RSS_KB / RSS_TEXT are the advanced column. USS_OK is false
         * on a fallback row — the tooltip explains the cell. */
        private enum Col { NAME, CPU, CPU_TEXT, MEM_KB, MEM_TEXT,
                           DISK_TEXT, PID, UID, RSS_KB, RSS_TEXT,
                           USS_OK }

        public TaskManagerWindow () {
            set_title (_("Task Manager"));
            /* W11 title bar (feedback A) — same as Settings. */
            Kavis.HeaderBar.attach (this, _("Task Manager"),
                                    "kavis-taskmanager");
            page_kb = Posix.sysconf (Posix._SC_PAGESIZE) / 1024;
            cpu_count = (int) get_num_processors ();
            own_uid = (int) Posix.getuid ();

            var css = new Gtk.CssProvider ();
            try {
                css.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), css,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-taskmanager: could not load CSS: %s",
                         e.message);
            }

            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            root.set_border_width (10);
            /* H (v0.4-test1): navigation on the left like W11 —
             * Processes / Performance / Startup / Logs. Stack unmaps
             * the hidden page: sampling stops while closed. */
            var stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            stack.transition_duration = 140;
            var sidebar = new Gtk.StackSidebar ();
            sidebar.stack = stack;
            sidebar.set_size_request (160, -1);
            sidebar.get_style_context ().add_class ("kavis-tasks-nav");
            var layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            layout.pack_start (sidebar, false, false, 0);
            layout.pack_start (stack, true, true, 0);
            add (layout);
            stack.add_titled (root, "processes", _("Processes"));
            stack.add_titled (new PerformancePage (), "performance", _("Performance"));
            stack.add_titled (new StartupPage (), "startup", _("Startup"));
            stack.add_titled (new LogsPage (), "logs", _("Logs"));
            set_default_size (920, 600);

            /* Totals on top: W11's "CPU 22% · Memory 50%" line. */
            totals = new Gtk.Label ("");
            totals.set_xalign (0);
            totals.get_style_context ().add_class ("dim-label");
            root.pack_start (totals, false, false, 0);

            var top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            search = new Gtk.SearchEntry ();
            search.placeholder_text = _("Search");
            search.search_changed.connect (() => filtered.refilter ());
            top.pack_start (search, true, true, 0);
            /* G2: no End task button here any more — see the file
             * header. The hint tells first-time users where it went. */
            var hint = new Gtk.Label (
                _("Right-click a process for actions"));
            hint.get_style_context ().add_class ("dim-label");
            top.pack_end (hint, false, false, 0);
            /* RAM cleanup item 1: everything a normal user does not
             * need every day sits behind one toggle — RSS (the number
             * that double-counts shared libraries) and the PID. */
            var advanced = new Gtk.ToggleButton.with_label (
                _("Advanced columns"));
            advanced.set_tooltip_text (
                _("Show the RSS and PID columns"));
            advanced.toggled.connect (() => {
                pid_column.visible = advanced.active;
                rss_column.visible = advanced.active;
            });
            top.pack_end (advanced, false, false, 0);
            root.pack_start (top, false, false, 0);

            store = new Gtk.ListStore (11,
                typeof (string),   /* NAME */
                typeof (double),   /* CPU (sorting) */
                typeof (string),   /* CPU_TEXT */
                typeof (uint64),   /* MEM_KB (sorting) */
                typeof (string),   /* MEM_TEXT */
                typeof (string),   /* DISK_TEXT */
                typeof (int),      /* PID */
                typeof (int),      /* UID */
                typeof (uint64),   /* RSS_KB (sorting) */
                typeof (string),   /* RSS_TEXT */
                typeof (bool));    /* USS_OK */
            filtered = new Gtk.TreeModelFilter (store, null);
            filtered.set_visible_func ((model, iter) => {
                string query = search.get_text ().down ().strip ();
                if (query == "") {
                    return true;
                }
                /* NAME is still NULL while store.append() is running:
                 * the filter re-runs on row-inserted, before the
                 * store.set() that fills the row in. Without the guard
                 * every refresh logged a GLib-CRITICAL from
                 * g_utf8_strdown (seen in the G1/G2 Xvfb run). */
                string? name;
                model.get (iter, Col.NAME, out name);
                return name != null && query in name.down ();
            });
            sortable = new Gtk.TreeModelSort.with_model (filtered);
            sortable.set_sort_column_id ((int) Col.CPU,
                                         Gtk.SortType.DESCENDING);

            view = new Gtk.TreeView.with_model (sortable);
            /* Fixed row height: GTK does not measure every row (lower
             * drawing cost on a long list). */
            view.fixed_height_mode = true;
            append_column (_("Name"), Col.NAME, Col.NAME, true);
            cpu_column = append_column (_("CPU"), Col.CPU_TEXT, Col.CPU, false);
            mem_column = append_column (_("Memory"), Col.MEM_TEXT, Col.MEM_KB, false);
            append_column (_("Disk"), Col.DISK_TEXT, -1, false);
            rss_column = append_column (_("Memory (RSS)"), Col.RSS_TEXT,
                                        Col.RSS_KB, false);
            pid_column = append_column (_("PID"), Col.PID, Col.PID, false);
            rss_column.visible = false;
            pid_column.visible = false;
            /* Why USS needs a word: nobody expects "Memory" to mean
             * something other than what every other tool prints. */
            view.has_tooltip = true;
            view.query_tooltip.connect (on_query_tooltip);
            sortable.sort_column_changed.connect (update_sort_indicator);
            update_sort_indicator ();
            /* G3 in one sentence, where the question comes up. */
            unowned Gtk.Widget? cpu_header = cpu_column.get_button ();
            if (cpu_header != null) {
                cpu_header.set_tooltip_text (_("Share of the whole processor — all %d logical cores together, so the column adds up to the total.").printf (cpu_count));
            }
            /* G2: Delete ends, Shift+Delete kills — the same two
             * actions the context menu offers, on the selected row. */
            view.key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Delete) {
                    if ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0) {
                        kill_selected ();
                    } else {
                        end_selected ();
                    }
                    return true;
                }
                return false;
            });
            /* Right-click: select the row under the pointer first, so
             * the menu always acts on what the user aimed at. */
            view.button_press_event.connect ((event) => {
                if (event.type != Gdk.EventType.BUTTON_PRESS
                    || event.button != Gdk.BUTTON_SECONDARY) {
                    return false;
                }
                Gtk.TreePath path;
                if (view.get_path_at_pos ((int) event.x, (int) event.y,
                                          out path, null, null, null)) {
                    view.get_selection ().select_path (path);
                }
                show_context_menu (event);
                return true;
            });
            /* Keyboard menu key / Shift+F10: same menu, no pointer. */
            view.popup_menu.connect (() => {
                show_context_menu (null);
                return true;
            });
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.add (view);
            root.pack_start (scroll, true, true, 0);

            /* Sampling only while the page is visible (Stack unmaps). */
            root.map.connect (() => {
                refresh ();
                if (timer == 0) {
                    timer = Timeout.add_seconds (REFRESH_SECONDS, () => {
                        refresh ();
                        return Source.CONTINUE;
                    });
                }
            });
            root.unmap.connect (() => {
                if (timer != 0) {
                    Source.remove (timer);
                    timer = 0;
                }
            });
        }

        private Gtk.TreeViewColumn append_column (string title, Col text_col,
                                                  Col sort_col, bool expand) {
            var renderer = new Gtk.CellRendererText ();
            if (!expand) {
                renderer.xalign = 1.0f;
            } else {
                renderer.ellipsize = Pango.EllipsizeMode.END;
            }
            var column = new Gtk.TreeViewColumn.with_attributes (
                title, renderer, "text", (int) text_col);
            column.set_expand (expand);
            column.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
            /* Wide enough for "Memory  34% ▼" — G4's arrow lives in
             * the title, so the numeric columns need the room. */
            column.set_fixed_width (expand ? 300 : 130);
            if ((int) sort_col >= 0) {
                column.set_sort_column_id ((int) sort_col);
            }
            view.append_column (column);
            columns += column;
            base_titles += title;
            return column;
        }

        /* G4: title arrow + accent header on the sorted column. */
        private void set_base_title (Gtk.TreeViewColumn column,
                                     string title) {
            for (int i = 0; i < columns.length; i++) {
                if (columns[i] == column) {
                    base_titles[i] = title;
                    return;
                }
            }
        }

        private void update_sort_indicator () {
            int sort_col;
            Gtk.SortType order;
            sortable.get_sort_column_id (out sort_col, out order);
            bool descending = (order == Gtk.SortType.DESCENDING);
            for (int i = 0; i < columns.length; i++) {
                bool active = columns[i].get_sort_column_id () == sort_col;
                /* GTK's own triangle off: it would be a second, fainter
                 * arrow next to ours. */
                columns[i].set_sort_indicator (false);
                columns[i].title = active
                    ? "%s %s".printf (base_titles[i],
                                      descending ? "▼" : "▲")
                    : base_titles[i];
                unowned Gtk.Widget? header = columns[i].get_button ();
                if (header == null) {
                    continue;
                }
                unowned Gtk.StyleContext ctx = header.get_style_context ();
                if (active) {
                    ctx.add_class ("kavis-sorted");
                } else {
                    ctx.remove_class ("kavis-sorted");
                }
            }
        }

        /* The Memory column needs a sentence: it is USS, not the RSS
         * every other tool prints, and on another user's process it is
         * RSS after all because smaps_rollup is refused. */
        private bool on_query_tooltip (int x, int y, bool keyboard,
                                       Gtk.Tooltip tooltip) {
            if (keyboard) {
                return false;
            }
            int bx, by;
            view.convert_widget_to_bin_window_coords (x, y, out bx, out by);
            Gtk.TreePath? path;
            unowned Gtk.TreeViewColumn? column;
            if (!view.get_path_at_pos (bx, by, out path, out column,
                                       null, null) || column != mem_column) {
                return false;
            }
            Gtk.TreeIter iter;
            if (!view.get_model ().get_iter (out iter, path)) {
                return false;
            }
            bool uss_ok;
            view.get_model ().get (iter, Col.USS_OK, out uss_ok);
            tooltip.set_text (uss_ok
                ? _("Private memory (USS): what is really freed when this process ends. Shared libraries are not counted twice.")
                : _("Private memory cannot be read for another user's process — this is RSS, which counts shared libraries too."));
            view.set_tooltip_row (tooltip, path);
            return true;
        }

        /* The selected row, or false when nothing is selected. */
        private bool selected_row (out int pid, out int uid,
                                   out string name) {
            pid = 0;
            uid = -1;
            name = "";
            Gtk.TreeModel model;
            Gtk.TreeIter iter;
            if (!view.get_selection ().get_selected (out model, out iter)) {
                return false;
            }
            model.get (iter, Col.PID, out pid, Col.UID, out uid,
                       Col.NAME, out name);
            return pid > 0;
        }

        /* G2: the row menu. Built fresh per click (the selected pid is
         * baked into the handlers) and destroyed on close, like the
         * panel's taskbar menu. */
        private void show_context_menu (Gdk.EventButton? event) {
            int pid, uid;
            string name;
            if (!selected_row (out pid, out uid, out name)) {
                return;
            }
            var menu = new Gtk.Menu ();
            var end_item = new Gtk.MenuItem.with_label (_("End task"));
            end_item.activate.connect (() => end_selected ());
            menu.append (end_item);
            var kill_item = new Gtk.MenuItem.with_label (_("Kill"));
            kill_item.activate.connect (() => kill_selected ());
            menu.append (kill_item);
            menu.append (new Gtk.SeparatorMenuItem ());

            var location_item = new Gtk.MenuItem.with_label (
                _("Open file location"));
            string? exe = executable_of (pid);
            if (exe == null) {
                /* Another user's process: /proc/PID/exe is unreadable,
                 * so there is no folder to open. Greyed out rather than
                 * failing silently after the click. */
                location_item.set_sensitive (false);
            } else {
                string target = exe;
                location_item.activate.connect (() => reveal (target));
            }
            menu.append (location_item);

            var properties_item = new Gtk.MenuItem.with_label (
                _("Properties"));
            int the_pid = pid;
            int the_uid = uid;
            string the_name = name;
            properties_item.activate.connect (
                () => show_properties (the_pid, the_uid, the_name));
            menu.append (properties_item);

            menu.deactivate.connect (() => {
                Idle.add (() => {
                    menu.destroy ();
                    return Source.REMOVE;
                });
            });
            menu.show_all ();
            if (event != null) {
                menu.popup_at_pointer (event);
            } else {
                menu.popup_at_widget (view, Gdk.Gravity.CENTER,
                                      Gdk.Gravity.NORTH, null);
            }
        }

        /* SIGTERM. No confirmation (G2): the process gets to save and
         * exit on its own — except for a system process, where the
         * warning the task list asks for still applies. */
        private void end_selected () {
            int pid, uid;
            string name;
            if (!selected_row (out pid, out uid, out name)) {
                return;
            }
            if (uid == 0 && !confirm (
                    _("Ending this system process may cause problems. Continue?"),
                    "%s (PID %d)".printf (name, pid))) {
                return;
            }
            signal_pid (pid, Posix.Signal.TERM);
        }

        /* SIGKILL — always confirmed, and the dialog names the process:
         * nothing gets to save, so the user must mean it. */
        private void kill_selected () {
            int pid, uid;
            string name;
            if (!selected_row (out pid, out uid, out name)) {
                return;
            }
            if (!confirm (
                    _("Kill %s (PID %d)?").printf (name, pid),
                    _("The process is stopped at once. Unsaved work is lost."))) {
                return;
            }
            signal_pid (pid, Posix.Signal.KILL);
        }

        private bool confirm (string question, string detail) {
            var dialog = new Gtk.MessageDialog (this,
                Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING,
                Gtk.ButtonsType.NONE, "%s", question);
            dialog.format_secondary_text ("%s", detail);
            dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
            var go = dialog.add_button (_("Continue"), Gtk.ResponseType.OK);
            go.get_style_context ().add_class ("destructive-action");
            int response = dialog.run ();
            dialog.destroy ();
            return response == Gtk.ResponseType.OK;
        }

        private void signal_pid (int pid, int sig) {
            Posix.kill ((Posix.pid_t) pid, sig);
            Timeout.add (500, () => {
                refresh ();
                return Source.REMOVE;
            });
        }

        /* Show the executable in the file manager. Nemo selects the
         * file when handed a file path; without it, open the folder. */
        private static void reveal (string path) {
            string[] argv = (Environment.find_program_in_path ("nemo") != null)
                ? new string[] { "nemo", path }
                : new string[] { "xdg-open", Path.get_dirname (path) };
            try {
                Process.spawn_async (null, argv, null,
                    SpawnFlags.SEARCH_PATH
                    | SpawnFlags.STDOUT_TO_DEV_NULL
                    | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
            } catch (Error e) {
                warning ("kavis-taskmanager: could not start %s: %s",
                         argv[0], e.message);
            }
        }

        /* G2 properties dialog. Every field is read from /proc on
         * demand — a container (or someone else's process) hides most
         * of them, and an unreadable field shows an em dash rather
         * than a lie or an empty row. */
        private void show_properties (int pid, int uid, string name) {
            var dialog = new Gtk.Dialog.with_buttons (
                _("Properties"), this,
                Gtk.DialogFlags.MODAL | Gtk.DialogFlags.USE_HEADER_BAR,
                _("Close"), Gtk.ResponseType.CLOSE);
            dialog.set_default_size (460, -1);

            var grid = new Gtk.Grid ();
            grid.row_spacing = 8;
            grid.column_spacing = 16;
            grid.margin = 16;
            int row = 0;

            /* CPU and memory come from the row we already sampled —
             * re-reading /proc here would show 0% (no previous tick). */
            string cpu_text = MISSING;
            string rss_text = MISSING;
            Gtk.TreeModel model;
            Gtk.TreeIter iter;
            if (view.get_selection ().get_selected (out model, out iter)) {
                model.get (iter, Col.CPU_TEXT, out cpu_text,
                           Col.RSS_TEXT, out rss_text);
            }

            add_property (grid, ref row, _("Name"), name);
            add_property (grid, ref row, _("PID"), pid.to_string ());
            add_property (grid, ref row, _("User"), user_name (uid));
            add_property (grid, ref row, _("Command line"),
                          text_or_dash (string.joinv (" ", argv_of (pid))));
            add_property (grid, ref row, _("Working directory"),
                          text_or_dash (link_target (pid, "cwd")));
            add_property (grid, ref row, _("Executable"),
                          text_or_dash (link_target (pid, "exe")));
            add_property (grid, ref row, _("CPU"), text_or_dash (cpu_text));
            add_property (grid, ref row, _("Memory (RSS)"),
                          text_or_dash (rss_text));
            add_property (grid, ref row, _("Memory (USS)"), uss_text (pid));
            add_property (grid, ref row, _("Start time"), start_time (pid));

            dialog.get_content_area ().add (grid);
            dialog.show_all ();
            dialog.run ();
            dialog.destroy ();
        }

        private static void add_property (Gtk.Grid grid, ref int row,
                                          string label, string value) {
            var key = new Gtk.Label (label);
            key.set_xalign (0);
            key.set_valign (Gtk.Align.START);
            key.get_style_context ().add_class ("dim-label");
            grid.attach (key, 0, row, 1, 1);
            var val = new Gtk.Label (value);
            val.set_xalign (0);
            val.set_selectable (true);   /* long paths are copyable */
            val.set_line_wrap (true);
            val.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
            /* width_chars, not only max_width_chars: WORD_CHAR lets a
             * long path break anywhere, so the label's MINIMUM width is
             * one character and GTK's height-for-width then asks for a
             * window thousands of pixels tall (measured: 3666 px). A
             * definite minimum width pins the wrap where we want it. */
            val.set_width_chars (46);
            val.set_max_width_chars (46);
            grid.attach (val, 1, row, 1, 1);
            row++;
        }

        private static string text_or_dash (string? value) {
            return (value == null || value.strip () == "") ? MISSING : value;
        }

        private static string user_name (int uid) {
            if (uid < 0) {
                return MISSING;
            }
            unowned Posix.Passwd? pw = Posix.getpwuid ((Posix.uid_t) uid);
            return (pw != null && pw.pw_name != null)
                ? "%s (%d)".printf (pw.pw_name, uid) : uid.to_string ();
        }

        private static string? link_target (int pid, string name) {
            try {
                return FileUtils.read_link (
                    "/proc/%d/%s".printf (pid, name));
            } catch (FileError e) {
                return null;   /* not ours, or already gone */
            }
        }

        /* Unique Set Size: the memory that dies with this process.
         * smaps_rollup is readable only for our own processes. */
        private static string uss_text (int pid) {
            uint64 kb = read_uss_kb (pid);
            return (kb > 0) ? SysInfo.format_bytes (kb * 1024) : MISSING;
        }

        private static string start_time (int pid) {
            string stat;
            try {
                FileUtils.get_contents ("/proc/%d/stat".printf (pid),
                                        out stat);
            } catch (Error e) {
                return MISSING;
            }
            int close = stat.last_index_of_char (')');
            if (close < 0) {
                return MISSING;
            }
            /* rest[19] is field 22, starttime in clock ticks after boot. */
            string[] rest = stat.substring (close + 2).split (" ");
            if (rest.length < 20) {
                return MISSING;
            }
            long hz = Posix.sysconf (Posix._SC_CLK_TCK);
            int64 boot = boot_time ();
            if (hz <= 0 || boot <= 0) {
                return MISSING;
            }
            int64 started = boot + (int64) (uint64.parse (rest[19]) / hz);
            return new DateTime.from_unix_local (started)
                .format ("%Y-%m-%d %H:%M:%S");
        }

        /* Seconds since the epoch at boot — /proc/stat "btime". */
        private static int64 boot_time () {
            string contents;
            try {
                FileUtils.get_contents ("/proc/stat", out contents);
            } catch (Error e) {
                return 0;
            }
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix ("btime ")) {
                    return int64.parse (line.substring (6).strip ());
                }
            }
            return 0;
        }

        /* Executable path, or null when /proc/PID/exe is not ours. */
        private static string? executable_of (int pid) {
            string? exe = link_target (pid, "exe");
            if (exe == null) {
                return null;
            }
            exe = exe.replace (" (deleted)", "");
            return FileUtils.test (exe, FileTest.EXISTS) ? exe : null;
        }

        private void refresh () {
            int64 started_us = get_monotonic_time ();
            uint64 busy, total;
            SysInfo.cpu_jiffies (out busy, out total);
            uint64 jiffy_delta = (prev_total_jiffies > 0 && total > prev_total_jiffies)
                ? total - prev_total_jiffies : 0;
            double cpu_total_pct = (jiffy_delta > 0)
                ? 100.0 * (busy - prev_busy_jiffies) / jiffy_delta : 0;
            prev_total_jiffies = total;
            prev_busy_jiffies = busy;

            samples.foreach ((pid, s) => { s.seen = false; });

            Dir dir;
            try {
                dir = Dir.open ("/proc");
            } catch (Error e) {
                return;
            }
            int shown = 0;
            unowned string? entry;
            while ((entry = dir.read_name ()) != null) {
                int pid = int.parse (entry);
                if (pid <= 0) {
                    continue;
                }
                if (update_process (pid, jiffy_delta)) {
                    shown++;
                }
            }
            /* Rows of vanished processes. */
            var gone = new GenericArray<int> ();
            samples.foreach ((pid, s) => {
                if (!s.seen) {
                    gone.add (pid);
                }
            });
            for (int i = 0; i < gone.length; i++) {
                var s = samples.lookup (gone[i]);
                store.remove (ref s.iter);
                samples.remove (gone[i]);
            }

            /* Totals: top line + column headers. The memory figure is
             * free(1)'s "used" — MemTotal minus MemAvailable (RAM
             * cleanup item 1); SysInfo.memory() computes exactly that,
             * so the line means the same thing as the panel's. */
            uint64 mt, mu, mc, st, su;
            SysInfo.memory (out mt, out mu, out mc, out st, out su);
            double mem_pct = (mt > 0) ? 100.0 * mu / mt : 0;
            totals.set_text (_("CPU %.0f%%   ·   Memory %s / %s (%.0f%%)   ·   %d processes")
                .printf (cpu_total_pct, SysInfo.format_bytes (mu),
                         SysInfo.format_bytes (mt), mem_pct, shown));
            set_base_title (cpu_column,
                "%s  %.0f%%".printf (_("CPU"), cpu_total_pct));
            set_base_title (mem_column,
                "%s  %.0f%%".printf (_("Memory"), mem_pct));
            update_sort_indicator ();

            if (profile) {
                printerr ("kavis-taskmanager: refresh %d processes in %.1f ms\n",
                          shown,
                          (get_monotonic_time () - started_us) / 1000.0);
            }
        }

        /* One process, one file read. Returns false for hidden rows. */
        private bool update_process (int pid, uint64 jiffy_delta) {
            string stat;
            try {
                FileUtils.get_contents ("/proc/%d/stat".printf (pid), out stat);
            } catch (Error e) {
                return false;
            }
            int close = stat.last_index_of_char (')');
            if (close < 0) {
                return false;
            }
            string[] rest = stat.substring (close + 2).split (" ");
            /* rest: 0 state … 11 utime 12 stime … 21 rss(pages) */
            if (rest.length < 22) {
                return false;
            }
            uint64 ticks = uint64.parse (rest[11]) + uint64.parse (rest[12]);
            uint64 rss_kb = uint64.parse (rest[21]) * page_kb;

            Sample? s = samples.lookup (pid);
            if (s == null) {
                /* Kernel thread (empty cmdline) hidden — like W11. */
                string name = process_name (pid);
                if (name == null) {
                    return false;
                }
                s = new Sample ();
                s.name = name;
                s.uid = owner_uid (pid);
                s.io_readable = (s.uid == own_uid);
                /* root reads everyone's smaps_rollup; a normal session
                 * reads only its own. */
                s.uss_readable = (own_uid == 0 || s.uid == own_uid);
                s.ticks = ticks;
                store.append (out s.iter);
                store.set (s.iter, Col.NAME, name, Col.PID, pid, Col.UID, s.uid);
                samples.insert (pid, s);
            }
            s.seen = true;

            /* G3: same denominator as the total — no core-count
             * factor, so the column sums to the figure on top. */
            double cpu_percent = 0;
            if (jiffy_delta > 0 && ticks >= s.ticks) {
                cpu_percent = 100.0 * (ticks - s.ticks) / jiffy_delta;
            }
            s.ticks = ticks;

            string disk_text = MISSING;
            if (s.io_readable) {
                uint64 io = read_io_bytes (pid);
                if (io > 0 || s.io_bytes > 0) {
                    uint64 per_second = (io >= s.io_bytes)
                        ? (io - s.io_bytes) / REFRESH_SECONDS : 0;
                    disk_text = SysInfo.format_bytes (per_second) + "/s";
                }
                s.io_bytes = io;
            }

            /* USS: one more open+read per process. Measured with
             * KAVIS_TASKMANAGER_PROFILE=1 over 222 processes: 7.5 ms
             * per pass without it, 32 ms with it (worst pass 63 ms) —
             * inside the ~80 ms budget for a 2-second tick, so every
             * row is read and not only the visible ones. If a bigger
             * machine ever passes that budget, this is the read to
             * make lazy. */
            uint64 mem_kb = rss_kb;
            bool uss_ok = false;
            if (s.uss_readable) {
                uint64 uss_kb = read_uss_kb (pid);
                if (uss_kb > 0) {
                    mem_kb = uss_kb;
                    uss_ok = true;
                } else {
                    /* Refused after all (a kernel without the page
                     * monitor, or a zombie): stop asking. */
                    s.uss_readable = false;
                }
            }

            store.set (s.iter,
                Col.CPU, cpu_percent,
                Col.CPU_TEXT, "%.1f%%".printf (cpu_percent),
                Col.MEM_KB, mem_kb,
                Col.MEM_TEXT, SysInfo.format_bytes (mem_kb * 1024),
                Col.RSS_KB, rss_kb,
                Col.RSS_TEXT, SysInfo.format_bytes (rss_kb * 1024),
                Col.USS_OK, uss_ok,
                Col.DISK_TEXT, disk_text);
            return true;
        }

        /* Unique Set Size in KB: smaps_rollup's Private_* lines — the
         * pages that die with the process. 0 when the file is not
         * readable (another user's process) or carries no such line. */
        private static uint64 read_uss_kb (int pid) {
            string contents;
            try {
                FileUtils.get_contents (
                    "/proc/%d/smaps_rollup".printf (pid), out contents);
            } catch (Error e) {
                return 0;
            }
            uint64 kb = 0;
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix ("Private_")) {
                    kb += uint64.parse (line.split (":")[1].strip ());
                }
            }
            return kb;
        }

        /* The process' argv. cmdline is NUL-separated: reading it as a
         * string cuts at the first NUL (Vala cannot split on "\0" —
         * GLib-CRITICAL, bug-scan finding), so it is parsed from the
         * raw byte array. Empty for kernel threads and for a pid that
         * vanished between the readdir and here. */
        private static string[] argv_of (int pid) {
            uint8[] raw;
            try {
                FileUtils.get_data ("/proc/%d/cmdline".printf (pid), out raw);
            } catch (Error e) {
                return {};
            }
            string[] argv = {};
            int start = 0;
            for (int i = 0; i < raw.length; i++) {
                if (raw[i] == 0) {
                    argv += (string) raw[start:i];
                    start = i + 1;
                }
            }
            if (start < raw.length) {
                argv += (string) raw[start:raw.length];
            }
            return argv;
        }

        /* Display name: exe basename (e.g. "kavis-panel", not a thread's
         * comm like "MainThread"); null for kernel threads. */
        private static string? process_name (int pid) {
            string[] argv = argv_of (pid);
            if (argv.length == 0 || argv[0] == "") {
                return null;
            }
            try {
                string exe = FileUtils.read_link ("/proc/%d/exe".printf (pid));
                string base_name = Path.get_basename (exe).replace (" (deleted)", "");
                /* Interpreters (python3, sh): the script name is more meaningful. */
                if (base_name.has_prefix ("python") || base_name == "sh"
                    || base_name == "bash" || base_name == "perl") {
                    if (argv.length > 1 && argv[1] != "" && !argv[1].has_prefix ("-")) {
                        return base_name + " " + Path.get_basename (argv[1]);
                    }
                }
                return base_name;
            } catch (FileError e) {
                /* Someone else's process: exe unreadable, argv[0] stays. */
                return Path.get_basename (argv[0]);
            }
        }

        private static int owner_uid (int pid) {
            Posix.Stat st;
            if (Posix.stat ("/proc/%d".printf (pid), out st) == 0) {
                return (int) st.st_uid;
            }
            return -1;
        }

        private static uint64 read_io_bytes (int pid) {
            string io;
            try {
                FileUtils.get_contents ("/proc/%d/io".printf (pid), out io);
            } catch (Error e) {
                return 0;
            }
            uint64 total = 0;
            foreach (unowned string line in io.split ("\n")) {
                if (line.has_prefix ("read_bytes:") || line.has_prefix ("write_bytes:")) {
                    total += uint64.parse (line.split (":")[1].strip ());
                }
            }
            return total;
        }
    }
}
