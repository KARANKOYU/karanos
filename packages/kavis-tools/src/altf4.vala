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

        /* true → a window was closed, no dialog needed. */
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

    /* Power dialog (2D): the Kavis design-language version — no title
     * bar, centered, 12px corners on @kavis_surface, four big icon buttons
     * side by side (Sleep / Restart / Shut down / Cancel). Escape
     * closes; the 180 ms open animation is picom's appear preset.
     * SHARED component: Alt+F4 (desktop) and the Ctrl+Alt+Del screen's
     * power button both open exactly this window (no second code).
     * An app_paintable window does NOT draw its own CSS background
     * (known pitfall) — the class goes on the INNER box. */
    public class ShutdownDialog : Gtk.Window {

        private const string CSS = """
        .kavis-power-dialog {
            background-color: @kavis_surface;
            border: 1px solid @kavis_border;
            border-radius: 12px;
            padding: 16px;
        }
        .kavis-power-dialog label { color: @kavis_text; }
        .kavis-power-dialog button {
            background-image: none;
            background-color: transparent;
            border: none;
            border-radius: 6px;
            box-shadow: none;
            color: @kavis_text;
            padding: 12px;
            transition: background-color 120ms cubic-bezier(0.2, 0.9, 0.25, 1);
        }
        .kavis-power-dialog button:hover {
            background-color: @kavis_overlay_hover;
        }
        .kavis-power-dialog button:active {
            background-color: @kavis_overlay_press;
        }
        """;

        public ShutdownDialog () {
            set_title (_("Shut down"));
            /* 2C: its own WM_CLASS — otherwise the taskbar icon fell
             * back to the .desktop of the emoji picker sharing the same
             * binary (smiley face). kavis-power.desktop matches via
             * StartupWMClass and provides the power icon. */
            set_wmclass ("kavis-power", "kavis-power");
            icon_name = "system-shutdown";
            set_resizable (false);
            set_decorated (false);
            set_position (Gtk.WindowPosition.CENTER);
            set_keep_above (true);

            /* Rounded corners: RGBA visual + transparent window, the
             * background on the inner box. */
            set_app_paintable (true);
            var visual = get_screen ().get_rgba_visual ();
            if (visual != null) {
                set_visual (visual);
            }
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) { }

            var outer = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            outer.get_style_context ().add_class ("kavis-power-dialog");
            add (outer);
            var card = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            outer.pack_start (card, false, false, 0);
            var hint = new Gtk.Label (_("Hold Shift: close without asking"));
            hint.get_style_context ().add_class ("dim-label");
            outer.pack_start (hint, false, false, 0);

            card.pack_start (power_button (
                "weather-clear-night-symbolic", _("Sleep"), () => {
                    Power.suspend ();
                }), false, false, 0);
            card.pack_start (power_button (
                "view-refresh-symbolic", _("Restart"), () => {
                    Power.reboot ();
                }), false, false, 0);
            card.pack_start (power_button (
                "system-shutdown-symbolic", _("Shut down"), () => {
                    Power.shutdown ();
                }), false, false, 0);
            card.pack_start (power_button (
                "window-close-symbolic", _("Cancel"), () => { }),
                false, false, 0);
            /* I (v0.4-test1): unsaved-document dialogs can stop the
             * shutdown — a Shift-click or this button first kills every
             * window, then shuts down. */
            card.pack_start (power_button (
                "process-stop-symbolic", _("Force shut down"), () => {
                    kill_all_windows ();
                    Power.shutdown ();
                }), false, false, 0);

            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    destroy ();
                    return true;
                }
                return false;
            });
        }

        private delegate void PowerAction ();

        /* SIGKILL to the processes owning normal/dialog windows: except
         * the panel, the desktop layer and this dialog. Shutdown is
         * coming anyway; not waiting for a graceful exit is the user's
         * choice. */
        private void kill_all_windows () {
            unowned Wnck.Screen screen = Wnck.Screen.get_default ();
            screen.force_update ();
            int self = (int) Posix.getpid ();
            foreach (unowned Wnck.Window w in screen.get_windows ()) {
                var type = w.get_window_type ();
                if (type == Wnck.WindowType.DOCK
                    || type == Wnck.WindowType.DESKTOP) {
                    continue;
                }
                int pid = w.get_pid ();
                if (pid <= 1 || pid == self) {
                    continue;
                }
                Posix.kill ((Posix.pid_t) pid, Posix.Signal.KILL);
            }
        }

        /* One big icon button: icon on top, label below (~110px). */
        private Gtk.Button power_button (string icon_name, string text,
                                         owned PowerAction action) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            var icon = new Gtk.Image.from_icon_name (
                icon_name, Gtk.IconSize.DIALOG);
            icon.pixel_size = 40;
            column.pack_start (icon, false, false, 0);
            column.pack_start (new Gtk.Label (text), false, false, 0);
            column.set_size_request (96, -1);
            button.add (column);
            button.clicked.connect (() => {
                /* With Shift held: kill every window first, then the
                 * action — no app is left asking questions. */
                Gdk.ModifierType state;
                if (Gtk.get_current_event_state (out state)
                    && (state & Gdk.ModifierType.SHIFT_MASK) != 0) {
                    kill_all_windows ();
                }
                action ();
                destroy ();
            });
            return button;
        }
    }
}
