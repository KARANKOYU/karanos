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
        /* Window buttons shrink between these bounds before the list
         * starts scrolling (stage 2 rule: the right region is never
         * squeezed, the window list is). Icon-only since stage 3, so
         * the bounds are near-square. */
        private const int MAX_BUTTON_WIDTH = 48;
        private const int MIN_BUTTON_WIDTH = 32;
        private const int BUTTON_SPACING = 2;
        /* Below this button width the 24 px icons switch to 16 px
         * ("icons shrink first, then the list scrolls"). */
        private const int COMPACT_THRESHOLD = 40;
        private const int ICON_NORMAL = 24;
        private const int ICON_COMPACT = 16;
        /* Active-window underline: short and centered, Windows 11
         * style — not the full button width. */
        private const int UNDERLINE_WIDTH = 16;
        private const int UNDERLINE_HEIGHT = 3;

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
        .kavis-panel button {
          transition: background-color 180ms ease;
        }
        .kavis-panel button:hover {
          background-color: #1D2C38;
        }
        /* Etkin öğe (sanal masaüstü düğmeleri): altında turkuaz şerit. */
        .kavis-panel button.active-item {
          background-color: #1D2C38;
          box-shadow: inset 0 -3px #2DD4BF;
        }
        /* Pencere düğmeleri (Windows 11 tarzı): yalnız ikon; etkin
           pencerenin göstergesi tam genişlik şerit değil, düğmenin
           ortasında kısa ince bir çizgi (.underline çocuğu). */
        .kavis-panel button.window-item {
          padding: 0 4px;
        }
        .kavis-panel button.window-item.active-item {
          box-shadow: none;
        }
        .kavis-panel .underline {
          background-color: transparent;
          border-radius: 2px;
          transition: background-color 180ms ease;
        }
        .kavis-panel button.active-item .underline {
          background-color: #2DD4BF;
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
        private Gtk.ScrolledWindow window_scroll;
        private Gtk.Box window_box;
        private HashTable<ulong, Gtk.Button> window_buttons;
        private HashTable<ulong, Gtk.Image> window_images;
        private int current_button_width = 0;
        private int current_icon_size = ICON_NORMAL;
        private bool width_update_pending = false;

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
            window_images = new HashTable<ulong, Gtk.Image> (
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
            /* Inside a ScrolledWindow so its minimum width collapses:
             * however many windows are open, the panel window never
             * demands more than the screen and the right region keeps
             * its natural size. Buttons first shrink toward
             * MIN_BUTTON_WIDTH; past that the list scrolls (overlay
             * scrollbar + mouse wheel). */
            window_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, BUTTON_SPACING);
            window_scroll = new Gtk.ScrolledWindow (null, null);
            window_scroll.set_policy (Gtk.PolicyType.AUTOMATIC,
                                      Gtk.PolicyType.NEVER);
            window_scroll.add (window_box);
            window_scroll.size_allocate.connect (() => {
                queue_button_width_update ();
            });
            box.pack_start (window_scroll, true, true, 6);

            /* --- right edge --- */
            /* Packed with expand=false: it always gets exactly its
             * natural width, no matter how crowded the window list is. */
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
            window_images.remove_all ();

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
            current_button_width = 0;   /* count changed — recompute */
            queue_button_width_update ();
        }

        /* Coalesce width updates into one idle pass: size_allocate fires
         * in bursts, and setting size requests from inside an allocate
         * cycle triggers GTK re-layout warnings. */
        private void queue_button_width_update () {
            if (width_update_pending) {
                return;
            }
            width_update_pending = true;
            Idle.add (() => {
                width_update_pending = false;
                update_button_widths ();
                return Source.REMOVE;
            });
        }

        /* Fit the window buttons to the space the list actually got:
         * equal widths, clamped to [MIN_BUTTON_WIDTH, MAX_BUTTON_WIDTH].
         * Below the minimum the ScrolledWindow takes over and scrolls. */
        private void update_button_widths () {
            uint count = window_buttons.size ();
            if (count == 0) {
                return;
            }
            int available = window_scroll.get_allocated_width ()
                - (int) (count - 1) * BUTTON_SPACING;
            if (available <= 1) {
                return;
            }
            int width = available / (int) count;
            width = int.min (MAX_BUTTON_WIDTH,
                             int.max (MIN_BUTTON_WIDTH, width));
            if (width == current_button_width) {
                return;
            }
            current_button_width = width;
            window_buttons.foreach ((xid, button) => {
                button.set_size_request (width, -1);
            });

            int icon_size = (width >= COMPACT_THRESHOLD)
                ? ICON_NORMAL : ICON_COMPACT;
            if (icon_size != current_icon_size) {
                current_icon_size = icon_size;
                refresh_icons ();
            }
        }

        private Gtk.Button window_button (Wnck.Window window, bool active) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            button.get_style_context ().add_class ("window-item");
            if (active) {
                button.get_style_context ().add_class ("active-item");
            }

            /* Icon centered, thin underline pinned to the bottom. The
             * underline is always in the layout (transparent when
             * inactive) so activation never shifts the icon. */
            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            var image = new Gtk.Image.from_pixbuf (
                window_icon (window, current_icon_size));
            image.set_valign (Gtk.Align.CENTER);
            column.pack_start (image, true, true, 0);

            var underline = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            underline.get_style_context ().add_class ("underline");
            underline.set_size_request (UNDERLINE_WIDTH, UNDERLINE_HEIGHT);
            underline.set_halign (Gtk.Align.CENTER);
            column.pack_end (underline, false, false, 0);

            button.add (column);

            /* Icon-only buttons: the full window title lives in the
             * tooltip and follows later title changes. */
            button.set_tooltip_text (window.get_name () ?? "");
            hook_name_changed (window);
            window_images.insert (window.get_xid (), image);

            unowned Wnck.Window target = window;
            button.clicked.connect (() => activate_window (target));
            if (current_button_width > 0) {
                button.set_size_request (current_button_width, -1);
            }
            return button;
        }

        /* The window's own icon scaled to `size`; a generic themed icon
         * when the window has none (libwnck would fall back to a bare
         * X pictogram). */
        private static Gdk.Pixbuf? window_icon (Wnck.Window window,
                                                int size) {
            Gdk.Pixbuf? icon = null;
            if (window.get_icon_is_fallback ()) {
                try {
                    icon = Gtk.IconTheme.get_default ().load_icon (
                        "application-x-executable", size, 0);
                } catch (Error e) {
                    icon = null;
                }
            }
            if (icon == null) {
                icon = window.get_icon ();
            }
            if (icon == null) {
                return null;
            }
            if (icon.get_width () != size || icon.get_height () != size) {
                icon = icon.scale_simple (size, size,
                                          Gdk.InterpType.BILINEAR);
            }
            return icon;
        }

        /* Keep tooltips in sync with title changes without rebuilding
         * the whole list. Connected once per window (flagged on the
         * object); the handler dies with the window. */
        private void hook_name_changed (Wnck.Window window) {
            if (window.get_data<bool> ("kavis-name-hooked")) {
                return;
            }
            window.set_data<bool> ("kavis-name-hooked", true);
            unowned Wnck.Window target = window;
            window.name_changed.connect (() => {
                var button = window_buttons.lookup (target.get_xid ());
                if (button != null) {
                    button.set_tooltip_text (target.get_name () ?? "");
                }
            });
        }

        /* Re-render every taskbar icon at the current size (called when
         * crossing the compact threshold). */
        private void refresh_icons () {
            foreach (unowned Wnck.Window window in screen.get_windows ()) {
                var image = window_images.lookup (window.get_xid ());
                if (image != null) {
                    image.set_from_pixbuf (
                        window_icon (window, current_icon_size));
                }
            }
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
