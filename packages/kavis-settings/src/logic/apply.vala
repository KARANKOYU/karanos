/* Applying settings to the live session (madde 9).
 *
 * Theme/scale go through xsettingsd (write its conf + SIGHUP — GTK
 * apps pick both up without restarting). Wallpaper through xwallpaper,
 * night light through xsct, compositor knobs by writing a user copy of
 * picom's config and restarting picom (picom has no live reload).
 * Every value is ALSO stored in kavis.conf by the calling page; this
 * file only touches the session.
 */

namespace Kavis.Settings.Apply {

    private string xsettings_path () {
        return Path.build_filename (Environment.get_user_config_dir (),
                                    "xsettingsd", "xsettingsd.conf");
    }

    /* Rewrite one xsettingsd key, keep the rest, HUP the daemon. */
    private void xsettings_set (string key, string value) {
        string path = xsettings_path ();
        string contents = "";
        try {
            FileUtils.get_contents (path, out contents);
        } catch (Error e) { }
        var lines = new StringBuilder ();
        bool replaced = false;
        foreach (unowned string line in contents.split ("\n")) {
            if (line.strip () == "") {
                continue;
            }
            if (line.has_prefix (key + " ")) {
                lines.append_printf ("%s %s\n", key, value);
                replaced = true;
            } else {
                lines.append (line);
                lines.append_c ('\n');
            }
        }
        if (!replaced) {
            lines.append_printf ("%s %s\n", key, value);
        }
        DirUtils.create_with_parents (Path.get_dirname (path), 0755);
        try {
            FileUtils.set_contents (path, lines.str);
        } catch (Error e) {
            warning ("kavis-settings: could not write xsettingsd.conf: %s",
                     e.message);
            return;
        }
        Run.fire ({ "pkill", "-HUP", "-x", "xsettingsd" });
    }

    /* theme_id: "dark" | "light" | "system". System falls back to the
     * distro default (dark) — there is no OS light/dark source yet. */
    public void theme (string theme_id) {
        string name = (theme_id == "light") ? "Kavis-Light" : "Kavis";
        xsettings_set ("Net/ThemeName", "\"%s\"".printf (name));
        openbox_theme (name);
        /* Panel/OSD/menus watch kavis.conf (Theme.install) — nothing
         * more to do here; the page already wrote the conf. */
    }

    /* Openbox reads only rc.xml: ensure a user copy exists (system
     * copy is the hook-processed /etc/xdg one), swap the theme name,
     * reconfigure live. */
    private void openbox_theme (string name) {
        string user_rc = Path.build_filename (
            Environment.get_user_config_dir (), "openbox", "rc.xml");
        string contents;
        try {
            FileUtils.get_contents (user_rc, out contents);
        } catch (Error e) {
            try {
                FileUtils.get_contents ("/etc/xdg/openbox/rc.xml",
                                        out contents);
            } catch (Error e2) {
                warning ("kavis-settings: rc.xml missing: %s", e2.message);
                return;
            }
        }
        try {
            /* The first <name> in the <theme> block is the theme name
             * (same assumption as the 0200 hook). */
            var re = new Regex ("(<theme>\\s*<name>)[^<]*(</name>)",
                                RegexCompileFlags.DOTALL);
            contents = re.replace (contents, -1, 0,
                                   "\\1" + name + "\\2");
        } catch (RegexError e) {
            return;
        }
        DirUtils.create_with_parents (Path.get_dirname (user_rc), 0755);
        try {
            FileUtils.set_contents (user_rc, contents);
        } catch (Error e) {
            warning ("kavis-settings: could not write rc.xml: %s", e.message);
            return;
        }
        Run.fire ({ "openbox", "--reconfigure" });
    }

    /* ~/.xsessionrc is shared by the language and the scale settings,
     * so neither may rewrite the whole file. Everything Kavis owns
     * lives between two markers; lines outside them are kept. */
    private const string ENV_BEGIN = "# --- Kavis settings (do not edit) ---";
    private const string ENV_END = "# --- end Kavis settings ---";

