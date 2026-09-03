/* Task Manager — Performance tab (v0.4-test1 H1, madde 49/50).
 *
 * W11 layout: a list on the left (CPU, Memory, each disk, each
 * network interface, GPU) with a live figure, a 60-second graph and
 * a detail grid on the right. Sampling runs ONLY while the page is
 * mapped (Gtk.Stack unmaps hidden children) — closed tab = zero cost.
 * All readers live in Kavis.SysInfo (shared with Settings > About).
 */

namespace Kavis.Tools {

    /* 60-sample line graph, teal on the card surface. */
    public class Graph : Gtk.DrawingArea {
        private const int SAMPLES = 60;
        private double[] values = new double[SAMPLES];
        private int head = 0;
        public double max_value = 100;   /* 100 for percentages */
        public bool auto_scale = false;  /* for bytes/s */

        public Graph () {
            set_size_request (-1, 160);
        }

        public void push (double v) {
            values[head] = v;
            head = (head + 1) % SAMPLES;
            if (auto_scale) {
                double m = 1;
                foreach (double x in values) {
                    if (x > m) {
                        m = x;
                    }
                }
                max_value = m;
            }
            queue_draw ();
        }

        public override bool draw (Cairo.Context cr) {
            int w = get_allocated_width ();
            int h = get_allocated_height ();
            unowned Gtk.StyleContext ctx = get_style_context ();
            Gdk.RGBA fg = ctx.get_color (Gtk.StateFlags.NORMAL);
            /* grid: 4 horizontal lines, 15% opaque */
            cr.set_source_rgba (fg.red, fg.green, fg.blue, 0.15);
            cr.set_line_width (1);
            for (int i = 1; i < 4; i++) {
                double y = Math.floor (h * i / 4.0) + 0.5;
                cr.move_to (0, y);
                cr.line_to (w, y);
            }
            cr.stroke ();
            /* line + fill */
            cr.set_source_rgba (0x2D / 255.0, 0xD4 / 255.0, 0xBF / 255.0, 1);
            cr.set_line_width (2);
            for (int i = 0; i < SAMPLES; i++) {
                double v = values[(head + i) % SAMPLES];
                double x = (double) w * i / (SAMPLES - 1);
                double y = h - (v / max_value) * (h - 4) - 2;
                if (i == 0) {
                    cr.move_to (x, y);
                } else {
                    cr.line_to (x, y);
                }
            }
            cr.stroke_preserve ();
            cr.line_to (w, h);
            cr.line_to (0, h);
            cr.close_path ();
            cr.set_source_rgba (0x2D / 255.0, 0xD4 / 255.0, 0xBF / 255.0, 0.18);
            cr.fill ();
            return true;
        }
    }

    public class PerformancePage : Gtk.Box {

        private class Item : Object {
            public string id;
            public Gtk.Label title;
            public Gtk.Label figure;
            public Gtk.ListBoxRow row;
        }

        private Gtk.ListBox list;
        private Gtk.Stack detail;
        private Item[] items = {};
        private uint timer = 0;

        /* sample history */
        private uint64 prev_busy = 0;
        private uint64 prev_total = 0;
        private HashTable<string, uint64?> prev_disk_r =
            new HashTable<string, uint64?> (str_hash, str_equal);
        private HashTable<string, uint64?> prev_disk_w =
            new HashTable<string, uint64?> (str_hash, str_equal);
        private HashTable<string, uint64?> prev_rx =
            new HashTable<string, uint64?> (str_hash, str_equal);
        private HashTable<string, uint64?> prev_tx =
            new HashTable<string, uint64?> (str_hash, str_equal);

        /* per-page graph + detail labels */
        private HashTable<string, Graph> graphs =
            new HashTable<string, Graph> (str_hash, str_equal);
        private HashTable<string, Gtk.Label> facts =
            new HashTable<string, Gtk.Label> (str_hash, str_equal);

        public PerformancePage () {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);

            list = new Gtk.ListBox ();
            list.set_size_request (200, -1);
            list.selection_mode = Gtk.SelectionMode.SINGLE;
            list.get_style_context ().add_class ("kavis-perf-list");
            detail = new Gtk.Stack ();
            detail.transition_type = Gtk.StackTransitionType.CROSSFADE;

            add_item ("cpu", _("CPU"));
            add_item ("mem", _("Memory"));
            foreach (unowned SysInfo.Disk d in SysInfo.disks ()) {
                add_item ("disk:" + d.name, _("Disk") + " (" + d.name + ")");
            }
            foreach (unowned SysInfo.Iface i in SysInfo.interfaces ()) {
                add_item ("net:" + i.name, _("Network") + " (" + i.name + ")");
            }
            add_item ("gpu", _("GPU"));

            list.row_selected.connect ((row) => {
                if (row == null) {
                    return;
                }
                foreach (unowned Item it in items) {
                    if (it.row == row) {
                        detail.set_visible_child_name (it.id);
                    }
                }
            });
            var side_scroll = new Gtk.ScrolledWindow (null, null);
            side_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            side_scroll.add (list);
            pack_start (side_scroll, false, false, 0);
            var detail_scroll = new Gtk.ScrolledWindow (null, null);
            detail_scroll.add (detail);
            pack_start (detail_scroll, true, true, 0);
            list.select_row (list.get_row_at_index (0));

