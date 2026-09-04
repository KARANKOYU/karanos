/* Hardware / system facts — ONE reader for Settings > About and the
 * Task Manager's Performance tab (v0.4-test1 H4: two apps read the
 * same data from the same place).
 *
 * THIS IS THE CANONICAL COPY — build-packages.sh copies it
 * (kavis-settings src/logic, kavis-taskmanager src); the copies are in
 * .gitignore.
 *
 * Everything comes from /proc, /sys and a few always-present tools
 * (lspci, ip, uname); nothing needs root. Values that DO need root
 * (dmidecode memory speed/type) are reported as "" and the UI shows a
 * dash — no pkexec prompt for a status page.
 */

namespace Kavis.SysInfo {

    public struct Fact {
        public string label;
        public string value;
    }

    /* --- helpers ------------------------------------------------------ */

    public string? capture (string[] argv) {
        try {
            string output;
            int status;
            Process.spawn_sync (null, argv, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, out output, null, out status);
            return (status == 0) ? output : null;
        } catch (Error e) {
            return null;
        }
    }

    public string read_file (string path) {
        try {
            string contents;
            FileUtils.get_contents (path, out contents);
            return contents.strip ();
        } catch (Error e) {
            return "";
        }
    }

    private int64 read_int64 (string path) {
        string s = read_file (path);
        return (s == "") ? -1 : int64.parse (s);
    }

    private string proc_field (string path, string key) {
        foreach (unowned string line in read_file (path).split ("\n")) {
            if (line.has_prefix (key)) {
                int colon = line.index_of (":");
                if (colon > 0) {
                    return line.substring (colon + 1).strip ();
                }
            }
        }
        return "";
    }

    public string format_bytes (uint64 bytes) {
        if (bytes >= 1024UL * 1024 * 1024) {
            return "%.1f GB".printf (bytes / 1073741824.0);
        }
        if (bytes >= 1024UL * 1024) {
            return "%.0f MB".printf (bytes / 1048576.0);
        }
        return "%.0f KB".printf (bytes / 1024.0);
    }

    /* --- os / brand ---------------------------------------------------- */

    public string os_release_value (string key) {
        foreach (unowned string line in read_file ("/etc/os-release").split ("\n")) {
            if (line.has_prefix (key + "=")) {
                return line.substring (key.length + 1).replace ("\"", "");
            }
        }
        return "?";
    }

    public string kernel () {
        string? o = capture ({ "uname", "-r" });
        return (o != null) ? o.strip () : "?";
    }

    /* --- cpu ---------------------------------------------------------- */

    public string cpu_model () {
        string m = proc_field ("/proc/cpuinfo", "model name");
        if (m == "") {
            m = proc_field ("/proc/cpuinfo", "Model");   /* arm */
        }
        return (m != "") ? m : "?";
    }

    /* threads = logical CPUs, cores = physical ("cpu cores" line;
     * falls back to threads when the field is missing, e.g. arm). */
    public void cpu_topology (out int cores, out int threads) {
        threads = (int) get_num_processors ();
        string c = proc_field ("/proc/cpuinfo", "cpu cores");
        cores = (c != "") ? int.parse (c) : threads;
    }

    /* Current MHz per logical CPU (cpufreq sysfs; /proc fallback). */
    public int[] cpu_freq_mhz () {
        int n = (int) get_num_processors ();
        int[] result = new int[n];
        bool any = false;
        for (int i = 0; i < n; i++) {
            int64 khz = read_int64 (
                "/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq".printf (i));
            if (khz > 0) {
                result[i] = (int) (khz / 1000);
                any = true;
            }
        }
        if (!any) {
            int i = 0;
            foreach (unowned string line in read_file ("/proc/cpuinfo").split ("\n")) {
                if (line.has_prefix ("cpu MHz") && i < n) {
                    result[i++] = (int) double.parse (
                        line.substring (line.index_of (":") + 1).strip ());
                }
            }
        }
        return result;
    }

    /* Base (max) MHz — cpufreq's cpuinfo_max_freq, else 0. */
    public int cpu_base_mhz () {
        int64 khz = read_int64 (
            "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq");
        return (khz > 0) ? (int) (khz / 1000) : 0;
    }

