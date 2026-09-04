/* Display modes via xrandr (madde 10).
 *
 * Only lines matching the "WxH  rate.rr*+" shape are parsed — xrandr's
 * human output shifts between versions, everything unrecognized is
 * skipped (ayarlar.md survey).
 *
 * xrandr repeats a resolution once per refresh rate (and sometimes on
 * several lines), which made the raw list long and full of duplicates
 * (VM feedback F2). group() collapses it: one Resolution per WxH with
 * its rates collected, so the page can show a short resolution list
 * and a separate refresh-rate list.
 */

namespace Kavis.Settings.XrandrInfo {

    public struct Mode {
        public int width;
        public int height;
        public double rate;      /* 0 when xrandr reports none (Xvfb, VMs) */
        public bool current;     /* xrandr "*" */
        public bool preferred;   /* xrandr "+" — the native mode */
    }

    /* One WxH with every refresh rate xrandr lists for it. */
    public class Resolution : Object {
        public int width;
        public int height;
        public double[] rates;      /* descending, de-duplicated, > 0 */
        public bool current;
        public bool preferred;
        public double current_rate; /* 0 when not current or unknown */

        public int pixels () {
            return width * height;
        }

        /* Combo id / xrandr --mode argument. */
        public string key () {
            return "%dx%d".printf (width, height);
        }
    }

    public struct Output {
        public string name;
        public Mode[] modes;
        /* F-Display: the layout half of the same xrandr line. A
         * connected output that is switched off has no geometry, which
         * is how `active` is told apart from `connected`. */
        public bool primary;
        public bool active;
        public int x;
        public int y;
        public int width;    /* as placed on the desktop, after rotation */
        public int height;
        public string rotation;   /* normal | left | right | inverted */
    }

    /* xrandr names the rotations; the UI shows them translated. */
    public const string[] ROTATIONS = { "normal", "left", "right", "inverted" };

    /* Connected outputs with their mode lists. */
    public Output[] outputs () {
        Output[] result = {};
        string? text = Run.capture ({ "xrandr" });
        if (text == null) {
            return result;
        }
        string current_name = "";
        Mode[] modes = {};
        bool primary = false;
        bool active = false;
        int px = 0, py = 0, pw = 0, ph = 0;
        string rotation = "normal";
        foreach (unowned string line in text.split ("\n")) {
            if (!line.has_prefix (" ") && line.contains (" connected")) {
                if (current_name != "") {
                    Output done = { current_name, modes, primary, active,
                                    px, py, pw, ph, rotation };
                    result += done;
                }
                current_name = line.split (" ")[0];
                modes = {};
                primary = line.contains (" primary ");
                rotation = "normal";
                active = false;
                px = py = pw = ph = 0;
                /* "HDMI-1 connected primary 1920x1080+0+0 left (normal
                 * left inverted right x axis y axis) 509mm x 286mm" —
                 * the geometry token and, when the screen is turned, a
                 * bare rotation word before the parenthesis. */
                foreach (unowned string token in line.split (" ")) {
                    if (token.contains ("+") && token.contains ("x")
                        && !active) {
                        string[] parts = token.split ("+");
                        string[] dims = parts[0].split ("x");
                        if (parts.length == 3 && dims.length == 2
                            && digits (dims[0]) && digits (dims[1])
                            && digits (parts[1]) && digits (parts[2])) {
                            pw = int.parse (dims[0]);
                            ph = int.parse (dims[1]);
                            px = int.parse (parts[1]);
                            py = int.parse (parts[2]);
                            active = true;
                        }
                        continue;
                    }
                    if (token == "left" || token == "right"
                        || token == "inverted") {
                        rotation = token;
                    }
                    if (token.has_prefix ("(")) {
                        break;   /* the capability list starts here */
                    }
                }
                continue;
            }
            if (current_name == "" || !line.has_prefix ("   ")) {
                continue;
            }
            /* "   1920x1080     60.00*+  59.94" */
            string[] fields = {};
            foreach (unowned string f in line.strip ().split_set (" \t")) {
                if (f != "") {
                    fields += f;
                }
            }
            if (fields.length < 2 || !fields[0].contains ("x")) {
                continue;
            }
            string[] dims = fields[0].split ("x");
            /* "1920x1080i" and friends: an interlaced mode cannot be
             * named by WxH alone, so it is skipped rather than merged
             * into the progressive mode of the same size. */
            if (dims.length != 2 || !digits (dims[0])
                || !digits (dims[1])) {
                continue;
            }
            int width = int.parse (dims[0]);
            int height = int.parse (dims[1]);
            if (width <= 0 || height <= 0) {
                continue;
            }
            int first = modes.length;
            int last = -1;
            for (int i = 1; i < fields.length; i++) {
                string token = fields[i];
                bool current = token.contains ("*");
                bool preferred = token.contains ("+");
                string number = token.replace ("*", "").replace ("+", "");
                if (number == "") {
                    /* xrandr prints the markers in fixed columns: on a
                     * preferred-but-not-current mode the "+" lands in a
                     * field of its own, so it belongs to the rate before
                     * it. */
                    if (last >= 0) {
                        if (current) {
                            modes[last].current = true;
                        }
                        if (preferred) {
                            modes[last].preferred = true;
                        }
                    }
                    continue;
                }
                double rate = double.parse (number);
                if (rate <= 0) {
                    continue;
                }
                Mode mode = { width, height, rate, current, preferred };
                modes += mode;
                last = modes.length - 1;
            }
            if (modes.length == first) {
                /* No usable rate on the line (Xvfb and some VM drivers
                 * print "0.00"): keep the resolution anyway, rate
                 * unknown — otherwise the page has nothing to show. */
                bool current = line.contains ("*");
                bool preferred = line.contains ("+");
                Mode mode = { width, height, 0, current, preferred };
                modes += mode;
            }
        }
        if (current_name != "") {
            Output done = { current_name, modes, primary, active,
                            px, py, pw, ph, rotation };
            result += done;
        }
        return result;
    }

