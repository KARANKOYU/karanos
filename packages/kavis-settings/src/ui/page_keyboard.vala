/* Keyboard & Language page (madde 34 + dil-secici.md rules).
 *
 * Language list: endonym + translation percent from the build-time
 * JSON; 100% first, then descending, 0% dimmed but selectable with a
 * one-line warning. Selection is written to kavis.conf and to
 * ~/.xsessionrc (LANG for the next session — gettext reads the
 * environment at process start; running apps keep their language).
 * Keyboard layout: ONE global layout via setxkbmap (decision 2F).
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

        var list = new Gtk.ListBox ();
        list.selection_mode = Gtk.SelectionMode.SINGLE;
        string current = conf_get ("keyboard", "language", "en");
        Langs.Lang[] langs = Langs.list ();
        Gtk.ListBoxRow? current_row = null;
        foreach (unowned Langs.Lang lang in langs) {
            var lrow = new Gtk.ListBoxRow ();
            lrow.set_data<string> ("lang-code", lang.code);
            lrow.set_data<int> ("lang-percent", lang.percent);
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            box.margin = 4;
            var name = new Gtk.Label (lang.endonym);
            name.set_xalign (0);
            box.pack_start (name, true, true, 0);
            var pct = new Gtk.Label ("%%%d".printf (lang.percent));
            pct.get_style_context ().add_class ("dim-label");
            box.pack_end (pct, false, false, 0);
            if (lang.percent == 0) {
                /* Dimmed but SELECTABLE (dil-secici.md). */
                name.set_opacity (0.5);
            }
            lrow.add (box);
            list.add (lrow);
            if (lang.code == current) {
                current_row = lrow;
            }
        }
        if (current_row != null) {
            list.select_row (current_row);
        }
        list.row_selected.connect ((lrow) => {
            if (lrow == null) {
                return;
            }
            string code = lrow.get_data<string> ("lang-code");
            int percent = lrow.get_data<int> ("lang-percent");
            if (code == conf_get ("keyboard", "language", "en")) {
                return;
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
        var list_scroll = new Gtk.ScrolledWindow (null, null);
        list_scroll.set_min_content_height (220);
        list_scroll.add (list);
        body.pack_start (list_scroll, false, false, 0);
        body.pack_start (note, false, false, 0);

        /* --- Keyboard layout --- */
        body.pack_start (group (_("Keyboard layout")), false, false, 0);
        var layout = new Gtk.ComboBoxText ();
        string[,] layouts = {
            { "tr", "Türkçe Q" }, { "us", "English (US)" },
            { "de", "Deutsch" }, { "fr", "Français" },
            { "gb", "English (UK)" }, { "es", "Español" },
            { "ru", "Русский" }, { "ar", "العربية" }
        };
        for (int i = 0; i < layouts.length[0]; i++) {
            layout.append (layouts[i, 0], layouts[i, 1]);
        }
        layout.active_id = conf_get ("keyboard", "layout", "tr");
        layout.changed.connect (() => {
            string chosen = layout.active_id ?? "tr";
            conf_set ("keyboard", "layout", chosen);
            Apply.keyboard_layout (chosen);
        });
        body.pack_start (row (_("Layout"),
            _("One global layout for every window"), layout),
            false, false, 0);

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

}
