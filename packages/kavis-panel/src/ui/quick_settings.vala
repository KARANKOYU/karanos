/* Quick settings popup (UI layer) — Grup D fix 2b.
 *
 * Windows 11 quick settings: a 3-column grid of tiles (split tiles
 * open an in-popup subpage), brightness and volume sliders, a battery
 * line with a settings gear. One shared instance — the volume and
 * battery indicators and the tray tools (item 3) all toggle the same
 * popup. Backends live in logic (Quick, Volume, PowerPlan, Focus,
 * Notifications); this file only draws.
 */

namespace Kavis.Ui {

    /* One tile: a bordered box holding the toggle button (icon), for
     * split tiles a narrow "›" button opening a subpage, and a small
     * caption underneath. Teal fill with dark icon when on. */
    public class SettingTile : Gtk.Box {

        public signal void toggled_by_user (bool enabled);
        public signal void details_requested ();

        private Gtk.Box frame;
        private Gtk.Label caption;
        private bool state = false;

        public SettingTile (string icon_name, string label_key,
                            bool split) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 4);

            frame = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            frame.get_style_context ().add_class ("setting-tile");

            var tile_icon = new Gtk.Image.from_icon_name (
                icon_name, Gtk.IconSize.INVALID);
            tile_icon.set_pixel_size (20);   /* B4: 20px ikon */
            var main_button = new Gtk.Button ();
            main_button.add (tile_icon);
            main_button.set_relief (Gtk.ReliefStyle.NONE);
            main_button.clicked.connect (() => {
                set_state (!state);
                toggled_by_user (state);
            });
            frame.pack_start (main_button, true, true, 0);

            if (split) {
                var arrow = new Gtk.Button.with_label ("›");
                arrow.set_relief (Gtk.ReliefStyle.NONE);
                arrow.get_style_context ().add_class ("tile-arrow");
                arrow.clicked.connect (() => details_requested ());
                frame.pack_end (arrow, false, false, 0);
            }
            pack_start (frame, false, false, 0);

