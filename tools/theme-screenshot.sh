#!/usr/bin/env bash
# Karan OS — temayı Xvfb'de çizdirip PNG olarak kaydeder
#
# NEDEN VAR: temanın nasıl göründüğünü öğrenmenin tek yolu ISO derleyip
# QEMU'da açmak olmasın. Bu script karanos-theme .deb'ini geçici bir
# dizine açar, Xvfb + Openbox başlatır, duvar kağıdını ve tema önizleme
# penceresini çizer, ekranı PNG'ye alır. Codespace'te ~10 saniye sürüyor.
#
# Kullanım:
#   tools/theme-screenshot.sh [cikti.png]
#
# Gereksinimler: xvfb, openbox, xwallpaper, python3-gi, gir1.2-gtk-3.0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT="${1:-$REPO_ROOT/out/tema.png}"
DEB=$(ls -1 out/packages/karanos-theme_*_all.deb 2>/dev/null | head -1 || true)

if [[ -z "$DEB" ]]; then
	echo "==> paket yok, derleniyor"
	tools/build-packages.sh karanos-theme >/dev/null
	DEB=$(ls -1 out/packages/karanos-theme_*_all.deb | head -1)
fi

for cmd in Xvfb openbox xwallpaper /usr/bin/python3; do
	command -v "$cmd" >/dev/null || {
		echo "HATA: $cmd kurulu degil" >&2
		exit 2
	}
done

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
dpkg-deb -x "$DEB" "$ROOT"

# Temayı sisteme kurmuyoruz — GTK'ya XDG_DATA_DIRS ile gösteriyoruz.
# Böylece Codespace'in kendi /usr'ı ellenmiyor.
export XDG_DATA_DIRS="$ROOT/usr/share:${XDG_DATA_DIRS:-/usr/share}"
# Karan OS tek temali: koyu. ":dark" soneki GTK'ya tema dizinindeki
# gtk-dark.css'i yukletiyor; zaten gtk.css de ayni dosyanin kopyasi,
# yani sonek olmasa da sonuc degismez.
export GTK_THEME=Karan:dark
export XCURSOR_PATH="$ROOT/usr/share/icons"
export XCURSOR_THEME=Karan-Cursors

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

# Openbox'ın teması rc.xml'den geliyor. ISO'da bunu
# iso/config/hooks/normal/0200-openbox-theme.hook.chroot yapıyor;
# burada aynı dönüşümü geçici bir kopyaya uygulayıp öyle başlatıyoruz ki
# ekran görüntüsünde gerçek pencere çerçevesi görünsün.
RC="$ROOT/rc.xml"
awk '
	/<theme>/            { intheme = 1 }
	intheme && !done && /<name>/ {
		sub(/<name>[^<]*<\/name>/, "<name>Karan</name>")
		done = 1
	}
	{ print }
' /etc/xdg/openbox/rc.xml > "$RC"
sed -i 's|<titleLayout>[^<]*</titleLayout>|<titleLayout>NLIMC</titleLayout>|' "$RC"

openbox --config-file "$RC" >/dev/null 2>&1 &
sleep 1
xwallpaper --zoom "$ROOT/usr/share/backgrounds/karanos/karan.png" || true
/usr/bin/python3 tools/ornek-pencere.py \
	>"$ROOT/preview.log" 2>&1 &
PREVIEW_PID=$!

# Pencerenin haritalanmasini bekle. Sabit bir `sleep` yeterli degil:
# yavas makinede kare pencere cizilmeden aliniyor ve ekran goruntusunde
# yalnizca duvar kagidi cikiyor.
for _ in $(seq 1 40); do
	if xdotool search --name "Karan OS" >/dev/null 2>&1; then break; fi
	if ! kill -0 "$PREVIEW_PID" 2>/dev/null; then
		echo "HATA: onizleme penceresi cikti, gunluk:" >&2
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
print(f"ekran goruntusu: {sys.argv[1]} ({w}x{h})")
PY

kill "$PREVIEW_PID" 2>/dev/null || true
