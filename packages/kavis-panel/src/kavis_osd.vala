/* kavis-osd — volume / brightness / lock key / media OSD daemon
 * (sonraki-isler 6a). A SEPARATE process from the panel: even if the
 * panel crashes the volume keys keep working and feedback shows on
 * screen.
 *
 * Openbox keybindings call org.kavis.Osd through gdbus; this process
 * performs the volume/brightness change itself (amixer / brightnessctl,
 * logic/volume.vala + logic/quick.vala are compiled in shared), the
 * OSD only displays. NO keybinding for Caps/Num Lock: the Gdk.Keymap
 * state-changed signal is listened to (grabbing the key would race the
 * lock itself). Media keys go to the playing player through MPRIS.
 *
 * Visual: a small rounded box at the top center of the screen
 * (@kavis_surface ~90%), icon + teal fill bar + percentage; closes
 * after 1 s (the 150 ms fade comes from picom's general window
 * animation). On repeated presses the counter resets and the box stays
 * in place.
 *
 * ~/.config/kavis/kavis.conf [osd] enabled=false silences all of it
 * (Settings will edit it in Grup F).
 */

namespace Kavis.Osd {

    [DBus (name = "org.kavis.Osd")]
    public class OsdService : Object {

        [DBus (visible = false)]
        public signal void volume_shown ();
        [DBus (visible = false)]
        public signal void brightness_shown ();
        [DBus (visible = false)]
        public signal void media_shown (string op);

        public void volume_up () throws Error {
            adjust_volume (5);
        }

        public void volume_down () throws Error {
            adjust_volume (-5);
        }

        public void volume_mute () throws Error {
            Volume.toggle_mute ();
            settle (() => { volume_shown (); return Source.REMOVE; });
        }

        public void brightness_up () throws Error {
            adjust_brightness (5);
        }

        public void brightness_down () throws Error {
            adjust_brightness (-5);
        }

        /* 3C: the quick settings slider writes the value itself, the
         * OSD only displays it. */
        public void brightness_show () throws Error {
            brightness_shown ();
        }

        public void media (string op) throws Error {
            media_shown (op);
        }

        private void adjust_volume (int delta) {
            var state = Volume.read ();
            Volume.set_percent ((state.percent + delta).clamp (0, 100));
            settle (() => { volume_shown (); return Source.REMOVE; });
        }

        private void adjust_brightness (int delta) {
            /* 3C: without hardware the xrandr software mode kicks in —
             * the OSD now works on every machine. */
            int current = Quick.brightness_percent ();
            Quick.brightness_set ((current + delta).clamp (10, 100));
            settle (() => { brightness_shown (); return Source.REMOVE; });
        }

        /* amixer/brightnessctl are asynchronous; wait briefly, then
         * read the real value. */
        private void settle (owned SourceFunc after) {
            Timeout.add (120, () => {
                after ();
                return Source.REMOVE;
            });
        }
    }

    public class OsdWindow : Gtk.Window {

        private const int HIDE_MS = 1000;

        private const string CSS = """
        .kavis-osd {
          background-color: @kavis_surface_acrylic;
          border: 1px solid @kavis_border;
          border-radius: 12px;
          box-shadow: inset 0 1px 0 @kavis_top_edge,
                      0 8px 24px rgba(0, 0, 0, 0.35);   /* A4 */
        }
        .kavis-osd label {
          color: @kavis_text;
        }
        .kavis-osd levelbar block.filled {
          background-color: @kavis_teal;
          border-radius: 3px;
        }
        .kavis-osd levelbar block.empty {
          background-color: @kavis_border;
          border-radius: 3px;
        }
        .kavis-osd levelbar.dim block.filled {
          background-color: @kavis_text2;
        }
        """;

        private new Gtk.Image icon;
        private Gtk.LevelBar bar;
        private Gtk.Label text_label;
        private uint hide_timer = 0;

