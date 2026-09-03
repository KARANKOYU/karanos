/* W11-style CSD title bar for Kavis apps (v0.4-test1 feedback A).
 *
 * THIS IS THE CANONICAL COPY — build-packages.sh (prepare_sources)
 * copies it into the GTK packages' src trees; the copies are in
 * .gitignore.
 *
 * Why CSD here: the Openbox themerc cannot draw 46×32 buttons with a
 * full-height hover fill (limits of decision 1B). GtkHeaderBar can, and
 * Tilix already ships that look — Kavis apps must match it. The
 * actual colors and 46×32 sizing live in kavis-theme's gtk.css
 * (headerbar button.titlebutton rules), so Tilix and every other CSD
 * window stays consistent automatically.
 */

namespace Kavis.HeaderBar {

    /* Attach a W11-style header bar: icon + title on the LEFT,
     * min/max/close on the right (settings.ini decoration layout;
     * set explicitly too so a stray gtk setting cannot move them).
     * Returns the bar so callers can pack extra widgets if needed. */
    public Gtk.HeaderBar attach (Gtk.Window window, string title,
                                 string icon_name) {
        var bar = new Gtk.HeaderBar ();
        bar.set_show_close_button (true);
        bar.set_decoration_layout (":minimize,maximize,close");

        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        row.pack_start (new Gtk.Image.from_icon_name (
            icon_name, Gtk.IconSize.MENU), false, false, 0);
        var label = new Gtk.Label (title);
        label.get_style_context ().add_class ("title");
        row.pack_start (label, false, false, 0);
        row.show_all ();
        bar.pack_start (row);

        /* Empty custom title: disables the HeaderBar's centered default
         * title; the title comes from the box on the left (W11 alignment). */
        var empty = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        empty.show ();
        bar.set_custom_title (empty);

        bar.show ();
        window.set_titlebar (bar);
        window.set_title (title);
        return bar;
    }
}
