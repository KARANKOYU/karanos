/* kavis-lock — the lock screen (item 70).
 *
 * One full-screen window per monitor's worth of screen, over everything,
 * with the keyboard and the pointer grabbed. The password goes to PAM,
 * which is the only way the answer respects the system's own rules:
 * account expiry, faillock, a fingerprint module. Comparing /etc/shadow
 * by hand would ignore all of that and need root besides.
 *
 * Started by: Win+L (the 0210 keybind hook), the panel when logind says
 * the session should lock (closing the lid, `loginctl lock-session`),
 * and the panel's idle watcher.
 *
 * Only one at a time — a second instance would fight the first for the
 * grab and leave the screen half covered, so it checks and exits.
 *
 * The look follows docs/tasarim-dili.md: blurred wallpaper, a 12px
 * card, Inter, the design curve on everything that moves.
 */

namespace Kavis {

    public class LockWindow : Gtk.Window {

        private const string CSS = """
        .kavis-lock {
          background-color: @kavis_backdrop;
        }
        .kavis-lock-card {
          background-color: @kavis_surface_acrylic;
          border: 1px solid @kavis_border;
          border-radius: 12px;
          box-shadow: inset 0 1px 0 @kavis_top_edge,
                      0 8px 24px rgba(0, 0, 0, 0.35);
          padding: 24px 32px;
        }
        .kavis-lock-clock {
          font-size: 64px;
          font-weight: 300;
          color: @kavis_text;
        }
        .kavis-lock-date {
          font-size: 16px;
          color: @kavis_text2;
        }
        .kavis-lock-user {
          font-size: 18px;
          color: @kavis_text;
        }
        .kavis-lock-error {
          color: #EF4444;
        }
        .kavis-lock entry {
          border-radius: 6px;
          min-height: 34px;
        }
        """;

        private Gtk.Label clock_label;
        private Gtk.Label date_label;
        private Gtk.Label error_label;
        private Gtk.Entry password;
        private Gtk.Button unlock_button;
        private Gdk.Pixbuf? background = null;
        private Gdk.Seat? grabbed_seat = null;
        private bool passwordless;

        public LockWindow () {
            Object (type: Gtk.WindowType.TOPLEVEL);
            passwordless = Auth.passwordless ();

            set_app_paintable (true);
            set_decorated (false);
            set_keep_above (true);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_type_hint (Gdk.WindowTypeHint.SPLASHSCREEN);
            fullscreen ();

            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-lock: CSS: %s", e.message);
            }
            get_style_context ().add_class ("kavis-lock");

            background = Wallpaper.blurred ();

            var centre = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
            centre.set_halign (Gtk.Align.CENTER);
            centre.set_valign (Gtk.Align.CENTER);

            clock_label = new Gtk.Label ("");
            clock_label.get_style_context ().add_class ("kavis-lock-clock");
            date_label = new Gtk.Label ("");
            date_label.get_style_context ().add_class ("kavis-lock-date");
            centre.pack_start (clock_label, false, false, 0);
            centre.pack_start (date_label, false, false, 0);

            var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            card.get_style_context ().add_class ("kavis-lock-card");
            var user = new Gtk.Label (Auth.display_name ());
            user.get_style_context ().add_class ("kavis-lock-user");
            card.pack_start (user, false, false, 0);

            password = new Gtk.Entry ();
            password.set_visibility (false);
            password.set_input_purpose (Gtk.InputPurpose.PASSWORD);
            password.set_placeholder_text (_("Password"));
            password.set_width_chars (24);
            password.set_activates_default (true);
            password.activate.connect (() => try_unlock ());

            unlock_button = new Gtk.Button.with_label (
                passwordless ? _("Sign in") : _("Unlock"));
            unlock_button.get_style_context ().add_class ("suggested-action");
            unlock_button.clicked.connect (() => try_unlock ());

            /* A session with no password gets one button, not an empty
             * field to press Enter in: asking for something that does
             * not exist is the sort of detail that makes a machine feel
             * unfinished. */
            if (!passwordless) {
                card.pack_start (password, false, false, 0);
            }
            card.pack_start (unlock_button, false, false, 0);

            error_label = new Gtk.Label ("");
            error_label.get_style_context ().add_class ("kavis-lock-error");
            error_label.set_no_show_all (true);
            card.pack_start (error_label, false, false, 0);

