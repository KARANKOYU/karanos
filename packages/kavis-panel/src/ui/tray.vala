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
        private GenericSet<string> seen_parts =
            new GenericSet<string> (str_hash, str_equal);

        private void refresh () {
            /* Tak/çıkar sesi (6b): udev olayını ayrıca dinlemek yerine
             * zaten dönen 5 sn'lik yoklamanın gördüğü değişim yeter. */
            int count = Usb.devices ().length;
            if (known_count >= 0 && count != known_count) {
                Sounds.play (count > known_count
                    ? "device-added" : "device-removed");
            }
            known_count = count;
            automount_new ();
            update_writing_state ();
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

        /* Gerçek yazma göstergesi (madde 63): çekirdek hâlâ diske
         * yazıyorken simge turuncuya döner ve araç ipucu uyarır —
         * kopyalama diyaloğu kapansa bile buffer boşalana dek. */
        private void update_writing_state () {
            bool writing = false;
            foreach (unowned Usb.Device device in Usb.devices ()) {
                if (Usb.writing (device.node)) {
                    writing = true;
                    break;
                }
            }
            var style = get_style_context ();
            if (writing) {
                style.add_class ("usb-writing");
                set_tooltip_text (
                    _("Still writing to the drive — do not remove"));
            } else if (style.has_class ("usb-writing")) {
                style.remove_class ("usb-writing");
                set_tooltip_text (_("Safely remove"));
            }
        }

        /* Otomatik bağlama + bildirim (madde 42): yeni görülen ve
         * bağlı olmayan bölümler udisks'le bağlanır, ilkinin yolu
         * tıklanınca açılan bir bildirim düşer. Kullanıcının elle
         * ayırdığı bölüm "görülmüş" kaldığı için yeniden BAĞLANMAZ;
         * çıkarılan çubuk kümeden düşer ki tekrar takılınca bağlansın. */
        private void automount_new () {
            var current = new GenericSet<string> (str_hash, str_equal);
            string[] todo = {};
            foreach (unowned Usb.Partition part in Usb.partitions ()) {
                current.add (part.node);
                if (!seen_parts.contains (part.node)
                    && part.mountpoint == "") {
                    todo += part.node;
                }
            }
            seen_parts = current;
            if (todo.length == 0) {
                return;
            }
            new Thread<void*> ("kavis-automount", () => {
                bool want_sync =
                    PanelConfig.get_default ().usb_sync;
                string? first = null;
                string? failed = null;
                foreach (string node in todo) {
                    string? mountpoint = Usb.mount_sync (node,
                                                         want_sync);
                    if (mountpoint != null && first == null) {
                        first = mountpoint;
                    }
                    if (mountpoint == null && failed == null) {
                        failed = node;
                    }
                }
                if (first != null) {
                    string target = first;
                    Idle.add (() => {
                        announce_mount (target);
                        return Source.REMOVE;
                    });
                }
                if (failed != null) {
                    string broken = failed;
                    Idle.add (() => {
                        offer_repair (broken);
                        return Source.REMOVE;
                    });
                }
                return null;
            });
        }

        /* Bağlanamayan bölüm (madde 64): bildirimde "Onarmayı dene"
         * düğmesi — tık kavis-tools repair-drive'ı açar (zorunlu
         * uyarı ve onay orada). */
        private void offer_repair (string node) {
            if (Notifications.server == null) {
                return;
            }
            var hints = new HashTable<string, Variant> (
                str_hash, str_equal);
            uint32 id = 0;
            try {
                id = Notifications.server.notify ("Kavis", 0,
                    "drive-removable-media-symbolic",
                    _("The drive could not be mounted"),
                    _("%s may have a damaged file system. Try to repair it?")
                        .printf (node),
                    { "repair", _("Try to repair") }, hints, 15000);
            } catch (Error e) {
                return;
            }
            ulong handler = 0;
            handler = Notifications.server.action_invoked.connect (
                (invoked_id, key) => {
                    if (invoked_id != id || key != "repair") {
                        return;
                    }
                    if (handler != 0) {
                        SignalHandler.disconnect (
                            Notifications.server, handler);
                        handler = 0;
                    }
                    try {
                        Process.spawn_async (null, {
                            "kavis-tools", "repair-drive", node
                        }, null, SpawnFlags.SEARCH_PATH, null, null);
                    } catch (Error e) {
                        warning ("kavis-panel: onarim acilamadi: %s",
                                 e.message);
                    }
                });
            /* Bildirim kaybolduktan sonra bağ askıda kalmasın. */
            Timeout.add_seconds (120, () => {
                if (handler != 0) {
                    SignalHandler.disconnect (
                        Notifications.server, handler);
                    handler = 0;
                }
                return Source.REMOVE;
            });
        }

        private void announce_mount (string mountpoint) {
            if (Notifications.server == null) {
                return;
            }
            var hints = new HashTable<string, Variant> (
                str_hash, str_equal);
            /* Tık → dosya yöneticisinde aç (toast x-kavis-path yolu). */
            hints.insert ("x-kavis-path",
                          new Variant.string (mountpoint));
            try {
                Notifications.server.notify ("Kavis", 0,
                    "drive-removable-media-symbolic",
                    _("Removable drive connected"),
                    mountpoint, {}, hints, 6000);
            } catch (Error e) { }
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

            /* Madde 63 "güvenli mod": sync bağlama. Varsayılan KAPALI;
             * ne yaptığı düğmenin altında tek cümleyle yazıyor. */
            content.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 4);
            var sync_toggle = new Gtk.CheckButton.with_label (
                _("Safe mode: write immediately"));
            sync_toggle.active =
                PanelConfig.get_default ().usb_sync;
            sync_toggle.toggled.connect (() => {
                var config = PanelConfig.get_default ();
                config.usb_sync = sync_toggle.active;
                config.save ();
            });
            content.pack_start (sync_toggle, false, false, 0);
            var sync_note = new Gtk.Label (
                _("Slower copying; applies when a drive is next plugged in"));
            sync_note.get_style_context ().add_class ("dim");
            sync_note.set_xalign (0);
            sync_note.set_margin_start (26);
            sync_note.set_line_wrap (true);
            content.pack_start (sync_note, false, false, 0);
        }

        /* Eject flushes buffers (can block seconds) — worker thread,
         * result comes back as a notification. */
        public static void eject_in_background (string node) {
            new Thread<void*> ("kavis-eject", () => {
                /* Meşgul süreçleri AYIRMADAN önce topla — başarısız
                 * ayırmadan sonra fuser aynı sonucu verir, başarılı
                 * ayırmada zaten gerek kalmaz (madde 63). */
                string[] users = Usb.busy_processes (node);
                bool ok = Usb.eject_sync (node);
                Idle.add (() => {
                    if (Notifications.server != null) {
                        var hints = new HashTable<string, Variant> (
                            str_hash, str_equal);
                        string body = "";
                        if (!ok && users.length > 0) {
                            body = _("In use by: %s").printf (
                                string.joinv (", ", users));
                        }
                        try {
                            Notifications.server.notify ("Kavis", 0,
                                "drive-removable-media-symbolic",
                                _(ok ? N_("You can now remove the device")
                                                : N_("Could not remove the device — files may still be in use")),
                                body, {}, hints, 5000);
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
                if (Usb.writing (device.node)) {
                    var busy = new Gtk.Label (
                        _("Still writing — do not remove"));
                    busy.get_style_context ().add_class ("dim");
                    row.pack_start (busy, false, false, 0);
                }
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
