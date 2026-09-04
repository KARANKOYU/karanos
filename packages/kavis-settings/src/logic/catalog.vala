/* The settings index (item 74): what exists, where it lives, and the
 * words a person might look for it under.
 *
 * WHY A SEPARATE TABLE. Pages are built lazily — opening the window
 * costs one page, not nine, and that is how the memory budget is kept.
 * So at the moment the user types into the search box, eight of the
 * nine pages do not exist and cannot be asked what is in them. The
 * index has to be declarative.
 *
 * The obvious risk is drift: a row renamed in a page and not here. The
 * titles below are the SAME msgids the pages use, and
 * tools/check-config.sh fails the push when a title in this table no
 * longer appears in its section's source file — which is exactly the
 * drift that had already happened between the openbox hook and the
 * hand-written shortcut list.
 *
 * SYNONYMS are what makes the search worth having. "light" has to find
 * the theme switch as well as Night light; "wifi" and "wireless" are
 * the same question; nobody looks for "Scale" by typing "scale".
 */

namespace Kavis.Settings.Catalog {

    /* A sub-section: the second level of the sidebar and the anchor a
     * search result scrolls to. */
    public struct Sub {
        public string section;
        public string id;
        public string title;
    }

    /* One setting, as the search sees it. */
    public struct Item {
        public string section;
        public string sub;
        public string title;      /* the row's own label */
        public string words;      /* description + synonyms, searched */
    }

    public Sub[] subs () {
        return {
            { "appearance", "theme",       _("Theme and color") },
            { "appearance", "effects",     _("Effects") },
            { "appearance", "wallpaper",   _("Wallpaper") },

            { "display",    "screen",      _("Screen") },
            { "display",    "arrangement", _("Arrangement") },
            { "display",    "nightlight",  _("Night light") },

            { "sound",      "output",      _("Output") },
            { "sound",      "system",      _("System sounds") },

            { "keyboard",   "language",    _("Language") },
            { "keyboard",   "layout",      _("Keyboard layout") },
            { "keyboard",   "shortcuts",   _("Shortcuts") },

            { "power",      "mode",        _("Power mode") },
            { "power",      "timeouts",    _("Screen and sleep") },
            { "power",      "battery",     _("Battery") },
            { "power",      "now",         _("Now") },

            { "network",    "wifi",        "Wi-Fi" },
            { "network",    "wired",       _("Wired") },
            { "network",    "vpn",         _("VPN") },
            { "network",    "dns",         _("DNS privacy") },

            { "taskbar",    "layout",      _("Layout") },
            { "taskbar",    "pinned",      _("Pinned apps") },

            { "hardware",   "tests",       _("Tests") },

            { "system",     "about",       _("About") },
            { "system",     "selftest",    _("Self test") }
        };
    }