            caption = new Gtk.Label (null);
            caption.set_ellipsize (Pango.EllipsizeMode.END);
            caption.set_max_width_chars (12);
            set_caption (_(label_key));
            pack_start (caption, false, false, 0);
        }

        public void set_caption (string text) {
            caption.set_markup ("<small>%s</small>".printf (
                Markup.escape_text (text)));
        }

        public void set_state (bool enabled) {
            state = enabled;
            unowned Gtk.StyleContext context = frame.get_style_context ();
            if (enabled) {
                context.add_class ("on");
            } else {
                context.remove_class ("on");
            }
        }
    }

    public class QuickSettingsPopup : PanelPopup {

        /* Tek örnek: ses/pil göstergeleri ve tepsi araçları (madde 3)
         * aynı popup'ı açar. */
        private static QuickSettingsPopup? instance = null;

        public static QuickSettingsPopup get_default () {
            if (instance == null) {
                instance = new QuickSettingsPopup ();
            }
            return instance;
        }

        private Gtk.Stack stack;
        private SettingTile? wifi_tile = null;
        private SettingTile? bt_tile = null;
        private SettingTile? airplane_tile = null;
        private SettingTile? night_tile = null;
        private SettingTile game_tile;
        private SettingTile focus_tile;
        private SettingTile dnd_tile;
        private SettingTile? saver_tile = null;
        private Gtk.Scale? brightness_slider = null;
        private Gtk.Scale? volume_slider = null;
        private Gtk.Image? volume_icon = null;
        private Gtk.Label battery_label;
        private Gtk.Box? wifi_list = null;
        private Gtk.Box? bt_list = null;
        private Gtk.Box? sink_list = null;
        private bool updating = false;
        private uint brightness_source = 0;
        private uint volume_source = 0;

        private QuickSettingsPopup () {
            edge_aligned = true;
            content.set_size_request (380, -1);
            content.set_border_width (16);

            stack = new Gtk.Stack ();
            stack.set_transition_type (
                Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            stack.set_transition_duration (180);
            stack.add_named (build_main_page (), "main");
            if (wifi_tile != null) {
                stack.add_named (build_wifi_page (), "wifi");
            }
            if (bt_tile != null && Quick.bluetooth_list_available ()) {
                stack.add_named (build_bt_page (), "bt");
            }
            if (Quick.sound_output_available ()) {
                stack.add_named (build_sink_page (), "sinks");
            }
            stack.add_named (build_access_page (), "access");
            if (Battery.present ()) {
                stack.add_named (build_battery_page (), "battery");
            }
            content.pack_start (stack, true, true, 0);
        }

        /* Tepsi araçları doğrudan bir alt sayfaya açabilir (madde 3:
         * Wi-Fi simgesi → ağ listesi). */
        public void open_page (Gtk.Widget anchor, string page) {
            if (get_visible ()) {
                dismiss ();
                return;
            }
            toggle_at (anchor);
            if (stack.get_child_by_name (page) != null) {
                show_page (page);
            }
        }

        private void show_page (string name) {
            stack.set_visible_child_name (name);
            if (name == "wifi") {
                rebuild_wifi_list ();
            } else if (name == "bt") {
                rebuild_bt_list ();
            } else if (name == "sinks") {
                rebuild_sink_list ();
            } else if (name == "battery"
                       && plugged_choices.length == 3) {
                plans_building = true;
                plugged_choices[(int) PowerPlan.get_plan (true)]
                    .set_active (true);
                battery_choices[(int) PowerPlan.get_plan (false)]
                    .set_active (true);
                plans_building = false;
            }
            refit ();
        }

        /* --- ana sayfa ------------------------------------------------ */

        private Gtk.Widget build_main_page () {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);

            var grid = new Gtk.Grid ();
            grid.set_column_homogeneous (true);
            grid.set_column_spacing (8);
            grid.set_row_spacing (10);

            int col = 0, row = 0;

            if (Quick.wifi_available ()) {
                wifi_tile = new SettingTile ("network-wireless-symbolic",
                                             N_("Wi-Fi"), true);
                wifi_tile.toggled_by_user.connect ((on) => {
                    Quick.wifi_set (on);
                });
                wifi_tile.details_requested.connect (() => {
                    show_page ("wifi");
                });
                attach_tile (grid, wifi_tile, ref col, ref row);
            }
            if (Quick.bluetooth_available ()) {
                bt_tile = new SettingTile ("bluetooth-active-symbolic",
                    N_("Bluetooth"),
                    Quick.bluetooth_list_available ());
                bt_tile.toggled_by_user.connect ((on) => {
                    Quick.bluetooth_set (on);
                });
                bt_tile.details_requested.connect (() => {
                    show_page ("bt");
                });
                attach_tile (grid, bt_tile, ref col, ref row);
            }
            if (Quick.airplane_available ()) {
                airplane_tile = new SettingTile ("airplane-mode-symbolic",
                                                 N_("Airplane mode"), false);
                airplane_tile.toggled_by_user.connect ((on) => {
                    Quick.airplane_set (on);
                    /* Telsiz kutucukları da değişir. */
                    Timeout.add (300, () => {
                        refresh_content ();
                        return Source.REMOVE;
                    });
                });
                attach_tile (grid, airplane_tile, ref col, ref row);
            }
            if (Quick.night_available ()) {
                night_tile = new SettingTile ("night-light-symbolic",
                                              N_("Night light"), false);
                night_tile.toggled_by_user.connect ((on) => {
                    Quick.night_set (on);
                });
                attach_tile (grid, night_tile, ref col, ref row);
            }
            game_tile = new SettingTile ("input-gaming-symbolic",
                                         N_("Game Mode"), false);
            game_tile.toggled_by_user.connect ((on) => {
                Quick.gamemode_set (on);
            });
            attach_tile (grid, game_tile, ref col, ref row);

            focus_tile = new SettingTile ("alarm-symbolic",
                                          N_("Focus"), false);
            focus_tile.toggled_by_user.connect ((on) => {
                if (on) {
                    Focus.start ();
                } else {
                    Focus.cancel ();
                }
            });
            attach_tile (grid, focus_tile, ref col, ref row);

            dnd_tile = new SettingTile ("notifications-disabled-symbolic",
                                        N_("Do not disturb"), false);
            dnd_tile.toggled_by_user.connect ((on) => {
                if (Notifications.server != null) {
                    Notifications.server.set_dnd (on);
                }
            });
            attach_tile (grid, dnd_tile, ref col, ref row);

            if (Battery.present ()) {
                saver_tile = new SettingTile ("battery-good-symbolic",
                                              N_("Battery saver"), false);
                saver_tile.toggled_by_user.connect ((on) => {
                    /* Tasarruf, o anki güç kaynağının planını değiştirir;
                     * kapatınca Normal'e döner. Kaynak yaklaşık olarak
                     * şarj durumundan okunur. */
                    bool plugged = Battery.charging ();
                    PowerPlan.set_plan (plugged, on
                        ? PowerPlan.Plan.SAVER : PowerPlan.Plan.NORMAL,
                        Battery.on_ac ());
                });
                attach_tile (grid, saver_tile, ref col, ref row);
            }

            var access_tile = new SettingTile (
                "preferences-desktop-accessibility-symbolic",
                N_("Accessibility"), true);
            access_tile.toggled_by_user.connect ((on) => {
                /* Aç/kapa karşılığı yok; kutucuk yalnız alt panele
                 * açılır. Durum vurgusunu geri al. */
                access_tile.set_state (false);
                show_page ("access");
            });
            access_tile.details_requested.connect (() => {
                show_page ("access");
            });
            attach_tile (grid, access_tile, ref col, ref row);

            page.pack_start (grid, false, false, 0);
            page.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 0);

            /* --- kaydırıcılar (3C: W11 sırası — parlaklık ÜSTTE,
             * ses altta; sürüklerken değer balonu; parlaklık artık
             * donanımsız da görünür, xrandr yazılım kipiyle) --- */
            {
                var row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                row_box.pack_start (new Gtk.Image.from_icon_name (
                    "display-brightness-symbolic", Gtk.IconSize.BUTTON),
                    false, false, 0);
                brightness_slider = new Gtk.Scale.with_range (
                    Gtk.Orientation.HORIZONTAL, 10, 100, 5);
                brightness_slider.set_draw_value (false);
                brightness_slider.set_tooltip_text (
                    Brightness.hardware ()
                    ? _("Brightness (backlight)")
                    : _("Brightness (software — no backlight hardware)"));
                attach_value_bubble (brightness_slider);
                brightness_slider.value_changed.connect (() => {
                    if (updating) {
                        return;
                    }
                    int value = (int) brightness_slider.get_value ();
                    if (brightness_source != 0) {
                        Source.remove (brightness_source);
                    }
                    brightness_source = Timeout.add (80, () => {
                        brightness_source = 0;
                        Quick.brightness_set (value);
                        /* Fn tuşlarıyla aynı OSD (3C). */
                        show_brightness_osd ();
                        return Source.REMOVE;
                    });
                });
                row_box.pack_start (brightness_slider, true, true, 0);
                page.pack_start (row_box, false, false, 0);
            }

            if (Volume.available ()) {
                var row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                volume_icon = new Gtk.Image.from_icon_name (
                    "audio-volume-high-symbolic", Gtk.IconSize.BUTTON);
                var mute = new Gtk.Button ();
                mute.set_relief (Gtk.ReliefStyle.NONE);
                mute.set_tooltip_text (_("Mute"));
                mute.add (volume_icon);
                mute.clicked.connect (() => {
                    Volume.toggle_mute ();
                    Timeout.add (150, () => {
                        refresh_sound_row ();
                        return Source.REMOVE;
                    });
                });
                row_box.pack_start (mute, false, false, 0);
                volume_slider = new Gtk.Scale.with_range (
                    Gtk.Orientation.HORIZONTAL, 0, 100, 5);
                volume_slider.set_draw_value (false);
                volume_slider.set_tooltip_text (
                    _("Volume"));
                attach_value_bubble (volume_slider);
                volume_slider.value_changed.connect (() => {
                    if (updating) {
                        return;
                    }
                    int value = (int) volume_slider.get_value ();
                    if (volume_source != 0) {
                        Source.remove (volume_source);
                    }
                    volume_source = Timeout.add (80, () => {
                        volume_source = 0;
                        Volume.set_percent (value);
                        return Source.REMOVE;
                    });
                });
                row_box.pack_start (volume_slider, true, true, 0);
                if (Quick.sound_output_available ()) {
                    var arrow = new Gtk.Button.with_label ("›");
                    arrow.set_relief (Gtk.ReliefStyle.NONE);
                    arrow.set_tooltip_text (_("Output device"));
                    arrow.clicked.connect (() => {
                        show_page ("sinks");
                    });
                    row_box.pack_end (arrow, false, false, 0);
                }
                page.pack_start (row_box, false, false, 0);
            }

            page.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 0);

            /* --- alt satır: pil + dişli --- */
            var bottom = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            battery_label = new Gtk.Label ("");
            battery_label.set_xalign (0);
            if (Battery.present ()) {
                bottom.pack_start (new Gtk.Image.from_icon_name (
                    "battery-good-symbolic", Gtk.IconSize.BUTTON),
                    false, false, 0);
                bottom.pack_start (battery_label, false, false, 0);
            }
            var gear = new Gtk.Button.from_icon_name (
                "emblem-system-symbolic", Gtk.IconSize.BUTTON);
            gear.set_relief (Gtk.ReliefStyle.NONE);
            gear.set_tooltip_text (_("Settings"));
            gear.clicked.connect (() => {
                dismiss ();
                Launch.settings ("home");
            });
            bottom.pack_end (gear, false, false, 0);
            page.pack_start (bottom, false, false, 0);

            return page;
        }

        private void attach_tile (Gtk.Grid grid, SettingTile tile,
                                  ref int col, ref int row) {
            grid.attach (tile, col, row, 1, 1);
            col++;
            if (col == 3) {
                col = 0;
                row++;
            }
        }

        /* --- alt sayfalar --------------------------------------------- */

        private Gtk.Widget subpage (string title_key, out Gtk.Box body) {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            var back = new Gtk.Button.with_label (
                "‹ " + _("Back"));
            back.get_style_context ().add_class ("back-button");
            back.set_relief (Gtk.ReliefStyle.NONE);
            back.clicked.connect (() => {
                stack.set_visible_child_name ("main");
                refit ();
            });
            header.pack_start (back, false, false, 0);
            var title = new Gtk.Label (_(title_key));
            title.get_style_context ().add_class ("dim");
            header.pack_start (title, true, true, 0);
            page.pack_start (header, false, false, 0);
            page.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 0);

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_policy (Gtk.PolicyType.NEVER,
                               Gtk.PolicyType.AUTOMATIC);
            scroll.set_size_request (-1, 240);
            body = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            scroll.add (body);
            page.pack_start (scroll, true, true, 0);
            return page;
        }

        private Gtk.Widget build_wifi_page () {
            Gtk.Box body;
            var page = subpage (N_("Wi-Fi"), out body);
            wifi_list = body;
            return page;
        }

        private Gtk.Widget build_bt_page () {
            Gtk.Box body;
            var page = subpage (N_("Paired devices"), out body);
            bt_list = body;
            return page;
        }

        private Gtk.Widget build_sink_page () {
            Gtk.Box body;
            var page = subpage (N_("Output device"), out body);
            sink_list = body;
            return page;
        }

        /* test8 B1: güç planı seçimi — şarjdayken ve pildeyken ayrı
         * sütun, üç plan radyosu (eski BatteryPopup mantığı geri,
         * alt panel olarak). */
        private Gtk.RadioButton[] plugged_choices = {};
        private Gtk.RadioButton[] battery_choices = {};
        private bool plans_building = false;

        private Gtk.Widget build_battery_page () {
            Gtk.Box body;
            var page = subpage (N_("Battery"), out body);
            var columns = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 18);
            columns.set_border_width (8);
            columns.pack_start (plan_column (
                _("When plugged in"), true, out plugged_choices),
                true, true, 0);
            columns.pack_start (plan_column (
                _("On battery"), false, out battery_choices),
                true, true, 0);
            body.pack_start (columns, false, false, 0);
            return page;
        }

        private Gtk.Box plan_column (string title_text, bool plugged,
                                     out Gtk.RadioButton[] choices) {
            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            var title = new Gtk.Label (title_text);
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            column.pack_start (title, false, false, 0);
            Gtk.RadioButton? group = null;
            Gtk.RadioButton[] built = {};
            PowerPlan.Plan[] plans = { PowerPlan.Plan.PERFORMANCE,
                                       PowerPlan.Plan.NORMAL,
                                       PowerPlan.Plan.SAVER };
            foreach (var plan in plans) {
                string label = (plan == PowerPlan.Plan.PERFORMANCE)
                    ? _("High performance")
                    : (plan == PowerPlan.Plan.SAVER)
                    ? _("Power saver") : _("Balanced");
                var choice = new Gtk.RadioButton.with_label_from_widget (
                    group, label);
                group = choice;
                var chosen = plan;   /* closure copy */
                choice.toggled.connect (() => {
                    if (!plans_building && choice.get_active ()) {
                        PowerPlan.set_plan (plugged, chosen, Battery.on_ac ());
                    }
                });
                built += choice;
                column.pack_start (choice, false, false, 0);
            }
            choices = built;
            return column;
        }

        private Gtk.Widget build_access_page () {
            Gtk.Box body;
            var page = subpage (N_("Accessibility"), out body);
            /* Erişilebilirlik seçenekleri Ayarlar uygulamasıyla
             * geliyor (Grup F); alt panel o güne kadar bunu söyler. */
            var soon = new Gtk.Label (_("Settings app coming soon"));
            soon.get_style_context ().add_class ("dim");
            soon.set_margin_top (20);
            body.pack_start (soon, false, false, 0);
            return page;
        }

        private void clear_box (Gtk.Box box) {
            foreach (var child in box.get_children ()) {
                box.remove (child);
            }
        }

        private Gtk.Button list_row (string text, bool active) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var label = new Gtk.Label (text);
            label.set_xalign (0);
            label.set_ellipsize (Pango.EllipsizeMode.END);
            row.pack_start (label, true, true, 0);
            if (active) {
                var mark = new Gtk.Label (
                    _("Connected"));
                mark.get_style_context ().add_class ("dim");
                row.pack_end (mark, false, false, 0);
            }
            button.add (row);
            return button;
        }

        private void rebuild_wifi_list () {
            if (wifi_list == null) {
                return;
            }
            clear_box (wifi_list);
            var networks = Quick.wifi_networks ();
            if (networks.length == 0) {
                var empty = new Gtk.Label (
                    _("No networks found"));
                empty.get_style_context ().add_class ("dim");
                empty.set_margin_top (20);
                wifi_list.pack_start (empty, false, false, 0);
            }
            foreach (unowned Quick.WifiNetwork network in networks) {
                var row = list_row (network.ssid, network.active);
                string ssid = network.ssid;
                bool active = network.active;
                row.clicked.connect (() => {
                    if (active) {
                        Quick.wifi_disconnect ();
                    } else {
                        Quick.wifi_connect (ssid);
                    }
                    dismiss ();
                });
                wifi_list.pack_start (row, false, false, 0);
            }
            wifi_list.show_all ();
        }

        private void rebuild_bt_list () {
            if (bt_list == null) {
                return;
            }
            clear_box (bt_list);
            var devices = Quick.bluetooth_devices ();
            if (devices.length == 0) {
                var empty = new Gtk.Label (_("None"));
                empty.get_style_context ().add_class ("dim");
                empty.set_margin_top (20);
                bt_list.pack_start (empty, false, false, 0);
            }
            foreach (unowned Quick.BtDevice device in devices) {
                var row = list_row (device.name, false);
                string address = device.address;
                row.clicked.connect (() => {
                    Quick.bluetooth_connect (address);
                    dismiss ();
                });
                bt_list.pack_start (row, false, false, 0);
            }
            bt_list.show_all ();
        }

        private void rebuild_sink_list () {
            if (sink_list == null) {
                return;
            }
            clear_box (sink_list);
            foreach (unowned Quick.SoundOutput sink in
                     Quick.sound_outputs ()) {
                var row = list_row (sink.description, sink.active);
                string name = sink.name;
                row.clicked.connect (() => {
                    Quick.sound_set_output (name);
                    Timeout.add (200, () => {
                        rebuild_sink_list ();
                        return Source.REMOVE;
                    });
                });
                sink_list.pack_start (row, false, false, 0);
            }
            sink_list.show_all ();
        }

        /* --- durum tazeleme ------------------------------------------- */

        /* 3C: sürüklerken kaydırıcının üstünde değer balonu ("90") —
         * GTK3'te hazır balon yok, en hafifi draw_value'yu yalnız
         * basılıyken açmak. */
        private void attach_value_bubble (Gtk.Scale scale) {
            scale.set_digits (0);
            scale.set_value_pos (Gtk.PositionType.TOP);
            scale.button_press_event.connect (() => {
                scale.set_draw_value (true);
                return false;
            });
            scale.button_release_event.connect (() => {
                scale.set_draw_value (false);
                return false;
            });
        }

        /* Fn tuşlarıyla aynı OSD'yi göster (kavis-osd ayrı süreç). */
        private void show_brightness_osd () {
            try {
                Process.spawn_async (null, {
                    "gdbus", "call", "--session",
                    "--dest", "org.kavis.Osd",
                    "--object-path", "/org/kavis/Osd",
                    "--method", "org.kavis.Osd.BrightnessShow"
                }, null, SpawnFlags.SEARCH_PATH
                   | SpawnFlags.STDOUT_TO_DEV_NULL
                   | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
            } catch (Error e) { }
        }

        private void refresh_sound_row () {
            if (volume_slider == null) {
                return;
            }
            var state = Volume.read ();
            updating = true;
            volume_slider.set_value (int.max (0, state.percent));
            updating = false;
            volume_icon.set_from_icon_name (
                Volume.icon_name (state.percent, state.muted),
                Gtk.IconSize.BUTTON);
        }

        protected override void refresh_content () {
            /* Her açılış ana sayfadan başlar (W11 davranışı). */
            var saved = stack.get_transition_type ();
            stack.set_transition_type (Gtk.StackTransitionType.NONE);
            stack.set_visible_child_name ("main");
            stack.set_transition_type (saved);

            if (wifi_tile != null) {
                wifi_tile.set_state (Quick.wifi_enabled ());
                string ssid = Quick.wifi_ssid ();
                wifi_tile.set_caption (
                    ssid != "" ? ssid : _("Wi-Fi"));
            }
            if (bt_tile != null) {
                bt_tile.set_state (Quick.bluetooth_enabled ());
            }
            if (airplane_tile != null) {
                airplane_tile.set_state (Quick.airplane_enabled ());
            }
            if (night_tile != null) {
                night_tile.set_state (Quick.night_enabled ());
            }
            game_tile.set_state (Quick.gamemode_enabled ());
            focus_tile.set_state (Focus.active ());
            dnd_tile.set_state (Notifications.server != null
                                && Notifications.server.dnd);
            if (brightness_slider != null) {
                int percent = Quick.brightness_percent ();
                if (percent >= 0) {
                    updating = true;
                    brightness_slider.set_value (percent);
                    updating = false;
                }
            }
            refresh_sound_row ();
            if (Battery.present ()) {
                int percent = Battery.percent ();
                unowned string fmt = _("%d%%");
                battery_label.set_text (
                    (percent >= 0) ? fmt.printf (percent) : "—");
            }
        }
    }
}
