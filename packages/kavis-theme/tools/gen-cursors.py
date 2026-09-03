#!/usr/bin/env python3
"""Kavis XCursor theme generator.

WHY A SCRIPT: 4 sizes x 14 shapes, two of them 12-frame animations —
over 400 PNGs. Instead of putting them in the repo as binary files we
generate them at build time from a single source (the SVG drawings
here). When we want to change a color we change one line and rebuild.

Requirements: rsvg-convert (librsvg2-bin), xcursorgen (x11-apps)
Usage:        gen-cursors.py <cursors-dir>
"""

import math
import os
import subprocess
import sys
import tempfile

# Identity colors from section 4
# The outline is nearly black: the cursor must be equally crisp on the
# dark desktop and on top of a white document.
OUTLINE = "#0D141B"
FILL = "#FFFFFF"
ACCENT = "#2DD4BF"
ACCENT2 = "#4F92F7"
# A teal "forbidden" cursor does not read as a warning; red as the single
# exception so its function is clear from its color.
DANGER = "#EF4444"

SIZES = (24, 32, 48, 64)
GRID = 24.0  # all drawings on a 24x24 grid, scaled to the sizes from here

ANIM_FRAMES = 12
ANIM_DELAY = 60  # ms


# --------------------------------------------------------------------
# SVG helpers
# --------------------------------------------------------------------
def svg(body):
	return (
		f'<svg xmlns="http://www.w3.org/2000/svg" width="{GRID:g}" height="{GRID:g}" '
		f'viewBox="0 0 {GRID:g} {GRID:g}">'
		'<defs>'
		f'<linearGradient id="k" x1="0" y1="0" x2="1" y2="1">'
		f'<stop offset="0%" stop-color="{ACCENT}"/>'
		f'<stop offset="100%" stop-color="{ACCENT2}"/>'
		'</linearGradient>'
		'<filter id="sh" x="-40%" y="-40%" width="200%" height="200%">'
		'<feDropShadow dx="0.5" dy="0.8" stdDeviation="0.6" flood-opacity="0.35"/>'
		'</filter>'
		'</defs>'
		f'{body}</svg>'
	)


def arc(cx, cy, r, deg0, deg1, color, width, cap="round"):
	x0 = cx + r * math.cos(math.radians(deg0))
	y0 = cy + r * math.sin(math.radians(deg0))
	x1 = cx + r * math.cos(math.radians(deg1))
	y1 = cy + r * math.sin(math.radians(deg1))
	large = 1 if (deg1 - deg0) % 360 > 180 else 0
	return (
		f'<path d="M{x0:.2f},{y0:.2f} A{r:g},{r:g} 0 {large} 1 {x1:.2f},{y1:.2f}" '
		f'fill="none" stroke="{color}" stroke-width="{width:g}" stroke-linecap="{cap}"/>'
	)


def stroked(d, fill=FILL, width=1.1):
	"""Filled shape + dark outline. Without the outline the cursor
	vanishes on a light background."""
	return (
		f'<path d="{d}" fill="{fill}" stroke="{OUTLINE}" stroke-width="{width:g}" '
		'stroke-linejoin="round" stroke-linecap="round"/>'
	)


# --------------------------------------------------------------------
# Shapes
# --------------------------------------------------------------------
ARROW = "M3,2 L3,18.6 L7.3,14.7 L10,20.6 L12.9,19.2 L10.2,13.5 L16,13.3 Z"
# A shrunken copy of the same shape that sits inside the arrow — the accent comes from here.
ARROW_INNER = "M4.7,5.3 L4.7,15 L7.6,12.3 L9.4,16.3 L10.7,15.7 L8.9,11.8 L12.4,11.7 Z"


def arrow(extra=""):
	return (
		'<g filter="url(#sh)">'
		+ stroked(ARROW)
		+ f'<path d="{ARROW_INNER}" fill="url(#k)"/>'
		+ '</g>'
		+ extra
	)


def badge(cx, cy, inner):
	"""Small accent badge next to the arrow (for copy/link/help)."""
	return (
		f'<g filter="url(#sh)">'
		f'<circle cx="{cx:g}" cy="{cy:g}" r="5" fill="url(#k)" '
		f'stroke="{FILL}" stroke-width="1.2"/>{inner}</g>'
	)


