/* Taking a file somebody sent (item 76).
 *
 * The LocalSend flow is two calls, and the split is the whole security
 * model: `prepare-upload` says WHAT is coming and from whom and gets a
 * yes or a no; `upload` carries the bytes and is only accepted with the
 * token that yes produced. So a stranger cannot push a file at a
 * machine — they can only ask, once, and be refused.
 *
 * WHO GETS A YES, and it is decided here rather than in a dialog:
 *   off       nobody. The announcement never left, and an address
 *             somebody guessed does not earn an exception.
 *   trusted   devices that have been paired. Anything else is refused
 *             without asking, because being asked by a stranger IS the
 *             thing "only trusted devices" was turned on to avoid.
 *   everyone  the person is asked, every time, with the sender's name
 *             and what they are sending on the dialog.
 *
 * Files land in ~/downloads/kavis-share and NEVER outside it: the name
 * the sender chose is stripped to its basename first. A file called
 * "../../.bashrc" is not a file name, it is an attempt.
 */

namespace Kavis.Share {

    public class Session : Object {
        public string id;
        public Device sender;
        public HashTable<string, string> tokens =
            new HashTable<string, string> (str_hash, str_equal);
        public HashTable<string, string> names =
            new HashTable<string, string> (str_hash, str_equal);
        public int64 total = 0;
    }

    /* One file on its way to disk. Held on the message while the body
     * streams, so the chunks have somewhere to go. */
    private class Landing : Object {
        public Session session;
        public string file_id;
        public string target;
        public FileOutputStream stream;
        public bool failed = false;
    }

    public class Receiver : Object {

        public signal void arrived (string path, string from);

        private Self me;
        private Discovery discovery;
        private Trust trust;
        private Soup.Server server;
        private HashTable<string, Session> sessions =
            new HashTable<string, Session> (str_hash, str_equal);

        public Receiver (Self me, Discovery discovery, Trust trust) {
            this.me = me;
            this.discovery = discovery;
            this.trust = trust;
        }

        public bool start () throws Error {
            server = new Soup.Server ("server-header", "kavis-share", null);
            server.add_handler (API + "/register", on_register);
            server.add_handler (API + "/prepare-upload", on_prepare);
            /* EARLY, before the body: the first version let libsoup
             * collect the whole upload in memory and wrote it out at
             * the end, so a two-gigabyte video needed two gigabytes of
             * RAM on a machine with a 380 MB idle target. An early
             * handler runs when the headers arrive, decides yes or no
             * on the token, and if yes turns off accumulation and
             * writes each chunk to the file as it comes. */
            server.add_early_handler (API + "/upload", on_upload);
            server.add_handler (API + "/info", on_info);
            server.listen_all (me.device.port, 0);
            return true;
        }

        private void reply_json (Soup.ServerMessage message, uint status,
                                 string body) {
            message.set_status (status, null);
            message.set_response ("application/json", Soup.MemoryUse.COPY,
                                  body.data);
        }

        private void on_info (Soup.Server server,
                              Soup.ServerMessage message, string path,
                              GLib.HashTable<string, string>? query) {
            reply_json (message, 200, Wire.registration (me.device));
        }

        /* A device introducing itself. We answer with ourselves, which
         * is what makes the two of them visible to each other after one
         * exchange rather than after the next multicast round. */
        private void on_register (Soup.Server server,
                                  Soup.ServerMessage message, string path,
                                  GLib.HashTable<string, string>? query) {
            var body = message.get_request_body ();
            var peer = Wire.parse_device ((string) body.data);
            if (peer == null) {
                reply_json (message, 400, "{}");
                return;
            }
            var remote = message.get_remote_address () as InetSocketAddress;
            if (remote != null) {
                peer.address = remote.get_address ().to_string ();
            }
            discovery.remember (peer);
            reply_json (message, 200, Wire.registration (me.device));
        }

        private void on_prepare (Soup.Server server,
                                 Soup.ServerMessage message, string path,
                                 GLib.HashTable<string, string>? query) {
            var body = message.get_request_body ();
            var parser = new Json.Parser ();
            try {
                parser.load_from_data ((string) body.data);
            } catch (Error e) {
                reply_json (message, 400, "{}");
                return;
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                reply_json (message, 400, "{}");
                return;
            }
            var object = root.get_object ();
            Device? sender = null;
            if (object.has_member ("info")) {
                var info = new Json.Generator ();
                info.set_root (object.get_member ("info"));
                sender = Wire.parse_device (info.to_data (null));
            }
            if (sender == null) {
                reply_json (message, 400, "{}");
                return;
            }
            var remote = message.get_remote_address () as InetSocketAddress;
            if (remote != null) {
                sender.address = remote.get_address ().to_string ();
            }

            if (!allowed (sender, object)) {
                /* 403 is LocalSend's "no". The sender shows it as
                 * declined, which is the truth. */
                reply_json (message, 403, "{}");
                return;
            }

            var session = new Session ();
            session.id = fresh_token ();
            session.sender = sender;

            var answer = new Json.Builder ();
            answer.begin_object ();
            answer.set_member_name ("sessionId");
            answer.add_string_value (session.id);
            answer.set_member_name ("files");
            answer.begin_object ();
            if (object.has_member ("files")) {
                var files = object.get_object_member ("files");
                foreach (unowned string id in files.get_members ()) {
                    var entry = files.get_object_member (id);
                    string token = fresh_token ();
                    session.tokens.insert (id, token);
                    session.names.insert (id,
                        entry.has_member ("fileName")
                        ? entry.get_string_member ("fileName") : id);
                    if (entry.has_member ("size")) {
                        session.total += entry.get_int_member ("size");
                    }
                    answer.set_member_name (id);
                    answer.add_string_value (token);
                }
            }
            answer.end_object ();
            answer.end_object ();
            sessions.insert (session.id, session);

            var generator = new Json.Generator ();
            generator.set_root (answer.get_root ());
            reply_json (message, 200, generator.to_data (null));
        }

