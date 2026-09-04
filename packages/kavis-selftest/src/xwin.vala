/* kavis-selftest — window / pointer helpers on top of libwnck and raw X. */
namespace Kavis.Selftest {

    public class XWin : Object {

        private unowned Wnck.Screen screen;

        public XWin () {
            screen = Wnck.Screen.get_default ();
            screen.force_update ();
        }

        /* Let libwnck and GTK catch up with the server. */
        public void pump () {
            screen.force_update ();
            while (Gtk.events_pending ()) {
                Gtk.main_iteration ();
            }
        }

        public static bool class_matches (Wnck.Window w, string cls) {
            string want = cls.down ();
            string? a = w.get_class_group_name ();
            string? b = w.get_class_instance_name ();
            return (a != null && a.down ().contains (want))
                || (b != null && b.down ().contains (want));
        }

        /* Top-most normal window of the class (stacking order). */
        public unowned Wnck.Window? find (string cls) {
            pump ();
            unowned Wnck.Window? hit = null;
            foreach (unowned Wnck.Window w in screen.get_windows_stacked ()) {
                if (w.get_window_type () == Wnck.WindowType.DESKTOP) {
                    continue;
                }
                if (class_matches (w, cls)) {
                    hit = w;
                }
            }
            return hit;
        }

        public unowned Wnck.Window? panel () {
            pump ();
            foreach (unowned Wnck.Window w in screen.get_windows ()) {
                if (w.get_window_type () == Wnck.WindowType.DOCK
                    && class_matches (w, "kavis-panel")) {
                    return w;
                }
            }
            return null;
        }

        public bool is_focused (Wnck.Window w) {
            pump ();
            unowned Wnck.Window? a = screen.get_active_window ();
            return a != null && a.get_xid () == w.get_xid ();
        }

        /* Window list snapshot for windows-NNN.txt and anomaly checks. */
        public string list_windows () {
            pump ();
            var sb = new StringBuilder ();
            foreach (unowned Wnck.Window w in screen.get_windows_stacked ()) {
                int x, y, ww, wh;
                w.get_geometry (out x, out y, out ww, out wh);
                sb.append_printf ("0x%08lx %-14s %-24s %4d,%-4d %4dx%-4d %s%s%s %s\n",
                    (ulong) w.get_xid (),
                    w.get_window_type ().to_string ().replace ("WNCK_WINDOW_", "").down (),
                    (w.get_class_group_name () ?? "?") + "/" + (w.get_class_instance_name () ?? "?"),
                    x, y, ww, wh,
                    w.is_minimized () ? "min " : "",
                    w.is_maximized () ? "max " : "",
                    is_focused (w) ? "focus" : "",
                    w.get_name ());
            }
            return sb.str;
        }

        public string[] window_classes () {
            pump ();
            string[] res = {};
            foreach (unowned Wnck.Window w in screen.get_windows ()) {
                string? c = w.get_class_group_name ();
                if (c != null) {
                    res += c.down ();
                }
            }
            return res;
        }

        /* Frame rectangle straight from X (root coordinates) — the same
         * approach kavis-snap uses: libwnck's cache lags during moves. */
        public bool frame_geometry (Wnck.Window w, out int fx, out int fy,
                                    out int fw, out int fh) {
            fx = 0; fy = 0; fw = 0; fh = 0;
            unowned X.Display xd =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            X.Window root = xd.default_root_window ();
            X.Window frame = (X.Window) w.get_xid ();
            Gdk.error_trap_push ();
            for (int depth = 0; depth < 8; depth++) {
                X.Window r, parent;
                X.Window[] children;
                xd.query_tree (frame, out r, out parent, out children);
                if (parent == root || parent == 0) {
                    break;
                }
                frame = parent;
            }
            X.WindowAttributes attrs;
            xd.get_window_attributes (frame, out attrs);
            X.Window child;
            int rx, ry;
            bool ok = xd.translate_coordinates (frame, root, 0, 0, out rx, out ry, out child);
            int err = Gdk.error_trap_pop ();
            if (err != 0 || !ok || attrs.width <= 0) {
                return false;
            }
            fx = rx; fy = ry; fw = attrs.width; fh = attrs.height;
            return true;
        }

