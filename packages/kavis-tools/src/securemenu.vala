/* Ctrl+Alt+Del screen (sonraki-isler 6d) —
 * `kavis-tools secure-menu`.
 *
 * Fullscreen dark layer, a centered list of big actions, a power
 * button at the bottom right. Runs OUT of the panel process on
 * purpose: the frozen-app scenario must work even when the panel is
 * dead. Always on top: override-redirect POPUP + seat grab. Esc
 * closes. "Switch user" stays hidden until the multi-user system
 * lands (spec).
 */

namespace Kavis.Tools {

    public class SecureMenuWindow : Gtk.Window {

        private const string CSS = """
        .kavis-secure.backdrop-layer {
          background-color: rgba(13, 20, 27, 0.92);
        }
        .kavis-secure label {
          color: #E6EDF3;
        }
        .kavis-secure button {
          background-image: none;
          background-color: transparent;
          border: none;
          border-radius: 8px;
          color: #E6EDF3;
          padding: 14px 28px;
          font-size: 18px;
          transition: background-color 140ms ease;
        }
        .kavis-secure button:hover {
          background-color: rgba(255, 255, 255, 0.09);
        }
        .kavis-secure button:active {
          background-color: rgba(255, 255, 255, 0.14);
        }
        """;

        public SecureMenuWindow () {
            Object (type: Gtk.WindowType.POPUP);
            set_type_hint (Gdk.WindowTypeHint.SPLASHSCREEN);
            set_keep_above (true);

            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) { }

            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor ()
                ?? display.get_monitor (0);
            Gdk.Rectangle area = monitor.get_geometry ();
            set_default_size (area.width, area.height);
            move (area.x, area.y);

            /* Karartma zemini ana çocukta; overlay ÇOCUKLARI o
             * kutunun altından inmediği için düğme kuralları sınıfı
             * ayrıca alır (Xvfb'de görüldü). */
            var overlay = new Gtk.Overlay ();
            var backdrop = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            backdrop.get_style_context ().add_class ("kavis-secure");
            backdrop.get_style_context ().add_class ("backdrop-layer");
            overlay.add (backdrop);
            add (overlay);

            /* Ortada dikey liste. */
            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            column.get_style_context ().add_class ("kavis-secure");
            column.set_halign (Gtk.Align.CENTER);
            column.set_valign (Gtk.Align.CENTER);
            column.pack_start (action_button (
                "system-lock-screen-symbolic", _("Lock"), () => {
                    Power.lock ();
                }), false, false, 0);
            column.pack_start (action_button (
                "system-log-out-symbolic", _("Sign out"), () => {
                    Power.log_out ();
                }), false, false, 0);
            /* "Kullanıcı değiştir": çoklu kullanıcı sistemi (2.0)
             * gelene kadar çizilmiyor. */
            column.pack_start (action_button (
                "utilities-system-monitor-symbolic", _("Task Manager"),
                () => {
                    try {
                        Process.spawn_async (null,
                            { "kavis-tools", "tasks" }, null,
                            SpawnFlags.SEARCH_PATH, null, null);
                    } catch (Error e) { }
                }), false, false, 0);
            overlay.add_overlay (column);

            /* Sağ altta güç düğmesi. */
            var power_button = new Gtk.Button.from_icon_name (
                "system-shutdown-symbolic", Gtk.IconSize.DIALOG);
            power_button.set_relief (Gtk.ReliefStyle.NONE);
            power_button.get_style_context ().add_class ("kavis-secure");
            power_button.set_halign (Gtk.Align.END);
            power_button.set_valign (Gtk.Align.END);
            power_button.set_margin_end (32);
            power_button.set_margin_bottom (32);
            power_button.clicked.connect (() => {
                var menu = new Gtk.Menu ();
                append_power (menu, _("Sleep"), () => Power.suspend ());
                append_power (menu, _("Shut down"),
                              () => Power.shutdown ());
                append_power (menu, _("Restart"), () => Power.reboot ());
                menu.show_all ();
                menu.popup_at_widget (power_button,
                    Gdk.Gravity.NORTH_EAST, Gdk.Gravity.SOUTH_EAST,
                    null);
            });
            overlay.add_overlay (power_button);

            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    close_menu ();
                    return true;
                }
                return false;
            });
            /* Boş alana tıklamak da kapatır (W11 davranışı). */
            button_press_event.connect (() => {
                close_menu ();
                return true;
            });

            map_event.connect (() => {
                grab_input ();
                return false;
            });
        }

        private delegate void ActionFunc ();

        private Gtk.Button action_button (string icon_name, string text,
                                          owned ActionFunc action) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 14);
            row.pack_start (new Gtk.Image.from_icon_name (
                icon_name, Gtk.IconSize.DIALOG), false, false, 0);
            var label = new Gtk.Label (null);
            label.set_markup ("<span size='x-large'>%s</span>".printf (
                Markup.escape_text (text)));
            label.set_xalign (0);
            row.pack_start (label, true, true, 0);
            row.set_size_request (320, -1);
            button.add (row);
            button.clicked.connect (() => {
                action ();
                close_menu ();
            });
            return button;
        }

        private delegate void PowerFunc ();

        private void append_power (Gtk.Menu menu, string text,
                                   owned PowerFunc action) {
            var item = new Gtk.MenuItem.with_label (text);
            item.activate.connect (() => {
                action ();
                close_menu ();
            });
            menu.append (item);
        }

        private void grab_input () {
            var seat = Gdk.Display.get_default ().get_default_seat ();
            uint tries = 0;
            if (seat.grab (get_window (), Gdk.SeatCapabilities.ALL,
                           true, null, null, null)
                == Gdk.GrabStatus.SUCCESS) {
                return;
            }
            Timeout.add (50, () => {
                tries++;
                if (!get_visible ()) {
                    return Source.REMOVE;
                }
                return seat.grab (get_window (),
                                  Gdk.SeatCapabilities.ALL,
                                  true, null, null, null)
                    != Gdk.GrabStatus.SUCCESS && tries < 10;
            });
        }

        private void close_menu () {
            Gdk.Display.get_default ().get_default_seat ().ungrab ();
            destroy ();
        }
    }
}
