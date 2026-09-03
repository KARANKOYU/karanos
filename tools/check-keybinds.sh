#!/usr/bin/env bash
# Kavis — rc.xml kısayol denetimi (v0.4-test1 C4): KEYBIND-OK/FAIL tablosu
#
# Ne yapar: stok openbox rc.xml'ine 0210 hook'unu uygular (ISO'daki
# gerçek sonuç), Xvfb'de openbox'ı bu rc ile başlatır, her Kavis
# kısayolunu xdotool ile basar ve 2 sn içinde beklenen eylemin
# gerçekleştiğini doğrular:
#   - pencere eylemleri (Win+ok, Win+D): xprop/xdotool geometrisi
#   - Execute bağları: PATH'te saplama komutlar (gdbus, nemo, kavis-*)
#     çağrıldıklarını bir günlüğe yazar — panel/uygulama GEREKMEZ.
# Bu yüzden test "kısayol openbox'ta bağlı ve doğru komutu çağırıyor"
# sorusunu cevaplar; uygulamanın kendisi ayrı testlerin işi.
#
# Kullanım: tools/check-keybinds.sh [stok-rc.xml]   (vars. /etc/xdg/openbox/rc.xml)
# Ortam:    KAVIS_WINDOW_CMD — test penceresi komutu (vars. xterm)
#           DISPLAY_NO — Xvfb ekran numarası (vars. 77)
# Çıkış kodu: FAIL varsa 1. Markdown tablo stdout'a ve varsa
# $GITHUB_STEP_SUMMARY'ye yazılır.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

STOCK=${1:-/etc/xdg/openbox/rc.xml}
DISPLAY_NO=${DISPLAY_NO:-77}
WINDOW_CMD=${KAVIS_WINDOW_CMD:-xterm}
HOOK=iso/config/hooks/normal/0210-openbox-kisayollar.hook.chroot

# Gereken araçların HEPSİ tek seferde denetlenir; eksikler tek satırda
# (CI'da teker teker düşmesin — v0.4-test2 kırmızısı: xprop yoktu).
# Debian paketleri: xvfb, openbox, xdotool, x11-utils (xprop), xterm.
eksik=""
for tool in Xvfb openbox xdotool xprop "${WINDOW_CMD%% *}" sed awk; do
	command -v "$tool" >/dev/null 2>&1 || eksik="$eksik $tool"
done
if [ -n "$eksik" ]; then
	echo "HATA: eksik araçlar:$eksik (apt: xvfb openbox xdotool x11-utils xterm)" >&2
	exit 2
fi
[ -f "$STOCK" ] || { echo "HATA: $STOCK yok" >&2; exit 2; }

T=$(mktemp -d)
LOG="$T/calls.log"
trap 'kill $WIN_PID $OB_PID $XV_PID 2>/dev/null; rm -rf "$T"' EXIT
WIN_PID=; OB_PID=; XV_PID=

# --- rc.xml: stok + hook (ISO ile birebir aynı işlem) ----------------
cp "$STOCK" "$T/rc.xml"
sed -e "s|^RC=/etc/xdg/openbox/rc.xml|RC=$T/rc.xml|" "$HOOK" > "$T/hook.sh"
sh "$T/hook.sh" >/dev/null || { echo "HATA: 0210 hook'u başarısız" >&2; exit 2; }

# --- saplama komutlar -------------------------------------------------
mkdir -p "$T/bin"
for cmd in gdbus nemo kavis-settings kavis-tools; do
	cat > "$T/bin/$cmd" <<EOF
#!/bin/sh
echo "$cmd \$*" >> "$LOG"
EOF
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
xprop -root _OB_VERSION 2>/dev/null | grep -q "3\." || { echo "HATA: openbox başlamadı" >&2; exit 2; }

$WINDOW_CMD >/dev/null 2>&1 &
WIN_PID=$!
WIN=
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
	WIN=$(xdotool search --onlyvisible --pid "$WIN_PID" 2>/dev/null | head -1)
	[ -n "$WIN" ] && break; sleep 0.5
