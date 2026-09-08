/* Run — Win+R (feedback, 8 Sep 2026).
 *
 * Win+R used to open the Start menu with its search box focused, which
 * is a different thing wearing the same key: the Start search looks for
 * APPLICATIONS, and Run is for typing a command, a path or an address
 * and pressing Enter. On Windows they are two dialogs for a reason, and
 * the person pressing Win+R has usually already decided what to type.
 *
 * What it accepts, decided in this order because the first match is
 * almost always what was meant:
 *   1. an absolute or ~ path        -> opened with its default handler
 *   2. a URL, or something that looks like a host (kavis.dev, an IP)
 *                                   -> the browser
 *   3. anything else                -> a command line, run through the
 *                                      shell so quoting and arguments
 *                                      behave the way a terminal does
 *
 * History is the last 30 lines, most recent first, in
 * ~/.local/share/kavis/run-history. Up and Down walk it; typing filters
 * the completion. Nothing is remembered from a command that failed to
 * start — a typo does not deserve a place in the list.
 *
 * "Run as administrator" is pkexec, so the password prompt is the
 * system's own policy agent rather than anything Kavis invents.
 */

namespace Kavis.Tools {

    public class RunWindow : Gtk.Window {

        private const int HISTORY_MAX = 30;

        private Gtk.Entry entry;
        private Gtk.Label error_label;
        private Gtk.CheckButton as_admin;
        private string[] history = {};
        /* Where Up/Down is in the history; -1 = editing a fresh line. */
        private int walk = -1;
        private string typed = "";

