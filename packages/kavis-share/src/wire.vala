/* The JSON on the wire (item 76).
 *
 * Every field name here is LocalSend's. They are not ours to tidy up:
 * "deviceModel", "protocolVersion", the lot. The moment one of them is
 * spelled the way we would have spelled it, the phone in the room stops
 * seeing this machine, and the whole point was the phone in the room.
 *
 * Parsing is strict about the ONE field that matters — the fingerprint,
 * which is the identity everything else hangs off — and forgiving about
 * the rest, because the other implementations disagree in small ways
 * and a share that refuses to talk to a device over a missing optional
 * field helps nobody.
 */

namespace Kavis.Share.Wire {

    public string announcement (Device me) {
        return describe (me, true);
    }

    /* The same object without the announce flag — what goes in the body
     * of a /register call and comes back as its answer. */
    public string registration (Device me) {
        return describe (me, false);
    }

    private string describe (Device me, bool announce) {
        var builder = new Json.Builder ();
        builder.begin_object ();
        builder.set_member_name ("alias");
        builder.add_string_value (me.alias);
        builder.set_member_name ("version");
        builder.add_string_value (PROTOCOL_VERSION);
        builder.set_member_name ("deviceModel");
        builder.add_string_value (me.device_model);
        builder.set_member_name ("deviceType");
        builder.add_string_value (me.device_type);
        builder.set_member_name ("fingerprint");
        builder.add_string_value (me.fingerprint);
        builder.set_member_name ("port");
        builder.add_int_value (me.port);
        builder.set_member_name ("protocol");
        builder.add_string_value ("http");
        builder.set_member_name ("download");
        builder.add_boolean_value (false);
        /* "announce": true says this is a shout, not an answer. A peer
         * that sees it knows to reply directly; a peer that sees it
         * false knows not to, which is what stops two machines
         * answering each other in a loop. */
        builder.set_member_name ("announce");
        builder.add_boolean_value (announce);
        builder.end_object ();

        var generator = new Json.Generator ();
        generator.set_root (builder.get_root ());
        return generator.to_data (null);
    }

    public Device? parse_device (string json) {
        var parser = new Json.Parser ();
        try {
            parser.load_from_data (json);
        } catch (Error e) {
            return null;
        }
        var root = parser.get_root ();
        if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
            return null;
        }
        var object = root.get_object ();
        if (!object.has_member ("fingerprint")) {
            return null;   /* no identity: nothing to remember it by */
        }
        var device = new Device ();
        device.fingerprint = object.get_string_member ("fingerprint");
        device.alias = object.has_member ("alias")
            ? object.get_string_member ("alias") : device.fingerprint;
        device.device_model = object.has_member ("deviceModel")
            ? object.get_string_member ("deviceModel") : "";
        device.device_type = object.has_member ("deviceType")
            ? object.get_string_member ("deviceType") : "desktop";
        if (object.has_member ("port")) {
            device.port = (uint16) object.get_int_member ("port");
        }
        return device;
    }

    /* Tell a device we exist, directly. Fire and forget: the answer is
     * that device's own registration, and if it never arrives we will
     * hear its next announcement anyway. */
    public void register_with (Device peer, Device me) {
        if (peer.address == "") {
            return;
        }
        var session = new Soup.Session ();
        session.set_timeout (4);
        var message = new Soup.Message (
            "POST", "http://%s:%u%s/register".printf (
                peer.address, peer.port, API));
        var body = new Bytes (registration (me).data);
        message.set_request_body_from_bytes ("application/json", body);
        session.send_async.begin (message, Priority.DEFAULT, null,
                                  (obj, res) => {
            try {
                session.send_async.end (res);
            } catch (Error e) {
                /* The device went away between hearing it and
                 * answering it. It will announce again if it comes
                 * back. */
            }
        });
    }
}
