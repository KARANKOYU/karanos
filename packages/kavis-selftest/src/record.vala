/* Record mode (item 72): a session, written down as a scenario.
 *
 *   kavis-selftest --record tests/ui/80-my-bug.yaml --item 80
 *
 * Everything the person does is watched with XRecord, and what the
 * session does in reply is polled from the window manager. The output
 * is a scenario in the same small YAML the runner reads, so a bug can
 * be demonstrated once and replayed for ever after.
 *
 * WHAT IT DOES NOT DO, on purpose: record pixel coordinates. The step
 * vocabulary is deliberately semantic — `click taskbar start`, `drag
 * window nemo to left`, `key super+e` — because a scenario written in
 * coordinates breaks the first time the taskbar changes height, and
 * the whole point of these scenarios is that they keep working. A
 * click the vocabulary cannot express is written out as a comment
 * saying where it was and what it hit, so the person can turn it into
 * a step by hand instead of getting a file that silently does the
 * wrong thing.
 *
 * The expectations are not guessed either: after each action the
 * recorder waits for the session to settle and writes down what
 * ACTUALLY changed — a window that appeared, a popup that opened, a
 * window that went away.
 */

namespace Kavis.Selftest {

    [CCode (cname = "kavis_record_cb", has_target = false)]
    private delegate void RecordFunc (int type, int detail, int x, int y,
                                      void* user);

    [CCode (cname = "kavis_record_start")]
    private extern int record_start (RecordFunc cb, void* user);
    [CCode (cname = "kavis_record_pump")]
    private extern void record_pump ();
    [CCode (cname = "kavis_record_stop")]
    private extern void record_stop ();

    /* X protocol event types, as they arrive from XRecord. */
    private const int KEY_PRESS = 2;
    private const int KEY_RELEASE = 3;
    private const int BUTTON_PRESS = 4;

    public class Recorder : Object {

        private static Recorder? live = null;

        private XWin xw = new XWin ();
        private string path;
        private string item;
        private string[] lines = {};
        private string[] classes = {};
        private string typing = "";
        private int64 last_action = 0;

        /* What the session looked like before the last action, so the
         * expectation can be what changed rather than what we hoped. */
        private string[] windows_before = {};
        private int popups_before = 0;

        /* True while a step is being written: the poll timer runs
         * inside settle(), and an observation emitted halfway through
         * an action would land between that action's `do:` and its
         * `expect:`. */
        private bool writing = false;

        private bool ctrl = false;
        private bool alt = false;
        private bool shift = false;
        private bool super = false;

        public Recorder (string path, string item) {
            this.path = path;
            this.item = item;
            windows_before = xw.window_classes ();
            popups_before = xw.popup_count ("kavis-panel");
            last_action = GLib.get_monotonic_time ();
        }

        /* Watch until Ctrl+C, then write the scenario. */
        public int run () {
            int fd = record_start (on_event, null);
            if (fd < 0) {
                stderr.printf (
                    "kavis-selftest: the X server has no RECORD extension, "
                    + "so nothing can be recorded\n");
                return 2;
            }
            live = this;
            Posix.signal (Posix.Signal.INT, (_) => {
                if (live != null) {
                    live.finish ();
                }
                Posix.exit (0);
            });

            var channel = new IOChannel.unix_new (fd);
            channel.add_watch (IOCondition.IN, () => {
                record_pump ();
                return true;
            });
            /* The window list is polled rather than subscribed to
             * (libwnck's list lags the server), and what changes
             * BETWEEN actions is written down as its own step: a
             * window that opened while nobody was typing did not come
             * from the next key press, and saying it did would be a
             * lie the replay then fails on. */
            Timeout.add (250, () => {
                xw.pump ();
                observe ();
                return true;
            });

            stdout.printf (
                "Recording to %s. Do the thing, then press Ctrl+C.\n"
                + "Keys and taskbar clicks become steps; what the "
                + "session does in reply becomes the expectations.\n",
                path);
            new MainLoop ().run ();
            return 0;
        }

