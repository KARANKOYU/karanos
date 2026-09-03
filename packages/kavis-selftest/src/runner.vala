/* kavis-selftest — executes scenario steps against the live session.
 *
 * Actions drive xdotool (real X input, the way a hand would); the
 * session's state is read through libwnck and raw X. Every step logs
 * before/after frames, the window list, kavis-* memory, journal lines
 * and anomalies independent of the expectation (kararlar.md 9b). */
namespace Kavis.Selftest {

    public class Runner : Object {

        private XWin xw = new XWin ();
        private Report rep;
        private int step_no = 0;
        private int coredumps;
        private string[] pillars = { "kavis-panel", "kavis-snap", "openbox", "picom" };
        private bool keep_all_shots;

        public Runner (Report report, bool keep_all_shots) {
            rep = report;
            this.keep_all_shots = keep_all_shots;
            coredumps = SysMon.coredump_count ();
        }

        public void run (Scenario sc) {
            if (sc.parse_error != "") {
                rep.add_scenario_error (sc.name + ": " + sc.parse_error);
                rep.line ("[%s] SCENARIO-ERROR %s".printf (sc.name, sc.parse_error));
                return;
            }
            rep.line ("[%s] BEGIN %s (madde %s, %d adım)".printf (sc.name, sc.title, sc.madde, sc.get_steps ().length));
            string[] known = xw.window_classes ();
            foreach (string a in sc.allowed) {
                known += a.down ();
            }
            int i = 0;
            foreach (Step st in sc.get_steps ()) {
                i++;
                run_step (sc, st, i, ref known);
            }
            rep.line ("[%s] END".printf (sc.name));
        }

        private void run_step (Scenario sc, Step st, int idx, ref string[] known) {
            step_no++;
            var r = new StepResult ();
            r.index = idx;
            r.scenario = sc.name;
            r.action = st.action;
            r.expect = st.expect;
            r.note = st.note;
            string tag = "[%s/%d]".printf (sc.name, idx);
            int64 t0 = new DateTime.now_utc ().to_unix ();
            int mem0 = SysMon.mem_used_mb ();
            var timer = new Timer ();
            Gdk.Pixbuf? before = capture ();

            string err;
            bool act_ok = do_action (st.action, out err);
            string detail = "";
            bool ok = act_ok;
            if (!act_ok) {
                detail = "eylem: " + err;
            } else {
                ok = wait_expect (st.expect, st.timeout_ms, out detail);
            }
            r.seconds = timer.elapsed ();
            r.result = ok ? "OK" : "FAIL";
            r.detail = detail;
            r.ram_delta_mb = SysMon.mem_used_mb () - mem0;

            /* --- kare + fark --- */
            Gdk.Pixbuf? after = capture ();
            r.diff_percent = diff (before, after);
            string stem = "%03d".printf (step_no);
            if (after != null) {
                if (!ok || st.shot || keep_all_shots) {
                    r.shot = stem + (ok ? "" : "-fail") + ".png";
                    save (after, r.shot, false);
                } else {
                    r.shot = stem + "-thumb.png";
                    save (after, r.shot, true);
                }
            }
            /* --- pencere listesi, süreçler, journal --- */
            string wins = xw.list_windows ();
            rep.write_aux ("windows-" + stem + ".txt", wins);
            rep.write_aux ("processes-" + stem + ".txt", SysMon.process_table ());
            string jl = SysMon.journal_since (t0);
            rep.journal_lines (tag, jl);
            /* --- anormallikler (beklentiden bağımsız) --- */
            int cd = SysMon.coredump_count ();
            if (cd > coredumps) {
                r.anomaly ("yeni coredump (%d)".printf (cd - coredumps));
                coredumps = cd;
            }
            foreach (string line in jl.split ("\n")) {
                string l = line.down ();
                if (l.contains ("critical") || l.contains ("assertion") || l.contains ("segfault")) {
                    r.anomaly ("journal: " + line.strip ());
                    rep.journal_errors++;
                }
            }
            int sync = xw.sync_ms ();
            if (sync > 2000) {
                r.anomaly ("donma: X yanıtı %d ms".printf (sync));
            }
            foreach (string p in pillars) {
                if (!SysMon.running (p)) {
                    r.anomaly ("süreç öldü: " + p);
                }
            }
            if (r.ram_delta_mb > 100) {
                r.anomaly ("RAM sıçraması %+d MB".printf (r.ram_delta_mb));
            }
            foreach (string c in xw.window_classes ()) {
                bool seen = false;
                foreach (string k in known) {
                    if (c.contains (k) || k.contains (c)) {
                        seen = true;
                    }
                }
                if (!seen) {
                    r.anomaly ("bilinmeyen pencere: " + c);
                    string[] grown = known;
                    grown += c;
                    known = grown;
                }
            }
            if (!ok) {
                rep.write_aux ("fail-" + stem + "-xprop.txt", xprop_dump ());
            }
            rep.line ("%s ACTION %s | EXPECT %s | RESULT %s%s | %.2fs | RAM %+d MB | fark %.1f%% | shot=%s%s".printf (
                tag, st.action, st.expect, r.result,
                detail == "" ? "" : " " + detail, r.seconds, r.ram_delta_mb,
                r.diff_percent, r.shot,
                r.anomalies.length == 0 ? "" : " | ANOMALI " + string.joinv ("; ", r.anomalies)));
            rep.add (r);
        }

