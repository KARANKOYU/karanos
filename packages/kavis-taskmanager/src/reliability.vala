/* Task Manager — Reliability tab (feedback, 8 Sep 2026).
 *
 * Windows' Reliability Monitor answers a question the Logs tab cannot:
 * "has this machine been getting worse?" A log is a list of lines and
 * you have to already know what you are looking for; this is a
 * fortnight of days with a mark on each, and the marks are the events
 * that actually cost somebody something — an application that crashed,
 * a service that failed, the machine going down without being asked.
 *
 * WHAT COUNTS, and why these four:
 *   crash    a coredump — a program died in a way it did not intend
 *   service  a systemd unit that entered a failed state
 *   kernel   an oops, a segfault the kernel logged, an OOM kill
 * Warnings are deliberately NOT counted. A stability score that moves
 * because something logged a warning teaches people to ignore it, and
 * a number nobody trusts is worse than no number.
 *
 * Everything is read on demand from journalctl and coredumpctl. Nothing
 * is collected in the background: a reliability view that costs memory
 * all day to tell you the machine is fine has failed at its own job.
 */

namespace Kavis.TaskManager {

    public class ReliabilityPage : Gtk.Box {

        private const int DAYS = 14;

        private Gtk.Box chart;
        private Gtk.ListBox event_list;
        private Gtk.Label summary;

        private class Day {
            public string label;
            public string key;        /* YYYY-MM-DD */
            public int crashes = 0;
            public int services = 0;
            public int kernel = 0;
            public int total { get { return crashes + services + kernel; } }
        }

        private class Event {
            public int64 when;
            public string kind;
            public string what;
        }

        public ReliabilityPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);
            margin = 12;

            summary = new Gtk.Label ("");
            summary.set_xalign (0);
            summary.set_line_wrap (true);
            pack_start (summary, false, false, 0);

            chart = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            chart.set_size_request (-1, 120);
            pack_start (chart, false, false, 0);

            event_list = new Gtk.ListBox ();
            event_list.set_selection_mode (Gtk.SelectionMode.NONE);
            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.add (event_list);
            pack_start (scrolled, true, true, 0);

