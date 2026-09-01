#!/usr/bin/env python3
"""Check that the panel's right-hand indicator region is actually drawn.

WHY: a verified bug (picom v12 damage tracking) painted newly mapped
windows black and hid the right side of the taskbar — clock and
indicators invisible — while boot-check still reported RESULT=OK.
Looking at the whole screen (screen-not-blank.py) does not catch this:
the wallpaper alone provides enough colors. So we crop the bottom-right
corner where the clock lives and require bright text pixels there.

Region: bottom PANEL_HEIGHT rows x rightmost quarter of the width.
The panel is 44 px tall (ui/panel.vala HEIGHT); the clock, keyboard
layout and workspace indicators sit at its right end. Panel background
is #121C26 (luma ~24), indicator text #E6EDF3 (luma ~232), secondary
text #8B9BA8 (luma ~152) — so "at least N pixels brighter than 120"
separates a drawn clock from a black/ghosted or text-less region.

Usage:  screen-clock-visible.py <file.ppm> [--min-bright N]
Exit:   0 = indicators visible, 1 = region empty/black, 2 = unreadable
"""

import sys

PANEL_HEIGHT = 44
BRIGHT_LUMA = 120.0


def read_ppm(path):
	"""Parse a binary PPM (P6); return (width, height, raw_rgb) or None."""
	with open(path, "rb") as fh:
		d = fh.read()
	if d[:2] != b"P6":
		return None
	parts, idx = [], 2
	while len(parts) < 3:
		while idx < len(d) and d[idx:idx + 1].isspace():
			idx += 1
		if d[idx:idx + 1] == b"#":
			while idx < len(d) and d[idx:idx + 1] != b"\n":
				idx += 1
			continue
		start = idx
		while idx < len(d) and not d[idx:idx + 1].isspace():
			idx += 1
		parts.append(int(d[start:idx]))
	idx += 1
	w, h = parts[0], parts[1]
	return w, h, d[idx:idx + w * h * 3]


def main():
	if len(sys.argv) < 2:
		sys.exit("kullanim: screen-clock-visible.py <dosya.ppm> [--min-bright N]")
	path = sys.argv[1]
	min_bright = 15
	for i, a in enumerate(sys.argv):
		if a == "--min-bright":
			min_bright = int(sys.argv[i + 1])

	data = read_ppm(path)
	if not data:
		print(f"SAAT-TANI: {path} okunamadi (PPM degil)")
		return 2
	w, h, raw = data
	if len(raw) < w * h * 3:
		print(f"SAAT-TANI: {path} eksik ({len(raw)} bayt)")
		return 2

	x_start = (w * 3) // 4
	y_start = max(0, h - PANEL_HEIGHT)
	bright = 0
	total = 0
	colors = set()
	for y in range(y_start, h):
		row = y * w * 3
		for x in range(x_start, w):
			off = row + x * 3
			r, g, b = raw[off], raw[off + 1], raw[off + 2]
			colors.add((r, g, b))
			if (r * 299 + g * 587 + b * 114) / 1000.0 >= BRIGHT_LUMA:
				bright += 1
			total += 1

	print(f"SAAT-TANI: sag alt bolge {w - x_start}x{h - y_start} · "
	      f"{len(colors)} renk · {bright}/{total} parlak piksel "
	      f"(esik {min_bright})")

	if bright < min_bright:
		print("SAAT-TANI: BOS — saat/gosterge bolgesinde parlak piksel yok "
		      "(picom hayalet cizim belirtisi)")
		return 1
	print("SAAT-TANI: gostergeler gorunuyor")
	return 0


if __name__ == "__main__":
	sys.exit(main())
