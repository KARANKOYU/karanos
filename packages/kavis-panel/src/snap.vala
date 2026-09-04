/* kavis-snap — drag-to-edge window snapping + W11 drag rules (madde 6,
 * v0.4-test1 C1/C2/C3).
 *
 * Openbox has no built-in aero snap and patching Debian's openbox is
 * off the table (signed archive package). This small daemon does what
 * opensnap does, minus its reported flaws (madde 59 scan,
 * docs/referans/grup-d-taramasi.md):
 *   - UNSNAP is built in: the pre-snap geometry is remembered and
 *     given back the moment the user drags the window away;
 *   - the monitor layout is read on EVERY event, never cached, so
 *     plugging/unplugging monitors cannot leave stale zones;
 *   - zones are computed per-monitor (multi-monitor from day one).
 *
 * Mechanism: poll the pointer (80 ms idle — one XQueryPointer round
 * trip; 16 ms while a button is held on a window, so a drag never lags
 * behind the hand). A drag is recognized only when the pressed
 * window's frame actually moves while button 1 is down — clicking the
 * panel or rubber-banding the desktop can never trigger a snap. Edges
 * give halves, corners give quarters, the top edge maximizes. The
 * pressed window is the one UNDER THE POINTER (C1: the active window
 * was wrong when the press itself changed focus).
 *
 * C3 — dragging a MAXIMIZED window: rc.xml (0210 hook) tells openbox
 * to do nothing for that case; this daemon unmaximizes, puts the
 * window under the pointer at the same proportional titlebar spot
 * (W11) and follows the pointer until release, then the usual zones
 * apply. Openbox's own Move would restore the old position first and
 * leave the window far from the hand.
 *
 * C2 — the titlebar always stays on screen: after every drag (ours or
 * openbox's) and on any geometry change while no button is held, a
 * window whose titlebar left the work area is pulled back.
 *
 * D1 — the title bar says the name Kavis uses. Renaming an application
 * in its .desktop file changes the menu and the taskbar, but the title
 * bar shows what the application writes into _NET_WM_NAME, so Notepad
 * still introduced itself as "Mousepad". The map in
 * /etc/kavis/window-title-map.conf is applied to every title change.
 * This daemon has the window list open already; a second process
 * watching the same windows would be waste.
 */

namespace Kavis {

    public class SnapDaemon : Object {

        private const int POLL_IDLE_MS = 80;
        private const int POLL_DRAG_MS = 16;
        private const int EDGE = 3;
        private const int CORNER = 180;
        private const int DRAG_MIN = 8;
        /* C2: at least this many pixels must stay inside (horizontal);
         * the whole titlebar vertically. */
        private const int KEEP_INSIDE = 80;

        private enum Zone { NONE, LEFT, RIGHT, TOP, TL, TR, BL, BR }

        private const Wnck.WindowMoveResizeMask ALL_MASK =
            Wnck.WindowMoveResizeMask.X | Wnck.WindowMoveResizeMask.Y
            | Wnck.WindowMoveResizeMask.WIDTH
            | Wnck.WindowMoveResizeMask.HEIGHT;

        private unowned Wnck.Screen screen;
        private Gtk.Window preview;
        private bool composited;

        /* xid → pre-snap outer geometry, for unsnap. */
        private HashTable<ulong, Gdk.Rectangle?> saved =
            new HashTable<ulong, Gdk.Rectangle?> (direct_hash, direct_equal);

        private bool button_was_down = false;
        private bool dragging = false;
        /* C1: preview fade and settle animation. `animating` also tells
         * the C2 keep-on-screen watcher to stay out of the way while a
         * window is travelling into its zone. */
        private uint preview_fade = 0;
        private double preview_opacity = 0;
        private bool preview_shown = false;
        private uint settle_timer = 0;
        private bool animating = false;
        private bool restored_this_drag = false;
        private Gdk.Rectangle unsnap_size = { 0, 0, 0, 0 };
        private unowned Wnck.Window? drag_window = null;
        private Gdk.Rectangle press_geometry;
        private int press_x = 0;
        private int press_y = 0;
        private Zone zone = Zone.NONE;

