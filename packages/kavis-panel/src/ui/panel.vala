/* Taskbar (UI layer).
 *
 * Layout: start button with the K logo on the left, open windows in the
 * middle, workspace switcher / keyboard layout / battery / clock /
 * show-desktop on the right.
 *
 * No system tray here — XEmbed/StatusNotifier is its own task and
 * arrives with the notification infrastructure (item 37).
 */

namespace Kavis.Ui {

    public class Panel : Gtk.Window {

        public const int HEIGHT = 44;
        private const int MAX_BUTTON_WIDTH = 190;

        private const string CSS = """
        .kavis-panel {
          background-color: #121C26;
          border-top: 1px solid #233A45;
        }
        .kavis-panel button {
          border: none;
          border-radius: 0;
          background-image: none;
          background-color: transparent;
          color: #E6EDF3;
          padding: 0 10px;
        }
        .kavis-panel button:hover {
          background-color: #1D2C38;
        }
        /* Etkin pencere: altında turkuaz şerit — Windows'taki gibi hangi
           pencerede olduğun bir bakışta belli olsun. */
        .kavis-panel button.active-item {
          background-color: #1D2C38;
          box-shadow: inset 0 -3px #2DD4BF;
        }
        .kavis-panel button.start {
          padding: 0 14px;
        }
        .kavis-panel button.start:hover {
          background-color: #17222C;
        }
        .kavis-panel label.clock {
          color: #E6EDF3;
          padding: 0 12px;
        }
        .kavis-panel label.indicator {
          color: #8B9BA8;
          padding: 0 8px;
        }
        .kavis-start-menu {
          background-color: #17222C;
          border: 1px solid #233A45;
        }
        """;

        private unowned Wnck.Screen screen;
        private StartMenu start_menu;
        private Gtk.Box window_box;
        private HashTable<ulong, Gtk.Button> window_buttons;

        public Panel () {
            Object (type: Gtk.WindowType.TOPLEVEL);
            set_title ("kavis-panel");
            set_type_hint (Gdk.WindowTypeHint.DOCK);
            set_decorated (false);
            set_resizable (false);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_keep_above (true);
            stick ();
            get_style_context ().add_class ("kavis-panel");

            load_css ();

            screen = Wnck.Screen.get_default ();
            screen.force_update ();
            start_menu = new StartMenu ();
            window_buttons = new HashTable<ulong, Gtk.Button> (
                direct_hash, direct_equal);

            build ();
            place ();

            screen.window_opened.connect (() => refresh_windows ());
            screen.window_closed.connect (() => refresh_windows ());
            screen.active_window_changed.connect (() => on_active_changed ());
            screen.active_workspace_changed.connect (() => refresh_windows ());

            destroy.connect (Gtk.main_quit);
            /* Panel drifted after resolution changes without this. */
            Gdk.Screen.get_default ().size_changed.connect (() => place ());
        }

        private void load_css () {
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-panel: CSS yuklenemedi: %s", e.message);
            }
        }

        private void build () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            add (box);

            /* --- start button --- */
            var start_button = new Gtk.Button ();
            start_button.get_style_context ().add_class ("start");
            start_button.set_relief (Gtk.ReliefStyle.NONE);
            var inner = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            /* Logo follows the active theme (item 1): dark logo on the
             * dark theme, light on light. The choice lives in Brand —
             * one place. */
            inner.pack_start (Brand.logo_image (24), false, false, 0);
            inner.pack_start (new Gtk.Label (Strings.get ("panel.start")),
                              false, false, 0);
            start_button.add (inner);
            start_button.clicked.connect (on_start_clicked);
            box.pack_start (start_button, false, false, 0);

            /* --- window list --- */
            window_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            box.pack_start (window_box, true, true, 6);

            /* --- right edge --- */
            var right = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            right.pack_start (new WorkspaceIndicator (screen), false, false, 0);
            right.pack_start (new KeyboardIndicator (), false, false, 0);
            right.pack_start (new BatteryIndicator (), false, false, 0);
            right.pack_start (new Clock (), false, false, 0);

            var show_desktop = new Gtk.Button ();
            show_desktop.set_relief (Gtk.ReliefStyle.NONE);
            show_desktop.set_tooltip_text (Strings.get ("panel.show_desktop"));
            show_desktop.set_size_request (8, -1);
            show_desktop.clicked.connect (() => {
                screen.toggle_showing_desktop (!screen.get_showing_desktop ());
            });
            right.pack_start (show_desktop, false, false, 0);

