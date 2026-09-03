#!/usr/bin/env python3
"""Measure whether a QEMU screendump (PPM) really shows a desktop.

WHY: in stages 1 and 2 CI went green while the QEMU screen was pitch
black — the graphical session had never started. Looking at the
"RESULT=OK" line is not enough; it must also be verified that something
was DRAWN on the screen.

Two criteria, both must pass:
  1. Color variety: how many distinct colors. An empty X root window is
     a single color; a wallpaper gradient produces thousands.
  2. Brightness spread (standard deviation): a screen filled with one
     flat color gives a deviation close to 0.

Usage:  screen-not-blank.py <file.ppm> [--min-colors N] [--min-stddev X]
Exit:   0 = content on screen, 1 = blank/flat screen, 2 = unreadable file
"""

import sys


def read_ppm(path):
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
		sys.exit("usage: screen-not-blank.py <file.ppm> [--min-colors N] [--min-stddev X]")
	path = sys.argv[1]
	min_colors = 24
	min_stddev = 3.0
	for i, a in enumerate(sys.argv):
		if a == "--min-colors":
			min_colors = int(sys.argv[i + 1])
		elif a == "--min-stddev":
			min_stddev = float(sys.argv[i + 1])

	data = read_ppm(path)
	if not data:
		print(f"SCREEN-CHECK: {path} unreadable (not a PPM)")
		return 2
	w, h, raw = data
	if len(raw) < w * h * 3:
		print(f"SCREEN-CHECK: {path} truncated ({len(raw)} bytes)")
		return 2

	# Visiting every pixel is unnecessary; sample every 4th pixel.
	step = 4 * 3
	colors = set()
	total = 0
	sq_total = 0
	count = 0
	for off in range(0, w * h * 3 - 3, step):
		r, g, b = raw[off], raw[off + 1], raw[off + 2]
		colors.add((r, g, b))
		luma = (r * 299 + g * 587 + b * 114) / 1000.0
		total += luma
		sq_total += luma * luma
		count += 1

	mean = total / count
	stddev = max(0.0, (sq_total / count) - mean * mean) ** 0.5

	print(f"SCREEN-CHECK: {w}x{h} · {len(colors)} distinct colors · "
	      f"mean brightness {mean:.1f} · stddev {stddev:.2f}")

	if len(colors) < min_colors and stddev < min_stddev:
		print(f"SCREEN-CHECK: BLANK — expected at least {min_colors} colors and {min_stddev} stddev")
		return 1
	print("SCREEN-CHECK: content on screen")
	return 0


if __name__ == "__main__":
	sys.exit(main())
