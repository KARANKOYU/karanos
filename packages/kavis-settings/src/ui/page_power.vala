/* Power page (item 51).
 *
 * Everything here has a real effect, which is the point of the round
 * that rewrote it: before, the four modes were four labels and the only
 * working setting was a DPMS timeout.
 *
 *   modes        → CPU governor and energy-performance preference, plus
 *                  power-profiles-daemon where it exists (powerplan.vala)
 *   screen / sleep timeouts → the panel's idle watcher, which reads the
 *                  X idle counter; separate values for battery and AC
 *                  because the right answer genuinely differs
 *   lid          → logind, through the root helper
 *   sleep now / hibernate now → logind directly
 *   low battery  → the panel warns at the chosen percentage
 *
 * The root half (governor, lid) goes through pkexec with an
 * allow_active:yes polkit action, so the local user is not asked for a
 * password on their own machine. Every write also lands in kavis.conf,
 * which is what the panel and the quick settings read.
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
            body.pack_start (timeout_row (_("Turn off screen after"),
                                          "screen_off", true), false, false, 0);
            body.pack_start (timeout_row (_("Sleep after"),
                                          "sleep_after", true), false, false, 0);
            body.pack_start (group (_("On battery")), false, false, 0);
            body.pack_start (plan_list (false), false, false, 0);
            body.pack_start (timeout_row (_("Turn off screen after"),
                                          "screen_off", false), false, false, 0);
            body.pack_start (timeout_row (_("Sleep after"),
                                          "sleep_after", false), false, false, 0);

            /* Low battery warning: the panel watches the charge and
             * shows a notification once per discharge below this. */
            body.pack_start (group (_("Battery")), false, false, 0);
            var low = new Gtk.ComboBoxText ();
            low.append ("0", _("Never"));
            foreach (int step in new int[] { 5, 10, 15, 20, 25 }) {
                low.append (step.to_string (), _("%d%%").printf (step));
            }
            low.active_id = conf_get_int ("power", "low_battery", 15)
                                .to_string ();
            low.changed.connect (() => {
                conf_set_int ("power", "low_battery",
                              int.parse (low.active_id ?? "0"));
            });
            body.pack_start (row (_("Warn me at"),
                _("A notification when the charge drops this low"), low),
                false, false, 0);

            /* Lid: a laptop-only question, so it is inside the battery
             * branch rather than shown greyed out on a desktop. */
            var lid = new Gtk.ComboBoxText ();
            lid.append ("suspend", _("Sleep"));
            lid.append ("hibernate", _("Hibernate"));
            lid.append ("lock", _("Lock the screen"));
            lid.append ("ignore", _("Do nothing"));
            lid.active_id = conf_get ("power", "lid", "suspend");
            lid.changed.connect (() => {
                string action = lid.active_id ?? "suspend";
                conf_set ("power", "lid", action);
                PowerPlan.apply_lid (action);
            });
            body.pack_start (row (_("When I close the lid"), null, lid),
                             false, false, 0);
        } else {
            /* Desktop: one list, and no lid or battery questions. */
            body.pack_start (group (_("Power mode")), false, false, 0);
            body.pack_start (plan_list (true), false, false, 0);
            body.pack_start (timeout_row (_("Turn off screen after"),
                                          "screen_off", true), false, false, 0);
            body.pack_start (timeout_row (_("Sleep after"),
                                          "sleep_after", true), false, false, 0);
        }

        /* Sleep and hibernate as actions. Hibernate is offered only
         * when it can actually work: without enough swap the machine
         * refuses at the last moment, and a button that fails silently
         * is worse than one that is not there. */
        body.pack_start (group (_("Now")), false, false, 0);
        var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var sleep_now = new Gtk.Button.with_label (_("Sleep"));
        sleep_now.clicked.connect (() => {
            Run.fire ({ "systemctl", "suspend" });
        });
        actions.pack_start (sleep_now, false, false, 0);
        if (hibernate_possible ()) {
            var hibernate_now = new Gtk.Button.with_label (_("Hibernate"));
            hibernate_now.clicked.connect (() => {
                Run.fire ({ "systemctl", "hibernate" });
            });
            actions.pack_start (hibernate_now, false, false, 0);
        }
        body.pack_start (row (_("Sleep or hibernate"),
            hibernate_possible ()
                ? _("Sleep keeps the session in memory; hibernate writes it to disk and powers off")
                : _("Hibernate needs a swap area at least as large as the memory in this machine"),
            actions), false, false, 0);

        return page;
    }

    /* logind knows whether hibernation would work: it checks for swap
     * big enough and for kernel support. Asking it is better than
     * guessing from /proc/swaps, which does not know about the rest. */
    private bool hibernate_possible () {
        string? answer = Run.capture ({ "systemctl", "hibernate",
                                        "--dry-run", "--check-inhibitors=no" });
        if (answer != null) {
            return true;
        }
        answer = Run.capture ({ "sh", "-c",
            "test -r /sys/power/state && grep -q disk /sys/power/state "
            + "&& awk 'NR>1{s+=$3} END{exit !(s>0)}' /proc/swaps && echo yes" });
        return answer != null && answer.strip () == "yes";
    }

    /* One "after N minutes" row for one power source. Both timeouts use
     * the same list, and 0 means never. */
    private Gtk.Widget timeout_row (string title, string key, bool plugged) {
        var combo = new Gtk.ComboBoxText ();
        combo.append ("0", _("Never"));
        foreach (int step in new int[] { 5, 10, 15, 30, 60 }) {
            combo.append (step.to_string (),
                          ngettext ("%d minute", "%d minutes", step)
                              .printf (step));
        }
        string full_key = key + (plugged ? "_ac" : "_battery");
        /* Default: a laptop on battery sleeps, a machine on mains does
         * not — and the screen goes dark before either. */
        int fallback = (key == "screen_off")
            ? (plugged ? 15 : 5)
            : (plugged ? 0 : 20);
        combo.active_id = conf_get_int ("power", full_key,
            conf_get_int ("power", key, fallback)).to_string ();
        combo.changed.connect (() => {
            int minutes = int.parse (combo.active_id ?? "0");
            conf_set_int ("power", full_key, minutes);
            /* The screen timeout for the CURRENT source also goes
             * straight into the X server, so the effect is immediate
             * rather than waiting for the watcher's next tick. */
            if (key == "screen_off" && plugged == Hw.on_ac ()) {
                Apply.screen_off (minutes);
            }
        });
        return row (title, null, combo);
    }

    /* Mode rows for one power source.
     *
     * THREE modes, not four: Game was the same governor and the same
     * preference as Performance — a second label for one behaviour. It
     * belongs with item 13 in Group H, where the things that would make
     * it a real mode live: a daemon holding /dev/cpu_dma_latency open
     * to pin the C-state, vm.max_map_count and split lock mitigation,
     * silencing notifications and letting the game bypass the
     * compositor. The config token is still understood, so a machine
     * that already chose Game keeps working. */
    private Gtk.Widget plan_list (bool plugged) {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        PowerPlan.Plan[] plans = {
            PowerPlan.Plan.SAVER, PowerPlan.Plan.NORMAL,
            PowerPlan.Plan.PERFORMANCE
        };
        PowerPlan.Plan active = PowerPlan.get_plan (plugged);
        Gtk.RadioButton? first = null;
        foreach (PowerPlan.Plan plan in plans) {
            PowerPlan.Plan chosen = plan;   /* closure copy */
            var radio = new Gtk.RadioButton.with_label_from_widget (
                first, plan_name (plan));
            radio.set_tooltip_text (plan_hint (plan));
            if (first == null) {
                first = radio;
            }
            radio.active = (plan == active)
                /* A stored "game" now shows as Performance, which is
                 * what it has always done. */
                || (plan == PowerPlan.Plan.PERFORMANCE
                    && active == PowerPlan.Plan.GAME);
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

    private string plan_hint (PowerPlan.Plan plan) {
        switch (plan) {
        case PowerPlan.Plan.SAVER:
            return _("Lowest clocks, longest battery life");
        case PowerPlan.Plan.PERFORMANCE:
            return _("Highest clocks, more heat and fan noise");
        default:
            return _("Clocks follow the load");
        }
    }
}
