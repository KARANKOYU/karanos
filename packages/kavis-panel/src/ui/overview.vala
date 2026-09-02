/* Overview (Win+Tab) — madde 55 (UI layer).
 *
 * Every virtual desktop as a card on one screen: click a window to go
 * to it, drag a window row onto another card to move it there, click a
 * card's header to switch desktops. Live thumbnails are deliberately
 * NOT drawn — XComposite pixmap scraping is a lot of machinery for a
 * cosmetic gain; icon + title rows carry the same information (lightest
 * solution rule). Opens via org.kavis.Panel.ShowOverview (openbox
 * keybind) or programmatically; Escape / outside click closes — the
 * same grab pair as the other panel surfaces (madde 60).
 */

namespace Kavis.Ui {

    public class Overview : Gtk.Window {

        private const string CSS = """
        .kavis-overview {
          background-color: rgba(13, 20, 27, 0.92);
          padding: 48px;
        }
        .kavis-overview .desktop-card {
          background-color: #17222C;
          border: 1px solid #233A45;
          border-radius: 10px;
          padding: 10px;
        }
        .kavis-overview .desktop-card.current {
          border-color: #2DD4BF;
        }
        .kavis-overview label {
          color: #E6EDF3;
        }
        .kavis-overview label.dim {
          color: #8B9BA8;
        }
        .kavis-overview button {
          background-image: none;
          background-color: transparent;
          border: none;
          border-radius: 6px;
          color: #E6EDF3;
          padding: 6px 8px;
          transition: background-color 180ms ease;
        }
        .kavis-overview button:hover {
          background-color: #1D2C38;
        }
        """;

        private unowned Wnck.Screen screen;
        private Gtk.Box cards_box;
        private bool gtk_grabbed = false;
        private static bool css_loaded = false;

        private const Gtk.TargetEntry[] DND_TARGETS = {
            { "application/x-kavis-window", Gtk.TargetFlags.SAME_APP, 0 }
        };

        public Overview (Wnck.Screen screen) {
            Object (type: Gtk.WindowType.POPUP);
            this.screen = screen;
            set_type_hint (Gdk.WindowTypeHint.POPUP_MENU);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_app_paintable (true);
            var gdk_screen = get_screen ();
            var rgba = gdk_screen.get_rgba_visual ();
            if (rgba != null) {
                set_visual (rgba);
            }
            load_css ();

            /* Karartma sınıfı pencereye değil kutuya: app_paintable
             * pencere CSS arka planını çizmez (PanelPopup deseni). */
            var outer = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            outer.get_style_context ().add_class ("kavis-overview");
            add (outer);
            cards_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
            cards_box.set_homogeneous (true);
            cards_box.set_valign (Gtk.Align.CENTER);
            outer.pack_start (cards_box, true, true, 0);

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
                warning ("kavis-panel: overview CSS yuklenemedi: %s",
                         e.message);
            }
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
            Gdk.Rectangle area = monitor.get_geometry ();
            set_size_request (area.width, area.height);
            resize (area.width, area.height);
            move (area.x, area.y);
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
            foreach (var child in cards_box.get_children ()) {
                cards_box.remove (child);
            }
            unowned Wnck.Workspace? active = screen.get_active_workspace ();
            foreach (unowned Wnck.Workspace workspace in
                     screen.get_workspaces ()) {
                cards_box.pack_start (
                    desktop_card (workspace, workspace == active),
                    true, true, 0);
            }
            cards_box.show_all ();
        }

        private Gtk.Widget desktop_card (Wnck.Workspace workspace,
                                         bool current) {
            var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            card.get_style_context ().add_class ("desktop-card");
            if (current) {
                card.get_style_context ().add_class ("current");
            }

            unowned Wnck.Workspace target = workspace;

            var header = new Gtk.Button.with_label (
                _("Desktop %d").printf (
                    workspace.get_number () + 1));
            header.set_relief (Gtk.ReliefStyle.NONE);
            header.clicked.connect (() => {
                target.activate (Gtk.get_current_event_time ());
                dismiss ();
            });
            card.pack_start (header, false, false, 0);

            int rows = 0;
            foreach (unowned Wnck.Window window in screen.get_windows ()) {
                if (window.is_skip_tasklist ()
                    || !window.is_on_workspace (workspace)) {
                    continue;
                }
                card.pack_start (window_row (window), false, false, 0);
                rows++;
            }
            if (rows == 0) {
                var empty = new Gtk.Label ("—");
                empty.get_style_context ().add_class ("dim");
                card.pack_start (empty, false, false, 12);
            }

            /* Kart, pencere satırlarının bırakma hedefi: sürüklenen
             * pencere bu masaüstüne taşınır. */
            Gtk.drag_dest_set (card, Gtk.DestDefaults.ALL, DND_TARGETS,
                               Gdk.DragAction.MOVE);
            card.drag_data_received.connect (
                (ctx, x, y, data, info, time) => {
                    /* Yük NUL ile bitirilerek gönderiliyor (aşağıda);
                     * string'e çevirmek bu yüzden güvenli. */
                    ulong xid = (ulong) uint64.parse (
                        (string) data.get_data ());
                    foreach (unowned Wnck.Window window in
                             screen.get_windows ()) {
                        if (window.get_xid () == xid) {
                            window.move_to_workspace (target);
                            break;
                        }
                    }
                    Gtk.drag_finish (ctx, true, false, time);
                    /* Kaynak satır hâlâ sürükleme içinde; listeyi
                     * olay bitince yeniden kur. */
                    Idle.add (() => {
                        if (get_visible ()) {
                            rebuild ();
                        }
                        return Source.REMOVE;
                    });
                });

            return card;
        }

        private Gtk.Widget window_row (Wnck.Window window) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var icon_pixbuf = window.get_mini_icon ();
            if (icon_pixbuf != null) {
                row.pack_start (new Gtk.Image.from_pixbuf (icon_pixbuf),
                                false, false, 0);
            }
            var title = new Gtk.Label (window.get_name () ?? "");
            title.set_xalign (0);
            title.set_ellipsize (Pango.EllipsizeMode.END);
            title.set_max_width_chars (24);
            row.pack_start (title, true, true, 0);
            button.add (row);

            unowned Wnck.Window target = window;
            button.clicked.connect (() => {
                uint32 timestamp = Gtk.get_current_event_time ();
                unowned Wnck.Workspace? workspace = target.get_workspace ();
                if (workspace != null) {
                    workspace.activate (timestamp);
                }
                target.unminimize (timestamp);
                target.activate (timestamp);
                dismiss ();
            });

            /* Satır sürükleme kaynağı: yük = pencerenin XID'i. */
            Gtk.drag_source_set (button, Gdk.ModifierType.BUTTON1_MASK,
                                 DND_TARGETS, Gdk.DragAction.MOVE);
            button.drag_data_get.connect ((ctx, data, info, time) => {
                string payload = "%lu".printf (target.get_xid ());
                data.set (data.get_target (), 8, (payload + "\0").data);
            });

            return button;
        }
    }
}
