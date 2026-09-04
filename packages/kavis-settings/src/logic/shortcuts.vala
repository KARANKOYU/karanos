/* Shortcut catalogue and reassignment (item 74).
 *
 * /usr/share/kavis/shortcuts.list is the single source: the openbox
 * hook writes rc.xml from it, the selftest generator turns it into
 * steps, and this file is how Settings reads it. Before item 74 the
 * Settings list was typed out by hand beside the hook and had already
 * drifted — it claimed Ctrl+Win+arrows switched desktops when the real
 * binding is Ctrl+Alt+arrows.
 *
 * The catalogue carries NO user-visible text on purpose. Labels are
 * the label() table below, so they are ordinary msgids that
 * tools/gen-pot.sh finds; a data file would be invisible to gettext.
 *
 * A reassignment is stored as "id = key" in kavis.conf [shortcuts] and
 * applied by /usr/lib/kavis/set-shortcuts, which rebuilds
 * ~/.config/openbox/rc.xml from the system one. Nothing here needs
 * root.
 */

namespace Kavis.Settings.Shortcuts {

    public struct Entry {
        public string id;
        public string group;
        public string key;      /* the shipped default */
        public bool editable;   /* false for the generated slot block */
    }

    public string catalog_path () {
        string? env = Environment.get_variable ("KAVIS_SHORTCUT_CATALOG");
        return (env != null && env != "")
            ? env : "/usr/share/kavis/shortcuts.list";
    }

    /* The catalogue, in file order — which is also the order the page
     * and the generated selftest use. Empty when the file is missing
     * (a developer checkout without the ISO tree): the page then says
     * so instead of showing a made-up list. */
    public Entry[] list () {
        Entry[] entries = {};
        string text;
        try {
            FileUtils.get_contents (catalog_path (), out text);
        } catch (Error e) {
            return entries;
        }
        foreach (unowned string raw in text.split ("\n")) {
            string line = raw.strip ();
            if (line == "" || line.has_prefix ("#")) {
                continue;
            }
            string[] fields = line.split ("|");
            if (fields.length != 4) {
                warning ("kavis-settings: bad shortcut line: %s", line);
                continue;
            }
            entries += Entry () {
                id = fields[0].strip (),
                group = fields[1].strip (),
                key = fields[2].strip (),
                editable = !fields[3].strip ().has_prefix ("generated")
            };
        }
        return entries;
    }

    /* The key in force right now: the user's override, or the default. */
    public string current_key (Entry entry) {
        try {
            return Config.load ().get_string ("shortcuts", entry.id);
        } catch (Error e) {
            return entry.key;
        }
    }

    public bool is_overridden (Entry entry) {
        return current_key (entry) != entry.key;
    }

    /* Store a new key (or clear the override when it equals the
     * default) and hand the session over to set-shortcuts. Returns
     * what the helper said when it refused, null when it worked. */
    public string? set_key (Entry entry, string key) {
        var file = Config.load ();
        if (key == entry.key) {
            try {
                file.remove_key ("shortcuts", entry.id);
            } catch (Error e) { }
        } else {
            file.set_string ("shortcuts", entry.id, key);
        }
        Config.save (file);
        return apply ();
    }

    public string? reset_all () {
        var file = Config.load ();
        try {
            file.remove_group ("shortcuts");
        } catch (Error e) { }
        Config.save (file);
        return apply ();
    }

    /* Rebuild rc.xml and reload openbox. Returns the helper's message
     * when it refused (a key collision), null when it worked. */
    public string? apply () {
        string message;
        if (Run.run ({ "/usr/lib/kavis/set-shortcuts" }, out message)) {
            return null;
        }
        return message.strip ();
    }

    /* Does any other shortcut already use this key? Returns the id of
     * the one that does, so the dialog can name it. set-shortcuts
     * refuses a collision as well; this is the half that can explain
     * it before the write. */
    public string? key_taken_by (Entry mine, string key) {
        foreach (Entry other in list ()) {
            if (other.id == mine.id) {
                continue;
            }
            if (current_key (other) == key) {
                return other.id;
            }
        }
        return null;
    }

    /* --- names ---------------------------------------------------- */

    /* Group heading. */
    public string group_label (string group) {
        switch (group) {
        case "system":  return _("System");
        case "window":  return _("Window");
        case "desktop": return _("Virtual desktops");
        case "screen":  return _("Screen");
        case "apps":    return _("Apps");
        case "media":   return _("Media and Fn keys");
        }
        return group;
    }

