/* Kavis single configuration file (madde 9, 1A-2).
 *
 * KANONİK KOPYA BURASI — build-packages.sh derlemede kavis-panel ve
 * kavis-settings src ağaçlarına kopyalar (kopyalar .gitignore'da).
 *
 * ~/.config/kavis/kavis.conf is THE settings file: the Settings app
 * writes it, the panel/OSD/sounds read it, later groups (picom, theme)
 * join in. Groups: [taskbar] (was panel.conf's [panel]), [clock],
 * [picker], [usb], [clipboard], [sounds], [osd], [appearance],
 * [display], [power], [keyboard]...
 *
 * Live propagation is a GLib.FileMonitor (inotify) on this one path —
 * chosen over a D-Bus signal because every consumer already links
 * GLib, nothing must be running for a write to land, and one file
 * needs no bus name/API versioning.
 *
 * Migration: an existing panel.conf (pre-Grup-F) is imported once on
 * first load — its [panel] group becomes [taskbar], everything else
 * carries over; the old file is left untouched as a backup.
 */

namespace Kavis.Config {

    /* Full path of kavis.conf. */
    public string path () {
        return Path.build_filename (
            Environment.get_user_config_dir (), "kavis", "kavis.conf");
    }

    private string old_panel_path () {
        return Path.build_filename (
            Environment.get_user_config_dir (), "kavis", "panel.conf");
    }

    /* One-time import of the pre-Grup-F panel.conf. Idempotent and
     * cheap: does nothing once kavis.conf exists. */
    public void migrate () {
        if (FileUtils.test (path (), FileTest.IS_REGULAR)
            || !FileUtils.test (old_panel_path (),
                                FileTest.IS_REGULAR)) {
            return;
        }
        var old_file = new KeyFile ();
        try {
            old_file.load_from_file (old_panel_path (),
                                     KeyFileFlags.KEEP_COMMENTS);
        } catch (Error e) {
            return;   /* bozuk eski dosya: sıfırdan başlanır */
        }
        var fresh = new KeyFile ();
        foreach (unowned string group in old_file.get_groups ()) {
            string target = (group == "panel") ? "taskbar" : group;
            try {
                foreach (unowned string key in
                         old_file.get_keys (group)) {
                    fresh.set_value (target, key,
                                     old_file.get_value (group, key));
                }
            } catch (Error e) { }
        }
        save (fresh);
    }

    /* Load kavis.conf (after migration); missing file = empty config. */
    public KeyFile load () {
        migrate ();
        var file = new KeyFile ();
        try {
            file.load_from_file (path (), KeyFileFlags.KEEP_COMMENTS);
        } catch (Error e) { }
        return file;
    }

    /* Write the whole file back. Callers must have loaded the same
     * file first (load ()) so other groups are preserved. */
    public bool save (KeyFile file) {
        string target = path ();
        DirUtils.create_with_parents (Path.get_dirname (target), 0755);
        try {
            FileUtils.set_contents (target, file.to_data ());
            return true;
        } catch (Error e) {
            warning ("kavis: kavis.conf yazilamadi: %s", e.message);
            return false;
        }
    }

    public delegate void ChangeFunc ();

    /* Watch kavis.conf; fires after a write settles
     * (CHANGES_DONE_HINT). The returned monitor must be kept alive by
     * the caller. */
    public FileMonitor? watch (owned ChangeFunc on_change) {
        try {
            var file = File.new_for_path (path ());
            var monitor = file.monitor_file (FileMonitorFlags.NONE);
            monitor.changed.connect ((f, other, event) => {
                if (event == FileMonitorEvent.CHANGES_DONE_HINT
                    || event == FileMonitorEvent.CREATED) {
                    on_change ();
                }
            });
            return monitor;
        } catch (Error e) {
            warning ("kavis: kavis.conf izlenemedi: %s", e.message);
            return null;
        }
    }
}
