/* Right-edge indicators of the taskbar (UI layer).
 *
 * Since stage 4 each indicator is a flat button that toggles a small
 * popup above the panel (calendar, battery + power plan, keyboard
 * layout, volume). System access lives in the logic namespaces
 * (Battery, Keyboard, Volume); these files only draw.
 *
 * No system tray (XEmbed / StatusNotifier) here — that is its own task
 * and comes later with the notification infrastructure (item 37).
 */

namespace Kavis.Ui {

    /* Clock and date; clicking opens the monthly calendar. Seconds are
     * not shown, so a redraw per minute is enough: we poll every 30 s —
     * missing the exact minute boundary by at most half a second, and
     * self-correcting after suspend. */
    public class Clock : Gtk.Button {

        private Gtk.Label text_label;
        private NotificationCenterPopup popup;

        public Clock () {
            set_relief (Gtk.ReliefStyle.NONE);
            get_style_context ().add_class ("indicator-button");
            text_label = new Gtk.Label ("");
            text_label.get_style_context ().add_class ("clock");
            text_label.set_justify (Gtk.Justification.CENTER);
            add (text_label);

            popup = new NotificationCenterPopup ();
            clicked.connect (() => popup.toggle_at (this));

            refresh ();
            Timeout.add_seconds (30, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private void refresh () {
            var now = new DateTime.now_local ();
            text_label.set_markup ("<small>%s\n%s</small>".printf (
                now.format ("%H:%M"), now.format ("%d.%m.%Y")));
        }
    }

    /* Active keyboard layout (TR/EN); clicking opens the switcher. */
    public class KeyboardIndicator : Gtk.Button {

        private Gtk.Label text_label;
        private KeyboardPopup popup;

        public KeyboardIndicator () {
            set_relief (Gtk.ReliefStyle.NONE);
            get_style_context ().add_class ("indicator-button");
            text_label = new Gtk.Label ("");
            text_label.get_style_context ().add_class ("indicator");
            add (text_label);

            popup = new KeyboardPopup ();
            popup.changed.connect (() => refresh ());
            clicked.connect (() => popup.toggle_at (this));

            refresh ();
            Timeout.add_seconds (2, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private void refresh () {
            text_label.set_text (Keyboard.current_layout ().up ());
        }
    }

    /* Master volume; clicking opens the shared quick-settings popup
     * (Grup D 2b — W11 behavior). Hidden when no mixer control is
     * readable (no sound hardware). */
    public class VolumeIndicator : Gtk.Button {

        private Gtk.Image icon;

        public VolumeIndicator () {
            set_relief (Gtk.ReliefStyle.NONE);
            get_style_context ().add_class ("indicator-button");
            icon = new Gtk.Image.from_icon_name (
                "audio-volume-high-symbolic", Gtk.IconSize.BUTTON);
            add (icon);
            set_tooltip_text (Strings.get ("sound.volume"));

            if (!Volume.available ()) {
                set_no_show_all (true);
                hide ();
                return;
            }

            clicked.connect (() => {
                QuickSettingsPopup.get_default ().toggle_at (this);
            });

            refresh ();
            Timeout.add_seconds (10, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private void refresh () {
            var state = Volume.read ();
            icon.set_from_icon_name (
                Volume.icon_name (state.percent, state.muted),
                Gtk.IconSize.BUTTON);
        }
    }

    /* Battery percentage; the whole button stays hidden on machines
     * without a battery (stage 4 rule: no battery indicator on
     * desktops). Clicking opens the shared quick-settings popup
     * (Grup D 2b); the power-plan choice moved to the RIGHT-CLICK
     * menu so it stays one click away until Settings arrives. */
    public class BatteryIndicator : Gtk.Button {

        private Gtk.Label text_label;

        public BatteryIndicator () {
            set_relief (Gtk.ReliefStyle.NONE);
            get_style_context ().add_class ("indicator-button");
            text_label = new Gtk.Label ("");
            text_label.get_style_context ().add_class ("indicator");
            add (text_label);

            if (!Battery.present ()) {
                set_no_show_all (true);
                hide ();
                return;
            }

            clicked.connect (() => {
                QuickSettingsPopup.get_default ().toggle_at (this);
            });
            button_press_event.connect ((event) => {
                if (event.button == 3) {
                    show_plan_menu (event);
                    return true;
                }
                return false;
            });

            refresh ();
            Timeout.add_seconds (30, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private void show_plan_menu (Gdk.EventButton event) {
            var menu = new Gtk.Menu ();
            bool[] sources = { true, false };
            string[] source_keys = {
                "power.when_plugged", "power.when_battery"
            };
            for (int s = 0; s < sources.length; s++) {
                var source_item = new Gtk.MenuItem.with_label (
                    Strings.get (source_keys[s]));
                var submenu = new Gtk.Menu ();
                unowned SList<Gtk.RadioMenuItem>? group = null;
                bool plugged = sources[s];
                PowerPlan.Plan[] plans = { PowerPlan.Plan.PERFORMANCE,
                                           PowerPlan.Plan.NORMAL,
                                           PowerPlan.Plan.SAVER };
                var current = PowerPlan.get_plan (plugged);
                foreach (var plan in plans) {
                    var item = new Gtk.RadioMenuItem.with_label (
                        group, Strings.get ("power.plan_" + plan.id ()));
                    group = item.get_group ();
                    item.set_active (current == plan);
                    var chosen = plan;   /* closure copy */
                    item.activate.connect (() => {
                        if (item.get_active ()) {
                            PowerPlan.set_plan (plugged, chosen);
                        }
                    });
                    submenu.append (item);
                }
                source_item.set_submenu (submenu);
                menu.append (source_item);
            }
            menu.show_all ();
            menu.popup_at_pointer (event);
        }

        private void refresh () {
            int percent = Battery.percent ();
            if (percent < 0) {
                text_label.set_text ("");
                return;
            }
            unowned string mark = Battery.charging () ? "⚡" : "";
            text_label.set_text ("%s%%%d".printf (mark, percent));
        }
    }

    /* Virtual-desktop switcher: one small button per workspace, the
     * active one carries a teal underline (CSS class "active-item"). */
    public class WorkspaceIndicator : Gtk.Box {
        private unowned Wnck.Screen screen;
        private Gtk.Button[] buttons = {};
        private int[] numbers = {};

        public WorkspaceIndicator (Wnck.Screen screen,
                                   Gtk.Orientation axis
                                   = Gtk.Orientation.HORIZONTAL) {
            Object (orientation: axis, spacing: 2);
            this.screen = screen;
            rebuild ();
            screen.workspace_created.connect (() => rebuild ());
            screen.workspace_destroyed.connect (() => rebuild ());
            screen.active_workspace_changed.connect (() => mark_active ());
        }

        private void rebuild () {
            foreach (var child in get_children ()) {
                remove (child);
            }
            buttons = {};
            numbers = {};
            foreach (unowned Wnck.Workspace workspace in
                     screen.get_workspaces ()) {
                var button = new Gtk.Button.with_label (
                    "%d".printf (workspace.get_number () + 1));
                button.set_relief (Gtk.ReliefStyle.NONE);
                button.set_tooltip_text (workspace.get_name () ?? "");
                unowned Wnck.Workspace target = workspace;
                button.clicked.connect (() => {
                    target.activate (Gtk.get_current_event_time ());
                });
                buttons += button;
                numbers += workspace.get_number ();
                pack_start (button, false, false, 0);
            }
            show_all ();
            mark_active ();
        }

        private void mark_active () {
            unowned Wnck.Workspace? active = screen.get_active_workspace ();
            int active_number = (active != null) ? active.get_number () : -1;
            for (int i = 0; i < buttons.length; i++) {
                unowned Gtk.StyleContext context =
                    buttons[i].get_style_context ();
                if (numbers[i] == active_number) {
                    context.add_class ("active-item");
                } else {
                    context.remove_class ("active-item");
                }
            }
        }
    }
}
