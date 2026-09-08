/* Taskbar window previews (feedback, 8 Sep 2026).
 *
 * An application with three windows open used to be one taskbar button
 * whose clicks cycled through them in an order nobody could see. This
 * is what Windows does instead: hover the button and the windows appear
 * as small cards; hover a card and that window is brought to the front
 * as if it were already there; move away and everything goes back;
 * click and it stays.
 *
 * THE PEEK IS REVERSIBLE, which is the whole point and the only hard
 * part. Peeking must not change what the session looks like once the
 * pointer has moved on, so the previously active window is remembered
 * and re-raised, and a window that was minimised is minimised again.
 * A peek that leaves the stacking order rearranged is worse than no
 * peek, because the person did not ask for anything to move.
 *
 * The thumbnail is the window's own pixels when they can be read (with
 * a compositor running they usually can, even for a window that is
 * covered) and the application icon when they cannot. A card that is
 * honestly an icon is better than a grey rectangle pretending to be a
 * picture of something.
 *
 * This is NOT a PanelPopup: that base takes a seat grab, which is
 * right for a menu and wrong for something driven by hovering. It
 * borrows the same CSS names so it looks like the rest.
 */

namespace Kavis.Ui {

    public class WindowPreviews : Gtk.Window {

        /* Big enough to recognise a window, small enough that four of
         * them fit on a 1280-wide screen. */
        private const int THUMB_W = 200;
        private const int THUMB_H = 120;
        private const int GAP = 8;
        /* Grace period before closing: moving the pointer from the
         * button to the popup crosses a few pixels of nothing. */
        private const int CLOSE_DELAY_MS = 220;

        private static WindowPreviews? open_previews = null;

        private Gtk.Box cards;
        private Gtk.Widget? anchor = null;
        private uint close_timer = 0;
        private uint watch_timer = 0;
        private bool pointer_inside = false;
        /* The button the previews belong to: while they are open the
         * pointer being over EITHER of the two keeps them open. */
        private Gtk.Widget? owner_button = null;

        /* Peek state, so leaving puts everything back exactly. */
        private unowned Wnck.Window? peeked = null;
        private unowned Wnck.Window? was_active = null;
        private bool was_minimised = false;

        private const string CSS = """
        .kavis-previews {
          background-color: @kavis_surface;
          border: 1px solid @kavis_border;
          border-radius: 12px;
          box-shadow: inset 0 1px 0 @kavis_top_edge,
                      0 8px 24px rgba(0, 0, 0, 0.35);
          padding: 8px;
        }
        .kavis-preview-card {
          border-radius: 8px;
          padding: 6px;
        }
        .kavis-preview-card:hover {
          background-color: @kavis_overlay_hover;
        }
        .kavis-preview-title {
          font-size: 12px;
          color: @kavis_text;
        }
        .kavis-preview-thumb {
          border: 1px solid @kavis_border;
          border-radius: 6px;
          background-color: @kavis_ground;
        }
        """;

        public WindowPreviews () {
            Object (type: Gtk.WindowType.POPUP);
            set_accept_focus (false);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_app_paintable (true);

            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-panel: preview css: %s", e.message);
            }
            get_style_context ().add_class ("kavis-previews");

            cards = new Gtk.Box (Gtk.Orientation.HORIZONTAL, GAP);
            add (cards);

            add_events (Gdk.EventMask.ENTER_NOTIFY_MASK
                        | Gdk.EventMask.LEAVE_NOTIFY_MASK);
            enter_notify_event.connect (() => {
                pointer_inside = true;
                cancel_close ();
                return false;
            });
            leave_notify_event.connect ((event) => {
                /* Crossing into a child is a leave event on the window
                 * too; only a real exit counts. */
                if (event.detail == Gdk.NotifyType.INFERIOR) {
                    return false;
                }
                pointer_inside = false;
                schedule_close ();
                return false;
            });
        }

        /* --- opening and closing ------------------------------------ */

        public static void hide_open () {
            if (open_previews != null) {
                open_previews.close_now ();
            }
        }

        public void show_for (Gtk.Widget button,
                              GenericArray<unowned Wnck.Window> windows,
                              PanelConfig.Position position) {
            if (windows.length == 0) {
                return;
            }
            if (open_previews != null && open_previews != this) {
                open_previews.close_now ();
            }
            anchor = button;
            cancel_close ();
            foreach (var child in cards.get_children ()) {
                cards.remove (child);
            }
            for (int i = 0; i < windows.length; i++) {
                cards.pack_start (card (windows[i]), false, false, 0);
            }
            show_all ();
            place (button, position);
            owner_button = button;
            open_previews = this;
            start_watching ();
        }

