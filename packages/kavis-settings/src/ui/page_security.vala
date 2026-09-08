/* Security page (feedback, 8 Sep 2026).
 *
 * "A security section — which application is reading my clipboard, or
 * antivirus, security things." Windows Security is a status board: a
 * row per area, each saying what state it is in and offering the one
 * action that changes it. That shape is right, and the reason is that
 * security settings are the ones people look at once a year — a page
 * that reads as a list of switches teaches nothing about whether the
 * machine is in good shape.
 *
 * EVERY ROW HERE IS MEASURED, not assumed. The kernel values are read
 * from /proc at the moment the page is built, Secure Boot from the
 * firmware variable, the clipboard log from the file the panel writes.
 * A security page that reports what the configuration INTENDED is
 * worse than none: it tells you you are safe because somebody wrote
 * that you would be.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget security (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        /* --- Status ------------------------------------------------- */
        var status = subsection (body, "status",
            Catalog.sub_title ("security", "status"));

        status.pack_start (check_row (_("Kernel hardening"),
            hardening_state ()), false, false, 0);
        status.pack_start (check_row (_("Secure Boot"),
            secure_boot_state ()), false, false, 0);
        status.pack_start (check_row (_("Screen lock"),
            lock_state ()), false, false, 0);
        status.pack_start (check_row (_("Firewall"),
            firewall_state ()), false, false, 0);

        /* --- Clipboard ---------------------------------------------- */
        var clip = subsection (body, "clipboard",
            Catalog.sub_title ("security", "clipboard"));

        var watch = new Gtk.Switch ();
        watch.active = conf_get_bool ("clipboard", "watch-reads", false);
        watch.notify["active"].connect (() => {
            conf_set_bool ("clipboard", "watch-reads", watch.active);
        });
        clip.pack_start (row (_("Watch clipboard reads"),
            _("Records which application reads the clipboard. Kavis has to hold the clipboard to see this, so a copy carrying formatting pastes as plain text while it is on."),
            watch), false, false, 0);

        var reads = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        fill_clipboard_reads (reads);
        clip.pack_start (reads, false, false, 0);

        var clear = new Gtk.Button.with_label (_("Clear the list"));
        clear.halign = Gtk.Align.START;
        clear.clicked.connect (() => {
            FileUtils.remove (clipboard_log ());
            fill_clipboard_reads (reads);
            reads.show_all ();
        });
        clip.pack_start (row (_("Clipboard read history"),
            _("Kept on this machine only, the last 200 reads"), clear),
            false, false, 0);

        /* --- Malware scan ------------------------------------------- */
        var scan = subsection (body, "scan",
            Catalog.sub_title ("security", "scan"));
        scan.pack_start (scan_row (), false, false, 0);

        return page;
    }

    /* A row whose right-hand side is a state, not a control. */
    private Gtk.Widget check_row (string title, string state) {
        var label = new Gtk.Label (state);
        label.set_line_wrap (true);
        label.set_max_width_chars (36);
        label.set_xalign (1);
        label.get_style_context ().add_class ("dim-label");
        return row (title, null, label);
    }

    /* The values item 8 sets, read back from the running kernel — the
     * file in /etc/sysctl.d that never got read looks exactly like the
     * one that works. */
    private string hardening_state () {
        string[,] wanted = {
            { "/proc/sys/kernel/kptr_restrict", "2" },
            { "/proc/sys/kernel/dmesg_restrict", "1" },
            { "/proc/sys/kernel/yama/ptrace_scope", "1" }
        };
        int ok = 0;
        int total = wanted.length[0];
        for (int i = 0; i < total; i++) {
            string value;
            try {
                FileUtils.get_contents (wanted[i, 0], out value);
            } catch (Error e) {
                total--;
                continue;
            }
            if (value.strip () == wanted[i, 1]) {
                ok++;
            }
        }
        if (total == 0) {
            return _("This kernel does not offer the settings");
        }
        return (ok == total)
            ? _("On — %d of %d kernel protections active").printf (ok, total)
            : _("Partly on — %d of %d").printf (ok, total);
    }

    /* The EFI variable, not the boot mode: a UEFI machine with Secure
     * Boot switched off is a different answer from a BIOS one. */
    private string secure_boot_state () {
        if (!FileUtils.test ("/sys/firmware/efi", FileTest.IS_DIR)) {
            return _("Not applicable — this machine booted in BIOS mode");
        }
        try {
            var dir = Dir.open ("/sys/firmware/efi/efivars");
            string? name;
            while ((name = dir.read_name ()) != null) {
                if (!name.has_prefix ("SecureBoot-")) {
                    continue;
                }
                uint8[] data;
                FileUtils.get_data (
                    "/sys/firmware/efi/efivars/" + name, out data);
                /* Four bytes of attributes, then the value. */
                if (data.length >= 5) {
                    return (data[4] == 1) ? _("On") : _("Off");
                }
            }
        } catch (Error e) { }
        return _("Unknown");
    }

    /* The same keys the idle watcher reads, in the same order: the
     * per-source value first, the old single one for an installation
     * that predates it. A row that read a key nobody writes would say
     * "Off" on every machine forever. */
    private string lock_state () {
        int minutes = conf_get_int ("power", "lock_after_ac",
                                    conf_get_int ("power", "lock_after", 0));
        if (minutes <= 0) {
            return _("Off — the screen does not lock by itself");
        }
        return ngettext ("After %d minute of inactivity",
                         "After %d minutes of inactivity", minutes)
            .printf (minutes);
    }

    /* Reported, not configured. Kavis ships no firewall yet, and a row
     * that pretends otherwise is exactly the kind of claim this page
     * exists to avoid. */
    private string firewall_state () {
        if (Environment.find_program_in_path ("nft") == null
            && Environment.find_program_in_path ("ufw") == null) {
            return _("No firewall installed — nothing accepts connections by default either");
        }
        /* Reading the ruleset needs root, and a settings page must not
         * throw a password prompt at somebody for opening it. So the
         * honest answer without rights is "cannot tell", not "no rules"
         * — the first version said the latter, which on a machine with
         * a firewall configured was simply false. */
        string output;
        int status;
        try {
            Process.spawn_sync (null, { "nft", "list", "ruleset" }, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, out output, null, out status);
        } catch (Error e) {
            return _("Installed — could not ask it");
        }
        if (status != 0) {
            return _("Installed — reading the rules needs administrator rights");
        }
        return (output.strip () != "")
            ? _("Rules are loaded") : _("Installed, no rules loaded");
    }

    private string clipboard_log () {
        return Path.build_filename (Environment.get_user_data_dir (),
                                    "kavis", "clipboard-reads.log");
    }

    private void fill_clipboard_reads (Gtk.Box box) {
        foreach (var child in box.get_children ()) {
            box.remove (child);
        }
        string contents;
        try {
            FileUtils.get_contents (clipboard_log (), out contents);
        } catch (Error e) {
            var empty = new Gtk.Label (
                conf_get_bool ("clipboard", "watch-reads", false)
                ? _("Nothing has read the clipboard yet.")
                : _("Not watching. Turn the switch above on to start recording."));
            empty.set_xalign (0);
            empty.get_style_context ().add_class ("dim-label");
            box.pack_start (empty, false, false, 0);
            return;
        }
        string[] lines = contents.split ("\n");
        /* Newest first, and only as many as anybody reads at a glance;
         * the file keeps the rest. */
        int shown = 0;
        for (int i = lines.length - 1; i >= 0 && shown < 10; i--) {
            string line = lines[i].strip ();
            if (line == "") {
                continue;
            }
            string[] fields = line.split ("\t");
            if (fields.length < 3) {
                continue;
            }
            var when = new DateTime.from_unix_local (
                int64.parse (fields[0]));
            box.pack_start (row (fields[1],
                _("%s · %s").printf (when.format ("%d %b %H:%M"), fields[2]),
                null), false, false, 0);
            shown++;
        }
        if (shown == 0) {
            var empty = new Gtk.Label (_("Nothing has read the clipboard yet."));
            empty.set_xalign (0);
            empty.get_style_context ().add_class ("dim-label");
            box.pack_start (empty, false, false, 0);
        }
    }

    /* ClamAV is not on the ISO: its signature database is bigger than
     * several of the applications Kavis ships, and a scanner with no
     * signatures is theatre. The row says what it would take, and runs
     * it when it is there. */
    private Gtk.Widget scan_row () {
        if (Environment.find_program_in_path ("clamscan") == null) {
            var label = new Gtk.Label (_("Not installed"));
            label.get_style_context ().add_class ("dim-label");
            return row (_("Malware scan"),
                _("Kavis does not ship a scanner — its signature database is larger than most of the system. Install ClamAV to scan on demand."),
                label);
        }
        var button = new Gtk.Button.with_label (_("Scan downloads"));
        var result = new Gtk.Label ("");
        result.get_style_context ().add_class ("dim-label");
        button.clicked.connect (() => {
            button.set_sensitive (false);
            result.set_text (_("Scanning…"));
            string downloads = Path.build_filename (
                Environment.get_home_dir (), "downloads");
            new Thread<void*> ("kavis-clamscan", () => {
                string output = "";
                int rc = 1;
                try {
                    Process.spawn_sync (null,
                        { "clamscan", "-r", "--no-summary", downloads },
                        null, SpawnFlags.SEARCH_PATH, null,
                        out output, null, out rc);
                } catch (Error e) { }
                string found = output.strip ();
                Idle.add (() => {
                    button.set_sensitive (true);
                    result.set_text (found == ""
                        ? _("Nothing found")
                        : found.split ("\n")[0]);
                    return false;
                });
                return null;
            });
        });
        var side = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        side.pack_start (result, false, false, 0);
        side.pack_start (button, false, false, 0);
        return row (_("Malware scan"),
            _("Scans the downloads folder with ClamAV"), side);
    }
}
