/* Sending files to another device (item 76).
 *
 * The mirror of receive.vala: ask first with `prepare-upload`, and only
 * send bytes for the files that came back with a token. A device that
 * says no gets no bytes, and a device that says yes to two of three
 * files gets two.
 *
 * Files are sent ONE AT A TIME on purpose. Parallel uploads to a phone
 * over Wi-Fi are slower than sequential ones and make the progress
 * meaningless; and the failure mode of a half-parallel transfer is a
 * folder of files that are each partly there.
 */

namespace Kavis.Share {

    public class Sender : Object {

        public signal void progress (int done, int total, string name);
        public signal void finished (bool ok, string detail);

        private Self me;

        public Sender (Self me) {
            this.me = me;
        }

        public void send (Device peer, string[] paths) {
            string base_url = "http://%s:%u%s".printf (
                peer.address, peer.port, API);
            var session = new Soup.Session ();
            /* Long enough for a big file over a slow link; the ask
                itself is fast, but the same session carries both. */
            session.set_timeout (600);

            string request = prepare_body (paths);
            var message = new Soup.Message ("POST", base_url + "/prepare-upload");
            message.set_request_body_from_bytes (
                "application/json", new Bytes (request.data));
            Bytes answer;
            try {
                answer = session.send_and_read (message, null);
            } catch (Error e) {
                finished (false, e.message);
                return;
            }
            if (message.get_status () == 403) {
                finished (false, _("The other device declined"));
                return;
            }
            if (message.get_status () != 200) {
                finished (false, _("The other device answered %u")
                    .printf (message.get_status ()));
                return;
            }

            var parser = new Json.Parser ();
            try {
                parser.load_from_data ((string) answer.get_data ());
            } catch (Error e) {
                finished (false, e.message);
                return;
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                finished (false, _("The other device sent no session"));
                return;
            }
            var object = root.get_object ();
            if (!object.has_member ("sessionId")
                || !object.has_member ("files")) {
                finished (false, _("The other device sent no session"));
                return;
            }
            string session_id = object.get_string_member ("sessionId");
            var tokens = object.get_object_member ("files");

            int done = 0;
            int total = (int) tokens.get_members ().length ();
            foreach (unowned string id in tokens.get_members ()) {
                int index = int.parse (id);
                if (index < 0 || index >= paths.length) {
                    continue;
                }
                string path = paths[index];
                string token = tokens.get_string_member (id);
                progress (done, total, Path.get_basename (path));
                if (!upload (session, base_url, session_id, id, token,
                             path)) {
                    finished (false, _("Sending %s failed")
                        .printf (Path.get_basename (path)));
                    return;
                }
                done++;
            }
            progress (done, total, "");
            finished (true, "");
        }

        private bool upload (Soup.Session session, string base_url,
                             string session_id, string file_id,
                             string token, string path) {
            uint8[] data;
            try {
                FileUtils.get_data (path, out data);
            } catch (Error e) {
                return false;
            }
            var message = new Soup.Message (
                "POST",
                "%s/upload?sessionId=%s&fileId=%s&token=%s".printf (
                    base_url, Uri.escape_string (session_id),
                    Uri.escape_string (file_id),
                    Uri.escape_string (token)));
            message.set_request_body_from_bytes (
                "application/octet-stream", new Bytes (data));
            try {
                session.send_and_read (message, null);
            } catch (Error e) {
                return false;
            }
            return message.get_status () == 200;
        }

        /* The file id is the INDEX in the list we were given, so the
         * tokens that come back map straight onto the paths without a
         * second table to keep in step. */
        private string prepare_body (string[] paths) {
            var builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("info");
            builder.begin_object ();
            builder.set_member_name ("alias");
            builder.add_string_value (me.device.alias);
            builder.set_member_name ("version");
            builder.add_string_value (PROTOCOL_VERSION);
            builder.set_member_name ("deviceModel");
            builder.add_string_value (me.device.device_model);
            builder.set_member_name ("deviceType");
            builder.add_string_value (me.device.device_type);
            builder.set_member_name ("fingerprint");
            builder.add_string_value (me.device.fingerprint);
            builder.set_member_name ("port");
            builder.add_int_value (me.device.port);
            builder.set_member_name ("protocol");
            builder.add_string_value ("http");
            builder.set_member_name ("download");
            builder.add_boolean_value (false);
            builder.end_object ();

            builder.set_member_name ("files");
            builder.begin_object ();
            for (int i = 0; i < paths.length; i++) {
                string name = Path.get_basename (paths[i]);
                int64 size = 0;
                try {
                    var info = File.new_for_path (paths[i]).query_info (
                        FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                    size = info.get_size ();
                } catch (Error e) { }
                builder.set_member_name (i.to_string ());
                builder.begin_object ();
                builder.set_member_name ("id");
                builder.add_string_value (i.to_string ());
                builder.set_member_name ("fileName");
                builder.add_string_value (name);
                builder.set_member_name ("size");
                builder.add_int_value (size);
                builder.set_member_name ("fileType");
                builder.add_string_value (content_type (paths[i]));
                builder.end_object ();
            }
            builder.end_object ();
            builder.end_object ();

            var generator = new Json.Generator ();
            generator.set_root (builder.get_root ());
            return generator.to_data (null);
        }

        private string content_type (string path) {
            bool uncertain;
            string guess = ContentType.guess (path, null, out uncertain);
            return ContentType.get_mime_type (guess) ?? "application/octet-stream";
        }
    }
}
