/* Hardware presence probes (battery, AC, backlight) via sysfs. */

namespace Kavis.Settings.Hw {

    /* Is there a battery? Decides the Power page layout (madde 51). */
    public bool has_battery () {
        try {
            var dir = Dir.open ("/sys/class/power_supply");
            string? name;
            while ((name = dir.read_name ()) != null) {
                if (name.has_prefix ("BAT")) {
                    return true;
                }
            }
        } catch (FileError e) { }
        return false;
    }

    /* On AC right now? No battery = always on AC. */
    public bool on_ac () {
        if (!has_battery ()) {
            return true;
        }
        try {
            var dir = Dir.open ("/sys/class/power_supply");
            string? name;
            while ((name = dir.read_name ()) != null) {
                if (name.has_prefix ("BAT")) {
                    continue;
                }
                string status;
                try {
                    FileUtils.get_contents (
                        "/sys/class/power_supply/%s/online".printf (name),
                        out status);
                    if (status.strip () == "1") {
                        return true;
                    }
                } catch (Error e) { }
            }
        } catch (FileError e) { }
        return false;
    }
}