def ibeam():
	d = ("M9.4,3.6 h5.2 v1.5 h-1.8 v13.8 h1.8 v1.5 h-5.2 v-1.5 h1.8 "
	     "v-13.8 h-1.8 z")
	return ('<g filter="url(#sh)">' + stroked(d, FILL, 1.0)
	        + f'<rect x="11.5" y="5.1" width="1" height="13.8" fill="url(#k)"/></g>')


def vibeam():
	return f'<g transform="rotate(90 12 12)">{ibeam()}</g>'


def hand():
	d = ("M8.4,3.2 a1.65,1.65 0 0 1 3.3,0 v6.2 a1.45,1.45 0 0 1 2.7,0.7 "
	     "a1.45,1.45 0 0 1 2.5,0.9 a1.35,1.35 0 0 1 2.3,0.95 v3.3 "
	     "c0,2.7 -2,4.75 -4.8,4.75 h-2.6 c-2.3,0 -4.1,-1.3 -5,-3.3 "
	     "l-1.75,-4.1 a1.55,1.55 0 0 1 2.5,-1.75 l1.55,1.8 z")
	return ('<g filter="url(#sh)">' + stroked(d, FILL, 1.05)
	        + '<rect x="7.6" y="16.4" width="8.6" height="1.8" rx="0.9" '
	          'fill="url(#k)"/></g>')


def crosshair():
	g = ('<g stroke-linecap="round">'
	     f'<path d="M12,1.5 V9 M12,15 V22.5 M1.5,12 H9 M15,12 H22.5" '
	     f'stroke="{FILL}" stroke-width="3.4"/>'
	     f'<path d="M12,1.5 V9 M12,15 V22.5 M1.5,12 H9 M15,12 H22.5" '
	     f'stroke="{OUTLINE}" stroke-width="1.4"/>'
	     f'<circle cx="12" cy="12" r="1.5" fill="url(#k)"/>'
	     '</g>')
	return g


def _double_arrow(angle):
	"""Double-headed arrow at the given angle — the resize cursors."""
	d = ("M2.2,12 L6.4,7.8 V10.4 H17.6 V7.8 L21.8,12 L17.6,16.2 V13.6 "
	     "H6.4 V16.2 Z")
	body = ('<g filter="url(#sh)">' + stroked(d, FILL, 1.1)
	        + '<path d="M5.4,12 L7.6,9.8 V11.4 H16.4 V9.8 L18.6,12 '
	          'L16.4,14.2 V12.6 H7.6 V14.2 Z" fill="url(#k)"/></g>')
	if angle:
		return f'<g transform="rotate({angle} 12 12)">{body}</g>'
	return body


def fleur():
	d = ("M12,1.6 L15.2,5.2 H13.1 V10.9 H18.8 V8.8 L22.4,12 L18.8,15.2 "
	     "V13.1 H13.1 V18.8 H15.2 L12,22.4 L8.8,18.8 H10.9 V13.1 H5.2 "
	     "V15.2 L1.6,12 L5.2,8.8 V10.9 H10.9 V5.2 H8.8 Z")
	return ('<g filter="url(#sh)">' + stroked(d, FILL, 1.05)
	        + '<circle cx="12" cy="12" r="2.1" fill="url(#k)"/></g>')


def forbidden():
	return ('<g filter="url(#sh)">'
	        f'<circle cx="12" cy="12" r="8.6" fill="none" stroke="{FILL}" '
	        'stroke-width="4.4"/>'
	        f'<circle cx="12" cy="12" r="8.6" fill="none" stroke="{DANGER}" '
	        'stroke-width="2.8"/>'
	        f'<path d="M6.4,6.4 L17.6,17.6" stroke="{FILL}" stroke-width="4.4" '
	        'stroke-linecap="round"/>'
	        f'<path d="M6.4,6.4 L17.6,17.6" stroke="{DANGER}" stroke-width="2.8" '
	        'stroke-linecap="round"/></g>')


