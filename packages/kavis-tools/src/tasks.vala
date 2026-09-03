/* Task manager (madde 7): process list with CPU / RAM / disk columns,
 * totals on top, search filter and end-task. Reads /proc directly — no
 * dependency on libgtop or similar; the panel's RAM rules apply here.
 *
 * Cost model (optimizasyon turu): ONE file per process per tick
 * (/proc/PID/stat carries utime, stime AND rss pages), the name is
 * resolved once per pid from /proc/PID/exe (cached until the pid
 * vanishes), uid comes from a stat(2) on the /proc/PID directory, and
 * /proc/PID/io is read only for processes we own (root-owned ones are
 * unreadable anyway). Rows are updated IN PLACE keyed by pid — no
 * store.clear(): no flicker, the selection and sort order survive.
 * Kernel threads (empty cmdline) are hidden like Windows does. The
 * 2-second tick runs only while the Processes page is mapped.
 *
 * CPU%: delta of utime+stime against the delta of the machine-wide
 * jiffy counter between refreshes, scaled by CPU count so one busy
 * core reads 100% like Windows. First refresh shows 0% by design.
 */

namespace Kavis.Tools {

    public class TaskManagerWindow : Gtk.Window {

        private const int REFRESH_SECONDS = 2;

        private Gtk.ListStore store;
        private Gtk.TreeModelFilter filtered;
        private Gtk.TreeView view;
        private Gtk.SearchEntry search;
        private Gtk.Label totals;
        private Gtk.TreeViewColumn cpu_column;
        private Gtk.TreeViewColumn mem_column;
        private uint timer = 0;

        private class Sample : Object {
            public uint64 ticks;
            public uint64 io_bytes;
            public bool io_readable;
            public string name;
            public int uid;
            public Gtk.TreeIter iter;
            public bool seen;
        }
        /* pid → son örnek + satır. */
        private HashTable<int, Sample> samples =
            new HashTable<int, Sample> (direct_hash, direct_equal);
        private uint64 prev_total_jiffies = 0;
        private uint64 prev_busy_jiffies = 0;
        private long page_kb = 4;
        private int cpu_count = 1;
        private int own_uid = 0;

        private enum Col { NAME, CPU, CPU_TEXT, MEM_KB, MEM_TEXT,
                           DISK_TEXT, PID, UID }

