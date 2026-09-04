#!/usr/bin/env bash
# Kavis — ISO smoke test (QEMU)
#
# Usage:  tools/qemu-smoke-test.sh <iso-file> [bios|uefi|secureboot]
#
# Boots the ISO in QEMU, watches the serial console and waits for the
# "KAVIS-CHECK: RESULT=OK" line written by the /usr/lib/kavis/boot-check
# script.
#
# This test runs on GitHub Actions. It also runs locally, but Codespaces
# has no KVM so it is slow (software emulation). The point is not having
# to download and boot the ISO by hand after every change; manual testing
# (VirtualBox, USB) comes on top of it, not instead of it.

set -euo pipefail

ISO="${1:?usage: $0 <iso-file> [bios|uefi|secureboot]}"
MODE="${2:-bios}"
TIMEOUT="${TIMEOUT:-900}"

# Multi-arch preparation: this test was written for qemu-system-x86_64 +
# OVMF. When arm64 support is wanted, a qemu-system-aarch64 + AAVMF path
# will be added; until then other architectures are skipped silently
# (without an error).
ARCH="${KAVIS_ARCH:-amd64}"
if [[ "$ARCH" != "amd64" ]]; then
	echo "NOTE: the smoke test exists only for amd64; $ARCH skipped."
	exit 0
fi

[[ -f "$ISO" ]] || { echo "ERROR: ISO not found: $ISO" >&2; exit 2; }

# Hardware profile (item 46A): CI tries different RAM/CPU/GPU combinations
# with the same script. The defaults equal the old behaviour.
RAM_MB="${RAM_MB:-2560}"
CPUS="${CPUS:-2}"
VGA="${VGA:-std}"

WORKDIR="$(mktemp -d)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
trap 'rm -rf "$WORKDIR"' EXIT
SERIAL="$WORKDIR/serial.log"
MONITOR="$WORKDIR/monitor.sock"
: > "$SERIAL"

# Export QEMU's screen as a PNG.
# If we ever get stuck in the GRUB menu again, the serial log shows
# nothing, but the screenshot shows clearly what happened. We hit exactly
# this in the first CI run and had to download the ISO by hand to see it.
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
print(f"    screenshot: {dst} ({w}x{h})")
PY
}

OVMF_DIR="/usr/share/OVMF"

# The commas below are part of the QEMU parameters (audiodev=snd0 etc.),
# not array separators.
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
	# Sound card: the stage-3 boot music looks for a real ALSA device.
	# Backend "none" — the audio goes nowhere, but aplay runs in real
	# time, so the splash staying up for the whole tune is tested too.
	-audiodev none,id=snd0
	-device intel-hda
	-device hda-duplex,audiodev=snd0
)

case "$MODE" in
bios)
	qemu_args+=(-machine q35)
	;;
uefi)
	[[ -f "$OVMF_DIR/OVMF_CODE_4M.fd" ]] || { echo "ERROR: the ovmf package is not installed" >&2; exit 2; }
	cp "$OVMF_DIR/OVMF_VARS_4M.fd" "$WORKDIR/vars.fd"
	qemu_args+=(
		-machine q35
		-drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_DIR/OVMF_CODE_4M.fd"
		-drive "if=pflash,format=raw,unit=1,file=$WORKDIR/vars.fd"
	)
	;;
secureboot)
	[[ -f "$OVMF_DIR/OVMF_CODE_4M.secboot.fd" ]] || { echo "ERROR: ovmf secboot file missing" >&2; exit 2; }
	cp "$OVMF_DIR/OVMF_VARS_4M.ms.fd" "$WORKDIR/vars.fd"
	# The commas below are part of the QEMU parameter, not array separators.
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
	echo "ERROR: unknown mode '$MODE' (bios|uefi|secureboot)" >&2
	exit 2
	;;
esac

# Use KVM if available (fast on real hardware), otherwise software emulation
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
	qemu_args+=(-enable-kvm)
	echo ">> using KVM"
else
	echo ">> no KVM, software emulation (slow) — timeout ${TIMEOUT}s"
fi

