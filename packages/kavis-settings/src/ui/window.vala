/* Settings main window (madde 9) — Windows 11 Settings layout.
 *
 * Left: 240 px sidebar with a search box on top and the icon+label
 * section list below; the selected row gets a teal left stripe and an
 * 8% white background, hover follows the panel rule (8-10% white,
 * 6 px radius). Right: the section's page inside a scroller.
 *
 * Pages are built LAZILY on first visit (the picker's
 * ensure_glyph_page pattern) — that is how the <25 MB RSS target is
 * held: opening the window costs one page, not eight.
 */

namespace Kavis.Settings {

    public class Window : Gtk.Window {

        private const string CSS = """
        .kavis-settings-sidebar {
            background-color: #121C26;
            padding: 8px 0;
        }
        .kavis-settings-sidebar list {
            background-color: transparent;
        }
        .kavis-settings-sidebar row {
            color: #E6EDF3;
        }
        .kavis-settings-sidebar row {
            border-radius: 6px;
            padding: 8px 10px;
            margin: 1px 8px;
        }
        .kavis-settings-sidebar row:hover {
            background-color: rgba(255,255,255,0.08);
        }
        .kavis-settings-sidebar row:selected {
            background-color: rgba(255,255,255,0.08);
            box-shadow: inset 3px 0 0 #2DD4BF;
        }
        .kavis-settings-content {
            background-color: #17222C;
            color: #E6EDF3;
        }
        .kavis-settings-title {
            font-size: 20px;
            font-weight: bold;
        }
        .kavis-accent-swatch {
            background-color: #2DD4BF;
            border-radius: 6px;
            min-width: 40px;
            min-height: 20px;
        }
        """;

        /* Section registry: id (stable, used by deep links and the
         * config), icon, translated title. Order = sidebar order. */
        private struct SectionInfo {
            public string id;
            public string icon;
            public string title;
        }

        private SectionInfo[] sections;
        private Gtk.ListBox sidebar;
        private Gtk.Stack stack;
        private Gtk.SearchEntry search;
        /* Which pages exist already (lazy build). */
        private GenericSet<string> built =
            new GenericSet<string> (str_hash, str_equal);

        public Window () {
            title = _("Settings");
            set_default_size (900, 620);
            window_position = Gtk.WindowPosition.CENTER;
            set_wmclass ("kavis-settings", "kavis-settings");
            icon_name = "preferences-system";

            sections = {
                { "appearance", "applications-graphics-symbolic",
                  _("Appearance") },
                { "display", "video-display-symbolic", _("Display") },
                { "sound", "audio-volume-high-symbolic", _("Sound") },
                { "keyboard", "input-keyboard-symbolic",
                  _("Keyboard & Language") },
                { "power", "battery-good-symbolic", _("Power") },
                { "network", "network-wireless-symbolic",
                  _("Network") },
                { "taskbar", "view-grid-symbolic", _("Taskbar") },
                { "system", "computer-symbolic", _("System") }
            };

            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS);
                Gtk.StyleContext.add_provider_for_screen (
                    get_screen (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-settings: css: %s", e.message);
            }

            var root = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            add (root);

            /* ---- sidebar ---- */
            var side = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            side.set_size_request (240, -1);
            side.get_style_context ()
                .add_class ("kavis-settings-sidebar");

            search = new Gtk.SearchEntry ();
            search.placeholder_text = _("Find a setting");
            search.margin = 8;
            side.pack_start (search, false, false, 0);

            sidebar = new Gtk.ListBox ();
            sidebar.selection_mode = Gtk.SelectionMode.SINGLE;
            sidebar.activate_on_single_click = true;
            foreach (unowned SectionInfo info in sections) {
                sidebar.add (make_row (info));
            }
            sidebar.row_selected.connect (on_row_selected);
            var side_scroll = new Gtk.ScrolledWindow (null, null);
            side_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            side_scroll.add (sidebar);
            side.pack_start (side_scroll, true, true, 0);
            root.pack_start (side, false, false, 0);

            /* ---- content ---- */
            stack = new Gtk.Stack ();
            stack.transition_type =
                Gtk.StackTransitionType.CROSSFADE;
            stack.transition_duration = 140;
            stack.get_style_context ()
                .add_class ("kavis-settings-content");
            root.pack_start (stack, true, true, 0);

            /* First section opens by default. */
            sidebar.select_row (sidebar.get_row_at_index (0));
        }

        private Gtk.ListBoxRow make_row (SectionInfo info) {
            var row = new Gtk.ListBoxRow ();
            row.set_data<string> ("section-id", info.id);
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.pack_start (new Gtk.Image.from_icon_name (
                info.icon, Gtk.IconSize.MENU), false, false, 0);
            var label = new Gtk.Label (info.title);
            label.set_xalign (0);
            box.pack_start (label, true, true, 0);
            row.add (box);
            return row;
        }

        private void on_row_selected (Gtk.ListBoxRow? row) {
            if (row == null) {
                return;
            }
            show_section (row.get_data<string> ("section-id"));
        }

        /* Build (once) and show one section's page. */
        private void show_section (string id) {
            if (!built.contains (id)) {
                built.add (id);
                var scroll = new Gtk.ScrolledWindow (null, null);
                scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
                scroll.add (Pages.build (id, section_title (id)));
                /* set_visible_child gösterilmemiş çocukta işlemez
                 * (bilinen tuzak) — önce show_all. */
                scroll.show_all ();
                stack.add_named (scroll, id);
            }
            stack.set_visible_child_name (id);
        }

        private string section_title (string id) {
            foreach (unowned SectionInfo info in sections) {
                if (info.id == id) {
                    return info.title;
                }
            }
            return id;
        }

        /* Deep link: select the sidebar row (which shows the page). */
        public void open_section (string id) {
            for (int i = 0; i < sections.length; i++) {
                if (sections[i].id == id) {
                    sidebar.select_row (sidebar.get_row_at_index (i));
                    return;
                }
            }
        }
    }
}