    public Item[] items () {
        return {
            /* --- Appearance ------------------------------------- */
            { "appearance", "theme", _("Theme"),
              _("Dark or light, the whole desktop") + " dark light night day" },
            { "appearance", "theme", _("Accent color"),
              _("The teal of the brand") + " accent colour teal" },
            { "appearance", "effects", _("Corner roundness"),
              _("How round window corners are") + " corners rounded radius sharp" },
            { "appearance", "effects", _("Animation speed"),
              _("How fast windows open and close") + " animation motion speed fast slow off" },
            { "appearance", "effects", _("Popup animation"),
              _("How the panel's popups appear") + " popup menu slide grow fade" },
            { "appearance", "effects", _("Transparency effects"),
              _("Blur behind the taskbar and menus") + " transparency blur acrylic opacity" },
            { "appearance", "wallpaper", _("Wallpaper"),
              _("The desktop background") + " wallpaper background picture desktop image" },

            /* --- Display ---------------------------------------- */
            { "display", "screen", _("Resolution"),
              _("How many pixels the screen shows") + " resolution pixels size 1080 4k" },
            { "display", "screen", _("Refresh rate"),
              _("How many times a second the screen redraws") + " refresh hz rate hertz" },
            { "display", "screen", _("Scale"),
              _("How large everything is drawn") + " scale zoom dpi size text bigger smaller" },
            { "display", "screen", _("Orientation"),
              _("Rotate the screen") + " rotate rotation portrait landscape flip" },
            { "display", "screen", _("Brightness"),
              _("How bright the screen is") + " brightness backlight dim" },
            { "display", "arrangement", _("Main display"),
              _("Which screen the taskbar is on") + " primary main monitor" },
            { "display", "arrangement", _("Multiple displays"),
              _("Mirror or extend") + " mirror extend duplicate second monitor projector" },
            { "display", "nightlight", _("Night light"),
              _("Warmer colors after sunset") + " night light blue warm eye sunset" },
            { "display", "nightlight", _("Color temperature"),
              _("How warm the night colors are") + " temperature kelvin warm" },
            { "display", "nightlight", _("Schedule"),
              _("Sunset to sunrise, or hours you choose") + " schedule time sunset sunrise" },

            /* --- Sound ------------------------------------------ */
            { "sound", "output", _("Output device"),
              _("Where sound comes out") + " speaker headphones output device audio" },
            { "sound", "output", _("Master volume"),
              _("How loud everything is") + " volume loud quiet mute audio" },
            { "sound", "system", _("System sounds"),
              _("The sounds the desktop itself makes") + " sounds beep notification startup" },

            /* --- Keyboard & Language ---------------------------- */
            { "keyboard", "language", _("Display language"),
              _("The language of the interface") + " language locale translation english turkish" },
            { "keyboard", "layout", _("Layout"),
              _("Which letters the keys type") + " layout keyboard qwerty azerty q f" },
            { "keyboard", "shortcuts", _("Shortcuts"),
              _("Every key combination, and how to change one") + " shortcut hotkey keybinding key combination fn reassign" },

            /* --- Power ------------------------------------------ */
            { "power", "mode", _("Power mode"),
              _("Efficiency, balanced or performance") + " power mode performance efficiency battery cpu governor" },
            { "power", "timeouts", _("Lock the screen after"),
              _("Idle time before the screen locks") + " lock idle timeout screensaver" },
            { "power", "timeouts", _("Turn off screen after"),
              _("Idle time before the screen goes dark") + " screen off blank idle timeout" },
            { "power", "timeouts", _("Sleep after"),
              _("Idle time before the machine sleeps") + " sleep suspend idle timeout" },
            { "power", "battery", _("Warn me at"),
              _("A notification when the charge drops this low") + " battery low warning percent" },
            { "power", "battery", _("When I close the lid"),
              _("What closing the lid does") + " lid close laptop suspend" },
            { "power", "now", _("Sleep or hibernate"),
              _("Sleep or hibernate right now") + " sleep hibernate suspend shutdown now" },

            /* --- Network ---------------------------------------- */
            { "network", "wifi", "Wi-Fi",
              _("Turn wireless on or off") + " wifi wireless wlan radio" },
            { "network", "wifi", _("Available networks"),
              _("Networks in range") + " wifi networks scan connect ssid" },
            { "network", "wifi", _("Wi-Fi actions"),
              _("Saved networks and the hotspot") + " forget saved hotspot tether share" },
            { "network", "wired", _("Wired"),
              _("The cable connection, and manual IP") + " ethernet cable wired ip dhcp static gateway" },
            { "network", "vpn", _("VPN"),
              _("Import and use a VPN profile") + " vpn wireguard openvpn tunnel" },
            { "network", "dns", _("Encrypted DNS"),
              _("DNS over TLS, and which resolver") + " dns encrypted tls doh privacy cloudflare quad9 resolver" },

            /* --- Taskbar ---------------------------------------- */
            { "taskbar", "layout", _("Position"),
              _("Which edge the taskbar is on") + " taskbar position bottom top left right edge" },
            { "taskbar", "layout", _("Size"),
              _("How tall the taskbar is") + " taskbar size height small large" },
            { "taskbar", "layout", _("Alignment"),
              _("Centred or to the left") + " align center left icons" },
            { "taskbar", "layout", _("Automatically hide the taskbar"),
              _("The taskbar gets out of the way") + " autohide hide taskbar" },
            { "taskbar", "pinned", _("Pinned apps"),
              _("Which apps sit on the taskbar") + " pin pinned apps shortcuts taskbar" },

            /* --- Hardware test ---------------------------------- */
            { "hardware", "tests", _("Hardware test"),
              _("Nine checks: does this machine work") + " test hardware diagnostics check keyboard mouse camera microphone disk memory smart" },

            /* --- System ----------------------------------------- */
            { "system", "about", _("About"),
              _("What this machine is") + " about system info specs processor cpu graphics gpu memory ram disk version" },
            { "system", "selftest", _("Automatic interface test"),
              _("Kavis tests its own interface and writes a report") + " selftest test report diagnose" }
        };
    }

    /* Title of one sub-section, for the "Section › Sub" line under a
     * search result. */
    public string sub_title (string section, string sub) {
        foreach (Sub entry in subs ()) {
            if (entry.section == section && entry.id == sub) {
                return entry.title;
            }
        }
        return sub;
    }
}
