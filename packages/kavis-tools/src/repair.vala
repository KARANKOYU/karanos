/* USB file-system repair (madde 64).
 *
 * Reached from the panel's "drive could not be mounted" notification
 * (Try to repair action) or manually: `kavis-tools repair-drive
 * /dev/sdb1`. Nothing runs without explicit consent: the window leads
 * with the data-loss warning and a read-only escape hatch, the repair
 * itself starts only from the Repair button (pkexec asks for admin
 * auth on top). Scope is ext2/3/4, FAT, exFAT and NTFS — btrfs is
 * deliberately out (grup-e-taramasi: multi-device risk; its own
 * tooling is a different world).
 */

namespace Kavis.Tools {

    public class RepairDriveWindow : Gtk.Window {

        private string device;
        private string fstype = "";
        private Gtk.Label status;
        private Gtk.TextView raw_view;
        private Gtk.Expander details;
        private Gtk.Button repair_button;
        private Gtk.Button ro_button;
        private Gtk.Spinner spinner;

        public RepairDriveWindow (string device) {
            this.device = device;
            title = _("Repair drive");
            window_position = Gtk.WindowPosition.CENTER;
            set_default_size (520, -1);
            fstype = detect_fstype ();

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.margin = 16;
            add (box);

            var head = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            var icon = new Gtk.Image.from_icon_name (
                "dialog-warning", Gtk.IconSize.DIALOG);
            head.pack_start (icon, false, false, 0);
            var intro = new Gtk.Label (
                _("The drive %s could not be mounted. Its file system may be damaged.")
                    .printf (device));
            intro.set_line_wrap (true);
            intro.set_xalign (0);
            head.pack_start (intro, true, true, 0);
            box.pack_start (head, false, false, 0);

            /* Zorunlu uyarı (madde 64): onarım veri kaybettirebilir;
             * mümkünse önce salt-okunur bağlayıp kopyala. */
            var warn = new Gtk.Label (
                _("Repair can cause data loss. If the files matter, first try mounting read-only and copy them somewhere safe."));
            warn.set_line_wrap (true);
            warn.set_xalign (0);
            warn.get_style_context ().add_class ("dim");
            box.pack_start (warn, false, false, 0);

            status = new Gtk.Label ("");
            status.set_line_wrap (true);
            status.set_xalign (0);
            box.pack_start (status, false, false, 0);

            spinner = new Gtk.Spinner ();
            spinner.set_no_show_all (true);
            box.pack_start (spinner, false, false, 0);

            raw_view = new Gtk.TextView ();
            raw_view.editable = false;
            raw_view.monospace = true;
            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.set_min_content_height (160);
            scrolled.add (raw_view);
            details = new Gtk.Expander (_("Details"));
            details.add (scrolled);
            details.set_no_show_all (true);
            box.pack_start (details, true, true, 0);

            var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            buttons.set_halign (Gtk.Align.END);
            ro_button = new Gtk.Button.with_label (
                _("Mount read-only"));
            ro_button.clicked.connect (mount_read_only);
            buttons.pack_start (ro_button, false, false, 0);
            repair_button = new Gtk.Button.with_label (_("Repair"));
            repair_button.get_style_context ()
                .add_class ("destructive-action");
            repair_button.clicked.connect (start_repair);
            buttons.pack_start (repair_button, false, false, 0);
            var close_button = new Gtk.Button.with_label (_("Close"));
            close_button.clicked.connect (() => destroy ());
            buttons.pack_start (close_button, false, false, 0);
            box.pack_start (buttons, false, false, 0);

            if (repair_argv () == null) {
                repair_button.sensitive = false;
                status.label = _("This file system cannot be repaired from here.");
            }
        }

        private string detect_fstype () {
            try {
                string output;
                Process.spawn_sync (null,
                    { "lsblk", "-no", "FSTYPE", device }, null,
                    SpawnFlags.SEARCH_PATH
                    | SpawnFlags.STDERR_TO_DEV_NULL,
                    null, out output);
                return output.strip ();
            } catch (Error e) {
                return "";
            }
        }

        private string[]? repair_argv () {
            switch (fstype) {
            case "ext2":
            case "ext3":
            case "ext4":
                return { "pkexec", "fsck." + fstype, "-f", "-y",
                         device };
            case "vfat":
                return { "pkexec", "fsck.fat", "-a", device };
            case "exfat":
                return { "pkexec", "fsck.exfat", "-y", device };
            case "ntfs":
                return { "pkexec", "ntfsfix", device };
            }
            return null;
        }

        private void mount_read_only () {
            ro_button.sensitive = false;
            new Thread<void*> ("kavis-ro-mount", () => {
                string output = "";
                int exit_status = 1;
                try {
                    Process.spawn_sync (null,
                        { "udisksctl", "mount", "-b", device,
                          "-o", "ro" },
                        null, SpawnFlags.SEARCH_PATH, null,
                        out output, null, out exit_status);
                } catch (Error e) { }
                bool ok = (exit_status == 0);
                Idle.add (() => {
                    ro_button.sensitive = true;
                    if (ok) {
                        status.label = _("Mounted read-only — copy your files now, then repair.");
                        int at = output.last_index_of (" at ");
                        if (at >= 0) {
                            string mountpoint =
                                output.substring (at + 4).strip ();
                            try {
                                Process.spawn_async (null,
                                    { "xdg-open", mountpoint }, null,
                                    SpawnFlags.SEARCH_PATH, null,
                                    null);
                            } catch (Error e) { }
                        }
                    } else {
                        status.label = _("Read-only mount failed too — the damage is deeper.");
                    }
                    return Source.REMOVE;
                });
                return null;
            });
        }

        private void start_repair () {
            string[]? argv = repair_argv ();
            if (argv == null) {
                return;
            }
            repair_button.sensitive = false;
            ro_button.sensitive = false;
            spinner.set_no_show_all (false);
            spinner.show ();
            spinner.start ();
            status.label = _("Repairing — do not unplug the drive…");
            new Thread<void*> ("kavis-repair", () => {
                string stdout_text = "";
                string stderr_text = "";
                int exit_status = 1;
                try {
                    Process.spawn_sync (null, argv, null,
                        SpawnFlags.SEARCH_PATH, null,
                        out stdout_text, out stderr_text,
                        out exit_status);
                } catch (Error e) {
                    stderr_text = e.message;
                }
                /* fsck çıkış kodu bit alanı: 1 = düzeltildi. */
                bool ok = (exit_status == 0 || exit_status == 1);
                string raw = (stdout_text + "\n" + stderr_text).strip ();
                Idle.add (() => {
                    spinner.stop ();
                    spinner.hide ();
                    repair_button.sensitive = true;
                    ro_button.sensitive = true;
                    string text = ok
                        ? _("Repair finished. Unplug the drive and plug it back in.")
                        : _("Repair could not fix the drive.");
                    if (fstype == "ntfs") {
                        text += "\n" + _("Deeper NTFS repair needs Windows: run chkdsk /f there.");
                    }
                    text += "\n" + _("If the drive keeps failing, the hardware itself may be dying — software cannot fix that.");
                    status.label = text;
                    raw_view.buffer.text = raw;
                    details.set_no_show_all (false);
                    details.show_all ();
                    return Source.REMOVE;
                });
                return null;
            });
        }
    }
}
