/* Taskbar configuration (business logic — no widget code here).
 *
 * Madde 5: position (bottom/top/left/right), thickness (thin/medium/
 * thick), which monitor on multi-monitor setups, auto-hide. Stored as
 * a GLib KeyFile at ~/.config/kavis/panel.conf — same directory the
 * power plan already uses, and the future Settings app (Grup F) edits
 * the same file.
 */

namespace Kavis {

    public class PanelConfig {

        public enum Position {
            BOTTOM, TOP, LEFT, RIGHT;

            public string id () {
                switch (this) {
                case TOP:   return "top";
                case LEFT:  return "left";
                case RIGHT: return "right";
                default:    return "bottom";
                }
            }

            public static Position from_id (string id) {
                switch (id) {
                case "top":   return TOP;
                case "left":  return LEFT;
                case "right": return RIGHT;
                default:      return BOTTOM;
                }
            }
        }

        public enum Thickness {
            THIN, MEDIUM, THICK;

            public string id () {
                switch (this) {
                case THIN:  return "thin";
                case THICK: return "thick";
                default:    return "medium";
                }
            }

            public static Thickness from_id (string id) {
                switch (id) {
                case "thin":  return THIN;
                case "thick": return THICK;
                default:      return MEDIUM;
                }
            }

            /* Panel strip thickness in pixels (height when horizontal,
             * width when vertical). MEDIUM matches the historical 44. */
            public int pixels () {
                switch (this) {
                case THIN:  return 36;
                case THICK: return 52;
                default:    return 44;
                }
            }
        }

        public enum Alignment {
            LEFT, CENTER;

            public string id () {
                switch (this) {
                case CENTER: return "center";
                default:     return "left";
                }
            }

            public static Alignment from_id (string id) {
                switch (id) {
                case "center": return CENTER;
                default:       return LEFT;
                }
            }
        }

        public Position position = Position.BOTTOM;
        public Thickness thickness = Thickness.MEDIUM;
        /* Start button + window list placement: Windows 10 style on the
         * left (the default) or Windows 11 style centered. */
        public Alignment alignment = Alignment.LEFT;
        /* Monitor model string, or "primary". Matched against
         * Gdk.Monitor.get_model(); a vanished monitor falls back to
         * primary at placement time (never fails hard). */
        public string monitor = "primary";
        public bool autohide = false;
        /* Notification-center calendar collapsed state (Grup D fix:
         * remembered across sessions, [clock] group). */
        public bool calendar_collapsed = false;
        /* "Emoji and more" panelinin son konumu (test8 G5); -1 = hiç
         * taşınmadı, imlecin yakınında açılır. [picker] grubu. */
        public int picker_x = -1;
        public int picker_y = -1;

        /* One shared instance: the popups save settings too, and a
         * second instance would write back stale panel values. */
        private static PanelConfig? instance = null;

        public static PanelConfig get_default () {
            if (instance == null) {
                instance = load ();
            }
            return instance;
        }

        public bool vertical {
            get {
                return position == Position.LEFT
                    || position == Position.RIGHT;
            }
        }

        private static string config_path () {
            return Path.build_filename (
                Environment.get_user_config_dir (), "kavis", "panel.conf");
        }

        public static PanelConfig load () {
            var config = new PanelConfig ();
            var file = new KeyFile ();
            try {
                file.load_from_file (config_path (), KeyFileFlags.NONE);
            } catch (Error e) {
                return config;   /* first run: defaults */
            }
            try {
                config.position = Position.from_id (
                    file.get_string ("panel", "position"));
            } catch (Error e) { }
            try {
                config.thickness = Thickness.from_id (
                    file.get_string ("panel", "size"));
            } catch (Error e) { }
            try {
                config.alignment = Alignment.from_id (
                    file.get_string ("panel", "align"));
            } catch (Error e) { }
            try {
                config.monitor = file.get_string ("panel", "monitor");
            } catch (Error e) { }
            try {
                config.autohide = file.get_boolean ("panel", "autohide");
            } catch (Error e) { }
            try {
                config.calendar_collapsed =
                    file.get_boolean ("clock", "calendar_collapsed");
            } catch (Error e) { }
            try {
                config.picker_x = file.get_integer ("picker", "x");
                config.picker_y = file.get_integer ("picker", "y");
            } catch (Error e) { }
            return config;
        }

        public void save () {
            var file = new KeyFile ();
            /* panel.conf carries other groups too ([clipboard] limit);
             * writing a fresh KeyFile would silently drop them. */
            try {
                file.load_from_file (config_path (), KeyFileFlags.KEEP_COMMENTS);
            } catch (Error e) { }
            file.set_string ("panel", "position", position.id ());
            file.set_string ("panel", "align", alignment.id ());
            file.set_string ("panel", "size", thickness.id ());
            file.set_string ("panel", "monitor", monitor);
            file.set_boolean ("panel", "autohide", autohide);
            file.set_boolean ("clock", "calendar_collapsed",
                              calendar_collapsed);
            file.set_integer ("picker", "x", picker_x);
            file.set_integer ("picker", "y", picker_y);
            string path = config_path ();
            DirUtils.create_with_parents (Path.get_dirname (path), 0755);
            try {
                FileUtils.set_contents (path, file.to_data ());
            } catch (Error e) {
                warning ("kavis-panel: panel.conf yazilamadi: %s", e.message);
            }
        }
    }
}
