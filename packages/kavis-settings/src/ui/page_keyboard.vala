/* Keyboard & Language page (madde 34 + dil-secici.md rules).
 *
 * Language list: endonym + translation percent from the build-time
 * JSON; 100% first, then descending, 0% dimmed but selectable with a
 * one-line warning. Selection is written to kavis.conf and to
 * ~/.xsessionrc (LANG for the next session — gettext reads the
 * environment at process start; running apps keep their language).
 * Keyboard layout: ONE global layout via setxkbmap (decision 2F), but
 * the FULL xkeyboard-config catalogue to choose from (decision 7).
 *
 * F4: neither list stays open on the page. Both are collapsed
 * dropdowns that open a popover with a search box — 79 languages and
 * ~590 layouts are unusable as a permanently expanded list, and a
 * plain Gtk.ComboBoxText with 590 rows is worse.
 */

namespace Kavis.Settings.Pages {

    private const string CONTRIB_URL =
        "https://github.com/KARANKOYU/karanos";

    public Gtk.Widget keyboard (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        /* --- Language --- */
        body.pack_start (group (_("Language")), false, false, 0);
        var note = new Gtk.Label ("");
        note.set_xalign (0);
        note.set_line_wrap (true);
        note.get_style_context ().add_class ("dim-label");

        string current = conf_get ("keyboard", "language", "en");
        var lang_drop = new SearchDropdown (_("Search languages"), true);
        Langs.Lang[] langs = Langs.list ();
        foreach (unowned Langs.Lang lang in langs) {
            /* An endonym the current fonts cannot draw falls back to
             * the English name (Noto fonts arrive in group G). */
            string name = Langs.display_name (note, lang.code,
                                              lang.endonym);
            string percent = "%d%%".printf (lang.percent);
            lang_drop.add_item (lang.code, name, percent,
                                lang.percent == 0);
            if (lang.code == current) {
                lang_drop.select (lang.code);
            }
        }
        lang_drop.chosen.connect ((code) => {
            if (code == conf_get ("keyboard", "language", "en")) {
                return;
            }
            int percent = 0;
            foreach (unowned Langs.Lang lang in langs) {
                if (lang.code == code) {
                    percent = lang.percent;
                }
            }
            conf_set ("keyboard", "language", code);
            if (percent == 0) {
                note.label = _("This language is not translated yet; the interface will appear in English. Contribute at %s")
                    .printf (CONTRIB_URL);
            } else if (percent < 100) {
                note.label = _("%d%% translated — untranslated parts appear in English")
                    .printf (percent);
            } else {
                note.label = _("Applying…");
            }
            /* B6: system language — file writes, locale-gen (pkexec),
             * the panel watches the conf and restarts, a notification,
             * and Settings re-opens itself in the new language. */
            Apply.language (code, Langs.locale_of (code));
        });
        body.pack_start (row (_("Display language"),
            _("Endonym and how much of the interface is translated"),
            lang_drop), false, false, 0);
        body.pack_start (note, false, false, 0);

        /* --- Keyboard layout --- */
        body.pack_start (group (_("Keyboard layout")), false, false, 0);
        var layout_drop = new SearchDropdown (_("Search layouts"));
        foreach (unowned Xkb.Entry entry in Xkb.list ()) {
            /* The id ("fr(azerty)") is shown next to the description
             * and is searchable too: that is how people who know xkb
             * look a layout up. */
            layout_drop.add_item (entry.id, entry.description,
                                  entry.id, false);
        }
        string layout_id = Xkb.make_id (
            conf_get ("keyboard", "layout", "tr"),
            conf_get ("keyboard", "variant", ""));
        layout_drop.select (layout_id);
        layout_drop.chosen.connect ((id) => {
            string chosen_layout, chosen_variant;
            Xkb.split_id (id, out chosen_layout, out chosen_variant);
            conf_set ("keyboard", "layout", chosen_layout);
            conf_set ("keyboard", "variant", chosen_variant);
            remember_layout (id);
            Apply.keyboard_layout (chosen_layout, chosen_variant);
        });
        body.pack_start (row (_("Layout"),
            _("One global layout for every window; right-click the taskbar indicator to switch between the ones you have used"),
            layout_drop), false, false, 0);

        /* --- Shortcuts (madde 34: a list; an editing capture widget
         * is separate work — ayarlar.md survey) --- */
        /* B7: sections + key badges (W11 shortcut list). Source: rc.xml
         * (0210 hook) and the panel's own bindings. */
        body.pack_start (group (_("Shortcuts")), false, false, 0);
        body.pack_start (group (_("System")), false, false, 0);
        add_shortcut (body, "Win", _("Start menu"));
        add_shortcut (body, "Ctrl+Alt+Del", _("Security screen"));
        add_shortcut (body, "Win+V", _("Clipboard history"));
        add_shortcut (body, "Win+.", _("Emoji and more"));
        body.pack_start (group (_("Window")), false, false, 0);
        add_shortcut (body, "Alt+F4",
                      _("Close window / power dialog"));
        add_shortcut (body, "Alt+Tab", _("Switch windows"));
        add_shortcut (body, "Win+←  Win+→", _("Snap left / right"));
        add_shortcut (body, "Win+↑  Win+↓", _("Maximize / restore"));
        add_shortcut (body, "Win+Z", _("Snap layouts"));
        add_shortcut (body, "Win+D", _("Show desktop"));
        body.pack_start (group (_("Virtual desktops")), false, false, 0);
        add_shortcut (body, "Ctrl+Win+←  Ctrl+Win+→",
                      _("Previous / next desktop"));
        add_shortcut (body, "Win+Tab", _("Task view"));
        body.pack_start (group (_("Screen")), false, false, 0);
        add_shortcut (body, "PrtSc", _("Screenshot"));
        add_shortcut (body, "Win+Shift+S", _("Screenshot"));
        add_shortcut (body, "Win+Shift+C", _("Color picker"));
        body.pack_start (group (_("Apps")), false, false, 0);
        add_shortcut (body, "Win+E", _("Files"));
        add_shortcut (body, "Win+I", _("Settings"));
        add_shortcut (body, "Win+R", _("Run"));
        add_shortcut (body, "Win+1…0", _("Open pinned app"));

        return page;
    }