        /* ---------------- actions ---------------- */

        private bool xdo (string[] args, out string err) {
            err = "";
            string[] argv = { "xdotool" };
            foreach (string a in args) {
                argv += a;
            }
            try {
                string so, se;
                int rc;
                Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out so, out se, out rc);
                if (rc != 0) {
                    err = "xdotool: " + se.strip ();
                    return false;
                }
                return true;
            } catch (Error e) {
                err = e.message;
                return false;
            }
        }

        private void settle (int ms) {
            var loop = new MainLoop ();
            Timeout.add (ms, () => { loop.quit (); return Source.REMOVE; });
            loop.run ();
            xw.pump ();
        }

        private bool do_action (string action, out string err) {
            err = "";
            string[] w = action.strip ().split (" ");
            if (w.length == 0 || w[0] == "none") {
                return true;
            }
            string rest = w.length > 1 ? action.strip ().substring (w[0].length + 1) : "";
            switch (w[0]) {
            case "key":
                return xdo ({ "key", "--clearmodifiers", rest }, out err);
            case "type":
                return xdo ({ "type", "--delay", "40", rest }, out err);
            case "wait":
                settle (int.parse (rest));
                return true;
            case "launch":
                try {
                    Process.spawn_command_line_async (rest);
                    return true;
                } catch (Error e) {
                    err = e.message;
                    return false;
                }
            case "shell": {
                int rc;
                string res = SysMon.run_shell (rest, out rc);
                if (rc != 0) {
                    err = "rc=%d %s".printf (rc, res.strip ().replace ("\n", " / "));
                }
                return rc == 0;
            }
            case "conf":
                return conf_set (w, out err);
            case "click":
                return do_click (w, out err);
            case "drag":
                return do_drag (w, out err);
            case "close": {
                if (w.length < 3) { err = "close window <sınıf>"; return false; }
                unowned Wnck.Window? win = xw.find (w[2]);
                if (win == null) { err = "pencere yok: " + w[2]; return false; }
                win.close (Gdk.CURRENT_TIME);
                return true;
            }
            default:
                err = "bilinmeyen eylem: " + w[0];
                return false;
            }
        }

        private bool conf_set (string[] w, out string err) {
            err = "";
            if (w.length < 4) { err = "conf <bölüm> <anahtar> <değer>"; return false; }
            string path = Path.build_filename (Environment.get_user_config_dir (), "kavis", "kavis.conf");
            var kf = new KeyFile ();
            try {
                kf.load_from_file (path, KeyFileFlags.KEEP_COMMENTS);
            } catch (Error e) { }
            kf.set_string (w[1], w[2], w[3]);
            DirUtils.create_with_parents (Path.get_dirname (path), 0755);
            try {
                FileUtils.set_contents (path, kf.to_data ());
            } catch (Error e) {
                err = e.message;
                return false;
            }
            return true;
        }

        private bool do_click (string[] w, out string err) {
            err = "";
            int x, y;
            if (w.length >= 3 && w[1] == "window") {
                unowned Wnck.Window? win = xw.find (w[2]);
                if (win == null) { err = "pencere yok: " + w[2]; return false; }
                int fx, fy, fw, fh;
                if (!xw.frame_geometry (win, out fx, out fy, out fw, out fh)) {
                    win.get_geometry (out fx, out fy, out fw, out fh);
                }
                x = fx + fw / 2; y = fy + fh / 2;
                if (w.length >= 5) {
                    x = fx + int.parse (w[3]); y = fy + int.parse (w[4]);
                }
            } else if (w.length >= 3 && w[1] == "taskbar") {
                if (!taskbar_point (w[2], out x, out y, out err)) {
                    return false;
                }
            } else if (w.length >= 3) {
                x = int.parse (w[1]); y = int.parse (w[2]);
            } else {
                err = "click <x> <y> | click window <sınıf> [dx dy] | click taskbar start|clock";
                return false;
            }
            string btn = "1";
            if (w[w.length - 1] == "right") {
                btn = "3";
            }
            return xdo ({ "mousemove", x.to_string (), y.to_string (), "click", btn }, out err);
        }

