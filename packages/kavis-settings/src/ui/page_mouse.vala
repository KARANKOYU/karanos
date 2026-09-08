/* Mouse and pointer page (feedback, 8 Sep 2026).
 *
 * Kavis had a mouse HARDWARE TEST and no mouse settings at all: no way
 * to make the pointer bigger, no way to make it visible on a white
 * document, no left-handed switch. Every one of those is a thing people
 * change on the first day, and two of them are accessibility settings
 * rather than preferences.
 *
 * The pointer colour is a THEME choice, because that is what X has:
 * a cursor theme is a directory of images, so "black pointer" means
 * shipping the same drawings with the body and outline swapped. The
 * generator already drew them from SVG, so the second theme costs one
 * more build of a file we already build (kavis-theme's rules).
 *
 * Everything here writes kavis.conf and applies immediately; the size
 * and colour reach running applications only when they open a new
 * window, which the page says out loud rather than pretending
 * otherwise.
 */

namespace Kavis.Settings.Pages {

    /* Directory name -> the name a person recognises. Only themes that
     * are actually installed are offered: a list that promises a
     * pointer the machine does not have is worse than a short list. */
    private struct Pointer {
        public string dir;
        public string label;
    }

    /* Where cursor themes live.
     *
     * NOT just /usr/share/icons. XCursor searches the user's own
     * directories first, and a person who installs a pointer theme from
     * the store or by hand puts it in one of those — a settings page
     * that only looks in the system directory would not list the theme
     * the machine is already using. The order is XCursor's own. */
    namespace Cursors {

        public string? find (string name) {
            string[] roots = {
                Path.build_filename (Environment.get_home_dir (), ".icons"),
                Path.build_filename (Environment.get_user_data_dir (),
                                     "icons")
            };
            foreach (unowned string dir in Environment.get_system_data_dirs ()) {
                roots += Path.build_filename (dir, "icons");
            }
            roots += "/usr/share/icons";
            foreach (unowned string root in roots) {
                string path = Path.build_filename (root, name, "cursors");
                if (FileUtils.test (path, FileTest.IS_DIR)) {
                    return path;
                }
            }
            return null;
        }
    }

