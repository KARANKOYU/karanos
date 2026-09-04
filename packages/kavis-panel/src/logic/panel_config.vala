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
             * width when vertical). MEDIUM matches the historical 44.
             * `scale_percent` scales it with the display scale (F3). */
            public int pixels (int scale_percent = 100) {
                int base_px;
                switch (this) {
                case THIN:  base_px = 36; break;
                case THICK: base_px = 52; break;
                default:    base_px = 44; break;
                }
                return base_px * scale_percent / 100;
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
        /* Display scale in percent ([display] scale, feedback F3). The
         * panel draws in pixels, so a bigger text DPI alone would leave
         * the strip and its icons behind and the layout would drift. */
        public int scale_percent = 100;
        /* Notification-center calendar collapsed state (Grup D fix:
         * remembered across sessions, [clock] group). */
        public bool calendar_collapsed = false;
        /* Last position of the "Emoji and more" panel (test8 G5); -1 =
         * never moved, opens near the cursor. [picker] group. */
        public int picker_x = -1;
        public int picker_y = -1;
        /* Picker glyph size step (feedback item I): "s" | "m" | "l",
         * roughly 20 / 24 / 32 px. [picker] size — applied on the next
         * open too, so the choice survives a restart. */
        public string picker_size = "m";
        /* Madde 63 "safe mode": mount USB with -o sync. Default OFF —
         * it costs speed; the explanation is in the USB popup. */
        public bool usb_sync = false;

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

        public static PanelConfig load () {
            var config = new PanelConfig ();
            /* Single file (1A-2): kavis.conf; the old panel.conf is
             * imported on first load ([panel] → [taskbar]). */
            Config.migrate ();
            var file = new KeyFile ();
            try {
                file.load_from_file (Config.path (), KeyFileFlags.NONE);
            } catch (Error e) {
                return config;   /* first run: defaults */
            }
            try {
                config.position = Position.from_id (
                    file.get_string ("taskbar", "position"));
            } catch (Error e) { }
            try {
                config.thickness = Thickness.from_id (
                    file.get_string ("taskbar", "size"));
            } catch (Error e) { }
            try {
                config.alignment = Alignment.from_id (
                    file.get_string ("taskbar", "align"));
            } catch (Error e) { }
            try {
                config.monitor = file.get_string ("taskbar", "monitor");
            } catch (Error e) { }
            try {
                config.autohide = file.get_boolean ("taskbar", "autohide");
            } catch (Error e) { }
            try {
                config.scale_percent = file.get_integer ("display", "scale");
            } catch (Error e) { }
            if (config.scale_percent < 100 || config.scale_percent > 400) {
                config.scale_percent = 100;
            }
            try {
                config.calendar_collapsed =
                    file.get_boolean ("clock", "calendar_collapsed");
            } catch (Error e) { }
            try {
                config.picker_x = file.get_integer ("picker", "x");
                config.picker_y = file.get_integer ("picker", "y");
            } catch (Error e) { }
            try {
                config.picker_size = file.get_string ("picker", "size");
            } catch (Error e) { }
            if (config.picker_size != "s" && config.picker_size != "l") {
                config.picker_size = "m";
            }
            try {
                config.usb_sync = file.get_boolean ("usb", "sync");
            } catch (Error e) { }
            return config;
        }

        public void save () {
            /* kavis.conf carries other groups too ([clipboard],
             * [appearance]...); a fresh KeyFile would silently drop
             * them — load first. */
            var file = Config.load ();
            file.set_string ("taskbar", "position", position.id ());
            file.set_string ("taskbar", "align", alignment.id ());
            file.set_string ("taskbar", "size", thickness.id ());
            file.set_string ("taskbar", "monitor", monitor);
            file.set_boolean ("taskbar", "autohide", autohide);
            file.set_boolean ("clock", "calendar_collapsed",
                              calendar_collapsed);
            file.set_integer ("picker", "x", picker_x);
            file.set_integer ("picker", "y", picker_y);
            file.set_string ("picker", "size", picker_size);
            file.set_boolean ("usb", "sync", usb_sync);
            Config.save (file);
        }

        /* To re-read a change coming from Settings as freshly written to
         * disk: refreshes the singleton instance. */
        public static void reload () {
            instance = load ();
        }
    }
}
