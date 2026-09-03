#!/usr/bin/env bash
# Kavis — ISO duman testi (QEMU)
#
# Kullanım:  tools/qemu-smoke-test.sh <iso-dosyasi> [bios|uefi|secureboot]
#
# ISO'yu QEMU'da açar, seri konsolu dinler ve /usr/lib/kavis/boot-check
# script'inin yazdığı "KAVIS-CHECK: RESULT=OK" satırını bekler.
#
# Bu test GitHub Actions'ta çalışır. Yerelde de çalışır ama Codespaces'te
# KVM olmadığı için yavaştır (yazılım öykünmesi). Amaç her değişiklikte
# ISO'yu indirip elle açmak zorunda kalmamak; elle test (VirtualBox, USB)
# bunun yerine değil, üstüne yapılır.

set -euo pipefail

ISO="${1:?kullanim: $0 <iso-dosyasi> [bios|uefi|secureboot]}"
MODE="${2:-bios}"
TIMEOUT="${TIMEOUT:-900}"

# Çok-mimarili hazırlık: bu test qemu-system-x86_64 + OVMF'e yazıldı.
# arm64 desteği istendiğinde qemu-system-aarch64 + AAVMF yolu eklenecek;
# o güne kadar başka mimaride sessizce (hata vermeden) atlanır.
MIMARI="${KAVIS_MIMARI:-amd64}"
if [[ "$MIMARI" != "amd64" ]]; then
	echo "NOT: duman testi yalnız amd64 için var; $MIMARI atlandı."
	exit 0
fi

[[ -f "$ISO" ]] || { echo "HATA: ISO bulunamadi: $ISO" >&2; exit 2; }

# Donanım profili (madde 46A): CI farklı RAM/çekirdek/ekran kartı
# bileşimlerini aynı scriptle dener. Varsayılanlar eski davranışla aynı.
RAM_MB="${RAM_MB:-2560}"
CPUS="${CPUS:-2}"
VGA="${VGA:-std}"

WORKDIR="$(mktemp -d)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
trap 'rm -rf "$WORKDIR"' EXIT
SERIAL="$WORKDIR/serial.log"
MONITOR="$WORKDIR/monitor.sock"
: > "$SERIAL"

# QEMU'nun ekranini PNG olarak disari al.
# Bir daha GRUB menusunde takilirsak seri gunlukte hicbir sey olmaz ama
# ekran goruntusunde ne oldugu net gorunur. Ilk CI koşusunda tam olarak bu
# sorunu yasadik ve gormek icin ISO'yu elle indirmek zorunda kaldik.
snapshot() {
	local label="$1"
	local ppm="$WORKDIR/screen-$label.ppm"
	[[ -S "$MONITOR" ]] || return 0
	printf 'screendump %s\n' "$ppm" | nc -U -q 2 "$MONITOR" >/dev/null 2>&1 || return 0
	sleep 1
	[[ -s "$ppm" ]] || return 0
	python3 - "$ppm" "${SCREENSHOT_DIR:-$PWD}/screen-$MODE-$label.png" <<'PY' || true
import sys, zlib, struct
src, dst = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
if d[:2] != b'P6':
    sys.exit(0)
# P6\n<w> <h>\n255\n
parts, idx = [], 2
while len(parts) < 3:
    while d[idx:idx+1].isspace():
        idx += 1
    if d[idx:idx+1] == b'#':
        while d[idx:idx+1] != b'\n':
            idx += 1
        continue
    start = idx
    while not d[idx:idx+1].isspace():
        idx += 1
    parts.append(int(d[start:idx]))
idx += 1
w, h = parts[0], parts[1]
raw = d[idx:idx + w*h*3]
rows = b''.join(b'\x00' + raw[y*w*3:(y+1)*w*3] for y in range(h))
def chunk(t, data):
    c = t + data
    return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c))
png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(rows, 6))
       + chunk(b'IEND', b''))
open(dst, 'wb').write(png)
print(f"    ekran goruntusu: {dst} ({w}x{h})")
PY
}

OVMF_DIR="/usr/share/OVMF"

# Asagidaki virguller QEMU parametrelerinin parcasi (audiodev=snd0 gibi),
# dizi ayraci degil.
# shellcheck disable=SC2054
qemu_args=(
	-name "kavis-smoke-$MODE"
	-cpu max
	-smp "$CPUS"
	-m "$RAM_MB"
	-cdrom "$ISO"
	-boot d
	-display none
	-vga "$VGA"
	-serial "file:$SERIAL"
	-monitor "unix:$MONITOR,server,nowait"
	-no-reboot
	-rtc base=utc
	-net none
	# Ses karti: 3. asamadaki acilis muzigi gercek bir ALSA aygiti
	# ariyor. Backend "none" — ses hicbir yere gitmiyor ama aplay
	# gercek zamanda calisiyor, yani splash'in muzik boyunca acik
	# kalmasi da test edilmis oluyor.
	-audiodev none,id=snd0
	-device intel-hda
	-device hda-duplex,audiodev=snd0
)

