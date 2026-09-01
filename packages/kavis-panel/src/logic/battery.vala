/* Battery state (business logic — no widget code here).
 *
 * Reads /sys/class/power_supply directly; no daemon dependency. On a
 * desktop machine without a battery `present()` is false and the UI
 * hides everything battery-related (stage 4 rule).
 */

namespace Kavis.Battery {

    private const string SYSFS_ROOT = "/sys/class/power_supply";

    /* Cached on first use; batteries do not come and go at runtime
     * often enough to justify rescanning every poll. */
    private string? battery_path = null;
    private bool scanned = false;

    /* Path of the first battery with a capacity file, or null. */
    public unowned string? find () {
        if (scanned) {
            return battery_path;
        }
        scanned = true;
        try {
            var dir = Dir.open (SYSFS_ROOT);
            string? entry;
            while ((entry = dir.read_name ()) != null) {
                if (entry.has_prefix ("BAT")) {
                    var candidate = SYSFS_ROOT + "/" + entry;
                    if (FileUtils.test (candidate + "/capacity",
                                        FileTest.EXISTS)) {
                        battery_path = candidate;
                        break;
                    }
                }
            }
        } catch (FileError e) {
            /* No directory means no battery — the normal desktop
             * path, not an error. */
        }
        return battery_path;
    }

    public bool present () {
        return find () != null;
    }

    /* Charge percentage 0-100, or -1 when unreadable. */
    public int percent () {
        unowned string? path = find ();
        if (path == null) {
            return -1;
        }
        try {
            string value;
            FileUtils.get_contents (path + "/capacity", out value);
            return int.parse (value.strip ());
        } catch (FileError e) {
            return -1;
        }
    }

    public bool charging () {
        unowned string? path = find ();
        if (path == null) {
            return false;
        }
        try {
            string value;
            FileUtils.get_contents (path + "/status", out value);
            return value.strip () == "Charging";
        } catch (FileError e) {
            return false;
        }
    }

    /* Whether the machine currently runs on external power. Charging
     * or Full both mean plugged in; "Discharging"/"Not charging" on
     * some firmwares still reports Full at 100 %, so the status file
     * is the best signal available without a power daemon. */
    public bool on_ac () {
        unowned string? path = find ();
        if (path == null) {
            return true;    /* no battery — a wall-powered machine */
        }
        try {
            string value;
            FileUtils.get_contents (path + "/status", out value);
            var status = value.strip ();
            return status != "Discharging";
        } catch (FileError e) {
            return true;
        }
    }

    private long read_long (string path) {
        try {
            string value;
            FileUtils.get_contents (path, out value);
            return long.parse (value.strip ());
        } catch (FileError e) {
            return -1;
        }
    }

    /* Estimated minutes until empty (discharging) or full (charging);
     * -1 when the kernel exposes no usable rate. Uses energy_* (µWh)
     * when present, charge_* (µAh) otherwise. */
    public int minutes_remaining () {
        unowned string? path = find ();
        if (path == null) {
            return -1;
        }
        long level = read_long (path + "/energy_now");
        long full = read_long (path + "/energy_full");
        long rate = read_long (path + "/power_now");
        if (level < 0 || rate <= 0) {
            level = read_long (path + "/charge_now");
            full = read_long (path + "/charge_full");
            rate = read_long (path + "/current_now");
        }
        if (level < 0 || rate <= 0) {
            return -1;
        }
        long togo = charging () ? (full - level) : level;
        if (togo < 0) {
            return -1;
        }
        return (int) (togo * 60 / rate);
    }
}
