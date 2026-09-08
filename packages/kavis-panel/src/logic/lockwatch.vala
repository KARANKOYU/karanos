/* When to lock the screen (item 70).
 *
 * The lock screen itself is a separate binary; this decides when to
 * start it. Three triggers, and only one of them is ours:
 *
 *   * logind's Lock signal — that is what `loginctl lock-session`
 *     sends, and what closing the lid does when Settings > Power says
 *     "lock the screen". Listening to it means the lid setting works
 *     through logind's own mechanism instead of a second one of ours.
 *   * the idle watcher, after the number of minutes in kavis.conf.
 *   * Win+L, which runs kavis-lock directly from the keybind — no
 *     round trip through here, because a keystroke that has to reach a
 *     daemon first is a keystroke that can be late.
 */

namespace Kavis {

    namespace LockWatch {

        /* `by_hand` is false when a timer or the lid asked for this.
         * kavis-lock refuses to lock an account with no password; the
         * difference the flag makes is whether it explains that to
         * somebody, and a timer is not somebody. */
        public void lock_now (bool by_hand = true) {
            if (Environment.find_program_in_path ("kavis-lock") == null) {
                return;
            }
            string[] argv = by_hand
                ? new string[] { "kavis-lock" }
                : new string[] { "kavis-lock", "--idle" };
            try {
                Process.spawn_async (null, argv, null,
                    SpawnFlags.SEARCH_PATH, null, null);
            } catch (SpawnError e) {
                warning ("kavis-panel: could not start the lock screen: %s",
                         e.message);
            }
        }

        /* Subscribe to the Lock signal of THIS session. The session
         * path is asked for by name ("auto" is the caller's own
         * session), so it stays right across a fast user switch. */
        public void start () {
            DBusConnection system;
            try {
                system = Bus.get_sync (BusType.SYSTEM);
            } catch (Error e) {
                warning ("kavis-panel: no system bus, the lid will not lock: %s",
                         e.message);
                return;
            }
            string path;
            try {
                var answer = system.call_sync (
                    "org.freedesktop.login1",
                    "/org/freedesktop/login1",
                    "org.freedesktop.login1.Manager",
                    "GetSession", new Variant ("(s)", "auto"),
                    new VariantType ("(o)"), DBusCallFlags.NONE, 2000, null);
                answer.get ("(o)", out path);
            } catch (Error e) {
                warning ("kavis-panel: logind did not name this session: %s",
                         e.message);
                return;
            }
            system.signal_subscribe ("org.freedesktop.login1", 
                "org.freedesktop.login1.Session", "Lock", path, null,
                DBusSignalFlags.NONE,
                (connection, sender, object_path, interface_name,
                 signal_name, parameters) => {
                    /* The lid, or `loginctl lock-session`: nobody is
                     * looking at the screen to read an explanation. */
                    lock_now (false);
                });
        }
    }
}