    /* What the shortcut does. The catalogue's ids, translated. */
    public string label (string id) {
        switch (id) {
        case "start-menu":       return _("Start menu");
        case "start-menu-alt":   return _("Start menu (second key)");
        case "run":              return _("Run");
        case "clipboard":        return _("Clipboard history");
        case "emoji":            return _("Emoji and more");
        case "security-screen":  return _("Security screen");
        case "task-manager":     return _("Task Manager");
        case "lock-screen":      return _("Lock screen");
        case "snap-left":        return _("Snap to the left half");
        case "snap-right":       return _("Snap to the right half");
        case "maximize":         return _("Maximize");
        case "restore":          return _("Restore or minimize");
        case "snap-menu":        return _("Snap layouts");
        case "close-window":     return _("Close window / power dialog");
        case "switch-windows":   return _("Switch windows");
        case "overview":         return _("Task view");
        case "show-desktop":     return _("Show desktop");
        case "desktop-next":     return _("Next desktop");
        case "desktop-prev":     return _("Previous desktop");
        case "screenshot":       return _("Screenshot");
        case "screenshot-alt":   return _("Screenshot (second key)");
        case "screenshot-quick": return _("Screenshot without asking");
        case "color-picker":     return _("Color picker");
        case "files":            return _("Files");
        case "settings":         return _("Settings");
        case "pinned-slots":     return _("Open pinned app 1…10");
        case "volume-up":        return _("Volume up");
        case "volume-down":      return _("Volume down");
        case "volume-mute":      return _("Mute");
        case "brightness-up":    return _("Brightness up");
        case "brightness-down":  return _("Brightness down");
        case "media-play":       return _("Play / pause");
        case "media-next":       return _("Next track");
        case "media-prev":       return _("Previous track");
        }
        return id;
    }

    /* openbox syntax → what a person reads. "W-S-c" → "Win+Shift+C". */
    public string display_key (string binding) {
        /* The ten taskbar slots are one catalogue row. */
        if (binding == "W-1") {
            return "Win+1…0";
        }
        var parts = binding.split ("-");
        var shown = new StringBuilder ();
        for (int i = 0; i < parts.length; i++) {
            string part = parts[i];
            /* "-0" of "W-Right"'s cousin: a lone empty piece cannot
             * happen, but a trailing "-" would produce one. */
            if (part == "") {
                continue;
            }
            if (shown.len > 0) {
                shown.append ("+");
            }
            if (i < parts.length - 1) {
                switch (part) {
                case "W": shown.append ("Win");   break;
                case "C": shown.append ("Ctrl");  break;
                case "A": shown.append ("Alt");   break;
                case "S": shown.append ("Shift"); break;
                default:  shown.append (part);    break;
                }
            } else {
                shown.append (key_name (part));
            }
        }
        return shown.str;
    }

    /* The last piece of a binding, as a person knows it. */
    private string key_name (string key) {
        switch (key) {
        case "Left":   return "←";
        case "Right":  return "→";
        case "Up":     return "↑";
        case "Down":   return "↓";
        case "period": return ".";
        case "comma":  return ",";
        case "space":  return _("Space");
        case "Escape": return "Esc";
        case "Delete": return "Del";
        case "Print":  return "PrtSc";
        case "Return": return _("Enter");
        /* xcape turns a Super tap into this synthetic key; showing the
         * name would be honest and useless. */
        case "XF86Launch5":           return "Win";
        case "XF86AudioRaiseVolume":  return _("Volume up key");
        case "XF86AudioLowerVolume":  return _("Volume down key");
        case "XF86AudioMute":         return _("Mute key");
        case "XF86MonBrightnessUp":   return _("Brightness up key");
        case "XF86MonBrightnessDown": return _("Brightness down key");
        case "XF86AudioPlay":         return _("Play key");
        case "XF86AudioNext":         return _("Next track key");
        case "XF86AudioPrev":         return _("Previous track key");
        }
        if (key.char_count () == 1) {
            return key.up ();
        }
        return key;
    }

    /* A key press, as openbox spells it. Empty when the press was a
     * modifier on its own (Shift held down is not a shortcut yet).
     *
     * Modifier order is W-C-A-S because that is the order every
     * shipped default uses; a binding that differs only in modifier
     * order would not match its own default and would look like an
     * override forever. */
    public string from_event (uint keyval, Gdk.ModifierType state) {
        switch (keyval) {
        case Gdk.Key.Shift_L:   case Gdk.Key.Shift_R:
        case Gdk.Key.Control_L: case Gdk.Key.Control_R:
        case Gdk.Key.Alt_L:     case Gdk.Key.Alt_R:
        case Gdk.Key.Super_L:   case Gdk.Key.Super_R:
        case Gdk.Key.Meta_L:    case Gdk.Key.Meta_R:
        case Gdk.Key.ISO_Level3_Shift:
            return "";
        }
        string? name = Gdk.keyval_name (keyval);
        if (name == null) {
            return "";
        }
        /* Shift turns "s" into "S" at the X level; the binding wants
         * the unshifted name plus an explicit S-. */
        if (name.char_count () == 1) {
            name = name.down ();
        }
        var binding = new StringBuilder ();
        if ((state & Gdk.ModifierType.SUPER_MASK) != 0) {
            binding.append ("W-");
        }
        if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
            binding.append ("C-");
        }
        if ((state & Gdk.ModifierType.MOD1_MASK) != 0) {
            binding.append ("A-");
        }
        if ((state & Gdk.ModifierType.SHIFT_MASK) != 0) {
            binding.append ("S-");
        }
        binding.append (name);
        return binding.str;
    }
}