        /* Something happened without anyone doing anything: an app
         * finished starting, a window closed itself. */
        private void observe () {
            if (writing) {
                return;
            }
            string what = changed ();
            if (what == "ok") {
                return;
            }
            int64 now = GLib.get_monotonic_time ();
            int64 waited = (now - last_action) / 1000;
            last_action = now;
            lines += "  - do: wait %lld".printf (int64.max (waited, 500));
            lines += "    expect: " + what;
            lines += "    timeout: 15000";
            lines += "    note: happened on its own, with no input";
        }

        /* --- input ------------------------------------------------- */

        private static void on_event (int type, int detail, int x, int y,
                                      void* user) {
            if (live != null) {
                live.handle (type, detail, x, y);
            }
        }

        private void handle (int type, int detail, int x, int y) {
            uint keyval = keyval_of (detail);
            if (type == KEY_PRESS || type == KEY_RELEASE) {
                if (track_modifier (keyval, type == KEY_PRESS)) {
                    return;
                }
                if (type == KEY_PRESS) {
                    on_key (keyval);
                }
                return;
            }
            if (type == BUTTON_PRESS) {
                on_click (detail, x, y);
            }
        }

        /* True when the key was a modifier and nothing else should
         * happen: holding Shift is not a step. */
        private bool track_modifier (uint keyval, bool pressed) {
            switch (keyval) {
            case Gdk.Key.Shift_L: case Gdk.Key.Shift_R:
                shift = pressed; return true;
            case Gdk.Key.Control_L: case Gdk.Key.Control_R:
                ctrl = pressed; return true;
            case Gdk.Key.Alt_L: case Gdk.Key.Alt_R:
                alt = pressed; return true;
            case Gdk.Key.Super_L: case Gdk.Key.Super_R:
            case Gdk.Key.Meta_L: case Gdk.Key.Meta_R:
                super = pressed; return true;
            }
            return false;
        }

        private void on_key (uint keyval) {
            string? name = Gdk.keyval_name (keyval);
            if (name == null) {
                return;
            }
            /* Plain typing collects into one `type` step: twenty `key`
             * steps for a filename is noise nobody will read. */
            uint32 unicode = Gdk.keyval_to_unicode (keyval);
            if (!ctrl && !alt && !super && unicode >= 32
                && unicode != 127) {
                typing += ((unichar) unicode).to_string ();
                return;
            }
            flush_typing ();
            var combo = new StringBuilder ();
            if (super) { combo.append ("super+"); }
            if (ctrl)  { combo.append ("ctrl+"); }
            if (alt)   { combo.append ("alt+"); }
            if (shift) { combo.append ("shift+"); }
            combo.append (name.char_count () == 1 ? name.down () : name);
            step ("key " + combo.str);
        }

        private void flush_typing () {
            if (typing == "") {
                return;
            }
            string text = typing;
            typing = "";
            step ("type " + text);
        }

        /* A click is only a step when the vocabulary can say where it
         * landed. Everything else is written down as a comment. */
        private void on_click (int button, int x, int y) {
            flush_typing ();
            if (button != 1) {
                note ("button %d at %d,%d — only the left button has a step"
                          .printf (button, x, y));
                return;
            }
            unowned Wnck.Window? panel = xw.panel ();
            if (panel != null) {
                int px, py, pw, ph;
                panel.get_geometry (out px, out py, out pw, out ph);
                if (x >= px && x < px + pw && y >= py && y < py + ph) {
                    step ("click taskbar " + taskbar_third (
                        panel, x, y));
                    return;
                }
            }
            note ("click at %d,%d — no step says this; write one by hand"
                      .printf (x, y));
        }

        /* Which of the three named taskbar spots the click was nearest
         * — the same three the runner can aim at. */
        private string taskbar_third (Wnck.Window panel, int x, int y) {
            int px, py, pw, ph;
            panel.get_geometry (out px, out py, out pw, out ph);
            bool vertical = ph > pw;
            int along = vertical ? y - py : x - px;
            int length = vertical ? ph : pw;
            if (along < length / 3) {
                return "start";
            }
            return (along > length * 2 / 3) ? "clock" : "middle";
        }

        /* --- steps ------------------------------------------------- */

