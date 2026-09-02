/* Sound page: output card (ALSA ~/.asoundrc), master volume (amixer),
 * system sounds toggle (kavis.conf [sounds], panel reads it live).
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget sound (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        /* Çıkış aygıtı. */
        var cards = Audio.cards ();
        var device = new Gtk.ComboBoxText ();
        foreach (unowned Audio.Card card in cards) {
            device.append (card.index.to_string (), card.name);
        }
        device.active_id = Audio.default_card ().to_string ();
        device.changed.connect (() => {
            Audio.set_default_card (int.parse (device.active_id ?? "0"));
        });
        body.pack_start (row (_("Output device"),
            _("Applies to newly started applications"), device),
            false, false, 0);

        /* Ana ses. */
        var volume = new Gtk.Scale.with_range (
            Gtk.Orientation.HORIZONTAL, 0, 100, 1);
        volume.set_size_request (200, -1);
        volume.set_value (Audio.volume ());
        volume.value_changed.connect (() => {
            Audio.set_volume ((int) volume.get_value ());
        });
        body.pack_start (row (_("Master volume"), null, volume),
                         false, false, 0);

        /* Sistem sesleri (kavis.conf [sounds] — panel canlı okur). */
        var sounds = new Gtk.Switch ();
        sounds.active = conf_get_bool ("sounds", "enabled", true);
        sounds.notify["active"].connect (() => {
            conf_set_bool ("sounds", "enabled", sounds.active);
        });
        body.pack_start (row (_("System sounds"),
            _("Device plug, notification and error sounds"), sounds),
            false, false, 0);

        return page;
    }
}
