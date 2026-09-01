/* Right-edge indicators of the taskbar (UI layer).
 *
 * No system tray (XEmbed / StatusNotifier) here — that is its own task
 * and comes later with the notification infrastructure (item 37). These
 * read straight from the system, no helper daemon.
 */

namespace Kavis.Ui {

    /* Clock and date. Seconds are not shown (a future
     * appearance.show_seconds setting may enable them), so a redraw per
     * minute is enough: we poll every 30 s and rewrite — missing the
     * exact minute boundary by at most half a second, and
     * self-correcting after suspend. */
    public class Clock : Gtk.Label {
        public Clock () {
            get_style_context ().add_class ("clock");
            set_justify (Gtk.Justification.CENTER);
            refresh ();
            Timeout.add_seconds (30, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private void refresh () {
            var now = new DateTime.now_local ();
            set_markup ("<small>%s\n%s</small>".printf (
                now.format ("%H:%M"), now.format ("%d.%m.%Y")));
        }
    }

    /* Active keyboard layout (TR/EN). */
    public class KeyboardIndicator : Gtk.Label {
        public KeyboardIndicator () {
            get_style_context ().add_class ("indicator");
            refresh ();
            Timeout.add_seconds (2, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private void refresh () {
            set_text (current_layout ().up ());
        }

        /* Reads the layout from setxkbmap. With several layouts the
         * first listed is shown, not necessarily the active group;
         * reading the active group needs an XKB call and will be fixed
         * together with the settings app (item 10/34). Failure falls
         * back to "tr" — the product default. */
        private static string current_layout () {
            string output;
            try {
                Process.spawn_sync (null,
                    { "setxkbmap", "-query" }, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                    null, out output, null, null);
            } catch (SpawnError e) {
                return "tr";
            }
            foreach (unowned string line in output.split ("\n")) {
                if (line.has_prefix ("layout:")) {
                    var value = line.substring (7).strip ();
                    return value.split (",")[0];
                }
            }
            return "tr";
        }
    }

    /* Battery percentage; stays hidden on machines without a battery. */
    public class BatteryIndicator : Gtk.Label {
        private string? battery_path;

        public BatteryIndicator () {
            get_style_context ().add_class ("indicator");
            battery_path = find_battery ();
            refresh ();
            if (battery_path != null) {
                Timeout.add_seconds (30, () => {
                    refresh ();
                    return Source.CONTINUE;
                });
            }
        }

        private static string? find_battery () {
            try {
                var dir = Dir.open ("/sys/class/power_supply");
                string? entry;
                while ((entry = dir.read_name ()) != null) {
                    if (entry.has_prefix ("BAT")) {
                        var candidate = "/sys/class/power_supply/" + entry;
                        if (FileUtils.test (candidate + "/capacity",
                                            FileTest.EXISTS)) {
                            return candidate;
                        }
                    }
                }
            } catch (FileError e) {
                /* No directory means no battery — staying hidden is the
                 * normal desktop-machine path, not an error. */
            }
            return null;
        }

        private void refresh () {
            if (battery_path == null) {
                hide ();
                set_no_show_all (true);
                return;
            }
            string percent;
            string status;
            try {
                FileUtils.get_contents (battery_path + "/capacity", out percent);
                FileUtils.get_contents (battery_path + "/status", out status);
            } catch (FileError e) {
                hide ();
                return;
            }
            unowned string mark = (status.strip () == "Charging") ? "⚡" : "";
            set_text ("%s%%%s".printf (mark, percent.strip ()));
        }
    }

    /* Virtual-desktop switcher: one small button per workspace, the
     * active one carries a teal underline (CSS class "active-item"). */
    public class WorkspaceIndicator : Gtk.Box {
        private unowned Wnck.Screen screen;
        private Gtk.Button[] buttons = {};
        private int[] numbers = {};

        public WorkspaceIndicator (Wnck.Screen screen) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 2);
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