            box.pack_end (right, false, false, 0);
        }

        private void place () {
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor ();
            if (monitor == null) {
                monitor = display.get_monitor (0);
            }
            Gdk.Rectangle area = monitor.get_geometry ();
            set_size_request (area.width, HEIGHT);
            resize (area.width, HEIGHT);
            move (area.x, area.y + area.height - HEIGHT);
            Idle.add (() => {
                set_strut (area);
                return Source.REMOVE;
            });
        }

        /* Reserve the panel strip at the bottom of the screen so
         * maximized windows stop above it (_NET_WM_STRUT_PARTIAL).
         *
         * The Python panel needed python3-xlib for this because
         * PyGObject hides Gdk.property_change; in Vala we talk to
         * libX11 directly — one XChangeProperty call, no extra
         * dependency. */
        private void set_strut (Gdk.Rectangle area) {
            var window = get_window ();
            if (window == null) {
                return;
            }
            var x11_window = window as Gdk.X11.Window;
            if (x11_window == null) {
                return;
            }
            unowned X.Display xdisplay =
                ((Gdk.X11.Display) get_display ()).get_xdisplay ();

            /* Combined screen height = bottom edge of the lowest
             * monitor (Gdk.Screen.get_height is deprecated). */
            int screen_height = 0;
            var display = Gdk.Display.get_default ();
            for (int i = 0; i < display.get_n_monitors (); i++) {
                Gdk.Rectangle mg = display.get_monitor (i).get_geometry ();
                screen_height = int.max (screen_height, mg.y + mg.height);
            }

            /* Panel sits at the bottom of the primary monitor; the
             * reserved strip runs to the very bottom of the combined
             * screen (covers the gap below on multi-monitor setups). */
            long bottom = screen_height - (area.y + area.height) + HEIGHT;
            long left_x = area.x;
            long right_x = area.x + area.width - 1;

            /* left, right, top, bottom, left_start, left_end,
             * right_start, right_end, top_start, top_end,
             * bottom_start, bottom_end */
            long[] strut_values = { 0, 0, 0, bottom, 0, 0, 0, 0, 0, 0,
                               left_x, right_x };

            X.Atom strut_partial = xdisplay.intern_atom (
                "_NET_WM_STRUT_PARTIAL", false);
            X.Atom strut = xdisplay.intern_atom ("_NET_WM_STRUT", false);
            X.Atom cardinal = xdisplay.intern_atom ("CARDINAL", false);
            X.Window xid = x11_window.get_xid ();

            xdisplay.change_property (xid, strut_partial, cardinal, 32,
                                      X.PropMode.Replace, (uchar[]) strut_values, 12);
            xdisplay.change_property (xid, strut, cardinal, 32,
                                      X.PropMode.Replace, (uchar[]) strut_values, 4);
            xdisplay.flush ();
        }

        private void on_start_clicked (Gtk.Button button) {
            if (start_menu.get_visible ()) {
                start_menu.dismiss ();
                return;
            }
            var window = button.get_window ();
            if (window == null) {
                return;
            }
            int root_x, root_y;
            window.get_origin (out root_x, out root_y);
            Gtk.Allocation alloc;
            button.get_allocation (out alloc);
            start_menu.open (root_x + alloc.x, root_y + alloc.y);
        }

        public void refresh_windows () {
            foreach (var child in window_box.get_children ()) {
                window_box.remove (child);
            }
            window_buttons.remove_all ();

            unowned Wnck.Workspace? active_workspace =
                screen.get_active_workspace ();
            unowned Wnck.Window? active_window = screen.get_active_window ();

            foreach (unowned Wnck.Window window in screen.get_windows ()) {
                if (window.is_skip_tasklist ()) {
                    continue;
                }
                /* Only windows of the current virtual desktop. */
                if (active_workspace != null
                    && !window.is_on_workspace (active_workspace)) {
                    continue;
                }
                var button = window_button (window, window == active_window);
                window_buttons.insert (window.get_xid (), button);
                window_box.pack_start (button, false, false, 0);
            }
            window_box.show_all ();
        }

        private Gtk.Button window_button (Wnck.Window window, bool active) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            if (active) {
                button.get_style_context ().add_class ("active-item");
            }
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var icon = window.get_mini_icon ();
            if (icon != null) {
                box.pack_start (new Gtk.Image.from_pixbuf (icon),
                                false, false, 0);
            }
            var label = new Gtk.Label (window.get_name () ?? "");
            label.set_xalign (0);
            label.set_ellipsize (Pango.EllipsizeMode.END);
            label.set_max_width_chars (20);
            box.pack_start (label, true, true, 0);
            button.add (box);
            button.set_tooltip_text (window.get_name () ?? "");
            unowned Wnck.Window target = window;
            button.clicked.connect (() => activate_window (target));
            button.set_property ("width-request", MAX_BUTTON_WIDTH);
            return button;
        }

        private void activate_window (Wnck.Window window) {
            uint32 timestamp = Gtk.get_current_event_time ();
            /* Clicking the active window again minimizes it — Windows
             * behavior. */
            if (window == screen.get_active_window ()
                && !window.is_minimized ()) {
                window.minimize ();
            } else {
                window.unminimize (timestamp);
                window.activate (timestamp);
            }
        }

        private void on_active_changed () {
            unowned Wnck.Window? active = screen.get_active_window ();
            ulong active_xid = (active != null) ? active.get_xid () : 0;
            window_buttons.foreach ((xid, button) => {
                unowned Gtk.StyleContext context = button.get_style_context ();
                if (xid == active_xid) {
                    context.add_class ("active-item");
                } else {
                    context.remove_class ("active-item");
                }
            });
        }
    }
}
