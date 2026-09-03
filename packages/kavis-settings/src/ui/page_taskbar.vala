/* Taskbar page. Writes the SAME kavis.conf [taskbar] keys the panel
 * reads; the panel watches the file and restarts itself on geometry
 * changes (1A-2) — no IPC needed here.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget taskbar (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        var position = new Gtk.ComboBoxText ();
        position.append ("bottom", _("Bottom"));
        position.append ("top", _("Top"));
        position.append ("left", _("Left"));
        position.append ("right", _("Right"));
        position.active_id = conf_get ("taskbar", "position", "bottom");
        position.changed.connect (() => {
            conf_set ("taskbar", "position", position.active_id);
            /* C6: the popup slide direction depends on the panel
             * position — rewrite the picom rule with the new direction. */
            Apply.picom (conf_get_int ("appearance", "radius", 8),
                         conf_get_int ("appearance", "animation", 100),
                         conf_get ("appearance", "popup_animation",
                                   "slide"),
                         position.active_id ?? "bottom");
        });
        body.pack_start (row (_("Position"), null, position),
                         false, false, 0);

        var size = new Gtk.ComboBoxText ();
        size.append ("thin", _("Small"));
        size.append ("medium", _("Medium"));
        size.append ("thick", _("Large"));
        size.active_id = conf_get ("taskbar", "size", "medium");
        size.changed.connect (() => {
            conf_set ("taskbar", "size", size.active_id);
        });
        body.pack_start (row (_("Size"), null, size), false, false, 0);

        var align = new Gtk.ComboBoxText ();
        align.append ("left", _("Left"));
        align.append ("center", _("Center"));
        align.active_id = conf_get ("taskbar", "align", "left");
        align.changed.connect (() => {
            conf_set ("taskbar", "align", align.active_id);
        });
        body.pack_start (row (_("Alignment"),
            _("Start button and window list placement"), align),
            false, false, 0);

        var autohide = new Gtk.Switch ();
        autohide.active = conf_get_bool ("taskbar", "autohide", false);
        autohide.notify["active"].connect (() => {
            conf_set_bool ("taskbar", "autohide", autohide.active);
        });
        body.pack_start (row (_("Automatically hide the taskbar"),
                              null, autohide), false, false, 0);

        /* Pinned apps: the list + how to edit it. Editing happens on
         * the taskbar itself (drag / right-click) — a second editor
         * here would be duplicate work. */
        body.pack_start (group (_("Pinned apps")), false, false, 0);
        string pinned_path = Path.build_filename (
            Environment.get_user_config_dir (), "kavis", "pinned.conf");
        string names = "";
        try {
            string contents;
            FileUtils.get_contents (pinned_path, out contents);
            foreach (unowned string line in contents.split ("\n")) {
                string id = line.strip ();
                if (id != "" && !id.has_prefix ("#")) {
                    if (names != "") {
                        names += ", ";
                    }
                    names += id.replace (".desktop", "");
                }
            }
        } catch (Error e) {
            names = _("Default set");
        }
        var pinned_label = new Gtk.Label (names);
        pinned_label.set_xalign (0);
        pinned_label.set_line_wrap (true);
        pinned_label.get_style_context ().add_class ("dim-label");
        body.pack_start (pinned_label, false, false, 0);
        var hint = new Gtk.Label (
            _("Pin and reorder from the taskbar itself (right-click or drag)"));
        hint.set_xalign (0);
        hint.get_style_context ().add_class ("dim-label");
        body.pack_start (hint, false, false, 0);

        return page;
    }
}
