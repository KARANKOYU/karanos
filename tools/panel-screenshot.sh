#!/usr/bin/env bash
# Kavis — görev çubuğunu Xvfb'de çalıştırıp PNG olarak kaydeder
#
# NEDEN VAR: panelin nasıl göründüğünü öğrenmenin tek yolu ISO derleyip
# QEMU'da açmak olmasın. Bu script kavis-panel ve kavis-theme
# .deb'lerini geçici bir dizine açar, Xvfb + Openbox başlatır, paneli
# ve birkaç örnek pencereyi çalıştırıp ekranı PNG'ye alır.
#
# Kullanım:
#   tools/panel-screenshot.sh [cikti.png]
#   MENU=1 tools/panel-screenshot.sh   # başlat menüsü açık hâlde
#
# Gereksinimler: xvfb, openbox, xwallpaper, xdotool,
#                python3-gi, gir1.2-gtk-3.0, gir1.2-wnck-3.0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT="${1:-$REPO_ROOT/out/panel.png}"

for pkg in kavis-panel kavis-theme; do
	if ! ls out/packages/${pkg}_*.deb >/dev/null 2>&1; then
		echo "==> $pkg yok, derleniyor"
		tools/build-packages.sh "$pkg" >/dev/null
	fi
done

for cmd in Xvfb openbox xdotool /usr/bin/python3; do
	command -v "$cmd" >/dev/null || {
		echo "HATA: $cmd kurulu degil" >&2
		exit 2
	}
done

ROOT=$(mktemp -d)
dpkg-deb -x "$(ls -1 out/packages/kavis-panel_*.deb | head -1)" "$ROOT"
dpkg-deb -x "$(ls -1 out/packages/kavis-theme_*_all.deb | head -1)" "$ROOT"

export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/share}"
export GTK_THEME=Kavis:dark
export XCURSOR_PATH="$ROOT/usr/share/icons"
# Logo dosyaları gerçek sistemde /usr/share/kavis/logo altında; burada
# .deb geçici köke açıldığı için panele yerini söylüyoruz.
export KAVIS_LOGO_DIZIN="$ROOT/usr/share/kavis/logo"

# Gercek sistemde /etc/gtk-3.0/settings.ini simge temasini Kavis yapiyor
# (kavis-theme paketinden geliyor). Burada onu XDG_CONFIG_HOME ile
# taklit ediyoruz; olmazsa baslat dugmesinde K logosu yerine genel bir
# simge cikiyor ve ekran goruntusu yaniltici oluyor.
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

# Openbox'ı Kavis temasıyla başlat (ISO'da bunu 0200 hook'u yapıyor)
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

# Kompozitor: ISO'da picom autostart'tan basliyor, burada da baslatiyoruz
# ki guc menusunun golgesi/yuvarlak kosesi gercekte nasil gorunecekse
# oyle cizilsin. Yoksa panel "bilesikleme yok" moduna dusuyor.
if command -v picom >/dev/null 2>&1; then
	picom --backend xrender \
		--config "$REPO_ROOT/iso/config/includes.chroot/etc/xdg/picom-kavis.conf" \
		>"$ROOT/picom.log" 2>&1 &
	sleep 2
fi

if command -v xwallpaper >/dev/null 2>&1; then
	xwallpaper --zoom "$ROOT/usr/share/backgrounds/kavis/kavis.png" || true
fi

# Pencere listesinin boş görünmemesi için iki örnek pencere
/usr/bin/python3 "$REPO_ROOT/tools/ornek-pencere.py" \
	>/dev/null 2>&1 &
ORNEK_PID=$!

"$ROOT/usr/bin/kavis-panel" >"$ROOT/panel.log" 2>&1 &
PANEL_PID=$!

for _ in $(seq 1 40); do
	if xdotool search --name "kavis-panel" >/dev/null 2>&1; then break; fi
	if ! kill -0 "$PANEL_PID" 2>/dev/null; then
		echo "HATA: panel cikti, gunluk:" >&2
		cat "$ROOT/panel.log" >&2
		exit 1
	fi
	sleep 0.5
done
sleep 3