echo ">> Mode: $MODE (RAM=${RAM_MB}MB CPU=$CPUS VGA=$VGA)"
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
		echo ">> QEMU exited unexpectedly (${elapsed}s)"
		break
	fi
	# Desktop frame: taken 2 s after boot-check says the panel +
	# nemo-desktop windows are VISIBLE (DESKTOP-READY)
	# (v0.4-test2 A: a fixed 12 s wait was too early on slow profiles).
	if (( desktop_shot == 0 )) && grep -q "KAVIS-CHECK: DESKTOP-READY" "$SERIAL" 2>/dev/null; then
		desktop_shot=1
		echo ">> DESKTOP-READY seen (${elapsed}s), desktop frame in 2 s"
		sleep 2
		snapshot "desktop"
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

	# Has the kernel started?
	# `quiet` was added in stage 3 and the "Linux version" line no longer
	# shows on the serial console. So we look for any sign of life from
	# the kernel or systemd — the goal is to tell "stuck in the
	# bootloader" apart from everything else.
	if (( kernel_seen == 0 )) && grep -qE "Linux version|systemd\[1\]|Welcome to|KAVIS-CHECK|Reached target" "$SERIAL" 2>/dev/null; then
		kernel_seen=1
		kernel_seen_at=$elapsed
		echo ">> kernel started (${elapsed}s)"
	fi

	# Splash frame: the Plymouth splash is on screen only during boot. By
	# the time the frames at the end of the smoke test are taken the
	# splash is long gone, so the stage-3 output is never seen.
	# plymouth-x11 is not in Debian, so it cannot be rendered locally
	# either; this early frame is the only way to see the splash.
	# Hitting the window in which the splash is on screen (~10-55 s
	# depending on profile speed) with a single frame was luck
	# (v0.2-test3: none of five profiles caught it). We take three.
	if (( kernel_seen == 1 && splash_shot == 0 && elapsed >= kernel_seen_at + 10 )); then
		splash_shot=1
		echo ">> splash frame 1/3 (${elapsed}s)"
		snapshot "splash-1"
	fi
	if (( kernel_seen == 1 && splash_shot == 1 && elapsed >= kernel_seen_at + 25 )); then
		splash_shot=2
		echo ">> splash frame 2/3 (${elapsed}s)"
		snapshot "splash-2"
	fi
	if (( kernel_seen == 1 && splash_shot == 2 && elapsed >= kernel_seen_at + 40 )); then
		splash_shot=3
		echo ">> splash frame 3/3 (${elapsed}s)"
		snapshot "splash-3"
	fi

	# If the kernel still has not started after 240 s we are stuck in the
	# bootloader. Take the screenshot and report without waiting for the
	# timeout.
	if (( kernel_seen == 0 && elapsed >= 240 && stuck_reported == 0 )); then
		stuck_reported=1
		echo ">> WARNING: ${elapsed}s passed, the kernel never started."
		echo ">> Probably the bootloader menu is waiting for a key. Screen:"
		snapshot "stuck"
	fi

	sleep 5
	elapsed=$((elapsed + 5))
	if (( elapsed % 60 == 0 )); then
		echo ">> ${elapsed}s… (serial log $(wc -l < "$SERIAL") lines)"
	fi
done

# Desktop frame: when boot-check says "RESULT=OK", Xorg and openbox are
# up but the wallpaper and windows from autostart may not be drawn yet.
# A frame taken a few seconds later is the fastest way to see how the
# theme looks without downloading the ISO.
if [[ "$result" == "OK" ]]; then
	# The verdict depends on DESKTOP-READY (inside boot-check: not mapped
	# within 60 s → PANEL-NOT-MAPPED → RESULT=FAIL). The measurements
	# here are LOG ONLY: mean brightness, distinct color count, clock region.
	#  - screen-not-blank: <24 colors AND stddev <3 → blank (dark desktop
	#    ~2000 colors, stddev ~11.5)
	#  - screen-clock-visible: bottom 44 rows x right quarter >=15 bright
	#    pixels (drawn panel ~440)
	ppm="$WORKDIR/screen-desktop.ppm"
	if [[ ! -s "$ppm" ]]; then
		echo "!! no DESKTOP-READY frame (line came late?) — taking one now"
		snapshot "desktop"
	fi
	if [[ -s "$ppm" ]]; then
		python3 "$REPO_ROOT/tools/screen-not-blank.py" "$ppm" \
			|| echo "::warning::Desktop frame failed the blank-screen check ($MODE) — test not failed because DESKTOP-READY arrived"
		python3 "$REPO_ROOT/tools/screen-clock-visible.py" "$ppm" \
			|| echo "::warning::Clock region failed the blank check ($MODE) — test not failed because DESKTOP-READY arrived"
	else
		echo "!! could not take the desktop frame, screen measurement skipped"
	fi
fi

# Take the final screenshot whatever the result
snapshot "final"

kill "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

echo
echo "===== KAVIS-CHECK lines ====="
# The selftest report is base64 in the middle of the log; printing it
# would bury everything else.
grep "KAVIS-CHECK" "$SERIAL" | grep -v "KAVIS-CHECK: SELFTEST-REPORT " \
	|| echo "(no lines at all)"
echo "==================================="

# --- selftest report (item 72) ---------------------------------------
#
# A failing scenario sends its run directory out as base64 over the
# serial port, since the VM has no shared folder. Rebuild the archive
# next to the screenshots so it travels with the diagnostics artifact.
if grep -q "KAVIS-CHECK: SELFTEST-REPORT-BEGIN" "$SERIAL" 2>/dev/null; then
	report="${SCREENSHOT_DIR:-$PWD}/selftest-$MODE.tar.gz"
	if sed -n 's/^KAVIS-CHECK: SELFTEST-REPORT \(.*\)$/\1/p' "$SERIAL" \
		| tr -d '\r' | base64 -d > "$report" 2>/dev/null \
		&& tar tzf "$report" >/dev/null 2>&1; then
		echo ">> selftest report: $report"
	else
		echo "::warning::selftest report could not be decoded ($MODE)"
		rm -f "$report"
	fi