            var bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var refresh = new Gtk.Button.with_label (_("Refresh"));
            refresh.clicked.connect (() => load ());
            bar.pack_end (refresh, false, false, 0);
            pack_start (bar, false, false, 0);

            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data ("""
                    .kavis-day-bar {
                      border-radius: 4px 4px 0 0;
                      background-color: @kavis_ok;
                    }
                    .kavis-day-bar.bad { background-color: @kavis_error; }
                    .kavis-day-bar.mixed { background-color: @kavis_warn; }
                    .kavis-day-label {
                      font-size: 11px;
                      color: @kavis_text2;
                    }
                """);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-taskmanager: reliability css: %s", e.message);
            }

            load ();
        }

        private void load () {
            var days = new GenericArray<Day> ();
            var by_key = new HashTable<string, Day> (str_hash, str_equal);
            var today = new DateTime.now_local ();
            for (int i = DAYS - 1; i >= 0; i--) {
                var when = today.add_days (-i);
                var day = new Day ();
                day.key = when.format ("%Y-%m-%d");
                day.label = when.format ("%d/%m");
                days.add (day);
                by_key.insert (day.key, day);
            }

            var found = new GenericArray<Event> ();
            collect_coredumps (by_key, found);
            collect_journal (by_key, found);
            draw_days (days);
            fill (found);
        }

        /* --- sources ------------------------------------------------ */

        private void collect_coredumps (HashTable<string, Day> by_key,
                                        GenericArray<Event> found) {
            string? listing = Kavis.SysInfo.capture (
                { "coredumpctl", "--no-pager", "--no-legend", "list" });
            if (listing == null) {
                return;
            }
            foreach (unowned string line in listing.split ("\n")) {
                string trimmed = line.strip ();
                if (trimmed == "") {
                    continue;
                }
                /* "Mon 2026-09-08 11:41:27 +03  1234  1000 ... program" */
                string[] parts = trimmed.split (" ");
                if (parts.length < 2) {
                    continue;
                }
                var day = by_key.lookup (parts[1]);
                if (day != null) {
                    day.crashes++;
                }
                var event = new Event ();
                event.kind = _("Crash");
                event.what = parts[parts.length - 1];
                event.when = 0;
                found.add (event);
            }
        }

        private void collect_journal (HashTable<string, Day> by_key,
                                      GenericArray<Event> found) {
            /* One journalctl call, not one per day: on a slow machine
             * fourteen of them is fourteen seconds of nothing. */
            string? errors = Kavis.SysInfo.capture ({
                "journalctl", "--no-pager", "--since",
                "%d days ago".printf (DAYS), "-p", "err", "-o", "short-iso"
            });
            if (errors == null) {
                return;
            }
            foreach (unowned string line in errors.split ("\n")) {
                if (line.length < 10) {
                    continue;
                }
                string key = line.substring (0, 10);
                var day = by_key.lookup (key);
                bool is_kernel = line.contains ("kernel:")
                    || line.contains ("segfault")
                    || line.contains ("Out of memory");
                bool is_service = line.contains ("Failed to start")
                    || line.contains ("entered failed state");
                if (day != null) {
                    if (is_kernel) {
                        day.kernel++;
                    } else if (is_service) {
                        day.services++;
                    }
                }
                if (is_kernel || is_service) {
                    var event = new Event ();
                    event.kind = is_kernel ? _("Kernel") : _("Service");
                    event.what = line;
                    found.add (event);
                }
            }
        }

        /* --- drawing ------------------------------------------------ */

        private void draw_days (GenericArray<Day> days) {
            foreach (var child in chart.get_children ()) {
                chart.remove (child);
            }
            int worst = 1;
            for (int i = 0; i < days.length; i++) {
                worst = int.max (worst, days[i].total);
            }
            int good = 0;
            for (int i = 0; i < days.length; i++) {
                var day = days[i];
                var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
                var bar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                bar.get_style_context ().add_class ("kavis-day-bar");
                if (day.total == 0) {
                    good++;
                } else if (day.crashes > 0 || day.kernel > 0) {
                    bar.get_style_context ().add_class ("bad");
                } else {
                    bar.get_style_context ().add_class ("mixed");
                }
                /* A day with nothing on it still gets a visible bar —
                 * an empty column reads as missing data rather than as
                 * a good day. */
                int height = (day.total == 0)
                    ? 8 : 8 + (int) (72.0 * day.total / worst);
                bar.set_size_request (18, height);
                bar.set_valign (Gtk.Align.END);
                bar.set_tooltip_text (day.total == 0
                    ? _("%s — nothing went wrong").printf (day.label)
                    : _("%s — %d crashes, %d service failures, %d kernel errors")
                        .printf (day.label, day.crashes, day.services,
                                 day.kernel));
                var label = new Gtk.Label (day.label);
                label.get_style_context ().add_class ("kavis-day-label");
                var holder = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                holder.set_valign (Gtk.Align.END);
                holder.pack_end (bar, false, false, 0);
                column.pack_start (holder, true, true, 0);
                column.pack_start (label, false, false, 0);
                chart.pack_start (column, false, false, 0);
            }
            summary.set_text (
                ngettext ("%d of the last %d days had nothing go wrong.",
                          "%d of the last %d days had nothing go wrong.",
                          good).printf (good, days.length));
            chart.show_all ();
        }

        private void fill (GenericArray<Event> found) {
            foreach (var child in event_list.get_children ()) {
                event_list.remove (child);
            }
            if (found.length == 0) {
                var none = new Gtk.Label (
                    _("Nothing has crashed or failed in the last two weeks."));
                none.set_xalign (0);
                none.margin = 8;
                event_list.add (none);
                event_list.show_all ();
                return;
            }
            /* Newest first, capped: this is a summary, and the Logs tab
             * is where the whole thing lives. */
            int shown = 0;
            for (int i = found.length - 1; i >= 0 && shown < 100; i--) {
                var event = found[i];
                var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                box.margin = 6;
                var kind = new Gtk.Label (event.kind);
                kind.set_xalign (0);
                kind.set_size_request (80, -1);
                var what = new Gtk.Label (event.what);
                what.set_xalign (0);
                what.set_ellipsize (Pango.EllipsizeMode.END);
                box.pack_start (kind, false, false, 0);
                box.pack_start (what, true, true, 0);
                event_list.add (box);
                shown++;
            }
            event_list.show_all ();
        }
    }
}
