/* Appearance page (madde 38). Theme switch is LIVE via xsettingsd;
 * corner radius / animation speed rewrite the user picom config and
 * restart picom; transparency is read by the panel (acrylic class);
 * accent is fixed teal (color identity) — display only.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget appearance (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        /* Theme: dark (default) / light. "Follow system" was REMOVED
         * (B1): we are the system, there is no third source. A legacy
         * "system" in the conf falls back to dark. */
        var look = subsection (body, "theme",
                               Catalog.sub_title ("appearance", "theme"));
        var theme = new Gtk.ComboBoxText ();
        theme.append ("dark", _("Dark"));
        theme.append ("light", _("Light"));
        string saved = conf_get ("appearance", "theme", "dark");
        theme.active_id = (saved == "light") ? "light" : "dark";
        theme.changed.connect (() => {
            conf_set ("appearance", "theme", theme.active_id);
            Apply.theme (theme.active_id);
        });
        look.pack_start (row (_("Theme"),
            _("Dark is the default"), theme), false, false, 0);

        /* Corner rounding (window corners, picom). */
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

        /* Popup animation (test2 C6): the panel's own popups (start,
         * quick settings, notifications, calendar). The duration comes
         * from the speed above; Apply.picom writes the picom window rule. */
        var popup = new Gtk.ComboBoxText ();
        popup.append ("slide", _("Slide up"));
        popup.append ("grow", _("Grow"));
        popup.append ("fade", _("Fade"));
        popup.append ("none", _("None"));
        popup.active_id = conf_get ("appearance", "popup_animation",
                                    "slide");

        /* Three controls feed one applier: the values are written to
         * kavis.conf and picom restarts with the user copy. */
        radius.button_release_event.connect (() => {
            apply_picom ((int) radius.get_value (),
                         int.parse (anim.active_id ?? "100"),
                         popup.active_id ?? "slide");
            return false;
        });
        anim.changed.connect (() => {
            apply_picom ((int) radius.get_value (),
                         int.parse (anim.active_id ?? "100"),
                         popup.active_id ?? "slide");
        });
        popup.changed.connect (() => {
            apply_picom ((int) radius.get_value (),
                         int.parse (anim.active_id ?? "100"),
                         popup.active_id ?? "slide");
        });
        /* Accent color: fixed teal — display only (madde 38). It
         * belongs with the theme, not with the effects below. */
        var swatch = new Gtk.Label ("   ");
        swatch.get_style_context ().add_class ("kavis-accent-swatch");
        look.pack_start (row (_("Accent color"),
            _("Teal — fixed in this release"), swatch),
            false, false, 0);

        var effects = subsection (body, "effects",
            Catalog.sub_title ("appearance", "effects"));
        effects.pack_start (row (_("Corner roundness"),
            _("Window corners; popups keep the design values"),
            radius), false, false, 0);
        effects.pack_start (row (_("Animation speed"), null, anim),
                            false, false, 0);
        effects.pack_start (row (_("Popup animation"),
            _("Start menu, quick settings and notifications"), popup),
            false, false, 0);

        /* Transparency (panel acrylic; live — the panel watches kavis.conf). */
        var transparency = new Gtk.Switch ();
        transparency.active =
            conf_get_bool ("appearance", "transparency", true);
        transparency.notify["active"].connect (() => {
            conf_set_bool ("appearance", "transparency",
                           transparency.active);
        });
        effects.pack_start (row (_("Transparency effects"),
            _("Taskbar and popup translucency (blur needs a GPU backend — design limit)"),
            transparency), false, false, 0);

        /* Wallpaper (B5): frameless thumbnails with 8px corners, the
         * selected one gets a 2px teal outline + a check at top right.
         * B8: thumbnails are scaled to 200px and loaded on idle after
         * the window is drawn — they do not enter the startup RSS. */
        var walls = subsection (body, "wallpaper",
            Catalog.sub_title ("appearance", "wallpaper"));
        var flow = new Gtk.FlowBox ();
        flow.max_children_per_line = 4;
        flow.column_spacing = 8;
        flow.row_spacing = 8;
        flow.selection_mode = Gtk.SelectionMode.NONE;
        walls.pack_start (flow, false, false, 0);
        Idle.add (() => {
            load_wallpapers (flow);
            return Source.REMOVE;
        });

        return page;
    }

    private void load_wallpapers (Gtk.FlowBox flow) {
        string current = conf_get ("appearance", "wallpaper", "");
        Thumbnail[] thumbs = {};
        try {
            var dir = Dir.open ("/usr/share/backgrounds/kavis");
            string? name;
            while ((name = dir.read_name ()) != null) {
                /* -preview.png: the theme package's own thumbnail
                 * (menu/GRUB preview) — must not appear twice in the list. */
                if ((!name.has_suffix (".png") && !name.has_suffix (".jpg"))
                    || name.contains ("-preview")) {
                    continue;
                }
                string path = "/usr/share/backgrounds/kavis/" + name;
                var thumb = new Thumbnail (path, path == current);
                thumb.set_tooltip_text (name);
                thumbs += thumb;
                flow.add (thumb);
            }
        } catch (FileError e) { }
        foreach (unowned Thumbnail thumb in thumbs) {
            thumb.chosen.connect ((path) => {
                foreach (unowned Thumbnail other in thumbs) {
                    other.set_selected (other == thumb);
                }
                conf_set ("appearance", "wallpaper", path);
                Apply.wallpaper (path);
            });
        }
        flow.show_all ();
    }

    /* Rounded wallpaper thumbnail drawn with cairo (a GtkImage cannot
     * clip its pixels to a radius). 200×112, selection = teal ring +
     * check badge. */
    private class Thumbnail : Gtk.DrawingArea {
        public signal void chosen (string path);
        private const int W = 200;
        private const int H = 112;
        private const double R = 8;
        private Gdk.Pixbuf? pixbuf = null;
        private new string path;
        private bool selected;

        public Thumbnail (string path, bool selected) {
            this.path = path;
            this.selected = selected;
            set_size_request (W + 4, H + 4);
            try {
                pixbuf = new Gdk.Pixbuf.from_file_at_scale (
                    path, W, H, false);
            } catch (Error e) { }
            add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
            button_press_event.connect (() => {
                chosen (this.path);
                return true;
            });
        }

        public void set_selected (bool on) {
            selected = on;
            queue_draw ();
        }

        public override bool draw (Cairo.Context cr) {
            double x = 2, y = 2;
            cr.new_sub_path ();
            cr.arc (x + W - R, y + R, R, -Math.PI / 2, 0);
            cr.arc (x + W - R, y + H - R, R, 0, Math.PI / 2);
            cr.arc (x + R, y + H - R, R, Math.PI / 2, Math.PI);
            cr.arc (x + R, y + R, R, Math.PI, 3 * Math.PI / 2);
            cr.close_path ();
            if (pixbuf != null) {
                cr.save ();
                cr.clip_preserve ();
                Gdk.cairo_set_source_pixbuf (cr, pixbuf, x, y);
                cr.paint ();
                cr.restore ();
            }
            if (selected) {
                cr.set_line_width (2);
                cr.set_source_rgb (0x2D / 255.0, 0xD4 / 255.0,
                                   0xBF / 255.0);
                cr.stroke ();
                /* Check badge: top right, teal circle + dark tick. */
                double cx = x + W - 14, cy = y + 14;
                cr.arc (cx, cy, 9, 0, 2 * Math.PI);
                cr.fill ();
                cr.set_source_rgb (0x0D / 255.0, 0x14 / 255.0,
                                   0x1B / 255.0);
                cr.set_line_width (2);
                cr.move_to (cx - 4, cy);
                cr.line_to (cx - 1, cy + 3);
                cr.line_to (cx + 4, cy - 3);
                cr.stroke ();
            } else {
                cr.new_path ();
            }
            return true;
        }
    }

    private void apply_picom (int radius, int anim, string popup) {
        conf_set_int ("appearance", "radius", radius);
        conf_set_int ("appearance", "animation", anim);
        conf_set ("appearance", "popup_animation", popup);
        Apply.picom (radius, anim, popup,
                     conf_get ("taskbar", "position", "bottom"));
    }
}