        /* Mapped override-redirect windows (menus, popups) whose WM_CLASS
         * contains cls — these never reach libwnck. */
        public int popup_count (string cls) {
            unowned X.Display xd =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            X.Window root = xd.default_root_window ();
            X.Window r, parent;
            X.Window[] children;
            int n = 0;
            Gdk.error_trap_push ();
            xd.query_tree (root, out r, out parent, out children);
            foreach (X.Window c in children) {
                X.WindowAttributes attrs;
                xd.get_window_attributes (c, out attrs);
                if (!attrs.override_redirect || attrs.map_state != X.MapState.IsViewable
                    || attrs.width < 40 || attrs.height < 40) {
                    continue;
                }
                /* WM_CLASS = "instance\0class\0" — search both names */
                X.Atom at; int af; ulong cnt, ba; void* prop;
                if (xd.get_window_property (c, X.XA_WM_CLASS, 0, 64, false,
                        X.XA_STRING, out at, out af, out cnt, out ba, out prop) == 0
                    && prop != null && cnt > 0) {
                    var sb = new StringBuilder ();
                    unowned uint8[] data = (uint8[]) prop;
                    for (int i = 0; i < (int) cnt; i++) {
                        sb.append_c (data[i] == 0 ? ' ' : (char) data[i]);
                    }
                    X.free (prop);
                    if (sb.str.down ().contains (cls.down ())) {
                        n++;
                    }
                }
            }
            Gdk.error_trap_pop_ignored ();
            return n;
        }

        /* WM_CLASS of an X window as "instance class" (both names). */
        private string wm_class (X.Display xd, X.Window w) {
            X.Atom at; int af; ulong cnt, ba; void* prop;
            var sb = new StringBuilder ();
            if (xd.get_window_property (w, X.XA_WM_CLASS, 0, 64, false,
                    X.XA_STRING, out at, out af, out cnt, out ba, out prop) == X.Success
                && prop != null && cnt > 0) {
                unowned uint8[] data = (uint8[]) prop;
                for (int i = 0; i < (int) cnt; i++) {
                    sb.append_c (data[i] == 0 ? ' ' : (char) data[i]);
                }
                X.free (prop);
            }
            return sb.str;
        }

        /* Managed windows of a class, read from the server every time.
         *
         * WHY NOT libwnck: its window list is a cache that lags the
         * server — the same lag that broke edge snapping twice. A close
         * request sent to a cached window that no longer exists looks
         * like it worked and changes nothing, which is exactly the
         * "close window does not work" the v0.4-test4 report showed
         * five times. _NET_CLIENT_LIST is the window manager's own,
         * current answer. */
        public X.Window[] clients_of (string cls) {
            unowned X.Display xd =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            X.Window root = xd.default_root_window ();
            X.Window[] res = {};
            X.Atom list = xd.intern_atom ("_NET_CLIENT_LIST", true);
            if ((X.ID) list == X.None) {
                return res;
            }
            X.Atom at; int af; ulong cnt, ba; void* prop;
            Gdk.error_trap_push ();
            if (xd.get_window_property (root, list, 0, 1024, false, X.XA_WINDOW,
                    out at, out af, out cnt, out ba, out prop) == X.Success
                && prop != null) {
                unowned X.Window[] wins = (X.Window[]) prop;
                for (int i = 0; i < (int) cnt; i++) {
                    if (!wm_class (xd, wins[i]).down ().contains (cls.down ())) {
                        continue;
                    }
                    /* NEVER the desktop or the panel. "nemo" matches
                     * nemo-desktop too, and the desktop layer does not
                     * answer a close request — so the escalation
                     * SIGTERMed the desktop out of the session and
                     * every scenario after it ran on a broken one.
                     * A scenario asks to close a window, never the
                     * furniture. */
                    if (is_furniture (xd, wins[i])) {
                        continue;
                    }
                    res += wins[i];
                }
                X.free (prop);
            }
            Gdk.error_trap_pop_ignored ();
            return res;
        }