        /* C3 takeover state. */
        private bool press_was_maximized = false;
        private bool taking_over = false;
        private bool takeover_placed = false;
        private double grab_ratio = 0;   /* pointer x / frame width */
        private int grab_dy = 0;         /* pointer y - frame y */
        /* Bias measured after the first placement: the frame position
         * wnck reads and the gravity coordinate set_geometry uses are
         * not always the same under openbox (the Xvfb test showed a
         * vertical difference of one title height) — measured once and
         * corrected on every following step. */
        private bool bias_known = false;
        private int bias_x = 0;
        private int bias_y = 0;
        private int intended_x = 0;
        private int intended_y = 0;

        /* KAVIS_SNAP_DEBUG=1: every state transition to stderr (VM
         * diagnosis, selftest). Off by default — zero cost. */
        private bool debug_on = Environment.get_variable ("KAVIS_SNAP_DEBUG") != null;

        private void dbg (string fmt, ...) {
            if (!debug_on) {
                return;
            }
            var l = va_list ();
            var msg = fmt.vprintf (l);
            var now = new DateTime.now_local ();
            printerr ("%s.%03d kavis-snap: %s\n", now.format ("%H:%M:%S"),
                      now.get_microsecond () / 1000, msg);
        }

        public SnapDaemon () {
            screen = Wnck.Screen.get_default ();
            screen.force_update ();

            preview = new Gtk.Window (Gtk.WindowType.POPUP);
            preview.set_type_hint (Gdk.WindowTypeHint.NOTIFICATION);
            preview.set_accept_focus (false);
            preview.set_app_paintable (true);
            var gdk_screen = preview.get_screen ();
            var rgba = gdk_screen.get_rgba_visual ();
            composited = (rgba != null && gdk_screen.is_composited ());
            if (composited) {
                preview.set_visual (rgba);
            }
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.get_style_context ().add_class ("kavis-snap-preview");
            preview.add (box);
            load_css ();

            /* C2: watch every window's geometry changes (keyboard, the
             * app moving itself). Existing ones + those opened later. */
            load_title_map ();
            foreach (unowned Wnck.Window w in screen.get_windows ()) {
                watch_window (w);
            }
            screen.window_opened.connect ((w) => watch_window (w));

            Timeout.add (POLL_IDLE_MS, poll);
            dbg ("started composited=%s windows=%u", composited.to_string (),
                 screen.get_windows ().length ());
        }

        private void load_css () {
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data ("""
                    /* C1: a translucent pane in the accent colour with
                       the window corner radius, so it reads as "the
                       window will land here" rather than as a marker.
                       Same 8px as a real window (docs/tasarim-dili.md). */
                    .kavis-snap-preview {
                      background-color: rgba(45, 212, 191, 0.16);
                      border: 2px solid rgba(45, 212, 191, 0.7);
                      border-radius: 8px;
                    }
                    """, -1);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-snap: could not load CSS: %s", e.message);
            }
        }

        private bool pointer_state (out int x, out int y, out bool down) {
            x = 0; y = 0; down = false;
            var display = Gdk.Display.get_default ();
            unowned X.Display xdisplay =
                ((Gdk.X11.Display) display).get_xdisplay ();
            X.Window root = xdisplay.default_root_window ();
            X.Window r, c;
            int wx, wy;
            uint mask;
            if (!xdisplay.query_pointer (root, out r, out c, out x, out y,
                                         out wx, out wy, out mask)) {
                dbg ("query_pointer failed");
                return false;
            }
            /* Button1Mask = 1<<8 (X.h) — no such constant in the vapi. */
            down = (mask & (1 << 8)) != 0;
            return true;
        }

        /* Variable-rate polling: 16 ms while the button is held on a
         * window, 80 ms when idle. */
        private bool poll () {
            int x, y;
            bool down;
            if (!pointer_state (out x, out y, out down)) {
                return Source.CONTINUE;
            }

            if (down && !button_was_down) {
                begin_press (x, y);
            }
            if (down && drag_window != null) {
                track_drag (x, y);
            }
            if (!down && button_was_down) {
                end_drag ();
            }
            bool fast_before = button_was_down && drag_window != null;
            button_was_down = down;
            bool fast_now = down && drag_window != null;
            if (fast_now != fast_before) {
                Timeout.add (fast_now ? POLL_DRAG_MS : POLL_IDLE_MS, poll);
                return Source.REMOVE;
            }
            return Source.CONTINUE;
        }

