#!/usr/bin/env bash
# Karan OS — ISO duman testi (QEMU)
#
# Kullanım:  tools/qemu-smoke-test.sh <iso-dosyasi> [bios|uefi|secureboot]
#
# ISO'yu QEMU'da açar, seri konsolu dinler ve /usr/lib/karanos/boot-check
# script'inin yazdığı "KARANOS-CHECK: RESULT=OK" satırını bekler.
#
# Bu test GitHub Actions'ta çalışır. Yerelde de çalışır ama Codespaces'te
# KVM olmadığı için yavaştır (yazılım öykünmesi) — geliştirici bağlantısı
# yavaş olduğundan ISO'yu indirip elle denemek yerine bunu kullanıyoruz.

set -euo pipefail

ISO="${1:?kullanim: $0 <iso-dosyasi> [bios|uefi|secureboot]}"
MODE="${2:-bios}"
TIMEOUT="${TIMEOUT:-900}"

[[ -f "$ISO" ]] || { echo "HATA: ISO bulunamadi: $ISO" >&2; exit 2; }

WORKDIR="$(mktemp -d)"
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

qemu_args=(
	-name "karanos-smoke-$MODE"
	-cpu max
	-smp 2
	-m 2560
	-cdrom "$ISO"
	-boot d
	-display none
	-vga std
	-serial "file:$SERIAL"
	-monitor "unix:$MONITOR,server,nowait"
	-no-reboot
	-rtc base=utc
	-net none
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

echo ">> Mod: $MODE"
echo ">> ISO: $ISO ($(du -h "$ISO" | cut -f1))"

qemu-system-x86_64 "${qemu_args[@]}" &
QEMU_PID=$!
# shellcheck disable=SC2064
trap "kill $QEMU_PID 2>/dev/null || true; rm -rf '$WORKDIR'" EXIT

result=""
elapsed=0
kernel_seen=0
stuck_reported=0
while (( elapsed < TIMEOUT )); do
	if ! kill -0 "$QEMU_PID" 2>/dev/null; then
		echo ">> QEMU beklenmedik sekilde kapandi (${elapsed}s)"
		break
	fi
	if grep -q "KARANOS-CHECK: RESULT=OK" "$SERIAL" 2>/dev/null; then
		result="OK"
		break
	fi
	if grep -q "KARANOS-CHECK: RESULT=FAIL" "$SERIAL" 2>/dev/null; then
		result="FAIL"
		break
	fi
	if grep -qi "Kernel panic" "$SERIAL" 2>/dev/null; then
		result="PANIC"
		break
	fi

	# Cekirdek basladi mi? "Linux version ..." cekirdegin ilk satiridir.
	if (( kernel_seen == 0 )) && grep -q "Linux version" "$SERIAL" 2>/dev/null; then
		kernel_seen=1
		echo ">> cekirdek basladi (${elapsed}s)"
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

# Sonuc ne olursa olsun son ekran goruntusunu al
snapshot "son"

kill "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

echo
echo "===== KARANOS-CHECK satirlari ====="
grep "KARANOS-CHECK" "$SERIAL" || echo "(hic satir yok)"
echo "==================================="
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