def spinner_frame(i, cx=12.0, cy=12.0, r=7.2, width=2.6):
	a0 = (i / ANIM_FRAMES) * 360.0
	return (
		'<g filter="url(#sh)">'
		f'<circle cx="{cx:g}" cy="{cy:g}" r="{r:g}" fill="none" '
		f'stroke="{FILL}" stroke-width="{width + 1.8:g}"/>'
		f'<circle cx="{cx:g}" cy="{cy:g}" r="{r:g}" fill="none" '
		f'stroke="{OUTLINE}" stroke-opacity="0.28" stroke-width="{width:g}"/>'
		+ arc(cx, cy, r, a0, a0 + 105, ACCENT, width)
		+ '</g>'
	)


def progress_frame(i):
	small = (
		f'<circle cx="17.5" cy="6.5" r="5" fill="none" stroke="{FILL}" '
		'stroke-width="4"/>'
		+ arc(17.5, 6.5, 5, (i / ANIM_FRAMES) * 360.0,
		      (i / ANIM_FRAMES) * 360.0 + 105, ACCENT, 2.4)
	)
	return arrow(f'<g filter="url(#sh)">{small}</g>')


def question():
	inner = (f'<path d="M17.4,15.6 c0,-1.9 2,-1.9 2,-3.3 c0,-0.9 -0.75,-1.5 '
	         f'-1.85,-1.5 c-0.95,0 -1.7,0.5 -2.05,1.2" fill="none" '
	         f'stroke="{FILL}" stroke-width="1.5" stroke-linecap="round"/>'
	         f'<circle cx="17.4" cy="18.1" r="0.95" fill="{FILL}"/>')
	return arrow(badge(17.4, 15.0, "").replace('r="5"', 'r="6.4"') + inner)


def copy_cur():
	inner = (f'<path d="M17.6,12.4 V18 M14.8,15.2 H20.4" stroke="{FILL}" '
	         'stroke-width="1.8" stroke-linecap="round"/>')
	return arrow(badge(17.6, 15.2, inner))


def link_cur():
	inner = (f'<path d="M15.4,17.4 L19.8,13" stroke="{FILL}" stroke-width="1.6" '
	         'stroke-linecap="round"/>'
	         f'<path d="M16.9,12.6 H20.2 V15.9" fill="none" stroke="{FILL}" '
	         'stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>')
	return arrow(badge(17.6, 15.2, inner))


# shape name -> (hotspot, frame list, frame delay)
SHAPES = {
	"left_ptr":        ((3, 2),   [arrow()],       0),
	"text":            ((12, 12), [ibeam()],       0),
	"vertical-text":   ((12, 12), [vibeam()],      0),
	"hand2":           ((10, 3),  [hand()],        0),
	"crosshair":       ((12, 12), [crosshair()],   0),
	"fleur":           ((12, 12), [fleur()],       0),
	"sb_h_double_arrow": ((12, 12), [_double_arrow(0)],   0),
	"sb_v_double_arrow": ((12, 12), [_double_arrow(90)],  0),
	"size_fdiag":      ((12, 12), [_double_arrow(45)],    0),
	"size_bdiag":      ((12, 12), [_double_arrow(-45)],   0),
	"X_cursor":        ((12, 12), [forbidden()],   0),
	"question_arrow":  ((3, 2),   [question()],    0),
	"copy":            ((3, 2),   [copy_cur()],    0),
	"link":            ((3, 2),   [link_cur()],    0),
	"watch":           ((12, 12), [spinner_frame(i) for i in range(ANIM_FRAMES)], ANIM_DELAY),
	"left_ptr_watch":  ((3, 2),   [progress_frame(i) for i in range(ANIM_FRAMES)], ANIM_DELAY),
}