    /* Collapse a mode list into one entry per resolution, largest
     * first; each entry carries its rates in descending order. */
    public Resolution[] group (Mode[] modes) {
        Resolution[] list = {};
        foreach (unowned Mode mode in modes) {
            bool known = false;
            foreach (unowned Resolution seen in list) {
                if (seen.width == mode.width
                    && seen.height == mode.height) {
                    known = true;
                    break;
                }
            }
            if (known) {
                continue;
            }
            var res = new Resolution ();
            res.width = mode.width;
            res.height = mode.height;
            res.rates = {};
            double[] rates = {};
            foreach (unowned Mode other in modes) {
                if (other.width != mode.width
                    || other.height != mode.height) {
                    continue;
                }
                if (other.current) {
                    res.current = true;
                    res.current_rate = other.rate;
                }
                if (other.preferred) {
                    res.preferred = true;
                }
                if (other.rate <= 0) {
                    continue;
                }
                /* Drivers list rates that differ in the second decimal
                 * (59.99 / 59.95 / 59.94): they would read as the same
                 * "60 Hz" line twice, so the label decides what counts
                 * as a duplicate. The rate actually in use wins the
                 * slot — the page matches it back exactly. */
                string text = rate_number (other.rate);
                int found = -1;
                for (int i = 0; i < rates.length; i++) {
                    if (rate_number (rates[i]) == text) {
                        found = i;
                        break;
                    }
                }
                if (found < 0) {
                    rates += other.rate;
                } else if (other.current) {
                    rates[found] = other.rate;
                }
            }
            /* Few rates per resolution (< 10): a plain swap sort, no
             * allocation. */
            for (int i = 0; i < rates.length; i++) {
                for (int j = i + 1; j < rates.length; j++) {
                    if (rates[j] > rates[i]) {
                        double swap = rates[i];
                        rates[i] = rates[j];
                        rates[j] = swap;
                    }
                }
            }
            res.rates = rates;
            list += res;
        }
        for (int i = 0; i < list.length; i++) {
            for (int j = i + 1; j < list.length; j++) {
                if (list[j].pixels () > list[i].pixels ()) {
                    Resolution swap = list[i];
                    list[i] = list[j];
                    list[j] = swap;
                }
            }
        }
        return list;
    }

    /* Rate as it is shown: the decimal only when it says something
     * (60, 59.9). Also the duplicate key inside group (). */
    public string rate_number (double rate) {
        int tenths = (int) (rate * 10 + 0.5);
        if (tenths % 10 == 0) {
            return "%d".printf (tenths / 10);
        }
        return "%.1f".printf (tenths / 10.0);
    }

    /* Only digits — no interlace suffix, no stray characters. */
    private bool digits (string text) {
        if (text.length == 0) {
            return false;
        }
        for (int i = 0; i < text.length; i++) {
            if (text[i] < '0' || text[i] > '9') {
                return false;
            }
        }
        return true;
    }

    /* Two xrandr rates are the same mode when they agree to 0.01 Hz. */
    public bool same_rate (double a, double b) {
        double diff = a - b;
        return diff > -0.01 && diff < 0.01;
    }

    /* Switch mode. Caller shows the 15 s revert countdown (a wrong mode
     * can leave a black screen — ayarlar.md). rate <= 0 means the
     * output reports no rate: let xrandr pick. */
    public void set_mode (string output, Mode mode) {
        set_resolution (output, mode.width, mode.height, mode.rate);
    }

    /* --- layout (F-Display) ---------------------------------------
     *
     * Every one of these is a single xrandr call. They are separate
     * functions rather than one "apply the whole layout" because a
     * failed call must leave the rest of the desktop as it was: xrandr
     * applies what it can and reports the rest, and a half-applied
     * multi-monitor layout is how people end up with no picture. */

    public void set_primary (string output) {
        Run.fire ({ "xrandr", "--output", output, "--primary" });
    }

    /* Position on the desktop, top-left corner, in pixels. */
    public void set_position (string output, int x, int y) {
        Run.fire ({ "xrandr", "--output", output, "--pos",
                    "%dx%d".printf (x, y) });
    }

    public void set_rotation (string output, string rotation) {
        Run.fire ({ "xrandr", "--output", output, "--rotate", rotation });
    }

    public void set_active (string output, bool on) {
        Run.fire ({ "xrandr", "--output", output, on ? "--auto" : "--off" });
    }

    /* Mirror: every other output shows the same picture as the primary
     * one, at the primary one's position. --same-as is xrandr's own
     * word for it and it does the scaling itself when the panels do not
     * share a resolution. */
    public void mirror (string primary_output, string[] others) {
        foreach (unowned string other in others) {
            Run.fire ({ "xrandr", "--output", other, "--auto",
                        "--same-as", primary_output });
        }
    }

    /* Extend: lay the others out in a row to the right of the primary
     * one, in the order given. */
    public void extend (string primary_output, string[] others) {
        string previous = primary_output;
        foreach (unowned string other in others) {
            Run.fire ({ "xrandr", "--output", other, "--auto",
                        "--right-of", previous });
            previous = other;
        }
    }

    public void set_resolution (string output, int width, int height,
                                double rate) {
        string mode = "%dx%d".printf (width, height);
        if (rate <= 0) {
            Run.fire ({ "xrandr", "--output", output, "--mode", mode });
            return;
        }
        Run.fire ({ "xrandr", "--output", output, "--mode", mode,
                    "--rate", "%.2f".printf (rate) });
    }
}
