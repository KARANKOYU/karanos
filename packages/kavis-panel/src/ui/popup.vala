/* Shared base for the indicator popups (UI layer) — stage 4.
 *
 * Windows 11 style: a small rounded box that opens ABOVE the panel,
 * horizontally aligned with the indicator that was clicked. Behavior
 * shared by every popup: clicking the same indicator again toggles it
 * closed, clicking outside closes, Escape closes, and at most one
 * popup is open at a time. Open/close animation comes from picom's
 * global window animations (150 ms appear/disappear) — the popup is a
 * real X window, so it needs no animation code of its own.
 *
 * The compositor fallback mirrors power_menu.vala: without picom the
 * transparent shadow margin would render black, so the box degrades to
 * a plain rectangle.
 */

namespace Kavis.Ui {

    public abstract class PanelPopup : Gtk.Window {

        private const int MARGIN_SHADOW = 10;
        private const int MARGIN_PLAIN = 0;
        /* Visual gap between the popup box and the panel edge (Grup D
         * fix: 8 px, W11 spacing). */
        private const int GAP = 8;

        private const string CSS = """
        .kavis-popup {
          background-color: #17222C;
          border: 1px solid #233A45;
          border-radius: 10px;
          box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
        }
        .kavis-popup.plain {
          border-radius: 0;
          box-shadow: none;
        }
        .kavis-popup label {
          color: #E6EDF3;
        }
        .kavis-popup label.dim {
          color: #8B9BA8;
        }
        .kavis-popup button {
          background-image: none;
          background-color: transparent;
          border: none;
          border-radius: 6px;
          color: #E6EDF3;
          padding: 8px 10px;
          transition: background-color 180ms ease;
        }
        .kavis-popup button:hover {
          background-color: #1D2C38;
        }
        .kavis-popup button:active {
          background-color: #233A45;
        }
        /* Takvim (saat popup'ı): koyu zemin, bugünün günü turkuaz. */
        .kavis-popup calendar {
          background-color: #17222C;
          color: #E6EDF3;
          border: none;
          padding: 4px;
        }
        .kavis-popup calendar:selected {
          background-color: #2DD4BF;
          color: #0D141B;
          border-radius: 6px;
        }
        .kavis-popup calendar:indeterminate {
          color: #4A5A66;
        }
        /* Hızlı ayar kutucukları (madde 37): açıkken turkuaz vurgulu. */
        .kavis-popup button.quick-tile {
          padding: 8px 4px;
          border-radius: 8px;
        }
        .kavis-popup button.quick-tile.on {
          background-color: rgba(45, 212, 191, 0.16);
          color: #2DD4BF;
        }
        .kavis-popup button.quick-tile.on:hover {
          background-color: rgba(45, 212, 191, 0.24);
        }
        """;

        /* Panelin konumu (madde 5): popup panelin karşı yanına açılır —
         * alttaysa üstüne, üstteyse altına, soldaysa sağına... Panel
         * kurulurken bir kez yazar. */
        public static PanelConfig.Position panel_position =
            PanelConfig.Position.BOTTOM;

        /* At most one popup open — opening any dismisses the other. */
        private static unowned PanelPopup? open_popup = null;
        /* Refit () needs the anchor after the open (collapse/expand
         * while visible). Unowned: an indicator outlives its popup. */
        private unowned Gtk.Widget? anchor_widget = null;
        /* The start menu takes part in the same exclusivity: opening a
         * popup closes it and vice versa (Panel sets this once). */
        public static unowned StartMenu? start_menu = null;
        private static bool css_loaded = false;

        protected Gtk.Box content;
        /* W11 davranışı (Grup D): bildirim merkezi ve hızlı ayarlar
         * göstergeye değil monitörün sağ kenarına hizalanır. Yatay
         * panelde geçerli; dikey panelde göstergeye hizalı kalır. */
        protected bool edge_aligned = false;
        private bool composited;
        private int shadow_margin;
        private bool gtk_grabbed = false;

