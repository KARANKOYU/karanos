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

    /* 4E: gösterge için GERÇEK ağ durumu. nmcli'nin varlığı donanım
     * demek değil (VM'de Wi-Fi yokken bağlı görünüyordu) — aygıt
     * listesi okunur. Öncelik W11 gibi: kablolu BAĞLIYSA kablolu
     * ikonu; değilse Wi-Fi donanımı varsa onun durumu; o da yoksa
     * kablolu donanımın durumu; hiç aygıt yoksa gösterge gizli. */
    public enum NetKind { NONE, WIFI, WIRED }
    public struct NetStatus {
        public NetKind kind;
        public bool connected;
    }

    public NetStatus net_status () {
        NetStatus status = { NetKind.NONE, false };
        string? output = run_capture (
            { "nmcli", "-t", "-f", "TYPE,STATE", "dev" });
        if (output == null) {
            return status;
        }
        bool wifi_hw = false, wired_hw = false;
        bool wifi_up = false, wired_up = false;
        foreach (unowned string line in output.split ("\n")) {
            var parts = line.split (":");
            if (parts.length < 2) {
                continue;
            }
            /* STATE "connected" ya da "connected (externally)". */
            bool up = parts[1].has_prefix ("connected");
            if (parts[0] == "wifi") {
                wifi_hw = true;
                wifi_up = wifi_up || up;
            } else if (parts[0] == "ethernet") {
                wired_hw = true;
                wired_up = wired_up || up;
            }
        }
        if (wired_up) {
            status.kind = NetKind.WIRED;
            status.connected = true;
        } else if (wifi_hw) {
            status.kind = NetKind.WIFI;
            status.connected = wifi_up;
        } else if (wired_hw) {
            status.kind = NetKind.WIRED;
            status.connected = false;
        }
        return status;
    }

    public bool wifi_enabled () {
        string? output = run_capture ({ "nmcli", "radio", "wifi" });
        return output != null && output.strip () == "enabled";
    }

    public void wifi_set (bool enabled) {
        run_async ({ "nmcli", "radio", "wifi", enabled ? "on" : "off" });
    }

    /* Bağlı Wi-Fi ağının adı; bağlı değilken boş. Kutucuk etiketi
     * olarak gösterilir (W11 davranışı). */
    public string wifi_ssid () {
        string? output = run_capture (
            { "nmcli", "-t", "-f", "active,ssid", "dev", "wifi" });
        if (output == null) {
            return "";
        }
        foreach (unowned string line in output.split ("\n")) {
            if (line.has_prefix ("yes:")) {
                return line.substring (4);
            }
        }
        return "";
    }

    public struct WifiNetwork {
        public string ssid;
        public bool active;
        public int signal;
    }

    /* Görünür ağlar (nmcli'nin önbelleğinden — tarama başlatmaz,
     * hızlı döner). Alt panel listesi için. */
    public WifiNetwork[] wifi_networks () {
        WifiNetwork[] result = {};
        string? output = run_capture (
            { "nmcli", "-t", "-f", "in-use,ssid,signal", "dev", "wifi" });
        if (output == null) {
            return result;
        }
        foreach (unowned string line in output.split ("\n")) {
            string[] parts = line.split (":");
            if (parts.length < 3 || parts[1] == "") {
                continue;
            }
            /* Aynı SSID birden çok bantta görünür; ilkini tut. */
            bool seen = false;
            foreach (unowned WifiNetwork known in result) {
                if (known.ssid == parts[1]) {
                    seen = true;
                    break;
                }
            }
            if (seen) {
                continue;
            }
            WifiNetwork network = {
                parts[1], parts[0] == "*", int.parse (parts[2])
            };
            result += network;
        }
        return result;
    }

    /* Kayıtlı ya da şifresiz ağa bağlanır. Şifre isteyen yeni ağın
     * diyaloğu Ayarlar'ın işi (Grup F) — burada deneme başarısızsa
     * nmcli sessizce düşer. */
    public void wifi_connect (string ssid) {
        run_async ({ "nmcli", "dev", "wifi", "connect", ssid });
    }

    public void wifi_disconnect () {
        run_async ({ "nmcli", "con", "down", "id", wifi_ssid () });
    }

    /* --- Uçak modu (rfkill hepsi) ------------------------------------- */

    public bool airplane_available () {
        return has_program ("rfkill");
    }

    /* Uçak modu = hiçbir telsiz açık değil. */
    public bool airplane_enabled () {
        string? output = run_capture ({ "rfkill", "list" });
        if (output == null || output.strip () == "") {
            return false;
        }
        return !("Soft blocked: no" in output);
    }

    public void airplane_set (bool enabled) {
        run_async ({ "rfkill", enabled ? "block" : "unblock", "all" });
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

    /* Eşleştirilmiş cihaz listesi (bluetoothctl varsa; yoksa kutucuğun
     * "›" bölümü hiç görünmez — araç yoklama kuralı). */
    public bool bluetooth_list_available () {
        return has_program ("bluetoothctl");
    }

    public struct BtDevice {
        public string address;
        public string name;
    }

    public BtDevice[] bluetooth_devices () {
        BtDevice[] result = {};
        string? output = run_capture ({ "bluetoothctl", "devices" });
        if (output == null) {
            return result;
        }
        foreach (unowned string line in output.split ("\n")) {
            /* "Device AA:BB:CC:DD:EE:FF Ad" */
            string[] parts = line.split (" ", 3);
            if (parts.length == 3 && parts[0] == "Device") {
                BtDevice device = { parts[1], parts[2] };
                result += device;
            }
        }
        return result;
    }

    public void bluetooth_connect (string address) {
        run_async ({ "bluetoothctl", "connect", address });
    }

    /* --- Ses çıkış aygıtları (pactl — PipeWire/Pulse) ------------------ */

    public bool sound_output_available () {
        return has_program ("pactl");
    }

    public struct SoundOutput {
        public string name;         /* pactl iç adı */
        public string description;  /* insan okur ad */
        public bool active;
    }

    /* Kısa liste (id\tad\t...) + varsayılan sink adı. İnsan-okur
     * açıklama `pactl list sinks` çözümlemesi ister; alt panele iç ad
     * yeter, zengin adlar Ayarlar Ses sayfasının işi (Grup F). */
    public SoundOutput[] sound_outputs () {
        SoundOutput[] result = {};
        string? default_sink = run_capture (
            { "pactl", "get-default-sink" });
        string active_name = (default_sink ?? "").strip ();
        string? output = run_capture ({ "pactl", "list", "short",
                                        "sinks" });
        if (output == null) {
            return result;
        }
        foreach (unowned string line in output.split ("\n")) {
            string[] parts = line.split ("\t");
            if (parts.length >= 2) {
                SoundOutput sink = {
                    parts[1], parts[1], parts[1] == active_name
                };
                result += sink;
            }
        }
        return result;
    }

    public void sound_set_output (string name) {
        run_async ({ "pactl", "set-default-sink", name });
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

    /* 3C: ortak backend'e delege — donanım yoksa xrandr yazılım
     * parlaklığı, değer kavis.conf'ta; kaydırıcı artık HEP görünür. */
    public int brightness_percent () {
        return Brightness.percent ();
    }

    public void brightness_set (int percent) {
        Brightness.set_percent (percent);
    }
}
