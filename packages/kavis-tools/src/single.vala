/* Single-instance guard for kavis-tools windows (2B).
 *
 * Alt+F4 held down used to spawn dozens of power dialogs — every
 * keypress is a new process. A flock on $XDG_RUNTIME_DIR/<name>.lock
 * is the lightest fix (no GtkApplication/D-Bus machinery): the fd is
 * deliberately kept open so the lock dies with the process, crashes
 * included. The loser raises the existing window and exits.
 */

namespace Kavis.Tools.SingleInstance {

    /* posix.vapi flock bilmiyor — doğrudan bağla (Linux: LOCK_EX=2,
     * LOCK_NB=4; sys/file.h). */
    [CCode (cname = "flock", cheader_filename = "sys/file.h")]
    private extern int sys_flock (int fd, int operation);
    private const int FLOCK_EX_NB = 2 | 4;

    /* false → another instance runs; its window was raised. */
    public bool acquire (string name) {
        string path = Path.build_filename (
            Environment.get_user_runtime_dir (), name + ".lock");
        int fd = Posix.open (path, Posix.O_CREAT | Posix.O_RDWR, 0600);
        if (fd < 0) {
            /* Kilit kurulamıyorsa engel olma — tek örnek garantisi
             * kaybolur ama araç çalışır. */
            return true;
        }
        if (sys_flock (fd, FLOCK_EX_NB) != 0) {
            Posix.close (fd);
            try {
                Process.spawn_async (null, {
                    "xdotool", "search", "--class", name,
                    "windowactivate"
                }, null, SpawnFlags.SEARCH_PATH
                   | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
            } catch (Error e) { }
            return false;
        }
        /* fd açık bırakılır (bilerek): süreçle birlikte ölür. */
        return true;
    }
}
