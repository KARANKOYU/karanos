# kavis-theme

Kavis' look and feel: GTK theme, icons, cursors, wallpapers and the
distribution identity.

## What it produces

| Path | Contents |
|---|---|
| `/usr/share/themes/Kavis/gtk-3.0/` | `gtk.css` (light), `gtk-dark.css` (dark) |
| `/usr/share/themes/Kavis/gtk-2.0/gtkrc` | color matching for legacy GTK2 apps |
| `/usr/share/themes/Kavis/openbox-3/themerc` | window frame and title bar |
| `/usr/share/icons/Kavis/` | icons derived from the K logo, inherits Adwaita |
| `/usr/share/icons/Kavis-Cursors/` | 16 shapes, 106 names, two animated |
| `/usr/share/backgrounds/kavis/` | `kavis`, `kavis-night`, `kavis-plain` (SVG + PNG + preview) |
| `/etc/gtk-3.0/settings.ini` | system-wide default theme/cursor/font |
| `/etc/os-release` | `PRETTY_NAME="Kavis 1.0"` |

## No binary files in the repo

Icons, cursors and wallpapers are not stored in the repo as PNG; they
are all generated at build time from `assets/logo/k-logo.svg` and the
two generators under `tools/`:

- `tools/gen-cursors.py` — SVG shapes → `rsvg-convert` → `xcursorgen`
- `tools/gen-wallpapers.py` — SVG gradients → `rsvg-convert`

To change a color, fix the constants at the top of the generators and
rebuild.

## Build

```bash
tools/build-packages.sh kavis-theme     # from the repo root
```

Output is `out/packages/kavis-theme_1.0_all.deb`. The script copies the
logo under `assets/logo/` into `src/logo/` (that copy is in
`.gitignore` — so the logo lives in one place).

## Seeing how it looks

```bash
tools/theme-screenshot.sh out/theme.png
```

Starts Xvfb + Openbox, draws the wallpaper and the theme preview window
and captures them to PNG. Gives a result in ~10 seconds without building
the ISO.

## Known pitfalls

- **Without `window.*.label.bg`** Openbox paints the label box black and
  a black stripe appears in the middle of the title bar.
  `parentrelative` is required.
- **Openbox's theme comes from `rc.xml`**, not from the GTK theme.
  `iso/config/hooks/normal/0200-openbox-theme.hook.chroot` changes a
  single field in Debian's file — replacing the file wholesale would
  drop the `<mouse>` section and windows could no longer be grabbed with
  the mouse.
- **`/etc/os-release` belongs to `base-files`.** Instead of overwriting
  it, `dpkg-divert` is used (`debian/preinst`); the original comes back
  when the package is removed.
