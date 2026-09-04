/* Night light: schedule and application (F-Display).
 *
 * THIS IS THE CANONICAL COPY — build-packages.sh copies it into the
 * packages that need it; the copies are gitignored.
 *
 * Until now the warm screen was a quick-settings toggle that lived in
 * one process's memory: it forgot itself on logout and had no schedule,
 * so "warmer colours in the evening" required the user to remember. The
 * settings are in kavis.conf, one process (the panel) applies them once
 * a minute, and everything else — Settings, the quick toggle — only
 * writes the file.
 *
 * The screen temperature is set with xsct, which writes X's gamma ramps
 * and cannot be queried back. So the last applied value is remembered
 * here and xsct is only run when it actually changes; otherwise every
 * tick would fight with anything else touching gamma.
 */

namespace Kavis {

    namespace NightLight {

        /* Neutral daylight. xsct with no argument resets to this. */
        public const int DAY_TEMPERATURE = 6500;
        public const int DEFAULT_TEMPERATURE = 4500;
        public const int MIN_TEMPERATURE = 2500;
        public const int MAX_TEMPERATURE = 6000;

        private int applied = 0;
        private uint timer = 0;
        private FileMonitor? monitor = null;

        private string get_string (string key, string fallback) {
            try {
                return Config.load ().get_string ("display", key);
            } catch (Error e) {
                return fallback;
            }
        }

        private int get_int (string key, int fallback) {
            try {
                return Config.load ().get_integer ("display", key);
            } catch (Error e) {
                return fallback;
            }
        }

        private bool get_bool (string key, bool fallback) {
            try {
                return Config.load ().get_boolean ("display", key);
            } catch (Error e) {
                return fallback;
            }
        }

        public bool enabled () {
            return get_bool ("nightlight", false);
        }

        /* "always" | "sunset" | "custom" */
        public string schedule () {
            return get_string ("nightlight_schedule", "always");
        }

        public int temperature () {
            int value = get_int ("nightlight_temp", DEFAULT_TEMPERATURE);
            return value.clamp (MIN_TEMPERATURE, MAX_TEMPERATURE);
        }

        /* "HH:MM" → minutes after midnight; -1 when unparseable. */
        private int minutes_of (string text) {
            string[] parts = text.split (":");
            if (parts.length != 2) {
                return -1;
            }
            int h = int.parse (parts[0]);
            int m = int.parse (parts[1]);
            if (h < 0 || h > 23 || m < 0 || m > 59) {
                return -1;
            }
            return h * 60 + m;
        }

        /* Whether the warm temperature should be on right now. */
        public bool wanted_now () {
            if (!enabled ()) {
                return false;
            }
            string mode = schedule ();
            if (mode == "always") {
                return true;
            }
            var now = new DateTime.now_local ();
            int minute = now.get_hour () * 60 + now.get_minute ();
            int from, to;
            if (mode == "sunset") {
                /* No coordinates (a timezone the table does not list)
                 * or polar day: fall back to the same fixed hours the
                 * custom mode defaults to, rather than silently doing
                 * nothing. */
                from = 20 * 60;
                to = 7 * 60;
                double latitude, longitude;
                if (Sun.location (out latitude, out longitude)) {
                    DateTime sunrise, sunset;
                    if (Sun.times (now, latitude, longitude,
                                   out sunrise, out sunset)) {
                        from = sunset.get_hour () * 60
                            + sunset.get_minute ();
                        to = sunrise.get_hour () * 60
                            + sunrise.get_minute ();
                    }
                }
            } else {
                from = minutes_of (get_string ("nightlight_from", "20:00"));
                to = minutes_of (get_string ("nightlight_to", "07:00"));
                if (from < 0 || to < 0) {
                    return false;
                }
            }
            if (from == to) {
                return false;
            }
            /* The interval normally wraps midnight (evening → morning),
             * so "inside" is the union of the two ends of the day. */
            return (from < to)
                ? (minute >= from && minute < to)
                : (minute >= from || minute < to);
        }

        /* Whether xsct exists at all. Checked once: without it there
         * is no way to set the screen temperature, and retrying every
         * minute would put a warning a minute in the journal — which
         * boot-check counts as errors. */
        private bool tool_missing = false;

        /* Apply what the settings ask for, if it is not already what
         * the screen has. */
        public void apply_now () {
            if (tool_missing) {
                return;
            }
            int want = wanted_now () ? temperature () : DAY_TEMPERATURE;
            if (want == applied) {
                return;
            }
            if (Environment.find_program_in_path ("xsct") == null) {
                tool_missing = true;
                warning ("kavis: xsct is not installed, night light is off");
                return;
            }
            applied = want;
            try {
                Process.spawn_async (null,
                    (want == DAY_TEMPERATURE)
                        ? new string[] { "xsct" }
                        : new string[] { "xsct", want.to_string () },
                    null, SpawnFlags.SEARCH_PATH | SpawnFlags.STDOUT_TO_DEV_NULL
                        | SpawnFlags.STDERR_TO_DEV_NULL, null, null);
            } catch (Error e) {
                warning ("kavis: night light could not be applied: %s",
                         e.message);
                applied = 0;   /* try again on the next tick */
            }
        }

        /* Start the scheduler: apply now, then once a minute, and
         * immediately whenever the settings change. One process should
         * call this — the panel does. */
        public void start () {
            if (timer != 0) {
                return;
            }
            apply_now ();
            /* A minute is the right granularity: the change is a slow
             * fade to the eye and a tick costs one config read. */
            timer = Timeout.add_seconds (60, () => {
                apply_now ();
                return Source.CONTINUE;
            });
            monitor = Config.watch (() => apply_now ());
        }
    }
}
