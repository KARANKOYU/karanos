/* About-page facts (madde 45). Brand values come from /etc/os-release
 * (marka kuralı: ürün adı koda gömülmez), hardware from /proc-sysfs,
 * GPU from lspci.
 */

namespace Kavis.Settings.SysInfo {

    public struct Fact {
        public string label;
        public string value;
    }

    private string os_release_value (string key) {
        try {
            string contents;
            FileUtils.get_contents ("/etc/os-release", out contents);
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix (key + "=")) {
                    return line.substring (key.length + 1)
                               .replace ("\"", "");
                }
            }
        } catch (Error e) { }
        return "?";
    }

    private string cpu_model () {
        try {
            string contents;
            FileUtils.get_contents ("/proc/cpuinfo", out contents);
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix ("model name")) {
                    return line.substring (line.index_of (":") + 1)
                               .strip ();
                }
            }
        } catch (Error e) { }
        return "?";
    }

    private string mem_total () {
        try {
            string contents;
            FileUtils.get_contents ("/proc/meminfo", out contents);
            foreach (unowned string line in contents.split ("\n")) {
                if (line.has_prefix ("MemTotal:")) {
                    int64 kb = int64.parse (
                        line.replace ("MemTotal:", "")
                            .replace ("kB", "").strip ());
                    return "%.1f GB".printf (kb / 1024.0 / 1024.0);
                }
            }
        } catch (Error e) { }
        return "?";
    }

    private string gpu_model () {
        string? output = Run.capture ({ "sh", "-c",
            "lspci | grep -i 'vga\\|3d controller' | head -1" });
        if (output == null || output.strip () == "") {
            return "?";
        }
        int colon = output.last_index_of (": ");
        return (colon >= 0)
            ? output.substring (colon + 2).strip ()
            : output.strip ();
    }

    private string disk_usage () {
        string? output = Run.capture ({ "df", "-h",
                                        "--output=size,used", "/" });
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
            ? _("%s used of %s").printf (fields[1], fields[0])
            : "?";
    }

    private string kernel () {
        string? output = Run.capture ({ "uname", "-r" });
        return (output != null) ? output.strip () : "?";
    }

    /* Everything the About page shows, in display order. */
    public Fact[] collect () {
        Fact[] result = {};
        result += Fact () {
            label = _("Version"),
            value = "%s %s".printf (os_release_value ("NAME"),
                                    os_release_value ("VERSION_ID")) };
        result += Fact () { label = _("Kernel"), value = kernel () };
        result += Fact () { label = _("Desktop"),
                            value = "%s (Openbox)".printf (
                                os_release_value ("NAME")) };
        result += Fact () { label = _("Processor"), value = cpu_model () };
        result += Fact () { label = _("Memory"), value = mem_total () };
        result += Fact () { label = _("Graphics"), value = gpu_model () };
        result += Fact () { label = _("Disk"), value = disk_usage () };
        result += Fact () { label = _("Hostname"),
                            value = Environment.get_host_name () };
        return result;
    }
}
