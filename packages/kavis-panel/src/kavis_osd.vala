/* kavis-osd — ses / parlaklık / kilit tuşu / medya OSD daemon'u
 * (sonraki-isler 6a). PANELDEN AYRI süreç: panel çökse bile ses
 * tuşları çalışır ve ekranda karşılık görünür.
 *
 * Openbox tuş bağları org.kavis.Osd'ye gdbus ile seslenir; ses/
 * parlaklık değişimini bu süreç yapar (amixer / brightnessctl,
 * logic/volume.vala + logic/quick.vala paylaşımlı derlenir), OSD
 * yalnız gösterir. Caps/Num Lock için tuş bağı YOK: Gdk.Keymap
 * state-changed sinyali dinlenir (tuşu grab'lamak kilidin kendisiyle
 * yarışırdı). Medya tuşları MPRIS üzerinden çalan oynatıcıya gider.
 *
 * Görsel: ekranın üst ortasında küçük yuvarlak köşeli kutu (@kavis_surface
 * ~%90), ikon + turkuaz dolgu çubuğu + yüzde; 1 sn sonra kapanır
 * (150 ms solma picom'un genel pencere animasyonundan). Arka arkaya
 * basışta sayaç sıfırlanır, kutu yerinde kalır.
 *
 * ~/.config/kavis/kavis.conf [osd] enabled=false hepsini susturur
 * (Ayarlar Grup F'de düzenleyecek).
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

        /* 3C: hızlı ayarlar kaydırıcısı değeri kendisi yazar, OSD
         * yalnız gösterir. */
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
            /* 3C: donanım yoksa xrandr yazılım kipi devrede — OSD
             * artık her makinede çalışır. */
            int current = Quick.brightness_percent ();
            Quick.brightness_set ((current + delta).clamp (10, 100));
            settle (() => { brightness_shown (); return Source.REMOVE; });
        }

        /* amixer/brightnessctl asenkron; gerçek değeri kısa bekleyip
         * oku. */
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

        private Gtk.Image icon;
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

        /* percent < 0: çubuk gizli, yalnız ikon + metin (kilit
         * tuşları, medya). dim: sessizde çubuk soluk. */
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
            /* Üst orta (6a): ses OSD'si artık alt değil üstte. */
            move (area.x + (area.width - natural.width) / 2,
                  area.y + 48);

            /* Arka arkaya basışta sayaç sıfırlanır, kutu kalır. */
            if (hide_timer != 0) {
                Source.remove (hide_timer);
            }
            hide_timer = Timeout.add (HIDE_MS, () => {
                hide_timer = 0;
                hide ();   /* 150 ms solma picom'dan */
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
            /* Kapatma anahtarı (Ayarlar Grup F): kavis.conf [osd]. */
            var file = Kavis.Config.load ();
            try {
                enabled = file.get_boolean ("osd", "enabled");
            } catch (Error e) { }
            /* Canlı ayar (1A-2): Ayarlar anahtarı değiştirince süreç
             * yeniden başlatılmadan geçerli olsun. */
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
                        warning ("kavis-osd: nesne verilemedi: %s",
                                 e.message);
                    }
                },
                null,
                () => {
                    warning ("kavis-osd: org.kavis.Osd alinamadi — ikinci kopya mi?");
                });

            service.volume_shown.connect (show_volume);
            service.brightness_shown.connect (show_brightness);
            service.media_shown.connect (handle_media);

            /* Caps/Num: tuş bağı yerine durum takibi. */
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

        /* Medya tuşları → MPRIS: ilk kayıtlı oynatıcıya komut; OSD'de
         * ikon + parça adı (varsa). */
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
                    return;   /* çalan oynatıcı yok */
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
                warning ("kavis-osd: MPRIS erisimi: %s", e.message);
            }
        }
    }
}

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);
    /* Palet (B2): bileşen CSS'leri @kavis_* adlarını buradan alır. */
    Kavis.Theme.install ();
    var daemon = new Kavis.Osd.Daemon ();
    daemon.ref ();   /* yaşam boyu — sinyaller kopmasın */
    Gtk.main ();
    return 0;
}