        /* Start = 40 px from the panel's leading edge, clock = 45 px from
         * the trailing edge — the same spots panel-screenshot.sh uses. */
        private bool taskbar_point (string what, out int x, out int y, out string err) {
            x = 0; y = 0; err = "";
            unowned Wnck.Window? p = xw.panel ();
            if (p == null) { err = "panel penceresi yok"; return false; }
            int px, py, pw, ph;
            p.get_geometry (out px, out py, out pw, out ph);
            bool vertical = ph > pw;
            switch (what) {
            case "start":
                x = vertical ? px + pw / 2 : px + 40;
                y = vertical ? py + 40 : py + ph / 2;
                return true;
            case "clock":
                x = vertical ? px + pw / 2 : px + pw - 45;
                y = vertical ? py + ph - 45 : py + ph / 2;
                return true;
            default:
                err = "taskbar: start | clock";
                return false;
            }
        }

        /* drag window <class> to left|right|top|tl|tr|bl|br|<x> <y> */
        private bool do_drag (string[] w, out string err) {
            err = "";
            if (w.length < 5 || w[1] != "window") { err = "drag window <sınıf> to <kenar|x y>"; return false; }
            unowned Wnck.Window? win = xw.find (w[2]);
            if (win == null) { err = "pencere yok: " + w[2]; return false; }
            int fx, fy, fw, fh;
            if (!xw.frame_geometry (win, out fx, out fy, out fw, out fh)) {
                win.get_geometry (out fx, out fy, out fw, out fh);
            }
            int sx = fx + int.min (120, fw / 3), sy = fy + 20;
            Gdk.Rectangle wa = xw.workarea ();
            int tx, ty;
            switch (w[4]) {
            case "left":  tx = wa.x + 1; ty = wa.y + wa.height / 2; break;
            case "right": tx = wa.x + wa.width - 2; ty = wa.y + wa.height / 2; break;
            case "top":   tx = wa.x + wa.width / 2; ty = wa.y + 1; break;
            case "tl":    tx = wa.x + 1; ty = wa.y + 40; break;
            case "tr":    tx = wa.x + wa.width - 2; ty = wa.y + 40; break;
            case "bl":    tx = wa.x + 1; ty = wa.y + wa.height - 40; break;
            case "br":    tx = wa.x + wa.width - 2; ty = wa.y + wa.height - 40; break;
            default:
                if (w.length < 6) { err = "drag hedefi"; return false; }
                tx = int.parse (w[4]); ty = int.parse (w[5]);
                break;
            }
            if (!xdo ({ "mousemove", sx.to_string (), sy.to_string (), "mousedown", "1" }, out err)) {
                return false;
            }
            settle (150);
            for (int i = 1; i <= 20; i++) {
                int x = sx + (tx - sx) * i / 20, y = sy + (ty - sy) * i / 20;
                xdo ({ "mousemove", x.to_string (), y.to_string () }, out err);
                settle (40);
            }
            settle (500);
            return xdo ({ "mouseup", "1" }, out err);
        }

        /* ---------------- expectations ---------------- */

        private bool wait_expect (string expect, int timeout_ms, out string detail) {
            detail = "";
            var timer = new Timer ();
            string d = "";
            while (true) {
                if (check_expect (expect, out d)) {
                    detail = "";
                    return true;
                }
                if (timer.elapsed () * 1000 > timeout_ms) {
                    detail = d;
                    return false;
                }
                settle (100);
            }
        }

