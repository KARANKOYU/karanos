/* Network page (madde 52 — bu adımda YALNIZ okuma: Wi-Fi listesi ve
 * kayıtlı ağlar NetworkManager'dan gösterilir; bağlanma/hotspot
 * sonraki adımların işi). nmcli -t (terse) kullanılır — insan biçimi
 * sürümle oynar (ayarlar.md).
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget network (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        /* Wi-Fi anahtarı (gerçek ayar: nmcli radio). */
        string? radio_state = Run.capture ({ "nmcli", "-t", "radio",
                                             "wifi" });
        bool has_wifi = (radio_state != null);
        if (has_wifi) {
            var wifi = new Gtk.Switch ();
            wifi.active = radio_state.strip () == "enabled";
            wifi.notify["active"].connect (() => {
                Run.fire ({ "nmcli", "radio", "wifi",
                            wifi.active ? "on" : "off" });
            });
            body.pack_start (row (_("Wi-Fi"), null, wifi),
                             false, false, 0);

            body.pack_start (group (_("Available networks")),
                             false, false, 0);
            string? nets = Run.capture ({ "nmcli", "-t",
                "-f", "SSID,SIGNAL,ACTIVE", "dev", "wifi" });
            int shown = 0;
            if (nets != null) {
                foreach (unowned string line in nets.split ("\n")) {
                    string[] fields = line.split (":");
                    if (fields.length < 3 || fields[0] == "") {
                        continue;
                    }
                    string detail = "%s%%".printf (fields[1]);
                    if (fields[2] == "yes") {
                        detail += " — " + _("Connected");
                    }
                    var label = new Gtk.Label (detail);
                    label.get_style_context ().add_class ("dim-label");
                    body.pack_start (row (fields[0], null, label),
                                     false, false, 0);
                    if (++shown >= 10) {
                        break;
                    }
                }
            }
            if (shown == 0) {
                var none = new Gtk.Label (_("No networks found"));
                none.set_xalign (0);
                none.get_style_context ().add_class ("dim-label");
                body.pack_start (none, false, false, 0);
            }
        } else {
            var none = new Gtk.Label (_("No Wi-Fi hardware"));
            none.set_xalign (0);
            none.get_style_context ().add_class ("dim-label");
            body.pack_start (none, false, false, 0);
        }

        /* Kayıtlı bağlantılar. */
        body.pack_start (group (_("Saved networks")), false, false, 0);
        string? saved = Run.capture ({ "nmcli", "-t",
            "-f", "NAME,TYPE", "connection", "show" });
        int count = 0;
        if (saved != null) {
            foreach (unowned string line in saved.split ("\n")) {
                string[] fields = line.split (":");
                if (fields.length < 2 || fields[0] == "") {
                    continue;
                }
                var type_label = new Gtk.Label (
                    fields[1].replace ("802-11-wireless", "Wi-Fi")
                             .replace ("802-3-ethernet", "Ethernet"));
                type_label.get_style_context ().add_class ("dim-label");
                body.pack_start (row (fields[0], null, type_label),
                                 false, false, 0);
                count++;
            }
        }
        if (count == 0) {
            var none = new Gtk.Label (_("No saved networks"));
            none.set_xalign (0);
            none.get_style_context ().add_class ("dim-label");
            body.pack_start (none, false, false, 0);
        }

        return page;
    }
}
