/* Network page (item 52).
 *
 * Everything goes through nmcli in terse mode (-t): the human-readable
 * output changes between NetworkManager versions, the terse one is a
 * stable, colon-separated contract (ayarlar.md survey). NetworkManager
 * is on the ISO already and is what the panel's Wi-Fi indicator uses,
 * so this page is a second face on the same state, never a second
 * writer of it.
 *
 * The page rebuilds itself after every action rather than trying to
 * patch its own widgets: a connect can change the Wi-Fi list, the saved
 * connections and the address of an interface at once, and re-reading
 * takes a few milliseconds.
 *
 * The one thing not done through nmcli is DNS privacy, which is
 * resolved's business and needs root — see the set-dns helper.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget network (string title) {
        var page = new NetworkPage ();
        return page.build (title);
    }

    private class NetworkPage : Object {

        private Gtk.Box? body = null;
        private Gtk.Widget? page = null;
        private string title = "";

        public Gtk.Widget build (string title) {
            this.title = title;
            var outer = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            page = outer;
            outer.set_data<Object> ("kavis-network-page", this);
            fill ();
            return outer;
        }

        /* Rebuild the whole page from the current state. */
        /* The box of the sub-section being filled right now. Each
         * section method opens one and packs into it; the page is a
         * list of blocks instead of one long run of cards (item 74). */
        private Gtk.Box block;

        private void refresh () {
            foreach (var child in ((Gtk.Box) page).get_children ()) {
                ((Gtk.Box) page).remove (child);
            }
            fill ();
            ((Gtk.Box) page).show_all ();
        }

        private void fill () {
            Gtk.Box b;
            var inner = frame (title, out b);
            body = b;
            ((Gtk.Box) page).pack_start (inner, true, true, 0);

            if (Environment.find_program_in_path ("nmcli") == null) {
                body.pack_start (row (_("Network"),
                    _("NetworkManager is not installed"), null),
                    false, false, 0);
                return;
            }
            wifi_section ();
            wired_section ();
            vpn_section ();
            dns_section ();
        }

        /* --- Wi-Fi ---------------------------------------------------- */

        private void wifi_section () {
            string? radio = Run.capture ({ "nmcli", "-t", "radio", "wifi" });
            if (radio == null || radio.strip () == "missing") {
                return;   /* no Wi-Fi hardware: the section would be a lie */
            }
            bool on = radio.strip () == "enabled";
            block = subsection (body, "wifi",
                                Catalog.sub_title ("network", "wifi"));

            var wifi = new Gtk.Switch ();
            wifi.active = on;
            wifi.notify["active"].connect (() => {
                Run.fire ({ "nmcli", "radio", "wifi",
                            wifi.active ? "on" : "off" });
                /* The radio takes a moment to come up; rescanning
                 * immediately would show an empty list. */
                Timeout.add_seconds (2, () => { refresh (); return Source.REMOVE; });
            });
            block.pack_start (row (_("Wi-Fi"), null, wifi), false, false, 0);
            if (!on) {
                return;
            }

            /* SSID:SIGNAL:SECURITY:ACTIVE — the terse format escapes a
             * colon inside a field as "\:", so the split has to be
             * undone for the name. */
            string? nets = Run.capture ({ "nmcli", "-t", "-f",
                "SSID,SIGNAL,SECURITY,ACTIVE", "dev", "wifi", "list" });
            var seen = new GenericSet<string> (str_hash, str_equal);
            int shown = 0;
            if (nets != null) {
                foreach (unowned string line in nets.split ("\n")) {
                    string[] f = split_terse (line);
                    if (f.length < 4 || f[0] == "") {
                        continue;
                    }
                    /* One row per network, not per access point. */
                    if (seen.contains (f[0])) {
                        continue;
                    }
                    seen.add (f[0]);
                    block.pack_start (wifi_row (f[0], f[1], f[2],
                                               f[3] == "yes"),
                                     false, false, 0);
                    if (++shown >= 12) {
                        break;
                    }
                }
            }
            if (shown == 0) {
                block.pack_start (row (_("Available networks"),
                    _("No networks found"), null), false, false, 0);
            }

            var rescan = new Gtk.Button.with_label (_("Scan again"));
            rescan.clicked.connect (() => {
                Run.fire ({ "nmcli", "dev", "wifi", "rescan" });
                Timeout.add_seconds (3, () => { refresh (); return Source.REMOVE; });
            });
            var hotspot = new Gtk.Button.with_label (_("Hotspot…"));
            hotspot.clicked.connect (() => hotspot_dialog ());
            var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            buttons.pack_start (rescan, false, false, 0);
            buttons.pack_start (hotspot, false, false, 0);
            block.pack_start (row (_("Wi-Fi actions"),
                _("Share this machine's connection over Wi-Fi"),
                buttons), false, false, 0);
        }

        private Gtk.Widget wifi_row (string ssid, string signal_strength,
                                     string security, bool active) {
            var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var strength = new Gtk.Label ("%s%%".printf (signal_strength));
            strength.get_style_context ().add_class ("dim-label");
            controls.pack_start (strength, false, false, 0);
            if (active) {
                var disconnect = new Gtk.Button.with_label (_("Disconnect"));
                disconnect.clicked.connect (() => {
                    Run.fire ({ "nmcli", "connection", "down", "id", ssid });
                    Timeout.add_seconds (1, () => { refresh (); return Source.REMOVE; });
                });
                controls.pack_start (disconnect, false, false, 0);
            } else {
                var connect = new Gtk.Button.with_label (_("Connect"));
                connect.clicked.connect (() => connect_wifi (ssid, security));
                controls.pack_start (connect, false, false, 0);
            }
            if (is_saved (ssid)) {
                var forget = new Gtk.Button.with_label (_("Forget"));
                forget.clicked.connect (() => {
                    Run.fire ({ "nmcli", "connection", "delete", "id", ssid });
                    Timeout.add_seconds (1, () => { refresh (); return Source.REMOVE; });
                });
                controls.pack_start (forget, false, false, 0);
            }
            string? state = active ? _("Connected")
                : (security.strip () == "" ? _("Open network") : security);
            return row (ssid, state, controls);
        }

        /* A saved network connects without asking; a new secured one
         * needs the password. Trying without it first would fail and
         * then ask, which is one pointless failure. */
        private void connect_wifi (string ssid, string security) {
            string[] argv;
            if (is_saved (ssid) || security.strip () == "") {
                argv = { "nmcli", "device", "wifi", "connect", ssid };
            } else {
                string? password = ask (_("Password for “%s”").printf (ssid),
                                        _("Wi-Fi password"), true);
                if (password == null) {
                    return;
                }
                argv = { "nmcli", "device", "wifi", "connect", ssid,
                         "password", password };
            }
            string message;
            bool ok = Run.run (argv, out message);
            if (!ok) {
                report (_("Could not connect to “%s”").printf (ssid), message);
            }
            refresh ();
        }

        private bool is_saved (string name) {
            string? saved = Run.capture ({ "nmcli", "-t", "-f", "NAME",
                                           "connection", "show" });
            if (saved == null) {
                return false;
            }
            foreach (unowned string line in saved.split ("\n")) {
                if (line.strip () == name) {
                    return true;
                }
            }
            return false;
        }

        private void hotspot_dialog () {
            var window = page.get_toplevel () as Gtk.Window;
            var dialog = new Gtk.Dialog.with_buttons (_("Hotspot"), window,
                Gtk.DialogFlags.MODAL | Gtk.DialogFlags.USE_HEADER_BAR,
                _("Cancel"), Gtk.ResponseType.CANCEL,
                _("Start"), Gtk.ResponseType.OK);
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box.margin = 16;
            var name = new Gtk.Entry ();
            name.set_text ("Kavis");
            var password = new Gtk.Entry ();
            password.set_visibility (false);
            password.set_placeholder_text (_("At least 8 characters"));
            box.pack_start (labelled (_("Network name"), name), false, false, 0);
            box.pack_start (labelled (_("Password"), password), false, false, 0);
            ((Gtk.Box) dialog.get_content_area ()).pack_start (box, true, true, 0);
            dialog.show_all ();
            if (dialog.run () == Gtk.ResponseType.OK) {
                string ssid = name.get_text ().strip ();
                string secret = password.get_text ();
                dialog.destroy ();
                if (ssid == "" || secret.length < 8) {
                    report (_("Hotspot not started"),
                        _("A hotspot needs a name and a password of at least 8 characters."));
                    return;
                }
                string message;
                if (!Run.run ({ "nmcli", "device", "wifi", "hotspot",
                                "ssid", ssid, "password", secret },
                              out message)) {
                    report (_("Hotspot not started"), message);
                }
                refresh ();
                return;
            }
            dialog.destroy ();
        }

        /* --- wired ---------------------------------------------------- */

        private void wired_section () {
            string? devices = Run.capture ({ "nmcli", "-t", "-f",
                "DEVICE,TYPE,STATE,CONNECTION", "device" });
            if (devices == null) {
                return;
            }
            bool header = false;
            foreach (unowned string line in devices.split ("\n")) {
                string[] f = split_terse (line);
                if (f.length < 4 || f[1] != "ethernet") {
                    continue;
                }
                if (!header) {
                    block = subsection (body, "wired",
                        Catalog.sub_title ("network", "wired"));
                    header = true;
                }
                bool up = f[2] == "connected";
                var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                var toggle = new Gtk.Button.with_label (
                    up ? _("Disconnect") : _("Connect"));
                string device = f[0];
                toggle.clicked.connect (() => {
                    Run.fire ({ "nmcli", "device", up ? "disconnect" : "connect",
                                device });
                    Timeout.add_seconds (2, () => { refresh (); return Source.REMOVE; });
                });
                controls.pack_start (toggle, false, false, 0);
                if (up && f[3] != "") {
                    string connection = f[3];
                    var addresses = new Gtk.Button.with_label (_("IP and DNS…"));
                    addresses.clicked.connect (() => address_dialog (connection));
                    controls.pack_start (addresses, false, false, 0);
                }
                block.pack_start (row (f[0], up ? f[3] : _("Not connected"),
                                      controls), false, false, 0);
            }
        }

        /* Manual addressing for one connection. Empty fields mean
         * automatic, which is also how NetworkManager stores it. */
        private void address_dialog (string connection) {
            string? current = Run.capture ({ "nmcli", "-t", "-f",
                "ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns",
                "connection", "show", connection });
            string method = "auto", addresses = "", gateway = "", dns = "";
            if (current != null) {
                foreach (unowned string line in current.split ("\n")) {
                    int at = line.index_of (":");
                    if (at < 0) {
                        continue;
                    }
                    string key = line.substring (0, at);
                    string value = line.substring (at + 1).strip ();
                    if (value == "--") {
                        value = "";
                    }
                    switch (key) {
                    case "ipv4.method":    method = value;    break;
                    case "ipv4.addresses": addresses = value; break;
                    case "ipv4.gateway":   gateway = value;   break;
                    case "ipv4.dns":       dns = value;       break;
                    }
                }
            }
            var window = page.get_toplevel () as Gtk.Window;
            var dialog = new Gtk.Dialog.with_buttons (_("IP and DNS"), window,
                Gtk.DialogFlags.MODAL | Gtk.DialogFlags.USE_HEADER_BAR,
                _("Cancel"), Gtk.ResponseType.CANCEL,
                _("Apply"), Gtk.ResponseType.OK);
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box.margin = 16;
            var automatic = new Gtk.Switch ();
            automatic.active = (method != "manual");
            var address_entry = new Gtk.Entry ();
            address_entry.set_text (addresses);
            address_entry.set_placeholder_text ("192.168.1.50/24");
            var gateway_entry = new Gtk.Entry ();
            gateway_entry.set_text (gateway);
            gateway_entry.set_placeholder_text ("192.168.1.1");
            var dns_entry = new Gtk.Entry ();
            dns_entry.set_text (dns);
            dns_entry.set_placeholder_text ("1.1.1.1, 9.9.9.9");
            box.pack_start (labelled (_("Automatic (DHCP)"), automatic),
                            false, false, 0);
            box.pack_start (labelled (_("Address"), address_entry),
                            false, false, 0);
            box.pack_start (labelled (_("Gateway"), gateway_entry),
                            false, false, 0);
            box.pack_start (labelled (_("DNS servers"), dns_entry),
                            false, false, 0);
            ((Gtk.Box) dialog.get_content_area ()).pack_start (box, true, true, 0);
            dialog.show_all ();
            if (dialog.run () == Gtk.ResponseType.OK) {
                bool auto_on = automatic.active;
                string a = address_entry.get_text ().strip ();
                string g = gateway_entry.get_text ().strip ();
                string d = dns_entry.get_text ().strip ();
                dialog.destroy ();
                string message;
                bool ok;
                if (auto_on) {
                    ok = Run.run ({ "nmcli", "connection", "modify", connection,
                                    "ipv4.method", "auto",
                                    "ipv4.addresses", "", "ipv4.gateway", "",
                                    "ipv4.dns", d }, out message);
                } else {
                    ok = Run.run ({ "nmcli", "connection", "modify", connection,
                                    "ipv4.method", "manual",
                                    "ipv4.addresses", a,
                                    "ipv4.gateway", g,
                                    "ipv4.dns", d }, out message);
                }
                if (!ok) {
                    report (_("Could not save the addresses"), message);
                } else {
                    /* The change only reaches the interface when the
                     * connection comes back up. */
                    Run.fire ({ "nmcli", "connection", "up", connection });
                }
                refresh ();
                return;
            }
            dialog.destroy ();
        }

        /* --- VPN ------------------------------------------------------ */

        private void vpn_section () {
            block = subsection (body, "vpn",
                                Catalog.sub_title ("network", "vpn"));
            string? saved = Run.capture ({ "nmcli", "-t", "-f",
                "NAME,TYPE,STATE", "connection", "show" });
            int count = 0;
            if (saved != null) {
                foreach (unowned string line in saved.split ("\n")) {
                    string[] f = split_terse (line);
                    if (f.length < 3) {
                        continue;
                    }
                    if (f[1] != "vpn" && f[1] != "wireguard") {
                        continue;
                    }
                    bool up = f[2] == "activated";
                    string name = f[0];
                    var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                    var toggle = new Gtk.Button.with_label (
                        up ? _("Disconnect") : _("Connect"));
                    toggle.clicked.connect (() => {
                        string message;
                        if (!Run.run ({ "nmcli", "connection",
                                        up ? "down" : "up", "id", name },
                                      out message)) {
                            report (_("VPN “%s”").printf (name), message);
                        }
                        refresh ();
                    });
                    var remove = new Gtk.Button.with_label (_("Remove"));
                    remove.clicked.connect (() => {
                        Run.fire ({ "nmcli", "connection", "delete", "id", name });
                        Timeout.add_seconds (1, () => { refresh (); return Source.REMOVE; });
                    });
                    controls.pack_start (toggle, false, false, 0);
                    controls.pack_start (remove, false, false, 0);
                    block.pack_start (row (name,
                        (f[1] == "wireguard") ? "WireGuard" : "OpenVPN",
                        controls), false, false, 0);
                    count++;
                }
            }
            var import = new Gtk.Button.with_label (_("Import a profile…"));
            import.clicked.connect (() => import_vpn ());
            block.pack_start (row (
                (count == 0) ? _("No VPN configured") : _("Add another"),
                _("A WireGuard .conf or an OpenVPN .ovpn file"),
                import), false, false, 0);
        }

        /* NetworkManager imports both formats itself; the type is
         * decided by the file, not by asking the user which they have. */
        private void import_vpn () {
            var window = page.get_toplevel () as Gtk.Window;
            var chooser = new Gtk.FileChooserDialog (
                _("Import a VPN profile"), window,
                Gtk.FileChooserAction.OPEN,
                _("Cancel"), Gtk.ResponseType.CANCEL,
                _("Import"), Gtk.ResponseType.ACCEPT);
            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (_("VPN profiles"));
            filter.add_pattern ("*.conf");
            filter.add_pattern ("*.ovpn");
            chooser.add_filter (filter);
            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                string path = chooser.get_filename ();
                chooser.destroy ();
                string type = path.has_suffix (".ovpn")
                    ? "openvpn" : "wireguard";
                string message;
                if (!Run.run ({ "nmcli", "connection", "import",
                                "type", type, "file", path },
                              out message)) {
                    report (_("Could not import the profile"), message);
                }
                refresh ();
                return;
            }
            chooser.destroy ();
        }

        /* --- DNS privacy ---------------------------------------------- */

        private void dns_section () {
            if (!FileUtils.test ("/usr/lib/kavis/set-dns",
                                 FileTest.IS_EXECUTABLE)) {
                return;
            }
            block = subsection (body, "dns",
                                Catalog.sub_title ("network", "dns"));
            var provider = new Gtk.ComboBoxText ();
            provider.append ("off", _("Off (use the network's DNS)"));
            provider.append ("cloudflare", "Cloudflare");
            provider.append ("google", "Google");
            provider.append ("quad9", "Quad9");
            provider.active_id = conf_get ("network", "dns_provider", "off");
            provider.changed.connect (() => {
                string id = provider.active_id ?? "off";
                conf_set ("network", "dns_provider", id);
                Run.fire ({ "pkexec", "/usr/lib/kavis/set-dns", id });
            });
            /* Named honestly: systemd-resolved speaks DNS over TLS, not
             * DNS over HTTPS. Both encrypt the query on the way to the
             * resolver; DoT is what this machine can do without adding
             * a proxy, and calling it DoH in the interface would be a
             * lie the user could not check. */
            block.pack_start (row (_("Encrypted DNS"),
                _("Send DNS queries over TLS to a chosen resolver instead of the network's"),
                provider), false, false, 0);
        }

        /* --- small helpers -------------------------------------------- */

        /* nmcli terse output escapes a literal colon as "\:". */
        private string[] split_terse (string line) {
            string[] fields = {};
            var current = new StringBuilder ();
            bool escaped = false;
            for (int i = 0; i < line.length; i++) {
                char c = line[i];
                if (escaped) {
                    current.append_c (c);
                    escaped = false;
                } else if (c == '\\') {
                    escaped = true;
                } else if (c == ':') {
                    fields += current.str;
                    current = new StringBuilder ();
                } else {
                    current.append_c (c);
                }
            }
            fields += current.str;
            return fields;
        }

        private Gtk.Widget labelled (string text, Gtk.Widget control) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            var label = new Gtk.Label (text);
            label.set_xalign (0);
            label.set_size_request (150, -1);
            box.pack_start (label, false, false, 0);
            control.hexpand = true;
            box.pack_start (control, true, true, 0);
            return box;
        }

        private string? ask (string title, string label, bool secret) {
            var window = page.get_toplevel () as Gtk.Window;
            var dialog = new Gtk.Dialog.with_buttons (title, window,
                Gtk.DialogFlags.MODAL | Gtk.DialogFlags.USE_HEADER_BAR,
                _("Cancel"), Gtk.ResponseType.CANCEL,
                _("Connect"), Gtk.ResponseType.OK);
            var entry = new Gtk.Entry ();
            entry.set_visibility (!secret);
            entry.set_activates_default (true);
            dialog.set_default_response (Gtk.ResponseType.OK);
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box.margin = 16;
            box.pack_start (labelled (label, entry), false, false, 0);
            ((Gtk.Box) dialog.get_content_area ()).pack_start (box, true, true, 0);
            dialog.show_all ();
            string? answer = null;
            if (dialog.run () == Gtk.ResponseType.OK) {
                answer = entry.get_text ();
            }
            dialog.destroy ();
            return answer;
        }

        /* nmcli's own message is shown rather than a rewritten one: it
         * says things like "Secrets were required, but not provided",
         * which is the actual answer to what went wrong. */
        private void report (string summary, string detail) {
            var window = page.get_toplevel () as Gtk.Window;
            var dialog = new Gtk.MessageDialog (window,
                Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING,
                Gtk.ButtonsType.CLOSE, "%s", summary);
            if (detail.strip () != "") {
                dialog.format_secondary_text ("%s", detail.strip ());
            }
            dialog.run ();
            dialog.destroy ();
        }
    }
}
