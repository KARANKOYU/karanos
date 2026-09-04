/* Idle actions: turn the screen off, then sleep (item 51).
 *
 * THIS IS THE CANONICAL COPY — build-packages.sh copies it into the
 * packages that need it; the copies are gitignored.
 *
 * The timeouts are per power source, because the answer is genuinely
 * different: a laptop on battery should sleep in ten minutes, the same
 * laptop on a charger usually should not sleep at all. One process
 * watches — the panel — and everything else only writes kavis.conf.
 *
 * Idle time comes from the X screen saver extension, which counts
 * milliseconds since the last key or pointer event. That is the same
 * counter every screen locker uses; polling it costs one round trip
 * every 20 seconds. The alternative, spawning xprintidle on a timer,
 * would cost a process each time and answer the same question.
 */

namespace Kavis {

    namespace IdleWatch {

        private uint timer = 0;
        private bool screen_is_off = false;
        private bool locked = false;
        private XScreenSaver.Info? info = null;

        /* Seconds of inactivity, or -1 when the extension is missing
         * (Xvfb builds without it, and some remote X servers). */
        public int seconds () {
            unowned X.Display? display =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            if (display == null) {
                return -1;
            }
            if (info == null) {
                info = XScreenSaver.alloc_info ();
            }
            if (info == null) {
                return -1;
            }
            if (XScreenSaver.query_info (display,
                    display.default_root_window (), info) == 0) {
                return -1;
            }
            return (int) (info.idle / 1000);
        }

        private int minutes (string key, bool plugged, int fallback) {
            try {
                return Config.load ().get_integer ("power",
                    key + (plugged ? "_ac" : "_battery"));
            } catch (Error e) { }
            /* Before the per-source keys existed there was one value;
             * an existing installation keeps its choice. */
            try {
                return Config.load ().get_integer ("power", key);
            } catch (Error e) { }
            return fallback;
        }

        /* on_ac is passed in: this file must not depend on the panel's
         * battery backend, the same rule powerplan.vala follows. */
        private void tick (bool on_ac) {
            int idle = seconds ();
            if (idle < 0) {
                return;
            }
            int screen_off = minutes ("screen_off", on_ac, 0);
            int sleep_after = minutes ("sleep_after", on_ac, 0);
            int lock_after = minutes ("lock_after", on_ac, 0);

            /* Lock first, before the screen goes dark: a machine that
             * sleeps or blanks while still unlocked is a machine
             * somebody can walk up to. Started once per idle period —
             * kavis-lock refuses a second instance anyway, but asking
             * every 20 seconds would fill the log.
             *
             * Never on a session with no password: locking a live image
             * that anyone can unlock with one click protects nothing
             * and puts a lock screen in front of somebody who is trying
             * the system out. */
            if (lock_after > 0 && idle >= lock_after * 60
                && !Session.passwordless ()) {
                if (!locked) {
                    locked = true;
                    LockWatch.lock_now ();
                }
            } else if (idle < 30) {
                locked = false;
            }

            if (screen_off > 0 && idle >= screen_off * 60) {
                if (!screen_is_off) {
                    screen_is_off = true;
                    run ({ "xset", "dpms", "force", "off" });
                }
            } else if (screen_is_off) {
                screen_is_off = false;
                run ({ "xset", "dpms", "force", "on" });
            }

            /* Sleep last and only well after the screen went dark, so a
             * machine never jumps straight from in-use to suspended. */
            if (sleep_after > 0 && idle >= sleep_after * 60) {
                run ({ "systemctl", "suspend" });
            }
        }

        private void run (string[] argv) {
            try {
                Process.spawn_async (null, argv, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.STDOUT_TO_DEV_NULL
                        | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
            } catch (SpawnError e) {
                warning ("kavis: idle action %s failed: %s", argv[0],
                         e.message);
            }
        }

        public delegate bool AcFunc ();

        /* 20 s: fine enough that a 5-minute timeout is not visibly late,
         * coarse enough to be free. */
        public void start (owned AcFunc on_ac) {
            if (timer != 0) {
                return;
            }
            timer = Timeout.add_seconds (20, () => {
                tick (on_ac ());
                return Source.CONTINUE;
            });
        }
    }
}
