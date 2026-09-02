/* Clipboard history popup (Win+V) — madde 7 (UI layer).
 *
 * Opens centered on the primary monitor (it is summoned by a keyboard
 * shortcut, not by clicking an indicator, so there is no anchor).
 * Rows: pinned first, then history; clicking a row puts the text on
 * the clipboard, closes the popup and — when xdotool is installed —
 * presses Ctrl+V into the still-focused window ("tıkla-yapıştır").
 * Close behavior follows the madde 60 rule set.
 */

namespace Kavis.Ui {

    public class ClipboardPopup : Gtk.Window {

        private const int WIDTH = 380;
        private const int HEIGHT = 420;

        private ClipboardHistory history;
        private Gtk.Box list_box;
        private bool gtk_grabbed = false;

        public ClipboardPopup (ClipboardHistory history) {
            Object (type: Gtk.WindowType.POPUP);
            this.history = history;
            set_type_hint (Gdk.WindowTypeHint.POPUP_MENU);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_app_paintable (true);
            var gdk_screen = get_screen ();
            var rgba = gdk_screen.get_rgba_visual ();
            if (rgba != null && gdk_screen.is_composited ()) {
                set_visual (rgba);
            }

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            content.get_style_context ().add_class ("kavis-popup");
            content.set_border_width (12);
            add (content);
            set_size_request (WIDTH, HEIGHT);

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var title = new Gtk.Label (_("Clipboard history"));
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            header.pack_start (title, true, true, 0);
            var clear_button = new Gtk.Button.with_label (
                _("Clear all"));
            clear_button.set_relief (Gtk.ReliefStyle.NONE);
            clear_button.clicked.connect (() => history.clear ());
            header.pack_end (clear_button, false, false, 0);
            content.pack_start (header, false, false, 0);

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_policy (Gtk.PolicyType.NEVER,
                               Gtk.PolicyType.AUTOMATIC);
            list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            scroll.add (list_box);
            content.pack_start (scroll, true, true, 0);

            history.changed.connect (() => {
                if (get_visible ()) {
                    rebuild ();
                }
            });

            button_press_event.connect ((event) => {
                if (PanelPopup.press_outside (this, event)) {
                    dismiss ();
                    return true;
                }
                return false;
            });
            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    dismiss ();
                    return true;
                }
                return false;
            });
        }

        public void toggle () {
            if (get_visible ()) {
                dismiss ();
            } else {
                open ();
            }
        }

        public void open () {
            PanelPopup.dismiss_open ();
            rebuild ();
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor ();
            if (monitor == null) {
                monitor = display.get_monitor (0);
            }
            Gdk.Rectangle area = monitor.get_workarea ();
            move (area.x + (area.width - WIDTH) / 2,
                  area.y + (area.height - HEIGHT) / 2);
            show_all ();
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
        }

        private void rebuild () {
            foreach (var child in list_box.get_children ()) {
                list_box.remove (child);
            }
            if (history.pinned.length == 0 && history.items.length == 0) {
                var empty = new Gtk.Label (_("Clipboard history is empty"));
                empty.get_style_context ().add_class ("dim");
                empty.set_margin_top (32);
                list_box.pack_start (empty, false, false, 0);
                list_box.show_all ();
                return;
            }
            for (int i = 0; i < history.pinned.length; i++) {
                list_box.pack_start (row (history.pinned[i], true),
                                     false, false, 0);
            }
            for (int i = 0; i < history.items.length; i++) {
                if (history.is_pinned (history.items[i])) {
                    continue;   /* sabitli kopya zaten üstte */
                }
                list_box.pack_start (row (history.items[i], false),
                                     false, false, 0);
            }
            list_box.show_all ();
        }

        private Gtk.Widget row (string text, bool pinned) {
            var line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            var label = new Gtk.Label (first_line (text));
            label.set_xalign (0);
            label.set_ellipsize (Pango.EllipsizeMode.END);
            label.set_max_width_chars (34);
            button.add (label);
            button.set_tooltip_text (text.length > 400
                                     ? text.substring (0, 400) : text);
            button.clicked.connect (() => {
                history.activate_item (text);
                dismiss ();
                paste_into_focused ();
            });
            line.pack_start (button, true, true, 0);

            var pin = new Gtk.Button.from_icon_name (
                "view-pin-symbolic", Gtk.IconSize.BUTTON);
            pin.set_relief (Gtk.ReliefStyle.NONE);
            pin.set_tooltip_text (_(
                pinned ? N_("Unpin") : N_("Pin")));
            if (pinned) {
                pin.get_style_context ().add_class ("quick-tile");
                pin.get_style_context ().add_class ("on");
            }
            pin.clicked.connect (() => history.toggle_pin (text));
            line.pack_end (pin, false, false, 0);

            return line;
        }

        private static string first_line (string text) {
            int newline = text.index_of_char ('\n');
            string line = (newline >= 0)
                ? text.substring (0, newline) : text;
            return line.strip ();
        }

        /* Popup kapandıktan sonra odak eski penceresinde (POPUP hiç WM
         * odağı almadı); Ctrl+V oraya gider. xdotool yoksa içerik yine
         * panoda — kullanıcı kendi yapıştırır. */
        private void paste_into_focused () {
            if (Environment.find_program_in_path ("xdotool") == null) {
                return;
            }
            Timeout.add (200, () => {
                try {
                    Process.spawn_async (null,
                        { "xdotool", "key", "--clearmodifiers", "ctrl+v" },
                        null, SpawnFlags.SEARCH_PATH, null, null);
                } catch (Error e) {
                    warning ("kavis-panel: yapistirma gonderilemedi: %s",
                             e.message);
                }
                return Source.REMOVE;
            });
        }
    }
}
