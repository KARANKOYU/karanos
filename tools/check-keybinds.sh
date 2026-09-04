#!/usr/bin/env bash
# Kavis — rc.xml keybind check (v0.4-test1 C4): KEYBIND-OK/FAIL table
#
# What it does: applies the 0210 hook to the stock openbox rc.xml (the
# real result on the ISO), starts openbox with that rc in Xvfb, presses
# every Kavis shortcut with xdotool and verifies within 2 s that the
# expected action happened:
#   - window actions (Win+arrow, Win+D): xprop/xdotool geometry
#   - Execute bindings: stub commands on PATH (gdbus, nemo, kavis-*)
#     log that they were called — NO panel/app is required.
# So the test answers "is the shortcut bound in openbox and does it call
# the right command"; the app itself is the job of other tests.
#
# Usage: tools/check-keybinds.sh [stock-rc.xml]   (default /etc/xdg/openbox/rc.xml)
# Env:   KAVIS_WINDOW_CMD — test window command (default xterm)
#        DISPLAY_NO — Xvfb display number (default 77)
# Exit code: 1 if any FAIL. A Markdown table goes to stdout and, if set,
# to $GITHUB_STEP_SUMMARY.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

STOCK=${1:-/etc/xdg/openbox/rc.xml}
DISPLAY_NO=${DISPLAY_NO:-77}
WINDOW_CMD=${KAVIS_WINDOW_CMD:-xterm}
HOOK=iso/config/hooks/normal/0210-openbox-keybinds.hook.chroot

# ALL required tools are checked at once; the missing ones on one line
# (so CI does not fail one by one — v0.4-test2 red: xprop was missing).
# Debian packages: xvfb, openbox, xdotool, x11-utils (xprop), xterm.
missing=""
for tool in Xvfb openbox xdotool xprop "${WINDOW_CMD%% *}" sed awk; do
	command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
	echo "ERROR: missing tools:$missing (apt: xvfb openbox xdotool x11-utils xterm)" >&2
	exit 2
fi
[ -f "$STOCK" ] || { echo "ERROR: $STOCK missing" >&2; exit 2; }

T=$(mktemp -d)
LOG="$T/calls.log"
trap 'kill $WIN_PID $OB_PID $XV_PID 2>/dev/null; rm -rf "$T"' EXIT
WIN_PID=; OB_PID=; XV_PID=

# --- rc.xml: stock + hook (exactly the same operation as on the ISO) ---
cp "$STOCK" "$T/rc.xml"
# The hook edits $RC in place, so the copy points at the temp file; the
# host guard is dropped with it, because every path this harness touches
# is already redirected into $T (the guard exists to stop an UNMODIFIED
# hook from running on a developer machine).
sed -e "s|^RC=/etc/xdg/openbox/rc.xml|RC=$T/rc.xml|" \
    -e '/--- Host guard/,/^fi$/d' "$HOOK" > "$T/hook.sh"
sh "$T/hook.sh" >/dev/null || { echo "ERROR: 0210 hook failed" >&2; exit 2; }

# --- stub commands ----------------------------------------------------
mkdir -p "$T/bin"
for cmd in gdbus nemo kavis-settings kavis-tools kavis-taskmanager kavis-lock; do
	cat > "$T/bin/$cmd" <<EOS
#!/bin/sh
echo "$cmd \$*" >> "$LOG"
EOS
	chmod +x "$T/bin/$cmd"
done

# --- X + openbox -------------------------------------------------------
export DISPLAY=":$DISPLAY_NO"
Xvfb "$DISPLAY" -screen 0 1280x800x24 >/dev/null 2>&1 &
XV_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[ -S "/tmp/.X11-unix/X$DISPLAY_NO" ] && break; sleep 0.5
done
PATH="$T/bin:$PATH" HOME="$T" openbox --config-file "$T/rc.xml" >/dev/null 2>&1 &
OB_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
	xprop -root _OB_VERSION 2>/dev/null | grep -q "3\." && break; sleep 0.5
done
xprop -root _OB_VERSION 2>/dev/null | grep -q "3\." || { echo "ERROR: openbox did not start" >&2; exit 2; }

$WINDOW_CMD >/dev/null 2>&1 &
WIN_PID=$!
WIN=
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
	WIN=$(xdotool search --onlyvisible --pid "$WIN_PID" 2>/dev/null | head -1)
	[ -n "$WIN" ] && break; sleep 0.5
done
[ -n "$WIN" ] || { echo "ERROR: test window did not open ($WINDOW_CMD)" >&2; exit 2; }
xdotool windowsize "$WIN" 500 400; xdotool windowmove "$WIN" 300 200
xdotool windowactivate --sync "$WIN" 2>/dev/null; sleep 0.5

