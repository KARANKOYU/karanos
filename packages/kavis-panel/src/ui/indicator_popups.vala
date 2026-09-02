/* The four indicator popups (UI layer) — stage 4.
 *
 * Shared open/close behavior lives in PanelPopup. Texts come from
 * docs/kavis-arayuz-metinleri.md via Strings; system access goes
 * through the logic namespaces (Battery, Keyboard, Volume, PowerPlan)
 * so no widget file touches /sys or spawns a process directly.
 */

namespace Kavis.Ui {

    /* Clock popup (madde 37): monthly calendar on top, the
     * notification center in the middle (grouped by app, per-group and
     * global clear), quick settings at the bottom. */
    public class CalendarPopup : PanelPopup {

        private Gtk.Calendar calendar;
        private Gtk.Box notif_list;
        private Gtk.Button clear_all_button;

        /* Quick toggles that need their state refreshed on open. */
        private QuickTile? wifi_tile = null;
        private QuickTile? bt_tile = null;
        private QuickTile? night_tile = null;
        private QuickTile? game_tile = null;
        private QuickTile? dnd_tile = null;
        private Gtk.Scale? brightness_slider = null;
        private bool updating = false;
        private uint brightness_source = 0;

        public CalendarPopup () {
            content.set_size_request (330, -1);

            calendar = new Gtk.Calendar ();
            calendar.show_heading = true;
            calendar.show_day_names = true;
            content.pack_start (calendar, false, false, 0);

            content.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 4);

            /* --- bildirim merkezi --- */
            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var title = new Gtk.Label (Strings.get ("notif.center"));
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            header.pack_start (title, true, true, 0);
            clear_all_button = new Gtk.Button.with_label (
                Strings.get ("notif.clear_all"));
            clear_all_button.set_relief (Gtk.ReliefStyle.NONE);
            clear_all_button.clicked.connect (() => {
                if (Notifications.server != null) {
                    Notifications.server.clear_all ();
                }
            });
            header.pack_end (clear_all_button, false, false, 0);
            content.pack_start (header, false, false, 0);

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_policy (Gtk.PolicyType.NEVER,
                               Gtk.PolicyType.AUTOMATIC);
            scroll.set_size_request (-1, 180);
            notif_list = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            scroll.add (notif_list);
            content.pack_start (scroll, true, true, 0);

            if (Notifications.server != null) {
                Notifications.server.history_changed.connect (() => {
                    if (get_visible ()) {
                        rebuild_notifications ();
                    }
                });
            }

            content.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 4);

