/* Volume OSD — madde 7 (UI layer).
 *
 * Media keys go openbox → gdbus → org.kavis.Panel → here. A small
 * pill near the bottom center shows icon + level bar + percent for a
 * moment. Reuses the .kavis-popup look; no grabs, no input — it is
 * pure display and never steals focus.
 */

namespace Kavis.Ui {

    public class VolumeOsd : Gtk.Window {

        private const int HIDE_MS = 1200;

        private Gtk.Image icon;
        private Gtk.LevelBar bar;
        private Gtk.Label percent_label;
        private uint hide_timer = 0;

        public VolumeOsd () {
            Object (type: Gtk.WindowType.POPUP);
            set_type_hint (Gdk.WindowTypeHint.NOTIFICATION);
            set_accept_focus (false);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_app_paintable (true);
            var gdk_screen = get_screen ();
            var rgba = gdk_screen.get_rgba_visual ();
            if (rgba != null && gdk_screen.is_composited ()) {
                set_visual (rgba);
            }

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.get_style_context ().add_class ("kavis-popup");
            box.set_border_width (14);
            add (box);

            icon = new Gtk.Image.from_icon_name (
                "audio-volume-high-symbolic", Gtk.IconSize.DND);
            box.pack_start (icon, false, false, 0);
            bar = new Gtk.LevelBar.for_interval (0, 100);
            bar.set_size_request (180, 6);
            bar.set_valign (Gtk.Align.CENTER);
            box.pack_start (bar, true, true, 0);
            percent_label = new Gtk.Label ("");
            percent_label.set_width_chars (5);
            box.pack_start (percent_label, false, false, 0);
        }

        public void show_level (int percent, bool muted) {
            icon.set_from_icon_name (VolumePopup.icon_for (percent, muted),
                                     Gtk.IconSize.DND);
            bar.set_value (muted ? 0 : percent.clamp (0, 100));
            unowned string fmt = Strings.is_turkish () ? "%%%d" : "%d%%";
            percent_label.set_text (muted ? "—" : fmt.printf (percent));

            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor ();
            if (monitor == null) {
                monitor = display.get_monitor (0);
            }
            Gdk.Rectangle area = monitor.get_workarea ();
            show_all ();
            Gtk.Requisition natural;
            get_preferred_size (null, out natural);
            move (area.x + (area.width - natural.width) / 2,
                  area.y + area.height - natural.height - 48);

            if (hide_timer != 0) {
                Source.remove (hide_timer);
            }
            hide_timer = Timeout.add (HIDE_MS, () => {
                hide_timer = 0;
                hide ();
                return Source.REMOVE;
            });
        }
    }
}
