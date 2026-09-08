/* Finding the other devices, and letting them find us (item 76).
 *
 * LocalSend discovers in two ways at once, and both are needed because
 * each fails where the other works:
 *
 *   * a UDP announcement to a multicast group, which reaches everything
 *     on the segment without anybody knowing an address — but which
 *     some networks drop, and which a device that joined after the
 *     announcement never hears;
 *   * an HTTP POST to /register, which a device sends directly to
 *     somebody it has just heard from, so the two learn about each
 *     other in one exchange rather than waiting for the next round.
 *
 * The rule that makes it work: when you hear an announcement from a
 * device you did not know, you answer it — over HTTP, directly. That is
 * why a device that has just been switched on appears in the list of a
 * device that has been running for an hour.
 *
 * VISIBILITY is enforced here rather than at the edges. "Off" does not
 * mean "announce and refuse": it means no announcement leaves this
 * machine at all, because an announcement is the thing that tells a
 * stranger a device is here.
 */

namespace Kavis.Share {

    public enum Visibility {
        OFF,        /* nothing is announced; sending still works     */
        TRUSTED,    /* announced, but only paired devices may send   */
        EVERYONE;   /* any LocalSend device may ask                  */

        public static Visibility from_string (string value) {
            switch (value) {
            case "off":      return OFF;
            case "everyone": return EVERYONE;
            default:         return TRUSTED;
            }
        }

        public string to_id () {
            switch (this) {
            case OFF:      return "off";
            case EVERYONE: return "everyone";
            default:       return "trusted";
            }
        }
    }

    public class Discovery : Object {

        /* A peer that has not been heard from in this long is gone.
         * LocalSend clients announce every few seconds; a minute is
         * long enough to survive a missed round and short enough that
         * a laptop that left the room stops being offered. */
        private const int64 PEER_TIMEOUT_S = 60;
        private const uint ANNOUNCE_INTERVAL_S = 5;

        public signal void peers_changed ();

        private Self me;
        private Socket? socket = null;
        private HashTable<string, Device> peers =
            new HashTable<string, Device> (str_hash, str_equal);

        public Discovery (Self me) {
            this.me = me;
        }

        public Visibility visibility () {
            string value = "trusted";
            try {
                value = Config.load ().get_string ("share", "visibility");
            } catch (Error e) { }
            return Visibility.from_string (value);
        }

        public Device[] known () {
            Device[] list = {};
            int64 now = get_monotonic_time () / 1000000;
            foreach (unowned Device peer in peers.get_values ()) {
                if (now - peer.seen <= PEER_TIMEOUT_S) {
                    list += peer;
                }
            }
            return list;
        }

        public Device? by_fingerprint (string fingerprint) {
            return peers.lookup (fingerprint);
        }

        /* --- listening -------------------------------------------- */

        public bool start () throws Error {
            socket = new Socket (SocketFamily.IPV4, SocketType.DATAGRAM,
                                 SocketProtocol.UDP);
            socket.set_blocking (false);
            /* Several LocalSend clients on one machine is the normal
             * case while testing, and the normal case for a person with
             * two accounts logged in. Without reuse the second one
             * cannot listen at all. */
            var address = new InetSocketAddress (
                new InetAddress.any (SocketFamily.IPV4), PORT);
            socket.bind (address, true);
            socket.join_multicast_group (
                new InetAddress.from_string (MULTICAST_GROUP), false, null);

            var source = socket.create_source (IOCondition.IN);
            source.set_callback ((s, condition) => {
                receive ();
                return Source.CONTINUE;
            });
            source.attach (MainContext.default ());

            announce ();
            Timeout.add_seconds (ANNOUNCE_INTERVAL_S, () => {
                announce ();
                return Source.CONTINUE;
            });
            return true;
        }

        private void receive () {
            uint8 buffer[8192];
            SocketAddress? from;
            ssize_t length;
            try {
                length = socket.receive_from (out from, buffer);
            } catch (Error e) {
                return;
            }
            if (length <= 0) {
                return;
            }
            string text = (string) buffer[0:length];
            var announced = Wire.parse_device (text);
            if (announced == null
                || announced.fingerprint == me.device.fingerprint) {
                return;   /* our own announcement, bouncing back */
            }
            var inet = from as InetSocketAddress;
            if (inet != null) {
                announced.address = inet.get_address ().to_string ();
            }
            bool is_new = (peers.lookup (announced.fingerprint) == null);
            remember (announced);

            /* The answer that makes discovery symmetric: a device that
             * has just started hears nothing from us until our next
             * announcement, so we tell it directly. Only for the ones
             * we did not already know, or two machines answer each
             * other forever. */
            if (is_new && visibility () != Visibility.OFF) {
                Wire.register_with (announced, me.device);
            }
        }

        public void remember (Device peer) {
            peer.seen = get_monotonic_time () / 1000000;
            var existing = peers.lookup (peer.fingerprint);
            peers.insert (peer.fingerprint, peer);
            if (existing == null) {
                peers_changed ();
            }
        }

        /* --- announcing ------------------------------------------- */

        private void announce () {
            if (socket == null || visibility () == Visibility.OFF) {
                return;
            }
            string body = Wire.announcement (me.device);
            try {
                var target = new InetSocketAddress (
                    new InetAddress.from_string (MULTICAST_GROUP), PORT);
                socket.send_to (target, body.data);
            } catch (Error e) {
                /* A network with no multicast route is normal — a
                 * cabled machine with the cable out, a VM on a NAT
                 * that drops it. Registration by address still works,
                 * so this is not worth a line in the log every five
                 * seconds. */
            }
        }
    }
}
