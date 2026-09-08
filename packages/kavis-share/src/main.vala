/* kavis-share — device to device, with no account and no server
 * (items 76/77, docs/kararlar.md 11).
 *
 *   kavis-share --daemon          announce, discover, receive
 *   kavis-share --list            what is nearby, one device per line
 *   kavis-share --send F... --to X   send to a fingerprint, name or address
 *
 * ONE PROCESS, not one per job: the daemon holds the socket on port
 * 53317 and the list of who is nearby, so `--list` and `--send` ask it
 * rather than starting a second discovery that would fight it for the
 * port. They ask over the session bus, which is also how the panel and
 * Nemo will ask later.
 */

namespace Kavis.Share {

    /* The client's view of the daemon. Vala builds a proxy from an
     * INTERFACE; the class below is what the daemon exports, and the
     * two are kept in step by having the same D-Bus name and the same
     * three methods — which is what D-Bus itself checks at the moment
     * of the call. */
    [DBus (name = "org.kavis.Share")]
    public interface ShareBus : Object {
        public abstract string list_devices () throws Error;
        public abstract string this_device () throws Error;
        public abstract async string send_files (string target,
                                                 string[] paths)
            throws Error;
    }

    [DBus (name = "org.kavis.Share")]
    public class Service : Object {

        [DBus (visible = false)]
        public Discovery discovery;
        [DBus (visible = false)]
        public Self me;
        [DBus (visible = false)]
        public Trust trust;

        /* "fingerprint\talias\taddress\ttrusted" per device. A table
         * rather than a structure because the callers are a shell
         * script, a panel and a settings page, and every one of them
         * wants a different two of the four columns. */
        public string list_devices () throws Error {
            var text = new StringBuilder ();
            foreach (unowned Device peer in discovery.known ()) {
                text.append_printf ("%s\t%s\t%s\t%s\n",
                    peer.fingerprint, peer.alias, peer.address,
                    trust.is_trusted (peer.fingerprint) ? "trusted" : "new");
            }
            return text.str;
        }

        public string this_device () throws Error {
            return "%s\t%s".printf (me.device.fingerprint, me.device.alias);
        }

        /* Returns "" on success, otherwise what went wrong — the caller
         * is a menu item, and a menu item that fails silently is worse
         * than one that says why. */
        /* ASYNC, and it matters: the first version ran a nested main
         * loop here until the transfer finished, which meant that for
         * the whole of a large send the daemon answered no announcement
         * and accepted no incoming file. A device that disappears from
         * everybody's list because it is busy sending is a device that
         * looks broken. The work runs in a thread; the reply is sent
         * from the main loop when it is done. */
        public async string send_files (string target, string[] paths)
            throws Error {
            Device? peer = find (target);
            if (peer == null) {
                return _("No device called “%s” is nearby").printf (target);
            }
            var sender = new Sender (me);
            string outcome = "";
            SourceFunc resume = send_files.callback;
            string[] copy = paths;
            new Thread<void*> ("kavis-share-send", () => {
                sender.finished.connect ((ok, detail) => {
                    outcome = ok ? "" : detail;
                });
                sender.send (peer, copy);
                Idle.add ((owned) resume);
                return null;
            });
            yield;
            return outcome;
        }

        [DBus (visible = false)]
        private Device? find (string target) {
            foreach (unowned Device peer in discovery.known ()) {
                if (peer.fingerprint == target || peer.alias == target
                    || peer.address == target) {
                    return peer;
                }
            }
            /* A bare address is allowed: a device on another subnet
             * never announced, and typing its address is the only way
             * to reach it. */
            if (target.contains (".")) {
                var direct = new Device ();
                direct.alias = target;
                direct.fingerprint = target;
                direct.address = target;
                return direct;
            }
            return null;
        }
    }
}

