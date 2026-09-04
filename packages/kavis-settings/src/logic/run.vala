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

    /* Run to completion and report whether it worked, with whatever it
     * said. For the actions where the user has to be told: connecting
     * to a network, importing a VPN profile. */
    public bool run (string[] argv, out string message) {
        message = "";
        try {
            string output, errors;
            int status;
            Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH,
                                null, out output, out errors, out status);
            message = (errors.strip () != "") ? errors.strip ()
                                              : output.strip ();
            return Process.if_exited (status)
                && Process.exit_status (status) == 0;
        } catch (Error e) {
            message = e.message;
            return false;
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