# Strut denetimi: _NET_WM_STRUT_PARTIAL calisiyorsa buyutulen pencere
# panelin ustunde durur, altini kaplamaz. Pencereyi buyutup panelin
# yerinde olup olmadigina bakiyoruz.
if [[ "${BUYUT:-0}" == "1" ]]; then
	ornek_id=$(xdotool search --name "^Kavis$" | head -1 || true)
	if [[ -n "$ornek_id" ]]; then
		xdotool windowactivate "$ornek_id" 2>/dev/null || true
		wmctrl -i -r "$ornek_id" -b add,maximized_vert,maximized_horz \
			2>/dev/null || xdotool key --window "$ornek_id" super+Up 2>/dev/null || true
		sleep 2
		yukseklik=$(xdotool getdisplaygeometry | cut -d' ' -f2)
		eval "$(xdotool getwindowgeometry --shell "$ornek_id")"
		alt_kenar=$(( Y + HEIGHT ))
		# Panel 44 piksel; strut calisiyorsa buyutulen pencerenin alt
		# kenari calisma alaninin disina tasmaz. Pencere cercevesi
		# (baslik cubugu) icin birkac piksel pay birakiyoruz.
		sinir=$(( yukseklik - 44 + 24 ))
		echo "buyutulmus pencere: Y=$Y HEIGHT=$HEIGHT alt=$alt_kenar (sinir $sinir)"
		if (( alt_kenar > sinir )); then
			echo "HATA: buyutulen pencere panelin altina giriyor —" >&2
			echo "      _NET_WM_STRUT_PARTIAL yazilmamis olmali." >&2
			exit 1
		fi
		echo "strut tamam: panel icin yer ayrilmis"
	fi
fi

if [[ "${MENU:-0}" == "1" || "${GUC:-0}" == "1" ]]; then
	# Başlat düğmesi sol altta; oraya tıkla
	yukseklik=$(xdotool getdisplaygeometry | cut -d' ' -f2)
	xdotool mousemove 40 $((yukseklik - 22)) click 1
	sleep 3
fi

# POPUP=1: saat gostergesine tikla, takvim popup'i acik hâlde cek (Asama 4).
if [[ "${POPUP:-0}" == "1" ]]; then
	genislik=$(xdotool getdisplaygeometry | cut -d' ' -f1)
	yukseklik=$(xdotool getdisplaygeometry | cut -d' ' -f2)
	xdotool mousemove $((genislik - 45)) $((yukseklik - 22)) click 1
	sleep 2
fi

# HIZLI=1: hızlı ayarlar göstergesine (saatin solu) tıkla, popup açık
# hâlde çek. BASILI="x y" verilirse o noktada fareyi basılı tut (kaydırıcı
# değer balonu, test2 D2); ekran görüntüsünden sonra bırakılır.
if [[ "${HIZLI:-0}" == "1" ]]; then
	genislik=$(xdotool getdisplaygeometry | cut -d' ' -f1)
	yukseklik=$(xdotool getdisplaygeometry | cut -d' ' -f2)
	xdotool mousemove $((genislik - ${HIZLI_X:-110})) $((yukseklik - 22)) click 1
	sleep 2
	if [[ -n "${BASILI:-}" ]]; then
		# shellcheck disable=SC2086
		xdotool mousemove $BASILI mousedown 1
		sleep 1
	fi
fi

# GUC=1: baslat menusundeki guc dugmesine de bas, popup acik kalsin.
# Guc dugmesi menunun sol alt kosesinde (menu x=0'dan basliyor).
if [[ "${GUC:-0}" == "1" ]]; then
	yukseklik=$(xdotool getdisplaygeometry | cut -d' ' -f2)
	xdotool mousemove 60 $((yukseklik - 70)) click 1
	sleep 3
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
print(f"ekran goruntusu: {sys.argv[1]} ({w}x{h})")
PY

if [[ -n "${BASILI:-}" ]]; then
	xdotool mouseup 1
fi

if [[ -s "$ROOT/panel.log" ]]; then
	echo "--- panel gunlugu ---"
	cat "$ROOT/panel.log"
fi

kill "$PANEL_PID" "$ORNEK_PID" 2>/dev/null || true
