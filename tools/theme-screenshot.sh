#!/usr/bin/env bash
# Kavis — render the theme in Xvfb and save it as a PNG
#
# WHY: building an ISO and booting it in QEMU should not be the only way to
# see what the theme looks like. This script extracts the kavis-theme .deb
# into a temporary directory, starts Xvfb + Openbox, draws the wallpaper
# and the theme preview window, and grabs the screen to a PNG. Takes ~10 s
# in a Codespace.
#
# Usage:
#   tools/theme-screenshot.sh [output.png]
#
# Requirements: xvfb, openbox, xwallpaper, python3-gi, gir1.2-gtk-3.0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT="${1:-$REPO_ROOT/out/theme.png}"
DEB=$(ls -1 out/packages/kavis-theme_*_all.deb 2>/dev/null | head -1 || true)

if [[ -z "$DEB" ]]; then
	echo "==> no package, building"
	tools/build-packages.sh kavis-theme >/dev/null
	DEB=$(ls -1 out/packages/kavis-theme_*_all.deb | head -1)
fi

for cmd in Xvfb openbox xwallpaper xrdb /usr/bin/python3; do
	command -v "$cmd" >/dev/null || {
		echo "ERROR: $cmd is not installed" >&2
		exit 2
	}
done

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
dpkg-deb -x "$DEB" "$ROOT"

# The theme is not installed system-wide — GTK is pointed at it through
# XDG_DATA_DIRS. That way the Codespace's own /usr is left untouched.
export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/share}"
# Kavis is single-theme: dark. The ":dark" suffix makes GTK load
# gtk-dark.css from the theme directory; gtk.css is a copy of the same
# file anyway, so the result is the same without the suffix.
export GTK_THEME=Kavis:dark
export XCURSOR_PATH="$ROOT/usr/share/icons"
export XCURSOR_THEME=Kavis-Cursors

DISPLAY_NUM=99
export DISPLAY=":$DISPLAY_NUM"

Xvfb ":$DISPLAY_NUM" -screen 0 1024x768x24 >/dev/null 2>&1 &
XVFB_PID=$!
# shellcheck disable=SC2064
trap "kill $XVFB_PID 2>/dev/null || true; rm -rf '$ROOT'" EXIT

for _ in $(seq 1 40); do
	xdpyinfo >/dev/null 2>&1 && break
	sleep 0.25
done

# Openbox's theme comes from rc.xml. On the ISO this is done by
# iso/config/hooks/normal/0200-openbox-theme.hook.chroot; here we apply
# the same transformation to a temporary copy and start with that, so the
# screenshot shows the real window frame.
RC="$ROOT/rc.xml"
awk '
	/<theme>/            { intheme = 1 }
	intheme && !done && /<name>/ {
		sub(/<name>[^<]*<\/name>/, "<name>Kavis</name>")
		done = 1
	}
	{ print }
' /etc/xdg/openbox/rc.xml > "$RC"
sed -i 's|<titleLayout>[^<]*</titleLayout>|<titleLayout>NLIMC</titleLayout>|' "$RC"
# Second pass of the hook (A1): the title font. Without it the frame is
# 4px shorter than the real one and the screenshot cannot be used to
# judge the title bar.
awk '
	/<theme>/  { intheme = 1 }
	/<\/theme>/ { intheme = 0 }
	intheme && /<font place=/ { infont = 1 }
	infont && /<\/font>/     { infont = 0 }
	infont && /<name>/   { sub(/<name>[^<]*<\/name>/,   "<name>Inter</name>") }
	infont && /<size>/   { sub(/<size>[^<]*<\/size>/,   "<size>10</size>") }
	infont && /<weight>/ { sub(/<weight>[^<]*<\/weight>/, "<weight>Normal</weight>") }
	{ print }
' "$RC" > "$RC.new"
mv "$RC.new" "$RC"

# The Xft policy the ISO ships (A1) — hinting and subpixel decide what
# the text in the screenshot looks like.
xrdb -merge "$REPO_ROOT/iso/config/includes.chroot/etc/X11/Xresources/kavis"

openbox --config-file "$RC" >/dev/null 2>&1 &
sleep 1
xwallpaper --zoom "$ROOT/usr/share/backgrounds/kavis/kavis.png" || true
/usr/bin/python3 tools/sample-window.py \
	>"$ROOT/preview.log" 2>&1 &
PREVIEW_PID=$!

# Wait for the window to be mapped. A fixed `sleep` is not enough: on a
# slow machine the frame is grabbed before the window is drawn and the
# screenshot shows only the wallpaper.
for _ in $(seq 1 40); do
	if xdotool search --name "Kavis" >/dev/null 2>&1; then break; fi
	if ! kill -0 "$PREVIEW_PID" 2>/dev/null; then
		echo "ERROR: preview window exited, log:" >&2
		cat "$ROOT/preview.log" >&2
		break
	fi
	sleep 0.5
done
sleep 2

mkdir -p "$(dirname "$OUT")"
/usr/bin/python3 - "$OUT" <<'PY'
import sys
import gi
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk

win = Gdk.get_default_root_window()
w, h = win.get_width(), win.get_height()
pb = Gdk.pixbuf_get_from_window(win, 0, 0, w, h)
pb.savev(sys.argv[1], "png", [], [])
print(f"screenshot: {sys.argv[1]} ({w}x{h})")
PY

kill "$PREVIEW_PID" 2>/dev/null || true
