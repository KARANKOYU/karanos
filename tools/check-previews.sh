#!/usr/bin/env bash
# Kavis — taskbar window previews behave (feedback 8 Sep, item 83).
#
# WHY THIS EXISTS. The previews are an override-redirect window the panel
# puts on screen by itself, and the first version of them had no reliable
# way back off: a click parks the pointer on the button it pressed, the
# previews opened four hundred milliseconds later, and nothing ever told
# them to close. One stale preview then sat over the desktop for the rest
# of the v0.5-test5 run and failed six steps in five unrelated scenarios,
# none of which had anything to do with previews. A whole ISO run to
# learn that.
#
# So both directions are checked, because either one alone is useless:
#   * they APPEAR when the pointer moves onto a taskbar button, and
#   * they are GONE when it is merely parked there after a click, when
#     it moves away, and after anything deliberate opens.
#
# Usage: tools/check-previews.sh
# Requirements: xvfb, openbox, xdotool, x11-utils, python3, xterm
# Exit: 0 = PREVIEWS-OK
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

for cmd in Xvfb openbox xdotool xwininfo /usr/bin/python3 xterm; do
	command -v "$cmd" >/dev/null || { echo "ERROR: $cmd missing" >&2; exit 2; }
done

for pkg in kavis-panel kavis-theme; do
	ls out/packages/${pkg}_*.deb >/dev/null 2>&1 || tools/build-packages.sh "$pkg" >/dev/null
done

ROOT=$(mktemp -d)
dpkg-deb -x "$(ls -1 out/packages/kavis-panel_*.deb | head -1)" "$ROOT"
dpkg-deb -x "$(ls -1 out/packages/kavis-theme_*_all.deb | head -1)" "$ROOT"

export DISPLAY=":${DISPLAY_NO:-92}"
export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/share}"
export XDG_CONFIG_HOME="$ROOT/config"
export XDG_RUNTIME_DIR="$ROOT/run"
export KAVIS_LOGO_DIR="$ROOT/usr/share/kavis/logo"
mkdir -p "$ROOT/config/kavis" "$ROOT/run"
chmod 700 "$ROOT/run"
printf '[appearance]\ntheme=dark\n' > "$ROOT/config/kavis/kavis.conf"

Xvfb "$DISPLAY" -screen 0 1280x800x24 >/dev/null 2>&1 &
XVFB_PID=$!
cleanup() {
	kill "$XVFB_PID" "${OB_PID:-}" "${PANEL_PID:-}" "${WIN_PID:-}" 2>/dev/null || true
	rm -rf "$ROOT"
}
trap cleanup EXIT
for _ in $(seq 1 40); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.25; done

openbox --config-file /etc/xdg/openbox/rc.xml >/dev/null 2>&1 &
OB_PID=$!
sleep 1
"$ROOT/usr/bin/kavis-panel" >"$ROOT/panel.log" 2>&1 &
PANEL_PID=$!
xterm -T probe -e sleep 300 >/dev/null 2>&1 &
WIN_PID=$!
sleep 5

# The taskbar is the WIDEST kavis-panel window; the small ones are helper
# windows GTK keeps around. Picking the first one found is how an earlier
# version of this check "proved" the previews never opened.
panel_id=""
best=0
for id in $(xdotool search --class kavis-panel); do
	eval "$(xdotool getwindowgeometry --shell "$id")"
	if [ "$WIDTH" -gt "$best" ]; then best=$WIDTH; panel_id=$id; fi
done
[ -n "$panel_id" ] || { echo "ERROR: the panel did not appear"; cat "$ROOT/panel.log"; exit 1; }
eval "$(xdotool getwindowgeometry --shell "$panel_id")"
MID_Y=$(( Y + HEIGHT / 2 ))
echo "panel: ${WIDTH}x${HEIGHT}+${X}+${Y}"

# Count the way the selftest runner does: override-redirect, viewable,
# at least 40x40, WM_CLASS kavis-panel.
count() {
	/usr/bin/python3 - <<'PY'
import re
import subprocess
out = subprocess.run(["xwininfo", "-root", "-children"],
                     capture_output=True, text=True).stdout
n = 0
for line in out.splitlines():
    m = re.match(r"\s+(0x[0-9a-f]+) ", line)
    if not m or "kavis-panel" not in line:
        continue
    info = subprocess.run(["xwininfo", "-id", m.group(1), "-stats"],
                          capture_output=True, text=True).stdout
    if "IsViewable" not in info:
        continue
    w = int(re.search(r"Width: (\d+)", info).group(1))
    h = int(re.search(r"Height: (\d+)", info).group(1))
    if w >= 40 and h >= 40:
        n += 1
print(n)
PY
}

fail=0
expect() { # expect <what> <wanted>
	local got
	got=$(count)
	if [ "$got" = "$2" ]; then
		printf '  \033[32m✓\033[0m %s (%s)\n' "$1" "$got"
	else
		printf '  \033[31m✗\033[0m %s — expected %s, got %s\n' "$1" "$2" "$got"
		fail=1
	fi
}

# The button of the sample window sits at the left of the window area.
BUTTON_X=120

xdotool mousemove 400 300; sleep 0.5
xdotool mousemove "$BUTTON_X" "$MID_Y"; sleep 1.6
expect "moving onto a taskbar button shows the previews" 1

xdotool mousemove 400 300; sleep 1.5
expect "moving away closes them" 0

# THE REGRESSION: a click parks the pointer on the button and never
# lifts it. Previews must not appear from a pointer that did not travel.
xdotool mousemove "$BUTTON_X" "$MID_Y" click 3; sleep 1.5
xdotool key --clearmodifiers Escape; sleep 1
expect "a right-click leaves nothing open" 0
sleep 2
expect "and still nothing two seconds later" 0

xdotool mousemove 40 "$MID_Y" click 1; sleep 1.5
expect "the Start menu opens" 1
xdotool key --clearmodifiers Escape; sleep 1.5
expect "Escape closes it" 0

[ "$fail" -eq 0 ] || { echo "PREVIEWS-FAIL"; exit 1; }
echo "PREVIEWS-OK: previews appear on a real hover and never outstay it"
