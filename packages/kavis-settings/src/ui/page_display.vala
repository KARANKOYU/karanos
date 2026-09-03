/* Display page (madde 10): real modes from xrandr, scale via
 * xsettingsd Xft/DPI, night light via xsct. A resolution change asks
 * for confirmation with a 15 s countdown and reverts on timeout —
 * yanlış mod siyah ekran bırakır (ayarlar.md taraması).
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget display (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        var outputs = XrandrInfo.outputs ();
        foreach (unowned XrandrInfo.Output output in outputs) {
            if (outputs.length > 1) {
                body.pack_start (group (output.name), false, false, 0);
            }
            var combo = new Gtk.ComboBoxText ();
            int active_index = -1;
            for (int i = 0; i < output.modes.length; i++) {
                XrandrInfo.Mode mode = output.modes[i];
                combo.append (i.to_string (), "%d × %d — %.0f Hz"
                    .printf (mode.width, mode.height, mode.rate));
                if (mode.current) {
                    active_index = i;
                }
            }
            if (active_index >= 0) {
                combo.active_id = active_index.to_string ();
            }
            /* Kopya al: closure döngü değişkenini tutamaz (tuzak). */
            string output_name = output.name;
            XrandrInfo.Mode[] modes = output.modes;
            int previous = active_index;
            combo.changed.connect (() => {
                int chosen = int.parse (combo.active_id ?? "-1");
                if (chosen < 0 || chosen == previous) {
                    return;
                }
                XrandrInfo.set_mode (output_name, modes[chosen]);
                if (confirm_or_revert (combo.get_toplevel ()
                                       as Gtk.Window)) {
                    previous = chosen;
                } else if (previous >= 0) {
                    XrandrInfo.set_mode (output_name, modes[previous]);
                    combo.active_id = previous.to_string ();
                }
            });
            body.pack_start (row (_("Resolution and refresh rate"),
                                  null, combo), false, false, 0);
        }
        if (outputs.length == 0) {
            body.pack_start (row (_("Resolution and refresh rate"),
                _("No display information available"), null),
                false, false, 0);
        }

        /* Ölçek: Xft/DPI (xsettingsd) — GTK uygulamaları canlı alır. */
        var scale = new Gtk.ComboBoxText ();
        scale.append ("100", "%100");
        scale.append ("125", "%125");
        scale.append ("150", "%150");
        scale.append ("200", "%200");
        scale.active_id = conf_get_int ("display", "scale", 100)
                              .to_string ();
        scale.changed.connect (() => {
            int percent = int.parse (scale.active_id ?? "100");
            conf_set_int ("display", "scale", percent);
            Apply.scale (percent);
        });
        body.pack_start (row (_("Scale"),
            _("Text and interface size"), scale), false, false, 0);

        /* Parlaklık (3C): hızlı ayarlar kaydırıcısıyla AYNI veri —
         * ortak Brightness backend'i kavis.conf [display] brightness
         * yazar; donanım yoksa xrandr yazılım kipi. */
        var bright = new Gtk.Scale.with_range (
            Gtk.Orientation.HORIZONTAL, 10, 100, 5);
        bright.set_size_request (200, -1);
        bright.set_value (Brightness.percent ());
        bright.value_changed.connect (() => {
            Brightness.set_percent ((int) bright.get_value ());
        });
        body.pack_start (row (_("Brightness"),
            Brightness.hardware ()
            ? _("Brightness (backlight)")
            : _("Brightness (software — no backlight hardware)"),
            bright), false, false, 0);

        /* Gece ışığı (xsct). */
        var night = new Gtk.Switch ();
        night.active = conf_get_bool ("display", "nightlight", false);
        night.notify["active"].connect (() => {
            conf_set_bool ("display", "nightlight", night.active);
            Apply.night_light (night.active);
        });
        body.pack_start (row (_("Night light"),
            _("Warmer colors in the evening (4500K)"), night),
            false, false, 0);

        return page;
    }

    /* 15 s countdown dialog; false = revert. */
    private bool confirm_or_revert (Gtk.Window? parent) {
        var dialog = new Gtk.MessageDialog (parent,
            Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION,
            Gtk.ButtonsType.NONE,
            _("Keep these display settings?"));
        dialog.add_button (_("Revert"), Gtk.ResponseType.CANCEL);
        dialog.add_button (_("Keep"), Gtk.ResponseType.OK);
        int remaining = 15;
        dialog.secondary_text =
            _("Reverting in %d seconds").printf (remaining);
        uint timer = 0;
        timer = Timeout.add_seconds (1, () => {
            remaining--;
            if (remaining <= 0) {
                /* Kaynak kendini kaldırıyor: aşağıdaki remove geçersiz
                 * id'ye koşup GLib uyarısı basmasın. */
                timer = 0;
                dialog.response (Gtk.ResponseType.CANCEL);
                return Source.REMOVE;
            }
            dialog.secondary_text =
                _("Reverting in %d seconds").printf (remaining);
            return Source.CONTINUE;
        });
        int response = dialog.run ();
        if (timer != 0) {
            Source.remove (timer);
        }
        dialog.destroy ();
        return response == Gtk.ResponseType.OK;
    }
}