        /* Frame geometry straight from the X server, root coordinates.
         * Wnck's cached geometry LAGS during an openbox interactive
         * move: the client gets no ConfigureNotify until the button is
         * released (v0.4-test2 E1, seen in a real VM — Xvfb tests moved
         * windows with xdotool, which never showed this), so the "did
         * the frame move" drag test must not depend on it. The frame is
         * the client's top-most ancestor below root (openbox reparents
         * the client straight into the frame window); an unreparented
         * client is its own frame. */
        private bool frame_geometry (Wnck.Window w, out int fx, out int fy,
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
            bool ok = xd.translate_coordinates (frame, root, 0, 0,
                                                out rx, out ry, out child);
            int err = Gdk.error_trap_pop ();
            if (err != 0 || !ok || attrs.width <= 0) {
                return false;   /* window closed / invalid */
            }
            fx = rx; fy = ry;
            fw = attrs.width; fh = attrs.height;
            return true;
        }

        /* Move/resize by FRAME rectangle (root coordinates). libwnck
         * always converts the frame rectangle to client coordinates by
         * adding the frame extents and passes the gravity through; with
         * NorthWest gravity openbox then treats that client position as
         * the frame origin once more, so a snapped openbox-decorated
         * window landed one title height too low (Xvfb harness, debug
         * turu — CSD windows have no extents, the VM Tilix test could
         * not show it). STATIC gravity makes openbox take the converted
         * pair as client coordinates: frame lands exactly at fx,fy. */
        private void set_frame_geometry (Wnck.Window w,
                                         Wnck.WindowMoveResizeMask mask,
                                         int fx, int fy, int fw, int fh) {
            w.set_geometry (Wnck.WindowGravity.STATIC, mask, fx, fy, fw, fh);
        }

        /* Topmost normal window whose frame contains the point. */
        private unowned Wnck.Window? window_at (int x, int y) {
            unowned List<Wnck.Window> stacked = screen.get_windows_stacked ();
            unowned Wnck.Window? hit = null;
            foreach (unowned Wnck.Window w in stacked) {
                if (w.is_skip_tasklist () || w.is_minimized ()
                    || w.get_window_type () == Wnck.WindowType.DESKTOP
                    || w.get_window_type () == Wnck.WindowType.DOCK) {
                    continue;
                }
                int wx, wy, ww, wh;
                w.get_geometry (out wx, out wy, out ww, out wh);
                if (x >= wx && x < wx + ww && y >= wy && y < wy + wh) {
                    hit = w;   /* list is bottom-to-top: last one is topmost */
                }
            }
            return hit;
        }

        /* Whether a compositor is up. Read again at every press: at
         * startup kavis-snap can win the race against picom, and a
         * daemon that decided "no compositor" once would then never
         * show a preview for the rest of the session — which is what
         * "there is no preview" looked like in the VM. */
        private void refresh_composited () {
            var s = preview.get_screen ();
            bool now = s.get_rgba_visual () != null && s.is_composited ();
            if (now != composited) {
                dbg ("compositing %s", now ? "appeared" : "went away");
                composited = now;
                if (now) {
                    preview.set_visual (s.get_rgba_visual ());
                }
            }
        }

        private void begin_press (int x, int y) {
            refresh_composited ();
            dragging = false;
            restored_this_drag = false;
            taking_over = false;
            takeover_placed = false;
            zone = Zone.NONE;
            drag_window = window_at (x, y);
            dbg ("press %d,%d window=%s", x, y,
                 drag_window == null ? "(none)" : drag_window.get_name ());
            if (drag_window == null || drag_window.is_fullscreen ()) {
                drag_window = null;
                return;
            }
            press_x = x;
            press_y = y;
            if (!frame_geometry (drag_window, out press_geometry.x,
                                 out press_geometry.y,
                                 out press_geometry.width,
                                 out press_geometry.height)) {
                drag_window.get_geometry (out press_geometry.x,
                                          out press_geometry.y,
                                          out press_geometry.width,
                                          out press_geometry.height);
            }
            press_was_maximized = drag_window.is_maximized ();
            if (press_was_maximized) {
                /* Was the press on the titlebar? (between the frame top
                 * and the client top). A press in the content area is
                 * not a drag. */
                int cx, cy, cw, ch;
                drag_window.get_client_window_geometry (
                    out cx, out cy, out cw, out ch);
                int title_h = int.max (cy - press_geometry.y, 24);
                if (y > press_geometry.y + title_h) {
                    press_was_maximized = false;
                } else {
                    grab_ratio = (double) (x - press_geometry.x)
                        / (double) int.max (press_geometry.width, 1);
                    grab_dy = y - press_geometry.y;
                }
            }
        }

