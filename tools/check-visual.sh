#!/usr/bin/env bash
# Kavis — visual quality gate (feedback A5).
#
# WHY: "the text is pixelated" and "some corners are sharp" were both
# true in v0.4-test4, and nothing in CI could have caught either. Both
# are measurable, so they are measured here:
#
#   FONT   — what fontconfig actually resolves for the generic families,
#            and the rendering policy that comes with it. The A1 round
#            found that <alias><prefer> in local.conf loses to Debian's
#            own 60-latin.conf and DejaVu kept winning; this check is
#            what proved it.
#   DPI    — Xft.dpi as the session sets it, and the three places that
#            must agree on the UI font (Xresources, settings.ini,
#            xsettingsd defaults).
#   CORNER — the radius picom actually draws, read off a screenshot of
#            a real window under a real picom.
#
# Usage: tools/check-visual.sh
#   DISPLAY_NO=93   Xvfb display number
# Requirements: xvfb, openbox, xterm, xdotool, x11-utils, xrdb, fontconfig,
#               python3-pil, and picom 12+ (system, or fetched by
#               tools/check-picom.sh into its cache)
# Exit: 0 = VISUAL-OK, 1 = at least one measurement is off.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

XRES="iso/config/includes.chroot/etc/X11/Xresources/kavis"
FONTCONF="iso/config/includes.chroot/etc/fonts/local.conf"
SETTINGS_INI="packages/kavis-theme/src/settings.ini"
AUTOSTART="iso/config/includes.chroot/etc/xdg/openbox/autostart"
PICOM_CONF="iso/config/includes.chroot/etc/xdg/picom-kavis.conf"
UI_FONT="Inter"
UI_SIZE="10"

for tool in Xvfb openbox xterm xdotool xwininfo xrdb fc-match /usr/bin/python3; do
	command -v "$tool" >/dev/null 2>&1 || {
		echo "ERROR: $tool missing" >&2
		exit 2
	}
done

fail=0
note() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=1; }

echo "==> FONT — what fontconfig resolves"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"; kill ${XVFB_PID:-} ${OB_PID:-} ${PICOM_PID:-} ${WIN_PID:-} 2>/dev/null || true' EXIT
# The shipped policy on top of the host's own configuration — exactly
# how it is layered on the ISO.
cat > "$TMP/fonts.conf" <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <include>/etc/fonts/fonts.conf</include>
  <include>$REPO_ROOT/$FONTCONF</include>
</fontconfig>
XML
export FONTCONFIG_FILE="$TMP/fonts.conf"

resolved=$(fc-match --format '%{family}' sans-serif)
if [[ "$resolved" == "$UI_FONT"* ]]; then
	note "sans-serif resolves to $resolved"
else
	bad "sans-serif resolves to '$resolved', expected $UI_FONT"
fi
for generic in sans system-ui; do
	got=$(fc-match --format '%{family}' "$generic")
	[[ "$got" == "$UI_FONT"* ]] && note "$generic resolves to $got" \
		|| bad "$generic resolves to '$got', expected $UI_FONT"
done

# hintstyle 1 = hintslight, rgba 1 = rgb, lcdfilter 1 = default.
read -r hint rgba aa lcd <<<"$(fc-match --format '%{hintstyle} %{rgba} %{antialias} %{lcdfilter}' sans-serif)"
[[ "$hint" == "1" ]] && note "hintstyle = slight" \
	|| bad "hintstyle = $hint, expected 1 (slight); full hinting is what made the text look pixelated"
[[ "$rgba" == "1" ]] && note "subpixel order = rgb" || bad "rgba = $rgba, expected 1 (rgb)"
[[ "$aa" == "True" ]] && note "antialias on" || bad "antialias = $aa"
[[ "$lcd" == "1" ]] && note "lcdfilter = default" || bad "lcdfilter = $lcd, expected 1"

echo
echo "==> DPI and the font name, in every place that carries it"
dpi=$(sed -n 's/^Xft\.dpi:[[:space:]]*//p' "$XRES")
[[ "$dpi" == "96" ]] && note "Xresources Xft.dpi = 96" || bad "Xresources Xft.dpi = '$dpi'"
for res in "Xft.antialias:  1" "Xft.hinting:    1" "Xft.hintstyle:  hintslight" "Xft.rgba:       rgb"; do
	grep -qF "$res" "$XRES" && note "Xresources $res" || bad "Xresources missing: $res"
