/* Power page (madde 51). Battery machines get two sections (plugged /
 * on battery), each with the four modes; desktops get one list. Data
 * is kavis.conf [power] via the shared PowerPlan backend — the quick
 * settings Battery panel reads the SAME keys, no second writer logic.
 * Screen-off timeout applies via DPMS. Lid/suspend timers need logind
 * (root) — deliberately deferred, logged under ONAY BEKLEYEN.
 */

namespace Kavis.Settings.Pages {

    public Gtk.Widget power (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        bool battery = Hw.has_battery ();
        if (battery) {
            body.pack_start (group (_("When plugged in")),
                             false, false, 0);
            body.pack_start (plan_list (true), false, false, 0);
            body.pack_start (group (_("On battery")), false, false, 0);
            body.pack_start (plan_list (false), false, false, 0);
        } else {
            /* Masaüstü: tek liste (pil yok — madde 51). */
            body.pack_start (group (_("Power mode")), false, false, 0);
            body.pack_start (plan_list (true), false, false, 0);
        }

        /* Ekran kapatma süresi (DPMS — oturum düzeyi, gerçek). */
        var screen_off = new Gtk.ComboBoxText ();
        screen_off.append ("0", _("Never"));
        screen_off.append ("5", _("5 minutes"));
        screen_off.append ("10", _("10 minutes"));
        screen_off.append ("30", _("30 minutes"));
        screen_off.active_id =
            conf_get_int ("power", "screen_off", 0).to_string ();
        screen_off.changed.connect (() => {
            int minutes = int.parse (screen_off.active_id ?? "0");
            conf_set_int ("power", "screen_off", minutes);
            Apply.screen_off (minutes);
        });
        body.pack_start (row (_("Turn off screen after"), null,
                              screen_off), false, false, 0);

        return page;
    }

    /* Four radio-style mode rows for one power source. */
    private Gtk.Widget plan_list (bool plugged) {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        PowerPlan.Plan[] plans = {
            PowerPlan.Plan.SAVER, PowerPlan.Plan.NORMAL,
            PowerPlan.Plan.PERFORMANCE, PowerPlan.Plan.GAME
        };
        PowerPlan.Plan active = PowerPlan.get_plan (plugged);
        Gtk.RadioButton? first = null;
        foreach (PowerPlan.Plan plan in plans) {
            PowerPlan.Plan chosen = plan;   /* closure kopyası */
            var radio = new Gtk.RadioButton.with_label_from_widget (
                first, plan_name (plan));
            if (first == null) {
                first = radio;
            }
            radio.active = (plan == active);
            radio.toggled.connect (() => {
                if (radio.active) {
                    PowerPlan.set_plan (plugged, chosen, Hw.on_ac ());
                }
            });
            box.pack_start (radio, false, false, 0);
        }
        return box;
    }

    private string plan_name (PowerPlan.Plan plan) {
        switch (plan) {
        case PowerPlan.Plan.SAVER:       return _("Efficiency");
        case PowerPlan.Plan.PERFORMANCE: return _("Performance");
        case PowerPlan.Plan.GAME:        return _("Game");
        default:                         return _("Balanced");
        }
    }
}