case "$MODE" in
bios)
	qemu_args+=(-machine q35)
	;;
uefi)
	[[ -f "$OVMF_DIR/OVMF_CODE_4M.fd" ]] || { echo "HATA: ovmf paketi kurulu degil" >&2; exit 2; }
	cp "$OVMF_DIR/OVMF_VARS_4M.fd" "$WORKDIR/vars.fd"
	qemu_args+=(
		-machine q35
		-drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_DIR/OVMF_CODE_4M.fd"
		-drive "if=pflash,format=raw,unit=1,file=$WORKDIR/vars.fd"
	)
	;;
secureboot)
	[[ -f "$OVMF_DIR/OVMF_CODE_4M.secboot.fd" ]] || { echo "HATA: ovmf secboot dosyasi yok" >&2; exit 2; }
	cp "$OVMF_DIR/OVMF_VARS_4M.ms.fd" "$WORKDIR/vars.fd"
	# Asagidaki virguller QEMU parametresinin parcasi, dizi ayraci degil.
	# shellcheck disable=SC2054
	qemu_args+=(
		-machine "q35,smm=on"
		-global driver=cfi.pflash01,property=secure,value=on
		-global ICH9-LPC.disable_s3=1
		-drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_DIR/OVMF_CODE_4M.secboot.fd"
		-drive "if=pflash,format=raw,unit=1,file=$WORKDIR/vars.fd"
	)
	;;
*)
	echo "HATA: bilinmeyen mod '$MODE' (bios|uefi|secureboot)" >&2
	exit 2
	;;
esac

# KVM varsa kullan (gercek donanimda hizli), yoksa yazilim oykunmesi
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
	qemu_args+=(-enable-kvm)
	echo ">> KVM kullaniliyor"
else
	echo ">> KVM yok, yazilim oykunmesi (yavas) — timeout ${TIMEOUT}s"
fi

echo ">> Mod: $MODE (RAM=${RAM_MB}MB CPU=$CPUS VGA=$VGA)"
echo ">> ISO: $ISO ($(du -h "$ISO" | cut -f1))"

qemu-system-x86_64 "${qemu_args[@]}" &
QEMU_PID=$!
# shellcheck disable=SC2064
trap "kill $QEMU_PID 2>/dev/null || true; rm -rf '$WORKDIR'" EXIT

