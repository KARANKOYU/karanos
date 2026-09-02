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
        /* delta: +/− adım; 0 = sessize alma anahtarı. Sonuç OSD'ye. */
        [DBus (visible = false)]
        public signal void volume_changed (int percent, bool muted);
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

        /* Ses tuşları (madde 7 OSD): openbox XF86Audio* bunları
         * çağırır; panel sesi değiştirir ve OSD'yi gösterir. */
        public void volume_up () throws Error {
            adjust (5);
        }

        public void volume_down () throws Error {
            adjust (-5);
        }

        public void volume_mute () throws Error {
            Volume.toggle_mute ();
            emit_after_settle ();
        }

        private void adjust (int delta) {
            var state = Volume.read ();
            int target = (state.percent + delta).clamp (0, 100);
            Volume.set_percent (target);
            emit_after_settle ();
        }

        /* amixer asenkron; kısa bekleyip gerçek durumu oku. */
        private void emit_after_settle () {
            Timeout.add (120, () => {
                var state = Volume.read ();
                volume_changed (state.percent, state.muted);
                return Source.REMOVE;
            });
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
