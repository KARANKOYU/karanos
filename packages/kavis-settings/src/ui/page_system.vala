/* System page: About (madde 45) with a copy button. Updates get a
 * docs note only — the update system is Grup J work, no placeholder
 * page here.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget system_page (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        body.pack_start (group (_("About")), false, false, 0);
        SysInfo.Fact[] facts = SysInfo.collect ();
        var text = new StringBuilder ();
        foreach (unowned SysInfo.Fact fact in facts) {
            var value = new Gtk.Label (fact.value);
            value.set_xalign (1);
            value.set_selectable (true);
            value.set_line_wrap (true);
            value.get_style_context ().add_class ("dim-label");
            body.pack_start (row (fact.label, null, value),
                             false, false, 0);
            text.append_printf ("%s: %s\n", fact.label, fact.value);
        }

        string report = text.str;
        var copy = new Gtk.Button.with_label (_("Copy details"));
        copy.halign = Gtk.Align.START;
        copy.clicked.connect (() => {
            Gtk.Clipboard.get_default (Gdk.Display.get_default ())
                .set_text (report, -1);
        });
        body.pack_start (copy, false, false, 0);

        return page;
    }
}
