/* kavis-selftest — run directory, run.log, report.json/html, retention. */
namespace Kavis.Selftest {

    public class StepResult : Object {
        public int index;
        public string scenario = "";
        public string action = "";
        public string expect = "";
        public string result = "";      /* OK | FAIL | SKIP */
        public string detail = "";
        public double seconds = 0;
        public int ram_delta_mb = 0;
        public double diff_percent = 0;
        public string shot = "";
        private string[] _anomalies = {};
        public string note = "";
        public void anomaly (string a) { _anomalies += a; }
        public unowned string[] anomalies { get { return _anomalies; } }
    }

    public class Report : Object {

        public string dir;
        public string stamp;
        public bool echo_stdout = true;
        private FileStream? runlog;
        private FileStream? journal;
        private StepResult[] _results = {};
        public unowned StepResult[] get_results () { return _results; }
        public int mem_start = 0;
        public int mem_end = 0;
        public int journal_errors = 0;
        private string[] _scenario_errors = {};
        public unowned string[] scenario_errors { get { return _scenario_errors; } }
        public void add_scenario_error (string e) { _scenario_errors += e; }

        public Report (string? base_dir) {
            var now = new DateTime.now_local ();
            stamp = now.format ("%Y-%m-%d-%H%M%S");
            string root = base_dir ?? Path.build_filename (
                Environment.get_user_data_dir (), "kavis", "selftest");
            dir = Path.build_filename (root, stamp);
            DirUtils.create_with_parents (dir, 0755);
            runlog = FileStream.open (Path.build_filename (dir, "run.log"), "w");
            journal = FileStream.open (Path.build_filename (dir, "journal.log"), "w");
            retention (root);
        }

        public string now_str () {
            var now = new DateTime.now_local ();
            return "%s.%03d".printf (now.format ("%Y-%m-%d %H:%M:%S"),
                                     now.get_microsecond () / 1000);
        }

        /* One grep-able line per event (kararlar.md 9b format). */
        public void line (string text) {
            string full = now_str () + " " + text;
            if (runlog != null) {
                runlog.puts (full + "\n");
                runlog.flush ();
            }
            if (echo_stdout) {
                stdout.puts (full + "\n");
                stdout.flush ();
            }
        }

        public void journal_lines (string tag, string text) {
            if (journal == null || text.strip () == "") {
                return;
            }
            journal.puts ("--- " + tag + "\n" + text);
            journal.flush ();
        }

        public void write_aux (string name, string text) {
            try {
                FileUtils.set_contents (Path.build_filename (dir, name), text);
            } catch (Error e) { }
        }

        public void add (StepResult r) {
            _results += r;
        }

        public int failures () {
            int n = 0;
            foreach (var r in _results) {
                if (r.result == "FAIL") {
                    n++;
                }
            }
            return n + scenario_errors.length;
        }

        /* Summary block (kararlar.md 9b): totals, slowest 5, RAM, journal. */
        public void finish () {
            int ok = 0, fail = 0, skip = 0;
            foreach (var r in _results) {
                if (r.result == "OK") ok++; else if (r.result == "FAIL") fail++; else skip++;
            }
            line ("SUMMARY total=%d passed=%d failed=%d skipped=%d scenario-errors=%d".printf (
                _results.length, ok, fail, skip, scenario_errors.length));
            StepResult[] sorted = {};
            foreach (var r0 in _results) { sorted += r0; }
            /* slowest 5 — small array, selection sort is enough */
            for (int i = 0; i < sorted.length; i++) {
                for (int j = i + 1; j < sorted.length; j++) {
                    if (sorted[j].seconds > sorted[i].seconds) {
                        var t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t;
                    }
                }
            }
            for (int i = 0; i < int.min (5, sorted.length); i++) {
                line ("SLOWEST %d [%s/%d] %.2fs %s".printf (i + 1, sorted[i].scenario,
                    sorted[i].index, sorted[i].seconds, sorted[i].action));
            }
            line ("RAM start=%d MB end=%d MB delta=%+d MB".printf (
                mem_start, mem_end, mem_end - mem_start));
            line ("JOURNAL new-errors=%d".printf (journal_errors));
            foreach (string e in scenario_errors) {
                line ("SCENARIO-ERROR " + e);
            }
            write_json ();
            write_html ();
        }

        private string esc (string s) {
            return s.replace ("\\", "\\\\").replace ("\"", "\\\"").replace ("\n", "\\n");
        }