# shellcheck disable=SC2034  # used by the conditions inside eval
SCREEN_W=1280
fail=0
rows=()

wait_for () {   # wait_for <shell-condition> — up to 2 s in 100 ms steps
	for _ in $(seq 1 20); do
		if eval "$1"; then return 0; fi
		sleep 0.1
	done
	return 1
}
geom_x () { xdotool getwindowgeometry "$WIN" | sed -n 's/.*Position: \([0-9-]*\),.*/\1/p'; }
geom_w () { xdotool getwindowgeometry "$WIN" | sed -n 's/.*Geometry: \([0-9]*\)x.*/\1/p'; }
state_has () { xprop -id "$WIN" _NET_WM_STATE 2>/dev/null | grep -q "$1"; }
log_has () { grep -q -- "$1" "$LOG" 2>/dev/null; }

check () {   # check <name> <xdotool key> <condition>
	local name=$1 key=$2 cond=$3
	: > "$LOG"
	xdotool key --clearmodifiers "$key"
	if wait_for "$cond"; then
		rows+=("| $name | \`$key\` | OK |")
		echo "KEYBIND-OK $name"
	else
		rows+=("| $name | \`$key\` | **FAIL** |")
		echo "KEYBIND-FAIL $name ($key)"
		fail=1
	fi
}

# --- window actions ---------------------------------------------------
check "Win+Left → left half"   super+Left  '[ "$(geom_x)" -le 2 ] && [ "$(geom_w)" -ge $((SCREEN_W/2 - 20)) ]'
check "Win+Right → right half" super+Right '[ "$(geom_x)" -ge $((SCREEN_W/2 - 5)) ]'
check "Win+Up → maximize"      super+Up    'state_has MAXIMIZED_VERT'
check "Win+Down → restore"     super+Down  '! state_has MAXIMIZED_VERT'
check "Win+Down → minimize"    super+Down  'state_has HIDDEN'
xdotool windowactivate --sync "$WIN" 2>/dev/null; sleep 0.3
check "Win+D → show desktop"   super+d 'xprop -root _NET_SHOWING_DESKTOP | grep -q "= 1"'
xdotool key --clearmodifiers super+d; sleep 0.3

# --- Execute bindings (stub log) ---------------------------------------
check "Win → start menu (XF86Launch5/xcape)" XF86Launch5 'log_has "ShowStartMenu false"'
check "Ctrl+Esc → start menu"   ctrl+Escape 'log_has "ShowStartMenu false"'
check "Win+R → start + search"  super+r     'log_has "ShowStartMenu true"'
check "Win+E → Files"           super+e     'log_has "^nemo"'
check "Win+I → Settings"        super+i     'log_has "^kavis-settings"'
check "Win+Tab → overview"      super+Tab   'log_has ShowOverview'
check "Win+Z → snap menu"       super+z     'log_has ShowSnapMenu'
check "Win+V → clipboard"       super+v     'log_has ShowClipboard'
check "Win+. → emoji"           super+period 'log_has ShowPicker'
check "Win+Shift+S → capture"   super+shift+s 'log_has "kavis-tools capture$"'
check "Win+Shift+C → color"     super+shift+c 'log_has "capture --color"'
check "PrtSc → capture"         Print       'log_has "kavis-tools capture$"'
check "Ctrl+PrtSc → quick"      ctrl+Print  'log_has "capture --quick"'
check "Alt+F4 → kavis-tools alt-f4" alt+F4  'log_has "alt-f4"'
check "Ctrl+Alt+Del → security" ctrl+alt+Delete 'log_has "secure-menu"'
check "Ctrl+Shift+Esc → task manager" ctrl+shift+Escape 'log_has "^kavis-taskmanager"'
check "Win+1 → slot 1"          super+1     'log_has "ActivateSlot 1 false"'
check "Win+Shift+1 → slot 1 new" super+shift+1 'log_has "ActivateSlot 1 true"'
check "Volume+ → OSD"           XF86AudioRaiseVolume 'log_has VolumeUp'
check "Brightness+ → OSD"       XF86MonBrightnessUp  'log_has BrightnessUp'
check "Win+L → lock screen"     super+l     'log_has "^kavis-lock"'

# --- table -------------------------------------------------------------
{
	echo "### KEYBIND (rc.xml + 0210 hook, Xvfb)"
	echo ""
	echo "| Shortcut | Key | Result |"
	echo "|---|---|---|"
	printf '%s\n' "${rows[@]}"
	echo ""
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [ "$fail" -ne 0 ]; then
	echo "KEYBIND-FAIL: at least one shortcut did not perform the expected action" >&2
	exit 1
fi
echo "KEYBIND-OK: all ${#rows[@]} shortcuts worked"
