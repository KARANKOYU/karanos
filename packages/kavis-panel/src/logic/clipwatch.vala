/* Who reads the clipboard (feedback, 8 Sep 2026).
 *
 * "A security section — which application is reading my clipboard."
 * On X11 that question has one honest answer and it costs something:
 * a clipboard read is a SelectionRequest sent to whoever OWNS the
 * selection, so only the owner can see it. The owner is normally the
 * application you copied from, which is not us.
 *
 * So this is opt-in and says why. With the setting on, Kavis takes
 * ownership of the clipboard after every copy — which is what a
 * clipboard manager does anyway, and it fixes the other half of the
 * same problem (on X the clipboard empties when the application you
 * copied from quits) — and from then on every read is a request to a
 * window we own, with the requestor's id in it.
 *
 * WHAT IT COSTS, stated in the UI rather than buried: Kavis serves the
 * content as text or as an image, so a copy carrying something richer
 * (formatted cells, a drawing object) pastes as its plain form once we
 * are the owner. That is a real loss for some people and no loss at
 * all for most, which is exactly the kind of decision that belongs to
 * the person and not to us.
 *
 * The reads are OBSERVED, not handled: GTK still answers the request.
 * A filter that returns CONTINUE sees the event on its way in and
 * changes nothing about it — the alternative, owning the selection at
 * the X level ourselves, would mean reimplementing TARGETS, MULTIPLE,
 * TIMESTAMP and INCR, and getting any of them subtly wrong breaks
 * pasting for everybody to add a log nobody asked to pay for.
 */

namespace Kavis {

    public class ClipWatch : Object {

        /* Kept small on purpose: this is a "what just happened" list,
         * not an audit trail, and it is written to the user's own
         * disk. */
        private const int MAX_LINES = 200;

        private static ClipWatch? instance = null;

        private X.Atom clipboard_atom;
        private X.Atom net_wm_pid;

        /* The signature has to match GdkFilterFunc EXACTLY or the C
         * compiler sees a second, conflicting declaration of
         * gdk_window_add_filter: GdkXEvent* is void*, but GdkEvent* is
         * not. */
        [CCode (has_target = false)]
        private delegate Gdk.FilterReturn RawFilter (void* xevent,
                                                     Gdk.Event* event,
                                                     void* data);

        /* gdk_window_add_filter (NULL, ...) is the global form: every
         * event for this application, including the selection requests
         * GTK is about to answer. The vapi only binds the per-window
         * method, so the C function is declared here. */
        [CCode (cname = "gdk_window_add_filter")]
        private static extern void add_global_filter (Gdk.Window? window,
                                                      RawFilter filter,
                                                      void* data);

        public static void start () {
            if (instance != null) {
                return;
            }
            instance = new ClipWatch ();
            add_global_filter (null, on_event, null);
        }

        private ClipWatch () {
            unowned X.Display xd =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            clipboard_atom = xd.intern_atom ("CLIPBOARD", false);
            net_wm_pid = xd.intern_atom ("_NET_WM_PID", false);
        }

        private static Gdk.FilterReturn on_event (void* xevent,
                                                  Gdk.Event* event,
                                                  void* data) {
            X.Event* ev = (X.Event*) xevent;
            if (ev->type == X.EventType.SelectionRequest
                && instance != null) {
                instance.note (ev->xselectionrequest.requestor,
                               ev->xselectionrequest.selection,
                               ev->xselectionrequest.target);
            }
            /* CONTINUE: GTK answers the request exactly as before. */
            return Gdk.FilterReturn.CONTINUE;
        }

        private void note (X.Window requestor, X.Atom selection,
                           X.Atom target) {
            if (selection != clipboard_atom) {
                return;   /* PRIMARY is the mouse selection, not this */
            }
            unowned X.Display xd =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            string? name = xd.get_atom_name (target);
            /* TARGETS is the question "what formats do you have", not
             * a read of the content. Logging it would fill the list
             * with entries for applications that only looked. */
            if (name == "TARGETS" || name == "TIMESTAMP"
                || name == "SAVE_TARGETS" || name == "MULTIPLE") {
                return;
            }
            append (describe (requestor), name ?? "?");
        }

        /* The requestor window belongs to some client; the name of that
         * client is what a person can act on. _NET_WM_PID is set by
         * every toolkit in use, but usually on the TOPLEVEL — the
         * requestor is often an unmapped helper window — so the tree is
         * walked upwards. */
        private string describe (X.Window requestor) {
            unowned X.Display xd =
                ((Gdk.X11.Display) Gdk.Display.get_default ()).get_xdisplay ();
            X.Window window = requestor;
            for (int depth = 0; depth < 8 && window != X.None; depth++) {
                int pid = pid_of (xd, window);
                if (pid > 0) {
                    string comm;
                    try {
                        FileUtils.get_contents (
                            "/proc/%d/comm".printf (pid), out comm);
                        return "%s (pid %d)".printf (comm.strip (), pid);
                    } catch (Error e) {
                        return "pid %d".printf (pid);
                    }
                }
                X.Window root, parent;
                X.Window[] children;
                Gdk.error_trap_push ();
                xd.query_tree (window, out root, out parent, out children);
                Gdk.error_trap_pop_ignored ();
                if (parent == X.None || parent == root) {
                    break;
                }
                window = parent;
            }
            return _("an application that did not identify itself");
        }

        private int pid_of (X.Display xd, X.Window window) {
            X.Atom actual_type;
            int actual_format;
            ulong items, remaining;
            void* prop = null;
            Gdk.error_trap_push ();
            int rc = xd.get_window_property (
                window, net_wm_pid, 0, 1, false, X.XA_CARDINAL,
                out actual_type, out actual_format, out items,
                out remaining, out prop);
            Gdk.error_trap_pop_ignored ();
            int pid = 0;
            if (rc == X.Success && prop != null && items >= 1) {
                pid = (int) ((ulong*) prop)[0];
                X.free (prop);
            }
            return pid;
        }

        private string log_path () {
            return Path.build_filename (Environment.get_user_data_dir (),
                                        "kavis", "clipboard-reads.log");
        }

        private void append (string who, string target) {
            string line = "%lld\t%s\t%s".printf (
                new DateTime.now_utc ().to_unix (), who, target);
            string existing = "";
            try {
                FileUtils.get_contents (log_path (), out existing);
            } catch (Error e) { }
            string[] lines = {};
            foreach (unowned string old in existing.split ("\n")) {
                if (old.strip () != "") {
                    lines += old;
                }
            }
            lines += line;
            int drop = int.max (0, lines.length - MAX_LINES);
            string[] kept = {};
            for (int i = drop; i < lines.length; i++) {
                kept += lines[i];
            }
            DirUtils.create_with_parents (Path.get_dirname (log_path ()),
                                          0700);
            try {
                FileUtils.set_contents (log_path (),
                                        string.joinv ("\n", kept) + "\n");
                FileUtils.chmod (log_path (), 0600);
            } catch (Error e) {
                warning ("kavis-panel: could not write the clipboard log: %s",
                         e.message);
            }
        }
    }
}