    /* One shortcut row: description left, each key as a badge right
     * ("Win+Shift+S" → three badges; two spaces separate alternatives). */
    private void add_shortcut (Gtk.Box body, string keys,
                               string description) {
        var badges = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        foreach (unowned string combo in keys.split ("  ")) {
            if (badges.get_children ().length () > 0) {
                badges.pack_start (new Gtk.Label ("/"), false, false, 4);
            }
            bool first = true;
            foreach (unowned string key in combo.split ("+")) {
                if (!first) {
                    badges.pack_start (new Gtk.Label ("+"),
                                       false, false, 0);
                }
                first = false;
                var badge = new Gtk.Label (key);
                badge.get_style_context ().add_class ("kavis-key");
                badges.pack_start (badge, false, false, 0);
            }
        }
        body.pack_start (row (description, null, badges),
                         false, false, 0);
    }

    /* The right-click menu of the panel indicator offers the layouts
     * the user has actually picked, so every choice is remembered here
     * ([keyboard] layouts, most recent first). */
    private void remember_layout (string id) {
        string[] ids = { id };
        foreach (unowned string old in
                 conf_get ("keyboard", "layouts", "").split (",")) {
            string trimmed = old.strip ();
            if (trimmed == "" || trimmed == id) {
                continue;
            }
            if (ids.length >= 8) {
                break;
            }
            ids += trimmed;
        }
        conf_set ("keyboard", "layouts", string.joinv (",", ids));
    }

    /* Collapsed dropdown with a search box (F4). GTK 3 has no such
     * widget: a Gtk.MenuButton shows the current choice, its popover
     * holds a search entry over a filtered Gtk.ListBox. Only the
     * selection is visible when it is closed. */
    private class SearchDropdown : Gtk.MenuButton {

        public signal void chosen (string id);

        private Gtk.Label current_label;
        private Gtk.SearchEntry search;
        private Gtk.ListBox list;
        private Gtk.Popover pop;
        private string selected_id = "";
        private bool face_shows_secondary;

