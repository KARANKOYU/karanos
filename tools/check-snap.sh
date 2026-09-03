#!/usr/bin/env bash
# Kavis — kavis-snap'in gerçek openbox sürüklemesiyle sınanması (Xvfb).
#
# NEDEN VAR: snap iki kez "Xvfb'de çalışıyor" sanılıp VM'de çalışmadı
# (v0.4-test2 E1: Wnck geometrisi taşıma sırasında donuk; debug turu:
# libwnck + NorthWest gravity çerçeve payı kadar kaydırıyordu). Bu betik
# pencereyi xdotool ile TAŞIMAZ; başlık çubuğuna basıp fareyi sürükler,
# taşımayı openbox yapar — tıpkı kullanıcı gibi.
#
# Kullanım: tools/check-snap.sh
#   KAVIS_ROOT=<dizin>  kurulu paket yerine açılmış .deb ağacı (yerel)
#   DISPLAY_NO=96       Xvfb ekran numarası
# Gereksinimler: xvfb, openbox, xdotool, x11-utils (xwininfo, xprop), xterm
# Çıkış: 0 = dört senaryo da tuttu (SNAP-OK), 1 = en az biri tutmadı.
set -eu

for arac in Xvfb openbox xdotool xwininfo xprop xterm; do
	command -v "$arac" >/dev/null 2>&1 || { echo "HATA: $arac yok (apt: xvfb openbox xdotool x11-utils xterm)"; exit 2; }
done

ROOT=${KAVIS_ROOT:-}
SNAP=${ROOT}/usr/bin/kavis-snap
[ -x "$SNAP" ] || { echo "HATA: kavis-snap yok: $SNAP"; exit 2; }
if [ -n "$ROOT" ]; then
	export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/share}"
fi
export DISPLAY=":${DISPLAY_NO:-96}"
TMP=$(mktemp -d)
Xvfb "$DISPLAY" -screen 0 1280x800x24 >/dev/null 2>&1 &
XVFB_PID=$!
cleanup() {
	kill "$XVFB_PID" "${SNAP_PID:-}" "${OB_PID:-}" "${WIN_PID:-}" 2>/dev/null || true
	rm -rf "$TMP"
}
trap cleanup EXIT
for _ in $(seq 1 40); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.25; done

# Kavis teması (openbox çerçevesi 46 px — pay hesabı gerçek olsun)
awk '/<theme>/{t=1} t&&!d&&/<name>/{sub(/<name>[^<]*<\/name>/,"<name>Kavis</name>");d=1}{print}' \
	/etc/xdg/openbox/rc.xml > "$TMP/rc.xml"
openbox --config-file "$TMP/rc.xml" >/dev/null 2>&1 &
OB_PID=$!
sleep 1
KAVIS_SNAP_DEBUG=1 "$SNAP" 2>"$TMP/snap.log" &
SNAP_PID=$!
sleep 1
xterm -T snaptest -geometry 50x15+300+200 >"$TMP/xterm.log" 2>&1 &
WIN_PID=$!
ID=""
for _ in $(seq 1 40); do
	ID=$(xdotool search --name '^snaptest$' 2>/dev/null | head -1)
	[ -n "$ID" ] && break
	sleep 0.25
done
[ -n "$ID" ] || { echo "HATA: test penceresi açılmadı"; cat "$TMP/xterm.log"; exit 1; }

# Çerçeve dikdörtgeni (kök koordinatları): istemci mutlak konumu - pay
frame() {
	local ax ay w h l t r b
	read -r l r t b < <(xprop -id "$ID" _NET_FRAME_EXTENTS | sed 's/.*= //; s/,//g')
	ax=$(xwininfo -id "$ID" | sed -n 's/.*Absolute upper-left X: *//p')
	ay=$(xwininfo -id "$ID" | sed -n 's/.*Absolute upper-left Y: *//p')
	w=$(xwininfo -id "$ID" | sed -n 's/.*Width: *//p')
	h=$(xwininfo -id "$ID" | sed -n 's/.*Height: *//p')
	echo "$((ax - l)) $((ay - t)) $((w + l + r)) $((h + t + b))"
}
title_xy() { # başlık çubuğunda bir nokta: çerçeve x+120, çerçeve y+20
	read -r fx fy _ _ < <(frame); echo "$((fx + 120)) $((fy + 20))"
}
drag() { # x1 y1 x2 y2 — basılı tut, 20 adımda sürükle, bırak
	xdotool mousemove "$1" "$2" mousedown 1; sleep 0.2
	local i
	for i in $(seq 1 20); do
		xdotool mousemove $(( $1 + ($3 - $1) * i / 20 )) $(( $2 + ($4 - $2) * i / 20 )); sleep 0.04
	done
	sleep 0.5; xdotool mouseup 1; sleep 0.8
}
hata=0
# Tolerans: konum ±4; boyut ±20 — xterm karakter hücresi artımlarıyla
# (size hints) istenen boyutu aşağı yuvarlar, openbox buna uyar.
bekle() { # ad x y w h
	local ad=$1; read -r fx fy fw fh < <(frame)
	if [ $((fx - $2)) -le 4 ] && [ $(($2 - fx)) -le 4 ] && [ $((fy - $3)) -le 4 ] && [ $(($3 - fy)) -le 4 ] \
		&& [ $((fw - $4)) -le 20 ] && [ $(($4 - fw)) -le 20 ] && [ $((fh - $5)) -le 20 ] && [ $(($5 - fh)) -le 20 ]; then
		echo "SNAP $ad: tamam ($fx,$fy ${fw}x${fh})"
	else
		echo "SNAP-FAIL $ad: beklenen $2,$3 $4x$5 — olan $fx,$fy ${fw}x${fh}"
		hata=1
	fi
}
read -r _ _ W0 H0 < <(frame)
echo "baslangic cerceve: $(frame)"

read -r tx ty < <(title_xy); drag "$tx" "$ty" 1 400
bekle "sol kenar → sol yarı" 0 0 640 800

read -r tx ty < <(title_xy); drag "$tx" "$ty" 700 300
read -r fx fy fw fh < <(frame)
if [ "$fw" -eq "$W0" ] && [ "$fh" -eq "$H0" ]; then
	echo "SNAP geri çekince eski boyut: tamam (${fw}x${fh})"
else
	echo "SNAP-FAIL geri çekince eski boyut: beklenen ${W0}x${H0} — olan ${fw}x${fh}"; hata=1
fi

read -r tx ty < <(title_xy); drag "$tx" "$ty" 1279 60
bekle "sağ üst köşe → çeyrek" 640 0 640 400

read -r tx ty < <(title_xy); drag "$tx" "$ty" 640 1
bekle "üst kenar → büyütme" 0 0 1280 800

if [ "$hata" -ne 0 ]; then
	echo "--- kavis-snap günlüğü ---"; cat "$TMP/snap.log"
	exit 1
fi
echo "SNAP-OK: 4 senaryo tuttu"