        /* One action, plus a pause if the person waited, plus whatever
         * the session did in reply. */
        private void step (string action) {
            writing = true;
            int64 now = GLib.get_monotonic_time ();
            int64 idle_ms = (now - last_action) / 1000;
            last_action = now;
            if (idle_ms > 1500 && lines.length > 0) {
                lines += "  - do: wait %lld".printf (idle_ms);
                lines += "    expect: ok";
                lines += "    note: the recorded session paused here";
            }
            lines += "  - do: " + action;
            /* Give the session the time a person would have given it
             * before deciding what changed. */
            settle (700);
            lines += "    expect: " + changed ();
            lines += "    timeout: 8000";
            last_action = GLib.get_monotonic_time ();
            writing = false;
        }

        private void note (string text) {
            lines += "  # " + text;
        }

        /* What is different now from before the last action. The first
         * difference wins: a step asserts one thing. */
        private string changed () {
            string[] now = xw.window_classes ();
            foreach (unowned string cls in now) {
                if (!contains (windows_before, cls)) {
                    remember (cls);
                    windows_before = now;
                    popups_before = xw.popup_count ("kavis-panel");
                    return "window %s visible".printf (cls);
                }
            }
            foreach (unowned string cls in windows_before) {
                if (!contains (now, cls)) {
                    windows_before = now;
                    popups_before = xw.popup_count ("kavis-panel");
                    return "window %s absent".printf (cls);
                }
            }
            int popups = xw.popup_count ("kavis-panel");
            string result = "ok";
            if (popups > popups_before) {
                result = "popup kavis-panel visible";
            } else if (popups < popups_before) {
                result = "popup kavis-panel hidden";
            }
            windows_before = now;
            popups_before = popups;
            return result;
        }

        private void remember (string cls) {
            if (!contains (classes, cls)) {
                classes += cls;
            }
        }

        private static bool contains (string[] haystack, string needle) {
            foreach (unowned string one in haystack) {
                if (one == needle) {
                    return true;
                }
            }
            return false;
        }

        private void settle (int ms) {
            xw.pump ();
            var end = GLib.get_monotonic_time () + ms * 1000;
            while (GLib.get_monotonic_time () < end) {
                while (Gtk.events_pending ()) {
                    Gtk.main_iteration_do (false);
                }
                Thread.usleep (20000);
            }
            xw.pump ();
        }

        /* --- output ------------------------------------------------ */

        public void finish () {
            record_stop ();
            flush_typing ();
            string name = Path.get_basename (path).replace (".yaml", "");
            var text = new StringBuilder ();
            text.append_printf (
                "# RECORDED by kavis-selftest --record.\n"
                + "# Read it before trusting it: the recorder writes down\n"
                + "# what changed after each action, and \"ok\" means it saw\n"
                + "# nothing change — often the right answer, sometimes a\n"
                + "# missing assertion.\n");
            text.append_printf ("name: %s\n", name);
            text.append_printf ("title: %s\n", name);
            text.append_printf ("item: %s\n", item);
            text.append_printf ("allowed: [%s]\n",
                                string.joinv (", ", classes));
            text.append ("steps:\n");
            if (lines.length == 0) {
                text.append ("  - do: none\n    expect: ok\n"
                             + "    note: nothing was recorded\n");
            }
            foreach (unowned string line in lines) {
                text.append (line);
                text.append_c ('\n');
            }
            try {
                FileUtils.set_contents (path, text.str);
                stdout.printf ("\nwrote %s (%d steps)\n", path,
                               count_steps ());
            } catch (Error e) {
                stderr.printf ("could not write %s: %s\n", path,
                               e.message);
            }
        }

        private int count_steps () {
            int n = 0;
            foreach (unowned string line in lines) {
                if (line.has_prefix ("  - do:")) {
                    n++;
                }
            }
            return n;
        }

        /* Keycode → keyval through the keymap the session is actually
         * using, so a Turkish layout records the key the person
         * pressed and not its US name. */
        private uint keyval_of (int keycode) {
            var keymap = Gdk.Keymap.get_for_display (
                Gdk.Display.get_default ());
            uint keyval;
            if (!keymap.translate_keyboard_state (
                    (uint) keycode, 0, 0, out keyval, null, null, null)) {
                return 0;
            }
            return keyval;
        }
    }
}