result=""
elapsed=0
desktop_shot=0
kernel_seen=0
kernel_seen_at=0
splash_shot=0
stuck_reported=0
while (( elapsed < TIMEOUT )); do
	if ! kill -0 "$QEMU_PID" 2>/dev/null; then
		echo ">> QEMU beklenmedik sekilde kapandi (${elapsed}s)"
		break
	fi
	# Masaustu karesi: boot-check panel + nemo-desktop pencerelerinin
	# GORUNUR oldugunu (DESKTOP-READY) soyleyince +2 sn bekleyip alinir
	# (v0.4-test2 A: 12 sn'lik sabit bekleme yavas profillerde erkendi).
	if (( desktop_shot == 0 )) && grep -q "KAVIS-CHECK: DESKTOP-READY" "$SERIAL" 2>/dev/null; then
		desktop_shot=1
		echo ">> DESKTOP-READY goruldu (${elapsed}s), 2 sn sonra masaustu karesi"
		sleep 2
		snapshot "masaustu"
	fi
	if grep -q "KAVIS-CHECK: RESULT=OK" "$SERIAL" 2>/dev/null; then
		result="OK"
		break
	fi
	if grep -q "KAVIS-CHECK: RESULT=FAIL" "$SERIAL" 2>/dev/null; then
		result="FAIL"
		break
	fi
	if grep -qi "Kernel panic" "$SERIAL" 2>/dev/null; then
		result="PANIC"
		break
	fi

	# Cekirdek basladi mi?
	# 3. asamada `quiet` eklendi ve "Linux version" satiri seri konsolda
	# gorunmuyor. Bu yuzden cekirdegin ya da systemd'nin herhangi bir
	# yasam belirtisine bakiyoruz — amac "onyukleyicide mi takildik"
	# sorusunu ayirt etmek.
	if (( kernel_seen == 0 )) && grep -qE "Linux version|systemd\[1\]|Welcome to|KAVIS-CHECK|Reached target" "$SERIAL" 2>/dev/null; then
		kernel_seen=1
		kernel_seen_at=$elapsed
		echo ">> cekirdek basladi (${elapsed}s)"
	fi

	# Acilis ekrani karesi: Plymouth splash yalnizca acilis sirasinda
	# ekranda. Duman testinin sonundaki kareler alindiginda splash coktan
	# kapanmis oluyor, yani 3. asamanin ciktisi hic gorulemiyor.
	# plymouth-x11 Debian'da olmadigi icin yerelde de cizdiremiyoruz;
	# splash'i gormenin tek yolu bu erken kare.
	# Splash'in ekranda oldugu araligi (profil hizina gore ~10-55 sn)
	# tek kareyle tutturmak sansa kaliyordu (v0.2-test3: bes profilin
	# hicbirinde kare splash'e denk gelmedi). Uc kare aliyoruz.
	if (( kernel_seen == 1 && splash_shot == 0 && elapsed >= kernel_seen_at + 10 )); then
		splash_shot=1
		echo ">> acilis ekrani karesi 1/3 (${elapsed}s)"
		snapshot "acilis-1"
	fi
	if (( kernel_seen == 1 && splash_shot == 1 && elapsed >= kernel_seen_at + 25 )); then
		splash_shot=2
		echo ">> acilis ekrani karesi 2/3 (${elapsed}s)"
		snapshot "acilis-2"
	fi
	if (( kernel_seen == 1 && splash_shot == 2 && elapsed >= kernel_seen_at + 40 )); then
		splash_shot=3
		echo ">> acilis ekrani karesi 3/3 (${elapsed}s)"
		snapshot "acilis-3"
	fi

	# 240 saniyede cekirdek hala baslamadiysa onyukleyicide takiliyiz.
	# Zaman asimini beklemeden ekran goruntusunu al ve durumu yaz.
	if (( kernel_seen == 0 && elapsed >= 240 && stuck_reported == 0 )); then
		stuck_reported=1
		echo ">> UYARI: ${elapsed}s gecti, cekirdek hic baslamadi."
		echo ">> Muhtemelen onyukleyici menusunde tus bekleniyor. Ekran:"
		snapshot "takildi"
	fi

	sleep 5
	elapsed=$((elapsed + 5))
	if (( elapsed % 60 == 0 )); then
		echo ">> ${elapsed}s… (seri gunlugu $(wc -l < "$SERIAL") satir)"
	fi
done

# Masaustu karesi: boot-check "RESULT=OK" derken Xorg ve openbox ayakta
# ama autostart'taki duvar kagidi ve pencereler henuz cizilmemis olabilir.
# Birkac saniye bekleyip alinan kare, temanin nasil gorundugunu ISO'yu
# indirmeden gostermenin en hizli yolu.
if [[ "$result" == "OK" ]]; then
	# Karar DESKTOP-READY'ye bagli (boot-check icinde: 60 sn'de
	# haritalanmazsa PANEL-NOT-MAPPED → RESULT=FAIL). Buradaki olcutler
	# yalniz GUNLUK: ortalama parlaklik, tekil renk sayisi, saat bolgesi.
	#  - screen-not-blank: <24 renk VE sapma <3 → bos (koyu masaustu
	#    ~2000 renk, sapma ~11.5)
	#  - screen-clock-visible: alt 44 satir x sag ceyrekte >=15 parlak
	#    piksel (cizilmis panel ~440)
	ppm="$WORKDIR/screen-masaustu.ppm"
	if [[ ! -s "$ppm" ]]; then
		echo "!! DESKTOP-READY karesi yok (satir gec geldi?) — simdi aliniyor"
		snapshot "masaustu"
	fi
	if [[ -s "$ppm" ]]; then
		python3 "$REPO_ROOT/tools/screen-not-blank.py" "$ppm" \
			|| echo "::warning::Masaustu karesi bos olcutune takildi ($MODE) — DESKTOP-READY geldigi icin test dusurulmedi"
		python3 "$REPO_ROOT/tools/screen-clock-visible.py" "$ppm" \
			|| echo "::warning::Saat bolgesi bos olcutune takildi ($MODE) — DESKTOP-READY geldigi icin test dusurulmedi"
	else
		echo "!! masaustu karesi alinamadi, ekran olcumu atlandi"
	fi
fi

# Sonuc ne olursa olsun son ekran goruntusunu al
snapshot "son"

kill "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

echo
echo "===== KAVIS-CHECK satirlari ====="
grep "KAVIS-CHECK" "$SERIAL" || echo "(hic satir yok)"
echo "==================================="

