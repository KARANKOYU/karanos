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
            /* Debian Xsession ~/.xsessionrc'yi kaynaklar: bir sonraki
             * oturumda X altındaki HER süreç aynı dili görür. */
            FileUtils.set_contents (
                Path.build_filename (Environment.get_home_dir (),
                                     ".xsessionrc"),
                "# Kavis Ayarlar > Dil yazdı.\nexport LANG=%s\nexport LANGUAGE=%s\n"
                    .printf (locale, code));
        } catch (Error e) {
            warning ("kavis-settings: dil dosyalari yazilamadi: %s",
                     e.message);
        }
        /* Root kısmı arka planda; bitince bildirim. */
        Run.fire ({ "sh", "-c",
            "pkexec /usr/lib/kavis/set-locale '" + locale + "'; "
            + "gdbus call --session --dest org.freedesktop.Notifications "
            + "--object-path /org/freedesktop/Notifications "
            + "--method org.freedesktop.Notifications.Notify "
            + "kavis-settings 0 preferences-desktop-locale "
            + "\"" + _("Language changed") + "\" "
            + "\"" + _("Sign out and back in for the change to take full effect.") + "\" "
            + "'[]' '{}' 8000 >/dev/null 2>&1" });
        /* Kendini yeni dille yeniden aç (klavye bölümünde). */
        Environment.set_variable ("LANG", locale, true);
        Environment.set_variable ("LANGUAGE", code, true);
        Posix.execvp ("kavis-settings", { "kavis-settings", "keyboard" });
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
     * copy). anim_factor: 0 = off, else duration multiplier ×100.
     * popup (C6): "slide" | "grow" | "fade" | "none" — animation of
     * the panel's own popups, written as a picom window rule between
     * the popup-animasyon-basi/-sonu markers; the slide direction
     * follows the taskbar position ("bottom" → slides up). */
    public void picom (int radius, int anim_factor, string popup,
                       string position) {
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
        /* Popup kuralı önce yazılır ki süre çarpanı ona da uygulansın. */
        int rb = template.index_of ("# popup-animasyon-basi");
        int re_ = template.index_of ("# popup-animasyon-sonu");
        if (rb >= 0 && re_ > rb) {
            template = template.substring (0, rb)
                + "# popup-animasyon-basi\n"
                + popup_rule (anim_factor == 0 ? "none" : popup, position)
                + "  " + template.substring (re_);
        }
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
        /* B3: canlı uygulama. D-Bus opts_set corner_radius'u
         * KAPSAMIYOR (picom dbus.c: yalnız fade/vsync/unredir), o yüzden
         * belgeli yol SIGUSR1: picom kendini yeniden başlatır, aynı
         * süreç conf'u tekrar okur — süreç ölmediği için 300 ms'lik
         * siyah kare yok. Yalnız kaydırıcı bırakılınca çağrılır. picom
         * hiç çalışmıyorsa (VM'de kapatılmış) kullanıcı kopyasıyla
         * başlatılır. */
        /* Debug turu (3 Eyl): SIGUSR1 picom'un BAŞLADIĞI dosyayı yeniden
         * okutur. Oturum kullanıcı kopyası olmadan açıldıysa picom
         * /etc/xdg şablonuyla çalışıyordur ve sinyal hiçbir şeyi
         * değiştirmez (VM'de görüldü). O durumda bir kez kullanıcı
         * kopyasıyla yeniden başlatılır (~300 ms siyah kare, oturumda
         * tek sefer); sonraki değişiklikler yine sinyalle. */
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
