/* org.kavis.Panel session-bus service (business logic).
 *
 * The panel is a single long-lived process; keyboard shortcuts live in
 * openbox (madde 6). This little interface is the bridge: a keybind
 * runs `gdbus call` and the running panel reacts — no second instance,
 * no sockets, no extra binary. Overview (madde 55) and the clipboard
 * popup (madde 7) arrive through here.
 */

namespace Kavis {

    [DBus (name = "org.kavis.Panel")]
    public class PanelService : Object {

        [DBus (visible = false)]
        public signal void overview_requested ();
        [DBus (visible = false)]
        public signal void clipboard_requested ();

        public void show_overview () throws Error {
            overview_requested ();
        }

        public void show_clipboard () throws Error {
            clipboard_requested ();
        }
    }

    namespace PanelBus {

        public PanelService? service = null;

        public void start () {
            service = new PanelService ();
            Bus.own_name (BusType.SESSION, "org.kavis.Panel",
                BusNameOwnerFlags.NONE,
                (connection) => {
                    try {
                        connection.register_object ("/org/kavis/Panel",
                                                    service);
                    } catch (IOError e) {
                        warning ("kavis-panel: panel servisi disari verilemedi: %s",
                                 e.message);
                    }
                },
                null,
                () => {
                    warning ("kavis-panel: org.kavis.Panel alinamadi — ikinci panel mi calisiyor?");
                });
        }
    }
}