    private void session_env_set (string[] assignments) {
        string path = Path.build_filename (Environment.get_home_dir (),
                                           ".xsessionrc");
        string contents = "";
        try {
            FileUtils.get_contents (path, out contents);
        } catch (Error e) { }
        var kept = new StringBuilder ();
        var mine = new HashTable<string, string> (str_hash, str_equal);
        string[] order = {};
        bool inside = false;
        foreach (unowned string line in contents.split ("\n")) {
            if (line.strip () == ENV_BEGIN) {
                inside = true;
                continue;
            }
            if (line.strip () == ENV_END) {
                inside = false;
                continue;
            }
            if (inside) {
                /* "export NAME=value" — remember what is already set. */
                string body = line.strip ();
                if (body.has_prefix ("export ")) {
                    body = body.substring (7);
                }
                int eq = body.index_of ("=");
                if (eq > 0) {
                    string key = body.substring (0, eq);
                    if (mine.lookup (key) == null) {
                        order += key;
                    }
                    mine.insert (key, body.substring (eq + 1));
                }
                continue;
            }
            if (line.strip () != "") {
                kept.append (line);
                kept.append_c ('\n');
            }
        }
        foreach (unowned string a in assignments) {
            int eq = a.index_of ("=");
            if (eq > 0) {
                string key = a.substring (0, eq);
                if (mine.lookup (key) == null) {
                    order += key;
                }
                mine.insert (key, a.substring (eq + 1));
            }
        }
        var text = new StringBuilder ();
        text.append (kept.str);
        text.append (ENV_BEGIN);
        text.append_c ('\n');
        foreach (unowned string key in order) {
            text.append_printf ("export %s=%s\n", key, mine.lookup (key));
        }
        text.append (ENV_END);
        text.append_c ('\n');
        try {
            FileUtils.set_contents (path, text.str);
        } catch (Error e) {
            warning ("kavis-settings: could not write ~/.xsessionrc: %s",
                     e.message);
        }
    }

    /* System language (B6). Order matters: files first (every Kavis
     * process reads ~/.config/kavis/locale in AppInit, the panel
     * restarts on the kavis.conf change), then the root part through
     * pkexec (/etc/default/locale + locale-gen — takes a few seconds
     * on first use of a language), a notification, and finally this
     * process re-executes itself so Settings speaks the new language. */
    public void language (string code, string locale) {
        string dir = Path.build_filename (
            Environment.get_user_config_dir (), "kavis");
        DirUtils.create_with_parents (dir, 0755);
        try {
            FileUtils.set_contents (Path.build_filename (dir, "locale"),
                "LANG=%s\nLANGUAGE=%s\n".printf (locale, code));
            /* Debian's Xsession sources ~/.xsessionrc: in the next
             * session EVERY process under X sees the same language. */
            FileUtils.set_contents (
                Path.build_filename (Environment.get_home_dir (),
                                     ".xsessionrc"),
                "# Written by Kavis Settings > Language.\nexport LANG=%s\nexport LANGUAGE=%s\n"
                    .printf (locale, code));
        } catch (Error e) {
            warning ("kavis-settings: could not write language files: %s",
                     e.message);
        }
        /* The root part runs in the background; notification when done. */
        Run.fire ({ "sh", "-c",
            "pkexec /usr/lib/kavis/set-locale '" + locale + "'; "
            + "gdbus call --session --dest org.freedesktop.Notifications "
            + "--object-path /org/freedesktop/Notifications "
            + "--method org.freedesktop.Notifications.Notify "
            + "kavis-settings 0 preferences-desktop-locale "
            + "\"" + _("Language changed") + "\" "
            + "\"" + _("Sign out and back in for the change to take full effect.") + "\" "
            + "'[]' '{}' 8000 >/dev/null 2>&1" });
        /* Re-open itself in the new language (on the keyboard section). */
        Environment.set_variable ("LANG", locale, true);
        Environment.set_variable ("LANGUAGE", code, true);
        Posix.execvp ("kavis-settings", { "kavis-settings", "keyboard" });
    }