elif grep -q "KAVIS-CHECK: SELFTEST-REPORT-SKIP" "$SERIAL" 2>/dev/null; then
	echo "::warning::selftest report too large for the serial log ($MODE)"
fi

# --- Idle RAM usage (prompt 20: 1 GB normal, 1.5 GB absolute limit) ---
#
# NOTE: the value measured here is the LIVE session's and comes out
# HIGHER than an installed system — in live mode the root file system is
# squashfs + an overlay in RAM, everything written accumulates in RAM. So
# this figure is a pessimistic upper bound; an installed system is lower.
# That is why we warn when it is exceeded instead of failing the test.
mem_line=$(grep -o 'MEM-USED=[0-9]*MB' "$SERIAL" 2>/dev/null | tail -1 || true)
if [[ -n "$mem_line" ]]; then
	mem_mb="${mem_line#MEM-USED=}"
	mem_mb="${mem_mb%MB}"
	echo
	echo "===== Idle RAM (live session) ====="
	printf '  measured: %s MB\n' "$mem_mb"
	printf '  target  : 1024 MB normal / 1536 MB absolute limit\n'
	if (( mem_mb > 1536 )); then
		mem_verdict="LIMIT EXCEEDED"
		echo "  ⚠ 1.5 GB absolute limit exceeded — needs slimming"
		echo "::warning::Idle RAM ${mem_mb} MB — above the 1.5 GB absolute limit ($MODE)"
	elif (( mem_mb > 1024 )); then
		mem_verdict="above normal"
		echo "  ! above the 1 GB normal target, below the 1.5 GB limit"
	else
		mem_verdict="on target"
		echo "  ✓ on target"
	fi
	echo "  (the live-mode measurement is higher than an installed system)"
	echo "===================================="

	# The panel's own cost (item 3: RAM measurement after the port).
	panel_rss=$(grep -o 'PANEL-RSS=[0-9]*MB' "$SERIAL" 2>/dev/null | tail -1 || true)
	panel_exe=$(grep -o 'PANEL-EXE=[^ ]*' "$SERIAL" 2>/dev/null | tail -1 || true)
	if [[ -n "$panel_rss" ]]; then
		printf '  panel   : %s (%s)\n' "${panel_rss#PANEL-RSS=}" "${panel_exe#PANEL-EXE=}"
	fi

	if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
		{
			echo "### QEMU $MODE"
			echo ""
			echo "| Field | Value |"
			echo "|---|---|"
			echo "| Idle RAM (live) | **${mem_mb} MB** — ${mem_verdict} |"
			if [[ -n "$panel_rss" ]]; then
				echo "| Panel RSS | ${panel_rss#PANEL-RSS=} |"
			fi
			echo "| Target | 1024 MB normal / 1536 MB limit |"
		} >> "$GITHUB_STEP_SUMMARY"
	fi
fi
echo
echo "===== last 80 lines of the serial log ====="
tail -n 80 "$SERIAL" || true
echo "========================================="

# Copy the full log out so the workflow can collect it
if [[ -n "${SERIAL_OUT:-}" ]]; then
	cp "$SERIAL" "$SERIAL_OUT"
fi

case "$result" in
OK)
	echo ">> RESULT: PASSED ($MODE, ${elapsed}s)"
	exit 0
	;;
FAIL)
	echo ">> RESULT: FAILED — boot-check returned FAIL ($MODE)"
	grep "KAVIS-CHECK: FAILED-CHECKS=" "$SERIAL" 2>/dev/null || true
	exit 1
	;;
BLANK)
	echo ">> RESULT: FAILED — desktop frame blank or panel region not drawn ($MODE)"
	echo ">> DIAGNOSIS: boot-check passed but nothing was drawn on screen."
	echo ">>            Usually the window manager or the wallpaper did not"
	echo ">>            run. Look at screen-$MODE-desktop.png in the"
	echo ">>            diag-$MODE artifact."
	exit 1
	;;
PANIC)
	echo ">> RESULT: KERNEL PANIC ($MODE, ${elapsed}s)"
	exit 1
	;;
*)
	echo ">> RESULT: TIMEOUT — no graphical session within ${TIMEOUT}s ($MODE)"
	if (( kernel_seen == 0 )); then
		echo ">> DIAGNOSIS: the kernel never started — the problem is in the"
		echo ">>            bootloader (GRUB), not the OS. Look at the screenshot."
	else
		echo ">> DIAGNOSIS: the kernel started but no graphical session came up."
		echo ">>            Look at the last lines of the serial log."
	fi
	exit 1
	;;
esac
