#!/usr/bin/env bash
# Kavis — test kavis-snap with a real openbox drag (Xvfb).
#
# WHY: twice snap was believed to "work in Xvfb" and then did not work in
# the VM (v0.4-test2 E1: Wnck geometry frozen during a move; debug round:
# libwnck + NorthWest gravity shifted by the frame extents). This script
# does NOT move the window with xdotool; it presses the title bar and
# drags the mouse, openbox does the move — just like a user.
#
# Usage: tools/check-snap.sh
#   KAVIS_ROOT=<dir>    extracted .deb tree instead of the installed package (local)
#   DISPLAY_NO=96       Xvfb display number
#   SNAP_PICOM=auto     run a compositor during the test, which switches
#                       kavis-snap to its ANIMATED path (C1): the window
#                       travels into the zone over 180 ms instead of
#                       jumping. Without a compositor that code never
#                       runs, so both passes are worth doing — the same
#                       four scenarios must hold either way.
# Requirements: xvfb, openbox, xdotool, x11-utils (xwininfo, xprop), xterm
# Exit: 0 = all four scenarios held (SNAP-OK), 1 = at least one did not.
set -eu

for tool in Xvfb openbox xdotool xwininfo xprop xterm; do
	command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool missing (apt: xvfb openbox xdotool x11-utils xterm)"; exit 2; }
done

ROOT=${KAVIS_ROOT:-}
SNAP=${ROOT}/usr/bin/kavis-snap
[ -x "$SNAP" ] || { echo "ERROR: kavis-snap missing: $SNAP"; exit 2; }
if [ -n "$ROOT" ]; then
	export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/share}"
fi
export DISPLAY=":${DISPLAY_NO:-96}"
TMP=$(mktemp -d)
Xvfb "$DISPLAY" -screen 0 1280x800x24 >/dev/null 2>&1 &
XVFB_PID=$!
cleanup() {
	kill "$XVFB_PID" "${SNAP_PID:-}" "${OB_PID:-}" "${WIN_PID:-}" "${PICOM_PID:-}" 2>/dev/null || true
	rm -rf "$TMP"
}
trap cleanup EXIT
for _ in $(seq 1 40); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.25; done

# Kavis theme (openbox frame is 46 px — so the extents math is real)
awk '/<theme>/{t=1} t&&!d&&/<name>/{sub(/<name>[^<]*<\/name>/,"<name>Kavis</name>");d=1}{print}' \
	/etc/xdg/openbox/rc.xml > "$TMP/rc.xml"
openbox --config-file "$TMP/rc.xml" >/dev/null 2>&1 &
OB_PID=$!
sleep 1
MODE="plain"
if [ -n "${SNAP_PICOM:-}" ]; then
	# Whatever picom is around: the system one, or the 12.5 that
	# tools/check-picom.sh caches. Only its presence matters here —
	# kavis-snap asks the X server whether anything is compositing.
	PICOM_BIN=""
	if command -v picom >/dev/null 2>&1; then
		PICOM_BIN=$(command -v picom)
	elif [ -x "${XDG_CACHE_HOME:-$HOME/.cache}/kavis-picom/root/usr/bin/picom" ]; then
		PICOM_BIN="${XDG_CACHE_HOME:-$HOME/.cache}/kavis-picom/root/usr/bin/picom"
		export LD_LIBRARY_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/kavis-picom/root/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
	fi
	if [ -z "$PICOM_BIN" ]; then
		echo "ERROR: SNAP_PICOM set but no picom found (run tools/check-picom.sh first)"; exit 2
	fi
	"$PICOM_BIN" --backend xrender >"$TMP/picom.log" 2>&1 &
	PICOM_PID=$!
	sleep 2
	MODE="composited"
