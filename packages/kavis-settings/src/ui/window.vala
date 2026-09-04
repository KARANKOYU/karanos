/* Settings main window (madde 9) — Windows 11 Settings layout.
 *
 * Left: 240 px sidebar with a search box on top and the section list
 * below; the selected row gets a teal left stripe and an 8% white
 * background, hover follows the panel rule (8-10% white, 6 px radius).
 * Right: the section's page inside a scroller.
 *
 * Item 74 made both halves two-level:
 *
 *   * the sidebar is a TREE — a section opens to show its
 *     sub-sections, and picking one scrolls the page to that block,
 *     which is also collapsible (Pages.subsection);
 *   * the search box searches SETTINGS, not section names. Typing
 *     "light" finds the theme switch and Night light, and each result
 *     says which section and sub-section it lives in. The index is
 *     Catalog.items () — declarative, because eight of the nine pages
 *     do not exist yet at the moment the user types.
 *
 * Pages are still built LAZILY on first visit (the picker's
 * ensure_glyph_page pattern) — that is how the <25 MB RSS target is
 * held: opening the window costs one page, not nine.
 */

namespace Kavis.Settings {

    public class Window : Gtk.Window {

        private const string CSS = """
        .kavis-settings-sidebar {
            background-color: @kavis_panel;
            padding: 8px 0;
        }
        .kavis-settings-sidebar list {
            background-color: transparent;
        }
        .kavis-settings-sidebar row {
            color: @kavis_text;
        }
        .kavis-settings-sidebar row {
            border-radius: 6px;
            padding: 8px 10px;
            margin: 1px 8px;
        }
        .kavis-settings-sidebar row:hover {
            background-color: @kavis_overlay_hover;
        }
        .kavis-settings-sidebar row:selected {
            background-color: @kavis_overlay_hover;
            box-shadow: inset 3px 0 0 @kavis_teal;
        }
        .kavis-settings-content {
            background-color: @kavis_surface;
            color: @kavis_text;
        }
        .kavis-settings-title {
            font-size: 20px;
            font-weight: bold;
        }
        /* Sub-section heading (item 74): between the page title and a
           card label, so the three levels read as three levels. */
        .kavis-sub-title {
            font-size: 15px;
            font-weight: bold;
        }
        /* "Appearance › Effects" under a search result. */
        .kavis-result-where {
            font-size: 12px;
        }
        .kavis-search-empty {
            padding: 16px 12px;
        }
        /* A4: 12px inner padding, 8px between cards (the body box
           spacing in pages.vala), 1px light line on the top edge. */
        .kavis-card {
            background-color: @kavis_card;
            border: 1px solid @kavis_card_border;
            border-radius: 8px;
            box-shadow: inset 0 1px 0 @kavis_top_edge;
            padding: 12px;
        }
        /* About page disclosure header (F1): a plain button inside the
         * card — no frame of its own, the card is the visual. */
        .kavis-disclosure {
            background: none;
            border: none;
            box-shadow: none;
            padding: 0;
            min-height: 0;
        }
        .kavis-disclosure:hover label {
            color: @kavis_teal;
        }
        .kavis-key {
            background-color: @kavis_overlay_hover;
            border: 1px solid @kavis_card_border;
            border-radius: 6px;
            padding: 2px 8px;
            font-family: monospace;
            font-size: 12px;
        }
        .kavis-accent-swatch {
            background-color: @kavis_teal;
            border-radius: 6px;
            min-width: 40px;
            min-height: 20px;
        }
        """;

        /* Section registry: id (stable, used by deep links and the
         * config), icon, translated title. Order = sidebar order.
         *
         * The keywords column is gone: what a section contains is
         * Catalog.items (), which the search reads directly, so there
         * is no second list to keep in step. */
        private struct SectionInfo {
            public string id;
            public string icon;
            public string title;
        }

        /* A page that has been built: kept so a search result can be
         * scrolled to, which needs the scroller AND the page inside
         * it. */
        private class Built {
            public Gtk.ScrolledWindow scroll;
            public Gtk.Widget page;
        }