        /* Is this the desktop layer or a panel? Read from
         * _NET_WM_WINDOW_TYPE, which is how the window manager itself
         * tells them apart. */
        private bool is_furniture (X.Display xd, X.Window w) {
            X.Atom type_atom = xd.intern_atom ("_NET_WM_WINDOW_TYPE", true);
            if ((X.ID) type_atom == X.None) {
                return false;
            }
            X.Atom desktop = xd.intern_atom ("_NET_WM_WINDOW_TYPE_DESKTOP", true);
            X.Atom dock = xd.intern_atom ("_NET_WM_WINDOW_TYPE_DOCK", true);
            X.Atom at; int af; ulong cnt, ba; void* prop;
            bool furniture = false;
            if (xd.get_window_property (w, type_atom, 0, 8, false, X.XA_ATOM,
                    out at, out af, out cnt, out ba, out prop) == X.Success
                && prop != null) {
                unowned X.Atom[] types = (X.Atom[]) prop;
                for (int i = 0; i < (int) cnt; i++) {
                    if (types[i] == desktop || types[i] == dock) {
                        furniture = true;
                    }
                }
                X.free (prop);
            }
            return furniture;
        }

        /* _NET_WM_PID, so a window that ignores the close request can
         * still be ended politely. 0 when the window does not say. */
        public int pid_of (X.Window w) {
            unowned X.Display xd =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            X.Atom prop_atom = xd.intern_atom ("_NET_WM_PID", true);
            if ((X.ID) prop_atom == X.None) {
                return 0;
            }
            X.Atom at; int af; ulong cnt, ba; void* prop;
            int pid = 0;
            Gdk.error_trap_push ();
            if (xd.get_window_property (w, prop_atom, 0, 1, false, X.XA_CARDINAL,
                    out at, out af, out cnt, out ba, out prop) == X.Success
                && prop != null && cnt > 0) {
                unowned ulong[] v = (ulong[]) prop;
                pid = (int) v[0];
                X.free (prop);
            }
            Gdk.error_trap_pop_ignored ();
            return pid;
        }

        /* The EWMH close request — what a taskbar's "close" does and
         * what `wmctrl -c` sends. The window manager then asks the
         * client to quit (WM_DELETE_WINDOW), so the application can run
         * its own shutdown. */
        public void request_close (X.Window w) {
            unowned X.Display xd =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            X.Window root = xd.default_root_window ();
            X.Event ev = {};
            ev.xclient.type = X.EventType.ClientMessage;
            ev.xclient.window = w;
            ev.xclient.message_type = xd.intern_atom ("_NET_CLOSE_WINDOW", false);
            ev.xclient.format = 32;
            ev.xclient.l[0] = (long) Gdk.X11.get_server_time (
                (Gdk.X11.Window) Gdk.get_default_root_window ());
            /* Source indication 2 = "a pager", i.e. a deliberate request
             * from a control surface rather than from the app itself. */
            ev.xclient.l[1] = 2;
            Gdk.error_trap_push ();
            xd.send_event (root, false,
                           X.EventMask.SubstructureNotifyMask
                           | X.EventMask.SubstructureRedirectMask, ref ev);
            xd.flush ();
            Gdk.error_trap_pop_ignored ();
        }

        public Gdk.Rectangle workarea () {
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor () ?? display.get_monitor (0);
            return monitor.get_workarea ();
        }

        public Gdk.Rectangle screen_rect () {
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor () ?? display.get_monitor (0);
            return monitor.get_geometry ();
        }

        /* X round trip timed: a server that takes >2 s to answer is
         * "frozen" for the anomaly log. */
        public int sync_ms () {
            var t = new Timer ();
            Gdk.Display.get_default ().sync ();
            return (int) (t.elapsed () * 1000);
        }
    }
}