        private void track_drag (int x, int y) {
            int wx, wy, ww, wh;
            if (!frame_geometry (drag_window, out wx, out wy, out ww, out wh)) {
                drag_window.get_geometry (out wx, out wy, out ww, out wh);
            }

            /* C3: maximized window — openbox does nothing in this case
             * (rc.xml If rule); once the pointer passes the threshold
             * we take over the drag. */
            if (press_was_maximized && !taking_over) {
                if ((x - press_x).abs () < DRAG_MIN
                    && (y - press_y).abs () < DRAG_MIN) {
                    return;
                }
                taking_over = true;
                dragging = true;
                drag_window.unmaximize ();
                return;   /* geometry arrives on the next poll */
            }
            if (taking_over) {
                follow_pointer (x, y, wx, wy, ww, wh);
                zone = zone_at (x, y);
                update_preview (x, y);
                return;
            }

            if (!dragging) {
                /* Drag = the window actually moved. A panel click /
                 * rubber-band on the desktop never triggers it. */
                if ((wx - press_geometry.x).abs () < DRAG_MIN
                    && (wy - press_geometry.y).abs () < DRAG_MIN) {
                    return;
                }
                dragging = true;
                dbg ("drag started frame %d,%d (at press %d,%d)",
                     wx, wy, press_geometry.x, press_geometry.y);
            }

            /* Unsnap: if a window we snapped is being dragged away,
             * give back its old size immediately (W11 behavior). */
            if (!restored_this_drag) {
                restored_this_drag = true;
                ulong xid = drag_window.get_xid ();
                Gdk.Rectangle? old = saved.lookup (xid);
                if (old != null) {
                    saved.remove (xid);
                    /* Tried during the drag (shrink in hand like W11);
                     * openbox ignores it while its own move is running
                     * (Xvfb harness), so end_drag applies it once more. */
                    unsnap_size = { 0, 0, old.width, old.height };
                    drag_window.set_geometry (Wnck.WindowGravity.STATIC,
                        Wnck.WindowMoveResizeMask.WIDTH
                        | Wnck.WindowMoveResizeMask.HEIGHT,
                        0, 0, old.width, old.height);
                    /* If re-snapped while snapped, the 'old size' must
                     * stay the REAL old size, not half-screen: the
                     * press geometry is now the restored size. */
                    press_geometry.width = old.width;
                    press_geometry.height = old.height;
                }
            }

            Zone before = zone;
            zone = zone_at (x, y);
            if (zone != before) {
                dbg ("zone %d -> %d pointer %d,%d", (int) before, (int) zone, x, y);
            }
            update_preview (x, y);
        }

        /* C3: put the restored window under the pointer at the same
         * proportional titlebar spot and follow. Wait while the
         * geometry is still large (unmaximize not yet processed). */
        private void follow_pointer (int x, int y, int wx, int wy,
                                     int ww, int wh) {
            if (!takeover_placed) {
                if (ww >= press_geometry.width - 2
                    && wh >= press_geometry.height - 2) {
                    return;   /* still at maximized size */
                }
                takeover_placed = true;
                bias_known = false;
                ulong xid = drag_window.get_xid ();
                saved.remove (xid);
                press_geometry = { 0, 0, ww, wh };
            } else if (!bias_known) {
                int dx = wx - intended_x, dy = wy - intended_y;
                if (dx.abs () < 200 && dy.abs () < 200) {
                    bias_x = dx;
                    bias_y = dy;
                }
                bias_known = true;
            }
            intended_x = x - (int) (grab_ratio * ww);
            intended_y = y - grab_dy;
            set_frame_geometry (drag_window,
                Wnck.WindowMoveResizeMask.X | Wnck.WindowMoveResizeMask.Y,
                intended_x - bias_x, intended_y - bias_y, 0, 0);
        }

