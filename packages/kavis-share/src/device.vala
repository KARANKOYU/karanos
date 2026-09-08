/* Who we are, and who else is out there (item 76).
 *
 * THE PROTOCOL IS LOCALSEND'S, not one of ours. A sharing feature that
 * only talks to other Kavis machines is a sharing feature nobody can
 * use: the phone in the room is running Android, the laptop is running
 * Windows, and LocalSend already exists on both. Speaking its protocol
 * costs us nothing we would not have written anyway — a UDP
 * announcement and three HTTP endpoints — and it is the difference
 * between "send a file to my phone" working and not.
 *
 * WHAT IS DELIBERATELY NOT ANNOUNCED: the hostname and the user name.
 * A device shouting "karan@kavis" across a café network has told every
 * stranger there who is sitting in it. The default name is two random
 * words, and the person can change it.
 */

namespace Kavis.Share {

    /* LocalSend v2 constants. These are the protocol, not preferences:
     * changing any of them means no longer being able to talk to the
     * applications this exists to talk to. */
    public const string MULTICAST_GROUP = "224.0.0.167";
    public const uint16 PORT = 53317;
    public const string API = "/api/localsend/v2";
    public const string PROTOCOL_VERSION = "2.1";

    public class Device : Object {
        public string alias;          /* the name a person sees */
        public string fingerprint;    /* stable id, ours is random   */
        public string address = "";   /* filled in for peers only    */
        public uint16 port = PORT;
        public string device_model = "";
        public string device_type = "desktop";
        public bool download = false; /* supports the download flow  */
        public int64 seen = 0;        /* monotonic seconds, peers    */

        public string display () {
            return (device_model != "")
                ? "%s (%s)".printf (alias, device_model) : alias;
        }
    }

    /* Two words and a number: recognisable in a list, and it says
     * nothing about the person or the machine. The word lists are
     * deliberately short and dull — this is a label, not a joke. */
    namespace Naming {

        private const string[] FIRST = {
            "amber", "blue", "calm", "clear", "coral", "dawn", "deep",
            "east", "fair", "glass", "green", "high", "ivory", "jade",
            "kind", "late", "light", "mild", "north", "olive", "pale",
            "quiet", "rapid", "rose", "sand", "slate", "soft", "still",
            "teal", "warm", "west", "wide"
        };
        private const string[] SECOND = {
            "arch", "bay", "bell", "bridge", "cliff", "cloud", "coast",
            "creek", "dune", "field", "forest", "grove", "harbour",
            "hill", "lake", "meadow", "mount", "oak", "path", "peak",
            "pine", "plain", "reef", "ridge", "river", "shore", "spring",
            "stone", "trail", "valley", "wave", "well"
        };

        public string suggest () {
            return "Kavis-%s-%s".printf (
                FIRST[Random.int_range (0, FIRST.length)],
                SECOND[Random.int_range (0, SECOND.length)]);
        }
    }

    /* This machine's identity, remembered so peers recognise it again.
     *
     * The fingerprint is random rather than derived from anything real
     * (a MAC address, a machine id): it is an identifier for pairing,
     * and an identifier that leaks something about the hardware is one
     * more thing to regret announcing on a public network. */
    public class Self : Object {

        public Device device = new Device ();

        public Self () {
            var conf = Config.load ();
            string alias = "";
            string fingerprint = "";
            try {
                alias = conf.get_string ("share", "name");
            } catch (Error e) { }
            try {
                fingerprint = conf.get_string ("share", "fingerprint");
            } catch (Error e) { }

            bool changed = false;
            if (alias.strip () == "") {
                alias = Naming.suggest ();
                conf.set_string ("share", "name", alias);
                changed = true;
            }
            if (fingerprint.strip () == "") {
                fingerprint = random_fingerprint ();
                conf.set_string ("share", "fingerprint", fingerprint);
                changed = true;
            }
            if (changed) {
                Config.save (conf);
            }

            /* The TCP port is settable because two instances on one
             * machine cannot both own 53317, and two instances on one
             * machine is how this gets tested — and how a person with
             * two sessions open experiences it. The announcement
             * carries the port, so a peer always knows where to knock;
             * only the multicast socket has to stay on 53317, and that
             * one is shared rather than owned. */
            int port = PORT;
            try {
                port = conf.get_integer ("share", "port");
            } catch (Error e) { }
            if (port <= 0 || port > 65535) {
                port = PORT;
            }

            device.alias = alias;
            device.port = (uint16) port;
            device.fingerprint = fingerprint;
            device.device_model = "Kavis";
            device.device_type = "desktop";
        }

        private string random_fingerprint () {
            var text = new StringBuilder ();
            for (int i = 0; i < 32; i++) {
                text.append_printf ("%02x", Random.int_range (0, 256));
            }
            return text.str;
        }
    }
}
