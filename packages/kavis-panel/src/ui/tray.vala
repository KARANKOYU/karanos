/* Kavis tray tools (UI layer) — madde 3 düzeltmesi.
 *
 * A small icon strip left of the indicators, holding KAVIS' OWN tools
 * only (third-party XEmbed/SNI trays are item 37's separate task).
 * Contract for every tool icon:
 *   left click  → the place the tool points at (Wi-Fi → the quick
 *                 settings Wi-Fi subpage, USB → the device list)
 *   right click → that tool's quick-action menu.
 * The volume indicator (ui/indicators.vala) follows the same contract.
 */

namespace Kavis.Ui {

    /* Removable-drive tool: visible only while a stick is attached.
     * Left click lists devices, right click ejects directly. */
    public class UsbIndicator : Gtk.Button {

        private UsbPopup popup;

        public UsbIndicator () {
            set_relief (Gtk.ReliefStyle.NONE);
            get_style_context ().add_class ("indicator-button");
            add (new Gtk.Image.from_icon_name (
                "drive-removable-media-symbolic", Gtk.IconSize.BUTTON));
            set_tooltip_text (_("Safely remove"));

            popup = new UsbPopup ();
            clicked.connect (() => popup.toggle_at (this));
            button_press_event.connect ((event) => {
                if (event.button == 3) {
                    show_eject_menu (event);
                    return true;
                }
                return false;
            });

            set_no_show_all (true);
            refresh ();
            /* Takıp çıkarma anlık yakalanmak zorunda değil; 5 sn'lik
             * yoklama udev izleme bağımlılığından ucuz. */
            Timeout.add_seconds (5, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private int known_count = -1;

        private void refresh () {
            /* Tak/çıkar sesi (6b): udev olayını ayrıca dinlemek yerine
             * zaten dönen 5 sn'lik yoklamanın gördüğü değişim yeter. */
            int count = Usb.devices ().length;
            if (known_count >= 0 && count != known_count) {
                Sounds.play (count > known_count
                    ? "device-added" : "device-removed");
            }
            known_count = count;
            if (count > 0) {
                /* show_all, no_show_all işaretli widget'ın KENDİSİNDE
                 * de işlemez — bayrağı önce kaldır. */
                set_no_show_all (false);
                show_all ();
            } else {
                if (popup.get_visible ()) {
                    popup.dismiss ();
                }
                set_no_show_all (true);
                hide ();
            }
        }

        private void show_eject_menu (Gdk.EventButton event) {
            var menu = new Gtk.Menu ();
            foreach (unowned Usb.Device device in Usb.devices ()) {
                var item = new Gtk.MenuItem.with_label (
                    _("Safely remove %s").printf (device.name));
                string node = device.node;
                item.activate.connect (() => {
                    UsbPopup.eject_in_background (node);
                });
                menu.append (item);
            }
            /* Sızıntı önlemi: kapanınca menü yok edilir (aktivasyon
             * deactivate'ten SONRA koştuğu için Idle ile). */
            menu.deactivate.connect (() => {
                Idle.add (() => {
                    menu.destroy ();
                    return Source.REMOVE;
                });
            });
            menu.show_all ();
            menu.popup_at_pointer (event);
        }
    }

    /* Device list popup: one row per stick, an eject button at the
     * right of each. */
    public class UsbPopup : PanelPopup {

        private Gtk.Box list;

        public UsbPopup () {
            var title = new Gtk.Label (_("Safely remove"));
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            title.set_margin_start (4);
            content.pack_start (title, false, false, 0);
            content.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 4);
            list = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            content.pack_start (list, false, false, 0);
        }

        /* Eject flushes buffers (can block seconds) — worker thread,
         * result comes back as a notification. */
        public static void eject_in_background (string node) {
            new Thread<void*> ("kavis-eject", () => {
                bool ok = Usb.eject_sync (node);
                Idle.add (() => {
                    if (Notifications.server != null) {
                        var hints = new HashTable<string, Variant> (
                            str_hash, str_equal);
                        try {
                            Notifications.server.notify ("Kavis", 0,
                                "drive-removable-media-symbolic",
                                _(ok ? N_("You can now remove the device")
                                                : N_("Could not remove the device — files may still be in use")),
                                "", {}, hints, 5000);
                        } catch (Error e) { }
                    }
                    return Source.REMOVE;
                });
                return null;
            });
        }

        protected override void refresh_content () {
            foreach (var child in list.get_children ()) {
                list.remove (child);
            }
            foreach (unowned Usb.Device device in Usb.devices ()) {
                var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                var label = new Gtk.Label (device.name);
                label.set_xalign (0);
                label.set_ellipsize (Pango.EllipsizeMode.END);
                row.pack_start (label, true, true, 0);
                var eject = new Gtk.Button.from_icon_name (
                    "media-eject-symbolic", Gtk.IconSize.BUTTON);
                eject.set_relief (Gtk.ReliefStyle.NONE);
                eject.set_tooltip_text (_("Safely remove"));
                string node = device.node;
                eject.clicked.connect (() => {
                    dismiss ();
                    eject_in_background (node);
                });
                row.pack_end (eject, false, false, 0);
                list.pack_start (row, false, false, 0);
            }
            list.show_all ();
        }
    }

}