# Applications ask for the same cursor under dozens of names. The long
# hex names here are the legacy hash values GTK/Firefox use instead of
# theme names — without them the system cursor comes back during
# drag-and-drop.
ALIASES = {
	"left_ptr": ["default", "arrow", "top_left_arrow", "left_arrow"],
	"text": ["xterm", "ibeam"],
	"hand2": ["hand", "hand1", "pointer", "pointing_hand", "grab", "grabbing",
	          "openhand", "closedhand", "dnd-move", "dnd-none",
	          "e29285e634086352946a0e7090d73106",
	          "9d800788f1b08800ae810202380a0822",
	          "5aca4d189052212118709018842178c0",
	          "208530c400c041818281048008011002"],
	"crosshair": ["cross", "tcross", "cross_reverse", "diamond_cross", "cell"],
	"fleur": ["move", "size_all", "all-scroll", "grabbing_move",
	          "4498f0e0c1937ffe01fd06f973665830",
	          "9081237383d90e509aa00f00170e968f"],
	"sb_h_double_arrow": ["h_double_arrow", "ew-resize", "col-resize",
	                      "size_hor", "split_h", "sb_left_arrow",
	                      "sb_right_arrow", "left_side", "right_side",
	                      "14fef782d02440884392942c11205230",
	                      "028006030e0e7ebffc7f7070c0600140"],
	"sb_v_double_arrow": ["v_double_arrow", "ns-resize", "row-resize",
	                      "size_ver", "split_v", "sb_up_arrow",
	                      "sb_down_arrow", "top_side", "bottom_side",
	                      "2870a09082c103050810ffdffffe0204",
	                      "00008160000006810000408080010102"],
	"size_fdiag": ["nwse-resize", "top_left_corner", "bottom_right_corner",
	               "fd_double_arrow",
	               "c7088f0f3e6c8088236ef8e1e3e70000"],
	"size_bdiag": ["nesw-resize", "top_right_corner", "bottom_left_corner",
	               "bd_double_arrow",
	               "fcf1c3c7cd4491d801f1e1c78f100000"],
	"X_cursor": ["x-cursor", "not-allowed", "no-drop", "forbidden", "circle",
	             "crossed_circle", "pirate",
	             "03b6e0fcb3499374a867c041f52298f0"],
	"question_arrow": ["help", "whats_this", "left_ptr_help", "dnd-ask",
	                   "d9ce0ab605698f320427677b458ad60b",
	                   "5c6cd98b3f3ebcb1f9c7f1c204630408"],
	"copy": ["dnd-copy",
	         "1081e37283d90000800003c07f3ef6bf",
	         "6407b0e94181790501fd1e167b474872"],
	"link": ["dnd-link", "alias",
	         "3085a0e285430894940527032f8b26df",
	         "640fb0e74195791501fd1e167b474872"],
	"watch": ["wait"],
	"left_ptr_watch": ["progress", "half-busy",
	                   "08e8e1c95fe2fc01f976f1e063a24ccd",
	                   "3ecb610c1bf2410f44200f48c40d3599"],
}


def main():
	if len(sys.argv) != 2:
		sys.exit("usage: gen-cursors.py <cursors-dir>")
	outdir = os.path.abspath(sys.argv[1])
	os.makedirs(outdir, exist_ok=True)

	with tempfile.TemporaryDirectory() as tmp:
		for name, (hot, frames, delay) in SHAPES.items():
			lines = []
			for size in SIZES:
				scale = size / GRID
				hx, hy = round(hot[0] * scale), round(hot[1] * scale)
				for idx, body in enumerate(frames):
					svgpath = os.path.join(tmp, f"{name}-{size}-{idx}.svg")
					pngpath = os.path.join(tmp, f"{name}-{size}-{idx}.png")
					with open(svgpath, "w", encoding="utf-8") as fh:
						fh.write(svg(body))
					subprocess.run(
						["rsvg-convert", "-w", str(size), "-h", str(size),
						 "-o", pngpath, svgpath],
						check=True,
					)
					line = f"{size} {hx} {hy} {pngpath}"
					if delay:
						line += f" {delay}"
					lines.append(line)

			cfg = os.path.join(tmp, f"{name}.cursor")
			with open(cfg, "w", encoding="utf-8") as fh:
				fh.write("\n".join(lines) + "\n")
			subprocess.run(
				["xcursorgen", cfg, os.path.join(outdir, name)], check=True
			)

	for target, names in ALIASES.items():
		for alias in names:
			path = os.path.join(outdir, alias)
			if os.path.lexists(path):
				os.remove(path)
			os.symlink(target, path)

	total = len(os.listdir(outdir))
	print(f"cursor theme ready: {len(SHAPES)} shapes, {total} names ({outdir})")


if __name__ == "__main__":
	main()
