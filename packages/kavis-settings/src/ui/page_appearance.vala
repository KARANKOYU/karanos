/* Appearance page (madde 38). Theme switch is LIVE via xsettingsd;
 * corner radius / animation speed rewrite the user picom config and
 * restart picom; transparency is read by the panel (acrylic class);
 * accent is fixed teal (renk kimliği) — display only.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget appearance (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        /* Tema: koyu (varsayılan) / açık / sistem. */
        var theme = new Gtk.ComboBoxText ();
        theme.append ("dark", _("Dark"));
        theme.append ("light", _("Light"));
        theme.append ("system", _("Same as system"));
        theme.active_id = conf_get ("appearance", "theme", "dark");
        theme.changed.connect (() => {
            conf_set ("appearance", "theme", theme.active_id);
            Apply.theme (theme.active_id);
        });
        body.pack_start (row (_("Theme"),
            _("Dark is the default; System follows the distribution default for now"),
            theme), false, false, 0);

        /* Köşe yuvarlaklığı (pencere köşeleri, picom). */
        var radius = new Gtk.Scale.with_range (
            Gtk.Orientation.HORIZONTAL, 0, 16, 1);
        radius.set_size_request (180, -1);
        radius.set_value (conf_get_int ("appearance", "radius", 8));

        var anim = new Gtk.ComboBoxText ();
        anim.append ("0", _("Off"));
        anim.append ("60", _("Fast"));
        anim.append ("100", _("Normal"));
        anim.append ("160", _("Slow"));
        anim.active_id = conf_get_int ("appearance", "animation", 100)
                             .to_string ();

        /* İki kontrol tek uygulayıcıyı besler: değerler kavis.conf'a
         * yazılır, picom kullanıcı kopyasıyla yeniden başlar. */
        radius.button_release_event.connect (() => {
            apply_picom ((int) radius.get_value (),
                         int.parse (anim.active_id ?? "100"));
            return false;
        });
        anim.changed.connect (() => {
            apply_picom ((int) radius.get_value (),
                         int.parse (anim.active_id ?? "100"));
        });
        body.pack_start (row (_("Corner roundness"),
            _("Window corners; popups keep the design values"),
            radius), false, false, 0);
        body.pack_start (row (_("Animation speed"), null, anim),
                         false, false, 0);

        /* Saydamlık (panel akriliği; canlı — panel kavis.conf izler). */
        var transparency = new Gtk.Switch ();
        transparency.active =
            conf_get_bool ("appearance", "transparency", true);
        transparency.notify["active"].connect (() => {
            conf_set_bool ("appearance", "transparency",
                           transparency.active);
        });
        body.pack_start (row (_("Transparency effects"),
            _("Taskbar and popup translucency (blur needs a GPU backend — design limit)"),
            transparency), false, false, 0);

        /* Duvar kâğıdı: /usr/share/backgrounds/kavis içindekiler. */
        body.pack_start (group (_("Wallpaper")), false, false, 0);
        var flow = new Gtk.FlowBox ();
        flow.max_children_per_line = 4;
        flow.selection_mode = Gtk.SelectionMode.NONE;
        try {
            var dir = Dir.open ("/usr/share/backgrounds/kavis");
            string? name;
            while ((name = dir.read_name ()) != null) {
                if (!name.has_suffix (".png")
                    && !name.has_suffix (".jpg")) {
                    continue;
                }
                string path = "/usr/share/backgrounds/kavis/" + name;
                var button = new Gtk.Button ();
                try {
                    var pix = new Gdk.Pixbuf.from_file_at_scale (
                        path, 140, 80, true);
                    button.add (new Gtk.Image.from_pixbuf (pix));
                } catch (Error e) {
                    button.label = name;
                }
                button.set_tooltip_text (name);
                button.clicked.connect (() => {
                    conf_set ("appearance", "wallpaper", path);
                    Apply.wallpaper (path);
                });
                flow.add (button);
            }
        } catch (FileError e) { }
        body.pack_start (flow, false, false, 0);

        /* Vurgu rengi: sabit turkuaz — yalnız gösterim (madde 38). */
        var swatch = new Gtk.Label ("   ");
        swatch.get_style_context ().add_class ("kavis-accent-swatch");
        body.pack_start (row (_("Accent color"),
            _("Teal — fixed in this release"), swatch),
            false, false, 0);

        return page;
    }

    private void apply_picom (int radius, int anim) {
        conf_set_int ("appearance", "radius", radius);
        conf_set_int ("appearance", "animation", anim);
        Apply.picom (radius, anim);
    }
}