        private void on_upload (Soup.Server server,
                                Soup.ServerMessage message, string path,
                                GLib.HashTable<string, string>? query) {
            if (query == null) {
                reply_json (message, 400, "{}");
                return;
            }
            string? session_id = query.lookup ("sessionId");
            string? file_id = query.lookup ("fileId");
            string? token = query.lookup ("token");
            if (session_id == null || file_id == null || token == null) {
                reply_json (message, 400, "{}");
                return;
            }
            var session = sessions.lookup (session_id);
            if (session == null
                || session.tokens.lookup (file_id) != token) {
                /* The token is the yes. Without it this is a stranger
                 * writing to the disk. */
                reply_json (message, 403, "{}");
                return;
            }
            /* One token, one file: a replay must not write again, so
             * it is spent the moment the upload starts, not when it
             * ends — a second request racing the first would otherwise
             * find it still there. */
            session.tokens.remove (file_id);

            string name = Path.get_basename (
                session.names.lookup (file_id) ?? file_id);
            if (name == "" || name == "." || name == "..") {
                name = file_id;
            }
            string dir = download_dir ();
            DirUtils.create_with_parents (dir, 0755);
            string target = unique_path (dir, name);

            var landing = new Landing ();
            landing.session = session;
            landing.file_id = file_id;
            landing.target = target;
            try {
                landing.stream = File.new_for_path (target).replace (
                    null, false, FileCreateFlags.PRIVATE);
            } catch (Error e) {
                warning ("kavis-share: could not open %s: %s", target,
                         e.message);
                reply_json (message, 500, "{}");
                return;
            }

            var body = message.get_request_body ();
            body.set_accumulate (false);
            message.got_chunk.connect ((chunk) => {
                if (landing.failed) {
                    return;
                }
                try {
                    landing.stream.write_all (chunk.get_data (), null);
                } catch (Error e) {
                    warning ("kavis-share: writing %s: %s", target,
                             e.message);
                    landing.failed = true;
                }
            });
            message.got_body.connect (() => {
                try {
                    landing.stream.close ();
                } catch (Error e) {
                    landing.failed = true;
                }
                if (landing.failed) {
                    FileUtils.remove (target);
                    reply_json (message, 500, "{}");
                    return;
                }
                arrived (target, session.sender.display ());
                reply_json (message, 200, "{}");
                /* The last file of a session takes the session with it;
                 * without this every transfer ever made stays in the
                 * table for the life of the daemon. */
                if (session.tokens.size () == 0) {
                    sessions.remove (session.id);
                }
            });
        }

        /* --- decisions -------------------------------------------- */

        private bool allowed (Device sender, Json.Object request) {
            switch (discovery.visibility ()) {
            case Visibility.OFF:
                return false;
            case Visibility.TRUSTED:
                return trust.is_trusted (sender.fingerprint);
            default:
                if (trust.is_trusted (sender.fingerprint)
                    && !always_ask ()) {
                    return true;
                }
                return Prompt.accept (sender, describe (request));
            }
        }

        private bool always_ask () {
            try {
                return Config.load ().get_boolean ("share", "confirm-every");
            } catch (Error e) {
                return false;
            }
        }

        private string describe (Json.Object request) {
            if (!request.has_member ("files")) {
                return "";
            }
            var files = request.get_object_member ("files");
            var members = files.get_members ();
            uint count = members.length ();
            if (count == 1) {
                var entry = files.get_object_member (members.nth_data (0));
                return entry.has_member ("fileName")
                    ? entry.get_string_member ("fileName") : "";
            }
            return ngettext ("%u file", "%u files", count).printf (count);
        }

        /* --- paths ------------------------------------------------- */

        private string download_dir () {
            string configured = "";
            try {
                configured = Config.load ().get_string ("share", "folder");
            } catch (Error e) { }
            if (configured.strip () != "") {
                return configured;
            }
            return Path.build_filename (Environment.get_home_dir (),
                                        "downloads", "kavis-share");
        }

        /* Never overwrite. A second "report.pdf" becomes "report (2).pdf",
         * the way a browser does it — silently replacing a file somebody
         * already had is the one outcome nobody wants. */
        private string unique_path (string dir, string name) {
            string candidate = Path.build_filename (dir, name);
            if (!FileUtils.test (candidate, FileTest.EXISTS)) {
                return candidate;
            }
            string stem = name;
            string extension = "";
            int dot = name.last_index_of (".");
            if (dot > 0) {
                stem = name.substring (0, dot);
                extension = name.substring (dot);
            }
            for (int n = 2; n < 1000; n++) {
                candidate = Path.build_filename (
                    dir, "%s (%d)%s".printf (stem, n, extension));
                if (!FileUtils.test (candidate, FileTest.EXISTS)) {
                    return candidate;
                }
            }
            return candidate;
        }

        private string fresh_token () {
            var text = new StringBuilder ();
            for (int i = 0; i < 16; i++) {
                text.append_printf ("%02x", Random.int_range (0, 256));
            }
            return text.str;
        }
    }
}
