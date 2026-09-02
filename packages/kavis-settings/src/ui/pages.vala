/* Section pages (madde 9). Skeleton commit: every page opens with its
 * title; the real settings land per section in the follow-up commits
 * (Görünüm 38, Ekran 10, Klavye/Dil 34, Güç 51, Ağ 52, Hakkında 45).
 */

namespace Kavis.Settings.Pages {

    /* Common page frame: 24 px margins, title on top, rows below. */
    public Gtk.Widget frame (string title, out Gtk.Box body) {
        var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        page.margin = 24;
        var heading = new Gtk.Label (title);
        heading.set_xalign (0);
        heading.get_style_context ().add_class ("kavis-settings-title");
        page.pack_start (heading, false, false, 0);
        body = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        page.pack_start (body, true, true, 0);
        return page;
    }

    /* Build one section's page by id. */
    public Gtk.Widget build (string id, string title) {
        Gtk.Box body;
        var page = frame (title, out body);
        /* İçerik commit (3)'te bölüm bölüm doluyor. */
        return page;
    }
}
