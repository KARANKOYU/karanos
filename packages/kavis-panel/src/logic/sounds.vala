/* System sound playback (business logic — no widget code).
 * Sonraki-isler 6b: plays kavis-theme's synthesized freedesktop sound
 * theme. NO new daemon — paplay (PipeWire/Pulse) when available,
 * aplay otherwise. kavis.conf [sounds] enabled=false silences all of
 * them (Settings, Grup F).
 */

namespace Kavis.Sounds {

    private bool checked = false;
    private bool enabled = true;

    private bool sounds_enabled () {
        if (checked) {
            return enabled;
        }
        checked = true;
        var file = new KeyFile ();
        try {
            file.load_from_file (Config.path (), KeyFileFlags.NONE);
            enabled = file.get_boolean ("sounds", "enabled");
        } catch (Error e) { }
        return enabled;
    }

    /* name: freedesktop sound name (device-added, message-new-instant…). */
    public void play (string name) {
        if (!sounds_enabled ()) {
            return;
        }
        string path = "/usr/share/sounds/kavis/stereo/%s.wav"
            .printf (name);
        if (!FileUtils.test (path, FileTest.IS_REGULAR)) {
            return;
        }
        string player = (Environment.find_program_in_path ("paplay")
                         != null) ? "paplay" : "aplay";
        try {
            Process.spawn_async (null, { player, path }, null,
                SpawnFlags.SEARCH_PATH
                | SpawnFlags.STDOUT_TO_DEV_NULL
                | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
        } catch (Error e) { }
    }
}