    /* hwmon temperature by driver name; -1 when absent. */
    private double hwmon_temp (string[] names) {
        try {
            var dir = Dir.open ("/sys/class/hwmon");
            string? entry;
            while ((entry = dir.read_name ()) != null) {
                string hw = "/sys/class/hwmon/" + entry;
                string name = read_file (hw + "/name");
                foreach (unowned string wanted in names) {
                    if (name == wanted) {
                        int64 milli = read_int64 (hw + "/temp1_input");
                        if (milli > 0) {
                            return milli / 1000.0;
                        }
                    }
                }
            }
        } catch (Error e) { }
        return -1;
    }

    public double cpu_temp () {
        double t = hwmon_temp ({ "coretemp", "k10temp", "zenpower",
                                 "cpu_thermal", "cpu-thermal" });
        if (t < 0) {
            int64 milli = read_int64 ("/sys/class/thermal/thermal_zone0/temp");
            if (milli > 0) {
                t = milli / 1000.0;
            }
        }
        return t;
    }

    /* /proc/stat first line: (busy, total) jiffies. */
    public void cpu_jiffies (out uint64 busy, out uint64 total) {
        busy = 0; total = 0;
        string[] f = read_file ("/proc/stat").split ("\n")[0].split (" ");
        uint64[] v = {};
        foreach (unowned string s in f[1:f.length]) {
            if (s != "") {
                v += uint64.parse (s);
            }
        }
        if (v.length < 4) {
            return;
        }
        foreach (uint64 x in v) {
            total += x;
        }
        /* idle + iowait count as idle */
        busy = total - v[3] - ((v.length > 4) ? v[4] : 0);
    }

    /* Per-logical-CPU jiffies: the "cpu0", "cpu1", … lines of /proc/stat,
     * in order. Same idle accounting as cpu_jiffies (idle + iowait).
     * Task Manager's Performance page draws one small graph per entry. */
    public void cpu_jiffies_per_core (out uint64[] busy, out uint64[] total) {
        /* Vala forbids += on an out parameter, so the lists are built
         * locally and handed over at the end. */
        uint64[] busy_list = {};
        uint64[] total_list = {};
        foreach (unowned string line in read_file ("/proc/stat").split ("\n")) {
            if (!line.has_prefix ("cpu") || line.has_prefix ("cpu ")) {
                continue;
            }
            string[] f = line.split (" ");
            uint64[] v = {};
            foreach (unowned string field in f[1:f.length]) {
                if (field != "") {
                    v += uint64.parse (field);
                }
            }
            if (v.length < 4) {
                continue;
            }
            uint64 t = 0;
            foreach (uint64 x in v) {
                t += x;
            }
            total_list += t;
            busy_list += t - v[3] - ((v.length > 4) ? v[4] : 0);
        }
        busy = busy_list;
        total = total_list;
    }

    public double uptime_seconds () {
        string s = read_file ("/proc/uptime").split (" ")[0];
        return (s != "") ? double.parse (s) : 0;
    }

    public void process_counts (out int processes, out int threads) {
        processes = 0; threads = 0;
        try {
            var dir = Dir.open ("/proc");
            string? entry;
            while ((entry = dir.read_name ()) != null) {
                if (int.parse (entry) <= 0) {
                    continue;
                }
                processes++;
                string t = proc_field ("/proc/" + entry + "/status", "Threads");
                if (t != "") {
                    threads += int.parse (t);
                }
            }
        } catch (Error e) { }
    }

    /* --- memory -------------------------------------------------------- */

    private uint64 meminfo_kb (string key) {
        string v = proc_field ("/proc/meminfo", key);
        return (v != "") ? uint64.parse (v.replace ("kB", "").strip ()) : 0;
    }

    public string mem_total () {
        uint64 kb = meminfo_kb ("MemTotal");
        return (kb > 0) ? "%.1f GB".printf (kb / 1048576.0) : "?";
    }

