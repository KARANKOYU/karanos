/* kavis-lock — the lock screen (item 70).
 *
 * A LOCK SCREEN THAT CANNOT BE UNLOCKED IS THE WORST BUG THIS PROJECT
 * CAN SHIP, and v0.5-test1 shipped it: the screen asked for a password,
 * and every answer came back "Wrong password" with no way out of the
 * session. The account was believed to have no password. It did:
 * live-config's user-setup gives the live user the password "live"
 * (a crypted default inside the component, no boot parameter turns it
 * off) and nothing on screen said so. The live image now deletes that
 * password at boot (0031-kavis-dirs), so "no password" is true rather
 * than assumed, and boot-check reads /etc/shadow to prove it. Three
 * things came out of the trap, and all three are here:
 *
 *   1. Whether an account can be locked is now asked of PAM, not
 *      inferred from group membership. Being in `nopasswdlogin` is a
 *      hint that lightdm honours; it is not the authority on whether a
 *      password exists, and when the hint was missing the lock believed
 *      there was a password to type. PAM is the thing that will judge
 *      the answer later, so it is the thing to ask first.
 *   2. An account with no password is NOT locked at all. Win+L says
 *      why and points at where a password would be set. Locking a
 *      session that anyone can open with Enter protects nothing, and
 *      the failure mode of getting it wrong is a machine nobody can
 *      get back into.
 *   3. There is always a way out. Three refusals inside thirty seconds
 *      reveal a Log out button — losing an unsaved document is bad,
 *      being locked out of your own computer is worse, and the person
 *      who reaches that button has already told us the password is not
 *      working.
 *
 * One full-screen window per monitor — the card on the primary one,
 * a plain cover on every other — over everything, with the keyboard
 * and the pointer grabbed. The password goes to PAM,
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

    /* The lock screen's own CSS, installed once per process by main()
     * — for BOTH windows. It used to be loaded inside LockWindow's
     * constructor, so the notice a passwordless account gets (the only
     * window the live image ever shows) came up as a stock GTK box:
     * no card, no padding, no accent on its button. */
    namespace LockStyle {
        public void install () {
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (LockWindow.CSS, LockWindow.CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-lock: CSS: %s", e.message);
            }
        }
    }

    public class LockWindow : Gtk.Window {

        public const string CSS = """
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
        /* The accent, not the stock GTK "suggested" blue: the lock
           screen is the one Kavis window a stranger sees first, and it
           was the one window wearing another desktop's colour. */
        .kavis-lock-card button.kavis-accent {
          background-image: none;
          background-color: @kavis_teal;
          color: @kavis_on_teal;
          border: 1px solid @kavis_teal;
          border-radius: 6px;
          min-height: 34px;
          padding: 0 20px;
          font-weight: 600;
        }
        .kavis-lock-card button.kavis-accent:hover {
          background-color: shade(@kavis_teal, 1.08);
        }
        .kavis-lock-notice {
          font-size: 15px;
          color: @kavis_text;
        }
        .kavis-lock-hint {
          font-size: 13px;
          color: @kavis_text2;
        }
        /* The notice: the WINDOW carries the card's background and
           border (a card inside a backdrop-coloured window left a rim
           around the rounded corners), but GtkWindow ignores CSS
           padding, so the inset lives on the box inside. */
        .kavis-lock-notice-body {
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
          /* The palette's name, not the hex: on the light theme the
             dark-theme red is 3.8:1 on white and the message telling
             somebody their password is wrong was the hardest thing on
             screen to read. */
          color: @kavis_error;
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
        private Gtk.Button logout_button;
        private Gdk.Pixbuf? background = null;
        private Gdk.Seat? grabbed_seat = null;

        /* A2: refusals, and when the first of the current run was. Three
         * inside thirty seconds means the password is not working —
         * whatever the reason — and the way out has to be on screen. */
        private int refusals = 0;
        private int64 first_refusal = 0;
        private const int REFUSALS_BEFORE_ESCAPE = 3;
        private const int64 REFUSAL_WINDOW_US = 30 * 1000000;

        /* One PAM conversation at a time. try_unlock pumps the main
         * loop before blocking in PAM, and pam_unix holds a failure for
         * two seconds; an Enter pressed in that time used to queue up,
         * fire against the just-emptied field, and count as a second
         * refusal the person never made. */
        private bool checking = false;
        /* When the last refusal came back. Keys pressed while PAM was
         * blocking are delivered the moment it returns; an Enter among
         * them submits the field that was just emptied. An EMPTY
         * submission inside this window after a refusal is that queued
         * Enter, not a new attempt. A deliberate empty password (the
         * right answer on an account that has none) comes later than
         * this. */
        private int64 last_refusal = 0;
        private const int64 QUEUED_ENTER_US = 500 * 1000;

        public LockWindow () {
            Object (type: Gtk.WindowType.TOPLEVEL);

            set_app_paintable (true);
            set_decorated (false);
            set_keep_above (true);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_type_hint (Gdk.WindowTypeHint.SPLASHSCREEN);
            /* Not fullscreen(): on a screen with two monitors that
             * covers the one the pointer happens to be on and leaves the
             * other showing the desktop — its windows, its text — with
             * only the keyboard taken away. The card goes on the
             * primary monitor and main() puts a LockCover on each of
             * the others. */
            fullscreen_on_monitor (Gdk.Screen.get_default (),
                                   primary_monitor ());
            get_style_context ().add_class ("kavis-lock");

            background = Wallpaper.blurred ();

            /* A4: ONE card. The clock used to float above a second,
             * narrower card and the two were centred independently, so
             * they never lined up with each other at any screen size.
             * Everything the lock screen shows is one thing the person
             * is looking at, so it is one card. */
            var centre = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            centre.set_halign (Gtk.Align.CENTER);
            centre.set_valign (Gtk.Align.CENTER);

            var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            card.get_style_context ().add_class ("kavis-lock-card");

            clock_label = new Gtk.Label ("");
            clock_label.get_style_context ().add_class ("kavis-lock-clock");
            date_label = new Gtk.Label ("");
            date_label.get_style_context ().add_class ("kavis-lock-date");
            card.pack_start (clock_label, false, false, 0);
            card.pack_start (date_label, false, false, 8);

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

            unlock_button = new Gtk.Button.with_label (_("Unlock"));
            unlock_button.get_style_context ().add_class ("kavis-accent");
            unlock_button.clicked.connect (() => try_unlock ());

            card.pack_start (password, false, false, 0);
            card.pack_start (unlock_button, false, false, 0);
            unlock_button.set_can_default (true);

            error_label = new Gtk.Label ("");
            error_label.get_style_context ().add_class ("kavis-lock-error");
            error_label.set_no_show_all (true);
            card.pack_start (error_label, false, false, 0);

            /* A2: hidden until the password has failed enough times to
             * mean something. Shown from the start it would read as an
             * invitation to give up; shown after three refusals it is
             * the only thing on screen that can still help. */
            logout_button = new Gtk.Button.with_label (_("Log out"));
            logout_button.set_no_show_all (true);
            logout_button.clicked.connect (() => log_out ());
            card.pack_start (logout_button, false, false, 0);

            centre.pack_start (card, false, false, 0);
            add (centre);

            draw.connect (on_draw);
            set_default (unlock_button);
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

        /* The monitor that gets the card: the one X calls primary, or
         * the first when none is marked (Xvfb, a bare VM). */
        public static int primary_monitor () {
            var display = Gdk.Display.get_default ();
            var primary = display.get_primary_monitor ();
            for (int i = 0; i < display.get_n_monitors (); i++) {
                if (display.get_monitor (i) == primary) {
                    return i;
                }
            }
            return 0;
        }

        public unowned Gdk.Pixbuf? wallpaper () {
            return background;
        }

        private bool on_draw (Cairo.Context cr) {
            Wallpaper.paint (cr, background,
                             get_allocated_width (), get_allocated_height ());
            return false;
        }

        private void tick () {
            var now = new DateTime.now_local ();
            clock_label.set_text (now.format (TimeFmt.time_format ()));
            date_label.set_text (now.format (TimeFmt.date_format ()));
        }

        private void try_unlock () {
            if (checking) {
                return;
            }
            string secret = password.get_text ();
            if (secret == "" && last_refusal != 0
                && get_monotonic_time () - last_refusal < QUEUED_ENTER_US) {
                return;
            }
            checking = true;
            unlock_button.set_sensitive (false);
            error_label.hide ();
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
            /* Before telling somebody their password is wrong, make
             * sure this account has one. If an empty password unlocks
             * it, the group that was supposed to say so is missing and
             * the lock is refusing everything — including the answer
             * that would work. Do not trap the session over it. */
            if (Auth.accepts_empty ()) {
                warning ("kavis-lock: this account unlocks with an empty "
                         + "password — not locking");
                release ();
                Gtk.main_quit ();
                return;
            }
            error_label.set_text (_("Wrong password"));
            error_label.show ();
            unlock_button.set_sensitive (true);
            password.grab_focus ();
            note_refusal ();
            last_refusal = get_monotonic_time ();
            checking = false;
        }

        /* A2. The counter restarts when the refusals stop coming: a
         * password mistyped once this morning and once tonight is not
         * somebody locked out. */
        private void note_refusal () {
            int64 now = get_monotonic_time ();
            if (refusals == 0 || now - first_refusal > REFUSAL_WINDOW_US) {
                refusals = 0;
                first_refusal = now;
            }
            refusals++;
            if (refusals >= REFUSALS_BEFORE_ESCAPE) {
                logout_button.show ();
                /* One string literal, not two joined with "+":
                 * xgettext takes the first literal and the translation
                 * would end mid-sentence. */
                error_label.set_text (
                    _("Wrong password. Log out to end the session — unsaved work will be lost."));
            }
        }

        /* End the session rather than the screen. The lock is released
         * first: a session torn down under a live seat grab leaves the
         * next one without a keyboard. logind is asked first because it
         * closes the session properly; openbox is the fallback when
         * there is no logind session to close. */
        private void log_out () {
            release ();
            string? id = Environment.get_variable ("XDG_SESSION_ID");
            try {
                if (id != null && id != "") {
                    Process.spawn_command_line_sync (
                        "loginctl terminate-session " + id);
                } else {
                    Process.spawn_command_line_sync ("openbox --exit");
                }
            } catch (Error e) {
                warning ("kavis-lock: could not end the session: %s",
                         e.message);
            }
            Gtk.main_quit ();
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

        /* A3: the login name, not the gecos field.
         *
         * The gecos of the live account is written by live-config and
         * says "Debian Live user" — so the one screen that introduces
         * the machine was introducing a different distribution. Kavis
         * has no user profile to read a real name from yet (the user
         * system is postponed, docs item 0); until it does, the name
         * Kavis knows is the login name, and that is the honest thing
         * to show. When the profile arrives this reads it instead —
         * NOT the gecos, which is a field the distribution below us
         * fills in. */
        public string display_name () {
            return Environment.get_user_name ();
        }

        /* Whether this session has a password at all.
         *
         * Group membership is asked first because it costs nothing, but
         * it is only a hint: `nopasswdlogin` is a lightdm convention,
         * and a live image whose user did not end up in that group
         * still has an account with no password. v0.5-test1 was exactly
         * that case and the lock screen asked for a password that could
         * not exist. So when the hint says nothing, PAM is asked
         * directly — the same PAM that would judge the answer later, so
         * its verdict cannot disagree with itself. */
        public bool passwordless () {
            return Kavis.Session.passwordless ();
        }

        /* One PAM round trip with an empty secret: does this account
         * unlock with no password at all?
         *
         * NOT asked before showing the lock. On an account that HAS a
         * password an empty one fails, and pam_unix answers a failure
         * with a two-second delay — two seconds in which Win+L has been
         * pressed and the desktop is still there, unlocked. It is asked
         * after the FIRST refusal instead, where the delay has already
         * been paid and the answer is worth having: an account whose
         * empty password works, refusing what the person types, is a
         * session about to be locked out of itself. */
        public bool accepts_empty () {
            return verdict ("") == Pam.SUCCESS;
        }

        /* One complete PAM transaction: start, authenticate, account,
         * end. Both questions the lock asks go through here, so they
         * cannot be answered by two different stacks.
         *
         * KAVIS_PAM_CONFDIR is a test hook, like KAVIS_GROUP_FILE in
         * session.vala: when set, the service file is read from that
         * directory instead of /etc/pam.d, so the password path can be
         * driven end to end under Xvfb with a stack of pam_exec. Unset
         * on a real system. */
        private int verdict (string secret) {
            conversation_password = secret;
            Pam.Conv conv = { conversation, null };
            unowned Pam.Handle handle;
            string user = Environment.get_user_name ();
            string? confdir = Environment.get_variable ("KAVIS_PAM_CONFDIR");
            int rc;
            if (confdir != null && confdir != "") {
                rc = Pam.start_confdir ("kavis-lock", user, ref conv,
                                        confdir, out handle);
            } else {
                rc = Pam.start ("kavis-lock", user, ref conv, out handle);
            }
            if (rc != Pam.SUCCESS) {
                warning ("kavis-lock: pam_start failed (%d)", rc);
                conversation_password = null;
                return rc;
            }
            /* No DISALLOW_NULL_AUTHTOK: on an account with an empty
             * password that flag makes PAM refuse, which would lock a
             * live session out of its own desktop. What may unlock is
             * PAM's decision, not a flag we pass. */
            rc = Pam.authenticate (handle, 0);
            /* The account stack too. /etc/pam.d/kavis-lock includes
             * common-account so that an expired or disabled account
             * cannot unlock a screen it could not log into — and that
             * line was never consulted, because only authenticate was
             * called. A right password is not the whole verdict. */
            if (rc == Pam.SUCCESS) {
                rc = Pam.acct_mgmt (handle, 0);
                /* "The password has expired, change it": the password
                 * was RIGHT. Changing it is the next login's job; a
                 * lock screen that refuses a right password over it
                 * has locked somebody out for a policy reminder. */
                if (rc == Pam.NEW_AUTHTOK_REQD) {
                    rc = Pam.SUCCESS;
                }
            }
            if (rc != Pam.SUCCESS) {
                debug ("kavis-lock: PAM refused: %s",
                       Pam.strerror (handle, rc));
            }
            Pam.end (handle, rc);
            conversation_password = null;
            return rc;
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
            return verdict (secret) == Pam.SUCCESS;
        }
    }

    /* --- the blurred wallpaper ---------------------------------------- */

    namespace Wallpaper {

        /* The wallpaper, blurred, painted under everything. Without one
         * the ground colour still applies, so a machine with no
         * wallpaper set is not a black rectangle by accident. Shared
         * by the card window and the covers on the other monitors. */
        public void paint (Cairo.Context cr, Gdk.Pixbuf? background,
                           int w, int h) {
            if (background == null) {
                return;
            }
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

/* A cover for a monitor that is not the primary one: the blurred
 * wallpaper and nothing else. It takes no focus and no grab — the card
 * window holds both — its whole job is that the second monitor does
 * not keep showing the desktop while the first says "locked". */
public class Kavis.LockCover : Gtk.Window {

    private Gdk.Pixbuf? background;

    public LockCover (Gdk.Pixbuf? background, int monitor) {
        Object (type: Gtk.WindowType.TOPLEVEL);
        this.background = background;
        set_app_paintable (true);
        set_decorated (false);
        set_keep_above (true);
        set_skip_taskbar_hint (true);
        set_skip_pager_hint (true);
        set_accept_focus (false);
        set_type_hint (Gdk.WindowTypeHint.SPLASHSCREEN);
        get_style_context ().add_class ("kavis-lock");
        fullscreen_on_monitor (Gdk.Screen.get_default (), monitor);
        draw.connect ((cr) => {
            Wallpaper.paint (cr, this.background,
                             get_allocated_width (), get_allocated_height ());
            return false;
        });
    }
}

/* A1: what Win+L says on an account that has no password.
 *
 * Not a lock: a card that explains why, and goes away by itself. It is
 * a plain window with no grab — the point is that the session stays
 * usable. */
public class Kavis.LockNotice : Gtk.Window {

    public LockNotice () {
        Object (type: Gtk.WindowType.TOPLEVEL);
        title = _("Lock screen");
        set_decorated (false);
        set_keep_above (true);
        set_skip_taskbar_hint (true);
        set_position (Gtk.WindowPosition.CENTER);
        /* The window IS the card: with the card as a box inside a
         * backdrop-coloured window, a rim of backdrop showed around the
         * rounded corners. */
        get_style_context ().add_class ("kavis-lock");
        get_style_context ().add_class ("kavis-lock-card");

        var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        card.get_style_context ().add_class ("kavis-lock-notice-body");
        var head = new Gtk.Label (_("This account has no password"));
        head.get_style_context ().add_class ("kavis-lock-notice");
        var hint = new Gtk.Label (
            _("Set a password first — a lock screen that anything can open protects nothing."));
        hint.set_line_wrap (true);
        hint.set_max_width_chars (44);
        hint.get_style_context ().add_class ("kavis-lock-hint");
        var close = new Gtk.Button.with_label (_("Close"));
        close.get_style_context ().add_class ("kavis-accent");
        close.clicked.connect (() => Gtk.main_quit ());
        card.pack_start (head, false, false, 0);
        card.pack_start (hint, false, false, 0);
        card.pack_start (close, false, false, 0);
        add (card);
        /* Long enough to read, short enough that a card nobody asked
         * for is not still there a minute later. */
        Timeout.add_seconds (8, () => { Gtk.main_quit (); return false; });
    }
}

int main (string[] args) {
    Kavis.AppInit.init ();
    Gtk.init (ref args);
    Kavis.Theme.install ();
    Kavis.LockStyle.install ();

    /* --idle: started by the idle watcher rather than by a person. The
     * difference matters in one place — a session that cannot be locked
     * explains itself to somebody who pressed Win+L, and says nothing
     * at all to a timer. */
    bool idle = false;
    foreach (unowned string arg in args) {
        if (arg == "--idle") {
            idle = true;
        }
    }

    /* One locker at a time. A second would fight the first for the
     * grab and leave the screen half covered. */
    if (Kavis.LockGuard.already_running ()) {
        return 0;
    }

    /* A1. An account with no password is not locked: the screen could
     * only be opened by pressing Enter, and getting the question wrong
     * in the other direction locks somebody out of their own machine. */
    if (Kavis.Auth.passwordless ()) {
        if (idle) {
            return 0;
        }
        var notice = new Kavis.LockNotice ();
        notice.show_all ();
        notice.destroy.connect (Gtk.main_quit);
        Gtk.main ();
        return 0;
    }

    var window = new Kavis.LockWindow ();
    window.show_all ();
    /* Every other monitor gets a cover. Created after the card window
     * so they stack above nothing of ours and below nothing that
     * matters — the grab is on the card, input never reaches them. */
    var covers = new GLib.List<Kavis.LockCover> ();
    var display = Gdk.Display.get_default ();
    int primary = Kavis.LockWindow.primary_monitor ();
    for (int i = 0; i < display.get_n_monitors (); i++) {
        if (i == primary) {
            continue;
        }
        var cover = new Kavis.LockCover (window.wallpaper (), i);
        cover.show_all ();
        covers.append (cover);
    }
    if (!window.grab ()) {
        warning ("kavis-lock: could not grab the keyboard — not locking");
        return 1;
    }
    Gtk.main ();
    window.release ();
    foreach (var cover in covers) {
        cover.destroy ();
    }
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