        protected PanelPopup () {
            Object (type: Gtk.WindowType.POPUP);
            set_type_hint (Gdk.WindowTypeHint.POPUP_MENU);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_app_paintable (true);

            var screen = get_screen ();
            var visual = screen.get_rgba_visual ();
            composited = (visual != null && screen.is_composited ());
            if (composited) {
                set_visual (visual);
            }
            shadow_margin = composited ? MARGIN_SHADOW : MARGIN_PLAIN;

            load_css ();

            var outer = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            outer.set_border_width (shadow_margin);
            add (outer);

            content = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            content.get_style_context ().add_class ("kavis-popup");
            if (!composited) {
                content.get_style_context ().add_class ("plain");
            }
            content.set_border_width (12);
            outer.pack_start (content, true, true, 0);

            button_press_event.connect (on_outside_click);
            key_press_event.connect (on_key_press);
        }

        private static void load_css () {
            if (css_loaded) {
                return;
            }
            css_loaded = true;
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-panel: popup CSS yuklenemedi: %s", e.message);
            }
        }

        /* Called every time the popup is about to open, so contents
         * show current values (battery %, volume, today's date). */
        protected virtual void refresh_content () {
        }

        /* True when the press landed outside win's frame (madde 60).
         * Uses ROOT coordinates: with an owner-events grab, an event
         * bubbling up from a child widget that has its own GdkWindow
         * (calendar cells, scrolled viewports) carries coordinates
         * relative to the CHILD's window, so event.x/y cannot be
         * compared against the toplevel — a click on a calendar cell
         * looked "outside" and wrongly closed the popup. */
        public static bool press_outside (Gtk.Window win,
                                          Gdk.EventButton event) {
            var gdk_window = win.get_window ();
            if (gdk_window == null) {
                return false;
            }
            int origin_x, origin_y;
            gdk_window.get_origin (out origin_x, out origin_y);
            return !(origin_x <= event.x_root
                     && event.x_root < origin_x + win.get_allocated_width ()
                     && origin_y <= event.y_root
                     && event.y_root < origin_y + win.get_allocated_height ());
        }

        /* Grab pointer + keyboard for win (madde 60C). POPUP windows
         * are mapped asynchronously; a grab issued right after
         * show_all() can fail with NOT_VIEWABLE and then clicks
         * outside the application never reach the window at all — it
         * silently refuses to close. Retry briefly until the X server
         * has mapped the window. */
        public static void seat_grab (Gtk.Window win) {
            if (try_seat_grab (win)) {
                return;
            }
            uint tries = 0;
            GLib.Timeout.add (50, () => {
                tries++;
                if (!win.get_visible ()) {
                    return false;
                }
                return !try_seat_grab (win) && tries < 10;
            });
        }

        private static bool try_seat_grab (Gtk.Window win) {
            var window = win.get_window ();
            if (window == null) {
                return false;
            }
            var seat = Gdk.Display.get_default ().get_default_seat ();
            return seat.grab (window, Gdk.SeatCapabilities.ALL, true,
                              null, null, null) == Gdk.GrabStatus.SUCCESS;
        }

        public static void seat_ungrab () {
            var display = Gdk.Display.get_default ();
            if (display != null) {
                display.get_default_seat ().ungrab ();
            }
        }

        /* Toggle from the indicator that anchors this popup: open above
         * the panel centered on the indicator, or close if already
         * open. Clamped to the monitor's edges. */
        public void toggle_at (Gtk.Widget anchor) {
            if (get_visible ()) {
                dismiss ();
                return;
            }
            if (open_popup != null && open_popup != this) {
                open_popup.dismiss ();
            }
            if (start_menu != null && start_menu.get_visible ()) {
                start_menu.dismiss ();
            }

            anchor_widget = anchor;
            refresh_content ();
            show_all ();
            refit ();

            /* GTK-level grab (madde 60): events on OTHER widgets of
             * this application (the panel, the start menu) are
             * redirected here instead of reaching them, so a click
             * anywhere else in the app closes the popup — and the
             * widget under it does NOT also act on the press, which
             * would instantly re-open what we just closed. Events on
             * our own children still flow normally. */
            Gtk.grab_add (this);
            gtk_grabbed = true;
            seat_grab (this);
            open_popup = this;
        }

