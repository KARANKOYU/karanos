/* The four indicator popups (UI layer) — stage 4.
 *
 * Shared open/close behavior lives in PanelPopup. Texts come from
 * docs/kavis-arayuz-metinleri.md via Strings; system access goes
 * through the logic namespaces (Battery, Keyboard, Volume, PowerPlan)
 * so no widget file touches /sys or spawns a process directly.
 */

namespace Kavis.Ui {

    /* Clock popup: monthly calendar, today highlighted, month arrows
     * come with Gtk.Calendar. */
    public class CalendarPopup : PanelPopup {

        private Gtk.Calendar calendar;

        public CalendarPopup () {
            calendar = new Gtk.Calendar ();
            calendar.show_heading = true;
            calendar.show_day_names = true;
            content.pack_start (calendar, true, true, 0);
        }

        protected override void refresh_content () {
            /* Jump back to the current month with today selected —
             * whatever month was browsed last time. */
            var now = new DateTime.now_local ();
            calendar.select_month (now.get_month () - 1, now.get_year ());
            calendar.select_day (now.get_day_of_month ());
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
