/* Task manager (madde 7): process list with CPU / RAM / disk columns,
 * search filter and end-task. Reads /proc directly — no dependency on
 * libgtop or similar; the panel's RAM rules apply here too.
 *
 * CPU%: delta of utime+stime against the delta of the machine-wide
 * jiffy counter between refreshes. Disk: delta of read_bytes +
 * write_bytes from /proc/PID/io per second ("-" where unreadable —
 * other users' processes hide it). First refresh shows 0% CPU by
 * design (no previous sample to diff against).
 */

namespace Kavis.Tools {

    public class TaskManagerWindow : Gtk.Window {

        private const int REFRESH_SECONDS = 2;

        private Gtk.ListStore store;
        private Gtk.TreeModelFilter filtered;
        private Gtk.TreeView view;
        private Gtk.SearchEntry search;

        /* pid → previous sample. */
        private HashTable<int, uint64?> prev_cpu =
            new HashTable<int, uint64?> (direct_hash, direct_equal);
        private HashTable<int, uint64?> prev_io =
            new HashTable<int, uint64?> (direct_hash, direct_equal);
        private uint64 prev_total_jiffies = 0;

        private enum Col { NAME, CPU, CPU_TEXT, MEM_KB, MEM_TEXT,
                           DISK_TEXT, PID, UID }