        private void write_json () {
            var sb = new StringBuilder ();
            sb.append ("{\n  \"stamp\": \"" + stamp + "\",\n");
            sb.append_printf ("  \"failures\": %d,\n  \"mem_start_mb\": %d,\n  \"mem_end_mb\": %d,\n  \"journal_errors\": %d,\n",
                              failures (), mem_start, mem_end, journal_errors);
            sb.append ("  \"scenario_errors\": [");
            for (int i = 0; i < scenario_errors.length; i++) {
                sb.append ((i > 0 ? ", " : "") + "\"" + esc (scenario_errors[i]) + "\"");
            }
            sb.append ("],\n  \"steps\": [\n");
            for (int i = 0; i < _results.length; i++) {
                var r = _results[i];
                sb.append ("    {");
                sb.append_printf ("\"scenario\": \"%s\", \"index\": %d, \"action\": \"%s\", \"expect\": \"%s\", \"result\": \"%s\", \"detail\": \"%s\", \"seconds\": %.3f, \"ram_delta_mb\": %d, \"diff_percent\": %.1f, \"shot\": \"%s\", \"anomalies\": [",
                    esc (r.scenario), r.index, esc (r.action), esc (r.expect), r.result,
                    esc (r.detail), r.seconds, r.ram_delta_mb, r.diff_percent, esc (r.shot));
                for (int j = 0; j < r.anomalies.length; j++) {
                    sb.append ((j > 0 ? ", " : "") + "\"" + esc (r.anomalies[j]) + "\"");
                }
                sb.append ("]}" + (i + 1 < _results.length ? ",\n" : "\n"));
            }
            sb.append ("  ]\n}\n");
            write_aux ("report.json", sb.str);
        }

        private string h (string s) {
            return s.replace ("&", "&amp;").replace ("<", "&lt;").replace (">", "&gt;");
        }

        private void write_html () {
            var sb = new StringBuilder ();
            sb.append ("<!doctype html><meta charset=utf-8><title>Kavis selftest " + stamp + "</title>");
            sb.append ("<style>body{font:14px sans-serif;background:#0D141B;color:#E6EDF3;margin:20px}table{border-collapse:collapse}td,th{border:1px solid #233A45;padding:4px 8px;vertical-align:top}.OK{color:#22C55E}.FAIL{color:#EF4444}.SKIP{color:#8B9BA8}img{max-width:320px}</style>");
            sb.append_printf ("<h1>Kavis selftest — %s</h1><p>failures: %d · RAM %d → %d MB · new journal errors: %d</p>",
                              stamp, failures (), mem_start, mem_end, journal_errors);
            foreach (string e in scenario_errors) {
                sb.append ("<p class=FAIL>scenario error: " + h (e) + "</p>");
            }
            sb.append ("<table><tr><th>#</th><th>scenario</th><th>action</th><th>expect</th><th>result</th><th>time</th><th>RAM</th><th>diff %</th><th>anomalies</th><th>frame</th></tr>");
            foreach (var r in _results) {
                sb.append_printf ("<tr><td>%d</td><td>%s</td><td>%s<br><small>%s</small></td><td>%s</td><td class=%s>%s<br><small>%s</small></td><td>%.2fs</td><td>%+d MB</td><td>%.1f</td><td>%s</td><td>%s</td></tr>",
                    r.index, h (r.scenario), h (r.action), h (r.note), h (r.expect), r.result, r.result,
                    h (r.detail), r.seconds, r.ram_delta_mb, r.diff_percent,
                    h (string.joinv ("; ", r.anomalies)),
                    r.shot == "" ? "" : "<a href=\"" + r.shot + "\"><img src=\"" + r.shot + "\"></a>");
            }
            sb.append ("</table>");
            write_aux ("report.html", sb.str);
        }

        /* Keep the last 10 runs and at most ~200 MB in total. */
        private void retention (string root) {
            string[] names = {};
            try {
                var d = Dir.open (root);
                string? n;
                while ((n = d.read_name ()) != null) {
                    if (n != stamp && FileUtils.test (Path.build_filename (root, n), FileTest.IS_DIR)) {
                        names += n;
                    }
                }
            } catch (Error e) {
                return;
            }
            /* names are timestamps: lexical order = time order */
            for (int i = 0; i < names.length; i++) {
                for (int j = i + 1; j < names.length; j++) {
                    if (strcmp (names[j], names[i]) > 0) {
                        var t = names[i]; names[i] = names[j]; names[j] = t;
                    }
                }
            }
            int64 total = 0;
            for (int i = 0; i < names.length; i++) {
                string p = Path.build_filename (root, names[i]);
                total += dir_size (p);
                if (i >= 9 || total > 200L * 1024 * 1024) {
                    remove_tree (p);
                }
            }
        }

        private int64 dir_size (string p) {
            int64 s = 0;
            try {
                var d = Dir.open (p);
                string? n;
                while ((n = d.read_name ()) != null) {
                    string c = Path.build_filename (p, n);
                    if (FileUtils.test (c, FileTest.IS_DIR)) {
                        s += dir_size (c);
                    } else {
                        Posix.Stat st;
                        if (Posix.stat (c, out st) == 0) {
                            s += st.st_size;
                        }
                    }
                }
            } catch (Error e) { }
            return s;
        }

        private void remove_tree (string p) {
            try {
                var d = Dir.open (p);
                string? n;
                while ((n = d.read_name ()) != null) {
                    string c = Path.build_filename (p, n);
                    if (FileUtils.test (c, FileTest.IS_DIR)) {
                        remove_tree (c);
                    } else {
                        FileUtils.unlink (c);
                    }
                }
            } catch (Error e) { }
            DirUtils.remove (p);
        }
    }
}
