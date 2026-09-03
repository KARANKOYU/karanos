#!/usr/bin/env bash
# Kavis — run the taskbar in Xvfb and save it as a PNG
#
# WHY: building an ISO and booting it in QEMU should not be the only way to
# see what the panel looks like. This script extracts the kavis-panel and
# kavis-theme .deb files into a temporary directory, starts Xvfb + Openbox,
# runs the panel and a few sample windows, and grabs the screen to a PNG.
#
# Usage:
#   tools/panel-screenshot.sh [output.png]
#   START_MENU=1 tools/panel-screenshot.sh   # with the start menu open
#
# Requirements: xvfb, openbox, xwallpaper, xdotool,
#               python3-gi, gir1.2-gtk-3.0, gir1.2-wnck-3.0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT="${1:-$REPO_ROOT/out/panel.png}"

for pkg in kavis-panel kavis-theme; do
	if ! ls out/packages/${pkg}_*.deb >/dev/null 2>&1; then
		echo "==> $pkg missing, building"
		tools/build-packages.sh "$pkg" >/dev/null
	fi
done

for cmd in Xvfb openbox xdotool /usr/bin/python3; do
	command -v "$cmd" >/dev/null || {
		echo "ERROR: $cmd is not installed" >&2
		exit 2
	}
done

ROOT=$(mktemp -d)
dpkg-deb -x "$(ls -1 out/packages/kavis-panel_*.deb | head -1)" "$ROOT"
dpkg-deb -x "$(ls -1 out/packages/kavis-theme_*_all.deb | head -1)" "$ROOT"

export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/share}"
export GTK_THEME=Kavis:dark
export XCURSOR_PATH="$ROOT/usr/share/icons"
# On a real system the logo files are under /usr/share/kavis/logo; here
# the .deb is extracted into a temporary root, so we tell the panel where.
export KAVIS_LOGO_DIR="$ROOT/usr/share/kavis/logo"

# On a real system /etc/gtk-3.0/settings.ini sets the icon theme to Kavis
# (it comes from the kavis-theme package). Here we imitate that with
# XDG_CONFIG_HOME; otherwise a generic icon appears on the start button
# instead of the K logo and the screenshot is misleading.
mkdir -p "$ROOT/config/gtk-3.0"
cp "$ROOT/etc/gtk-3.0/settings.ini" "$ROOT/config/gtk-3.0/settings.ini"
export XDG_CONFIG_HOME="$ROOT/config"

DISPLAY_NUM=98
export DISPLAY=":$DISPLAY_NUM"

Xvfb ":$DISPLAY_NUM" -screen 0 1280x800x24 >/dev/null 2>&1 &
XVFB_PID=$!
# shellcheck disable=SC2064
trap "kill $XVFB_PID 2>/dev/null || true; rm -rf '$ROOT'" EXIT

for _ in $(seq 1 40); do
	xdpyinfo >/dev/null 2>&1 && break
	sleep 0.25
done

# Start Openbox with the Kavis theme (on the ISO the 0200 hook does this)
RC="$ROOT/rc.xml"
awk '
	/<theme>/            { intheme = 1 }
	intheme && !done && /<name>/ {
		sub(/<name>[^<]*<\/name>/, "<name>Kavis</name>")
		done = 1
	}
	{ print }
' /etc/xdg/openbox/rc.xml > "$RC"
openbox --config-file "$RC" >/dev/null 2>&1 &
sleep 1

# Compositor: on the ISO picom starts from autostart; we start it here too
# so the power menu's shadow/rounded corners are drawn as they will really
# look. Otherwise the panel falls back to its "no compositing" mode.
if command -v picom >/dev/null 2>&1; then
	picom --backend xrender \
		--config "$REPO_ROOT/iso/config/includes.chroot/etc/xdg/picom-kavis.conf" \
		>"$ROOT/picom.log" 2>&1 &
	sleep 2
fi

if command -v xwallpaper >/dev/null 2>&1; then
	xwallpaper --zoom "$ROOT/usr/share/backgrounds/kavis/kavis.png" || true
fi

# Two sample windows so the window list does not look empty
/usr/bin/python3 "$REPO_ROOT/tools/sample-window.py" \
	>/dev/null 2>&1 &
SAMPLE_PID=$!

"$ROOT/usr/bin/kavis-panel" >"$ROOT/panel.log" 2>&1 &
PANEL_PID=$!

for _ in $(seq 1 40); do
	if xdotool search --name "kavis-panel" >/dev/null 2>&1; then break; fi
	if ! kill -0 "$PANEL_PID" 2>/dev/null; then
		echo "ERROR: panel exited, log:" >&2
		cat "$ROOT/panel.log" >&2
		exit 1
	fi
	sleep 0.5
done
sleep 3

