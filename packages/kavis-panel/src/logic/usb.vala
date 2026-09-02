/* Removable-drive backend for the tray USB tool (business logic —
 * no widget code). Madde 3 düzeltmesi.
 *
 * Listing goes through lsblk (util-linux, always present); safe
 * removal through udisksctl (udisks2 — polkit lets the live/desktop
 * user unmount and power off without root). Ejecting flushes buffers
 * and can take seconds on slow sticks, so eject_sync() is meant to be
 * called from a worker thread, never the UI loop.
 */

namespace Kavis.Usb {

    public struct Device {
        public string node;    /* /dev/sdb */
        public string name;    /* human-readable: label or NAME (SIZE) */
    }

    public struct Partition {
        public string node;        /* /dev/sdb1 */
        public string mountpoint;  /* "" = not mounted */
    }

    private string? field (string line, string key) {
        /* lsblk -P satırı: NAME="sdb1" RM="1" ... */
        string marker = key + "=\"";
        int start = line.index_of (marker);
        if (start < 0) {
            return null;
        }
        start += marker.length;
        int end = line.index_of ("\"", start);
        if (end < 0) {
            return null;
        }
        return line.substring (start, end - start);
    }

    private string? run_capture (string[] argv) {
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

    /* Removable disks currently attached. The display name is the
     * first labeled partition, else "NAME (SIZE)". */
    public Device[] devices () {
        Device[] result = {};
        string? output = run_capture ({ "lsblk", "-Pno",
            "NAME,RM,TYPE,LABEL,SIZE,PKNAME,TRAN" });
        if (output == null) {
            return result;
        }
        string[] lines = output.split ("\n");
        foreach (unowned string line in lines) {
            if (field (line, "TYPE") != "disk"
                || !is_removable (line)) {
                continue;
            }
            string name = field (line, "NAME") ?? "";
            if (name == "") {
                continue;
            }
            string display = "";
            /* Bu diskin etiketli ilk bölümü. */
            foreach (unowned string part in lines) {
                if (field (part, "PKNAME") == name
                    && (field (part, "LABEL") ?? "") != "") {
                    display = field (part, "LABEL");
                    break;
                }
            }
            if (display == "") {
                display = "%s (%s)".printf (
                    name, field (line, "SIZE") ?? "");
            }
            Device device = { "/dev/" + name, display };
            result += device;
        }
        return result;
    }

    /* RM bayrağı tek başına yanıltıcı (udisks #358: eMMC "removable"
     * görünebilir) — USB veriyoluna takılı HER disk çıkarılabilir
     * sayılır, RM=1 de kalır (SD kart okuyucular TRAN vermez). */
    private bool is_removable (string line) {
        return field (line, "TRAN") == "usb"
            || field (line, "RM") == "1";
    }

    public bool present () {
        return devices ().length > 0;
    }

    /* Every partition of the removable disks, mounted or not — the
     * automount pass (madde 42) walks this. */
    public Partition[] partitions () {
        Partition[] result = {};
        string? output = run_capture ({ "lsblk", "-Pno",
            "NAME,RM,TYPE,MOUNTPOINT,PKNAME,TRAN" });
        if (output == null) {
            return result;
        }
        string[] lines = output.split ("\n");
        var disks = new GenericSet<string> (str_hash, str_equal);
        foreach (unowned string line in lines) {
            if (field (line, "TYPE") == "disk"
                && is_removable (line)) {
                disks.add (field (line, "NAME") ?? "");
            }
        }
        foreach (unowned string line in lines) {
            if (field (line, "TYPE") != "part"
                || !disks.contains (field (line, "PKNAME") ?? "?")) {
                continue;
            }
            Partition part = {
                "/dev/" + (field (line, "NAME") ?? ""),
                field (line, "MOUNTPOINT") ?? ""
            };
            result += part;
        }
        return result;
    }

    /* Mount one partition through udisks (polkit lets the desktop
     * user do this; the mountpoint lands under /media). BLOCKING —
     * worker thread only. Returns the mountpoint, or null. */
    public string? mount_sync (string part) {
        /* Çıktı: "Mounted /dev/sdb1 at /media/karan/ETIKET" (eski
         * udisks sona nokta koyardı). */
        string? output = run_capture ({ "udisksctl", "mount", "-b",
                                        part });
        if (output == null) {
            return null;
        }
        int at = output.last_index_of (" at ");
        if (at < 0) {
            return null;
        }
        string mountpoint = output.substring (at + 4).strip ();
        if (mountpoint.has_suffix (".")) {
            mountpoint = mountpoint.substring (0, mountpoint.length - 1);
        }
        return mountpoint;
    }

    /* Unmount every mounted partition of the disk, then power it off.
     * BLOCKING (buffer flush) — call from a worker thread. Returns
     * false when anything failed (the caller warns the user instead
     * of claiming the stick is safe to pull). */
    public bool eject_sync (string node) {
        bool have_udisks =
            Environment.find_program_in_path ("udisksctl") != null;
        string disk_name = Path.get_basename (node);
        string? output = run_capture ({ "lsblk", "-Pno",
            "NAME,MOUNTPOINT,PKNAME" });
        if (output == null) {
            return false;
        }
        foreach (unowned string line in output.split ("\n")) {
            if (field (line, "PKNAME") != disk_name
                || (field (line, "MOUNTPOINT") ?? "") == "") {
                continue;
            }
            string part = "/dev/" + field (line, "NAME");
            bool ok = have_udisks
                ? run_capture ({ "udisksctl", "unmount", "-b", part }) != null
                : run_capture ({ "umount", part }) != null;
            if (!ok) {
                return false;
            }
        }
        if (have_udisks) {
            /* Güç kesilmiş çubuk gönül rahatlığıyla çekilir; udisks
             * yoksa ayırma yeterli sayılır (yalnız bağı çözülmüş). */
            return run_capture ({ "udisksctl", "power-off", "-b",
                                  node }) != null;
        }
        return true;
    }
}