            /* Sampling only while visible. */
            map.connect (() => {
                sample ();
                if (timer == 0) {
                    timer = Timeout.add_seconds (1, () => {
                        sample ();
                        return Source.CONTINUE;
                    });
                }
            });
            unmap.connect (() => {
                if (timer != 0) {
                    Source.remove (timer);
                    timer = 0;
                }
            });
        }

        private void add_item (string id, string title) {
            var it = new Item ();
            it.id = id;
            it.row = new Gtk.ListBoxRow ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            box.margin = 8;
            it.title = new Gtk.Label (title);
            it.title.set_xalign (0);
            it.figure = new Gtk.Label ("—");
            it.figure.set_xalign (0);
            it.figure.get_style_context ().add_class ("dim-label");
            box.pack_start (it.title, false, false, 0);
            box.pack_start (it.figure, false, false, 0);
            it.row.add (box);
            list.add (it.row);
            items += it;

            /* Detail page: heading, graph, facts grid. */
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            page.margin = 16;
            var heading = new Gtk.Label (title);
            heading.set_xalign (0);
            heading.get_style_context ().add_class ("kavis-perf-title");
            page.pack_start (heading, false, false, 0);
            var graph = new Graph ();
            graph.auto_scale = id.has_prefix ("disk:") || id.has_prefix ("net:");
            graphs.insert (id, graph);
            page.pack_start (graph, false, false, 0);
            var grid = new Gtk.Grid ();
            grid.column_spacing = 24;
            grid.row_spacing = 6;
            int r = 0;
            foreach (unowned string key in fact_keys (id)) {
                var k = new Gtk.Label (fact_title (key));
                k.set_xalign (0);
                k.get_style_context ().add_class ("dim-label");
                var v = new Gtk.Label ("—");
                v.set_xalign (0);
                v.set_selectable (true);
                grid.attach (k, 0, r, 1, 1);
                grid.attach (v, 1, r, 1, 1);
                facts.insert (id + "/" + key, v);
                r++;
            }
            page.pack_start (grid, false, false, 0);
            detail.add_named (page, id);
        }

        private string[] fact_keys (string id) {
            if (id == "cpu") {
                return { "model", "cores", "base", "cur", "temp",
                         "uptime", "procs", "board" };
            }
            if (id == "mem") {
                return { "used", "cached", "swap", "speed" };
            }
            if (id.has_prefix ("disk:")) {
                return { "model", "size", "read", "write", "temp" };
            }
            if (id.has_prefix ("net:")) {
                return { "ip", "rx", "tx" };
            }
            return { "model", "usage", "vram", "temp" };
        }

        private string fact_title (string key) {
            switch (key) {
            case "model":  return _("Model");
            case "cores":  return _("Cores / threads");
            case "base":   return _("Base speed");
            case "cur":    return _("Current speed");
            case "temp":   return _("Temperature");
            case "uptime": return _("Up time");
            case "procs":  return _("Processes / threads");
            case "board":  return _("Motherboard");
            case "used":   return _("In use");
            case "cached": return _("Cached");
            case "swap":   return _("Swap");
            case "speed":  return _("Speed / type");
            case "size":   return _("Capacity");
            case "read":   return _("Read");
            case "write":  return _("Write");
            case "ip":     return _("IP address");
            case "rx":     return _("Receive");
            case "tx":     return _("Send");
            case "usage":  return _("Usage");
            case "vram":   return _("Video memory");
            }
            return key;
        }

        private void set_fact (string id, string key, string value) {
            unowned Gtk.Label? l = facts.lookup (id + "/" + key);
            if (l != null) {
                l.set_text (value);
            }
        }

        private void set_figure (string id, string text) {
            foreach (unowned Item it in items) {
                if (it.id == id) {
                    it.figure.set_text (text);
                }
            }
        }

        private static string rate (uint64 bytes_per_s) {
            return SysInfo.format_bytes (bytes_per_s) + "/s";
        }

        private static string temp_text (double t) {
            return (t >= 0) ? "%.0f °C".printf (t) : "—";
        }