    public void memory (out uint64 total, out uint64 used, out uint64 cached,
                        out uint64 swap_total, out uint64 swap_used) {
        total = meminfo_kb ("MemTotal") * 1024;
        uint64 avail = meminfo_kb ("MemAvailable") * 1024;
        used = (total > avail) ? total - avail : 0;
        cached = (meminfo_kb ("Cached") + meminfo_kb ("Buffers")) * 1024;
        swap_total = meminfo_kb ("SwapTotal") * 1024;
        swap_used = swap_total - meminfo_kb ("SwapFree") * 1024;
    }

    /* --- board / gpu / disk -------------------------------------------- */

    public string board () {
        string vendor = read_file ("/sys/class/dmi/id/board_vendor");
        string name = read_file ("/sys/class/dmi/id/board_name");
        string bios = read_file ("/sys/class/dmi/id/bios_version");
        if (vendor == "" && name == "") {
            return "";
        }
        return "%s %s%s".printf (vendor, name,
                                 (bios != "") ? " (BIOS " + bios + ")" : "");
    }

    public string gpu_model () {
        string? output = capture ({ "sh", "-c",
            "lspci 2>/dev/null | grep -i 'vga\\|3d controller' | head -1" });
        if (output == null || output.strip () == "") {
            return "?";
        }
        int colon = output.last_index_of (": ");
        return (colon >= 0) ? output.substring (colon + 2).strip ()
                            : output.strip ();
    }

    /* amdgpu sysfs or nvidia-smi; percent/vram/temp are -1 when the
     * driver exposes nothing (intel, VM). */
    public void gpu_stats (out int busy_percent, out int64 vram_used,
                           out int64 vram_total, out double temp) {
        busy_percent = -1; vram_used = -1; vram_total = -1; temp = -1;
        for (int card = 0; card < 4; card++) {
            string dev = "/sys/class/drm/card%d/device".printf (card);
            int64 busy = read_int64 (dev + "/gpu_busy_percent");
            if (busy < 0) {
                continue;
            }
            busy_percent = (int) busy;
            vram_used = read_int64 (dev + "/mem_info_vram_used");
            vram_total = read_int64 (dev + "/mem_info_vram_total");
            temp = hwmon_temp ({ "amdgpu", "radeon" });
            return;
        }
        if (Environment.find_program_in_path ("nvidia-smi") != null) {
            string? o = capture ({ "nvidia-smi",
                "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu",
                "--format=csv,noheader,nounits" });
            if (o != null) {
                string[] f = o.strip ().split (",");
                if (f.length >= 4) {
                    busy_percent = int.parse (f[0].strip ());
                    vram_used = int64.parse (f[1].strip ()) * 1048576;
                    vram_total = int64.parse (f[2].strip ()) * 1048576;
                    temp = double.parse (f[3].strip ());
                }
            }
        }
    }

    public struct Disk {
        public string name;     /* sda, nvme0n1 */
        public string model;
        public uint64 size;
        public uint64 read_bytes;
        public uint64 write_bytes;
        public double temp;
    }

    public Disk[] disks () {
        Disk[] result = {};
        try {
            var dir = Dir.open ("/sys/block");
            string? entry;
            while ((entry = dir.read_name ()) != null) {
                if (entry.has_prefix ("loop") || entry.has_prefix ("ram")
                    || entry.has_prefix ("zram") || entry.has_prefix ("dm-")
                    || entry.has_prefix ("sr")) {
                    continue;
                }
                string blk = "/sys/block/" + entry;
                var d = Disk ();
                d.name = entry;
                d.model = read_file (blk + "/device/model");
                if (d.model == "") {
                    d.model = read_file (blk + "/device/name");
                }
                d.size = (uint64) int64.max (0, read_int64 (blk + "/size")) * 512;
                /* stat: rd_ios rd_merges rd_sectors rd_ticks wr_ios wr_merges wr_sectors ... */
                string[] f = {};
                foreach (unowned string s in read_file (blk + "/stat").split (" ")) {
                    if (s != "") {
                        f += s;
                    }
                }
                if (f.length >= 7) {
                    d.read_bytes = uint64.parse (f[2]) * 512;
                    d.write_bytes = uint64.parse (f[6]) * 512;
                }
                d.temp = entry.has_prefix ("nvme")
                    ? hwmon_temp ({ "nvme" }) : hwmon_temp ({ "drivetemp" });
                result += d;
            }
        } catch (Error e) { }
        return result;
    }

