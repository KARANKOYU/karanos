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
 */

namespace Kavis {

    public class SnapDaemon : Object {

        private const int POLL_IDLE_MS = 80;
        private const int POLL_DRAG_MS = 16;
        private const int EDGE = 3;
        private const int CORNER = 180;
        private const int DRAG_MIN = 8;
        /* C2: bu kadar piksel içeride kalmalı (yatay), başlık tamamen
         * dikeyde. */
        private const int KEEP_INSIDE = 80;

        private enum Zone { NONE, LEFT, RIGHT, TOP, TL, TR, BL, BR }

        private unowned Wnck.Screen screen;
        private Gtk.Window preview;
        private bool composited;

        /* xid → pre-snap outer geometry, for unsnap. */
        private HashTable<ulong, Gdk.Rectangle?> saved =
            new HashTable<ulong, Gdk.Rectangle?> (direct_hash, direct_equal);

        private bool button_was_down = false;
        private bool dragging = false;
        private bool restored_this_drag = false;
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
        /* İlk yerleştirmeden sonra ölçülen sapma: wnck'nin okuduğu
         * çerçeve konumu ile set_geometry'nin kullandığı gravity
         * koordinatı openbox'ta her zaman aynı değil (Xvfb testinde
         * dikeyde başlık yüksekliği kadar fark çıktı) — bir kez ölçüp
         * sonraki her adımda düzeltiyoruz. */
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

            /* C2: her pencerenin geometri değişimini izle (klavye,
             * uygulamanın kendi taşıması). Var olanlar + sonrakiler. */
            foreach (unowned Wnck.Window w in screen.get_windows ()) {
                watch_window (w);
            }
            screen.window_opened.connect ((w) => watch_window (w));

            Timeout.add (POLL_IDLE_MS, poll);
            dbg ("basladi composited=%s pencere=%u", composited.to_string (),
                 screen.get_windows ().length ());
        }

