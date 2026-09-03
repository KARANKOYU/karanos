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

        /* Historical default (the single value before madde 5).
         * External tools (the CI clock check) look at the default
         * bottom/44 layout; the real thickness now comes from
         * config.thickness. */
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
        /* Acrylic (madde 4): with a compositor the panel is slightly
           translucent — the wallpaper shows through. Blur is
           deliberately ABSENT: it does not work on xrender (Grup B
           decision); madde 38 will evaluate picom blur on a real GPU,
           translucency is the 'acrylic' share until then. Without a
           compositor the panel falls back to a solid color. */
        .kavis-panel.acrylic {
          background-color: @kavis_panel_acrylic;
          border-top: 1px solid @kavis_border_acrylic;
        }
        .kavis-panel {
          background-color: @kavis_panel;
          border-top: 1px solid @kavis_border;
        }
        /* Hover rule (sonraki-isler 1): everything clickable on the
           panel gets the same box — white 9%, 14% when pressed, 6px
           corners, 140 ms; no border at rest. Buttons still cover the
           full panel height (no margin given): clicking the bottom-most
           pixel of the screen must work — Fitts. */
        .kavis-panel button {
          border: none;
          border-radius: 8px;   /* J1: single value for button corners */
          background-image: none;
          background-color: transparent;
          color: @kavis_text;
          padding: 0 10px;
          transition: background-color 140ms ease;
        }
        .kavis-panel button:hover {
          background-color: @kavis_overlay_hover;
        }
        .kavis-panel button:active {
          background-color: @kavis_overlay_press;
        }
        /* Indicator with an open popup: the box stays until it closes. */
        .kavis-panel button.popup-open {
          background-color: @kavis_overlay_hover;
        }
        /* Active item (virtual desktop buttons): teal strip underneath. */
        .kavis-panel button.active-item {
          background-color: @kavis_overlay_hover;
          box-shadow: inset 0 -3px @kavis_teal;
        }
        /* Window buttons (Windows 11 style): icon only; the active
           window's marker is not a full-width strip but a short thin
           line centered in the button (the .underline child). */
        .kavis-panel button.window-item {
          padding: 0 4px;
        }
        .kavis-panel button.window-item.active-item {
          box-shadow: none;
        }
        .kavis-panel .underline {
          border-radius: 2px;
          transition: background-color 140ms ease;
        }
        /* Slot lines (sonraki-isler 2): active is teal, running but
           inactive is dim; a pinned app that is not running has none. */
        .kavis-panel .underline.on {
          background-color: @kavis_teal;
        }
        .kavis-panel .underline.idle {
          background-color: @kavis_underline_idle;
        }
        .kavis-panel button.start {
          padding: 0 12px;
        }
        /* C4 (v0.4-test2): click feedback — a 150 ms flash one shade
           lighter than hover + a slight shrink of the icon (grows back
           through the transition). */
        .kavis-panel button image {
          transition: -gtk-icon-transform 150ms ease;
        }
        .kavis-panel button.flash {
          background-color: @kavis_overlay_flash;
        }
        .kavis-panel button.flash image {
          -gtk-icon-transform: scale(0.88);
        }
        /* D2: slider value bubble (quick settings), dark text on
           teal — an overlay child, takes no layout space. */
        label.kavis-bubble {
          background-color: @kavis_teal;
          color: @kavis_on_teal;
          border-radius: 6px;
          padding: 0 6px;
          font-size: 90%;
        }
        /* Show-desktop strip: the 8 px W11 remnant in the corner —
           gets no rounding and no padding. */
        .kavis-panel button.edge {
          border-radius: 0;
          padding: 0;
        }
        .kavis-panel label.clock {
          color: @kavis_text;
          padding: 0 12px;
        }
        .kavis-panel label.indicator {
          color: @kavis_text2;
          padding: 0 8px;
        }
        /* Indicator buttons (stage 4): the labels have their own
           padding, the button must not widen them further. */
        .kavis-panel button.usb-writing image {
            color: #F59E0B;
        }
        .kavis-panel button.indicator-button {
          padding: 0 2px;
        }
        .kavis-start-menu {
          background-color: @kavis_surface;
          border: 1px solid @kavis_border;
        }
        /* F1 (v0.4-test1): names were dim — light text, category
           header in its own tone, hover row a 10% overlay. Contrast
           on the dark theme 13:1 / 6:1. */
        .kavis-start-menu label.app-name {
          color: @kavis_text;
          opacity: 1;
        }
        .kavis-start-menu label.category {
          color: @kavis_menu_category;
          opacity: 1;
        }
        .kavis-start-menu button:hover {
          background-color: @kavis_menu_hover;
        }
        """;

        private new unowned Wnck.Screen screen;
        private PanelConfig config;
        private FileMonitor? config_monitor = null;
        private int thickness;
        /* Root box carrying the background class: on an app_paintable
         * window GTK does NOT paint the window's CSS background
         * (PanelPopup/Overview pattern) — with the class on the window
         * the panel came out fully transparent in the VM (the "blends
         * into the wallpaper" bug). */
        private Gtk.Box root_box;
        private StartMenu start_menu;
        private int logged_start_width = 0;
        private Gtk.Image start_logo;
        private string current_language = "";
        private Gtk.ScrolledWindow window_scroll;
        private Gtk.Box window_box;
        private Gtk.Box right_box;
        private Gtk.Button start_button;
        /* Auto-hide state (madde 5). */
        private bool panel_hidden = false;
        private uint hide_timer = 0;
        /* Notification toasts (madde 37) — a field to keep the ref alive. */
        private ToastManager toast_manager;
        /* Overview (madde 55). */
        private Overview overview;
        /* Clipboard history + volume OSD (madde 7). */
        private ClipboardHistory clipboard_history;
        /* Combined "Emoji and more" panel (sonraki-isler 5): Win+V
         * opens the clipboard tab, Win+. the last used tab. */
        private PickerPanel picker;
        /* Snap layout menu (sonraki-isler 4, Win+Z). */
        private SnapMenu snap_menu = new SnapMenu ();
        private GenericArray<TaskSlot> slots =
            new GenericArray<TaskSlot> ();
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

            /* Acrylic (madde 4): with a compositor an RGBA visual +
             * semi-transparent background; without picom (recovery,
             * crash) fall back to a solid color. picom may start AFTER
             * the panel, so composited-changed is listened to. */
            set_app_paintable (true);
            var gdk_screen = get_screen ();
            var rgba_visual = gdk_screen.get_rgba_visual ();
            if (rgba_visual != null) {
                set_visual (rgba_visual);
            }
            update_acrylic ();
            gdk_screen.composited_changed.connect (update_acrylic);

            load_css ();

            config = PanelConfig.get_default ();
            thickness = config.thickness.pixels ();
            /* Popups open on the side away from the panel. */
            PanelPopup.panel_position = config.position;

            /* Notification infrastructure (madde 37) BEFORE build():
             * the clock popup connects to the server while being built. */
            Notifications.start ();
            toast_manager = new ToastManager (Notifications.server);
            /* org.kavis.Panel: openbox shortcuts call in here
             * (W-Tab overview — madde 55, W-v clipboard — madde 7). */
            PanelBus.start ();

            screen = Wnck.Screen.get_default ();
            screen.force_update ();
            overview = new Overview (screen);
            clipboard_history = new ClipboardHistory ();
            picker = new PickerPanel (clipboard_history);
            if (PanelBus.service != null) {
                PanelBus.service.overview_requested.connect (() => {
                    overview.toggle ();
                });
                PanelBus.service.clipboard_requested.connect (() => {
                    picker.open ("clipboard");
                });
                PanelBus.service.start_menu_requested.connect ((search) => {
                    /* Close if open, open if closed (Win key, like W11). */
                    on_start_clicked (start_button);
                });
                PanelBus.service.picker_requested.connect ((page) => {
                    picker.open (page);
                });
                PanelBus.service.slot_requested.connect (
                    (number, new_window) => {
                        activate_slot_number (number, new_window);
                    });
                PanelBus.service.snap_menu_requested.connect (() => {
                    snap_menu.open ();
                });
            }
            start_menu = new StartMenu ();
            start_menu.taskbar_changed.connect (() => refresh_windows ());
            /* Start menu and indicator popups close one another. */
            PanelPopup.start_menu = start_menu;

            build ();
            place ();

            screen.window_opened.connect (() => refresh_windows ());
            screen.window_closed.connect (() => refresh_windows ());
            screen.active_window_changed.connect (() => on_active_changed ());
            screen.active_workspace_changed.connect (() => refresh_windows ());

            destroy.connect (Gtk.main_quit);
            /* Panel drifted after resolution changes without this. */
            Gdk.Screen.get_default ().size_changed.connect (() => place ());

            /* Right-click menu (madde 5). Buttons consume only the left
             * click, so the right click bubbles up to the window. */
            button_press_event.connect ((event) => {
                if (event.button == 3) {
                    show_context_menu (event);
                    return true;
                }
                return false;
            });

            /* Auto-hide: reveal on entering from the edge, hide on leave. */
            add_events (Gdk.EventMask.ENTER_NOTIFY_MASK
                        | Gdk.EventMask.LEAVE_NOTIFY_MASK);
            enter_notify_event.connect ((event) => {
                if (event.detail != Gdk.NotifyType.INFERIOR) {
                    reveal_panel ();
                }
                return false;
            });
            leave_notify_event.connect ((event) => {
                if (event.detail != Gdk.NotifyType.INFERIOR) {
                    schedule_hide ();
                }
                return false;
            });
            if (config.autohide) {
                schedule_hide ();
            }

            /* Live settings (1A-2): when Settings writes kavis.conf the
             * taskbar refreshes itself. The layout is fixed at build
             * time (box axes, strut) — rebuilding in place is costlier
             * and more error-prone than exec, and restart_self already
             * exists. The panel's OWN save() also fires the monitor;
             * the fields are already equal, so no loop forms. */
            try {
                current_language = Config.load ()
                    .get_string ("keyboard", "language");
            } catch (Error e) { }
            config_monitor = Config.watch (() => {
                var fresh = PanelConfig.load ();
                /* B6: language changed → gettext must be rebound; the
                 * cheapest correct way is a restart (AppInit reads the
                 * new language from ~/.config/kavis/locale). */
                string lang = "";
                try {
                    lang = Config.load ().get_string ("keyboard", "language");
                } catch (Error e) { }
                if (lang != current_language) {
                    current_language = lang;
                    restart_self ();
                    return;
                }
                if (fresh.position != config.position
                    || fresh.thickness != config.thickness
                    || fresh.alignment != config.alignment
                    || fresh.monitor != config.monitor
                    || fresh.autohide != config.autohide) {
                    config.position = fresh.position;
                    config.thickness = fresh.thickness;
                    config.alignment = fresh.alignment;
                    config.monitor = fresh.monitor;
                    config.autohide = fresh.autohide;
                    restart_self ();
                } else {
                    /* Cheap keys are applied in place. */
                    update_acrylic ();
                }
            });
        }

        private void update_acrylic () {
            if (root_box == null) {
                return;
            }
            /* Settings > Appearance "transparency" key (madde 38):
             * when off, a solid background even with compositing. */
            bool wanted = true;
            try {
                wanted = Config.load ().get_boolean (
                    "appearance", "transparency");
            } catch (Error e) { }
            unowned Gtk.StyleContext context = root_box.get_style_context ();
            if (wanted && get_screen ().is_composited ()) {
                context.add_class ("acrylic");
            } else {
                context.remove_class ("acrylic");
            }
        }

        private void load_css () {
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-panel: could not load CSS: %s", e.message);
            }
        }

        private void build () {
            /* In a vertical position (left/right, madde 5) the whole
             * axis turns: the cluster gathers at the top, indicators
             * move to the bottom, the window list scrolls vertically. */
            var axis = config.vertical
                ? Gtk.Orientation.VERTICAL : Gtk.Orientation.HORIZONTAL;
            var box = new Gtk.Box (axis, 0);
            root_box = box;
            box.get_style_context ().add_class ("kavis-panel");
            update_acrylic ();
            add (box);

            /* --- start button --- */
            start_button = new Gtk.Button ();
            start_button.get_style_context ().add_class ("start");
            start_button.set_relief (Gtk.ReliefStyle.NONE);
            /* Logo follows the active theme (item 1): dark logo on the
             * dark theme, light on light. The choice lives in Brand —
             * one place. Left-aligned (the Windows 10 default) the
             * logo carries a "Start" label; centered (Windows 11
             * option) it is icon-only with the label in the tooltip. */
            bool centered =
                config.alignment == PanelConfig.Alignment.CENTER;
            start_logo = Brand.logo_image (24);
            /* B2: when the theme changes live, the logo (dark/light K)
             * changes with it. */
            Theme.events ().changed.connect ((light) => {
                Brand.refresh_logo (start_logo, 24);
            });
            if (centered || config.vertical) {
                start_button.add (start_logo);
                start_button.set_tooltip_text (_("Start"));
            } else {
                var start_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                start_row.pack_start (start_logo, false, false, 0);
                var start_label = new Gtk.Label (_("Start"));
                /* 4A: in long languages the text is NOT clipped — the
                 * button grows with the text, the window list shrinks
                 * (update_button_widths already subtracts start_extent). */
                start_label.set_ellipsize (Pango.EllipsizeMode.NONE);
                start_row.pack_start (start_label, false, false, 0);
                start_button.add (start_row);
                /* 4A CI check: the LABEL width is written to stderr
                 * (the button width would dilute the growth because of
                 * logo+padding); the workflow compares the EN/xx runs
                 * and emits I18N-WIDTH-WARN. */
                start_label.size_allocate.connect ((alloc) => {
                    if (alloc.width != logged_start_width) {
                        logged_start_width = alloc.width;
                        /* J: the '··' padding of xx is not overflow; real
                         * clipping is whether Pango inserted '…'. */
                        printerr ("kavis-panel: start-width=%d start-clipped=%d\n",
                                  alloc.width,
                                  start_label.get_layout ().is_ellipsized () ? 1 : 0);
                    }
                });
            }
            start_button.clicked.connect (on_start_clicked);

            /* --- window list --- */
            /* Inside a ScrolledWindow so its minimum width collapses:
             * however many windows are open, the panel window never
             * demands more than the screen and the right region keeps
             * its natural size. Buttons first shrink toward
             * MIN_BUTTON_WIDTH; past that the list scrolls (overlay
             * scrollbar + mouse wheel). propagate_natural_width: the
             * scroll area ASKS for its content's width (so the cluster
             * can sit centered) but still collapses under pressure. */
            window_box = new Gtk.Box (axis, BUTTON_SPACING);
            window_scroll = new Gtk.ScrolledWindow (null, null);
            if (config.vertical) {
                window_scroll.set_policy (Gtk.PolicyType.NEVER,
                                          Gtk.PolicyType.AUTOMATIC);
                window_scroll.set_propagate_natural_height (true);
            } else {
                window_scroll.set_policy (Gtk.PolicyType.AUTOMATIC,
                                          Gtk.PolicyType.NEVER);
                window_scroll.set_propagate_natural_width (true);
            }
            window_scroll.add (window_box);
            window_scroll.size_allocate.connect (() => {
                queue_button_width_update ();
            });

            /* --- cluster placement (madde 4 + alignment option) --- */
            /* Left-aligned (default, W10): Start + window list begin at
             * the left. Centered (W11 option): two expanding spacers
             * center the cluster. In both layouts scrolling kicks in
             * once the window list exceeds its natural width — the
             * right region is never squeezed (stage 2 rule holds). */
            var cluster = new Gtk.Box (axis, 4);
            cluster.pack_start (start_button, false, false, 0);
            cluster.pack_start (window_scroll, false, false, 0);

            if (centered) {
                var left_spacer = new Gtk.Box (axis, 0);
                var right_spacer = new Gtk.Box (axis, 0);
                box.pack_start (left_spacer, true, true, 0);
                box.pack_start (cluster, false, false, 0);
                box.pack_start (right_spacer, true, true, 0);
            } else {
                box.pack_start (cluster, false, false, 0);
            }

            /* --- right edge --- */
            /* Packed with expand=false: it always gets exactly its
             * natural width, no matter how crowded the window list is. */
            /* Right region groups (sonraki-isler 1 + test8 A1):
             * [desktops][language][tools][Wi-Fi+volume+battery][clock]
             * — 6px apart horizontally, 8px vertically; in vertical
             * mode the cluster stacks and the clock uses a short date
             * without the year. */
            right_box = new Gtk.Box (axis, config.vertical ? 8 : 6);
            right_box.pack_start (new WorkspaceIndicator (screen, axis),
                                  false, false, 0);
            right_box.pack_start (new KeyboardIndicator (), false, false, 0);
            right_box.pack_start (new UsbIndicator (), false, false, 0);
            right_box.pack_start (new StatusCluster (config.vertical),
                                  false, false, 0);
            right_box.pack_start (new Clock (config.vertical),
                                  false, false, 0);

            var show_desktop = new Gtk.Button ();
            show_desktop.get_style_context ().add_class ("edge");
            show_desktop.set_relief (Gtk.ReliefStyle.NONE);
            show_desktop.set_tooltip_text (_("Show desktop"));
            if (config.vertical) {
                show_desktop.set_size_request (-1, 8);
            } else {
                show_desktop.set_size_request (8, -1);
            }
            show_desktop.clicked.connect (() => {
                screen.toggle_showing_desktop (!screen.get_showing_desktop ());
            });
            right_box.pack_start (show_desktop, false, false, 0);

            box.pack_end (right_box, false, false, 0);
            /* When the right region widens (an indicator is added) the
             * window buttons' share changes too. */
            right_box.size_allocate.connect (() => {
                queue_button_width_update ();
            });
        }

        /* The monitor the panel lives on (madde 5): the configured
         * model if it is still connected, else primary — a vanished
         * monitor must never leave the user panel-less. */
        private Gdk.Monitor pick_monitor () {
            var display = Gdk.Display.get_default ();
            if (config.monitor != "primary") {
                for (int i = 0; i < display.get_n_monitors (); i++) {
                    var candidate = display.get_monitor (i);
                    if (candidate != null
                        && candidate.get_model () == config.monitor) {
                        return candidate;
                    }
                }
            }
            var primary = display.get_primary_monitor ();
            return (primary != null) ? primary : display.get_monitor (0);
        }

        private void place () {
            Gdk.Rectangle area = pick_monitor ().get_geometry ();
            int w, h, x, y;
            switch (config.position) {
            case PanelConfig.Position.TOP:
                w = area.width;  h = thickness;
                x = area.x;      y = area.y;
                break;
            case PanelConfig.Position.LEFT:
                w = thickness;   h = area.height;
                x = area.x;      y = area.y;
                break;
            case PanelConfig.Position.RIGHT:
                w = thickness;   h = area.height;
                x = area.x + area.width - thickness;
                y = area.y;
                break;
            default:   /* BOTTOM */
                w = area.width;  h = thickness;
                x = area.x;      y = area.y + area.height - thickness;
                break;
            }
            set_size_request (w, h);
            resize (w, h);
            move (x, y);
            panel_hidden = false;
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

            /* Combined screen extents (Gdk.Screen.get_width/height are
             * deprecated): struts are measured from the edges of the
             * WHOLE virtual screen, not of one monitor. */
            int screen_width = 0;
            int screen_height = 0;
            var display = Gdk.Display.get_default ();
            for (int i = 0; i < display.get_n_monitors (); i++) {
                Gdk.Rectangle mg = display.get_monitor (i).get_geometry ();
                screen_width = int.max (screen_width, mg.x + mg.width);
                screen_height = int.max (screen_height, mg.y + mg.height);
            }

            /* left, right, top, bottom, left_start, left_end,
             * right_start, right_end, top_start, top_end,
             * bottom_start, bottom_end */
            long[] strut_values = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

            /* With auto-hide no strip is reserved: windows use the
             * whole screen and the panel slides in over them. */
            if (!config.autohide) {
                switch (config.position) {
                case PanelConfig.Position.TOP:
                    strut_values[2] = area.y + thickness;
                    strut_values[8] = area.x;
                    strut_values[9] = area.x + area.width - 1;
                    break;
                case PanelConfig.Position.LEFT:
                    strut_values[0] = area.x + thickness;
                    strut_values[4] = area.y;
                    strut_values[5] = area.y + area.height - 1;
                    break;
                case PanelConfig.Position.RIGHT:
                    strut_values[1] = screen_width
                        - (area.x + area.width) + thickness;
                    strut_values[6] = area.y;
                    strut_values[7] = area.y + area.height - 1;
                    break;
                default:   /* BOTTOM — the strip extends to the very
                            * bottom of the combined screen (also covers
                            * the gap of a monitor below). */
                    strut_values[3] = screen_height
                        - (area.y + area.height) + thickness;
                    strut_values[10] = area.x;
                    strut_values[11] = area.x + area.width - 1;
                    break;
                }
            }

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
            flash (button);
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
            int bx = root_x + alloc.x;
            int by = root_y + alloc.y;

            /* The menu's TOP-LEFT corner depends on the panel position
             * (madde 5): open() expects an absolute corner. */
            int x, y;
            switch (config.position) {
            case PanelConfig.Position.TOP:
                x = bx;
                y = by + alloc.height;
                break;
            case PanelConfig.Position.LEFT:
                x = bx + alloc.width;
                y = by;
                break;
            case PanelConfig.Position.RIGHT:
                x = bx - StartMenu.WIDTH;
                y = by;
                break;
            default:   /* BOTTOM */
                x = bx;
                y = by - StartMenu.HEIGHT;
                break;
            }
            /* Clamp into the monitor. */
            Gdk.Rectangle area = pick_monitor ().get_geometry ();
            x = int.max (area.x, int.min (x, area.x + area.width
                                          - StartMenu.WIDTH));
            y = int.max (area.y, int.min (y, area.y + area.height
                                          - StartMenu.HEIGHT));
            start_menu.open (x, y);
        }

        /* --- taskbar slots (sonraki-isler 2) -------------------------- */
        /* One slot = one application: pinned ones from the left
         * (pinned.conf order), unpinned running ones toward the right.
         * When a pinned app runs the SAME icon becomes its window; the
         * windows of one app gather in a single icon (two short lines
         * underneath, clicks cycle through them). An unmatched window
         * becomes an unpinned slot keyed by its class name. */
        private class TaskSlot {
            public string key;
            public string? desktop_id;
            public bool pinned;
            public GenericArray<unowned Wnck.Window> windows =
                new GenericArray<unowned Wnck.Window> ();
            public Gtk.Button button;
            public Gtk.Image image;
            public Gtk.Box underline_row;
            public int cycle = 0;
        }

        public void refresh_windows () {
            foreach (var child in window_box.get_children ()) {
                window_box.remove (child);
            }
            slots = new GenericArray<TaskSlot> ();
            var by_key = new HashTable<string, TaskSlot> (
                str_hash, str_equal);

            foreach (unowned string id in Pinned.load ()) {
                if (by_key.lookup (id) != null
                    || AppMatch.info_for (id) == null) {
                    /* A pinned app that is not installed is not drawn
                     * but stays in the list — the icon appears once the
                     * app arrives. */
                    continue;
                }
                var slot = new TaskSlot ();
                slot.key = id;
                slot.desktop_id = id;
                slot.pinned = true;
                slots.add (slot);
                by_key.insert (id, slot);
            }

            unowned Wnck.Workspace? active_workspace =
                screen.get_active_workspace ();
            foreach (unowned Wnck.Window window in screen.get_windows ()) {
                if (window.is_skip_tasklist ()) {
                    continue;
                }
                /* Only windows of the current virtual desktop. */
                if (active_workspace != null
                    && !window.is_on_workspace (active_workspace)) {
                    continue;
                }
                string? id = AppMatch.desktop_id_for_window (window);
                string key = id ?? "class:%s".printf (
                    window.get_class_group_name ()
                    ?? "%lu".printf (window.get_xid ()));
                var slot = by_key.lookup (key);
                if (slot == null) {
                    slot = new TaskSlot ();
                    slot.key = key;
                    slot.desktop_id = id;
                    slot.pinned = false;
                    slots.add (slot);
                    by_key.insert (key, slot);
                }
                slot.windows.add (window);
                hook_name_changed (window);
            }

            for (int i = 0; i < slots.length; i++) {
                var slot = slots[i];
                slot.button = slot_button (slot);
                window_box.pack_start (slot.button, false, false, 0);
            }
            window_box.show_all ();
            sync_slot_states ();
            current_button_width = 0;   /* count changed — recompute */
            queue_button_width_update ();
        }

        /* Win+digit (sonraki-isler 2): the Nth slot from the left —
         * launch if not running, focus if running; new_window always
         * opens a new instance. number 0 = the tenth slot. */
        public void activate_slot_number (int number, bool new_window) {
            int index = (number == 0) ? 9 : number - 1;
            if (index < 0 || index >= slots.length) {
                return;
            }
            var slot = slots[index];
            if (new_window || slot.windows.length == 0) {
                if (slot.button != null) {
                    flash (slot.button);
                }
                launch_slot (slot);
            } else {
                on_slot_clicked (slot);
            }
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

        /* Fit the window buttons to the space the list CAN take:
         * equal widths, clamped to [MIN_BUTTON_WIDTH, MAX_BUTTON_WIDTH].
         * Below the minimum the ScrolledWindow takes over and scrolls.
         *
         * Since the centered cluster (madde 4) the available space
         * CANNOT be read from the scroller's allocation: because of
         * propagate_natural_width the allocation equals the content
         * width and the computation would feed itself (a button that
         * started at 32 would stay at 32). The space is derived from
         * the panel geometry: panel − right region − Start − cluster
         * spacing. */
        private void update_button_widths () {
            uint count = slots.length;
            if (count == 0) {
                return;
            }
            /* On a vertical panel the same math runs on the height axis. */
            int panel_extent = config.vertical
                ? get_allocated_height () : get_allocated_width ();
            int right_extent = config.vertical
                ? right_box.get_allocated_height ()
                : right_box.get_allocated_width ();
            int start_extent = config.vertical
                ? start_button.get_allocated_height ()
                : start_button.get_allocated_width ();
            int list_space = panel_extent - right_extent - start_extent
                - 16;   /* cluster spacing + breathing room */
            int available = list_space - (int) (count - 1) * BUTTON_SPACING;
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
            for (int i = 0; i < slots.length; i++) {
                if (config.vertical) {
                    slots[i].button.set_size_request (-1, width);
                } else {
                    slots[i].button.set_size_request (width, -1);
                }
            }

            int icon_size = (width >= COMPACT_THRESHOLD)
                ? ICON_NORMAL : ICON_COMPACT;
            if (icon_size != current_icon_size) {
                current_icon_size = icon_size;
                refresh_icons ();
            }
        }

        private Gtk.Button slot_button (TaskSlot slot) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            button.get_style_context ().add_class ("window-item");

            /* Icon centered, underline strip pinned to the bottom.
             * The strip is always in the layout (empty when the app
             * is not running) so state changes never shift the icon. */
            /* C3 (v0.4-test2): on a vertical panel the strip is vertical
             * and to the LEFT of the icon (like the W10 vertical
             * taskbar); horizontally it sits below. */
            var column = new Gtk.Box (config.vertical
                ? Gtk.Orientation.HORIZONTAL : Gtk.Orientation.VERTICAL, 0);
            slot.image = new Gtk.Image ();
            slot.image.set_valign (Gtk.Align.CENTER);
            slot.image.set_halign (Gtk.Align.CENTER);
            set_slot_image (slot, current_icon_size > 0
                            ? current_icon_size : ICON_NORMAL);

            if (config.vertical) {
                slot.underline_row = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
                slot.underline_row.set_valign (Gtk.Align.CENTER);
                slot.underline_row.set_size_request (UNDERLINE_HEIGHT, -1);
                column.pack_start (slot.underline_row, false, false, 0);
                column.pack_start (slot.image, true, true, 0);
            } else {
                column.pack_start (slot.image, true, true, 0);
                slot.underline_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
                slot.underline_row.set_halign (Gtk.Align.CENTER);
                slot.underline_row.set_size_request (-1, UNDERLINE_HEIGHT);
                column.pack_end (slot.underline_row, false, false, 0);
            }

            button.add (column);

            unowned TaskSlot target = slot;
            button.clicked.connect (() => on_slot_clicked (target));
            button.button_press_event.connect ((event) => {
                if (event.button == 3) {
                    show_slot_menu (target, event);
                    return true;
                }
                return false;
            });

            /* Drag-and-drop serves two purposes: pin reordering (pinned
             * only, application/x-kavis-pin) and DROPPING A FILE ON THE
             * ICON (6f, text/uri-list — the app opens the file). Files
             * are accepted only by apps that can take files; otherwise
             * the cursor stays 'forbidden' (drag_motion status 0). */
            if (slot.pinned) {
                Gtk.TargetEntry[] pin_source = {
                    { "application/x-kavis-pin",
                      Gtk.TargetFlags.SAME_APP, 0 }
                };
                Gtk.drag_source_set (button,
                    Gdk.ModifierType.BUTTON1_MASK, pin_source,
                    Gdk.DragAction.MOVE);
                button.drag_data_get.connect ((ctx, data, info, time) => {
                    data.set_text (target.desktop_id, -1);
                });
            }
            Gtk.TargetEntry[] dest_targets = {
                { "application/x-kavis-pin",
                  Gtk.TargetFlags.SAME_APP, 0 },
                { "text/uri-list", 0, 1 }
            };
            Gtk.drag_dest_set (button,
                Gtk.DestDefaults.HIGHLIGHT | Gtk.DestDefaults.DROP,
                dest_targets,
                Gdk.DragAction.MOVE | Gdk.DragAction.COPY);
            button.drag_motion.connect ((ctx, x, y, time) => {
                var uri_atom = Gdk.Atom.intern ("text/uri-list", false);
                bool has_uri = false;
                foreach (var atom in ctx.list_targets ()) {
                    if (atom == uri_atom) {
                        has_uri = true;
                    }
                }
                if (has_uri) {
                    if (!slot_accepts_files (target)) {
                        Gdk.drag_status (ctx, 0, time);   /* forbidden */
                        return true;
                    }
                    Gdk.drag_status (ctx, Gdk.DragAction.COPY, time);
                    return true;
                }
                /* Pin reordering: pinned targets only. */
                Gdk.drag_status (ctx,
                    target.pinned ? Gdk.DragAction.MOVE : 0, time);
                return true;
            });
            button.drag_data_received.connect (
                (ctx, x, y, data, info, time) => {
                    if (info == 1) {
                        drop_uris_on_slot (target, data.get_uris ());
                        Gtk.drag_finish (ctx, true, false, time);
                        return;
                    }
                    string? dragged = data.get_text ();
                    if (target.pinned && dragged != null
                        && dragged != target.desktop_id) {
                        Pinned.move_before (dragged,
                                            target.desktop_id);
                        refresh_windows ();
                    }
                    Gtk.drag_finish (ctx, true, false, time);
                });

            if (current_button_width > 0) {
                if (config.vertical) {
                    button.set_size_request (-1, current_button_width);
                } else {
                    button.set_size_request (current_button_width, -1);
                }
            }
            return button;
        }

        private void set_slot_image (TaskSlot slot, int size) {
            if (slot.desktop_id != null) {
                var info = AppMatch.info_for (slot.desktop_id);
                if (info != null && info.get_icon () != null) {
                    slot.image.set_from_gicon (info.get_icon (),
                                               Gtk.IconSize.INVALID);
                    slot.image.set_pixel_size (size);
                    return;
                }
            }
            if (slot.windows.length > 0) {
                slot.image.set_from_pixbuf (
                    window_icon (slot.windows[0], size));
                return;
            }
            slot.image.set_from_icon_name ("application-x-executable",
                                           Gtk.IconSize.INVALID);
            slot.image.set_pixel_size (size);
        }

        /* 6f: can this app open a file dropped on its icon? */
        private bool slot_accepts_files (TaskSlot slot) {
            if (slot.desktop_id == null) {
                return false;
            }
            var info = AppMatch.info_for (slot.desktop_id);
            return info != null
                && (info.supports_uris () || info.supports_files ());
        }

        private void drop_uris_on_slot (TaskSlot slot, string[] uris) {
            if (!slot_accepts_files (slot) || uris.length == 0) {
                return;
            }
            var info = AppMatch.info_for (slot.desktop_id);
            var list = new List<string> ();
            foreach (unowned string uri in uris) {
                list.append (uri);
            }
            try {
                info.launch_uris (list, null);
            } catch (Error e) {
                warning ("kavis-panel: could not open file: %s", e.message);
            }
        }

        private void launch_slot (TaskSlot slot) {
            if (slot.desktop_id == null) {
                return;
            }
            var info = AppMatch.info_for (slot.desktop_id);
            if (info == null) {
                return;
            }
            try {
                /* GDesktopAppInfo expands the %U/%f codes itself. */
                info.launch (null, null);
            } catch (Error e) {
                warning ("kavis-panel: could not launch %s: %s",
                         slot.desktop_id, e.message);
            }
        }

        /* C4: the 150 ms flash class — same for click and Win+digit. */
        private void flash (Gtk.Widget widget) {
            widget.get_style_context ().add_class ("flash");
            /* widget is held strongly by the closure: even if a slot
             * button rebuilt within those 150 ms goes away, a freed
             * StyleContext is never touched. */
            Timeout.add (150, () => {
                widget.get_style_context ().remove_class ("flash");
                return Source.REMOVE;
            });
        }

        private void on_slot_clicked (TaskSlot slot) {
            if (slot.button != null) {
                flash (slot.button);
            }
            if (slot.windows.length == 0) {
                launch_slot (slot);
                return;
            }
            if (slot.windows.length == 1) {
                activate_window (slot.windows[0]);
                return;
            }
            /* Multiple windows: clicks cycle through them. */
            slot.cycle = (slot.cycle + 1) % (int) slot.windows.length;
            unowned Wnck.Window next = slot.windows[slot.cycle];
            uint32 timestamp = Gtk.get_current_event_time ();
            next.unminimize (timestamp);
            next.activate (timestamp);
        }

        /* Refresh underlines and tooltips by state: a pinned app that
         * is not running has no line; one window one line; several
         * windows two short lines. Teal when active, dim otherwise. */
        private void sync_slot_states () {
            unowned Wnck.Window? active_window =
                screen.get_active_window ();
            for (int i = 0; i < slots.length; i++) {
                var slot = slots[i];
                if (slot.underline_row == null) {
                    continue;
                }
                foreach (var child in slot.underline_row.get_children ()) {
                    slot.underline_row.remove (child);
                }
                bool any_active = false;
                var titles = new StringBuilder ();
                for (int w = 0; w < slot.windows.length; w++) {
                    if (slot.windows[w] == active_window) {
                        any_active = true;
                    }
                    if (titles.len > 0) {
                        titles.append_c ('\n');
                    }
                    titles.append (slot.windows[w].get_name () ?? "");
                }
                int bars = int.min (2, (int) slot.windows.length);
                int bar_width = (bars == 2)
                    ? UNDERLINE_WIDTH / 2 - 2 : UNDERLINE_WIDTH;
                for (int b = 0; b < bars; b++) {
                    var bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                    bar.get_style_context ().add_class ("underline");
                    bar.get_style_context ().add_class (
                        any_active ? "on" : "idle");
                    if (config.vertical) {
                        bar.set_size_request (UNDERLINE_HEIGHT, bar_width);
                    } else {
                        bar.set_size_request (bar_width, UNDERLINE_HEIGHT);
                    }
                    slot.underline_row.pack_start (bar, false, false, 0);
                }
                slot.underline_row.show_all ();

                if (slot.windows.length == 0) {
                    var info = (slot.desktop_id != null)
                        ? AppMatch.info_for (slot.desktop_id) : null;
                    slot.button.set_tooltip_text (
                        (info != null) ? info.get_display_name () : "");
                } else {
                    slot.button.set_tooltip_text (titles.str);
                }
            }
        }

        /* --- slot right-click menu (sonraki-isler 2) ------------------ */

        private void show_slot_menu (TaskSlot slot, Gdk.EventButton event) {
            var menu = new Gtk.Menu ();
            unowned TaskSlot target = slot;

            if (slot.desktop_id != null) {
                var info = AppMatch.info_for (slot.desktop_id);
                if (info != null) {
                    /* App name in bold; clicking opens a new window. */
                    var title = new Gtk.MenuItem ();
                    var title_label = new Gtk.Label (null);
                    title_label.set_markup ("<b>%s</b>".printf (
                        Markup.escape_text (info.get_display_name ())));
                    title_label.set_xalign (0);
                    title.add (title_label);
                    title.activate.connect (() => launch_slot (target));
                    menu.append (title);

                    /* .desktop Actions (if any). */
                    string[] actions = info.list_actions ();
                    if (actions.length > 0) {
                        menu.append (new Gtk.SeparatorMenuItem ());
                    }
                    foreach (unowned string action in actions) {
                        /* G2: verb first — "Open Trash", not "Trash";
                         * the action name comes localized from GLib, the
                         * pattern is translated (.desktop untouched). */
                        var item = new Gtk.MenuItem.with_label (
                            _("Open %s").printf (
                                info.get_action_name (action)));
                        string action_copy = action;
                        item.activate.connect (() => {
                            var fresh = AppMatch.info_for (
                                target.desktop_id);
                            if (fresh != null) {
                                fresh.launch_action (action_copy,
                                    new AppLaunchContext ());
                            }
                        });
                        menu.append (item);
                    }

                    menu.append (new Gtk.SeparatorMenuItem ());
                    var pin_item = new Gtk.MenuItem.with_label (
                        slot.pinned ? _("Unpin from taskbar")
                                    : _("Pin to taskbar"));
                    pin_item.activate.connect (() => {
                        if (target.pinned) {
                            Pinned.remove (target.desktop_id);
                        } else {
                            Pinned.add (target.desktop_id);
                        }
                        refresh_windows ();
                    });
                    menu.append (pin_item);
                }
            }

            if (slot.windows.length > 0) {
                var close_item = new Gtk.MenuItem.with_label (
                    slot.windows.length == 1
                    ? _("Close window") : _("Close all windows"));
                close_item.activate.connect (() => {
                    uint32 timestamp = Gtk.get_current_event_time ();
                    for (int w = 0; w < target.windows.length; w++) {
                        target.windows[w].close (timestamp);
                    }
                });
                menu.append (close_item);
            }

            if (menu.get_children ().length () == 0) {
                return;
            }
            /* Leak guard: the menu is destroyed on close (via Idle,
             * because activation runs AFTER deactivate). */
            menu.deactivate.connect (() => {
                Idle.add (() => {
                    menu.destroy ();
                    return Source.REMOVE;
                });
            });
            menu.show_all ();
            /* G4: the menu opens centered ABOVE the clicked icon (with
             * the panel at the bottom; elsewhere GTK flips it itself). */
            menu.popup_at_widget (slot.button,
                Gdk.Gravity.NORTH, Gdk.Gravity.SOUTH, event);
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
            window.name_changed.connect (() => {
                sync_slot_states ();
            });
        }

        /* Re-render every taskbar icon at the current size (called when
         * crossing the compact threshold). */
        private void refresh_icons () {
            for (int i = 0; i < slots.length; i++) {
                set_slot_image (slots[i], current_icon_size);
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

        /* --- right-click menu (madde 5) ------------------------------- */

        private void show_context_menu (Gdk.EventButton event) {
            var menu = new Gtk.Menu ();

            /* Position */
            var position_item = new Gtk.MenuItem.with_label (
                _("Position"));
            var position_menu = new Gtk.Menu ();
            unowned SList<Gtk.RadioMenuItem>? position_group = null;
            PanelConfig.Position[] positions = {
                PanelConfig.Position.BOTTOM, PanelConfig.Position.TOP,
                PanelConfig.Position.LEFT, PanelConfig.Position.RIGHT
            };
            string[] position_keys = {
                N_("Bottom"), N_("Top"),
                N_("Left"), N_("Right")
            };
            for (int i = 0; i < positions.length; i++) {
                var item = new Gtk.RadioMenuItem.with_label (
                    position_group, _(position_keys[i]));
                position_group = item.get_group ();
                item.set_active (config.position == positions[i]);
                PanelConfig.Position value = positions[i];
                item.activate.connect (() => {
                    if (item.get_active () && config.position != value) {
                        config.position = value;
                        restart_self ();
                    }
                });
                position_menu.append (item);
            }
            position_item.set_submenu (position_menu);
            menu.append (position_item);

            /* Size */
            var size_item = new Gtk.MenuItem.with_label (
                _("Size"));
            var size_menu = new Gtk.Menu ();
            unowned SList<Gtk.RadioMenuItem>? size_group = null;
            PanelConfig.Thickness[] sizes = {
                PanelConfig.Thickness.THIN, PanelConfig.Thickness.MEDIUM,
                PanelConfig.Thickness.THICK
            };
            string[] size_keys = {
                N_("Thin"), N_("Medium"), N_("Thick")
            };
            for (int i = 0; i < sizes.length; i++) {
                var item = new Gtk.RadioMenuItem.with_label (
                    size_group, _(size_keys[i]));
                size_group = item.get_group ();
                item.set_active (config.thickness == sizes[i]);
                PanelConfig.Thickness value = sizes[i];
                item.activate.connect (() => {
                    if (item.get_active () && config.thickness != value) {
                        config.thickness = value;
                        restart_self ();
                    }
                });
                size_menu.append (item);
            }
            size_item.set_submenu (size_menu);
            menu.append (size_item);

            /* Alignment (Grup D fix): left is the default, centered is
             * the option. Since build() sets up the layout, a change
             * needs restart_self() just like position/size. */
            var align_item = new Gtk.MenuItem.with_label (
                _("Alignment"));
            var align_menu = new Gtk.Menu ();
            unowned SList<Gtk.RadioMenuItem>? align_group = null;
            PanelConfig.Alignment[] alignments = {
                PanelConfig.Alignment.LEFT, PanelConfig.Alignment.CENTER
            };
            string[] align_keys = {
                N_("Align left"), N_("Center")
            };
            for (int i = 0; i < alignments.length; i++) {
                var item = new Gtk.RadioMenuItem.with_label (
                    align_group, _(align_keys[i]));
                align_group = item.get_group ();
                item.set_active (config.alignment == alignments[i]);
                PanelConfig.Alignment value = alignments[i];
                item.activate.connect (() => {
                    if (item.get_active () && config.alignment != value) {
                        config.alignment = value;
                        restart_self ();
                    }
                });
                align_menu.append (item);
            }
            align_item.set_submenu (align_menu);
            menu.append (align_item);

            /* Monitor — only when there is more than one. */
            var display = Gdk.Display.get_default ();
            if (display.get_n_monitors () > 1) {
                var monitor_item = new Gtk.MenuItem.with_label (
                    _("Monitor"));
                var monitor_menu = new Gtk.Menu ();
                unowned SList<Gtk.RadioMenuItem>? monitor_group = null;

                var primary_item = new Gtk.RadioMenuItem.with_label (
                    monitor_group, _("Primary monitor"));
                monitor_group = primary_item.get_group ();
                primary_item.set_active (config.monitor == "primary");
                primary_item.activate.connect (() => {
                    if (primary_item.get_active ()
                        && config.monitor != "primary") {
                        config.monitor = "primary";
                        config.save ();
                        place ();
                    }
                });
                monitor_menu.append (primary_item);

                for (int i = 0; i < display.get_n_monitors (); i++) {
                    var candidate = display.get_monitor (i);
                    if (candidate == null) {
                        continue;
                    }
                    string model = candidate.get_model () ?? "%d".printf (i);
                    var item = new Gtk.RadioMenuItem.with_label (
                        monitor_group, model);
                    monitor_group = item.get_group ();
                    item.set_active (config.monitor == model);
                    item.activate.connect (() => {
                        if (item.get_active () && config.monitor != model) {
                            config.monitor = model;
                            config.save ();
                            place ();
                        }
                    });
                    monitor_menu.append (item);
                }
                monitor_item.set_submenu (monitor_menu);
                menu.append (monitor_item);
            }

            /* Auto-hide */
            var autohide_item = new Gtk.CheckMenuItem.with_label (
                _("Auto-hide"));
            autohide_item.set_active (config.autohide);
            autohide_item.toggled.connect (() => {
                config.autohide = autohide_item.get_active ();
                config.save ();
                place ();   /* restore / remove the strip */
                if (config.autohide) {
                    schedule_hide ();
                }
            });
            menu.append (autohide_item);

            menu.append (new Gtk.SeparatorMenuItem ());

            /* Shortcuts. If the target app is not installed yet the
             * item stays greyed out — kavis-settings arrives in Grup F,
             * kavis-tools in madde 7. */
            menu.append (launcher_item (N_("Display settings"),
                "kavis-settings", { "kavis-settings", "display" }));
            menu.append (launcher_item (N_("Task Manager"),
                "kavis-tools", { "kavis-tools", "tasks" }));

            /* Leak guard: the menu is destroyed on close (via Idle,

             * because activation runs AFTER deactivate). */

            menu.deactivate.connect (() => {

                Idle.add (() => {

                    menu.destroy ();

                    return Source.REMOVE;

                });

            });

            menu.show_all ();

            menu.popup_at_pointer (event);
        }

        private Gtk.MenuItem launcher_item (string key, string program,
                                            string[] argv) {
            var item = new Gtk.MenuItem.with_label (_(key));
            if (Environment.find_program_in_path (program) == null) {
                item.set_sensitive (false);
                return item;
            }
            string[] command = argv;
            item.activate.connect (() => {
                try {
                    Process.spawn_async (null, command, null,
                        SpawnFlags.SEARCH_PATH, null, null);
                } catch (Error e) {
                    warning ("kavis-panel: could not launch %s: %s",
                             program, e.message);
                }
            });
            return item;
        }

        /* On a position/size change the panel restarts itself: the
         * lightest and most robust way, rather than rotating every
         * widget live — the panel is stateless and starts instantly.
         * exec replaces the process image in place; the X connection
         * is CLOEXEC, so the old windows drop off the server. */
        private void restart_self () {
            config.save ();
            string[] argv = { "kavis-panel" };
            /* Resolve the real path: exec'ing via /proc/self/exe makes
             * the process name (comm) "exe", and pgrep/pkill -x
             * kavis-panel (CI, single-instance checks) cannot see the
             * panel (B6 test). */
            string exe = "/proc/self/exe";
            try {
                exe = FileUtils.read_link ("/proc/self/exe");
            } catch (FileError e) { }
            Posix.execv (exe, argv);
            /* If exec returned it failed — do not end up panel-less. */
            warning ("kavis-panel: could not restart, the setting applies at next start");
        }

        /* --- auto-hide (madde 5) -------------------------------------- */

        private void reveal_panel () {
            if (hide_timer != 0) {
                Source.remove (hide_timer);
                hide_timer = 0;
            }
            if (panel_hidden) {
                place ();
            }
        }

        private void schedule_hide () {
            if (!config.autohide) {
                return;
            }
            if (hide_timer != 0) {
                Source.remove (hide_timer);
            }
            hide_timer = Timeout.add (600, () => {
                hide_timer = 0;
                /* Hiding while a popup/menu is open would leave them
                 * without a root. */
                if (PanelPopup.any_open () || start_menu.get_visible ()) {
                    schedule_hide ();
                    return Source.REMOVE;
                }
                slide_away ();
                return Source.REMOVE;
            });
        }

        /* Slides to the edge, leaving a 2 px detection strip. */
        private void slide_away () {
            if (panel_hidden || !config.autohide) {
                return;
            }
            Gdk.Rectangle area = pick_monitor ().get_geometry ();
            switch (config.position) {
            case PanelConfig.Position.TOP:
                move (area.x, area.y - thickness + 2);
                break;
            case PanelConfig.Position.LEFT:
                move (area.x - thickness + 2, area.y);
                break;
            case PanelConfig.Position.RIGHT:
                move (area.x + area.width - 2, area.y);
                break;
            default:
                move (area.x, area.y + area.height - 2);
                break;
            }
            panel_hidden = true;
        }

        private void on_active_changed () {
            sync_slot_states ();
        }
    }
}
