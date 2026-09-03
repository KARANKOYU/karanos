/* W11-style CSD title bar for Kavis apps (v0.4-test1 geri bildirimi A).
 *
 * KANONİK KOPYA BURASI — build-packages.sh (prepare_sources) GTK
 * paketlerinin src ağacına kopyalar; kopyalar .gitignore'da.
 *
 * Why CSD here: the Openbox themerc cannot draw 46×32 buttons with a
 * full-height hover fill (1B kararı sınırları). GtkHeaderBar can, and
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

        /* Boş özel başlık: HeaderBar'ın ortalanmış varsayılan başlığı
         * kapanır, başlık soldaki kutudan gelir (W11 hizası). */
        var empty = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        empty.show ();
        bar.set_custom_title (empty);

        bar.show ();
        window.set_titlebar (bar);
        window.set_title (title);
        return bar;
    }
}