    /* percent: 100/125/150/200 → Xft DPI (xsettingsd wants it ×1024). */
    /* Scale (feedback F3). Two mechanisms, the same split GNOME uses:
     * the WINDOW scale is an integer (GTK can only draw at 1x or 2x),
     * the rest is text DPI. Feeding the whole factor into Xft/DPI alone
     * made 125% look enormous while icons and paddings stayed put, so
     * the layout drifted. Values are in 1024ths, as the XSETTINGS spec
     * requires. Non-GTK apps (Qt: Kate) read environment variables, so
     * the same factor is written to the Kavis block of ~/.xsessionrc
     * for the next session — X has no way to change their scale live. */
    public void scale (int percent) {
        int window_factor = percent >= 200 ? 2 : 1;
        int total_dpi = 96 * percent / 100;
        int unscaled_dpi = total_dpi / window_factor;
        xsettings_set ("Gdk/WindowScalingFactor", window_factor.to_string ());
        xsettings_set ("Gdk/UnscaledDPI", (unscaled_dpi * 1024).to_string ());
        xsettings_set ("Xft/DPI", (total_dpi * 1024).to_string ());
        session_env_set ({
            "GDK_SCALE=%d".printf (window_factor),
            "GDK_DPI_SCALE=%.3f".printf (
                (double) percent / 100.0 / window_factor),
            "QT_SCALE_FACTOR=%.3f".printf ((double) percent / 100.0)
        });
    }

    /* Night light: xsct is on the ISO (madde 10). 6500K = neutral. */
    public void night_light (bool on) {
        Run.fire ({ "xsct", on ? "4500" : "6500" });
    }

    public void wallpaper (string path) {
        Run.fire ({ "xwallpaper", "--zoom", path });
    }

    /* Compositor knobs (madde 38): write ~/.config/kavis/picom.conf
     * from the system template with corner radius and animation speed
     * substituted, then restart picom (autostart prefers the user
     * copy). anim_factor: 0 = off, else duration multiplier ×100.
     * popup (C6): "slide" | "grow" | "fade" | "none" — animation of
     * the panel's own popups, written as a picom window rule between
     * the popup-animation-begin/-sonu markers; the slide direction
     * follows the taskbar position ("bottom" → slides up). */
    public void picom (int radius, int anim_factor, string popup,
                       string position) {
        string template;
        try {
            FileUtils.get_contents ("/etc/xdg/picom-kavis.conf",
                                    out template);
        } catch (Error e) {
            warning ("kavis-settings: picom template missing: %s", e.message);
            return;
        }
        try {
            var re = new Regex ("corner-radius = [0-9]+;");
            template = re.replace (template, -1, 0,
                "corner-radius = %d;".printf (radius));
        } catch (RegexError e) { }
        /* The popup rule is written first so the duration multiplier
         * applies to it as well. */
        int rb = template.index_of ("# popup-animation-begin");
        int re_ = template.index_of ("# popup-animation-end");
        if (rb >= 0 && re_ > rb) {
            template = template.substring (0, rb)
                + "# popup-animation-begin\n"
                + popup_rule (anim_factor == 0 ? "none" : popup, position)
                + "  " + template.substring (re_);
        }
        if (anim_factor == 0) {
            /* Animations off: replace the block with an empty list. */
            int start = template.index_of ("animations = (");
            if (start >= 0) {
                int end = template.index_of (");", start);
                if (end >= 0) {
                    template = template.substring (0, start)
                        + "animations = ("
                        + template.substring (end);
                }
            }
        } else {
            /* tasarim-dili.md base durations: open 0.18, close 0.12 —
             * scaled by the multiplier. */
            try {
                var re = new Regex ("duration = 0\\.18;");
                template = re.replace (template, -1, 0,
                    "duration = %.2f;".printf (0.18 * anim_factor / 100.0));
                re = new Regex ("duration = 0\\.12;");
                template = re.replace (template, -1, 0,
                    "duration = %.2f;".printf (0.12 * anim_factor / 100.0));
            } catch (RegexError e) { }
        }
        string user_conf = Path.build_filename (
            Environment.get_user_config_dir (), "kavis", "picom.conf");
        DirUtils.create_with_parents (
            Path.get_dirname (user_conf), 0755);
        try {
            FileUtils.set_contents (user_conf, template);
        } catch (Error e) {
            warning ("kavis-settings: could not write picom.conf: %s",
                     e.message);
            return;
        }
        /* B3: live apply. D-Bus opts_set does NOT cover corner_radius
         * (picom dbus.c: only fade/vsync/unredir), so the documented
         * path is SIGUSR1: picom restarts itself, the same process
         * re-reads the conf — no 300 ms black frame since the process
         * never dies. Called only when the slider is released. If picom
         * is not running at all (disabled in a VM) it is started with
         * the user copy. */
        /* Debug round (3 Sep): SIGUSR1 re-reads the file picom was
         * STARTED with. If the session began without a user copy, picom
         * is running with the /etc/xdg template and the signal changes
         * nothing (seen in a VM). In that case it is restarted once with
         * the user copy (~300 ms black frame, once per session); later
         * changes go through the signal again. */
        Run.fire ({ "sh", "-c",
            "pid=$(pgrep -x picom | head -1); "
            + "if [ -n \"$pid\" ] && tr '\\0' ' ' < /proc/$pid/cmdline | grep -qF '"
            + user_conf + "'; then kill -USR1 \"$pid\"; else "
            + "pkill -x picom; sleep 0.3; "
            + "picom --backend xrender --config '" + user_conf
            + "' -b; fi" });
    }

