/* Tiny process helpers for the Settings backends. */

namespace Kavis.Settings.Run {

    /* Run and capture stdout; null on failure or nonzero exit. */
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

    /* Fire and forget. */
    public void fire (string[] argv) {
        try {
            Process.spawn_async (null, argv, null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL,
                null, null);
        } catch (Error e) {
            warning ("kavis-settings: could not run %s: %s",
                     argv[0], e.message);
        }
    }
}
