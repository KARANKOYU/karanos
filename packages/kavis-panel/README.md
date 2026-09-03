# kavis-panel

Taskbar and start menu. Written in **Vala** and compiled to a single
native binary (madde 3: the Python version ate 117 MB of RAM; Vala
compiles to the same GTK/Wnck C API — same look and behavior, RAM is
only GTK's own cost).

## File layout (business logic / UI split — madde 3 requirement)

| File | What it does |
|---|---|
| `src/main.vala` | Entry point (the translation check is now `tools/check-i18n.sh` — over po/) |
| `po/` (repo root) | gettext translations — msgids are the English strings in the code, TR in `po/tr.po` |
| `src/logic/brand.vala` | Product identity: name from os-release, logo path by theme (madde 1) |
| `src/logic/apps.vala` | Application list/search/categories (GLib.AppInfo — no .desktop parser of our own) |
| `src/logic/power.vala` | Power actions (systemctl/loginctl via polkit; no sudo) |
| `src/ui/panel.vala` | Taskbar window, window list, strut (libX11 directly) |
| `src/ui/start_menu.vala` | Start menu: search + categorized list + power button |
| `src/ui/power_menu.vala` | Power popup (Lock/Sleep/Shut down/Restart) |
| `src/ui/indicators.vala` | Clock, keyboard layout, battery, virtual desktop indicators |

Code identifiers are English, user-facing strings TR+EN (project rule).

## Building

```bash
tools/build-packages.sh kavis-panel     # from the repo root; produces the .deb
```

By hand: the `valac` call in `debian/rules` (packages: gtk+-3.0,
libwnck-3.0, gdk-x11-3.0, x11, gio-unix-2.0;
`-DWNCK_I_KNOW_THIS_IS_UNSTABLE` is required).

## Testing

```bash
tools/panel-screenshot.sh out/panel.png   # render in Xvfb, grab a PNG
START_MENU=1 tools/panel-screenshot.sh    # start menu open
POWER=1 tools/panel-screenshot.sh         # power popup open
MAXIMIZE=1 tools/panel-screenshot.sh      # strut verification
```

## Decisions made

- **Strut via libX11 directly** (`XChangeProperty`): the python3-xlib
  dependency in Python existed only because PyGObject does not expose
  `Gdk.property_change`; Vala has no such obstacle.
- **`setxkbmap` dependency fixed**: the binary lives in the
  `x11-xkb-utils` package; the old package did not declare it and the
  keyboard indicator silently fell back to "TR".
- **`librsvg2-common` as an explicit dependency**: the logo SVG is
  opened by gdk-pixbuf's SVG loader; shlibs cannot see that dynamic
  loader.
- No system tray on purpose — it comes with the notification
  infrastructure (madde 37).
