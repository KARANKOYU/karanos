/* Power popup (UI layer) — opens above the start menu's power button.
 *
 * Windows 11 style: a small rounded, softly shadowed box with icon
 * rows. Hovering highlights a row; clicking outside closes it.
 *
 * Texts come from po/ (gettext) panel.* keys.
 */

namespace Kavis.Ui {

    public class PowerMenu : Gtk.Window {

        /* Transparent margin so the shadow fits inside the window.
         * Without a compositor that margin is painted BLACK, not
         * transparent, and the box grows an ugly black frame (seen in
         * Xvfb) — so the margin exists only while compositing works. */
        private const int MARGIN_SHADOW = 10;
        private const int MARGIN_PLAIN = 0;

        private const string CSS = """
        /* Kutunun kendisi: yüzey rengi, yuvarlatılmış köşe, ince
           kenarlık ve yumuşak gölge. Gölge iç kutuda; pencere şeffaf
           kalıyor ki gölge kırpılmasın. */
        .kavis-power-menu {
          background-color: @kavis_surface;
          border: 1px solid @kavis_border;
          border-radius: 10px;
          box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
        }
        /* Kompozitör yokken: gölge ve yuvarlak köşe yerine sade kenarlık. */
        .kavis-power-menu.plain {
          border-radius: 0;
          box-shadow: none;
        }
        .kavis-power-menu button {
          background-image: none;
          background-color: transparent;
          border: none;
          border-radius: 6px;
          color: @kavis_text;
          padding: 9px 12px;
        }
        .kavis-power-menu button:hover {
          background-color: @kavis_hover;
        }
        .kavis-power-menu button:active {
          background-color: @kavis_border;
        }
        """;

        /* Fired on every dismiss; the start menu re-takes the seat
         * grab from this if it is still open (madde 60). */
        public signal void closed ();

        private Gtk.Box box;
        private bool composited;
        private new int margin;
        private bool gtk_grabbed = false;

        public PowerMenu () {
            Object (type: Gtk.WindowType.POPUP);
            set_type_hint (Gdk.WindowTypeHint.POPUP_MENU);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_app_paintable (true);

            /* Rounded corners and the shadow only render under a
             * compositor. picom starts from autostart; if it is gone
             * (rescue mode, crash) the box degrades to a plain
             * rectangle instead of showing black margins. */
            var screen = get_screen ();
            var visual = screen.get_rgba_visual ();
            composited = (visual != null && screen.is_composited ());
            if (composited) {
                set_visual (visual);
            }
            margin = composited ? MARGIN_SHADOW : MARGIN_PLAIN;

            load_css ();
            build ();

            button_press_event.connect (on_outside_click);
            key_press_event.connect (on_key_press);
        }

        private void load_css () {
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-panel: guc menusu CSS yuklenemedi: %s",
                         e.message);
            }
        }

        private void build () {
            /* Outer box stays transparent, the shadow lives on the
             * inner box — so the shadow is not clipped at the window
             * edge. */
            var outer = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            outer.set_border_width (margin);
            add (outer);

            box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            box.get_style_context ().add_class ("kavis-power-menu");
            if (!composited) {
                box.get_style_context ().add_class ("plain");
            }
            box.set_border_width (6);
            outer.pack_start (box, true, true, 0);

            /* Row order as requested: Kilitle, Uyku, Kapat, Yeniden
             * başlat. */
            box.pack_start (row (N_("Lock"),
                "system-lock-screen-symbolic", Power.lock), false, false, 0);
            box.pack_start (row (N_("Sleep"),
                "weather-clear-night-symbolic", Power.suspend), false, false, 0);
            box.pack_start (row (N_("Shut down"),
                "system-shutdown-symbolic", Power.shutdown), false, false, 0);
            box.pack_start (row (N_("Restart"),
                "system-reboot-symbolic", Power.reboot), false, false, 0);
        }

        private delegate void Action ();

        private Gtk.Button row (string key, string icon_name, Action action) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            var inner = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            inner.pack_start (new Gtk.Image.from_icon_name (
                icon_name, Gtk.IconSize.LARGE_TOOLBAR), false, false, 0);
            var label = new Gtk.Label (_(key));
            label.set_xalign (0);
            inner.pack_start (label, true, true, 0);
            button.add (inner);
            button.clicked.connect (() => {
                dismiss ();
                action ();
            });
            return button;
        }

        /* Open ABOVE the given point (x, y = top-left of the power
         * button). */
        public void open (int x, int y) {
            show_all ();
            Gtk.Requisition natural;
            get_preferred_size (null, out natural);
            move (x - margin, y - natural.height + margin);

            /* GTK grab stacks ON TOP of the start menu's: a click on
             * the start menu (the power button included) lands here,
             * reads as outside and closes this popup — that is the
             * madde 60B toggle: the press is consumed, so the button
             * does not immediately re-open what it just closed. */
            Gtk.grab_add (this);
            gtk_grabbed = true;
            PanelPopup.seat_grab (this);
        }

        public void dismiss () {
            if (gtk_grabbed) {
                Gtk.grab_remove (this);
                gtk_grabbed = false;
            }
            PanelPopup.seat_ungrab ();
            hide ();
            closed ();
        }

        private bool on_outside_click (Gdk.EventButton event) {
            if (PanelPopup.press_outside (this, event)) {
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