        /* Size the window to its CURRENT natural size and re-place it
         * against the anchor. A popup window never shrinks by itself:
         * without the explicit resize a reopened (or collapsed) popup
         * keeps its old height and drifts over the panel (Grup D VM
         * finding). Also called by subclasses whose content grows or
         * shrinks while open (calendar collapse, history rebuild). */
        protected void refit () {
            if (anchor_widget == null) {
                return;
            }
            Gtk.Requisition natural;
            get_preferred_size (null, out natural);
            resize (int.max (1, natural.width),
                    int.max (1, natural.height));

            unowned Gtk.Widget anchor = anchor_widget;
            var anchor_window = anchor.get_window ();
            if (anchor_window == null) {
                hide ();
                return;
            }
            int origin_x, origin_y;
            anchor_window.get_origin (out origin_x, out origin_y);
            Gtk.Allocation alloc;
            anchor.get_allocation (out alloc);
            /* get_origin already includes the allocation for widgets
             * with their own GdkWindow (buttons); for the others add
             * the allocation offset. */
            if (!anchor.get_has_window ()) {
                origin_x += alloc.x;
                origin_y += alloc.y;
            }

            var display = Gdk.Display.get_default ();
            var monitor = display.get_monitor_at_window (anchor_window);
            Gdk.Rectangle area = monitor.get_geometry ();
            int box_width = natural.width - 2 * shadow_margin;
            int box_height = natural.height - 2 * shadow_margin;
            int x, y;

            switch (panel_position) {
            case PanelConfig.Position.TOP:
                /* Altına, göstergeye yatay ortalı. */
                x = origin_x + alloc.width / 2 - box_width / 2
                    - shadow_margin;
                y = origin_y + alloc.height + GAP - shadow_margin;
                break;
            case PanelConfig.Position.LEFT:
                /* Sağına, göstergeye dikey ortalı. */
                x = origin_x + alloc.width + GAP - shadow_margin;
                y = origin_y + alloc.height / 2 - box_height / 2
                    - shadow_margin;
                break;
            case PanelConfig.Position.RIGHT:
                x = origin_x - GAP - natural.width + shadow_margin;
                y = origin_y + alloc.height / 2 - box_height / 2
                    - shadow_margin;
                break;
            default:   /* BOTTOM: üstüne, yatay ortalı (ilk davranış). */
                x = origin_x + alloc.width / 2 - box_width / 2
                    - shadow_margin;
                y = origin_y - GAP - natural.height + shadow_margin;
                break;
            }

            if (edge_aligned
                && (panel_position == PanelConfig.Position.BOTTOM
                    || panel_position == PanelConfig.Position.TOP)) {
                x = area.x + area.width - box_width - GAP - shadow_margin;
            }

            /* Monitör içine kıstır. */
            x = int.max (area.x + GAP - shadow_margin,
                         int.min (x, area.x + area.width - box_width
                                  - GAP - shadow_margin));
            y = int.max (area.y + GAP - shadow_margin,
                         int.min (y, area.y + area.height - box_height
                                  - GAP - shadow_margin));

            move (x, y);
        }

        /* Whether any indicator popup is currently open (auto-hide
         * keeps the panel visible while one is). */
        public static bool any_open () {
            return open_popup != null;
        }

        /* Close whichever popup is open (the start menu calls this when
         * it opens — same exclusivity, opposite direction). */
        public static void dismiss_open () {
            if (open_popup != null) {
                open_popup.dismiss ();
            }
        }

        public void dismiss () {
            if (gtk_grabbed) {
                Gtk.grab_remove (this);
                gtk_grabbed = false;
            }
            seat_ungrab ();
            hide ();
            if (open_popup == this) {
                open_popup = null;
            }
        }

        private bool on_outside_click (Gdk.EventButton event) {
            /* Rule (madde 60): every press inside the window area
             * counts as inside — buttons, labels, empty space, all of
             * it. Only a press outside the frame closes. */
            if (press_outside (this, event)) {
                dismiss ();
                return true;
            }
            return false;
        }

        private bool on_key_press (Gdk.EventKey event) {
            if (event.keyval == Gdk.Key.Escape) {
                dismiss ();
                return true;
            }
            return false;
        }
    }
}