    public Gtk.Widget mouse (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        /* --- Pointer ------------------------------------------------ */
        var pointer_block = subsection (body, "pointer",
            Catalog.sub_title ("mouse", "pointer"));

        Pointer[] themes = {
            { "Kavis-Cursors", _("Kavis white") },
            { "Kavis-Cursors-Black", _("Kavis black") },
            { "Breeze_Light", _("Breeze light") },
            { "Breeze_Snow", _("Breeze snow") },
            { "breeze_cursors", _("Breeze dark") }
        };
        var colour = new Gtk.ComboBoxText ();
        string current_theme = conf_get ("mouse", "pointer", "Kavis-Cursors");
        int index = 0;
        int active = -1;
        foreach (unowned Pointer p in themes) {
            if (Cursors.find (p.dir) == null) {
                continue;
            }
            colour.append (p.dir, p.label);
            if (p.dir == current_theme) {
                active = index;
            }
            index++;
        }
        colour.set_active (active >= 0 ? active : 0);

        var size = new Gtk.ComboBoxText ();
        /* The four sizes the cursors are generated at. An XCursor theme
         * only carries the sizes it was built with; offering a fifth
         * would silently pick the nearest one. */
        size.append ("24", _("Small (24)"));
        size.append ("32", _("Medium (32)"));
        size.append ("48", _("Large (48)"));
        size.append ("64", _("Extra large (64)"));
        size.set_active_id (conf_get_int ("mouse", "pointer-size", 24)
                            .to_string ());

        colour.changed.connect (() => {
            string? id = colour.get_active_id ();
            if (id != null) {
                conf_set ("mouse", "pointer", id);
                Apply.pointer (id, conf_get_int ("mouse", "pointer-size", 24));
            }
        });
        size.changed.connect (() => {
            string? id = size.get_active_id ();
            if (id != null) {
                conf_set_int ("mouse", "pointer-size", int.parse (id));
                Apply.pointer (conf_get ("mouse", "pointer",
                                         "Kavis-Cursors"), int.parse (id));
            }
        });

        /* An empty dropdown is a setting that looks broken and says
         * nothing. If not one of the themes is installed — which is
         * what a bare build tree looks like — say that instead of
         * offering a list with nothing in it. */
        if (index == 0) {
            var none = new Gtk.Label (_("No pointer themes installed"));
            none.get_style_context ().add_class ("dim-label");
            pointer_block.pack_start (row (_("Pointer colour"),
                _("The Kavis pointers come with the theme package"),
                none), false, false, 0);
        } else {
            pointer_block.pack_start (row (_("Pointer colour"),
                _("A white pointer disappears on a white page; a dark one disappears on the desktop"),
                colour), false, false, 0);
        }
        pointer_block.pack_start (row (_("Pointer size"),
            _("Applications already open keep the old size until their next window"),
            size), false, false, 0);

        /* A colour of one's own.
         *
         * The dropdown offers the pointers that EXIST; this builds one
         * that does not. The cursors were always generated from SVG at
         * package build time, so generating one more at the moment
         * somebody picks a colour is the same operation with a
         * different argument — and it is the only way an X11 pointer
         * can take an arbitrary colour, because a cursor theme is a
         * directory of images and not a stylesheet.
         *
         * It goes in the user's own icon directory, which is where
         * XCursor looks first, so nothing needs root and nothing the
         * package manager owns is touched. */
        var custom = new Gtk.ColorButton ();
        custom.set_use_alpha (false);
        var chosen = Gdk.RGBA ();
        chosen.parse (conf_get ("mouse", "pointer-colour", "#2DD4BF"));
        custom.set_rgba (chosen);
        var building = new Gtk.Label ("");
        building.get_style_context ().add_class ("dim-label");
        custom.color_set.connect (() => {
            var rgba = custom.get_rgba ();
            string hex = "#%02X%02X%02X".printf (
                (int) (rgba.red * 255), (int) (rgba.green * 255),
                (int) (rgba.blue * 255));
            conf_set ("mouse", "pointer-colour", hex);
            build_pointer (hex, building, size);
        });
        var custom_side = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        custom_side.pack_start (building, false, false, 0);
        custom_side.pack_start (custom, false, false, 0);
        pointer_block.pack_start (row (_("Your own colour"),
            _("Builds a pointer in this colour from the Kavis drawings. The outline stays black or white, whichever keeps it visible."),
            custom_side), false, false, 0);


        /* --- Buttons ------------------------------------------------ */
        var buttons = subsection (body, "buttons",
            Catalog.sub_title ("mouse", "buttons"));

        var handed = new Gtk.Switch ();
        handed.active = conf_get_bool ("mouse", "left-handed", false);
        handed.notify["active"].connect (() => {
            conf_set_bool ("mouse", "left-handed", handed.active);
            Apply.left_handed (handed.active);
        });
        buttons.pack_start (row (_("Left-handed"),
            _("Swaps the left and right buttons"), handed), false, false, 0);

        var double_click = new Gtk.Scale.with_range (
            Gtk.Orientation.HORIZONTAL, 200, 900, 50);
        double_click.set_size_request (220, -1);
        double_click.set_value (conf_get_int ("mouse", "double-click", 400));
        double_click.set_draw_value (false);
        /* The three marks are the answer to "what is a normal value" —
         * a bare slider between two numbers tells nobody anything. */
        double_click.add_mark (200, Gtk.PositionType.BOTTOM, _("Fast"));
        double_click.add_mark (400, Gtk.PositionType.BOTTOM, _("Default"));
        double_click.add_mark (900, Gtk.PositionType.BOTTOM, _("Slow"));
        double_click.value_changed.connect (() => {
            int ms = (int) double_click.get_value ();
            conf_set_int ("mouse", "double-click", ms);
            Apply.double_click (ms);
        });
        buttons.pack_start (row (_("Double-click speed"),
            _("How long two clicks may be apart and still count as one double click"),
            double_click), false, false, 0);

        /* --- Pointer speed and scrolling ---------------------------- */
        var motion = subsection (body, "motion",
            Catalog.sub_title ("mouse", "motion"));

        var speed = new Gtk.Scale.with_range (
            Gtk.Orientation.HORIZONTAL, -100, 100, 5);
        speed.set_size_request (220, -1);
        speed.set_value (conf_get_int ("mouse", "speed", 0));
        speed.set_draw_value (false);
        speed.add_mark (0, Gtk.PositionType.BOTTOM, _("Default"));
        speed.value_changed.connect (() => {
            int percent = (int) speed.get_value ();
            conf_set_int ("mouse", "speed", percent);
            Apply.pointer_speed (percent);
        });
        motion.pack_start (row (_("Pointer speed"),
            _("How far the pointer travels for the same movement of the hand"),
            speed), false, false, 0);

        var natural = new Gtk.Switch ();
        natural.active = conf_get_bool ("mouse", "natural-scroll", false);
        natural.notify["active"].connect (() => {
            conf_set_bool ("mouse", "natural-scroll", natural.active);
            Apply.natural_scroll (natural.active);
        });
        motion.pack_start (row (_("Natural scrolling"),
            _("The content follows the fingers, the way a phone scrolls"),
            natural), false, false, 0);

        return page;
    }