    public string disk_usage () {
        string? output = capture ({ "df", "-h", "--output=size,used", "/" });
        if (output == null) {
            return "?";
        }
        string[] lines = output.strip ().split ("\n");
        if (lines.length < 2) {
            return "?";
        }
        string[] fields = {};
        foreach (unowned string f in lines[1].split_set (" \t")) {
            if (f != "") {
                fields += f;
            }
        }
        return (fields.length >= 2)
            ? _("%s used of %s").printf (fields[1], fields[0]) : "?";
    }

    /* --- network -------------------------------------------------------- */

    public struct Iface {
        public string name;
        public uint64 rx_bytes;
        public uint64 tx_bytes;
    }

    public Iface[] interfaces () {
        Iface[] result = {};
        string[] lines = read_file ("/proc/net/dev").split ("\n");
        foreach (unowned string line in lines) {
            int colon = line.index_of (":");
            if (colon <= 0) {
                continue;
            }
            string name = line.substring (0, colon).strip ();
            if (name == "lo") {
                continue;
            }
            string[] f = {};
            foreach (unowned string s in line.substring (colon + 1).split (" ")) {
                if (s != "") {
                    f += s;
                }
            }
            if (f.length < 9) {
                continue;
            }
            result += Iface () { name = name,
                                 rx_bytes = uint64.parse (f[0]),
                                 tx_bytes = uint64.parse (f[8]) };
        }
        return result;
    }

    public string ip_of (string iface) {
        string? o = capture ({ "ip", "-4", "-o", "addr", "show", "dev", iface });
        if (o == null) {
            return "";
        }
        foreach (unowned string tok in o.split (" ")) {
            if (tok.contains (".") && tok.contains ("/")) {
                return tok.split ("/")[0];
            }
        }
        return "";
    }

    /* --- About page ----------------------------------------------------
     *
     * The About page is hierarchical (feedback F1): one group of facts
     * per hardware area, each group behind its own disclosure row. The
     * groups are built here so that the page and the "Copy details"
     * button always show the SAME set of values.
     *
     * A value that cannot be read is returned as an empty string; the
     * caller turns it into DASH. Nothing here asks for a password.
     */

    /* Placeholder for a value this machine does not expose. */
    public const string DASH = "—";

    /* A class, not a struct: a struct holding an array copies the
     * array pointer only. */
    public class Group : GLib.Object {
        public string title;
        public Fact[] facts;

        public Group (string title, Fact[] facts) {
            this.title = title;
            this.facts = facts;
        }
    }

    private string or_dash (string value) {
        return (value.strip () == "" || value == "?") ? DASH : value;
    }

    private string mhz_text (int mhz) {
        return (mhz > 0) ? "%.2f GHz".printf (mhz / 1000.0) : DASH;
    }

    /* "32K" / "1024K" / "16M" (sysfs cache size) -> KB. */
    private int64 cache_kb (string size) {
        string s = size.strip ();
        if (s == "") {
            return 0;
        }
        int64 value = int64.parse (s);
        if (s.has_suffix ("M")) {
            return value * 1024;
        }
        if (s.has_suffix ("G")) {
            return value * 1024 * 1024;
        }
        return value;   /* K, or a bare number of KB */
    }

    /* Per-level cache of cpu0. L1 has two entries (data +
     * instruction), so the sizes are summed per level. */
    public string cpu_cache () {
        int64[] level_kb = new int64[4];
        bool any = false;
        for (int i = 0; i < 16; i++) {
            string dir =
                "/sys/devices/system/cpu/cpu0/cache/index%d".printf (i);
            string level = read_file (dir + "/level");
            int64 kb = cache_kb (read_file (dir + "/size"));
            if (level == "" || kb <= 0) {
                continue;
            }
            int index = int.parse (level) - 1;
            if (index < 0 || index >= level_kb.length) {
                continue;
            }
            level_kb[index] += kb;
            any = true;
        }
        if (!any) {
            return "";
        }
        var text = new StringBuilder ();
        for (int i = 0; i < level_kb.length; i++) {
            if (level_kb[i] <= 0) {
                continue;
            }
            if (text.len > 0) {
                text.append ("   ");
            }
            text.append_printf ("L%d %s", i + 1,
                                format_bytes ((uint64) level_kb[i] * 1024));
        }
        return text.str;
    }