            /* --- hızlı ayarlar --- */
            build_quick_settings ();
        }

        private void build_quick_settings () {
            var grid = new Gtk.FlowBox ();
            grid.set_selection_mode (Gtk.SelectionMode.NONE);
            grid.set_max_children_per_line (4);
            grid.set_min_children_per_line (4);
            grid.set_homogeneous (true);

            if (Quick.wifi_available ()) {
                wifi_tile = new QuickTile ("network-wireless-symbolic",
                                           "network.wifi");
                wifi_tile.toggled_by_user.connect ((on) => {
                    Quick.wifi_set (on);
                });
                grid.add (wifi_tile);
            }
            if (Quick.bluetooth_available ()) {
                bt_tile = new QuickTile ("bluetooth-active-symbolic",
                                         "settings.bluetooth");
                bt_tile.toggled_by_user.connect ((on) => {
                    Quick.bluetooth_set (on);
                });
                grid.add (bt_tile);
            }
            if (Quick.night_available ()) {
                night_tile = new QuickTile ("night-light-symbolic",
                                            "display.night_mode");
                night_tile.toggled_by_user.connect ((on) => {
                    Quick.night_set (on);
                });
                grid.add (night_tile);
            }
            game_tile = new QuickTile ("input-gaming-symbolic",
                                       "game.mode");
            game_tile.toggled_by_user.connect ((on) => {
                Quick.gamemode_set (on);
            });
            grid.add (game_tile);

            dnd_tile = new QuickTile ("notifications-disabled-symbolic",
                                      "notif.dnd");
            dnd_tile.toggled_by_user.connect ((on) => {
                if (Notifications.server != null) {
                    Notifications.server.set_dnd (on);
                }
            });
            grid.add (dnd_tile);

            content.pack_start (grid, false, false, 0);

            /* Parlaklık kaydırıcısı yalnız backlight olan makinelerde
             * (masaüstlerinde monitör DDC'si ayrı iş — madde 10). */
            if (Quick.brightness_available ()) {
                var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                var icon = new Gtk.Image.from_icon_name (
                    "display-brightness-symbolic", Gtk.IconSize.BUTTON);
                row.pack_start (icon, false, false, 0);
                brightness_slider = new Gtk.Scale.with_range (
                    Gtk.Orientation.HORIZONTAL, 5, 100, 5);
                brightness_slider.set_draw_value (false);
                brightness_slider.set_tooltip_text (
                    Strings.get ("display.brightness"));
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
                        return Source.REMOVE;
                    });
                });
                row.pack_start (brightness_slider, true, true, 0);
                content.pack_start (row, false, false, 0);
            }
        }

        private void rebuild_notifications () {
            foreach (var child in notif_list.get_children ()) {
                notif_list.remove (child);
            }
            unowned NotificationServer? server = Notifications.server;
            if (server == null || server.history.length == 0) {
                var empty = new Gtk.Label (
                    Strings.get ("notif.no_notifications"));
                empty.get_style_context ().add_class ("dim");
                empty.set_margin_top (24);
                notif_list.pack_start (empty, false, false, 0);
                clear_all_button.set_sensitive (false);
                notif_list.show_all ();
                return;
            }
            clear_all_button.set_sensitive (true);

            /* Uygulama bazlı grupla: geçmiş zaten yeni→eski sıralı;
             * ilk görüldüğü sıraya göre grup başlıkları. */
            var seen = new GenericArray<string> ();
            for (int i = 0; i < server.history.length; i++) {
                unowned string app = server.history[i].app_name;
                bool found = false;
                for (int j = 0; j < seen.length; j++) {
                    if (seen[j] == app) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    seen.add (app);
                }
            }
            for (int g = 0; g < seen.length; g++) {
                unowned string app = seen[g];
                var group_header = new Gtk.Box (
                    Gtk.Orientation.HORIZONTAL, 8);
                var app_label = new Gtk.Label (null);
                app_label.set_markup ("<small><b>%s</b></small>".printf (
                    Markup.escape_text (app)));
                app_label.get_style_context ().add_class ("dim");
                app_label.set_xalign (0);
                group_header.pack_start (app_label, true, true, 0);
                var clear_button = new Gtk.Button.with_label (
                    Strings.get ("common.clear"));
                clear_button.set_relief (Gtk.ReliefStyle.NONE);
                string app_copy = app;
                clear_button.clicked.connect (() => {
                    Notifications.server.clear_app (app_copy);
                });
                group_header.pack_end (clear_button, false, false, 0);
                notif_list.pack_start (group_header, false, false, 0);

                for (int i = 0; i < server.history.length; i++) {
                    unowned NotificationEntry entry = server.history[i];
                    if (entry.app_name != app) {
                        continue;
                    }
                    var row = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                    var line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
                    var summary = new Gtk.Label (null);
                    summary.set_markup ("<b>%s</b>".printf (
                        Markup.escape_text (entry.summary)));
                    summary.set_xalign (0);
                    summary.set_ellipsize (Pango.EllipsizeMode.END);
                    line.pack_start (summary, true, true, 0);
                    var when = new Gtk.Label (
                        entry.timestamp.format ("%H:%M"));
                    when.get_style_context ().add_class ("dim");
                    line.pack_end (when, false, false, 0);
                    row.pack_start (line, false, false, 0);
                    if (entry.body != "") {
                        var body = new Gtk.Label (entry.body);
                        body.get_style_context ().add_class ("dim");
                        body.set_xalign (0);
                        body.set_ellipsize (Pango.EllipsizeMode.END);
                        row.pack_start (body, false, false, 0);
                    }
                    notif_list.pack_start (row, false, false, 0);
                }
            }
            notif_list.show_all ();
        }

        protected override void refresh_content () {
            /* Jump back to the current month with today selected —
             * whatever month was browsed last time. */
            var now = new DateTime.now_local ();
            calendar.select_month (now.get_month () - 1, now.get_year ());
            calendar.select_day (now.get_day_of_month ());

            rebuild_notifications ();

            if (wifi_tile != null) {
                wifi_tile.set_state (Quick.wifi_enabled ());
            }
            if (bt_tile != null) {
                bt_tile.set_state (Quick.bluetooth_enabled ());
            }
            if (night_tile != null) {
                night_tile.set_state (Quick.night_enabled ());
            }
            game_tile.set_state (Quick.gamemode_enabled ());
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
        }
    }

    /* One quick-settings tile: icon over a small label; teal when on. */
    public class QuickTile : Gtk.Button {

        public signal void toggled_by_user (bool enabled);

        private bool state = false;

        public QuickTile (string icon_name, string label_key) {
            set_relief (Gtk.ReliefStyle.NONE);
            get_style_context ().add_class ("quick-tile");
            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            column.pack_start (new Gtk.Image.from_icon_name (
                icon_name, Gtk.IconSize.LARGE_TOOLBAR), false, false, 0);
            var label = new Gtk.Label (null);
            label.set_markup ("<small>%s</small>".printf (
                Markup.escape_text (Strings.get (label_key))));
            label.set_ellipsize (Pango.EllipsizeMode.END);
            column.pack_start (label, false, false, 0);
            add (column);
            clicked.connect (() => {
                set_state (!state);
                toggled_by_user (state);
            });
        }

        public void set_state (bool enabled) {
            state = enabled;
            unowned Gtk.StyleContext context = get_style_context ();
            if (enabled) {
                context.add_class ("on");
            } else {
                context.remove_class ("on");
            }
        }
    }

    /* Battery popup: charge, state, time estimate, and the power-plan
     * choice per power source. */
    public class BatteryPopup : PanelPopup {

        private Gtk.Label percent_label;
        private Gtk.Label status_label;
        private Gtk.RadioButton[] plugged_choices = {};
        private Gtk.RadioButton[] battery_choices = {};
        private bool building = false;

        public BatteryPopup () {
            percent_label = new Gtk.Label ("");
            percent_label.set_markup ("");
            percent_label.set_xalign (0);
            content.pack_start (percent_label, false, false, 0);

            status_label = new Gtk.Label ("");
            status_label.get_style_context ().add_class ("dim");
            status_label.set_xalign (0);
            content.pack_start (status_label, false, false, 0);

            content.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 4);

            var plan_title = new Gtk.Label (Strings.get ("power.plan"));
            plan_title.get_style_context ().add_class ("dim");
            plan_title.set_xalign (0);
            content.pack_start (plan_title, false, false, 0);

            var columns = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 18);
            columns.pack_start (
                plan_column ("power.when_plugged", true,
                             out plugged_choices), true, true, 0);
            columns.pack_start (
                plan_column ("power.when_battery", false,
                             out battery_choices), true, true, 0);
            content.pack_start (columns, false, false, 0);
        }

        private Gtk.Box plan_column (string title_key, bool plugged,
                                     out Gtk.RadioButton[] choices) {
            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            var title = new Gtk.Label (Strings.get (title_key));
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            column.pack_start (title, false, false, 0);

            Gtk.RadioButton? group = null;
            Gtk.RadioButton[] built = {};
            PowerPlan.Plan[] plans = { PowerPlan.Plan.PERFORMANCE,
                                       PowerPlan.Plan.NORMAL,
                                       PowerPlan.Plan.SAVER };
            foreach (var plan in plans) {
                var choice = new Gtk.RadioButton.with_label_from_widget (
                    group, Strings.get ("power.plan_" + plan.id ()));
                group = choice;
                var chosen = plan;    /* per-iteration copy for closure */
                choice.toggled.connect (() => {
                    if (!building && choice.get_active ()) {
                        PowerPlan.set_plan (plugged, chosen);
                    }
                });
                built += choice;
                column.pack_start (choice, false, false, 0);
            }
            choices = built;
            return column;
        }

        protected override void refresh_content () {
            int percent = Battery.percent ();
            unowned string fmt = Strings.is_turkish () ? "%%%d" : "%d%%";
            percent_label.set_markup (
                "<span size='x-large' weight='bold'>%s</span>".printf (
                    (percent >= 0) ? fmt.printf (percent) : "—"));

            string status = "";
            int minutes = Battery.minutes_remaining ();
            string duration = "";
            if (minutes > 0) {
                if (minutes >= 60) {
                    duration = "%d %s %d %s".printf (
                        minutes / 60, Strings.get ("power.hours_short"),
                        minutes % 60, Strings.get ("power.minutes_short"));
                } else {
                    duration = "%d %s".printf (
                        minutes, Strings.get ("power.minutes_short"));
                }
            }
            string remaining = (duration != "")
                ? Strings.get ("power.remaining").printf (duration) : "";
            if (Battery.charging ()) {
                status = Strings.get ("power.charging");
                if (remaining != "") {
                    status += " — " + remaining;
                }
            } else {
                status = remaining;
            }
            status_label.set_text (status);
            status_label.set_visible (status != "");

            building = true;
            plugged_choices[(int) PowerPlan.get_plan (true)]
                .set_active (true);
            battery_choices[(int) PowerPlan.get_plan (false)]
                .set_active (true);
            building = false;
        }
    }

    /* Keyboard-layout popup: TR / EN choice, the active one marked. */
    public class KeyboardPopup : PanelPopup {

        public signal void changed ();

        private Gtk.Image tr_mark;
        private Gtk.Image en_mark;

        public KeyboardPopup () {
            var title = new Gtk.Label (Strings.get ("keyboard.layout"));
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            content.pack_start (title, false, false, 0);

            content.pack_start (
                layout_row ("setup.keyboard_trq", "tr", out tr_mark),
                false, false, 0);
            content.pack_start (
                layout_row ("setup.keyboard_en", "us", out en_mark),
                false, false, 0);
        }

        private Gtk.Button layout_row (string label_key, string layout,
                                       out Gtk.Image mark) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            var label = new Gtk.Label (Strings.get (label_key));
            label.set_xalign (0);
            row.pack_start (label, true, true, 0);
            var check = new Gtk.Image.from_icon_name (
                "object-select-symbolic", Gtk.IconSize.BUTTON);
            row.pack_end (check, false, false, 0);
            button.add (row);
            button.clicked.connect (() => {
                Keyboard.set_layout (layout);
                dismiss ();
                /* setxkbmap runs asynchronously; poke listeners after
                 * it has had time to apply. */
                Timeout.add (400, () => {
                    changed ();
                    return Source.REMOVE;
                });
            });
            mark = check;
            return button;
        }

        protected override void refresh_content () {
            bool turkish = Keyboard.current_layout ().down ()
                .has_prefix ("tr");
            /* show_all on open would reveal both marks; pin them. */
            tr_mark.set_no_show_all (!turkish);
            en_mark.set_no_show_all (turkish);
            tr_mark.set_visible (turkish);
            en_mark.set_visible (!turkish);
        }
    }

    /* Volume popup: slider plus mute toggle. */
    public class VolumePopup : PanelPopup {

        public signal void changed ();

        private Gtk.Button mute_button;
        private Gtk.Image mute_icon;
        private Gtk.Scale slider;
        private Gtk.Label percent_label;
        private bool updating = false;
        private uint apply_source = 0;

        public VolumePopup () {
            var title = new Gtk.Label (Strings.get ("sound.volume"));
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            content.pack_start (title, false, false, 0);

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);

            mute_icon = new Gtk.Image.from_icon_name (
                "audio-volume-high-symbolic", Gtk.IconSize.BUTTON);
            mute_button = new Gtk.Button ();
            mute_button.set_relief (Gtk.ReliefStyle.NONE);
            mute_button.set_tooltip_text (Strings.get ("sound.mute"));
            mute_button.add (mute_icon);
            mute_button.clicked.connect (() => {
                Volume.toggle_mute ();
                /* amixer runs asynchronously; re-read shortly after. */
                Timeout.add (150, () => {
                    refresh_content ();
                    changed ();
                    return Source.REMOVE;
                });
            });
            row.pack_start (mute_button, false, false, 0);

            slider = new Gtk.Scale.with_range (
                Gtk.Orientation.HORIZONTAL, 0, 100, 5);
            slider.set_draw_value (false);
            slider.set_size_request (180, -1);
            slider.value_changed.connect (on_slider_moved);
            row.pack_start (slider, true, true, 0);

            percent_label = new Gtk.Label ("");
            percent_label.set_width_chars (5);
            row.pack_start (percent_label, false, false, 0);

            content.pack_start (row, false, false, 0);
        }

        /* Dragging fires value_changed continuously; one amixer per
         * event would spawn dozens of processes. Coalesce into one
         * call 80 ms after the last movement. */
        private void on_slider_moved () {
            if (updating) {
                return;
            }
            int value = (int) slider.get_value ();
            set_percent_text (value, false);
            if (apply_source != 0) {
                Source.remove (apply_source);
            }
            apply_source = Timeout.add (80, () => {
                apply_source = 0;
                Volume.set_percent (value);
                changed ();
                return Source.REMOVE;
            });
        }

        private void set_percent_text (int percent, bool muted) {
            unowned string fmt = Strings.is_turkish () ? "%%%d" : "%d%%";
            percent_label.set_text (
                muted ? "—" : fmt.printf (percent.clamp (0, 100)));
            mute_icon.set_from_icon_name (
                icon_for (percent, muted), Gtk.IconSize.BUTTON);
        }

        /* Also used by the indicator button in the panel. */
        public static unowned string icon_for (int percent, bool muted) {
            if (muted || percent <= 0) {
                return "audio-volume-muted-symbolic";
            }
            if (percent < 34) {
                return "audio-volume-low-symbolic";
            }
            if (percent < 67) {
                return "audio-volume-medium-symbolic";
            }
            return "audio-volume-high-symbolic";
        }

        protected override void refresh_content () {
            var state = Volume.read ();
            updating = true;
            slider.set_value (int.max (0, state.percent));
            updating = false;
            set_percent_text (state.percent, state.muted);
        }
    }
}
