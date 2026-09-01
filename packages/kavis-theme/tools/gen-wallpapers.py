#!/usr/bin/env python3
"""Kavis duvar kağıdı üreteci.

NEDEN SCRIPT: duvar kağıdını PNG olarak depoya koysak her değişiklik
megabaytlarca ikili fark demek olurdu. Burada SVG olarak tanımlanıp
derleme sırasında PNG'ye çevriliyor; depoda yalnızca bu dosya duruyor.

Varsayılan tema koyu olduğu için üç duvar kağıdı da koyu zeminli:
  kavis       marka degradesi — turkuazdan maviye ışıma (varsayılan)
  kavis-gece  neredeyse düz, en sakin olanı
  kavis-duz   tek renk zemin, ortada logo

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

ACCENT = "#2DD4BF"   # turkuaz — ana vurgu
ACCENT2 = "#4F92F7"  # mavi — ikincil
GROUND = "#0D141B"   # masaüstü zemini
SURFACE = "#17222C"  # pencere yüzeyi
BORDER = "#233A45"

# Logodaki "K" — düşük opaklıkta filigran olarak kullanılıyor.
# assets/logo/koyu-k-logo.svg ile aynı yollar, 100x100 ızgarada.
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


def gradient_watermark(cx, cy, size, opacity):
	"""Degradeli K — logonun kendi renk geçişini taşıyan filigran."""
	s = size / 100.0
	return (
		f'<g transform="translate({cx - size / 2:.1f},{cy - size / 2:.1f}) scale({s:.4f})" '
		f'fill="none" stroke="url(#kgrad)" stroke-opacity="{opacity}" '
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


KGRAD = (
	f'<linearGradient id="kgrad" x1="0.2" y1="0" x2="0.9" y2="1">'
	f'<stop offset="0%" stop-color="{ACCENT}"/>'
	f'<stop offset="100%" stop-color="{ACCENT2}"/>'
	f'</linearGradient>'
)


def page(defs, body):
	return (
		f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
		f'viewBox="0 0 {W} {H}">'
		f'<defs>{KGRAD}{defs}</defs>{body}</svg>'
	)


def kavis():
	"""Varsayılan: koyu zemin, turkuazdan maviye ışıma, sağ altta K."""
	defs = (
		f'<linearGradient id="g" x1="0" y1="0" x2="0.7" y2="1">'
		f'<stop offset="0%" stop-color="#101B24"/>'
		f'<stop offset="60%" stop-color="{GROUND}"/>'
		f'<stop offset="100%" stop-color="#0A1016"/>'
		f'</linearGradient>'
	)
	body = (
		f'<rect width="{W}" height="{H}" fill="url(#g)"/>'
		# Turkuaz sol üstten, mavi sağ alttan — logonun degrade yönü.
		f'<g>{blob(300, 200, 880, ACCENT, 0.30)}</g>'
		f'<g>{blob(1680, 940, 900, ACCENT2, 0.26)}</g>'
		f'<g>{blob(1500, 260, 520, ACCENT2, 0.10)}</g>'
		# Masaüstü simgeleri sol üstte duracağı için filigran sağ altta.
		+ gradient_watermark(1480, 660, 760, 0.22)
	)
	return defs, body


def kavis_gece():
	"""En sakin olanı: neredeyse düz zemin, tek soluk ışıma."""
	defs = (
		f'<linearGradient id="g" x1="0" y1="0" x2="0.3" y2="1">'
		f'<stop offset="0%" stop-color="{SURFACE}"/>'
		f'<stop offset="100%" stop-color="#080D12"/>'
		f'</linearGradient>'
	)
	body = (
		f'<rect width="{W}" height="{H}" fill="url(#g)"/>'
		f'<g>{blob(1450, 820, 900, ACCENT, 0.12)}</g>'
		+ watermark(1480, 660, 700, ACCENT, 0.07)
	)
	return defs, body


def kavis_duz():
	"""Dikkat dağıtmayan düz zemin — ortada logo kutusu."""
	defs = (
		f'<linearGradient id="box" x1="0" y1="0" x2="1" y2="1">'
		f'<stop offset="0%" stop-color="#0F2A2C"/>'
		f'<stop offset="100%" stop-color="#152444"/>'
		f'</linearGradient>'
	)
	body = (
		f'<rect width="{W}" height="{H}" fill="{GROUND}"/>'
		f'<rect x="{W / 2 - 90:.0f}" y="{H / 2 - 90:.0f}" width="180" height="180" '
		f'rx="47" fill="url(#box)" stroke="{BORDER}" stroke-width="2"/>'
		+ gradient_watermark(W / 2, H / 2, 150, 1.0)
	)
	return defs, body


def grub_arkaplan():
	"""GRUB menü arka planı — kural: GRUB'da HER ZAMAN koyu logo.

	Duvar kağıdı değil; koyu-k-logo.svg'nin birebir karşılığı (kutu +
	degradeli K) düz zeminde, üst üçte birlik bölgede. Menü metni ekranın
	ortasına çizildiği için logo yukarıda duruyor — yazıyla çakışmıyor.
	"""
	defs = (
		f'<linearGradient id="box" x1="0" y1="0" x2="1" y2="1">'
		f'<stop offset="0%" stop-color="#0F2A2C"/>'
		f'<stop offset="100%" stop-color="#152444"/>'
		f'</linearGradient>'
	)
	logo_boy = 130
	cx, cy = W / 2, H / 4
	body = (
		f'<rect width="{W}" height="{H}" fill="{GROUND}"/>'
		f'<rect x="{cx - logo_boy / 2:.0f}" y="{cy - logo_boy / 2:.0f}" '
		f'width="{logo_boy}" height="{logo_boy}" rx="{logo_boy * 0.26:.0f}" '
		f'fill="url(#box)" stroke="{BORDER}" stroke-width="2"/>'
		+ gradient_watermark(cx, cy, logo_boy * 0.83, 1.0)
	)
	return defs, body


WALLPAPERS = {
	"kavis": kavis,
	"kavis-gece": kavis_gece,
	"kavis-duz": kavis_duz,
}


def grub_uret(png_yolu):
	"""GRUB arka planını tek PNG olarak üretir (SVG ve önizleme yok)."""
	defs, body = grub_arkaplan()
	svg_yolu = png_yolu + ".tmp.svg"
	with open(svg_yolu, "w", encoding="utf-8") as fh:
		fh.write(page(defs, body))
	subprocess.run(
		["rsvg-convert", "-w", str(W), "-o", png_yolu, svg_yolu],
		check=True,
	)
	os.unlink(svg_yolu)
	print(f"grub arka planı: {png_yolu}")


def main():
	if len(sys.argv) == 3 and sys.argv[1] == "--grub":
		grub_uret(os.path.abspath(sys.argv[2]))
		return
	if len(sys.argv) != 2:
		sys.exit("kullanim: gen-wallpapers.py <cikis-dizini> | --grub <png>")
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
