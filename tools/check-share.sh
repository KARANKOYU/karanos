#!/usr/bin/env bash
# Kavis — two devices find each other and a file crosses (item 76).
#
# WHY IT IS TWO INSTANCES ON ONE MACHINE. The thing worth testing is the
# PROTOCOL — the announcement, the direct registration that answers it,
# the ask-then-send pair — and none of that cares whether the two ends
# are on different hardware. What it does care about is that each end
# has its own configuration, its own trusted list, its own downloads
# folder and its own session bus, so this gives them one each.
#
# The TCP port is the one thing that cannot be shared, so the second
# instance takes 53318. That is not a test-only hack: the announcement
# carries the port precisely because a device may not be on the default
# one, and a person with two sessions open is the same situation.
#
# What is checked, in order:
#   1. each end finds the other, with the right name and address;
#   2. a device that is not trusted is REFUSED, with nobody to ask
#      (no display here — the daemon must decline, never assume);
#   3. a trusted device gets through and the bytes arrive intact.
#
# Usage: tools/check-share.sh
# Requirements: dbus-x11 (dbus-launch)
# Exit: 0 = SHARE-OK
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

command -v dbus-launch >/dev/null 2>&1 || {
	echo "ERROR: dbus-launch missing (apt: dbus-x11)" >&2; exit 2; }

ls out/packages/kavis-share_*.deb >/dev/null 2>&1 \
	|| tools/build-packages.sh kavis-share >/dev/null

T=$(mktemp -d)
ROOT="$T/root"
dpkg-deb -x "$(ls -1 out/packages/kavis-share_*.deb | head -1)" "$ROOT"
SHARE="$ROOT/usr/bin/kavis-share"

A_PID=""; B_PID=""; A_BUS_PID=""; B_BUS_PID=""
cleanup() {
	kill $A_PID $B_PID $A_BUS_PID $B_BUS_PID 2>/dev/null || true
	rm -rf "$T"
}
trap cleanup EXIT

# Each peer gets its own everything: configuration, trusted list,
# downloads folder, runtime dir and session bus. Sharing any one of them
# would make the two ends the same device wearing two names.
start_peer() { # <dir> <name> <visibility> <port> <bus>
	local d="$1"
	mkdir -p "$d/config/kavis" "$d/data" "$d/home/downloads" "$d/run"
	chmod 700 "$d/run"
	printf '[share]\nname=%s\nvisibility=%s\nport=%s\n' "$2" "$3" "$4" \
		> "$d/config/kavis/kavis.conf"
	env XDG_CONFIG_HOME="$d/config" XDG_DATA_HOME="$d/data" \
	    HOME="$d/home" XDG_RUNTIME_DIR="$d/run" \
	    DBUS_SESSION_BUS_ADDRESS="$5" \
		"$SHARE" --daemon > "$d/log" 2>&1 &
	echo $!
}

ask() { # <dir> <bus> <args...>
	local d="$1" bus="$2"; shift 2
	env XDG_CONFIG_HOME="$d/config" XDG_DATA_HOME="$d/data" \
	    HOME="$d/home" XDG_RUNTIME_DIR="$d/run" \
	    DBUS_SESSION_BUS_ADDRESS="$bus" "$SHARE" "$@"
}

fail=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=1; }

eval "$(dbus-launch --sh-syntax)"
A_BUS="$DBUS_SESSION_BUS_ADDRESS"; A_BUS_PID=$DBUS_SESSION_BUS_PID
eval "$(dbus-launch --sh-syntax)"
B_BUS="$DBUS_SESSION_BUS_ADDRESS"; B_BUS_PID=$DBUS_SESSION_BUS_PID

A_PID=$(start_peer "$T/a" peer-a everyone 53317 "$A_BUS")
sleep 2
# Peer B trusts peer A before it starts: the already-paired path, the
# one that has to work with nobody being asked anything.
FP_A=$(sed -n 's/^fingerprint=//p' "$T/a/config/kavis/kavis.conf")
mkdir -p "$T/b/data/kavis"
printf '%s peer-a\n' "$FP_A" > "$T/b/data/kavis/trusted-devices"
B_PID=$(start_peer "$T/b" peer-b trusted 53318 "$B_BUS")
sleep 7

grep -q "peer-a listening" "$T/a/log" || bad "peer A did not start"
grep -q "peer-b listening" "$T/b/log" || bad "peer B did not start"

A_SEES=$(ask "$T/a" "$A_BUS" --list)
B_SEES=$(ask "$T/b" "$B_BUS" --list)
printf '%s' "$A_SEES" | grep -q "peer-b" \
	&& ok "peer A found peer B" || bad "peer A did not find peer B"
printf '%s' "$B_SEES" | grep -q "peer-a" \
	&& ok "peer B found peer A" || bad "peer B did not find peer A"
printf '%s' "$B_SEES" | grep -q "trusted" \
	&& ok "peer B knows peer A is trusted" \
	|| bad "peer B did not recognise the trusted fingerprint"

# The refusal, which matters more than the transfer: peer A is set to
# "everyone", so an unknown sender is ASKED — and with no display there
# is nobody to ask, so the answer has to be no.
echo "from b" > "$T/b/home/note-b.txt"
if ask "$T/b" "$B_BUS" --send "$T/b/home/note-b.txt" --to peer-a \
		>/dev/null 2>&1; then
	bad "an untrusted device was accepted with nobody to ask"
else
	ok "an untrusted device is declined when nobody can be asked"
fi
[[ -e "$T/a/home/downloads/kavis-share/note-b.txt" ]] \
	&& bad "a declined file was written anyway" \
	|| ok "and nothing was written"

echo "hello from peer A" > "$T/a/home/note.txt"
if ask "$T/a" "$A_BUS" --send "$T/a/home/note.txt" --to peer-b \
		>/dev/null 2>&1; then
	ok "a trusted device is accepted without asking"
else
	bad "the trusted transfer failed"
fi
sleep 1
LANDED="$T/b/home/downloads/kavis-share/note.txt"
if [[ -f "$LANDED" ]] && [[ "$(cat "$LANDED")" == "hello from peer A" ]]; then
	ok "the bytes arrived intact, in ~/downloads/kavis-share"
else
	bad "the file did not arrive (or arrived wrong)"
fi

[ "$fail" -eq 0 ] || { echo "SHARE-FAIL"; exit 1; }
echo "SHARE-OK: two devices, one protocol, a file across and a stranger refused"