        private void sample () {
            /* --- CPU --- */
            uint64 busy, total;
            SysInfo.cpu_jiffies (out busy, out total);
            double cpu_pct = 0;
            if (prev_total > 0 && total > prev_total) {
                cpu_pct = 100.0 * (busy - prev_busy) / (total - prev_total);
            }
            prev_busy = busy;
            prev_total = total;
            graphs.lookup ("cpu").push (cpu_pct);
            set_figure ("cpu", "%.0f%%".printf (cpu_pct));
            set_fact ("cpu", "model", SysInfo.cpu_model ());
            int cores, threads;
            SysInfo.cpu_topology (out cores, out threads);
            set_fact ("cpu", "cores", "%d / %d".printf (cores, threads));
            int base_mhz = SysInfo.cpu_base_mhz ();
            set_fact ("cpu", "base", (base_mhz > 0)
                      ? "%.2f GHz".printf (base_mhz / 1000.0) : "—");
            int[] freqs = SysInfo.cpu_freq_mhz ();
            var sb = new StringBuilder ();
            int shown = 0;
            foreach (int f in freqs) {
                if (f <= 0) {
                    continue;
                }
                if (shown > 0) {
                    sb.append ("  ");
                }
                sb.append_printf ("%.2f", f / 1000.0);
                shown++;
                if (shown >= 8) {
                    sb.append (" …");
                    break;
                }
            }
            set_fact ("cpu", "cur", (shown > 0) ? sb.str + " GHz" : "—");
            set_fact ("cpu", "temp", temp_text (SysInfo.cpu_temp ()));
            int up = (int) SysInfo.uptime_seconds ();
            set_fact ("cpu", "uptime", "%d:%02d:%02d".printf (
                up / 3600, (up / 60) % 60, up % 60));
            int procs, thr;
            SysInfo.process_counts (out procs, out thr);
            set_fact ("cpu", "procs", "%d / %d".printf (procs, thr));
            string board = SysInfo.board ();
            set_fact ("cpu", "board", (board != "") ? board : "—");

            /* --- Memory --- */
            uint64 mt, mu, mc, st, su;
            SysInfo.memory (out mt, out mu, out mc, out st, out su);
            double mem_pct = (mt > 0) ? 100.0 * mu / mt : 0;
            graphs.lookup ("mem").push (mem_pct);
            set_figure ("mem", "%s / %s".printf (
                SysInfo.format_bytes (mu), SysInfo.format_bytes (mt)));
            set_fact ("mem", "used", "%s (%.0f%%)".printf (
                SysInfo.format_bytes (mu), mem_pct));
            set_fact ("mem", "cached", SysInfo.format_bytes (mc));
            set_fact ("mem", "swap", (st > 0)
                ? "%s / %s".printf (SysInfo.format_bytes (su),
                                    SysInfo.format_bytes (st)) : "—");
            /* dmidecode needs root — no password prompt for a status page */
            set_fact ("mem", "speed", "—");

            /* --- Disks --- */
            foreach (unowned SysInfo.Disk d in SysInfo.disks ()) {
                string id = "disk:" + d.name;
                if (graphs.lookup (id) == null) {
                    continue;   /* disk plugged in later: shows when the tab reopens */
                }
                uint64? pr = prev_disk_r.lookup (d.name);
                uint64? pw = prev_disk_w.lookup (d.name);
                uint64 rs = (pr != null && d.read_bytes >= pr) ? d.read_bytes - pr : 0;
                uint64 ws = (pw != null && d.write_bytes >= pw) ? d.write_bytes - pw : 0;
                prev_disk_r.insert (d.name, d.read_bytes);
                prev_disk_w.insert (d.name, d.write_bytes);
                graphs.lookup (id).push ((double) (rs + ws));
                set_figure (id, "R %s  W %s".printf (rate (rs), rate (ws)));
                set_fact (id, "model", (d.model != "") ? d.model : "—");
                set_fact (id, "size", SysInfo.format_bytes (d.size));
                set_fact (id, "read", rate (rs));
                set_fact (id, "write", rate (ws));
                set_fact (id, "temp", temp_text (d.temp));
            }

            /* --- Network --- */
            foreach (unowned SysInfo.Iface i in SysInfo.interfaces ()) {
                string id = "net:" + i.name;
                if (graphs.lookup (id) == null) {
                    continue;
                }
                uint64? pr = prev_rx.lookup (i.name);
                uint64? pt = prev_tx.lookup (i.name);
                uint64 rx = (pr != null && i.rx_bytes >= pr) ? i.rx_bytes - pr : 0;
                uint64 tx = (pt != null && i.tx_bytes >= pt) ? i.tx_bytes - pt : 0;
                prev_rx.insert (i.name, i.rx_bytes);
                prev_tx.insert (i.name, i.tx_bytes);
                graphs.lookup (id).push ((double) (rx + tx));
                set_figure (id, "↓ %s  ↑ %s".printf (rate (rx), rate (tx)));
                string ip = SysInfo.ip_of (i.name);
                set_fact (id, "ip", (ip != "") ? ip : "—");
                set_fact (id, "rx", rate (rx));
                set_fact (id, "tx", rate (tx));
            }

            /* --- GPU --- */
            int gbusy; int64 vu, vt; double gt;
            SysInfo.gpu_stats (out gbusy, out vu, out vt, out gt);
            graphs.lookup ("gpu").push ((gbusy >= 0) ? gbusy : 0);
            set_figure ("gpu", (gbusy >= 0) ? "%d%%".printf (gbusy) : "—");
            set_fact ("gpu", "model", SysInfo.gpu_model ());
            set_fact ("gpu", "usage", (gbusy >= 0) ? "%d%%".printf (gbusy) : "—");
            set_fact ("gpu", "vram", (vt > 0)
                ? "%s / %s".printf (SysInfo.format_bytes ((uint64) vu),
                                    SysInfo.format_bytes ((uint64) vt)) : "—");
            set_fact ("gpu", "temp", temp_text (gt));
        }
    }
}
