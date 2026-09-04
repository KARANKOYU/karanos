/* Section pages: shared frame + row widgets (madde 9).
 *
 * Every page is a vertical list of "setting rows": bold-ish label +
 * optional subtitle on the left, the control on the right — the W11
 * Settings card shape, spacing per tasarim-dili.md (16 inner padding,
 * 8 between items, 12 between groups).
 */

namespace Kavis.Settings.Pages {

    /* Common page frame: margins, title on top, rows below. */
    public Gtk.Widget frame (string title, out Gtk.Box body) {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        page.margin = 24;
        var heading = new Gtk.Label (title);
        heading.set_xalign (0);
        heading.get_style_context ().add_class ("kavis-settings-title");
        page.pack_start (heading, false, false, 0);
        body = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        page.pack_start (body, true, true, 0);
        return page;
    }

    /* One setting row: title (+subtitle) left, control right. */
    public Gtk.Widget row (string title, string? subtitle,
                           Gtk.Widget? control) {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        /* B4: every setting row is a CARD like W11 — background, 1px
         * border, 8px corners; the gap between cards is the body
         * spacing (8). */
        box.get_style_context ().add_class ("kavis-card");
        var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        var label = new Gtk.Label (title);
        label.set_xalign (0);
        text.pack_start (label, false, false, 0);
        if (subtitle != null) {
            var sub = new Gtk.Label (subtitle);
            sub.set_xalign (0);
            sub.set_line_wrap (true);
            sub.get_style_context ().add_class ("dim-label");
            text.pack_start (sub, false, false, 0);
        }
        box.pack_start (text, true, true, 0);
        if (control != null) {
            control.valign = Gtk.Align.CENTER;
            box.pack_end (control, false, false, 0);
        }
        return box;
    }

    /* A collapsible sub-section (item 74): the second level of the
     * sidebar, and the anchor a search result scrolls to.
     *
     * Every page is now a list of these instead of a flat run of rows.
     * The id must match a Catalog.subs () entry — that is the pairing
     * the sidebar tree and the search results are built from.
     *
     * Returns the box the rows go into, so a page reads
     *   var block = subsection (body, "theme", ...);
     *   block.pack_start (row (...));
     */
    public Gtk.Box subsection (Gtk.Box body, string sub_id,
                               string title) {
        var block = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        block.set_data<string> ("kavis-sub", sub_id);

        var inner = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        var revealer = new Gtk.Revealer ();
        /* One duration, one curve (tasarim-dili.md): 180 ms. */
        revealer.transition_duration = 180;
        revealer.transition_type =
            Gtk.RevealerTransitionType.SLIDE_DOWN;
        revealer.set_reveal_child (true);
        revealer.add (inner);

        var arrow = new Gtk.Image.from_icon_name (
            "pan-down-symbolic", Gtk.IconSize.MENU);
        var label = new Gtk.Label (title);
        label.set_xalign (0);
        label.get_style_context ().add_class ("kavis-sub-title");
        var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        header_box.pack_start (arrow, false, false, 0);
        header_box.pack_start (label, true, true, 0);
        var header = new Gtk.Button ();
        header.get_style_context ().add_class ("kavis-disclosure");
        header.add (header_box);
        header.margin_top = 12;
        header.clicked.connect (() => {
            /* reveal_child, not child_revealed: the second is where
             * the animation has got to, so two quick clicks would
             * fight each other. */
            bool open = !revealer.reveal_child;
            revealer.set_reveal_child (open);
            arrow.set_from_icon_name (
                open ? "pan-down-symbolic" : "pan-end-symbolic",
                Gtk.IconSize.MENU);
        });

        block.pack_start (header, false, false, 0);
        block.pack_start (revealer, false, false, 0);
        block.set_data<Gtk.Revealer> ("kavis-revealer", revealer);
        body.pack_start (block, false, false, 0);
        return inner;
    }

    /* Open a sub-section that the user was sent to from search, and
     * hand back the widget to scroll to. Null when this page has no
     * such block. */
    public Gtk.Widget? reveal_subsection (Gtk.Widget page,
                                          string sub_id) {
        var block = find_subsection (page, sub_id);
        if (block == null) {
            return null;
        }
        var revealer = block.get_data<Gtk.Revealer> ("kavis-revealer");
        if (revealer != null) {
            revealer.set_reveal_child (true);
        }
        return block;
    }

    private Gtk.Widget? find_subsection (Gtk.Widget widget,
                                         string sub_id) {
        string? mine = widget.get_data<string> ("kavis-sub");
        if (mine == sub_id) {
            return widget;
        }
        var container = widget as Gtk.Container;
        if (container == null) {
            return null;
        }
        foreach (unowned Gtk.Widget child in
                 container.get_children ()) {
            var found = find_subsection (child, sub_id);
            if (found != null) {
                return found;
            }
        }
        return null;
    }

    /* Group heading inside a page. */
    public Gtk.Widget group (string title) {
        var label = new Gtk.Label (title);
        label.set_xalign (0);
        label.margin_top = 12;
        label.margin_start = 4;
        label.get_style_context ().add_class ("dim-label");
        return label;
    }

    /* Read a string from kavis.conf with a default. */
    public string conf_get (string grp, string key, string fallback) {
        try {
            return Config.load ().get_string (grp, key);
        } catch (Error e) {
            return fallback;
        }
    }

    public bool conf_get_bool (string grp, string key, bool fallback) {
        try {
            return Config.load ().get_boolean (grp, key);
        } catch (Error e) {
            return fallback;
        }
    }

    public int conf_get_int (string grp, string key, int fallback) {
        try {
            return Config.load ().get_integer (grp, key);
        } catch (Error e) {
            return fallback;
        }
    }

    /* Write one value back (loads first so other groups survive). */
    public void conf_set (string grp, string key, string value) {
        var file = Config.load ();
        file.set_string (grp, key, value);
        Config.save (file);
    }

    public void conf_set_bool (string grp, string key, bool value) {
        var file = Config.load ();
        file.set_boolean (grp, key, value);
        Config.save (file);
    }

    public void conf_set_int (string grp, string key, int value) {
        var file = Config.load ();
        file.set_integer (grp, key, value);
        Config.save (file);
    }

    /* Build one section's page by id. */
    public Gtk.Widget build (string id, string title) {
        switch (id) {
        case "appearance": return appearance (title);
        case "display":    return display (title);
        case "sound":      return sound (title);
        case "keyboard":   return keyboard (title);
        case "power":      return power (title);
        case "network":    return network (title);
        case "taskbar":    return taskbar (title);
        case "system":     return system_page (title);
        case "hardware":   return hardware (title);
        }
        Gtk.Box body;
        return frame (title, out body);
    }
}