        public TaskManagerWindow () {
            set_title (_("Task Manager"));
            /* W11 başlık çubuğu (geri bildirim A) — Ayarlar'la aynı. */
            Kavis.HeaderBar.attach (this, _("Task Manager"),
                                    "utilities-system-monitor");
            page_kb = Posix.sysconf (Posix._SC_PAGESIZE) / 1024;
            cpu_count = (int) get_num_processors ();
            own_uid = (int) Posix.getuid ();

            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            root.set_border_width (10);
            /* H (v0.4-test1): W11 gibi solda gezinti — Süreçler /
             * Performans / Başlangıç / Günlükler. Stack görünmeyen
             * sayfayı unmap eder: ölçümler kapalıyken durur. */
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

            /* Üstte toplamlar: W11'in "CPU 22% · Bellek 50%" satırı. */
            totals = new Gtk.Label ("");
            totals.set_xalign (0);
            totals.get_style_context ().add_class ("dim-label");
            root.pack_start (totals, false, false, 0);

            var top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            search = new Gtk.SearchEntry ();
            search.placeholder_text = _("Search");
            search.search_changed.connect (() => filtered.refilter ());
            top.pack_start (search, true, true, 0);
            var end_button = new Gtk.Button.with_label (_("End task"));
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
            /* Satır yüksekliği sabit: GTK her satırı ölçmez (uzun
             * listede çizim maliyeti düşer). */
            view.fixed_height_mode = true;
            append_column (_("Name"), Col.NAME, Col.NAME, true);
            cpu_column = append_column (_("CPU"), Col.CPU_TEXT, Col.CPU, false);
            mem_column = append_column (_("Memory"), Col.MEM_TEXT, Col.MEM_KB, false);
            append_column (_("Disk"), Col.DISK_TEXT, -1, false);
            view.key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Delete) {
                    end_selected ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0);
                    return true;
                }
                return false;
            });
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.add (view);
            root.pack_start (scroll, true, true, 0);

            /* Ölçüm yalnız sayfa görünürken (Stack unmap eder). */
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
            column.set_fixed_width (expand ? 320 : 110);
            if ((int) sort_col >= 0) {
                column.set_sort_column_id ((int) sort_col);
            }
            view.append_column (column);
            return column;
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

        private void refresh () {
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
            /* Kaybolan süreçlerin satırları. */
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

            /* Toplamlar: üst satır + sütun başlıkları. */
            uint64 mt, mu, mc, st, su;
            SysInfo.memory (out mt, out mu, out mc, out st, out su);
            double mem_pct = (mt > 0) ? 100.0 * mu / mt : 0;
            totals.set_text (_("CPU %.0f%%   ·   Memory %s / %s (%.0f%%)   ·   %d processes")
                .printf (cpu_total_pct, SysInfo.format_bytes (mu),
                         SysInfo.format_bytes (mt), mem_pct, shown));
            cpu_column.title = "%s  %.0f%%".printf (_("CPU"), cpu_total_pct);
            mem_column.title = "%s  %.0f%%".printf (_("Memory"), mem_pct);
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
                /* Çekirdek iş parçacığı (cmdline boş) gizli — W11 gibi. */
                string name = process_name (pid);
                if (name == null) {
                    return false;
                }
                s = new Sample ();
                s.name = name;
                s.uid = owner_uid (pid);
                s.io_readable = (s.uid == own_uid);
                s.ticks = ticks;
                store.append (out s.iter);
                store.set (s.iter, Col.NAME, name, Col.PID, pid, Col.UID, s.uid);
                samples.insert (pid, s);
            }
            s.seen = true;

            double cpu_percent = 0;
            if (jiffy_delta > 0 && ticks >= s.ticks) {
                cpu_percent = 100.0 * (ticks - s.ticks) * cpu_count / jiffy_delta;
            }
            s.ticks = ticks;

            string disk_text = "—";
            if (s.io_readable) {
                uint64 io = read_io_bytes (pid);
                if (io > 0 || s.io_bytes > 0) {
                    uint64 per_second = (io >= s.io_bytes)
                        ? (io - s.io_bytes) / REFRESH_SECONDS : 0;
                    disk_text = SysInfo.format_bytes (per_second) + "/s";
                }
                s.io_bytes = io;
            }

            store.set (s.iter,
                Col.CPU, cpu_percent,
                Col.CPU_TEXT, "%.1f%%".printf (cpu_percent),
                Col.MEM_KB, rss_kb,
                Col.MEM_TEXT, SysInfo.format_bytes (rss_kb * 1024),
                Col.DISK_TEXT, disk_text);
            return true;
        }

        /* Display name: exe basename (e.g. "kavis-panel", not a thread's
         * comm like "MainThread"); null for kernel threads. */
        private static string? process_name (int pid) {
            /* cmdline NUL ayrılmış: string olarak okumak ilk NUL'da
             * keser (Vala "\0" ile split edilemez — GLib-CRITICAL,
             * hata taraması bulgusu). Ham bayt dizisinden ayrıştırılır. */
            uint8[] raw;
            try {
                FileUtils.get_data ("/proc/%d/cmdline".printf (pid), out raw);
            } catch (Error e) {
                return null;
            }
            if (raw.length == 0) {
                return null;   /* çekirdek iş parçacığı */
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
            if (argv.length == 0 || argv[0] == "") {
                return null;
            }
            try {
                string exe = FileUtils.read_link ("/proc/%d/exe".printf (pid));
                string base_name = Path.get_basename (exe).replace (" (deleted)", "");
                /* Yorumlayıcılar (python3, sh): betiğin adı daha anlamlı. */
                if (base_name.has_prefix ("python") || base_name == "sh"
                    || base_name == "bash" || base_name == "perl") {
                    if (argv.length > 1 && argv[1] != "" && !argv[1].has_prefix ("-")) {
                        return base_name + " " + Path.get_basename (argv[1]);
                    }
                }
                return base_name;
            } catch (FileError e) {
                /* Başkasının süreci: exe okunamaz, argv[0] kalır. */
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