        private Zone zone_at (int x, int y) {
            Gdk.Rectangle wa = workarea_at (x, y);
            bool left = x <= wa.x + EDGE;
            bool right = x >= wa.x + wa.width - 1 - EDGE;
            bool top = y <= wa.y + EDGE;
            bool bottom = y >= wa.y + wa.height - 1 - EDGE;
            if (left) {
                if (y <= wa.y + CORNER) { return Zone.TL; }
                if (y >= wa.y + wa.height - CORNER) { return Zone.BL; }
                return Zone.LEFT;
            }
            if (right) {
                if (y <= wa.y + CORNER) { return Zone.TR; }
                if (y >= wa.y + wa.height - CORNER) { return Zone.BR; }
                return Zone.RIGHT;
            }
            if (top) {
                if (x <= wa.x + CORNER) { return Zone.TL; }
                if (x >= wa.x + wa.width - CORNER) { return Zone.TR; }
                return Zone.TOP;
            }
            if (bottom) {
                if (x <= wa.x + CORNER) { return Zone.BL; }
                if (x >= wa.x + wa.width - CORNER) { return Zone.BR; }
            }
            return Zone.NONE;
        }

        /* Monitor layout is read fresh every time (opensnap lesson). */
        private Gdk.Rectangle workarea_at (int x, int y) {
            var display = Gdk.Display.get_default ();
            var monitor = display.get_monitor_at_point (x, y);
            return monitor.get_workarea ();
        }

        private Gdk.Rectangle zone_rect (Zone z, Gdk.Rectangle wa) {
            var r = Gdk.Rectangle ();
            int half_w = wa.width / 2;
            int half_h = wa.height / 2;
            switch (z) {
            case Zone.LEFT:
                r = { wa.x, wa.y, half_w, wa.height };
                break;
            case Zone.RIGHT:
                r = { wa.x + half_w, wa.y, wa.width - half_w, wa.height };
                break;
            case Zone.TL:
                r = { wa.x, wa.y, half_w, half_h };
                break;
            case Zone.TR:
                r = { wa.x + half_w, wa.y, wa.width - half_w, half_h };
                break;
            case Zone.BL:
                r = { wa.x, wa.y + half_h, half_w, wa.height - half_h };
                break;
            case Zone.BR:
                r = { wa.x + half_w, wa.y + half_h,
                      wa.width - half_w, wa.height - half_h };
                break;
            default:   /* TOP: full work area (maximize preview) */
                r = wa;
                break;
            }
            return r;
        }

        private void update_preview (int x, int y) {
            if (!composited) {
                return;   /* uncomposited preview would draw an opaque box */
            }
            if (zone == Zone.NONE) {
                fade_preview (false);
                return;
            }
            Gdk.Rectangle r = zone_rect (zone, workarea_at (x, y));
            preview.set_size_request (r.width, r.height);
            preview.resize (r.width, r.height);
            preview.move (r.x, r.y);
            fade_preview (true);
        }

        /* C1: the preview appears and leaves on the design curve rather
         * than blinking. 180 ms, the same as every other transition.
         *
         * The raise is not decoration: the preview is an override-
         * redirect window, so the window manager never restacks it, and
         * the window openbox raises while you drag it would otherwise
         * end up on top of the preview — which is exactly "there is no
         * preview" from the user's side. */
        private void fade_preview (bool visible) {
            if (visible == preview_shown && preview_fade != 0) {
                return;
            }
            if (visible == preview_shown && preview_opacity == (visible ? 1.0 : 0.0)) {
                if (visible) {
                    preview.get_window ().raise ();
                }
                return;
            }
            preview_shown = visible;
            if (visible) {
                preview.set_opacity (preview_opacity);
                preview.show_all ();
                preview.get_window ().raise ();
            }
            if (preview_fade != 0) {
                Source.remove (preview_fade);
            }
            double from = preview_opacity;
            double to = visible ? 1.0 : 0.0;
            var timer = new Timer ();
            preview_fade = Timeout.add (16, () => {
                double t = timer.elapsed () * 1000 / Kavis.Easing.DURATION_MS;
                if (t >= 1) {
                    preview_opacity = to;
                    preview.set_opacity (to);
                    if (to == 0) {
                        preview.hide ();
                    }
                    preview_fade = 0;
                    return Source.REMOVE;
                }
                preview_opacity = from + (to - from) * Kavis.Easing.ease (t);
                preview.set_opacity (preview_opacity);
                return Source.CONTINUE;
            });
        }

