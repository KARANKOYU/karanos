/* Quick-settings backends (business logic — no widget code).
 *
 * Madde 37: wifi, bluetooth, night light, game mode, brightness.
 * Every backend probes its tool/sysfs path and reports availability;
 * a missing tool hides the toggle instead of erroring (same rule as
 * the battery indicator on desktops). All writes are fire-and-forget
 * child processes — the panel never blocks on a toggle.
 */

namespace Kavis.Quick {

    private void run_async (string[] argv) {
        try {
            Process.spawn_async (null, argv, null,
                SpawnFlags.SEARCH_PATH
                | SpawnFlags.STDOUT_TO_DEV_NULL
                | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
        } catch (Error e) {
            warning ("kavis-panel: %s calistirilamadi: %s",
                     argv[0], e.message);
        }
    }

    private string? run_capture (string[] argv) {
        try {
            string output;
            int status;
            Process.spawn_sync (null, argv, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, out output, null, out status);
            if (status != 0) {
                return null;
            }
            return output;
        } catch (Error e) {
            return null;
        }
    }

    private bool has_program (string name) {
        return Environment.find_program_in_path (name) != null;
    }

    /* --- Wi-Fi (NetworkManager) -------------------------------------- */

    public bool wifi_available () {
        return has_program ("nmcli");
    }

    public bool wifi_enabled () {
        string? output = run_capture ({ "nmcli", "radio", "wifi" });
        return output != null && output.strip () == "enabled";
    }

    public void wifi_set (bool enabled) {
        run_async ({ "nmcli", "radio", "wifi", enabled ? "on" : "off" });
    }

    /* --- Bluetooth (rfkill) ------------------------------------------ */

    public bool bluetooth_available () {
        if (!has_program ("rfkill")) {
            return false;
        }
        string? output = run_capture ({ "rfkill", "list", "bluetooth" });
        return output != null && output.strip ().length > 0;
    }

    public bool bluetooth_enabled () {
        string? output = run_capture ({ "rfkill", "list", "bluetooth" });
        if (output == null) {
            return false;
        }
        return !("Soft blocked: yes" in output);
    }

    public void bluetooth_set (bool enabled) {
        run_async ({ "rfkill", enabled ? "unblock" : "block", "bluetooth" });
    }

    /* --- Gece modu (xsct — X renk sıcaklığı) --------------------------- */
    /* Durum X'ten geri OKUNAMAZ (xsct yazar, sorgulamaz); oturum içi
     * bellekte tutulur. Kalıcılık ve zamanlama madde 10/38'in işi. */

    private bool night_on = false;
    private const string NIGHT_TEMPERATURE = "4500";

    public bool night_available () {
        return has_program ("xsct");
    }

    public bool night_enabled () {
        return night_on;
    }

    public void night_set (bool enabled) {
        night_on = enabled;
        if (enabled) {
            run_async ({ "xsct", NIGHT_TEMPERATURE });
        } else {
            run_async ({ "xsct" });   /* argümansız: 6500K'ya döner */
        }
    }

    /* --- Oyun Modu (madde 13'e köprü) --------------------------------- */
    /* Şimdilik yalnız durum dosyası: ~/.config/kavis/gamemode. Grup
     * H'nin oyun modu servisi bu dosyayı okuyup gerçek işi yapacak;
     * düğme o güne kadar da durumu doğru gösterir. */

    private string gamemode_path () {
        return Path.build_filename (
            Environment.get_user_config_dir (), "kavis", "gamemode");
    }

    public bool gamemode_enabled () {
        string contents;
        try {
            FileUtils.get_contents (gamemode_path (), out contents);
        } catch (Error e) {
            return false;
        }
        return contents.strip () == "on";
    }

    public void gamemode_set (bool enabled) {
        string path = gamemode_path ();
        DirUtils.create_with_parents (Path.get_dirname (path), 0755);
        try {
            FileUtils.set_contents (path, enabled ? "on\n" : "off\n");
        } catch (Error e) {
            warning ("kavis-panel: gamemode durumu yazilamadi: %s",
                     e.message);
        }
    }

    /* --- Parlaklık (sysfs backlight) ---------------------------------- */

    private string? backlight_dir_cache = null;
    private bool backlight_probed = false;

    private string? backlight_dir () {
        if (backlight_probed) {
            return backlight_dir_cache;
        }
        backlight_probed = true;
        try {
            var dir = Dir.open ("/sys/class/backlight");
            unowned string? name = dir.read_name ();
            if (name != null) {
                backlight_dir_cache =
                    Path.build_filename ("/sys/class/backlight", name);
            }
        } catch (Error e) {
            backlight_dir_cache = null;
        }
        return backlight_dir_cache;
    }

    public bool brightness_available () {
        return backlight_dir () != null;
    }

    private int read_int_file (string path) {
        string contents;
        try {
            FileUtils.get_contents (path, out contents);
        } catch (Error e) {
            return -1;
        }
        return int.parse (contents.strip ());
    }

    /* 0-100; -1 when unreadable. */
    public int brightness_percent () {
        string? dir = backlight_dir ();
        if (dir == null) {
            return -1;
        }
        int current = read_int_file (Path.build_filename (dir, "brightness"));
        int max = read_int_file (Path.build_filename (dir, "max_brightness"));
        if (current < 0 || max <= 0) {
            return -1;
        }
        return current * 100 / max;
    }

    public void brightness_set (int percent) {
        /* brightnessctl, yetki işini udev kurallarıyla çözer (sysfs'e
         * doğrudan yazmak root ister). Yoksa deneme yine yapılır ama
         * sessizce başarısız olabilir — kaydırıcı zaten yalnız
         * backlight varken görünür. */
        if (has_program ("brightnessctl")) {
            run_async ({ "brightnessctl", "set", "%d%%".printf (percent) });
            return;
        }
        string? dir = backlight_dir ();
        if (dir == null) {
            return;
        }
        int max = read_int_file (Path.build_filename (dir, "max_brightness"));
        if (max <= 0) {
            return;
        }
        try {
            FileUtils.set_contents (
                Path.build_filename (dir, "brightness"),
                "%d".printf (int.max (1, percent * max / 100)));
        } catch (Error e) {
            /* yetki yoksa sessiz: kaydırıcı görünür ama etkisiz kalır */
        }
    }
}
