/* kavis-snap — drag-to-edge window snapping (madde 6).
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
 * Mechanism: poll the pointer (~80 ms — idle cost is one XQueryPointer
 * round trip). A drag is recognized only when the ACTIVE window's
 * geometry actually moves while button 1 is down — clicking the panel
 * or rubber-banding the desktop can never trigger a snap. Edges give
 * halves, corners give quarters ("hazır düzenler"), the top edge
 * maximizes. A translucent preview shows the target area while a zone
 * is armed (skipped without a compositor, where it would draw as a
 * solid box).
 */

namespace Kavis {

    public class SnapDaemon : Object {

        private const int POLL_MS = 80;
        private const int EDGE = 3;
        private const int CORNER = 180;
        private const int DRAG_MIN = 20;

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
        private Zone zone = Zone.NONE;

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

            Timeout.add (POLL_MS, poll);
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
                return false;
            }
            /* Button1Mask = 1<<8 (X.h) — vapi'de sabit olarak yok. */
            down = (mask & (1 << 8)) != 0;
            return true;
        }

        private bool poll () {
            int x, y;
            bool down;
            if (!pointer_state (out x, out y, out down)) {
                return Source.CONTINUE;
            }

            if (down && !button_was_down) {
                begin_press ();
            }
            if (down && drag_window != null) {
                track_drag (x, y);
            }
            if (!down && button_was_down) {
                end_drag ();
            }
            button_was_down = down;
            return Source.CONTINUE;
        }

        private void begin_press () {
            dragging = false;
            restored_this_drag = false;
            zone = Zone.NONE;
            drag_window = null;
            unowned Wnck.Window? active = screen.get_active_window ();
            if (active == null || active.is_skip_tasklist ()
                || active.is_fullscreen ()) {
                return;
            }
            drag_window = active;
            drag_window.get_geometry (out press_geometry.x,
                                      out press_geometry.y,
                                      out press_geometry.width,
                                      out press_geometry.height);
        }

        private void track_drag (int x, int y) {
            int wx, wy, ww, wh;
            drag_window.get_geometry (out wx, out wy, out ww, out wh);
            if (!dragging) {
                /* Sürükleme = pencere gerçekten yer değiştirdi. Panel
                 * tıklaması / masaüstünde seçim asla tetiklemez. */
                if ((wx - press_geometry.x).abs () < DRAG_MIN
                    && (wy - press_geometry.y).abs () < DRAG_MIN) {
                    return;
                }
                dragging = true;
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

            zone = zone_at (x, y);
            update_preview (x, y);
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
            preview.hide ();
            if (dragging && zone != Zone.NONE && drag_window != null) {
                apply_zone ();
            }
            drag_window = null;
            dragging = false;
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
