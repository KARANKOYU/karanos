/* System page: About (madde 45) with a copy button. Updates get a
 * docs note only — the update system is Grup J work, no placeholder
 * page here.
 *
 * Feedback F1: the page is no longer one flat list. The operating
 * system rows stay on top, everything else lives in a disclosure
 * section per hardware area (Processor open, the rest closed). The
 * facts themselves come from Kavis.SysInfo — the same reader the Task
 * Manager uses — and are probed on an idle callback, so opening the
 * page never waits on lspci or dmidecode.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget system_page (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        body.pack_start (group (_("About")), false, false, 0);
        foreach (unowned Kavis.SysInfo.Fact fact in Kavis.SysInfo.os_facts ()) {
            body.pack_start (row (fact.label, null, value_label (fact.value)),
                             false, false, 0);
        }

        body.pack_start (about_section (_("Processor"), "cpu", true),
                         false, false, 0);
        body.pack_start (about_section (_("Graphics"), "gpu", false),
                         false, false, 0);
        body.pack_start (about_section (_("Memory"), "memory", false),
                         false, false, 0);
        body.pack_start (about_section (_("Disk"), "disk", false),
                         false, false, 0);

        var copy = new Gtk.Button.with_label (_("Copy details"));
        copy.halign = Gtk.Align.START;
        copy.clicked.connect (() => {
            /* Re-read on click: the same groups the page shows, as one
             * plain-text block. A click can afford the probe; the page
             * build cannot. */
            Gtk.Clipboard.get_default (Gdk.Display.get_default ())
                .set_text (Kavis.SysInfo.report (Kavis.SysInfo.collect ()),
                           -1);
        });
        body.pack_start (copy, false, false, 0);

        return page;
    }

    /* Right-hand value of a fact: dim, right aligned, selectable. */
    private Gtk.Widget value_label (string text) {
        var value = new Gtk.Label (text);
        value.set_xalign (1);
        value.set_selectable (true);
        value.set_line_wrap (true);
        value.max_width_chars = 44;
        value.justify = Gtk.Justification.RIGHT;
        value.get_style_context ().add_class ("dim-label");
        return value;
    }

    /* One "label ....... value" line inside a section. */
    private Gtk.Widget detail_row (string label, string text) {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        var key = new Gtk.Label (label);
        key.set_xalign (0);
        box.pack_start (key, false, false, 0);
        box.pack_end (value_label (text), false, false, 0);
        return box;
    }

    private Kavis.SysInfo.Fact[] facts_of (string kind) {
        switch (kind) {
        case "cpu":    return Kavis.SysInfo.cpu_facts ();
        case "gpu":    return Kavis.SysInfo.gpu_facts ();
        case "memory": return Kavis.SysInfo.memory_facts ();
        case "disk":   return Kavis.SysInfo.disk_facts ();
        }
        return {};
    }

    /* Collapsible card: header (arrow + title + summary) and the fact
     * rows behind a revealer. The rows are filled on an idle so the
     * probe (lspci, dmidecode, sysfs) is off the first draw. */
    private Gtk.Widget about_section (string title, string kind,
                                      bool expanded) {
        var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        card.get_style_context ().add_class ("kavis-card");

        var arrow = new Gtk.Image.from_icon_name (
            expanded ? "pan-down-symbolic" : "pan-end-symbolic",
            Gtk.IconSize.MENU);
        var name = new Gtk.Label (title);
        name.set_xalign (0);
        /* Collapsed state still says something: the first fact (the
         * model / the total) is shown next to the title. */
        var summary = new Gtk.Label ("");
        summary.set_xalign (1);
        summary.ellipsize = Pango.EllipsizeMode.END;
        summary.get_style_context ().add_class ("dim-label");
        /* Only while closed — expanded, the same value is the first row. */
        summary.no_show_all = true;
        summary.visible = !expanded;

        var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        header_box.pack_start (arrow, false, false, 0);
        header_box.pack_start (name, false, false, 0);
        header_box.pack_end (summary, true, true, 0);

        var header = new Gtk.Button ();
        header.relief = Gtk.ReliefStyle.NONE;
        header.get_style_context ().add_class ("kavis-disclosure");
        header.add (header_box);
        card.pack_start (header, false, false, 0);

        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        content.margin_top = 12;
        content.margin_start = 26;
        var revealer = new Gtk.Revealer ();
        revealer.transition_type =
            Gtk.RevealerTransitionType.SLIDE_DOWN;
        revealer.transition_duration = 180;
        revealer.add (content);
        revealer.reveal_child = expanded;
        card.pack_start (revealer, false, false, 0);

        Idle.add (() => {
            Kavis.SysInfo.Fact[] facts = facts_of (kind);
            foreach (unowned Kavis.SysInfo.Fact fact in facts) {
                content.pack_start (detail_row (fact.label, fact.value),
                                    false, false, 0);
            }
            if (facts.length > 0) {
                summary.label = facts[0].value;
            }
            content.show_all ();
            return Source.REMOVE;
        });

        header.clicked.connect (() => {
            bool open = !revealer.reveal_child;
            revealer.reveal_child = open;
            summary.visible = !open;
            arrow.set_from_icon_name (
                open ? "pan-down-symbolic" : "pan-end-symbolic",
                Gtk.IconSize.MENU);
        });

        return card;
    }
}
