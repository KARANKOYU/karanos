#!/usr/bin/env python3
"""Splash spinner frames (v0.4-test1 G): 8 SVG frames, 48x48, 8 teal
dots on a ring with a trailing fade; each frame rotates the bright
dot one step. rules converts them to PNG; kavis.script scales to 12 px
and cycles them next to "Starting…" so the user never thinks the
screen froze. No cairo dependency — plain SVG text."""
import math
import sys
from pathlib import Path

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
SIZE, R, DOT = 48, 17, 4.2
for frame in range(8):
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">']
    for i in range(8):
        # the bright dot rotates with the frame; the ones behind it fade
        age = (i - frame) % 8
        opacity = 1.0 - age * 0.11
        a = math.radians(i * 45 - 90)
        cx = SIZE / 2 + R * math.cos(a)
        cy = SIZE / 2 + R * math.sin(a)
        parts.append(f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{DOT}" fill="#2DD4BF" fill-opacity="{opacity:.2f}"/>')
    parts.append("</svg>")
    (out / f"spinner-{frame}.svg").write_text("\n".join(parts) + "\n")
print(f"{out}: 8 frames")