fi
# After the compositor: kavis-snap reads the compositing state when a
# drag starts, but starting it second keeps the log honest about what it
# saw at boot.
KAVIS_SNAP_DEBUG=1 "$SNAP" 2>"$TMP/snap.log" &
SNAP_PID=$!
sleep 1
# -e sleep: an interactive shell rewrites the window title from
# its prompt within a second, and the search by title then
# misses — a flaky "test window did not open".
xterm -T snaptest -geometry 50x15+300+200 -e sleep 600 >"$TMP/xterm.log" 2>&1 &
WIN_PID=$!
ID=""
for _ in $(seq 1 40); do
	ID=$(xdotool search --name '^snaptest$' 2>/dev/null | head -1)
	[ -n "$ID" ] && break
	sleep 0.25
done
[ -n "$ID" ] || { echo "ERROR: test window did not open"; cat "$TMP/xterm.log"; exit 1; }

# Frame rectangle (root coordinates): client absolute position - extents
frame() {
	local ax ay w h l t r b
	read -r l r t b < <(xprop -id "$ID" _NET_FRAME_EXTENTS | sed 's/.*= //; s/,//g')
	ax=$(xwininfo -id "$ID" | sed -n 's/.*Absolute upper-left X: *//p')
	ay=$(xwininfo -id "$ID" | sed -n 's/.*Absolute upper-left Y: *//p')
	w=$(xwininfo -id "$ID" | sed -n 's/.*Width: *//p')
	h=$(xwininfo -id "$ID" | sed -n 's/.*Height: *//p')
	echo "$((ax - l)) $((ay - t)) $((w + l + r)) $((h + t + b))"
}
title_xy() { # a point on the title bar: frame x+120, frame y+20
	read -r fx fy _ _ < <(frame); echo "$((fx + 120)) $((fy + 20))"
}
drag() { # x1 y1 x2 y2 — press and hold, drag in 20 steps, release
	xdotool mousemove "$1" "$2" mousedown 1; sleep 0.2
	local i
	for i in $(seq 1 20); do
		xdotool mousemove $(( $1 + ($3 - $1) * i / 20 )) $(( $2 + ($4 - $2) * i / 20 )); sleep 0.04
	done
	sleep 0.5; xdotool mouseup 1; sleep 0.8
}
fail=0
# Tolerance: position ±4; size ±20 — xterm rounds the requested size down
# to character-cell increments (size hints) and openbox honours that.
expect() { # name x y w h
	local name=$1; read -r fx fy fw fh < <(frame)
	if [ $((fx - $2)) -le 4 ] && [ $(($2 - fx)) -le 4 ] && [ $((fy - $3)) -le 4 ] && [ $(($3 - fy)) -le 4 ] \
		&& [ $((fw - $4)) -le 20 ] && [ $(($4 - fw)) -le 20 ] && [ $((fh - $5)) -le 20 ] && [ $(($5 - fh)) -le 20 ]; then
		echo "SNAP $name: ok ($fx,$fy ${fw}x${fh})"
	else
		echo "SNAP-FAIL $name: expected $2,$3 $4x$5 — got $fx,$fy ${fw}x${fh}"
		fail=1
	fi
}
read -r _ _ W0 H0 < <(frame)
echo "mode: $MODE"
echo "initial frame: $(frame)"

read -r tx ty < <(title_xy); drag "$tx" "$ty" 1 400
expect "left edge → left half" 0 0 640 800

read -r tx ty < <(title_xy); drag "$tx" "$ty" 700 300
read -r fx fy fw fh < <(frame)
if [ "$fw" -eq "$W0" ] && [ "$fh" -eq "$H0" ]; then
	echo "SNAP original size after dragging back: ok (${fw}x${fh})"
else
	echo "SNAP-FAIL original size after dragging back: expected ${W0}x${H0} — got ${fw}x${fh}"; fail=1
fi

read -r tx ty < <(title_xy); drag "$tx" "$ty" 1279 60
expect "top-right corner → quarter" 640 0 640 400

read -r tx ty < <(title_xy); drag "$tx" "$ty" 640 1
expect "top edge → maximize" 0 0 1280 800

if [ "$fail" -ne 0 ]; then
	echo "--- kavis-snap log ---"; cat "$TMP/snap.log"
	exit 1
fi
echo "SNAP-OK: 4 scenarios held ($MODE)"