        /* WHY A POLL AND NOT JUST CROSSING EVENTS. An override-redirect
         * window gets enter and leave events, but only when the pointer
         * actually travels; a pointer that is warped — by xdotool, by
         * an application moving it, by a grab ending somewhere else —
         * can leave the button without either window hearing about it.
         * The previews then stay on screen over everything, which is
         * how the v0.5-test5 run failed six later steps in five
         * different scenarios: a synthetic click landed on a taskbar
         * button, the previews opened four hundred milliseconds later,
         * and nothing ever told them to close.
         *
         * So the pointer is asked where it is. Twice a second costs one
         * XQueryPointer round trip and is the difference between a
         * feature and a window nobody can get rid of. */
        private void start_watching () {
            stop_watching ();
            watch_timer = Timeout.add (500, () => {
                if (!get_visible ()) {
                    watch_timer = 0;
                    return false;
                }
                if (!pointer_over_previews_or_button ()) {
                    close_now ();
                    watch_timer = 0;
                    return false;
                }
                return true;
            });
        }

        private void stop_watching () {
            if (watch_timer != 0) {
                Source.remove (watch_timer);
                watch_timer = 0;
            }
        }

        private bool pointer_over_previews_or_button () {
            var seat = Gdk.Display.get_default ().get_default_seat ();
            int px, py;
            seat.get_pointer ().get_position (null, out px, out py);
            return contains (get_window (), null, px, py)
                || (owner_button != null
                    && contains (owner_button.get_window (), owner_button,
                                 px, py));
        }

        /* Root-coordinate hit test. The widget is passed as well as its
         * GdkWindow because a button shares its parent's window and its
         * own rectangle is an allocation inside it. */
        private bool contains (Gdk.Window? window, Gtk.Widget? widget,
                               int px, int py) {
            if (window == null) {
                return false;
            }
            int ox, oy;
            window.get_origin (out ox, out oy);
            int w, h;
            if (widget != null) {
                Gtk.Allocation alloc;
                widget.get_allocation (out alloc);
                ox += alloc.x;
                oy += alloc.y;
                w = alloc.width;
                h = alloc.height;
            } else {
                w = window.get_width ();
                h = window.get_height ();
            }
            return px >= ox && px < ox + w && py >= oy && py < oy + h;
        }

        public void schedule_close () {
            cancel_close ();
            close_timer = Timeout.add (CLOSE_DELAY_MS, () => {
                close_timer = 0;
                if (!pointer_inside) {
                    close_now ();
                }
                return false;
            });
        }

        public void cancel_close () {
            if (close_timer != 0) {
                Source.remove (close_timer);
                close_timer = 0;
            }
        }

        private void close_now () {
            cancel_close ();
            stop_watching ();
            unpeek ();
            hide ();
            if (open_previews == this) {
                open_previews = null;
            }
        }

        /* Above the button, clamped to the monitor — the same geometry
         * rule the indicator popups use, without their grab. */
        private void place (Gtk.Widget button, PanelConfig.Position position) {
            var window = button.get_window ();
            if (window == null) {
                return;
            }
            int origin_x, origin_y;
            window.get_origin (out origin_x, out origin_y);
            Gtk.Allocation alloc;
            button.get_allocation (out alloc);
            origin_x += alloc.x;
            origin_y += alloc.y;

            Gtk.Requisition natural;
            get_preferred_size (null, out natural);

            var display = Gdk.Display.get_default ();
            var monitor = display.get_monitor_at_point (origin_x, origin_y);
            Gdk.Rectangle area = monitor.get_workarea ();

            int x, y;
            switch (position) {
            case PanelConfig.Position.TOP:
                x = origin_x + alloc.width / 2 - natural.width / 2;
                y = origin_y + alloc.height + GAP;
                break;
            case PanelConfig.Position.LEFT:
                x = origin_x + alloc.width + GAP;
                y = origin_y + alloc.height / 2 - natural.height / 2;
                break;
            case PanelConfig.Position.RIGHT:
                x = origin_x - GAP - natural.width;
                y = origin_y + alloc.height / 2 - natural.height / 2;
                break;
            default:
                x = origin_x + alloc.width / 2 - natural.width / 2;
                y = origin_y - GAP - natural.height;
                break;
            }
            x = int.max (area.x + GAP,
                         int.min (x, area.x + area.width - natural.width - GAP));
            y = int.max (area.y + GAP,
                         int.min (y, area.y + area.height - natural.height - GAP));
            move (x, y);
        }

        /* --- one card ----------------------------------------------- */

