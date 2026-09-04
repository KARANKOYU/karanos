#!/usr/bin/env python3
"""Measure the corner radius of a window in a screenshot (A5).

The compositor rounds window corners, and "some corners are sharp" was a
real v0.4-test4 finding that nothing in CI could see. Given the top-left
corner of a window frame, this reports the radius drawn there.

How it works:

  * a pixel counts as window if it differs AT ALL from the screen
    background. The arc is antialiased and its outermost pixels are only
    faintly covered; a "closer to the window than to the background"
    rule drops them and reports a radius about 4px too small. This only
    works because the caller paints the root a colour nothing else uses.
  * on each row of the corner the first window pixel gives a staircase,
    and the radius is whichever value reproduces it best:

        offset(y) = ceil(r - sqrt(r^2 - (r - y - 0.5)^2) - 0.5)

    (pixel centres at +0.5; a pixel counts once its centre is inside the
    circle). Reading the first row's offset as "the radius" would be
    wrong — for r=8 that row starts at 5, and the whole staircase
    [5,3,2,1,1,0] is what identifies it.

Usage: corner-radius.py <png> <x> <y> [--expect N] [--tolerance N]
  x, y   top-left corner of the window FRAME in screen coordinates
Exit: 0 = within tolerance (or no --expect given), 1 = not.
"""
import math
import sys

from PIL import Image

BOX = 24          # how far into the corner we look
EDGE = 24         # colour distance that still counts as background


def distance(a, b):
    return sum(abs(x - y) for x, y in zip(a[:3], b[:3]))


def model(radius, y):
    """The offset an ideal quarter circle of this radius would give."""
    if y >= radius:
        return 0
    dy = radius - y - 0.5
    return max(0, math.ceil(radius - math.sqrt(radius ** 2 - dy ** 2) - 0.5))


def measure(path, ox, oy):
    im = Image.open(path).convert("RGB")
    # Sampled on the diagonal outside the corner, where neither edge of
    # the window can reach even with the largest radius we allow.
    bg = im.getpixel((ox - 3, oy - 3))

    def is_window(x, y):
        return distance(im.getpixel((x, y)), bg) > EDGE

    if is_window(ox - 2, oy - 2):
        raise SystemExit("ERROR: the point given is not a window corner — "
                         "the pixel outside it is not background")
    rows = []
    for dy in range(BOX):
        first = BOX
        for dx in range(BOX):
            if is_window(ox + dx, oy + dy):
                first = dx
                break
        rows.append(first)
    best, best_error = 0, None
    for radius in range(0, BOX):
        error = sum((model(radius, y) - rows[y]) ** 2 for y in range(BOX))
        if best_error is None or error < best_error:
            best, best_error = radius, error
    return best, rows


def main(argv):
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    path, ox, oy = argv[0], int(argv[1]), int(argv[2])
    expect = tolerance = None
    if "--expect" in argv:
        expect = int(argv[argv.index("--expect") + 1])
    if "--tolerance" in argv:
        tolerance = int(argv[argv.index("--tolerance") + 1])
    radius, rows = measure(path, ox, oy)
    print(f"corner radius: {radius}px  (row offsets: {rows[:10]})")
    if expect is None:
        return 0
    tolerance = 1 if tolerance is None else tolerance
    if abs(radius - expect) > tolerance:
        print(f"ERROR: expected {expect}px ±{tolerance}, measured {radius}px",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