        public RunWindow () {
            set_title (_("Run"));
            set_default_size (420, -1);
            set_resizable (false);
            set_position (Gtk.WindowPosition.CENTER);
            /* A dialog, not an application window: no taskbar button
             * and no place in Alt+Tab for a box that lives for five
             * seconds. */
            set_type_hint (Gdk.WindowTypeHint.DIALOG);
            set_skip_taskbar_hint (true);
            Kavis.HeaderBar.attach (this, _("Run"), "system-run");

            load_history ();

            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            root.set_border_width (16);
            add (root);

            var hint = new Gtk.Label (
                _("Type the name of a program, folder, document or address."));
            hint.set_xalign (0);
            hint.set_line_wrap (true);
            hint.get_style_context ().add_class ("dim-label");
            root.pack_start (hint, false, false, 0);

            entry = new Gtk.Entry ();
            entry.set_activates_default (true);
            entry.set_placeholder_text (_("Open"));
            entry.activate.connect (() => go ());
            entry.key_press_event.connect (on_key);
            /* The completion is the history plus every executable name
             * on the PATH: the answer to "what was that command called"
             * is usually three letters away. */
            var completion = new Gtk.EntryCompletion ();
            var store = new Gtk.ListStore (1, typeof (string));
            fill_completion (store);
            completion.set_model (store);
            completion.set_text_column (0);
            completion.set_inline_completion (true);
            completion.set_popup_single_match (false);
            entry.set_completion (completion);
            root.pack_start (entry, false, false, 0);

            as_admin = new Gtk.CheckButton.with_label (
                _("Run as administrator"));
            root.pack_start (as_admin, false, false, 0);

            error_label = new Gtk.Label ("");
            error_label.set_xalign (0);
            error_label.set_line_wrap (true);
            error_label.set_no_show_all (true);
            error_label.get_style_context ().add_class ("kavis-run-error");
            root.pack_start (error_label, false, false, 0);

            var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            buttons.set_halign (Gtk.Align.END);
            var cancel = new Gtk.Button.with_label (_("Cancel"));
            cancel.clicked.connect (() => destroy ());
            var ok = new Gtk.Button.with_label (_("OK"));
            ok.get_style_context ().add_class ("kavis-accent");
            ok.can_default = true;
            ok.clicked.connect (() => go ());
            buttons.pack_start (cancel, false, false, 0);
            buttons.pack_start (ok, false, false, 0);
            root.pack_start (buttons, false, false, 0);
            set_default (ok);

            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data ("""
                    .kavis-run-error { color: @kavis_error; }
                    button.kavis-accent {
                      background-image: none;
                      background-color: @kavis_teal;
                      color: @kavis_on_teal;
                      border: 1px solid @kavis_teal;
                      border-radius: 6px;
                      padding: 0 20px;
                      font-weight: 600;
                    }
                """);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-tools: run css: %s", e.message);
            }

            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    destroy ();
                    return true;
                }
                return false;
            });
        }

        /* --- history ------------------------------------------------ */

        private string history_path () {
            return Path.build_filename (Environment.get_user_data_dir (),
                                        "kavis", "run-history");
        }

        private void load_history () {
            string contents;
            try {
                FileUtils.get_contents (history_path (), out contents);
            } catch (Error e) {
                return;
            }
            foreach (unowned string line in contents.split ("\n")) {
                if (line.strip () != "") {
                    history += line;
                }
            }
        }

        private void remember (string line) {
            string[] kept = { line };
            foreach (unowned string old in history) {
                if (old != line && kept.length < HISTORY_MAX) {
                    kept += old;
                }
            }
            history = kept;
            string dir = Path.get_dirname (history_path ());
            DirUtils.create_with_parents (dir, 0755);
            try {
                FileUtils.set_contents (history_path (),
                                        string.joinv ("\n", history) + "\n");
                /* The list is a record of what somebody typed on their
                 * own machine; it is nobody else's business. */
                FileUtils.chmod (history_path (), 0600);
            } catch (Error e) {
                warning ("kavis-tools: could not write the run history: %s",
                         e.message);
            }
        }

        private void fill_completion (Gtk.ListStore store) {
            var seen = new GenericSet<string> (str_hash, str_equal);
            Gtk.TreeIter iter;
            foreach (unowned string line in history) {
                if (!seen.contains (line)) {
                    seen.add (line);
                    store.append (out iter);
                    store.set (iter, 0, line);
                }
            }
            string? path = Environment.get_variable ("PATH");
            if (path == null) {
                return;
            }
            foreach (unowned string dir in path.split (":")) {
                try {
                    var d = Dir.open (dir);
                    string? name;
                    while ((name = d.read_name ()) != null) {
                        if (seen.contains (name)) {
                            continue;
                        }
                        seen.add (name);
                        store.append (out iter);
                        store.set (iter, 0, name);
                    }
                } catch (Error e) {
                    /* A directory on the PATH that does not exist is
                     * normal, not an error worth reporting. */
                }
            }
        }

        /* Up and Down walk the history the way a shell does: the line
         * being typed is kept, so walking away and back does not lose
         * it. */
        private bool on_key (Gdk.EventKey event) {
            if (event.keyval != Gdk.Key.Up && event.keyval != Gdk.Key.Down) {
                return false;
            }
            if (history.length == 0) {
                return true;
            }
            if (walk < 0) {
                typed = entry.get_text ();
            }
            if (event.keyval == Gdk.Key.Up) {
                walk = int.min (walk + 1, history.length - 1);
            } else {
                walk--;
            }
            if (walk < 0) {
                walk = -1;
                entry.set_text (typed);
            } else {
                entry.set_text (history[walk]);
            }
            entry.set_position (-1);
            return true;
        }

        /* --- running ------------------------------------------------ */

        private void go () {
            string line = entry.get_text ().strip ();
            if (line == "") {
                return;
            }
            string? failure = launch (line);
            if (failure != null) {
                error_label.set_text (failure);
                error_label.show ();
                entry.grab_focus ();
                return;
            }
            remember (line);
            destroy ();
        }

        /* null on success, otherwise the message to show. */
        private string? launch (string line) {
            bool admin = as_admin.active;
            string expanded = line.has_prefix ("~/")
                ? Path.build_filename (Environment.get_home_dir (),
                                       line.substring (2))
                : line;

            /* 1. A path that exists. Opened with its handler, not run:
             * "Documents" is a folder to show, not a program. */
            if (!admin && (expanded.has_prefix ("/") || line.has_prefix ("~/"))
                && FileUtils.test (expanded, FileTest.EXISTS)
                && !FileUtils.test (expanded, FileTest.IS_EXECUTABLE)) {
                return spawn ({ "xdg-open", expanded });
            }
            /* 2. An address. A bare host with a dot counts — typing
             * kavis.dev and getting "command not found" helps nobody. */
            if (!admin && looks_like_url (line)) {
                string url = line.contains ("://") ? line : "https://" + line;
                return spawn ({ "xdg-open", url });
            }
            /* 3. A command line. Through the shell so quotes, pipes and
             * arguments behave the way the person expects; pkexec first
             * when the box is ticked, so the prompt is the system's own
             * policy agent. */
            string[] argv = admin
                ? new string[] { "pkexec", "sh", "-c", line }
                : new string[] { "sh", "-c", line };
            /* A command that does not exist has to fail HERE, not in a
             * shell that has already been handed the line: `sh -c`
             * always starts. So the first word is looked up first. */
            string program = line.split (" ")[0];
            if (!program.contains ("/")
                && Environment.find_program_in_path (program) == null) {
                return _("There is no program called “%s”.").printf (program);
            }
            return spawn (argv);
        }

        private static bool looks_like_url (string line) {
            if (line.contains ("://")) {
                return true;
            }
            if (line.contains (" ") || !line.contains (".")) {
                return false;
            }
            /* A file name with an extension is not a host: the dot has
             * to be inside something that looks like a domain. */
            string last = line.substring (line.last_index_of (".") + 1);
            return last.length >= 2 && !last.contains ("/")
                && last.get_char ().isalpha ();
        }

        private string? spawn (string[] argv) {
            try {
                Process.spawn_async (null, argv, null,
                    SpawnFlags.SEARCH_PATH, null, null);
                return null;
            } catch (Error e) {
                return e.message;
            }
        }
    }
}
