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
: > "$SERIAL"

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
	sleep 5
	elapsed=$((elapsed + 5))
	if (( elapsed % 60 == 0 )); then
		echo ">> ${elapsed}s… (seri gunlugu $(wc -l < "$SERIAL") satir)"
	fi
done

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
OK)   echo ">> SONUC: BASARILI ($MODE, ${elapsed}s)"; exit 0 ;;
FAIL) echo ">> SONUC: BASARISIZ — boot-check FAIL dondu ($MODE)"; exit 1 ;;
*)    echo ">> SONUC: ZAMAN ASIMI — ${TIMEOUT}s icinde grafik arayuze ulasilamadi ($MODE)"; exit 1 ;;
esac
