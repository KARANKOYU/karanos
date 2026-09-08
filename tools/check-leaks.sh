#!/usr/bin/env bash
# Kavis — the long-running parts do not grow (feedback, 8 Sep 2026).
#
# A leak is invisible to every other check here: a panel that gains 200
# KB per hover passes check-previews forty times a day and is 100 MB
# heavier by Friday. So this does the thing a person does over a week,
# in a minute — the same action many times — and reads private memory
# (USS, from smaps_rollup: the pages this process alone would give back)
# before and after. Growth between the two rounds is the finding; a
# little on the first round is the process warming its caches and is
# not.
#
#   panel        forty preview hovers, forty Start menu open/close
#   kavis-share  thirty file transfers between two instances
#
# The bar is deliberately loose (a few MB over forty rounds): GLib slab
# allocators and font caches settle rather than free, and a check that
# cries wolf at 300 KB is a check people learn to ignore.
#
# Usage: tools/check-leaks.sh
# Exit: 0 = LEAKS-OK
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

for cmd in Xvfb openbox xdotool xterm dbus-launch; do
	command -v "$cmd" >/dev/null || { echo "ERROR: $cmd missing" >&2; exit 2; }
done
for pkg in kavis-panel kavis-theme kavis-share; do
	ls out/packages/${pkg}_*.deb >/dev/null 2>&1 || tools/build-packages.sh "$pkg" >/dev/null
done

T=$(mktemp -d)
ROOT="$T/root"
for pkg in kavis-panel kavis-theme kavis-share; do
	dpkg-deb -x "$(ls -1 out/packages/${pkg}_*.deb | head -1)" "$ROOT"
done
PIDS=()
cleanup() { kill "${PIDS[@]}" 2>/dev/null || true; rm -rf "$T"; }
trap cleanup EXIT

uss_kb() { awk '/^Private_(Clean|Dirty):/ { s += $2 } END { print s + 0 }' "/proc/$1/smaps_rollup" 2>/dev/null; }
fail=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=1; }

# Growth in the SECOND half of the run is what counts: the first half is
# allowed to warm caches.
judge() { # <name> <kb-after-first-half> <kb-after-second-half> <allowed-kb>
	local grew=$(( $3 - $2 ))
	if [ "$grew" -le "$4" ]; then
		ok "$1: $(( $2 / 1024 )) MB → $(( $3 / 1024 )) MB over the second half (+${grew} KB)"
	else
		bad "$1 grew ${grew} KB over the second half — that is a leak, not a cache"
	fi
}

# ---- the panel ------------------------------------------------------
export DISPLAY=":${DISPLAY_NO:-90}"
export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/share}"
export XDG_CONFIG_HOME="$T/config" XDG_RUNTIME_DIR="$T/run"
mkdir -p "$T/config/kavis" "$T/run"; chmod 700 "$T/run"
printf '[appearance]\ntheme=dark\n' > "$T/config/kavis/kavis.conf"
Xvfb "$DISPLAY" -screen 0 1280x800x24 >/dev/null 2>&1 & PIDS+=("$!")
for _ in $(seq 1 40); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.25; done
openbox --config-file /etc/xdg/openbox/rc.xml >/dev/null 2>&1 & PIDS+=("$!")
sleep 1
"$ROOT/usr/bin/kavis-panel" >"$T/panel.log" 2>&1 & PANEL=$!; PIDS+=("$PANEL")
xterm -T probe -e sleep 600 >/dev/null 2>&1 & PIDS+=("$!")
sleep 5

panel_id=""; best=0
for id in $(xdotool search --class kavis-panel); do
	eval "$(xdotool getwindowgeometry --shell "$id")"
	[ "$WIDTH" -gt "$best" ] && { best=$WIDTH; panel_id=$id; }
done
eval "$(xdotool getwindowgeometry --shell "$panel_id")"
MID_Y=$(( Y + HEIGHT / 2 ))

