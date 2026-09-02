#!/usr/bin/env python3
"""GRUB gfxmenu theme assets (test8 H1).

Generates, at package build time (no binary blobs in the repo):
  select_*.png  — 9-slice teal rounded box for the SELECTED menu item
                  (gfxmenu can style only the selected item; plain
                  items cannot get boxes — GRUB limitation, logged)
  icons/*.png   — 24px monochrome line icons per menu entry class
                  (gfxmenu shows the icon of an entry's first --class)

All drawings are our own simple SVG paths rendered with rsvg-convert.

Usage: gen-grub-tema.py <output-dir>
"""

import subprocess
import sys
import tempfile
from pathlib import Path

TEAL = "#2DD4BF"
FG = "#E6EDF3"

# 9 dilim: köşeler 10x10 (r=10 çeyrek yuvarlak), kenarlar/merkez düz.
SLICES = {
    "nw": (10, 10, '<path d="M10 0 A10 10 0 0 0 0 10 L0 10 L10 10 Z" fill="%s"/>'
                   '<rect x="0" y="10" width="10" height="0" fill="%s"/>' % (TEAL, TEAL)),
    "ne": (10, 10, '<path d="M0 0 A10 10 0 0 1 10 10 L0 10 Z" fill="%s"/>' % TEAL),
    "sw": (10, 10, '<path d="M0 0 L10 0 L10 10 A10 10 0 0 1 0 0 Z" fill="%s"/>' % TEAL),
    "se": (10, 10, '<path d="M0 0 L10 0 A10 10 0 0 1 0 10 Z" fill="%s"/>' % TEAL),
    "n": (8, 10, '<rect width="8" height="10" fill="%s"/>' % TEAL),
    "s": (8, 10, '<rect width="8" height="10" fill="%s"/>' % TEAL),
    "e": (10, 8, '<rect width="10" height="8" fill="%s"/>' % TEAL),
    "w": (10, 8, '<rect width="10" height="8" fill="%s"/>' % TEAL),
    "c": (8, 8, '<rect width="8" height="8" fill="%s"/>' % TEAL),
}

# Basit çizgi ikonlar (24x24, tek renk). Sınıf adları menuentry
# --class değerleriyle eşleşir.
LINE = 'fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"' % FG
ICONS = {
    # ana girdiler: K başharfi
    "kavis": '<path d="M7 4 V20 M17 4 L8 12 L17 20" %s/>' % LINE,
    # güvenli mod: kalkan
    "safemode": '<path d="M12 3 L20 6 V12 C20 17 16 20 12 21 C8 20 4 17 4 12 V6 Z" %s/>' % LINE,
    # detaylı açılış: terminal
    "verbose": ('<rect x="3" y="5" width="18" height="14" rx="2" %s/>'
                '<path d="M6 10 L9 12 L6 14 M12 15 H17" %s/>' % (LINE, LINE)),
    # bütünlük doğrulama: onay işareti
    "verify": '<path d="M5 13 L10 18 L19 7" %s/>' % LINE,
    # RAM testi: yonga
    "memtest": ('<rect x="7" y="7" width="10" height="10" rx="1" %s/>'
                '<path d="M9 7 V4 M15 7 V4 M9 17 V20 M15 17 V20 '
                'M7 9 H4 M7 15 H4 M17 9 H20 M17 15 H20" %s/>'
                % (LINE, LINE)),
    # UEFI ayarları: dişli
    "uefi": ('<circle cx="12" cy="12" r="4" %s/>'
             '<path d="M12 4 V7 M12 17 V20 M4 12 H7 M17 12 H20 '
             'M6.3 6.3 L8.4 8.4 M15.6 15.6 L17.7 17.7 '
             'M17.7 6.3 L15.6 8.4 M8.4 15.6 L6.3 17.7" %s/>'
             % (LINE, LINE)),
}


def render(svg_body, width, height, out_path):
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" '
           'height="%d" viewBox="0 0 %d %d">%s</svg>'
           % (width, height, width, height, svg_body))
    with tempfile.NamedTemporaryFile("w", suffix=".svg",
                                     delete=False) as tmp:
        tmp.write(svg)
        path = tmp.name
    subprocess.run(["rsvg-convert", "-w", str(width), "-h", str(height),
                    "-o", str(out_path), path], check=True)
    Path(path).unlink()


def main():
    if len(sys.argv) != 2:
        print("kullanim: gen-grub-tema.py <cikti-dizini>",
              file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    (out / "icons").mkdir(parents=True, exist_ok=True)

    for name, (w, h, body) in SLICES.items():
        render(body, w, h, out / f"select_{name}.png")
    for name, body in ICONS.items():
        render(body, 24, 24, out / "icons" / f"{name}.png")
    print(f"{len(SLICES)} dilim + {len(ICONS)} ikon -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