            centre.pack_start (card, false, false, 12);
            add (centre);

            draw.connect (on_draw);
            tick ();
            Timeout.add_seconds (1, () => { tick (); return Source.CONTINUE; });
            /* Escape clears the field rather than closing anything —
             * there is nothing to close, and a locker that reacts to
             * Escape at all is a locker somebody will try Escape on. */
            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    password.set_text ("");
                    return true;
                }
                return false;
            });
        }

        /* The wallpaper, blurred, painted under everything. Without one
         * the ground colour still applies, so a machine with no
         * wallpaper set is not a black rectangle by accident. */
        private bool on_draw (Cairo.Context cr) {
            if (background != null) {
                int w = get_allocated_width ();
                int h = get_allocated_height ();
                double sx = (double) w / background.get_width ();
                double sy = (double) h / background.get_height ();
                double scale = double.max (sx, sy);
                cr.save ();
                cr.scale (scale, scale);
                Gdk.cairo_set_source_pixbuf (cr, background, 0, 0);
                cr.paint ();
                cr.restore ();
                /* Darkened, so white text is readable over any picture
                 * and the card still reads as being in front. */
                cr.set_source_rgba (0.05, 0.08, 0.11, 0.55);
                cr.paint ();
            }
            return false;
        }

        private void tick () {
            var now = new DateTime.now_local ();
            clock_label.set_text (now.format (TimeFmt.time_format ()));
            date_label.set_text (now.format (TimeFmt.date_format ()));
        }

        private void try_unlock () {
            unlock_button.set_sensitive (false);
            error_label.hide ();
            string secret = passwordless ? "" : password.get_text ();
            /* PAM blocks, and pam_unix sleeps for two seconds after a
             * failure. Pumping the main loop first means the button
             * shows as pressed instead of the window looking frozen. */
            while (Gtk.events_pending ()) {
                Gtk.main_iteration ();
            }
            if (Auth.check (secret)) {
                release ();
                Gtk.main_quit ();
                return;
            }
            password.set_text ("");
            error_label.set_text (_("Wrong password"));
            error_label.show ();
            unlock_button.set_sensitive (true);
            password.grab_focus ();
        }

        /* Grab the keyboard and pointer, or the lock is decoration:
         * without the grab, Alt+Tab reaches the desktop behind. If the
         * grab cannot be taken (another grab is active — a menu was
         * open when the lock fired) the attempt is repeated for a few
         * seconds before giving up and exiting, which is safer than
         * showing a lock screen that does not lock. */
        public bool grab () {
            var display = Gdk.Display.get_default ();
            var seat = display.get_default_seat ();
            for (int attempt = 0; attempt < 20; attempt++) {
                var status = seat.grab (get_window (),
                    Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER,
                    true, null, null, null);
                if (status == Gdk.GrabStatus.SUCCESS) {
                    grabbed_seat = seat;
                    password.grab_focus ();
                    return true;
                }
                Thread.usleep (100000);
                while (Gtk.events_pending ()) {
                    Gtk.main_iteration ();
                }
            }
            return false;
        }

        public void release () {
            if (grabbed_seat != null) {
                grabbed_seat.ungrab ();
                grabbed_seat = null;
            }
        }
    }

    /* --- who is logged in, and is the password right ------------------ */

    namespace Auth {

        private static string? conversation_password = null;

        /* GLib reads the gecos field for us and copes with it being
         * empty or absent, which a live user's passwd entry often is;
         * it answers "Unknown" in that case, so the login name is the
         * fallback. */
        public string display_name () {
            unowned string? real = Environment.get_real_name ();
            if (real != null && real != "" && real != "Unknown") {
                return real;
            }
            return Environment.get_user_name ();
        }

        /* A live session where the user has no password at all: PAM
         * would accept anything, so asking for a password would be
         * theatre. Detected from the shadow field being empty, which is
         * what "no password" means to PAM too. */
        public bool passwordless () {
            string? shadow = null;
            try {
                string contents;
                FileUtils.get_contents ("/etc/shadow", out contents);
                foreach (unowned string line in contents.split ("\n")) {
                    string[] f = line.split (":");
                    if (f.length > 1 && f[0] == Environment.get_user_name ()) {
                        shadow = f[1];
                    }
                }
            } catch (Error e) {
                /* Not readable as a normal user on a normal system —
                 * assume a password exists, which is the safe answer. */
                return false;
            }
            return shadow != null && shadow == "";
        }

        private static int conversation (int num_msg, Pam.Message** msg,
                                         out Pam.Response* resp,
                                         void* appdata) {
            resp = null;
            if (num_msg <= 0) {
                return Pam.SUCCESS;
            }
            /* PAM frees this array itself, so it has to come from the C
             * allocator — not from a Vala string that Vala would also
             * free. */
            Pam.Response* answers =
                (Pam.Response*) GLib.malloc0 (sizeof (Pam.Response) * num_msg);
            for (int i = 0; i < num_msg; i++) {
                if (msg[i]->msg_style == Pam.PROMPT_ECHO_OFF
                    || msg[i]->msg_style == Pam.PROMPT_ECHO_ON) {
                    answers[i].resp =
                        GLib.strdup (conversation_password ?? "");
                }
                answers[i].resp_retcode = 0;
            }
            resp = answers;
            return Pam.SUCCESS;
        }

        public bool check (string secret) {
            if (passwordless ()) {
                return true;
            }
            conversation_password = secret;
            Pam.Conv conv = { conversation, null };
            unowned Pam.Handle handle;
            int rc = Pam.start ("kavis-lock", Environment.get_user_name (),
                                ref conv, out handle);
            if (rc != Pam.SUCCESS) {
                warning ("kavis-lock: pam_start failed (%d)", rc);
                conversation_password = null;
                return false;
            }
            rc = Pam.authenticate (handle, Pam.DISALLOW_NULL_AUTHTOK);
            Pam.end (handle, rc);
            conversation_password = null;
            return rc == Pam.SUCCESS;
        }
    }

    /* --- the blurred wallpaper ---------------------------------------- */

    namespace Wallpaper {

        /* Scale far down and back up: bilinear interpolation over a
         * tiny image IS a blur, costs one allocation, and needs no
         * image library beyond the one GTK already links. A real
         * gaussian would look marginally better and cost a dependency
         * plus a visible pause while the lock appears. */
        public Gdk.Pixbuf? blurred () {
            string path = "";
            try {
                path = Config.load ().get_string ("appearance", "wallpaper");
            } catch (Error e) { }
            if (path == "" || !FileUtils.test (path, FileTest.EXISTS)) {
                path = "/usr/share/backgrounds/kavis/kavis.png";
            }
            if (!FileUtils.test (path, FileTest.EXISTS)) {
                return null;
            }
            try {
                var full = new Gdk.Pixbuf.from_file (path);
                int w = int.max (1, full.get_width () / 24);
                int h = int.max (1, full.get_height () / 24);
                var small = full.scale_simple (w, h, Gdk.InterpType.BILINEAR);
                return small.scale_simple (full.get_width (),
                                           full.get_height (),
                                           Gdk.InterpType.BILINEAR);
            } catch (Error e) {
                warning ("kavis-lock: wallpaper: %s", e.message);
                return null;
            }
        }
    }
}

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);
    Kavis.Theme.install ();

    /* One locker at a time. A second would fight the first for the
     * grab and leave the screen half covered. */
    if (Kavis.LockGuard.already_running ()) {
        return 0;
    }

    var window = new Kavis.LockWindow ();
    window.show_all ();
    if (!window.grab ()) {
        warning ("kavis-lock: could not grab the keyboard — not locking");
        return 1;
    }
    Gtk.main ();
    window.release ();
    return 0;
}

namespace Kavis.LockGuard {

    /* A lock file with our pid in it. Checked against /proc rather than
     * trusted: a locker killed by the OOM killer must not leave the
     * machine unlockable. */
    private string path () {
        return Path.build_filename (
            Environment.get_variable ("XDG_RUNTIME_DIR") ?? "/tmp",
            "kavis-lock.pid");
    }

    public bool already_running () {
        string contents;
        try {
            FileUtils.get_contents (path (), out contents);
            int other = int.parse (contents.strip ());
            if (other > 0 && FileUtils.test ("/proc/%d".printf (other),
                                             FileTest.IS_DIR)) {
                return true;
            }
        } catch (Error e) { }
        try {
            FileUtils.set_contents (path (),
                                    "%d\n".printf ((int) Posix.getpid ()));
        } catch (Error e) { }
        return false;
    }
}