        private bool check_expect (string expect, out string detail) {
            detail = "";
            string[] w = expect.strip ().split (" ");
            if (w.length == 0 || w[0] == "ok" || w[0] == "none") {
                return true;
            }
            string rest = w.length > 1 ? expect.strip ().substring (w[0].length + 1) : "";
            switch (w[0]) {
            case "window": {
                if (w.length < 3) { detail = "window <sınıf> visible|hidden|focused|absent"; return false; }
                unowned Wnck.Window? win = xw.find (w[1]);
                switch (w[2]) {
                case "absent":
                    detail = win == null ? "" : "pencere hâlâ var"; return win == null;
                case "visible":
                    if (win == null) { detail = "pencere yok: " + w[1]; return false; }
                    detail = win.is_minimized () ? "küçültülmüş" : ""; return !win.is_minimized ();
                case "hidden":
                    detail = (win == null || win.is_minimized ()) ? "" : "görünür"; return win == null || win.is_minimized ();
                case "focused":
                    if (win == null) { detail = "pencere yok: " + w[1]; return false; }
                    detail = xw.is_focused (win) ? "" : "odak başka pencerede"; return xw.is_focused (win);
                default:
                    detail = "window durumu: " + w[2]; return false;
                }
            }
            case "popup": {
                if (w.length < 3) { detail = "popup <sınıf> visible|hidden"; return false; }
                int n = xw.popup_count (w[1]);
                bool want = w[2] == "visible";
                detail = "popup sayısı %d".printf (n);
                return want ? n > 0 : n == 0;
            }
            case "geometry":
                return check_geometry (w, out detail);
            case "process": {
                if (w.length < 3) { detail = "process <ad> running|absent"; return false; }
                bool run = SysMon.running (w[1]);
                detail = run ? "çalışıyor" : "yok";
                return (w[2] == "running") == run;
            }
            case "file": {
                if (w.length < 3) { detail = "file <yol> exists|absent"; return false; }
                bool ex = FileUtils.test (expand (w[1]), FileTest.EXISTS);
                detail = ex ? "var" : "yok";
                return (w[2] == "exists") == ex;
            }
            case "count": {
                if (w.length < 3) { detail = "count <dizin> <n>"; return false; }
                int n = 0;
                try {
                    var d = Dir.open (expand (w[1]));
                    while (d.read_name () != null) { n++; }
                } catch (Error e) { detail = e.message; return false; }
                detail = "%d girdi".printf (n);
                return n == int.parse (w[2]);
            }
            case "shell": {
                int rc;
                string res = SysMon.run_shell (rest, out rc);
                detail = "rc=%d %s".printf (rc, res.strip ().replace ("\n", " / "));
                if (detail.length > 200) { detail = detail.substring (0, 200) + "…"; }
                return rc == 0;
            }
            case "conf": {
                if (w.length < 4) { detail = "conf <bölüm> <anahtar> <değer>"; return false; }
                var kf = new KeyFile ();
                try {
                    kf.load_from_file (Path.build_filename (Environment.get_user_config_dir (), "kavis", "kavis.conf"), KeyFileFlags.NONE);
                    string v = kf.get_string (w[1], w[2]);
                    detail = "değer " + v;
                    return v == w[3];
                } catch (Error e) { detail = e.message; return false; }
            }
            case "screen":
                return check_screen (w, out detail);
            default:
                detail = "bilinmeyen beklenti: " + w[0];
                return false;
            }
        }

        private string expand (string p) {
            return p.has_prefix ("~/") ? Path.build_filename (Environment.get_home_dir (), p.substring (2)) : p;
        }

        private bool check_geometry (string[] w, out string detail) {
            detail = "";
            if (w.length < 3) { detail = "geometry <sınıf> <bölge>"; return false; }
            unowned Wnck.Window? win = xw.find (w[1]);
            if (win == null) { detail = "pencere yok: " + w[1]; return false; }
            if (w[2] == "maximized") {
                detail = win.is_maximized () ? "" : "büyütülmemiş";
                return win.is_maximized ();
            }
            int fx, fy, fw, fh;
            if (!xw.frame_geometry (win, out fx, out fy, out fw, out fh)) {
                win.get_geometry (out fx, out fy, out fw, out fh);
            }
            Gdk.Rectangle wa = xw.workarea ();
            int hw = wa.width / 2, hh = wa.height / 2;
            int ex, ey, ew, eh;
            switch (w[2]) {
            case "left-half":    ex = wa.x; ey = wa.y; ew = hw; eh = wa.height; break;
            case "right-half":   ex = wa.x + hw; ey = wa.y; ew = wa.width - hw; eh = wa.height; break;
            case "top-left":     ex = wa.x; ey = wa.y; ew = hw; eh = hh; break;
            case "top-right":    ex = wa.x + hw; ey = wa.y; ew = wa.width - hw; eh = hh; break;
            case "bottom-left":  ex = wa.x; ey = wa.y + hh; ew = hw; eh = wa.height - hh; break;
            case "bottom-right": ex = wa.x + hw; ey = wa.y + hh; ew = wa.width - hw; eh = wa.height - hh; break;
            case "on-screen":
                bool inside = fx + 80 <= wa.x + wa.width && fx + fw >= wa.x + 80 && fy >= wa.y && fy + 20 <= wa.y + wa.height;
                detail = "çerçeve %d,%d %dx%d".printf (fx, fy, fw, fh);
                return inside;
            default:
                detail = "bölge: " + w[2]; return false;
            }
            /* boyut toleransı 20 (size hints yuvarlaması), konum 4 */
            bool ok = (fx - ex).abs () <= 4 && (fy - ey).abs () <= 4
                && (fw - ew).abs () <= 20 && (fh - eh).abs () <= 20;
            detail = ok ? "" : "çerçeve %d,%d %dx%d — beklenen %d,%d %dx%d".printf (fx, fy, fw, fh, ex, ey, ew, eh);
            return ok;
        }

