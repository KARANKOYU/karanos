#!/usr/bin/env bash
# Kavis — boot an ISO in QEMU/KVM on the developer's own machine.
#
# WHY: the ISO is still built only in CI (lb build), but since 11 Sep 2026
# development runs on a machine with KVM (Bazzite host, Debian 13
# distrobox), so a downloaded ISO can be looked at here in a minute
# instead of in VirtualBox. This is the same machine shape as
# tools/qemu-smoke-test.sh, with two deliberate differences:
#
#   * A WINDOW, sound and no timeout — a person is watching.
#   * NO selftest marker by default. boot-check runs the selftest only
#     when the SMBIOS serial says "kavis-selftest" (CI sets it); a person
#     who sees keys being pressed and windows dragged on first boot
#     reports "the computer does things by itself" (v0.5-test1). Pass
#     --selftest to get CI's behaviour on purpose.
#
# The serial console is on this terminal AND logged: boot-check's marker
# lines (RESULT=, PASSWORDLESS-, MEM-USED ...) scroll here, and the
# getty on ttyS0 gives a shell in the guest — `karan` with no password —
# for looking at /etc/shadow, journalctl and the like without leaving
# the desktop alone.
#
# Usage:
#   tools/vm.sh [ISO] [--mode bios|uefi|secureboot] [--selftest]
#               [--ram MB] [--cpus N] [--no-sound] [--disk FILE]
#   ISO defaults to the newest kavis*.iso under ~/Downloads, out/ or iso/.
#   --disk FILE   attach a persistent qcow2 (created, 20 GB, if missing)
#                 — for the installer, once there is one.
# Requirements: qemu-system-x86 + qemu-system-gui (gtk display, pipewire
# audio), ovmf for uefi/secureboot, /dev/kvm.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ISO=""
MODE="uefi"
SELFTEST=0
RAM_MB=4096
CPUS=4
SOUND=1
DISK=""
while [[ $# -gt 0 ]]; do
	case "$1" in
	--mode) MODE="$2"; shift 2 ;;
	--selftest) SELFTEST=1; shift ;;
	--ram) RAM_MB="$2"; shift 2 ;;
	--cpus) CPUS="$2"; shift 2 ;;
	--no-sound) SOUND=0; shift ;;
	--disk) DISK="$2"; shift 2 ;;
	-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
	-*) echo "ERROR: unknown option $1" >&2; exit 2 ;;
	*) ISO="$1"; shift ;;
	esac
done

if [[ -z "$ISO" ]]; then
	ISO=$(ls -t ~/Downloads/kavis*.iso out/*.iso iso/*.iso 2>/dev/null | head -1 || true)
	[[ -n "$ISO" ]] || { echo "ERROR: no ISO given and none found under ~/Downloads, out/ or iso/" >&2; exit 2; }
fi
[[ -f "$ISO" ]] || { echo "ERROR: $ISO does not exist" >&2; exit 2; }
[[ -r /dev/kvm && -w /dev/kvm ]] || { echo "ERROR: /dev/kvm is not usable — without KVM this is the smoke test's slow path, use tools/qemu-smoke-test.sh" >&2; exit 2; }

WORKDIR="$REPO_ROOT/out/vm"
mkdir -p "$WORKDIR"
LOG="$WORKDIR/serial-$MODE.log"
OVMF_DIR="/usr/share/OVMF"

# Display: gtk (qemu-system-gui) is the one that resizes and takes the
# pointer properly; sdl is the fallback; with neither, say so instead of
# starting a VM nobody can see.
display=""
for d in gtk sdl; do
	if qemu-system-x86_64 -display help 2>/dev/null | grep -qx "$d"; then
		display="$d"
		break
	fi
done
[[ -n "$display" ]] || { echo "ERROR: this qemu has no gtk/sdl display — install qemu-system-gui" >&2; exit 2; }

# Sound: the boot music and the desktop's own sounds. pipewire goes
# straight to the host's socket (shared into a distrobox), pa is the
# fallback; none means the tune is still played to nowhere, so the
# splash timing stays real.
audio="none"
if [[ $SOUND -eq 1 ]]; then
	for a in pipewire pa; do
		if qemu-system-x86_64 -audiodev help 2>/dev/null | grep -qx "$a"; then
			audio="$a"
			break
		fi
	done
fi

# shellcheck disable=SC2054
qemu_args=(
	-name "kavis-vm-$MODE"
	-enable-kvm
	-cpu host
	-smp "$CPUS"
	-m "$RAM_MB"
	-cdrom "$ISO"
	-boot d
	-display "$display"
	-vga virtio
	-usb -device usb-tablet
	-rtc base=utc
	-nic user,model=virtio-net-pci
	-audiodev "$audio,id=snd0"
	-device intel-hda
	-device hda-duplex,audiodev=snd0
	-chardev "stdio,id=ser0,logfile=$LOG,signal=off"
	-serial chardev:ser0
	-monitor "unix:$WORKDIR/monitor-$MODE.sock,server,nowait"
)

if [[ $SELFTEST -eq 1 ]]; then
	# The one thing that tells CI's boot apart from a person's — see
	# boot-check "IS ANYBODY WATCHING".
	# shellcheck disable=SC2054
	qemu_args+=(-smbios type=1,serial=kavis-selftest)
fi

if [[ -n "$DISK" ]]; then
	if [[ ! -f "$DISK" ]]; then
		qemu-img create -f qcow2 "$DISK" 20G >/dev/null
		echo ">> created $DISK (20 GB, qcow2)"
	fi
	qemu_args+=(-drive "file=$DISK,if=virtio,format=qcow2")
fi

case "$MODE" in
bios)
	qemu_args+=(-machine q35)
	;;
uefi)
	[[ -f "$OVMF_DIR/OVMF_CODE_4M.fd" ]] || { echo "ERROR: the ovmf package is not installed" >&2; exit 2; }
	cp "$OVMF_DIR/OVMF_VARS_4M.fd" "$WORKDIR/vars-uefi.fd"
	qemu_args+=(
		-machine q35
		-drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_DIR/OVMF_CODE_4M.fd"
		-drive "if=pflash,format=raw,unit=1,file=$WORKDIR/vars-uefi.fd"
	)
	;;
secureboot)
	[[ -f "$OVMF_DIR/OVMF_CODE_4M.secboot.fd" ]] || { echo "ERROR: ovmf secboot file missing" >&2; exit 2; }
	cp "$OVMF_DIR/OVMF_VARS_4M.ms.fd" "$WORKDIR/vars-secboot.fd"
	# shellcheck disable=SC2054
	qemu_args+=(
		-machine "q35,smm=on"
		-global driver=cfi.pflash01,property=secure,value=on
		-global ICH9-LPC.disable_s3=1
		-drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_DIR/OVMF_CODE_4M.secboot.fd"
		-drive "if=pflash,format=raw,unit=1,file=$WORKDIR/vars-secboot.fd"
	)
	;;
*)
	echo "ERROR: unknown mode '$MODE' (bios|uefi|secureboot)" >&2
	exit 2
	;;
esac

echo ">> ISO: $ISO ($(du -h "$ISO" | cut -f1))"
echo ">> mode=$MODE ram=${RAM_MB}MB cpus=$CPUS display=$display audio=$audio selftest=$SELFTEST"
echo ">> serial console on this terminal, logged to $LOG"
echo ">> screenshot: echo 'screendump $WORKDIR/shot.ppm' | socat - UNIX-CONNECT:$WORKDIR/monitor-$MODE.sock"
exec qemu-system-x86_64 "${qemu_args[@]}"