    /* Nominal (base) clock: intel_pstate's base_frequency, else the
     * "@ 3.60GHz" tail of the model name. 0 when neither exists. */
    public int cpu_nominal_mhz () {
        int64 khz = read_int64 (
            "/sys/devices/system/cpu/cpu0/cpufreq/base_frequency");
        if (khz > 0) {
            return (int) (khz / 1000);
        }
        string model = cpu_model ();
        int at = model.last_index_of ("@");
        if (at < 0) {
            return 0;
        }
        string tail = model.substring (at + 1).strip ().down ();
        double ghz = double.parse (tail.replace ("ghz", "").strip ());
        return (ghz > 0) ? (int) (ghz * 1000) : 0;
    }

    /* Kernel driver bound to the first render card ("amdgpu", "i915",
     * "virtio-pci", "vmwgfx"...). Empty when nothing is bound. */
    public string gpu_driver () {
        for (int card = 0; card < 8; card++) {
            string link = "/sys/class/drm/card%d/device/driver"
                .printf (card);
            if (!FileUtils.test (link, FileTest.EXISTS)) {
                continue;
            }
            try {
                return Path.get_basename (FileUtils.read_link (link));
            } catch (FileError e) { }
        }
        return "";
    }

    /* --- dmidecode (needs root) ----------------------------------------
     *
     * /dev/mem and /sys/firmware/dmi/tables are both root-only, so this
     * fails for a normal session and every field stays empty — a status
     * page must not pop a password prompt. In a VM the DMI memory
     * records are usually missing even for root.
     */
    public void memory_dmi (out string type, out string speed,
                            out string latency, out int slots_used,
                            out int slots_total) {
        type = ""; speed = ""; latency = "";
        slots_used = 0; slots_total = 0;
        string? output = capture ({ "dmidecode", "-t", "memory" });
        if (output == null) {
            output = capture ({ "/usr/sbin/dmidecode", "-t", "memory" });
        }
        if (output == null) {
            return;
        }
        bool populated = false;
        foreach (unowned string raw in output.split ("\n")) {
            string line = raw.strip ();
            if (line == "Memory Device") {
                slots_total++;
                populated = false;
                continue;
            }
            int colon = line.index_of (":");
            if (colon <= 0) {
                continue;
            }
            string key = line.substring (0, colon).strip ();
            string value = line.substring (colon + 1).strip ();
            switch (key) {
            case "Size":
                if (value != "" && !value.has_prefix ("No Module")) {
                    slots_used++;
                    populated = true;
                }
                break;
            case "Type":
                if (populated && type == "" && value.has_prefix ("DDR")) {
                    type = value;
                }
                break;
            case "Configured Memory Speed":
            case "Speed":
                if (populated && speed == "" && value != ""
                    && !value.has_prefix ("Unknown")) {
                    speed = value;
                }
                break;
            /* Not in SMBIOS type 17 today; parsed anyway so a firmware
             * that does report it lands in the right row. */
            case "CAS Latency":
            case "Configured CAS Latency":
                if (populated && latency == "") {
                    latency = value;
                }
                break;
            }
        }
    }

    /* Filesystems mounted from this disk's partitions ("ext4",
     * "ext4, vfat"). Empty when nothing of it is mounted. */
    public string disk_filesystem (string name) {
        var seen = new StringBuilder ();
        foreach (unowned string line in read_file ("/proc/mounts").split ("\n")) {
            string[] f = line.split (" ");
            if (f.length < 3 || !f[0].has_prefix ("/dev/" + name)) {
                continue;
            }
            if (seen.str.contains (f[2])) {
                continue;
            }
            if (seen.len > 0) {
                seen.append (", ");
            }
            seen.append (f[2]);
        }
        return seen.str;
    }