        /* screen panel|full bright|dark — mean luminance of the region. */
        private bool check_screen (string[] w, out string detail) {
            detail = "";
            if (w.length < 3) { detail = "screen panel|full bright|dark"; return false; }
            Gdk.Pixbuf? pb = capture ();
            if (pb == null) { detail = "kare alınamadı"; return false; }
            int x0 = 0, y0 = 0, x1 = pb.width, y1 = pb.height;
            if (w[1] == "panel") {
                unowned Wnck.Window? p = xw.panel ();
                if (p == null) { detail = "panel yok"; return false; }
                int px, py, pw, ph;
                p.get_geometry (out px, out py, out pw, out ph);
                x0 = px; y0 = py; x1 = px + pw; y1 = py + ph;
            }
            double lum = luminance (pb, x0, y0, x1, y1);
            detail = "parlaklık %.0f".printf (lum);
            return w[2] == "bright" ? lum >= 128 : lum < 128;
        }

        /* ---------------- frames ---------------- */

        private Gdk.Pixbuf? capture () {
            var root = Gdk.get_default_root_window ();
            return Gdk.pixbuf_get_from_window (root, 0, 0, root.get_width (), root.get_height ());
        }

        private double luminance (Gdk.Pixbuf pb, int x0, int y0, int x1, int y1) {
            unowned uint8[] px = pb.get_pixels ();
            int rs = pb.rowstride, nc = pb.n_channels;
            double sum = 0; int n = 0;
            for (int y = y0; y < y1; y += 4) {
                for (int x = x0; x < x1; x += 4) {
                    int o = y * rs + x * nc;
                    sum += 0.299 * px[o] + 0.587 * px[o + 1] + 0.114 * px[o + 2];
                    n++;
                }
            }
            return n == 0 ? 0 : sum / n;
        }

        private double diff (Gdk.Pixbuf? a, Gdk.Pixbuf? b) {
            if (a == null || b == null || a.width != b.width || a.height != b.height) {
                return 0;
            }
            unowned uint8[] pa = a.get_pixels ();
            unowned uint8[] pb = b.get_pixels ();
            int rs = a.rowstride, nc = a.n_channels;
            int changed = 0, n = 0;
            for (int y = 0; y < a.height; y += 4) {
                for (int x = 0; x < a.width; x += 4) {
                    int o = y * rs + x * nc;
                    if (((int) pa[o] - (int) pb[o]).abs () > 8 || ((int) pa[o + 1] - (int) pb[o + 1]).abs () > 8 || ((int) pa[o + 2] - (int) pb[o + 2]).abs () > 8) {
                        changed++;
                    }
                    n++;
                }
            }
            return n == 0 ? 0 : 100.0 * changed / n;
        }

        private void save (Gdk.Pixbuf pb, string name, bool thumb) {
            try {
                Gdk.Pixbuf outpb = pb;
                if (thumb) {
                    int tw = 320, th = pb.height * 320 / int.max (pb.width, 1);
                    outpb = pb.scale_simple (tw, th, Gdk.InterpType.BILINEAR);
                }
                outpb.save (Path.build_filename (rep.dir, name), "png");
            } catch (Error e) { }
        }

        private string xprop_dump () {
            int rc;
            return SysMon.run_shell ("xprop -root _NET_ACTIVE_WINDOW _NET_CLIENT_LIST_STACKING _NET_WORKAREA; xdotool getactivewindow getwindowname getwindowgeometry 2>/dev/null; xprop -id $(xdotool getactivewindow 2>/dev/null) 2>/dev/null | head -40", out rc);
        }
    }
}