    /* Build the pointer theme and switch to it.
     *
     * In a thread: on this machine it is four hundred images and a few
     * seconds, and a Settings window that stops answering while it
     * happens would look like the thing that just broke. The label says
     * what is going on, because a colour button that does nothing for
     * five seconds is a colour button somebody presses again. */
    private void build_pointer (string hex, Gtk.Label status,
                                Gtk.ComboBoxText size) {
        if (!FileUtils.test ("/usr/lib/kavis/gen-cursors",
                             FileTest.IS_EXECUTABLE)) {
            status.set_text (_("The pointer generator is not installed"));
            return;
        }
        string dir = Path.build_filename (Environment.get_user_data_dir (),
                                          "icons", "Kavis-Cursors-Custom");
        status.set_text (_("Building…"));
        new Thread<void*> ("kavis-cursors", () => {
            int rc = 1;
            try {
                DirUtils.create_with_parents (
                    Path.build_filename (dir, "cursors"), 0755);
                Process.spawn_sync (null,
                    { "/usr/lib/kavis/gen-cursors",
                      Path.build_filename (dir, "cursors"), hex },
                    null, SpawnFlags.SEARCH_PATH
                    | SpawnFlags.STDOUT_TO_DEV_NULL, null, null, null,
                    out rc);
                /* Without index.theme XCursor does not consider the
                 * directory a theme at all, and the setting would apply
                 * to nothing. */
                FileUtils.set_contents (
                    Path.build_filename (dir, "index.theme"),
                    "[Icon Theme]\nName=Kavis Custom\n"
                    + "Comment=Kavis cursors, chosen colour\n"
                    + "Inherits=Breeze_Light\n");
            } catch (Error e) {
                rc = 1;
            }
            bool ok = (rc == 0);
            Idle.add (() => {
                if (ok) {
                    status.set_text ("");
                    conf_set ("mouse", "pointer", "Kavis-Cursors-Custom");
                    string? id = size.get_active_id ();
                    Apply.pointer ("Kavis-Cursors-Custom",
                                   (id != null) ? int.parse (id) : 24);
                } else {
                    status.set_text (_("Could not build the pointer"));
                }
                return false;
            });
            return null;
        });
    }
}
