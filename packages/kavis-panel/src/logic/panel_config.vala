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

        public Position position = Position.BOTTOM;
        public Thickness thickness = Thickness.MEDIUM;
        /* Monitor model string, or "primary". Matched against
         * Gdk.Monitor.get_model(); a vanished monitor falls back to
         * primary at placement time (never fails hard). */
        public string monitor = "primary";
        public bool autohide = false;

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
                config.monitor = file.get_string ("panel", "monitor");
            } catch (Error e) { }
            try {
                config.autohide = file.get_boolean ("panel", "autohide");
            } catch (Error e) { }
            return config;
        }

        public void save () {
            var file = new KeyFile ();
            file.set_string ("panel", "position", position.id ());
            file.set_string ("panel", "size", thickness.id ());
            file.set_string ("panel", "monitor", monitor);
            file.set_boolean ("panel", "autohide", autohide);
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