        private void load_css () {
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data ("""
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
                warning ("kavis-snap: CSS yuklenemedi: %s", e.message);
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
                dbg ("query_pointer basarisiz");
                return false;
            }
            /* Button1Mask = 1<<8 (X.h) — vapi'de sabit olarak yok. */
            down = (mask & (1 << 8)) != 0;
            return true;
        }

        /* Değişken hızlı yoklama: düğme bir pencerenin üstünde
         * basılıyken 16 ms, boşta 80 ms. */
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
                return false;   /* pencere kapandı / geçersiz */
            }
            fx = rx; fy = ry;
            fw = attrs.width; fh = attrs.height;
            return true;
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
                    hit = w;   /* liste alttan üste: sonuncu en üstte */
                }
            }
            return hit;
        }

        private void begin_press (int x, int y) {
            dragging = false;
            restored_this_drag = false;
            taking_over = false;
            takeover_placed = false;
            zone = Zone.NONE;
            drag_window = window_at (x, y);
            dbg ("basis %d,%d pencere=%s", x, y,
                 drag_window == null ? "(yok)" : drag_window.get_name ());
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
                /* Basış başlıkta mı? (çerçeve üstü ile istemci üstü
                 * arası). İçerik alanındaki basış sürükleme değildir. */
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

            /* C3: büyütülmüş pencere — openbox bu durumda hiçbir şey
             * yapmıyor (rc.xml If kuralı); işaretçi eşiği geçince
             * sürüklemeyi biz üstleniriz. */
            if (press_was_maximized && !taking_over) {
                if ((x - press_x).abs () < DRAG_MIN
                    && (y - press_y).abs () < DRAG_MIN) {
                    return;
                }
                taking_over = true;
                dragging = true;
                drag_window.unmaximize ();
                return;   /* geometri bir sonraki yoklamada gelir */
            }
            if (taking_over) {
                follow_pointer (x, y, wx, wy, ww, wh);
                zone = zone_at (x, y);
                update_preview (x, y);
                return;
            }

            if (!dragging) {
                /* Sürükleme = pencere gerçekten yer değiştirdi. Panel
                 * tıklaması / masaüstünde seçim asla tetiklemez. */
                if ((wx - press_geometry.x).abs () < DRAG_MIN
                    && (wy - press_geometry.y).abs () < DRAG_MIN) {
                    return;
                }
                dragging = true;
                dbg ("surukleme basladi cerceve %d,%d (basista %d,%d)",
                     wx, wy, press_geometry.x, press_geometry.y);
            }

            /* Unsnap: bizim yapıştırdığımız pencere çekilip
             * götürülüyorsa eski boyutunu hemen geri ver (W11
             * davranışı). */
            if (!restored_this_drag) {
                restored_this_drag = true;
                ulong xid = drag_window.get_xid ();
                Gdk.Rectangle? old = saved.lookup (xid);
                if (old != null) {
                    saved.remove (xid);
                    drag_window.set_geometry (Wnck.WindowGravity.NORTHWEST,
                        Wnck.WindowMoveResizeMask.WIDTH
                        | Wnck.WindowMoveResizeMask.HEIGHT,
                        0, 0, old.width, old.height);
                    /* Yapışıkken tekrar yapıştırılırsa 'eski boyut'
                     * yarım-ekran değil GERÇEK eski boyut kalsın:
                     * basıştaki geometri artık geri verilen boyut. */
                    press_geometry.width = old.width;
                    press_geometry.height = old.height;
                }
            }

            Zone before = zone;
            zone = zone_at (x, y);
            if (zone != before) {
                dbg ("bolge %d -> %d isaretci %d,%d", (int) before, (int) zone, x, y);
            }
            update_preview (x, y);
        }

        /* C3: geri yüklenmiş pencereyi işaretçinin altına, başlıkta aynı
         * oransal noktaya koy ve izle. Geometri henüz büyük (unmaximize
         * işlenmemiş) ise bekle. */
        private void follow_pointer (int x, int y, int wx, int wy,
                                     int ww, int wh) {
            if (!takeover_placed) {
                if (ww >= press_geometry.width - 2
                    && wh >= press_geometry.height - 2) {
                    return;   /* hâlâ büyütülmüş boyutta */
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
            drag_window.set_geometry (Wnck.WindowGravity.NORTHWEST,
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
            default:   /* TOP: tam çalışma alanı (büyütme önizlemesi) */
                r = wa;
                break;
            }
            return r;
        }

        private void update_preview (int x, int y) {
            if (!composited) {
                return;   /* kompozitörsüz önizleme opak kutu çizer */
            }
            if (zone == Zone.NONE) {
                preview.hide ();
                return;
            }
            Gdk.Rectangle r = zone_rect (zone, workarea_at (x, y));
            preview.set_size_request (r.width, r.height);
            preview.resize (r.width, r.height);
            preview.move (r.x, r.y);
            preview.show_all ();
        }

        private void end_drag () {
            dbg ("birakildi dragging=%s bolge=%d pencere=%s",
                 dragging.to_string (), (int) zone,
                 drag_window == null ? "(yok)" : drag_window.get_name ());
            preview.hide ();
            if (dragging && drag_window != null) {
                if (zone != Zone.NONE) {
                    apply_zone ();
                } else {
                    clamp_to_screen (drag_window);
                }
            }
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
                /* Yapıştırma öncesi boyut: sürükleme başındaki. */
                saved.insert (xid, press_geometry);
            }

            if (zone == Zone.TOP) {
                drag_window.maximize ();
                return;
            }
            Gdk.Rectangle r = zone_rect (zone, wa);
            drag_window.unmaximize ();
            drag_window.set_geometry (Wnck.WindowGravity.NORTHWEST,
                Wnck.WindowMoveResizeMask.X | Wnck.WindowMoveResizeMask.Y
                | Wnck.WindowMoveResizeMask.WIDTH
                | Wnck.WindowMoveResizeMask.HEIGHT,
                r.x, r.y, r.width, r.height);
        }

        /* --- C2: başlık çubuğu ekranda kalır ------------------------- */

        private void watch_window (Wnck.Window w) {
            w.geometry_changed.connect ((win) => {
                /* Sürükleme sırasında karışma; bırakınca end_drag
                 * zaten düzeltir. */
                if (button_was_down) {
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
            /* Dikey: başlık çalışma alanının içinde. */
            if (wy < wa.y) {
                ny = wa.y;
            } else if (wy + title_h > wa.y + wa.height) {
                ny = wa.y + wa.height - title_h;
            }
            /* Yatay: pencerenin en az KEEP_INSIDE pikseli içeride. */
            if (wx + ww < wa.x + KEEP_INSIDE) {
                nx = wa.x + KEEP_INSIDE - ww;
            } else if (wx > wa.x + wa.width - KEEP_INSIDE) {
                nx = wa.x + wa.width - KEEP_INSIDE;
            }
            if (nx != wx || ny != wy) {
                w.set_geometry (Wnck.WindowGravity.NORTHWEST,
                    Wnck.WindowMoveResizeMask.X
                    | Wnck.WindowMoveResizeMask.Y, nx, ny, 0, 0);
            }
        }
    }
}

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);
    /* Palet (B2): bileşen CSS'leri @kavis_* adlarını buradan alır. */
    Kavis.Theme.install ();
    var daemon = new Kavis.SnapDaemon ();
    daemon.ref ();   /* yaşasın — tek sahibi main döngüsü */
    Gtk.main ();
    return 0;
}
