/* Power plans (business logic — no widget code here).
 *
 * KANONİK KOPYA BURASI — build-packages.sh panel ve Ayarlar'a kopyalar.
 *
 * One plan per power source (plugged in / on battery). Madde 51: four
 * modes — Efficiency / Normal / Performance / Game (Game maps to the
 * performance profile until Grup H wires game-specific bits). The
 * choice persists in kavis.conf [power] (old power.conf imported once)
 * and is applied through powerprofilesctl when present; without it the
 * choice is stored only. Callers pass whether the machine is on AC —
 * this file must not depend on the panel's Battery backend. */

namespace Kavis.PowerPlan {

    public enum Plan {
        SAVER,
        NORMAL,
        PERFORMANCE,
        GAME;

        /* Config-file token. */
        public unowned string id () {
            switch (this) {
            case PERFORMANCE: return "performance";
            case SAVER:       return "saver";
            case GAME:        return "game";
            default:          return "normal";
            }
        }

        public static Plan from_id (string id) {
            switch (id) {
            case "performance": return PERFORMANCE;
            case "saver":       return SAVER;
            case "game":        return GAME;
            default:            return NORMAL;
            }
        }
    }

    private string old_config_path () {
        return Path.build_filename (Environment.get_user_config_dir (),
                                    "kavis", "power.conf");
    }

    /* Stored plan for one power source; NORMAL when never chosen.
     * Reads kavis.conf [power]; falls back to the pre-1A power.conf. */
    public Plan get_plan (bool plugged) {
        unowned string key = plugged ? "plugged" : "battery";
        var file = Config.load ();
        try {
            return Plan.from_id (file.get_string ("power", key));
        } catch (Error e) { }
        try {
            string contents;
            FileUtils.get_contents (old_config_path (), out contents);
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix (key + "=")) {
                    return Plan.from_id (
                        line.substring (key.length + 1).strip ());
                }
            }
        } catch (FileError e) { }
        return Plan.NORMAL;
    }

    /* now_plugged: is the machine on AC right now — the caller knows
     * (panel: Battery.on_ac; Ayarlar: sysfs). */
    public void set_plan (bool plugged, Plan plan, bool now_plugged) {
        var file = Config.load ();
        file.set_string ("power", plugged ? "plugged" : "battery",
                         plan.id ());
        Config.save (file);
        if (plugged == now_plugged) {
            apply (plan);
        }
    }

    /* Best-effort immediate effect via power-profiles-daemon's CLI;
     * silently a no-op when the tool is absent. */
    public void apply (Plan plan) {
        unowned string profile;
        switch (plan) {
        case Plan.PERFORMANCE:
        case Plan.GAME:        profile = "performance"; break;
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
