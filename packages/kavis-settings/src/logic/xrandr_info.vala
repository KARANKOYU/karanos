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
    }

    /* Connected outputs with their mode lists. */
    public Output[] outputs () {
        Output[] result = {};
        string? text = Run.capture ({ "xrandr" });
        if (text == null) {
            return result;
        }
        string current_name = "";
        Mode[] modes = {};
        foreach (unowned string line in text.split ("\n")) {
            if (!line.has_prefix (" ") && line.contains (" connected")) {
                if (current_name != "") {
                    Output done = { current_name, modes };
                    result += done;
                }
                current_name = line.split (" ")[0];
                modes = {};
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
            Output done = { current_name, modes };
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
