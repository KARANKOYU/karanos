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
        /* Madde 63 "güvenli mod": USB'yi -o sync bağla. Varsayılan
         * KAPALI — hız bedeli var, açıklaması USB popup'ında. */
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
            /* Tek dosya (1A-2): kavis.conf; eski panel.conf ilk
             * yüklemede içe alınır ([panel] → [taskbar]). */
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
                config.calendar_collapsed =
                    file.get_boolean ("clock", "calendar_collapsed");
            } catch (Error e) { }
            try {
                config.picker_x = file.get_integer ("picker", "x");
                config.picker_y = file.get_integer ("picker", "y");
            } catch (Error e) { }
            try {
                config.usb_sync = file.get_boolean ("usb", "sync");
            } catch (Error e) { }
            return config;
        }

        public void save () {
            /* kavis.conf başka grupları da taşıyor ([clipboard],
             * [appearance]...); sıfırdan KeyFile onları sessizce
             * düşürürdü — önce yükle. */
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
            file.set_boolean ("usb", "sync", usb_sync);
            Config.save (file);
        }

        /* Ayarlar'dan gelen değişikliği diske yeni yazılmış hâliyle
         * yeniden okumak için: tekil örneği tazeler. */
        public static void reload () {
            instance = load ();
        }
    }
}
