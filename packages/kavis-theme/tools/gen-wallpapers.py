#!/usr/bin/env python3
"""Kavis wallpaper generator.

WHY A SCRIPT: keeping the wallpaper as PNG in the repo would mean
megabytes of binary diff on every change. Here it is defined as SVG and
converted to PNG at build time; only this file lives in the repo.

Since the default theme is dark, all three wallpapers have a dark ground:
  kavis        brand gradient — teal-to-blue glow (default)
  kavis-night  nearly flat, the calmest one
  kavis-plain  single-color ground, logo in the center

Generated for each wallpaper:
  <name>.svg          scalable source
  <name>.png          1920x1080 (wallpaper setters want a raw image)
  <name>-preview.png  320x180 (thumbnail for the settings app)

Requirement: rsvg-convert (librsvg2-bin)
Usage:       gen-wallpapers.py <output-dir>
"""

import os
import subprocess
import sys

W, H = 1920, 1080

ACCENT = "#2DD4BF"   # teal — primary accent
ACCENT2 = "#4F92F7"  # blue — secondary
GROUND = "#0D141B"   # desktop ground
SURFACE = "#17222C"  # window surface
BORDER = "#233A45"

# The "K" from the logo — used as a low-opacity watermark.
# Same paths as assets/logo/koyu-k-logo.svg, on a 100x100 grid.
K_PATHS = (
	'<path d="M40 18 C31 24, 27 44, 28 60 C28.6 70, 30 76, 32 80" stroke-width="10"/>'
	'<path d="M74 24 C60 33, 45 43, 33 51" stroke-width="4.5"/>'
	'<path d="M37 48 C49 56, 60 66, 72 80" stroke-width="8"/>'
)


def watermark(cx, cy, size, color, opacity):
	"""K watermark — scaled from the 100x100 grid to the requested size."""
	s = size / 100.0
	return (
		f'<g transform="translate({cx - size / 2:.1f},{cy - size / 2:.1f}) scale({s:.4f})" '
		f'fill="none" stroke="{color}" stroke-opacity="{opacity}" '
		'stroke-linecap="round" stroke-linejoin="round">'
		f'{K_PATHS}</g>'
	)


def gradient_watermark(cx, cy, size, opacity):
	"""Gradient K — a watermark carrying the logo's own color transition."""
	s = size / 100.0
	return (
		f'<g transform="translate({cx - size / 2:.1f},{cy - size / 2:.1f}) scale({s:.4f})" '
		f'fill="none" stroke="url(#kgrad)" stroke-opacity="{opacity}" '
		'stroke-linecap="round" stroke-linejoin="round">'
		f'{K_PATHS}</g>'
	)


def blob(cx, cy, r, color, opacity):
	"""Soft color blob — breaks the banding of a flat gradient."""
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
	"""Default: dark ground, teal-to-blue glow, K at the bottom right."""
	defs = (
		f'<linearGradient id="g" x1="0" y1="0" x2="0.7" y2="1">'
		f'<stop offset="0%" stop-color="#101B24"/>'
		f'<stop offset="60%" stop-color="{GROUND}"/>'
		f'<stop offset="100%" stop-color="#0A1016"/>'
		f'</linearGradient>'
	)
	body = (
		f'<rect width="{W}" height="{H}" fill="url(#g)"/>'
		# Teal from the top left, blue from the bottom right — the logo's
		# gradient direction.
		f'<g>{blob(300, 200, 880, ACCENT, 0.30)}</g>'
		f'<g>{blob(1680, 940, 900, ACCENT2, 0.26)}</g>'
		f'<g>{blob(1500, 260, 520, ACCENT2, 0.10)}</g>'
		# Desktop icons sit at the top left, so the watermark is at the
		# bottom right.
		+ gradient_watermark(1480, 660, 760, 0.22)
	)
	return defs, body


def kavis_night():
	"""The calmest one: nearly flat ground, a single faint glow."""
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


def kavis_plain():
	"""Non-distracting flat ground — logo box in the center."""
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


def grub_background():
	"""GRUB menu background — rule: ALWAYS the dark logo in GRUB.

	Not a wallpaper; the exact counterpart of koyu-k-logo.svg (box +
	gradient K) on a flat ground, in the top third. The menu text is
	drawn in the middle of the screen, so the logo stays up top — no
	overlap with the text.
	"""
	defs = (
		f'<linearGradient id="box" x1="0" y1="0" x2="1" y2="1">'
		f'<stop offset="0%" stop-color="#0F2A2C"/>'
		f'<stop offset="100%" stop-color="#152444"/>'
		f'</linearGradient>'
	)
	logo_size = 130
	cx, cy = W / 2, H / 4
	body = (
		f'<rect width="{W}" height="{H}" fill="{GROUND}"/>'
		f'<rect x="{cx - logo_size / 2:.0f}" y="{cy - logo_size / 2:.0f}" '
		f'width="{logo_size}" height="{logo_size}" rx="{logo_size * 0.26:.0f}" '
		f'fill="url(#box)" stroke="{BORDER}" stroke-width="2"/>'
		+ gradient_watermark(cx, cy, logo_size * 0.83, 1.0)
	)
	return defs, body


WALLPAPERS = {
	"kavis": kavis,
	"kavis-night": kavis_night,
	"kavis-plain": kavis_plain,
}


def gen_grub(png_path):
	"""Generates the GRUB background as a single PNG (no SVG, no preview)."""
	defs, body = grub_background()
	svg_path = png_path + ".tmp.svg"
	with open(svg_path, "w", encoding="utf-8") as fh:
		fh.write(page(defs, body))
	subprocess.run(
		["rsvg-convert", "-w", str(W), "-o", png_path, svg_path],
		check=True,
	)
	os.unlink(svg_path)
	print(f"grub background: {png_path}")


def main():
	if len(sys.argv) == 3 and sys.argv[1] == "--grub":
		gen_grub(os.path.abspath(sys.argv[2]))
		return
	if len(sys.argv) != 2:
		sys.exit("usage: gen-wallpapers.py <output-dir> | --grub <png>")
	outdir = os.path.abspath(sys.argv[1])
	os.makedirs(outdir, exist_ok=True)

	for name, fn in WALLPAPERS.items():
		defs, body = fn()
		svg_path = os.path.join(outdir, f"{name}.svg")
		with open(svg_path, "w", encoding="utf-8") as fh:
			fh.write(page(defs, body))
		for suffix, width in (("", W), ("-preview", 320)):
			subprocess.run(
				["rsvg-convert", "-w", str(width),
				 "-o", os.path.join(outdir, f"{name}{suffix}.png"), svg_path],
				check=True,
			)
		print(f"wallpaper: {name}")


if __name__ == "__main__":
	main()