# Strut check: if _NET_WM_STRUT_PARTIAL works, a maximized window stops
# above the panel instead of covering it. Maximize a window and look at
# whether the panel's spot is left alone.
if [[ "${MAXIMIZE:-0}" == "1" ]]; then
	sample_id=$(xdotool search --name "^Kavis$" | head -1 || true)
	if [[ -n "$sample_id" ]]; then
		xdotool windowactivate "$sample_id" 2>/dev/null || true
		wmctrl -i -r "$sample_id" -b add,maximized_vert,maximized_horz \
			2>/dev/null || xdotool key --window "$sample_id" super+Up 2>/dev/null || true
		sleep 2
		height=$(xdotool getdisplaygeometry | cut -d' ' -f2)
		eval "$(xdotool getwindowgeometry --shell "$sample_id")"
		bottom_edge=$(( Y + HEIGHT ))
		# The panel is 44 px; with a working strut the bottom edge of the
		# maximized window does not leave the work area. A few pixels of
		# slack for the window frame (title bar).
		limit=$(( height - 44 + 24 ))
		echo "maximized window: Y=$Y HEIGHT=$HEIGHT bottom=$bottom_edge (limit $limit)"
		if (( bottom_edge > limit )); then
			echo "ERROR: maximized window goes under the panel —" >&2
			echo "       _NET_WM_STRUT_PARTIAL is probably not set." >&2
			exit 1
		fi
		echo "strut ok: space reserved for the panel"
	fi
fi

if [[ "${START_MENU:-0}" == "1" || "${POWER:-0}" == "1" ]]; then
	# The start button is at the bottom left; click there
	height=$(xdotool getdisplaygeometry | cut -d' ' -f2)
	xdotool mousemove 40 $((height - 22)) click 1
	sleep 3
fi

# CALENDAR=1: click the clock indicator, capture with the calendar popup open (stage 4).
if [[ "${CALENDAR:-0}" == "1" ]]; then
	width=$(xdotool getdisplaygeometry | cut -d' ' -f1)
	height=$(xdotool getdisplaygeometry | cut -d' ' -f2)
	xdotool mousemove $((width - 45)) $((height - 22)) click 1
	sleep 2
fi

# QUICK=1: click the quick settings indicator (left of the clock), capture
# with the popup open. If HOLD="x y" is given, hold the mouse button down
# at that point (slider value bubble, test2 D2); released after the shot.
if [[ "${QUICK:-0}" == "1" ]]; then
	width=$(xdotool getdisplaygeometry | cut -d' ' -f1)
	height=$(xdotool getdisplaygeometry | cut -d' ' -f2)
	xdotool mousemove $((width - ${QUICK_X:-110})) $((height - 22)) click 1
	sleep 2
	if [[ -n "${HOLD:-}" ]]; then
		# shellcheck disable=SC2086
		xdotool mousemove $HOLD mousedown 1
		sleep 1
	fi
fi

# POWER=1: also press the power button in the start menu, keep the popup open.
# The power button is in the menu's bottom-left corner (menu starts at x=0).
if [[ "${POWER:-0}" == "1" ]]; then
	height=$(xdotool getdisplaygeometry | cut -d' ' -f2)
	xdotool mousemove 60 $((height - 70)) click 1
	sleep 3
fi

# CYCLES=N: open/close the start menu N times, open/close quick settings
# N times; the panel's USS (smaps_rollup Private_*) is printed before and
# after — leak scan (debug round). Informational only; no threshold.
if [[ "${CYCLES:-0}" -gt 0 ]]; then
	uss() { awk '/^Private_(Clean|Dirty)/{s+=$2} END{printf "%d", s/1024}' "/proc/$PANEL_PID/smaps_rollup"; }
	width=$(xdotool getdisplaygeometry | cut -d' ' -f1)
	height=$(xdotool getdisplaygeometry | cut -d' ' -f2)
	xdotool mousemove 40 $((height - 22)) click 1; sleep 1; xdotool key Escape; sleep 0.5
	echo "USS at start: $(uss) MB"
	for ((d = 0; d < CYCLES; d++)); do
		xdotool mousemove 40 $((height - 22)) click 1; sleep 0.25; xdotool key Escape; sleep 0.25
		xdotool mousemove $((width - ${QUICK_X:-110})) $((height - 22)) click 1; sleep 0.25; xdotool key Escape; sleep 0.25
		xdotool mousemove $((width - 45)) $((height - 22)) click 1; sleep 0.25; xdotool key Escape; sleep 0.25
	done
	sleep 2
	echo "USS after $CYCLES cycles: $(uss) MB"
fi

# SELFTEST=1: run kavis-selftest in this Xvfb session (scenarios from
# tests/ui, output in $ROOT/selftest → run.log is printed). Not a real
# session: steps specific to the live system (autologin, /users/karan)
# fail here; the point is to exercise the engine itself. Binary:
# KAVIS_SELFTEST_BIN or the deb.
if [[ "${SELFTEST:-0}" == "1" ]]; then
	BIN=${KAVIS_SELFTEST_BIN:-$ROOT/usr/bin/kavis-selftest}
	if [[ ! -x "$BIN" ]]; then
		dpkg-deb -x "$REPO_ROOT"/out/packages/kavis-selftest_*.deb "$ROOT" 2>/dev/null || true
	fi
	"$BIN" --scenarios "$REPO_ROOT/tests/ui" --dir "$ROOT/selftest" \
		${SELFTEST_ARGS:-} > "$ROOT/selftest.log" 2>&1 || true
	echo "--- selftest run.log ---"
	cat "$ROOT/selftest.log"
	if [[ -n "${SELFTEST_COPY:-}" ]]; then
		cp -r "$ROOT/selftest" "$SELFTEST_COPY"
	fi
fi

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

if [[ -n "${HOLD:-}" ]]; then
	xdotool mouseup 1
fi

if [[ -s "$ROOT/panel.log" ]]; then
	echo "--- panel log ---"
	cat "$ROOT/panel.log"
fi

kill "$PANEL_PID" "$SAMPLE_PID" 2>/dev/null || true