# --- Bosta RAM kullanimi (prompt 20: 1 GB normal, 1.5 GB mutlak sinir) ---
#
# DIKKAT: burada olculen deger CANLI (live) oturumun degeri ve KURULU
# sistemden YUKSEK cikar — canli modda kok dosya sistemi squashfs + RAM
# uzerinde overlay olarak durur, yazilan her sey RAM'de birikir. Yani bu
# rakam kotumser bir ust sinir; kurulu sistemde daha dusuk olacak.
# Bu yuzden asilirsa uyariyoruz, testi basarisiz saymiyoruz.
mem_line=$(grep -o 'MEM-USED=[0-9]*MB' "$SERIAL" 2>/dev/null | tail -1 || true)
if [[ -n "$mem_line" ]]; then
	mem_mb="${mem_line#MEM-USED=}"
	mem_mb="${mem_mb%MB}"
	echo
	echo "===== Bosta RAM (canli oturum) ====="
	printf '  olculen: %s MB\n' "$mem_mb"
	printf '  hedef  : 1024 MB normal / 1536 MB mutlak sinir\n'
	if (( mem_mb > 1536 )); then
		mem_verdict="SINIR ASILDI"
		echo "  ⚠ 1.5 GB mutlak sinir asildi — hafifletme gerekiyor"
		echo "::warning::Bosta RAM ${mem_mb} MB — 1.5 GB mutlak sinirin ustunde ($MODE)"
	elif (( mem_mb > 1024 )); then
		mem_verdict="normal ustu"
		echo "  ! 1 GB normal hedefin ustunde, 1.5 GB sinirin altinda"
	else
		mem_verdict="hedefte"
		echo "  ✓ hedefte"
	fi
	echo "  (canli mod olcumu kurulu sistemden yuksektir)"
	echo "===================================="

	# Panelin kendi maliyeti (madde 3: tasima sonrasi RAM olcumu).
	panel_rss=$(grep -o 'PANEL-RSS=[0-9]*MB' "$SERIAL" 2>/dev/null | tail -1 || true)
	panel_exe=$(grep -o 'PANEL-EXE=[^ ]*' "$SERIAL" 2>/dev/null | tail -1 || true)
	if [[ -n "$panel_rss" ]]; then
		printf '  panel  : %s (%s)\n' "${panel_rss#PANEL-RSS=}" "${panel_exe#PANEL-EXE=}"
	fi

	if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
		{
			echo "### QEMU $MODE"
			echo ""
			echo "| Alan | Değer |"
			echo "|---|---|"
			echo "| Boşta RAM (canlı) | **${mem_mb} MB** — ${mem_verdict} |"
			if [[ -n "$panel_rss" ]]; then
				echo "| Panel RSS | ${panel_rss#PANEL-RSS=} |"
			fi
			echo "| Hedef | 1024 MB normal / 1536 MB sınır |"
		} >> "$GITHUB_STEP_SUMMARY"
	fi
fi
echo
echo "===== seri gunlugunun son 80 satiri ====="
tail -n 80 "$SERIAL" || true
echo "========================================="

# Tam gunlugu is akisinin toplayabilmesi icin disari kopyala
if [[ -n "${SERIAL_OUT:-}" ]]; then
	cp "$SERIAL" "$SERIAL_OUT"
fi

case "$result" in
OK)
	echo ">> SONUC: BASARILI ($MODE, ${elapsed}s)"
	exit 0
	;;
FAIL)
	echo ">> SONUC: BASARISIZ — boot-check FAIL dondu ($MODE)"
	grep "KAVIS-CHECK: FAILED-CHECKS=" "$SERIAL" 2>/dev/null || true
	exit 1
	;;
BLANK)
	echo ">> SONUC: BASARISIZ — masaustu karesi bos ya da panel bolgesi cizilmemis ($MODE)"
	echo ">> TESHIS: boot-check gecti ama ekranda hicbir sey cizilmemis."
	echo ">>         Genellikle pencere yoneticisi ya da duvar kagidi"
	echo ">>         calismamis demektir. tani-$MODE yapitindaki"
	echo ">>         screen-$MODE-masaustu.png dosyasina bak."
	exit 1
	;;
PANIC)
	echo ">> SONUC: KERNEL PANIC ($MODE, ${elapsed}s)"
	exit 1
	;;
*)
	echo ">> SONUC: ZAMAN ASIMI — ${TIMEOUT}s icinde grafik arayuze ulasilamadi ($MODE)"
	if (( kernel_seen == 0 )); then
		echo ">> TESHIS: cekirdek hic baslamadi — sorun onyukleyicide (GRUB),"
		echo ">>         isletim sisteminde degil. Ekran goruntusune bak."
	else
		echo ">> TESHIS: cekirdek basladi ama grafik arayuze ulasilamadi."
		echo ">>         Seri gunlugundeki son satirlara bak."
	fi
	exit 1
	;;
esac
