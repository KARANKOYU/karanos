/* Display page (madde 10): real modes from xrandr, scale via
 * xsettingsd Xft/DPI, night light via xsct. A resolution change asks
 * for confirmation with a 15 s countdown and reverts on timeout —
 * a wrong mode leaves a black screen (ayarlar.md survey).
 *
 * F2 (VM feedback): the single "resolution — rate" list was long and
 * showed the same WxH once per rate. Now there are two combos: a short
 * Resolution list (native + the common modes the screen supports +
 * "Custom…", which opens the full xrandr list in a dialog) and a
 * Refresh rate list rebuilt for the selected resolution.
 */

namespace Kavis.Settings.Pages {

    /* The short list, largest first. Only the ones the output really
     * supports are offered; the native mode is always in. */
    private const int[] COMMON_MODES = {
        3840, 2160,
        2560, 1440,
        1920, 1080,
        1600, 900,
        1366, 768,
        1280, 720
    };

    private const string CUSTOM_ID = "custom";

    public Gtk.Widget display (string title) {
        Gtk.Box body;
        var page = frame (title, out body);

        var outputs = XrandrInfo.outputs ();
        bool any = false;
        foreach (unowned XrandrInfo.Output output in outputs) {
            var modes = XrandrInfo.group (output.modes);
            if (modes.length == 0) {
                continue;
            }
            if (outputs.length > 1) {
                body.pack_start (group (output.name), false, false, 0);
            }
            var rows = new OutputRows (output.name, modes);
            body.pack_start (rows.resolution_row (), false, false, 0);
            body.pack_start (rows.rate_row (), false, false, 0);
            any = true;
        }
        if (!any) {
            body.pack_start (row (_("Resolution"),
                _("No display information available"), null),
                false, false, 0);
        }

        /* Scale: Xft/DPI (xsettingsd) — GTK apps pick it up live. */
        /* F3: the percentage sign follows the locale — "125%" in
         * English, "%125" in Turkish — so the label is a translatable
         * format string, not a hardcoded prefix. */
        var scale = new Gtk.ComboBoxText ();
        int[] steps = { 100, 125, 150, 175, 200 };
        foreach (int step in steps) {
            scale.append (step.to_string (), _("%d%%").printf (step));
        }
        scale.active_id = conf_get_int ("display", "scale", 100)
                              .to_string ();
        scale.changed.connect (() => {
            int percent = int.parse (scale.active_id ?? "100");
            conf_set_int ("display", "scale", percent);
            Apply.scale (percent);
        });
        body.pack_start (row (_("Scale"),
            _("Text and interface size"), scale), false, false, 0);

        /* Brightness (3C): the SAME data as the quick-settings slider —
         * the shared Brightness backend writes kavis.conf [display]
         * brightness; without hardware, xrandr software mode. */
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

        /* Night light (xsct). */
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

    /* One output's two combos plus the state they share (which mode is
     * on screen right now, so a rejected change can be undone). The
     * object is kept alive by the resolution row it builds. */
    private class OutputRows : Object {

        private string output;
        private XrandrInfo.Resolution[] all;    /* every resolution */
        private XrandrInfo.Resolution[] shown;  /* combo entries */
        private Gtk.ComboBoxText res_combo;
        private Gtk.ComboBoxText rate_combo;
        /* Guards the combos while they are refilled in code: without it
         * every append would fire "changed" and re-apply the mode. */
        private bool updating;
        private XrandrInfo.Resolution applied;
        private double applied_rate;

        public OutputRows (string output, XrandrInfo.Resolution[] modes) {
            this.output = output;
            this.all = modes;
            this.res_combo = new Gtk.ComboBoxText ();
            this.rate_combo = new Gtk.ComboBoxText ();

            /* Native first, then the supported common modes (largest
             * first). The mode in use is always offered too — a screen
             * may be running something the list does not cover. */
            var native = native_mode ();
            shown = { native };
            foreach (unowned XrandrInfo.Resolution res in all) {
                if (res == native) {
                    continue;
                }
                if (res.current || is_common (res)) {
                    shown += res;
                }
            }
            fill_resolutions ();

            applied = current_mode ();
            applied_rate = applied.current_rate;
            select (applied, applied_rate);
            /* current_rate is 0 when xrandr reports no rate: take what
             * the rate combo settled on instead. */
            applied_rate = selected_rate ();

            res_combo.changed.connect (on_resolution_changed);
            rate_combo.changed.connect (on_rate_changed);
        }

        public Gtk.Widget resolution_row () {
            var widget = row (_("Resolution"), null, res_combo);
            /* Tie this controller's lifetime to the row. */
            widget.set_data<Object> ("kavis-display-rows", this);
            return widget;
        }

        public Gtk.Widget rate_row () {
            return row (_("Refresh rate"), null, rate_combo);
        }

        /* xrandr marks the native mode with "+". Some VM drivers mark
         * nothing: fall back to the mode in use, then to the largest. */
        private XrandrInfo.Resolution native_mode () {
            foreach (unowned XrandrInfo.Resolution res in all) {
                if (res.preferred) {
                    return res;
                }
            }
            foreach (unowned XrandrInfo.Resolution res in all) {
                if (res.current) {
                    return res;
                }
            }
            return all[0];
        }

        private XrandrInfo.Resolution current_mode () {
            foreach (unowned XrandrInfo.Resolution res in all) {
                if (res.current) {
                    return res;
                }
            }
            return native_mode ();
        }

        private bool is_common (XrandrInfo.Resolution res) {
            for (int i = 0; i + 1 < COMMON_MODES.length; i += 2) {
                if (res.width == COMMON_MODES[i]
                    && res.height == COMMON_MODES[i + 1]) {
                    return true;
                }
            }
            return false;
        }

        private XrandrInfo.Resolution? by_key (string? key) {
            if (key == null) {
                return null;
            }
            foreach (unowned XrandrInfo.Resolution res in all) {
                if (res.key () == key) {
                    return res;
                }
            }
            return null;
        }

        private string label_of (XrandrInfo.Resolution res) {
            string size = "%d × %d".printf (res.width, res.height);
            return (res == native_mode ())
                ? _("%s (native)").printf (size) : size;
        }

        /* Rates come from xrandr with two decimals; the shown form
         * (60 Hz, 59.9 Hz) is what group () de-duplicated on. */
        private string rate_label (double rate) {
            return _("%s Hz").printf (XrandrInfo.rate_number (rate));
        }

        private void fill_resolutions () {
            bool was = updating;
            updating = true;
            string? keep = res_combo.active_id;
            res_combo.remove_all ();
            foreach (unowned XrandrInfo.Resolution res in shown) {
                res_combo.append (res.key (), label_of (res));
            }
            res_combo.append (CUSTOM_ID, _("Custom…"));
            if (keep != null) {
                res_combo.active_id = keep;
            }
            updating = was;
        }

        /* Refill the rate combo for one resolution; keep the rate in
         * use when the new resolution still has it, else the highest. */
        private void fill_rates (XrandrInfo.Resolution res,
                                 double preferred) {
            bool was = updating;
            updating = true;
            rate_combo.remove_all ();
            if (res.rates.length == 0) {
                /* Xvfb and some VM drivers report no rate at all. */
                rate_combo.append ("0", _("Unknown"));
                rate_combo.active_id = "0";
                rate_combo.sensitive = false;
                updating = was;
                return;
            }
            rate_combo.sensitive = true;
            string chosen = "%.2f".printf (res.rates[0]);
            foreach (double rate in res.rates) {
                string id = "%.2f".printf (rate);
                rate_combo.append (id, rate_label (rate));
                if (XrandrInfo.same_rate (rate, preferred)) {
                    chosen = id;
                }
            }
            rate_combo.active_id = chosen;
            updating = was;
        }

        /* Show a mode in both combos without applying anything. */
        private void select (XrandrInfo.Resolution res, double rate) {
            bool was = updating;
            updating = true;
            if (by_key_shown (res.key ()) == null) {
                shown += res;
                sort_shown ();
                fill_resolutions ();
            }
            res_combo.active_id = res.key ();
            fill_rates (res, rate);
            updating = was;
        }

        private XrandrInfo.Resolution? by_key_shown (string key) {
            foreach (unowned XrandrInfo.Resolution res in shown) {
                if (res.key () == key) {
                    return res;
                }
            }
            return null;
        }

        /* Native stays on top, the rest largest first. */
        private void sort_shown () {
            for (int i = 1; i < shown.length; i++) {
                for (int j = i + 1; j < shown.length; j++) {
                    if (shown[j].pixels () > shown[i].pixels ()) {
                        XrandrInfo.Resolution swap = shown[i];
                        shown[i] = shown[j];
                        shown[j] = swap;
                    }
                }
            }
        }

        private double selected_rate () {
            string? id = rate_combo.active_id;
            return (id == null) ? 0 : double.parse (id);
        }

        private void on_resolution_changed () {
            if (updating) {
                return;
            }
            string? id = res_combo.active_id;
            if (id == null) {
                return;
            }
            if (id == CUSTOM_ID) {
                open_custom ();
                return;
            }
            var res = by_key (id);
            if (res == null || res == applied) {
                return;
            }
            fill_rates (res, applied_rate);
            apply (res, selected_rate ());
        }

        private void on_rate_changed () {
            if (updating) {
                return;
            }
            var res = by_key (res_combo.active_id);
            double rate = selected_rate ();
            if (res == null
                || (res == applied
                    && XrandrInfo.same_rate (rate, applied_rate))) {
                return;
            }
            apply (res, rate);
        }

        /* Switch, then ask: on "Revert" (or the 15 s timeout) the mode
         * that was on screen before comes back. */
        private void apply (XrandrInfo.Resolution res, double rate) {
            XrandrInfo.set_resolution (output, res.width, res.height,
                                       rate);
            if (confirm_or_revert (res_combo.get_toplevel ()
                                   as Gtk.Window)) {
                applied = res;
                applied_rate = rate;
                return;
            }
            XrandrInfo.set_resolution (output, applied.width,
                                       applied.height, applied_rate);
            select (applied, applied_rate);
        }

        /* "Custom…": every mode xrandr reports, in a modal list. */
        private void open_custom () {
            var parent = res_combo.get_toplevel () as Gtk.Window;
            var dialog = new Gtk.Dialog.with_buttons (
                _("All resolutions"), parent,
                Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                _("Cancel"), Gtk.ResponseType.CANCEL,
                _("Apply"), Gtk.ResponseType.OK);
            dialog.set_default_size (360, 420);
            var content = dialog.get_content_area ();
            content.spacing = 8;
            content.margin = 16;

            var list = new Gtk.ListBox ();
            list.selection_mode = Gtk.SelectionMode.SINGLE;
            Gtk.ListBoxRow? active_row = null;
            foreach (unowned XrandrInfo.Resolution res in all) {
                if (res.rates.length == 0) {
                    active_row = custom_row (list, res, 0, active_row);
                    continue;
                }
                foreach (double rate in res.rates) {
                    active_row = custom_row (list, res, rate, active_row);
                }
            }
            if (active_row != null) {
                list.select_row (active_row);
            }
            list.row_activated.connect (() => {
                dialog.response (Gtk.ResponseType.OK);
            });
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_min_content_height (280);
            scroll.add (list);
            content.pack_start (scroll, true, true, 0);
            content.show_all ();

            int response = dialog.run ();
            var chosen = list.get_selected_row ();
            dialog.destroy ();

            if (response != Gtk.ResponseType.OK || chosen == null) {
                select (applied, applied_rate);
                return;
            }
            var res = by_key (chosen.get_data<string> ("mode-key"));
            double rate = double.parse (
                chosen.get_data<string> ("mode-rate"));
            if (res == null) {
                select (applied, applied_rate);
                return;
            }
            select (res, rate);
            if (res == applied && XrandrInfo.same_rate (rate,
                                                        applied_rate)) {
                return;
            }
            apply (res, rate);
        }

        /* One "1920 × 1080   60 Hz" line; returns the row to preselect. */
        private Gtk.ListBoxRow? custom_row (Gtk.ListBox list,
                                            XrandrInfo.Resolution res,
                                            double rate,
                                            Gtk.ListBoxRow? active) {
            var line = new Gtk.ListBoxRow ();
            line.set_data<string> ("mode-key", res.key ());
            line.set_data<string> ("mode-rate", "%.2f".printf (rate));
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            box.margin = 4;
            var size = new Gtk.Label ("%d × %d".printf (res.width,
                                                        res.height));
            size.set_xalign (0);
            box.pack_start (size, true, true, 0);
            if (rate > 0) {
                var hz = new Gtk.Label (rate_label (rate));
                hz.get_style_context ().add_class ("dim-label");
                box.pack_end (hz, false, false, 0);
            }
            line.add (box);
            list.add (line);
            if (res == applied
                && XrandrInfo.same_rate (rate, applied_rate)) {
                return line;
            }
            return active;
        }
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
                /* The source removes itself: keep the remove below from
                 * running on a stale id and printing a GLib warning. */
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