        public OsdWindow () {
            Object (type: Gtk.WindowType.POPUP);
            set_type_hint (Gdk.WindowTypeHint.NOTIFICATION);
            set_accept_focus (false);
            set_skip_taskbar_hint (true);
            set_app_paintable (true);
            var gdk_screen = get_screen ();
            var rgba = gdk_screen.get_rgba_visual ();
            if (rgba != null && gdk_screen.is_composited ()) {
                set_visual (rgba);
            }
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) { }

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            row.get_style_context ().add_class ("kavis-osd");
            row.set_border_width (14);
            add (row);

            icon = new Gtk.Image.from_icon_name (
                "audio-volume-high-symbolic", Gtk.IconSize.DND);
            row.pack_start (icon, false, false, 0);
            bar = new Gtk.LevelBar.for_interval (0, 100);
            bar.set_size_request (180, 6);
            bar.set_valign (Gtk.Align.CENTER);
            row.pack_start (bar, true, true, 0);
            text_label = new Gtk.Label ("");
            text_label.set_width_chars (5);
            row.pack_start (text_label, false, false, 0);
        }

        /* percent < 0: bar hidden, only icon + text (lock keys,
         * media). dim: bar faded while muted. */
        public void present_osd (string icon_name, int percent,
                                 string text, bool dim = false) {
            icon.set_from_icon_name (icon_name, Gtk.IconSize.DND);
            bar.set_visible (percent >= 0);
            bar.set_no_show_all (percent < 0);
            if (percent >= 0) {
                bar.set_value (percent.clamp (0, 100));
            }
            unowned Gtk.StyleContext context = bar.get_style_context ();
            if (dim) {
                context.add_class ("dim");
            } else {
                context.remove_class ("dim");
            }
            text_label.set_text (text);
            text_label.set_width_chars (
                (text.length > 6) ? -1 : 5);

            show_all ();
            bar.set_visible (percent >= 0);
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor ()
                ?? display.get_monitor (0);
            Gdk.Rectangle area = monitor.get_workarea ();
            Gtk.Requisition natural;
            get_preferred_size (null, out natural);
            /* Top center (6a): the volume OSD is now at the top, not bottom. */
            move (area.x + (area.width - natural.width) / 2,
                  area.y + 48);

            /* On repeated presses the counter resets, the box stays. */
            if (hide_timer != 0) {
                Source.remove (hide_timer);
            }
            hide_timer = Timeout.add (HIDE_MS, () => {
                hide_timer = 0;
                hide ();   /* the 150 ms fade comes from picom */
                return Source.REMOVE;
            });
        }
    }

    public class Daemon : Object {

        private OsdService service;
        private OsdWindow window = new OsdWindow ();
        private bool caps_state;
        private bool num_state;
        private bool enabled = true;
        private FileMonitor? config_monitor = null;

        public Daemon () {
            /* Kill switch (Settings Grup F): kavis.conf [osd]. */
            var file = Kavis.Config.load ();
            try {
                enabled = file.get_boolean ("osd", "enabled");
            } catch (Error e) { }
            /* Live setting (1A-2): when Settings flips the key it takes
             * effect without restarting the process. */
            config_monitor = Kavis.Config.watch (() => {
                var fresh = Kavis.Config.load ();
                try {
                    enabled = fresh.get_boolean ("osd", "enabled");
                } catch (Error e) {
                    enabled = true;
                }
            });

            service = new OsdService ();
            Bus.own_name (BusType.SESSION, "org.kavis.Osd",
                BusNameOwnerFlags.NONE,
                (connection) => {
                    try {
                        connection.register_object ("/org/kavis/Osd",
                                                    service);
                    } catch (IOError e) {
                        warning ("kavis-osd: could not register object: %s",
                                 e.message);
                    }
                },
                null,
                () => {
                    warning ("kavis-osd: could not acquire org.kavis.Osd — second instance?");
                });

            service.volume_shown.connect (show_volume);
            service.brightness_shown.connect (show_brightness);
            service.media_shown.connect (handle_media);

            /* Caps/Num: state tracking instead of a keybinding. */
            var keymap = Gdk.Keymap.get_for_display (
                Gdk.Display.get_default ());
            caps_state = keymap.get_caps_lock_state ();
            num_state = keymap.get_num_lock_state ();
            keymap.state_changed.connect (() => {
                bool caps = keymap.get_caps_lock_state ();
                bool num = keymap.get_num_lock_state ();
                if (caps != caps_state) {
                    caps_state = caps;
                    show_lock (caps
                        ? _("Caps Lock on") : _("Caps Lock off"));
                }
                if (num != num_state) {
                    num_state = num;
                    show_lock (num
                        ? _("Num Lock on") : _("Num Lock off"));
                }
            });
        }

        private void show_volume () {
            if (!enabled) {
                return;
            }
            var state = Volume.read ();
            window.present_osd (
                Volume.icon_name (state.percent, state.muted),
                state.muted ? 0 : state.percent,
                state.muted ? "—" : _("%d%%").printf (state.percent),
                state.muted);
        }

        private void show_brightness () {
            if (!enabled) {
                return;
            }
            int percent = Quick.brightness_percent ();
            if (percent < 0) {
                return;
            }
            window.present_osd ("display-brightness-symbolic",
                percent, _("%d%%").printf (percent));
        }

        private void show_lock (string text) {
            if (!enabled) {
                return;
            }
            window.present_osd ("input-keyboard-symbolic", -1, text);
        }

        /* Media keys → MPRIS: the command goes to the first registered
         * player; the OSD shows icon + track title (if any). */
        private void handle_media (string op) {
            try {
                var bus = Bus.get_sync (BusType.SESSION);
                var reply = bus.call_sync ("org.freedesktop.DBus",
                    "/org/freedesktop/DBus", "org.freedesktop.DBus",
                    "ListNames", null, new VariantType ("(as)"),
                    DBusCallFlags.NONE, -1, null);
                string[] names;
                reply.get ("(^as)", out names);
                string? player = null;
                foreach (unowned string name in names) {
                    if (name.has_prefix ("org.mpris.MediaPlayer2.")) {
                        player = name;
                        break;
                    }
                }
                if (player == null) {
                    return;   /* no player running */
                }
                string method = (op == "next") ? "Next"
                    : (op == "prev") ? "Previous" : "PlayPause";
                bus.call_sync (player, "/org/mpris/MediaPlayer2",
                    "org.mpris.MediaPlayer2.Player", method,
                    null, null, DBusCallFlags.NONE, -1, null);

                string title = "";
                try {
                    var meta = bus.call_sync (player,
                        "/org/mpris/MediaPlayer2",
                        "org.freedesktop.DBus.Properties", "Get",
                        new Variant ("(ss)",
                            "org.mpris.MediaPlayer2.Player", "Metadata"),
                        new VariantType ("(v)"),
                        DBusCallFlags.NONE, 500, null);
                    Variant inner;
                    meta.get ("(v)", out inner);
                    var lookup = inner.lookup_value ("xesam:title",
                        VariantType.STRING);
                    if (lookup != null) {
                        title = lookup.get_string ();
                    }
                } catch (Error e) { }

                if (enabled) {
                    string icon_name = (op == "next")
                        ? "media-skip-forward-symbolic"
                        : (op == "prev")
                        ? "media-skip-backward-symbolic"
                        : "media-playback-start-symbolic";
                    window.present_osd (icon_name, -1, title);
                }
            } catch (Error e) {
                warning ("kavis-osd: MPRIS access: %s", e.message);
            }
        }
    }
}

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);
    /* Palette (B2): component CSS gets the @kavis_* names from here. */
    Kavis.Theme.install ();
    var daemon = new Kavis.Osd.Daemon ();
    daemon.ref ();   /* for life — keep the signals connected */
    Gtk.main ();
    return 0;
}
