/* Hardware test page (item 50).
 *
 * Nine checks, each PASS / FAIL / SKIP, and one report at the end.
 *
 * Split by who can answer the question. The machine answers where it
 * can measure — disk health, memory, network throughput, whether the
 * microphone heard anything, whether a camera opens — and the person
 * answers only where a machine cannot: did you hear the sound, did
 * every key register, is there a dead pixel. Asking a person to confirm
 * something measurable turns a test into a formality.
 *
 * Interactive checks open a dialog; the automatic ones run in place.
 * The results are one list, so a run is one thing to read.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget hardware (string title) {
        var page = new HardwarePage ();
        return page.build (title);
    }

    private class HardwarePage : Object {

        private Gtk.Box? body = null;
        private Gtk.Widget? page = null;
        private Gtk.Label? summary = null;
        private HwTest.Check[] results = {};
        private Gtk.Label[] status_labels = {};
        private string[] status_ids = {};

        private struct Entry {
            public string id;
            public string title;
            public string hint;
            public bool interactive;
        }

        private Entry[] entries () {
            return {
                { "keyboard", _("Keyboard"),
                  _("Press keys and check that each one registers"), true },
                { "mouse", _("Mouse"),
                  _("Both buttons, the wheel, and movement"), true },
                { "sound", _("Sound output"),
                  _("Plays a test tone through the speakers"), true },
                { "microphone", _("Microphone"),
                  _("Records three seconds and measures the level"), false },
                { "camera", _("Camera"), _("Finds and opens the device"), false },
                { "screen", _("Screen"),
                  _("Full-screen colours for dead pixels and tint"), true },
                { "smart", _("Disk health"),
                  _("SMART self-assessment for every disk"), false },
                { "memory", _("Memory"),
                  _("Writes and reads back patterns in free memory"), false },
                { "network", _("Network speed"),
                  _("Downloads from the Debian mirror"), false }
            };
        }

        public Gtk.Widget build (string title) {
            Gtk.Box b;
            var frame_widget = frame (title, out b);
            body = b;
            page = frame_widget;
            frame_widget.set_data<Object> ("kavis-hardware-page", this);

            summary = new Gtk.Label (
                _("Nothing has been tested yet."));
            summary.set_xalign (0);
            summary.get_style_context ().add_class ("dim-label");
            body.pack_start (summary, false, false, 0);

            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var run_all = new Gtk.Button.with_label (_("Test everything"));
            run_all.get_style_context ().add_class ("suggested-action");
            run_all.clicked.connect (() => run_everything ());
            var open_report = new Gtk.Button.with_label (_("Save and open the report"));
            open_report.clicked.connect (() => save_report ());
            actions.pack_start (run_all, false, false, 0);
            actions.pack_start (open_report, false, false, 0);
            body.pack_start (row (_("Hardware test"),
                _("Each check reports on its own; the report collects them"),
                actions), false, false, 0);

            foreach (Entry entry in entries ()) {
                body.pack_start (check_row (entry), false, false, 0);
            }
            return frame_widget;
        }

        private Gtk.Widget check_row (Entry entry) {
            var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var status = new Gtk.Label ("—");
            status.get_style_context ().add_class ("dim-label");
            controls.pack_start (status, false, false, 0);
            var button = new Gtk.Button.with_label (_("Test"));
            string id = entry.id;
            button.clicked.connect (() => {
                run_one (id);
            });
            controls.pack_start (button, false, false, 0);
            status_labels += status;
            status_ids += entry.id;
            return row (entry.title, entry.hint, controls);
        }

        private void set_status (HwTest.Check check) {
            /* Replace any earlier result for the same check: a run is
             * the latest answer, not a history. */
            HwTest.Check[] kept = {};
            foreach (HwTest.Check c in results) {
                if (c.id != check.id) {
                    kept += c;
                }
            }
            kept += check;
            results = kept;
            for (int i = 0; i < status_ids.length; i++) {
                if (status_ids[i] == check.id) {
                    status_labels[i].set_text (
                        HwTest.result_word (check.result));
                    unowned Gtk.StyleContext ctx =
                        status_labels[i].get_style_context ();
                    ctx.remove_class ("dim-label");
                    status_labels[i].set_tooltip_text (check.detail);
                }
            }
            int failed = 0, passed = 0, skipped = 0;
            foreach (HwTest.Check c in results) {
                switch (c.result) {
                case HwTest.Result.PASS: passed++; break;
                case HwTest.Result.FAIL: failed++; break;
                default: skipped++; break;
                }
            }
            summary.set_text (
                _("%d passed, %d failed, %d skipped")
                    .printf (passed, failed, skipped));
        }

        private void run_one (string id) {
            switch (id) {
            case "keyboard":   set_status (keyboard_test ()); break;
            case "mouse":      set_status (mouse_test ()); break;
            case "sound":      set_status (sound_test ()); break;
            case "screen":     set_status (screen_test ()); break;
            case "microphone": set_status (HwTest.microphone ()); break;
            case "camera":     set_status (HwTest.camera ()); break;
            case "smart":      set_status (HwTest.smart ()); break;
            case "memory":     set_status (HwTest.memory ()); break;
            case "network":    set_status (HwTest.network ()); break;
            }
        }

        /* "Test everything" runs the automatic checks first and only
         * then asks the person anything: the machine's part needs no
         * one present, and someone who walks away still gets those. */
        private void run_everything () {
            foreach (Entry entry in entries ()) {
                if (!entry.interactive) {
                    run_one (entry.id);
                    /* Keep the list responsive between checks — the
                     * memory pass and the download both take seconds. */
                    while (Gtk.events_pending ()) {
                        Gtk.main_iteration ();
                    }
                }
            }
            foreach (Entry entry in entries ()) {
                if (entry.interactive) {
                    run_one (entry.id);
                }
            }
        }

        private void save_report () {
            if (results.length == 0) {
                ask_ok (_("Nothing to report"),
                        _("Run at least one check first."));
                return;
            }
            string path = HwTest.write_report (results);
            if (path == "") {
                ask_ok (_("The report could not be written"),
                        _("Check the space in your home folder."));
                return;
            }
            try {
                Process.spawn_async (null, { "xdg-open", path }, null,
                    SpawnFlags.SEARCH_PATH, null, null);
            } catch (Error e) {
                warning ("kavis-settings: could not open the report: %s",
                         e.message);
            }
        }

        /* --- interactive checks ---------------------------------------- */

        private HwTest.Check result (string id, string title,
                                     HwTest.Result r, string detail) {
            var c = new HwTest.Check ();
            c.id = id;
            c.title = title;
            c.result = r;
            c.detail = detail;
            return c;
        }

        /* Counts DISTINCT keys, so holding one down does not pass the
         * test, and shows them as they arrive so a key that repeats or
         * never arrives is visible. */
        private HwTest.Check keyboard_test () {
            var window = page.get_toplevel () as Gtk.Window;
            var dialog = new Gtk.Dialog.with_buttons (_("Keyboard"), window,
                Gtk.DialogFlags.MODAL | Gtk.DialogFlags.USE_HEADER_BAR,
                _("Something did not work"), Gtk.ResponseType.REJECT,
                _("Done"), Gtk.ResponseType.OK);
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.margin = 16;
            var instruction = new Gtk.Label (
                _("Press at least eight different keys."));
            var seen_label = new Gtk.Label ("");
            seen_label.set_line_wrap (true);
            seen_label.set_max_width_chars (40);
            box.pack_start (instruction, false, false, 0);
            box.pack_start (seen_label, false, false, 0);
            ((Gtk.Box) dialog.get_content_area ()).pack_start (box, true, true, 0);

            var pressed = new GenericSet<string> (str_hash, str_equal);
            dialog.key_press_event.connect ((event) => {
                unowned string? name = Gdk.keyval_name (event.keyval);
                if (name != null && !pressed.contains (name)) {
                    pressed.add (name);
                    var all = new GenericArray<string> ();
                    pressed.foreach ((k) => { all.add (k); });
                    all.sort (strcmp);
                    var shown = new StringBuilder ();
                    for (int i = 0; i < all.length; i++) {
                        if (i > 0) {
                            shown.append_c (' ');
                        }
                        shown.append (all[i]);
                    }
                    seen_label.set_text (shown.str);
                    instruction.set_text (
                        ngettext ("%d more key to press",
                                  "%d more keys to press",
                                  int.max (0, 8 - (int) pressed.length))
                            .printf (int.max (0, 8 - (int) pressed.length)));
                }
                /* Swallow the key: Escape and Return would otherwise
                 * close the dialog before they can be counted. */
                return true;
            });
            dialog.show_all ();
            int answer = dialog.run ();
            int distinct = (int) pressed.length;
            dialog.destroy ();
            if (answer == Gtk.ResponseType.REJECT) {
                return result ("keyboard", _("Keyboard"), HwTest.Result.FAIL,
                    _("Reported as not working after %d keys").printf (distinct));
            }
            if (distinct < 8) {
                return result ("keyboard", _("Keyboard"), HwTest.Result.SKIP,
                    _("Stopped after %d keys").printf (distinct));
            }
            return result ("keyboard", _("Keyboard"), HwTest.Result.PASS,
                _("%d different keys registered").printf (distinct));
        }

        private HwTest.Check mouse_test () {
            var window = page.get_toplevel () as Gtk.Window;
            var dialog = new Gtk.Dialog.with_buttons (_("Mouse"), window,
                Gtk.DialogFlags.MODAL | Gtk.DialogFlags.USE_HEADER_BAR,
                _("Something did not work"), Gtk.ResponseType.REJECT,
                _("Done"), Gtk.ResponseType.OK);
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.margin = 16;
            var area = new Gtk.DrawingArea ();
            area.set_size_request (320, 160);
            area.add_events (Gdk.EventMask.BUTTON_PRESS_MASK
                             | Gdk.EventMask.SCROLL_MASK
                             | Gdk.EventMask.POINTER_MOTION_MASK);
            var todo = new Gtk.Label ("");
            box.pack_start (new Gtk.Label (
                _("Inside the box: click left, click right, scroll up, scroll down, and move the pointer.")),
                false, false, 0);
            box.pack_start (area, true, true, 0);
            box.pack_start (todo, false, false, 0);
            ((Gtk.Box) dialog.get_content_area ()).pack_start (box, true, true, 0);

            var done = new GenericSet<string> (str_hash, str_equal);
            void update () {
                string[] want = { "left", "right", "up", "down", "move" };
                string[] missing = {};
                foreach (unowned string w in want) {
                    if (!done.contains (w)) {
                        missing += w;
                    }
                }
                todo.set_text (missing.length == 0
                    ? _("All five registered.")
                    : _("Still missing: %d").printf (missing.length));
            }
            area.button_press_event.connect ((event) => {
                if (event.button == Gdk.BUTTON_PRIMARY) {
                    done.add ("left");
                } else if (event.button == Gdk.BUTTON_SECONDARY) {
                    done.add ("right");
                }
                update ();
                return true;
            });
            area.scroll_event.connect ((event) => {
                if (event.direction == Gdk.ScrollDirection.UP) {
                    done.add ("up");
                } else if (event.direction == Gdk.ScrollDirection.DOWN) {
                    done.add ("down");
                }
                update ();
                return true;
            });
            area.motion_notify_event.connect (() => {
                done.add ("move");
                update ();
                return true;
            });
            update ();
            dialog.show_all ();
            int answer = dialog.run ();
            int count = (int) done.length;
            dialog.destroy ();
            if (answer == Gtk.ResponseType.REJECT) {
                return result ("mouse", _("Mouse"), HwTest.Result.FAIL,
                    _("Reported as not working (%d of 5 registered)")
                        .printf (count));
            }
            if (count < 5) {
                return result ("mouse", _("Mouse"), HwTest.Result.SKIP,
                    _("Stopped with %d of 5 registered").printf (count));
            }
            return result ("mouse", _("Mouse"), HwTest.Result.PASS,
                _("Buttons, wheel and movement all registered"));
        }

        /* speaker-test from alsa-utils plays a channel at a time, which
         * also tells left from right — more useful than one beep. */
        private HwTest.Check sound_test () {
            if (Environment.find_program_in_path ("speaker-test") == null) {
                return result ("sound", _("Sound output"), HwTest.Result.SKIP,
                    _("alsa-utils is not installed"));
            }
            Pid pid = 0;
            try {
                Process.spawn_async (null,
                    { "speaker-test", "-t", "sine", "-f", "440",
                      "-l", "3", "-c", "2" },
                    null, SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD
                        | SpawnFlags.STDOUT_TO_DEV_NULL
                        | SpawnFlags.STDERR_TO_DEV_NULL,
                    null, out pid);
            } catch (Error e) {
                return result ("sound", _("Sound output"), HwTest.Result.SKIP,
                    _("The test tone could not be played: %s").printf (e.message));
            }
            bool heard = ask_yes_no (_("Sound output"),
                _("A tone is playing on the left and right speakers. Do you hear it?"));
            if (pid != 0) {
                Posix.kill ((Posix.pid_t) pid, Posix.Signal.TERM);
                Process.close_pid (pid);
            }
            return heard
                ? result ("sound", _("Sound output"), HwTest.Result.PASS,
                          _("The tone was heard"))
                : result ("sound", _("Sound output"), HwTest.Result.FAIL,
                          _("No sound — check the volume, the mute switch and the cable"));
        }

        /* Full-screen solid colours. Black finds stuck bright pixels,
         * white finds dead ones, and the three primaries find a channel
         * that is missing on part of the panel. */
        private HwTest.Check screen_test () {
            string[] colours = { "#000000", "#FFFFFF", "#FF0000",
                                 "#00FF00", "#0000FF" };
            var window = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
            window.fullscreen ();
            window.set_app_paintable (true);
            var area = new Gtk.DrawingArea ();
            window.add (area);
            int index = 0;
            area.draw.connect ((cr) => {
                Gdk.RGBA colour = Gdk.RGBA ();
                colour.parse (colours[index]);
                cr.set_source_rgb (colour.red, colour.green, colour.blue);
                cr.paint ();
                /* The instruction has to stay readable on every ground,
                 * so it is drawn twice, dark on light and light on
                 * dark, one of which always shows. */
                cr.select_font_face ("sans", Cairo.FontSlant.NORMAL,
                                     Cairo.FontWeight.NORMAL);
                cr.set_font_size (18);
                string text = _("Any key: next colour · Escape: finish");
                Cairo.TextExtents ext;
                cr.text_extents (text, out ext);
                double x = (area.get_allocated_width () - ext.width) / 2;
                double y = area.get_allocated_height () - 40;
                cr.set_source_rgba (0, 0, 0, 0.55);
                cr.move_to (x + 1, y + 1);
                cr.show_text (text);
                cr.set_source_rgba (1, 1, 1, 0.85);
                cr.move_to (x, y);
                cr.show_text (text);
                return true;
            });
            var loop = new MainLoop ();
            window.key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape
                    || index >= colours.length - 1) {
                    loop.quit ();
                    return true;
                }
                index++;
                area.queue_draw ();
                return true;
            });
            window.delete_event.connect (() => { loop.quit (); return true; });
            window.show_all ();
            loop.run ();
            int shown = index + 1;
            window.destroy ();
            bool clean = ask_yes_no (_("Screen"),
                _("Were all the colours even, with no dots or patches?"));
            if (!clean) {
                return result ("screen", _("Screen"), HwTest.Result.FAIL,
                    _("Uneven colour or dead pixels reported"));
            }
            if (shown < colours.length) {
                return result ("screen", _("Screen"), HwTest.Result.SKIP,
                    _("Stopped after %d of %d colours")
                        .printf (shown, colours.length));
            }
            return result ("screen", _("Screen"), HwTest.Result.PASS,
                _("All %d colours looked even").printf (colours.length));
        }

        private bool ask_yes_no (string title, string question) {
            var window = page.get_toplevel () as Gtk.Window;
            var dialog = new Gtk.MessageDialog (window, Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", question);
            dialog.set_title (title);
            dialog.add_button (_("No"), Gtk.ResponseType.NO);
            dialog.add_button (_("Yes"), Gtk.ResponseType.YES);
            dialog.set_default_response (Gtk.ResponseType.YES);
            bool answer = dialog.run () == Gtk.ResponseType.YES;
            dialog.destroy ();
            return answer;
        }

        private void ask_ok (string summary_text, string detail) {
            var window = page.get_toplevel () as Gtk.Window;
            var dialog = new Gtk.MessageDialog (window, Gtk.DialogFlags.MODAL,
                Gtk.MessageType.INFO, Gtk.ButtonsType.CLOSE, "%s", summary_text);
            dialog.format_secondary_text ("%s", detail);
            dialog.run ();
            dialog.destroy ();
        }
    }
}