private int run_daemon () {
    var me = new Kavis.Share.Self ();
    var trust = new Kavis.Share.Trust ();
    var discovery = new Kavis.Share.Discovery (me);
    var receiver = new Kavis.Share.Receiver (me, discovery, trust);
    Kavis.Share.Prompt.use (trust);

    /* The file receiver is what makes the daemon a daemon; if its
     * ports cannot be taken there is a real conflict and exiting is
     * right. Discovery is best-effort and started after — it can never
     * be the reason the daemon is not there, which is the mistake the
     * first version made. */
    try {
        receiver.start ();
    } catch (Error e) {
        stderr.printf ("kavis-share: could not listen: %s\n", e.message);
        return 1;
    }
    discovery.start ();

    receiver.arrived.connect ((path, from) => {
        stdout.printf ("kavis-share: received %s from %s\n", path, from);
        stdout.flush ();
    });

    var service = new Kavis.Share.Service ();
    service.discovery = discovery;
    service.me = me;
    service.trust = trust;
    Bus.own_name (BusType.SESSION, "org.kavis.Share",
                  BusNameOwnerFlags.NONE,
                  (connection) => {
                      try {
                          connection.register_object (
                              "/org/kavis/Share", service);
                      } catch (IOError e) {
                          warning ("kavis-share: bus: %s", e.message);
                      }
                  }, null, null);

    string bus = Environment.get_variable ("DBUS_SESSION_BUS_ADDRESS")
        ?? ("(default $XDG_RUNTIME_DIR/bus: "
            + (Environment.get_variable ("XDG_RUNTIME_DIR") ?? "unset")
            + "/bus)");
    stdout.printf ("kavis-share: %s listening on %u, session bus %s\n",
                   me.device.alias, me.device.port, bus);
    stdout.flush ();
    new MainLoop ().run ();
    return 0;
}

private Kavis.Share.ShareBus? bus_service () {
    /* Wait a moment for the name rather than failing on the instant it
     * is not yet there: Bus.own_name in the daemon is asynchronous, so
     * a client that races a just-started daemon would see nothing. Two
     * seconds is far more than acquisition takes and is invisible when
     * the daemon has been up for a while, which is the usual case. */
    for (int attempt = 0; attempt < 10; attempt++) {
        try {
            var proxy = Bus.get_proxy_sync<Kavis.Share.ShareBus> (
                BusType.SESSION, "org.kavis.Share", "/org/kavis/Share",
                DBusProxyFlags.DO_NOT_AUTO_START);
            /* get_proxy_sync does not itself prove the name is owned;
             * a call does. this_device is cheap and read-only. */
            proxy.this_device ();
            return proxy;
        } catch (Error e) {
            if (attempt == 9) {
                stderr.printf (
                    "kavis-share: the daemon did not answer (%s)\n",
                    e.message);
                return null;
            }
            Thread.usleep (200000);
        }
    }
    return null;
}

int main (string[] args) {
    Kavis.AppInit.init ();
    /* init_check, not init: a share daemon with no display is a
     * perfectly reasonable thing (a machine that only receives, a test
     * harness), and dying at startup because nobody is logged in is
     * not. What a missing display costs is the ability to ASK, and
     * Prompt says no rather than guessing when it cannot. */
    Kavis.Share.Prompt.display_available = Gtk.init_check (ref args);

    string mode = (args.length > 1) ? args[1] : "";
    switch (mode) {
    case "--daemon":
        return run_daemon ();

    case "--list":
        var service = bus_service ();
        if (service == null) {
            return 1;
        }
        try {
            stdout.printf ("%s", service.list_devices ());
        } catch (Error e) {
            stderr.printf ("kavis-share: %s\n", e.message);
            return 1;
        }
        return 0;

    case "--send":
        string target = "";
        string[] paths = {};
        for (int i = 2; i < args.length; i++) {
            if (args[i] == "--to" && i + 1 < args.length) {
                target = args[++i];
            } else {
                paths += args[i];
            }
        }
        if (target == "" || paths.length == 0) {
            stderr.printf (
                _("usage: kavis-share --send <file>... --to <device>\n"));
            return 2;
        }
        var sending = bus_service ();
        if (sending == null) {
            return 1;
        }
        /* The daemon's method is asynchronous so the daemon stays
         * alive during a transfer; this end is a command line and has
         * nothing else to do, so it simply waits for the answer. */
        string problem = "";
        var waiting = new MainLoop ();
        sending.send_files.begin (target, paths, (obj, res) => {
            try {
                problem = sending.send_files.end (res);
            } catch (Error e) {
                problem = e.message;
            }
            waiting.quit ();
        });
        waiting.run ();
        if (problem != "") {
            stderr.printf ("kavis-share: %s\n", problem);
            return 1;
        }
        return 0;

    default:
        stderr.printf (
            _("usage: kavis-share [--daemon|--list|--send <file>... --to <device>]\n"));
        return 2;
    }
}
