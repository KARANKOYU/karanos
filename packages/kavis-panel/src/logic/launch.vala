/* Launching helpers (business logic — no widget code).
 *
 * Grup D fix: the notification center and quick settings open files,
 * folders and the (future) Settings app. All spawning funnels through
 * here so widget files never call Process directly.
 */

namespace Kavis.Launch {

    public void run (string[] argv) {
        try {
            Process.spawn_async (null, argv, null,
                SpawnFlags.SEARCH_PATH
                | SpawnFlags.STDOUT_TO_DEV_NULL
                | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
        } catch (Error e) {
            warning ("kavis-panel: could not start %s: %s",
                     argv[0], e.message);
        }
    }

    /* Send Ctrl+V to the focused window (xdotool). The picker uses it
     * to paste right after putting something on the clipboard; without
     * xdotool the clipboard is still set, the user pastes by hand. */
    public void paste_keystroke () {
        if (Environment.find_program_in_path ("xdotool") != null) {
            run ({ "xdotool", "key", "--clearmodifiers", "ctrl+v" });
        }
    }

    /* Show `path` in the file manager. Nemo selects the file when
     * handed a file path; without nemo fall back to opening the
     * containing folder. */
    public void reveal (string path) {
        if (Environment.find_program_in_path ("nemo") != null) {
            run ({ "nemo", path });
            return;
        }
        string dir = FileUtils.test (path, FileTest.IS_DIR)
            ? path : Path.get_dirname (path);
        run ({ "xdg-open", dir });
    }

    /* Open the Settings app at `page`, or say it is coming (Grup F)
     * via a notification when it is not installed yet. */
    public void settings (string page) {
        if (Environment.find_program_in_path ("kavis-settings") != null) {
            run ({ "kavis-settings", page });
            return;
        }
        if (Notifications.server == null) {
            return;
        }
        var hints = new HashTable<string, Variant> (str_hash, str_equal);
        try {
            Notifications.server.notify ("Kavis", 0,
                "preferences-system-symbolic",
                _("Settings app coming soon"), "",
                {}, hints, 4000);
        } catch (Error e) { }
    }
}
