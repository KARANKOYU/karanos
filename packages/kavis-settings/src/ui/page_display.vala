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

        /* Multi-monitor: the arrangement first, because everything
         * below it is per-output and only makes sense once you know
         * which screen is which. With one output there is nothing to
         * arrange, so the whole section is absent rather than showing
         * a single rectangle nobody can move. */
        if (outputs.length > 1) {
            body.pack_start (group (_("Arrangement")), false, false, 0);
            var layout = new MonitorLayout (outputs);
            body.pack_start (layout.widget (), false, false, 0);
            body.pack_start (layout.primary_row (), false, false, 0);
            body.pack_start (layout.mode_row (), false, false, 0);
        }

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
            body.pack_start (rotation_row (output), false, false, 0);
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

        /* Night light. Settings only writes kavis.conf; the panel's
         * scheduler reads it and runs xsct, so the quick toggle, the
         * schedule and this page can never disagree. */
        var night = new Gtk.Switch ();
        night.active = conf_get_bool ("display", "nightlight", false);
        body.pack_start (row (_("Night light"),
            _("Warmer colors so the screen is easier on the eyes"), night),
            false, false, 0);

        var when = new Gtk.ComboBoxText ();
        when.append ("always", _("Always on"));
        when.append ("sunset", _("Sunset to sunrise"));
        when.append ("custom", _("Custom hours"));
        when.active_id = conf_get ("display", "nightlight_schedule",
                                   "always");
        var hours = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var from = time_entry ("nightlight_from", "20:00");
        var to = time_entry ("nightlight_to", "07:00");
        hours.pack_start (new Gtk.Label (_("From")), false, false, 0);
        hours.pack_start (from, false, false, 0);
        hours.pack_start (new Gtk.Label (_("to")), false, false, 0);
        hours.pack_start (to, false, false, 0);
        var hours_row = row (_("Hours"), null, hours);

        /* The temperature is shown in kelvin because that is what the
         * number means and what every other tool calls it; the labels
         * at the ends say which way is which. */
        var warmth = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
            NightLight.MIN_TEMPERATURE, NightLight.MAX_TEMPERATURE, 100);
        warmth.set_size_request (220, -1);
        warmth.set_value (conf_get_int ("display", "nightlight_temp",
                                        NightLight.DEFAULT_TEMPERATURE));
        warmth.add_mark (NightLight.MIN_TEMPERATURE, Gtk.PositionType.BOTTOM,
                         _("Warmer"));
        warmth.add_mark (NightLight.MAX_TEMPERATURE, Gtk.PositionType.BOTTOM,
                         _("Cooler"));
        /* GTK3's Scale has no format callback; format-value is the
         * signal that does the same job. */
        warmth.format_value.connect ((value) => {
            return _("%dK").printf ((int) value);
        });
        warmth.value_changed.connect (() => {
            conf_set_int ("display", "nightlight_temp",
                          (int) warmth.get_value ());
        });
        var warmth_row = row (_("Color temperature"), null, warmth);

        var schedule_row = row (_("Schedule"), null, when);
        body.pack_start (schedule_row, false, false, 0);
        body.pack_start (hours_row, false, false, 0);
        body.pack_start (warmth_row, false, false, 0);

        /* Only what applies right now is on screen: the custom hours
         * mean nothing in the other two modes, and nothing at all when
         * night light is off.
         *
         * Applied on `map` as well as right away: the window calls
         * show_all() on the page when the section is opened, which
         * reveals every row again, and map fires after that. (Marking
         * the rows no_show_all instead would keep them hidden but also
         * leave their contents unshown when they are wanted — the row
         * would appear as an empty card.) */
        void sync_night () {
            bool on = night.active;
            string mode = when.active_id ?? "always";
            schedule_row.visible = on;
            warmth_row.visible = on;
            hours_row.visible = on && mode == "custom";
        }
        night.notify["active"].connect (() => {
            conf_set_bool ("display", "nightlight", night.active);
            sync_night ();
        });
        when.changed.connect (() => {
            conf_set ("display", "nightlight_schedule",
                      when.active_id ?? "always");
            sync_night ();
        });
        sync_night ();
        page.map.connect (() => sync_night ());

        return page;
    }

    /* A "HH:MM" field backed by one config key. An entry rather than
     * two spin buttons: typing 22:30 is fewer actions than clicking
     * eight times, and the value is validated on the way out. */
    private Gtk.Widget time_entry (string key, string fallback) {
        var entry = new Gtk.Entry ();
        entry.set_width_chars (5);
        entry.set_max_length (5);
        entry.set_text (conf_get ("display", key, fallback));
        entry.focus_out_event.connect (() => {
            string text = entry.get_text ().strip ();
            string[] parts = text.split (":");
            bool valid = parts.length == 2
                && int.parse (parts[0]) >= 0 && int.parse (parts[0]) <= 23
                && int.parse (parts[1]) >= 0 && int.parse (parts[1]) <= 59
                && parts[0].length > 0 && parts[1].length > 0;
            if (valid) {
                string clean = "%02d:%02d".printf (int.parse (parts[0]),
                                                   int.parse (parts[1]));
                entry.set_text (clean);
                conf_set ("display", key, clean);
            } else {
                /* Put back what is stored rather than keeping something
                 * the scheduler cannot read. */
                entry.set_text (conf_get ("display", key, fallback));
            }
            return false;
        });
        return entry;
    }

    /* Screen rotation. xrandr names the four positions; the labels say
     * which way the TOP of the picture goes, which is how a person
     * thinks about a screen they just turned. */
    private Gtk.Widget rotation_row (XrandrInfo.Output output) {
        var combo = new Gtk.ComboBoxText ();
        combo.append ("normal", _("Landscape"));
        combo.append ("left", _("Portrait (left)"));
        combo.append ("right", _("Portrait (right)"));
        combo.append ("inverted", _("Landscape (flipped)"));
        combo.active_id = output.rotation;
        string name = output.name;
        combo.changed.connect (() => {
            XrandrInfo.set_rotation (name, combo.active_id ?? "normal");
        });
        return row (_("Orientation"), null, combo);
    }

    /* Multi-monitor arrangement: the screens as rectangles you can
     * drag (F-Display).
     *
     * WHY A DRAWING AREA: every desktop does this the same way because
     * it is the only presentation where the answer to "which one is on
     * the left" is obvious. A list of coordinates is exact and useless.
     *
     * Dropped positions SNAP to the neighbours' edges. Two monitors a
     * few pixels apart leave a dead strip the pointer cannot cross and
     * a gap the wallpaper does not cover, and nobody can hit pixel
     * alignment by hand — so the drop lands on the nearest edge within
     * a threshold, in the widget's own scale.
     */
    private class MonitorLayout : Object {

        private const int PAD = 12;         /* margin inside the canvas */
        private const int SNAP = 24;        /* snap distance, in canvas px */

        private XrandrInfo.Output[] outputs;
        private Gtk.DrawingArea area;
        private Gtk.ComboBoxText primary_combo;
        private double scale = 0.1;
        private int drag_index = -1;
        private double drag_dx;
        private double drag_dy;
        /* Desktop coordinates while dragging; committed on release. */
        private int[] pos_x = {};
        private int[] pos_y = {};

        public MonitorLayout (XrandrInfo.Output[] outputs) {
            this.outputs = outputs;
            foreach (unowned XrandrInfo.Output o in outputs) {
                pos_x += o.x;
                pos_y += o.y;
            }
            area = new Gtk.DrawingArea ();
            area.set_size_request (-1, 180);
            area.add_events (Gdk.EventMask.BUTTON_PRESS_MASK
                             | Gdk.EventMask.BUTTON_RELEASE_MASK
                             | Gdk.EventMask.POINTER_MOTION_MASK);
            area.draw.connect (on_draw);
            area.button_press_event.connect (on_press);
            area.motion_notify_event.connect (on_motion);
            area.button_release_event.connect (on_release);

            primary_combo = new Gtk.ComboBoxText ();
            foreach (unowned XrandrInfo.Output o in outputs) {
                primary_combo.append (o.name, o.name);
                if (o.primary) {
                    primary_combo.active_id = o.name;
                }
            }
            if (primary_combo.active_id == null && outputs.length > 0) {
                primary_combo.active_id = outputs[0].name;
            }
            primary_combo.changed.connect (() => {
                string? name = primary_combo.active_id;
                if (name != null) {
                    XrandrInfo.set_primary (name);
                    area.queue_draw ();
                }
            });
        }

        public Gtk.Widget widget () {
            var frame = new Gtk.Frame (null);
            frame.add (area);
            /* The controller lives as long as the widget it drew. */
            frame.set_data<Object> ("kavis-monitor-layout", this);
            return frame;
        }

        public Gtk.Widget primary_row () {
            return row (_("Main display"),
                _("Where the taskbar and new windows go"),
                primary_combo);
        }

        public Gtk.Widget mode_row () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var mirror = new Gtk.Button.with_label (_("Mirror"));
            var extend = new Gtk.Button.with_label (_("Extend"));
            mirror.clicked.connect (() => apply_mode (true));
            extend.clicked.connect (() => apply_mode (false));
            box.pack_start (mirror, false, false, 0);
            box.pack_start (extend, false, false, 0);
            return row (_("Multiple displays"),
                _("Show the same picture everywhere, or spread the desktop across them"),
                box);
        }

        private void apply_mode (bool mirrored) {
            string main = primary_combo.active_id ?? outputs[0].name;
            string[] others = {};
            foreach (unowned XrandrInfo.Output o in outputs) {
                if (o.name != main) {
                    others += o.name;
                }
            }
            if (mirrored) {
                XrandrInfo.mirror (main, others);
            } else {
                XrandrInfo.extend (main, others);
            }
            /* xrandr has moved the screens; read the new truth back
             * instead of guessing where they landed. */
            reload ();
        }

        private void reload () {
            outputs = XrandrInfo.outputs ();
            pos_x = {};
            pos_y = {};
            foreach (unowned XrandrInfo.Output o in outputs) {
                pos_x += o.x;
                pos_y += o.y;
            }
            area.queue_draw ();
        }

        /* Desktop bounding box of all the active outputs. */
        private void bounds (out int minx, out int miny,
                             out int maxx, out int maxy) {
            minx = 0; miny = 0; maxx = 1; maxy = 1;
            bool first = true;
            for (int i = 0; i < outputs.length; i++) {
                if (!outputs[i].active) {
                    continue;
                }
                int x1 = pos_x[i], y1 = pos_y[i];
                int x2 = x1 + outputs[i].width, y2 = y1 + outputs[i].height;
                if (first) {
                    minx = x1; miny = y1; maxx = x2; maxy = y2;
                    first = false;
                    continue;
                }
                minx = int.min (minx, x1);
                miny = int.min (miny, y1);
                maxx = int.max (maxx, x2);
                maxy = int.max (maxy, y2);
            }
        }

        private bool on_draw (Cairo.Context cr) {
            int w = area.get_allocated_width ();
            int h = area.get_allocated_height ();
            unowned Gtk.StyleContext ctx = area.get_style_context ();
            Gdk.RGBA fg = ctx.get_color (Gtk.StateFlags.NORMAL);

            int minx, miny, maxx, maxy;
            bounds (out minx, out miny, out maxx, out maxy);
            double sx = (double) (w - 2 * PAD) / (maxx - minx);
            double sy = (double) (h - 2 * PAD) / (maxy - miny);
            scale = double.min (sx, sy);
            /* Centre the whole arrangement in the canvas. */
            double ox = (w - (maxx - minx) * scale) / 2 - minx * scale;
            double oy = (h - (maxy - miny) * scale) / 2 - miny * scale;

            cr.set_line_width (2);
            for (int i = 0; i < outputs.length; i++) {
                if (!outputs[i].active) {
                    continue;
                }
                double x = ox + pos_x[i] * scale;
                double y = oy + pos_y[i] * scale;
                double rw = outputs[i].width * scale;
                double rh = outputs[i].height * scale;
                bool is_primary = outputs[i].name == primary_combo.active_id;
                cr.set_source_rgba (fg.red, fg.green, fg.blue,
                                    (i == drag_index) ? 0.22 : 0.12);
                cr.rectangle (x, y, rw, rh);
                cr.fill_preserve ();
                if (is_primary) {
                    /* The main display is the teal one — the same accent
                     * that marks "active" everywhere else. */
                    cr.set_source_rgb (0.176, 0.831, 0.749);
                } else {
                    cr.set_source_rgba (fg.red, fg.green, fg.blue, 0.5);
                }
                cr.stroke ();

                cr.set_source_rgba (fg.red, fg.green, fg.blue, 0.9);
                cr.select_font_face ("sans", Cairo.FontSlant.NORMAL,
                                     Cairo.FontWeight.NORMAL);
                cr.set_font_size (12);
                Cairo.TextExtents ext;
                cr.text_extents (outputs[i].name, out ext);
                cr.move_to (x + (rw - ext.width) / 2,
                            y + (rh + ext.height) / 2);
                cr.show_text (outputs[i].name);
            }
            return true;
        }

        /* Canvas point → the output under it, topmost last. */
        private int hit (double px, double py) {
            int w = area.get_allocated_width ();
            int h = area.get_allocated_height ();
            int minx, miny, maxx, maxy;
            bounds (out minx, out miny, out maxx, out maxy);
            double ox = (w - (maxx - minx) * scale) / 2 - minx * scale;
            double oy = (h - (maxy - miny) * scale) / 2 - miny * scale;
            for (int i = outputs.length - 1; i >= 0; i--) {
                if (!outputs[i].active) {
                    continue;
                }
                double x = ox + pos_x[i] * scale;
                double y = oy + pos_y[i] * scale;
                if (px >= x && px <= x + outputs[i].width * scale
                    && py >= y && py <= y + outputs[i].height * scale) {
                    drag_dx = px - x;
                    drag_dy = py - y;
                    return i;
                }
            }
            return -1;
        }

        private bool on_press (Gdk.EventButton event) {
            drag_index = hit (event.x, event.y);
            area.queue_draw ();
            return true;
        }

        private bool on_motion (Gdk.EventMotion event) {
            if (drag_index < 0) {
                return false;
            }
            int w = area.get_allocated_width ();
            int h = area.get_allocated_height ();
            int minx, miny, maxx, maxy;
            bounds (out minx, out miny, out maxx, out maxy);
            double ox = (w - (maxx - minx) * scale) / 2 - minx * scale;
            double oy = (h - (maxy - miny) * scale) / 2 - miny * scale;
            pos_x[drag_index] = (int) ((event.x - drag_dx - ox) / scale);
            pos_y[drag_index] = (int) ((event.y - drag_dy - oy) / scale);
            area.queue_draw ();
            return true;
        }

        private bool on_release (Gdk.EventButton event) {
            if (drag_index < 0) {
                return false;
            }
            int i = drag_index;
            drag_index = -1;
            snap (i);
            XrandrInfo.set_position (outputs[i].name, pos_x[i], pos_y[i]);
            /* xrandr may refuse a position that would leave a hole; the
             * layout is read back so the picture matches the screens. */
            reload ();
            return true;
        }

        /* Pull the dragged screen onto its neighbours' edges. The
         * threshold is in canvas pixels so it feels the same however
         * far the view is zoomed out. */
        private void snap (int index) {
            int limit = (int) (SNAP / scale);
            for (int j = 0; j < outputs.length; j++) {
                if (j == index || !outputs[j].active) {
                    continue;
                }
                int left = pos_x[j], right = pos_x[j] + outputs[j].width;
                int top = pos_y[j], bottom = pos_y[j] + outputs[j].height;
                int my_right = pos_x[index] + outputs[index].width;
                int my_bottom = pos_y[index] + outputs[index].height;
                if ((my_right - left).abs () < limit) {
                    pos_x[index] = left - outputs[index].width;
                }
                if ((pos_x[index] - right).abs () < limit) {
                    pos_x[index] = right;
                }
                if ((pos_x[index] - left).abs () < limit) {
                    pos_x[index] = left;
                }
                if ((my_bottom - top).abs () < limit) {
                    pos_y[index] = top - outputs[index].height;
                }
                if ((pos_y[index] - bottom).abs () < limit) {
                    pos_y[index] = bottom;
                }
                if ((pos_y[index] - top).abs () < limit) {
                    pos_y[index] = top;
                }
            }
            /* Never negative: xrandr places the desktop from 0,0 and a
             * negative offset silently moves everything else instead. */
            pos_x[index] = int.max (0, pos_x[index]);
            pos_y[index] = int.max (0, pos_y[index]);
        }
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