        /* C1: the window travels into its zone instead of teleporting.
         *
         * The steps are frame geometry changes on the design curve, one
         * per frame for 180 ms, and the last one sets the exact target
         * so rounding can never leave the window a pixel off. Openbox
         * processes each as an ordinary configure — the same traffic a
         * drag already produces, so nothing new is being asked of the
         * application. */
        private void animate_to (Wnck.Window w, Gdk.Rectangle from,
                                 Gdk.Rectangle to, owned Func<void*>? done) {
            if (settle_timer != 0) {
                Source.remove (settle_timer);
                settle_timer = 0;
            }
            if (!composited || from.width <= 0) {
                set_frame_geometry (w, ALL_MASK, to.x, to.y, to.width, to.height);
                if (done != null) { done (null); }
                return;
            }
            animating = true;
            unowned Wnck.Window win = w;
            var timer = new Timer ();
            settle_timer = Timeout.add (16, () => {
                double t = timer.elapsed () * 1000 / Kavis.Easing.DURATION_MS;
                if (t >= 1) {
                    set_frame_geometry (win, ALL_MASK,
                                        to.x, to.y, to.width, to.height);
                    settle_timer = 0;
                    animating = false;
                    if (done != null) { done (null); }
                    return Source.REMOVE;
                }
                set_frame_geometry (win, ALL_MASK,
                    Kavis.Easing.step (from.x, to.x, t),
                    Kavis.Easing.step (from.y, to.y, t),
                    Kavis.Easing.step (from.width, to.width, t),
                    Kavis.Easing.step (from.height, to.height, t));
                return Source.CONTINUE;
            });
        }

        private void end_drag () {
            dbg ("released dragging=%s zone=%d window=%s",
                 dragging.to_string (), (int) zone,
                 drag_window == null ? "(none)" : drag_window.get_name ());
            fade_preview (false);
            if (dragging && drag_window != null) {
                if (zone != Zone.NONE) {
                    apply_zone ();
                } else {
                    if (restored_this_drag && unsnap_size.width > 0) {
                        drag_window.set_geometry (Wnck.WindowGravity.STATIC,
                            Wnck.WindowMoveResizeMask.WIDTH
                            | Wnck.WindowMoveResizeMask.HEIGHT,
                            0, 0, unsnap_size.width, unsnap_size.height);
                    }
                    clamp_to_screen (drag_window);
                }
            }
            unsnap_size = { 0, 0, 0, 0 };
            drag_window = null;
            dragging = false;
            taking_over = false;
            zone = Zone.NONE;
        }

        private void apply_zone () {
            int px, py;
            bool down;
            pointer_state (out px, out py, out down);
            Gdk.Rectangle wa = workarea_at (px, py);

            ulong xid = drag_window.get_xid ();
            if (saved.lookup (xid) == null) {
                /* Pre-snap size: the one at the start of the drag. */
                saved.insert (xid, press_geometry);
            }

            Gdk.Rectangle r = zone_rect (zone, wa);
            drag_window.unmaximize ();

            /* Where it is now, so the settle can start from there. */
            var from = Gdk.Rectangle ();
            int fx, fy, fw, fh;
            if (frame_geometry (drag_window, out fx, out fy, out fw, out fh)) {
                from = { fx, fy, fw, fh };
            }
            unowned Wnck.Window w = drag_window;
            bool maximize = (zone == Zone.TOP);
            animate_to (w, from, r, (_) => {
                /* The top edge means maximize, not "cover the work
                 * area": the window must come back to its old size on
                 * unmaximize, and the taskbar must stay reserved. The
                 * animation lands on the work area first so the state
                 * change is invisible. */
                if (maximize) {
                    w.maximize ();
                }
            });
        }

        /* --- C2: the titlebar stays on screen -------------------------- */

        /* --- D1: the vendor's name out of the title bar ------------- */

        /* vendor name → the name Kavis uses, from
         * /etc/kavis/window-title-map.conf. Empty when the file is
         * missing, and then nothing is rewritten. */
        private HashTable<string, string> title_map =
            new HashTable<string, string> (str_hash, str_equal);

        private void load_title_map () {
            /* The path is overridable so tools/check-snap.sh can point
             * at the file in the source tree; unset on a real system. */
            string path = Environment.get_variable ("KAVIS_TITLE_MAP")
                ?? "/etc/kavis/window-title-map.conf";
            string contents;
            try {
                FileUtils.get_contents (path, out contents);
            } catch (Error e) {
                return;
            }
            foreach (unowned string line in contents.split ("\n")) {
                string trimmed = line.strip ();
                if (trimmed == "" || trimmed.has_prefix ("#")) {
                    continue;
                }
                int eq = trimmed.index_of ("=");
                if (eq > 0) {
                    string from = trimmed.substring (0, eq).strip ();
                    string to = trimmed.substring (eq + 1).strip ();
                    if (from != "" && from != to) {
                        title_map.insert (from, to);
                    }
                }
            }
            dbg ("title map: %u entries", title_map.size ());
        }

