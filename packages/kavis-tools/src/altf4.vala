/* Alt+F4 on the desktop (sonraki-isler 6e) —
 * `kavis-tools alt-f4`.
 *
 * Openbox's Alt+F4 close needs a focused client; on the bare desktop
 * it does nothing. Our binding routes Alt+F4 here instead: if a real
 * window has focus it is closed (same WM_DELETE path), otherwise the
 * Windows-style shutdown dialog appears — a combo of power actions
 * plus OK/Cancel, unchanged since XP on purpose.
 */

namespace Kavis.Tools {

    namespace AltF4 {

        /* true → pencere kapatıldı, diyaloğa gerek yok. */
        public bool close_focused_window () {
            var screen = Wnck.Screen.get_default ();
            screen.force_update ();
            unowned Wnck.Window? active = screen.get_active_window ();
            if (active == null
                || active.get_window_type () == Wnck.WindowType.DESKTOP
                || active.get_window_type () == Wnck.WindowType.DOCK) {
                return false;
            }
            active.close (Gtk.get_current_event_time ());
            return true;
        }
    }

    public class ShutdownDialog : Gtk.Window {

        public ShutdownDialog () {
            set_title (_("Shut down"));
            set_resizable (false);
            set_position (Gtk.WindowPosition.CENTER);
            set_keep_above (true);

            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            column.set_border_width (16);
            add (column);

            var combo = new Gtk.ComboBoxText ();
            combo.append ("shutdown", _("Shut down"));
            combo.append ("restart", _("Restart"));
            combo.append ("sleep", _("Sleep"));
            combo.append ("logout", _("Sign out"));
            combo.set_active_id ("shutdown");
            column.pack_start (combo, false, false, 0);

            var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            buttons.set_halign (Gtk.Align.END);
            var cancel = new Gtk.Button.with_label (_("Cancel"));
            cancel.clicked.connect (() => destroy ());
            buttons.pack_start (cancel, false, false, 0);
            var ok = new Gtk.Button.with_label (_("OK"));
            ok.get_style_context ().add_class ("suggested-action");
            ok.clicked.connect (() => {
                switch (combo.get_active_id ()) {
                case "restart":
                    Power.reboot ();
                    break;
                case "sleep":
                    Power.suspend ();
                    break;
                case "logout":
                    Power.log_out ();
                    break;
                default:
                    Power.shutdown ();
                    break;
                }
                destroy ();
            });
            buttons.pack_start (ok, false, false, 0);
            column.pack_start (buttons, false, false, 0);

            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    destroy ();
                    return true;
                }
                return false;
            });
        }
    }
}