    /* The picom window rule for panel popups (C6). Durations are the
     * design-language bases (0.18 / 0.12) — the caller scales them
     * together with the window animations. */
    private string popup_rule (string popup, string position) {
        string open_dir, close_dir;
        switch (position) {
        case "top":   open_dir = "down";  close_dir = "up";    break;
        case "left":  open_dir = "right"; close_dir = "left";  break;
        case "right": open_dir = "left";  close_dir = "right"; break;
        default:      open_dir = "up";    close_dir = "down";  break;
        }
        string anims;
        switch (popup) {
        case "none":
            anims = "()";
            break;
        case "grow":
            anims = "(\n"
                + "      { triggers = [ \"open\", \"show\" ];  preset = \"appear\";    scale = 0.90; duration = 0.18; },\n"
                + "      { triggers = [ \"close\", \"hide\" ]; preset = \"disappear\"; scale = 0.90; duration = 0.12; }\n"
                + "    )";
            break;
        case "fade":
            anims = "(\n"
                + "      { triggers = [ \"open\", \"show\" ];  preset = \"appear\";    scale = 1.0; duration = 0.18; },\n"
                + "      { triggers = [ \"close\", \"hide\" ]; preset = \"disappear\"; scale = 1.0; duration = 0.12; }\n"
                + "    )";
            break;
        default: /* slide */
            anims = "(\n"
                + "      { triggers = [ \"open\", \"show\" ];  preset = \"slide-in\";  direction = \"" + open_dir + "\";   duration = 0.18; },\n"
                + "      { triggers = [ \"close\", \"hide\" ]; preset = \"slide-out\"; direction = \"" + close_dir + "\"; duration = 0.12; }\n"
                + "    )";
            break;
        }
        return "  { match = \"class_g = 'kavis-panel' && override_redirect\";\n"
            + "    animations = " + anims + ";\n"
            + "  }\n";
    }

    /* Keyboard layout: one GLOBAL layout, no per-window groups (decision
     * 2F, ayarlar.md survey). The variant is the xkeyboard-config one
     * ("dvorak", "azerty", ...) and is empty for a plain layout;
     * -option "" clears any group/toggle option left behind. */
    public void keyboard_layout (string layout, string variant = "") {
        if (variant == "") {
            Run.fire ({ "setxkbmap", "-layout", layout, "-option", "" });
        } else {
            Run.fire ({ "setxkbmap", "-layout", layout,
                        "-variant", variant, "-option", "" });
        }
    }

    /* Screen blank timeout (minutes; 0 = never) via DPMS. */
    public void screen_off (int minutes) {
        if (minutes == 0) {
            Run.fire ({ "xset", "s", "off", "-dpms" });
        } else {
            int secs = minutes * 60;
            Run.fire ({ "xset", "s", secs.to_string (),
                        secs.to_string () });
            Run.fire ({ "xset", "+dpms", "dpms",
                        secs.to_string (), secs.to_string (),
                        secs.to_string () });
        }
    }
}
