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
            warning ("kavis-panel: could not run %s: %s",
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

    /* 4E: the REAL network state for the indicator. The presence of
     * nmcli does not mean hardware (a VM without Wi-Fi showed as
     * connected) — the device list is read. Priority like W11: if
     * wired is CONNECTED, the wired icon; else if Wi-Fi hardware
     * exists, its state; else the wired hardware's state; with no
     * device at all the indicator is hidden. */
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
            /* STATE is "connected" or "connected (externally)". */
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

    /* Name of the connected Wi-Fi network; empty when not connected.
     * Shown as the tile caption (W11 behaviour). */
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

    /* Visible networks (from nmcli's cache — starts no scan, returns
     * fast). For the subpage list. */
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
            /* The same SSID shows up on several bands; keep the first. */
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

    /* Connects to a saved or open network. The dialog for a new
     * network that asks for a password is Settings' job (Grup F) — if
     * the attempt fails here, nmcli quietly gives up. */
    public void wifi_connect (string ssid) {
        run_async ({ "nmcli", "dev", "wifi", "connect", ssid });
    }

    public void wifi_disconnect () {
        run_async ({ "nmcli", "con", "down", "id", wifi_ssid () });
    }

    /* --- Airplane mode (rfkill all) ----------------------------------- */

    public bool airplane_available () {
        return has_program ("rfkill");
    }

    /* Airplane mode = no radio is on. */
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

    /* Paired device list (if bluetoothctl exists; otherwise the tile's
     * "›" part is not shown at all — the tool-probe rule). */
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
            /* "Device AA:BB:CC:DD:EE:FF Name" */
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

    /* --- Sound output devices (pactl — PipeWire/Pulse) ----------------- */

    public bool sound_output_available () {
        return has_program ("pactl");
    }

    public struct SoundOutput {
        public string name;         /* pactl internal name */
        public string description;  /* human-readable name */
        public bool active;
    }

    /* Short list (id\tname\t...) + default sink name. A human-readable
     * description would need parsing `pactl list sinks`; the internal
     * name is enough for the subpage, rich names are the job of the
     * Settings Sound page (Grup F). */
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

    /* --- Night light (xsct — X colour temperature) --------------------- */
    /* F-Display: the state used to live in this process's memory, so it
     * forgot itself on logout and the toggle disagreed with Settings.
     * Both write the same kavis.conf key now and the scheduler in
     * NightLight applies it; the toggle is the master switch, the
     * schedule decides when it actually warms the screen. */

    public bool night_available () {
        return has_program ("xsct");
    }

    public bool night_enabled () {
        return Kavis.NightLight.enabled ();
    }

    public void night_set (bool enabled) {
        var file = Kavis.Config.load ();
        file.set_boolean ("display", "nightlight", enabled);
        Kavis.Config.save (file);
        Kavis.NightLight.apply_now ();
    }

    /* --- Game Mode (bridge to madde 13) ------------------------------- */
    /* For now only a state file: ~/.config/kavis/gamemode. Grup H's
     * game mode service will read this file and do the real work;
     * until then the button still shows the state correctly. */

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
            warning ("kavis-panel: could not write gamemode state: %s",
                     e.message);
        }
    }

    /* --- Brightness (sysfs backlight) --------------------------------- */

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

    /* 3C: delegates to the shared backend — without hardware, xrandr
     * software brightness with the value in kavis.conf; the slider is
     * now ALWAYS shown. */
    public int brightness_percent () {
        return Brightness.percent ();
    }

    public void brightness_set (int percent) {
        Brightness.set_percent (percent);
    }
}