        private SectionInfo[] sections;
        private Gtk.ListBox sidebar;
        private Gtk.ListBox results;
        private Gtk.Stack side_stack;
        private Gtk.Stack stack;
        private Gtk.SearchEntry search;
        private GenericSet<string> expanded =
            new GenericSet<string> (str_hash, str_equal);
        private HashTable<string, Built> built =
            new HashTable<string, Built> (str_hash, str_equal);

        public Window () {
            title = _("Settings");
            set_default_size (900, 620);
            window_position = Gtk.WindowPosition.CENTER;
            set_wmclass ("kavis-settings", "kavis-settings");
            icon_name = "preferences-system";
            /* W11 title bar (feedback A): CSD — 46×32 buttons and the
             * hover fill cannot be done in themerc. */
            Kavis.HeaderBar.attach (this, _("Settings"),
                                    "preferences-system");

            sections = {
                { "appearance", "applications-graphics-symbolic",
                  _("Appearance") },
                { "display", "video-display-symbolic", _("Display") },
                { "sound", "audio-volume-high-symbolic", _("Sound") },
                { "keyboard", "input-keyboard-symbolic",
                  _("Keyboard & Language") },
                { "power", "battery-good-symbolic", _("Power") },
                { "network", "network-wireless-symbolic", _("Network") },
                { "taskbar", "view-grid-symbolic", _("Taskbar") },
                /* drive-harddisk-symbolic and not
                 * preferences-desktop-peripherals-symbolic: the latter
                 * is not in Adwaita, and a symbolic name with no
                 * fallback draws the broken-image icon rather than
                 * quietly picking something else. */
                { "hardware", "drive-harddisk-symbolic",
                  _("Hardware test") },
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
            search.search_changed.connect (on_search_changed);
            /* Enter opens the first result. */
            search.activate.connect (() => {
                var first = results.get_row_at_index (0);
                if (first != null) {
                    open_result (first);
                }
            });
            side.pack_start (search, false, false, 0);

            sidebar = new Gtk.ListBox ();
            sidebar.selection_mode = Gtk.SelectionMode.SINGLE;
            sidebar.activate_on_single_click = true;
            build_tree ();
            sidebar.set_filter_func (tree_visible);
            sidebar.row_activated.connect (on_tree_activated);
            var tree_scroll = new Gtk.ScrolledWindow (null, null);
            tree_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            tree_scroll.add (sidebar);

            results = new Gtk.ListBox ();
            results.selection_mode = Gtk.SelectionMode.SINGLE;
            results.activate_on_single_click = true;
            results.row_activated.connect (open_result);
            var results_scroll = new Gtk.ScrolledWindow (null, null);
            results_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            results_scroll.add (results);

            side_stack = new Gtk.Stack ();
            side_stack.add_named (tree_scroll, "tree");
            side_stack.add_named (results_scroll, "results");
            side.pack_start (side_stack, true, true, 0);
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
            open_section (sections[0].id);
        }

        /* --- the sidebar tree ----------------------------------- */

        /* Section rows with their sub-section rows underneath. Both
         * kinds live in one ListBox: a Gtk.TreeView would bring its
         * own theming and no gain, and the sub rows are only ever
         * shown or hidden. */
        private void build_tree () {
            foreach (unowned SectionInfo info in sections) {
                sidebar.add (section_row (info));
                foreach (Catalog.Sub sub in Catalog.subs ()) {
                    if (sub.section == info.id) {
                        sidebar.add (sub_row (sub));
                    }
                }
            }
        }

        private Gtk.ListBoxRow section_row (SectionInfo info) {
            var row = new Gtk.ListBoxRow ();
            row.set_data<string> ("section-id", info.id);
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.pack_start (new Gtk.Image.from_icon_name (
                info.icon, Gtk.IconSize.MENU), false, false, 0);
            var label = new Gtk.Label (info.title);
            label.set_xalign (0);
            box.pack_start (label, true, true, 0);
            var arrow = new Gtk.Image.from_icon_name (
                "pan-end-symbolic", Gtk.IconSize.MENU);
            box.pack_end (arrow, false, false, 0);
            row.set_data<Gtk.Image> ("arrow", arrow);
            row.add (box);
            return row;
        }

        private Gtk.ListBoxRow sub_row (Catalog.Sub sub) {
            var row = new Gtk.ListBoxRow ();
            row.set_data<string> ("section-id", sub.section);
            row.set_data<string> ("sub-id", sub.id);
            var label = new Gtk.Label (sub.title);
            label.set_xalign (0);
            label.margin_start = 26;
            row.add (label);
            return row;
        }

        /* Sub rows are shown only while their section is open. */
        private bool tree_visible (Gtk.ListBoxRow row) {
            string? sub = row.get_data<string> ("sub-id");
            if (sub == null) {
                return true;
            }
            return expanded.contains (
                row.get_data<string> ("section-id"));
        }

        private void on_tree_activated (Gtk.ListBoxRow row) {
            string section = row.get_data<string> ("section-id");
            string? sub = row.get_data<string> ("sub-id");
            if (sub != null) {
                show_section (section);
                go_to (section, sub);
                return;
            }
            /* A section row both opens the page and folds its
             * children out — one click, like the file manager. */
            if (expanded.contains (section)) {
                expanded.remove (section);
            } else {
                expanded.add (section);
            }
            var arrow = row.get_data<Gtk.Image> ("arrow");
            if (arrow != null) {
                arrow.set_from_icon_name (
                    expanded.contains (section)
                        ? "pan-down-symbolic" : "pan-end-symbolic",
                    Gtk.IconSize.MENU);
            }
            sidebar.invalidate_filter ();
            show_section (section);
        }

        /* --- search --------------------------------------------- */

        private void on_search_changed () {
            string needle = search.text.strip ();
            if (needle == "") {
                side_stack.set_visible_child_name ("tree");
                return;
            }
            fill_results (needle);
            side_stack.set_visible_child_name ("results");
        }

        /* Best matches first: a hit in the title beats a hit in the
         * description or the synonyms, and a plain substring beats a
         * scattered subsequence. Without the ranking "light" put Night
         * light above the theme switch on some runs and below it on
         * others, which is the kind of search people stop trusting. */
        private int score (string needle, Catalog.Item item) {
            string n = needle.down ();
            string title = item.title.down ();
            if (title.has_prefix (n)) {
                return 100;
            }
            if (title.contains (n)) {
                return 80;
            }
            if (item.words.down ().contains (n)) {
                return 60;
            }
            if (Catalog.sub_title (item.section, item.sub)
                    .down ().contains (n)) {
                return 40;
            }
            if (section_title (item.section).down ().contains (n)) {
                return 30;
            }
            if (subsequence (n, title)) {
                return 20;
            }
            return 0;
        }

        /* "anmz" → "animation speed": every letter in order, gaps
         * allowed. The forgiving half of the search. */
        private static bool subsequence (string needle, string hay) {
            int pos = 0;
            unichar c;
            for (int i = 0; needle.get_next_char (ref i, out c);) {
                int found = hay.index_of_char (c, pos);
                if (found < 0) {
                    return false;
                }
                pos = found + 1;
            }
            return true;
        }

        private void fill_results (string needle) {
            foreach (unowned Gtk.Widget child in
                     results.get_children ()) {
                results.remove (child);
            }
            int[] scores = {};
            Catalog.Item[] matched = {};
            foreach (Catalog.Item item in Catalog.items ()) {
                int s = score (needle, item);
                if (s > 0) {
                    matched += item;
                    scores += s;
                }
            }
            /* Insertion sort by score, highest first: the list is a
             * few dozen entries and the order inside one score has to
             * stay the catalogue's. */
            for (int i = 1; i < matched.length; i++) {
                var item = matched[i];
                int s = scores[i];
                int j = i - 1;
                while (j >= 0 && scores[j] < s) {
                    matched[j + 1] = matched[j];
                    scores[j + 1] = scores[j];
                    j--;
                }
                matched[j + 1] = item;
                scores[j + 1] = s;
            }
            foreach (Catalog.Item item in matched) {
                results.add (result_row (item));
            }
            if (matched.length == 0) {
                var empty = new Gtk.Label (
                    _("Nothing matches “%s”").printf (needle));
                empty.set_line_wrap (true);
                empty.set_xalign (0);
                empty.get_style_context ().add_class ("dim-label");
                empty.get_style_context ()
                     .add_class ("kavis-search-empty");
                var row = new Gtk.ListBoxRow ();
                row.selectable = false;
                row.activatable = false;
                row.add (empty);
                results.add (row);
            }
            results.show_all ();
        }

        private Gtk.ListBoxRow result_row (Catalog.Item item) {
            var row = new Gtk.ListBoxRow ();
            row.set_data<string> ("section-id", item.section);
            row.set_data<string> ("sub-id", item.sub);
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            var title_label = new Gtk.Label (item.title);
            title_label.set_xalign (0);
            title_label.set_ellipsize (Pango.EllipsizeMode.END);
            box.pack_start (title_label, false, false, 0);
            /* Where it lives — the half that makes a result useful:
             * the user learns the path, not just the answer. */
            var where = new Gtk.Label ("%s › %s".printf (
                section_title (item.section),
                Catalog.sub_title (item.section, item.sub)));
            where.set_xalign (0);
            where.set_ellipsize (Pango.EllipsizeMode.END);
            where.get_style_context ().add_class ("dim-label");
            where.get_style_context ().add_class ("kavis-result-where");
            box.pack_start (where, false, false, 0);
            row.add (box);
            return row;
        }

        private void open_result (Gtk.ListBoxRow row) {
            string? section = row.get_data<string> ("section-id");
            if (section == null) {
                return;   /* the "nothing matches" row */
            }
            show_section (section);
            go_to (section, row.get_data<string> ("sub-id"));
        }

        /* --- pages ----------------------------------------------- */

        /* Build (once) and show one section's page. */
        private void show_section (string id) {
            var have = built.lookup (id);
            if (have == null) {
                var page = Pages.build (id, section_title (id));
                var scroll = new Gtk.ScrolledWindow (null, null);
                scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
                scroll.add (page);
                /* set_visible_child does nothing on an unshown child
                 * (known pitfall) — show_all first. */
                scroll.show_all ();
                stack.add_named (scroll, id);
                have = new Built ();
                have.scroll = scroll;
                have.page = page;
                built.insert (id, have);
            }
            stack.set_visible_child_name (id);
            select_tree_row (id, null);
        }

        /* Open a sub-section and scroll the page to it. */
        private void go_to (string section, string? sub) {
            if (sub == null) {
                return;
            }
            var have = built.lookup (section);
            if (have == null) {
                return;
            }
            var target = Pages.reveal_subsection (have.page, sub);
            if (target == null) {
                return;
            }
            select_tree_row (section, sub);
            /* After a size_allocate, not before: the block has no
             * position until the page has been laid out, and a search
             * result usually arrives on a page built one line ago. */
            Idle.add (() => {
                int x, y;
                if (!target.translate_coordinates (have.page, 0, 0,
                                                   out x, out y)) {
                    return Source.REMOVE;
                }
                var adjustment = have.scroll.get_vadjustment ();
                double top = double.max (0, y - 8);
                adjustment.set_value (double.min (top,
                    adjustment.get_upper () - adjustment.get_page_size ()));
                return Source.REMOVE;
            });
        }

        /* Keep the tree in step with where the content is, so closing
         * the search box does not leave the sidebar pointing
         * somewhere else. */
        private void select_tree_row (string section, string? sub) {
            if (sub != null && !expanded.contains (section)) {
                expanded.add (section);
                sidebar.invalidate_filter ();
            }
            for (int i = 0; ; i++) {
                var row = sidebar.get_row_at_index (i);
                if (row == null) {
                    return;
                }
                if (row.get_data<string> ("section-id") != section) {
                    continue;
                }
                string? row_sub = row.get_data<string> ("sub-id");
                if ((sub == null && row_sub == null)
                    || (sub != null && row_sub == sub)) {
                    sidebar.select_row (row);
                    return;
                }
            }
        }

        private string section_title (string id) {
            foreach (unowned SectionInfo info in sections) {
                if (info.id == id) {
                    return info.title;
                }
            }
            return id;
        }

        /* Deep link (kavis-settings <section>), and the panel's
         * "Settings" items. */
        public void open_section (string id) {
            foreach (unowned SectionInfo info in sections) {
                if (info.id == id) {
                    show_section (id);
                    return;
                }
            }
        }
    }
}
