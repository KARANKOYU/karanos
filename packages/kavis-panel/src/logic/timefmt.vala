/* Locale-aware clock/date formats (4B).
 *
 * The panel clock used hardcoded "%H:%M" + "%d.%m.%Y" — wrong on an
 * EN system (Windows shows 3:04 PM and 09/02/2026 there). The C
 * library already knows the answer: nl_langinfo(T_FMT/D_FMT) follows
 * LC_TIME (AppInit.init calls setlocale). We only decide 12/24 hour
 * from t_fmt and drop the seconds Windows never shows.
 *
 * Turkish exception: glibc's tr_TR d_fmt is "%d-%m-%Y" (dashes) but
 * the Windows convention the product mirrors is dots — tr gets
 * "%d.%m.%Y" explicitly.
 */

namespace Kavis.TimeFmt {

    /* "%l:%M %p" (3:04 PM) when the locale prefers 12-hour time,
     * else "%H:%M" (15:04). */
    public string time_format () {
        unowned string t = Posix.nl_langinfo (Posix.NLItem.T_FMT);
        if ("%r" in t || "%I" in t || "%p" in t) {
            /* %-I: no padding — Windows shows "3:04 PM", not "03:04". */
            return "%-I:%M %p";
        }
        return "%H:%M";
    }

    /* Full date: locale d_fmt (EN 09/02/2026), tr forced to dots. */
    public string date_format () {
        if (locale_is_turkish ()) {
            return "%d.%m.%Y";
        }
        unowned string d = Posix.nl_langinfo (Posix.NLItem.D_FMT);
        return (d != "") ? d : "%x";
    }

    /* Short date for the vertical panel (test8 A1: the year does not
     * fit): the full format with the year and its separator removed. */
    public string short_date_format () {
        string f = date_format ()
            .replace ("%Y", "").replace ("%y", "");
        while (f.length > 0 && !f.has_suffix ("d")
               && !f.has_suffix ("m") && !f.has_suffix ("e")) {
            f = f.substring (0, f.length - 1);
        }
        while (f.length > 0 && !f.has_prefix ("%")) {
            f = f.substring (1);
        }
        return (f != "") ? f : "%d.%m";
    }

    private bool locale_is_turkish () {
        unowned string? loc =
            Intl.setlocale (LocaleCategory.TIME, null);
        return loc != null && loc.has_prefix ("tr");
    }
}
