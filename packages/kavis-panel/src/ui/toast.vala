/* Notification toasts (UI layer) — madde 37.
 *
 * Each toast is its OWN window (dunst lesson: rows painted into a
 * shared surface misfire on click targeting). Stacked from the
 * bottom-right corner of the monitor WORK AREA — the work area already
 * excludes the panel strut, so every panel position (madde 5) is
 * handled for free. Critical toasts stay until clicked; the rest
 * auto-close. Clicking a toast dismisses it.
 */

namespace Kavis.Ui {

    public class ToastManager : Object {

        private const int MAX_VISIBLE = 4;
        private const int MARGIN = 12;
        private const int SPACING = 8;

        private GenericArray<Toast> toasts = new GenericArray<Toast> ();

        public ToastManager (NotificationServer server) {
            server.toast_requested.connect ((entry, timeout_ms) => {
                show_toast (entry, timeout_ms);
            });
        }

        private void show_toast (NotificationEntry entry, int timeout_ms) {
            /* Aynı id'nin tazelenmesi: eski pencereyi kapat. */
            for (int i = 0; i < toasts.length; i++) {
                if (toasts[i].entry_id == entry.id) {
                    toasts[i].close_toast ();
                    break;
                }
            }
            while (toasts.length >= MAX_VISIBLE) {
                toasts[toasts.length - 1].close_toast ();
            }

            var toast = new Toast (entry, timeout_ms);
            toast.gone.connect (() => {
                for (int i = 0; i < toasts.length; i++) {
                    if (toasts[i] == toast) {
                        toasts.remove_index (i);
                        break;
                    }
                }
                reposition ();
            });
            toasts.insert (0, toast);
            toast.show_all ();
            reposition ();
        }

        /* Position is recomputed on EVERY change (dunst lesson: a
         * cached position goes stale when monitors turn off/on). */
        private void reposition () {
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor ();
            if (monitor == null) {
                monitor = display.get_monitor (0);
            }
            Gdk.Rectangle area = monitor.get_workarea ();
            int y = area.y + area.height - MARGIN;
            for (int i = 0; i < toasts.length; i++) {
                Gtk.Requisition natural;
                toasts[i].get_preferred_size (null, out natural);
                y -= natural.height;
                toasts[i].move (
                    area.x + area.width - natural.width - MARGIN, y);
                y -= SPACING;
            }
        }
    }

    private class Toast : Gtk.Window {

        public uint32 entry_id;
        public signal void gone ();

        private uint timer = 0;

        public Toast (NotificationEntry entry, int timeout_ms) {
            Object (type: Gtk.WindowType.POPUP);
            set_type_hint (Gdk.WindowTypeHint.NOTIFICATION);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            entry_id = entry.id;

            /* Görsel dil popup'larla aynı (.kavis-popup CSS'i panel
             * açılışında yüklenmiş oluyor — göstergeler popup'larını
             * kurarken). */
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.get_style_context ().add_class ("kavis-popup");
            box.set_border_width (12);
            add (box);
            set_size_request (340, -1);

            string icon_name = (entry.app_icon != null
                                && entry.app_icon != ""
                                && !("/" in entry.app_icon))
                ? entry.app_icon : "dialog-information-symbolic";
            var icon = new Gtk.Image.from_icon_name (
                icon_name, Gtk.IconSize.DND);
            icon.set_valign (Gtk.Align.START);
            box.pack_start (icon, false, false, 0);

            var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            var summary = new Gtk.Label (null);
            summary.set_markup ("<b>%s</b>".printf (
                Markup.escape_text (entry.summary)));
            summary.set_xalign (0);
            summary.set_ellipsize (Pango.EllipsizeMode.END);
            summary.set_max_width_chars (36);
            text.pack_start (summary, false, false, 0);
            if (entry.body != "") {
                var body = new Gtk.Label (entry.body);
                body.get_style_context ().add_class ("dim");
                body.set_xalign (0);
                body.set_line_wrap (true);
                body.set_lines (3);
                body.set_ellipsize (Pango.EllipsizeMode.END);
                body.set_max_width_chars (36);
                text.pack_start (body, false, false, 0);
            }
            box.pack_start (text, true, true, 0);

            button_press_event.connect (() => {
                close_toast ();
                return true;
            });

            if (timeout_ms > 0) {
                timer = Timeout.add (timeout_ms, () => {
                    timer = 0;
                    close_toast ();
                    return Source.REMOVE;
                });
            }
        }

        public void close_toast () {
            if (timer != 0) {
                Source.remove (timer);
                timer = 0;
            }
            hide ();
            gone ();
            destroy ();
        }
    }
}