        public TaskManagerWindow () {
            set_title (_("Task Manager"));
            set_default_size (620, 480);
            /* W11 başlık çubuğu (geri bildirim A) — Ayarlar'la aynı. */
            Kavis.HeaderBar.attach (this, _("Task Manager"),
                                    "utilities-system-monitor");

            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            root.set_border_width (10);
            /* H (v0.4-test1): W11 gibi solda gezinti — Süreçler /
             * Performans / Başlangıç / Günlükler. Stack görünmeyen
             * sayfayı unmap eder: Performans ölçümü kapalıyken durur. */
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
            set_default_size (860, 560);

            var top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            search = new Gtk.SearchEntry ();
            search.search_changed.connect (() => filtered.refilter ());
            top.pack_start (search, true, true, 0);
            var end_button = new Gtk.Button.with_label (
                _("End task"));
            end_button.clicked.connect (() => end_selected (false));
            top.pack_end (end_button, false, false, 0);
            root.pack_start (top, false, false, 0);

            store = new Gtk.ListStore (8,
                typeof (string),   /* NAME */
                typeof (double),   /* CPU (sıralama) */
                typeof (string),   /* CPU_TEXT */
                typeof (uint64),   /* MEM_KB (sıralama) */
                typeof (string),   /* MEM_TEXT */
                typeof (string),   /* DISK_TEXT */
                typeof (int),      /* PID */
                typeof (int));     /* UID */
            filtered = new Gtk.TreeModelFilter (store, null);
            filtered.set_visible_func ((model, iter) => {
                string query = search.get_text ().down ().strip ();
                if (query == "") {
                    return true;
                }
                string name;
                model.get (iter, Col.NAME, out name);
                return query in name.down ();
            });
            var sortable = new Gtk.TreeModelSort.with_model (filtered);
            sortable.set_sort_column_id ((int) Col.CPU,
                                         Gtk.SortType.DESCENDING);

            view = new Gtk.TreeView.with_model (sortable);
            append_column (_("Name"), Col.NAME, Col.NAME,
                           true);
            append_column (_("CPU"), Col.CPU_TEXT, Col.CPU,
                           false);
            append_column (_("Memory"), Col.MEM_TEXT,
                           Col.MEM_KB, false);
            append_column (_("Disk"), Col.DISK_TEXT, -1,
                           false);
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.add (view);
            root.pack_start (scroll, true, true, 0);

            refresh ();
            Timeout.add_seconds (REFRESH_SECONDS, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private void append_column (string title, Col text_col,
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
            if ((int) sort_col >= 0) {
                column.set_sort_column_id ((int) sort_col);
            }
            view.append_column (column);
        }

        private void end_selected (bool force) {
            Gtk.TreeModel model;
            Gtk.TreeIter iter;
            if (!view.get_selection ().get_selected (out model, out iter)) {
                return;
            }
            int pid, uid;
            model.get (iter, Col.PID, out pid, Col.UID, out uid);

            /* Kök (sistem) işlemi: madde gereği uyar, onaysız dokunma. */
            if (uid == 0) {
                var dialog = new Gtk.MessageDialog (this,
                    Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING,
                    Gtk.ButtonsType.YES_NO, "%s",
                    _("Ending this system process may cause problems. Continue?"));
                int response = dialog.run ();
                dialog.destroy ();
                if (response != Gtk.ResponseType.YES) {
                    return;
                }
            }
            Posix.kill ((Posix.pid_t) pid,
                        force ? Posix.Signal.KILL : Posix.Signal.TERM);
            Timeout.add (500, () => {
                refresh ();
                return Source.REMOVE;
            });
        }

        private static uint64 total_jiffies () {
            string contents;
            try {
                FileUtils.get_contents ("/proc/stat", out contents);
            } catch (Error e) {
                return 0;
            }
            /* "cpu  user nice system idle iowait irq softirq ..." */
            string[] fields = contents.split ("\n")[0].split (" ");
            uint64 total = 0;
            foreach (unowned string f in fields[1:fields.length]) {
                if (f != "") {
                    total += uint64.parse (f);
                }
            }
            return total;
        }

        private void refresh () {
            uint64 jiffies = total_jiffies ();
            uint64 jiffy_delta = (prev_total_jiffies > 0)
                ? jiffies - prev_total_jiffies : 0;

            var next_cpu = new HashTable<int, uint64?> (
                direct_hash, direct_equal);
            var next_io = new HashTable<int, uint64?> (
                direct_hash, direct_equal);
            int cpu_count = (int) get_num_processors ();

            store.clear ();
            Dir dir;
            try {
                dir = Dir.open ("/proc");
            } catch (Error e) {
                return;
            }
            unowned string? entry;
            while ((entry = dir.read_name ()) != null) {
                int pid = int.parse (entry);
                if (pid <= 0) {
                    continue;
                }
                add_process (pid, jiffy_delta, cpu_count,
                             next_cpu, next_io);
            }
            prev_cpu = next_cpu;
            prev_io = next_io;
            prev_total_jiffies = jiffies;
        }

        private void add_process (int pid, uint64 jiffy_delta,
                                  int cpu_count,
                                  HashTable<int, uint64?> next_cpu,
                                  HashTable<int, uint64?> next_io) {
            string stat;
            try {
                FileUtils.get_contents ("/proc/%d/stat".printf (pid),
                                        out stat);
            } catch (Error e) {
                return;
            }
            /* comm parantezlidir ve boşluk içerebilir. */
            int open = stat.index_of_char ('(');
            int close = stat.last_index_of_char (')');
            if (open < 0 || close < 0) {
                return;
            }
            string name = stat.substring (open + 1, close - open - 1);
            string[] rest = stat.substring (close + 2).split (" ");
            /* rest[0]=state, utime=rest[11], stime=rest[12] (man proc). */
            if (rest.length < 13) {
                return;
            }
            uint64 ticks = uint64.parse (rest[11])
                + uint64.parse (rest[12]);
            next_cpu.insert (pid, ticks);

            double cpu_percent = 0;
            uint64? prev = prev_cpu.lookup (pid);
            if (prev != null && jiffy_delta > 0) {
                cpu_percent = 100.0 * (ticks - prev) * cpu_count
                    / jiffy_delta;
            }

            uint64 rss_kb = read_rss_kb (pid);
            int uid = read_uid (pid);

            string disk_text = "-";
            uint64 io_bytes = read_io_bytes (pid);
            if (io_bytes > 0 || prev_io.lookup (pid) != null) {
                next_io.insert (pid, io_bytes);
                uint64? prev_bytes = prev_io.lookup (pid);
                if (prev_bytes != null) {
                    uint64 per_second = (io_bytes - prev_bytes)
                        / REFRESH_SECONDS;
                    disk_text = format_bytes (per_second) + "/s";
                }
            }

            Gtk.TreeIter iter;
            store.append (out iter);
            store.set (iter,
                Col.NAME, name,
                Col.CPU, cpu_percent,
                Col.CPU_TEXT, "%.1f%%".printf (cpu_percent),
                Col.MEM_KB, rss_kb,
                Col.MEM_TEXT, format_bytes (rss_kb * 1024),
                Col.DISK_TEXT, disk_text,
                Col.PID, pid,
                Col.UID, uid);
        }

        private static uint64 read_rss_kb (int pid) {
            string status;
            try {
                FileUtils.get_contents ("/proc/%d/status".printf (pid),
                                        out status);
            } catch (Error e) {
                return 0;
            }
            foreach (unowned string line in status.split ("\n")) {
                if (line.has_prefix ("VmRSS:")) {
                    return uint64.parse (line.replace ("VmRSS:", "")
                                         .replace ("kB", "").strip ());
                }
            }
            return 0;
        }

        private static int read_uid (int pid) {
            string status;
            try {
                FileUtils.get_contents ("/proc/%d/status".printf (pid),
                                        out status);
            } catch (Error e) {
                return -1;
            }
            foreach (unowned string line in status.split ("\n")) {
                if (line.has_prefix ("Uid:")) {
                    return int.parse (line.substring (4).strip ()
                                      .split ("\t")[0]);
                }
            }
            return -1;
        }

        private static uint64 read_io_bytes (int pid) {
            string io;
            try {
                FileUtils.get_contents ("/proc/%d/io".printf (pid),
                                        out io);
            } catch (Error e) {
                return 0;
            }
            uint64 total = 0;
            foreach (unowned string line in io.split ("\n")) {
                if (line.has_prefix ("read_bytes:")
                    || line.has_prefix ("write_bytes:")) {
                    total += uint64.parse (
                        line.split (":")[1].strip ());
                }
            }
            return total;
        }

        private static string format_bytes (uint64 bytes) {
            if (bytes >= 1024uL * 1024 * 1024) {
                return "%.1f GB".printf (bytes / (1024.0 * 1024 * 1024));
            }
            if (bytes >= 1024 * 1024) {
                return "%.1f MB".printf (bytes / (1024.0 * 1024));
            }
            if (bytes >= 1024) {
                return "%.0f KB".printf (bytes / 1024.0);
            }
            return "%llu B".printf (bytes);
        }
    }
}