hover_round() {
	xdotool mousemove 400 300; sleep 0.3
	xdotool mousemove 120 "$MID_Y"; sleep 0.8
	xdotool mousemove 400 300; sleep 0.6
}
start_round() {
	xdotool mousemove 40 "$MID_Y" click 1; sleep 0.5
	xdotool key --clearmodifiers Escape; sleep 0.4
}
for _ in $(seq 1 20); do hover_round; start_round; done
P1=$(uss_kb $PANEL)
for _ in $(seq 1 20); do hover_round; start_round; done
P2=$(uss_kb $PANEL)
judge "kavis-panel after 40 hovers and 40 Start menus" "$P1" "$P2" 3072

# ---- kavis-share ----------------------------------------------------
SHARE="$ROOT/usr/bin/kavis-share"
peer() { # <dir> <name> <vis> <port> <bus>
	local d="$1"
	mkdir -p "$d/config/kavis" "$d/data/kavis" "$d/home/downloads" "$d/run"; chmod 700 "$d/run"
	printf '[share]\nname=%s\nvisibility=%s\nport=%s\n' "$2" "$3" "$4" > "$d/config/kavis/kavis.conf"
	env XDG_CONFIG_HOME="$d/config" XDG_DATA_HOME="$d/data" HOME="$d/home" \
	    XDG_RUNTIME_DIR="$d/run" DBUS_SESSION_BUS_ADDRESS="$5" \
		"$SHARE" --daemon > "$d/log" 2>&1 &
	echo $!
}
eval "$(dbus-launch --sh-syntax)"; A_BUS="$DBUS_SESSION_BUS_ADDRESS"; PIDS+=("$DBUS_SESSION_BUS_PID")
eval "$(dbus-launch --sh-syntax)"; B_BUS="$DBUS_SESSION_BUS_ADDRESS"; PIDS+=("$DBUS_SESSION_BUS_PID")
A=$(peer "$T/a" leak-a everyone 53317 "$A_BUS"); PIDS+=("$A")
sleep 2
FP_A=$(sed -n 's/^fingerprint=//p' "$T/a/config/kavis/kavis.conf")
printf '%s leak-a\n' "$FP_A" > "$T/b/data/kavis/trusted-devices" 2>/dev/null || { mkdir -p "$T/b/data/kavis"; printf '%s leak-a\n' "$FP_A" > "$T/b/data/kavis/trusted-devices"; }
B=$(peer "$T/b" leak-b trusted 53318 "$B_BUS"); PIDS+=("$B")
sleep 6
head -c 300000 /dev/urandom > "$T/a/home/blob.bin"
send() {
	env XDG_CONFIG_HOME="$T/a/config" XDG_DATA_HOME="$T/a/data" HOME="$T/a/home" \
	    XDG_RUNTIME_DIR="$T/a/run" DBUS_SESSION_BUS_ADDRESS="$A_BUS" \
		"$SHARE" --send "$T/a/home/blob.bin" --to leak-b >/dev/null 2>&1
}
for _ in $(seq 1 15); do send; done
RA1=$(uss_kb $A); RB1=$(uss_kb $B)
for _ in $(seq 1 15); do send; done
RA2=$(uss_kb $A); RB2=$(uss_kb $B)
judge "kavis-share sender after 30 transfers" "$RA1" "$RA2" 2048
judge "kavis-share receiver after 30 transfers" "$RB1" "$RB2" 2048
landed=$(find "$T/b/home/downloads/kavis-share" -name 'blob*' | wc -l)
[ "$landed" -eq 30 ] && ok "all 30 files landed, none overwrote another" \
	|| bad "expected 30 files on the receiver, found $landed"

[ "$fail" -eq 0 ] || { echo "LEAKS-FAIL"; exit 1; }
echo "LEAKS-OK: the panel and the share daemon do the same thing forty times without growing"
