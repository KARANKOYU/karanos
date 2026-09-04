/* Sunrise and sunset without a network or a GPS (F-Display night light).
 *
 * Night light "from sunset to sunrise" needs to know where the machine
 * is. Asking a geolocation service means a network call and a privacy
 * question on every boot, and asking the user for coordinates is a
 * question almost nobody can answer. But the timezone the user already
 * picked during installation carries coordinates: tzdata's zone1970.tab
 * lists a latitude and longitude for every zone, accurate to the city.
 * Reading that file is offline, instant, and needs no permission.
 *
 * The times come from the NOAA solar position equations. They are
 * accurate to about a minute, which is far beyond what a screen
 * temperature change needs.
 */

namespace Kavis {

    namespace Sun {

        /* Where this machine is, from its timezone. false when the
         * zone cannot be resolved (a container with no /etc/timezone,
         * a zone the table does not list). */
        public bool location (out double latitude, out double longitude) {
            latitude = 0;
            longitude = 0;
            string zone = timezone_name ();
            if (zone == "") {
                return false;
            }
            foreach (unowned string path in new string[] {
                    "/usr/share/zoneinfo/zone1970.tab",
                    "/usr/share/zoneinfo/zone.tab" }) {
                string contents;
                try {
                    FileUtils.get_contents (path, out contents);
                } catch (Error e) {
                    continue;
                }
                foreach (unowned string line in contents.split ("\n")) {
                    if (line.has_prefix ("#") || line.strip () == "") {
                        continue;
                    }
                    /* country codes <TAB> coordinates <TAB> zone name */
                    string[] fields = line.split ("\t");
                    if (fields.length < 3) {
                        continue;
                    }
                    /* zone1970.tab can list several zone names for one
                     * row only in its comment column, so an exact match
                     * on the third field is right for both files. */
                    if (fields[2].strip () != zone) {
                        continue;
                    }
                    if (parse_iso6709 (fields[1].strip (),
                                       out latitude, out longitude)) {
                        return true;
                    }
                }
            }
            return false;
        }

        private string timezone_name () {
            /* /etc/localtime is a symlink into the zoneinfo tree on a
             * systemd system; /etc/timezone is the Debian file. Either
             * answers, and both are read because a container may have
             * only one of them. */
            try {
                string link = FileUtils.read_link ("/etc/localtime");
                int at = link.index_of ("zoneinfo/");
                if (at >= 0) {
                    return link.substring (at + 9);
                }
            } catch (Error e) { }
            string contents;
            try {
                FileUtils.get_contents ("/etc/timezone", out contents);
                return contents.strip ();
            } catch (Error e) { }
            return "";
        }

        /* "+4013+00344" or "+401300+0034400" — sign, then degrees with
         * a fixed width, then minutes and optionally seconds. */
        private bool parse_iso6709 (string text, out double latitude,
                                    out double longitude) {
            latitude = 0;
            longitude = 0;
            /* The longitude's sign starts the second half. */
            int split = -1;
            for (int i = 1; i < text.length; i++) {
                if (text[i] == '+' || text[i] == '-') {
                    split = i;
                    break;
                }
            }
            if (split < 0) {
                return false;
            }
            return degrees (text.substring (0, split), 2, out latitude)
                && degrees (text.substring (split), 3, out longitude);
        }

        private bool degrees (string text, int degree_digits,
                              out double value) {
            value = 0;
            if (text.length < 1 + degree_digits + 2) {
                return false;
            }
            double sign = (text[0] == '-') ? -1 : 1;
            string body = text.substring (1);
            if (body.length < degree_digits + 2) {
                return false;
            }
            double d = double.parse (body.substring (0, degree_digits));
            double m = double.parse (body.substring (degree_digits, 2));
            double s = (body.length >= degree_digits + 4)
                ? double.parse (body.substring (degree_digits + 2, 2)) : 0;
            value = sign * (d + m / 60.0 + s / 3600.0);
            return true;
        }

        /* Sunrise and sunset for the given local day, as local times.
         * false during polar day or polar night, where neither event
         * happens and the caller has to fall back to fixed hours. */
        public bool times (DateTime day, double latitude, double longitude,
                           out DateTime sunrise, out DateTime sunset) {
            sunrise = day;
            sunset = day;
            double gamma = 2 * Math.PI / 365.0 * (day.get_day_of_year () - 1
                                                  + (12 - 12) / 24.0);
            double eqtime = 229.18 * (0.000075
                + 0.001868 * Math.cos (gamma)
                - 0.032077 * Math.sin (gamma)
                - 0.014615 * Math.cos (2 * gamma)
                - 0.040849 * Math.sin (2 * gamma));
            double decl = 0.006918
                - 0.399912 * Math.cos (gamma)
                + 0.070257 * Math.sin (gamma)
                - 0.006758 * Math.cos (2 * gamma)
                + 0.000907 * Math.sin (2 * gamma)
                - 0.002697 * Math.cos (3 * gamma)
                + 0.001480 * Math.sin (3 * gamma);
            double phi = latitude * Math.PI / 180.0;
            /* 90.833°: the sun's disc and refraction at the horizon. */
            double cos_ha = Math.cos (90.833 * Math.PI / 180.0)
                    / (Math.cos (phi) * Math.cos (decl))
                - Math.tan (phi) * Math.tan (decl);
            if (cos_ha > 1 || cos_ha < -1) {
                return false;   /* the sun does not cross the horizon */
            }
            double ha = Math.acos (cos_ha) * 180.0 / Math.PI;
            double rise_utc = 720 + 4 * (-longitude - ha) - eqtime;
            double set_utc = 720 + 4 * (-longitude + ha) - eqtime;
            sunrise = at_utc_minutes (day, rise_utc);
            sunset = at_utc_minutes (day, set_utc);
            return true;
        }

        /* Minutes after midnight UTC on that day → a local DateTime.
         * The value can fall outside 0..1440 near the date line; adding
         * it as seconds to UTC midnight handles that by itself. */
        private DateTime at_utc_minutes (DateTime day, double minutes) {
            var midnight = new DateTime.utc (day.get_year (),
                                             day.get_month (),
                                             day.get_day_of_month (),
                                             0, 0, 0);
            return midnight.add_seconds (minutes * 60).to_local ();
        }
    }
}
