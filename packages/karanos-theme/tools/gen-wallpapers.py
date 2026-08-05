#!/usr/bin/env python3
"""Karan OS duvar kağıdı üreteci.

NEDEN SCRIPT: duvar kağıdını PNG olarak depoya koysak her değişiklik
megabaytlarca ikili fark demek olurdu. Burada SVG olarak tanımlanıp
derleme sırasında PNG'ye çevriliyor; depoda yalnızca bu dosya duruyor.

Her duvar kağıdı için üretilenler:
  <ad>.svg          ölçeklenebilir kaynak
  <ad>.png          1920x1080 (duvar kağıdı koyucular ham görüntü ister)
  <ad>-onizleme.png 320x180 (ayarlar uygulaması için küçük resim)

Gereksinim: rsvg-convert (librsvg2-bin)
Kullanım:   gen-wallpapers.py <cikis-dizini>
"""

import os
import subprocess
import sys

W, H = 1920, 1080

ACCENT = "#FF8C1A"
ACCENT2 = "#FFBF00"
INK = "#575E75"
DARK = "#1B1F2E"
DARK2 = "#2A3046"

# Logodaki "K" — düşük opaklıkta filigran olarak kullanılıyor.
# assets/logo/k-logo.svg ile aynı yollar, 100x100 ızgarada.
K_PATHS = (
	'<path d="M40 18 C31 24, 27 44, 28 60 C28.6 70, 30 76, 32 80" stroke-width="10"/>'
	'<path d="M74 24 C60 33, 45 43, 33 51" stroke-width="4.5"/>'
	'<path d="M37 48 C49 56, 60 66, 72 80" stroke-width="8"/>'
)


def watermark(cx, cy, size, color, opacity):
	"""K filigranı — 100x100 ızgaradan istenen boyuta ölçeklenir."""
	s = size / 100.0
	return (
		f'<g transform="translate({cx - size / 2:.1f},{cy - size / 2:.1f}) scale({s:.4f})" '
		f'fill="none" stroke="{color}" stroke-opacity="{opacity}" '
		'stroke-linecap="round" stroke-linejoin="round">'
		f'{K_PATHS}</g>'
	)


def blob(cx, cy, r, color, opacity):
	"""Yumuşak renk lekesi — düz degradenin bantlaşmasını kırıyor."""
	return (
		f'<radialGradient id="b{cx}{cy}" cx="50%" cy="50%" r="50%">'
		f'<stop offset="0%" stop-color="{color}" stop-opacity="{opacity}"/>'
		f'<stop offset="100%" stop-color="{color}" stop-opacity="0"/>'
		f'</radialGradient>'
		f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#b{cx}{cy})"/>'
	)


def page(defs, body):
	return (
		f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
		f'viewBox="0 0 {W} {H}">'
		f'<defs>{defs}</defs>{body}</svg>'
	)


def karan():
	"""Varsayılan: marka degradesi, sağ altta soluk K."""
	defs = (
		f'<linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
		f'<stop offset="0%" stop-color="{ACCENT}"/>'
		f'<stop offset="55%" stop-color="#FFA320"/>'
		f'<stop offset="100%" stop-color="{ACCENT2}"/>'
		f'</linearGradient>'
	)
	body = (
		f'<rect width="{W}" height="{H}" fill="url(#g)"/>'
		f'<g>{blob(320, 220, 620, "#FFFFFF", 0.22)}</g>'
		f'<g>{blob(1650, 900, 700, "#FF6A00", 0.28)}</g>'
		+ watermark(1480, 660, 760, "#FFFFFF", 0.13)
	)
	return defs, body


def karan_koyu():
	"""Koyu tema eşi: lacivert zemin, köşelerde turuncu ışıma."""
	defs = (
		f'<linearGradient id="g" x1="0" y1="0" x2="0.6" y2="1">'
		f'<stop offset="0%" stop-color="{DARK2}"/>'
		f'<stop offset="100%" stop-color="{DARK}"/>'
		f'</linearGradient>'
	)
	body = (
		f'<rect width="{W}" height="{H}" fill="url(#g)"/>'
		f'<g>{blob(1620, 240, 820, ACCENT, 0.42)}</g>'
		f'<g>{blob(180, 960, 720, ACCENT2, 0.20)}</g>'
		# Filigran açık duvar kağıdındakiyle aynı yerde — masaüstü
		# simgeleri sol üstte duracağı için sağ alt boş kalıyor.
		+ watermark(1480, 660, 760, ACCENT2, 0.20)
	)
	return defs, body


def karan_duz():
	"""Dikkat dağıtmayan düz zemin — ortada küçük logo."""
	defs = (
		f'<linearGradient id="k" x1="0" y1="0" x2="1" y2="1">'
		f'<stop offset="0%" stop-color="{ACCENT}"/>'
		f'<stop offset="100%" stop-color="{ACCENT2}"/>'
		f'</linearGradient>'
	)
	body = (
		f'<rect width="{W}" height="{H}" fill="{INK}"/>'
		f'<rect x="{W / 2 - 90:.0f}" y="{H / 2 - 90:.0f}" width="180" height="180" '
		f'rx="47" fill="url(#k)"/>'
		+ watermark(W / 2, H / 2, 150, "#FFFFFF", 0.95)
	)
	return defs, body


WALLPAPERS = {
	"karan": karan,
	"karan-koyu": karan_koyu,
	"karan-duz": karan_duz,
}


def main():
	if len(sys.argv) != 2:
		sys.exit("kullanim: gen-wallpapers.py <cikis-dizini>")
	outdir = os.path.abspath(sys.argv[1])
	os.makedirs(outdir, exist_ok=True)

	for name, fn in WALLPAPERS.items():
		defs, body = fn()
		svg_path = os.path.join(outdir, f"{name}.svg")
		with open(svg_path, "w", encoding="utf-8") as fh:
			fh.write(page(defs, body))
		for suffix, width in (("", W), ("-onizleme", 320)):
			subprocess.run(
				["rsvg-convert", "-w", str(width),
				 "-o", os.path.join(outdir, f"{name}{suffix}.png"), svg_path],
				check=True,
			)
		print(f"duvar kağıdı: {name}")


if __name__ == "__main__":
	main()
