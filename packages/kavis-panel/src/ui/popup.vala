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
        /* Visual gap between the popup box and the panel edge. */
        private const int GAP = 6;

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
        """;

        /* At most one popup open — opening any dismisses the other. */
        private static unowned PanelPopup? open_popup = null;
        /* The start menu takes part in the same exclusivity: opening a
         * popup closes it and vice versa (Panel sets this once). */
        public static unowned StartMenu? start_menu = null;
        private static bool css_loaded = false;

        protected Gtk.Box content;
        private bool composited;
        private int shadow_margin;

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

            refresh_content ();
            show_all ();

            Gtk.Requisition natural;
            get_preferred_size (null, out natural);

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

            /* Center on the anchor, clamp into the monitor. */
            int box_width = natural.width - 2 * shadow_margin;
            int x = origin_x + alloc.width / 2 - box_width / 2 - shadow_margin;
            var display = Gdk.Display.get_default ();
            var monitor = display.get_monitor_at_window (anchor_window);
            Gdk.Rectangle area = monitor.get_geometry ();
            x = int.max (area.x + GAP - shadow_margin,
                         int.min (x, area.x + area.width - box_width
                                  - GAP - shadow_margin));
            /* Bottom of the visible box sits GAP above the panel's
             * top edge (origin_y = top of the panel window). */
            int y = origin_y - GAP - natural.height + shadow_margin;

            move (x, y);

            var window = get_window ();
            if (window != null) {
                var seat = display.get_default_seat ();
                seat.grab (window, Gdk.SeatCapabilities.ALL, true,
                           null, null, null);
            }
            open_popup = this;
        }

        /* Close whichever popup is open (the start menu calls this when
         * it opens — same exclusivity, opposite direction). */
        public static void dismiss_open () {
            if (open_popup != null) {
                open_popup.dismiss ();
            }
        }

        public void dismiss () {
            var display = Gdk.Display.get_default ();
            if (display != null) {
                display.get_default_seat ().ungrab ();
            }
            hide ();
            if (open_popup == this) {
                open_popup = null;
            }
        }

        private bool on_outside_click (Gdk.EventButton event) {
            Gtk.Allocation alloc;
            content.get_allocation (out alloc);
            bool inside = alloc.x <= event.x
                && event.x <= alloc.x + alloc.width
                && alloc.y <= event.y
                && event.y <= alloc.y + alloc.height;
            if (!inside) {
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
