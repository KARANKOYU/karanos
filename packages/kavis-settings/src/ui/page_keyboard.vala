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
        var lang_block = subsection (body, "language",
            Catalog.sub_title ("keyboard", "language"));
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
        lang_block.pack_start (row (_("Display language"),
            _("Endonym and how much of the interface is translated"),
            lang_drop), false, false, 0);
        lang_block.pack_start (note, false, false, 0);

        /* --- Keyboard layout --- */
        var layout_block = subsection (body, "layout",
            Catalog.sub_title ("keyboard", "layout"));
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
        layout_block.pack_start (row (_("Layout"),
            _("One global layout for every window; right-click the taskbar indicator to switch between the ones you have used"),
            layout_drop), false, false, 0);

        /* --- Shortcuts (item 74) ---
         *
         * The list is the CATALOGUE, grouped, and every row can be
         * reassigned. It used to be typed out here beside the openbox
         * hook and had already drifted: it claimed Ctrl+Win+arrows
         * switched desktops when the real binding is Ctrl+Alt+arrows.
         * Nothing is hand-written any more — what is shown is what
         * openbox was given. */
        var keys_block = subsection (body, "shortcuts",
            Catalog.sub_title ("keyboard", "shortcuts"));
        fill_shortcuts (keys_block);

        return page;
    }

    /* Build (or rebuild, after a change) the shortcut list. */
    private void fill_shortcuts (Gtk.Box into) {
        foreach (unowned Gtk.Widget child in into.get_children ()) {
            into.remove (child);
        }
        var entries = Shortcuts.list ();
        if (entries.length == 0) {
            into.pack_start (row (_("Shortcuts"),
                _("The shortcut list is missing from this system"), null),
                false, false, 0);
            into.show_all ();
            return;
        }

        string current_group = "";
        bool any_override = false;
        foreach (Shortcuts.Entry entry in entries) {
            if (entry.group != current_group) {
                current_group = entry.group;
                into.pack_start (
                    group (Shortcuts.group_label (entry.group)),
                    false, false, 0);
            }
            if (Shortcuts.is_overridden (entry)) {
                any_override = true;
            }
            into.pack_start (shortcut_row (into, entry),
                             false, false, 0);
        }

        var reset_all = new Gtk.Button.with_label (
            _("Reset every shortcut"));
        reset_all.halign = Gtk.Align.START;
        reset_all.sensitive = any_override;
        reset_all.clicked.connect (() => {
            complain (into, Shortcuts.reset_all ());
            fill_shortcuts (into);
        });
        into.pack_start (reset_all, false, false, 0);
        into.show_all ();
    }

    /* One shortcut: what it does on the left, its keys and a Change
     * button on the right. The ten taskbar slots are one row and are
     * not editable — they are generated as a block. */
    private Gtk.Widget shortcut_row (Gtk.Box into,
                                     Shortcuts.Entry entry) {
        string key = Shortcuts.current_key (entry);
        var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        controls.pack_start (key_badges (Shortcuts.display_key (key)),
                             false, false, 0);
        if (entry.editable) {
            var change = new Gtk.Button.with_label (_("Change"));
            change.clicked.connect (() => {
                string? chosen = ask_for_key (into, entry);
                if (chosen != null) {
                    complain (into, Shortcuts.set_key (entry, chosen));
                    fill_shortcuts (into);
                }
            });
            controls.pack_start (change, false, false, 0);
            if (Shortcuts.is_overridden (entry)) {
                var reset = new Gtk.Button.from_icon_name (
                    "edit-undo-symbolic", Gtk.IconSize.BUTTON);
                reset.tooltip_text = _("Back to %s").printf (
                    Shortcuts.display_key (entry.key));
                reset.clicked.connect (() => {
                    complain (into,
                              Shortcuts.set_key (entry, entry.key));
                    fill_shortcuts (into);
                });
                controls.pack_start (reset, false, false, 0);
            }
        }
        return row (Shortcuts.label (entry.id),
                    Shortcuts.is_overridden (entry)
                        ? _("Changed from %s").printf (
                              Shortcuts.display_key (entry.key))
                        : null,
                    controls);
    }

    /* set-shortcuts refuses rather than leave the session with two
     * actions on one key. It should not get that far — the dialog
     * checks first — but a hand-edited kavis.conf can still bring the
     * refusal, and silence would look like the change had worked. */
    private void complain (Gtk.Widget anchor, string? message) {
        if (message == null || message == "") {
            return;
        }
        var dialog = new Gtk.MessageDialog (
            anchor.get_toplevel () as Gtk.Window,
            Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING,
            Gtk.ButtonsType.OK, "%s",
            _("The shortcut could not be applied: %s").printf (message));
        dialog.run ();
        dialog.destroy ();
    }

    /* "Win+Shift+S" → three badges. */
    private Gtk.Widget key_badges (string combo) {
        var badges = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        bool first = true;
        foreach (unowned string key in combo.split ("+")) {
            if (!first) {
                badges.pack_start (new Gtk.Label ("+"), false, false, 0);
            }
            first = false;
            var badge = new Gtk.Label (key);
            badge.get_style_context ().add_class ("kavis-key");
            badges.pack_start (badge, false, false, 0);
        }
        return badges;
    }

    /* Ask for a new combination. Returns null when the user backed
     * out, or when the key is already taken — a shortcut on two
     * actions is not a warning in openbox, it runs both, which is the
     * bug that made Alt+F4 close a window AND open the power dialog.
     *
     * The dialog keeps the keyboard to itself while it is up: without
     * a grab the combination being typed would ALSO fire the shortcut
     * it is bound to today, and pressing Win+E to reassign it would
     * open the file manager over the dialog. */
    private string? ask_for_key (Gtk.Widget anchor,
                                 Shortcuts.Entry entry) {
        var parent = anchor.get_toplevel () as Gtk.Window;
        var dialog = new Gtk.Dialog.with_buttons (
            _("Change shortcut"), parent,
            Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
            _("Cancel"), Gtk.ResponseType.CANCEL);
        var text = new Gtk.Label (
            _("Press the new combination for “%s”.")
                .printf (Shortcuts.label (entry.id)));
        text.set_line_wrap (true);
        var hint = new Gtk.Label (
            _("Esc cancels. The keys are taken as they are pressed."));
        hint.get_style_context ().add_class ("dim-label");
        hint.set_line_wrap (true);
        var box = dialog.get_content_area ();
        box.spacing = 8;
        box.margin = 16;
        box.pack_start (text, false, false, 0);
        box.pack_start (hint, false, false, 0);
        box.show_all ();

        string chosen = "";
        dialog.key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                dialog.response (Gtk.ResponseType.CANCEL);
                return true;
            }
            string binding = Shortcuts.from_event (event.keyval,
                                                   event.state);
            if (binding == "") {
                return true;   /* still holding modifiers down */
            }
            chosen = binding;
            dialog.response (Gtk.ResponseType.OK);
            return true;
        });
        dialog.map_event.connect (() => {
            var seat = Gdk.Display.get_default ().get_default_seat ();
            seat.grab (dialog.get_window (),
                       Gdk.SeatCapabilities.KEYBOARD,
                       false, null, null, null);
            return false;
        });

        int answer = dialog.run ();
        Gdk.Display.get_default ().get_default_seat ().ungrab ();
        dialog.destroy ();
        if (answer != Gtk.ResponseType.OK || chosen == "") {
            return null;
        }
        string? taken = Shortcuts.key_taken_by (entry, chosen);
        if (taken != null) {
            var clash = new Gtk.MessageDialog (parent,
                Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING,
                Gtk.ButtonsType.OK, "%s",
                _("%s is already “%s”. Change that one first.")
                    .printf (Shortcuts.display_key (chosen),
                             Shortcuts.label (taken)));
            clash.run ();
            clash.destroy ();
            return null;
        }
        return chosen;
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