    public Fact[] os_facts () {
        Fact[] result = {};
        result += Fact () {
            label = _("Version"),
            value = "%s %s".printf (os_release_value ("NAME"),
                                    os_release_value ("VERSION_ID")) };
        result += Fact () { label = _("Kernel"), value = or_dash (kernel ()) };
        result += Fact () { label = _("Desktop"),
                            value = "%s (Openbox)".printf (os_release_value ("NAME")) };
        result += Fact () { label = _("Hostname"),
                            value = Environment.get_host_name () };
        string b = board ();
        if (b != "") {
            result += Fact () { label = _("Motherboard"), value = b };
        }
        return result;
    }

    public Fact[] cpu_facts () {
        int cores, threads;
        cpu_topology (out cores, out threads);
        int nominal = cpu_nominal_mhz ();
        int max = cpu_base_mhz ();     /* cpuinfo_max_freq = turbo ceiling */
        Fact[] result = {};
        result += Fact () { label = _("Model"), value = or_dash (cpu_model ()) };
        result += Fact () { label = _("Cores / threads"),
                            value = "%d / %d".printf (cores, threads) };
        result += Fact () { label = _("Base frequency"),
                            value = mhz_text (nominal) };
        result += Fact () { label = _("Turbo frequency"),
                            value = mhz_text (max) };
        result += Fact () { label = _("Cache"),
                            value = or_dash (cpu_cache ()) };
        return result;
    }

    public Fact[] gpu_facts () {
        int busy;
        int64 vram_used, vram_total;
        double temp;
        gpu_stats (out busy, out vram_used, out vram_total, out temp);
        Fact[] result = {};
        result += Fact () { label = _("Model"), value = or_dash (gpu_model ()) };
        result += Fact () { label = _("Driver"),
                            value = or_dash (gpu_driver ()) };
        result += Fact () { label = _("Video memory"),
                            value = (vram_total > 0)
                                ? format_bytes ((uint64) vram_total) : DASH };
        return result;
    }

    public Fact[] memory_facts () {
        string type, speed, latency;
        int used, total;
        memory_dmi (out type, out speed, out latency, out used, out total);
        Fact[] result = {};
        result += Fact () { label = _("Total"), value = or_dash (mem_total ()) };
        result += Fact () { label = _("Type"), value = or_dash (type) };
        result += Fact () { label = _("Speed"), value = or_dash (speed) };
        result += Fact () { label = _("CAS latency"),
                            value = or_dash (latency) };
        result += Fact () { label = _("Slots in use"),
                            value = (total > 0)
                                ? "%d / %d".printf (used, total) : DASH };
        return result;
    }

    public Fact[] disk_facts () {
        Fact[] result = {};
        Disk[] all = disks ();
        bool many = all.length > 1;
        foreach (unowned Disk d in all) {
            string prefix = many ? d.name + " — " : "";
            result += Fact () { label = prefix + _("Model"),
                                value = or_dash (d.model) };
            result += Fact () { label = prefix + _("Capacity"),
                                value = (d.size > 0)
                                    ? format_bytes (d.size) : DASH };
            result += Fact () { label = prefix + _("File system"),
                                value = or_dash (disk_filesystem (d.name)) };
        }
        result += Fact () { label = _("Usage"), value = or_dash (disk_usage ()) };
        return result;
    }

    /* Every group in page order. */
    public Group[] collect () {
        return {
            new Group (_("System"), os_facts ()),
            new Group (_("Processor"), cpu_facts ()),
            new Group (_("Graphics"), gpu_facts ()),
            new Group (_("Memory"), memory_facts ()),
            new Group (_("Disk"), disk_facts ())
        };
    }

    /* One plain-text block for the Copy details button. */
    public string report (Group[] groups) {
        var text = new StringBuilder ();
        foreach (unowned Group g in groups) {
            text.append_printf ("%s\n", g.title);
            foreach (unowned Fact f in g.facts) {
                text.append_printf ("  %s: %s\n", f.label, f.value);
            }
        }
        return text.str;
    }
}
