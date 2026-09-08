/* Language page (feedback, 8 Sep 2026).
 *
 * The old arrangement had one dropdown for "display language" and,
 * always underneath it, a dropdown for the keyboard layout. That second
 * one is a question nobody has an answer to until they have more than
 * one layout: on a machine that speaks Turkish and types Turkish there
 * is nothing to choose, and offering the choice anyway is how a
 * settings page teaches people to ignore it.
 *
 * So this is the Windows arrangement, which exists for the same reason:
 *   * a LIST of languages you have added, in order;
 *   * the one at the top is the system language;
 *   * each one brings a keyboard layout with it;
 *   * and the "which keyboard am I typing on" chooser appears ONLY
 *     when there is more than one to choose between.
 *
 * One global layout is still the rule (decision 2F): the chooser picks
 * which of the added layouts is in use, it does not turn on per-window
 * layouts. "Another layout…" is kept as the way to reach the full xkb
 * catalogue — somebody with a Turkish system and a US keyboard is a
 * real person, and a list built only from languages would strand them.
 *
 * Storage: [keyboard] languages=tr,en — an ordered list. The first
 * entry and [keyboard] language are kept in step; language is what the
 * rest of the system already reads.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget language (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        var note = new Gtk.Label ("");
        note.set_xalign (0);
        note.set_line_wrap (true);
        note.get_style_context ().add_class ("dim-label");

        var langs_block = subsection (body, "languages",
            Catalog.sub_title ("language", "languages"));
        var list = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        langs_block.pack_start (list, false, false, 0);
        langs_block.pack_start (note, false, false, 0);

        var keyboard_block = subsection (body, "typing",
            Catalog.sub_title ("language", "typing"));

        rebuild_languages (list, note, keyboard_block);
        return page;
    }

    /* The codes the user has added, in order. Migrates a machine that
     * only ever had the single [keyboard] language key. */
    private string[] added_languages () {
        string raw = conf_get ("keyboard", "languages", "");
        string[] codes = {};
        foreach (unowned string part in raw.split (",")) {
            string code = part.strip ();
            if (code != "") {
                codes += code;
            }
        }
        if (codes.length == 0) {
            codes += conf_get ("keyboard", "language", "en");
        }
        return codes;
    }

    private void save_languages (string[] codes) {
        conf_set ("keyboard", "languages", string.joinv (",", codes));
        /* The top of the list IS the system language. Everything else
         * in the system reads [keyboard] language, so it follows. */
        if (codes.length > 0) {
            conf_set ("keyboard", "language", codes[0]);
        }
    }

    /* The layout a language brings with it. xkb layout names follow the
     * ISO code for most languages, so the code is tried first and "us"
     * is the fallback — a layout that exists everywhere and that every
     * keyboard can at least type Latin letters on. */
    private string layout_for_language (string code) {
        foreach (unowned Xkb.Entry entry in Xkb.list ()) {
            if (entry.layout == code && entry.variant == "") {
                return code;
            }
        }
        return "us";
    }

    private string language_name (Gtk.Widget probe, string code) {
        foreach (unowned Langs.Lang lang in Langs.list ()) {
            if (lang.code == code) {
                return Langs.display_name (probe, lang.code, lang.endonym);
            }
        }
        return code;
    }

    private int language_percent (string code) {
        foreach (unowned Langs.Lang lang in Langs.list ()) {
            if (lang.code == code) {
                return lang.percent;
            }
        }
        return 0;
    }

    private void rebuild_languages (Gtk.Box list, Gtk.Label note,
                                    Gtk.Box keyboard_block) {
        foreach (var child in list.get_children ()) {
            list.remove (child);
        }
        foreach (var child in keyboard_block.get_children ()) {
            keyboard_block.remove (child);
        }

        string[] codes = added_languages ();
        for (int i = 0; i < codes.length; i++) {
            string code = codes[i];
            int index = i;
            var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            /* Moving a language to the top is how the system language
             * is chosen — the same gesture Windows uses, and the
             * reason there is no separate "make this the system
             * language" button. */
            var up = new Gtk.Button.from_icon_name ("go-up-symbolic",
                                                    Gtk.IconSize.BUTTON);
            up.set_tooltip_text (_("Move up — the top language is the system language"));
            up.set_sensitive (i > 0);
            up.clicked.connect (() => {
                string[] moved = added_languages ();
                string swap = moved[index - 1];
                moved[index - 1] = moved[index];
                moved[index] = swap;
                save_languages (moved);
                apply_system_language (moved[0], note);
                rebuild_languages (list, note, keyboard_block);
            });
            controls.pack_start (up, false, false, 0);

            var remove = new Gtk.Button.from_icon_name ("list-remove-symbolic",
                                                        Gtk.IconSize.BUTTON);
            remove.set_tooltip_text (_("Remove this language"));
            /* The last one cannot go: a system with no language is not
             * a state worth being able to reach. */
            remove.set_sensitive (codes.length > 1);
            remove.clicked.connect (() => {
                string[] kept = {};
                string[] before = added_languages ();
                for (int k = 0; k < before.length; k++) {
                    if (k != index) {
                        kept += before[k];
                    }
                }
                save_languages (kept);
                apply_system_language (kept[0], note);
                rebuild_languages (list, note, keyboard_block);
            });
            controls.pack_start (remove, false, false, 0);

            string percent = "%d%%".printf (language_percent (code));
            string subtitle = (i == 0)
                ? _("System language · %s translated · keyboard %s")
                    .printf (percent, layout_for_language (code))
                : _("%s translated · keyboard %s")
                    .printf (percent, layout_for_language (code));
            list.pack_start (row (language_name (note, code), subtitle,
                                  controls), false, false, 0);
        }

        /* Add: the full list of languages, minus the ones already in. */
        var add_drop = new SearchDropdown (_("Search languages"), true);
        add_drop.add_item ("", _("Add a language"), "", false);
        foreach (unowned Langs.Lang lang in Langs.list ()) {
            bool already = false;
            foreach (unowned string code in codes) {
                if (code == lang.code) {
                    already = true;
                }
            }
            if (already) {
                continue;
            }
            add_drop.add_item (lang.code,
                Langs.display_name (note, lang.code, lang.endonym),
                "%d%%".printf (lang.percent), lang.percent == 0);
        }
        add_drop.select ("");
        add_drop.chosen.connect ((code) => {
            if (code == "") {
                return;
            }
            string[] grown = added_languages ();
            grown += code;
            save_languages (grown);
            rebuild_languages (list, note, keyboard_block);
        });
        list.pack_start (row (_("Add a language"),
            _("Adding one does not change the system language — move it to the top for that"),
            add_drop), false, false, 0);

        build_keyboard_block (keyboard_block, codes);
        list.show_all ();
        keyboard_block.show_all ();
    }

    private void apply_system_language (string code, Gtk.Label note) {
        int percent = language_percent (code);
        if (percent == 0) {
            note.label = _("This language is not translated yet; the interface will appear in English. Contribute at %s")
                .printf (CONTRIB_URL);
        } else if (percent < 100) {
            note.label = _("%d%% translated — untranslated parts appear in English")
                .printf (percent);
        } else {
            note.label = _("Applying…");
        }
        Apply.language (code, Langs.locale_of (code));
    }

    /* The "which keyboard" question, asked only when it has an answer.
     * With one language there is one layout and nothing to decide; the
     * block says which layout is in use and offers the full catalogue
     * for the person who wants a different one. */
    private void build_keyboard_block (Gtk.Box block, string[] codes) {
        string current = Xkb.make_id (conf_get ("keyboard", "layout", "tr"),
                                      conf_get ("keyboard", "variant", ""));

        /* ONE LANGUAGE, NO CHOOSER. A dropdown offering a choice
         * between one thing teaches people that this page is not worth
         * reading. What the row says instead is which keyboard is in
         * use and how to get a second one — adding a language is how,
         * because a language brings its layout with it. */
        if (codes.length < 2) {
            var single = new Gtk.Label (Xkb.describe (current));
            single.set_line_wrap (true);
            single.set_max_width_chars (28);
            single.set_xalign (1);
            single.get_style_context ().add_class ("dim-label");
            block.pack_start (row (_("Keyboard layout"),
                _("Add a second language to be able to switch between layouts — a language brings its keyboard with it"),
                single), false, false, 0);
            return;
        }

        var choice = new SearchDropdown (_("Search layouts"));
        foreach (unowned string code in codes) {
            string id = layout_for_language (code);
            choice.add_item (id, Xkb.describe (id), id, false);
        }
        /* A layout chosen from the full catalogue is not one of the
         * languages' own, and it still has to appear as the current
         * one. */
        bool listed = false;
        foreach (unowned string code in codes) {
            if (layout_for_language (code) == current) {
                listed = true;
            }
        }
        if (!listed) {
            choice.add_item (current, Xkb.describe (current), current, false);
        }
        choice.select (current);
        choice.chosen.connect ((id) => {
            string layout, variant;
            Xkb.split_id (id, out layout, out variant);
            conf_set ("keyboard", "layout", layout);
            conf_set ("keyboard", "variant", variant);
            /* The panel indicator's right-click menu offers the
             * layouts that have actually been picked; forgetting to
             * record them here would quietly empty that menu. */
            remember_layout (id);
            Apply.keyboard_layout (layout, variant);
        });
        block.pack_start (row (_("Keyboard layout"),
            _("One global layout for every window; right-click the taskbar indicator to switch between the ones you have used"),
            choice), false, false, 0);
        block.pack_start (row (_("Another layout"),
            _("Anything in the xkb catalogue, whether a language on the list uses it or not"),
            other_layout_button (block, codes)), false, false, 0);
    }

    private Gtk.Widget other_layout_button (Gtk.Box block, string[] codes) {
        var drop = new SearchDropdown (_("Search layouts"));
        foreach (unowned Xkb.Entry entry in Xkb.list ()) {
            /* The shape leads: somebody looking for their keyboard
             * knows it is a QWERTY or a Turkish F, not that it was
             * standardised in Ghana. */
            drop.add_item (entry.id, Xkb.describe (entry.id), entry.id,
                           false);
        }
        drop.select (Xkb.make_id (conf_get ("keyboard", "layout", "tr"),
                                  conf_get ("keyboard", "variant", "")));
        drop.chosen.connect ((id) => {
            string layout, variant;
            Xkb.split_id (id, out layout, out variant);
            conf_set ("keyboard", "layout", layout);
            conf_set ("keyboard", "variant", variant);
            remember_layout (id);
            Apply.keyboard_layout (layout, variant);
        });
        return drop;
    }
}
