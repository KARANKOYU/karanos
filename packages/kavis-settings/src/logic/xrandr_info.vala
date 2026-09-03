/* Display modes via xrandr (madde 10).
 *
 * Only lines matching the "WxH  rate.rr*+" shape are parsed — xrandr's
 * human output shifts between versions, everything unrecognized is
 * skipped (ayarlar.md survey).
 */

namespace Kavis.Settings.XrandrInfo {

    public struct Mode {
        public int width;
        public int height;
        public double rate;
        public bool current;
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
            if (dims.length != 2) {
                continue;
            }
            int width = int.parse (dims[0]);
            int height = int.parse (dims[1]);
            if (width <= 0 || height <= 0) {
                continue;
            }
            for (int i = 1; i < fields.length; i++) {
                string token = fields[i];
                bool current = token.contains ("*");
                double rate = double.parse (
                    token.replace ("*", "").replace ("+", ""));
                if (rate <= 0) {
                    continue;
                }
                Mode mode = { width, height, rate, current };
                modes += mode;
            }
        }
        if (current_name != "") {
            Output done = { current_name, modes };
            result += done;
        }
        return result;
    }

    /* Switch mode. Caller shows the 15 s revert countdown (a wrong mode
     * can leave a black screen — ayarlar.md). */
    public void set_mode (string output, Mode mode) {
        Run.fire ({ "xrandr", "--output", output,
                    "--mode", "%dx%d".printf (mode.width, mode.height),
                    "--rate", "%.2f".printf (mode.rate) });
    }
}