        private Gtk.Widget card (Wnck.Window window) {
            unowned Wnck.Window target = window;
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            box.get_style_context ().add_class ("kavis-preview-card");

            var head = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var icon = new Gtk.Image.from_pixbuf (window.get_mini_icon ());
            head.pack_start (icon, false, false, 0);
            var title = new Gtk.Label (window.get_name () ?? "");
            title.set_ellipsize (Pango.EllipsizeMode.END);
            title.set_max_width_chars (22);
            title.set_xalign (0);
            title.get_style_context ().add_class ("kavis-preview-title");
            head.pack_start (title, true, true, 0);
            var close = new Gtk.Button.from_icon_name (
                "window-close-symbolic", Gtk.IconSize.MENU);
            close.set_relief (Gtk.ReliefStyle.NONE);
            close.set_tooltip_text (_("Close this window"));
            close.clicked.connect (() => {
                /* Closing the window we are peeking at must not leave
                 * the peek state pointing at something that is gone. */
                if (peeked == target) {
                    peeked = null;
                }
                target.close (Gtk.get_current_event_time ());
                close_now ();
            });
            head.pack_end (close, false, false, 0);
            box.pack_start (head, false, false, 0);

            var thumb = new Gtk.Image.from_pixbuf (thumbnail (window));
            thumb.get_style_context ().add_class ("kavis-preview-thumb");
            box.pack_start (thumb, false, false, 0);

            /* An EventBox so the whole card reacts, not just the label. */
            var events = new Gtk.EventBox ();
            events.add (box);
            events.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK
                               | Gdk.EventMask.LEAVE_NOTIFY_MASK
                               | Gdk.EventMask.BUTTON_PRESS_MASK);
            events.enter_notify_event.connect (() => {
                peek (target);
                return false;
            });
            events.leave_notify_event.connect ((event) => {
                if (event.detail != Gdk.NotifyType.INFERIOR) {
                    unpeek ();
                }
                return false;
            });
            events.button_press_event.connect (() => {
                uint32 timestamp = Gtk.get_current_event_time ();
                /* Chosen deliberately: this one stays where the peek
                 * put it, so nothing is restored on the way out. */
                peeked = null;
                target.unminimize (timestamp);
                target.activate (timestamp);
                close_now ();
                return true;
            });
            return events;
        }

        /* The window's own pixels if they can be read, the application
         * icon if they cannot. With a compositor running even a covered
         * window has a backing pixmap to read; without one, a window
         * behind another reads back as whatever is in front of it, so
         * the icon is the honest answer. */
        private Gdk.Pixbuf? thumbnail (Wnck.Window window) {
            int x, y, w, h;
            window.get_client_window_geometry (out x, out y, out w, out h);
            if (w > 0 && h > 0 && !window.is_minimized ()) {
                var display = (Gdk.X11.Display) Gdk.Display.get_default ();
                Gdk.error_trap_push ();
                var gwin = new Gdk.X11.Window.foreign_for_display (
                    display, (X.Window) window.get_xid ());
                Gdk.Pixbuf? shot = null;
                if (gwin != null) {
                    shot = Gdk.pixbuf_get_from_window (gwin, 0, 0, w, h);
                }
                Gdk.error_trap_pop_ignored ();
                if (shot != null) {
                    return scale_into (shot);
                }
            }
            var icon = window.get_icon ();
            return (icon != null) ? centred_icon (icon) : null;
        }

        /* Fit inside the card without distorting the aspect ratio. */
        private Gdk.Pixbuf scale_into (Gdk.Pixbuf source) {
            double scale = double.min (
                (double) THUMB_W / source.get_width (),
                (double) THUMB_H / source.get_height ());
            int w = int.max (1, (int) (source.get_width () * scale));
            int h = int.max (1, (int) (source.get_height () * scale));
            return source.scale_simple (w, h, Gdk.InterpType.BILINEAR);
        }

        /* An icon in the middle of a card-sized transparent area, so a
         * row of cards keeps one height whatever is in them. */
        private Gdk.Pixbuf centred_icon (Gdk.Pixbuf icon) {
            var canvas = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8,
                                         THUMB_W, THUMB_H);
            canvas.fill (0x00000000);
            int size = int.min (64, int.min (icon.get_width (),
                                             icon.get_height ()));
            var scaled = icon.scale_simple (size, size,
                                            Gdk.InterpType.BILINEAR);
            scaled.copy_area (0, 0, size, size, canvas,
                              (THUMB_W - size) / 2, (THUMB_H - size) / 2);
            return canvas;
        }

        /* --- peek --------------------------------------------------- */

        private void peek (Wnck.Window window) {
            if (peeked == window) {
                return;
            }
            unpeek ();
            unowned Wnck.Screen screen = Wnck.Screen.get_default ();
            was_active = screen.get_active_window ();
            was_minimised = window.is_minimized ();
            peeked = window;
            uint32 timestamp = Gtk.get_current_event_time ();
            if (was_minimised) {
                window.unminimize (timestamp);
            }
            raise_only (window);
        }

        private void unpeek () {
            if (peeked == null) {
                was_active = null;
                return;
            }
            unowned Wnck.Window window = peeked;
            peeked = null;
            if (was_minimised) {
                window.minimize ();
            } else if (was_active != null && was_active != window) {
                raise_only (was_active);
            }
            was_active = null;
            was_minimised = false;
        }

        /* Raise WITHOUT focus. wnck's activate() focuses, which would
         * make a peek a real switch — the pointer is only passing
         * over. */
        private void raise_only (Wnck.Window window) {
            var display = (Gdk.X11.Display) Gdk.Display.get_default ();
            unowned X.Display xd = display.get_xdisplay ();
            Gdk.error_trap_push ();
            xd.raise_window ((X.Window) window.get_xid ());
            xd.flush ();
            Gdk.error_trap_pop_ignored ();
        }
    }
}