done
grep -qF "gtk-font-name=$UI_FONT $UI_SIZE" "$SETTINGS_INI" \
	&& note "settings.ini gtk-font-name = $UI_FONT $UI_SIZE" \
	|| bad "settings.ini does not carry '$UI_FONT $UI_SIZE'"
grep -qF "Gtk/FontName \"$UI_FONT $UI_SIZE\"" "$AUTOSTART" \
	&& note "xsettingsd default Gtk/FontName = $UI_FONT $UI_SIZE" \
	|| bad "the xsettingsd defaults in the autostart do not carry '$UI_FONT $UI_SIZE'"
# 96 dpi in XSETTINGS units (×1024) — the two must not drift apart.
grep -qF "Xft/DPI $((96 * 1024))" "$AUTOSTART" \
	&& note "xsettingsd default Xft/DPI = $((96 * 1024)) (96 dpi)" \
	|| bad "the xsettingsd Xft/DPI default does not match ${dpi} dpi"

echo
echo "==> CORNER — the radius picom draws on a real window"
PICOM=""
if command -v picom >/dev/null 2>&1 \
	&& [[ "$(picom --version 2>/dev/null | tr -d 'v' | cut -d. -f1)" =~ ^1[2-9]|^[2-9][0-9] ]]; then
	PICOM=$(command -v picom)
elif [[ -x "${XDG_CACHE_HOME:-$HOME/.cache}/kavis-picom/root/usr/bin/picom" ]]; then
	PICOM="${XDG_CACHE_HOME:-$HOME/.cache}/kavis-picom/root/usr/bin/picom"
	export LD_LIBRARY_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/kavis-picom/root/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
fi
if [[ -z "$PICOM" ]]; then
	echo "  · no picom 12+ available — run tools/check-picom.sh first to cache one"
else
	expect=$(sed -n 's/^corner-radius = \([0-9]*\);.*/\1/p' "$PICOM_CONF")
	export DISPLAY=":${DISPLAY_NO:-93}"
	Xvfb "$DISPLAY" -screen 0 1024x768x24 >/dev/null 2>&1 &
	XVFB_PID=$!
	for _ in $(seq 1 40); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.25; done
	# A background nothing in the theme uses, so "not the background" is
	# unambiguous for the pixel reader.
	xsetroot -solid '#FF00FF'
	openbox >/dev/null 2>&1 &
	OB_PID=$!
	sleep 1
	"$PICOM" --backend xrender --config "$PICOM_CONF" >"$TMP/picom.log" 2>&1 &
	PICOM_PID=$!
	sleep 2
	# -e sleep: the shell would rename the window from its prompt
	xterm -T cornertest -geometry 40x12+200+150 -e sleep 600 >/dev/null 2>&1 &
	WIN_PID=$!
	ID=""
	for _ in $(seq 1 40); do
		# `|| true`: with pipefail a search that finds nothing would
		# end the script instead of retrying.
		ID=$(xdotool search --name '^cornertest$' 2>/dev/null | head -1 || true)
		# `[[ ... ]] && break` would end the script under `set -e` on
		# the first miss — an if, deliberately.
		if [[ -n "$ID" ]]; then break; fi
		sleep 0.25
	done
	if [[ -z "$ID" ]]; then
		bad "test window did not open"
	else
		sleep 1.5
		read -r l _ t _ < <(xprop -id "$ID" _NET_FRAME_EXTENTS | sed 's/.*= //; s/,//g')
		ax=$(xwininfo -id "$ID" | sed -n 's/.*Absolute upper-left X: *//p')
		ay=$(xwininfo -id "$ID" | sed -n 's/.*Absolute upper-left Y: *//p')
		/usr/bin/python3 - "$TMP/corner.png" <<'PY'
import sys
import gi
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk
win = Gdk.get_default_root_window()
pb = Gdk.pixbuf_get_from_window(win, 0, 0, win.get_width(), win.get_height())
pb.savev(sys.argv[1], "png", [], [])
PY
		if /usr/bin/python3 tools/corner-radius.py "$TMP/corner.png" \
				"$((ax - l))" "$((ay - t))" --expect "$expect" --tolerance 1; then
			note "window corner radius matches picom's corner-radius = $expect"
		else
			bad "window corner radius does not match corner-radius = $expect"
		fi
	fi
fi

echo
if [[ $fail -eq 0 ]]; then
	echo "VISUAL-OK: font, DPI and corner radius are what the design language says"
else
	echo "VISUAL-FAIL: see above"
fi
exit $fail