done
[ -n "$WIN" ] || { echo "HATA: test penceresi açılmadı ($WINDOW_CMD)" >&2; exit 2; }
xdotool windowsize "$WIN" 500 400; xdotool windowmove "$WIN" 300 200
xdotool windowactivate --sync "$WIN" 2>/dev/null; sleep 0.5

# shellcheck disable=SC2034  # eval içindeki koşullar kullanıyor
SCREEN_W=1280
fail=0
rows=()

wait_for () {   # wait_for <shell-condition> — 2 sn'ye kadar 100 ms adım
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

check () {   # check <ad> <xdotool tuş> <koşul>
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

# --- pencere eylemleri ------------------------------------------------
check "Win+Sol → sol yarı"  super+Left  '[ "$(geom_x)" -le 2 ] && [ "$(geom_w)" -ge $((SCREEN_W/2 - 20)) ]'
check "Win+Sağ → sağ yarı"  super+Right '[ "$(geom_x)" -ge $((SCREEN_W/2 - 5)) ]'
check "Win+Yukarı → büyüt"  super+Up    'state_has MAXIMIZED_VERT'
check "Win+Aşağı → geri yükle" super+Down '! state_has MAXIMIZED_VERT'
check "Win+Aşağı → simge durumu" super+Down 'state_has HIDDEN'
xdotool windowactivate --sync "$WIN" 2>/dev/null; sleep 0.3
check "Win+D → masaüstünü göster" super+d 'xprop -root _NET_SHOWING_DESKTOP | grep -q "= 1"'
xdotool key --clearmodifiers super+d; sleep 0.3

# --- Execute bağları (saplama günlüğü) ---------------------------------
check "Win → başlat menüsü (XF86Launch5/xcape)" XF86Launch5 'log_has "ShowStartMenu false"'
check "Ctrl+Esc → başlat menüsü" ctrl+Escape 'log_has "ShowStartMenu false"'
check "Win+R → başlat + arama"  super+r     'log_has "ShowStartMenu true"'
check "Win+E → Dosyalar"        super+e     'log_has "^nemo"'
check "Win+I → Ayarlar"         super+i     'log_has "^kavis-settings"'
check "Win+Tab → genel bakış"   super+Tab   'log_has ShowOverview'
check "Win+Z → snap menüsü"     super+z     'log_has ShowSnapMenu'
check "Win+V → pano"            super+v     'log_has ShowClipboard'
check "Win+. → emoji"           super+period 'log_has ShowPicker'
check "Win+Shift+S → yakalama"  super+shift+s 'log_has "kavis-tools capture$"'
check "Win+Shift+C → renk"      super+shift+c 'log_has "capture --color"'
check "PrtSc → yakalama"        Print       'log_has "kavis-tools capture$"'
check "Ctrl+PrtSc → hızlı"      ctrl+Print  'log_has "capture --quick"'
check "Alt+F4 → kavis-tools alt-f4" alt+F4  'log_has "alt-f4"'
check "Ctrl+Alt+Del → güvenlik" ctrl+alt+Delete 'log_has "secure-menu"'
check "Win+1 → yuva 1"          super+1     'log_has "ActivateSlot 1 false"'
check "Win+Shift+1 → yuva 1 yeni" super+shift+1 'log_has "ActivateSlot 1 true"'
check "Ses+ → OSD"              XF86AudioRaiseVolume 'log_has VolumeUp'
check "Parlaklık+ → OSD"        XF86MonBrightnessUp  'log_has BrightnessUp'

# --- tablo -------------------------------------------------------------
{
	echo "### KEYBIND (rc.xml + 0210 hook, Xvfb)"
	echo ""
	echo "| Kısayol | Tuş | Sonuç |"
	echo "|---|---|---|"
	printf '%s\n' "${rows[@]}"
	echo ""
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [ "$fail" -ne 0 ]; then
	echo "KEYBIND-FAIL: en az bir kısayol beklenen eylemi yapmadı" >&2
	exit 1
fi
echo "KEYBIND-OK: ${#rows[@]} kısayolun hepsi çalıştı"
