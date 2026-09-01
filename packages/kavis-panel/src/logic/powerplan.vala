/* Power plans (business logic — no widget code here).
 *
 * One plan per power source (plugged in / on battery), as in the
 * design. The choice persists in ~/.config/kavis/power.conf and, when
 * the machine is currently on the source whose plan changed, is
 * applied immediately through powerprofilesctl if that tool exists.
 * Without it the choice is stored only; full enforcement (governors,
 * thresholds) arrives with the power settings page (item 51, Grup F) —
 * the popup must not grow its own daemon.
 */

namespace Kavis.PowerPlan {

    public enum Plan {
        PERFORMANCE,
        NORMAL,
        SAVER;

        /* Config-file token; also the Strings key suffix. */
        public unowned string id () {
            switch (this) {
            case PERFORMANCE: return "performance";
            case SAVER:       return "saver";
            default:          return "normal";
            }
        }

        public static Plan from_id (string id) {
            switch (id) {
            case "performance": return PERFORMANCE;
            case "saver":       return SAVER;
            default:            return NORMAL;
            }
        }
    }

    private string config_path () {
        return Path.build_filename (Environment.get_user_config_dir (),
                                    "kavis", "power.conf");
    }

    /* Stored plan for one power source; NORMAL when never chosen. */
    public Plan get_plan (bool plugged) {
        unowned string key = plugged ? "plugged" : "battery";
        try {
            string contents;
            FileUtils.get_contents (config_path (), out contents);
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix (key + "=")) {
                    return Plan.from_id (line.substring (key.length + 1).strip ());
                }
            }
        } catch (FileError e) {
            /* Missing file = defaults; first write creates it. */
        }
        return Plan.NORMAL;
    }

    public void set_plan (bool plugged, Plan plan) {
        var contents = "plugged=%s\nbattery=%s\n".printf (
            (plugged ? plan : get_plan (true)).id (),
            (plugged ? get_plan (false) : plan).id ());
        var path = config_path ();
        DirUtils.create_with_parents (Path.get_dirname (path), 0755);
        try {
            FileUtils.set_contents (path, contents);
        } catch (FileError e) {
            warning ("kavis-panel: guc plani kaydedilemedi: %s", e.message);
        }
        if (plugged == Battery.on_ac ()) {
            apply (plan);
        }
    }

    /* Best-effort immediate effect via power-profiles-daemon's CLI;
     * silently a no-op when the tool is absent. */
    public void apply (Plan plan) {
        unowned string profile;
        switch (plan) {
        case Plan.PERFORMANCE: profile = "performance"; break;
        case Plan.SAVER:       profile = "power-saver"; break;
        default:               profile = "balanced";    break;
        }
        if (Environment.find_program_in_path ("powerprofilesctl") == null) {
            return;
        }
        try {
            Process.spawn_async (null,
                { "powerprofilesctl", "set", profile }, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, null);
        } catch (SpawnError e) {
            warning ("kavis-panel: powerprofilesctl calistirilamadi: %s",
                     e.message);
        }
    }
}
