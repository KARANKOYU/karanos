/* Screen brightness backend (3C) — THIS IS THE CANONICAL COPY
 * (build-packages.sh copies it into the panel and Settings).
 *
 * Hardware path: /sys/class/backlight via brightnessctl — its own
 * udev rule grants the video group write access, so no pkexec (the
 * live user is in video). Software path (desktops/VMs, madde 3C: the
 * slider is NOT hidden): xrandr --brightness gamma multiplier mapped
 * 0.3–1.0, value remembered in kavis.conf [display] brightness.
 * Both paths persist to kavis.conf — the Settings Display page reads
 * the same key.
 */

namespace Kavis.Brightness {

    /* Is there real backlight hardware? Decides tooltip wording. */
    public bool hardware () {
        return backlight_dir () != null;
    }

    private string? backlight_dir () {
        try {
            var dir = Dir.open ("/sys/class/backlight");
            string? name = dir.read_name ();
            if (name != null) {
                return "/sys/class/backlight/" + name;
            }
        } catch (FileError e) { }
        return null;
    }

    private int read_int (string path) {
        try {
            string contents;
            FileUtils.get_contents (path, out contents);
            return int.parse (contents.strip ());
        } catch (Error e) {
            return -1;
        }
    }

    /* Current brightness 0-100. Software path reads the stored value
     * (reading xrandr's gamma multiplier back is fragile). */
    public int percent () {
        string? dir = backlight_dir ();
        if (dir != null) {
            int current = read_int (dir + "/brightness");
            int max = read_int (dir + "/max_brightness");
            if (current >= 0 && max > 0) {
                return current * 100 / max;
            }
        }
        try {
            return Config.load ()
                .get_integer ("display", "brightness")
                .clamp (10, 100);
        } catch (Error e) {
            return 100;
        }
    }

    public void set_percent (int percent) {
        int value = percent.clamp (10, 100);
        if (hardware ()) {
            try {
                Process.spawn_async (null, {
                    "brightnessctl", "set", "%d%%".printf (value)
                }, null, SpawnFlags.SEARCH_PATH
                   | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
            } catch (Error e) {
                warning ("kavis: brightnessctl: %s", e.message);
            }
        } else {
            /* Software brightness: 0.30-1.00 gamma multiplier on every
             * connected output. Full blackout is deliberately absent
             * (so the screen is not mistaken for "gone"). */
            double gamma = 0.3 + 0.7 * value / 100.0;
            foreach (string output in connected_outputs ()) {
                try {
                    Process.spawn_async (null, {
                        "xrandr", "--output", output,
                        "--brightness", "%.2f".printf (gamma)
                    }, null, SpawnFlags.SEARCH_PATH
                       | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
                } catch (Error e) { }
            }
        }
        /* Single source (3C): Settings > Display reads the same key. */
        var file = Config.load ();
        file.set_integer ("display", "brightness", value);
        Config.save (file);
    }

    private string[] connected_outputs () {
        string[] result = {};
        try {
            string output;
            Process.spawn_sync (null, { "xrandr" }, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, out output);
            foreach (unowned string line in output.split ("\n")) {
                if (!line.has_prefix (" ")
                    && line.contains (" connected")) {
                    result += line.split (" ")[0];
                }
            }
        } catch (Error e) { }
        return result;
    }
}