        /* One row keeps its own strings — set_data would hand out a
         * pointer into an array that dies with the page builder. */
        private class Item : Gtk.ListBoxRow {
            public string id;
            public string haystack;
            public string primary;
            public string secondary;
        }

        /* face_shows_secondary: the language dropdown wants
         * "Türkçe — 100%" on the button, the layout one only the
         * description ("French (AZERTY)") — its secondary column is
         * the xkb id, useful while searching, noise on the button. */
        public SearchDropdown (string search_hint,
                               bool face_shows_secondary = false) {
            this.face_shows_secondary = face_shows_secondary;
            var face = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            current_label = new Gtk.Label ("");
            current_label.set_xalign (0);
            current_label.set_ellipsize (Pango.EllipsizeMode.END);
            current_label.set_max_width_chars (28);
            face.pack_start (current_label, true, true, 0);
            face.pack_end (new Gtk.Image.from_icon_name (
                "pan-down-symbolic", Gtk.IconSize.BUTTON),
                false, false, 0);
            add (face);
            set_size_request (260, -1);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box.margin = 8;
            /* Wide enough for the search placeholder; a popover that
             * only fits its rows squeezes the entry to its icon. */
            box.set_size_request (320, -1);
            search = new Gtk.SearchEntry ();
            search.set_placeholder_text (search_hint);
            box.pack_start (search, false, false, 0);
            list = new Gtk.ListBox ();
            list.selection_mode = Gtk.SelectionMode.SINGLE;
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_policy (Gtk.PolicyType.NEVER,
                               Gtk.PolicyType.AUTOMATIC);
            scroll.set_min_content_height (280);
            scroll.set_min_content_width (300);
            scroll.add (list);
            box.pack_start (scroll, true, true, 0);
            box.show_all ();

            pop = new Gtk.Popover (this);
            pop.add (box);
            set_popover (pop);

            list.set_filter_func ((r) => {
                string needle = search.text.strip ().down ();
                if (needle == "") {
                    return true;
                }
                return ((Item) r).haystack.contains (needle);
            });
            search.search_changed.connect (() => list.invalidate_filter ());
            /* Enter picks the first row still standing after filtering. */
            search.activate.connect (() => {
                var first = list.get_row_at_y (0);
                if (first != null) {
                    activate_row ((Item) first);
                }
            });
            list.row_activated.connect ((r) => activate_row ((Item) r));
            pop.show.connect (() => {
                search.set_text ("");
                search.grab_focus ();
            });
        }

        public void add_item (string id, string primary,
                              string? secondary, bool dim) {
            var item = new Item ();
            item.id = id;
            item.primary = primary;
            item.secondary = secondary ?? "";
            item.haystack = "%s %s %s".printf (primary, item.secondary,
                                               id).down ();
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            box.margin = 4;
            var name = new Gtk.Label (primary);
            name.set_xalign (0);
            box.pack_start (name, true, true, 0);
            if (item.secondary != "") {
                var extra = new Gtk.Label (item.secondary);
                extra.get_style_context ().add_class ("dim-label");
                box.pack_end (extra, false, false, 0);
            }
            if (dim) {
                /* 0% translated: dimmed but SELECTABLE (dil-secici.md). */
                name.set_opacity (0.5);
            }
            item.add (box);
            list.add (item);
            /* The popover ran show_all in the constructor; rows added
             * afterwards have to be shown themselves or the list opens
             * empty. */
            item.show_all ();
        }

        /* Show an id as the current choice without emitting "chosen". */
        public void select (string id) {
            foreach (unowned Gtk.Widget child in list.get_children ()) {
                var item = (Item) child;
                if (item.id == id) {
                    selected_id = id;
                    list.select_row (item);
                    current_label.set_text (face_text (item));
                    return;
                }
            }
            /* Unknown id (hand-edited conf): show it as it is. */
            current_label.set_text (id);
        }

        private string face_text (Item item) {
            if (!face_shows_secondary || item.secondary == "") {
                return item.primary;
            }
            return "%s — %s".printf (item.primary, item.secondary);
        }

        private void activate_row (Item item) {
            pop.popdown ();
            current_label.set_text (face_text (item));
            if (item.id == selected_id) {
                return;
            }
            selected_id = item.id;
            chosen (item.id);
        }
    }

}
