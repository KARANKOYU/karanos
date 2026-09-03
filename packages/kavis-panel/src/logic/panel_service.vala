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
        /* C4: Win / Win+R — baslat menusu (search=true: arama odakli). */
        public signal void start_menu_requested (bool search);
        [DBus (visible = false)]
        public signal void clipboard_requested ();
        /* Win+sayı (sonraki-isler 2): soldan N. görev çubuğu yuvası. */
        [DBus (visible = false)]
        public signal void slot_requested (int number, bool new_window);
        /* Win+Z (sonraki-isler 4): snap yerleşim menüsü. */
        [DBus (visible = false)]
        public signal void snap_menu_requested ();
        /* Win+. (sonraki-isler 5): birleşik panel, istenen sekmede. */
        [DBus (visible = false)]
        public signal void picker_requested (string page);

        public void show_overview () throws Error {
            overview_requested ();
        }

        public void show_start_menu (bool search) throws Error {
            start_menu_requested (search);
        }

        public void activate_slot (int number, bool new_window)
            throws Error {
            slot_requested (number, new_window);
        }

        public void show_snap_menu () throws Error {
            snap_menu_requested ();
        }

        public void show_picker (string page) throws Error {
            picker_requested (page);
        }

        public void show_clipboard () throws Error {
            clipboard_requested ();
        }

        /* Ses tuşları kavis-osd'ye taşındı (sonraki-isler 6a) —
         * OSD paneli değil ayrı süreci. */
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
