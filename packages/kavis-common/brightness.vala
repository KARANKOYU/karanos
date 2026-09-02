/* Screen brightness backend (3C) — KANONİK KOPYA BURASI
 * (build-packages.sh panel ve Ayarlar'a kopyalar).
 *
 * Hardware path: /sys/class/backlight via brightnessctl — its own
 * udev rule grants the video group write access, so no pkexec (the
 * live user is in video). Software path (desktops/VMs, madde 3C:
 * kaydırıcı GİZLENMEZ): xrandr --brightness gamma multiplier mapped
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
     * (xrandr'ın gama çarpanını geri okumak kırılgan). */
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
            /* Yazılım parlaklığı: 0.30-1.00 gama çarpanı, bağlı her
             * çıkışa. Tam karartma bilerek yok (ekran "kayboldu"
             * sanılmasın). */
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
        /* Tek veri (3C): Ayarlar > Ekran aynı anahtarı okur. */
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
