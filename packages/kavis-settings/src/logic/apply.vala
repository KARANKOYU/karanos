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
            warning ("kavis-settings: xsettingsd.conf yazilamadi: %s",
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
        /* Panel/OSD/menüler kavis.conf'u izler (Theme.install) —
         * burada ek iş yok; sayfa conf'u zaten yazdı. */
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
                warning ("kavis-settings: rc.xml yok: %s", e2.message);
                return;
            }
        }
        try {
            /* <theme> bloğundaki ilk <name> tema adıdır (0200 hook'u
             * ile aynı varsayım). */
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
            warning ("kavis-settings: rc.xml yazilamadi: %s", e.message);
            return;
        }
        Run.fire ({ "openbox", "--reconfigure" });
    }

    /* percent: 100/125/150/200 → Xft DPI (xsettingsd wants it ×1024). */
    public void scale (int percent) {
        int dpi = 96 * percent / 100;
        xsettings_set ("Xft/DPI", (dpi * 1024).to_string ());
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
     * copy). anim_factor: 0 = off, else duration multiplier ×100. */
    public void picom (int radius, int anim_factor) {
        string template;
        try {
            FileUtils.get_contents ("/etc/xdg/picom-kavis.conf",
                                    out template);
        } catch (Error e) {
            warning ("kavis-settings: picom sablonu yok: %s", e.message);
            return;
        }
        try {
            var re = new Regex ("corner-radius = [0-9]+;");
            template = re.replace (template, -1, 0,
                "corner-radius = %d;".printf (radius));
        } catch (RegexError e) { }
        if (anim_factor == 0) {
            /* Animasyon kapalı: bloğu boş listeyle değiştir. */
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
            /* tasarim-dili.md taban süreleri: açılış 0.18, kapanış
             * 0.12 — çarpanla ölçeklenir. */
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
            warning ("kavis-settings: picom.conf yazilamadi: %s",
                     e.message);
            return;
        }
        /* picom yeniden yükleme bilmiyor: öldür, kullanıcı kopyasıyla
         * yeniden başlat (autostart'la aynı satır). */
        Run.fire ({ "sh", "-c",
            "pkill -x picom; sleep 0.3; "
            + "picom --backend xrender --config '" + user_conf
            + "' -b" });
    }

    /* Keyboard layout: one GLOBAL layout, no per-window groups (2F
     * kararı, ayarlar.md taraması). */
    public void keyboard_layout (string layout) {
        Run.fire ({ "setxkbmap", layout });
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