        /* Whole-word replacement, so "Mousepad" in "notes - Mousepad"
         * becomes "Notepad" while a file actually NAMED mousepad.txt is
         * left alone. */
        private string rename_in (string title) {
            string result = title;
            title_map.foreach ((from, to) => {
                int at = 0;
                while (true) {
                    int i = result.index_of (from, at);
                    if (i < 0) {
                        break;
                    }
                    bool left = (i == 0) || !result[i - 1].isalnum ();
                    int end = i + from.length;
                    bool right = (end >= result.length)
                        || !result[end].isalnum ();
                    if (left && right) {
                        result = result.substring (0, i) + to
                            + result.substring (end);
                        at = i + to.length;
                    } else {
                        at = end;
                    }
                }
            });
            return result;
        }

        /* Rewriting _NET_WM_NAME makes the window manager redraw the
         * title. It cannot loop: the replacement contains no vendor
         * name, so the PropertyNotify our own write causes finds
         * nothing left to change. */
        private void fix_title (Wnck.Window w) {
            if (title_map.size () == 0) {
                return;
            }
            string? name = w.get_name ();
            if (name == null || name == "") {
                return;
            }
            string wanted = rename_in (name);
            if (wanted == name) {
                return;
            }
            unowned X.Display xd =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            X.Atom net_name = xd.intern_atom ("_NET_WM_NAME", false);
            X.Atom utf8 = xd.intern_atom ("UTF8_STRING", false);
            Gdk.error_trap_push ();
            xd.change_property ((X.Window) w.get_xid (), net_name, utf8, 8,
                                X.PropMode.Replace,
                                (uchar[]) wanted.data, wanted.length);
            xd.flush ();
            Gdk.error_trap_pop_ignored ();
            dbg ("title '%s' -> '%s'", name, wanted);
        }

        private void watch_window (Wnck.Window w) {
            fix_title (w);
            w.name_changed.connect ((win) => fix_title (win));
            w.geometry_changed.connect ((win) => {
                /* Do not interfere during a drag (end_drag fixes it on
                 * release anyway) or while a window is travelling into
                 * its zone — an intermediate frame of the settle is
                 * partly off screen by design. */
                if (button_was_down || animating) {
                    return;
                }
                clamp_to_screen (win);
            });
        }

        private void clamp_to_screen (Wnck.Window w) {
            if (w.is_skip_tasklist () || w.is_minimized ()
                || w.is_maximized () || w.is_fullscreen ()
                || w.get_window_type () == Wnck.WindowType.DESKTOP
                || w.get_window_type () == Wnck.WindowType.DOCK) {
                return;
            }
            int wx, wy, ww, wh;
            w.get_geometry (out wx, out wy, out ww, out wh);
            int cx, cy, cw, ch;
            w.get_client_window_geometry (out cx, out cy, out cw, out ch);
            int title_h = int.max (cy - wy, 24);
            Gdk.Rectangle wa = workarea_at (wx + ww / 2, wy + title_h / 2);
            int nx = wx, ny = wy;
            /* Vertical: the titlebar inside the work area. */
            if (wy < wa.y) {
                ny = wa.y;
            } else if (wy + title_h > wa.y + wa.height) {
                ny = wa.y + wa.height - title_h;
            }
            /* Horizontal: at least KEEP_INSIDE pixels of the window inside. */
            if (wx + ww < wa.x + KEEP_INSIDE) {
                nx = wa.x + KEEP_INSIDE - ww;
            } else if (wx > wa.x + wa.width - KEEP_INSIDE) {
                nx = wa.x + wa.width - KEEP_INSIDE;
            }
            if (nx != wx || ny != wy) {
                set_frame_geometry (w,
                    Wnck.WindowMoveResizeMask.X
                    | Wnck.WindowMoveResizeMask.Y, nx, ny, 0, 0);
            }
        }
    }
}

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);
    /* Palette (B2): component CSS gets the @kavis_* names from here. */
    Kavis.Theme.install ();
    var daemon = new Kavis.SnapDaemon ();
    daemon.ref ();   /* keep alive — the main loop is its only owner */
    Gtk.main ();
    return 0;
}
